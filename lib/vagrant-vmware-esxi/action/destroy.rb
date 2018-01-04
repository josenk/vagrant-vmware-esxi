require 'log4r'
require 'net/ssh'

module VagrantPlugins
  module ESXi
    module Action
      # This action will Destroy VM. unregister and delete the VM from disk.
      class Destroy
        def initialize(app, _env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::destroy')
        end

        def call(env)
          destroy(env)
          @app.call(env)
        end

        def destroy(env)
          @logger.info('vagrant-vmware-esxi, destroy: start...')

          # Get config.
          machine = env[:machine]
          config = env[:machine].provider_config

          @logger.info("vagrant-vmware-esxi, destroy: machine id: #{machine.id}")
          @logger.info('vagrant-vmware-esxi, destroy: current state: '\
                       "#{env[:machine_state]}")

          if env[:machine_state].to_s == 'not_created'
            env[:ui].info I18n.t('vagrant_vmware_esxi.already_destroyed')
          elsif env[:machine_state].to_s != 'powered_off'
            raise Errors::ESXiError,
                  message: 'Guest VM should have been powered off...'
          else
            Net::SSH.start( config.esxi_hostname, config.esxi_username,
              password:                   $esxi_password,
              port:                       config.esxi_hostport,
              keys:                       config.esxi_private_keys,
              timeout:                    10,
              number_of_password_prompts: 0,
              non_interactive:            true
            ) do |ssh|

              r = ssh.exec!("vim-cmd vmsvc/destroy #{machine.id}")
              if r.exitstatus != 0
                raise Errors::ESXiError,
                      message => "Unable to destroy the VM:\n"\
                                 "  #{r}"
              end
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'VM has been destroyed...')
            end
          end
        end
      end
    end
  end
end
