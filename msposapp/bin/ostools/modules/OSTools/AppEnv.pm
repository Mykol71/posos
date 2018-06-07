#
# $Revision: 1.1 $
# Copyright 2014 Teleflora
#
# Application Environment module for OSTools.
#

package OSTools::AppEnv;

use strict;
use warnings;
use Carp;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default.

our @EXPORT = qw(
    appenv_module_version
    appenv_pos_name
    appenv_pos_version
    appenv_pos_topdir
    appenv_pos_dir
    appenv_ostools_version
    appenv_ostools_dir
);

# Perl module method of getting CVS/RCS version number into variable
our $VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);


# Preloaded methods go here.

sub appenv_module_version
{
    return($VERSION);
}


#
# Which POS is running on this system.
# Assumption: there can be only one, RTI or Daisy
#
# Returns
#   "RTI" or "Daisy"
#   undef if no POS detected
#
sub appenv_pos_name
{
    if (-d "/usr2/bbx") {
	return("RTI");
    }
    if (-d "/d/daisy") {
	return("Daisy");
    }

    return(undef);
}


#
# What is the version number of the POS?
#
# Returns
#   version string if POS installed
#   undef if POS not installed
#
sub appenv_pos_version
{
    my $pos_name = appenv_pos_name();
    return (undef) if (!defined($pos_name));

    my $pos_version = undef;

    my $pos_dir = appenv_pos_dir();
    if ($pos_name eq "RTI") {
	my $rti_ini_file = $pos_dir . "/bbxd/RTI.ini";
	if (-f $rti_ini_file) {
	    if (open(my $ini_fh, '<', $rti_ini_file)) {
		my $rti_patchlevel = "";;
		while (<$ini_fh>) {
		    chomp;
		    if (/^VERSION\s*=\s*([[:print:]]+)/) {
			$pos_version = $1;
		    }
		    if (/^PATCH\s*=\s*([[:print:]]+)/) {
			$rti_patchlevel = $1;
			last;
		    }
		}
		close($ini_fh);
		if ($pos_version) {
		    $pos_version .= $rti_patchlevel;
		}
	    }
	    else {
		carp "error opening RTI INI file: $rti_ini_file: $!";
	    }
	}
	else {
	    carp "RTI INI file does not exist: $rti_ini_file";
	}
    }
    if ($pos_name eq "Daisy") {
	my $daisy_info_file = $pos_dir . "/config/daisybuildinfo.txt";
	if (-f $daisy_info_file) {
	    if (open(my $info_fh, '<', $daisy_info_file)) {
		my $daisy_version = "";
		while (<$info_fh>) {
		    chomp;
		    if (/^Build Number:\s+([[:print:]]+)/) {
			$pos_version = $1;
			last;
		    }
		}
		close($info_fh);
	    }
	    else {
		carp "error opening Daisy build info file: $daisy_info_file: $!";
	    }
	}
	else {
	    carp "Daisy build info file does not exist: $daisy_info_file";
	}
    }

    return($pos_version);
}


#
# What is the top level directory of the POS?
#
# Returns
#   "/usr2" if POS eq "RTI"
#   "/d" if POS eq "Daisy"
#   undef if no POS detected
#
sub appenv_pos_topdir
{
    my $pos_name = appenv_pos_name();
    return (undef) if (!defined($pos_name));

    if ($pos_name eq "RTI") {
	return("/usr2");
    }
    if ($pos_name eq "Daisy") {
	return("/d");
    }

    return(undef);
}


#
# What is the default directory of the POS?
#
# Returns
#   "/usr2/bbx" if POS eq "RTI"
#   "/d/daisy" if POS eq "Daisy"
#   undef if no POS detected
#
sub appenv_pos_dir
{
    my $pos_name = appenv_pos_name();
    return (undef) if (!defined($pos_name));

    if ($pos_name eq "RTI") {
	return("/usr2/bbx");
    }
    if ($pos_name eq "Daisy") {
	return("/d/daisy");
    }

    return(undef);
}


