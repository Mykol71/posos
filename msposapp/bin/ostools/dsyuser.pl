#!/usr/bin/perl
#
# $Revision: 1.12 $
# Copyright 2008 Teleflora
#
# dsyuser.pl
#
# Script to help Customer Service manage user accounts on
# a daisy system. This script is intended to get the barrage of PA-DSS settings
# "correct" for admin and non-admin users.
#

use strict;
use warnings;
use POSIX;
use Getopt::Long;
use English;
use File::Basename;

use lib qw( /teleflora/ostools/modules /d/ostools/modules /usr2/ostools/modules );
use OSTools::Platform;
use OSTools::Hardware;
use OSTools::AppEnv;
use OSTools::Filesys;


my $CVS_REVISION = '$Revision: 1.12 $';
my $TIMESTAMP = strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($0);

#
# Command line options
#
my $USERNAME = "";
my $ADD = 0;
my $REMOVE = 0;
my $ENABLE_ADMIN = 0;
my $DISABLE_ADMIN = 0;
my $INFO = 0;
my $LIST = 0;
my $PROFILE = 1;
my $RESETPW = 0;
my $EXPIREPW = 0;
my $LOCK = 0;
my $UNLOCK = 0;
my $UPDATE = 0;
my $VERSION = 0;
my $returnval = 0;
my $HELP = 0;


#
# Globals
#
my $OS = plat_os_version();
my $NU_PASSWORD = "";

#
# Constants
#

my $EXIT_OK = 0;
my $EXIT_ERROR = -1;
my $EXIT_COMMAND_LINE = 1;

my $DSY_USER_SHELL = '/d/daisy/bin/dsyshell';
my $DSY_ADMIN_SHELL = '/bin/bash';


GetOptions (
	"add" => \$ADD,
	"enable-admin" => \$ENABLE_ADMIN,
	"disable-admin" => \$DISABLE_ADMIN,
	"remove" => \$REMOVE,
	"info" => \$INFO,
	"list" => \$LIST,
	"profile!" => \$PROFILE,
	"lock" => \$LOCK,
	"unlock" => \$UNLOCK,
	"update" => \$UPDATE,
	"resetpw" => \$RESETPW,
	"expirepw" => \$EXPIREPW,
	"version" => \$VERSION,
	"help" => \$HELP,
);



# --version
if ($VERSION != 0) {
	print "OSTools Version: 1.15.0\n";
	print "$PROGNAME: $CVS_REVISION\n";
	exit(0);
}


# --help
if ($HELP != 0) {
	usage();
	exit(0);
}


