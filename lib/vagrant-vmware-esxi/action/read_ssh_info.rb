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

          #  most of the time, state will be nil.   But that's OK, we need to
          #  continue to read_ssh_info...
          if (env[:machine_state].to_s == 'not_created' ||
             env[:machine_state].to_s == 'powered_off' ||
             env[:machine_state].to_s == 'suspended')
             config.saved_ipaddress = nil
             return nil
           end

          @logger.info("vagrant-vmware-esxi, read_ssh_info: machine id: #{machine.id}")
          @logger.info('vagrant-vmware-esxi, read_ssh_info: current state:'\
                       " #{env[:machine_state]}")

          if config.saved_ipaddress.nil? or config.local_use_ip_cache == 'False'

            #  Figure out vm_ipaddress
            Net::SSH.start(config.esxi_hostname, config.esxi_username,
              password:                   config.esxi_password,
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

              #  Some OS's don't like above method, so use IP from summary (after 120 seconds uptime)
              r2 = ''
              if r.length == 0
                ssh_execute_cmd = "vim-cmd vmsvc/get.summary #{machine.id} 2>/dev/null |"
                ssh_execute_cmd << 'grep "uptimeSeconds ="|sed "s/^.*= //g"|sed s/,//g'
                uptime = ssh.exec!(ssh_execute_cmd)
                if uptime.to_i > 120
                  puts "Get IP alt method, uptime: #{uptime.to_i}" if config.debug =~ %r{ip}i
                  ssh_execute_cmd = "vim-cmd vmsvc/get.guest #{machine.id} 2>/dev/null |"
                  ssh_execute_cmd << 'grep "^   ipAddress = "|head -1|'
                  ssh_execute_cmd << 'grep -oE "((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])"'
                  r2 = ssh.exec!(ssh_execute_cmd)
                  ipaddress = r2.strip
                end
              end

              puts "ip1 (pri):#{r.strip} ip2 (alt):#{r2.strip}" if config.debug =~ %r{ip}i

              return nil if (ipaddress == '')

              config.saved_ipaddress = ipaddress

              return {
                host: ipaddress,
                port: 22
              }
            end
          else
            puts "Using cached guest IP address" if config.debug =~ %r{ip}i
            ipaddress = config.saved_ipaddress

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
