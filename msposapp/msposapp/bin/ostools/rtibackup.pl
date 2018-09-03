#!/usr/bin/perl
#
# $Revision: 1.367 $
# Copyright 2009-2017 Teleflora
#
# rtibackup.pl
#
# Script to perform backups and restores of an RTI and/or Daisy system.
#

use strict;
use warnings;
use POSIX;
use IO::Socket;
use Getopt::Long;
use English qw( -no_match_vars );
use Net::SMTP;
use File::Basename;
use Sys::Hostname;
use Digest::MD5;
use Cwd;

use lib qw( /teleflora/ostools/modules /d/ostools/modules /usr2/ostools/modules );
use OSTools::Platform;
use OSTools::Hardware;
use OSTools::Filesys;


our $VERSION = 1.15;
my $CVS_REVISION = '$Revision: 1.367 $';
my $TIMESTAMP = strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($0);

my $HELP = 0;
my $CVS_VERSION = 0;

my $EMPTY_STR   = q{};

my $OS = $EMPTY_STR;
my @BACKUP = ();
my @RESTORE = ();
my @RESTORE_EXCLUDES = ();
my @EMAIL = ();
my @PRINTER = ();
my @USERFILES = ();
my @EXCLUDES = ();
my $EMAIL_SERVER = 'sendmail';
my $EMAIL_USER = $EMPTY_STR;
my $EMAIL_PASS = $EMPTY_STR;
my $VERIFY = 0;
my $VERBOSE = 0;
my $FORCE = 0;
my $FORMAT = 0;
my $MOUNT = 0;
my $UNMOUNT = 0;
my $FINDDEV = 0;
my $INSTALL = 0;
my $SHOWKEY = 0;
my $CHECKMEDIA = 0;
my $EJECT = 0;
my $EJECTDAYS = "mon,tue,wed,thu,fri";
my $CURRENT_ARCH = $EMPTY_STR;
my $RH_VERSION = $EMPTY_STR;
my $KERNEL_VERSION = $EMPTY_STR;
my $SYS_HOSTNAME = $EMPTY_STR;
my $CONSOLE =  0;
my $NOCC =  0;
my $DAISY =  0;
my $RTI =  0;
my @LIST = ();
my $CHECKFILE = 0;
my $CONFIGFILE = $EMPTY_STR;
my $REPORT_CONFIGFILE = 0;
my $REPORT_IS_BACKUP_ENABLED = 0;
my $DEVICE = $EMPTY_STR;
my $DEVICE_IMAGE_FILE_MIN = 1048576; # 1 MB in bytes
my $DEVICE_VENDOR = "WD";
my $DEVICE_MODEL = "My Passport";
my $USB_DEVICE = 0;
my $CRYPTKEY = $EMPTY_STR;
my $VALIDATE_CRYPTKEY = 0;
my $ROOTDIR = "/";
my $TOOLSDIR = $EMPTY_STR;
my $RTIDIR = "/usr2/bbx"; # This could be changed based on 'rootdir' value.
my $DAISYDIR = "/d"; # This could be different based on 'rootdir' value.
my $MOUNTPOINT = "/mnt/backups";
my $LOGFILE = $EMPTY_STR;
my $LOGFILE_DEF = "rtibackup.log";
my $DEBUGLOGFILE = $EMPTY_STR;
my $DEBUGMODE = 0;
my $NEED_USAGE = 0; #Surely there's a better way to do this.
my $backup_returnval = -1;
my @ARGV_ORIG = @ARGV;
my $VERIFY_FAILED = 0;
my $AUTO_CHECKMEDIA = 0;
my $COMPRESS_BU = 0;
my $DECOMPRESS_BU = 0;
my $KEEP_OLD_FILES = 0;
my $GETINFO = 0;
my $DRY_RUN = 0;
my $UPGRADE = 0;
my $HARDEN_LINUX = 1;
my $BACKUP_SUMMARY_INFO = $EMPTY_STR;
my $TELEFLORA_FS_LABEL_PATTERN = 'TFBUDSK-\d{8}';

#
# Constants
#

# script exit status
my $EXIT_OK = 0;
my $EXIT_COMMAND_LINE = 1;
my $EXIT_PLATFORM = 2;
my $EXIT_ROOTDIR = 3;
my $EXIT_TOOLSDIR = 4;
my $EXIT_BACKUP_DEVICE_NOT_FOUND = 5;
my $EXIT_USB_DEVICE_NOT_FOUND = 6;
my $EXIT_BACKUP_TYPE = 7;
my $EXIT_MOUNT_ERROR = 8;
my $EXIT_RESTORE = 9;
my $EXIT_LIST = 10;
my $EXIT_DEVICE_VERIFY = 11;
my $EXIT_USB_DEVICE_UNSUPPORTED = 12;
my $EXIT_MOUNT_POINT = 13;
my $EXIT_IS_BACKUP_ENABLED = 14;
my $EXIT_SAMBA_CONF = 23;
my $EXIT_SENDTO_CONNECT = 30;
my $EXIT_SENDTO_IPADDR = 31;
my $EXIT_SENDTO_SVCTAG = 32;
my $EXIT_SENDTO_READ_ERR = 33;
my $EXIT_SENDTO_WRITE_ERR = 34;
my $EXIT_SENDTO_PIPEOPEN_ERR = 35;
my $EXIT_SECONDARY_IN_USE = 40;
my $EXIT_SECONDARY_IPADDR = 41;
my $EXIT_SECONDARY_SVCTAG = 42;
my $EXIT_SECONDARY_READ_ERR = 43;
my $EXIT_SECONDARY_WRITE_ERR = 44;
my $EXIT_SECONDARY_PIPEOPEN_ERR = 45;

