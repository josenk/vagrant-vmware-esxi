require 'log4r'
require 'net/ssh/simple'

module VagrantPlugins
  module ESXi
    module Action
      # This action connects to the ESXi, verifies credentials and
      # validates if it's a ESXi host
      class ConnectESXi
        def initialize(app, _env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::connect_esxi')
        end

        def call(env)
          connect_esxi(env)
          @app.call(env)
        end

        def connect_esxi(env)
          @logger.info('vagrant-vmware-esxi, connect_esxi: start...')

          # Get config.
          config = env[:machine].provider_config

          if config.esxi_private_keys.is_a? Array
            config.esxi_private_keys = [
              '~/.ssh/id_rsa',
              '~/.ssh/id_dsa',
              '~/.ssh/id_ecdsa',
              '~/.ssh/id_ed25519'
            ]
          end
          @logger.info('vagrant-vmware-esxi, connect_esxi: esxi_private_keys: '\
                       "#{config.esxi_private_keys}")

          Net::SSH::Simple.sync(
            user:     config.esxi_username,
            password: config.esxi_password,
            port:     config.esxi_hostport,
            keys:     config.esxi_private_keys
          ) do

            r = ssh config.esxi_hostname,
                    'esxcli system version get | grep Version:'
            if (!r.stdout.include? 'Version:') || (r.exit_code != 0)
              raise Errors::ESXiConfigError,
                    message: "Unable to access ESXi host.\n"\
                             'Verify esxi_hostname, esxi_hostport, '\
                             'esxi_username, esxi_password in your Vagrantfile.'
            end
          end
          @logger.info('vagrant-vmware-esxi, connect_esxi: connect success...')
        end
      end
    end
  end
end
