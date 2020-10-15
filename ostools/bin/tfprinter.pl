#!/usr/bin/perl

#
# $Revision: 1.32 $
# Copyright Teleflora 2010-2015
#
# tfprinter.pl
#
# Script to provide a convenient method of printing files to
# the various supported printers on Teleflora POS systems.
#

use strict;
use warnings;
use POSIX;
use IO::Socket;
use Getopt::Long;
use English;
use File::Basename;


my $CVS_REVISION = '$Revision: 1.32 $';
my $TIMESTAMP = strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($PROGRAM_NAME);

my $HELP = 0;
my $VERSION = 0;
my $DRYRUN = 0;
my $VERBOSE = 0;
my $LIST = 0;
my $SAMBA = 0;
my $JETDIRECT = 0;
my $IPP = 0;
my $LPD = 0;
my $PPD = ""; 
my $ADD = ""; 
my $DELETE = ""; 
my $CLEAR = ""; 
my $USER = ""; 
my $PASSWORD = ""; 
my $SHARE = ""; 
my $WKGRP = ""; 
my $PRINTTO = ""; 

my $RTIDIR = '/usr2/bbx';
my $DAISYDIR = '/d/daisy';

GetOptions(
"help" => \$HELP,
"version" => \$VERSION,
"dryrun" => \$DRYRUN,
"verbose" => \$VERBOSE,
"list" => \$LIST,
"samba" => \$SAMBA,
"jetdirect" => \$JETDIRECT,
"ipp" => \$IPP,
"lpd" => \$LPD,
"ppd=s" => \$PPD,
"add=s" => \$ADD,
"delete=s" => \$DELETE,
"clear=s" => \$CLEAR,
"user=s" => \$USER,
"password=s" => \$PASSWORD,
"print=s" => \$PRINTTO,
"share=s" => \$SHARE,
"workgroup=s" => \$WKGRP,
);


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
	my $printer = "";
	my %printers = ();
	%printers = list_printers();

	foreach $printer (sort(keys(%printers))) {
		printf("%-20s\t(%03d Jobs)\n", $printer, $printers{$printer});
	}

	exit(0);
}


# --add spoolname:printer.ip.address
if ($ADD) {
	$ADD = validate_input($ADD);
	exit(add_printer($ADD));
}

# --delete spoolname
if("$DELETE" ne "") {
	exit(delete_printer($DELETE));
}

# --clear spoolname
if("$CLEAR" ne "") {
	exit(clear_printqueues($CLEAR));
}


# --print=p1name
# --print=p2name,p2name,p3name,...
if("$PRINTTO" ne "") {
	exit(print_to_fastest_printer($PRINTTO));
}

usage();
exit(0);

#################################################################
#################################################################
#################################################################

