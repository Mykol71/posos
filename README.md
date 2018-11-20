MSCloudServer
----------
Teleflora Managed Services Linux

Install
----------

1. Create a base RHEL7 install anywhere.

2. Download and Install Cloud Menus.

```
      sudo yum install git
      git clone https://github.com/mykol-com/MSCloudServer.git
      cd ./MSCloudServer ; sudo ./MENU
	
	03:03:03 - MG-Dev
	┏━━━━━━━━━━━━━━━━
	┃ MS Cloud Menu
	┣━
	┃ 1. Backup Service
	┃ 2. POS Service
	┃ 3. CentOS Repo
	┃ 4. Admin Tasks
	┃
	┃ d. I/C/U Deps
	┃ a. I/C/U AWS
	┃ i. Info
	┃ x. Exit
	┗━
	Enter selection: 
	
      Select "d" to I/C/U Deps (Install/Configure/Upgrade)
      Select "a" to I/C/U AWS (Need AWS Account public/private Key pair)
```

_Cloud Backup Service_ - Current Cloud Backup Service.

_POS Cloud Service_ - RTI Running in the Cloud.

_CentOS Repo_ - Creation and Maintenance of Teleflora's CentOS Repo.

_Admin tasks_ - Various Admin tasks.

---------
Mike Green - mgreen@teleflora.com
