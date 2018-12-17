#!/bin/bash

# Must be root
ID=$(/usr/bin/id -u)
[ $ID -ne 0 ] && echo "You must be root to run $0." && exit 1
#
#--Daisy conversion script written for Erik Watson. 10-12-2018
#a. Cleanup/Initialize.
umount /mnt/usb >>/dev/null 2>&1 1>/dev/null
rm -rf /mnt/usb >>/dev/null 2>&1 1>/dev/null
mkdir /mnt/usb >>/dev/null 2>&1 1>/dev/null
[ ! -d /d/conversion ] && mkdir -p /d/conversion/export

#b. Set drive list.
DRIVE_LIST="`ls /dev/sd[a-z]`"

#c. Get Shop Code.
if [ "$1" != "" ];
	then
	SHOPCODE="$1"
else
	echo -n "Enter Shopcode: "
	read SHOPCODE
fi
#
for DRIVE in $DRIVE_LIST 
	do
#1. Test for USB stick and run the conversion against result if found.
	echo "Testing $DRIVE.."
	udevadm info -a -n `basename $DRIVE` 2>/dev/null | grep Transcend 2>&1 1>/dev/null
	if [ $? -eq 0 ];
	then
		echo "FOUND USB stick at $DRIVE."
		mount ${DRIVE}1 /mnt/usb
		[ $? -ne 0 ] && echo "Could not mount conversion drive." && exit 1
		[ ! -d /mnt/usb/Conversion ] && echo "Not a conversion drive. Remove $DRIVE and try again." && umount /mnt/usb && exit 1
		cd /d/conversion
		echo "Running conversion for $SHOPCODE against $DRIVE...."
		#[ ! -f /mnt/usb/Conversion/$SHOPCODE_datafile.tgz ] && echo "No data file found for ${SHOPCODE}." && exit 1
#2. Extracting datafile.tgz from conversion USB stick.
		tar xvfz /mnt/usb/Conversion/$SHOPCODE_datafile.tgz
		chmod 777 *.dsy
		chmod 777 *.pos
		[ $? -ne 0 ] && echo "Extract of datafile failed." && exit 1
#3. Dumping florist notes.
		./notedump export/$SHOPCODE_notes.txt
#4. Copying florist notes to USB stick.
		echo "Copying $SHOPCODE notes back to USB conversion stick."
$5. Run PLIST
		echo "Running PLIST."
		cd /d/conversion
		./plist
#6  Run CUSTPRO
		echo "Running CUSTPRO."
		cd /d/conversion
		./custpro
#7  Run MARKETPRO
		echo "Running MARKETPRO."
		cd /d/conversion
		./marketpr
#8  Make archive
		echo "Creating archive."
		cd /d/conversion
		tar cvfz $SHOPCODE_MIGRATED.tgz control.dsy plutable.pos export/*.txt
#9  Copy to USB stick.
		echo "Copying $SHOPCODE migration data back to USB conversion stick."
		cd /d/conversion
		cp -f $SHOPCODE_MIGRATED.tgz /mnt/usb/Conversion/$SHOPCODE_MIGRATED.tgz
#10. Umount USB stick.
		umount /mnt/usb
		echo "Conversion Complete. Remove USB stick."
		exit 0
	fi
	done
echo "USB Conversion drive not found."
#-
exit 1
