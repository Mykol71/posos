Sample crontab for daily backups, rotating each week:
---
0 0 * * 1 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000001 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 2 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000002 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 3 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000003 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 4 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000004 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 5 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000005 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 6 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000006 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 7 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000007 --cloud-server=iflorist.myk.green --force-rsync-account

TO DO -
-------

- tfsupport CS keys and auth style?


- Replace daisy console screens with pts equivs.
- POS instance user removal upon shutdown.
- Updated ipsec.conf format for Strongswan.
- Scrub and condence code.
- shellinabox config.
- missing character map piece for daisy.
- Combine ks files from both POS systems into one.
- Sanity checks. EX: don't allow selection of stage if one is already staged.
- examples of cron jobs to backup for different situations.
- Build RTI QA example for management.
- Test install on physical hardware. (It should not matter if it is an AWS instance or not.)
- Add istar rpm to both POS systems.
- Daisy function keys.
- logging and error capturing.
- Ask for shop code when staging, not installing.
- Ask for container IP when staging, not installing.
- Patch method of these menus.
- 

-- For Documentation
- Pic updates.
- Add custom data import.
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
