#!/usr/bin/perl
#
# $Revision: 1.352 $
# Copyright 2009-2017 Teleflora
#
# Script to update / install Daisy onto either an existing or new daisy system.
#


use strict;
use warnings;
use English qw( -no_match_vars );
use POSIX;
use Getopt::Long;
use File::Spec;
use File::Basename;
use File::stat;
use Digest::MD5;
use Cwd;

my $CVS_REVISION = '$Revision: 1.352 $';
my $PROGNAME = basename($0);

#
# Command line options
#
my $HELP = "";
my $VERSION = 0;
my $COUNTRY = "us";
my $FORCE= "";
my $VERBOSE = "";
my $LINKDATA = "";
my $PREV_DAISY_VERSION = "";
my $PRESERVE_OSTOOLS = 0;
my $SKIP_SPACE_CHECK = 0;
my $SPACE_CHECK_ONLY = 0;
my $ROTATE_KEYS = 1;
my $DAISY92_DATA_CONVERSION = 1;
my $CONFIG_AUDIT_SYSTEM = 0;
my $CHECK_ARGS_ONLY = 0;

#
# Globals
#
my $EMPTY_STR   = q{};
my $OS = "Linux";
my $ALTOS = "";
my $MAJOR_VERSION="10";
my $MINOR_VERSION="0";
my $BUILD_VERSION="29";
my $DAISY_VERSION = "$MAJOR_VERSION.$MINOR_VERSION.$BUILD_VERSION";

my $SOURCEROOT = "";
my $DESTROOT = "";
my $PREVIOUSROOT= "";
my $SAVEDROOT = "";
my $SOURCE_INSTALL_FILES_DIR = "";
my $SOURCE_UTILS_DIR = "";
my $DATESTAMP = strftime "%Y%m%d", localtime;
my $TIMESTAMP = $DATESTAMP . strftime "%H%M", localtime;

#
# Install types consist of:
#	new
#	upgrade
#	forced upgrade
#	data_only
#
my $INSTALL_TYPE = "";

my $ENCRYPTED_TAR_FILE = "";
my $LOGFILE = "";
my $INSTALL_CMD = "install --owner=daisy --preserve-timestamps";
my $errors = "";
my $destdir = "";
my $strerror = "";
my $TFSERVER = "rtihardware.homelinux.com";

# Linux audit system config file for Daisy
my $DAISY_AUDIT_SYSTEM_CONFIG_DIR  = '/etc/audit/rules.d';
my $DAISY_AUDIT_SYSTEM_CONFIG_FILE = 'daisy.rules';
my $DAISY_AUDIT_SYSTEM_CONFIG_PATH =
    File::Spec->catdir($DAISY_AUDIT_SYSTEM_CONFIG_DIR, $DAISY_AUDIT_SYSTEM_CONFIG_FILE);

#
# When upgrading a Daisy installation, for any version of Daisy less than a minimum
# specified by $MIN_DSY_MAJOR_VERSION, the root password should be set to expire,
# forcing password change for the next login on the root account.
#
my $MIN_DSY_MAJOR_VERSION = 8;
my $DSY_MAJOR_VERSION = 0;

#
# Exit status values
#
my $EXIT_OK = 0;
my $EXIT_COMMAND_LINE = 1;
my $EXIT_MUST_BE_ROOT = 2;
my $EXIT_FORCE_REQ = 3;
my $EXIT_DISK_SPACE = 4;
my $EXIT_INSTALL_FILES = 5;
my $EXIT_PLATFORM = 6;
my $EXIT_STOP_DAISY = 9;
my $EXIT_START_DAISY = 10;
my $EXIT_BACKUP_FAILED = 11;
my $EXIT_OSTOOLS_DOWNLOAD = 12;
my $EXIT_OSTOOLS_INSTALL = 13;
my $EXIT_INTERNET = 14;



#############
### Main  ###
##########################################################################################

my $COMMAND_LINE = get_command_line();

#
# Gather up command line... exit if error.
#
GetOptions(
	'help' => \$HELP, 
	'version' => \$VERSION,
	'previous=s' => \$PREV_DAISY_VERSION,
	'force' => \$FORCE, 
	'verbose' => \$VERBOSE, 
	'linkdata' => \$LINKDATA, 
	'country=s' => \$COUNTRY,
	'preserve-ostools' => \$PRESERVE_OSTOOLS,
	'skip-space-check' => \$SKIP_SPACE_CHECK,
	'space-check-only' => \$SPACE_CHECK_ONLY,
	'rotate-keys!' => \$ROTATE_KEYS,
	'daisy92-data-conversion!' => \$DAISY92_DATA_CONVERSION,
	'config-audit-system' => \$CONFIG_AUDIT_SYSTEM,
	'check-args-only' => \$CHECK_ARGS_ONLY,
) or exit($EXIT_COMMAND_LINE);

#
# if configuration of audit system was NOT specified on command line,
# maybe it was in the environment.  Value of command line takes
# prescedence.
#
if ($CONFIG_AUDIT_SYSTEM == 0) {
    my $env_value = $ENV{'DAISY_CONFIG_AUDIT_SYSTEM'};
    if (defined($env_value)) {
	if ($env_value == 1) {
	    $CONFIG_AUDIT_SYSTEM = 1;
	}
	else {
	    print "$0: only allowed value for env var DAISY_CONFIG_AUDIT_SYSTEM is 1\n";
	}
    }
}

# Handle "--version" command line option
if ($VERSION != 0) {
	print("$0 $CVS_REVISION\n");
	exit($EXIT_OK);
}


# Handle "--help" command line option
if ($HELP ne "") {
	usage();
	exit($EXIT_OK);
}

# Handle "--previous" command line option
if ($PREV_DAISY_VERSION ne "") {
	if (verify_daisy_version($PREV_DAISY_VERSION) == 0) {
		print("$0 invalid format for previous daisy version: $PREV_DAISY_VERSION\n");
		exit($EXIT_COMMAND_LINE);
	}
}

#
# This script must be run as root.
#
if ($EUID != 0) {
        print "Upgrade/Install must be run as root.\n";
        usage();
        exit($EXIT_MUST_BE_ROOT);
}

#
# The destination daisy db directory is required.
#
if (scalar(@ARGV) <= 0) {
        print "Error: destination Daisy database directory required.\n";
        usage();
        exit($EXIT_COMMAND_LINE);
}

#
# install_daisy.pl /d/daisy
#	if "/d/daisy/control.dsy" exists then
#		upgrade install
#	else
#		new install
#
# install_daisy.pl /d/daisy /d/daisy
#	if "/d/daisy/control.dsy" exists then
#		upgrade install
#	else
#		new install
#
# install_daisy.pl /d/daisy /tmp/daisy
#	if "/tmp/daisy/control.dsy" does not exist then error
#	if "/d/daisy/control.dsy" exists then
#		upgrade install of /d/daisy with data migration
#		from "/tmp/daisy/control.dsy"
#	else
#		new install of /d/daisy/with data migration
#		from "/tmp/daisy/control.dsy"
#

#
# ARGV[0] --> DESTINATION DAISY DB DIR
#
$DESTROOT = validate_input($ARGV[0]);
if ($DESTROOT eq "") {
	usage();
	print("$0: Destination Daisy database directory path invalid: $ARGV[0].\n");
        exit($EXIT_COMMAND_LINE);
}

#
# if $DESTROOT exists but is not a daisy database dir,
# output an error and exit.
#
if (-e $DESTROOT) {
    # must be in "/d"
    my $std_location_flag = 1;
    unless (is_daisy_db_dir($DESTROOT, $std_location_flag)) {
	print "The path to the destination Daisy database directory exists but\n";
	print "it is NOT a Daisy database dir: $DESTROOT\n";
	print "\n";
	print "The path to the destination Daisy database directory must either\n";
	print "be to a valid Daisy database directory or it must NOT exist.\n";
        exit($EXIT_COMMAND_LINE);
    }
}

#
# ARGV[1] --> OPTIONAL PREVIOUS DAISY DB DIR
#
if (defined $ARGV[1]) {
    $PREVIOUSROOT = validate_input($ARGV[1]);
    if ($PREVIOUSROOT eq "") {
	print "Previous Daisy database directory path invalid: $ARGV[1]\n";
	exit($EXIT_COMMAND_LINE);
    }
    # does not have to be in "/d"
    my $std_location_flag = 0;
    unless (is_daisy_db_dir($PREVIOUSROOT, $std_location_flag)) {
	print "The path to the previous Daisy database directory exists but\n";
	print "it is NOT a Daisy database dir: $PREVIOUSROOT\n";
	exit($EXIT_COMMAND_LINE);
    }
}

#
# DESTINATION --> existing daisy database directory
#    PREVIOUS --> not specified
#
# Our user didn't specify an 'upgrade' directory, but did specify
# to install into an existing daisy directory. This is, for all intents and
# purposes, an upgrade.
if ( ($PREVIOUSROOT eq "") && (-f "$DESTROOT/control.dsy") ) {
	$PREVIOUSROOT = $DESTROOT;
}


#
# DESTINATION --> existing daisy database directory
#    PREVIOUS --> a different existing daisy database directory
#
# We want to upgrade from directory "X" into directory "Y", yet
# both "X" and "Y" are different daisy directories. This is odd.
# It makes more sense if "X" and "Y" are the same directory, or
# "Y" isn't a daisy directory yet.
#
if (-f "$DESTROOT/control.dsy"     &&
    -f "$PREVIOUSROOT/control.dsy" &&
    $DESTROOT ne $PREVIOUSROOT) {

	#
	# In this case, we are trying to "over-write" an existing Daisy directory.
	# We will complain here, as, "over-writing" means destroying data, which
	# is never a good thing. We'll complain and suggest the "force" flag.
	#
	if($FORCE eq "") {
		print <<EOF;
You are trying to upgrade from \"$PREVIOUSROOT\" into \"$DESTROOT\", yet,
these are different daisy directories.

Try moving \"$DESTROOT\" out of the way first, or using the \"--force\"
commandline option.
EOF
		exit($EXIT_FORCE_REQ);

	#
	# In this case, we are effectively over-writing an existing Daisy directory.
	# Our "destdir" already exists, but, "--force" tells us that we don't care
	# if data is overwritten.
	#
	} else {
		print "\n";
		print "\n";
		print "*** Forcing Installation. This will over-write data presently in $DESTROOT!\n";
		print "(Press Control-C to cancel now, or just wait to continue.)\n";
		print "\n";
		sleep 5;
	}
}

#
# ARGV[2] --> INSTALLATION MEDIA
#
if(defined $ARGV[2]) {
	$SOURCEROOT = validate_input($ARGV[2]);
} else {
	my $currentwd = getcwd;

	if (-d "$currentwd/daisy-installfiles") {
		$SOURCEROOT = "$currentwd";
	} elsif (-d "/mnt/cdrom/daisy-installfiles") {
		$SOURCEROOT = '/mnt/cdrom';
	} elsif (-d "$ENV{HOME}/daisy-$DAISY_VERSION/daisy-installfiles") {
		$SOURCEROOT = "$ENV{HOME}/daisy-$DAISY_VERSION";
	}
}
if ($SOURCEROOT eq "") {
	print("$0: Install sources not found.\n");
	usage();
	exit($EXIT_INSTALL_FILES);
}

$SOURCE_INSTALL_FILES_DIR = "$SOURCEROOT/daisy-installfiles";
$SOURCE_UTILS_DIR = "$SOURCEROOT/utils";
my $SOURCE_TEST_TARBALL = "$SOURCE_INSTALL_FILES_DIR/data_daisy.tgz";

#
# Init the log file and tell the user about it.
#
$LOGFILE = "/tmp/daisy_install-" . strftime("%Y-%m-%d", localtime()) . ".log";
print("Daisy installation log file initialzed to: $LOGFILE\n");

#
# Check for a few tell tale signs that a valid SOURCE path was specified or guessed.
#
unless (-d $SOURCE_INSTALL_FILES_DIR) {
	showerror("Invalid Source path specified: \"$SOURCEROOT\" ($SOURCE_INSTALL_FILES_DIR missing)");
	exit($EXIT_INSTALL_FILES);
}
unless (-f $SOURCE_TEST_TARBALL) {
	showerror("Invalid Source path specified: \"$SOURCEROOT\" ($SOURCE_TEST_TARBALL missing)");
	exit($EXIT_INSTALL_FILES);
}
unless (-d $SOURCE_UTILS_DIR) {
	showerror("Invalid Source path specified: \"$SOURCEROOT\" ($SOURCE_UTILS_DIR missing)");
	exit($EXIT_INSTALL_FILES);
}

#
# Set the $OS variable to the value of the platform we are running on.
#
determine_os();

#
# If the Daisy build info file exists at the top level of the iso, then
# verify that the contents of the CDROM are appropriate for the platform.
#

my $cdrom_buildinfo_file = "$SOURCEROOT/daisybuildinfo.txt"; 
if (-f $cdrom_buildinfo_file) {

	unless (open(IFH, "< $cdrom_buildinfo_file")) {
		showerror("Can't open Daisy build info file: \"$cdrom_buildinfo_file\"");
		exit($EXIT_INSTALL_FILES);
	}

	my $build_platform = "";
	while(<IFH>) {
		chomp;
		if (/(Build Platform:)(\s+)([[:print:]]+)/) {
			$build_platform = $3;
			last;
		}
	}
	close(IFH);

	if ($OS ne $build_platform) {
		showerror("Error: platform mismatch: CDROM is $build_platform, OS is $OS");
		exit($EXIT_PLATFORM);
	}
}


#
# At this point:
# assert($DESTROOT ne "")
# assert(if ($PREVIOUSROOT ne "") {it points at a daisy tree}
# assert($SOURCEROOT ne "")
# assert($SOURCE_INSTALL_FILES_DIR ne "");
# assert($SOURCE_UTILS_DIR ne "");
#


#####################################
#                                   #
# Install Daisy in 10 easy steps... #
#                                   #
#####################################

my $install_type = ($PREVIOUSROOT eq "") ? "Installation" : "Upgrade";
my $install_prev_root = ($PREVIOUSROOT ne "") ? $PREVIOUSROOT : "none";
my $start_time = strftime("%Y-%m-%d %H:%M:%S", localtime());
my $start_msg = "Daisy install start time: $start_time
  Install script version: $CVS_REVISION
       Installation type: $install_type
   Installing files from: $SOURCEROOT
     Installing files to: $DESTROOT
     Migrating data from: $PREVIOUSROOT
                 Country: $COUNTRY
             Commandline: $COMMAND_LINE
";

if ($CHECK_ARGS_ONLY) {
    print "$0: check args only\n";
    print "$start_msg\n";
    exit($EXIT_OK);
}

showinfo("\n");
showinfo("=========================================================================");
showinfo("$start_msg");
showinfo("=========================================================================");


###############
### Step -1 ###
##########################################################################################
#
# (A) check disk space requirements
#

# if they want space check only, then don't let them skip it.
if ($SPACE_CHECK_ONLY && $SKIP_SPACE_CHECK) {
    $SKIP_SPACE_CHECK = 0;
}

if ($SKIP_SPACE_CHECK == 0) {
    showinfo("\n");
    showinfo("Checking Disk Space Requirements");
    showinfo("================================");
    if (is_disk_space_available($DESTROOT, $PREVIOUSROOT) == 0) {
	showerror("Not enough disk space available for install... exiting");
	exit($EXIT_DISK_SPACE);
    }
    else {
	showinfo("--> Disk space OK");
    }
}

if ($SPACE_CHECK_ONLY) {
    exit($EXIT_OK);
}


#
# (B) verify Internet connection
#
showinfo("\n");
showinfo("Verifying Internet Connection");
showinfo("=============================");

if (verify_internet() == -1) {
    showerror("Can't verify Internet connection");
}

#
# (C) must be able to download the ostools package now, install it later.
#
showinfo("\n");
showinfo("Downloading OSTools Package");
showinfo("===========================");

my $ostools_path = get_ostools_package();

if ($ostools_path eq "") {
    showerror("Could not download OSTools package... exiting");
    exit($EXIT_OSTOOLS_DOWNLOAD);
}


##########################################################################################



