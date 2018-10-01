#!/usr/bin/perl
#
# $Revision: 1.11 $
# Copyright 2016-2017 Teleflora
#
# dsycheck.pl
#
# Script to check the installation quality of a Daisy system.
#
# Daisy reports
# =============
# report Daisy version number
# report Teleflora shopcode
# report Daisy shop name
# report Daisy country
# report Daisy florist directory release date
# report TCC version number
# rerort credit card url
# report credit card start number
# report backup device type
# report which type of backup is installed and enabled
# report existence of encrypted backup of /d/daisy
# report existence of any credit card processing dirs
# report existence of global Daisy config file: "/etc/profile.d/daisy"
# report existence of Daisy shell within /etc/shells
# report existence of Daisy service cron job: "/etc/cron.d/daisy-service"
#
# System reports
# ==============
# report OS version string
# report OSTools version number
# report hostname
# report boot protocol
# report ip-addr
# report public ip-addr
# report gateway ip-addr
# report free disk space
# report fstab changes
# report existence of mount points
# report samba conf
# report samba password
# report default system locale
# report audit rules configured
# report if cloud backup is installed
# report if server backup is installed
# report number of virtual consoles allowed if RHEL6
# report exisence of appropriate virtual console files
# report perms of appropriate virtual console files
# report existence of user "tfsupport"
# report existence of user "daisy"
# report existence of Samba user "daisy"
# 


use strict;
use warnings;
use POSIX;
use Getopt::Long;
use English qw( -no_match_vars );
use Socket;
use Net::SMTP;
use File::Spec;
use File::Basename;
use File::Temp qw(tempfile);
use File::stat;
use Sys::Hostname;
use Fcntl qw(:flock SEEK_END);

use lib qw( /teleflora/ostools/modules /d/ostools/modules );
use OSTools::Platform;
use OSTools::Hardware;
use OSTools::AppEnv;
use OSTools::Filesys;


our $VERSION = 1.15;
my $CVS_REVISION = '$Revision: 1.11 $';
my $TIMESTAMP = POSIX::strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($0);


############################
###                      ###
###      DEFINITIONS     ###
###                      ###
############################

# exit status values
my $EXIT_OK = 0;
my $EXIT_COMMAND_LINE = 1;
my $EXIT_MUST_BE_ROOT = 2;
my $EXIT_LOGFILE_SETUP = 3;
my $EXIT_PLATFORM = 4;
my $EXIT_OSTOOLSDIR = 5;
my $EXIT_OS_VERSION = 9;
my $EXIT_DAISY_VERSION = 11;
my $EXIT_OSTOOLS_VERSION = 13;
my $EXIT_SHOPCODE = 14;
my $EXIT_COUNTRY_CODE = 15;
my $EXIT_FLORIST_DIRECTORY_VERSION = 16;
my $EXIT_TCC_VERSION = 17;
my $EXIT_CARD_URL = 18;
my $EXIT_SHOPNAME = 19;
my $EXIT_SAMBA_CONF = 20;
my $EXIT_SAMBA_PASSWORD = 21;
my $EXIT_CARD_START_NUMBER = 22;
my $EXIT_NEXT_TICKET_NUMBER = 23;
my $EXIT_LARGE_FILE = 24;
my $EXIT_HOSTNAME = 50;
my $EXIT_IPADDR = 51;
my $EXIT_GATEWAY_IPADDR = 52;
my $EXIT_DISK_FREE = 53;
my $EXIT_FSTAB_CHANGES = 54;
my $EXIT_ACCOUNT_INFO = 55;
my $EXIT_SYSTEM_LOCALE = 56;;

my $EMPTY_STR   = q{};
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
my @EMPTY_LIST  = ();
my $TRUE        = 1;
my $FALSE       = 0;


# Daisy locations
my $DAISY_TOPDIR                      = '/d';

my $DAISYDIR_NAME                     = 'daisy';
my $DAISY_LOGDIR_NAME                 = 'log';
my $DAISY_POS_BIN_NAME                = 'pos';
my $DAISY_SHOPCODE_FILE_NAME          = 'dovectrl.pos';
my $DAISY_CONTROL_FILE_NAME           = 'control.dsy';
my $DAISY_COUNTRY_CODE_FILE_NAME      = 'control.dsy';
my $DAISY_FLORIST_DIRECTORY_FILE_NAME = 'control.tel';
my $DAISY_CARD_URL_FILE_NAME          = 'crdinet.pos';
my $DAISY_POS_CONTROL_FILE_NAME       = 'posctrl.pos';
my $DAISY_TCC_BIN_DIR_NAME            = 'tcc';
my $DAISY_TCC_BIN_NAME                = 'tcc';
my $DAISY_RSYNC_BU_DIR_NAME           = 'tfrsync';

my $OSTOOLS_TOPDIR                    = $DAISY_TOPDIR;
my $OSTOOLS_DIR_NAME                  = 'ostools';
my $OSTOOLS_BINDIR_NAME               = 'bin';
my $OSTOOLS_CONFIGDIR_NAME            = 'config';

# default values
my $DEF_RSYNC_ACCOUNT_NAME            = 'tfrsync';
my $DEF_TFSUPPORT_ACCOUNT_NAME        = 'tfsupport';
my $DEF_CLOUD_BACKUP_CRON_JOB_NAME    = 'tfrsync-cloud';
my $DEF_SERVER_BACKUP_CRON_JOB_NAME   = 'tfrsync-server';
my $DEF_DAISY_USER_NAME               = 'daisy';
my $DEF_DAISY_GROUP_NAME              = 'daisy';
my $DEF_DAISY_ADMIN_GROUP_NAME        = 'dsyadmins';

my $DEF_LOGFILE_DIR                   = dc_pathto_daisy_logfile_dir();
my $DEF_ALT_LOGFILE_DIR               = '/tmp';
my $DEF_LOGFILE_NAME                  = 'dsycheck.log';

my $DEF_MAX_TICKET_NUMBER             = 999999;

my $DEF_LARGE_FILE                    = 10000000;

# network device
my $DEF_NETWORK_DEVICE         = 'eth0';


############################
###                      ###
###   GLOBAL VARIABLES   ###
###                      ###
############################

my @ARGV_ORIG = @ARGV;

my $DAISY = 1;

# logfile vars
my $LOGFILE        = $EMPTY_STR;
my $DebugLogfile   = $EMPTY_STR;

# path to the existing ostools directory
my $ToolsDir = $EMPTY_STR;

my $ExitStatus = $EXIT_OK;

my $OS = $EMPTY_STR;

my $ALL_OPTIONS = 1;

#
# The command line must be recorded before the GetOptions modules
# is called or any options will be removed.
#
my $COMMAND_LINE = get_command_line();

# command line options
my $HELP = 0;
my $CVS_VERSION = 0;
my $VERBOSE = 0;
my $DEBUGMODE = 0;
my $LOGFILE_DIR = $DEF_LOGFILE_DIR;
my $NETWORK_DEV_NAME = $DEF_NETWORK_DEVICE;
my $REPORT_OS_VERSION = 0;
my $REPORT_OSTOOLS_VERSION = 0;
my $REPORT_HOSTNAME = 0;
my $REPORT_BOOT_PROTOCOL = 0;
my $REPORT_IP_ADDR = 0;
my $REPORT_PUBLIC_IP_ADDR = 0;
my $REPORT_GATEWAY_IP_ADDR = 0;
my $REPORT_DISK_FREE = 0;
my $REPORT_FSTAB_CHANGES = 0;
my $REPORT_MOUNT_POINTS = 0;
my $REPORT_SAMBA_CONF = 0;
my $REPORT_SAMBA_PASSWORD = 0;
my $REPORT_SYSTEM_LOCALE = 0;
my $REPORT_SYSTEM_AUDIT_RULES = 0;
my $REPORT_CLOUD_BACKUP = 0;
my $REPORT_SERVER_BACKUP = 0;
my $REPORT_VIRT_CON_COUNT = 0;
my $REPORT_VIRT_CON_FILES = 0;
my $REPORT_VIRT_CON_PERMS = 0;
my $REPORT_TFSUPPORT_USER = 0;
my $REPORT_DAISY_USER = 0;
my $REPORT_DAISY_VERSION = 0;
my $REPORT_SHOPCODE = 0;
my $REPORT_SHOPNAME = 0;
my $REPORT_COUNTRY_CODE = 0;
my $REPORT_FLORIST_DIRECTORY_VERSION = 0;
my $REPORT_TCC_VERSION = 0;
my $REPORT_CARD_URL = 0;
my $REPORT_CARD_START_NUMBER = 0;
my $REPORT_NEXT_TICKET_NUMBER = 0;
my $REPORT_LARGE_FILE = 0;
my $REPORT_ENCRYPTED_DAISYDIR = 0;
my $REPORT_PACKAGE_VERSIONS = 0;

GetOptions(
	"help" => \$HELP,
	"version" => \$CVS_VERSION,
	"verbose" => \$VERBOSE,
	"debugmode" => \$DEBUGMODE,
	"logfile-dir=s" => \$LOGFILE_DIR,
	"network-device-name=s" => \$NETWORK_DEV_NAME,
	"report-os-version" => \$REPORT_OS_VERSION,
	"report-ostools-version" => \$REPORT_OSTOOLS_VERSION,
	"report-hostname" => \$REPORT_HOSTNAME,
	"report-ip-addr" => \$REPORT_IP_ADDR,
	"report-public-ip-addr" => \$REPORT_PUBLIC_IP_ADDR,
	"report-gateway-ip-addr" => \$REPORT_GATEWAY_IP_ADDR,
	"report-boot-protocol" => \$REPORT_BOOT_PROTOCOL,
	"report-disk-free" => \$REPORT_DISK_FREE,
	"report-fstab-changes" => \$REPORT_FSTAB_CHANGES,
	"report-mount-points" => \$REPORT_MOUNT_POINTS,
	"report-samba-conf" => \$REPORT_SAMBA_CONF,
	"report-samba-password" => \$REPORT_SAMBA_PASSWORD,
	"report-system-locale" => \$REPORT_SYSTEM_LOCALE,
	"report-system-audit-rules" => \$REPORT_SYSTEM_AUDIT_RULES,
	"report-cloud-backup" => \$REPORT_CLOUD_BACKUP,
	"report-server-backup" => \$REPORT_SERVER_BACKUP,
	"report-virtual-console-count" => \$REPORT_VIRT_CON_COUNT,
	"report-virtual-console-files" => \$REPORT_VIRT_CON_FILES,
	"report-virtual-console-perms" => \$REPORT_VIRT_CON_PERMS,
	"report-tfsupport-user" => \$REPORT_TFSUPPORT_USER,
	"report-daisy-user" => \$REPORT_DAISY_USER,
	"report-daisy-version" => \$REPORT_DAISY_VERSION,
	"report-shopcode" => \$REPORT_SHOPCODE,
	"report-shopname" => \$REPORT_SHOPNAME,
	"report-country-code" => \$REPORT_COUNTRY_CODE,
	"report-florist-directory-version" => \$REPORT_FLORIST_DIRECTORY_VERSION,
	"report-tcc-version" => \$REPORT_TCC_VERSION,
	"report-card-url" => \$REPORT_CARD_URL,
	"report-card-start-number" => \$REPORT_CARD_START_NUMBER,
	"report-next-ticket-number" => \$REPORT_NEXT_TICKET_NUMBER,
	"report-large-file" => \$REPORT_LARGE_FILE,
	"report-encrypted-daisydir" => \$REPORT_ENCRYPTED_DAISYDIR,
	"report-package-versions" => \$REPORT_PACKAGE_VERSIONS,
) || die "Error: invalid command line option, exiting...\n";