sub main
{
	# --list
	if ($LIST != 0) {
	    list_users();
	    exit(0);
	}


	# for all operations after this, root priv is required.
	if ($EUID != 0) {
	    usage();
	    showerror("Error: You must be root (or setuid) to run some subcommands.");
	    exit(3);
	}


	# was a username specified?
	if (defined $ARGV[0]) {
	    $USERNAME = validate_input($ARGV[0]);
	    if ($USERNAME eq "") {
		usage();
		showerror("Error: please specify a valid username.");
		exit(5);
	    }
	}
	else {
	    usage();
	    showerror("Error: username must be specified.");
	    exit(4);
	}

	# was a password specified?
	if (defined $ARGV[1]) {
	    $NU_PASSWORD = validate_input($ARGV[1]);
	    if ($NU_PASSWORD eq "") {
		showerror("Error: Specified password did not pass validation.");
		exit(4);
	    }
	}

	# --add username
	if ($ADD != 0) {
	    if (user_exists("$USERNAME") == 0) {
		# User already exists.
		exec("$0 --update $USERNAME");
	    }
	    else {
		# This is a new user.
		$returnval += add_dsyuser("$USERNAME");
		$returnval += update_dsyuser("$USERNAME");
		$returnval += modify_profile("$USERNAME");
		$returnval += lock_dsyuser("$USERNAME");
	    }

	    exit($returnval);
	}

	# --remove username
	if ($REMOVE != 0) {
	    $returnval = remove_user($USERNAME);
	    exit($returnval);
	}

	# --update username
	if ($UPDATE != 0) {
	    if (user_exists("$USERNAME") == 0) {
		# Note, do not automatically 'unlock' a user here;
		# we could call "update" on a locked out user during a patch upgrade.
		$returnval += update_dsyuser($USERNAME);
		$returnval += modify_profile("$USERNAME");
	    }
	    else {
		showerror("Error: User \"$USERNAME\" does not exist.\n");
		$returnval = 1;
	    }

	    exit($returnval);
	}

	# --resetpw username
	if ($RESETPW != 0) {
	    my $nupasswd = "";

	    # Was a password specified?
	    if (defined $ARGV[1]) {
		$nupasswd = $ARGV[1];
	    }

	    if (user_exists("$USERNAME") == 0) {
		$returnval += update_dsyuser($USERNAME);
		$returnval += unlock_user($USERNAME);
		$returnval += reset_password("$USERNAME", $NU_PASSWORD);
	    }
	    else {
		showerror("Error: User \"$USERNAME\" Does not exist.\n");
		$returnval = 1;
	    }

	    exit($returnval);
	}


	# --enable-admin username
	if ($ENABLE_ADMIN != 0) {

	    if ($USERNAME eq "daisy") {
		showerror("Error: --enable-admin not allowed for \"$USERNAME\".\n");
		$returnval = 1;

	    }
	    elsif (user_exists("$USERNAME") == 0) {
		$returnval += enable_dsyadmin($USERNAME);
		$returnval += update_dsyuser("$USERNAME");
		$returnval += modify_profile("$USERNAME");
		if ( ($USERNAME ne "root") && ($USERNAME ne "tfsupport") ) {
		    $returnval += reset_password($USERNAME, $NU_PASSWORD);
		}

	    }
	    else {
		showerror("Error: User \"$USERNAME\" does not exist.\n");
		$returnval = 1;
	    }

	    exit($returnval);
	}

	# --disable-admin username
	if ($DISABLE_ADMIN != 0) {
	    if (user_exists("$USERNAME") == 0) {
		$returnval += disable_dsyadmin("$USERNAME");
		$returnval += update_dsyuser("$USERNAME");
		$returnval += modify_profile("$USERNAME");
	    }
	    else {
		showerror("Error: User \"$USERNAME\" does not exist.\n");
		$returnval = 1;
	    }

	    exit($returnval);
	}

	# --info username
	if ($INFO != 0) {
	    user_info($USERNAME);
	    exit(0);
	}


	# --lock username
	if ($LOCK != 0) {
	    $returnval = lock_dsyuser($USERNAME);
	    exit($returnval);
	}

	# --unlock username
	if ($UNLOCK != 0) {
	    $returnval = unlock_user($USERNAME);
	    exit($returnval);
	}

	# --expire username
	if ($EXPIREPW != 0) {
	    $returnval = expire_pw($USERNAME);
	    exit($returnval);
	}
}


##########################################################
##########################################################
##########################################################


sub usage
{

	print "Usage:\n";
	print "$PROGNAME $CVS_REVISION\n";
	print "$PROGNAME --help\n";
	print "$PROGNAME --version\n";
	print "\n";
	print "$PROGNAME --list                    # List current daisy users and admins.\n";
	print "$PROGNAME --info username           # Get information about specified user.\n";
	print "\n";
	print "$PROGNAME --add username            # Add a new user to the system.\n";
	print "$PROGNAME --remove username         # Remove a user from the system.\n";
	print "$PROGNAME --update username         # Update user settings; Reset User Password.\n";
	print "\n";
	print "$PROGNAME --lock username           # Disable (but do not remove) user's account.\n";
	print "$PROGNAME --unlock username         # Enable a user's account. Do not modify password.\n";
	print "$PROGNAME --resetpw username        # Reset a user's password\n";
	print "$PROGNAME --expirepw username       # Expire a user's password\n";
	print "\n";
	print "$PROGNAME --enable-admin username   # Give User 'admin' privileges to daisy app.\n";
	print "$PROGNAME --disable-admin username  # Remove 'admin' privileges for a user.\n";
	print "\n";

	return "";
}


