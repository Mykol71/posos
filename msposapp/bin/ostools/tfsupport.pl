#!/usr/bin/perl
#
# $Revision: 1.205 $
# Copyright 2009-2015 Teleflora
#
# tfsupport.pl
#
# Script for all common remote Teleflora Customer Service activities.
#

use strict;
use warnings;
use POSIX;
use Getopt::Long;
use File::Spec;
use File::Basename;
use File::Temp qw/ tempdir /;
use Digest::MD5;

use lib qw( /teleflora/ostools/modules /d/ostools/modules /usr2/ostools/modules );
use OSTools::Platform;
use OSTools::Hardware;
use OSTools::AppEnv;
use OSTools::Filesys;


my $CVS_REVISION = '$Revision: 1.205 $';
my $CVS_REV_NR = $CVS_REVISION;
if ($CVS_REVISION =~ /(\$Revision)(: )(\d+\.\d+)( \$)/) {
	$CVS_REV_NR = $3;
}
my $PROGNAME = basename($0);

my $EMPTY_STR = q{};
my $POSDIR  = $EMPTY_STR;
my $POS_BINDIR  = $EMPTY_STR;
my $OSTOOLSDIR  = $EMPTY_STR;
my $OSTOOLS_BINDIR = $EMPTY_STR;

#
# global defines
#
my $TFSERVER_URL = 'http://rtihardware.homelinux.com/';
my $TFSERVER_DAISY_URL = $TFSERVER_URL . 'daisy/';
my $TFSERVER_OSTOOLS_URL = $TFSERVER_URL . 'ostools';

#
# ostools bin dir if a POS is not installed yet
#
my $NOPOS_BINDIR ="/teleflora/ostools/bin";

#
# global defines for RTI
#
my $DEF_RTI_ROOT_NAME          = 'usr2';
my $DEF_RTI_DIR_NAME           = 'bbx';
my $DEF_RTI_BINDIR_NAME        = 'bin';
my $DEF_RTI_LOGDIR_NAME        = 'log';

my $RTI_ROOT                   = File::Spec->catdir('/', $DEF_RTI_ROOT_NAME);
my $RTIDIR                     = File::Spec->catdir($RTI_ROOT, $DEF_RTI_DIR_NAME);
my $RTI_BINDIR                 = File::Spec->catdir($RTIDIR, $DEF_RTI_BINDIR_NAME);
my $RTI_LOGDIR                 = File::Spec->catdir($RTIDIR, $DEF_RTI_LOGDIR_NAME);

#
# global defines for Daisy
#
my $DEF_DAISY_ROOT_NAME        = 'd';
my $DEF_DAISY_DIR_NAME         = 'daisy';
my $DEF_DAISY_BINDIR_NAME      = 'bin';
my $DEF_DAISY_LOGDIR_NAME      = 'log';
my $DEF_DAISY_UPDATE_MNT_POINT = '/mnt/cdrom';

my $DAISY_ROOT                 = File::Spec->catdir('/', $DEF_DAISY_ROOT_NAME);
my $DAISYDIR                   = File::Spec->catdir($DAISY_ROOT, $DEF_DAISY_DIR_NAME);
my $DAISY_BINDIR               = File::Spec->catdir($DAISYDIR, $DEF_DAISY_BINDIR_NAME);
my $DAISY_LOGDIR               = File::Spec->catdir($DAISYDIR, $DEF_DAISY_LOGDIR_NAME);

#
# names of latest released per platform ISO files for Daisy.
# these are actually symlinks on the "rtihardware.homelinux.com" web site.
#
my $DAISY_LATEST_RHEL5_ISO = 'daisy_latest_rhel5.iso';
my $DAISY_LATEST_RHEL6_ISO = 'daisy_latest_rhel6.iso';
my $DAISY_LATEST_RHEL7_ISO = 'daisy_latest_rhel7.iso';

my $DAISY_TEST_RHEL5_ISO = 'daisy_test_rhel5.iso';
my $DAISY_TEST_RHEL6_ISO = 'daisy_test_rhel6.iso';
my $DAISY_TEST_RHEL7_ISO = 'daisy_test_rhel7.iso';

# names of latest Daisy florist directory packages
my $DEF_DAISY_FLORIST_DIRECTORY_PATCH = 'daisy-latest-altiris.tar';
my $DEF_DAISY_FLORIST_DIRECTORY_DELTA = 'edir_base_latest.tar.gz';
my $DEF_DAISY_TMPDIR = '/tmp';

# name of legacy backup script
my $BACKUP_SCRIPT_NAME = "rtibackup.pl";

# types of tfrsync.pl backups
my $DEVTYPE_CLOUD       = "cloud";
my $DEVTYPE_SERVER      = "server";
my $DEVTYPE_DEVICE      = "device";
my $DEVTYPE_LUKS        = "luks";
my $DEVTYPE_RTIBACKUP   = "rtibackup";
my $DEVTYPE_LTAR        = "ltar";

# cron job types used by tfrsync.pl
my $CRON_JOB_TYPE_CLOUD    = $DEVTYPE_CLOUD; 
my $CRON_JOB_TYPE_SERVER   = $DEVTYPE_SERVER;
my $CRON_JOB_TYPE_DEVICE   = $DEVTYPE_LUKS;
my $CRON_JOB_CLOUD_PATH    = "/etc/cron.d/tfrsync-cloud";
my $CRON_JOB_SERVER_PATH   = "/etc/cron.d/tfrsync-server";
my $CRON_JOB_DEVICE_PATH   = "/etc/cron.d/tfrsync-device";

# log file used by tfrsync.pl
my $DEF_TFRSYNC_CLOUD_LOGFILE    = 'tfrsync-cloud-Day_%d.log';
my $DEF_TFRSYNC_SERVER_LOGFILE   = 'tfrsync-server-Day_%d.log';
my $DEF_TFRSYNC_LUKSLOGFILE      = 'tfrsync-device-Day_%d.log';
my $DEF_TFRSYNC_SUMMARY_LOGFILE  = 'tfrsync-summary.log';

# log files used by florist directory scripts
my $DEF_DELTA_UPDATE_LOGFILE     = 'edir_update.log';
my $DEF_DELTA_SUMMARY_LOGFILE    = 'Delta_Stats.log';

# log file used to log errors in logging
my $ERROR_LOG = "$ENV{'HOME'}/tfsupport-errors.log";

# path to config file used in testing
my $TEST_CONFIG_FILE_PATH = $EMPTY_STR;

#
# command line options
#
my $VERSION = 0;
my $HELP = 0;


#
# Check whether running as root - not allowed since
# there may be ways to escape to a root shell - there
# is a least one that we know of and there may be more.
# It is very undesirable to allow a root shell.

if ($> == 0) {
    print "running $PROGNAME as root not allowed\n";
    exit(3);
}


# Handle signals.
# Mainly, prevent "breaking out" to a shell.
set_signal_handlers('IGNORE');

GetOptions(
	"version" => \$VERSION,
	"help" => \$HELP,
);


# --version
if($VERSION != 0) {
	print "OSTools Version:  1.15.0\n";
	print "$PROGNAME: $CVS_REVISION\n";
	exit(0);
}


# --help
if($HELP != 0) {
	print("Usage:\n");
	print("$PROGNAME\n");
	print("$PROGNAME --help\n");
	print("$PROGNAME --version\n");
	print("This script offers a system of menus for customer service to perform most\n");
	print("common tasks of an RTI/Daisy server. This script occasionally runs commands via \n");
	print("'sudo', thus, a member of the POS 'admins' should run the script.\n");
	print("\n");
	exit(0);
}


#
# what platform is this?
#
my $OS = plat_os_version();

#
# look for a point of sale footprint
#
$POSDIR = $ENV{'RTI_DIR'};
if (! defined($POSDIR)) {
    if (-d $RTIDIR) {
	$POSDIR = $RTIDIR;
    }
    if (-d $DAISYDIR) {
	$POSDIR = $DAISYDIR;
    }
}
if ($POSDIR) {
    $POS_BINDIR  = File::Spec->catdir($POSDIR, 'bin');
}
else {
    logerror("[main] proceeding without a POS installed\n");
}

if (-d "$RTIDIR/ostools") {
    $OSTOOLSDIR = "$RTIDIR/ostools";
}
elsif (-d "$DAISY_ROOT/ostools") {
    $OSTOOLSDIR = "$DAISY_ROOT/ostools";
}
elsif (-d '/teleflora/ostools') {
    $OSTOOLSDIR = '/teleflora/ostools';
}

if ($OSTOOLSDIR) {
    $OSTOOLS_BINDIR = File::Spec->catdir($OSTOOLSDIR, 'bin');
    logevent("[main] using ostools at location: $OSTOOLSDIR");
}
else {
    logerror("[main] could not happen: ostools is not installed");
}
    

#
# If TERM is unset, dump them to a shell.
#
unless (defined($ENV{'TERM'})) {
	print("The TERM environemnt variable is not defined - please fix.\n");
	print("\n");
	print("The Support Admin menus require TERM to be defined in order to run.\n");
	print("Please configure the environment to define TERM.  After TERM is defined,\n");
	print("the Support Admin menus may be reached by entering this command:\n");
	print("\texec $POSDIR/bin/tfsupport.pl\n");
	print("\n");
	print("execing the Bash Shell...\n");
	set_signal_handlers('DEFAULT');
	exec("/bin/bash");
}


#
# On platforms before RHEL6, "scoansi-old" emulation works for both
# the "dialog" and "sshbbx" applications.  However, for RHEL6, there is
# no definition for "scoansi-old" and current belief is that "linux" is
# the choice that works best.
#
if ($ENV{'TERM'} eq "ansi") {
    if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	$ENV{'TERM'} = "linux";
    }
    else {
	$ENV{'TERM'} = "scoansi-old";
    }
}

my $TIMEOUT_MENU_ARG = " --timeout 900";

my $title = "";
my $command = "";
my $returnval =  "";
logevent("Starting Support Menu");
while(1) {

	# Summary information about this shop.
	$title = titlestring("Support Menu");
	$title .= "OSTools Package Version: 1.15.0\\n";
	$title .= "  Support Menus Version: $CVS_REV_NR\\n";
	$title .= "      Linux Platform ID: $OS\\n";
	$title .= "          " . get_pos_version();
	$title .= "\\n";
	$title .= "\\n";

	$command = "dialog --stdout";
	$command .= " $TIMEOUT_MENU_ARG";
	$command .= " --no-cancel";
	$command .= " --default-item \"Exit\"";
	$command .= " --menu '$title'";
	$command .= " 0 0 0";

	if(-d "/usr2/bbx") {
		$command .= " \"RTI\"" . " \"RTI Application\"";
	}
	if(-d "/d/daisy") {
		$command .= " \"Daisy\"" . " \"Daisy Application\"";
	}

	# $command .= " \"TCC\"" . " \"TCC Logs\"";
	$command .= " \"Users\"" . " \"Linux Users\"";
	$command .= " \"Printers\"" . " \"Printers\"";
	$command .= " \"Network\"" . " \"Network Connectivity\"";
	$command .= " \"Backups\"" . " \"System and Data Backup Tools\"";
	$command .= " \"Hardware\"" . " \"Hardware Related Items\"";
	$command .= " \"Linux\"" . " \"Linux and Operating System\"";
	if (is_admin_user() != 0) {
	    $command .= " \"Commandline\"" . " \"Go to the Linux Shell\"";
	}

	$command .= " \"Exit\"" . " \"Exit\"";

	# Redirect stderr to stdout so that we can tell if there was a timeout
	# since 'dialog' writes "timeout" to stderr and exits if a timeout happens.
	$returnval = qx($command 2>&1);

	# Remove trailing and leading newlines because if there was a timeout,
	# the form of the output is:
	#	^\ntimeout\n$
	chomp($returnval);
	$returnval =~ s/^\n//;

	next if (!$returnval);

	if($returnval eq "timeout") {
		logevent("Inactivity Timeout");
		exit(0);
	}

	# Backups.
       	elsif ($returnval eq "Backups") {
	    backup_main();
	}
       
	# Dove
	elsif($returnval eq "Dove") {
		dove_menu();

	} elsif($returnval eq "Network") {
		network_main();

	} elsif($returnval eq "Linux") {
		linux_main();

	} elsif($returnval eq "ODBC") {
		odbc_menu();

	} elsif($returnval eq "Printers") {
		printers_main();

	} elsif($returnval eq "RTI") {
		rti_menu();

	} elsif($returnval eq "Daisy") {
		daisy_menu();

	} elsif($returnval eq "TCC") {
		tcc_logs_menu();

	} elsif($returnval eq "Hardware") {
		hardware_main();

	} elsif($returnval eq "Users") {
		users_main();

	} elsif($returnval eq "Commandline") {
		system("/usr/bin/clear");
		logevent("Begin Shellout to Commandline.");

		set_signal_handlers('DEFAULT');
		system("PS1=\"\[\\u\@\\h\ \\W]\$ \" /bin/bash");
		set_signal_handlers('IGNORE');

		logevent("Finish Shellout to Commandline.");

	} elsif($returnval eq "Exit") {
		$returnval = menu_confirm("Exit Support Menu?", "No");
		if($returnval eq "Y") {
			logevent("Finish Support Menu.");
			exit(0);
		}

	} else {
		logevent("tfsupport.pl main loop: unknown return value from dialog: $returnval");
		logevent("TERM environment var: $ENV{'TERM'}");
		exit(2);
	}
}

exit(0);

###############################################################################
###############################################################################
###############################################################################


sub hardware_main
{
	my $title = "Hardware Menu";
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $user = "";

	while(1) {
		$title = titlestring("Hardware Menu");

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";
		$command .= " \"Hardware List\"" . " \"Server Hardware Information\"";
		$command .= " \"Disk\"" . " \"Disk Usage Statistics\"";
		$command .= " \"Battery Backup\"" . " \"Battery Backup Info\"";
		if(-f "/etc/init.d/dgrp_daemon") {
			$command .= " \"Restart Digi\"" . " \"Restart Digi Services.\"";
		}
		$command .= " \"Advanced\"" . " \"Advanced Tools.\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";


		open(USERDIALOG, "$command |");
		$returnval = <USERDIALOG>;
		close(USERDIALOG);
		next if(! $returnval);
		chomp($returnval);


		if($returnval eq "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);
		


		} elsif($returnval eq "Restart Digi") {
			system("/usr/bin/clear");
			system("sudo /sbin/service dgrp_daemon restart ; sudo /sbin/service dgrp_ditty restart ; sudo /sbin/init q");
			wait_for_user();

		} elsif($returnval eq "Disk") {
			system("/usr/bin/clear");
			system("df -h");
			print("\n\n");
			system("df -ih");
			wait_for_user();


		} elsif($returnval eq "Battery Backup") {
			hardware_battery_backup();


		} elsif($returnval eq "Hardware List") {
			$command = "sudo /usr/sbin/dmidecode | grep -A 5 \"System Information\"";
			$command .= " ; sudo /usr/sbin/dmidecode | grep -A 4 \"BIOS Information\"";
			$command .= " ; /bin/echo ; /bin/echo";
			$command .= " ; cat /etc/redhat-release";
			$command .= " ; uname --kernel-release --processor";
			$command .= " ; /bin/echo ; /bin/echo";
			$command .= " ; cat /proc/meminfo";
			$command .= " ; /bin/echo ; /bin/echo";
			$command .= " ; cat /proc/cpuinfo";
			if ($OS eq 'RHEL5') {
				$command .= " ; /bin/echo ; /bin/echo";
				$command .= " ; /sbin/lsusb";
			}
			elsif ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
				$command .= " ; /bin/echo ; /bin/echo";
				$command .= " ; /usr/bin/lsusb";
			}
			$command .= " ; /bin/echo ; /bin/echo";
			$command .= " ; /sbin/lspci";
			$command .= " ; /bin/echo ; /bin/echo";
			$command .= " ; /sbin/lsmod";
			$command .= " ; /bin/echo ; /bin/echo";
			$command .= " ; cat /proc/interrupts";
			system("($command) | less");


		} elsif($returnval eq "Advanced") {
			hardware_advanced();

		#  Exit
		} elsif($returnval eq "Close") {
			return(0);
	
		}
	}

	return(1);
}

sub hardware_advanced
{
	my $title = "Hardware Advanced Menu";
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $user = "";

	while(1) {
		$title = titlestring("Hardware Advanced Menu");

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";
		if (-f '/etc/apcupsd/apcupsd.conf') {
			$command .= " \"Battery Backup Config\"" . " \"Edit Battery Backup Conf File\"";
		}
		$command .= " \"Eject Devices\"" . " \"Eject Removable Media\"";
		if(-f "/etc/dgap/dgapview") {
			$command .= " \"Digi DGapview\"" . " \"Run Digi Utility\"";
		}
		if(-f "/usr/bin/mpi") {
			$command .= " \"Digi MPI\"" . " \"Run Digi Control Software\"";
		}
		if(-f "/usr/bin/minicom && -f /etc/minirc.dfl") {
			$command .= " \"Minicom\"" . " \"Run Modem Terminal Program\"";
		}
		$command .= " \"Close\"" . " \"Close This Menu\"";


		open(USERDIALOG, "$command |");
		$returnval = <USERDIALOG>;
		close(USERDIALOG);
		next if(! $returnval);
		chomp($returnval);

		if($returnval eq "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);
		

		} elsif($returnval eq "Battery Backup Config") {
			system("sudo rvim /etc/apcupsd/apcupsd.conf");

		} elsif($returnval eq "Eject Devices") {
			if(-f "$POSDIR/bin/rtibackup.pl") {
				system("sudo $POSDIR/bin/rtibackup.pl --eject");
			}
			system("eject /dev/scd0");
			system("eject /dev/scd1");
			wait_for_user();

		} elsif($returnval eq "Digi MPI") {
			system("sudo /usr/bin/mpi");

		} elsif($returnval eq "Digi DGapview") {
			system("sudo /etc/dgap/dgapview");

		} elsif($returnval eq "Minicom") {
			system("/usr/bin/minicom");

		} elsif($returnval eq "Close") {
			return(0);
	
		}
	}

	return(1);
}


sub hardware_battery_backup
{
	my $apcupsd_service = 'apcupsd';
	my $apcstatus_cmd = '/sbin/apcaccess';

	system("/usr/bin/clear");

	# assume the the service is installed if config directory exists
	unless (-d "/etc/apcupsd") {
		print("Warning: the $apcupsd_service system service is not installed.\n");
		logevent("[hardware batt backup] system service not installed: $apcupsd_service");
		wait_for_user();
		return(0);;
	}

	# is the service running?
	my $is_running = get_system_service_status($apcupsd_service);
	unless ($is_running) {
		print("Warning: the $apcupsd_service system service is not running.\n");
		print("The UPS signal cable, either USB or Serial, must be connected or\n");
		print("the $apcupsd_service system service will not run.\n");
		logevent("[hardware batt backup] system service not running: $apcupsd_service");
		wait_for_user();
		return(0);;
	}

	unless (-f $apcstatus_cmd) {
		print("Warning: can't find $apcupsd_service status command: $apcstatus_cmd\n");
		logevent("[hardware batt backup] file not found: $apcstatus_cmd");
		wait_for_user();
		return(0);;
	}

	print("---[ $apcupsd_service System Service Summary ]---\n");
	if (open(my $pipefh, '-|', "sudo $apcstatus_cmd")) {
	    while (<$pipefh>) {
		if ( /HOSTNAME :/ ||
		     /CABLE    :/ ||
		     /MODEL    :/ ||
		     /STATUS   :/ ||
		     /LOADPCT  :/ ||
		     /BCHARGE  :/ ||
		     /TIMELEFT :/ ||
		     /MBATTCHG :/ ||
		     /MINTIMEL :/ ||
		     /MAXTIME  :/ ||
		     /ITEMP    :/ ||
		     /BATTV    :/ ||
		     /SERIALNO :/ ||
		     /BATTDATE :/ ||
		     /FIRMWARE :/ ||
		     /APCMODEL :/ ) {
			print("$_");
			next;
		}
	    }
	    close($pipefh);
	    print("\n");
	}
	else {
	    print("Warning: can't find $apcupsd_service status command: $apcstatus_cmd\n");
	    logevent("[hardware batt backup] file not found: $apcstatus_cmd");
	}
	wait_for_user();

	if (-f '/sbin/lsusb') {
		print("---[ List of USB devices ]---\n");
		system("sudo /sbin/lsusb | less");
		print("\n");
		wait_for_user();
	}

	print("---[ $apcupsd_service System Service Details ]---\n");
	system("sudo $apcstatus_cmd | less");

	return(1);
}


sub advanced_truncate_root_mbox
{
	my $path = "/var/spool/mail/root";
	my $maxsize = 250000;
        my $root_mbox_size;

	if (-e $path) {
		$root_mbox_size = -s $path;
		if ($root_mbox_size > $maxsize) {
			print("Sizeof $path ($root_mbox_size) > limit ($maxsize)... removing\n");
			system("sudo rm -f $path");
			system("sudo touch $path");
			print("$path truncated\n");
		} else {
			print("Sizeof $path ($root_mbox_size) <= limit ($maxsize)... keeping\n");
		}
	} else {
		print("$path: file not found\n");
	}
}

sub users_unlock
{
    my $user = $_[0];

    print("Unlocking access to account: $user");

    system "sudo /usr/bin/passwd -u $user";
    if (-f "/sbin/pam_tally2") {
	system "sudo /sbin/pam_tally2 --reset --user $user";
    }
    else {
        system "sudo /usr/bin/faillog -u $user -r";
    }
}

sub users_remove_from_group
{
    my $delgroup= $_[0];
    my $username = $_[1];
    my @array = ();
    my $line = "";

    # Get a list of current groups.
    open(PIPE, "groups $username |");
    $line = <PIPE>;
    close(PIPE);

    # "root : root foo bar fee\n" -> "root : root foo bar fee"
    chomp($line);

    # "root : root foo bar fee" -> "root foo bar fee"
    $line =~ s/^([[:print:]]+)(:)(\s+)//g;

    # "root foo bar fee" -> "root bar fee"
    $line =~ s/(\s+)($delgroup)//g;

    # "root bar fee" -> "root,bar,fee"
    $line =~ s/\s+/,/g;

    system("sudo /usr/sbin/usermod -G \"$line\" $username");
}

sub users_disable_admin
{
    my $user = $_[0];
    my %userinfo = get_userinfo($user);
    my $admin_type = "rtiadmins";

    if (-d "/d/daisy") {
	$admin_type = "dsyadmins";
    }

    if (%userinfo) {
	if (grep(/$admin_type/, @{$userinfo{'groups'}})) {
	    users_remove_from_group($admin_type, $user);
	    print("Admin privileges removed for account $user.\n");
	}
	else {
	    print("Account \"$user\" is not an admin.\n");
	}
    }
    else {
	print("Account \"$user\" not found.\n");
    }
}

sub users_info
{
    my $user = $_[0];
    my %userinfo = get_userinfo($user);

    print "User Info\n";
    print "=========\n";
    print "   User: $user\n";
    print "   Home: $userinfo{'homedir'}\n";
    print " Groups: @{$userinfo{'groups'}}\n";
    print "\n";

    # Password expiration times.
    print "Password Expiration Info\n";
    print "========================\n";
    system("sudo chage -l $user");
    print "\n";

    #
    # Is user unlocked?  Note use of either pam_tally2 or faillog.
    # If pam_tally2 is present on the system, then harden_linux.pl
    # would have chosen it for /etc/pam.d/system-auth and thus the
    # corresponding program must be chosen here.
    #
    print "Login Failure Info\n";
    print "==================\n";
    if (-f "/sbin/pam_tally2") {
	system("sudo /sbin/pam_tally2 --user $user");
    }
    else {
	system("sudo /usr/bin/faillog -u $user");
    }

}

