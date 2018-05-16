#!/bin/bash

echo "SHOPCODE|START_DATE|BU_COUNT|BU_SUCCESS_COUNT|JAN_SUCCESS|JAN_FAIL|FEB_SUCCESS|FEB_FAIL|MAR_SUCCESS|MAR_FAIL|APR_SUCCESS|APR_FAIL|MAY_SUCCESS|MAY_FAIL|JUN_SUCCESS|JUN_FAIL|JUL_SUCCESS|JUL_FAIL|AUG_SUCCESS|AUG_FAIL|SEP_SUCCESS|SEP_FAIL|OCT_SUCCESS|OCT_FAIL|NOV_SUCCESS|NOV_FAIL|DEC_SUCCESS|DEC_FAIL">/tmp/TU_STATS_LINUX_Cloud_Backup_Detail.txt

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
   START_DATE=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | head -12 | grep 'BEGIN:' | sed -e 's/^ *//' | cut -d' ' -f2 | cut -d- -f1`
   BU_COUNT=`grep 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | wc -l`
   BU_SUCCESS_COUNT=`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | grep 'RESULT:' | grep -e 'Exit OK' -e '0' -e '99' | wc -l`

RECORD="$SHOPCODE|$START_DATE|$BU_COUNT|$BU_SUCCESS_COUNT"
year=`date +%Y`
months='01 02 03 04 05 06 07 08 09 10 11 12'
for month in $months
do
  monthname="`/usr/local/bin/monthname.sh $month`"
  RECORD="$RECORD|`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log |  grep -A 8 -B 3 "BEGIN: $year$month" | grep 'RESULT:' | grep -e 'Exit OK' -e '0' -e '99' | wc -l`|`grep -A 5 -B 6 'DEVICE: cloud' ${LOGPATH}/tfrsync-summary.log | grep -A 8 -B 3 "BEGIN: $year$month" | grep 'RESULT:' | grep -v -e 'Exit OK' -e '0' -e '99' | wc -l`"
done
echo "$RECORD">>/tmp/TU_STATS_LINUX_Cloud_Backup_Detail.txt

done
