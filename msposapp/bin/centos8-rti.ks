# Basic setup information
url --url="http://mirrors.kernel.org/centos/8/os/x86_64/"
install
keyboard us
rootpw --iscrypted $1$b2bDwXkz$ZpKi4Jx7tox779nrUdt8h1
selinux --permissive
skipx
timezone  America/Chicago
install
network --bootproto=dhcp --activate --onboot=on
shutdown
bootloader --disable
lang en_US
auth  --useshadow --passalgo=sha512
firewall --enabled --ssh  --trust=eth0
firstboot --disable
logging --level=info

# Repositories to use
repo --name="CentOS" --baseurl=http://mirrors.kernel.org/centos/8/kickstart/x86_64/os/ --cost=100
## Uncomment for rolling builds
repo --name="CentOS Updates" --baseurl=http://mirror.centos.org/centos/8/BaseOS/x86_64/os/ --cost=100

# Disk setup
zerombr
clearpart --all --initlabel
part / --asprimary --fstype="ext4" --size=10000

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
initscripts
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
deltarpm
-chrony
%end
%post --log=/anaconda-post.log

cat << xxxEOFxxx > /usr/local/bin/ksrti.sh
#!/usr/bin/bash
LOG="/var/log/ksrti.sh.log"
/usr/local/bin/ksrti_install.sh 2>&1 | tee -a \$LOG
xxxEOFxxx

cat << xxxEOFxxx > /usr/local/bin/ksrti_install.sh
#!/usr/bin/ksh
#cd /usr/local/bin
#wget -nv "http://rtihardware.homelinux.com/aws/RTI-16.1.5-Linux.iso.gz"
#wget -nv "http://rtihardware.homelinux.com/aws/update_bbj_15.pl"
#wget -nv "http://rtihardware.homelinux.com/aws/tfsupport-authorized_keys"
#wget -nv "http://rtihardware.homelinux.com/aws/twofactor-20090723.tar"
#wget -nv "http://rtihardware.homelinux.com/aws/multiserver.pwd"
#wget -nv "http://rtihardware.homelinux.com/aws/14_rhel6.tar.gz"
echo "\`date\` -- Beginning RTI Install $SHOPCODE.teleflora.com" >/var/log/verify.txt
#echo "Extracting files...."
#tar xvfz ./14_rhel6.tar.gz
#gunzip ./RTI-16.1.5-Linux.iso.gz
export TERM=linux
#/usr2/ostools/bin/updateos.pl --rti14
#sed -i '1s/^/#\!\/usr\/bin\/ksh\n/' /etc/init.d/blm
#sed -i '1s/^/#\!\/usr\/bin\/ksh\n/' /etc/init.d/bbj
#echo "bbj 8 installed......"
#systemctl daemon-reload
#systemctl restart blm
#systemctl restart bbj
#sleep 3
#ps -ef | grep basis
#echo ; echo ; echo
#echo "Make sure that you see the -T above and Press enter to continue"
#read X
#mkdir /usr2/bbx
#mkdir /usr2/bbx/bin
#mkdir /usr2/bbx/log
#mkdir /usr2/bbx/conf
#mkdir /usr2/bbj/cfg
#ln -s /usr2/ostools/bin/rtiuser.pl /usr2/bbx/bin/rtiuser.pl
#echo "bbj 8 installed......"

#echo "Installing bbj 15......"
#chmod +x /usr/local/bin/update_bbj_15.pl
#/usr/local/bin/update_bbj_15.pl --bbj 15
#echo "Fixing init.d service files....."
#sed -i '1s/^/#\!\/usr\/bin\/ksh\n/' /etc/init.d/blm
#sed -i '1s/^/#\!\/usr\/bin\/ksh\n/' /etc/init.d/bbj
#sed -i '1s/^/#\!\/usr\/bin\/ksh\n/' /etc/init.d/rti
#systemctl enable blm
#systemctl enable bbj
#systemctl enable rti
#systemctl restart blm
#systemctl restart bbj
#systemctl restart rti

#echo "Installing RTI...."
#cd /usr/local/bin
#mount -o loop /usr/local/bin/RTI-16.1.5-Linux.iso /mnt
#cd /mnt
#./install_rti-16.1.5.pl --nobbxt /usr2/bbx 2>/dev/null
#/usr2/ostools/bin/updateos.pl --samba-set-passdb
#umount /mnt

echo "Installing RTI Florist Directory...."
#cd /usr/local/bin
#wget -nv http://tposlinux.blob.core.windows.net/rti-edir/rti-edir-tel-latest.patch
#wget -nv http://tposlinux.blob.core.windows.net/rti-edir/applypatch.pl
#./applypatch.pl ./rti-edir-tel-latest.patch

#echo "Installing tfsupport authorized keys...."
#mkdir /home/tfsupport/.ssh
#chmod 700 /home/tfsupport/.ssh
#chown tfsupport:rti /home/tfsupport/.ssh
#tar xvf /usr/local/bin/twofactor-20090723.tar
#chmod +x /usr/local/bin/*.pl
#chmod +x /usr/local/bin/*.sh
#cp /usr/local/bin/tfsupport-authorized_keys /home/tfsupport/.ssh/authorized_keys
#chmod 700 /home/tfsupport/.ssh/authorized_keys
#chown tfsupport:root /home/tfsupport/.ssh/authorized_keys
#rm -f /etc/cron.d/nightly-backup
#rm -f /usr/local/bin/rtibackup.pl
#cd /usr/local/bin
#./bin/install-ostools.pl ./ostools-1.15-latest.tar.gz --noharden-linux

