#
# $Revision: 1.2 $
# Copyright 2012 Teleflora
#
# Hardware module for OSTools.
#

package OSTools::Hardware;

use strict;
use warnings;
use Carp;

require Exporter;

# Perl module method of getting CVS/RCS version number into variable
our $VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

# Items to export into callers namespace by default.

our @EXPORT = qw(
    hw_module_version
    hw_manufacturer
    hw_product_name
    hw_serial_number
    hw_sysinfo
);

our @ISA = qw(Exporter);


# Preloaded methods go here.

my $ALTOSROOT = (exists $ENV{'ALTOSROOT'}) ? $ENV{'ALTOSROOT'} : '';

sub hw_module_version
{
    return($VERSION);
}


#
# Get the "type of" hardware we are on. 
#
# Call the dmidecode command to get the:
#   vendor name ("Manufacturer")
#   service tag number ("Serial Number")
#   hardware name ("Product Name")

sub hw_sysinfo
{
    my $manufacturer = "";
    my $serial_number = "";
    my $product_name = "";

    my $dmi_cmd = "$ALTOSROOT/usr/sbin/dmidecode";

    unless (-e $dmi_cmd) {
	carp("The $dmi_cmd program does not exist");
	return($manufacturer, $serial_number, $product_name);
    }

    my $pipe;
    unless (open($pipe, '-|', "$dmi_cmd | grep -A 5 \"System Information\"")) {
	carp("Can't pipe info from $dmi_cmd\n");
	return($manufacturer, $serial_number, $product_name);
    }

    while(<$pipe>) {
	chomp;
	if (/(Manufacturer:)(\s+)(\S+)/) {
	    $manufacturer = $3;
	}
	if(/(Serial Number:)(\s+)(\S+)/) {
	    $serial_number = uc($3);
	}
	if(/(Product Name:)(\s+)(.+)/) {
	    $product_name = $3;
	}

    }
    close($pipe);

    return($manufacturer, $serial_number, $product_name);
}

sub hw_manufacturer
{
    my ($manufacturer, $serial_number, $product_name) = hw_sysinfo();

    return($manufacturer);
}

sub hw_serial_number
{
    my ($manufacturer, $serial_number, $product_name) = hw_sysinfo();

    return($serial_number);
}

sub hw_product_name
{
    my ($manufacturer, $serial_number, $product_name) = hw_sysinfo();

    return($product_name);
}

1;


__END__

=head1 NAME

OSTools::Hardware - Perl module for library of hardware functions

=head1 SYNOPSIS

On a RTI system:
  use lib '/usr2/ostools/modules';

On a Daisy system:
  use lib '/d/ostools/modules';

  use OSTools::Hardware;

  my $module_version = hw_module_version();
  my $manufacturer = hw_manufacturer();
  my $product_name = hw_product_name();
  my $serial_nr = hw_serial_number();
  my $sysinfo = hw_sysinfo();


=head1 DESCRIPTION

The C<OSTools::Hardware> module implements functions which
provide information about the system hardware.

The output of the C</usr/sbin/dmidecode> program is used to obtain
the values returned by the functions.
The information provided includes the manufacturer name,
the product name, and the serial number.

Also, there is a function to return the version string of the
C<Hardware> module itself.


=head2 EXPORT

=over 4

=item function C<OSTools::Hardware::hw_module_version>

A call to this function returns the version string of the module.
This version string is simply the CVS revision string of the
source file of the module.

=item function C<OSTools::Hardware::hw_manufacturer>

A call to this function returns a string with the manufacturer name.
Typically, for Teleflora systems, that name would be "Dell".

=item function C<OSTools::Hardware::hw_product_name>

A call to this function returns a string with the product name.
For example, a Daisy server might return "OptiPlex 380".

=item function C<OSTools::Hardware::hw_serial_number>

A call to this function returns a string with the system serial number.
For Dell systems, this is aka the "service tag number".

=item function C<OSTools::Hardware::hw_sysinfo>

This function returns a list with
the first element containing the manufacturer name,
the second element containing the serial number, and
the third element containing the product name.
If the first element of the list is the empty string, then
either the C</usr/sbin/dmidecode> program does not exist, or
the pipeline using that command could not be opened.

=back


=head1 SEE ALSO

updateos.pl, rtibackup.pl, tfsupport.pl, dmidecode(8)

=cut
