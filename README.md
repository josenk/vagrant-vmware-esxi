vagrant-vmware-esxi plugin
==========================
This is a Vagrant plugin that adds a VMware ESXi provider support.  This allows Vagrant to control and provision VMs directly on an ESXi hypervisor without a need for vCenter or VShpere.   ESXi hypervisor is a free download from VMware!
>https://www.vmware.com/go/get-free-esxi

Documentation:
-------------
Refer to the WIKI for documentation, examples and other information...  
>https://github.com/josenk/vagrant-vmware-esxi/wiki



Features and Compatibility
--------------------------
* Any of the vmware Box formats should be compatible.
  * vmware_desktop, vmware_fusion, vmware_workstation...
  * To be fully functional, you must have open-vm-tools or vmware tools installed.
* Will automatically download boxes from the web.
* Will automatically upload the box to your ESXi host.
* Automatic or manual VM names.
  * Automatic VM names are 'PREFIX-HOSTNAME-USERNAME-DIR'.
* Multi machine capable.
* Supports adding your VM to Resource Pools to partition CPU and memory usage from other VMs on your ESXi host.
* suspend / resume.
* snapshots.
* rsync & NFS using built-in Vagrant synced folders.
* Provision using built-in Vagrant provisioner.
* package your vm's into boxes.
* Create additional network interfaces, set nic type, MAC addresses, static IPs.
* Use Vagrants private_network, public_network options to set a static IP addresses on additional network interfaces.  (not the primary interface)
* Disks provisioned using thin, thick or eagerzeroedthick.
* Specify GuestOS types, virtual HW version, or any custom vmx settings.

Requirements
------------
1. This is a vagrant plugin, so you need vagrant installed...  :-)
2. This plugin requires ovftool from VMware.  Download from VMware website.
>https://www.vmware.com/support/developer/ovf/
3. You MUST enable ssh access on your ESXi hypervisor.
  * Google 'How to enable ssh access on esxi'
4. The boxes must have open-vm-tools or vmware-tools installed to properly transition to the 'running' state.
5. In general, you should know how to use vagrant and esxi...

Why this plugin?
----------------
Not everyone has vCenter / vSphere...  vCenter cost $$$.  ESXi is free!
Using this plugin will allow you to use a central VMware ESXi host for your development needs.  Using a centralized host will release the extra load on your local system (vs using KVM or Virtual Box).

How to install
--------------
Download and install Vagrant on your local system using instructions from https://vagrantup.com/downloads.html.   
```
vagrant plugin install vagrant-vmware-esxi
vagrant version
```
How to use and configure a Vagrantfile
--------------------------------------

