vagrant-vmware-esxi plugin
==========================
This is a Vagrant plugin that adds a VMware ESXi provider support.  This allows Vagrant to control and provision VMs directly on an ESXi hypervisor without a need for vCenter or VShpere.   ESXi hypervisor is a free download from VMware!
>https://www.vmware.com/go/get-free-esxi


Features and Compatibility
--------------------------
* Any of the vmware Box formats should be compatible.
  * vmware_desktop, vmware_fusion, vmware_workstation...
  * To be fully functional, you must have open-vm-tools or vmware tools installed
* Will automatically download boxes from the web.
* Will automatically upload the box to your ESXi host.
* Automatic or manual VM names.
  * Automatic VM names are "PREFIX-HOSTNAME-USERNAME-DIR".
* Multi machine capable.
* Supports adding your VM to Resource Pools to partition CPU and memory usage from other VMs on your ESXi host.
* suspend / resume.
* snapshots.
* rsync & NFS using built-in Vagrant synced folders.
* Provision using built-in Vagrant provisioner.
* package

Requirements
------------
1. This is a vagrant plugin, so you need vagrant installed...  :-)
2. This plugin requires ovftool from VMware.  Download from VMware website.
>https://www.vmware.com/support/developer/ovf/
3. You MUST enable ssh access on your ESXi hypervisor.
  * Google 'How to enable ssh access on esxi'
4. The boxes must have open-vm-tools or vmware-tools installed to properly transition to the "running" state.

Why this plugin?
----------------
Not everyone has vCenter / vSphere...  vCenter cost $$$.  ESXi is free!

How to install
--------------
```
vagrant plugin install vagrant-vmware-esxi
```
How to configure
----------------