##############
### Step 0 ###
##########################################################################################
#
# Kill currently running Daisy processes.
#
if (-f "$DESTROOT/control.dsy") {

	showinfo("\n");
	showinfo("Stopping all Daisy processes");
	showinfo("============================");

	if ($OS eq 'RHEL5' || $OS eq 'RHEL6') {
	    showinfo("--> Changing system to runlevel 4");
	    unless (set_runlevel(4) == 0) {
		showerror("Can't set system runlevel to 4... exiting");
		exit_after_daisy_restart($EXIT_STOP_DAISY);
	    }
	    # verify system runlevel is what we expect
	    unless (get_runlevel() == 4) {
		showerror("Can't verify system runlevel is 4... exiting");
		exit_after_daisy_restart($EXIT_STOP_DAISY);
	    }
	    showinfo("--> System changed to runlevel 4");
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

	if (-f "$DESTROOT/utils/killemall") {
	    showinfo("--> Killing all Daisy processes");
	    unless (do_system("$DESTROOT/utils/killemall")) {
		showerror("Unable to stop Daisy processes... exiting");
		exit_after_daisy_restart($EXIT_STOP_DAISY);
	    }
	    showinfo("--> All Daisy processes killed");
	}
}


##############
### Step 1 ###
##########################################################################################

#
# Make an encrypted backup of a previous Daisy database directory.
# 
if (-f "$DESTROOT/control.dsy") {

    showinfo("\n");
    showinfo("Making encrypted backup of Daisy database directory");
    showinfo("===================================================");

    if (backup_previous_tree($DESTROOT, $SOURCEROOT) != 0) {
	exit_after_daisy_restart($EXIT_BACKUP_FAILED);
    }
}


##############
### Step 2 ###
##########################################################################################
#
# Make an installation tree.
# 
# In the event that we are doing an "in place" upgrade, we will actually install "beside"
# the existing directory, and then rename things once we're done.
# If we are doing a "forced" install, then, we just overwrite the existing directory.
#
showinfo("\n");
showinfo("Making new Daisy tree");
showinfo("=====================");

if (-f "$DESTROOT/control.dsy") {

    if ($FORCE eq "") {

	#
	#=======================================
	# Save previous daisy database directory
	#=======================================
	#
	# Here is where the old daisy database directory is saved by moving
	# it to a time stamped name.  If need be, it can be recovered.
	#
	$SAVEDROOT = $DESTROOT . "-" . $TIMESTAMP;

	showinfo("--> Moving previous Daisy tree to: $SAVEDROOT");
	system("mv $DESTROOT $SAVEDROOT");
	if ($? != 0) {
	    showerror("Move of existing Daisy database directory failed: $DESTROOT.");
	    exit_after_daisy_restart(2);
	}

	#
	# Now that the destination was moved, if we were doing an
	# upgrade install of the destination, adjust previous to point
	# to the moved instance of the destination.
	#
	if ($PREVIOUSROOT eq $DESTROOT) {
	    $PREVIOUSROOT = $SAVEDROOT;
	}

	#
	#====================================
	# Make a new daisy database directory
	#====================================
	#
	$destdir = create_daisy_tree($DESTROOT);
	$INSTALL_TYPE = "upgrade";
    }
    else {
	$destdir = create_daisy_tree($DESTROOT);
	    $INSTALL_TYPE = "forced upgrade";
    }
}
else {
	#
	#============================
	# Make a whole new daisy tree
	#============================
	#
	$destdir = create_daisy_tree($DESTROOT);
	$INSTALL_TYPE = "new";
}

if ($destdir eq "") {
	logerror("Could Not Create Directory under \"$DESTROOT\".");
	exit_after_cleanup($DESTROOT, $SAVEDROOT, 3);
}

showinfo("--> New Daisy database directory: $destdir");
showinfo("--> Installation type: $INSTALL_TYPE");


##############
### Step 3 ###
##########################################################################################
#
# Fill installation tree.
#
showinfo("\n");
showinfo("Populating Daisy Tree");
showinfo("=====================");
install_daisy_tree($SOURCE_INSTALL_FILES_DIR, $destdir, $INSTALL_TYPE);

#
# Migrate some "special" script files... they are "special" because they
# may be been modified in the field and any changes are required to be
# preserved.
#
# This step must come after fill of new daisy db directory with files
# from the iso.
#
migrate_daisy_scripts($PREVIOUSROOT, $destdir);

#
# Similar step for custom scripts in the "utils" directory of a
# daisy database dir - the Daisy Support team has agreed that they will
# only put their custom scripts into the "utils" directory and will
# always be named "something.sh".
#
migrate_utils_scripts($PREVIOUSROOT, $destdir);


##############
### Step 4 ###
##########################################################################################
#
# Install OSTools package.
#

my $install_new_version = 1;

if ($PRESERVE_OSTOOLS) {
    #
    # Check to see if a newer version of OSTools is already installed.
    # Don't install the downloaded ostools if the user asked to preserve
    # ostools and the downloaded version is older than the installed version.
    #
    showinfo("\n");
    showinfo("Evaluating need to install new OSTools Package");
    showinfo("==============================================");

    my $ostools_bin_dir = "/d/ostools/bin";
    my $ostools_installed_version = ostools_installed_version($ostools_bin_dir);

    if ($ostools_installed_version ne "") {
	my $ostools_pkg_version = ostools_pkg_version($ostools_path);
     
	if (ostools_cmp_version($ostools_installed_version, $ostools_pkg_version) >= 0) {
	    showinfo("--> Installed OSTools package version: $ostools_installed_version");
	    showinfo("--> Downloaded OSTools package version: $ostools_pkg_version");
	    showinfo("--> Installed OSTools package version newer than downloaded version");
	    showinfo("--> Downloaded OSTools package will not be installed");

	    system("rm $ostools_path");

	    $install_new_version = 0;
	}
    }
}

if ($install_new_version) {
    #
    # Install the OSTools package
    #
    showinfo("\n");
    showinfo("Installing new OSTools Package");
    showinfo("==============================");

    showinfo("--> Installing OSTools package: $ostools_path");

    if (ostools_install_package($ostools_path) != 0) {
	showerror("Could not install OSTools package... exiting after cleanup");
	system("rm $ostools_path");
	exit_after_cleanup($DESTROOT, $SAVEDROOT, $EXIT_OSTOOLS_INSTALL);
    }

    showinfo("--> OSTools package installed");
}

#
# Whether installing OSTools or using existing installation, at this point,
# the symlinks from the daisy database dir to the ostools bin dir need to
# be established.
#
ostools_install_links($destdir);

##############
### Step 5 ###
##########################################################################################
#
# Add required user accounts and groups.
#
showinfo("\n");
showinfo("Adding Daisy User Accounts");
showinfo("==========================");
if (create_daisy_users($destdir) != 0) {
	showerror("Can't add Daisy user accounts... exiting");
	exit_after_cleanup($DESTROOT, $SAVEDROOT, 4);
}

#
# Install new versions of Daisy Config Files.
#
showinfo("\n");
showinfo("Installing Daisy Config Files");
showinfo("=============================");
install_dsyconfigs($DESTROOT);


##############
### Step 6 ###
##########################################################################################
#
# Migrate data.
#
# If there was a previous Daisy install, either link to it's data or
# migrate the data from it to the new tree.  Else, it must be a new
# install.
#
if (-d $PREVIOUSROOT) {
	if ($LINKDATA ne "") {
		showinfo("Making links to previous Daisy installation: $PREVIOUSROOT.");
		linkto_daisy_data($PREVIOUSROOT, $destdir);
	} else {
		showinfo("\n");
		showinfo("Migrating Data from Previous Daisy Installation");
		showinfo("===============================================");
		showinfo("--> Previous Daisy Database Directory: $PREVIOUSROOT");
		my $rc = migrate_daisy_data(
				$destdir,
				$PREVIOUSROOT,
				$SOURCE_INSTALL_FILES_DIR,
				$SOURCE_UTILS_DIR);
		if ($rc) {
			exit_after_cleanup($DESTROOT, $SAVEDROOT, 5);
		}
	}
} else {
	showinfo("\n");
	showinfo("Initializing Random Card Data");
	showinfo("=============================");
	set_card_data("$destdir/crddata.pos");

	showinfo("\n");
	showinfo("Setting Country");
	showinfo("===============");
	showinfo("--> Setting country to: $COUNTRY");
	set_country($COUNTRY, "$destdir/control.dsy");

	showinfo("\n");
	showinfo("Updating Dove control file");
	showinfo("==========================");
	update_dovectrl_high_speed($destdir);
}

#
# Migrate top level directories
#
if ($INSTALL_TYPE eq "upgrade") {
	migrate_daisy_backup_dir($destdir);
	migrate_daisy_config_dir($destdir);
	migrate_daisy_menus_dir($destdir);
	migrate_daisy_putty_dir($destdir);
	migrate_daisy_server_dir($destdir);
	migrate_daisy_startup_dir($destdir);
}


##############
### Step 7 ###
##########################################################################################
#                                 #
# Configure Daisy Users and Perms #
#                                 #
###################################
#
# (A) Set permissions.
#
# Make sure the Daisy installation has all modes and permissions set appropriately.
#
if ($destdir ne "/") {

	showinfo("\n");
	showinfo("Setting permissions for the Daisy installation tree");
	showinfo("===================================================");

	showinfo("--> Setting permissions for: $destdir");

	my $perms_cmd = "$destdir/bin/dsyperms.pl";
	if (-e $perms_cmd) {
	    showinfo("--> Using script: $perms_cmd");
	    system("/usr/bin/perl $perms_cmd $destdir");
	    showinfo("--> Permissions set");
	}
	else {
	    showerror("Can't set perms - script does not exist: $perms_cmd");
	}
}

#
# (B) Add Daisy Shell.
#
# This step must be done before the update to daisy users is done since the
# daisy shell must be on the white list of permitted shells (/etc/shells)
# before it can be specfied as a user's shell.
#
if ($INSTALL_TYPE ne "data_only") {
	showinfo("\n");
	showinfo("Adding Daisy Shell to Shells White List");
	showinfo("=======================================");
	os_configure_shells();
} else {
	loginfo("Skipping: Adding Daisy Shell to Shells White List");
}

#
# (C) Update Daisy Users.
#
# In this step, we select all the Daisy users and make sure they conform to the
# standard configuration.
#
if ($INSTALL_TYPE ne "data_only") {
	showinfo("\n");
	showinfo("Updating Daisy Users to the Standard Configuration");
	showinfo("==================================================");
	update_dsyusers($destdir);
} else {
	loginfo("Skipping: Updating Daisy Users to the Standard Configuration");
}


##############
### Step 8 ###
##########################################################################################
#                        #
# Clear Credit Card Data #
#                        #
##########################
#
# (A) Clear CC Swipes.
#
if ($INSTALL_TYPE ne "data_only") {
	showinfo("\n");
	showinfo("Securing Credit Card Information");
	showinfo("================================");
	clear_cc_swipes($destdir);
} else {
	loginfo("Skipping: Securing Credit Card Information");
}


##############
### Step 9 ###
##########################################################################################
#                                                                  #
# Catch all step - things that need to be done before finishing up #
#                                                                  #
####################################################################

showinfo("\n");
showinfo("System Config and Cleanup");
showinfo("=========================");

#
# (A) Modify os configs.
#
if ($CONFIG_AUDIT_SYSTEM) {
    showinfo("--> Installing Audit System config file");
    os_audit_system_install();
}

if ($INSTALL_TYPE ne "data_only") {
	showinfo("--> Modifying OS configs");
	modify_os_configs($destdir, $PREVIOUSROOT);
} else {
	showinfo("--> Skipping: Modifying OS configs because install type \"data only\"");
}

#
# (B) Harden Linux which will also modify some OS configs
#
if ($INSTALL_TYPE ne "data_only") {
	showinfo("--> Hardening Linux");
	system("/d/ostools/bin/harden_linux.pl");
} else {
	showinfo("--> Skipping: Hardening Linux because install type \"data only\"");
}

#
# (C) Preserve the contents of the previous export directory
#
if (-d "$SAVEDROOT/export") {
	showinfo("\n");
	showinfo("Preserving export directory contents");
	showinfo("====================================");
	showinfo("--> Preserving contents of: $SAVEDROOT/export");
	showinfo("--> Copying to: $DESTROOT/export");
	system ("cp -pr $SAVEDROOT/export/* $DESTROOT/export");
	$strerror = system_exit_status($?);
	if ($strerror) {
		showerror("Copy of $SAVEDROOT/export/* to $DESTROOT/export failed");
		showerror("$strerror");
	}

	showinfo("--> The export directory preserved");
}


#
# (D) Install the Florist Directory patch
#
showinfo("\n");
showinfo("Installing Florist Directory");
showinfo("============================");
install_florist_directory_patch($destdir, $SOURCEROOT);

#
# (E) correct perms of tty service files on RHEL7 if necessary
#
if ($OS eq 'RHEL7') {
    showinfo("\n");
    showinfo("Correcting Perms on Virtual Console Service Files");
    showinfo("=================================================");
    os_virt_cons_patch_perms();
}

###############
### Step 10 ###
##########################################################################################
#
# Remove old tree.
#
# Once we are done upgrading, the saved Daisy database directory must be deleted,
# leaving behind only the encrypted tarball of saved data.
#
if (-d $SAVEDROOT) {

    showinfo("\n");
    showinfo("Removing Saved Daisy Database Directory");
    showinfo("=======================================");

    showinfo("--> Removing saved Daisy database directory: $SAVEDROOT");

    if (! -e $ENCRYPTED_TAR_FILE) {
	showerror("Encrypted tar file $ENCRYPTED_TAR_FILE: file not found");
    }
    elsif (! -s $ENCRYPTED_TAR_FILE) {
	showerror("Encrypted tar file $ENCRYPTED_TAR_FILE: file size zero");
    }
    else {
	# file exists and has length > 0
	# shred saved daisy db dir - required by PCI
	if (cleanup_saved_daisy_dir($SAVEDROOT)) {
	    showinfo("--> Saved Daisy Database directory removed");
	}
	else {
	    showerror("Could not remove saved Daisy database directory");
	}

	# don't let "other" even read the encrypted tar archive
	system("chown tfsupport:daisy $ENCRYPTED_TAR_FILE");
	system("chmod 440 $ENCRYPTED_TAR_FILE");

	# The encrypted tar file will be removed after n days where
	# currently n = 30.  This will be done by the postinstall
	# cron job.
    }
}


#################
### Step 10+1 ###
##########################################################################################
#
# announce the installation is finished.
#
##########################################################################################

# get the Daisy version string from the Daisy build info file on
# the ISO so it can be reported in the Daisy actions screen and
# in a Daisy logevent.
#
# If the Daisy version string can't be obtained from the build info file
# on the ISO, then use the output of the "pos" command from the
# newly installed Daisy tree.
#
# If the Daisy version string can't be obtained from there, just use
# the major and minor number as recorded in the install script.
#
my $daisy_version_string = get_iso_daisy_version("$SOURCEROOT/daisybuildinfo.txt");
if ($daisy_version_string eq $EMPTY_STR) {
    $daisy_version_string = get_new_daisy_version($destdir);
    if ($daisy_version_string eq $EMPTY_STR) {
	$daisy_version_string = $MAJOR_VERSION . $MINOR_VERSION . q{x};
    }
}

showinfo("");
showinfo("Daisy $daisy_version_string is now Installed at: $DESTROOT");
showinfo("");
showinfo("Install completed at " . strftime("%Y-%m-%d %H:%M:%S", localtime()));
showinfo("");
showinfo("Daisy installation log file available at: $LOGFILE");
showinfo("");

#
# copy the log file to the new daisy log dir
#
system("cp $LOGFILE $destdir/log");
$strerror = system_exit_status($?);
if ($strerror) {
	showerror("Error: could not copy installation log file \"$LOGFILE\" to $destdir/log.");
}

#
# the current working directory must be in the new Daisy database dir
# in order for the "actions" and "logevent" programs to work correctly.
#
chdir $destdir;

system("./actions naIsystemUpdate 2 0 \"\" install-daisy.pl \"Your system has been updated to version $daisy_version_string.\rPlease contact Daisy support if you have any questions.\"");

system("./logevent nEventSystemUpdate 0 \"\" SYS install-daisy.pl \"System was updated to version $daisy_version_string\"");

#
# we are otta here.  have a good one!
#
exit_after_daisy_restart(0);


#################
### Functions ###
##########################################################################################

sub usage
{
	print "Usage:\n";
	print "$0 [options] Destdir [MigrateFrom [InstallFiles]]\n";
	print "$0 --version\n";
	print "$0 --help\n";
	print "\n";
	print "Arguments\n";
	print "Destdir: Directory which will contain new Daisy Installation. Usually \"/d/daisy\"\n";
	print "MigrateFrom: (Optional) Directory containing an existing installation of Daisy.\n";
	print "InstallFiles: (Optional) Full path to the directory containing all install files.\n";
	print "\n";
	print "Options\n";
	print "--force:               allows installation over existing installation of Daisy.\n";
	print "--linkdata:            just use symlinks to data in \"MigrateFrom\".\n";
	print "--preserve-ostools:    don't overwrite installed OSTools pkg if newer version.\n";
	print "--skip-space-check:    don't check disk space available.\n";
	print "--space-check-only:    check disk space requirments and exit (off by default).\n";
	print "--country=string:      specify which country of software to install (default = us).\n";
	print "--previous=version:    specify previous Daisy version number.\n";
	print "--[no]rotate-keys:     perform key rotation after data migration (default).\n";
	print "--config-audit-system: configure Linux audit system (off by default).\n";
	print "--check-args-only:     check command line args and exit (off by default).\n";
	print "--version:             output version number and exit.\n";
	print "--help:                output this help text and exit.\n";
}


sub copy_if_exists
{
	my $source = $_[0];
	my $dest = $_[1];

	my @files = glob($source);
	if (@files) {
		system("cp $source $dest");
	}
}


#
# Function to determine if an arbitrary path is a path to a
# daisy databse directory.
#
# Returns 1 if true, 0 if false.
#
sub is_daisy_db_dir
{
	my ($path, $std_location_flag) = @_;

	if ($std_location_flag) {
	    # must begin with '/d/'
	    return(0) unless ($path =~ /^\/d\//);
	}

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

sub get_new_daisy_version
{
    my ($newroot) = @_;

    my $ml = '[get_new_daisy_version]';
    my $daisy_version = '';

    my $cmd = "$newroot/pos --version";
    if (open(my $pipe, q{-|}, $cmd)) {
	while (<$pipe>) {
	    if (/^Build Number: (.+)$/) {
		$daisy_version = $1;
		last;
	    }
	}
	close($pipe) or warn "$ml could not close pipe $cmd: $OS_ERROR\n";
    }
    else {
	showerror("$ml could not open pipe to Daisy program: $cmd");
    }

    return($daisy_version);
}

sub get_iso_daisy_version
{
    my ($buildinfo_file) = @_;

    my $ml = '[get_iso_daisy_version]';
    my $daisy_version = '';

    if (open(my $fh, '<', $buildinfo_file)) {
	while (<$fh>) {
	    chomp;
	    if (/Build Number: ([[:print:]]+)/) {
		$daisy_version = $1;
		last;
	    }
	}
	close($fh) or warn "$ml could not close Daisy build info file $buildinfo_file: $OS_ERROR\n";
    }
    else {
	showerror("$ml could not open Daisy build info file: $buildinfo_file");
    }

    return($daisy_version);
}

sub get_prev_daisy_version
{
	my $previous_root = $_[0];
	my $prev_version = "";

	#
	# Which version is the previously installed daisy?  Use the new
	# version of the script to look at the old version of daisy.
	#
	open(PIPE, "strings $previous_root/pos |");
	while (<PIPE>) {
	    if(/^Build Number: (.+)$/) {
		$prev_version = $1;
	    }
	}
	close(PIPE);

	#
	# If we have found Daisy the version number, let the rest of the script
	# know about the major version number by setting the global variable.
	#
	if ($prev_version ne "") {
	    if ($prev_version =~ /^(\d+)\./) {
		$DSY_MAJOR_VERSION = $1;
	    }
	}

	return ($prev_version);
}


sub verify_daisy_version
{
	my $daisy_version = $_[0];

	if ($daisy_version !~ /^([\d]+)\.([\d]+)\.([\d]+[[:alpha:]]*)$/) {
		return(0);
	}

	return(1);
}


#
# Get a list of file names from a directory - exclude directories and
# "dot" files.
#
sub get_dirfiles
{
	my $dirname = $_[0];
	my @dirfiles = ();

	unless (opendir(DIRH, $dirname)) {
		loginfo("get_dirfiles(): opendir returns: $!");
		return @dirfiles;
	}

	foreach my $dirent (readdir(DIRH)) {
		next if ($dirent =~ /^\.$/);
		next if ($dirent =~ /^\.\.$/);
		next if ($dirent =~ /^\..*$/);
		next if (-d $dirent);

		push @dirfiles, $dirent;
	}
	closedir(DIRH);

	return @dirfiles;
}

sub trim
{
	my $string = $_[0];

	$string =~ s/^\s+//;
	$string =~ s/\s+$//;

	return $string;
}

#
# Compare md5 sums of two files. If they are the same file, then return non-zero.
#
sub is_same_file
{
        my $file1 = $_[0];
        my $file2 = $_[1];
        my $context1 = "";
        my $context2 = "";
        my $hash1 = "";
        my $hash2 = "";

        if("$file1" eq "") {
                return(0);
        }
        if("$file2" eq "") {
                return(0);
        }
        if(! -f "$file1") {
                return(0);
        }
        if(! -f "$file2") {
                return(0);
        }

        open(FILE1, "< $file1");
        binmode(FILE1);
        $context1 = new Digest::MD5;
        $context1->reset();
        $context1->addfile(*FILE1);
        $hash1 = $context1->hexdigest();
        close(*FILE1);

        open(FILE2, "< $file2");
        binmode(FILE2);
        $context2 = new Digest::MD5;
        $context2->reset();
        $context2->addfile(*FILE2);
        $hash2 = $context2->hexdigest();
        close(*FILE2);

        if("$hash1" eq "") {
                return(0);
        }
        if("$hash2" eq "") {
                return(0);
        }

        if("$hash1" eq "$hash2") {
                return(1);
        }

        return(0);
}

sub get_file_perms
{
    my ($file) = @_;

    my $sb = File::stat::stat($file);
    my $perms = $sb->mode & 07777;

    return($perms);
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

#=====================================#
# +---------------------------------+ #
# | Section Begin: Cleanup and Exit | #
# +---------------------------------+ #
#=====================================#

#
# Get the system run level.
#
# Returns 0-6 on success, -1 on error
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
	if (open(RL, "$whocmd -r |")) {
	    while (<RL>) {
		chomp($_);
		$runlevel = $_;
		$runlevel =~ s/\s*run-level\s(\d).+$/$1/;
	    }
	    close(RL);
	}
    }
    else {
	showerror("The who command is not available: $whocmd");
    }

    return($runlevel);
}


#
# Set the system run level to value between 0 and 6.
#
# Returns 0 on success, -1 on error.
#
sub set_runlevel
{
    my $new_runlevel = $_[0];
    my $rc = 0;

    system("/sbin/telinit $new_runlevel");
    $strerror = system_exit_status($?);
    if ($strerror) {
	$rc = -1;
    }

    # The "init" man page mentions that "init" waits 5 seconds
    # between each of two kills, and testing reveals we need
    # to wait a bit for the runlevel to change.
    sleep(10);

    return($rc);
}


sub exit_after_daisy_restart
{
    my ($exitvalue) = @_;

    if ($OS eq 'RHEL5' || $OS eq 'RHEL6') {
	if (get_runlevel() != 3) {
	    if (set_runlevel(3) != 0) {
		showerror("Can't set runlevel to 3: $strerror");
	    }
	}

	if (get_runlevel() != 3) {
	    showerror("Unable to return to runlevel 3");
	    if ($exitvalue == $EXIT_OK) {
		$exitvalue = $EXIT_START_DAISY;
	    }

	    exit($exitvalue);
	}
	showinfo("System back to run level 3");
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

	showinfo("gettys restarted");
    }

    showinfo("Daisy restarted");

    exit($exitvalue);
}


#
# If we've had an error, we may need to cleanup a bit
# before exiting this script.
#
sub exit_after_cleanup
{
        my $destroot = $_[0];
        my $savedroot = $_[1];
        my $exitvalue = $_[2];

	unless ($destroot) {
		showerror("Can't cleanup before exit.");
		exit $exitvalue;
	}

	if (-d "$destroot/log") {
		system("cp $LOGFILE $destroot/log 2>/dev/null");
	}

        # Installation failed.
        if ($exitvalue != 0) {

		#
                # If there is a "savedroot", then
		#	move "$savedroot" back to "$destroot".
		#
                if ( ($savedroot ne "") &&
		     ($savedroot ne $destroot) &&
		     (-d $savedroot) ) {

			my $datestamp = strftime "%Y%m%d", localtime;
			my $timestamp = $datestamp . strftime "%H%M%S", localtime;
			my $failed_name = $destroot . "-failed_install-" . $timestamp;
			my $strerror = "";

			# failed name with timestamp should not exist, but check anyway
			if (-e $failed_name) {
				showerror("Removing old $failed_name.");
				system("rm $failed_name");
				$strerror = system_exit_status($?);
				if ($strerror) {
					showerror("Error removing old failed install dir: $failed_name.");
				}
			}

			#
			# The next 2 moves should succeed in putting original daisy
			# db directory back.
			#
			unless (-e $failed_name) {
				system("mv $destroot $failed_name");
				$strerror = system_exit_status($?);
				if ($strerror) {
					showerror("Error moving $destroot to $failed_name.");
				}
			}

			unless (-e $destroot) {
				system("mv $savedroot $destroot");
				$strerror = system_exit_status($?);
				if ($strerror) {
					showerror("Error moving $savedroot to $destroot.");
				}
			}
                }
        }

	exit_after_daisy_restart($exitvalue);
}

#========================================#
# +------------------------------------+ #
# | Section Begin: Make New Daisy Tree | #
# +------------------------------------+ #
#========================================#

# Create an empty directory tree for daisy 6.
sub create_daisy_tree
{
	my $destroot = $_[0];

	unless (defined $destroot) {
		showerror("Daisy directory not specified.");
		return "";
	}

	#
	# A "daisy dir" must not start at the root of the file system; it must
	# be at least one directory level below root.
	#
	my $treetop = dirname($destroot); 
	if ($treetop eq '/') {
		showerror("Daisy directory specification error: $destroot.");
		return "";
	}
	unless (-d $treetop) {
		system("mkdir -p $treetop");
	}
	unless (-d $treetop) {
		showerror("Daisy tree toplevel does not exist: $treetop.");
		return "";
	}

	my @dsy_top_level_dirs = qw(
		backup
		config
		daisy
		menus
		putty
		server
		startup
		utils
	); 

	#
	# Make Daisy top level if necessary.
	#
	foreach my $dirname (@dsy_top_level_dirs)  {
		next if (-d "$treetop/$dirname");

		system("mkdir $treetop/$dirname");
		unless (-d "$treetop/$dirname") {
			showerror("Could not create directory \"$treetop/$dirname\"");
			return "";
		}

		if ($dirname eq 'backup') {
			system("mkdir $treetop/$dirname/verify");
		}
	}

	#
	# Remember, there could be multiple daisy database dirs, so
	# we might need to make a new daisy db directory that is not
	# named /d/daisy.
	#
	unless (-d $destroot) {
		system("mkdir $destroot");
	}

	#
	# Make Daisy subdirectories if necessary.
	#
	my @dsydir_list = qw(
		backup.dir
		bin
		blankdata
		comms
		config
		cubby
		docs
		dsy
		errors
		export
		log
		pospool
		recv
		submit
		tcc
		tfm
		utils
	);

	foreach my $dirname (@dsydir_list)  {
		next if (-d "$destroot/$dirname");

		system("mkdir $destroot/$dirname");
		if(! -d "$destroot/$dirname") {
			showerror("Could not create directory \"$destroot/$dirname\"");
			return "";
		}
	}

	#
	# Make a file named "flordat.tel" - it's a file that normally
	# gets installed when the eDirectory files are installed and
	# is one of the markers that defines a directory as a Daisy
	# database dir... so it has to be there or utils like dysperms.pl
	# won't recognize it as a daisy db dir and won't operate on it...
	# so appease them until the edir is really installed.

	system("touch $destroot/flordat.tel");

	return "$destroot";
}

#=======================================#
# +-----------------------------------+ #
# | Section Begin: Daisy Installation | #
# +-----------------------------------+ #
#=======================================#

#
# Install daisy programs and infrasturcture.
#
sub install_daisy_tree
{
	my $sourceroot = $_[0];
	my $destdir = $_[1];
	my $installation_type = $_[2];
	my $errors;

	$errors = install_blankdata($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_blankdata() returned \"$errors\". Continuing.");
	}

	$errors = install_crd($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_crd() returned \"$errors\". Continuing.");
	}

	$errors = install_daisy_core($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_daisy_core() returned \"$errors\". Continuing.");
	}

	$errors = install_utils($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_utils() returned \"$errors\". Continuing.");
	}

	$errors = install_scripts($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_scripts() returned \"$errors\". Continuing.");
	}

	$errors = install_bins($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_bins() returned \"$errors\". Continuing.");
	}

	$errors = install_fonts($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_fonts() returned \"$errors\". Continuing.");
	}

	$errors = install_menus($sourceroot, $destdir, $installation_type);
	if ($errors ne "") {
		logerror("install_menus() returned \"$errors\". Continuing.");
	}

	$errors = install_putty($sourceroot, $destdir, $installation_type);
	if ($errors ne "") {
		logerror("install_putty() returned \"$errors\". Continuing.");
	}

	$errors = install_session($sourceroot, $destdir, $installation_type);
	if ($errors ne "") {
		logerror("install_session() returned \"$errors\". Continuing.");
	}

	$errors = install_startup($sourceroot, $destdir, $installation_type);
	if ($errors ne "") {
		logerror("install_startup() returned \"$errors\". Continuing.");
	}

	$errors = install_service($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_service() returned \"$errors\". Continuing.");
	}

	$errors = install_ppd($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_ppd() returned \"$errors\". Continuing.");
	}

	$errors = install_dole($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_dole() returned \"$errors\". Continuing.");
	}

	$errors = install_buildinfo($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_buildinfo() returned \"$errors\". Continuing.");
	}

	$errors = install_tcc($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_tcc() returned \"$errors\". Continuing.");
	}

	$errors = install_dove($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_dove() returned \"$errors\". Continuing.");
	}

	$errors = install_mercury($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_mercury() returned \"$errors\". Continuing.");
	}

	$errors = install_marketpro($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_marketpro() returned \"$errors\". Continuing.");
	}

	$errors = install_map($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_map() returned \"$errors\". Continuing.");
	}

	$errors = install_pool($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_pool() returned \"$errors\". Continuing.");
	}

	$errors = install_glexport($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_glexport() returned \"$errors\". Continuing.");
	}

	$errors = install_hospital($sourceroot, $destdir);
	if ($errors ne "") {
		logerror("install_hospital() returned \"$errors\". Continuing.");
	}
}

