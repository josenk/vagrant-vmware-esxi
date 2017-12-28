require 'log4r'
require 'net/ssh/simple'

module VagrantPlugins
  module ESXi
    module Action
      # This action connects to the ESXi, verifies credentials and
      # validates if it's a ESXi host
      class CreateVM
        def initialize(app, _env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::createvm')
        end

        def call(env)
          createvm(env)
          @app.call(env)
        end

        def createvm(env)
          @logger.info('vagrant-vmware-esxi, createvm: start...')

          # Get config.
          machine = env[:machine]
          config = env[:machine].provider_config

          if env[:machine_state].to_s == 'not_created'
            env[:ui].info I18n.t('vagrant_vmware_esxi.vmbuild_not_done')
          else
            env[:ui].info I18n.t('vagrant_vmware_esxi.vmbuild_already_done')
            return
          end

          # Set guestvm_vmname
          if !env[:machine].config.vm.hostname.nil?
            # A hostname has been set, so use it.
            guestvm_vmname = env[:machine].config.vm.hostname
          elsif config.vmname.nil?
            #  Nothing set, so generate our own
            guestvm_vmname = config.vmname_prefix.strip
            guestvm_vmname << `hostname`.partition('.').first.strip
            guestvm_vmname << '-'
            guestvm_vmname << `whoami`.gsub!(/[^0-9A-Za-z]/, '').strip
            guestvm_vmname << '-'
            base = File.basename machine.env.cwd.to_s
            guestvm_vmname << base
            config.vmname = guestvm_vmname
          else
            # A vmname has been set, so use it.
            guestvm_vmname = config.vmname
          end
          @logger.info("vagrant-vmware-esxi, createvm: config.vmname: #{config.vmname}")

          #
          #  Source vmx / vmdk files
          src_dir = env[:machine].box.directory
          @logger.info("vagrant-vmware-esxi, createvm: src_dir: #{src_dir}")

          vmx_file = Dir.glob("#{src_dir}/*.vmx").first
          vmdk_files = Dir.glob("#{src_dir}/*.vmdk")
          @logger.info("vagrant-vmware-esxi, createvm: vmx_file: #{vmx_file}")
          @logger.info("vagrant-vmware-esxi, createvm: vmdk_files: #{vmdk_files}")

          #
          #  Open the network connection
          #
          Net::SSH::Simple.sync(
            user:     config.esxi_username,
            password: config.esxi_password,
            port:     config.esxi_hostport,
            keys:     config.esxi_private_keys
          ) do

            @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::createvm-ssh')

            #
            #  Figure out DataStore
            r = ssh config.esxi_hostname,
                    'df | grep "^[VMFS|NFS]" | sort -nk4 |'\
                    'sed "s|.*/vmfs/volumes/||g" | tail +2'

            availvolumes = r.stdout.dup.split(/\n/)
            if (config.debug =~ %r{true}i) ||
               (config.debug =~ %r{yes}i)
               puts "Available DS Volumes: #{availvolumes}"
            end
            if (r == '') || (r.exit_code != 0)
              raise Errors::ESXiError,
                    message: 'Unable to get list of Disk Stores:'
            end

            #  Use least-used if vm_disk_store is not set (or not found)
            if config.vm_disk_store.nil?
              desired_ds = '--- Least Used ---'
            else
              desired_ds = config.vm_disk_store.to_s
            end

            if availvolumes.include? desired_ds
              guestvm_dsname = desired_ds
            else
              guestvm_dsname = availvolumes.last
            end

            if (guestvm_dsname != desired_ds) &&
               !config.vm_disk_store.nil?
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'WARNING         : '\
                                            "#{config.vm_disk_store} not "\
                                            "found, using #{guestvm_dsname}")
            end

            @logger.info('vagrant-vmware-esxi, createvm: '\
                         "guestvm_dsname: #{guestvm_dsname}")

            #
            #  Figure out network
            #
            r = ssh config.esxi_hostname,
                    'esxcli network vswitch standard list |'\
                    'grep Portgroups | sed "s/^   Portgroups: //g" |'\
                    'sed "s/,./\n/g"'
            availnetworks = r.stdout.dup.split(/\n/)
            if (config.debug =~ %r{true}i) ||
               (config.debug =~ %r{yes}i)
               puts "Available Networks: #{availnetworks}"
            end
            if (availnetworks == '') || (r.exit_code != 0)
              raise Errors::ESXiError,
                    message: "Unable to get list of Virtual Networks:\n"\
                             "#{r.stderr}"
            end

            guestvm_network = []
            counter = 0
            if config.virtual_network.nil?
              guestvm_network[0] = availnetworks.first
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                    message: 'WARNING         : '\
                                             "config.virtual_network not "\
                                             "set, using #{availnetworks.first}")
            else
              networkID = 0
              for aVirtNet in Array(config.virtual_network) do
                if availnetworks.include? aVirtNet
                  guestvm_network << aVirtNet
                else
                  guestvm_network << availnetworks.first
                  env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                       message: 'WARNING         : '\
                                                "#{aVirtNet} not "\
                                                "found, using #{availnetworks.first}")
                end
                networkID += 1
                if networkID >= 4
                  break
                end
              end
            end

            @logger.info('vagrant-vmware-esxi, createvm: '\
                         "virtual_network: #{guestvm_network}")

            #   finalize some paramaters
            if (config.memsize.is_a? String) || (config.memsize.is_a? Integer)
              desired_memsize = config.memsize.to_s.to_i
            end
            if (config.numvcpus.is_a? String) || (config.numvcpus.is_a? Integer)
              desired_numvcpus = config.numvcpus.to_s.to_i
            end

            #
            #   Fix/clean up vmx file.
            #
            new_vmx_contents = ''
            File.readlines(vmx_file).each do |line|

              if line.match(/^displayname =/i)
                new_vmx_contents << "displayname = \"#{guestvm_vmname}\"\n"
              elsif line.match(/^memsize =/i) && (!desired_memsize.nil?)
                new_vmx_contents << "memsize = \"#{desired_memsize}\"\n"
              elsif line.match(/^numvcpus =/i) && (!desired_numvcpus.nil?)
                new_vmx_contents << "numvcpus = \"#{desired_numvcpus}\"\n"
              elsif line.match(/^ethernet[0-9].networkName =/i) ||
                    line.match(/^ethernet[0-9].addressType =/i) ||
                    line.match(/^ethernet[0-9].present =/i) ||
                    line.match(/^ethernet[0-9].address =/i) ||
                    line.match(/^ethernet[0-9].generatedAddress =/i) ||
                    line.match(/^ethernet[0-9].generatedAddressOffset =/i)
                # Do nothing, delete these lines
              else
                new_vmx_contents << line
              end
            end

            #  finalize vmx.
            unless new_vmx_contents =~ %r{^numvcpus =}i
              if desired_numvcpus.nil?
                new_vmx_contents << "numvcpus = \"1\"\n"
              else
                new_vmx_contents << "numvcpus = \"#{desired_numvcpus}\"\n"
              end
            end

            #unless new_vmx_contents =~ %r{^ethernet0.networkName =}i
            #  new_vmx_contents << "ethernet0.networkName = \"#{guestvm_network}\"\n"
            #end
            netOpts = ""
            networkID = 0
            for element in guestvm_network do
              if (config.debug =~ %r{true}i) ||
                 (config.debug =~ %r{yes}i)
                puts "guestvm_network[#{networkID}]: #{element}"
              end
              new_vmx_contents << "ethernet#{networkID}.networkName = \"net#{networkID}\"\n"
              new_vmx_contents << "ethernet#{networkID}.present = \"TRUE\"\n"
              new_vmx_contents << "ethernet#{networkID}.addressType = \"generated\"\n"
              netOpts << " --net:\"net#{networkID}=#{element}\""
              networkID += 1
              if networkID >= 4
                break
              end
            end

            if config.custom_vmx_settings.is_a? Array
              env[:machine].provider_config.custom_vmx_settings.each do |k, v|
                new_vmx_contents << "#{k} = \"#{v}\"\n"
              end
            end

            #  Write new vmx file
            filename_only = File.basename vmx_file, '.vmx'
            path_only = File.dirname vmx_file
            new_vmx_file = "#{path_only}/ZZZZ_#{guestvm_vmname}.vmx"

            File.open(new_vmx_file, 'w') { |file|
              file.write(new_vmx_contents)
              file.close
            }

            #
            #  Check if using a Resource Pool
            if config.resource_pool.is_a? String
              if config.resource_pool =~ %r{^\/}
                resource_pool = config.resource_pool
              else
                resource_pool = '/'
                resource_pool << config.resource_pool
              end
            else
              resource_pool = ''
            end

            if (config.allow_overwrite =~ %r{true}i) ||
               (config.allow_overwrite =~ %r{yes}i)
              overwrite_opts = '--overwrite --powerOffTarget'
            else
              overwrite_opts = nil
            end

            #
            #  Display build summary
            numvcpus = new_vmx_contents.match(/^numvcpus =.*/i)
                       .to_s.gsub(/^numvcpus =/i, '').gsub(/\"/, '')
            memsize = new_vmx_contents.match(/^memsize =.*/i)
                      .to_s.gsub(/^memsize =/i, '').gsub(/\"/, '')
            guestOS = new_vmx_contents.match(/^guestOS =.*/i)
                      .to_s.gsub(/^guestOS =/i, '').gsub(/\"/, '')
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "ESXi host       : #{config.esxi_hostname}")
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "VM Name         : #{guestvm_vmname}")
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "CPUS            :#{numvcpus}")
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Memsize (MB)    :#{memsize}")
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Guest OS type   :#{guestOS}")
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Disk Store      : #{guestvm_dsname}")
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "NetworkName     : #{guestvm_network[0..3]}")
            unless overwrite_opts.nil?
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'Allow Overwrite : True')
            end
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Resource Pool   : #{resource_pool}")
            #
            #  Encode special characters in PW
            #
            encoded_esxi_password = config.esxi_password.gsub('@', '%40').gsub(\
              '<', '%3c').gsub('>', '%3e').gsub(\
              '[', '%5b').gsub(']', '%5d').gsub(\
              '(', '%28').gsub(')', '%29').gsub(\
              '%', '%25').gsub('#', '%23').gsub(\
              '&', '%26').gsub(':', '%3a').gsub(\
              '/', '%2f').gsub('\\','%5c').gsub(\
              '"', '%22').gsub('\'','%27').gsub(\
              '*', '%2a').gsub('?', '%3f')


            #
            # Using ovftool, import vmx in box folder, export to ESXi server
            #
            unless system 'ovftool --version'
              raise Errors::OVFToolError,
                    message: 'ovftool not found or not in your path.'\
                             "  Please download and "\
                             '  install from http://www.vmware.com.'
            end
            ovf_cmd = "ovftool --noSSLVerify #{overwrite_opts} "\
                  "#{netOpts} -dm=thin --powerOn "\
                  "-ds=\"#{guestvm_dsname}\" --name=\"#{guestvm_vmname}\" "\
                  "\"#{new_vmx_file}\" vi://#{config.esxi_username}:"\
                  "#{encoded_esxi_password}@#{config.esxi_hostname}"\
                  "#{resource_pool}"

            #  Security bug if unremarked! Password will be exposed in log file.
            #  @logger.info("vagrant-vmware-esxi, createvm: ovf_cmd #{ovf_cmd}")
            if (config.debug =~ %r{true}i) ||
               (config.debug =~ %r{yes}i)
               puts "ovftool command: #{ovf_cmd}"
            end
            unless system "#{ovf_cmd}"
              raise Errors::OVFToolError, message: ''
            end

            # VMX file is not needed any longer
            if (config.debug =~ %r{true}i) ||
               (config.debug =~ %r{yes}i)
               puts "Keeping file: #{new_vmx_file}"
             else
               File.delete(new_vmx_file)
             end

            r = ssh config.esxi_hostname,
                    'vim-cmd vmsvc/getallvms |'\
                    "grep \" #{guestvm_vmname} \"|awk '{print $1}'"
            vmid = r.stdout
            if (vmid == '') || (r.exit_code != 0)
              raise Errors::ESXiError,
                    message: "Unable to register / start #{guestvm_vmname}"
            end

            env[:machine].id = vmid.to_i
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "VMID: #{env[:machine].id}")
          end
        end
      end
    end
  end
end
