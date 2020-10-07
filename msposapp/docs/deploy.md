Deployment
----------

Create and start VPN connection(s) if you didnt during staging, shutdown application on physical server (if exists), run final backup to sync data (if exists), restore customer data, then start the application instance in the cloud.

```
 02/01/2019  1:16 AM
┏━━━━━━━━━
┃🌷 POS Cloud Menu 
┣━
┃ Mike's Store of Stuff
┃ 12345678
┃
┃ Status: Up 43 minutes
┃ Type  : m5d.xlarge
┃ POS IP: 192.168.222.222
┃ Free  : 69G
┃ Patchd: Tue Jan 29 07:51:25 CST 2019
┃
┃ VPNs:
┃     remote1{1}:   192.168.222.0/24 === 192.168.22.0/24
┃
┃ 1. POS Status
┃ 2. Start POS
┃ 3. Stop POS
┃ 4. Connect to POS
┃ 5. Restore POS Data
┃
┃ 11. List Images
┃ 12. Build OS Media
┃ 13. Stage POS
┃ 14. Delete Image(s)
┃ 15. Test Print
┃
┃ 111. VPN Status
┃ 112. Create VPN
┃ 113. Start VPN(s)
┃ 114. Stop VPN(s)
┃ 115. Delete VPN(s)
┃
┃ p. Purge All
┃ i. I/C/U Deps
┃ r. Readme
┃ x. Exit
┗━
Enter selection: 
```

```
Enter selection: 111
Security Associations (1 up, 0 connecting):
   phonehome[1]: ESTABLISHED 2 minutes ago, 192.168.222.233[35.182.191.52]...70.175.163.115[70.175.163.115]
   phonehome{1}:  INSTALLED, TUNNEL, reqid 1, ESP in UDP SPIs: 032b7ac6_i 0e86eb3c_o
   phonehome{1}:   192.168.222.0/24 === 192.168.22.0/24
Press enter to continue..
```

Next
----

[Ongoing Maintenance](maintain.md)

-----------------------
Mike Green - mgreen@teleflora.org
