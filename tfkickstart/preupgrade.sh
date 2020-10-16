#!/bin/sh
wget http://rtihardware.homelinux.com/ostools/ostools-1.15-latest.tar.gz
tar xvfz ostools-1.15-latest.tar.gz
./bin/install-ostools.pl ./ostools-1.15-latest.tar.gz --noharden-linux
mkdir /usr2/upgrade
cp -f /etc/sysconfig/network-scripts/ifcfg-eth0 /usr2/upgrade/.
cp -f /etc/sysconfig/network-scripts/ifcfg-eth1 /usr2/upgrade/.
cp -f /etc/hosts /usr2/upgrade/.
cp -P /etc/localtime /usr2/upgrade/.
cp -f /etc/resolv.conf /usr2/upgrade/.
hostname >/usr2/upgrade/hostname
dd if=/dev/zero of=/usr2/upgrade/upgrade_backup.img bs=1M count=2000
wget -O /usr2/upgrade/upgrade.config http://rtihardware.homelinux.com/t1800/upgrade.config
wget -O /usr2/upgrade/jdk-8u45-linux.tar.gz http://tposlinux.blob.core.windows.net/rtibbjupdate11/jdk-8u45-linux-x64.tar.gz
/usr2/ostools/bin/rtibackup.pl --backup=all --format --configfile=/usr2/upgrade/upgrade.config
echo "Preupgrade complete. Load the RHEL7 DVD and select upgrade from boot menu."
