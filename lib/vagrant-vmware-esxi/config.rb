#  Config

module VagrantPlugins
  module ESXi
    # Config class
    class Config < Vagrant.plugin('2', :config)
      attr_accessor :esxi_hostname
      attr_accessor :esxi_hostport
      attr_accessor :esxi_username
      attr_accessor :esxi_password
      attr_accessor :encoded_esxi_password
      attr_accessor :esxi_disk_store
      attr_accessor :esxi_virtual_network
      attr_accessor :default_vswitch
      attr_accessor :default_port_group
      attr_accessor :destroy_unused_port_groups
      attr_accessor :destroy_unused_vswitches
      attr_accessor :destroy_unused_networks
      attr_accessor :esxi_resource_pool
      attr_accessor :clone_from_vm
      attr_accessor :guest_username
      attr_accessor :guest_name
      attr_accessor :guest_name_prefix
      attr_accessor :guest_guestos
      attr_accessor :guest_disk_type
      attr_accessor :guest_boot_disk_size
      attr_accessor :guest_storage
      attr_accessor :guest_nic_type
      attr_accessor :guest_mac_address
      attr_accessor :guest_memsize
      attr_accessor :guest_numvcpus
      attr_accessor :guest_virtualhw_version
      attr_accessor :guest_snapshot_includememory
      attr_accessor :guest_snapshot_quiesced
      attr_accessor :guest_custom_vmx_settings
      attr_accessor :guest_autostart
      attr_accessor :local_private_keys
      attr_accessor :local_allow_overwrite
      attr_accessor :local_lax
      attr_accessor :local_use_ip_cache
      attr_accessor :local_failonwarning
      attr_accessor :debug
      attr_accessor :supported_guest_virtualhw_versions
      attr_accessor :supported_guest_disk_types
      attr_accessor :supported_guest_nic_types
      attr_accessor :supported_guest_guestos
      attr_accessor :saved_ipaddress

      #
      #  legacy (1.x) config entries
      attr_accessor :esxi_private_keys   # esxi_password
      attr_accessor :ssh_username        # guest_username
      attr_accessor :vmname              # guest_name
      attr_accessor :vmname_prefix       # guest_name_prefix
      attr_accessor :guestos             # guest_guestos
      attr_accessor :vm_disk_store       # esxi_disk_store
      attr_accessor :vm_disk_type        # guest_disk_type
      attr_accessor :virtual_network     # esxi_virtual_network
      attr_accessor :nic_type            # guest_nic_type
      attr_accessor :mac_address         # guest_mac_address
      attr_accessor :resource_pool       # esxi_resource_pool
      attr_accessor :memsize             # guest_memsize
      attr_accessor :numvcpus            # guest_numvcpus
      attr_accessor :virtualhw_version   # guest_virtualhw_version
      attr_accessor :custom_vmx_settings # guest_custom_vmx_settings
      attr_accessor :allow_overwrite     # local_allow_overwrite
      attr_accessor :lax                 # local_lax

      def initialize
        @esxi_hostname = nil
        @esxi_hostport = 22
        @esxi_username = 'root'
        @esxi_password = ''
        @encoded_esxi_password = nil
        @esxi_disk_store = nil
        @esxi_virtual_network = nil
        @default_vswitch = UNSET_VALUE
        @default_port_group = UNSET_VALUE
        @destroy_unused_port_groups = UNSET_VALUE
        @destroy_unused_vswitches = UNSET_VALUE
        @destroy_unused_networks = UNSET_VALUE
        @esxi_resource_pool = nil
        @clone_from_vm = nil
        @guest_username = 'vagrant'
        @guest_name = nil
        @guest_name_prefix = 'V-'
        @guest_guestos = nil
        @guest_disk_type = nil
        @guest_boot_disk_size = nil
        @guest_storage = nil
        @guest_nic_type = nil
        @guest_mac_address = ["","","",""]
        @guest_memsize = nil
        @guest_numvcpus = nil
        @guest_virtualhw_version = nil
        @guest_snapshot_includememory = 'False'
        @guest_snapshot_quiesced = 'False'
        @guest_custom_vmx_settings = nil
        @local_private_keys = nil
        @local_allow_overwrite = 'False'
        @local_lax = 'False'
        @local_use_ip_cache = 'True'
        @local_failonwarning = 'False'
        @debug = 'False'
        @saved_ipaddress = nil
        @supported_guest_virtualhw_versions = [
          4,7,8,9,10,11,12,13,14
        ]
        @supported_guest_disk_types = [
          'thin',
          'thick',
          'eagerzeroedthick'
        ]
        @supported_guest_nic_types = [
          'vlance',
          'flexible',
          'e1000',
          'e1000e',
          'vmxnet',
          'vmxnet2',
          'vmxnet3'
        ]
        @supported_guest_guestos = [
          'asianux3-64',
          'asianux3',
          'asianux4-64',
          'asianux4',
          'asianux5-64',
          'asianux7-64',
          'centos6-64',
          'centos-64',
          'centos6',
          'centos7-64',
          'centos7',
          'centos8-64',
          'centos',
          'coreos-64',
          'darwin10-64',
          'darwin10',
          'darwin11-64',
          'darwin11',
          'darwin12-64',
          'darwin13-64',
          'darwin14-64',
          'darwin15-64',
          'darwin16-64',
          'darwin17-64',
          'darwin18-64',
          'darwin19-64',
          'darwin-64',
          'darwin',
          'debian10-64',
          'debian10',
          'debian4-64',
          'debian4',
          'debian5-64',
          'debian5',
          'debian6-64',
          'debian6',
          'debian7-64',
          'debian7',
          'debian8-64',
          'debian8',
          'debian9-64',
          'debian9',
          'dos',
          'ecomstation2',
          'ecomstation',
          'fedora-64',
          'fedora',
          'freebsd-64',
          'freebsd',
          'freebsd11-64',
          'freebsd11',
          'freebsd12-64',
          'freebsd12',
          'genericlinux',
          'mandrake',
          'mandriva-64',
          'mandriva',
          'netware4',
          'netware5',
          'netware6',
          'nld9',
          'oes',
          'openserver5',
          'openserver6',
          'opensuse-64',
          'opensuse',
          'oraclelinux6-64',
          'oraclelinux-64',
          'oraclelinux6',
          'oraclelinux7-64',
          'oraclelinux7',
          'oraclelinux',
          'os2',
          'other24xlinux-64',
          'other24xlinux',
          'other26xlinux-64',
          'other26xlinux',
          'other3xlinux-64',
          'other3xlinux',
          'other',
          'otherguest-64',
          'otherlinux-64',
          'otherlinux',
          'redhat',
          'rhel2',
          'rhel3-64',
          'rhel3',
          'rhel4-64',
          'rhel4',
          'rhel5-64',
          'rhel5',
          'rhel6-64',
          'rhel6',
          'rhel7-64',
          'rhel7',
          'rhel8-64',
          'sjds',
          'sles10-64',
          'sles10',
          'sles11-64',
          'sles11',
          'sles12-64',
          'sles12',
          'sles-64',
          'sles',
          'solaris10-64',
          'solaris10',
          'solaris11-64',
          'solaris6',
          'solaris7',
          'solaris8',
          'solaris9',
          'suse-64',
          'suse',
          'turbolinux-64',
          'turbolinux',
          'ubuntu-64',
          'ubuntu',
          'unixware7',
          'vmkernel5',
          'vmkernel65',
          'vmkernel6',
          'vmkernel',
          'vmwarephoton-64',
          'win2000advserv',
          'win2000pro',
          'win2000serv',
          'win31',
          'win95',
          'win98',
          'windows7-64',
          'windows7',
          'windows7server-64',
          'windows8-64',
          'windows8',
          'windows8server-64',
          'windows9-64',
          'windows9',
          'windows9server-64',
          'windowshyperv',
          'winlonghorn-64',
          'winlonghorn',
          'winme',
          'winnetbusiness',
          'winnetdatacenter-64',
          'winnetdatacenter',
          'winnetenterprise-64',
          'winnetenterprise',
          'winnetstandard-64',
          'winnetstandard',
          'winnetweb',
          'winnt',
          'winvista-64',
          'winvista',
          'winxphome',
          'winxppro-64',
          'winxppro'
        ]

        # Legacy (1.x)
        @esxi_private_keys = nil
        @ssh_username = nil
        @vmname = nil
        @vmname_prefix = nil
        @guestos = nil
        @vm_disk_store = nil
        @vm_disk_type = nil
        @virtual_network = nil
        @nic_type = nil
        @mac_address = nil
        @resource_pool = nil
        @memsize = nil
        @numvcpus = nil
        @virtualhw_version = nil
        @custom_vmx_settings = nil
        @allow_overwrite = nil
        @lax = nil
      end

      def finalize!

        #  Migrate legacy(1.x) parms to 2.0
        migrate_msg = ""
        unless @esxi_private_keys.nil?
          migrate_msg << "You should migrate legacy option esxi_private_keys to esxi_password = \"key:\" in Vagrant file.\n"
        end
        unless @ssh_username.nil?
          migrate_msg << "You should migrate legacy option ssh_username to guest_username in Vagrant file.\n"
          @guest_username = @ssh_username.dup
        end
        unless @vmname.nil?
          migrate_msg << "You should migrate legacy option vmname to guest_name in Vagrant file.\n"
          @guest_name = @vmname.dup
        end
        unless @vmname_prefix.nil?
          migrate_msg << "You should migrate legacy option vmname_prefix to guest_name_prefix in Vagrant file.\n"
          @guest_name_prefix = @vmname_prefix.dup
        end
        unless @guestos.nil?
          migrate_msg << "You should migrate legacy option guestos to guest_guestos in Vagrant file.\n"
          @guest_guestos = @guestos.dup
        end
        unless @vm_disk_store.nil?
          migrate_msg << "You should migrate legacy option vm_disk_store to esxi_disk_store in Vagrant file.\n"
          @esxi_disk_store = @vm_disk_store.dup
        end
        unless @vm_disk_type.nil?
          migrate_msg << "You should migrate legacy option vm_disk_type to guest_disk_type in Vagrant file.\n"
          @guest_disk_type = @vm_disk_type.dup
        end
        unless @virtual_network.nil?
          migrate_msg << "You should migrate legacy option virtual_network to esxi_virtual_network in Vagrant file.\n"
          @esxi_virtual_network = @virtual_network.dup
        end
        unless @nic_type.nil?
          migrate_msg << "You should migrate legacy option nic_type to guest_nic_type in Vagrant file.\n"
          @guest_nic_type = @nic_type.dup
        end
        unless @mac_address.nil?
          migrate_msg << "You should migrate legacy option mac_address to guest_mac_address in Vagrant file.\n"
          @guest_mac_address = @mac_address.dup
        end
        unless @resource_pool.nil?
          migrate_msg << "You should migrate legacy option resource_pool to esxi_resource_pool in Vagrant file.\n"
          @esxi_resource_pool = @resource_pool.dup
        end
        unless @memsize.nil?
          migrate_msg << "You should migrate legacy option memsize to guest_memsize in Vagrant file.\n"
          @guest_memsize = @memsize.dup
        end
        unless @numvcpus.nil?
          migrate_msg << "You should migrate legacy option numvcpus to guest_numvcpus in Vagrant file.\n"
          @guest_numvcpus = @numvcpus.dup
        end
        unless @virtualhw_version.nil?
          migrate_msg << "You should migrate legacy option virtualhw_version to guest_virtualhw_version in Vagrant file.\n"
          @guest_virtualhw_version = @virtualhw_version.dup
        end
        unless @custom_vmx_settings.nil?
          migrate_msg << "You should migrate legacy option custom_vmx_settings to guest_custom_vmx_settings in Vagrant file.\n"
          @guest_custom_vmx_settings = @custom_vmx_settings.dup
        end
        unless @allow_overwrite.nil?
          migrate_msg << "You should migrate legacy option allow_overwrite to local_allow_overwrite in Vagrant file.\n"
          @local_allow_overwrite = @allow_overwrite.dup
        end
        unless @lax.nil?
          migrate_msg << "You should migrate legacy option lax to local_lax in Vagrant file.\n"
          @local_lax = @lax.dup
        end

        if $migrate_msg_flag.nil?
          $migrate_msg_flag = 'True'
          puts migrate_msg
        end

        @guest_username = nil if @guest_username == UNSET_VALUE
        @encoded_esxi_password = nil

        @guest_boot_disk_size = @guest_boot_disk_size.to_i if @guest_boot_disk_size.is_a? String
        @guest_boot_disk_size = nil if @guest_boot_disk_size == 0
        @guest_storage = [@guest_storage.to_i] if @guest_storage.is_a? String
        @guest_storage = [@guest_storage] if @guest_storage.is_a? Integer
        @guest_storage = [{ size: @guest_storage[:size], datastore: @guest_storage[:datastore] }] if @guest_storage.is_a? Hash

        @esxi_virtual_network = [@esxi_virtual_network] if @esxi_virtual_network.is_a? String

        @esxi_virtual_network = ['--NotSet--'] if @esxi_virtual_network.nil?

        @default_vswitch = "vSwitch0" if @default_vswitch == UNSET_VALUE
        @default_port_group = "VM Network" if @default_port_group == UNSET_VALUE

        @destroy_unused_port_groups = false if @destroy_unused_port_groups == UNSET_VALUE
        @destroy_unused_vswitches = false if @destroy_unused_vswitches == UNSET_VALUE
        @destroy_unused_networks = false if @destroy_unused_networks == UNSET_VALUE
        if @destroy_unused_networks
          @destroy_unused_port_groups = true
          @destroy_unused_vswitches = true
        end

        @local_private_keys = [
          '~/.ssh/id_rsa',
          '~/.ssh/id_ecdsa',
          '~/.ssh/id_dsa'
        ]
        #'~/.ssh/id_ed25519',
        # Removed support for ed25519 because libsodium is not compatible with windows.
        # Should be added back when net-ssh 5.0 is out of beta.

        if @local_lax =~ /true/i
          @local_lax = 'True'
        else
          @local_lax = 'False'
        end

        if @local_use_ip_cache =~ /false/i
          @local_use_ip_cache = 'False'
        else
          @local_use_ip_cache = 'True'
        end

        if @local_failonwarning =~ /true/i
          @local_failonwarning = 'True'
        else
          @local_failonwarning = 'False'
        end

        if @guest_snapshot_includememory =~ /true/i
          @guest_snapshot_includememory = 'includeMemory'
        else
          @guest_snapshot_includememory = ''
       end
       if @guest_snapshot_quiesced =~ /true/i
         @guest_snapshot_quiesced = 'quiesced'
       else
         @guest_snapshot_quiesced = ''
       end
       @saved_ipaddress = nil

      end
    end
  end
end
