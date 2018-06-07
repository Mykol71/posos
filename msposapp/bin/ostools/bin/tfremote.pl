#!/usr/bin/perl
#
# $Revision: 1.56 $
# Copyright 2009-2015 Teleflora
# 
# tfremote.pl
#
# Setup a "parallel" SSHd service called "tfremote".
# PA-DSS 11.2
# PCI-DSS 8.2, 8.3
#

use strict;
use warnings;
use POSIX;
use Getopt::Long;
use English;
use File::Basename;
use Digest::MD5;

use lib qw( /teleflora/ostools/modules /d/ostools/modules /usr2/ostools/modules );
use OSTools::Platform;

my $CVS_REVISION = '$Revision: 1.56 $';
my $TIMESTAMP = strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($0);

#
# Definitions
#
my $DEF_SSH_DIR          = '/etc/ssh';
my $DEF_SSHD_CONFIG      = '/etc/ssh/sshd_config';
my $DEF_SSHD_BIN         = '/usr/sbin/sshd';
my $DEF_SSHD_INIT        = '/etc/init.d/sshd';
my $DEF_TFREMOTE_INIT    = '/etc/init.d/tfremote';
my $DEF_SSHD_SERVICE     = '/usr/lib/systemd/system/sshd.service';
my $DEF_TFREMOTE_CONFIG  = '/etc/ssh/tfremote_config';
my $DEF_TFREMOTE_SERVICE = '/etc/systemd/system/tfremote.service';

#
# Globals
#

# literals
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

# error exit codes
my $EXIT_OK           = 0;
my $EXIT_MUST_BE_ROOT = 1;
my $EXIT_COMMAND_LINE = 2;
my $EXIT_PLATFORM     = 3;

# command line options
my $VERSION = 0;
my $HELP = 0;
my $INSTALL = 0;
my $START = 0;
my $STOP = 0;
my $STATUS = 0;
my $CONNECT = "";

# command line options to invoke test code
my $TEST_MAKE_START_FILE = 0;
my $TEST_MAKE_CONFIG_FILE = 0;

my $OS = "";


GetOptions(
    "version" => \$VERSION,
    "help" => \$HELP,
    "install" => \$INSTALL,
    "start" => \$START,
    "stop" => \$STOP,
    "status" => \$STATUS,
    "connect=s" => \$CONNECT,
    "test-make-start-file" => \$TEST_MAKE_START_FILE,
    "test-make-config-file" => \$TEST_MAKE_CONFIG_FILE,
);


$OS = determine_os();
if ($OS eq $EMPTY_STR) {
    log_error("[main] unknown operating system");
    exit($EXIT_PLATFORM);
}

#
# if there were any command line options specifying test functions,
# the script will exit after running the test.
#
tfrem_test_functions();


# --help
if ($HELP) {
    usage();
    exit(0);
}

# --version
if ($VERSION) {
    print "OSTools Version: 1.15.0\n";
    print "$PROGNAME: $CVS_REVISION\n";
    exit(0);
}

# --status
if ($STATUS) {
    exit(tfremote_status());
}


# --connect some.host.com
# --connect=some.host.com
if ($CONNECT) {
    exit(connect_to_host($CONNECT));
}


#######################################################
# Root priviledge required to execute commands below  #
#######################################################

if ($< != 0) {
    usage();
    print("Error: Must run this script as 'sudo' or root.\n");
    exit($EXIT_MUST_BE_ROOT);
}


# --start
if ($START) {
    exit(start_tfremote());
}

# --stop
if ($STOP) {
    exit(stop_tfremote());
}

# --install
if ($INSTALL != 0) {
    exit(tfrem_install());
}


usage();

exit($EXIT_COMMAND_LINE);

#####################################################################
#####################################################################
#####################################################################


