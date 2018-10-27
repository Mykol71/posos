#!/usr/bin/perl
#
# $Revision: 1.136 $
# Copyright 2009-2015 Teleflora
# 
# harden_linux.pl
#
# Script used to harden a daisy server towards PCI/PABP compliance.
#
# The exit status of the script will either be 0 for no errors or
# if there were errors in one or more of the options, the exit status
# will be the value of the last option with an error.
#

use strict;
use warnings;
use POSIX;
use Socket;
use Getopt::Long;
use English;
use File::Spec;
use File::Basename;
use Cwd;

use lib qw( /teleflora/ostools/modules /d/ostools/modules /usr2/ostools/modules );
use OSTools::Platform;
use OSTools::Hardware;
use OSTools::AppEnv;
use OSTools::Filesys;


my $CVS_REVISION = '$Revision: 1.136 $';
my $TIMESTAMP = strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($0);

my $HELP = 0;
my $VERSION = 0;
my $ALL = 0;
my $INSTALL = 0;
my $INSTALL_CONFIGFILE = 0;
my $INSTALL_UPGRADE = 0;
my $CONVERT_CONFIGFILE = 0;
my $CONFIGFILE_PATH = "";
my $CONFIGFILE_DIR = "";
my $CONFIGFILE_NAME = "harden_linux.conf";
my $REVERT_DELAY = 0;
my $REVERT_IPTABLES = 0;
my $REVERT_SUDO = 0;
my $IPTABLES = 0;
my $IPTABLES_PORTS = "";
my $SERVICES = 0;
my $WHITELIST_ENFORCE = 0;
my $BASTILLE = 0;
my $IPV6 = 0;
my $TIME = 0;
my $LOGGING = 0;
my $HOSTSALLOW = 0;
my $HOSTSALLOW_APPEND = "";
my $IDS = 0;
my $SSH = 0;
my $PAM = 0;
my $SUDO = 0;
my $SUDOERS_APPEND = "";
my $TestPam = 0;


# Global variables
my $ALTROOT = "";
my $OS = plat_os_version();

my $pid = -1;
my $exit_status = 0;
my @exit_list = ();

#
# Constants
#

# Exit status values
my $EXIT_OK = 0;
my $EXIT_COMMAND_LINE = 1;
my $EXIT_MUST_BE_ROOT = 2;
my $EXIT_CONVERT_CONFIG = 9;
my $EXIT_INSTALL_CONFIG = 10;
my $EXIT_REVERT_IPTABLES = 11;
my $EXIT_REVERT_SUDO = 12;
my $EXIT_INSTALL_UPGRADE = 14;
my $EXIT_OSTOOLS_VERSION = 15;
my $EXIT_IPTABLES = 20;
my $EXIT_IPV6 = 21;
my $EXIT_HOSTS_ALLOW = 22;
my $EXIT_PAM = 23;
my $EXIT_SUDO = 24;
my $EXIT_SERVICES = 25;
my $EXIT_BASTILLE = 26;
my $EXIT_LOGGING = 27;
my $EXIT_SSH = 28;
my $EXIT_TIME = 29;
my $EXIT_IDS = 30;

my $RTIDIR = "/usr2";
my $DAISYDIR = "/d";
my $OSTOOLS_BINDIR = "";

# Network attribute selector
my $NET_ATTR_IPADDR = 1;
my $NET_ATTR_BROADCAST = 2;
my $NET_ATTR_NETMASK = 3;

# Change types
# All that is needed is a unique value, so the type is cleverly
# the command line option value needed to revert the change.
my $REVERT_TYPE_IPTABLES = "--revert-iptables";
my $REVERT_TYPE_SUDO = "--revert-sudo";

#
# upgrade types
#
my $UPGRADE_BUILD = "build";
my $UPGRADE_MINOR = "minor";
my $UPGRADE_MAJOR = "major";

# Command line options
GetOptions (
	"version" => \$VERSION,
	"help" => \$HELP,
	"altroot=s" => \$ALTROOT,
	"configfile|configfile-path=s" => \$CONFIGFILE_PATH,
	"install-configfile" => \$INSTALL_CONFIGFILE,
	"install-upgrade" => \$INSTALL_UPGRADE,
	"convert-configfile" => \$CONVERT_CONFIGFILE,
	"revert-delay=s" => \$REVERT_DELAY,
	"revert-iptables" => \$REVERT_IPTABLES,
	"revert-sudo" => \$REVERT_SUDO,
	"install" => \$INSTALL,
	"all" => \$ALL,
	"iptables" => \$IPTABLES,
	"iptables-port=s" => \$IPTABLES_PORTS,
	"ipv6" => \$IPV6,
	"hostsallow" => \$HOSTSALLOW,
	"services" => \$SERVICES,
	"whitelist-enforce" => \$WHITELIST_ENFORCE,
	"bastille" => \$BASTILLE,
	"sudo" => \$SUDO,
	"pam" => \$PAM,
	"time" => \$TIME,
	"logging|logrotate" => \$LOGGING,
	"ids" => \$IDS,
	"ssh" => \$SSH,
	"test-pam" => \$TestPam,
) || die "Error: invalid command line option, exiting...\n";


# --version
if ($VERSION != 0) {
	print "OSTools Version: 1.15.0\n";
	print "$PROGNAME: $CVS_REVISION\n";
	exit($EXIT_OK);
}


# --help
if ($HELP != 0) {
	usage();
	exit($EXIT_OK);
}


loginfo("BEGIN $0 $CVS_REVISION");


loginfo("[main] operating system type: $OS");


# We must be root to do these things.
if ($ALTROOT eq "") {
    if ($EUID != 0) {
	showinfo("$0 must be run as root or with sudo");
	exit($EXIT_MUST_BE_ROOT);
    }
}


# Choose a location for the default confile file if one was not
# specified on the command line.
if ($CONFIGFILE_PATH eq "") {
    if (-d $RTIDIR) {
	$CONFIGFILE_DIR = "$RTIDIR/ostools/config";
	$OSTOOLS_BINDIR = "$RTIDIR/ostools/bin";
    }
    elsif (-d $DAISYDIR) {
	$CONFIGFILE_DIR = "$DAISYDIR/ostools/config";
	$OSTOOLS_BINDIR = "$DAISYDIR/ostools/bin";
    }
    else {
	$CONFIGFILE_DIR = "/teleflora/ostools/config";
	$OSTOOLS_BINDIR = "/teleflora/ostools/bin";
    }

    $CONFIGFILE_PATH = "$CONFIGFILE_DIR/$CONFIGFILE_NAME";
}

if ($CONVERT_CONFIGFILE) {
    exit(hl_configfile_convert($CONFIGFILE_PATH));
}

# --install-upgrade
#
# if the upgrade install option was specified, attempt an upgrade install and
# exit.
#
if ($INSTALL_UPGRADE) {
    if (hl_install_upgrade()) {
	exit($EXIT_OK);
    }
    else {
	logerror("[main] could not upgrade install");
	exit($EXIT_INSTALL_UPGRADE);
    }
}

# --install
# --install-configfile
#
# if the only the install option was specified, install a new config file and
# continue on with a normal install.
#
# if the install config file option was specified, then install a new config
# file and exit.  
#
if ($INSTALL || $INSTALL_CONFIGFILE) {

    my $rc = hl_configfile_install($CONFIGFILE_PATH);
    if ($INSTALL_CONFIGFILE) {
	$rc = ($rc) ? $EXIT_OK : $EXIT_INSTALL_CONFIG;
	exit($rc);
    }

    $ALL = 1;
}

# if --all specified or if none of the configuration options are specifed,
# then make them all true.

if ($ALL) {
    $IPTABLES = $IPV6 = $HOSTSALLOW = $SERVICES =
    $BASTILLE = $SUDO = $PAM = $TIME = $LOGGING = $SSH = $IDS = 1;
}
else {
    my $options_sum =
	$IPTABLES + $IPV6 + $HOSTSALLOW + $SERVICES + $BASTILLE +
	$SUDO + $PAM + $TIME + $LOGGING + $SSH + $IDS;

    if ($options_sum == 0) {
	$IPTABLES = $IPV6 = $HOSTSALLOW = $SERVICES =
	$BASTILLE = $SUDO = $PAM = $TIME = $LOGGING = $SSH = $IDS = 1;
	$ALL = 1;
    }
}

# read the config file at this point so that it overrides the
# command line
if (hl_configfile_read($CONFIGFILE_PATH) ne 0) {
    showinfo("[main] could not process config file: $CONFIGFILE_PATH");
}

# --revert-iptables
if ($REVERT_IPTABLES) {
    exit(revert_change($REVERT_TYPE_IPTABLES));
}

# --revert-sudo
if ($REVERT_SUDO) {
    exit(revert_change($REVERT_TYPE_SUDO));
}

if ($ALL) {
    showinfo("[main] hardening all supported system configurations");
}

# --iptables
if ($IPTABLES) {
	if ($REVERT_DELAY > 0) {
	    revert_preserve($REVERT_TYPE_IPTABLES);
	}

	$exit_status = hl_harden_iptables($IPTABLES_PORTS) ? 0 : $EXIT_IPTABLES;
	push(@exit_list, $exit_status);

	if ($exit_status == 0 && $REVERT_DELAY > 0) {
	    revert_setup($REVERT_TYPE_IPTABLES, $REVERT_DELAY);
	}
}

# --ipv6
if ($IPV6) {
	$exit_status = disable_ipv6() ? 0 : $EXIT_IPV6;
	push(@exit_list, $exit_status);
}

# --hostsallow
if ($HOSTSALLOW) {
	$exit_status = modify_host_access() ? $EXIT_OK : $EXIT_HOSTS_ALLOW;
	push(@exit_list, $exit_status);
}

# --pam
if ($PAM) {
	$exit_status = pam_modify_securetty() ? 0 : $EXIT_PAM;
	push(@exit_list, $exit_status);
	$exit_status = pam_modify_rules() ? 0 : $EXIT_PAM;
	push(@exit_list, $exit_status);
	$exit_status = pam_modify_pamsu() ? 0 : $EXIT_PAM;
	push(@exit_list, $exit_status);
}

# --sudo
if ($SUDO) {
	if ($REVERT_DELAY > 0) {
	    revert_preserve($REVERT_TYPE_SUDO);
	}

	$exit_status = modify_sudoers() ? 0 : $EXIT_SUDO;
	push(@exit_list, $exit_status);

	if ($exit_status == 0 && $REVERT_DELAY > 0) {
	    revert_setup($REVERT_TYPE_SUDO, $REVERT_DELAY);
	}
}

# --services
if ($SERVICES) {
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	$exit_status = setup_system_services() ? $EXIT_OK : $EXIT_SERVICES;
    }
    if ($OS eq 'RHEL7') {
	$exit_status = configure_system_services() ? $EXIT_OK : $EXIT_SERVICES;
    }
    push(@exit_list, $exit_status);
}

# --bastille
if ($BASTILLE) {
	$exit_status = modify_bastille() ? $EXIT_OK : $EXIT_BASTILLE;
	push(@exit_list, $exit_status);
}

# --logging
if ($LOGGING) {
	$exit_status = modify_logrotate() ? $EXIT_OK : $EXIT_LOGGING;
	push(@exit_list, $exit_status);
}

# --ssh
if ($SSH) {
	$exit_status = modify_sshd() ? $EXIT_OK : $EXIT_SSH;
	push(@exit_list, $exit_status);
}

# --time
if ($TIME) {
	$exit_status = modify_timeservers() ? 0 : $EXIT_TIME;
	push(@exit_list, $exit_status);
}

# --ids
# Do this last.
if ($IDS) {
	$exit_status = update_aide() ? 0 : $EXIT_IDS;
	push(@exit_list, $exit_status);
}


loginfo("END $0 $CVS_REVISION");


#
# look for the last result that was an error, so pop results
# off the stack until one is non-zero or stack is empty.
#
while ( defined($exit_status = pop(@exit_list)) ) {
	if ($exit_status != $EXIT_OK) {
	    last;
	}
}

#
# if at this point the $exit_status has value undef, then
# there were no entries on the stack with non-zero value,
# ie there were no errors.
#
if (!defined($exit_status)) {
    $exit_status = $EXIT_OK;
}

exit ($exit_status);

######################################################################
######################################################################
######################################################################


sub usage
{
	print("\n");
	print("$PROGNAME $CVS_REVISION Usage:\n");
	print("Usage:\n");
	print(<< "EOF");
$PROGNAME --help                 # write this help message and exit
$PROGNAME --version              # report version and exit
$PROGNAME --all                  # run all configuration options
$PROGNAME --install-configfile   # install default config file
$PROGNAME --convert-configfile   # convert append directives in config file 
$PROGNAME --configfile=path      # set path to config file
$PROGNAME --revert-iptables      # revert previous iptables change and exit
$PROGNAME --revert-sudo          # revert previous sudo change and exit
$PROGNAME --revert-delay=n       # revert change after 'n' minutes (def: 0, max = 60)

-- Configuration Options --
$PROGNAME --iptables [--revert-delay=n]
$PROGNAME --ipv6
$PROGNAME --hostsallow
$PROGNAME --pam
$PROGNAME --sudo [--revert-delay=n]
$PROGNAME --services [--whitelist-enforce]
$PROGNAME --bastille
$PROGNAME --logging|--logrotate
$PROGNAME --ssh
$PROGNAME --time
$PROGNAME --ids

If there is an error during execution of any option, exit status
of script will be that of last option with an error.
EOF

    return(1);
}


sub ost_info_compare_versions
{
    my ($ost_vers_info_old, $ost_vers_info_new) = @_;

    my $upgrade_type = $UPGRADE_BUILD;

    if ($ost_vers_info_new->{MAJOR} > $ost_vers_info_old->{MAJOR}) {
	$upgrade_type = $UPGRADE_MAJOR;
    }

    if ( ($ost_vers_info_new->{MAJOR} == $ost_vers_info_old->{MAJOR}) &&
	 ($ost_vers_info_new->{MINOR} > $ost_vers_info_old->{MINOR}) ) {
	$upgrade_type = $UPGRADE_MINOR;
    }

    if ( ($ost_vers_info_new->{MAJOR} == $ost_vers_info_old->{MAJOR}) &&
	 ($ost_vers_info_new->{MINOR} == $ost_vers_info_old->{MINOR}) &&
	 ($ost_vers_info_new->{BUILD} > $ost_vers_info_old->{BUILD}) ) {
	$upgrade_type = $UPGRADE_BUILD;
    }

    return($upgrade_type);
}


#
# parse the ostools version string into it's constituent parts.
#
# Returns
#   version info hash on success
#   empty hash if not found
#   
sub ost_info_parse_version
{
    my ($ost_version_string) = @_;

    my %ost_vers_info = ();

    if ($ost_version_string =~ /(\d+)\.(\d+)\.(\d+)/) {
	$ost_vers_info{FULL} = $ost_version_string;
	$ost_vers_info{MAJOR} = $1;
	$ost_vers_info{MINOR} = $2;
	$ost_vers_info{BUILD} = $3;
    }

    return(%ost_vers_info);
}


sub ost_info_get_new_version
{
    my %ost_vers_info = ost_info_parse_version("1.15.0");

    return(%ost_vers_info);
}


#
# Look for an installed ostools package in standard locations.
#
# Return
#   version info hash on success
#   empty hash if not found
#
sub ost_info_get_installed_version
{
    my @ost_bindirs = qw(
	/usr2/ostools/bin
	/d/ostools/bin
	/teleflora/ostools/bin
    );

    # look for an ostools bindir
    my $ost_bindir = "";
    foreach my $bindir (@ost_bindirs) {
	if (-d $bindir) {
	    $ost_bindir = $bindir;
	    last;
	}
    }

    # if ostools bindir found, get version string
    my $ost_installed_version = "";
    if ($ost_bindir) {
	my $ost_cmd = "$ost_bindir/tfinfo.pl --version";
	loginfo("[ost version] cmd to get ostools version string: $ost_cmd");
	if (open(my $pfh, '-|', $ost_cmd)) {
	    while (<$pfh>) {
		if (/^OSTools Version: (.+)$/i) {
		    $ost_installed_version = $1;
		    last;
		}
	    }
	    close($pfh);
	}
	else {
	    showinfo("[ost version] could not run script to get ostools version string: $ost_cmd");
	    return($ost_installed_version);
	}
    }
    else {
	logerror("[ost version] could not find ostools bin dir");
    }

    # if version string found, parse it
    my %ost_vers_info = ();
    if ($ost_installed_version) {
	%ost_vers_info = ost_info_parse_version($ost_installed_version);
    }

    return(%ost_vers_info);
}


sub install_get_custom_rules
{
    my ($ha_custom_rules_ref) = @_;

    $$ha_custom_rules_ref = "";

    my $conf_file = "$ALTROOT/etc/hosts.allow";

    unless (open(FILE, "<", $conf_file)) {
	showinfo("Can't read conf file: $conf_file");
	return(0);
    }

#
# output from ostools-1.12 at then end of generated content
# and hopefully (!) anything after this line till the end of
# file will be the custom content.
#
#   #
#   # End of generated content
#   #

    my $is_in_custom_section = 0;
    my $is_first_line_in_custom_section = 0;
    while (<FILE>) {
	if (/\s*# End of generated content/) {
	    $is_in_custom_section = 1;
	    $is_first_line_in_custom_section = 1;
	    next;
	}

	if ($is_in_custom_section) {
	    # skip first line in custom section if it's a blank comment
	    if ($is_first_line_in_custom_section) {
		$is_first_line_in_custom_section = 0;
		if (/^#$/) {
		    next;
		}
	    }
	    $$ha_custom_rules_ref .= $_;
	}
    }

    close(FILE);

    return(1);
}