sub is_primary_group
{
    my ($group, $username) = @_;

    my $gid = -1;
    my $pri_group_name = "";

    # first, find the passwd file entry for user account
    setpwent();
    my @ent = getpwent();
    while (@ent) {
	if ($username eq $ent[0]) {
	    $gid = $ent[3];
	    last;
	}
	@ent = getpwent();
    }
    endpwent();
 
    # if user account was found, lookup name of primary group
    unless ($gid == -1) {
	$pri_group_name = getgrgid($gid);
    }

    # now compare primary group name to supplied group name
    my $return_val = ($group eq $pri_group_name) ? 1 : 0;

    return($return_val);
}


#
# Add a new user account.
# Note that this sub need be non-interactive, as, it is performed during install time.
#
sub add_dsyuser
{
	my $username = $_[0];
	my $returnval = 0;
	my %userinfo = ();

	if ($username eq "") {
	    return(-1);
	}

	if ($username eq "root") {
	    showerror("Error: Will not make account for the 'root' user.");
	    return(-1);
	}


	# Make sure the 'daisy' system group exists *before* creating the user,
	# since all daisy users will be a member of this group.
	add_dsy_groups();


	# If the user doesn't already exist, create it.
	$returnval = user_exists($username);
	if ($returnval != 0) {
	    showerror("Adding Daisy user account: $username");
	    my $name_opt = "-c \'Daisy User Account\'";
	    my $shell_opt = "-s /d/daisy/bin/dsyshell";
	    my $useradd_cmd = "/usr/sbin/useradd";
	    system "sudo $useradd_cmd $name_opt $shell_opt -g daisy -G 'daisy' $username";

	    # Make sure the Daisy user account was actually added.
	    $returnval = user_exists($username);
	    if ($returnval != 0) {
		showerror("Error: Can't add Daisy user account: $username");
	    }
	    else {

		# We should not have to do this, but, we do under RHEL4 for reasons
		# that are unexplained: the user's home directory is being created
		# with ownership of the sudoer so it must be corrected.
		unless ($OS eq "RHEL5" || $OS eq "RHEL6" || $OS eq "RHEL7") {
		    system("chown $username ~$username");
		}

		# make a mail box file if necessary
		unless ($OS eq "RHEL5" || $OS eq "RHEL6" || $OS eq "RHEL7") {
		    my $mail_spool_dir = "/var/spool/mail";
		    my $mbox_path = "$mail_spool_dir/$username";
		    unless (-e "$mbox_path") {
			system("touch $mbox_path");
		    }
		    system("chown $username $mbox_path");
		}
	    }
	}
	else {
	    showerror("Daisy user account already exists: $username");
	    disable_dsyadmin("$username");
	}

	return($returnval);
}



# Remove a daisy user account from the system.
sub remove_user
{
	my $username = $_[0];
	my %userinfo = ();


	if ($username eq "") {
	    print("Please specify a user to remove.");
	    return(-1);
	}


	%userinfo = get_userinfo($username);

	if ($username eq "root") {
	    showerror("Error: Will not remove 'root' user with this utility.");
	    return(-2);
	}
	if (! %userinfo) {
	    showerror("Error: user account does not exist: $username");
	    return(-1);
	}

	# Only remove users who are in the 'daisy' group.
	if (! defined grep(/^daisy$/, @{$userinfo{'groups'}})) {
	    showerror("Error: user account is not a Daisy user: $username");
	    showerror("Please use system utilities to remove this user.");
	    return(-2);
	}


	showerror("Removing User Account \"$username\"");
	system("sudo /usr/sbin/userdel -r $username");

	return(0);
}



