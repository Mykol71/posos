#!/usr/bin/perl
#
# $Revision: 1.32 $
# Copyright 2013-2017 Teleflora
#
# tfmkpserver.pl
#
# Script to make a backup server into a production server.
#

use strict;
use warnings;
use POSIX;
use Getopt::Long;
use English qw( -no_match_vars );
use Net::SMTP;
use File::Basename;
use File::Temp qw(tempfile);
use File::stat;
use Sys::Hostname;

use lib qw( /teleflora/ostools/modules /d/ostools/modules /usr2/ostools/modules );
use OSTools::Platform;
use OSTools::Hardware;
use OSTools::AppEnv;


our $VERSION = 1.15;
my $CVS_REVISION = '$Revision: 1.32 $';
my $TIMESTAMP = strftime('%Y%m%d%H%M%S', localtime());
my $PROGNAME = basename($PROGRAM_NAME);

#######################################
#########   D E F A U L T S   #########
#######################################

my $PROJ_NAME_DEF       = 'tfrsync';

my $RTI_TOPDIR          = '/usr2';
my $RTIDIR              = $RTI_TOPDIR . '/bbx';
my $RTI_BINDIR          = $RTIDIR . q{/} . 'bin';
my $RTI_CONFIG_DIR      = $RTIDIR . q{/} . 'config';
my $RTI_TFRSYNC_DIR     = $RTI_TOPDIR . q{/} . $PROJ_NAME_DEF;
my $RTI_RSYNC_BU_DIR    = $RTI_TOPDIR . q{/} . $PROJ_NAME_DEF;
my $TOOLSDIR_RTI_DEF    = $RTI_TOPDIR . q{/} . 'ostools';

my $DAISY_TOPDIR        = '/d';
my $DAISYDIR            = $DAISY_TOPDIR . q{/} . 'daisy';
my $DAISY_BINDIR        = $DAISYDIR . q{/} . 'bin';
my $DAISY_TFRSYNC_DIR   = $DAISY_TOPDIR . q{/} . $PROJ_NAME_DEF;
my $DAISY_RSYNC_BU_DIR  = $DAISY_TOPDIR . q{/} . $PROJ_NAME_DEF;
my $TOOLSDIR_DAISY_DEF  = $DAISY_TOPDIR . q{/} . 'ostools';

my $PRIMARY_SERVER_IP_DEF       = '192.168.1.21';

my $RSYNC_ACCOUNT_DEF           = $PROJ_NAME_DEF;
my $RSYNC_ACCOUNT_NAME_DEF      = $PROJ_NAME_DEF;
my $RSYNC_ACCOUNT_FULL_NAME_DEF = $PROJ_NAME_DEF . ' user';

my $TFSUPPORT_ACCOUNT_NAME_DEF  =  'tfsupport';

# name of directory used to hold info to be transferred
# between production server and backup server...
my $PSERVER_XFER_DIR  = 'pserver_xfer.d';

# name of dir to hold production server info files
my $PSERVER_INFO_DIR         = 'pserver_info.d';

# name of the file to hold production server info
my $PSERVER_INFO_FILE        = 'pserver_info.txt';

# name of dir to hold backup server info files
my $BUSERVER_INFO_DIR        = 'buserver_info.d';

# name of the file to hold the backup server info
my $BUSERVER_INFO_FILE       = 'buserver_info.txt';

# name of dir to hold backup server system files
my $BUSERVER_SYSFILES_DIR    = 'buserver_sysfiles.d';

# name of dir to hold cloistered files
my $PSERVER_CLOISTER_DIR     = 'pserver_cloister.d';

# some components of TCC that must be present
my $TCC_RHEL5_TCC2 = $RTI_BINDIR . q{/} . 'tcc2_x64';
my $TCC_RHEL5_TCC  = $RTI_BINDIR . q{/} . 'tcc_x64';

my $TCC_RHEL6_TCC2 = $RTI_BINDIR . q{/} . 'tcc2_rhel6';
my $TCC_RHEL6_TCC  = $RTI_BINDIR . q{/} . 'tcc_rhel6';

my $TCC_RHEL7_TCC2 = $RTI_BINDIR . q{/} . 'tcc2_rhel7';
my $TCC_RHEL7_TCC  = $RTI_BINDIR . q{/} . 'tcc_rhel7';

# generic TCC paths
my $TCC_TCC        = $RTI_BINDIR . q{/} . 'tcc';
my $TCC_TCC_TWS    = $RTI_BINDIR . q{/} . 'tcc_tws';

# network device
my $NETWORK_DEVICE_DEF = 'eth0';


############################################
#########   E X I T  S T A T U S   #########
############################################

my $EXIT_OK = 0;
my $EXIT_COMMAND_LINE = 1;
my $EXIT_MUST_BE_ROOT = 2;

my $EXIT_PREREQS = 10;
my $EXIT_UPDATE_CONFIG = 11;
my $EXIT_START_RTI = 12;
my $EXIT_TCC_CONFIG = 13;
my $EXIT_NETWORK_CONFIG = 14;
my $EXIT_RESTORING_SPECIAL_FILES = 15;
my $EXIT_RESTORING_USERS = 16;
my $EXIT_SAMBA_PW_BACKEND = 17;
my $EXIT_SAMBA_USERS = 18;
my $EXIT_RESTORING_SYSTEM_FILES = 19;
my $EXIT_MKDIR_SERVER_INFO_DIR = 20;
my $EXIT_GEN_BSERVER_INFO_FILE = 21;
my $EXIT_INFO_FILE_GET = 22;
my $EXIT_MKDIR_SYSFILES_DIR = 23;
my $EXIT_SAVE_SYSFILES = 24;
my $EXIT_REVERT_SYSFILES = 25;
my $EXIT_SERVICE_STOP = 26;

my $EXIT_PLATFORM = 42;
my $EXIT_DOVE_SERVER_RM = 61;
my $EXIT_TEST_USERS_PASSWD = 97;
my $EXIT_TEST_USERS_FILE = 98;
my $EXIT_TEST_USERS_RESTORE = 99;;


#####################################
#########   G L O B A L S   #########
#####################################

my $EMPTY_STR = q{};
my $SPACE_CHAR = q{ };

my $OS = $EMPTY_STR;
my $ALTROOT = ($ENV{'ALTROOT'}) ? "$ENV{'ALTROOT'}" : $EMPTY_STR;
my $ALTOS = ($ENV{'ALTOS'}) ? "$ENV{'ALTOS'}" : $EMPTY_STR;

my $RTI                    = 0;
my $DAISY                  = 0;

my $RSYNC_BU_DIR_RTI       = $RTI_TFRSYNC_DIR;
my $RSYNC_ACCOUNT          = $RSYNC_ACCOUNT_NAME_DEF;
my $TFSUPPORT_ACCOUNT      = $TFSUPPORT_ACCOUNT_NAME_DEF;
my $TOOLSDIR               = $EMPTY_STR;

my $RTI_DOVE_SERVER_NAME   = 'doveserver.pl';

my $SERVER_INFO_PLATFORM   = 'platform';
my $SERVER_INFO_HOSTNAME   = 'hostname';
my $SERVER_INFO_IPADDR     = 'ipaddr';
my $SERVER_INFO_NETMASK    = 'netmask';
my $SERVER_INFO_GATEWAY    = 'gateway';
my %SERVER_INFO_KEYS = (
    $SERVER_INFO_PLATFORM => 1,
    $SERVER_INFO_HOSTNAME => 1,
    $SERVER_INFO_IPADDR => 1,
    $SERVER_INFO_NETMASK => 1,
    $SERVER_INFO_GATEWAY => 1,
);

my $USERS_INFO_BU_DIR        = 'users_info.d';
my $NETCONFIGS_BU_DIR        = 'netconfigs.d';
my $USERCONFIGS_BU_DIR       = 'userconfigs.d';
my $USERFILES_BU_DIR         = 'userfiles.d';
my $SPECIALFILES_BU_DIR      = 'specialfiles.d';

my $RTI_USERS_LISTING_FILE   = 'rti_users_listing.txt';
my $RTI_USERS_SHADOW_FILE    = 'rti_users_shadow.txt';
my $DAISY_USERS_LISTING_FILE = 'daisy_users_listing.txt';
my $DAISY_USERS_SHADOW_FILE  = 'daisy_users_shadow.txt';

my $USER_TYPE_ADMIN          = 'admin user';
my $USER_TYPE_NONADMIN       = 'non-admin user';

##############################################
#########   C O M M A N D  L I N E   #########
##############################################

#
# The command line must be recorded before the GetOptions modules
# is called or any options will be removed.
#
my $COMMAND_LINE = get_command_line();

# command line options
my $HELP = 0;
my $CVS_VERSION = 0;
my $VERBOSE = 0;
my $CONVERT = 0;
my $REPORT = 0;
my $REVERT = 0;
my $LOGFILE_PATH = $EMPTY_STR;
my $NETWORK_DEVICE = $NETWORK_DEVICE_DEF;
my $KEEP_IP_ADDR = 0;
my $REPORT_FILES = 0;
my $DRY_RUN = 0;
my $TEST_CONF_FILE = $EMPTY_STR;
my $TEST_PW_FILE = $EMPTY_STR;
my $TEST_ADD_USERS = 0;
my $TEST_RESTORE_PASSWDS = 0;
my $TEST_SAMBA_GET_PASSWORD_BACKEND = 0;
my $TEST_SAMBA_SET_PASSWORD_BACKEND = 0;
my $TEST_SAMBA_GET_UIDS = 0;
my $TEST_SAMBA_SYNC_PASSWORD_UIDS = 0;
my $TEST_GENERATE_BUSERVER_INFO_FILE = 0;
my $TEST_GETFIELD_INFO_FILE = $EMPTY_STR;
my $DEBUGMODE = 0;

