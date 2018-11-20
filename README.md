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
	
      Select "d" to I/C/U Deps (Install/Configure/Upgrade - Need Redhat login 1st time)
      Select "a" to I/C/U AWS (Need AWS Account public/private Key pair, Region, text output)
```

___Cloud Backup Service___ - Current Cloud Backup Service.

___POS Cloud Service__ - Point of Sale Systems Running in AWS.

___CentOS Repository___ - Creation and Maintenance of Teleflora's CentOS Repository.

___Linux Admin Tasks___ - Various Linux Administration tasks.

---------
Mike Green - mgreen@teleflora.com
