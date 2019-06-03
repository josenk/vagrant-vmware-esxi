require 'log4r'
require 'net/ssh'
require 'io/console'

module VagrantPlugins
  module ESXi
    module Action
      # This action set the global variable esxi_password and attempt to
      # login to the esxi server to verify connectivity.
      class SetESXiPassword
        def initialize(app, _env)
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
          config = env[:machine].provider_config

          #
          #  Set global variable config.esxi_password
          #
          if config.encoded_esxi_password.nil?
            if config.esxi_password =~ %r{^prompt:}i
              #
              #  Prompt for password
              #
              password_type = 'prompt'
              begin
                print "#{config.esxi_username}@#{config.esxi_hostname} password:"
                config.esxi_password = STDIN.noecho(&:gets).chomp
                puts ''
              rescue
                begin
                  #  There is something funky with STDIN... (unsupported console)
                  puts ''
                  puts ''
                  puts 'Error! Your console doesn\'t support hiding input. We\'ll ask for'
                  puts 'input again below, but we WILL NOT be able to hide input. If this'
                  puts 'is a problem for you, ctrl-C / [ENTER] to exit and fix your stdin.'
                  puts ''
                  print "#{config.esxi_username}@#{config.esxi_hostname} password:"
                  config.esxi_password = $stdin.readline().chomp
                  puts ''
                rescue
                  raise Errors::ESXiError,
                        message: 'Prompt for password error???'
                end
              end
            elsif config.esxi_password =~ %r{^env:}i
              #
              #  Get pw from environment variable
              #
              password_type = 'env'
              esxi_password_env = config.esxi_password.gsub(/env:/i, '').chomp
              if esxi_password_env.length < 1
                esxi_password_env = 'esxi_password'
              end
              begin
                stdin_pw = ENV[esxi_password_env]
                config.esxi_password = stdin_pw.chomp
              rescue
                raise Errors::ESXiError,
                      message: "Unable to read environment variable: #{esxi_password_env}"
              end
            elsif config.esxi_password =~ %r{^file:}i
              #
              #  Get password from file
              #
              password_type = 'file'
              esxi_password_file = config.esxi_password.gsub(/file:/i, '').chomp
              if esxi_password_file.empty?
                esxi_password_file = '~/.esxi_password'
              end
              esxi_password_file = File.expand_path(esxi_password_file)
              #  Get password from file
              begin
                if File.file?(esxi_password_file)
                  file_pw = ''
                  fh = File.open(File.expand_path(esxi_password_file))
                  file_pw = fh.readline
                  fh.close
                  config.esxi_password = file_pw.chomp
                else
                  raise Errors::ESXiError, message: "Unable to open #{esxi_password_file}"
                end
              rescue
                raise Errors::ESXiError, message: "Unable to open #{esxi_password_file}"
              end
            elsif config.esxi_password =~ %r{^key:}i
              #
              #  use ssh keys
              #
              password_type = 'key'
              esxi_password_key = config.esxi_password.gsub(/key:/i, '').chomp
              config.esxi_password = ''
              unless esxi_password_key.empty?
                config.local_private_keys = esxi_password_key
              end
            else
              # Use plain text password from config
              password_type = 'plain'
            end

            #
            #  Encode special characters in PW
            #
            config.encoded_esxi_password = config.esxi_password.gsub('%', '%25').\
              gsub(' ', '%20').\
              gsub('!', '%21').\
              gsub('"', '%22').\
              gsub('#', '%23').\
              gsub('$', '%24').\
              gsub('&', '%26').\
              gsub('\'','%27').\
              gsub('(', '%28').\
              gsub(')', '%29').\
              gsub('*', '%2a').\
              gsub('+', '%2b').\
              gsub(',', '%2c').\
              gsub('-', '%2d').\
              gsub('.', '%2e').\
              gsub('/', '%2f').\
              gsub(':', '%3a').\
              gsub(';', '%3b').\
              gsub('<', '%3c').\
              gsub('=', '%3d').\
              gsub('>', '%3e').\
              gsub('?', '%3f').\
              gsub('@', '%40').\
              gsub('[', '%5b').\
              gsub('\\','%5c').\
              gsub(']', '%5d').\
              gsub('^', '%5e').\
              gsub('_', '%5f').\
              gsub('`', '%60').\
              gsub('{', '%7b').\
              gsub('|', '%7c').\
              gsub('}', '%7d').\
              gsub('~', '%7e')

            @logger.info('vagrant-vmware-esxi, connect_esxi: local_private_keys: '\
                         "#{config.local_private_keys}")

            #
            #  Test ESXi host connectivity
            #
            begin
              puts "RUBY_PLATFORM: #{RUBY_PLATFORM}" if config.debug =~ %r{true}i
              puts "Testing esxi connectivity" if config.debug =~ %r{ip}i
              puts "esxi_ssh_keys: #{config.local_private_keys}" if config.debug =~ %r{password}i
              Net::SSH.start(config.esxi_hostname, config.esxi_username,
                password:                   config.esxi_password,
                port:                       config.esxi_hostport,
                keys:                       config.local_private_keys,
                timeout:                    20,
                number_of_password_prompts: 0,
                non_interactive:            true
              ) do |ssh|

                esxi_version = ssh.exec!('vmware -v')
                ssh.close

                @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::set_esxi_password')
                if (config.debug =~ %r{true}i) && $showVersionFlag.nil?
                  $showVersionFlag = true
                  env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                       message: "ESXi version    : #{esxi_version}")
                end
                if esxi_version !~ %r{^vmware esxi}i
                  @logger.info('vagrant-vmware-esxi, set_esxi_password: '\
                               "ESXi version: #{esxi_version}")
                  raise Errors::ESXiError,
                        message: 'Unable to connect to ESXi host!'\
                                "Error: #{esxi_version}"
                end
              end
            rescue
              if password_type == 'prompt'
                access_error_message = 'Password incorrect.'
              elsif password_type == 'env'
                access_error_message = "Verify env:#{esxi_password_env}"
              elsif password_type == 'file'
                access_error_message = "Verify file:#{esxi_password_file}"
              elsif password_type == 'key'
                access_error_message = "Verify key:#{config.local_private_keys}"
              else
                access_error_message = 'Verify password in Vagrantfile is correct.'
              end

              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: "ESXi host access : #{access_error_message}")

              @logger.info('vagrant-vmware-esxi, set_esxi_password: '\
                          "ESXi host access : #{access_error_message}")

              raise Errors::ESXiError,
                    message: 'Unable to connect to ESXi host!'
            end
          end
        end
      end
    end
  end
end
