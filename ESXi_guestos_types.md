VMware ESXi 6.5 guestOS types
=============================

Based on my research and some trial & error, I made this list of guestOS types that are compatible with ESXi 6.5.  I started with some api documenation from vmware that listed guestOS types.

>http://pubs.vmware.com/vsphere-6-5/index.jsp#com.vmware.wssdk.apiref.doc/vim.vm.GuestOsDescriptor.GuestOsIdentifier.html

But they didn't quite work when put directly in the vmx file...   I noticed none of my existing vmx files had the word "Guest" in guestOS line.  I also noticed in the list that the 64 bit entries were inconsistent.  (Some have _64, others are -64, and others are just 64.)   I removed the word Guest and set all the 64 bit OS's to be standard "-64".  The results seems to work for various OS's I installed, but I certainly didn't try all of these.    So here is my list...  Please report any errors.

Asianux:
'asianux3-64','asianux3','asianux4-64','asianux4','asianux5-64','asianux7-64'

Centos:
'centos6-64','centos-64','centos6','centos7-64','centos7','centos'

Darwin (mac):
'darwin10-64','darwin10','darwin11-64','darwin11','darwin12-64','darwin13-64','darwin14-64','darwin15-64','darwin16-64','darwin-64','darwin'

Debian:
'debian10-64','debian10','debian4-64','debian4','debian5-64','debian5','debian6-64','debian6','debian7-64','debian7','debian8-64','debian8','debian9-64','debian9'

Dos & Other:
'dos','os2','oes','other','sjds','coreos-64'

eComStation:
'eComStation2','eComStation'

Fedora:
'fedora-64','fedora'

FreeBSD:
'freebsd-64','freebsd'

Mandrake:
'mandrake','mandriva-64','mandriva'

Netware:
'netware4','netware5','netware6','nld9'

SCO:
'openServer5','openServer6','unixWare7'

SUSE:
'opensuse-64','opensuse','sles10-64','sles10','sles11-64','sles11','sles12-64','sles12','sles-64','sles','suse-64','suse'

Oracle Linux:
'oracleLinux6-64','oracleLinux-64','oracleLinux6','oracleLinux7-64','oracleLinux7','oracleLinux'

Other Linux:
'genericLinux','other24xLinux-64','other24xLinux','other26xLinux-64','other26xLinux','other3xLinux-64','other3xLinux','otherGuest-64','otherLinux-64','otherLinux'

Redhat:
'redhat','rhel2','rhel3-64','rhel3','rhel4-64','rhel4','rhel5-64','rhel5','rhel6-64','rhel6','rhel7-64','rhel7'

Solaris:
'solaris10-64','solaris10','solaris11-64','solaris6','solaris7','solaris8','solaris9'

TurboLInux:
'turboLinux-64','turboLinux'

Ubuntu:
'ubuntu-64','ubuntu'

VMware:
'vmkernel5','vmkernel65','vmkernel6','vmkernel','vmwarePhoton-64'

Windows:
'win2000AdvServ','win2000Pro','win2000Serv','win31','win95','win98','windows7-64','windows7','windows7Server-64','windows8-64','windows8','windows8Server-64','windows9-64','windows9','windows9Server-64','windowsHyperV','winLonghorn-64','winLonghorn','winMe','winNetBusiness','winNetDatacenter-64','winNetDatacenter','winNetEnterprise-64','winNetEnterprise','winNetStandard-64','winNetStandard','winNetWeb','winNT','winVista-64','winVista','winXPHome','winXPPro-64','winXPPro'
