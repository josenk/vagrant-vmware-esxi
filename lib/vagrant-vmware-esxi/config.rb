#  Config

module VagrantPlugins
  module ESXi
    # Config class
    class Config < Vagrant.plugin('2', :config)
      attr_accessor :esxi_hostname
      attr_accessor :esxi_hostport
      attr_accessor :esxi_username
      attr_accessor :esxi_password
      attr_accessor :esxi_private_keys
      attr_accessor :ssh_username
      attr_accessor :private_key_path
      attr_accessor :vmname
      attr_accessor :vmname_prefix
      attr_accessor :guestos
      attr_accessor :vm_disk_store
      attr_accessor :vm_disk_type
      attr_accessor :virtual_network
      attr_accessor :nic_type
      attr_accessor :mac_address
      attr_accessor :resource_pool
      attr_accessor :memsize
      attr_accessor :numvcpus
      attr_accessor :virtualhw_version
      attr_accessor :custom_vmx_settings
      attr_accessor :allow_overwrite
      attr_accessor :debug
      attr_accessor :lax
      attr_accessor :system_private_keys_path
      attr_accessor :supported_virtualhw_versions
      attr_accessor :supported_vm_disk_types
      attr_accessor :supported_nic_types
      attr_accessor :supported_guestos

      def initialize
        @esxi_hostname = nil
        @esxi_hostport = 22
        @esxi_username = 'root'
        @esxi_password = nil
        @esxi_private_keys = UNSET_VALUE
        @ssh_username = 'vagrant'
        @private_key_path = UNSET_VALUE
        @vmname = nil
        @vmname_prefix = 'V-'
        @guestos = nil
        @vm_disk_store = nil
        @vm_disk_type = nil
        @virtual_network = nil
        @nic_type = nil
        @mac_address = ["","","",""]
        @resource_pool = nil
        @memsize = UNSET_VALUE
        @numvcpus = UNSET_VALUE
        @virtualhw_version = nil
        @custom_vmx_settings = UNSET_VALUE
        @allow_overwrite = 'False'
        @debug = 'False'
        @lax = 'False'
        @system_private_keys_path = [
          '~/.ssh/id_rsa',
          '~/.ssh/id_ecdsa',
          '~/.ssh/id_ed25519',
          '~/.ssh/id_dsa'
        ]
        @supported_virtualhw_versions = [
          4,7,8,9,10,11,12,13
        ]
        @supported_vm_disk_types = [
          'thin',
          'thick',
          'eagerzeroedthick'
        ]
        @supported_nic_types = [
          'vlance',
          'flexible',
          'e1000',
          'e1000e',
          'vmxnet',
          'vmxnet2',
          'vmxnet3'
        ]
        @supported_guestos = [
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
          'eComStation2',
          'eComStation',
          'fedora-64',
          'fedora',
          'freebsd-64',
          'freebsd',
          'genericLinux',
          'mandrake',
          'mandriva-64',
          'mandriva',
          'netware4',
          'netware5',
          'netware6',
          'nld9',
          'oes',
          'openServer5',
          'openServer6',
          'opensuse-64',
          'opensuse',
          'oracleLinux6-64',
          'oracleLinux-64',
          'oracleLinux6',
          'oracleLinux7-64',
          'oracleLinux7',
          'oracleLinux',
          'os2',
          'other24xLinux-64',
          'other24xLinux',
          'other26xLinux-64',
          'other26xLinux',
          'other3xLinux-64',
          'other3xLinux',
          'other',
          'otherGuest-64',
          'otherLinux-64',
          'otherLinux',
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
          'turboLinux-64',
          'turboLinux',
          'ubuntu-64',
          'ubuntu',
          'unixWare7',
          'vmkernel5',
          'vmkernel65',
          'vmkernel6',
          'vmkernel',
          'vmwarePhoton-64',
          'win2000AdvServ',
          'win2000Pro',
          'win2000Serv',
          'win31',
          'win95',
          'win98',
          'windows7-64',
          'windows7',
          'windows7Server-64',
          'windows8-64',
          'windows8',
          'windows8Server-64',
          'windows9-64',
          'windows9',
          'windows9Server-64',
          'windowsHyperV',
          'winLonghorn-64',
          'winLonghorn',
          'winMe',
          'winNetBusiness',
          'winNetDatacenter-64',
          'winNetDatacenter',
          'winNetEnterprise-64',
          'winNetEnterprise',
          'winNetStandard-64',
          'winNetStandard',
          'winNetWeb',
          'winNT',
          'winVista-64',
          'winVista',
          'winXPHome',
          'winXPPro-64',
          'winXPPro'
        ]
      end

      def finalize!
        @private_key_path = nil if @private_key_path == UNSET_VALUE
        @ssh_username = nil if @ssh_username == UNSET_VALUE
        @esxi_private_keys = @system_private_keys_path if @esxi_private_keys == UNSET_VALUE
        if @lax =~ /true/i
          @lax = 'True'
        else
          @lax = 'False'
        @virtualhw_version = @virtualhw_version.to_i unless @virtualhw_version.nil?
       end
     end
    end
  end
end
