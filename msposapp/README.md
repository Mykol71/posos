RTI Cloud Service
------------------------

Teleflora Managed Services Linux POS Applications in Amazon AWS.



Overview
------------------------

![Docker Single Host](https://d3ansictanv2wj.cloudfront.net/dnsd_0201-7c6df9623cb9dc0bb0276d02ac921b39.png "Docker Single Host Configuration")



Requirements
------------------------

- Low cost.

- Minimal use of support time or resources.

- Automated build process.

- PCI/PA-DSS compliant.

- Minimal impact to other processes.

- Able to expand to a share-hosted style, or host multiple customers with one cloud account.

- Fast, repeatable, installation and configuration of Prod, QA, and Dev instances.

- Allow for ease to add other Teleflora POS Linux applications.

- Teleflora Managed Services Linux Cloud Backup Service (To be upgraded from by the end of this process).

- Minimal to no maintenance added to what is already done for the instance itself.

- Reporting; track use for billing, performance, and compliance purposes.



Design
------------------------

The solution can be considered in 4 peices (Each having different compliance implications):

1. Build (media creation)

	An automated build process, using containers, to quickly produce OS media prepared with all the required components needed by the application installation. Technically, the use of prepared media from a marketplace or other solution, isn't suggested for PCI compliance. Additionally, in a catastrophic situation, quickling matching patch levels from a customer's physical server might be needed.

2. Staging (creation of a running, generic, instance from media)

	Prepare the linux boot volume, combine with added required pieces needed for deployment from managed services for the application installation, run through the build process, then commit to the resulting container.

3. Deployment (with data)

	Assign to a customer, create VPN connection, start application instance prepared above, restore data (if desired).

4. Reporting 

	Creation of reporting sufficient enough to produce historical info for billing, performance, and compliance purposes.



Installation
------------------------

1. Launch an RHEL7 EC2 instance in AWS with the following confuration options:

	- A second network interface (eth1) assigned to the VM.
	- 100GB of disk space.
	- 2 Elastic IPs. Each assigned to each NIC. (One for a managment endpoint and another to passthrough for the application instance.)
	- Ports to be opened inbound: ssh, icmp, and rdp.

2. Download and install cloud admin menus:

		sudo yum install git
		git clone https://github.com/mykol-com/MSCloudServer.git
		cd ./MSCloudServer
		sudo ./MENU
		
		12:24:33 - Not Installed
		┏━━━━━━━━━━
		┃ MS Cloud Menu
		┣━
		┃ 1. Backup Service
		┃ 2. RTI Service
		┃ 3. CentOS Repo
		┃ 4. Admin Tasks
		┃
		┃ d. I/C/U Deps
		┃ a. I/C/U AWS
		┃ i. Info
		┃ x. Exit
		┗━
		Enter selection: 

		Select "2" to load the RTI Cloud Menu
		
		10:18:27 - 12345678
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
		┃ 15.
		┃
		┃ 111. Instance Snapshot
		┃ 112. List VPNs
		┃ 113. Create VPN
		┃ 114. Delete VPN
		┃ 115.
		┃
		┃ p. Purge All
		┃ d. I/C/U Deps
		┃ a. I/C/U AWS
		┃ x. Exit
		┗━
		Enter selection: 
		
		Select "d" to Install/Configure/Upgrade Dependant packages; need Redhat support login the first time.
		Select "a" to I/C/U AWS - Need AWS Account Keys, region, and enter "text" for output.

3. Start with Build OS Media; then create a VPN connection; lastly, stage and restore data.



PCI/Security Considerations
------------------------

In my opinion, the most important quote from any of these articles to be aware of: _"And while there are hurdles to be jumped and special attention that is needed when using containers in a cardholder data environment, there are no insurmountable obstacles to achieving PCI compliance."_ - Phil Dorzuk.

- Good Container/PCI Article:

	https://thenewstack.io/containers-pose-different-operational-security-challenges-pci-compliance/

- Another, with downloadable container specific, PA-DSS Guide:

	https://blog.aquasec.com/why-container-security-matters-for-pci-compliant-organizations

- And, one more, that outlines the differences to address between PA-DSS Virtualization and Docker/containers:

	https://www.schellman.com/blog/docker-pci-compliance

- PCI Cloud Computing general document:

	https://www.pcisecuritystandards.org/pdfs/PCI_DSS_v2_Cloud_Guidelines.pdf

- CIS Hardening Benchmarks for OS, Virtualization, Containers, etc., with downloadable pdf:

	https://learn.cisecurity.org/benchmarks

- Free container vulnerability scanner:
	
	https://www.open-scap.org/resources/documentation/security-compliance-of-rhel7-docker-containers/

- Docker hardening standards:

	https://benchmarks.cisecurity.org/tools2/docker/CIS_Docker_1.12.0_Benchmark_v1.0.0.pdf
	
	https://web.nvd.nist.gov/view/ncp/repository/checklistDetail?id=655



Other Resources
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

- OpenVPN:

	https://openvpn.net/

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



------------------------
Mike Green / Systems Architect / Teleflora Managed Services / mgreen@teleflora.com
