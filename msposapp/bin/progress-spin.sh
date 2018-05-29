#!/bin/bash
$1 2>/var/log/rhel7-rti-build.log &
pid=$! # Process Id of the previous running command

spin[0]="-"
spin[1]="\\"
spin[2]="|"
spin[3]="/"

echo -n "[copying] ${spin[0]}"
while [ kill -0 $pid ]
do
  for i in "${spin[@]}"
  do
        echo -ne "\b$i"
        sleep 0.1
  done
done