#
# Takes a tarball and installs
# it's contents into "destdir".
#
sub install_tarball
{
	my $tarball = $_[0];
	my $destdir = $_[1];

	if(! -f $tarball) {
		return "";
	}
	if(! -d $destdir) {
		return "";
	}

	# If we are root, then set user/group otherwise, just plain vanilla tar.
	system("cd $destdir && tar -xzvf $tarball >> $LOGFILE 2>&1");
	my $strerror = system_exit_status($?);
	if ($strerror) {
		showerror("Error installing tar file: $tarball");
		showerror("$strerror");
		return;
	}

	# If this is a "data" tarball, then copy the tarball itself to the user's HDD.
	# Note this relies on magic file naming convention.
	if ($tarball =~ /data_/i) {
		if (-d "$destdir/blankdata") {
			system "cp $tarball $destdir/blankdata/";
		} else {
			system "cp $tarball $destdir/";
		}
	}
}

#
# Install "core" programs and resources for Daisy.
#
sub install_daisy_core
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Daisy Core Programs...");
	loginfo("Installing Daisy Core Programs...");

	install_tarball("$sourceroot/progs_daisy.tgz", "$destroot");
	install_tarball("$sourceroot/screens_daisy.tgz", "$destroot");
	install_tarball("$sourceroot/data_daisy.tgz", "$destroot");
	install_tarball("$sourceroot/docs_daisy.tgz", "$destroot/docs");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_utils
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Utilities...");
	loginfo("Installing Utilities...");

	install_tarball("$sourceroot/screens_util.tgz", "$destroot/utils");
	install_tarball("$sourceroot/progs_util.tgz", "$destroot/utils");
	install_tarball("$sourceroot/screens_misc.tgz", "$destroot");

	#
	# "Copy" - nope, just symlink them - files from "utils" to main directory.
	#
	my @util_list = (
		'arcprint',
		'listscr.scr',
		'mainscr.scr',
		'plist',
		'rbl',
		'rep',
		'repost',
		'tercreat'
	);

	foreach my $filename (@util_list) {
		symlink "$destroot/utils/$filename", "$destroot/$filename";
	}

	#
	# FIXME
	# One special case for menus
	symlink "$destroot/utils/pause", "$destroot/../utils/pause";

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_scripts
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Scripts...");
	loginfo("Installing Scripts...");

	install_tarball("$sourceroot/progs_script.tgz", "$destroot/bin");

	#
	# FIXME
	# The script programs are now going to reside in /d/daisy/bin.
	# But there are some references to them in other locations so
	# for the time being, patch that with a simlink.
	#
	symlink "$destroot/bin/dsyperms.pl", "$destroot/utils/dsyperms";
	symlink "$destroot/bin/encrypttar.pl", "$destroot/utils/encrypttar.pl";
	symlink "$destroot/bin/killemall.pl", "$destroot/utils/killemall";

	#
	# The old /d/menus contains a copy of market_input - need to get rid
	# of that first.
	#
	if (-f "$destroot/../menus/market_input") {
		system "rm $destroot/../menus/market_input";
	}
	symlink "$destroot/bin/market_input", "$destroot/../menus/market_input";

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_bins
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Binaries...");
	loginfo("Installing Binaries...");

	install_tarball("$sourceroot/progs_bin.tgz", "$destroot/bin");
	install_tarball("$sourceroot/progs_pdf.tgz", "$destroot/bin");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_fonts
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Fonts...");
	loginfo("Installing Fonts...");

	install_tarball("$sourceroot/fonts_daisy.tgz", "$destroot/tfm");
	install_tarball("$sourceroot/fonts_printer.tgz", "$destroot/tfm");

	system("cp $destroot/tfm/ff.txt $destroot");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_menus
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];
	my $installation_type = $_[2];

	print("Installing Menus...");
	loginfo("Installing Menus...");

	#
	# Always install the crawl program that interprets the crawl menus.
	#
	install_tarball("$sourceroot/crawl_progs.tgz", "$destroot/../menus");

	#
	# All of the menus get installed on a full install.
	#
	if ($installation_type eq "new") {
		install_tarball("$sourceroot/crawl_menus.tgz", "$destroot/../menus");
		install_tarball("$sourceroot/crawl_menus_new.tgz", "$destroot/../menus");
		print(" Done.\n");
		loginfo("Done.");
		return "";
	}

	#
	# assert - at this point, we are doing an upgrade install.
	#

	#
	# The bulk of the menus are in 'crawl_menus.tgz' but since crawl menus
	# are site specific and can be modified by Support, previous menus
	# need to be preserved unless it's absolutely necessary to change them.
	# If a menu needs to be updated, put it in the 'crawl_menus_new.tgz' tarball.
	#
	# The new or replacement menus that always get installed - they might have
	# some new actions that require a new version.  But save a copy of the
	# old menu before overwriting with new.
	#
	# make a temp dir
	# install tarball of new menus in temp dir
	# get a list of new menus
	# mv the old menus aside
	# mv the new menus into place
	#
	my $menu_dir = "$destroot/../menus";
	my $menu_tmpdir = "$menu_dir/newmenus-$TIMESTAMP";

	unless (mkdir $menu_tmpdir) {
		showerror("Can't install new crawl menus: mkdir returns: $!");
	} else {

		install_tarball("$sourceroot/crawl_menus_new.tgz", $menu_tmpdir);

		my @numenus = get_dirfiles($menu_tmpdir);

		unless (@numenus) {
			showerror("Warning: new crawl menu list empty.");
		} else {
			foreach my $numenu (@numenus) {
				if (-e "$menu_dir/$numenu") {
					rename "$menu_dir/$numenu", "$menu_dir/$numenu.orig";
				}
				rename "$menu_tmpdir/$numenu", "$menu_dir/$numenu";
			} 
		}

		unless (rmdir $menu_tmpdir) {
			showerror("Can't remove tempdir: rmdir returns: $!");
		}
	}

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_putty
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];
	my $installation_type = $_[2];


	if ($installation_type eq "new") {

		print("Installing Putty Config...");
		loginfo("Installing Putty Config...");

		install_tarball("$sourceroot/putty_config.tgz", "$destroot/../putty");

		print(" Done.\n");
		loginfo("Done.");
	}

	return "";
}

sub install_session
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];
	my $installation_type = $_[2];

	print("Installing Session Files...");
	loginfo("Installing Session Files...");

	if ($installation_type eq "new") {
		install_tarball("$sourceroot/session_putty.tgz", "$destroot/../putty");
		install_tarball("$sourceroot/session_server.tgz", "$destroot/../server");
		install_tarball("$sourceroot/session_server12.tgz", "$destroot/../server");
		install_tarball("$sourceroot/session_startup.tgz", "$destroot/../startup");
	} else {
		#
		# We need to replace the old /d/server/12 file with the
		# new version.
		#
		system("rm -f $destroot/../server/12");
		install_tarball("$sourceroot/session_server12.tgz", "$destroot/../server");

		#
		# Even on an upgrade, if the OS is RHEL5, then install the new
		# startup session file because it has console font commands.
		#
		determine_os();
		if ($OS eq "RHEL5") {
			install_tarball("$sourceroot/session_startup.tgz", "$destroot/../startup");
		}
	}

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_startup
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];
	my $installation_type = $_[2];

	print("Installing Startup Files...");
	loginfo("Installing Startup Files...");

	if ($installation_type eq "new") {
		install_tarball("$sourceroot/startup_files.tgz", "$destroot/../startup");
	}

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_service
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Daisy System Service Files...");
	loginfo("Installing Daisy System Service Files...");

	install_tarball("$sourceroot/service.tgz", "$destroot/config");

	# copy consolechars to bin
	system("cp $destroot/config/consolechars $destroot/bin");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_ppd
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];
	my $previousroot = $_[2];

	print("Installing Daisy System PPD Files...");
	loginfo("Installing Daisy System PPD Files...");

	install_tarball("$sourceroot/ppd.tgz", "$destroot/config");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}


#
# Install Credit Card Related items
#
sub install_crd
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Credit Card Software...");
	loginfo("Installing Credit Card Software...");

	install_tarball("$sourceroot/data_crd.tgz", "$destroot");
	install_tarball("$sourceroot/screens_crd.tgz", "$destroot");
	install_tarball("$sourceroot/progs_crd.tgz", "$destroot");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_dove
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Dove...");
	loginfo("Installing Dove...");

	install_tarball("$sourceroot/progs_dove.tgz", "$destroot");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

#
# Install the files to be doled out to systems mounting /d/daisy/export.
#
sub install_dole
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Copying Dole Files to $destroot/export...");
	loginfo("Copying Dole Files to $destroot/export...");

	install_tarball("$sourceroot/dole.tgz", "$destroot/export");

	print(" Done.\n");
	loginfo("Done.");

	return "";

}

#
# Install the daisy build info file to be referenced by the install
# script to verify that the binaries are appropriate to the platform and
# by the custom inventory program run under Altiris.
#
sub install_buildinfo
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Copying Daisy Build Info File to $destroot/config...");
	loginfo("Copying Daisy Build Info File to $destroot/config...");

	install_tarball("$sourceroot/buildinfo.tgz", "$destroot/config");

	print(" Done.\n");
	loginfo("Done.");

	return "";

}

sub install_tcc
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing TCC...");
	loginfo("Installing TCC...");

	install_tarball("$sourceroot/progs_tcc.tgz", "$destroot/tcc");

	determine_os();

	# By default, we'll assume this to be a FC5 box.
	system "cd $destroot/tcc && ln -sf tcc_fc5 tcc";

	# This could be a RH 7.2 box.
	if ($OS eq 'RH72') {
		unlink "$destroot/tcc/tcc";
		system "cd $destroot/tcc && ln -sf tcc_rh72 tcc";
	}

	# This could be a FC3 box however
	if ($OS eq 'FC3') {
		unlink "$destroot/tcc/tcc";
		system "cd $destroot/tcc && ln -sf tcc_fc3 tcc";
	}

	# This is an FC5 box.
	if ($OS eq 'FC5') {
		unlink "$destroot/tcc/tcc";
		system "cd $destroot/tcc && ln -sf tcc_fc5 tcc";
	}

	# This is an RHEL5 box.
	if ($OS eq 'RHEL5') {
		unlink "$destroot/tcc/tcc";
		system "cd $destroot/tcc && ln -sf tcc_rhel5 tcc";
	}

	# This is an RHEL6 box.
	if ($OS eq 'RHEL6') {
		unlink "$destroot/tcc/tcc";
		system "cd $destroot/tcc && ln -sf tcc_rhel6 tcc";
	}

	# This is an RHEL7 box.
	if ($OS eq 'RHEL7') {
		unlink "$destroot/tcc/tcc";
		system "cd $destroot/tcc && ln -sf tcc_rhel7 tcc";
	}

	print(" Done.\n");
	loginfo("Done.");

	return "";

}

