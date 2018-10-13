#!/bin/bash

ID=$(/usr/bin/id -u)
[ $ID -ne 0 ] && echo "You must be root to run $0." && exit 1
#
#--Daisy migration script written for Erik White. 10-12-2018
#a. Cleanup/Initialize.
umount /mnt/usb >>/dev/null 2>&1 1>/dev/null
rm -rf /mnt/usb >>/dev/null 2>&1 1>/dev/null
mkdir /mnt/usb >>/dev/null 2>&1 1>/dev/null

#b. Set drive list.
DRIVE_LIST="`ls /dev/sd[a-z]`"

#c. Get Shop Code.
echo -n "Enter Shopcode: "
read SHOPCODE
#
#1. Test for USB conversion stick and run the migration against result if found.
for DRIVE in $DRIVE_LIST 
	do
	echo "Testing $DRIVE.."
	udevadm info -a -n `basename $DRIVE` 2>/dev/null | grep Removable 2>&1 1>/dev/null
	if [ $? -eq 0 ];
	then
		echo "FOUND USB Conversion stick at $DRIVE."
		echo "Running migration for $SHOPCODE against $DRIVE...."
		mount ${DRIVE}1 /mnt/usb
		[ $? -ne 0 ] && echo "Could not mount conversion drive." && exit 1
		[ ! -d /mnt/usb/Conversion ] && echo "/d/conversion does not exist." && exit 1
		cd /d/conversion
		[ ! -f /mnt/usb/Conversion/$SHOPCODE_datafile.tgz ] && echo "No data file found." && exit 1
#2. Extracting datafile.tgz from conversion USB stick.
		tar xvfz /mnt/usb/Conversion/$SHOPCODE_datafile.tgz
		[ $? -ne 0 ] && echo "Extract of datafile failed." && exit 1
#3. Dumping florist notes.
		./notedump export/florist_notes.txt
#4. Copying florist notes back to USB stick.
		echo "Copying $SHOPCODE notes back to USB conversion stick."
		cp -f export/florist_notes.txt /mnt/usb/Conversion/$SHOPCODE_notes.txt
#5. Umount USB stick.
		umount /mnt/usb
		echo "Success!"
		exit 0
	fi
	done
echo "USB Conversion stick not found."
#-
exit 1
