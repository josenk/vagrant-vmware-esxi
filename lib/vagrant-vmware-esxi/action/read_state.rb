require 'log4r'
require 'net/ssh'
require 'socket'

module VagrantPlugins
  module ESXi
    module Action
      # This action reads the state of the machine and puts it in the
      # `:machine_state_id` key in the environment.
      class ReadState
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::read_state')
        end

        def call(env)
          env[:machine_state] = read_state(env)

          #  Do NFS stuff
          if env[:machine_state].to_s.include? "running"
            ssh_info = env[:machine].ssh_info
            if defined?(ssh_info[:host])
              env[:nfs_machine_ip] = [ssh_info[:host]]
              env[:nfs_host_ip] = Socket::getaddrinfo(Socket.gethostname,"echo",Socket::AF_INET)[0][3]
              env[:nfs_valid_ids] = [env[:machine].id]
            end
          end

          @app.call(env)
        end

        def read_state(env)
          @logger.info('vagrant-vmware-esxi, read_state: start...')

          # Get config.
          machine = env[:machine]
          config = env[:machine].provider_config

          return :not_created if machine.id.to_i < 1

          @logger.info("vagrant-vmware-esxi, read_state: machine id: #{machine.id}")
          @logger.info("vagrant-vmware-esxi, read_state: current state: #{env[:machine_state]}")

          Net::SSH.start(config.esxi_hostname, config.esxi_username,
            password:                   $esxi_password,
            port:                       config.esxi_hostport,
            keys:                       config.local_private_keys,
            timeout:                    20,
            number_of_password_prompts: 0,
            non_interactive:            true
          ) do |ssh|

            r = ssh.exec!(
                    "vim-cmd vmsvc/getallvms|grep -q \"^#{machine.id} \" && "\
                    "vim-cmd vmsvc/power.getstate #{machine.id} || return 254")
            power_status = r

            return :not_created if r.exitstatus == 254

            if power_status == "" or r.exitstatus != 0
              raise Errors::ESXiError,
                    message: 'Unable to get VM Power State!'
            end

            if (power_status.include? "Powered on") && !env[:machine].ssh_info.nil?
              return :running
            elsif power_status.include? "Powered on"
              return :powered_on
            elsif power_status.include? "Powered off"
              return :powered_off
            elsif power_status.include? "Suspended"
              return :suspended
            end

            return nil
          end

          return :not_created
        end
      end
    end
  end
end