my $SPACE       = q{ };
my $COMMA       = q{,};
my $COLON       = q{:};
my $ATSIGN      = q{@};
my $DOT         = q{.};
my $DOTDOT      = q{..};
my $SLASH       = q{/};
my $DASH        = q{-};
my $EQUALS      = q{=};
my $SINGLEQUOTE = q{'};

my @EMPTY_LIST = ();

# wait time for completion of md5sum calculations
my $MAX_WAIT_TIME = 3 * 60 * 60; # Seconds

# port used to communicate from primary to secondary
# not used any more
my $SECONDARY_SVR_PORT = 15020;

# the lockfile used for --checkmedia
my $LOCKFILE_NAME = "rtibackup.lock";
my $LOCKFILE_DIR = $EMPTY_STR;
my $LOCKFILE = $EMPTY_STR;

my $CRON_JOB_FILE_NAME = 'nightly-backup';
my $CRON_JOB_FILE_PATH = "/etc/cron.d/$CRON_JOB_FILE_NAME";

# Device types are:
# 1) "passport" - a Western Digital Passport USB disk
# 2) "rev"      - an IOmega Rev drive
# 3) "usb"      - a USB disk with Teleflora label
my $DEVICE_TYPE = $EMPTY_STR;

my @BACKUP_TYPES = (
	"all",
	"usr2",
	"daisy",
	"printconfigs",
	"rticonfigs",
	"daisyconfigs",
	"osconfigs",
	"netconfigs",
	"userconfigs",
	"userfiles",
	"logfiles"
);
my @RESTORE_TYPES = (@BACKUP_TYPES, "bbxd", "bbxps", "singlefiles");

#
# If a particular restore type needs to have the perms fixed, 
# it should set one of these global flags and then the perms
# will be fixed just before exit.
#
my $RUN_RTI_PERMS = 0;
my $RUN_DAISY_PERMS = 0;

#
# If the user permits it via the "--harden_linux" command line option,
# run the harden_linux.pl script after restoration of some files.
#
my $RUN_HARDEN_LINUX = 0;

#
# The name of the crypt key validation file - it is put onto a
# backup device every time a successful backup is completed.
#
my $VALIDATION_FILE = "teleflora-cryptkey-validation-20111130.dat";

#
# The name of the rtibacukp.pl setup file - it is written to the
# backup device any time it is formatted via "--format".
#
my $FORMAT_FILE = "teleflora-formatted.txt";

#
# The command line must be recorded before the GetOptions modules
# is called or any options will be removed.
#
my $COMMAND_LINE = get_command_line();

#Getopt::Long::Configure("pass_through");
GetOptions(
	"help" => \$HELP,
	"version" => \$CVS_VERSION,
	"configfile=s" => \$CONFIGFILE,
	"report-configfile" => \$REPORT_CONFIGFILE,
	"report-is-backup-enabled" => \$REPORT_IS_BACKUP_ENABLED,
	"checkmedia" => \$CHECKMEDIA,
	"email=s" => \@EMAIL,
	"printer=s" => \@PRINTER,
	"eject" => \$EJECT,
	"console" => \$CONSOLE,
	"finddev" => \$FINDDEV,
	"format" => \$FORMAT,
	"install" => \$INSTALL,
	"showkey" => \$SHOWKEY,
	"mount" => \$MOUNT,
	"unmount|umount" => \$UNMOUNT,
	"nocc" => \$NOCC,
	"backup=s" => \@BACKUP,
	"restore=s" => \@RESTORE,
	"restore-exclude=s" => \@RESTORE_EXCLUDES,
	"rootdir=s" => \$ROOTDIR,
	"daisy" => \$DAISY,
	"rti" => \$RTI,
	"list=s" => \@LIST,
	"checkfile" => \$CHECKFILE,
	"verbose" => \$VERBOSE,
	"force" => \$FORCE,
	"verify" => \$VERIFY,
	"logfile=s" => \$LOGFILE,
	"device=s" => \$DEVICE,
	"device-vendor=s" => \$DEVICE_VENDOR,
	"device-model=s" => \$DEVICE_MODEL,
	"usb-device" => \$USB_DEVICE,
	"cryptkey=s" => \$CRYPTKEY,
	"validate-cryptkey" => \$VALIDATE_CRYPTKEY,
	"autocheckmedia!" => \$AUTO_CHECKMEDIA,
	"compress" => \$COMPRESS_BU,
	"decompress" => \$DECOMPRESS_BU,
	"keep-old-files" => \$KEEP_OLD_FILES,
	"getinfo" => \$GETINFO,
	"dry-run" => \$DRY_RUN,
	"upgrade" => \$UPGRADE,
	"harden-linux!" => \$HARDEN_LINUX,
	"debugmode" => \$DEBUGMODE,
) || die "Error: invalid command line option, exiting...\n";


# --version
if ($CVS_VERSION) {
	print "OSTools Version: 1.15.0\n";
	print "$PROGNAME: $CVS_REVISION\n";
	exit($EXIT_OK);
}

# --help
if ($HELP != 0) {
	usage();
	exit($EXIT_OK);
}


# cli: --logfile
#
# There are several possibilities:
#   1) path to the logfile specified on the command line
#   2) the default name for a normal rtibackup.pl invocation
#
if ($LOGFILE eq $EMPTY_STR) {
	my $logfiledir = "/tmp";
	my $logfilename = "rtibackup-Day_%d.log";

	if (-d "$RTIDIR/log") {
		$logfiledir= "$RTIDIR/log";
	}
	if (-d "$DAISYDIR/daisy/log") {
		$logfiledir = "$DAISYDIR/daisy/log";
	}

	if ($DEBUGMODE) {

	    $DEBUGLOGFILE = "$logfiledir/rtibackup-debug.log";

	    debuglog("Starting $PROGNAME $CVS_REVISION");
	    debuglog("Invoked with command line:");
	    debuglog("$COMMAND_LINE");

	}

	$LOGFILE = strftime("$logfiledir/$logfilename", localtime());

	if ($DEBUGMODE) {
	    debuglog("\$LOGFILE = <$LOGFILE>");
	}
}

# should never get here with $LOGFILE undefined, but...
if ($LOGFILE eq $EMPTY_STR) {
	$LOGFILE = "/tmp/$LOGFILE_DEF";
}


# Rotate the log file now that we know it's name
$LOGFILE = logrotate($LOGFILE);


$OS = plat_os_version();
if ($OS eq $EMPTY_STR) {
	logerror("Unknown operating system.");
	exit($EXIT_PLATFORM);
}


# cli: --rootdir=/some/path
if (! -d "$ROOTDIR") {
	logerror("Specifed directory not found: rootdir=\"$ROOTDIR\".");
	exit($EXIT_ROOTDIR);
}


# Where do our "OSTOOLS" typically reside?
my @ostools_dir_paths = qw(
    /teleflora/ostools
    /usr2/ostools
    /d/ostools
);

foreach (@ostools_dir_paths) {
    if (-e $_) {
	$TOOLSDIR = $_;
	last;
    }
}

if ($TOOLSDIR eq $EMPTY_STR) {
    logerror("OSTools directory does not exist at: @ostools_dir_paths");
    exit($EXIT_TOOLSDIR);
}


my $begin_separator = $EQUALS x 40;
loginfo("| $begin_separator");
loginfo("| BEGIN Script $PROGNAME");
loginfo("| CVS Revision: $CVS_REVISION");
loginfo("| Command Line: $COMMAND_LINE");
loginfo("| $begin_separator");


# Read our settings from --configfile=xxxx
if ($CONFIGFILE eq $EMPTY_STR) {
	if (-e "$RTIDIR/config/backups.config") {
		$CONFIGFILE = "$RTIDIR/config/backups.config";
	}
	if (-e "$DAISYDIR/daisy/config/backups.config") {
		$CONFIGFILE = "$DAISYDIR/daisy/config/backups.config";
	}
}
if ($CONFIGFILE ne $EMPTY_STR) {
    if ($REPORT_CONFIGFILE) {
	print "reading config file: $CONFIGFILE\n";
    }

    if (read_configfile($CONFIGFILE)) {
	loginfo("config file read: $CONFIGFILE");
    }
    else {
	loginfo("error reading config file... proceeding without it: $CONFIGFILE");
    }
}


# cli: --report-configfile
# at this point, the report of the config file name and
# it's content have already been done, so since this is
# report only, then just exit now.
if ($REPORT_CONFIGFILE) {
    exit($EXIT_OK);
}


# cli: --daisy --rti
# cli: --daisy
# cli: --rti
# (Nothing specified)
# Guess which system we are on if we have not been explicitly told.
# Note that if both /usr2 and /d/daisy exist, then, we'll work with both.
if ( ($RTI == 0) && ($DAISY == 0) ) {
    if (-d "/d/daisy") {
	$DAISY = 1;
    }
    if (-d "/usr2/bbx") {
	$RTI = 1;
    }
}
# System type still not determined... this could be in the case of
# a fresh install and, no "--daisy" and no "--rti" specified
# on the commandline.
if ( ($RTI == 0) && ($DAISY == 0) ) {
    $RTI = 1;
}

if ($DAISY != 0) {
    loginfo("Assuming --daisy");
}
if ($RTI != 0) {
    loginfo("Assuming --rti");
}

#
# cli: --report-is-backup-enabled
#
# This command line option reports on whether the rtibackup.pl script
# is installed and enabled.
#
if ($REPORT_IS_BACKUP_ENABLED) {
    my $exit_status = $EXIT_OK;
    if (rb_report_is_backup_enabled()) {
	showinfo("[main] backup is installed and enabled");
    }
    else {
	showerror("[main] backup is NOT installed and enabled");
	$exit_status = $EXIT_IS_BACKUP_ENABLED;
    }
    exit($exit_status);
}

#
# Determine the lockfile for --checkmedia
#
$LOCKFILE_DIR = ($RTI) ? "$RTIDIR/config" : "$DAISYDIR/daisy/config";
if (! -d $LOCKFILE_DIR) {
    $LOCKFILE_DIR = "/tmp";
}
$LOCKFILE = "$LOCKFILE_DIR/$LOCKFILE_NAME";


# get platform info
$CURRENT_ARCH = plat_processor_arch();
$RH_VERSION = plat_redhat_version();
$KERNEL_VERSION = plat_kernel_release();
$SYS_HOSTNAME = hostname();


#
# cli: --cryptkey
#
# The crypt key can be obtained from 1 of 3 ways as outlined here,
# listed in order of precedence:
#
# 1) from the command line
# 2) from the system serial number (aka Dell Service Tag)
# 3) a default value
#
if ($CRYPTKEY eq $EMPTY_STR) {
    $CRYPTKEY = uc(hw_serial_number());
}
# Set a default crypt key if need be.
if ($CRYPTKEY eq $EMPTY_STR) {
	$CRYPTKEY = "Pwklk+82rT";
}


# cli: --install
if ($INSTALL != 0) {
	install_rtibackup();
	exit($EXIT_OK);
}


#
# verify existence of mountpoint
#
if (-d $MOUNTPOINT) {
    loginfo("mountpoint verified: $MOUNTPOINT");
}
else {
    showerror("mountpoint does not exist: $MOUNTPOINT");
    exit($EXIT_MOUNT_POINT);
}


#
# If the backup device is an image file, make sure that it exists and
# is at least $DEVICE_IMAGE_SIZE in size - arbitrary yes, but at least
# some measure of defense.
#
if ($DEVICE ne $EMPTY_STR) {
    unless (device_is_verified($DEVICE)) {
	logerror("Backup device verification error for device: $DEVICE");
	exit($EXIT_DEVICE_VERIFY);
    }
}

#
# cli: --usb-device
#
# If specifed, either find and verify a USB device, or exit.
#
if ($USB_DEVICE) {
    if ($OS eq "RHEL4") {
	showerror("USB devices other than WD Passports are not supported on $OS");
	exit($EXIT_USB_DEVICE_UNSUPPORTED);
    }
    else {
	$DEVICE = find_usb_device();
	if ($DEVICE) {
	    if (device_is_verified($DEVICE)) {
		showinfo("USB backup device with Teleflora label verified: $DEVICE");
	    }
	    else {
		showerror("Can't verify USB device: $DEVICE");
		exit($EXIT_DEVICE_VERIFY);
	    }
	}
	else {
	    showerror("Can't find USB backup device");
	    exit($EXIT_USB_DEVICE_NOT_FOUND);
	}
    }
}

#
# cli: --device
#
# If the user doesn't specify a specific device name, then, guess it.
# First, look for the "newer generation" RD1000 device, then, for the iomega rev.
if ($DEVICE eq $EMPTY_STR) {
    $DEVICE = find_passport();
    if ($DEVICE eq $EMPTY_STR) {
	$DEVICE = find_revdevice();
    }
}
if ($DEVICE eq $EMPTY_STR) {
	logerror("No backup device found.");
	if( ( ($#EMAIL >= 0) || ($#PRINTER >= 0))
	&&  ($#BACKUP >= 0) ) {
		my $info = $EMPTY_STR;
		my $subject = $EMPTY_STR;
		my $timestamp = $EMPTY_STR;
		$timestamp = strftime("%Y-%m-%d", localtime());
		$subject = "Backup $timestamp FAILED - No Device";
		$info = << "EOF";

-- Backup Device Not Found --
A backup could not be performed because a device could not be found to
store your backup onto.

If you use an Iomega REV drive, check to verify that a cartridge is
snapped into the drive, and that the drive's "active" light is not
illuminated.

If you are using a Passport drive, verify that the drive is connected to
your server by a  USB cable, and verify that the small white light is
illuminated on the side of the Passport drive.

EOF
		if($#EMAIL >= 0) {
			send_email(\@EMAIL, $subject, $info);
		} 
		if($#PRINTER >= 0) {
			print_results(\@PRINTER, $subject, $info);
		}
	}

	exit($EXIT_BACKUP_DEVICE_NOT_FOUND);
}


showinfo("[main] using backup device \"$DEVICE\"");


# cli: --getinfo
if ($GETINFO != 0) {
	exit(rb_getinfo());
}


# cli: --unmount
# cli: --umount
if ($UNMOUNT != 0) {
	$NEED_USAGE = 0;
	if ($DEVICE ne $EMPTY_STR) {
		unmount_device();
	}
}


# cli: --format
if ($FORMAT != 0) {
    $NEED_USAGE = 0;
    rb_format_device_cmd($DEVICE, \@BACKUP);
}


# cli: --mount
if ($MOUNT != 0) {
	$NEED_USAGE = 0;
	mount_device("rw");
}


# cli: --finddev
if ($FINDDEV) {
    my $device_file = $EMPTY_STR;
    my $device_type = $EMPTY_STR;
    my $formatted_line = $EMPTY_STR;

    if ($OS eq "RHEL4") {
	$device_file = "(not supported)";
    }
    else {
	$device_type = "USB Device";
	$device_file = find_usb_device();
	if ($device_file) {
	    my $fs_uuid = get_filesys_uuid($device_file);
	    $device_file .= " (filesystem UUID: $fs_uuid)";
	}
	else {
	    $device_file = "(device not found)";
	}
    }
    $formatted_line = sprintf("%15s: %s", $device_type, $device_file);
    showinfo($formatted_line);

    $device_type = "Passport Device";
    $device_file = find_passport();
    if ($device_file) {
	my $fs_uuid = get_filesys_uuid($device_file);
	$device_file .= " (filesystem UUID: $fs_uuid)";
    }
    else {
	$device_file = "(device not found)";
    }
    $formatted_line = sprintf("%15s: %s", $device_type, $device_file);
    showinfo($formatted_line);

    $device_type = "REV Device";
    $device_file = find_revdevice();
    if ($device_file) {
	my $fs_uuid = get_filesys_uuid($device_file);
	$device_file .= " (filesystem UUID: $fs_uuid)";
    }
    else {
	$device_file = "(device not found)";
    }
    $formatted_line = sprintf("%15s: %s", $device_type, $device_file);
    showinfo($formatted_line);
}


# cli: --showkey
if ($SHOWKEY != 0) {
	# Do not log this to logfile.
	print("Using CryptKey: \"$CRYPTKEY\"\n");
}


# cli: --checkmedia
if ($CHECKMEDIA != 0) {
	checkmedia();
}


# cli: --backup
# Make sure this block of code comes *after* the "mount", "unmount" and "format" blocks of code.
if ($#BACKUP >= 0) {
	$NEED_USAGE = 0;
	@BACKUP = split(/,/, join(',', @BACKUP));

	#
	# Check the backup types specified on the command line and let the user
	# know if there is an error and what the supported backup types are.
	#
	for my $backup_type (@BACKUP) {
		unless (grep(/^$backup_type$/, @BACKUP_TYPES)) {
			logerror("Error: backup type specified: $backup_type");
			logerror("Error: supported backup types: @BACKUP_TYPES");
			exit($EXIT_BACKUP_TYPE);
		}
	}


	# Default set of things to *not* backup.
	push(@EXCLUDES, "*.iso");
	push(@EXCLUDES, "*.tar.asc");
	push(@EXCLUDES, "lost+found");

	if ($RTI) {
		push(@EXCLUDES, "/usr2/*.iso");
		push(@EXCLUDES, "/usr2/*.tar.asc");
		push(@EXCLUDES, "/usr2/bbx-*");
		push(@EXCLUDES, "/usr2/bbx/*.iso");
		push(@EXCLUDES, "/usr2/bbx/log/*");
		push(@EXCLUDES, "/usr2/bbx/bbxt/*");
		push(@EXCLUDES, "/usr2/bbx/backups/*");
		push(@EXCLUDES, "/usr2/bbx/*.tar.asc");
		if($NOCC != 0) {
			showinfo("Will not include Cardholder Data in this backup.");
			push(@EXCLUDES, "CCXF01");
			push(@EXCLUDES, "CCXF02");
			push(@EXCLUDES, "ONCA01");
			push(@EXCLUDES, "bytefile");
			push(@EXCLUDES, "recv.fil");
		}
	} elsif ($DAISY) {

		# exclude some files commonly found in /d 
		push(@EXCLUDES, "/d/*.iso");
		push(@EXCLUDES, "/d/*.tar.asc");

		# exclude some files from within daisy database dirs
		determine_daisy_excludes(\@EXCLUDES);
	}

	my $begin_timestamp = strftime("%a %b %d %H:%M:%S %Y", localtime());

	$backup_returnval = backup_files();

	my $end_timestamp = strftime("%a %b %d %H:%M:%S %Y", localtime());

	$BACKUP_SUMMARY_INFO =
"#
#      Backup program: $PROGNAME $CVS_REVISION
#          Backup Set: @BACKUP
#      Backup Started: $begin_timestamp
#    Backup Completed: $end_timestamp
#
";

	#
	# if the backup was successful, write a new validation file
	#
	if ($backup_returnval == 0) {

	    my $ml = "backup";
	    if (mount_device_simple($ml, "rw")) {
		logerror("[$ml] Can't mount backup device for writing validation file: $DEVICE");
	    }

	    else {
		my $cat_cmd = "cat /etc/redhat-release";
		my $encrypt_cmd = "nice openssl aes-128-cbc -e -salt -k \"$CRYPTKEY\"";
		my $cmd = $cat_cmd . " | " . $encrypt_cmd . " > $MOUNTPOINT/$VALIDATION_FILE";

		system("$cmd");
		if ($? == 0) {
		    showinfo("[$ml] Validation file written to backup device: $DEVICE");

		    if ($DAISY) {
			daisy_log_success($DAISYDIR, $DEVICE);
		    }
		}
		else {
		    showerror("[$ml] Error writing validation file to backup device: DEVICE");
		}

		unmount_device_simple($ml);
	    }

	}
	else {
	    if ($DAISY) {
		daisy_log_failure($DAISYDIR, $DEVICE);
	    }
	}
}


# cli: --restore
if ($#RESTORE >= 0) {
	$NEED_USAGE = 0;
	@RESTORE = split(/,/, join(',', @RESTORE));

	#
	# Check the backup types specified on the command line and let the user
	# know if there is an error and what the supported backup types are.
	#
	# One exception, if the string following "--restore" has a leading '/'
	# char, ie it specifies an absolute path, then assume the restore type
	# is "singlefiles".
	#
	for my $restore_type (@RESTORE) {
		unless ($restore_type =~ /^\//) {
			unless (grep(/^$restore_type$/, @RESTORE_TYPES)) {
				logerror("Error: restore type specified: $restore_type");
				logerror("Error: supported restore types: @RESTORE_TYPES");
				exit($EXIT_RESTORE);
			}
		}
	}

	if (@RESTORE_EXCLUDES) {
		@RESTORE_EXCLUDES = split(/,/, join(',', @RESTORE_EXCLUDES));
	}

	restore_files(\@RESTORE_EXCLUDES);

	if ($HARDEN_LINUX && $RUN_HARDEN_LINUX) {
	    run_harden_linux();
	}
}


# cli: --list
if ($#LIST >= 0) {
	$NEED_USAGE = 0;
	@LIST = split(/,/, join(',', @LIST));

	#
	# Check the backup types to list that were specified on the command line and
	# let the user know if there is an error and what the supported backup types are.
	#
	for my $backup_type (@LIST) {
		unless (grep(/^$backup_type$/, @BACKUP_TYPES)) {
			logerror("Error: backup type specified: $backup_type");
			logerror("Error: supported backup types: @BACKUP_TYPES");
			exit($EXIT_LIST);
		}
	}
	list_files();
}


# cli: --checkfile
if ($CHECKFILE != 0) {
	$NEED_USAGE = 0;
	checkfile(@ARGV);
}


# cli: --verify
# cli: --verify --console
# cli: --backup --email=someone@somewhere
# Make sure this block of code comes *after* the "BACKUP" block of code.
#
if ($VERIFY) {
	my $subject = $EMPTY_STR;
	my @termnames = qw( /dev/tty0 );

	if ($RTI) {
	    @termnames = qw( /dev/tty8 );
	}
	if ($DAISY) {
	    @termnames = qw( /dev/tty11 );
	}

	$NEED_USAGE = 0;
	my $info = verify_backup();

	# add the backup summary info
	$info = $BACKUP_SUMMARY_INFO . $info;

	showinfo($info);

	if ($CONSOLE) {
	    foreach my $termname (@termnames) {
		if (open(my $con_fh, '>', $termname)) {
		    print($con_fh "\n");
		    print($con_fh "\n");
		    print($con_fh "\n");
		    print($con_fh "\n");
		    print($con_fh "\n");
		    print($con_fh "$info");
		    close($con_fh);
		}
		else {
		    showerror("Error: open of console failed: $termname");
		}
	    }
	}


	# If we specified "--backup" and "--verify" together,
	# then, we'll email the verify results only if there
	# are email addresses configured.
	if( (($#EMAIL >= 0) || ($#PRINTER >= 0)) && ($#BACKUP >= 0) ) {

	    #
	    # Errors in our verify text always start with a bunch
	    # of exclamation marks.  Note too that our email titles
	    # should be easily sortable, and, give a quick overview
	    # for the user to decide "do I even need to open this email?" 
	    #
	    my $timestamp = strftime("%Y-%m-%d", localtime());
	    if ($info =~ /[!]{7,}/) {
		$subject = "Backup $timestamp ERRORS"
	    }
	    else {
		$subject = "Backup $timestamp SUCCESS"
	    }
	    if ($#EMAIL >= 0) {
		send_email(\@EMAIL, $subject, $info);
	    }
	    if ($#PRINTER >= 0) {
		print_results(\@PRINTER, $subject, $info);
	    }
	}

	#
	# If performing a "--backup" and a "--verify" and the "--verify" fails,
	# then do a "--checkmedia" unless "--noautocheckmedia" was specified.
	#
	if ($VERIFY_FAILED && ($#BACKUP >=0) && $AUTO_CHECKMEDIA) {
	    checkmedia();
	}
}


# cli: --eject
# Make sure this block of code comes *after* the "VERIFY" block of code.
if ($EJECT != 0) {
    $NEED_USAGE = 0;

    unless ($DEVICE_TYPE eq "passport" || $DEVICE_TYPE eq "usb") {

	# --eject + --backup
	if ($#BACKUP >= 0) {

	    # eject only if backup succeeded.
	    if ($backup_returnval == 0) {
		eject_devices();
	    }

	    else {
		showinfo("Media NOT ejected: backup error $backup_returnval.");
	    }
	}

	else {
	    eject_devices();
	}
    }
}


# ejectdays is a config file item only - it is not a command line option
# Make sure this block of code comes *after* the "VERIFY" block of code.
#
# Requirements to evaluate:
#   0) ejectdays has been specified in the config file
#   1) the backup device is not a USB disk drive
#   2) there must have been a backup attempted and a verification
#
if ($EJECTDAYS ne $EMPTY_STR) {

    unless ($DEVICE_TYPE eq "passport" || $DEVICE_TYPE eq "usb") {

	if ( ($#BACKUP >= 0) && ($VERIFY != 0) ) {
	    eject_days($EJECTDAYS, $backup_returnval);
	}
    }
}


if ($RUN_RTI_PERMS) {
    set_rti_perms();
}
if ($RUN_DAISY_PERMS) {
    set_daisy_perms();
}


#
# cli: --validate-cryptkey [--cryptkey=s]
#
# Validate the value of cryptkey
#
if ($VALIDATE_CRYPTKEY) {
    my $rc = validate_crypt_key($CRYPTKEY);
    if ($rc == 0) {
	unless ($DRY_RUN) {
	    print("The crypt key is valid\n");
	}
    }
    elsif ($rc == 1) {
	unless ($DRY_RUN) {
	    print("The crypt key is invalid\n");
	}
    }
}


# Nothing specified on commandline.
if ($NEED_USAGE != 0) {
	usage();
}

exit($EXIT_OK);

#####################################################################
#####################################################################
#####################################################################


sub usage
{
	print("$PROGNAME $CVS_REVISION\n");
	print("$PROGNAME --help\n");
	print("$PROGNAME --version\n");
	print("$PROGNAME --eject\n");
	print("$PROGNAME --finddev\n");
	print("$PROGNAME --format [--force]\n");
	print("$PROGNAME --install\n");
	print("$PROGNAME --showkey\n");
	print("$PROGNAME --mount\n");
	print("$PROGNAME --unmount\n");
	print("$PROGNAME --verify [--verbose]\n");
	print("$PROGNAME --getinfo\n");
	print("$PROGNAME --report-configfile\n");
	print("$PROGNAME --report-is-backup-enabled\n");
	print("$PROGNAME --checkmedia [--email=user1\@foo.com,user2\@bar.com,...] [--printer=printer1,printer2,...] \n");
	print("$PROGNAME --[no]autocheckmedia\n");
	print("$PROGNAME --validate-cryptkey [--cryptkey=s]\n");

	#
	# The following code assumes that @BACKUP_TYPES and @RESTORE_TYPES has
	# at least one element.
	#
	my $first_elem = shift(@BACKUP_TYPES);
	print("$PROGNAME --backup=$first_elem");
	foreach my $bu_type (@BACKUP_TYPES) {
		print(",$bu_type");
	}
	unshift(@BACKUP_TYPES, $first_elem);
	print(" [--eject] [--console] [--nocc] [--email=user1\@foo.com,user2\@bar.com,...] [--printer=printer1,printer2,...] ");
	print("\n");

	$first_elem = shift(@BACKUP_TYPES);
	print("$PROGNAME --list=$first_elem");
	foreach my $bu_type (@BACKUP_TYPES) {
		print(",$bu_type");
	}
	unshift(@BACKUP_TYPES, $first_elem);
	print("\n");

	$first_elem = shift(@RESTORE_TYPES);
	print("$PROGNAME --restore=$first_elem");
	foreach my $r_type (@RESTORE_TYPES) {
		print(",$r_type");
	}
	unshift(@RESTORE_TYPES, $first_elem);
	print(" [--force] [--keep-old-files] [--rootdir=/some/path]");
	print(" [--restore-exclude=path,path,...] [--harden-linux]");
	print("\n");

	print("$PROGNAME --restore $RTIDIR/bin/killem $RTIDIR/bbxd /etc/sysconfig/network-scripts ...");
	print(" [--force] [--keep-old-files] [--rootdir=/some/path]");
	print("\n");


	print("$PROGNAME --checkfile /dir/file /dir/*.blah ...\n");
	print("\n");
	print("For any command above, you may also need one or many of the following:\n");
	print("\t--configfile=/usr2/bbx/config/backups.config\n");
	print("\t--configfile=/d/daisy/config/backups.config\n");
	print("\t--logfile=/path/to/logfile.log\n");
	print("\t--device=/dev/xxxx or --device=/path/to/imagefile.img\n");
	print("\t--device-vendor=name (from /sys/block/sd[a|b|c|d|e]/device/vendor)\n");
	print("\t--device-model=name (from /sys/block/sd[a|b|c|d|e]/device/model))\n");
	print("\t--usb-device\n");
	print("\t--cryptkey=s\n");
	print("\t--compress\n");
	print("\t--decompress\n");
	print("\t--debugmode\n");
	print("\t--daisy\n");
	print("\t--rti\n");
	print("\n");
	print("The harden_linux.pl script will be run after any of these restore types:\n");
	print("\tall, rticonfigs, daisy, daisyconfigs, osconfigs and netconfigs\n");
	print("The script will only be run once after all restores are finished.\n");
	print("To prevent harden_linux.pl from running, specify the following option:\n");
	print("\t--noharden-linux\n");
	print("\n");

	return(1);
}


#
# start the Daisy POS
#
# returns
#   1 on success
#   0 if error
#
sub daisy_start
{
    if ($OS eq 'RHEL5' || $OS eq 'RHEL6') {
	system("/sbin/init 3");
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
	    system("systemctl start $_");
	}
    }

    return(1);
}


#
# stop the Daisy POS
#
# returns
#   1
#
sub daisy_stop
{
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	system("/sbin/init 4");
	system("sleep 10");
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
	    system("systemctl stop $_");
	}
    }

    my $daisy_kill_util = "$DAISYDIR/utils/killemall";
    if (-e $daisy_kill_util) {
	system("$daisy_kill_util 2>> $LOGFILE");
    }
    else {
	logerror("[daisy_stop] Daisy utility does not exist: $daisy_kill_util");
    }

    return(1);
}


#
# can't call a daisy program unless the cwd is /d/daisy or
# there will be an error message and a hang.
#
sub daisy_chk_cwd
{
    my ($daisy_top_dir) = @_;

    my $cwd = getcwd();
    if ($cwd eq "$daisy_top_dir/daisy") {
	loginfo("cwd ok for calling Daisy programs: $cwd");
    }
    else {
	showerror("cwd is not $daisy_top_dir/daisy thus can not call Daisy programs: $cwd");
	return(0);
    }

    return(1);
}


sub daisy_log_success
{
    my ($daisy_top_dir, $device) = @_;

    my $ml = '[daisy_log_success]';

    my $current_dir = getcwd;
    if (chdir("$daisy_top_dir/daisy")) {
	showinfo("$ml current working directory changed to: $daisy_top_dir/daisy");
	my $daisy_log_cmd = "$daisy_top_dir/daisy/logevent";
	if (-e $daisy_log_cmd) {
	    system("$daisy_log_cmd nEventSuccessfulBackup 0 \"\" SYS rtibackup.pl \"Backup succeeded: $device\"");
	    if ($? == 0) {
		showinfo("$ml successful backup msg logged via: $daisy_log_cmd");
	    }
	    else {
		showerror("$ml $daisy_log_cmd returned non-zero exit status: $?");
	    }
	}
	if (chdir($current_dir)) {
	    showinfo("$ml current working directory changed back to: $current_dir");
	}
	else {
	    showerror("$ml could not chdir back to $current_dir: $!");
	}
    }
    else {
	showerror("$ml could not chdir to $daisy_top_dir/daisy: $!");
    }

    return(1);
}

sub daisy_log_failure
{
    my ($daisy_top_dir, $device) = @_;

    my $ml = '[daisy_log_failure]';

    my $current_dir = getcwd;
    if (chdir("$daisy_top_dir/daisy")) {
	showinfo("$ml current working directory changed to: $daisy_top_dir/daisy");
	my $daisy_action_cmd = "$daisy_top_dir/daisy/actions";
	my $daisy_log_cmd = "$daisy_top_dir/daisy/logevent";
	if (-e $daisy_action_cmd) {
	    system("$daisy_action_cmd naIfailedBackup 3 0 \"\" rtibackup.pl \"Backup failed: $device.  This is a serious problem.\rPlease be sure to rotate backup media\rPlease contact Daisy support if this problem persists.\"");
	    if ($? != 0) {
		showinfo("$ml backup failure action recorded via: $daisy_action_cmd");
	    }
	    else {
		showerror("$ml $daisy_action_cmd returned non-zero exit status: $?");
	    }
	    system("$daisy_log_cmd nEventFailedBackup 0 \"\" SYS rtibackup.pl \"Backup failure: $device\"");
	    if ($? == 0) {
		showinfo("$ml backup failure logged via: $daisy_log_cmd");
	    }
	    else {
		showerror("$ml $daisy_log_cmd returned non-zero exit status: $?");
	    }
	}
	if (chdir($current_dir)) {
	    showinfo("$ml current working directory changed back to: $current_dir");
	}
	else {
	    showerror("$ml could not chdir back to $current_dir: $!");
	}
    }
    else {
	showerror("$ml could not chdir to $daisy_top_dir/daisy: $!");
    }

    return(1);
}


#
# Verify that the backup device path is either a block device or
# the path to an image file of at least a minimum size.
#
# Return TRUE if backup device path is verified
# Return FALSE if not
#
sub device_is_verified
{
    my ($device_path) = @_;

    if (-b $device_path) {
	return(1);
    }

    elsif (-f $device_path) {
	if ((-s $device_path) >= $DEVICE_IMAGE_FILE_MIN) {
	    return(1);
	}
	else {
	    logerror("Backup image file less then minimum size: $DEVICE_IMAGE_FILE_MIN bytes");
	}
    }

    else {
	logerror("Backup device must be a block device or an existing image file");
    }

    return(0);
}


sub rb_format_device_cmd
{
    my ($device, $backup_list) = @_;

    my $rc = 1;

    # Format the device if "--backup=list" specified and can't find
    # a filesystem UUID.
    if (scalar(@{$backup_list})) {
	if (get_filesys_uuid($device)) {
	    showinfo("format unnessary, backup device is already formatted: $device");
	}
	else {
	    # Unconditional format.
	    rb_device_format_ext2("format", 1);
	}
    }
    else {
	# --force --format will not ask questions.
	if ($FORCE) {
	    rb_device_format_ext2("format", 1);
	}
	else {
	    rb_device_format_ext2("format", 0);
	}
    }

    return($rc);
}


#
# Format the backup device using Linux EXT2 Filesystem.
# Note that this supports either block devices, or image files.
#
sub rb_device_format_ext2
{
    my ($ml, $force) = @_;

    my $returnval = 0;
    my $answer = "";
    my $uuid = "";

    if ($DEVICE eq "") {
	logerror("[$ml] backup device not specified");
	return(-2);
    }

    unless (device_is_verified($DEVICE)) {
	logerror("[$ml] could not verify backup device path: $DEVICE");
	return(-3);
    }

    unless (-d $MOUNTPOINT) {
	logerror("[$ml] mount point does not exist: $MOUNTPOINT");
	return(-4);
    }

    # Don't format a mounted drive.
    if (device_is_mounted()) {
	logerror("[$ml] backup device is mounted. Please unmount before formatting.");
	return(-5);
    }

    my $device_type = "device";
    $device_type = "image file" if (-f $DEVICE);

    my $begin_timestamp = strftime("%a %b %d %H:%M:%S %Y", localtime());

    showinfo("[$ml] Formatting $device_type: $DEVICE");

    #
    # Verify that the user wants to format the disk. If "force" is in place, then
    # just format.
    #
    if ($force == 0) {
	$answer = "";
	while (1) {
	    if (-b "$DEVICE") {
		print("Format Backup Device \"$DEVICE\"?\n");
	    }
	    elsif (-f "$DEVICE") {
		print("Format Backup Image File \"$DEVICE\"?\n");
	    }
	    else {
		logerror("[$ml] Can't format - device is not a file or block device: $DEVICE");
		return(-3);
	    }
	    print("(Y/N) >");
	    $answer = <STDIN>;
	    chomp($answer);
	    last if ("$answer" =~ /^n/i);
	    last if ("$answer" =~ /^y/i);
	}

	# anything but 'yes'.
	if ($answer !~ /^y/i) {
	    return(0);
	}
    }


    # Determine the "old" UUID (if any).  If there is no old UUID,
    # then by setting the value to "random", it will cause the
    # tune2fs command to generate a new UUID for the file system.

    $uuid = get_filesys_uuid($DEVICE);
    if ($uuid eq "") {
	$uuid = "random";
    }

    #
    # Put a file system on the device.
    #
    # Note that, under RHEL5 at least, these same commands work equally
    # whether talking to a block device or a file. "mkfs.ext2" and "tune2fs"
    # transparently figure out whether loopback devices are needed.
    #
    # Make the disk label something that can be searched for and
    # recognized as a disk being used as a Teleflora backup device.
    # A disk label can be a maximum of 16 chars, so make it:
    #
    #       |<---- 16 ---->|
    #       |     chars    |
    #	    TFBUDSK-YYYYMMDD
    #
    # which would be the string "TFBUDSK" followed by a date stamp.
    # "TFBUDSK" stands for "Teleflora Backup Disk".  The disk label
    # can be read with the e2label command.

    my $label_brand = "TFBUDSK";
    my $label_datestamp = strftime("%Y%m%d", localtime());
    my $label_disk = $label_brand . "-" . $label_datestamp;

    showinfo("[$ml] Making an EXT2 file system on $device_type: $DEVICE");
    if ($VERBOSE) {
	showinfo("[$ml] CLI: /sbin/mkfs.ext2 -F -L $label_disk $DEVICE");
    }
    system("/sbin/mkfs.ext2 -F -L $label_disk $DEVICE 2>> $LOGFILE");
    $returnval = $?;
    showinfo("[$ml] Completed make of an EXT2 file system");
    if ($returnval != 0) {
	showerror("[$ml] The command to make an EXT2 file system exited with error: $!");
	showerror("[$ml] The $device_type was not formatted: $DEVICE");
    }
    else {
	showinfo("[$ml] Setting tuning parameters for $device_type: $DEVICE");
	if ($VERBOSE) {
	    showinfo("[$ml] Setting max mount count to 0, thus disabling it");
	    showinfo("[$ml] Setting error behavior to \"remount read-only on error\"");
	    showinfo("[$ml] Setting FSCK interval to 12 months");
	    showinfo("[$ml] Setting UUID of file system to: $uuid");
	    showinfo("[$ml] CLI: /sbin/tune2fs -c 0 -e remount-ro -i 12m -U $uuid $DEVICE");
	}
	system("/sbin/tune2fs -c 0 -e remount-ro -i 12m -U $uuid $DEVICE 2>> $LOGFILE");
	if ($returnval != 0) {
	    showerror("[$ml] could not tune2fs $device_type: $DEVICE");
	}
	else {
	    showinfo("[$ml] tuning parameters set");
	}

	my $end_timestamp = strftime("%a %b %d %H:%M:%S %Y", localtime());

	showinfo("[$ml] format complete");

	showinfo("[$ml] Setting up $PROGNAME framework on $device_type: $DEVICE");

	#
	# Write format info to newly formatted device and make framework
	# expected by script.
	#

	if (mount_device_simple($ml, "rw")) {
	    logerror("[$ml] Could not mount $device_type after formatting: $DEVICE");
	    $returnval = -6;
	}
	else {

	    showinfo("[$ml] Writing files to $device_type: $DEVICE");

	    my $format_info =
"#
#      Backup program: $PROGNAME $CVS_REVISION
#         Device type: $device_type $DEVICE
#      Format Started: $begin_timestamp
#    Format Completed: $end_timestamp
#
";
	    my $format_file_path = $MOUNTPOINT . '/' . $FORMAT_FILE;
	    if (open(my $ff_fh, '>', $format_file_path)) {
		print($ff_fh $format_info);
		close($ff_fh);
	    }
	    else {
		showerror("[$ml] error writing format info file to: $DEVICE");
	    }

	    mkdir("$MOUNTPOINT/configs");

	    showinfo("[$ml] Completed writing files");

	    unmount_device_simple($ml);

	    showinfo("[$ml] Completed setup of $PROGNAME framework");
	}
    }

    return($returnval);
}


sub make_tempfile
{
        my ($prefix) = @_;

        my $tmpfile = qx(mktemp $prefix.XXXXXXX);
        chomp($tmpfile);
        if ($tmpfile eq "") {
                $tmpfile = "$prefix" . '.' . strftime("%Y%m%d%H%M%S", localtime());
        }

        return($tmpfile);
}


sub get_free_space
{
    my ($mount_point) = @_;

    my $available = 0;
    my $ref = OSTools::Filesys::filesys_df($mount_point);

    if (exists($ref->{available})) {
	$available = $ref->{available};
    }
    else {
	showerror("error getting available space of filesystem at: $mount_point");
    }

    return($available);
}


#
# use file(1) to determine if file has compressed data.
#
# Returns
#   1 if file compressed
#   0 if file not compressed
#
sub is_file_compressed
{
    my ($file_path) = @_;

    my $rc = 0;

    my $cmd = "file";
    if (open(my $pipe_fh, '-|', "$cmd $file_path")) {
	while (<$pipe_fh>) {
	    if (/compressed data/) {
		$rc = 1;
		last;
	    }
	}
	close($pipe_fh);
    }
    else {
	logerror("error opening file to determine compression: $file_path");
    }

    return($rc);
}


#
# Read up to the first 1MB of the backup file to determine
# whether it is a compressed file or not.
#
# Returns
#   1 if file compressed
#   0 if file not compressed
#   -1 on error
#
sub is_compressed
{
    my ($bu_file) = @_;

    my $rc = 1;

    #
    # per platform temp file dir:
    #
    my $prefix = "/tmp";
    if ($RTI) {
	$prefix = "/usr2/bbx/backups";
    }
    elsif ($DAISY) {
	$prefix = "/d/daisy/backups";
    }
    unless (-d $prefix) {
	$prefix = "/tmp";
    }
    unless (-d $prefix) {
	logerror("error locating temp file directory: $prefix");
	return(-1);
    }

    my $tmpfile = make_tempfile($prefix);

    my $decrypt_cmd = "openssl aes-128-cbc -d -salt -k \"$CRYPTKEY\"";

    my $undo_cmd = "cat $bu_file | " . $decrypt_cmd;

    my $bytes_read = 0;
    my $bytes_written = 0;
    my $sum = 0;
    my $buffer = "";
    my $maxread = 1000000;

    if (open(my $src_pipe_fh, '-|', $undo_cmd)) {	
	if (open(my $dst_fh, '>', $tmpfile)) {

	    while(1) {
		$bytes_read = sysread($src_pipe_fh, $buffer, $maxread);
		if ($bytes_read == 0) {
		    last;
		}
		if ($bytes_read < 0) {
		    logerror("Error \"$!\" reading from pipe process.");
		    $rc = -1;
		    last;
		}
		$bytes_written = syswrite($dst_fh, $buffer, $bytes_read);
		if (! defined($bytes_written)) {
		    logerror("Error \"$!\" writing to $tmpfile.");
		    $rc = -1;
		    last;
		}
		$sum += $bytes_read;
		last if ($sum >= $maxread);
	    }
	    close($dst_fh);

	    # drain pipe to avoid error message
	    while (<$src_pipe_fh>) {
	    }

	    if ($rc == 1) {
		$rc = is_file_compressed($tmpfile);
	    }
	}
	else {
	    logerror("error opening destination tmpfile: $tmpfile");
	    $rc = -1;
	}

	close($src_pipe_fh);
    }
    else {
	logerror("error opening pipe to decrypt cmd: $undo_cmd");
	$rc = -1;
    }

    unlink($tmpfile);

    return($rc);
}


#
# Get info about the backup set on the backup device
#
sub rb_getinfo
{
	loginfo("Get Info about Backups");

	# Verify there is a backup device.
	if ($DEVICE eq "") {
		logerror("Backup device not specified or unknown.");
		return($EXIT_BACKUP_DEVICE_NOT_FOUND);
	}

	# Verify the backup device can be mounted.
	my $ml = "getinfo";
	mount_device_simple($ml, "ro");
	if (!device_is_mounted()) {
		return($EXIT_MOUNT_ERROR);
	}

	my $uuid = get_filesys_uuid($DEVICE);

	print("Using config file: $CONFIGFILE\n");
	print("Backup device: $DEVICE\n");
	print("Backup UUID: $uuid\n");

	my $free_space = get_free_space($MOUNTPOINT);
	print("Backup free space: $free_space KB\n");

	my @backup_files = qw(
		configs/printconfigs.bak
		configs/rticonfigs.bak
		configs/dsyconfigs.bak
		configs/osconfigs.bak
		configs/userconfigs.bak
		usr2.bak
		daisy.bak
		userfiles.bak
		logfiles.bak
	);

	foreach my $backup_file (@backup_files) {

		my $bu_file_path = "$MOUNTPOINT/$backup_file";

		unless (-f $bu_file_path) {
		    next;
		}

		my $file_is_compressed = is_compressed($bu_file_path);

		if ($file_is_compressed == -1) {
		    logerror("$backup_file: error determining compression");
		    next;
		}

		print "$backup_file: ";

		if ($file_is_compressed == 0) {
		    print "not ";
		}
		print "compressed\n";
	}

	unmount_device_simple($ml);

	loginfo("---- END Get Info about Backups ----");

	return($EXIT_OK);
}


sub set_signal_handlers
{
	my ($handler) = @_;

	$SIG{'STOP'} = $handler;
	$SIG{'TSTP'} = $handler;
	$SIG{'INT'} = $handler;

	return(1);
}


#
# Run filesystem check, and media check, to ensure the disk is OK.
# This is intended as a tool to run if we believe the cartridge, or
# perhaps, the rev drive, is "bad".
#
sub checkmedia
{
	loginfo("Check Backup Media");

	# Handle signals.
	set_signal_handlers('IGNORE');

	unless (sysopen(LFH, $LOCKFILE, O_EXCL|O_CREAT)) {
	    showinfo("Lockfile exists, resource in use, try again later: $LOCKFILE");
	    set_signal_handlers('DEFAULT');
	    return;
	}
	close(LFH);

	# Don't format a mounted drive.
	if (device_is_mounted()) {
		unmount_device();
	}
	if (device_is_mounted()) {
		logerror("Error: could not unmount backup device. Please --unmount first.");
		unlink($LOCKFILE);
		set_signal_handlers('DEFAULT');
		return(-3);
	}

	# On RHWS5, this works when "DEVICE" is either a block device or file.
	# "e2fsck" figures out whether to use a loopback device.
	showinfo("Checking Filesystem and disk for errors. This will take a long time.");
	showinfo("Results will be logged.");
	if($#EMAIL >= 0) {
		showinfo("Results will also be emailed to \"@EMAIL\"");
	}
	if($#PRINTER >= 0) {
		showinfo("Results will also be printed on printer(s): \"@PRINTER\"");
	}

	# If we run '--checkmedia' and '--backup=blah' at the same time, then,
	# don't fork 'checkmedia' into the background. This allows our cron tasks
	# to run a nightly "checkmedia" before running the backup. Doing so better
	# ensures that backups will always succeed.
	my $pid = -1;
	if ($#BACKUP >= 0) {
		$pid = 0;
	}
	else {
		$pid = fork();
	}

	# parent
	if ($pid > 0) {
		showinfo("Checkdisk background process started as PID $pid");
		set_signal_handlers('DEFAULT');
	}

	# child
	elsif ($pid == 0) {

		my $subject = "";
		my $results = "";
		my $tapeid = "";

		$tapeid = get_filesys_uuid($DEVICE);
		$results =  "---------------------------------\n";
		$results .= "--  $PROGNAME --checkmedia Results\n";
		$results .= "--  PID: $$\n";
		$results .= "--  Tape ID: $tapeid\n";
		$results .= "--  Start Time:" . localtime() . "\n";
		$results .= "---------------------------------\n";
		$results .= "\n";

		if (open(my $fsck_fh, '-|', "/sbin/e2fsck -v -y -c $DEVICE 2>&1")) {
		    while (<$fsck_fh>) {
			$results .= <$fsck_fh>;
		    }
		    close($fsck_fh);
		    loginfo("Checkdisk (PID $$) Complete.\n$results\n");
		}
		else {
		    logerror("error opening pipe to fsck for: $DEVICE");
		}


		# Do not email checkmedia results in the event that we are also
		# backing up (nightly backups.)
		if ( ($#EMAIL >= 0) && ($#BACKUP < 0) ) {
			$subject = "Backup Media Checkdisk Results";
			send_email(\@EMAIL, $subject, $results);
			loginfo("Checkdisk email sent to @EMAIL");
		}

		# Do not print checkmedia results in the event that we are also
		# backing up (nightly backups.)
		if ( ($#PRINTER >= 0) && ($#BACKUP < 0) ) {
			$subject = "Backup Media Checkdisk Results";
			print_results(\@PRINTER, $subject, $results);
			loginfo("Checkdisk results sent to printer(s): @PRINTER");
		}

		unlink($LOCKFILE);

		#
		# If not run with "--backup", then this code was forked,
		# so don't return to mainline processing, just exit.
		#
		if ($#BACKUP < 0) {
		    exit(0);
		}
		set_signal_handlers('DEFAULT');
	}

	return(1);
}


sub eject_days
{
    my ($eject_days, $backup_returnval) = @_;

    if ($eject_days =~ /always/i) {
	my $backup_status = ($backup_returnval != 0) ? "Backup NOT succssful" : "Successful backup";
	showinfo("$backup_status... ejecting media: because ejectdays is set to 'always'.");
	eject_devices();
    }

    elsif ($backup_returnval != 0) {
	# Don't eject if the backup failed.
	showinfo("Backup NOT successful... media NOT ejected: backup error $backup_returnval.");
    }

    elsif ($eject_days =~ /never/i) {
	showinfo("Successful backup... media NOT ejected: because ejectdays is set to 'never'.");
    }

    else {
	# Eject if our "eject days" matches.
	my $today = lc(strftime("%a", localtime()));
	if ($eject_days =~ /$today/i) {
	    showinfo("Successful backup... ejecting media: because $today is an eject day.");
	    eject_devices();
	} else {
	    showinfo("Successful backup... media NOT ejected: because $today is NOT an eject day.");
	}
    }
    
    return(1);
}


#
# Eject rev devices.
#
sub eject_devices
{
	my $tapeid = "";

	if ( (($DEVICE ne "") && ($DEVICE_TYPE eq "passport")) ||
	     (($DEVICE ne "") && ($DEVICE_TYPE eq "usb")) ) {
		showinfo("Only REV devices can be ejected");
		return(0);
	}

	if ( ($DEVICE ne "") &&  (-b $DEVICE) ) {

		$tapeid = get_filesys_uuid($DEVICE);
		showinfo("Ejecting Device $DEVICE ($tapeid)");
		system("eject $DEVICE > /dev/null 2>> $LOGFILE");
	}

	return($?);
}


#
# Backup Files.
#
# The backup of all backup types funnels through this function.
#
sub backup_files
{
	my @array = ();
	my $returnval = 0;
	my $total_returnval = 0;
	my $pid = -1;
	my $kid = -1;
	my $i = 0;

	my $ml = '[backup_files]';

	# No need to backup to the backup device if we don't even know what that is.
	if ($DEVICE eq "") {
		return(-2);
	}

	# Verify the backup device is accessible via mount
	showinfo("$ml verifying backup device accessible via mount...");
	mount_device("rw");
	if (device_is_mounted()) {
		showinfo("$ml verified backup device accessible via mount: $DEVICE");
	}
	else {
		showerror("$ml error verifying backup device accessible via mount: $DEVICE");
		return(-1);
	}

	#RTI and (--backup=all or --backup=usr2)
	$returnval = 0;
	if(($total_returnval == 0)
	&& ($RTI != 0)
	&& ((grep(/^usr2$/, @BACKUP))
	|| (grep(/^all$/, @BACKUP)))) {
		$returnval = backup_usr2();
		if($returnval != 0) {
			logerror("$ml backup_usr2() returned $returnval");
		}
	}
	$total_returnval += $returnval;


	#DAISY and (--backup=all or --backup=daisy)
	$returnval = 0;
	if(($total_returnval == 0)
	&& ($DAISY != 0)
	&& ( (grep(/^daisy$/, @BACKUP)) || (grep(/^all$/, @BACKUP)) )) {
		$returnval = backup_daisy();
		if($returnval != 0) {
			logerror("$ml backup_daisy() returned $returnval");
		}
	}
	$total_returnval += $returnval;


	#--backup=all
	#--backup=printconfigs
	$returnval = 0;
	if(($total_returnval == 0)
	&& ((grep(/^printconfigs$/, @BACKUP))
	|| (grep(/^all$/, @BACKUP)))) {
		$returnval = backup_printconfigs();
		if($returnval != 0) {
			logerror("$ml backup_printconfigs() returned $returnval");
		}
	}
	$total_returnval += $returnval;

	#RTI and (--backup=all or --backup=rticonfigs)
	$returnval = 0;
	if(($total_returnval == 0)
	&& ($RTI != 0)
	&& ((grep(/^rticonfigs$/, @BACKUP))
	|| (grep(/^all$/, @BACKUP)))) {
		$returnval = backup_rticonfigs();
		if($returnval != 0) {
			logerror("$ml backup_rticonfigs() returned $returnval");
		}
	}
	$total_returnval += $returnval;

	#DAISY and (--backup=all or --backup=daisyconfigs)
	$returnval = 0;
	if(($total_returnval == 0)
	&& ($DAISY != 0)
	&& ((grep(/^daisyconfigs$/, @BACKUP))
	|| (grep(/^all$/, @BACKUP)))) {
		$returnval = backup_dsyconfigs();
		if($returnval != 0) {
			logerror("$ml backup_dsyconfigs() returned $returnval");
		}
	}
	$total_returnval += $returnval;

	#--backup=all
	#--backup=userconfigs
	$returnval = 0;
	if(($total_returnval == 0)
	&& ((grep(/^userconfigs$/, @BACKUP))
	|| (grep(/^all$/, @BACKUP)))) {
		$returnval = backup_userconfigs();
		if($returnval != 0) {
			logerror("$ml backup_userconfigs() returned $returnval");
		}
	}
	$total_returnval += $returnval;


	#--backup=all
	#--backup=netconfigs
	$returnval = 0;
	if( ($total_returnval == 0)
	&& ((grep(/^netconfigs$/, @BACKUP))
	|| (grep(/^all$/, @BACKUP)))) {
		$returnval = backup_netconfigs();
		if($returnval != 0) {
			logerror("$ml backup_netconfigs() returned $returnval");
		}
	}
	$total_returnval += $returnval;


	#--backup=all
	#--backup=osconfigs
	$returnval = 0;
	if( ($total_returnval == 0)
	&& ((grep(/^osconfigs$/, @BACKUP))
	|| (grep(/^all$/, @BACKUP)))) {
		$returnval = backup_osconfigs();
		if($returnval != 0) {
			logerror("$ml backup_osconfigs() returned $returnval");
		}
	}
	$total_returnval += $returnval;


	#--backup=all
	#--backup=userfiles
	$returnval = 0;
	if( ($total_returnval == 0)
	&& ((grep(/^userfiles$/, @BACKUP))
	|| (grep(/^all$/, @BACKUP)))) {
		$returnval = backup_userfiles();
		if($returnval != 0) {
			logerror("$ml backup_userfiles() returned $returnval"); }
	}
	$total_returnval += $returnval;


	#--backup=all
	#--backup=logfiles
	$returnval = 0;
	if( ($total_returnval == 0)
	&& ((grep(/^logfiles$/, @BACKUP))
	|| (grep(/^all$/, @BACKUP)))) {
		$returnval = backup_logfiles();
		if($returnval != 0) {
			logerror("$ml backup_logfiles() returned $returnval"); }
	}
	$total_returnval += $returnval;

	#
	# There was an error. Log information which could help post-mortem the problem.
	# Do this *before* we unmount the drive.
	#
	if ($total_returnval != 0) {
		logerror("$ml an error occurred during backup.");
	}

	# How much space is left?
	my $ref = OSTools::Filesys::filesys_df($MOUNTPOINT);

	if (exists($ref->{blocks})) {
	    my $blocks = $ref->{blocks};
	    my $available = $ref->{available};

	    my $total_bu_space = int($blocks / 1024);
	    my $free_space_percent = int(100 * ($available/$blocks));
	    loginfo("$ml total backup space: $total_bu_space MB. percent free: $free_space_percent");
	}

	# Copy the backup script onto our backup media, which will a
	# bare-metal restore possible but there is not workflow that
	# currently makes use of the capability.  This is relatively
	# safe from the PCI perspective, as the service tag number
	# is used for the cryptkey and thus 'hard coded' into the
	# backup script.
	system("cp $0 $MOUNTPOINT");


	# Once the backup is finished, umount the drive.
	unmount_device();

	return($total_returnval);
}


#
# Daisy POS can have one or more daisy db dirs.
#
sub get_daisy_db_dirs
{
    my @daisy_db_dirs = ();

    # if not a Daisy system, then list is empty, we are done
    unless (-d "/d/daisy") {
	return(@daisy_db_dirs);
    }

    my @d_dirs = glob("/d/*");

    for my $d_dir (@d_dirs) {

	# must be a directory
	next unless (-d $d_dir);

	# skip old daisy dirs
	next if ($d_dir =~ /.+-\d{12}$/);

	# must contain the magic files
	next unless(-e "$d_dir/flordat.tel");
	next unless(-e "$d_dir/control.dsy");

	# must be daisy 8.0+
	next unless (-d "$d_dir/bin");

	push(@daisy_db_dirs, $d_dir);
    }

    return(@daisy_db_dirs);
}


#
# Add excludes for all the daisy database dirs to the global
# list of excluded paths.
#
sub determine_daisy_excludes
{
    my ($global_excludes) = @_;

    my @daisy_db_dirs = get_daisy_db_dirs();

    foreach my $daisy_db_dir (@daisy_db_dirs) {
	push(@{$global_excludes}, "${daisy_db_dir}-*");
	push(@{$global_excludes}, "${daisy_db_dir}/*.iso");
	push(@{$global_excludes}, "${daisy_db_dir}/*.tar.asc");
	push(@{$global_excludes}, "${daisy_db_dir}/log/*");
    }

    return(1);
}


sub read_users_file
{
    my ($users_file) = @_;

    my %users_tab = ();

    if (open(my $uf_fh, '<', $users_file)) {
	while (my $line = <$uf_fh>) {
	    if ($line =~ /^(\S+)\s/) {
		$users_tab{$1} = 1;
	    }
	    if ($line =~ /^(\S+)\s.*RTI Admin/) {
		$users_tab{$1} = 2;
	    }
	}
	close($uf_fh);
    }
    else {
	logerror("error opening users file: $users_file");
    }

    return(%users_tab);
}


sub backup_users_info
{
    my $users_file;
    my $users_cmd;
    my $rc = 1;

    if (-f "$RTIDIR/bin/rtiuser.pl") {
	$users_file = "$MOUNTPOINT/configs/rtiusers.txt";
	$users_cmd = "$RTIDIR/bin/rtiuser.pl";
    }
    elsif (-f "$DAISYDIR/daisy/bin/dsyuser.pl") {
	$users_file = "$MOUNTPOINT/configs/dsyusers.txt";
	$users_cmd = "$DAISYDIR/daisy/bin/dsyuser.pl";
    }

    system("$users_cmd --list > $users_file 2>> $LOGFILE");

    my %users_tab = read_users_file($users_file);

    if (open(my $src_fh, '<', "/etc/shadow")) {
	if (open(my $out_fh, '>', "$MOUNTPOINT/configs/usersinfo.txt")) {
	    while (<$src_fh>) {
		my $i = index($_, ":");
		my $username = substr($_, 0, $i);
		if (defined($users_tab{$username})) {
		    print $out_fh $_;
		}
	    }
	    close($out_fh);
	}
	else {
	    logerror("error opening users info file: usersinfo.txt");
	}
	close($src_fh);
    }
    else {
	logerror("error opening shadow file: /etc/shadow");
    }

    unless (-s "$MOUNTPOINT/configs/usersinfo.txt") {
	$rc = 0;
    }

    return($rc);
}


sub backup_userconfigs
{
	my @toback = ();

	showinfo("BEGIN Backup of User Configs...");

	unless (backup_users_info()) {
	    logerror("non-fatal error: can't backup users info");
	}

	#
	# Save files that have to do with users.
	#
	@toback = qw(
		/etc/pam.d
		/etc/shadow
		/etc/shadow-
		/etc/gshadow
		/etc/passwd
		/etc/passwd-
		/etc/group
		/etc/login.defs
		/etc/sudoers
		/etc/cron.d/nightly-backup
		/var/spool/cron
		/home
		/root
	);

	if ($OS eq 'RHEL5') {
		push(@toback, "/var/log/faillog");
	}
	if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
		push(@toback, "/var/log/tallylog");
	}

	if (-d "$RTIDIR") {
	    my @rti_cron_files = glob("/etc/cron.d/rti*");
	    foreach (@rti_cron_files) {
		push(@toback, $_);
	    }
	}
	if (-d "$DAISYDIR") {
	    my @daisy_cron_files = glob("/etc/cron.d/daisy*");
	    foreach (@daisy_cron_files) {
		push(@toback, $_);
	    }
	}

	create_tarfile(\@toback, \@EXCLUDES, "$MOUNTPOINT/configs/userconfigs.bak");


	loginfo("END Backup of User Configs");

	return(0);
}


sub backup_printconfigs
{
	my @toback = ();

	if(! -d "$MOUNTPOINT/configs") {
		mkdir("$MOUNTPOINT/configs");
	}

	showinfo("BEGIN Backup of Printer Configs...");

	# Printer Configs
	@toback = ();
	push(@toback, "/etc/printcap ");
	push(@toback, "/etc/cups");
	if (-f "$RTIDIR/config/config.bbx") {
		push(@toback, "$RTIDIR/config/config.bbx");
	}

	create_tarfile(\@toback, \@EXCLUDES, "$MOUNTPOINT/configs/printconfigs.bak");


	loginfo("END Backup of Printer Configs");

	return(0);
}



sub backup_osconfigs
{
	my @toback = ();
	my $returnval = 0;

	if(! -d "$MOUNTPOINT/configs") {
		mkdir("$MOUNTPOINT/configs");
	}

	showinfo("BEGIN Backup of OS Configs...");

	# OS Configs
	@toback = ();

	my @common_files = (
	    "/etc/ssh",		    # tfremote
	    "/etc/samba",
	    "/etc/mail",	    # RTI v12 outbound emails
	    "/etc/cron.d",
	    "/etc/log.d",
	    "/etc/sysconfig/rhn",
	    "/etc/yum",
	    "/etc/yum.conf",
	    "/etc/yum.repos.d",
	    "/etc/inittab",
	);

	# contains setting for kernel log message priority for console
	if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	    push(@common_files, '/etc/rsyslog.conf');
	}
	else {
	    push(@common_files, '/etc/sysconfig/syslog');
	}

	# check for optional files or directories
	my @possible_files = (
	    '/etc/httpd',	    # web server config directory
	    '/usr/src/redhat'	    # source directory
	);
	foreach (@possible_files) {
	    if (-e $_) {
		push(@common_files, $_);
	    }
	}

	foreach (@common_files) {
	    if (-e $_) {
		push(@toback, $_);
	    }
	    else {
		loginfo("Skipping backup of \"$_\". File not found.");
	    }
	}

	$returnval += create_tarfile(\@toback, \@EXCLUDES, "$MOUNTPOINT/configs/osconfigs.bak");


	# Master boot record.
	logdebug("Saving Master Boot Record...");
	system("dd if=/dev/sda of=$MOUNTPOINT/configs/sda-mbr.img bs=512 count=1 2>> $LOGFILE");
	system("/sbin/sfdisk -d > $MOUNTPOINT/configs/sfdisk-layout.txt 2>> $LOGFILE");
	system("mount > $MOUNTPOINT/configs/mount-layout.txt 2>> $LOGFILE");


	# "OS" configs. Just in case.
	# This is an advanced item in case we need it.
	# Restoring from this, you should know what you are doing.
	logdebug("Saving /etc...");
	@toback = ();
	push(@toback, "/etc"); # Just in case we miss something below.
	$returnval += create_tarfile(\@toback, \@EXCLUDES, "$MOUNTPOINT/configs/etc.bak");


	loginfo("END Backup of OS Configs");

	return($returnval);
}



sub backup_netconfigs
{
	my @toback = ();
	my $returnval = 0;

	if(! -d "$MOUNTPOINT/configs") {
		mkdir("$MOUNTPOINT/configs");
	}

	showinfo("BEGIN Backup of Network Configs...");

	# Network Configs
	@toback = ();
	push(@toback, "/etc/hosts");
	push(@toback, "/etc/hosts.allow");
	push(@toback, "/etc/hosts.deny");
	push(@toback, "/etc/resolv.conf");
	push(@toback, "/etc/ssh");
	push(@toback, "/etc/sysconfig/iptables");
	push(@toback, "/etc/sysconfig/network");
	push(@toback, "/etc/sysconfig/network-scripts/ifcfg*");

	if (-d '/etc/sysconfig/networking/profiles') {
	    push(@toback, '/etc/sysconfig/networking/profiles');
	}

	# this path does not exist on all platforms
	my @net_devices_dir = glob("/etc/sysconfig/networking/devices/ifcfg*");
	if (@net_devices_dir) {
	    push(@toback, "/etc/sysconfig/networking/devices/ifcfg*");
	}

	$returnval += create_tarfile(\@toback, \@EXCLUDES, "$MOUNTPOINT/configs/netconfigs.bak");


	loginfo("END Backup of Network Configs");

	return($returnval);
}

sub backup_rticonfigs
{
	my @toback = ();
	my $returnval = -1;

	if($RTI == 0) {
		loginfo("--rti not specified. Will not backup RTI configs.");
		return(0);
	}

	if(! -d "$MOUNTPOINT/configs") {
		mkdir("$MOUNTPOINT/configs");
	}

	showinfo("BEGIN Backup of RTI Configs...");

	backup_users_info();

	# RTI Configs
	@toback = ();
	push(@toback, "/etc/sysconfig/i18n");
	push(@toback, "/etc/inittab");
	push(@toback, "/etc/sudoers");
	push(@toback, "/etc/profile");
	push(@toback, "/etc/profile.d/rti.sh");
	push(@toback, "/etc/profile.d/pro5.sh");
	push(@toback, "/etc/rc.d/init.d/rti");
	push(@toback, "/etc/rc.d/init.d/blm");
	push(@toback, "/etc/rc.d/init.d/bbj");
	push(@toback, "$RTIDIR/config/");
	push(@toback, "/var/spool/fax");
	push(@toback, "/usr/local/lib/BITMAPS");

	$returnval = create_tarfile(\@toback, \@EXCLUDES, "$MOUNTPOINT/configs/rticonfigs.bak");


	loginfo("END Backup of RTI Configs");

	return($returnval);
}

sub backup_dsyconfigs
{
	my @toback = ();
	my $returnval = -1;

	if($DAISY == 0) {
		loginfo("--daisy not specified. Will not backup Daisy configs.");
		return(0);
	}

	if(! -d "$MOUNTPOINT/configs") {
		mkdir("$MOUNTPOINT/configs");
	}

	showinfo("BEGIN Backup of Daisy Configs...");

	# Copy a list of the Daisy Users to the backup medium.
	system("$DAISYDIR/daisy/bin/dsyuser.pl --list > $MOUNTPOINT/configs/dsyusers.txt 2>> $LOGFILE");


	# Here is the list of files that constitute the Daisy Configs
	@toback = ();
	push(@toback, "/etc/inittab");
	push(@toback, "/etc/sudoers");
	push(@toback, "/etc/profile.d/daisy.sh");
	push(@toback, "/etc/rc.d/init.d/daisy");
	push(@toback, "$DAISYDIR/daisy/config/");

	# don't forget the upstart files for the virtual consoles
	if ($OS eq 'RHEL6') {
	    push(@toback, "/etc/init/tty*.conf");
	}
	$returnval = create_tarfile(\@toback, \@EXCLUDES, "$MOUNTPOINT/configs/dsyconfigs.bak");


	loginfo("END Backup of Daisy Configs");

	return($returnval);
}

sub backup_usr2
{
	my @toback = ();
	my $returnval = -1;

	if($RTI == 0) {
		loginfo("--rti not specified. Will not backup usr2 directory.");
		return(0);
	}

	showinfo("BEGIN Backup of RTI Data (/usr2)...");

	# RTI
	@toback = ();
	push(@toback, "/usr2");

	# Version 14
	foreach("/var/www/jnlp",
	"/var/www/lib",
	"/var/www/cgi-bin"
	) {
		if(-d $_) {
			push(@toback, $_);
		}
	}

	$returnval = create_tarfile(\@toback, \@EXCLUDES, "$MOUNTPOINT/usr2.bak");

	# Stow away a list of inode numbers for each 'important' bbx file.
	# We have seen cases where fsck goes wrong and loses files. However,
	# these 'lost' files often show up in /usr2/lost+found as a file named
	# after the inode. If we were to know the inode mapping (as per these
	# items below), we would have a better idea of what the files are in "lost+found".
	# Again, this is only useful in very bad situations, but at least, gives us options.

	my @dir_records = (
	    [ "ls -l --inode --recursive", "/usr2/bbx/bbxd", "bbxd-filelist.txt" ] ,
	    [ "ls -l --inode --recursive", "/usr2/bbx/bbxps", "bbxps-filelist.txt" ],
	);

        foreach (@dir_records) {

	    my $cmd  = ${$_}[0];    # command to run
	    my $dir  = ${$_}[1];    # comand argument
	    my $dest = ${$_}[2];    # redirect output of command to this

	    next unless (-d $dir);

	    system("$cmd $dir > $MOUNTPOINT/configs/$dest");
	}

	loginfo("END Backup of RTI Data (/usr2)");

	return($returnval);
}


sub backup_daisy
{
	my @toback = ();
	my $returnval = -1;

	if($DAISY == 0) {
		loginfo("--daisy not specified. Will not backup daisy directory.");
		return(0);
	}

	showinfo("BEGIN Backup of Daisy Data...");

	# Daisy
	@toback = ();
	push(@toback, "/d");

	$returnval = create_tarfile(\@toback, \@EXCLUDES, "$MOUNTPOINT/daisy.bak");

	# Mapping of "Inode to filenames"; in case we ever need to pick files out of /d/lost+found.
	my $config_dir = "$MOUNTPOINT/configs";
	unless (-d $config_dir) {
	    mkdir($config_dir);
	}
	if (-d $config_dir) {
	    system("ls -l --inode --recursive /d > $config_dir/daisy-filelist.txt");
	}
	else {
	    logerror("[backup_daisy] could not write innode list, directory does not exist: $config_dir");
	}

	loginfo("END Backup of Daisy Data");

	return($returnval);
}


#
# Backup user specified files.
#
sub backup_userfiles
{
	my @toback = ();
	my @emptyarray = ();

	if(! -d "$MOUNTPOINT/configs") {
		mkdir("$MOUNTPOINT/configs");
	}

	# typically, there are none.
	unless (@USERFILES) {
		loginfo("There are no user specified files to backup... skipping");
		return(0);
	}

	showinfo("BEGIN Backup of User Specified Files...");

	create_tarfile(\@USERFILES, \@emptyarray,  "$MOUNTPOINT/userfiles.bak");


	loginfo("END Backup of User Specified Files");

	return(0);
}


#
# Backup log files.
#
sub backup_logfiles
{
    my @toback = ();

    if(! -d "$MOUNTPOINT/configs") {
	mkdir("$MOUNTPOINT/configs");
    }

    showinfo("BEGIN Backup of Log Files...");

    push(@toback, "/var/log");

    create_tarfile(\@toback, \@EXCLUDES, "$MOUNTPOINT/logfiles.bak");


    loginfo("END Backup of Log Files");

    return(0);
}




#
# Guess which device our rev drive is mapped to.
# We are looking for a fast "cdrom" device which can't write CD-Rs,
# can't read DVDs yet, can "write RAM".
#
sub find_revdevice
{
    my @array = ();
    my %hash = ();

    my $cdrom_proc_file = "/proc/sys/dev/cdrom/info";
    unless (-e $cdrom_proc_file) {
	logerror("can't look for Rev device: /proc file not present: $cdrom_proc_file");
	return("");
    }

    if (open(my $proc_fh, '<', $cdrom_proc_file)) {
        while (my $line=<$proc_fh>) {
	    chomp $line;
	    next if ($line eq "");
	    if ($line =~ /^drive name:/i) {
		@array = split(/\t+/, $line);
		for (my $i = 1; $i <= $#array; $i++) {
		    $hash{$i}{"name"} = "$array[$i]";
		}
	    }
	    if ($line =~ /^Can read DVD:/i) {
		@array = split(/\t+/, $line);
		for(my $i = 1; $i <= $#array; $i++) {
		    $hash{$i}{"can_read_dvd"} = $array[$i];
		}
	    }
	    if ($line =~ /^Can write CD-R:/i) {
		@array = split(/\t+/, $line);
		for(my $i = 1; $i <= $#array; $i++) {
		    $hash{$i}{"can_write_cdr"} = $array[$i];
		}
	    }
	    if ($line =~ /^drive speed:/i) {
		@array = split(/\t+/, $line);
		for(my $i = 1; $i <= $#array; $i++) {
		    $hash{$i}{"speed"} = int($array[$i]);
		}
	    }
        }
        close($proc_fh);
    }

    if (! %hash) {
	return("");
    }

    foreach my $key (keys(%hash)) {
	if ( ($hash{$key}{"can_write_cdr"} == 0) &&
             ($hash{$key}{"can_read_dvd"} == 0)  &&
             ($hash{$key}{"speed"} > 100) ) {

	    $DEVICE_TYPE = "rev";

	    # For reasons not yet understood, "/dev/scd0" seems to work "better"
	    # than sr0 after extended periods of time under RTI.
	    if ($hash{$key}{"name"} eq "sr0") {
		return("/dev/scd0");
	    }
	    if ($hash{$key}{"name"} eq "sr1") {
		return("/dev/scd1");
	    }

	    #
	    # add "/dev/" at the beginning of the device name
	    # so it will work with mount.
	    #
	    return("/dev/" . $hash{$key}{"name"});
	}
    }

    return("");
}


#
# Verify if specified device is on USB bus.
#
# Scan the output of command reporting USB bus info and
# look for the pattern:
#   ID_BUS=usb
# to verify it's on the USB bus.
#
# Returns
#   1 if device is on USB bus
#   0 if not
#
sub is_on_usb_bus
{
    my ($dev_file) = @_;

    my $rc = 0;

    # first choose the command to get udev info depending on platform
    my $udev_cmd = '/usr/bin/udevinfo';
    my $udev_opt = "";
    if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	$udev_cmd = '/sbin/udevadm';
	$udev_opt = 'info';
    }

    # then verify it exists
    if (! -f $udev_cmd) {
	logerror("command to get udev info does not exist: $udev_cmd");
	return($rc);
    }

    if (open(my $pipe_fh, '-|', "$udev_cmd $udev_opt -q env -n $dev_file")) {
	while (<$pipe_fh>) {
	    if (/ID_BUS=usb/) {
		$rc = 1;
		last;
	    }
	}
	close($pipe_fh);
    }
    else {
	logerror("can't open pipe to $udev_cmd for device file: $dev_file");
    }

    return($rc);
}


#
# Actually read the disk and return the filesystem label.
#
# Returns
#   filesystem label  on device
#   empty string if no label
#
sub get_fs_label
{
    my ($dev_file) = @_;

    my $rc = "";

    # verify command to read filesystem label exists
    my $e2label_cmd = '/sbin/e2label';
    if (! -f $e2label_cmd) {
	logerror("command to read filesystem label does not exist: $e2label_cmd");
	return($rc);
    }

    if (open(my $pipe_fh, '-|', "$e2label_cmd $dev_file")) {
	$rc = <$pipe_fh>;
	chomp($rc);
	close($pipe_fh)
    }
    else {
	logerror("can't open pipe to $e2label_cmd for device file: $dev_file");
    }

    return($rc);
}


#
# Get the filesystem label of the specified block device and
# verify if it has a Teleflora label.
#
# Look for the pattern:
#   TFBUDSK-YYYYMMDD
# to verify it has a Teleflora file system label.
#
# Returns
#   1 if filesystem on device has Teleflora label
#   0 if not
#
sub is_teleflora_fs_label
{
    my ($dev_file) = @_;

    my $rc = 0;

    my $fs_label = get_fs_label($dev_file);
    if ($VERBOSE) {
	if ($fs_label eq "") {
	    showinfo("there is no filesystem label for device: $dev_file");
	}
	else {
	    showinfo("filesystem label for device $dev_file: $fs_label");
	}
    }
    if ($fs_label =~ /^$TELEFLORA_FS_LABEL_PATTERN/) {
	$rc = 1;
    }

    return($rc);
}


#
# Locate a USB disk with a Teleflora label - the disk could be either
# a disk or flash drive.
#
# Scan the output of "udevinfo" or "udevadm" and look for the pattern:
#   ID_BUS=usb
# to verify it's on the USB bus.
#
# Then scan the output of "e2label" and look for the pattern:
#   TFBUDSK-YYYYMMDD
# to verify it has a Teleflora file system label.
#
# Returns:
#   device name if device found that is on USB bus and has Teleflora label
#   empty string if not
#
sub find_usb_device
{
    my $returnval = "";
    my @dev_files = qw(
	/dev/sda
	/dev/sdb
	/dev/sdc
	/dev/sdd
	/dev/sde
	/dev/sdf
	/dev/sdg
    );

    # now run through the list of potential device files
    foreach my $this_dev_file (@dev_files) {

	# verify there is a block device file
	next unless (-b $this_dev_file);

	# if on USB bus and has Teleflora filesystem label,
	# then we found one.
	if (is_on_usb_bus($this_dev_file)) {
	    if (is_teleflora_fs_label($this_dev_file)) {
		$returnval = $this_dev_file;
		$DEVICE_TYPE = "usb";
		last;
	    }
	}
    }

    return($returnval);
}


#
# Look at values for "vendor" and "model" of block device.
#
# Note it is important to look at the model. Some shops could have internal Western
# digital HDDs. If we were to only look for "WD" drive, and not look for this particular
# model, then, we could inadvertently use the internal disk device as the "backup" device,
# which would be catastrophic.
#
# Returns
#   1 if vendor == "WD" and model == "Passport"
#   0 if not
#   -1 if error, can't continue
#
sub is_wd_passport
{
    my ($dev_node) = @_;

    unless (-d "/sys/block") {
	logerror("error looking for Passport device: filesystem not present: /sys/block");
	return(-1);
    }

    # strip "/dev"
    my $dev_name = basename($dev_node);

    # constuct path to vendor file
    my $sys_vendor_file = "/sys/block/$dev_name/device/vendor";

    # if BOTH Vendor...
    # ... AND Model is correct THEN found one.
    my $found = 0;
    if (-f $sys_vendor_file) {
	if (open(my $vendor_fh, '<', $sys_vendor_file)) {
	    while (<$vendor_fh>) {
		if (/$DEVICE_VENDOR/i) {
		    $found = 1;
		    last;
		}
	    }
	    close($vendor_fh);
	}
	else {
	    logerror("error opening /sys vendor file: $sys_vendor_file");
	}
    }
    if ($found == 0) {
	return(0);
    }

    # constuct path to model file
    my $sys_model_file = "/sys/block/$dev_name/device/model";
    $found = 0;
    if (-f $sys_model_file) {
	if (open(my $model_fh, '<', $sys_model_file)) {
	    while (<$model_fh>) {
		if (/$DEVICE_MODEL/i) {
		    $found = 1;
		    last;
		}
	    }
	    close($model_fh);
	}
	else {
	    logerror("error opening /sys model file: $sys_model_file");
	}
    }
    if ($found == 0) {
	return(0);
    }

    return(1);
}


#
# Locate a Western Digital Passport Device
#
sub find_passport
{
    foreach my $thisdev ("sda", "sdb", "sdc", "sdd", "sde") {

	my $rc = is_wd_passport($thisdev);
	if ($rc == 1) {
	    $DEVICE_TYPE = "passport";
	    return("/dev/$thisdev");
	}
	elsif ($rc == -1) {
	    last;
	}
    }

    return("");
}


#
# Is the backup device already mounted?
#
# Returns
#   1 means "yes, the device is mounted."
#   0 means "no, the device is not mounted."
#
sub device_is_mounted
{
    my $rc = 0;

    # Does the backup device mount point exist?
    unless (-e "$MOUNTPOINT") {
	logerror("Backup Device mount point \"$MOUNTPOINT\" not found.");
	return($rc);
    }

    my $proc_mount_file = "/proc/mounts";
    if (open(my $mounts_fh, '<', $proc_mount_file)) {
	while (<$mounts_fh>) {
	    if (/$MOUNTPOINT/) {
		$rc = 1;
		last;
	    }
	    if (/$DEVICE/) {
		$rc = 1;
		last;
	    }
	}
	close($mounts_fh);
    }
    else {
	logerror("error opening /proc mounts file: $proc_mount_file");
    }

    return($rc);
}


#
# Mount either a block device, or an "image file".
# Returnval of 0 means "yes, mount succeeded"
# Returnval non-zero means "no, the mount failed."
#
sub mount_device_simple
{
    my ($ml, $mount_opt) = @_;

    # Is our mountpoint present?
    unless (-d $MOUNTPOINT) {
	showinfo("[$ml] Making mountpoint: $MOUNTPOINT");
	mkdir("$MOUNTPOINT");
    }
    unless (-d $MOUNTPOINT) {
	showerror("[$ml] Could not find nor make mountpoint: $MOUNTPOINT");
	return(-3);
    }

    if (device_is_mounted()) {
	showinfo("[$ml] Device already mounted: $DEVICE");
	system("umount $DEVICE > /dev/null 2>&1");
	if ($? != 0) {
	    showerror("[$ml] Could not umount device: $DEVICE");
	    return(-3);
	}
    }

    my $device_type = "";
    if (-b $DEVICE) {
	$device_type = "device";
    }
    elsif (-f $DEVICE) {
	$device_type = "image file";
	$mount_opt .= ",loop";
    }
    else {
	showerror("[$ml] Unknown device: $DEVICE");
	return(-3);
    }

    if ($VERBOSE) {
	showinfo("[$ml] Mounting \"$DEVICE\" -> \"$MOUNTPOINT\"");
    }

    system("mount -t ext2 -o $mount_opt $DEVICE $MOUNTPOINT > /dev/null 2>&1");
    if ($? != 0) {
	showerror("[$ml] Could not mount $device_type: $DEVICE on mountpoint: $MOUNTPOINT");
	return(-3);
    }

    return(0);
}


#
# Mount either the physical rev device, or possibly,
# a "loopback image file"
#
# Returns
#   0 means "yes, mount succeeded"
#   non-zero means "no, the mount failed."
#
sub mount_device
{
    my ($writemode) = @_;

    my $uuid = "";
    my $returnval = 0;

    my $ml = '[mount_device]';
    if (device_is_mounted()) {
	unmount_device();
    }

    my $mount_opt = "";
    if (-b $DEVICE) {
	# Mount a "real" device, typically the passport drive or Iomega Rev device.

	$mount_opt = $writemode;
    }
    else {
	# Mount a local "loopback image" file.

	if (-e $DEVICE) {
	    $mount_opt = $writemode . ",loop";
	}
	else {
	    showerror("$ml path to backup image file does not exist: $DEVICE");
	    $returnval = -5;
	}
    }

    if ($returnval == 0) {
	$uuid = get_filesys_uuid($DEVICE);

	showinfo("$ml backup device UUID: $uuid");
	showinfo("$ml mmount cmd: mount -t ext2 -o $mount_opt $DEVICE $MOUNTPOINT");

	system("mount -t ext2 -o $mount_opt $DEVICE $MOUNTPOINT > /dev/null 2>&1");
	if ($? == 0) {
	    showinfo("$ml device $DEVICE mounted on: $MOUNTPOINT");
	}
	else {
	    logerror("$ml mount cmd of device $DEVICE returns non-zero status");
	    $returnval = -6;
	}
    }

    return($returnval);
}


sub unmount_device_simple
{
    my ($ml) = @_;

    my $returnval = -1;

    if ($DEVICE ne "") {
	if (device_is_mounted()) {
	    if ($VERBOSE) {
		showinfo("[$ml] Un-mounting \"$DEVICE\"");
	    }

	    system("umount $DEVICE");
	    $returnval = $?;

	}
    }

    return($returnval);
}


sub unmount_device
{
    my $returnval = -1;

    if ($DEVICE ne "") {
	if (device_is_mounted()) {
	    if ($VERBOSE) {
		my $uuid = get_filesys_uuid($DEVICE);
		showinfo("Un-mounting \"$DEVICE\" (UUID: \"$uuid\") ...");
	    }

	    system("umount $DEVICE");
	    $returnval = $?;
	}
    }

    return($returnval);
}


#
# Create a .bak of files or directories in "@tobackup".
# Also creates a .md5 file which we can use to md5 verify the tar's
# integrity.
#
sub create_tarfile
{
	my @tobackup = @{$_[0]};
	my @excludes = @{$_[1]};
	my $tarpath  = $_[2];

	my $bytecount = 0;
	my $buffer = $EMPTY_STR;
	my $pid_mdfind = -1;
	my $md5 = $EMPTY_STR;
	my $returnval = 0;
	my $i = 0;
	my $kid = -1;

	loginfo("##### BEGIN writing encrypted tar archive: \"$tarpath\" #####");

	if( (! $tarpath) 
	||  ("$tarpath" eq "") ){
		logerror("Destination tar filename not specified.");
		return(-1);
	}
	if($#tobackup < 0) {
		logerror("Nothing specified to backup.");
		return(-2);
	}


	#
	# In the background, kick off a process which takes md5sums of all files
	# which we are about to be written to a tar archive.
	#
	# This background child process will create a file called, for example,
	# "printconfigs.bak.allmd5" for the backup type "printconfigs".
	# This resultant file is then used when the --checkfile command line
	# option is specified.
	#

	###############################
	# split into parent and child #
	###############################
	$pid_mdfind = fork();

	if ($pid_mdfind == 0) {

	    #########
	    # child #
	    #########

	    # calculate the md5 checksums, then exit

	    unlink("$tarpath.allmd5");

	    logdebug("***** BEGIN Creating $tarpath.allmd5 (Background PID $$)");
	    system("find @tobackup -type f -exec md5sum \\{\\} \\; >> $tarpath.allmd5 2>> $LOGFILE");
	    $returnval = $?;
	    logdebug("***** END Creating $tarpath.allmd5 (Background PID $$)(returnval=$?)");

	    exit($returnval);
	}

	##########
	# parent #
	##########

	# log files to backup and to exclude
	foreach (@tobackup) {
	    loginfo("ToBackup: $_");
	}
	foreach (@excludes) {
	    loginfo("Exclude: $_");
	}

	# Collect some information for this backup file and
	# then write it out.	
	my $backup_info = "#\n";
	$backup_info .= "# Backup Started: " . localtime(time()) . "\n";
	$backup_info .= "# Backup Version: $CVS_REVISION\n";
	$backup_info .= "# Backup PID: $$\n";
	$backup_info .= "# Hostname: " . $SYS_HOSTNAME . "\n";
	$backup_info .= "# RHVersion: " . $RH_VERSION . "\n";
	$backup_info .= "# Architecture: " . $CURRENT_ARCH . "\n";
	$backup_info .= "# Kernel: " . $KERNEL_VERSION . "\n";
	my $is_compressed = ($COMPRESS_BU) ? "yes" : "no";
	$backup_info .= "# Compressed archives: " . $is_compressed . "\n";
	foreach (@tobackup) {
	    $backup_info .= "# ToBackup: $_\n";
	}
	foreach (@excludes) {
	    $backup_info .= "# Excludes: $_\n";
	}

	# These are things we do not want in our tarfile.
	if (open(my $excludes_fh, '>', "/tmp/exclude.$$")) {
	    foreach (@excludes) {
		print($excludes_fh "$_\n");
	    }
	    close($excludes_fh);
	}
	else {
	    logerror("error opening exclude file: /tmp/exclude.$$");
	}

	# Note that we pipe our backup image to an internal (memory) MD5sum
	# prior to sending the data to disk. That way, if the disk is corrupted,
	# our MD5 is "pure", as, the MD5 is created entirely in-memory.
	# This should safeguard us against any disk corruptions.
	$md5 = Digest::MD5->new;

	#
	# Form the tar command - the compression step is optional and can be specified
	# with a command line option.
	#
	my $tar_cmd = "nice tar --exclude-from=/tmp/exclude.$$ -cvf - @tobackup";
	my $compress_cmd = "nice bzip2 --quiet";
	my $encrypt_cmd = "nice openssl aes-128-cbc -e -salt -k \"$CRYPTKEY\"";

	if ($COMPRESS_BU) {
		$tar_cmd .= " | " . $compress_cmd;
	}
	$tar_cmd .= " | " . $encrypt_cmd;

	if (open(my $tar_pipe_fh, '-|', "$tar_cmd 2>> $LOGFILE")) {
	    if (open(my $out_fh, '>', $tarpath)) {
		while (1) {
		    $bytecount = sysread($tar_pipe_fh, $buffer, 10 * 1024 * 1024);
		    last if ($bytecount == 0);
		    if ($bytecount < 0) {
			logerror("error reading tar (input) process: $!");
			$returnval = -5;
			last;
		    }
		    if (! syswrite($out_fh, $buffer, $bytecount)) {
			logerror("error writing backup to media: $!");
			$returnval = -6;
			last;
		    }
		    $md5->add($buffer);
		}
		close($out_fh);
	    }
	    else {
		logerror("error opening file for writing to: $tarpath");
		$returnval = -7;
	    }
	    close($tar_pipe_fh);
	}
	else {
	    logerror("error opening pipe for reading from tar cmd: $tar_cmd");
	    $returnval = -8;
	}

	$backup_info .= "# Backup Finished: " . localtime(time()) . "\n";

	loginfo("##### END writing encrypted tar archive: $tarpath #####");
	logdebug("##### END writing encrypted tar archive: $tarpath #####");

	# cleanup temp file
	unlink("/tmp/exclude.$$");

	# Write error status.
	my $backup_status = "";
	if ($returnval == 0) {
	    $backup_status = "SUCCESSFUL Backup.";
	    loginfo($backup_status);
	}
	elsif ($returnval == -5) {
	    $backup_status = "FAILED. Error reading from tar process";
	}
	elsif ($returnval == -6) {
	    $backup_status = "FAILED. Error while writing backup to media";
	}
	elsif ($returnval == -7) {
	    $backup_status = "FAILED. Error opening file for writing to backup media";
	}
	elsif ($returnval == -8) {
	    $backup_status = "FAILED. Error opening pipe for reading from tar process"; 
	}
	else {
	    $backup_status = "FAILED. Error encountered during Backup!!!";
	    logerror($backup_status);
	}
	$backup_info .= "# Backup Status: " . $backup_status . "\n";
	$backup_info .= "#\n";

	# Write the MD5sum of our backup image to disk.
	if ($returnval != 0) {
	    $backup_info .= "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" . "  " . $tarpath . "\n";
	}
	else {
	    $backup_info .= $md5->hexdigest . "  " . $tarpath . "\n";
	}
	
	if (open(my $info_fh, '>', "$tarpath.info")) {
	    print $info_fh $backup_info;
	    close($info_fh);
	}
	else {
	    logerror("error opening backup info file: $tarpath.info");
	}


	# Set permissions for the files on the backup media.
	my @files_on_media = (
	    "$tarpath",
	    "$tarpath.info",
	    "$tarpath.allmd5"
	);

	foreach (@files_on_media) {
	    if (-e $_) {
		system("chown root:root $_");
		system("chmod 444 $_");
		loginfo("File modes set for: $_");
	    }
	    else {
		loginfo("File modes NOT set because file does not exist: $_");
	    }
	}

	system("sync 2>> $LOGFILE");


	# Wait for our "md5sum" process to finish if it is not already.
	if ($pid_mdfind > 0) {
		for($i = 0; $i < $MAX_WAIT_TIME; $i++) {
			$kid =  waitpid($pid_mdfind, WNOHANG);
			last if($kid != 0);
			sleep(1);
		}
		if($kid < 0) {
			logerror("waitpid() on PID $pid_mdfind returned $kid. This is odd.");
		}
		if($i >= $MAX_WAIT_TIME) {
			logerror("We waited long enough ($MAX_WAIT_TIME) for our background 'find' to finish. Killing PID $pid_mdfind");
			system("kill -TERM $pid_mdfind 2>> $LOGFILE");
		}
	}

	return($returnval);
}



#
# Restore all files from "tarfile" back onto disk.
#
sub restore_tarfile
{
	my $tarfile = $_[0];
	my @excludes = @{$_[1]};
	
	showinfo("===== BEGIN Restore $tarfile =====");
	showinfo("Using Rootdir=\"$ROOTDIR\"");

	if (! $tarfile || ("$tarfile" eq "")) {
	    return(-1);
	}
	if (! -f "$tarfile") {
	    logerror("File not found: \"$tarfile\"");
	    return(-2);
	}

	# These are the files which we do *not* want to restore.
	loginfo("--- Will NOT restore the following files due to exclusion list. ---");
	my $restore_exludes_tmpfile = "/tmp/restore-excludes.$$";
	if (open(my $re_fh, '>', $restore_exludes_tmpfile)) {
	    foreach (@excludes) {
		print($re_fh "$_\n");
		loginfo("$_");
	    }
	    close($re_fh);
	}
	else {
	    logerror("error opening restore excludes file for write: $restore_exludes_tmpfile");
	}
	loginfo("--- End Restore Exclusion List  ---");


	# If we don't use "--keep-old-files", then, overwrite files, otherwise, 
	# use "tar --keep-old-files" which should NOT overwrite.
	my $keepfiles = "";
	if ($KEEP_OLD_FILES) {
	    $keepfiles = "--keep-old-files";
	}

	#
	# Form the untar command - the decompression step is optional and can be specified
	# with a command line option, but it's needed when trying to restore an old backup
	# file with the newer backup program... the compression of backup files as standard
	# was removed in version 1.192 of rtibackup.pl.
	#
	my $untar_cmd = "cat $tarfile";
	my $decrypt_cmd = "openssl aes-128-cbc -d -salt -k \"$CRYPTKEY\"";
	my $decompress_cmd = "bzip2 -dc";
	my $tar_cmd = "tar -C $ROOTDIR --exclude-from /tmp/restore-excludes.$$ $keepfiles -xvf -";

	$untar_cmd .= " | " . $decrypt_cmd;
	if ($DECOMPRESS_BU) {
		$untar_cmd .= " | " . $decompress_cmd;
	}
	$untar_cmd .= " | " . $tar_cmd;

	if ($DRY_RUN) {
	    print "$untar_cmd\n";
	}

	else {
	    if (open(my $pipe_fh, '-|', "$untar_cmd 2>&1")) {
		while (<$pipe_fh>) {
		    chomp;
		    loginfo("$_");
		    if ($VERBOSE) {
			print($_);
		    }
		}
		close($pipe_fh);
	    }
	    else {
		logerror("error opening pipe for reading tar cmd: $untar_cmd");
	    }
	}

	unlink("/tmp/restore-excludes.$$");

	showinfo("===== END Restore $tarfile =====");

	return(0);
}


#
# Verifies md5sum of files on disk with md5sums taken during backup.
# If used with no commandline parameters, then, check all known files.
# If specified with commandline (file/dir) names, then, check only those.
#
sub checkfile
{
	my @searchlist = @_;
	my @md5files = ();

	mount_device("ro");
	if (!device_is_mounted()) {
	    return(-1);
	}

	showinfo("===== Begin Checkfile =====");
	loginfo("Searchlist: @searchlist");

	# Just check everything we know about.
	if ($#searchlist < 0) {
	    loginfo("Checking All Known Files.");
	    my $cmd = "find $MOUNTPOINT -type f -iname *.allmd5 -exec md5sum --check \\{\\} \\;";
	    if (open(my $pipe_fh, '-|', $cmd)) {
		while (<$pipe_fh>) {
		    showinfo("$_");
		}
		close($pipe_fh);
	    }
	    else {
		logerror("error opening pipe reading from: $cmd");
	    }
	    return($?);
	}

	# Open a find process which produces a complete list of all md5 files.
	# Then, use the files from this list to select a set of files names
	# that were specified on the command line.

	my $tar_cmd = "find $MOUNTPOINT -type f -iname *.allmd5 -print";
	if (open(my $md5_pipe_fh, '-|', $tar_cmd)) {
	    while (my $thisfile = <$md5_pipe_fh>) {
		chomp $thisfile;

		# Open this .allmd5 file and start searching for each item
		# we had on the commandline and write results to temp file.

		if (open(my $md5_fh, '<', $thisfile)) {

		    
		    if (open(my $out_fh, '>>', "/tmp/greplist.$$")) {
			while(my $thisline = <$md5_fh>) {
			    chomp $thisline;
			    foreach my $tofind (@searchlist) {
				if ($thisline =~ /$tofind/) {
				    print($out_fh "$thisline\n");
				}
			    }
			}
			close($out_fh);
		    }
		    else {
			logerror("error opening file for writing list of files to check: /tmp/greplist.$$");
		    }
		    close($md5_fh);
		}
		else {
		    logerror("error opening md5 file for reading: $thisfile");
		}
	    }
	    close($md5_pipe_fh);
	}
	else {
	    logerror("error opening pipe for reading list of md5 files: $tar_cmd");
	}


	# Now, our "greplist.$$" file contains only files which were selected for checking.
	my $md5_cmd = "md5sum --check /tmp/greplist.$$ 2>&1";
	if (open(my $selected_fh, '-|', $md5_cmd)) {
	    while (<$selected_fh>) {
		chomp;
		showinfo("$_");
	    }
	    close($selected_fh);
	}
	else {
	    logerror("error opening pipe from: $md5_cmd");
	}

	unlink("/tmp/greplist.$$");


	unmount_device();
	showinfo("===== End Checkfile =====");
	return($?);
}




sub list_tarfile
{
	my ($tarfile) = @_;


	# Mount the fs image using loopback device.
	if(! -f "$tarfile") {
		logerror("File not found: \"$tarfile\".");
		return(-1);
	}

	showinfo("----- BEGIN $tarfile Contents -----");

	#
	# Form the untar command - the decompression step is optional and can be specified
	# with a command line option, but it's needed when trying to read an old backup
	# file with the newer backup program... the compression of backup files as standard
	# was removed in version 1.192 of rtibackup.pl.
	#
	my $untar_cmd = "cat $tarfile";
	my $decrypt_cmd = "nice openssl aes-128-cbc -d -salt -k \"$CRYPTKEY\"";
	my $decompress_cmd = "nice bzip2 -dc";
	my $tar_cmd = "nice tar -tvf -";

	$untar_cmd .= " | " . $decrypt_cmd;
	if ($DECOMPRESS_BU) {
		$untar_cmd .= " | " . $decompress_cmd;
	}
	$untar_cmd .= " | " . $tar_cmd;

	if (open(my $list_pipe_fh, '-|', "$untar_cmd 2>&1")) {
	    while(<$list_pipe_fh>) {
		chomp;
		showinfo("$_");
	    }
	    close($list_pipe_fh);
	}
	else {
	    logerror("error opening pipe for reading list of files: $untar_cmd");
	}

	showinfo("----- END $tarfile Contents -----");
	return($?);
}



sub get_filesys_uuid
{
    my ($device) = @_;

    my $filesys_uuid  = OSTools::Filesys::filesys_uuid($device);

    return($filesys_uuid);
}


sub convert_kb_to_gb
{
    my ($n) = @_;

    $n /= 1024;
    $n /= 1024;

    return($n);
}


#
# read a backup info file, aka checksum file.
#
# Returns
#   reference to a hash with keys:
#	{contents}   = the contents of the info file
#	{status}     = either "SUCCESS" or "ERROR"
#	{backuptime} = the time the backup finished
#
sub parse_backup_info
{
    my ($info_file) = @_;

    my %rc = ();

    if (open(my $info_fh, '<', $info_file)) {
	while (<$info_fh>) {
	    $rc{contents} .= "#######$_";
	    if (/Backup Status:/) {
		if (/Backup Status:\s+SUCCESS/) {
		    $rc{status} = "SUCCESS";
		}
		else {
		    $rc{status} = "ERROR";
		}
	    }
	    if (/Backup Finished:\s+([[:print:]]+)/){
		$rc{backuptime} = $1;
	    }
	}
	close($info_fh);
    }
    else {
	logerror("error opening backup info file: $info_file");
    }

    return(\%rc);
}


#
# Verify any and all items backed up.
#
sub verify_backup
{
	my @array = ();
	my @errors = ();
	my $error_found = 0;
	my $status = "";
	my $errors_present = 0;
	my $tapeid = "";
	my $backuptime = "";

	$VERIFY_FAILED = 0;

	showinfo("---- BEGIN Verify ----");
	$status .= "############################################################\n";
	if($VERBOSE != 0) {
		$status .= "######## Backup DEVICE: $DEVICE\n";
	}

	mount_device("ro");
	if (!device_is_mounted()) {
		$status .= "!!!!!!!! $DEVICE cannot be mounted. (Is cartridge ejected?)\n";
		$status .= "!!!!!!!! BACKUP DEVICE NOT FOUND\n";
	} else {
		$status .= "######## UUID: " . get_filesys_uuid($DEVICE) . "\n";
	}


	# How much space is left?
	if (device_is_mounted()) {
	    my $ref = OSTools::Filesys::filesys_df($MOUNTPOINT);
	    if (exists($ref->{blocks})) {
		# results are in KB, need to convert to GB as float
		my $blocks_gb = convert_kb_to_gb($ref->{blocks});
		my $df_size = sprintf("%.2f", $blocks_gb);
		my $avail_gb = convert_kb_to_gb($ref->{available});
		my $df_avail = sprintf("%.2f", $avail_gb);

		if ($ref->{available} == 0 ) {
		    $status .= "!!!!!!!! NO SPACE LEFT on Backup Device\n";
		}
		elsif ($ref->{available} < 1000 ) {
		    $status .= "wwwwwwww LOW SPACE AVAILABLE ($df_avail GB) on Backup Device\n";
		}
		else {
		    $status .= "######## SPACE REMAINING: $df_avail / $df_size GB \n";
		}
	    }
	}
	$status .= "######## NOW: " . localtime(time()) . "\n";


	# Summary information about a particular backup.
	if (device_is_mounted()) {

		my @backup_files = qw(
			configs/printconfigs.bak
			configs/rticonfigs.bak
			configs/dsyconfigs.bak
			configs/osconfigs.bak
			configs/userconfigs.bak
			usr2.bak
			daisy.bak
			userfiles.bak
			logfiles.bak
		);

		foreach my $thisfile (@backup_files) {

			# Don't print error messages about backup files which we may not care about.
			if ( ("$thisfile" eq "usr2.bak") || ("$thisfile" eq "configs/rticonfigs.bak") ) {
				if( ($RTI == 0) && ($DAISY == 1) ) {
					# Don't report to daisy users errors related to "usr2 not found!",
					# since that info is not pertinant to daisy users.
					loginfo("POS type 'daisy', thus backup files for 'usr2' ignored during verify. Use '--rti' to change this behavior.");
					next;
				} else {
					if(! -f "$MOUNTPOINT/$thisfile") {
						$status .= "!!!!!!!! ERROR: Backup File not Found: $MOUNTPOINT/$thisfile\n";
						$VERIFY_FAILED = 1;
					}

					if(! -f "$MOUNTPOINT/$thisfile.info") {
						$status .= "!!!!!!!! ERROR: Checksum File not Found: $MOUNTPOINT/$thisfile.info\n";
						$VERIFY_FAILED = 1;
						next;
					}
				}


			} elsif ( ($thisfile eq "daisy.bak") || ($thisfile eq "configs/dsyconfigs.bak") ) {
				if( ($RTI == 1) && ($DAISY == 0) ) {
					# Don't report to RTI users errors related to "daisy not found!",
					# since that info is not pertinant to RTI users.
					loginfo("POS type 'rti', thus backup files for 'daisy' ignored during verify. Use '--daisy' to change this behavior.");
					next;
				} else {
					if(! -f "$MOUNTPOINT/$thisfile") {
						$status .= "!!!!!!!! ERROR: Backup File not Found: $MOUNTPOINT/$thisfile\n";
						$VERIFY_FAILED = 1;
					}

					if(! -f "$MOUNTPOINT/$thisfile.info") {
						$status .= "!!!!!!!! ERROR: Checksum File not Found: $MOUNTPOINT/$thisfile.info\n";
						$VERIFY_FAILED = 1;
						next;
					}
				}



			# If we don't see both the backup and checksum files, assume that is intentional,
			# just give a warning.
			# If we see one file, but not the other, there is a problem.
			} else {

				if( (! -f "$MOUNTPOINT/$thisfile")
				&&  (! -f "$MOUNTPOINT/$thisfile.info")) {
					loginfo("Backup and Checksum files not found: \"$MOUNTPOINT/$thisfile\".");
					if("$thisfile" ne "userfiles.bak") {
						$status .= "wwwwwwww WARN: Backup and Checksum Files not Found: $MOUNTPOINT/$thisfile\n";
					}
					next;
				} else {
					if(! -f "$MOUNTPOINT/$thisfile") {
						$status .= "!!!!!!!! ERROR: Backup File not Found: $MOUNTPOINT/$thisfile\n";
						$VERIFY_FAILED = 1;
					}
					if(! -f "$MOUNTPOINT/$thisfile.info") {
						$status .= "!!!!!!!! ERROR: Checksum File not Found: $MOUNTPOINT/$thisfile.info\n";
						$VERIFY_FAILED = 1;
						next;
					}
				}
			}


			# How did the backup process go?
			showinfo("Getting backup info for $thisfile");
			my $ref = parse_backup_info("$MOUNTPOINT/$thisfile.info");
			if ($VERBOSE) {
			    if (exists($ref->{contents})) {
				$status .= $ref->{contents};
			    }
			}
			if (exists($ref->{status})) {
			    if ($ref->{status} ne "SUCCESS") {
				$status .= "!!!!!!!! ERROR occurred during Backup of $thisfile\n";
				$VERIFY_FAILED = 1;
			    }
			}
			if (exists($ref->{backuptime})) {
			    $backuptime = $ref->{backuptime};
			}

			# Verify our backup.
			showinfo("Verifying md5sums for $thisfile");
			system("md5sum --check $MOUNTPOINT/$thisfile.info > /dev/null 2>> $LOGFILE");
			if ($? != 0) {
			    $status .= "!!!!!!!! VERIFY FAILED: $thisfile ($backuptime)\n";
			    $VERIFY_FAILED = 1;
			}
			else {
			    $status .= "######## VERIFY SUCCEEDED: $thisfile ($backuptime)\n";
			}
		}
	}

	unmount_device();


	$status .= "############################################################\n";

	showinfo("---- END Verify ----");

	return($status);
}

# 
# List contents of various tarfiles.
#
sub list_files
{
	loginfo("---- BEGIN List Files ----");

	mount_device("ro");
	if (!device_is_mounted()) {
		logerror("Could not mount device \"$DEVICE\" for file listing purposes.");
		return(-1);
	}

	if ((grep(/^all$/, @LIST)) || (grep(/^usr2$/, @LIST))) {
		if ($RTI) {
			showinfo("List RTI Data...");
			list_tarfile("$MOUNTPOINT/usr2.bak");
		}
	}

	if ((grep(/^all$/, @LIST)) || (grep(/^rticonfigs$/, @LIST))) {
		if ($RTI) {
			showinfo("List RTI Configs ...");
			list_tarfile("$MOUNTPOINT/configs/rticonfigs.bak");
		}
	}

	if ((grep(/^all$/, @LIST)) || (grep(/^daisy$/, @LIST))) {
		if ($DAISY) {
			showinfo("List Daisy Data...");
			list_tarfile("$MOUNTPOINT/daisy.bak");
		}
	}

	if ((grep(/^all$/, @LIST)) || (grep(/^daisyconfigs$/, @LIST))) {
		if ($DAISY) {
			showinfo("List Daisy Configs ...");
			list_tarfile("$MOUNTPOINT/configs/dsyconfigs.bak");
		}
	}

	if((grep(/^all$/, @LIST))
	|| (grep(/^userconfigs$/, @LIST))) {
		showinfo("List User Configs ...");
		list_tarfile("$MOUNTPOINT/configs/userconfigs.bak");
	}

	if((grep(/^all$/, @LIST))
	|| (grep(/^userfiles$/, @LIST))) {
		showinfo("List User Specified Data ...");
		list_tarfile("$MOUNTPOINT/userfiles.bak");
	}

	if((grep(/^all$/, @LIST))
	|| (grep(/^netconfigs$/, @LIST))) {
		showinfo("List Network Configs...");
		list_tarfile("$MOUNTPOINT/configs/netconfigs.bak");
	}

	if((grep(/^all$/, @LIST))
	|| (grep(/^printconfigs$/, @LIST))) {
		showinfo("List Printer Configs...");
		list_tarfile("$MOUNTPOINT/configs/printconfigs.bak");
	}

	if((grep(/^all$/, @LIST))
	|| (grep(/^logfiles$/, @LIST))) {
		showinfo("List Log Files ...");
		list_tarfile("$MOUNTPOINT/logfiles.bak");
	}

	if((grep(/^all$/, @LIST))
	|| (grep(/^osconfigs$/, @LIST))) {
		showinfo("List OS Configs...");
		list_tarfile("$MOUNTPOINT/configs/osconfigs.bak");
	}

	unmount_device();
	loginfo("---- END List Files ----");
	return($?);
}


#
# Restore some or all files based on what "group" we specified on the commandline.
# Also restore individual files if so specified on the commandline.
#
sub restore_files
{
	my @restore_excludes = @{$_[0]};

	my $returnval = 0;
	my $answer = "";

	# First make sure the crypt key is valid
	if (validate_crypt_key($CRYPTKEY) != 0) {
	    return(-1);
	}

	loginfo("---- BEGIN Restore Files ----");

	mount_device("ro");
	if (!device_is_mounted()) {
		logerror("Could not mount \"$DEVICE\". Cannot proceed with restore.");
		return(-1);
	}

	# Make sure the user has somehow acknowledged that they really want to restore.
	my $fs_uuid = get_filesys_uuid($DEVICE);
	if ($FORCE != 0) {
		loginfo("--force specified. Will force restore \"@RESTORE\" to rootdir=\"$ROOTDIR\" (FS UUID: $fs_uuid)");
	}
	else {
		$answer = "";
		while(1) {
			print("FS UUID: \"$fs_uuid\"\n");
			print("Restore \"@RESTORE\" to rootdir=\"$ROOTDIR\"?");
			print("(Y/N) >");
			$answer = <STDIN>;
			chomp($answer);
			last if("$answer" =~ /^n/i);
			last if("$answer" =~ /^y/i);
		}

		# anything but 'yes'.
		if($answer !~ /^y/i) {
			loginfo("Restore cancelled by user.");
			return(0);
		}
		loginfo("User accepted restore of \"@RESTORE\" to rootdir=\"$ROOTDIR\" (FS UUID: $fs_uuid)");
	}


	if((grep(/^all$/, @RESTORE))
	|| (grep(/^daisy$/, @RESTORE))) {
		if($DAISY == 0) {
			loginfo("--daisy not specified. Will not restore daisy files.");
		} else {
			$returnval += restore_daisy(\@restore_excludes);
		}
	}

	if((grep(/^all$/, @RESTORE))
	|| (grep(/^usr2$/, @RESTORE))) {
		if($RTI == 0) {
			loginfo("--rti not specified. Will not restore RTI files.");
		} else {
			$returnval += restore_usr2(\@restore_excludes);
		}
	}

	# Restore only RTI "bbxd"
	# A sort of "pseudo-special" restore.
	if(grep(/^bbxd$/, @RESTORE)) {
		if($RTI == 0) {
			loginfo("--rti not specified. Will not restore bbxd files.");
		} else {
			system("cat $MOUNTPOINT/usr2.bak | openssl aes-128-cbc -d -salt -k \"$CRYPTKEY\" | tar -C $ROOTDIR -xvf - usr2/bbx/bbxd 2>> $LOGFILE");
			$returnval += $?;
		}
	}

	# Restore only RTI "bbxps" (Customs)
	# A sort of "pseudo-special" restore.
	if(grep(/^bbxps$/, @RESTORE)) {
		if($RTI == 0) {
			loginfo("--rti not specified. Will not restore bbxps files.");
		} else {
			system("cat $MOUNTPOINT/usr2.bak | openssl aes-128-cbc -d -salt -k \"$CRYPTKEY\" | tar -C $ROOTDIR -xvf - usr2/bbx/bbxps 2>> $LOGFILE");
			$returnval += $?;
		}
	}


	if((grep(/^all$/, @RESTORE))
	|| (grep(/^rticonfigs$/, @RESTORE))) {
		if($RTI == 0) {
			loginfo("--rti not specified. Will not restore rticonfig files.");
		} else {
			$returnval += restore_rticonfigs(\@restore_excludes);
		}
	}

	if((grep(/^all$/, @RESTORE))
	|| (grep(/^daisyconfigs$/, @RESTORE))) {
		if($DAISY == 0) {
			loginfo("--daisy not specified. Will not restore daisyconfig files.");
		} else {
			$returnval += restore_dsyconfigs(\@restore_excludes);
		}
	}

	if((grep(/^all$/, @RESTORE))
	|| (grep(/^userconfigs$/, @RESTORE))) {
		$returnval += restore_userconfigs(\@restore_excludes);
	}

	if((grep(/^all$/, @RESTORE))
	|| (grep(/^userfiles$/, @RESTORE))) {
		$returnval += restore_userfiles(\@restore_excludes);
	}

	if((grep(/^all$/, @RESTORE))
	|| (grep(/^logfiles$/, @RESTORE))) {
		$returnval += restore_logfiles(\@restore_excludes);
	}

	if((grep(/^all$/, @RESTORE))
	|| (grep(/^printconfigs$/, @RESTORE))) {
		$returnval += restore_printconfigs(\@restore_excludes);
	}

	if((grep(/^all$/, @RESTORE))
	|| (grep(/^netconfigs$/, @RESTORE))) {
		$returnval += restore_netconfigs(\@restore_excludes);
	}

	if((grep(/^all$/, @RESTORE))
	|| (grep(/^osconfigs$/, @RESTORE))) {
		$returnval += restore_osconfigs(\@restore_excludes);
	}


	# If user specified "--restore /usr2/bbx/blah /etc/sysconfig/blah" or
	# "--restore=singlefiles" /usr2/bbx/blah /etc/sysconfig/blah then,
	# this subroutine restores those specific files.
	$returnval += restore_singlefiles();

	unmount_device();

	loginfo("---- END Restore Files ----");
	return($returnval);
}


sub restore_usr2
{
	my @restore_excludes = @{$_[0]};

	my $returnval = -1;

	mount_device("ro");
	if (!device_is_mounted()) {
		return(-1);
	}

	if($RTI == 0) {
		logerror("--rti not specified. Will not restore RTI data.");
		return(0);
	}


	showinfo("Restore RTI Data...");

	#
	# Only stop RTI if restoring on top of /usr2...  which
	# is true only if restoring to the top of the file system - the
	# default value for the restore root directory.
	#
	my $clobber_rti = 0;
	if ($ROOTDIR eq '/') {
		$clobber_rti = 1;
	}

	#
	# If /usr2 is being restored, then two things have to happen:
	# 1) RTI must be stopped
	# 2) the log file location must be moved
	#
	my $old_logfile_path = "";

	if ($clobber_rti) {

	    # stop RTI
	    if (-f "$RTIDIR/bin/killem") {
		system("$RTIDIR/bin/killem 2>> $LOGFILE");
	    }
	    if (-f "/etc/rc.d/init.d/httpd") {
		system("/sbin/service httpd stop 2>> $LOGFILE");
	    }
	    if (-f "/etc/rc.d/init.d/bbj") {
		system("/sbin/service bbj stop 2>> $LOGFILE");
	    }
	    if (-f "/etc/rc.d/init.d/rti") {
		system("/sbin/service rti stop 2>> $LOGFILE");
	    }

	    # move logfile location
	    $old_logfile_path = log_change_location();
	}

	# Should we *not* restore some files?
	if(-d "/usr2/basis") {
		push(@restore_excludes, "usr2/basis");
	}


	# /usr2
	$returnval = restore_tarfile("$MOUNTPOINT/usr2.bak", \@restore_excludes );

	#
	# Make correct symlink for tcc based on which OS we are on.
	# Assumption is that the payment processor is Elavon.
	#
	$OS = plat_os_version();

	loginfo("Making TCC links for: $OS");
	if ($OS eq 'RHEL4') {
	    if (-e '/usr2/bbx/bin/tcc2_linux') {
		system("ln -sf /usr2/bbx/bin/tcc2_linux /usr2/bbx/bin/tcc");
		system("ln -sf /usr2/bbx/bin/tcc_linux /usr2/bbx/bin/tcc_tws");
	    }
	    else {
		system("ln -sf /usr2/bbx/bin/tcc_linux /usr2/bbx/bin/tcc");
	    }
	}

	elsif ($OS eq 'RHEL5') {
	    if (-e '/usr2/bbx/bin/tcc2_x64') {
		system("ln -sf /usr2/bbx/bin/tcc2_x64 /usr2/bbx/bin/tcc");
		system("ln -sf /usr2/bbx/bin/tcc_x64 /usr2/bbx/bin/tcc_tws");
	    }
	    else {
		system("ln -sf /usr2/bbx/bin/tcc_x64 /usr2/bbx/bin/tcc");
	    }
	}

	elsif ($OS eq 'RHEL6') {
	    system("ln -sf /usr2/bbx/bin/tcc2_rhel6 /usr2/bbx/bin/tcc");
	    system("ln -sf /usr2/bbx/bin/tcc_rhel6 /usr2/bbx/bin/tcc_tws");
	}

	elsif ($OS eq 'RHEL7') {
	    system("ln -sf /usr2/bbx/bin/tcc2_rhel7 /usr2/bbx/bin/tcc");
	    system("ln -sf /usr2/bbx/bin/tcc_rhel7 /usr2/bbx/bin/tcc_tws");
	}

	else {
	    logerror("could not make TCC links: unsupported platform: $OS");
	}

	if ($clobber_rti) {

	    $RUN_RTI_PERMS = 1;

	    showinfo("*** Make sure to restart 'bbj', 'rti' and 'httpd' services.");
	}

	loginfo("END Restore RTI Data...");

	if ($old_logfile_path ne "") {
	    log_restore_location($old_logfile_path);
	}

	return($returnval);
}



sub restore_rticonfigs
{
	my @restore_excludes = @{$_[0]};

	my $returnval = -1;


	mount_device("ro");
	if (!device_is_mounted()) {
		return(-1);
	}

	if($RTI == 0) {
		logerror("--rti not specified. Will not restore RTI configs.");
		return(0);
	}


	showinfo("Restore RTI Configs...");

	# Bring down RTI.
	if(-f "$RTIDIR/bin/killem") {
		system("$RTIDIR/bin/killem 2>> $LOGFILE");
	}
	if(-f "/etc/rc.d/init.d/rti") {
		system("/sbin/service rti stop 2>> $LOGFILE");
	}

	# Restore RTI "configurations".
	$returnval = restore_tarfile("$MOUNTPOINT/configs/rticonfigs.bak", \@restore_excludes);

	# Make sure our system services are re-established.
	if($returnval == 0) {
		system("/sbin/chkconfig --add --level 35 rti 2>> $LOGFILE");
		system("/sbin/chkconfig --add --level 35 blm 2>> $LOGFILE");
		system("/sbin/chkconfig --add --level 35 bbj 2>> $LOGFILE");

		$RUN_HARDEN_LINUX = 1;

		$RUN_RTI_PERMS = 1;
	}

	loginfo("END Restore RTI Configs...");

	return($returnval);
}


sub restore_daisy
{
	my @restore_excludes = @{$_[0]};

	my $returnval = -1;
	my $clobber_daisy = 0;

	mount_device("ro");
	if (!device_is_mounted()) {
		return(-1);
	}

	if($DAISY == 0) {
		logerror("--daisy not specified. Will not restore Daisy data.");
		return(0);
	}

	#
	# Only bring down Daisy if restoring on top of daisy...  which
	# is true only if restoring to the top of the file system - the
	# default value for the restore root directory.
	#
	if ($ROOTDIR eq '/') {
		$clobber_daisy = 1;
	}

	#
	# if (/d is being restored) then
	#   the log file location must be moved
	#   if (/d/daisy exists) then
	#	daisy must be stopped
	#
	my $old_logfile_path = "";
	if ($clobber_daisy) {
	    # move logfile location
	    $old_logfile_path = log_change_location();

	    # stop daisy if necessary
	    if (-e "/d/daisy") {
		daisy_stop();
	    }
	}

	showinfo("Restore Daisy Data...");

	# Restore "/d".
	$returnval = restore_tarfile("$MOUNTPOINT/daisy.bak", \@restore_excludes);

	# Make sure our system services are re-established.
	if ($returnval == 0 && $clobber_daisy) {

		$RUN_HARDEN_LINUX = 1;

		$RUN_DAISY_PERMS = 1;

	}

	# Bring Daisy back up if necessary.
	if ($clobber_daisy) {
	    daisy_start();
	}

	loginfo("END Restore Daisy Data...");

	if ($old_logfile_path ne "") {
	    log_restore_location($old_logfile_path);
	}

	return($returnval);
}

sub restore_dsyconfigs
{
	my @restore_excludes = @{$_[0]};

	my $returnval = -1;

	mount_device("ro");
	if (!device_is_mounted()) {
		return(-1);
	}

	if($DAISY == 0) {
		logerror("--daisy not specified. Will not restore Daisy configs.");
		return(0);
	}


	showinfo("Restore Daisy Config Files...");

	#
	# Only bring down Daisy if restoring on top of daisy...  which
	# is true only if restoring to the top of the file system - the
	# default value for the restore root directory.
	#
	my $clobber_daisy = 0;
	if ($ROOTDIR eq '/') {
		$clobber_daisy = 1;
	}

	if ($clobber_daisy) {
	    daisy_stop();
	}

	# Restore Daisy "configurations".
	$returnval = restore_tarfile("$MOUNTPOINT/configs/dsyconfigs.bak", \@restore_excludes);

	# Make sure our system services are re-established.
	if ($returnval == 0 && $clobber_daisy) {

		$RUN_HARDEN_LINUX = 1;

		$RUN_DAISY_PERMS = 1;

	}

	# Bring Daisy back up if necessary.
	if ($clobber_daisy) {
	    daisy_start();
	}

	loginfo("END Restore Daisy Configs...");

	return($returnval);
}


#
# Read the "usersinfo.txt" file from a backup which
# consists of the lines from the shadow file for each
# user on the system at the time of the backup.
#
# This sub reads the user info file and
# returns a hash with the username as the key and
# the line as the value.
#
sub read_usersinfo_file
{
    my $info_file = "$MOUNTPOINT/configs/usersinfo.txt";

    my %usersinfo_tab = ();
    my $line;

    if (open(my $ui_fh, '<', $info_file)) {
	while ($line = <$ui_fh>) {
	    my $i = index($line, ":");
	    my $username = substr($line, 0, $i);
	    $usersinfo_tab{$username} = $line;
	}
	close($ui_fh);
    }
    else {
	logerror("error opening users info file: $info_file");
    }

    return(%usersinfo_tab);
}


#
# Re-create user accounts related to the POS.
#
sub restore_users_info
{
    my $users_file = $EMPTY_STR;
    my $users_cmd = $EMPTY_STR;

    if ( (-f "$RTIDIR/bin/rtiuser.pl") && (-f "$MOUNTPOINT/configs/rtiusers.txt") ) {
	$users_file = "$MOUNTPOINT/configs/rtiusers.txt";
	$users_cmd = "$RTIDIR/bin/rtiuser.pl";
	# leave the existing shell profile files alone when
	# doing an upgrade.
	$users_cmd .= " --noprofile";
    }

    elsif ( (-f "$DAISYDIR/daisy/bin/dsyuser.pl") && (-f "$MOUNTPOINT/configs/dsyusers.txt") ) {
	$users_file = "$MOUNTPOINT/configs/dsyusers.txt";
	$users_cmd = "$DAISYDIR/daisy/bin/dsyuser.pl";
    }

    if ($users_file) {

	my %users_tab = read_users_file($users_file);

	foreach my $key (keys(%users_tab)) {
	    loginfo("Restoring POS user $key...");
	    system("$users_cmd --add $key 2>> $LOGFILE");
	    if ($users_tab{$key} == 2) {
		loginfo("Restoring POS admin $key...");
		system("$users_cmd --enable-admin $key password 2>> $LOGFILE");
	    }
	}
    }

    my $info_file = "";
    if (-f "$MOUNTPOINT/configs/usersinfo.txt") {
	$info_file = "$MOUNTPOINT/configs/usersinfo.txt";
    }

    if ($info_file) {

	my %usersinfo_tab = read_usersinfo_file();

	my $conf_file = "/etc/shadow";
	my $new_conf_file = "$conf_file.$$";

	unless (-f "$conf_file") {
	    logerror("Can't happen: shadow password file does not exist: $conf_file");
	    return;
	}

	if (open(my $old_fh, '<', $conf_file)) {
	    if (open(my $new_fh, '>', $new_conf_file)) {
		while (my $line = <$old_fh>) {
		    my $i = index($line, ":");
		    my $username = substr($line, 0, $i);
		    if (defined($usersinfo_tab{$username})) {
			print $new_fh "$usersinfo_tab{$username}";
		    }
		    else {
			print $new_fh "$line";
		    }
		}
		close($new_fh);
	    }
	    else {
		logerror("error opening new shadow password file: $new_conf_file");
	    }
	    close($old_fh);
	}
	else {
	    logerror("error opening old shadow password file: $conf_file");
	}

	if (-e $new_conf_file && -s $new_conf_file) {
	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");
	    system("mv $new_conf_file $conf_file");

	    loginfo("POS users and shadow file info restored.");
	}
	else {
	    if (-e $new_conf_file) {
		unlink $new_conf_file;
		logerror("zero length temporary shadow password file removed: $new_conf_file");
	    }
	}
    }

    return(1);
}


sub restore_userconfigs
{
	my @restore_excludes = @{$_[0]};

	my $returnval = -1;

	mount_device("ro");
	if (!device_is_mounted()) {
		return(-1);
	}

	# exclude /etc/passwd, /etc/group, /etc/shadow when upgrading
	# between os releases

	if ($UPGRADE) {

	    my @excludes = qw(
		etc/pam.d
		etc/login.defs
		etc/shadow
		etc/shadow-
		etc/gshadow
		etc/passwd
		etc/passwd-
		etc/group
	    );

	    foreach my $exclude (@excludes) {
		push(@restore_excludes, $exclude);
	    }
	}

	showinfo("BEGIN Restore POS User Configs...");

	# Restore user config Settings
	$returnval = restore_tarfile("$MOUNTPOINT/configs/userconfigs.bak", \@restore_excludes);
	if ($returnval == 0) {
	    loginfo("restarting crond...");
	    system("/sbin/service crond restart 2>> $LOGFILE");

	    if ($UPGRADE) {
		restore_users_info();
	    }
	}


	loginfo("END Restore POS User Configs...");

	return($returnval);
}


sub restore_userfiles
{ 
	my @restore_excludes = @{$_[0]};

	my $returnval = -1;

	mount_device("ro");
	if (!device_is_mounted()) {
		return(-1);
	}


	showinfo("Restore User Specified Files...");

	# Restore User Specified Files
	$returnval = restore_tarfile("$MOUNTPOINT/userfiles.bak", \@restore_excludes);

	loginfo("END Restore User Files ...");

	return($returnval);
}


sub restore_logfiles
{ 
	my @restore_excludes = @{$_[0]};

	#
	# do NOT restore log files if doing an upgrade
	#
	if ($UPGRADE) {
	    loginfo("Log Files NOT restored when --upgrade specified.");
	    return(0);
	}

	my $returnval = -1;

	mount_device("ro");
	if (!device_is_mounted()) {
		return(-1);
	}


	showinfo("Restore Log Files...");

	# Restore User Specified Files
	$returnval = restore_tarfile("$MOUNTPOINT/logfiles.bak", \@restore_excludes);

	loginfo("END Restore Log Files ...");

	return($returnval);
}


#
# Set the "passdb backend"  parameter to a value of "smbpasswd"
# in the samba config file.  This is a "global" section parameter.
# This must be done for RHEL6 systems to be backwards compatabile
# with the way the pre-RHEL6 systems were configured.
# It's unknown at the point what to do for RHEL7 systems but
# the starting point is to do the same as for RHEL6 systems.
#
sub samba_set_passdb
{
    my $parameter = 'passdb backend = smbpasswd';
    my $parameter2 = 'smb passwd file = /etc/samba/smbpasswd';

    my $conf_file = '/etc/samba/smb.conf';
    my $new_conf_file = "$conf_file.$$";

    my $rc = $EXIT_OK;

    unless (-f $conf_file) {
	showerror("Samba config file does not exist: $conf_file");
	return($EXIT_SAMBA_CONF);
    }

    # Do nothing if a modified conf file is already in place.
    system("grep '$parameter' $conf_file > /dev/null 2> /dev/null");
    if ($? == 0) {
	showinfo("Samba config file already appears to be modified: $conf_file");
	return($EXIT_OK);
    }

    #
    # Copy all lines from old to new, but immediately after the
    # global section declaraion, write the new parameter(s) into
    # the new conf file.
    #
    if (open(my $old_fh, '<', $conf_file)) {
	if (open(my $new_fh, '>', $new_conf_file)) {
	    while (<$old_fh>) {
		if (/^\s*\[global\]/) {
		    print($new_fh $_);
		    print($new_fh "#Following lines added by $PROGNAME, $CVS_REVISION, $TIMESTAMP\n");
		    print($new_fh "$parameter\n");
		    print($new_fh "$parameter2\n");
		    next;
		}
		else {
		    print($new_fh $_);
		}
	    }
	    close($new_fh);

	    # If the new conf file exists and is size non-zero, call it good
	    # so replace the old one with the new.
	    if (-e $new_conf_file && -s $new_conf_file) {
		system("chmod --reference=$conf_file $new_conf_file");
		system("chown --reference=$conf_file $new_conf_file");
		system("cp $new_conf_file $conf_file");

		loginfo("Samba config file modified successfully: $conf_file");
	    }
	    else {
		showerror("error modifying existing Samba config file: $conf_file");
		unlink($new_conf_file) if (-e $new_conf_file);
		$rc = $EXIT_SAMBA_CONF;
	    }
	}
	else {
	    showerror("error opening new Samba config file: $new_conf_file");
	    $rc = $EXIT_SAMBA_CONF;
	}
	close($old_fh);
    }
    else {
	showerror("error opening existing Samba config file: $conf_file");
	$rc = $EXIT_SAMBA_CONF;
    }

    return($rc);
}


#
# Make the UIDs in the "smbpasswd" file match those in /etc/passwd.
#
sub samba_rebuild_passdb
{
    my $conf_file = '/etc/samba/smbpasswd';
    if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	if (! -e $conf_file) {
	    my $alt_conf_file = '/var/lib/samba/private/smbpasswd';
	    if (-e $alt_conf_file) {
		showerror("Expecting smbpasswd file to be in /etc/samba");
		return($EXIT_SAMBA_CONF);
	    }
	}
    }
    my $new_conf_file = "$conf_file.$$";

    unless (-f $conf_file) {
	showerror("Samba config file does not exist: $conf_file");
	return($EXIT_SAMBA_CONF);
    }

    #
    # Copy all lines from old to new, but adjust the UID field if necessary.
    #
    # The structure of an smbpasswd entry is:
    #
    # username:uid:lanman_hash:nt_hash:flags:pw_lct
    #
    # username    - the user's login name.
    # uid         - the user's UID
    # lanman_hash - Windows stuff
    # nt_hash     - Windows stuff
    # flags       - Various single-character flags representing the type and
    #               state of the user's account.
    # pw_lct      - the timestamp of the user's last successful password change
    #
    my $file_modified = 0;
    if (open(my $old_fh, '<', $conf_file)) {
	if (open(my $new_fh, '>', $new_conf_file)) {
	    while (<$old_fh>) {
		my $line = $_;
		if ($line =~ /^(\S+):(\d+):(.*)$/) {
		    my $username = $1;
		    my $uid = $2;
		    my $remainder = $3;

		    my $system_uid = getpwnam($username);
		    if (defined($system_uid)) {
			if ($uid ne $system_uid) {
			    $line = "$username" . ":" . "$system_uid" . ":" . "$remainder" . "\n";
			    $file_modified = 1;
			}
		    }
		}
		print($new_fh $line);
	    }

	    close($old_fh);
	    close($new_fh);
	}
	else {
	    close($old_fh);
	    showerror("error opening new Samba config file: $new_conf_file");
	    return($EXIT_SAMBA_CONF);
	}
    }
    else {
	showerror("error opening existing Samba config file: $conf_file");
	return($EXIT_SAMBA_CONF);
    }


    if ($file_modified) {
	# If we created a new conf file that is zero sized, that is bad.
	if (-z $new_conf_file) {
	    showerror("The copy of the Samba $conf_file is a zero size file");
	    showerror("Samba $conf_file NOT modified with new UID fields");
	    system("rm $new_conf_file");
	    return($EXIT_SAMBA_CONF);
	}

	# Assume conf file was successfully transformed...
	# so replace the old one with the new.
	system("chmod --reference=$conf_file $new_conf_file");
	system("chown --reference=$conf_file $new_conf_file");
	system("cp $new_conf_file $conf_file");

	loginfo("Samba $conf_file modified with new UID fields");
    }
    else {
	system("rm $new_conf_file");
	loginfo("Samba $conf_file did not need any modification with new UID fields");
    }

    return($EXIT_OK);
}


sub restore_osconfigs
{
	my @restore_excludes = @{$_[0]};

	my $thisfile = "";
	my $returnval = -1;
	my $datestamp = "";

	mount_device("ro");
	if (!device_is_mounted()) {
		return(-1);
	}


	showinfo("Restore OS Configs...");

	# What *not* to restore
	if(-f "/etc/httpd/conf.d/rti.conf") {
		push(@restore_excludes, "etc/httpd/conf.d/rti.conf");
	}
	if(-f "/etc/sysconfig/rhn/systemid") {
		push(@restore_excludes, "etc/sysconfig/rhn");
	}

	# Copy critical files before blowing them away.
	$datestamp = strftime("%Y-%m-%d_%H%M%S", localtime());
	system("cp /etc/inittab /etc/inittab.$datestamp");

	# Restore OS Configurations
	$returnval = restore_tarfile("$MOUNTPOINT/configs/osconfigs.bak", \@restore_excludes);
	if($returnval == 0) {
		my $service_name = ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) ? 'rsyslog' : 'syslog';
		system("/sbin/service $service_name restart 2>> $LOGFILE");
		system("/sbin/service rhnsd restart 2>> $LOGFILE");
		system("/sbin/service sendmail restart 2>> $LOGFILE");

		if ($UPGRADE && ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') )) {
		    samba_set_passdb();
		    samba_rebuild_passdb();
		}

		system("/sbin/service smb restart 2>> $LOGFILE");

		if ($RTI) {
			if(-f "/etc/rc.d/init.d/httpd 2>> $LOGFILE") {
				system("/sbin/service httpd restart 2>> $LOGFILE");
			}
		}

		# (Re) Setup tfremote
		if (-f "$RTIDIR/bin/tfremote.pl") {
			system("$RTIDIR/bin/tfremote.pl --install 2>> $LOGFILE");
		} else {
			logerror("Error: expecting script to exist: $RTIDIR/bin/tfremote.pl");
			logerror("Error: could not install: $RTIDIR/bin/tfremote.pl");
		}

		$RUN_HARDEN_LINUX = 1;

	}

	loginfo("END Restore OS Configs...");

	return($returnval);
}


sub restore_netconfigs
{
	my @restore_excludes = @{$_[0]};

	my $returnval = -1;

	mount_device("ro");
	if (!device_is_mounted()) {
	    return(-1);
	}

	showinfo("Restore Network Configs...");

	# Restore Network Configurations
	$returnval = restore_tarfile("$MOUNTPOINT/configs/netconfigs.bak", \@restore_excludes);

	# Don't preserve the "HWADDR=" line in ifcfg-eth0. This causes issues
	# when migrating ethernet configs from an older server to a new server.
	my $oldfile = "/etc/sysconfig/network-scripts/ifcfg-eth0";
	my $newfile = "/etc/sysconfig/network-scripts/ifcfg-eth0.$$";
	if (open(my $old_fh, '<', $oldfile)) {
	    if (open(my $new_fh, '>', $newfile)) {
		while (<$old_fh>) {
		    if (/HWADDR/) {
			print {$new_fh} "# $_";
		    }
		    else {
			print {$new_fh} "$_";
		    }
		}
		close($new_fh);

		if (-e $newfile && -s $newfile > 0) {
		    system("mv -v $newfile $oldfile");
		}
		else {
		    logerror("error modifying config file: $oldfile");
		}
	    }
	    else {
		logerror("error opening new ifcfg file: $newfile");
	    }

	    close($old_fh);
	}
	else {
	    logerror("error opening old ifcfg file: $oldfile");
	}

	if ($returnval == 0) {
	    $RUN_HARDEN_LINUX = 1;
	}

	loginfo("END Restore Network Configs");

	return($returnval);
}


sub restore_printconfigs
{
	my @restore_excludes = @{$_[0]};

	my $thisfile = "";
	my $returnval = -1;

	mount_device("ro");
	if (!device_is_mounted()) {
		return(-1);
	}


	showinfo("Restore Printer Configs...");

	# Restore Printer Configurations
	$returnval = restore_tarfile("$MOUNTPOINT/configs/printconfigs.bak", \@restore_excludes);
	if($returnval == 0) {
		system("/sbin/service cups restart 2>> $LOGFILE");
	}

	loginfo("END Restore Printer Configs...");

	return($returnval);
}


#
# Restore a single file from one of the backup tar files on the backup device.
# All backup tar files on the backup device are searched... last one wins.
#
# Examples of where this is used:
# --restore=singlefiles /usr2/bbx/bin/rtiperms.pl /usr/bbx/bin/harden_rti.pl
# --restore /usr2/bbx/bin/killem
# --restore /etc/sysconfig/network-scripts/ifcfg-eth0
#
sub restore_singlefiles
{
	my @files_to_restore = ();

	mount_device("ro");
	if (!device_is_mounted()) {
	    logerror("error mounting backup device for restoring singlefiles");
	    return(-1);
	}

	# If we specify a file "path" in ARGV, our first "path" shows up in @RESTORE,
	# with remaining paths showing up in @ARGV. 
	# Thus, for example, valid things to restore would be:
	#    /usr2/bbx/
	#    /usr2/bbx/bin/killem
	# 
	# remove leading '/' char and quote in case of SPACE chars
	foreach my $thisfile (@RESTORE, @ARGV) {
	    chomp $thisfile;
	    if ($thisfile =~ /^\//) {
		$thisfile =~ s/^\///g;
		push(@files_to_restore, "\"$thisfile\"");
	    }
	}
	if ($#files_to_restore < 0) {
	    if ($VERBOSE) {
		showinfo("list of files to restore is empty");
	    }
	    return(0);
	}


	if ($DEVICE ne "") {

	    #
	    # Form the untar command - the decompression step is optional and can be specified
	    # with a command line option, but it's needed when trying to read an old backup
	    # file with the newer backup program... the compression of backup files as standard
	    # was removed in version 1.192 of rtibackup.pl.
	    #
	    # First, define the segments of the pipeline
	    my $decrypt_cmd = "openssl aes-128-cbc -d -salt -k \"$CRYPTKEY\"";
	    my $decompress_cmd = "bzip2 -dc";
	    my $tar_cmd = "tar -C $ROOTDIR -xvf - @files_to_restore";

	    # Now put as much as we have together
	    my $partial_cmd = $decrypt_cmd;
	    if ($DECOMPRESS_BU) {
		$partial_cmd .= " | " . $decompress_cmd;
	    }
	    $partial_cmd .= " | " . $tar_cmd;

	    #
	    # Search though all available backup tarfiles.
	    #
	    if (open(my $tar_fh, '-|', "find $MOUNTPOINT -type f -iname '*.bak' -print")) {
		while (<$tar_fh>) {
		    chomp;

		    showinfo("Restoring @files_to_restore from \"$_\" into rootdir=\"$ROOTDIR\".");

		    # complete the command now that we have a filename
		    my $untar_cmd = "cat $_" . " | " . $partial_cmd;

		    # And then issue the command
		    if ($DRY_RUN) {
			print "$untar_cmd 2>> $LOGFILE\n\n";
		    }
		    else {
			system("$untar_cmd 2>> $LOGFILE");
		    }
		}
		close($tar_fh);
	    }
	    else {
		logerror("error opening pipeline to restore: @files_to_restore");
	    }
	}

	return(0);
}


#
# Validate a crypt key
#
# Returns:
#    0 --> crypt key is valid
#    1 --> crypt key is invalid
#   -1 --> crypt key is empty string
#   -2 --> could not mount backup device
#   -3 --> no encrypted files on backup device
#
sub validate_crypt_key
{
    my ($cryptkey) = @_;
    my $rc = 0;

    if ($cryptkey eq "") {
	logerror("Can't validate empty crypt key");
	return(-1);
    }

    mount_device("ro");
    unless (device_is_mounted()) {
	logerror("Could not mount backup device: $DEVICE");
	return(-2);
    }

    my $validation_file_path = "$MOUNTPOINT/$VALIDATION_FILE";

    # Pick a file to test decryption:
    # First, look for the file dedicated for this use:
    #	teleflora-cryptkey-validation-20111130.dat
    #
    # Next, look for the smallest file of:
    my @encrypted_files = qw(
    	configs/osconfigs.bak
    	configs/netconfigs.bak
    	configs/userconfigs.bak
    	configs/rticonfigs.bak
    	configs/dsyconfigs.bak
    	configs/printconfigs.bak
    	userfiles.bak
	logfiles.bak
    	daisy.bak
    	usr2.bak
    );

    my $tarfile = "";

    # if the special validation file exists, use it
    if (-e $validation_file_path) {
	$tarfile = $validation_file_path;
	loginfo("The validation file exists on backup device: $VALIDATION_FILE");
    }

    # otherwise look for the smallest encrypted file
    else {
	loginfo("The validation file does not exist on backup device: $VALIDATION_FILE");
	loginfo("The smallest encrypted file will be used instead");

	my $smallest_file_size = -1;
	my $smallest_file = "";
	my $file_size = 0;
	foreach (@encrypted_files) {
	    if (-e "$MOUNTPOINT/$_") {
		$file_size = -s "$MOUNTPOINT/$_";

		# first time through, use the current file's size
		if ($smallest_file_size == -1) {
		    $smallest_file_size = $file_size;
		    $smallest_file = $_;
		}

		# after that, actually look for a smaller file
		elsif ($file_size < $smallest_file_size) {
		    $smallest_file_size = $file_size;
		    $smallest_file = $_;
		}
	    }
	}

	if ($smallest_file ne "") {
	    $tarfile = "$MOUNTPOINT/$smallest_file";
	    loginfo("Smallest encrypted file: $smallest_file");
	}
    }

    if ($tarfile eq "") {
	showinfo("The backup device does not contain any encrypted files");
	logerror("The crypt key can not be validated");
	unmount_device();
	return(-3);
    }

    loginfo("===== BEGIN Validate Cryptkey =====");

    my $cat_cmd = "cat $tarfile";
    my $decrypt_cmd = "openssl aes-128-cbc -d -salt -k \"$cryptkey\" > /dev/null 2> /dev/null";
    my $validate_cmd = $cat_cmd . " | " . $decrypt_cmd;

    unless ($DRY_RUN) {
	loginfo("Attempting to validate crypt key by decrypting: $tarfile");
	system("$validate_cmd");
	if ($? != 0) {
	    loginfo("The crypt key is invalid");
	    $rc = 1;
	}
	else {
	    loginfo("The crypt key is valid");
	}
    }

    loginfo("===== END Validate Cryptkey =====");

    unmount_device();

    return($rc);
}

#
# Run the harden script on the POS, with an input argument of either
# "$DAISYDIR/daisy" or "$RTIDIR".
#
sub run_harden_linux
{
    my $posdir = $EMPTY_STR;

    if ($RTI) {
	$posdir = $RTIDIR;
    }
    elsif ($DAISY) {
	$posdir = "$DAISYDIR/daisy";
    }

    if (-f "$posdir/bin/harden_linux.pl") {
	showinfo("Running $posdir/bin/harden_linux.pl");
	system("perl $posdir/bin/harden_linux.pl 2>> $LOGFILE");
    } else {
	logerror("Error: expecting script to exist: $posdir/bin/harden_linux.pl");
	logerror("Error: could not run: $posdir/bin/harden_linux.pl");
    }

    return(1);
}


#
# Run rtiperms.pl on the RTI application files.
#
sub set_rti_perms
{
	if (-f "$RTIDIR/bin/rtiperms.pl") {
		showinfo("Running $RTIDIR/bin/rtiperms.pl /usr2/bbx");
		system("perl $RTIDIR/bin/rtiperms.pl /usr2/bbx 2>> $LOGFILE");
	} else {
		logerror("Error: expecting script to exist: $RTIDIR/bin/rtiperms.pl");
		logerror("Error: could not run: $RTIDIR/bin/rtiperms.pl /usr2/bbx");
	}

	return(1);
}


#
# Run dsyperms.pl on all possible daisy database dirs... always remember
# that there can be multiple daisy database dirs!
#
# Look for all directories in "/d" that contain files named
# "flordat.tel" and "control.dsy".  Skip old dirs.
#
sub set_daisy_perms
{
	my @daisy_db_dirs = glob("$DAISYDIR/*");
	my $dsyperms_cmd = "$DAISYDIR/daisy/bin/dsyperms.pl";

	for my $daisy_db_dir (@daisy_db_dirs) {

		# must be a directory
		next unless (-d $daisy_db_dir);

		# skip old daisy dirs
		next if ($daisy_db_dir =~ /.+-\d{12}$/);

		# must contain the magic files
		next unless(-e "$daisy_db_dir/flordat.tel");
		next unless(-e "$daisy_db_dir/control.dsy");

		if (-f "$DAISYDIR/daisy/bin/dsyperms.pl") {
			showinfo("Running $dsyperms_cmd $daisy_db_dir");
			system("perl $dsyperms_cmd $daisy_db_dir 2>> $LOGFILE");
		} else {
			logerror("Error: expecting script to exist: $dsyperms_cmd");
			logerror("Error: could not run: $dsyperms_cmd");
		}
	}

	return(1);
}

#
# Function to determine if an arbitrary path is a path to a
# daisy databse directory.
#
sub is_daisy_db_dir
{
	my ($path) = @_;

	# must begin with '/d/'
	return(0) unless ($path =~ /^\/d\//);

	# must be a directory
	return(0) unless (-d $path);

	# skip old daisy dirs
	return(0) if ($path =~ /^\/d\/.+-\d{12}$/);

	# must contain the magic files
	return(0) unless (-e "$path/flordat.tel");
	return(0) unless (-e "$path/control.dsy");

	# must be daisy 8.0+
	return(0) unless (-d "$path/bin");

	return(1);
}

sub send_email
{
    my ($recipients, $subject, $message) = @_;

    my $rc = 1;

    # tack the system hostname onto end of the subject.
    my $hostname = hostname();
    $subject .= " $hostname";

    # frist choice, send via "sendmail"
    if ($EMAIL_SERVER eq 'sendmail') {
	# Use the sendmail program directly
	if (send_email_sendmail($recipients, $subject, $message)) {
	    loginfo("email sent via sendmail: @{$recipients}");
	}
	else {
	    logerror("error sending email via sendmail: @{$recipients}");
	    $rc = 0;
	}
    }

    # second choice via configured SMTP server with credentials
    elsif ($EMAIL_SERVER) {
	# If configured to do so, try sending email via smtp server
	if ($EMAIL_USER && $EMAIL_PASS){
	    if (send_email_smtp($recipients, {subject  => $subject,
					      message  => $message,
					      server   => $EMAIL_SERVER,
					      username => $EMAIL_USER,
					      password => $EMAIL_PASS})) {
		loginfo("email sent via SMTP server: @{$recipients}");
	    }
	    else {
		logerror("error sending email via SMTP server: @{$recipients}");
		$rc = 0;
	    }
	}
	else {
	    showerror("username and password required to send email via SMTP server");
	    $rc = 0;
	}
    }

    # third choice, try to use Mutt (and thus indirectly sendmail)
    elsif ( ($EMAIL_SERVER eq $EMPTY_STR) || ($EMAIL_SERVER eq 'mutt') ) {
	if (send_email_mutt($recipients, $subject, $message)) {
	    loginfo("email sent via mutt(1): @{$recipients}");
	}
	else {
	    logerror("error sending email via mutt(1): @{$recipients}");
	    $rc = 0;
	}
    }

    return($rc);
}


#
# Send email via direct connect from this script, to an SMTP(s) server.
# This "way" of sending email totally bypasses the use of sendmail, and
# could also resolve issues with email blacklisting.
#
# Returns
#   1 on success
#   0 on error
#
sub send_email_smtp
{
    my ($recipients, $arg_ref) = @_;

    my $hostname = hostname();
    my $rc = 1;

    foreach my $recipient (@{$recipients}) {

	loginfo("sending email via SMTP server to: $recipient");

	# Connect to an SMTP server.
	my $smtp = Net::SMTP->new($arg_ref->{server}, Port=> 25);
	if ($smtp) {
	    $smtp->auth($arg_ref->{username}, $arg_ref->{password});
	    $smtp->mail("backups\@$hostname");
	    $smtp->to("$recipient\n", {SkipBad => 1} );
	    $smtp->data();
	    $smtp->datasend("From: backups\@$hostname\n");
	    $smtp->datasend("To: $recipient\n");
	    $smtp->datasend("Subject: $arg_ref->{subject}\n");
	    $smtp->datasend("\n");
	    $smtp->datasend("$arg_ref->{message}\n");
	    $smtp->dataend();
	    $smtp->quit;
	}
	else {
	    logerror("error connecting to email SMTP server: $arg_ref->{server}");
	    $rc = 0;
	}
    }

    return($rc);
}

sub send_email_mutt
{
    my @recipients = @{$_[0]};
    my $subject = $_[1];
    my $message = $_[2];

    my $rc = 1;

    #["foo,bar,fee"] -> ["foo", "bar", "fee"]
    @recipients = split(/,/, join(',', @recipients));

    foreach my $recipient(@recipients) {
	next if("$recipient" eq "");
	loginfo("Sending email to $recipient via MUTT");
	if (open(my $mutt_fh, '|-', "mutt -s \"$subject\" $recipient")) {
	    print($mutt_fh $message);
	    close($mutt_fh);
	}
	else {
	    logerror("error opening pipe to mutt: $!");
	    $rc = 0;
	}
    }

    return($rc);
}

#
# Send email via pipe to "sendmail" command.
#
# Returns
#   1 on success
#   0 on error
#
sub send_email_sendmail
{
    my ($recipients, $subject, $message) = @_;

    my $rc = 1;

    my $sendmail_cmd = '/usr/lib/sendmail';
    unless (-x $sendmail_cmd) {
	logerror("error sending email: sendmail command does not exist: $sendmail_cmd: $!");
	return(0);
    }

    my $hostname = hostname();
    my $from = "$PROGNAME\@${hostname}.teleflora.com";

    my $cmd = "$sendmail_cmd -oi -t";

    # any recipients from the command line are a comma separated string but
    # the recipients from the config file are not.
    my @recipient_list = split(/,/, join(',', @{$recipients}));

    foreach my $recipient (@recipient_list) {
	if (open(my $mail_fh, '|-', $cmd)) {
	    loginfo("Sending email via sendmail to: $recipient");
	    print $mail_fh "From: $from\n";
	    print $mail_fh "To: $recipient\n";
	    print $mail_fh "Subject: $subject\n\n";
	    print $mail_fh "$message\n";
	    close($mail_fh);
	}
	else {
	    logerror("error sending email to recipient: $recipient");
	    $rc = 0;
	}
    }

    return($rc);
}


sub build_results_msg
{
    my ($subject, $message) = @_;

    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime());

    my $results_msg = "=============================================================\n";
    $results_msg   .= "$subject\n";
    $results_msg   .= "Begin Printout: $timestamp\n";
    $results_msg   .= "=============================================================\n";
    $results_msg   .= "\n";
    $results_msg   .= "\n";
    $results_msg   .= "\n";
    $results_msg   .= "\n";
    $results_msg   .= "\n";
    $results_msg   .= "$message\n";
    $results_msg   .= "\n";
    $results_msg   .= "\n";
    $results_msg   .= "\n";
    $results_msg   .= "\n";
    $results_msg   .= "\n";
    $results_msg   .= "=============================================================\n";
    $results_msg   .= "End Printout: $timestamp\n";
    $results_msg   .= "$subject\n";
    $results_msg   .= "=============================================================\n";

    return($results_msg);
}


#
# Send backup results to a named printer.
#
sub print_results
{
    my @printers = @{$_[0]};
    my $subject = $_[1];
    my $message = $_[2];

    my $tmpfile = "/tmp/rtibackup.results.$$";

    my $rc = 1;

    #["foo,bar,fee"] -> ["foo", "bar", "fee"]
    @printers = split(/,/, join(',', @printers));

    # pipe message to each defined printer
    foreach my $printer (@printers) {
	next if ($printer eq "");

	my $results_msg = build_results_msg($subject, $message);
	if (open(my $results_fh, '>', $tmpfile)) {
	    print $results_fh $results_msg;
	    close($results_fh);

	    system("unix2dos < $tmpfile | lp -d $printer -s");
	    if ($? == 0) {
		loginfo("results message successfully sent to printer: $printer");
	    }
	    else {
		logerror("error sending results message to printer ($printer): $?");
		$rc = 0;
	    }
	}
	else {
	    logerror("error generating results file: $tmpfile");
	}
    }

    unlink $tmpfile if (-e $tmpfile);

    return($rc);
}


#
# Copy script to bin directory, set modes and owners.
# If the path to this script is the same as the destination,
# there is no need to copy and thus a nasty diagnostic is avoided.
#
sub install_script
{
	if ($0 ne "$TOOLSDIR/bin/$PROGNAME") {
		system("cp $0 $TOOLSDIR/bin/");
	}
	system("chown root:root $TOOLSDIR/bin/rtibackup.pl");
	system("chmod 555 $TOOLSDIR/bin/rtibackup.pl");

	# Now remove old versions in $POSDIR/bin and make symlinks
	if (-d "/usr2/bbx/bin") {
		system("rm -f /usr2/bbx/bin/rtibackup.pl");
		system("ln -sf $TOOLSDIR/bin/rtibackup.pl /usr2/bbx/bin");
	}
	if (-d "/d/daisy/bin/") {
		system("rm -f /d/daisy/bin/rtibackup.pl");
		system("ln -sf $TOOLSDIR/bin/rtibackup.pl /d/daisy/bin");
	}

	return(1);
}


#
# if the ostools config dir does not exist, make it
#
# returns
#   TRUE if ostools config dir exists or mkdir is successful
#   FALSE if ostools config dir does not exist and mkdir fails
#
sub install_ostools_config_dir
{
    my ($config_dir) = @_;

    my $retval = 1;

    if (! -d $config_dir) {

	if (-f $config_dir) {
	    system("rm -f $config_dir");
	}

	system("mkdir $config_dir");

	if (! -d $config_dir) {
	    showerror("Can not make OSTools config dir: $config_dir");
	    $retval = 0;
	}

	else {

	    my $owner = "root";
	    my $group = "root";

	    if (-d "/usr2/bbx") {
		$owner = "tfsupport";
		$group = "rtiadmins";
	    }
	    elsif (-d "/d/daisy") {
		$owner = "tfsupport";
		$group = "dsyadmins";
	    }
	    system("chown $owner:$group $config_dir");
	    system("chmod 775 $config_dir");
	}
    }

    return($retval);
}


sub rb_install_cron_job
{
	my $label = '[install_cron_job]';
	# Get rid of old backup cron job files
	if (-f '/etc/cron.d/rti-backup') {
		system("rm -f /etc/cron.d/rti-backup");
	}
	if (-f '/etc/cron.d/daisy-backup') {
		system("rm -f /etc/cron.d/daisy-backup");
	}

	my $cron_job_file = rb_pathto_cron_job_file();

	# If a cron job file already exists, don't overwrite it since
	# it might have site dependent contents.  Put the new version
	# into the ostools config directory.

	if (-e $cron_job_file) {
	    my $ostools_config_dir = rb_pathto_ostools_config_dir();
	    if (install_ostools_config_dir($ostools_config_dir)) {
		loginfo("$label OSTools config dir exists: $ostools_config_dir");
	    }
	    else {
		showerror("$label OSTools config dir doesn't exist: $ostools_config_dir");
		return(0);
	    }
	    my $cron_job_file_name = rb_nameof_cron_job_file();
	    $cron_job_file = $ostools_config_dir . $SLASH . $cron_job_file_name . '.new';
	}

	# Make a new combined cron job file
	my $cron_job_contents = << 'EOF';
# Do not edit this file.
#
# Automated Nightly backups.
# See also config file /usr2/bbx/config/backups.config
# See also config file /d/daisy/config/backups.config
#

# RTI - Nightly Backups.
30 01 * * * root (/usr/bin/test -e /usr2/bbx && . /etc/profile.d/rti.sh && /usr2/bbx/bin/rtibackup.pl --rti --configfile=/usr2/bbx/config/backups.config --format --backup=all --verify --console)

# Daisy - Nightly Backups.
35 01 * * * root (/usr/bin/test -e /d/daisy && /d/daisy/bin/rtibackup.pl --daisy --format --backup=all --verify --console)

EOF
	if (open(my $cron_fh, '>', $cron_job_file)) {
	    # write first line normal way so we can inject variable values
	    print($cron_fh "#\n");
	    print($cron_fh "# Generated by $PROGNAME $CVS_REVISION $TIMESTAMP\n");
	    print($cron_fh "#\n");

	    print($cron_fh $cron_job_contents);
	    close($cron_fh);

	    system("chown root:root $cron_job_file");
	    system("chmod 644 $cron_job_file");
	}
	else {
	    showerror("$label could not generate new cron job file: $cron_job_file");
	}

	return(1);
}


sub install_edit_root_crontab
{
    my $rc = 1;

    # Only need to edit crontab if root crontab exists
    system("crontab -u root -l > /dev/null 2>&1");
    if ($? == 0) {

	# Remove from root crontab entries for RTI or Daisy
	if (open(my $old_fh, '-|', "crontab -u root -l")) {
	    if (open(my $new_fh, '>', "/tmp/crontab.$$")) {
		while (<$old_fh>) {
		    if (/dsyclean.pl/ || /daisyback/ || /dback/ || /dayback/) {
			unless (/^(\s*)(#)/) {
			    # this entry has not already been pounded out.
			    print($new_fh "# $_");
			}
			next;
		    }
		    else {
			print($new_fh $_);
		    }
		}
		close($new_fh);
	    }
	    else {
		logerror("error opening write to new cron job file: /tmp/crontab.$$");
		$rc = 0;
	    }
	    close($old_fh);
	}
	else {
	    logerror("error opening pipe reading root crontab");
	    $rc = 0;
	}

	if (-s "/tmp/crontab.$$" > 0) {
	    system("crontab -u root /tmp/crontab.$$");
	    loginfo("new root crontab file generated");
	}
	else {
	    logerror("error generating new root crontab file");
	    $rc = 0;
	}

	unlink("/tmp/crontab.$$");
    }

    return($rc);
}


# Add an init.d entry for the "rtibackup data secondary server".
# Make sure *not* to enable this by default, though.
# This option is rarely used, especially in daisy, and,
# we do not want it running by default, as, it exposes a
# listening TCP port.  However, we do want this service
# to be available for those shops who are performing
# backups to a secondary server.

sub install_secondary_server
{
    my $init_file_contents = << 'xxxEOFxxx';
#!/bin/bash
#
# rtibackup-secondary  Act as a POS Secondary Server for Backup Data.
#
# chkconfig: 345 25 75
# description: Starts daemon which listens for incoming POS data, and places that onto local disk.
### BEGIN INIT INFO
# Provides: $rti-datasync
### END INIT INFO


case "$1" in
 start)
	if [ -x /usr2/bbx/bin/rtibackup.pl ] ; then
        	/usr2/bbx/bin/rtibackup.pl --secondary --configfile=/usr2/bbx/config/backups.config
	elif [ -x /d/daisy/bin/rtibackup.pl ] ; then
        	/d/daisy/bin/rtibackup.pl --secondary --configfile=/d/daisy/config/backups.config
	else
		echo "rtibackup script not found."
	fi
	;;
	
 stop)
        killall rtibackup.pl
	;;

 status)
        ps wwaux | grep rtibackup.pl
	;;

 *)
	echo "usage: $0 start|stop|status"
	exit 1
