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

          if (env[:machine_state].to_s == 'not_created' ||
             env[:machine_state].to_s == 'powered_off' ||
             env[:machine_state].to_s == 'suspended')
             return nil
           end

          @logger.info("vagrant-vmware-esxi, read_ssh_info: machine id: #{machine.id}")
          @logger.info('vagrant-vmware-esxi, read_ssh_info: current state:'\
                       " #{env[:machine_state]}")

          #  Figure out vm_ipaddress
          Net::SSH.start(config.esxi_hostname, config.esxi_username,
            password:                   $esxi_password,
            port:                       config.esxi_hostport,
            keys:                       config.local_private_keys,
            timeout:                    20,
            number_of_password_prompts: 0,
            non_interactive:            true
          ) do |ssh|

            @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::'\
                                        'read_ssh_info-net_ssh')

            #  ugly, but it works...
            #    Try to get first interface.  This is the prefered method
            #    when you have multiple network interfaces
            ssh_execute_cmd = "vim-cmd vmsvc/get.guest #{machine.id} 2>/dev/null |"
            ssh_execute_cmd << 'grep -A 5 "deviceConfigId = 4000" |tail -1|'
            ssh_execute_cmd << 'grep -oE "((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])"'
            r = ssh.exec!(ssh_execute_cmd)
            ipaddress = r.strip

            #  Some OS's don't like above method, so use IP from summary (after 60 seconds uptime)
            ssh_execute_cmd = "vim-cmd vmsvc/get.guest #{machine.id} 2>/dev/null |"
            ssh_execute_cmd << 'grep "^   ipAddress = "|head -1|'
            ssh_execute_cmd << 'grep -oE "((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])"'
            r2 = ssh.exec!(ssh_execute_cmd)

            ssh_execute_cmd = "vim-cmd vmsvc/get.summary #{machine.id} 2>/dev/null |"
            ssh_execute_cmd << 'grep "uptimeSeconds ="|sed "s/^.*= //g"|sed s/,//g'
            uptime = ssh.exec!(ssh_execute_cmd)

            if ( r.length == 0 && uptime.to_i > 120)
              ipaddress = r2.strip
            else
              ipaddress = r.strip
            end

            if (config.debug =~ %r{ip}i)
              puts "ip1 (prim):#{r.strip} ip2 (alt):#{r2.strip}  Final: #{ipaddress}"
            end

            return nil if (ipaddress == '')

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
