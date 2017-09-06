require 'log4r'
require 'net/ssh/simple'

module VagrantPlugins
  module ESXi
    module Action
      # This action will save (create) a new snapshot
      class SnapshotSave
        def initialize(app, _env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::snapshot_save')
        end

        def call(env)
          suspend(env)
          @app.call(env)
        end

        def suspend(env)
          @logger.info('vagrant-vmware-esxi, snapshot_save: start...')

          # Get config.
          machine = env[:machine]
          config = env[:machine].provider_config

          @logger.info("vagrant-vmware-esxi, snapshot_save: machine id: #{machine.id}")
          @logger.info("vagrant-vmware-esxi, snapshot_save: current state: #{env[:machine_state]}")

          if env[:machine_state].to_s == 'not_created'
           env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                message: 'Cannot snapshot_save in this state')
          else
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: 'Attempting to snapshot_save')

            Net::SSH::Simple.sync(
              user:     config.esxi_username,
              password: config.esxi_password,
              port:     config.esxi_hostport,
              keys:     config.esxi_private_keys,
              timeout:  300
            ) do

              r = ssh config.esxi_hostname,
                  "vim-cmd vmsvc/snapshot.create #{machine.id} \"#{env[:snapshot_name]}\""

              if r.exit_code != 0
                raise Errors::ESXiError,
                      message: "Unable to save snapshots of the VM:\n"\
                               "  #{r.stdout}\n#{r.stderr}"
              end
              env[:ui].info I18n.t('vagrant_vmware_esxi.support')

              env[:ui].info I18n.t('vagrant_vmware_esxi.snapshot_saved')
            end
          end
        end
      end
    end
  end
end