sub tfrem_test_functions
{
    if ($TEST_MAKE_START_FILE) {
	my $ssh_start_file = basename($DEF_SSHD_SERVICE);
	my $tfremote_start_file = basename($DEF_TFREMOTE_SERVICE);
	unless (tfrem_install_make_startup_file($ssh_start_file, $tfremote_start_file)) {
	    print "could not make start file: $tfremote_start_file\n";
	}
	exit(0);
    }

    if ($TEST_MAKE_CONFIG_FILE) {
	my $ssh_config_file = basename('/etc/ssh/sshd_config');
	my $tfremote_config_file = basename('/etc/ssh/tfremote_config');
	unless (tfrem_install_make_config_file($ssh_config_file, $tfremote_config_file)) {
	    print "could not make tfremote config file: $tfremote_config_file\n";
	}
	exit(0);
    }

    return(1);
}


sub usage
{
	print("Usage:\n");
	print("$PROGNAME --help\n");
	print("$PROGNAME --version\n");
	print("$PROGNAME --start\n");
	print("$PROGNAME --stop\n");
	print("$PROGNAME --status\n");
	print("$PROGNAME --install\n");
	print("$PROGNAME --connect some.host.com\n");
	print("\n");
	print("TFRemote is a system service which only allows incoming connections\n");
	print("authenticated via ssh public key encryption.  Since the service is\n");
	print("actually a second instance of OpenSSH, all configuration and\n");
	print("usage rules which apply to SSH, apply here as well.\n");
	print("\n");
	print("This script is capable of setting up the 'tfremote' service on a\n");
	print("Red Hat Enterprise Linux system, as well as starting and stopping\n");
	print("the service.\n");
	print("\n");
	return(0);
}


sub determine_os
{
    my $os = plat_os_version();

    return($os);
}


#
# Get useful information such as groups and home directory
# about a given user.
sub get_userinfo
{
	my ($username) = @_;

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


sub start_tfremote
{
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	return(system("/sbin/service tfremote start"));
    }
    if ($OS eq 'RHEL7') {
	return(system("systemctl start tfremote.service"));
    }
}


sub stop_tfremote
{
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	return(system("/sbin/service tfremote stop"));
    }
    if ($OS eq 'RHEL7') {
	return(system("systemctl stop tfremote.service"));
    }
}


sub tfremote_status
{
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	return(system("/sbin/service tfremote status"));
    }
    if ($OS eq 'RHEL7') {
	return(system("systemctl status tfremote.service"));
    }
}


#
# Verify the files required to exist before installation.
#
# returns
#   1 on success
#   0 if error
#
sub tfrem_install_verify_files
{
    my $rc = 1;
    my $ml = '[tfrem_install_verify_files]';

    # verify directories required to exist.
    my @required_dirs = (
	$DEF_SSH_DIR
    );
    foreach my $dir (@required_dirs) {
	if (-d $dir) {
	    print "$ml required dir verified: $dir\n";
	}
	else {
	    print "$ml required directory does not exist: $dir\n";
	    $rc = 0;
	}
    }

    # verify files required to exist.
    my @required_files = (
	$DEF_SSHD_CONFIG,
	$DEF_SSHD_BIN
    );
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	push(@required_files, $DEF_SSHD_INIT);
    }
    if ($OS eq 'RHEL7') {
	push(@required_files, $DEF_SSHD_SERVICE);
    }
    foreach my $file (@required_files) {
	if ( -f $file) {
	    print("$ml required file verified: $file\n");
	}
	else {
	    print("$ml required file does not exist: $file\n");
	    $rc = 0;
	}
    }

    return($rc);
}


