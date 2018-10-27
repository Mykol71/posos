#!/usr/bin/perl
#
# $Revision: 1.13 $
# Copyright 2008-2011 Teleflora
#
# rtiuser.pl
#
# Script to help RTI Customer Service manage user accounts on
# an RTI system. This script is intended to get the barrage of PA-DSS settings
# "correct" for admin and non-admin users.
#

use strict;
use warnings;
use POSIX;
use Getopt::Long;
use English;
use File::Basename;


my $CVS_REVISION = '$Revision: 1.13 $';
my $TIMESTAMP = strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($0);

my $USERNAME = "";
my $ADD = 0;
my $REMOVE = 0;
my $ENABLE_ADMIN = 0;
my $DISABLE_ADMIN = 0;
my $INFO = 0;
my $LIST = 0;
my $PROFILE = 1;
my $RESETPW = 0;
my $LOCK = 0;
my $UNLOCK = 0;
my $UPDATE = 0;
my $SSHKEY = "";
my $VERSION = 0;
my $returnval = 0;
my $HELP = 0;
my $NU_PASSWORD = "";


sub usage
{
	print("$PROGNAME $CVS_REVISION\n");
	print "Usage:\n";
	print "$PROGNAME --help\n";
	print "$PROGNAME --version\n";
	print "\n";
	print "$PROGNAME --list              # List current RTI users and admins.\n";
	print "$PROGNAME --info username     # Get information about specified user.\n";
	print "\n";
	print "$PROGNAME --add username      # Add a new user to the system.\n";
	print "$PROGNAME --remove username   # Remove a user from the system.\n";
	print "$PROGNAME --update username   # Update user settings.\n";
	print "\n";
	print "$PROGNAME --lock username     # Disable (but do not remove) user's account.\n";
	print "$PROGNAME --unlock username   # Enable a user's account. Do not modify password.\n";
	print "$PROGNAME --resetpw username [password]      # Reset a user's password\n";
	print "\n";
	print "$PROGNAME --enable-admin username [password] # Grant user 'admin' privileges\n";
	print "$PROGNAME --disable-admin username           # Remove 'admin' privileges\n";
	print "$PROGNAME --sshkey /path/to/pubkey username  # Set \"pubkey\" in \"username's\" SSH authorized keys.\n";
	print "\n";

	return "";
}






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
	"sshkey=s" => \$SSHKEY,
	"version" => \$VERSION,
	"help" => \$HELP,
) || die "Error: invalid command line option, exiting...\n";



# --version
if($VERSION != 0) {
	print "OSTools Version: 1.15.0\n";
	print "$PROGNAME: $CVS_REVISION\n";
	exit(0);
}


# --help
if($HELP != 0) {
	usage();
	exit(0);
}


# --list
if($LIST != 0) {
	list_users();
	exit(0);
}


# Are we root?
if($EUID != 0) {
	usage();
	showerror("Error: You must be root (or setuid) to run some subcommands.");
	exit(2);
}


# Did we specify a username?
unless (defined $ARGV[0]) {
	usage();
	showerror("Error: Please specify a username.");
	exit(1);
}

$SSHKEY = validate_input($SSHKEY);

$USERNAME = validate_input($ARGV[0]);
if ($USERNAME eq "") {
	usage();
	showerror("Error: Specified username did not pass validation.");
	exit(3);
}

# Did we specify a password?
if (defined $ARGV[1]) {
	$NU_PASSWORD = validate_input($ARGV[1]);
	if ($NU_PASSWORD eq "") {
	    showerror("Error: Specified password did not pass validation.");
	    exit(4);
	}
}


# --add username
if($ADD != 0) {
	if(user_exists("$USERNAME") == 0) {
		# User already exists.
		exec("$0 --update $USERNAME");
	} else {
		# This is a new user.
		$returnval += add_rtiuser("$USERNAME");
		$returnval += update_rtiuser("$USERNAME");
		$returnval += modify_profile("$USERNAME");
		$returnval += lock_rtiuser("$USERNAME");
	}

	exit($returnval);
}

# --remove username
if ($REMOVE != 0) {
	$returnval = remove_user($USERNAME);
	exit($returnval);
}

