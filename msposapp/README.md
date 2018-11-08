RTI Cloud Service
------------------------

Teleflora Managed Services Linux Point of Sale Applications deployed in Amazon AWS.



Overview
------------------------

This solution provides for the Teleflora Managed Services Linux point of sale applications to run in the cloud on a single-host Docker environment with a 1:1 contanier to host ratio, in a private cloud network accessible by all branch locations of the florist. It will utilize as many of the existing, proven compliant, internal processes for delivering a point of sale system to the florist as possible. This application serves to manage those processes as well as the a few additional ones for inserting the container layer. The end result will be a simple set of instructions to build, stage, and deploy a customer's point of sale application into the cloud in a small amount of time, with no loss of data.

Example pic here
![](https://github.com/mykol-com/MSCloudServer/blob/master/msposapp/pics/docker_single_host.png)



Requirements
------------------------

- Low cost.

- Minimal use of support time or resources.

- Automated build process.

- PA-DSS compliant.

- Minimal impact to other processes.

- Able to expand to a share-hosted style, or host multiple customers with one cloud account.

- Fast, repeatable, installation and configuration of Prod, QA, and Dev instances.

- Allow for ease to add other Teleflora POS Linux applications.

- Teleflora Managed Services Linux Cloud Backup Service.

- Minimal maintenance added to what is already done for the point of sale instance itself.

- Reporting; track use for billing, performance, and compliance purposes.



Design
------------------------

The solution can be considered in 4 peices (Each having different compliance implications):

1. Build (media creation)

	An automated build process, using containers, to quickly produce OS media prepared with all the required components needed by the application installation. Technically, the use of prepared media from a marketplace or other solution, isn't suggested for PCI compliance. Additionally, in a catastrophic situation, quickling matching patch levels from a customer's physical server might be needed.

2. Staging (creation of a running, generic, instance from media)

	Prepare the linux boot volume, combine with added required pieces needed for deployment from managed services for the application installation, run through the build process, then commit to the resulting container.

3. Deployment (with data)

	Assign to a customer, create VPN connection, mount persisted data, and start application instance.

4. Reporting 

	Creation of reporting sufficient enough to produce historical info for billing, performance, and compliance purposes.

The resulting EC2 instance will be hardened with existing processes, as well as address the gaps covered by the PCI references below. It will run the linux POS application in a container that is built with the same processes as the physical servers sold to the florists now. There will be a 1-to-1 container to host ratio to allow all host resources to be used by the point of sale application, as well as simplify the segregation of customer data per PA-DSS requirements. The point of sale instance will intiate a VPN connection to the florist's network(s), and route all traffic through the florist via the VPN tunnel. This allows us to block all ports inbound to the container because we are using the POS application server as the VPN client.



Example1 pic here
![](https://github.com/mykol-com/MSCloudServer/blob/master/msposapp/pics/docker_single_host.png)

Example2 pic here
![](https://github.com/mykol-com/MSCloudServer/blob/master/msposapp/pics/docker_single_host.png)



Installation
------------------------

1. Launch an RHEL7 EC2 instance in AWS with the following confuration options:

	- A second network interface (eth1) assigned to the VM.
	- 100GB of disk space.
	- 2 Elastic IPs. Each assigned to each NIC. (One for the Docker host, one for the container.)
	- Ports to be opened inbound to host (eth0): ssh (22).
	- Ports to be opened inbound to container (eth1): None (Block all inbound initiated connections).

2. Download and install cloud admin menus:

		sudo yum install git
		git clone https://github.com/mykol-com/MSCloudServer.git
		cd ./MSCloudServer/msposapp
		sudo ./MENU
		
		10:18:27 - Not Installed
		┏━━━━━━━━━━━━
		┃ RTI Cloud Menu
		┣━
		┃ 1. Running Instances
		┃ 2. Start Instance
		┃ 3. Stop Instance
		┃ 4. Connect to Instance
		┃ 5. List NICs
		┃
		┃ 11. Build OS Media
		┃ 12. Stage a Server
		┃ 13. List Images
		┃ 14. Delete Image(s)
		┃
		┃ 111. Instance Snapshot
		┃ 112. List VPNs
		┃ 113. Create VPN
		┃ 114. Delete VPN
		┃
		┃ p. Purge All
		┃ d. I/C/U Deps
		┃ a. I/C/U AWS
		┃ x. Exit
		┗━
		Enter selection: 
		
		Select "d" to Install/Configure/Upgrade Dependant packages; 1st time need Redhat support login.
		Select "a" to I/C/U AWS - Need AWS Account Keys, region, and enter "text" for output.

- Next, build the OS media, stage an instance, create a VPN connection, mount persisted data, then start the point of sale appliation.



Costs
------------------------

		Pricing info here.



PCI/Security References
------------------------

In my opinion, the most important quote from any of these articles: 

>_"And while there are hurdles to be jumped and special attention that is needed when using containers in a cardholder data environment, there are no insurmountable obstacles to achieving PCI compliance."_ - Phil Dorzuk.

- Good Container/PCI article:

	https://thenewstack.io/containers-pose-different-operational-security-challenges-pci-compliance/

- Another, with downloadable container specific, PA-DSS guide:

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

- SSL VPN Client Creation from linux command line:

	http://www.tldp.org/HOWTO/VPN-HOWTO/x346.html



------------------------
Mike Green - mgreen@teleflora.com
