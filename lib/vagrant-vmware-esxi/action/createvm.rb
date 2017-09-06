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
                    'esxcli storage filesystem list | '\
                    'grep "/vmfs/volumes/.*true  VMFS" | sort -nk7'

            availvolumes = r.stdout.dup
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

            for line in availvolumes.each_line do
              if line =~ %r{ #{desired_ds} }
                guestvm_ds = line.split(' ')[0].to_s
                guestvm_dsname = line.split(' ')[1]
                break
              end
              guestvm_ds = line.split(' ')[0].to_s
              guestvm_dsname = line.split(' ')[1]
            end

            if (guestvm_dsname != desired_ds) &&
               !config.vm_disk_store.nil?
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'WARNING       : '\
                                            "#{config.vm_disk_store} not "\
                                            "found, using #{guestvm_dsname}.")
            end

            dst_dir = "#{guestvm_ds}/#{guestvm_vmname}"
            @logger.info("vagrant-vmware-esxi, createvm: dst_dir: #{dst_dir}")
            @logger.info('vagrant-vmware-esxi, createvm: '\
                         "guestvm_dsname: #{guestvm_dsname}")

            #
            #  Figure out network
            #
            r = ssh config.esxi_hostname,
                    'esxcli network vswitch standard list |'\
                    'grep Portgroups | sed "s/^   Portgroups: //g" |'\
                    'sed "s/,.*$//g"'
            availnetworks = r.stdout.dup
            if (availnetworks == '') || (r.exit_code != 0)
              raise Errors::ESXiError,
                    message: "Unable to get list of Virtual Networks:\n"\
                             "#{r.stderr}"
            end

            guestvm_network = nil
            availnetworkslist = availnetworks.dup
            for line in availnetworks.each_line do
              if line =~ %r{#{config.virtual_network}}
                guestvm_network = config.virtual_network
              end
            end

            if guestvm_network.nil?
              raise Errors::ESXiConfigError,
                    message: "You MUST specify a valid virtual network.\n"\
                             "virtual_network (#{config.virtual_network}).\n"\
                             "Available Virtual Networks:\n#{availnetworkslist}"
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
              elsif line.match(/^ethernet0.networkName =/i)
                new_vmx_contents << "ethernet0.networkName = \"#{guestvm_network}\"\n"
              elsif line.match(/^ethernet0.addressType =.*static/i)
                new_vmx_contents << 'ethernet0.addressType = \"generated\"'
              elsif line.match(/^ethernet[1-9]/i) ||
                    line.match(/^ethernet0.address = /i) ||
                    line.match(/^ethernet0.generatedAddress = /i) ||
                    line.match(/^ethernet0.generatedAddressOffset = /i)
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

            unless new_vmx_contents =~ %r{^ethernet0.networkName =}i
              new_vmx_contents << "ethernet0.networkName = \"#{guestvm_network}\"\n"
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
                                 message: "NetworkName     : \"#{guestvm_network}\"")
            unless overwrite_opts.nil?
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'Allow Overwrite : True')
            end
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Resource Pool   : #{resource_pool}")
            #
            # Using ovftool, import vmx in box folder, export to ESXi server
            #
            unless system 'ovftool --version'
              raise Errors::ESXiConfigError,
                    message: 'ovftool not found or not in your path.'\
                             "  Please download and "\
                             '  install from http://www.vmware.com.'
            end
            ovf_cmd = "ovftool --noSSLVerify #{overwrite_opts} "\
                  "-nw=\"#{guestvm_network}\" -dm=thin --powerOn "\
                  "-ds=\"#{guestvm_dsname}\" --name=\"#{guestvm_vmname}\" "\
                  "\"#{new_vmx_file}\" vi://#{config.esxi_username}:"\
                  "#{config.esxi_password}@#{config.esxi_hostname}"\
                  "#{resource_pool}"

            #  Security bug if unremarked! Password will be exposed in log file.
            #  @logger.info("vagrant-vmware-esxi, createvm: ovf_cmd #{ovf_cmd}")
            unless system "#{ovf_cmd}"
              raise Errors::ESXiConfigError, message: 'Error with ovftool...'
            end

            # VMX file is not needed any longer
            File.delete(new_vmx_file)

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
