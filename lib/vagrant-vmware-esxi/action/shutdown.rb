require 'log4r'
require 'net/ssh'

module VagrantPlugins
  module ESXi
    module Action
      # This action will start a graceful shutdown on the vm
      class Shutdown
        def initialize(app, _env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::shutdown')
        end

        def call(env)
          shutdown(env)
          @app.call(env)
        end

        def shutdown(env)
          @logger.info('vagrant-vmware-esxi, shutdown: start...')

          # Get config.
          machine = env[:machine]
          config = env[:machine].provider_config

          if env[:machine_state].to_s == 'powered_off'
            env[:ui].info I18n.t('vagrant_vmware_esxi.already_powered_off')
          elsif env[:machine_state].to_s == 'not_created'
            env[:ui].info I18n.t('vagrant_vmware_esxi.already_destroyed')
          else
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Starting graceful shutdown...")
            Net::SSH.start(config.esxi_hostname, config.esxi_username,
              password:                   config.esxi_password,
              port:                       config.esxi_hostport,
              keys:                       config.local_private_keys,
              timeout:                    20,
              number_of_password_prompts: 0,
              non_interactive:            true
            ) do |ssh|

              r = ssh.exec!("vim-cmd vmsvc/power.shutdown #{machine.id}")
              config.saved_ipaddress = nil

              if r.exitstatus != 0
                raise Errors::ESXiError,
                      message: "Unable to shutdown the VM:\n    #{r}"
              end
            end
          end
        end
      end
    end
  end
end