1. cd SOMEDIR
1. `vagrant init`
1. `vi Vagrantfile`  # setup access your ESXi host and to set some preferences.
```ruby
Vagrant.configure("2") do |config|

  #  Box, Select any box created for VMware that is compatible with
  #    the ovftool.  To get maximum compatiblity You should download
  #    and install the latest version for your OS.
  #    https://www.vmware.com/support/developer/ovf/
  #
  #    If your box is stuck at "Powered On", then most likely
  #    the system doesn't have the vmware tools installed.
  #
  # Here are some of the MANY examples....
  config.vm.box = 'hashicorp/precise64'
  #config.vm.box = 'steveant/CentOS-7.0-1406-Minimal-x64'
  #config.vm.box = 'geerlingguy/ubuntu1604'
  #config.vm.box = 'laravel/homestead'
  #config.vm.box = 'bento/ubuntu-14.04'
  #config.vm.box = 'generic/centos7'
  #config.vm.box = 'generic/fedora26'
  #config.vm.box = 'generic/alpine36'


  #  Supports type rsync and NFS.
  config.vm.synced_folder('.', '/Vagrantfiles', type: 'rsync')

  #
  #  Provider (esxi) settings
  #
  config.vm.provider :vmware_esxi do |esxi|

    #  REQUIRED!  ESXi hostname/IP
    #    You MUST specify a esxi_hostname or IP, uless you
    #    were lucky enough to name your esxi host "esxi".  :-)
    esxi.esxi_hostname = "esxi"

    #  ESXi username
    #    Default is "root".
    esxi.esxi_username = "root"

    #
    #  IMPORTANT!  ESXi password.
    #  *** NOTES about esxi_password & ssh keys!! ***
    #
    #    1) "prompt:"
    #       This will prompt you for the esxi password each time you
    #       run a vagrant command.  This is the default.
    #
    #    2) "file:"  or  "file:my_secret_file"
    #       This will read a plain text file containing the esxi
    #       password.   The default filename is ~/.esxi_password, or
    #       you can specify any filename after the colon ":".
    #
    #    3) "env:"  or "env:my_secret_env_var"
    #        This will read the esxi password via a environment
    #        variable.  The default is $esxi_password, but you can
    #        specify any environment variable after the colon ":".
    #
    #            $ export esxi_password="my_secret_password"
    #
    #    4)  "key:"  or  key:~/.ssh/some_ssh_private_key"
    #        Use ssh keys.  The default is to use the system private keys,
    #        or you specify a custom private key after the colon ":".
    #
    #        To test connectivity. From your command line, you should be able to
    #        run following command without an error and get an esxi prompt.
    #
    #            $ ssh root@ESXi_IP_ADDRESS
    #
    #        The ssh connections to esxi will try the ssh private
    #        keys.  However the ovftool does NOT!  To make
    #        vagrant fully password-less, you will need to use other
    #        options. (set the passord, use "env:" or "file:")
    #
    #    5)  esxi.esxi_password = "my_esxi_password"
    #        Enter your esxi passowrd in clear text here...  This is the
    #        least secure method because you may share this Vagrant file without
    #        realizing the password is in clear text.
    #
    #  IMPORTANT!  Set the ESXi password or authentication method..
    esxi.esxi_password = "prompt:"

    #  ESXi ssh keys.   (This is depreciated!!!)
    #    The Default is to use system default ssh keys, However
    #    you can specify an array of keys here...
    #
    #   ***  Depreciated, use esxi_password = "key:" instead. ***
    #esxi.esxi_private_keys = []

    #  SSH port.
    #    Default port 22.
    #esxi.esxi_hostport = 22

    #  HIGHLY RECOMMENDED!  Virtual Network
    #    You should specify a Virtual Network!  If it's not specified, the
    #    default is to use the first found.
    #    You can specify up to 4 virtual networks using an array
    #    format.  Note that Vagrant only looks at the first
    #    interface for a valid IP address.
    #esxi.virtual_network = "vmnet_example"
    #esxi.virtual_network = ["vmnet1","vmnet2","vmnet3","vmnet4"]

    #  OPTIONAL.  Specify a Disk Store
    #    If it's not specified, the Default is to use the least used Disk Store.
    #esxi.vm_disk_store = "DS_001"

    #  OPTIONAL.  Guest VM name to be created/used.
    #    The Default will be automatically generated
    #    and will be based on the vmname_prefix,
    #    hostname, username, path.  Otherwise you
    #    can set a fixed guest VM name here.
    #esxi.vmname = "Custom-Guest-VM_Name"

    #  OPTIONAL.  When automatically naming VMs, use
    #    this prifix.
    #esxi.vmname_prefix = "V-"

    #  OPTIONAL.  Memory size override
    #    The default is to use the memory size specified in the
    #    vmx file, however you can specify a new value here.
    #esxi.memsize = "2048"

    #  OPTIONAL.  Virtual CPUs override
    #    The default is to use the number of virtual cpus specified
    #     in the vmx file, however you can specify a new value here.
    #esxi.numvcpus = "2"

    #  OPTIONAL.  Resource Pool
    #    If unspecified, the default is to create VMs in the "root".  You can
    #    specify a resource pool here to partition memory and cpu usage away
    #    from other systems on your esxi host.  The resource pool must
    #    already exist and have the proper permissions set.
    #     
    #     Vagrant will NOT create a Resource pool it for you.
    #esxi.resource_pool = "/Vagrant"

    #  DANGEROUS!  Allow Overwrite
    #    If unspecified, the default is to produce an error if overwriting
    #    vm's and packages.
    #    Set this to 'True' will overwrite existing VMs (with the same name)
    #    when you run vagrant up.   ie,  if the vmname already exists,
    #    it will be destroyed, then over written...  This is helpful
    #    if you have a VM that became an orphan (vagrant lost association).
    #    This will also overwrite your box when using vagrant package.
    #esxi.allow_overwrite = 'True'

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
  * `vagrant snapshot push`
  * `vagrant snapshot list`
  * `vagrant snapshot-info`
  * `vagrant snapshot pop`  
  * `vagrant halt`
  * `vagrant provision`


Known issues with vmware_esxi
-----------------------------
* The boxes must have open-vm-tools or vmware-tools installed to properly transition to the "running" state.
* Cleanup doesn't always destroy a VM that has been partially built.  Use the allow_overwrite = 'True' option if you need to force a rebuild.
* ovftool installer for windows doesn't put ovftool.exe in your path.  You can manually set your path, or install ovftool in the \HashiCorp\Vagrant\bin directory.
* Built-in Vagrant synced folders using NFS fails if you try to re-provision.
  * In general I find NFS synced folders pretty "flaky" anyways...
* Multi machines may not provision one VM if the boxes are different.
  * I found this problem with libvirt also, so I'm assuming it's a vagrant problem...

Version History
---------------
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