#
# Given the existing sshd startup file, copy and edit it
# to the new tfremote startup file.
#
# returns
#   1 on success
#   0 if error
#
sub tfrem_install_make_startup_file
{
    my ($conf_file, $new_conf_file) = @_;

    my $rc = 1;
    my $ml = '[install_make_startup_file]';

    if (open(my $oldfh, '<', $conf_file)) {
	if (open(my $newfh, '>', $new_conf_file)) {
	    while (my $line = <$oldfh>) {
		if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
		    $line =~ s/ssh_host_key/tfremote_host_key/g;
		    $line =~ s/ssh_host_rsa_key/tfremote_host_rsa_key/g;
		    $line =~ s/ssh_host_dsa_key/tfremote_host_dsa_key/g;

		    $line =~ s/ssh_random_seed/tfremote_random_seed/g;
		    $line =~ s/sshd/tfremote/g;
		    $line =~ s/prog=\"([[:print:]]+)\"/prog=\"tfremote\"/g;
		    $line =~ s/description: .+$/description: Teleflora POS Remote Access/;
		}
		if ($OS eq 'RHEL7') {
		    $line =~ s/Description=.*$/Description=OpenSSH-tfremote server daemon/;
		    $line =~ s/After=.*$/After=network.target sshd.service/;
		    if ($line =~ /Wants=/) {
			next;
		    }
		    $line =~ s/ExecStart=.*$/ExecStart=\/usr\/sbin\/sshd -D -f \/etc\/ssh\/tfremote_config/;
		}

		print {$newfh} $line;
	    }
	    close($newfh);

	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");
	}
	else {
	    print "$ml could not open new conf file: $new_conf_file\n";
	    $rc = 0;
	}
	close($oldfh);
    }
    else {
	print "$ml could not open existing conf file: $conf_file\n";
	$rc = 0;
    }

    return($rc);
}


#
# make a new tfremote config file from a sshd config file.
#
# returns
#   1 on success
#   0 if error
#
sub tfrem_install_make_config_file
{
    my ($conf_file, $new_conf_file) = @_;

    my $rc = 1;
    my $ml = '[install_make_config_file]';

    if (open(my $oldfh, '<', $conf_file)) {
	if (open(my $newfh, '>', $new_conf_file)) {
	    while(<$oldfh>) {
		# remove these lines
		next if(/Port /i);
		next if(/ListenAddress /i);
		next if(/Protocol /i);
		next if(/HostKey /i);
		next if(/AcceptEnv /i);
		next if(/SyslogFacility /i);
		next if(/LogLevel /i);
		next if(/LoginGraceTime /i);
		next if(/MaxAuthTries /i);
		next if(/MaxStartups /i);
		next if(/PidFile /i);
		next if(/PermitRootLogin /i);
		next if(/RSAAuthentication /i);
		next if(/PubkeyAuthentication /i);
		next if(/RhostsRSAAutthenitcation /i);
		next if(/HostbasedAuthentication /i);
		next if(/IgnoreUserKnownHosts /i);
		next if(/IgnoreRhosts /i);
		next if(/PermitEmptyPasswords /i);
		next if(/PasswordAuthentication /i);
		next if(/KerberosAuthentication /i);
		next if(/UsePrivilegeSeparation /i);
		next if(/GSSAPIAuthentication /i);
		next if(/UsePAM /i);
		next if(/AllowTcpForwarding /i);
		next if(/X11Forwarding /i);
		next if(/Banner /i);
		next if(/ClientAliveInterval /i);
		next if(/ClientAliveCountMax /i);

		print {$newfh} "$_";
	    }

	    # now add the new lines
	    print {$newfh} "\n";
	    print {$newfh} "\n";
	    print {$newfh} "#\n"; 
	    print {$newfh} "# PA-DSS Compliant Settings\n";
	    print {$newfh} "# Setup by tfremote " . '$Revision: 1.56 $' . "\n";
	    print {$newfh} "#\n"; 
	    print {$newfh} "Port 15022\n";
	    print {$newfh} "ListenAddress 0.0.0.0\n";
	    print {$newfh} "Protocol 2\n";
	    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
		print {$newfh} "HostKey /etc/ssh/tfremote_host_rsa_key\n";
		print {$newfh} "HostKey /etc/ssh/tfremote_host_dsa_key\n";
	    }
	    if ($OS eq 'RHEL7') {
		print {$newfh} "HostKey /etc/ssh/ssh_host_rsa_key\n";
		print {$newfh} "HostKey /etc/ssh/ssh_host_ecdsa_key\n";
		print {$newfh} "HostKey /etc/ssh/ssh_host_ed25519_key\n";
	    }
	    print {$newfh} "AcceptEnv BBTERM\n";
	    print {$newfh} "SyslogFacility AUTH\n";
	    print {$newfh} "LogLevel VERBOSE\n";
	    print {$newfh} "LoginGraceTime 30\n";
	    print {$newfh} "MaxAuthTries 1\n";
	    print {$newfh} "MaxStartups 3:30:10\n";
	    print {$newfh} "PidFile /var/run/tfremote.pid\n";
	    print {$newfh} "PermitRootLogin no\n";
	    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
		print {$newfh} "RSAAuthentication no\n";
	    }
	    print {$newfh} "PubkeyAuthentication yes\n";
	    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
		print {$newfh} "RhostsRSAAuthentication no\n";
		print {$newfh} "HostBasedAuthentication no\n";
	    }
	    print {$newfh} "IgnoreUserKnownHosts yes\n";
	    print {$newfh} "IgnoreRhosts yes\n";
	    print {$newfh} "PermitEmptyPasswords no\n";
	    print {$newfh} "PasswordAuthentication no\n";
	    print {$newfh} "KerberosAuthentication no\n";
	    print {$newfh} "UsePrivilegeSeparation yes\n";
	    print {$newfh} "GSSAPIAuthentication no\n";
	    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
		print {$newfh} "UsePAM no\n";
	    }
	    print {$newfh} "AllowTcpForwarding yes\n";
	    print {$newfh} "X11Forwarding no\n";
	    print {$newfh} "Banner /etc/motd\n";
	    print {$newfh} "ClientAliveInterval 300\n";
	    print {$newfh} "ClientAliveCountMax 3\n";
	    print {$newfh} "\n";
	    print {$newfh} "\n";

	    close($newfh);

	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");
	}
	else {
	    print "$ml could not open new config file: $new_conf_file\n";
	    $rc = 0;
	}

	close($oldfh);
    }
    else {
	print "$ml could not open existing config file: $conf_file\n";
	$rc = 0;
    }

    return($rc);
}


