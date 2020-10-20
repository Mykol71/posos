posos
-----

A collection of code written over the years to simplify linux OS administration on a PCI compliant Point of Sale Server.

ostools, written in perl, started as a set of sripts to simplify staging a server for a customer.
Later a backup script (rtibackup.pl) was added to securly backup the POS to a number of various types of devices.
Even later, that same backup script was revamped based on rsync instead of simply tar, and added support for a server-to-server and a cloud (AWS backed) configuration.

In tandom with the ostools development, a fairly complicated set of kickstart scripts were produced and maintained for each major release of Redhat Enterprise Linux.
These were used to prepare the OS for the required paritioning schemes as expected etc., but also to configure older requirements like old video resolutions on the console, supporting POS application entry points from the console of a server, etc.

Every time and major linux OS release would come due, it would kick off a long and involved process to upgrading the above for the new version. As well as creation and delivery of media to customers on a mass scale. 
And, as far as I know at the time I wrote this, linux still has no seemless major OS upgrade path for systems with custom applications.

This repo contains a series of bash scripts (posos), driven by a menu and the above historical development, that gives one server the ability to "containerize" a CentOS/Redhat linux POS system, that is also running as its own "cloud" backup backend, or on-site physical server.
For users hosting this in AWS or another cloud provider, posos will also create a site-to-site VPN connection to your local network (requires preconfigured router settings), which the container will route all networking through.
Then, allows you to switch the running container to any of the preproduced rsync backups on that same server within seconds.
Lastly, for security, compliance, etc., the only 2 repos that are enabled are the core CentOS updates, and the epel repo only long enough to install strongswan (VPN software). No compilers, dev packages etc.


Sample container crontab for daily backups, rotating each week:
---
0 0 * * 1 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000001 --cloud-server=iflorist.myk.green --force-rsync-account

0 0 * * 2 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000002 --cloud-server=iflorist.myk.green --force-rsync-account

0 0 * * 3 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000003 --cloud-server=iflorist.myk.green --force-rsync-account

0 0 * * 4 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000004 --cloud-server=iflorist.myk.green --force-rsync-account

0 0 * * 5 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000005 --cloud-server=iflorist.myk.green --force-rsync-account

0 0 * * 6 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000006 --cloud-server=iflorist.myk.green --force-rsync-account

0 0 * * 7 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000007 --cloud-server=iflorist.myk.green --force-rsync-account


Sample tfrsync account scenerios:
---
drwx------. 3 sunday-01202001     sunday-01202001       88 Oct 17 09:43 sunday-01202001

drwx------. 3 monday-01202001     monday-01202001       88 Oct 17 09:47 monday-01202001

drwx------. 3 tuesday-01202001    tuesday-01202001      88 Oct 17 09:48 tuesday-01202001

drwx------. 3 wednesday-01202001  wednesday-01202001    88 Oct 17 09:48 wednesday-01202001

drwx------. 3 wednesday-012020010 wednesday-012020010   88 Oct 17 09:49 wednesday-012020010

drwx------. 3 mykdev-20201017     mykdev-20201017       88 Oct 17 09:50 mykdev-20201017

drwx------. 3 mykdev-01222222     mykdev-01222222       88 Oct 17 09:51 mykdev-01222222




TO DO -
-------

X fix backup scripts for account name.
- tfsupport CS keys and auth style?
X create isos repo
- admin maintenance menu
- Patch method for these menus.
- add restore snapshot link stuff.
X match rti staging added packages to daisy.
X install; set server hostname.
X tfrsync.pl change to not require only numbers for 8 char ID.
- ostools RH8 work around for now?
X add RH8 build repo option.
- install; add tfsupport ssh keys.
- physical media iso creation/download option?
- add spacewalk setup/integration.
- check on security/cvs info on patches and notifications with spacewalk.
- migrate kickstart files to spacewalk.
- Replace daisy console screens with pts equivs.
X POS instance user removal upon shutdown.
---> Updated Strongswan config for ipsec.
- Scrub and condence code.
0 shellinabox config.
- missing character map piece for daisy.
- Combine base OS ks files from both POS systems into one.
- Sanity checks. EX: don't allow selection of stage if one is already staged.
X examples of cron jobs to backup for different situations.
- Build RTI QA example for management.
X Test install on physical hardware. (It should not matter if it is an AWS instance or not.)
- Add istar rpm to both POS systems.
- Daisy function keys.
- logging and error capturing.
X create ostools subrepo.
- optional server-wide repo (instead of rtihardware.homelinux.com)
X create kickstart file repo. 
-


-- For Documentation
- Pic updates.
- Add custom data import information.
- Update design diagram. (genericize cloude/physical server)
-  



Dependancies -
--------------

- GET LINKS
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



SOME DAY -
----------

-- Linux
- Multiple containers on the same host.
- Promote it all to CentOS8.
- Integrate with its own CentOS repo if desired.

-- Windows?
- Hyper-V config for running Windows.
- Windows installation.
- Dove POS installation.
- Web based rdp client.
- Software VPN
-
