#!/usr/bin/bash
#echo "\`date\` -- Beginning RTI Install \${1}.teleflora.com"
cd /usr/local/bin
wget http://rtihardware.homelinux.com/ostools/ostools-1.15-latest.tar.gz
tar xvfz ostools-1.15-latest.tar.gz
#./bin/install-ostools.pl ./ostools-1.15-latest.tar.gz
#/teleflora/ostools/bin/updateos.pl --hostname=\$1
#/teleflora/ostools/bin/harden_linux.pl --iptables
echo "Copying files from DVD. This will take a bit....."
#mount \$CDROM /mnt
#cp /mnt/2145830.jar.gz /usr/local/bin
#cp /mnt/blm.2145830.jar.gz /usr/local/bin
#cp /mnt/jdk-8u65-linux-x64.tar.gz /usr/local/bin
#cp /mnt/jre-latest-linux-x64-rpm.bin /usr/local/bin
#cp /mnt/RTI-16.1.5-Linux.iso.gz /usr/local/bin
#cp /mnt/update_bbj_15.pl /usr/local/bin
#cp /mnt/bbj15update.tar.gz /usr/local/bin
#cp /mnt/14_rhel6.tar.gz /usr/local/bin
#cp /mnt/tfsupport-authorized_keys /usr/local/bin/tfsupport-authorized_keys
#cp /mnt/twofactor-20090723.tar /usr/local/bin/twofactor-20090723.tar
#cp /mnt/multiserver.pwd /usr/local/bin
#umount /mnt
#echo "Done copying files...."
#cd /usr/local/bin
#echo "Extracting files...."
#tar xvfz /usr/local/bin/14_rhel6.tar.gz
#gunzip /usr/local/bin/RTI-16.1.5-Linux.iso.gz
#/teleflora/ostools/bin/updateos.pl --baremetal
#/teleflora/ostools/bin/updateos.pl --ospatches
#/teleflora/ostools/bin/updateos.pl --rti14
#mkdir /usr2/bbx
#mkdir /usr2/bbx/bin
#ln -s /usr2/ostools/bin/rtiuser.pl /usr2/bbx/bin/rtiuser.pl
#echo "bbj 8 installed......"
service blm start
service bbj start
echo "Installing RTI...."
#mount -o loop /usr/local/bin/RTI-16.1.5-Linux.iso /mnt
#cd /mnt
#./install_rti-16.1.5.pl --nobbxt /usr2/bbx
#/teleflora/ostools/bin/updateos.pl --samba-set-passdb
cd /usr/local/bin
echo "Installing bbj 15......"
#chmod +x /usr/local/bin/update_bbj_15.pl
#/usr/local/bin/update_bbj_15.pl --bbj15
#echo "Fixing init.d service files....."
#sed -i '1s/^/#Required-Start:\ \$network\n/' /etc/init.d/blm
#sed -i '1s/^/#Required-Start:\ blm\ \$network\n/' /etc/init.d/bbj
#sed -i '1s/^/#\!\/bin\/sh\n/' /etc/init.d/blm
#sed -i '1s/^/#\!\/bin\/sh\n/' /etc/init.d/bbj
#echo "Installing RTI Florist Directory...."
#wget http://tposlinux.blob.core.windows.net/rti-edir/rti-edir-tel-latest.patch
#wget http://tposlinux.blob.core.windows.net/rti-edir/applypatch.pl
#./applypatch.pl ./rti-edir-tel-latest.patch
#echo "Installing tfsupport authorized keys...."
#mkdir /home/tfsupport/.ssh
#chmod 700 /home/tfsupport/.ssh
#chown tfsupport:rti /home/tfsupport/.ssh
#tar xvf /usr/local/bin/twofactor-20090723.tar
#chmod +x /usr/local/bin/*.pl
#cp /usr/local/bin/tfsupport-authorized_keys /home/tfsupport/.ssh/authorized_keys
#chmod 700 /home/tfsupport/.ssh/authorized_keys
#chown tfsupport:root /home/tfsupport/.ssh/authorized_keys
#echo "Installing admin menus....."
#/usr/local/bin/install_adminmenus.pl --run
#rm -f /etc/cron.d/nightly-backup
#rm -f /usr/local/bin/rtibackup.pl
#cd /usr/local/bin
#./bin/install-ostools.pl ./ostools-1.15-latest.tar.gz
#echo "Installing the backups.config file to exclude files during restore...."
#wget http://rtihardware.homelinux.com/ostools/backups.config.rhel7
#cp /usr2/bbx/config/backups.config /usr2/bbx/config/backups.config.save
#cp backups.config.rhel7 /usr2/bbx/config/backups.config
#chmod 777 /usr2/bbx/config/backups.config
#chown tfsupport:rtiadmins /usr2/bbx/config/backups.config
wget http://rtihardware.homelinux.com/ostools/librxtxSerial.so
echo "Installing 32-bit library for serial ports...."
cp /usr2/basis/lib/librxtxSerial.so /usr2/basis/lib/librxtxSerial.so.64bit
cp librxtxSerial.so /usr2/basis/lib/librxtxSerial.so
chmod 666 /usr2/basis/lib/librxtxSerial.so
chown root:root /usr2/basis/lib/librxtxSerial.so
#echo "Adding multiserver.pwd fix....."
#cp -f /usr/local/bin/multiserver.pwd /usr2/bbx/config/
# Install tcc
#echo "Installing tcc....."
#cd /usr2/bbx/bin
#wget http://rtihardware.homelinux.com/support/tcc/tcc-latest_linux.tar.gz
#tar xvfz ./tcc-latest_linux.tar.gz
#rm -f ./tcc
#rm -f ./tcc_tws
#ln -s ./tcc2_rhel7 ./tcc
#ln -s ./tcc_rhel7 ./tcc_tws
#cd /usr/local/bin
#echo "Done installing tcc..."
#echo "Installing Kaseya....."
#wget http://rtihardware.homelinux.com/support/KcsSetup.sh
#chmod +x /usr/local/bin/KcsSetup.sh
#/usr/local/bin/KcsSetup.sh