#
# Create the system service.
# This is basically a clone of "sshd" which runs concurrent to sshd,
# uses the same config files, but is just renamed.  The reason for
# a separate, concurrent process, is to enforce on a "system" level,
# the use of two-factor authentication.
#
# returns
#   1 on success
#   0 if error
#
sub tfrem_install
{
    my $rc = 1;
    my $ml = '[tfrem_install]';

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	if (-e $DEF_TFREMOTE_INIT) {
	    print "$ml $PROGNAME already installed, init file exists: $DEF_TFREMOTE_INIT\n";
	    return(1);
	}
    }
    if ($OS eq 'RHEL7') {
	if (-e $DEF_TFREMOTE_SERVICE) {
	    print "$ml $PROGNAME already installed, service file exists: $DEF_TFREMOTE_SERVICE\n";
	    return(1);
	}
    }

    # return if any required dirs or files were missing.
    if (tfrem_install_verify_files()) {
	print "$ml required files and directories verified\n";
    }
    else {
	print "$ml could not verify required files\n";
	return(0);
    }

    # make the platform specific startup file
    my $ssh_start_file = "";
    my $tfremote_start_file = "";
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	$ssh_start_file = $DEF_SSHD_INIT;
	$tfremote_start_file = $DEF_TFREMOTE_INIT;
    }
    if ($OS eq 'RHEL7') {
	$ssh_start_file = $DEF_SSHD_SERVICE;
	$tfremote_start_file = $DEF_TFREMOTE_SERVICE;
    }
    if (tfrem_install_make_startup_file($ssh_start_file, $tfremote_start_file)) {
	print "$ml new service file: $tfremote_start_file\n";
    }
    else {
	print "$ml could not make new service file: $tfremote_start_file\n";
	return(0);
    }
    if (! -f $tfremote_start_file) {
	print("$ml assert error: tfremote service file ($tfremote_start_file): $!\n");
	return(0);
    }

    # make the priviledge separation directory
    if (-f '/var/empty/sshd') {
	if (! -f '/var/empty/tfremote') {
	    system("mkdir /var/empty/tfremote");
	    system("chmod --reference=/var/empty/sshd /var/empty/tfremote");
	    system("chown --reference=/var/empty/sshd /var/empty/tfremote");
	}
    }

    # make a copy of the sshd binary.
    # Must use a hard link here (not symlink), as, RHEL init.d/functions will
    # wind up killing all "sshd" processes if we use a symlink.
    # Redhat updates should work fine in the event that we use hard links.
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	unlink("/usr/sbin/tfremote");
	system("ln /usr/sbin/sshd /usr/sbin/tfremote");
    }


    # make a tfremote_config file
    my $ssh_config_file = $DEF_SSHD_CONFIG;
    my $tfremote_config_file = $DEF_TFREMOTE_CONFIG;
    if (tfrem_install_make_config_file($ssh_config_file, $tfremote_config_file)) {
	print("$ml new tfremote config file: $tfremote_config_file\n");
    }
    else {
	print("$ml could not make new tfremote config file: $tfremote_config_file\n");
	return(0);
    }
    if (! -f $tfremote_config_file) {
	print("$ml assert error: tfremote config file ($tfremote_config_file): $!\n");
	return(0);
    }

    # make sysconfig conf file to point at the new tfremote config file.
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	my $tfremote_sysconfig_file = '/etc/sysconfig/tfremote';
	if (open(my $newfh, '>', $tfremote_sysconfig_file)) {
	    print {$newfh} "OPTIONS=\"-f $tfremote_config_file\"\n";
	    close($newfh);
	}
	if (! -f $tfremote_sysconfig_file) {
	    print("$ml assert error: tfremote sysconfig file ($tfremote_sysconfig_file): $!\n");
	    return(0);
	}
    }

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	# configure service starts with each reboot
	system("/sbin/chkconfig --add tfremote");
	system("/sbin/chkconfig --level 35 tfremote on");

	# start the service
	system("/sbin/service tfremote start");
    }
    if ($OS eq 'RHEL7') {
	# enable the service
	system("systemctl enable tfremote.service");

	# start the service
	system("systemctl start tfremote.service");
    }

    return(1);
}


