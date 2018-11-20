Linux Admin Tasks
------------------------

Linux Managed Services Various Admin Tasks.


Overview
------------------------

To provide a place to quickly deliver and deloy linux admin changes to servers.


Requirements
------------------------

- RHEL7

- git


Installation
------------------------

1. Launch an RHEL7 EC2 instance in AWS with the following configuration options:

	- 100GB of disk space.
	- Ports to be opened inbound to host (elastic bound to eth0): ssh (22) and http (80 if creating centos repo).

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
		Enter selection: 4	
		
		03:16:25
		┏━━━━━━━━━━━━━━
		┃ Linux Admin Tasks
		┣━
		┃ 1. Configure Sendgrid Relay
		┃ 2. Convert to CentOS
		┃ 3. Daisy Conversion Script
		┃
		┃ i. Info
		┃ x. Exit
		┗━
		Enter selection: 

------------------------
Mike Green -- mgreen@teleflora.com
=======