sub install_mercury
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Mercury ...");
	loginfo("Installing Mercury ...");

	install_tarball("$sourceroot/progs_merc.tgz", "$destroot");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_marketpro
{
	my $sourceroot = $_[0];
	my $destroot= $_[1];

	print("Installing Marketpro / Custpro ...");
	loginfo("Installing Marketpro / Custpro ...");

	install_tarball("$sourceroot/data_marketpro.tgz", "$destroot");
	install_tarball("$sourceroot/progs_marketpro.tgz", "$destroot");
	install_tarball("$sourceroot/screens_marketpro.tgz", "$destroot");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_map
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Map Software ...");
	loginfo("Installing Map Software ...");

	install_tarball("$sourceroot/progs_map.tgz", "$destroot");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_pool
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Delivery Pool Software ...");
	loginfo("Installing Delivery Pool Software ...");

	install_tarball("$sourceroot/data_pool.tgz", "$destroot");
	install_tarball("$sourceroot/progs_pool.tgz", "$destroot");
	install_tarball("$sourceroot/docs_pool.tgz", "$destroot/docs");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_glexport
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing General Ledger Export ...");
	loginfo("Installing General Ledger Export ...");

	install_tarball("$sourceroot/progs_gl.tgz", "$destroot");
	install_tarball("$sourceroot/screens_gl.tgz", "$destroot");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

sub install_hospital
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Facilities Software...");
	loginfo("Installing Facilities Software...");

	install_tarball("$sourceroot/progs_hosp.tgz", "$destroot");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

#
# Install "new" data with one catch,
#
sub install_blankdata
{
	my $sourceroot = $_[0];
	my $destroot = $_[1];

	print("Installing Data Files...");
	loginfo("Installing Data Files...");

	install_tarball("$sourceroot/data_cubby.tgz", "$destroot");
	install_tarball("$sourceroot/data_dsy.tgz", "$destroot");

	print(" Done.\n");
	loginfo("Done.");

	return "";
}

#=========================================#
# +-------------------------------------+ #
# | Section Begin: Daisy Data Migration | #
# +-------------------------------------+ #
#=========================================#

sub linkto_daisy_data
{
	my $previousroot = $_[0];
	my $destdir = $_[1];

	system "cp --symbolic-link --force $previousroot/*.dsy $destdir";
	system "cp --symbolic-link --force $previousroot/*.pos $destdir";
	system "cp --symbolic-link --force $previousroot/*.map $destdir";
	system "cp --symbolic-link --force $previousroot/*.rep $destdir";
	system "cp --symbolic-link --force $previousroot/*.arc $destdir";
	system "cp --symbolic-link --force $previousroot/*.idx $destdir";
	system "cp --symbolic-link --force $previousroot/*.pr $destdir";
	system "cp --symbolic-link --force $previousroot/*.prc $destdir";
	system "cp --symbolic-link --force $previousroot/*.sh $destdir";
}

sub report_migrate_err
{
	my $function_name = $_[0];
	my $error_msg = $_[1];

	if ($error_msg) {
		logerror("$function_name returned \"$error_msg\". Continuing.");
	}
}

#
# Migrate data from previous versions of Daisy.
#
sub migrate_daisy_data
{
	my $destdir = $_[0];
	my $previousroot = $_[1];
	my $source_install_files_dir = $_[2];
	my $source_utils_dir = $_[3];
	my $errors = "";

	# If user specifies previous daisy version on command line, then
	# that takes precedence.
	my $prev_version = $PREV_DAISY_VERSION;

	if ($prev_version eq "") {
		$prev_version = get_prev_daisy_version($previousroot);
	}

	# if the previous version of daisy is unknown, assume 6.0.154 which
	# was a GA version of 6.0.x
	if ($prev_version eq "UNK") {
		showinfo("Assuming daisy version: $prev_version");
		$prev_version = "6.0.154";
	}

	showinfo("--> Begin Daisy Data Migration Process...");

	# Daisy 9.4 not supported in this install script
	if ( $prev_version =~ "^9\.4\." ) {
	    showinfo("error: unsupported version of Daisy: $prev_version");
	    return(1);
	}

	# Daisy 8.1 or 8.2 or 8.3 or 8.4 or 9.0 or 9.1 or 9.2 or 9.3 or 10.0 -> current
	if ( ( $prev_version =~ "^8\.(1|2|3|4)\." ) ||
	     ( $prev_version =~ "^9\.(0|1|2|3)\." ) ||
	     ( $prev_version =~ "^10\.0\." ) ) {

		showinfo("--> Migrating from Daisy: $prev_version");

		showinfo("--> Setting install type to: data_only");
		$INSTALL_TYPE = "data_only";

		migrate_daisy_datafiles($destdir, $previousroot);

		my @special_dirs = ("backup.dir", "tfm");
		foreach my $dirname (@special_dirs) {
		    migrate_daisy_special_dir_files($destdir, $previousroot, $dirname);
		}

		migrate_daisy_log_dir($destdir, $previousroot);

		migrate_daisy_cc_dirs($destdir, $previousroot);

		migrate_daisy_edir_files($destdir, $previousroot);

		migrate_daisy_delta_edir_files($destdir, $previousroot);

		# set aside new version of "crdinet.pos" for 10.0
		my $new_file = "crdinet.pos";
		my $new_file_path = "$destdir/crdinet.pos";
		my $saved_file_path = $new_file_path . $$;
		if (rename($new_file_path, $saved_file_path)) {
		    showinfo("--> New version of file set aside: $new_file");
		}
		else {
		    showerror("could not set aside new version of: $new_file");
		}

		# Unconditionally copy files over from the previous version of Daisy.
		showinfo("--> Migrating *.pos and *.dsy files: $previousroot -> $destdir");
		system("cp $previousroot/*.pos $destdir");
		system("cp $previousroot/*.dsy $destdir");

		# restore version of "crdinet.pos" that was set aside
		if (-e $saved_file_path) {
		    if (rename($saved_file_path, $new_file_path)) {
			showinfo("--> Installed new version of: $new_file");
		    }
		    else {
			showerror("could not install new version of: $new_file");
		    }
		}

		# This was something that should have always been done but
		# it never was before... tracker 166480.
		if (-f "$previousroot/audit.log") {
		    showinfo("--> Migrating audit.log: $previousroot -> $destdir");
		    system("cp $previousroot/audit.log $destdir");
		}

		# migrate action and event files - new for 9.3
		# if updating from a release before 9.3, ie 9.0, 9.1 or 9.2,
		# install new blank action and event files.
		if ($prev_version =~ "^9\.(0|1|2)\.") {
		    showinfo("--> Installing new action/event files: $destdir");
		    migrate_daisy_action_event_files($destdir, $source_install_files_dir);
		}

		# migrate cubby files - the format of cubby files changed
		# in 9.3 so special care must be taken when migrating cubby
		# files
		if ( ($prev_version =~ "^9\.(0|1|2|3)\.") ||
		     ($prev_version =~ "^10\.0\." ) ) {
		    showinfo("--> Migrating cubby files: $destdir");
		    migrate_daisy_cubby_files($destdir, $previousroot, $SOURCEROOT);
		}

		# at this point, assume that some version of ostools is installed.
		# if the default daisy database dir, ie /d/daisy, is being upgraded,
		# the one and only one ostools config file located therein can now
		# be migrated.
		migrate_ostools_config($previousroot);

		# before rotating keys, run Daisy 9.2 data file convertors
		if ($DAISY92_DATA_CONVERSION) {
		    showinfo("--> Daisy 9.2 data file conversion: $destdir");
		    my @convertors = qw(
			cust92
			pos92
		    );
		    foreach my $util (@convertors) {
			if (-f "$destdir/utils/$util") {
			    my $rc = system("cd $destdir; $destdir/utils/$util");
			    if ($rc == 0) {
			        showinfo("--> successful data file conversion with: $util");
			    }
			    else {
				logerror("data file conversion error from $util: $rc");
				return(1);
			    }
			}
			else {
			    logerror("data file convertor does not exist: $util");
			}
		    }
		}

		# back to rotating the keys.  The "--rotate-keys" command line
		# option is TRUE by default, but it can be negated to not do
		# the key rotation.
		if ($ROTATE_KEYS) {
		    $errors = daisy8_rotatekeys($destdir, $previousroot, $source_install_files_dir);
		    if ($errors) {
			    logerror("key rotation returned \"$errors\"... exiting.");
			    return 1;
		    }
		}

		#
		# this call was added per cmoth and tracker 193597.
		# only run cardfix if updating from 9.3.x.
		#
		if ( $prev_version =~ "^9\.3\." ) {
		    my $utility = "cardfix";
		    if (-f "$destdir/utils/$utility") {
			my $exit_status = system("cd $destdir && ./utils/$utility");
			if ($exit_status == 0) {
			    showinfo("--> successful: $utility");
			}
			else {
			    logerror("$utility returned exit status: $exit_status");
			    return(1);
			}
		    }
		    else {
			logerror("utility does not exist: $utility");
		    }
		}

		return 0;
	}

	# Daisy 8.0 -> current
	if ( $prev_version =~ "^8\.0\." ) {

		$errors = daisy65_to_daisy65($destdir, $previousroot, $source_install_files_dir);
		report_migrate_err("daisy65_to_daisy65()", $errors);

		$errors = daisy8_rotatekeys($destdir, $previousroot, $source_install_files_dir);
		if ($errors) {
			logerror("Data migration to daisy8 returned \"$errors\"... exiting.");
			return 1;
		}

		return 0;
	}

	# Daisy 6.5 -> current
	# Daisy 7.0 -> current
	# Daisy 7.1 -> current
	if ( $prev_version =~ "^(6\.5\.|7\.\\d.)" ) {

		$errors = daisy65_to_daisy65($destdir, $previousroot, $source_install_files_dir);
		report_migrate_err("daisy65_to_daisy65()", $errors);

		$errors = daisy8_rotatekeys($destdir, $previousroot, $source_install_files_dir);
		if ($errors) {
			logerror("Data migration to daisy8 returned \"$errors\"... exiting.");
			return 1;
		}

		return 0;
	}

	# Daisy 6.0 -> current
	# Daisy 6.1 -> current
	if ( $prev_version =~ "^6\.(0|1)\." ) {
	
		$errors = daisy60_to_daisy65($destdir, $previousroot, $source_install_files_dir);
		report_migrate_err("daisy60_to_daisy65()", $errors);

		$errors = daisy65_to_daisy65($destdir, $previousroot, $source_install_files_dir);
		report_migrate_err("daisy65_to_daisy65()", $errors);

		$errors = daisy8_rotatekeys($destdir, $previousroot, $source_install_files_dir);
		if ($errors) {
			logerror("Data migration to daisy8 returned \"$errors\"... exiting.");
			return 1;
		}

		return 0;
	}


	# If we don't know, then assume this is a version 4 shop.
	$errors = daisy407_to_daisy6($destdir, $previousroot, $source_install_files_dir);
	report_migrate_err("daisy407_to_daisy6()", $errors);

	$errors = daisy8_rotatekeys($destdir, $previousroot, $source_install_files_dir);
	if ($errors) {
		logerror("Data migration to daisy8 returned \"$errors\"... exiting.");
		return 1;
	}

	return 0;
}


sub migrate_daisy_special_dir_files
{
    my ($destdir, $previousroot, $dirname) = @_;

    # if there are any files in the directory, migrate them
    my @files = glob("$previousroot/$dirname/*");
    if (@files) {
	system "cp $previousroot/$dirname/* $destdir/$dirname";
    }
}


#
# The /d/backup dir used to contain the scripts called from cron,
# among other files.  But now the only script called from cron is the new
# rtibackup.pl script.  So kill the old cron scripts.
#
# Note: the backup dir does not contain any data, just scripts and logs.
#
sub migrate_daisy_backup_dir
{
	my $destdir = $_[0];

	my @oldbucronfiles = qw(
		daisyback
		dayback
		dback
		monthback
	);

	foreach my $file (@oldbucronfiles)  {
		if (-d "$destdir/../backup/$file") {
			system("rm -f $destdir/../backup/$file");
		}
	}
}

#
# The /d/config dir seems to be a dumping group for misc config files
# concerning daisy and the host os... there doesnt' really seem to be
# a need for these files, but for backward compatability...
#
sub migrate_daisy_config_dir
{
	my $destdir = $_[0];

}

#
# The /d/menus dir contains the "crawlmenus".  These can be edited
# by support and can be unique to the site.  Thus, copy over any
# existing menus.  Also, note that some may be have been deleted
# by support if the site has not purchased the full daisy product,
# so don't copy over any missing menus - they are not missing.
#
sub migrate_daisy_menus_dir
{
	my $destdir = $_[0];

}

#
# The /d/putty dir contains the putty config files.  These can be edited
# by support and can be unique to the site.  Thus, copy over any existing
# files.
#
sub migrate_daisy_putty_dir
{
	my $destdir = $_[0];

}

#
# The /d/server dir contains the daisy session scripts.  These can be edited
# by support and can be unique to the site.  Thus, copy over any existing
# files.
#
sub migrate_daisy_server_dir
{
	my $destdir = $_[0];

}

#
# The /d/startup dir contains the daisy startup scripts.  These can be edited
# by support and can be unique to the site.  Thus, copy over any existing
# files.
#
sub migrate_daisy_startup_dir
{
	my $destdir = $_[0];

}


#
# Migrate some "special" script files... they are "special" because they
# may be been modified in the field and any changes are required to be
# preserved.
#
sub migrate_daisy_scripts
{
	my $previousroot = $_[0];
	my $destdir = $_[1];
	my $strerror = "";

	unless ( (-d $previousroot) && (-d $destdir) ) {
		return;
	}

	my @special_scripts = qw(
		dodayend.sh
		pdayend.sh
		pdayend.new
		ppool.sh
		proute.sh
	);

	showinfo("Migrating Daisy Special Script Files...");

	for my $script (@special_scripts) {
		if (-f "$previousroot/$script") {
			# first save the new version
			system("mv $destdir/$script $destdir/$script.orig");
			$strerror = system_exit_status($?);
			if ($strerror) {
				showerror("Error migrating \"$script\": could not save new version");
			}

			# then migrate the old version
			system("cp $previousroot/$script $destdir");
			$strerror = system_exit_status($?);
			if ($strerror) {
				showerror("Error migrating \"$script\": could not copy from $previousroot");
			} else {
				showinfo("Success migrating \"$script\"");
			}
		}
	}
}


#
# 168352
#
# Copy custom scripts written by the Daisy Support team from
# the previous daisy database dir into the new database dir.
# The definition of "custom scripts" are those files which
# are named "something.sh" and didn't originate from the
# Daisy install iso.
#
sub migrate_utils_scripts
{
    my ($previousroot, $destdir) = @_;
    my $rc = 0;

    # get list of files in old "utils" dir
    my @utils_scripts = glob("$previousroot/utils/*.sh");

    showinfo("Migrating Custom Daisy Support Scripts...");

    # look for scripts in old "utils" dir not in new "utils" dir
    foreach my $src_script (@utils_scripts) {

	my $src_script_name = basename($src_script);
	my $dst_script_path = "$destdir/utils/$src_script_name";
	if (-e $dst_script_path) {
	    next;
	}

	system("cp $src_script $dst_script_path");

	if (-e $dst_script_path) {
	    showinfo("Success migrating \"$src_script\"");
	}
	else {
	    showerror("Error migrating \"$src_script\"");
	    $rc = 1;
	}
    }

    return($rc);
}


sub migrate_ostools_config
{
    my ($previousroot) = @_;

    my $prev_config_path = "$previousroot/config/backups.config";
    my $default_config_path = "/d/daisy/config/backups.config";

    showinfo("--> Migrating OSTools Backup Config File...");

    # only need to migrate when updating /d/daisy
    unless ($previousroot =~ /^\/d\/daisy-/) {
	showinfo("--> Migration unnecessary for $previousroot");
	return(0);
    }

    # only need to migrate if there is an old config file
    unless (-e $prev_config_path) {
	showinfo("--> Previous config file does not exist: $prev_config_path");
	showinfo("--> Migration unnessary");
	return(0);
    }

    # if there is an existing default config file, save it
    my $saved_path = $default_config_path . ".orig";
    if (-e $default_config_path) {
	system("mv $default_config_path $saved_path");
    }
    if (-e $default_config_path) {
	showerror("Error saving existing default config file: $default_config_path");
    }
    else {
	showinfo("--> Existing config file saved: $saved_path");
    }

    # finally, try to migrate the file
    system("cp $prev_config_path $default_config_path");
    if (-e $default_config_path) {
	showinfo("--> Migration of config file successful: $prev_config_path");
    }
    else {
	showerror("Error migrating config file: $prev_config_path");
    }

    return(0);
}


#
# The Daisy edir file "control.tel" contains the edir version string
# as the first line of the file.  For example, the line from for the
# MJJ quarter, should look like:
#
#	Teleflora May-Jul 2010
#
# We just want the quarter name in the form of the 3 letter abbreviation and
# the year... so this needs to be transformed into:
#
#	MJJ2010
#
sub get_daisy_edir_version
{
    my $newroot = $_[0];
    my $prevroot = $_[1];

    my $ctrl_file_line1 = "";
    my $edir_version = "";

    # In daisy, the eDirectory version is in the file 'control.tel',
    # which is a cleartext file.
    unless (open(FILE, '<', "$prevroot/control.tel")) {
	showerror("Can't open Daisy eDirectory control file: $prevroot/control.tel");
	return($edir_version);
    }

    $ctrl_file_line1 = <FILE>;
    close(FILE);
    chomp($ctrl_file_line1);

    my @edir_tuple = split(/\s/, $ctrl_file_line1);

    if ($edir_tuple[1] =~ /Nov.*-.*Jan/) {
	$edir_version = "NDJ";
    }
    elsif ($edir_tuple[1] =~ /Feb.*-.*Apr/) {
	$edir_version = "FMA";
    }
    elsif ($edir_tuple[1] =~ /May.*-.*Jul/) {
	$edir_version = "MJJ";
    }
    elsif ($edir_tuple[1] =~ /Aug.*-.*Oct/) {
	$edir_version = "ASO";
    }
    $edir_version .= $edir_tuple[2];

    return($edir_version);
}


sub set_signal_handlers
{
    my $handler = $_[0];

    $SIG{'STOP'} = $handler;
    $SIG{'TSTP'} = $handler;
    $SIG{'INT'} = $handler;
}


#
# Look for the florist directory patch on the server and
# install it if found.  Else, install the patch on the ISO.
#
sub install_florist_directory_patch
{
    my ($newroot, $sourceroot) = @_;

    showinfo("--> Installing Daisy Florist Directory patch for: $newroot");

    # ignore INTERRUPT to ensure we clean up
    set_signal_handlers("IGNORE");

    my $altiris_cmd = "perl applypatch.pl";
    my $altiris_opts = "--daisydir=$newroot --norestart --log-stderror";
    my $altiris_args = "*.patch";

    my $altiris_tmp_dir = "/tmp/florist_directory_patch.$$";
    system("rm -rf $altiris_tmp_dir");
    system("mkdir $altiris_tmp_dir");

    my $altiris_patch_dir = "/d/FLORDIR";
    unless (-d $altiris_patch_dir) {
	$altiris_patch_dir = "$sourceroot/edirectory";
    }

    system("cp $altiris_patch_dir/applypatch.pl $altiris_tmp_dir");
    system("cp $altiris_patch_dir/*.patch $altiris_tmp_dir");
    my $rc = system("cd $altiris_patch_dir && $altiris_cmd $altiris_opts $altiris_args");
    if ($rc == 0) {
	loginfo("[flordir patch] florist directory patch install successful");
    }
    else {
	my $strerror = system_exit_status($rc);
	showerror("florist directory patch script returned non-zero status: $rc");
	showerror("$strerror");
    }

    # cleanup temp working dir
    system("rm -rf $altiris_tmp_dir");

    # restore signal handlers
    set_signal_handlers("DEFAULT");

    showinfo("--> Daisy Florist Directory patch installation complete");
}


sub migrate_daisy_delta_edir_files
{
    my $newroot = $_[0];
    my $prevroot = $_[1];

    showinfo("--> Begin migrating Daisy delta edir files: $prevroot -> $newroot");

    my @files_to_copy = qw(
	edir_installbase.pl
	edir_update.pl
	edir_revert.pl
	edir_update.conf
    );

    foreach (@files_to_copy) {
	my $sub_dir = "bin";
	if (/\w+\.conf$/) {
	    $sub_dir  = "config";
	}
	my $src_path = "$prevroot/$sub_dir/$_";
	my $dst_path = "$newroot/$sub_dir/$_";
	if (-f $src_path) {
	    system("cp -p $src_path $dst_path");
	    $strerror = system_exit_status($?);
	    if ($strerror) {
		showerror("The copy of $src_path to $dst_path returned an error");
		showerror("$strerror");
	    }
	    else {
		showinfo("--> Successful migration of: $src_path -> $dst_path");
	    }
	}
    }

    showinfo("--> Migrating Daisy delta edir files complete");
}

sub migrate_daisy_edir_files
{
    my $newroot = $_[0];
    my $prevroot = $_[1];

    showinfo("--> Begin migrating Daisy eDirectory files: $prevroot -> $newroot");

    # The only eDirectory files we need to copy, if they exist, are:
    #	--> the Teleflora files
    #	--> the FTD files
    #	--> the US CDIFCATM file
    #
    # The florist's note files, "fnotdat.pos" and "fnotidx.pos" will be
    # copied elsewhere when a copy of "*.pos" from old to new is done.
    #
    # The facilities note files, "hnotdat.hsp" and "hnotidex.hsp" will be
    # copied elsewhere also.

    my @files_to_copy = qw(
	*.tel
	*.ftd
	us-cdifcatm.txt
    );

    foreach my $src (@files_to_copy) {
	# determine if there any files to copy before trying to copy them
	my $copy_required = 0;
	if ($src eq 'us-cdifcatm.txt') {
	    if (-e "$prevroot/$src") {
		$copy_required = 1;
	   }
	}
	else {
	    my @files = glob("$prevroot/$src");
	    if (@files) {
		$copy_required = 1;
	    }
	}

	if ($copy_required) {
	    system("cp -p $prevroot/$src $newroot");
	    $strerror = system_exit_status($?);
	    if ($strerror) {
		showerror("The copy of $prevroot/$src to $newroot returned an error");
		showerror("$strerror");
	    }
	    else {
		showinfo("--> Successful migration of: $prevroot/$src -> $newroot");
	    }
	}
    }

    showinfo("--> Migrating Daisy eDirectory files complete");
}


#
# Migrate a Daisy credit card processing directory.
#
# A directory with the name "crd[2-5]" in a daisy database directory
# is a daisy credit card processing directory.  These directories are
# only present in a small pertcentage of Daisy shops.
#
sub migrate_cc_dir
{
    my $cc_dir = $_[0];
    my $oldroot = $_[1];
    my $newroot = $_[2];

    if (-d "$oldroot/$cc_dir") {

	showinfo("--> Begin migrating Daisy credit card directory: $oldroot/$cc_dir");

	# first, copy the old cc directory over to the new daisy db dir
	system("cp -pr $oldroot/$cc_dir $newroot");
	my $strerror = system_exit_status($?);
	if ($strerror) {
	    showerror("Error migrating $oldroot/$cc_dir to $newroot: Could not copy directory");
	    showerror("$strerror");
	}

	# copy the files
	if (-d "$newroot/$cc_dir") {

	    # here is the list of files that must be copied from the
	    # new daisy db dir to the daisy cc dir that was just moved.
	    my @new_crd_files = qw(
		authdat.pos
		crd
		crd_scr.scr
		crdmenu
		crdpos
		crdterm
		cutilscr.scr
		prsetscr.scr
		panelp.cnf
		settfile.pos
	    );

	    foreach my $filename (@new_crd_files) {
		if (-f "$newroot/$filename") {
		    system("cp $newroot/$filename $newroot/$cc_dir");
		    $strerror = system_exit_status($?);
		    if ($strerror) {
			showerror("Error copying $newroot/$filename to $newroot/$cc_dir");
			showerror("$strerror");
		    }
		}
		else {
		    showerror("Missing file: $newroot/$filename");
		}
	    }

	    # Finally, copy tcc.
	    system("cp -pr $newroot/tcc $newroot/$cc_dir");
	    $strerror = system_exit_status($?);
	    if ($strerror) {
		showerror("Error copying $newroot/tcc to $newroot/$cc_dir");
		showerror("$strerror");
	    }
	}

	showinfo("--> Done migrating Daisy credit card directory: $oldroot/$cc_dir");
    }
}


sub migrate_daisy_cc_dirs
{
    my $newroot = $_[0];
    my $oldroot = $_[1];

    # migrate possible credit card processing dirs
    my @cc_dirs = qw(
	crd2
	crd3
	crd4
	crd5
    );

    foreach (@cc_dirs) {
	migrate_cc_dir($_, $oldroot, $newroot);
    }
}


sub migrate_daisy_log_dir
{
    my ($newroot, $oldroot) = @_;

    if (-d "$oldroot/log") {
	showinfo("--> Begin migrating Daisy log directory: $oldroot/log -> $newroot/log");

	system("cp -pr $oldroot/log/* $newroot/log");
	my $strerror = system_exit_status($?);
	if ($strerror) {
	    showerror("Error copying $oldroot/log to $newroot/log");
	    showerror("$strerror");
	}
	else {
	    showinfo("--> Successful migration of: $oldroot/log -> $newroot/log");
	}
	showinfo("--> Migrating Daisy log directory complete");
    }

    return(1);
}


#
# These are files which are copied from any generic "older"
# daisy distro, to the current daisy version installed. Ie,
# these are all of the "unconditional file copies".
#
sub migrate_daisy_datafiles
{
	my $newroot = $_[0];
	my $oldroot = $_[1];
	my @files = ();
	my $filename = "";

	if($newroot eq "") {
		return "";
	}
	if($oldroot eq "") {
		return "";
	}

	showinfo("--> Begin migrating generic Daisy data files: $oldroot -> $newroot");

	# a change with Daisy 9.1 - can't unconditionally copy
	# the *.idx files anymore... there is one that must not
	# be copied over.
	@files = glob("$oldroot/*.idx");
	foreach (@files) {
	    next if ($_ eq "$oldroot/wordlist.idx");	# skip this one

	    system("cp $_ $newroot");
	}

	# Unconditionally copy over legacy data files.
	copy_if_exists("$oldroot/*.map", $newroot);
	copy_if_exists("$oldroot/*.rep", $newroot);
	copy_if_exists("$oldroot/*.sal", $newroot);
	copy_if_exists("$oldroot/*.arc", $newroot);
	copy_if_exists("$oldroot/*.pr", $newroot);
	copy_if_exists("$oldroot/*.prc", $newroot);
	copy_if_exists("$oldroot/*.sh", $newroot);
	copy_if_exists("$oldroot/*.uc", $newroot);
	copy_if_exists("$oldroot/hnot*.hsp", $newroot);
	copy_if_exists("$oldroot/printers", $newroot);
	copy_if_exists("$oldroot/dodayend.sh", $newroot);
	copy_if_exists("$oldroot/proute.sh", $newroot);
	copy_if_exists("$oldroot/pdayend.sh", $newroot);
	copy_if_exists("$oldroot/ff.txt", $newroot);
	copy_if_exists("$oldroot/macros", $newroot);
	copy_if_exists("$oldroot/pospool/*", "$newroot/pospool/");


	# Here,we need to pick out specific naming. Easier to use perl regexes.
	opendir DIR, "$oldroot";
	@files = readdir DIR;
	closedir DIR;
	foreach $filename (@files) {

		# Copy Special Product Information Files.
		# files are of the form: siNNNN...\.txt
		#
		if($filename =~/(si)([[:digit:]])+\.txt/i) {
			copy_if_exists("$oldroot/$filename", "$newroot/$filename");
		}

		# Copy Drawer "Control" Files over.
		# xxawctrl.pos
		if($filename =~ /..awctrl\.pos/i) {
			copy_if_exists("$oldroot/$filename", "$newroot/$filename");
		}

		# Re-Create "xxawdat.pos" and "xxawidx.pos
		if($filename =~ /..awdat\.pos/i) {
			next if ($filename eq 'drawdat.pos');
			copy_if_exists("$newroot/drawdat.pos", "$newroot/$filename");
		}
		if($filename =~ /..awidx\.pos/i) {
			next if ($filename eq 'drawidx.pos');
			copy_if_exists("$newroot/drawidx.pos", "$newroot/$filename");
		}

		# Re-Create "xxxzdat.pos" and "xxxzidx.pos
		if($filename =~ /..tzdat\.pos/i) {
			next if ($filename eq 'dgtzdat.pos');
			copy_if_exists("$newroot/dgtzdat.pos", "$newroot/$filename");
		}
		if($filename =~ /..tzidx\.pos/i) {
			next if ($filename eq 'dgtzidx.pos');
			copy_if_exists("$newroot/dgtzidx.pos", "$newroot/$filename");
		}

		# Migrate Control.ftd  over s.t. the edirectory install script can pick it up.
		if($filename =~ /control\.ftd/i) {
			copy_if_exists("$oldroot/$filename", "$newroot/control.ftd");
		}
	}
}


# migrate action and event files - new for 9.3
#
# if updating from a release before 9.3, ie 9.1 or 9.2,
# install new blank action and event files.
#
sub migrate_daisy_action_event_files
{
    my ($newroot, $source_dir) = @_;

    # this is the source of a fresh copy of the data files
    my $source_tarball = $source_dir . '/' . 'data_daisy.tgz';

    # this is the list of data files to get
    my @action_event_data_files = qw(
	actndat.pos
	actnidx.pos
	evntdat.pos
	evntidx.pos 
    );

    system("cd $newroot && tar -xzf $source_tarball @action_event_data_files");
    my $strerror = system_exit_status($?);
    if ($strerror) {
	showerror("Error installing new blank instances of @action_event_data_files");
	showerror("$strerror");
    }
}


sub cubby_file_chksum
{
    my ($file_path) = @_;

    my $md5sum = undef;

    if (open(my $fh, '<', $file_path)) {
	my $ctx = Digest::MD5->new;
	$ctx->addfile($fh);
	$md5sum = $ctx->hexdigest;
	close($fh);
    }

    return($md5sum);
}


sub cubby_files_calculate_chksums
{
    my ($cubby_dir) = @_;

    my %cubby_chksums = ();

    my @cubby_files = glob("$cubby_dir/poslist.*");

    for my $file_path (@cubby_files) {

	my $file_name = basename($file_path);
	my $file_chksum = cubby_file_chksum($file_path);
	unless (defined($file_chksum)) {
	    logerror("could not calculate file chksum: $file_path");
	    %cubby_chksums = ();
	    last;
	}
	else {
	    $cubby_chksums{$file_name} = $file_chksum;
        }
    }

    return(%cubby_chksums);
}


sub cubby_files_parse_chksum_file
{
    my ($cubby_chksum_path) = @_;

    my %cubby_chksums = ();

    if (open(my $cfh, '<', $cubby_chksum_path)) {
	while (<$cfh>) {
	    chomp;
	    if (/^(\S+)  (\S+)$/) {
		my $cubby_chksum = $1;
		my $cubby_file_name = $2;
		$cubby_chksums{$cubby_file_name} = $cubby_chksum;
	    }
	}
	close($cfh);
    }
    else {
	logerror("could not open 9.2 cubby checksum file: $cubby_chksum_path");
    }

    return(%cubby_chksums);
}


sub cubby_file_copy_all
{
    my ($newroot, $prevroot) = @_;

    my @cubby_files = glob("$prevroot/cubby/poslist.*");
    foreach my $cubby_file (@cubby_files) {
	my $cubby_file_name = basename($cubby_file);
	$cubby_file_name = cubby_file_convert_suffix($cubby_file_name);
	system("cp -p $cubby_file $newroot/cubby/$cubby_file_name");
    }

    return(1);
}


sub cubby_file_convert_suffix
{
    my ($cubby_file) = @_;

    if ($cubby_file =~ /(\.[^.]{3})$/) {
	$cubby_file =~ s/\..(..)$/.9$1/;
    }

    return($cubby_file);
}


#
# migrate cubby files
#
# the format of cubby files changed in 9.3 so special care
# must be taken when migrating cubby files.
#
# the cubby dir of the new tree will contain the unmodified
# 9.3 cubby files.
#
# the old cubby files will be copied to the new tree.
#
# the new cubby files will be copied to the new tree.
#
# yes, the old files will copy over the new files.
#
sub migrate_daisy_cubby_files
{
    my ($newroot, $previousroot, $sourceroot) = @_;

    my $dst_dir = "$newroot/cubby";

    my @cubby_file_types = qw(
	custpro
	poslist
    );

    # copy old cubby files to new tree
    foreach my $cubby_file_type (@cubby_file_types) {
	my @cubby_files = glob("$previousroot/cubby/$cubby_file_type.*");
	for my $cubby_file_path (@cubby_files) {
	    my $cubby_file_name = basename($cubby_file_path);
	    system("cp -p $cubby_file_path $dst_dir/$cubby_file_name");
	}
    }

    # Per CMoth in tracker 194446, do NOT copy new cubby files
    # over the old one when upgrading from 9.3 to 10.0 or
    # from 10.0.x to 10.0.y.
    #
    # copy new custpro files over old files in the new tree
    #install_tarball("$sourceroot/data_marketpro.tgz", $newroot);

    # copy new poslist files over old files in the new tree
    #install_tarball("$sourceroot/data_cubby.tgz", $newroot);

    return(1);
}


#
# Migrate and convert datafiles from Daisy 4.07 to Daisy 6.
#
sub daisy407_to_daisy6
{
	my $newroot = $_[0];
	my $oldroot = $_[1];
	my $source_install_files_dir = $_[2];
	my @files = ();
	my $filename = "";
	my $parentdir = "";

	if($newroot eq "") {
		return "Invalid parameter 'newroot'";
	}
	if($oldroot eq "") {
		return "Invalid parameter 'oldroot'";
	}

	showinfo("Begin Daisy 4.0.7 to Daisy 6 Conversion Process...");

	# Make sure our prerequisite conversion utilities are present.
	foreach $filename ('splitconv', 'delvconv', 'tercreat', 'tconvert') {
		unless (-f "$newroot/utils/$filename") {
			return "Could not find Conversion program \"$filename\" in Daisy6 utils directory.";
		}
	}

	# Move "unconditional copy" files over.
	migrate_daisy_datafiles($newroot, $oldroot);


	# Make sure we are using 'fresh' copies of these files.
	system "cd $newroot && tar -xzf $source_install_files_dir/data_daisy.tgz settfile.pos crdinput.pos authdat.pos";


	# Migrate Cubby Files
	# Please note! This isn't a straight copy! These files are
	# parsed and likely renamed in the conversion!
	print "Migrating Custom Reports (Cubbyfiles) ...";
	opendir DIR, "$oldroot/cubby";
	@files = readdir DIR;
	closedir DIR;
	foreach $filename (@files) {
		migrate_cubbyfile("$oldroot/cubby/$filename", "$newroot/cubby");
	}

	showinfo("Done Daisy 4.0.7 to Daisy 6 Conversion Process.");



	# These copies are conditional, some files should be copied, and some should not.
	opendir DIR, "$oldroot";
	@files = readdir DIR;
	closedir DIR;
	foreach $filename (@files) {

		# something.pos
		if($filename =~ /\.pos$/i) {

			# These are all of the "exceptions" we are not supposed
			# to copy over.
			# Any .pos file which does *not* meet an exception below, is copied.
			if (
			($filename !~ /^resp.*.\.pos$/i)  
			&& ($filename !~ /^.*.awdat\.pos$/i) 
			&& ($filename !~ /^.*.awidx\.pos$/i) 
			&& ($filename !~ /^.*.tzdat\.pos$/i) 
			&& ($filename !~ /^.*.tzidx\.pos$/i) 
			&& ($filename !~ /^authdat\.pos$/i)
			&& ($filename !~ /^crdinput\.pos$/i)
			&& ($filename !~ /^pend.*.\.pos$/i)
			&& ($filename !~ /^settfil.*.\.pos$/i) 
			&& ($filename !~ /^ndcbatch\.pos$/i) 
			&& ($filename !~ /^ndcinput\.pos$/i) 
			&& ($filename !~ /^dgtz.*.\.pos$/i)
			&& ($filename !~ /^merc.*.\.pos$/i)
			&& ($filename !~ /^authdat\.pos$/i) 
			&& ($filename !~ /^dmgrdat\.pos$/i) 
			&& ($filename !~ /^dmgridx\.pos$/i) 
			&& ($filename !~ /^tinpdat\.pos$/i) 
			&& ($filename !~ /^tinpidx\.pos$/i) 
			&& ($filename !~ /^tpnddat\.pos$/i) 
			&& ($filename !~ /^tpndidx\.pos$/i) 
			&& ($filename !~ /^tsntdat\.pos$/i) 
			&& ($filename !~ /^tsntidx\.pos$/i) 
			&& ($filename !~ /^trcvdat\.pos$/i) 
			&& ($filename !~ /^trcvidx\.pos$/i) 
			) {
				system "cp $oldroot/$filename $newroot/$filename";
			}
		}

		# Copy *.dsy, with exceptions.
		if($filename =~ /\.dsy$/i) {
			if (
			($filename !~ /^workdat\.dsy$/i) 
			&& ($filename !~ /^workidx\.dsy$/i) 
			&& ($filename !~ /^carddat\.dsy$/i) 
			) {
				system "cp $oldroot/$filename $newroot/$filename";
			}

		}

		# Migrate Mercury Settings
		if(
		($filename =~ /mercmsg\.txt$/i) 
		|| ($filename =~ /mercctrl.pos$/i)
		) {
			system "cp $oldroot/$filename $newroot/$filename";
		}
	}


	# Make sure we are using 'fresh' copies of these files.
	system "cd $newroot && tar -xzf $source_install_files_dir/data_daisy.tgz settfile.pos crdinput.pos authdat.pos";


	# Change into our new working directory to run our conversion utils.
	# But save the current working directory first so we can get back.
	$parentdir = getcwd;
	chdir "$newroot";

	#
	# Delivery Manager Conversion 	
	# Note that delvconf looks for a magic filename of dmgrxxx.old
	#
	showinfo("Converting Delivery Manager Files...");
	if(-f "$oldroot/dmgrdat.pos") {
		system "cp $oldroot/dmgrdat.pos $newroot/dmgrdat.old";
	}
	if(-f "$oldroot/dmgridx.pos") {
		system "cp $oldroot/dmgridx.pos $newroot/dmgridx.old";
	}
	if(-f "$oldroot/tcktdat.pos") {
		system "cp $oldroot/tcktdat.pos $newroot/tcktdat.old";
	}
	if(-f "$oldroot/tcktidx.pos") {
		system "cp $oldroot/tcktidx.pos $newroot/tcktidx.old";
	}

	unlink "$newroot/ttbddat.pos";
	unlink "$newroot/ttbdidx.pos";
	system "utils/delvconv";
	unlink "$newroot/dmgrdat.old";
	unlink "$newroot/dmgridx.old";
	unlink "$newroot/tcktdat.old";
	unlink "$newroot/tcktidx.old";


	showinfo("Converting Split Payments...");
	system "utils/splitconv";


	showinfo("Converting Dove Files...");
	# Note the ".old" extension is magic; tconvert looks for that.	
	foreach $filename ('tinpdat', 'tinpidx', 'tpnddat', 'tpndidx', 'tsntdat', 'tsntidx', 'trcvdat', 'trcvidx') {
		if(-f "$oldroot/$filename.pos") {
			system "cp $oldroot/$filename.pos $newroot/$filename.old";
		}
	}
	system "utils/tercreat";
	system "utils/tconvert";
	foreach $filename ('tinpdat', 'tinpidx', 'tpnddat', 'tpndidx', 'tsntdat', 'tsntidx', 'trcvdat', 'trcvidx') {
		unlink "$newroot/$filename.old";
	}




	# Customer File Encryption
	showinfo("Encrypting Customer files...");
	system "utils/custencr";


	chdir "$parentdir";

	showinfo("Done.");

	return "";
}

#
# Given an "old" cubbyfile, and a new directory to move to, this
# sub will do the following:
# 1) Identify this cubbyfile. Is it a custom? If not, we don't care.
# 2) If this is a custom cubby, copy into new directory using the "next available" number.
#
sub migrate_cubbyfile
{
	my $oldfile = $_[0];
	my $newdir = $_[1];
	my $lockfound = 0;
	my $basename = "";
	my $highest_value = 0;
	my $thisvalue = 0;
	my $filename = "";
	my @newfiles = ();


	if(! -f $oldfile) {
		return 0;
	}
	if(! -d $newdir) {
		return 0;
	}

	# filename.NNN
	if( ! $oldfile =~ /\.[[:digit:]]{3}/) {
		return 0;
	}


	# Look for "[CubbyLocked]"
	$lockfound = 0;
	open FILE, $oldfile;
	while (<FILE>) {
		if (/\[CubbyLocked\]/) {
			$lockfound = 1;
		}
	}
	close FILE;


	# This is a "locked" cubby file. Don't bother migrating it.
	# If we get past this point, we know that "oldfile" is indeed, a 
	# Custom Cubbyfile.
	if($lockfound != 0) {
		return "";
	}

	# What is the "name" of this cubbyfile anyhow?
	# For instance "/foo/bar/poslist.000" would just be "poslist".
	$basename = basename "$oldfile", "[[:digit:]]{3}";
	$basename =~ s/\.[[:digit:]]{3}//;




	# Now figure out our "next available number" for this new file.
	@newfiles = ();
	opendir DIR, "$newdir";
	@newfiles = readdir DIR;
	closedir DIR;
	foreach $filename (@newfiles) {
		if($filename =~ /$basename\.[[:digit:]]{3}/) {
			$thisvalue = $filename;

			# foo.011 -> 011
			$thisvalue =~ s/$basename\.//;
			if( int($highest_value) < int($thisvalue) ) {
				$highest_value = int ($thisvalue);
			}
		}
	}

	if($highest_value > 0) {
		$highest_value++;
	}

	# Finally, copy our file.
	$filename = sprintf ("%s.%03d", "$newdir/$basename", $highest_value);
	system "$INSTALL_CMD $oldfile $filename";
	print ".";

	return 0;
}

#
#	"Build to Build" update.
#
#	(Copy/pasted from first half of "sub daisy407_to_daisy6".  They are the
#	 same today, but may change later.)
#
sub daisy65_to_daisy65
{
	my $newroot = $_[0];
	my $oldroot = $_[1];
	my $source_install_files_dir = $_[2];
	my @files = ();
	my $filename = "";
	my $parentdir = "";


	if($newroot eq "") {
		return "";
	}
	if($oldroot eq "") {
		return "";
	}


	showinfo("Begin Daisy 6.5 to Daisy 6.5 Conversion Process...");

	migrate_daisy_datafiles($newroot, $oldroot);

	showinfo("Copying Daisy 6.5 Data Files...");

	# Unconditionally copy files over from the previous version of Daisy.
	system "cp $oldroot/*.pos $newroot";
	system "cp $oldroot/*.dsy $newroot";

	#
	# Turns out that *.dsy files are not unconditional...
	# There is one condition for copying *.dsy files:
	#	don't let the copy of carddat.dsy survive
	#
	my $datafile_exception = "$newroot/carddat.dsy";
	my $delcmd = cleanup_choose_deletion_cmd();

	if (-e $datafile_exception) {
		unless (do_system("$delcmd $datafile_exception")) {
			showerror("Could not remove $datafile_exception from $newroot.");
		}
	}

	# New settfile as, our settlement fields have changed in daisy 6.5 due
	# to Globaleast certification.
	system "cd $newroot && tar -xzf $source_install_files_dir/data_daisy.tgz settfile.pos";


	# Only copy the cubby files from the previous 6 build.
	# Do not add any "new defaults".
	system "rm -f $newroot/cubby/*";
	system "cp $oldroot/cubby/* $newroot/cubby";


	# Change into our new working directory to run our conversion utils.
	# But save the current working directory first so we can get back.
	$parentdir = getcwd;
	chdir "$newroot";



	# Customer File Encryption
	showinfo("Encrypting Customer files...");
	system "utils/custencr";

	#
	# Beta6 shops prior to build 126 should need this; though,
	# this should not affect shops if repeatedly run.
	#
	showinfo("Updating Delivery Manager Status' ...");
	system "utils/delvconv --update-delvgroup";

	# Starting with version 7.0.6, we need to run doverbl as part of update
	system "utils/doverbl";

	chdir "$parentdir";

	showinfo("Done Daisy 6.5 to Daisy 6.5 Conversion Process.");

	return "";
}

#
# Update from Daisy 6.0 to Daisy 6.5
# Update from Daisy 6.1 to Daisy 6.5
#
# Basically just blank out a specific list of data files.
#
sub daisy60_to_daisy65
{
	my $newroot = $_[0];
	my $oldroot = $_[1];
	my $source_install_files_dir = $_[2];

	# this is the source of a fresh copy of the data files
	my $source_tarball = "$source_install_files_dir/data_daisy.tgz";

	# this is the list of data files to get
	my @data_files = qw(
		settfile.pos
		crdinput.pos
		authdat.pos
	);

	system "cd $newroot && tar -xzf $source_tarball @data_files";
}

sub daisy8_to_daisy8
{
	my $newroot = $_[0];
	my $oldroot = $_[1];
	my $source_install_files_dir = $_[2];
}

sub daisy8_rotatekeys
{
	my $newroot = $_[0];
	my $oldroot = $_[1];
	my $source_install_files_dir = $_[2];
	my $strerror = "";

	#
	# First, make sure there are no numbered settle files.
	#
	showinfo("\nDisposing of Numbered Settle Files.");
	showinfo("===================================");
	cleanup_numbered_settle_files($newroot);

	#
	# Second, make sure the dove control file has been converted.
	#
	showinfo("\nVerifying Dove Control File.");
	showinfo("============================");
	update_dovectrl_high_speed($newroot);

	#
	# Third, replace omrc*.pos files with blank copies.
	#
	showinfo("\nReplacing omrc files.");
	showinfo("======================");
	cleanup_omrc_files($newroot, $source_install_files_dir);


	showinfo("Rotating Keys...");

	# Change into our new working directory to run the conversion utils.
	# But save the current working directory first so we can get back.
	my $parentdir = getcwd;
	chdir $newroot;

	my $script = "bin/rotatekeys.pl";
	system("/usr/bin/perl $script");
	if ($? == -1) {
		$strerror = "Program $script failed to execute: $!";
	} elsif ($? & 127) {
		my $signalnr = ($? & 127);
		$strerror = "Program $script died with signal $signalnr";
	} else {
		my $exitstatus = ($? >> 8);
		if ($exitstatus) {
			$strerror = "Program $script exited with value $exitstatus\n";
		}
	}
	
	chdir $parentdir;

	showinfo("Done Rotating Keys.");

	return $strerror;
}

sub set_card_data
{
	my $crddata_file = $_[0];
	my $openssl_cmd = '/usr/bin/openssl';
	my $magic_nr = 16384;

	showinfo("--> Writing random bytes to: $crddata_file");

	unless (-x $openssl_cmd) {
		showerror("The \"$openssl_cmd\" program is not installed on this system.");
		return;
	}

	system("$openssl_cmd rand $magic_nr > $crddata_file");
	if($? != 0) {
		showerror("Could not initialize: $crddata_file.");
		return;
	}

	unless (-e $crddata_file) {
		showerror("File not found: $crddata_file.");
		return;
	}

	my $filesize = -s $crddata_file;
	unless ($filesize == $magic_nr) {
		showerror("File size: $filesize, expecting: $magic_nr: $crddata_file.");
	}

	showinfo("--> Random bytes written to: $crddata_file");
}


#
# New install only.
# Set the "country" byte, ie, is this a Canadian or US build?
#
sub set_country
{
	my $country = $_[0];
	my $controlfile = $_[1];


	# Do nothing;
	if(! defined $country) {
		return 0;
	}
	if(! defined $controlfile) {
		return (-1);
	}
	if(! -f "$controlfile" ) {
		return(-2);
	}

	# Set the first byte of "control.dsy" to 0x01 for canadian,
	# or 0x00 for US.
	# see man perlopentut, perlfunc
	open( FILE, "+< $controlfile");
	seek FILE, 0, SEEK_SET;
	if ($country =~ /^us$/i || $country =~ /^usa$/i || $country =~ /^united states$/i) {
		print FILE "\0";
	}
	elsif ($country =~ /^can$/i || $country =~ /^canada$/i) {
		print FILE "\1";
	}
	close FILE;
}


#===========================================#
# +---------------------------------------+ #
# | Cleanup selected Daisy data files     | #
# +---------------------------------------+ #
#===========================================#

sub clear_cc_swipes
{
	my $destdir = $_[0];
	my $item = "";

	showinfo("--> Securing Daisy data files");

	system ("cd $destdir && ./utils/ccutil clearswipe paydetails");
	system ("cd $destdir && ./utils/ccutil clearswipe pending");
	system ("cd $destdir && ./utils/ccutil encrypt paydetails");
	system ("cd $destdir && ./utils/ccutil encrypt pending");
	open PIPE, "cd  $destdir && ls *.pos |";
	while (<PIPE>) {
		chomp;
		$item = $_;
		if( $item =~ /[d1-9][gr1-9][at][wz]dat\.pos$/) {
			if(-f $item) {
				system ("cd $destdir && ./utils/ccutil clearswipe $item");
				system ("cd $destdir && ./utils/ccutil encrypt $item");
			}
		}
	}
	close PIPE;
	system ("cd $destdir && ./utils/cardfix");

	showinfo("--> Daisy data files secured");
}

#
# Update "dovectrl.pos" to accomodate high speed dove (Daisy 6.5)
#
sub update_dovectrl_high_speed
{
	my $destdir = $_[0];
	my $controlfile = "";

	# Find existing "dovectrl.pos"
	open(PIPE, "find $destdir -type f -iname dovectrl.pos -print |");
	while (<PIPE>) {
		chomp;
		if ($_ ne "") {
			$controlfile = $_;
			last;
		}
	}
	close PIPE;

	if ($controlfile eq "") {
		showerror("Error: Could not find file dovectrl.pos");
		return 1;
	}


	# use filesize to determine whether this is already a 6.5 formatted file.
	my $filesize = -s $controlfile;
	if ($filesize <= 2333) {
		showinfo("--> Converting to new Daisy format: $controlfile");
		open(NEW, ">> $controlfile");

			# Output two zero bytes for the new Dial/Internet selector
			print NEW "\001\000";

			# Output the password - 17 spaces and trailing 0
			for (my $i = 0; $i < 17; $i++) {
				print NEW " ";
			}
			print NEW "\000";


			# Output 100 zeroes of fill bytes
			for (my $i = 0; $i < 100; $i++) {
				print NEW "\000";
			}
			
		close(NEW);

		showinfo("--> Converted to new Daisy format: $controlfile");
	}

	return;
}

sub cleanup_numbered_settle_files
{
	my $destdir = $_[0];
	my @settle_files = ();

	my $delcmd = cleanup_choose_deletion_cmd();

        unless (opendir(DIR, $destdir)) {
                showerror("Error opening directory $destdir\n");
                return;
        }

        foreach my $dirent (readdir(DIR)) {
                if ($dirent =~ /settfil\d+.pos/) {
                        push(@settle_files, "$destdir/$dirent");
                }
        }
        closedir(DIR);

	if (@settle_files) {
		system("$delcmd @settle_files");
		my $strerror = system_exit_status($?);
		if ($strerror) {
			showerror("Error removing numbered settle files");
			showerror("$strerror");
		}
	}
}

sub cleanup_omrc_files
{
	my $destdir = $_[0];
	my $source_install_files_dir = $_[1];

	my @omrc_files = qw(
		omrcdat.pos
		omrcidx.pos
	);

	# shred or rm
	my $delcmd = cleanup_choose_deletion_cmd();

	# dispose of old files if present
	foreach my $omrc_file (@omrc_files) {
		if (-f $omrc_file) {
			system("$delcmd $omrc_file");
			my $strerror = system_exit_status($?);
			if ($strerror) {
				showerror("Error removing $omrc_file");
				showerror("$strerror");
			}
		}
	}

	# this is the source of a fresh copy of the data files
	my $source_tarball = "$source_install_files_dir/data_daisy.tgz";

	system("cd $destdir && tar -xzf $source_tarball @omrc_files");
	my $strerror = system_exit_status($?);
	if ($strerror) {
		showerror("Error installing new blank instances of @omrc_files");
		showerror("$strerror");
	}
}


#================================#
# +----------------------------+ #
# | Section Begin: Daisy Users | #
# +----------------------------+ #
#================================#

#
# Make sure the following accounts exist:
#	"daisy" user
#	"tfsupport" user
#
sub create_daisy_users
{
        my $destroot = $_[0];
        my $dsyusercmd = "$destroot/bin/dsyuser.pl";

        if (! -f "$dsyusercmd") {
                logerror("$dsyusercmd doesn't exist. Cannot Create User Accounts");
                return -1;
	}

	# Add administrative user... it has to be added first since there is
	# a dependency on this user in 'dsyuser.pl'.
	if (getpwnam('tfsupport')) {
                showinfo("The \"tfsupport\" user already exists on this system.");
                showinfo("Updating \"tfsupport\" user.");
		system ("/usr/bin/perl $dsyusercmd --update tfsupport");
                showinfo("Enabling \"tfsupport\" user as daisy admin.");
		system ("/usr/bin/perl $dsyusercmd --enable-admin tfsupport");
	} else {
                showinfo("The \"tfsupport\" user does not exist on this system.");
		#
		# These 3 commands must be performed in this order - the behaviour
		# of --resetpw is different depending on whether it's an admin or not.
		#
                showinfo("Adding \"tfsupport\" as a daisy user.");
		system ("/usr/bin/perl $dsyusercmd --add tfsupport");
                showinfo("Enabling \"tfsupport\" user as daisy admin.");
		system ("/usr/bin/perl $dsyusercmd --enable-admin tfsupport");
                showinfo("Resetting password for \"tfsupport\" user.");
		system ("/usr/bin/perl $dsyusercmd --resetpw tfsupport password");
	}

	# Only add "daisy" user account if not present.
	unless (getpwnam('daisy')) {
		showinfo("Adding \"daisy\" as a daisy user.");
		system ("/usr/bin/perl $dsyusercmd --add daisy");
		#
		# per management... in order to make life easier for staging/support:
		#	set the password to a fixed value
		#	no rotation
		#	not a one time password
		#
		system ("/usr/bin/perl $dsyusercmd --resetpw daisy dai1sy#");
	}

	return 0;
}

#
# Step through each Daisy user, and run them through 'dsyuser.pl --update'
# to update them to the standard config.
#
# This code assumes the output of 'dsyuser.pl --list' produces one line of
# output for each Daisy user on the system where each line looks like:
#
#	username (Daisy User) [(Daisy Admin)] [(TFRemote)]
#
# Note that the "(Daisy Admin)" field and the "(TFRemote)" field are optional
# but "username" and "(Daisy User") will always be present.
#
# assert(dsyperms.pl has already been run)
#
sub update_dsyusers
{
	my $destroot = $_[0];
	my $dsyuser_cmd = "$destroot/bin/dsyuser.pl --list";
	my @dsyuser_list = qx($dsyuser_cmd);

	showinfo("--> Updating Daisy users via: $dsyuser_cmd");

	if (@dsyuser_list == 0) {
		logerror("Could not get a list of Daisy users");
		return;
	}

	foreach (@dsyuser_list) {
		my @dsyuser_and_groups = split(/\s+/);
		my $dsyuser = $dsyuser_and_groups[0];
		system("$destroot/bin/dsyuser.pl --update $dsyuser");
		if ($? != 0) {
			logerror("Could not update Daisy user: $dsyuser");
		}
	}

	showinfo("--> Daisy users updated");
}

#======================================#
# +----------------------------------+ #
# | Section Begin: Cleanup Old Stuff | #
# +----------------------------------+ #
#======================================#

sub cleanup_choose_deletion_cmd
{
	my $delcmd = '/usr/bin/shred --remove --iterations=2 --force';

	#
	# If shred is not installed, drop back to plain old rm
	#
	unless (-x '/usr/bin/shred') {
		$delcmd = '/usr/bin/rm -f' 
	}

	return $delcmd;
}


#
# PCI requires that we shred the saved daisy dir.
#
# Return = 1 on success, 0 otherwise.
#
sub cleanup_saved_daisy_dir
{
	my $saved_dsy_dir = $_[0];
	my $delcmd = cleanup_choose_deletion_cmd();

	#
	# On the find command line, use the "-print0" and "-0" to take care of
	# file names with SPACE chars.
	#
	if (do_system("find $saved_dsy_dir -type f -print0 | xargs -0 $delcmd")) {

		showinfo("--> Successful shred of saved Daisy database files");

		if (do_system("rm -rf $saved_dsy_dir")) {
			showinfo("--> Successful removal of saved Daisy database directory");
			return (1);
		}

		showerror("Unable to remove saved Daisy database directory: $saved_dsy_dir");
		return (0);

	}

	showerror("Unable to shred files in saved Daisy database directory: $saved_dsy_dir");

	showinfo("Attempting to remove saved Daisy database directory");

	if (do_system("rm -rf $saved_dsy_dir")) {
		showinfo("--> Successful removal of saved Daisy database directory");
		return (1);
	}

	showerror("Unable to remove saved Daisy database directory: $saved_dsy_dir");
	return (0);
}


#========================================#
# +------------------------------------+ #
# | Section Begin: OS Config Functions | #
# +------------------------------------+ #
#========================================#

sub os_edit_conf_postop
{
	my $conf_file = $_[0];
	my $new_conf_file = $_[1];
	my $timestamp = strftime("%Y-%m-%d_%H%M%S", localtime());
	my $saved_conf_file = "${conf_file}-$timestamp";

	# measure of success: the generated file contains something
	unless (-s $new_conf_file) {
		showerror("Error: generated new conf file $new_conf_file is zero length.");
		system("rm $new_conf_file");
		return 0;
	}

	# now exchange file names and set perms
	system("mv $conf_file $saved_conf_file");
	my $strerror = system_exit_status($?);
	if ($strerror) {
		showerror("Error: could not archive original conf file $conf_file");
		showerror("$strerror");
		system("rm $new_conf_file");
		return 0;
	}
	system("mv $new_conf_file $conf_file");
	$strerror = system_exit_status($?);
	if ($strerror) {
		showerror("Error: could not install generated new version of $conf_file");
		showerror("$strerror");
		system("rm $new_conf_file");
		system("mv $saved_conf_file $conf_file");
		return 0;
	} else {
		system("chown root:root $conf_file");
		system("chmod 644 $conf_file");
	}

	return 1;
}


#
# Return the template for the daisy crontab file.
#
sub os_emit_daisy_crontab
{
	return <<'EOF';
##
## $Revision: 1.352 $
## Cron entries added by Daisy scripts for Daisy related tasks.  Not for use
## by customers or Diasy support.  Do not edit this file.  It can be changed
## at any time.
##
7 3 * * * tfsupport /d/daisy/bin/dsypostinstall.pl
EOF
}


#
# This function installs a template crontab file that is used for Daisy
# related tasks.  Not for use by customers or Diasy support.  It can be
# changed at any time.
#
sub os_add_daisy_crontab
{
	my $crontabfile = "/etc/cron.d/daisy";

	showinfo("--> Adding Daisy crontab file: $crontabfile");

        # If not already installed, add a template for a general crontab file
        if (-f "$crontabfile") {
                loginfo("$crontabfile already exists. Will leave intact.");
		return;
        }

	open(FILE, "> $crontabfile");
	print(FILE os_emit_daisy_crontab());
	close(FILE);

        system ("chown root:root $crontabfile 2>/dev/null");
        system ("chmod 644 $crontabfile 2>/dev/null");
}

#
# Return the template for the daisy-service crontab file.
#
sub os_emit_daisy_service_crontab
{
	return <<'EOF';
#
# $Revision: 1.352 $
# Cron entries added by customer service for Daisy related tasks.
#
#
# Format
#
# 1 2 3 4 5 user (. /etc/profile.d/daisy.sh && mycommand --parameter blah blah)
#
# 1 - Minute
# 2 - Hour
# 3 - Day of Month
# 4 - Month
# 5 - Day of Week
#
# user - Unix username which this cron task will run as.
# ". /etc/profile.d/daisy.sh - ensures that 'DSY_DIR' is defined for your command
# mycommand --parameter blah blah - The command (and any following parameters) you want to run
#
# Example:
# * * * * * daisy (. /etc/profile.d/daisy.sh && $DSY_DIR/bin/dsyperms.pl $DSY_DIR)
EOF
}


#
# This is a template of a crontab file that can be used by support to
# add functions to Daisy that need to be run by cron.
#
sub os_add_daisy_service_crontab
{
	my $crontabfile = "/etc/cron.d/daisy-service";

	showinfo("--> Adding Daisy crontab file: $crontabfile");

        # If not already installed, add a template for a general crontab file
        if (-f "$crontabfile") {
                loginfo("$crontabfile already exists. Will leave intact.");
		return;
        }

	open(FILE, "> $crontabfile");
	print(FILE os_emit_daisy_service_crontab());
	close(FILE);

        system ("chown root:root $crontabfile 2>/dev/null");
        system ("chmod 644 $crontabfile 2>/dev/null");
}

#
# Setup "daisy" service.
#
# Never happened but intended use:
#	Startup Daisy when system boots.
#	Shutdown Daisy when system is shutdown.
#
sub os_add_daisy_service
{
	my $destdir = $_[0];

	# choose appropriate service name
	my $service = "";
	if ($OS eq 'RHEL5') {
	    $service = "daisy";
	}
	if ($OS eq 'RHEL6') {
	    $service = "zeedaisy";
	}
	if ($OS eq 'RHEL7') {
	    showinfo("--> Daisy RHEL7 system service unit file does not exist");
	    return(1);
	}

	# chkconfig service if init script exists and has not already been configured.
	my $init_script = "$destdir/config/$service" . "-init.d";
	if (-e $init_script) {
	    system("/sbin/chkconfig --list | grep $service > /dev/null 2> /dev/null");
	    if ($? != 0) {
		showinfo("--> Adding Daisy system service: $service");
		system ("cp -f $init_script /etc/init.d/$service");
		system ("chmod 755 /etc/init.d/$service 2>/dev/null");
		system ("chown root:root /etc/init.d/$service 2>/dev/null");

		showinfo("--> Configuring Daisy system service: $service");
		system ("/sbin/chkconfig  --add $service");
		system ("/sbin/chkconfig  --level 0 $service off");
		system ("/sbin/chkconfig  --level 1 $service off");
		system ("/sbin/chkconfig  --level 2 $service on");
		system ("/sbin/chkconfig  --level 3 $service on");
		system ("/sbin/chkconfig  --level 4 $service off");
		system ("/sbin/chkconfig  --level 5 $service off");
		system ("/sbin/chkconfig  --level 6 $service off");
		system ("/sbin/chkconfig  --list $service >> $LOGFILE 2>&1");
	    }
	}

	return(1);
}


sub os_virt_cons_patch_perms
{
    my $system_service_dir = '/etc/systemd/system';

    my $corrected_count = 0;
    for (my $i=1; $i <= 11; $i++) {

	# skip vc 10 since it will run the normal getty service
	if ($i == 10) {
	    next;
	}

	# form the path to the service file to generate
	my $service_name = 'getty@tty' . $i . ".service";
	my $service_file = $system_service_dir . '/' . $service_name;

	if (get_file_perms($service_file) != 0644) {
	    system("chmod 644 $service_file");
	    showinfo("--> Perms set on virtual console service file: $service_file");
	    $corrected_count++;
	}
    }

    if ($corrected_count == 0) {
	showinfo("--> Perms on virtual console service files did not need correction");
    }

    return(1);
}


sub os_virt_cons_generate_service_file
{
    my ($fh, $session_nr) = @_;

    # can't use "heredoc" since it sometimes causes a problem with
    # POD output.

    print {$fh} "#  This file is part of systemd.\n";
    print {$fh} "#\n";
    print {$fh} "#  systemd is free software; you can redistribute it and/or modify it\n";
    print {$fh} "#  under the terms of the GNU Lesser General Public License as published by\n";
    print {$fh} "#  the Free Software Foundation; either version 2.1 of the License, or\n";
    print {$fh} "#  (at your option) any later version.\n";
    print {$fh} "#\n";
    print {$fh} "[Unit]\n";
    print {$fh} "Description=Getty on %I\n";
    print {$fh} "Documentation=http://www.teleflora.com\n";
    print {$fh} "After=systemd-user-sessions.service plymouth-quit-wait.service\n";
    print {$fh} "After=rc-local.service\n";
    print {$fh} "#\n";
    print {$fh} "# If additional gettys are spawned during boot then we should make\n";
    print {$fh} "# sure that this is synchronized before getty.target, even though\n";
    print {$fh} "# getty.target didn't actually pull it in.\n";
    print {$fh} "Before=getty.target\n";
    print {$fh} "IgnoreOnIsolate=yes\n";
    print {$fh} "#\n";
    print {$fh} "# On systems without virtual consoles, don't start any getty. Note\n";
    print {$fh} "# that serial gettys are covered by serial-getty@.service, not this\n";
    print {$fh} "# unit.\n";
    print {$fh} "ConditionPathExists=/dev/%I\n";
    print {$fh} "#\n";
    print {$fh} "[Service]\n";
    print {$fh} "# the VT is cleared by TTYVTDisallocate\n";
    print {$fh} "ExecStart=/usr/bin/bash -c '/d/startup/session ";
    printf {$fh} "%02d ", $session_nr;
    print {$fh} "</dev/%I &>/dev/%I' &\n";
    print {$fh} "Type=idle\n";
    print {$fh} "Restart=no\n";
    print {$fh} "RestartSec=0\n";
    print {$fh} "UtmpIdentifier=%I\n";
    print {$fh} "TTYPath=/dev/%I\n";
    print {$fh} "TTYReset=yes\n";
    print {$fh} "TTYVHangup=yes\n";
    print {$fh} "TTYVTDisallocate=yes\n";
    print {$fh} "KillMode=process\n";
    print {$fh} "IgnoreSIGPIPE=no\n";
    print {$fh} "SendSIGHUP=yes\n";
    print {$fh} "StandardOutput=tty\n";
    print {$fh} "#\n";
    print {$fh} "# Unset locale for the console getty since the console has problems\n";
    print {$fh} "# displaying some internationalized messages.\n";
    print {$fh} "Environment=LANG= LANGUAGE= LC_CTYPE= LC_NUMERIC= LC_TIME= LC_COLLATE= ";
    print {$fh} "LC_MONETARY= LC_MESSAGES= LC_PAPER= LC_NAME= LC_ADDRESS= LC_TELEPHONE= LC_MEASUREMENT= ";
    print {$fh} "LC_IDENTIFICATION= TERM=\n";
    print {$fh} "#\n";
    print {$fh} "[Install]\n";
    print {$fh} "WantedBy=getty.target\n";

    return(1);
}


#
# configure the programs that will run on the virtual consoles
# under the systemd facility of RHEL7.
#
sub os_virt_cons_configure_systemd
{
    my $conf_dir_name = '/etc/systemd/system';

    for (my $i=1; $i <= 11; $i++) {

	# skip vc 10 since it will run the normal getty service
	if ($i == 10) {
	    next;
	}

	# form the path to the service file to generate
	my $conf_file_name = 'getty@tty' . $i . ".service";
	my $conf_file = $conf_dir_name . '/' . $conf_file_name;
	my $new_conf_file = "${conf_file}.$$";

	# generate the new service file, set perms and rename,
	# and finally, tell the system about it
	if (open(my $new, '>', $new_conf_file)) {
	    os_virt_cons_generate_service_file($new, $i);
	    close($new);

	    system("chmod 644 $new_conf_file");
	    system("chown root:root $new_conf_file");
	    system("mv $new_conf_file $conf_file");

	    system("systemctl enable $conf_file_name");
	    #system("systemctl start $conf_file_name");

	    loginfo("--> generated unit file for: $conf_file_name");
	}
	else {
	    showerror("could not make new systemd service file: $new_conf_file");
	}
    }

    my @getty_consoles = qw(
	getty@tty10.service
	getty@tty12.service
    );

    foreach my $getty_console (@getty_consoles) {
	system("systemctl enable $getty_console");
	#system("systemctl start $getty_console");
	#loginfo("--> enable of: $getty_console");
    }

    return(1);
}


#
# Configure which Daisy processes run on the virtual consoles
# via "upstart".
#
sub os_virt_cons_configure_upstart
{
    showinfo("--> Configuring upstart to run Daisy processes in Virtual Consoles");

    for (my $i=1; $i <= 12; $i++) {
	my $conf_file = "/etc/init/tty" . $i . ".conf";
	my $new_conf_file = "${conf_file}.new";

	unless (open(NEW, '>', "$new_conf_file")) {
	    showerror("Can't make new upstart file: $new_conf_file");
	    return;
	}

	#
	# Special case tty1: it will depend on the "init.d" script
	# run for Daisy at runlevels 2 and 3.  This prevents the
	# appearance of session 1 on the console too early.
	#
	if ($i == 10 || $i == 12) {
	    print(NEW "stop on runlevel [0156]\n");
	    print(NEW "start on runlevel [234]\n");
	    printf(NEW "exec /sbin/mingetty /dev/tty%d\n", $i);
	}
	else {
	    print(NEW "stop on runlevel [01456]\n");
	    print(NEW "start on started zeedaisy\n");
	    print(NEW "exec /d/startup/session ");
	    printf(NEW "%02d < /dev/tty%d &> /dev/tty%d\n", $i, $i, $i);
	}

	print(NEW "respawn\n");

	close(NEW);

	system("chmod 755 $new_conf_file");
	system("chown root:root $new_conf_file");
	system("mv $new_conf_file $conf_file");
    }

    # remove the upstart conf file that kicks off all the ttys
    my $old_conf_file = "/etc/init/start-ttys.conf";
    if (-e $old_conf_file) {
	system("rm -f $old_conf_file");
    }

    # remove the upstart conf file that actually starts a getty
    $old_conf_file = "/etc/init/tty.conf";
    if (-e $old_conf_file) {
	system("rm -f $old_conf_file");
    }

    showinfo("--> Upstart configured");
}


#
# Configure which Daisy processes run on the virtual consoles
# the traditional way: by editing the content of "/etc/inittab".
#
# Edit the inittab file by removing lines like:
#
#	1:2345:respawn:/sbin/mingetty tty1
#
# and replace them with lines like:
#
#	1:23:respawn:/d/startup/session 01 < /dev/tty1 &> /dev/tty1
#
sub os_virt_cons_configure_inittab
{
    my $timestamp = strftime("%Y-%m-%d_%H%M%S", localtime());
    my $conf_file = '/etc/inittab';
    my $new_conf_file = "$conf_file-$timestamp";

    showinfo("--> Configuring /etc/inittab to run Daisy processes in Virtual Consoles");

    unless (-s "$conf_file") {
	showerror("$conf_file does not exist...  Will skip edits.");
	return;
    }

    unless (open(OLD, "< $conf_file")) {
	showerror("Could not open $conf_file for read... Will skip edits.");
	return;
    }

    unless (open(NEW, "> $new_conf_file")) {
	showerror("Could not open $new_conf_file for write... Will skip edits.");
	close(OLD);
	return;
    }

    my $dsyvt_re = '\d:\d+:respawn:/d/startup/session';
    my $dsyvt12_re = '12:\d+:respawn:/d/server/12';
    my $dsyvt12_re2 = '12:\d+:respawn:/d/server/tty12';
    my $std_inittab = 1;
    while (<OLD>) {
	#
	# If we see a daisy style inittab, note it if not already noted.
	#
	if (/^$dsyvt_re/ && $std_inittab) {
		$std_inittab = 0;
	}

	#
	# If scanning standard inittab, remove all the regular virtual consoles.
	# Else if scanning daisy style inittab, just remove Alt F12.
	#
	if ($std_inittab) {
	    next if (/# Run gettys in standard runlevels/);
	    next if (/^\d+:\d+:respawn:/);
	}
	else {
	    if (/^$dsyvt12_re/ || /^$dsyvt12_re2/) {
		print(NEW "12:234:respawn:/sbin/mingetty tty12\n");
		next;
	    }
	}

	# By default, just copy what we read.
	print(NEW $_);
    }
    close(OLD);

    if ($std_inittab) {
	print(NEW "\n");
	print(NEW "# Daisy virtual consoles\n");
	print(NEW "1:23:respawn:/d/startup/session 01 < /dev/tty1 &> /dev/tty1\n");
	print(NEW "2:23:respawn:/d/startup/session 02 < /dev/tty2 &> /dev/tty2\n");
	print(NEW "3:23:respawn:/d/startup/session 03 < /dev/tty3 &> /dev/tty3\n");
	print(NEW "4:23:respawn:/d/startup/session 04 < /dev/tty4 &> /dev/tty4\n");
	print(NEW "5:23:respawn:/d/startup/session 05 < /dev/tty5 &> /dev/tty5\n");
	print(NEW "6:23:respawn:/d/startup/session 06 < /dev/tty6 &> /dev/tty6\n");
	print(NEW "7:23:respawn:/d/startup/session 07 < /dev/tty7 &> /dev/tty7\n");
	print(NEW "8:23:respawn:/d/startup/session 08 < /dev/tty8 &> /dev/tty8\n");
	print(NEW "9:23:respawn:/d/startup/session 09 < /dev/tty9 &> /dev/tty9\n");
	print(NEW "10:234:respawn:/sbin/mingetty tty10\n");
	print(NEW "11:234:respawn:/d/startup/session 11 < /dev/tty11 &> /dev/tty11\n");
	print(NEW "12:234:respawn:/sbin/mingetty tty12\n");
    }
    close(NEW);

    # If we created a new conf file that is zero sized, that is bad.
    if (-z $new_conf_file) {
	showerror("Copy of $conf_file is a zero size file. Will skip edits.");
	system("rm $new_conf_file");
	return;
    }

    # Assume conf file was successfully transformed...
    # so replace the old one with the new.
    system("chmod --reference=$conf_file $new_conf_file");
    system("chown --reference=$conf_file $new_conf_file");
    system("mv $new_conf_file $conf_file");

    #
    # Tell init to re-examine the /etc/inittab file.
    #
    system("/sbin/telinit Q");

    showinfo("--> The /etc/inittab file configured");
}


#
# Previous to RHEL6, the processes that run in the virtual consoles
# was configured in the /etc/inittab file.
#
# For RHEL6, the "Upstart process management" system is used and
# the /etc/inittab is not involved with configuring which processes
# run in virtual consoles.
#
# If only Daisy complied with PCI and made the users login to use it,
# none of this would have to be done.
# 
sub os_virt_cons_configure_procs
{
    if ($OS eq 'RHEL7') {
	os_virt_cons_configure_systemd();
    }

    if ($OS eq 'RHEL6') {
	os_virt_cons_configure_upstart();
    }

    if ($OS eq 'RHEL5') {
	os_virt_cons_configure_inittab();
    }
}


#
# Configure the number of virtual consoles the system allows.
# Apparently, you only have to do this for RHEL6.
#
sub os_virt_cons_set_number
{
    if ($OS eq "RHEL6") {
	my $conf_file = "/etc/sysconfig/init";
	my $new_conf_file = "$conf_file.new";
	my $MAX_VIRTUAL_CONSOLES = 12;

	showinfo("--> Updating number of virtual consoles in: $conf_file");

	unless (-s "$conf_file") {
	    showerror("$conf_file does not exist...  Will skip edits.");
	    return;
	}

	unless (open(OLD, "< $conf_file")) {
	    showerror("Could not open $conf_file for read... Will skip edits.");
	    return;
	}

	unless (open(NEW, "> $new_conf_file")) {
	    showerror("Could not open $new_conf_file for write... Will skip edits.");
	    close(OLD);
	    return;
	}

	while (<OLD>) {

	    if (/^ACTIVE_CONSOLES/) {
                printf(NEW "ACTIVE_CONSOLES=/dev/tty[1-%d]\n", $MAX_VIRTUAL_CONSOLES);
		next;
	    }

	    # By default, just copy what we read.
	    print(NEW $_);
	}
	close(OLD);
	close(NEW);

	# If we created a new conf file that is zero sized, that is bad.
	if (-z $new_conf_file) {
	    showerror("Copy of $conf_file is a zero size file. Will skip edits.");
	    system("rm -f $new_conf_file");
	    return;
	}

	# Assume conf file was successfully transformed...
	# so replace the old one with the new.
	system("chmod --reference=$conf_file $new_conf_file");
	system("chown --reference=$conf_file $new_conf_file");
	system("mv $new_conf_file $conf_file");

	showinfo("--> Virtual console configuration updated");
    }
}


#
# Configure the Daisy processes running on virtual consoles.
#
sub os_configure_virt_cons
{
    os_virt_cons_set_number();

    os_virt_cons_configure_procs();
}


sub os_audit_system_generate
{
    my ($conf_file) = @_;

    my $rc = 1;

    if (open(my $cf, '>', $conf_file)) {
	print {$cf} "# Daisy PA DSS Audit System config file\n";
	print {$cf} "# Copyright 2009-2017 Teleflora\n";
	print {$cf} "#\n";
	print {$cf} "# Generated file - do not edit\n";
	print {$cf} "#\n";
	print {$cf} "# This file contains the auditctl rules that are loaded\n";
	print {$cf} "# whenever the audit daemon is started via the initscripts.\n";
	print {$cf} "# The rules are simply the parameters that would be passed\n";
	print {$cf} "# to auditctl.\n";
	print {$cf} "#\n";
	print {$cf} "# -k key\n";
	print {$cf} "#    Set a filter key on an audit rule.\n";
	print {$cf} "# -p [r|w|x|a]\n";
	print {$cf} "#    Describe the permission access type that a file system watch\n";
	print {$cf} "#    will trigger on. r=read, w=write,  x=execute,  a=attribute change.\n";
	print {$cf} "# -w path\n";
	print {$cf} "#    Insert a watch for the file system object at path.\n";
	print {$cf} "\n";
	print {$cf} "-w /d/daisy -p wa -k daisypadss\n";
	close($cf) or warn "could not close audit config file $conf_file: $OS_ERROR\n";
    }
    else {
	logerror("could not open audit config file for write: $conf_file");
	$rc = 0;
    }

    return($rc);
}

#
# if needed, install config file for Linux kernel audit system.
#
sub os_audit_system_install
{
    my $rc = 1;

    if (-e $DAISY_AUDIT_SYSTEM_CONFIG_PATH) {
	showinfo("--> Skipping: Audit system already configured: $DAISY_AUDIT_SYSTEM_CONFIG_PATH");
    }
    else {
	if (os_audit_system_generate($DAISY_AUDIT_SYSTEM_CONFIG_PATH)) {
	    showinfo("--> Audit system config file installed: $DAISY_AUDIT_SYSTEM_CONFIG_PATH");
	}
	else {
	    showerror("could not install audit system config file: $DAISY_AUDIT_SYSTEM_CONFIG_PATH");
	    $rc = 0;
	}
    }

    return($rc);
}

#
# Add the Daisy shell to the /etc/shells whitelist.
#
sub os_configure_shells
{
	my $timestamp = strftime("%Y-%m-%d_%H%M%S", localtime());
	my $conf_file = '/etc/shells';
	my $new_conf_file = "$conf_file-$timestamp";
	my $marker = '/d/daisy/bin/dsyshell';

	showinfo("--> Adding path of Daisy Shell to: $conf_file");

	unless (-s "$conf_file") {
		showerror("$conf_file does not exist...  Will skip edits.");
		return;
	}

	unless (open(OLD, "< $conf_file")) {
		showerror("Could not open $conf_file for read... Will skip edits.");
		return;
	}

	unless (open(NEW, "> $new_conf_file")) {
		showerror("Could not open $new_conf_file for write... Will skip edits.");
		close(OLD);
		return;
	}

	while (<OLD>) {
		# if we are looking at an already modified conf file, stop
		if (/$marker/) {
			close(OLD);
			close(NEW);
			system("rm $new_conf_file");
			return;
		}

		# By default, just copy what we read.
		print(NEW $_);
	}

	close(OLD);

	print(NEW "/d/daisy/bin/dsyshell\n");

	close(NEW);

	# If we created a new conf file that is zero sized, that is bad.
	if (-z $new_conf_file) {
		showerror("Copy of $conf_file is a zero size file. Will skip edits.");
		system("rm $new_conf_file");
		return;
	}

	# Assume conf file was successfully transformed... so replace the old one with the new.
	system("chmod --reference=$conf_file $new_conf_file");
	system("chown --reference=$conf_file $new_conf_file");
	system("mv $new_conf_file $conf_file");

	showinfo("--> Path of Daisy Shell added to: $conf_file");
}


sub modify_os_configs
{
    my $destdir = $_[0];
    my $previousroot = $_[1];

    os_add_daisy_crontab();

    os_add_daisy_service_crontab();

    os_add_daisy_service($destdir);

    os_configure_virt_cons();
}


sub install_dsyconfigs
{
	my $destroot = $_[0];
	my $conf_file = '/etc/profile.d/daisy.sh';

        unless (-d '/etc/profile.d') {
		system("mkdir /etc/profile.d");
		system("chown root:root /etc/profile.d");
		system("chmod 755 /etc/profile.d");
        }
        unless (-d '/etc/profile.d') {
		return;
        }

	#
	# If the daisy profile.d config file already exists, we just need to
	# add a define for the daisy database dir being installed if the
	# definition in the file is a different value.
	#
	# If it does not exist, then make a new one.
	#
	if (-e $conf_file) {

		showinfo("--> Updating global Daisy config file: $conf_file");

		# look for daisy db dir
		my $grepout = qx(grep "^DSY_DIR.*=$destroot" $conf_file);
		chomp($grepout);

		# if didn't find it, add it to the file
		unless ($grepout) {
			for (my $i=2; $i < 10; $i++) {
				$grepout = qx(grep "DSY_DIR$i" $conf_file);
				unless ($grepout) {
					system("echo DSY_DIR$i=$destroot >> $conf_file");
					system("echo export DSY_DIR$i >> $conf_file");
				}
			}
		}

	} else {

		showinfo("--> Generating new global Daisy config file: $conf_file");

		open FILE, "> $conf_file";
			print FILE "#\n";
			print FILE "# Setup Daisy Environment Variables.\n";
			print FILE "# Created by Daisy $DAISY_VERSION Install Script.\n";
			print FILE "# " . strftime("%Y-%m-%d %H:%M:%S\n", localtime());
			print FILE "#\n";
			print FILE "DSY_DIR=$destroot\n";
			print FILE "export DSY_DIR\n";
			print FILE "PATH=/d/daisy/bin:\$PATH\n";
			print FILE "#\n";
			print FILE "alias l='ls -l'\n";
		close FILE;
	}

        system("chown root:root $conf_file");
        system("chmod 755 $conf_file");

	showinfo("--> Global Daisy config file updated: /etc/profile.d/daisy");
}

#==========================================#
# +--------------------------------------+ #
# | Section Begin: Backup old Daisy tree | #
# +--------------------------------------+ #
#==========================================#

#
# This very clever function taken from perlmonks.org.
#
sub format_elapsed_time
{
    my( $weeks, $days, $hours, $minutes, $seconds, $sign, $res ) = qw/0 0 0 0 0/;

    $seconds = shift;
    $sign    = $seconds == abs $seconds ? '' : '-';
    $seconds = abs $seconds;

    ($seconds, $minutes) = ($seconds % 60, int($seconds / 60)) if $seconds;
    ($minutes, $hours  ) = ($minutes % 60, int($minutes / 60)) if $minutes;
    ($hours,   $days   ) = ($hours   % 24, int($hours   / 24)) if $hours;
    ($days,    $weeks  ) = ($days    %  7, int($days    /  7)) if $days;

    $res = sprintf '%ds',     $seconds;
    $res = sprintf "%dm$res", $minutes if $minutes or $hours or $days or $weeks;
    $res = sprintf "%dh$res", $hours   if             $hours or $days or $weeks;
    $res = sprintf "%dd$res", $days    if                       $days or $weeks;
    $res = sprintf "%dw$res", $weeks   if                                $weeks;

    return "$sign$res";
}

#
# Create an encrypted tarball of the previous Daisy installation.
#
# Return 0 on success, non-zero on error
#
sub backup_previous_tree
{
    my $destroot = $_[0];
    my $sourceroot = $_[1];

    my $savedroot = $destroot . "-" . $TIMESTAMP;

    showinfo("--> Starting encrypted backup of Daisy directory: $destroot");

    my $encryptcmd = "$sourceroot/utils/encrypttar.pl";
    $ENCRYPTED_TAR_FILE = $savedroot . ".tar.asc";

    if (! -f $encryptcmd) {
	showerror("Could not find encryption tool: $encryptcmd");
	return(-1);
    }

    showinfo("--> Backup being written to encrypted tar file: $ENCRYPTED_TAR_FILE");

    my $start_time = time();

    system("$encryptcmd $destroot > $ENCRYPTED_TAR_FILE 2>> $LOGFILE");
    $strerror = system_exit_status($?);
    if ($strerror) {
	showerror("Cound not make encrypted tar archive of: $destroot");
	return(-2);
    }

    my $elapsed_time = format_elapsed_time(time() - $start_time);

    showinfo("--> Encrypted backup completed ($elapsed_time)");

    return(0);
}


#======================================#
# +----------------------------------+ #
# | Section Begin: OSTools Functions | #
# +----------------------------------+ #
#======================================#

#
# Get installed OSTools package version.
#
sub ostools_installed_version
{
    my ($ostools_bin_dir) = @_;

    my $ostools_version = "";
    my $ostools_cmd = "tfsupport.pl --version";

    if (-d $ostools_bin_dir) {
	unless (open(PIPE, "$ostools_bin_dir/$ostools_cmd |")) {
	    showerror("Can't open pipe to ostools command: $ostools_cmd");
	}
	else {
	    while (<PIPE>) {
		if (/OSTools Version:  (.*)$/) {
		    $ostools_version = $1;
		    last;
		}
	    }
	    close(PIPE);
	}
    }

    return($ostools_version);
}


#
# Get OSTools package version.
#
sub ostools_pkg_version
{
    my ($ostools_pkg_path) = @_;

    # this will put the scripts in /tmp/bin
    system("tar -C /tmp -xf $ostools_pkg_path");

    my $ostools_version = ostools_installed_version("/tmp/bin");

    # clean up
    system("rm -rf /tmp/bin");

    return($ostools_version);
}


#
# Compare version strings of 2 OSTools pacakges.
#
# if version 1 newer than version 2 return 1
# if version 1 older than version 2 return -1
# if version 1 == version 2 return 0
#
sub ostools_cmp_version
{
    my ($ostools_version1, $ostools_version2) = @_;

    if ($ostools_version1 eq $ostools_version2) {
	return(0);
    }

    my ($vers1_major, $vers1_minor, $vers1_buildnr) = split(/\./, $ostools_version1);
    my ($vers2_major, $vers2_minor, $vers2_buildnr) = split(/\./, $ostools_version2);

    if ($vers1_major < $vers2_major) {
	return(-1);
    }
    if ($vers1_major > $vers2_major) {
	return(1);
    }

    if ($vers1_minor < $vers2_minor) {
	return(-1);
    }
    if ($vers1_minor > $vers2_minor) {
	return(1);
    }

    if ($vers1_buildnr < $vers2_buildnr) {
	return(-1);
    }
    if ($vers1_buildnr > $vers2_buildnr) {
	return(1);
    }

    return(0);
}


#
# Either download the OSTools package or get it from the ISO file.
#
# Returns non-empty path to ostools tar file on success else empty string
#
sub get_ostools_package
{
    my $ostools_pkg_file = "";
    my $ostools_remote_dir = "";

    if ($OS eq 'RHEL7') {
	$ostools_pkg_file = 'ostools-1.15-latest.tar.gz';
	$ostools_remote_dir = 'ostools';
    }
    elsif ($OS eq 'RHEL6' || $OS eq 'RHEL5') {
	$ostools_pkg_file = 'ostools-1.14-latest.tar.gz';
	$ostools_remote_dir = 'ostools';
    }
    else {
	showerror("Can't happen: unsupported operating system: $OS");
	return("");
    }

    my $ostools_pkg_path = "/tmp/$ostools_pkg_file";

    #
    # First try to download it
    #
    showinfo("--> Downloading OSTools from: $TFSERVER...");
    showinfo("--> Downloading OSTools package: $ostools_pkg_file...");

    my $ostools_pkg_url = "http://$TFSERVER/$ostools_remote_dir/$ostools_pkg_file";

    system("curl -f -s -o $ostools_pkg_path $ostools_pkg_url");
    $strerror = system_exit_status($?);
    if ($strerror eq "") {
	system("tar ztvf $ostools_pkg_path > /dev/null 2> /dev/null");
	$strerror = system_exit_status($?);
	if ($strerror eq "") {
	    showinfo("--> OSTools package downloaded");
	    return($ostools_pkg_path);
	}
    }


    showerror("Could not download: $ostools_pkg_url");

    #
    # Plan B, use the local copy if it exists
    #

    # for this case, local name is different than remote
    if ($OS eq "RHEL5" || $OS eq "FC5" || $OS eq "FC3") {
	$ostools_pkg_file = "ostools-1.12-latest.tar.gz";
    }

    my $ostools_local_path = "$SOURCEROOT/ostools/$ostools_pkg_file";

    showinfo("--> Getting OSTools package from installation ISO: $ostools_local_path");

    if (-e $ostools_local_path) {
	system("cp $ostools_local_path $ostools_pkg_path");
	$strerror = system_exit_status($?);
	if ($strerror) {
	    showerror("Could not copy $ostools_local_path to $ostools_pkg_path");
	    $ostools_pkg_path = "";
	}
	else {
	    showinfo("--> Please update OSTools to latest version after installation");
	}
    }
    else {
	showerror("Could not find OSTools package on ISO: $ostools_local_path");
	$ostools_pkg_path = "";
    }

    return($ostools_pkg_path);
}


#
# Install the OSTools package.
#
# Returns 0 on success, -1 on error
#
sub ostools_install_package
{
    my ($ostools_path) = @_;

    system("tar -C /tmp -xf $ostools_path");

    my $install_cmd = "/tmp/bin/install-ostools.pl";
    my $install_opts = "--noharden-linux --update";
    system("perl $install_cmd $install_opts --update $ostools_path >> $LOGFILE 2>&1");
    $strerror = system_exit_status($?);
    if ($strerror) {
	return(-1);
    }

    return(0);
}


#
# The function in the OSTools installer will not detect the
# daisy database dir at the time the OSTools is installed so
# this function was extracted from the installer and altered
# to work on the daisy database dir being installed/upgraded.
#
sub ostools_install_links
{
    my ($destdir) = @_;

    my $script_path;
    my $script_name;

    loginfo("--> Making symlinks to OSTools scripts");

    my $ostools_bin_path = "/d/ostools/bin";
    my @ostools_scripts_path = glob("$ostools_bin_path/*.pl");

    foreach $script_path (@ostools_scripts_path) {

	$script_name = basename($script_path);

	# skip special instance of dsyperms.pl
	next if ($script_name eq "dsyperms.pl");

	# skip any RTI scripts that are a part of ostools
	next if ($script_name eq "rtiuser.pl");
	next if ($script_name eq "rtiperms.pl");

	system("rm -f $destdir/$script_name");
	system("ln -sf $script_path $destdir/bin");
    }
}


#======================================#
# +----------------------------------+ #
# | Section Begin: Utility Functions | #
# +----------------------------------+ #
#======================================#

#
# Exec a command with system();
#
# Returns TRUE on success, FALSE on error.
#
sub do_system
{
	my $cmd = $_[0];

	if (system("$cmd > /dev/null 2> /dev/null") == -1) {
		showerror("Unable to exec \"$cmd\": $!");
		return(0);
	}
	unless (WIFEXITED($?)) {
		showerror("\"$cmd\" exited abnormally: $!.");
		return(0);
	}

	my $rc = WEXITSTATUS($?);
	if ($rc) {
		showerror("\"$cmd\" returned non-zero exit status: $rc.");
		return(0);
	}

	return(1);
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
# Sets global variable $OS to one of:
#	RH72
#	FC3
#	FC4
#	FC5
#	RHEL4
#	RHEL5
#	RHEL6

sub determine_os
{
	$OS = "";

	# We could also use /usr/bin/lsb-release
	open(FILE, "< /etc/redhat-release");
	while(<FILE>) {

		# Fedora Core 3
		if(/(Fedora)(\s+)(Core)(\s+)(release)(\s+)(3)/) {
			$OS = "FC3";
			last;
		}

		# Fedora Core 4
		if(/(Fedora)(\s+)(Core)(\s+)(release)(\s+)(4)/) {
			$OS = "FC4";
			last;
		}

		# Fedora Core 5
		if(/(Fedora)(\s+)(Core)(\s+)(release)(\s+)(5)/) {
			$OS = "FC5";
			last;
		}

		# Redhat Enterprise Linux Server 7
		if( (/(release)(\s+)(7)/)
		||  (/(CentOS)([[:print:]]+)(\s)(7)/) ) {
			$OS = "RHEL7";
			last;
		}

		# ES 6
		# Redhat Enterprise Linux Server 6
		if( (/(release)(\s+)(6)/)
		||  (/(CentOS)([[:print:]]+)(\s)(6)/) ) {
			$OS = "RHEL6";
			last;
		}

		# ES 5
		# Redhat Enterprise Linux Server 5
		if( (/(release)(\s+)(5)/)
		||  (/(CentOS)([[:print:]]+)(\s)(5)/) ) {
			$OS = "RHEL5";
			last;
		}

		# EL 4
		if( (/(release)(\s+)(4)/) 
		||  (/(CentOS)([[:print:]]+)(\s)(4)/) ) {
			$OS = "RHEL4";
			last;
		}

		# Redhat 7.2
		if(/(release)(\s+)(7\.2)/) {
			$OS = "RH72";
			last;
		}
	}
	close(FILE);

	#
	# Allow a last minute switcheroo.
	#
	if ($ALTOS) {
	    $OS = $ALTOS;
	}

	return($OS);
}

#
# PCI 6.3
#	Develop software appliations in accordance with PCI DSS and
#	based on industry best practices, and incorporate information
#	security throughout the software development life cycle.
#
#	PCI 6.3.1.1
#	Validation of all input.
#
# Examples of how potentially dangerous input is converted:
#
# "some string; `cat /etc/passwd`" -> "some string cat /etc/passwd"
# "`echo $ENV; $(sudo ls)`" -> "echo ENV sudo ls"
#
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
# So, disk space requirements...
#
# Assumptions:
#   1) overhead for daisy install tree is ~250 MB
#   2) only an existing $destroot gets saved in encrypted tar archive
#   3) size of encrypted daisy tree is about 50%
#   4) for size of $prevroot, ignore overhead
#
# if $destroot does not exist
#   space needed == sizeof (daisy install tree) + sizeof ($prevroot)
#
# if $destroot does exist
#   if $prevroot == $destroot
#	sizof ($prevroot) = 0
#   space needed == sizeof (daisy install tree) +
#		    sizeof (encrypted($destroot)) +
#                   sizeof ($prevroot)
#
# fixme:
# there should be a module function to determine if a
# specified directory is a daisy database dir
#

sub is_disk_space_available
{
	my ($destroot, $prevroot) = @_;

	my $install_tree_size = 250000;

	my $destroot_size = 0;
	my $prevroot_size = 0;
	my $destroot_encrypted_size = 0;

	if (-d $prevroot && -f "$prevroot/control.dsy") {
	    if ($prevroot ne $destroot) {
		$prevroot_size = check_disk_usage($prevroot);
		if ($prevroot_size == -1) {
		    showerror("Error calculating disk space used by: $prevroot");
		    return(0);
		}
	    }
	}

	if (-d $destroot && -f "$destroot/control.dsy") {
	    $destroot_size = check_disk_usage($destroot);
	    if ($destroot_size == -1) {
		showerror("Error calculating disk space used by: $destroot");
		return(0);
	    }
	    $destroot_encrypted_size = 0.50 * $destroot_size;
	}

	my $space_needed = $install_tree_size +
			$destroot_encrypted_size +
			$prevroot_size;

	my $space_available = check_disk_free("/d");
	if ($space_available == 0) {
	    showerror("Error calculating disk space available");
	    return(0);
	}

	if ($SPACE_CHECK_ONLY) {
	    showinfo("Install tree size: $install_tree_size");
	    showinfo("Encrypted tree size: $destroot_encrypted_size");
	    showinfo("Previous tree size: $prevroot_size");
	    showinfo("Disk space required: $space_needed");
	    showinfo("Disk space available: $space_available");
	}

	if ($space_needed > $space_available) {
	    showerror("Disk space required ($space_needed) more than available ($space_available)");
	    return(0);
	}

	return($space_available);
}


sub check_disk_free
{
	my ($mount_point) = @_;

	my @fs_stats = ();

	# The output of the "df" command looks like this:
	#
	#Filesystem           1k-blocks          Used    Available Use% Mounted on
	#/dev/cciss/c0d0p1     26204060      22578308      2294656  91% /
	#
	# fs_stats[0]       fs_stats[1]   fs_stats[2]  fs_stats[3]
	#
	if (open(my $pipe, "df -k $mount_point |")) {
	    while(<$pipe>) {
		    next until(/$mount_point/);

		    chomp;
		    @fs_stats = split(/\s+/);
		    unless (@fs_stats) {
			    $fs_stats[3] = 0;
		    }

		    last;
	    }
	    close($pipe);
	}
	else {
	    $fs_stats[3] = 0;
	}

	return($fs_stats[3]);
}


sub check_disk_usage
{
        my $dir = $_[0];
	my $returnval;

	if (! -d $dir) {
		return(-1);
	}

	my $du_string = qx(du -s $dir);
        $returnval = $?;
	chomp ($du_string);
	my @duline = split (/\s+/, $du_string);
        if (($returnval != 0) || ("$duline[1]" ne "$dir")) {
                return(-1);
        }

	return($duline[0]);
}


#
# Verify Internet connectivity.
#
# Returns ping error percentage or -1 on error:
#     0 == success
#   100 == complete lack of connectivity
#   -1  == error running ping command
#
sub verify_internet
{
    my $ping_target = "www.google.com";

    showinfo("--> Pinging Internet target: $ping_target...");

    my $ping_count = 3;
    my $rc = -1;

    unless (open(PING, "ping -q -c $ping_count $ping_target |")) {
	showerror("Can't open pipe to ping command");
	return($rc);
    }

    #
    # Looking for line like:
    #	3 packets transmitted, 3 received, 0% packet loss, time 2022ms
    #
    my @ping_stats = ();
    while (<PING>) {
        chomp;
        if (/^$ping_count packets transmitted/) {
            @ping_stats = split(', ');
        }
    }
    close(PING);

    if (@ping_stats) {
	my $ping_error_percent = $ping_stats[2];
	$ping_error_percent =~ s/^(\d)+%(.*)$/$1/;

	if ($ping_error_percent == 0) {
	    showinfo("--> Internet target responded without error");
	}
	else {
	    showinfo("--> Internet target responded with error percentage: $ping_error_percent");
	}
	$rc = $ping_error_percent;
    }
    else {
	showerror("Can't get ping stats");
	$rc = -1;
    }

    return($rc);
}


#
# Since there are lots of places where we want to keep the user informed
# of progress and log that info as a tracer, combine both actions in a
# little "macro".
#
sub showinfo
{
	my $msg = $_[0];

	print("$msg\n");
	loginfo($msg);
}

sub showerror
{
	my $msg = $_[0];

	print("Error: $msg\n");
	logerror($msg);
}

#
# Log an informational message to the logfile.
#
sub loginfo
{
        my $msg = $_[0];

	logit($msg, "I");
}

sub logerror
{
        my $msg = $_[0];

	logit($msg, "E");
}

sub logit
{
        my $message = $_[0];
        my $type = $_[1];
        my $timestamp = "";

        chomp ($message);
        $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime());

        open LOGFILE, ">> $LOGFILE";
                print LOGFILE "$timestamp <$type> (PID $$) $message\n";
        close LOGFILE;

        return "";
}


__END__

=pod

=head1 NAME

install-daisy.pl - installation script for Teleflora Daisy POS

=head1 VERSION

This documenation refers to: $Revision: 1.352 $.


=head1 USAGE

install-daisy.pl B<--version>

install-daisy.pl B<--help>

install-daisy.pl [options] dest_daisy_dir [prev_daisy_dir] [install_files]


=head1 ARGUMENTS

=over 4

=item B<dest_daisy_dir>

The first argument specifies the path to a destination Daisy database directory.
The path should be to an existing Daisy database directory that is to be updated or
the path to new, not yet existing, Daisy database directory.

If the path is to a file system object that exists and
is not a valid Daisy database directory,
a diagnostic will be output and the install script will exit.

The definition of a valid destination Daisy database directory is:
 1) it must be a directory located in "/d".
 2) it must have a file named "control.dsy" in it.
 3) it must have a file named "flordat.dsy" in it.
 4) it must have a directory named "bin" in it.