sub install_sanitize_conf_file
{
    my ($conf_file) = @_;

    my $timestamp = strftime("%Y%m%d-%H%M%S", localtime());
    my $new_conf_file = "$conf_file-$timestamp";
    my $cfh;
    my $ncfh;

    unless (open($cfh, "<", $conf_file)) {
	showinfo("Could not open existing config file: $conf_file");
	return(0);
    }

    unless (open($ncfh, ">", $new_conf_file)) {
	showinfo("Could not make new config file: $new_conf_file");
	close($cfh);
	return(0);
    }

    loginfo("Sanitizing config file: $conf_file");

    while(<$cfh>) {
	# skip "append" sections
	if (/^(\s*append\s+)(\/etc\/hosts.allow)(\s*<<\s*)([[:print:]]+)$/i) {
	    my $end_of_append_marker = $4;
	    while(<$cfh>) {
		if (/^$end_of_append_marker/) {
		    last;
		}
	    }
	}

	# everything else goes to copy of config file
	else {
	    print {$ncfh} $_;
	}
    }
    close($cfh);
    close($ncfh);

    # only weak verification: an error if new conf file is zero sized
    if (-z $new_conf_file) {
	showinfo("Could not sanitize config file: $conf_file");
	system("rm $new_conf_file");
	return(0);
    }

    # presume conf file was successfully transformed...
    # so replace the old one with the new.
    system("chmod --reference=$conf_file $new_conf_file");
    system("chown --reference=$conf_file $new_conf_file");
    system("mv $new_conf_file $conf_file");

    return(1);
}


sub install_sanitize_custom_rules
{
    my ($ha_custom_rules_ref) = @_;

    $$ha_custom_rules_ref =~ s/^#\n# Begin custom sshd rules\n#\n//;
    $$ha_custom_rules_ref =~ s/#\n# End custom sshd rules\n#\n$//;

    return(1);
}


sub install_put_custom_rules
{
    my ($ha_custom_rules) = @_;

    my $conf_file = "$ALTROOT" . "$CONFIGFILE_PATH";

    unless (install_sanitize_conf_file($conf_file)) {
	showinfo("Could not remove pre-existing host access append sections: $conf_file");
	return(0);
    }

    unless (open(FILE, ">>", $conf_file)) {
	showinfo("Can't append to conf file: $conf_file");
	return(0);
    }

    print FILE "append /etc/hosts.allow << __EndAppendMarker__\n";

    print FILE "$ha_custom_rules";

    print FILE "__EndAppendMarker__\n";

    close(FILE);

    return(1);
}


sub install_upgrade_host_access
{
    my $ha_custom_rules = "";

    unless (install_get_custom_rules(\$ha_custom_rules)) {
	return(0);
    }

    if ($ha_custom_rules) {
	unless (install_sanitize_custom_rules(\$ha_custom_rules)) {
	    return(0);
	}
	unless (install_put_custom_rules($ha_custom_rules)) {
	    return(0);
	}
    }

    return(1);
}


#
# major upgrade
#
sub hl_install_upgrade_major
{
    loginfo("[major upgrade] no upgrade necessary");

    return(1);
}


#
# minor upgrade
#
sub hl_install_upgrade_minor
{
    loginfo("[minor upgrade] no upgrade necessary");

    return(1);
}


#
# do whatever is necessary to perform an upgrade.
#
# Returns
#   1 on success
#   0 if error
#
sub hl_install_upgrade
{
    my %ost_vers_info_old = ost_info_get_installed_version();

    my $rc = 1;

    if (defined($ost_vers_info_old{FULL})) {
	my %ost_vers_info_new = ost_info_get_new_version();
	if (defined($ost_vers_info_new{FULL})) {
	    my $upgrade_type = ost_info_compare_versions(\%ost_vers_info_old, \%ost_vers_info_new);
	    if ($upgrade_type eq $UPGRADE_MAJOR) {
		hl_install_upgrade_major();
	    }
	    elsif ($upgrade_type eq $UPGRADE_MINOR) {
		hl_install_upgrade_minor();
	    }
	    else {
		loginfo("[install upgrade] upgrade unnecessary");
	    }
	}
	else {
	    showinfo("[install upgrade] could not get version of new ostools");
	    $rc = 0;
	}
    }
    else {
	showinfo("[install upgrade] could not get version of installed ostools");
	$rc = 0;
    }

    return($rc);
}


#
# Returns 1 on success, 0 if error
#
sub hl_configfile_append_gather
{
    my ($cfh, $marker, $bufref) = @_;

    my $rc = 1;
    my $marker_seen = 0;

    while(<$cfh>) {
	chomp;
	if (/^$marker$/) {
	    $marker_seen = 1;
	    last;
	}
	$$bufref .= "$_\n";
    }

    if ($marker_seen == 0) {
	logerror("append marker not seen before EOF: $marker");
	$rc = 0;
    }

    return($rc);
}


#
# Convert a config file with "append <<" or "append == file" to
# one with only "append == directory".
#
# Returns 1 on success, 0 if error
#
sub hl_configfile_convert_append
{
    my ($cfh, $bufref) = @_;

    my $rc = 1;
    my $config_line;
    my $append_buffer;
    my $append_file_path = "";
    my $last_append_type = "none";

    while(<$cfh>) {
	chomp;
	$config_line = $_;

	if ($config_line =~ /^(\s*append\s+\/etc\/sudoers\s*<<\s*)([[:print:]]+)$/i) {
	    my $append_marker = $2;
	    $last_append_type = "here_doc";
	    $append_buffer = "";
	    if (hl_configfile_append_gather($cfh, $append_marker, \$append_buffer) == 0) {
		logerror("can't convert append directive: $config_line");
		$rc = 0;
		last;
	    }
	}

	elsif ($config_line =~ /^(\s*append\s+\/etc\/sudoers\s*==\s*)([[:print:]]+)$/i) {
	    $append_file_path = $2;
	    if (-e $append_file_path) {
		if (-f $append_file_path) {
		    $last_append_type = "file";
		}
		elsif (-d $append_file_path) {
		    $last_append_type = "dir";
		    $$bufref .= "$config_line\n"
		}
		else {
		    logerror("append directive file unknown type: $append_file_path");
		    $rc = 0;
		    last;
		}
	    }
	    else {
		logerror("append directive file does not exist: $append_file_path");
		$rc = 0;
		last;
	    }
	}

	else {
	    $$bufref .= "$config_line\n"
	}
    }

    return($rc) if ($rc == 0);

    # make the new directory for content files if necessary.
    # it's ok for this directory to be empty.
    if (! -d "$CONFIGFILE_DIR/sudoers.d") {
	system("mkdir $CONFIGFILE_DIR/sudoers.d");
	system("chmod 755 $CONFIGFILE_DIR/sudoers.d");
	system("chown --reference=$CONFIGFILE_PATH $CONFIGFILE_DIR/sudoers.d");
    }

    if ($last_append_type eq "here_doc") {
	my $timestamp = strftime("%Y%m%d-%H%M%S", localtime());
	my $new_config = "$CONFIGFILE_DIR/sudoers.d/sudoers-" . $timestamp . ".conf";
	if (open(my $fh, '>', $new_config)) {
	    print($fh $append_buffer);
	    close($fh);
	}
	system("chmod --reference=$CONFIGFILE_PATH $CONFIGFILE_DIR/sudoers.d/*");
	system("chown --reference=$CONFIGFILE_PATH $CONFIGFILE_DIR/sudoers.d/*");
	$$bufref .= "append /etc/sudoers == $CONFIGFILE_DIR/sudoers.d\n"
    }
    elsif ($last_append_type eq "file") {
	system("mv $append_file_path $CONFIGFILE_DIR/sudoers.d");
	system("chmod --reference=$CONFIGFILE_PATH $CONFIGFILE_DIR/sudoers.d/*");
	system("chown --reference=$CONFIGFILE_PATH $CONFIGFILE_DIR/sudoers.d/*");
	$$bufref .= "append /etc/sudoers == $CONFIGFILE_DIR/sudoers.d\n"
    }
    elsif ($last_append_type eq "dir") {
	loginfo("last append directive type 'directory' - no conversion required");
    }
    else {
	loginfo("config file did not contain any append directives");
	$$bufref .= "append /etc/sudoers == $CONFIGFILE_DIR/sudoers.d\n"
    }

    return($rc);
}


#
# Write text of converted config file to new config file.
#
# Returns 1 on success, 0 on error
#
sub hl_configfile_convert_write
{
    my ($config_path, $bufref) = @_;

    my $rc = 1;
    my $timestamp = strftime("%Y%m%d-%H%M%S", localtime());
    my $new_config = $config_path . '-' . $timestamp;
 
    if (open(my $cfh, ">", $new_config)) {
	print($cfh $$bufref);
	close($cfh);

	if (-z $new_config) {
	    logerror("new config file zero length: $new_config");
	    unlink($new_config);
	    $rc = 0;
	}
	else {
	    system("chmod --reference=$config_path $new_config");
	    system("chown --reference=$config_path $new_config");
	    system("mv $new_config $config_path");
	}
    }
    else {
	logerror("can't open new config file: $new_config");
	$rc = 0;
    }

    return($rc);
}


#
# Convert append directives in config file.
#
# Returns 0 on success, 1 if error since return value is used as
# the exit status of the program.
#
sub hl_configfile_convert
{
    my ($config_path) = @_;
    my $rc = 0;

    if (-e $config_path) {
	if (open(my $cfh, "<", $config_path)) {
	    my $buffer = "";
	    if (hl_configfile_convert_append($cfh, \$buffer)) {
		if ($buffer ne "") {
		    if (hl_configfile_convert_write($config_path, \$buffer)) {
			loginfo("config file converted: $config_path");
		    }
		    else {
			showerror("can't write new config file: $config_path");
			$rc = 1;
		    }
		}
	    }
	    else {
		showerror("config file conversion failed: $config_path");
		$rc = 1;
	    }
	    close($cfh);
	}
	else {
	    showerror("can't open config file: $config_path");
	    $rc = 1;
	}
    }
    else {
	showerror("config file does not exist: $config_path");
	$rc = 1;
    }

    return($rc);
}


#
# Install the config file.  Of there is an existing config file,
# then do not overwrite it, just leave a new one with the file
# extension of ".new".
#
# Returns 1 on success, 0 if issues
#
sub hl_configfile_install
{
    my ($configfile_path) = @_;

    #
    # If config file exists, write a new one with ".new" suffix and
    # leave the old one in place.
    #
    if (-f $configfile_path) {
	$configfile_path .= ".new";
    }

    unless (open(CONFIG, ">", $configfile_path)) {
	loginfo("Can't open new default config file: $configfile_path");
	return(0);
    }

    loginfo("Begin installing default config file");

    print(CONFIG "#\n");
    print(CONFIG "# $PROGNAME Config File\n");
    print(CONFIG "# Generated by $PROGNAME $CVS_REVISION $TIMESTAMP\n");
    print(CONFIG "#\n");

    print(CONFIG << 'EOB');
# enable/disable configuring iptables
# default: yes
#iptables=yes

# enable/disable configuring ipv6
# default: yes
#ipv6=yes

# enable/disable configuring /etc/hosts.allow
# default: yes
#hostsallow=yes

# enable/disable configuring system services
# default: yes
#services=yes
#whitelist-enforce=no

# enable/disable configuring items from "bastille report"
# default: yes
#bastille=yes

# enable/disable configuring /etc/sudoers file
# default: yes
#sudo=yes

# enable/disable configuring PAM rules
# default: yes
#pam=yes

# enable/disable configuring NTP timer servers
# default: yes
#time=yes

# enable/disable configuring log rotation
# default: yes
#logging=yes

# enable/disable configuring intrusion detection
# default: yes
#ids=yes

# enable/disable configuring sshd system services
# default: yes
#ssh=yes

# Allow specification of additional inbound ports to open
# in the iptables "INPUT" chain of the "filter" table.
# Zero or more of these directives are allowed.
# For each directive, only 1 port number is allowed.
# The allowed value of <n> is 0 to 65535.
#iptables-port=<n>

# append site specific contents to generated config file
# default: none
#
# In the append directive grammar description below,
# the value for <conf_file> can be:
#	/etc/hosts.allow
#	/etc/sudoers
# the value for <marker> can be:
#	any unique string, eg EOF
# the value for <path> can be:
#	the path to a file with the contents
#	to be appended to the generated config file.
#
#append <conf_file> << <marker>
#append <conf_file> == <path>
EOB

    close(CONFIG);

    my $owner = "root";
    my $group = "root";

    if (-d "/usr2/bbx/config") {
	$owner = "tfsupport";
	$group = "rtiadmins";
    }
    elsif (-d "/d/daisy/config") {
	$owner = "tfsupport";
	$group = "dsyadmins";
    }

    system ("chown $owner:$group $configfile_path");
    system ("chmod 640 $configfile_path");

    loginfo("End installing default config file");

    return(1);
}


sub hl_configfile_append_directory
{
    my ($dir_path, $buffer) = @_;

    my @files = glob("$dir_path/*.conf");

    if (scalar(@files)) {
	foreach my $file_path (@files) {
	    hl_configfile_append_file($file_path, $buffer);
	}
    }
    else {
	loginfo("append directory does not contain any config files: $dir_path")
    }

    return(1);
}


sub hl_configfile_append_file
{
    my ($file_path, $buffer) = @_;

    if (open(my $afh, "<", $file_path)) {
	while (<$afh>) {
	    ${$buffer} .= $_;
	}
	close($afh);
    }
    else {
	showerror("can't open file specified in append directive: $file_path");
    }

    return(1);
}


#
# Handle the following config file directives:
#   "append" <conf_file> "<<" <marker>
#   "append" <conf_file> "==" <file_path>
#   "append" <conf_file> "==" <directory_path>
#
sub hl_configfile_parse_append
{
    my ($cfh, $append_directive) = @_;

    my @conf_files = (
	[ "/etc/hosts.allow", \$HOSTSALLOW_APPEND ],
	[ "/etc/sudoers", \$SUDOERS_APPEND ]
    );

    for my $i (0 .. $#conf_files) {
	if ($append_directive =~ /^(\s*append\s+)($conf_files[$i][0])(\s*<<\s*)([[:print:]]+)$/i) {
	    my $append_marker = $4;
	    my $append_marker_seen = 0;
	    ${$conf_files[$i][1]} = "";
	    while(<$cfh>) {
		chomp;
		if (/^$append_marker$/) {
		    $append_marker_seen = 1;
		    last;
		}
		${$conf_files[$i][1]} .= "$_\n";
	    }
	    unless ($append_marker_seen) {
		showinfo("append marker not seen before EOF");
	    }
	}

	if ($append_directive =~ /^(\s*append\s+)($conf_files[$i][0])(\s*==\s*)([[:print:]]+)$/i) {
	    my $append_file_path = $4;
	    if (-e $append_file_path) {
		${$conf_files[$i][1]} = "";
		if (-d $append_file_path) {
		    hl_configfile_append_directory($append_file_path, $conf_files[$i][1]);
		}
		else {
		    hl_configfile_append_file($append_file_path, $conf_files[$i][1]);
		}
	    }
	    else {
		showinfo("File specified in append directive does not exist: $append_file_path");
	    }
	}
    }

    return(1);
}


