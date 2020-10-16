lang en_US
keyboard us
timezone America/Chicago --isUtc
rootpw $1$Yk7QrM4n$1v8ys8uRQklH3UeQUBrxV1 --iscrypted
#platform x86, AMD64, or Intel EM64T
reboot
text
url --url=http://rtihardware.homelinux.com/rhel7.7_64_daisy_efi/
#cdrom
zerombr
clearpart --all --initlabel
bootloader --location=mbr --append=biosdevname=0 video=640x480 net.ifnames=0
#part biosboot --fstype=biosboot --size=1 --ondisk=nvme0n1
autopart --type=plain --fstype=xfs
#part /boot/efi --fstype=efi --grow --maxsize=200 --size=20
#part /boot --fstype=ext4 --size=512
#part / --fstype=ext4 --size=20096
#part /d --fstype=ext4 --size=40768 --grow
#part swap --size=4000
# Configure the bootloader.
auth --passalgo=sha512 --useshadow
user --groups=wheel --name=tfsupport --password=$1$Yk7QrM4n$1v8ys8uRQklH3UeQUBrxV1 --iscrypted 
selinux --permissive
firewall --disabled
skipx
firstboot --disable
%pre
# clear the MBR and partition table
#dd if=/dev/zero of=/dev/nvme0n1 bs=512 count=1
#parted -s /dev/sda mklabel msdos
%end
%post
exec < /dev/tty3 > /dev/tty3
chvt 3
(
cd /tmp
curl -O http://rtihardware.homelinux.com/support/daisy_uefi.sh
chmod +x /tmp/daisy_uefi.sh
/tmp/daisy_uefi.sh | tee /tmp/daisy_uefi.sh.log
) 2>&1 | /usr/bin/tee /tmp/ks-post.log
chvt 1
%end
%packages
@Base
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
