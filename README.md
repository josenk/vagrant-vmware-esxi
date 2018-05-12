vagrant-vmware-esxi plugin
==========================
This is a Vagrant plugin that adds a VMware ESXi provider support.  This allows Vagrant to control and provision VMs directly on an ESXi hypervisor without a need for vCenter or VShpere.   ESXi hypervisor is a free download from VMware!
>https://www.vmware.com/go/get-free-esxi

Documentation:
-------------
Refer to the WIKI for documentation, examples and other information...  
>https://github.com/josenk/vagrant-vmware-esxi/wiki


What's new!
-----------
Added support to clone from a VM!   Refer to the WIKI for documentation, example and other information.
>https://github.com/josenk/vagrant-vmware-esxi/wiki/How-to-clone_from_vm.

Features and Compatibility
--------------------------
* Clone from VMs.  Clone a VM on the esxi host instead of transferring a box stored on your local pc.
* Any of the vmware Box formats should be compatible.
  * vmware_desktop, vmware_fusion, vmware_workstation...
  * To be fully functional, you must have open-vm-tools or vmware tools installed.
* Will automatically download boxes from the web.
* Will automatically upload the box to your ESXi host.
* Automatic or manual VM names.
  * Automatic VM names are 'PREFIX-HOSTNAME-USERNAME-DIR'.
* Multi machine capable.
* Supports adding your VM to Resource Pools to partition CPU and memory usage from other VMs on your ESXi host.
* suspend, resume, snapshots.
* rsync & NFS using built-in Vagrant synced folders.
* Provision using built-in Vagrant provisioner.
* package your vm's into boxes.
* Create additional network interfaces, set nic type, MAC addresses, static IPs.
* Use Vagrants private_network, public_network options to set a static IP addresses on additional network interfaces.  (not the primary interface)
* Disks can be provisioned using thin, thick or eagerzeroedthick.
* Create additional guest storage (upto 14 virtual disks).
* Specify GuestOS types, virtual HW version.
* Any custom vmx settings can be added or modified.

Requirements
------------
1. This is a vagrant plugin, so you need vagrant installed...  :-)
2. This plugin requires ovftool from VMware.  Download from VMware website.  NOTE: ovftool installer for windows doesn't put ovftool.exe in your path.  You can manually set your path, or install ovftool in the \HashiCorp\Vagrant\bin directory.
>https://www.vmware.com/support/developer/ovf/
3. You MUST enable ssh access on your ESXi hypervisor.
  * Google 'How to enable ssh access on esxi'
4. The boxes must have open-vm-tools or vmware-tools installed to properly transition to the 'running' state.
5. In general, you should know how to use vagrant, esxi and some networking...

Why this plugin?
----------------
Not everyone has vCenter / vSphere...  vCenter cost $$$.  ESXi is free!
Using this plugin will allow you to use a central VMware ESXi host for your development needs.  Using a centralized host will release the extra load on your local system (vs using KVM or Virtual Box).

How to install
--------------
Download and install Vagrant on your local system using instructions from https://vagrantup.com/downloads.html.   
```
vagrant plugin install vagrant-vmware-esxi
vagrant plugin list
vagrant version
```
How to use and configure a Vagrantfile
--------------------------------------

1. cd SOMEDIR
1. `vagrant init`
1. `vi Vagrantfile`  # Replace the contents of Vagrantfile with the following example. Specify parameters to access your ESXi host, guest and local preferences.
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
  #    the box/vm doesn't have the vmware tools installed.
  #
  # Here are some of the MANY examples....
  config.vm.box = 'generic/centos7'
  #config.vm.box = 'generic/centos6'
  #config.vm.box = 'generic/fedora27'
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

  #  Vagrant can configure additional network interfaces using a static IP or
  #  DHCP. Use public_network or private_network to manually set a static IP and
  #  optionally netmask.  ESXi doesn't use the concept of public or private
  #  networks so both are valid here.  The primary network interface is considered the
  #  "vagrant management" interface and cannot be changed and this plugin
  #  supports 4 NICS, so you can specify 3 entries here!
  #
  #  https://www.vagrantup.com/docs/networking/public_network.html
  #  https://www.vagrantup.com/docs/networking/private_network.html
  #
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

    #  HIGHLY RECOMMENDED!  ESXi Virtual Network
    #    You should specify an ESXi Virtual Network!  If it's not specified, the
    #    default is to use the first found.  You can specify up to 4 virtual
    #    networks using an array format.
    #esxi.esxi_virtual_network = ['VM Network','VM Network2','VM Network3','VM Network4']

    #  OPTIONAL.  Specify a Disk Store
    #esxi.esxi_disk_store = 'DS_001'

    #  OPTIONAL.  Resource Pool
    #     Vagrant will NOT create a Resource pool it for you.
    #esxi.esxi_resource_pool = '/Vagrant'

    #  Optional. Specify a VM to clone instead of uploading a box.
    #    Vagrant can use any stopped VM as the source 'box'.   The VM must be
    #    registered, stopped and must have the vagrant insecure ssh key installed.
    #    If the VM is stored in a resource pool, it must be specified.
    #    See wiki: https://github.com/josenk/vagrant-vmware-esxi/wiki/How-to-clone_from_vm.
    #esxi.clone_from_vm = 'resource_pool/source_vm'

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

    #  OPTIONAL. Boot disk size.
    #    If unspecified, the boot disk size will be the same as the original
    #    box.  You can specify a larger boot disk size in GB.  The extra disk space
    #    will NOT automatically be available to your OS.  You will need to
    #    create or modify partitions, LVM and/or filesystems.
    #esxi.guest_boot_disk_size = 50

    #  OPTIONAL.  Create additional storage for guests.
    #    You can specify an array of up to 13 virtual disk sizes (in GB) that you
    #    would like the provider to create once the guest has been created.
    #esxi.guest_storage = [ 10, 20, { size: 30, datastore: 'datastore1' } ]

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

    #  OPTIONAL. Guest IP Caching
    #esxi.local_use_ip_cache = 'True'

    #  DANGEROUS!  Allow Overwrite
    #    If unspecified, the default is to produce an error if overwriting
    #    vm's and packages.
    #esxi.local_allow_overwrite = 'True'

    #  Plugin debug output.
    #    Please send any bug reports with debug this output...
    #esxi.debug = 'true'

  end
