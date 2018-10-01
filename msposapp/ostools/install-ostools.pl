#!/usr/bin/perl
#
# $Revision: 1.64 $
# Copyright Teleflora 2010-2015
#
# install-ostools.pl
#
# Install OSTools onto a Teleflora POS Linux machine.
#

use strict;
use warnings;
use POSIX;
use Getopt::Long;
use English;
use File::Basename;


my $CVS_REVISION = '$Revision: 1.64 $';
my $TIMESTAMP = strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($0);

# global variables
my $TOOLSDIR = "";
my $TFSERVER = "rtihardware.homelinux.com";
my $PACKAGE = "http://$TFSERVER/ostools/ostools-1.15-latest.tar.gz";
my $MSG_PREFIX = "OSTools v1.15.0";
my $FRESH_INSTALL = 0;
my $RTI = 0;
my $DAISY = 0;

# command line options
my $VERSION = 0;
my $HELP = 0;
my $RTI_PATCHES = 0;
my $DAISY_PATCHES = 0;
my $UPDATE = 0;
my $RUN_HARDEN_LINUX = 1;
my $INSTALLED_OSTOOLS_VERSION = "";

# Exit status values
my $EXIT_OK = 0;
my $EXIT_COMMAND_LINE = 1;
my $EXIT_MUST_BE_ROOT = 2;
my $EXIT_OSTOOLS_BIN_DIR = 3;
my $EXIT_RTI_PATCHES = 4;
my $EXIT_DAISY_PATCHES = 5;
my $EXIT_DOWNLOAD = 6;
my $EXIT_UNTAR = 7;
my $EXIT_GLOBAL_TOOLS_DIR = 8;
my $EXIT_GLOBAL_MODULES_DIR = 9;
my $EXIT_GLOBAL_MODULES_INSTALL = 10;

GetOptions(
	"help" => \$HELP,
	"version" => \$VERSION,
	"rti-patches" => \$RTI_PATCHES,
	"daisy-patches" => \$DAISY_PATCHES,
	"update" => \$UPDATE,
	"harden-linux!" => \$RUN_HARDEN_LINUX,
	"run-harden-linux!" => \$RUN_HARDEN_LINUX,
	"installed-ostools-version" => \$INSTALLED_OSTOOLS_VERSION,
) || die "error: invalid command line option\n";


# --version
if ($VERSION) {
	print "OSTools Version: 1.15.0\n";
	print "$PROGNAME: $CVS_REVISION\n";
	exit($EXIT_OK);
}


# --help
if ($HELP) {
	print "Usage:\n";
	print "$PROGNAME --help\n";
	print "$PROGNAME --version\n";
	print "$PROGNAME --rti-patches\n";
	print "$PROGNAME --daisy-patches\n";
	print "$PROGNAME --[no]harden-linux\n";
	print "$PROGNAME --[no]run-harden-linux\n";
	print "$PROGNAME --installed-ostools-version\n";
	print "$PROGNAME --update [ostools_pkg_file]\n";

	exit($EXIT_OK);
}

# --installed-ostools-version
if ($INSTALLED_OSTOOLS_VERSION) {
    my $ost_installed_version = ost_get_installed_version();
    if ($ost_installed_version) {
	print "[main] installed ostools version: $ost_installed_version\n";
    }
    else {
	print "[main] could not get installed ostools version\n";
    }

    exit($EXIT_OK);
}


# Are we running as root?
if ($UID != 0) {
    print "[main] this script must be run via sudo\n";
    exit($EXIT_MUST_BE_ROOT);
}


# Allow user to specify where to pull ostools 'package' from.
# otherwise, we will default to the 'latest'.
if (defined($ARGV[0])) {
	if ($ARGV[0] ne "") {
		$PACKAGE = $ARGV[0];
	}
}

loginfo("BEGIN ostools 1.15.0 installation");
loginfo("$PROGNAME: $CVS_REVISION");

#
# Which POS are we using? 
# Where is the root directory of said POS ?
# Ultimately, our ostools should reside under either:
# /d/ostools/bin/ /usr2/ostools/bin/ or /teleflora/ostools/bin/
#
if (-d "/d") {
	$TOOLSDIR="/d/ostools";
	$DAISY = 1;
}
elsif (-d "/usr2") {
	$TOOLSDIR="/usr2/ostools";
	$RTI = 1;
}
elsif (-d "/teleflora") {
	$TOOLSDIR="/teleflora/ostools";
}
else {
	# At this point, none of the expected dirs exist, so use the default.
	$TOOLSDIR="/teleflora/ostools";
}