=item B<prev_daisy_dir>

The second argument is optional and may be used to specify the path
to an existing Daisy database directory that will be used as the
source of data to migrate to the specified destination Daisy
database directory.

The definition of a valid previous Daisy database directory is:
 1) it may be located anywhere, eg "/tmp/d/daisy".
 2) it must have a file named "control.dsy" in it.
 3) it must have a file named "flordat.dsy" in it.
 4) it must have a directory named "bin" in it.

=item B<install_files>

The third argument is optional and may be used to specify the path
to the top of the mounted installation ISO.

=back


=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--country=string>

This option allows the specification of the country, either
the United States or Canada.
The values allowed for the United Stares are "us", "usa", or "United States".
The values allowed for Canada are "can", or "Canada".

=item B<--force>

This option must be specified when upgrading an existing
daisy database directory whose path is specified in the first argument
from a different existing daisy database directory whose path
is specified in the second argument.

=item B<--previous=string>

This allows the specification of the version of the previous
daisy database directory.  Use this option if the previous
daisy database directory is so old that there is no programmatic
way to determine it's version string.

=item B<--preserve-ostools>

Specify this option to preserve an installed version of the OSTools package if:
(1) there is an existing OSTools package installed, and (2) if it's a newer version
of the OSTools package than the one downloaded at the beginning of the install script.
If this option is not specified, the downloaded version will be installed regardless.

