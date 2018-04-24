require 'log4r'
require 'net/ssh'

module VagrantPlugins
  module ESXi
    module Action
      # This action will Suspend the VM
      class Suspend
        def initialize(app, _env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::suspend')
        end

        def call(env)
          suspend(env)
          @app.call(env)
        end

        def suspend(env)
          @logger.info('vagrant-vmware-esxi, suspend: start...')

          # Get config.
          machine = env[:machine]
          config = env[:machine].provider_config

          @logger.info("vagrant-vmware-esxi, suspend: machine id: #{machine.id}")
          @logger.info("vagrant-vmware-esxi, suspend: current state: #{env[:machine_state]}")

          if env[:machine_state].to_s == 'suspended'
            env[:ui].info I18n.t('vagrant_vmware_esxi.already_suspended')
          elsif (env[:machine_state].to_s == 'powered_off') ||
                (env[:machine_state].to_s == 'not_created')
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: 'Cannot suspend in this state')
          else
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: 'Attempting to suspend')

            #
            Net::SSH.start(config.esxi_hostname, config.esxi_username,
              password:                   config.esxi_password,
              port:                       config.esxi_hostport,
              keys:                       config.local_private_keys,
              timeout:                    20,
              number_of_password_prompts: 0,
              non_interactive:            true,
              keepalive:                  true,
              keepalive_interval:         30
            ) do |ssh|

              r = ssh.exec!("vim-cmd vmsvc/power.suspend #{machine.id}")
              if r.exitstatus != 0
                raise Errors::ESXiError,
                      message: "Unable to suspend the VM:\n"\
                               "  #{r}"
              end
              env[:ui].info I18n.t('vagrant_vmware_esxi.support')
              env[:ui].info I18n.t('vagrant_vmware_esxi.states.suspended.short')
            end
          end
        end
      end
    end
  end
end
