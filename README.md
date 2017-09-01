vagrant-vmware-esxi plugin
==========================
This is a Vagrant plugin that adds a VMware ESXi provider support.  This allows Vagrant to control and provision VMs directly on an ESXi hypervisor without a need for vCenter or VShpere.   ESXi hypervisor is a free download from VMware! 
>https://www.vmware.com/go/get-free-esxi


Features
--------
* Any of the vmware Box formats should be compatible.
  * vmware_destop, vmware_fusion, vmware_workstation...
* Will automatically download boxes from the web.
* Will automatically upload the box to your ESXi host.
* Automatic or manual VM names.
  * Automatic VM names are "PREFIX-HOSTNAME-USERNAME-DIR".
* Multi machine capable.
* Supports adding your VM to a Resource Pools to partition CPU and memory usage from other VMs on your ESXi host.
* suspend / resume
* rsync, using built-in Vagrant synced folders.
* Provision using built-in Vagrant provisioner.

Requirements
------------
1. This plugin requires ovftool from VMware.  Download from VMware website.
>https://www.vmware.com/support/developer/ovf/
1. You MUST enable ssh access on your ESXi hypervisor.
  * Google 'How to enable ssh access on esxi'
1. The boxes should have open-vm-tools or vmware-tools installed.

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
  #    the system didn't have the vmware tools installed.
  #
  # Here are some of the MANY examples....
  config.vm.box = 'hashicorp/precise64'
  #config.vm.box = 'steveant/CentOS-7.0-1406-Minimal-x64'
  #config.vm.box = 'geerlingguy/ubuntu1604'
  #config.vm.box = 'laravel/homestead'
  #config.vm.box = 'centos/7'
  #config.vm.box = 'bento/ubuntu-14.04'

  #  Currently this tool supports rsync ONLY.   NFS is not working yet
  config.vm.synced_folder('.', '/Vagrantfiles', type: 'rsync')

  #
  #  Provider (esxi) settings
  #
  config.vm.provider :esxi do |esxi|

    #  REQUIRED!  ESXi hostname/IP
    #    You MUST specify a esxi_hostname or IP, uless you
    #    were lucky enough to name your esxi host "esxi".  :-)
    esxi.esxi_hostname = "esxi"

    #  ESXi username
    #    Default is "root".
    esxi.esxi_username = "root"

    #
    #  A NOTE about esxi_password / ssh keys!!
    #
    #    If you don't specify a password and do not use ssh
    #    keys, you wil; be entering your esxi password A LOT!
    #
    #    From your command line, you should be able to run
    #    following command without erros and be able to get to
    #    the esxi command prompt.
    #
    #      $ ssh root@ESXi_IP_ADDRESS

    #  IMPORTANT!  ESXi password.
    #    The ssh connections to esxi will try your ssh
    #    keys first.  However the ovftool does NOT!  To make
    #    vagrant up fully password-less, you will need to
    #    enter your password here....
    esxi.esxi_password = nil

    #  ESXi ssh keys
    #    The Default is to use system defaults, However
    #    you can specify an array of keys here...
    #esxi.esxi_private_keys = []

    #  SSH port.
    #    Default port 22
    #esxi.esxi_hostport = 22

    #  REQUIRED!  Virtual Network
    #    You MUST specify a Virtual Network!
    #    The default is fail if no Virtual Network is set!
    esxi.virtual_network = "vmnet_example"

    #  OPTIONAL.  Specify a Disk Store
    #    Default is to use the least used Disk Store.
    #esxi.vm_disk_store = "DS_001"

    #  OPTIONAL.  Guest VM name to be created/used.
    #    The Default will be automatically generated
    #    and will be based on the vmname_prefix,
    #    hostname, username, path...
    #esxi.vmname = "Custome_Guest_VM_Name"

    #  OPTIONAL.  When automatically naming VMs, use
    #    this prifix.
    #esxi.vmname_prefix = "V-"

    #  OPTIONAL.  Memory size override
    #    The default is to use the memory size specified in the
    #    vmx file, however you can specify a new value here.
    #esxi.memsize = "2048"

    #  OPTIONAL.  Virtual CPUs override
    #    The default is to use the number of virt cpus specified
    #     in the vmx file, however you can specify a new value here.
    #esxi.numvcpus = "2"

    #  OPTIONAL.  Resource Pool
    #    The default is to create VMs in the "root".  You can
    #     specify a resource pool here to partition memory and
    #     cpu usage away from other systems on your esxi host.
    #     The resource pool must already exist and be configured.
    #     Vagrant will NOT create it for you.
    #esxi.resource_pool = "/Vagrant"

    #  DANGEROUS!  Allow Overwrite
    #    Set this to 'True' will overwrite existing VMs (with the same name)
    #    when you run vagrant up.   ie,  if the vmname already exists,
    #    it will be destroyed, then over written...  This is helpful
    #    if you have a VM that vagrant lost control (lost association).
    #esxi.allow_overwrite = 'True'

  end
end
```

Basic usage
-----------
1. `vagrant up --provider=esxi`
1. To access the VM, use `vagrant ssh`
1. To destroy the VM, use `vagrant destroy`
1. Some other fun stuff you can do.
  * `vagrant status`
  * `vagrant suspend`
  * `vagrant resume`
  * `vagrant halt`
  * `vagrant provision`


Known issues
------------
* NFS using built-in Vagrant synced folders is not yet supported.
* Multi machines may not provision one VM if the boxes are different.
  * I found this seems to be a problem with libvirt also, so I'm assuming it's a vagrant problem...
* Cleanup doesn't always destroy a VM that has been partially built.  Use the allow_overwrite = 'True' option if you need to force a rebuild.
* ovftool for windows doesn't put ovftool.exe in your path.  You can manually set your path, or install ovftool in the \HashiCorp\Vagrant\bin directory.
