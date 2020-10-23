# Basic setup information
install
keyboard us
rootpw --iscrypted $1$b2bDwXkz$ZpKi4Jx7tox779nrUdt8h1
timezone --isUtc --nontp UTC
selinux --enforcing
firewall --disabled
network --bootproto=dhcp --device=link --activate --onboot=on
shutdown
bootloader --disable
lang en_US

# Disk setup
zerombr
clearpart --all --initlabel
part / --asprimary --fstype="ext4" --size=10000

# Repos
url --url="https://mirrors.edge.kernel.org/centos/8/BaseOS/x86_64/kickstart/"
repo --name="CentOS" --baseurl=https://mirrors.edge.kernel.org/centos/8/BaseOS/x86_64/kickstart/ --cost=100
repo --name="Updates" --baseurl=https://mirrors.edge.kernel.org/centos/8/BaseOS/x86_64/os/ --cost=100

# Package setup
%packages --excludedocs --instLangs=en --nocore
centos-release
binutils
-brotli
bash
hostname
rootfiles
coreutils-single
glibc-minimal-langpack
vim-minimal
less
-gettext*
-firewalld
-os-prober*
tar
-iptables
iputils
-kernel
-dosfstools
-e2fsprogs
-fuse-libs
-gnupg2-smime
-libss
-pinentry
-shared-mime-info
-trousers
-xkeyboard-config
-xfsprogs
-qemu-guest-agent
yum
-grub\*

%end

%post --erroronfail --log=/root/anaconda-post.log
# container customizations inside the chroot

echo 'container' > /etc/dnf/vars/infra

#Generate installtime file record
/bin/date +%Y%m%d_%H%M > /etc/BUILDTIME

# Limit languages to help reduce size.
LANG="en_US:UTF-8"
echo "%_install_langs $LANG" > /etc/rpm/macros.image-language-conf

# systemd fixes
:> /etc/machine-id
umount /run
systemd-tmpfiles --create --boot
# mask mounts and login bits
systemctl mask systemd-logind.service getty.target console-getty.service sys-fs-fuse-connections.mount systemd-remount-fs.service dev-hugepages.mount

# Remove things we don't need
rm -f /etc/udev/hwdb.bin
rm -rf /usr/lib/udev/hwdb.d/
rm -rf /boot
rm -rf /var/lib/dnf/history.*

%end