=item B<--config-audit-system>

Specify this option to configure the Linux Audit System with
the rules specific to a Daisy system.
The rules will be generated and put into the audit system config directory.
Upon the next reboot, the audit system will pick up the new rules.
In lieu of specifying this command line option, the environment
variable B<DAISY_CONFIG_AUDIT_SYSTEM> can be set to 1 and
exported to the environment before running the script
to achieve the same effect.

=back


=head1 DESCRIPTION

The Daisy installation script may be used to install the
Teleflora Daisy POS.
The script can install a completely new instance of Daisy,
generating all new Daisy files and modifying the system
as necessary to run Daisy.
It can also upgrade an existing installation of Daisy to a new
version of Daisy, keeping the existing data files, and NOT
modifying the system.
Finally, it can upgrade an existing installation of Daisy to a new
version of Daisy, and migrating the data from a previous Daisy
database directory.

=head2 Daisy Log Messages

At the end of the installation of a new version of Daisy,
the Daisy F<actions> and the I<logevent> commands in the newly
installed Daisy tree
are called to report that Daisy has been updated and to report the
new Daisy version string.


=head1 FILES

=over 4

=item F</d/daisy>

The path of the default Daisy database directory.
There may be one or more Daisy database directories but there must be
at least be a "/d/daisy".