# --update
if($UPDATE != 0) {
	if(user_exists("$USERNAME") == 0) {
		# Note, do not automatically 'unlock' a user here;
		# we could call "update" on a locked out user during a patch upgrade.
		$returnval += update_rtiuser($USERNAME);
		$returnval += modify_profile("$USERNAME");
	} else {
		showerror("Error: User \"$USERNAME\" does not exist.\n");
		$returnval = 1;
	}

	exit($returnval);
}

# --resetpw
if($RESETPW != 0) {
	if(user_exists("$USERNAME") == 0) {
		$returnval += update_rtiuser($USERNAME);
		$returnval += unlock_user($USERNAME);
		$returnval += reset_password("$USERNAME", $NU_PASSWORD);
	} else {
		showerror("Error: User \"$USERNAME\" Does not exist.\n");
		$returnval = 1;
	}

	exit($returnval);
}

# --sshkey
if($SSHKEY ne "") {
	if(user_exists("$USERNAME") == 0) {
		$returnval = update_sshkey($USERNAME, $SSHKEY);
	} else {
		showerror("Error: User \"$USERNAME\" Does not exist.\n");
		$returnval = 1;
	}

	exit($returnval);
}

# --enable-admin username
if ($ENABLE_ADMIN != 0) {

	if ($USERNAME eq "rti") {
		showerror("Error: --enable-admin not allowed for \"$USERNAME\".\n");
		$returnval = 1;
	}

	elsif (user_exists("$USERNAME") == 0) {
		$returnval += enable_rtiadmin($USERNAME);
		$returnval += update_rtiuser("$USERNAME");
		$returnval += modify_profile("$USERNAME");
		if( ($USERNAME ne "root") &&  ($USERNAME ne "tfsupport") ) {
			$returnval += reset_password("$USERNAME", $NU_PASSWORD);
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
	if(user_exists("$USERNAME") == 0) {
		$returnval += disable_rtiadmin("$USERNAME");
		$returnval += update_rtiuser("$USERNAME");
		$returnval += modify_profile("$USERNAME");
	} else {
		showerror("Error: User \"$USERNAME\" does not exist.\n");
		$returnval = 1;
	}
	exit($returnval);
}

# --info
if ($INFO != 0) {
	user_info($USERNAME);
	exit(0);
}


# --lock
if ($LOCK != 0) {
	$returnval = lock_rtiuser($USERNAME);
	exit($returnval);
}

# --unlock
if ($UNLOCK != 0) {
	$returnval = unlock_user($USERNAME);
	exit($returnval);
}



exit(0);

##########################################################
##########################################################
##########################################################


#
# Add a new user account.
# Note that this sub need be non-interactive, as, it is performed during install time.
#
sub add_rtiuser
{
	my $username = $_[0];
	my $returnval = 0;
	my %userinfo = ();

	if($username eq "") {
		return(-1);
	}

	if($username eq "root") {
		showerror("Error: Will not create the 'root' user. If you need to do this, you have bigger problems at hand.");
		return(-1);
	}


	# Make sure the 'rti' unix group exists *before* creating our user,
	# as, all RTI users will be a member of this group.
	add_rti_groups();


	# If the user doesn't already exist, create it.
	if(user_exists($username) != 0) {
		showerror("Creating User \"$username\"");

		# homedir of the RTI user "kiosk" is in a special location
		my $homedir = "";
		if ($username eq "kiosk") {
		    $homedir = "--home /usr2/bbx/kiosk/work";
		}
		system "sudo /usr/sbin/useradd -c 'RTI User Account' -g rti -G 'rti' $homedir $username";

		# Make sure we actually created our user account.
		if(user_exists($username) != 0) {
			showerror("Error: Could not create user \"$username\"");
			return $?
		}

		# We should not have to do this, but, we do under RHEL4 for reasons I cannot explain.
		# The user's home directory is being created with ownership of the sudoer.
		system("chown $username ~$username");
		system("touch /var/spool/mail/$username");
		system("chown $username /var/spool/mail/$username");

	} else {
		showerror("User \"$username\" already exists.");
		disable_rtiadmin("$username");
	}


	return $returnval;
}



# Remove an RTI user account from the system.
sub remove_user
{
	my $username = $_[0];
	my %userinfo = ();


	if($username eq "") {
		print("Please specify a user to remove.");
		return(-1);
	}


	%userinfo = get_userinfo($username);

	if($username eq "root") {
		showerror("Error: Will not remove 'root' user with this utility.\n");
		return(-2);
	}
	if(! %userinfo) {
		showerror("Error: User \"$username\" does not exist. Unable to remove user.");
		return(-1);
	}

	# Only remove users who are in the 'rti' group.
	if(! defined grep(/^rti$/, @{$userinfo{'groups'}})) {
		showerror("Error: \"$username\" is not an RTI user. Please use system utilities to remove this user.\n");
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
sub update_rtiuser
{
	my $username = $_[0];
	my %userinfo = ();
	my $returnval = 0;
	my $date = "";

	if($username eq "") {
		return(-1);
	}


	# Make sure the 'rti' unix group exists *before* creating our user,
	# as, all RTI users will be a member of this group.
	add_rti_groups();


	# If the user doesn't already exist, create it.
	%userinfo = get_userinfo($username);
	if(! %userinfo) {
		showerror("User \"$username\" Does not exist. Please add the user first.");
		return(-3);
	} else {
		showerror("Updating User \"$username\"");
	}



	#
	# In the case of linux, certain hardware devices (/dev/ttySx /dev/lp0, /dev/fd0) are 
	# all writable by users who are members of certain groups. Here, we add our user to said
	# groups.
	#
	append_usergroup("rti", $username);
	append_usergroup("floppy", $username); # Wire Service Reconciliation.
	append_usergroup("lp", $username); # Printing Reports.
	append_usergroup("lock", $username); # Dove Modems (Lockfiles)

	#
	# The group "uucp" does not exist on RHEL7
	#
	my $gid_uucp = getgrnam("uucp");
	if (defined($gid_uucp)) {
	    append_usergroup("uucp", $username);
	}

	#
	# There is a new group for RHEL6 - "dialout".
	#
	# Specifically, the default perms for "/dev/ttyUSB*" devices are "rw"
	# for this group and users need permission to write to these devices so
	# add the users to this group if it exists.
	#
	my $gid = getgrnam("dialout");
	if (defined($gid)) {
	    append_usergroup("dialout", $username);
	}

	system ("sudo /usr/sbin/usermod -g rti $username");


	#
	# All of these settings pertain to being an RTI administrator
	#
	if(grep(/rtiadmins/, @{$userinfo{'groups'}})) {

		# PCI 8.5.9
		# Maximum number of days until password must be changed.
		if($username ne "root") {
			system("sudo /usr/bin/chage -M 90 $username");
			system("sudo /usr/bin/chage -W 7 $username");
		}

		# PCI 8.5.5
		# Number of days after password has expired and which
		# the user has not attempted login, before the account is automatically
		# locked.
		#
		# Since PCI 8.5.5 can technically be enforced via policy (and not hard and fast rules like this)
		# We will not enforce the rules for 'root' and 'tfsupport'. Doing so could result in being unable to
		# login to the system as 'root' or 'tfsupport' which could make the server unmanageable, as well as
		# cause unexpected crontab outages.
		#
		if( ($username ne "root")
		&&  ($username ne "tfsupport") ) {
			system("sudo /usr/bin/chage -I 90 $username");
		} else {
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
	} else {
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
	}


	return 0;
}



#
# Copy a new SSH "authorized_keys" file into place.
#
sub update_sshkey
{
	my $username = $_[0];
	my $keyfile = $_[1];
	my %userinfo = ();

	if("$username" eq "") {
		return(1);
	}
	if("$keyfile" eq "") {
		return(2);
	}
	if(! -f "$keyfile") {
		return(3);
	}


	%userinfo = get_userinfo($username);
	if(! %userinfo) {
		return(4);
	}



	# Make a backup of our existing ssh key, if it exists.
	if(-f "$userinfo{'homedir'}/.ssh/authorized_keys") {
		system("mv $userinfo{'homedir'}/.ssh/authorized_keys  $userinfo{'homedir'}/.ssh/old-authorized_keys");
	}


	# Install new key.
	system("cp $keyfile $userinfo{'homedir'}/.ssh/authorized_keys");
	system("chown $USERNAME:rtiadmins $userinfo{'homedir'}/.ssh/authorized_keys");
	system("chmod 440 $userinfo{'homedir'}/.ssh/authorized_keys");


	# Make sure our new key is in plce.
	# If something goes wrong here, it is possible that this user will be locked out, as, 
	# two factor auth is requried (and where would that leave us if one of our factors was
	# not in place?)
	system("diff $keyfile $userinfo{'homedir'}/.ssh/authorized_keys > /dev/null 2> /dev/null");
	if($? != 0) {
		system("mv $userinfo{'homedir'}/.ssh/old-authorized_keys  $userinfo{'homedir'}/.ssh/authorized_keys");
		return(5);
	}

	# Shred the old key.
	if(-f "$userinfo{'homedir'}/.ssh/old-authorized_keys") {
		system("shred -fu $userinfo{'homedir'}/.ssh/old-authorized_keys");
	}


	#
	# Remote Administrators need to use two factor authentication.
	# PCI 8.3
	#
	if("$username" eq "tfsupport") {

		open(FILE, "> $userinfo{'homedir'}/.ssh/config");
		print FILE "#\n";
		print FILE "# RTI Remote Administrative SSH Configuration\n";
		print FILE "# Created by $PROGNAME $CVS_REVISION\n";
		print FILE "#\n";
		print FILE "\n";

		print(FILE << 'EOF');
RSAAuthentication yes
PasswordAuthentication no
HostbasedAuthentication no
EOF

		close(FILE);
	}




	return(0);
}



#
# Creat the "rti" unix group, if need be.
#
sub add_rti_groups
{

	# Add our RTI related unix groups.
	system "sudo /usr/sbin/groupadd rti > /dev/null 2> /dev/null";
	system "sudo /usr/sbin/groupadd rtiadmins > /dev/null 2> /dev/null";
	unless (-f "/sbin/pam_tally2") {
	    unless (-e "/var/log/faillog") {
		system "touch /var/log/faillog > /dev/null 2> /dev/null";
	    }
	}

	return $?
}






#
# Change appropriate settings for an RTI administrator.
#
sub enable_rtiadmin
{
	my $username = $_[0];
	my $thisgroup = "";
	my $line = "";



	if($username eq "") {
		return(-1);
	}

	if(user_exists($username) != 0) {
		showerror("User \"$username\" does not exist. Please use --add first.");
		return(-2);
	}


	# Make sure "rti" group exists.
	add_rti_groups();


	showerror("Setting \"$username\" as an RTI Administrator");
	append_usergroup("rtiadmins", $username);


	return 0;
}



#
# Remove administrative privileges from an RTI user.
#
sub disable_rtiadmin
{
	my $username = $_[0];
	my %userinfo = ();
	my $thisgroup = "";

	if($username eq "") {
		return(-1);
	}


	%userinfo = get_userinfo($username);
	if(! %userinfo) {
		showerror("User \"$username\" is not an RTI user. Please use --add first.");
		return(-2);
	}
	if(! grep(/rtiadmins/, @{$userinfo{'groups'}})) {
		showerror("User \"$username\" is not an RTI Admin. Cannot disable.");
		return(0);
	}


	# Re-add user to all groups *except* rtiadmins.
	showerror("Removing Administrative Privileges for \"$username\".");
	if($username ne "root") {
		remove_usergroup("rtiadmins", $username);
	}


	return(0);
}




#
# Modify .bash_profile to ensure we are only executing RTI.
# We want this for "rti" users, but not necessarily for "root" or "tfsupport".
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


	if ( ($username eq "kiosk") 
	||   ("$username" eq "tfsupport")
	||   ("$username" eq "root") ) {
		showerror("Warning: Skipping modification of .bash_profile because user is either 'kiosk', 'tfsupport' or 'root' user.");
		return(0);
	}


	

	# Get the full path for this user's home directory.
	%userinfo = get_userinfo($username);



	# Remove any existing symlinks.
	if(-l "$userinfo{'homedir'}/.bash_profile") {
		system("sudo rm -f $userinfo{'homedir'}/.bash_profile");
	}
	if(-l "$userinfo{'homedir'}/.profile") {
		system("sudo rm -f $userinfo{'homedir'}/.profile");
	}


	if(-f "$userinfo{'homedir'}/.profile") {
		system "sudo mv $userinfo{'homedir'}/.profile $userinfo{'homedir'}/.profile-" . strftime("%Y-%m-%d_%H%M%S", localtime());
	}
	if(-f "$userinfo{'homedir'}/.bash_profile") {
		system "sudo mv $userinfo{'homedir'}/.bash_profile $userinfo{'homedir'}/.bash_profile-" . strftime("%Y-%m-%d_%H%M%S", localtime());
	}
	if(-f "$userinfo{'homedir'}/.bash_logout") {
		system "sudo mv $userinfo{'homedir'}/.bash_logout $userinfo{'homedir'}/.bash_logout-" . strftime("%Y-%m-%d_%H%M%S", localtime());
	}

	# .bash_profile
	open(FILE, "> $userinfo{'homedir'}/.bash_profile");
	print(FILE << 'EOF');
#
# RTI User Login Script
# Copyright 2008 Teleflora
#

# PCI 10.x
# Log what the user does.
#
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "
export HISTTIMEFORMAT

#
# TERM is a magic value set within the Putty/Powerterm settings
# used to identify which 'shop' the user is coming in from.
#
bbxterm=`echo $TERM | cut -c 1-1|grep -i T`
if [ "$bbxterm" ] ; then
	BBTERM="T"`echo $TERM|cut -c 2-`
	TERM=ansi
	export BBTERM TERM
fi


# Administrators use a stricter set of rules.
groups | grep rtiadmins > /dev/null 2> /dev/null
if [ $? == 0 ] ; then
	PATH=/sbin:/usr/sbin:$PATH
	export PATH
	export TMOUT=900
fi


EOF

	# All users are "locked into" running RTI at login; except 'tfsupport'.
	if( ($username ne "tfsupport") 
	&&  ($username ne "root") ){
		print(FILE << 'EOF');
# Setup environment variables for running RTI.
umask 0002
alias l="ls -l"
. /etc/profile.d/rti.sh
exec rti
EOF
	}
	close(FILE);



	# .bash_logout
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
		system "sudo chgrp rtiadmins $userinfo{'homedir'}/.bash_profile";
		system "sudo chmod 575 $userinfo{'homedir'}/.bash_profile";
	}

	# If user is "rti", setup the .rhosts for java webstart connectivity
        if($username eq "rti") {
                open(FILE, "> $userinfo{'homedir'}/.rhosts");
                print(FILE "+ +\n");
                close(FILE);
        }

	if(-f "$userinfo{'homedir'}/.forward") {
		system "sudo chown tfsupport $userinfo{'homedir'}/.forward";
		system "sudo chgrp rtiadmins $userinfo{'homedir'}/.forward";
		system "sudo chmod 575 $userinfo{'homedir'}/.forward";
	}

	if(-f "$userinfo{'homedir'}/.rhosts") {
                system "sudo chown rti $userinfo{'homedir'}/.rhosts";
                system "sudo chgrp rti $userinfo{'homedir'}/.rhosts";
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
	my $nu_password = $_[1];

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
	# Note that we don't want sudo prompting for a password Just before "passwd"
	# prmpts for the new user's password. This opens us to a lot of risk of the admin placing the administrator's
	# password as the new user's password.
	# So here, if we are not already root, then, request such.
	#
	if($EUID != 0) {
		showerror("Invalid Permissions. Please run this command as 'sudo'.");
		return(-3);
	}

	# Actually change the password here.
        if ($nu_password eq "") {
                system "sudo /usr/bin/passwd $username";
        } else {
                system "echo $nu_password | sudo /usr/bin/passwd --stdin $username";
        }



        # The password we set for members of the "rtiadmins" group and
        # for the "root" account should be a one-time password.
	if ( grep(/rtiadmins/, @{$userinfo{'groups'}}) ||
            ($userinfo{'username'} eq "root") ) {
		# PCI 8.5.3
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
sub lock_rtiuser
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
# Undo what we did with "lock_user()
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


	system "sudo /usr/bin/passwd -u $username";
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
# RHEL 5, and later versions of RHEL 4 support "appending" group memberships. However,
# Early (initial release) versions of RHEL4 do not support "-a". This is a sort of 'hand rolled'
# "append" flag.
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
	my $is_rtiadmin = "";
	my $is_tfremote = "";



	# Get a list of all users in the "RTI" group.
	@entry = getgrent();
	while(@entry) {
		if($entry[0] eq "rti") {
			$usergid = $entry[2];
			foreach $username (split /\s+/, $entry[3]) {
				push(@users, $username);
			}
		}
		if($entry[0] eq "rtiadmins") {
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
	# Get a list of all users in the "RTIAdmins" group.


	# Step through each user on the box, are they a member of either "admins" or the "rti" group?
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

		$is_rtiadmin = "";
		$is_tfremote = "";
		if(grep(/^$username$/, @admins)) {
			$is_rtiadmin = "(RTI Admin)";
		}
		if(grep(/^$username$/, @remotes)) {
			$is_tfremote = "(TFRemote)";
		}

		printf("%-20s %-12s %-12s %-12s\n", $username, "(RTI User)", $is_rtiadmin, $is_tfremote);
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
# AN error which is reported both to the user, and to syslogs.
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
	system("/usr/bin/logger -i -t \"$UID-rtiuser\.pl \" -- \"$message\"");
}


__END__


=pod

=head1 NAME

rtiuser.pl - Manage RTI User Accounts


=head1 VERSION

This documenation refers to version: $Revision: 1.13 $


=head1 USAGE

rtiuser.pl

rtiuser.pl B<--version>

rtiuser.pl B<--help>

rtiuser.pl B<--list>

rtiuser.pl B<--info username>

rtiuser.pl B<--add username>

rtiuser.pl B<--remove username>

rtiuser.pl B<--update username>

rtiuser.pl B<--lock username>

rtiuser.pl B<--unlock username>

rtiuser.pl B<--resetpw username [password]>

rtiuser.pl B<--enable-admin username [password]>

rtiuser.pl B<--disable-admin username>


=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--list>

List the current RTI users and admins.

=item B<--info username>

Get information about the specified user.

=item B<--add username>

Add the specified user to the system as an RTI user.

=item B<--remove username>

Remove the specified user from the system.

=item B<--update username>

Update the settings for the specified user.

=item B<--lock username>

Disable, but do not remove, the account of the specified user.

=item B<--unlock username>

Enable the account of the specified user but do not modify the password.

=item B<--resetpw username [password]>

Reset the password for the specified user, either interactively or
optionally from the command line.

=item B<--enable-admin username [password]>

Grant the specified RTI user 'admin' privileges.

=item B<--disable-admin username>

Remove 'admin' privileges from the specified RTI user.

=back


=head1 DESCRIPTION

This C<rtiuser.pl> script manages many aspects of RTI user accounts
on the system including adding and removing users, setting their passwords,
enabling/disabling accounts, and enabling/disabling 'admin' privs.

When adding a new C<rti> user via C<--add username> option,
the new account will also be added to the following system groups:

=over

=item C<rti>

=item C<floppy>

=item C<lp>

=item C<lock>

=back

On C<RHEL5> and C<RHEL6>, it will also be added to the C<uucp> group.

On C<RHEL6> and C<RHEL7>, it will also be added to the C<dialout> group.

When granting 'admin' privs with the C<--enable-admin username> option,
the user C<rti> may not be specified as the username.


=head1 FILES

=over 4

=item C</var/log/faillog>

The log file for recording login failures on platforms that do not not
the C</sbin/pam_tally2> command.

=item C</var/log/tallylog>

The log file for recording login failures on platforms that do have
the C</sbin/pam_tally2> command.

=item C</var/log/messages>

The default log file.  Log file messages are written via the
C<logger> command.

=item C<~/.bash_profile>

This C<bash> startup script is modified by the C<--add>, C<--update>,
C<--enable-admin>, and C<--disable-admin> options.

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status 0

Successful completion.

=item Exit status 1

In general, there was an issue with the syntax of the command line.
Specifically, if the username C<rti> was specified with the C<--enable-admin> option.

=item Exit status 2

For all command line options other than C<--version> and C<--help>,
the user must be root or running under C<sudo>.

=item Exit status 3

The specified username did not pass validation, eg it may have
had characters that are considered a security issue.

=item Exit status 4

The specified password did not pass validation, eg it may have
had characters that are considered a security issue.

=back


=head1 SEE ALSO

C<chage(1)>, C<faillog(1)>, C<pam_tally2(1)>, C<useradd(1)>, C<usermod(1)>


=cut