esac

exit $?
xxxEOFxxx

    my $init_file_path = "/etc/init.d/rtibackup-secondary";
    if (open(my $init_fh, '>', $init_file_path)) {
	print($init_fh $init_file_contents);
	close($init_fh);

	system("chown root:root $init_file_path");
	system("chmod 555 $init_file_path");

	system("/sbin/chkconfig --list | grep rtibackup-secondary > /dev/null 2> /dev/null");
	if ($? != 0) {
	    system("/sbin/chkconfig --add rtibackup-secondary");
	    system("/sbin/chkconfig --level 345 rtibackup-secondary off");
	}
    }
    else {
	logerror("error opening secondary server init.d file for write: $init_file_path");
    }

    return(1);
}


#
# If one does not already exist, write a "template" config file.
#
sub install_configfile
{
	my ($filepath) = @_;

	my $rc = 1;
	my $text = "";

	unless (defined($filepath)) {
	    loginfo("can't happen: install_configfile() called with undefined arg");
	    return;
	}

	if ($filepath eq "") {
	    loginfo("can't happen: install_configfile() called with null arg");
	    return;
	}

	#
	# If config file exists, write a new one with ".new" suffix and
	# leave the old one in place.
	#
	if (-f $filepath) {
	    $filepath = "$filepath.new"
	}

	loginfo("---- BEGIN Install Config File $PROGNAME $CVS_REVISION ----");

	#
	# (RTI)
	# Pick any existing email addresses from current "ltar.cfg" file and
	# add those into our newly generated config file.
	#
	my @email_addrs = ();
	if (-f "/usr/lone-tar/ltar.cfg") {
		loginfo("---- Looking for Email Addresses in ltar.cfg ----");
		if (open(my $ltar_fh, '<', "/usr/lone-tar/ltar.cfg")) {
		    while(<$ltar_fh>) {
			if (/^(\s*)(MAIL_TO)(\s*)(=)(\s*)(\S+)/) {
				chomp;
				$text = $6;
				$text =~ s/\"//g; #strip quotes.
				$text =~ s/,//g; # Strip commas.
				# John Simon is no longer employed by Teleflora.
				$text =~ s/jsimon\@teleflora\.com//g;
				@email_addrs = split(/\s+/,$text);
				last;
			}
		    }
		    close($ltar_fh);

		    foreach (@email_addrs) {
			loginfo("Found Lonetar Email Address: $_");
		    }
		}
		else {
		    logerror("error opening LoneTar config file: /usr/lone-tar/ltar.cfg");
		}
		loginfo("---- Done with ltar.cfg ----");
	}

	my $config_section_1 = << 'EOB';
#
# email=xxxxx
# When backups complete, send an email to the user(s) specified in an "email=" line (below).
# Use multiple "email=" lines, one email address per line.
# Note that the system "mutt" utility is used to send these mails.
#
#email=user@somewhere.com
#email=user2@elsewhere.com

EOB

	my $config_section_2 = << 'EOB';

#
# emailserver=smtp.isp.com
# In the event that email does not "just work", this option allows us to send an email via
# a 3rd party. For example, sending "through" gmail, yahoo, or your ISP.
# Using this requires you have a 3rd party email "username" and "password" as well
# as the "smtp" host which your provider uses (eg "smtp.google.com", "smtp.emailsrvr.com", etc)
# Note that your password will be stored here in cleartext.
#
#email_server=smtp.google.com
#email_username=someone@gmail.com
#email_password=gmailpassword
#
# Use the sendmail program
#email_server=sendmail


#
# printer=xxxxx
# When backups complete, send verify results to one of the printers listed here.
# Multiple "printer=xxxxxxx" lines are allowed, in which case, results will be sent to multiple printers.
# "xxxxxx" represents the printer queue name; typically the "cups printer name."
#
#printer=printer11
#printer=order1


#
# ejectdays=never
# ejectdays=always
# ejectdays=weekdays
# ejectdays=mon,tue,wed,thu,fri,sat,sun
# ejectdays=mon,wed,fri
# ejectdays=xxx,xxx,xxx...
#
# This only applies to devices which can be ejected, eg the revdrive.
# When a backup succeeds, on which days of the week should the device be ejected?
# Some shops never want their device ejected, other shops want the device ejected
# with every successful backup.
#
# Most shops are not in the office on Sunday, thus, would not want the device
# ejected on Sunday. Many shops may not want the device ejected over the weekend.
#
# This config option enables some control over when the device is ejected.
# Note that the device is never ejected if the backup failed.
#
ejectdays=weekdays


#
# exclude=/path/to/somewhere
# Exclude files or paths from the configured backups.
# Note that multiple "exclude=" lines are allowed, and results are passed
# directly into a tar "exclude" file (see tar man page.)
#
#exclude=/path/to/file
#exclude=filename


#
# restore-exclude=/path/to/directory
# restore-exclude=/path/to/file
# Multiple of these are allowed.
# Only used during restore.
# Note: if there were values specified on the command line via the
# "--restore-exclude=" option, then the values specified in the
# config file will be added to those specified on the command line.
#restore-exclude=/path/to/directory
#restore-exclude=/path/to/file
#restore-exclude=filename

#
# userfile=/path/to/somewhere
# userfile=/path/to/somewhere
# ...
# Include "user specified" files for backup into the "--backup=include"
# option.
# Note that multiple "include=" lines are allowed.
# Note that "exclude" rules (above) are ignored when these "userfiles" are
# backed up.
#
#userfile=/path/to/file
#userfile=filename


#
# Specify which device we will use to backup.
# Note that this device is normally auto-detected, however, by specifying a default,
# one could use "non-standard" devices such as external hard disks, USB thumb drives
# or even "loopback" image files.
#
# Use this option with care!
# Especially when working with removable media. If you specify some device here
# which turns out to be your primary partition, you will wind up wiping out your primary partition.
#
# To create a "loopback" image file, some examples are below. Make sure to --format the device
# before use:
# dd if=/dev/zero of=/path/to/file.img bs=1M count=30000 #30 GB image file.
#
#device=/dev/scd0
#device=/path/to/file.img

#
# Identify the vendor and model of an external disk.  These are the
# strings that appear in the following files:
#
#   /sys/block/sd[a|b|c|d|e]/device/vendor
#   /sys/block/sd[a|b|c|d|e]/device/model
#
# Default values:
#device-vendor=WD
#device-model="My Passport"
#
# Example for other block devices:
#device-vendor=Seagate
#device-model="FreeAgent GoFlex"


#
# If set to true, the tar files written to the backup device will be
# compressed with bzip2.  The default is to not compress.
#
#compress=false


#
# If set to true, the tar files read from the backup device are
# decompressed with bzip2.  The default is to not decompress.
#
#decompress=false


# If set to true, run in debug mode
# Default: false.
#
#debugmode=false


# If set to true, then if there is a verify error on a backup device,
# and a specific backup type was specified on the command line,
# then an fsck of the backup device will be performed.
#
#autocheckmedia=false


# If set to true, then look for a device on the USB bus that
# has a file system label of "TFBUDSK-yyyymmdd".
#
#usb-device=false


#
# rti=true
# rti=yes
# Hint the backup script that this is an "rti" system.
# This is normally auto-detected.
#
#rti=true
#rti=false


#
# daisy=true
# daisy=false
# daisy=yes
# daisy=no
# Hint the backup script that this is a "daisy" system.
# This is normally auto-detected.
#
#daisy=true
#daisy=false
EOB

	if (open(my $conf_fh, '>', $filepath)) {

	    print($conf_fh "#\n");
	    print($conf_fh "# $PROGNAME Config File\n");
	    print($conf_fh "# Generated by $PROGNAME $CVS_REVISION $TIMESTAMP\n");
	    print($conf_fh "#\n");

	    print($conf_fh $config_section_1);

	    # The Long Tar config file uses a value of "off" as a special
	    # email address that means "do not send email".
	    my $lone_tar_special_addr = "off";

	    # Add any email addresses which we found from ltar.cfg
	    foreach (@email_addrs) {
		if (! /$lone_tar_special_addr/i) {
		    print($conf_fh "email=$_\n");
		}
	    }

	    print($conf_fh $config_section_2);

	    close($conf_fh);
	}
	else {
	    logerror("error opening config file for write: $filepath");
	    $rc = 0;
	}

	loginfo("---- END Install Configfile ----");

	return($rc);
}