GetOptions(
    'help' => \$HELP,
    'version' => \$CVS_VERSION,
    'verbose' => \$VERBOSE,
    'report' => \$REPORT,
    'convert' => \$CONVERT,
    'revert' => \$REVERT,
    'logfile=s' => \$LOGFILE_PATH,
    'network-device=s' => \$NETWORK_DEVICE,
    'keep-ip-addr' => \$KEEP_IP_ADDR,
    'report-files' => \$REPORT_FILES,
    'dry-run' => \$DRY_RUN,
    'test-conf-file=s' => \$TEST_CONF_FILE,
    'test-pw-file=s' => \$TEST_PW_FILE,
    'test-add-users' => \$TEST_ADD_USERS,
    'test-restore-passwds' => \$TEST_RESTORE_PASSWDS,
    'test-samba-get-passwd-backend' => \$TEST_SAMBA_GET_PASSWORD_BACKEND,
    'test-samba-set-passwd-backend' => \$TEST_SAMBA_SET_PASSWORD_BACKEND,
    'test-samba-get-uids' => \$TEST_SAMBA_GET_UIDS,
    'test-samba-sync-passwd-uids' => \$TEST_SAMBA_SYNC_PASSWORD_UIDS,
    'test-generate-buserver-info-file' => \$TEST_GENERATE_BUSERVER_INFO_FILE,
    'test-getfield-info-file=s' => \$TEST_GETFIELD_INFO_FILE,
    'debugmode' => \$DEBUGMODE,
) || die "Error: invalid command line option, exiting...\n";


# --version
if ($CVS_VERSION) {
    print "OSTools Version: 1.15.0\n";
    print "$PROGNAME: $CVS_REVISION\n";
    exit($EXIT_OK);
}

# --help
if ($HELP) {
    usage();
    exit($EXIT_OK);
}

# which OS?
$OS = plat_os_version();
if (! defined($OS) || ($OS eq $EMPTY_STR)) {
    $OS = '(undefined)';
}

# which POS?
$RTI = (appenv_pos_name()) eq 'RTI' ? 1 : 0;
$DAISY = (appenv_pos_name()) eq 'Daisy' ? 1 : 0;

# which ostools?
$TOOLSDIR = appenv_ostools_dir();

# establish a logfile
logfile_setup();

#
# if there are any test options, code path will not return
# from the function call.
#
try_test_routines();

#
# obviously no testing going on, so do main.
#
my $exit_status = main();

exit($exit_status);


###############################
#########   M A I N   #########
###############################

sub main
{
    loginfo("$PROGNAME $CVS_REVISION");

    my $rc = $EXIT_OK;

    if ($REPORT_FILES) {
	return(tfmp_report_files());
    }

    # revert from production server to backup server
    if ($REVERT) {
	$rc = tfmp_revert();
	if ($rc == $EXIT_OK) {
	    showinfo('[main] production server reverted to backup server');
	}
	else {
	    showerror("[main] could not revert production server to backup server: $rc");
	}
    }

    # convert from backup server to production server
    if ($CONVERT) {
	$rc = tf_make_pserver();
	if ($rc == $EXIT_OK) {
	    showinfo('[main] backup server converted to production server');
	}
	else {
	    showerror("[main] could not convert backup server to production server: $rc");
	}
    }

    return($rc);
}


########################################
#########   F U N C T I O N S  #########
########################################

sub usage
{
    print "$PROGNAME $CVS_REVISION\n";
    print "SYNOPSIS\n";
    print "$PROGNAME --help\n";
    print "$PROGNAME --version\n";
    print "$PROGNAME [options]\n";
    print "OPTIONS\n";
    print "$PROGNAME --verbose\n";             # include more output than normal
    print "$PROGNAME --convert\n";             # convert from backup server to production server
    print "$PROGNAME --revert\n";              # revert from production server to backup server
    #print "$PROGNAME --report\n";              # report state of the backup server
    print "$PROGNAME --report-files\n";        # list paths to important files and directories
    print "$PROGNAME --logfile=path\n";        # specify logfile path
    print "$PROGNAME --network-device=s\n";    # specify network interface name
    print "$PROGNAME --keep-ip-addr\n";        # don't change ip addr
    print "$PROGNAME --dry-run\n";             # reveal operation but don't execute it
    print "$PROGNAME --debugmode\n";           # run in debug mode

    return(1);
}


#
# get the ip address of the default or CLI specified network interface.
#
# Returns
#   non-empty string on success
#   empty string on error
#
sub get_ip_address
{
    my $ip_addr = get_network_attribute($NETWORK_DEVICE, 'inet addr');

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
    my $netmask = get_network_attribute($NETWORK_DEVICE, 'Mask');

    return($netmask);
}


#
# get a network attribute - one of ip addr, broadcast address, or
# netmask.
#
# Returns
#   non-empty string on success
#   empty string on error
#
sub get_network_attribute
{
    my ($device, $pattern) = @_;

    my $rc = $EMPTY_STR;

    my $cmd = "/sbin/ifconfig $device 2> /dev/null";
    if (open(my $pipe, q{-|}, $cmd)) {
	while (<$pipe>) {
	    if (/${pattern}:(\d+\.\d+\.\d+\.\d+)/) {
		$rc = $1;
	    }
	}
	close($pipe) or warn "[get_network_attribute] could not close pipe: $OS_ERROR\n";
    }
    else {
	logerror("error opening pipe to command: $cmd");
    }

    return($rc);
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

    my $route_cmd = '/sbin/route -n';
    my $pattern = '0.0.0.0';
    my @route_table_entry = ();

    if (open(my $pipe, q{-|}, $route_cmd)) {
	while (<$pipe>) {
	    if (/^$pattern/) {
		@route_table_entry = split(/\s+/);
		last;
	    }
	}
	close($pipe) or warn "[get_gateway_ipaddr] could not close pipe: $OS_ERROR\n";
    }
    else {
	logerror("error opening pipe to command: $route_cmd");
    }

    # check for a route table entry with something reasonable in it
    if (exists($route_table_entry[1])) {
	my $gateway = $route_table_entry[1];
	if ($gateway =~ /\d+\.\d+\.\d+\.\d+/) {
	    $rc = $gateway;
	}
	else {
	    logerror("unrecognized format for gateway address: $rc");
	}
    }
    else {
	logerror("unexpected output of route command: $route_cmd");
    }

    return($rc);
}