#
# Read the config file if it exists.
#
# Returns 0 on success, 1 on error
#
sub hl_configfile_read
{
    my ($configfile_path) = @_;
    my $cfh;

    unless (-e $configfile_path) {
	loginfo("[config] config file does not exist: $configfile_path");
	return(0);
    }

    unless (open($cfh, "<", $configfile_path)) {
	loginfo("[config] could not open configfile: $configfile_path");
	return(1);
    }

    loginfo("[config] reading configfile: $configfile_path");

    while(<$cfh>) {

	# enable/disable configuring iptables
	# iptables=yes
	# iptables=no
	if (/^(\s*)(iptables)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[NnFf0]/) {
		if ($IPTABLES) {
		    loginfo("[config] negating --iptables from conf file");
		}
		$IPTABLES = 0;
	    }
	}

	# enable/disable configuring ipv6
	# ipv6=yes
	# ipv6=no
	if (/^(\s*)(ipv6)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[NnFf0]/) {
		if ($IPV6) {
		    loginfo("[config] negating --ipv6 from conf file");
		}
		$IPV6 = 0;
	    }
	}

	# enable/disable configuring /etc/hosts.allow
	# hostsallow=yes
	# hostsallow=no
	if (/^(\s*)(hostsallow)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[NnFf0]/) {
		if ($HOSTSALLOW) {
		    loginfo("[config] negating --hostsallow from conf file");
		}
		$HOSTSALLOW = 0;
	    }
	}

	# enable/disable configuring system services
	# services=yes
	# services=no
	if (/^(\s*)(services)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[NnFf0]/) {
		if ($SERVICES) {
		    loginfo("[config] negating --services from conf file");
		}
		$SERVICES = 0;
	    }
	}

	# enforce system services whitelist on RHEL7
	# whitelist-enforce=yes
	# whitelist-enforce=no
	if (/^(\s*)(whitelist-enforce)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[YyTt1]/) {
		$WHITELIST_ENFORCE = 1;
	    }
	}

	# enable/disable configuring items from "bastille report"
	# bastille=yes
	# bastille=no
	if (/^(\s*)(bastille)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[NnFf0]/) {
		if ($BASTILLE) {
		    loginfo("[config] negating --bastille from conf file");
		}
		$BASTILLE = 0;
	    }
	}

	# enable/disable configuring /etc/sudoers file
	# sudo=yes
	# sudo=no
	if (/^(\s*)(sudo)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[NnFf0]/) {
		if ($SUDO) {
		    loginfo("[config] negating --sudo from conf file");
		}
		$SUDO = 0;
	    }
	}

	# enable/disable configuring PAM rules
	# pam=yes
	# pam=no
	if (/^(\s*)(pam)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[NnFf0]/) {
		if ($PAM) {
		    loginfo("[config] negating --pam from conf file");
		}
		$PAM = 0;
	    }
	}

	# enable/disable configuring NTP timer servers
	# time=yes
	# time=no
	if (/^(\s*)(time)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[NnFf0]/) {
		if ($TIME) {
		    loginfo("[config] negating --time from conf file");
		}
		$TIME = 0;
	    }
	}

	# enable/disable configuring log rotation
	# logging=yes
	# logging=no
	if (/^(\s*)(logging)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[NnFf0]/) {
		if ($LOGGING) {
		    loginfo("[config] negating --logging from conf file");
		}
		$LOGGING = 0;
	    }
	}

	# enable/disable configuring intrusion detection
	# ids=yes
	# ids=no
	if (/^(\s*)(ids)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[NnFf0]/) {
		if ($IDS) {
		    loginfo("[config] negating --ids from conf file");
		}
		$IDS = 0;
	    }
	}

	# enable/disable configuring sshd system services
	# ssh=yes
	# ssh=no
	if (/^(\s*)(ssh)(\s*)(=)(\s*)([[:print:]]+)$/i) {
	    if ($6 =~ /[NnFf0]/) {
		if ($SSH) {
		    loginfo("[config] negating --ssh from conf file");
		}
		$SSH = 0;
	    }
	}

	# Allow specification of additional inbound ports to open
	# in the iptables "INPUT" chain of the "filter" table.
	# Zero or more of these directives are allowed.
	# For each directive, only 1 port number is allowed.
	# The allowed value of <n> is 0 to 65535.
	#iptables-port=<n>
	if (/^(\s*)(iptables-port)(\s*=\s*)(\d+)$/i) {
	    loginfo("[config] adding $4 to list of iptables inbound ports from conf file");
	    $IPTABLES_PORTS .= ',' if ($IPTABLES_PORTS ne "");
	    $IPTABLES_PORTS .= $4;
	}

	# site specific contents for config file
	# append <config file path> == <site specific file path>
	# append <config file path> << <marker>
	# text
	# <marker>
	if (/^(\s*)append(\s+)/i) {
	    hl_configfile_parse_append($cfh, $_);
	}
    }
    close($cfh);

    return(0);
}


sub get_hostname
{
    my $hostname = qx(/bin/hostname);
    chomp($hostname);

    return($hostname);
}


sub get_host_ipaddr
{
    my $hostname = get_hostname();

    # from perlfaq9
    my $ipaddr = inet_ntoa(scalar gethostbyname($hostname));

    return($ipaddr);
}


sub get_network_attribute
{
    my ($device, $selector) = @_;

    my $attribute_val = "";
    open(PIPE, "/sbin/ifconfig $device 2> /dev/null |");
    while(<PIPE>) {

	my $pattern = "";
	if ($selector eq $NET_ATTR_IPADDR) {
	    $pattern = "inet addr";
	}
	elsif ($selector eq $NET_ATTR_BROADCAST) {
	    $pattern = "Bcast";
	}
	elsif ($selector eq $NET_ATTR_NETMASK) {
	    $pattern = "Mask";
	}

	if (/($pattern):(\d+\.\d+\.\d+\.\d+)/) {
	    $attribute_val = $2;
	}
    }
    close(PIPE);

    return($attribute_val);
}


#
# Determine the address of the gateway.
#
sub get_gateway_ipaddr
{
    my @route_table_entry = ();
    my $gateway = "";

    my $route_cmd = ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) ? 'ip route list' : '/sbin/route -n';
    my $pattern = ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) ? 'default' : '0.0.0.0';
    
    if (open(my $pipe, '-|', $route_cmd)) {
	while (<$pipe>) {
	    next until(/^$pattern/);
	    @route_table_entry = split(/\s+/);
	    last;
	}
	close($pipe);
    }
    else {
	logerror("could not get gateway ip address from: $route_cmd");
	return("");
    }

    # check for a route table entry with something in it
    if ($#route_table_entry <= 0) {
	return("");
    }

    # for RHEL6 and RHEL7 systems, the ip address of gateway is at
    # index 2 rather than 1
    my $i = ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) ? 2 : 1;
    $gateway = $route_table_entry[$i];
    if ($gateway =~ /(\d+)(\.)(\d+)(\.)(\d+)(\.)(\d+)/) {
	return($gateway);
    }

    return("");
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


#
# Returns 0 on success
# On iptables error, returns: $EXIT_REVERT_IPTABLES;
# On sudo error, returns: $EXIT_REVERT_SUDO;
#
sub revert_change
{
    my ($revert_type) = @_;

    my $retval = 0;

    if ($revert_type eq $REVERT_TYPE_IPTABLES) {
	my $savefile = "$CONFIGFILE_DIR/iptables.save";
	my $restore_cmd = "iptables-restore $savefile";
	system("$restore_cmd");
	if ($? != 0) {
	    showinfo("Could not revert to previous iptables config");
	    $retval = $EXIT_REVERT_IPTABLES;
	}
    }

    elsif ($revert_type eq $REVERT_TYPE_SUDO) {
	my $savefile = "$CONFIGFILE_DIR/sudoers.save";
	my $restore_cmd = "cp -f $savefile /etc/sudoers";
	system("$restore_cmd");
	if ($? != 0) {
	    showinfo("Could not revert to previous sudo config");
	    $retval = $EXIT_REVERT_SUDO;
	}
    }

    else {
	showinfo("Can't happen: bad arg to function revert_change()");
	$retval = 1;
    }

    return($retval);
}


#
# Preserve neccessary data before making a change so that the
# config can be reverted.
#
# Returns 0 on success, else 1
#
sub revert_preserve
{
    my ($revert_type) = @_;

    my $retval = 0;
    my $savefile = "";
    my $savecmd = "";

    if ($revert_type eq $REVERT_TYPE_IPTABLES) {
	$savefile = "$CONFIGFILE_DIR/iptables.save";
	$savecmd = "iptables-save > $savefile";
    }

    elsif ($revert_type eq $REVERT_TYPE_SUDO) {
	$savefile = "$CONFIGFILE_DIR/sudoers.save";
	$savecmd = "cp -f /etc/sudoers $savefile";
    }

    else {
	showinfo("Can't happen: bad arg to function preserve_before_change()");
    }

    if ($savefile) {
	system("$savecmd");
	if (-s $savefile) {
	    system("chmod 600 $savefile");
	}
	else {
	    system("rm -f $savefile");
	    showinfo("Can't preserve config for: $revert_type");
	    $retval = 1;
	}
    }

    return($retval);
}


sub revert_setup
{
    my ($revert_type, $revert_delay) = @_;

    my $retval = 0;

    my $revert_script = "$OSTOOLS_BINDIR/harden_linux.pl";
    my $revert_cmd = "$revert_script $revert_type";

    my $tmpfile = make_tempfile($PROGNAME);
    open(RS, ">", $tmpfile);
    print(RS "perl $revert_cmd\n");
    close(RS);

    # try to schedule the at job, but if it fails, then
    # better revert now
    system("at -f $tmpfile now + $revert_delay minutes");
    if ($? != 0) {
	system("perl $revert_cmd");
	showinfo("Change reverted because at job could not be scheduled");
	$retval = 1;
    }

    system("rm -f $tmpfile");

    return($retval);
}


#
# Setup System services
# PCI-DSS 2.2.1
# PCI-DSS 2.2.2
#
sub setup_system_services
{
    my @whitelist = ();

    # Comprehensive list of system Services.
    my @system_services = qw(
	acpid
	apcupsd
	anacron
	atd
	blm
	bbj
	auditd
	cpuspeed
	crond
	cups
	cups-config-daemon
	daisy
	dgap
	dgrp_daemon
	dgrp_ditty
	dsm_sa_ipmi
	firstboot
	httpd
	instsvcdrv
	ipmi
	iptables
	irqbalance
	kagent-TLFRLC38702197701560
	kagent-TLFRLC81288907470344
	lm_sensors
	lpd
	lvm2-monitor
	mdmonitor
	mdmpd
	messagebus
	microcode_ctl
	multipathd
	network
	ntpd
	readahead_early
	readahead_later
	restorecond
	rhnsd
	rsyslog
	rti
	sendmail
	smartd
	smb
	sshd
	syslog
	sysstat
	systememail
	tfremote
	yum
	yum-updatesd
	zeedaisy
	PBEAgent
    );

    foreach my $servicename (@system_services) {
	    next unless (-f "/etc/init.d/$servicename");
	    next if ( ($servicename eq 'rsyslog') && ($OS ne 'RHEL6') );
	    next if ( ($servicename eq 'syslog') && ($OS eq 'RHEL6') );
	    next if ( ($servicename eq 'cups-config-daemon') && ($OS eq 'RHEL5') );
	    next if ( ($servicename eq 'ipmi') && (! -e '/dev/ipmi0') );
	    push(@whitelist, $servicename);
    }

    showinfo("Hardening System Services...");

    # As a rule of thumb, if we don't know what it is, then, turn it off.
    if (open(my $pipe, '-|', "/sbin/chkconfig --list | grep 3:on")) {
	while (<$pipe>) {
	    my @service_names = split(/\s+/);
	    my $servicename = $service_names[0];
	    next if (grep {/^($servicename)$/} @whitelist);

	    if (-f "/etc/init.d/$servicename") {
		loginfo("Disabling System Service $servicename");
		system("/sbin/chkconfig $servicename off");
		# Stopping netfs will unmount loopback filesystems (ie, our install media)
		next if ($servicename eq "netfs");
		system("/sbin/service $servicename stop");
	    }
	}
	close($pipe);
    }

    # Start whitelisted services if not already started.
    foreach my $servicename (@whitelist) {
	next if ($servicename eq "iptables");
	next if ($servicename eq "bbj");
	next if ($servicename eq "blm");
	next if ($servicename eq "rti");

	# guess what?  If a "chkconfig on" is done on zeedaisy
	# on RHEL6, the default action is to make it "on" for
	# runlevels "234" and we need it to stay at "23"...
	# so skip it here.
	next if ($servicename eq "zeedaisy");

	loginfo("Enabling System Service $servicename");
	system("/sbin/chkconfig $servicename on");

	# skip "daisy" at this point since it is not going to
	# report "running".
	next if ($servicename eq "daisy");

	my $service_status = sys_service_status($servicename);
	next if ($service_status eq "running");

	loginfo("Starting System Service $servicename");
	system("/sbin/service $servicename start");
    }

    return(1);
}


sub sys_service_status
{
    my ($servicename) = @_;
    my $retval = "";
    my $running_re = ' is running\.\.\.';

    if (open(my $pipe, '-|', "/sbin/service $servicename status")) {
	while (<$pipe>) {
	    chomp;
	    if (/$running_re/) {
		$retval = "running";
		last;
	    }
	}
	close($pipe);
    }

    return($retval);
}


#
# configure RHEL7 system services.
#
# returns
#   x if success
#   y on error
#
sub configure_system_services
{
    my @service_white_list = qw(
	abrt-ccpp.service
	abrt-oops.service
	abrt-vmcore.service
	abrt-xorg.service
	abrtd.service
	apcupsd.service
	atd.service
	auditd.service
	crond.service
	cups.service
	dbus-org.freedesktop.network1.service
	dbus-org.freedesktop.NetworkManager.service
	dbus-org.freedesktop.nm-dispatcher.service
	dmraid-activation.service
	getty@.service
	getty@tty1.service
	getty@tty2.service
	getty@tty3.service
	getty@tty4.service
	getty@tty5.service
	getty@tty6.service
	getty@tty7.service
	getty@tty8.service
	getty@tty9.service
	getty@tty11.service
	httpd.service
	iptables.service
	irqbalance.service
	kdump.service
	libstoragemgmt.service
	lvm2-monitor.service
	mdmonitor.service
	microcode.service
	NetworkManager-dispatcher.service
	NetworkManager.service
	ntpd.service
	sshd.service
	rhsmcertd.service
	rngd.service
	rsyslog.service
	sendmail.service
	sm-client.service
	smartd.service
	smb.service       
	sshd.service
	sysstat.service
	systemd-readahead-collect.service
	systemd-readahead-drop.service
	systemd-readahead-replay.service 
	tfremote.service
	tuned.service
    );

    my $sys_ctl_cmd = '/usr/bin/systemctl';

    # As a rule of thumb, if we don't know what it is, then, turn it off.
    if (open(my $pipe, '-|', "$sys_ctl_cmd --no-legend --no-pager list-unit-files")) {
	while (my $line=<$pipe>) {
	    chomp($line);
	    my ($service_name, $service_status) = split(/\s+/, $line);
	    next if ( (-d $DAISYDIR) && ($service_name eq 'httpd.service') );
	    next unless ($service_name =~ /.+\.service/);
	    next if ( ($service_status eq 'static') || ($service_status eq 'disabled') );

	    # at this point, we have names of only enabled system services.
	    # if service is on the white list, it's ok
	    next if (grep {/^($service_name)$/} @service_white_list);

	    # at this point, we found an enabled system service NOT on white list,
	    # so stop it and disable it.
	    if ($WHITELIST_ENFORCE) {
		system("$sys_ctl_cmd stop $service_name");
		system("$sys_ctl_cmd disable $service_name");
		loginfo("[configure services] service stopped and disabled: $service_name");
	    }
	    else {
		showinfo("[configure services] execution disabled: $sys_ctl_cmd stop $service_name");
		showinfo("[configure services] execution disabled: $sys_ctl_cmd disable $service_name");
	    }
	}
	close($pipe);
    }
    else {
	showerror("[configure services] could not get list of system services");
	return(0);
    }

    # enable and start whitelisted services if not already enabled and started.
    foreach my $service_name (@service_white_list) {
	next if ($service_name eq 'bbj');
	next if ($service_name eq 'blm');
	next if ($service_name eq 'rti');
	next if ( (-d $DAISYDIR) && ($service_name eq 'httpd.service') );

	system("$sys_ctl_cmd -q is-enabled $service_name");
	if ($? != 0) {
	    if ($WHITELIST_ENFORCE) {
		system("$sys_ctl_cmd -q enable $service_name");
		loginfo("[configure services] system service enabled: $service_name");
	    }
	    else {
		showinfo("[configure services] execution disabled: $sys_ctl_cmd -q enable $service_name");
	    }
	}
	system("$sys_ctl_cmd -q is-active $service_name");
	if ($? != 0) {
	    if ($WHITELIST_ENFORCE) {
		system("$sys_ctl_cmd start $service_name");
		loginfo("[configure services] system service started: $service_name");
	    }
	    else {
		showinfo("[configure services] execution disabled: $sys_ctl_cmd start $service_name");
	    }
	}

    }

    return(1);
}


sub modify_bastille
{

    showinfo("[mod bastille] mods per the Bastille Linux Report no longer performed");

    return(1);
}


#
# Now that the system is configured to refer to password history,
# make sure there is a password history file.
#
sub pam_verify_passwd_history_file
{
    my $passwd_history_file = '/etc/security/opasswd';

    unless (-e $passwd_history_file) {
	my $echo_cmd = ($TestPam) ? "echo " : "";
	system("${echo_cmd}touch $passwd_history_file");
	system("${echo_cmd}chown root:root $passwd_history_file");
	system("${echo_cmd}chmod 600 $passwd_history_file");
    }

    return(1);
}


#
# The PAM tally rules depend on existence of "pam_tally2".
#
sub pam_system_auth_tally_rules
{
    my @tally_rules = ();

    # Updated RHEL5, RHEL6, RHEL7
    # Note the added "unlock_time" functionality in pam_tally2.
    if (-f '/sbin/pam_tally2') {
	push(@tally_rules, 'pam_tally2.so');
	push(@tally_rules, 'pam_tally2.so onerr=fail deny=6 unlock_time=1800');
    }

    return(@tally_rules);
}


sub pam_system_auth_generate
{
    my ($pam_tally, $pam_tally_rule) = pam_system_auth_tally_rules();

    my $system_auth = qq{#\%PAM-1.0
# This file installed by harden_linux.pl $CVS_REVISION for \"$OS\"
#
auth        required      pam_env.so
auth        required      $pam_tally_rule
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 500 quiet
auth        required      pam_warn.so
auth        required      pam_deny.so

account     required      $pam_tally
account     required      pam_unix.so
account     sufficient    pam_succeed_if.so uid < 500 quiet
account     required      pam_permit.so

password    required      pam_warn.so
password    requisite     pam_cracklib.so retry=2 minlen=7 lcredit=-1 ucredit=-1 dcredit=-1
password    sufficient    pam_unix.so sha512 shadow nullok use_authtok remember=4
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
session     [success=2 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
session     required      pam_warn.so
};

    return($system_auth);
}


sub pam_system_auth_add_symlinks
{
    my ($conf_dir, $new_conf_file) = @_;

    #
    # Need to be in /etc/pam.d for the symlinks to be right.
    #
    my $saved_cwd = getcwd;

    chdir $conf_dir;

    my $conf_file_basename = basename($new_conf_file);

    my $ln_cmd = ($TestPam) ? "echo ln" : "ln";

    system("$ln_cmd -sf $conf_file_basename system-auth");

    # Have to also do this symlink for RHEL6 and RHEL7 since "/etc/pam.d/sshd"
    # includes "/etc/pam.d/password-auth" - this changed from RHEL5 to
    # RHEL6.
    if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	system("$ln_cmd -sf $conf_file_basename password-auth");
    }

    chdir $saved_cwd;

    return(1);
}