# Write a default config file if need be.
sub install_default_config_file
{
	my $owner = "root";
	my $group = "root";
	my $conf_file = "$TOOLSDIR/config/backups.config";

	if (-d "/usr2/bbx/config") {
		$conf_file = "/usr2/bbx/config/backups.config";
		$owner = "tfsupport";
		$group = "rtiadmins";
	}
	elsif (-d "/d/daisy/config") {
		$conf_file = "/d/daisy/config/backups.config";
		$owner = "tfsupport";
		$group = "dsyadmins";
	}

	install_configfile($conf_file);
	system ("chown $owner:$group $conf_file");
	system ("chmod 554 $conf_file");

	return(1);
}


sub install_mount_point
{
    my $rc = 1;

    if (-d $MOUNTPOINT) {
	loginfo("mountpoint verified: $MOUNTPOINT");
    }
    else {
	if ($VERBOSE) {
	    showinfo("making mountpoint: $MOUNTPOINT");
	}
	if (mkdir($MOUNTPOINT)) {
	    loginfo("mkdir of mountpoint successful: $MOUNTPOINT");
	}
	else {
	    showerror("could not make mountpoint: $MOUNTPOINT: $!");
	    $rc = 0;
	}
    }

    return($rc);
}


sub install_rtibackup
{
	loginfo("---- BEGIN Installation $PROGNAME $CVS_REVISION ----");

	install_script();

	rb_install_cron_job();

	install_edit_root_crontab();

	install_default_config_file();

	install_mount_point();

	loginfo("---- END rtibackup installation ----");

	return(1);
}