1. cd SOMEDIR
1. `vagrant init`
1. `vi Vagrantfile`  # See below to setup access your ESXi host and to set some preferences.
```ruby
#
#  Fully documented Vagrantfile available
#  in the wiki:  https://github.com/josenk/vagrant-vmware-esxi/wiki
Vagrant.configure('2') do |config|

  #  Box, Select any box created for VMware that is compatible with
  #    the ovftool.  To get maximum compatibility You should download
  #    and install the latest version of ovftool for your OS.
  #    https://www.vmware.com/support/developer/ovf/
  #
  #    If your box is stuck at 'Powered On', then most likely
  #    the system doesn't have the vmware tools installed.
  #
  # Here are some of the MANY examples....
  config.vm.box = 'generic/centos7'
  #config.vm.box = 'generic/centos6'
  #config.vm.box = 'generic/fedora26'
  #config.vm.box = 'generic/freebsd11'
  #config.vm.box = 'generic/ubuntu1710'
  #config.vm.box = 'generic/debian9'
  #config.vm.box = 'hashicorp/precise64'
  #config.vm.box = 'steveant/CentOS-7.0-1406-Minimal-x64'
  #config.vm.box = 'geerlingguy/centos7'
  #config.vm.box = 'geerlingguy/ubuntu1604'
  #config.vm.box = 'laravel/homestead'
  #config.vm.box = 'puphpet/debian75-x64'


  #  Use rsync and NFS synced folders. (or disable them)
  config.vm.synced_folder('.', '/vagrant', type: 'rsync')
  config.vm.synced_folder('.', '/vagrant', type: 'nfs', disabled: true)

  #  Vagrant can set a static IP for the additional network interfaces.  Use
  #  public_network or private_network to manually set a static IP and
  #  netmask.  ESXi doesn't use the concept of public or private networks so
  #  both are valid here.  The primary network interface is considered the
  #  "vagrant management" interface and cannot be changed,
  #  so you can specify 3 entries here!
  #    *** Invalid settings could cause 'vagrant up' to fail ***
  #config.vm.network 'private_network', ip: '192.168.10.170', netmask: '255.255.255.0'
  #config.vm.network 'private_network', ip: '192.168.11.170'
  #config.vm.network 'public_network', ip: '192.168.12.170'

  #
  #  Provider (esxi) settings
  #
  config.vm.provider :vmware_esxi do |esxi|

    #  REQUIRED!  ESXi hostname/IP
    esxi.esxi_hostname = 'esxi'

    #  ESXi username
    esxi.esxi_username = 'root'

    #  IMPORTANT!  Set ESXi password.
    #    1) 'prompt:'
    #    2) 'file:'  or  'file:my_secret_file'
    #    3) 'env:'  or 'env:my_secret_env_var'
    #    4) 'key:'  or  key:~/.ssh/some_ssh_private_key'
    #    5) or esxi.esxi_password = 'my_esxi_password'
    #
    esxi.esxi_password = 'prompt:'

    #  SSH port.
    #esxi.esxi_hostport = 22

    #  HIGHLY RECOMMENDED!  Virtual Network
    #    You should specify a Virtual Network!  If it's not specified, the
    #    default is to use the first found.  You can specify up to 4 virtual
    #    networks using an array format.
    #esxi.esxi_virtual_network = ['vmnet1','vmnet2','vmnet3','vmnet4']

    #  OPTIONAL.  Specify a Disk Store
    #esxi.esxi_disk_store = 'DS_001'

    #  OPTIONAL.  Resource Pool
    #     Vagrant will NOT create a Resource pool it for you.
    #esxi.esxi_resource_pool = '/Vagrant'

    #  OPTIONAL.  Guest VM name to use.
    #    The Default will be automatically generated.
    #esxi.guest_name = 'Custom-Guest-VM_Name'

    #  OPTIONAL.  When automatically naming VMs, use this prifix.
    #esxi.guest_name_prefix = 'V-'


    #  OPTIONAL.  Set the guest username login.  The default is 'vagrant'.
    #esxi.guest_username = 'vagrant'

    #  OPTIONAL.  Memory size override
    #esxi.guest_memsize = '2048'

    #  OPTIONAL.  Virtual CPUs override
    #esxi.guest_numvcpus = '2'

    #  OPTIONAL & RISKY.  Specify up to 4 MAC addresses
    #    The default is ovftool to automatically generate a MAC address.
    #    You can specify an array of MAC addresses using upper or lower case,
    #    separated by colons ':'.
    #esxi.guest_mac_address = ['00:50:56:aa:bb:cc', '00:50:56:01:01:01','00:50:56:02:02:02','00:50:56:BE:AF:01' ]

    #   OPTIONAL & RISKY.  Specify a guest_nic_type
    #     The validated list of guest_nic_types are 'e1000', 'e1000e', 'vmxnet',
    #     'vmxnet2', 'vmxnet3', 'Vlance', and 'Flexible'.
    #esxi.guest_nic_type = 'e1000'

    #  OPTIONAL. Specify a disk type.
    #    If unspecified, it will be set to 'thin'.  Otherwise, you can set to
    #    'thin', 'thick', or 'eagerzeroedthick'
    #esxi.guest_disk_type = 'thick'

    #  OPTIONAL. specify snapshot options.
    #esxi.guest_snapshot_includememory = 'true'
    #esxi.guest_snapshot_quiesced = 'true'

    #  RISKY. guest_guestos
    #    https://github.com/josenk/vagrant-vmware-esxi/ESXi_guest_guestos_types.md
    #esxi.guest_guestos = 'centos-64'

    #  OPTIONAL. guest_virtualhw_version
    #    ESXi 6.5 supports these versions. 4,7,8,9,10,11,12 & 13.
    #esxi.guest_virtualhw_version = '9'

    #  RISKY. guest_custom_vmx_settings
    #esxi.guest_custom_vmx_settings = [['vhv.enable','TRUE'], ['floppy0.present','TRUE']]

    #  OPTIONAL. local_lax
    #esxi.local_lax = 'true'

    #  DANGEROUS!  Allow Overwrite
    #    If unspecified, the default is to produce an error if overwriting
    #    vm's and packages.
    #esxi.local_allow_overwrite = 'True'

    #  Plugin debug output.
    #    Send bug reports with debug output...
    #esxi.debug = 'true'

  end
end
```

