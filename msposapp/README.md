MS POS Cloud Service
------------------------

Teleflora Managed Services Linux Point of Sale Applications deployed in Amazon AWS.



Overview
------------------------

This solution provides for the Teleflora Managed Services Linux Point of Sale applications to run in the cloud on a single-host Docker environment with a 1:1 container to host ratio, in a private cloud network accessible by all branch locations of the customer. It will utilize as many of the existing, proven compliant, internal processes for delivering a Point of Sale system as possible. This application serves to manage those processes as well as a few additional ones from inserting the container layer. The end result will be a simple set of instructions (menu driven) to: Build, stage, and deploy a customer's Point of Sale server into the cloud, quickly, with no loss of data and minimal downtime.

![](https://github.com/mykol-com/MSCloudServer/blob/master/msposapp/pics/RTI_cloud1.png)

Requirements
------------------------

- Very low cost.

- Minimal use of support time or resources.

- Automated build process.

- PA-DSS compliant.

- Minimal impact to other processes.

- Able to expand to a share-hosted style, or host multiple customers with one cloud account.

- Fast, repeatable, installation and configuration of Prod, QA, and Dev instances.

- Allow for ease to add other Teleflora POS Linux applications.

- Teleflora Managed Services Linux Cloud Backup Service.

- Minimal maintenance added to what is already done for the Point of Sale instance itself.

- Reporting; track use for billing, performance, and compliance purposes.

- Self-contained: The intention is to promote the conversion of physical Point of Sale machines to virtual. The POS servers need to be independant of each other. (An outage by one doesnt affect the many.)

- Ipsec VPN connection information for each remote location wanting to use this server.



Design
------------------------

The solution can be considered in 4 peices (Each having different compliance implications):

1. Build (media creation):

	An automated build process, using containers, to quickly produce OS media prepared with all the required components needed by the OS and application installation. Technically, the use of pre-prepared media from a marketplace, appstore, or other 3rd party, isn't recommended for PCI compliance. Additionally, in a catastrophic situation, quickly matching patch levels from a customer's physical server becomes a requirement.


  ```
01/18/2019 10:09 AM
┏━━━━━━━━━
┃🌷 POS Cloud Menu 
┣━
┃ Mike's Store of Stuff
┃ 12345678
┃
┃ Status: 
┃ POS IP: 192.168.222.233
┃
┃ 1. POS Status
┃ 2. Start POS
┃ 3. Stop POS
┃ 4. Connect to POS
┃ 5. Restore POS Data
┃
┃ 11. List Images
┃ 12. Build OS Media
┃ 13. Stage POS
┃ 14. Delete Image(s)
┃ 15. POS Snapshot
┃
┃ 111. VPN Status
┃ 112. Create VPN
┃ 113. Start VPN(s)
┃ 114. Stop VPN(s)
┃ 115. Delete VPN(s)
┃
┃ p. Purge All
┃ i. I/C/U Deps
┃ r. Readme
┃ x. Exit
┗━
Enter selection: 12
daisy or rti?: rti 

Starting installer, one moment...
anaconda argparse: terminal size detection failed, using default width
[Errno 25] Inappropriate ioctl for device
anaconda 21.48.22.147-1 for CentOS 7 Docker 7 (pre-release) started.
Starting automated install............
Checking software selection
================================================================================
================================================================================
Installation

 1) [x] Language settings                 2) [x] Time settings
        (English (United States))                (America/Chicago timezone)
 3) [x] Installation source               4) [x] Software selection
        (http://mirrors.kernel.org/cent          (Custom software selected)
        os/7/os/x86_64/)
 5) [x] Network configuration
        (Connected: eth1, docker0 (),
        ens5)
================================================================================
================================================================================
Progress
Setting up the installation environment
.
Running pre-installation scripts
j.
Starting package installation process
Preparing transaction from installation source
Installing libgcc (1/615)
Installing fontpackages-filesystem (2/615)
Installing poppler-data (3/615)
Installing libreport-filesystem (4/615)
Installing bind-license (5/615)
Installing langtable (6/615)
	.  
	.. 
	...
Removing intermediate container bbd1052e4a93
Step 29/31 : EXPOSE 445
 ---> Running in d7e162ea6127
 ---> 1eede00a7e58
Removing intermediate container d7e162ea6127
Step 30/31 : EXPOSE 631
 ---> Running in ca7a4630aeb5
 ---> d0ed99e5e25d
Removing intermediate container ca7a4630aeb5
Step 31/31 : CMD [“/usr/bin/bash”]
 ---> Running in b6530f49b66c
 ---> 8b1cc27630a5
Removing intermediate container b6530f49b66c
Successfully built 8b1cc27630a5
/home/tfsupport/msposapp/bin

real    14m16.460s
user    12m7.525s
sys     0m40.405s
Press enter to continue..
  ```

  ```
	Enter selection: 11
	REPOSITORY                         TAG                 IMAGE ID            CREATED             SIZE
	centos7-rti-16.1.3                 latest              05b1c483ffcf        19 seconds ago      1.38 GB
	Press enter to continue..
  ```


2. Staging (Assign to a customer, install OS, and run application installation from media):

	Prepare the linux boot volume, combine with added required pieces needed for deployment from managed services for the application installation, run through the installation process, then commit to the resulting container.


  ```
01/18/2019 10:27 AM
┏━━━━━━━━━
┃🌷 POS Cloud Menu 
┣━
┃ Mike's Store of Stuff
┃ 12345678
┃
┃ Status: 
┃ POS IP: 192.168.222.233
┃
┃ 1. POS Status
┃ 2. Start POS
┃ 3. Stop POS
┃ 4. Connect to POS
┃ 5. Restore POS Data
┃
┃ 11. List Images
┃ 12. Build OS Media
┃ 13. Stage POS
┃ 14. Delete Image(s)
┃ 15. POS Snapshot
┃
┃ 111. VPN Status
┃ 112. Create VPN
┃ 113. Start VPN(s)
┃ 114. Stop VPN(s)
┃ 115. Delete VPN(s)
┃
┃ p. Purge All
┃ i. I/C/U Deps
┃ r. Readme
┃ x. Exit
┗━
Enter selection: 13
daisy or rti?: rti
	--2018-11-15 00:43:25--  http://rtihardware.homelinux.com/ostools/ostools-1.15-latest.tar.gz
	Resolving rtihardware.homelinux.com (rtihardware.homelinux.com)... 209.141.208.120
	Connecting to rtihardware.homelinux.com (rtihardware.homelinux.com)|209.141.208.120|:80... connected.
	HTTP request sent, awaiting response... 200 OK
	Length: 367453 (359K) [application/x-gzip]
	Saving to: 'ostools-1.15-latest.tar.gz'
	
	     0K .......... .......... .......... .......... .......... 13%  394K 1s
	    50K .......... .......... .......... .......... .......... 27%  726K 1s
...
..
.
```

```
Installed:
  strongswan.x86_64 0:5.7.1-1.el7    strongswan-libipsec.x86_64 0:5.7.1-1.el7   

Complete!
Error response from daemon: No such container: yum
Create Primary VPN for this POS? (y/n): y
Gathering required information....
Enter LOCATION_NAME: phonehome
Enter POS_CLOUD_NETWORK: 192.168.222.0  
Enter MAINSTORE_PUBLIC: 70.175.163.115
Enter MAINSTORE_NET: 192.168.22.0
Enter PRESHAREDKEY: Telefl0ra1
ipsec VPN Connection about to be created:
--------------------
Continue y/n?
y
...
..
.
```

```
  sos.noarch 0:3.6-11.el7.centos                                                
  tzdata.noarch 0:2018i-1.el7                                                   
  tzdata-java.noarch 0:2018i-1.el7                                              

Complete!
sha256:29cfbc5289cb096e5238aaf4b8b5379fdaba5f30c290e71d43ff743d4cc90721
---
centos7-rti-12345678 instance is ready!
---
OSTools Version: 1.15.0
updateos.pl: $Revision: 1.347 $
CentOS Linux release 7.6.1810 (Core) 
---

real    5m8.698s
user    0m0.228s
sys     0m0.277s
Press enter to continue..
  ```

  ```
	Enter selection: 1
	CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                                                                                    NAMES
	9e2f3ba06379        centos7-rti-16.1.3  "/usr/sbin/init"    2 minutes ago       Up 2 minutes        22/tcp, 80/tcp, 111/tcp, 443/tcp, 445/tcp, 631/tcp, 2001-2006/tcp, 9100/tcp, 15022/tcp   1234.teleflora.com
		Press enter to continue..
  ```

  ```
	Enter selection: 11
	REPOSITORY                         TAG                 IMAGE ID            CREATED             SIZE
	12345678.teleflora.com             latest              1b69b029b807        3 minutes ago       1.58 GB
	rhel7-rti-16.1.3                   latest              05b1c483ffcf        7 minutes ago       1.38 GB
	Press enter to continue..
  ```

```
Enter selection: 111
Security Associations (1 up, 0 connecting):
   phonehome[1]: ESTABLISHED 2 minutes ago, 192.168.222.233[35.182.191.52]...70.175.163.115[70.175.163.115]
   phonehome{1}:  INSTALLED, TUNNEL, reqid 1, ESP in UDP SPIs: 032b7ac6_i 0e86eb3c_o
   phonehome{1}:   192.168.222.0/24 === 192.168.22.0/24
Press enter to continue..
```

  ```
	Enter selection: 4
	The authenticity of host '172.17.0.2 (172.17.0.2)' can't be established.
	ECDSA key fingerprint is SHA256:TJc4LTltNe5sjUKuOcGxXaQvpO2iuGcCCd3iL6tgU40.
	ECDSA key fingerprint is MD5:a4:28:54:8d:b6:b6:fd:54:19:4f:d2:cd:78:f7:21:e0.
	Are you sure you want to continue connecting (yes/no)? yes
	Warning: Permanently added '172.17.0.2' (ECDSA) to the list of known hosts.
	root@172.17.0.2's password: 
	[root@1234 ~]# 
	[root@1234 ~]# 
	[root@1234 ~]# ifconfig
	eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
       	 	inet 172.17.0.2  netmask 255.255.0.0  broadcast 0.0.0.0
       		inet6 fe80::42:acff:fe11:2  prefixlen 64  scopeid 0x20<link>
       		ether 02:42:ac:11:00:02  txqueuelen 0  (Ethernet)
       		RX packets 51  bytes 6271 (6.1 KiB)
       		RX errors 0  dropped 0  overruns 0  frame 0
       		TX packets 37  bytes 5667 (5.5 KiB)
       		TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
	
	eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
       		inet 192.168.222.222  netmask 255.255.255.0  broadcast 192.168.222.255
       		inet6 fe80::6f:92ff:fec0:bde  prefixlen 64  scopeid 0x20<link>
       		ether 02:6f:92:c0:0b:de  txqueuelen 1000  (Ethernet)
       		RX packets 4038  bytes 5595840 (5.3 MiB)
       		RX errors 0  dropped 0  overruns 0  frame 0
       		TX packets 1984  bytes 139556 (136.2 KiB)
       		TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

	[root@1234 ~]# netstat -rn
	Kernel IP routing table
	Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
	0.0.0.0         192.168.222.1   0.0.0.0         UG        0 0          0 eth1
	172.17.0.0      0.0.0.0         255.255.0.0     U         0 0          0 eth0
	192.168.222.0   0.0.0.0         255.255.255.0   U         0 0          0 eth1
	
	[root@1234 ~]# df -h
	Filesystem      Size  Used Avail Use% Mounted on
	overlay          10G  5.8G  4.3G  58% /
	tmpfs           7.6G     0  7.6G   0% /dev
	/dev/nvme0n1p2   10G  5.8G  4.3G  58% /usr2
	shm              64M     0   64M   0% /dev/shm
	tmpfs            64M  4.2M   60M   7% /run
	tmpfs            64M     0   64M   0% /run/lock
	tmpfs            64M     0   64M   0% /var/log/journal
	tmpfs           7.6G  4.0K  7.6G   1% /tmp
	tmpfs           1.6G     0  1.6G   0% /run/user/0
	
	[root@1234 ~]# /usr/local/bin/bin/updateos.pl --ospatches
	Begin Installing OS Patches...
	Timestamp: 20181115005113
	Loaded plugins: fastestmirror, langpacks, ovl
	Cleaning repos: base epel extras updates
	Cleaning up everything
	Maybe you want: rm -rf /var/cache/yum, to also free up space taken by orphaned data from disabled or removed repos
	Cleaning up list of fastest mirrors
	Loaded plugins: fastestmirror, langpacks, ovl
	Determining fastest mirrors
	 * base: mirror.steadfastnet.com
	 * epel: mirror.steadfastnet.com
	 * extras: mirror.siena.edu
	 * updates: mirror.steadfastnet.com
	No packages marked for update
	Timestamp: 20181115005142
	End Installing OS Patches...
	[root@1234 ~]# 
	
	[root@1234 ~]# exit
	logout
	Connection to 172.17.0.2 closed.
	Press enter to continue..
  ```



3. Deployment (with or without data):

	Create VPN connection(s), shutdown application on physical server (if exists), run final backup to sync data (if exists), restore customer data, then start the application instance in the cloud.


  ```
	- Menu item: 112(create vpn), 5(restore data).

	SS NEEDED HERE
  ```


4. Reporting: 

	Creation of reporting sufficient enough to produce historical info for billing, performance, and compliance purposes.

	Examples: Yearly key rotations, periodic patch updates, instance inventory/subscriber list, or perhaps running time for a time-slice billing option.


The resulting container will be hardened, as well as address the gaps covered by the PCI references below. It will run the linux POS application in a container that is built with the same processes as the physical servers offered to the florists now. There will be a 1-to-1 container to host ratio to allow all host resources to be used by the point of sale application, as well as simplify the segregation of customer data per PA-DSS requirements. The point of sale instance will be connected by VPN connection to the florist's network(s), and route all traffic through the florist via that VPN tunnel (one VPN tunnel per remote location). Or "spoke and wheel" VPN configuration. This allows us to block all ports inbound to the container itself because we are using the POS application server as the VPN client, who ___initiates___ the connection(s).



Installation
------------------------

1. Launch a CentOS7 EC2 instance in AWS with the following configuration options:

	- A second network interface (eth1) assigned to the VM.
	- 100GB of disk space.
	- 2 Elastic IPs. Each assigned to each NIC. (One for the Docker host, one for the container.)
		- Leave the 1st NIC (eth0) an auto-assigned (DHCP) IP. 
		- Assign the 2nd NIC (eth1) an IP of 192.168.222.233/24.
	- Ports to be opened inbound to host (elastic bound to eth0): ssh (22).
	- Ports to be opened inbound to container (elastic bound to eth1): None (Block all inbound ___initiated___ connections).

2. Download and install cloud admin menus:

Login to the CentOS instance as centos; 

  ```
yum install git
git clone https://github.com/mykol71/MSCloudServer.git
cd MSCloudServer; sudo ./MENU; Select option "2 POS Cloud Serivce"

 01/18/2019 10:02 AM
┏━━━━━━━━━
┃🌷 POS Cloud Menu 
┣━
┃ Not Installed
┃ 
┃
┃ Status: 
┃ POS IP: 
┃
┃ 1. POS Status
┃ 2. Start POS
┃ 3. Stop POS
┃ 4. Connect to POS
┃ 5. Restore POS Data
┃
┃ 11. List Images
┃ 12. Build OS Media
┃ 13. Stage POS
┃ 14. Delete Image(s)
┃ 15. POS Snapshot
┃
┃ 111. VPN Status
┃ 112. Create VPN
┃ 113. Start VPN(s)
┃ 114. Stop VPN(s)
┃ 115. Delete VPN(s)
┃
┃ p. Purge All
┃ i. I/C/U Deps
┃ r. Readme
┃ x. Exit
┗━
Enter selection: i

Env Name: Mike's Store of Stuff
POS IP Adress: 192.168.222.233
POS Shop Code: 12345678
Loaded plugins: fastestmirror, langpacks
Cleaning repos: base epel extras updates
Loaded plugins: fastestmirror, langpacks
Determining fastest mirrors
...
..
.
Loaded plugins: fastestmirror, langpacks
Loading mirror speeds from cached hostfile
 * base: mirror.calgah.com
 * epel: fedora-epel.mirrors.tds.net
 * extras: mirror.calgah.com
 * updates: mirror.calgah.com
No packages marked for update

Done!

real    0m34.189s
user    0m3.633s
sys     0m0.686s
Press enter to continue..
  ```

- Next, build the OS media (12), stage an instance (13), restore data (5 if desired), then start the Point of Sale server (2).



Costs
------------------------

__Small Server Option:__

![](https://github.com/mykol-com/MSCloudServer/blob/master/msposapp/pics/ss1.png)


![](https://github.com/mykol-com/MSCloudServer/blob/master/msposapp/pics/ss2.png)


__Large Server Option:__

![](https://github.com/mykol-com/MSCloudServer/blob/master/msposapp/pics/ss4.png)


![](https://github.com/mykol-com/MSCloudServer/blob/master/msposapp/pics/ss3.png)



PCI/Security References
------------------------

In my opinion, the most important quote from any of these articles: 

>_"And while there are hurdles to be jumped and special attention that is needed when using containers in a cardholder data environment, there are no insurmountable obstacles to achieving PCI compliance."_ - Phil Dorzuk.

- Good Container/PCI article:

	https://thenewstack.io/containers-pose-different-operational-security-challenges-pci-compliance/

- Another, with downloadable container specific PA-DSS guide:

	https://blog.aquasec.com/why-container-security-matters-for-pci-compliant-organizations

- And, one more, that outlines the differences to address between PA-DSS Virtualization and Docker/containers:

	https://www.schellman.com/blog/docker-pci-compliance

- PCI Cloud Computing Guidelines:

	https://www.pcisecuritystandards.org/pdfs/PCI_DSS_v2_Cloud_Guidelines.pdf

- CIS Hardening benchmarks for OS, virtualization, containers, etc., with downloadable pdf:

	https://learn.cisecurity.org/benchmarks

- Free container vulnerability scanner:
	
	https://www.open-scap.org/resources/documentation/security-compliance-of-rhel7-docker-containers/

- Docker hardening standards:

	https://benchmarks.cisecurity.org/tools2/docker/CIS_Docker_1.12.0_Benchmark_v1.0.0.pdf
	
	https://web.nvd.nist.gov/view/ncp/repository/checklistDetail?id=655



Other References
------------------------

- Amazon AWS:

	https://aws.amazon.com/
	
	https://aws.amazon.com/cli/

	https://calculator.s3.amazonaws.com/index.html

- Redhat Containers:

	https://access.redhat.com/containers/

- CentOS:

	https://www.centos.org/
	
	https://www.centos.org/forums/

- Docker:

	https://www.docker.com/
	
	https://docs.docker.com/ 

- Kickstart Info:

	https://github.com/CentOS/sig-cloud-instance-build/tree/master/docker 

- Host to Container Network Configuration:

	https://github.com/jpetazzo/pipework 

- Teleflora Managed Services OSTools:

	http://rtihardware.homelinux.com/ostools/ostools.html 

- PCI Council:
	
	https://www.pcisecuritystandards.org/

- OpenSCAP:

	https://www.open-scap.org/

- ipsec VPN for RHEL/CentOS7 installation instructions:

	https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/docs/clients.md#linux-vpn-clients


------------------------
Mike Green -- mgreen@teleflora.com
