#!/bin/bash
#
# Daisy staging script to be ran during the post section of a kickstart install.
# Added KS post syntax:
#
# Mike Green 
#
echo ""
echo "----------------------------------"
echo "Begging Daisy 10.1.22 Staging....."
echo "----------------------------------"
echo ""
echo ""
sleep 5
# Check for internet.
ping -c 1 8.8.8.8
if [ $? -eq 0 ]; then
	echo "Internet connection working.....continuing"
else
	echo "Internet connection down.....exiting"
	exit 1
fi
#
cd /tmp
#
# Create Daisy dir if not exist.
[ ! -d /d ] && mkdir /d
#
# Add term.sh to /etc/profile.d
[ ! -f /etc/profile.d/term.sh ] && echo unicode_stop > /etc/profile.d/term.sh && chmod +x /etc/profile.d/term.sh
#
# Download i18n file.
#curl -O http://rtihardware.homelinux.com/rhel7.7_64_daisy_efi/i18n
#cp -f ./i18n /etc/sysconfig/.
#
# Download and install ostools.
curl -O http://rtihardware.homelinux.com/ostools/ostools-1.15-latest.tar.gz
tar xvfz ostools-1.15-latest.tar.gz
./bin/install-ostools.pl ./ostools-1.15-latest.tar.gz --noharden-linux
#
# Register with Redhat
#/d/ostools/bin/updateos.pl --sub-mgr-reg
#
# Install dependent RPMs.
#yum -y install perl perl-Digest-MD5 samba iptables ntp smartmontools boost boost-regex dialog telnet iptables-services ncurses-term wget net-tools
#
# Configure firewall.
systemctl enable iptables
/d/ostools/bin/harden_linux.pl --iptables
#
# Download Daisy and Daisy migration script.
cd /tmp
curl -O http://rtihardware.homelinux.com/rhel7.7_64_daisy_upgrade/daisy_10.1.22_rhel7.iso
curl -O http://rtihardware.homelinux.com/rhel7.7_64_daisy_upgrade/daisy7-mig.sh
#
# Prep for Daisy install.
/d/ostools/bin/updateos.pl --daisy8
#
# Install Daisy.
[ ! -d /mnt/cdrom ] && mkdir /mnt/cdrom
mount -o loop /tmp/daisy_10.1.22_rhel7.iso /mnt/cdrom
cd /mnt/cdrom
systemctl disable getty@tty1
./install-daisy.pl /d/daisy
cd /tmp
umount /mnt/cdrom
#
# Install tfsupport authentication stuff.
[ ! -d /home/tfsupport/.ssh ] && mkdir /home/tfsupport/.ssh
chmod 700 /home/tfsupport/.ssh
chown tfsupport:daisy /home/tfsupport/.ssh
curl -O http://rtihardware.homelinux.com/t1800/tfsupport-authorized_keys
curl -O http://rtihardware.homelinux.com/t1800/twofactor-20090723.tar
tar xvf /tmp/twofactor-20090723.tar
chmod +x /tmp/*.pl
cp /tmp/tfsupport-authorized_keys /home/tfsupport/.ssh/authorized_keys
chmod 700 /home/tfsupport/.ssh/authorized_keys
chown tfsupport:root /home/tfsupport/.ssh/authorized_keys
rm -f /etc/cron.d/nightly-backup
rm -f /tmp/rtibackup.pl
#
# Install Kaseya
echo "Downloading Kaseya install script....."
curl -O http://rtihardware.homelinux.com/support/KcsSetup.sh
chmod +x /tmp/KcsSetup.sh
echo "Installing Kaseya....."
/tmp/KcsSetup.sh
#
# Install EDir.
echo "Installing base edir....."
cd /tmp
rm -f /tmp/edir_installbase.pl
curl -O http://rtihardware.homelinux.com/daisy/edir_installbase.pl
chmod +x /tmp/edir_installbase.pl
curl -O http://rtihardware.homelinux.com/daisy/edir_base_latest.tar.gz
/tmp/edir_installbase.pl /tmp/edir_base_latest.tar.gz
echo "edir base installed....."
cd /d/daisy
./rbl 20
cd /d/startup
#
# Install ostools with hardening.
cd /tmp
tar xvfz ./ostools-1.15-latest.tar.gz
./bin/install-ostools.pl ./ostools-1.15-latest.tar.gz
#
# Enabling ttys.
echo "Enabling Virtual Consoles...."
for x in {1..12}
do
systemctl enable getty@tty$x.service
done
#
# Locale setup
/d/ostools/bin/updateos.pl --locale
#
# OS Patches.
echo "Patching the OS...."
#/d/ostools/bin/updateos.pl --ospatches
#
echo "Done."
