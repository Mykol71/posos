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
	Enter selection: 12
	Daisy or RTI?: RTI
	Trying to pull repository registry.access.redhat.com/rhel7 ... 
	latest: Pulling from registry.access.redhat.com/rhel7
	50a402dbfd72: Pull complete 
	c6796217be8f: Pull complete 
	Digest: sha256:7ae7375bdbb23180d21dfed3408ba82f0d00dd049557cd62716a628367d31d61
	.  
	.. 
	...
	Removing intermediate container 0eca109df016
	Step 29/29 : CMD [“/usr/bin/bash”]
	 ---> Running in c5f8834ddbb8
	 ---> d7acf0c663a2
	Removing intermediate container c5f8834ddbb8
	Successfully built d7acf0c663a2
	/home/ec2-user/msposapp/bin

	real    12m28.976s
	user    12m9.770s
	sys     0m44.830s
	Press enter to continue..
  ```

  ```
	Enter selection: 11
	REPOSITORY                         TAG                 IMAGE ID            CREATED             SIZE
	rhel7-rti-16.1.3                   latest              05b1c483ffcf        19 seconds ago      1.38 GB
	registry.access.redhat.com/rhel7   latest              eb205f07ce7d        2 weeks ago         203 MB
	Press enter to continue..
  ```


2. Staging (Assign to a customer, install OS, and run application installation from media):

	Prepare the linux boot volume, combine with added required pieces needed for deployment from managed services for the application installation, run through the installation process, then commit to the resulting container.


  ```
	Enter selection: 13
	SHOPCODE: 1234
	daisy or rti?: rti
	--2018-11-15 00:43:25--  http://rtihardware.homelinux.com/ostools/ostools-1.15-latest.tar.gz
	Resolving rtihardware.homelinux.com (rtihardware.homelinux.com)... 209.141.208.120
	Connecting to rtihardware.homelinux.com (rtihardware.homelinux.com)|209.141.208.120|:80... connected.
	HTTP request sent, awaiting response... 200 OK
	Length: 367453 (359K) [application/x-gzip]
	Saving to: 'ostools-1.15-latest.tar.gz'
	
	     0K .......... .......... .......... .......... .......... 13%  394K 1s
	    50K .......... .......... .......... .......... .......... 27%  726K 1s
	.  
	.. 
	...
	No packages marked for update
	sha256:1b69b029b807e52398b7446abbc5207d294b2dd0cc36703fb81ee93024a23dfb
	---
	rhel7-rti-1234 instance is ready!
	---
	OSTools Version: 1.15.0
	updateos.pl: $Revision: 1.347 $
	CentOS Linux release 7.5.1804 (Core) 
	---
	Press enter to continue..
  ```

  ```
	Enter selection: 1
	CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                                                                                    NAMES
	9e2f3ba06379        rhel7-rti-16.1.3    "/usr/sbin/init"    2 minutes ago       Up 2 minutes        22/tcp, 80/tcp, 111/tcp, 443/tcp, 445/tcp, 631/tcp, 2001-2006/tcp, 9100/tcp, 15022/tcp   1234.teleflora.com
		Press enter to continue..
  ```

  ```
	Enter selection: 11
	REPOSITORY                         TAG                 IMAGE ID            CREATED             SIZE
	1234.teleflora.com                 latest              1b69b029b807        3 minutes ago       1.58 GB
	rhel7-rti-16.1.3                   latest              05b1c483ffcf        7 minutes ago       1.38 GB
	registry.access.redhat.com/rhel7   latest              eb205f07ce7d        2 weeks ago         203 MB
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

1. Launch an RHEL7 EC2 instance in AWS with the following configuration options:

	- A second network interface (eth1) assigned to the VM.
	- 100GB of disk space.
	- 2 Elastic IPs. Each assigned to each NIC. (One for the Docker host, one for the container.)
		- Leave the 1st NIC (eth0) an auto-assigned (DHCP) IP. 
		- Assign the 2nd NIC (eth1) an IP of 192.168.222.222/24.
	- Ports to be opened inbound to host (elastic bound to eth0): ssh (22).
	- Ports to be opened inbound to container (elastic bound to eth1): None (Block all inbound ___initiated___ connections).

2. Download and install cloud admin menus:

		sudo yum install git
		git clone https://github.com/mykol-com/msposapp.git
		cd ./msposapp
		sudo ./MENU
		
		21:50:34 - Not Installed
		┏━━━━━━━━━━━━
		┃ MS POS Cloud Menu
		┣━
		┃ 1. Server Status
		┃ 2. Start Server
		┃ 3. Stop Server(s)
		┃ 4. Connect to Server
		┃ 5. Restore Florist Data
		┃
		┃ 11. List Images
		┃ 12. Build OS Media
		┃ 13. Stage a Server
		┃ 14. Delete Image(s)
		┃ 15. Server Snapshot
		┃
		┃ 111. VPN Status
		┃ 112. Create VPN
		┃ 113. Start VPN(s)
		┃ 114. Stop VPN(s)
		┃ 115. Delete VPN(s)
		┃
		┃ p. Purge All
		┃ d. I/C/U Deps
		┃ x. Exit
		┗━
		Enter selection: 
		
		Select "d" to Install/Configure/Upgrade Dependant packages; 1st time need Redhat support login.

- Next, build the OS media (12), stage an instance (13), create a VPN connection(s) (112), restore data (5 if desired), then start the Point of Sale server (2).



Costs
------------------------

__Small Server Option:__

![](https://github.com/mykol-com/msposapp/blob/master/pics/ss1.png)


![](https://github.com/mykol-com/msposapp/blob/master/pics/ss2.png)


__Large Server Option:__

![](https://github.com/mykol-com/msposapp/blob/master/pics/ss4.png)


![](https://github.com/mykol-com/msposapp/blob/master/pics/ss3.png)



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