#
# What is the version number of ostools?
#
# Returns
#   version string if ostools installed
#   undef if ostools not installed
#
# FIXME:
#    this code does not actually look up the version number.
#    the code exists in other files, will have to add it to
#    this file ASAP.
#
sub appenv_ostools_version
{
    my $ostools_version = undef;

    my $ostools_dir = appenv_ostools_dir();
    if (defined($ostools_dir)) {
	my $ostools_bindir = $ostools_dir . "/bin";
	my $ostools_cmd = $ostools_bindir . "/tfsupport.pl --version";
	if (open(my $pipe, '-|', $ostools_cmd)) {
	    while (<$pipe>) {
		if (/^OSTools Version:\s+([[:print:]]+)$/i) {
		    $ostools_version = $1;
		    last;
		}
	    }
	    close($pipe);
	}
	else {
	    carp "error opening pipe to ostools command: $ostools_cmd: $!";
	}
    }
    else {
	carp "OSTools package not installed";
    }

    return($ostools_version);
}


#
# What is the top level directory of ostools on this system.
#
# Returns
#   "/usr2/ostools" if POS eq "RTI"
#   "/d/ostools" if POS eq "Daisy"
#   "/teleflora/ostools" if ostools installed but not POS
#   undef if no POS detected or ostools dir does not exist
#
sub appenv_ostools_dir
{
    my $pos_name = appenv_pos_name();
    if (defined($pos_name)) {
	if ($pos_name eq "RTI") {
	    if (-d "/usr2/ostools") {
		return("/usr2/ostools");
	    }
	}
	if ($pos_name eq "Daisy") {
	    if (-d "/d/ostools") {
		return("/d/ostools");
	    }
	}
    }
    else {
	if (-d "/telefora/ostools") {
	    return("/telefora/ostools");
	}
    }

    return(undef);
}

1;


__END__

=head1 NAME

OSTools::AppEnv - Perl module for library of Application Environment functions


=head1 SYNOPSIS

  use lib '/usr/local/ostools/modules';

  use OSTools::AppEnv;

  my $module_version = appenv_module_version();
  my $pos_name = appenv_pos_name();
  my $pos_version = appenv_pos_version();
  my $pos_topdir = appenv_pos_topdir();
  my $pos_dir = appenv_pos_dir();
  my $ostools_version = appenv_ostools_version();
  my $ostools_dir = appenv_ostools_dir();_


=head1 DESCRIPTION

The C<OSTools::AppEnv> module implements functions which
provide information about the application environment for
the Teleflora RTI and Daisy Point of Sale packages.

=head2 EXPORT

=over 4

=item function C<OSTools::AppEnv::appenv_module_version>

A call to this function returns the version string of the module.
This version string is simply the CVS revision string of the
source file of the module.

=item function C<OSTools::AppEnv::appenv_pos_name>

A call to this function returns the name of the installed POS.
The choices are "RTI" and "Daisy".
If there is no POS installed, then B<undef> is returned.

=item function C<OSTools::AppEnv::appenv_pos_version>

A call to this function returns the version string of the installed POS.
This is usually a string with 3 integers seperated by a "." but
it may contain alpha characters so be aware.
A typical value for "RTI" would be "14.5.7".
A typical value for "Daisy" would be "9.2.10".
If there is no POS installed, then B<undef> is returned.

=item function C<OSTools::AppEnv::appenv_pos_topdir>

A call to this function returns a string with the path to the
top level directory of the installed POS.
For "RTI", the standard location is F</usr2>.
For "Daisy, the standard location is F</d>.
If there is no POS installed, then B<undef> is returned.

=item function C<OSTools::AppEnv::appenv_pos_dir>

A call to this function returns a string with the path to the
default directory of the installed POS.
For "RTI", the standard location is F</usr2/bbx>.
For "Daisy, the standard location is the default Daisy
database directory F</d/daisy>.
If there is no POS installed, then B<undef> is returned.

=item function C<OSTools::AppEnv::appenv_ostools_version>

A call to this function returns the version string of the
ostools package.
This version string is taken from the output of the command:
C<tfsupport.pl --version>.

=item function C<OSTools::AppEnv::appenv_ostools_dir>

A call to this function returns a string with the path to the
top level directory of the ostools directory if
the ostools package is installed.
For "RTI", the standard location is F</usr2/ostools>.
For "Daisy, the standard location is F</d/ostools>.
If neither POS is installed, the standard location is F</teleflora/ostools>.
If the ostools package is not installed, then if B<undef> is returned.

=back


=head1 SEE ALSO

B<updateos.pl>, B<rtibackup.pl>, B<tfsupport.pl>, B<dsyuser.pl>, B<harden_linux.pl>,
B<tfprinter.pl>, B<tfremote.pl>

B<http://rtihardware.homelinux.com/ostools/ostools.html>

=cut