sub users_password_gen
{
	my $pwdocument = "";
	my $alphanumeric_only = 0;
	my $pw_min_size = 8;
	my $pw_sample_size = 7;
	my $i;
	my $j;

	my $openssl_cmd = '/usr/bin/openssl';
	my $strings_cmd = '/usr/bin/strings';

	# Can not proceed without basic utilities
	unless (-f $openssl_cmd && -f $strings_cmd) {

		$pwdocument = "Error: can't generate passwords";

		unless (-f $openssl_cmd) {
			$pwdocument .= "\n";
			$pwdocument .= "Required utility not found: $openssl_cmd";
		}
		unless (-f $strings_cmd) {
			$pwdocument .= "\n";
			$pwdocument .= "Required utility not found: $strings_cmd";
			$pwdocument .= "\n";
		}
		return($pwdocument);

	}

	#
	# Generate more than three passwords to choose from.
	#
	$pwdocument = "";
	$pwdocument .= "- - - === === === === PASSWORD  GENERATOR  RESULTS === === === === - - -\n";
	$pwdocument .= "\n";
	$pwdocument .= "Generated on: " . strftime("%Y-%m-%d %H:%M:%S", localtime()) . "\n";
	$pwdocument .= "Generated by: $ENV{'USER'}\n";
	$pwdocument .= "\n";
	$pwdocument .= "\n";

	my $pw_found_count = 0;

	for ($i = 0; $i < 15; $i++) {
		my $pwbuf = "";
		my $thispw = "";

		open(PIPE, "openssl rand 512 | /usr/bin/strings |");
		while(<PIPE>) {
			chomp;
			$pwbuf .= $_;
		}
		close(PIPE);

		$pwbuf =~ s/\s+//g; # Strip whitespace.
		$pwbuf =~ s/[^[:print:]]+//g; # Strip non-printable chars
		$pwbuf =~ s/[()`{}<>|~,'"\\[\]]//g; # Strip inconvenient chars
		if ($alphanumeric_only) {
			$pwbuf =~ s/[^[:alnum:]]+//g; # Strip non-alphanumeric chars
		}

		my $pwbuf_size = length($pwbuf);

		for ($j=0; $j < $pwbuf_size; $j += $pw_min_size) {
			$thispw = substr($pwbuf, $j, $pw_min_size);  #PCI 8.5.10
			next if ($thispw !~ /[0-9]/); # PCI 8.5.11
			next if ($thispw !~ /[a-z]/); # PCI 8.5.11
			next if ($thispw !~ /[A-Z]/); # PCI 8.5.11
			next if (length($thispw) < $pw_min_size);
			$pwdocument .= "$thispw\n";
			$pwdocument .= "\n";
			$pwdocument .= "\n";
			$pw_found_count++;
			last if ($pw_found_count >= $pw_sample_size);
		}
		last if ($pw_found_count >= $pw_sample_size);
	}

	# Print results to the screen.
	return($pwdocument);
}

sub users_main
{
	my $title = "User Menu";
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $user = "";
	my $userscript = "$POSDIR/bin/";


	# Select the appropriate user management script.
	if ($POSDIR eq $RTIDIR) {
	    $userscript .= 'rtiuser.pl';
	}
	elsif ($POSDIR eq $DAISYDIR) {
	    $userscript .= 'dsyuser.pl';
	}
	else {
	    $userscript = '';
	}
	unless (-f $userscript) {
	    print("POS user management script does not exist: $userscript");
	    print("Only a limited subset of options in the User menu will be available");
	    wait_for_user();
	}

	while(1) {
		$title = titlestring("User Menu");

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";
		if("$userscript" ne "") {
			$command .= " \"Add User\"" . " \"Add User\"";
			$command .= " \"Enable Admin\"" . " \"Set User as Administrator\"";
			$command .= " \"Disable Admin\"" . " \"Remove Administrative Privileges\"";
			$command .= " \"Remove\"" . " \"Remove User\"";
			$command .= " \"Info\"" . " \"Get User Info\"";
			$command .= " \"List\"" . " \"List all users.\"";
			$command .= " \"Who\"" . " \"Who is currently Logged In?\"";
			$command .= " \"ResetPW\"" . " \"Reset Password\"";
			$command .= " \"Unlock\"" . " \"Unlock Account\"";
			$command .= " \"Password Generator\"" . " \"Suggest New Passwords\"";
		}
		$command .= " \"Advanced\"" . " \"Advanced Tools.\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(USERDIALOG, "$command |");
		$returnval = <USERDIALOG>;
		close(USERDIALOG);
		next if(! $returnval);
		chomp($returnval);


		if($returnval eq "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);
		}

		elsif($returnval eq "Add User") {
		    $user = menu_getstring("Enter a name for the new account");
		    if ($user ne "") {
			system("sudo $userscript --info $user > /dev/null 2> /dev/null");
			if ($? == 0) {
			    menu_info("An account named $user already exists.\n");
			}
			else {
			    $suboption = menu_confirm("Add new account named $user?");
			    if ($suboption eq "Y") {
				system("sudo $userscript --add $user");
				wait_for_user();

				$suboption = menu_confirm("Set password for account $user?");
				if ($suboption eq "Y") {
				    system("sudo $userscript --resetpw $user");
				    wait_for_user();
				}
			    }
			}
		    }
		}

		elsif ($returnval eq "Password Generator") {
			$returnval = users_password_gen();

			system("/usr/bin/clear");
			print("$returnval");
			wait_for_user();

			if ($returnval !~ /^Error/) {
			    $suboption = choose_printer("Select printer for password list output");
			    if ($suboption ne "") {
				my $cmd = "$POSDIR/bin/tfprinter.pl";
				if (-f $cmd) {
				    print("Sending password list to $suboption\n");
				    if (open(my $pipe, '|-', "$cmd --print \"$suboption\"")) {
					print {$pipe} "$returnval";
					close($pipe);
					wait_for_user();
				    }
				    else {
					print("could not print password list to: $suboption");
					wait_for_user();
				    }
				}
				else {
				    print("ostools package not installed");
				    wait_for_user();
				}
			    }
			}
		}

		elsif($returnval eq "Enable Admin") {
			$user = users_menu_choose("Enable Administrative Privileges");
			if($user ne "") {
				if( ($user eq "daisy") 
				||  ($user eq "rti") ) {
					menu_info("Will not enable admin for \"$user\".\n");
				} else {
					system("/usr/bin/clear");
					system("sudo $userscript --enable-admin $user 2>&1");
					wait_for_user();
				}
			}
		}

		elsif($returnval eq "Disable Admin") {
			$user = users_menu_choose("Disable Administrative Privileges");
			if ($user ne "") {
				if ( ("$user" eq "tfsupport") || ("$user" eq "root") ) {
					menu_info("Will not disable admin for \"$user\"");
				} else {
					system("/usr/bin/clear");
					users_disable_admin($user);
					wait_for_user();
				}
			}
		}

		elsif($returnval eq "Info") {
			$user = users_menu_choose("Get User Information");
			if ($user ne "") {
				system("/usr/bin/clear");
				users_info($user);
				wait_for_user();
			}
		}

		elsif($returnval eq "List") {
			system("/usr/bin/clear");
			system("sudo $userscript --list 2>&1 | less");
		}

		elsif($returnval eq "Who") {
			system("/usr/bin/clear");
			system("who | less");
		}

		# Change Password
		elsif($returnval eq "ResetPW") {
			$user = users_menu_choose("Which User to Reset Password?");
			if($user ne "") {
				$suboption = menu_confirm("Reset Password for '$user'?");
				if($suboption eq "Y") {
					system("/usr/bin/clear");
					system("sudo $userscript --resetpw $user");
					wait_for_user();
				}
			}
		}

		elsif($returnval eq "Unlock") {
			$user = users_menu_choose("Which User to Unlock?");
			if($user ne "") {
				system("/usr/bin/clear");
				users_unlock($user);
				wait_for_user();
			}
		}

		# Remove User
		elsif($returnval eq "Remove") {
			$user = users_menu_choose("Which User to Remove?");
			if($user ne "") {
				$suboption = menu_confirm("Remove User \"$user\"?");
				if($suboption eq "Y") {
					system("/usr/bin/clear");
					system("sudo $userscript --remove $user 2>&1");
					wait_for_user();
				}
			}
		}

		elsif($returnval eq "Advanced") {
		# Advanced Menu
			users_advanced();
		}

		#  Exit
		elsif($returnval eq "Close") {
			return;
		}
	}

	return;
}

sub users_advanced
{
	my $title = "User (Advanced) Menu";
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $user = "";
	my $userscript = "";


	# Which user management script are we using?
	foreach("$POSDIR/bin/rtiuser.pl", "$POSDIR/bin/dsyuser.pl") {
		next until -f $_;
		$userscript = $_;
		last;
	}


	while(1) {
		$title = titlestring("User Advanced Menu");

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";
		if("$userscript" ne "") {
			$command .= " \"Login\"" . " \"Login as a different user.\"";
		}
		$command .= " \"Login History\"" . " \"Show History of a User's Logins.\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(USERDIALOG, "$command |");
		$returnval = <USERDIALOG>;
		close(USERDIALOG);
		next if(! $returnval);
		chomp($returnval);


		if($returnval eq "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);
			

		} elsif($returnval eq "Login") {
			$user = users_menu_choose("Login as Which User?");
			if("$user" ne "") {
				system("/usr/bin/clear");

				# On RTI systems, set the TERM env var
				my $env_var = (-d '/usr2/bbx') ? 'TERM=T375' : "";
				system("$env_var ssh $user\@localhost");
			}

		} elsif($returnval eq "Login History") {
			$user = users_menu_choose("Which User to see Login History?");
			if("$user" ne "") {
				system("/usr/bin/clear");
				system("/usr/bin/last -a \"$user\" | less");
			}


		#  Exit
		} elsif($returnval eq "Close") {
			return(0);
		}
	}
}


#
# verify if rtibackup.pl is enabled.
#
# let the rtibackup.pl script do the work.
#
# returns
#   1 if enabled
#   0 if disabled
#
sub backup_is_rtibackup_enabled
{
    my $rc = 0;

    my $cmd = "$POS_BINDIR/rtibackup.pl";
    if (-f $cmd) {
	$rc = system("sudo $cmd --report-is-backup-enabled");
	$rc = ($rc == 0) ? 1 : 0;
    }

    return($rc);
}


sub backup_is_luks_enabled
{
    my $rc = 0;

    if (-f "$POSDIR/bin/tfrsync.pl") {
	if (-f $CRON_JOB_DEVICE_PATH) {
	    if (open(my $cron, '<', $CRON_JOB_DEVICE_PATH)) {
		while (my $line=<$cron>) {
		    if ($line =~ m/^(\d|\*).+tfrsync.pl --luks/) {
			$rc = 1;
		    }
		}
		close($cron);
	    }
	    else {
		logerror("[backup_is_luks_enabled] could not open cron file: $CRON_JOB_DEVICE_PATH");
	    }
	}
    }

    return($rc);
}


sub backup_is_cloud_backup_enabled
{
    my $rc = 0;

    if (-f "$POSDIR/bin/tfrsync.pl") {
	if (-f $CRON_JOB_CLOUD_PATH) {
	    if (open(my $cron, '<', $CRON_JOB_CLOUD_PATH)) {
		while (my $line=<$cron>) {
		    if ($line =~ m/^(\d|\*).+tfrsync.pl --cloud/) {
			$rc = 1;
		    }
		}
		close($cron);
	    }
	    else {
		logerror("[backup_is_cloud_backup_enabled] could not open cron file: $CRON_JOB_CLOUD_PATH");
	    }
	}
    }

    return($rc);
}


sub backup_is_server_backup_enabled
{
    my $rc = 0;

    if (-f "$POSDIR/bin/tfrsync.pl") {
	if (-f $CRON_JOB_SERVER_PATH) {
	    if (open(my $cron, '<', $CRON_JOB_SERVER_PATH)) {
		while (my $line=<$cron>) {
		    if ($line =~ m/^(\d|\*).+tfrsync.pl --server/) {
			$rc = 1;
		    }
		}
		close($cron);
	    }
	    else {
		logerror("[backup_is_server_backup_enabled] could not open cron file: $CRON_JOB_SERVER_PATH");
	    }
	}
    }

    return($rc);
}


sub backup_main
{
    my $menu_title = '[[ Backup Menu ]]';

    my @backup_rtibackup_item = (
	"Legacy Backup",
	"System and Data Backup to Local Storage Device",
	\&backup_rtibackup_main,
	$DEVTYPE_DEVICE,
    );
    my @backup_device_item = (
	"Device Backup",
	"System and Data Backup to Local Storage Device",
	\&backup_device_main,
	$DEVTYPE_LUKS,
    );
    my @backup_cloud_item = (
	"Cloud Backup",
	"System and Data Backup to Remote Cloud Server",
	\&backup_cloud_main,
	$DEVTYPE_CLOUD,
    );
    my @backup_server_item = (
	"Server Backup",
	"System and Data Backup to Secondary Server",
	\&backup_server_main,
	$DEVTYPE_SERVER,
    );

    my @menu_items = ();

    if (backup_is_rtibackup_enabled()) {
	push(@menu_items, \@backup_rtibackup_item);
    }
    if (backup_is_luks_enabled()) {
	push(@menu_items, \@backup_device_item);
    }
    push(@menu_items, \@backup_cloud_item);
    push(@menu_items, \@backup_server_item);

    my $returnval = menu_presenter($menu_title, \@menu_items);

    if ($returnval eq "timeout") {
	logevent("backup_main] inactivity timeout");
	wait_for_user();
    }
    elsif ($returnval eq "dialogerr") {
	logevent("backup_main] dialog error");
	wait_for_user();
    }

    return(1);
}


sub lonetar_main
{
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $title = "Backup Menu";
	my $user = "";
	my $logfile = "";

	while(1) {

		$title = titlestring("Lonetar Menu");

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";
		$command .= " \"Backup History\"" . " \"History of previous Backups\"";
		$command .= " \"Backup Results\"" . " \"Display Backup Results\"";
		$command .= " \"Ltar Log\"" . " \"Lone-Tar \"ltar.log\" File\"";
		$command .= " \"Master Log\"" . " \"Lone-Tar \"Master\" Logfiles\"";
		$command .= " \"Eject\"" . " \"Eject Rev Tape\"";
		$command .= " \"LoneTar\"" . " \"Lone-Tar Menu\"";
		$command .= " \"Tapetell\"" . " \"Verify Tape Contents\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(BACKDIALOG, "$command |");
		$returnval = <BACKDIALOG>;
		close(BACKDIALOG);
		next if(! $returnval);
		chomp($returnval);

		if($returnval eq  "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);

		} elsif($returnval eq "Backup History") {
			backup_summary_logs($DEVTYPE_LTAR);

		} elsif($returnval eq "Backup Results") {
			system("grep -B 3 \"RESULT:\" /log/ltar.log | tac | less");


		} elsif($returnval eq "Ltar Log") {
			viewfiles("/log/ltar.log");

		} elsif($returnval eq "Master Log") {
			viewfiles("/log/Master*");
			
		} elsif($returnval eq "Eject") {
			system("sudo /usr/sbin/eject /dev/scd0");

		} elsif($returnval eq "LoneTar") {
			system("sudo /usr/lone-tar/ltmenu");

		} elsif($returnval eq "Tapetell") {
			system("sudo /usr/lone-tar/tapetell");

		} elsif($returnval eq "Close") {
			return(0);
		}
	}
}


sub backup_cmd_path
{
    my @search_dirs = (
	$POS_BINDIR,
	$OSTOOLS_BINDIR,
	$DAISYDIR,
	$NOPOS_BINDIR,
    );

    my $backup_cmd_path = "";
    foreach my $script_dir (@search_dirs) {
	my $script_path = File::Spec->catdir($script_dir, $BACKUP_SCRIPT_NAME);
	next until(-f $script_path);
	$backup_cmd_path = $script_path;
	last;
    }

    return($backup_cmd_path);
}


sub backup_print_backup_header
{
    my ($menu_code) = @_;;

    system("/usr/bin/clear");
    print "[[ $menu_code - Device Backup Menu ]]\n\n";

    return(1);
}


sub backup_rtibackup_find_device
{
    my ($menu_code, $backupscript) = @_;

    backup_print_backup_header($menu_code);

    my $cmd = "sudo $backupscript --finddev";
    print "command: $cmd\n\n";
    system("$cmd");
    wait_for_user();

    return(1);
}


sub backup_rtibackup_history_rti_summary_logs
{
    system("/usr/bin/clear");
    system("/usr2/bbx/bin/checkbackup.pl | less");

    return;
}


sub backup_rtibackup_history_daisy_summary_logs
{
    my ($backup_script) = @_;

    my $pos_log_dir = $DAISY_LOGDIR;
    my $lastbackup = qx(ls -1tr $pos_log_dir/rtibackup* | tail -1);
    chomp $lastbackup;

    my $backup_results = get_backup_status_indicator($lastbackup);
    if ($backup_results eq $EMPTY_STR) {
	$backup_results = "FAILED";
    }

    my @log_files = qx(ls -tr $pos_log_dir/rtiback* | tail -7);

    my $backup_last = $EMPTY_STR;
    foreach my $log_file (@log_files) {

	chomp $log_file;

	my $revision_line = $EMPTY_STR;
        if (open(my $lfh, '<', $log_file)) {
	    while (<$lfh>) {
		if (/Revision:/) {
		    $revision_line = $_;
		    last;
		}
	    }
	    close($lfh);
	}
	else {
	    next;
	}

        my @log_entry_line = ();
        if ($revision_line) {
            @log_entry_line = split (/\s+/, $revision_line);
        }
        if (@log_entry_line) {
            $backup_last .= " $log_file  $log_entry_line[0]   ";
        }

	my $temp_results = get_backup_status_indicator($log_file);
	if ($temp_results eq $EMPTY_STR) {
	    $temp_results = "FAILED";
	}

	$backup_last .= " $temp_results\n";
    }

    my $tmp_file = "/tmp/rtibackup.daisy.summary.log.$$";

    if (open(my $sumfh, '>', $tmp_file)) {
	print $sumfh "backup script: $backup_script\n";
	print $sumfh "latest results: $backup_results\n\n";
	print $sumfh "results for previous week:\n\n";
	print $sumfh "$backup_last\n";

	close($sumfh);

	system("cat $tmp_file");
	wait_for_user();

	system("rm $tmp_file");
    }
    else {
	print("could not make temp file: $tmp_file\n");
	wait_for_user();
    }

    return(1);
}


sub backup_rtibackup_history
{
    my ($menu_code, $backupscript) = @_;

    backup_print_backup_header($menu_code);

    if (-d $RTIDIR) {
	backup_rtibackup_history_rti_summary_logs();
    }
    elsif (-d $DAISYDIR) {
	backup_rtibackup_history_daisy_summary_logs($backupscript);
    }

    return(1);
}


sub backup_rtibackup_eject_device
{
    my ($menu_code, $backupscript) = @_;

    backup_print_backup_header($menu_code);

    my $cmd = "sudo $backupscript --eject";
    print "command: $cmd\n\n";
    system("$cmd");
    wait_for_user();

    return(1);
}


sub backup_rtibackup_full_backup
{
    my ($menu_code, $backupscript) = @_;

    backup_print_backup_header($menu_code);

    print "The full backup procedure overwrites any backups on the backup device.\n\n";
    my $cmd = "sudo $backupscript --format --backup=all --verbose";
    print "command: $cmd\n\n";
    my $answer = backup_prompt_cancel_confirm();
    if ($answer) {
	system("$cmd");
	wait_for_user();
    }

    return(1);
}


sub backup_rtibackup_verify_backup
{
    my ($menu_code, $backupscript) = @_;

    backup_print_backup_header($menu_code);

    my $cmd = "sudo $backupscript --verify";
    print "command: $cmd\n\n";

    my $tmp_file = "/tmp/tfsupport.backup.verify.$$";
    $cmd .= " | tee $tmp_file";
    system("$cmd");
    wait_for_user();

    print "\nSend verification results to a printer?\n";
    my $returnval = backup_prompt_cancel_confirm();
    if ($returnval) {
	my $printer = choose_printer("Please choose a printer");
	if ($printer) {
	    my $cmd = "cat $tmp_file";
	    system("$cmd | $POSDIR/bin/tfprinter.pl --print $printer");
	    print("Verification results sent to printer \"$printer\".\n");
	    wait_for_user();
	}
    }
    system("rm $tmp_file");

    return(1);
}


sub backup_rtibackup_format_device
{
    my ($menu_code, $backupscript) = @_;

    backup_print_backup_header($menu_code);

    print "The format operation removes all data from the backup device\n\n";
    my $answer = backup_prompt_cancel_confirm();
    if ($answer) {
	my $cmd = "sudo $backupscript --force --format";
	print "\ncommand: $cmd\n\n";
	system("$cmd");
    }
    else {
	print "\nFormat of backup device was NOT Performed\n";
    }
    wait_for_user();

    return(1);
}


sub backup_rtibackup_main
{
    my ($device_type) = @_;

    my $backupscript = backup_cmd_path();
    unless ($backupscript) {
	system("/usr/bin/clear");
	logerror("[backup_rtibackup_main] could not locate backup script");
	wait_for_user();
	return(0);
    }

    my $menu_title = '[[ Legacy Device Backup Menu ]]';

    my @menu_items = (
	[ "Find Device",
	"Report Backup Device Info",
	\&backup_rtibackup_find_device,
	$backupscript,
	],
	[ "Backup History",
	"Review Status of Previous Backups",
	\&backup_rtibackup_history,
	$backupscript,
	],
	[ "Eject Device",
	"Eject Backup Device",
	\&backup_rtibackup_eject_device,
	$backupscript,
	],
	[ "Full Backup",
	"Perform a Full Backup",
	\&backup_rtibackup_full_backup,
	$backupscript,
	],
	[ "Verify Backup",
	"Verify Backup Status",
	\&backup_rtibackup_verify_backup,
	$backupscript,
	],
	[ "Format Device",
	"Format Backup Device",
	\&backup_rtibackup_format_device,
	$backupscript,
	],
	[ "Advanced",
	"Advanced Device Backup Tools",
	\&backup_rtibackup_advanced,
	$backupscript,
	],
    );

    my $returnval = menu_presenter($menu_title, \@menu_items);

    if ($returnval eq "timeout") {
	logevent("backup_rtibackup_main] inactivity timeout");
	wait_for_user();
    }
    elsif ($returnval eq "dialogerr") {
	logevent("backup_rtibackup_main] dialog error");
	wait_for_user();
    }

    return(1);
}

sub backup_prompt
{
    my ($prompt) = @_;

    $| = 1; # activate autoflush to immediately show the prompt

    print "$prompt: ";
    my $answer = <STDIN>;
    chomp($answer);

    $| = 0;

    return($answer);
}

sub backup_prompt_cancel_confirm
{
    my $answer = backup_prompt("cancel: ENTER, confirm: Y followed by ENTER");

    return(lc($answer));
}

sub backup_prompt_string
{
    my ($prompt) = @_;

    my $answer = backup_prompt($prompt);

    return($answer);
}

sub backup_print_advanced_backup_header
{
    my ($menu_code, $menu_type) = @_;

    system("/usr/bin/clear");
    print "[[ $menu_code - Advanced $menu_type Device Backup Menu ]]\n\n";

    return(1);
}


sub backup_rtibackup_advanced_view_log
{
    my ($menu_code, $backupscript) = @_;

    backup_print_advanced_backup_header($menu_code, 'Legacy');

    print "Confirm to view the current log file or cancel to choose a previous log file.\n\n";
    my $answer = backup_prompt_cancel_confirm();
    print "\n";
    if ($answer) {
	my $logfile = qx(ls -t $POSDIR/log/rtibackup-*.log | head -1);
	print "command: less $logfile\n";
	wait_for_user();

	system("less $logfile");
    }
    else {
	while (1) {
	    $answer = viewfiles("$POSDIR/log/rtibackup-*.log", "");
	    if ($answer eq "") {
		last;
	    }
	}
    }

    return(1);
}

sub backup_rtibackup_advanced_edit_config
{
    my ($menu_code, $backupscript) = @_;

    backup_print_advanced_backup_header($menu_code, 'Legacy');

    print "Warning: editing the config file can drastically change the backup behaviour\n\n";
    my $rc = backup_rtibackup_edit_vim_config('.vimrc');
    if ($rc == 0) {
	wait_for_user();
    }
    my $cmd = "sudo rvim $POSDIR/config/backups.config";
    print "command: $cmd\n";
    wait_for_user();

    system("$cmd");

    return(1);
}

sub backup_rtibackup_edit_vim_config
{
    my ($conf_file) = @_;

    my $rc = 1;

    my $vim_conf_stmt = 'colorscheme desert';

    # just return if the file is already changed
    if (fgrep($conf_file, $vim_conf_stmt) == 0) {
	return($rc);
    }

    # make the file and return if it does not exist
    if (! -f $conf_file) {
	system("echo $vim_conf_stmt > $conf_file");
	my $pos_group = (-d $RTIDIR) ? 'rti' : 'daisy';
	system("chown tfsupport:$pos_group $conf_file");
	system("chmod 644 $conf_file");
	return($rc);
    }

    # ok, gotta update the config file
    my $new_conf_file = $conf_file . "$$";
    if (open(my $fh, '<', $conf_file)) {
	if (open(my $nfh, '>', $new_conf_file)) {

	    # copy the old to the new
	    while (<$fh>) {
		print {$nfh} $_;
	    }

	    # append to the new
	    print {$nfh} "$vim_conf_stmt\n";

	    close($nfh);

	    # set file perms on new 
	    $rc = backup_rtibackup_set_modes_vim_config($conf_file, $new_conf_file);
	}
	else {
	    print "could not open for write new config file: $new_conf_file\n";
	    $rc = 0;
	}
	close($fh);
    }
    else {
	print "could not open for read config file: $conf_file\n";
	$rc = 0;
    }

    return($rc);
}

sub backup_rtibackup_set_modes_vim_config
{
    my ($conf_file, $new_conf_file) = @_;

    my $rc = 1;

    # verify new config file exists and is not zero length
    if (-s $new_conf_file) {
	system("chmod --reference=$conf_file $new_conf_file");
	system("chown --reference=$conf_file $new_conf_file");
	system("mv $new_conf_file $conf_file");
    }
    else {
	my $err_type = (-f $new_conf_file) ? "is zero length" : "does not exist";
	print "could not update vim config, new config file: $err_type";
	$rc = 0;
    }

    return($rc);
}

sub backup_rtibackup_advanced_check_disk
{
    my ($menu_code, $backupscript) = @_;

    backup_print_advanced_backup_header($menu_code, 'Legacy');

    print "The check disk operation can take a very long time.\n\n";
    my $answer = backup_prompt_cancel_confirm();
    if ($answer) {
	my $cmd = "echo sudo $backupscript --checkmedia";
	my $recipient = backup_prompt_string("\n(Optional) Send results to email address");
	if ($recipient) {
	    $recipient = validate_input($recipient);
	    if ($recipient) {
		$cmd .= " --email=\"$recipient\"";
	    }
	}
	print "\ncommand: $cmd\n";
	system("$cmd");
	wait_for_user();
    }

    return(1);
}

sub backup_rtibackup_advanced_list_files
{
    my ($menu_code, $backupscript) = @_;

    backup_print_advanced_backup_header($menu_code, 'Legacy');

    my $cmd = "(sudo $backupscript --list=all) | less";
    print "command: $cmd\n\n";
    print "This command will list all files on the backup device.\n\n";
    my $answer = backup_prompt_cancel_confirm();
    if ($answer) {
	system("$cmd");
    }

    return(1);
}

sub backup_rtibackup_advanced_backup_date
{
    my ($menu_code, $backupscript) = @_;

    backup_print_advanced_backup_header($menu_code, 'Legacy');

    backup_display_date($backupscript);
    wait_for_user();

    return(1);
}

sub backup_rtibackup_advanced_restore_file
{
    my ($menu_code, $backupscript) = @_;

    backup_print_advanced_backup_header($menu_code, 'Legacy');

    my $line1 = "\nEnter the full path of a file or directory to be restored:\n";
    my $line2 = "a) only one file path or directory path is allowed\n";
    my $line3 = "b) file or directory paths with SPACES are allowed\n";
    my $line4 = "c) shell style wildcard chars are allowed\n";
    my $message = $line1 . $line2 . $line3 . $line4;
    print "$message\n";

    my $file_path = backup_prompt_string("\nEnter file or directory path");
    if ($file_path) {
	$file_path = validate_input($file_path);
	my $cmd = "sudo $backupscript --verbose --rootdir=/tmp --restore \"$file_path\"";
	print "\ncommand: $cmd\n\n";
	system("sudo $backupscript --verbose --rootdir=/tmp --restore \"$file_path\"");
	wait_for_user();
    }

    return(1);
}

sub backup_rtibackup_advanced_verify_file
{
    my ($menu_code, $backupscript) = @_;

    backup_print_advanced_backup_header($menu_code, 'Legacy');

    my $file_path = backup_prompt_string("\nEnter file or directory path to verify");
    if ($file_path) {
	$file_path = validate_input($file_path);
	my $cmd = "sudo $backupscript --checkfile \"$file_path\"";
	print "\ncommand: $cmd\n\n";
	system("sudo $backupscript --checkfile \"$file_path\"");
	wait_for_user();
    }

    return(1);
}

sub backup_rtibackup_advanced_backup_rti_root
{
    my ($menu_code, $backupscript) = @_;

    backup_print_advanced_backup_header($menu_code, 'Legacy');

    print "This procedure overwrites backup 'usr2' on the backup device.\n\n";
    my $cmd = "sudo $backupscript --backup=usr2 --verbose";
    print "command: $cmd\n";
    my $answer = backup_prompt_cancel_confirm();
    if ($answer) {
	system("$cmd");
    }
    wait_for_user();

    return(1);
}

sub backup_rtibackup_advanced_backup_daisy_root
{
    my ($menu_code, $backupscript) = @_;

    backup_print_advanced_backup_header($menu_code, 'Legacy');

    print "This procedure overwrites backup 'daisy' on the backup device.\n\n";
    my $cmd = "sudo $backupscript --backup=daisy --verbose";
    print "command: $cmd\n\n";
    my $answer = backup_prompt_cancel_confirm();
    if ($answer) {
	system("$cmd");
    }
    wait_for_user();

    return(1);
}


sub backup_rtibackup_advanced
{
    my ($menu_code, $backupscript) = @_;

    my $menu_title = "[[ $menu_code - Legacy Device Backup Menu ]]";

    my @menu_items = (
	[ "View Log",
	"View Backup Log Files",
	\&backup_rtibackup_advanced_view_log,
	$backupscript,
	],
	[ "Edit Config",
	"Edit Backup Config File",
	\&backup_rtibackup_advanced_edit_config,
	$backupscript,
	],
	[ "Check Disk",
	"Scan for Errors on Backup Device",
	\&backup_rtibackup_advanced_check_disk,
	$backupscript,
	],
	[ "List Files",
	"List All Files On Backup Device",
	\&backup_rtibackup_advanced_list_files,
	$backupscript,
	],
	[ "Backup Date",
	"Dispay Backup Dates On Backup Device",
	\&backup_rtibackup_advanced_backup_date,
	$backupscript,
	],
	[ "Restore File",
	"Restore File From Backup Device",
	\&backup_rtibackup_advanced_restore_file,
	$backupscript,
	],
	[ "Verify File",
	"Verify File On Backup Device",
	\&backup_rtibackup_advanced_verify_file,
	$backupscript,
	],
    );

    my @backup_rti_root_item = (
	"Backup $RTI_ROOT",
	"Backup contents of $RTI_ROOT",
	\&backup_rtibackup_advanced_backup_rti_root,
	$backupscript,
    );
    my @backup_daisy_root_item = (
	"Backup $DAISY_ROOT",
	"Backup contents of $DAISY_ROOT",
	\&backup_rtibackup_advanced_backup_daisy_root,
	$backupscript,
    );

    if (-d $RTI_ROOT) {
	push(@menu_items, \@backup_rti_root_item);
    }
    if (-d $DAISY_ROOT) {
	push(@menu_items, \@backup_daisy_root_item);
    }

    my $returnval = menu_presenter($menu_title, \@menu_items);

    if ($returnval eq "timeout") {
	logevent("backup_rtibackup_advanced] inactivity timeout");
	wait_for_user();
    }
    elsif ($returnval eq "dialogerr") {
	logevent("backup_rtibackup_advanced] dialog error");
	wait_for_user();
    }

    return(1);
}


sub backup_device_main_report_name
{
    my ($menu_code, $script_path) = @_;

    backup_print_backup_header($menu_code, 'LUKS');

    my $cmd = "sudo $script_path --luks --luks-getinfo";
    print "command: $cmd\n\n";
    system("$cmd");
    wait_for_user();

    return(1);
}


sub backup_device_main_history
{
    my ($menu_code, $backupscript) = @_;

    backup_print_backup_header($menu_code);

    if ($POSDIR) {
	my $logfile_dir = ($POSDIR eq $RTIDIR) ? $RTI_LOGDIR : $DAISY_LOGDIR;
	my $logfile_name = $DEF_TFRSYNC_SUMMARY_LOGFILE;
	my $logfile_path = File::Spec->catdir($logfile_dir, $logfile_name);
	my $backup_type = $DEVTYPE_LUKS;
	backup_tfrsync_summary_status($backup_type, $logfile_path);
    }
    else {
	print "There are no backup log files available\n";
    }

    wait_for_user();

    return(1);
}


sub backup_device_main_perform_backup
{
    my ($menu_code, $backupscript) = @_;

    backup_print_backup_header($menu_code);

    print "The full backup procedure alters the current backup on the backup device.\n\n";
    my $cmd = "sudo $backupscript --luks --backup=all";
    print "command: $cmd\n\n";
    my $answer = backup_prompt_cancel_confirm();
    if ($answer) {
	system("$cmd");
	wait_for_user();
    }

    return(1);
}


sub backup_device_main_format_device
{
    my ($menu_code, $script_path) = @_;

    backup_print_backup_header($menu_code);

    print "The format operation removes all data from the backup device\n\n";
    my $answer = backup_prompt_cancel_confirm();
    if ($answer) {
	my $cmd = "sudo $script_path --luks --luks-init";
	print "\ncommand: $cmd\n\n";
	system("$cmd");
    }
    else {
	print "\nFormat of backup device was NOT Performed\n";
    }
    wait_for_user();

    return(1);
}


sub backup_device_main
{
    my ($device_type) = @_;

    if (! backup_is_luks_enabled()) {
	system("/usr/bin/clear");
	backup_device_sales_pitch();
	wait_for_user();
	return(1);
    }

    my $script_path = File::Spec->catdir($OSTOOLS_BINDIR, "tfrsync.pl");

    my $menu_title = '[[ Device Backup Menu ]]';

    my @menu_items = (
	[ "Find Device",
	"Report Backup Device Info",
	\&backup_device_main_report_name,
	$script_path,
	],
	[ "Backup History",
	"Review Status of Previous Backups",
	\&backup_device_main_history,
	$script_path,
	],
	[ "Full Backup",
	"Perform a Full Backup",
	\&backup_device_main_perform_backup,
	$script_path,
	],
	[ "Format Device",
	"Format Backup Device",
	\&backup_device_main_format_device,
	$script_path,
	],
	[ "Advanced",
	"Advanced Device Backup Tools",
	\&backup_device_advanced,
	$script_path,
	],
    );

    my $returnval = menu_presenter($menu_title, \@menu_items);

    if ($returnval eq "timeout") {
	logevent("backup_device_main] inactivity timeout");
	wait_for_user();
    }
    elsif ($returnval eq "dialogerr") {
	logevent("backup_device_main] dialog error");
	wait_for_user();
    }

    return(1);
}


sub backup_device_advanced_view_log
{
    my ($menu_code, $script_path) = @_;

    backup_print_advanced_backup_header($menu_code, 'LUKS');

    print "Confirm to view the current log file or cancel to choose a previous log file.\n\n";
    my $answer = backup_prompt_cancel_confirm();
    print "\n";
    if ($answer) {
	my $logfile_path = qx/sudo $script_path --luks --report-logfile/;
	if (defined($logfile_path)) {
	    $logfile_path =~ s/^.*: //;
	    my $cmd = "less $logfile_path";
	    print "command: $cmd\n";
	    wait_for_user();
	    system("$cmd");
	}
	else {
	    print "Could not get path to log file\n";
	}
    }
    else {
	while (1) {
	    $answer = viewfiles("$POSDIR/log/tfrsync-device-Day*.log", "");
	    if ($answer eq "") {
		last;
	    }
	}
    }

    return(1);
}


sub backup_device_advanced_list_files
{
    my ($menu_code, $script_path) = @_;

    backup_print_advanced_backup_header($menu_code, 'LUKS');

    my $cmd = "(sudo $script_path --luks --list=all) | less";
    print "command: $cmd\n\n";
    print "This command will list all files on the backup device.\n\n";
    my $answer = backup_prompt_cancel_confirm();
    if ($answer) {
	system("$cmd");
    }

    wait_for_user();

    return(1);
}


sub backup_device_advanced_mount_device
{
    my ($menu_code, $script_path) = @_;

    backup_print_advanced_backup_header($menu_code, 'LUKS');

    my $cmd = "$script_path --luks --luks-mount";
    print "\ncommand: $cmd\n\n";
    system("sudo $cmd");

    wait_for_user();

    return(1);
}


sub backup_device_advanced_umount_device
{
    my ($menu_code, $script_path) = @_;

    backup_print_advanced_backup_header($menu_code, 'LUKS');

    my $cmd = "$script_path --luks --luks-umount";
    print "\ncommand: $cmd\n\n";
    system("sudo $cmd");

    wait_for_user();

    return(1);
}


sub backup_device_advanced_verify_device
{
    my ($menu_code, $script_path) = @_;

    backup_print_backup_header($menu_code, 'LUKS');

    my $cmd = "$script_path --luks --luks-verify";
    print "\ncommand: $cmd\n\n";
    system("sudo $cmd");

    wait_for_user();

    return(1);
}


sub backup_device_advanced_backup_date
{
    my ($menu_code, $script_path) = @_;

    backup_print_advanced_backup_header($menu_code, 'LUKS');

    my $cmd = "$script_path --luks --luks-backup-date";
    print "\ncommand: $cmd\n\n";
    system("sudo $cmd");

    wait_for_user();

    return(1);
}


sub backup_device_advanced_restore_file
{
    my ($menu_code, $script_path) = @_;

    backup_print_advanced_backup_header($menu_code, 'LUKS');

    my $line1 = "\nEnter the full path of a file or directory to be restored:\n";
    my $line2 = "a) only one file path or directory path is allowed\n";
    my $line3 = "b) file or directory paths with SPACES are allowed\n";
    my $line4 = "c) shell style wildcard chars are allowed\n";
    my $message = $line1 . $line2 . $line3 . $line4;
    print "$message\n";

    my $file_path = backup_prompt_string("\nEnter file or directory path");
    if ($file_path) {
	$file_path = validate_input($file_path);
	my $cmd = "sudo $script_path --luks --luks-file-restore=$file_path --rootdir=/tmp";
	print "\ncommand: $cmd\n\n";
	system($cmd);
	wait_for_user();
    }

    return(1);
}


sub backup_device_advanced_verify_file
{
    my ($menu_code, $script_path) = @_;

    backup_print_advanced_backup_header($menu_code, 'LUKS');

    print "Perl regular expressions may be entered for file or directory path\n";
    my $file_path = backup_prompt_string("\nEnter file or directory path to verify");
    if ($file_path) {
	my $cmd = "$script_path --luks --luks-file-verify=$file_path";
	print "\ncommand: $cmd\n\n";
	system("sudo $cmd");
	wait_for_user();
    }

    return(1);
}


sub backup_device_advanced_backup_rti_root
{
    my ($menu_code, $script_path) = @_;

    backup_print_advanced_backup_header($menu_code, 'LUKS');

    print "This procedure may alter files in the 'usr2' backup set.\n\n";
    my $cmd = "sudo $script_path --luks --backup=usr2";
    print "command: $cmd\n\n";
    my $answer = backup_prompt_cancel_confirm();
    if ($answer) {
	system("$cmd");
    }

    wait_for_user();

    return(1);
}


sub backup_device_advanced_backup_daisy_root
{
    my ($menu_code, $script_path) = @_;

    backup_print_advanced_backup_header($menu_code, 'LUKS');

    print "This procedure may alter files in the 'daisy' backup set.\n\n";
    my $cmd = "sudo $script_path --luks --backup=daisy";
    print "command: $cmd\n\n";
    my $answer = backup_prompt_cancel_confirm();
    if ($answer) {
	system("$cmd");
    }

    wait_for_user();

    return(1);
}


sub backup_device_advanced_shell
{
    my ($menu_code, $script_path) = @_;

    system("/usr/bin/clear");
    logevent("Begin Shellout to Commandline.");
    set_signal_handlers('DEFAULT');
    system("PS1=\"\[\\u\@\\h\ \\W]\$ \" /bin/bash");
    set_signal_handlers('IGNORE');

    return(1);
}


sub backup_device_advanced
{
    my ($menu_code, $backupscript) = @_;

    my $menu_title = "[[ $menu_code - Device Backup Menu ]]";

    my @menu_items = (
	[ "View Log",
	"View Current Device Backup Log File",
	\&backup_device_advanced_view_log,
	$backupscript,
	],
	[ "List Files",
	"List All Files in Current Backup",
	\&backup_device_advanced_list_files,
	$backupscript,
	],
	[ "Mount Device",
	"Mount Backup Device",
	\&backup_device_advanced_mount_device,
	$backupscript,
	],
	[ "Unmount Device",
	"Unmount Backup Device",
	\&backup_device_advanced_umount_device,
	$backupscript,
	],
	[ "Verify Device",
	"Verify Backup Device",
	\&backup_device_advanced_verify_device,
	$backupscript,
	],
	[ "Backup Date",
	"Dispay Backup Date On Backup Device",
	\&backup_device_advanced_backup_date,
	$backupscript,
	],
	[ "Restore File",
	"Restore File From Backup Device",
	\&backup_device_advanced_restore_file,
	$backupscript,
	],
	[ "Verify File",
	"Verify File On Backup Device",
	\&backup_device_advanced_verify_file,
	$backupscript,
	],
    );

    my @backup_rti_root_item = (
	"Backup $RTI_ROOT",
	"Backup contents of $RTI_ROOT",
	\&backup_device_advanced_backup_rti_root,
	$backupscript,
    );
    my @backup_daisy_root_item = (
	"Backup $DAISY_ROOT",
	"Backup contents of $DAISY_ROOT",
	\&backup_device_advanced_backup_daisy_root,
	$backupscript,
    );
    if (-d $RTI_ROOT) {
	push(@menu_items, \@backup_rti_root_item);
    }
    if (-d $DAISY_ROOT) {
	push(@menu_items, \@backup_daisy_root_item);
    }
    my @shellout_item = (
	"Commandline",
	"Go to the Linux Shell",
	\&backup_device_advanced_shell,
	$backupscript,
    );
    push(@menu_items, \@shellout_item);

    my $returnval = menu_presenter($menu_title, \@menu_items);

    if ($returnval eq "timeout") {
	logevent("backup_device_advanced] inactivity timeout");
	wait_for_user();
    }
    elsif ($returnval eq "dialogerr") {
	logevent("backup_device_advanced] dialog error");
	wait_for_user();
    }

    return(1);
}


sub backup_cloud_main
{
    my ($device_type) = @_;

    unless (backup_is_cloud_backup_enabled()) {
	system("/usr/bin/clear");
	backup_cloud_sales_pitch();
	wait_for_user();
	return(1);
    }

    my $menu_title = '[[ Cloud Backup Menu ]]';

    return(1);
}


sub backup_server_main
{
    my ($device_type) = @_;

    unless (backup_is_server_backup_enabled()) {
	system("/usr/bin/clear");
	backup_server_sales_pitch();
	wait_for_user();
	return(1);
    }

    my $menu_title = '[[ Server Backup Menu ]]';


    return(1);
}


sub backup_summary_logs
{
    my ($backup_type) = @_;

    print "sub backup_summary_logs() obsolete\n";

    wait_for_user();

    return(1);
}


sub backup_cloud_sales_pitch
{
    my $msg = "[[ Cloud Server Backup ]]\n";
    $msg   .= "\n";
    $msg   .= "Your system is not configured for Teleflora's Cloud Backup Solution.\n";
    $msg   .= "\n";
    $msg   .= "Teleflora offers a secure and fully automated cloud backup solution,\n";
    $msg   .= "created specifically for your Point of Sale, that ensures that your\n";
    $msg   .= "critical data is safely protected offsite and always available.\n";
    $msg   .= "This cloud backup solution backs up every piece of your point of sale data\n";
    $msg   .= "each night to ensure full recovery if a disaster were to strike.\n";
    $msg   .= "\n";
    $msg   .= "Contact your point of sale support team for more information or\n";
    $msg   .= "to take advantage of this valuable feature!\n";

    print $msg;

    return(1);
}

sub backup_server_sales_pitch
{
    my $msg = "[[ Secondary Server Backup ]]\n";
    $msg   .= "\n";
    $msg   .= "Your system is not configured to back up your data to a second server.\n";
    $msg   .= "\n";
    $msg   .= "Teleflora offers the ability to back up your point of sale data\n";
    $msg   .= "to a second server on your network as often as once each hour.\n";
    $msg   .= "This allows you to avoid downtime by having a second server onsite\n";
    $msg   .= "with data installed and ready to use in the event that your production\n";
    $msg   .= "server dies unexpectedly.\n";
    $msg   .= "\n";
    $msg   .= "Contact your point of sale support team for more information or\n";
    $msg   .= "to take advantage of this valuable feature!\n";

    print $msg;

    return(1);
}

sub backup_device_sales_pitch
{
    my $msg = "[[ LUKS Device Backup ]]\n";
    $msg   .= "\n";
    $msg   .= "Your system is not configured to back up your data to a LUKS device.\n";
    $msg   .= "\n";
    $msg   .= "Teleflora offers the ability to back up your point of sale data\n";
    $msg   .= "incrementally to a locally connected LUKS device as often as\n";
    $msg   .= "once each hour.\n";
    $msg   .= "\n";
    $msg   .= "Contact your point of sale support team for more information or\n";
    $msg   .= "to take advantage of this valuable feature!\n";

    print $msg;

    return(1);
}

sub backup_sales_pitch
{
    my ($backup_type) = @_;

    if ($backup_type eq $DEVTYPE_CLOUD) {
	backup_cloud_sales_pitch();
    }
    elsif ($backup_type eq $DEVTYPE_SERVER) {
	backup_server_sales_pitch();
    }
    elsif ($backup_type eq $DEVTYPE_LUKS) {
	backup_device_sales_pitch();
    }

    return(1);
}

#
# the tfrsync.pl backup facility is considered to be installed if
# on of the following are true:
# 1. the "tfrsync" account is present and a "cloud" log file is present
# 2. the "tfrsync" account is present and a "server" log file is present
# 3. a "device" log file is present
#
# returns
#   true if tfrsync.pl is installed
#   false if not
#
sub backup_is_tfrsync_installed
{
    my ($backup_type, $logdir) = @_;

    my $rc = 0;

    my %logfile_tab = (
	$DEVTYPE_LUKS   => 'tfrsync-device-Day*.log',
	$DEVTYPE_CLOUD  => 'tfrsync-cloud-Day*.log',
	$DEVTYPE_SERVER => 'tfrsync-server-Day*.log',
    );

    for my $logfile_type (keys(%logfile_tab)) {
	# form a path to a logfile
	my $logfile_re = $logfile_tab{$logfile_type};
	my $logfile_path = File::Spec->catdir($logdir, $logfile_re);

	# count the number of logfiles
	my $logfile_count = glob($logfile_path);

	# if there are any logfiles
	if ($logfile_count) {
	    # don't need an account for device or luks device type
	    if ($logfile_type eq $DEVTYPE_LUKS) {
		$rc = 1;
	    }
	    # must have account for either cloud or server
	    else {
		my %account_info = get_account_info("tfrsync");
		if (%account_info) {
		    $rc = 1;
		}
	    }
	}
    }

    return($rc);
}

sub backup_summary_log_get_next_record
{
    my ($slf, $backup_type) = @_;

    my %record = ();
    while (my $line = <$slf>) {
	# skip lines until start of record seen
	if ($line =~ m/^=======/) {
	    # gather fields until end of record seen
	    while ($line = <$slf>) {
		if ($line =~ m/^=======/) {
		    last;
		}
		if ($line =~ m/\s*(\S+): (.+)$/) {
		    $record{$1} = $2;
		}
	    }
	}
	# if record seen, and of right type, exit loop
	# else, zero record and try again
	if (%record) {
	    if ($record{DEVICE} eq $backup_type) {
		last;
	    }
	    else {
		%record = ();
	    }
	}
    }

    return(%record);
}

sub backup_tfrsync_summary_status
{
    my ($backup_type, $logfile) = @_;

    unless (-f $logfile) {
	print "Backup summary log file does not exist: $logfile";
	return(1);
    }

    my %record = ();

    my $q_size = 10;
    my @q = ();
    my $rec_nr = 0;
    if (open(my $slf, '<', $logfile)) {
	while (%record = backup_summary_log_get_next_record($slf, $backup_type)) {
	    $rec_nr++;

	    # add the per-backup-type record number to the record
	    $record{RECNR} = $rec_nr;

	    # if the q is full, remove record at beginning of q,
	    # move all entries up
	    if (scalar(@q) >= $q_size) {
		shift(@q);
	    }

	    # add reference to the new record to end of q
	    push(@q, { %record });
	}
	close($slf);

	if (@q) {
	    my $q_ents = $#q + 1;

	    print "\n";
	    print "The backup system being used: tfrsync.pl --$backup_type\n";
	    print "The last backup results: $q[$#q]->{RESULT}\n";
	    print "\n";
	    print "=====================================================================\n";
	    print "\n";
	    print "The results for the last $q_ents backups, oldest first:\n";
	    print "\n";
	    print "Logfile                           Recnr  Begin Date       Status\n";
	    print "-------                           -----  ---------------  ------\n";

	    for my $i (0 .. $#q) {
		printf("%-32s  %5s  %15s  %5s\n", $logfile, $q[$i]->{RECNR}, $q[$i]->{BEGIN}, $q[$i]->{RESULT});
	    }
	}
	else {
	    print "There are no records for backup type: $backup_type\n";
	}
    }

    return(1);
}

sub backup_display_date
{
    my ($backupcmd) = @_;

    # mount the backup device, no way to test success
    system("sudo $backupcmd --mount > /dev/null");

    # at this point, should be able to list files on mount device
    my $MOUNTPOINT = "/mnt/backups";

    # now get a list of files on the backup device
    my @top_level = glob("$MOUNTPOINT/*.bak");
    my @config_level = glob("$MOUNTPOINT/configs/*.bak");

    if (scalar(@top_level) == 0 && scalar(@config_level) == 0) {
	print "The backup device has no backup files\n";
	return;
    }

    print "List of backup files with backup dates\n\n";

    foreach my $file (@top_level, @config_level) {
	my $mtime = (stat $file)[9];
	my $ctime = localtime($mtime);
	printf "%+20s - %s\n", basename($file), $ctime;
    }

    # umount the backup device, no way to test success
    system("sudo $backupcmd --unmount > /dev/null");
}


sub tcc_logs_menu
{
    my $title = titlestring("TCC Logs Menu");
    my $tcc_version = get_tcc_version();
    $title .= $tcc_version;

    my $command = "dialog --stdout";
    $command .= " $TIMEOUT_MENU_ARG";
    $command .= " --no-cancel";
    $command .= " --default-item \"Close\"";
    $command .= " --menu '$title'";
    $command .= " 0 0 0";
    $command .= " \"Log\"" . " \"Show TCC Logfile\"";
    $command .= " \"Live Logs\"" . " \"Watch Live Logfile Activity\"";
    $command .= " \"Errors\"" . " \"TCC Errors and Warnings\"";
    $command .= " \"Close\"" . " \"Close This Menu\"";

    while(1) {

	if (open(my $dialogfh, '-|', $command)) {
	    $returnval = <$dialogfh>;
	    close($dialogfh);
	    next unless ($returnval);
	    chomp($returnval);
	}
	else {
	    print "[tcc logs menu] could not open pipe to dialog for: $title\n";
	    wait_for_user();
	    last;
	}

	if ($returnval eq  "timeout") {
	    logevent("Inactivity Timeout.");
	    exit(0);

	}
	elsif ($returnval eq "Live Logs") {
	    system("tail -f $POSDIR/log/tcc.log");

	}
	elsif ($returnval eq "Log") {
	    viewfiles("$POSDIR/log/tcc*.log");

	}
	elsif ($returnval eq "Errors") {
	    my $filter = "grep -e '<E>' -e '<W>'";
	    viewfiles("$POSDIR/log/tcc*.log", "", $filter);

	}
	elsif ($returnval eq "Close") {
	    last;
	}
    }

    return(1);
}


sub network_main
{
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $ipaddr = "";
	my $macaddr = "";
	my $title = "Network Menu\n";
	my $user = "";
	my $logfile = "";
	my $i = 0;
	my $temp = "";

	$title .="\n";
	while(1) {

		$title = titlestring("Network Menu");

		$returnval = get_hostname("--long");
		$title .= "Hostname: $returnval\\n";

		# Private IP Address(es)
		foreach my $device("eth0", "eth1", "bond0") {
			$ipaddr = "";
			$macaddr = "";
			open(PIPE, "/sbin/ifconfig $device 2> /dev/null |");
			while(<PIPE>) {
				chomp;
				if(/(inet addr:)(\d+\.\d+\.\d+\.\d+)/) {
					$ipaddr = $2;
					$ipaddr =~ s/[[:space:]]+//g;
				}
				if(/(HWaddr)(\s+)([[:print:]]+)/) {
					$macaddr = $3;
					$macaddr =~ s/[[:space:]]+//g;
				}
			}
			close(PIPE);
			if("$ipaddr" ne "") {
				$title .= "$device IPADDR=\"$ipaddr\" MAC=\"$macaddr\" \\n";
			}
		}


		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";
		$command .= " \"Host Connectivity Test\"" . " \"Verify Critical Hosts are Available\"";
		$command .= " \"Ping Test\"" . " \"Ping Specified IP Address or Hostname\"";
		$command .= " \"DNS Test\"" . " \"Test Domain Name Service (DNS)\"";
		$command .= " \"Cable Connectivity\"" . " \"Is a Cable Connected to the Server?\"";
		$command .= " \"Test Workstation\"" . " \"Can we see a workstation or Printer?\"";
		$command .= " \"Advanced\"" . " \"Advanced Tools\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(BACKDIALOG, "$command |");
		$returnval = <BACKDIALOG>;
		close(BACKDIALOG);
		next if(! $returnval);
		chomp($returnval);


		if($returnval eq  "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);
		}

		elsif ($returnval eq "DNS Test") {
			my $tmpfile = make_tempfile("tfsupport.pl");
			system("/usr/bin/clear");
			system("echo Running DNS lookup...");
			system("echo DNS lookup of www.google.com: >> $tmpfile");
			system("nslookup www.google.com >> $tmpfile");
			system("echo ================================================ >> $tmpfile");
			system("echo >> $tmpfile");
			system("echo DNS lookup of www.teleflora.com: >> $tmpfile");
			system("nslookup www.teleflora.com >> $tmpfile");
			system("echo ================================================ >> $tmpfile");
			system("echo >> $tmpfile");
			system("echo DNS lookup of igusproda.globalpay.com: >> $tmpfile");
			system("nslookup igusproda.globalpay.com >> $tmpfile");
			system("/usr/bin/clear");
			system("less $tmpfile");
			system("rm $tmpfile");
		}

		elsif ($returnval eq "Test Workstation") {
			$ipaddr = menu_getstring("Workstation IP Address?");
			if("$ipaddr" ne "") {
				system("ping -c 3 $ipaddr");
				system("sudo /usr/bin/nmap -v -sP $ipaddr");
				print("Customer may want to run \"Start -> Run -> 'netsh diag gui'\"\n");
				wait_for_user();
			}

		} elsif($returnval eq "Cable Connectivity") {
			system("clear");
			foreach my $device("eth0", "eth1", "eth2", "eth3", "eth4") {
				print("--- /dev/$device ---\n");
				system("sudo /sbin/ethtool $device 2> /dev/null | grep -i -e 'Speed' -e 'detected'");
				print("\n");
			}
			wait_for_user();
		}

		elsif ($returnval eq "Ping Test") {
			my $ipaddr = menu_getstring("Enter IP Address or Hostname to ping");
			if ($ipaddr ne "") {
				system("/usr/bin/clear");
				system("ping -c 3 $ipaddr");
				wait_for_user();
			}
		}

		elsif($returnval eq "Host Connectivity Test") {
			my $found = 0;
			system("/usr/bin/clear");
			my @urls = (
			    'https://tws.teleflora.com/TelefloraWebService.asmx', 
			    'https://twsstg.teleflora.com/TelefloraWebService.asmx',
			);
			foreach my $url (@urls) {
				$found = 0;
				print "Testing Web Server: $url\n\n";
				if (open(my $pipe, '-|', "curl -s --connect-timeout 3 $url")) {
				    while (<$pipe>) {
					if (/disco/) {
					    $found = 1;
					}
				    }
				    close($pipe);
				}
				if ($found == 1) {
				    print "Connection OK\n\n";
				}
				else {
				    print "Connection FAILED\n\n";
				}
			}

			# Actually connect to payment processor and validate that their
			# SSL Certificate indicates they are who we think they are.
			foreach my $url ('prodgate.viaconex.com') {
				$found = 0;
				print "Testing Payment Processor: $url\n\n";
				my $cmd = "echo \cD | openssl s_client -host $url -port 443 -verify 5";
				if (open(my $pipe, '-|', $cmd)) {
				    while (<$pipe>) {
					if (/Elavon Inc/) {
					    $found = 1;	
					    last;
					}
				    }
				    close($pipe);
				}
				else {
				    print "could not establish openssh connnection to: $url\n";
				}
				if ($found == 1) {
				    print "\nConnection OK\n\n";
				}
				else {
				    print "\nConnection FAILED\n\n";
				}
			}

			wait_for_user();

		} elsif($returnval eq "Advanced") {
			network_advanced();

		} elsif($returnval eq "Close") {
			return(0);
		}
	}
}

sub network_advanced
{
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $ipaddr = "";
	my $macaddr = "";
	my $title = "Network Advanced Menu";
	my $user = "";
	my $logfile = "";
	my $i = 0;
	my $temp = "";


	$title .="\n";
	while(1) {

		$title = titlestring("Network Advanced Menu");

		$returnval = get_hostname("--long");
		$title .= "Hostname: $returnval\\n";

		# Private IP Address(es)
		foreach my $device("eth0", "eth1", "bond0") {
			$ipaddr = "";
			$macaddr = "";
			open(PIPE, "/sbin/ifconfig $device 2> /dev/null |");
			while(<PIPE>) {
				chomp;
				if(/(inet addr:)(\d+\.\d+\.\d+\.\d+)/) {
					$ipaddr = $2;
					$ipaddr =~ s/[[:space:]]+//g;
				}
				if(/(HWaddr)(\s+)([[:print:]]+)/) {
					$macaddr = $3;
					$macaddr =~ s/[[:space:]]+//g;
				}
				
			}
			close(PIPE);
			if("$ipaddr" ne "") {
				$title .= "$device IPADDR=\"$ipaddr\" MAC=\"$macaddr\" \\n";
			}
		}


		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";
		$command .= " \"Route Info\"" . " \"IP Tables Routing Information\"";
		$command .= " \"Trace Route\"" . " \"Trace Packets to Specified Host\"";
		$command .= " \"Arp\"" . " \"View Current Arp Cache\"";
		$command .= " \"IPTables Rules\"" . " \"View IPTables Rules\"";
		$command .= " \"IP Addresses\"" . " \"Network Interface Information\"";
		$command .= " \"Restart Network\"" . " \"Restart all Network Interfaces\"";
		if(-f "/usr/sbin/system-config-network") {
			$command .= " \"Configure\"" . " \"Configure Ethernet Device(s)\"";
		}
		if(-f "/etc/sysconfig/network") {
			$command .= " \"Set Hostname\"" . " \"Re-Set the Computer's Hostname\"";
		}
		if(-f "/usr/bin/nmap") {
			$command .= " \"Network Discovery\"" . " \"Scan Network for Hosts\"";
		}
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(BACKDIALOG, "$command |");
		$returnval = <BACKDIALOG>;
		close(BACKDIALOG);
		next if(! $returnval);
		chomp($returnval);


		if ($returnval eq  "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);
		}

		elsif ($returnval eq "Arp") {
			system("/usr/bin/clear");
			system("/sbin/arp -vn");
			wait_for_user();
		}

		elsif ($returnval eq "Configure") {
			system("sudo /usr/sbin/system-config-network");
		}

		elsif ($returnval eq "Route Info") {
			my $tmpfile = make_tempfile("tfsupport.pl");
			system("echo Information about active interfaces: >> $tmpfile");
			system("/sbin/ifconfig >> $tmpfile");
			system("echo >> $tmpfile");
			system("echo ================================================ >> $tmpfile");
			system("echo >> $tmpfile");
			system("echo Information about IP routing tables: >> $tmpfile");
			system("route -n >> $tmpfile");
			system("echo >> $tmpfile");
			system("/usr/bin/clear");
			system("less $tmpfile");
			system("rm $tmpfile");
		}

		elsif ($returnval eq "Trace Route") {
			my $ipaddr = menu_getstring("Enter IP address or hostname to trace");
			if ($ipaddr ne "") {
				system("/usr/bin/clear");
				set_signal_handlers('DEFAULT');
				system("traceroute -n $ipaddr");
				set_signal_handlers('IGNORE');
				wait_for_user();
			}
		}

		elsif ($returnval eq "IP Addresses") {
			system("clear");
			system("/sbin/ifconfig -a | less");
		}

		elsif ($returnval eq "Restart Network") {
			$returnval = menu_confirm("Restart Network Connections?");
			if($returnval eq "Y") {
				system("clear");
				if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
				    system("sudo /sbin/service network restart");
				}
				if ($OS eq 'RHEL7') {
				    system("sudo systemctl restart network.service");
				}
				wait_for_user();
			}
		}

		elsif ($returnval eq "IPTables Rules") {
			system("clear");
			system("sudo iptables -t filter --list -n --line-numbers | less");
			wait_for_user();
		}

		elsif ($returnval eq "Network Discovery") {
			my %options = ();
			my $selection = "";
			$options{"a"} = "10.0.0.1/8";
			$options{"b"} = "172.16.0.1/12";
			$options{"c"} = "192.168.1.1/16";
			$options{"d"} = "Specify custom network address...";
			$selection = menu_pickone("Specify network address to scan", \%options, "c");
			$ipaddr = "";
			if (defined($selection) && ($selection ne "")) {
			    if ($selection eq "d") {
				$ipaddr = menu_getstring("Enter network address to scan");
				if ($ipaddr !~ /\d+\.\d+\.\d+\.\d+\/\d+/) {
				    system("/usr/bin/clear");
				    print("Invalid network address: $ipaddr\n");
				    wait_for_user();
				    $ipaddr = "";
				}
			    }
			    else {
				$ipaddr = $options{$selection};
			    }
			}

			if ($ipaddr) {
			    system("/usr/bin/clear");
			    print("Ready to discover hosts on network: $ipaddr\n");
			    print("This may take some time...\n");
			    wait_for_user();
			    system("sudo /usr/bin/nmap -n -sP $ipaddr | less");
			}
		}

		elsif ($returnval eq "Set Hostname") {
		    my $new_hostname = "";
		    my $hostname = get_hostname("--short");
		    if ($hostname ne "") {
			$new_hostname = menu_getstring("Enter New Hostname (Currently $hostname)");
			if ($new_hostname ne "") {
			    system("sudo $POSDIR/bin/updateos.pl --hostname=$new_hostname");
			    wait_for_user();
			}
		    }
		    else {
			system("/usr/bin/clear");
			print("Error setting hostname: can't get current hostname\n");
			wait_for_user();
		    }

		}

		elsif ($returnval eq "Close") {
			return(0);
		}
	}
}

#
# On Red Hat systems, the steps for changing the hostname are:
# 1) edit /etc/sysconfig/network
# 2) edit /etc/hosts
# 3) run the hostname command
# 4) reboot or at least restart the network service
#

sub network_set_hostname
{
	my $hostname = qx(hostname);

	unless ($hostname) {
		menu_info("Error setting hostname: can't get current hostname");
		return "";
	}

	$hostname = menu_getstring("Enter New Hostname (Currently $hostname)");

	unless ($hostname) {
		menu_info("Set Hostname Cancelled. No Changes Made.");
		return "";
	}

	unless (network_edit_network_file($hostname)) {
		menu_info("Error Setting Hostname: sysconfig network file.");
		return "";
	}

	unless (network_edit_hosts_file($hostname)) {
		menu_info("Error Setting Hostname: hosts file.");
		return "";
	}

	system("sudo hostname $hostname");
	my $strerror = system_exit_status($?);
	if ($strerror) {
		menu_info("Error Setting Hostname: \"hostname\" command error.");
		return "";
	}

	return($hostname);
}

sub network_edit_network_file
{
	my $hostname = $_[0];
	my $current_file = "/etc/sysconfig/network";
	my $saved_file = "${current_file}.orig";
	my $tmpfile = "/tmp/tfsupport.sethostname.$$";

	open(OLDFILE, "< $current_file");
	open(NEWFILE, "> $tmpfile");
	while (<OLDFILE>) {
		if(/^(\s*)(HOSTNAME)(\s*)(=)(\s*)(\S+)/) {
			print(NEWFILE "HOSTNAME=$hostname\n");
		} else {
			print(NEWFILE);
		}
	}
	close(OLDFILE);
	close(NEWFILE);

	# measure of success: the generated file contains something
	if (-s $tmpfile > 0) {
		system("sudo mv $current_file $saved_file");
		system("sudo cp $tmpfile $current_file");
		system("sudo chown root:root $current_file");
		system("sudo chmod 644 $current_file");
		system("sudo rm $tmpfile");
	} else {
		menu_info("Error Setting Hostname: generated file empty.");
		system("rm $tmpfile");
		return(0);
	}

	return(1);
}

sub network_edit_hosts_file
{
	my $hostname = $_[0];
	my $current_file = "/etc/hosts";
	my $saved_file = "${current_file}.orig";
	my $tmpfile = "/tmp/tfsupport.sethostname.$$";

	open(OLDFILE, "< $current_file");
	open(NEWFILE, "> $tmpfile");
	while (<OLDFILE>) {
		if (/^127.0.0.1[ \t]+/) {
			print(NEWFILE "127.0.0.1\t$hostname localhost.localdomain localhost\n");
		} else {
			print(NEWFILE);
		}
	}
	close(OLDFILE);
	close(NEWFILE);

	# measure of success: the generated file contains something
	if (-s $tmpfile > 0) {
		system("sudo mv $current_file $saved_file");
		system("sudo cp $tmpfile $current_file");
		system("sudo chown root:root $current_file");
		system("sudo chmod 644 $current_file");
		system("sudo rm $tmpfile");
	} else {
		menu_info("Error Setting Hostname: generated file empty.");
		system("rm $tmpfile");
		return(0);
	}

	return(1);
}

sub linux_main
{
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $title = "Linux Menu";
	my $user = "";
	my $runlevel = "";
	my $logfile = "";

	while(1) {

		$title = titlestring("Linux Menu");


		# Which version of Linux?
		open(FILE, "< /etc/redhat-release");
		while(<FILE>) {
			chomp;
			if(/Linux/) {
				$title .= "$_\\n";
			}
		}
		close(FILE);


		# Which version of Linux?
		open(UNAME, "uname --kernel-release --processor |");
		while(<UNAME>) {
			chomp;
			if("$_" ne "") {
				$title .= "Kernel: $_\\n";
			}
		}
		close(UNAME);


		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";

		$command .= " \"Halt\"" . " \"Halt the Server\"";
		$command .= " \"Reboot\"" . " \"Reboot the Server.\"";
		$command .= " \"Red Hat Updates\"" . " \"Apply Red Hat OS Updates\"";
		$command .= " \"OSTools Update\"" . " \"Update Teleflora OSTools Package\"";
		$command .= " \"Uptime\"" . " \"Server Uptime / Reboot History\"";
		$command .= " \"Top\"" . " \"Running Processes (Top)\"";
		$command .= " \"Advanced\"" . " \"Advanced Tools\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(OSDIALOG, "$command |");
		$returnval = <OSDIALOG>;
		close(OSDIALOG);
		next if(! $returnval);
		chomp($returnval);


		if($returnval eq  "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);



		} elsif($returnval eq "Halt") {
			my %options = ();
			my $when = "";
			$options{"Now"} = "Halt Immediately.";
			$options{"1 Minute"} = "Halt in One Minute.";
			$options{"5 Minutes"} = "Halt in Five Minutes.";
			$options{"Cancel"} = "Don't Halt. Cancel Current Halt.";
			$when = menu_pickone("Halt the Linux Server?", \%options, "Now");
			if ("$when" eq "Now") {
				system("sudo /sbin/shutdown -h now");
			} elsif ("$when" eq "1 Minute") {
				system("sudo /sbin/shutdown -h +1 &");
				wait_for_user();
			} elsif ("$when" eq "5 Minutes") {
				system("sudo /sbin/shutdown -h +5 &");
				wait_for_user();
			} elsif ("$when" eq "Cancel") {
				system("sudo /sbin/shutdown -c");
				wait_for_user();
			} else {
				menu_info("No System Shutdown will occur.");
			}

		} elsif($returnval eq "Reboot") {

			my %options = ();
			my $when = "";
			$options{"Now"} = "Reboot Immediately.";
			$options{"1 Minute"} = "Reboot in One Minute.";
			$options{"5 Minutes"} = "Reboot in Five Minutes.";
			$options{"Cancel"} = "Don't Reboot. Cancel Current Reboot.";
			$when = menu_pickone("When to Reboot?", \%options, "Now");
			if ("$when" eq "Now") {
				system("sudo $POSDIR/bin/updateos.pl --reboot");
				wait_for_user();
			} elsif ("$when" eq "1 Minute") {
				system("sudo /sbin/shutdown -r +1 &");
				wait_for_user();
			} elsif ("$when" eq "5 Minutes") {
				system("sudo /sbin/shutdown -r +5 &");
				wait_for_user();
			} elsif ("$when" eq "Cancel") {
				system("sudo /sbin/shutdown -c");
				wait_for_user();
			} else {
				menu_info("No Reboot will occur.");
			}



		} elsif($returnval eq "Red Hat Updates") {
			$returnval = menu_confirm("Download and Apply Red Hat OS Updates Now?");
			if($returnval eq "Y") {
				system("/usr/bin/clear");
				print "[[ Red Hat Updates - Linux Menu]]\n\n";
				system("sudo $POSDIR/bin/updateos.pl --ospatches");
				wait_for_user();
			}

		} elsif($returnval eq "OSTools Update") {
			$returnval = menu_confirm("Download and Update Teleflora OSTools Package?");
			if($returnval eq "Y") {
				system("sudo $POSDIR/bin/updateos.pl --ostools");
				wait_for_user();
				$returnval = menu_confirm("Re-run the newly-updated admin menus now?");
				if($returnval eq "Y") {
					exec("$POSDIR/bin/tfsupport.pl");
				}
			}

		} elsif($returnval eq "Uptime") {
			system("clear");
			system("last reboot");
			system("uptime");
			wait_for_user();

			
		} elsif($returnval eq "Top") {
			system("top");


		} elsif($returnval eq "Advanced") {
			linux_advanced();

		} elsif($returnval eq "Close") {
			return(0);
		}
	}
}

sub get_def_runlevel
{
    my $runlevel = $EMPTY_STR;

    my $conf_file = tfs_pathto_inittab();
    if (open(my $itabfh, '<', $conf_file)) {
	while (<$itabfh>) {
	    if (/^\s*id:(\d+):/) {
		$runlevel = $1;
		last;
	    }
	}
	close($itabfh);
    }

    return($runlevel);
}

#
# for RHEL5 and RHEL6 systems:
# display the system services that are configured "on" at the
# default runlevel; if the default runlevel can not be determined,
# display all system services.
#
# for RHEL7 systems:
# display the system services that are enabled.
#
# returns
#   1
#
sub linux_advanced_services_menu
{
    if ($OS eq 'RHEL7') {
	my $cmd = 'systemctl --no-pager --no-legend list-unit-files --type service';
	system("$cmd | grep -v disabled | grep -v static | less");
    }

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	my $runlevel = get_def_runlevel();
	if ($runlevel) {
	    system("/sbin/chkconfig --list | grep -v $runlevel:off | less");
	}
	else {
	    system("/sbin/chkconfig --list | less");
	}
    }

    return(1);
}

sub linux_advanced
{
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $title = "Linux Advanced Menu";
	my $user = "";
	my $runlevel = "";
	my $logfile = "";

	while(1) {

		$title = titlestring("Linux Advanced Menu");


		# Which version of Linux?
		open(FILE, "< /etc/redhat-release");
		while(<FILE>) {
			chomp;
			if(/Linux/) {
				$title .= "$_\\n";
			}
		}
		close(FILE);


		# Which version of Linux?
		open(UNAME, "uname --kernel-release --processor |");
		while(<UNAME>) {
			chomp;
			if("$_" ne "") {
				$title .= "Kernel: $_\\n";
			}
		}
		close(UNAME);
				

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";

		if(is_admin_user() != 0) {
			$command .= " \"Commandline\"" . " \"Go to the Linux Shell\"";
		}
		$command .= " \"Red Hat SOS\"" . " \"Create a Red Hat 'SOS' Report\"";
		$command .= " \"Red Hat List\"" . " \"List Available Red Hat Updates\"";
		$command .= " \"FSCK on Reboot\"" . " \"Require Filesystem Check on Reboot\"";
		$command .= " \"Samba Stop\"" . " \"Stop Samba (Network Neighborhood) Shares\"";
		$command .= " \"Samba Start\"" . " \"Start Samba (Network Neighborhood) Shares\"";
		$command .= " \"Samba Status\"" . " \"Samba Share Status\"";
		$command .= " \"Samba Config\"" . " \"Edit Samba Config File\"";
		$command .= " \"IPTables Start\"" . " \"Start IPTables (Linux Firewall)\"";
		$command .= " \"IPTables Stop\"" . " \"Stop IPTables (Linux Firewall)\"";
		$command .= " \"Services\"" . " \"Show Running Services\"";
		$command .= " \"Truncate\"" . " \"Truncate /var/spool/mail/root\"";
		$command .= " \"vmstat\"" . " \"CPU and Swap Status\"";
		$command .= " \"iostat\"" . " \"Disk IO Statistics\"";
		$command .= " \"Messages\"" . " \"/var/log/messages Logs\"";
		$command .= " \"Secure\"" . " \"/var/log/secure Logs\"";
		$command .= " \"Sudo Actions\"" . " \"Monitor Super-User Actions\"";
		$command .= " \"PS\"" . " \"Current Running Processes (PS)\"";
		$command .= " \"Inittab\"" . " \"Edit inittab file\"";
		$command .= " \"dmesg\"" . " \"Recent Kernel Messages\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(OSDIALOG, "$command |");
		$returnval = <OSDIALOG>;
		close(OSDIALOG);
		next if(! $returnval);
		chomp($returnval);


		if($returnval eq  "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);



		} elsif($returnval eq "Red Hat SOS") {
			system("/usr/bin/clear");
			system("sudo /usr/sbin/sosreport");
			wait_for_user();

		} elsif($returnval eq "Red Hat List") {
			# RHWS 5
			if(-f "/usr/bin/yum") {
				system("/usr/bin/clear");
				system("sudo yum clean all");
				system("sudo /usr/bin/yum check-update 2>&1 | less");
			# RHEL 4
			} elsif (-f "/usr/sbin/up2date") {
				system("/usr/bin/clear");
				system("sudo /usr/sbin/up2date --list 2>&1 | less");
			}

		} elsif($returnval eq "FSCK on Reboot") {
			system("echo '-f -v -y' | sudo tee /fsckoptions > /dev/null");
			system("sudo touch /forcefsck");
			$returnval = menu_confirm("Reboot Server Now?");
			if($returnval eq "Y") {
				system("sudo /sbin/shutdown -r now");
				wait_for_user();
			}


		} elsif($returnval eq "Samba Stop") {
			system("/usr/bin/clear");
			if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
			    system("sudo /sbin/service smb stop");
			}
			if ($OS eq 'RHEL7') {
			    system("sudo systemctl stop smb.service");
			}
			wait_for_user();

		} elsif($returnval eq "Samba Start") {
			system("/usr/bin/clear");
			if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
			    system("sudo /sbin/service smb start");
			}
			if ($OS eq 'RHEL7') {
			    system("sudo systemctl start smb.service");
			    system("systemctl status smb.service");
			}
			wait_for_user();

		} elsif($returnval eq "Samba Status") {
			system("/usr/bin/clear");
			my $cmd_prefix = ($OS eq 'RHEL7') ? 'sudo ' : $EMPTY_STR;
			my $cmd = $cmd_prefix . '/usr/bin/smbstatus';
			system("$cmd");
			wait_for_user();

		} elsif($returnval eq "Samba Config") {
			system("sudo rvim /etc/samba/smb.conf");

		} elsif($returnval eq "IPTables Start") {
			system("/usr/bin/clear");
			if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
			    system("sudo /sbin/service iptables start");
			}
			if ($OS eq 'RHEL7') {
			    system("sudo systemctl start iptables.service");
			    system("systemctl status iptables.service");
			}
			wait_for_user();

		} elsif($returnval eq "IPTables Stop") {
			system("/usr/bin/clear");
			if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
			    system("sudo /sbin/service iptables stop");
			}
			if ($OS eq 'RHEL7') {
			    system("sudo systemctl stop iptables.service");
			}
			wait_for_user();


		} elsif($returnval eq "dmesg") {
			system("dmesg | less");

		} elsif($returnval eq "Inittab") {
			system("sudo rvim /etc/inittab");

		} elsif($returnval eq "vmstat") {
			system("/usr/bin/clear");
			system("vmstat 2 15");
			wait_for_user();

		} elsif($returnval eq "iostat") {
			system("/usr/bin/clear");
			system("iostat 2 15");
			wait_for_user();

		} elsif($returnval eq "Messages") {
			viewfiles("/var/log/messages*", "sudo");

		} elsif($returnval eq "Truncate") {
			system("/usr/bin/clear");
			advanced_truncate_root_mbox();
			wait_for_user();
		}

		elsif ($returnval eq "Secure") {
		    $command = viewfiles("/var/log/secure*", "sudo");
		    if ($command ne "") {
			$returnval = menu_confirm("Send log file to a Printer?", "No");
			if ($returnval eq "Y") {
			    $suboption = choose_printer("Print Security log to which Printer?");
			    if ($suboption ne "") {
				system("$command | $POSDIR/bin/tfprinter.pl --print $suboption");
			    }
			}
		    }
		}

		elsif ($returnval eq "Sudo Actions") {
		    $command = viewfiles("/var/log/secure*", "sudo", "grep sudo");
		    if ($command ne "") {
			$returnval = menu_confirm("Send log file to a Printer?", "No");
			if ($returnval eq "Y") {
			    $suboption = choose_printer("Print Security log to which Printer?");
			    if ("$suboption" ne "") {
				system("$command | $POSDIR/bin/tfprinter.pl --print $suboption");
			    }
			}
		    }
		}

		elsif ($returnval eq "Services") {
		    system("/usr/bin/clear");
		    linux_advanced_services_menu();
		    wait_for_user();
		}

		elsif ($returnval eq "PS") {
			system("/usr/bin/clear");
			system("ps wwaux | less");
		}

		# Prompt - Commandline.
		elsif ($returnval eq "Commandline") {
			system("/usr/bin/clear");
			logevent("Begin Shellout to Commandline.");

			set_signal_handlers('DEFAULT');
			system("PS1=\"\[\\u\@\\h\ \\W]\$ \" /bin/bash");
			set_signal_handlers('IGNORE');

			logevent("Finish Shellout to Commandline.");
		}

		elsif($returnval eq "Close") {
			return(0);
		}
	}
}



sub odbc_menu
{
	my @array = ();
	my $printer = "";
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $title = "";
	my $logfile = "";

	while(1) {
		$title = titlestring("ODBC Menu");
		$title .= "\n\n";

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";
		$command .= " \"Server Logs\"" . " \"View Logfile(s) for BBj Data Server.\"";
		$command .= " \"Live Logs\"" . " \"Watch Live Logfile Activity\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(BACKDIALOG, "$command |");
		$returnval = <BACKDIALOG>;
		close(BACKDIALOG);
		next if(! $returnval);
		chomp($returnval);

		if($returnval eq "Server Logs") {
			viewfiles("/var/log/ds.log");

		} elsif($returnval eq "Live Logs") {
			system("sudo tail -f /var/log/ds.log");

		} elsif($returnval eq "Close") {
			return(0);
		}
	}
}


sub printers_main
{
	my @array = ();
	my $printer = "";
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $title = "";
	my $logfile = "";

	while(1) {
		$title = titlestring("Printer Menu");
		$title .= "\n\n";
		$title .= get_printer_status();

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";

		if(-f "$POSDIR/bin/tfprinter.pl") {
			$command .= " \"Add\"" . " \"Add a new Printer\"";
			$command .= " \"Delete\"" . " \"Delete an Existing Printer\"";
			$command .= " \"Queues\"" . " \"View Printer Queues\"";
			$command .= " \"Test\"" . " \"Send Test Page to Printer\"";
		}
		$command .= " \"Kill\"" . " \"Kill a Print Job\"";
		$command .= " \"Restart\"" . " \"Restart Cups\"";
		$command .= " \"Purge Queue\"" . " \"Purge Print Jobs for a Printer\"";
		if(-f "$POSDIR/config/config.bbx") {
			$command .= " \"ConfigBBX\"" . " \"Edit Config.bbx\"";
		}

		$command .= " \"Advanced\"" . " \"Advanced Tools\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(BACKDIALOG, "$command |");
		$returnval = <BACKDIALOG>;
		close(BACKDIALOG);
		next if(! $returnval);
		chomp($returnval);


		if($returnval eq "Add") {
			my $printer = "";
			$printer = add_printer();
			if($printer) {
				$returnval = menu_confirm("Print a Test Page to printer \"$printer\" ?");
				if($returnval eq "Y") {
					test_printer($printer);
				}
			}

		} elsif($returnval eq "Delete") {
			del_printer();

		} elsif($returnval eq "Test") {
			test_printer("");

		} elsif($returnval eq "Kill") {
			kill_printjob();
		}

		elsif ($returnval eq "Restart") {
			system("/usr/bin/clear");
			cups_restart();
			wait_for_user();
		}

		elsif ($returnval eq "Queues") {
			system("/usr/bin/clear");
			if (-f "$POSDIR/bin/tfprinter.pl") {
				system("$POSDIR/bin/tfprinter.pl --list");
			} else {
				show_printer_queues();
			}
			wait_for_user();
		}

		elsif ($returnval eq "ConfigBBX") {
			system("sudo rvim $POSDIR/config/config.bbx");
		}

		# Delete all print jobs for all printers.
		elsif ($returnval eq "Purge Queue") {

			$printer = choose_printer("Which Print Queue to Clear?");
			if(! $printer) {
				menu_info("No Printers Present.");
			}
			if("$printer" ne "") {
				$returnval = menu_confirm("Remove ALL Print Jobs for \"$printer\"?");
				if($returnval eq "Y") {
					system("sudo /usr/bin/cancel -a \"$printer\"");
					show_printer_queues();
				}
			}
		}

		elsif ($returnval eq "Advanced") {
			printers_advanced();
		}

		elsif ($returnval eq "Close") {
			return(0);
		}
	}
}


sub printers_advanced
{
	my @array = ();
	my $printer = "";
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $title = "Advanced Printer Menu";
	my $logfile = "";

	while(1) {
		$title = titlestring("Advanced Printer Menu");
		$title .= "\n\n";
		$title .= get_printer_status();

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";

		if(-d "/usr2/bbx") {
			$command .= " \"Barcode\"" . " \"Send Barcode Font to a Printer\"";
		}
		if(-f "/usr/sbin/lpmove") {
			$command .= " \"Move Jobs\"" . " \"Move ALL Jobs from one printer to another.\"";
		}
		$command .= " \"List Printers\"" . " \"List CUPS Printers\"";
		$command .= " \"Show Jobs\"" . " \"List Jobs for a CUPS Printer\"";
		$command .= " \"Enable\"" . " \"CUPS Enable Printer\"";
		$command .= " \"Disable\"" . " \"CUPS Disable Printer\"";
		$command .= " \"Error\"" . " \"View CUPS Error Logfile\"";
		$command .= " \"Live Logs\"" . " \"Watch Live Logfile Activity\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(BACKDIALOG, "$command |");
		$returnval = <BACKDIALOG>;
		close(BACKDIALOG);
		next if(! $returnval);
		chomp($returnval);


		if($returnval eq "Barcode") {
			$printer = choose_printer("Which Printer Send a Barcode to?");
			if("$printer" ne "") {
				system("lp -d $printer $POSDIR/bbxd/barcode");
			}

		} elsif($returnval eq "Enable") {
			$printer = choose_printer("Which Printer to Enable?");
			if("$printer" ne "") {
				system("sudo /usr/sbin/cupsenable $printer");
			}
		} elsif($returnval eq "Disable") {
			$printer = choose_printer("Which Printer to Disable?");
			if("$printer" ne "") {
				system("sudo /usr/sbin/cupsdisable -r \"$ENV{'USER'} admin menus\" $printer");
			}

		}

		elsif ($returnval eq "Move Jobs") {
			my $srcprinter = "";
			my $destprinter = "";
			$srcprinter = choose_printer("Move Jobs FROM which Printer?");
			if ($srcprinter ne "") {
				$destprinter = choose_printer("Move Jobs TO which Printer?");
				if ($destprinter ne "") {
					system("/usr/bin/clear");
					system("sudo /usr/sbin/lpmove $srcprinter $destprinter");
					wait_for_user();
				}
			}
		}

		elsif ($returnval eq "List Printers") {
			system("/usr/bin/clear");
			system("lpstat -v | less");
		}

		elsif ($returnval eq "Show Jobs") {
			printers_advanced_show_jobs();
		}

		elsif ($returnval eq "Error") {
			viewfiles("/var/log/cups/error_log*", "sudo");
		}

		elsif ($returnval eq "Live Logs") {
		    my @cups_logs = qw(
			/var/log/cups/access_log
			/var/log/cups/error_log
			/var/log/cups/page_log
		    );

		    my @existing_cups_logs = ();
		    foreach (@cups_logs) {
			push(@existing_cups_logs, $_) if (-f $_);
		    }

		    system("/usr/bin/clear");

		    if (@existing_cups_logs) {
			print("About to run \"tail -f\" on these CUPS log files:\n");

			foreach (@existing_cups_logs) {
			    print("\t$_\n") if (-f $_);
			}

			print("\n");
			print("Hit ^C to exit from \"tail -f\" command\n");
			print("\n");
			wait_for_user();

			system("/usr/bin/clear");
			set_signal_handlers('DEFAULT');
			system("sudo tail -f @existing_cups_logs");
			set_signal_handlers('IGNORE');
		    }
		    else {
			print("No CUPS log files present - shouldn't happen!\n");
			wait_for_user();
		    }
		}

		elsif ($returnval eq "Close") {
			return(0);
		}
	}
}


sub printers_advanced_show_jobs
{
    my $printer = choose_printer("Select a printer");
    if ($printer ne "") {
	my $tmpfile = make_tempfile("tfsupport.pl");
	system("lpstat -o $printer > $tmpfile");

	system("/usr/bin/clear");
	if (-s $tmpfile) {
	    system("less $tmpfile");
	}
	else {
	    print "No jobs to display\n";
	    wait_for_user();
	}
	system("rm $tmpfile");
    }
}


sub add_printer
{
	my $interface_type = "";
	my $printer_type = "";
	my $ipaddress = "";
	my %options = ();
	my $printer = "";
	my $username = "";
	my $password = "";
	my $workgroup = "";
	my $share = "";
	my $tfprinter_cmd = "$POSDIR/bin/tfprinter.pl";
	my $tfprinter_opts = "";

	# What type of interface?
	$options{"Auto"} = "Automatically Detect";
	$options{"Jetdirect"} = "HP Jetdirect (Network) Printers";
	$options{"LPD"} = "LPD (Network) Printer";
	$options{"Windows"} = "Printer Attached to a Windows PC";
	$options{"Parallel"} = "Printer Connected to Parallel Port.";
	$interface_type = menu_pickone("What type of interface?", \%options, "Auto");
	return("") if (! $interface_type);


	# What kind of printer?
	if ($POSDIR eq $DAISYDIR) {
	    %options = ();
	    $options{"raw"} = "Raw Print Queue";
	    $options{"PCL"} = "HP LaserJet 4200 PCL Printer";
	    $options{"PostScript"} = "Dell 5200 PostScript Printer";
	    $printer_type = menu_pickone("What kind of printer?", \%options, "raw");
	}
	elsif ($POSDIR eq $RTIDIR) {
	    $printer_type = "raw";
	}
	else {
	    # no POS installed, assume raw
	    $printer_type = "raw";
	}
	return("") if(! $printer_type);


	my $ppd_arg = "";
	if ($printer_type eq "PCL") {
		$ppd_arg = "--ppd=hplj4200.ppd";
	} elsif ($printer_type eq "PostScript") {
		$ppd_arg = "--ppd=dell5200.ppd";
	}
	$tfprinter_opts = $ppd_arg;

	#
	# Warn the user about special chars not allowed in printer names.
	#
	my $printer_name_title = "Printer Name?";
	$printer_name_title .= "\nNames may not contain SPACE, TAB, /, or #";

	if( ("$interface_type" eq "Auto") 
	||  ("$interface_type" eq "LPD")
	||  ("$interface_type" eq "Jetdirect") ) {

		$printer = menu_getstring($printer_name_title);
		return("") if (! $printer);
		$ipaddress = menu_getstring("IP Address or Device Name?");
		return("") if (! $ipaddress);


		# LPD Printer
		if ("$interface_type" eq "LPD") {
			$tfprinter_opts .= " --lpd --add $printer:$ipaddress";
			$share = menu_getstring("Windows 7 LPD Printer Share Name? (Optional)");
			if ($share ne "") {
				$tfprinter_opts .= " --share=\"$share\"";
			}

		# Jetdirect Printer
		} elsif ("$interface_type" eq "Jetdirect") {
			$tfprinter_opts .= " --jetdirect --add $printer:$ipaddress";

		# Auto Detect
		} else {
			$tfprinter_opts .= " --add $printer:$ipaddress";
		}

	# Samba Printer
	} elsif ("$interface_type" eq "Windows") {
		$printer = menu_getstring($printer_name_title);
		return("") if (! $printer);

		$ipaddress = menu_getstring("IP Address?");
		if("$ipaddress" !~ /(\d+)(\.)(\d+)(\.)(\d+)(\.)(\d+)/) {
			return("");
		}
 
		$username = menu_getstring("Username? (Optional)");
		if("$username" ne "") {
			$username = " --user=\"$username\"";

			$password = menu_getstring("Password? (Optional)");
			if("$password" ne "") {
				$password = " --password=\"$password\"";
			}
		}
		$workgroup = menu_getstring("Windows Workgroup?");
		if("$workgroup" ne "") {
			$workgroup = " --workgroup=\"$workgroup\"";
		}

		$share = menu_getstring("Windows Printer Share?");
		if("$share" ne "") {
			$share = " --share=\"$share\"";
		}
		$tfprinter_opts .= " --add $printer:$ipaddress";
		$tfprinter_opts .= " --samba $username $password $share $workgroup";

	} elsif ("$interface_type" eq "Parallel") {
		$printer = menu_getstring($printer_name_title);
		return("") if (! $printer);

		$tfprinter_opts .= " --add $printer:/dev/lp0";
	}

	#
	# Now that the info is gathered, the printer can actually be added.
	# The tfprinter.pl script will output a message about the status
	# of adding the printer, so do a wait so the user can see the
	# status message.
	#
	system("sudo $tfprinter_cmd $tfprinter_opts");
	wait_for_user();

	return($printer);
}

sub del_printer
{
	my $printer = "";

	$printer = choose_printer("Which Printer to Delete?");
	if ("$printer" ne "") {
		system("sudo $POSDIR/bin/tfprinter.pl --delete $printer");
		wait_for_user();
	}
}

sub test_printer
{
	my $the_choice = $_[0];
	my $printer_script = "$POSDIR/bin/tfprinter.pl";
	my @output = ();
	my %printers = ();
	my %options = ();
	my $title = "Choose Printer to Send Test Page";

	unless (-f $printer_script) {
		menu_info("Printer script missing: $printer_script.");
		return;
	}

	if (! defined($the_choice) || $the_choice eq "") {
		#
		# output from "tfprinter.pl --list" looks like:
		#	"printer_name" \s \t "(n" \s "Jobs)" \n
		#
		open(PIPE, "$printer_script --list |");
		while(<PIPE>) {
			chomp;
			@output = split(/\s+/);
			next if ($output[0] eq "null");
			# kill leading open paren
			$output[1] =~ s/^\(//;
			# key = printer name, value = q size
			$printers{$output[0]} = $output[1];
		}
		close(PIPE);

		unless (scalar(keys(%printers)) > 0) {
			menu_info("No Printers Configured.");
			return;
		}

		#
		# fill out list of printers for the menu_pickone() function.
		#
		foreach (sort(keys(%printers))) {
			$options{$_} = "";
		}

		$the_choice = menu_pickone($title, \%options, "");
	}

	if ($the_choice eq "") {
		return;
	}

	my $test_page = "/tmp/tfsupport.test.page.$$";
	my $hostname = get_hostname("--long");
	my $localtime = strftime("%a %B %d, %Y %T %Z", localtime());
	my $username = getpwuid($<);
	my $ttyname = qx(tty);
	chomp($ttyname);
	my $printer_type = get_printer_type($the_choice);
	my $cups_file_count = get_cups_file_count();
	my $cups_free_space = get_cups_free_space();
	my $pos_version = get_pos_version();
	my $linux_version = get_linux_version();
	my $cups_version = get_cups_version();
	my $tfsupport_version = get_script_version("tfsupport");
	my $tfprinter_version = get_script_version("tfprinter");

	open(TP, "> $test_page");
	print TP "=================================\r\n";
	print TP "P R I N T E R   T E S T   P A G E\r\n";
	print TP "=================================\r\n";
	print TP "\r\n";
	print TP "time: $localtime\r\n";
	print TP "\r\n\r\n";
	print TP "---------------------------------\r\n";
	print TP "      S Y S T E M    I N F O     \r\n";
	print TP "---------------------------------\r\n";
	print TP "\r\n";
	print TP "server hostname: $hostname\r\n";
	print TP "user: $username\r\n";
	print TP "tty: $ttyname\r\n";
	print TP "\r\n\r\n";
	print TP "---------------------------------\r\n";
	print TP "     P R I N T E R   I N F O     \r\n";
	print TP "---------------------------------\r\n";
	print TP "\r\n";
	print TP "printer: $the_choice\r\n";
	print TP "printer queue size: $printers{$the_choice}\r\n";
	print TP "printer type: $printer_type\r\n";
	print TP "cups file count: $cups_file_count\r\n";
	print TP "cups free space: $cups_free_space\r\n";
	print TP "\r\n\r\n";
	print TP "---------------------------------\r\n";
	print TP "     V E R S I O N   I N F O     \r\n";
	print TP "---------------------------------\r\n";
	print TP "\r\n";
	print TP "POS version: $pos_version\r\n";
	print TP "Linux version: $linux_version\r\n";
	print TP "CUPS version: $cups_version\r\n";
	print TP "Support Menu version: $tfsupport_version\r\n";
	print TP "Printer Util version: $tfprinter_version\r\n";
	close(TP);

	system("/usr/bin/clear");
	system("cat $test_page | $printer_script --print $the_choice");
	system("cat $test_page");
	system("rm -f $test_page");
	wait_for_user();

}


sub get_printer_status
{
	my $message = "";

	# Is cups service running?
	my $is_running = get_system_service_status("cups");
	$message .= "CUPS System Service is ";
	$message .= "NOT " unless ($is_running);
	$message .= "running.\\n";

	# Is cups listening on TCP Port?
	my $found = 0;
	my $cmd = 'netstat -plan 2> /dev/null';
	if (open(my $pipefh, '-|', $cmd)) {
	    while(<$pipefh>) {
		if(/(\d+\.\d+\.\d+\.\d+:631)([[:print:]]+)(LISTEN)/) {
		    $found = 1;
		    last;
		}
	    }
	    close($pipefh);
	}
	else {
	    logevent("[get printer status] could not open pipe to: $cmd");
	}
	if ($found == 0) {
	    $message .= "CUPS Printer Daemon is NOT LISTENING on TCP port.\\n";
	}

	# How many files in /var/spool/cups/tmp? 
	my $jobs = get_cups_file_count();
	if ($jobs > 1000) {
	    $message .= "$jobs jobs in /var/spool/cups/tmp\\n";
	}

	return($message);
}

#
# Show "lpq" for each and every printer.
#
sub show_printer_queues
{
	my @array = ();
	my @printers = ();
	my $printer = "";
	my $command = "";
	my $i = 0;


	# Which printers are present?
	# What are their queue counts.
	open(PRINTERS, "lpstat -a |");
	while(<PRINTERS>) {
		@array = split(/[[:space:]]+/);
		$printer = $array[0];
		next if("$printer" eq "");
		push(@printers, "$printer");
	}
	close(PRINTERS);

	# We did not find a printer. This is odd.
	if($#printers < 0) {
		system("echo \"No Printers Found.\" | less");
		return(0);
	}

	$command = "(date ";
	$command .= " ; sudo lpq -P $printers[0]";
	for ($i = 1; $i <= $#printers; $i++) {
		$command .= " ; /bin/echo";
		$command .= " ; /bin/echo";
		$command .= " ; sudo lpq -P $printers[$i]";
	}
	$command .= ") | less";

	system("$command");

	return(0);
}


#
# Request a job ID, and then kill that.
#
sub kill_printjob
{
	my $command = "";
	my $returnval = "";
	my $printer = "";
	my $user = "";
	my $line = "";
	my %printers = ();
	my %printjobs = ();
	my @array = ();


	# Expected output:
	#
	#Rank    Owner   Job     File(s)                         Total Size
	#active  daffentr23592   (stdin)                         2048 bytes
	#1st     daffentr23593   (stdin)                         2048 bytes
	#2nd     daffentr23594   (stdin)                         2048 bytes
	#
	# Which printers are present?
	# What are their queue counts.
	if (open(my $qfh, "lpq -a |")) {
	    while(<$qfh>) {
		next if (/Total Size/);
		chomp;
		$line = $_;
		$user = substr($line, 8,8);
		my $jobnum = substr($line, 16,8);
		next if ("$user" eq "");
		$printjobs{$jobnum}{"user"} = $user;
		$printjobs{$jobnum}{"jobnum"} = $jobnum;
	    }
	    close($qfh);
	}


	$command = "dialog --separate-output --stdout";
	$command .= " $TIMEOUT_MENU_ARG";
	$command .= " --title 'Kill Which Print Jobs?'";
	$command .= " --checklist 'Select which print jobs to kill.'";
	$command .= " 0 0 0";
	foreach my $jobnum (sort(keys(%printjobs))) {
		$command .= " " . "\"$jobnum\" \"User $printjobs{$jobnum}{'user'} \" \"off\"";
	}


	@array = ();
	open(DIALOG, "$command |");
	while(<DIALOG>) {
		chomp;
		$returnval = $_;
		$returnval =~ s/\s+//g; # Strip leading and trailing spaces.
		if("$returnval" eq "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);
		}
		push(@array, $returnval);
	}
	close(DIALOG);



	if($#array < 0) {
		menu_info("No Print Job Specified.");
		return(0);
	}

	system("/usr/bin/clear");
	foreach my $jobnum(@array) {
		system("sudo /usr/bin/cancel $jobnum");
	}

	menu_info("Print Job(s) Killed.");
}



#
# Choose one printer from a list of printers.
#
sub choose_printer
{
	my $title = $_[0];
	my @printers = ();
	my $printer = "";
	my $command = "";

	#
	# First, form a dialog command with list of printers
	#
	$command = "dialog --stdout";
	$command .= " $TIMEOUT_MENU_ARG";
	$command .= " --menu '$title'";
	$command .= " 0 0 0";

	#
	# Which printers are present?
	#
	# NOTE: be careful, lpstat can return blank lines.
	#
	open(PRINTERS, "lpstat -a |");
	while (<PRINTERS>) {
	    next if (/^$/);
	    @printers = split(/[[:space:]]+/);
	    $printer = $printers[0];
	    next if ($printer eq "");
	    $command .= " \"$printer\" \"$printer\"";
	}
	close(PRINTERS);

	#
	# convenience - give user choice of no printer
	#
	$command .= " \"null\" \"don't print\"";

	#
	# Now, run the dialog command
	#
	# Redirect stderr to stdout so that we can tell if there was a timeout
	# since 'dialog' writes "timeout" to stderr and exits if a timeout happens.
	$printer = qx($command 2>&1);

	if ($printer ne "") {

	    # Remove trailing and leading newlines because if there was a timeout,
	    # the form of the output is:
	    #	^\ntimeout\n$
	    chomp($printer);
	    $printer =~ s/^\n//;

	    if ($printer eq "timeout") {
		logevent("Inactivity Timeout");
		exit(0);
	    }

	    if ($printer eq "null") {
		$printer = "";
	    }
	}

	return($printer);
}


sub get_printer_type
{
	my $printer_name = $_[0];
	my $device = "";

	return ($printer_name) if ($printer_name eq "null");
	return ($printer_name) if ($printer_name eq "screen");

	#
	# Expecting the output of the "lpstat -v" to look like this:
	#
	# $ lpstat -v
	# device for printer1: socket://192.168.10.52/
	# device for hppcl: ipp://192.168.1.52/
	# device for dell5210: ipp://192.168.10.52/
	#

	open(PIPE, "lpstat -v |");
	while(<PIPE>) {
		if (/^device for $printer_name:/) {
			$device = (split(/\s+/))[3];
		}
	}
	close(PIPE);

	return($device);
}


# How many files in /var/spool/cups/tmp? 
sub get_cups_file_count
{
	my $cups_file_count = 0;

	open(PIPE, "sudo /usr/bin/find /var/spool/cups/tmp -type f -print |");
	while(<PIPE>) {
		$cups_file_count++;
	}
	close(PIPE);

	return($cups_file_count);
}

sub get_cups_free_space
{
	my @df_values = ();

	open(PIPE, "sudo df -Ph /var/spool/cups |");
	while(<PIPE>) {
		next if (/^Filesystem/);
		chomp;
		@df_values = split(/\s+/);
	}
	close(PIPE);

	return($df_values[3]);
}


sub cups_accept_all
{
    my $rc = 1;

    if (open(my $pfh, '-|', "$POSDIR/bin/tfprinter.pl --list")) {
	while(<$pfh>) {
	    chomp;
	    my ($printer, $fodder) = split(/\s+/);
	    print("Accepting jobs on printer: $printer\n");
	    my $cmd = '/usr/sbin/accept';
	    if ($OS eq 'RHEL7') {
		$cmd = '/sbin/cupsaccept';
	    }
	    system("sudo $cmd $printer > /dev/null 2> /dev/null");
	}
	close($pfh);
    }
    else {
	$rc = 0;
    }

    return($rc);
}


sub cups_restart
{
    if ($OS eq 'RHEL7') {
	system("sudo systemctl stop cups.service");
	system("sudo $POSDIR/bin/updateos.pl --cupstmp");
	system("sudo systemctl start cups.service");
    }

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	system("sudo /sbin/service cups stop");
	system("sudo $POSDIR/bin/updateos.pl --cupstmp");
	system("sudo /sbin/service cups start");
    }

    # Need to run 'accept' on every single printer
    cups_accept_all();

    return(1);
}


# Pick a user from the results of "rtiuser.pl".
sub users_menu_choose
{
	my $title = $_[0];
	my $command = "";
	my $returnval = "";
	my $userscript = "";
	my @array = ();


	# Where is our 'xxxuser.pl' script?
	foreach("$POSDIR/bin/rtiuser.pl", "$POSDIR/bin/dsyuser.pl", "/d/daisy/dsyuser.pl", "/usr2/bbx/bin/rtiuser.pl") {
		next until -f $_;
		$userscript = $_;
		last;
	}
	if("$userscript" eq "") {
		print("rtiuser.pl or dsyuser.pl scripts not found on this system.");
		wait_for_user();
		return;
	}


	$command = "dialog --stdout";
	$command .= " $TIMEOUT_MENU_ARG";
	$command .= " --menu '$title'";
	$command .= " 0 0 0";

	# Create a list of all users who could be unlocked.
	open(PIPE, "$userscript --list | grep User | sort |");
	while(<PIPE>) {
		chomp;
		@array = split(/[[:space:]]+/);

		#
		# The output from the xxxusers.pl --list can be up to 5 elements.
		# For example, with a Daisy non-admin user, there would be:
		#	daisy (Daisy User)                    <-- 3 space separated elements
		# With a Daisy admin user, there would be:
		#	daisy (Daisy User) (Daisy Admin)      <-- 5 space separated elements

		if (@array) {
			$command .= " \"$array[0]\"";
			for (my $i = 1; $i <= 4; $i++) {
				if (defined($array[$i])) {
					$command .= " ";
					$command .= "\"" if ($i == 1);
					$command .= "$array[$i]";
				} else {
					last;
				}
			}
			$command .= "\"" if ($#array > 0);
		}
	}
	close(PIPE);

	#
	# SPECIAL CASE:
	# If this function was called by Support Menu -> Users -> ResetPW, then
	# add "root" as one of the users eligible to have it's password reset.
	#

	if ($title eq "Which User to Reset Password?") {
		$command .= " \"root\" \"root user\"";
	}

	open(USERCHOOSE, "$command |");
	$returnval = <USERCHOOSE>;
	close(USERCHOOSE);
	next if(! $returnval);
	chomp($returnval);


	if($returnval eq "timeout") {
		logevent("Inactivity Timeout.");
		exit(0);
	}


	return($returnval);
}



sub rti_menu
{
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $title = "RTI Application Menu";
	my $user = "";
	my $logfile = "";

	while(1) {

		$title = titlestring("RTI Application Menu");

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";
		$command .= " \"Killem\"" . " \"Stop RTI Background Processes.\"";
		$command .= " \"Startbbx\"" . " \"Restart RTI Background Processes.\"";
		$command .= " \"Checkit\"" . " \"RTI Background Process Status.\"";
		$command .= " \"RTI\"" . " \"Run RTI as current user\"";
		$command .= " \"CC Log\"" . " \"Credit Card (TCC) Logfile.\"";
		$command .= " \"DoveOut Log\"" . " \"Logfile for outbound Dove Txns.\"";
		$command .= " \"Doveserver Log\"" . " \"Logfile for inbound Dove Txns.\"";
		if(-f "$POSDIR/bin/killterms.pl") {
			$command .= " \"Killterms\"" . " \"Kill stuck terminals.\"";
		}
		$command .= " \"Advanced\"" . " \"Advanced Tools.\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(BACKDIALOG, "$command |");
		$returnval = <BACKDIALOG>;
		close(BACKDIALOG);
		next if(! $returnval);
		chomp($returnval);


		if($returnval eq "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);

		} elsif($returnval eq "RTI") {
			system("TERM=ansi $POSDIR/bin/sshbbx");

		} elsif($returnval eq "Checkit") {
			system("clear");
			system("$POSDIR/bin/checkit | less");

		} elsif($returnval eq "Killem") {
			my @progs = ();

			# Let user pick which Background programs to stop.
			@progs = choose_rtibackgr();
			if(@progs) {
				$returnval = menu_confirm("Stop RTI Background Processes?", "No");
				if($returnval eq "Y") {
					system("clear");
					if(grep(/^All$/, @progs)) {
						system("sudo $POSDIR/bin/killem");
					} else {
						system("sudo $POSDIR/bin/killem @progs");
					}
					system("$POSDIR/bin/checkit");
					wait_for_user();
				}
			}

		} elsif($returnval eq "Startbbx") {
			my @progs = ();

			# Let user pick which Background programs to start.
			@progs = choose_rtibackgr();
			if(@progs) {
				$returnval = menu_confirm("Start RTI Background Processes?", "No");
				if($returnval eq "Y") {
					system("clear");
					if(grep(/^All$/, @progs)) {
						system("sudo $POSDIR/bin/startbbx");
					} else {
						system("sudo $POSDIR/bin/startbbx @progs");
					}
					system("$POSDIR/bin/checkit");
					wait_for_user();
				}
			}

		} elsif($returnval eq "DoveOut Log") {
			viewfiles("$POSDIR/log/callout-*.log");

		} elsif($returnval eq "Doveserver Log") {
			viewfiles("$POSDIR/log/doveserver-*.log");

		} elsif($returnval eq "CC Log") {
			viewfiles("$POSDIR/log/tcc*.log");

		} elsif($returnval eq "Killterms") {
			system("sudo $POSDIR/bin/killterms.pl --nobbterm");
			wait_for_user();

		} elsif($returnval eq "Advanced") {
			rti_advanced();

		} elsif($returnval eq "Close") {
			return(0);
		}
	}
}


sub rti_advanced
{
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $user = "";
	my $logfile = "";

	while(1) {

		my $title = titlestring("RTI Advanced Menu");

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";
		$command .= " \"RTI as User\"" . " \"Run RTI as another user.\"";
		$command .= " \"Edit RTI.ini\"" . " \"Edit conf file RTI.ini.\"";
		$command .= " \"Edit rtiBackgr\"" . " \"Edit conf file rtiBackgr.\"";
		$command .= " \"Basis Logs\"" . " \"Basis License Manager Logs.\"";
		$command .= " \"Fax Logs\"" . " \"RTI-Sendfax Logs.\"";
		$command .= " \"Fax Queue\"" . " \"Queue of items to be Faxed.\"";
		$command .= " \"Fax Unlock\"" . " \"Remove Fax Lock.\"";
		$command .= " \"Patchlog\"" . " \"View RTI Patch Logfile.\"";
		$command .= " \"Dove Stop\"" . " \"Stop the Dove server process.\"";
		$command .= " \"Dove Start\"" . " \"Start the Dove server process.\"";
		$command .= " \"Dove Status\"" . " \"Display Dove server process status.\"";
		$command .= " \"BBj Stop\"" . " \"Stop the BBj service.\"";
		$command .= " \"BBj Start\"" . " \"Start the BBj service.\"";
		$command .= " \"BBj Status\"" . " \"Display BBj service status.\"";
		$command .= " \"Permissions\"" . " \"Reset Permissions on All RTI Files.\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		open(BACKDIALOG, "$command |");
		$returnval = <BACKDIALOG>;
		close(BACKDIALOG);
		next if(! $returnval);
		chomp($returnval);


		if($returnval eq "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);
		}

		elsif ($returnval eq "RTI as User") {
			$returnval = users_menu_choose("Choose RTI User");
			if($returnval ne "") {
				system("TERM=ansi sudo -u $returnval $POSDIR/bin/sshbbx");
			}
		}

		elsif ($returnval eq "Edit RTI.ini") {
			system("/usr/bin/clear");
			system("sudo vi /usr2/bbx/bbxd/RTI.ini");
			wait_for_user();
		}

		elsif ($returnval eq "Edit rtiBackgr") {
			system("/usr/bin/clear");
			system("sudo vi /usr2/bbx/config/rtiBackgr");
			wait_for_user();
		}

		elsif ($returnval eq "Fax Logs") {
			viewfiles("$POSDIR/log/rti_sendfax-*.log");
		}

		elsif ($returnval eq "Fax Queue") {
			system("/usr/bin/clear");
			system("$POSDIR/bin/rti_sendfax.pl --list | less");
		}

		elsif ($returnval eq "Fax Unlock") {

			system("/usr/bin/clear");

			#
			# Since the rtisendfax.pl script is maintained by
			# another group, (effectively) we can't make changes.
			# So the code below "borrows" the knowledge of the path
			# to the lock file... thus, the code could break at any time.
			#
			my $lockdir = "/var/lock";
			my $rtisendfax_lock_file = "rtisendfax.lock";
			my $rtisendfax_lock_path = "$lockdir/$rtisendfax_lock_file";
			if (-e $rtisendfax_lock_path) {
			    print "Calling \"rti_sendfax.pl --unlock\" to remove lock\n";
			    system("$POSDIR/bin/rti_sendfax.pl --unlock");
			    unless (-e $rtisendfax_lock_path) {
				print "Successfully removed lock\n";
			    }
			    else {
				print "Error: could not remove lock: $rtisendfax_lock_path\n";
			    }
			}
			else {
			    print "No locks to remove\n";
			}

			wait_for_user();

		}

		elsif ($returnval eq "Basis Logs") {
			viewfiles("/usr2/basis/blm/log/blm.log*");
		}

		elsif ($returnval eq "Patchlog") {
			viewfiles("$POSDIR/log/RTI-Patches.log");
		}

		elsif ($returnval eq "Dove Stop") {
			system("/usr/bin/clear");
			system("sudo $POSDIR/bin/doveserver.pl --stop");
			wait_for_user();
		}

		elsif ($returnval eq "Dove Start") {
			system("/usr/bin/clear");
			system("sudo $POSDIR/bin/doveserver.pl --start");
			wait_for_user();
		}

		elsif ($returnval eq "Dove Status") {
			system("/usr/bin/clear");
			system("sudo $POSDIR/bin/doveserver.pl --status");
			wait_for_user();
		}

		elsif ($returnval eq "BBj Stop") {
			my $confirm_msg = "\
All users will be logged out and all background processes will be killed. \
Are you sure you want to continue?";
		 	$returnval = menu_confirm($confirm_msg, "No");
			if ($returnval eq "Y") {
			    system("/usr/bin/clear");
			    system("sudo $POSDIR/bin/bbjservice.pl --stop");
			    wait_for_user();
			}
		}

		elsif ($returnval eq "BBj Start") {
			system("/usr/bin/clear");
			system("sudo $POSDIR/bin/bbjservice.pl --start");
			wait_for_user();
		}

		elsif ($returnval eq "BBj Status") {
			system("/usr/bin/clear");
			system("sudo $POSDIR/bin/bbjservice.pl --status");
			wait_for_user();
		}

		elsif ($returnval eq "Permissions") {
			system("/usr/bin/clear");
			system("sudo $POSDIR/bin/rtiperms.pl $POSDIR");
			wait_for_user();
		}

		elsif ($returnval eq "Close") {
			return(0);
		}
	}
}


#
# Choose one or more "background" programs as configured in the "rtiBackgr" config file.
# This primarily used for "killem" and "startbbx".
#
sub choose_rtibackgr
{
	my @progs = ();
	my @array = ();
	my $string = "";
	my $command = "";


	$command = "dialog --stdout";
	$command .= " $TIMEOUT_MENU_ARG";
	$command .= " --checklist 'Choose RTI Background Program'";
	$command .= " 0 0 0";


	# Get a  list of programs from our 'rtiBackgr' file.
	open(RTIBACKGR, "< $POSDIR/config/rtiBackgr");
	$command .= " \"All\" \"All Background Programs\" \"off\"";
	while(<RTIBACKGR>) {
		chomp;
		next if (/^\s*$/);
		next if (/^\s*#.*/);
		$string = $_;
		@array = split(/,/, $string);  # First 'word' of comma separated data.
		$string = $array[0];
		$command .= " \"$string\" \"\" \"off\"";
	}
	close(RTIBACKGR);


	open(DIALOG, "$command |");
	$string = <DIALOG>;
	close(DIALOG);
	return if(! $string);
	chomp($string);
	system("clear");
	foreach ( split(/"/, $string)) {
		next if(! /[[:alnum:]]+/);
		push(@progs, $_);
	}

	if($string eq "timeout") {
		logevent("Inactivity Timeout.");
		exit(0);
	}


	return(@progs);
}


sub daisy_start_menu
{
    system("/usr/bin/clear");

    my $runlevel = get_runlevel();

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	my $DAISY_START_RUNLEVEL = 3;
	if ($runlevel != $DAISY_START_RUNLEVEL) {
	    system("sudo /sbin/init $DAISY_START_RUNLEVEL");

	    logevent("[daisy start menu] runlevel set to: $DAISY_START_RUNLEVEL");
	}
    }

    if ($OS eq 'RHEL7') {
	my @tty_list = qw(
	    getty@tty1
	    getty@tty2
	    getty@tty3
	    getty@tty4
	    getty@tty5
	    getty@tty6
	    getty@tty7
	    getty@tty8
	    getty@tty9
	    getty@tty11
	);

	foreach (@tty_list) {
	    print "starting system service: $_\n";
	    system("sudo systemctl start $_");
	}

	logevent("[daisy start menu] getty\@tty system services started: 1-9, 11");
    }

    wait_for_user();

    return(1);
}

sub daisy_stop_menu
{
    $returnval = menu_confirm("Stop Daisy and all Daisy background processes?", "No");
    if ($returnval eq "Y") {

	system("/usr/bin/clear");

	# revoke cached sudo credentials, ie make them enter password
	system("sudo -k");

	if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	    my $DAISY_STOP_RUNLEVEL = 4;
	    print "[daisy stop menu] setting runlevel to: $DAISY_STOP_RUNLEVEL\n";
	    system("sudo /sbin/init $DAISY_STOP_RUNLEVEL");
	    logevent("[daisy stop menu] runlevel set to: $DAISY_STOP_RUNLEVEL");
	}

	if ($OS eq 'RHEL7') {
	    my @tty_list = qw(
		getty@tty1
		getty@tty2
		getty@tty3
		getty@tty4
		getty@tty5
		getty@tty6
		getty@tty7
		getty@tty8
		getty@tty9
		getty@tty11
	    );

	    foreach my $tty (@tty_list) {
		print "stopping system service $tty\n";
		system("sudo systemctl stop $tty");
	    }

	    logevent("[daisy stop menu] getty\@tty system services stopped: 1-9, 11");
	}

	my $daisy_kill_cmd = "$POSDIR/utils/killemall";
	if (-x $daisy_kill_cmd) {
	    # this daisy script does not provide an exit status
	    print "\n";
	    print "[daisy stop menu] stopping all Daisy processes via: $daisy_kill_cmd\n";
	    system("sudo $daisy_kill_cmd");
	    print "\n";
	    logevent("[daisy stop menu] all Daisy processes stopped");
	}
	else {
	    logevent("[daisy stop menu] Daisy kill processes command does not exist: $daisy_kill_cmd");
	}
    }
    else {
	system("/usr/bin/clear");
	print "[daisy stop menu] Daisy stop cancelled\n";
    }

    wait_for_user();

    return(1);
}

# Return full path to a daisy database dir.
# If "Cancel" selected, return NULL string.

sub daisy_select_db_dir
{
	my %options = ();
	my @daisy_db_dirs = ();
	my $default_db_dir = "/d/daisy";
	my $title = "Choose Daisy DB Directory";

	# first add the default value to the list
	push(@daisy_db_dirs, $default_db_dir);

	# now get any others and add them to the list
	if (open(my $pipefh, '-|', "sudo $POSDIR/bin/tfupdate.pl --list")) {
	    while(<$pipefh>) {
		chomp;
		push(@daisy_db_dirs, $_);
	    }
	    close($pipefh);
	}
	else {
	    print "[select daisy dirs ] could not open pipe to get list of daisy dirs\n";
	    wait_for_user();
	    return("");
	}

	return($default_db_dir) if (@daisy_db_dirs == 1);


	# now fill out the hash for the radio box
	my $filler = "";
	my $counter = 2;
	foreach (@daisy_db_dirs) {
		if (/^$default_db_dir$/) {
			$options{$_} = "Default Daisy DB Directory";
		} else {
			$filler = "second" if ($counter == 2);
			$filler = "third" if ($counter == 3);
			$filler = "fourth" if ($counter == 4);
			$filler = "fifth" if ($counter == 5);
			$filler = "yet another" if ($counter > 5);
			$options{$_} = "$filler Daisy DB Directory";
			$counter++;
		}
	}

	my $the_choice = menu_pickone($title, \%options, $default_db_dir);
	unless (defined($the_choice)) {
		$the_choice = "";
	}

	return ($the_choice);
}


#
# get the lastest Daisy ISO file by downloading from
# the Managed Services web site.
#
# returns
#   on success, path to downloaded ISO file
#   if error, empty string
#

sub daisy_get_iso
{
    my ($iso_name) = @_;

    my $daisy_iso_path = $EMPTY_STR;

    if ($iso_name) {
	my $iso_url = $TFSERVER_DAISY_URL . $iso_name;
	my $iso_path = File::Spec->catdir('/tmp',  $iso_name);
	logevent("[daisy get iso] downloading Daisy ISO...");
	logevent("[daisy get iso] server URL: $TFSERVER_DAISY_URL");
	logevent("[daisy get iso] ISO name: $iso_name");
	system("curl -f -o $iso_path $iso_url");
	if ($? == 0) {
	    logevent("[daisy get iso] Daisy ISO downloaded to: $iso_path");
	    $daisy_iso_path = $iso_path;
	}
	else {
	    logevent("[daisy get iso] could not download Daisy ISO: $iso_url");
	}
    }

    return($daisy_iso_path);
}

#
# update the version of daisy in the daisy database dir
# specified in the first argument.
# the iso file to use for the update has already been
# downloaded and is specified in the second argument.
#
# a: mount iso
# b: run daisy install script
# c: umount iso
#
# returns
#   1 on success
#   0 if error
#
sub daisy_update_software
{
    my ($daisy_dir, $daisy_iso) = @_;

    my $rc = 1;

    unless (-d $DEF_DAISY_UPDATE_MNT_POINT) {
	system("mkdir $DEF_DAISY_UPDATE_MNT_POINT");
	logevent("[daisy update software] performed mkdir of mount point: $DEF_DAISY_UPDATE_MNT_POINT");
    }
    unless (-d $DEF_DAISY_UPDATE_MNT_POINT) {
	logevent("[daisy update software] could not mkdir mount point: $DEF_DAISY_UPDATE_MNT_POINT");
	return(0);
    }

    system("sudo mount -o loop $daisy_iso $DEF_DAISY_UPDATE_MNT_POINT");
    system("sudo perl $DEF_DAISY_UPDATE_MNT_POINT/install-daisy.pl $daisy_dir");
    $rc = 0 if ($? != 0);
    system("sudo umount $DEF_DAISY_UPDATE_MNT_POINT");

    return($rc);
}

#
# update the daisy software in the default daisy database dir.
#
# a: download the latest daisy iso
# b: get confirmation from user
# c: attempt update
# d: report
#
# returns
#   1 on success
#   0 if error
#
sub daisy_update_software_menu
{
    system("/usr/bin/clear");

    my $daisy_iso = $EMPTY_STR;
    my $returnval = menu_confirm('Download lastest Daisy ISO', 'Yes');
    if ($returnval eq 'Y') {
	my %iso_latest_names = (
	    'RHEL5' => $DAISY_LATEST_RHEL5_ISO,
	    'RHEL6' => $DAISY_LATEST_RHEL6_ISO,
	    'RHEL7' => $DAISY_LATEST_RHEL7_ISO,
	);
	$daisy_iso = daisy_get_iso($iso_latest_names{$OS});
    }
    else {
	my %iso_test_names = (
	    'RHEL5' => $DAISY_TEST_RHEL5_ISO,
	    'RHEL6' => $DAISY_TEST_RHEL6_ISO,
	    'RHEL7' => $DAISY_TEST_RHEL7_ISO,
	);
	$daisy_iso = daisy_get_iso($iso_test_names{$OS});
    }
    if ($daisy_iso eq $EMPTY_STR) {
	logevent("[daisy_update_software] could not download latest Daisy ISO");
	wait_for_user();
	return(0);
    }

    logevent("[daisy_update_software] Daisy ISO downloaded: $daisy_iso");

    wait_for_user();

    my $rc = 1;

    my $daisy_dir = $DAISYDIR;
    my $menu_title = "Update Daisy in $daisy_dir";
    my $menu_default = "No";
    $returnval = menu_confirm($menu_title, $menu_default);
    if ($returnval eq 'Y') {
	system("/usr/bin/clear");
	if (daisy_update_software($daisy_dir, $daisy_iso)) {
	    logevent("[daisy_update_software] successful update of Daisy software: $daisy_dir");
	    wait_for_user();

	    # cleanup downloaded file
	    system("rm $daisy_iso");

	    $menu_title = "Reboot strongly advised.";
	    $menu_default = "Yes";
	    $returnval = menu_confirm($menu_title, $menu_default);
	    if ($returnval eq 'Y') {
		system("sudo $POSDIR/bin/updateos.pl --reboot");
	    }
	    else {
		system("/usr/bin/clear");
		logevent("[daisy_update_software] reboot after Daisy software update declined");
	    }
	}
	else {
	    logevent("[daisy_update_software] could not update Daisy software: $daisy_dir");
	    $rc = 0;
	}
    }

    wait_for_user();

    return($rc);
}

#
# download the specified daisy florist directory package
#
# a: download the lastest instance of specified package
# b: inform user
# c: return name
#
# returns
#   on success, path to downloaded package
#   if error, empty string
#
sub daisy_get_florist_directory_pkg
{
    my ($pkg_name) = @_;

    my $florist_directory_pkg_path = $EMPTY_STR;

    my $pkg_src_url = $TFSERVER_DAISY_URL . $pkg_name;
    my $pkg_dst_path = File::Spec->catdir($DEF_DAISY_TMPDIR, $pkg_name);
    logevent("[daisy get directory pkg] downloading Daisy florist directory pkg...");
    logevent("[daisy get directory pkg] server URL: $TFSERVER_DAISY_URL");
    logevent("[daisy get directory pkg] package name: $pkg_name");
    system("curl -f -o $pkg_dst_path $pkg_src_url");
    if ($? == 0) {
	logevent("[daisy get directory pkg] package downloaded to: $pkg_dst_path");
	print "\n";
	$florist_directory_pkg_path = $pkg_dst_path;
    }
    else {
	logevent("[daisy get directory pkg] could not download Daisy florist directory package: $pkg_src_url");
    }

    return($florist_directory_pkg_path);
}

sub daisy_download_florist_directory_packages
{
    my $rc = 1;

    system("/usr/bin/clear");

    print "Download Daisy Florist Directory Packages\n";
    print "\n";

    my $daisy_directory_patch = $EMPTY_STR;
    my $daisy_directory_delta = $EMPTY_STR;

    $daisy_directory_patch = daisy_get_florist_directory_pkg($DEF_DAISY_FLORIST_DIRECTORY_PATCH);
    if ($daisy_directory_patch) {
	$daisy_directory_delta = daisy_get_florist_directory_pkg($DEF_DAISY_FLORIST_DIRECTORY_DELTA);
	if ($daisy_directory_delta) {
	    logevent("[daisy download pkgs] Daisy florist directory packages successfully downloaded");
	}
	else {
	    logevent("[daisy download pkgs] could not download Daisy DELTA florist directory package");
	    $rc = 0;
	}
    }
    else {
	logevent("[daisy download pkgs] could not download Daisy PATCH florist directory package");
	$rc = 0;
    }

    wait_for_user();

    return($daisy_directory_patch, $daisy_directory_delta);
}

sub daisy_confirm_florist_directory_install
{
    my $rc = 1;

    my $menu_title = "Install Daisy Florist Directory Packages";
    my $menu_default = "No";
    my $returnval = menu_confirm($menu_title, $menu_default);
    $rc = 0 if ($returnval ne 'Y');

    return($rc);
}

#
# install the Daisy florist directory patch
#
# a: make a temp dir
# b: untar the patch file
# c: run apply patch
# d: return exit status
#
# returns
#   1 on success
#   0 if error
#
sub daisy_install_florist_directory_patch
{
    my ($directory_tar_path) = @_;

    my $rc = 1;

    logevent("[daisy install patch] Daisy PATCH florist directory installation");
    print "\n";

    #
    # make a tempdir that will be removed when script exits,
    # and extract script and patch file from tar file
    #
    my $tempdir_template = 'daisy_patch_dir.XXXXXXX';
    my $tempdir = tempdir($tempdir_template, TMPDIR => 1, CLEANUP => 1);
    system("tar -C $tempdir -xf $directory_tar_path");
    my $patch_script_name = 'applypatch.pl';
    my $patch_script_path = File::Spec->catdir($tempdir, $patch_script_name);
    unless (-f $patch_script_path) {
	logevent("[daisy install patch] apply patch script not present in: $directory_tar_path");
	return(0);
    }
    my $patch_file_path = glob("$tempdir/*.patch");
    unless (-f $patch_file_path) {
	logevent("[daisy install patch] patch file not present in: $directory_tar_path");
	return(0);
    }

    logevent("[daisy install patch] patch contents extracted to: $tempdir");
    logevent("[daisy install patch] apply script: $patch_script_path");
    logevent("[daisy install patch] patch file: $patch_file_path");

    #
    # apply the patch file
    #
    my $cmd = "perl $patch_script_path";
    $cmd .= " --norestart";
    $cmd .= " --log-stderr";
    $cmd .= " --install-ftd-files";
    $cmd .= " $patch_file_path";
    system("cd $tempdir; echo $cmd");
    if ($? == 0) {
	print "\n";
	logevent("[daisy install patch] Daisy PATCH florist directory package successfully installed");
	print "\n";
    }
    else {
	logevent("[daisy install patch] could not apply Daisy PATCH florist directory package");
	logevent("[daisy install patch] apply patch script exit status: $?");
	$rc = 0;
    }

    return($rc);
}

#
# get the release version string from the delta tar file
#
# returns
#   release string if succesful
#   empty string on error
#
sub daisy_get_delta_release
{
    my ($delta_directory_path) = @_;

    my $delta_year = $EMPTY_STR;
    my $delta_book = $EMPTY_STR;

    if (open(my $tarfh, '-|', "tar tf $delta_directory_path")) {
	my $line = <$tarfh>;
	if ($line =~ /([[:digit:]]{4})([[:alpha:]]{3})/) {
	    $delta_year = $1;
	    $delta_book = $2;
	}
	close($tarfh);
    }

    return($delta_year . $delta_book);
}

sub daisy_install_florist_directory_delta
{
    my ($delta_directory_path) = @_;

    my $rc = 1;

    logevent("[daisy install delta] Daisy DELTA florist directory installation");
    print "\n";

    #
    # make a tempdir that will be removed when script exits,
    # and extract install script from the tar file
    #
    my $tempdir_template = 'daisy_delta_dir.XXXXXXX';
    my $tempdir = tempdir($tempdir_template, TMPDIR => 1, CLEANUP => 1);

    my $delta_release = daisy_get_delta_release($delta_directory_path);
    unless ($delta_release) {
	logevent("[daisy install delta] could not get delta release info: $delta_directory_path");
	return(0);
    }

    my $install_script_name = 'edir_installbase.pl';
    my $install_script_tar_path = $delta_release . '/bin/' . $install_script_name;
    system("tar -C $tempdir -xf $delta_directory_path $install_script_tar_path");

    my $install_script_path = $tempdir . '/' . $install_script_tar_path;
    unless (-f $install_script_path) {
	logevent("[daisy install delta] delta install script not present: $delta_directory_path");
	return(0);
    }

    logevent("[daisy install delta] delta install script: $install_script_path");
    logevent("[daisy install delta] delta tar file: $delta_directory_path");

    #
    # install the delta base
    #
    my $cmd = "perl $install_script_path $delta_directory_path";
    system("cd $tempdir; echo $cmd");
    if ($? == 0) {
	print "\n";
	logevent("[daisy install delta] Daisy DELTA florist directory package successfully installed");
	print "\n";
    }
    else {
	logevent("[daisy install delta] could not install Daisy DELTA florist directory package");
	logevent("[daisy install delta] install script exit status: $?");
	$rc = 0;
    }

    return($rc);
}

sub daisy_install_florist_directory_packages
{
    my ($directory_patch, $directory_delta) = @_;

    my $rc = 1;

    system("/usr/bin/clear");

    if (daisy_install_florist_directory_patch($directory_patch)) {
	unless (daisy_install_florist_directory_delta($directory_delta)) {
	    $rc = 0;
	}
    }
    else {
	$rc = 0;
    }

    wait_for_user();

    return($rc);
}

#
# update the daisy florist directory in the default daisy database dir.
#
# a: download the latest daisy florist directory patch:
#   http://rtihardware.homelinux.com/daisy/daisy-latest-altiris.tar
# b: download the latest daisy florist directory delta package:
#   http://rtihardware.homelinux.com/daisy/edir_base_latest.tar.gz
# b: get confirmation from user
# c: attempt update
# d: report
#
# returns
#   1 on success
#   0 if error
#
sub daisy_update_directory_menu
{
    my $rc = 1;

    my ($directory_patch, $directory_delta) = daisy_download_florist_directory_packages();
    if ($directory_patch && $directory_delta) {
	if (daisy_confirm_florist_directory_install()) {
	    if (daisy_install_florist_directory_packages($directory_patch, $directory_delta)) {
	    }
	    else {
		logevent("[daisy update directory] could not install Daisy florist directory packages");
		$rc = 0;
	    }
	}
	else {
	    logevent("[daisy update directory] installation of Daisy florist directory packages cancelled");
	}
    }
    else {
	logevent("[daisy update directory] could not download Daisy florist directory packages");
	$rc = 0;
    }

    # clean up downloaded directory files
    if (-f $directory_patch) {
	system("rm $directory_patch");
    }
    if (-f $directory_delta) {
	system("rm $directory_delta");
    }

    return($rc);
}

#
# given a path to a report file and an output type, send a
# dayend report to the printer or screen.
#
# first arg: name of dayend report file
# second arg: "Screen" or "Printer"
#
# returns
#   1 on success
#   0 if error
#
sub daisy_dayend_processor
{
    my ($report_file, $output) = @_;

    my $printer = "printer0";
    my $rc = 1;

    if (-e $report_file) {
	if ($output eq "Screen" ) {
	    system("clear");
	    system("cat $report_file | less");
	}

	elsif ($output eq "Printer" ) {
	    system("lpr -P $printer $report_file");
	    print "[dayend processor] $report_file sent to printer: $printer\n";
	}

	else {
	    print "[dayend processor] output device must be: Screen|Printer\n";
	    $rc = 0;
	}
    }
    else {
	print "[dayend processor] report does not exist: $report_file\n";
	$rc = 0;
    }

    wait_for_user();

    return($rc);
}

sub daisy_dayend_reporter_menu
{
	my $day = "Mon";
	my $output = "Printer";
	my %options = ();

	$options{"Screen"} = "Send Results to the Screen.";
	$options{"Printer"} = "Send Results to Printer.";
	$output = menu_pickone("Select destination for Dayend/Audit Reports", \%options, $output);

	if ($output eq "Cancel") {
		return;
	}

	%options = ();
	$options{"1. Sun"} = "Dayend report for Sunday.";
	$options{"2. Mon"} = "Dayend report for Monday.";
	$options{"3. Tue"} = "Dayend report for Tuesday.";
	$options{"4. Wed"} = "Dayend report for Wednesday.";
	$options{"5. Thu"} = "Dayend report for Thursday.";
	$options{"6. Fri"} = "Dayend report for Friday.";
	$options{"7. Sat"} = "Dayend report for Saturday.";
	$day = menu_pickone("Select the Day of the Week of the Dayend/Audit Reports", \%options, $day);

	if ($day eq "Cancel") {
		return;
	}

	# get rid of number prefix which was only there for sort order
	$day =~ s/^\d\.\s//;

	# emit the files
	daisy_dayend_processor("${POSDIR}/dayend.$day", $output);
	daisy_dayend_processor("${POSDIR}/audit.$day", $output);

	return(1);
}

sub daisy_db_dirs
{
    my @candidates = ();
    my @daisy_db_dirs = ();

    my @exclude_dirs = qw(
	backup
	config
	drawer
	menus
	pcterm
	putty
	server
	startup
	utils
    );

    #
    # Start with every file in /d.
    #
    @candidates = glob("/d/*");

    #
    # Look for all directories in "/d" that are not on the exclude list and
    # contain files named "flordat.tel" and "control.dsy".
    # 
    foreach my $candidate (@candidates) {

	# must be a directory
	next unless (-d $candidate);

	# must not be on the exclude list
	my $dirname = basename($candidate);
	next if (grep(/$dirname/, @exclude_dirs));

	# must contain these daisy config files
	next unless(-e "$candidate/flordat.tel");
	next unless(-e "$candidate/control.dsy");

	# it made the grade
	push(@daisy_db_dirs, $candidate);
    }

    return (@daisy_db_dirs);
}

sub daisy_list_dirs_menu
{
    system("/usr/bin/clear");

    print "[daisy list dirs] list of Daisy database directories\n";
    print "\n";

    my @daisy_db_dirs = daisy_db_dirs();
    if (@daisy_db_dirs) {
	foreach my $daisy_dir (@daisy_db_dirs) {
	    system("ls -ld $daisy_dir");
	}
    }
    else {
	print "[daisy list dirs] no Daisy database directories found\n";
    }

    wait_for_user();

    return(1);
}

sub daisy_review_log_cloud_backup
{
    print "sub daisy_review_log_cloud_backup\n";

    my $logfile = $DEF_TFRSYNC_CLOUD_LOGFILE;
    my @cloud_backup_logs = glob("/d/daisy/log/tfrsync-cloud-Day_*.log");
    if (@cloud_backup_logs) {
	viewfiles("/d/daisy/log/tfrsync-cloud-Day_*.log", 0);
    }
    else {
	system("/usr/bin/clear");
	print "[review cloud backup logs] there are no cloud backup log files\n";
	wait_for_user();
    }

    return(1);
}

sub daisy_review_log_server_backup
{
    print "sub daisy_review_log_server_backup\n";

    my $logfile = $DEF_TFRSYNC_SERVER_LOGFILE;
    my @server_backup_logs = glob("/d/daisy/log/tfrsync-server-Day_*.log");
    if (@server_backup_logs) {
	viewfiles("/d/daisy/log/tfrsync-server-Day_*.log", 0);
    }
    else {
	system("/usr/bin/clear");
	print "[review server backup logs] there are no server backup log files\n";
	wait_for_user();
    }

    return(1);
}

sub daisy_review_log_summary_backup
{
    my $header = "Daisy Review Summary Backup Log\n\n";

    my $logfile = File::Spec->catdir($DAISY_LOGDIR, $DEF_TFRSYNC_SUMMARY_LOGFILE);
    if (-f $logfile) {
	system("echo '$header' | cat - $logfile | less");
    }
    else {
	system("/usr/bin/clear");
	print "[review backup summary log] file does not exist: $logfile\n";
	wait_for_user();
    }

    return(1);
}

sub daisy_review_log_delta_update
{
    my $header = "Daisy Review Delta Update Log\n\n";

    my $logfile = File::Spec->catdir($DAISY_LOGDIR, $DEF_DELTA_UPDATE_LOGFILE);
    if (-f $logfile) {
	system("echo '$header' | cat - $logfile | less");
    }
    else {
	system("/usr/bin/clear");
	print "[review delta update log] file does not exist: $logfile\n";
	wait_for_user();
    }

    return(1);
}

sub daisy_review_log_delta_summary
{
    my $header = "Daisy Review Delta Summary Log\n\n";

    my $logfile = File::Spec->catdir($DAISY_LOGDIR, $DEF_DELTA_SUMMARY_LOGFILE);
    if (-f $logfile) {
	system("echo $header | cat - $logfile | less");
    }
    else {
	system("/usr/bin/clear");
	print "[review delta summary log] file does not exist: $logfile\n";
	wait_for_user();
    }

    return(1);
}

#
# review some Daisy log files
#
# a: tfrsync.pl cloud backup
# b: tfrsync.pl server to server
# c: tfrsync.pl summary
# d: edir_update.pl processing
# e: edir_update.pl summary
#
# returns
#   1 always
#
sub daisy_review_logs_menu
{
    my $title = 'Daisy Review Log Files Menu';
    my $command = "dialog --stdout";
    $command .= " $TIMEOUT_MENU_ARG";
    $command .= " --no-cancel";
    $command .= " --default-item \"Close\"";
    $command .= " --menu '$title'";
    $command .= " 0 0 0";

    my @menu_items = (
	[ "Delta Update Log",
	  "Review Delta Florist Directory Update Log File.",
	  \&daisy_review_log_delta_update,
        ],
	[ "Delta Summary Log",
	  "Review Delta Florist Directory Summary Log File.",
	  \&daisy_review_log_delta_summary,
        ],
	[ "Cloud Backup Logs",
	  "Review Cloud Backup Log Files.",
	  \&daisy_review_log_cloud_backup,
        ],
	[ "Server Backup Logs",
	  "Review Server to Server Backup Log Files.",
	  \&daisy_review_log_server_backup,
        ],
	[ "Backup Summary Log",
	  "Review Backup Summary Log File.",
	  \&daisy_review_log_summary_backup,
        ],
    );

    foreach my $menu_item (@menu_items) {
	my ($code, $description, $func) = @$menu_item;
	$command .= " \"$code\"" . " \"$description\"";
    }

    $command .= " \"Close\"" . " \"Close This Menu\"";

    my $returnval = "";

    while (1) {
	if (open(my $dialogfh, '-|', $command)) {
	    $returnval = <$dialogfh>;
	    close($dialogfh);
	    next unless ($returnval);
	    chomp($returnval);
	}
	else {
	    print "[daisy review logs menu] could not open pipe to dialog for: $title\n";
	    wait_for_user();
	    last;
	}

	if ($returnval eq "timeout") {
	    logevent("Inactivity Timeout: [daisy_review_logs_menu]");
	    exit(0);
	}

	if ($returnval eq "Close") {
	    last;
	}

	foreach my $menu_item (@menu_items) {
	    my ($code, $description, $func) = @$menu_item;
	    if ($returnval eq $code) {
		&$func();
	    }
	}
    }

    return(1);
}

sub daisy_menu
{
    my $title = titlestring("Daisy Application Menu");
    my $command = "dialog --stdout";
    $command .= " $TIMEOUT_MENU_ARG";
    $command .= " --no-cancel";
    $command .= " --default-item \"Close\"";
    $command .= " --menu '$title'";
    $command .= " 0 0 0";
    $command .= " \"Start Daisy\"" . " \"Start Daisy Programs.\"";
    $command .= " \"Stop Daisy\"" . " \"Stop all Daisy Programs.\"";
    $command .= " \"Update Software\"" . " \"Update Daisy Point-of-Sale Software.\"";
    $command .= " \"Update Directory\"" . " \"Update Daisy Florist Directory.\"";
    $command .= " \"List Daisy Dirs\"" . " \"List all Daisy database directories.\"";
    $command .= " \"POS\"" . " \"Run '$POSDIR/pos' as current user.\"";
    $command .= " \"Daisy\"" . " \"Run '$POSDIR/daisy' as current user.\"";
    $command .= " \"Dayend Report\"" . " \"Print Daisy Dayend Reports.\"";
    $command .= " \"Review Logs\"" . " \"Review Daisy Log Files.\"";
    $command .= " \"Advanced\"" . " \"Advanced Tools.\"";
    $command .= " \"Close\"" . " \"Close This Menu\"";

    my $returnval = "";

    while (1) {

	if (open(my $dialogfh, '-|', $command)) {
	    $returnval = <$dialogfh>;
	    close($dialogfh);
	    next unless ($returnval);
	    chomp($returnval);
	}
	else {
	    print "[daisy menu] could not open pipe to dialog for: $title\n";
	    wait_for_user();
	    last;
	}

	if ($returnval eq "timeout") {
	    logevent("Inactivity Timeout: daisy_menu");
	    exit(0);
	}

	elsif ($returnval eq "Start Daisy") {
	    daisy_start_menu();
	}

	elsif ($returnval eq "Stop Daisy") {
	    daisy_stop_menu();
	}

	elsif ($returnval eq "POS") {
	    system("cd $POSDIR && $POSDIR/pos");
	}

	elsif ($returnval eq "Daisy") {
	    system("cd $POSDIR && $POSDIR/daisy");
	}

	elsif ($returnval eq "Update Software") {
	    daisy_update_software_menu();
	}

	elsif ($returnval eq "Update Directory") {
	    daisy_update_directory_menu();
	}

	elsif ($returnval eq "List Daisy Dirs") {
	    daisy_list_dirs_menu();
	}

	elsif ($returnval eq "Review Logs") {
	    daisy_review_logs_menu();
	}

	elsif($returnval eq "Dayend Report") {
	    daisy_dayend_reporter_menu();
	}

	elsif ($returnval eq "Advanced") {
	    daisy_advanced_menu();
	}

	elsif ($returnval eq "Close") {
	    last;
	}
    }

    return(1);
}



sub daisy_advanced_menu
{
	my $command = "";
	my $returnval = "";
	my $suboption = "";
	my $title = "Daisy Advanced Menu";
	my $user = "";
	my $logfile = "";
	my $daisy_db_dir = "";

	while(1) {

		$title = titlestring("Daisy Advanced Menu");

		$command = "dialog --stdout";
		$command .= " $TIMEOUT_MENU_ARG";
		$command .= " --no-cancel";
		$command .= " --default-item \"Close\"";
		$command .= " --menu '$title'";
		$command .= " 0 0 0";
		$command .= " \"POS as User\"" . " \"'pos' as another user.\"";
		$command .= " \"Daisy as User\"" . " \"Run 'daisy' as another user.\"";
		$command .= " \"Permissions\"" . " \"Run Permissions on All Daisy Files.\"";
		$command .= " \"Rotate Keys\"" . " \"Rotate Encryption Keys.\"";
		$command .= " \"CC Purge\"" . " \"Purge Expired Credit Cards.\"";
		$command .= " \"Quick Restore\"" . " \"Quick restore (QREST) saved transaction files\"";
		$command .= " \"Close\"" . " \"Close This Menu\"";

		if (open(my $dialogfh, '-|', $command)) {
		    $returnval = <$dialogfh>;
		    close($dialogfh);
		    next unless ($returnval);
		    chomp($returnval);
		}
		else {
		    print "[daisy advanced menu] could not open pipe to dialog for: $title\n";
		    wait_for_user();
		    last;
		}

		if($returnval eq "timeout") {
			logevent("Inactivity Timeout.");
			exit(0);


		} elsif($returnval eq "POS as User") {
			$returnval = users_menu_choose("Choose Daisy User");
			if($returnval ne "") {
				system("cd $POSDIR && sudo -u $returnval $POSDIR/pos");
			}

		} elsif($returnval eq "Daisy as User") {
			$returnval = users_menu_choose("Choose Daisy User");
			if($returnval ne "") {
				system("cd $POSDIR && sudo -u $returnval $POSDIR/daisy");
			}

		} elsif($returnval eq "Permissions") {
			$daisy_db_dir = daisy_select_db_dir();
			unless ($daisy_db_dir eq "") {
				system("/usr/bin/clear");
				print("Running Daisy Perms...\n");
				system("sudo $POSDIR/bin/dsyperms.pl $daisy_db_dir");
				wait_for_user();
			}

		} elsif($returnval eq "Rotate Keys") {
			$daisy_db_dir = daisy_select_db_dir();
			unless ($daisy_db_dir eq "") {
				system("/usr/bin/clear");
				system("sudo $POSDIR/bin/dokeyrotate.pl $daisy_db_dir");
				wait_for_user();
			}

		} elsif($returnval eq "CC Purge") {
			$daisy_db_dir = daisy_select_db_dir();
			unless ($daisy_db_dir eq "") {
				system("/usr/bin/clear");
				system("sudo $POSDIR/bin/doccpurge.pl $daisy_db_dir");
				wait_for_user();
			}

		} elsif($returnval eq "Quick Restore") {
			$daisy_db_dir = daisy_select_db_dir();
			unless ($daisy_db_dir eq "") {
				system("/usr/bin/clear");
				system("cd $daisy_db_dir && sudo $daisy_db_dir/qrest");
				wait_for_user();
			}

		} elsif($returnval eq "Close") {
			return(0);
		}
	}

	return(1);
}


sub menu_confirm
{
	my $title = $_[0];
	my $default = $_[1];
	my $command = "";


	$command = "dialog --stdout";
	$command .= " $TIMEOUT_MENU_ARG";
	if( ($default) && ($default =~ /^no$/i)) {
		$command .= " --defaultno";
	}
	$command .= " --yesno";
	$command .= " \"$title\"";
	$command .= " 0 0";

	system("$command");

	if($? == 0) {
		return("Y");

	} elsif ($? == 255) {
		# Timeout
		logevent("Inactivity Timeout.");
		exit(0);
		
	} else {
		return("N");
	}
}


sub menu_info
{
	my $title = $_[0];
	my $command = "";


	$command = "dialog --stdout";
	$command .= " $TIMEOUT_MENU_ARG";
	$command .= " --msgbox";
	$command .= " \"$title\"";
	$command .= " 0 0";

	system("$command");
	if($? == 255) {
		# Timeout
		logevent("Inactivity Timeout.");
		exit(0);
	}

	return(0);
}


sub menu_getstring
{
	my ($title, $menu_height) = @_;

	my $default = "";
	my $command = "";
	my $returnval = "";

	$command = "dialog --stdout";
	$command .= " $TIMEOUT_MENU_ARG";
	$command .= " --no-cancel";
	$command .= " --inputbox '$title'";

	#
	# One, I don't want to change the interface to menu_getstring()
	# to provide values for the height and width of the inputbox...
	# so we will just look at the length of the title string passed
	# as the first arg to this function.
	#
	# Two, the following section of code contains magic numbers to try to
	# get the dialog --inputbox to provide enough width for the title string...
	# values determined via trying various title lengths and menu box widths
	# at the command line.
	#
	my $menu_width = 0;
	my $title_len = length($title);
	if ($title_len > 25) {
		$menu_width = $title_len + 5;
	}

	unless (defined($menu_height)) {
	    $menu_height = 0;
	}

	$command .= " $menu_height $menu_width";

	if( ($default) && ("$default" ne "")) {
		$command .= " \"$default\"";
	}

	open(DIALOG, "$command |");
	$returnval = <DIALOG>;
	close(DIALOG);

	unless (defined $returnval) {
		return("");
	}

	chomp($returnval);
	
	$returnval = validate_input($returnval);

	#
	# Three, the following code does not work - upon a timeout, the dialog command
	# writes the string "\ntimeout\n" to stderr, not stdout, and the call to open()
	# above only captures stdout.
	#
	if($returnval eq "timeout") {
		# Timeout
		logevent("Inactivity Timeout.");
		exit(0);
	}

	return("$returnval");
}


#
# Simple radio button box.
#
sub menu_pickone
{
	my $title = $_[0];
	my %options = %{$_[1]};
	my $default = $_[2];
	my $value = "";


	my $command = "";
	my $returnval = "";

	$command = "dialog --stdout";
	$command .= " $TIMEOUT_MENU_ARG";
	# $command .= " --no-cancel";
	$command .= " --radiolist '$title' 0 0 0 ";

	foreach my $key (sort(keys(%options))) {
		$value = $options{$key};
		$command .= " " . "\"$key\" \"$value\" ";
		if("$key" eq "$default") {
			$command .= " on";
		} else {
			$command .= " off";
		}
	}


	open(DIALOG, "$command |");
	$returnval = <DIALOG>;
	close(DIALOG);
	return if(! $returnval);
	chomp($returnval);
	
	$returnval = validate_input($returnval);

	if($returnval eq "timeout") {
		# Timeout
		logevent("Inactivity Timeout.");
		exit(0);
	}

	return("$returnval");
}


sub titlestring
{
	my $title = $_[0];
	my $returnval = "";

	$returnval = "--------======== $title =======---------\\n";
	
	# Get our hostname.
	$returnval .= get_hostname("--short");

	# Current timestamp.
	$returnval .= " - ";
	$returnval .= strftime("%a %B %d, %Y %T %Z", localtime());
	$returnval .= "\\n";
	$returnval .= "\\n";



	return($returnval);
}


sub menu_presenter
{
    my ($menu_title, $menu_items) = @_;

    my $command = "dialog --stdout";
    $command .= " $TIMEOUT_MENU_ARG";
    $command .= " --no-cancel";
    $command .= " --default-item \"Close\"";
    $command .= " --menu '$menu_title'";
    $command .= " 0 0 0";

    foreach my $menu_item (@{$menu_items}) {
	my ($code, $description, $func) = @$menu_item;
	$command .= " \"$code\"" . " \"$description\"";
    }

    $command .= " \"Close\"" . " \"Close This Menu\"";

    my $returnval = "";

    while (1) {
	if (open(my $dialogfh, '-|', $command)) {
	    $returnval = <$dialogfh>;
	    close($dialogfh);
	    next unless ($returnval);
	    chomp($returnval);
	}
	else {
	    $returnval = "dialogerr";
	}

	last if ($returnval eq "dialogerr");
	last if ($returnval eq "timeout");
	last if ($returnval eq "Close");

	foreach my $menu_item (@{$menu_items}) {
	    my ($code, $description, $func, $arg) = @$menu_item;
	    if ($returnval eq $code) {
		&$func($code, $arg);
	    }
	}
    }

    return($returnval);
}


#
# Check for backup status in a rtibackup.pl log file.
# Uses the same strategy as in the "checkbackup.pl" script.
#
# Returns string indicating backup status or empty string.
#
sub get_backup_status_indicator
{
    my $rtibackup_logfile = $_[0];
    my $return_val = "";

    my $rc = system("grep VERIFY $rtibackup_logfile 2>/dev/null | grep -iq failed 2>/dev/null");
    if ($rc == 0) {
	$return_val = "FAILED";
    }
    else {
	$rc = system("grep VERIFY $rtibackup_logfile 2>/dev/null | grep -iq succeeded 2>/dev/null");
	if ($rc == 0) {
	    $return_val = "SUCCESS";
	}
    }

    return($return_val);
}


#
# Present a list of files in a dialog box and let the user
# pick one or cancel.
#
# Returns file chosen or empty string if none chosen or
# the user cancels.
#
# First arg is mandatory arg that is a path to set of files
# that can contain shell meta chars.
#
# Second arg is optional and if defined and true, means that
# "sudo" must be used to get the file list.
#
sub pickfile
{
    my $filepattern = $_[0];
    my $sudo = $_[1];

    if ($filepattern eq "") {
	return("");
    }

    if (defined($sudo)) {
	$sudo = ($sudo) ? "sudo " : "";
    }
    else {
	$sudo = "";
    }

    #
    # Were rtibackup.pl log files specified?
    #
    my $rtibackup_logfile = 0;
    if ($filepattern =~ /log\/rtibackup-.*\.log/) {
	$rtibackup_logfile = 1;
    }

    #
    # Start forming a dialog radio box that will present the files and
    # let the user pick one.
    #
    my $command = "";
    my $title = "Pick a log file to view, ";
    if ($rtibackup_logfile) {
	$title .= "directory = $POSDIR/log";
    }

    $command = "dialog --stdout";
    $command .= " $TIMEOUT_MENU_ARG";
    $command .= " --radiolist '$title'";
    $command .= " 0 80 16";

    #
    # Get the list of files to pick from
    #
    open(FILELIST, "$sudo /bin/ls -t $filepattern |");

    my @files = ();
    while (<FILELIST>) {
	chomp;
	push(@files, $_);
    }
    close(FILELIST);

    #
    # Now, finish forming the input to dialog.
    #
    my $i = 0;
    my $indicator = "";
    my $tag = "";
    my $alphabet_size = ord('z') - ord('a');
    my %tag_to_file_map = ();
    foreach my $file_path (@files) {

	my $file_basename = basename($file_path);

        #
        # if rtibackup.pl log files were specified, determine which
        # ones have verify errors.
        #
        if ($rtibackup_logfile) {
	    $indicator = get_backup_status_indicator($file_path);
	    if ($indicator eq "") {
		$indicator = "Please view log for status";
	    }
        }

	if ($i < $alphabet_size) {
	    $tag = chr(ord('a') + $i);
	}
	elsif ($i < (2 * $alphabet_size)) {
	    $tag = chr(ord('A') + ($i % $alphabet_size));
	}
	else {
	    $tag = $i;
	}

	# save the mapping from tag to file path
	$tag_to_file_map{$tag} = $file_path;

	if ($indicator) {
	    $file_basename .= " $indicator";
	}
	
        $command .= " " . "\"$tag\" \"$file_basename\" off";

        $i++;
    }

    #
    # Put up the list of files and let user select
    #
    open(DIALOG, "$command |");
    my $returnval = <DIALOG>;
    close(DIALOG);

    #
    # if we got a return value, map back to file path
    #
    if (defined($returnval)) {
	$returnval = $tag_to_file_map{$returnval};
    }
    else {
	$returnval = "";
    }

    return($returnval);
}


sub viewfiles
{
    my $filepattern = $_[0];
    my $sudo = $_[1];
    my $filter = $_[2];

    if ($filepattern eq "") {
	return("");
    }

    if (defined($sudo)) {
	$sudo = ($sudo) ? "sudo " : "";
    }

    if (!defined($filter)) {
	$filter = "";
    }

    #
    # Put up a dialog making the user choose one lucky file.
    #
    $filepattern = pickfile($filepattern, $sudo);
    if ($filepattern eq "") {
	return("");
    }

    #
    # Allow the user to define an alternative file cat program,
    # ie "tac" instead of "cat" (ugh!).
    #
    my $cat_cmd = "/bin/cat";
    if (defined $ENV{'TFSUPPORT_CAT'}) {
	$cat_cmd = $ENV{'TFSUPPORT_CAT'};
    }

    open(FILELIST, "$sudo /bin/ls -t $filepattern |");
    my @files = ();
    while (<FILELIST>) {
	chomp;
	push(@files, $_);
    }
    close(FILELIST);

    #
    # Output a header before each file so the viewer can tell
    # which file they are looking at.
    #
    my $command = "(/bin/true";
    foreach (@files) {
	if (/\.gz$/) {
	    $command .= " ; echo \">>>>>\"; echo \">>>>> $_\"; echo \">>>>>\"";
	    $command .= " ; $sudo /bin/zcat $_ | $cat_cmd";
	}
	else {
	    $command .= " ; echo \">>>>>\"; echo \">>>>> $_\"; echo \">>>>>\"";
	    $command .= " ; $sudo $cat_cmd $_";
	}
    }
    $command .= ") ";
    if ($filter ne "") {
	$command .= " | $filter";
    }
    system("$command | less");

    #
    # Return the command... without trailing "| less"
    # This allows the caller to re-run the command and
    # print results to a printer if wanted.
    # (Especially useful for security logs.)
    #
    return($command);
}


sub get_cups_version
{
	my $cups_version = "";

	open(PIPE, "rpm -qa |");
	while(<PIPE>) {
		chomp;
		if (/^cups-(\d)/) {
			$cups_version = $_;
			last;
		}
	}
	close(PIPE);

	return($cups_version);
}


sub get_script_version
{
	my $script_name = $_[0];
	my $version = "";
	my $cmd = "/d/daisy/bin/" . $script_name . ".pl --version";

	$version = qx($cmd);
	chomp($version);

	return($version);
}


sub get_linux_version
{
	my $linux_version = qx(cat /etc/redhat-release);

	chomp($linux_version);

	return($linux_version);
}


sub get_pos_version
{
	my $returnval = "";
  
	if (-d "$POSDIR/bbxd/RTI.ini") {
		open(FILE, "< $POSDIR/bbxd/RTI.ini");
		while(<FILE>) {
			chomp;
			if (/(VERSION)(\s*)(=)(\s*)([[:print:]]+)/) {
				$returnval = "RTI Version: $5";
				last;
			}
		}
		close(FILE);
	} elsif (-d "/d/daisy") {
		open (PIPE, "/d/daisy/bin/identify_daisy_distro.pl /d/daisy |");
		while(<PIPE>) {
			chomp;
			$returnval = "Daisy Version: " . (split(/\s+/))[3];
			last;
		}
		close(PIPE);
	} 
	return($returnval);
}


# get the version of TCC
sub get_tcc_version
{
    my $tcc_version = $EMPTY_STR;

    # the TCC binary is on different paths for RTI and Daisy.
    my $tcc_cmd = ($POSDIR eq $RTIDIR) ? "$POSDIR/bin/tcc_tws" : "$POSDIR/tcc/tcc";

    if (open(my $pipefh, '-|', "$tcc_cmd --version")) {
	while (<$pipefh>) {
	    chomp;
	    if (/Version:/) {
		$tcc_version = "TCC $_\\n";
	    }
	}
	close($pipefh);

	my $tcc_md5 = get_md5sum($tcc_cmd);
	$tcc_version .= "TCC MD5: " . $tcc_md5 . "\\n";
    }

    return($tcc_version);
}


# calculate the md5sum of a file
sub get_md5sum
{
    my ($filename) = @_;

    my $md5sum = "";

    if (-f $filename) {
	if (open(my $fh, '<', $filename)) {
	    binmode($fh);
	    my $ctx = Digest::MD5->new;
	    $ctx->addfile($fh);
	    $md5sum = $ctx->hexdigest;
	    close($fh);
	}
    }

    return($md5sum);
}


# Get our hostname.
sub get_hostname
{
	my $hostname_type = $_[0];
	my $returnval = "";

	open(HOST, "/bin/hostname $hostname_type |");
	while(<HOST>) {
		chomp;
		if ($_ ne "") {
			$returnval = $_;
			last;
		}
	}
	close(HOST);

	return ($returnval);
}


#
# Get the system run level.
#
# Use output of 'who -r' which seems to work on both
# RHEL5 and RHEL6 under Kaseya.
#
#
# Returns
#   0-6 on success
#   -1 on error
#
sub get_runlevel
{
    my $runlevel = -1;

    my $whocmd = '/usr/bin/who';
    if (-x $whocmd) {
	if (open(my $pipefh, '-|', "$whocmd -r")) {
	    while (my $line = <$pipefh>) {
		chomp($line);
		if ($line =~ m/\s*run-level\s(\d).+$/) {
		    if ($1 >= 0 && $1 <= 6) {
			$runlevel = $1;
		    }
		}
	    }
	    close($pipefh);
	}
	else {
	    logevent("[get runlevel] could not open pipe to command: $whocmd");
	}
    }
    else {
	logevent("[get runlevel] command does not exist: $whocmd");
    }

    return($runlevel);
}


#
# get system service status
#
# returns
#   true if running
#   false if not
#
sub get_system_service_status
{
    my ($service_name) = @_;

    my $rc = 0;

    # default to RHEL5 and RHEL6
    my $cmd = "sudo /sbin/service $service_name status";
    my $cmd_response = 'is running';
    if ($OS eq 'RHEL7') {
	$cmd = "systemctl is-active $service_name";
	$cmd_response = 'active';
    }

    if (open(my $pipefh, '-|', $cmd)) {
	while(<$pipefh>) {
	    if (/$cmd_response/) {
		$rc = 1;
		last;
	    }
	}
	close($pipefh);
    }
    else {
	logevent("[get service status] could not open pipe to command: $cmd");
    }

    return($rc);
}


sub make_tempfile
{
        my $prefix = $_[0];

        my $tmpfile = qx(mktemp $prefix.XXXXXXX);
        chomp($tmpfile);
        if ($tmpfile eq "") {
                $tmpfile = "$prefix" . '.' . strftime("%Y%m%d%H%M%S", localtime());
        }

        return($tmpfile);
}


sub set_signal_handlers
{
	my $handler = $_[0];

	$SIG{'STOP'} = $handler;
	$SIG{'TSTP'} = $handler;
	$SIG{'INT'} = $handler;
}


# trim whitespace from start and end of string
sub trim
{
	my $string = $_[0];

	$string =~ s/^\s+//;
	$string =~ s/\s+$//;

	return $string;
}
# trim leading whitespace
sub ltrim
{
	my $string = $_[0];

	$string =~ s/^\s+//;

        return $string;
}
# trim trailing whitespace
sub rtrim
{
        my $string = $_[0];

        $string =~ s/\s+$//;

        return $string;
}

sub system_exit_status
{
        my $exit_status = $_[0];
        my $strerror = "";

        if ($exit_status == -1) {
                $strerror = "system() failed to execute: $!";
        } elsif ($exit_status & 127) {
                my $signalnr = ($exit_status & 127);
                $strerror = "system() died from signal: $signalnr";
        } else {
                my $return_status = ($exit_status >> 8);
                if ($return_status) {
                        $strerror = "system() exited with value: $return_status";
                }
        }

        return $strerror;
}

#
# User presses enter to clear input of a screen.
#
sub wait_for_user
{
	my $temp = "";

	print("\nPress the Enter key to continue ...");
	$temp = <STDIN>;
	return(0);
}


# PCI 6.5.6
# "some string; `cat /etc/passwd`" -> "some string cat /etc/passwd"
# "`echo $ENV; $(sudo ls)`" -> "echo ENV sudo ls"
# etc.
sub validate_input
{
	my $var = $_[0];
	my $temp = "";

	if(! $var) {
		return "";
	}

	$temp = $var;

	# "`bad command`" -> "bad command"
	$temp =~ s/\`//g;

	# "$(bad command)" -> "bad command"
	$temp =~ s/(\$\()(.*.)(\))/$2/g;


	# "stuff ; bad command" -> "stuff bad command"
	$temp =~ s/\;//g;

	# "stuff && bad command" -> "stuff bad command"
	$temp =~ s/\&//g;

	# "stuff | bad command" -> "stuff bad command"
	$temp =~ s/\|//g;

	# "stuff > bad command" -> "stuff bad command"
	$temp =~ s/\>//g;

	# "stuff < bad command" -> "stuff bad command"
	$temp =~ s/\<//g;

	# Filter non printables
	$temp =~ s/[[:cntrl:]]//g;


	return($temp);
}


# 
# Is the current user an administrative user?
#
sub is_admin_user
{
	my $returnval = 0;
	my @array = ();


	# We can have a shell option if we are either tfsupport, or root.
	# In 12.6 systems, "tfsupport" and "root" are always memebers of rtiadmins, however,
	# in 12.5 systmes, such may not be the case.
	open(NAME, "/usr/bin/whoami |");
	while(<NAME>) {
		chomp;
		if(/^tfsupport$/) {
			$returnval = 1;
		} elsif(/^root$/) {
			$returnval = 1;
		}
	}
	close(NAME);
	if($returnval != 0) {
		return($returnval);
	}


	open(GROUPS, "groups |");
	while(<GROUPS>) {
		chomp;
		@array = split(/\s+/);
		if(grep(/^rtiadmins$/, @array)) {
			$returnval = 1;
		}
		if(grep(/^dsyadmins$/, @array)) {
			$returnval = 1;
		}
	}
	close(GROUPS);

	return($returnval);
}


sub loginfo
{
    my ($message) = @_;

    return(logevent("<I>  $message"));
}


sub logerror
{
    my ($message) = @_;

    return(logevent("<E>  $message"));
}


#
# Send an event to syslog.
#
sub logevent
{
    my ($event) = @_;

    my $cmd = "";
    my $user =  "";
    my $client = "";

    if (-f "/bin/logger") {
	$cmd = "/bin/logger";
    }
    elsif (-f "/usr/bin/logger") {
	$cmd = "/usr/bin/logger";
    }
    else {
	$cmd = "echo";
    }

    if (defined $ENV{'USER'}) {
	$user = $ENV{'USER'};
    }
    else {
	system("echo [logevent] user unknown >> $ERROR_LOG");
	$user = 'UNK';
    }

    if (defined $ENV{'SSH_CLIENT'}) {
	$client = $ENV{'SSH_CLIENT'};
    }
    elsif (open(my $tty, '-|', '/usr/bin/tty')) {
	while (<$tty>) {
	    chomp;
	    $client = $_;
	    last;
	}
	close($tty);
    }
    else {
	system("echo [logevent] could not open pipe to tty >> $ERROR_LOG");
	$client = 'UNK';
    }

    system("$cmd \"(PID $$: $user\@$client) $event\"");

    print("$event\n");

    return(1);
}


#
# search file for regular expression
#
# Returns
#   0 found regular expression
#   1 did not find regular expression
#
sub fgrep
{
    my ($fpath, $re) = @_;

    my $rc = 1;
    if (open(my $fp, '<', $fpath)) {
	while (<$fp>) {
	    chomp;
	    if (/$re/) {
		$rc = 0;
		last;
	    }
        }
	close($fp);
    }

    return($rc);
}

#
# would be better if we had used User::pwent from the start,
# but not going to change things now.
#
sub get_account_info
{
    my ($username) = @_;

    my %hash = ();

    setpwent();
    my @pwent = getpwent();
    while (@pwent) {
	if ($pwent[0] eq $username) {
	    $hash{"username"} = $username;
	    $hash{"uid"} = $pwent[2];
	    $hash{"gid"} = $pwent[3];
	    $hash{"homedir"} = $pwent[7];
	    $hash{"shell"} = $pwent[8];
	    last;
	}
	@pwent = getpwent();
    }
    endpwent();

    return(%hash);
}

#
# Get useful information such as groups and home directory
# about a given user.
sub get_userinfo
{
	my $username = $_[0];
	my $groupname = "";
	my $users = "";
	my @ent = ();
	my @groups = ();
	my %hash;
	my $found = 0;

	if($username eq "") {
		return %hash;
	}



	# Get user related info.
	setpwent();
	@ent = getpwent();
	while(@ent) {
		if( "$ent[0]" eq "$username") {
			$found = 1;
			$hash{"username"} = $username;
			$hash{"homedir"} = "$ent[7]";
			$hash{"shell"} = "$ent[8]";
			last;
		}
		@ent = getpwent();
	}
	endpwent();
 

	# We did  not find this user.
	if($found == 0) {
		return %hash;
	}


	# Get user's associated groups.
	# ($name,$passwd,$gid,$members) = getgr*
	$hash{"groups"} = ();
	@ent = getgrent();
	while(@ent) {
		$groupname = $ent[0];
		$users = $ent[3];
		if($users =~ /([[:space:]]*)($username)([[:space:]]{1}|$)/) {
			push @groups, $groupname;
		}
		@ent = getgrent();
	}
	endgrent();
	$hash{'groups'} = [ @groups ];
 

	return(%hash);
}


sub tfs_pathto_inittab
{
    my $conf_file_path = '/etc/inittab';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub tfs_pathto_ostools_bindir
{
    return("$OSTOOLSDIR/bin");
}



__END__


=pod

=head1 NAME

tfsupport.pl - Teleflora Support Menus

=head1 VERSION

This documenation refers to version: $Revision: 1.205 $


=head1 USAGE

tfsupport.pl

tfsupport.pl B<--version>

tfsupport.pl B<--help>


=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=back


=head1 DESCRIPTION

The C<tfsupport.pl> script offers a system of menus for
Teleflora customer service staff which provides
a convenient, reliable, efficient, platform indepenent method
for performing many tasks commonly required on a RTI/Daisy server.
Since this script occasionally runs commands via C<sudo(1)>,
a member of the "rtiadmins" or "dsyadmins" group should run the script.

Since the menus are implemented with the C<dialog> command,
the "TERM" environment variable must be defined before execution of the script.
If not defined, the script will exit by execing a BASH shell with
output asking the user to fix the situation.
If the platform is not "RHEL6", and the value of "TERM" is "ansi", then
the value of "TERM" is set to "scoansi-old".
If the platform is "RHEL6", and the value of "TERM" is "ansi", then
the value of "TERM" is set to "linux".
Testing with a Putty connection from a PC to an RTI server has shown
these values to be the best for working with RTI and C<dialog(1)> command.

There is an inactivity limit of 15 minutes.
Thus, if the script is displaying the starting support menu
for more than 15 minutes, the script exits.

Log messages are logged via the C<logger(1)> command and thus
by default go to C</var/log/messages>.

The menu item "Backup -> Advanced -> Logs" displays a picklist of
log files to view.
For each log file, the verification status is displayed to the right
of the file name.
If there was a verification failure anywhere in the log file, then
the string "FAILED" is displayed.
If there are no verification errors and there is at least one
verification success, then
the string "SUCCESS" is displayed.
If there is no verification status in the log file, then
the string "Please view log for status" is displayed.

The menu item "Backups -> Backup History" uses the script
C<checkbackup.pl> to get a summary of recent backup results
for RTI systems.


=head1 FILES

=over 4

=item B</var/log/messages>

The default log file.

=item B</etc/redhat-release>

The file that contains the platform release version information.

=item B<rtibackup-Day_01.log .. rtibackup-Day_31.log>

A set of daily C<rtibackup.pl> log files.
For Daisy systems, they are located in C</d/daisy/log>.
For RTI systems, they are located in C</usr2/bbx/log>.

=item B</var/lock/rtisendfax.lock>

The lock file used by C<rti_sendfax.pl>.

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status 0

Successful completion.

=item Exit status 1

In general, there was an issue with the syntax of the command line.

=item Exit status 2

An unexpected error was reported by the I<dialog> command.

=item Exit status 3

The script was run with an effective UID of 0 which is not allowed.

=back


=head1 SEE ALSO

C<rtibackup.pl>,
C<updateos.pl>,
C<harden_linux.pl>,
C<install-ostools.pl>,
C<bbjservice.pl>,
C<checkbackup.pl>,
C<doveserver.pl>,
C<rti_sendfax.pl>,
C<lsusb(8)>
C<lpstat(1)>


=cut
