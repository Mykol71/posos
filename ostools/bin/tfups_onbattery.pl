#!/usr/bin/perl
#
# $Revision: 1.2 $
# Copyright 2015 Teleflora.
# 
# OSTools Version: 1.15.0
#
# tfups_onbattery.pl
#
# APC UPS "on battery" Script.
#
# Script to inform Teleflora POS users about being on battery backup
# (ie, power is out.)
#

use strict;
use warnings;


if (open(my $wall, '|-', "wall")) {
    print {$wall} "\n";
    print {$wall} "!!!!!!!!!!!!!!!!!!!!!!!\n";
    print {$wall} "!!!!! POWER OUTAGE !!!!\n";
    print {$wall} "!!!!!!!!!!!!!!!!!!!!!!!\n";
    print {$wall} "!!!!! Your Teleflora Server is running on Battery Backup.\n";
    print {$wall} "!!!!! Please make sure to finish and save any tasks.\n";
    print {$wall} "!!!!! DO NOT begin critical operations (such as credit cards)\n";
    print {$wall} "!!!!! until power is restored.\n";
    print {$wall} "!!!!!\n";
    print {$wall} "!!!!! Take measures to shut down your server now, before the\n";
    print {$wall} "!!!!! batteries are drained.\n";
    print {$wall} "!!!!!!!!!!!!!!!!!!!!!!!\n";
    print {$wall} "\n";
    print {$wall} "\n";
    print {$wall} "Press Control-L to refresh the screen.\n";
    print {$wall} "\n";
    close($wall);
}

# Magic return value needed by apccontrol.\n";
exit(99);

