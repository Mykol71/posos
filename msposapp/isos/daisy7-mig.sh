#!/bin/bash
#
# Make sure you have done steps 1 - 7 in the FC to RHEL5 Daisy Server Upgrade doc.
# Set passwords and ips to correct values, and 1 ON and 0 OFF for each feature or migration step below
# Only disable pieces of a failed migration that have already succeeded. Do not disable random parts of the script because they might have dependancies on prior steps.
#
# Variables
tfsupport_pwd="T3l3fl0r4#"
old_server_ip="192.168.1.21"
new_server_ip="192.168.1.22"
PID="$$"
CONSOLEDISPLAY=1
EMAILRESULTS="vmarkum@teleflora.com mgreen@teleflora.com kpugh@teleflora.com sjackson@teleflora.com tnapier@teleflora.com jmonazym@teleflora.com"
LOG="/tmp/daisy-mig.log.$PID"
# Migration Steps
APPLY_PATCH_FILES="/tmp/FMA12FD_ALL.patch"
ELAVON_PATCH="/tmp/Daisy_ElavonConversion.patch"
BACKUP_PRINTERS=1
COPY_DAISY=1
BACKUP_NEW_DAISY=1
INSTALL_DAISY=1
INSTALL_PRINTERS=1
INSTALL_PATCHES=0
MIGRATE_DAISY_DATA=1
CHANGE_IP=1
FIX_PRINTING=0
EMAIL_RESULTS=1
CP_FLORDIR=1
INSTALL_EDIR=1
CP_EXPORTS=1
INSTALL_OSTOOLS=1

#DO NOT EDIT BELOW THIS LINE
log(){
        [ $CONSOLEDISPLAY == 1 ] && echo "$@"
        echo "`date`--$@" >> $LOG
}

# log message and stop script
die(){
        [ $CONSOLEDISPLAY == 1 ] && echo "Failed error code--$@"
        exit 99
}

# Validate initial conditions 
init_script(){
>$LOG
log "Beginning migration...."
ID=`/usr/bin/id -u`
        [ $ID -ne 0 ]  && echo "You must sudo to run $0." && die 2.1
if [ -d /tmp/d ]; then
	COPY_DAISY=0	
	CHANGE_IP=0
	BACKUP_PRINTERS=0
	LOCAL_INSTALL=1
	[ ! -x /usr/bin/expect ] && log "Installing expect...." && yum -y install expect 1>>$LOG 2>&1
	[ ! -x /usr/bin/expect ] && log "Could not install expect. Check to make sure server is registered with redhat." && die 2.4
	log "Initial Validation Complete...."
	log "Migrating from /tmp/d...."
	return
else
ping -c 1 $old_server_ip 1>>$LOG 2>&1
fi
if [ $? -eq 0 ]; then
        log "Old server there...."
else
        log "Old server down...."
        die 2.2
fi
ping -c 1 google.com 1>>$LOG 2>&1
if [ $? -eq 0 ]; then
        log "Internet there...."
else
        log "No internet connection...."
        die 2.3
fi
[ ! -x /usr/bin/expect ] && log "Installing expect...." && yum -y install expect 1>>$LOG 2>&1
[ ! -x /usr/bin/expect ] && log "Could not install expect. Check to make sure server is registered with redhat." && die 2.4
log "Initial Validation Complete...."
}

# Backup printers
backup_printers(){
log "Backing up printers on $old_server_ip...."
expect -c "set timeout 5;\
log_user 0;\
log_file -a $LOG;\
spawn ssh -tq -oStrictHostKeyChecking=no $old_server_ip -l tfsupport \"sudo cp /etc/cups/printers.conf /d/printers.conf; sudo cp /etc/hosts /d/hosts; sudo cp /etc/sysconfig/network /d/network\";\
match_max 100000;\
expect *password:*;\
send -- $tfsupport_pwd\r;\
expect *assword*;\
send -- $tfsupport_pwd\r;\
interact;"
[ $? -ne 0 ] && read -p "Failed at 3.1, continue y/n?" && [ "$REPLY" == "n" ] && die 3.1
log "Finished printers backup on $old_server_ip...."
}