Upgrading from vagrant-vmware-esxi 1.x.x
----------------------------------------
The following Vagrantfile parameters have been renamed for clarity.  The plugin still recognizes these legacy parameters, however it's recommended to migrate to the 2.x parameters.
* esxi_private_keys --> esxi_password = "key:"
* vm_disk_store --> esxi_disk_store
* virtual_network --> esxi_virtual_network
* resource_pool --> esxi_resource_pool
* vmname --> guest_name
* vmname_prefix --> guest_name_prefix
* ssh_username --> guest_username
* memsize --> guest_memsize
* numvcpus --> guest_numvcpus
* vm_disk_type --> guest_disk_type
* nic_type --> guest_nic_type
* mac_address --> guest_mac_address
* guestos --> guest_guestos
* virtualhw_version --> guest_virtualhw_version
* custom_vmx_settings --> guest_custom_vmx_settings
* lax --> local_lax
* allow_overwrite --> local_allow_overwrite


Basic usage
-----------
1. `vagrant up --provider=vmware_esxi`
1. To access the VM, use `vagrant ssh`
1. To destroy the VM, use `vagrant destroy`
1. Some other fun stuff you can do.
  * `vagrant status`
  * `vagrant suspend`
  * `vagrant resume`
  * `vagrant snapshot push`
  * `vagrant snapshot list`
  * `vagrant snapshot-info`
  * `vagrant snapshot pop`  
  * `vagrant halt`
  * `vagrant provision`


Known issues with vmware_esxi
-----------------------------
* The boxes must have open-vm-tools or vmware-tools installed to properly transition to the 'running' state.
* Invalid settings (bad IP address, netmask, MAC address, guest_custom_vmx_settings) could cause 'vagrant up' to fail.  Review your ESXi logs to help debug why it failed.
* Cleanup doesn't always destroy a VM that has been partially built.  Use the local_allow_overwrite = 'True' option if you need to force a rebuild, or delete the vm using the VSphere client.
* ovftool installer for windows doesn't put ovftool.exe in your path.  You can manually set your path, or install ovftool in the \HashiCorp\Vagrant\bin directory.
* In general I find NFS synced folders a little 'flaky'...


Version History
---------------
* 2.0.1 Updated version:
      Most Vagrantfile options have been renamed to be consistent and for clarity.
      vagrant up, more organized summary by esxi/guest options.
      Lots of Code cleanup.
      Add support for snapshot options (includeMemory & quiesced)
      Snapshot save/push adds a description.

* 1.5.1 Fix:
      Improve debug output.
      Fix password encoding for @ character.
      Automatically add a virtual network when configuring a public_network or private_network.

* 1.5.0 Add support for:
      Specify guest_custom_vmx_settings (to add or modify vmx settings).
      Specify Virtual HW version.
      Allow $ in Password.
      Disk types (thick, thin, eagerzeroedthick).
      Specify a guestOS type (see list above).
      Relocal_laxed ovftool setting (--local_lax), to allow importing strange ovf boxes.

* 1.4.0 Add support to set MAC and IP addresses for network interfaces.
* 1.3.2 Fix, Don't timeout ssh connection when ovftool takes a long time to upload image.
* 1.3.0 Add support to get esxi password from env, from a file or prompt.
* 1.2.1 Encode special characters in password.
* 1.2.0 Add support for up to 4 virtual networks.
* 1.7.1 Show all port groups for each virtual switch instead of just the first.
* 1.1.6 Update documenation.
* 1.1.5 Add more detailed information when waiting for state (running).
* 1.1.4 Update documentation.
* 1.1.3 Add support to create package.
* 1.1.2 Fix, reload.
* 1.1.1 Add support for NFS.
* 1.1.0 Add support for snapshots.
* 1.0.1 Init commit.

Feedback please!
----------------
* To help improve this plugin, I'm requesting that you provide some feedback.
* https://goo.gl/forms/tY14mE77HJvhNvjj1
