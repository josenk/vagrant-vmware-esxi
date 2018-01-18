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
          Net::SSH.start( config.esxi_hostname, config.esxi_username,
            password:                   $esxi_password,
            port:                       config.esxi_hostport,
            keys:                       config.esxi_private_keys,
            timeout:                    20,
            number_of_password_prompts: 0,
            non_interactive:            true
          ) do |ssh|

            @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::createvm-ssh')

            #
            #  Figure out DataStore
            r = ssh.exec!(
                    'df | grep "^[VMFS|NFS]" | sort -nk4 |'\
                    'sed "s|.*/vmfs/volumes/||g" | tail +2')

            availvolumes = r.split(/\n/)
            if (config.debug =~ %r{true}i)
               puts "Available DS Volumes: #{availvolumes}"
            end
            if (r == '') || (r.exitstatus != 0)
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
              @guestvm_dsname = desired_ds
            else
              @guestvm_dsname = availvolumes.last
            end

            if (@guestvm_dsname != desired_ds) &&
               !config.vm_disk_store.nil?
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                   message: 'WARNING         : '\
                                            "#{config.vm_disk_store} not "\
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
            if (config.debug =~ %r{true}i)
               puts "Available Networks: #{availnetworks}"
            end
            if (availnetworks == '') || (r.exitstatus != 0)
              raise Errors::ESXiError,
                    message: "Unable to get list of Virtual Networks:\n"\
                             "#{r.stderr}"
            end

            @guestvm_network = []
            counter = 0
            if config.virtual_network.nil?
              @guestvm_network[0] = availnetworks.first
              env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                    message: 'WARNING         : '\
                                             "config.virtual_network not "\
                                             "set, using #{availnetworks.first}")
            else
              networkID = 0
              for aVirtNet in Array(config.virtual_network) do
                if availnetworks.include? aVirtNet
                  @guestvm_network << aVirtNet
                else
                  @guestvm_network << availnetworks.first
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
          end

          @logger.info('vagrant-vmware-esxi, createvm: '\
                       "virtual_network: #{@guestvm_network}")

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

          #  Append virt network options
          netOpts = ""
          networkID = 0
          for element in @guestvm_network do
            if (config.debug =~ %r{true}i)
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

          # Validate mac addresses
          unless config.mac_address.nil?
            new_mac_address = []
            0.upto(@guestvm_network.count - 1) do |index|
              unless config.mac_address[index].nil?
                mac_address = config.mac_address[index].gsub(/-/,':').downcase
                if mac_address =~ /^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$/i
                  new_mac_address[index] = mac_address
                elsif mac_address == ''
                  new_mac_address[index] = ''
                else
                  new_mac_address[index] = "invalid"
                end
              end
            end
            config.mac_address = new_mac_address
          end

          #  Validate nic types
          unless config.nic_type.nil?
            if config.nic_type =~ /Vlance/i
              config.nic_type = 'Vlance'
            elsif config.nic_type =~ /Flexible/i
              config.nic_type = 'Flexible'
            elsif config.nic_type =~ /e1000$/i
              config.nic_type = 'e1000'
            elsif config.nic_type =~ /e1000e$/i
              config.nic_type = 'e1000e'
            elsif config.nic_type =~ /vmxnet$/i
              config.nic_type = 'vmxnet'
            elsif config.nic_type =~ /vmxnet2$/i
              config.nic_type = 'vmxnet2'
            elsif config.nic_type =~ /vmxnet3$/i
              config.nic_type = 'vmxnet3'
            else
              config.nic_type = 'e1000'
            end
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
                               message: "Box             : #{env[:machine].box.name}")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "Box Ver         : #{env[:machine].box.version}")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "CPUS            :#{numvcpus}")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "Memsize (MB)    :#{memsize}")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "Guest OS type   :#{guestOS}")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "Disk Store      : #{@guestvm_dsname}")
          env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                               message: "Virtual Network : #{@guestvm_network[0..3]}")
          unless config.mac_address[0].eql? ''
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Mac Address     : #{config.mac_address}")
          end
          unless config.nic_type.nil?
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Nic Type        : #{config.nic_type}")
          end
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
            raise Errors::OVFToolError,
                  message: 'ovftool not found or not in your path.'\
                           "  Please download and "\
                           '  install from http://www.vmware.com.'
          end
          ovf_cmd = "ovftool --noSSLVerify #{overwrite_opts} "\
                "#{netOpts} -dm=thin "\
                "-ds=\"#{@guestvm_dsname}\" --name=\"#{guestvm_vmname}\" "\
                "\"#{new_vmx_file}\" vi://#{config.esxi_username}:"\
                "#{$encoded_esxi_password}@#{config.esxi_hostname}"\
                "#{resource_pool}"

          #  Security bug if unremarked! Password will be exposed in log file.
          if (config.debug =~ %r{password}i)
            @logger.info("vagrant-vmware-esxi, createvm: ovf_cmd #{ovf_cmd}")
            puts "ovftool command: #{ovf_cmd}"
          end
          if (config.debug =~ %r{true}i)
            ovf_cmd_nopw = ovf_cmd.gsub(/#{$encoded_esxi_password}/, '******')
            puts "ovftool command: #{ovf_cmd_nopw}"
          end
          unless system "#{ovf_cmd}"
            raise Errors::OVFToolError, message: ''
          end

          # VMX file is not needed any longer. Delete it
          if (config.debug =~ %r{true}i)
            puts "Keeping file: #{new_vmx_file}"
          else
            File.delete(new_vmx_file)
          end

          #
          #  Re-open the network connection to get VMID
          #
          Net::SSH.start( config.esxi_hostname, config.esxi_username,
            password:                   $esxi_password,
            port:                       config.esxi_hostport,
            keys:                       config.esxi_private_keys,
            timeout:                    20,
            number_of_password_prompts: 0,
            non_interactive:            true
          ) do |ssh|
            r = ssh.exec!(
                    'vim-cmd vmsvc/getallvms |'\
                    "grep \" #{guestvm_vmname} \"|awk '{print $1}'")
            vmid = r
            if (vmid == '') || (r.exitstatus != 0)
              raise Errors::ESXiError,
                    message: "Unable to register #{guestvm_vmname}"
            end

            env[:machine].id = vmid.to_i
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "VMID: #{env[:machine].id}")

            #
            #   -=-=-=-=-=-=-
            #  Destination (on esxi host) vmx file
            dst_vmx = ssh.exec!("vim-cmd vmsvc/get.config #{env[:machine].id} |\
                    grep vmPathName|awk '{print $NF}'|sed 's/[\"|,]//g'")

            dst_vmx_dir = ssh.exec!("vim-cmd vmsvc/get.config #{env[:machine].id} |"\
                    'grep vmPathName|grep -oE "\[.*\]"')

            dst_vmx_file = "/vmfs/volumes/"
            dst_vmx_file << dst_vmx_dir.gsub('[','').gsub(']','').strip + "/"
            dst_vmx_file << dst_vmx

            #  Get vmx file in memory
            esxi_orig_vmx_file = ssh.exec!("cat #{dst_vmx_file} 2>/dev/null")
            if (config.debug =~ %r{vmx}i)
              puts "orig vmx: #{esxi_orig_vmx_file}"
            end
            if esxi_orig_vmx_file.exitstatus != 0
              raise Errors::ESXiError,
                    message: "Unable to read #{dst_vmx_file}"
            end

            #  read each line in vmx to configure mac and nic type.
            new_vmx_contents = ''
            vmx_need_change_flag = false
            esxi_orig_vmx_file.each_line do |line|
              if line.match(/^ethernet[0-9]/i)
                nicindex = line[8].to_i
                if line.match(/^ethernet[0-9].networkName = /i)
                  new_vmx_contents << line
                elsif line.match(/^ethernet0.virtualDev = /i)
                  #  Update nic_type if it's set, otherwise, save eth0 nic_type
                  #  for the remaining nics.  (ovftool doesn't set it...)
                  if config.nic_type.nil?
                    config.nic_type = line.gsub(/ethernet0.virtualDev = /i, '').gsub('"', '').strip
                    new_vmx_contents << line
                  else
                    new_vmx_contents << line.gsub(/ = .*$/, " = \"#{config.nic_type}\"\n")
                    vmx_need_change_flag = true
                  end
                elsif (line.match(/^ethernet[0-9].addressType = /i) &&
                    !config.mac_address[nicindex].nil?)
                  # Update MAC address if it's set
                  mac_address = config.mac_address[nicindex]
                  if mac_address =~ /^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$/i
                    new_vmx_contents << line.gsub(/ = .*$/, " = \"static\"")
                    new_vmx_contents << line.gsub(/Type = .*$/, " = \"#{mac_address}\"")
                    vmx_need_change_flag = true
                  elsif mac_address == ''
                    new_vmx_contents << line
                  else
                    env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                       message: "Ignored invalid mac address at index: #{nicindex}")
                    new_vmx_contents << line
                  end
                end
              else
                new_vmx_contents << line
              end
            end

            #  For all nics, configure nic_type and enable nics
            if config.nic_type.nil?
              config.nic_type = "e1000"
            end
            if config.virtual_network.is_a? Array
              number_of_adapters = config.virtual_network.count
            else
              number_of_adapters = 1
            end

            1.upto(number_of_adapters) do |index|
              nic_index = index - 1
              unless new_vmx_contents =~ /ethernet#{nic_index}.virtualDev = \"#{config.nic_type}\"/i
                new_vmx_contents << "ethernet#{nic_index}.virtualDev = \"#{config.nic_type}\"\n"
                vmx_need_change_flag = true
              end
              unless new_vmx_contents =~ /ethernet#{nic_index}.present = \"TRUE\"/i
                new_vmx_contents << "ethernet#{nic_index}.present = \"TRUE\"\n"
                vmx_need_change_flag = true
              end
            end

            # append custom_vmx_settings if exists
            if config.custom_vmx_settings.is_a? Array
              env[:machine].provider_config.custom_vmx_settings.each do |k, v|
                new_vmx_contents << "#{k} = \"#{v}\"\n"
                vmx_need_change_flag = true
              end
            end

            #  If there was changes, update esxi
            if vmx_need_change_flag == true
              if (config.debug =~ %r{vmx}i)
                puts "new vmx: #{new_vmx_contents}"
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
            else
              if (config.debug =~ %r{vmx}i)
                puts "no changes requried to vmx file"
              end
            end
          end
        end
      end
    end
  end
end
