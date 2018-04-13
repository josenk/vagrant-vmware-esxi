require 'log4r'
require 'net/ssh'

module VagrantPlugins
  module ESXi
    module Action
      # This action creates a new vmx file (using overwrides from config file),
      # then creates a new VM guest using ovftool.
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

          #
          # Verify ovftool is installed.
          #
          unless system 'ovftool --version'
            raise Errors::OVFToolError,
                  message: 'ovftool not found or not in your path.'\
                           "  Please download and "\
                           '  install from http://www.vmware.com.'
          end

          # Set desired_guest_name
          if !env[:machine].config.vm.hostname.nil?
            # A hostname has been set, so use it.
            desired_guest_name = env[:machine].config.vm.hostname.dup
          elsif config.guest_name.nil?
            #  Nothing set, so generate our own
            desired_guest_name = config.guest_name_prefix.strip
            desired_guest_name << `hostname`.partition('.').first.strip
            desired_guest_name << '-'
            desired_guest_name << `whoami`.gsub!(/[^0-9A-Za-z]/, '').strip
            desired_guest_name << '-'
            base = File.basename machine.env.cwd.to_s
            desired_guest_name << base
            config.guest_name = desired_guest_name
          else
            # A guest_name has been set, so use it.
            desired_guest_name = config.guest_name.strip
          end
          desired_guest_name = desired_guest_name[0..252].gsub(/_/,'-').gsub(/[^0-9A-Za-z\-\.]/i, '').strip
          @logger.info("vagrant-vmware-esxi, createvm: config.guest_name: #{config.guest_name}")

          #  Source vmx / vmdk files
          src_dir = env[:machine].box.directory
          @logger.info("vagrant-vmware-esxi, createvm: src_dir: #{src_dir}")

          if config.clone_from_vm.nil?
            vmx_file = Dir.glob("#{src_dir}/*.vmx").first
            @logger.info("vagrant-vmware-esxi, createvm: vmx_file: #{vmx_file}")
            source_vmx_contents = File.read(vmx_file)
          else
            begin
              tmpdir = Dir.mktmpdir
            rescue
              raise Errors::GeneralError,
                    message: "Unable to create tmp dir #{tmpdir}"
            end
            #
            #  Source from Clone Source
            clone_from_vm_path = "vi://#{config.esxi_username}:#{$encoded_esxi_password}@#{config.esxi_hostname}/#{config.clone_from_vm}"
            ovf_cmd = "ovftool --noSSLVerify --overwrite --powerOffTarget --noDisks --targetType=vmx "\
                  "#{clone_from_vm_path} #{tmpdir}"
            unless system "#{ovf_cmd}"
              raise Errors::OVFToolError,
                    message: "Unable to access #{config.clone_from_vm}"
            end
            vmx_file = Dir.glob("#{tmpdir}/#{config.clone_from_vm.split('/')[-1]}/*.vmx").first
            unless source_vmx_contents = File.read(vmx_file)
              raise Errors::GeneralError,
                    message: "Unable to read #{vmx_file}"
            end

            puts "source_vmx_contents: #{source_vmx_contents}" if config.debug =~ %r{vmx}i
          end

          #
          #  Open the network connection
          #
          Net::SSH.start( config.esxi_hostname, config.esxi_username,
            password:                   $esxi_password,
            port:                       config.esxi_hostport,
            keys:                       config.local_private_keys,
            timeout:                    20,
            number_of_password_prompts: 0,
            non_interactive:            true
          ) do |ssh|

            @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::createvm-ssh')

            #
            #  Figure out DataStore
            r = ssh.exec!(
                    'esxcli storage filesystem list | grep "/vmfs/volumes/.*[VMFS|NFS]" | '\
                    "sort -nk7 | awk '{print $2}'")

            availvolumes = r.split(/\n/)
            if config.debug =~ %r{true}i
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: "Avail DS vols   : #{availvolumes}")
            end
            if (r == '') || (r.exitstatus != 0)
              raise Errors::ESXiError,
                    message: 'Unable to get list of Disk Stores:'
            end

            #  Use least-used if esxi_disk_store is not set (or not found)
            if config.esxi_disk_store.nil?
              desired_ds = '--- Least Used ---'
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'WARNING         : '\
                                            "esxi_disk_store not set, using "\
                                            "\"--- Least Used ---\"")
            else
              desired_ds = config.esxi_disk_store.to_s
            end

            if availvolumes.include? desired_ds
              @guestvm_dsname = desired_ds
            else
              @guestvm_dsname = availvolumes.last
            end

            if (@guestvm_dsname != desired_ds) &&
               !config.esxi_disk_store.nil?
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'WARNING         : '\
                                            "Disk Store \"#{config.esxi_disk_store}\" not "\
                                            "found, using #{@guestvm_dsname}")
            end

            @logger.info('vagrant-vmware-esxi, createvm: '\
                         "@guestvm_dsname: #{@guestvm_dsname}")

            #
            #  Figure out network
            #
            r = ssh.exec!(
                    'esxcli network vswitch standard list |'\
                    'grep Portgroups | sed "s/^   Portgroups: //g" |'\
                    'sed "s/,./\n/g"')
            availnetworks = r.split(/\n/)
            if config.debug =~ %r{true}i
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: "Avail Networks  : #{availnetworks}")
            end
            if (availnetworks == '') || (r.exitstatus != 0)
              raise Errors::ESXiError,
                    message: "Unable to get list of Virtual Networks:\n"\
                             "#{r.stderr}"
            end

            #   How many vm.network are there?
            vm_network_index = 0
            env[:machine].config.vm.networks.each do |type, options|
              # I only handle private and public networks
              next if type != :private_network && type != :public_network
              vm_network_index += 1
            end

            #  If there is more vm.network than esxi_virtual_network's configured
            #  I need to add more esxi_virtual_networks.  Setting each to ---NotSet---
            #  to give a warning below...
            if vm_network_index >= config.esxi_virtual_network.count
              config.esxi_virtual_network.count.upto(vm_network_index) do |index|
                config.esxi_virtual_network << '--NotSet--'
              end
            end

            #  Go through each esxi_virtual_network and make sure it's good.  If not
            #  display a WARNING that we are choosing the first found.
            @guestvm_network = []
            networkID = 0
            for aVirtNet in Array(config.esxi_virtual_network) do
              if config.esxi_virtual_network == [''] ||
                config.esxi_virtual_network[0] == '--NotSet--'
                #  First (and only ) interface is not configure or not set
                @guestvm_network = [availnetworks.first]
                config.esxi_virtual_network = [availnetworks.first]
                env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                      message: 'WARNING         : '\
                                               "esxi_virtual_network[#{networkID}] not "\
                                               "set, using #{availnetworks.first}")
              elsif availnetworks.include? aVirtNet
                # Network interface is good
                @guestvm_network << aVirtNet
              else
                # Network interface is NOT good.
                @guestvm_network[networkID] = availnetworks.first
                config.esxi_virtual_network[networkID] = availnetworks.first
                if aVirtNet == '--NotSet--'
                  aVirtNet_msg = "esxi_virtual_network[#{networkID}]"
                else
                  aVirtNet_msg = aVirtNet
                end
                env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                     message: 'WARNING         : '\
                                              "#{aVirtNet_msg} not "\
                                              "found, using #{availnetworks.first}")
              end
              networkID += 1
              if networkID >= 4
                break
              end
            end
          end

          @logger.info('vagrant-vmware-esxi, createvm: '\
                       "esxi_virtual_network: #{@guestvm_network}")

          #  Set some defaults
          desired_guest_memsize = config.guest_memsize.to_s.to_i unless config.guest_memsize.nil?
          desired_guest_memsize = 1024 if desired_guest_memsize.nil?

          desired_guest_numvcpus = config.guest_numvcpus.to_s.to_i unless config.guest_numvcpus.nil?
          desired_guest_numvcpus = 1 if desired_guest_numvcpus.nil?

          unless config.guest_guestos.nil?
            if config.supported_guest_guestos.include? config.guest_guestos.downcase
              desired_guestos = config.guest_guestos.downcase.strip
            else
              config.guest_guestos = nil
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'WARNING         : '\
                                            "GuestOS: #{config.guest_guestos} not "\
                                            "supported, using box/ovftool defaults")
            end
          end

          unless config.guest_virtualhw_version.nil?
            if config.supported_guest_virtualhw_versions.include? config.guest_virtualhw_version.to_i
              desired_virtualhw_version = config.guest_virtualhw_version.to_i.to_s
            else
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                    message: 'WARNING         : '\
                                             "Invalid guest_virtualhw_version: #{config.guest_virtualhw_version},"\
                                             "using ovftool defaults")
              config.guest_virtualhw_version = nil
            end
          end

          unless config.guest_nic_type.nil?
            if config.supported_guest_nic_types.include? config.guest_nic_type.downcase
              desired_nic_type = config.guest_nic_type.downcase
            else
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'WARNING         : '\
                                            "NIC type: #{config.guest_nic_type} not "\
                                            "found, using ovftool defaults.")
              config.guest_nic_type = nil
            end
          end

          #
          #   Fix/clean up vmx file.
          #
          new_vmx_contents = ''
          source_vmx_contents.each_line do |line|

            case line
            when /^displayname =/i
              new_vmx_contents << "displayname = \"#{desired_guest_name}\"\n"

            when /^memsize =/i
              if config.guest_memsize.nil?
                desired_guest_memsize = line.gsub(/^memsize = /i, '').gsub(/\"/, '').to_i
              end
              new_vmx_contents << "memsize = \"#{desired_guest_memsize}\"\n"

            when /^numvcpus =/i
              if config.guest_numvcpus.nil?
                desired_guest_numvcpus = line.gsub(/^numvcpus = /i, '').gsub(/\"/, '').to_i
              end
              new_vmx_contents << "numvcpus = \"#{desired_guest_numvcpus}\"\n"

            when /^guestOS = /i
              if config.guest_guestos.nil?
                desired_guestos = line.gsub(/^guestOS = /i, '').gsub(/\"/, '').strip
                new_vmx_contents << line
              else
                new_vmx_contents << "guestOS = \"#{desired_guestos}\"\n"
              end

            when /^virtualHW.version = /i
              if desired_virtualhw_version.nil?
                desired_virtualhw_version = line.gsub(/^virtualHW.version = /i, '').gsub(/\"/, '').strip
                new_vmx_contents << line
              else
                new_vmx_contents << "virtualHW.version = \"#{desired_virtualhw_version}\"\n"
              end

            when /^ethernet[0-9]/i
              # Just save the nic type
              if (line =~ /ethernet0.virtualDev = /i) and desired_nic_type.nil?
                desired_nic_type = line.gsub(/ethernet0.virtualDev = /i, '').gsub('"', '').strip
              end

            else
              new_vmx_contents << line
            end

          end

          #  finalize vmx.
          unless new_vmx_contents =~ %r{^numvcpus =}i
            new_vmx_contents << "numvcpus = \"#{desired_guest_numvcpus}\"\n"
          end

          #  Write new vmx file on local filesystem
          filename_only = File.basename vmx_file, '.vmx'
          path_only = File.dirname vmx_file
          new_vmx_file = "#{path_only}/ZZZZ_#{desired_guest_name}.vmx"

          File.open(new_vmx_file, 'w') { |file|
            file.write(new_vmx_contents)
            file.close
          }

          #
          #  Do some validations, set defaults...
          #
          #  Validate if using a Resource Pool
          if config.esxi_resource_pool.is_a? String
            if config.esxi_resource_pool =~ %r{^\/}
              esxi_resource_pool = config.esxi_resource_pool
            else
              esxi_resource_pool = '/' + config.esxi_resource_pool
            end
          else
            esxi_resource_pool = '/'
          end

          if (config.local_allow_overwrite =~ %r{true}i) ||
             (config.local_allow_overwrite =~ %r{yes}i)
            overwrite_opts = '--overwrite --powerOffTarget'
          else
            overwrite_opts = nil
          end

          # Validate mac addresses
          unless config.guest_mac_address.nil?
            new_guest_mac_address = []
            0.upto(@guestvm_network.count - 1) do |index|
              unless config.guest_mac_address[index].nil?
                guest_mac_address = config.guest_mac_address[index].gsub(/-/,':').downcase
                if guest_mac_address =~ /^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$/i
                  new_guest_mac_address[index] = guest_mac_address
                elsif guest_mac_address == ''
                  new_guest_mac_address[index] = ''
                else
                  new_guest_mac_address[index] = "invalid"
                  env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                     message: "WARNING         : Ignored invalid mac address at index[#{index}]")
                end
              end
            end
            config.guest_mac_address = new_guest_mac_address
          end

          #  Validate disk types (thin, thick, etc...)
          if config.guest_disk_type.nil?
            guest_disk_type = "thin"
          else
            if config.supported_guest_disk_types.include? config.guest_disk_type.downcase
              guest_disk_type = config.guest_disk_type.downcase
            else
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'WARNING         : '\
                                            "Disk type: #{config.guest_disk_type} not "\
                                            "found, using \"thin\"")
              guest_disk_type = "thin"
            end
          end

          #  Validate guest Storage
          if config.guest_storage.is_a? Array
            new_guest_storage = []
            0.upto(config.guest_storage.count - 1) do |index|
              store_size = config.guest_storage[index].to_i
              if store_size < 1
                env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                     message: 'WARNING         : Ignored invalid '\
                                     "storage size #{config.guest_storage[index]} at "\
                                     "index[#{index}]")
                new_guest_storage[index] = "invalid"
              else
                new_guest_storage[index] = store_size
              end
            end
            config.guest_storage = new_guest_storage
          end

          # Validate local_lax setting (use relaxed (--lax) ovftool option)
          unless config.local_lax.nil?
            if config.local_lax == 'True'
              local_laxoption = '--lax'
            else
              local_laxoption = ''
            end
          end

          #
          #  Print summary
          #
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "  --- ESXi Summary ---")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "ESXi host       : #{config.esxi_hostname}")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                              message: "Virtual Network : #{@guestvm_network[0..3]}")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "Disk Store      : #{@guestvm_dsname}")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "Resource Pool   : #{esxi_resource_pool}")
          #
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: " --- Guest Summary ---")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "VM Name         : #{desired_guest_name}")
          if config.clone_from_vm.nil?
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Box             : #{env[:machine].box.name}")
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Box Ver         : #{env[:machine].box.version}")
          else
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Clone from VM   : #{config.clone_from_vm}")
          end
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "Memsize (MB)    : #{desired_guest_memsize}")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "CPUS            : #{desired_guest_numvcpus}")
          unless config.guest_mac_address[0].eql? ''
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Mac Address     : #{config.guest_mac_address[0..3]}")
          end
          unless config.guest_nic_type.nil?
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Nic Type        : #{desired_nic_type}")
          end
          unless config.guest_disk_type.nil?
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Disk Type       : #{guest_disk_type}")
          end
          unless config.guest_storage.nil?
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Storage (GB)    : #{config.guest_storage[0..13]}")
          end
          
          unless config.guest_extend_main_disk_size.nil?
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                message: "Extend Primary Disk Provision Size(GB)    : #{config.guest_extend_main_disk_size}")
          end          
          
          
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "Guest OS type   : #{desired_guestos}")
          unless config.virtualhw_version.nil?
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Virtual HW ver  : #{desired_virtualhw_version}")
          end
          if config.local_lax == 'True'
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Relaxed (--lax) : #{config.local_lax}")
          end
          unless overwrite_opts.nil?
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: 'Allow Overwrite : True')
          end
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "  --- Guest Build ---")

          if config.clone_from_vm.nil?
            src_path = new_vmx_file
          else
            src_path = clone_from_vm_path
          end
          ovf_cmd = "ovftool --noSSLVerify #{overwrite_opts} "\
                "-dm=#{guest_disk_type} #{local_laxoption} "\
                "-ds=\"#{@guestvm_dsname}\" --name=\"#{desired_guest_name}\" "\
                "\"#{src_path}\" vi://#{config.esxi_username}:"\
                "#{$encoded_esxi_password}@#{config.esxi_hostname}"\
                "#{esxi_resource_pool}"

          #
          #  Security alert! If password debugging is enabled, Password will
          #  be exposed in log file.
          if config.debug =~ %r{password}i
            @logger.info("vagrant-vmware-esxi, createvm: ovf_cmd #{ovf_cmd}")
            puts "ovftool command: #{ovf_cmd}"
          elsif config.debug =~ %r{true}i
            if $encoded_esxi_password == ''
              ovf_cmd_nopw = ovf_cmd
            else
              ovf_cmd_nopw = ovf_cmd.gsub(/#{$encoded_esxi_password}/, '******')
            end
            puts "ovftool command: #{ovf_cmd_nopw}"
          end
          unless system "#{ovf_cmd}"
            raise Errors::OVFToolError, message: ''
          end

          # VMX file is not needed any longer. Delete it
          if config.debug =~ %r{true}i
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Keeping file    : #{new_vmx_file}")
          else
            File.delete(new_vmx_file)
            FileUtils.remove_entry tmpdir unless tmpdir.nil?
          end

          #
          #  Re-open the network connection to get VMID and do adjustments
          #  to vmx file.
          #
          Net::SSH.start(config.esxi_hostname, config.esxi_username,
            password:                   $esxi_password,
            port:                       config.esxi_hostport,
            keys:                       config.local_private_keys,
            timeout:                    20,
            number_of_password_prompts: 0,
            non_interactive:            true
          ) do |ssh|
            r = ssh.exec!(
                    'vim-cmd vmsvc/getallvms 2>/dev/null | sort -n |'\
                    "grep \"[0-9] * #{desired_guest_name} .*#{desired_guest_name}\"|"\
                    "awk '{print $1}'|tail -1")
            vmid = r
            if (vmid == '') || (vmid == '0') || (r.exitstatus != 0)
              raise Errors::ESXiError,
                    message: "Unable to register #{desired_guest_name}"
            end

            env[:machine].id = vmid.to_i
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "VMID            : #{env[:machine].id}")

            #
            #   -=-=-=-=-=-=-
            #  Destination (on esxi host) vmx file
            dst_vmx = ssh.exec!("vim-cmd vmsvc/get.config #{env[:machine].id} |\
                    grep vmPathName|awk '{print $NF}'|sed 's/[\"|,]//g'")

            dst_vmx_ds = ssh.exec!("vim-cmd vmsvc/get.config #{env[:machine].id} |"\
                    'grep vmPathName|grep -oE "\[.*\]"')

            dst_vmx_dir = ssh.exec!("vim-cmd vmsvc/get.config #{env[:machine].id} |\
                    grep vmPathName|awk '{print $NF}'|awk -F'\/' '{print $1}'")


            dst_vmx_file = "/vmfs/volumes/"
            dst_vmx_file << dst_vmx_ds.gsub('[','').gsub(']','').strip + "/"
            esxi_guest_dir = dst_vmx_file + dst_vmx_dir.strip
            dst_vmx_file << dst_vmx

            
            vmdk_primary_file_location = "#{esxi_guest_dir}/#{desired_guest_name}.vmdk"
            if config.guest_extend_main_disk_size.is_a? Integer
              guest_extend_main_disk_size = config.guest_extend_main_disk_size
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                message: "Extending Main Storage: #{desired_guest_name}.vmdk (#{guest_extend_main_disk_size}GB)")              

            cmd =  "/bin/vmkfstools -X #{guest_extend_main_disk_size}G \"#{vmdk_primary_file_location}\"" 
              puts "cmd: #{cmd}" if config.debug =~ %r{true}i
                r = ssh.exec!(cmd)
                if r.exitstatus != 0
                  raise Errors::ESXiError,
                        message: "Unable to extend disk (vmkfstools failed):\n"\
                                 " #{r}"\
                                 ' Review ESXi logs for addiontal information!'
                end
            end            
            
            
            
            #  Create storage if required
            if config.guest_storage.is_a? Array
              index = -1
              config.guest_storage.each do |store|
                store_size = store.to_i
                index += 1
                if store_size == 0
                  env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                       message: "Creating Storage: Skipping --invalid-- at storage[#{index}]")
                elsif index > 14
                  env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                       message: "Creating Storage: Skipping storage[#{index}], Maximum 14 devices exceeded...")
                else
                  env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                       message: "Creating Storage: disk_#{index}.vmdk (#{store_size}GB)")

                  #  Figure out what SCSI slots are used.
                  r = ssh.exec!("vim-cmd vmsvc/device.getdevices #{machine.id}|"\
                    "grep -A 30 vim.vm.device.VirtualDisk|"\
                    "grep -e controllerKey -e unitNumber|grep -A 1 'controllerKey = 1000,'|"\
                    "grep unitNumber|awk '{print $3}'|sed 's/,//g'")

                  if r.length < 2
                    raise Errors::ESXiError,
                          message: "Unable to get guest storage configuration:\n"\
                                   "  #{r}"\
                                   '  Review ESXi logs for additional information!'
                  end
                  0.upto(15) do |slot|
                    next if slot == 7
                    if r !~ %r{^#{slot.to_s}$}i
                      puts "Avail slot: #{slot}" if config.debug =~ %r{true}i
                      guest_disk_type = 'zeroedthick' if guest_disk_type == 'thick'

                      cmd = "/bin/vmkfstools -c #{store_size}G -d #{guest_disk_type} \"#{esxi_guest_dir}/disk_#{index}.vmdk\""
                      puts "cmd: #{cmd}" if config.debug =~ %r{true}i
                      r = ssh.exec!(cmd)
                      if r.exitstatus != 0
                        raise Errors::ESXiError,
                              message: "Unable to create guest storage (vmkfstools failed):\n"\
                                       "  #{r}"\
                                       '  Review ESXi logs for additional information!'
                      end
                      r = ssh.exec!("vim-cmd vmsvc/device.diskaddexisting #{env[:machine].id} "\
                        "#{esxi_guest_dir}/disk_#{index}.vmdk 0 #{slot}")
                      if r.exitstatus != 0
                        raise Errors::ESXiError,
                              message: "Unable to create guest storage (vmkfstools failed):\n"\
                                       "  #{r}"\
                                       '  Review ESXi logs for additional information!'
                      end
                      break
                    end
                  end
                end
              end
            end

            #  Get vmx file in memory
            esxi_orig_vmx_file = ssh.exec!("cat #{dst_vmx_file} 2>/dev/null")

            puts "orig vmx: #{esxi_orig_vmx_file}\n\n" if config.debug =~ %r{vmx}i

            if esxi_orig_vmx_file.exitstatus != 0
              raise Errors::ESXiError,
                    message: "Unable to read #{dst_vmx_file}"
            end

            #  read each line in vmx to customize
            new_vmx_contents = ''
            esxi_orig_vmx_file.each_line do |line|

              case line

              when /^memsize = /i
                new_vmx_contents << "memsize = \"#{desired_guest_memsize}\"\n"

              when /^numvcpus = /i
                new_vmx_contents << "numvcpus = \"#{desired_guest_numvcpus}\"\n"

              when /^virtualHW.version = /i
                new_vmx_contents << "virtualHW.version = \"#{desired_virtualhw_version}\"\n"

              when /^guestOS = /i
                new_vmx_contents << "guestOS = \"#{desired_guestos}\"\n"

              when /^ethernet[0-9]/i
                #  Delete these entries.  We'll append them later.

              else
                line_changed = false
                if config.guest_custom_vmx_settings.is_a? Array
                  env[:machine].provider_config.guest_custom_vmx_settings.each do |k, v|
                    if line =~ /#{k} = /
                      new_vmx_contents << "#{k} = \"#{v}\"\n"
                      line_changed = true
                      env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                           message: "Custom vmx      : Modify #{k} = \"#{v}\"")
                    end
                  end
                end
                if line_changed == false
                  new_vmx_contents << line
                end
              end
            end

            #  For all nics, configure desired_nic_type and enable nics
            desired_nic_type = 'e1000' if desired_nic_type.nil?

            if config.esxi_virtual_network.is_a? Array
              number_of_adapters = config.esxi_virtual_network.count
            else
              number_of_adapters = 1
            end

            0.upto(number_of_adapters - 1) do |nic_index|
              new_vmx_contents << "ethernet#{nic_index}.networkName = \"#{@guestvm_network[nic_index]}\"\n"
              new_vmx_contents << "ethernet#{nic_index}.virtualDev = \"#{desired_nic_type}\"\n"
              new_vmx_contents << "ethernet#{nic_index}.present = \"TRUE\"\n"
              if config.guest_mac_address[nic_index].nil?
                new_vmx_contents << "ethernet#{nic_index}.addressType = \"generated\"\n"
              else
                guest_mac_address = config.guest_mac_address[nic_index]
                if guest_mac_address =~ /^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$/i
                  new_vmx_contents << "ethernet#{nic_index}.addressType = \"static\"\n"
                  new_vmx_contents << "ethernet#{nic_index}.address = \"#{guest_mac_address}\"\n"
                else
                  new_vmx_contents << "ethernet#{nic_index}.addressType = \"generated\"\n"
                end
              end
            end

            # append guest_custom_vmx_settings if not yet in vmx
            if config.guest_custom_vmx_settings.is_a? Array
              env[:machine].provider_config.guest_custom_vmx_settings.each do |k, v|
                unless new_vmx_contents =~ /#{k} = /
                  new_vmx_contents << "#{k} = \"#{v}\"\n"
                  env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                       message: "Custom vmx      : Append #{k} = \"#{v}\"")
                end
              end
            end

            #  update vmx on esxi
            if config.debug =~ %r{vmx}i
              puts "new vmx: #{new_vmx_contents}"
              puts "\n\n"
            end
            r = ''
            ssh.open_channel do |channel|
              channel.exec("cat >#{dst_vmx_file}") do |ch, success|
                raise Errors::ESXiError,
                      message: "Unable to update vmx file.\n"\
                               "  #{r}" unless success
                channel.send_data(new_vmx_contents)
                channel.eof!
              end
            end
            ssh.loop

            # Done
          end
        end
      end
    end
  end
end
