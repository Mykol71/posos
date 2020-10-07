Installation
-----------------------

 Install git; Download the Admin Menus; then run the installer to assign an IP, and customer.

```
yum install git
git clone https://github.com/mykol71/msposapp
cd msposapp/bin
sudo ./install
```

 The required packages will be installed and configured, then the system will reboot.

```
Env Name: Mike's Store of Stuff
POS IP Adress: 192.168.222.222
POS Shop Code: 12345678
```

```
Loaded plugins: fastestmirror, langpacks
Cleaning repos: base epel extras updates
Loaded plugins: fastestmirror, langpacks
Determining fastest mirrors
epel/x86_64/metalink                                                                               |  15 kB  00:00:00
...
..
.
No packages marked for update

Done!

The system will reboot in 10secs. Please log back in with the same credentials.
```

 Once logged back in, you will see the Admin Menu.

```
 02/01/2019 12:14 AM
┏━━━━━━━━━
┃🌷 POS Cloud Menu 
┣━
┃ Mike's Store of Stuff
┃ 12345678
┃
┃ Status: 
┃ Type  : m5d.xlarge
┃ POS IP: 192.168.222.222
┃ Free  : 78G
┃ Patchd: Tue Jan 29 07:51:25 CST 2019
┃
┃ VPNs:
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
```

Next
----

[Build](build.md)

 The resulting container will be hardened, as well as address the gaps covered by the PCI references below. It will run the  linux POS application in a container that is built with the same processes as the physical servers offered to the florists  now. There will be a 1-to-1 container to host ratio to allow all host resources to be used by the point of sale application, as well as simplify the segregation of customer data per PA-DSS requirements. The point of sale instance will be connected by VPN connection to the florist's network(s), and route all traffic through the florist via that VPN tunnel (one VPN tunnel per remote location). Or "spoke and wheel" VPN configuration. This allows us to block all ports inbound to the container itself because we are using the POS application server as the VPN client, who ___initiates___ the connection(s).

------------------------
Mike Green - mgreen@teleflora.org
