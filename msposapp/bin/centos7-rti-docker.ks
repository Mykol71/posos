# This is a minimal CentOS kickstart designed for docker.
# It will not produce a bootable system
# To use this kickstart, run the following command
# livemedia-creator --make-tar \
#   --iso=/path/to/boot.iso  \
#   --ks=centos-7.ks \
#   --image-name=centos-root.tar.xz
#
# Once the image has been generated, it can be imported into docker
# by using: cat centos-root.tar.xz | docker import -i imagename

# Basic setup information
url --url="http://mirrors.kernel.org/centos/7/os/x86_64/"
install
keyboard us
rootpw --iscrypted $1$b2bDwXkz$ZpKi4Jx7tox779nrUdt8h1
selinux --permissive
skipx
timezone  America/Chicago
install
network --bootproto=dhcp --device=eth0 --activate --onboot=on
shutdown
bootloader --disable
lang en_US
auth  --useshadow --passalgo=sha512
firewall --enabled --ssh  --trust=eth0
firstboot --disable
logging --level=info

# Repositories to use
repo --name="CentOS" --baseurl=http://mirrors.kernel.org/centos/7/os/x86_64/ --cost=100
## Uncomment for rolling builds
#repo --name="Updates" --baseurl=http://mirror.centos.org/centos/7/updates/x86_64/ --cost=100

# Disk setup
zerombr
clearpart --all --initlabel
part / --asprimary --fstype="ext4" --size=30000
part /teleflora --asprimary --fstype="ext4" --grow --size=1

%addon org_fedora_oscap
content-type = scap-security-guide
profile = pci-dss
%end

# Package setup
%packages --excludedocs --instLangs=en --nocore
@Base
bind-utils
bash
yum
vim-minimal
centos-release
less
-kernel*
-*firmware
-firewalld-filesystem
-os-prober
-gettext*
-GeoIP
-bind-license
-freetype
iputils
iproute
systemd
rootfiles
-libteam
-teamd
tar
passwd
yum-utils
yum-plugin-ovl
firewalld
java
samba
cups
minicom
elinks
telnet
mc
glibc
mutt
samba-client
slang
curl
sendmail
glibc.i686
strace
dvd+rw-tools
dialog
firstboot
mtools
cdrecord
fetchmail
net-snmp
vlock
sysstat
ntp
procps
e2fsprogs
audit
expect
ksh
nmap
uuid
libuuid
screen
dos2unix
unix2dos
yum-presto
ncurses-term
boost
biosdevname
iptables-services
perl-Digest
perl-Digest-MD5
-chrony
%end
%post --log=/anaconda-post.log

cat << xxxEOFxxx > /tmp/ksrti.sh
#!/bin/bash
LOG="/tmp/ksrti.sh.log"
/tmp/ksrti_install.sh \$1 \$2 \$3 \$4 \$5 2>&1 | tee -a \$LOG
xxxEOFxxx