#
# For RHEL5, RHEL6, and RHEL7 generate a new system-auth file, and
# change the "/etc/pam.d/system-auth" symlink to point to it.
#
# For RHEL6 and RHEL7, also change the "/etc/pam.d/password-auth"
# symlink to point to it so that sshd logins are counted correctly.
#
sub pam_system_auth_modify
{
    my $conf_dir = '/etc/pam.d';
    my $conf_file = File::Spec->catdir($conf_dir, 'system-auth-ac');
    my $new_conf_file = File::Spec->catdir($conf_dir, 'system-auth-teleflora');
    my $system_auth_contents = pam_system_auth_generate();

    my $rc = 1;

    if (open(my $nfh, '>', $new_conf_file)) {
	print {$nfh} $system_auth_contents;
	close($nfh);
	loginfo("[pam] new system auth file generated: $new_conf_file");

	if (-s $new_conf_file) {
	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");

	    if (pam_system_auth_add_symlinks($conf_dir, $new_conf_file)) {
		loginfo("[pam] new system auth file linked: $new_conf_file");
	    }
	    else {
		showerror("[pam] could not link new system auth file: $new_conf_file");
		$rc = 0;
	    }
	}
	else {
	    if (-e $new_conf_file) {
		showerror("[pam] new system auth file exists but is zero length: $new_conf_file");
		system("rm $new_conf_file");
	    }
	    else {
		showerror("[pam] new system auth file does not exist: $new_conf_file");
	    }
	    $rc = 0;
	}
    }
    else {
	showerror("[pam] could not open new conf file for write: $new_conf_file");
	$rc = 0;
    }

    return($rc);
}


sub pam_modifiy_security_limits_morph
{
    my ($old_fh, $new_fh) = @_;

    my $rc = 1;
    
    while(<$old_fh>) {
	next if (/^(\s*)(\%rtiadmins)/);
	next if (/^(\s*)(\%dsyadmins)/);
	next if (/^(\s*)(root)/);
	next if (/^(\s*)(tfsupport)/);
	print {$new_fh} $_;
    }
    # this is what should be written
    #print {$new_fh} "\%rtiadmins\t-\tmaxlogins\t1\n";
    #print {$new_fh} "\%dsyadmins\t-\tmaxlogins\t1\n";

    # this is what we really write
    print {$new_fh} "root            -        maxlogins       10\n";
    print {$new_fh} "tfsupport       -        maxlogins       10\n";

    return($rc);
}


#
# Enforce that users in the "rtiadmins" and "dsyadmins" group may only have 1
# simultaneious login at a time.
#
# Yes, this also applies to the 'tfsupport' user as well.
#
# PABP 3.1 /  PCI 8.5.8
#
# NOTE: code does not enforce this yet.
#
sub pam_modify_security_limits
{
    my $conf_file = '/etc/security/limits.conf';

    my $rc = 1;

    # the code depends on the existence of the limits file so
    # make sure there is something there.
    unless (-e $conf_file) {
	loginfo("[pam] making missing security limits conf file: $conf_file");
	system("touch $conf_file");
	system("chown root:root $conf_file");
	system("chmod 644 $conf_file");
    }

    my $timestamp = strftime("%Y%m%d_%H%M%S", localtime());
    my $new_conf_file = $conf_file . '_' . $timestamp;

    if (open(my $old_fh, '<', $conf_file)) {
	if (open(my $new_fh, '>', $new_conf_file)) {

	    pam_modifiy_security_limits_morph($old_fh, $new_fh);

	    close($new_fh);

	}
	else {
	    showerror("[pam] could not open new conf file for write: $new_conf_file");
	    $rc = 0;
	}

	close($old_fh);

	# now that both conf files are closed,
	# move new conf file to old conf file and
	# set owner/group/perms
	if ($rc) {
	    if (pam_modify_util_rename($conf_file, $new_conf_file)) {
		loginfo("[pam] conf file modified: $conf_file");
	    }
	    else {
		showerror("[pam] could not modify conf file: $conf_file");
		$rc = 0;
	    }
	}
    }
    else {
	showerror("[pam] could not open conf file for read: $conf_file");
	$rc = 0;
    }

    return($rc);
}


#
# Modifications to ensure PCI 8.5.x
#
# PCI 8.5
#	Ensure proper user authenticaion and password management for
#	non-consumer users and administrators on all system components
#	as follows:
#	8.5.1
#		Control addition, deletion, and modification of user IDs,
#		credentials, and other identifier objects.
#	8.5.10
#		Require a minimum password length of at least 7 chars.
#	8.5.11
#		Use passwords containing both numeric and alpha chars.
#	8.5.12
#		Do not allow an individual to submit a new password that is
#		the same as any of the last four passwords used.
#
#
# PCI 8.5.13
#	Limit repeated access attempts by locking out the user ID
#	after not more than 6 attempts.
#
# PCI 8.5.14
#	Set the lockout duration to a minimum of 30 minutes or until
#	administrator enables the user ID.
#
# http://searchenterrpiselinux.techtarget.com/tip/0,289483,sid39_gci1213570,00.html
# Setup s.t. faillog is being used on a per-user basis.
#

sub pam_modify_rules
{
    pam_modify_security_limits();

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	pam_system_auth_modify();
    }

    if (pam_verify_passwd_history_file()) {
	loginfo("[pam] password history file verified");
    }

    return(1);
}


sub pam_modify_util_rename
{
    my ($conf_file, $new_conf_file) = @_;

    my $rc = 1;

    # if new conf file exists and is non-zero length, then success
    if (-s $new_conf_file) {
	system("chmod --reference=$conf_file $new_conf_file");
	system("chown --reference=$conf_file $new_conf_file");
	my $mv_cmd = ($TestPam) ? "echo mv" : "mv";
	system("$mv_cmd $new_conf_file $conf_file");
	if ($? != 0) {
	    showerror("[pam] could not mv conf file to new name: $new_conf_file");
	    system("rm $new_conf_file");
	    $rc = 0;
	}
    }
    else {
	if (-e $new_conf_file) {
	    showerror("[pam] new conf file exists but is zero length: $new_conf_file");
	    system("rm $new_conf_file");
	}
	else {
	    showerror("[pam] new conf file does not exist: $new_conf_file");
	}
	$rc = 0;
    }

    return($rc);
}


sub pam_modify_pamsu_morph
{
    my ($old_fh, $new_fh) = @_;

    my $rc = 1;

    # default value for RHEL5, RHEL6, and RHEL7
    my $pam_dir = "";

    #
    # Add a line that prevents the 'su' program from working when run
    # on any tty other than what appears in the secure tty white list.
    #
    while (<$old_fh>) {
	# add a line
	if (/^auth.*sufficient.*pam_rootok.so.*/) {
	    print {$new_fh} $_;
	    print {$new_fh} "auth\t\trequired\t${pam_dir}pam_securetty.so\n";
	    next;
	}
	# default is to just copy what is read
	else {
	    print {$new_fh} $_;
	}
    }

    return($rc);
}


#
# Modify pam file for 'su' so that an "su -" will only work if entered
# on one of the white listed tty lines or virtual consoles.
# Basically, disallow access to the "root" account unless you are physically at the box.
# PCI-DSS 8.3
# 
sub pam_modify_pamsu
{
    my $conf_file = '/etc/pam.d/su';

    my $rc = 1;

    unless (-s $conf_file) {
	loginfo("[pam] conf file does not exist: $conf_file");
	return($rc);
    }

    system("grep pam_securetty.so $conf_file > /dev/null 2> /dev/null");
    if ($? == 0) {
	loginfo("[pam] conf file previously changed: $conf_file");
	return($rc);
    }

    my $timestamp = strftime("%Y%m%d_%H%M%S", localtime());
    my $new_conf_file = $conf_file . '_' . $timestamp;

    if (open(my $old_fh, '<', $conf_file)) {
	if (open(my $new_fh, '>', $new_conf_file)) {

	    pam_modify_pamsu_morph($old_fh, $new_fh);

	    close($new_fh);
	}
	else {
	    showerror("[pam] could not open new conf file for write: $new_conf_file");
	    $rc = 0;
	}

	close($old_fh);

	# now that both conf files are closed,
	# move new conf file to old conf file and
	# set owner/group/perms
	if ($rc) {
	    if (pam_modify_util_rename($conf_file, $new_conf_file)) {
		loginfo("[pam] conf file modified: $conf_file");
	    }
	    else {
		showerror("[pam] could not modify conf file: $conf_file");
		$rc = 0;
	    }
	}
    }
    else {
	showerror("[pam] could not open conf file for read: $conf_file");
	$rc = 0;
    }

    return($rc);
}


sub pam_modify_securetty_morph
{
    my ($old_fh, $new_fh) = @_;

    my $rc = 1;

    while (<$old_fh>) {
	# copy all lines
	print {$new_fh} $_;
    }

    # actually modify the file
    print {$new_fh} "tty12\n";

    return($rc);
}


#
# Modify /etc/securetty so that tty12 will allow root logins
# PCI-DSS 8.3
#
sub pam_modify_securetty
{
    my $conf_file = '/etc/securetty';

    my $rc = 1;

    unless (-s $conf_file) {
	loginfo("[pam] conf file does not exist: $conf_file");
	return($rc);
    }

    system("grep tty12 $conf_file > /dev/null 2> /dev/null");
    if ($? == 0) {
	loginfo("[pam] conf file previously changed: $conf_file");
	return($rc);
    }

    my $timestamp = strftime("%Y%m%d_%H%M%S", localtime());
    my $new_conf_file = $conf_file . '_' . $timestamp;

    if (open(my $old_fh, '<', $conf_file)) {
	if (open(my $new_fh, '>', $new_conf_file)) {

	    pam_modify_securetty_morph($old_fh, $new_fh);

	    close($new_fh);

	}
	else {
	    showerror("[pam] could not open new conf file for write: $new_conf_file");
	    $rc = 0;
	}

	close($old_fh);

	# now that both conf files are closed,
	# move new conf file to old conf file and
	# set owner/group/perms
	if ($rc) {
	    if (pam_modify_util_rename($conf_file, $new_conf_file)) {
		loginfo("[pam] conf file modified: $conf_file");
	    }
	    else {
		showerror("[pam] could not modify conf file: $conf_file");
		$rc = 0;
	    }
	}
    }
    else {
	showerror("[pam] could not open conf file for read: $conf_file");
	$rc = 0;
    }

    return($rc);
}