# choose RTI over Daisy if both are true
if ($RTI && $DAISY) {
    $DAISY = 0;
}


# if there is no tools dir, then this must be a fresh install
unless (-d $TOOLSDIR) {
    loginfo("[ostools install] installation type: fresh");
    $FRESH_INSTALL = 1;
}

# make the ostools directory for the ostools scripts if necessary
unless (-d $TOOLSDIR) {
	loginfo("[ostools install] making directory: $TOOLSDIR");
	system("mkdir -p $TOOLSDIR");
}
system("chown root:root $TOOLSDIR");
system("chmod 775 $TOOLSDIR");

# make the bin directory for the ostools scripts if necessary
unless (-d "$TOOLSDIR/bin") {
	loginfo("[ostools install] making directory: $TOOLSDIR/bin");
	system("mkdir $TOOLSDIR/bin");
}
system("chown root:root $TOOLSDIR/bin");
system("chmod 775 $TOOLSDIR/bin");

# make the config directory for the ostools scripts if necessary
unless (-d "$TOOLSDIR/config") {
	loginfo("[ostools install] making directory: $TOOLSDIR/config");
	system("mkdir $TOOLSDIR/config");
}
system("chown root:root $TOOLSDIR/config");
system("chmod 775 $TOOLSDIR/config");

# make the modules directory for the ostools scripts if necessary
unless (-d "$TOOLSDIR/modules") {
    loginfo("[ostools install] making directory: $TOOLSDIR/modules");
    system("mkdir $TOOLSDIR/modules");
}
system("chown root:root $TOOLSDIR/modules");
system("chmod 775 $TOOLSDIR/modules");

# At this point, the bin dir must exist, or we can't continue.
unless (-d "$TOOLSDIR/bin") {
	logerror("[ostools install] directory does not exist: $TOOLSDIR/bin");
	exit($EXIT_OSTOOLS_BIN_DIR);
}

#
# If explicitly specified on the command line, just do the POS patches.
#
if ($RTI_PATCHES) {
	exit(install_rti_patches());
}

if ($DAISY_PATCHES) {
	exit(install_daisy_patches());
}


# Either download the package or use a local package and install.
loginfo("[ostools install] installing ostools modules and scripts from: $PACKAGE");
if ($PACKAGE =~ /http/) {
    system("cd $TOOLSDIR && wget -O - $PACKAGE | tar -xzf -");
    if ($? != 0) {
	logerror("[ostools install] download error: $PACKAGE");
	exit($EXIT_DOWNLOAD);
    }
} else {
    system("cat $PACKAGE | tar -C $TOOLSDIR -xzf -");
    if ($? != 0) {
	logerror("[ostools install] could not install package file: $PACKAGE");
	exit($EXIT_UNTAR);
    }
}

# fix ostools bin dir that comes out of the tar archive
loginfo("[ostools install] setting owner, group, and perms: $TOOLSDIR/bin");
system("chown root:root $TOOLSDIR/bin");
system("chmod 775 $TOOLSDIR/bin");

# always set the owner, group, and perms for README
my @ostools_readme = glob("$TOOLSDIR/README*");
foreach my $readme (@ostools_readme) {
    system("chown root:root $readme");
    system("chmod 555 $readme");
    loginfo("[ostools install] owner, group, and perms set for: $readme");
}

# always set the owner, group, and perms for modules
loginfo("[ostools install] setting owner, group, and perms: $TOOLSDIR/modules");
system("chown root:root $TOOLSDIR/modules");
system("chmod 775 $TOOLSDIR/modules");
system("chown root:root $TOOLSDIR/modules/OSTools");
system("chmod 775 $TOOLSDIR/modules/OSTools");
system("chown root:root $TOOLSDIR/modules/OSTools/*");
system("chmod 555 $TOOLSDIR/modules/OSTools/*");

#
# install new system service
#
my $service_name = "systememail";
if (-f "$TOOLSDIR/config/$service_name") {

    # copy init.d file into place
    system("cp $TOOLSDIR/config/$service_name /etc/init.d/$service_name");
    system("chmod 755 /etc/init.d/$service_name");
    system("chown root:root /etc/init.d/$service_name");

    # add it
    system("/sbin/chkconfig --add $service_name");

    # but leave it off by default
    system("/sbin/chkconfig --level 2 $service_name off");
    system("/sbin/chkconfig --level 3 $service_name off");
    system("/sbin/chkconfig --level 4 $service_name off");
    system("/sbin/chkconfig --level 5 $service_name off");

    loginfo("[ostools install] added new system service: $service_name");
}

