#! /usr/bin/perl 
#
# $Revision: 1.9 $
# Copyright 2009 Teleflora
#
# tfinfo.pl
#
# Report info about the Teleflora Daisy POS installation.
#

use strict;
use warnings;
use POSIX;
use Getopt::Long;
use English;
use File::Basename;


my $CVS_REVISION = '$Revision: 1.9 $';
my $TIMESTAMP = strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($0);

#=====================================#
# +---------------------------------+ #
# | Global variables                | #
# +---------------------------------+ #
#=====================================#
my $HARDWARE = "unknown";
my $DEF_RTIDIR = '/usr2/bbx';
my $DEF_DAISYDIR = '/d/daisy';
my $RTIDIR = "";
my $DSYDIR = "";
my $VERSION = 0;
my $HELP = 0;
my $RTI = 0;
my $DAISY = 0;


#=====================================#
# +---------------------------------+ #
# | Utility Functions               | #
# +---------------------------------+ #
#=====================================#
sub usage
{
	print "Usage:\n";
	print "$PROGNAME $CVS_REVISION\n";
	print "$PROGNAME --help         # output this help message and exit\n";
	print "$PROGNAME --version      # output version number and exit\n";
	print "$PROGNAME --rti          # report info about RTI installation\n";
	print "$PROGNAME --daisy        # report info about Daisy installation\n";
	print "$PROGNAME                # report info about Teleflora POS installation\n";
	print "\n";

	return "";
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
    my ($arg) = @_;

    my $temp = "";

    unless ($arg) {
	return "";
    }

    $temp = $arg;

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


sub validate_arg
{
    my ($arg) = @_;

    my $rc = 0;

    my $dsydir = validate_input($arg);
    if ($dsydir) {

	# make sure it is an absolute path
	if (substr($dsydir, 0, 1) eq '/') {

	    # make sure it's a daisy database directory
	    if ( (-d $dsydir) && (-f "$dsydir/control.dsy") ) {
		$rc = 1;
	    }
	    else {
		print("not a Daisy database directory: $dsydir\n");
	    }
	}
	else {
	    print("must be an absolute path: $dsydir\n");
	}
    }

    return($rc);
}


#=====================================#
# +---------------------------------+ #
# | Application Specific Functions  | #
# +---------------------------------+ #
#=====================================#

sub report_rti_dove_info
{
    my $rc = 0;

    my $RTIDIR = '/usr2/bbx';
    my $dove_ini_file = "$RTIDIR/config/dove.ini";

    if (-f $dove_ini_file) {
	if (open(my $fh, '<', $dove_ini_file)) {
	    my $shopcode = "";
	    while (<$fh>) {
		if (/DOVE_USERNAME\s*=\s*([[:print:]]+)/) {
		    $shopcode = $1;
		    last;
		}
	    }
	    close($fh);

	    if ($shopcode) {
		print "Teleflora Dove ID: $shopcode\n";
		$rc = 1;
	    }
	    else {
		print "Teleflora Dove ID not found in ini file: $dove_ini_file\n";
	    }
	}
	else {
	    print("could not open Dove init file: $dove_ini_file\n");
	}
    }
    else {
	print "Dove ini file does not exist: $dove_ini_file\n";
    }

    return($rc);
}


sub report_dove_info
{
    my ($dsydir) = @_;

    my $rc = 1;

    my $trcv_data_file = "$dsydir/trcvdat.pos";
    if (-f $trcv_data_file) {
	# use the mtime of the data file as an indication of
	# when the last Dove data was received.
	my $mtime = (stat($trcv_data_file))[9];

	# approximately 30 days per month, 24 hrs/day 60 mins/hr 60 secs/min
	my $lastmonth = time() - 30*24*60*60;
	if ($mtime < $lastmonth) {
	    print "Dove has received no data for a month\n";
	    $rc = 0;
        }
    }
    else {
	print "could not detect Dove activity, file does not exist: $trcv_data_file\n";
	$rc = 0;
    }

    return($rc) if ($rc != 1);

    #
    # If there is an active Dove, then what is the shop ID
    # entered for Primary ID by the florist.
    #
    my $dove_control_file = "$dsydir/dovectrl.pos";
    if (-f $dove_control_file) {
	if (open(my $dovefh, '<', $dove_control_file)) {
	    my $buffer = "";
	    sysread($dovefh, $buffer, 50);
	    close($dovefh);

	    printf("Teleflora Dove ID: %s\n", substr($buffer, 30, 9));
	}
	else {
	    print("could not open Dove control file: $dove_control_file\n");
	    $rc = 0;
	}
    }
    else {
	print "Dove control file does not exist: $dove_control_file\n";
	$rc = 0;
    }

    return($rc);
}

sub report_rti_florist_directory_info
{
    my $rc = 0;

    my $RTIDIR = '/usr2/bbx';
    my $rti_data_file = "$RTIDIR/bbxd/ONRO01";

    my $edir_date_string = "";
    my $edir_type_string = "";
    if (-f $rti_data_file) {
	#
	# bytes 60-65 contain a string which looks like: 'YY.MM' where
	# "MM" would be '08' (August), and YY would be '07' (2007).
	# Also, bytes 422-423 are the Directory Type.
	#
	if (open(my $fh, '<', $rti_data_file)) {
	    sysseek($fh, 60, 0);
	    sysread($fh, $edir_date_string, 5);
	    sysseek($fh, 422, 0);
	    sysread($fh, $edir_type_string, 2);
	    close($fh);
	    $rc = 1;
	}
	else {
	    print "could not open RTI florist directory data file: $rti_data_file\n";
	}
    }
    else {
	print "RTI florist directory data file does not exist: $rti_data_file\n";
    }

    if ($rc) {

	if ($edir_date_string =~ /(\d\d)\.(\d\d)/) {
	    my $edir_year = '20' . $1;
	    my $edir_month_nr = int($2);
	    my $edir_month_name = strftime("%B", 0, 0, 0, 0, $edir_month_nr, 0);
	    my $edir_type = ($edir_type_string eq "CB") ? "CMB" : "TEL";
	    my $edir_release = "$edir_month_name, $edir_year $edir_type";
	    print "Teleflora florist directory release: $edir_release\n";
	}
	else {
	    print "could not determine Teleflora directory release\n";
	    $rc = 0;
	}
    }

    return($rc);
}


sub report_florist_directory_info
{
    my ($dsydir) = @_;

    my $rc = 0;

    my $edir_control_file = "$dsydir/control.tel";
    if (-f $edir_control_file) {
	if (open(my $edirfh, '<', $edir_control_file)) {
	    my $firstline = <$edirfh>;
	    close($edirfh);

	    if ($firstline =~ /Teleflora (.+)$/) {
		print "Teleflora florist directory release: $1\n";
		$rc = 1;
	    }
	    else {
		print "could not determine Teleflora directory release\n";
	    }
	}
	else {
	    print "could not open Daisy florist directory control file: $edir_control_file\n";
	}
    }
    else {
	print "Daisy florist directory control file does not exist: $edir_control_file\n";
    }

    return($rc);
}


sub report_rti_version_nr
{
    my $rc = 0;

    my $RTIDIR = '/usr2/bbx';
    my $rti_ini_file = "$RTIDIR/bbxd/RTI.ini";

    my $buildnum = "";
    my $patchlev = "";
    if (-f $rti_ini_file) {
	if (open(my $fh, '<', $rti_ini_file)) {
	    while (<$fh>) {
		chomp;
		if (/^VERSION\s*=\s*([[:print:]]+)/) {
		    $buildnum = $1;
		}
		if (/^PATCH\s*=\s*([[:print:]]+)/) {
		    $patchlev = $1;
		}
	    }
	    close($fh);
	    if ($buildnum) {
		$buildnum .= $patchlev;
		print "RTI build version: $buildnum\n";
		$rc = 1;
	    }
	}
	else {
	    print "could not open RTI ini file: $rti_ini_file\n";
	}
    }
    else {
	print "RTI ini file does not exist: $rti_ini_file\n";
    }

    return($rc);
}


sub report_daisy_version_nr
{
    my ($dsydir) = @_;

    my $identify_cmd = "$dsydir/bin/identify_daisy_distro.pl";

    if (-x $identify_cmd) {
	my $line = qx($identify_cmd $dsydir);
	chomp $line;
	my ($product_name, $product_os, $product_country, $product_version, $product_dir) =
		split(/[[:space:]]/, $line);
	print("Daisy version: $product_version\n");
    }
    else {
	print("could not identify Daisy version - try running \"$dsydir/pos --version\".\n");
    }

    return(1);
}


sub report_tcc_version_nr
{
    my ($dir) = @_;

    my $rc = 1;

    my $tcc_cmd = ($dir eq $DEF_RTIDIR) ? "$DEF_RTIDIR/bin/tcc_tws" : "$dir/tcc/tcc";

    if (open(my $pipefh, '-|', "$tcc_cmd --version")) {
	while (<$pipefh>) {
	    chomp;
	    if (/Version: (.+)$/) {
		print "TCC version: $1\n";
		last;
	    }
	}
	close($pipefh);
    }
    else {
	print "could not get TCC version nr; could not open pipe to: $tcc_cmd\n";
	$rc = 0;
    }

    return($rc);
}


sub identify_hardware
{
    if (open(my $pipefh, '-|', '/usr/sbin/dmidecode')) {
	while (<$pipefh>) {
		if(/PowerEdge T300/) {
			$HARDWARE = "t300";
		} elsif (/PowerEdge T310/) {
			$HARDWARE = "t310";
		} elsif (/PowerEdge T410/) {
			$HARDWARE = "t410";
		} elsif (/PowerEdge 1800/) {
			$HARDWARE = "1800";
		} elsif (/PowerEdge 420/) {
			$HARDWARE = "420";
		} elsif (/PowerEdge R910/) {
			$HARDWARE = "r910";
		} elsif (/PowerEdge 2950/) {
			$HARDWARE = "2950";
		} elsif (/Precision 380/) {
			$HARDWARE = "Precision380";
		} elsif (/Precision 390/) {
			$HARDWARE = "Precision390";
		} elsif (/Precision T3400/) {
			$HARDWARE = "t3400";
		} elsif (/Precision T3500/) {
			$HARDWARE = "t3500";
		} else {
			$HARDWARE = "unknown";
		}
	}
	close($pipefh);
    }

    return(1);
}

#=====================================#
# +---------------------------------+ #
# | Main                            | #
# +---------------------------------+ #
#=====================================#

GetOptions (
	"version" => \$VERSION,
	"help" => \$HELP,
	"rti" => \$RTI,
	"daisy" => \$DAISY,
);


# --version
if($VERSION != 0) {
	print "OSTools Version: 1.15.0\n";
	print "$PROGNAME: $CVS_REVISION\n";
	exit 0;
}


# --help
if($HELP != 0) {
	usage();
	exit 0;
}

#
# If there is more than one command line argument, it's an error.
# If there is one command line argument, use it as the path to the
# daisy database directory.  If there are no command line args,
# then choose a POS.
#
if (@ARGV > 1) {
    usage();
    exit(1);
}
elsif (@ARGV == 1) {
    if (validate_arg($ARGV[0])) {
	$DSYDIR = $ARGV[0];
	$DAISY = 1;
    }
    else {
	usage();
	exit(1);
    }
}
else {
    if ($RTI) {
	unless (-d $DEF_RTIDIR) {
	    print "default RTI directory does not exist: $DEF_RTIDIR\n";
	    exit(1);
	}
    }
    if ($DAISY) {
	if (-d $DEF_DAISYDIR) {
	    $DSYDIR = $DEF_DAISYDIR;
	}
	else {
	    print "default Daisy directory does not exist: $DEF_DAISYDIR\n";
	    exit(1);
	}
    }
}

if ( ($RTI == 0) && ($DAISY == 0) ) {
    if (-d $DEF_RTIDIR) {
	$RTI = 1;
    }
    if (-d $DEF_DAISYDIR) {
	$DSYDIR = $DEF_DAISYDIR;
	$DAISY = 1;
    }
}

if ($RTI) {
    report_rti_dove_info();
    report_rti_florist_directory_info();
    report_tcc_version_nr($DEF_RTIDIR);
    report_rti_version_nr();
}
if ($DAISY) {
    report_dove_info($DSYDIR);
    report_florist_directory_info($DSYDIR);
    report_tcc_version_nr($DSYDIR);
    report_daisy_version_nr($DSYDIR);
}


exit(0);


__END__

=pod

=head1 NAME

tfinfo.pl - report information about the Teleflora Daisy POS

=head1 VERSION

This documenation refers to version: $Revision: 1.9 $


=head1 USAGE

tfinfo.pl [B<--rti>] [B<--daisy>]

tfinfo.pl B<--version>

tfinfo.pl B<--help>


=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--rti>

Report info on a RTI POS

=item B<--daisy>

Report info on a Daisy POS

=back


=head1 DESCRIPTION

The I<tfinfo.pl> script gathers information about a RTI or Daisy system,
such as Dove activity, the florist directory release date,
the TCC version number, and POS application version number, and
writes a short summary to stdout.

The script C<identify_daisy_distro.pl> is used to get the Daisy version number.

On RTI systems, the file C</usr2/bbx/tcc_tws> is used to get the version of TCC.

On Daisy systems, the fine C</d/daisy/tcc/tcc> is used to get the version of TCC.


=head1 EXAMPLE

The output looks like this:

    $ perl tfinfo.pl
    Teleflora Dove ID: 01234500
    Teleflora florist directory release: Sep 2015
    TCC version: 1.8.3
    Daisy version: 9.3.15


=head1 FILES

=over 4

=item B</usr2/bbx/bbxd/RTI.ini>

The RTI application "ini" file - contains the RTI version number.

=item B</usr2/bbx/bbxd/ONRO01>

The RTI file which contains the RTI florist directory release date.

=item B</usr2/bbx/config/dove.ini>

The RTI file which contains the Teleflora shop id.

=item B</d/daisy/control.dsy>

The Daisy control file.

=item B</d/daisy/control.tel>

The Daisy edir control file.

=item B</d/daisy/dovectrl.pos>

The Daisy Dove control file.

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status 0 ($EXIT_OK)

Successful completion.

=item Exit status 1 ($EXIT_COMMAND_LINE)

In general, there was an issue with the syntax of the command line.

=back


=head1 SEE ALSO

identify_daisy_distro.pl


=cut
