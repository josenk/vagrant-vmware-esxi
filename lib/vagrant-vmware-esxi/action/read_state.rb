require 'log4r'

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

          Net::SSH::Simple.sync(
            user:     config.esxi_username,
            password: config.esxi_password,
            port:     config.esxi_hostport,
            keys:     config.esxi_private_keys
          ) do

            r = ssh config.esxi_hostname,
                    "vim-cmd vmsvc/getallvms|grep -q \"^#{machine.id} \" && "\
                    "vim-cmd vmsvc/power.getstate #{machine.id} || return 254"
            power_status = r.stdout

            return :not_created if r.exit_code == 254
            if power_status == "" or r.exit_code != 0
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