# Copy Daisy and Printers from old server
copy_daisy(){
log "Copying Daisy from $old_server_ip...."
expect -c "set timeout 5;\
log_user 0;\
log_file -a $LOG;\
spawn ssh -t -oStrictHostKeyChecking=no $old_server_ip -l tfsupport \"sudo chmod -R 777 /d\";\
expect *password:*;\
send -- $tfsupport_pwd\r;\
expect *asswor*;\
send -- $tfsupport_pwd\r;\
interact;"
expect -c "set timeout 5;\
log_user 0;\
log_file -a $LOG;\
spawn scp -r -q -oStrictHostKeyChecking=no tfsupport@$old_server_ip:/d /tmp;\
match_max 100000;\
expect *password*;\
send -- $tfsupport_pwd\r;\
interact;"
[ $? -ne 0 ] && read -p "Failed at 4.1, continue y/n?" && [ "$REPLY" == "n" ] && die 4.1
log "Finished copying daisy from $old_server_ip...."
}


# Backup New Server daisy install
backup_new_daisy(){
log "Backing up current Daisy install...."
[ ! -d /d/stage ] && mkdir /d/stage 1>>$LOG 2>&1
cp -rf /d/daisy /d/stage/daisy.stage 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 5.1, continue y/n?" && [ "$REPLY" == "n" ] && die 5.1
rm -rf /d/daisy 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 5.2, continue y/n?" && [ "$REPLY" == "n" ] && die 5.2
log "Current Daisy install moved...."
}

cp_flordir(){
cp -rf /tmp/d/FLORDIR /d
[ $? -ne 0 ] && read -p "Failed at 5.3, continue y/n?" && [ "$REPLY" == "n" ] && die 5.3
mv -f /tmp/d/FLORDIR/applypatch.pl /tmp/d/FLORDIR/applypatch.pl.orig
[ $? -ne 0 ] && read -p "Failed at 5.4, continue y/n?" && [ "$REPLY" == "n" ] && die 5.4
}

# Download and mount Daisy rhel5 iso and run install script
install_daisy(){
log "Begin Daisy install...."
cd /tmp 1>>$LOG 2>&1
DAISY_ISO=`ls daisy*.iso | sort | tail -1`
[ ! -f /tmp/$DAISY_ISO ] && log "Daisy ISO not found...." && read -p "Failed at 6.2, continue y/n?" && [ "$REPLY" == "n" ] && die 6.2
log "Mounting iso...."
mount -o loop /tmp/$DAISY_ISO /mnt 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 6.3, continue y/n?" && [ "$REPLY" == "n" ] && die 6.3
log "Running Daisy install script...."
[ $? -ne 0 ] && read -p "Failed at 6.4, continue y/n?" && [ "$REPLY" == "n" ] && die 6.4
expect -c "set timeout 5;\
log_user 0;\
log_file -a $LOG;\
spawn /mnt/install-daisy.pl /d/daisy /tmp/d/daisy /mnt;\
expect *==>*;\
send -- B\r;\
expect *==>*;\
send -- YES\r;\
interact;"
[ $? -ne 0 ] && read -p "Failed at 6.5, continue y/n?" && [ "$REPLY" == "n" ] && die 6.5
umount /mnt 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 6.6, continue y/n?" && [ "$REPLY" == "n" ] && die 6.6
[ $LOCAL_INSTALL -eq 1 ] && log "Daisy install complete..." && return
cp -f /tmp/d/hosts /etc/hosts 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 6.7, continue y/n?" && [ "$REPLY" == "n" ] && die 6.7
cp -f /tmp/d/network /etc/sysconfig/network 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 6.8, continue y/n?" && [ "$REPLY" == "n" ] && die 6.8
hostname `grep HOSTNAME /etc/sysconfig/network | cut -d= -f2` 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 6.9, continue y/n?" && [ "$REPLY" == "n" ] && die 6.9
log "Daisy install complete...."
}

# Install printers from old server
install_printers(){
log "Migrating printers from old server...."
if [ $LOCAL_INSTALL -eq 1 ]; then
cp -f /tmp/etc/cups/printers.conf /etc/cups 1>>$LOG 2>&1
else
cp -f /tmp/d/printers.conf /etc/cups 1>>$LOG 2>&1
fi
service cups restart 1>>$LOG 2>&1
lpstat -v 1>>$LOG 2>&1
#[ $CONSOLEDISPLAY == 1 ] && lpstat -v
# why does it die with printers with console off?
[ $? -ne 0 ] && read -p "Failed at 7.1, continue y/n?" && [ "$REPLY" == "n" ] && die 7.1
log "Printers installed...."
}

