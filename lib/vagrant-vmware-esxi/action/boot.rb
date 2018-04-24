require 'log4r'
require 'net/ssh'

module VagrantPlugins
  module ESXi
    module Action
      # This action Boots (power on) the VM
      class Boot
        def initialize(app, _env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::boot')
        end

        def call(env)
          boot(env)
          @app.call(env)
        end

        def boot(env)
          @logger.info('vagrant-vmware-esxi, boot: start...')

          # Get config.
          machine = env[:machine]
          config = env[:machine].provider_config

          @logger.info("vagrant-vmware-esxi, boot: machine id: #{machine.id}")
          @logger.info('vagrant-vmware-esxi, boot: current state: '\
                       "#{env[:machine_state]}")

          if env[:machine_state].to_s == 'powered_on' ||
             env[:machine_state].to_s == 'running'
            env[:ui].info I18n.t('vagrant_vmware_esxi.already_powered_on')
          elsif env[:machine_state].to_s == 'not_created'
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: 'Cannot boot in this state')
          else
            Net::SSH.start(config.esxi_hostname, config.esxi_username,
              password:                   config.esxi_password,
              port:                       config.esxi_hostport,
              keys:                       config.local_private_keys,
              timeout:                    20,
              number_of_password_prompts: 0,
              non_interactive:            true
            ) do |ssh|

              r = ssh.exec!("vim-cmd vmsvc/power.on #{machine.id}")
              if r.exitstatus != 0
                raise Errors::ESXiError,
                      message: "Unable to power on VM:\n"\
                               "  #{r}"\
                               '  Review ESXi logs for additional information!'
              end
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'VM has been Powered On...')
            end
          end
        end
      end
    end
  end
end