#
# Used primarily during install/upgrade script to bring this user "up-to-date" with current
# security settings. Things such as .bash_profiles, chage settings, unix groups, and whatnot.
# Intended to be run against an existing user without making changes which are notably visible to 
# the user (such as requiring a password change).
#
sub update_dsyuser
{
	my $username = $_[0];
	my %userinfo = ();
	my $returnval = 0;
	my $date = "";

	if ($username eq "") {
	    return(-1);
	}

	# handle special case caused by FC5 "golden master" configuration:
	# the "lp" user and the "games" user are configured as
	# members of the "daisy" group but we don't want to allow
	# them to become actual daisy users.
	if ($username eq 'lp' || $username eq 'games') {
	    logerror("Can't update non-Daisy user accounts: $username");
	    return 0;
	}

	# Make sure the 'daisy' unix group exists *before* creating our user,
	# as, all daisy users will be a member of this group.
	add_dsy_groups();

	# If the user doesn't already exist, report error to user.
	%userinfo = get_userinfo($username);
	if (! %userinfo) {
	    showerror("User account does not exist: $username");
	    return(-3);
	}
	else {
	    showerror("Updating user account: $username");
	}

	#
	# In the case of linux, certain hardware devices (/dev/ttySx /dev/lp0, /dev/fd0) are 
	# all writable by users who are members of certain groups. Here, we add our user to said
	# groups.
	#
	append_usergroup("daisy", $username);
	append_usergroup("floppy", $username); # Wire Service Reconciliation.
	append_usergroup("lp", $username); # Printing Reports.
	if ($OS eq 'RHEL5' || $OS eq 'RHEL6') {
	    append_usergroup("uucp", $username); # Dove Modems
	}
	append_usergroup("lock", $username); # Dove Modems (Lockfiles)
	my $primary_group_name = "daisy";
	unless (is_primary_group($primary_group_name, $username)) {
	    system ("sudo /usr/sbin/usermod -g $primary_group_name $username");
	}

	#
	# All of these settings pertain to being a daisy administrator
	#
	if (grep(/dsyadmins/, @{$userinfo{'groups'}})) {

	    # PCI 8.5.9
	    # Maximum number of days until password must be changed.
	    if ( ($username ne "root") &&  ($username ne "tfsupport") ) {
		system("sudo /usr/bin/chage -M 90 $username");
		system("sudo /usr/bin/chage -W 7 $username");
	    }

	    # PCI 8.5.5
	    # Number of days after password has expired and which
	    # the user has not attempted login, before the account is automatically
	    # locked.
	    #
	    # Since PCI 8.5.5 can technically be enforced via policy (and not hard and
	    # fast rules like this). We will not enforce the rules for 'root' and 'tfsupport'.
	    # Doing so could result in being unable to login to the system as 'root' or
	    # 'tfsupport' which could make the server unmanageable, as well as cause
	    # unexpected crontab outages.
	    #
	    if ( ($username ne "root") && ($username ne "tfsupport") ) {
		system("sudo /usr/bin/chage -I 90 $username");
	    }
	    else {
		system("sudo /usr/bin/chage -I -1 $username");
	    }

	    # PCI 8.5.13
	    # Limit repeated access attempts by locking out the user ID
	    # after not more than six attempts.
	    #
	    # If "/sbin/pam_tally2" is present on the system, then the
	    # "harden_linux.pl" script would have chosen it for use in
	    # /etc/pam.d/system-auth and thus the corresponding program
	    # must be chosen here.  So for pre-RHEL5, use "faillog" and
	    # for RHEL5 and RHEL6, the "pam_tally2" program does not
	    # handle configuring lock out counts.
	    unless (-f "/sbin/pam_tally2") {
		system("sudo /usr/bin/faillog -u $username -m 6");
	    }


	    #
	    # Change the shell to the Bash shell.
	    #
	    unless ($userinfo{'shell'} eq $DSY_ADMIN_SHELL) {
		system("chsh -s $DSY_ADMIN_SHELL $username");
	    }

	}
	else {
	    # For Non-Admins.
	    # Undo PCI related password enforcements changes.
	    system("sudo /usr/bin/chage -M -1 $username");
	    system("sudo /usr/bin/chage -I -1 $username");

	    # See notes above about "pam_tally2" vs "faillog".
	    if (-f "/sbin/pam_tally2") {
		system("sudo /sbin/pam_tally2 --user $username --reset --quiet");
	    }
	    else {
		system("sudo /usr/bin/faillog -u $username -m 0");
	    }

	    #
	    # Change the shell to the Daisy shell if necessary.
	    #
	    if ($username ne "root") {
		unless ($userinfo{'shell'} eq $DSY_USER_SHELL) {
		    system("chsh -s $DSY_USER_SHELL $username");
		}
	    }
	}

	return(0);
}




