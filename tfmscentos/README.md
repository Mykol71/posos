TFMS CentOS Repository
------------------------

Teleflora Managed Services CentOS Repository deployed in Amazon AWS.


Overview
------------------------

To provide a CentOS repository for the Teleflora Point of Sale systems to get OS updates from.


Requirements
------------------------

- Very low cost.

- Minimal use of support time or resources.

- Automated build process.


Installation / Maintenance
--------------------------

1. Create/Update Repository:

This will create the repository if it isnt there, and update it if it is.

  ```

	02:40:53
	┏━━━━━━━━━━━━━━━
	┃ CentOS Repo Menu
	┣━
	┃ Status: inactive
	┃
	┃ 1. Start Repo
	┃ 2. Stop Repo
	┃ 3. Create/Update Repo
	┃
	┃ d. I/C/U Deps
	┃ x. Exit
	┗━
	Enter selection: 3
	receiving incremental file list
	x86_64/
	x86_64/.discinfo
       	      29 100%   28.32kB/s    0:00:00 (xfr#1, ir-chk=9934/9936)
	x86_64/.treeinfo
       	     354 100%  345.70kB/s    0:00:00 (xfr#2, ir-chk=9933/9936)
	x86_64/CentOS_BuildTag
       	      14 100%   13.67kB/s    0:00:00 (xfr#3, ir-chk=9932/9936)
	x86_64/EULA
	.  
	.. 
	...
	/home/ec2-user/MSCloudServer/tfmscentos/bin

	real    12m28.976s
	user    12m9.770s
	sys     0m44.830s
	Press enter to continue..
  ```

2. Start Repo:

  ```
	Enter selection: 1
	   Active: active (running) since Tue 2018-11-20 02:12:03 CST; 13s ago
	Press enter to continue..
  ```


3. Stop Repo:

  ```
	Enter selection: 2
	   Active: inactive (dead) since Tue 2018-11-20 02:16:27 CST; 1min 57s ago
	Press enter to continue..
  ```

4. Convert Customer's POS Servier:

- Login to the customer's server, download these scripts, the select (4) for "Admin Tasks", then (2) for "Convert to CentOS".

  ```
	Enter selection: 2
	#!/bin/bash
	
	#
	#--Convert system to CentOS
	cd /etc/yum.repos.d
	#a. Cleanup.
	rm -f /etc/yum.repos.d/CentOS*
	rm -f /etc/yum.repos.d/tfmscentos*
	#
	#1. Disable Redhat repos.
	sed -i 's/enabled = 1/enabled = 0/g' redhat.repo
	
	#2. Install CentOS repo provided by Teleflora.
	wget http://centos.myk.green/repos/centos7/x86_64/x86_84/tfmscentos.repo
	echo "enabled=1">>/etc/yum.repos.d/tfmscentos.repo
	
	#3. Replace redhat-release with centos-release
	rpm -e --nodeps redhat-release-server
	rm -rf /usr/share/doc/redhat*
	rm -rf /usr/share/redhat-release*
	yum -y install centos-release
	
	#4. Update everything.
	yum -y update
	
	#5. Done.
	cat /etc/redhat-release
	cd -
	#-
	Run it? y/n:
	n
	/home/ec2-user/MSCloudServer/linuxadmin
	Press enter to continue..

  ```

Installation
------------------------

1. Launch an RHEL7 EC2 instance in AWS with the following configuration options:

	- 100GB of disk space.
	- Ports to be opened inbound to host (elastic bound to eth0): ssh (22) and http (80).

2. Download and install cloud admin menus:

		sudo yum install git
		git clone https://github.com/mykol-com/MSCloudServer.git
		cd ./MSCloudServer
		sudo ./MENU
		
		01:52:07 - MG-Dev
		┏━━━━━━━━━━━━━━━━
		┃ MS Cloud Menu
		┣━
		┃ 1. Backup Service
		┃ 2. POS Service
		┃ 3. CentOS Repo
		┃ 4. Admin Tasks
		┃
		┃ d. I/C/U Deps
		┃ i. Info
		┃ x. Exit
		┗━
		Enter selection: 3	

		01:56:13
		┏━━━━━━━━━━━━━━━
		┃ CentOS Repo Menu
		┣━
		┃ Status: 
		┃
		┃ 1. Start Repo
		┃ 2. Stop Repo
		┃ 3. Create/Update Repo
		┃
		┃ d. I/C/U Deps
		┃ x. Exit
		┗━
		Enter selection: 

		Select "d" to Install/Configure/Upgrade Dependant packages; 1st time need Redhat support login.

- Next, create/update the repo (3), start repo (1).

- /etc/yum.repos.d/tfmscentos.repo:

```

[Teleflora Managed Services CentOS 7]
name=TFMSCentOS
baseurl=http://tfmscentos.homelinux.com/repos/7/os/x86_64/x86_64
gpgcheck=0
enabled=1

```

------------------------
Mike Green -- mgreen@teleflora.com