#
# if there is a line in the cron job file that starts with
# either a digit or an ASTERISK, and has "rtibackup.pl" on it,
# then the cron job is enabled.
#
# returns
#   TRUE if installed and enabled
#   FALSE if not
#
sub rb_report_is_backup_cron_job_enabled
{
    my $rc = 0;
    my $label = '[report_is_backup_cron_job_enabled]';

    my $cron_job_file = rb_pathto_cron_job_file();
    if (open(my $fh, '<', $cron_job_file)) {
	while (my $line = <$fh>) {
	    my $pattern = $EMPTY_STR;
	    if ($RTI) {
		$pattern = '(\d|\*).+\/usr2\/bbx\/bin\/rtibackup.pl';
	    }
	    if ($DAISY) {
		$pattern = '(\d|\*).+\/d\/daisy\/bin\/rtibackup.pl';
	    }
	    if ($line =~ /^$pattern/) {
		$rc = 1;
		last;
	    }
	}
	close($fh) or warn "$label could not close $cron_job_file: $OS_ERROR\n";

	if ($rc) {
	    loginfo("$label backup is enabled in cron job file: $cron_job_file");
	}
	else {
	    showerror("$label backup not enabled in cron job file: $cron_job_file");
	}

    }
    else {
	showerror("$label could not open cron job file: $cron_job_file");
    }

    return($rc);
}


