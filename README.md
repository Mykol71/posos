Sample crontab for daily backups, rotating each week:
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
[tfsupport@01222222 ~]$ ls -ltr /home

total 4

drwx------. 3 daisy               daisy                165 Oct 17 09:32 daisy

drwx------. 5 tfsupport           daisy               4096 Oct 17 09:37 tfsupport

drwx------. 3 sunday-01202001     sunday-01202001       88 Oct 17 09:43 sunday-01202001

drwx------. 3 monday-01202001     monday-01202001       88 Oct 17 09:47 monday-01202001

drwx------. 3 tuesday-01202001    tuesday-01202001      88 Oct 17 09:48 tuesday-01202001

drwx------. 3 wednesday-01202001  wednesday-01202001    88 Oct 17 09:48 wednesday-01202001

drwx------. 3 wednesday-012020010 wednesday-012020010   88 Oct 17 09:49 wednesday-012020010

drwx------. 3 mykdev-20201017     mykdev-20201017       88 Oct 17 09:50 mykdev-20201017

drwx------. 3 mykdev-01222222     mykdev-01222222       88 Oct 17 09:51 mykdev-01222222

[tfsupport@01222222 ~]$ 


TO DO -
-------

- tfsupport CS keys and auth style?
- create isos repo
- admin maintenance menu
- Patch method for these menus.
- add restore snapshot link stuff.
- match rti staging added packages to daisy.
- install; set server hostname.
- tfrsync.pl change to not require only numbers for 8 char ID.
- ostools RH8 work around for now?
- add RH8 build repo option.
- install; add tfsupport ssh keys.
- physical media iso creation/download option?
- add spacewalk setup/integration.
- check on security/cvs info on patches and notifications with spacewalk.
- migrate kickstart files to spacewalk.
- 


- Replace daisy console screens with pts equivs.
- POS instance user removal upon shutdown.
- Updated Strongswan config for ipsec.
- Scrub and condence code.
- shellinabox config.
- missing character map piece for daisy.
- Combine base OS ks files from both POS systems into one.
- Sanity checks. EX: don't allow selection of stage if one is already staged.
- examples of cron jobs to backup for different situations.
- Build RTI QA example for management.
- Test install on physical hardware. (It should not matter if it is an AWS instance or not.)
- Add istar rpm to both POS systems.
- Daisy function keys.
- logging and error capturing.
- 


-- For Documentation
- Pic updates.
- Add custom data import.
-  


-- Credits
- GET LINKS
- shellinabox
- pipework
- ksstuff
- docker
- centos
- teleflora
- epel
- 


-- information
- Security related
- PCI council
- openscap
- 



SOME DAY:
---------

-- For Linux
- Multiple containers on the same host.
- Promote it all to CentOS8.
- Integrate with its own CentOS repo if desired.

-- For Windows
- Hyper-V config for running Windows.
- Windows installation.
- Dove POS installation.
- Web based rdp client.
- Software VPN
-
