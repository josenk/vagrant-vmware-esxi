require 'log4r'
require 'net/ssh'

module VagrantPlugins
  module ESXi
    module Action
      # This action will halt (power off) the VM
      class Halt
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::halt')
        end

        def call(env)
          halt(env)
          @app.call(env)
        end

        def halt(env)
          @logger.info('vagrant-vmware-esxi, halt: start...')

          # Get config.
          machine = env[:machine]
          config = env[:machine].provider_config

          if env[:machine_state].to_s == 'powered_off'
            env[:ui].info I18n.t('vagrant_vmware_esxi.already_powered_off')
          elsif env[:machine_state].to_s == 'not_created'
            env[:ui].info I18n.t('vagrant_vmware_esxi.already_destroyed')
          else
            Net::SSH.start( config.esxi_hostname, config.esxi_username,
              password:                   $esxi_password,
              port:                       config.esxi_hostport,
              keys:                       config.esxi_private_keys,
              timeout:                    20,
              number_of_password_prompts: 0,
              non_interactive:            true
            ) do |ssh|

              r = ssh.exec!("vim-cmd vmsvc/power.off #{machine.id}")

              if r.exitstatus != 0
                raise Errors::ESXiError,
                      message: "Unable to power off the VM:\n"
                               "  #{r}"
              end
              env[:ui].info I18n.t('vagrant_vmware_esxi.states.powered_off.short')
            end
          end
        end
      end
    end
  end
end