my @AllOptions = (
    $REPORT_OS_VERSION, $REPORT_OSTOOLS_VERSION, $REPORT_HOSTNAME,
    $REPORT_BOOT_PROTOCOL, $REPORT_IP_ADDR, $REPORT_PUBLIC_IP_ADDR,
    $REPORT_GATEWAY_IP_ADDR, $REPORT_DISK_FREE, $REPORT_FSTAB_CHANGES,
    $REPORT_MOUNT_POINTS, $REPORT_SAMBA_CONF, $REPORT_SAMBA_PASSWORD,
    $REPORT_SYSTEM_LOCALE, $REPORT_SYSTEM_AUDIT_RULES, $REPORT_CLOUD_BACKUP,
    $REPORT_SERVER_BACKUP, $REPORT_VIRT_CON_COUNT, $REPORT_VIRT_CON_FILES,
    $REPORT_VIRT_CON_PERMS, $REPORT_TFSUPPORT_USER, $REPORT_DAISY_USER,
    $REPORT_DAISY_VERSION, $REPORT_SHOPCODE, $REPORT_SHOPNAME,
    $REPORT_COUNTRY_CODE, $REPORT_FLORIST_DIRECTORY_VERSION, $REPORT_TCC_VERSION,
    $REPORT_CARD_URL, $REPORT_CARD_START_NUMBER, $REPORT_NEXT_TICKET_NUMBER,
    $REPORT_LARGE_FILE, $REPORT_ENCRYPTED_DAISYDIR, $REPORT_PACKAGE_VERSIONS,
);


#
# figure out what options were specified.
#
# if any particular option was specified, disable all options
foreach my $option (@AllOptions) {
    my $count = 0;
    if ($option) {
	$count++
    }
    if ($count) {
	$ALL_OPTIONS = 0;
    }
}

# --version
if ($CVS_VERSION) {
    print "OSTools Version: 1.15.0\n";
    print "$CVS_REVISION\n";
    exit($EXIT_OK);
}

# --help
if ($HELP != 0) {
    dca_usage();
    exit($EXIT_OK);
}

# check command line for obviously inconsistent command line options
# and rule them out now
if (dc_is_cmd_line_consistent() == $FALSE) {
    exit($EXIT_COMMAND_LINE);
}

if ($EUID != 0) {
    print {*STDERR} "[mainline] $0 must be run as root or with sudo\n";
    exit($EXIT_MUST_BE_ROOT);
}

#
# initialize log file configuration
#
if (dc_log_setup($LOGFILE_DIR, $DEF_LOGFILE_NAME) == $FALSE) {
    print {*STDERR} "[mainline] could not initialize log file: $DEF_LOGFILE_NAME\n";
    exit($EXIT_LOGFILE_SETUP);
}


# --debug
# output extra messages if debug requested
if ($DEBUGMODE) {
    loginfo("[mainline] debug mode enabled");
}


# verify network interface is valid
if (dc_verify_network_dev_name($NETWORK_DEV_NAME)) {
    loginfo("[mainline] network interface device name verified: $NETWORK_DEV_NAME");
}
else {
    showerror("[mainline] can not verify network interface device name: $NETWORK_DEV_NAME");
    exit($EXIT_COMMAND_LINE);
}


$OS = OSTools::Platform::plat_os_version();
if ($OS) {
    if ($OS eq 'RHEL6' || $OS eq 'RHEL7') {
    loginfo("[mainline] supported platform: $OS");
    }
    else {
	showerror("[mainline] supported operating systems: RHEL6 and RHEL7");
	exit($EXIT_PLATFORM);
    }
}
else {
    showerror("[mainline] unknown operating system");
    exit($EXIT_PLATFORM);
}


my $OSTOOLS_DIR = dc_pathto_ostools_dir();
if (-d $OSTOOLS_DIR) {
    loginfo("[mainline] using OSTools installed at: $OSTOOLS_DIR");
}
else {
    logerror("[mainline] OSTools directory does not exist: $OSTOOLS_DIR");
    exit($EXIT_OSTOOLSDIR);
}


my $exit_status = main();

exit($exit_status);


############################
###                      ###
###        MAIN          ###
###                      ###
############################