end
```


Basic usage
-----------
1. `vagrant up --provider=vmware_esxi`
1. To access the VM, use `vagrant ssh`
1. To destroy the VM, use `vagrant destroy`
1. Some other fun stuff you can do.
  * `vagrant status`
  * `vagrant suspend`
  * `vagrant resume`
  * `vagrant ssh-config`
  * `vagrant snapshot push`
  * `vagrant snapshot list`
  * `vagrant snapshot-info`
  * `vagrant snapshot pop`  
  * `vagrant halt`
  * `vagrant provision`



Upgrading from vagrant-vmware-esxi 1.x.x
----------------------------------------
See wiki for more information.
>https://github.com/josenk/vagrant-vmware-esxi/wiki/Upgrading-from-vagrant-vmware-esxi-1.x.x


Known issues with vmware_esxi
-----------------------------
* The boxes must have open-vm-tools or vmware-tools installed to properly transition to the 'running' state.
* Invalid settings (bad IP address, netmask, MAC address, guest_custom_vmx_settings) could cause 'vagrant up' to fail.  Review vSphere console and/or ESXi logs to help debug why it failed.
* Cleanup doesn't always destroy a VM that has been partially built.  Use the local_allow_overwrite = 'True' option if you need to force a rebuild, or you can delete the vm using the VSphere client.
* ovftool installer for windows doesn't put ovftool.exe in your path.  You can manually set your path, or install ovftool in the \HashiCorp\Vagrant\bin directory.
* Vagrant NFS synced folders is not reliable on multi-homed clients (your vagrant pc/laptop/host).  There is no 100% reliable way to know which IP is the correct, most reliable, most desirable, etc...
* V2.0.1 - 2.0.5 is not compatible with Windows (to support ed25519 ssh keys, net-ssh requires libsodium but it's not compatible with Windows).  ed25519 support has been removed for now.   It will be added back when net-ssh 5.x goes out of beta.
* Cygwin & gitbash have console issues. Ruby module io/console does not have support.  https://github.com/ruby/io-console/issues/2
* Setting the hostname might fail on some boxes.  Use most recent version of Vagrant for best results.   


Version History
---------------
* 2.2.1 Fix, clone_from_vm not working on MAC.
        Fix, enabled SetHostname.
        Fix, Multimachine not working with multiple esxi hosts and different passwords.

* 2.2.0 Add support to extend boot disk size.
        Fix, add many more special characters to encode in esxi passwords.

* 2.1.0 Add support for clone_from_vm.
        Fix, use esxcli to get storage information.

* 2.0.7 Fix, Doesn't wait for running when executing "vagrant reload"
        Fix, "vagrant halt" will now attempt a graceful shutdown before doing a hard power off.

* 2.0.6 Fix Windows compatibility by not supporting ed25519 ssh keys.  When net-ssh 5.x is released AND vagrant allows it's use, I will support ed25519 again.
        Fix, encode '/' in esxi passwords.
        Fix, Get local IP address for NFS syncd folders.  Filter out localhost 127.0.0.0/8.
        Work-around 'prompt:' issues with unsupported consoles. Cygwin & gitbash, for example.

* 2.0.5 Performance enhancement. Guest IP caching
        Performance enhancement. Optimize esxi connectivity checks.
        Performance enhancement & bugfix.  Get local IP address for NFS syncd folders.
        Fix, unable to get VMID if getallvms command produces any errors (for other vms).

* 2.0.2 Add support to add additional storage to guest vms.
        Fix, encode (space) in esxi passwords.

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