#echo "Installing the backups.config file to exclude files during restore...."
#wget -nv http://rtihardware.homelinux.com/ostools/backups.config.rhel7
#cp /usr2/bbx/config/backups.config /usr2/bbx/config/backups.config.save
#cp backups.config.rhel7 /usr2/bbx/config/backups.config
#chmod 777 /usr2/bbx/config/backups.config
#chown tfsupport:rtiadmins /usr2/bbx/config/backups.config
#echo "Adding multiserver.pwd fix....."
#cp -f /usr/local/bin/multiserver.pwd /usr2/bbx/config/

# Install tcc
#echo "Installing tcc....."
#cd /usr2/bbx/bin
#wget -nv http://rtihardware.homelinux.com/support/tcc/tcc-latest_linux.tar.gz
#tar xvfz ./tcc-latest_linux.tar.gz
#rm -f ./tcc
#rm -f ./tcc_tws
#ln -s ./tcc2_rhel7 ./tcc
#ln -s ./tcc_rhel7 ./tcc_tws
#cd /usr/local/bin

#echo "Installing Kaseya....."
#wget -nv http://rtihardware.homelinux.com/support/KcsSetup.sh
#chmod +x /usr/local/bin/KcsSetup.sh
#/usr/local/bin/KcsSetup.sh

#echo "Patching OS...."
#/usr2/ostools/bin/updateos.pl --ospatches

echo "Creating /etc/profile.d/term.sh"
[ ! -f /etc/profile.d/term.sh ] && echo "unicode_stop" > /etc/profile.d/term.sh
chmod +x /etc/profile.d/term.sh
xxxEOFxxx

#cat << xxxEOFxxx >> /usr/local/bin/verify.sh
#echo "--------------------">>/usr/local/bin/verify.txt
#echo "ifconfig results....">>/usr/local/bin/verify.txt
#ifconfig >>/usr/local/bin/verify.txt
#echo "--------------------">>/usr/local/bin/verify.txt
#echo "etc/hosts ....">>/usr/local/bin/verify.txt
#cat /etc/hosts >>/usr/local/bin/verify.txt
#echo "--------------------">>/usr/local/bin/verify.txt
#echo "etc/resolve.conf .....">>/usr/local/bin/verify.txt
#cat /etc/resolv.conf >>/usr/local/bin/verify.txt
#echo "--------------------">>/usr/local/bin/verify.txt
#echo "netstat results....">>/usr/local/bin/verify.txt
#netstat -rn >>/usr/local/bin/verify.txt
#echo "--------------------">>/usr/local/bin/verify.txt
#echo "etc/samba/smb.conf .....">>/usr/local/bin/verify.txt
#cat /etc/samba/smb.conf >>/usr/local/bin/verify.txt
#echo "--------------------">>/usr/local/bin/verify.txt
#echo "usr2/basis/basis.lic .....">>/usr/local/bin/verify.txt
#cat /usr2/basis/basis.lic >>/usr/local/bin/verify.txt
#echo "--------------------">>/usr/local/bin/verify.txt
#echo "/etc/hosts.allow">>/usr/local/bin/verify.txt
#cat /etc/hosts.allow >>/usr/local/bin/verify.txt
#echo "--------------------">>/usr/local/bin/verify.txt
#mail -s \`hostname\` mgreen@teleflora.com,kpugh@teleflora.com </usr/local/bin/verify.txt
#xxxEOFxxx

#cd /usr/local/bin
#chmod +x /usr/local/bin/*.sh
#chmod +x /usr/local/bin/*.pl

#/usr/bin/chage -d 0 root

# Post configure tasks for Docker

# remove stuff we don't need that anaconda insists on
# kernel needs to be removed by rpm, because of grubby
rpm -e kernel

#yum -y remove bind-libs bind-libs-lite dhclient dhcp-common dhcp-libs \
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
#passwd -l root

#LANG="en_US"
#echo "%_install_lang $LANG" > /etc/rpm/macros.image-language-conf

awk '(NF==0&&!done){print "override_install_langs=en_US.utf8\ntsflags=nodocs";done=1}{print}' \
    < /etc/yum.conf > /etc/yum.conf.new
mv /etc/yum.conf.new /etc/yum.conf
echo 'container' > /etc/yum/vars/infra

##Setup locale properly
rm -f /usr/lib/locale/locale-archive
localedef -v -c -i en_US -f UTF-8 en_US.UTF-8

## Remove some things we don't need
#rm -rf /var/cache/yum/x86_64
#rm -f /tmp/ks-script*
#rm -rf /var/log/anaconda
#rm -rf /tmp/ks-script*
#rm -rf /etc/sysconfig/network-scripts/ifcfg-*
# do we really need a hardware database in a container?
rm -rf /etc/udev/hwdb.bin
rm -rf /usr/lib/udev/hwdb.d/*

## Systemd fixes
# no machine-id by default.
#:> /etc/machine-id
# Fix /run/lock breakage since it's not usr/local/binfs in docker
umount /run
systemd-tmpfiles --create --boot
# Make sure login works
rm /var/run/nologin

#Generate installtime file record
/bin/date +%Y%m%d_%H%M > /etc/BUILDTIME

echo "\`date\` -- End RTI Install $SHOPCODE.teleflora.com" >>/usr/local/bin/verify.txt
# Verify
#/usr/local/bin/verify.sh

%end