#
# is backup installed and enabled?
#
# Definition of installed and enabled:
#   1) script exists in ostools bin dir
#   2) symlink exists from RTI or Daisy to ostools bin dir
#   3) mount point exists
#   4) cron job file exists and rtibackup.pl is not commented out
#
# returns
#   TRUE if installed and enabled
#   FALSE if not
#
sub rb_report_is_backup_enabled
{
    my $rc = 0;
    my $label = '[rb_report_is_backup_enabled]';

    my $ostools_bin_dir = rb_pathto_ostools_bin_dir();
    my $script_name = rb_nameof_script();
    my $script = "$ostools_bin_dir/$script_name";
    if (-e $script) {
	my $pos_bin_dir = rb_pathto_pos_bin_dir();
	my $symlink = "$pos_bin_dir/$script_name";
	if (-l $symlink) {
	    my $mount_point = rb_pathto_mountpoint();
	    if (-e $mount_point) {
		if (rb_report_is_backup_cron_job_enabled()) {
		    $rc = 1;
		}
	    }
	    else {
		showerror("$label mount point does not exist: $mount_point");
	    }
	}
	else {
	    showerror("$label symlink does not exist: $symlink");
	}
    }
    else {
	showerror("$label script does not exist: $script");
    }

    return($rc);
}