#
# Add the 'daisy' group and the 'dsyadmins' group, if need be.
# Also, create the faillog log if it doesn't exist.
#
sub add_dsy_groups
{

	# Add our daisy related unix groups.
	system "sudo /usr/sbin/groupadd daisy > /dev/null 2> /dev/null";
	system "sudo /usr/sbin/groupadd dsyadmins > /dev/null 2> /dev/null";
	unless (-f "/sbin/pam_tally2") {
	    unless (-e "/var/log/faillog") {
		system "touch /var/log/faillog > /dev/null 2> /dev/null";
	    }
	}

	return $?
}


#
# Add the 'tfremote' group, if need be.
#
sub add_tfremote_group
{

	system("sudo /usr/sbin/groupadd tfremote > /dev/null 2> /dev/null");

	return $?
}




#
# Change appropriate settings for a daisy administrator.
#
sub enable_dsyadmin
{
	my $username = $_[0];

	if($username eq "") {
		return(-1);
	}

	if(user_exists($username) != 0) {
		showerror("User \"$username\" does not exist. Please use --add first.");
		return(-2);
	}

	# Make sure "daisy" group exists.
	add_dsy_groups();

	showerror("Setting \"$username\" as a daisy Administrator");
	append_usergroup("dsyadmins", $username);

	return 0;
}



#
# Remove administrative privileges from a daisy user.
#
sub disable_dsyadmin
{
	my $username = $_[0];
	my %userinfo = ();

	if($username eq "") {
		return(-1);
	}


	%userinfo = get_userinfo($username);
	if(! %userinfo) {
		showerror("User \"$username\" is not a daisy user. Please use --add first.");
		return(-2);
	}
	if(! grep(/dsyadmins/, @{$userinfo{'groups'}})) {
		showerror("User \"$username\" is not a daisy Admin. Cannot disable.");
		return(0);
	}


	# Re-add user to all groups *except* dsyadmins.
	showerror("Removing Administrative Privileges for \"$username\".");
	if($username ne "root") {
		remove_usergroup("dsyadmins", $username);
	}


	return(0);
}


#
# Modify .bash_profile to ensure we are only executing daisy.
# We want this for "daisy" users, but not necessarily for "root" or "tfsupport".
#
sub modify_profile
{
	my $username = $_[0];
	my %userinfo = ();


	# We have been requested to not modify profiles.
	if($PROFILE == 0) {
		showerror("Warning: Skipping modification of .bash_profile due to user request.");
		return(0);
	}

	# Get the full path for this user's home directory.
	%userinfo = get_userinfo($username);

	if ($username eq "root") {
		showerror("Warning: Skipping modification of .bash_profile for user $username.");
		return(0);
	}
	
	# Remove any existing symlinks.
	if(-l "$userinfo{'homedir'}/.bash_profile") {
		system("sudo rm -f $userinfo{'homedir'}/.bash_profile");
	}
	if(-l "$userinfo{'homedir'}/.profile") {
		system("sudo rm -f $userinfo{'homedir'}/.profile");
	}

	# Move the old startup files out of the way.
	my $timestamp = strftime("%Y-%m-%d_%H%M%S", localtime());
	if(-f "$userinfo{'homedir'}/.profile") {
		system "sudo mv $userinfo{'homedir'}/.profile $userinfo{'homedir'}/.profile-$timestamp";
	}
	if(-f "$userinfo{'homedir'}/.bash_profile") {
		system "sudo mv $userinfo{'homedir'}/.bash_profile $userinfo{'homedir'}/.bash_profile-$timestamp";
	}
	if(-f "$userinfo{'homedir'}/.bash_logout") {
		system "sudo mv $userinfo{'homedir'}/.bash_logout $userinfo{'homedir'}/.bash_logout-$timestamp";
	}

	# Make a new .bash_profile
	open(FILE, "> $userinfo{'homedir'}/.bash_profile");
	print(FILE << 'EOF');
#
# Daisy User Login Script
# Copyright 2009 Teleflora
#

# PCI 10.x
# Log what the user does.
#
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "
export HISTTIMEFORMAT

DSYUSER=0
DSYADMIN=0
groups | grep dsyadmins > /dev/null 2> /dev/null
if [ $? == 0 ] ; then
	DSYADMIN=1
else
	DSYUSER=1
fi

# Administrators use a stricter set of rules.
if [ $DSYADMIN == 1 ] ; then
	PATH=/sbin:/usr/sbin:$PATH
	export PATH
	export TMOUT=900
fi

umask 0002
alias l="ls -l"

# Setup environment variables for running daisy.
if [ -f /etc/profile.d/daisy.sh ]
then
. /etc/profile.d/daisy.sh
fi
if [ $DSYADMIN == 1 ]; then
	if [ -n "$TERM" ]
	then
		if [ -s /d/daisy/bin/tfsupport.pl ]
		then
			if [ -x /d/daisy/bin/tfsupport.pl ]
			then
				exec /d/daisy/bin/tfsupport.pl
			else
				echo "/d/daisy/bin/tfsupport.pl not executable"
			fi
		else
			echo "/d/daisy/bin/tfsupport.pl does not exist"
		fi
	else
		echo "TERM env var not set"
	fi
fi
EOF
	close(FILE);


	# Make a new .bash_logout
	open(FILE, "> $userinfo{'homedir'}/.bash_logout");
	print(FILE << 'EOF');
#!/bin/bash
/usr/bin/sudo -k
EOF
	close(FILE);


	# User's should not own their own .bash_profile, thus preventing them from
	# insecure modifications.
	if(-f "$userinfo{'homedir'}/.bash_profile") {
		system "sudo chown tfsupport $userinfo{'homedir'}/.bash_profile";
		system "sudo chgrp dsyadmins $userinfo{'homedir'}/.bash_profile";
		system "sudo chmod 575 $userinfo{'homedir'}/.bash_profile";
	}

	if(-f "$userinfo{'homedir'}/.forward") {
		system "sudo chown tfsupport $userinfo{'homedir'}/.forward";
		system "sudo chgrp dsyadmins $userinfo{'homedir'}/.forward";
		system "sudo chmod 575 $userinfo{'homedir'}/.forward";
	}

	if(-f "$userinfo{'homedir'}/.rhosts") {
                system "sudo chown daisy $userinfo{'homedir'}/.rhosts";
                system "sudo chgrp daisy $userinfo{'homedir'}/.rhosts";
                system "sudo chmod 644 $userinfo{'homedir'}/.rhosts";
        }

	return(0);
}



