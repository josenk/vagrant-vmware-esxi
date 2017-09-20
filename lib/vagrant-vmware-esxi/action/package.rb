require 'log4r'
require 'net/ssh/simple'
require 'fileutils'

module VagrantPlugins
  module ESXi
    module Action
      # This action will save (create) a new snapshot
      class Package
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::package')
          env['package.files'] ||= {}
          env['package.output'] ||= 'package'
        end

        def call(env)
          suspend(env)
          @app.call(env)
        end

        def suspend(env)
          @logger.info('vagrant-vmware-esxi, package: start...')

          # Get config.
          machine = env[:machine]
          config = env[:machine].provider_config

          @logger.info("vagrant-vmware-esxi, package: machine id: #{machine.id}")
          @logger.info("vagrant-vmware-esxi, package: current state: #{env[:machine_state]}")

          if env[:machine_state].to_s != 'powered_off'
           env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                message: 'Cannot package in this state, must '\
                                         'be powered off.')
          else
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: 'Attempting to package')

            if (config.allow_overwrite =~ %r{true}i) ||
               (config.allow_overwrite =~ %r{yes}i)
              overwrite_opts = '--overwrite'
            else
              overwrite_opts = nil
            end

            boxname = env['package.output'].gsub('/', '-VAGRANTSLASH-')
            tmpdir = "ZZZZ_tmpdir"
            Dir.mkdir(tmpdir) unless File.exists?(tmpdir)

            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "boxname: #{boxname}.box")

            if File.exists?("#{boxname}.box") && overwrite_opts.nil?
              raise Errors::GeneralError,
                    message: "#{boxname}.box already exists.  Set \n"\
                             "  allow_overwrite='True' in Vagrantfile for force."
            end

            # Find a tar/bsdtar
            if system 'tar --version >/dev/null 2>&1'
              tar_cmd = 'tar'
            elsif system 'bsdtar --version >/dev/null 2>&1'
              tar_cmd = 'bsdtar'
            else
              raise Errors::ESXiConfigError,
                    message: 'unable to find tar in your path.'
            end

            # Check if user files and Vagrantfile exists
            if env['package.include']
              env['package.include'].each do |f|
                unless File.exists?(f)
                  raise Errors::GeneralError,
                        message: "file not found #{f}"
                end
              end
            end
            if env['package.vagrantfile']
              unless File.exists?(env['package.vagrantfile'])
                raise Errors::GeneralError,
                      message: "file not found #{env['package.vagrantfile']}"
              end
            end

            #
            # Using ovftool, import vmx in box folder, export to ESXi server
            #
            unless system 'ovftool --version'
              raise Errors::OVFToolError,
                    message: 'ovftool not found or not in your path.'\
                             "  Please download and "\
                             '  install from http://www.vmware.com.'
            end

            ovf_cmd = "ovftool --noSSLVerify -tt=VMX --name=\"#{boxname}\" "\
                      "#{overwrite_opts} vi://#{config.esxi_username}:"\
                      "#{config.esxi_password}@#{config.esxi_hostname}"\
                      "?moref=vim.VirtualMachine:#{machine.id} #{tmpdir}"

            unless system "#{ovf_cmd}"
              raise Errors::OVFToolError, message: ''
            end

            #  Add user files, Vagrantfile & metadata
            if env['package.include']
              env['package.include'].each do |f|
                env[:ui].info("Including user file: #{f}")
                FileUtils.cp(f, "#{tmpdir}/#{boxname}/")
              end
            end
            if env['package.vagrantfile']
              env[:ui].info('Including user Vagrantfile')
              FileUtils.cp(env['package.vagrantfile'], "#{tmpdir}/#{boxname}/")
            end
            #  Add metadata.json
            File.open("#{tmpdir}/#{boxname}/metadata.json", "w") do |f|
              unless f.write('{"provider":"vmware"}')
                raise Errors::GeneralError, message: 'cannot create metadata.json'
              end
            end

            env[:ui].info("tarring #{boxname}.box")
            unless system "cd #{tmpdir}/#{boxname} ; #{tar_cmd} cvf ../../#{boxname}.box *"
              raise Errors::GeneralError,
                    message: 'tar command failed.'
            end

            env[:ui].info("Doing cleanup.")
            unless FileUtils.rm_r tmpdir
              raise Errors::GeneralError,
                    message: "unable to remove tmpdir. (#{tmpdir})"
            end
          end
        end
      end
    end
  end
end