sub report_configfile_entry
{
    my ($configfile_entry) = @_;

    loginfo("\tConfigfile: $configfile_entry");
    if ($REPORT_CONFIGFILE) {
	print "$configfile_entry\n";
    }

    return(1);
}


sub parse_config_file
{
    my ($conf_fh) = @_;

    while (<$conf_fh>) {

	# printer=cups_prn_name
	# Multiple of these are allowed.
	if (/^\s*printer\s*=\s*([[:print:]]+)$/i) {
	    push(@PRINTER, $1);
	    report_configfile_entry("--printer=\"$1\"");
	}

	# email=someone@foo.com
	# Multiple of these are allowed.
	if (/^\s*email\s*=\s*([[:print:]]+)$/i) {
	    push(@EMAIL, $1);
	    report_configfile_entry("--email=\"$1\"");
	}

	# If we want to try sending emails via, say, gmail or yahoo.
	if (/^\s*email_server\s*=\s*([[:print:]]+)$/i) {
	    $EMAIL_SERVER = $1;
	    report_configfile_entry("Email Server =\"$1\"");
	}
	if (/^\s*email_username\s*=\s*([[:print:]]+)$/i) {
	    $EMAIL_USER = $1;
	    report_configfile_entry("Email Username=\"$1\"");
	}
	if (/^\s*email_password\s*=\s*([[:print:]]+)$/i) {
	    $EMAIL_PASS = $1;
	    report_configfile_entry("Email Password=\"xxxxxxx\"");
	}

	# exclude=/path/to/directory
	# exclude=/path/to/file
	# Multiple of these are allowed.
	# Only used during backup.
	if (/^\s*exclude\s*=\s*([[:print:]]+)$/i) {
	    push(@EXCLUDES, $1);
	    report_configfile_entry("Will exclude backup of \"$1\"");
	}

	# restore-exclude=/path/to/directory
	# restore-exclude=/path/to/file
	# Multiple of these are allowed.
	# Only used during restore.
	# Note: if there were values specified on the command line via the
	# "--restore-exclude=" option, then the values specified in the
	# config file will be added to those specified on the command line.
	if (/^\s*restore-exclude\s*=\s*([[:print:]]+)$/i) {
	    push(@RESTORE_EXCLUDES, $1);
	    report_configfile_entry("Will exclude restore of \"$1\"");
	}

	# userfile=/path/to/directory
	# userfile=/path/to/file
	# Multiple of these are allowed.
	# Only used during backup.
	# Backs up into "other" category.
	if (/^\s*userfile\s*=\s*([[:print:]]+)$/i) {
	    push(@USERFILES, $1);
	    report_configfile_entry("userfile=\"$1\"");
	}

	# Which backup device to use.
	# device=/dev/whatever
	if (/^\s*device\s*=\s*([[:print:]]+)$/i) {
	    $DEVICE = $1;
	    report_configfile_entry("--device=$DEVICE");
	}

	# Which vendor for external backup device to use.
	# The default value is:
	# device-vendor=WD
	if (/^\s*device-vendor\s*=\s*([[:print:]]+)$/i) {
	    $DEVICE_VENDOR = $1;
	    $DEVICE_VENDOR =~ s/"//g;
	    report_configfile_entry("--device-vendor=\"$DEVICE_VENDOR\"");
	}

	# Which model for external backup device to use.
	# The default value is:
	# device-model=My Passport
	if (/^\s*device-model\s*=\s*([[:print:]]+)$/i) {
	    $DEVICE_MODEL = $1;
	    $DEVICE_MODEL =~ s/"//g;
	    report_configfile_entry("--device-model=\"$DEVICE_MODEL\"");
	}

	# When to eject the backup media
	# eject=never
	# eject=always
	# eject=weekdays
	# eject=mon,tue,wed,thu,fri,sat,sun
	if (/^\s*ejectdays\s*=\s*([[:print:]]+)$/i) {
	    $EJECTDAYS = lc($1);
	    $EJECTDAYS =~ s/(\s+)//g; # Strip out spaces.
	    if($EJECTDAYS =~ /weekdays/i) {
		$EJECTDAYS =~ s/weekdays/mon,tue,wed,thu,fri/g;
	    }
	    if($EJECTDAYS =~ /weekend/i) {
		$EJECTDAYS =~ s/weekend/sat,sun/g;
	    }
	    report_configfile_entry("ejectdays=$EJECTDAYS");
	}

	# Use compression when writing tar files?
	# compress=1
	# compress=True / compress=true
	# compress=Yes / compress=yes
	if (/^\s*compress\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		$COMPRESS_BU = 1;
		report_configfile_entry("--compress");
	    }
	}

	# Use decompression when reading tar files?
	# decompress=1
	# decompress=True / decompress=true
	# decompress=Yes / decompress=yes
	if (/^\s*decompress\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		$DECOMPRESS_BU = 1;
		report_configfile_entry("--decompress");
	    }
	}

	# Run in debug mode
	# debugmode=1
	# debugmode=True
	# debugmode=Yes
	if (/^\s*debugmode\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		$DEBUGMODE = 1;
		report_configfile_entry("--debugmode");
	    }
	}

	# Do autocheckmedia?
	# autocheckmedia=1
	# autocheckmedia=True / autocheckmedia=true
	# autocheckmedia=Yes / autocheckmedia=yes
	if (/^\s*autocheckmedia\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		$AUTO_CHECKMEDIA = 1;
		report_configfile_entry("--autocheckmedia");
	    }
	}

	# Use a USB device?
	# usb-device=1
	# usb-device=True / usb-device=true
	# usb-device=Yes / usb-device=yes
	if (/^\s*usb-device\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		$USB_DEVICE = 1;
		report_configfile_entry("--usb-device");
	    }
	}

	# Is this an RTI system?
	# rti=1
	# rti=True / rti=true
	# rti=Yes / rti=yes
	if (/^\s*rti\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		$RTI = 1;
		report_configfile_entry("--rti");
	    }
	}

	# Is this a daisy system?
	# daisy=1
	# daisy=True / daisy=true
	# daisy=Yes / daisy=yes
	if (/^\s*daisy\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		$DAISY = 1;
		report_configfile_entry("--daisy");
	    }
	}
    }

    return(1);
}

