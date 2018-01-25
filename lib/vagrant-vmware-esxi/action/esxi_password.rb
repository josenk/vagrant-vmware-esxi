require 'log4r'
require 'net/ssh'
require 'io/console'

module VagrantPlugins
  module ESXi
    module Action
      # This action set the global variable esxi_password and attempt to
      # login to the esxi server to verify connectivity.
      class SetESXiPassword
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::set_esxi_password')
        end

        def call(env)
          set_esxi_password(env)
          @app.call(env)
        end

        def set_esxi_password(env)
          @logger.info('vagrant-vmware-esxi, set_esxi_password: start...')

          # Get config.
          machine = env[:machine]
          config = env[:machine].provider_config

          #
          #  Set global variable $esxi_password
          #
          if $esxi_password.nil?
            if (config.esxi_password =~ %r{^prompt:}i)
              #
              #  Prompt for password
              #
              begin
                print "#{config.esxi_hostname} password:"
                $esxi_password = STDIN.noecho(&:gets).chomp
                puts ""
              rescue
                raise Errors::ESXiError,
                      message: "Prompt for password error???"
              end
            elsif (config.esxi_password =~ %r{^env:}i)
              #
              #  Get pw from environment variable
              #
              esxi_password_env = config.esxi_password.gsub(/env:/i, '').chomp
              if esxi_password_env.length < 1
                esxi_password_env = 'esxi_password'
              end
              begin
                stdin_pw = ENV[esxi_password_env]
                $esxi_password = stdin_pw.chomp
              rescue
                raise Errors::ESXiError,
                      message: "Unable to read environment variable: #{esxi_password_env}"
              end
            elsif (config.esxi_password =~ %r{^file:}i)
              #
              #  Get password from file
              #
              esxi_password_file = config.esxi_password.gsub(/file:/i, '').chomp
              if esxi_password_file.length < 1
                esxi_password_file = '~/.esxi_password'
              end
              esxi_password_file = File.expand_path(esxi_password_file)
              #  Get password from file
              begin
                if File.file?(esxi_password_file)
                  file_pw=""
                  fh = File.open(File.expand_path(esxi_password_file))
                  file_pw = fh.readline
                  fh.close
                  $esxi_password = file_pw.chomp
                else
                  raise Errors::ESXiError, message: "Unable to open #{esxi_password_file}"
                end
              rescue
                raise Errors::ESXiError, message: "Unable to open #{esxi_password_file}"
              end
            elsif (config.esxi_password =~ %r{^key:}i)
              #
              #  use ssh keys
              #
              $esxi_password = ""
              esxi_password_key = config.esxi_password.gsub(/key:/i, '').chomp
              if esxi_password_key.length < 1
                config.esxi_private_keys = config.system_private_keys_path
              else
                config.esxi_private_keys = esxi_password_key
              end
            else
              # Use plain text password from config
              $esxi_password = config.esxi_password
            end
          end

          #
          #  Encode special characters in PW
          #
          $encoded_esxi_password = $esxi_password.gsub('@', '%40').gsub(\
            '<', '%3c').gsub('>', '%3e').gsub(\
            '[', '%5b').gsub(']', '%5d').gsub(\
            '(', '%28').gsub(')', '%29').gsub(\
            '%', '%25').gsub('#', '%23').gsub(\
            '&', '%26').gsub(':', '%3a').gsub(\
            '/', '%2f').gsub('\\','%5c').gsub(\
            '"', '%22').gsub('\'','%27').gsub(\
            '*', '%2a').gsub('?', '%3f').gsub(\
            '$', '%24')

          @logger.info('vagrant-vmware-esxi, connect_esxi: esxi_private_keys: '\
                       "#{config.esxi_private_keys}")

          #
          #  Test ESXi host connectivity
          #
          begin
            Net::SSH.start( config.esxi_hostname, config.esxi_username,
              password:                   $esxi_password,
              port:                       config.esxi_hostport,
              keys:                       config.esxi_private_keys,
              timeout:                    20,
              number_of_password_prompts: 0,
              non_interactive:            true
            ) do |ssh|

              esxi_version = ssh.exec!("vmware -v")
              ssh.close

              @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::set_esxi_password')
              if esxi_version =~ %r{^vmware esxi}i
                @logger.info('vagrant-vmware-esxi, set_esxi_password: '\
                             "ESXi version: #{esxi_version}")
              else
                @logger.info('vagrant-vmware-esxi, set_esxi_password: '\
                             "ESXi version: #{esxi_version}")
                raise Errors::ESXiError,
                      message: "Unable to connect to ESXi host!"
              end
            end
          rescue
            if (config.esxi_password =~ %r{^prompt:}i)
              access_error_message = "Prompt for password"
            elsif (config.esxi_password =~ %r{^env:}i)
              access_error_message = "env:#{esxi_password_env}"
            elsif (config.esxi_password =~ %r{^file:}i)
              access_error_message = "file:#{esxi_password_file}"
            elsif (config.esxi_password =~ %r{^key:}i)
              access_error_message = "key:#{config.esxi_private_keys}"
            else
              access_error_message = "password in Vagrantfile"
            end

            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "ESXi host access : #{access_error_message}")

            @logger.info('vagrant-vmware-esxi, set_esxi_password: '\
                        "ESXi host access : #{access_error_message}")

            raise Errors::ESXiError,
                  message: "Unable to connect to ESXi host!"
          end
        end
      end
    end
  end
end
