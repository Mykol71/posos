#
# $Revision: 1.5 $
# Copyright 2012-2015 Teleflora
#
# Platform module for OSTools.
#

package OSTools::Platform;

use strict;
use warnings;
use Carp;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default.

our @EXPORT = qw(
    plat_module_version
    plat_kernel_release
    plat_os_version
    plat_processor_arch
    plat_redhat_version
);

# Perl module method of getting CVS/RCS version number into variable
our $VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);


# Preloaded methods go here.

my $PLAT_ALTOSROOT = (exists $ENV{'ALTOSROOT'}) ? $ENV{'ALTOSROOT'} : '';
my $PLAT_RH_VERSION_FILE = "$PLAT_ALTOSROOT/etc/redhat-release";

sub plat_module_version
{
    return($VERSION);
}


sub plat_kernel_release
{
    my $kernel_release = "";

    if (open(my $uname, "uname -r |")) {
	while(<$uname>) {
	    chomp($_);
	    $kernel_release = $_;
	    last;
	}
	close($uname);
    }
    else {
	carp "Can't get kernel release via opening pipe to: uname -r\n";
	return(undef);
    }

    return($kernel_release);
}


sub plat_redhat_version
{
    my $rh_version = "";

    if (open(my $rhvf, '<', $PLAT_RH_VERSION_FILE)) {
	while(<$rhvf>) {
	    if (/Red Hat/) {
		chomp($_);
		$rh_version = $_;
		last;
	    }
	}
	close($rhvf);
    }
    else {
	carp "Can't open Red Hat version file: $PLAT_RH_VERSION_FILE\n";
	return(undef);
    }

    return($rh_version);
}


sub plat_os_version
{
    my $os = "";

    my $file;
    unless (open($file, '<', $PLAT_RH_VERSION_FILE)) {
	carp "Can't open Red Hat version file: $PLAT_RH_VERSION_FILE\n";
	return(undef);
    }

    while(<$file>) {

	# Fedora Core 3
	if (/(Fedora)(\s+)(Core)(\s+)(release)(\s+)(3)/) {
	    $os = "FC3";
	    last;
	}

	# Fedora Core 4
	if (/(Fedora)(\s+)(Core)(\s+)(release)(\s+)(4)/) {
	    $os = "FC4";
	    last;
	}

	# Fedora Core 5
	if (/(Fedora)(\s+)(Core)(\s+)(release)(\s+)(5)/) {
	    $os = "FC5";
	    last;
	}

	# Redhat Enterprise Linux Client Workstation 5
	if (/(Client release)(\s+)(5)/) {
	    $os = "RHWS5";
	    last;
	}

	# ES 7
	# Redhat Enterprise Linux Server 7
	if ((/(release)(\s+)(7)/)
	    ||  (/(CentOS)([[:print:]]+)(\s)(7)/)) {
	    $os = "RHEL7";
	    last;
	}

	# ES 6
	# Redhat Enterprise Linux Server 6
	if ((/(release)(\s+)(6)/)
	    ||  (/(CentOS)([[:print:]]+)(\s)(6)/)) {
	    $os = "RHEL6";
	    last;
	}

	# ES 5
	# Redhat Enterprise Linux Server 5
	if ((/(release)(\s+)(5)/)
	    ||  (/(CentOS)([[:print:]]+)(\s)(5)/)) {
			$os = "RHEL5";
			last;
		}

	# EL 4
	# Redhat Enterprise Linux Server 4
	if (/(release)(\s+)(4)/) {
	    $os = "RHEL4";
	    last;
	}

	# EL 3
	# Redhat Enterprise Linux Server 3
	if (/(release)(\s+)(3)/) {
	    $os = "RHEL3";
	    last;
	}

	# Redhat 7.2
	if (/(release)(\s+)(7\.2)/) {
	    $os = "RH72";
	    last;
	}
    }
    close($file);

    return($os);
}




#
# Which processor architecture are we running on?
#
sub plat_processor_arch
{
    my $arch = "";

    open(my $pipe, '-|', "uname -i");
    while(<$pipe>) {
	if (/i386/) {
	    $arch = "i386";
	}
	if(/x86_64/) {
	    $arch = "x86_64";
	}
    }
    close($pipe);

    if ($arch eq "") {
	$arch = "i386";
    }

    return($arch);
}

1;


__END__

=head1 NAME

OSTools::Platform - Perl module for library of platform functions


=head1 SYNOPSIS

  use lib '/usr/local/ostools/modules';

  use OSTools::Platform;

  my $module_version = plat_module_version();
  my $os = plat_os_version();
  my $arch = plat_processor_arch();
  my $kernel = plat_kernel_release();
  my $rh_version = plat_redhat_version();


=head1 DESCRIPTION

The C<OSTools::Platform> module implements functions which
provide information about the computing platform.
The functions provide information about the os version,
the processor architecture,
as well as the version string of the C<Platform> module itself.

=head2 EXPORT

=over 4

=item function C<OSTools::Platform::plat_module_version>

A call to this function returns the version string of the module.
This version string is simply the CVS revision string of the
source file of the module.

=item function C<OSTools::Platform::plat_os_version>

A call to this function returns a version string reflecting the
operating system.
Values may be:
    B<RH72>, B<FC3>, B<FC5>, B<RHEL3>, B<RHEL4>, B<RHEL5>, B<RHEL6>

If the operating system version can not be deteremined, then
the value of C<undef> is returned.

=item function C<OSTools::Platform::plat_processor_arch>

This function returns a string reflecting the processor architecture.
Possible vales are:
    B<i386>, B<x86_64>

=back


=head1 SEE ALSO

B<updateos.pl>, B<rtibackup.pl>, B<tfsupport.pl>, B<dsyuser.pl>, B<harden_linux.pl>,
B<tfprinter.pl>, B<tfremote.pl>

B<http://rtihardware.homelinux.com/ostools/ostools.html>

=cut
