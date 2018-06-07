#!/usr/bin/perl
#
# $Revision: 1.227 $
# Copyright 2012-2017 Teleflora
#
# tfrsync.pl
#
# Script to perform backups of type server to server, server to cloud, or
# server to LUKS disk on an Teleflora RTI or Daisy POS system.
#

use strict;
use warnings;
use POSIX;
use Socket;
use Getopt::Long;
use English qw( -no_match_vars );
use Net::SMTP;
use File::Spec;
use File::Basename;
use File::Temp qw(tempfile);
use File::stat;
use File::Find;
use Sys::Hostname;
use Fcntl qw(:flock SEEK_END);

use lib qw( /teleflora/ostools/modules /d/ostools/modules /usr2/ostools/modules );
use OSTools::Platform;
use OSTools::Hardware;
use OSTools::AppEnv;
use OSTools::Filesys;


our $VERSION = 1.15;
my $CVS_REVISION = '$Revision: 1.227 $';
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
my $EXIT_ROOTDIR = 3;
my $EXIT_TOOLSDIR = 4;
my $EXIT_BACKUP_DEVICE_NOT_FOUND = 5;
my $EXIT_USB_DEVICE_NOT_FOUND = 6;
my $EXIT_BACKUP_TYPE = 7;
my $EXIT_MOUNT_ERROR = 8;
my $EXIT_RESTORE = 9;
my $EXIT_DEVICE_NOT_SPECIFIED = 10;
my $EXIT_DEVICE_VERIFY = 11;
my $EXIT_USB_DEVICE_UNSUPPORTED = 12;
my $EXIT_CRON_JOB_FILE = 13;
my $EXIT_DEF_CONFIG_FILE = 14;
my $EXIT_FORMAT = 15;
my $EXIT_LIST_UNSUP = 16;
my $EXIT_LIST = 17;
my $EXIT_SIGINT = 18;
my $EXIT_RSYNC_ACCOUNT = 19;
my $EXIT_SSH_GENERATE_KEYS = 20;
my $EXIT_SSH_GET_PUBLIC_KEY = 21;
my $EXIT_SSH_GET_PRIVATE_KEY = 22;
my $EXIT_SSH_SUDO_CONF = 23;
my $EXIT_SSH_TUNNEL_OPEN = 24;
my $EXIT_SSH_TUNNEL_CLOSE = 25;
my $EXIT_SSH_COPY_PUBLIC_KEY = 26;
my $EXIT_SSH_ID_FILE = 27;
my $EXIT_CLOUD_ACCOUNT_NAME = 29;
my $EXIT_GENERATE_PERMS = 30;
my $EXIT_UPLOAD_PERMS = 31;
my $EXIT_RESTORE_PERMS = 32;
my $EXIT_DOWNLOAD_PERMS = 33;
my $EXIT_PERM_FILE_MISSING = 34;
my $EXIT_LOCK_SETUP = 39;
my $EXIT_LOCK_ACQUISITION = 40;
my $EXIT_BACKUP_DEVICE_CONFLICT = 41;
my $EXIT_PLATFORM = 42;
my $EXIT_RSYNC_ERROR = 43;
my $EXIT_USERS_INFO_SAVE = 44;
my $EXIT_PSERVER_INFO_SAVE = 45;
my $EXIT_PSERVER_CLOISTER_FILES_SAVE = 46;
my $EXIT_XFERDIR_WRITE_ERROR = 50;
my $EXIT_XFERDIR_MKDIR = 51;
my $EXIT_XFERDIR_RMDIR = 52;
my $EXIT_INFODIR_MKDIR = 53;
my $EXIT_INFODIR_RMDIR = 54;
my $EXIT_USERSDIR_MKDIR = 55;
my $EXIT_USERSDIR_RMDIR = 56;
my $EXIT_TOP_LEVEL_MKDIR = 57;
my $EXIT_INSTALL_PSERVER_INFO_FILE = 58;
my $EXIT_DOVE_SERVER_MISSING = 59;
my $EXIT_DOVE_SERVER_SAVE_EXISTS = 60;
my $EXIT_CLOISTERDIR_MKDIR = 62;
my $EXIT_CLOISTERDIR_RMDIR = 63;
my $EXIT_RUNTIME_CLEANUP = 64;
my $EXIT_COULD_NOT_EXECUTE = 70;
my $EXIT_FROM_SIGNAL = 71;
my $EXIT_LOGFILE_SETUP = 72;
my $EXIT_NET_IPADDR = 73;
my $EXIT_NET_NETMASK = 74;
my $EXIT_NET_GATEWAY = 75;
my $EXIT_LUKS_UNUSABLE = 80;
my $EXIT_LUKS_INIT = 81;
my $EXIT_LUKS_MOUNT = 82;
my $EXIT_LUKS_UMOUNT = 83;
my $EXIT_LUKS_VERIFY = 84;
my $EXIT_LUKS_LABEL = 85;
my $EXIT_LUKS_CLOSE = 86;
my $EXIT_LUKS_ROTATE = 87;
my $EXIT_LUKS_INSTALL = 88;
my $EXIT_LUKS_BACKUP_DATE = 89;
my $EXIT_LUKS_FILE_VERIFY = 90;
my $EXIT_LUKS_FILE_RESTORE = 91;
my $EXIT_SEND_TEST_EMAIL = 92;
my $EXIT_LUKS_UUID = 93;
my $EXIT_LUKS_STATUS = 94;
my $EXIT_LUKS_GETINFO = 95;
my $EXIT_UNKNOWN = 99;

my %ExitTable = (
    $EXIT_OK => "Exit OK",
    $EXIT_COMMAND_LINE => "Command line error",
    $EXIT_MUST_BE_ROOT => "Must be root to run script",
    $EXIT_ROOTDIR => "Directory specified with --rootdir does not exist",
    $EXIT_TOOLSDIR => "OSTools directory does not exist",
    $EXIT_BACKUP_DEVICE_NOT_FOUND => "Backup device not found",
    $EXIT_USB_DEVICE_NOT_FOUND => "USB backup device not found",
    $EXIT_BACKUP_TYPE => "Unknown backup type",
    $EXIT_MOUNT_ERROR => "Error mounting backup device",
    $EXIT_RESTORE => "Restore error",
    $EXIT_DEVICE_NOT_SPECIFIED => "Backup device not specified",
    $EXIT_DEVICE_VERIFY => "Backup device can not be verified",
    $EXIT_USB_DEVICE_UNSUPPORTED => "Unsupported USB backup device",
    $EXIT_CRON_JOB_FILE => "Error installing cron job",
    $EXIT_DEF_CONFIG_FILE => "Error installing default config file",
    $EXIT_FORMAT => "Error formatting the backup device",
    $EXIT_LIST_UNSUP => "Unknown list type",
    $EXIT_LIST => "Error with list",
    $EXIT_SIGINT => "Process received signal SIGINT",
    $EXIT_RSYNC_ACCOUNT => "Error installing or removing rsync account",
    $EXIT_SSH_GENERATE_KEYS => "Error generating ssh key pair",
    $EXIT_SSH_GET_PUBLIC_KEY => "Error getting the ssh public key",
    $EXIT_SSH_GET_PRIVATE_KEY => "Error getting the private key",
    $EXIT_SSH_SUDO_CONF => "Error sudoers config file",
    $EXIT_SSH_TUNNEL_OPEN => "Error opening the ssh tunnel socket",
    $EXIT_SSH_TUNNEL_CLOSE => "Error closing the ssh tunnel socket",
    $EXIT_SSH_COPY_PUBLIC_KEY => "Error copying the public key",
    $EXIT_SSH_ID_FILE => "Error with ssh id file",
    $EXIT_CLOUD_ACCOUNT_NAME => "Error with cloud account name",
    $EXIT_GENERATE_PERMS => "Error generating perm files",
    $EXIT_UPLOAD_PERMS => "Error uploading perm files",
    $EXIT_RESTORE_PERMS => "Error restoring perm files",
    $EXIT_DOWNLOAD_PERMS => "Error downloading perm files",
    $EXIT_PERM_FILE_MISSING => "Perm file missing",
    $EXIT_LOCK_SETUP => "Error setting up process lock",
    $EXIT_LOCK_ACQUISITION => "Could not acquire process lock",
    $EXIT_BACKUP_DEVICE_CONFLICT => "Backup device conflict",
    $EXIT_PLATFORM => "Unsupported platform",
    $EXIT_RSYNC_ERROR => "Non-zero exit status from rsync command",
    $EXIT_USERS_INFO_SAVE => "Could not save users info",
    $EXIT_PSERVER_INFO_SAVE => "Could not save pserver info",
    $EXIT_PSERVER_CLOISTER_FILES_SAVE => "Cound not save pserver cloister files",
    $EXIT_XFERDIR_WRITE_ERROR => "Error writing to transfer dir",
    $EXIT_XFERDIR_MKDIR => "Error from mkdir of transfer dir",
    $EXIT_XFERDIR_RMDIR => "Error removing transfer dir",
    $EXIT_INFODIR_MKDIR => "Error from mkdir of info dir",
    $EXIT_INFODIR_RMDIR => "Error removing info dir",
    $EXIT_USERSDIR_MKDIR => "Error making users info dir",
    $EXIT_USERSDIR_RMDIR => "Error removing users info dir",
    $EXIT_TOP_LEVEL_MKDIR => "Error making top level project dir",
    $EXIT_INSTALL_PSERVER_INFO_FILE => "Could not get production server info file",
    $EXIT_DOVE_SERVER_MISSING => "Dover server script missing",
    $EXIT_DOVE_SERVER_SAVE_EXISTS => "Saved Dove server script exists",
    $EXIT_CLOISTERDIR_MKDIR => "Error making pserver cloister dir",
    $EXIT_CLOISTERDIR_RMDIR => "Error removing pserver cloister dir",
    $EXIT_RUNTIME_CLEANUP => "Could not cleanup the process lock or the SSH tunnel socket",
    $EXIT_COULD_NOT_EXECUTE => "Could not execute sub program",
    $EXIT_FROM_SIGNAL => "From signal",
    $EXIT_LOGFILE_SETUP => "Log file setup error",
    $EXIT_NET_IPADDR => "Network IP Addr error",
    $EXIT_NET_NETMASK => "Network netmask error",
    $EXIT_NET_GATEWAY => "Network gateway error",
    $EXIT_LUKS_UNUSABLE => "LUKS device unusable",
    $EXIT_LUKS_INIT => "could not init LUKS device",
    $EXIT_LUKS_MOUNT => "could not mount LUKS device",
    $EXIT_LUKS_UMOUNT => "could not mount LUKS device",
    $EXIT_LUKS_VERIFY => "could not verify LUKS device",
    $EXIT_LUKS_LABEL => "could not report file system label of LUKS device",
    $EXIT_LUKS_CLOSE => "could not close LUKS device",
    $EXIT_LUKS_ROTATE => "could not rotate buckets on LUKS device",
    $EXIT_LUKS_INSTALL => "could not install LUKS configuration",
    $EXIT_LUKS_BACKUP_DATE => "could not report LUKS device backup date",
    $EXIT_LUKS_FILE_VERIFY => "could not verify file on LUKS device",
    $EXIT_LUKS_FILE_RESTORE => "could not restore file from LUKS device",
    $EXIT_SEND_TEST_EMAIL => "could not send test email message",
    $EXIT_LUKS_UUID => "could not get UUID for LUKS device",
    $EXIT_LUKS_STATUS => "could not get status for LUKS device",
    $EXIT_LUKS_GETINFO => "could not get info for LUKS device",
    $EXIT_UNKNOWN => "Unknown reason for exit",
);


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

my @EMPTY_LIST = ();

my $SECONDS_PER_YEAR = 60 * 60 * 24 * 365;

#
# Device types are:
# 4) "image"	   - an image file
# 5) "server"      - ip address of backup server
# 6) "file system" - locally mounted file system
# 7) "block"       - either "passport", "rev", or "usb"
# 8) "show-only"   - special device, same thing as "--show-only"
# 9) "cloud"       - special device, same thing as "--cloud"
#
my $DEVTYPE_IMAGE       = 'image';
my $DEVTYPE_SERVER      = 'server';
my $DEVTYPE_FILE_SYSTEM = 'file system';
my $DEVTYPE_BLOCK       = 'block';
my $DEVTYPE_SHOW_ONLY   = 'show-only';
my $DEVTYPE_CLOUD       = 'cloud';
my $DEVTYPE_DEVICE      = 'device';
my $DEVTYPE_LUKS        = 'luks';
my $DEVTYPE_ANY         = 'any';
my $DEVTYPE_UNK         = 'unknown';

# defaults
my $DEF_PROJ_NAME = 'tfrsync';

# RTI locations
my $RTI_TOPDIR            = '/usr2';
my $RTIDIR                = "$RTI_TOPDIR/bbx";
my $RTI_BINDIR            = "$RTIDIR/bin";
my $RTI_CONFIGDIR         = "$RTIDIR/config";
my $RTI_LOGDIR            = "$RTIDIR/log";
my $RTI_TOOLSDIR          = "$RTI_TOPDIR/ostools";
my $RTI_TOOLS_BINDIR      = "$RTI_TOOLSDIR/bin";
my $RTI_SHOPCODE_FILE     = "$RTI_CONFIGDIR/dove.ini";

# Daisy locations
my $DAISY_TOPDIR          = '/d';
my $DAISYDIR              = "$DAISY_TOPDIR/daisy";
my $DAISY_BINDIR          = "$DAISYDIR/bin";
my $DAISY_CONFIGDIR       = "$DAISYDIR/config";
my $DAISY_LOGDIR          = "$DAISYDIR/log";
my $DAISY_TOOLSDIR        = "$DAISY_TOPDIR/ostools";
my $DAISY_TOOLS_BINDIR    = "$DAISY_TOOLSDIR/bin";
my $DAISY_SHOPCODE_FILE   = "$DAISYDIR/dovectrl.pos";

my $DEF_TFSUPPORT_ACCOUNT_NAME = 'tfsupport';
my $DEF_RTI_GROUP_NAME         = 'rti';
my $DEF_RTI_ADMIN_GROUP_NAME   = 'rtiadmins';
my $DEF_DAISY_GROUP_NAME       = 'daisy';
my $DEF_DAISY_ADMIN_GROUP_NAME = 'dsyadmins';

my $MOUNTPOINT      = '/mnt/backups';
my $LUKS_TIME_STAMP_FILE = 'backup_date.txt';

my $DEVICE_IMAGE_FILE_MIN = (1024 * 1024); # old style 1 megabyte

#
# there is a log file for each of the backup classes and
# the default value contains variables used with "strftime()"
# to put the day of the month and the time in the file name
# during log file setup.
#
my $DEF_RTI_LOG_DIR      = $RTI_LOGDIR;
my $DEF_DAISY_LOG_DIR    = $DAISY_LOGDIR;
# in case POS log directory does not exist
my $DEF_ALT_LOGFILE_DIR  = '/tmp';
# cloud log file name
my $DEF_LOGFILE_CLOUD    = $DEF_PROJ_NAME . '-cloud-Day_%d.log';
# server log file name
my $DEF_LOGFILE_SERVER   = $DEF_PROJ_NAME . '-server-Day_%d.log';
# device log file name
my $DEF_LOGFILE_DEVICE   = $DEF_PROJ_NAME . '-device-Day_%d.log';
# default log file name
my $DEF_LOGFILE          = $DEF_PROJ_NAME . '-Day_%d.log';
# summary log file name
my $DEF_SUMMARY_LOGFILE  = $DEF_PROJ_NAME . '-summary.log';
# debug log file name
my $DEF_DEBUG_LOGFILE    = $DEF_PROJ_NAME . '-debug.log';
# rsync stats log file name
my $DEF_RSYNC_STATS_LOG  = $DEF_PROJ_NAME . '-rsync-stats.log';

# wait this number of seconds to lock log file
my $WAIT_FOR_LOG_FILE_LOCK = 30;

# defines for summary logfile rotation
# max number of summary log files to save
my $DEF_MAX_SAVE_SUMMARY_LOG = 10;
# min number of summary log files to save
my $DEF_MIN_SAVE_SUMMARY_LOG = 3;
# summary log file rotation disabled by default
my $DEF_ROTATE_SUMMARY_LOG = 0;

my $DEF_ROOTDIR = q{/};

my $DEF_TOOLS_CONFIG_DIR_NAME  = 'config';
my $DEF_CONFIG_FILE_EXT        = '.conf';
my $DEF_CONFIG_FILENAME        = $DEF_PROJ_NAME . $DEF_CONFIG_FILE_EXT;
my $DEF_CONFIG_DIR_NAME        = $DEF_PROJ_NAME . '.d';
my $DEF_RTI_CONFIG_FILE_PATH   = "$RTI_CONFIGDIR/$DEF_CONFIG_FILENAME";
my $DEF_DAISY_CONFIG_FILE_PATH = "$DAISY_CONFIGDIR/$DEF_CONFIG_FILENAME";

my $DEF_SUDOERS_CONTENT_FILE   = $DEF_PROJ_NAME . $DEF_CONFIG_FILE_EXT;

my $DEF_RTI_RSYNC_BU_DIR   = "$RTI_TOPDIR/$DEF_PROJ_NAME";
my $DEF_DAISY_RSYNC_BU_DIR = "$DAISY_TOPDIR/$DEF_PROJ_NAME";

my $CRON_JOB_OLD           = '/etc/cron.d/nightly-backup';
my $CRON_JOB_SERVER_PATH   = "/etc/cron.d/$DEF_PROJ_NAME" . '-server';
my $CRON_JOB_CLOUD_PATH    = "/etc/cron.d/$DEF_PROJ_NAME" . '-cloud';
my $CRON_JOB_DEVICE_PATH   = "/etc/cron.d/$DEF_PROJ_NAME" . '-luks';
my $CRON_JOB_TYPE_SERVER   = $DEVTYPE_SERVER;
my $CRON_JOB_TYPE_CLOUD    = $DEVTYPE_CLOUD; 
my $CRON_JOB_TYPE_DEVICE   = $DEVTYPE_LUKS;

my @CRON_JOB_TYPES = (
    $CRON_JOB_TYPE_SERVER,
    $CRON_JOB_TYPE_CLOUD,
    $CRON_JOB_TYPE_DEVICE,
);

my $DEF_PRIMARY_SERVER = '192.168.1.21';
my $DEF_RSYNC_SERVER = '192.168.1.22';

my $DEF_RSYNC_ACCOUNT = $DEF_PROJ_NAME;
my $DEF_RSYNC_ACCOUNT_FULL_NAME = $DEF_PROJ_NAME . ' user';

# default rsync command timeout, value is in seconds.
# this value added to backups and restores via the
# rsync "--timeout" command line option.
# a value of 0 means no timeout
my $DEF_RSYNC_TIMEOUT = 600;

my $DEF_RSYNC_COMPRESSION = 0;

my $DEF_CLOUD_SERVER = 'rticloud.homelinux.com';

my $SSH_KEY_FILENAME = 'id_rsa';
my $SSH_KEY_FILENAME_PUBLIC = 'id_rsa.pub';

my $SSH_AUTH_KEYS_FILENAME = 'authorized_keys';
my $SSH_KEY_LEN = 2048;
my $SSH_KEY_TYPE = 'rsa';
my $SSH_PUBLIC_KEY_CACHEDIR = $DEF_PROJ_NAME . '_public_key';
my $DEF_SSH_SOCKET_DIR_PATH = '/var/run';
my $DEF_SSH_SOCKET_PREFIX = $DEF_PROJ_NAME . q{-};
my $DEF_SSH_SOCKET_EXT = '.socket';

# number of times to retry opening ssh tunnel
my $DEF_SSH_TUNNEL_RETRIES = 3;

my $KEY_TYPE_PRIVATE = 1;
my $KEY_TYPE_PUBLIC = $KEY_TYPE_PRIVATE + 1;

my $TELEFLORA_FS_LABEL_PATTERN = 'TFBUDSK-\d{8}';
#
# The name of the rtibackup.pl setup file - it is written to the
# backup device any time it is formatted via "--format".
#
my $FORMAT_FILE = 'teleflora-formatted.txt';

my $LOCKFILE_DIR         = '/var/lock';
my $LOCKFILE_SUFFIX      = '.lock';
my $LOCKFILE_TYPE_SERVER = $DEVTYPE_SERVER;
my $LOCKFILE_TYPE_CLOUD  = $DEVTYPE_CLOUD;
my $LOCKFILE_TYPE_DEVICE = $DEVTYPE_DEVICE;
my $LOCKFILE_TYPE_UNK    = $DEVTYPE_UNK;

my $PERM_FILE_SUFFIX = '-perms.txt';

my $RSYNCSTATS_TEMPLATE = $DEF_PROJ_NAME . '-rsyncstats-XXXXXXX';

# name of directory used to hold info to be transferred
# between production server and backup server...
my $PSERVER_XFER_DIR         = 'pserver_xfer.d';

# name of dir to hold production server info file
my $PSERVER_INFO_DIR         = 'pserver_info.d';

# name of the file to hold production server info
my $PSERVER_INFO_FILE        = 'pserver_info.txt';

# name of dir to hold the restored production server info file
my $RESTORED_PSERVER_INFO_DIR = 'restored_pserver_info.d';

# name of dir to hold backup server info files
my $BUSERVER_INFO_DIR        = 'buserver_info.d';

# name of the file to hold the backup server info
my $BUSERVER_INFO_FILE       = 'buserver_info.txt';

# name of dir to hold cloistered files
my $PSERVER_CLOISTER_DIR     = 'pserver_cloister.d';

# name of dir to hold POS users info files
my $USERS_INFO_DIR           = 'users_info.d';

my $RTI_USERS_LISTING_FILE   = 'rti_users_listing.txt';
my $RTI_USERS_SHADOW_FILE    = 'rti_users_shadow.txt';
my $DAISY_USERS_LISTING_FILE = 'daisy_users_listing.txt';
my $DAISY_USERS_SHADOW_FILE  = 'daisy_users_shadow.txt';

#
# keys for the pserver info file
#
my $SERVER_INFO_PLATFORM  = 'platform';
my $SERVER_INFO_HOSTNAME  = 'hostname';
my $SERVER_INFO_IPADDR    = 'ipaddr';
my $SERVER_INFO_NETMASK   = 'netmask';
my $SERVER_INFO_GATEWAY   = 'gateway';

# these are the supported backup methods
my @BU_METHOD_TYPES = ($DEVTYPE_CLOUD, $DEVTYPE_SERVER, $DEVTYPE_LUKS);

# these are the supported backup types
my $BU_TYPE_ALL              = 'all';
my $BU_TYPE_USR2             = 'usr2';
my $BU_TYPE_DAISY            = 'daisy';
my $BU_TYPE_PRINT_CONFIGS    = 'printconfigs';
my $BU_TYPE_RTI_CONFIGS      = 'rticonfigs';
my $BU_TYPE_DAISY_CONFIGS    = 'daisyconfigs';
my $BU_TYPE_OS_CONFIGS       = 'osconfigs';
my $BU_TYPE_NET_CONFIGS      = 'netconfigs';
my $BU_TYPE_USER_CONFIGS     = 'userconfigs';
my $BU_TYPE_USER_FILES       = 'userfiles';
my $BU_TYPE_LOG_FILES        = 'logfiles';

my $BU_TYPE_POS_USERS_INFO   = 'posusersinfo';
my $BU_TYPE_PSERVER_INFO     = 'pserverinfo';
my $BU_TYPE_PSERVER_CLOISTER = 'pservercloister';

my $BU_TYPE_BBXD             = 'bbxd';
my $BU_TYPE_BBXPS            = 'bbxps';
my $BU_TYPE_SINGLEFILE       = 'singlefile';

my $BU_TYPE_POS_LOG_FILES    = 'poslogfiles';
my $BU_TYPE_POS_SUMMARY_LOG  = 'possummarylog';

my @BACKUP_TYPES = (
    $BU_TYPE_ALL,
    $BU_TYPE_USR2,
    $BU_TYPE_DAISY,
    $BU_TYPE_PRINT_CONFIGS,
    $BU_TYPE_RTI_CONFIGS,
    $BU_TYPE_DAISY_CONFIGS,
    $BU_TYPE_OS_CONFIGS,
    $BU_TYPE_NET_CONFIGS,
    $BU_TYPE_USER_CONFIGS,
    $BU_TYPE_USER_FILES,
    $BU_TYPE_LOG_FILES,
);


#
# define a hash as a lookup table for use in verifying that a variable
# is a backup type.
#
my %IS_BACKUP_TYPE = map { ($_ => 1) } @BACKUP_TYPES;

my @BACKUP_EQUALS_ALL_BACKUP_TYPES = (
    $BU_TYPE_USR2,
    $BU_TYPE_DAISY,
    $BU_TYPE_PRINT_CONFIGS,
    $BU_TYPE_RTI_CONFIGS,
    $BU_TYPE_DAISY_CONFIGS,
    $BU_TYPE_OS_CONFIGS,
    $BU_TYPE_NET_CONFIGS,
    $BU_TYPE_USER_CONFIGS,
    $BU_TYPE_LOG_FILES,
    $BU_TYPE_USER_FILES,
    $BU_TYPE_PSERVER_CLOISTER,
    $BU_TYPE_POS_USERS_INFO,
    $BU_TYPE_PSERVER_INFO,
);

my @RESTORE_EQUALS_ALL_BACKUP_TYPES = (
    $BU_TYPE_USR2,
    $BU_TYPE_DAISY,
    $BU_TYPE_PRINT_CONFIGS,
    $BU_TYPE_RTI_CONFIGS,
    $BU_TYPE_DAISY_CONFIGS,
    $BU_TYPE_OS_CONFIGS,
    $BU_TYPE_NET_CONFIGS,
    $BU_TYPE_USER_CONFIGS,
    $BU_TYPE_USER_FILES,
    $BU_TYPE_SINGLEFILE,
    $BU_TYPE_PSERVER_CLOISTER,
);

my @UNIQUE_BACKUP_TYPES = (
    $BU_TYPE_POS_USERS_INFO,
    $BU_TYPE_PSERVER_INFO,
    $BU_TYPE_PSERVER_CLOISTER,
    $BU_TYPE_BBXD,
    $BU_TYPE_BBXPS,
    $BU_TYPE_SINGLEFILE,
);
my %IS_UNIQUE_BACKUP_TYPE = map { ($_ => 1) } @UNIQUE_BACKUP_TYPES;


#
# Special backup types are those that DO NOT get copied
# in place.
#
my @SERVER_SPECIAL_BACKUP_TYPES = (
    $BU_TYPE_NET_CONFIGS,
    $BU_TYPE_OS_CONFIGS,
    $BU_TYPE_USER_CONFIGS,
    $BU_TYPE_USER_FILES,
    $BU_TYPE_LOG_FILES,
);
my %IS_SERVER_SPECIAL_BACKUP_TYPE = map { ($_ => 1) } @SERVER_SPECIAL_BACKUP_TYPES;

my @RESTORE_TYPES = (
    @BACKUP_TYPES,
    $BU_TYPE_BBXD,
    $BU_TYPE_BBXPS,
    $BU_TYPE_SINGLEFILE,
    $BU_TYPE_PSERVER_CLOISTER,
);
#
# define a hash as a lookup table for use in verifying that a variable
# is a restore type.
#
my %IS_RESTORE_TYPE = map { ($_ => 1) } @RESTORE_TYPES;

my @LIST_ALL_BACKUP_TYPES = (
    $BU_TYPE_USR2,
    $BU_TYPE_DAISY,
    $BU_TYPE_PRINT_CONFIGS,
    $BU_TYPE_RTI_CONFIGS,
    $BU_TYPE_DAISY_CONFIGS,
    $BU_TYPE_OS_CONFIGS,
    $BU_TYPE_NET_CONFIGS,
    $BU_TYPE_USER_CONFIGS,
    $BU_TYPE_LOG_FILES,
    $BU_TYPE_USER_FILES,
    $BU_TYPE_PSERVER_CLOISTER,
);


my @DEF_BACKUP_EXCLUDES = qw(
    *.iso
    *.tar
    *.tar.gz
    *.tar.asc
    *.revision
    *.patch
    lost+found
);
my @DEF_RTI_BACKUP_EXCLUDES = qw(
    /usr2/*.iso
    /usr2/*.tar.asc
    /usr2/bbx-*
    /usr2/bbx/*.iso
    /usr2/bbx/bbxt/*
    /usr2/bbx/backups/*
    /usr2/bbx/*.tar.asc
    /usr2/bbx/bbxtmp/*
    /usr2/basis-old
    /usr2/basis/cache/*
);
my @DEF_RTI_RESTORE_EXCLUDES = qw(
    /usr2/bbx/backups/*
    /usr2/bbx/bbxtmp/*
    /usr2/bbx/log/*
    /usr2/basis/log/*
    /usr2/basis/cache/*
);

my @DEF_DAISY_BACKUP_EXCLUDES = qw(
    /d/*.iso
    /d/*.tar.asc
    /d/backup
);

#
# RTI files and directories excluded from from USR2 backup
#
my $RTI_DOVE_CMD         = "$RTI_BINDIR/doveserver.pl";
my $RTI_BASIS_CACHE_DIR  = "$RTI_TOPDIR/basis/cache";
my $RTI_DELVCONF         = "$RTIDIR/delvconf";

# "--retry-backup" cmd line options defaults
my $DEF_RETRY_BACKUP = 0;           # default policy is to not do retries
my $DEF_RETRY_BACKUP_REPS = 3;      # default number of backup retries
my $MAX_RETRY_BACKUP_REPS = 10;     # max value
my $DEF_RETRY_BACKUP_WAIT = 120;    # default seconds to wait between retries
my $MAX_RETRY_BACKUP_WAIT = 3600;   # max value = 1 hour

# network device
my $DEF_NETWORK_DEVICE = 'eth0';

# error exit status values of rsync(1)
my $RSYNC_EXIT_STATUS_PARTIAL = 23;
my $RSYNC_EXIT_STATUS_VANISHED = 24;
my $RSYNC_EXIT_STATUS_PROTOCOL_ERROR = 12;
my $RSYNC_EXIT_STATUS_TIMEOUT_ERROR = 30;
my $RSYNC_EXIT_STATUS_SSH_ERROR = 255;

# defines for LUKS devices
my $LUKS_KEY_FILE_DIR      = '/root';
my $LUKS_KEY_FILE_TEMPLATE = 'luks_key_file_XXXXXXX';

# LUKS directory names on LUKS disk device
my $LUKS_BUCKET_TODAY      = 'today';
my $LUKS_BUCKET_YESTERDAY  = 'yesterday';
my $LUKS_BUCKET_WEEKLY     = 'weekly';
my $LUKS_BUCKET_MONTHLY    = 'monthly';
my $LUKS_BUCKET_TEMP       = 'today_temp';
my $DEF_LUKS_DIR           = $LUKS_BUCKET_TODAY;
my @LUKS_DIR_NAMES = (
	$LUKS_BUCKET_TODAY,
	$LUKS_BUCKET_YESTERDAY,
	$LUKS_BUCKET_WEEKLY,
	$LUKS_BUCKET_MONTHLY,
    );
my %IS_LUKS_DIR_NAME = map { ($_ => 1) } @LUKS_DIR_NAMES;

# keys for the backup summary report
my $BU_SUMMARY_BEGIN          = 'BEGIN';
my $BU_SUMMARY_END            = 'END';
my $BU_SUMMARY_BU_RESULT      = 'BU_RESULT';
my $BU_SUMMARY_BU_RETRIES     = 'BU_RETRIES';
my $BU_SUMMARY_DEVICE_FILE    = 'DEVICE_FILE';
my $BU_SUMMARY_DEV_TYPE       = 'DEV_TYPE';
my $BU_SUMMARY_DEV_CAPACITY   = 'DEV_CAPACITY';
my $BU_SUMMARY_DEV_AVAILABLE  = 'DEV_AVAILABLE';
my $BU_SUMMARY_RSYNC_RESULT   = 'RSYNC_RESULT';
my $BU_SUMMARY_RSYNC_WARNINGS = 'RSYNC_WARNINGS';
my $BU_SUMMARY_RSYNC_SENT     = 'RSYNC_SENT';
my $BU_SUMMARY_RSYNC_SERVER   = 'RSYNC_SERVER';
my $BU_SUMMARY_RSYNC_PATH     = 'RSYNC_PATH';


############################
###                      ###
###   GLOBAL VARIABLES   ###
###                      ###
############################

my @ARGV_ORIG = @ARGV;

# logfile vars
my $LogfileDir     = $EMPTY_STR;
my $LogfileName    = $EMPTY_STR;
my $LOGFILE        = $EMPTY_STR;
my $SummaryLogfile = $EMPTY_STR;
my $DebugLogfile   = $EMPTY_STR;
my $SummaryLogMaxSave = $DEF_MAX_SAVE_SUMMARY_LOG;
my $SummaryLogMinSave = $DEF_MIN_SAVE_SUMMARY_LOG;
my $SummaryLogRotateEnabled = $DEF_ROTATE_SUMMARY_LOG;

my @USERFILES = ();

my @EXCLUDES = ();

my $EMAIL_SERVER = $EMPTY_STR;
my $EMAIL_USER = $EMPTY_STR;
my $EMAIL_PASS = $EMPTY_STR;

my $DeviceType = $EMPTY_STR;
my $DeviceDir = $EMPTY_STR;

# path to the existing ostools directory
my $ToolsDir = $EMPTY_STR;

my $ExitStatus = $EXIT_OK;

# the last exit status of the rsync command for backup operations.
my $RsyncExitStatus = 0;
# true if any rsync timeout error occurred
my $RsyncTimeoutSeen = 0;
# true if any rsync protocol error occurred
my $RsyncProtocolErrorSeen = 0;

my $RsyncStatsSent = 0;
my $RsyncStatsReceived = 0;
my $RsyncStatsRate = 0;

# list of rsync errors seen but considered only a warning
my @RsyncWarnings = ();

my $SigIntSeen = 0;

my $RetryBackupIterations = 0;

# the LUKS encryption key
my $LuksKey = $EMPTY_STR;

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

my $OS = $EMPTY_STR;

#
# The command line must be recorded before the GetOptions modules
# is called or any options will be removed.
#
my $COMMAND_LINE = get_command_line();

# command line options
my $HELP = 0;
my $CVS_VERSION = 0;
my $CONFIGFILE = $EMPTY_STR;
my $REPORT_CONFIGFILE = 0;
my $REPORT_LOGFILE = 0;
my $REPORT_DEVICE = 0;
my $REPORT_BACKUP_METHOD = 0;
my $GEN_DEF_CONFIGFILE = 0;
my $SEND_SUMMARY = 0;
my $SEND_TEST_EMAIL = 0;
my @EMAIL_RECIPIENTS = @EMPTY_LIST;
my @PRINTERS = @EMPTY_LIST;
my $FORMAT = 0;
my $INSTALL = 0;
my $UNINSTALL_PRIMARY = 0;
my $INFO_PRIMARY = 0;
my $INSTALL_SECONDARY = 0;
my $UNINSTALL_SECONDARY = 0;
my $INFO_SECONDARY = 0;
my $INSTALL_CLOUD = 0;
my $UNINSTALL_CLOUD = 0;
my $INFO_CLOUD = 0;
my $PRIMARY_SERVER = $EMPTY_STR;
my $MOUNT = 0;
my $UNMOUNT = 0;
my @BACKUP = @EMPTY_LIST;
my @RESTORE = @EMPTY_LIST;
my @RESTORE_EXCLUDES = @EMPTY_LIST;
my @SinglefilesCLO = @EMPTY_LIST;
my $RestoreUpgradeCLO = 0;
my $RootDirCLO = $DEF_ROOTDIR;
my @LIST = @EMPTY_LIST;
my $DAISY =  0;
my $RTI =  0;
my $VERBOSE = 0;
my $ForceFormatCLO = 0;
my $ForceRsyncAccountNameCLO = 0;
my $SHOW_ONLY = 0;
my $LogfileDirCLO = $EMPTY_STR;
my $CLOUD = 0;
my $CLOUD_SERVER = $DEF_CLOUD_SERVER;
my $PERMS_GENERATE = 0;
my $PERMS_UPLOAD = 0;
my $PERMS_DOWNLOAD = 0;
my $PERMS_RESTORE = 0;
my $SERVER = 0;
my $RSYNC_ACCOUNT = $EMPTY_STR;
my $RsyncServer = $EMPTY_STR;
my $RsyncDir = $EMPTY_STR;
my @RSYNC_OPTIONS = @EMPTY_LIST;
my $RSYNC_TRIAL = 0;
my $RSYNC_NICE = 1;
my $RSYNC_METADATA = 1;
my $RSYNC_COMPRESSION = $DEF_RSYNC_COMPRESSION;
my $RSYNC_TIMEOUT = $DEF_RSYNC_TIMEOUT;
my $RUNTIME_CLEANUP = 0;
my $DEVICE = $EMPTY_STR;
my $DEVICE_VENDOR = 'WD';
my $DEVICE_MODEL = 'My Passport';
my $USB_DEVICE = 0;
my $LUKS = 0;
my $LuksInstallCLO = 0;
my $LuksKeyCLO = $EMPTY_STR;
my $LuksShowKeyCLO = 0;
my $LuksValidateKeyCLO = 0;
my $LuksInitCLO = 0;
my $LuksIsLuksCLO = 0;
my $LuksVerifyCLO = 0;
my $LuksMountCLO = 0;
my $LuksUmountCLO = 0;
my $LuksLabelCLO = 0;
my $LuksUUIDCLO = 0;
my $LuksDeviceStatusCLO = 0;
my $LuksDeviceGetInfoCLO = 0;
my $LuksBucketDayCLO = 0;
my $LuksDirCLO = 'today';
my $LuksBackupDateCLO = 0;
my $LuksFileVerifyCLO = $EMPTY_STR;
my $LuksFileRestoreCLO = $EMPTY_STR;
my $NetworkDeviceCLO = $DEF_NETWORK_DEVICE;
my $GETINFO = 0;
my $DRY_RUN = 0;
my $HARDEN_LINUX = 1;
my $RetryBackupCLO = $DEF_RETRY_BACKUP;
my $RetryBackupReps = 0;
my $RetryBackupWait = 0;
my $TEST_GET_SHOPCODE = 0;
my $TEST_PROCESS_LOCK = 0;
my $TEST_NOTIFICATION_NO_BACKUP_DEVICE = 0;
my $TEST_GEN_SUMMARY_EMAIL_MSG = 0;
my $TEST_GEN_USERS_LISTING_FILE = 0;
my $TEST_GEN_USERS_SHADOW_FILE = 0;
my $TEST_RETRY_BACKUP = 0;
my $TEST_GEN_DEF_CONFIG_FILE = 0;
my $TEST_GEN_PERMFILE_LIST = 0;
my $TEST_PARSE_RSYNC_STATS = 0;
my $TEST_PARSE_RSYNC_LOG = $EMPTY_STR;
my $TEST_RSYNC_EXIT_STATUS = 0;
my $TEST_EDIT_AUTH_KEYS = 0;
my $TEST_RESTORE_UPGRADE_ADD_USERS = 0;
my $TEST_RESTORE_UPGRADE_ADJUST_USERS = 0;
my $TEST_RESTORE_UPGRADE_SAMBA_CONF = 0;
my $TEST_RESTORE_UPGRADE_SAMBA_PASSWD = 0;
my $TEST_RESTORE_UPGRADE_HOMEDIR_OWNERS = 0;
my $TEST_NOTIFICATION_EMAIL = 0;
my $DEBUGMODE = 0;

GetOptions(
	"help" => \$HELP,
	"version" => \$CVS_VERSION,
	"configfile=s" => \$CONFIGFILE,
	"report-configfile" => \$REPORT_CONFIGFILE,
	"report-logfile" => \$REPORT_LOGFILE,
	"report-device|finddev" => \$REPORT_DEVICE,
	"report-backup-method" => \$REPORT_BACKUP_METHOD,
	"gen-default-configfile" => \$GEN_DEF_CONFIGFILE,
	"send-summary" => \$SEND_SUMMARY,
	"send-test-email" => \$SEND_TEST_EMAIL,
	"email=s" => \@EMAIL_RECIPIENTS,
	"printer=s" => \@PRINTERS,
	"format" => \$FORMAT,
	"install|install-primary|install-production-server" => \$INSTALL,
	"uninstall-primary|uninstall-production-server" => \$UNINSTALL_PRIMARY,
	"info-primary|info-production-server" => \$INFO_PRIMARY,
	"install-secondary|install-backup-server" => \$INSTALL_SECONDARY,
	"uninstall-secondary|uninstall-backup-server" => \$UNINSTALL_SECONDARY,
	"info-secondary|info-backup-server" => \$INFO_SECONDARY,
	"install-cloud" => \$INSTALL_CLOUD,
	"uninstall-cloud" => \$UNINSTALL_CLOUD,
	"info-cloud" => \$INFO_CLOUD,
	"primary-server|production-server=s" => \$PRIMARY_SERVER,
	"mount" => \$MOUNT,
	"unmount|umount" => \$UNMOUNT,
	"backup=s" => \@BACKUP,
	"exclude|backup-exclude=s" => \@EXCLUDES,
	"restore=s" => \@RESTORE,
	"restore-exclude=s" => \@RESTORE_EXCLUDES,
	"restore-upgrade" => \$RestoreUpgradeCLO,
	"rootdir=s" => \$RootDirCLO,
	"list=s" => \@LIST,
	"daisy" => \$DAISY,
	"rti" => \$RTI,
	"verbose" => \$VERBOSE,
	"force-format" => \$ForceFormatCLO,
	"force-rsync-account-name" => \$ForceRsyncAccountNameCLO,
	"show-only" => \$SHOW_ONLY,
	"logfiledir=s" => \$LogfileDirCLO,
	"singlefile=s" => \@SinglefilesCLO,
	"cloud" => \$CLOUD,
	"cloud-server=s" => \$CLOUD_SERVER,
	"generate-permfiles" => \$PERMS_GENERATE,
	"upload-permfiles" => \$PERMS_UPLOAD,
	"download-permfiles" => \$PERMS_DOWNLOAD,
	"restore-from-permfiles" => \$PERMS_RESTORE,
	"server" => \$SERVER,
	"rsync-server=s" => \$RsyncServer,
	"rsync-dir=s" => \$RsyncDir,
	"rsync-account=s" => \$RSYNC_ACCOUNT,
	"rsync-trial" => \$RSYNC_TRIAL,
	"rsync-option=s" => \@RSYNC_OPTIONS,
	"rsync-nice!" => \$RSYNC_NICE,
	"rsync-metadata!" => \$RSYNC_METADATA,
	"rsync-compression" => \$RSYNC_COMPRESSION,
	"rsync-timeout=s" => \$RSYNC_TIMEOUT,
	"retry-backup" => \$RetryBackupCLO,
	"retry-reps=s" => \$RetryBackupReps,
	"retry-wait=s" => \$RetryBackupWait,
	"runtime-cleanup" => \$RUNTIME_CLEANUP,
	"device=s" => \$DEVICE,
	"device-vendor=s" => \$DEVICE_VENDOR,
	"device-model=s" => \$DEVICE_MODEL,
	"usb-device" => \$USB_DEVICE,
	"luks" => \$LUKS,
	"luks-install" => \$LuksInstallCLO,
	"luks-key=s" => \$LuksKeyCLO,
	"luks-showkey|showkey" => \$LuksShowKeyCLO,
	"luks-validate-key|validate-cryptkey" => \$LuksValidateKeyCLO,
	"luks-init" => \$LuksInitCLO,
	"luks-is-luks" => \$LuksIsLuksCLO,
	"luks-verify" => \$LuksVerifyCLO,
	"luks-mount" => \$LuksMountCLO,
	"luks-umount|luks-eject" => \$LuksUmountCLO,
	"luks-label" => \$LuksLabelCLO,
	"luks-uuid" => \$LuksUUIDCLO,
	"luks-bucket-day=s" => \$LuksBucketDayCLO,
	"luks-dir=s" => \$LuksDirCLO,
	"luks-status" => \$LuksDeviceStatusCLO,
	"luks-getinfo" => \$LuksDeviceGetInfoCLO,
	"luks-backup-date" => \$LuksBackupDateCLO,
	"luks-file-verify=s" => \$LuksFileVerifyCLO,
	"luks-file-restore=s" => \$LuksFileRestoreCLO,
	"summary-log-max-save=s" => \$SummaryLogMaxSave,
	"summary-log-min-save=s" => \$SummaryLogMinSave,
	"summary-log-rotate" => \$SummaryLogRotateEnabled,
	"network-device=s" => \$NetworkDeviceCLO,
	"dry-run" => \$DRY_RUN,
	"harden-linux!" => \$HARDEN_LINUX,
	"test-get-shopcode" => \$TEST_GET_SHOPCODE,
	"test-process-lock" => \$TEST_PROCESS_LOCK,
	"test-notify-no-backup-device" => \$TEST_NOTIFICATION_NO_BACKUP_DEVICE,
	"test-gen-summary-email-msg" => \$TEST_GEN_SUMMARY_EMAIL_MSG,
	"test-gen-users-listing-file" => \$TEST_GEN_USERS_LISTING_FILE,
	"test-gen-users-shadow-file" => \$TEST_GEN_USERS_SHADOW_FILE,
	"test-gen-permfile-list" => \$TEST_GEN_PERMFILE_LIST,
	"test-retry-backup" => \$TEST_RETRY_BACKUP,
	"test-gen-default-config-file" => \$TEST_GEN_DEF_CONFIG_FILE,
	"test-parse-rsync-stats" => \$TEST_PARSE_RSYNC_STATS,
	"test-parse-rsync-log=s" => \$TEST_PARSE_RSYNC_LOG,
	"test-rsync-exit-status" => \$TEST_RSYNC_EXIT_STATUS,
	"test-edit-auth-keys" => \$TEST_EDIT_AUTH_KEYS,
	"test-restore-upgrade-add-users" => \$TEST_RESTORE_UPGRADE_ADD_USERS,
	"test-restore-upgrade-adjust-users" => \$TEST_RESTORE_UPGRADE_ADJUST_USERS,
	"test-restore-upgrade-samba-conf" => \$TEST_RESTORE_UPGRADE_SAMBA_CONF,
	"test-restore-upgrade-samba-passwd" => \$TEST_RESTORE_UPGRADE_SAMBA_PASSWD,
	"test-restore-upgrade-homedir-owners" => \$TEST_RESTORE_UPGRADE_HOMEDIR_OWNERS,
	"test-notification-email" => \$TEST_NOTIFICATION_EMAIL,
	"debugmode" => \$DEBUGMODE,
) || die "Error: invalid command line option, exiting...\n";


# some options automatically imply --server
if ($INSTALL || $UNINSTALL_PRIMARY || $INFO_PRIMARY ||
    $UNINSTALL_SECONDARY || $INSTALL_SECONDARY || $INFO_SECONDARY) {
    $SERVER = 1;
}

# some other options automatically imply --cloud
if ($INSTALL_CLOUD || $UNINSTALL_CLOUD || $INFO_CLOUD ||
    $PERMS_GENERATE || $PERMS_UPLOAD || $PERMS_DOWNLOAD || $PERMS_RESTORE) {
    $CLOUD = 1;
}


# check command line for obviously inconsistent command line options
# and rule them out now
if (!tfr_is_cmd_line_consistent()) {
    exit($EXIT_COMMAND_LINE);
}


# --version
if ($CVS_VERSION != 0) {
    print "OSTools Version: 1.15.0\n";
    print "$PROGNAME: $CVS_REVISION\n";
    exit($EXIT_OK);
}

# --help
if ($HELP != 0) {
    usage();
    exit($EXIT_OK);
}


if ($EUID != 0) {
    print {*STDERR} "$0 must be run as root or with sudo\n";
    exit($EXIT_MUST_BE_ROOT);
}


#
# decide the application platform and set the relevant
# global vars appropriately.
#
if (!tfr_pick_rti_or_daisy()) {
    exit($EXIT_COMMAND_LINE);
}


#
# initialize log file configuration
#
if (!tfr_log_setup($LogfileDirCLO)) {
    print {*STDERR} "could not initialize log file configuration\n";
    exit($EXIT_LOGFILE_SETUP);
}


# --debug
# output extra messages if debug requested, start off
# with some info sent to debug log file
if ($DEBUGMODE) {
    debuglog("starting $PROGNAME $CVS_REVISION");
    debuglog("invoked with command line:");
    debuglog("$COMMAND_LINE");
    debuglog("CURRENT LOGFILE = <$LOGFILE>");
    debuglog("SUMMARY LOGFILE = <$SummaryLogfile>");
}

#
# convert all the command line options that are
# comma separated strings into lists.
#
my @list_cmd_line_options = (
    \@BACKUP,
    \@EXCLUDES,
    \@EMAIL_RECIPIENTS,
    \@PRINTERS,
    \@RESTORE,
    \@RESTORE_EXCLUDES,
    \@LIST,
    \@SinglefilesCLO,
    \@RSYNC_OPTIONS,
);
for my $ref (@list_cmd_line_options) {
    if (scalar(@{$ref})) {
	@{$ref} = split(/,/, join($COMMA, @{$ref}));
    }
}


#
# Check all the options that allow lists for insecure values.
#
my @options_allowing_lists = (
    ['@BACKUP', @BACKUP],
    ['@EXCLUDES', @EXCLUDES],
    ['@EMAIL_RECIPIENTS', @EMAIL_RECIPIENTS],
    ['@PRINTERS', @PRINTERS],
    ['@RESTORE', @RESTORE],
    ['@RESTORE_EXCLUDES', @RESTORE_EXCLUDES],
    ['@LIST', @LIST],
    ['@SinglefilesCLO', @SinglefilesCLO],
    ['@RSYNC_OPTIONS', @RSYNC_OPTIONS],
);

# loop through each anonymous list
for my $rec_nr (0 .. $#options_allowing_lists) {

    # each anonymous list has a least one element, the name
    my $rec_name = $options_allowing_lists[$rec_nr][0];

    # if the maximum index nr of anonymous list is 0, there is only
    # the name field
    my $max_rec_idx = $#{$options_allowing_lists[$rec_nr]};

    # loop through any elements present after the name
    for my $elem_nr (1 .. $max_rec_idx) {
	my $elem_val = $options_allowing_lists[$rec_nr][$elem_nr];
	if (is_input_insecure($elem_val)) {
	    showerror("insecure value contained in $rec_name: $elem_val");
	    shutdown_and_exit($EXIT_COMMAND_LINE);
	}
    }
}

#
# Check the values of options that allow input from user.
#
my @options_allowing_vals = (
    ['$DEVICE', $DEVICE],
    ['$DEVICE_VENDOR', $DEVICE_VENDOR],
    ['$DEVICE_MODEL', $DEVICE_MODEL],
    ['$RsyncServer', $RsyncServer],
    ['$RsyncDir', $RsyncDir],
    ['$RSYNC_ACCOUNT', $RSYNC_ACCOUNT],
    ['$RSYNC_TIMEOUT', $RSYNC_TIMEOUT],
    ['$RootDirCLO', $RootDirCLO],
    ['$PRIMARY_SERVER', $PRIMARY_SERVER],
    ['$NetworkDeviceCLO', $NetworkDeviceCLO],
    ['$RetryBackupReps', $RetryBackupReps],
    ['$RetryBackupWait', $RetryBackupWait],
    ['$LuksKeyCLO', $LuksKeyCLO],
);

# loop through each anonymous list
for my $rec_nr (0 .. $#options_allowing_vals) {

    # each anonymous list has a least one element, the name
    my $rec_name = $options_allowing_vals[$rec_nr][0];

    # get value of 2nd element
    my $rec_val = $options_allowing_vals[$rec_nr][1];

    # $NetworkDeviceCLO is not allowed to be empty
    if ($rec_name eq '$NetworkDeviceCLO' && $rec_val eq $EMPTY_STR) {
	showerror("[main] network interface device name is not allowed to be empty");
	shutdown_and_exit($EXIT_COMMAND_LINE);
    }

    # test value, empty string is considered OK... if not,
    # test before this code.
    if (is_input_insecure($rec_val)) {
	showerror("[main] insecure value contained in $rec_name: $rec_val");
	shutdown_and_exit($EXIT_COMMAND_LINE);
    }
}

# verify network interface is valid
if (verify_network_device($NetworkDeviceCLO)) {
    loginfo("[main] network interface device name verified: $NetworkDeviceCLO");
}
else {
    showerror("[main] network interface device name does not verify: $NetworkDeviceCLO");
    shutdown_and_exit($EXIT_COMMAND_LINE);
}


# verify LUKS directory name is valid
if (verify_luks_directory_name($LuksDirCLO) == 0) {
    showerror("[main] LUKS directory name does not verify: $LuksDirCLO");
    shutdown_and_exit($EXIT_COMMAND_LINE);
}


$OS = plat_os_version();
if ($OS eq $EMPTY_STR) {
	logerror("[main] unknown operating system");
	shutdown_and_exit($EXIT_PLATFORM);
}


# --rootdir=/some/path
if (!(-d $RootDirCLO)) {
	logerror("[main] directory specified with --rootdir not found: $RootDirCLO");
	shutdown_and_exit($EXIT_ROOTDIR);
}


# Where do our "OSTOOLS" typically reside?
my @ostools_dir_paths = (
    "/teleflora/ostools",
    "/usr2/ostools",
    "/d/ostools"
);

foreach my $ostools_path (@ostools_dir_paths) {
    if (-e $ostools_path) {
	$ToolsDir = $ostools_path;
	last;
    }
}

if ($ToolsDir eq $EMPTY_STR) {
    logerror("[main] ostools directory does not exist at: @ostools_dir_paths");
    shutdown_and_exit($EXIT_TOOLSDIR);
}

#
# now that the tools directory location is set, the other locations
# which depend on location of tools can be set:
#   1) path to tools config dir
#   2) path to our default config file
#   3) path to our default config dir
#   4) path to sudoers config dir
#   5) path to sudoers content config file
#
my $TOOLS_CONFIG_DIR_PATH      = File::Spec->catdir($ToolsDir, $DEF_TOOLS_CONFIG_DIR_NAME);
my $TFRSYNC_CONFIG_FILE_PATH   = File::Spec->catdir($TOOLS_CONFIG_DIR_PATH, $DEF_CONFIG_FILENAME);
my $TFRSYNC_CONFIG_DIR_PATH    = File::Spec->catdir($TOOLS_CONFIG_DIR_PATH, $DEF_CONFIG_DIR_NAME);

my $SUDOERS_CONFIG_DIR_PATH    = "$TOOLS_CONFIG_DIR_PATH/sudoers.d";
my $SUDOERS_CONTENT_FILE_PATH  = "$SUDOERS_CONFIG_DIR_PATH/$DEF_SUDOERS_CONTENT_FILE";


#
# there are some files and directories in "/usr2" that must
# not be backed up in place.  Entities on this list will be
# skipped when backing up to an rsync server.
#
my @USR2_EXCLUSIONS  = (
    # constraint            item to be excluded
    [ $DEVTYPE_CLOUD,       $RTI_DELVCONF],
    [ $DEVTYPE_SERVER,      $RTI_DOVE_CMD],
    [ $DEVTYPE_SERVER,      $DEF_RTI_RSYNC_BU_DIR],
    [ $DEVTYPE_SERVER,      $ToolsDir],
    [ $DEVTYPE_ANY,         $RTI_BASIS_CACHE_DIR],
);


####################################
###                              ###
###          MAINLINE            ###
###                              ###
####################################


my $begin_separator = $EQUALS x 40;
loginfo("| $begin_separator");
loginfo("| BEGIN Script $PROGNAME");
loginfo("| CVS Revision: $CVS_REVISION");
loginfo("| Command Line: $COMMAND_LINE");
loginfo("| $begin_separator");


####################################
###                              ###
### PROCESS COMMAND LINE OPTIONS ###
###                              ###
####################################

#
# get this out of the way first since a lot of things
# depend on it.
#
if ($SERVER) {
    $DeviceType = $DEVTYPE_SERVER;
}
if ($CLOUD) {
    $DeviceType = $DEVTYPE_CLOUD;
}
if ($LUKS) {
    $DeviceType = $DEVTYPE_LUKS;
}
#
# --device
#
# change:
#   if a device name is specified, then it implies "--luks"
#   since only LUKS devices are supported now.
#
if ($DEVICE) {
    $DeviceType = $DEVTYPE_LUKS;
}

#
# if there were any command line options specifying test functions,
# the script will exit after running the test.
#
tfr_test_functions();


#
# the rsync dir can be specified either:
#   1) as a command line option
#   2) as a command line argument
#   3) in the config file
#
# if a path is specified, but the rsync server is not, then
# do a rsync to a local file system.
#
if (defined($ARGV[0])) {
    $RsyncDir = $ARGV[0];
    if (is_input_insecure($RsyncDir)) {
	print("[main] insecure value for path specified with --rsync-dir: $RsyncDir\n");
	shutdown_and_exit($EXIT_COMMAND_LINE);
    }
}

#
# --backup=<backup_type_list>
#
# Check backup type list
#
# Check the backup types specified on the command line and
# let the user know if there is an unknown or unsupported
# backup type specified.
#
if ($#BACKUP >= 0) {
    foreach my $backup_type (@BACKUP) {
	if (! ($IS_UNIQUE_BACKUP_TYPE{$backup_type} || $IS_BACKUP_TYPE{$backup_type}) ) {
	    showerror("[main] unknown backup type specified: $backup_type");
	    shutdown_and_exit($EXIT_BACKUP_TYPE);
	}
    }
}


#
# --restore=<restore_type_list>
#
# Check restore type list
#
# Check the restore types specified on the command line and
# let the user know if there is an error.
#
if ($#RESTORE >= 0) {
    foreach my $restore_type (@RESTORE) {
	if (! $IS_RESTORE_TYPE{$restore_type}) {
	    showerror("[main] unknown restore type specified: $restore_type");
	    shutdown_and_exit($EXIT_RESTORE);
	}
    }
}


# what is the hostname?
my $Hostname = hostname();
loginfo("[main] hostname: $Hostname");

# what is the shopcode?
my $Shopcode = tfr_pos_get_shopcode();
if ($Shopcode eq $EMPTY_STR) {
    $Shopcode = '(empty)';
}
loginfo("[main] shopcode: $Shopcode");

#
# --server
#
if ($SERVER) {
    if ($RsyncServer eq $EMPTY_STR) {
	$RsyncServer = $DEF_RSYNC_SERVER;
	loginfo("[main] using default backup server: $RsyncServer");
    }
    if ($RSYNC_ACCOUNT eq $EMPTY_STR) {
	$RSYNC_ACCOUNT = $DEF_RSYNC_ACCOUNT;
	loginfo("[main] using default server account name: $RSYNC_ACCOUNT");
    }
}

#
# --cloud
#
if ($CLOUD) {
    if ($CLOUD_SERVER eq $DEF_CLOUD_SERVER) {
	loginfo("[main] using default cloud server: $CLOUD_SERVER");
    }
    if ($RSYNC_ACCOUNT) {
	if ($RSYNC_ACCOUNT eq $DEF_RSYNC_ACCOUNT) {
	    showerror("[main] cloud account name can not be the default: $DEF_RSYNC_ACCOUNT");
	    shutdown_and_exit($EXIT_CLOUD_ACCOUNT_NAME);
	}
	elsif ($RSYNC_ACCOUNT =~ m/[[:alpha:]]{1}\w*-(\d{8})/) {
	    my $shopcode_from_user = $1;
	    my $shopcode_from_pos  = tfr_pos_get_shopcode();
	    if ($shopcode_from_user eq $shopcode_from_pos) {
		loginfo("[main] using cloud account name: $RSYNC_ACCOUNT");
	    }
	    else {
		if ($ForceRsyncAccountNameCLO) {
		    loginfo("[main] using forced cloud account name: $RSYNC_ACCOUNT");
		}
		else {
		    my $answer = get_yn("shopcode mismatch - verify cloud account name: $RSYNC_ACCOUNT");
		    if ($answer) {
			loginfo("[main] using verified cloud account name: $RSYNC_ACCOUNT");
		    }
		    else {
			showerror("[main] cloud account name not verified: $RSYNC_ACCOUNT");
			shutdown_and_exit($EXIT_OK);
		    }
		}
	    }
	}
	else {
	    showerror("[main] cloud account name not of the form 'name-nnnnnnnn': $RSYNC_ACCOUNT");
	    shutdown_and_exit($EXIT_CLOUD_ACCOUNT_NAME);
	}
    }
    else {
	$RSYNC_ACCOUNT = tfr_cloud_account_name();
	if ($RSYNC_ACCOUNT) {
	    loginfo("[main] using cloud account name: $RSYNC_ACCOUNT");
	}
	else {
	    showerror("[main] could not determine cloud account name");
	    shutdown_and_exit($EXIT_CLOUD_ACCOUNT_NAME);
	}
    }
}
else {
    if ($RestoreUpgradeCLO) {
	showerror("[main] restore upgrade only allowed from cloud server");
	shutdown_and_exit($EXIT_CLOUD_ACCOUNT_NAME);
    }
}


#
# if the config file path has a non-empty value then
# it has already been set on the command line so
# check it for security issues.
#
# else if not set, then set it to the default config file path.
#
if ($CONFIGFILE) {
    if (is_input_insecure($CONFIGFILE)) {
	showerror("[main] insecure value for path to config file: $CONFIGFILE");
	shutdown_and_exit($EXIT_COMMAND_LINE);
    }
}
else {
    $CONFIGFILE = tfrm_pathto_def_tfrsync_config_file();
}


# --luks-install
if ($LuksInstallCLO) {
    my $rc = $EXIT_OK;
    if (tfr_luks_device_install()) {
	showinfo("[main] LUKS configuration installed");
    }
    else {
	showerror("[main] could not install LUKS configuration");
	$rc = $EXIT_LUKS_INSTALL;
    }
    shutdown_and_exit($rc);
}


#
# --uninstall-primary
# --uninstall-production-server
#
if ($UNINSTALL_PRIMARY) {
    shutdown_and_exit(tfr_uninstall_production_server($RSYNC_ACCOUNT, $DeviceType));
}

#
# --install
# --install-primary
# --install-production-server
#
if ($INSTALL) {
    shutdown_and_exit(tfr_install_production_server($RSYNC_ACCOUNT, $DeviceType));
}

#
# --info-primary
# --info-production-server
#
# report info about primary configuration and exit
#
if ($INFO_PRIMARY) {
    shutdown_and_exit(tfr_info_production_server($RSYNC_ACCOUNT, $DeviceType));
}

#
# --uninstall-secondary
# --uninstall-backup-server
#
if ($UNINSTALL_SECONDARY) {
    shutdown_and_exit(tfr_uninstall_backup_server($RSYNC_ACCOUNT));
}

#
# --install-secondary
# --install-backup-server
#
if ($INSTALL_SECONDARY) {
    if ($PRIMARY_SERVER eq $EMPTY_STR) {
	$PRIMARY_SERVER = $DEF_PRIMARY_SERVER;
	loginfo("[main] using default production server: $PRIMARY_SERVER");
    }

    shutdown_and_exit(tfr_install_backup_server($RSYNC_ACCOUNT, $PRIMARY_SERVER, $DeviceType));
}

#
# --info-secondary
# --info-backup-server
#
# report info about secondary configuration and exit
#
if ($INFO_SECONDARY) {
    shutdown_and_exit(tfr_info_backup_server($RSYNC_ACCOUNT));
}

#
# --uninstall-cloud
#
if ($UNINSTALL_CLOUD) {
    shutdown_and_exit(tfr_uninstall_production_server($RSYNC_ACCOUNT, $DeviceType));
}

#
# --install-cloud
#
if ($INSTALL_CLOUD) {
    my $rc = tfr_install_production_server($RSYNC_ACCOUNT, $DeviceType);
    if ($rc == $EXIT_OK) {
	my @platform_bu_types = tfr_get_platform_bu_types(@BACKUP_TYPES);
	$rc = tfr_generate_perm_files(@platform_bu_types);
    }

    shutdown_and_exit($rc);
}

#
# --info-cloud
#
# report info about cloud configuration and exit
#
if ($INFO_CLOUD) {
    shutdown_and_exit(tfr_info_cloud($RSYNC_ACCOUNT, $DeviceType));
}

#
# --generate-permfiles
#
# generate perm files for all backup types
#
if ($PERMS_GENERATE) {
    my @platform_bu_types = tfr_get_platform_bu_types(@BACKUP_TYPES);
    shutdown_and_exit(tfr_generate_perm_files(@platform_bu_types));
}

#
# --upload-permfiles
#
# upload set of existing perm files to the cloud server
#
if ($PERMS_UPLOAD) {
    shutdown_and_exit(tfr_upload_perm_files($RSYNC_ACCOUNT, $CLOUD_SERVER));
}

#
# --download-permfiles
#
# download existing set of perm files from the cloud server.
#
if ($PERMS_DOWNLOAD) {
    my @platform_bu_types = tfr_get_platform_bu_types(@BACKUP_TYPES);
    shutdown_and_exit(tfr_download_perm_files($RSYNC_ACCOUNT, $CLOUD_SERVER, @platform_bu_types));
}

#
# --restore-from-permfiles
#
# restore the perms from a set of perm files
#
if ($PERMS_RESTORE) {
    my @platform_bu_types = tfr_get_platform_bu_types(@BACKUP_TYPES);
    shutdown_and_exit(tfr_restore_from_perm_files($RSYNC_ACCOUNT, $CLOUD_SERVER, @platform_bu_types));
}


#
# "it was decided" that the config file values takes precedence
# over command line values.  Thus, this is the point that the
# config file can be read.
#
# read the configuration file(s)
#
my $ConfigFilePath = tfrm_pathto_config_file();
my $ConfigFileCount = tfr_read_configuration($ConfigFilePath);
if ($VERBOSE) {
    showinfo("[main] number of conf files read: $ConfigFileCount");
}


#
# --report-configfile
#
# report only, then exit
#
if ($REPORT_CONFIGFILE) {
    shutdown_and_exit($EXIT_OK);
}

#
# --gen-configfile
#
# generate and install a default config file
#
if ($GEN_DEF_CONFIGFILE) {
    my $config_file_path = tfrm_pathto_def_tfrsync_config_file();
    my $rc = $EXIT_OK;

    my $installed_config_file_path = tfr_install_default_config_file($config_file_path);
    if ($installed_config_file_path) {
	showinfo("[main] default config file generated: $installed_config_file_path");
    }
    else {
	showerror("[main] could not generate default config file: $config_file_path");
	$rc = $EXIT_DEF_CONFIG_FILE;
    }

    shutdown_and_exit($rc);
}


#
# --send-test-email
#
if ($SEND_TEST_EMAIL) {
    exit(tfr_send_test_email());
}


if ($SummaryLogMinSave < $DEF_MIN_SAVE_SUMMARY_LOG) {
    showerror("[main] min saved summary log files must be >= $DEF_MIN_SAVE_SUMMARY_LOG: $SummaryLogMinSave");
    shutdown_and_exit($EXIT_COMMAND_LINE);
}
if ($SummaryLogMaxSave < $SummaryLogMinSave) {
    showerror("[main] max saved summary log files must be >= $SummaryLogMinSave: $SummaryLogMaxSave");
    shutdown_and_exit($EXIT_COMMAND_LINE);
}

#
# if "--retry-backup" is specified, then check the range of values for
# "--retry-reps" and "--retry-wait".  If their values are 0, set them
# to default values and log values.
#
if ($RetryBackupCLO) {
    if ( ($RetryBackupReps < 0) || ($RetryBackupReps > $MAX_RETRY_BACKUP_REPS) ) {
	showerror("[main] backup retry reps must be >= 0 and <= $MAX_RETRY_BACKUP_REPS: $RetryBackupReps");
	shutdown_and_exit($EXIT_COMMAND_LINE);
    }
    if ( ($RetryBackupWait < 0) || ($RetryBackupWait > $MAX_RETRY_BACKUP_WAIT) ) {
	showerror("[main] backup retry wait must be >= 0 and <= $MAX_RETRY_BACKUP_WAIT: $RetryBackupWait");
	shutdown_and_exit($EXIT_COMMAND_LINE);
    }

    if ($RetryBackupReps == 0) {
	$RetryBackupReps = $DEF_RETRY_BACKUP_REPS;
    }
    loginfo("[main] backup retries set to: $RetryBackupReps");

    if ($RetryBackupWait == 0) {
	$RetryBackupWait = $DEF_RETRY_BACKUP_WAIT;
    }
    loginfo("[main] backup wait set to: $RetryBackupWait");
}
# if "--retry-backup" is not specified, then set the reps to 1 and
# the wait to 0 so other code can use these values.
else {
    $RetryBackupReps = 1;
    $RetryBackupWait = 0;
}


#
# some command line consistency checking
#
if ($DEVICE && $SERVER) {
    showerror("[main] --server and --device=path are mutually exclusive");
    shutdown_and_exit($EXIT_COMMAND_LINE);
}

if ($DEVICE && $CLOUD) {
    showerror("[main] --cloud and --device=path are mutually exclusive");
    shutdown_and_exit($EXIT_COMMAND_LINE);
}

if ($DEVICE || $USB_DEVICE) {
    my $device_str = ($DEVICE) ? "--device" : "--usb-device";
    if ($RsyncDir) {
	showerror("[main] $device_str and --rsync-dir mutually exclusive");
	shutdown_and_exit($EXIT_BACKUP_DEVICE_CONFLICT);
    }
}


#
# --report-logfile
#
# report only, then exit
#
if ($REPORT_LOGFILE) {
    print "logfile: $LOGFILE\n";
    shutdown_and_exit($EXIT_OK);
}

#
# --report-backup-method
#
if ($REPORT_BACKUP_METHOD) {
    foreach my $bu_method (@BU_METHOD_TYPES) {
	my $account_name = $EMPTY_STR;
	if ($bu_method eq $DEVTYPE_SERVER) {
	    $account_name = $DEF_RSYNC_ACCOUNT;
	}
	if ($bu_method eq $DEVTYPE_CLOUD) {
	    $account_name = tfr_cloud_account_name();
	}
	my $report_status =
	    (tfr_backup_method_report($bu_method, $account_name)) ? 'installed' : 'not installed';
	showinfo("[main] $bu_method installation: $report_status");
    }
    shutdown_and_exit($EXIT_OK);
}


#
# --runtime-cleanup
#
# cleanup the process lock file and the ssh tunnel socket.
#
if ($RUNTIME_CLEANUP) {
    if ($SERVER || $CLOUD || $DEVICE) {
	shutdown_and_exit(tfr_runtime_cleanup());
    }
    else {
	showerror("[main] --server or --cloud or --device=path must be specified with --runtime-cleanup");
	shutdown_and_exit($EXIT_COMMAND_LINE);
    }
}


#
# --finddev | --report-device
#
if ($REPORT_DEVICE) {
    shutdown_and_exit(tfr_finddev());
}

#
# if not doing a cloud backup or a server backup and
# a rsync destination path IS specified, it's a copy
# to a local file system so make sure that the
# destination exists.
#
if (! ($CLOUD || $SERVER) ) {
    if ($RsyncDir) {
	if (-d $RsyncDir) {
	    $DeviceType = $DEVTYPE_FILE_SYSTEM;
	    loginfo("[main] backup to local filesystem: $RsyncDir");
	}
	else {
	    showerror("[main] destination directory does not exist: $RsyncDir");
	    shutdown_and_exit($EXIT_COMMAND_LINE);
	}
    }
}

#
# --usb-device
#
# If specifed, either find and verify a USB device, or exit.
#
if ($USB_DEVICE) {
    $DEVICE = tfr_find_usb_device();
    if ($DEVICE) {
	if (tfr_device_is_verified($DEVICE)) {
	    $DeviceType = $DEVTYPE_LUKS;
	}
	else {
	    showerror("[main] could not verify USB device: $DEVICE");
	    shutdown_and_exit($EXIT_DEVICE_VERIFY);
	}
    }
    else {
	showerror("[main] could not find USB backup device");
	shutdown_and_exit($EXIT_USB_DEVICE_NOT_FOUND);
    }
}


#
# --device=path
#
# If the backup device is an image file, make sure that it exists and
# is at least $DEVICE_IMAGE_SIZE in size - arbitrary yes, but at least
# some measure of defense.
#
if ($DEVICE) {
    if ($DEVICE eq $DEVTYPE_SHOW_ONLY) {
	$DeviceType = $DEVTYPE_SHOW_ONLY;
    }
    elsif (-f $DEVICE) {
	$DeviceType = $DEVTYPE_IMAGE;
    }
    elsif (-b $DEVICE) {
	if ($DeviceType eq $EMPTY_STR) {
	    $DeviceType = $DEVTYPE_LUKS;
	}
    }
    else {
	if (! tfr_device_is_verified($DEVICE)) {
	    logerror("[main] backup device verification error for: $DEVICE");
	    shutdown_and_exit($EXIT_DEVICE_VERIFY);
	}
    }
}

#
# If at this point the user hasn't specified an rsync to a
# backup server or to a local file system or to the cloud or
# explicity to a backup device, then look for a WD Passport.
#
else {
    if (! ($SERVER || $RsyncDir || $CLOUD) ) {
	$DEVICE = tfr_find_passport();
	if ($DEVICE ne $EMPTY_STR) {
	    $DeviceType = $DEVTYPE_LUKS;
	}
	else {
	    $DEVICE = tfr_find_usb_device();
	    if ($DEVICE ne $EMPTY_STR) {
		$DeviceType = $DEVTYPE_LUKS;
	    }
	    else {
		showerror("[main] could not find backup device");
		shutdown_and_exit($EXIT_COMMAND_LINE);
	    }
	}
    }
}

if ($DeviceType eq $DEVTYPE_LUKS) {
    $LUKS = 1;
}

#
# [--luks-validate-key | --validate-cryptkey] (--luks-key=s)
#
# validate the encryption key
#
if ($LuksValidateKeyCLO) {
    my $crypt_key = tfr_luks_device_set_key($LuksKeyCLO);
    if (tfr_luks_device_mount($DEVICE)) {
	tfr_luks_device_umount($DEVICE);
	showinfo("[main] encryption key is valid");
    }
    else {
	showerror("[main] encryption key is invalid");
    }
    shutdown_and_exit($EXIT_OK);
}

#
# --luks-showkey | --showkey
#
if ($LuksShowKeyCLO) {
    my $crypt_key = tfr_luks_device_set_key($LuksKeyCLO);
    showinfo("LUKS backup device key: $crypt_key");
    shutdown_and_exit($EXIT_OK);
}

#
# --luks-getinfo
#
if ($LuksDeviceGetInfoCLO && $DEVICE) {
    my $rc = $EXIT_OK;
    showinfo("Backup type: $DeviceType");
    showinfo("Backup block device name: $DEVICE");
    my $luks_name = tfr_luks_device_get_name($DEVICE);
    if ($luks_name) {
	showinfo("Backup LUKS device name: $luks_name");
	tfr_luks_device_set_key($LuksKeyCLO);
	if (tfr_luks_device_mount($DEVICE)) {
	    my $free_space = get_free_space($MOUNTPOINT);
	    showinfo("Backup LUKS device mount point: $MOUNTPOINT");
	    showinfo("Backup LUKS device free space: $free_space bytes");
	    tfr_luks_device_umount($DEVICE);
	}
	else {
	    showerror("[main] could not mount LUKS device: $DEVICE");
	    $rc = $EXIT_LUKS_GETINFO;
	}
    }
    else {
	showerror("[main] could not get name of LUKS device: $DEVICE");
	$rc = $EXIT_LUKS_GETINFO;
    }
    shutdown_and_exit($rc);
}

#
# At this point, assert there is some backup device or
# it's an error.
#
if ($SERVER) {
    showinfo("[main] using backup server: $RsyncServer");
}
elsif ($RsyncDir) {
    showinfo("[main] using local file system at path: $RsyncDir");
}
elsif ($DeviceType eq $DEVTYPE_SHOW_ONLY) {
    showinfo("[main] using special backup device: $DEVICE");
}
elsif (-f $DEVICE) {
    showinfo("[main] using backup image file: $DEVICE");
}
elsif (-b $DEVICE) {
    showinfo("[main] using backup device: $DEVICE");
}
elsif ($CLOUD) {
    showinfo("[main] using cloud backup");
}
else {
    # If at this point the device is still unknown, and there are
    # one or more backup sets specified, then send notifications.
    showerror("[main] no backup device found");
    if ($#BACKUP >= 0) {
	tfr_notification_no_backup_device();
    }
    shutdown_and_exit($EXIT_BACKUP_DEVICE_NOT_FOUND);
}


#
# doesn't make any sense to specify luks key if
# the device type is not luks, but it's not going
# to be an error (Postel's Law of Robustness:
# "be conservative in what you do, be liberal
# in what you accept")
#
if ($DeviceType eq $DEVTYPE_LUKS) {
    tfr_luks_device_set_key($LuksKeyCLO);
    $DeviceDir = File::Spec->catdir($MOUNTPOINT,  $LUKS_BUCKET_TODAY);
}
else {
    if ($LuksKeyCLO) {
	loginfo("[main] specified LUKS key ignored for non-LUKS device type: $DeviceType");
    }
    $DeviceDir = $MOUNTPOINT;
}


#
#if ($DEVICE) {
#    if (tfr_luks_device_close()) {
#	showerror("[main] could not close LUKS device");
#	shutdown_and_exit($EXIT_LUKS_CLOSE);
#    }
#}


#
# --getinfo
#
if ($GETINFO) {
    if ($RsyncServer || ($RsyncServer eq $EMPTY_STR && $RsyncDir)) {
	showinfo("[main] the --getinfo option does not apply to rsync servers or file systems");
    }
    else {
	get_backup_device_info($DEVICE, $MOUNTPOINT);
    }

    shutdown_and_exit($EXIT_OK);
}


# --luks-init
if ($LuksInitCLO) {
    my $rc = $EXIT_OK;
    if (tfr_luks_device_initialize($DEVICE)) {
	showinfo("[main] LUKS device initialized: $DEVICE");
    }
    else {
	showerror("[main] could not initialize LUKS device: $DEVICE");
	$rc = $EXIT_LUKS_INIT;
    }
    shutdown_and_exit($rc);
}

# --luks-is-luks
if ($LuksIsLuksCLO) {
    my $rc = $EXIT_OK;
    if (tfr_luks_device_is_luks($DEVICE)) {
	showinfo("[main] is a LUKS device: $DEVICE");
    }
    else {
	showinfo("[main] not a LUKS device: $DEVICE");
    }
    shutdown_and_exit($rc);
}

# --luks-status
if ($LuksDeviceStatusCLO) {
    my $rc = $EXIT_OK;
    if (tfr_luks_device_get_status($DEVICE)) {
	loginfo("[main] LUKS device status: $DEVICE");
    }
    else {
	showerror("[main] could not get status for LUKS device: $DEVICE");
	$rc = $EXIT_LUKS_STATUS;
    }
    shutdown_and_exit($rc);
}

# --luks-verify
if ($LuksVerifyCLO) {
    my $rc = $EXIT_OK;
    if (tfr_luks_device_verify($DEVICE)) {
	showinfo("[main] LUKS device verified: $DEVICE");
    }
    else {
	showinfo("[main] not a LUKS device: $DEVICE");
    }
    shutdown_and_exit($rc);
}

# --luks-mount
if ($LuksMountCLO) {
    my $rc = $EXIT_OK;
    if (tfr_luks_device_mount($DEVICE)) {
	showinfo("[main] LUKS device mounted: $DEVICE");
    }
    else {
	showerror("[main] could not mount LUKS device: $DEVICE");
	$rc = $EXIT_LUKS_MOUNT;
    }
    shutdown_and_exit($rc);
}

# --luks-umount
if ($LuksUmountCLO) {
    my $rc = $EXIT_OK;
    if (tfr_luks_device_umount($DEVICE)) {
	showinfo("[main] LUKS device umounted: $DEVICE");
    }
    else {
	showerror("[main] could not umount LUKS device: $DEVICE");
	$rc = $EXIT_LUKS_UMOUNT;
    }
    shutdown_and_exit($rc);
}

# --luks-label
if ($LuksLabelCLO) {
    my $rc = $EXIT_OK;
    if (tfr_luks_device_report_label($DEVICE)) {
	loginfo("[main] successful report of file system label on LUKS device: $DEVICE");
    }
    else {
	showerror("[main] could not report file system label on LUKS device: $DEVICE");
	$rc = $EXIT_LUKS_LABEL;
    }
    shutdown_and_exit($rc);
}

# --luks-uuid
if ($LuksUUIDCLO) {
    my $rc = $EXIT_OK;
    my $luks_uuid = tfr_luks_device_get_uuid($DEVICE);
    if ($luks_uuid) {
	print "LUKS device UUID: $luks_uuid\n";
	loginfo("[main] successful report of UUID of LUKS device: $DEVICE");
    }
    else {
	showerror("[main] could not get UUID of LUKS device: $DEVICE");
	$rc = $EXIT_LUKS_LABEL;
    }
    shutdown_and_exit($rc);
}

# --luks-backup-date
if ($LuksBackupDateCLO) {
    my $rc = $EXIT_OK;
    if (tfr_luks_device_get_backup_date($DEVICE)) {
	loginfo("[main] successful report of LUKS device backup date: $DEVICE");
    }
    else {
	showerror("[main] could not report LUKS device backup date: $DEVICE");
	$rc = $EXIT_LUKS_BACKUP_DATE;
    }
    shutdown_and_exit($rc);
}

# --luks-file-verify
if ($LuksFileVerifyCLO) {
    my $rc = $EXIT_OK;
    my $luks_device = $DEVICE;
    my $luks_bucket = $LuksDirCLO;
    my $file = $LuksFileVerifyCLO;
    if (tfr_luks_device_file_verify($luks_device, $luks_bucket, $file)) {
	loginfo("[main] successful file verification on LUKS device: $DEVICE");
    }
    else {
	showerror("[main] could not verify file on LUKS device: $DEVICE");
	$rc = $EXIT_LUKS_FILE_VERIFY;
    }
    shutdown_and_exit($rc);
}


#
# --luks-file-restore=path
#
# "path" may be a regular expression.
#
# search for "path" on the LUKS backup device, which searches
# the default directory of "/mnt/backups/today" unless the
# "--luks-dir=s" was also specified, then the search is done
# from the specified "bucket".
#
if ($LuksFileRestoreCLO) {
    my $rc = $EXIT_OK;
    my $luks_device = $DEVICE;
    my $luks_bucket = $LuksDirCLO;
    my $src_file = $LuksFileRestoreCLO;
    my $dst_path = $RootDirCLO;

    if (tfr_luks_device_file_restore($luks_device, $luks_bucket, $src_file, $dst_path)) {
	loginfo("[main] successful file restore from LUKS device: $DEVICE");
    }
    else {
	showerror("[main] could not restore file from LUKS device: $DEVICE");
	$rc = $EXIT_LUKS_FILE_RESTORE;
    }
    shutdown_and_exit($rc);
}


# --mount
if ($MOUNT) {
    my $rc = $EXIT_OK;
    if ($DEVICE) {
	mount_device("rw");
    }
    else {
	showerror("[main] backup device not specified");
	$rc = $EXIT_DEVICE_NOT_SPECIFIED;
    }

    shutdown_and_exit($rc);
}


# --unmount
# --umount
if ($UNMOUNT) {
    my $rc = $EXIT_OK;
    if ($DEVICE) {
	unmount_device();
    }
    else {
	showerror("[main] backup device not specified");
	$rc = $EXIT_DEVICE_NOT_SPECIFIED;
    }

    shutdown_and_exit($rc);
}


# --format
if ($FORMAT) {
    # unless "--force-format" is also specified, verify format with "yes/no"
    if ($ForceFormatCLO eq $EMPTY_STR) {
	if (! get_yn("Format backup device: $DEVICE")) {
	    shutdown_and_exit($EXIT_OK);
	}
    }

    my $rc = tfr_device_format_ext2($DEVICE, $DeviceType);
    if ($rc == 0) {
	showinfo("[main] device formatted: $DEVICE");
	$rc = $EXIT_OK;
    }
    else {
	showerror("[main] format failed: $DEVICE");
	$rc = $EXIT_FORMAT;
    }

    shutdown_and_exit($rc);
}


#=======================================================================
# setup the interrupt signal handler
# ----------------------------------
#
# catch interrupt signal in order to exit cleanly.
#
#=======================================================================
tfr_set_sigint_handler();


#
# --list
#
if ($#LIST >= 0) {

    if ($CLOUD) {
	showerror("[main] the --cloud option may not be used with --list option");
	shutdown_and_exit($EXIT_COMMAND_LINE);
    }

    #
    # Compare the backup types to the list that was specified on the command line and
    # let the user know if there is an unknown backup type.
    #
    for my $backup_type (@LIST) {
	if (! $IS_BACKUP_TYPE{$backup_type}) {
	    showerror("[main] unsupported list type specified: $backup_type");
	    shutdown_and_exit($EXIT_LIST_UNSUP);
	}
    }
    if (tfr_list_files(\@LIST, $DeviceType)) {
	shutdown_and_exit($EXIT_OK);
    }
    else {
	logerror("[main] error while listing files");
	shutdown_and_exit($EXIT_LIST);
    }
}

#=======================================================================
# attempt to obtain a process lock
# --------------------------------
#
# If a process lock can not be obtained, will not return, will just
# clean up and exit.
#
# If "--dry-run" specified, will return without getting process lock.
#
#=======================================================================
tfr_process_lock_obtain();

loginfo("[main] process lock obtained");

#
# --backup
#
if ($#BACKUP >= 0) {

    if ($DEBUGMODE) {
	push(@BACKUP, "specialfiles");
    }

    my %dev_attributes = (
	DEVICE  => $DEVICE,
	DEVTYPE => $DeviceType,
	DEVDIR  => $DeviceDir,
    );

    if ($CLOUD) {
	$dev_attributes{DESTINATION} = $CLOUD_SERVER;
    }
    elsif ($SERVER) {
	$dev_attributes{DESTINATION} = $RsyncServer;
    }
    elsif ($DEVICE) {
	$dev_attributes{DESTINATION} = $DEVICE;
    }
    else {
	$dev_attributes{DESTINATION} = 'Unknown';
    }

    my %bu_attributes = (
	BU_SETS     => \@BACKUP,
	BU_EXCLUDES => \@EXCLUDES,
	BU_TYPE     => $EMPTY_STR,
    );

    loginfo("[main] begin --backup");

    my $backup_returnval = tfr_backup(\%bu_attributes, \%dev_attributes);

    if (tfr_process_lock_release()) {
	loginfo("[main] process lock released");
    }

    $ExitStatus = $backup_returnval;
}


#
# --restore
#
if ($#RESTORE >= 0) {
    # if RTI and restoring "in place", then exclude these:
    if ($RTI && is_restore_in_place()) {
	push(@RESTORE_EXCLUDES, @DEF_RTI_RESTORE_EXCLUDES);
    }

    my $rc = tfr_restore_files(\@RESTORE, \@RESTORE_EXCLUDES, $RootDirCLO);
    if ($rc == 0) {
	if ($RUN_RTI_PERMS) {
	    set_rti_perms();
	}
	if ($RUN_DAISY_PERMS) {
	    tfr_daisy_set_perms();
	}
	if ($HARDEN_LINUX && $RUN_HARDEN_LINUX) {
	    run_harden_linux();
	}
    }
    else {
	print STDERR "[main] the --restore option reported errors - please check log file\n";
	$ExitStatus = $EXIT_RESTORE;
    }

    if (tfr_process_lock_release()) {
	loginfo("[main] process lock released");
    }
}

loginfo("END MAINLINE: $PROGNAME");

if (! tfr_log_conclude()) {
    print {*STDERR} "[main] could not conclude log file operations\n";
}


exit($ExitStatus);

#####################################################################
#####################################################################
#####################################################################


sub usage
{
    print("$PROGNAME $CVS_REVISION\n");
    print("\n");
    print("For full documenation, enter the command:  perldoc $0\n");
    print("\n");

    print("SYNOPSIS\n");
    print("$PROGNAME --help\n");
    print("$PROGNAME --version\n");
    print("\n");

    print("$PROGNAME --install-production-server (--server | --cloud) [--rsync-account=name]\n");
    print("$PROGNAME --uninstall-production-server [--rsync-account=name]\n");
    print("$PROGNAME --info-production-server [--rsync-account=name]\n");
    print("$PROGNAME --install-backup-server [--production-server=addr] [--rsync-account=name]\n");
    print("$PROGNAME --uninstall-backup-server [--rsync-account=name]\n");
    print("$PROGNAME --info-backup-server [--rsync-account=name]\n");
    print("$PROGNAME --install-cloud [--cloud-server=addr] [---rsync-account=name]\n");
    print("$PROGNAME --uninstall-cloud [--cloud-server=addr] [---rsync-account=name]\n");
    print("$PROGNAME --generate-permfiles\n");
    print("$PROGNAME --upload-permfiles [--cloud-server=addr] [--rsync-account=name]\n");
    print("$PROGNAME --download-permfiles [--cloud-server=addr] [--rsync-account=name]\n");
    print("$PROGNAME --restore-from-permfiles [--cloud-server=addr] [--rsync-account=name]\n");
    print("$PROGNAME --backup=<list> [--device=s] [--luks] [--luks-key=string]\n");
    print("$PROGNAME --backup=<list> --cloud [--cloud-server=addr] [--rsync-account=name]\n");
    print("$PROGNAME --backup=<list> --server [--rsync-server=addr] [--rsync-account=name]\n");
    print("\twhere <list> is one or more of the following comma separated types:\n");
    my @backup_types = @BACKUP_TYPES;
    push(@backup_types, @UNIQUE_BACKUP_TYPES);
    tfr_print_array(\@backup_types, "\t", $COMMA, 6);
    print("$PROGNAME --restore=<list> --cloud [--cloud-server=addr] [--rsync-account=name]\n");
    print("$PROGNAME --restore=<list> --server [--rsync-server=addr] [--rsync-account=name]\n");
    print("\twhere <list> is one or more of the following comma separated types:\n");
    tfr_print_array(\@RESTORE_TYPES, "\t", $COMMA, 6);
    print("$PROGNAME --list=<list>\n");
    print("\twhere <list> is one or more of the following comma separated types:\n");
    tfr_print_array(\@backup_types, "\t", $COMMA, 6);
    print("\n");

    print("$PROGNAME --mount [--device]\n");
    print("$PROGNAME --unmount [--device]\n");
    print("$PROGNAME --report-configfile\n");
    print("$PROGNAME --report-logfile\n");
    print("$PROGNAME --report-device\n");
    print("$PROGNAME --report-backup-method\n");
    print("$PROGNAME --gen-configfile\n");
    print("$PROGNAME --format [--force-format]\n");
    print("$PROGNAME --runtime-cleanup (--server | --cloud)\n");
    print("$PROGNAME --send-test-email\n");
    print("$PROGNAME --finddev\n");
    print("$PROGNAME --showkey\n");
    print("$PROGNAME --validate-cryptkey\n");
    print("\n");

    print("DEFAULTS\n");
    print("The default production server address: $DEF_PRIMARY_SERVER\n");
    print("The default server account name: $DEF_RSYNC_ACCOUNT\n");
    print("The default cloud server name: $DEF_CLOUD_SERVER\n");
    print("The default cloud account name: 'tfrsync-nnnnnnnn' where nnnnnnnn = shopcode\n");
    print("\n");

    print("OPTIONS for '--backup'\n");
    print("--cloud\n");
    print("--cloud-server=(FQDN | ipaddr)\n");
    print("--server\n");
    print("--rsync-server=(hostname | ipaddr)\n");
    print("--rsync-account=name\n");
    print("--force-rsync-account-name\n");
    print("--rsync-dir=path\n");
    print("--rsync-option=string\n");
    print("--rsync-timeout=secs\n");
    print("--[no]rsync-nice\n");
    print("--rsync-trial\n");
    print("--rsync-compression\n");
    print("--force-rsync-account-name\n");
    print("--retry-backup\n");
    print("--retry-reps=number\n");
    print("--retry-wait=seconds\n");
    print("--network-device=s\n");
    print("--send-summary\n");
    print("--singlefile=<list>      where <list> is one or more comma separated paths\n");
    print("--backup-exclude=<list>  where <list> is one or more comma separated paths\n");
    print("--email=<list>           where <list> is one or more comma separated email addresses\n");
    print("--printer=<list>         where <list> is 1 or more comma separated printer names\n");
    print("--rootdir=<path>         where <path> is the path to an existing directory\n");
    print("--show-only              only show the filenames to backup, do not perform back up\n");
    print("\n");

    print("DEFAULTS\n");
    print("The default rsync timeout: $DEF_RSYNC_TIMEOUT seconds, 0 means no timeout\n");
    print("The default rsync compression: " . (($DEF_RSYNC_COMPRESSION) ? "yes" : "no") . "\n");
    print("The default backup retry policy: " . (($DEF_RETRY_BACKUP) ? "do retries" : "no retries") . "\n");
    print("The default number of backup retries: $DEF_RETRY_BACKUP_REPS\n");
    print("The max value for number of backup retries: $MAX_RETRY_BACKUP_REPS\n");
    print("The default backup retry wait (seconds): $DEF_RETRY_BACKUP_WAIT\n");
    print("The max value for backup retry wait (seconds): $MAX_RETRY_BACKUP_WAIT\n");
    print("The default number of ssh open retries: $DEF_SSH_TUNNEL_RETRIES\n");
    print("The default network interface device name: $DEF_NETWORK_DEVICE\n");
    print("The default backup excludes:\n");
    tfr_print_array(\@DEF_BACKUP_EXCLUDES, "\t", $COMMA, 5);
    print("The default RTI backup excludes:\n");
    tfr_print_array(\@DEF_RTI_BACKUP_EXCLUDES, "\t", $COMMA, 5);
    print("The default RTI usr2 backup excludes for backup class \"cloud\":\n");
    print "\t$RTI_DELVCONF\n";
    print("The default RTI usr2 backup excludes for backup class \"server\":\n");
    print "\t$RTI_DOVE_CMD, $DEF_RTI_RSYNC_BU_DIR, $RTI_TOOLSDIR\n";
    print("The default Daisy backup excludes:\n");
    tfr_print_array(\@DEF_DAISY_BACKUP_EXCLUDES, "\t", $COMMA, 5);
    print("\n");

    print("OPTIONS for '--restore'\n");
    print("--restore-exclude=<list>    where <list> is one or more comma separated paths\n");
    print("--singlefile=<list>         where <list> is one or more comma separated paths\n");
    print("--noharden-linux            do not run harden_linux.pl after restore\n");
    print("\n");

    print("DEFAULTS\n");
    print("The default RTI restore excludes:\n");
    tfr_print_array(\@DEF_RTI_RESTORE_EXCLUDES, "\t", $COMMA, 5);
    print("The default number of ssh open retries: $DEF_SSH_TUNNEL_RETRIES\n");
    print("\n");

    print("OPTIONS for LUKS devices\n");
    print("--luks                use a LUKS block device locally connected via USB\n");
    print("--luks-install        install elements required for LUKS operation\n");
    print("--luks-key=s          use specified key for LUKS rather than the default\n");
    print("--luks-showkey        output the string being used as the LUKS key\n");
    print("--luks-validate-key   verify the encryption key is valid\n");
    print("--luks-init           initialize the block device for use with LUKS\n");
    print("--luks-is-luks        is the block device a LUKS device\n");
    print("--luks-verify         verify the block device is a LUKS device\n");
    print("--luks-mount          mount the LUKS device on $MOUNTPOINT\n");
    print("--luks-umount         umount the LUKS device\n");
    print("--luks-label          report the file system label on the LUKS device\n");
    print("--luks-uuid           report the UUID of the LUKS device\n");
    print("--luks-dir=s          specify name of directory on LUKS device to restore from\n");
    print("--luks-status         report low level info about the LUKS device\n");
    print("--luks-getinfo        report info about the LUKS device\n");
    print("--luks-backup-date    report the date of last backup on the LUKS device\n");
    print("--luks-file-verify=s  verify file 's' exists on the LUKS device\n");
    print("--luks-file-restore=s restore file or directory from the LUKS device\n");
    print("\n");

    print("DEFAULTS\n");
    print("The default LUKS key: Dell Service Tag\n");
    print("The default mountpoint: $MOUNTPOINT\n");
    print("The default LUKS directory: $DEF_LUKS_DIR\n");
    print("\n");

    print("OPTIONS for any command\n");
    print("--daisy\n");
    print("--rti\n");
    print("--configfile=path\n");
    print("--logfiledir=path\n");
    print("--device=/dev/xxxx where /dev/xxxx is a block device\n");
    print("--device=/path/to/imagefile.img where imagefile.img is prepped image file\n");
    print("--usb-device\n");
    print("--summary-log-max-save=n          max nr of saved summary log files\n");
    print("--summary-log-min-save=n          min nr of saved summary log files\n");
    print("--summary-log-rotate              enable rotation of summary log files\n");
    print("--dry-run\n");
    print("\n");

    print("DEFAULTS\n");
    print("The default RTI config file path: $DEF_RTI_CONFIG_FILE_PATH\n");
    print("The default Daisy config file path: $DEF_DAISY_CONFIG_FILE_PATH\n");
    print("The default RTI log file directory: $DEF_RTI_LOG_DIR\n");
    print("The default Daisy log file directory: $DEF_DAISY_LOG_DIR\n");
    print("The default maximum nr of saved summary log files: $DEF_MAX_SAVE_SUMMARY_LOG\n");
    print("The default minimum nr of saved summary log files: $DEF_MIN_SAVE_SUMMARY_LOG\n");
    print("The default for summary log file rotation: ", 
	($DEF_ROTATE_SUMMARY_LOG) ? "enabled" : "disabled", "\n");

    return(1);
}


sub tfr_list_longest_elem
{
    my ($list_ref) = @_;

    my $longest_elem = $list_ref->[0];
    my $elem_len = length $longest_elem;
    for my $elem (@{$list_ref}) {
	if (length($elem) > $elem_len ) {
	    $longest_elem = $elem;
	    $elem_len = length($elem);
	}
    }

    return($longest_elem);
}


#
# is given element a member of specified list
#
# returns
#   1 if true
#   0 if false
#
sub tfr_list_is_member_of
{
    my ($list_ref, $element) = @_;

    my $rc = 0;

    for my $item (@{$list_ref}) {
	if ($item eq $element) {
	    $rc = 1;
	    last;
	}
    }

    return($rc);
}


sub tfr_is_cmd_line_consistent
{
    if ($CLOUD && $SERVER) {
	print {*STDERR} "--cloud and --server are mutually exclusive\n";
	return(0);
    }

    #
    # Consistency check for backup device conflicts.
    #
    if ($DEVICE || $USB_DEVICE) {
    
	if ($DEVICE && $USB_DEVICE) {
	    print {*STDERR} "--device=path and --usb-device are mutually exclusive\n";
	    return(0);
	}

	my $device_str = ($DEVICE) ? "--device=path" : "--usb-device";
	if ($RsyncServer) {
	    print {*STDERR} "$device_str and --rsync-server are mutually exclusive\n";
	    return(0);
	}
	elsif ($RsyncDir) {
	    print {*STDERR} "$device_str and --rsync-dir are mutually exclusive\n";
	    return(0);
	}
    }

    return(1);
}


#
# decide if a RTI system or a Daisy system
#
# handle four cases:
# 1. both --daisy and --rti specified
# 2. neither specified
# 3. only --rti specified
# 4. only --daisy rti specified
#
sub tfr_pick_rti_or_daisy
{
    # 1. if both specified, log warning and use "rti".
    # Note that these options are mutally exclusive
    if ( ($RTI == 1) && ($DAISY == 1) ) {
	print {*STDERR} "the --rti and --daisy options are mutally exclusive";
	print {*STDERR} "continuing as if only --rti was specified";
	$DAISY = 0;
    }

    # 2. if neither specified, give preference to $RTI
    elsif ( ($RTI == 0) && ($DAISY == 0) ) {
	if (-d "/usr2/bbx") {
	    $RTI = 1;
	}
	elsif (-d "/d/daisy") {
	    $DAISY = 1;
	}
	else {
	    $RTI = 1;
	}
    }

    # one or the other was specified

    return(1);
}


sub tfr_tfsupport_account_name
{
    return($DEF_TFSUPPORT_ACCOUNT_NAME);
}

sub tfr_pos_admin_group_name
{
    return($DEF_RTI_ADMIN_GROUP_NAME) if ($RTI);
    return($DEF_DAISY_ADMIN_GROUP_NAME) if ($DAISY);
    return("root");
}

sub tfr_pos_group_name
{
    return($DEF_RTI_GROUP_NAME) if ($RTI);
    return($DEF_DAISY_GROUP_NAME) if ($DAISY);
    return("root");
}

sub tfr_rsync_server_ipaddr
{
    my $rsync_server_ipaddr = 'NA';

    if ($DeviceType eq $DEVTYPE_SERVER) {
	$rsync_server_ipaddr = $RsyncServer;
    }
    elsif ($DeviceType eq $DEVTYPE_CLOUD) {
	$rsync_server_ipaddr = $CLOUD_SERVER;
    }

    return($rsync_server_ipaddr);
}

sub tfr_rsync_server_path
{
    my $rsync_server_path = 'NA';

    if ( ($DeviceType eq $DEVTYPE_SERVER) || ($DeviceType eq $DEVTYPE_FILE_SYSTEM) ) {
	$rsync_server_path = ($RsyncDir eq $EMPTY_STR) ? '(in place)' : $RsyncDir;
    }

    return($rsync_server_path);
}

sub tfr_rsync_device_is_disk
{
    my ($dev_type) = @_;

    if ($dev_type eq $DEVTYPE_LUKS || $dev_type eq $DEVTYPE_IMAGE ) {
	return(1);
    }

    return(0);
}

sub tfr_exit_status_extract
{
    my ($system_rc) = @_;

    my $exit_status = -1;

    # no exit status available
    if ( ($system_rc == -1) || ($system_rc & 127) ) {
	return($exit_status);
    }
	    
    # get at the command' exit status
    $exit_status = ($system_rc >> 8);

    return($exit_status);
}


#
# given the specified error number,
# return the appropriate error description string, or
# the empty string if error number is unknown.
#
# returns
#   error string on success
#   empty string if errno unknown
#
sub tfr_exit_strerror
{
    my ($errno) = @_;

    my $rc = (defined($ExitTable{errno})) ? $ExitTable{errno} : $EMPTY_STR;

    return($rc);
}

############################
###                      ###
###    TEST FUNCTIONS    ###
###                      ###
############################

sub tfr_test_functions
{
    # --test-get-shopcode
    if ($TEST_GET_SHOPCODE) {
	exit(tfr_test_get_shopcode());
    }

    # --test-process-lock
    if ($TEST_PROCESS_LOCK) {
	exit(tfr_test_process_lock());
    }

    # --test-notify-no-backup-device
    if ($TEST_NOTIFICATION_NO_BACKUP_DEVICE) {
	exit(tfr_test_notification_no_backup_device());
    }

    # --test-gen-summary-email-msg
    if ($TEST_GEN_SUMMARY_EMAIL_MSG) {
	exit(tfr_test_gen_summary_email_msg());
    }

    # --test-gen-users-listing-file
    if ($TEST_GEN_USERS_LISTING_FILE) {
	exit(tfr_test_gen_users_listing_file());
    }

    # --test-gen-users-shadow-file
    if ($TEST_GEN_USERS_SHADOW_FILE) {
	exit(tfr_test_gen_users_shadow_file());
    }

    # --test-gen-permfile-list
    if ($TEST_GEN_PERMFILE_LIST) {
	exit(tfr_test_gen_permfile_list());
    }

    # --test-retry-backup
    if ($TEST_RETRY_BACKUP) {
	tfr_test_backup_retry();
    }

    # --test-gen-default-config-file
    if ($TEST_GEN_DEF_CONFIG_FILE) {
	exit(tfr_test_gen_default_config_file());
    }

    # --test-parse-rsync-stats
    if ($TEST_PARSE_RSYNC_STATS) {
	exit(tfr_test_parse_rsync_stats());
    }

    # --test-rsync-exit-status
    if ($TEST_RSYNC_EXIT_STATUS) {
	tfr_test_rsync_exit_status();
    }

    # --test-edit-auth-keys
    if ($TEST_EDIT_AUTH_KEYS) {
	exit(tfr_test_edit_auth_keys());
    }

    # --test-restore-upgrade-add-users
    if ($TEST_RESTORE_UPGRADE_ADD_USERS) {
	exit(tfr_test_restore_upgrade_add_users());
    }

    # --test-restore-upgrade-adjust-users
    if ($TEST_RESTORE_UPGRADE_ADJUST_USERS) {
	exit(tfr_test_restore_upgrade_adjust_users());
    }

    # --test-restore-upgrade-samba-conf
    if ($TEST_RESTORE_UPGRADE_SAMBA_CONF) {
	exit(tfr_test_restore_upgrade_samba_conf());
    }

    # --test-restore-upgrade-samba-passwd
    if ($TEST_RESTORE_UPGRADE_SAMBA_PASSWD) {
	exit(tfr_test_restore_upgrade_samba_passwd());
    }

    # --test-restore-upgrade-set-homedir-owners
    if ($TEST_RESTORE_UPGRADE_HOMEDIR_OWNERS) {
	exit(tfr_test_restore_upgrade_homedir_owners());
    }

    # --test-notification-email
    if ($TEST_NOTIFICATION_EMAIL) {
	exit(tfr_test_notification_email());
    }

    return(1);
}


sub tfr_test_get_shopcode
{
    my $shopcode = tfr_pos_get_shopcode();
    if ($shopcode eq $EMPTY_STR) {
	print "could not get shopcode\n";
    }
    else {
	print "shopcode = $shopcode\n";
    }

    return($EXIT_OK);
}


sub tfr_test_process_lock
{
    $SERVER = 1;

    tfr_process_lock_obtain();

    my $pid = tfr_process_lock_pid();
    my $acquire_time = tfr_process_lock_acquire_time();

    print "process lock pid = $pid, process lock acquire time = $acquire_time\n";
    
    @EMAIL_RECIPIENTS = ("gsmith\@teleflora.com");
    $EMAIL_SERVER = "sendmail";
    $DeviceType = $DEVTYPE_SERVER;

    tfr_notification_process_lock_acquisition();

    tfr_process_lock_release();

    return($EXIT_OK);
}

sub tfr_test_notification_no_backup_device
{
    @EMAIL_RECIPIENTS = ("gsmith\@teleflora.com");
    $EMAIL_SERVER = "sendmail";

    tfr_notification_no_backup_device();

    return($EXIT_OK);
}

sub tfr_test_gen_summary_email_msg
{
    my %dev_attributes = (
	DEVICE  => $DEVICE,
	DEVDIR  => $DeviceDir,
    );

    if ($CLOUD) {
	$dev_attributes{DESTINATION} = $CLOUD_SERVER;
	$dev_attributes{DEVTYPE} = $DEVTYPE_CLOUD;
    }
    elsif ($SERVER) {
	$dev_attributes{DESTINATION} = $RsyncServer;
	$dev_attributes{DEVTYPE} = $DEVTYPE_SERVER;
    }
    elsif ($DEVICE) {
	$dev_attributes{DESTINATION} = $DEVICE;
	$dev_attributes{DEVTYPE} = $DEVTYPE_LUKS;
    }
    else {
	$dev_attributes{DESTINATION} = $DEVTYPE_UNK;
	$dev_attributes{DEVTYPE} = $DEVTYPE_LUKS;
    }

    my %bu_attributes = (
	BU_SETS     => \@BACKUP,
	BU_EXCLUDES => \@EXCLUDES,
	BU_TYPE     => $EMPTY_STR,
    );

    my $begin_time = time;
    my $end_time = time + 1000;
    my $backup_rc = 0;

    my %bu_summary_info = ();
    $bu_summary_info{$BU_SUMMARY_BEGIN} = $begin_time;
    $bu_summary_info{$BU_SUMMARY_END} = $end_time;
    $bu_summary_info{$BU_SUMMARY_BU_RESULT} = $backup_rc ;
    $bu_summary_info{$BU_SUMMARY_BU_RETRIES} = tfr_retry_backup_fetch_retries();
    $bu_summary_info{$BU_SUMMARY_DEV_TYPE} = $dev_attributes{DEVTYPE};
    $bu_summary_info{$BU_SUMMARY_DEVICE_FILE} = (tfr_rsync_device_is_disk($DeviceType)) ?  $DEVICE : 'NA';
    $bu_summary_info{$BU_SUMMARY_DEV_CAPACITY} = (tfr_rsync_device_is_disk($DeviceType)) ? '1TB' : 'NA';
    $bu_summary_info{$BU_SUMMARY_DEV_AVAILABLE} = (tfr_rsync_device_is_disk($DeviceType)) ? '50BB' : 'NA';
    $bu_summary_info{$BU_SUMMARY_RSYNC_RESULT} = tfr_rsync_exit_status_fetch();
    $bu_summary_info{$BU_SUMMARY_RSYNC_WARNINGS} = tfr_rsync_status_warnings();
    $bu_summary_info{$BU_SUMMARY_RSYNC_SENT} = tfr_format_rsync_stats(1_000_000);
    $bu_summary_info{$BU_SUMMARY_RSYNC_SERVER} = tfr_rsync_server_ipaddr();
    $bu_summary_info{$BU_SUMMARY_RSYNC_PATH} = tfr_rsync_server_path();

    my $subject = tfr_backup_summary_report_subject($backup_rc, \%dev_attributes);
    my $summary = tfr_backup_summary_report_generate(\%bu_summary_info);

    print "subject: $subject\n";
    print "summary:\n$summary\n";

    return($EXIT_OK);
}

sub tfr_test_gen_users_listing_file
{
    my $list_users_cmd = tfrm_pathto_pos_users_script() . " --list";
    my $users_listing_file_path = tfrm_nameof_users_listing_file();

    tfr_generate_users_listing_file($list_users_cmd, $users_listing_file_path);

    return($EXIT_OK);
}

sub tfr_test_gen_users_shadow_file
{
    my $list_users_cmd = tfrm_pathto_pos_users_script() . " --list";
    my $users_listing_file_path = tfrm_nameof_users_listing_file();

    tfr_generate_users_listing_file($list_users_cmd, $users_listing_file_path);

    my $shadow_file_path = "/etc/shadow";
    my $users_shadow_file_path = tfrm_nameof_users_shadow_file();

    tfr_generate_users_shadow_file($users_listing_file_path, $shadow_file_path, $users_shadow_file_path);

    return($EXIT_OK);
}

sub tfr_test_gen_permfile_list
{
    my @platform_bu_types = tfr_get_platform_bu_types(@BACKUP_TYPES);
    foreach my $bu_type (@platform_bu_types) {
	my $bu_perm_file_path = tfrm_pathto_perm_file($bu_type);
	print "permfile path: $bu_perm_file_path\n";
    }

    return($EXIT_OK);
}

sub tfr_test_backup_retry
{
    loginfo("***** testing backup retries *****");

    return(1);
}


sub tfr_test_gen_default_config_file
{
    my $config_file_path = tfrm_pathto_def_tfrsync_config_file();
    my $config_file_name = basename($config_file_path);

    my $generated_config_file = tfr_install_default_config_file($config_file_name);
    if ($generated_config_file) {
	print "default config file generated: $generated_config_file\n";
    }
    else {
	print "could not generate default config file: $config_file_name\n";
    }

    return($EXIT_OK);
}


sub tfr_test_parse_rsync_stats
{
    tfr_record_rsync_stats($TEST_PARSE_RSYNC_LOG);

    print "rsync sent     = $RsyncStatsSent\n";
    print "rsync received = $RsyncStatsReceived\n";
    print "rsync rate     = $RsyncStatsRate\n";

    return($EXIT_OK);
}


sub tfr_test_rsync_exit_status
{
    loginfo("***** testing rsync exit status *****");

    return(1);
}


sub tfr_test_edit_auth_keys
{
    my $auth_keys_path = "authorized_keys";
    my $key_path = "id_rsa.pub";
    
    if (tfr_auth_keys_file_rm_key($auth_keys_path, $key_path)) {
	print "public key in $key_path removed from $auth_keys_path\n";
    }
    else {
	print "public key in $key_path NOT removed from $auth_keys_path\n";
    }

    return($EXIT_OK);
}


sub tfr_test_restore_upgrade_add_users
{
    my $users_listing_file = "users_listing.txt";
    tfr_restore_upgrade_add_users($users_listing_file);

    return($EXIT_OK);
}

sub tfr_test_restore_upgrade_adjust_users
{
    my $users_shadow_file = "users_shadow.txt";
    my $system_shadow_file = "shadow";
    tfr_restore_upgrade_adjust_users($users_shadow_file, $system_shadow_file);

    return($EXIT_OK);
}


sub tfr_test_restore_upgrade_samba_conf
{
    my $samba_conf_file = "smb.conf";
    tfr_restore_upgrade_samba_conf($samba_conf_file);

    return($EXIT_OK);
}


sub tfr_test_restore_upgrade_samba_passwd
{
    my $samba_pdb = 'smbpasswd';
    my $new_samba_pdb = $samba_pdb . $DOT . $$;
    tfr_restore_upgrade_samba_gen_passwd($samba_pdb, $new_samba_pdb);

    return($EXIT_OK);
}


sub tfr_test_restore_upgrade_homedir_owners
{
    my $users_listing_file = "users_listing.txt";

    tfr_restore_upgrade_homedir_owners($users_listing_file);

    return($EXIT_OK);
}

sub tfr_test_notification_email
{
    my %subject_info = ();
    $subject_info{BACKUP_NAME} = tfr_backup_name();
    $subject_info{BACKUP_DESTINATION} = tfr_backup_destination();
    $subject_info{BACKUP_HOSTNAME} = hostname();
    my $subject = tfr_notification_generate_subject(\%subject_info);

    my %msg_info = ();
    $msg_info{PROGNAME} = $PROGNAME;
    $msg_info{PID} = 2631;
    $msg_info{ACQUIRE_TIME} = "Thu Nov 24 18:22:48 2016";
    $msg_info{WHAT} = $PROGNAME . $ATSIGN . hostname();
    my $message = tfr_notification_process_lock_acquisition_message(\%msg_info);
    print "===========================================================================\n";
    print "NOTIFICTION TYPE: process lock acquisition\n\n";
    print "SUBJECT: $subject\n\n";
    print "MESSAGE:\n";
    print $message;
    print "===========================================================================\n";

    %msg_info = ();
    $msg_info{PROGNAME} = $PROGNAME;
    $msg_info{WHAT} = $PROGNAME . $ATSIGN . hostname();
    $message = tfr_notification_no_backup_device_message(\%msg_info);
    print "===========================================================================\n";
    print "NOTIFICATION TYPE: no backup device:\n\n";
    print "SUBJECT: $subject\n\n";
    print "MESSAGE:\n";
    print $message;
    print "===========================================================================\n";

    my $backup_rc = 43;
    %msg_info = ();
    $msg_info{PROGNAME} = $PROGNAME;
    $msg_info{WHAT} = $PROGNAME . $ATSIGN . hostname();
    $msg_info{BACKUP_RC} = $backup_rc;
    $msg_info{BACKUP_RC_DESC} = tfr_exit_strerror($backup_rc);
    $msg_info{RSYNC_EXIT_STATUS} = ($backup_rc == $EXIT_RSYNC_ERROR) ? 30 : 0;
    $message = tfr_notification_backup_error_message(\%msg_info);
    print "===========================================================================\n";
    print "NOTIFICATION TYPE: backup error\n\n";
    print "SUBJECT: $subject\n\n";
    print "MESSAGE:\n";
    print $message;
    print "===========================================================================\n";

    return($EXIT_OK);
}


###############################
###############################
###############################


sub shutdown_and_exit
{
    my ($exit_status) = @_;

    if (! tfr_log_conclude()) {
	print {*STDERR} "error closing log files\n";
    }

    exit($exit_status);
}


#
# small API for managing the rsync exit status.
#
# if code calling the backup transactions function
# gets a return value of $EXIT_RSYNC_ERROR,
# it can call the rsync status accessor to get the
# actual value returned by rsync.
#
sub tfr_rsync_exit_status_clear
{
    $RsyncExitStatus = 0;

    return(1);
}


sub tfr_rsync_exit_status_fetch
{
    return($RSYNC_EXIT_STATUS_TIMEOUT_ERROR) if ($TEST_RETRY_BACKUP);

    return($RsyncExitStatus);
}


sub tfr_rsync_exit_status_record
{
    my ($exit_status) = @_;

    $RsyncExitStatus = $exit_status;

    return(1);
}


sub tfr_rsync_exit_status_prepare
{
    my ($returnval) = @_;

    if ($TEST_RETRY_BACKUP) {
	# return rsync error for all but last interation
	my $retry_backup_reps = tfr_retry_backup_reps();
	my $retries = tfr_retry_backup_fetch_retries();
	$returnval = ($retries < $retry_backup_reps) ? $EXIT_RSYNC_ERROR : $returnval;
    }

    return($returnval);
}


#
# classify value of rsync exit status and handle appropriately.
#
# Returns
#   rsync exit status
#
sub tfr_rsync_exit_status_classify
{
    my ($rc) = @_;

    # save the rsync status value
    tfr_rsync_exit_status_record($rc);

    # a value of 23 from rsync, which the man page
    # states is:  partial transfer due to error,
    # is only going to be a warning, so just note it and
    # reset status to success.
    if ($rc == $RSYNC_EXIT_STATUS_PARTIAL) {
	loginfo("warning: rsync command exit status: partial xfer due to error ($rc)");
	tfr_rsync_status_warnings_push($rc);
	$rc = 0;
    }
    
    # a value of 24 from rsync, which the rsync man page
    # states is: Partial transfer due to vanished source files,
    # is only going to be a warning, so just note it and
    # reset status to success.
    elsif ($rc == $RSYNC_EXIT_STATUS_VANISHED) {
	loginfo("warning: rsync command exit status: partial xfer due to vanished files ($rc)");
	tfr_rsync_status_warnings_push($rc);
	$rc = 0;
    }

    # a value of 255 from rsync is going to be
    # classified as an SSH connection error.
    elsif ($rc == $RSYNC_EXIT_STATUS_SSH_ERROR) {
	logerror("rsync command exit status: ssh connection error ($rc)");
	$rc = $EXIT_RSYNC_ERROR;
    }

    # a value of 30 from rsync, which the rsync man pages
    # states is: Timeout in data send/receive,
    # is going to be an error.
    elsif ($rc == $RSYNC_EXIT_STATUS_TIMEOUT_ERROR) {
	tfr_rsync_status_record_timeout_error();
	logerror("rsync command exit status: timeout in data send/receive ($rc)");
	$rc = $EXIT_RSYNC_ERROR;
    }

    # a value of 12 from rsync, which the rsync man pages
    # states is: Error in rsync protocol data stream,
    # is going to be an error.
    elsif ($rc == $RSYNC_EXIT_STATUS_PROTOCOL_ERROR) {
	tfr_rsync_status_record_protocol_error();
	logerror("rsync command exit status: error in rsync protocol data stream ($rc)");
	$rc = $EXIT_RSYNC_ERROR;
    }

    # anything other than 0 is an error
    elsif ($rc != 0) {
	showerror("rsync command exited with non-zero value: $rc");
	$rc = $EXIT_RSYNC_ERROR;
    }

    return($rc);
}


#
# if any rsync commands executed during backup operations
# returned a timeout error, value 30, then this accessor
# will return true.
#
sub tfr_rsync_status_timeout_error_seen
{
    return($RsyncTimeoutSeen);
}

sub tfr_rsync_status_record_timeout_error
{
    $RsyncTimeoutSeen = 1;

    return($RsyncTimeoutSeen);
}


#
# if any rsync commands executed during backup operations
# returned a protocol error, value 12, then this accessor
# will return true.
#
sub tfr_rsync_status_protocol_error_seen
{
    return($RsyncProtocolErrorSeen);
}

sub tfr_rsync_status_record_protocol_error
{
    $RsyncProtocolErrorSeen = 1;

    return($RsyncProtocolErrorSeen);
}


#
# if any rsync commands executed during a backup operation
# returned an exit status that is not considered serious
# enough to abort will be considered a warning.
#
sub tfr_rsync_status_warnings_init
{
    @RsyncWarnings = ();

    return(1);
}

sub tfr_rsync_status_warnings_push
{
    my ($rsync_exit_status) = @_;

    # if the given rsync exit status is not already in the list of warnings,
    # add it to the list
    if (! tfr_list_is_member_of(\@RsyncWarnings, $rsync_exit_status)) {
	push(@RsyncWarnings, $rsync_exit_status);
    }

    return(1);
}

sub tfr_rsync_status_warnings_list
{
    return(@RsyncWarnings);
}

sub tfr_rsync_status_warnings
{
    my $warnings = (@RsyncWarnings) ? join(', ', @RsyncWarnings) : '0';

    return($warnings);
}


#
# small API for backup retries.
#
sub tfr_retry_backup_wait
{
    return($RetryBackupWait);
}

sub tfr_retry_backup_reps
{
    return($RetryBackupReps);
}

sub tfr_retry_backup_record_retries
{
    my ($backup_retry_iteration) = @_;

    $RetryBackupIterations = $backup_retry_iteration;

    return($RetryBackupIterations);
}

sub tfr_retry_backup_fetch_retries
{
    return($RetryBackupIterations);
}


#
# output elements of an array, with specified separator, and
# with specified number of elements per line.
#
sub tfr_print_array
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

#
# get "yes/no" answer from stdin.
#
# Returns
#   1 if "y"
#   0 for anything else
#
sub get_yn
{
    my ($prompt) = @_;

    my $answer = $EMPTY_STR;

    while (1) {
	print("$prompt?\n");
	print("(Y/N) >");
	$answer = <>;
	if (defined($answer)) {
	    chomp($answer);
	    last if ($answer =~ /^n/i);
	    last if ($answer =~ /^y/i);
	}
	else {
	    # eof seen (usually ^D)
	    $answer = 'n';
	    last;
	}
    }

    if ($answer =~ /^y/i) {
	return(1);
    }

    return(0);
}


sub get_command_line
{
	my $cmd_line = $EMPTY_STR;

	$cmd_line = $0;
	foreach my $i (@ARGV) {
		$cmd_line .= $SPACE;
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


sub is_configured_sendmail
{
    return($EMAIL_SERVER eq "sendmail");
}

sub is_configured_smtp_mail
{
    return( ($EMAIL_SERVER) && ($EMAIL_SERVER ne "sendmail") && $EMAIL_USER && $EMAIL_PASS );
}

sub is_configured_email_recipients
{
    return(scalar(@EMAIL_RECIPIENTS));
}

sub is_configured_print
{
    return(scalar(@PRINTERS));
}

#
# if the value of $RootDirCLO is equal to the default value,
# then a restore in place is being done.
#
sub is_restore_in_place
{
    return($RootDirCLO eq $DEF_ROOTDIR);
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
sub is_input_insecure
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
	'[[:cntrl:]]',      # non printables
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
	close($pipe);
    }
    else {
	logerror("error opening pipe to command: $cmd");
    }

    return($rc);
}


#
# is directory empty - from perlmonks.org
#
# definition of "empty" -- no files/folders/links except . and ..
#
# returns:
#   1 - empty
#   0 - not empty
#  -1 - doesn't exist

sub is_dir_empty
{
    my ($dir) = @_;

    my $rc = 1;

    my $file;
    if (opendir(my $dfh, $dir)) {
	while (defined($file = readdir $dfh)) {
	    if ( ($file eq $DOT) || ($file eq $DOTDOT) ) {
		next:
	    }
	    $rc = 0;
	}
	closedir($dfh);
    }
    else {
	$rc = -1;
   }

   return($rc);
} 


# Verify that the backup device path is either a block device or
# the path to an image file of at least a minimum size.
#
# Return TRUE if backup device path is verified
# Return FALSE if not
#
sub tfr_device_is_verified
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
	    logerror("[device verify] image file less then minimum size: $DEVICE_IMAGE_FILE_MIN bytes");
	}
    }

    else {
	logerror("[device verify] device must be a block device or an existing image file");
    }

    return(0);
}


#
# Format the backup device using Linux EXT2 Filesystem.
# Note that this supports either block devices, or image files.
#
# Returns
#   0 on success
#   non-zero on failure
#
sub tfr_device_format_ext2
{
    my ($device, $device_type) = @_;

    my $returnval = 0;
    my $answer = $EMPTY_STR;
    my $uuid = $EMPTY_STR;
    my $ml = "format";

    if ($device eq $EMPTY_STR) {
	logerror("[$ml] No device specified to format.");
	return(-2);
    }

    if (! tfr_device_is_verified($device)) {
	logerror("[$ml] Backup device path verification error");
	return(-3);
    }

    # Don't format a mounted drive.
    if (is_rsync_bu_device_mounted()) {
	logerror("[$ml] Backup Device is mounted. Please --unmount before formatting.");
	return(-3);
    }

    my $begin_timestamp = POSIX::strftime("%a %b %d %H:%M:%S %Y", localtime());

    showinfo("[$ml] formatting: $device");


    # Determine the "old" UUID (if any).  If there is no old UUID,
    # then by setting the value to "random", it will cause the
    # tune2fs command to generate a new UUID for the file system.

    $uuid = tfr_get_filesys_uuid($DEVICE);
    if ($uuid eq $EMPTY_STR) {
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
    my $label_datestamp = POSIX::strftime("%Y%m%d", localtime());
    my $label_disk = $label_brand . $DASH . $label_datestamp;

    showinfo("[$ml] Making an EXT2 file system on: $device");
    my $fmt_cmd = "/sbin/mkfs.ext2 -F -L $label_disk $device";
    if ($VERBOSE) {
	# all output to logs and stdout
	showinfo("[$ml] $fmt_cmd");
	system("$fmt_cmd 2>&1 | tee -a $LOGFILE");
    }
    else {
	# all output to logs
	loginfo("[$ml] $fmt_cmd");
	system("$fmt_cmd >> $LOGFILE 2>> $LOGFILE");
    }
    $returnval = $?;
    if ($returnval != 0) {
	showerror("[$ml] Could not format: $device");
    }
    else {
	showinfo("[$ml] Setting tuning parameters for $device_type: $device");
	my $tune_cmd = "/sbin/tune2fs -c 0 -e remount-ro -i 12m -U $uuid $device";
	if ($VERBOSE) {
	    showinfo("[$ml] Setting max mount count to 0, thus disabling it");
	    showinfo("[$ml] Setting error behavior to \"remount read-only on error\"");
	    showinfo("[$ml] Setting FSCK interval to 12 months");
	    showinfo("[$ml] Setting UUID of file system to: $uuid");
	    system("$tune_cmd 2>&1 | tee -a $LOGFILE");
	    $returnval = $?;
	}
	else {
	    loginfo("[$ml] $tune_cmd");
	    system("$tune_cmd >> $LOGFILE 2>> $LOGFILE");
	    $returnval = $?;
	}
	if ($returnval != 0) {
	    showerror("[$ml] Could not tune2fs: $device");
	}

	else {

	    my $end_timestamp = POSIX::strftime("%a %b %d %H:%M:%S %Y", localtime());

	    showinfo("[$ml] Setting up $PROGNAME framework on $device_type: $device");

	    #
	    # Write format info to newly formatted device
	    #
	    if (mount_device("rw")) {
		logerror("[$ml] Could not mount $device_type after formatting: $device");
		$returnval = -4;
	    }
	    else {

		showinfo("[$ml] Writing tag file to $device_type: $device");

		my $format_info = << "END_FORMAT_INFO";
#
#      Backup program: $PROGNAME $CVS_REVISION
#         Device type: $device_type $device
#      Format Started: $begin_timestamp
#    Format Completed: $end_timestamp
#
END_FORMAT_INFO

		if (open(my $BUSIG, '>', "$MOUNTPOINT/$FORMAT_FILE")) {
		    print($BUSIG "$format_info");
		    close($BUSIG);
		}
		else {
		    logerror("Could not write backup tag file: $MOUNTPOINT/$FORMAT_FILE");
		    $returnval = -5;
		}

		unmount_device();
	    }
	}
    }

    return($returnval);
}


#
# remove a list of paths.
#
# if path does not exist, do nothing and don't complain.
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_runtime_cleanup_unlink_paths
{
    my (@paths) = @_;

    my $rc = 1;

    for my $path (@paths) {
	if (-e $path) {
	    unlink $path;
	    if (-e $path) {
		showerror("runtime cleanup could not remove: $path");
		$rc = 0;
	    }
	    else {
		loginfo("runtime cleanup removed: $path");
	    }
	}
    }

    return($rc);
}


sub tfr_runtime_cleanup
{
    my $rc = $EXIT_OK;

    my $process_lock_path = tfr_pathto_process_lock();
    my @paths = ($process_lock_path);

    if ($SERVER || $CLOUD) {
	my $ssh_socket_path = tfr_pathto_ssh_tunnel_socket();
	push(@paths, $ssh_socket_path);
    }

    if (tfr_runtime_cleanup_unlink_paths(@paths)) {
	loginfo("runtime cleanup successful");
    }
    else {
	logerror("could not cleanup runtime files");
	$rc = $EXIT_RUNTIME_CLEANUP;
    }

    return($rc);
}


##################################
###                            ###
###   PROCESS LOCK FUNCTIONS   ###
###                            ###
##################################

#
# called from mainline - try to obtain a process lock.
# if process lock not available, cleanup and exit.
#
# if "--dry-run" specified, just return.
#
sub tfr_process_lock_obtain
{
    if ($DRY_RUN) {
	return(1);
    }

    if (tfr_process_lock_setup()) {
	my $process_lockfile_path = tfr_process_lock_acquire();
	if ($process_lockfile_path) {
	    loginfo("[plock obtain] process lock file path: $process_lockfile_path");
	}
	else {
	    showerror("[plock obtain] could not acquire process lock: can not continue");
	    tfr_notification_process_lock_acquisition();
	    shutdown_and_exit($EXIT_LOCK_ACQUISITION);
	}
    }
    else {
	showerror("[plock obtain] could not set up process lock: can not continue");
	shutdown_and_exit($EXIT_LOCK_SETUP);
    }

    return(1);
}


sub tfr_process_lock_classify
{
    my $lockfile_type = $EMPTY_STR;
    if ($SERVER) {
	$lockfile_type = $LOCKFILE_TYPE_SERVER;
    }
    elsif ($CLOUD) {
	$lockfile_type = $LOCKFILE_TYPE_CLOUD;
    }
    elsif ($DEVICE) {
	$lockfile_type = $LOCKFILE_TYPE_DEVICE;
    }
    else {
	$lockfile_type = $LOCKFILE_TYPE_UNK;
    }

    return($lockfile_type);
}


#
# If the process lock file directory does not exist,
# and is the public lock directory, log an error message and
# return an error.  If a private lock file directory,
# try to make it if it does not exist, and log an error
# message if the mkdir fails.
#
# Returns
#   1 on success
#   0 if error
#
sub tfr_process_lock_mkdir
{
    my $rc = 1;

    # public lockfile directory
    if ($LOCKFILE_DIR eq "/var/lock") {
	if (! -d $LOCKFILE_DIR) {
	    logerror("[plock mkdir] directory for process lock file does not exist: $LOCKFILE_DIR");
	    $rc = 0;
	}
    }

    # private lockfile directory
    else {
	if (! -d $LOCKFILE_DIR) {
	    system("mkdir $LOCKFILE_DIR");
	    if (! -d $LOCKFILE_DIR) {
		logerror("[plock mkdir] could not make process lock directory: $LOCKFILE_DIR");
		$rc = 0;
	    }
	}
    }

    return($rc);
}

#
# return the path to the process lock lockfile.
#
# The lockfile name is formed from the lockfile dir and
# device type.
#
# Returns
#   path to lockfile on success
#   empty string on error
#
sub tfr_pathto_process_lock
{
    my $lockfile_type = tfr_process_lock_classify();
    my $lockfile_path = $LOCKFILE_DIR . $SLASH . $DEF_PROJ_NAME;
    $lockfile_path .= $DASH . $lockfile_type;
    $lockfile_path .= $LOCKFILE_SUFFIX;

    return($lockfile_path);
}

#
# init the process lock.
#
# Returns
#   1 on success
#   0 if error
#
sub tfr_process_lock_setup
{
    my $rc = 1;

    if (! tfr_process_lock_mkdir()) {
	logerror("[plock setup] lockfile dir does not exist and can't make it: $LOCKFILE_DIR");
	$rc = 0;
    }

    return($rc);
}

#
# attempt to get exclusive access to the process lock.
#
# Returns
#   path to lockfile if successful
#   empty string if not
#
# FIXME: if making the lock file fails, look for a pid file and
# if there is a process that corresponds to the pid.  If there
# is no pid file, look for a "edir_update.pl" process by name.
# if there is no currently running instance, there should not be
# a lock file or a pid file.
#
sub tfr_process_lock_acquire
{
    my $rc = $EMPTY_STR;

    if ($SERVER || $CLOUD || $DEVICE) {
	my $lockfile_path = tfr_pathto_process_lock();
	if ($DEBUGMODE) {
	    loginfo("[plock acquire] attempting to acquire process lock: $lockfile_path");
	}
	if (sysopen(LFH, $lockfile_path, O_EXCL|O_CREAT)) {
	    close(LFH);
	    if (open(my $lfh, '>', $lockfile_path)) {
		print($lfh "$$\n");
		close($lfh);
		if ($DEBUGMODE) {
		    loginfo("[plock acquire] process lock acquired: $lockfile_path");
		    loginfo("[plock acquire] pid written to process lock file: $$");
		}
	    }
	    else {
		logerror("[plock acquire] could not write pid to process lock file: $lockfile_path");
	    }

	    $rc = $lockfile_path;
	}

	# couldn't get lock, but verify lock is valid.
	# get pid from lockfile and verify the process
	# still exists.
	else {
	    if (open(my $lfh, '<', $lockfile_path)) {
		my $pid = <$lfh>;
		chomp($pid);
		close($lfh);
		if (kill(0, $pid)) {
		    loginfo("[plock acquire] signal 0 sent to pid: $pid");
		}
		else {
		    showerror("[plock acquire] could not verify process lock validity: $lockfile_path");
		    showerror("[plock acquire] pid contained in process lock does not exist: $pid");
		}
	    }
	    else {
		showerror("[plock acquire] could not verify lockfile validity: $lockfile_path");
	    }
	}
    }

    return($rc);
}

#
# release the process lock.
#
# Returns
#   1 if successful
#   0 if not
#
sub tfr_process_lock_release
{
    my $rc = 1;

    if ($DRY_RUN) {
	return($rc);
    }

    if ($SERVER || $CLOUD || $DEVICE) {
	my $lockfile_path = tfr_pathto_process_lock();

	if (-f $lockfile_path) {
	    if (unlink($lockfile_path)) {
		loginfo("[process_lock_release] file unlinked: $lockfile_path");
	    }
	    else {
		logerror("[process_lock_release] error unlinking process lock $lockfile_path: $!");
		$rc = 0;
	    }
	}
	else {
	    loginfo("[process_lock_release] process lock already released, file does not exist: $lockfile_path");
	}
    }

    return($rc);
}

sub tfr_process_lock_pid
{
    my $pid = 0;

    my $lockfile_path = tfr_pathto_process_lock();
    if (-e $lockfile_path) {
	if (open(my $lfh, '<', $lockfile_path)) {
	    $pid = <$lfh>;
	    chomp($pid);
	    close($lfh);
	}
	else {
	    loginfo("[plock pid] could not get process lock pid, could not open file: $lockfile_path");
	}
    }
    else {
	loginfo("[plock pid] could not get process lock pid, file does not exist: $lockfile_path");
    }

    return($pid);
}

sub tfr_process_lock_acquire_time
{
    my $acquire_time = $EMPTY_STR;

    my $lockfile_path = tfr_pathto_process_lock();
    if (-e $lockfile_path) {
	my $st = File::stat::stat($lockfile_path);
	my $lockfile_mtime = POSIX::ctime($st->mtime);
	chomp($lockfile_mtime);
	$acquire_time = $lockfile_mtime;
    }
    else {
	loginfo("[plock acq time] could not get process lock mtime, file does not exist: $lockfile_path");
    }

    return($acquire_time);
}


####################################
###                              ###
###        NOTIFICATIONS         ###
###                              ###
####################################

sub tfr_notification_generate_subject
{
    my ($subject_info) = @_;

    my $subject = "ERROR $subject_info->{BACKUP_NAME} Backup";
    $subject .= " ($subject_info->{BACKUP_DESTINATION})";
    $subject .= " $subject_info->{BACKUP_HOSTNAME}";

    return($subject);
}

sub tfr_notification_subject
{
    my %subject_info = ();
    $subject_info{BACKUP_NAME} = tfr_backup_name();
    $subject_info{BACKUP_DESTINATION} = tfr_backup_destination();
    $subject_info{BACKUP_HOSTNAME} = hostname();

    return(tfr_notification_generate_subject(\%subject_info));
}

sub tfr_notification_process_lock_acquisition_message
{
    my ($msg_info) = @_;

    my $message = "A new instance of $msg_info->{PROGNAME} could not be started because\n";
    $message .=   "it could not acquire the process lock.\n\n";
    if ($msg_info->{PID} != 0) {
	$message .= "The previous instance was started by a proccess with PID $msg_info->{PID}.\n";
    }
    if ($msg_info->{ACQUIRE_TIME}) {
	$message .= "The previous instance was started at time $msg_info->{ACQUIRE_TIME}.\n";
    }
    $message .= "\n";
    $message .= "Message sent by $msg_info->{WHAT}\n";

    return($message);
}

sub tfr_notification_process_lock_acquisition
{
    # first the subject line
    my $subject = tfr_notification_subject();

    # then the message body
    my %msg_info = ();
    $msg_info{PROGNAME} = $PROGNAME;
    $msg_info{PID} = tfr_process_lock_pid();
    $msg_info{ACQUIRE_TIME} = tfr_process_lock_acquire_time();
    $msg_info{WHAT} = $PROGNAME . $ATSIGN . hostname();
    my $message = tfr_notification_process_lock_acquisition_message(\%msg_info);

    return(tfr_send_email($subject, $message));
}


sub tfr_notification_no_backup_device_message
{
    my ($msg_info) = @_;

    my $message = "The $msg_info->{PROGNAME} script encountered an error.\n\n";
    $message .= "-- Backup Device Not Found --\n\n";
    $message .= "A backup could not be performed because a device could not be found\n";
    $message .= "to store the backup.\n\n";
    $message .= "If you are using a Passport drive, verify that the drive is connected to\n";
    $message .= "the server by a  USB cable, and verify that the small white light is\n";
    $message .= "illuminated on the side of the Passport drive.\n\n";
    $message .= "Message sent by $msg_info->{WHAT}\n";

    return($message);
}

sub tfr_notification_no_backup_device
{
    # first the subject line
    my $subject = tfr_notification_subject();

    my %msg_info = ();
    $msg_info{PROGNAME} = $PROGNAME;
    $msg_info{WHAT} = $PROGNAME . $ATSIGN . hostname();
    my $message = tfr_notification_no_backup_device_message(\%msg_info);

    tfr_send_email($subject, $message);

    return(tfr_print_results($subject, $message));
}

sub tfr_notification_backup_error_message
{
    my ($msg_info) = @_;

    my $message = "The backup function of the $msg_info->{PROGNAME} script returned an error.\n\n";
    $message .= "The backup function returned error code: $msg_info->{BACKUP_RC}\n";
    $message .= "Description of backup function error: $msg_info->{BACKUP_RC_DESC}\n\n";
    if ($msg_info->{RSYNC_EXIT_STATUS}) {
	$message .= "The rsync command returned error code: $msg_info->{RSYNC_EXIT_STATUS}\n\n";
    }
    $message .= "Message sent by $msg_info->{WHAT}\n";

    return($message);
}

sub tfr_notification_backup_error
{
    my ($backup_rc) = @_;

    # first the subject line
    my $subject = tfr_notification_subject();

    my %msg_info = ();
    $msg_info{PROGNAME} = $PROGNAME;
    $msg_info{WHAT} = $PROGNAME . $ATSIGN . hostname();
    $msg_info{BACKUP_RC} = $backup_rc;
    $msg_info{BACKUP_RC_DESC} = tfr_exit_strerror($backup_rc);
    $msg_info{RSYNC_EXIT_STATUS} = ($backup_rc == $EXIT_RSYNC_ERROR) ? tfr_rsync_exit_status_fetch() : 0;
    my $message = tfr_notification_backup_error_message(\%msg_info);

    return(tfr_send_email($subject, $message));
}


#
# Get the system run level.
#
# returns
#	0-6 on success
#	-1 on error
#
sub get_runlevel
{
    my $runlevel = -1;

    #
    # Use output of 'who -r' which seems to work on both
    # RHEL5 and RHEL6 under Kaseya.
    #
    my $whocmd = '/usr/bin/who';
    if (-x $whocmd) {
	if (open(my $pipe, q{-|}, "$whocmd -r")) {
	    while (<$pipe>) {
		chomp;
		$runlevel = $_;
		$runlevel =~ s/\s*run-level\s(\d).+$/$1/;
	    }
	    close($pipe);
	}
	else {
	    logerror("[get_runlevel] could not open pipe to command: $whocmd");
	}
    }
    else {
	logerror("[get_runlevel] required command not available: $whocmd");
    }

    return($runlevel);
}


#
# Set the system run level to value between 0 and 6.
#
# returns
#	1 on success
#	0 if error
#
sub set_runlevel
{
    my ($new_runlevel) = @_;

    my $rc = 1;

    system("/sbin/telinit $new_runlevel");
    if ($? != 0) {
	$rc = 0;
    }

    # The "init" man page mentions that "init" waits 5 seconds
    # between each of two kills, and testing reveals we need
    # to wait a bit for the runlevel to change.
    sleep(10);

    return($rc);
}


#
# Get the file system UUID from the specified backup device.
#
# Returns
#   non-empty string with 36 character UUID
#   empty string if UUID can not be found
#
sub tfr_get_filesys_uuid
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
# Get info about the backup set on the backup device
#
sub get_backup_device_info
{
    my ($device, $mountpoint) = @_;

    loginfo("Get backup device info");

    # Verify the backup device can be mounted.
    mount_device("ro");
    if (! is_rsync_bu_device_mounted()) {
	if (-f $device) {
	    showinfo("Could not mount image file: $device");
	    showinfo("Use \"--format\" to format image file first");
	}
	else {
	    showinfo("Could not mount backup device: $device");
	}
	return(1);
    }

    my $uuid = tfr_get_filesys_uuid($device);
    print("Backup device file system UUID: $uuid\n");

    my $free_space = get_free_space($mountpoint);
    print("Backup device free space: $free_space KB\n");

    unmount_device();

    return(0);
}


#
# Public IP Address
#
sub get_public_ip_addr
{
    my $publicip = $EMPTY_STR;
    my $cmd = "curl --silent http://icanhazip.com";

    # retry several times
    my $max_retries = 5;
    for (1 .. $max_retries) {
	if (open(my $pipe, q{-|}, $cmd)) {
	    while (<$pipe>) {
		chomp;
		if (/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
		    $publicip = $1;
		}
	    }
	    close($pipe);

	    if ($publicip) {
		loginfo("iterations to obtain public ip: $_");
		last;
	    }
	}
	else {
	    logerror("error opening pipe to: $cmd");
	}
    }

    return($publicip);
}


#
# get the ip address of the default network interface.
#
# Returns
#   non-empty string on success
#   empty string on error
#
sub get_ip_address
{
    my $hostname = hostname();
    my $ip_addr_binary = gethostbyname($hostname);
    my $ip_addr = inet_ntoa($ip_addr_binary);

    return($ip_addr);
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
    my $netmask = $EMPTY_STR;
    my $pattern = 'Mask:';
    if ($OS eq 'RHEL7') {
	$pattern = 'netmask ';
    }

    my $cmd = "/sbin/ifconfig $NetworkDeviceCLO 2> /dev/null";
    if (open(my $pipe, q{-|}, $cmd)) {
	while (<$pipe>) {
	    if (/${pattern}(\d+\.\d+\.\d+\.\d+)/) {
		$netmask = $1;
	    }
	}
	close($pipe);
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
    my $rc = $EMPTY_STR;

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
	close($pipe);
    }
    else {
	logerror("[get_gateway_ipaddr] could not open pipe to: $route_cmd");
    }

    # check for a route table entry with something reasonable in it
    if (exists($route_table_entry[1])) {
	my $gateway = $route_table_entry[1];
	if ($gateway =~ /\d+\.\d+\.\d+\.\d+/) {
	    $rc = $gateway;
	}
	else {
	    logerror("[get_gateway_ipaddr] unrecognized format for gateway address: $rc");
	}
    }
    else {
	logerror("[get_gateway_ipaddr] unexpected output of route command: $route_cmd");
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
sub verify_network_device
{
    my ($network_device) = @_;

    my $rc = 1;

    system("/sbin/ifconfig $network_device > /dev/null 2>&1");
    if ($? != 0) {
	$rc = 0;
    }

    return($rc);
}


#
# verify that the specified name is one of the possible
# directories allowed on the LUKS device.
#
# returns
#   1 if verified
#   0 if not
#
sub verify_luks_directory_name
{
    my ($luks_dir_name) = @_;

    my $rc = 0;

    if ($IS_LUKS_DIR_NAME{$luks_dir_name}) {
	$rc = 1;
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


sub system_service_disable
{
    my ($service_name) = @_;

    system("/sbin/chkconfig --list | grep $service_name");
    if ($? == 0) {
	system("/sbin/service $service_name stop");
	system("/sbin/chkconfig $service_name off");
    }

    return(1);
}


#
# restart the system service
#
# returns
#   1 on success
#   0 if error
#
sub system_service_restart
{
    my ($service_name) = @_;

    my $rc = 1;

    my $exit_status = 1;
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	$exit_status = system("/sbin/service $service_name restart 2>> $LOGFILE");
    }
    if ($OS eq 'RHEL7') {
	$exit_status = system("/bin/systemctl restart $service_name 2>> $LOGFILE");
    }

    $rc = ($exit_status == 0) ? 1 : 0;

    return($rc);
}


############################################
##                                        ##
## subsection: LUKS                       ##
##                                        ##
############################################

sub tfr_luks_device_set_key
{
    my ($luks_key_clo) = @_;

    if ($luks_key_clo) {
	loginfo("[luks set key] LUKS key specified on command line");
	$LuksKey = $luks_key_clo;
    }
    else {
	loginfo("[luks set key] LUKS key determined by hardware");
	$LuksKey = OSTools::Hardware::hw_serial_number();
	# if the hardware serial number is zero, use a default key
	if ($LuksKey eq '0') {
	    $LuksKey = "Pwklk+82rT";
	}
    }

    return($LuksKey);
}


sub tfr_luks_device_key_file
{
    # make a temp file for the luks key
    my ($lkfh, $luks_key_file_path) = tempfile($LUKS_KEY_FILE_TEMPLATE, DIR => $LUKS_KEY_FILE_DIR);
    close($lkfh);

    # use the global luks key
    my $key = $LuksKey;

    # put the key in a temp file and init the device
    if (open(my $fh, '>', $luks_key_file_path)) {
	print {$fh} "$key\n";
	close($fh);

	# shutdown perms
	chmod oct(400), $luks_key_file_path;

	loginfo("[luks_device_key_file] LUKS key written to: $luks_key_file_path");
    }
    else {
	logerror("[luks_device_key_file] could not open LUKS key file for write: $luks_key_file_path");
    }

    return($luks_key_file_path);
}


sub tfr_luks_device_get_uuid
{
    my ($device) = @_;

    my $ml = '[luks_device_get_uuid]';

    my $luks_uuid = $EMPTY_STR;
    my $blkid_cmd = "blkid $device";
    loginfo("$ml $blkid_cmd");
    if (open(my $pipe, q{-|}, $blkid_cmd)) {
	my $blkid_out = <$pipe>;
	chomp($blkid_out);
	close($pipe);

	if ($blkid_out =~ /^$device: UUID="(.+)" TYPE="crypto_LUKS"/) {
	    $luks_uuid = $1;
	    loginfo("$ml UUID for LUKS device found: $luks_uuid");
	}
	else {
	    logerror("$ml could not get UUID for LUKS device: $device");
	}
    }
    else {
	logerror("$ml could not open pipe: $blkid_cmd");
    }

    return($luks_uuid);
}

sub tfr_luks_device_get_name
{
    my ($device) = @_;

    my $luks_name = $EMPTY_STR;
    my $ml = '[luks_device_get_name]';

    my $luks_uuid = tfr_luks_device_get_uuid($device);
    if ($luks_uuid) {
	$luks_name = 'luks-' . $luks_uuid;
    }
    else {
	logerror("$ml could not get UUID of LUKS device: $device");
    }

    return($luks_name);
}

sub tfr_luks_device_get_mapping
{
    my ($device) = @_;

    my $luks_mapping = $EMPTY_STR;
    my $ml = '[luks_device_get_mapping]';
    
    my $luks_name = tfr_luks_device_get_name($device);
    if ($luks_name) {
	$luks_mapping = '/dev/mapper/' . $luks_name;
    }
    else {
	logerror("$ml could not make name for LUKS device: $device");
    }

    return($luks_mapping);
}

sub tfr_luks_device_format
{
    my ($device) = @_;

    my $rc = 1;
    my $ml = '[luks_device_format]';

    my $luks_key_file_path = tfr_luks_device_key_file();
    if ($luks_key_file_path) {

	my $luks_cmd = "cryptsetup -q luksFormat $device $luks_key_file_path";
	loginfo("$ml $luks_cmd");
	system("$luks_cmd >> $LOGFILE 2>> $LOGFILE");
	if ($? == 0) {
	    loginfo("$ml successful format of LUKS device: $device");
	}
	else {
	    logerror("$ml could not format LUKS device: $device");
	    $rc = 0;
	}

	# remove the temp file
	if (unlink $luks_key_file_path) {
	    loginfo("[luks_device_init] temp key file unlinked: $luks_key_file_path");
	}
	else {
	    logerror("[luks_device_init] could not unlink temp key file: $luks_key_file_path");
	}
    }
    else {
	logerror("$ml could not write LUKS device key to temp file");
	$rc = 0;
    }


    return($rc);
}

sub tfr_luks_device_open
{
    my ($device) = @_;

    my $rc = 1;
    my $ml = '[luks_device_open]';

    my $luks_key_file_path = tfr_luks_device_key_file();
    if ($luks_key_file_path) {

	my $luks_name = tfr_luks_device_get_name($device);
	if ($luks_name) {
	    my $luks_cmd = "cryptsetup luksOpen $device $luks_name --key-file $luks_key_file_path";
	    loginfo("$ml LUKS cmd: $luks_cmd");
	    my $exit_status = system("$luks_cmd >> $LOGFILE 2>> $LOGFILE");
	    if ($exit_status == 0 ) {
		loginfo("$ml LUKS cmd successful");
	    }
	    else {
		$exit_status = tfr_exit_status_extract($exit_status);
		logerror("$ml LUKS cmd failed with exit_status: $exit_status");
		$rc = 0;
	    }

	    # remove the temp file for the key
	    if (unlink $luks_key_file_path) {
		loginfo("$ml temp key file unlinked: $luks_key_file_path");
	    }
	    else {
		logerror("$ml could not unlink temp key file: $luks_key_file_path");
	    }
	}
	else {
	    logerror("$ml could not make name for LUKS device: $device");
	    $rc = 0;
	}
    }
    else {
	logerror("$ml could not write LUKS key to temp file: $luks_key_file_path");
	$rc = 0;
    }

    return($rc);
}

sub tfr_luks_device_close
{
    my ($device) = @_;

    my $rc = 1;
    my $ml = '[luks_device_close]';

    my $luks_name = tfr_luks_device_get_name($device);
    if ($luks_name) {
	my $luks_cmd = "cryptsetup luksClose $luks_name";
	loginfo("$ml LUKS cmd: $luks_cmd");
	my $exit_status = system("$luks_cmd >> $LOGFILE 2>> $LOGFILE");
	if ($exit_status == 0) {
		loginfo("$ml LUKS cmd successful");
	}
	else {
	    $exit_status = tfr_exit_status_extract($exit_status);
	    logerror("$ml LUKS cmd failed with exit_status: $exit_status");
	    $rc = 0;
	}
    }
    else {
	logerror("$ml could not make name for LUKS device: $device");
	$rc = 0;
    }

    return($rc);
}


#
# open and mount a LUKS device
#
# returns
#   1 for success
#   0 for error
#
sub tfr_luks_device_mount
{
    my ($device) = @_;

    my $rc = 1;
    my $ml = '[luks_device_mount]';

    if (tfr_luks_device_open($device)) {

	my $luks_path = tfr_luks_device_get_mapping($device);
	if ($luks_path) {
	    my $luks_cmd = "mount $luks_path $MOUNTPOINT";
	    loginfo("$ml LUKS cmd: $luks_cmd");
	    system("$luks_cmd >> $LOGFILE 2>> $LOGFILE");
	    if ($? == 0) {
		loginfo("$ml successful mount: $luks_path, $MOUNTPOINT");
	    }
	    else {
		showerror("$ml could not mount LUKS device: $luks_path, $MOUNTPOINT");
		$rc = 0;
	    }
	}
	else {
	    showerror("$ml could not get device mapper path for LUKS device: $device");
	    $rc = 0;
	}
    }
    else {
	showerror("$ml could not open LUKS device: $device");
	$rc = 0;
    }

    return($rc);
}


sub tfr_luks_device_umount
{
    my ($device) = @_;

    my $rc = 1;

    my $cmd = "umount $MOUNTPOINT";
    system($cmd);
    if ($? == 0) {
	loginfo("[luks umount] successful umount: $device");

	if (tfr_luks_device_close($device)) {
	    loginfo("[luks umount] successful close of LUKS device: $device");
	}
	else {
	    logerror("[luks umount] could not close LUKS device: $device");
	    $rc = 0;
	}
    }
    else {
	showerror("[luks umount] command returned non-zero exit status: $cmd");
	$rc = 0;
    }

    return($rc);
}


sub tfr_luks_device_is_luks
{
    my ($device) = @_;

    my $rc = 1;
    my $ml = '[luks_device_is_luks]';

    my $luks_cmd = "cryptsetup isLuks";
    loginfo("$ml cmd: $luks_cmd $device");
    my $exit_status = system ("$luks_cmd $device > /dev/null 2>&1");
    if ($exit_status == 0) {
	loginfo("$ml device is a LUKS device: $device");
    }
    else {
	loginfo("$ml exit status: $exit_status; device is NOT a LUKS device: $device");
	$rc = 0;
    }

    return($rc);
}

sub tfr_luks_device_get_status
{
    my ($device) = @_;

    my $rc = 1;
    my $ml = '[luks_device_get_status]';

    if (tfr_luks_device_open($device)) {
	my $luks_name = tfr_luks_device_get_name($device);
	if ($luks_name) {
	    my $luks_cmd = "cryptsetup status $luks_name";
	    loginfo("$ml cmd: $luks_cmd");
	    my $exit_status = system ("$luks_cmd");
	    if ($exit_status != 0) {
		logerror("$ml exit status: $exit_status");
		$rc = 0;
	    }
	}
	else {
	    logerror("$ml could not get name of LUKS device: $device");
	    $rc = 0;
	}
	if (tfr_luks_device_close($device)) {
	    loginfo("$ml successful close of LUKS device: $device");
	}
	else {
	    logerror("$ml could not close LUKS device: $device");
	    $rc = 0;
	}
    }
    else {
	logerror("$ml could not open LUKS device: $device");
	$rc = 0;
    }

    return($rc);
}


sub tfr_luks_device_verify
{
    my ($device) = @_;

    my $rc = 1;

    my $luks_cmd = "cryptsetup luksDump $device";
    loginfo("[luks_device_verify] $luks_cmd");
    system ("$luks_cmd $device > /dev/null 2>&1");
    if ($? == 0) {
	loginfo("[luks_device_verify] LUKS disk device verified: $device");
    }
    else {
	loginfo("[luks_device_verify] not a LUKS disk device: $device");
	$rc = 0;
    }

    return($rc);
}


sub tfr_luks_device_report_label
{
    my ($device) = @_;

    my $rc = 1;
    my $ml = '[luks_device_report_label]';

    if (tfr_luks_device_open($device)) {

	my $luks_path = tfr_luks_device_get_mapping($device);
	if ($luks_path) {
	    my $e2label_cmd = "/sbin/e2label $luks_path";
	    if (open(my $pipe, q{-|}, $e2label_cmd)) {
		my $e2label_out = <$pipe>;
		chomp($e2label_out);
		close($pipe);

		if ($e2label_out =~ /TFBULUKS[0-9]{8}/) {
		    print "$e2label_out\n";
		    loginfo("$ml Teleflora LUKS label found: $e2label_out");
		}
		else {
		    logerror("$ml could not find Teleflora LUKS label: $e2label_out");
		    $rc = 0;
		}
	    }
	    else {
		logerror("$ml could not open pipe: $e2label_cmd");
		$rc = 0;
	    }
	}
	else {
	    showerror("$ml could not get device mapper path for LUKS device: $device");
	    $rc = 0;
	}

	if (tfr_luks_device_close($device)) {
	    loginfo("$ml successful close of LUKS device: $device");
	}
	else {
	    logerror("$ml could not close LUKS device: $device");
	    $rc = 0;
	}
    }
    else {
	showerror("$ml could not open LUKS device: $device");
	$rc = 0;
    }

    return($rc);
}


sub tfr_luks_device_record_backup_date
{
    my ($device) = @_;

    my $rc = 1;

    my $time_stamp_file = tfrm_pathto_luks_time_stamp();
    if (open(my $tsfh, '>', $time_stamp_file)) {
	my $now_time = localtime;
	print {$tsfh} "$now_time\n";
	close($tsfh);
    }
    else {
	showerror("[luks_device_record_backup_date] could not make backup date file on: $device");
	showerror("[luks_device_record_backup_date] could not open backup date file: $time_stamp_file");
    }

    system("touch $time_stamp_file");
    if (-f $time_stamp_file) {
	loginfo("[luks_device_record_backup_date] backup time recorded on: $device");
	loginfo("[luks_device_record_backup_date] backup time recorded in: $time_stamp_file");
    }
    else {
	showerror("[luks_device_record_backup_date] could not make backup date file on: $device");
	showerror("[luks_device_record_backup_date] could not touch backup date file: $time_stamp_file");
	$rc = 0;
    }

    return($rc);
}


sub tfr_luks_device_get_backup_date
{
    my ($device) = @_;

    my $rc = 1;

    if (tfr_luks_device_mount($device)) {

	my $time_stamp_file = tfrm_pathto_luks_time_stamp();
	if (open(my $tsfh, '<', $time_stamp_file)) {
	    my $luks_device_backup_date = <$tsfh>;
	    chomp($luks_device_backup_date);
	    close($tsfh);

	    print "LUKS device backup date: $luks_device_backup_date\n";
	    loginfo("[luks_device_get_backup_date] LUKS disk device backup date: $luks_device_backup_date");
	}
	else {
	    showerror("[luks_device_get_backup_date] could not open backup date file on: $device");
	}

	tfr_luks_device_umount($device);
    }

    return($rc);
}


sub tfr_luks_device_file_verify
{
    my ($luks_device, $luks_bucket, $file) = @_;

    my $rc = 1;

    if (tfr_luks_device_mount($luks_device)) {

	my $search_dir = tfrm_pathto_luks_bucket($luks_bucket);
	my $search_term = $file;
	find(sub {print "$File::Find::name\n" if m/$search_term/}, $search_dir);

	tfr_luks_device_umount($luks_device);
    }

    return($rc);
}


sub tfr_luks_device_file_restore
{
    my ($luks_device, $luks_bucket, $luks_file, $restore_dir) = @_;

    my $rc = 1;

    if (tfr_luks_device_mount($luks_device)) {

	my $search_dir = tfrm_pathto_luks_bucket($luks_bucket);
	my $search_term = $luks_file;
	my @search_results = ();
	find(
	    sub {
		if ($File::Find::name =~ m/$search_term/) {
		    push(@search_results, $File::Find::name);
		}
	    }, $search_dir);
	if (@search_results) {
	    print "restoration directory: $restore_dir\n";
	}
	foreach my $src_path (@search_results) {
	    my $target = tfr_util_rm_prefix($search_dir, $src_path);
	    next if ($target eq $EMPTY_STR);
	    my $dst_path = File::Spec->catdir($restore_dir, $target);
	    if (-d $src_path) {
		# if the directory does not exist on destination
		if (! -d $dst_path) {
		    print "restoring directory: $target\n";
		    system("mkdir -p $dst_path");
		    system("chmod --reference=$src_path $dst_path");
		    system("chown --reference=$src_path $dst_path");
		}
		if (! is_dir_empty($src_path)) {
		    print "restoring contents of directory: $target\n";
		    system("sudo cp -pr $src_path/* $dst_path");
		}
	    }
	    else {
		my $dst_dir = dirname($dst_path);
		# if the enclosing directory does not exist on destination
		if (! -d $dst_dir) {
		    system("mkdir -p $dst_dir");
		    my $src_dir = dirname($src_path);
		    system("chmod --reference=$src_dir $dst_dir");
		    system("chown --reference=$src_dir $dst_dir");
		}
		print "restoring file: $target\n";
		system("sudo cp -pr $src_path $dst_path");
	    }
	}

	tfr_luks_device_umount($luks_device);
    }

    return($rc);
}


sub tfr_luks_device_initialize
{
    my ($device) = @_;

    my $rc = 1;
    my $ml = '[luks_device_initialize]';

    if (tfr_luks_device_format($device)) {

	if (tfr_luks_device_open($device)) {

	    my $luks_path = tfr_luks_device_get_mapping($device);
	    if ($luks_path) {

		my $label_brand = "TFBULUKS";
		my $label_datestamp = POSIX::strftime("%Y%m%d", localtime());
		my $label_disk = $label_brand . $label_datestamp;
		my $mkfs_cmd = "mkfs -t ext3 -L $label_disk $luks_path";
		loginfo("$ml $mkfs_cmd");
		system("$mkfs_cmd");
		if ($? == 0 ) {
		    loginfo("$ml successful mkfs of ext3 file system: $luks_path");

		    my $tune_cmd = "/sbin/tune2fs -c 0 -e remount-ro -i 12m -U time $luks_path";
		    system("$tune_cmd 2>&1 | tee -a $LOGFILE");
		    if ($? == 0 ) {
			loginfo("$ml Set max mount count to 0, thus disabling it");
			loginfo("$ml Set error behavior to \"remount read-only on error\"");
			loginfo("$ml Set FSCK interval to 12 months");
			loginfo("$ml Set UUID of file system to time based");
		    }
		    else {
			logerror("$ml could not tune2fs: $device");
			$rc = 0;
		    }

		    if ($OS eq 'RHEL6') {
			loginfo("$ml delaying to let device become unbusy: $device");
			sleep(10);
		    }
		}
		else {
		    logerror("$ml could not mkfs of ext3 file system: $luks_path");
		    $rc = 0;
		}
	    }
	    else {
		showerror("$ml could not get device mapper path for LUKS device: $device");
		$rc = 0;
	    }

	    if (tfr_luks_device_close($device)) {
		loginfo("$ml successful close of LUKS device: $device");
	    }
	    else {
		logerror("$ml could not close LUKS device: $device");
		$rc = 0;
	    }
	}
	else {
	    logerror("$ml could not open LUKS device: $device");
	    $rc = 0;
	}
    }
    else {
	logerror("$ml could not format LUKS device: $device");
	$rc = 0;
    }

    return($rc);
}


#
# if the luks bucket day of the month was specified on the command line,
# return that.
#
# else return the current day of the month.
#
sub tfr_luks_device_bucket_day
{
    if ($LuksBucketDayCLO > 0) {
	return($LuksBucketDayCLO);
    }

    return(POSIX::strftime("%d", localtime(time)));
}


#
# rotate luks buckets
#
# NOTE: assumes luks device is mounted
#
# each luks device will have 4 buckets:
#   today
#   yesterday
#   weekly
#   monthly
#
sub tfr_luks_device_rotate_buckets
{
    my ($dev_attr) = @_;

    my $rc = 1;

    loginfo("[luks rotate] rotate luks device buckets if necessary: $dev_attr->{DEVICE}");

    my $luks_path_today = tfrm_pathto_luks_bucket($LUKS_BUCKET_TODAY);
    my $luks_path_yesterday = tfrm_pathto_luks_bucket($LUKS_BUCKET_YESTERDAY);
    my $luks_path_temp = tfrm_pathto_luks_bucket($LUKS_BUCKET_TEMP);

    if (-e $luks_path_today) {
	my $st = File::stat::stat($luks_path_today);
	my $today_bucket_day = POSIX::strftime("%d", localtime($st->mtime));
	loginfo("[luks rotate] today bucket exists with month day: $today_bucket_day");

	my $current_day = tfr_luks_device_bucket_day();
	loginfo("[luks rotate] current month day: $current_day");

	if ($current_day == $today_bucket_day) {
	    loginfo("[luks rotate] rotate not necessary: $dev_attr->{DEVICE}");
	}
	else {

	    # rename "today" to "today-temp"
	    rename $luks_path_today, $luks_path_temp;
	    loginfo("[luks rotate] $luks_path_today renamed to: $luks_path_temp");

	    # if "yesterday" exists, rename to "today"
	    if (-e $luks_path_yesterday) {
		rename $luks_path_yesterday, $luks_path_today;
		loginfo("[luks rotate] $luks_path_yesterday renamed to: $luks_path_today");
		utime undef, undef, $luks_path_today;
		loginfo("[luks rotate] mtime set to today's date: $luks_path_today");
	    }

	    # if "today_temp" exists, rename to "yesterday"
	    if (-e $luks_path_temp) {
		rename $luks_path_temp, $luks_path_yesterday;
		loginfo("[luks rotate] $luks_path_temp renamed to: $luks_path_yesterday");
	    }
	}
    }
    else {
	if (-e $luks_path_yesterday) {
	    rename $luks_path_yesterday, $luks_path_today;
	    loginfo("[luks rotate] $luks_path_yesterday renamed to: $luks_path_today");
	}
    }

    if (! -e $luks_path_today) {
	mkdir $luks_path_today;
	loginfo("[luks rotate] mkdir of: $luks_path_today");
    }

    return($rc);
}


sub tfr_luks_device_cyclic_buckets
{
    my ($bu_attr, $dev_attr) = @_;

    my $rc = 1;

    my $day_name = POSIX::strftime("%a", localtime(time));
    if ($day_name eq 'Sun') {
	if (tfr_luks_device_mount($dev_attr->{DEVICE})) {
	    my $luks_path_weekly = tfrm_pathto_luks_bucket($LUKS_BUCKET_WEEKLY);
	    if (-e $luks_path_weekly) {
		utime undef, undef, $luks_path_weekly;
		loginfo("[luks cyclic] mtime set to today's date: $luks_path_weekly");
	    }
	    else {
		mkdir $luks_path_weekly;
		loginfo("[luks cyclic] mkdir of: $luks_path_weekly");
	    }
	    tfr_luks_device_umount($dev_attr->{DEVICE});

	    $dev_attr->{DEVDIR} = tfrm_pathto_luks_bucket($LUKS_BUCKET_WEEKLY);
	    if (tfr_backup_files($bu_attr, $dev_attr) == $EXIT_OK) {
		loginfo("[luks cyclic] backup of weekly bucket successful: $dev_attr->{DEVDIR}");
	    }
	    else {
		logerror("[luks cyclic] could not backup weekly bucket: $dev_attr->{DEVDIR}");
		$rc = 0;
	    }
	}
	else {
	    logerror("[luks cyclic] could not mount LUKS device: $dev_attr->{DEVICE}");
	    $rc = 0;
	}
    }

    my $month_day = POSIX::strftime("%d", localtime(time));
    if ($month_day == 1) {
	if (tfr_luks_device_mount($dev_attr->{DEVICE})) {
	    my $luks_path_monthly = tfrm_pathto_luks_bucket($LUKS_BUCKET_MONTHLY);
	    if (-e $luks_path_monthly) {
		utime undef, undef, $luks_path_monthly;
		loginfo("[luks cyclic] mtime set to today's date: $luks_path_monthly");
	    }
	    else {
		mkdir $luks_path_monthly;
		loginfo("[luks cyclic] mkdir of: $luks_path_monthly");
	    }
	    tfr_luks_device_umount($dev_attr->{DEVICE});

	    $dev_attr->{DEVDIR} = tfrm_pathto_luks_bucket($LUKS_BUCKET_MONTHLY);
	    if (tfr_backup_files($bu_attr, $dev_attr) == $EXIT_OK) {
		loginfo("[luks cyclic] backup of monthly bucket successful: $dev_attr->{DEVDIR}");
	    }
	    else {
		logerror("[luks cyclic] could not backup monthly bucket: $dev_attr->{DEVDIR}");
		$rc = 0;
	    }
	}
	else {
	    logerror("[luks cyclic] could not mount LUKS device: $dev_attr->{DEVICE}");
	    $rc = 0;
	}
    }

    return($rc);
}

#
# install for the luks device
#
# 0) make the top level backup dir
# 1) make the transfer dir
# 2) make the pserver info dir
# 3) make the pserver cloister dir
# 4) make the users info dir
# 5) remove old cron job
# 6) add new cron job
# 9) install the default tfrsync config file
#
sub tfr_luks_device_install
{
    my $lt = '[luks_device_install]';

    loginfo("$lt LUKS device installation");

    # make the top level backup dir if necessary
    my $top_level_bu_dir = tfrm_pathto_project_bu_dir();
    if (tfr_util_mkdir($top_level_bu_dir)) {
	loginfo("$lt mkdir of top level tfrsync backup dir successful: $top_level_bu_dir");
    }
    else {
	showerror("$lt could not make top level tfrsync backup dir: $top_level_bu_dir");
	return(0);
    }

    # make the transfer dir if necessary
    my $pserver_xferdir_path = tfrm_pathto_pserver_xferdir();
    if (tfr_util_mkdir($pserver_xferdir_path)) {
	loginfo("$lt mkdir of pserver transfer dir successful: $pserver_xferdir_path");
    }
    else {
	showerror("$lt could not make pserver transfer dir: $pserver_xferdir_path");
	return(0);
    }

    # make the pserver info dir if necessary
    my $pserver_infodir_path = tfrm_pathto_pserver_info_dir();
    if (tfr_util_mkdir($pserver_infodir_path)) {
	loginfo("$lt mkdir of pserver info dir successful: $pserver_infodir_path");
    }
    else {
	showerror("$lt could not make pserver info dir: $pserver_infodir_path");
	return(0);
    }

    # make the pserver cloister dir if necessary
    my $pserver_cloister_dir_path = tfrm_pathto_pserver_cloister_dir();
    if (tfr_util_mkdir($pserver_cloister_dir_path)) {
	loginfo("$lt mkdir of pserver cloister dir successful: $pserver_cloister_dir_path");
    }
    else {
	showerror("$lt could not make pserver cloister dir: $pserver_cloister_dir_path");
	return(0);
    }

    # make the users info dir if necessary
    my $users_infodir_path = tfrm_pathto_users_info_dir();
    if (tfr_util_mkdir($users_infodir_path)) {
	loginfo("$lt mkdir of users info dir successful: $users_infodir_path");
    }
    else {
	logerror("$lt could not make users info dir: $users_infodir_path");
	return(0);
    }

    # remove the old cron job if it exists
    if (! tfr_cron_job_cleanup($CRON_JOB_OLD)) {
	showerror("$lt could not clean up old cron job: $CRON_JOB_OLD");
	return(0);
    }

    # install a new cron job
    my $cron_job_type = tfr_cron_job_type($DEVTYPE_LUKS);
    if (tfr_cron_job_add($cron_job_type)) {
	my $cron_job_path = tfr_cron_job_path($cron_job_type);
	loginfo("$lt new cron job installed: $cron_job_path");
    }
    else {
	showerror("$lt could not install cron job type: $cron_job_type");
	return(0);
    }

    # install the default config file - careful - the name of the
    # default config file might have changed, ie it might have a
    # ".new" suffix on it.
    my $conf_file_path = tfrm_pathto_def_tfrsync_config_file();
    my $installed_conf_file_path = tfr_install_default_config_file($conf_file_path);
    if ($installed_conf_file_path) {
	loginfo("$lt new default config file installed: $installed_conf_file_path");
    }
    else {
	showerror("$lt could not install default config file: $conf_file_path");
	return(0);
    }

    return(1);
}


############################################
##                                        ##
## subsection: "pathto" and "nameof" subs ##
##                                        ##
############################################

sub tfr_pathto_rti_dir
{
    return($RTIDIR);
}

sub tfr_pathto_rti_shopcode_file
{
    return($RTI_SHOPCODE_FILE);
}

sub tfr_pathto_daisy_dir
{
    return($DAISYDIR);
}

sub tfr_pathto_daisy_shopcode_file
{
    return($DAISY_SHOPCODE_FILE);
}

sub tfrm_pathto_harden_linux_cmd
{
    return("$RTI_TOOLS_BINDIR/harden_linux.pl") if ($RTI);
    return("$DAISY_TOOLS_BINDIR/harden_linux.pl") if ($DAISY);
    return("/teleflora/ostools/bin/harden_linux.pl");
}

sub tfrm_pathto_project_bu_dir
{
    return($DEF_RTI_RSYNC_BU_DIR) if ($RTI);
    return($DEF_DAISY_RSYNC_BU_DIR) if ($DAISY);
    return($EMPTY_STR);
}

sub tfrm_pathto_def_tfrsync_config_file
{
    return($TFRSYNC_CONFIG_FILE_PATH);
}

sub tfrm_pathto_def_tfrsync_config_dir
{
    return($TFRSYNC_CONFIG_DIR_PATH);
}

sub tfrm_pathto_config_file
{
    return($CONFIGFILE);
}

sub tfrm_pathto_logfile_dir
{
    return($LogfileDir);
}

sub tfrm_pathto_logfile
{
    return($LOGFILE);
}

sub tfrm_pathto_summary_logfile
{
    return($SummaryLogfile);
}

sub tfrm_pathto_debug_logfile
{
    return($DebugLogfile);
}

sub tfrm_pathto_users_info_dir
{
    my $bu_dir = tfrm_pathto_project_bu_dir();
    if ($bu_dir) {
	return($bu_dir . $SLASH . $USERS_INFO_DIR);
    }
    return($EMPTY_STR);
}

sub tfrm_pathto_perm_file
{
    my ($bu_type) = @_;

    my $perm_file_dir = tfrm_pathto_project_bu_dir();
    my $perm_file_name = tfrm_nameof_perm_file($bu_type);
    my $bu_perm_file_path = $perm_file_dir . $SLASH . $perm_file_name;

    return($bu_perm_file_path);
}

sub tfrm_pathto_pos_users_script
{
    if ($RTI) {
	return("$RTI_BINDIR/rtiuser.pl");
    }
    if ($DAISY) {
	return("$DAISY_BINDIR/dsyuser.pl");
    }
    return($EMPTY_STR);
}

sub tfrm_pathto_pserver_info_dir
{
    return(tfrm_pathto_project_bu_dir() . $SLASH . $PSERVER_INFO_DIR);
}

sub tfrm_pathto_pserver_info_file
{
    return(tfrm_pathto_pserver_info_dir() . $SLASH . $PSERVER_INFO_FILE);
}

sub tfrm_pathto_restored_pserver_info_dir
{
    return(File::Spec->catdir(tfrm_pathto_pserver_info_dir(),
			      tfrm_nameof_restored_pserver_info_dir()));
}

sub tfrm_pathto_restored_pserver_info_file
{
    return(File::Spec->catdir(tfrm_pathto_restored_pserver_info_dir(),
			      tfrm_nameof_pserver_info_file()));
}

sub tfrm_pathto_buserver_info_dir
{
    return(tfrm_pathto_project_bu_dir() . $SLASH . $BUSERVER_INFO_DIR);
}

sub tfrm_pathto_bu_server_info_file
{
    return(tfrm_pathto_buserver_info_dir() . $SLASH . $BUSERVER_INFO_FILE);
}

sub tfrm_pathto_pserver_cloister_dir
{
    return(tfrm_pathto_project_bu_dir() . $SLASH . $PSERVER_CLOISTER_DIR);
}

#
# return the path to production server transfer dir.
#
# Returns
#   path to xfer dir on success
#   partial path if error
#
sub tfrm_pathto_pserver_xferdir
{
    my $tfsupport = tfr_tfsupport_account_name();
    my $homedir = tfr_accounts_homedir($tfsupport);
    return($homedir . $SLASH . $PSERVER_XFER_DIR);
}

sub tfrm_pathto_xferdir_keydir
{
    my ($device_type) = @_;

    my $keydir_path = $EMPTY_STR;

    my $xferdir_keydir_name = tfrm_nameof_xferdir_keydir($device_type);
    $keydir_path = File::Spec->catdir(tfrm_pathto_pserver_xferdir(), $xferdir_keydir_name);

    return($keydir_path);
}

sub tfrm_pathto_xferdir_keydir_key
{
    my ($device_type) = @_;

    return(File::Spec->catfile(tfrm_pathto_xferdir_keydir($device_type), $SSH_KEY_FILENAME_PUBLIC));
}

sub tfrm_pathto_users_listing_file
{
    my $pathto_users_info_dir = tfrm_pathto_users_info_dir();
    my $nameof_users_listing_file = tfrm_nameof_users_listing_file();
    my $pathto_users_listing_file = File::Spec->catdir($pathto_users_info_dir, $nameof_users_listing_file);
    return($pathto_users_listing_file);
}

sub tfrm_pathto_users_shadow_file
{
    my $pathto_users_info_dir = tfrm_pathto_users_info_dir();
    my $nameof_users_shadow_file = tfrm_nameof_users_shadow_file();
    my $pathto_users_shadow_file = File::Spec->catdir($pathto_users_info_dir, $nameof_users_shadow_file);
    return($pathto_users_shadow_file);
}

sub tfr_pathto_ssh_tunnel_socket
{
    my $ssh_socket_path = $EMPTY_STR;

    if ( ($DeviceType eq $DEVTYPE_SERVER) || ($DeviceType eq $DEVTYPE_CLOUD) ) {
	my $ssh_socket_dir_path = $DEF_SSH_SOCKET_DIR_PATH;
	my $ssh_socket_file_name = $DEF_SSH_SOCKET_PREFIX . $DeviceType . $DEF_SSH_SOCKET_EXT;
	$ssh_socket_path = File::Spec->catdir($ssh_socket_dir_path, $ssh_socket_file_name);
    }

    return($ssh_socket_path);
}


#
# Given an account name, return the path to the ssh id file.
#
# Returns
#   path to file on success
#   empty string on error
#
sub tfr_pathto_ssh_id_file
{
    my ($account_name) = @_;

    my $ssh_id_path = $EMPTY_STR;

    my $sshdir_path = tfr_sshdir_default_path($account_name);
    if ($sshdir_path) {
	$ssh_id_path = File::Spec->catdir($sshdir_path, $SSH_KEY_FILENAME);
    }

    return($ssh_id_path);
}


#
# Given an account name, form the path to the authorized keys file.
#
# Returns
#   path to authorized keys file success
#   empty string on error
#
sub tfr_pathto_ssh_auth_keys_file
{
    my ($account_name) = @_;

    my $auth_keys_path = $EMPTY_STR;

    my $sshdir_path = tfr_sshdir_default_path($account_name);
    if ($sshdir_path) {
	$auth_keys_path = File::Spec->catdir($sshdir_path, $SSH_AUTH_KEYS_FILENAME);
    }

    return($auth_keys_path);
}


#
# Given an account name, return the path to the public key file.
#
# Input
#   account name
#
# Returns
#   path to key file on success
#   empty string on error
#
sub tfr_pathto_ssh_public_key_file
{
    my ($account_name) = @_;

    my $public_key_path = $EMPTY_STR;

    my $sshdir_path = tfr_sshdir_default_path($account_name);
    if ($sshdir_path) {
	$public_key_path = File::Spec->catdir($sshdir_path, $SSH_KEY_FILENAME_PUBLIC);
    }

    return($public_key_path);
}

 
sub tfrm_pathto_luks_bucket
{
    my ($bucket_type) = @_;

    my $bucket_path = $EMPTY_STR;

    if ( ($bucket_type eq $LUKS_BUCKET_TODAY) ||
	 ($bucket_type eq $LUKS_BUCKET_YESTERDAY) ||
	 ($bucket_type eq $LUKS_BUCKET_WEEKLY) ||
	 ($bucket_type eq $LUKS_BUCKET_MONTHLY) ||
	 ($bucket_type eq $LUKS_BUCKET_TEMP) ) {

	$bucket_path = File::Spec->catdir($MOUNTPOINT, $bucket_type);
    }

    return($bucket_path);
}

sub tfrm_pathto_luks_time_stamp
{
    return(File::Spec->catdir($MOUNTPOINT,  $LUKS_TIME_STAMP_FILE));
}

#
# given a backup type, return the name of the perm file
# for that type.
#
# always returns a non-empty string.
#
sub tfrm_nameof_perm_file
{
    my ($bu_type) = @_;

    my $perm_file_name = $bu_type . tfrm_suffixof_perm_file();

    return($perm_file_name);
}

#
# return name of users listing file.
#
sub tfrm_nameof_users_listing_file
{
    return($RTI_USERS_LISTING_FILE) if ($RTI);
    return($DAISY_USERS_LISTING_FILE) if ($DAISY);
    return($EMPTY_STR);
}

#
# return name of users shadow file.
#
sub tfrm_nameof_users_shadow_file
{
    return($RTI_USERS_SHADOW_FILE) if ($RTI);
    return($DAISY_USERS_SHADOW_FILE) if ($DAISY);
    return($EMPTY_STR);
}

sub tfrm_nameof_pserver_info_file
{
    return($PSERVER_INFO_FILE);
}

sub tfrm_nameof_restored_pserver_info_dir
{
    return($RESTORED_PSERVER_INFO_DIR);
}

sub tfrm_nameof_xferdir_keydir
{
    my ($device_type) = @_;

    my $keydir_name = $EMPTY_STR;

    if ($device_type eq $DEVTYPE_CLOUD) {
	$keydir_name = $DEVTYPE_CLOUD . '.d';
    }
    if ($device_type eq $DEVTYPE_SERVER) {
	$keydir_name = $DEVTYPE_SERVER . '.d';
    }

    return($keydir_name);
}

sub tfrm_suffixof_perm_file
{
    return($PERM_FILE_SUFFIX);
}


#
# produce a perm file for the specified files of the specified
# backup type.  Put it in the tfrsync backup dir.
#
# Save the results in a file whose name is the backup type
# with the perm file suffix.  Put the file in directory
# "/usr2/tfrsync" for RTI systems, "/d/tfrsync" for Daisy
# systems.
#
# To get the metadata, run the command "getfacl --absolute-names -R"
# on each backup item and concatenate text to a perms
# file.
#
# Returns
#   path to perms file on success
#   empty string on error
#
sub tfr_produce_perm_file
{
    my ($tobackup, $bu_type) = @_;

    my $bu_perm_file_path = tfrm_pathto_perm_file($bu_type);
    if (scalar(@{$tobackup})) {
	print "\n";
	showinfo("saving output to permfile: $bu_perm_file_path");
    }

    foreach my $src (@{$tobackup}) {
	if ($DRY_RUN) {
	    system("echo \"getfacl --absolute-names -R $src >> $bu_perm_file_path\"");
	}
	else {
	    my $cmd = "getfacl --absolute-names -R $src";
	    showinfo("command: $cmd");
	    system("$cmd >> $bu_perm_file_path");
	    my $exit_status = $?;
	    if ($exit_status == -1) {
		showerror("command failed to execute: $!");
	    }
	    elsif ($exit_status & 127) {
		my $signo = ($exit_status & 127);
		showerror("command died from signal: $signo");
	    }
	    else {
		$exit_status = ($exit_status >> 8);
		if ($exit_status != 0) {
		    showerror("command exit status non-zero: $exit_status");
		}
	    }
	}
    }

    return($bu_perm_file_path);
}


#
# top level sub for "--generate-permfiles"
#
# generate the perm files for a set of backup types.
#
# Returns
#   $EXIT_OK on success
#   $EXIT_GENERATE_PERMS if error generating perm file
#
sub tfr_generate_perm_files
{
    my (@bu_type_list) = @_;

    my $rc = $EXIT_OK;

    foreach my $bu_type (@bu_type_list) {
	my @toback = tfr_backup_file_list($bu_type);
	my $perm_file = tfr_produce_perm_file(\@toback, $bu_type);
	if (! $perm_file) {
	    showerror("error generating perm file for backup type: $bu_type");
	    $rc = $EXIT_GENERATE_PERMS;
	    last;
	}
    }

    return($rc);
}


#
# top level sub for "--upload-permfiles"
#
# upload any perm files located in the tfrsync backup dir
# to the cloud server.
#
# Returns
#   $EXIT_OK on success
#   $EXIT_SSH_ID_FILE if path to ssh id file does not exist
#   $EXIT_SSH_TUNNEL_OPEN if error opening master socket
#   $EXIT_UPLOAD_PERMS if error uploading a perm file
#   $EXIT_SSH_TUNNEL_CLOSE if error closing master socket
#
sub tfr_upload_perm_files
{
    my ($account_name, $cloud_server) = @_;

    my $rc = $EXIT_OK;

    my $rsync_bu_dir = tfrm_pathto_project_bu_dir();
    my $bu_perm_files_re = $rsync_bu_dir . q{/*} . tfrm_suffixof_perm_file();

    my @bu_perm_file_path_list = glob($bu_perm_files_re);
    if ($DRY_RUN) {
	foreach (@BACKUP_TYPES) {
	    my $bu_perm_file_path = $rsync_bu_dir . $SLASH . $_ . tfrm_suffixof_perm_file();
	    push(@bu_perm_file_path_list, $bu_perm_file_path);
	}
    }

    if (scalar(@bu_perm_file_path_list) == 0) {
	showinfo("there are no perm files to upload: $bu_perm_files_re");
	return($EXIT_OK);
    }

    # open the ssh tunnel socket
    if (! tfr_open_ssh_tunnel($account_name, $cloud_server)) {
	showerror("could not open ssh tunnel socket for perm upload: $account_name, $cloud_server");
	return($EXIT_SSH_TUNNEL_OPEN);
    }

    # form the rsync command
    my $rsync_cmd = tfr_construct_rsync_cmd($account_name, $DEVTYPE_CLOUD);

    # prefix for rsync source argument
    my $dst_prefix = $account_name . $ATSIGN . $cloud_server . $COLON;

    foreach my $bu_perm_file_path (@bu_perm_file_path_list) {
	my $src = $bu_perm_file_path;
	my $dst = $dst_prefix . basename($bu_perm_file_path);

	if ($DRY_RUN) {
	    system("echo \"$rsync_cmd $src $dst\"");
	}
	else {
	    system("$rsync_cmd $src $dst 2>> $LOGFILE");
	    if ($? != 0) {
		showerror("could not upload perm file: $bu_perm_file_path");
		$rc = $EXIT_UPLOAD_PERMS;
		last;
	    }
	}
    }

    if (! tfr_close_ssh_tunnel($account_name, $cloud_server)) {
	showerror("could not close ssh tunnel socket for perm upload: $account_name, $cloud_server");
	if ($rc == $EXIT_OK) {
	    $rc = $EXIT_SSH_TUNNEL_CLOSE;
	}
    }

    return($rc);
}


sub tfr_construct_rsync_cmd
{
    my ($account_name, $devtype) = @_;

    # start forming the rsync command
    my $rsync_cmd = "rsync -ahv";

    # add ssh identity file and ssh tunnel socket
    my $ssh_id_path = tfr_pathto_ssh_id_file($account_name);
    my $ssh_tunnel_socket_path = tfr_pathto_ssh_tunnel_socket();
    $rsync_cmd .= " -e \'ssh -i $ssh_id_path -o ControlPath=$ssh_tunnel_socket_path\'";

    # dry run or not
    if ($RSYNC_TRIAL) {
	$rsync_cmd .= " -n";
    }

    # add any extra options specified in config file
    foreach (@RSYNC_OPTIONS) {
	$rsync_cmd .= " $_";
    }

    return($rsync_cmd);
}


#
# get a perm file at the specifed source path on the
# cloud server using the specified rsync command and
# put it at the specified destination path.
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_get_perm_file
{
    my ($rsync_cmd) = @_;

    my $rc = 0;

    # exec the remote command
    if ($DRY_RUN) {
	system("echo \"$rsync_cmd\"");
    }
    else {
	loginfo("Execing rsync command:");
	loginfo($rsync_cmd);

	system("$rsync_cmd 2>> $LOGFILE");
	if ($? == 0) {
	    $rc = 1;
	}
	else {
	    showerror("error returned by rsync command: $?");
	}
    }

    return($rc);
}


#
# top level sub for "--download-permfiles"
#
# For the specified account on the specified cloud server,
# get the perm file for each of the specified backup types.
#
# Returns
#   $EXIT_OK on success
#   $EXIT_SSH_ID_FILE if ssh identity file not found 
#   $EXIT_SSH_TUNNEL_OPEN if open of ssh tunnel fails
#   $EXIT_DOWNLOAD_PERMS if download fails
#
sub tfr_download_perm_files
{
    my ($account_name, $cloud_server, @bu_type_list) = @_;

    my $rc = $EXIT_OK;

    # open the ssh tunnel socket
    if (! tfr_open_ssh_tunnel($account_name, $cloud_server)) {
	showerror("could not open ssh tunnel socket for perm download: $account_name, $cloud_server");
	return($EXIT_SSH_TUNNEL_OPEN);
    }

    # form the rsync command
    my $rsync_cmd = tfr_construct_rsync_cmd($account_name, $DEVTYPE_CLOUD);

    # prefix for rsync source argument
    my $src_prefix = $account_name . $ATSIGN . $cloud_server . $COLON;

    # for each backup type, download corresponding perm file
    foreach my $bu_type (@bu_type_list) {
	my $src_path = $src_prefix . tfrm_nameof_perm_file($bu_type);
	my $dst_path = tfrm_pathto_perm_file($bu_type);
	
	$rsync_cmd .= " $src_path $dst_path";

	if (! tfr_get_perm_file($rsync_cmd)) {
	    showerror("could not download perm file: $dst_path");
	    $rc = $EXIT_DOWNLOAD_PERMS;
	    last;
	}
    }

    if (tfr_close_ssh_tunnel($account_name, $cloud_server)) {
	loginfo("ssh tunnel socket for perm download closed: $account_name, $cloud_server");
    }
    else {
	showerror("could not close ssh tunnel socket for perm download: $account_name, $cloud_server");
	if ($rc == $EXIT_OK) {
	    $rc = $EXIT_SSH_TUNNEL_CLOSE;
	}
    }

    return($rc);
}


#
# top level sub for "--restore-from-permfiles"
#
# for the specified account on the cloud server, set
# the perms for the specified backup type.
#
# Returns
#   $EXIT_OK on success
#   $EXIT_RESTORE_PERMS if perms could not be restored
#   $EXIT_PERM_FILE_MISSING if perm file does not exist
#
sub tfr_restore_from_perm_files
{
    my ($account_name, $cloud_server, @bu_type_list) = @_;

    my $rc = $EXIT_OK;

    foreach my $bu_type (@bu_type_list) {
	my $perm_file_path = tfrm_pathto_perm_file($bu_type);
	if ($perm_file_path) { 
	    print "restoring perms from $perm_file_path...";
	    if (tfr_restore_perms_from_perm_file($perm_file_path)) {
		print "\n";
		loginfo("perms restored from: $perm_file_path");
	    }
	    else {
		logerror("error restoring perms from perm file: $perm_file_path");
		$rc = $EXIT_RESTORE_PERMS;
	    }
	}
	else {
	    logerror("perm file for backup type does not exist: $bu_type");
	    $rc = $EXIT_PERM_FILE_MISSING;
	}

	last if ($rc != $EXIT_OK);
    }

    return($rc);
}


#
# restore perms from specified perm file.
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_restore_perms_from_perm_file
{
    my ($perm_file_path) = @_;

    my $rc = 1;

    if ($DRY_RUN) {
	system("echo \"setfacl --restore=$perm_file_path\"");
    }
    else {
	system("setfacl --restore=$perm_file_path 2> /dev/null");
	if ($? != 0) {
	    logerror("non-zero error status returned by setfacl: $?");
	    $rc = 0;
	}
    }

    return($rc);
}


#
# Add excludes for all the daisy database dirs to the global
# list of excluded paths.
#
sub determine_daisy_excludes
{
    my ($global_excludes) = @_;

    my @daisy_db_dirs = tfr_daisy_get_db_dirs();

    foreach my $daisy_db_dir (@daisy_db_dirs) {
	push(@{$global_excludes}, "${daisy_db_dir}-*");
	push(@{$global_excludes}, "${daisy_db_dir}/*.iso");
	push(@{$global_excludes}, "${daisy_db_dir}/*.tar.asc");
	push(@{$global_excludes}, "${daisy_db_dir}/backups/*");
	#push(@{$global_excludes}, "${daisy_db_dir}/log/*");
    }

    return(1);
}


sub tfr_backup_destination
{
    my $destination = $EMPTY_STR;

    if ($CLOUD) {
	$destination = $CLOUD_SERVER;
    }
    elsif ($SERVER) {
	$destination = $RsyncServer;
    }
    elsif ($DEVICE) {
	$destination = $DEVICE;
    }

    return($destination);
}


sub tfr_backup_name
{
    my $backup_name = $EMPTY_STR;

    if ($CLOUD) {
	$backup_name = 'Cloud';
    }
    elsif ($SERVER) {
	$backup_name = 'Server-to-Server';
    }
    elsif ($LUKS) {
	$backup_name = 'Local';
    }

    return($backup_name);
}


sub tfr_backup_dev_capacity
{
    my ($device) = @_;

    my $rc = 1;

    if ($LUKS) {
	if (tfr_luks_device_mount($device) == 0) {
	    logerror("[backup dev cap] could not mount LUKS device: $device");
	    $rc = 0;
	}
    }
    else {
	mount_device("ro");
	if (is_rsync_bu_device_mounted() == 0) {
	    logerror("[backup dev cap] could not mount backup device: $device");
	    $rc = 0;
	}
    }

    my $blocks = 0;
    if ($rc) {
	if ($rc) {
	    my $ref = OSTools::Filesys::filesys_df($MOUNTPOINT);
	    if (exists($ref->{blocks})) {
		$blocks = $ref->{blocks};
	    }
	}

	if ($LUKS) {
	    tfr_luks_device_umount($device);
	}
	else {
	    unmount_device();
	}
    }

    return($blocks);
}


sub tfr_backup_dev_available
{
    my ($device) = @_;

    my $rc = 1;

    if ($LUKS) {
	if (! tfr_luks_device_mount($device)) {
	    logerror("[backup dev cap] could not mount LUKS device: $device");
	    $rc = 0;
	}
    }
    else {
	mount_device("ro");
	if (! is_rsync_bu_device_mounted()) {
	    logerror("Could not mount backup device: $device");
	    $rc = 0;
	}
    }

    my $available = 0;
    if ($rc) {
	my $ref = OSTools::Filesys::filesys_df($MOUNTPOINT);
	if (exists($ref->{available})) {
	    $available = $ref->{available};
	}
    }

    if ($LUKS) {
	tfr_luks_device_umount($device);
    }
    else {
	unmount_device();
    }

    return($available);
}


#
# process backup summary report
#
# 1. generate a report
# 2. save it
# 3. send it via email if configured
#
sub tfr_backup_summary_report
{
    my ($begin_time, $end_time, $backup_rc, $dev_attr) = @_;

    my $rc = 1;

    my %bu_summary_info = ();
    $bu_summary_info{$BU_SUMMARY_BEGIN} = $begin_time;
    $bu_summary_info{$BU_SUMMARY_END} = $end_time;
    $bu_summary_info{$BU_SUMMARY_DEV_TYPE} = $dev_attr->{DEVTYPE};
    $bu_summary_info{$BU_SUMMARY_BU_RESULT} = $backup_rc;
    $bu_summary_info{$BU_SUMMARY_BU_RETRIES} = tfr_retry_backup_fetch_retries();
    $bu_summary_info{$BU_SUMMARY_DEVICE_FILE} = (tfr_rsync_device_is_disk($DeviceType)) ?
	$DEVICE : 'NA';
    $bu_summary_info{$BU_SUMMARY_DEV_CAPACITY} = (tfr_rsync_device_is_disk($DeviceType)) ?
	tfr_backup_dev_capacity($DEVICE) : 'NA';
    $bu_summary_info{$BU_SUMMARY_DEV_AVAILABLE} = (tfr_rsync_device_is_disk($DeviceType)) ?
	tfr_backup_dev_available($DEVICE) : 'NA';
    $bu_summary_info{$BU_SUMMARY_RSYNC_RESULT} = tfr_rsync_exit_status_fetch();
    $bu_summary_info{$BU_SUMMARY_RSYNC_WARNINGS} = tfr_rsync_status_warnings();
    $bu_summary_info{$BU_SUMMARY_RSYNC_SENT} = tfr_format_rsync_stats($RsyncStatsSent);
    $bu_summary_info{$BU_SUMMARY_RSYNC_SERVER} = tfr_rsync_server_ipaddr();
    $bu_summary_info{$BU_SUMMARY_RSYNC_PATH} = tfr_rsync_server_path();

    my $subject = tfr_backup_summary_report_subject($backup_rc, $dev_attr);
    my $summary = tfr_backup_summary_report_generate(\%bu_summary_info);
    if ($summary) {
	loginfo("[backup summary] summary report generated");
	if (tfr_backup_summary_report_save($summary)) {
	    loginfo("[backup summary] summary report saved");
	    if ($SEND_SUMMARY) {
		tfr_send_email($subject, $summary);
		loginfo("[backup summary] summary report sent via email");
		loginfo("[backup summary] subject: $subject");
	    }
	    if (is_configured_print()) {
		if (tfr_print_results($subject, $summary)) {
		    loginfo("summary report printed");
		}
		else {
		    logerror("could not print summary report");
		    $rc = 0;
		}
	    }
	}
	else {
	    logerror("could not save backup summary report");
	    $rc = 0;
	}
    }
    else {
	logerror("could not generate formatted backup summary report");
	$rc = 0;
    }

    return($rc);
}


sub tfr_backup_summary_report_subject
{
    my ($backup_rc, $dev_attr) = @_;

    # status of backup
    my $subject = ($backup_rc == $EXIT_OK) ? 'SUCCESS' : 'ERROR';

    # type of backup device
    if ($dev_attr->{DEVTYPE} eq $DEVTYPE_CLOUD) {
	$subject .= ' Cloud';
    }
    if ($dev_attr->{DEVTYPE} eq $DEVTYPE_SERVER) {
	$subject .= ' Server-to-Server';
    }
    if ($dev_attr->{DEVTYPE} eq $DEVTYPE_LUKS) {
	$subject .= ' Local';
    }
    $subject .= ' Backup';

    # backup destination
    $subject .= " ($dev_attr->{DESTINATION})";
 
    # hostname running backup
    my $hostname = hostname();
    $subject .= " $hostname";

    return($subject);
}


#
# generate a backup summary report entry
#
# Each entry of the summary log file contains:
#
#   name of script
#   version of script
#   command line
#   time of start of execution
#   time of end of execution
#   duration of execution
#   device type
#   result description
#   rsync exit status
#   rsync backup retries
#   rsync warnings
#   rsync bytes sent
#   server ip addr, either backup server or cloud, else NA
#   path on server, either backup server or device, else NA
#   device file if device type is "passport", "rev", "usb", or "image"
#   capacity if device type is "passport", "rev", "usb", or "image"
#   available if device type is "passport", "rev", "usb", or "image"
#
# Entry separator is line of 80 EQUAL chars ('=')
#
sub tfr_backup_summary_report_generate
{
    my ($bu_info) = @_;

    my $rec_sep = $EQUALS x 80;
    my $summary = $EMPTY_STR;

    my $begin_timestamp = POSIX::strftime("%Y%m%d-%H%M%S", localtime($bu_info->{$BU_SUMMARY_BEGIN}));
    my $end_timestamp = POSIX::strftime("%Y%m%d-%H%M%S", localtime($bu_info->{$BU_SUMMARY_END}));
    my $duration = $bu_info->{$BU_SUMMARY_END} - $bu_info->{$BU_SUMMARY_BEGIN};
    my $duration_timestamp = conv_time_to_dhms($duration);

    $summary .= "$rec_sep\n";

    $summary .= "    PROGRAM: $PROGNAME\n";
    $summary .= "    VERSION: $CVS_REVISION\n";
    $summary .= "    COMMAND: $COMMAND_LINE\n";
    $summary .= "      BEGIN: $begin_timestamp\n";
    $summary .= "        END: $end_timestamp\n";
    $summary .= "   DURATION: $duration_timestamp\n";
    $summary .= "     DEVICE: $bu_info->{$BU_SUMMARY_DEV_TYPE}\n";
    $summary .= "     RESULT: $bu_info->{$BU_SUMMARY_BU_RESULT}\n";
    $summary .= "      RSYNC: $bu_info->{$BU_SUMMARY_RSYNC_RESULT}\n";
    $summary .= "    RETRIES: $bu_info->{$BU_SUMMARY_BU_RETRIES}\n";
    $summary .= "   WARNINGS: $bu_info->{$BU_SUMMARY_RSYNC_WARNINGS}\n";
    $summary .= " BYTES SENT: $bu_info->{$BU_SUMMARY_RSYNC_SENT}\n";
    $summary .= "     SERVER: $bu_info->{$BU_SUMMARY_RSYNC_SERVER}\n";
    $summary .= "       PATH: $bu_info->{$BU_SUMMARY_RSYNC_PATH}\n";
    $summary .= "DEVICE FILE: $bu_info->{$BU_SUMMARY_DEVICE_FILE}\n";
    $summary .= "   CAPACITY: $bu_info->{$BU_SUMMARY_DEV_CAPACITY}\n";
    $summary .= "  AVAILABLE: $bu_info->{$BU_SUMMARY_DEV_AVAILABLE}\n";

    $summary .= "$rec_sep\n\n";

    return($summary);
}

#
# save the current summary report to the summary log file
#
# Returns
#   1 on success
#   0 on errror
#
sub tfr_backup_summary_report_save
{
    my ($summary) = @_;

    my $rc = 1;

    if ($DRY_RUN) {
	return($rc);
    }

    if (open(my $slf, ">>", $SummaryLogfile)) {
	if (log_file_lock($slf)) {
	    print {$slf} $summary;
	    log_file_unlock($slf);
	}
	else {
	    logerror("error obtaining file lock on: $SummaryLogfile");
	    $rc = 0;
	}
	close($slf);
    }
    else {
	logerror("Could not open summary log file: $SummaryLogfile");
	$rc = 0;
    }

    return($rc);
}


#
# get the list of bu types appropriate to the current platform.
#
# Returns
#   non-empty list on success
#   empty list on error
#
sub tfr_get_platform_bu_types
{
    my (@bu_type_list) = @_;

    my @platform_bu_types = ();

    foreach my $bu_type (@bu_type_list) {
	next if ($bu_type eq $BU_TYPE_ALL);
	next if ($RTI && $bu_type eq $BU_TYPE_DAISY);
	next if ($RTI && $bu_type eq $BU_TYPE_DAISY_CONFIGS);
	next if ($DAISY && $bu_type eq $BU_TYPE_USR2);
	next if ($DAISY && $bu_type eq $BU_TYPE_RTI_CONFIGS);
	push(@platform_bu_types, $bu_type);
    }

    return(@platform_bu_types);
}


sub tfr_log_rsync_transaction
{
    my ($bu_attr, $dev_attr) = @_;

    # Collect some information about this backup set.	
    loginfo("|=======================");
    loginfo("| rsync transaction info");
    loginfo("|=======================");
    loginfo("| rsync Started: " . localtime(time()));
    loginfo("| rsync PID: $$");

    # What is our hostname?
    my $hostname = hostname();
    loginfo("| Hostname: $hostname");

    # Which version of redhat does this file come from?
    loginfo("| Red Hat Version: " . plat_redhat_version());

    # 32 or 64 bit linux?
    loginfo("| Architecture: " . plat_processor_arch());

    # Which Linux Kernel?
    loginfo("| Kernel: " . plat_kernel_release());

    # What is the backup type?
    loginfo("| Backup Type: $bu_attr->{BU_TYPE}");

    # What is the transaction class?
    loginfo("| Transaction Class: $dev_attr->{DEVTYPE}");

    # What are we backing up?
    loginfo("| ToBackup: @{$bu_attr->{BU_FILES}}");

    # What are we excluding?
    loginfo("| Exclude: @{$bu_attr->{BU_EXCLUDES}}");

    loginfo("|=======================");

    return(1);
}


#
# Fill a file with paths to exclude from rsync transaction.
# If an exclude prefix is given and is not present on the
# front of the exclude path, then add it to the front of
# each path.
#
# Returns
#   name of temp file if there are files to exclude
#   empty string if there are NO files to exclude
#
sub tfr_rsync_exclude_file
{
    my ($excludes, $exclude_prefix) = @_;
    my $returnval = $EMPTY_STR;

    if (scalar(@{$excludes})) {
	my $template = "tfrsync-excludes-XXXXXXX";
	my ($tfh, $tfn) = tempfile($template, DIR => '/tmp');

	foreach my $path (@{$excludes}) {
	    if ($exclude_prefix) {
		if ($path !~ /^$exclude_prefix/) {
		    $path = $exclude_prefix . $path;
		}
	    }
	    print {$tfh} "$path\n";
	}
	close($tfh);
	$returnval = $tfn;
    }

    return($returnval);
}


sub tfr_set_sigint_handler
{
    local $SIG{'INT'} = 'tfr_sigint_handler';

    $SigIntSeen = 0;

    return(1);
}


sub tfr_reset_sigint_handler
{
    local $SIG{'INT'} = 'DEFAULT';

    return(1);
}


sub tfr_sigint_handler
{
    $SigIntSeen = 1;

    return(1);
}


#
# open an ssh tunnel
#
# if this function succeeds, then the "pathto" function for
# the ssh tunnel socket returns a path to the active socket.
#
# Returns
#   1 on success
#   0 if error
#
sub tfr_open_ssh_tunnel
{
    my ($account_name, $server) = @_;

    if ($DRY_RUN) {
	return(1);
    }

    my $rc = 0;

    my $ssh_id_path = tfr_pathto_ssh_id_file($account_name);
    if (! -e $ssh_id_path) {
	showerror("[open_ssh_tunnel] ssh identity file does not exist for account: $account_name");
	return($rc);
    }

    # if ssh tunnel socket exists, attempt to remove it
    my $ssh_tunnel_socket_path = tfr_pathto_ssh_tunnel_socket();
    if (-e $ssh_tunnel_socket_path) {
	loginfo("[open_ssh_tunnel] ssh tunnel socket exists: $ssh_tunnel_socket_path");
	system("rm $ssh_tunnel_socket_path");
	if ($? == 0) {
	    loginfo("[open_ssh_tunnel] rm ssh tunnel socket ok: $ssh_tunnel_socket_path");
	}
	else {
	    logerror("[open_ssh_tunnel] ssh tunnel socket rm failed: $ssh_tunnel_socket_path");
	    return($rc);
	}
    }

    my $ssh_cmd = 'ssh -tfnN';
    $ssh_cmd .= " -i $ssh_id_path";
    $ssh_cmd .= " -o ControlMaster=yes";
    $ssh_cmd .= " -o ControlPath=$ssh_tunnel_socket_path";
    $ssh_cmd .= " $account_name\@$server";

    loginfo("[open_ssh_tunnel] ssh command: $ssh_cmd");

    # there has been a new decision: now, when attempting to open
    # the ssh tunnel, observe the retry backup reps and the retry
    # backup wait time
    my $ssh_open_retry_reps = tfr_retry_backup_reps();
    my $ssh_open_retry_wait = tfr_retry_backup_wait();

    for (my $j=0; $j < $ssh_open_retry_reps; $j++) {

	for (my $i=0; $i < $DEF_SSH_TUNNEL_RETRIES; $i++) {
	    system("$ssh_cmd >> $LOGFILE 2>> $LOGFILE");

	    my $ssh_exit_status = $?;
	    if ($ssh_exit_status == -1) {
		showerror("[open_ssh_tunnel] ssh command failed to execute: $!");
		last;
	    }
	    elsif ($ssh_exit_status & 127) {
		my $signo = ($ssh_exit_status & 127);
		showerror("[open_ssh_tunnel] ssh command died from signal: $signo");
		last;
	    }
	    else {
		$ssh_exit_status = ($ssh_exit_status >> 8);

		if ($ssh_exit_status == 0) {
		    loginfo("[open_ssh_tunnel] ssh tunnel socket path: $ssh_tunnel_socket_path");
		    $rc = 1;
		    last;
		}
		elsif ($ssh_exit_status == 255) {
		    # per man page for ssh
		    showerror("[open_ssh_tunnel] could not open ssh tunnel: $ssh_tunnel_socket_path");
		    showerror("[open_ssh_tunnel] open ssh tunnel command exit status: $ssh_exit_status"); 
		    # try again
		}
		else {
		    showerror("[open_ssh_tunnel] remote ssh open tunnel cmd exit status: $ssh_exit_status");
		    last;
		}
	    }
	    my $iterations = $i + 1;
	    loginfo("[open_ssh_tunnel] ssh open tunnel iterations: $iterations");
	}

	last if ($rc == 1);

	# only if the retry reps are more than one are we actually doing retries.
	if ($ssh_open_retry_reps > 1) {
	    my $retry_iterations = $j + 1;
	    loginfo("[open_ssh_tunnel] ssh open tunnel retry iterations: $retry_iterations");

	    # take care not to sleep if wait time is 0 or on the last iteration
	    if ($ssh_open_retry_wait) {
		if ($retry_iterations < $ssh_open_retry_reps) {
		    loginfo("[open_ssh_tunnel] ssh open tunnel retry sleep: $ssh_open_retry_wait");
		    sleep($ssh_open_retry_wait);
		}
	    }
	}
    }

    return($rc);
}


#
# if there has been a rsync timeout or protocol error, where
# rsync has an exit status of 12 or 30, emperical evidence shows that
# the ssh tunnel socket is removed... in that case, log it as
# info rather than an error.
#
sub tfr_close_ssh_tunnel
{
    my ($account_name, $server) = @_;

    if ($DRY_RUN) {
	return(1);
    }

    my $rc = 0;

    my $ssh_id_path = tfr_pathto_ssh_id_file($account_name);
    if (! -e $ssh_id_path) {
	logerror("[close_ssh_tunnel] could not get path to ssh identity file: $account_name");
	return($rc);
    }

    my $ssh_tunnel_socket_path = tfr_pathto_ssh_tunnel_socket();
    if (! -e $ssh_tunnel_socket_path) {
	# if there was a rsync timeout or protocol error, then assume it is ok
	# for the socket to not exist and don't return an error.
	if (tfr_rsync_status_timeout_error_seen()) {
	    loginfo("[close_ssh_tunnel] ssh tunnel socket does not exist after rsync timeout: $ssh_tunnel_socket_path");
	    loginfo("[close_ssh_tunnel] for this case, assuming it is ok for ssh tunnel socked to not exist");
	    return(1);
	}
	elsif(tfr_rsync_status_protocol_error_seen()) {
	    loginfo("[close_ssh_tunnel] ssh tunnel socket does not exist after rsync protocol error: $ssh_tunnel_socket_path");
	    loginfo("[close_ssh_tunnel] for this case, assuming it is ok for ssh tunnel socked to not exist");
	    return(1);
	}
	else {
	    logerror("[close_ssh_tunnel] ssh tunnel socket does not exist: $ssh_tunnel_socket_path");
	    return(0);
	}
    }

    my $ssh_cmd = 'ssh -t';
    $ssh_cmd .= " -O exit";
    $ssh_cmd .= " -i $ssh_id_path";
    $ssh_cmd .= " -o ControlPath=$ssh_tunnel_socket_path";
    $ssh_cmd .= " $account_name\@$server";

    loginfo("[close_ssh_tunnel] command: $ssh_cmd"); 

    system("$ssh_cmd >> $LOGFILE 2>> $LOGFILE");

    my $ssh_exit_status = $?;
    if ($ssh_exit_status == -1) {
	showerror("[close_ssh_tunnel] command failed to execute: $!");
    }
    elsif ($ssh_exit_status & 127) {
	my $signo = ($ssh_exit_status & 127);
	showerror("[close_ssh_tunnel] command died from signal: $signo");
    }
    else {
	$ssh_exit_status = ($ssh_exit_status >> 8);
	if ($ssh_exit_status == 0) {
	    # as long as close was successful, return true
	    loginfo("[close_ssh_tunnel] command succeeded: $ssh_tunnel_socket_path");
	    $rc = 1;
	    # if socket still exists, attempt to remove it but it is
	    # not an error if it can't be removed.
	    if (-e $ssh_tunnel_socket_path) {
		system("rm $ssh_tunnel_socket_path");
		if ($? == 0) {
		    loginfo("[close_ssh_tunnel] rm ssh socket ok: $ssh_tunnel_socket_path");
		}
		else {
		    loginfo("[close_ssh_tunnel] oops: ssh socket still exists: $ssh_tunnel_socket_path");
		}
	    }
	}
	else {
	    showerror("[close_ssh_tunnel] could not close ssh tunnel: $ssh_tunnel_socket_path");
	    showerror("[close_ssh_tunnel] command exit status: $ssh_exit_status"); 
	}
    }

    return($rc);
}


#
# read a users listing file and record the list of users
# in the given hash; also note in the hash whether the
# user is a normal user or an admin user.
#
# the content of a users listing file is assumed to be in
# the format as produced by the output of the "--list" option
# of either the "rtiuser.pl" or "dsyuser.pl" scripts.
#
# Returns
#   1 for success
#   0 for error
#
sub tfr_parse_users_listing_file
{
    my ($users_table, $users_listing_file_path) = @_;

    my $rc = 1;

    if (open(my $uf_fh, '<', $users_listing_file_path)) {
	while (my $line = <$uf_fh>) {
	    if ($line =~ /^(\S+)\s/) {
		$users_table->{$1} = 1;
	    }
	    if ($line =~ /^(\S+)\s.*RTI Admin/) {
		$users_table->{$1} = 2;
	    }
	    if ($line =~ /^(\S+)\s.*Daisy Admin/) {
		$users_table->{$1} = 2;
	    }
	}
	close($uf_fh);
    }
    else {
	logerror("could not open users listing file: $users_listing_file_path");
	$rc = 0;
    }

    return($rc);
}


#
# Generate a list of POS users and save it to a location
# that will be backed up.  This info is required for 
# transforming a backup server into a primary server.
#
# Returns
#   1 for success
#   0 for error
#
sub tfr_generate_users_listing_file
{
    my ($list_users_cmd, $users_listing_file_path) = @_;

    my $rc = 1;

    system("$list_users_cmd > $users_listing_file_path 2>> $LOGFILE");
    my $exit_status = $?;
    if ($exit_status == 0) {
	loginfo("generated new users listing file: $users_listing_file_path");
    }
    else {
	$exit_status = ($exit_status >> 8);
	showerror("could not generate users listing file, $list_users_cmd returned: $exit_status");
	$rc = 0;
    }

    return($rc);
}


#
# Generate a file of shadow file entries that correspond
# to the entries in the users listing file and save it to
# a location that will be backed up.  This info is required
# for transforming a backup server into a primary server.
#
# Returns
#   1 for success
#   0 for error
#
sub tfr_generate_users_shadow_file
{
    my ($users_listing_file_path, $shadow_file_path, $users_shadow_file_path) = @_;

    my $rc = 1;

    my %users_table = ();
    if (tfr_parse_users_listing_file(\%users_table, $users_listing_file_path)) {
	loginfo("successfully parsed users listing file: $users_listing_file_path");
	if (open(my $src_fh, '<', $shadow_file_path)) {
	    if (open(my $dst_fh, '>', $users_shadow_file_path)) {
		my $counter = 0;
		while (my $line = <$src_fh>) {
		    my ($username) = split(/:/, $line);
		    if (defined($users_table{$username})) {
			print {$dst_fh} $line;
			$counter++;
		    }
		}
		close($dst_fh);
		loginfo("generated new users shadow file: $users_shadow_file_path");
		loginfo("number of entries written to new users shadow file: $counter");
	    }
	    else {
		logerror("could not open-for-write users shadow file: $users_shadow_file_path");
		$rc = 0;
	    }
	    close($src_fh);
	}
	else {
	    logerror("could not open-for-read shadow file: $shadow_file_path");
	    $rc = 0;
	}
    }
    else {
	showerror("could not parse users listing file: $users_listing_file_path");
	$rc = 0;
    }

    if (! -s $users_shadow_file_path) {
	showerror("could not generate users shadow file: $users_shadow_file_path");
	$rc = 0;
    }

    return($rc);
}


#
# save users info:
#   1) generate and save the users listing file
#   2) generate and save the users shadow file
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_save_users_info
{
    my $rc = 1;

    my $users_info_dir_path = tfrm_pathto_users_info_dir();
    if (-d $users_info_dir_path) {
	my $users_listing_file_path = tfrm_pathto_users_listing_file();
	my $list_users_cmd = tfrm_pathto_pos_users_script() . " --list";
	if (tfr_generate_users_listing_file($list_users_cmd, $users_listing_file_path)) {
	    loginfo("users listing file saved: $users_listing_file_path");
	}
	else {
	    logerror("could not save users listing file: $users_listing_file_path");
	    $rc = 0;
	}
	my $users_shadow_file_path = tfrm_pathto_users_shadow_file();
	my $shadow_file_path = "/etc/shadow";
	if (tfr_generate_users_shadow_file( $users_listing_file_path,
					    $shadow_file_path,
					    $users_shadow_file_path)) {
	    loginfo("users shadow file saved: $users_shadow_file_path");
	}
	else {
	    logerror("could not save users shadow file: $users_shadow_file_path");
	    $rc = 0;
	}
    }
    else {
	logerror("users info directory does not exist: $users_info_dir_path");
	$rc = 0;
    }

    return($rc);
}


#
# generate a new pserver info file which will be
# copied to the backup server if a "--backup=all"
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_save_pserver_info
{
    my $rc = 1;

    my $pserver_infodir_path = tfrm_pathto_pserver_info_dir();
    if (-d $pserver_infodir_path) {
	my $pserver_info_file_path = tfrm_pathto_pserver_info_file();
	if (tfr_generate_pserver_info_file($pserver_info_file_path)) {
	    loginfo("new pserver info file saved: $pserver_info_file_path");
	}
	else {
	    logerror("could not save pserver info file: $pserver_info_file_path");
	    $rc = 0;
	}
    }
    else {
	logerror("pserver info directory does not exist: $pserver_infodir_path");
	$rc = 0;
    }

    return($rc);
}


#
# copy the pserver cloister files to the pserver
# cloister dir
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_save_pserver_cloister_files
{
    my $rc = 1;

    my $pserver_cloister_dir_path = tfrm_pathto_pserver_cloister_dir();
    if (-d $pserver_cloister_dir_path) {
	my @cloistered_files = (
	    "/var/spool/cron",
	    "/etc/cron.d",
	);

	# extra file for RTI system
	if (-e $RTI_DOVE_CMD) {
	    push(@cloistered_files, $RTI_DOVE_CMD);
	}

	# update the files
	foreach (@cloistered_files) {
	    #system("tar cf - $_ | (cd $pserver_cloister_dir_path && tar xf -)");
	    system("cd /; rsync -ahv --delete --relative $_  $pserver_cloister_dir_path");
	    if ($? == 0) {
		loginfo("pserver cloister file copied to $pserver_cloister_dir_path: $_");
	    }
	    else {
		logerror("could not copy pserver cloister file to $pserver_cloister_dir_path: $_");
		$rc = 0;
	    }
	}
    }

    return($rc);
}


#
# add the default paths to *not* backup to the global
# backup exclude list.
#
sub tfr_backup_init_default_excludes
{
    push(@EXCLUDES, @DEF_BACKUP_EXCLUDES);

    if ($RTI) {
	push(@EXCLUDES, @DEF_RTI_BACKUP_EXCLUDES);
    }

    if ($DAISY) {
	push(@EXCLUDES, @DEF_DAISY_BACKUP_EXCLUDES);

	# exclude some files from within daisy database dirs
	determine_daisy_excludes(\@EXCLUDES);
    }

    return(1);
}


############################################
##                                        ##
## subsection: restore upgrade            ##
##                                        ##
############################################


sub tfr_restore_upgrade_samba_check_conf
{
    my ($samba_conf_file) = @_;

    my $rc = 0;

    my $parameter = "passdb backend = smbpasswd";
    my $parameter2 = "smb passwd file = /etc/samba/smbpasswd";

    if (fgrep($samba_conf_file, $parameter) == 0) {
	if (fgrep($samba_conf_file, $parameter2) == 0) {
	    showinfo("[restore upgrade] samba config file already modified: $samba_conf_file");
	    $rc = 1;
	}
    }

    return($rc);
}


sub tfr_restore_upgrade_samba_gen_conf
{
    my ($samba_conf_file) = @_;

    my $rc = 1;

    my $parameter = "passdb backend = smbpasswd";
    my $parameter2 = "smb passwd file = /etc/samba/smbpasswd";

    my $new_samba_conf_file = $samba_conf_file . $DOT . $$;

    #
    # Copy all lines from old to new, but immediately after the
    # global section declaraion, write the new parameter(s) into
    # the new conf file.
    #
    if (open(my $old_fh, '<', $samba_conf_file)) {
	if (open(my $new_fh, '>', $new_samba_conf_file)) {
	    while (<$old_fh>) {
		if (/^\s*\[global\]/) {
		    print {$new_fh} $_;
		    print {$new_fh} "#Following 2 lines added by $PROGNAME, $CVS_REVISION, $TIMESTAMP\n";
		    print {$new_fh} "$parameter\n";
		    print {$new_fh} "$parameter2\n";
		}
		else {
		    print {$new_fh} $_;
		}
	    }
	    close($new_fh);
	    close($old_fh);
	}
	else {
	    showerror("[restore upgrade] could not open new samba config file: $new_samba_conf_file");
	    $rc = 0;
	}
    }
    else {
	showerror("[restore upgrade] could not open existing samba config file: $samba_conf_file");
	$rc = 0;
    }

    if ($rc == 1) {
	# If the new conf file exists and is size non-zero, call it good
	# so replace the old one with the new.
	if (-e $new_samba_conf_file && -s $new_samba_conf_file) {
	    system("chmod --reference=$samba_conf_file $new_samba_conf_file");
	    system("chown --reference=$samba_conf_file $new_samba_conf_file");
	    rename $new_samba_conf_file, $samba_conf_file;
	    loginfo("[restore upgrade] samba config file updated successfully: $samba_conf_file");
	}
	else {
	    showerror("[restore upgrade] could not modify existing samba config file: $samba_conf_file");
	    if (-e $new_samba_conf_file) {
		unlink($new_samba_conf_file);
	    }
	    $rc = 0;
	}
    }

    return($rc);
}


#
# verify that the Samba config file has been updated for RHEL6.
# If it has not, update it.  This must be done for RHEL6 systems
# to be backwards compatabile with the way the pre-RHEL6 systems
# were configured.
#
# Updating it consists of setting two parameters in the global
# section:
#   1) set the "passdb backend" parameter to a value of "smbpasswd"
#   2) set the path to the "smb passwd file" parameter
#
sub tfr_restore_upgrade_samba_conf
{
    my ($samba_conf_file) = @_;

    my $rc = 1;

    if (-e $samba_conf_file) {
	if (-f $samba_conf_file) {
	    if (tfr_restore_upgrade_samba_check_conf($samba_conf_file)) {
		loginfo("[restore upgrade] samba config file already modified: $samba_conf_file");
	    }
	    else {
		if (tfr_restore_upgrade_samba_gen_conf($samba_conf_file)) {
		    loginfo("[restore upgrade] samba config file updated: $samba_conf_file"); 
		}
		else {
		    showerror("[restore upgrade] could not update samba config file: $samba_conf_file");
		    $rc = 0;
		}
	    }
	}
	else {
	    showerror("[restore upgrade] samba config file not a regular file: $samba_conf_file");
	    $rc = 0;
	}
    }
    else {
	showerror("[restore upgrade] samba config file does not exist: $samba_conf_file");
	$rc = 0;
    }

    return($rc);
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
sub tfr_restore_upgrade_samba_gen_passwd
{
    my ($samba_pdb, $new_samba_pdb) = @_;

    my $rc = 1;

    if (open(my $old_fh, '<', $samba_pdb)) {
	if (open(my $new_fh, '>', $new_samba_pdb)) {
	    while (<$old_fh>) {
		my $line = $_;
		if ($line =~ /^(\S+):(\d+):(.*)$/) {
		    my $username = $1;
		    my $uid = $2;
		    my $remainder = $3;

		    my $system_uid = getpwnam($username);
		    if (defined($system_uid)) {
			if ($uid ne $system_uid) {
			    $line = "$username" . $COLON . "$system_uid" . $COLON . "$remainder" . "\n";
			}
		    }
		}
		print {$new_fh} $line;
	    }
	    close($new_fh);
	}
	else {
	    showerror("[restore upgrade] could not open new samba passwd file: $new_samba_pdb");
	    $rc = 0;
	}
	close($old_fh);
    }
    else {
	showerror("[restore upgrade] could not open existing samba passwd file: $samba_pdb");
	$rc = 0;
    }

    return($rc);
}


#
# Make the UIDs in the "smbpasswd" file match those in /etc/passwd.
#
sub tfr_restore_upgrade_samba_rebuild_passwd
{
    my ($samba_pdb) = @_;

    my $rc = 1;

    if (-f $samba_pdb) {

	my $new_samba_pdb = $samba_pdb . $DOT . $$;

	if (tfr_restore_upgrade_samba_gen_passwd($samba_pdb, $new_samba_pdb)) {

	    # check result
	    if (-z $new_samba_pdb) {

		# bad: new generated conf file is zero sized
		showerror("[restore upgrade] generated samba passdb is a zero size: $new_samba_pdb");
		showerror("[restore upgrade] samba passwd file NOT modified: $samba_pdb");
		unlink $new_samba_pdb;
		$rc = 0;
	    }
	    else {

		# good: new conf file successfully generated, so replace old with new
		system("chmod --reference=$samba_pdb $new_samba_pdb");
		system("chown --reference=$samba_pdb $new_samba_pdb");
		rename $new_samba_pdb, $samba_pdb;

		loginfo("[restore upgrade] samba passwd file modified with new UID fields: $samba_pdb ");
	    }
	}
    }
    else {
	showerror("[restore upgrade] samba passswd file does not exist: $samba_pdb");
	$rc = 0;
    }

    return($rc);
}


sub tfr_restore_upgrade_pathto_useradd_cmd
{
    my $useradd_cmd = $EMPTY_STR;

    if ($RTI) {
	$useradd_cmd = File::Spec->catdir($RTI_BINDIR, 'rtiuser.pl');
    }
    if ($DAISY) {
	$useradd_cmd = File::Spec->catdir($DAISY_BINDIR, 'dsyuser.pl');
    }

    if ($useradd_cmd) {
	if ($TEST_RESTORE_UPGRADE_ADD_USERS) {
	    $useradd_cmd = "echo $useradd_cmd";
	}
    }

    return($useradd_cmd);
}


sub tfr_restore_upgrade_pathto_mv_cmd
{
    my $mv_cmd = '/bin/mv';

    if ($TEST_RESTORE_UPGRADE_ADJUST_USERS) {
	$mv_cmd = "echo $mv_cmd";
    }

    return($mv_cmd);
}


sub tfr_restore_upgrade_parse_users
{
    my ($users_listing_file) = @_;

    my %users_tab = ();

    if (open(my $uf_fh, '<', $users_listing_file)) {
	while (my $line = <$uf_fh>) {
	    next if ($line =~ /^\s*$/);
	    next if ($line =~ /^\s*#/);

	    if ($line =~ /^(\S+)\s/) {
		$users_tab{$1} = 1;
	    }
	    if ($line =~ /^(\S+)\s.*RTI Admin/) {
		$users_tab{$1} = 2;
	    }
	    if ($line =~ /^(\S+)\s.*Daisy Admin/) {
		$users_tab{$1} = 2;
	    }
	}
	close($uf_fh);
    }
    else {
	showerror("[restore upgrade] could not open users listing file: $users_listing_file");
    }

    return(%users_tab);
}


#
# Read the shadow file from a backup which
# consists of the lines from the shadow file for each
# user on the system at the time of the backup.
#
# Returns
#   hash with the username as the key and the line as the value.
#
sub tfr_restore_upgrade_parse_shadow_file
{
    my ($shadow_file) = @_;

    my %usersinfo_tab = ();
    my $line;

    if (open(my $ui_fh, '<', $shadow_file)) {
	while ($line = <$ui_fh>) {
	    my $i = index($line, $COLON);
	    my $username = substr($line, 0, $i);
	    $usersinfo_tab{$username} = $line;
	}
	close($ui_fh);
    }
    else {
	logerror("[restore upgrade] could not open shadow file: $shadow_file");
    }

    return(%usersinfo_tab);
}


sub tfr_restore_upgrade_add_users
{
    my ($users_listing_file) = @_;

    my $rc = 1;

    my $useradd_cmd = tfr_restore_upgrade_pathto_useradd_cmd();
    if ($useradd_cmd) {
	my %users_tab = tfr_restore_upgrade_parse_users($users_listing_file);
	if (scalar(keys(%users_tab))) {
	    foreach my $key (keys(%users_tab)) {
		loginfo("restoring POS user $key...");
		system("$useradd_cmd --add $key 2>> $LOGFILE");
		if ($users_tab{$key} == 2) {
		    loginfo("restoring POS admin $key...");
		    system("$useradd_cmd --enable-admin $key password 2>> $LOGFILE");
		}
	    }
	    loginfo("[restore upgrade] users info restored");
	}
	else {
	    showerror("[restore upgrade] users listing file empty: $users_listing_file");
	    $rc = 0;
	}
    }
    else {
	showerror("[restore upgrade] can't happen: could not determine user add command");
	$rc = 0;
    }

    return($rc);
}


sub tfr_restore_upgrade_adjust_users
{
    my ($users_shadow_file, $system_shadow_file) = @_;

    my $rc = 1;

    my %usersinfo_tab = tfr_restore_upgrade_parse_shadow_file($users_shadow_file);

    my $new_shadow_file = $system_shadow_file . ".$$";

    if (open(my $old_fh, '<', $system_shadow_file)) {
	if (open(my $new_fh, '>', $new_shadow_file)) {
	    while (my $line = <$old_fh>) {
		my $i = index($line, $COLON);
		my $username = substr($line, 0, $i);
		if (defined($usersinfo_tab{$username})) {
		    print {$new_fh} "$usersinfo_tab{$username}";
		}
		else {
		    print {$new_fh} "$line";
		}
	    }
	    close($new_fh);
	}
	else {
	    logerror("[restore upgrade] could not open new shadow file: $new_shadow_file");
	    $rc = 0;
	}
	close($old_fh);
    }
    else {
	logerror("[restore upgrade] could not open system shadow file: $system_shadow_file");
	$rc = 0;
    }

    if (-e $new_shadow_file && -s $new_shadow_file) {
	system("chmod --reference=$system_shadow_file $new_shadow_file");
	system("chown --reference=$system_shadow_file $new_shadow_file");
	my $mv_cmd = tfr_restore_upgrade_pathto_mv_cmd();
	system("$mv_cmd $new_shadow_file $system_shadow_file");

	loginfo("[restore upgrade] shadow file info restored");
    }
    else {
	if (-e $new_shadow_file) {
	    unlink $new_shadow_file;
	    logerror("[restore upgrade] zero length new shadow file removed: $new_shadow_file");
	    $rc = 0;
	}
    }

    return($rc);
}


#
# Rebuild users info from restored passwd and shadow files.
#
# 1) add new users from users info file
# 2) adjust the shadow file entries for new users
#
sub tfr_restore_upgrade_rebuild_users_info
{
    my ($users_listing_file, $users_shadow_file) = @_;

    my $rc = 1;

    if (tfr_restore_upgrade_add_users($users_listing_file)) {
	loginfo("[restore upgrade] added users from: $users_listing_file");
	my $system_shadow_file = '/etc/shadow';
	if (tfr_restore_upgrade_adjust_users($users_shadow_file, $system_shadow_file)) {
	    loginfo("[restore upgrade] shadow file adjusted for: $users_listing_file");
	}
	else {
	    showerror("[restore upgrade] could not adjust shadow file for: $users_listing_file");
	    $rc = 0;
	}
    }
    else {
	showerror("[restore upgrade] could not add users from: $users_listing_file");
	$rc = 0;
    }

    return($rc);
}


sub tfr_restore_upgrade_homedir_owners
{
    my ($users_listing_file) = @_;

    my $rc = 1;

    my $cmd_prefix = ($TEST_RESTORE_UPGRADE_HOMEDIR_OWNERS) ? 'echo' : $EMPTY_STR;

    my %users_tab = tfr_restore_upgrade_parse_users($users_listing_file);
    if (scalar(keys(%users_tab))) {
	foreach my $key (keys(%users_tab)) {
	    my $homedir = File::Spec->catdir('/home', $key);
	    if (-d $homedir) {
		my $owner = $key . $COLON;
		my $group = ($RTI) ? 'rti' : 'daisy';
		system("$cmd_prefix chown -R $owner $homedir");
		# some fixups
		system("$cmd_prefix chown 'root:root' $homedir/.bash_logout");
		system("$cmd_prefix chown 'tfsupport:$group' $homedir/.bash_profile");
		loginfo("[restore upgrade] home directory owner/group set: $homedir");
	    } 
	}
    }

    return($rc);
}


#
# Restore user accounts related to the POS.
#
# 1) rebuild users info in passwd and shadow file
# 2) set the perms on user's home directory
#
sub tfr_restore_upgrade_restore_users
{
    my ($users_listing_file, $users_shadow_file) = @_;

    my $rc = 0;

    if (tfr_restore_upgrade_rebuild_users_info($users_listing_file, $users_shadow_file)) {
	if (tfr_restore_upgrade_homedir_owners($users_listing_file)) {
	    $rc = 1;
	}
    }

    return($rc);
}


############################################
##                                        ##
## subsection: file perms                 ##
##                                        ##
############################################

#
# given a list of files, if the read bit for user is NOT set,
# set it to read.
#
# Returns
#   list of filenames changed
#   empty list means none changed
#
sub tfr_file_perms_set_readable
{
    my ($files) = @_;

    my @changed_files = ();

    foreach my $file (@{$files}) {
	if (-e $file) {
	    # get current perms
	    my $sb = File::stat::stat($file);
	    my $file_perms = $sb->mode & oct(7777);

	    # if user's access not readable, make it so
	    if (! ($file_perms & oct(400)) ) {
		$file_perms |= oct(400);
		my $result = chmod $file_perms, $file;
		if ($result == 1) {
		    push(@changed_files, $file);
		}
		else {
		    logerror("[set readable] could not set user access to read: $file");
		}
	    }
	}
	else {
	    loginfo("[set readable] file does not exist: $file");
	}
    }

    return(@changed_files);
}

#
# given a list of files which originally had the read bit
# for user access clear, clear the read bit.
#
# Returns
#   1 for success
#   0 for error and log a message
#
sub tfr_file_perms_unset_readable
{
    my ($changed_files) = @_;

    my $rc = 1;

    foreach my $file (@{$changed_files}) {
	if (-e $file) {
	    # get current perms
	    my $sb = File::stat::stat($file);
	    my $file_perms = $sb->mode & oct(7777);

	    # remove user's read access
	    $file_perms &= ~oct(400);
	    my $result = chmod $file_perms, $file;
	    if ($result != 1) {
		logerror("[unset readable] could not set user access to unreadable: $file");
		$rc = 0;
	    }
	}
	else {
	    loginfo("[unset readable] file does not exist: $file");
	}
    }

    return($rc);
}


############################################
##                                        ##
## subsection: rsync stats api            ##
##                                        ##
############################################

sub tfr_format_rsync_stats
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


#
# parse out the totals line output by rsync
#
# Returns
#   list of bytes sent, bytes received, rate on success
#   empty list otherwise
#
sub tfr_parse_log_rsync_stats
{
    my ($rsync_stats_log) = @_;

    my @rc = ();

    # this regex is for the totals line output by rsync
    my $re_sent     = qr{ sent     \s+ (\S+) \s+ bytes \s+  }x;
    my $re_received = qr{ received \s+ (\S+) \s+ bytes \s+  }x;
    my $re_rate     = qr{              (\S+) \s+ bytes\/sec }x;
    my $re          = qr{ $re_sent $re_received $re_rate }x;

    if (open(my $rrlfh, '<', $rsync_stats_log)) {
	while (my $line=<$rrlfh>) {
	    chomp($line);

# perlcritic -3 did not like this line
#	    if ($line =~ m/^sent     \s+ (\S+) \s+ bytes \s+
#                            received \s+ (\S+) \s+ bytes \s+
#                                         (\S+) \s+ bytes\/sec/x) {

	    if ($line =~ m/ $re /x) {
		@rc = ( $1, $2, $3 );
	    }
	}
	close($rrlfh);
    }
    else {
	logerror("could not open rsync stats log: $rsync_stats_log");
    }

    return(@rc);
}


sub tfr_convert_rsync_stats
{
    my ($rsync_stat_raw) = @_;

    my $rsync_stat = 0;

    if ($rsync_stat_raw =~ m/([\d.]+) (K|M|G)*/x) {
	$rsync_stat = $1;
	my $modifier = ($2) ? $2 : 0;
	if ($modifier eq 'K') {
	    $rsync_stat *= 1024;
	}
	if ($modifier eq 'M') {
	    $rsync_stat *= (1024 * 1024);
	}
	if ($modifier eq 'G') {
	    $rsync_stat *= (1024 * 1024 * 1024);
	}
    }

    return($rsync_stat);
}


#
# process the rsync stats file
#
# - get bytes sent, received, and rate
# - add to running total
#
# Returns
#   1 on success
#   0 or error
#
sub tfr_record_rsync_stats
{
    my ($rsync_stats_log) = @_;

    my $rc = 1;


    my @results = tfr_parse_log_rsync_stats($rsync_stats_log);
    if (scalar(@results)) {
	my $prev_sent = $RsyncStatsSent;
	my $prev_sent_formatted = tfr_format_rsync_stats($prev_sent);
	loginfo("[record_rsync_stats] previous total bytes sent: $prev_sent ($prev_sent_formatted)");

	my $current_sent = tfr_convert_rsync_stats($results[0]);
	my $current_sent_formatted = tfr_format_rsync_stats($current_sent);
	loginfo("[record_rsync_stats] bytes sent: $current_sent ($current_sent_formatted)");

	$RsyncStatsSent += $current_sent;
	$RsyncStatsReceived += tfr_convert_rsync_stats($results[1]);
	$RsyncStatsRate += tfr_convert_rsync_stats($results[2]);

	my $total_sent_formatted = tfr_format_rsync_stats($RsyncStatsSent);
	loginfo("[record_rsync_stats] current total bytes sent: $RsyncStatsSent ($total_sent_formatted)");

	# total should never regress
	if ($RsyncStatsSent < $prev_sent) {
	    logerror("[record_rsync_stats] can't happen: total bytes sent regressed!");
	}
    }
    else {
	logerror("[record_rsync_stats] could not parse rsync stats log: $rsync_stats_log");
	$rc = 0;
    }

    return($rc);
}


sub tfr_append_log_rsync_output
{
    my ($rsync_stats_log, $logfile) = @_;

    if (open(my $infh, '<', $rsync_stats_log)) {
	if (open(my $outfh, '>>', $logfile)) {
	    while (my $line = <$infh>) {
		print {$outfh} $line;
	    }
	    close($outfh);
	}
	close($infh);
    }
    loginfo("[append_log_rsync_output] stats appended to: $logfile");

    return(1);
}


sub tfr_init_rsync_stats
{
    $RsyncStatsSent = 0;
    $RsyncStatsReceived = 0;
    $RsyncStatsRate = 0;

    return(1);
}


# take care of the rsync stats
sub tfr_manage_rsync_stats
{
    my ($rsync_stats_path, $rc) = @_;

    # if no exit status available, just return
    if ( ($rc == -1) || ($rc & 127) ) {
	return($rc);
    }
	    
    # now get at the real rsync exit status
    my $rsync_exit_status = ($rc >> 8);

    # if exit status from rsync was zero, ie no errors or
    # if 24, ie files vanished, then process the rsync stats file
    if ( ($rsync_exit_status == 0) || ($rsync_exit_status == $RSYNC_EXIT_STATUS_VANISHED) ) {
	if (tfr_record_rsync_stats($rsync_stats_path)) {
	    loginfo("[manage_rsync_stats] rsync stats recorded from: $rsync_stats_path");
	}
	else {
	    logerror("[manage_rsync_stats] could not record rsync stats from: $rsync_stats_path");
	}
    }

    return($rc);
}


sub tfr_backup_command_status_classify
{
    my ($rc) = @_;

    # now examine the exit status from perl system builtin
    if ($rc == -1) {
	showerror("rsync command failed to execute: $!");
	$rc = $EXIT_COULD_NOT_EXECUTE;
    }
    elsif ($rc & 127) {
	my $signo = ($rc & 127);
	showerror("rsync command died from signal: $signo");
	$rc = $EXIT_FROM_SIGNAL;
    }
    else {
	$rc = ($rc >> 8);

	# classify the error was warning, error, or OK
	$rc = tfr_rsync_exit_status_classify($rc);
    }

    return($rc);
}


#
# Do an rsync of a source tree to a destination
#
# To rsync from local backup dir to backup server:
#   cd /; sudo rsync -avR --delete --rsync-path='sudo rsync' \
#	etc/inittab tfrsync@192.168.2.2:/d/tfrsync
#
# Returns
#   $EXIT_OK for success
#   $EXIT_MOUNT_ERROR if doing device backup and can not mount device
#   $EXIT_BACKUP_TYPE if backup device or remote server not specified
#   > 0 is the rsync exit value
#   
sub tfr_backup_transaction
{
    my ($bu_attr, $dev_attr) = @_;

    loginfo("[backup_transaction] begin backup transaction");

    my $tobackup = $bu_attr->{BU_FILES};
    my $bu_type = $bu_attr->{BU_TYPE};
    my $excludes = $bu_attr->{BU_EXCLUDES};

    # if there are no files to backup, just return
    if (scalar(@{$tobackup}) == 0) {
	loginfo("[backup_transaction] empty list of paths to backup");
	return($EXIT_OK);
    }

    my $rc = 0;

    # form prefix for destination argument if possible
    my $dst_prefix = $EMPTY_STR;

    # backing up to local device
    if ($dev_attr->{DEVICE}) {
	if ($dev_attr->{DEVTYPE} ne $DEVTYPE_LUKS) {
	    if (mount_device("rw")) {
		logerror("[backup_transaction] could not mount filesystem on: $dev_attr->{DEVICE}");
		return($EXIT_MOUNT_ERROR);
	    }
	}
	$dst_prefix = $dev_attr->{DEVDIR};
	loginfo("[backup_transaction] destination directory on device: $dst_prefix");
    }

    # backing up to rsync server
    elsif ($SERVER) {
	$dst_prefix = $RSYNC_ACCOUNT . $ATSIGN . $RsyncServer . $COLON;

	# if backup type is a special backup type, ie, one that
	# does not get copied "in place", ie at the same path
	# on the backup server as it is on the primary server,
	# then destination is the tfrsync backup directory.

	if ($IS_SERVER_SPECIAL_BACKUP_TYPE{$bu_type}) {
	    if ($RTI) {
		$dst_prefix .= ($RsyncDir) ? $RsyncDir : $DEF_RTI_RSYNC_BU_DIR;
	    }
	    if ($DAISY) {
		$dst_prefix .= ($RsyncDir) ? $RsyncDir : $DEF_DAISY_RSYNC_BU_DIR;
	    }
	}
	else {
	    $dst_prefix .= ($RsyncDir) ? $RsyncDir : $SLASH;
	}
    }

    elsif ($RsyncDir) {
	$dst_prefix = $RsyncDir;
    }

    elsif ($CLOUD) {
	$dst_prefix = $RSYNC_ACCOUNT . $ATSIGN . $CLOUD_SERVER . $COLON;
    }

    else {
	logerror("[backup_transaction] backup destination unspecified");
	return($EXIT_BACKUP_TYPE);
    }

    # deal with entities that must be excluded from a "usr2" backup,
    # eg, "doveserver.pl".  When backing up to a rsync server, they
    # can't be backed up in place.
    #
    # To keep them from being backed up in place, they will be
    # put on the global exclude list while backing up "usr2" and
    # removed from the exclude list after backup is complete.
    my $rti_exclusion_push_count = 0;
    if ($bu_type eq $BU_TYPE_USR2) {
	for my $idx (0 .. $#USR2_EXCLUSIONS) {
	    my $exclude_it = 0;
	    if ($SERVER && ($USR2_EXCLUSIONS[$idx][0] = $DEVTYPE_SERVER)) {
		$exclude_it++;
	    }
	    elsif ($CLOUD && ($USR2_EXCLUSIONS[$idx][0] = $DEVTYPE_CLOUD)) {
		$exclude_it++;
	    }
	    elsif ($DEVICE && ($USR2_EXCLUSIONS[$idx][0] = $DEVTYPE_DEVICE)) {
		$exclude_it++;
	    }
	    else {
		if ($USR2_EXCLUSIONS[$idx][0] = $DEVTYPE_ANY) {
		    $exclude_it++;
		}
	    }
	    if ($exclude_it) {
		$rti_exclusion_push_count++;
		push(@{$excludes}, $USR2_EXCLUSIONS[$idx][1]);
		loginfo("[backup_transaction] element pushed onto excludes list: $USR2_EXCLUSIONS[$idx][1]");
	    }
	}
    }
    my $daisy_exclusion_push_count = 0;
    if ($bu_type eq $BU_TYPE_DAISY) {
	# must exclude an old directory that causes rsync error
	my $daisy_old_edir = "/d/edirectories/2013may/xml";
	if (-d $daisy_old_edir) {
	    push(@{$excludes}, $daisy_old_edir);
	    loginfo("[backup_transaction] element pushed onto excludes list: $daisy_old_edir");
	    $daisy_exclusion_push_count++;
	}
	if ($SERVER) {
	    # just like for RTI, must exclude "/d/tfrsync"
	    push(@{$excludes}, $DEF_DAISY_RSYNC_BU_DIR);
	    loginfo("[backup_transaction] element pushed onto excludes list: $DEF_DAISY_RSYNC_BU_DIR");
	    $daisy_exclusion_push_count++;
	}
    }

    #
    # here we go...
    #

    # write the list of the exclude files to a temp file IF the
    # backup type is not user specified files - it doesn't make sense to
    # have exceptions for user specified files.
    my $tfn = $EMPTY_STR;
    if ($bu_type ne $BU_TYPE_USER_FILES) {
	my $exclude_prefix = $EMPTY_STR;
	$tfn = tfr_rsync_exclude_file($excludes, $exclude_prefix);
	if ($tfn) {
	    loginfo("[backup_transaction] tempfile for rsync excludes: $tfn");
	}
    }

    # save the POS users info to the users info dir
    if ($bu_type eq $BU_TYPE_POS_USERS_INFO) {
	if (tfr_save_users_info()) {
	    loginfo("[backup_transaction] users info saved");
	}
	else {
	    logerror("[backup_transaction] could not save users info");
	    return($EXIT_USERS_INFO_SAVE);
	}
    }

    # save the pserver info to the pserver info dir
    if ($bu_type eq $BU_TYPE_PSERVER_INFO) {
	if (tfr_save_pserver_info()) {
	    loginfo("[backup_transaction] pserver info saved");
	}
	else {
	    logerror("[backup_transaction] could not save pserver info");
	    return($EXIT_PSERVER_INFO_SAVE);
	}
    }

    # save the pserver cloistered files to the pserver cloister dir
    if ($bu_type eq $BU_TYPE_PSERVER_CLOISTER) {
	if (tfr_save_pserver_cloister_files()) {
	    loginfo("[backup_transaction] pserver cloister files saved");
	}
	else {
	    logerror("[backup_transaction] could not save the pserver cloister files");
	    return($EXIT_PSERVER_CLOISTER_FILES_SAVE);
	}
    }

    # make any unreadable files from "userconfigs" readable
    my @changed_files = ();
    if (($bu_type eq $BU_TYPE_USER_CONFIGS) && ($OS eq 'RHEL6')) {
	@changed_files = tfr_file_perms_set_readable($tobackup);
    }

    if ($DEBUGMODE) {
	tfr_log_rsync_transaction($bu_attr, $dev_attr);
    }
    else {
	loginfo("[backup_transaction] backup set: @{$bu_attr->{BU_SETS}}");
	loginfo("[backup_transaction] backup type: $bu_type");
	loginfo("[backup_transaction] backup files: @{$tobackup}");
	loginfo("[backup_transaction] backup exclusions: @{$excludes}");
	loginfo("[backup_transaction] backup class: $dev_attr->{DEVTYPE}");
    }


    ###################################
    # start forming the rsync command #
    ###################################

    # will it be "niced" or not?
    my $rsync_bu_cmd = ($RSYNC_NICE) ? "nice " : $EMPTY_STR;

    $rsync_bu_cmd .= "rsync -ahv";

    # will rsync compression be used?
    $rsync_bu_cmd .= ($RSYNC_COMPRESSION) ? "z" : $EMPTY_STR;

    # if path to ssh identity file exists, add it to command
    my $ssh_id_path = tfr_pathto_ssh_id_file($RSYNC_ACCOUNT);
    if (-e $ssh_id_path) {
	$rsync_bu_cmd .= " -e \'ssh -i $ssh_id_path";

	# if using ssh tunnel, add it to ssh option
	my $ssh_tunnel_socket_path = tfr_pathto_ssh_tunnel_socket();
	if (-e $ssh_tunnel_socket_path) {
	    $rsync_bu_cmd .= " -o ControlPath=$ssh_tunnel_socket_path";
	}

	$rsync_bu_cmd .= $SINGLEQUOTE;
    }

    # dry run or not
    if ($RSYNC_TRIAL) {
	$rsync_bu_cmd .= " -n";
    }

    # delete files located in destination that are not in source
    $rsync_bu_cmd .= " --delete";

    # specify exclude list if not empty
    if ($tfn) {
	$rsync_bu_cmd .= " --exclude-from=$tfn";
    }

    # set up the temp dir location, default to local
    # if the rsync options array already has it specified,
    # then do nothing, else add it.
    if (! $CLOUD) {
	my $temp_dir_option_seen = 0;
	for (@RSYNC_OPTIONS) {
	    if (/^--temp-dir=/) {
		$temp_dir_option_seen = 1;
		last;
	    }
	}
	if (! $temp_dir_option_seen) {
	    if ($RTI) {
		unshift(@RSYNC_OPTIONS, "--temp-dir=/usr2");
	    }
	    if ($DAISY) {
		unshift(@RSYNC_OPTIONS, "--temp-dir=/tmp");
	    }
	}
    }

    # add timeout option
    if ($RSYNC_TIMEOUT) {
	$rsync_bu_cmd .= " --timeout=$RSYNC_TIMEOUT";
    }

    # add any extra options specified in config file
    foreach (@RSYNC_OPTIONS) {
	$rsync_bu_cmd .= " $_";
    }

    # commands to run for remote copy
    my $cmd_remote = "cd /; $rsync_bu_cmd --relative";
    if ($SERVER) {
	$cmd_remote .= " --rsync-path=\'sudo rsync\'";
    }

    #
    # Loop through all the paths to backup
    #
    foreach my $src (@{$tobackup}) {

	last if ($SigIntSeen);

	my $src_remote = $src;
	$src_remote =~ s/^\///;

	# source and destination arguments
	my $rsync_cmd_remote = $cmd_remote;
	$rsync_cmd_remote .= " $src_remote";
	$rsync_cmd_remote .= " $dst_prefix";

	# exec the remote command
	if ($DRY_RUN) {
	    system("echo \"$rsync_cmd_remote\"");
	}
	else {
	    # always init saved rsync exit status
	    tfr_rsync_exit_status_clear();

	    # make a temp file for the rsync output
	    my ($rsfh, $rsfn) = tempfile($RSYNCSTATS_TEMPLATE, DIR => '/tmp');
	    close($rsfh);
	    loginfo("[backup_transaction] rsync output will be redirected to temp file: $rsfn");

	    loginfo("[backup_transaction] backup command: $rsync_cmd_remote");

	    # exec the rsync command, display output on stdout in addition
	    # to saving output to a log file for further processing
	    $rc = system("$rsync_cmd_remote 2>&1 | tee $rsfn ; ( exit \${PIPESTATUS[0]} )");

	    # take care of the rsync stats
	    $rc = tfr_manage_rsync_stats($rsfn, $rc);

	    # now append the rsync output file to the full logfile
	    if (tfr_append_log_rsync_output($rsfn, $LOGFILE)) {
		loginfo("[backup_transaction] rsync output appended to logfile from temp file");
	    }
	    else {
		logerror("[backup_transaction] could not append rsync output to logfile");
	    }

	    # remove the rysnc output temp file
	    if (unlink($rsfn)) {
		loginfo("[backup_transaction] rsync output temp file unlinked: $rsfn");
	    }
	    else {
		logerror("[backup_transaction] could not unlink rsync output temp file: $rsfn");
	    }

	    # classify backup command results
	    $rc = tfr_backup_command_status_classify($rc);

	    # break on errors
	    if ($rc == 0) {
		loginfo("[backup_transaction] backup command successful: $rc");
	    }
	    else {
		last;
	    }
	}
    }

    if ($tfn) {
	if (unlink($tfn)) {
	    loginfo("[backup_transaction] rsync excludes temp file unlinked: $tfn");
	}
	else {
	    logerror("[backup_transaction] could not unlink rsync excludes temp file: $tfn");
	}
    }

    if (! $DRY_RUN) {
	if ($dev_attr->{DEVICE}) {
	    if ($dev_attr->{DEVTYPE} ne $DEVTYPE_LUKS) {
		unmount_device();
	    }
	}
    }

    # deal with exclusions...
    # remove them from the global exclude list now
    # that the transaction is over.
    if ($bu_type eq $BU_TYPE_USR2) {
	while ($rti_exclusion_push_count--) {
	    pop(@{$excludes});
	}
    }
    if ($bu_type eq $BU_TYPE_DAISY) {
	while ($daisy_exclusion_push_count--) {
	    pop(@{$excludes});
	}
    }

    # restore file perms for some userconfig files
    if (($bu_type eq $BU_TYPE_USER_CONFIGS) && ($OS eq 'RHEL6')) {
	if (@changed_files) {
	    if (tfr_file_perms_unset_readable(\@changed_files)) {
		loginfo("[backup_transaction] userconfig file perms restored");
	    }
	    else {
		logerror("[backup_transaction] could not restore userconfig file perms");
	    }
	}
    }

    loginfo("[backup_transaction] end transaction");

    return($rc);
}


#
# Given a backup type, return a list of files to backup.
#
sub tfr_backup_file_list
{
    my ($bu_type) = @_;

    my @bu_type_files = ();

    if ($bu_type eq $BU_TYPE_USER_CONFIGS) {
	my @possible_files = qw(
	    /etc/group
	    /etc/group-
	    /etc/gshadow
	    /etc/gshadow-
	    /etc/login.defs
	    /etc/passwd
	    /etc/passwd-
	    /etc/shadow
	    /etc/shadow-
	    /etc/sudoers
	    /etc/pam.d
	    /home
	    /root
	);

	if ($OS eq 'RHEL5') {
	    push(@possible_files, "/var/log/faillog");
	}
	if ($OS eq 'RHEL6') {
	    push(@possible_files, "/var/log/tallylog");
	}
	foreach my $file (@possible_files) {
	    if (-e $file) {
		push(@bu_type_files, $file);
	    }
	}

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_PRINT_CONFIGS) {
	@bu_type_files = qw(
	    /etc/printcap
	    /etc/cups
	);

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_OS_CONFIGS) {
	my @common_files = qw(
	    /etc/inittab
	    /etc/log.d
	    /etc/mail
	    /etc/redhat-release
	    /etc/samba
	    /etc/yum
	    /etc/yum.conf
	    /etc/yum.repos.d
	);

	# contains setting for kernel log message priority for console
	if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	    push(@common_files, '/etc/rsyslog.conf');
	}
	if ($OS eq 'RHEL5') {
	    push(@common_files, '/etc/sysconfig/syslog');
	}

	# check for optional files or directories
	my @possible_files = (
	    '/etc/httpd',           # web server config directory
	    '/usr/src/redhat'       # source directory
	);
	foreach my $file (@possible_files) {
	    if (-e $file) {
		push(@common_files, $file);
	    }
	}

	foreach my $file (@common_files) {
	    if (-e $file) {
		push(@bu_type_files, $file);
	    }
	}

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_NET_CONFIGS) {
	@bu_type_files = qw(
	    /etc/hosts
	    /etc/hosts.allow
	    /etc/hosts.deny
	    /etc/resolv.conf
	    /etc/ssh
	    /etc/sysconfig/iptables
	    /etc/sysconfig/network
	);

	if (-d '/etc/sysconfig/networking/profiles') {
	    push(@bu_type_files, '/etc/sysconfig/networking/profiles');
	}

	my @ifcfg_files = glob("/etc/sysconfig/network-scripts/ifcfg*");
	foreach (@ifcfg_files) {
	    push(@bu_type_files, $_);
	}

	# this path does not exist on all platforms
	@ifcfg_files = glob("/etc/sysconfig/networking/devices/ifcfg*");
	foreach (@ifcfg_files) {
	    push(@bu_type_files, $_);
	}

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_RTI_CONFIGS) {
	@bu_type_files = (
	    "/etc/sysconfig/i18n",
	    "/etc/profile",
	    "/etc/profile.d/rti.sh",
	    "/etc/rc.d/init.d/rti",
	    "/etc/rc.d/init.d/blm",
	    "/etc/rc.d/init.d/bbj",
	    "/etc/services",
	    "/etc/mime.types",
	    "$RTIDIR/config",
	    "/var/spool/fax",
	    "/usr/local/lib/BITMAPS",
	    "/usr/java",
	);

	# check for optional files or directories
	my @optional_files = (
	    '/etc/profile.d/pro5.sh',
	);
	foreach my $file (@optional_files) {
	    if (-e $file) {
		push(@bu_type_files, $file);
	    }
	}

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_DAISY_CONFIGS) {
	@bu_type_files = (
	    "/etc/inittab",
	    "/etc/profile.d/daisy.sh",
	    "$DAISYDIR/config",
	);

	if ($OS eq 'RHEL5') {
	    # a long time ago this file was standard on all
	    # Daisy RHEL5 systems and should be present, but
	    # it seems that bit rot has set in and it is not
	    # present on all Daisy servers, so skip it if it
	    # does not exist
	    my $daisy_init_file = "/etc/rc.d/init.d/daisy";
	    if (-f $daisy_init_file) {
		push(@bu_type_files, $daisy_init_file);
	    }
	    else {
		loginfo("missing Daisy init file ignored: $daisy_init_file");
	    }
	}
	# don't forget the upstart files for the startup and virtual consoles
	if ($OS eq 'RHEL6') {
	    push(@bu_type_files, "/etc/rc.d/init.d/zeedaisy");
	    push(@bu_type_files, "/etc/init/tty*.conf");
	}

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_USR2) {
	@bu_type_files = (
	    "/usr2",
	);

	# additional directories for RTI version 14
	my @rti14_files = qw(
	    /var/www
	);

	foreach my $file (@rti14_files) {
	    if (-d $file) {
		push(@bu_type_files, $file);
	    }
	}

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_BBXD) {
	@bu_type_files = (
	    "/usr2/bbx/bbxd",
	);

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_BBXPS) {
	@bu_type_files = (
	    "/usr2/bbx/bbxps",
	);

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_DAISY) {
	@bu_type_files = (
	    "/d",
	);

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_LOG_FILES) {
	@bu_type_files = (
	    "/var/log",
	);

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_USER_FILES) {
	@bu_type_files = @USERFILES;

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_SINGLEFILE) {
	if (@SinglefilesCLO) {
	    @bu_type_files = @SinglefilesCLO;
	}

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_PSERVER_CLOISTER) {
	my $pserver_cloister_dir_path = tfrm_pathto_pserver_cloister_dir();
	@bu_type_files = (
	    $pserver_cloister_dir_path,
	);

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_POS_USERS_INFO) {
	my $users_info_bu_dir = tfrm_pathto_users_info_dir();
	@bu_type_files = (
	    $users_info_bu_dir,
	);

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_PSERVER_INFO) {
	my $pserver_infodir = tfrm_pathto_pserver_info_dir();
	@bu_type_files = (
	    $pserver_infodir,
	);

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_POS_LOG_FILES) {
	if ($RTI) {
	    @bu_type_files = ( $RTI_LOGDIR );
	}
	if ($DAISY) {
	    @bu_type_files = ( $DAISY_LOGDIR);
	}

	return(@bu_type_files);
    }

    if ($bu_type eq $BU_TYPE_POS_SUMMARY_LOG) {
	@bu_type_files = ( $SummaryLogfile );

	return(@bu_type_files);
    }

    logerror("[tfr_backup_file_list()] Can't happen: \$bu_type = $bu_type");

    return(@bu_type_files);
}


#
# Save files associated with a backup type
#
sub tfr_backup_by_type
{
    my ($bu_attr, $dev_attr) = @_;

    my $rc = 0;

    my $bu_type = $bu_attr->{BU_TYPE};

    loginfo("[backup type] begin backup by type: $bu_type");

    my @toback = tfr_backup_file_list($bu_type);
    if (@toback) {
	if ($dev_attr->{DEVTYPE} eq $DEVTYPE_SHOW_ONLY || $SHOW_ONLY) {
	    foreach (@toback) {
		print "$_\n";
	    }
	}
	else {
	    $bu_attr->{BU_FILES} = \@toback;

	    $rc = tfr_backup_transaction($bu_attr, $dev_attr);

	}
    }
    else {
	loginfo("[backup type] empty list of files for backup type: $bu_type");
    }

    return($rc);
}


#
# backup files
#
# The backup of all backup types funnels through this function.
#
sub tfr_backup_files
{
    my ($bu_attr, $dev_attr) = @_;

    my $returnval = 0;

    loginfo("[backup_files] begin backup files");

    # Verify the luks backup device is accessible and
    # rotate buckets if necessary
    if ($dev_attr->{DEVTYPE} eq $DEVTYPE_LUKS) {
	if (tfr_luks_device_is_luks($dev_attr->{DEVICE})) {
	    loginfo("[backup_files] LUKS device usable: $dev_attr->{DEVICE}");
	}
	else {
	    showerror("[backup_files] LUKS device not usable (check log for details): $dev_attr->{DEVICE}");
	    return($EXIT_LUKS_UNUSABLE);
	}
    }

    if ($dev_attr->{DEVTYPE} eq $DEVTYPE_BLOCK || $dev_attr->{DEVTYPE} eq $DEVTYPE_IMAGE) {
	mount_device("rw");
	if (is_rsync_bu_device_mounted()) {
	    unmount_device();
	}
	else {
	    showerror("[backup_files] backup device NOT accessible via mount: $dev_attr->{DEVICE}");
	    return($EXIT_MOUNT_ERROR);
	}
    }

    if ($dev_attr->{DEVTYPE} eq $DEVTYPE_LUKS) {
	if (tfr_luks_device_mount($dev_attr->{DEVICE})) {
	    loginfo("[backup_files] luks device mounted: $dev_attr->{DEVICE}");

	    if (tfr_luks_device_rotate_buckets($dev_attr)) {
		loginfo("[backup_files] luks device buckets rotated: $dev_attr->{DEVICE}");
	    }
	    else {
		showerror("[backup_files] could not rotate luks device buckets: $dev_attr->{DEVICE}");
		tfr_luks_device_umount($dev_attr->{DEVICE});
		return($EXIT_LUKS_ROTATE);
	    }
	}
	else {
	    showerror("[backup_files] could not mount luks device: $dev_attr->{DEVICE}");
	    return($EXIT_LUKS_MOUNT);
	}
    }

    if ($CLOUD || $SERVER) {
	my $server_addr = ($SERVER) ? $RsyncServer : $CLOUD_SERVER;
	if (tfr_open_ssh_tunnel($RSYNC_ACCOUNT, $server_addr)) {
	    loginfo("[backup_files] ssh tunnel opened: $RSYNC_ACCOUNT, $server_addr");
	}
	else {
	    showerror("[backup_files] could not open ssh tunnel: $RSYNC_ACCOUNT, $server_addr");
	    return($EXIT_SSH_TUNNEL_OPEN);
	}
    }

    my @types_to_backup = (tfr_list_is_member_of($bu_attr->{BU_SETS}, $BU_TYPE_ALL)) ?
				@BACKUP_EQUALS_ALL_BACKUP_TYPES :
				@{$bu_attr->{BU_SETS}};

    #
    # normally, only one backup iteration is attempted.
    #
    my $max_backup_iterations = 1;

    #
    # If backup retries are specified, then additional attempts
    # are performed.
    #
    my $retry_backup_reps = tfr_retry_backup_reps();
    $max_backup_iterations += $retry_backup_reps;

    #
    # And if backup wait is specified, there will be some
    # time between each try.
    #
    my $retry_backup_wait = tfr_retry_backup_wait();

    for (my $i=0; $i < $max_backup_iterations; $i++) {

	foreach my $bu_type (@types_to_backup) {

	    last if ($SigIntSeen);

	    next if ( ($bu_type eq $BU_TYPE_USR2) && ($RTI == 0) );
	    next if ( ($bu_type eq $BU_TYPE_RTI_CONFIGS) && ($RTI == 0) );
	    next if ( ($bu_type eq $BU_TYPE_DAISY) && ($DAISY == 0) );
	    next if ( ($bu_type eq $BU_TYPE_DAISY_CONFIGS) && ($DAISY == 0) );

	    $bu_attr->{BU_TYPE} = $bu_type;

	    $returnval = tfr_backup_by_type($bu_attr, $dev_attr);
	    if ($returnval != 0) {
		logerror("[backup_files] could not backup type: $bu_type");
		last;
	    }
	}

	# record and log number of retries
	# NOTE: $i will only be > 0 only if backup retries are enabled and
	# the first attempt was already completed.
	if ($i > 0) {
	    tfr_retry_backup_record_retries($i);
	    loginfo("[backup_files] retrying: backup retries completed: $i");
	}

	$returnval = tfr_rsync_exit_status_prepare($returnval);

	if ($returnval == $EXIT_RSYNC_ERROR) {
	    my $rsync_exit_status = tfr_rsync_exit_status_fetch();
	    if ($rsync_exit_status == $RSYNC_EXIT_STATUS_PROTOCOL_ERROR) {
		loginfo("[backup_files] retrying: rsync reported protocol error exit status: $RSYNC_EXIT_STATUS_PROTOCOL_ERROR");
	    }
	    elsif ($rsync_exit_status == $RSYNC_EXIT_STATUS_TIMEOUT_ERROR) {
		loginfo("[backup_files] retrying: rsync reported timeout error exit status: $RSYNC_EXIT_STATUS_TIMEOUT_ERROR");
	    }
	    elsif ($rsync_exit_status == $RSYNC_EXIT_STATUS_SSH_ERROR) {
		loginfo("[backup_files] retrying: rsync reported SSH error exit status: $RSYNC_EXIT_STATUS_SSH_ERROR");
	    }
	    else {
		# exit loop if the rsync error was ordinary error
		loginfo("[backup_files] retrying: no retry for ordinary rsync error: $rsync_exit_status");
		last;
	    }
	}
	else {
	    # exit loop if not an rsync error
	    loginfo("[backup_files] retrying: no retry for non-rsync error: $returnval");
	    last;
	}

	#
	# sleep unless on the last iteration.
	#
	if ( ($i < ($max_backup_iterations-1)) && ($retry_backup_wait) ) {
	    sleep($retry_backup_wait);
	    loginfo("[backup_files] retrying: time waited in seconds: $retry_backup_wait");
	}
    }

    if ($dev_attr->{DEVTYPE} eq $DEVTYPE_LUKS) {
	if (tfr_luks_device_record_backup_date($dev_attr->{DEVICE})) {
	    loginfo("[backup_files] backup date recorded on $dev_attr->{DEVICE}");
	}
	else {
	    showerror("[backup_files] could not record backup date on: $dev_attr->{DEVICE}");
	}

	if (tfr_luks_device_umount($dev_attr->{DEVICE})) {
	    loginfo("[backup_files] luks device umounted: $dev_attr->{DEVICE}");
	}
	else {
	    showerror("[backup_files] could not umount luks device: $dev_attr->{DEVICE}");
	    if ($returnval == 0) {
		$returnval = $EXIT_LUKS_UMOUNT;
	    }
	}
    }

    if ($CLOUD || $SERVER) {
	my $server_addr = ($SERVER) ? $RsyncServer : $CLOUD_SERVER;
	if (tfr_close_ssh_tunnel($RSYNC_ACCOUNT, $server_addr)) {
	    loginfo("[backup_files] ssh tunnel socket closed: $RSYNC_ACCOUNT, $server_addr");
	}
	else {
	    showerror("[backup_files] could not close ssh tunnel socket: $RSYNC_ACCOUNT, $server_addr");
	    if ($returnval == 0) {
		$returnval = $EXIT_SSH_TUNNEL_CLOSE;
	    }
	}
    }

    return($returnval);
}


#
# top level function for doing a backup
#
# Input
#   $bu_attr   - ref to hash containing backup attributes
#   $dev_attr  - ref to hash containing device attributes
#
# Returns
#   exit status - 0 == success, non-zero == error
#
sub tfr_backup
{
    my ($bu_attr, $dev_attr) = @_;

    loginfo("[backup] begin backup");

    tfr_init_rsync_stats();

    tfr_rsync_status_warnings_init();

    tfr_backup_init_default_excludes();

    my $begin_time = time;

    my $backup_returnval = tfr_backup_files($bu_attr, $dev_attr);

    my $end_time = time;

    loginfo("[backup] return value: $backup_returnval");

    my $backup_strerror = tfr_exit_strerror($backup_returnval);
    if ($backup_strerror) {
	loginfo("[backup] exit table entry for return value: $backup_strerror");
    }
    else {
	loginfo("[backup] return value undefined in exit table: $backup_returnval");
	$backup_returnval = $EXIT_UNKNOWN;
    }

    # send out an error notification if needed
    if ($backup_returnval != $EXIT_OK) {
	tfr_notification_backup_error($backup_returnval);
    }

    # process the backup summary report
    tfr_backup_summary_report($begin_time, $end_time, $backup_returnval, $dev_attr);

    #
    # do a backup of the POS summary log
    # For cloud backup, this will make it easier to collect the
    # results by management facilities like Kaseya.
    #
    my $saved_backup_sets = $bu_attr->{BU_SETS};
    $bu_attr->{BU_SETS} = [ $BU_TYPE_POS_SUMMARY_LOG ];
    loginfo("[backup] begin backing up pos summary log");
    if (tfr_backup_files($bu_attr, $dev_attr) == $EXIT_OK) {
	loginfo("[backup] POS summary log file resynced: $SummaryLogfile");
    }
    else {
	logerror("[backup] could not resync POS summary log: $SummaryLogfile");
    }

    #
    # if backing up to a local disk, do a backup to the "weekly" and/or
    # "monthly" buckets if needed.
    #
    if ($dev_attr->{DEVTYPE} eq $DEVTYPE_LUKS) {
	$bu_attr->{BU_SETS} = $saved_backup_sets;
	if (tfr_luks_device_cyclic_buckets($bu_attr, $dev_attr)) {
	    loginfo("[backup] cyclic luks buckets backed up as necessary");
	}
	else {
	    showerror("[backup] could not backup cyclic luks buckets");
	}
    }

    return($backup_returnval);
}


#
# Do an "list only" rsync of a source tree to a destination
#
# To rsync from local path to local backup dir:
#   cd /; sudo rsync -avR --delete home /d/backup/
#
# To rsync from local backup dir to backup server:
#   cd /; sudo rsync -avR --delete --rsync-path='sudo rsync' \
#	etc/inittab tfrsync@192.168.2.2:/d/backup
#
# Returns
#   0 for success
#   -1 if list of items to backup is empty
#   -2 if doing device backup and can not mount device
#   -3 if backup device or remote server not specified
#   > 0 is the rsync exit value
#   
sub tfr_list_only_rsync_transaction
{
    my ($tobackup, $excludes, $bu_type) = @_;

    my $rc = 0;

    loginfo("[list trans] begin list transaction");

    # form prefix for destination argument if possible
    my $dst_prefix = $EMPTY_STR;

    # listing files from a local device
    if ($DEVICE) {
	$dst_prefix = $MOUNTPOINT;
    }

    # listing files from an rsync server
    elsif ($SERVER) {
	$dst_prefix = $RSYNC_ACCOUNT . $ATSIGN . $RsyncServer . $COLON;
	if ($RsyncDir) {
	    $dst_prefix .= $RsyncDir;
	}
    }

    elsif ($RsyncDir) {
	$dst_prefix = $RsyncDir;
    }

    else {
	logerror("[list trans] source unspecified");
	return(-3);
    }

    # write the list of the exclude files to a temp file IF the
    # backup type is not user specified files - it doesn't make sense to
    # have exceptions for user specified files.
    my $tfn = $EMPTY_STR;
    if ($bu_type ne "userfiles") {
	my $exclude_prefix = $EMPTY_STR;
	$tfn = tfr_rsync_exclude_file($excludes, $exclude_prefix);
	if ($tfn) {
	    loginfo("[list trans] tempfile for rsync excludes: $tfn");
	}
    }

    # form the rsync command
    my $cmd = "nice rsync -av";

    # if path to ssh identity file exists, add it to command
    my $ssh_id_path = tfr_pathto_ssh_id_file($RSYNC_ACCOUNT);
    if (-e $ssh_id_path) {
	$cmd .= " -e \'ssh -i $ssh_id_path";

	# if using ssh tunnel, add it to ssh option
	my $ssh_tunnel_socket_path = tfr_pathto_ssh_tunnel_socket();
	if (-e $ssh_tunnel_socket_path) {
	    $cmd .= " -o ControlPath=$ssh_tunnel_socket_path";
	}

	$cmd .= $SINGLEQUOTE;
    }

    # dry run or not
    if ($RSYNC_TRIAL) {
	$cmd .= " -n";
    }

    # specify exclude list if not empty
    if ($tfn) {
	$cmd .= " --exclude-from=$tfn";
    }

    # commands to run for local copy and remote copy
    my $cmd_remote = "cd /; $cmd --relative";
    if ($SERVER) {
	$cmd_remote .= " --rsync-path=\'sudo rsync\'";
    }

    #
    # Loop through all the paths to list
    #
    foreach my $src (@{$tobackup}) {

	my $src_remote = $src;
	$src_remote =~ s/^\///;

	# source and destination arguments
	my $rsync_cmd_remote = $cmd_remote;
	$rsync_cmd_remote .= " --list-only";
	$rsync_cmd_remote .= " $src_remote";
	$rsync_cmd_remote .= " $dst_prefix";

	# exec the remote command
	if ($DRY_RUN) {
	    system("echo \"$rsync_cmd_remote\"");
	}
	else {
	    loginfo("[list trans] execing rsync command for remote or device backup:");
	    loginfo("[list trans] $rsync_cmd_remote");
	    $rc = system("$rsync_cmd_remote");
	    last if ($rc != 0);
	}
    }

    unlink($tfn);

    loginfo("[list trans] end list transaction");

    return($rc);
}


sub tfr_list_by_type
{
    my ($bu_type) = @_;

    my $returnval = 0;

    my @tolist = tfr_backup_file_list($bu_type);
    if (@tolist) {
	$returnval = tfr_list_only_rsync_transaction(\@tolist, \@EXCLUDES, $bu_type);
    }
    else {
	loginfo("Empty list of files for backup type: $bu_type");
    }

    return($returnval);
}


sub tfr_list_files
{
    my ($list_ref, $bu_device_type) = @_;

    my $rc = 1;

    if (is_mount_required($bu_device_type)) {
	if ($LUKS) {
	    if (tfr_luks_device_mount($DEVICE)) {
		loginfo("[list files] successful mount of LUKS device: $DEVICE");
	    }
	    else {
		logerror("[list files] could not mount LUKS device: $DEVICE");
		return(0);
	    }
	}
	else {
	    mount_device("ro");
	    if (! is_rsync_bu_device_mounted()) {
		logerror("[list files] could not mount backup device for listing files: $DEVICE");
		return(0);
	    }
	}
    }

    my @bu_types = (tfr_list_is_member_of($list_ref, $BU_TYPE_ALL)) ?
		    @LIST_ALL_BACKUP_TYPES :
		    @{$list_ref};

    if ($SERVER) {
	if (tfr_open_ssh_tunnel($RSYNC_ACCOUNT, $RsyncServer)) {
	    loginfo("[list files] successful open of ssh tunnel: $RSYNC_ACCOUNT, $RsyncServer");
	}
	else {
	    showerror("[list files] could not open ssh tunnel: $RSYNC_ACCOUNT, $RsyncServer");
	    return(0);
	}
    }

    loginfo("[list files] begin list files");

    foreach my $bu_type (@bu_types) {

	if ( ($bu_type eq $BU_TYPE_USR2) && ($RTI == 0) ) {
	    next;
	}
	elsif ( ($bu_type eq $BU_TYPE_RTI_CONFIGS) && ($RTI == 0) ) {
	    next;
	}
	elsif ( ($bu_type eq $BU_TYPE_DAISY) && ($DAISY == 0) ) {
	    next;
	}
	elsif ( ($bu_type eq $BU_TYPE_DAISY_CONFIGS) && ($DAISY == 0) ) {
	    next;
	}

	if ($SERVER) {
	    $rc = tfr_list_by_type($bu_type);
	    if ($rc != 0) {
		logerror("[list files] error listing files for backup type: $bu_type");
		$rc = 0;
	    }
	}
	else {
	    # get list of files in backup type
	    my @bu_type_file_list = tfr_backup_file_list($bu_type);

	    # if there any files in the list, print heading
	    if (scalar(@bu_type_file_list)) {
		print "backup type: $bu_type\n";
	    }

	    # get location of files on the luks device
	    my $luks_dir_name = ($LuksDirCLO) ? $LuksDirCLO : $DEF_LUKS_DIR;
	    my $luks_dir = File::Spec->catdir($MOUNTPOINT, $luks_dir_name);

	    # now a recursive long listing of the flies of the backup type
	    foreach (@bu_type_file_list) {
		my $file_on_device = File::Spec->catdir($luks_dir, $_);
		if (-e $file_on_device) {
		    system "ls -lR $file_on_device";
		}
		else {
		    print "missing: $_\n";
		}
	    }
	}
    }

    if ($SERVER) {
	if (tfr_close_ssh_tunnel($RSYNC_ACCOUNT, $RsyncServer)) {
	    loginfo("[list files] successful close of ssh tunnel: $RSYNC_ACCOUNT, $RsyncServer");
	}
	else {
	    showerror("[list files] could not close ssh tunnel: $RSYNC_ACCOUNT, $RsyncServer");
	    $rc = 0;
	}
    }

    if (is_mount_required($bu_device_type)) {
	if ($LUKS) {
	    if (tfr_luks_device_umount($DEVICE)) {
		loginfo("[list files] successful umount of LUKS device: $DEVICE");
	    }
	    else {
		logerror("[list files] could not umount LUKS device: $DEVICE");
		$rc = 0;
	    }
	}
	else {
	    unmount_device();
	}
    }

    loginfo("[list files] end list files");

    return($rc);
}


sub is_restore_type_compatible
{
    my ($restore_type) = @_;

    my $rc = 0;

    if ( ($restore_type eq $BU_TYPE_USR2) && ($RTI != 1) ) {
	showerror("restore type only compatible with RTI: $restore_type");
    }
    elsif ( ($restore_type eq $BU_TYPE_RTI_CONFIGS) && ($RTI != 1) ) {
	showerror("restore type only compatible with RTI: $restore_type");
    }
    elsif ( ($restore_type eq $BU_TYPE_DAISY) && ($DAISY != 1) ) {
	showerror("restore type only compatible with Daisy: $restore_type");
    }
    elsif ( ($restore_type eq $BU_TYPE_DAISY_CONFIGS) && ($DAISY != 1) ) {
	showerror("restore type only compatible with Daisy: $restore_type");
    }
    elsif ( ($restore_type eq $BU_TYPE_LOG_FILES) && is_restore_in_place() ) {
	showerror("restore type not allowed without alternate location: $restore_type");
    }
    else {
	$rc = 1;
    }

    return($rc);
}


sub tfr_restore_perms
{
    my ($restore_type) = @_;

    my $rc = 1;

    if ($restore_type eq $BU_TYPE_BBXD || $restore_type eq $BU_TYPE_BBXPS) {
	$restore_type = $BU_TYPE_USR2;
    }
    if ($restore_type eq $BU_TYPE_SINGLEFILE) {
	loginfo("[restore perms] perms are not saved for this backup type: $restore_type");
    }
    else {
	my $perm_file_path = tfrm_pathto_perm_file($restore_type);
	if ($perm_file_path) { 
	    print "[restore perms] restoring perms from $perm_file_path...";
	    if (tfr_restore_perms_from_perm_file($perm_file_path)) {
		print "\n";
		loginfo("[restore perms] perms restored from: $perm_file_path");
	    }
	    else {
		logerror("[restore perms] error restoring perms from perm file: $perm_file_path");
		$rc = 0;
	    }
	}
	else {
	    logerror("[restore perms] perm file does not exist for backup type: $restore_type");
	    $rc = 0;
	}
    }

    return($rc);
}


#
# top level sub for "--restore"
#
# Restore some or all files based on what restore type
# was specified on the commandline.  Also restore
# individual files if so specified as command line args.
#
# Returns
#   0 for success
#   !0 for error
#
sub tfr_restore_files
{
    my ($restore_ref, $restore_excludes_ref, $restore_dir) = @_;

    my $rc = 0;

    loginfo("[restore files] begin restore files");

    # Verify the luks device
    if ($DeviceType eq $DEVTYPE_LUKS) {
	if (tfr_luks_device_is_luks($DEVICE)) {
	    loginfo("[restore files] verified as LUKS device: $DEVICE");
	}
	else {
	    showerror("[restore files] could not verify LUKS device: $DEVICE");
	    return($EXIT_LUKS_VERIFY);
	}
    }

    # Verify the backup device is accessible via mount
    if ($DeviceType eq $DEVTYPE_BLOCK || $DeviceType eq $DEVTYPE_IMAGE) {
	mount_device("ro");
	if (is_rsync_bu_device_mounted()) {
	    unmount_device();
	}
	else {
	    showerror("[restore files] could not verify backup device is accessible via mount: $DEVICE");
	    return($EXIT_MOUNT_ERROR);
	}
    }

    #
    # "restore all" does not include "logfiles" anymore
    #
    my @restore_types = tfr_list_is_member_of($restore_ref, $BU_TYPE_ALL) ?
			    @RESTORE_EQUALS_ALL_BACKUP_TYPES :
			    @{$restore_ref};

    if ($CLOUD || $SERVER) {
	my $server_addr = ($SERVER) ? $RsyncServer : $CLOUD_SERVER;
	if (tfr_open_ssh_tunnel($RSYNC_ACCOUNT, $server_addr)) {
	    loginfo("[restore files] ssh tunnel socket opened: $RSYNC_ACCOUNT, $server_addr");
	}
	else {
	    showerror("[restore files] could not open ssh tunnel: $RSYNC_ACCOUNT, $server_addr");
	    return($EXIT_SSH_TUNNEL_OPEN);
	}
    }

    #
    # before restoring any files, first determine the kind
    # of source platform by restoring the pserver info file;
    # put it into a special directory reserved just for it.
    #
    if ($RestoreUpgradeCLO) {
	# make the pserver info restore dir if necessary
	my $restored_pserver_info_dir_path = tfrm_pathto_restored_pserver_info_dir();
	if (tfr_util_mkdir($restored_pserver_info_dir_path)) {
	    loginfo("[restore files] restored pserver info dir: $restored_pserver_info_dir_path");
	    my @no_excludes = ();
	    if (tfr_restore_by_type($BU_TYPE_PSERVER_INFO, \@no_excludes, $restored_pserver_info_dir_path)) {
		loginfo("[restore files] pserver info file restored to: $restored_pserver_info_dir_path");
	    }
	    else {
		logerror("[restore files] could not restore pserver info file");
	    }
	}
	else {
	    logerror("[restore files] could not make restored pserver info dir: $restored_pserver_info_dir_path");
	}
    }

    foreach my $restore_type (@restore_types) {

	last if ($SigIntSeen);

	if (is_restore_type_compatible($restore_type)) {

	    $rc = tfr_restore_by_type($restore_type, $restore_excludes_ref, $restore_dir);

	    if ($rc != 0) {
		showerror("[restore files] could not restore type: $restore_type");
		last;
	    }
	    else {
		if ($CLOUD || $SERVER) {
		    if (is_restore_in_place()) {
			if (tfr_restore_perms($restore_type)) {
			    loginfo("[restore files] perms restored for: $restore_type");
			}
			else {
			    logerror("[restore files] could not restore perms for: $restore_type");
			}
		    }
		}
	    }
	}
    }

    if ($CLOUD || $SERVER) {
	my $server_addr = ($SERVER) ? $RsyncServer : $CLOUD_SERVER;
	if (tfr_close_ssh_tunnel($RSYNC_ACCOUNT, $server_addr)) {
	    loginfo("[restore files] ssh tunnel socket closed: $RSYNC_ACCOUNT, $server_addr");
	}
	else {
	    showerror("[restore files] could not close ssh tunnel socket: $RSYNC_ACCOUNT, $server_addr");
	    return($EXIT_SSH_TUNNEL_CLOSE);
	}
    }

    #
    # take care of items that need attending to after
    # the restore is finished and doing an upgrade.
    #
    if ($rc == 0) {
	if ($CLOUD && $RestoreUpgradeCLO) {
	    my $users_listing_file = tfrm_pathto_users_listing_file();
	    my $users_shadow_file = tfrm_pathto_users_shadow_file();
	    if (-f $users_listing_file) {
		if (-f $users_shadow_file) {
		    if (tfr_restore_upgrade_restore_users($users_listing_file, $users_shadow_file)) {
			loginfo("[restore files] users restored after upgrade: $users_listing_file");
		    }
		    else {
			showerror("[restore files] could not restore users after upgrade: $users_listing_file");
		    }
		}
		else {
		    showerror("[restore files] file required for restore upgrade does not exist: $users_shadow_file");
		}
	    }
	    else {
		showerror("[restore files] file required for restore upgrade does not exist: $users_listing_file");
	    }
	}
    }

    if ($RestoreUpgradeCLO) {
	my $restored_pserver_info_dir_path = tfrm_pathto_restored_pserver_info_dir();
	if (tfr_util_rmdir($restored_pserver_info_dir_path)) {
	    loginfo("[restore files] restored pserver info dir removed: $restored_pserver_info_dir_path");
	}
	else {
	    logerror("[restore files] could not remove restored pserver info dir: $restored_pserver_info_dir_path");
	}
    }

    loginfo("[restore files] end restore files");

    return($rc);
}


#
# Call the function that handles the specified restore type.
#
sub tfr_restore_by_type
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = 0;

    # map restore types to a function
    my @ftab = (
	[\&tfr_restore_usr2, $BU_TYPE_USR2],
	[\&tfr_restore_bbxd, $BU_TYPE_BBXD],
	[\&tfr_restore_bbxps, $BU_TYPE_BBXPS],
	[\&tfr_restore_rticonfigs, $BU_TYPE_RTI_CONFIGS],
	[\&tfr_restore_daisy, $BU_TYPE_DAISY],
	[\&tfr_restore_dsyconfigs, $BU_TYPE_DAISY_CONFIGS],
	[\&tfr_restore_userconfigs, $BU_TYPE_USER_CONFIGS],
	[\&tfr_restore_printconfigs, $BU_TYPE_PRINT_CONFIGS],
	[\&tfr_restore_netconfigs, $BU_TYPE_NET_CONFIGS],
	[\&tfr_restore_osconfigs, $BU_TYPE_OS_CONFIGS],
	[\&tfr_restore_userfiles, $BU_TYPE_USER_FILES],
	[\&tfr_restore_logfiles, $BU_TYPE_LOG_FILES],
	[\&tfr_restore_singlefile, $BU_TYPE_SINGLEFILE],
	[\&tfr_restore_specialfiles, $BU_TYPE_PSERVER_CLOISTER],
	[\&tfr_restore_pserver_info, $BU_TYPE_PSERVER_INFO],
    );

    # now call the function appropriate to the restore type
    foreach my $ftab_entry (@ftab) {
	my ($func, $type) = @{$ftab_entry};
	if ($restore_type eq $type) {
	    $rc = &{$func}($restore_type, $restore_excludes, $restore_dir);
	    last;
	}
    }

    if ($rc != 0) {
	logerror("[restore by type] non-zero return code: $rc");
    }

    return($rc);
}


sub tfr_restore_transaction
{
    my ($torestore, $excludes, $bu_type, $restore_dir) = @_;

    # if there are no files to restore, just return
    if (scalar(@{$torestore}) == 0) {
	loginfo("[restore_transaction] empty list of paths to restore");
	return($EXIT_OK);
    }

    my $rc = 0;

    # form prefix for source argument if possible
    my $src_prefix = $EMPTY_STR;
    my $exclude_prefix = $EMPTY_STR;

    my $transaction_class = $EMPTY_STR;

    # restoring from a local device
    if ($DEVICE) {
	if ($LUKS) {
	    if (tfr_luks_device_mount($DEVICE)) {
		loginfo("[restore_transation] successful mount of LUKS device: $DEVICE");
	    }
	    else {
		logerror("[restore_transation] could not mount LUKS device: $DEVICE");
		return($EXIT_LUKS_MOUNT);
	    }
	}
	else {
	    if ($DRY_RUN == 0) {
		unmount_device();
		if (mount_device("ro")) {
		    logerror("[restore_transation] could not mount filesystem on: $DEVICE");
		    return($EXIT_MOUNT_ERROR);
		}
	    }
	}
	$src_prefix = "$MOUNTPOINT/$LuksDirCLO";
	$exclude_prefix = $src_prefix;
	$transaction_class = "device";
    }

    # restoring from a backup server
    elsif ($SERVER) {
	$src_prefix = $RSYNC_ACCOUNT . $ATSIGN . $RsyncServer . $COLON;

	# if backup type is a special backup type, ie, one that
	# does not get copied "in place", ie at the same path
	# on the backup server as it is on the primary server,
	# then source is the tfrsync backup directory.

	if ($IS_SERVER_SPECIAL_BACKUP_TYPE{$bu_type}) {
	    if ($RTI) {
		$src_prefix .= ($RsyncDir) ? $RsyncDir : $DEF_RTI_RSYNC_BU_DIR;
	    }
	    if ($DAISY) {
		$src_prefix .= ($RsyncDir) ? $RsyncDir : $DEF_DAISY_RSYNC_BU_DIR;
	    }
	}
	else {
	    $src_prefix .= ($RsyncDir) ? $RsyncDir : $SLASH;
	}
	$transaction_class = "server";
    }

    # restoring from a local file system
    elsif ($RsyncDir) {
	$src_prefix = $RsyncDir;
	$exclude_prefix = $src_prefix;
	$transaction_class = "local fs";
    }

    # restoring from a cloud server
    elsif ($CLOUD) {
	$src_prefix = $RSYNC_ACCOUNT . $ATSIGN . $CLOUD_SERVER . $COLON;
	$transaction_class = "cloud";
    }

    else {
	logerror("[retore_transation] restore source unspecified");
	return(-3);
    }

    loginfo("[restore_transation] begin transaction");

    if ($DEBUGMODE) {
	tfr_log_rsync_transaction($torestore, $excludes, $bu_type, $transaction_class);
    }
    else {
	loginfo("[restore_transation] restore type: $bu_type");
	loginfo("[restore_transation] restore class: $transaction_class");
	loginfo("[restore_transation] restore set: @{$torestore}");
	loginfo("[restore_transation] restore exclusions: @{$excludes}");
    }

    # write the list of the exclude files to a temp file IF the
    # backup type is not user specified files - it doesn't make sense to
    # have exceptions for user specified files.
    my $tfn = $EMPTY_STR;
    if ($bu_type ne $BU_TYPE_USER_FILES) {
	$tfn = tfr_rsync_exclude_file($excludes, $exclude_prefix);
	if ($tfn) {
	    loginfo("[restore_transation] tempfile for rsync excludes: $tfn");
	}
    }

    # start forming the rsync command
    my $rsync_cmd = "rsync -ahv";

    # if path to ssh identity file exists, add it to command
    my $ssh_id_path = tfr_pathto_ssh_id_file($RSYNC_ACCOUNT);
    if (-e $ssh_id_path) {
	$rsync_cmd .= " -e \'ssh -i $ssh_id_path";

	# if using ssh tunnel, add it to ssh option
	my $ssh_tunnel_socket_path = tfr_pathto_ssh_tunnel_socket();
	if (-e $ssh_tunnel_socket_path) {
	    $rsync_cmd .= " -o ControlPath=$ssh_tunnel_socket_path";
	}

	$rsync_cmd .= $SINGLEQUOTE;
    }

    # dry run or not
    if ($RSYNC_TRIAL) {
	$rsync_cmd .= " -n";
    }

    # delete files located in destination that are not in source
    if  (! $CLOUD) {
	$rsync_cmd .= " --delete";
    }

    # specify exclude list if not empty
    if ($tfn) {
	$rsync_cmd .= " --exclude-from=$tfn";
    }

    # set up the temp dir location, default to local
    # if the rsync options array already has it specified,
    # then do nothing, else add it.
    if  (! $CLOUD) {
	my $temp_dir_option_seen = 0;
	for (@RSYNC_OPTIONS) {
	    if (/^--temp-dir=/) {
		$temp_dir_option_seen = 1;
		last;
	    }
	}
	if (! $temp_dir_option_seen) {
	    if ($RTI) {
		unshift(@RSYNC_OPTIONS, "--temp-dir=/usr2");
	    }
	    if ($DAISY) {
		unshift(@RSYNC_OPTIONS, "--temp-dir=/tmp");
	    }
	}
    }

    # add timeout option
    if ($RSYNC_TIMEOUT) {
	$rsync_cmd .= " --timeout=$RSYNC_TIMEOUT";
    }

    # add any extra options specified in config file
    foreach (@RSYNC_OPTIONS) {
	$rsync_cmd .= " $_";
    }

    # commands to run
    if ($CLOUD || $SERVER) {
	$rsync_cmd = "cd /; $rsync_cmd --relative";
    }
    else {
	$rsync_cmd = "cd $MOUNTPOINT/$LuksDirCLO; $rsync_cmd --relative";
    }

    if ($SERVER) {
	$rsync_cmd .= " --rsync-path=\'sudo rsync\'";
    }

    #
    # Loop through all the paths to restore
    #
    foreach my $src (@{$torestore}) {

	last if ($SigIntSeen);

	my $cmd = $rsync_cmd;

	my $src_path = $src;
	if ($CLOUD || $LUKS) {
	    $src_path =~ s/^\///;
	}

	if ($LUKS) {
	    $cmd .= " $src_path";
	}
	else {
	    # source and destination arguments
	    $cmd .= " $src_prefix";
	    $cmd .= "$src_path";
	}

	my $dst = $restore_dir;
	$cmd .= " $dst";

	# exec the remote command
	if ($DRY_RUN) {
	    system("echo \"$cmd\"");
	}
	else {
	    loginfo("[restore_transation] restore command: $cmd");

	    $rc = system("$cmd 2>&1 | tee -a $LOGFILE ; ( exit \${PIPESTATUS[0]} )");

	    # break on errors
	    if ($rc == 0) {
		loginfo("[restore_transation] restore command successful: $rc");
	    }
	    else {
		last;
	    }
	}
    }

    if ($tfn) {
	unlink($tfn);
    }

    if (! $DRY_RUN) {
	if ($DEVICE) {
	    if ($LUKS) {
		if (tfr_luks_device_umount($DEVICE)) {
		    loginfo("[restore_transation] successful umount of LUKS device: $DEVICE");
		}
		else {
		    logerror("[restore_transation] could not umount LUKS device: $DEVICE");
		}
	    }
	    else {
		unmount_device();
	    }
	}
    }

    loginfo("[restore_transation] end transaction");

    return($rc);
}


# Restore RTI /usr2
sub tfr_restore_usr2
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;

    showinfo("[restore_usr2] restore: $restore_type");

    #
    # Only stop RTI if restoring on top of /usr2...
    # which is true only if restoring in place.
    #
    my $clobber_rti = (is_restore_in_place()) ? 1 : 0;

    #
    # If /usr2 is being restored, then two things have to happen:
    # 1) RTI must be stopped
    # 2) the log file location must be moved
    #
    my $old_logfile_path = $EMPTY_STR;

    if (! $DRY_RUN) {
	if ($clobber_rti) {
	    showinfo("[restore_usr2] stopping RTI");
	    # stop RTI
	    if (-f "$RTIDIR/bin/killem") {
		loginfo("killing rti processes: $RTIDIR/bin/killem");
		system("$RTIDIR/bin/killem >> $LOGFILE 2>> $LOGFILE");
	    }

	    # stop RTI services
	    my @rti_services = qw(
		httpd
		bbj
		rti
	    );

	    foreach my $service_name (@rti_services) {
		if (-f "/etc/rc.d/init.d/$service_name") {
		    system("/sbin/service $service_name stop >> $LOGFILE 2>> $LOGFILE");
		    if ($? == 0) {
			loginfo("[restore_usr2] service stopped: $service_name");
		    }
		    else {
			logerror("[restore_usr2] could not stop service: $service_name");
		    }
		}
	    }

	    # move logfile location
	    $old_logfile_path = log_change_location();
	}
    }

    # Should we *not* restore some files?
    if (-d "/usr2/basis") {
	push(@{$restore_excludes}, "/usr2/basis");
    }

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("[restore_usr2] files to be restored: @torestore");
	loginfo("[restore_usr2] files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("[restore_usr2] files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    if (! $DRY_RUN) {
	if ($rc == 0) {
	    if ($clobber_rti) {
		# arrange to run both rti_perms.pl
		$RUN_RTI_PERMS = 1;

		if ($old_logfile_path ne $EMPTY_STR) {
		    log_restore_location($old_logfile_path);
		}

		showinfo("[restore_usr2] *** Make sure to restart 'bbj', 'rti' and 'httpd' services.");
	    }

	    #
	    # Make correct symlink for tcc based on which OS we are on.
	    #
	    loginfo("[restore_usr2] making TCC links for: $OS");
	    if ($OS eq 'RHEL4') {
		if (-e "/usr2/bbx/bin/tcc2_linux") {
		    system("ln -sf /usr2/bbx/bin/tcc2_linux /usr2/bbx/bin/tcc");
		    system("ln -sf /usr2/bbx/bin/tcc_linux /usr2/bbx/bin/tcc_tws");
		}
		else {
		    system("ln -sf /usr2/bbx/bin/tcc_linux /usr2/bbx/bin/tcc");
		}
	    }

	    elsif ($OS eq 'RHEL5') {
		if (-e "/usr2/bbx/bin/tcc2_x64") {
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
		logerror("[restore_usr2] could not make TCC links: unsupported platform: $OS");
	    }
	}
    }

    return($rc);
}


sub tfr_restore_bbxd
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;

    my $verb = (is_restore_in_place()) ? "restoring" : "retrieving";
    showinfo("[restore_bbxd] $verb directory: $restore_type");

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("[restore_bbxd] files to be restored: @torestore");
	loginfo("[restore_bbxd] files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("[restore_bbxd] files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    return($rc);
}


sub tfr_restore_bbxps
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;

    my $verb = (is_restore_in_place()) ? "restoring" : "retrieving";
    showinfo("[restore_bbxps] $verb directory: $restore_type");

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("[restore_bbxps] files to be restored: @torestore");
	loginfo("[restore_bbxps] files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("[restore_bbxps] files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    return($rc);
}


# Restore RTI Config Files
sub tfr_restore_rticonfigs
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;

    showinfo("[restore_rticonfigs] restoring: $restore_type");

    if (! $DRY_RUN) {
	if (is_restore_in_place()) {
	    showinfo("[restore_rticonfigs] stopping RTI");
	    # must stop RTI
	    if (-f "$RTIDIR/bin/killem") {
		system("$RTIDIR/bin/killem 2>> $LOGFILE");
	    }
	    if (-f "/etc/rc.d/init.d/rti") {
		system("/sbin/service rti stop 2>> $LOGFILE");
	    }
	}
    }

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("[restore_rticonfigs] files to be restored: @torestore");
	loginfo("[restore_rticonfigs] files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("[restore_rticonfigs] files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    if (! $DRY_RUN) {
	if ( ($rc == 0) && is_restore_in_place() ) {
	    system("/sbin/chkconfig --add --level 35 rti 2>> $LOGFILE");
	    system("/sbin/chkconfig --add --level 35 blm 2>> $LOGFILE");
	    system("/sbin/chkconfig --add --level 35 bbj 2>> $LOGFILE");

	    $RUN_HARDEN_LINUX = 1;
	    $RUN_RTI_PERMS = 1;

	    showinfo("[restore_rticonfigs] *** Make sure to restart 'rti' service");
	}
    }

    return($rc);
}


# Restore Daisy /d
sub tfr_restore_daisy
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;

    showinfo("[restore_daisy] restoring: $restore_type");

    #
    # Only bring down Daisy if restoring on top of daisy...  which
    # is true only if restoring to the top of the file system - the
    # default value for the restore root directory.
    #
    my $clobber_daisy = (is_restore_in_place()) ? 1 : 0;

    my $old_logfile_path = $EMPTY_STR;

    if (! $DRY_RUN) {
	if ($clobber_daisy) {
	    # move logfile location
	    $old_logfile_path = log_change_location();
	    showinfo("[restore_daisy] stopping daisy");
	    tfr_daisy_stop();
	}
    }

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("[restore_daisy] files to be restored: @torestore");
	loginfo("[restore_daisy] files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("[restore_daisy] files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    if (! $DRY_RUN) {
	if ($rc == 0) {
	    if ($clobber_daisy) {
		showinfo("[restore_daisy] starting daisy");
		tfr_daisy_start();

		# arrange to run both dsy_perms.pl and harden_linux.pl
		$RUN_HARDEN_LINUX = 1;
		$RUN_DAISY_PERMS = 1;

		if ($old_logfile_path ne $EMPTY_STR) {
		    log_restore_location($old_logfile_path);
		}
	    }
	}
    }

    return($rc);
}


# Restore Daisy Config Files
sub tfr_restore_dsyconfigs
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;

    showinfo("[restore_dsyconfigs] restoring: $restore_type");

    #
    # Only stop Daisy if restoring on top of /d...  which
    # is true only if restoring in place.
    #
    my $clobber_daisy = (is_restore_in_place()) ? 1 : 0;

    if (! $DRY_RUN) {
	if ($clobber_daisy) {
	    showinfo("[restore_dsyconfigs] stopping daisy");
	    tfr_daisy_stop();
	}
    }

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("[restore_dsyconfigs] files to be restored: @torestore");
	loginfo("[restore_dsyconfigs] files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("[restore_dsyconfigs] files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    if (! $DRY_RUN) {
	if ($rc == 0) {
	    if ($clobber_daisy) {
		showinfo("[restore_dsyconfigs] starting daisy");
		tfr_daisy_start();

		# arrange to run both dsy_perms.pl and harden_linux.pl
		$RUN_HARDEN_LINUX = 1;
		$RUN_DAISY_PERMS = 1;
	    }
	}
    }

    return($rc);
}


# Restore OS User Config Files
sub tfr_restore_userconfigs
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;


    showinfo("Restoring OS User Configs...");

    my @torestore = tfr_backup_file_list($restore_type);

    # remove from list of files to restore those files that
    # are almost certainly going to be different when upgrading,
    # especially when upgrading between os releases
    if ($RestoreUpgradeCLO) {
	my @userconfig_excludes = qw(
	    /etc/pam.d
	    /etc/login.defs
	    /etc/shadow
	    /etc/shadow-
	    /etc/gshadow
	    /etc/gshadow-
	    /etc/passwd
	    /etc/passwd-
	    /etc/group
	    /etc/group-
	);

	# inefficient - loop through entire list for each file
	# to be excluded!  thankfully, list is short.
	foreach my $exclude (@userconfig_excludes) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
    }

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("files to be restored: @torestore");
	loginfo("files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    if (! $DRY_RUN) {
	if ( ($rc == 0) && is_restore_in_place() ) {
	    if ($OS eq 'RHEL6') {
		my @shadow_files = qw( /etc/shadow /etc/shadow- /etc/gshadow /etc/gshadow- );
		if (tfr_file_perms_unset_readable(\@shadow_files)) {
		    loginfo("[restore userconfigs] shadow files restored to unreadable");
		}
		else {
		    logerror("[restore userconfigs] could not restore shadow files to unreadable");
		}
	    }

	    loginfo("restarting crond...");
	    system("/sbin/service crond restart 2>> $LOGFILE");
	}
    }

    loginfo("END Restore OS User Configs");

    return($rc);
}


# Restore User Specified Files
sub tfr_restore_userfiles
{ 
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = 0;

    showinfo("Restoring User Specified Files...");

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("files to be restored: @torestore");
	loginfo("files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("files to be restored minus files to be excluded: @torestore");
    }

    if (scalar(@torestore)) {
	$rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);
    }
    else {
	loginfo("[restore user files] no user files specified");
    }

    loginfo("END Restore User Files");

    return($rc);
}


# Restore OS Log Files
#
# Returns
#   0 on success
#   non-zero on error
#
sub tfr_restore_logfiles
{ 
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = 0;

    if ($RestoreUpgradeCLO) {
	loginfo("log files NOT restored: --restore-upgrade specified");
    }
    else {
	showinfo("Restoring Log Files...");

	my @torestore = tfr_backup_file_list($restore_type);

	$rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

	loginfo("END Restore Log Files");
    }

    return($rc);
}


# Restore OS Config Files
sub tfr_restore_osconfigs
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;
    my $datestamp = $EMPTY_STR;

    showinfo("[restore_osconfigs] restoring: $restore_type");

    # What *not* to restore
    if(-f "/etc/httpd/conf.d/rti.conf") {
	push(@{$restore_excludes}, "/etc/httpd/conf.d/rti.conf");
    }
    if(-f "/etc/sysconfig/rhn/systemid") {
	push(@{$restore_excludes}, "/etc/sysconfig/rhn");
    }

    # if restoring on top of OS locations, copy critical files
    # before blowing them away.
    if (is_restore_in_place()) {
	$datestamp = POSIX::strftime("%Y-%m-%d_%H%M%S", localtime());
	system("cp /etc/inittab /etc/inittab.$datestamp");
    }

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("[restore_osconfigs] files to be restored: @torestore");
	loginfo("[restore_osconfigs] files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("[restore_osconfigs] files to be restored minus files to be excluded: @torestore");
    }

    #
    # some messiness: if restoring FROM RHEL5 TO RHEL6 or RHEL7,
    # then some files will have to be excluded.
    #
    # if source platform of backup set == RHEL5 and
    # dst platform == RHEL6 then
    #	    remove "rsyslog.conf" from restore list

    if ($RestoreUpgradeCLO) {
	my $restored_pserver_info_dir_path = tfrm_pathto_restored_pserver_info_dir();
	my $pserver_info_file_path = tfrm_pathto_pserver_info_file();
	my $restored_pserver_info_file_path = File::Spec->catdir($restored_pserver_info_dir_path,
								 $pserver_info_file_path);
	my %pserver_info = ();
	loginfo("[restore_osconfigs] restored pserver info file path: $restored_pserver_info_file_path");
	if (tfr_read_pserver_info_file($restored_pserver_info_file_path, \%pserver_info)) {
	    loginfo("[restore_osconfigs] restored pserver info file read: $restored_pserver_info_file_path");
	    if ( ($pserver_info{$SERVER_INFO_PLATFORM} eq 'RHEL5') &&
		 ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) ) {
		@torestore = grep { $_ ne '/etc/rsyslog.conf' } @torestore;
	    }
	}
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    if (! $DRY_RUN) {
	if ( ($rc == 0) && is_restore_in_place() ) {

	    my $service_name = ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) ? 'rsyslog' : 'syslog';
	    system_service_restart($service_name);
	    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
		system_service_restart('rhnsd');
	    }
	    system_service_restart('sendmail');

	    if ($RestoreUpgradeCLO && ($OS eq 'RHEL6')) {
		my $conf_file = '/etc/samba/smb.conf';
		tfr_restore_upgrade_samba_conf($conf_file);
		$conf_file = '/etc/samba/smbpasswd';
		tfr_restore_upgrade_samba_rebuild_passwd($conf_file);
	    }

	    system_service_restart('smb');

	    if ($RTI) {
		if (-f "/etc/rc.d/init.d/httpd 2>> $LOGFILE") {
		    system_service_restart('httpd');
		}
	    }

	    my $posdir = ($RTI) ? $RTIDIR : $DAISYDIR;

	    # (Re) Setup tfremote
	    if (-f "$posdir/bin/tfremote.pl") {
		system("$posdir/bin/tfremote.pl --install 2>> $LOGFILE");
	    }
	    else {
		logerror("[restore_osconfigs] file does not exist: $posdir/bin/tfremote.pl");
		logerror("[restore_osconfigs] could not install: $posdir/bin/tfremote.pl");
	    }

	    $RUN_HARDEN_LINUX = 1;
	}
    }

    return($rc);
}


#
# Don't preserve the "HWADDR=" line in ifcfg-eth0. This causes issues
# when migrating ethernet configs from an older server to a new server.
#
sub tfr_edit_ifcfg
{
    my $oldfile = "/etc/sysconfig/network-scripts/ifcfg-eth0";
    my $newfile = "/etc/sysconfig/network-scripts/ifcfg-eth0.$$";

    if (open(my $old, '<', $oldfile)) {
	if (open(my $new, '>', $newfile)) {
	    while(<$old>) {
		if (/HWADDR/) {
		    print {$new} "# ";
		}
		print $new;
	    }
	    close($new);
	}
	close($old);
    }

    if (-s $newfile > 0) {
	system("mv $newfile $oldfile");
    }

    return(1);
}


# Restore OS Network Config Files
sub tfr_restore_netconfigs
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;

    showinfo("Restoring Network Configs...");

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("files to be restored: @torestore");
	loginfo("files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    if (! $DRY_RUN) {
	if ( ($rc == 0) && is_restore_in_place() ) {
	    tfr_edit_ifcfg();

	    $RUN_HARDEN_LINUX = 1;
	}
    }

    loginfo("END Restore Network Configs");

    return($rc);
}


# Restore Print Config Files
sub tfr_restore_printconfigs
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;

    showinfo("Restoring Printer Configs...");

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("files to be restored: @torestore");
	loginfo("files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    if (! $DRY_RUN) {
	if ( ($rc == 0) && is_restore_in_place() ) {
	    system("/sbin/service cups restart 2>> $LOGFILE");
	}
    }

    loginfo("END Restore Printer Configs");

    return($rc);
}


#
# If user specified:
#
#   --restore=singlefile --singlefile="/usr2/bbx/blah,/etc/sysconfig/blah"
#
# then this subroutine restores those specific files.
#
# Restore a single file from the backup server or the backup device.
#
sub tfr_restore_singlefile
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;

    showinfo("Restoring Single Files...");

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("files to be restored: @torestore");
	loginfo("files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    loginfo("End Restore Single Files");

    return($rc);
}


sub tfr_restore_specialfiles
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;

    showinfo("restoring special files...");

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("files to be restored: @torestore");
	loginfo("files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    loginfo("end restore special files");

    return($rc);
}


sub tfr_restore_pserver_info
{
    my ($restore_type, $restore_excludes, $restore_dir) = @_;

    my $rc = -1;

    showinfo("restoring pserver info...");

    my @torestore = tfr_backup_file_list($restore_type);

    # remove elements in the "files to be excluded" list from
    # the "files to be restored" list.
    if ($RestoreUpgradeCLO) {
	loginfo("files to be restored: @torestore");
	loginfo("files to be excluded: @{$restore_excludes}");
	foreach my $exclude (@{$restore_excludes}) {
	    @torestore = grep { $_ ne $exclude } @torestore;
	}
	loginfo("files to be restored minus files to be excluded: @torestore");
    }

    $rc = tfr_restore_transaction(\@torestore, $restore_excludes, $restore_type, $restore_dir);

    loginfo("end restore pserver info");

    return($rc);
}


#
# --finddev | --report-device
#
# There should be a generalized name for the backup device.
# In the future, if some device other than a WD Passport
# was to be supported, there is going to be significant
# changes to the code.
#
# returns
#   $EXIT_OK on success
#   $EXIT_BACKUP_DEVICE_NOT_FOUND 
#
sub tfr_finddev
{
    my $rc = $EXIT_OK;

    my $device_type = "USB Device";
    my $device_file = tfr_find_usb_device();
    if ($device_file) {
	my $fs_uuid = tfr_get_filesys_uuid($device_file);
	if ($fs_uuid) {
	    $device_file .= " (filesystem UUID: $fs_uuid)";
	}
	showinfo("$device_type: $device_file");
    }
    else {
	$device_type = "Passport Device";
	$device_file = tfr_find_passport();
	if ($device_file) {
	    my $fs_uuid = tfr_get_filesys_uuid($device_file);
	    if ($fs_uuid) {
		$device_file .= " (filesystem UUID: $fs_uuid)";
	    }
	    showinfo("$device_type: $device_file");
	}
	else {
	    showerror("[tfr_finddev] backup device not found");
	    $rc = $EXIT_BACKUP_DEVICE_NOT_FOUND;
	}
    }

    return($rc);
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
    my $udev_opt = $EMPTY_STR;
    if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	$udev_cmd = '/sbin/udevadm';
	$udev_opt = 'info';
    }

    # then verify it exists
    if (!(-f $udev_cmd)) {
	logerror("command to get udev info does not exist: $udev_cmd");
	return($rc);
    }

    if (open(my $pipe, q{-|}, "$udev_cmd $udev_opt -q env -n $dev_file")) {
	while (<$pipe>) {
	    if (/ID_BUS=usb/) {
		$rc = 1;
		last;
	    }
	}
	close($pipe);
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

    my $rc = $EMPTY_STR;

    # verify command to read filesystem label exists
    my $e2label_cmd = '/sbin/e2label';
    if (!(-f $e2label_cmd)) {
	logerror("command to read filesystem label does not exist: $e2label_cmd");
	return($rc);
    }

    if (open(my $pipe, q{-|}, "$e2label_cmd $dev_file")) {
	$rc = <$pipe>;
	chomp($rc);
	close($pipe)
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
	if ($fs_label eq $EMPTY_STR) {
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
# Returns:
#   device file name if disk found is on USB bus and has Teleflora label
#   empty string if not
#
sub tfr_find_usb_device
{
    my $returnval = $EMPTY_STR;
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
	if (! -b $this_dev_file) {
	    next;
	}

	# if on USB bus and has Teleflora filesystem label,
	# then we found one.
	if (is_on_usb_bus($this_dev_file)) {
	    if (is_teleflora_fs_label($this_dev_file)) {
		$returnval = $this_dev_file;
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

    if (! -d '/sys/block') {
	logerror("Warning: Cannot look for Passport device: \"/sys\" filesystem not present.");
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
	if (open(my $file, '<', $sys_vendor_file)) {
	    while (<$file>) {
		if (/$DEVICE_VENDOR/i) {
		    $found = 1;
		    last;
		}
	    }
	    close($file);
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
	if (open(my $file, '<', $sys_model_file)) {
	    while (<$file>) {
		if (/$DEVICE_MODEL/i) {
		    $found = 1;
		    last;
		}
	    }
	    close($file);
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
sub tfr_find_passport
{
    foreach my $thisdev ("sda", "sdb", "sdc", "sdd", "sde") {

	my $rc = is_wd_passport($thisdev);
	if ($rc == 1) {
	    return("/dev/$thisdev");
	}
	elsif ($rc == -1) {
	    last;
	}
    }

    return($EMPTY_STR);
}


sub is_mount_required
{
    my ($bu_device_type) = @_;

    if ($bu_device_type eq $DEVTYPE_LUKS || $bu_device_type eq $DEVTYPE_IMAGE) {
	return(1);
    }
    return(0);
}


#
# Is the rsync backup device already mounted?
#
# Returns
#   1 means "yes, the device is mounted."
#   0 means "no, the device is not mounted."
#
sub is_rsync_bu_device_mounted
{
    my $rc = 0;

    # Does the backup device mount point exist?
    if (! -e $MOUNTPOINT) {
	logerror("Backup Device mount point \"$MOUNTPOINT\" not found.");
	return($rc);
    }

    my $proc_mount_file = "/proc/mounts";
    if (open(my $file, '<', $proc_mount_file)) {
	while (<$file>) {
	    if (/$MOUNTPOINT/) {
		$rc = 1;
		last;
	    }
	    if (/$DEVICE/) {
		$rc = 1;
		last;
	    }
	}
	close($file);
    }
    else {
	logerror("error opening /proc mounts file: $proc_mount_file");
    }

    return($rc);
}


#
# Mount either a block device, or an "image file".
#
# Returns
#   0 means "yes, mount succeeded"
#   non-zero means "no, the mount failed."
#
sub mount_device
{
    my ($mount_opt) = @_;

    # Is our mountpoint present?
    if (! -d $MOUNTPOINT) {
	loginfo("[mount_device] mountpoint does not exist: $MOUNTPOINT");
	mkdir("$MOUNTPOINT");
    }
    if (! -d $MOUNTPOINT) {
	showerror("[mount_device] could not make mountpoint: $MOUNTPOINT");
	return(-3);
    }

    if (is_rsync_bu_device_mounted()) {
	showinfo("[mount_device] device already mounted: $DEVICE");
	system("umount $DEVICE > /dev/null 2>&1");
	if ($? != 0) {
	    showerror("[mount_device] could not umount device: $DEVICE");
	    return(-3);
	}
    }

    my $device_type = $EMPTY_STR;
    if (-b $DEVICE) {
	$device_type = "device";
    }
    elsif (-f $DEVICE) {
	$device_type = "image file";
	$mount_opt .= ",loop";
    }
    else {
	showerror("[mount_device] unknown device: $DEVICE");
	return(-3);
    }

    if ($VERBOSE) {
	showinfo("[mount_device] mounting \"$DEVICE\" -> \"$MOUNTPOINT\"");
    }

    system("mount -t ext2 -o $mount_opt $DEVICE $MOUNTPOINT > /dev/null 2>&1");
    if ($? != 0) {
	showerror("[mount_device] could not mount $device_type: $DEVICE on mountpoint: $MOUNTPOINT");
	return(-3);
    }

    return(0);
}


sub unmount_device
{
    my $returnval = -1;

    if ($DEVICE ne $EMPTY_STR) {
	if (is_rsync_bu_device_mounted()) {
	    if ($VERBOSE) {
		showinfo("Un-mounting \"$DEVICE\"");
	    }

	    system("umount $DEVICE");
	    $returnval = $?;
	}
    }

    return($returnval);
}


#
# Run the harden script on the POS, with an input argument of either
# "$DAISYDIR" or "$RTIDIR".
#
sub run_harden_linux
{
    my $posdir = $EMPTY_STR;
    my $rc = 1;

    if ($RTI) {
	$posdir = $RTIDIR;
    }
    elsif ($DAISY) {
	$posdir = $DAISYDIR;
    }

    if (-f "$posdir/bin/harden_linux.pl") {
	showinfo("Running $posdir/bin/harden_linux.pl");
	system("perl $posdir/bin/harden_linux.pl 2>> $LOGFILE");
    } else {
	logerror("Error: expecting script to exist: $posdir/bin/harden_linux.pl");
	logerror("Error: could not run: $posdir/bin/harden_linux.pl");
	$rc = 0;
    }

    return($rc);
}


#
# Run rtiperms.pl on the RTI application files.
#
sub set_rti_perms
{
    my $rc = 1;

    if (-f "$RTIDIR/bin/rtiperms.pl") {
	showinfo("Running $RTIDIR/bin/rtiperms.pl /usr2/bbx");
	system("perl $RTIDIR/bin/rtiperms.pl /usr2/bbx 2>> $LOGFILE");
    } else {
	logerror("Error: expecting script to exist: $RTIDIR/bin/rtiperms.pl");
	logerror("Error: could not run: $RTIDIR/bin/rtiperms.pl /usr2/bbx");
	$rc = 0;
    }

    return($rc);
}


#
# start the Daisy POS
#
# returns
#   1 on success
#   0 if error
#
sub tfr_daisy_start
{
    if ($OS eq 'RHEL5' || $OS eq 'RHEL6') {
	if (get_runlevel() != 3) {
	    if (! set_runlevel(3)) {
		logerror("[daisy_start] could not set runlevel to 3");
		return(0);
	    }
	}

	if (get_runlevel() != 3) {
	    logerror("[daisy_start] could not set runlevel to 3");
	    return(0);
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
	    system("systemctl start $_");
	}

	showinfo("[daisy_start] gettys restarted");
    }

    return(1);
}


#
# stop the Daisy POS
#
# returns
#   1
#
sub tfr_daisy_stop
{
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	system("/sbin/init 4");
	# wait is suggested by init(1) man page
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

	showinfo("[daisy_stop] gettys stopped");
    }

    if (-e $DAISYDIR) {
	system("$DAISYDIR/utils/killemall 2>> $LOGFILE");
    }

    return(1);
}


#
# the Daisy POS can have one or more daisy db dirs.
#
# return
#   list of zero or more daisy db dirs
#
sub tfr_daisy_get_db_dirs
{
    my @daisy_db_dirs = ();

    # if not a Daisy system, then list is empty, we are done
    if (! -d $DAISYDIR) {
	return(@daisy_db_dirs);
    }

    my @d_dirs = glob("$DAISY_TOPDIR/*");

    for my $d_dir (@d_dirs) {

	# must be a directory
	if (! -d $d_dir) {
	    next;
	}

	# skip old daisy dirs
	if ($d_dir =~ /.+-\d{12}$/) {
	    next;
	}

	# must contain some mandatory files and directories
	if (! -e "$d_dir/flordat.tel") {
	    next;
	}
	if (! -e "$d_dir/control.dsy") {
	    next;
	}
	if (! -d "$d_dir/bin") {
	    next;
	}
	if (! -d "$d_dir/log") {
	    next;
	}

	push(@daisy_db_dirs, $d_dir);
    }

    return(@daisy_db_dirs);
}


#
# Run dsyperms.pl on all possible daisy database dirs... always remember
# that there can be multiple daisy database dirs!
#
# Look for all directories in "/d" that contain files named
# "flordat.tel" and "control.dsy".  Skip old dirs.
#
# returns
#   1 on success
#   0 if error
#
sub tfr_daisy_set_perms
{
    my @daisy_db_dirs = tfr_daisy_get_db_dirs();
    my $dsyperms_cmd = "$DAISY_BINDIR/dsyperms.pl";

    if (! -f "$DAISY_BINDIR/dsyperms.pl") {
	logerror("[daisy_set_perms] script does not exist: $dsyperms_cmd");
	return(0);
    }

    my $rc = 1;

    for my $daisy_db_dir (@daisy_db_dirs) {
	showinfo("[daisy_set_perms] running: $dsyperms_cmd $daisy_db_dir");
	system("perl $dsyperms_cmd $daisy_db_dir 2>> $LOGFILE");
	if ($? != 0) {
	    $rc = 0;
	}
    }

    return($rc);
}


#
# get the POS shopcode, for either RTI or Daisy
#
# Returns:
#   shopcode as 8 digit string on success
#   empty string on error
#
sub tfr_pos_get_shopcode
{
    my $shopcode = $EMPTY_STR;

    my $rti_dir = tfr_pathto_rti_dir();
    my $daisy_dir = tfr_pathto_daisy_dir();

    if (-d $rti_dir) {
	my $dove_cfg_file = tfr_pathto_rti_shopcode_file();
	if (-f $dove_cfg_file) {
	    if (open(my $df, '<', $dove_cfg_file)) {
		while (<$df>) {
		    if (/DOVE_USERNAME\s*=\s*([[:print:]]+)/) {
			$shopcode = $1;
			last;
		    }
		}
		close($df);
	    }
	}
	else {
	    logerror("[pos_get_shopcode] RTI shopcode file does not exist: $dove_cfg_file");
	}
    }
    elsif (-d $daisy_dir) {
	my $dove_cfg_file = tfr_pathto_daisy_shopcode_file();
	if (-f $dove_cfg_file) {
	    if (open(my $df, '<', $dove_cfg_file)) {
		my $buffer;
		my $rc = sysread($df, $buffer, 38);
		if (defined($rc) && $rc != 0) {
		    $shopcode = substr($buffer, 30, 8);
		}
		close($df);
	    }
	}
	else {
	    logerror("[pos_get_shopcode] Daisy shopcode file does not exist: $dove_cfg_file");
	}
    }
    else {
	logerror("[pos_get_shopcode] could not get shopcode, neither directory exists: $rti_dir, $daisy_dir");
    }

    return($shopcode);
}


sub tfr_send_email
{
    my ($subject, $message) = @_;

    my $rc = 1;

    if ($DRY_RUN) {
	return($rc);
    }

    if (! is_configured_email_recipients()) {
	return($rc);
    }

    # first choice, send via "sendmail"
    if (is_configured_sendmail()) {
	# Use the sendmail program directly
	if (send_email_sendmail($subject, $message)) {
	    loginfo("email sent via sendmail: $subject");
	}
	else {
	    logerror("could not send email via sendmail: $subject}");
	    $rc = 0;
	}
    }

    # second choice via configured SMTP server with credentials
    # If configured to do so, try sending email via smtp server
    elsif (is_configured_smtp_mail()) {
	if (send_email_smtp($subject, $message)) {
	    loginfo("email sent via SMTP server: $subject}");
	}
	else {
	    logerror("could not send email via SMTP server: $subject}");
	    $rc = 0;
	}
    }

    # no third choice
    else {
	logerror("could not send email message - email not configured");
	$rc = 0;
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
    my ($subject, $message) = @_;

    my $hostname = hostname();
    my $rc = 1;

    foreach my $recipient (@EMAIL_RECIPIENTS) {

	# Connect to an SMTP server.
	my $smtp = Net::SMTP->new($EMAIL_SERVER, Port=> 25);
	if ($smtp) {
	    $smtp->auth($EMAIL_USER, $EMAIL_PASS);
	    $smtp->mail("backups\@$hostname");
	    $smtp->to("$recipient\n", {SkipBad => 1} );
	    $smtp->data();
	    $smtp->datasend("From: backups\@$hostname\n");
	    $smtp->datasend("To: $recipient\n");
	    $smtp->datasend("Subject: $subject\n");
	    $smtp->datasend("\n");
	    $smtp->datasend("$message\n");
	    $smtp->dataend();
	    $smtp->quit;
	    loginfo("email sent via SMTP server to: $recipient");
	}
	else {
	    logerror("could not connect to SMTP server: $EMAIL_SERVER");
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
    my ($subject, $message) = @_;

    my $rc = 1;

    my $sendmail_cmd = '/usr/lib/sendmail';
    if (! -e $sendmail_cmd) {
	logerror("[send_email_sendmail] sendmail command does not exist: $sendmail_cmd");
	return(0);
    }

    my $hostname = hostname();
    my $from = "$PROGNAME\@${hostname}.teleflora.com";

    my $cmd = "$sendmail_cmd -oi -t";

    foreach my $recipient (@EMAIL_RECIPIENTS) {
	if (open(my $mail, q{|-}, $cmd)) {
	    print {$mail} "From: $from\n";
	    print {$mail} "To: $recipient\n";
	    print {$mail} "Subject: $subject\n\n";
	    print {$mail} "$message\n";
	    close($mail);
	    loginfo("[send_email_sendmail] email sent via sendmail to: $recipient");
	}
	else {
	    logerror("[send_email_sendmail] could not connect to sendmail cmd: $cmd");
	    $rc = 0;
	}
    }

    return($rc);
}

#
# --send-test-email
#
# send a test email msg via any configured email methods
# to verify that the system's email is working.
#
# returns
#   1 on success
#   0 if error
#
sub tfr_send_test_email
{
    my $sub_name = "tfr_send_test_email";

    my $hostname = hostname();
    my $what = $PROGNAME . $ATSIGN . $hostname;
    my $timestamp = POSIX::strftime("%Y-%m-%d", localtime());
    my $subject = "test message from $what sent at $timestamp";
    my $message = "This is a test message from the script $PROGNAME running on host $hostname\n";

    my $rc = $EXIT_OK;

    if (tfr_send_email($subject, $message)) {
	showinfo("[$sub_name] test message sent via configured email");
    }
    else {
	showerror("[$sub_name] could not send test message");
	$rc = $EXIT_SEND_TEST_EMAIL;
    }

    return($rc);
}


#
# Send backup results to a list of printers.
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_print_results
{
    my ($subject, $message) = @_;

    my $rc = 1;

    if (! is_configured_print()) {
	return($rc);
    }

    my $timestamp = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime());

    my @template = (
	"=============================================================\r\n",
	"$subject\r\n",
	"Begin Printout:",
	"\r\n",
	"=============================================================\r\n",
	"\r\n",
	"\r\n",
	"\r\n",
	"\r\n",
	"\r\n",
	"$message",
	"\r\n",
	"\r\n",
	"\r\n",
	"\r\n",
	"\r\n",
	"=============================================================\r\n",
	"End Printout: $timestamp\r\n",
	"$subject\r\n",
	"=============================================================\r\n",
    );

    foreach my $printer (@PRINTERS) {

	next if ($printer eq $EMPTY_STR);

	my $print_cmd = "lp -d $printer";
	if (open(my $pipe, q{|-}, $print_cmd)) {
	    foreach (@template) {
		print {$pipe} "$_";
		if (/^Begin Printout:/) {
                    print {$pipe} " $timestamp on printer: $printer";
		}
	    }
	    close($pipe);
	}
	else {
	    $rc = 0;
	}
    }

    return($rc);
}


#
# make the dir at the given path if it does not
# already exist.
#
# Returns
#   1 on success
#   0 if error
#
sub tfr_util_mkdir
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
sub tfr_util_rmdir
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


sub tfr_util_rm_prefix
{
    my ($prefix, $path) = @_;

    my $result = $path;
    $result =~ s/$prefix//;

    return($result);
}


#
# form the cloud account name.  The cloud account name is:
#
#   project name . '-' . shopcode
#
# EG, tfrsync-01234567
#
# Returns
#   account name on success
#   empty string on failure
#
sub tfr_cloud_account_name
{
    my $cloud_account_name = $EMPTY_STR;

    my $shopcode = tfr_pos_get_shopcode();
    if ($shopcode) {
	$cloud_account_name = $DEF_PROJ_NAME . $DASH . $shopcode;
    }

    return($cloud_account_name);
}


#
# Given an account name, verify existence of account.
#
# Returns
#   1 if account exists
#   0 if account does NOT exist
#
sub tfr_accounts_exists
{
    my ($account_name) = @_;

    my $system_uid = getpwnam($account_name);
    return((defined($system_uid)) ? 1 : 0);
}


#
# Given an account name, return path to home directory.
#
# Returns
#   path to home dir if account exists
#   empty string if account does NOT exist
#
sub tfr_accounts_homedir
{
    my ($account_name) = @_;

    my $homedir_path = (getpwnam($account_name))[7];
    if (!defined($homedir_path)) {
	$homedir_path = $EMPTY_STR;
    }

    return($homedir_path);
}


#
# Given an account name, get the path to default ssh dir.
#
# Returns
#   path to default ssh dir on success
#   empty string on failure
#
sub tfr_sshdir_default_path
{
    my ($account_name) = @_;

    my $sshdir_path = $EMPTY_STR;

    if ($account_name) {
	if (tfr_accounts_verify_account($account_name)) {
	    my $homedir_path = tfr_accounts_homedir($account_name);
	    $sshdir_path = File::Spec->catdir($homedir_path, '.ssh');
	}
    }

    return($sshdir_path);
}


#
# Given an account name, make the default ssh dir if it does not
# already exist.
#
# Returns
#   path to ssh dir on success
#   empty string on error
#
sub tfr_accounts_make_default_sshdir
{
    my ($account_name) = @_;

    my $account_sshdir_path = tfr_sshdir_default_path($account_name);

    if (-d $account_sshdir_path) {
	loginfo("default ssh dir for account already exists: $account_name");
    }
    else {
	# make the dir and then verify that the dir exists
	system("mkdir $account_sshdir_path");
	if (-d $account_sshdir_path) {
	    # mkdir successful, set owners and perms
	    loginfo("mkdir of default ssh dir successful for account: $account_name");
	    my $account_homedir = dirname($account_sshdir_path);
	    system("chown --reference $account_homedir $account_sshdir_path");
	    system("chmod 0700 $account_sshdir_path");
	}
	else {
	    showerror("mkdir of default ssh dir failed for account; $account_name");
	    $account_sshdir_path = $EMPTY_STR;
	}
    }

    return($account_sshdir_path);
}


#
# Given an account name, verify it's existence.
#
# Returns
#   1 if account exists
#   0 if account does not exist
#   
sub tfr_accounts_verify_account
{
    my ($account_name) = @_;

    if (system("id -u $account_name > /dev/null 2>&1") == 0) {
	return(1);
    }

    return(0);
}


#
# Given an account name, add a system account with that name.
#
# BE AWARE: when adding an account, the "useradd" command can be
# netatively influenced by the contents of "/etc/login.defs" and
# "/etc/default/useradd".  For example, if "/etc/login.defs" has
# a low value for "PASS_MAX_DAYS", then this script will not work
# after the password expires even tho password-less ssh keys are
# being used for authentication.
#
# Returns
#   1 on success
#   0 on error
#   
sub tfr_accounts_add_account
{
    my ($account_name, $account_full_name) = @_;

    my $rc = 1;

    # if the account does not exist, try to add it, and verify
    if (tfr_accounts_verify_account($account_name) == 0) {
	my $cmd = "/usr/sbin/useradd";
	my $cmd_opts = "-c \"$account_full_name\"";
	system("$cmd $cmd_opts $account_name");
	if (tfr_accounts_verify_account($account_name) == 0) {
	    logerror("command failed: $cmd $cmd_opts $account_name");
	    $rc = 0;
	}
    }

    return($rc);
}


#
# Given an account name, remove it from the system.
#
# Returns
#   1 on success
#   0 on error
#   
sub tfr_accounts_rm_account
{
    my ($rsync_account_name) = @_;
    my $rc = 1;

    # if the account exists, remove it
    if (tfr_accounts_verify_account($rsync_account_name)) {
	my $cmd = "/usr/sbin/userdel";
	my $cmd_opts = "-r";
	system("$cmd $cmd_opts $rsync_account_name");
	if (tfr_accounts_verify_account($rsync_account_name)) {
	    showerror("error removing account: $rsync_account_name");
	    $rc = 0;
	}
    }
    else {
	loginfo("account does not exist: $rsync_account_name");
    }

    return($rc);
}


#####################################
####### SERVER INFO FILE SUBS #######
#####################################

#
# toplevel function for getting the contents of a
# server info file and writing it to the specified path.
#
# Returns
#   1 on success
#   0 if error
#
sub tfr_generate_pserver_info_file
{
    my ($pserver_info_file_path) = @_;

    my $rc = 0;

    my %server_info = ();
    if (tfr_prepare_pserver_info_file(\%server_info)) {
	if (tfr_write_pserver_info_file($pserver_info_file_path, \%server_info)) {
	    loginfo("[generate_pserver_info_file] server info file written: $pserver_info_file_path");

	    $rc = 1;
	}
	else {
	    showerror("[generate_pserver_info_file] could not write server info file: $pserver_info_file_path");
	}
    }
    else {
	showerror("[generate_pserver_info_file] could not prepare pserver info file: $pserver_info_file_path");
    }

    return($rc);
} 


#
# prepare info for the production server info file by
# putting it into the specified hash ref.
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_prepare_pserver_info_file
{
    my ($server_info_ref) = @_;

    my $rc = 0;

    my $ip_addr = get_ip_address();
    if ($ip_addr) {
	loginfo("ip addr of production server network device: $ip_addr");
	my $netmask = get_netmask();
	if ($netmask) {
	    loginfo("netmask of production server network device: $netmask");
	    my $gateway_ip_addr = get_gateway_ipaddr();
	    if ($gateway_ip_addr) {
		loginfo("ip addr of gateway: $gateway_ip_addr");
		my $hostname = hostname();

		$server_info_ref->{$SERVER_INFO_PLATFORM} = $OS;
		$server_info_ref->{$SERVER_INFO_HOSTNAME} = $hostname;
		$server_info_ref->{$SERVER_INFO_IPADDR} = $ip_addr;
		$server_info_ref->{$SERVER_INFO_NETMASK} = $netmask;
		$server_info_ref->{$SERVER_INFO_GATEWAY} = $gateway_ip_addr;

		$rc = 1;
	    }
	    else {
		showerror("error getting ip addr of gateway");
	    }
	}
	else {
	    logerror("error getting netmask for production server network device");
	}
    }
    else {
	logerror("error getting ip addr for production server network device");
    }

    return($rc);
}


#
# write server info to the file at the given path from
# the given hash reference.
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_write_pserver_info_file
{
    my ($pserver_info_file_path, $pserver_info_ref) = @_;

    my $rc = 0;

    if (open(my $fh, '>', $pserver_info_file_path)) {

	print {$fh} "$SERVER_INFO_PLATFORM=$pserver_info_ref->{$SERVER_INFO_PLATFORM}\n";
	print {$fh} "$SERVER_INFO_HOSTNAME=$pserver_info_ref->{$SERVER_INFO_HOSTNAME}\n";
	print {$fh} "$SERVER_INFO_IPADDR=$pserver_info_ref->{$SERVER_INFO_IPADDR}\n";
	print {$fh} "$SERVER_INFO_NETMASK=$pserver_info_ref->{$SERVER_INFO_NETMASK}\n";
	print {$fh} "$SERVER_INFO_GATEWAY=$pserver_info_ref->{$SERVER_INFO_GATEWAY}\n";

	close($fh);

	loginfo("[write_pserver_info_file] pserver info file generated: $pserver_info_file_path");

	$rc = 1;
    }
    else {
	showerror("[write_pserver_info_file] could not open pserver info file: $pserver_info_file_path");
    }

    return($rc);
}


#
# read pserver info file at the given path and
# fill given hash reference.
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_read_pserver_info_file
{
    my ($pserver_info_file_path, $pserver_info_ref) = @_;

    my $rc = 0;

    if (! -e $pserver_info_file_path) {
	logerror("[read_pserver_info_file] file does not exist: $pserver_info_file_path");
	return($rc);
    }

    if (open(my $fh, '<', $pserver_info_file_path)) {
	while (<$fh>) {
	    if (/^$SERVER_INFO_PLATFORM=(.+)$/) {
		$pserver_info_ref->{$SERVER_INFO_PLATFORM} = $1;
	    }
	    if (/^$SERVER_INFO_HOSTNAME=(.+)$/) {
		$pserver_info_ref->{$SERVER_INFO_HOSTNAME} = $1;
	    }
	    elsif (/^$SERVER_INFO_IPADDR=(.+)$/) {
		$pserver_info_ref->{$SERVER_INFO_IPADDR} = $1;
	    }
	    elsif (/^$SERVER_INFO_NETMASK=(.+)$/) {
		$pserver_info_ref->{$SERVER_INFO_NETMASK} = $1;
	    }
	    elsif (/^$SERVER_INFO_GATEWAY=(.+)$/) {
		$pserver_info_ref->{$SERVER_INFO_GATEWAY} = $1;
	    }
	}
	close($fh) || logerror("[read_pserver_info_file] close error: $pserver_info_file_path");
	$rc = 1;
    }
    else {
	logerror("[read_pserver_info_file] could not open pserver info file: $pserver_info_file_path");
    }

    return($rc);
}


#
# Given an account name, look for given public key in the
# account's authorized keys file in the default ssh dir.
# Default ssh dir and authorized keys file should exist but
# no error message if they don't.
#
# Returns
#   1 if key found
#   0 if key not found
#
sub tfr_keys_find_key_in_auth_keys
{
    my ($account_name, $key_path) = @_;

    my $auth_keys_path = tfr_pathto_ssh_auth_keys_file($account_name);
    if ($auth_keys_path) {

	# read the public key file
	if (open(my $kf, '<', $key_path)) {
	    my $public_key = <$kf>;
	    close($kf);
	    chomp($public_key);

	    # search for public key in authorized keys file
	    if (open(my $akf, '<', $auth_keys_path)) {
		while (my $line = <$akf>) {
		    chomp($line);
		    if ($public_key eq $line) {
			close($akf);
			return(1);
		    }
                }
		# if get here, did not find it
		close($akf);
            }
	}
    }

    return(0);
}


#
# Given an account name, add the given public key to the
# account's authorized keys file in the default ssh dir.
#
# Returns
#   1 on success
#   0 if error
#
sub tfr_keys_add_key_to_auth_keys
{
    my ($account_name, $key_path) = @_;

    my $rc = 1;

    # get the path to default ssh dir, make it if necessary
    my $sshdir_path = tfr_accounts_make_default_sshdir($account_name);
    if ($sshdir_path) {
	if (-e "$key_path") {
	    system("cd $sshdir_path; cat $key_path >> $SSH_AUTH_KEYS_FILENAME");
	    system("cd $sshdir_path; chmod 600 $SSH_AUTH_KEYS_FILENAME");
	    system("cd $sshdir_path; chown $account_name $SSH_AUTH_KEYS_FILENAME");
	    system("cd $sshdir_path; chgrp $account_name $SSH_AUTH_KEYS_FILENAME");
	    if (tfr_keys_find_key_in_auth_keys($account_name, $key_path)) {
		loginfo("key added to authorized keys file for account: $account_name");
	    }
	    else {
		showerror("error adding key to authorized keys file for account: $account_name");
		showerror("path to key: $key_path");
		$rc = 0;
	    }
	}
	else {
	    showerror("public key does not exist: $key_path");
	    $rc = 0;
	}
    }
    else {
	showerror("could not get path to default ssh dir for account: $account_name");
	$rc = 0;
    }

    return($rc);
}


#
# Given the path to an authorized keys file, remove
# the given public key from said authorized keys file.
#
# Returns
#   1 on success
#   0 if error
#
sub tfr_auth_keys_file_rm_key
{
    my ($auth_keys_path, $public_key_path) = @_;

    my $rc = 0;

    my $public_key = $EMPTY_STR;
    my $new_auth_keys_path = "${auth_keys_path}.$$";

    # read the public key file
    if (open(my $kf, '<', $public_key_path)) {
	$public_key = <$kf>;
	chomp($public_key);
	close($kf);
    }
    else {
	showerror("could not open public key file for reading: $auth_keys_path");
    }

    if ($public_key eq $EMPTY_STR) {
	showerror("public key file empty: $public_key_path");
    }
    else {
	# read the authorized keys file
	my @auth_keys = ();
	if (open(my $akf, '<', $auth_keys_path)) {
	    chomp(@auth_keys = <$akf>);
	    close($akf);
	}
	else {
	    showerror("could not open authorized keys file for reading: $auth_keys_path");
	}

	if (scalar(@auth_keys) == 0) {
	    showerror("authorized keys file empty: $auth_keys_path");
	}
	else {
	    # write the authorized keys without public key to new file
	    if (open(my $nakf, '>', $new_auth_keys_path)) {
		for my $auth_key (@auth_keys) {
		    if ($auth_key ne $public_key) {
			print {$nakf} "$auth_key\n";
		    }
		}
		close($nakf);
	    }
	    else {
		showerror("could not open new authorized keys file for writing: $new_auth_keys_path");
	    }
	}
    }

    # if successful, switch files
    if (-e $new_auth_keys_path) {
	if (-s $new_auth_keys_path) {
	    system("chmod --reference=$auth_keys_path $new_auth_keys_path");
	    system("chown --reference=$auth_keys_path $new_auth_keys_path");
	    system("mv $new_auth_keys_path $auth_keys_path");
	    loginfo("public key removed from: $auth_keys_path");
	    $rc = 1;
	}
	else {
	    showerror("new authorized keys file zero length: $new_auth_keys_path");
	    unlink($new_auth_keys_path);
	}
    }

    return($rc);
}


#
# Given an account name, generate a SSH RSA key pair.
# If the default SSH directory does not exist, make it.
# If there are old SSH keys, rename them with a timestamp.
# Generate passwordless keys, of type and bits specified by
# defines at top of program (currently RSA and 2048), and
# set the perms as appropriate.
#
# Returns
#   1 on success
#   0 on error
#   
sub tfr_keys_generate_ssh_keys
{
    my ($account_name) = @_;

    # get the path to default ssh dir, make it if necessary
    my $sshdir_path = tfr_accounts_make_default_sshdir($account_name);
    if ($sshdir_path eq $EMPTY_STR) {
	showerror("could not make default ssh dir for account: $account_name");
	return(0);
    }

    # form the path to the private and public keys
    my $keyfile_path = File::Spec->catdir($sshdir_path, $SSH_KEY_FILENAME);
    my $keyfile_path_pub = File::Spec->catdir($sshdir_path, $SSH_KEY_FILENAME_PUBLIC);

    # if old keys exist, rename them with timestamp
    if (-e $keyfile_path) {
	my $st = File::stat::stat($keyfile_path);
	my $timestamp = POSIX::strftime("%Y%m%d%H%M%S", localtime($st->mtime));
	my $keyfile_prev = $keyfile_path . "-$timestamp";
	my $keyfile_prev_pub = $keyfile_path_pub . "-$timestamp";
	system("rm -f $keyfile_prev $keyfile_prev_pub");
	system("mv $keyfile_path $keyfile_prev");
	system("mv $keyfile_path_pub $keyfile_prev_pub");
    }
    if (-e $keyfile_path) {
	showerror("could not rename old key file for account: $account_name");
	return(0);
    }

    # generate the key pair
    my $comment = $account_name . $ATSIGN . hostname;
    my $cmd = "/usr/bin/ssh-keygen";
    my $cmd_opts  = "-b $SSH_KEY_LEN";  # key length
    $cmd_opts .= " -t $SSH_KEY_TYPE";   # key type
    $cmd_opts .= " -N \"\"";            # no passphrase
    $cmd_opts .= " -f $keyfile_path";   # location of key file
    $cmd_opts .= " -C $comment";        # add comment
    loginfo("generate keys cmd: $cmd $cmd_opts");
    system("$cmd $cmd_opts >> $LOGFILE 2>> $LOGFILE");
    if (-e $keyfile_path) {
	loginfo("keys generated: $keyfile_path");
	my $homedir_path = (getpwnam $account_name)[7];
	system("chown --reference $homedir_path $keyfile_path");
	system("chmod 0600 $keyfile_path");
	system("chown --reference $homedir_path $keyfile_path_pub");
	system("chmod 0644 $keyfile_path_pub");
    }
    else {
	showerror("could not generate new keys for account: $account_name");
	return(0);
    }

    return(1);
}


#
# Given an account name and a destination path, copy the
# public key file located in the account's default ssh dir
# to the destination path.
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_keys_copy_public_key_file
{
    my ($account_name, $dst_path) = @_;

    my $rc = 0;

    my $key_path = tfr_pathto_ssh_public_key_file($account_name);
    if ($key_path) {
	# copy the key file
	system("cp $key_path $dst_path");
	if (-e $dst_path) {
	    loginfo("[keys_copy_public_key_file] public key file copied: $dst_path");
	    $rc = 1;
	}
	else {
	    showerror("[keys_copy_public_key_file] could not copy public key file ($key_path) to: $dst_path");
	}
    }
    else {
	showerror("[keys_copy_public_key_file] public key file does not exist for account: $account_name");
    }

    return($rc);
}


#
# Given an account name, remove the private key file, ie,
# the ssh identity file.
#
# Returns
#   1 on success
#   0 on error 
#
sub tfr_keys_rm_private_key
{
    my ($account_name) = @_;

    my $rc = 1;

    my $private_key_path = tfr_pathto_ssh_id_file($account_name);
    if (-e $private_key_path) {

	unlink($private_key_path);
	if (-e $private_key_path) {
	    showerror("can't remove private key: $private_key_path");
	    $rc = 0;
	}
	else {
	    loginfo("private key removed: $private_key_path");
	}
    }
    else {
	loginfo("private key file does not exist for account: $account_name");
    }

    return($rc);
}


#
# Given an account name, remove the public key file.
#
# Returns
#   1 on success
#   0 on error 
#
sub tfr_keys_rm_public_key
{
    my ($account_name) = @_;

    my $rc = 1;

    my $public_key_path = tfr_pathto_ssh_public_key_file($account_name);
    if (-e $public_key_path) {

	unlink($public_key_path);
	if (-e $public_key_path) {
	    showerror("can't remove public key for account: $account_name");
	    $rc = 0;
	}
	else {
	    loginfo("ssh public key removed: $public_key_path");
	}
    }
    else {
	loginfo("public key file does not exist for account: $account_name");
    }

    return($rc);
}


#
# Given an account name, get the public key for the corresponding account
# on the production server and put it in the authorized keys file in the
# given accounts default ssh dir.
#
# This sub is called during an installation of the backup server so the
# name of the account will be "tfrsync".
#
# When the private/public key pair for the "tfrsync" account was generated
# on the production server, the public key was put into the home dir of the
# support account in a special directory so it could be copied from the
# production server to the backup server knowing only the support accounts
# password.
#
# Returns
#   1 on success
#   0 on error 
#
sub tfr_keys_get_production_server_public_key
{
    my ($account_name, $production_server, $device_type) = @_;

    my $rc = 0;

    # form command to get the public key from the production server -
    # the production's "tfrsync" public key was put into the home dir
    # of the support account
    my $cmd = "/usr/bin/scp";
    my $tfsupport = tfr_tfsupport_account_name();
    my $src_host = $tfsupport . $ATSIGN . $production_server . $COLON;
    # fixme
    my $xferdir_keydir_path = tfrm_pathto_xferdir_keydir($device_type);
    my $src_arg = $src_host . File::Spec->catfile($xferdir_keydir_path, $SSH_KEY_FILENAME_PUBLIC);

    # get path to the xfer dir for specified account and then
    # copy the public key file from production server to backup server
    my $dst_dir = tfrm_pathto_pserver_xferdir();
    loginfo("cmd for getting production server public key: $cmd $src_arg $dst_dir");
    system("$cmd $src_arg $dst_dir");

    # was the copy successful?
    my $public_key_path = File::Spec->catfile($dst_dir, $SSH_KEY_FILENAME_PUBLIC);
    if (-e $public_key_path) {
	loginfo("production server public key copied to xfer dir: $public_key_path");

	# put the production server public key in authorized keys file
	if (tfr_keys_add_key_to_auth_keys($account_name, $public_key_path)) {
	    loginfo("production server public key added to authorized keys file for account: $account_name");
	    $rc = 1;
	}
	else {
	    showerror("error adding production server public key to authorized keys file for: $account_name");
	}
    }
    else {
	showerror("error copying production server ssh public key to: $public_key_path");
    }

    return($rc);
}


#
# Call the ostools script "harden_linux.pl" to generate a
# new /etc/sudoers file.
#
# Returns
#   1 on success
#   0 on error
#   
sub tfr_install_sudoers_generate
{
    my $cmd = "$ToolsDir/bin/harden_linux.pl";
    my $cmd_opts = "--sudo";

    loginfo("generating a new sudoers file: $cmd $cmd_opts");
    if (system("$cmd $cmd_opts >> $LOGFILE 2>> $LOGFILE") != 0) {
	logerror("harden_linux.pl returned non-zero exit status: $?");
	return(0);
    }

    return(1);
}


#
# Call the ostools script "harden_linux.pl" to convert the
# "append sudoers" directvies in the "harden_linux.pl"
# config file to use content files in the "sudoers.d"
# directory in the ostools "config" directory.  Why?
# This script must add content to the "/etc/sudoers" file
# and it's much easier to do that with content files rather
# then editing "append" directives in the "harden_linux.pl"
# config file.
#
# Returns
#   1 on success
#   0 on error
#   
sub tfr_install_sudoers_convert
{
    my $cmd = "$ToolsDir/bin/harden_linux.pl";
    my $cmd_opts = "--convert-configfile";

    loginfo("converting harden_linux.pl config file: $cmd $cmd_opts");
    if (system("$cmd $cmd_opts >> $LOGFILE 2>> $LOGFILE") != 0) {
	logerror("harden_linux.pl returned non-zero exit status: $?");
	return(0);
    }

    return(1);
}


#
# Add the tfrsync account to the "/etc/sudoers" file so that the
# tfrsync account can run the "rsync" command as root.
#
# Steps to add new entry to "sudoers" file via harden_linux.pl:
# 0) verify existence of harden_linux.pl sudoers config dir 
# 1) remove any old sudoers content files in the harden_linux sudoers config dir
# 2) generate new harden_linux.pl sudoers content file
# 3) generate new /etc/sudoers file by running the "harden_linux.pl --sudo" script
#
# Returns
#   1 on success
#   0 on error
#   
sub tfr_install_sudoers_add
{
    my (@sudoers_conf_lines) = @_;

    # verify existence of harden_linux.pl sudoers config dir
    my $sudoers_conf_dir = "$ToolsDir/config/sudoers.d";
    my $sudoers_conf_file = "tfrsync.conf";
    if (!(-d $sudoers_conf_dir)) {
	showerror("harden_linux.pl sudoers directory does not exist: $sudoers_conf_dir");
	return(0);
    }

    # remove the old harden_linux.pl sudoers content file
    my $sudoers_content_path = "$sudoers_conf_dir/$sudoers_conf_file";
    if (-e $sudoers_content_path) {
	if (unlink($sudoers_content_path)) {
	    loginfo("existing tfrsync sudoers content file removed: $sudoers_content_path");
	}
	else {
	    showerror("can't remove existing tfrsync sudoers content file: $sudoers_content_path");
	    return(0);
	}
    }

    # generate new harden_linux.pl sudoers content file
    if (open(my $cf, '>', $sudoers_content_path)) {
	foreach (@sudoers_conf_lines) {
	    print {$cf} "$_\n";
	}
	close($cf);
    }
    else {
	showerror("can't generate new tfrsync sudoers content file: $sudoers_content_path");
	return(0);
    }

    # generate new /etc/sudoers file
    if (tfr_install_sudoers_generate() == 0) {
	showerror("can't generate new /etc/sudoers file");
	return(0);
    }

    return(1);
}


#
# Remove the tfrsync "sudoers" content file in the "harden_linux.pl"
# configuration directory and generate a new sudoers file.
#
# Returns
#   1 on success
#   0 on error
#   
sub tfr_install_sudoers_rm
{
    my $rc = 1;

    if (-d $SUDOERS_CONFIG_DIR_PATH) {
	my $sudoers_content_path = $SUDOERS_CONTENT_FILE_PATH;
	if (-e $sudoers_content_path) {
	    unlink($sudoers_content_path);
	    if (-e $sudoers_content_path) {
		showerror("error removing tfrsync sudoers content file: $sudoers_content_path");
		$rc = 0;
	    }
	    else {
		loginfo("tfrsync sudoers content file removed: $sudoers_content_path");
	    }
	}
    }

    if (tfr_install_sudoers_generate() == 0) {
	showerror("can't generate new sudoers file");
	$rc = 0;
    }

    return($rc);
}


#
# Configure the "tfrsync" account to be able to run "rsync" via "sudo".
# Steps to accomplish:
# 1) convert harden_linux.pl to use sudoers content files
# 2) add new /etc/sudoers content
#
# Returns
#   1 on success
#   0 on error 
#
sub tfr_install_sudoers_config
{
    my ($rsync_account_name) = @_;

    if (tfr_install_sudoers_convert()) {
	loginfo("the harden_linux.pl config file converted");

	my @sudoers_conf_lines = (
	    "tfrsync     ALL=       NOPASSWD: /usr/bin/rsync",
	    "Defaults:tfrsync    !requiretty",
	);
	if (tfr_install_sudoers_add(@sudoers_conf_lines)) {
	    loginfo("content for account added to sudoers file: $rsync_account_name");
	}
	else {
	    showerror("can't add content for account to sudoers file: $rsync_account_name");
	    return(0);
	}
    }
    else {
	showerror("conversion of harden_linux.pl config file failed");
	return(0);
    }

    return(1);
}


sub tfr_cron_job_type
{
    my ($device_type) = @_;

    my $cron_job_type = $EMPTY_STR;

    if ($device_type eq $DEVTYPE_SERVER) {
	$cron_job_type = $CRON_JOB_TYPE_SERVER;
    }
    elsif ($device_type eq $DEVTYPE_CLOUD) {
	$cron_job_type = $CRON_JOB_TYPE_CLOUD; 
    }
    else {
	$cron_job_type = $CRON_JOB_TYPE_DEVICE;
    }

    return($cron_job_type);
}


sub tfr_cron_job_path
{
    my ($cron_job_type) = @_;

    my $cron_job_path = $EMPTY_STR;

    if ($cron_job_type eq $CRON_JOB_TYPE_SERVER) {
	$cron_job_path = $CRON_JOB_SERVER_PATH;
    }
    elsif ($cron_job_type eq $CRON_JOB_TYPE_CLOUD) {
	$cron_job_path = $CRON_JOB_CLOUD_PATH;
    }
    else {
	$cron_job_path = $CRON_JOB_DEVICE_PATH;
    }

    return($cron_job_path);
}


#
# Add a cron job.
#
#   run tfrsync.pl directly from ostools bin directory
#   default start: 3:30
#   command line: tfrsync.pl --backup=all
#
# Returns
#   1 on success
#   0 on error
#   
sub tfr_cron_job_add
{
    my ($cron_job_type) = @_;

    # If a cron job file already exists, don't overwrite it since
    # it might have site dependent contents.  Put the new version
    # into the ostools config directory.
    my $cron_job_path = tfr_cron_job_path($cron_job_type);
    if ($cron_job_path eq $EMPTY_STR) {
	showerror("can't determine cron job path for type: $cron_job_type");
	return(0);
    }

    if (-e $cron_job_path) {
	showerror("cron job file already exists: $cron_job_path");
	my $cron_job_file_name = basename($cron_job_path);
	$cron_job_path = "$TOOLS_CONFIG_DIR_PATH/$cron_job_file_name" . '-new';
	showinfo("cron job file will be written to: $cron_job_path");
    }

    # form the command for the cron job and it's options
    my $cmd = "$ToolsDir/bin/$PROGNAME";
    my $cmd_opts = $EMPTY_STR;
    if ($cron_job_type eq $CRON_JOB_TYPE_SERVER) {
	$cmd_opts = "--server --backup=all";
    }
    elsif ($cron_job_type eq $CRON_JOB_TYPE_CLOUD) {
	$cmd_opts = "--cloud --backup=all";
    }
    else {
	$cmd_opts = "--luks --backup=all";
    }

    # Make a new cron job file
    if (open(my $file, '>', $cron_job_path)) {

	print {$file} "#\n";
	print {$file} "# Generated by $PROGNAME $CVS_REVISION $TIMESTAMP\n";
	print {$file} "#\n";
	print {$file} "# Cron job file for backup of production server using backup method $cron_job_type.\n";
	print {$file} "#\n";
	print {$file} "30 3 * * * root (/usr/bin/test -e $cmd && $cmd $cmd_opts)\n";

	close($file);

	system("chown root:root $cron_job_path");
	system("chmod 644 $cron_job_path");
    }
    else {
	showerror("Can not make new cron job file: $cron_job_path");
	return(0);
    }

    return(1);
}


#
# Remove a cron job.
#
# Returns
#   1 on success
#   0 on error
#   
sub tfr_cron_job_rm
{
    my ($cron_job_type) = @_;

    my $cron_job_file = $EMPTY_STR;
    if ($cron_job_type eq $CRON_JOB_TYPE_SERVER) {
	$cron_job_file = $CRON_JOB_SERVER_PATH;
    }
    elsif ($cron_job_type eq $CRON_JOB_TYPE_CLOUD) {
	$cron_job_file = $CRON_JOB_CLOUD_PATH;
    }
    else {
	showerror("can't happen: unknown cron job type: $cron_job_type");
	return(0);
    }

    if (-e $cron_job_file) {
	unlink($cron_job_file);
	if (-e $cron_job_file) {
	    showerror("can't remove cron job file: $cron_job_file");
	    return(0);
	}
    }
    else {
	loginfo("cron job file does not exist, no need to remove: $cron_job_file");
    }

    return(1);
}


#
# remove old "rtibackup.pl" cron jobs.
#
# returns
#   1 on success
#   0 if error
#
sub tfr_cron_job_cleanup
{
    my ($cron_job_old) = @_;

    my $rc = 1;
    my $lt = '[cron_job_cleanup]';

    if (-e $cron_job_old) {
	system("rm -f $cron_job_old");
	if ($? == 0) {
	    loginfo("$lt old cron job removed: $cron_job_old");
	}
	else {
	    logerror("$lt could not remove old cron job: $cron_job_old");
	    $rc = 0;
	}
    }
    else {
	loginfo("$lt old cron job did not exist: $cron_job_old");
    }

    return($rc);
}


#
# generate the contents of the default config file.
#
# Returns
#   string with contents
#
sub tfr_generate_default_config_file
{
    my $config_text_header = $EMPTY_STR;

    $config_text_header  = "#\n";
    $config_text_header .= "# $PROGNAME Config File\n";
    $config_text_header .= "# Generated by $PROGNAME $CVS_REVISION $TIMESTAMP\n";
    $config_text_header .= "#\n";

    my $config_text = << 'END_CONFIG_TEXT';
#
# email=xxxxx
#
# When backups are complete, if the "email" attribute is given
# a value, than an email is sent to the recipient specified.
# To specify a list of more than one recipient,
# use multiple "email=" lines, one email address per line.
#
#email=user@somewhere.com
#email=user2@elsewhere.com

#
# emailserver=smtp.isp.com
#
# Instead of using the default system mail agent, to use
# a 3rd party mail facility like Gmail, or Yahoo, or
# a local ISP, use the "email_server", "email_username", and
# "email_password" attributes to define an account to use
# for sending email.
#
# NOTE that your password will be stored here in cleartext.
#
#email_server=smtp.google.com
#email_username=someone@gmail.com
#email_password=gmailpassword
#
# Use the sendmail program
#email_server=sendmail

#
# send-summary
#
# If set to true, send summary backup report if email configured
# Default: false.
#
#send-summary=true
#send-summary=false

#
# printer=xxxxx
#
# If printers are configured, the backup summary report
# will be output to all named printers.
# Also, if the backup class is "device" and there is no
# backup device discovered, and printers are configured,
# an error message will be output to all named printers.
# Multiple "printer=xxxxxxx" lines are allowed, in which case,
# results will be sent to multiple printers.
#
# "xxxxxx" represents the printer queue name, ie the
# "cups printer name".
#
#printer=printer11
#printer=order1

#
# exclude=/path/to/somewhere
# Exclude files or paths from the configured backups.
# Note that multiple "exclude=" lines are allowed, and results are passed
# directly into a tar "exclude" file (see tar man page.)
#
#exclude=/path/to/file
#backup-exclude=/path/to/file
#exclude=filename
#backup-exclude=filename

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
# which turns out to be your primary partition, you will wind up wiping out your
# primary partition.
#
# To create an image file, some examples are below. Make sure to --format the device
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

# If set to true, run in debug mode
# Default: false.
#
#debugmode=true
#debugmode=false

# If set to true, then look for a device on the USB bus that
# has a file system label of "TFBUDSK-yyyymmdd".
# Default: false
#
#usb-device=true
#usb-device=false

# If set to false, then do not run the "harden_linux.pl" script
# even if it normally would be run.
# Default: true
#
#harden-linux=true
#harden-linux=false

#
# Hint the backup script that this is an "rti" system.
# This is normally auto-detected.
# Default: none
#
#rti=true
#rti=false

#
# Hint the backup script that this is a "daisy" system.
# This is normally auto-detected.
# Default: none
#
#daisy=true
#daisy=false

# 
# If set to true, do a backup to the cloud server
# Default: false
#
#cloud=false

#
# Specify the ip addr or hostname of the cloud server
# Default: yourcloudserver.com
#
#cloud-server=yourcloudserver.com

#
# Specify the ip addr of backup server
# Default: empty string
#
#rsync-server=192.168.1.22

#
# Specify the path to the destination directory
# Default: empty string
#
#rsync-dir=/path/to/directory

#
# Specify addtional arbitrary rsync options... one or
# more of these statements may be specified.
# Default: empty string
#
#rsync-option=--temp-dir=/usr2
#rsync-option=--progress


END_CONFIG_TEXT

    $config_text .= "#\n";
    $config_text .= "# Specify a timeout (in seconds) for rsync command\n";
    $config_text .= "# Timeout must be >= 0, 0 means no timeout\n";
    $config_text .= "# Default: $DEF_RSYNC_TIMEOUT\n";
    $config_text .= "#\n";
    $config_text .= "#rsync-timeout=$DEF_RSYNC_TIMEOUT\n";
    $config_text .= "\n";

    $config_text .= "#\n";
    $config_text .= "# Specify that backup retries should be done.\n";
    $config_text .= "# Default policy: do " . (($DEF_RETRY_BACKUP) ? $EMPTY_STR : "not do ") . "retries\n";
    $config_text .= "#\n";
    $config_text .= "#retry-backup=" . (($DEF_RETRY_BACKUP) ? "true" : "false") . "\n";
    $config_text .= "\n";

    $config_text .= "#\n";
    $config_text .= "# If \"retry-backup=true\", specify number of retries.\n";
    $config_text .= "# Retries must be >= 0 and <= $MAX_RETRY_BACKUP_REPS\n";
    $config_text .= "# Default: $DEF_RETRY_BACKUP_REPS\n";
    $config_text .= "#\n";
    $config_text .= "#retry-reps=$DEF_RETRY_BACKUP_REPS\n";
    $config_text .= "\n";

    $config_text .= "#\n";
    $config_text .= "# If \"retry-backup=true\", specify seconds to wait between retries.\n";
    $config_text .= "# Wait must be >= 0 and <= $MAX_RETRY_BACKUP_WAIT\n";
    $config_text .= "# Default: $DEF_RETRY_BACKUP_WAIT\n";
    $config_text .= "#\n";
    $config_text .= "#retry-wait=$DEF_RETRY_BACKUP_WAIT\n";
    $config_text .= "\n";

    $config_text .= "#\n";
    $config_text .= "# Specify the network interface device name.\n";
    $config_text .= "# Default: $DEF_NETWORK_DEVICE\n";
    $config_text .= "#\n";
    $config_text .= "#network-device=$DEF_NETWORK_DEVICE\n";
    $config_text .= "\n";

    $config_text .= "#\n";
    $config_text .= "# Specify the maximum number of summary log files to save when rotating.\n";
    $config_text .= "# Default: $DEF_MAX_SAVE_SUMMARY_LOG\n";
    $config_text .= "#\n";
    $config_text .= "#summary-log-max-save=$DEF_MAX_SAVE_SUMMARY_LOG\n";
    $config_text .= "\n";

    $config_text .= "#\n";
    $config_text .= "# Specify the minimum number of summary log files to save when rotating.\n";
    $config_text .= "# Default: $DEF_MIN_SAVE_SUMMARY_LOG\n";
    $config_text .= "#\n";
    $config_text .= "#summary-log-min-save=$DEF_MIN_SAVE_SUMMARY_LOG\n";
    $config_text .= "\n";

    $config_text .= "#\n";
    $config_text .= "# Enable rotation of summary log files.\n";
    $config_text .= "# Default: " . (($DEF_ROTATE_SUMMARY_LOG) ? "true" : "false") . "\n";
    $config_text .= "#\n";
    $config_text .= "#summary-log-rotate=" . (($DEF_ROTATE_SUMMARY_LOG) ? "true" : "false") . "\n";
    $config_text .= "\n";

    my $config_contents = $config_text_header . $config_text; 

    return($config_contents);
}


#
# Install the default config file.
#
# If the default config file does not already exist, generate and
# write config file to the standard place.  If one already exists,
# write it to the standard place with an extension of ".new".
#
# Returns
#   name of config file on success
#   empty string on error
#
sub tfr_install_default_config_file
{
    my ($conf_file) = @_;

    #
    # If config file exists, write a new one with ".new" suffix and
    # leave the old one in place.
    #
    if (-f $conf_file) {
	$conf_file .= ".new"
    }

    if (open(my $cfh, '>', $conf_file)) {
	my $config_text = tfr_generate_default_config_file();
	print {$cfh} $config_text;
	close($cfh);

	my $owner = tfr_tfsupport_account_name();
	my $group = tfr_pos_admin_group_name();
	system ("chown $owner:$group $conf_file");
	system ("chmod 640 $conf_file");
    }
    else {
	showerror("could not write to new default config file: $conf_file");
	$conf_file = $EMPTY_STR;
    }

    return($conf_file);
}


#
# top level sub for "--install-primary" and "--install-cloud"
#
# Install the tfrsync.pl configuration on the primary server.
# The installation steps consist of:
# 0) make the top level backup dir
# 1) make the transfer dir
# 2) make the pserver info dir
# 3) make the pserver cloister dir
# 4) make the users info dir
# 5) add a tfrsync account
# 6) generate the ssh key pair
# 7) copy the public key file to the transfer dir
# 8) install a cron job file
# 9) install the default tfrsync config file
#
# Returns
#   $EXIT_OK on success
#   non-zero on error
#
sub tfr_install_production_server
{
    my ($account_name, $device_type) = @_;

    my $logtag = 'install_production_server';

    loginfo("[$logtag] production server installation: $PROGNAME ($CVS_REVISION)");

    # make the top level backup dir
    my $top_level_bu_dir = tfrm_pathto_project_bu_dir();
    if (tfr_util_mkdir($top_level_bu_dir)) {
	loginfo("[$logtag] mkdir of top level tfrsync backup dir successful: $top_level_bu_dir");
    }
    else {
	showerror("[$logtag] could not make top level tfrsync backup dir: $top_level_bu_dir");
	return($EXIT_TOP_LEVEL_MKDIR);
    }

    # make the transfer dir
    my $pserver_xferdir_path = tfrm_pathto_pserver_xferdir();
    if (tfr_util_mkdir($pserver_xferdir_path)) {
	loginfo("[$logtag] mkdir of production server transfer dir successful: $pserver_xferdir_path");
    }
    else {
	showerror("[$logtag] could not make production server transfer dir: $pserver_xferdir_path");
	return($EXIT_XFERDIR_MKDIR);
    }

    # make the pserver info dir
    my $pserver_infodir_path = tfrm_pathto_pserver_info_dir();
    if (tfr_util_mkdir($pserver_infodir_path)) {
	loginfo("[$logtag] mkdir of production server info dir successful: $pserver_infodir_path");
    }
    else {
	showerror("[$logtag] could not make production server info dir: $pserver_infodir_path");
	return($EXIT_INFODIR_MKDIR);
    }

    # make the pserver cloister dir
    my $pserver_cloister_dir_path = tfrm_pathto_pserver_cloister_dir();
    if (tfr_util_mkdir($pserver_cloister_dir_path)) {
	loginfo("[$logtag] mkdir of production server cloister dir successful: $pserver_cloister_dir_path");
    }
    else {
	showerror("[$logtag] could not make production server cloister dir: $pserver_cloister_dir_path");
	return($EXIT_INFODIR_MKDIR);
    }

    # make the users info dir
    my $users_infodir_path = tfrm_pathto_users_info_dir();
    if (tfr_util_mkdir($users_infodir_path)) {
	loginfo("[$logtag] mkdir of users info dir successful: $users_infodir_path");
    }
    else {
	showgerror("[$logtag] could not make users info dir: $users_infodir_path");
	return($EXIT_USERSDIR_MKDIR);
    }

    # add "tfrsync" account if necessary
    if (tfr_accounts_verify_account($account_name)) {
	loginfo("[$logtag] account already exists: $account_name");
    }
    else {
	if (tfr_accounts_add_account($account_name, $DEF_RSYNC_ACCOUNT_FULL_NAME)) {
	    loginfo("[$logtag] added account: $account_name");
	}
	else {
	    showerror("[$logtag] could not add account: $account_name");
	    return($EXIT_RSYNC_ACCOUNT);
	}
    }

    # generate the password-less ssh key pair
    if (tfr_keys_generate_ssh_keys($account_name)) {
	loginfo("[$logtag] ssh keypair generated for account: $account_name");
    }
    else {
	showerror("[$logtag] could not generate SSH keypair for account: $account_name");
	return($EXIT_SSH_GENERATE_KEYS);
    }

    #
    # copy the public key file that was just generated for the "tfrsync" account
    # to the production server transfer dir.
    #
    # The public key file for cloud backups and server backups are copied to
    # their own corresponding directory.  But first, make the directory if it does
    # not exist.
    #
    my $xferdir_keydir_path = tfrm_pathto_xferdir_keydir($device_type);
    if (tfr_util_mkdir($xferdir_keydir_path)) {
	if (tfr_keys_copy_public_key_file($account_name, $xferdir_keydir_path)) {
	    loginfo("[$logtag] public key for \"$account_name\" copied to: $xferdir_keydir_path");
	}
	else {
	    showerror("[$logtag] could not copy public key for \"$account_name\" to: $xferdir_keydir_path");
	    return($EXIT_SSH_COPY_PUBLIC_KEY);
	}
    }
    else {
	showerror("[$logtag] could not make public key dir: $xferdir_keydir_path");
	return($EXIT_SSH_COPY_PUBLIC_KEY);
    }

    # install a cron job file
    my $cron_job_type = tfr_cron_job_type($device_type);
    if (tfr_cron_job_add($cron_job_type)) {
	loginfo("[$logtag] new cron job type installed: $cron_job_type");
    }
    else {
	showerror("[$logtag] could not install cron job type: $cron_job_type");
	return($EXIT_CRON_JOB_FILE);
    }

    # install the default config file - careful - the name of the
    # default config file might have changed, ie it might have a
    # ".new" suffix on it.
    my $conf_file_path = tfrm_pathto_def_tfrsync_config_file();
    my $installed_conf_file_path = tfr_install_default_config_file($conf_file_path);
    if ($installed_conf_file_path) {
	loginfo("[$logtag] new default config file installed: $installed_conf_file_path");
    }
    else {
	showerror("[$logtag] could not install default config file: $conf_file_path");
	return($EXIT_DEF_CONFIG_FILE);
    }

    return($EXIT_OK);
}


#
# top level sub for "--uninstall-primary" and "--uninstall-cloud"
#
# Uninstall the tfrsync.pl configuration on the primary server.
# The un-installation steps consist of:
# 1) remove the cron job file
# 2) remove the xfer dir
# 3) delete the tfrsync account
#
# Returns
#   $EXIT_OK on success
#   non-zero exit status on error
#
sub tfr_uninstall_production_server
{
    my ($rsync_account_name, $device_type) = @_;

    loginfo("uninstalling $PROGNAME ($CVS_REVISION) on primary server");

    # remove the cron job file
    my $cron_job_type = tfr_cron_job_type($device_type);
    if (tfr_cron_job_rm($cron_job_type)) {
	loginfo("cron job type removed: $cron_job_type");
    }
    else {
	showerror("error removing cron job type: $cron_job_type");
	return($EXIT_CRON_JOB_FILE);
    }

    # remove the pserver xfer dir
    my $pserver_xferdir_path = tfrm_pathto_pserver_xferdir();
    if (tfr_util_rmdir($pserver_xferdir_path)) {
	loginfo("production server xfer dir removed");
    }
    else {
	showerror("error removing production server xfer dir");
	return($EXIT_XFERDIR_RMDIR);
    }

    # remove the "tfrsync" account
    if (tfr_accounts_rm_account($rsync_account_name)) {
	loginfo("account removed: $rsync_account_name");
    }
    else {
	showerror("error removing account: $rsync_account_name");
	return($EXIT_RSYNC_ACCOUNT);
    }

    return($EXIT_OK);
}


#
# top level sub for "--info-production-server" or "--info-cloud"
#
# Report info about the state of the tfrsync.pl installation
# on the production server.
#
# 0) does the tfrsync account exist?
# 1) does the ssh private key exist?
# 2) does the ssh public key exist?
# 3) has the public key file been copied to the xfer dir of
#    the Teleflora support account's home dir?
# 4) has the cron job been installed?
# 5) install the default tfrsync.pl config file
#
sub tfr_info_production_server
{
    my ($account_name, $device_type) = @_;

    my @info_recs = ();

    my $info_line = "production server transfer dir exists: ";
    my $pserver_xferdir_path = tfrm_pathto_pserver_xferdir();
    $info_line .= (-d $pserver_xferdir_path) ? "yes: $pserver_xferdir_path" : 'no';
    push(@info_recs, $info_line);

    $info_line = "tfrsync account exists: ";
    my $account_exists = tfr_accounts_exists($account_name);
    $info_line .= ($account_exists) ? 'yes' : 'no';
    push(@info_recs, $info_line);

    if ($account_exists) {
	$info_line = "tfrsync home dir exists: ";
	my $homedir_path = tfr_accounts_homedir($account_name);
	$info_line .= ($homedir_path ne $EMPTY_STR) ? "yes: $homedir_path" : 'no';
	push(@info_recs, $info_line);

	$info_line = "tfrsync SSH dir exists: ";
	my $ssh_dir_path = File::Spec->catfile($homedir_path, '.ssh');
	$info_line .= (-e $ssh_dir_path) ? "yes: $ssh_dir_path" : 'no';
	push(@info_recs, $info_line);

	$info_line = "tfrsync private key exists: ";
	my $private_key_path = tfr_pathto_ssh_id_file($account_name);
	$info_line .= (-e $private_key_path) ? "yes: $private_key_path" : 'no';
	push(@info_recs, $info_line);

	$info_line = "tfrsync public key exists: ";
	my $public_key_path = tfr_pathto_ssh_public_key_file($account_name);
	$info_line .= (-e $public_key_path) ? "yes: $public_key_path" : 'no';
	push(@info_recs, $info_line);

	if (-e $public_key_path) {
	    $info_line = "tfrsync public key copied to xfer dir: ";
	    my $xferdir_keydir = tfrm_pathto_xferdir_keydir($device_type);
	    my $xferdir_key_path = File::Spec->catfile($xferdir_keydir, $SSH_KEY_FILENAME_PUBLIC);
	    $info_line .= (-e $xferdir_key_path) ? "yes: $xferdir_key_path" : 'no';
	    push(@info_recs, $info_line);
	}
    }

    foreach my $cron_job_type (@CRON_JOB_TYPES) {
	my $cron_job_path = tfr_cron_job_path($cron_job_type);
	$info_line = "\"$cron_job_type\" cron job installed: ";
	if (-e $cron_job_path) {
	    $info_line .= "yes: $cron_job_path";
	}
	else {
	    $info_line .= "no";
	}
	push(@info_recs, $info_line);
    }

    $info_line = "tfrsync.pl config file exists: ";
    my $config_file_path = tfrm_pathto_config_file();
    $info_line .= (-e $config_file_path) ? "yes: $config_file_path" : 'no';
    push(@info_recs, $info_line);

    $info_line = "tfrsync backup dir exists: ";
    my $bu_dir = tfrm_pathto_project_bu_dir();
    $info_line .= (-d $bu_dir) ? "yes: $bu_dir" : 'no';
    push(@info_recs, $info_line);

    $info_line = "production server info dir exists: ";
    my $pserver_info_dir_path = tfrm_pathto_pserver_info_dir();
    $info_line .= (-d $pserver_info_dir_path) ? "yes: $pserver_info_dir_path" : 'no';
    push(@info_recs, $info_line);

    $info_line = "production server cloister dir exists: ";
    my $pserver_cloister_dir_path = tfrm_pathto_pserver_cloister_dir();
    $info_line .= (-d $pserver_cloister_dir_path) ? "yes: $pserver_cloister_dir_path" : 'no';
    push(@info_recs, $info_line);

    $info_line = "users info dir exists: ";
    my $users_info_dir = tfrm_pathto_users_info_dir();
    $info_line .= (-d $users_info_dir) ? "yes: $users_info_dir" : 'no';
    push(@info_recs, $info_line);

    my $longest_prefix = -1;
    foreach (@info_recs) {
	my $prefix_end = index($_, $COLON);
	if ($prefix_end > $longest_prefix) {
	    $longest_prefix = $prefix_end;
	}
    }

    foreach (@info_recs) {
	my $prefix_end = index($_, $COLON);
	my $leading_spaces = q{ } x ($longest_prefix - $prefix_end);
	my $formatted_line = $leading_spaces . $_;
	print "$formatted_line\n";
    }

    return($EXIT_OK);
}


#
# top level sub for "--install-backup-server"
#
# Install the tfrsync.pl configuration on the backup server.
# The installation steps consist of:
# 1) make the top level backup dir
# 2) make the transfer dir
# 3) add the tfrsync account
# 4) get the public key from the production server
# 5) add an entry to the sudoers file for tfrsync
# 6) service httpd stop and chkconfig httpd off if RTI
# 7) service rti stop and chkconfig rti off if RTI
# 8) move /usr2/bbx/bin/doveserver.pl to /usr2/bbx/bin/doveserver.pl.save if RTI
# 9) service blm stop and chkconfig blm off if RTI
# 10) service bbj stop and chkconfig bbj off if RTI
#
# Returns
#   0 on success
#   non-zero exit status on error
#
sub tfr_install_backup_server
{
    my ($rsync_account_name, $primary_server, $device_type) = @_;

    loginfo("installing $PROGNAME ($CVS_REVISION) on backup server");

    # make the top level backup dir
    my $top_level_bu_dir = tfrm_pathto_project_bu_dir();
    if (tfr_util_mkdir($top_level_bu_dir)) {
	loginfo("mkdir of top level tfrsync backup dir successful: $top_level_bu_dir");
    }
    else {
	showerror("could not make top level tfrsync backup dir: $top_level_bu_dir");
	return($EXIT_TOP_LEVEL_MKDIR);
    }

    # make the transfer dir
    my $pserver_xferdir_path = tfrm_pathto_pserver_xferdir();
    if (tfr_util_mkdir($pserver_xferdir_path)) {
	loginfo("mkdir of pserver transfer dir successful: $pserver_xferdir_path");
    }
    else {
	showerror("could not make pserver transfer dir: $pserver_xferdir_path");
	return($EXIT_XFERDIR_MKDIR);
    }

    # add "tfrsync" account if necessary
    if (tfr_accounts_verify_account($rsync_account_name)) {
	loginfo("account already exists: $rsync_account_name");
    }
    else {
	if (tfr_accounts_add_account($rsync_account_name, $DEF_RSYNC_ACCOUNT_FULL_NAME)) {
	    loginfo("account added: $rsync_account_name");

	    my $account_sshdir_path = tfr_accounts_make_default_sshdir($rsync_account_name);
	    if ($account_sshdir_path) {
		loginfo("default ssh dir made for account: $rsync_account_name");
	    }
	    else {
		showerror("could not make default ssh dir for account: $rsync_account_name");
		return($EXIT_RSYNC_ACCOUNT);
	    }
	}
	else {
	    showerror("error adding account: $rsync_account_name");
	    return($EXIT_RSYNC_ACCOUNT);
	}
    }

    # get the public key from the production server
    if (tfr_keys_get_production_server_public_key($rsync_account_name, $primary_server, $device_type)) {
	loginfo("primary public key obtained for account: $rsync_account_name");
    }
    else {
	showerror("error obtaining primary public key for account: $rsync_account_name");
	return($EXIT_SSH_GET_PUBLIC_KEY);
    }

    # add an entry to the sudoers file for the "tfrsync" account
    if (tfr_install_sudoers_config($rsync_account_name)) {
	loginfo("sudoers configuration updated for account: $rsync_account_name");
    }
    else {
	showerror("error configuring sudoers for account: $rsync_account_name");
	return($EXIT_SSH_SUDO_CONF);
    }

    my $pserver_cloister_dir_path = tfrm_pathto_pserver_cloister_dir();
    if (tfr_util_mkdir($pserver_cloister_dir_path)) {
	loginfo("mkdir successful: $pserver_cloister_dir_path");
    }
    else {
	showerror("mkdir unsuccessful: $pserver_cloister_dir_path");
	return($EXIT_CLOISTERDIR_MKDIR);
    }

    #
    # make sure that all the RTI processes and services are shutdown and
    # will not restart on reboot and prevent Dove from running.
    #
    if ($RTI) {
	if (is_service_configured("rti")) {
	    system("/sbin/service rti stop");
	    system("/sbin/chkconfig rti off");
	}
	if (is_service_configured("httpd")) {
	    system("/sbin/service httpd stop");
	    system("/sbin/chkconfig httpd off");
	}

	# deal with Dove server script
	if (-e $RTI_DOVE_CMD) {
	    system("cp -p $RTI_DOVE_CMD $pserver_cloister_dir_path");
	    system("rm -f $RTI_DOVE_CMD");
	}

	if (is_service_configured("blm")) {
	    system("/sbin/service blm stop");
	    system("/sbin/chkconfig blm off");
	}

	if (is_service_configured("bbj")) {
	    system("/sbin/service bbj stop");
	    system("/sbin/chkconfig bbj off");
	}
    }

    return($EXIT_OK);
}


#
# top level sub for "--uninstall-backup-server"
#
# Uninstall the tfrsync.pl configuration on the backup server.
# 1) remove the "tfrsync" account from the sudoers config
# 2) remove the public key for the "tfrsync" account
# 3) remove the "tfrsync" account 
#
# Returns
#   $EXIT_OK on success
#   non-zero exit status on error
#
sub tfr_uninstall_backup_server
{
    my ($rsync_account_name) = @_;

    loginfo("uninstalling $PROGNAME ($CVS_REVISION) from backup server");

    # remove the tfrsync account from the /etc/sudoers file
    if (tfr_install_sudoers_rm()) {
	loginfo("account removed from sudoers configuration: $rsync_account_name");
    }
    else {
	showerror("error removing account from sudoers configuration: $rsync_account_name");
	return($EXIT_SSH_SUDO_CONF);
    }

    # remove the tfrsync account - the public key removed as side effect
    if (tfr_accounts_rm_account($rsync_account_name)) {
	loginfo("account removed: $rsync_account_name");
    }
    else {
	showerror("error removing account: $rsync_account_name");
	return($EXIT_RSYNC_ACCOUNT);
    }

    # remove the pserver xfer dir
    my $pserver_xferdir_path = tfrm_pathto_pserver_xferdir();
    if (tfr_util_rmdir($pserver_xferdir_path)) {
	loginfo("production server xfer dir removed");
    }
    else {
	showerror("error removing production server xfer dir");
	return($EXIT_XFERDIR_RMDIR);
    }

    return($EXIT_OK);
}


#
# top level sub for "--info-backup-server"
#
# Report info about the state of the tfrsync.pl installation
# on the backup server.
#
# 1) does the tfrsync account exist?
# 2) is the public key from the primary server in the tfrsync account's
#    default ssh dir authorized keys file?
# 3) is there an entry in the sudoers file for the tfrsync account?
#
sub tfr_info_backup_server
{
    my ($rsync_account_name) = @_;

    my @info_recs = ();

    my $info_line = "tfrsync account exists: ";
    if (tfr_accounts_exists($rsync_account_name)) {
	my $homedir_path = tfr_accounts_homedir($rsync_account_name);
	$info_line .= "yes: $homedir_path";
    }
    else {
	$info_line .= "no";
    }
    push(@info_recs, $info_line);

    $info_line = "tfrsync public key obtained: ";
    my $xferdir_path = tfrm_pathto_pserver_xferdir();
    if ($xferdir_path) {
	my $public_key_path = File::Spec->catfile($xferdir_path, $SSH_KEY_FILENAME_PUBLIC);
	if (-e $public_key_path) {
	    if (tfr_keys_find_key_in_auth_keys($rsync_account_name, $public_key_path)) {
		my $auth_keys_path = tfr_pathto_ssh_auth_keys_file($rsync_account_name);
		$info_line .= "yes: $auth_keys_path";
	    }
	    else {
	    }
	}
    }
    if (index($info_line, "yes: ") == -1) {
	$info_line .= "no";
    }
    push(@info_recs, $info_line);

    $info_line = "tfrsync account given privledge: ";
    if (fgrep("/etc/sudoers", $rsync_account_name) == 0) {
	$info_line .= "yes: /etc/sudoers";
    }
    else {
	$info_line .= "no";
    }
    push(@info_recs, $info_line);

    $info_line = "tfrsync backup dir exists: ";
    my $rsync_bu_dir_path = tfrm_pathto_project_bu_dir();
    $info_line .= (-d $rsync_bu_dir_path) ? "yes: $rsync_bu_dir_path" : 'no';
    push(@info_recs, $info_line);

    $info_line = "production server info dir exists: ";
    my $pserver_info_dir_path = tfrm_pathto_pserver_info_dir();
    $info_line .= (-d $pserver_info_dir_path) ? "yes: $pserver_info_dir_path" : 'no';
    push(@info_recs, $info_line);

    $info_line = "production server cloister dir exists: ";
    my $pserver_cloister_dir_path = tfrm_pathto_pserver_cloister_dir();
    $info_line .= (-d $pserver_cloister_dir_path) ? "yes: $pserver_cloister_dir_path" : 'no';
    push(@info_recs, $info_line);

    $info_line = "users info dir exists: ";
    my $users_info_dir = tfrm_pathto_users_info_dir();
    $info_line .= (-d $users_info_dir) ? "yes: $users_info_dir" : 'no';
    push(@info_recs, $info_line);

    my $longest_prefix = -1;
    foreach (@info_recs) {
	my $prefix_end = index($_, $COLON);
	if ($prefix_end > $longest_prefix) {
	    $longest_prefix = $prefix_end;
	}
    }

    foreach (@info_recs) {
	my $prefix_end = index($_, $COLON);
	my $leading_spaces = q{ } x ($longest_prefix - $prefix_end);
	my $formatted_line = $leading_spaces . $_;
	print "$formatted_line\n";
    }

    return($EXIT_OK);
}


#
# Report info about the state of the tfrsync.pl installation
# on the cloud server.
#
# 1) what is the name of the tfrsync account?  and does it exist?
# 2) has the ssh key pair been generated?  and does the public key
#    in the tfrsync account .ssh dir match the one in tfsupport's $HOME?
# 3) what is the ip addr of the cloud server?
#
sub tfr_info_cloud
{
    my ($account_name, $device_type) = @_;

    my @info_recs = ();
    my $info_line = $EMPTY_STR;

    $info_line = "cloud file server ip addr: ";
    $info_line .= ($CLOUD_SERVER) ? "yes: $CLOUD_SERVER" : 'unknown';
    push(@info_recs, $info_line);

    $info_line = "tfrsync account exists: ";
    if (tfr_accounts_exists($account_name)) {
	my $homedir_path = tfr_accounts_homedir($account_name);
	$info_line .= "yes: $homedir_path";
	push(@info_recs, $info_line);

	$info_line = "tfrsync private key exists: ";
	my $private_key_path = tfr_pathto_ssh_id_file($account_name);
	if (-e $private_key_path) {
	    $info_line .= "yes: $private_key_path";
	    push(@info_recs, $info_line);
	}
	else {
	    $info_line .= "no";
	    push(@info_recs, $info_line);
	}

	$info_line = "tfrsync public key exists: ";
	my $public_key_path = tfr_pathto_ssh_public_key_file($account_name);
	if (-e $private_key_path) {
	    $info_line .= "yes: $public_key_path";
	    push(@info_recs, $info_line);

	    $info_line = "tfrsync public key copied to xfer dir: ";
	    my $xferdir_keydir = tfrm_pathto_xferdir_keydir($device_type);
	    my $xferdir_key_path = File::Spec->catfile($xferdir_keydir, $SSH_KEY_FILENAME_PUBLIC);
	    if (-e $xferdir_key_path) {
		$info_line .= "yes: $xferdir_key_path";
	    }
	    else {
		$info_line .= "no";
	    }
	    push(@info_recs, $info_line);
	}
	else {
	    $info_line .= "no";
	    push(@info_recs, $info_line);
	}
    }
    else {
	$info_line .= "no";
	push(@info_recs, $info_line);
    }

    foreach my $cron_job_type (@CRON_JOB_TYPES) {
	my $cron_job_path = tfr_cron_job_path($cron_job_type);
	$info_line = "\"$cron_job_type\" cron job installed: ";
	if (-e $cron_job_path) {
	    $info_line .= "yes: $cron_job_path";
	}
	else {
	    $info_line .= "no";
	}
	push(@info_recs, $info_line);
    }

    $info_line = "tfrsync.pl config file exists: ";
    my $config_file_path = tfrm_pathto_config_file();
    $info_line .= (-e $config_file_path) ? "yes: $config_file_path" : 'no';
    push(@info_recs, $info_line);

    $info_line = "tfrsync backup dir exists: ";
    my $bu_dir = tfrm_pathto_project_bu_dir();
    $info_line .= (-d $bu_dir) ? "yes: $bu_dir" : 'no';
    push(@info_recs, $info_line);

    $info_line = "production server info dir exists: ";
    my $pserver_info_dir_path = tfrm_pathto_pserver_info_dir();
    $info_line .= (-d $pserver_info_dir_path) ? "yes: $pserver_info_dir_path" : 'no';
    push(@info_recs, $info_line);

    $info_line = "production server cloister dir exists: ";
    my $pserver_cloister_dir_path = tfrm_pathto_pserver_cloister_dir();
    $info_line .= (-d $pserver_cloister_dir_path) ? "yes: $pserver_cloister_dir_path" : 'no';
    push(@info_recs, $info_line);

    $info_line = "users info dir exists: ";
    my $users_info_dir = tfrm_pathto_users_info_dir();
    $info_line .= (-d $users_info_dir) ? "yes: $users_info_dir" : 'no';
    push(@info_recs, $info_line);

    my $longest_prefix = -1;
    foreach (@info_recs) {
	my $prefix_end = index($_, $COLON);
	if ($prefix_end > $longest_prefix) {
	    $longest_prefix = $prefix_end;
	}
    }

    foreach (@info_recs) {
	my $prefix_end = index($_, $COLON);
	my $leading_spaces = q{ } x ($longest_prefix - $prefix_end);
	my $formatted_line = $leading_spaces . $_;
	print "$formatted_line\n";
    }

    return($EXIT_OK);
}


#
# CLI: --report-backup-method
#
# report which backup method is installed and enabled:
#   "cloud", "server", or "luks".
#
# returns
#   1 on success
#   0 if error
#


sub tfr_backup_method_report
{
    my ($bu_method, $account_name) = @_;

    my $rc = 1;
    my $lt = '[report_backup_method]';

    # tfrsync config file will exist
    my $conf_file_path = tfrm_pathto_def_tfrsync_config_file();
    if (-f $conf_file_path) {
	loginfo("$lt default tfrsync config file exists: $conf_file_path");
    }
    else {
	loginfo("$lt default tfrsync config file does not exist: $conf_file_path");
	$rc = 0;
    }

    if (tfr_backup_method_required_files($bu_method, $account_name)) {
	loginfo("$lt backup method $bu_method: all required files installed");
    }
    else {
	loginfo("$lt backup method $bu_method: required files not installed");
	$rc = 0;
    }

    if (tfr_backup_method_required_dirs($bu_method, $account_name)) {
	loginfo("$lt backup method $bu_method: all required dirs installed");
    }
    else {
	loginfo("$lt backup method $bu_method: required dirs not installed");
	$rc = 0;
    }

    my $cron_job_path = tfr_cron_job_path($bu_method);
    if (-e $cron_job_path) {
	loginfo("$lt backup method $bu_method enabled");
    }
    else {
	loginfo("$lt backup method $bu_method not enabled");
	$rc = 0;
    }

    return($rc);
}


sub tfr_backup_method_required_files
{
    my ($bu_method, $account_name) = @_;

    my $rc = 1;
    my $lt = '[backup_method_required_files]';

    my %required_files = (
	$DEVTYPE_CLOUD =>  [
			    &tfr_pathto_ssh_id_file($account_name),
			    &tfrm_pathto_xferdir_keydir_key($bu_method),
			   ],

	$DEVTYPE_SERVER => [
			    &tfr_pathto_ssh_id_file($account_name),
			    &tfrm_pathto_xferdir_keydir_key($bu_method),
			   ],

	$DEVTYPE_LUKS =>   [
			    $MOUNTPOINT,
			   ],
    );

    my @files = @{$required_files{$bu_method}};
    foreach my $file (@files) {
	if (-e $file) {
	    loginfo("$lt file exists: $file");
	}
	else {
	    loginfo("$lt file does not exist: $file");
	    $rc = 0;
	}
    }
    return($rc);
}


sub tfr_backup_method_required_dirs
{
    my ($bu_method, $account_name) = @_;

    my $rc = 1;
    my $lt = '[backup_method_required_dirs]';

    my %required_dirs = (
	$DEVTYPE_CLOUD =>  [
			    File::Spec->catfile('/home', $account_name),
			    &tfrm_pathto_project_bu_dir(),
			    &tfrm_pathto_pserver_xferdir(),
			    &tfrm_pathto_pserver_info_dir(),
			    &tfrm_pathto_pserver_cloister_dir(),
			    &tfrm_pathto_users_info_dir(),
			    &tfrm_pathto_xferdir_keydir($DEVTYPE_CLOUD)
			   ],

	$DEVTYPE_SERVER => [
			    File::Spec->catfile('/home', $account_name),
			    &tfrm_pathto_project_bu_dir(),
			    &tfrm_pathto_pserver_xferdir(),
			    &tfrm_pathto_pserver_info_dir(),
			    &tfrm_pathto_pserver_cloister_dir(),
			    &tfrm_pathto_users_info_dir(),
			    &tfrm_pathto_xferdir_keydir($DEVTYPE_SERVER),
			   ],

	$DEVTYPE_LUKS =>   [
			    &tfrm_pathto_project_bu_dir(),
			    &tfrm_pathto_pserver_xferdir(),
			    &tfrm_pathto_pserver_info_dir(),
			    &tfrm_pathto_pserver_cloister_dir(),
			    &tfrm_pathto_users_info_dir(),
			   ],
    );

    my @dirs = @{$required_dirs{$bu_method}};
    foreach my $dir (@dirs) {
	if (-d $dir) {
	    loginfo("$lt directory exists: $dir");
	}
	else {
	    loginfo("$lt directory does not exist: $dir");
	    $rc = 0;
	}
    }

    return($rc);
}


sub tfr_report_configfile_entry
{
    my ($configfile_entry) = @_;

    loginfo("config attribute parsed: $configfile_entry");
    if ($REPORT_CONFIGFILE) {
	print "config attribute parsed: $configfile_entry\n";
    }

    return(1);
}


sub tfr_parse_conf_file
{
    my ($line) = @_;

    chomp($line);

    # skip empty lines, lines with only white space, and comment lines
    if ( ($line eq $EMPTY_STR) ||
	 ($line =~ /^\s+$/)      ||
	 ($line =~ /^\s*#/) ) {
	return(1);
    }

    # printer=cups_prn_name
    # Multiple of these are allowed.
    if ($line =~ /^\s*printer\s*=\s*([[:print:]]+)$/i) {
	    push(@PRINTERS, $1);
	    tfr_report_configfile_entry("--printer=$1");
    }

    # email=someone@foo.com
    # Multiple of these are allowed.
    if ($line =~ /^\s*email\s*=\s*([[:print:]]+)$/i) {
	    push(@EMAIL_RECIPIENTS, $1);
	    tfr_report_configfile_entry("--email=$1");
    }

    # If we want to try sending emails via, say, gmail or yahoo.
    if ($line =~ /^\s*email_server\s*=\s*([[:print:]]+)$/i) {
	    $EMAIL_SERVER = $1;
	    tfr_report_configfile_entry("email_server =$1");
    }
    if ($line =~ /^\s*email_username\s*=\s*([[:print:]]+)$/i) {
	    $EMAIL_USER = $1;
	    tfr_report_configfile_entry("email_username=$1");
    }
    if ($line =~ /^\s*email_password\s*=\s*([[:print:]]+)$/i) {
	    $EMAIL_PASS = $1;
	    tfr_report_configfile_entry("email_password=*****");
    }

    # send summary report via email
    # send-summary=1
    # send-summary=true
    # send-summary=yes
    # only used by backup function
    if ($line =~ /^\s*send-summary\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		    $SEND_SUMMARY = 1;
		    tfr_report_configfile_entry("--send-summary");
	    }
    }

    # exclude=/path/to/directory
    # exclude=/path/to/file
    # Multiple of these are allowed.
    # Only used during backup.
    if ($line =~ /^\s*exclude\s*=\s*([[:print:]]+)$/i) {
	    push(@EXCLUDES, $1);
	    tfr_report_configfile_entry("exclude=$1");
    }
    if ($line =~ /^\s*backup-exclude\s*=\s*([[:print:]]+)$/i) {
	    push(@EXCLUDES, $1);
	    tfr_report_configfile_entry("backup-exclude=$1");
    }

    # restore-exclude=/path/to/directory
    # restore-exclude=/path/to/file
    # Multiple of these are allowed.
    # Only used during restore.
    # Note: if there were values specified on the command line via the
    # "--restore-exclude=" option, then the values specified in the
    # config file will be added to those specified on the command line.
    if ($line =~ /^\s*restore-exclude\s*=\s*([[:print:]]+)$/i) {
	    push(@RESTORE_EXCLUDES, $1);
	    tfr_report_configfile_entry("restore-exclude=$1");
    }

    # userfile=/path/to/directory
    # userfile=/path/to/file
    # Multiple of these are allowed.
    if ($line =~ /^\s*userfile\s*=\s*([[:print:]]+)$/i) {
	    push(@USERFILES, $1);
	    tfr_report_configfile_entry("userfile=$1");
    }

    # Which backup device to use.
    # device=/dev/whatever
    if ($line =~ /^\s*device\s*=\s*([[:print:]]+)$/i) {
	    $DEVICE = $1;
	    tfr_report_configfile_entry("--device=$DEVICE");
    }

    # Specify vendor for external backup device.
    # The default value is:
    # device-vendor=WD
    if ($line =~ /^\s*device-vendor\s*=\s*([[:print:]]+)$/i) {
	    $DEVICE_VENDOR = $1;
	    $DEVICE_VENDOR =~ s/"//g;
	    tfr_report_configfile_entry("--device-vendor=$DEVICE_VENDOR");
    }


    # Specify model for external backup device.
    # The default value is:
    # device-model=My Passport
    if ($line =~ /^\s*device-model\s*=\s*([[:print:]]+)$/i) {
	    $DEVICE_MODEL = $1;
	    $DEVICE_MODEL =~ s/"//g;
	    tfr_report_configfile_entry("--device-model=$DEVICE_MODEL");
    }

    # cloud backup
    # cloud=1
    # cloud=True / cloud=true
    # cloud=Yes / cloud=yes
    if ($line =~ /^\s*cloud\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		    $CLOUD = 1;
		    tfr_report_configfile_entry("--cloud");
	    }
    }

    # Specify cloud server
    # cloud-server=server.ip.address or hostname
    if ($line =~ /^\s*cloud-server\s*=\s*([[:print:]]+)$/i) {
	    $CLOUD_SERVER = $1;
	    tfr_report_configfile_entry("--cloud-server=$CLOUD_SERVER");
    }

    # Specify backup server
    # rsync-server=server.ip.address or hostname
    if ($line =~ /^\s*rsync-server\s*=\s*([[:print:]]+)$/i) {
	    $RsyncServer = $1;
	    tfr_report_configfile_entry("--rsync-server=$RsyncServer");
    }

    # Specify rsync directory
    # rsync-dir=path
    if ($line =~ /^\s*rsync-dir\s*=\s*([[:print:]]+)$/i) {
	    $RsyncDir = $1;
	    tfr_report_configfile_entry("--rsync-dir=$RsyncDir");
    }

    # Specify rsync option
    # rsync-option=string
    if ($line =~ /^\s*rsync-option\s*=\s*([[:print:]]+)$/i) {
	    push(@RSYNC_OPTIONS, $1);
	    tfr_report_configfile_entry("--rsync-option=$1");
    }

    # Specify rsync timeout
    # rsync-timeout=n
    if ($line =~ /^\s*rsync-timeout\s*=\s*(\d+)$/i) {
	    $RSYNC_TIMEOUT = $1;
	    tfr_report_configfile_entry("--rsync-timeout=$1");
    }

    # Specify backup retries should be done.
    # retry-backup=true
    if ($line =~ /^\s*retry-backup\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		    $RetryBackupCLO = 1;
		    tfr_report_configfile_entry("--retry-backup");
	    }
    }

    # Specify backup retry reps
    # retry-reps=n
    if ($line =~ /^\s*retry-reps\s*=\s*(\d+)$/i) {
	    $RetryBackupReps = $1;
	    tfr_report_configfile_entry("--retry-reps=$1");
    }

    # Specify backup retry wait
    # retry-wait=n
    if ($line =~ /^\s*retry-wait\s*=\s*(\d+)$/i) {
	    $RetryBackupWait = $1;
	    tfr_report_configfile_entry("--retry-wait=$1");
    }

    # specify maximum number of summary logfiles to save
    # summary-log-max-save
    if ($line =~ /^\s*summary-log-max-save\s*=\s*(\d+)$/i) {
	    $SummaryLogMaxSave = $1;
	    tfr_report_configfile_entry("--summary-log-max-save=$1");
    }

    # specify minimum number of summary logfiles to save
    # summary-log-min-save
    if ($line =~ /^\s*summary-log-min-save\s*=\s*(\d+)$/i) {
	    $SummaryLogMinSave = $1;
	    tfr_report_configfile_entry("--summary-log-min-save=$1");
    }

    # specify enable of summary log rotation
    # summary-log-rotation=1
    # summary-log-rotation=True
    # summary-log-rotation=Yes
    if ($line =~ /^\s*summary-log-rotation\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		$SummaryLogRotateEnabled = $1;
		tfr_report_configfile_entry("--summary-log-rotation");
	    }
    }


    # Specify network interface device name
    # network-device=string
    if ($line =~ /^\s*network-device\s*=\s*([[:print:]]+)$/i) {
	    $NetworkDeviceCLO = $1;
	    tfr_report_configfile_entry("--network-device=$NetworkDeviceCLO");
    }

    # Run in debug mode
    # debugmode=1
    # debugmode=True
    # debugmode=Yes
    if ($line =~ /^\s*debugmode\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		    $DEBUGMODE = 1;
		    tfr_report_configfile_entry("--debugmode");
	    }
    }

    # Use a USB device?
    # usb-device=1
    # usb-device=True / usb-device=true
    # usb-device=Yes / usb-device=yes
    if ($line =~ /^\s*usb-device\s*=\s*([[:print:]]+)$/i) {
	    if ($1 =~ /[YyTt1]/) {
		    $USB_DEVICE = 1;
		    tfr_report_configfile_entry("--usb-device");
	    }
    }

    # Run the harden_linux.pl script?
    # harden-linux=1
    # harden-linux=True / harden-linux=true
    # harden-linux=Yes / harden-linux=yes
    if ($line =~ /^\s*harden-linux\s*=\s*([[:print:]]+)$/i) {
	    my $config_entry = "--harden-linux";
	    if($1 =~ /[YyTt1]/) {
		$HARDEN_LINUX = 1;
	    }
	    else {
		$HARDEN_LINUX = 0;
		$config_entry = "--noharden-linux";
	    }
	    tfr_report_configfile_entry($config_entry);
    }

    # Is this an RTI system?
    # rti=1
    # rti=True / rti=true
    # rti=Yes / rti=yes
    if ($line =~ /^\s*rti\s*=\s*([[:print:]]+)$/i) {
	    if($1 =~ /[YyTt1]/) {
		    $RTI = 1;
		    tfr_report_configfile_entry("--rti");
	    }
    }

    # Is this a daisy system?
    # daisy=1
    # daisy=True / daisy=true
    # daisy=Yes / daisy=yes
    if ($line =~ /^\s*daisy\s*=\s*([[:print:]]+)$/i) {
	    if($1 =~ /[YyTt1]/) {
		    $DAISY = 1;
		    tfr_report_configfile_entry("--daisy");
	    }
    }

    # ignore anything else

    return(1);
}


sub tfr_read_conf_file
{
    my ($conf_file) = @_;

    my $rc = 1;

    if (-e $conf_file) {
	if (open(my $config, '<', $conf_file)) {
	    loginfo("[read_conf_file] config file opened for read: $conf_file");
	    while(my $line = <$config>) {
		if (! tfr_parse_conf_file($line)) {
		    logerror("[read_conf_file] unrecognized line in config file: $line");
		    $rc = 0;
		}
	    }
	    if ($DEBUGMODE) {
		loginfo("[read_conf_file] config file read completed: $conf_file");
	    }
	    close($config) || logerror("[read_conf_file] error closing config file: $conf_file");
	}
	else {
	    showerror("[read_conf_file] could not open config file: $conf_file");
	}
    }
    else {
	logerror("[read_conf_file] config file does not exist: $conf_file");
	$rc = 0;
    }

    return($rc);
}


#
# Read configuration.
#
# if specified config file is not the default config file
# then
#   read only from path specified
# else
#   read from default config file and
#   any config files in the config directory
#
# Returns
#   number of config files read successfully
#
sub tfr_read_configuration
{
    my ($config_file_path) = @_;

    my $conf_file_count = 0;
    my @conf_files = ();

    if ($config_file_path eq $EMPTY_STR) {
	logerror("Can't happen: config file path is the empty string");
	return($conf_file_count);
    }

    if (tfr_read_conf_file($config_file_path)) {
	$conf_file_count++;
    }
    else {
	logerror("error reading config file: $config_file_path");
    }

    my $def_pos_config_dir_path = tfrm_pathto_def_tfrsync_config_dir();
    my @dotdir_conf_files = glob("$def_pos_config_dir_path/*$DEF_CONFIG_FILE_EXT");

    foreach my $conf_file (@dotdir_conf_files) {
	if (tfr_read_conf_file($conf_file)) {
	    $conf_file_count++;
	}
	else {
	    logerror("error reading config file: $conf_file");
	    last;
	}
    }

    return($conf_file_count);
}


#
# setup all the log files and their location
#
# There is a log file for each of the destination classes:
#
#   cloud, server, and device
#
# For these log files, they are cummulative on a daily basis.
#
# The summary log file and the debug log file are cummulative.
#
# A directory to contain the log files may be specified
# on the command line.  If not, a default location is
# log directory of the POS, either RTI or Daisy.
#
sub tfr_log_setup
{
    my ($logfile_dir) = @_;

    my $rc = 1;

    # if the location of the log directory was specified
    # on the command line, verify it's usable,
    # otherwise choose the appropriate location
    if ($logfile_dir) {
	if (-d $logfile_dir) {
	    if (is_input_insecure($logfile_dir)) {
		print {*STDERR} "[log setup] specified directory for log files insecure: $logfile_dir\n";
		$LogfileDir = $DEF_ALT_LOGFILE_DIR;
	    }
	    else {
		$LogfileDir = $logfile_dir;
	    }
	}
	else {
	    print {*STDERR} "[log setup] specified location for log files not a directory: $logfile_dir\n";
	    $LogfileDir = $DEF_ALT_LOGFILE_DIR;
	}
    }
    elsif ($RTI) {
	$LogfileDir = $RTI_LOGDIR;
    }
    elsif ($DAISY) {
	$LogfileDir = $DAISY_LOGDIR;
    }
    else {
	$LogfileDir = $DEF_ALT_LOGFILE_DIR;
    }

    # now choose the logfile name
    if ($CLOUD) {
	$LogfileName = $DEF_LOGFILE_CLOUD;
    }
    elsif ($SERVER) {
	$LogfileName = $DEF_LOGFILE_SERVER;
    }
    elsif ($DEVICE) {
	$LogfileName = $DEF_LOGFILE_DEVICE;
    }
    elsif ($LUKS) {
	$LogfileName = $DEF_LOGFILE_DEVICE;
    }
    else {
	$LogfileName = $DEF_LOGFILE_DEVICE;
    }

    # get current value of time and use it to form each of the various
    # types of log file names.
    my @current_time = localtime(time);

    # form path for current log file
    $LogfileName = POSIX::strftime($LogfileName, @current_time);
    $LOGFILE = File::Spec->catfile($LogfileDir, $LogfileName);

    if (tfr_log_rotate($LOGFILE, @current_time)) {
	loginfo("[log setup] log file rotated: $LOGFILE");
    }

    # form path for summary log file
    $SummaryLogfile = File::Spec->catfile($LogfileDir, $DEF_SUMMARY_LOGFILE);

    if ($SummaryLogRotateEnabled) {
	loginfo("[log setup] summary log file rotation enabled");
	if (tfr_summary_log_rotate($SummaryLogfile, @current_time)) {
	    loginfo("[log setup] summary log file rotated if necessary: $SummaryLogfile");
	}
    }
    else {
	loginfo("[log setup] summary log file rotation disabled");
    }

    # form path for debug log file
    $DebugLogfile = File::Spec->catfile($LogfileDir, $DEF_DEBUG_LOGFILE);

    if ($VERBOSE) {
	print "logfile directory: $LogfileDir\n";
	print "  current logfile: $LOGFILE\n";
	print "  summary logfile: $SummaryLogfile\n";
	if ($DEBUGMODE) {
	    print "   debug logfile: $DebugLogfile\n";
	}
    }

    return($rc);
}


#
# conclude log file operations
#
# Returns
#   1 on success
#   0 on error
#
sub tfr_log_conclude
{
    my $rc = 1;

    my $owner = tfr_tfsupport_account_name();
    my $group = tfr_pos_group_name();

    my $logfile_path = tfrm_pathto_logfile();
    my $summary_log_path = tfrm_pathto_summary_logfile();
    my $debug_log_path = tfrm_pathto_debug_logfile();

    my @log_paths = ($logfile_path, $summary_log_path, $debug_log_path);

    for my $log_path (@log_paths) {
	if (-e $log_path) {
	    system("chown $owner:$group $log_path");
	    system("chmod ugo=rw $log_path");     # yes, perms wide open
	}
    }

    return($rc);
}


#
# if month number of current time > month number of the log file,
# rotate, ie re-init, log file.
#
# The "@current_time" arg is a list as returned by function localtime().
#
# Returns
#   1 if logfile rotated
#   0 if not
#
sub tfr_log_rotate
{
    my ($logfile_path, @current_time) = @_;

    my $rc = 0;

    my $current_mon = POSIX::strftime("%m", @current_time);

    if (-e $logfile_path) {
	my $st = File::stat::stat($logfile_path);
	my $logfile_mon = POSIX::strftime("%m", localtime($st->mtime));

	if ($current_mon > $logfile_mon) {
	    unlink($logfile_path);
	    system("touch $logfile_path");
	    system("chmod ugo=rw $logfile_path"); # yes, perms wide open
	    $rc = 1;
	}
    }

    return($rc);
}


sub tfr_summary_log_reap
{
    my ($log_dir) = @_;

    my $rc = 1;
    my $logtag = "[summary log reap]";

    #
    # the convention used in the log file name and glob does all
    # the work in terms of putting the list of log files in order
    # by date, oldest to newest.  Thus, we can just remove files
    # from the front of the list.
    #
    my @logfiles = glob("$log_dir/tfrsync-summary-*.log");
    my $log_count = scalar(@logfiles);
    my $reap_count = 0;
    while ( ($log_count > $SummaryLogMinSave) && ($log_count > $SummaryLogMaxSave) ) {
	if (unlink($logfiles[0])) {
	    loginfo("$logtag file unlinked: $logfiles[0]");
	}
	else {
	    logerror("$logtag could not unlink: $logfiles[0] ($!)");
	    $rc = 0;
	}
	splice(@logfiles, 0, 1);
	$log_count = scalar(@logfiles);
	$reap_count++;
    }

    if ($reap_count) {
	loginfo("$logtag reap count: $reap_count");
    }

    return($rc);
}


sub tfr_summary_log_maintenance
{
    my ($summary_log, $summary_log_begin) = @_;

    my $rc = 1;
    my $logtag = '[summary log maintenance]';

    # convert summary log time and current time to epoch time
    # so they can be compared.
    my ($log_year, $log_mon, $log_mday, $log_hour, $log_min, $log_sec) =
	($summary_log_begin =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/);
    my $log_epoch_time = timelocal($log_sec,$log_min,$log_hour,$log_mday,$log_mon-1,$log_year);
    my $current_epoch_time = timelocal(localtime());
    my $time_diff = $current_epoch_time - $log_epoch_time;
    if ($time_diff > $SECONDS_PER_YEAR) {

	# form new name and move old name to it
	my $log_date = $log_year . $log_mon . $log_mday;
	my ($log_name, $log_dir, $log_ext) = File::Basename::fileparse($summary_log);
	my $nu_log_name = $log_name . q{-} . $log_date . $log_ext;
	my $nu_log_path = File::Spec->catdir($log_dir,  $nu_log_name);
	system("mv $summary_log $nu_log_path");
	if (-f $nu_log_path) {
	    loginfo("$logtag summary log rotated to: $nu_log_path");
	    if (! tfr_summary_log_reap($log_dir)) {
		logerror("$logtag could not reap old summary log files: $log_dir");
		$rc = 0;
	    }
	}
	else {
	    logerror("$logtag could not rename summary log file: $summary_log");
	    $rc = 0;
	}
    }
    else {
	logerror("$logtag could not rotate summary log: $summary_log");
    }

    return($rc);
}


sub tfr_summary_log_rotate
{
    my ($summary_log, @current_time) = @_;

    my $rc = 0;
    my $logtag = "[summary log rotate]";

    # get date of first entry in summary log
    my $summary_log_begin = $EMPTY_STR;
    if (open(my $lfh, '<', $summary_log)) {
	while (my $line = <$lfh>) {
	    if ($line =~ /BEGIN:\s(\d+)-(\d+)/) {
		$summary_log_begin = $1 . $2;
		last;
	    }
	}
	close($lfh);
    }
    else {
	logerror("$logtag could not open summary log: $summary_log");
    }

    if ($summary_log_begin) {
	$rc = tfr_summary_log_maintenance($summary_log, $summary_log_begin);
    }

    return($rc);
}


sub log_file_lock
{
    my ($lfh) = @_;

    my $rc = 1;

    if ($DEBUGMODE) {
	loginfo("waiting up to these many seconds to obtain log file lock: $WAIT_FOR_LOG_FILE_LOCK");
    }
    my $fail_safe = 0;
    while ($fail_safe++ < $WAIT_FOR_LOG_FILE_LOCK) {
	if (flock($lfh, LOCK_EX|LOCK_NB)) {
	    if ($DEBUGMODE) {
		loginfo("obtained log file lock on iteration: $fail_safe");
	    }
	    seek($lfh, 0, SEEK_END);
	    last;
	}
	sleep(1);
    }
    if ($fail_safe >= $WAIT_FOR_LOG_FILE_LOCK) {
	$rc = 0;
    }

    return($rc);
}


sub log_file_unlock
{
    my ($lfh) = @_;

    my $rc = flock($lfh, LOCK_UN);

    return($rc);
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
    return if ($LOGFILE eq $EMPTY_STR);

    # First, make a temp logfile based on name of standard logfile
    my $logfile_basename = basename($LOGFILE, '.log');
    my $template = $logfile_basename . '-XXXXXXX';
    my ($fh, $tmp_logfile) = tempfile($template, SUFFIX => '.log', DIR => '/tmp');
    close($fh);
    loginfo("tempfile for changing log file location: $tmp_logfile");

    # save path to old logfile
    my $old_logfile_path = $LOGFILE;

    # switch to temp logfile after writing message to old logfile
    loginfo(q{#});
    loginfo("# Switching to temp logfile: $tmp_logfile");
    loginfo(q{#});
    $LOGFILE = $tmp_logfile;

    # write message to new temp logfile
    loginfo(q{#});
    loginfo('# Logfile location switched');
    loginfo(q{#});
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
    loginfo(q{#});
    loginfo("# Switching to original logfile: $orig_logfile_path");
    loginfo(q{#});
    $LOGFILE = $orig_logfile_path;

    # write status message to standard logfile
    loginfo(q{#});
    loginfo("# Logfile location switched");
    loginfo(q{#});
    loginfo("#\tCurrent logfile: $LOGFILE");
    loginfo("#\tTemporary logfile: $tmp_logfile");
    loginfo(q{#});

    # concatenate temp logfile to the standard log file
    loginfo(q{#});
    loginfo('# BEGIN including contents of temp logfile');
    loginfo(q{#});
    system("cat $tmp_logfile >> $LOGFILE");
    my $cat_status = $?;
    loginfo(q{#});
    loginfo('# END including contents of temp logfile');
    loginfo(q{#});

    if ($cat_status != 0) {
	# could not copy contents of temp logfile
	logerror('Concatenation of temp logfile to standard log file failed');
	loginfo("Contents of temp logfile preserved: $tmp_logfile");
	loginfo('Please remove when no longer needed');
    }
    else {
	# success, so rm previous logfile
	unlink "$tmp_logfile";
	loginfo("Temp logfile removed: $tmp_logfile");
    }

    return(1);
}


# Output to screen, and write info to logfile.
sub showinfo
{
    my ($message) = @_;

    print("$message\n");

    return(loginfo("<I>  $message"));
}


# Output to screen, and write error to logfile.
sub showerror
{
    my ($message) = @_;

    print("$message\n");

    return(loginfo("<E>  $message"));
}


# Write error to logfile and output to screen if verbose.
sub logerror
{
    my ($message) = @_;

    if($VERBOSE != 0) {
	print("$message\n");
    }

    return(loginfo("<E>  $message"));
}


# Write debug info to logfile and output to screen if verbose.
sub logdebug
{
    my ($message) = @_;

    if($VERBOSE != 0) {
	print("$message\n");
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
	close($log);

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
	close($log);
    }
    else {
	print "$timestamp $message\n";
    }

    return(1);
}


__END__

=pod

=head1 NAME

tfrsync.pl - synchronize production server files to a backup destination.

=head1 VERSION

This documenation refers to version: $Revision: 1.227 $


=head1 SYNOPSIS

tfrsync.pl --help

tfrsync.pl --version

tfrsync.pl --install-primary (--server | --cloud) [--rsync-account=name] [--network-device=s]

tfrsync.pl --uninstall-primary [--rsync-account=name]

tfrsync.pl --info-primary [--rsync-account=name]

tfrsync.pl --install-secondary [--primary-server=addr] [--rsync-account=name]

tfrsync.pl --uninstall-secondary [--rsync-account=name]

tfrsync.pl --info-secondary [--rsync-account=name]

tfrsync.pl --install-cloud [--cloud-server=addr] [---rsync-account=name]

tfrsync.pl --uninstall-cloud [--cloud-server=addr] [---rsync-account=name]

tfrsync.pl --generate-permfiles

tfrsync.pl --upload-permfiles [--cloud-server=addr] [--rsync-account=name]

tfrsync.pl --download-permfiles [--cloud-server=addr] [--rsync-account=name]

tfrsync.pl --restore-from-permfiles [--cloud-server=addr] [--rsync-account=name]

tfrsync.pl --backup=type [--luks] [--luks-key=s]

tfrsync.pl --backup=type --cloud [--cloud-server=addr] [--rsync-account=name]

tfrsync.pl --backup=type --server [--rsync-server=addr] [--rsync-account=name]

tfrsync.pl --restore=type --cloud [--cloud-server=addr] [--rsync-account=name]

tfrsync.pl --restore=type --server [--rsync-server=addr] [--rsync-account=name]

tfrsync.pl --list=type

tfrsync.pl --mount [--device=s]

tfrsync.pl --unmount [--device=s]

tfrsync.pl --luks-install [--luks] [--device=s]

tfrsync.pl --luks-init [--luks] [--device=s]

tfrsync.pl --luks-is-luks [--luks] [--device=s]

tfrsync.pl --luks-verify [--luks] [--device=s]

tfrsync.pl --luks-mount [--luks] [--device=s]

tfrsync.pl --luks-umount [--luks] [--device=s]

tfrsync.pl --luks-uuid [--luks] [--device=s]

tfrsync.pl --luks-label [--luks] [--device=s]

tfrsync.pl --luks-status [--luks] [--device=s]

tfrsync.pl --luks-getinfo [--luks] [--device=s]

tfrsync.pl --luks-showkey [--luks] [--device=s]

tfrsync.pl --luks-validate-key [--luks-key=s] [--luks] [--device=s]

tfrsync.pl --luks-backup-date [--luks] [--device=s]

tfrsync.pl --luks-file-verify=s [--luks] [--luks-dir=s] [--device=s]

tfrsync.pl --luks-file-restore=s [--luks] [--luks-dir=s] [--rootdir=s] [--device=s]

tfrsync.pl --report-configfile

tfrsync.pl --report-logfile

tfrsync.pl --report-device

tfrsync.pl --report-backup-method

tfrsync.pl --gen-default-configfile

tfrsync.pl --finddev

tfrsync.pl --showkey

tfrsync.pl --validate-cryptkey

tfrsync.pl --format [--force-format]

tfrsync.pl --runtime-cleanup ( --cloud | --server )

tfrsync.pl --send-test-email

=head1 OPTIONS

There are two types of options.
The first is essentially a command since without this type of option,
the script will do nothing.
The second type is a modifier to a command option;
it tailors the behavior of the command.


=head2 Commands

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a usage help message and exit.

=item B<--install|install-primary>

Install the I<tfrsync.pl> script on the production server and
perform other steps to prep the production server.

=item B<--uninstall-primary>

Undo what was done to install I<tfrsync.pl> on the production server.

=item B<--info-primary>

Report configuration of production server.

=item B<--install-secondary>

Prepare the secondary server.

=item B<--uninstall-secondary>

Undo what was done to install I<tfrsync.pl> on the secondary server.

=item B<--info-secondary>

Report configuration of backup server.

=item B<--generate-permfiles>

Generate perm files for all backup types.
For all the files that make up a backup type,
the F<getfacl(1)> command is used to capture the file perms of
the files that make up the backup type.
It writes the captured info into a perm file corresponding to the backup type.
If an error occurs while iterating through the list of files for
any backup type, the error is logged but the generation will continue.
Thus, if there are any errors reported, the contents of the perm file
may not be complete.
An example of an error that may occur is one caused when there are
stale symlinks in the set of files of a backup type.

=item B<--backup=type>

Perform a backup of the specified I<type>.
The I<type> may be one or more of the following:

	all
	usr2
	daisy
	printconfigs
	rticonfigs
	daisyconfigs
	osconfigs
	netconfigs
	userconfigs
	userfiles
	logfiles
	posusersinfo
	pserverinfo
	pservercloister
	bbxd
	bbxps
	singlefile

Modifiers: B<--device=s>, B<--usb-device>, B<--backup-exclude=list>,
B<--rsync-server=addr>, B<--rsync-dir=path>,
B<--retry-backup>, B<--retry-reps=number>, B<--retry-wait=seconds>,
B<--singlefile=path>, and B<--send-summary>

=item B<--restore=type>

Restore files of specified C<type> from a backup.
The I<type> may be one or more of the following:

	all
	usr2
	daisy
	printconfigs
	rticonfigs
	daisyconfigs
	osconfigs
	netconfigs
	userconfigs
	userfiles
	logfiles
	bbxd
	bbxps
	singlefile

Modifiers: B<--device=s>, B<--usb-device>, B<--restore-exclude=list>,
B<--rootdir=s>, B<--[no]harden-linux>, B<--singlefile=path> and
B<--dry-run>

=item B<--list=type>

List the files on a backup server or device for the specified backup type
(see B<--backup=type> option.
If no backup type is specfied, the default is I<all>.
This option may not be used with the B<--cloud> option.

Modifiers: B<--device=s>, B<--usb-device>, B<--rsync-server=addr>, B<--rsync-dir=path>

=item B<--finddev | --report-device>

Search for a USB or Passport backup disk device.

=item B<--report-backup-method>

Report what type of backup is installed, ie, "cloud", "server", or "LUKS".

=item B<--showkey>

Output the string being used as the LUKS key.

=item B<--format>

Format a backup device.

=item B<--getinfo>

Get and report info about the backups on a backup device.

=item B<--mount>

Mount a backup device.

=item B<--unmount|--umount>

Unmount a backup device.

=item B<--runtime-cleanup>

If the script crashed rather than ending with a clean exit,
there possibly will be a process lock file and/or
a SSH tunnel socket left behind.
This command can be used to cleanup those dangling files.
For cloud, server, or device backup operations,
the process lock file will be removed.
For server or cloud, the SSH tunnel socket will be removed.

=item B<--send-test-email>

Send an email message via the email configuration to test
whether an email message would make it through to any
configured recepients.

=item B<--report-configfile>

Parse the config file, and report it's contents.

=item B<--report-backup-method>

Information about how the decision of what backup method
was installed will be in the device log file.

=item B<--gen-default-configfile>

Generate a new default config file and
put it into the OSTools config directory.
If there is already an existing config file,
do not overwrite the old config file -
rather, add the extension F<.new> before installation.

=item B<--luks-install>

Like B<--production-install>, sets up a production server to be ready
to perform backups to a LUKS device.
Modifiers allowed:  B<[--luks]>, B<[--device=s]>.

=item B<--luks-init>

Writes the LUKS header to the backup disk and
puts an ext2 file system on the LUKS device.

=item B<--luks-is-luks>

Verify the current backup disk is a LUKS device.
This command uses the C<cryptsetup isLuks> command.

=item B<--luks-verify>

Verify the current backup disk is a LUKS device.
This command uses the C<cryptsetup luksDump> command.

=item B<--luks-mount>

Mount a LUKS disk device.

=item B<--luks-umount>

Unmount (aka eject) a LUKS device.

=item B<--luks-uuid>

Output the UUID of the LUKS device.

=item B<--luks-label>

Output the disk label of a LUKS device.

=item B<--luks-status>

Output low level system inforation about the LUKS device.

=item B<--luks-getinfo>

For the currently selected backup disk,
output the backup type, the block device name of the LUKS device,
the LUKS device name, the mount point for file system on the
LUKS device, and the free space on the LUKS device.

=item B<--luks-showkey>

Output the encryption key for the LUKS disk device.

=item B<--luks-validate-key>

Validate the default or specified LUKS disk device encryption key
by trying to mount the LUKS disk device.

=back


=head2 Command Modifiers

=over 4

=item B<--luks>

This option specifies a backup type of "LUKS disk device".
While it may be ommitted since the script can deduce what
should be done from other options, specifying this option
makes explicit what is desired and makes communication clearer.

=item B<--luks-key=s>

Specify the LUKS key.
If this option is not specified the hardware serial number is used.
Note, if the LUKS device is moved to another system, the LUKS key
must be noted and used in order to access the files on the LUKS device.

=item B<--luks-dir=s>

This command line option allows the user to specify which "bucket"
on the LUKS disk device is to be used for listing, searching, and
restoring.

=item B<--server>

Specify this option when performing a backup from
a production server to a backup server.
Sets the default values of B<--rsync-server=s> and
B<--rsync-account=s> if not set.

=item B<--cloud>

Specify this option when performing a backup from
a production server to a cloud server.
Sets the default values of B<--cloud-server=s> and B<--rsync-account=s>.

=item B<--cloud-server=addr>

Specify the FQDN or IP address of the cloud server.

=item B<--primary-server=addr>

Sets the hostname or IP address of the production server.
May only be used with B<--install-secondary>.

=item B<--rsync-server=addr>

Specify the hostname or IP address of the rsync backup server.

=item B<--rsync-dir=path>

Specify the directory to write files to on the rsync server if
B<--rsync-server> is specified or
to a local file system if B<--rsync-server> is not specified.

=item B<--rsync-account=s>

Sets the name of the account on the rsync server.
May be used with B<--install-primary>, B<--uninstall-primary>,
B<--info-primary>, B<--install-secondary>, B<--uninstall-secondary>,
B<--info-secondary>, B<--install-cloud>, B<--uninstall-cloud>,
B<--upload-permfiles>, B<--download-permfiles>,
B<--restore-from-permfiles>, B<--backup=type>, and B<--restore=type>.

=item B<--force-rsync-account-name>

If the B<--cloud> option is specified, the default account name
used is of the form "name-nnnnnnnn" where "name" is "tfrsync" and
"nnnnnnnn" is the shopcode of the system.
If a cloud account name is specified on the command line that does
not contain the shopcode matching the system, then the account name
is not allowed unless B<--force-rsync-account-name> is also specified
on the command line.

=item B<--rsync-trial>

Run the I<rsync> command in trial mode
(accomplished by adding the B<-n> option to the I<rsync> command
that gets generated).
This provides a method to determine what files will be synchronized
without actually synchronizing them.

=item B<--rsync-options=s>

Specify a list of one or more comma separated I<rsync> options to be
added to the I<rsync> command line.

=item B<--rsync-timeout=s>

All I<rsync> commands generated have the B<--timeout=s> option
with a default value of 600 seconds.
Specify this option to change that value.
A value of zero means no timeout.

=item B<--[no]rsync-nice>

Run the C<rsync> command with C<nice>; this is the default behavior.
Specify I<--norsync-nice> on the command line to run the C<rsync>
command without C<nice>.

=item B<--[no]rsync-metadata>

The default behavior when doing a backup to the "cloud" is to
generated metadata files for each of the backup types.
To keep from generating metadata files,
specify the "--norsync-metatdata" option on the command line.

=item B<--rsync-compression>

By default, there is no compression of files during the transfer
by rsync, ie the B<-z> option is not present on the F<rsync> command.
If the B<--rsync-compression> option is specified with the
B<--backup=type> option, then the B<-z> option will be added
to the F<rsync> command issued.
Note that adding this option can increase the time required
to perform a backup when backing up very large files.

=item B<--retry-backup>

If present, enables the backup retry policy.
Note that retries are only applicable for instances
when F<rsync(1)> returns a value of 12 (rsync protocol),  30 (I/O error) or
255 (SSH connection error).

=item B<--retry-reps=number>

If present, sets the number of retries to "number".
This option is ignored unless B<--retry-backup> is also specified.
The value specified must be >= 0 and <= 10.
If B<--retry-backup> is specified and
B<--retry-reps=number> is not specified or
if B<--retry-reps=0> is specified,
then the default value of 3 retries is used.

=item B<--retry-wait=number>

If present, sets the retry wait time to "number" seconds.
This option is ignored unless B<--retry-backup> is also specified.
The value specified must be >= 0 and <= 3600.
If B<--retry-backup> is specified and
B<--retry-wait=number> is not specified or
if B<--retry-wait=0> is specified,
then the default value of 120 seconds is used.

=item B<--force-format>

Unless specified with the B<--format> option, the user is
asked a "yes/no" question on STDIN to verify that a format
of the file system is really desired.
If <--force-format> is specified, it's equivalent to "yes"
being answered.

=item B<--singlefile=path>

Provides the method to specify one or more files to backup or restore.
The files are specified by a list of one or more comma separated paths.
This option may only be used in conjunction with the
B<--backup=type> or B<--restore=type> commands.

=item B<--restore-upgrade>

An option that may only be used when both B<--cloud> and
B<--restore=type> are specified, ie that a restore is being
done from a cloud server to a staged production server.
The set of backup files being restored may or may not be
from the same platform as the staged server, ie the backup files
may be from a RHEL5 system and the staged server may be a RHEL6 system.

=item B<--network-device=s>

This option allows the specification of a network interface device name,
eg "eth0" or "eth1", and
is only used to produce the contents of the
production server info file when performing a backup.
The default value is "eth0" so if you are using that interface
for your network tap, there is no need to specify this option.

=item B<--send-summary>

A summary report is sent to a list of one or more email addresses
if email is configured.

=item B<--rti>

Specify that the system is a RTI system.

=item B<--daisy>

Specify that the system is a Daisy system.

=item B<--email=recipients>

Specifies a list of email addresses.

=item B<--printer=names>

Specifies a comma separated list of printer names.
If printers are configured, the backup summary report
will be output to all named printers.
Also, if the backup class is "device" and there is no
backup device discovered, and printers are configured,
an error message will be output to all named printers.

=item B<--rootdir=path>

Specifies the destination directory for restore.

=item B<--configfile=path>

Specifies the path to the config file.

=item B<--logfile=path>

Specifies the path to the logfile.

=item B<--summary-log-max-save=n>

Specifies the maximum number of saved summary log files.

=item B<--summary-log-min-save=n>

Specifies the minimum number of saved summary log files.

=item B<--summary-log-rotate>

Enable summary log file rotation (by default, disabled).

=item B<--backup-exclude=list>

Specifies a list of one or more comma separated files and/or directories
to exclude from a backup.

=item B<--restore-exclude=list>

Specifies a list of one ore more comma separated files and/or directories
to exclude from a restore.

=item B<--device=path>

Specifies the path to the device special file for the backup device.
It can also have the special value of I<show-only> whose
meaning is described under the B<--show-only> option description.

Each backup device is classified as to type.
There are several different device types supported:

 1. "passport"    - a Western Digital Passport USB disk
 2. "rev"         - an IOmega Rev drive
 3. "usb"         - a USB disk with Teleflora label
 4. "image"       - an image file
 5. "server"      - ip address of backup server
 6. "file system" - locally mounted file system
 7. "block"       - either "passport", "rev", or "usb"
 8. "show-only"   - special device, same thing as "--show-only"

=item B<--usb-device>

Use a disk plugged into the USB bus which has been
formatted with B<--format> as the backup device.

=item B<--dry-run>

Report what an operation would do but don't actually do it.

=item B<--show-only>

Change the behavior of B<--backup> to only show the filenames
of the backup type not actually back up any files.
Another way to think about this option is that it is an alias
for B<--device=show-only>, ie you are specifying a
special device named I<show-only> which does not backup
any data but rather reports the filenames to be backed up.

=item B<--verbose>

Report extra information.

=item B<--[no]harden-linux>

Run (or don't run) the I<harden_linux.pl> script.
The B<--harden-linux|--noharden-linux> command line option provides
a way to specify whether or not the I<harden_linux.pl> script
should be run by the I<tfrsync.pl> script.
The default behavior for I<tfrsync.pl> is to run I<harden_linux.pl>
after performing any of the following restore types:
"all", "rticonfigs", "daisy", "daisyconfigs", "osconfigs" and "netconfigs".
The I<harden_linux.pl> script will only be run once after all restores are finished.
To prevent I<harden_linux.pl> from running, specify the following option:
B<--noharden-linux>.

=back


=head1 DESCRIPTION

The I<tfrsync.pl> script may be used to synchronize data
from a Teleflora RTI or Daisy Point of Sale server,
referred to below as the "production server", to a cloud server,
a backup server, a backup device, or a local file system.
It is essentially a front end to the I<rsync(1)> command which
does the real work of reading and writing the data.
For maximum versatility, there are many options and
many ways that the script can be used.

Since the backup strategy is one based on I<rsync(1)>,
implied is that the first backup performed copies all files of interest
from the production server to the backup destination and
could take a significant amount of time depending
on the characteristics of the destination.
For example, if there is a 25 GB of data to backup,
if the distination is a cloud server, and
if the upload bandwidth to the cloud server is typical,
it should take 10 hours or less.
Subsequent backups are incremental and only the files that have changed
are copied to the backup destination.
This results in a significant savings in time,
with a typical installation taking 30 minutes and usually less.


=head2 Installation

Before I<tfrsync.pl> can be used on either the production server or
the backup server, it must be installed.
The I<tfrsync.pl> script itself will have been installed when
the OSTools package was installed.
However, the I<tfrsync.pl> must install a framework of directories and
files in order to accomplish it's job.
This installation must be performed on both the production server and
the backup server separately.
The sections which follow outline what is done during production and
backup server installations.


=head2 Installation on the Production Server

The B<--install-primary> command line option performs all the steps
necessary to install the I<tfrsync.pl> script onto a RTI production server,
aka a production server.

The OSTools installation process will already have copied the
I<tfrsync.pl> script to the OSTools F<bin> directory and
made a symlink from the RTI F<bin> directory to it which
makes it available from the command line for the I<tfsupport> account.

The steps performed during the installation of the production server
are outlined below:

=over 4

=item 1.

make the I<tfrsync.pl> backup directory if it does not exist.
For a RTI system, this is F</usr2/tfrsync>, and
for a Daisy system, this is F</d/tfrsync>.

=item 2.

make the production server transfer directory if it does not exist.
This directory is located in the home directory of the I<tfsupport>
account and is named F<pserver_xfer.d>.
The transfer directory is used to hold files that are to be
copied from the production server to the backup server.

=item 3.

make the production server info directory if it does not exist.
This directory is located in the I<tfrsync.pl> backup directory and
is named F<pserver_info.d>.
The production server info directory is the location of the
production server info file which is named F<pserver_info.txt>.
The production server info file is generated each time
a backup transaction occurs.

=item 4.

make the production server cloister directory if it does not exist.
This directory is located in the I<tfrsync.pl> backup directory and
is named F<pserver_cloister.d>.
The cloister directory is used to hold backup copies of
certain files that need to be backed up but need to be
segregated into a special location rather than be copied
"in place" like the bulk of the files to be backed up.
Examples of such files are F</var/spool/cron> and F</etc/cron.d>.
These files need segregation because if they are copied "in place"
to the backup server, they would cause behavior on the backup server
that would not be wanted, ie they would cause cron jobs to run.

=item 5.

make the users info directory if it does not exist.
This directory is located in the I<tfrsync.pl> backup directory and
is named F<users_info.d>.
The users info directory is used to hold files containing info
about the POS users on the production server.
These files are copied to the backup server and are required
for transforming a backup server into a production server.

=item 6.

if the I<tfrsync.pl> account does not exist, add the I<tfrsync.pl> account.

=item 7.

generate a password-less SSH key-pair for the I<tfrsyc> account and
copy the public SSH key file that was just generated
to the production server transfer directory.
The name of the public key file is F<id_rsa.pub>.

=item 8.

add a new cron job file named F<tfrsync> to the directory
F</etc/cron.d>.  If there is an existing cron job file there,
then the cron job file is placed in the OSTools config
directory instead.

=item 9.

generate a new config file and put it into the OSTools config directory.
If there is already an existing config file for I<tfrsync.pl>,
then do not overwrite the old config file - rather, put the new config file
into the OSTools config dir with the extension F<.new>.

=back


=head2 Installation on the Backup Server

In addition to installation of I<tfrsync.pl> on the RTI production server,
there are several installation steps that must also be performed
on the backup server, aka secondary server.
To install I<tfrsync.pl> on the backup server,
first install the OSTools package on the secondary server.
Then, run the I<tfrsync.pl> script on the backup server
specifying the B<--install-secondary> command line option.
The B<--primary-server=s> may also be specified with the
B<--install-secondary> option;
it is used to specify the hostname or IP address of the production server.
If the B<--primary-server=s> option is not specifed, then
the default value for the IP address of the production server is used.
The default value is 192.168.1.21.
The following steps are performed:

=over 4

=item 1.

an account named I<tfrsync> is added if it does not exist

=item 2.

the account name I<tfrsync> is added to the F</etc/sudoers> file
to allow the I<tfrsync> account to run the C<rsync> command as root
without being prompted for a password.
This is accomplished by adding the account name I<tfrsync> to the
OSTools F<harden_linux.pl> config file and then running the
C<harden_linux.pl --sudo> command.

=item 3.

the public key of the I<tfrsync> account on the production server is
added to the F<.ssh/authorized_keys> file of the
I<tfrsync> account on the backup server

=item 4.

service httpd stop and chkconfig httpd off

=item 5.

service rti stop and chkconfig rti off

=item 6.

move /usr2/bbx/bin/doveserver.pl to /usr2/bbx/bin/doveserver.pl.save

=item 7.

service blm stop and chkconfig blm off

=item 8.

service bbj stop and chkconfig bbj off

=back


=head2 Uninstall on the Backup Server

The B<--uninstall-secondary> command line option
undoes what was done to install the I<tfrsync.pl> script
on the secondary server.

=over 4

=item 1.

the account named I<tfrsync> is removed from the C</etc/sudoers> file
by removing the C<harden_linux.pl> sudoers content file from the
C<harden_linux.pl> sudoers config directory,
C</d/ostools/config/sudoers.d> on Daisy systems and
C</usr2/ostools/config/suders.d> on RTI systems, and
then running the C<harden_linux.pl --sudo> command.

=item 2.

the public key of the I<tfrsync> account on the production server is
removed from the C<~tfrsync/.ssh/authorized_keys> file on the
backup server.

=item 3.

the account named I<tfrsync> is removed from the backup server.

=back


=head2 Backup Retries

When doing a backup to a cloud server, if the Internet connection
is inconsistent and unreliable, the rsync command can fail with a
protocol error, or an i/o error, or an ssh connection error.
For systems experiencing these conditions, the command line options
B<--retry-backup>, B<--retry-reps=n> and B<--retry-wait=secs> can be
very useful.
When B<--retry-backup> is specified, if there is an rsync error
as described above,
the entire backup operation is retried one or more times with a wait
between each retry.
The default number of times to retry is 3.
The default time to wait between retries is 2 minutes (120 seconds).
The B<--retry-reps=n> and B<--retry-wait=secs> allows you to tune
the retry and wait values to best suite your situation.
These options are also supported in the config file so they
can be specified on the command line as well as the config file.


=head2 Sending Email

The I<tfrsync.pl> script can be configured to send email depending
on one of several conditions.  First, described below is
when an email message is sent, and second, how an email message is sent.

=over 4

=item Could not start new instance

If there are email recipients specified on the command line or
in the config file, and the I<tfrsync.pl> script can not execute
because an instance of the I<tfrsync.pl> script is aleady running
as indicated by not being able to obtain the process lock,
an error message will be sent to each of the recipients.

=item Backup device not found

If there are email recipients specified on the command line or
in the config file, and a backup device is not found, an error
message will be sent to each of the recipients.

=item Backup error

If there are email recipients specified on the command line or
in the config file, and an error occurred during a backup operation,
then a status message will be sent to each of the recipients.

=item Backup summary report

If there are email recipients specified on the command line or
in the config file, and the C<--send-summary> command line option
is specified or the C<send-summary> statement is set to true in
the config file, then
a summary report will be sent to each of the recipients.

=back

Given that one or more email recipients are specified, and
one of the conditions upon which the script will attempt to
send an email message occurs, then the message can be sent
one of the following methods.  Note, if there is no email
server configured in the config file, then no mail message
will be sent even if there are recipients specified.

=over 4

=item Sendmail

If the C<email_server> config file statement is specified with
a value of C<sendmail>, then any email messages sent by the script
will directly invoke the C</usr/lib/sendmail -oi -t> program with a
from address of C<tfrsync.pl@HOSTNAME.teleflora.com> where
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

=back

=head2 Rsync of Summary Log File

After a backup operation is complete, ie after all
changed files have been written to the backup device or
to the backup server or to the cloud server,
a summary log file is written locally to the POS log directory.
Thus, this summary log file will not be transferred to the backup device until
the next time a backup operation is performed.
In order to backup the summary log file and
to have convenient access to this file for monitoring and reporting,
a resync of the summary log file is performed
after the backup operation is complete and
the summary log file has been written.


=head2 Config File

The I<tfrsync.pl> script supports one or more config files.
The default config file name and location is specified in
the FILES section below.
There are many configuration attributes that can be set
in the config file.
Refer to the comments in the generated default config file
for a list of attributes, their meaning, and their values.


=head2 Backup to a LUKS Device

In addition to "cloud" and "server" backup,
the I<tfrsync.pl> script supports backing up files to a LUKS device, ie
a locally connected disk drive that has been specially initialized
according to the LUKS specification.
A LUKS device is one that complies with the "Linux Unified Key Setup"
disk encryption specification.  For more info, see the Wikipedia
entry: L<< https://en.wikipedia.org/wiki/Linux_Unified_Key_Setup >>
Essentially, the backups are written to an encrypted file system
which resides on a locally connected block device that has been
configured to be a LUKS device.
Files written to or read from the LUKS device are encrypted or
decrypted by the Linux kernel automatically.

To configure a local disk drive as a LUKS device,
two steps are required.
First, install the I<tfrsync.pl> script
using the B<--luks-install> command line option, and
then initialize the backup disk
as a LUKS device with the B<--luks-init> command line option.
Then the backup disk is ready to be used as a LUKS device.
After script installation and backup disk initialization,
the LUKS device can be used as a backup disk, 
using the B<--backup=> command line option
to specify the set of files to write to the disk.
See the EXAMPLES section below for specific command lines.

By default, the backup disk is expected to be a Western Digital Passport.
When the script starts, it will automatically look for a Passport as the
backup disk.
Upon finding a Passport, it will determine it's block device name but
a specific block device name can be specified
via the B<--device=> option.
In order to automatically find the Passport,
it must be connected to the system and
the block device name for it must be one of C</dev/sda> through C</dev/sdg>.

The I<tfrsync.pl> script maintains 4 separate trees of files on the
LUKS device being used as the backup disk.
The head of each tree is a directory
at the top of the file system on the LUKS device.
These directories are named "today, "yesterday", "weekly" and "monthly".
When the script runs, if the current day of the month matches the
day of the month of the C<mtime> field of the "today" directory, then
the backup operation is performed against that tree.
If the current day of the month does not match, then
the "yesterday" tree is renamed to "today", and
the "today" tree is renamed to "yesterday", and
then the backup operation is performed against the new "today" tree.
After the backup operation is complete, if the current day of the week
is Sunday, then the "weekly" tree is updated.
Similarly, if the current day of the month is the first day of the month,
then the "monthly" tree is updated.

Thus, with this strategy, the 4 trees on the LUKS device will have
a backup that is the current backup less than one day old,
a backup that is 1 day old,
a backup this is 1 week old, and finally
a backup that is 1 month old.

The LUKS device encrption scheme uses the AES block cypher,
with a 256-bit key, and if you don't specify a LUKS key when
initializing the LUKS device, the DELL service tag will be used.
The LUKS initialization step writes the LUKS header on the disk;
the header is where the key is stored.
The LUKS "key" is really a passphrase used for encrypting a
master key which is automatically generated by the system.
Thus, the LUKS key is not the key used to encrypt the data but
merely allows access to the use of the master key.


=head2 Production Server Info File

The production server info file, aka pserver info file,
contains key information about the production server.
It is generated each time a backup is performed and
is copied to the backup server, or cloud server, or device
each time there is a backup.

The name of the pserver info file is F<pserver_info.txt> and
is located in the F</usr2/tfrsync/pserver_info.d> directory
on an RTI system and in the F</d/tfrsync/pserver_info.d>
directory on a Daisy system.
The file is a simple ASCII text file,
with each line consisting of an attribute/value pair,
separated by an EQUALS SIGN.

The pserver info file contains the following attributes;

=over 4

=item platform

The value is the name of the platform, either
"RHEL5", or "RHEL6", or "RHEL7".

=item hostname

The value is the hostname of the production server. 

=item ipaddr

The IP address of the production server

=item netmask

The netmask of the production server

=item gateway

The IP address of the "gateway", ie the router.

=back

As a concrete example, if the production server was a
Daisy "RHEL5" system,
the pserver info file would look similar to the following,
with values adjusted as appropriate:

 platform=RHEL5
 hostname=77777700-tsrvr
 ipaddr=192.168.1.21
 netmask=255.255.255.0
 gateway=192.168.1.1




=head2 Backup Summary Log File

The backup summary log file contains an entry for each execution
of the I<tfrsync.pl> script.
Each entry is about 750 bytes long and is a short summary of the backup result.
This file grows without bound, but due to the relatively small entry size and
frequency of execution, it should not be a factor in disk space usage.
The backup summary log file can be rotated each year if desired.
This rotation is disabled by default, but
can be enabled via the C<--summary-log-rotate> command line option or
the C<summary-log-rotate=true> statement in the config file.
If summary log file rotation is enabled, then
upon each execution of I<tfrsync.pl>, the script determines
the date of the earliest entry in the summary log file -
if the date is more than 1 year earlier than the current date,
then the current file is
renamed with a name that includes the date of the earliest entry.
Then a new summary log file will be established and used for another year.
By default, a minimum of 3 copies of the summary log file is kept, and
a maximum of 10;
these values are configurable on the command line or through the config file.

Each entry in the summary log file consists of a record of 17 lines,
one line per field, in the format oulined below.
If the value of an entry is not applicable to the type of backup being performed,
the value of the field will be the string "NA".

=over 4

=item separator line

A line of 80 "=" chars.

=item script name

The file name of the script, I<tfrsync.pl>.

=item script version

The CVS revision number of the script.

=item command line

The command line used to invoke the script.

=item execution start time

The execution start time in the format of "YMD-HMS", which
for example, Jan 27, 2014 at 10:40 and 24 seconds
would be "20150127-104024".

=item execution stop time

The execution stop time in the format of "YMD-HMS", which
for example, Jan 27, 2014 at 10:40 and 24 seconds
would be "20150127-104024".

=item execution duration

The length of time for the execution in the format of "H:M:S", which
for example, a duration of 0 hours, 10 minutes, and 27 seconds
would be "00:10:27".

=item device type

The backup device type, would will usually be
"cloud", "server", "passport", or "usb".

=item result description

The english equivaliant of the exit status.

=item rsync exit status

The exit status reported by the F<rsync> command used
to perform the backup.

=item rsync backup retries

The number of times that the F<rsync> command was retried.

=item rsync warnings

A list of one or more rsync exit status values that are
considered to  be just warnings.
If there are no warnings, then the value is just "0".

=item bytes written

The total number of bytes written by rsync.

=item server IP addr

The hostname or IP address of the cloud server or the backup server.

=item path on server

The value of the B<--rsync-dir> option if it was specified.
Not applicable for "cloud" backup.

=item device file path

The path of the device file for the backup device, which,
for example, might be F</dev/sdb1> for a Passport device.
Not applicable for "cloud" backup.

=item backup device capacity

The total capacity of the backup device.
Not applicable for "cloud" backup.

=item backup device available space

The available space left on the backup device.
Not applicable for "cloud" backup.

=item separator line

A line of 80 "=" chars.

=back

Here is an example of the contents of a summary log file:

 ================================================================================
     PROGRAM: tfrsync.pl
     VERSION: $Revision: 1.227 $
     COMMAND: /home/tfsupport/tfrsync.pl --server --backup=osconfigs
       BEGIN: 20150210-133052
         END: 20150210-133103
    DURATION: 00:00:11
      DEVICE: server
      RESULT: Exit OK
       RSYNC: 0
     RETRIES: 0
    WARNINGS: 0
  BYTES SENT: 374.17KB
      SERVER: 192.168.2.31
        PATH: /tmp
 DEVICE FILE: NA
    CAPACITY: NA
   AVAILABLE: NA
 ================================================================================


=head1 EXAMPLES

To install the I<tfrsync.pl> script on a Teleflora POS system and
configure it as the production server, enter the following:

 sudo tfrsync.pl --server --install-production-server

To get info about the installation on the primary server, you can
enter the following:

 sudo tfrsync.pl --info-production-server

To install the I<tfrsync.pl> script on a Teleflora POS system and
configure it as the backup server, enter the following:

 sudo tfrsync.pl --install-secondary --production-server=192.168.1.21

On an RTI system,
to backup all files in all backup types to the backup server at
IP addr 192.168.1.22, in the directory F</usr2/tfrsync>, enter the following:

 sudo tfrsync.pl --server --backup=all --rsync-server=192.168.1.22

To display the filenames contained in the backup type C<netconfigs>,
enter the following:

 sudo tfrsync.pl --server --backup=netconfigs --show-only

To perform a backup operation to a cloud server with retries,
with the number of retries 5 and the time of 3 minutes to wait between each retry,
enter the following:

 sudo tfrsync.pl --cloud --backup=all --retry-backup --retry-reps=5 --retry-wait=180

To backup a single file, say F</etc/motd>, from the production server
to the backup server and put it in F</tmp> on the backup server,
enter the following:

 sudo tfrsync.pl --server --singlefile=/etc/motd --backup=singlefile --rsync-dir=/tmp

To restore the single file F</tmp/etc/printcap> from the backup server and
put it in the F</tmp> directory on the production server,
enter the following:

 sudo tfrsync.pl --server --singlefile=/etc/printcap --restore=singlefile \
    --rsync-dir=/tmp --rootdir=/tmp

To use an external USB Western Digital Passport as a LUKS backup device,
first install the I<tfrsync.pl> script for use with a LUKS device, then initialize
the Passport as a LUKS device, and then you can use it as a backup device.
To install the I<tfrsync.pl> script for use with a LUKS device, enter:

 sudo tfrsync.pl --luks-install

To initialize the LUKS device, enter the following command - note, by not specifying
the B<--device=s> option, the script will look for a Western Digitial Passport
connected to the system as block device C</dev/sda> through C</dev/sdg>.
Also not that if you don't specify the LUKS key, the DELL service tag
will be used.

 sudo tfrsync.pl --luks --luks-key=fred --luks-init

To use the Western Digital Passport as the LUKS backup device,
enter the command:

 sudo tfrsync.pl --backup=all

To get the date of the last backup to the LUKS device,
enter the command:

 sudo tfrsync.pl --luks --luks-backup-date

To get more information about the LUKS device, enter:

 sudo tfrsync.pl --luks --luks-getinfo

To get low level system information about the LUKS device, enter:

 sudo tfrsync.pl --luks --luks-status

To view files on the LUKS device, first mount the LUKS device,
use ordinary shell commands to view or manipulate files on the
LUKS device, and then make sure to umount the LUKS device:

 sudo tfrsync.pl --luks --luks-key=fred --luks-mount
 ls -l /mnt/backups
 cp -pr /mnt/backups/yesterday/etc /tmp
 sudo tfrsync.pl --luks --luks-key=fred --luks-umount


=head1 FILES

=over 4

=item F</usr2/tfrsync>

The I<tfrsync.pl> backup directory for a RTI system.

=item F</d/tfrsync>

The I<tfrsync.pl> backup directory for a Daisy system.

=item F</home/tfrsync>

The home directory of the I<tfrsync> account.

=item F</home/tfsupport>

The home directory of the Teleflora support account

=item F</home/tfsupport/pserver_xfer.d>

The production server transfer directory.

=item F<pserver_cloister.d>

The production server cloister directory is located
in the F<tfrsync.pl> backup directory.

=item F<pserver_info.d>

the production server info directory and is located
in the F<tfrsync.pl> backup directory.

=item F<pserver_info.txt>

The production server info file -
it contains information about the production server and
is located in the production server info directory.
The production server info file is generated each time
a backup transaction occurs.
Contents include the production server platform string
(either "RHEL5", or "RHEL6", or "RHEL7"),
the production server's hostname, IP address, and netmask, and
the gateway IP address.

=item F<users_info.d>

The users info directory is located
in the F<tfrsync.pl> backup directory.

=item F</usr2/tfrsync/users_info.d/rti_users_listing.txt>

The RTI users listing file.

=item F</usr2/tfrsync/users_info.d/rti_users_shadow.txt>

The shadow file entries for the users in the RTI users listing file.

=item F</d/tfrsync/users_info.d/daisy_users_listing.txt>

The Daisy users listing file.

=item F</d/tfrsync/users_info.d/daisy_users_shadow.txt>

The shadow file entries for the users in the Daisy users listing file.

=item F<id_rsa.pub>

The name of the public SSH key file.

=item F</etc/cron.d/tfrsync>

the F<tfrsync.pl> cron job file.

=item F<tfrsync-server-Day_nn.log>

The name of the log file for destination class "server".
The string I<nn> is replaced by the zero filled, two digit
day of the month.

=item F<tfrsync-cloud-Day_nn.log>

The name of the log file for destination class "cloud".
The string I<nn> is replaced by the zero filled, two digit
day of the month.

=item F<tfrsync-device-Day_nn.log>

The name of the log file for destination class "device".
The string I<nn> is replaced by the zero filled, two digit
day of the month.

=item F<tfrsync-summary.log>

The summary log file contains an entry for each execution
of the I<tfrsync.pl> script with a short summary of the result.

=item F</usr2/bbx/log> 

On an RTI system, the location of the log files.
If this directory does not exist, the log files will be
put in F</tmp>.

=item F</d/daisy/log>

On a Daisy system, the location of the log files.
If this directory does not exist, the log files will be
put in F</tmp>.

=item F</usr2/ostools/config>

The location of the default I<tfrsync.pl> config file for an RTI system.

=item F</d/ostools/config>

The location of the default I<tfrsync.pl> config file for a Daisy system.

=item F<tfrsync.conf>

The name of the default I<tfrsync.pl> config file.

=item F</usr2/ostools/config/tfrsync.d>

The location of optional custom config files for an RTI system.

=item F</d/ostools/config/tfrsync.d>

The location of optional custom config files for a Daisy system.

=item F</mnt/backups>

Mount point for backup devices.

=item F</etc/redhat-release>

Contents determines OS type.

=item F</sys/block/{sda,sdb,sdc,sde,sdd}/device/vendor>

This file contains the vendor string for the block device, ie disk,
that has special device file "/dev/sda", or "/dev/sdb", etc.

=item F</sys/block/{sda,sdb,sdc,sde,sdd}/device/model>

This file contains the model string for the block device, ie disk,
that has special device file "/dev/sda", or "/dev/sdb", etc.

=item F</usr2/tfrsync/$backuptype-perms.txt>

The metadata files generated on a RTI system when doing a backup to the cloud.
See the output of F<tfrsync.pl --help> for a list of backup type values
that "$backuptype" may take.

=item F</d/tfrsync/$backuptype-perms.txt>

The metadata files generated on a Daisy sysstem when doing a backup to the cloud.
See the output of F<tfrsync.pl --help> for a list of backup type values
that "$backuptype" may take.

=item F</var/lock/tfrsync-server.lock>

=item F</var/lock/tfrsync-cloud.lock>

=item F</var/lock/tfrsync-device.lock>

The process lock file.
There is a separate process lock file for each of the device types.
The process lock file path will be one of the paths above,
for either the "server", "cloud", or "device",
which corresponds to each of the device types.
When the script starts, an attempt is made to acquire the lock file
corresponding to the device type;
if the lock file already exists when this check is made, then
it indicates that an existing process has the lock for that device type and
thus, a new process is not allowed to proceed. 

=item F</var/run/tfrsync-server.socket>

=item F</var/run/tfrsync-cloud.socket>

The SSH tunnel socket.
There is a separate SSH tunnel socket for each of the destination classes.
For the backup destination class "server",
the name of the socket is F<tfrsync-server.socket>.
For the "cloud" destination class, the name is F<tfrsync-cloud.socket>.
When a backup or restore operation is performed,
an attempt is made to establish an SSH tunnel on a socket at the appropriate path.
If the socket already exists, it indicates that a previous process
used the socket for a connection to the remote device and crashed
without cleaning up the socket;
the B<--runtime-cleanup> command can be used to cleanup stale sockets.
If the SSH command returns an exit status of 255,
the script makes 3 attempts to open the socket before
returning an error.

=item F</tmp/tfrsync-rsyncstats-XXXXXXX>

A temp file to hold the stats generated during a successful rsync command.
The stats are compiled immedately after a rsync command completes and
then the temp file is deleted.

=back


=head1 DIAGNOSTICS

=over 4

=item "Error: invalid command line option, exiting..."

This message is output if an invalid command line option was entered.

=item "--cloud and --server are mutually exclusive"

Only one of the "--cloud" and "--server" command line options may appear
on the command line at an execution of the script - either you are doing
a "cloud" backup or a "server" backup.
If your production server is configured to be backed up to both, then you 
must run "tfrsync.pl" twice, once for "cloud", and once for "server".

=item "tfrsync.pl must be run as root or with sudo"

You can run the "tfrsync.pl" script with the "--help" or "--version"
command line options as a non-root user,
but any other usage must be run as root.

=item "[tfr_finddev] backup device not found"

Error message if the B<--finddev> or B<--report-device> command line option is specified and
a USB or Passport backup device is not found.

=back


=head1 EXIT STATUS

=over 4

=item Exit status 0 ($EXIT_OK)

Successful completion.

=item Exit status 1 ($EXIT_COMMAND_LINE)

In general, there was an issue with the syntax of the command line.

=item Exit status 2 ($EXIT_MUST_BE_ROOT)

The script must run as root or with sudo(1).

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

=item Exit status 8 ($EXIT_MOUNT_ERROR)

An error occurred when trying to mount a backup device that
was of type block device or image file.

=item Exit status 9 ($EXIT_RESTORE)

An unsupported restore type was specified on the command line.

=item Exit status 10 ($EXIT_DEVICE_NOT_SPECIFIED)

A backup device was not specified nor could be found

=item Exit status 11 ($EXIT_DEVICE_VERIFY)

The specified backup device is either not a block device or
is not an image file of minimum size.

=item Exit status 12 ($EXIT_USB_DEVICE_UNSUPPORTED)

USB devices other than WD Passports are not supported on RHEL4.

=item Exit status 13 ($EXIT_CRON_JOB_FILE)

An error occurred when installing the cron job file.

=item Exit status 14 ($EXIT_DEF_CONFIG_FILE)

An error occurred when installing the default config file.

=item Exit status 15 ($EXIT_FORMAT)

An error occurred when formatting the backup device.

=item Exit status 16 ($EXIT_LIST_UNSUP)

An unsupported list type was specified on the command line.

=item Exit status 17 ($EXIT_LIST)

The files of the specified backup type could not be listed.

=item Exit status 18 ($EXIT_SIGINT)

Script received interrupt signal during a rsync transaction.

=item Exit status 19 ($EXIT_RSYNC_ACCOUNT)

An error occurred either when making the I<tfrsync> account
while installing or
when removing the I<tfrsync> account while uninstalling.

=item Exit status 20 ($EXIT_SSH_GENERATE_KEYS)

An error occurred when generating the RSA keypair for
the account used to run the rsync command.

=item Exit status 21 ($EXIT_SSH_GET_PUBLIC_KEY)

An error occurred when getting the public key for an
C<rsync> account on the production server.

=item Exit status 22 ($EXIT_SSH_GET_PRIVATE_KEY)

An error occurred when getting the private key for an
C<rsync> account on the production server.

=item Exit status 23 ($EXIT_SSH_SUDO_CONF)

An error occurred configuring the F</etc/sudoers> file
to allow an C<rsync> account to run I<rsync> command via I<sudo>; 
this is accomplished not by directly editing F</etc/sudoers>, but
rather by using the mechanism for doing this provided in the
I<harden_linux.pl> config file.

=item Exit status 24 ($EXIT_SSH_TUNNEL_OPEN)

An error occurred opening SSH tunnel.

=item Exit status 25 ($EXIT_SSH_TUNNEL_CLOSE)

An error occurred closing SSH tunnel.

=item Exit status 26 ($EXIT_SSH_COPY_PUBLIC_KEY)

An error occurred when trying to copy the newly generated
public key of the C<rsync> account to the default SSH dir
of the I<tfsupport> account.

=item Exit status 27 ($EXIT_SSH_ID_FILE)

The path to the SSH identity file for a specified account
could not be found.

=item Exit status 29 ($EXIT_CLOUD_ACCOUNT_NAME)

An error occurred forming the name of the cloud account.

=item Exit status 30 ($EXIT_GENERATE_PERMS)

An error occurred generating the perm file for a backup type.

=item Exit status 31 ($EXIT_UPLOAD_PERMS)

An error occurred uploading a perm file to the cloud server.

=item Exit status 32 ($EXIT_RESTORE_PERMS)

When restoring perms from a perm file via the
B<--restore-from-permfiles> command line option,
there was an error restoring the perms on the files
corresponding to the specified backup type.

=item Exit status 33 ($EXIT_DOWNLOAD_PERMS)

When downloading a perm file via the
B<--download-permfiles> command line option,
the perm file corresponding to the specified backup type
can not be downloaded from the cloud server.

=item Exit status 34 ($EXIT_PERM_FILE_MISSING)

When restoring permissions from a perm file via the
B<--restore-from-permfiles> command line option,
the perm file corresponding to the specified backup type
can not be found.

=item Exit status 40 ($EXIT_LOCK_ACQUISITION)

Could not acquire the appropriate lockfile which means some
previous instance of the script is still running.

=item Exit status 41 ($EXIT_BACKUP_DEVICE_CONFLICT)

If a backup device is specified with B<--device> or
a usb device is specified with B<--usb-device> and
B<--rsync-server> is specified, this error results.
You may not back up to both a device and an rsync server
at the same time.

Likewise, if a backup device is specified with B<--device> or
a usb device is specified with B<--usb-device> and
B<--rsync-dir> is specified and not B<--rsync-server>, this error results.
You may not back up to both a device and a file system
at the same time.

=item Exit status 42 ($EXIT_PLATFORM)

Unknown operating system.

=item Exit status 43 ($EXIT_RSYNC_ERROR)

The F<rsync> command returned an error.
This script response is to stop backup transactions and exit.

=item Exit status 44 ($EXIT_USERS_INFO_SAVE)

The users info files could not be generated and saved when
attempting a backup.

=item Exit status 45 ($EXIT_PSERVER_INFO_SAVE)

The pserver info file could not be saved when
attempting a backup.

=item Exit status 46 ($EXIT_PSERVER_CLOISTER_FILES_SAVE)

The pserver cloister files cound not saved when
attempting a backup.

=item Exit status 50 ($EXIT_XFERDIR_WRITE_ERROR)

An error occurred when attempting to write a file in the xfer dir.

=item Exit status 51 ($EXIT_XFERDIR_MKDIR)

An error occurred when attempting to make the transfer directory.
This could happen during installation on the production or the
backup server.

=item Exit status 52 ($EXIT_XFERDIR_RMDIR)

An error occurred when attempting to remove the transfer directory.

=item Exit status 53 ($EXIT_INFODIR_MKDIR)

An error occurred when attempting to make the production server info directory.

=item Exit status 54 ($EXIT_INFODIR_RMDIR)

An error occurred when attempting to remove the production server info directory.

=item Exit status 55 ($EXIT_USERSDIR_MKDIR)

An error occurred when attempting to make the users info directory.

=item Exit status 56 ($EXIT_USERSDIR_RMDIR)

An error occurred when attempting to remove the users info directory.

=item Exit status 57 ($EXIT_TOP_LEVEL_MKDIR)

Could not make the top level backup dir, ie
F</usr2/tfrsync> on RTI, or F</d/tfrsync> on Daisy.

=item Exit status 58 ($EXIT_INSTALL_PSERVER_INFO_FILE)

An error occurred when attempting to copy the
info file from the production server to the backup server.

=item Exit status 59 ($EXIT_DOVE_SERVER_MISSING)

During installation on the backup server, the script
verifies that the Dove server script exists and
if it does not, the script exits with this exit status.

=item Exit status 60 ($EXIT_DOVE_SERVER_SAVE_EXISTS)

During installation on the backup server,
the script verifies that the saved Dover server script
does NOT exist, and if it does, the script exits with
this exit status.

=item Exit status 62 ($EXIT_CLOISTERDIR_MKDIR)

An error occurred when attempting to make
the directory for the production server cloistered files.

=item Exit status 63 ($EXIT_CLOISTERDIR_RMDIR)

An error occurred when attempting to remove
the directory for the production server cloistered files.

=item Exit status 64 ($EXIT_RUNTIME_CLEANUP)

Could not cleanup the process lock or the SSH tunnel socket.

=item Exit status 70 ($EXIT_COULD_NOT_EXECUTE)

The script was attempting to exec a program,
typically via the builtin fuction C<system>, and
the exec of the program failed.

=item Exit status 71 ($EXIT_FROM_SIGNAL)

The script execed a program and the program exited
because it caught a signal.

=item Exit status 72 ($EXIT_LOGFILE_SETUP)

An error occurred while attempting to establish the
location for the log files.

=item Exit status 73 ($EXIT_NET_IPADDR)

Could not get the ip address of the network device.

=item Exit status 74 ($EXIT_NET_NETMASK)

Could not get the netmask of the network device.

=item Exit status 75 ($EXIT_NET_GATEWAY)

Could not get the ip address of the gateway (router).

=item Exit status 92 ($EXIT_SEND_TEST_EMAIL)

Could not send a test email message.

=item Exit status 93 ($EXIT_LUKS_UUID)

Could not get UUID for LUKS device.

=item Exit status 94 ($EXIT_LUKS_STATUS)

Could not get status for LUKS device.

=item Exit status 95 ($EXIT_LUKS_GETINFO)

Could not get info about LUKS device.

=back


=head1 SEE ALSO

I<rsync(1)>, I<rtibackup.pl>, I<harden_linux.pl>


=cut