#
# Sets password rules into place.
# Actually prompts for a new password if the "change_now" parameter is non-zero.
#
sub reset_password
{
	my $username = $_[0];
	my $nupasswd = $_[1];

	my $returnval = 0;
	my %userinfo = ();


	if($username eq "") {
		return(-1);
	}

	%userinfo = get_userinfo($username);
	if(! %userinfo) {
		showerror("Cannot Change Password for user \"$username\". User Not Found.");
		return(-2);
	}

	#
	# Note that we don't want sudo prompting for a password just before "passwd"
	# prompts for the new user's password. This opens us to a lot of risk of the
	# admin placing the administrator's password as the new user's password.
	# So here, if we are not already root, then, request such.
	#
	if($EUID != 0) {
		showerror("Invalid Permissions. Please run this command as 'sudo'.");
		return(-3);
	}

	# Actually change the password here.
	if ($nupasswd) {
		system "echo $nupasswd | sudo /usr/bin/passwd --stdin $username";
	} else {
		system "sudo /usr/bin/passwd $username";
	}


	# The password we set for members of the "dsyadmins" group and
	# for the "root" account should be a one-time password.
	if ( grep(/dsyadmins/, @{$userinfo{'groups'}}) ||
	    ($userinfo{'username'} eq "root") ) {
		# PCI 8.5.3
		# Set first-time passwords to a unique value for each user and
		# change immediately after the first use.
		showerror("Setting this as a 'one-time' password.");
		system "sudo /usr/sbin/usermod -L $username";
		system "sudo chage -d 0 $username";
		system "sudo /usr/sbin/usermod -U $username";
	}


	return $returnval;
}


#
# Render a user "unusable"
# by locking password, and/or other techniques.
#
sub lock_dsyuser
{
	my $username = $_[0];
	my $returnval = 0;

	if($username eq "root") {
		showerror("Will not lock root user account.");
		return(-2);
	}
	showerror("Locking access to \"$username\" Account.");

	if(user_exists($username) != 0) {
		return(-3);
	}


	if($username ne "root") {
		system("sudo /usr/bin/passwd -l $username");
		$returnval = $?;
	}


	return $returnval;
}