sub get_command_line
{
    my $cmd_line = $PROGRAM_NAME;

    foreach my $i (@ARGV) {
	$cmd_line .= $SPACE_CHAR;
	if ($i =~ /\s/x) {
	    if ($i =~ /(--[[:print:]]+)(=)(.+)$/x) {
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
sub is_input_insecure
{
    my ($cmd) = @_;

    return(1) if ($cmd eq $EMPTY_STR);

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
	if ($cmd =~ /$re/x) {
	    $rc = 1;
	    last;
	}
    }

    return($rc);
}


#
# Same as Linux shell command "touch".  Mostly taken from
# ExtUtils::Command but operates on input argument and
# does not call the die() function on error.
#
# Returns
#   1 on success
#   0 of failure
#
sub touch
{
    my (@files) = @_;

    my $atime = time;
    my $mtime = $atime;
    my $rc = 0;

    foreach my $file (@files) {
        if (open(my $tfh, '>>', $file)) {
	    close($tfh) or warn "[touch] could not close file $file: $OS_ERROR\n";
	    utime($atime, $mtime, $file);
	    $rc = 1;
	}
    }

    return($rc);
}


########################################################################
#
# Some notes on the difference between RHEL5/RHEL6 vs RHEL7
# system service administration.
#
# Stop $service:                         systemctl stop $service
# Start $service:                        systemctl start $service
# Restart $service (stops/starts):       systemctl restart $service
# Reload $service (reloads config file): systemctl reload $service
# List status of $service:               systemctl status $service
#
# chkconfig $service on:  systemctl enable $service
# chkconfig $service off: systemctl disable $service
# chkconfig $service:     systemctl is-enabled $service
# chkconfig –list:        systemctl list-unit-files --type=service
#
########################################################################

#
# RTI system services are still the old style init.d type.
#
sub is_rti_system_service
{
    my ($service_name) = @_;

    my $rc = 0;

    my %rti_system_service_table = (
	rti => 1,
	blm => 1,
	bbj => 1,
    );

    if ( defined($rti_system_service_table{$service_name}) ) {
	$rc = 1;
    }

    return($rc);
}


sub is_service_configured
{
    my ($service_name) = @_;

    my $rc = 1;

    if ($OS eq 'RHEL5' || $OS eq 'RHEL6' || is_rti_system_service($service_name)) {
	if (system("/sbin/chkconfig --list $service_name 2>> $LOGFILE_PATH") != 0) {
	    $rc = 0;
	}
    }
    elsif ($OS eq 'RHEL7') {
	if (system("/usr/bin/systemctl -q is-enabled $service_name 2>> $LOGFILE_PATH") != 0) {
	    $rc = 0;
	}
    }

    return($rc);
}


sub tfmp_system_service_enable
{
    my ($service_name) = @_;

    my $rc = 1;

    if ($OS eq 'RHEL5' || $OS eq 'RHEL6' || is_rti_system_service($service_name)) {
	if (system("/sbin/chkconfig $service_name on >> $LOGFILE_PATH 2>> $LOGFILE_PATH") != 0) {
	    $rc = 0;
	}
    }
    elsif ($OS eq 'RHEL7') {
	if (system("/usr/bin/systemctl enable $service_name 2>> $LOGFILE_PATH") != 0) {
	    $rc = 0;
	}
    }

    return($rc);
}


sub tfmp_system_service_start
{
    my ($service_name) = @_;

    my $rc = 1;

    if ($OS eq 'RHEL5' || $OS eq 'RHEL6' || is_rti_system_service($service_name)) {
	if (system("/sbin/service $service_name start 2>> $LOGFILE_PATH") != 0) {
	    $rc = 0;
	}
    }
    elsif ($OS eq 'RHEL7') {
	if (system("/usr/bin/systemctl start $service_name 2>> $LOGFILE_PATH") != 0) {
	    $rc = 0;
	}
    }

    return($rc);
}


sub tfmp_system_service_stop
{
    my ($service_name) = @_;

    my $rc = 1;

    if ($OS eq 'RHEL5' || $OS eq 'RHEL6' || is_rti_system_service($service_name)) {
	if (system("/sbin/service $service_name stop 2>> $LOGFILE_PATH") != 0) {
	    $rc = 0;
	}
    }
    elsif ($OS eq 'RHEL7') {
	if (system("systemctl stop $service_name 2>> $LOGFILE_PATH") != 0) {
	    $rc = 0;
	}
    }

    return($rc);
}


sub logfile_setup
{
    #
    # make the default logfile name from the program name
    #
    # remove the extension from the name of the script and
    # then append the new extension.
    #
    my $LOGFILE_NAME_DEF = $PROGNAME;
    $LOGFILE_NAME_DEF =~ s{\.[^.]+$}{};
    $LOGFILE_NAME_DEF = $LOGFILE_NAME_DEF . '.log';

    # --logfile=path
    #
    # There are several possibilities:
    #   1) the default location and name
    #   2) path to the logfile was specified on the command line
    #   3) if $RTIDIR/log does not exist use "/tmp" for location
    #
    #my $ISO8601 = strftime("%Y%m%d", localtime());
    #my $LOGFILE_NAME = sprintf($LOGFILE_NAME_DEF, $ISO8601);
    my $LOGFILE_NAME = $LOGFILE_NAME_DEF;
    if ($LOGFILE_PATH) {
	if (is_input_insecure($LOGFILE_PATH)) {
	    print "[logfile_setup] insecure value for \$LOGFILE: $LOGFILE_PATH\n";
	    exit($EXIT_COMMAND_LINE);
	}
    }
    else {
	my $logfiledir = '/tmp';

	if (-d "$RTIDIR/log") {
	    $logfiledir= "$RTIDIR/log";
	}
	if (-d "$DAISYDIR/log") {
	    $logfiledir= "$DAISYDIR/log";
	}

	$LOGFILE_PATH = "$logfiledir/$LOGFILE_NAME";
    }

    # should never get here with $LOGFILE undefined, but...
    if ($LOGFILE_PATH eq $EMPTY_STR) {
	$LOGFILE_PATH = "/tmp/$LOGFILE_NAME";
    }
    touch($LOGFILE_PATH);

    return(1);
}


# Output to screen, and write info to logfile.
sub showinfo
{
    my ($message) = @_;

    chomp $message;
    print "$message\n";

    return(loginfo($message));
}


# Output to screen, and write error to logfile.
sub showerror
{
    my ($message) = @_;

    chomp $message ;
    print "error: $message\n" ;

    return(logerror($message));
}


sub loginfo
{
    my ($message) = @_;

    chomp $message;

    return(logit("<I>  $message"));
}


sub logerror
{
    my ($message) = @_;

    chomp $message;

    return(logit("<E>  error: $message"));
}


sub logit
{
    my ($message) = @_;

    my $logtime = strftime('%Y-%m-%d %H:%M:%S', localtime());

    chomp($message);
    if (open(my $logfh, '>>', $LOGFILE_PATH)) {
	print {$logfh} "$logtime ($PROGNAME-$PID) $message\n";
	close($logfh) or warn "[logit] could not close file $LOGFILE_PATH: $OS_ERROR\n";
    }
    else {
	print "$logtime ($PROGNAME-$PID) $message\n";
    }

    if ($VERBOSE) {
	print "$message\n";
    }

    return(1);
}


###################################
####### TFRSYNC MODULE SUBS #######
###################################

#
# search file for regular expression.
#
# Returns
#   0 found regular expression
#   1 did not find regular expression
#
sub tfrm_fgrep
{
    my ($file, $re) = @_;

    my $rc = 1;
    if (open(my $fp, '<', $file)) {
	while (<$fp>) {
	    chomp;
	    if (/$re/) {
		$rc = 0;
		last;
	    }
        }
	close($fp) or warn "[tfrm_fgrep] could not close file $file: $OS_ERROR\n";
    }

    return($rc);
}


#
# Given an account name, return path to home directory.
#
# Returns
#   path to home dir if account exists
#   empty string if account does NOT exist
#
sub tfrm_accounts_homedir
{
    my ($account_name) = @_;

    my $homedir_path = (getpwnam($account_name))[7];
    if (!defined($homedir_path)) {
	$homedir_path = $EMPTY_STR;
    }

    return($homedir_path);
}


#
# make the dir at the given path
#
# Returns
#   1 on success
#   0 if error
#
sub tfrm_util_mkdir
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


############################################
##                                        ##
## subsection: "pathto" and "nameof" subs ##
##                                        ##
############################################

sub tfrm_pathto_project_bu_dir
{
    return($RTI_RSYNC_BU_DIR) if ($RTI);
    return($DAISY_RSYNC_BU_DIR) if ($DAISY);
    return($EMPTY_STR);
}


sub tfrm_pathto_users_info_bu_dir
{
    my $bu_dir = tfrm_pathto_project_bu_dir();
    return($bu_dir . q{/} . $USERS_INFO_BU_DIR) if ($bu_dir);
    return($EMPTY_STR);
}


#
# Given an account name, return the path to production server
# transfer dir.
#
# Returns
#   path to xfer dir on success
#   empty string on error
#
sub tfrm_pathto_pserver_xferdir
{
    my ($account_name) = @_;

    my $rc = $EMPTY_STR;

    my $homedir_path = tfrm_accounts_homedir($account_name);
    if ($homedir_path) {
	$rc = $homedir_path . q{/} . $PSERVER_XFER_DIR;
    }

    return($rc);
}


sub tfrm_pathto_pserver_info_dir
{
    return(tfrm_pathto_project_bu_dir() . q{/} . $PSERVER_INFO_DIR);
}

sub tfrm_pathto_pserver_info_file
{
    return(tfrm_pathto_pserver_info_dir() . q{/} . $PSERVER_INFO_FILE);
}

sub tfrm_pathto_buserver_info_dir
{
    return(tfrm_pathto_project_bu_dir() . q{/} . $BUSERVER_INFO_DIR);
}

sub tfrm_pathto_buserver_info_file
{
    return(tfrm_pathto_buserver_info_dir() . q{/} . $BUSERVER_INFO_FILE);
}

sub tfrm_pathto_buserver_sysfiles_dir
{
    return(tfrm_pathto_project_bu_dir() . q{/} .  $BUSERVER_SYSFILES_DIR);
}

sub tfrm_pathto_pserver_cloister_dir
{
    return(tfrm_pathto_project_bu_dir() . q{/} . $PSERVER_CLOISTER_DIR);
}

sub tfrm_pathto_dove_server
{
    if ($RTI) {
	return($RTI_BINDIR . q{/} . $RTI_DOVE_SERVER_NAME);
    }
    else {
	return($EMPTY_STR);
    }
}

sub tfrm_pathto_saved_dove_server
{
    if ($RTI) {
	return(tfrm_pathto_pserver_cloister_dir() . tfrm_pathto_dove_server());
    }
    else {
	return($EMPTY_STR);
    }

}

sub tfrm_pathto_users_listing_file
{
    return(tfrm_pathto_users_info_bu_dir() . q{/} . $RTI_USERS_LISTING_FILE) if ($RTI);
    return(tfrm_pathto_users_info_bu_dir() . q{/} . $DAISY_USERS_LISTING_FILE) if ($DAISY);
    return($EMPTY_STR);
}


sub tfrm_pathto_users_shadow_file
{
    return(tfrm_pathto_users_info_bu_dir() . q{/} . $RTI_USERS_SHADOW_FILE) if ($RTI);
    return(tfrm_pathto_users_info_bu_dir() . q{/} . $DAISY_USERS_SHADOW_FILE) if ($DAISY);
    return($EMPTY_STR);
}


sub tfrm_pathto_pos_users_script
{
    return("$RTI_BINDIR/rtiuser.pl") if ($RTI);
    return("$DAISY_BINDIR/dsyuser.pl") if ($DAISY);
    return($EMPTY_STR);
}


#
# search the Samba conf file for the statement:
#   smb passwd file = <path>
# and return <path>.
#
# Returns
#   non-empty <path> if successful
#   empty string if not
#
sub tfrm_pathto_samba_passwd_file
{
    my ($conf_file) = @_;

    my $samba_pw_file_path = $EMPTY_STR;

    if (open(my $cfh, '<', $conf_file)) {
	while (<$cfh>) {
	    if (/^\s*smb\s+passwd\s+file\s*=\s*(\S*)\s*$/) {
		$samba_pw_file_path = $1;
	    }
	}
	close($cfh) or warn "[tfrm_pathto_samba_passwd_file] could not close file $conf_file: $OS_ERROR\n";
    }

    return($samba_pw_file_path);
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
sub tfmp_generate_server_info_file
{
    my ($info_file_path) = @_;

    my %server_info = ();

    my $rc = 0;

    if (tfmp_prepare_server_info_file(\%server_info)) {
	if (tfmp_write_server_info_file(\%server_info, $info_file_path)) {
	    loginfo("server info file written: $info_file_path");

	    $rc = 1;
	}
	else {
	    showerror("error writing server info file: $info_file_path");
	}
    }
    else {
	showerror("error preparing contents of server info file: $info_file_path");
    }

    return($rc);
}


#
# prepare info for the server info file by
# putting it into the specified hash ref.
#
# Returns
#   1 on success
#   0 on error
#
sub tfmp_prepare_server_info_file
{
    my ($server_info_ref) = @_;

    my $rc = 0;

    my $ip_addr = get_ip_address();
    if ($ip_addr) {
	loginfo("ip addr of primary network device: $ip_addr");
	my $netmask = get_netmask();
	if ($netmask) {
	    loginfo("netmask of primary network device: $netmask");
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
		showerror('error getting ip addr of gateway');
	    }
	}
	else {
	    logerror('error getting netmask for primary network device');
	}
    }
    else {
	logerror('error getting ip addr for primary network device');
    }

    return($rc);
}


#
# write server info to the specified path.
#
# Returns
#   1 on success
#   0 on error
#
sub tfmp_write_server_info_file
{
    my ($server_info_ref, $info_file) = @_;

    my $rc = 0;

    if (open(my $fh, '>', $info_file)) {

	print {$fh} "$SERVER_INFO_PLATFORM=$server_info_ref->{$SERVER_INFO_PLATFORM}\n";
	print {$fh} "$SERVER_INFO_HOSTNAME=$server_info_ref->{$SERVER_INFO_HOSTNAME}\n";
	print {$fh} "$SERVER_INFO_IPADDR=$server_info_ref->{$SERVER_INFO_IPADDR}\n";
	print {$fh} "$SERVER_INFO_NETMASK=$server_info_ref->{$SERVER_INFO_NETMASK}\n";
	print {$fh} "$SERVER_INFO_GATEWAY=$server_info_ref->{$SERVER_INFO_GATEWAY}\n";

	close($fh) or warn "[tfmp_write_server_info_file] could not close file $info_file: $OS_ERROR\n";

	loginfo("server info file generated: $info_file");

	$rc = 1;
    }
    else {
	showerror("error opening server info file: $info_file");
    }

    return($rc);
}


sub tfmp_read_server_info_file
{
    my ($server_info_ref, $info_file) = @_;

    my $label = 'tfmp_read_server_info_file';
    my $rc = 0;

    if (open(my $fh, '<', $info_file)) {
	my $line_count = 0;
	while (my $line = <$fh>) {
	    $line_count++;
	    chomp($line);
	    #
	    # extract key name and value from line
	    # then lookup the name in table and
	    # if found, save value
	    #
	    if ($line =~ /^(.+)=(.+)$/) {
		if ($SERVER_INFO_KEYS{$1}) {
		    $server_info_ref->{$1} = $2;
		}
		else {
		    logerror("[$label] unknown key in info file at line $line_count: $info_file");
		}
	    }
	}
	close($fh) or warn "[$label] could not close server info file: $info_file ($OS_ERROR)\n";
	$rc = 1;
    }
    else {
	logerror("[$label] could not open server info file: $info_file ($OS_ERROR)");
    }

    return($rc);
}


sub tfmp_getfield_server_info_file
{
    my ($key, $info_file_path) = @_;

    my %server_info = ();
    my $rc = $EMPTY_STR;

    if (tfmp_read_server_info_file(\%server_info, $info_file_path)) {
	$rc = $server_info{$key};
    }

    return($rc);
}


###################################
####### TOP LEVEL TEST SUBS #######
###################################

sub try_test_routines
{
    if ($TEST_ADD_USERS) {
	exit(tfmp_test_restore_users($TEST_CONF_FILE));
    }

    if ($TEST_RESTORE_PASSWDS) {
	exit(tfmp_test_restore_passwords($TEST_CONF_FILE));
    }

    if ($TEST_SAMBA_GET_PASSWORD_BACKEND) {
	exit(tfmp_test_get_samba_passwd_backend($TEST_CONF_FILE));
    }

    if ($TEST_SAMBA_SET_PASSWORD_BACKEND) {
	exit(tfmp_test_set_samba_passwd_backend($TEST_CONF_FILE));
    }

    if ($TEST_SAMBA_GET_UIDS) {
	exit(tfmp_test_get_uids($TEST_CONF_FILE));
    }

    if ($TEST_SAMBA_SYNC_PASSWORD_UIDS) {
	exit(tfmp_test_samba_sync_password_uids($TEST_CONF_FILE, $TEST_PW_FILE));
    }

    if ($TEST_GENERATE_BUSERVER_INFO_FILE) {
	my $server_info_dir_path = tfrm_pathto_buserver_info_dir();
	if (tfrm_util_mkdir($server_info_dir_path)) {
	    exit(tfmp_generate_server_info_file($TEST_CONF_FILE));
	}
	else {
	    exit($EXIT_MKDIR_SERVER_INFO_DIR);
	}
    }

    if ($TEST_GETFIELD_INFO_FILE) {
	exit(tfmp_test_getfield_info_file($TEST_GETFIELD_INFO_FILE, $TEST_CONF_FILE));
    }

    return($EXIT_OK);
}


sub tfmp_test_restore_users
{
    my ($users_file) = @_;

    my $rc = $EXIT_OK;

    if ($users_file) {
	if (tfmp_restore_pos_users($users_file)) {
	    print "normal users added from: $users_file\n";
	}
	else {
	    print "error: could not restore POS users from: $users_file\n";
	    $rc = $EXIT_TEST_USERS_RESTORE;
	}
    }
    else {
	print "error: specify path to users file: --test-users-file=path\n";
	$rc = $EXIT_TEST_USERS_FILE;
    }

    return($rc);
}


sub tfmp_test_restore_passwords
{
    my ($shadow_file) = @_;

    my $rc = $EXIT_OK;

    if ($shadow_file) {
	if (tfmp_restore_passwords($shadow_file)) {
	    print "passwords for POS users restored from: $shadow_file\n";
	}
	else {
	    print "error: could not restore passwords for POS users in: $shadow_file\n";
	    $rc = $EXIT_TEST_USERS_RESTORE;
	}
    }
    else {
	print "error: could not get path to POS users shadow file\n";
	    $rc = $EXIT_TEST_USERS_FILE;
    }

    return($rc);
}


sub tfmp_test_get_samba_passwd_backend
{
    my ($conf_file) = @_;

    my $samba_passwd_backend = tfrm_get_samba_passwd_backend($conf_file);
    if ($samba_passwd_backend) {
	print "Samba passwd backend configured for: <$samba_passwd_backend>\n";
    }
    else {
	print "Samba passwd backend unconfigured\n";
    }

    return($EXIT_OK);
}


sub tfmp_test_set_samba_passwd_backend
{
    my ($conf_file) = @_;

    my $new_conf_file = $conf_file . q{_} . $PID;
    if (tfmp_set_samba_passwd_backend($conf_file, $new_conf_file)) {
	print "Samba password backend config changed to: smbpasswd\n";
    }
    else {
	print "Samba password backend config unchanged\n";
    }

    return($EXIT_OK);
}


sub tfmp_test_get_uids
{
    my ($conf_file) = @_;

    my %uids = ();
    if (tfrm_get_uids($conf_file, \%uids)) {
	foreach my $key (keys(%uids)) {
	    print "account $key has uid: $uids{$key}\n";
	}
    }
    else {
	print "error: could not get system uids from: $conf_file\n";
    }

    return($EXIT_OK);
}


sub tfmp_test_samba_sync_password_uids
{
    my ($conf_file, $pw_file) = @_;

    my %uids = ();
    if (tfrm_get_uids($pw_file, \%uids)) {
	my $samba_pw_file = tfrm_pathto_samba_passwd_file($conf_file);
	if ($samba_pw_file) {
	    my $new_samba_pw_file = $samba_pw_file . q{_} . $PID;
	    if (tfmp_samba_rebuild_passdb($samba_pw_file, $new_samba_pw_file, \%uids)) {
	    }
	    else {
		print "error: could not sync uids in samba passwd file: $samba_pw_file\n";
	    }
	}
	else {
	    print "error: could not get path to samba passwd file from: $conf_file\n";
	}
    }
    else {
	print "error: could not get system uids from: $pw_file\n";
    }

    return($EXIT_OK);
}


sub tfmp_test_getfield_info_file
{
    my ($key, $info_file) = @_;

    my $rc = $EXIT_OK;

    my $info_file_value = tfmp_getfield_server_info_file($key, $info_file);
    if ($info_file_value) {
	print "info file field value = $info_file_value\n";
    }
    else {
	$rc = $EXIT_INFO_FILE_GET;
    }

    return($rc);
}


#
# read file of users, fill in supplied hash.
# keys of hash are user names, value of hash
# refects normal user or admin user.
#
# Returns
#   1 if successful
#   0 on error
#
sub tfrm_read_users_listing_file
{
    my ($users_file, $users_ref) = @_;

    my $rc = 1;

    my $admin_re = ($RTI) ? 'RTI Admin' : 'Daisy Admin';

    if (open(my $uf_fh, '<', $users_file)) {
	while (my $line = <$uf_fh>) {
	    if ($line =~ /^(\S+)\s.*$admin_re/) {
		$users_ref->{$1} = $USER_TYPE_ADMIN;
	    }
	    elsif ($line =~ /^(\S+)\s/) {
		$users_ref->{$1} = $USER_TYPE_NONADMIN;
	    }
	}
	close($uf_fh) or warn "[tfrm_read_users_listing_file] could not close file $users_file: $OS_ERROR\n";

	if (keys(%{$users_ref}) == 0) {
	    logerror("users file empty: $users_file");
	    $rc = 0;
	}

    }
    else {
	logerror("could not open users file: $users_file");
	$rc = 0;
    }

    return($rc);
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
sub tfrm_read_users_shadow_file
{
    my ($shadow_file, $shadow_ref) = @_;

    my $rc = 1;

    my $line;

    if (open(my $us_fh, '<', $shadow_file)) {
	while ($line = <$us_fh>) {
	    my $i = index($line, q{:});
	    my $username = substr($line, 0, $i);
	    $shadow_ref->{$username} = $line;
	}
	close($us_fh) or warn "[tfrm_read_users_shadow_file] could not close file $shadow_file: $OS_ERROR\n";
    }
    else {
	logerror("could not open users shadow file: $shadow_file");
    }

    return($rc);
}


#
# replace an existing conf file with a new one.
#
# if the new conf file exists and is non-zero sized, call
# it good and replace the existing one with the new one.
#
# Returns
#   1 if successful
#   0 on error
#
sub tfrm_replace_conf_file
{
    my ($conf_file, $new_conf_file) = @_;

    my $rc = 1;

    if (-s $new_conf_file) {
	system("chmod --reference=$conf_file $new_conf_file");
	system("chown --reference=$conf_file $new_conf_file");
	system("cp $new_conf_file $conf_file");
    }
    else {
	if (-e $new_conf_file) {
	    unlink($new_conf_file);
	}
	$rc = 0;
    }

    return($rc);
}


sub tfrm_get_uids
{
    my ($passwd_file, $system_uids) = @_;

    my $rc = 0;

    if (open(my $pdfh, '<', $passwd_file)) {
	while (<$pdfh>){
	    my ($name,$passwd,$uid,$gid,$gcos,$dir,$shell) = split(/:/);
	    $system_uids->{$name} = $uid;
	}
	close($pdfh) or warn "[tfrm_get_uids] could not close file $passwd_file: $OS_ERROR\n";
	$rc = 1;
    }

    return($rc);
}


#
# parse Samba conf file looking for this statement:
#
#	passdb backend = <backend_type>
#
sub tfrm_get_samba_passwd_backend
{
    my ($conf_file) = @_;

    my $samba_passwd_backend = $EMPTY_STR;

    if (open(my $cfh, '<', $conf_file)) {
	while (<$cfh>) {
	    if (/^\s*passdb\s+backend\s*=\s*([[:alpha:]]+)/) {
		$samba_passwd_backend = $1;
	    }
	}
	close($cfh) or warn "[tfrm_get_samba_passwd_backend] could not close file $conf_file: $OS_ERROR\n";
    }
    return($samba_passwd_backend);
}


#
# restore POS uses from users listing file.
#
sub tfmp_restore_pos_users
{
    my ($users_file) = @_;

    my $rc = 1;
    my %users = ();

    if (tfrm_read_users_listing_file($users_file, \%users)) {
	my $users_cmd = tfrm_pathto_pos_users_script();

	foreach my $key (keys(%users)) {
	    system("$users_cmd --add $key 2>> $LOGFILE_PATH");
	    if ($? == 0) {
		loginfo("POS user added: $key");
		if ($users{$key} eq $USER_TYPE_ADMIN) {
		    system("$users_cmd --enable-admin $key password 2>> $LOGFILE_PATH");
		    if ($? == 0) {
			loginfo("admin mode enabled for POS user: $key");
		    }
		    else {
			logerror("could not enable admin mode for: $key");
			$rc = 0;
			last;
		    }
		}
	    }
	    else {
		logerror("could not add POS user: $key");
		$rc = 0;
		last;
	    }
	}
    }
    else {
	logerror("could not read users listing file: $users_file");
	$rc = 0;
    }

    return($rc);
}


sub tfmp_restore_passwords
{
    my ($shadow_file) = @_;

    my $rc = 0;

    my %users_shadow = ();
    if (tfrm_read_users_shadow_file($shadow_file, \%users_shadow)) {

	my $conf_file = '/etc/shadow';
	my $new_conf_file = "$conf_file.$PID";

	if (open(my $old_fh, '<', $conf_file)) {
	    if (open(my $new_fh, '>', $new_conf_file)) {
		while (my $line = <$old_fh>) {
		    my $i = index($line, q{:});
		    my $username = substr($line, 0, $i);
		    if (defined($users_shadow{$username})) {
			print {$new_fh} "$users_shadow{$username}";
		    }
		    else {
			print {$new_fh} "$line";
		    }
		}
		close($new_fh) or warn "[tfmp_restore_passwords] could not close file $new_conf_file: $OS_ERROR\n";
	    }
	    else {
		logerror("could not open new shadow file: $new_conf_file");
	    }
	    close($old_fh) or warn "[tfmp_restore_passwords] could not close file $conf_file: $OS_ERROR\n";

	    if (-s $new_conf_file) {
		system("chmod --reference=$conf_file $new_conf_file");
		system("chown --reference=$conf_file $new_conf_file");
		system("mv $new_conf_file $conf_file");
		$rc = 1;
	    }
	    else {
		unlink $new_conf_file;
		logerror("could not update shadow file: $new_conf_file");
	    }
	}
	else {
	    logerror("could not open shadow file: $conf_file");
	}
    }

    return($rc);
}


#
# set the "passdb backend"  parameter to a value of "smbpasswd".
# in the "global" section.
#
# this must be done for RHEL6/7 systems to be backwards compatabile
# with the way the pre-RHEL6/7 systems were configured.
#
sub tfmp_set_samba_passwd_backend
{
    my ($conf_file, $new_conf_file) = @_;

    my $parameter = 'passdb backend = smbpasswd';
    my $parameter2 = 'smb passwd file = /etc/samba/smbpasswd';

    my $rc = 1;

    #
    # Copy all lines from old to new, but immediately after the
    # global section declaraion, write the new parameter(s) into
    # the new conf file.
    #
    if (open(my $old_fh, '<', $conf_file)) {
	if (open(my $new_fh, '>', $new_conf_file)) {
	    while (<$old_fh>) {
		if (/^\s*\[global\]/) {
		    print {$new_fh} $_;
		    print {$new_fh} "#Following lines added by $PROGNAME, $CVS_REVISION, $TIMESTAMP\n";
		    print {$new_fh} "$parameter\n";
		    print {$new_fh} "$parameter2\n";
		    next;
		}
		else {
		    print {$new_fh} $_;
		}
	    }
	    close($new_fh) or warn "[tfmp_set_samba_passwd_backend] could not close file $new_conf_file: $OS_ERROR\n";

	}
	else {
	    showerror("could not open new Samba config file: $new_conf_file");
	    $rc = 0;
	}
	close($old_fh) or warn "[tfmp_set_samba_passwd_backend] could not close file $conf_file: $OS_ERROR\n";
    }
    else {
	showerror("could not open existing Samba config file: $conf_file");
	$rc = 0;
    }

    return($rc);
}


#
# convert an entry from the samba password file by
# substituting the samba uid with the current system uid.
#
sub tfmp_convert_samba_passdb_entry
{
    my ($line, $system_uids) = @_;

    my $rc = $line;

    if ($line =~ /^(\S+):(\d+):(.*)$/) {
	my $samba_username = $1;
	my $samba_uid = $2;
	my $remainder = $3;

	my $system_uid = $system_uids->{$samba_username};
	if (defined($system_uid)) {
	    if ($samba_uid ne $system_uid) {
		$rc = $samba_username . q{:} . $system_uid . q{:} . $remainder . "\n";
	    }
	}
    }

    return($rc);
}


#
# Make the UIDs in the "smbpasswd" file match those in /etc/passwd.
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
sub tfmp_samba_rebuild_passdb
{
    my ($conf_file, $new_conf_file, $system_uids) = @_;

    my $rc = 1;

    if (open(my $old_fh, '<', $conf_file)) {
	if (open(my $new_fh, '>', $new_conf_file)) {
	    while (<$old_fh>) {
		my $line = tfmp_convert_samba_passdb_entry($_, $system_uids);
		print {$new_fh} $line;
	    }
	    close($new_fh) or warn "[tfmp_samba_rebuild_passdb] could not close file $new_conf_file: $OS_ERROR\n";
	}
	else {
	    showerror("[tfmp_samba_rebuild_passdb] could not open new Samba config file: $new_conf_file");
	    $rc = 0;
	}
	close($old_fh) or warn "[tfmp_samba_rebuild_passdb] could not close file $conf_file: $OS_ERROR\n";
    }
    else {
	showerror("[tfmp_samba_rebuild_passdb] could not open existing Samba config file: $conf_file");
	$rc = 0;
    }

    return($rc);
}


sub tfmp_copy_system_file
{
    my ($file) = @_;

    my $rc = 0;

    my $src_dir = tfrm_pathto_project_bu_dir();
    if ( ($file eq '/var/spool/cron') || ($file eq '/etc/cron.d') ) {
	$src_dir .= '/' . $PSERVER_CLOISTER_DIR;
    }
    my $src_path = $src_dir . $file;
    if (-e $src_path) {
	if (-d $src_path) {
	    if (system("cp -pr $src_path/* $file") == 0) {
		$rc = 1;
	    }
	}
	else {
	    if (system("cp -p $src_path $file") == 0) {
		$rc = 1;
	    }
	}
    }
    else {
	logerror("could not restore system file since it does not exist: $src_path ");
    }

    return($rc);
}


sub tfmp_restore_select_system_files
{
    my $rc = 1;

    my @system_files = qw(
	/etc/samba/smb.conf
	/etc/samba/smbpasswd
	/etc/inittab
	/etc/hosts
	/etc/hosts.allow
	/etc/hosts.deny
	/etc/resolv.conf
	/etc/sysconfig/iptables
	/var/spool/cron
	/etc/cron.d
	/etc/mail
	/home
    );

    my $info_file_path = tfrm_pathto_pserver_info_file();
    my $pserver_platform = tfmp_getfield_server_info_file($SERVER_INFO_PLATFORM, $info_file_path);
    if ($pserver_platform) {
	foreach my $file (@system_files) {
	    if (($file eq '/etc/inittab') && ($pserver_platform ne $OS)) {
		loginfo("file restore not required: $file");
		next;
	    }

	    if (tfmp_copy_system_file($file)) {
		loginfo("system file restored: $file");
	    }
	    else {
		logerror("could not restore file: $file");
		$rc = 0;
		last;
	    }
	}
    }
    else {
	logerror('could not determine production server platform');
	$rc = 0;
    }

    return($rc);
}



#############################################
#########   A P P L I C A T I O N   #########
#############################################


sub tfmp_report_files
{
    my $rc = $EXIT_OK;

    print "FILES\n";
    printf(" pserver info file = %s\n", tfrm_pathto_pserver_info_file());
    printf("buserver info file = %s\n", tfrm_pathto_buserver_info_file());
    printf("users listing file = %s\n", tfrm_pathto_users_listing_file());
    printf(" users shadow file = %s\n", tfrm_pathto_users_shadow_file());
    if ($RTI) {
	printf(" samba passwd file = %s\n", tfrm_pathto_samba_passwd_file('/etc/samba/smb.conf'));
    }

    if ($RTI) {
	print "\nSCRIPTS\n";
	printf("       dove server = %s\n", tfrm_pathto_dove_server());
	printf("    dove server bu = %s\n", tfrm_pathto_saved_dove_server());
    }

    print "\nDIRECTORIES\n";
    printf("               backup dir = %s\n", tfrm_pathto_project_bu_dir());
    printf("           users info dir = %s\n", tfrm_pathto_users_info_bu_dir());
    printf("         pserver info dir = %s\n", tfrm_pathto_pserver_info_dir());
    printf("     pserver cloister dir = %s\n", tfrm_pathto_pserver_cloister_dir());
    printf("        buserver info dir = %s\n", tfrm_pathto_buserver_info_dir());
    printf("buserver system files dir = %s\n", tfrm_pathto_buserver_sysfiles_dir());
    printf("     pserver transfer dir = %s\n", tfrm_pathto_pserver_xferdir($TFSUPPORT_ACCOUNT));

    return($rc);
}


#
# revert from production server to backup server.
#
# 0) verify platform
# 1) verify backup server info file exists
# 2) special files: remove doverserver.pl if RTI
# 3) system files: revert cron files
# 4) revert network settings
# 5) stop the Samba system service
# 6) stop rti, bbj, and blm system services
# 7) stop http system service
#
# Returns
#   $EXIT_OK on success
#   $EXIT_
#
sub tfmp_revert
{
    my $label = 'tfmp_revert';
    my $rc = $EXIT_OK;

    # 0) verify platform
    if ( !($OS eq 'RHEL5' || $OS eq 'RHEL6' || $OS eq 'RHEL7') ) {
	showerror("[$label] unsupported platform: $OS");
	return($EXIT_PLATFORM);
    }

    # 1) verify backup server info file exists
    my $info_file_path = tfrm_pathto_buserver_info_file();
    if (! -e $info_file_path) {
	showerror("[$label] backup server info file does not exist: $info_file_path");
	return($EXIT_PLATFORM);
    }

    # 2) special files: remove doverserver.pl if RTI
    if ($RTI) {
	my $dove_server_path = tfrm_pathto_dove_server();
	if (-e $dove_server_path) {
	    unlink $dove_server_path;
	    if (-e $dove_server_path) {
		showerror("[$label] could not remove dove server script: $dove_server_path");
		return($EXIT_DOVE_SERVER_RM);
	    }
	}
    }

    # 3) system files: revert cron files
    my $sysfiles_dir_path = tfrm_pathto_buserver_sysfiles_dir();
    if (-d $sysfiles_dir_path) {
	my @sysfiles_dirs = qw(
	    var/spool/cron
	    etc/cron.d
	);

	foreach my $dir (@sysfiles_dirs) {
	    system("cd $sysfiles_dir_path; tar cf - $dir 2> /dev/null | (cd / && tar xf -)");
	    if ($? == 0) {
		loginfo("[$label] backup server sysfiles reverted: $sysfiles_dir_path");
	    }
	    else {
		showerror("[$label] could not revert backup server sysfiles: $sysfiles_dir_path");
		return($EXIT_REVERT_SYSFILES);
	    }
	}
    }
    else {
	showerror("[$label] backup server sysfiles dir does not exist: $sysfiles_dir_path");
	return($EXIT_REVERT_SYSFILES);
    }

    # 4) revert network settings
    my %server_info = ();
    my $server_info_file_path = tfrm_pathto_buserver_info_file();
    if (tfmp_read_server_info_file(\%server_info, $server_info_file_path)) {
	if (tfmp_configure_network(\%server_info)) {
	    loginfo("[$label] network configured");
	}
	else {
	    showerror("[$label] could not change network configuration");
	    return($EXIT_NETWORK_CONFIG);
	}
    }
    else {
	showerror("[$label] could not read pserver info file");
	return($EXIT_NETWORK_CONFIG);
    }

    # 5), 6), 7) - stop the various system services
    my @service_names = qw(
	smb
	rti
	bbj
	blm
	httpd
    );

    foreach my $service_name (@service_names) {
	if (tfmp_system_service_stop($service_name)) {
	    loginfo("[$label] system service stopped: $service_name");
	}
	else {
	    logerror("[$label] could not stop system service: $service_name");
	    $rc = $EXIT_SERVICE_STOP;
	}
    }

    return($rc);
}


#
# Convert a backup server back into a production server
#
# 0) verify pre-requisites
# 1) save backup server config to server info file
# 2) save backup server system files
# 3) restore special files
# 4) restore system files
# 5) configure tcc
# 6) configure network
# 7) restore POS users
# 8) convert Samba
# 9) start RTI system services
#

sub tf_make_pserver
{
    my $label = 'tf_make_pserver';

    if (tfmp_verify_prereqs()) {
	loginfo("[$label] pre-requisites verified");
    }
    else {
	showerror("[$label] could not verify pre-requisites");
	return($EXIT_PREREQS);
    }

    my $server_info_dir_path = tfrm_pathto_buserver_info_dir();
    if (tfrm_util_mkdir($server_info_dir_path)) {
	my $info_file_path = tfrm_pathto_buserver_info_file();
	if (tfmp_generate_server_info_file($info_file_path)) {
	    loginfo("[$label] new backup server info file generated: $info_file_path");
	}
	else {
	    showerror("[$label] could not generate new backup server info file: $info_file_path");
	    return($EXIT_GEN_BSERVER_INFO_FILE);
	}
    }
    else {
	showerror("[$label] could not make backup server info dir: $server_info_dir_path");
	return($EXIT_MKDIR_SERVER_INFO_DIR);
    }

    my $sysfiles_dir_path = tfrm_pathto_buserver_sysfiles_dir();
    if (tfrm_util_mkdir($sysfiles_dir_path)) {
	my @dirs_to_save = qw(
	    /var/spool/cron
	    /etc/cron.d
	);

	foreach my $dir (@dirs_to_save) {
	    system("tar cf - $dir 2> /dev/null | (cd $sysfiles_dir_path && tar xf -)");
	    if ($? == 0) {
		loginfo("[$label] backup server files saved: $sysfiles_dir_path");
	    }
	    else {
		showerror("[$label] could not save backup server files: $sysfiles_dir_path");
		return($EXIT_SAVE_SYSFILES);
	    }
	}
    }
    else {
	showerror("[$label] could not make backup server sysfiles dir: $sysfiles_dir_path");
	return($EXIT_MKDIR_SYSFILES_DIR);
    }

    if (tfmp_restore_special_files()) {
	loginfo("[$label] special files restored");
    }
    else {
	showerror("[$label] could not restore special files");
	return($EXIT_RESTORING_SPECIAL_FILES);
    }

    if (tfmp_restore_system_files()) {
	loginfo("[$label] special backups restored");
    }
    else {
	showerror("[$label] could not restore special backups");
	return($EXIT_RESTORING_SYSTEM_FILES);
    }

    if (tfmp_configure_tcc()) {
	loginfo("[$label] tcc configured");
    }
    else {
	showerror("[$label] could not configure TCC");
	return($EXIT_TCC_CONFIG);
    }

    my %server_info = ();
    my $server_info_file_path = tfrm_pathto_pserver_info_file();
    if (tfmp_read_server_info_file(\%server_info, $server_info_file_path)) {
	if (tfmp_configure_network(\%server_info)) {
	    loginfo("[$label] network config converted from backup server to production server");
	}
	else {
	    showerror("[$label] could not change network config");
	    return($EXIT_NETWORK_CONFIG);
	}
    }
    else {
	showerror("[$label] could not read pserver info file");
	return($EXIT_NETWORK_CONFIG);
    }

    if (tfmp_restore_users_info()) {
	loginfo("[$label] POS users restored");
    }
    else {
	showerror("[$label] could not restore POS users");
	return($EXIT_RESTORING_USERS);
    }

    if (tfmp_change_samba_passwd_backend()) {
	if (tfmp_update_samba_passwd_file()) {
	    loginfo("[$label] Samba config updated");
	    system('/sbin/service smb restart');
	    loginfo("[$label] Samba system service restarted");
	}
	else {
	    showerror("[$label] could not change Samba password file");
	    return($EXIT_SAMBA_USERS);
	}

    }
    else {
	showerror("[$label] could not change Samba password backend");
	return($EXIT_SAMBA_PW_BACKEND);
    }

    if (tfmp_start_rti()) {
	loginfo("[$label] RTI started");
    }
    else {
	showerror("[$label] could not start RTI");
	return($EXIT_START_RTI);
    }

    return($EXIT_OK);
}


#
# verify pre-requisites
#
# -> supported platform?
# -> does production server info file exist?
# -> does /usr2/ostools exist? /d/ostools?
# -> does /usr2/bbx exist? /d/daisy?
# -> does /etc/init.d/rti exist?
# -> does /etc/init.d/bbj exist?
# -> does /etc/init.d/blm exist?
# -> do TCC components exist?
#
# Returns
#   1 on success
#   0 if error
#
sub tfmp_verify_prereqs
{
    my $rc = 1;

    if ( !($OS eq 'RHEL5' || $OS eq 'RHEL6' || $OS eq 'RHEL7') ) {
	showerror("[tfmp_verify_prereqs] unsupported platform: $OS");
	return($rc);
    }

    my $info_file_path = tfrm_pathto_pserver_info_file();
    if (-s $info_file_path) {
	my %server_info = ();
	if (tfmp_read_server_info_file(\%server_info, $info_file_path)) {
	    foreach my $key (keys(%SERVER_INFO_KEYS)) {
		if (! defined($server_info{$key})) {
		    showerror("[tfmp_verify_prereqs] missing server info file key: $key");
		    $rc = 0;
		    last;
		}
	    }
	}
	else {
	    showerror("[tfmp_verify_prereqs] could not read server info file: $info_file_path");
	    $rc = 0;
	}
    }
    else {
	showerror("[tfmp_verify_prereqs] server info file empty: $info_file_path");
	$rc = 0;
    }

    if (! -e $TOOLSDIR) {
	showerror("[tfmp_verify_prereqs] ostools dir does not exist: $TOOLSDIR");
	$rc = 0;
    }

    if ($RTI) {
	if (-e $RTIDIR) {
	    my @required_files = (
		# platform       file path          type
		[ 'any',         '/etc/init.d/rti', 'init script' ],
		[ 'any',         '/etc/init.d/bbj', 'init script' ],
		[ 'any',         '/etc/init.d/blm', 'init script' ],
		[ 'RHEL5',       $TCC_RHEL5_TCC2,   'TCC component' ],
		[ 'RHEL5',       $TCC_RHEL5_TCC,    'TCC component' ],
		[ 'RHEL6',       $TCC_RHEL6_TCC2,   'TCC component' ],
		[ 'RHEL6',       $TCC_RHEL6_TCC,    'TCC component' ],
		[ 'RHEL7',       $TCC_RHEL7_TCC2,   'TCC component' ],
		[ 'RHEL7',       $TCC_RHEL7_TCC,    'TCC component' ],
	    );
	    foreach my $idx (0 .. $#required_files) {

		next if ($required_files[$idx][0] ne 'any' && $required_files[$idx][0] ne $OS);

		if (! -e $required_files[$idx][1]) {
		    showerror("[tfmp_verify_prereqs] missing $required_files[$idx][2]: $required_files[$idx][1]");
		    $rc = 0;
		}
	    }
	}
	else {
	    showerror("[tfmp_verify_prereqs] RTI directory does not exist: $RTIDIR");
	    $rc = 0;
	}
    }
    if ($DAISY) {
	if (! -e $DAISYDIR) {
	    showerror("[tfmp_verify_prereqs] Daisy directory does not exist: $DAISYDIR");
	    $rc = 0;
	}
    }

    return($rc);
}


#
# restore special files, ie those that could not be
# backed up in place.
#
# 1) for rti, doveserver.pl
#
# Returns
#   1 on success
#   0 if error
#
sub tfmp_restore_special_files
{
    my $rc = 0;

    if ($RTI) {
	my $dove_server_path = tfrm_pathto_dove_server();
	if (-e $dove_server_path) {
	    showerror("Dove server script already exists: $dove_server_path");
	}
	else {
	    my $saved_dove_server_path = tfrm_pathto_saved_dove_server();
	    if (-e $saved_dove_server_path) {
		system("cp -p $saved_dove_server_path $dove_server_path");
		if ($? == 0) {
		    loginfo("Dove server script restored: $dove_server_path");
		    $rc = 1;
		}
		else {
		    showerror("restoration of Dove server script failed: $dove_server_path");
		}
	    }
	    else {
		showerror("saved Dove server script does not exist: $saved_dove_server_path");
	    }
	}
    }

    return($rc);
}


#
# restore appropriate system files and directories.
#
# Returns
#   1 on success
#   0 if error
#
sub tfmp_restore_system_files
{
    my $rc = 1;

    if (tfmp_restore_select_system_files()) {
	loginfo('system files restored');
    }
    else {
	showerror('could not restore system files');
	$rc = 0;
    }

    return($rc);
}

#
# configure tcc
#
# Returns
#   1 on success
#   0 if error
#
sub tfmp_configure_tcc
{
    my $rc = 1;

    if ($OS eq 'RHEL5') {
	system("ln -sf $TCC_RHEL5_TCC2 $TCC_TCC");
	system("ln -sf $TCC_RHEL5_TCC  $TCC_TCC_TWS");
    }

    elsif ($OS eq 'RHEL6') {
	system("ln -sf $TCC_RHEL6_TCC2 $TCC_TCC");
	system("ln -sf $TCC_RHEL6_TCC  $TCC_TCC_TWS");
    }

    elsif ($OS eq 'RHEL7') {
	system("ln -sf $TCC_RHEL7_TCC2 $TCC_TCC");
	system("ln -sf $TCC_RHEL7_TCC  $TCC_TCC_TWS");
    }

    if (-e $TCC_TCC && -e $TCC_TCC_TWS) {
	loginfo("TCC symlinks configured: $TCC_TCC, $TCC_TCC_TWS");
    }
    else {
	showerror("TCC symlink configuration: $TCC_TCC, $TCC_TCC_TWS");
    }

    return($rc);
}


#
# configure the network to match the production server.
#
# Returns
#   1 on success
#   0 if error
#
sub tfmp_configure_network
{
    my ($server_info) = @_;

    my $rc = 1;

    my $cmd = $TOOLSDIR . '/bin/updateos.pl';

    # only change the ip addr if "--keep-ip-addr" is NOT on the
    # command line.
    if ($KEEP_IP_ADDR == 0) {
	my $cmd_opts = " --ipaddr=$server_info->{$SERVER_INFO_IPADDR}";
	$cmd_opts .=   " --netmask=$server_info->{$SERVER_INFO_NETMASK}";
	$cmd_opts .=   " --gateway=$server_info->{$SERVER_INFO_GATEWAY}";
	loginfo("[tfmp_configure_network] cmd to change ip addr $cmd $cmd_opts");
	system("perl $cmd $cmd_opts");
	if ($? == 0) {
	    loginfo('[tfmp_configure_network] ip addr change successful');
	}
	else {
	    showerror("[tfmp_configure_network] could not change ip addr, command exit status: $?");
	    $rc = 0
	}
    }

    my $cmd_opts = " --hostname=$server_info->{$SERVER_INFO_HOSTNAME}";
    loginfo("[tfmp_configure_network] cmd to change hostname: $cmd $cmd_opts");
    system("perl $cmd $cmd_opts");
    if ($? == 0) {
	loginfo('[tfmp_configure_network] hostname change successful');
    }
    else {
	showerror("[tfmp_configure_network] could not change hostname, command exit status: $?");
	$rc = 0
    }

    my $system_service_name = 'network';
    loginfo("[tfmp_configure_network] restarting system service: $system_service_name");
    system("/sbin/service $system_service_name restart");

    return($rc);
}


#
# add any POS user accounts from users listing file
# if the accounts do not already exists, and update
# of they do.
#
# enable any admin accounts.
#
# sync up the passwords.
#
# Returns
#   1 if successful
#   0 on error
#
sub tfmp_restore_users_info
{
    my $rc = 0;

    my %users = ();
    my $users_file = tfrm_pathto_users_listing_file();
    if ($users_file) {
	if (tfmp_restore_pos_users($users_file, \%users)) {
	    loginfo("POS normal and admin users restored from: $users_file");
	    $rc = 1;
	}
	else {
	    showerror("could not restore POS users from: $users_file");
	}
    }
    else {
	showerror('could not get path to POS users listing file');
    }

    if ($rc) {
	my $shadow_file = tfrm_pathto_users_shadow_file();
	if ($shadow_file) {
	    if (tfmp_restore_passwords($shadow_file)) {
		loginfo("passwords for POS users restored: $shadow_file");
		$rc = 1;
	    }
	    else {
		showerror("could not restore passwords for POS users in: $shadow_file");
	    }
	}
	else {
	    showerror('could not get path to POS users shadow file');
	}
    }

    return($rc);
}


sub tfmp_change_samba_passwd_backend
{
    my $rc = 1;

    my $conf_file = '/etc/samba/smb.conf';

    if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	my $samba_passwd_backend = tfrm_get_samba_passwd_backend($conf_file);
	if ($samba_passwd_backend eq 'smbpasswd') {
	    loginfo('Samba already configured for smbpasswd');
	}
	else {
	    my $new_conf_file = $conf_file . q{_} . $PID;
	    if (tfmp_set_samba_passwd_backend($conf_file, $new_conf_file)) {
		if (tfrm_replace_conf_file($conf_file, $new_conf_file)) {
		    loginfo('Samba password backend config changed to: smbpasswd');
		}
		else {
		    showerror("could not replace conf file: $conf_file");
		    $rc = 0;
		}
	    }
	    else {
		showerror('could not change Samba password backend config to: smbpasswd');
		$rc = 0;
	    }
	}
    }

    return($rc);
}


sub tfmp_update_samba_passwd_file
{
    my $conf_file = '/etc/samba/smb.conf';
    my $rc = 0;

    my %uids = ();
    if (tfrm_get_uids('/etc/passwd', \%uids)) {
	my $samba_pw_file = tfrm_pathto_samba_passwd_file($conf_file);
	if ($samba_pw_file) {
	    my $new_samba_pw_file = $samba_pw_file . q{_} . $PID;
	    if (tfmp_samba_rebuild_passdb($samba_pw_file, $new_samba_pw_file, \%uids)) {
		if (tfrm_replace_conf_file($samba_pw_file, $new_samba_pw_file)) {
		    loginfo("Samba password file rebuilt: $samba_pw_file");
		    $rc = 1;
		}
		else {
		    showerror("could not replace conf file: $samba_pw_file");
		}
	    }
	    else {
		showerror("could not rebuild samba password database: $samba_pw_file");
	    }
	}
	else {
	    showerror("could not get path to samba password file: $conf_file");
	}
    }
    else {
	showerror('could not read passwd file');
    }

    return($rc);
}


#
# Start the RTI POS and it's dependencies.
#
# 0) start web server
# 1) start blm service
# 2) start bbj service
# 3) start rti service
#
# Returns
#   1 on success
#   0 if error
#
sub tfmp_start_rti
{
    my $label = 'tfmp_start_rti';

    my $rc = 1;

    my @rti_system_services = qw(
	blm
	bbj
	rti
    );

    if (is_service_configured('httpd')) {
	if (tfmp_system_service_start('httpd')) {
	    loginfo("[$label] system service started: httpd");
	}
	else {
	    logerror("[$label] could not start system service: httpd");
	    $rc = 0;
	}
    }
    else {
	showerror("[$label] http service is not configured");
	$rc = 0;
    }

    if ($rc) {
	foreach my $service_name (@rti_system_services) {
	    if (tfmp_system_service_enable($service_name)) {
		loginfo("[$label] system service enabled: $service_name");
	    }
	    else {
		logerror("[$label] could not enable system service: $service_name");
		$rc = 0;
		last;
	    }
	    if (tfmp_system_service_start($service_name)) {
		loginfo("[$label] system service started: $service_name");
	    }
	    else {
		logerror("[$label] could not start system service: $service_name");
		$rc = 0;
		last;
	    }
	}
    }

    return($rc);
}


__END__


#################################################
#########   D O C U M E N T A T I O N   #########
#################################################

=pod


=head1 NAME

I<tfmkpserver.pl> - Script to make a backup server into a production server.

=head1 VERSION

This documentation refers to version: $Revision: 1.32 $


=head1 SYNOPSIS

tfmkpserver.pl B<--help>

tkmkpserver.pl B<--version>

tkmkpserver.pl [B<--verbose>] [B<--dry-run>] [B<--logfile=path>] [B<--keep-ip-addr>] --convert

tkmkpserver.pl [B<--verbose>] [B<--dry-run>] [B<--logfile=path>] --revert

=begin comment

tkmkpserver.pl [B<--verbose>] [B<--dry-run>] [B<--logfile=path>] --report

=end comment

tkmkpserver.pl [B<--verbose>] [B<--dry-run>] [B<--logfile=path>] --report-files

=head1 DESCRIPTION

=head2 Overview

The F<tkmkpserver.pl> script is used to convert a backup server into
a production server.

=head2 Details

Here is a detailed outline of how F<tfmkpserver.pl>
converts the backup server to a production serverby performing

=over 4

=item 1.

The script verifies the following list of pre-requesites are fulfilled:

=over 4

=item a.

verify the platform is "RHEL5" or "RHEL6" or "RHEL7".

=item b.

verify that the "production server info file" is present and
contains values for each of the possible fields allowed.

=item c.

verify that the B<OSTools> package is installed.

=item d.

if RTI, verify that F</usr2> exists and is a directory.

=item e.

if RTI, verify that the RTI F</etc/init.d> scripts exist.

=item f.

if RTI, verify that the TCC package is installed.

=item g.

if Daisy, verify that F</d> exists and is a directory.

=back

=item 2.

restore special files like F</usr2/bbx/bin/doveserver.pl>.
The restoration involves renaming the file to it's actual name, and
setting the perms, owner, and group to there proper values.

=item 3.

restore a select set of system files from the production server,
for example, F</etc/samba/smb.conf>.

=item 4.

configure the TCC package as appropriate for the platform.

=item 5.

configure the network by setting the hostname, the ip addr,
the netmask, and the gateway ipaddr of the backup server
to that of the production server.

=item 6.

add any POS users from the production server to the backup server.

=item 7.

reconcile the UIDs in the Samba password file from the
production server with those in the password file of the
backup server.

=item 8.

Configure and start the RTI system services: http, bbj, blm, and rti.

The script exits with the exit status returned by F<tf_make_pserver()>.
See section on "EXIT STATUS" below for actual exit status values and
the the reason why each status would be reported.

=back

=head2 Command Line Options

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--verbose>

Modifier: report extra information.

=begin comment

=item B<--report>

Output a report of state of backup server.

=end comment

=item B<--report-files>

List paths to important files and directories.

=item B<--convert>

Convert a backup server to a production server.

=item B<--revert>

Revert a production server that had once been a backup server
back to being a backup server.

=item B<--logfile=path>

Specify path to log file.

=item B<--keep-ip-addr>

When converting from a backup server to a production server,
keep the current ip address of the backup server.

=item B<--dry-run>

Report what an operation would do but don't actually do it.

=item B<--debugmode>

If specified, run in debug mode.

=back


=head1 EXAMPLES

To list the locations of important files and directories,
enter the following:

 sudo tfmkpserver.pl --report-files


=head1 FILES

=over 4

=item F</usr2>

The top of the RTI filesystem.

=item F</usr2/tfrsync>

This directory contains files from the production system.

=item F</usr2/bbx>

The default RTI directory - this directory must exist and
contain a standard RTI POS installation.

=item F</usr2/bbx/log/tfmkpserver.log>

The log file produced by this script.

=back


=head1 EXIT STATUS

=over 4

=item Exit status 0 ($EXIT_OK)

Successful completion.

=item Exit status 1 ($EXIT_COMMAND_LINE)

In general, there was an issue with the syntax of the command line.

=item Exit status 2 ($EXIT_MUST_BE_ROOT)

The script must run as root or with sudo(1).

=item Exit status 10 ($EXIT_PREREQS)

One or more of the prerequisites could not be verified.
These "prereqs" include conditions like the platform the
script is running on, the installation of the OSTools package,
the existence of specific files, directories, and scripts, and
the existence of an installed POS, either RTI or Daisy.

=item Exit status 12 ($EXIT_START_RTI)

The RTI point of sales application could not be started.

=item Exit status 13 ($EXIT_TCC_CONFIG)

The TCC symlinks for RTI could not be configured.

=item Exit status 14 ($EXIT_NETWORK_CONFIG)

The network configuration of the backup server could not
be changed to that of the production server.

=item Exit status 15 ($EXIT_RESTORING_SPECIAL_FILES)

The set of files requiring special handling could not be restored.
Examples include F<doveserver.pl>.

=item Exit status 16 ($EXIT_RESTORING_USERS)

The set of POS users from the production server and their info
such as passwords, could not be restored on the backup server.

=item Exit status 17 ($EXIT_SAMBA_PW_BACKEND)

The Samba password backend configuration could not be updated
on a RHEL6 or RHEL7 system.

=item Exit status 18 ($EXIT_SAMBA_USERS)

The Samba B<uid> values in the Samba password file could not be updated.

=item Exit status 19 ($EXIT_RESTORING_SYSTEM_FILES)

The backup sets that could not be stored "in place" could
not be copied into place.

=item Exit status 20 ($EXIT_MKDIR_SERVER_INFO_DIR)

Could not mkdir the server info directory.

=item Exit status 21 ($EXIT_GEN_BSERVER_INFO_FILE)

Could not generate a new backup server info file.

=back


=head2 SEE ALSO

I<tfrsync.pl>


=cut
