#!/bin/sh

CMD='/usr2/ostools/bin/tfrsync.pl --version'
#CMD='/usr2/ostools/bin/tfrsync.pl --cloud --backup=printconfigs'
USR='tfsupport'
PSWD='Fl0wers'

for IP in $@
  do
    ./ssh_sudo.expect "$IP" "$USR" "$PSWD" "$CMD"
  done

exit 0
