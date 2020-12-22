posos
-----
msposbackup

- Server-side target for tfrsync.pl --cloud to backup to.

```
-----
10/19/2020 10:57 PM
┏━━━━━━━━
┃ @ Mike's Devel
┃ )~ Data
┃━
┃ Free Space: 994G
┃
┃---
┃ 1. List Accounts
┃ 2. Create Account
┃ 3. Change Key
┃ 4. View Key
┃ 5. Get Key
┃ 6. Delete Account
┃ 7. Is Subscriber?
┃
┃ r. Readme
┃ x. Exit
┗━
Enter selection: 1
tfrsync-01222222 - Daisy   - CentOS - Size on disk: 169M
tfrsync-00000003 - Daisy   - CentOS - Size on disk: 174M
tfrsync-00000001 - Daisy   - CentOS - Size on disk: 171M
tfrsync-00000002 - Daisy   - CentOS - Size on disk: 171M
tfrsync-00000004 - Daisy   - CentOS - Size on disk: 180M
tfrsync-00000005 - Daisy   - CentOS - Size on disk: 181M
tfrsync-00000006 - Daisy   - CentOS - Size on disk: 171M
tfrsync-00000007 - Daisy   - CentOS - Size on disk: 171M
Press enter to continue..
```

```
Sample container crontab for daily backups, rotating each week -
----------------------------------------------------------------

0 0 * * 1 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000001 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 2 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000002 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 3 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000003 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 4 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000004 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 5 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000005 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 6 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000006 --cloud-server=iflorist.myk.green --force-rsync-account
0 0 * * 7 tfrsync.pl --cloud --backup=all --rsync-account=tfrsync-00000007 --cloud-server=iflorist.myk.green --force-rsync-account
```

```
Sample account name scenerios -
-------------------------------

drwx------. 3 sunday-01202001     sunday-01202001       88 Oct 17 09:43 sunday-01202001
drwx------. 3 monday-01202001     monday-01202001       88 Oct 17 09:47 monday-01202001
drwx------. 3 tuesday-01202001    tuesday-01202001      88 Oct 17 09:48 tuesday-01202001
drwx------. 3 wednesday-01202001  wednesday-01202001    88 Oct 17 09:48 wednesday-01202001
drwx------. 3 wednesday-012020010 wednesday-012020010   88 Oct 17 09:49 wednesday-012020010
drwx------. 3 mykdev-20201017     mykdev-20201017       88 Oct 17 09:50 mykdev-20201017
drwx------. 3 mykdev-01222222     mykdev-01222222       88 Oct 17 09:51 mykdev-01222222
```