=item F</tmp/daisy_install-YYYY-MM-DD.log>

The path to the log file that all log messsages are written to by the install.

=item F</d/daisy-yyyyMMDDHHMM.tar.asc>

As one of the very first steps performed, if an upgrade of an existing
Daisy database directory is being performed, the install script
makes an encrypted tar archive of the entire tree and puts it in
a file named as above.

=item F</etc/audit/rules.d/daisy.rules>

The file containing the generated rules for Linux Audit System that
are appropriate for a Daisy system.

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status 0

Successful completion or when the "--version" and "--help"
command line options are specified.

=item Exit status 1

There was an issue with one of the command line arguments or options:
 1) an invalid command line option was specified.
 2) the path to a destination Daisy database directory
    was not specified.
 3) if the path to the destination Daisy database directory
    exists and is not a Daisy database directory.
 4) if the path to the previous Daisy database directory
    does not exist or is not a Daisy database directory.

=item Exit status 2

If the install script was not executed with root privilege.

=item Exit status 3

If the B<--force> command line option was not specified when
upgrading an existing destination Daisy database directory from
an existing previous Daisy database directory.

=item Exit status 4

There was not enough disk space available to perform the installation.

=item Exit status 5

The path to the installation files was invalid or
the install files at the path provided did not conform
to the expected format.

=item Exit status 6

The installation files were built for a platform other than
the one the installation was being executed upon.

=item Exit status 9

Daisy could not be stopped so the installation aborted.

=item Exit status 10

The installation failed because Daisy could not be restarted after
the installation completed.

=item Exit status 12

The new version of the OSTools package could not be downloaded
from the Teleflora server or from the installation media.

=item Exit status 13

The installation of the OSTools package failed.

=back


=head1 SEE ALSO

B<dsyuser.pl>, B<dsyperms.pl>, B<harden_linux.pl>, B<killemall.pl>


=cut