#
# install on all systems
#
loginfo("[ostools install] installing tfremote.pl");
system("$TOOLSDIR/bin/tfremote.pl --install");

loginfo("[ostools install] installing rtibackup.pl");
system("$TOOLSDIR/bin/rtibackup.pl --install");

# install on daisy systems only
if (-d "/d/daisy") {
    loginfo("[ostools install] installing dsyperms.pl");
    system("perl $TOOLSDIR/bin/dsyperms.pl --install");
}

# The default is to run harden linux, but the user can specify
# the command line option so that it does not
if ($RUN_HARDEN_LINUX) {
    loginfo("[ostools install] installing harden_linux.pl");
    system("$TOOLSDIR/bin/harden_linux.pl --install");
}


# make links from POS to OSTools if POS is installed
install_ostools_links();


# Run "perms" script to properly setup permissions on the script(s)
# which we just put into place.
if (-f "/usr2/bbx/bin/rtiperms.pl") {
    if (is_existing_group("rti")) {
	loginfo("[ostools install] setting RTI permissions");
	system("/usr2/bbx/bin/rtiperms.pl /usr2/bbx");
    }
}

elsif (-f "/d/daisy/bin/dsyperms.pl") {
    if (is_existing_group("daisy")) {
	loginfo("[ostools install] setting Daisy permissions");
	set_daisy_perms();
    }
}

#
# This should not be necessary, but just to be sure...
#
# Check the owner of a representative file - if the file is not owned by
# "tfsupport", then either the POS *perms.pl script did not run or
# did not run correctly, so the perms must be set here.
#

my @stats = stat("$TOOLSDIR/bin/tfsupport.pl");
my $uid_fileowner = $stats[4];

my @pwent = getpwnam("tfsupport");
my $uid_tfsupport = (@pwent) ? $pwent[2] : -1;

if ( $uid_fileowner != $uid_tfsupport ) {

	system("chown root:root $TOOLSDIR/bin/*");
	system("chmod 775 $TOOLSDIR/bin/*");

	loginfo("[ostools install] perms set explicitly for scripts in: $TOOLSDIR/bin");
}

#
# If on a RTI system, install any applicable patches.
#
if (-d "/usr2/bbx") {
	install_rti_patches();
}

#
# If on a daisy system, install any applicable patches.
#
if (-d "/d/daisy") {
	install_daisy_patches();
}

loginfo("END ostools 1.15.0 installation");

exit($EXIT_OK);

################################################################################

#
# Look for an installed ostools package in standard locations.
#
# Return version string on success, empty string if not found.
#
sub ost_get_installed_version
{
    my $ost_installed_version = "";
    my $ost_bindir = "";

    my @ost_bindirs = qw(
	/usr2/ostools/bin
	/d/ostools/bin
	/teleflora/ostools/bin
    );

    foreach (@ost_bindirs) {
	if (-d $_) {
	    $ost_bindir = $_;
	    last;
	}
    }
    if ($ost_bindir eq "") {
	return($ost_installed_version);
    }

    my $ost_cmd = "$ost_bindir/tfsupport.pl --version";
    if (open(my $pfh, '-|', $ost_cmd)) {
	while (<$pfh>) {
	    if (/^OSTools Version:\s+(.+)$/i) {
		$ost_installed_version = $1;
		last;
	    }
	}
	close($pfh);
    }
    else {
	logerror("[ostools get version] could not get ostools version string from: $ost_cmd");
	return($ost_installed_version);
    }

    return($ost_installed_version);
}


sub install_rti_patches
{
    my $link_file = "/usr2/bbx/bin/harden_rti.pl";
    my $target_file = "$TOOLSDIR/bin/harden_linux.pl";

    loginfo("[rti patches install] making symlink from $link_file to $target_file");

    #
    # Make sure the symlink target exists.
    #
    unless (-e $target_file) {
	logerror("[rti patches install] symlink target does not exist: $target_file");
	return($EXIT_RTI_PATCHES);
    }

    #
    # If the file to be replaced exists, try to remove it.
    #
    if (-e $link_file) {
	system("rm $link_file");
	if (-e $link_file) {
	    logerror("[rti patches install] could not remove old file: $link_file");
	    return($EXIT_RTI_PATCHES);
	}
    }

    #
    # Now make the symlink
    #
    system("ln -s $target_file $link_file");
    unless (-l $link_file) {
	logerror("[rti patches install] could not make new symlink: $link_file");
	return($EXIT_RTI_PATCHES);
    }

    return($EXIT_OK);
}

