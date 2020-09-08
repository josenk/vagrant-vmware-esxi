require 'log4r'
require 'net/ssh'
require 'socket'

module VagrantPlugins
  module ESXi
    module Action
      # This action reads the state of the machine and puts it in the
      # `:machine_state_id` key in the environment.
      class ReadState
        @@nfs_valid_ids = []
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::read_state')
        end

        def call(env)
          env[:machine_state] = read_state(env)

          #  Do NFS stuff
          if (env[:machine_state].to_s.include? "running") && (@nfs_host_ip.nil?)
            ssh_info = env[:machine].ssh_info
            if defined?(ssh_info[:host])
              env[:nfs_machine_ip] = [ssh_info[:host]]
              @nfs_machine_ip = [ssh_info[:host]].dup
              @@nfs_valid_ids |= [env[:machine].id]
              env[:nfs_valid_ids] = @@nfs_valid_ids

              begin
                puts "Get local IP address for NFS. (pri)" if env[:machine].provider_config.debug =~ %r{ip}i
                #  The Standard way to get your IP.  Get your hostname, resolv it.
                addr_info = Socket::getaddrinfo(Socket.gethostname,"echo",Socket::AF_INET)

                non_localhost = addr_info.select{ |info| info[3] !~ /^127./}

                env[:nfs_host_ip] = non_localhost[0][3]
              rescue
                puts "Get local IP address for NFS. (alt)" if env[:machine].provider_config.debug =~ %r{ip}i
                #  Alt method.  Get list of ip_addresses on system and use the first.
                Socket.ip_address_list.each do |ip|
                  if (ip.ip_address =~ /^(\d{1,3}).(\d{1,3}).(\d{1,3}).(\d{1,3})$/) && (ip.ip_address !~ /^127./)
                    env[:nfs_host_ip] = ip.ip_address
                    break
                  end
                end
              end

              @nfs_host_ip = env[:nfs_host_ip].dup
              if env[:nfs_host_ip].nil?
                #  Something bad happened above.  Give up on NFS.
                env[:nfs_machine_ip] = nil
                env[:nfs_host_ip] = nil
                env[:nfs_valid_ids] = nil
                #  Give an error, but continue..
                env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                     message: 'Configure NFS   : ERROR, Unable to configure NFS on this machine.')
              end
              if (env[:machine].provider_config.debug =~ %r{ip}i) && !env[:nfs_host_ip].nil?
                puts "nfs_host_ip: #{env[:nfs_host_ip]}"
              end
            end
          else
            # Use Cached entries
            env[:nfs_machine_ip] = @nfs_machine_ip
            env[:nfs_host_ip] = @nfs_host_ip
            env[:nfs_valid_ids] = @@nfs_valid_ids
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
            password:                   config.esxi_password,
            port:                       config.esxi_hostport,
            keys:                       config.local_private_keys,
            timeout:                    20,
            number_of_password_prompts: 0,
            non_interactive:            true
          ) do |ssh|

            r = ssh.exec!("vim-cmd vmsvc/power.getstate #{machine.id} || return 254")
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