sub main
{
    my $begin_separator = $EQUALS x 40;
    loginfo("| $begin_separator");
    loginfo("| BEGIN Script $PROGNAME");
    loginfo("| CVS Revision: $CVS_REVISION");
    loginfo("| Command Line: $COMMAND_LINE");
    loginfo("| $begin_separator");

    my $rc = $EXIT_OK;

    if ($ALL_OPTIONS == $TRUE) {
	showinfo("===========================");
	showinfo("reporting system attributes");
	showinfo("===========================");
    }

    # --report-package-versions
#    if ($ALL_OPTIONS || $REPORT_PACKAGE_VERSIONS) {
#	$rc = dca_report_package_versions();
#	if ($rc != $EXIT_OK) {
#	    return($rc);
#	}
#    }

    # --report-os-version
    if ($ALL_OPTIONS || $REPORT_OS_VERSION) {
	$rc = dca_report_os_version();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-ostools-version
    if ($ALL_OPTIONS || $REPORT_OSTOOLS_VERSION) {
	$rc = dca_report_ostools_version();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-hostname
    if ($ALL_OPTIONS || $REPORT_HOSTNAME) {
	$rc = dca_report_hostname();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-ip-addr
    if ($ALL_OPTIONS || $REPORT_IP_ADDR) {
	$rc = dca_report_ipaddr();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-public-ip-addr
    if ($ALL_OPTIONS || $REPORT_PUBLIC_IP_ADDR) {
	$rc = dca_report_public_ipaddr();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-gateway-ip-addr
    if ($ALL_OPTIONS || $REPORT_GATEWAY_IP_ADDR) {
	$rc = dca_report_gateway_ipaddr();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-boot-protocol
    if ($ALL_OPTIONS || $REPORT_BOOT_PROTOCOL) {
	$rc = dca_report_boot_protocol();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-disk-free
    if ($ALL_OPTIONS || $REPORT_DISK_FREE) {
	$rc = dca_report_disk_free();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-fstab-changes
    if ($ALL_OPTIONS || $REPORT_FSTAB_CHANGES) {
	$rc = dca_report_fstab_changes();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-mount-points
    if ($ALL_OPTIONS || $REPORT_MOUNT_POINTS) {
	$rc = dca_report_mount_points();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-samba-conf
    if ($ALL_OPTIONS || $REPORT_SAMBA_CONF) {
	$rc = dca_report_samba_conf();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-samba-password
    if ($ALL_OPTIONS || $REPORT_SAMBA_PASSWORD) {
	$rc = dca_report_samba_password();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-system-locale
    if ($ALL_OPTIONS || $REPORT_SYSTEM_LOCALE) {
	$rc = dca_report_system_locale();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-system-audit-rules
    if ($ALL_OPTIONS || $REPORT_SYSTEM_AUDIT_RULES) {
	$rc = dca_report_system_audit_rules();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-cloud-backup
    if ($ALL_OPTIONS || $REPORT_CLOUD_BACKUP) {
	$rc = dca_report_cloud_backup();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-server-backup
    if ($ALL_OPTIONS || $REPORT_SERVER_BACKUP) {
	$rc = dca_report_server_backup();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-virtual-console-count
    if ($ALL_OPTIONS || $REPORT_VIRT_CON_COUNT) {
	$rc = dca_report_virtual_console_count();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-virtual-console-files
    if ($ALL_OPTIONS || $REPORT_VIRT_CON_FILES) {
	$rc = dca_report_virtual_console_files();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-virtual-console-perms
    if ($ALL_OPTIONS || $REPORT_VIRT_CON_PERMS) {
	$rc = dca_report_virtual_console_perms();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-tfsupport-user-info
    if ($ALL_OPTIONS || $REPORT_TFSUPPORT_USER) {
	$rc = dca_report_tfsupport_user();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }

    # --report-daisy-user-info
    if ($ALL_OPTIONS || $REPORT_DAISY_USER) {
	$rc = dca_report_daisy_user();
	if ($rc != $EXIT_OK) {
	    return($rc);
	}
    }


    my @daisy_dirs = dc_get_daisy_dirs();

    foreach my $daisy_dir (@daisy_dirs) {

	if ($ALL_OPTIONS == $TRUE) {
	    showinfo("====================================");
	    showinfo("reporting attributes from: $daisy_dir");
	    showinfo("====================================");
	}

	# --report-daisy-version
	if ($ALL_OPTIONS || $REPORT_DAISY_VERSION) {
	    $rc = dca_report_daisy_version($daisy_dir);
	    if ($rc != $EXIT_OK) {
		return($rc);
	    }
	}

	# --report-shopcode
	if ($ALL_OPTIONS || $REPORT_SHOPCODE) {
	    $rc = dca_report_shopcode($daisy_dir);
	    if ($rc != $EXIT_OK) {
		return($rc);
	    }
	}

	# --report-shopname
	if ($ALL_OPTIONS || $REPORT_SHOPNAME) {
	    $rc = dca_report_shopname($daisy_dir);
	    if ($rc != $EXIT_OK) {
		return($rc);
	    }
	}

	# --report-country-code
	if ($ALL_OPTIONS || $REPORT_COUNTRY_CODE) {
	    $rc = dca_report_country_code($daisy_dir);
	    if ($rc != $EXIT_OK) {
		return($rc);
	    }
	}

	# --report-florist-directory-version
	if ($ALL_OPTIONS || $REPORT_FLORIST_DIRECTORY_VERSION) {
	    $rc = dca_report_florist_directory_version($daisy_dir);
	    if ($rc != $EXIT_OK) {
		return($rc);
	    }
	}

	# --report-tcc-version
	if ($ALL_OPTIONS || $REPORT_TCC_VERSION) {
	    $rc = dca_report_tcc_version($daisy_dir);
	    if ($rc != $EXIT_OK) {
		return($rc);
	    }
	}

	# --report-card-url
	if ($ALL_OPTIONS || $REPORT_CARD_URL) {
	    $rc = dca_report_card_url($daisy_dir);
	    if ($rc != $EXIT_OK) {
		return($rc);
	    }
	}

	# --report-card-start-number
	if ($ALL_OPTIONS || $REPORT_CARD_START_NUMBER) {
	    $rc = dca_report_card_start_number($daisy_dir);
	    if ($rc != $EXIT_OK) {
		return($rc);
	    }
	}

	# --report-next-ticket-number
	if ($ALL_OPTIONS || $REPORT_NEXT_TICKET_NUMBER) {
	    $rc = dca_report_next_ticket_number($daisy_dir);
	    if ($rc != $EXIT_OK) {
		return($rc);
	    }
	}

	# --report-large-file
	if ($ALL_OPTIONS || $REPORT_LARGE_FILE) {
	    $rc = dca_report_large_file();
	    if ($rc != $EXIT_OK) {
		return($rc);
	    }
	}

	# --report-encrypted-daisydir
	if ($ALL_OPTIONS || $REPORT_ENCRYPTED_DAISYDIR) {
	    $rc = dca_report_encrypted_daisy_dir();
	    if ($rc != $EXIT_OK) {
		return($rc);
	    }
	}
    }

    return($EXIT_OK);
}


############################
###                      ###
###      APPLICATION     ###
###                      ###
############################

sub dca_usage
{
    print "$PROGNAME $CVS_REVISION\n";
    print "\n";
    print "For full documenation, enter the command:  perldoc $0\n";
    print "\n";

    print "SYNOPSIS\n";
    print "$PROGNAME --help\n";
    print "$PROGNAME --version\n";
    print "$PROGNAME --verbose\n";
    print "$PROGNAME --debugmode\n";
    print "$PROGNAME --logfile-dir=s            # default value = $DEF_LOGFILE_DIR\n";
    print "$PROGNAME --network-device-name=s    # default value = $DEF_NETWORK_DEVICE\n";
    print "\n";
    print "System Wide Attributes\n";
    print "$PROGNAME --report-os-version\n";
    print "$PROGNAME --report-ostools-version\n";
    print "$PROGNAME --report-hostname\n";
    print "$PROGNAME --report-ip-addr\n";
    print "$PROGNAME --report-public-ip-addr\n";
    print "$PROGNAME --report-gateway-ip-addr\n";
    print "$PROGNAME --report-boot-protocol\n";
    print "$PROGNAME --report-disk-free\n";
    print "$PROGNAME --report-fstab-changes\n";
    print "$PROGNAME --report-mount-points\n";
    print "$PROGNAME --report-samba-conf\n";
    print "$PROGNAME --report-samba-password\n";
    print "$PROGNAME --report-system-locale\n";
    print "$PROGNAME --report-system-audit-rules\n";
    print "$PROGNAME --report-cloud-backup\n";
    print "$PROGNAME --report-server-backup\n";
    print "$PROGNAME --report-virtual-console-count\n";
    print "$PROGNAME --report-virtual-console-files\n";
    print "$PROGNAME --report-virtual-console-perms\n";
    print "$PROGNAME --report-tfsupport-user-info\n";
    print "$PROGNAME --report-daisy-user-info\n";
    print "\n";
    print "Per Daisy Directory Attributes\n";
    print "$PROGNAME --report-daisy-version\n";
    print "$PROGNAME --report-shopcode\n";
    print "$PROGNAME --report-shopname\n";
    print "$PROGNAME --report-country-code\n";
    print "$PROGNAME --report-florist-directory-version\n";
    print "$PROGNAME --report-tcc-version\n";
    print "$PROGNAME --report-card-url\n";
    print "$PROGNAME --report-card-start-number\n";
    print "$PROGNAME --report-next-ticket-number\n";
    print "$PROGNAME --report-large-file\n";
    print "$PROGNAME --report-encrypted-daisydir\n";

    return(1);
}


sub dca_report_package_versions
{
    my $rc = $EXIT_OK;

    my @pkg_table = (
	[ "OSTools::AppEnv",   \&OSTools::AppEnv::appenv_module_version ],
	[ "OSTools::FileSys",  \&OSTools::Filesys::filesys_module_version ],
	[ "OSTools::Hardware", \&OSTools::Hardware::hw_module_version ],
	[ "OSTools::Platform", \&OSTools::Platform::plat_module_version ],
    );

    foreach my $pkg_table_entry (@pkg_table) {
	my ($pkg_name, $pkg_sub) = @{$pkg_table_entry};
	my $pkg_version = &{$pkg_sub};
	print "Package name and version: $pkg_name $pkg_version\n";
    }

    return($rc);
}


sub dca_fstab_changes_verify
{
    my $rc = $EMPTY_STR;
    my $ml = '[fstab_changes_verify]';

    my $fstab = '/etc/fstab';

    if (open(my $fh, '<', $fstab)) {
	while (my $line = <$fh>) {
	    my ($fs_spec, $fs_file, $fs_vfstype, $fs_mntops, $fs_freq, $fs_passno) = split(/\s+/, $line);
	    if ($OS eq 'RHEL7') {
		if ($fs_file eq '/d') {
		    if ($fs_mntops =~ m/,nofail$/) {
			$rc = 'fstab changes (RHEL7): OK';
		    }
		}
	    }
	    elsif ($OS eq 'RHEL6') {
		if ($fs_file eq '/mnt/cdrom') {
		    $rc = 'fstab changes (RHEL6): OK';
		}
	    }
	    else {
		my $platform = ($OS eq $EMPTY_STR) ? "OS unknown" : $OS;
		$rc = "fstab changes ($platform): none";
	    }
	}
	close($fh) or warn "$ml could not close file $fstab: $OS_ERROR\n";
    }
    else {
	$rc = "fstab changes: could not open file ($fstab)";
	logerror("$ml could not open file: $fstab");
    }

    return($rc);
}


##
## System Reporters
##

sub dca_report_os_version
{
    my $rc = $EXIT_OK;

    my $os_version = OSTools::Platform::plat_os_version();
    if ($os_version) {
	showinfo("OS version: $os_version");
    }
    else {
	showerror("[report_platform] unknown operating system");
	$rc = $EXIT_OS_VERSION;
    }

    return($rc);
}

sub dca_report_ostools_version
{
    my $rc = $EXIT_OK;

    my $ostools_dir = dc_pathto_ostools_dir();
    if (! -d $ostools_dir) {
	showerror("[report_ostools_version] OSTools directory does not exist");
	$rc = $EXIT_OSTOOLSDIR;
    }

    my $ostools_version = dca_get_ostools_version();
    if ($ostools_version) {
	showinfo("OSTools version: $ostools_version");
    }
    else {
	showerror("[report_ostools_version] could not get OSTools version");
	$rc = $EXIT_OSTOOLS_VERSION;
    }

    return($rc);
}

sub dca_report_hostname
{
    my $rc = $EXIT_OK;

    my $hostname = hostname();
    if ($hostname) {
	showinfo("hostname: $hostname");
    }
    else {
	logerror("[report_hostname] could not get hostname");
	$rc = $EXIT_HOSTNAME;
    }

    return($rc);
}

sub dca_report_boot_protocol
{
    my $rc = $EXIT_OK;

    my $protocol = get_boot_protocol();
    if ($protocol) {
	my $result = ($protocol eq 'static') ? 'OK' : 'abnormal';
	showinfo("boot protocol ($protocol): $result");
    }
    else {
	showerror("[report_boot_protocol] could not get boot protocol");
	$rc = $EXIT_HOSTNAME;
    }


    return($rc);
}

sub dca_report_ipaddr
{
    my $rc = $EXIT_OK;

    my $ipaddr = get_ipaddr($NETWORK_DEV_NAME);
    if ($ipaddr) {
	showinfo("$NETWORK_DEV_NAME IP address: $ipaddr");
    }
    else {
	showerror("[report_ipaddr] could not get IP address");
	$rc = $EXIT_IPADDR;
    }

    return($rc);
}

sub dca_report_public_ipaddr
{
    my $rc = $EXIT_OK;

    my $ipaddr = get_public_ipaddr();
    if ($ipaddr) {
	showinfo("Public IP address: $ipaddr");
    }
    else {
	showerror("[report_public_ipaddr] could not get public IP address");
	$rc = $EXIT_IPADDR;
    }

    return($rc);
}

sub dca_report_gateway_ipaddr()
{
    my $rc = $EXIT_OK;

    my $gateway_ipaddr = get_gateway_ipaddr($NETWORK_DEV_NAME);
    if ($gateway_ipaddr) {
	showinfo("Gateway IP address: $gateway_ipaddr");
    }
    else {
	showerror("[report_gateway_ipaddr] could not get Gateway IP address");
	$rc = $EXIT_GATEWAY_IPADDR;
    }

    return($rc);
}

sub dca_report_disk_free
{
    my $rc = $EXIT_OK;

    my $available = get_free_space('/d'); # number of 1k blocks
    if ($available) {
	my $status = 'OK';
	if ($available < (1024 * 1024 * 10)) {
	    $status = 'LOW';
	}
	my $formatted_size = dc_util_convert_bytes($available);
	showinfo("disk space free ($formatted_size): $status");
    }
    else {
	showerror("[report_disk_free] could not get disk space available");
	$rc = $EXIT_DISK_FREE;
    }

    return($rc);
}

sub dca_report_fstab_changes
{
    my $rc = $EXIT_OK;

    my $status = dca_fstab_changes_verify();
    showinfo("$status");

    return($rc);
}

sub dca_report_mount_points
{
    my $rc = $EXIT_OK;

    my @mount_points = qw{
	/mnt/usb
	/mnt/cdrom
    };

    foreach (@mount_points) {
	my $status = (-d $_) ? 'OK' : 'directory does not exist';
	showinfo("mount point ($_): $status");
    }

    return($rc);
}

sub dca_report_samba_conf
{
    my $rc = $EXIT_OK;
    my $ml = '[report_samba_conf]';

    my $pattern = '/d/daisy/export';
    my $conf = '/etc/samba/smb.conf';
    my $status = 'unconfigured';

    if (open(my $fh, '<', $conf)) {
	while (my $line = <$fh>) {
	    if ($line =~ m/$pattern/) {
		$status = 'OK';
		last;
	    }
	}
	close($fh) or warn "$ml could not close file: $conf $OS_ERROR\n";
    }
    else {
	logerror("$ml could not open file: $conf");
	$rc = $EXIT_SAMBA_CONF;
    }

    showinfo("Samba config file ($conf): $status");

    return($rc);
}

sub dca_report_samba_password
{
    my $rc = $EXIT_OK;
    my $ml = '[report_samba_paasword]';

    my $pattern = 'daisy';
    my $conf = '/etc/samba/smbpasswd';
    my $status = 'unconfigured';

    if (open(my $fh, '<', $conf)) {
	while (my $line = <$fh>) {
	    if ($line =~ m/$pattern/) {
		$status = 'OK';
		last;
	    }
	}
	close($fh) or warn "$ml could not close file: $conf $OS_ERROR\n";
    }
    else {
	logerror("$ml could not open file: $conf");
	$rc = $EXIT_SAMBA_PASSWORD;
    }

    showinfo("Samba password file ($conf): $status");

    return($rc);
}

sub get_rhel6_system_locale
{
    my $rc = 1;
    my $ml = '[get_rhel6_system_locale]';

    my $conf = '/etc/sysconfig/i18n';

    # looking for lines like:
    #     LANG=\"en_US\"
    #     SYSFONT=\"latarcyrheb-sun16\"
    #     SUPPORTED=\"en_US.UTF-8:en_US:en\"

    if (open(my $fh, '<', $conf)) {
	while (my $line = <$fh>) {
	    if ($line =~ m/^LANG="([a-zA-Z_]+)"/) {
		if ($1 ne 'en_US') {
		    $rc = 0;
		    last;
		}
	    }
	    if ($line =~ m/^SYSFONT=="([a-zA-Z0-9\-]+)"/) {
		if ($1 ne 'latarcyrheb-sun16') {
		    $rc = 0;
		    last;
		}
	    }
	    if ($line =~ m/^SUPPORTED="([a-zA-Z0-9\-\.\:]+)"/) {
		if ($1 ne 'en_US.UTF-8:en_US:en') {
		    $rc = 0;
		    last;
		}
	    }
	}
	close($fh) or warn "$ml could not close file $conf: $OS_ERROR\n";
    }
    else {
	$rc = 0;
	showerror("$ml could not open file: $conf");
    }

    return($rc);
}

sub get_rhel7_system_locale
{
    my $rc = 0;
    my $ml = '[get_rhel7_system_locale]';

    my $cmd = 'localectl status';
    if (open(my $pipe, '-|', $cmd)) {
	while (my $line = <$pipe>) {
	    if ($line =~ m/^\s*System Locale: ([a-zA-Z_=]+)/) {
		$rc = 1;
		last;
	    }
	}
	close($pipe) or warn "$ml could not close pipe $cmd: $OS_ERROR\n";
    }
    else {
	showerror("$ml could not open pipe $cmd");
    }

    return($rc);
}

sub get_system_locale
{
    my $rc = 1;

    if ($OS eq 'RHEL6') {
	$rc = get_rhel6_system_locale();
    }

    if ($OS eq 'RHEL7') {
	$rc = get_rhel7_system_locale();
    }

    return($rc);
}

sub dca_report_system_locale
{
    my $rc = $EXIT_OK;

    my $result = 'OK';

    if (!get_system_locale()) {
	$result = 'unknown';
	$rc = $EXIT_SYSTEM_LOCALE;
    }
    showinfo("system locale ($OS): $result");

    return($rc);
}

sub dca_report_system_audit_rules
{
    my $rc = $EXIT_OK;

    my $result = 'NO';
    if (-e '/etc/audit/rules.d/daisy.rules') {
	$result = 'YES';
    }
    showinfo("system audit rules configured: $result");

    return($rc);
}


sub dca_report_cloud_backup
{
    my $rc = $EXIT_OK;

    my $cloud_backup_installed = 'NO';
    if (is_cloud_backup_installed()) {
	$cloud_backup_installed = 'YES';
    }
    showinfo("cloud backup installed: $cloud_backup_installed");

    return($rc);
}


sub dca_report_server_backup
{
    my $rc = $EXIT_OK;

    my $server_backup_installed = 'NO';
    if (is_server_backup_installed()) {
	$server_backup_installed = 'YES';
    }
    showinfo("server backup installed: $server_backup_installed");

    return($rc);
}

sub dca_report_virtual_console_count
{
    my $rc = $EXIT_OK;

    my $virtual_console_count = get_virtual_console_count();
    my $comment = 'OK';
    if ($virtual_console_count != 12) {
	$comment = 'unexpected';
    }
    showinfo("virtual console count ($virtual_console_count): $comment");

    return($rc);
}

sub dca_report_virtual_console_files
{
    my $rc = $EXIT_OK;

    showinfo("virtual console files: unimplemented");

    return($rc);
}

sub dca_report_virtual_console_perms
{
    my $rc = $EXIT_OK;

    showinfo("virtual console perms: unimplemented");

    return($rc);
}

sub dca_report_tfsupport_user
{
    my $rc = $EXIT_OK;

    if (is_account_installed($DEF_TFSUPPORT_ACCOUNT_NAME)) {
	my $user = get_userinfo($DEF_TFSUPPORT_ACCOUNT_NAME);
	if (defined($user->{'username'})) {
	    showinfo("Admin account ($user->{'username'}) exists: OK");

	    my $shell_status = 'ERROR';
	    if ($user->{'shell'} =~ /\/bin\/bash/) {
		$shell_status = 'OK';
	    }
	    showinfo("Admin account shell ($user->{'shell'}): $shell_status");

	    my $group_status = 'ERROR';
	    my $groups = $user->{'groups'}; 
	    if ( ($groups =~ /daisy/) && ($groups =~ /dsyadmins/) ) {
		$group_status = 'OK';
	    }
	    showinfo("Admin account groups (daisy,dsyadmins): $group_status");

	}
	else {
	    showerror("[report_tfsupport_user] could not get info for account: $DEF_TFSUPPORT_ACCOUNT_NAME");
	    $rc = $EXIT_ACCOUNT_INFO;
	}
    }
    else {
	showerror("[report_tfsupport_user] required account not installed: $DEF_TFSUPPORT_ACCOUNT_NAME");
	$rc = $EXIT_ACCOUNT_INFO;
    }

    return($rc);
}

sub dca_report_daisy_user
{
    my $rc = $EXIT_OK;

    if (is_account_installed($DEF_DAISY_USER_NAME)) {
	my $user = get_userinfo($DEF_DAISY_USER_NAME);
	if (defined($user->{'username'})) {
	    showinfo("User account ($user->{'username'}) exists: OK");

	    my $shell_status = 'ERROR';
	    if ($user->{'shell'} =~ /\/d\/daisy\/bin\/dsyshell/) {
		$shell_status = 'OK';
	    }
	    showinfo("User account shell ($user->{'shell'}): $shell_status");

	    my $group_status = 'ERROR';
	    my $groups = $user->{'groups'}; 
	    if ( ($groups =~ /daisy/) && ($groups =~ /lp/) && ($groups =~ /lock/) ) {
		$group_status = 'OK';
	    }
	    showinfo("User account groups (daisy,lp,lock): $group_status");

	}
	else {
	    showerror("[report_daisy_user] could not get info for account: $DEF_DAISY_USER_NAME");
	    $rc = $EXIT_ACCOUNT_INFO;
	}
    }
    else {
	logerror("[report_tfsupport_user] required account not installed: $DEF_DAISY_USER_NAME");
	$rc = $EXIT_ACCOUNT_INFO;
    }

    return($rc);
}


##
## Daisy Reporters
##
#
sub dca_report_daisy_version
{
    my ($daisy_dir) = @_;

    my $rc = $EXIT_OK;

    my $daisy_version = dca_get_daisy_version($daisy_dir);
    if ($daisy_version) {
	showinfo("Daisy version: $daisy_version");
    }
    else {
	logerror("[report_daisy_version] could not get Daisy version");
	$rc = $EXIT_DAISY_VERSION;
    }

    return($rc);
}


sub dca_report_shopcode
{
    my ($daisy_dir) = @_;

    my $rc = $EXIT_OK;

    my $shopcode_file = dc_pathto_daisy_shopcode_file($daisy_dir);
    my $shopcode = dca_get_shopcode($shopcode_file);
    if ($shopcode) {
	showinfo("Teleflora Shopcode: $shopcode");
    }
    else {
	logerror("[report_shopcode] could not get shopcode");
	$rc = $EXIT_SHOPCODE;
    }

    return($rc);
}


sub dca_report_shopname
{
    my ($daisy_dir) = @_;

    my $rc = $EXIT_OK;

    my $shopname_file = dc_pathto_daisy_shopname_file($daisy_dir);
    my $shopname = dca_get_shopname($shopname_file);
    if ($shopname) {
	showinfo("Teleflora Shop Name: $shopname");
    }
    else {
	logerror("[report_shopname] could not get shopname");
	$rc = $EXIT_SHOPNAME;
    }

    return($rc);
}


sub dca_report_country_code
{
    my ($daisy_dir) = @_;

    my $rc = $EXIT_OK;

    my $country_code_file = dc_pathto_daisy_country_code_file($daisy_dir);
    my $country_code = dca_get_country_code($country_code_file);
    if ($country_code) {
	showinfo("Country: $country_code");
    }
    else {
	logerror("[report_country_code] could not get country code");
	$rc = $EXIT_COUNTRY_CODE;
    }

    return($rc);
}


sub dca_report_florist_directory_version
{
    my ($daisy_dir) = @_;

    my $rc = $EXIT_OK;

    my $florist_directory_version_file = dc_pathto_daisy_florist_directory_version_file($daisy_dir);
    my $florist_directory_version = dca_get_florist_directory_version($florist_directory_version_file);
    if ($florist_directory_version) {
	showinfo("Daisy florist directory version: $florist_directory_version");
    }
    else {
	logerror("[report_florist_directory_version] could not get Daisy florist directory version");
	$rc = $EXIT_FLORIST_DIRECTORY_VERSION;
    }

    return($rc);
}


sub dca_report_tcc_version
{
    my ($daisy_dir) = @_;

    my $rc = $EXIT_OK;

    my $tcc_bin_path = dc_pathto_daisy_tcc_bin($daisy_dir);
    my $tcc_version = dca_get_tcc_version($tcc_bin_path);
    if ($tcc_version) {
	showinfo("TCC version: $tcc_version");
    }
    else {
	showerror("[report_tcc_version] could not get TCC version");
	$rc = $EXIT_TCC_VERSION;
    }

    return($rc);
}


sub dca_report_card_url
{
    my ($daisy_dir) = @_;

    my $rc = $EXIT_OK;

    my $card_url_file_path = dc_pathto_daisy_card_url_file($daisy_dir);
    my $card_url = dca_get_card_url($card_url_file_path);
    if ($card_url) {
	my $status = 'OK';
	if ($card_url ne 'https://prodgate.viaconex.com   ') {
	    $status = 'OBSOLETE';
	}
	showinfo("Credit card URL ($card_url): $status");
    }
    else {
	showerror("[report_card_url] could not get credit card url");
	$rc = $EXIT_CARD_URL;
    }

    return($rc);
}


sub dca_report_card_start_number
{
    my ($daisy_dir) = @_;

    my $rc = $EXIT_OK;
    my $ml = '[report_card_start_number]';

    my $daisy_control_file = dc_pathto_daisy_control($daisy_dir);
    my $card_start_number = $EMPTY_STR;

    if (open(my $fh, '<', $daisy_control_file)) {
	my $buffer;
	seek($fh, 7434, 0);
	my $read_status = sysread($fh, $buffer, 1);
	if (defined($read_status) && $read_status != 0) {
	    $card_start_number = substr($buffer, 0, 1);
	}
	close($fh) or warn "$ml could not close $daisy_control_file: $OS_ERROR\n";

	my $status = ($card_start_number eq '2') ? 'OK' : 'OBSOLETE';
	showinfo("Credit card start number ($card_start_number): $status");
    }
    else {
	logerror("$ml could not open Daisy control file: $daisy_control_file");
	$rc = $EXIT_CARD_START_NUMBER;
    }

    return($rc);
}


sub dca_report_next_ticket_number
{
    my ($daisy_dir) = @_;

    my $rc = $EXIT_OK;
    my $ml = '[report_next_ticket_number]';

    my $pos_control_file = dc_pathto_daisy_pos_control($daisy_dir);

    if (open(my $fh, '<', $pos_control_file)) {
	binmode($fh);
	my $read_status = read($fh, my $bytes, 4);
	if (defined($read_status) && $read_status == 4) {
	    # little endian 32-bit signed number
	    my $next_ticket_number = unpack('l<', $bytes);
	    my $status = ($next_ticket_number <= $DEF_MAX_TICKET_NUMBER) ? 'OK' : 'OVERFLOW';
	    showinfo("Next Ticket number ($next_ticket_number): $status");
	}
	else {
	    logerror("$ml could not read pos control file: $pos_control_file");
	    $rc = $EXIT_NEXT_TICKET_NUMBER;
	}
	close($fh) or warn "$ml could not close $pos_control_file: $OS_ERROR\n";
    }
    else {
	logerror("$ml could not open pos control file: $pos_control_file");
	$rc = $EXIT_NEXT_TICKET_NUMBER;
    }

    return($rc);
}

sub dca_report_large_file
{
    my $rc = $EXIT_OK;
    my $ml = '[report_large_file]';

    my $dir = $DAISY_TOPDIR;
    if (opendir(my $fh, $dir)) {
        foreach my $dirent (readdir($fh)) {
	    if ($dirent eq '.' || $dirent eq '..') {
		next;
	    }
	    my $file_path = File::Spec->catdir($dir, $dirent);
	    if (-f $file_path) {
		my $file_size = -s $file_path;
		if ($file_size > $DEF_LARGE_FILE) {
		    showinfo("Large File in /d ($file_size bytes): $file_path");
		}
	    }
	}
	closedir($fh);
    }
    else {
	logerror("$ml could not open directory: /d");
	$rc = $EXIT_LARGE_FILE;
    }

    return($rc);
}


sub dca_report_encrypted_daisy_dir
{
    my $rc = $EXIT_OK;
    my $ml = '[report_encrypted_daisy_dir]';

    my $daisy_top = dc_pathto_daisy_topdir();
    my @encrypted_archives = glob("$daisy_top/*.tar.asc");
    for my $archive (@encrypted_archives) {
	my $archive_size = -s $archive;
	showinfo("Encrypted tar archive ($archive_size bytes): $archive");
    }

    return($rc);
}


##
## Getters
##

sub dca_get_daisy_version
{
    my ($daisy_dir) = @_;

    my $daisy_version = $EMPTY_STR;

    my $daisy_pos_bin = dc_pathto_daisy_pos_bin($daisy_dir);
    my $cmd = "$daisy_pos_bin --version";
    if (-x $daisy_pos_bin) {
	if (open(my $pipe, q{-|}, $cmd)) {
	    while (<$pipe>) {
		if (/^Build Number: (.+)$/) {
		    $daisy_version = $1;
		    last;
		}
	    }
	    close($pipe) or warn "[get_daisy_version] could not close pipe $cmd: $OS_ERROR\n";
	}
	else {
	    showerror("[get_daisy_version] could not open Daisy program: $daisy_pos_bin");
	}
    }
    else {
	showerror("[get_daisy_version] Daisy program does not exist: $daisy_pos_bin");
    }

    return($daisy_version);
}


sub dca_get_ostools_version
{
    my $ostools_version = $EMPTY_STR;

    my $ostools_cmd_name = 'tfinfo.pl';
    my $ostools_cmd_options = '--version';
    my $ostools_cmd = "$ostools_cmd_name $ostools_cmd_options";
    my $ostools_cmd_path = File::Spec->catdir(dc_pathto_ostools_bindir(), $ostools_cmd_name);
    if (-x $ostools_cmd_path) {
	if (open(my $pipe, q{-|}, $ostools_cmd)) {
	    while (<$pipe>) {
		if (/OSTools Version:\s*(.*)$/i) {
		    $ostools_version = $1;
		    last;
		}
	    }
	    close($pipe) or warn "[get_ostools_version] could not close pipe $ostools_cmd: $OS_ERROR\n";
	}
	else {
	    showerror("[get_ostools_version] could not open pipe to OSTools command: $ostools_cmd");
	}
    }
    else {
	showerror("[get_ostools_version] OSTools command is not executable: $ostools_cmd_path");
    }

    return($ostools_version);
}


#
# get the shopcode
#
# Returns:
#   shopcode as 8 digit string on success
#   empty string on error
#
sub dca_get_shopcode
{
    my ($shopcode_file) = @_;

    my $shopcode = $EMPTY_STR;

    if (-f $shopcode_file) {
	if (open(my $fh, '<', $shopcode_file)) {
	    my $buffer;
	    my $rc = sysread($fh, $buffer, 38);
	    if (defined($rc) && $rc != 0) {
		$shopcode = substr($buffer, 30, 8);
	    }
	    close($fh) or warn "[get_shopcode] could not close $shopcode_file: $OS_ERROR\n";
	}
	else {
	    logerror("[get_shopcode] could not open shopcode file: $shopcode_file");
	}
    }
    else {
	logerror("[get_shopcode] Daisy shopcode file does not exist: $shopcode_file");
    }

    return($shopcode);
}

#
# get the shop name
#
# returns
#   shop name on success
#   empty string if error
#
sub dca_get_shopname
{
    my ($shopname_file) = @_;

    my $shopname = $EMPTY_STR;
    my $ml = '[get_shopname]';

    if (-f $shopname_file) {
	if (open(my $fh, '<', $shopname_file)) {
	    my $buffer;
	    seek($fh, 0x2e3, 0);
	    my $rc = sysread($fh, $buffer, 40);
	    if (defined($rc) && $rc != 0) {
		$buffer =~ s/^\s+//;
		$buffer =~ s/\s+$//;
		$shopname = $buffer;
	    }
	    else {
		logerror("$ml could not read shop name file: $shopname_file");
	    }
	    close($fh) or warn "$ml could not close $shopname_file: $OS_ERROR\n";
	}
	else {
	    logerror("$ml could not open shop name file: $shopname_file");
	}
    }
    else {
	logerror("$ml shop name file does not exist: $shopname_file");
    }

    return($shopname);
}

#
# get the country code
#
# the first byte of "control.dsy" is 0x01 for canadian, or 0x00 for US.
#
# Returns:
#   country code
#   empty string on error
#
sub dca_get_country_code
{
    my ($country_code_file) = @_;

    my $country_code = $EMPTY_STR;
    my $country_byte = 0;

    if (-f $country_code_file) {
	if (open(my $fh, '<', $country_code_file)) {
	    my $rc = read($fh, my $buffer, 1);
	    if (defined($rc) && $rc != 0) {
		$country_byte = unpack 'c', $buffer;
		if ($country_byte == 0) {
		    $country_code = 'USA';
		}
		if ($country_byte == 1) {
		    $country_code = 'Canada';
		}
	    }
	    else {
		showerror("[get_country_code] could not read Daisy country code file: $country_code_file");
	    }
	    close($fh) or warn "[get_country_code] could not close $country_code_file: $OS_ERROR\n";
	}
	else {
	    showerror("[get_country_code] could not open Daisy country code file: $country_code_file");
	}
    }
    else {
	showerror("[get_country_code] Daisy country code file does not exist: $country_code_file");
    }

    return($country_code);
}


#
# get the florist directory version
#
# the first line of "control.tel" contains the version string
#
# Returns:
#   florist directory version
#   empty string on error
#
sub dca_get_florist_directory_version
{
    my ($florist_directory_version_file) = @_;

    my $florist_directory_version = $EMPTY_STR;
    my $log_label = "get_florist_directory_version";

    if (-f $florist_directory_version_file) {
	if (open(my $fh, '<', $florist_directory_version_file)) {
	    while (<$fh>) {
		if (/Teleflora (.*)$/) {
		    $florist_directory_version = $1;
		    last;
		}
	    }
	    close($fh) or warn "[get_florist_directory_version] could not close $florist_directory_version_file: $OS_ERROR\n";
	}
	else {
	    showerror("[$log_label] could not open florist directory version file: $florist_directory_version_file");
	}
    }
    else {
	showerror("[$log_label] Daisy florist directory version file does not exist: $florist_directory_version_file");
    }

    return($florist_directory_version);
}


#
# get the TCC version
#
# Returns:
#   TCC version
#   empty string on error
#
sub dca_get_tcc_version
{
    my ($tcc_bin_path) = @_;

    my $tcc_version = $EMPTY_STR;

    my $tcc_cmd_options = '--version';
    my $tcc_cmd = "$tcc_bin_path $tcc_cmd_options";
    if (-x $tcc_bin_path) {
	if (open(my $pipe, q{-|}, $tcc_cmd)) {
	    while (<$pipe>) {
		if (/Version:\s*(.*)$/i) {
		    $tcc_version = $1;
		    last;
		}
	    }
	    close($pipe) or warn "[get_tcc_version] could not close pipe $tcc_cmd: $OS_ERROR\n";
	}
	else {
	    showerror("[get_tcc_version] could not open pipe to TCC command: $tcc_cmd");
	}
    }
    else {
	showerror("[get_tcc_version] TCC command is not executable: $tcc_bin_path");
    }

    return($tcc_version);
}


sub dca_get_card_url
{
    my ($card_url_file_path) = @_;

    my $card_url = $EMPTY_STR;

    if (open(my $fh, '<', $card_url_file_path)) {
	seek($fh, 4, 0);
	my $rc = sysread($fh, $card_url, 32);
	if (defined($rc) && $rc != 0) {
	    loginfo("[get_card_url] bytes read from credit card url file: $rc");
	    loginfo("[get_card_url] credit card url: $card_url");
	}
	else {
	    showerror("[get_card_url] read error on credit card url file: $card_url_file_path");
	    $card_url = $EMPTY_STR;
	}
	close($fh) or warn "[get_card_url] could not close file $card_url_file_path: $OS_ERROR\n";
    }
    else {
	showerror("[get_card_url] could not open credit card url file: $card_url_file_path");
    }

    return($card_url);
}


############################
###                      ###
###    TEST FUNCTIONS    ###
###                      ###
############################

sub dc_test_functions
{
    return(1);
}



############################
###                      ###
###    DAISY FUNCTIONS   ###
###                      ###
############################

sub dc_tfsupport_account_name
{
    return($DEF_TFSUPPORT_ACCOUNT_NAME);
}

sub dc_pos_admin_group_name
{
    return($DEF_DAISY_ADMIN_GROUP_NAME) if ($DAISY);
    return("root");
}

sub dc_pos_group_name
{
    return($DEF_DAISY_GROUP_NAME) if ($DAISY);
    return("root");
}


#
# Function to determine if an arbitrary path is a path to a
# daisy databse directory.
#
sub is_daisy_db_dir
{
    my ($path) = @_;

    # must begin with '/d/'
    if ($path !~ /^\/d\//) {
	return(0);
    }

    # must be a directory
    if (! -d $path) {
	return(0);
    }

    # skip old daisy dirs
    if ($path =~ /^\/d\/.+-\d{12}$/) {
	return(0);
    }

    # must contain the magic files
    if (! -e "$path/flordat.tel") {
	return(0);
    }
    if (! -e "$path/control.dsy") {
	return(0);
    }

    # must be daisy 8.0+
    if (! -d "$path/bin") {
	return(0);
    }

    return(1);
}

sub is_cloud_backup_installed
{
    my $rc = $FALSE;

    my $rsync_bu_dir = dc_pathto_daisy_rsync_bu_dir();
    if (-d $rsync_bu_dir) {
	if (is_cloud_backup_account_installed()) {
	    if (is_cloud_backup_cron_job_installed()) {
		$rc = $TRUE;
	    }
	}
    }

    return($rc);
}

sub is_server_backup_installed
{
    my $rc = $FALSE;

    my $rsync_bu_dir = dc_pathto_daisy_rsync_bu_dir();
    if (-d $rsync_bu_dir) {
	if (is_server_backup_account_installed()) {
	    if (is_server_backup_cron_job_installed()) {
		$rc = $TRUE;
	    }
	}
    }

    return($rc);
}

sub is_cloud_backup_account_installed
{
    my $rc = $FALSE;

    if (is_account_installed($DEF_RSYNC_ACCOUNT_NAME)) {
	$rc = $TRUE;
    }

    return($rc);
}

sub is_cloud_backup_cron_job_installed
{
    my $rc = $FALSE;

    my $cloud_cron_job_path = dc_pathto_cloud_backup_cron_job();
    if (-f $cloud_cron_job_path) {
	$rc = $TRUE;
    }

    return($rc);
}

sub is_server_backup_account_installed
{
    my $rc = $FALSE;

    if (is_account_installed($DEF_RSYNC_ACCOUNT_NAME)) {
	$rc = $TRUE;
    }

    return($rc);
}

sub is_server_backup_cron_job_installed
{
    my $rc = $FALSE;

    my $server_backup_cron_job_path = dc_pathto_server_backup_cron_job();
    if (-f $server_backup_cron_job_path) {
	$rc = $TRUE;
    }

    return($rc);
}

#
# Given an account name, verify it's existence.
#
# Returns
#   1 if account exists
#   0 if account does not exist
#   
sub is_account_installed
{
    my ($account_name) = @_;

    if (system("id -u $account_name > /dev/null 2>&1") == 0) {
	return(1);
    }

    return(0);
}


#
# Daisy POS must have at least one database dir but can have more than one.
#
sub dc_get_daisy_dirs
{
    my @daisy_dirs = ();
    my $daisy_top_dir = dc_pathto_daisy_topdir();

    my @daisy_top_files = glob("$daisy_top_dir/*");
    for my $daisy_top_file (@daisy_top_files) {
	if (is_daisy_db_dir($daisy_top_file)) {
	    push(@daisy_dirs, $daisy_top_file);
	}
    }

    return (@daisy_dirs);
}


############################################
##                                        ##
##        PATHTO and NAMEOF SUBS          ##
##                                        ##
############################################

sub dc_pathto_ostools_topdir
{
    return($OSTOOLS_TOPDIR);
}

sub dc_pathto_ostools_dir
{
    return(File::Spec->catfile(dc_pathto_ostools_topdir(), dc_nameof_ostools_dir()));
}

sub dc_pathto_ostools_bindir
{
    return(File::Spec->catfile(dc_pathto_ostools_dir(), dc_nameof_ostools_bindir()));
}

sub dc_pathto_ostools_configdir
{
    return(File::Spec->catfile(dc_pathto_ostools_dir(), dc_nameof_ostools_configdir()));
}

sub dc_pathto_daisy_topdir
{
    return($DAISY_TOPDIR);
}

sub dc_pathto_daisy_rsync_bu_dir
{
    return(File::Spec->catfile($DAISY_TOPDIR, dc_nameof_daisy_rsync_bu_dir()));
}

sub dc_pathto_daisy_dir
{
    return(File::Spec->catfile(dc_pathto_daisy_topdir(), dc_nameof_daisydir()));
}

sub dc_pathto_daisy_shopcode_file
{
    my ($daisy_dir) = @_;

    return(File::Spec->catfile($daisy_dir, dc_nameof_daisy_shopcode_file()));
}

sub dc_pathto_daisy_shopname_file
{
    my ($daisy_dir) = @_;

    return(File::Spec->catfile($daisy_dir, dc_nameof_daisy_control_file()));
}

sub dc_pathto_daisy_control
{
    my ($daisy_dir) = @_;

    return(File::Spec->catfile($daisy_dir, dc_nameof_daisy_control_file()));
}

sub dc_pathto_daisy_pos_control
{
    my ($daisy_dir) = @_;

    return(File::Spec->catfile($daisy_dir, dc_nameof_daisy_pos_control_file()));
}

sub dc_pathto_daisy_logfile_dir
{
    return(File::Spec->catfile(dc_pathto_daisy_dir, dc_nameof_daisy_logdir()));
}

sub dc_pathto_logfile
{
    return($LOGFILE);
}

sub dc_pathto_daisy_pos_bin
{
    my ($daisy_dir) = @_;

    return(File::Spec->catfile($daisy_dir, dc_nameof_daisy_pos_bin()));
}

sub dc_pathto_daisy_tcc_bin
{
    my ($daisy_dir) = @_;

    my $tcc_bindir = (File::Spec->catfile($daisy_dir, dc_nameof_daisy_tcc_bindir()));

    return(File::Spec->catfile($tcc_bindir, dc_nameof_daisy_tcc_bin()));
}

sub dc_pathto_daisy_card_url_file
{
    my ($daisy_dir) = @_;

    return(File::Spec->catdir($daisy_dir, dc_nameof_daisy_card_url_file()));
}

sub dc_pathto_daisy_country_code_file
{
    my ($daisy_dir) = @_;

    return(File::Spec->catfile($daisy_dir, dc_nameof_daisy_country_code_file()));
}

sub dc_pathto_daisy_florist_directory_version_file
{
    my ($daisy_dir) = @_;

    return(File::Spec->catfile($daisy_dir, dc_nameof_daisy_florist_directory_file()));
}

sub dc_pathto_cloud_backup_cron_job
{
    return(File::Spec->catfile('/etc/cron.d', dc_nameof_cloud_backup_cron_job()));
}

sub dc_pathto_server_backup_cron_job
{
    return(File::Spec->catfile('/etc/cron.d', dc_nameof_server_backup_cron_job()));
}

sub dc_pathto_network_ifcfg
{
    return('/etc/sysconfig/network-scripts/ifcfg-eth0');
}

sub dc_nameof_cloud_backup_cron_job
{
    return($DEF_CLOUD_BACKUP_CRON_JOB_NAME);
}

sub dc_nameof_server_backup_cron_job
{
    return($DEF_SERVER_BACKUP_CRON_JOB_NAME);
}

sub dc_nameof_ostools_dir
{
    return($OSTOOLS_DIR_NAME);
}

sub dc_nameof_ostools_bindir
{
    return($OSTOOLS_BINDIR_NAME);
}

sub dc_namefo_ostools_configdir
{
    return($OSTOOLS_CONFIGDIR_NAME);
}

sub dc_nameof_daisydir
{
    return($DAISYDIR_NAME);
}

sub dc_nameof_daisy_logdir
{
    return($DAISY_LOGDIR_NAME);
}

sub dc_nameof_daisy_pos_bin
{
    return($DAISY_POS_BIN_NAME);
}

sub dc_nameof_daisy_shopcode_file
{
    return($DAISY_SHOPCODE_FILE_NAME);
}

sub dc_nameof_daisy_control_file
{
    return($DAISY_CONTROL_FILE_NAME);
}

sub dc_nameof_daisy_pos_control_file
{
    return($DAISY_POS_CONTROL_FILE_NAME);
}

sub dc_nameof_daisy_country_code_file
{
    return($DAISY_COUNTRY_CODE_FILE_NAME);
}

sub dc_nameof_daisy_florist_directory_file
{
    return($DAISY_FLORIST_DIRECTORY_FILE_NAME);
}

sub dc_nameof_daisy_tcc_bindir
{
    return($DAISY_TCC_BIN_DIR_NAME);
}

sub dc_nameof_daisy_tcc_bin
{
    return($DAISY_TCC_BIN_NAME);
}

sub dc_nameof_daisy_card_url_file
{
    return($DAISY_CARD_URL_FILE_NAME);
}

sub dc_nameof_daisy_rsync_bu_dir
{
    return($DAISY_RSYNC_BU_DIR_NAME);
}


############################
###                      ###
###        UTILITY       ###
###                      ###
############################

sub dc_is_cmd_line_consistent
{

    return(1);
}


sub dc_exit_status_extract
{
    my ($system_rc) = @_;

    my $cmd_exit_status = -1;

    # no exit status available
    if ( ($system_rc == -1) || ($system_rc & 127) ) {
	return($cmd_exit_status);
    }
	    
    # get at the command's exit status
    $cmd_exit_status = ($system_rc >> 8);

    return($cmd_exit_status);
}


#
# output elements of an array, with specified separator, and
# with specified number of elements per line.
#
sub dc_print_array
{
    my ($array_ref, $leadchar, $sepchar, $elems_per_line) = @_;

    # if array empty, nothing to print
    if (scalar(@{$array_ref}) == 0) {
	return(1);
    }

    # if elements per line <= 0, nothing to print
    if ($elems_per_line > 0) {
	my $elems_out_counter = 0;
	foreach my $elem (@{$array_ref}) {
	    if ($elems_out_counter >= $elems_per_line) {
		print "$sepchar\n";
		$elems_out_counter = 0;
	    }
	    if ($elems_out_counter == 0) {
		print $leadchar;
	    }
	    if ($elems_out_counter > 0) {
		print $sepchar;
	    }
	    print $elem;
	    $elems_out_counter++;
	}
	print "\n";
    }

    return(1);
}

#
# Convert seconds to human readable time.
#
# Taken from www.perlmonks.org
#
sub conv_time_to_dhms
{
    my ($s) = @_;

    return "less than 1 sec" if ($s == 0);

    return sprintf "00:00:%02d", $s if $s < 60;

    my $m = $s / 60; $s = $s % 60;
    return sprintf "00:%02d:%02d", $m, $s if $m < 60;

    my $h = $m /  60; $m %= 60;
    return sprintf "%02d:%02d:%02d", $h, $m, $s if $h < 24;

    my $d = $h / 24; $h %= 24;
    return sprintf "%d:%02d:%02d:%02d", $d, $h, $m, $s;
}


sub get_command_line
{
	my $cmd_line = $EMPTY_STR;

	$cmd_line = $0;
	foreach my $i (@ARGV) {
		$cmd_line .= q{ };
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


# PCI 6.5.6
#
# Look for a list of patterns in an input string that might
# indicate that some insecure value was passed into the script.
# Example, no input scring should have the BACKQUOTE chars as
# part of the string... if there were, it could mean that
# someone was trying to get the script to run another unknown
# script as "root".
#
# Returns
#   1 if input is insecure
#   0 if input is OK
#
sub dc_is_input_insecure
{
    my ($cmd) = @_;

    return(0) if ($cmd eq $EMPTY_STR);

    my $rc = 0;

    my @insecure_patterns = (
	q{\`},               # `bad command`
	q{(\$\()(.*.)(\))},  # $(bad command)
	q{\;},               # stuff ; bad command
	q{\&},               # stuff && bad command
	q{\|},               # stuff | bad command
	q{\>},               # stuff > bad command
	q{\<},               # stuff < bad command
	q{[[:cntrl:]]},      # non printables
    );

    foreach my $re (@insecure_patterns) {
	if ($cmd =~ /$re/) {
	    $rc = 1;
	    last;
	}
    }

    return($rc);
}


sub is_service_configured
{
    my ($service_name) = @_;

    my $rc = 0;

    my $cmd = "/sbin/chkconfig --list";
    if (open(my $pipe, q{-|}, $cmd)) {
	while (<$pipe>) {
	    if (/^${service_name}\s+/) {
		$rc = 1;
	    }
	}
	close($pipe) or warn "[is_service_configured] could not close pipe $cmd: $OS_ERROR\n";
    }
    else {
	logerror("error opening pipe to command: $cmd");
    }

    return($rc);
}


#
# Get the file system UUID from the specified backup device.
#
# Returns
#   non-empty string with 36 character UUID
#   empty string if UUID can not be found
#
sub get_filesys_uuid
{
    my ($device) = @_;

    my $filesys_uuid  = OSTools::Filesys::filesys_uuid($device);

    return($filesys_uuid);
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
# get boot protocol
#
sub get_boot_protocol
{
    my $protocol = $EMPTY_STR;

    my $conf_file = dc_pathto_network_ifcfg();
    my $pattern = "BOOTPROTO=\"([a-zA-Z]+)\"";
    if (open(my $fh, '<', $conf_file)) {
	while (<$fh>) {
	    if (/$pattern/) {
		$protocol = $1;
	    }
	}
	close($fh) or warn "[get_boot_protocol] could not close file $conf_file: $OS_ERROR\n";
    }
    else {
	logerror("[get_boot_protocol] could not open file: $conf_file");
    }

    return($protocol);
}

#
# Public IP Address
#
sub get_public_ipaddr
{
    my $publicip = $EMPTY_STR;
    my $cmd = "curl --silent http://icanhazip.com";

    # retry several times
    my $max_retries = 5;
    my $iteration = 0;
    for (1 .. $max_retries) {
	$iteration = $_;
	if (open(my $pipe, q{-|}, $cmd)) {
	    while (<$pipe>) {
		chomp;
		if (/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
		    $publicip = $1;
		}
	    }
	    close($pipe) or warn "[get_public_ipaddr] could not close pipe $cmd: $OS_ERROR\n";
	    if ($publicip) {
		loginfo("[get_public_ipaddr] iterations to obtain public ip: $iteration");
		last;
	    }
	}
	else {
	    logerror("[get_public_ipaddr] could not open pipe: $cmd");
	}
    }

    return($publicip);
}

#
# get the ip address of the default network interface.
#
# RHEL6:
#   $ ifconfig eth0
#   eth0      Link encap:Ethernet  HWaddr 08:00:27:2E:A0:DA  
#            inet addr:192.168.1.21  Bcast:192.168.1.255  Mask:255.255.255.0
#
# RHEL7:
#   $ ifconfig eth0
#   eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
#         inet 192.168.1.33  netmask 255.255.255.0  broadcast 192.168.1.255
#
# Returns
#   non-empty string on success
#   empty string on error
#
sub get_ipaddr
{
    my ($network_dev_name) = @_;

    my $ipaddr = $EMPTY_STR;

    my $pattern = 'inet addr:';
    if ($OS eq 'RHEL7') {
	$pattern = 'inet ';
    }

    my $cmd = "/sbin/ifconfig $network_dev_name 2> /dev/null";
    if (open(my $pipe, q{-|}, $cmd)) {
	while (<$pipe>) {
	    if (/${pattern}(\d+\.\d+\.\d+\.\d+)/) {
		$ipaddr = $1;
	    }
	}
	close($pipe) or warn "[get_ipaddr] could not close pipe $cmd: $OS_ERROR\n";
    }
    else {
	logerror("[get_netmask] could not open pipe to command: $cmd");
    }

    return($ipaddr);
}


#
# get the netmask of the default or CLI specified network interface.
#
# Returns
#   non-empty string on success
#   empty string on error
#
sub get_netmask
{
    my ($network_dev_name) = @_;

    my $netmask = $EMPTY_STR;
    my $pattern = 'Mask:';
    if ($OS eq 'RHEL7') {
	$pattern = 'netmask ';
    }

    my $cmd = "/sbin/ifconfig $network_dev_name 2> /dev/null";
    if (open(my $pipe, q{-|}, $cmd)) {
	while (<$pipe>) {
	    if (/${pattern}(\d+\.\d+\.\d+\.\d+)/) {
		$netmask = $1;
	    }
	}
	close($pipe) or warn "[get_netmask] could not close pipe $cmd: $OS_ERROR\n";
    }
    else {
	logerror("[get_netmask] could not open pipe to command: $cmd");
    }

    return($netmask);
}


#
# get the gateway address
#
# Returns
#   non-empty string on success
#   empty string on error
#
sub get_gateway_ipaddr
{
    my $gateway_ipaddr = $EMPTY_STR;

    my $route_cmd = "/sbin/route -n";
    my $pattern = "0.0.0.0";
    my @route_table_entry = ();

    if (open(my $pipe, q{-|}, $route_cmd)) {
	while (<$pipe>) {
	    if (/^$pattern/) {
		@route_table_entry = split(/\s+/);
		last;
	    }
	}
	close($pipe) or warn "[get_gateway_ipaddr] could not close pipe $route_cmd: $OS_ERROR\n";
    }
    else {
	logerror("error opening pipe to command: $route_cmd");
    }

    # check for a route table entry with something reasonable in it
    if (exists($route_table_entry[1])) {
	my $gateway = $route_table_entry[1];
	if ($gateway =~ /\d+\.\d+\.\d+\.\d+/) {
	    $gateway_ipaddr = $gateway;
	}
	else {
	    logerror("unrecognized format for gateway address: $gateway_ipaddr");
	}
    }
    else {
	logerror("unexpected output of route command: $route_cmd");
    }

    return($gateway_ipaddr); 
}


#
# Get account information from password file entry.
#
# returns
#
sub get_userinfo
{
    my ($username) = @_;

    my $groupname = $EMPTY_STR;
    my $users = $EMPTY_STR;
    my @groups = ();
    my %hash = ();

    # Get user related info.
    setpwent();
    my @ent = getpwent();
    while(@ent) {
	if($ent[0] eq $username) {
	    $hash{'username'} = $ent[0];
	    $hash{'passwd'}   = $ent[1];
	    $hash{'uid'}      = $ent[2];
	    $hash{'gid'}      = $ent[3];
	    $hash{'quota'}    = $ent[4];
	    $hash{'comment'}  = $ent[5];
	    $hash{'gcos'}     = $ent[6];
	    $hash{'homedir'}  = $ent[7];
	    $hash{'shell'}    = $ent[8];
	    $hash{'expire'}   = $ent[9];
	    last;
	}
	@ent = getpwent();
    }
    endpwent();
 
    if (!defined($hash{'username'})) {
	return(\%hash);
    }

    # Get user's associated groups.
    # ($name,$passwd,$gid,$members) = getgr*
    #
    # Note: the $members value is a SPACE separated list
    #
    $hash{"groups"} = ();
    @ent = getgrent();
    while(@ent) {
	$groupname = $ent[0];
	$users = $ent[3];
	if ($users =~ /([[:space:]]*)($username)([[:space:]]{1}|$)/) {
	    push @groups, $groupname;
	}
	@ent = getgrent();
    }
    endgrent();
    $hash{'groups'} = join(q{,}, @groups);

    return(\%hash);
}

#
# counts number of active virtual console files
#
# returns
#   number of virtual console files
#
sub get_virtual_console_count
{
    my $rc = 0;

    if ($OS eq 'RHEL7') {
	my %getty_tab = ();
	my $line_count = 0;
	my $cmd = 'systemctl --no-legend --no-pager --type=service --state=active  list-units getty*';
	if (open(my $pipe, q{-|}, $cmd)) {
	    while (<$pipe>) {
		$line_count++;
		if (/getty\@tty(\d+)\.service/) {
		    $getty_tab{$1} = $TRUE;
		}
	    }
	    close($pipe) or warn "[get_virtual_console_count] could not close pipe $cmd: $OS_ERROR\n";
	}

	$rc = $line_count;
	foreach my $i (1..12) {
	    if (! defined($getty_tab{$i})) {
		showerror("[get_virtual_console_count] virtual console unit file missing: $i");
	    }
	}
    }

    if ($OS eq 'RHEL6') {
	my $active_consoles = 0;
	my $conf_file = '/etc/sysconfig/init';
	if (open(my $fh, '<', $conf_file)) {
	    while (<$fh>) {
		if (/ACTIVE_CONSOLES=\/dev\/tty\[1-(\d+)\]/) {
		    $active_consoles = $1;
		}
	    }
	    close($fh) or warn "[get_virtual_console_count] could not close $conf_file: $OS_ERROR\n";

	    if ($active_consoles != 12) {
		showerror("[get_virtual_console_count] number of ACTIVE_CONOLES (should be 12): $active_consoles");
	    }
	}
	else {
	    showerror("[get_virtual_console_count] could not open conf file: $conf_file");
	}

	my @init_files = glob("/etc/init/tty*.conf");
	my %tty_conf_file_tab = ();
	foreach my $tty_file (@init_files) {
	    if ($tty_file =~ /\/etc\/init\/tty(\d+)\.conf/) {
		$tty_conf_file_tab{$1} = 1;
	    }
	}

	$rc = scalar(@init_files);
	if ($rc != 12) {
	    showerror("[get_virtual_console_count] unexpected number of tty*.conf files: $rc");
	}

	foreach (1 .. 12) {
	    if (! defined($tty_conf_file_tab{$_})) {
		showerror("[get_virtual_console_count] missing tty conf file: $_");
	    }
	}
    }

    return($rc);
}


#
# verify network device - all this means is that "ifconfig"
# returned an exit status of 0 for this interface.
#
# Returns
#   1 if verify successful
#   0 if not
#
sub dc_verify_network_dev_name
{
    my ($network_dev_name) = @_;

    my $rc = 1;

    if ($network_dev_name eq $EMPTY_STR) {
	showinfo("[verify_network_dev_name] network device name is empty string");
	return(0);
    }

    if (dc_is_input_insecure($network_dev_name)) {
	showinfo("[verify_network_dev_name] network device name is insecure: $network_dev_name");
	return(0);
    }

    system("/sbin/ifconfig $network_dev_name > /dev/null 2>&1");
    if ($? != 0) {
	$rc = 0;
    }

    return($rc);
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
    if (open(my $fh, '<', $fpath)) {
	while (<$fh>) {
	    chomp;
	    if (/$re/) {
		$rc = 0;
		last;
	    }
        }
	close($fh) or warn "[fgrep] could not close $fpath: $OS_ERROR\n";
    }

    return($rc);
}

sub dc_util_convert_bytes
{
    my ($bytes) = @_;

    my $rc = $EMPTY_STR;

    foreach ('B', 'KB', 'MB', 'GB', 'TB', 'PB') {
	if ($bytes < 1024) {
	    $rc = sprintf("%.2f", $bytes) . $_;
	    last;
	}
	$bytes /= 1024;
    }

    return($rc);
}

sub dc_list_longest_elem
{
    my (@list_elems) = @_;

    my $longest_elem = $list_elems[0];
    my $elem_len = length $longest_elem;
    for my $elem (@list_elems) {
	if (length($elem) > $elem_len ) {
	    $longest_elem = $elem;
	    $elem_len = length($elem);
	}
    }

    return($longest_elem);
}



#
# make the dir at the given path if it does not
# already exist.
#
# Returns
#   1 on success
#   0 if error
#
sub dc_util_mkdir
{
    my ($dir_path) = @_;

    my $rc = 1;

    if (! -d $dir_path) {
	mkdir($dir_path);
	if (! -d $dir_path) {
	    $rc = 0;
	}
    }

    return($rc);
}


#
# remove the pserver dir at the given path
#
# Returns
#   1 on success
#   0 if error
#
sub dc_util_rmdir
{
    my ($dir_path) = @_;

    my $rc = 1;

    if (-d $dir_path) {
	system("rm -rf $dir_path");
	if (-d $dir_path) {
	    $rc = 0;
	}
    }

    return($rc);
}


#
# Given an account name, get the path to default ssh dir.
#
# Returns
#   path to default ssh dir on success
#   empty string on failure
#
sub dc_sshdir_default_path
{
    my ($account_name) = @_;

    my $sshdir_path = $EMPTY_STR;

    if ($account_name) {
	if (dc_accounts_verify_account($account_name)) {
	    my $homedir_path = dc_accounts_homedir($account_name);
	    $sshdir_path = $homedir_path . q{/} . '.ssh';
	}
    }

    return($sshdir_path);
}


#
# Given an account name, verify it's existence.
#
# Returns
#   1 if account exists
#   0 if account does not exist
#   
sub dc_accounts_verify_account
{
    my ($account_name) = @_;

    if (system("id -u $account_name > /dev/null 2>&1") == 0) {
	return(1);
    }

    return(0);
}


#
# setup the log file and it's location
#
# A directory to contain the log file may be specified
# on the command line.  The default location is
# the Daisy log directory.
#
# The log dir can be either $DEF_DAISY_LOGDIR or user input.
# if insecure or $EMPTY_STR, make it ".".
# if not a directory, make it "/tmp".
#
sub dc_log_setup
{
    my ($logfile_dir, $logfile_name) = @_;

    my $rc = $TRUE;

    if (dc_is_input_insecure($logfile_dir) || ($logfile_dir eq $EMPTY_STR)) {
	$logfile_dir = q{.};
    }

    if (! -d $logfile_dir) {
	print {*STDERR} "[log setup] logfile dir not a directory: $logfile_dir\n";
	print {*STDERR} "[log setup] logfile dir set to: $DEF_ALT_LOGFILE_DIR\n";
	$logfile_dir = $DEF_ALT_LOGFILE_DIR;
    }

    # form path for current log file
    $LOGFILE = File::Spec->catfile($logfile_dir, $logfile_name);

    # make an empty logfile if it does not exist
    if (! -f $LOGFILE) {
	if (open(my $lfh, '>', $LOGFILE)) {
	    close($lfh) or warn "[log_setup] could not close $LOGFILE: $OS_ERROR\n";
	}
	else {
	    print {*STDERR} "[log setup] could not make new empty logfile $LOGFILE\n";
	    $rc = $FALSE;
	}
    }

    return($rc);
}


# Output to screen, and write info to logfile.
sub showinfo
{
    my ($message) = @_;

    print "$message\n";

    return(loginfo("<I>  $message"));
}


# Output to screen, and write error to logfile.
sub showerror
{
    my ($message) = @_;

    print "$message\n";

    return(loginfo("<E>  $message"));
}


# Write error to logfile and output to screen if verbose.
sub logerror
{
    my ($message) = @_;

    if($VERBOSE != 0) {
	print "$message\n";
    }

    return(loginfo("<E>  $message"));
}


# Write debug info to logfile and output to screen if verbose.
sub logdebug
{
    my ($message) = @_;

    if($VERBOSE != 0) {
	print "$message\n";
    }

    return(loginfo("<D>  $message"));
}


#
# Write message to logfile.
#
sub loginfo
{
    my ($message) = @_;

    my $timestamp = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time()));

    if (open(my $log, '>>', $LOGFILE)) {
	print {$log} "$timestamp";
	if ( ($message !~ /<E>/) &&  ($message !~ /<D>/) &&  ($message !~ /<I>/) ) {
	    print {$log} " <I> ";
	}
	print {$log} " $message\n";
	close($log) or warn "[loginfo] could not close $LOGFILE: $OS_ERROR\n";

	# insurance that processes can access the log file
	system("chmod ugo=rw $LOGFILE");
    }
    else {
	print "$timestamp $message\n";
    }

    return(1);
}


sub debuglog
{
    my ($message) = @_;

    my $timestamp = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time()));

    if (open(my $log, '>>', $DebugLogfile)) {
	print {$log} "$timestamp $message\n";
	close($log) or warn "[debuglog] could not close $DebugLogfile: $OS_ERROR\n";
    }
    else {
	print "$timestamp $message\n";
    }

    return(1);
}


#__END__

=pod

=head1 NAME

dsycheck.pl - Check a Daisy Installation

=head1 VERSION

This documenation refers to version: $Revision: 1.11 $


=head1 SYNOPSIS

dsycheck.pl --help

dsycheck.pl --version

dsycheck.pl [option]


=head1 OPTIONS

=over 4

=item B<--help>

Output a usage help message and exit.

=item B<--version>

Output the version number of the script and exit.

=item B<--verbose>

Write log messages to screen as well as to log file.

=item B<--logfile-dir=s>

Set the location of the log file rather than to the default F</d/daisy/log>.

=item B<--report-os-version>

Output the string for the platform, either "RHEL6" or "RHEL7".

=item B<--report-ostools-version>

Output the version number of the OSTools package.

=item B<--report-hostname>

Output the hostname of the system.

=item B<--report-ip-addr>

Output the IP address of the network interface (default named "eth0")

=item B<--report-public-ip-addr>

Output the public IP address of the system as reported by "icanhazip.com".

=item B<--report-gateway-ip-addr>

Output the IP address of the gateway, usually the router.

=item B<--report-boot-protocol>

Output the type of boot protocol.

=item B<--report-disk-free>

Output the amount of available disk space on the "/d" file system.

=item B<--report-fstab-changes>

Verify that the changes to the file "/etc/fstab" have been made.
The changes are different between "RHEL6" and "RHEL7".

=item B<--report-mount-points>

Verify the existence of the mount points "/mnt/cdrom" and "/mnt/usb".

=item B<--report-samba-conf>

Verify the changes made to the Samba config file.

=item B<--report-samba-password>

Verify the "daisy" user has a Samba password.

=item B<--report-system-locale>

Verify the system locale has been set appropriately for "RHEL6" and "RHEL7".

=item B<--report-system-audit-rules>

Report whether system audit rules for Daisy have been configured.

=item B<--report-cloud-backup>

Report whether the system is configured for Cloud backup.

=item B<--report-server-backup>

Report whether the system is configured for Server to Server backup.

=item B<--report-virtual-console-count>

Report the nunber of configured virtual consoles.

=item B<--report-virtual-console-files>

Verify the existence of virtual console config files.

=item B<--report-virtual-console-perms>

Verify the perms and modes on the virtual console config files.

=item B<--report-tfsupport-user>

Verify the existence of the "tfsupport" user.

=item B<--report-daisy-user>

Verify the existence of the "daisy" user.

=item B<--report-daisy-version>

Report the Daisy version number.

=item B<--report-shopcode>

Report the Teleflora shopcode.

=item B<--report-shopname>

Report the Teleflora shop name.

=item B<--report-country-code>

Report the country code.

=item B<--report-florist-directory-version>

Report the version string for the installed florist directory package.

=item B<--report-tcc-version>

Report the version number of TCC.

=item B<--report-card-url>

Report the URL for the configured credit card processor.

=item B<--report-card-start-number>

Report the allowed credit card start number from the Daisy control file.

=item B<--report-next-ticket-number>

Report the next ticket number from the Daisy POS control file.

=item B<--report-large-file>

Report files larger than 10MB in '/d'.

=item B<--report-encrypted-daisydir>

Report the encrypted tar archive files of old Daisy dirs
located in the top level of the Daisy file system.
After an upgrade installation has been verfied as successful and
has operated correctly for an appropriate amount of time,
these files should be removed since
they can consume significant disk space.

=back


=head1 DESCRIPTION

The C<dsycheck.pl> script scans key elements of a Daisy installation
on a Red Hat Enterprise Linux system and reports the values of many
attributes.
This information can be of major interest to Teleflora personnel
installing, testing, and supporting Daisy systems.

=head1 EXAMPLES

To run C<dsycheck.pl> and report all attributes:

  $ sudo perl dsycheck.pl

To run C<dsycheck.pl> and report only specific attributes:

  $ sudo perl dsycheck.pl --report-daisy-version --report-tcc-version


=head1 AUTHOR

Script conceived, developed, debugged, and documented by George Smith
of the Teleflora Linux Technologies Group.
Any comments, suggestions, bug reports, or feedback welcome -
call Daisy Support at 888-324-7963.


=head1 FILES

=over 4

=item F</home/tfsupport>

The home directory of the Teleflora support account.

=item F</home/daisy>

The home directory of the quentessential Daisy account.

=item F</d>

Top level Daisy directory.

=item F</d/daisy>

The default Daisy database directory.

=item F</d/daisy-YYYYMMDDHHSS.tar.asc>

After an upgrade install of Daisy, the previous F</d/daisy> will be
left as an encrypted tar archive in F</d>.
The name of the tar archive consists of "daisy-" followed by a
date stamp followed by the suffix ".tar.asc".
The date stamp is of the form "YYYMMDDHHSS" where
"YYYY" is the 4 digit year, "MM" is the month,
"DD" is the day, "HH" is the hour, and "SS" is the seconds.
For exmple, an upgrade install of Daisy on May 10th, 2017 at 8:22am,
will have a file name of F</d/daisy-201705100822.tar.asc>.

=item F<d/tfrsync>

The top level cloud or server-to-server backup directory;
this directory will only exist if the cloud or server to server
backup package is installed.

=item F</d/daisy/log>

On a Daisy system, the location of the log files.
If this directory does not exist, the log file will be
put in F</tmp>.

=item F</d/daisy/control.dsy>

The Daisy control file.
This file contains amoung other items,
the country code and
the allowed credit card start number.

=item F</d/daisy/posctrl.pos>

The Daisy POS control file.
This file contains amoung other items,
the next ticket number.

=item F</d/daisy/crdinet.pos>

File which contains the credit card url.

=item F</d/ostools>

The OSTools directory on a Daisy system.
This directory is created when the OSTools package is installed.

=item F</d/ostools/config>

The location of the OSTools config directory for a Daisy system.

=item F</d/ostools/bin>

This directory contains the OSTools scripts.

=item F</etc/redhat-release>

This system file contains the OS version string.

=item F</etc/shells>

This file has a list of all the allowed shells on the system;
it must contain an entry for the Daisy shell.

=item F</etc/cron.d/daisy-service>

The Daisy cron job file.

=item F</etc/sysconfig/init>

This system config file contains a value for the maximum
number of allowed virtual consoles on a RHEL6 system.

=item F</etc/sysconfig/i18n>

System locale config file for "RHEL6".

=item F</etc/audit/rules.d/daisy.rules>

Config file for Daisy audit system configuration.

=item F</etc/sysconfig/network-scripts/ifcfg-eth0>

Config file for network interface;
contains setting for boot protocol.

=item F</etc/fstab>

The file system table config file.

=item F</etc/samba/smb.conf>

The Samba config file.

=back


=head1 EXIT STATUS

=over 4

=item Exit status 0 ($EXIT_OK)

Successful completion.

=item Exit status 1 ($EXIT_COMMAND_LINE)

In general, there was an issue with the syntax of the command line.

=item Exit status 2 ($EXIT_MUST_BE_ROOT)

The script must run as root or with sudo(1).

=item Exit status 3 ($EXIT_LOGFILE_SETUP)

A new empty log file could not be established.

=item Exit status 4 ($EXIT_PLATFORM)

Either the operating system is unknown or it is not one of
the supported platforms: "RHEL6" or "RHEL7".

=item Exit status 5 ($EXIT_OSTOOLSDIR)

The OSTools directory does not exist and thus OSTools must not be installed.
OSTools 1.14.0 or better required.

=item Exit status 9 ($EXIT_OS_VERSION)

Could not get the OS version string.

=item Exit status 11 ($EXIT_DAISY_VERSION)

Could not get the Daisy version string.

=item Exit status 13 ($EXIT_OSTOOLS_VERSION)

Could not get the OSTools version string.

=item Exit status 14 ($EXIT_SHOPCODE)

Could not get the Teleflora shop code.

=item Exit status 15 ($EXIT_COUNTRY_CODE)

Could not get the Daisy country code.

=item Exit status 16 ($EXIT_FLORIST_DIRECTORY_VERSION)

Could not get the Daisy florist directory version string.

=item Exit status 17 ($EXIT_TCC_VERSION)

Could not get the TCC version string.

=item Exit status 18 ($EXIT_CARD_URL)

Could not get the credit card url.

=item Exit status 19 ($EXIT_SHOPNAME)

Could not get the Teleflora shop name.

=item Exit status 20 ($EXIT_SAMBA_CONF)

Could not verify Samba config file.

=item Exit status 21 ($EXIT_SAMBA_PASSWORD)

Could not verify Samba Daisy user

=item Exit status 22 ($EXIT_CARD_START_NUMBER)

Could not report credit card start number

=item Exit status 23 ($EXIT_NEXT_TICKET_NUMBER)

Could not report the next ticket number

=item Exit status 24 ($EXIT_LARGE_FILE)

Could not read Daisy top level directory

=item Exit status 50 ($EXIT_HOSTNAME)

Could not get the system hostname.

=item Exit status 51 ($EXIT_IPADDR)

Could not determine the IP address of the default network interface.

=item Exit status 52 ($EXIT_GATEWAY_IPADDR)

Could not determine the IP address of the gateway (router).

=item Exit status 55 ($EXIT_ACCOUNT_INFO)

There is no info for given account.

=back


=head1 SEE ALSO

install-daisy.pl