cat << xxxEOFxxx > /tmp/ksrti_install.sh
#!/bin/bash
# Script to run, just after a kickstart, which will start things rolling.
CDROM="/dev/sr0"
if [ \$# -eq 0 ]; then
        echo "Below is the usage info. Please note only the hostname is required."
        echo "Usage ksrti.sh {hostname} {ipaddr} {dnsaddr} {gateway} {netmask}"
        exit 1
fi
if [ "\$2" == "" ]; then
        new_ip="192.168.1.21"
else
        new_ip="\$2"
fi
if [ "\$3" == "" ]; then
        new_dns="192.168.1.1"
else
        new_dns="\$3"
fi
if [ "\$4" == "" ]; then
        new_gateway="192.168.1.1"
else
        new_gateway="\$4"
fi
if [ "\$5" == "" ]; then
        new_netmask="255.255.255.0"
else
        new_netmask="\$5"
fi
mount \$CDROM /mnt
if [ \$? -eq 0 ]; then
        umount \$CDROM
        echo "CDROM mounting ok.....continuing"
else
        echo "CDROM could not be mounted.....exiting"
        exit 1
fi
ping -c 5 google.com
if [ \$? -eq 0 ]; then
        echo "Internet connection working.....continuing"
else
        echo "Internet connection down.....exiting"
        exit 1
fi
echo "\`date\` -- Beginning RTI Install \${1}.teleflora.com" >/tmp/verify.txt
cd /tmp
wget http://rtihardware.homelinux.com/ostools/ostools-1.15-latest.tar.gz
tar xvfz ostools-1.15-latest.tar.gz
./bin/install-ostools.pl ./ostools-1.15-latest.tar.gz
/teleflora/ostools/bin/updateos.pl --ipaddr="\$new_ip" --gateway="\$new_gateway" --netmask="\$new_netmask" --hostname=\$1
service network restart
/teleflora/ostools/bin/updateos.pl --nameserver="\$new_dns"
ping -c 5 google.com
if [ \$? -eq 0 ]; then
        echo "Internet connection working.....continuing"
else
        echo "Internet connection down.....exiting"
        exit 1
fi
systemctl disable firewalld
systemctl enable iptables
yum -y remove firewalld
/teleflora/ostools/bin/harden_linux.pl --iptables
echo "Copying files from DVD. This will take a bit....."
mount \$CDROM /mnt
cp /mnt/2145830.jar.gz /tmp
cp /mnt/blm.2145830.jar.gz /tmp
cp /mnt/jdk-8u65-linux-x64.tar.gz /tmp
cp /mnt/jre-latest-linux-x64-rpm.bin /tmp
cp /mnt/RTI-16.1.5-Linux.iso.gz /tmp
cp /mnt/update_bbj_15.pl /tmp
cp /mnt/bbj15update.tar.gz /tmp
cp /mnt/14_rhel6.tar.gz /tmp
cp /mnt/tfsupport-authorized_keys /tmp/tfsupport-authorized_keys
cp /mnt/twofactor-20090723.tar /tmp/twofactor-20090723.tar
cp /mnt/multiserver.pwd /tmp
umount /mnt
echo "Done copying files...."
cd /tmp
echo "Extracting files...."
tar xvfz /tmp/14_rhel6.tar.gz
gunzip /tmp/RTI-16.1.5-Linux.iso.gz
/teleflora/ostools/bin/updateos.pl --baremetal
/teleflora/ostools/bin/updateos.pl --ospatches
/teleflora/ostools/bin/updateos.pl --rti14
service blm start
sleep 3
ps -ef | grep basis
echo ; echo ; echo
echo "Make sure that you see the -T above and Press enter to continue"
read X
mkdir /usr2/bbx
mkdir /usr2/bbx/bin
ln -s /usr2/ostools/bin/rtiuser.pl /usr2/bbx/bin/rtiuser.pl
echo "bbj 8 installed......"
service blm start
sleep 3
ps -ef | grep basis
echo ; echo ; echo
echo "Make sure that you see the -T above and Press enter to continue"
read X
mkdir /usr2/bbx
mkdir /usr2/bbx/bin
ln -s /usr2/ostools/bin/rtiuser.pl /usr2/bbx/bin/rtiuser.pl
echo "bbj 8 installed......"
service blm start
service bbj start
echo "Installing RTI...."
mount -o loop /tmp/RTI-16.1.5-Linux.iso /mnt
cd /mnt
./install_rti-16.1.5.pl --nobbxt /usr2/bbx
/teleflora/ostools/bin/updateos.pl --samba-set-passdb
umount /mnt
#systemctl enable blm
#systemctl enable bbj
#systemctl enable rti
cd /tmp
echo "Installing bbj 15......"
chmod +x /tmp/update_bbj_15.pl
/tmp/update_bbj_15.pl --bbj15
echo "Fixing init.d service files....."
sed -i '1s/^/#Required-Start:\ \$network\n/' /etc/init.d/blm
sed -i '1s/^/#Required-Start:\ blm\ \$network\n/' /etc/init.d/bbj
sed -i '1s/^/#\!\/bin\/sh\n/' /etc/init.d/blm
sed -i '1s/^/#\!\/bin\/sh\n/' /etc/init.d/bbj
echo "Installing RTI Florist Directory...."
wget http://tposlinux.blob.core.windows.net/rti-edir/rti-edir-tel-latest.patch
wget http://tposlinux.blob.core.windows.net/rti-edir/applypatch.pl
./applypatch.pl ./rti-edir-tel-latest.patch
echo "Installing tfsupport authorized keys...."
mkdir /home/tfsupport/.ssh
chmod 700 /home/tfsupport/.ssh
chown tfsupport:rti /home/tfsupport/.ssh
tar xvf /tmp/twofactor-20090723.tar
chmod +x /tmp/*.pl
cp /tmp/tfsupport-authorized_keys /home/tfsupport/.ssh/authorized_keys
chmod 700 /home/tfsupport/.ssh/authorized_keys
chown tfsupport:root /home/tfsupport/.ssh/authorized_keys
echo "Installing admin menus....."
/tmp/install_adminmenus.pl --run
echo "Installing Dell dset...."
gunzip /tmp/delldset_v2.0.0.119_A00.bin.gz
/tmp/dset.sh
rm -f /etc/cron.d/nightly-backup
rm -f /tmp/rtibackup.pl
cd /tmp
./bin/install-ostools.pl ./ostools-1.15-latest.tar.gz
echo "Installing the backups.config file to exclude files during restore...."
wget http://rtihardware.homelinux.com/ostools/backups.config.rhel7
cp /usr2/bbx/config/backups.config /usr2/bbx/config/backups.config.save
cp backups.config.rhel7 /usr2/bbx/config/backups.config
chmod 777 /usr2/bbx/config/backups.config
chown tfsupport:rtiadmins /usr2/bbx/config/backups.config
wget http://rtihardware.homelinux.com/ostools/librxtxSerial.so
echo "Installing 32-bit library for serial ports...."
cp /usr2/basis/lib/librxtxSerial.so /usr2/basis/lib/librxtxSerial.so.64bit
cp librxtxSerial.so /usr2/basis/lib/librxtxSerial.so
chmod 666 /usr2/basis/lib/librxtxSerial.so
chown root:root /usr2/basis/lib/librxtxSerial.so
echo "Adding multiserver.pwd fix....."
cp -f /tmp/multiserver.pwd /usr2/bbx/config/
# Install tcc
echo "Installing tcc....."
cd /usr2/bbx/bin
wget http://rtihardware.homelinux.com/support/tcc/tcc-latest_linux.tar.gz
tar xvfz ./tcc-latest_linux.tar.gz
rm -f ./tcc
rm -f ./tcc_tws
ln -s ./tcc2_rhel7 ./tcc
ln -s ./tcc_rhel7 ./tcc_tws
cd /tmp
echo "Done installing tcc..."
echo "Installing Kaseya....."
wget http://rtihardware.homelinux.com/support/KcsSetup.sh
chmod +x /tmp/KcsSetup.sh
/tmp/KcsSetup.sh
echo "\`date\` -- End RTI Install \${1}.teleflora.com" >>/tmp/verify.txt
# Verify
/tmp/verify.sh
echo "Remove the DVD from the drive"
echo "Please reboot the system......ctl-alt-del"
xxxEOFxxx

if [[ ! -e /etc/profile.d/term.sh ]]; then
cat << xxxEOFxxx > /etc/profile.d/term.sh
unicode_stop
xxxEOFxxx
fi

cat << xxxEOFxxx >> /tmp/verify.sh
echo "--------------------">>/tmp/verify.txt
echo "ifconfig results....">>/tmp/verify.txt
ifconfig >>/tmp/verify.txt
echo "--------------------">>/tmp/verify.txt
echo "etc/hosts ....">>/tmp/verify.txt
cat /etc/hosts >>/tmp/verify.txt
echo "--------------------">>/tmp/verify.txt
echo "etc/resolve.conf .....">>/tmp/verify.txt
cat /etc/resolv.conf >>/tmp/verify.txt
echo "--------------------">>/tmp/verify.txt
echo "netstat results....">>/tmp/verify.txt
netstat -rn >>/tmp/verify.txt
echo "--------------------">>/tmp/verify.txt
echo "etc/samba/smb.conf .....">>/tmp/verify.txt
cat /etc/samba/smb.conf >>/tmp/verify.txt
echo "--------------------">>/tmp/verify.txt
echo "usr2/basis/basis.lic .....">>/tmp/verify.txt
cat /usr2/basis/basis.lic >>/tmp/verify.txt
echo "--------------------">>/tmp/verify.txt
echo "/etc/hosts.allow">>/tmp/verify.txt
cat /etc/hosts.allow >>/tmp/verify.txt
echo "--------------------">>/tmp/verify.txt
mail -s \`hostname\` mgreen@teleflora.com,kpugh@teleflora.com,sjackson@teleflora.com </tmp/verify.txt
xxxEOFxxx

cd /tmp
chmod +x /tmp/*.sh
chmod +x /tmp/*.pl

/usr/bin/chage -d 0 root

# Post configure tasks for Docker

# remove stuff we don't need that anaconda insists on
# kernel needs to be removed by rpm, because of grubby
rpm -e kernel

yum -y remove bind-libs bind-libs-lite dhclient dhcp-common dhcp-libs \
  dracut-network e2fsprogs e2fsprogs-libs ebtables ethtool file \
  firewalld freetype gettext gettext-libs groff-base grub2 grub2-tools \
  grubby initscripts iproute iptables kexec-tools libcroco libgomp \
  libmnl libnetfilter_conntrack libnfnetlink libselinux-python lzo \
  libunistring os-prober python-decorator python-slip python-slip-dbus \
  snappy sysvinit-tools which linux-firmware GeoIP firewalld-filesystem

yum clean all

#clean up unused directories
rm -rf /boot
rm -rf /etc/firewalld

# Lock roots account, keep roots account password-less.
passwd -l root

#LANG="en_US"
#echo "%_install_lang $LANG" > /etc/rpm/macros.image-language-conf

awk '(NF==0&&!done){print "override_install_langs=en_US.utf8\ntsflags=nodocs";done=1}{print}' \
    < /etc/yum.conf > /etc/yum.conf.new
mv /etc/yum.conf.new /etc/yum.conf
echo 'container' > /etc/yum/vars/infra


##Setup locale properly
# Commenting out, as this seems to no longer be needed
#rm -f /usr/lib/locale/locale-archive
#localedef -v -c -i en_US -f UTF-8 en_US.UTF-8

## Remove some things we don't need
rm -rf /var/cache/yum/x86_64
rm -f /tmp/ks-script*
rm -rf /var/log/anaconda
rm -rf /tmp/ks-script*
rm -rf /etc/sysconfig/network-scripts/ifcfg-*
# do we really need a hardware database in a container?
rm -rf /etc/udev/hwdb.bin
rm -rf /usr/lib/udev/hwdb.d/*

## Systemd fixes
# no machine-id by default.
:> /etc/machine-id
# Fix /run/lock breakage since it's not tmpfs in docker
umount /run
systemd-tmpfiles --create --boot
# Make sure login works
rm /var/run/nologin

#Generate installtime file record
/bin/date +%Y%m%d_%H%M > /etc/BUILDTIME

%end