#
# Read config file.
#
# Returns 0 on success, 1 on error.
#
sub read_configfile
{
    my ($configfile) = @_;

    my $rc = 1;

    if ($configfile eq "") {
	logerror("Can't happen: config file value is the empty string");
	return($rc);
    }
    unless (-e $configfile) {
	logerror("Config file does not exist: $configfile");
	return($rc);
    }

    loginfo("Reading config file: $configfile");

    if (open(my $conf_fh, '<', $configfile)) {

	if (parse_config_file($conf_fh)) {
	    loginfo("config file parsed: $configfile");
	}
	else {
	    logerror("error parsing config file: $configfile");
	    $rc = 0;
	}

	close($conf_fh);
    }
    else {
	logerror("error opening config file: $configfile");
	$rc = 0;
    }

    return($rc);
}


sub get_command_line
{
	my $cmd_line = $EMPTY_STR;

	$cmd_line = $0;
	foreach my $i (@ARGV) {
		$cmd_line .= " ";
		if ($i =~ /\s/) {
			if ($i =~ /(--[[:print:]]+)(=)(.+)$/) {
				$cmd_line .= "$1$2\"$3\"";
			}

			else {
				$cmd_line .= "\"$i\"";
			}
		}

		else {
			$cmd_line .= "$i";
		}
	}

	return($cmd_line);
}

sub rb_nameof_script
{
    return($PROGNAME);
}

sub rb_nameof_cron_job_file
{
    return($CRON_JOB_FILE_NAME);
}

sub rb_pathto_ostools_dir
{
    return($TOOLSDIR);
}

sub rb_pathto_ostools_bin_dir
{
    my $ostools_dir = rb_pathto_ostools_dir();
    return("$ostools_dir/bin");
}

sub rb_pathto_ostools_config_dir
{
    my $ostools_dir = rb_pathto_ostools_dir();
    return("$ostools_dir/config");
}

sub rb_pathto_pos_bin_dir
{
    my $pos_dir = "$RTIDIR/bin";
    if ($DAISY) {
	$pos_dir = "$DAISYDIR/daisy/bin";
    }

    return($pos_dir);
}

sub rb_pathto_cron_job_file
{
    return($CRON_JOB_FILE_PATH);
}

sub rb_pathto_mountpoint
{
    return($MOUNTPOINT);
}


#
# Change the location of the logfile - when doing a "--restore=all" or
# a "--restore=rti" on an RTI system, or a "--restore=daisy" on a Daisy
# system, the logfile location is going to be replaced.
#
# The only real choice for a new temporary location is /tmp.  After
# the restore is done, copy the temporary logfile back to the normal
# location.
#
sub log_change_location
{
    return if ($LOGFILE eq "");

    # First, make a temp logfile based on name of standard logfile
    my $logfile_basename = basename($LOGFILE);
    my $tmp_dir = "/tmp";
    my $tmp_logfile = make_tempfile("$tmp_dir/$logfile_basename");

    # save path to old logfile
    my $old_logfile_path = $LOGFILE;

    # switch to temp logfile after writing message to old logfile
    loginfo("#");
    loginfo("# Switching to temp logfile: $tmp_logfile");
    loginfo("#");
    $LOGFILE = $tmp_logfile;

    # write message to new temp logfile
    loginfo("#");
    loginfo("# Logfile location switched");
    loginfo("#");
    loginfo("#\tTemporary logfile: $LOGFILE");
    loginfo("#\tPrevious logfile: $old_logfile_path");

    return($old_logfile_path);
}

sub log_restore_location
{
    my ($orig_logfile_path) = @_;

    # save path to temp logfile
    my $tmp_logfile = $LOGFILE;

    # switch to standard logfile after writing message to temp logfile
    loginfo("#");
    loginfo("# Switching to original logfile: $orig_logfile_path");
    loginfo("#");
    $LOGFILE = $orig_logfile_path;

    # write status message to standard logfile
    loginfo("#");
    loginfo("# Logfile location switched");
    loginfo("#");
    loginfo("#\tCurrent logfile: $LOGFILE");
    loginfo("#\tTemporary logfile: $tmp_logfile");
    loginfo("#");

    # concatenate temp logfile to the standard log file
    loginfo("#");
    loginfo("# BEGIN including contents of temp logfile");
    loginfo("#");
    system("cat $tmp_logfile >> $LOGFILE");
    my $cat_status = $?;
    loginfo("#");
    loginfo("# END including contents of temp logfile");
    loginfo("#");

    if ($cat_status != 0) {
	# could not copy contents of temp logfile
	logerror("Concatenation of temp logfile to standard log file failed");
	loginfo("Contents of temp logfile preserved: $tmp_logfile");
	loginfo("Please remove when no longer needed");
    }
    else {
	# success, so rm previous logfile
	unlink "$tmp_logfile";
	loginfo("Temp logfile removed: $tmp_logfile");
    }

    return(1);
}


# Remove tomorrow's logfile.
sub logrotate
{
	my ($logfile) = @_;

	#
	# If the format of the log file is one that can be rotated, that is,
	# it ends with "-Day_nn.log", then "rotate it":
	#   - remove tomorrow's instance.
	#   - form file name with todays day of the month
	#
	if ($logfile =~ /(.*)-(Day_\d\d)\.log/) {
		my $logfiletype = $1;
		my $today = strftime("Day_%d", localtime(time())) . ".log";
		my $tomorrow = strftime("Day_%d", localtime(time() + (60*60*24))) . ".log";
		if (unlink "$logfiletype-$tomorrow") {
			loginfo("Logfile Rotation: tomorrow's logfile removed: $logfiletype-$tomorrow");;
		}
		my $new_logfile_name = "$logfiletype-$today";
			loginfo("Logfile Rotation: current logfile: $logfiletype-$today");;
		return($new_logfile_name);
	}

	return($logfile);
}


sub showerror
{
	my ($message) = @_;

	print("$message\n");
	return(loginfo("<E>  $message"));
}

sub logerror
{
	my ($message) = @_;

	print("$message\n");
	return(loginfo("<E> $message"));
}

sub logdebug
{
	my ($message) = @_;

	if($VERBOSE != 0) {
		print("$message\n");
		return(loginfo("<D> $message"));
	}
}


# Print to screen, and log to logfile.
sub showinfo
{
	my ($message) = @_;

	print("$message\n");
	return(loginfo("<I>  $message"));
}


#
# Write message to logfile.
#
sub loginfo
{
    my ($message) = @_;

    # Is a log directory in place? If so, keep a logfile as well.
    unless (-d "$RTIDIR/log" || -d "$DAISYDIR/daisy/log") {
	return(0);
    }

    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime(time()));

    if (open(my $log_fh, '>>', $LOGFILE)) {
	print($log_fh "$timestamp");
	if ( ($message !~ /<E>/) &&  ($message !~ /<D>/) &&  ($message !~ /<I>/) ) {
	    print($log_fh " <I> ");
	}
	print($log_fh " $message\n");
	close($log_fh);

	# insurance that processes can access the log file
	system "chmod 666 $LOGFILE";
    }
    else {
	print "$timestamp $message\n";
    }

    return(1);
}

sub debuglog
{
    my ($message) = @_;

    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime(time()));

    if (open(my $log_fh, '>>', $DEBUGLOGFILE)) {
	print($log_fh "$timestamp $message\n");
	close($log_fh);
    }
    else {
	print "$timestamp $message\n";
    }

    return(1);
}


__END__

=pod

=head1 NAME

rtibackup.pl - OSTools backup script for RTI and Daisy

=head1 VERSION

This documenation refers to version: $Revision: 1.367 $



=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--install>

Install the script.

=item B<--backup=s>

Perform a backup.

Modifiers: B<--device=s>, B<--usb-device>, B<--compress>, B<--nocc>,
B<--cryptkey=s>, B<--rti>, and B<--daisy>.

=item B<--restore=s>

Restore files from a backup.

Modifiers: B<--device>, B<--usb-device>, B<--restore-exclude=s>, B<--decompress>,
B<--cryptkey=s>, B<--force>, B<--rootdir=s>, B<--[no]harden-linux>,
B<--dry-run> and B<--upgrade>.

=item B<--list=s>

List the files in a backup.

Modifiers: B<--device>, B<--usb-device>, B<--rti> and B<--daisy>.

=item B<--verify>

Verify a backup.

Modifiers: B<--console>, B<--[no]autocheckmedia>, B<--verbose>, B<--rti>, and B<--daisy>.

=item B<--checkmedia>

Check the media of a backup device.
May be used with B<--backup=s>.

Modifiers: B<--checkmedia>,  B<--email=s>, and B<--printer=s>.

=item B<--format>

Format the backup device.
May be used with B<--backup=s>.

Modifiers: B<--force>, and B<--verbose>.

=item B<--eject>

Eject the media from a backup device.

=item B<--finddev>

Find a backup device and report it's device special file.

=item B<--getinfo>

Get and report info about the backups on a backup device.

=item B<--showkey>

Output the encryption key.

Modifers: B<--cryptkey=s>.

=item B<--validate-cryptkey>

Verify that the encryption key will actually decrypt the backup files.

Modifers: B<--cryptkey=s>.

=item B<--mount>

Mount a backup device.

=item B<--unmount|--umount>

Unmount a backup device.

Modifers: B<--verbose>.

=item B<--report-configfile>

Parse the config file, and report it's contents.

=item B<--report-is-backup-enabled>

Report whether the backup script is installed and enabled.

=item B<--checkfile args [args ...]>

Verify the files listed as command arguments.

=item B<--rti>

Modifier: specify that the system is a RTI system.

=item B<--daisy>

Modifier: specify that the system is a Daisy system.

=item B<--email=s>

Modifier: specifies a list of email addresses.

=item B<--printer=s>

Modifier: specifies a list of printer names.

=item B<--rootdir=s>

Modifier: specifies the destination directory for restore;
used as the B<-C=dir> option for the tar(1) command.

=item B<--configfile=s>

Modifier: specifies the path to the config file.

=item B<--logfile=s>

Modifier: specifies the path to the logfile.

=item B<--restore-exclude=s>

Modifier: specifiesy a list of files to exclude from a restore.

=item B<--device=s>

Modifier: specifies the path to the device special file for the backup device.

=item B<--device-vendor=s>

Modifier: specifies the vendor name of the backup device.

=item B<--device-model=s>

Modifier: specifies the model name of the backup device.

=item B<--usb-device>

Modifier: use a disk plugged into the USB bus which has been
formatted with B<--format> as the backup device.

=item B<--compress>

Modifier: compress the files when writing to the backup device.

=item B<--decompress>

Modifier: decompress the files when reading from the backup device.

=item B<--keep-old-files>

Modifer: don't overwrite files when doing a restore.

=item B<--upgrade>

Modifier: perform extra operations when doing a restore.

=item B<--dry-run>

Modifer: report what an operation would do but don't actually do it.

=item B<--verbose>

Modifier: report extra information.

=item B<--[no]autocheckmedia>

Modifier: don't check media on errors during a backup.

=item B<--[no]harden-linux>

Modifier: don't run the harden_linux.pl script.



=back


=head1 DESCRIPTION

This I<rtibackup.pl> script is used to backup and restore data
for a Teleflora RTI or Daisy Point of Sale system.
It is essentially an elaborate front end to the tar(1) command which
does the real work of reading and writing the data files.
Due to the complexity of the requirements, there are many options and
many ways that the script can be used.


=head2 Command Line Options

The B<--install> command line option performs all the steps
necessary to install the "rtibackup.pl" script onto the system.
First, the script is copied to the OSTools bin directory,
and it's file owner, group, and perms are set.
Then, a symlink is made from the POS bin directory pointing to the script
in the OSTools bin directory.
Next, the cron job file is installed.
If any old style cron job files exist, they are removed.
The new cron job file named "nightly-backup" is generated and
copied into directory "/etc/cron.d".
However, if there is an existing cron job file in "/etc/cron.d", then
the cron job file is copied to the OSTools config directory instead.

The B<--restore=s> command line option restores file from a backup.
The options B<--restore-exclude=s>,  B<--cryptkey=s>, B<--force>, and
B<--rootdir=s> may be used with B<--restore>.

The B<--harden-linux|--noharden-linux> command line option provides
a way to specify whether or not the "harden_linux.pl" script
should be run by the "rtibackup.pl" script.
The default behavior for "rtibackup.pl" is to run "harden_linux.pl"
after performing any of the following restore types:
"all", "rticonfigs", "daisy", "daisyconfigs", "osconfigs" and "netconfigs".
The "harden" script will only be run once after all restores are finished.
To prevent harden_linux.pl from running, specify the following option:
"--noharden-linux".

=head2 Definition of Installed and Enabled

The B<--report-is-backup-enabled> runs through an algorithm to determine
if the backup script is installed and enabled.
The definition of "installed and enabled" is:

=over 4

=item 1.

the C<rtibackup.pl> script exists in OSTools bin directory.

=item 2.

a symlink for the C<rtibackup.pl> script exists in the
RTI or Daisy bin directory which points to the actual script
in the OSTools bin directory.

=item 3.

the mount point exists.

=item 4.

the cron job file exists and the line which executes
C<rtibackup.pl> is not commented out.

=back

=head2 Daisy Logevents

When run on a Daisy system and the B<--backup> command line option is specified,
the C<rtibackup.pl> script is coded to
send a Daisy "logevent" indicating either success or failure of
the backup.
If the backup was successful, only a Daisy "logevent" is sent
to the Daisy system, with a message stating that the backup succeeded and
includes the Linux device name.
If the backup failed, a Daisy "action" is sent
to the Daisy system, with a message stating that the backup failed,
includes the Linux device name, and
provides advice on how to address the issue.
Also, a Daisy "logevent" is sent
to the Daisy system, with a message stating that the backup failed and
includes the Linux device name.


=head2 Sending Email

The C<rtibackup.pl> script can be configured to send email depending
on one of several conditions.  First, described below is
when an email message is sent, and second, how an email message is sent.

=over 4

=item Backup device not found

If there are email recipients specified on the command line or
in the config file, and a backup device is not found, an error
message will be sent to each of the recipients.

=item Verify Status

If there are email recipients specified on the command line or
in the config file, and the C<--verify> command line option is
specified along with the C<--backup> command line option, then
a status message will be sent to each of the recipients.
Note that the default cron job installed by the script specifies
both C<--backup> and C<--verify> on the command line invoking
C<rtibackup.pl> so the default case is that an email message
will be sent after the backups are completed each night.

=item Checkmedia Results

If there are email recipients specified on the command line or
in the config file, and the C<--checkmedia> command line option is
specified and the C<--backup> command line option is NOT specified, then
a message containing the results of the checkmedia will be sent to each of the recipients.

=back

Given that one or more email recipients are specified, and
one of the conditions upon which the script will attempt to
send an email message occurs, then the message can be sent
one of the following 3 methods.

=over 4

=item Sendmail

If the C<email_server> config file statement is specified with
a value of C<sendmail>, then any email messages sent by the script
will directly invoke the C</usr/lib/sendmail -oi -t> program with a
from address of C<rtibackup.pl@HOSTNAME.teleflora.com> where
HOSTNAME will be substituted with the hostname of the system.

=item SMTP Server

If the C<email_server> config file statement is specified with
a value of the FQDN of an SMTP server, and the C<email_user> and
C<email_password> config file statements have valid credentials
for the specified SMTP server, 
then any email messages sent by the script will
use the Perl module C<Net::SMTP> with a from address of
C<backups@HOSTNAME> where
HOSTNAME will be substituted with the hostname of the system.

=item MUTT

If the C<email_server> config file statement is NOT specified
in the config file, the message will be sent via the C<mutt>
command with a from address of C<tfsupport@HOSTNAME> where,
HOSTNAME will be substituted with the hostname of the system.

=back


=head1 EXAMPLES

During a backup of types "all" or "osconfigs", a backup of the
complete F</etc> sub-tree is written to the backup device.
It is sometimes useful to reference or restore one file from
this copy of F</etc>.
When retrieving a file from the backup of F</etc>,
it's generally a good idea a temporary directory to hold
the extracted files.
Thus, the I<rtibackup.pl> script is directed to write the file
to the temporary directory via the use of the I<--rootdir> command line option.
The command line to restore a single file from the backup of F</etc>,
for example F</etc/sysconfig/tfremote>, enter the following command:

 sudo rtibackup.pl --rootdir=/tmp --restore /etc/sysconfig/tfremote 

There are several issues to take note of:
first, if the I<rtibackup.pl> script is not in your C<$PATH>, then
you will have to specify the whole path to the script;
second, it takes longer to restore from F</etc> than other
restore types since the script looks in every backup set
on the backup device and does not stop when the file is found -
even after finding the file, it continues on through all the
remaining backup types.
The restored file will be found in F</tmp/etc/sysconfig/tfremote>.
The file can be referenced at that path and copied into it's
actual spot in the F</etc> sub-tree as desired.


=head1 FILES

=over 4

=item B</usr2/bbx/bin> and B</d/daisy/bin>

The path to the bin directory for RTI and Daisy systems respectively.

=item B</usr2/ostools/bin> and B</d/ostools/bin>

The path to the OSTools bin directory for RTI and Daisy systems respectively.

=item B</usr2/ostools/config> and B</d/ostools/config>

The path to the OSTools config directory for RTI and Daisy system respectively.

=item B</etc/cron.d/nightly-backup>

The path to the cron job file.

=item B</mnt/backups>

Mount point for backup device.

=item B</etc/redhat-release>

Contents determines OS type, and is used for validating crypt key.

=item B</sys/block/{sda,sdb,sdc,sde,sdd}/device/vendor>

This file contains the vendor string for the block device, ie disk,
that has special device file "/dev/sda", or "/dev/sdb", etc.

=item B</sys/block/{sda,sdb,sdc,sde,sdd}/device/model>

This file contains the model string for the block device, ie disk,
that has special device file "/dev/sda", or "/dev/sdb", etc.

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status 0 ($EXIT_OK)

Successful completion.

=item Exit status 1 ($EXIT_COMMAND_LINE)

In general, there was an issue with the syntax of the command line.

=item Exit status 2 ($EXIT_PLATFORM)

Unknown operating system.

=item Exit status 3 ($EXIT_ROOTDIR)

The directory specified for B<--rootdir> does not exist.

=item Exit status 4 ($EXIT_TOOLSDIR)

The OSTools directory does not exist.

=item Exit status 5 ($EXIT_BACKUP_DEVICE_NOT_FOUND)

A backup device of any kind was not found.

=item Exit status 6 ($EXIT_USB_DEVICE_NOT_FOUND)

The B<--usb-device> option was specified but a USB backup device
was not found.

=item Exit status 7 ($EXIT_BACKUP_TYPE)

The backup type specified with B<--backup> is not supported.

=item Exit status 10 ($EXIT_LIST)

The backup type specified with B<--list> was not recognized.

=item Exit status 11 ($EXIT_DEVICE_VERIFY)

The specified backup device is either not a block device or
is not an image file of minimum size.

=item Exit status 12 ($EXIT_USB_DEVICE_UNSUPPORTED)

USB devices other than WD Passports are not supported on RHEL4.

=item Exit status 13 ($EXIT_MOUNT_POINT)

The default mount point for the backup device did not exist and
one could not be made.

=item Exit status 14 ($EXIT_IS_BACKUP_ENABLED)

It could not be determined if the C<rtibackup.pl> script was
enabled or not.

=item Exit status 23 ($EXIT_SAMBA_CONF)

An error occurred while modifying one of the Samba conf files.

=back


=head1 SEE ALSO

tar(1), openssl(1)


=cut
