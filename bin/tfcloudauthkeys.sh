#!/bin/bash

echo "SHOPCODE|POSTYPE|CERTDATE|PUBLICKEY">/tmp/TU_STATS_LINUX_Cloud_Auth_Keys.txt

for SHOPCODE in `ls /backups | grep tfrsync | cut -d- -f2`
do
if [ -d /backups/tfrsync-$SHOPCODE/d ] ; then POSTYPE="Daisy"
else
POSTYPE="Unknown"
fi
if [ -d /backups/tfrsync-$SHOPCODE/usr2 ] ; then POSTYPE="RTI"
fi
AUTHPATH="/backups/tfrsync-${SHOPCODE}/home/tfrsync-${SHOPCODE}/.ssh"
CERTDATE=`ls -l --time-style=long-iso $AUTHPATH/id_rsa.pub | awk '{ print $6 }'`
PUBLICKEY=`cat $AUTHPATH/id_rsa.pub`

echo "$SHOPCODE|$POSTYPE|$CERTDATE|$PUBLICKEY">>/tmp/TU_STATS_LINUX_Cloud_Auth_Keys.txt
done

