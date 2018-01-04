require 'log4r'
require 'net/ssh'

module VagrantPlugins
  module ESXi
    module Action
      # This action will get the SSH "availability".
      class ReadSSHInfo
        def initialize(app, _env)
          @app = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::read_ssh_info')
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env)
          @app.call(env)
        end

        def read_ssh_info(env)
          @logger.info('vagrant-vmware-esxi, read_ssh_info: start...')

          # Get config.
          machine = env[:machine]
          config = env[:machine].provider_config

          return nil if machine.id.nil?

          @logger.info("vagrant-vmware-esxi, read_ssh_info: machine id: #{machine.id}")
          @logger.info('vagrant-vmware-esxi, read_ssh_info: current state:'\
                       " #{env[:machine_state]}")

          #  Figure out vm_ipaddress
          Net::SSH.start( config.esxi_hostname, config.esxi_username,
            password:                   $esxi_password,
            port:                       config.esxi_hostport,
            keys:                       config.esxi_private_keys,
            timeout:                    10,
            number_of_password_prompts: 0,
            non_interactive:            true
          ) do |ssh|

            @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::'\
                                        'read_ssh_info-net_ssh')

            #  ugly, but it works...
            ssh_execute_cmd = "vim-cmd vmsvc/get.guest #{machine.id} |"
            ssh_execute_cmd << 'grep -i "^   ipAddress"|'
            ssh_execute_cmd << 'grep -oE "((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])"'
            r = ssh.exec!(ssh_execute_cmd)

            ipaddress = r.strip
            @logger.info('vagrant-vmware-esxi, read_ssh_info: ipaddress: '\
                         "#{ipaddress}")

            return nil if (ipaddress == '') || (r.exitstatus != 0)

            return {
              host: ipaddress,
              port: 22
            }
          end
        end
      end
    end
  end
end
