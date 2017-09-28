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
      attr_accessor :vm_disk_store
      attr_accessor :virtual_network
      attr_accessor :resource_pool
      attr_accessor :memsize
      attr_accessor :numvcpus
      attr_accessor :custom_vmx_settings
      attr_accessor :allow_overwrite
      attr_accessor :debug
      attr_accessor :system_private_keys_path
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
        @vm_disk_store = nil
        @virtual_network = nil
        @resource_pool = nil
        @memsize = UNSET_VALUE
        @numvcpus = UNSET_VALUE
        @custom_vmx_settings = UNSET_VALUE
        @allow_overwrite = 'False'
        @debug = 'False'
        @system_private_keys_path = [
          '~/.ssh/id_rsa',
          '~/.ssh/id_ecdsa',
          '~/.ssh/id_ed25519',
          '~/.ssh/id_dsa'
        ]
      end

      def finalize!
        @private_key_path = nil if @private_key_path == UNSET_VALUE
        @ssh_username = nil if @ssh_username == UNSET_VALUE
        @esxi_private_keys = @system_private_keys_path if @esxi_private_keys == UNSET_VALUE
      end
    end
  end
end