sub logrotate_rewrite_conf
{
    my ($oldfh, $newfh, $conf_file) = @_;

    my $rc = 1;

    while (<$oldfh>) {

	if ($conf_file =~ /logrotate.conf/) {
	    my $stanza_copied = 0;

	    #
	    # looking for start of btmp or wtmp stanza
	    #
	    if (/^\/var\/log\/btmp \{/ || /^\/var\/log\/wtmp \{/) {
		print {$newfh} $_;
		print {$newfh} "    monthly\n";
		print {$newfh} "    rotate 12\n";

		# copy rest of stanza minus replaced lines
		while (<$oldfh>) {
		    # break out at end of stanza
		    if (/^\}/) {
			print {$newfh} $_;
			$stanza_copied = 1;
			last;
		    }

		    next if (/^(\s+)monthly$/);
		    next if (/^(\s+)rotate/);

		    print {$newfh} $_;
		}
	    }

	    next if ($stanza_copied);

	    # By default, just copy what we read.
	    print {$newfh} $_;
	}

	else {
	    #
	    # looking for start of stanza in package conf file:
	    # either a '{' at the end of line, or beginning of line
	    #
	    if (/^.* \{/ || /^\s*\{/) {
		print {$newfh} $_;
		print {$newfh} "    monthly\n";
		print {$newfh} "    rotate 12\n";
		next;
	    }

	    next if (/^(\s+)monthly$/);
	    next if (/^(\s+)rotate 12$/);

	    # By default, just copy what we read.
	    print {$newfh} $_;
	}
    }

    return($rc);
}


sub logrotate_edit_conf
{
    my ($conf_file) = @_;

    my $rc = 0;

    my $timestamp = strftime("%Y-%m-%d_%H%M%S", localtime());
    my $new_conf_file = $conf_file . '-' . $timestamp;

    if (open(my $oldfh, '<', $conf_file)) {
	if (open(my $newfh, '>', $new_conf_file)) {
	    if (logrotate_rewrite_conf($oldfh, $newfh, $conf_file)) {
		$rc = 1;
	    }
	    close($newfh);
	}
	else {
	    showerror("[edit logrotate] could not open new conf file for write: $new_conf_file");
	}
	close($oldfh);
    }
    else {
	showerror("[edit logrotate] could not open conf file for read: $conf_file");
    }

    if ($rc) {
	# If new conf file exists and is non-zero sized, AOK.
	if (-s $new_conf_file) {
	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");
	    system("mv $new_conf_file $conf_file");
	}
	else {
	    showerror("[edit logrotate] could not make new conf file: $new_conf_file");
	    if (-e $new_conf_file) {
		system("rm $new_conf_file");
	    }
	}
    }

    return($rc);
}


#
# Modify the top level logfile rotation conf file and several of the
# package specific conf files in /etc/logrotate.d.
#
# To comply wth PCI, the log files should be rotated monthly and
# kept for one year. (PCI-DSS 10.7)
#
sub modify_logrotate
{
    my $rc = 1;

    # logrotate conf files from individual packages
    my @logrotate_conf_files = qw(
	syslog
	httpd
	samba
	logrotate.conf

    );

    foreach my $conf_file (@logrotate_conf_files) {

	# form the full path to a config file
	my $conf_dir = '/etc/logrotate.d';
	if ($conf_file eq 'logrotate.conf') {
	    $conf_dir = '/etc';
	}

	my $conf_file_path = File::Spec->catdir($conf_dir, $conf_file);
	if (-e $conf_file_path) {
	    if (logrotate_edit_conf($conf_file_path)) {
		showinfo("[modify logrotate] configured logrotate conf file: $conf_file_path");
	    }
	    else {
		showinfo("[modify logrotate] could not configure logrotate conf file: $conf_file_path");
		$rc = 0;
	    }
	}
	else {
	    loginfo("[modify logrotate] logrotate conf file does not exist: $conf_file");
	}
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


#
# In the specified logrotate conf file, check for a reference
# to the specified regular expression and if there is one,
# remove it.  The re must be to a path before the first stanza.
#
# For RHEL5 and RHEL6, stanza begins on line AFTER line that ends
# with a CURLY.  For RHEL5, the line that ends with CURLY has a
# list of log file paths on it.  For RHEL6, the log file paths
# are each on a separate line.
#
# Returns
#   1 on success
#   0 on error
#
sub sudo_cleanup_logrotate_conf
{
    my ($conf_file, $re) = @_;
    my $rc = 0;

    my $filtered_contents = "";
    my $stanza_marker_seen = 0;
    if (open(my $fh, '<', $conf_file)) {
	while (<$fh>) {
	    chomp(my $line = $_);
	    # possibly filter the line
	    if (! $stanza_marker_seen) {
		if ($line =~ /$re/) {
		    $line =~ s/$re//;
		}
		# remove leading SPACES
		$line =~ s/^\s+//;
		# convert lines with just SPACEs to empty line
		$line =~ s/^\s+$//;
		# convert 2 SPACEs to one
		$line =~ s/\s\s/ /g;
	    }
	    # look for stanza marker
	    if ($line =~ /^.*{\s*$/) {
		$stanza_marker_seen = 1;
	    }
	    # if not empty line, add to output buffer
	    if (! $line =~ /^$/) {
		$filtered_contents = $filtered_contents . $line . "\n";
	    }
	}
	close($fh);
    }
    else {
	logerror("can't open: $conf_file");
    }

    # if we have some contents for the new conf file
    if (length($filtered_contents)) {
	my $timestamp = strftime("%Y%m%d-%H%M%S", localtime());
	my $new_conf_file = $conf_file . '-' . $timestamp;
	if (open(my $fh, '>', $new_conf_file)) {
	    print {$fh} $filtered_contents;
	    close($fh);
	}
	else {
	    logerror("can't open new logrotate conf file: $new_conf_file");
	}
	# If we created a new conf file that is zero sized, that is bad.
	if (-z $new_conf_file) {
	    logerror("edited version of logrotate conf file is zero size: $new_conf_file");
	    logerror("will skip edits");
	    unlink($new_conf_file);
	}
	else {
	    # Assume conf file was successfully transformed...
	    # so replace the old one with the new.
	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");
	    system("mv $new_conf_file $conf_file");

	    # success
	    $rc = 1;
	}
    }

    return($rc);
}


#
# When generating a new sudoers file, generate a new
# sudo logrotate conf file.
#
# Returns
#   1 for success
#   0 for error
#
sub sudo_gen_sudo_logrotate_conf
{
    my $conf_file = "$ALTROOT/etc/logrotate.d/sudo";

    # first, check for a reference to "sudo" in the "syslog"
    # logrotate conf file and if there is one, remove it.
    my $syslog_logrotate_conf_file = "/etc/logrotate.d/syslog";
    if (-e $syslog_logrotate_conf_file) {
	my $reference = "/var/log/sudo";
	if (fgrep($syslog_logrotate_conf_file, $reference) == 0) {
	    if (sudo_cleanup_logrotate_conf($syslog_logrotate_conf_file, $reference)) {
		loginfo("reference to 'sudo' removed from: $syslog_logrotate_conf_file");
	    }
	    else {
		showerror("could not remove reference to 'sudo' from: $syslog_logrotate_conf_file");

		# since there was a reference to "sudo" within the
		# syslog log rotate conf file, and it could not be
		# removed, we must return since the logrotate code
		# does not allow a separate log rotate file AND a
		# reference within the syslog log rotate file.
		showerror("new sudo logrotate conf file not allowed: $conf_file");
		showerror("manual intervention required");
		return(0);
	    }
	}
	else {
	    loginfo("no reference to 'sudo' within: $syslog_logrotate_conf_file");
	}
    }
    else {
	loginfo("syslog log rotate conf file does not exist: $syslog_logrotate_conf_file");
    }
 
    # now, generate the new sudo logrotate conf file
    unless (open(NEW, ">", $conf_file)) {
	showinfo("Could not open new logrotate conf file for write: $conf_file");
	return(0);
    }

    print(NEW << 'xxxEOFxxx');
/var/log/sudo.log {
    monthly
    rotate 12
    postrotate
        /usr/bin/killall -HUP syslogd
    endscript
}
xxxEOFxxx

    close(NEW);

    # We created a zero size file. That is bad.
    if (-z $conf_file) {
	showinfo("generated new logrotate conf file is zero size: $conf_file");
	system("rm $conf_file");
	return(0);
    }

    system("chmod 0644 $conf_file");
    system("chown root:root $conf_file");

    showinfo("new logrotate conf file generated: $conf_file");

    return(1);
}


#
# Note here that order of the sudoers rules matters.
#
# Generate a new sudoers file
#
# PCI-DSS 7.x
# PCI-DSS 10.x
#
sub modify_sudoers
{
	my $returnval = -5;
	my $admingroup = "";
	my $timestamp = strftime("%Y-%m-%d_%H%M%S", localtime());
	my $sudoers = "$ALTROOT/etc/sudoers";


	if (-z "$sudoers") {
		showinfo("$sudoers does not exist error...  Will skip sudoers edits.");
		return(0);
	}

	$returnval = open(OLD, "< $sudoers");
	if (! $returnval) {
		showinfo("Could not open $sudoers for read. Will skip sudoers edits.");
		return(0);
	}
	$returnval = open(NEW, "> $sudoers.$$");
	if (! $returnval) {
		showinfo("Could not open $sudoers.$$ for write. Will skip sudoers edits.");
		close(OLD);
		return(0);
	}

	print(NEW "# The /etc/sudoers file.\n");
	print(NEW "# Generated by harden_linux.pl $CVS_REVISION $timestamp\n");
	print(NEW "# Do not hand-edit.\n");

	print(NEW << 'xxxEOFxxx');
# Users and Admins
root	ALL=(ALL) ALL
tfsupport ALL=(ALL) ALL
%dsyadmins ALL=(ALL) ALL
%rtiadmins ALL=(ALL) ALL
User_Alias ADMINS = %dsyadmins, %rtiadmins, tfsupport

# Logging and password attempts
Defaults:tfsupport passwd_timeout=5, passwd_tries=3
Defaults logfile=/var/log/sudo.log

# POS Administrative Users
ADMINS ALL=NOPASSWD: /bin/hostname
ADMINS ALL=NOPASSWD: /bin/ls
ADMINS ALL=NOPASSWD: /bin/netstat
ADMINS ALL=NOPASSWD: /bin/stty
ADMINS ALL=NOPASSWD: /bin/true
ADMINS ALL=NOPASSWD: /bin/zcat
ADMINS ALL=NOPASSWD: /usr/bin/cancel
ADMINS ALL=NOPASSWD: /usr/bin/chage
ADMINS ALL=NOPASSWD: /usr/bin/enable
ADMINS ALL=NOPASSWD: /usr/bin/faillog
ADMINS ALL=NOPASSWD: /usr/bin/find
ADMINS ALL=NOPASSWD: /usr/bin/kill
ADMINS ALL=NOPASSWD: /usr/bin/pkill
ADMINS ALL=NOPASSWD: /usr/bin/lpstat
ADMINS ALL=NOPASSWD: /usr/bin/lpr
ADMINS ALL=NOPASSWD: /usr/bin/lpc
ADMINS ALL=NOPASSWD: /usr/bin/lpq
ADMINS ALL=NOPASSWD: /usr/bin/lprm
ADMINS ALL=NOPASSWD: /usr/bin/mpi
ADMINS ALL=NOPASSWD: /usr/bin/mdir
ADMINS ALL=NOPASSWD: /usr/bin/nmap
ADMINS ALL=NOPASSWD: /usr/bin/shred
ADMINS ALL=NOPASSWD: /usr/bin/tac
ADMINS ALL=NOPASSWD: /usr/bin/tail
ADMINS ALL=NOPASSWD: /usr/bin/top
ADMINS ALL=NOPASSWD: /usr/bin/write
ADMINS ALL=NOPASSWD: /usr/bin/yum
ADMINS ALL=NOPASSWD: /usr/bin/systemctl
ADMINS ALL=NOPASSWD: /etc/dgap/dpa
ADMINS ALL=NOPASSWD: /etc/dgap/dgapview
ADMINS ALL=NOPASSWD: /usr/lone-tar/ltmenu
ADMINS ALL=NOPASSWD: /sbin/apcaccess
ADMINS ALL=NOPASSWD: /sbin/ethtool
ADMINS ALL=NOPASSWD: /sbin/fuser
ADMINS ALL=NOPASSWD: /sbin/lsusb
ADMINS ALL=NOPASSWD: /sbin/pam_tally2
ADMINS ALL=NOPASSWD: /sbin/reboot
ADMINS ALL=NOPASSWD: /sbin/service
ADMINS ALL=NOPASSWD: /sbin/shutdown
ADMINS ALL=NOPASSWD: /usr/sbin/accept
ADMINS ALL=NOPASSWD: /usr/sbin/dmidecode
ADMINS ALL=NOPASSWD: /usr/sbin/cupsenable
ADMINS ALL=NOPASSWD: /usr/sbin/cupsdisable
ADMINS ALL=NOPASSWD: /usr/sbin/eject
ADMINS ALL=NOPASSWD: /usr/sbin/lpmove
ADMINS ALL=NOPASSWD: /usr/sbin/sosreport
ADMINS ALL=NOPASSWD: /usr/sbin/system-config-network
ADMINS ALL=NOPASSWD: /usr/sbin/system-config-printer
ADMINS ALL=NOPASSWD: /usr/sbin/up2date

# OSTools
ADMINS ALL=NOPASSWD: /d/ostools/bin/rtibackup.pl
ADMINS ALL=NOPASSWD: /d/daisy/bin/rtibackup.pl
ADMINS ALL=NOPASSWD: /usr2/ostools/bin/rtibackup.pl
ADMINS ALL=NOPASSWD: /usr2/bbx/bin/rtibackup.pl

ADMINS ALL=NOPASSWD: /d/ostools/bin/updateos.pl
ADMINS ALL=NOPASSWD: /d/daisy/bin/updateos.pl
ADMINS ALL=NOPASSWD: /usr2/ostools/bin/updateos.pl
ADMINS ALL=NOPASSWD: /usr2/bbx/bin/updateos.pl

ADMINS ALL=NOPASSWD: /d/ostools/bin/tfprinter.pl
ADMINS ALL=NOPASSWD: /d/daisy/bin/tfprinter.pl
ADMINS ALL=NOPASSWD: /usr2/ostools/bin/tfprinter.pl
ADMINS ALL=NOPASSWD: /usr2/bbx/bin/tfprinter.pl

# RTI Specific
%rti ALL=NOPASSWD: /usr/bin/enable
%rti ALL=NOPASSWD: /usr/sbin/cupsenable
%rti ALL=NOPASSWD: /usr2/bbx/bin/checkbackup.pl
%rti ALL=NOPASSWD: /usr2/bbx/bin/key_lock
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/applypatch.pl
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/bbjservice.pl
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/checkbackup.pl
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/killterms.pl
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/doveserver.pl
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/rtidevice.pl
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/rtiuser.pl
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/updateos.pl
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/watchrti.pl
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/rti
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/killem
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/startbbx
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/sshbbx
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/checkit
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/dosdir
%rtiadmins ALL=NOPASSWD: /usr2/bbx/bin/rti_mtools_wrapper
%rtiadmins ALL=NOPASSWD: /usr2/basis/pro5/mkrecover/mrebuild

# Daisy Specific
%dsyadmins ALL=NOPASSWD: /d/daisy/utils/docd_update
%dsyadmins ALL=NOPASSWD: /d/daisy/utils/killemall
%dsyadmins ALL=NOPASSWD: /d/daisy/bin/killemall.pl
%dsyadmins ALL=NOPASSWD: /d/daisy/utils/mount.sh
%dsyadmins ALL=NOPASSWD: /d/daisy/bin/tfupdate.pl
%dsyadmins ALL=NOPASSWD: /d/daisy/utils/umount.sh
%dsyadmins ALL=NOPASSWD: /d/daisy/bin/doaccessadm.pl
%dsyadmins ALL=NOPASSWD: /d/daisy/bin/purgecc.pl
%dsyadmins ALL=NOPASSWD: /d/daisy/bin/doccpurge.pl
%dsyadmins ALL=NOPASSWD: /d/daisy/bin/dokeyrotate.pl
%dsyadmins ALL=NOPASSWD: /d/daisy/bin/doprinterconfig.pl
%dsyadmins ALL=NOPASSWD: /d/daisy/bin/doverifybu.pl
%dsyadmins ALL=NOPASSWD: /d/daisy/bin/dsyuser.pl
%dsyadmins ALL=NOPASSWD: /d/daisy/bin/dsyperms.pl
%dsyadmins ALL=NOPASSWD: /d/daisy/qrest

xxxEOFxxx

	# change in RHEL7: now requires sudo for smbstatus
	if ($OS eq 'RHEL7') {
	    print(NEW "# RHEL7 Specific\n");
	    print(NEW "ADMINS ALL=NOPASSWD: /usr/bin/smbstatus\n");
	    print(NEW "\n");
	}

	# Deny admins the capability of obtaining a "raw shell."
	# As per RTI 12.7 PA-DSS audit.
	print(NEW "# Deny (easy) access to a raw shell.\n");

	if (open(SHELLS, "<", "/etc/shells")) {
	    while (<SHELLS>) {
		    chomp;
		    print(NEW "ADMINS ALL=PASSWD: !$_\n");
	    }
	    close(SHELLS);
	}
	else {
	    showinfo("Can't open /etc/shells");
	    showinfo("Warning - admins might be able to exec a raw shell");

	    # some minimal protection
	    print(NEW "ADMINS ALL=PASSWD: !/bin/sh\n");
	    print(NEW "ADMINS ALL=PASSWD: !/bin/bash\n");
	    print(NEW "ADMINS ALL=PASSWD: !/bin/csh\n");
	    print(NEW "ADMINS ALL=PASSWD: !/bin/tcsh\n");
	    print(NEW "ADMINS ALL=PASSWD: !/bin/ksh\n");
	}

	# catchall misc stuff to not allow
	print(NEW "ADMINS ALL=PASSWD: !/bin/su\n");
	print(NEW "ADMINS ALL=PASSWD: !/sbin/sulogin\n");
	print(NEW "ADMINS ALL=PASSWD: !/usr/bin/screen\n");
	
	# Finally, append any site dependent entries
	if ($SUDOERS_APPEND ne "") {

	    showinfo("Appending site dependent sudoers content from: $CONFIGFILE_PATH");

	    print(NEW "\n");
	    print(NEW "# Begin site dependent sudoers specifications\n");

	    print(NEW "$SUDOERS_APPEND");

	    print(NEW "# End site dependent sudoers specifications\n");
	}

	# Close matches open
	close(NEW);


	# We created a zero size file. That is bad.
	if (-z "$sudoers.$$") {
		showinfo("Copy of '$sudoers.$$' is a zero size file. Will skip sudoers edits.");
		system("rm $sudoers.$$");
		return(0);
	}

	# Are there any syntax errors?
	system("/usr/sbin/visudo -c -f $sudoers.$$ > /dev/null 2> /dev/null");
	if ($? != 0) {
		showinfo("Newly created $sudoers has syntax errors. Will skip sudoers edits.");
		system("rm $sudoers.$$");
		return(0);
	}

	# File was successfully transformed... so replace the old one with the new.
	system("mv $sudoers.$$ $sudoers");
	system("chown root:root $sudoers");
	system("chmod 0440 $sudoers");

	showinfo("new sudoers file generated: $sudoers");

	# generate a new "sudo" logrotate conf file
	if (sudo_gen_sudo_logrotate_conf() == 0) {
	    return(0);
	}

	return(1);
}


#
# Modify syslog to now log "kernel debug" messages, which is where the
# logged iptables messages will show up.
#
sub hl_iptables_modify_syslog
{
    my ($conf_file) = @_;

    my $rc = 1;

    my $timestamp = strftime("%Y%m%d_%H%M%S", localtime());
    my $new_conf_file = $conf_file . '_' . $timestamp;

    if (open(my $old_fh, '<', $conf_file)) {
	if (open(my $new_fh, '>', $new_conf_file)) {
	    while(<$old_fh>) {
		next if(/kern\.debug/);
		print {$new_fh} $_;
	    }

	    print {$new_fh} "kern.debug\t\t\t/var/log/secure\n";

	    close($new_fh);
	}
	else {
	    showerror("[iptables] could not open new conf file for write: $new_conf_file");
	    $rc = 0;
	}

	close($old_fh);

	# if new conf file is zero sized, that is bad.
	if (-z $new_conf_file) {
	    showerror("[iptables] generated zero length conf file: $new_conf_file");
	    system("rm $new_conf_file");
	    $rc = 0;
	}
	else {
	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");
	    system("mv $new_conf_file $conf_file");
	    if ($? != 0) {
		showerror("[iptables] could not mv conf file to new name: $new_conf_file");
		system("rm $new_conf_file");
		$rc = 0;
	    }
	}
    }
    else {
	showerror("[iptables] could not open conf file for read: $conf_file");
	$rc = 0;
    }

    return($rc);
}


# 
# Setup iptables and tcpwrappers rules.
# PCI-DSS 1.1.5
# PCI-DSS 1.2.x
#
# Return
#   1 if no errors else 0
# 
sub hl_harden_iptables
{
	my ($iptables_ports) = @_;

	my $fwcmd = "/sbin/iptables";


	showinfo("Setup IPTables ...");

	#
	# If the iptables package is not installed, then nothing to do.
	#
	if (! -x $fwcmd) {
		showinfo("The iptables package is not installed ($fwcmd not found).");
		showinfo("Host firewall will not be configured.");
		return(0);
	}

	#
	# Determine what type of network the system is on:
	#
	my $ipaddr = get_host_ipaddr();
	if ($ipaddr eq "") {
	    showinfo("Can not determine ip address of host");
	    showinfo("Host firewall will not be configured.");
	    return(0);
	}

	my $network_addr = "";
	if ($ipaddr =~ /^192\.168\./) {
	    $network_addr = "192.168.0.0/16";
	}
	elsif ($ipaddr =~ /^172\.[16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31]/) {
	    $network_addr = "172.16.0.0/12";
	}
	elsif ($ipaddr =~ /^10\./) {
	    $network_addr = "10.0.0.0/8";
	}
	else {
	    showinfo("The hostname ip addr is: $ipaddr");
	    showinfo("Expecting network address: 10.0.0.0/8, 172.16.0.0/12, or 192.168.0.0/24");
	    showinfo("Host firewall will not be configured.");
	    return(0);
	}

	#
	# This is a list of allowed inbound ports.  It may be augmented
	# by values from the command line.  If there are any errors in
	# the values from command line, do not configure iptables.
	#
	my @inbound_ports = qw(
	    80
	    443
	    2000
	    2001
	    2002
	    2003
	    2004
	    2005
	    2006
	    2007
	    2008
	    2009
	    2100
	    2103
	    2552
	    4000
	    4003
	    8443
	    8888
	    11057
	);

	my $port_nr_min = 0;
	my $port_nr_max = 65535;
	my $port_nr_format_err = 0;
	foreach my $port_nr (split(/,/, $iptables_ports)) {
	    if ($port_nr =~ /^\d+$/) {
		if ($port_nr >= $port_nr_min && $port_nr <= $port_nr_max) {
		    push(@inbound_ports, $port_nr);
		}
		else {
		    showinfo("Port number oob: $port_nr (min=$port_nr_min, max=$port_nr)");
		    $port_nr_format_err = 1;
		}
	    }
	    else {
		showinfo("Port number format invalid: $port_nr");
		$port_nr_format_err = 1;
	    }
	}
	return(0) if ($port_nr_format_err);

	#
	# Allow network traffic, but log it.
	# http://www.sans.org/reading_room/whitepapers/linux/2059.php
	#
	# PCI 10.2
	#
	# Implement automated audit trails for all system components
	# to reconstruct the following events:
	# 10.2.1: All individual accesses to cardholder data
	# 10.2.2: All actions taken by any individual with root priv
	# 10.2.3: Access to all audit trails
	# 10.2.4: Invalid logical access attempts
	# 10.2.5: Use of identification and authentication mechanisms
	# 10.2.6: Initialization of audit logs
	# 10.2.7: Creation and deletion of system level objects
	#
	my $iptables_flags = "URG,ACK,PSH,RST,SYN,FIN";

	#
	# First, clean out the "filter" table:
	#	-F -> delete all rules in all chains
	#	-X -> delete every non-builtin chain
	#	-Z -> zero counters
	#
	# Check the return status on this first use of iptables cmd... it it works here,
	# we will just assume it works for the rest of the function.
	#
	loginfo("Deleting Old IPTables Rule Sets from Filter Table.");
	if (system("$fwcmd -t filter -F") != 0) {
		my $exitstatus = $? >> 8;
		showinfo("Exec of ($fwcmd) failed: exit status: $exitstatus.");
		showinfo("Host firewall will not be configured.");
		return(0);
	}
	system("$fwcmd -t filter -X");
	system("$fwcmd -t filter -Z");

	#
	# PCI DSS 1.2.1
	#	Restrict inbound and outbound traffic to that which is necessary
	#	for the cardholder data environment.  Verify that inbound and
	#	outbound traffice is limited to that which is necessary for
	#	for the cardholder data environment.  Verify that all other
	#	inbound and outbound traffic is specifically denied, eg by
	#	using an explicit "deny all" or an implicit deny after allow.
	#
	# Set the default policy in table "filter":
	#	DROP for the "INPUT" chain
	#	DROP for the "FORWARD" chain
	#	ACCEPT for the "OUTPUT" chain
	#
	loginfo("Setting Default Policies for Filter Table.");
	system("$fwcmd -t filter -P INPUT DROP");
	system("$fwcmd -t filter -P OUTPUT ACCEPT");
	system("$fwcmd -t filter -P FORWARD DROP");

	# Log accept rule
	# Make a new chain named "LOG_ACCEPT" and add rules to it.
	loginfo("Setting IPTables Logging Rules.");
	system("$fwcmd -N LOG_ACCEPT");
	system("$fwcmd -A LOG_ACCEPT -j LOG --log-level debug --log-prefix 'ACCEPT '");
	system("$fwcmd -A LOG_ACCEPT -j ACCEPT");

	# Loopback device
	system("$fwcmd -A INPUT -i lo -j ACCEPT");
	system("$fwcmd -A OUTPUT -o lo -j ACCEPT");
	if ($OS eq "RHEL6" || $OS eq "RHEL7") {
	    system("$fwcmd -A INPUT -s 127.0.0.0/255.0.0.0 ! -i lo -j DROP");
	}
	else {
	    system("$fwcmd -A INPUT -s 127.0.0.0/255.0.0.0 -i ! lo -j DROP");
	}
	# If a rule is needed: Allow localhost access to TCP 127.0.0.1/2551 for APCUPSD daemon.

	#
	# Allow return traffic initiated from the host
	#
	system("$fwcmd -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT");

	#
	# Accept important ping traffic
	#
	## Allow inbound ICMP from 192.168.x.x (ping, traceroute)
	## Allow inbound ICMP from 172.16.x.x (ping, traceroute)
	## Allow inbound ICMP from 10.x.x.x (ping, traceroute)
	## Allow inbound ICMP from teleflora IPs (ping,traceroute)
	#
	system("$fwcmd -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT");
	system("$fwcmd -A INPUT -p icmp --icmp-type echo-request -j ACCEPT");
	system("$fwcmd -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT");
	system("$fwcmd -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT");

	#
	# INPUT rules.
	#

	## Allow new inbound ssh (tfremote)
	## Allow new inbound sftp
	#
	## But slow down incoming ssh brute force attacks.
	## http://linuxquestions.org/questions/linux-security-4/breakin-attempt-normal-425588/
	#
	## This recent match does the following:
	## if the source address is on the bad guy list "sshprobe" and
	## if the source address tried 5 or more times in the last 60 seconds and
	## if the TTL of packet matches that which hit the -set rule.
	my $recent_too_fast = "-m recent --name sshprobe --update --seconds 60 --hitcount 5 --rttl";

	## This recent match adds the source address of the packet to
	## the list named "sshprobe"
	my $recent_add_list = "-m recent --name sshprobe --set";

	## Now use these matches for allowing ssh under acceptable conditions
	system("$fwcmd -A INPUT -p tcp --dport 22 -m state --state NEW $recent_too_fast -j DROP");
	system("$fwcmd -A INPUT -p tcp --dport 22 -m state --state NEW $recent_add_list -j LOG_ACCEPT");

	## Do the same thing for tfremote which is really ssh
	system("$fwcmd -A INPUT -p tcp --dport 15022 -m state --state NEW $recent_too_fast -j DROP");
	system("$fwcmd -A INPUT -p tcp --dport 15022 -m state --state NEW $recent_add_list -j LOG_ACCEPT");

	## Allow inbound from network printers
	system("$fwcmd -A INPUT -s  $network_addr -p tcp --sport 1100 -j ACCEPT");
	system("$fwcmd -A INPUT -s  $network_addr -p tcp --sport 9100 -j ACCEPT");

	## Allow inbound CUPS
	system("$fwcmd -A INPUT -s $network_addr -p tcp -m tcp --dport 631 -j ACCEPT");

	## Allow inbound Samba
	system("$fwcmd -A INPUT -s $network_addr -p udp -m udp --dport 137:138 -j ACCEPT");
	system("$fwcmd -A INPUT -s $network_addr -p tcp -m state --state NEW -m tcp --dport 137:139 -j ACCEPT");
	system("$fwcmd -A INPUT -s $network_addr -p tcp -m state --state NEW -m tcp --dport 445 -j ACCEPT");

	## Allow inbound Basis 
	system("$fwcmd -A INPUT -s $network_addr -p tcp -m tcp --dport 32778 -j ACCEPT");
	system("$fwcmd -A INPUT -s $network_addr -p tcp -m tcp --dport 42672 -j ACCEPT");
	
	## Allow inbound Basis License Manager
	system("$fwcmd -A INPUT -s $network_addr -p tcp -m tcp --dport 27000 -j ACCEPT");

	## Allow inbound Pro5
	system("$fwcmd -A INPUT -s $network_addr -p tcp -m tcp --dport 2525 -j ACCEPT");

	## Allow inbound rtibackup "slave server sync"
	system("$fwcmd -A INPUT -s $network_addr -p tcp -m tcp --dport 15020 -j ACCEPT");

	## Allow inbound BBj Connections.
	foreach my $port (@inbound_ports) {
		system("$fwcmd -A INPUT -s $network_addr -p tcp -m tcp --dport $port -j ACCEPT");
	}

	## Allow inbound Media99 connections
	##
	## determine whether this is a "media99 shop" - if it is, it needs
	## the "media99 port" open.  The definition of a "media99 shop"
	## is one where the directory "/usr2/media99" exists.
	if (-d "/usr2/media99") {
		system("$fwcmd -A INPUT -p tcp -m tcp --dport 4099 -j ACCEPT");
	}

	#
	# Accept and log end of connection.
	#
	system("$fwcmd -A INPUT -p tcp --tcp-flags $iptables_flags SYN,ACK -m state --state ESTABLISHED,RELATED -j LOG_ACCEPT");
	system("$fwcmd -A INPUT -p tcp --tcp-flags $iptables_flags FIN,ACK -m state --state ESTABLISHED,RELATED -j LOG_ACCEPT");
	system("$fwcmd -A INPUT -p tcp --tcp-flags $iptables_flags RST,ACK -m state --state ESTABLISHED,RELATED -j LOG_ACCEPT");


	## TODO: Allow inbound RTI "odbc" only from local IP Addresses.

	#
	# Policy for INPUT is DROP so if it didn't match any of the above rules,
	# the packet is dropped.
	#

	#
	# OUTPUT rules
	#
	# PCI 1.2.1
	#	Restrict outbound traffic to that which is necessary for
	#	the cardholder data environment.
	#

	## Allow all outbound
	system("$fwcmd -A OUTPUT -p tcp --syn -j ACCEPT");
	system("$fwcmd -A OUTPUT -m state --state NEW -j ACCEPT");
	system("$fwcmd -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT");

	## Allow outbound ssh and sftp to Teleflora
	system("$fwcmd -A OUTPUT -p tcp --dport ssh -m state --state NEW -j ACCEPT");

	## Allow outbound to network printers
	system("$fwcmd -A OUTPUT -p tcp -m tcp --dport 1100 -j ACCEPT");
	system("$fwcmd -A OUTPUT -p tcp -m tcp --dport 9100 -j ACCEPT");

	## Allow outbound DNS
	system("$fwcmd -A OUTPUT -p udp --dport domain -m state --state NEW -j ACCEPT");
	system("$fwcmd -A OUTPUT -p tcp --dport domain -m state --state NEW -j ACCEPT");

	## Allow outbound NTP traffic
	system("$fwcmd -A OUTPUT -p udp --sport ntp -m state --state NEW -j ACCEPT");

	## Allow outbound CUPS traffic
	system("$fwcmd -A OUTPUT -p tcp --dport 631 -m state --state NEW -j ACCEPT");

	## TODO: Allow outbound ICMP to all (ping, traceroute)

	## TODO: Allow outbound SMTP for RTI v12.x email.

	## TODO: Allow outbound POP for RTI v12.x "fetchmail"

	## Allow outbound http/https to tws.teleflora.com
	## Allow outbound http/https to redhat
	## Allow outbound http/https to "whatismyip.com"
	system("$fwcmd -A OUTPUT -p udp --dport http -m state --state NEW -j ACCEPT");
	system("$fwcmd -A OUTPUT -p udp --dport https -m state --state NEW -j ACCEPT");

	#
	# Accept and log end of connection.
	#
	system("$fwcmd -t filter -A OUTPUT -p tcp --tcp-flags $iptables_flags SYN,ACK -m state --state ESTABLISHED,RELATED -j LOG_ACCEPT");
	system("$fwcmd -t filter -A OUTPUT -p tcp --tcp-flags $iptables_flags FIN,ACK -m state --state ESTABLISHED,RELATED -j LOG_ACCEPT");
	system("$fwcmd -t filter -A OUTPUT -p tcp --tcp-flags $iptables_flags RST,ACK -m state --state ESTABLISHED,RELATED -j LOG_ACCEPT");
	system("$fwcmd -t filter -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT");


	## Deny/log all remaining outbound ipv4
	#system("$fwcmd -A OUTPUT -j DROP");


	#
	# PCI 1.2.2
	#	Secure and syncrhonize router config files.  Verify that router
	#	config files are secure and synchronized, eg, running config
	#	files and start-up config files have the same config.
	#

	# save iptables rules, this method is good for RHEL5/6/7.
	# if the save worked, restart the iptables system service
	system("/sbin/service iptables save");
	if ($? != 0) {
	    showerror("[iptables] could not save iptables rules");
	}
	else {
	    my $iptables_rules_file = '/etc/sysconfig/iptables';
	    if (-f $iptables_rules_file) {
		if (-s $iptables_rules_file) {
		    showinfo("[iptables] iptables rules saved: $iptables_rules_file");
		    my $exit_status;
		    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
			$exit_status = system("/sbin/service iptables restart");
		    }
		    elsif ($OS eq 'RHEL7') {
			$exit_status = system("/bin/systemctl restart iptables.service");
		    }
		    else {
			showerror("[iptables] could not restart iptables: unsupported platform: $OS");
			$exit_status = 1;
		    }
		    if ($exit_status == 0) {
			showinfo("[iptables] iptables system service restarted");
		    }
		    else {
			showerror("[iptables] could not restart iptables system service");
		    }
		}
		else {
		    showerror("[iptables] iptables rules file zero size: $iptables_rules_file");
		}
	    }
	    else {
		showerror("[iptables] iptables rules file does not exist: $iptables_rules_file");
	    }
	}


	my $conf_file = ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) ? '/etc/rsyslog.conf' : '/etc/syslog.conf';
	if (hl_iptables_modify_syslog($conf_file)) {
	    loginfo("[iptables] new conf file generated: $conf_file");
	}
	else {
	    showerror("[iptables] could not generate new conf file: $conf_file");
	}

	return(1);
}


sub disable_ipv6_update_network_config
{
    my $configfile = '/etc/sysconfig/network';

    system("cp $configfile $configfile.$$");
    if (-s "$configfile.$$" > 0) {
	if (open(my $newfh, '>', $configfile)) {
	    if (open(my $oldfh, '<', $configfile.$$)) {
		while (<$oldfh>) {
		    next if(/^(\s*)(NETWORKING_IPV6)(\s*)(=)/);
		    next if(/^(\s*)(IPV6INIT)(\s*)(=)/);
		    print {$newfh} $_;
		}
		print {$newfh} "NETWORKING_IPV6=no\n";
		print {$newfh} "IPV6INIT=no\n";
		close($oldfh);
	    }
	    close($newfh);
	}
    }
    if (-s "$configfile" > 0) {
	unlink "$configfile.$$";
    }
    else {
	system("cp $configfile.$$ $configfile");
    }

    return(1);
}


#
# The ipv6 kernel module also needs to be prevented from loading.
# To accomplish that, add a new modprobe config file to directory
# /etc/modprobe.d if it does not exist.
#
sub disable_ipv6_add_modprobe_config
{
    my $rc = 1;

    my $modprobe_conf_file = '/etc/modprobe.d/tf-disable-ipv6.conf';

    if (-e $modprobe_conf_file) {
	showinfo("ipv6 already disabled with modprobe config file: $modprobe_conf_file");
    }
    else {
	if (open(my $newfh, '>', $modprobe_conf_file)) {
	    print {$newfh} "install ipv6 /bin/true\n";
	    close($newfh);

	    if (-e $modprobe_conf_file) {
		showinfo("new modprobe config file generated: $modprobe_conf_file");
		showinfo("ipv6 will be disabled after next reboot.");
	    }
	    else {
		showinfo("new modprobe config file NOT generated: $modprobe_conf_file");
		showinfo("ipv6 will not be disabled");
		$rc = 0;
	    }
	}
	else {
	    showinfo("could not make new modprobe config file: $modprobe_conf_file");
	    showinfo("ipv6 will not be disabled");
	    $rc = 0;
	}
    }

    return($rc);
}


#
# Make sure the ip6tables system service is not running and
# that it will not be started at the next reboot.
#
sub disable_ipv6_stop_ip6tables_service
{
    my $service_name = 'ip6tables';

    system("/sbin/service $service_name stop");
    system("/sbin/chkconfig $service_name off");

    loginfo("system service stopped and disabled: $service_name");

    return(1);
}


#
# Remove ipv6 line from /etc/hosts if present
#
sub disable_ipv6_update_hosts_config
{
    my $conf_file = '/etc/hosts';
    my $new_conf_file = "$conf_file.$$";

    if (open(my $oldfh, '<', $conf_file)) {
        if (open(my $newfh, '>', $new_conf_file)) {

	    my $ipv6_line_seen = 0;
	    while (<$oldfh>) {
		if (/^::1/) {
		    # note that ipv6 lines were skipped
		    $ipv6_line_seen = 1;
		}
		else {
		    # everything else gets through
		    print {$newfh} $_;
		}
	    }
	    close($newfh);

	    if ($ipv6_line_seen) {
		system("mv $new_conf_file $conf_file");
		loginfo("ipv6 lines removed from: $conf_file");
	    }
	    else {
		system("rm $new_conf_file");
		loginfo("there were no ipv6 lines within: $conf_file");
	    }
	}
	close($oldfh);
    }

    return(1);
}


#
# make a new sysctl config file to set the kernel parameter
# to disable ipv6 for all network interfaces.
#
sub disable_ipv6_add_sysctl_config
{
    my $sysctl_conf = '/etc/sysctl.d/98-tf-ipv6.conf';

    my $rc = 1;

    if (-e $sysctl_conf) {
	showinfo("sysctl config file to disable ipv6 already exists: $sysctl_conf");
    }
    else {
	if (open(my $newfh, '>', $sysctl_conf)) {
	    print {$newfh} "net.ipv6.conf.all.disable_ipv6 = 1\n";
	    close($newfh);

	    system("chown root:root $sysctl_conf");
	    system("chmod 644 $sysctl_conf");

	    system("sysctl -p $sysctl_conf");

	    showinfo("ipv6 disabled via new config file: $sysctl_conf");
	}
	else {
	    showerror("could not make new config file to disable ipv6: $sysctl_conf");
	    $rc = 0;
	}
    }

    return($rc); 
}

#
# Disable IPv6. We don't use it.
# PCI-DSS 1.1.5
#
# Enclosed below is the old comment that may not be so true
# sooner rather than later since ipv4 addresses are getting to
# be quite rare and the use of ipv6 may become necessary.
# Also, the steps briefly outlined were for RHEL5 and they
# were good for RHEL6.  But RHEL7 requires a different
# procedure.
#
#> There is no reason for us to be using ipv6, and, ipv6 hacks are becoming
#> a known vulnerability in the world of security.
#>
#> Disable IPv6 networking whether it is currently enabled or not.
#> Make sure the following 2 lines are added to the file
#> "/etc/sysconfig/network":
#>	NETWORKING_IPV6=no
#>	IPV6INIT=no
#>
#> Additionally, this should happen in execution of function setup_system_services():
#>	service ip6tables stop
#>	chkconfig ip6tables off
#>
#> This tip from the National Security Agency publication:
#> "Hardening Tips for the Default Installation of Red Hat Enterprise Linux 5"
#
sub disable_ipv6
{
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {

	disable_ipv6_update_network_config();

	disable_ipv6_add_modprobe_config();

	disable_ipv6_stop_ip6tables_service();

	disable_ipv6_update_hosts_config();

    }

    if ($OS eq 'RHEL7') {

	disable_ipv6_add_sysctl_config();

	disable_ipv6_update_hosts_config();
    }

    showinfo("ipv6 disabled");

    return(0);
}


sub generate_hosts_allow_empty
{
    my ($conf_file) = @_;

    my $rc = 1;

    my $timestamp = strftime("%Y%m%d%H%M%S", localtime());

    if (open(my $cfh, '>', $conf_file)) {
	print {$cfh} "#\n";
	print {$cfh} "# $conf_file\n";
	print {$cfh} "# Generated by $0 $CVS_REVISION $timestamp\n";
	print {$cfh} "#\n";
	close($cfh);

	system("chown root:root $conf_file");
	system("chmod 644 $conf_file");
    }
    else {
	logerror("[gen empty hosts allow] could not generate new empty config file: $conf_file");
	$rc = 0;
    }

    return($rc);
}


sub generate_hosts_allow_local_network
{
    my ($allowfh, $ipaddr, $gateway) = @_;

    my $local_network_rule = "";

    if ($ipaddr =~ /^192\.168/) {
	$local_network_rule = "sshd: 192.168. except $gateway\n";
    }
    elsif ($ipaddr =~ /^172\.(16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)/) {
	for (my $i=16; $i <= 31; $i++) {
	    $local_network_rule .= sprintf("sshd: 172.%i. except %s\n", $i, $gateway);
	}
    }
    elsif ($ipaddr =~ /^10\./) {
	$local_network_rule = "sshd: 10. except $gateway\n";
    }
    else {
	showinfo("Can't determine local network pattern for rule in /etc/hosts.allow.");
	showinfo("Please add rule to $0 conf file: $CONFIGFILE_PATH");
	$local_network_rule = "#sshd: LOCAL_NETWORK_PATTERN except $gateway\n";
    }

    print($allowfh "# access from local network\n");
    print($allowfh "$local_network_rule");

    return(1);
}


sub generate_hosts_allow_standard_rules
{
    my ($allowfh) = @_;

    #
    # Here are the rules that will be put into the host access file,
    # ie /etc/hosts.allow.
    #
    # This string is referenced both by the function that writes the
    # actual file and the function that decides if there any non-std
    # sshd rules in the existing file by searching through the list
    # generated from the string.
    #
    # Thus, add any new rules to this string.
    #
    my @hosts_allow_sshd_rules = (
	"# access via loopback",
	"sshd: 127.0.0.1",
	"# access from OKC IT",
	"sshd: 65.198.163.36",
	"tfremote: 65.198.163.36",
	"# access from AR Customer Service",
	"sshd: 65.245.5.36",
	"tfremote: 65.245.5.36",
	"# access from AR MSG network",
	"sshd: 65.245.5.209",
	"tfremote: 65.245.5.209",
	"# access from AR MSG network",
	"sshd: 209.141.208.118",
	"tfremote: 209.141.208.118",
	"# Sendmail",
	"sendmail: 127.0.0.1",
    );

    foreach (@hosts_allow_sshd_rules) {
	print($allowfh "$_\n");
    }

    print($allowfh "#\n");
    print($allowfh "# End of generated content\n");
    print($allowfh "#\n");

    return(1);
}


sub generate_hosts_allow_site_rules
{
    my ($allowfh) = @_;

    # append site dependent entries if any
    if ($HOSTSALLOW_APPEND) {

	showinfo("[gen hosts allow] appending site dependent host access rules from: $CONFIGFILE_PATH");

	print($allowfh "#\n");
	print($allowfh "# Begin custom sshd rules\n");
	print($allowfh "#\n");

	print($allowfh "$HOSTSALLOW_APPEND");

	print($allowfh "#\n");
	print($allowfh "# End custom sshd rules\n");
	print($allowfh "#\n");
    }

    return(1);
}


#
# generate new hosts access config file
#
# returns
#   1 on success
#   0 on error
#
sub generate_hosts_allow
{
    my ($conf_file) = @_;

    my $rc = 1;

    my $ipaddr = get_host_ipaddr();
    if ($ipaddr eq "") {
	showinfo("[gen hosts allow] could not host ip address required for generating: $conf_file");
	return(0);
    }

    my $gateway = get_gateway_ipaddr();
    if ($gateway eq "") {
	showinfo("[gen hosts allow] could not get gateway address required for generating: $conf_file");
	return(0);
    }

    unless (-e $conf_file) {
	showinfo("[gen hosts allow] there is no existing host access conf file: $conf_file");
    }


    if (generate_hosts_allow_empty($conf_file)) {
	loginfo("[gen hosts allow] generated new host access conf file template: $conf_file");
    }
    else {
	showerror("[gen hosts allow] could not generate new host access conf file template: $conf_file");
	return(0);
    }

    if (open(my $allowfh, '>>', $conf_file)) {

	generate_hosts_allow_local_network($allowfh, $ipaddr, $gateway);

	generate_hosts_allow_standard_rules($allowfh);

	generate_hosts_allow_site_rules($allowfh);

	close($allowfh);

	showinfo("[gen hosts allow] generated new host access conf file: $conf_file");

	# set perms
	system("chown root:root $conf_file");
	system("chmod 644 $conf_file");
	showinfo("[gen hosts allow] perms set for new host access conf file: $conf_file");
    }
    else {
	showerror("[gen hosts allow] could not write to new host access conf file: $conf_file");
	$rc = 0;
    }

    return($rc);
}


sub generate_hosts_deny
{
    my ($conf_file) = @_;

    my $rc = 1;

    if (open(my $denyfh, '>', $conf_file)) {
        print {$denyfh} 'sshd: ALL: spawn (echo "illegal connection attempt from %a to %d %p at `date` %u user" | mail managedservicesar@teleflora.com -s "Unauthorized ssh connection for `hostname`';
        print {$denyfh} "\n";
        print {$denyfh} 'tfremote: ALL: spawn (echo "illegal connection attempt from %a to %d %p at `date` %u user" | mail managedservicesar@teleflora.com -s "Unauthorized tfremote connection for `hostname`';
        print {$denyfh} "\n";
        print {$denyfh} 'in.telnetd: ALL: spawn (echo "illegal connection attempt from %a to %d %p at `date` %u user" | mail managedservicesar@teleflora.com -s "Unauthorized ssh connection for `hostname`';
        print {$denyfh} "\n";
        print {$denyfh} 'ALL: ALL';
        print {$denyfh} "\n";
        close($denyfh);

	showinfo("[gen hosts deny] generated new host access conf file: $conf_file");

	system("chown root:root $conf_file");
	system("chmod 644 $conf_file");
	showinfo("[gen hosts deny] perms set for new host access conf file: $conf_file");
    }
    else {
	logerror("[gen hosts deny] could not open for write: $conf_file");
	$rc = 0;
    }

    return($rc);
}


#
# Use "tcpwarappers" to also guard against external access.
# PCI-DSS 1.1.5
# PCI-DSS 1.2.x
#
# In order to use the "hosts_access(3)", the binary implementing the service
# must be linked with the "libwrap" library.  Here is what testing determined...
# pretty much the *only* service which observes this access is sshd:
#
# binary	platform	yes	no
# cupsd		all			x
# httpd		all			x
# nmbd		all			x
# ntpd		all			x
# sshd		all		x
#
# returns
#   1 on success
#   0 if error
#

sub modify_host_access
{
    #
    # if host ip is reported as 127.0.0.1, this is a misconfiguration and
    # it's best if the script punts.
    #
    my $ipaddr = get_host_ipaddr();
    if ($ipaddr eq "127.0.0.1") {
	showerror("[modify host access] mis-configuration, host ip address reported as: $ipaddr");
	return(0);
    }

    my $deny_conf_file = '/etc/hosts.deny';
    unless (generate_hosts_deny($deny_conf_file)) {
	showinfo("[modify host access] could not generate new host access file: $deny_conf_file");
	return(0);
    }

    my $allow_conf_file = '/etc/hosts.allow';
    unless (generate_hosts_allow($allow_conf_file)) {
	showinfo("[modify host access] could not generate new host access file: $allow_conf_file");
	return(0);
    }

    return(1);
}


sub sshd_conf_rewrite
{
    my ($oldfh, $newfh) = @_;

    while (<$oldfh>) {
	next if(/^(\s*)(#BEGIN code added by $0)/i);
	next if(/^(\s*)(#END code added by $0)/i);
	next if(/^(\s*)(ListenAddress)/i);
	next if(/^(\s*)(PermitRootLogin)/i);
	next if(/^(\s*)(Banner)/i);
	next if(/^(\s*)(AllowTcpForwarding)/i);
	next if(/^(\s*)(X11Forwarding)/i);
	next if(/^(\s*)(PasswordAuthentication)/i);

	print {$newfh} $_;
    }

    print {$newfh} "#BEGIN code added by $0 $CVS_REVISION $TIMESTAMP\n";
    print {$newfh} "ListenAddress 0.0.0.0\n";
    print {$newfh} "PermitRootLogin no\n";
    print {$newfh} "Banner /etc/motd\n";
    print {$newfh} "AllowTcpForwarding yes\n";
    print {$newfh} "X11Forwarding no\n";
    print {$newfh} "PasswordAuthentication yes\n";
    print {$newfh} "#END code added by $0 $CVS_REVISION $TIMESTAMP\n";

    return(1);
}


#
# Since ssh is remote access, tighten up access.
# PCI-DSS 8.3
#
# returns
#   1 on success
#   0 if error
#
sub modify_sshd
{
    my $conf_file = '/etc/ssh/sshd_config';

    my $timestamp = strftime("%Y%m%d%H%M%S", localtime());
    my $new_conf_file = $conf_file . '-' . $timestamp;

    my $rc = 1;

    if (open(my $oldfh, '<', $conf_file)) {
	if (open(my $newfh, '>', $new_conf_file)) {
	    if (sshd_conf_rewrite($oldfh, $newfh)) {
		loginfo("[mod ssh] sshd conf file rewritten: $conf_file");
	    }
	    else {
		showerror("[mod ssh] could not rewrite sshd conf file: $conf_file");
		$rc = 0;
	    }
	    close($newfh);
	}
	close($oldfh);
    }

    if ($rc) {
	if (-s $new_conf_file) {
	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");
	    system("mv $new_conf_file $conf_file");
	    showinfo("[mod ssh] sshd conf file modified: $conf_file");

	    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
		system ("/sbin/service sshd restart");
	    }
	    if ($OS eq 'RHEL7') {
		system ("/usr/bin/systemctl restart sshd");
	    }
	    showinfo("[mod ssh] sshd system service restarted");
	}
	else {
	    if (-e $new_conf_file) {
		showerror("[mod ssh] new ssh conf file exists but is zero length: $new_conf_file");
		system("rm $new_conf_file");
	    }
	    else {
		showerror("[mod ssh] new ssh conf file does not exist: $new_conf_file");
	    }
	    $rc = 0;
	}
    }

    return($rc);
}


#
#Syncrhonize clock with network servers.
#PCI 10.4
#
# Red Hat Enterprise Linux 5
#
# /etc/init.d/ntpd, seeks for a file, /etc/ntp/step-tickers, on start-up.
# If it finds the file, the script will execute ntpdate command against
# the servers in /etc/ntp/step-tickers.  The command executed looks
# something like:
#   /usr/sbin/ntpdate $dropstr -s -b $NTPDATE_OPTIONS $tickers &>/dev/null.
#
# Red Hat Enterprise Linux 6
#
# /etc/init.d/ntpdate seeks for /etc/ntp/step-tickers.
# It is no longer called from /etc/init.d/ntpd.
# For usage, ntpdate should be set to start at boot (chkconfig on).
# They system will then use the ntpdate command to sync at boot with
# the destinations listed in the step-tickers file.
#
sub modify_timeservers
{
    my $ntp_dir = '/etc/ntp';

    unless (-d $ntp_dir) {
	showerror("[modify timeservers] required directory does not exist: $ntp_dir");
	return(0);
    }

    my $ntp_conf = '/etc/ntp/step-tickers';
    if (open(my $ntpfh, '>', $ntp_conf)) {
	print {$ntpfh} "clock.redhat.com\n";
	print {$ntpfh} "time.nist.gov\n";
	close($ntpfh);

	system("chown root:root $ntp_conf");
	system("chmod 644 $ntp_conf");

	showinfo("[modify timeservers] generated new ntp conf file: $ntp_conf");

	if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	    system("/sbin/service ntpd restart");
	    showinfo("[modify timeservers] restarted system service: ntpd");
	}
    }

    return(1);
}


sub update_aide
{
    showinfo("[update aide] aide database update no longer performed");

    return(1);
}


# 
# Show the user an error message *and* log to syslog
#
sub showerror
{
    my ($msg) = @_;

    print("$msg\n");
    return(logit($msg, 'E'));
}

# 
# Show the user an info message *and* log to syslog
#
sub showinfo
{
    my ($msg) = @_;

    print("$msg\n");
    return(logit($msg, 'I'));
}

sub loginfo
{
    my ($msg) = @_;

    return(logit($msg, 'I'));
}

sub logwarning
{
    my ($msg) = @_;

    return(logit($msg, 'W'));
}

sub logerror
{
    my ($msg) = @_;

    return(logit($msg, 'E'));
}

#
# Only Log message to syslog.
#
sub logit
{
    my ($msg, $msg_type) = @_;

    my $tag = "$PROGNAME";

    system("/usr/bin/logger -i -t $tag -- \"<$msg_type> $msg\"");
    if ($? == 0) {
	return(1);
    }

    return(0);
}


__END__

=pod

=head1 NAME

harden_linux.pl - Linux operating systems security hardener

=head1 VERSION

This documenation refers to version: $Revision: 1.136 $


=head1 USAGE

harden_linux.pl B<--version>

harden_linux.pl B<--help>

harden_linux.pl B<--install [--upgrade-12-13]>

harden_linux.pl B<--install-configfile [--configfile=path]>

harden_linux.pl B<--convert-configfile [--configfile=path]>

harden_linux.pl B<--iptables-port=string>

harden_linux.pl B<[--configfile=path]>

harden_linux.pl B<--all [--configfile=path]>

harden_linux.pl B<(--ipv6 | --hostsallow | --pam | --services | --bastille | --logging | --logrotate | --ssh | --time | --ids) [--configfile=path]>

harden_linux.pl B<(--iptables | --sudo) [--configfile=path] [--revert-delay=n]>

harden_linux.pl B<(--revert-iptables | --revert-sudo)>



=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--install>

Install the script.

=item B<--upgrade-12-13>

Force an upgrade from the 1.12.x version of the script to a
1.13.x version.

=item B<--all>

For convenience, this option is the same as specifying all options.

=item B<--install-configfile>

Install a default version of the config file.

=item B<--convert-configfile>

Convert any "append" directives to "directory" style.

=item B<--configfile=path>

Specify the location of the config file.
This option may be added to any of the other options.

=item B<--revert-delay=n>

Setup an "at job" which will revert a change after 'n' minutes.
This option may only be specified with the B<--iptables> or
B<--sudoers> options.

=item B<--revert-iptables>

Revert the last iptables change.

=item B<--revert-sudo>

Revert the last sudo change.

=item B<--iptables-port=string>

Allows specification of ports to open in the "iptables" firewall.

=item B<--iptables>

Configure the iptables system service.

=item B<--ipv6>

Disable the IPv6 features of the system.

=item B<--hostsallow>

Generate a new "/etc/hosts.allow" file.

=item B<--pam>

Configure login parameters via PAM.

=item B<--sudo>

Generate a new "/etc/sudoers" file.

=item B<--services>

Stop and disable system services not on an allowed white list.

=item B<--bastille>

No function, present for backward compatability only.

=item B<--logging|--logrotate>

Configure the log file rotation schedule.

=item B<--ssh>

Generate a new instance of the sshd config file.

=item B<--time>

Generate a new NTP "step-tickers" config file.

=item B<--ids>

No function, present for backward compatability only.

=back


=head1 DESCRIPTION

The C<"harden_linux.pl"> improves the security of the system,
chiefly with respect to PCI security requirements.
It performs this system "hardening", in a manner of speaking,
by editing or generating config files which control or
dictate the actions of several of the system facilities;
some of these system facilities include:
iptables, PAM, sudoers, hosts.allow, system services, ssh, etc.

The "harden script" must be run as C<"root">,
ie either from the C<"root"> account or via the C<"sudo"> command;
if not, the script will exit with a non-zero exit status .

Each of these facilities may be changed all at once, or individually.
The selection of which facilities to configure is accomplished via the
configuration command line options.

Running C<"harden_linux.pl"> with no configuration command line options
means to configure all the facilities under the purview of C<"harden_linux.pl">.
Likewise, the C<"--all"> option is the same as if
no configuration command line options were specified.

There are no command line arguments expected and any specifed are ignored.

Running C<"harden_linux.pl"> with select configuration options means
to configure just the facility specified.
For example, the command:

    harden_linux.pl --iptables

will only configure the iptables facility.

There are other command line options that deal with details other than
the facility to configure.
There are options like C<"--version"> to report the version number, and
C<"--help"> to output a brief help message.

=head2 CONFIG FILE

There is a config file for the C<"harden_linux.pl"> command.
The name of the config file is C<"harden_linux.conf">.
The default location of the config file is located
in C<"/usr2/ostools/config"> for RTI systems and
in C<"/d/ostools/config"> for Daisy systems.
The path to a custom config file may be specified with the
C<"--configfile=path"> command line option.

Blank lines, or lines that have only "white space", or
lines that begin with a C<"#"> character are ignored.
Otherwise, each line is considered a config file directive.
Each directive can tailor the behavior of harden_linux.pl in some way.
There can be one or more directives in the config file.

The are several types of directives -
the first type can enable or disable any of the configuration options.
Thus, there corresponds a directive for each of these options.
However, if an option is enabled in the config file,
the action associated with an option is only performed by
C<"harden_linux.pl"> if it is I<also> specified on the command line.
And on the contrary, an option that is disabled in the config file,
then the action associated with that option is NOT performed even
if it is specified on the command line.
Thus, for the revertable and non-revertable configuration options,
the config file is best used as a way to keep some options from
being performed.
This is quite useful when running on a host that is known to be
incompatible with one of more of the configuration options.

The second type of directive is the "append" directive which
provides a method of adding content to a generated config file.
Currently, the two config files supported are C<"/etc/hosts.allow"> and
C<"/etc/sudoers">.

An as example of the first type of directive,
the C<"harden_linux.pl"> config file can contain lines like:

 iptables=yes
 sudo=no
 ids=no

and so on, one for each of the configuration options.
The value of the directive is the word to the right of the EQUAL SIGN;
for the configuration options, the word may either be "yes" or "no",
"true" or "false", "1" or "0".
The default value of a configuration option directive is considered to be "true".

As an example, the "iptables" directive
can be used to prevent configuration of the iptables facility.
If the config file contains the line:

 iptables=no

then when the C<"harden_linux.pl"> script runs,
the iptables facility will not be configured.
The config file overrides any command line options.
This can be useful for sites that are known to have networks
that are not supported by the C<"harden_linux.pl --iptables"> command.

The second directive type provides a method for specifying the text that
will be appended to the contents of a generated config file.
This may be used to specify site dependent contents to be added
to the contents generated by C<"harden_linux.pl">.
The syntax of this "append" command is very similar to the
BASH Shell "here" document.

The following command;

 harden_linux.pl --hostsallow

generates a new C</etc/hosts.allow> config file with standard contents.
The append directive may be used as
a way to add additional, site dependent contents to C</etc/hosts.allow>.

For example, if the C<harden_linux.pl> config file contains:

 append /etc/hosts.allow << EOF
 #Fred
 sshd:   10.10.6.0 except 10.10.6.1
 #Barney
 sshd:   10.10.7.0 except 10.10.7.1
 #Wilma
 sshd:   10.10.8.0 except 10.10.8.1
 EOF

then the lines between the "append" line and the "marker" line,
ie the line containing only "EOF", will be appended to C</etc/hosts.allow>
whenever a new instance of C</etc/hosts.allow> is generated.

Another form of the "append" command allows the specification of
the path to a file whose contents will be appended to the C</etc/sudoers>
config file.

For example, if the C<harden_linux.pl> config file contains:

 append /etc/sudoers == /etc/sudoers.local

then the contents of C</etc/sudoers.local> will be appended to the
C</etc/sudoers> file generated by C<harden_linux.pl>.

Yet another method to append site specific content to C</etc/sudoers> file
is to specify the path to a directory in the "append" directive.
Then, the conents of any files in the directory
that have a file extension of C<.conf>
will all be appended to the generated C<sudoers> file.

For example, if the C<harden_linux.pl> config file contains:

 append /etc/sudoers == /d/ostools/config/sudoers.d

and C</d/ostools/config/sudoers.d> is a directory, and
the directory contains the files C<tfspec.conf>, C<tfdefault.conf>, and
C<tfdefault.conf.old>, then
the contents of the files C<tfspec.conf> and C<tfdefault.conf>
will be concatenated and appended to the C</etc/sudoers> file.

If mutltiple types of "append" directives appear in the C<harden_linux.pl>
config file, then
the last "append" directive in the conf file will be the one that
actually takes effect.

A third directive available is the C<iptables-port=n> directive.
This directive allows the specification of additional inbound ports to open
in the iptables "INPUT" chain of the "filter" table.
One or more of these directives are allowed.
For each directive, only 1 port number is allowed.
The allowed value of "n" is 0 to 65535.


=head2 COMMAND LINE OPTIONS

The C<--install> command line option performs all the steps
necessary to install the C<harden_linux.pl> script onto the system.
First, a new default config file is installed - please see the
description for the C<--install-configfile> option for the details.
Then, the version of the currently installed C<harden_linux.pl> script
is compared with the new version to be installed.
If the old version was 1.12.x and the new version is 1.13.x, then
the custom rules from C</etc/hosts.allow> are migrated to the
C<harden_linux.conf> file.
For some situations where the automatic detection of an upgrade may
not be possible, ie when a whole new OSTools package is being stalled,
the upgrade step may be forced by specifying the C<--upgrade-12-13>
command line option.
Thus, when C<harden_linux.pl --all> or C<harden_linux.pl --hostsallow>
is run and a new C</etc/hosts.allow> config file is generated,
these rules will be in place in the config file and
thus be included in the new instance
of the C</etc/hosts.allow> config file.

The C<--all> command line option is a convenience alias;
this option is the same as specifying
--iptables, --ipv6, --hostsallow, --pam, --sudo, --services,
--bastille, --logging, --ssh, --time,  and --ids.

The C<--install-configfile> command line option specifies that
the default config file is to be installed.
If a config file already exists, then the existing config will be left, and
the new version will be written with the suffix ".new".

The C<--configfile=path> command line option is a way to specify
an alternate location for the config file.
The default location is in the OSTools directory in a directory
named "config".  For example, on a Daisy system, the default location of
the config file is "/d/ostools/config/harden_linux.config".
If the "--install-configfile" and "--configfile=path" are both
specified on the same command line, the default config file will be
installed at the alternate location.

The C<--revert-delay=n> command line option provides a way to
revert a change made to the iptables config file or
to the "sudo" config file.
Changes to either of these config files could seriously
subvert the security of the system,
deny required services to the system, or
prevent privledged access to the system.
Thus, changes to them should not be taken lightly.

If a change is made via C<--iptables> or C<--sudo>, and
if the C<--revert-delay> option is also specified on the command line,
then after the change to the system is made,
an "at job" is submitted which will revert the system back to the way it
was before the change.
If the change made to the system was determined to be appropriate and
working as desired, the "at job" can be cancelled (via "sudo at -d <job_nr>") and
the change will stand.
If the change did not work as desired, it would be reverted automatically.

As an example, assume that the B<harden_linux.pl> config file has
a directive like:

 append /etc/sudoers == /d/ostools/config/sudoers.local

which causes the contents of "/d/ostools/config/sudoers.local" to be
appended to "/etc/sudoers" after it's generated by "harden_linux.pl".
If the command

 harden_linux.pl --sudo --revert-delay=5

is run, a new instance of the "/etc/sudoers" file is generated and
an "at job" is submitted that will revert the change after 5 mintues.
If that change happens to lock out privledged access to the system
for the "tfsupport" account,
after the time specified with the C<--revert-delay> option has elapsed,
the system will revert the change and
privledged access will be returned.

The C<--revert-iptables> command line option will revert to the last
change made to the iptables config file.

The C<--revert-sudo> command line option will revert to the last
change made to sudo config file, ie "/etc/sudoers".

The C<--iptables-port=string> command line option 
allows the user to specify a comma separated
list of ports to open in the "INPUT" chain of the "filter" table of
the iptables firewall.

The C<--iptables> command line option generates a new set of
iptables firewall rules.
Currently, only hosts on the 10.0.0.0/8,
172.16.0.0/12, and 192.168.0.0/24 networks are supported.
For systems on networks other than these networks, do not run
the "harden_linux.pl" script with "--iptables" option.
In fact, it is suggested that the line "iptables=no" be put in the
C<harden_linux.pl> config file so that even if "--iptables" is specified
on the command line, it will not be done.

The C<--ipv6> command line option disables support for the IPv6 network protocol.

The C<--hostsallow> command line option generates a new "/etc/hosts.allow" file.
The contents generated for the file "/etc/hosts.allow" will
depend on the network configuration and
any site dependent configuration specified in the harden_linux.pl conf file. 
Currently, for generation of the rule for "sshd" access to the server
from hosts on the local network, only hosts on the 10.0.0.0/8,
172.16.0.0/12, and 192.168.0.0/24 networks are supported.
For systems on networks other than these networks, add a
site specific rule to the "harden_linux.pl" conf file. 
For example, if your server IP address is 193.193.1.21 and
your gateway is at ip address 193.193.1.254,
add a rule like the following to the "harden_linux.pl" conf file -
this rule will be appended to the contents of the "/etc/hosts.allow" file
after the contents generated by "harden_linux.pl":

 append /etc/hosts.allow << EOF
 sshd: 193.193. except 193.193.1.254
 EOF

The C<--pam> command line option configures login parameters via PAM.
Examples are minimum length
of account passwords, number of incorrect login attempts allowed
before 30 minute timeout applied, etc.

For RHEL5 and RHEL6 systems, a new PAM conf file named
C</etc/pamd.d/system-auth-teleflora> is generated and
a symlink named C</etc/pam.d/system-auth> is made to point at it.
For RHEL6 systems, a symlink named C</etc/pam.d/passwd-auth> is also
made to point at it.
The first symlink takes care of enforcing login rules for non-SSH logins,
while the second symlink takes care of SSH logins.

It modifies the C</etc/securetty> file so that
root logins are allowed on C<tty12>;
it modifies C</etc/security/limits.conf> so that only 1 simultaneous Daisy admin
account login is allowed, 10 simultaneous "root" logins are allowed, and
10 simultaneous "tfsupport" logins are allowed;
modifies C</etc/pam.d/su> so that an "su -" will only work if entered
on one of the white listed tty lines or virtual consoles.
Basically, this disallows remote access to the "root" account.


The C<--sudo> command line option generates a new C</etc/sudoers> file.
One of the directives within the new C</etc/sudoers> file establishes
a log file named C</var/log/sudo.log> which records all commands
executed with C<sudo>.
Since this log file is subject to the PA-DSS rules for rotating and
retaining log files, a "logrotate" config file named
C</etc/logrotate.d/sudo> is generated to manage that requirment.

There is one issue with this strategy: one some systems, the
C<syslog> log rotate config file may contain a reference to C<sudo>.
If so, that reference must be removed since the C<logrotate> code
can not tolerate a reference to C<sudo> in the C<syslog> log rotate
config file and in a separate log rotate config file.


The C<--services> command line option disables all systerm services that
are not on a list of allowed system services, ie a "whitelist" of
system services.

The list of allowed system services for RHEL5 and RHEL6 is:

=over 4

    acpid
    apcupsd
    anacron
    atd
    auditd
    blm
    bbj
    cpuspeed
    crond
    cups
    cups-config-daemon
    daisy
    dgap
    dgrp_daemon
    dgrp_ditty
    dsm_sa_ipmi
    firstboot
    httpd
    instsvcdrv
    ipmi
    iptables
    irqbalance
    kagent-TLFRLC38702197701560
    kagent-TLFRLC81288907470344
    lm_sensors
    lpd
    lvm2-monitor
    mdmonitor
    mdmpd
    messagebus
    microcode_ctl
    multipathd
    network, ntpd
    readahead_early
    readahead_later
    restorecond
    rhnsd
    rsyslog
    rti
    sendmail
    smartd
    smb
    sshd
    syslog, 
    sysstat
    tfremote
    yum
    yum-updatesd
    zeedaisy
    PBEAgent

=back 4

The list of allowed system services for RHEL7 is as follows:

=over 4

    abrt-ccpp.service
    abrt-oops.service
    abrt-vmcore.service,
    abrt-xorg.service
    abrtd.service
    apcupsd.service
    atd.service
    auditd.service,
    crond.service
    cups.service,
    dbus-org.freedesktop.network1.service
    dbus-org.freedesktop.NetworkManager.service,
    dbus-org.freedesktop.nm-dispatcher.service,
    dmraid-activation.service,
    getty@.service,
    getty@tty1.service, getty@tty2.service, getty@tty3.service
    getty@tty4.service, getty@tty5.service, getty@tty6.service
    getty@tty7.service, getty@tty8.service, getty@tty9.service,
    getty@tty11.service
    httpd.service,
    iptables.service,
    irqbalance.service,
    kdump.service,
    libstoragemgmt.service,
    lvm2-monitor.service,
    mdmonitor.service,
    microcode.service,
    ntpd.service,
    rhsmcertd.service,
    rngd.service,
    rsyslog.service,
    sendmail.service
    sm-client.service
    smartd.service
    smb.service       
    sshd.service
    sysstat.service
    systemd-readahead-collect.service
    systemd-readahead-drop.service
    systemd-readahead-replay.service 
    tfremote.service
    tuned.service

=back 4

The C<--whitelist-enforce> command line option can be used
to modify the behavior of the C<--services> option for RHEL7 systems.
Currently, on RHEL7 systems, the default behavour is to not enforce 
the system services "whitelist" since the final list of allowed
system services has not yet been decided.
By specifying C<--whitelist-enforce>, the system services
"whitelist" will be enforced as is done on RHEL5 and RHEL6.
Note, enabling enforcement of the system services "whitelist"
is also available as a config file statement.
To enable enforcement, add the following line to the config file:

=over 4

whitelist-enforce=1

=back 4

The C<--bastille> command line option no longer performas any changes,
it is just present for backward compatability.

The C<--logging|--logrotate> command line option modifies the log file rotation
schedule so that log files are rotated on a monthly basis and
only deleted after one year.

The log rotate conf files that are modified:

=over 4

=item C</etc/logrotate.conf>

=item C</etc/logrotate.d/syslog>

=item C</etc/logrotate.d/httpd>

=item C</etc/logrotate.d/samba>

=back


The C<--ssh> command line option modifies the existing "sshd" config file
by making the following changes:
the "ListenAddress" is set to "0.0.0.0",
logins with the root account are disallowed over ssh,
TCP forwarding is enabled,
X11 forwarding is disabled,
and
password authentication is enabled.

The C<--time> command line option adds "clock.redhat.com" and
"time.nist.gov" to the "/etc/ntp/step-tickers" NTP config file and
on RHEL5 and RHEL6, restarts the "ntpd" system service.

The C<--ids> command line option no longer performas any changes,
it is just present for backward compatability.


=head1 FILES

=over 4

=item B</usr2/ostools/config/harden_linux.conf>

=item B</d/ostools/config/harden_linux.conf>

=item B</etc/sysconfig/iptables>

=item B</etc/sysconfig/network>

=item B</etc/modprobe.d/tf-disable-ipv6.conf>

=item B</etc/hosts.deny>

=item B</etc/hosts.allow>

=item B</etc/securetty>

=item B</etc/security/limits.conf>

=item B</etc/pamd.d/system-auth-teleflora>

=item B</etc/pam.d/su>

=item B</etc/sudoers>

=item B</etc/logrotate.d/sudo>

=item B</etc/logrotate.d/syslog>

=item B</etc/ssh/sshd_config>

=item B</etc/ntp/step-tickers>

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status: 0

Successful completion or when the "--version" and "--help"
command line options are specified.
Internal symbol: $EXIT_OK.

=item Exit status: 1

In general, there was an issue with the syntax of the command line.
Internal symbol: $EXIT_COMMAND_LINE.

=item Exit status: 2

For all command line options other than "--version" and "--help",
the user must be root or running under "sudo".
Internal symbol: $EXIT_MUST_BE_ROOT.

=item Exit status: 9

An error occurred converting the C<sudoers> append directives in the
config file from "here documents" and single files to
a directory of C<sudoers> config files.
Internal symbol: $EXIT_CONVERT_CONFIG.

=item Exit status: 11

An error occurred reverting to the previous iptables config.
Internal symbol: $EXIT_REVERT_IPTABLES.

=item Exit status: 12

An error occurred reverting to the previous sudo config.
Internal symbol: $EXIT_REVERT_SUDO.

=item Exit status: 15

The script could not get the version number of the installed OSTools.
Internal symbol:  $EXIT_OSTOOLS_VERSION.

=item Exit status: 20

An error occurred configuring iptables.
Internal symbol: $EXIT_IPTABLES.

=item Exit status: 21

An error occurred disabling IPv6.
Internal symbol: $EXIT_IPV6.

=item Exit status: 22

An error occurred generating a new /etc/hosts.allow file.
Internal symbol: $EXIT_HOSTS_ALLOW.

=item Exit status: 23

An error occurred configuring PAM rules.
Internal symbol: $EXIT_PAM.

=item Exit status: 24

An error occurred generating a new /etc/sudoers file.
Internal symbol: $EXIT_SUDO.

=item Exit status: 25

An error occurred configuring allowed system services.
Internal symbol: $EXIT_SERVICES.

=item Exit status: 26

An error occurred removing the SETUID bit from certain programs or
removing the "rsh" programs.
Internal symbol: $EXIT_BASTILLE.

=item Exit status: 27

An error occurred configuring the log file rotation schedule.
Internal symbol: $EXIT_LOGGING.

=item Exit status: 28

An error occurred modifying the sshd config file.
Internal symbol: $EXIT_SSH.

=item Exit status: 29

An error occurred generating the NTP server config file.
Internal symbol: $EXIT_TIME.

=item Exit status: 30

An error occurred updating the Aide intrusion detection system database.
Internal symbol: $EXIT_IDS.

=back


=head1 BUGS

The iptables configuration currently only supports
the 192.168.0.0/24, 10.0.0.0/8, and 172.16.0.0/12 networks.


=head1 SEE ALSO

/var/log/messages, /var/log/secure


=cut