# Copy pieces needed from old server Daisy install
migrate_daisy_data(){
log "Migrating files from old Daisy install...."
cp -rf /d/putty /d/stage/putty.stage 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.1, continue y/n?" && [ "$REPLY" == "n" ] && die 8.1
rm -rf /d/putty 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.2, continue y/n?" && [ "$REPLY" == "n" ] && die 8.2
cp -rf /tmp/d/putty /d 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.3, continue y/n?" && [ "$REPLY" == "n" ] && die 8.3
cp -rf /d/menus /d/stage/menus.stage 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.4, continue y/n?" && [ "$REPLY" == "n" ] && die 8.4
rm -rf /d/menus 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.5, continue y/n?" && [ "$REPLY" == "n" ] && die 8.5
cp -rf /tmp/d/menus /d 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.6, continue y/n?" && [ "$REPLY" == "n" ] && die 8.6
cp -f /d/stage/menus.stage/crawlmenu /d/menus 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.7, continue y/n?" && [ "$REPLY" == "n" ] && die 8.7
cp -rf /d/daisy/cubby /d/stage/cubby.stage 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.8, continue y/n?" && [ "$REPLY" == "n" ] && die 8.8
rm -rf /d/daisy/cubby 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.9, continue y/n?" && [ "$REPLY" == "n" ] && die 8.9
cp -rf /tmp/d/daisy/cubby /d/daisy 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.10, continue y/n?" && [ "$REPLY" == "n" ] && die 8.10
cp -rf /d/server /d/stage/server.stage 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.11, continue y/n?" && [ "$REPLY" == "n" ] && die 8.11
rm -rf /d/server 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.12, continue y/n?" && [ "$REPLY" == "n" ] && die 8.12
cp -rf /tmp/d/server /d/server 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.13, continue y/n?" && [ "$REPLY" == "n" ] && die 8.13
/d/daisy/bin/dsyperms.pl 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 8.14, continue y/n?" && [ "$REPLY" == "n" ] && die 8.14
log "Done migrating files...."
}

# Install applypatch.pl patches
install_patches(){
log "Installing applypatch.pl patches...."
[ ! -f /tmp/applypatch.pl ] && log "Apply patch script not found...." && read -p "Failed at 9.1, continue y/n?" && [ "$REPLY" == "n" ] && die 9.1
[ -f /d/daisy/elavctrl.pos ] && rm -f /d/daisy/elavctrl.pos
for patch in $APPLY_PATCH_FILES
do
[ -f $patch ] && sudo /tmp/applypatch.pl --norestart --log-stderror $patch 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 9.2, continue y/n?" && [ "$REPLY" == "n" ] && die 9.2
done
for patch in $ELAVON_PATCH
do
[ -f $patch ] && sudo /tmp/applypatch.pl --norestart --log-stderror --convert-to-elavon $patch 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 9.3, continue y/n?" && [ "$REPLY" == "n" ] && die 9.3
done
log "Done installing applypatch.pl patches...."
}

# Change New Server IP to 1.21
change_ip(){
log "Changing IP on new server...."
cp /etc/hosts /tmp/hosts.bak 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 10.1, continue y/n?" && [ "$REPLY" == "n" ] && die 10.1
cp /etc/sysconfig/network-scripts/ifcfg-eth0 /tmp/ifcfg-eth0.bak 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 10.2, continue y/n?" && [ "$REPLY" == "n" ] && die 10.2
sed -e "s/$new_server_ip/$old_server_ip/g" /tmp/hosts.bak >/etc/hosts
[ $? -ne 0 ] && read -p "Failed at 10.3, continue y/n?" && [ "$REPLY" == "n" ] && die 10.3
sed -e "s/$new_server_ip/$old_server_ip/g" /tmp/ifcfg-eth0.bak >/etc/sysconfig/network-scripts/ifcfg-eth0
[ $? -ne 0 ] && read -p "Failed at 10.4, continue y/n?" && [ "$REPLY" == "n" ] && die 10.4
log "IP changed to $old_server_ip...."
}