#
# Always remember - there can be multiple daisy db dirs!
#
sub install_ostools_links
{
	# Get a list of POS bin dirs, if any.
	my @dst_dirs = get_pos_bin_dirs();

	# If there are none, then nothing to do.
	unless (@dst_dirs) {
		return;
	}

	loginfo("[ostools install] linking ostools scripts to POS");

	my @ostools_scripts = glob("$TOOLSDIR/bin/*.pl");
	foreach my $script_path (@ostools_scripts) {

		my $script_name = basename($script_path);

		# exceptions for RTI
		if (-d "/usr2/bbx/bin") {
		    next if ($script_name eq "dsycheck.pl");
		    next if ($script_name eq "dsyuser.pl");
		    next if ($script_name eq "dsyperms.pl");
		}
		# exceptions for Daisy
		if (-d "/d/daisy/bin") {
		    next if ($script_name eq "rtiuser.pl");
		    next if ($script_name eq "rtiperms.pl");
		}

		foreach my $dst_dir (@dst_dirs) {
			system("rm -f $dst_dir/$script_name");
			system("ln -sf $script_path $dst_dir");
		}
	}

	return(1);
}

sub get_pos_bin_dirs
{
	my @bin_dirs = ();

	# if RTI POS, then only one item in the list
	if (-d "/usr2/bbx/bin") {
		@bin_dirs = ("/usr2/bbx/bin");
		return(@bin_dirs);
	}

	# if not RIT or Daisy, then list is empty - should not happen
	unless (-d "/d/daisy/bin") {
		return(@bin_dirs);
	}

	# Daisy POS can have one or more bin dirs
	my @daisy_db_dirs = glob("/d/*");
	for my $daisy_db_dir (@daisy_db_dirs) {

		# must be a directory
		next unless (-d $daisy_db_dir);

		# skip old daisy dirs
		next if ($daisy_db_dir =~ /.+-\d{12}$/);

		# must contain the magic files
		next unless(-e "$daisy_db_dir/flordat.tel");
		next unless(-e "$daisy_db_dir/control.dsy");

		# must be daisy 8.0+
		next unless (-d "$daisy_db_dir/bin");

		push(@bin_dirs, "$daisy_db_dir/bin");
	}

	return(@bin_dirs);
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
	my $dsyperms_cmd = '/d/daisy/bin/dsyperms.pl';

	unless (-f $dsyperms_cmd) {
		logerror("expecting script to exist: $dsyperms_cmd");
		logerror("could not run: $dsyperms_cmd");
		return(0);
	}

	my @daisy_db_dirs = glob("/d/*");

	for my $daisy_db_dir (@daisy_db_dirs) {

		# must be a directory
		next unless (-d $daisy_db_dir);

		# skip old daisy dirs
		next if ($daisy_db_dir =~ /.+-\d{12}$/);

		# must contain the magic files
		next unless(-e "$daisy_db_dir/flordat.tel");
		next unless(-e "$daisy_db_dir/control.dsy");

		loginfo("Running: $dsyperms_cmd $daisy_db_dir");
		system("perl $dsyperms_cmd $daisy_db_dir");
	}

	return(1);
}


sub install_daisy_patches
{
	my $daisy_version = "";

	loginfo("[daisy install patches] there are no patches for Daisy");

	return($EXIT_OK);
}


#
# Search /etc/group for a specific group name.
#
# Returns 1 if found, 0 if not
#
sub is_existing_group
{
    my ($group_name) = @_;

    my @group_ent = ();
    my $rc = 0;

    @group_ent = getgrent();
    while(@group_ent) {
        if ($group_name eq $group_ent[0]) {
            $rc = 1;
	    last;
	}

        @group_ent = getgrent();
    }
    endgrent();

    return($rc);
}


sub loginfo
{
    my ($msg) = @_;

    print("$msg\n");

    return(logit($msg, 'I'));
}

sub logwarning
{
    my ($msg) = @_;

    print("Warning: $msg\n");

    return(logit($msg, 'W'));
}

sub logerror
{
    my ($msg) = @_;

    print("Error: $msg\n");

    return(logit($msg, 'E'));
}

sub logit
{
    my ($msg, $msg_type) = @_;

    my $tag = "$PROGNAME";

    my $rc = system("/usr/bin/logger -i -t $tag -- \"$UID: <$msg_type> $msg\"");

    return($rc);
}


__END__

=pod

=head1 NAME

B<install-ostools.pl> - OSTools Package Installer

=head1 VERSION

This documenation refers to version: $Revision: 1.64 $


=head1 USAGE

B<install-ostools.pl> B<--version>

B<install-ostools.pl> B<--help>