#
# Connect to a tfremote server.
#
# Doubles as a "sftp client" to help us connect to sftp.teleflora.com.
# This script is used mainly on our customer service servers to connect
# to customer machines; setting up appropriate security parameters,
# as well as port forwarding rules.
#
sub connect_to_host
{
	my ($hostname) = @_;

	my $localuser = getpwuid($>);
	my $portnum = int(10000 + int($UID));

	if (!defined($hostname)) {
	    return(1);
	}

	# Who is the current user?
	if ($localuser eq "") {
		log_error("Could not determine name of effective user.");
		return (1);
	}

	my $id_dsa = "";
	my $fingerprint = "";
	my %userinfo = get_userinfo($localuser);
	foreach my $thisfile ("tfremote-id_dsa", "tfsupport-id_dsa", "id_dsa") {
	    if (-f "$userinfo{'homedir'}/.ssh/$thisfile") {
		$id_dsa = "$userinfo{'homedir'}/.ssh/$thisfile";
		if (open(my $pipe, '-|', "/usr/bin/md5sum $id_dsa")) {
		    while(<$pipe>) {
			chomp;
			my @md5_output = split(/\s+/);
			if ($#md5_output >= 0) {
			    # index 0 is the md5 checksum
			    $fingerprint .= $md5_output[0];
			}
		    }
		    close($pipe);
		    last;
		}
	    }
	}

	my $remoteuser = "";
	if($id_dsa =~ /tfsupport-id_dsa/) {
	    $remoteuser = "tfsupport";
	} else {
	    $remoteuser = $localuser;
	}

	if ($id_dsa eq "") {
	    log_error("Could not find a DSA SSH Private Key File for $localuser.");
	    return(2);
	}

	unless (-f $id_dsa) {
	    log_error("Could not find DSA SSH Private Key File ($id_dsa) for $localuser.");
	    return(3);
	}


	# Log when we start and end our session, as well as who we are.
	system("/usr/bin/logger \"$localuser:$fingerprint:$$ SSH to $remoteuser\@$hostname\"");

	my $command = "ssh ";
	$command .= " -t";
	$command .= " -o PubKeyAuthentication=yes";
	$command .= " -o PasswordAuthentication=no";
	$command .= " -o GSSAPIAuthentication=no";
	$command .= " -o StrictHostKeyChecking=no";
	$command .= " -o LogLevel=VERBOSE";
	$command .= " -o DynamicForward=$portnum";
	$command .= " -i $id_dsa";
	$command .= " -l $remoteuser";
	$command .= " $hostname";
	$command .= " \"/bin/bash --login\"";


	print("\n");
	print("\n");
	print("Your SOCKS Port is: $portnum\n");
	print("\n");
	print("Suggested Putty configuration:\n");
	print("Connection->SSH->Tunnels->Source port=10000, Destination=localhost:$portnum\n");
	print("\n");
	print("Suggested Firefox configuration:\n");
	print("Manual Proxy Configuration->Host or IP Address=localhost Port=10000\n");
	print("\n");
	print("\n");

	system("$command");
	if ($? == 0) {
	    system("/usr/bin/logger \"$localuser:$fingerprint:$$ LOGOUT from $remoteuser\@$hostname status SUCCESS\"");
	}
	else {
	    system("/usr/bin/logger \"$localuser:$fingerprint:$$ LOGOUT from $remoteuser\@$hostname status FAIL ($?)\"");
	}

	return(0);
}