sub usage
{
	print(<< "EOF");
Usage:
$PROGNAME --help
$PROGNAME --version
$PROGNAME --list
sudo $PROGNAME --add spoolname:/dev/lp0
sudo $PROGNAME --add spoolname:/dev/ttyS0
sudo $PROGNAME --add spoolname:/dev/usb/lp0
sudo $PROGNAME [--dryrun] --add spoolname:printer.ip.address
sudo $PROGNAME (--jetdirect | --ipp | --samba | --lpd) --ppd=ppd_file --add spoolname:printer.ip.address
sudo $PROGNAME --user=username --password=pw --share=sharename --workgroup=smbwkgrp --add spoolname:printer.ip.address
sudo $PROGNAME --delete spoolname
sudo $PROGNAME --clear spoolname
echo "Stuff to print" | $PROGNAME --print null
echo "Stuff to print" | $PROGNAME --print screen
echo "Stuff to print" | $PROGNAME --print spoolname
echo "Stuff to print" | $PROGNAME --print spoolname,spool2name,spool3name,...
echo "Stuff to print" | $PROGNAME --print pdf > /path/to/somefile.pdf

EOF
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
# Only Log actions to syslog, without display to screen.
#
sub loginfo
{
	my $message = $_[0];
	system("/usr/bin/logger -i -t \"$UID-tfprinter\.pl \" -- \"$message\"");
}


sub add_printer
{
	my $fullname =  $_[0];
	my $spoolname = "";
	my $ipaddr = "";
	my $protocol = "";
	my $thiskey = "";
	my %services = ();

	unless ($fullname) {
		return(-2);
	}

	#
	# Expected input:
	#	"spoolname" ":" "printer_ip_address", eg printer11:192.168.1.52
	#
	if ($fullname !~ /\S+:\S+/) {
		print("Error: Invalid printer name ($fullname): expecting \"name:ipaddress\".\n");
		return(-4);
	}

	($spoolname, $ipaddr) = split(/:/, $fullname);
	if ((! defined $spoolname) || (! defined $ipaddr)) {
		print("Error: Invalid printer name ($fullname): expecting \"name:ipaddress\".\n");
		return(-4);
	}

	# Don't add a spool which already exists.
	unless ($DRYRUN) {
	    if (does_spool_exist($spoolname) != 0) {
		    print("Error: printer \"$spoolname\" already exists.\n");
		    return(-5);
	    }
	}

	my $lpadmin_default_opt = "";
	my $lpadmin_desc_opt = "";
	my $lpadmin_name_opt = "";
	my $lpadmin_device_opt = "";
	my $lpadmin_opts = "";
	my $lpadmin_cmd = '/usr/sbin/lpadmin';
	my $enable_cmd = '/usr/sbin/cupsenable';
	my $accept_cmd = '/usr/sbin/accept';

	#
	# Now we can set the printer name option.
	#
	$lpadmin_name_opt = "-p \"$spoolname\"";

	#
	# If a PPD file path was specified on the command line, use it to form
	# an argument for the lpadmin command.
	#
	# The $PPD arg can be an empty string, a full path or a file in /d/daisy/config.
	# Init the $PPD arg to a raw queue so that if $PPD eq "", then the ppd arg will
	# specify a raw queue... NOTE, I could not find any documentation that "-m raw"
	# is what should be used for a raw queue, but trial and error shows that with
	# "-m raw" or just leaving off the "-m" option, you get a raw queue.
	# 
	my $ppd_arg = "-m raw";
	if ($PPD ne "") {
		if (-f $PPD) {
			$ppd_arg = "-P $PPD";
		}
		elsif (-f "$DAISYDIR/config/$PPD") {
			$ppd_arg = "-P $DAISYDIR/config/$PPD";
		}
		elsif (-f "$RTIDIR/config/$PPD") {
			$ppd_arg = "-P $RTIDIR/config/$PPD";
		} else {
			print("Error: PPD file \"$PPD\": no such file.\n");
			return(-6);
		}
	}


	# Default options when adding any printer.
	$lpadmin_default_opt .= " -o printer-error-policy=retry-job"; 
	$lpadmin_default_opt .= " -u allow:all";


	# Parallel Printer
	if("$ipaddr" =~ /\/dev\/lp/) {
		$lpadmin_desc_opt = "-D \"Teleflora Parallel Printer\"";
		$lpadmin_device_opt = "-v \"parallel:$ipaddr\"";

	# Serial Printer
	# http://www.cups.org/doc-1.1/sam.html
	} elsif ("$ipaddr" =~ /\/dev\/tty[^U]/) {
		$lpadmin_desc_opt = "-D \"Teleflora Serial Printer\"";
		$lpadmin_device_opt = "-v \"serial:$ipaddr\"";

	# Local USB Printer
	} elsif ("$ipaddr" =~ /\/dev\/usb/) {
		$lpadmin_desc_opt = "-D \"Teleflora USB Printer\"";
		$lpadmin_device_opt = "-v \"usb:$ipaddr\"";

	# LPD Printer
	# Good solution for Windows 7 Home Premium
	} elsif ($LPD) {
		my $protocol_name = 'lpd';	# LPD protocol name
		my $portnr = 515;		# LPD protocol port number

		unless ($DRYRUN) {
		    unless (does_port_respond($ipaddr, $portnr)) {
			    loginfo("No response from ipaddr $ipaddr at port $portnr");
			    return(-7);
		    }
		}

		$lpadmin_desc_opt = "-D \"Teleflora $protocol_name Network Printer\"";
		$lpadmin_device_opt = "-v \"$protocol_name://$ipaddr\"";
		if ($SHARE) {
			$lpadmin_device_opt = "-v \"$protocol_name://$ipaddr/$SHARE\"";
		}

	# JETDIRECT Printer
	} elsif ($JETDIRECT) {
		my $protocol_name = 'socket';	# JETDIRECT protocol name
		my $portnr = 9100;		# JETDIRECT protocol port number

		unless ($DRYRUN) {
		    unless (does_port_respond($ipaddr, $portnr)) {
			    loginfo("No response from ipaddr $ipaddr at port $portnr");
			    return(-7);
		    }
		}

		$lpadmin_desc_opt = "-D \"Teleflora $protocol_name Network Printer\"";
		$lpadmin_device_opt = "-v \"$protocol_name://$ipaddr\"";

	# IPP Printer
	} elsif ($IPP) {
		my $protocol_name = 'ipp';	# IPP protocol name
		my $portnr = 631;		# IPP protocol port number

		unless ($DRYRUN) {
		    unless (does_port_respond($ipaddr, $portnr)) {
			    loginfo("No response from ipaddr $ipaddr at port $portnr");
			    return(-7);
		    }
		}

		$lpadmin_desc_opt = "-D \"Teleflora $protocol_name Network Printer\"";
		$lpadmin_device_opt = "-v \"$protocol_name://$ipaddr\"";

	# Samba Printer
	} elsif ($SAMBA) {
		my $protocol_name = 'smb';	# Samba protocol name
		my $portnr = 445;		# Samba protocol port number

		unless ($DRYRUN) {
		    unless (does_port_respond($ipaddr, $portnr)) {
			    loginfo("No response from ipaddr $ipaddr at port $portnr");
			    return(-7);
		    }
		}

		$lpadmin_desc_opt = "-D \"Teleflora $protocol_name Network Printer\"";
		$lpadmin_device_opt = form_samba_device_url($ipaddr);

	# Test for some kind of Network Printer
	} else {

		# Try each connection type in turn... first one that responds wins.
		$services{"01 lpd"} = 515;
		$services{"02 smb"} = 445;
		$services{"03 socket"} = 9100;
		$services{"04 ipp"} = 631;
		$services{"05 http"} = 80;

		foreach $thiskey (sort keys(%services)) {

			next unless (does_port_respond($ipaddr, $services{$thiskey}));
			
			# "01 keyname" -> "keyname"
			$protocol = $thiskey;
			$protocol =~ s/^\d\d\s//g;

			if ("$protocol" eq "smb") {
				$lpadmin_desc_opt = "-D \"Teleflora Samba Network Printer\"";
				$lpadmin_device_opt = form_samba_device_url($ipaddr);

			} else {
				$lpadmin_desc_opt = "-D \"Teleflora $protocol Network Printer\"";
				$lpadmin_device_opt = "-v \"$protocol://$ipaddr\"";
			}

			last;
		}
		if ($lpadmin_device_opt eq "") {
			loginfo("No response from ports: 80, 445, 515, 631, 9100 at $ipaddr");
		}
	}

	if ($lpadmin_device_opt eq "") {
		return(7);
	}

	if ($DRYRUN) {
		$lpadmin_cmd = "echo $lpadmin_cmd";
		$enable_cmd = "echo $enable_cmd";
		$accept_cmd = "echo $accept_cmd";
	}

	# gather up the options
	$lpadmin_opts = "$lpadmin_name_opt $lpadmin_desc_opt $lpadmin_device_opt $ppd_arg";

	unless ($DRYRUN) {
		print("adding printer: $lpadmin_cmd $lpadmin_default_opt $lpadmin_opts\n");
		loginfo("add printer: $lpadmin_cmd $lpadmin_default_opt $lpadmin_opts");
	}

	system("$lpadmin_cmd $lpadmin_default_opt $lpadmin_opts");
	if ($? != 0) {
		unless ($DRYRUN) {
			loginfo("$lpadmin_cmd returns non-zero status: $?");
			loginfo("printer $spoolname not added");
		}
		return(8);
	} else {
		unless ($DRYRUN) {
			print("printer $spoolname added\n");
			loginfo("printer $spoolname added");
		}
	}

	system("$enable_cmd $spoolname");
	system("$accept_cmd $spoolname");

	return(0);
}


sub delete_printer
{
	my $spoolname =  $_[0];

	if(does_spool_exist($spoolname) == 0) {
		print("Printer \"$spoolname\" Does not exist.\n");
		return(0);
	}

	system("/usr/sbin/lpadmin -x \"$spoolname\"");
	if(does_spool_exist($spoolname) == 0) {
		print("Printer \"$spoolname\" Removed Successfully.\n");
		return(0);
	} else {
		print("Error Removing Printer \"$spoolname\".\n");
		return(1);
	}

	
	return(2);
}


# Put together a list of printers and their queue sizes.
sub list_printers
{
	my @array = ();
	my $count = 0;
	my $printer = "";
	my %results = ();

	$results{"null"} = -1;
	$results{"screen"} = -1;
	open(PRINTERS, "lpstat -a 2>&1 |");
	while(<PRINTERS>) {
		chomp;
		next if (/^\s+/);
		next if (/No destinations added/);
		@array = split(/\s+/);
		$printer = $array[0];

		unless (defined($printer)) {
			next;
		}

		$count = 0;
		open(JOBS, "lpq -P $printer |");
		while(<JOBS>) {
			next if (/^Rank/);
			next if (/ is ready/);
			if(/^no entries/) {
				$count = 0;
				last;
			}
			$count++;
		}
		close(JOBS);
		$results{$printer} = $count;
	}
	close(PRINTERS);


	return(%results);
}


# Given a list of "candidate" printers, print the contents of STDIN to 
# that printer who's queue is smallest.
# This allows us to sort of "load balance" printers.
sub print_to_fastest_printer
{
	my $destprinters = $_[0];
	my @candidates = ();
	my %printers = ();
	my $printer = "";
	my $keyval = "";
	my $queuesize = 0;


	# We were given just one printer.
	if($destprinters !~ /,/) {
		$printer = $destprinters;

	# We were given more than one printer to send to in the form of a comma separated list.
	} else {


		# "pr1,pr2,pr3" -> @candidates
		@candidates = split(/,/, $destprinters);
		%printers = list_printers();

		$queuesize = 1000000000; # Infinite.
		$printer = $candidates[0];
		foreach $keyval (keys(%printers)) {
			next until grep(/^$keyval$/, @candidates);

			if( $printers{$keyval} <= $queuesize) {
				$printer = $keyval;
				$queuesize = $printers{$keyval};
			}
		}
	}


	# Read from stdin, write to an 'lp' job for our printer.
	# If we are printing to the 'null' printer, then, do nothing.
	# If we are printing to the 'screen' printer, then, send to stdout.
	if ($printer eq "screen") {
		while (<STDIN>) {
			print(STDOUT);
		}

	# Read from STDIN, create a PDF file and send that to STDOUT.
	} elsif ($printer eq "pdf") {
		system("a2ps --quiet --portrait --no-header --borders no --truncate-lines no --delegate no --margin=0 -o - | ps2pdf - -");

	} elsif ($printer ne "null") {
		open(PIPE, "| lp -d$printer -s 2> /dev/null");
		while(<STDIN>) {
			print(PIPE);
		}
		close(PIPE);

	}

	return(0);
}



sub clear_printqueues
{
	my $spoolname =  $_[0];

	if(does_spool_exist($spoolname) == 0) {
		print("Printer \"$spoolname\" Does not exist.\n");
		return(0);
	}

	system("cancel -a $spoolname");
	print("Queue Cleared for printer \"$spoolname\"");
	return(0);
}

#
# Form the Samba device option
#
# Examples:
#	-v smb://ipaddress/SHARE -m raw
#	-v smb://USER@WKGRP/ipaddress/SHARE -m raw
#	-v smb://USER:PASSWORD@WKGRP/ipaddress/SHARE -m raw
#
sub form_samba_device_url
{
	my $ipaddr = $_[0];

	if ($ipaddr eq "") {
		return("");
	}

	my $device_url = "-v smb://";

	if ($USER ne "") {
		$device_url .= "$USER";
		if ($PASSWORD ne "") {
			$device_url .= ":$PASSWORD";
		}
		if ($WKGRP ne "") {
			$device_url .= "\@$WKGRP";
			$device_url .= "/";
		}
	}
	$device_url .= "$ipaddr";
	if ($SHARE ne "") {
		$device_url .= "/$SHARE";
	}

	return($device_url);
}

#
# Does something respond at this address/port?
#
# Return TRUE (non-zero) if something responds, FALSE (0) otherwise
#
sub does_port_respond
{
	my $ipaddr = $_[0];
	my $port = $_[1];
	my $rc = 0;

	if ($VERBOSE) {
		print("looking for response at ip addr $ipaddr port $port...\n");
	}

	my $sock = IO::Socket::INET->new(
		Proto => "tcp",
		PeerAddr => "$ipaddr",
		PeerPort => "$port",
		Timeout => 1
	);
	if ($sock) {
		close($sock);
		$rc = 1;
		if ($VERBOSE) {
			print("got response\n");
		}
	} else {
		if ($VERBOSE) {
			print("no response\n");
		}
	}

	return($rc);
}


sub does_spool_exist
{
	my $spoolname = $_[0];
	my @array = ();
	my $found = 0;

	open(PRINTERS, "lpstat -a 2>&1 |");
	while(<PRINTERS>) {
		chomp;
		#
		# lpstat can return lines with only white space
		#
		next if (/^\s+/);
		next if (/No destinations added/);
		@array = split(/\s+/);
		if (defined($array[0])) {
			if ($spoolname eq $array[0]) {
				$found = 1;
				last;
			}
		}
	}
	close(PRINTERS);
	
	return($found);
}

sub pinghost
{
	my $hostname = $_[0];

	my $p = Net::Ping->new("icmp", 2);
	$p->ping($hostname);

}

__END__


=pod

=head1 NAME

tfprinter.pl - Teleflora Printer Maintenance


=head1 VERSION

This documenation refers to version: $Revision: 1.32 $


=head1 USAGE

./tfprinter.pl --help

./tfprinter.pl --version

./tfprinter.pl --list

sudo ./tfprinter.pl --add spoolname:/dev/lp0

sudo ./tfprinter.pl --add spoolname:/dev/ttyS0

sudo ./tfprinter.pl --add spoolname:/dev/usb/lp0

sudo ./tfprinter.pl [--dryrun] --add spoolname:printer.ip.address

sudo ./tfprinter.pl (--jetdirect | --ipp | --samba | --lpd) --ppd=ppd_file --add spoolname:printer.ip.address

sudo ./tfprinter.pl --user=username --password=pw --share=sharename --workgroup=smbwkgrp --add spoolname:printer.ip.address

sudo ./tfprinter.pl --delete spoolname

sudo ./tfprinter.pl --clear spoolname

echo "Stuff to print" | ./tfprinter.pl --print null

echo "Stuff to print" | ./tfprinter.pl --print screen

echo "Stuff to print" | ./tfprinter.pl --print spoolname

echo "Stuff to print" | ./tfprinter.pl --print spoolname,spool2name,spool3name,...

echo "Stuff to print" | ./tfprinter.pl --print pdf > /path/to/somefile.pdf


=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--dryrun>

Output what the command will do without actually making the changes.

=back


=head1 DESCRIPTION

This script 


=head1 FILES

=over 4

=item B</var/log/messages>

The default log file.

=item B</etc/redhat-release>

The file that contains the platform release version information.

=item B</var/log/cups>

Location of printing log files.

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status 0

Successful completion.

=back


=head1 SEE ALSO

C</etc/cups/cupsd.conf>,
C<cupsenable(1)>,
C<cupsdisable(1)>,
C<lpadmin(1)>,
C<lpstat(1)>,
C</etc/init.d/cups>,
C</var/log/cups>,


=cut
