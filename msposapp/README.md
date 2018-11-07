RTI Cloud Service
------------------------

Teleflora Managed Services RTI Application in Amazon AWS.



Overview
------------------------



Requirements
------------------------

- Low Cost

- Minimal use of support time or resources

- Automated Build Process

- PCI/PA-DSS Compliant

- Minimal impact to other processes

- Able to expand to a share-hosted style, or host multiple florists with one cloud account

- Repeatable installation and configuration of Build / QA / Dev Instances

- Allow for ease to add other Teleflora POS Linux applications

- Integrated with Cloud Backup Service

- Minimal to no maintenance added to what is already done for the instance itself

- Reporting; track use for billing purposes


Design
------------------------

The solution can be considered in 3 peices:

1. Build (media creation)

	An automated build process, using containers, to quickly produce OS media prepared with all the required components needed by the application installation. Technically, the use of prepared media from a marketplace or other solution, isn't suggested for PCI compliance. Additionally, in a catastrophic situation, quickling matching patch levels from a customer's physical server might bee needed.

2. Staging (creation of a running, generic instance, from media)

	Prepare the linux boot volume, combine with added required pieces needed for deployment from managed services for the application installation, assign to a specific customer, run through the kickstart process, then commit (and export if desired) the resulting image.

3. Deployment (with data)

	Create VPN connection, start application instance prepared above, restore data (if desired).



Installation
------------------------

1. Create a base RHEL7 install in AWS with the following confuration options.

	- A second network interface (eth1) assigned to the VM
	- 100GB of disk space
	- 2 Elastic IPs. Each assigned to each NIC. (One for a managment endpoint and another to passthrough for the application instance.)

2. Download and Install Cloud Menus:
-

	sudo yum install git
	git clone https://github.com/mykol-com/MSCloudServer.git
	cd ./MSCloudServer ; sudo ./MENU
	Select "d" to I/C/U Deps (Install/Configure/Upgrade; need Redhat support login)
	Select "a" to I/C/U AWS (Need AWS Account Keys, region, text output)


3. Start with Building the OS Media; then create a VPN connection; and finally Deploy.



PCI/Security Considerations
------------------------

In my opinion, the most important quote from any of these articles to be aware of: "And while there are hurdles to be jumped and special attention that is needed when using containers in a cardholder data environment, there are no insurmountable obstacles to achieving PCI compliance."

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



Other Resources
------------------------

- Amazon AWS

	https://aws.amazon.com/

- Redhat Containers

	https://www.redhat.com/

- CentOS

	https://www.centos.org/

- Docker

	https://docs.docker.com/ 

- OpenVPN

	https://openvpn.net/

- Kickstart Info

	https://github.com/CentOS/sig-cloud-instance-build/tree/master/docker 

- Host to Container Network Configuration

	https://github.com/jpetazzo/pipework 

- Teleflora Managed Services OSTools

	http://rtihardware.homelinux.com/ostools/ostools.html 



------------------------

	Mike Green - mgreen@teleflora.com
