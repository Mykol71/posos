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
network --bootproto=dhcp --activate --onboot=on
shutdown
bootloader --disable
#lang en_US.UTF-8
lang en_US.UTF-8  --addsupport=en_US,en
auth  --useshadow --passalgo=sha512
firewall --enabled --ssh  --trust=eth0
firstboot --disable
logging --level=info

# Repositories to use
repo --name="CentOS" --baseurl=http://mirrors.kernel.org/centos/7/os/x86_64/ --cost=100
## Uncomment for rolling builds
repo --name="Updates" --baseurl=http://mirror.centos.org/centos/7/updates/x86_64/ --cost=100

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

mknod /dev/loop0 b 7 0

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

LANG="en_US.utf8"
echo "%_install_lang $LANG" > /etc/rpm/macros.image-language-conf

awk '(NF==0&&!done){print "override_install_langs=en_US.utf8\ntsflags=nodocs";done=1}{print}' \
    < /etc/yum.conf > /etc/yum.conf.new
mv /etc/yum.conf.new /etc/yum.conf
echo 'container' > /etc/yum/vars/infra

##Setup locale properly
# Commenting out, as this seems to no longer be needed
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

%end