B<install-ostools.pl> (B<--rti-patches> | B<--daisy-patches>)

B<install-ostools.pl> [B<--[no]harden-linux>] B<--update> [(I<URL> | I<path>)]

B<install-ostools.pl> B<--update> [(I<URL> | I<path>)]


=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--rti-patches>

Install any RTI patches.

=item B<--daisy-patches>

Install any Daisy patches.

=item B<--update>

Install the the OSTools package.

=item B<--[no]harden-linux>

Run the B<harden-linux.pl> script after installation.

=back


=head1 DESCRIPTION

The B<install-ostools.pl> script installs the OSTools package
on a Red Hat Enterprise Linux server.

The major parts of the installed package consist of:

=over 4

=item README file

=item Scripts

=item Config files

=item Modules

=back

The package is installed with a top level folder named C<ostools>
which is located in the directory C</usr2> on RTI systems and
in C</d> on Daisy systems.
The scripts are located in C<ostools/bin>,
the config files in C<ostools/config>, and
the modules are in C<ostools/modules>.

The latest release of this package can always be downloaded to the
system via the following commands:

 $ cd /tmp
 $ package_name=ostools-latest.tar.gz
 $ url=http://rtihardware.homelinux.com/ostools
 $ curl -o $package_name $url/$package_name

Then, to install the package, run the following commands:

 $ tar xf $package_name
 $ sudo perl bin/install-ostools.pl --update $package_name

Installation will have the side effect of the B<harden_linux.pl>
script running and thus possibly changing the system configuration.
If installation of the OSTools package without running B<harden_linux.pl>
is desired, specify the B<--noharden-linux> option:

 $ sudo perl bin/install-ostools.pl --noharden-linux --update $package_name

After the scripts are installed, if there is a POS installed,
then the appropriate "perms" script is run,
B<rtiperms.pl> on a RTI system, and B<dsyperms.pl> on a Daisy system.


=head2 COMMAND LINE OPTIONS

Specify the B<--rti-patches> command line option
to install any RTI patches.

Specify the B<--daisy-patches> command line option
to install any Daisy patches.

Specify the B<--update> command line option
to install the OSTools package.

Specify the B<--[no]harden-linux> command line option
to run the B<harden_linux.pl> script after installation
of the OSTools package.
Since the default behavior is to run the B<harden_linux.pl> script,
this option is actually provided as a way to prevent running the
B<harden_linux.pl> script.


=head1 FILES

=over 4

=item C<http://rtihardware.homelinux.com/ostools/ostools-1.14-latest.tar.gz>

This URL will always point at the latest release of the OSTools 1.14 package.

=item C</usr2/bbx>

If this directory exists, then it is assumed that the system has the
RTI POS installed.

=item C</d/daisy>

If this directory exists, then it is assumed that the system has the
Daisy POS installed.

=item C</usr2/ostools/bin>

On RTI systems, the OSTools scripts will be installed in this directory.

=item C</usr2/ostools/config>

On RTI systems, the OSTools config files are located in this directory.

=item C</usr2/ostools/modules>

The OSTools modules directory for RTI systems.

=item C</d/ostools/bin>

On Daisy systems, the OSTools scripts will be installed in this directory.

=item C</d/ostools/config>

On Daisy systems, the OSTools config files are located in this directory.

=item C</d/ostools/modules>

The OSTools modules directory for Daisy systems.

=item C</etc/redhat-release>

The contents of this file are used to determine the version of Linux.

=item C</var/log/messages>

Log messages are written to this log file via the B<logger(1)> command.

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status 0 ($EXIT_OK)

Successful completion.

=item Exit status 1 ($EXIT_COMMAND_LINE)

In general, there was an issue with the syntax of the command line.

=item Exit status 2 ($EXIT_MUST_BE_ROOT)

For all command line options other than B<--version> and B<--help>,
the user must be root or running under B<sudo>.

=item Exit status 3 ($EXIT_OSTOOLS_BIN_DIR)

The directory that the OSTools scripts are to be installed into
does not exist.

=item Exit status 4 ($EXIT_RTI_PATCHES)

In error occurred installing RTI patches.

=item Exit status 5 ($EXIT_DAISY_PATCHES)

In error occurred installing DAISY patches.

=item Exit status 6 ($EXIT_DOWNLOAD)

An error occurred downloading the OSTools package.

=item Exit status 7 ($EXIT_UNTAR)

An error occurred untarring the OSTools package file.

=back


=head1 SEE ALSO

B<logger(1)>, B<rtiperms.pl>, B<dsyperms.pl>


=cut
