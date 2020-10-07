POS Cloud Service
------------------------

Teleflora Managed Services Linux Point of Sale Applications deployed in Amazon AWS.

Overview
------------------------

This solution provides for the Teleflora Managed Services Linux Point of Sale applications to run in the cloud on a single-host Docker environment with a 1:1 container to host ratio, in a private cloud network accessible by all branch locations of the customer. It will utilize as many of the existing, proven compliant, internal processes for delivering a Point of Sale system as possible. This application serves to manage those processes as well as a few additional ones from inserting the container layer. The end result will be a simple set of instructions (menu driven) to: Build, stage, and deploy a customer's Point of Sale server into the cloud, quickly, with no loss of data and minimal downtime.

![](./pics/RTI_cloud1.png)

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

- Ipsec site-to-site VPN connection information for each remote location wanting to use this server.


Process
-------

Done prior to go live with customer.

 1. [AWS Networking Configuration](awsconfig.md) - _Customers using their own AWS Account_
 2. [AWS EC2 Instance Creation](awsec2.md) - _Customers using their own AWS Account_
 3. [Remote Store Router Configurations](router_config.md) - _Start here for customers using Teleflorara as the cloud services provider_
 4. [Admin Scripts Installation](install.md)
 5. [Build OS Media](build.md)
 6. [Stage Instance](stage.md)

During outage with customer.

7. [Restore Data](deploy.md)
8. [Switch to Cloud Running POS](golive.md)

After outage, and ongoing.

9. [Ongoing Maintenance](maintain.md)

Information
-----------

 - [Pricing](pricing.md)
 - [Reporting](reporting.md)
 - [References](references.md)
 - [PA-DSS Specific](pci.md)
 - [Building Local Dev/QA/Backup Instances](test.md)

------

![](pics/POS%20Cloud.png)

---------------------------------
Mike Green - mgreen@teleflora.org
