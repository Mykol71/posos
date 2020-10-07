Build
-----
An automated build process, using containers, to quickly produce OS media prepared with all the required components needed by the OS and application installation. Technically, the use of pre-prepared media from a marketplace, appstore, or other 3rd party, isn't recommended for PCI compliance. Additionally, in a catastrophic situation, quickly matching patch levels from a customer's physical server becomes a requirement.

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
Enter selection: 12
daisy or rti?: rti
```

```
Starting installer, one moment...
anaconda argparse: terminal size detection failed, using default width
[Errno 25] Inappropriate ioctl for device
anaconda 21.48.22.147-1 for CentOS 7 Docker 7 (pre-release) started.
Starting automated install............
Checking software selection
================================================================================
================================================================================
Installation

 1) [x] Language settings                 2) [x] Time settings
        (English (United States))                (America/Chicago timezone)
 3) [x] Installation source               4) [x] Software selection
        (http://mirrors.kernel.org/cent          (Custom software selected)
        os/7/os/x86_64/)
 5) [x] Network configuration
        (Connected: eth1, docker0 (),
        ens5)
================================================================================
================================================================================
Progress
Setting up the installation environment
.
Running pre-installation scripts
j.
Starting package installation process
Preparing transaction from installation source
Installing libgcc (1/615)
Installing fontpackages-filesystem (2/615)
Installing poppler-data (3/615)
Installing libreport-filesystem (4/615)
Installing bind-license (5/615)
Installing langtable (6/615)
.  
.. 
...
Removing intermediate container bbd1052e4a93
Step 29/31 : EXPOSE 445
 ---> Running in d7e162ea6127
 ---> 1eede00a7e58
Removing intermediate container d7e162ea6127
Step 30/31 : EXPOSE 631
 ---> Running in ca7a4630aeb5
 ---> d0ed99e5e25d
Removing intermediate container ca7a4630aeb5
Step 31/31 : CMD [“/usr/bin/bash”]
 ---> Running in b6530f49b66c
 ---> 8b1cc27630a5
Removing intermediate container b6530f49b66c
Successfully built 8b1cc27630a5
/home/tfsupport/msposapp/bin

real    14m16.460s
user    12m7.525s
sys     0m40.405s
Press enter to continue..
```

```
Enter selection: 11
REPOSITORY                         TAG                 IMAGE ID            CREATED             SIZE
centos7-rti-16.1.3                 latest              05b1c483ffcf        19 seconds ago      1.38 GB
Press enter to continue..
```

Next
----

[Stage](stage.md)

-------
Mike Green - mgreen@teleflora.org