# Printing fix
fix_printing(){
cd /tmp
wget http://rtihardware.homelinux.com/support/dsy-lpr-fixup.pl 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 11.1, continue y/n?" && [ "$REPLY" == "n" ] && die 11.1
chmod +x /tmp/edir_installbase.pl 1>>$LOG 2>&1
log "Applying printing fix...."
[ ! -f /tmp/dsy-lpr-fixup.pl ] && log "Printing fix script not found...." && read -p "Failed at 11.2, continue y/n?" && [ "$REPLY" == "n" ] && die 11.2
/tmp/dsy-lpr-fixup.pl 1>>$LOG 2>&1
log "Printing fix complete...."
}

# Install EDIR
install_edir(){
log "Installing base edir....."
cd /tmp
rm -f /tmp/edir_installbase.pl
wget http://rtihardware.homelinux.com/daisy/edir_installbase.pl 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 12.1, continue y/n?" && [ "$REPLY" == "n" ] && die 12.1
chmod +x /tmp/edir_installbase.pl 1>>$LOG 2>&1
wget http://rtihardware.homelinux.com/daisy/edir_base_latest.tar.gz 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 12.2, continue y/n?" && [ "$REPLY" == "n" ] && die 12.2
/tmp/edir_installbase.pl /tmp/edir_base_latest.tar.gz 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 12.3, continue y/n?" && [ "$REPLY" == "n" ] && die 12.3
log "edir base installed....."
}

# Copy Exports folder
cp_exports(){
log "Copying exports folder contents...."
[ ! -d /tmp/d/daisy/export ] && log "Exports folder does not exist...." && read -p "Failed at 13.1, continue y/n?" && [ "$REPLY" == "n" ] && die 13.1
cp -rfp /tmp/d/daisy/export/* /d/daisy/export/. 1>>$LOG 2>&1
log "Done copying exports folder...."
}

# Install OSTools
install_ostools(){
log "Installing OSTools 1.15...."
cd /tmp
rm -f /tmp/ostools*.gz
wget http://rtihardware.homelinux.com/ostools/ostools-1.15-latest.tar.gz 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 14.1, continue y/n?" && [ "$REPLY" == "n" ] && die 14.1
tar xvfz ostools-1.15-latest.tar.gz 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 14.2, continue y/n?" && [ "$REPLY" == "n" ] && die 14.2
./bin/install-ostools.pl ./ostools-1.15-latest.tar.gz 1>>$LOG 2>&1
[ $? -ne 0 ] && read -p "Failed at 14.3, continue y/n?" && [ "$REPLY" == "n" ] && die 14.3
log "OSTools 1.15 installed....."
}

# Email Results
email_results(){
service sendmail restart 1>>$LOG 2>&1
for i in $EMAILRESULTS
do
[ $EMAIL_RESULTS -eq 1 ] && /bin/mail -s "Daisy Server upgrade complete @ $(hostname)" $i < $LOG
done
}

# Main
init_script
[ $BACKUP_PRINTERS -eq 1 ] && backup_printers
[ $COPY_DAISY -eq 1 ] && copy_daisy
[ $BACKUP_NEW_DAISY -eq 1 ] && backup_new_daisy
[ $CP_FLORDIR -eq 1 ] && cp_flordir
[ $INSTALL_DAISY -eq 1 ] && install_daisy
[ $INSTALL_PRINTERS -eq 1 ] && install_printers
[ $MIGRATE_DAISY_DATA -eq 1 ] && migrate_daisy_data
[ $INSTALL_PATCHES -eq 1 ] && install_patches
[ $CHANGE_IP -eq 1 ] && change_ip
[ $FIX_PRINTING -eq 1 ] && fix_printing
[ $INSTALL_EDIR -eq 1 ] && install_edir
[ $CP_EXPORTS -eq 1 ] && cp_exports
[ $INSTALL_OSTOOLS -eq 1 ] && install_ostools
cd /d/daisy/bin
/d/ostools/bin/dsyperms.pl 1>>$LOG 2>&1
[ $EMAIL_RESULTS -eq 1 ] && email_results
log "Daisy Migration complete...."
exit