#
# Undo what we did with "lock_dsyuser()
#
sub unlock_user
{
	my $username = $_[0];
	my $returnval = 0;

	if($username eq "") {
		return(-1);
	}


	if(user_exists($username) != 0) {
		showerror("Invalid user \"$username\". Could not unlock.");
		return(-2);
	}


	showerror("Unlocking access to \"$username\" Account.");


	system "sudo /usr/bin/passwd -f -u $username";
	if (-f "/sbin/pam_tally2") {
		system "sudo /sbin/pam_tally2 --reset --user $username";
	}
	elsif (-f "/sbin/pam_tally") {
		system "sudo /sbin/pam_tally --reset --user $username";
	}
	else {
		system "sudo /usr/bin/faillog -u $username -r";
	}


	return $returnval;
}



#
# Expire the password of any existing user - including "root".
#
sub expire_pw
{
	my $username = $_[0];
	my $returnval = 0;

	if ($username eq "") {
		return(-1);
	}

	if (user_exists($username) != 0) {
		showerror("Invalid user \"$username\". Could not expire password.");
		return(-2);
	}

	showerror("Expiring password for \"$username\" Account.");

	system("sudo /usr/bin/chage -d 0 $username");
	$returnval = $?;

	return $returnval;
}


sub user_info
{
	my $user = $_[0];
	my %hash;
	%hash = get_userinfo($user);


	print "User: $user\n";
	print "\tHome Directory: $hash{'homedir'}\n";
	print "\tGroups: @{$hash{'groups'}}\n";
	print "\n";

	# Password expiration times.
	system("chage -l $user");
	print "\n";

	# Is user unlocked?
	if (-f "/sbin/pam_tally2") {
	    system("/sbin/pam_tally2 --user $user");
	}
	else {
	    system("/usr/bin/faillog -u $user");
	}
}




#
# RHEL 5, and later versions of RHEL 4 support "appending" group memberships.
# However, early (initial release) versions of RHEL4 do not support "-a".
# This is a sort of 'hand rolled' "append" flag.
#
# Yes, this is pretty inefficient, but then it's not used very often either.
#
sub append_usergroup
{
	my $newgroup = $_[0];
	my $username = $_[1];
	my $line = "";


	if($newgroup eq "") {
		return(-1);
	}
	if($username eq "") {
		return(-2);
	}



	# Get a list of current groups.
	open(PIPE, "groups $username |");
	$line = <PIPE>;
	close(PIPE);

	# "root : root foo bar fee" -> "root foo bar fee"
	$line =~ s/^([[:print:]]+)(:\s+)([[:print:]]+)/$3/g;

	# We are already a member of this group.
	if($line =~ /(\s+)($newgroup)/) {
		return;
	}

	# "root foo bar fee" -> "root foo bar fee baz"
	$line .= " $newgroup";

	# "root foo bar fee baz" -> "root,foo,bar,fee,baz"
	$line =~ s/(\s+)/,/g;


	# Actually set groups here.
	system("/usr/sbin/usermod -G \"$line\" $username");


	return;
}



sub remove_usergroup
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

	system("/usr/sbin/usermod -G \"$line\" $username");
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
	my %hash = ();
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
	#
	# Note: the $members value is a SPACE separated list
	#
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

#
# Does a user already exist? 
# Return 0 if user exists
# Return > 0 if user does not exist, or error.
# Return < 0 if error.
#
sub user_exists
{
	my $username = $_[0];
	my %userinfo = ();

	if(! $username) {
		return(-1);
	}
	if("$username" eq "") {
		return(-2);
	}


	%userinfo = get_userinfo($username);
	if(! %userinfo) {
		return(1);
	}

	return(0);
}

