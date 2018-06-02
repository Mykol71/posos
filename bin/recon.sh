#!/usr/bin/bash

SUBSCRIBERS=`find /backups -name paying_customer | wc -l`
TOTAL_ACCOUNTS=`ls /backups | grep tfrsync | wc -l`
USED_DISK_SPACE=`du -h /backups | tail -1 | cut -c1-5`
FREE_SPACE=`df -h /backups | tail -1 | awk '{print $3}'`
EMAIL_USER=mgreen@teleflora.com,kpugh@teleflora.com,sjackson@teleflora.com

echo "Free Space: $FREE_SPACE">/tmp/recon.txt
echo "Subscribers: $SUBSCRIBERS">>/tmp/recon.txt
echo "Total Accounts: $TOTAL_ACCOUNTS">>/tmp/recon.txt
echo "Used Disk Space: $USED_DISK_SPACE">>/tmp/recon.txt

mail -s "Cloud Recon" $EMAIL_USER </tmp/recon.txt
