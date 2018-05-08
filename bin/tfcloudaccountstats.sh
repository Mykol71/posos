#!/bin/bash

echo "SHOPCODE|BACKUP_DATE|BACKUP_BEGIN|BACKUP_END|TFRSYNC_RESULT|RSYNC_RESULT|RSYNC_WARN|RETRY_COUNT|DURATION|BU_SIZE|BACKUP_COMMAND|TFRSYNC_VERSION|POSTYPE|SIZE_ON_DISK|FAIL_COUNT_LAST_30|FAIL_COUNT_LAST_7|BU_COUNT|BU_SUCCESS_COUNT|SUBSCRIBER">/tmp/TU_STATS_LINUX_Cloud_Backups.txt

#for SHOPCODE in `ls /backups | grep -v tfrsync-36353700 | grep tfrsync | cut -d- -f2`
for SHOPCODE in `ls /backups | grep tfrsync | cut -d- -f2`
do
if [ -d /backups/tfrsync-$SHOPCODE/d ] ; then POSTYPE="Daisy"
LOGPATH="/backups/tfrsync-${SHOPCODE}/d/daisy/log"
else
POSTYPE="Unknown"
fi
if [ -d /backups/tfrsync-$SHOPCODE/usr2 ] ; then POSTYPE="RTI"
LOGPATH="/backups/tfrsync-${SHOPCODE}/usr2/bbx/log"
fi
if [ -f /backups/tfrsync-$SHOPCODE/paying_customer ] ; then SUBSCRIBER="Y"
else
SUBSCRIBER="N"
fi
BACKUP_DATE=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | tail -12 | grep BEGIN | sed -e 's/^ *//' | cut -d" " -f2 | cut -d- -f1`
BACKUP_BEGIN=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | tail -12 | grep BEGIN | sed -e 's/^ *//' | cut -d" " -f2 | cut -d- -f2`
BACKUP_END=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | tail -12 | grep END | sed -e 's/^ *//' | cut -d" " -f2 | cut -d- -f2`
DURATION=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | tail -12 | grep DURATION | sed -e 's/^ *//' | cut -d" " -f2`
TFRSYNC_RESULT=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | tail -12 | grep RESULT | sed -e 's/^ *//' | cut -d" " -f2-10`
if [[ "$TFRSYNC_RESULT" == "0" ]] ; then TFRSYNC_RESULT="Exit OK"
fi
if [[ "$TFRSYNC_RESULT" == "99" ]] ; then TFRSYNC_RESULT="Exit OK"
fi
RSYNC_RESULT=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | tail -12 | grep RSYNC | sed -e 's/^ *//' | cut -d" " -f2-10`
RETRY=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | tail -12 | grep RETRIES | sed -e 's/^ *//' | cut -d" " -f2-10`
BACKUP_COMMAND=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | tail -12 | grep COMMAND | sed -e 's/^ *//' | cut -d" " -f2-20`
TFRSYNC_VERSION=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | tail -12 | grep VERSION | sed -e 's/^ *//' | cut -d" " -f3`
RSYNC_WARN=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | tail -12 | grep WARNING | sed -e 's/^ *//' | cut -d" " -f2-5`
BU_SIZE=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | tail -12 | grep 'BYTES SENT' | sed -e 's/^ *//' | cut -d" " -f3`
BU_FAIL_COUNT_LAST_30=`grep -A 1 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | grep 'RESULT:' | tail -30 | grep -v 'RESULT: Exit OK' | grep -v 'RESULT: 0' | wc -l`
BU_FAIL_COUNT_LAST_7=`grep  -A 1 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | grep 'RESULT:' | tail -7 | grep -v 'RESULT: Exit OK' | grep -v 'RESULT: 0' | wc -l`
BU_COUNT=`grep 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | wc -l`
BU_SUCCESS_COUNT=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | grep -e 'RESULT: Exit OK' -e 'RESULT: 0' -e 'RESULT: 99' | wc -l`
SIZE_ON_DISK=`du -ch /backups/tfrsync-$SHOPCODE | tail -1 | cut -f1`
echo "$SHOPCODE|$BACKUP_DATE|$BACKUP_BEGIN|$BACKUP_END|$TFRSYNC_RESULT|$RSYNC_RESULT|$RSYNC_WARN|$RETRY|$DURATION|$BU_SIZE|$BACKUP_COMMAND|$TFRSYNC_VERSION|$POSTYPE|$SIZE_ON_DISK|$BU_FAIL_COUNT_LAST_30|$BU_FAIL_COUNT_LAST_7|$BU_COUNT|$BU_SUCCESS_COUNT|$SUBSCRIBER">>/tmp/TU_STATS_LINUX_Cloud_Backups.txt
done