sub list_users
{
	my @users = ();
	my @admins = ();
	my @remotes = ();
	my @pwent = ();
	my @entry = ();
	my $usergid = "";
	my $admingid = "";
	my $remotegid = "";
	my $username = "";
	my $group = "";
	my $is_dsyadmin = "";
	my $is_tfremote = "";



	# Get a list of all users in the "daisy" group, the "dsyadmins" group and
	# the "tfremote" group.
	@entry = getgrent();
	while(@entry) {
		if($entry[0] eq "daisy") {
			$usergid = $entry[2];
			foreach $username (split /\s+/, $entry[3]) {
				push(@users, $username);
			}
		}
		if($entry[0] eq "dsyadmins") {
			$admingid = $entry[2];
			foreach $username (split /\s+/, $entry[3]) {
				push(@admins, $username);
			}
		}
		if($entry[0] eq "tfremote") {
			$remotegid = $entry[2];
			foreach $username (split /\s+/, $entry[3]) {
				push(@remotes, $username);
			}
		}

		@entry = getgrent();
	}
	endgrent();


	# Step through each user on the box, are they a member of either "admins" or the "daisy" group?
	# Note that the "primary gid" of the user is not reflected in our above step through "getgrent()"
	@entry = getpwent();
	while(@entry) {
		$username = $entry[0];
		$group = $entry[3]; 

		if( ("$group" eq "$usergid") 
		  &&(! grep(/^$username$/, @users)) ) {
			push(@users, $username);
		}

		if( ("$group" eq "$admingid") 
		&&  (! grep(/^$username$/, @admins)) ) {
			push(@admins, $username);
		}

		if( ("$group" eq "$remotegid") 
		&&  (! grep(/^$username$/, @remotes)) ) {
			push(@remotes, $username);
		}

		@entry = getpwent();
	}
	endpwent();


	foreach $username (@users)
	{
		# handle special case caused by FC5 "golden master" configuration:
		# the "lp" user and the "games" user are configured as
		# members of the "daisy" group but we don't want to list
		# them as such.
		if ($username eq 'lp' || $username eq 'games') {
			logerror("--list of $username suppressed");
			next;
		}

		$is_dsyadmin = "";
		$is_tfremote = "";
		if(grep(/^$username$/, @admins)) {
			$is_dsyadmin = "(Daisy Admin)";
		}
		if(grep(/^$username$/, @remotes)) {
			$is_tfremote = "(TFRemote)";
		}

		printf("%-20s %-12s %-12s %-12s\n", $username, "(Daisy User)", $is_dsyadmin, $is_tfremote);
	}

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
# An error which is reported both to the user, and to syslogs.
#
sub showerror
{
	my $message = $_[0];

	logerror($message);
	print("$message\n");
}


sub logerror
{
	my $message = $_[0];
	system("/usr/bin/logger -i -t \"$UID-dsyuser\.pl \" -- \"$message\"");
}


exit(main());


__END__

=pod

=head1 NAME

dsyuser.pl - manage Daisy user and Daisy admin accounts


=head1 VERSION

This documenation refers to version: $Revision: 1.12 $


=head1 USAGE

dsyuser.pl

dsyuser.pl B<--version>

dsyuser.pl B<--help>

dsyuser.pl B<--add>

dsyuser.pl B<--enable-admin>

dsyuser.pl B<--disable-admin>

dsyuser.pl B<--remove>

dsyuser.pl B<--info>

dsyuser.pl B<--list>

dsyuser.pl B<--profile>

dsyuser.pl B<--lock>

dsyuser.pl B<--unlock>

dsyuser.pl B<--update>

dsyuser.pl B<--resetpw>

dsyuser.pl B<--expirepw>


=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--add>

Add a new Daisy user account.

=back


=head1 DESCRIPTION

This script performs all operations to manage Daisy user accounts and
Daisy admin accounts.
It should be used in lieu of other interfaces because it ensures that
operations conform to the applicable security policies with regard
to accounts on a Daisy system.

When adding a new C<daisy> user via C<--add username> option,
the new account will also be added to the following system groups:

=over

=item C<daisy>

=item C<floppy>

=item C<lp>

=item C<lock>

=back

On C<RHEL5> and C<RHEL6>, it will also be added to the C<uucp> group.


=head1 FILES

=over 4

=item B<~/.bash_profile>

Upon addition of every a Daisy account, whether a user account or
an admin account, a new B<~/.bash_profile> file is generated.

=item B</var/log/messages>

The log file that all log messages are written to.

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status 0

Successful completion or when the "--version" and "--help"
command line options are specified.

=back


=head1 SEE ALSO

B<dsyperms.pl>


=cut
