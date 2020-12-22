posos
-----

A collection of code written over the years to simplify linux OS administration on a PCI compliant Point of Sale Server.

- ostools, written in perl, started as a set of sripts to simplify staging a server for a customer.
Later a backup script (rtibackup.pl) was added to securly backup the POS to a number of various types of devices.
Even later, that same backup script was revamped based on rsync instead of simply tar, and added support for a server-to-server and a cloud (AWS backed) configuration.

- In tandom with the ostools development, a fairly complicated set of kickstart scripts were produced and maintained for each major release of Redhat Enterprise Linux.
These were used to prepare the OS for the required paritioning schemes as expected etc., but also to configure older requirements like old video resolutions on the console, supporting POS application entry points from the console of a server, etc.

- Every time and major linux OS release would come due, it would kick off a long and involved process to upgrading the above for the new version. As well as creation and delivery of media to customers on a mass scale. 
And, as far as I know at the time I wrote this, linux still has no seemless major OS upgrade path for systems with custom applications.

- This repo contains a series of bash scripts (posos), driven by a menu and the above historical development, that gives one server the ability to "containerize" a CentOS/Redhat linux POS system, that is also running as its own "cloud" backup backend, or on-site physical server.
For users hosting this in AWS or another cloud provider, posos will also create a site-to-site VPN connection to your local network (requires preconfigured router settings), which the container will route all networking through.
Then, allows you to switch the running container to any of the preproduced rsync backups on that same server within seconds.
Lastly, for security, compliance, etc., the only 2 repos that are enabled are the core CentOS updates, and the epel repo only long enough to install strongswan (VPN software). No compilers, dev packages etc.

```
10/19/2020 10:56 PM
┏━━━━━━━━
┃ @ Mike's Devel
┃ )~ m5d.large
┃━
┃ Free Space: 994G
┃
┃---
┃ 1. Data
┃ 2. Containers
┃ 3. Repos
┃ 4. Admin
┃ 5. Reports
┃
┃ i. Install
┃ r. Readme
┃ x. Exit
┗━
Enter selection:
```

```
TO DO -
-------

-- Scripts
- github CLI auth changes.
- msposapp; data - restore data from backups section to live container.
- mash code.
- add podman suport for host-side RH/CentOS8.
- local repo for RH/CentOS8.
X make package/repo changes for RH8/CentOS8.
X fix backup scripts for account name.
- tfsupport CS keys and auth style?
X match daisy package installation timing to rti's.
X create isos repo
- admin maintenance menu
- patch method for these menus.
X push all package installs to ks portion (except VPN software).
- add restore snapshot link stuff.
X match rti staging added packages to daisy.
X install; set server hostname.
X tfrsync.pl change to not require only numbers for 8 char ID.
X add RH8 build repo option.
- install; add tfsupport ssh keys.
- physical media iso creation/download option?
- migrate kickstart files to spacewalk.
0 Replace daisy console screens with pts equivs.
X POS instance user removal upon shutdown.
---> Updated Strongswan config for ipsec.
0 shellinabox config.
X missing lang setting for daisy.
- Sanity checks. EX: don't allow selection of stage if one is already staged.
X examples of cron jobs to backup for different situations.
- Build RTI QA example for management.
X Test install on physical hardware. (It should not matter if it is an AWS instance or not.)
- Add istar rpm to both POS systems.
- Daisy function keys.
- logging and error capturing.
X create ostools subrepo.
- optional server-wide local repo (instead of rtihardware.homelinux.com)
X create kickstart file repo. 
- admin scripts; add usb_build_media and dvd_build scripts.
- 

-- ostools
- bbj8 install upgrade during --rti14 of updateos.pl.
- rhel/centos8 awareness.
- configure perldoc for documentation.
- 

-- Documentation
- Add custom data import information.
- Update design diagram. (genericize cloude/physical server)
- Seperate readme for each app.
- Document how-tos for backup configuration.
- Document data import logic.
- 
```


Dependencies -
--------------

- shellinabox
- pipework
- ksstuff
- docker
- centos
- teleflora
- epel
- 



Information -
-------------

-- Security related
- PCI council
- openscap
- Strongswan ipsec/ikev1 example configuration: 

https://www.strongswan.org/testing/testresults/ikev1/net2net-psk/

-  



Some Day -
----------

-- Linux
- Multiple containers on the same host.
- Promote it all to CentOS8.
- Integrate with its own CentOS repo if desired.
- Build container from hosts anaconda.ks file.
-

-- Windows
- Hyper-V config for running Windows.
- Windows installation.
- Dove POS installation.
- Web based rdp client.
- Software VPN
-