sub log_error
{
    my ($emsg) = @_;

    system("/usr/bin/logger $emsg");
    return(print("Error: $emsg\n"));
}


__END__

=pod

=head1 NAME

tfremote.pl - script for remote access to a Teleflora POS


=head1 VERSION

This documenation refers to version: $Revision: 1.56 $


=head1 USAGE

tfremote.pl

tfremote.pl B<--version>

tfremote.pl B<--help>

tfremote.pl B<--install>

tfremote.pl B<--start>

tfremote.pl B<--stop>

tfremote.pl B<--status>

tfremote.pl B<--connect=s>


=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--install>

Run only once, installs the F<tfremote.pl> script, the F<tfremote> system service, and
the config file.
Must be root to run this option.

=item B<--connect=s>

This option is used mainly on the Teleflora customer service servers to connect
to customer machines, setting up appropriate security parameters,
as well as port forwarding rules.

=item B<--start>

Starts the F<tfremote> system service.
Must be root to run this option.

=item B<--stop>

Stops the F<tfremote> system service.
Must be root to run this option.

=item B<--status>

Reports the status of the F<tfremote> system service.

=back



=head1 DESCRIPTION

The I<tfremote.pl> script sets up a "parallel" SSHd service called "tfremote".
The only authentication method allowed is "SSH public key".


=head1 FILES

=over 4

=item B</etc/init.d/tfremote>

Only used on RHEL5 and RHEL6, an edited copy of B</etc/init.d/sshd>.

=item B</etc/ssh/tfremote_config>

An edited copy of B</etc/ssh/sshd_config>.

=item B</etc/sysconfig/tfremote>

Only used on RHEL5 and RHEL6, an edited copy of B</etc/sysonfig/sshd>.

=item B</usr/sbin/tfremote>

Only used on RHEL5 and RHEL6, a copy of B</usr/sbin/sshd>.

=item B</etc/systemd/system/tfremote.service>

Only used on RHEL7, the unit service file for the B<tfremote> system service.

=item B</usr/lib/systemd/system/sshd.service>

Only used on RHEL7, the unit service file for the B<sshd> system service.

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status 0 ($EXIT_OK)

Successful completion.

=item Exit status 1 ($EXIT_MUST_BE_ROOT)

For the "--start", "--stop", and "--install" command line options,
the user must be root or running under "sudo".

=item Exit status 2 ($EXIT_COMMAND_LINE)

The command line entered was not recognized.

=item Exit status 3 ($EXIT_PLATFORM)

The operating system was not recognized.

=back


=head1 SEE ALSO

sshd(8), sshd_config(5)


=cut
