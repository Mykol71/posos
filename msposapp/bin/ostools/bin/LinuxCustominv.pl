#!/usr/bin/perl
#
# $Revision: 1.41 $
#
# LinuxCustominv.pl
#
# Script which creates various "custom inventory" scripts for
# RTI Altiris agent.
#
# Note that this script has been written in a way that it is usasble under Daisy as well, thus
# making changes in one POS easier to 'port to' the other.
#
# This file should be located under:
# /opt/altiris/notification/nsagent/var/packages/{*
# This file is automagically downloaded by the Altiris client as a package. The package also 
# manages how often the script is run.
#
#
# How to Add a new Custom Inventory Script.
# Ie, how to add a new custom inventory "report" such that it shows up under Altiris.
# Basically, copy and paste from an existing script. There are a few places in here which
# need attention.
#
# 1) Create a new global variable (eg my $DOVEERRORS)
# 2) Add an entry in the GetOptions() function call.
# 3) Create a new subroutine for this functionality (eg sub custominv_dove_errors)
# 4) Add an "} elsif" condition which calls your new subroutine.
# 5) Add an entry into checkin()'s "foreach" loop.
# 

use strict;
use warnings;
use POSIX;
use Getopt::Long;
use File::Basename;
use File::stat;

use lib qw( /teleflora/ostools/modules /d/ostools/modules /usr2/ostools/modules );
use OSTools::Platform;
use OSTools::Hardware;
use OSTools::AppEnv;
use OSTools::Filesys;


my $CVS_REVISION = '$Revision: 1.41 $';
my $TIMESTAMP = strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($0);

my $VERSION = 0;
my $VERSIONS = 0;
my $CONFIGS = 0;
my $CHECKIN = 0;
my $DMESG = 0;
my $SECURE = 0;
my $BBXERRORS = 0;
my $DOVEERRORS = 0;
my $KIOSKERRORS = 0;
my $WATCHRTI = 0;
my $ADMINEXPIRES = 0;
my $errorstats = 0;
my $rti = 0;
my $daisy = 0;
my $SYSINFO = 0;
my $updates = 0;
my $filelist = "";
my $install = 0;
my $RTILOGS = 0;




my $ALTIRIS_DIR = "/opt/altiris";
my $CUSTOMINV_DIR= "$ALTIRIS_DIR/notification/nsagent/var/packages/{B89D89CA-DF94-4FC6-8DE4-D2EB4BB50984}";


#
# Changes to reflect Daisy or RTI
#
my $POS = "";
my $POSDIR = ""; # Root directory for our POS.
my $USERSCRIPT = ""; 

my @ARGV_ORIG = @ARGV;


GetOptions(

	"version" => \$VERSION,
	"checkin" => \$CHECKIN,
	"rti" => \$rti,
	"daisy" => \$daisy,

	"dmesg" => \$DMESG,
	"secure" => \$SECURE,
	"versions" => \$VERSIONS,
	"configs" => \$CONFIGS,
	"sysinfo" => \$SYSINFO,
	"bbx" => \$BBXERRORS,
	"dove" => \$DOVEERRORS,
	"errorstats" => \$errorstats,
	"kiosk" => \$KIOSKERRORS,
	"watchrti" => \$WATCHRTI,
	"adminexpires" => \$ADMINEXPIRES,
	"updates" => \$updates,
	"rtilogs" => \$RTILOGS,
);


# --version
if($VERSION != 0) {
	print "OSTools Version: 1.15.0\n";
	print "$PROGNAME: $CVS_REVISION\n";
	exit 0;
}



# Unless --daisy is specified, assume --rti
if($daisy != 0) {
	$POS = "DAISY";
} elsif ($rti != 0) {
	$POS = "RTI";

# We have to guess at which POS we are looking at.
} else {

	if(-d "/d/daisy") {
		$POS = "DAISY";
	} else {
		$POS = "RTI";
	}
}


if($POS eq "DAISY") {
	$POSDIR = "/d/daisy";
	$USERSCRIPT = "/d/daisy/bin/dsyuser.pl";
} else {
	if(-f "/etc/profile.d/rti.sh") {
		open FILE, "< /etc/profile.d/rti.sh";
		while(<FILE>) {
			if(/(RTI_DIR)(\s*)(=)(\s*)([[:print:]]+)/) {
				$POSDIR = $5;
				last;
			}
		}
		close FILE;
	}
	if(! -d "$POSDIR") {
		$POSDIR = "/usr2/bbx";
	}
	$USERSCRIPT = "$POSDIR/bin/rtiuser.pl";
}



# 
# Note that options such as "--dove" and "--kiosk" have a different meaning
# depending on whether "--checkin" was specified.
# If "--dove", without "--checkin", then, we just run the Dove report and spit to stdout.
# if, however, "--checkin" *and* "--dove", then, we run a checkin consisting only with the "dove" report.
# 
if($CHECKIN != 0) {


	# Set all options "on" by default if only "--checkin" is specified.
	if( ($DMESG == 0)
	&&  ($SECURE == 0)
	&&  ($VERSIONS == 0)
	&&  ($CONFIGS == 0)
	&&  ($SYSINFO == 0)
	&&  ($BBXERRORS == 0)
	&&  ($DOVEERRORS == 0)
	&&  ($KIOSKERRORS == 0)
	&&  ($WATCHRTI == 0)
	&&  ($ADMINEXPIRES == 0)
	) {
		#$DMESG = 1;
		#$SECURE = 1;
		#$VERSIONS = 1;
		#$CONFIGS = 1;
		$SYSINFO = 1;
		#$BBXERRORS = 1;
		#$DOVEERRORS = 1;
		#$KIOSKERRORS = 1;
		#$WATCHRTI = 1;
	}

	if($RTILOGS != 0) {
		$DMESG = 1;
		$SECURE = 1;
		$VERSIONS = 1;
		$CONFIGS = 1;
		$SYSINFO = 1;
		$BBXERRORS = 1;
		$DOVEERRORS = 1;
		$KIOSKERRORS = 1;
		$WATCHRTI = 1;
	}


	# Intentionally disable Dove for now.
	# we are seeing a flood of data from Dove for reasons we 
	# cannot explain.
	$DOVEERRORS = 0;




	checkin();


# --checkin not specified on commandline.
} else {



	if($VERSIONS != 0) {
		custominv_rti_versions();

	} elsif($CONFIGS != 0) {
		custominv_rti_configs();

	} elsif($DMESG != 0) {
		custominv_dmesg();
	} elsif($SECURE != 0) {
		custominv_secure();


	} elsif($SYSINFO != 0) {
		custominv_sysinfo();
	} elsif($BBXERRORS != 0) {
		custominv_rti_rtibbx_errors();
	} elsif($DOVEERRORS != 0) {
		custominv_rti_dove_errors();
	} elsif($KIOSKERRORS!= 0) {
		custominv_rti_kiosk_errors();
	} elsif($WATCHRTI != 0) {
		custominv_rti_watchrti_errors();
	} elsif($ADMINEXPIRES != 0) {
		custominv_admin_expires();

	} elsif($errorstats != 0) {
		if($POS ne "daisy") {
			custominv_rti_errorstats();
		}

	} elsif($updates != 0) {
		get_updates();
	} elsif($RTILOGS != 0) {
		custominv_rti_versions();
		custominv_rti_configs();
		custominv_dmesg();
		custominv_secure();
		custominv_sysinfo();
		custominv_rti_rtibbx_errors();
		custominv_rti_dove_errors();
		custominv_rti_kiosk_errors();
		custominv_rti_watchrti_errors();
		custominv_admin_expires();
		custominv_rti_errorstats();
	} else {
		usage();
	}
}




exit 0;

#####################################################################################
#####################################################################################
#####################################################################################

sub usage
{
	print "\n";
	print "Usage:\n";
	print "$0 " . '$Revision: 1.41 $' . "\n";
	print "$0 --checkin\tSee if Altiris is alive, sign into server.\n";
	print "$0 --version\tPrint version of this script.\n";
	print "\n";
}


#
# Send custom inventory, receive packages.
#
sub checkin
{
	my $parameter = "";

	# Send Custom Inventory.
	if(! -d "$CUSTOMINV_DIR") {
		print "Error: Could not find Custom Inventory Directory '$CUSTOMINV_DIR'\n";
		print "Perhaps installation did not complete fully?\n";
		return "";
	}


	#
	# This is the script which 'aex-runinvnow' looks for when executed.
	#  We are dynamically creating this with the intent that we need only update this script 
	# in order to have an 'up-to-date' version of everything else altiris.
	#
	open SCRIPT, "> $CUSTOMINV_DIR/aex-invagent-tfcustom" or die "Could not open custom inventory script. $!";

	print SCRIPT "#!/bin/bash\n";
	print SCRIPT "#\n";
	print SCRIPT "# This script automatically generated by $0\n";
	print SCRIPT "# This script called with command line of: $0 @ARGV_ORIG\n";
	print SCRIPT "#\n";
	print SCRIPT "\n";

	my $LDLIBPATH = "$ALTIRIS_DIR/notification/nsagent/lib";
	my $AEXAGENT = "$CUSTOMINV_DIR/aex-invagent-generic";
	my $PROGPATH = "$ENV{'PWD'}/" . basename($0);

	if($DMESG != 0) {
		print SCRIPT "LD_LIBRARY_PATH=$LDLIBPATH $AEXAGENT \"$PROGPATH --dmesg\"\n";
	}
	if($SECURE != 0) {
		print SCRIPT "LD_LIBRARY_PATH=$LDLIBPATH $AEXAGENT \"$PROGPATH --secure\"\n";
	}
	if($VERSIONS != 0) {
		print SCRIPT "LD_LIBRARY_PATH=$LDLIBPATH $AEXAGENT \"$PROGPATH --versions\"\n";
	}
	if($CONFIGS != 0) {
		print SCRIPT "LD_LIBRARY_PATH=$LDLIBPATH $AEXAGENT \"$PROGPATH --configs\"\n";
	}
	if($SYSINFO != 0) {
		print SCRIPT "LD_LIBRARY_PATH=$LDLIBPATH $AEXAGENT \"$PROGPATH --sysinfo\"\n";
	}
	if($BBXERRORS != 0) {
		print SCRIPT "LD_LIBRARY_PATH=$LDLIBPATH $AEXAGENT \"$PROGPATH --bbx\"\n";
	}
	if($DOVEERRORS != 0) {
		print SCRIPT "LD_LIBRARY_PATH=$LDLIBPATH $AEXAGENT \"$PROGPATH --dove\"\n";
	}
	if($KIOSKERRORS != 0) {
		print SCRIPT "LD_LIBRARY_PATH=$LDLIBPATH $AEXAGENT \"$PROGPATH --kiosk\"\n";
	}
	if($WATCHRTI != 0) {
		print SCRIPT "LD_LIBRARY_PATH=$LDLIBPATH $AEXAGENT \"$PROGPATH --watchrti\"\n";
	}
	if($ADMINEXPIRES != 0) {
		print SCRIPT "LD_LIBRARY_PATH=$LDLIBPATH $AEXAGENT \"$PROGPATH --adminexpires\"\n";
	}


	close SCRIPT;
	system "chown root $CUSTOMINV_DIR/aex-invagent-tfcustom";
	system "chmod 755 $CUSTOMINV_DIR/aex-invagent-tfcustom";

	#
	# clear the old queue so new xml report files will be generated.
	#
	system "rm -f $ALTIRIS_DIR/notification/nsagent/var/queue/*";

	#
	# now run the script which will cause reports to be generated.
	#
	system "cd $CUSTOMINV_DIR && ./aex-runinvnow";

}


#
# Invoke user interface for running packages.
#
sub get_updates
{
	system "$ALTIRIS_DIR/notification/nsagent/bin/aex-swdapm";
}





sub custominv_dmesg
{
	my $timestamp  = strftime("%Y-%m-%d %H:%M:%S", localtime());
	my $line = "";

	# Headers
	print "AeX_CI_Teleflora_" . $POS . "_dmesg\n";
	print "Delimiters = \",\"\n";
	print "string19 string128\n";
	print "Timestamp Message\n";


	open PIPE, "dmesg |";
	while(<PIPE>) {
		chomp;
		$line = $_;
		$line =~ s/,/_/g;
		print "$timestamp,$line\n";
	}
	close PIPE;

}


# /var/log/secure
sub custominv_secure
{
	my $line = "";
	my $month = "";
	my $day = "";
	my $year = strftime("%Y", localtime);
	my $timestamp = "";




	# Headers
	print "AeX_CI_Teleflora_" . $POS . "_secure\n";
	print "Delimiters = \",\"\n";
	print "string19 string128 string100\n";
	print "Timestamp Message ErrorFile\n";




	open FILE, "tail -n 1000 /var/log/secure |";
	while(<FILE>) {
		chomp;

		#
		# Aug 15 18:13:11 Stuff follows here.
		# Transformed to ...
		# 2007-08-15 18:13:11 Stuff follows here.
		#
		$line = $_;
		if(/^(\w+)(\s+)(\d+)(\s+)(\d\d:\d\d:\d\d)(\s+)([[:print:]]+)/) {
			$month = $1;
			$day = $3;
			$timestamp = $5;
			$line = $7;

			if($month eq "Jan") {
				$month = "01";
			} elsif ($month eq "Feb") {
				$month = "02";
			} elsif ($month eq "Mar") {
				$month = "03";
			} elsif ($month eq "Apr") {
				$month = "04";
			} elsif ($month eq "May") {
				$month = "05";
			} elsif ($month eq "Jun") {
				$month = "06";
			} elsif ($month eq "Jul") {
				$month = "07";
			} elsif ($month eq "Aug") {
				$month = "08";
			} elsif ($month eq "Sep") {
				$month = "09";
			} elsif ($month eq "Oct") {
				$month = "10";
			} elsif ($month eq "Nov") {
				$month = "11";
			} elsif ($month eq "Dec") {
				$month = "12";
			} else {
				$month = "01";
			}
			
		}
		$line =~ s/,/_/g;
		print "$year-$month-$day $timestamp,$line,/var/log/secure\n";
	}
	close FILE;

}


#
# Note that these field names are intentionally named similar to those in Dove POS
# to ease naming conventions on the server side.
#
sub custominv_sysinfo
{
	my @array = ();
	my $filename = "";
	my $filestat = "";
	my $string = "";
	my $string2 = "";
	my $shopcode = "Unknown";
	my $postype = "$POS";
	my $buildnum = "Unknown";
	my $patchlev = "";
	my $installdate = "Unknown";
	my $installdir = "$POSDIR";
	my $edirectory = "Unknown";
	my $publicip = "Unknown";
	my $custominv_version = "Unknown";
	my $platform_id = plat_os_version();


	# Headers
	print "AeX_CI_Teleflora_" . $POS . "_SystemInformation\n";
	print "Delimiters = \",\"\n";
	print "string20 string10 string14 string20 string255 string10 string10 string20 string20\n";
	print "ShopCode POSType CurrentVersion CurrentInstallDate InstallDirectory InstallType TFEEdition PublicIP CustomInvVersion\n";



	# RTI specific findings.
	if($POS eq "RTI") {

		# Dove ID
		if(-f "$POSDIR/config/dove.ini") {
			open FILE, "< $POSDIR/config/dove.ini";
			while(<FILE>) {
				if(/(DOVE_USERNAME)(\s*)(=)(\s*)([[:print:]]+)/) {
					$shopcode = $5;
				}
			}
			close FILE;
		}


		# Build / CurrentVersion
		if(-f "$POSDIR/bbxd/RTI.ini") {
			$buildnum = "Unknown";
			open FILE, "< $POSDIR/bbxd/RTI.ini";
			while(<FILE>) {
				chomp;
				if(/^(VERSION)(\s*)(=)(\s*)([[:print:]]+)/) {
					$buildnum = $5;
				}
				if(/^(PATCH)(\s*)(=)(\s*)([[:print:]]+)/) {
					$patchlev = $5;
					last;
				}
			}
			$buildnum = $buildnum . $patchlev;
			close FILE;
		} else {
			$buildnum = "No .INI File";
		}


		# Install Date
		$installdate = "Unknown";
		$filename = `ls -tr /root/rti_install*.log 2> /dev/null | tail -1`;
		if($filename) {
			chomp($filename);
			if("$filename" ne "" && -f "$filename") {
				chomp($filename);
				open PIPE, "< $filename";
				while(<PIPE>) {
					if(/(Install Started )(\d+)(-)(\d+)(-)(\d+)/) {
						$installdate = $2 . $4 . $6;
					}
				}
				close PIPE;
			}
		}




		# Install Directory
		# RTI is technically 'installed' wherever our profile.d is pointing to.
		$installdir = "Unknown";
		if(-f "/etc/profile.d/rti.sh") {
			open FILE, "< /etc/profile.d/rti.sh";
			while(<FILE>) {
				if(/(RTI_DIR)(\s*)(=)(\s*)([[:print:]]+)/) {
					$installdir = $5;
					last;
				}
			}
			close FILE;
		}



		# eDirectory Version
		if(-f "$POSDIR/bbxd/ONRO01") {

			#
			# This from Scott Buckholtz.
			# Basically we read from bytes 60-65 for a string which
			# looks like... YY.MM
			# Where "MM" would be '08' (August), and YY would be
			# '07' (2007).  There is a 14 byte file header offset
			# from the RTI file layout
			#
			open FILE, "< $POSDIR/bbxd/ONRO01";
			sysseek (FILE,60,0);
			sysread (FILE, $string,5);
			# and bytes 422-423 for Directory Type
			sysseek (FILE,422,0);
			sysread (FILE, $string2,2);
			close FILE;

			# XX.YY
			@array = split (/\./, $string);
			if( (int($array[1]) == 2) 
			||  (int($array[1]) == 3)
			||  (int($array[1]) == 4) ) {
				$edirectory = "FMA" . (2000 + int($array[0]));

			} elsif( ( int($array[1]) == 5)
			||       ( int($array[1]) == 6)
			||       ( int($array[1]) == 7) ) {
				$edirectory = "MJJ" . (2000 + int($array[0]));

			} elsif( ( int($array[1]) == 8) 
			||       ( int($array[1]) == 9)
			||       ( int($array[1]) == 10) ) {
				$edirectory = "ASO" . (2000 + int($array[0]));

			} elsif( ( int($array[1]) == 11) 
			||       ( int($array[1]) == 12)
			||       ( int($array[1]) == 1) ) {
				$edirectory = "NDJ" . (2000 + int($array[0]));
			} else {
				$edirectory = $string;
			}

			if ($string2 eq "CB") {
				$edirectory = $edirectory . "CMB";
			} else {
				$edirectory = $edirectory . "TEL";
			}

		}



	} elsif ($POS eq "DAISY") {

		# Shop Code
		$shopcode = "Unknown";

		my $buffer;
		my $dove_control_file = "$POSDIR/dovectrl.pos";
		if (-f $dove_control_file) {
			if (open(DF, $dove_control_file)) {
				my $rc = sysread(DF, $buffer, 38);
				if (defined($rc) && $rc != 0) {
					$shopcode = substr($buffer, 30, 8);
				}
				close(DF);
			}
		}

		# Current Version / Build
		if (-f "$POSDIR/config/daisybuildinfo.txt") {
			open FILE, "< $POSDIR/config/daisybuildinfo.txt";
			while(<FILE>) {
				chomp;
				if(/^(Build Number:)(\s+)([[:print:]]+)/) {
					$buildnum = $3;
					last;
				}
			}
			close FILE;

		} else {
			my $LDLIBPATH = "/lib:/usr/lib";
			open PIPE, "LD_LIBRARY_PATH=$LDLIBPATH $POSDIR/pos --version |";
			while(<PIPE>) {
				chomp;
				if (/(Build Number:)(\s*)([[:print:]]+)/) {
					$buildnum = $3;
					last;
				}
			}
			close PIPE;

		}


		# Install date.
		# The best we have for daisy is the timestamp of the newest 'daisy'
		# installation log or in lieu of that, the date of /d/daisy directory.
		$installdate = "Unknown";
		my @logfiles = glob("$POSDIR/log/daisy_install*.log");
		if (@logfiles) {
			$filename = qx(ls -tr $POSDIR/log/daisy_install*.log 2> /dev/null | tail -1);
			chomp($filename);
			if ($filename ne "" && -f $filename) {
				$filestat = stat($filename);
				$installdate = strftime("%Y%m%d", localtime($filestat->mtime));
			}
		} else {
			$filename = '/d/daisy';
			if (-d $filename) {
				$filestat = stat($filename);
				$installdate = strftime("%Y%m%d", localtime($filestat->mtime));
			}
		}


		# Install Directory.
		$installdir = $POSDIR;


		# In Daisy, the eDirectory version is the first line
		# in the file "control.tel".
		if (-e "$POSDIR/control.tel") {
		    if (open(my $telfh, '<', "$POSDIR/control.tel")) {
			$edirectory = <$telfh>;
			close($telfh);
		    }
		}

		# remove trailing NEWLINE and any leading SPACEs
		chomp($edirectory);
		$edirectory =~ s/^\s+//;

		# In Daisy, the book name of the daily edir update is in the
		# edir_update.pl config file:
		my $edir_book = "UNK";
		if (-e "$POSDIR/config/edir_update.conf") {
		    if (open(my $conf_fh, '<', "$POSDIR/config/edir_update.conf")) {
			while(my $line = <$conf_fh>) {
			    chomp($line);
			    if ($line =~ /^\s*edir-book\s*=\s*(...)/) {
				$edir_book = uc($1);
				last;
			    }
			}
			close($conf_fh);
		    }
		}

		#
		# Previously (for the old quarterly edir updates),
		# the first line of "control.tel" looked like this:
		#
		#	input: Teleflora May-Jul 2010
		#
		# The code transformed this line to a quarter name in the
		# form of the 3 letter abbreviation and the year...
		# so for example, the line above would be transformed into:
		#
		#	output: MJJ2010
		#
		# For the May 2013 edir update which was a one time update
		# and thus the format of the first line was temporary,
		# the first line of "control.tel" looked like this:
		#
		#	input: Teleflora May 2013
		#
		# There were no changes to the code in this script for that
		# temporary situation, so the code did not handle the input
		# correctly and ended up transforming a line like this to
		# a multi-word string of the form:
		#
		#	output: Teleflora May 20132013
		# 
		# For the new daily edir updates, the first line of
		# "control.tel" should look like this:
		#
		#	input: Teleflora May 28, 2013
		#
		# The requirement for the code is to transform this
		# multi-word string into a value that looks like:
		#
		#	output: 2013-05-28
		#
		# This new code should handle all types of input.
		#
		my @edir_version_list = split(/\s/, $edirectory);

		# old quarterly updates style
		if ($edirectory =~ /Teleflora (\w){3}.*-.*(\w){3} (\d){4}/) {
		    if ($edir_version_list[1] =~ /Nov.*-.*Jan/) {
			    $edirectory = "NDJ";
		    } elsif ($edir_version_list[1] =~ /Feb.*-.*Apr/) {
			    $edirectory = "FMA";
		    } elsif ($edir_version_list[1] =~ /May.*-.*Jul/) {
			    $edirectory = "MJJ";
		    } elsif ($edir_version_list[1] =~ /Aug.*-.*Oct/) {
			    $edirectory = "ASO";
		    }
		    $edirectory = $edirectory . $edir_version_list[2];
		}

		# interim updates style
		elsif ($edirectory =~ /Teleflora (\w){3} (\d){4}/) {
		    if ($edir_version_list[1] =~ /Nov/) {
			    $edirectory = "NOV";
		    } elsif ($edir_version_list[1] =~ /Feb/) {
			    $edirectory = "FEB";
		    } elsif ($edir_version_list[1] =~ /May/) {
			    $edirectory = "MAY";
		    } elsif ($edir_version_list[1] =~ /Aug/) {
			    $edirectory = "AUG";
		    }
		    $edirectory = $edirectory . $edir_version_list[2];
		}

		# new daily edir updates
		#	input: Teleflora May 28, 2013
		#	output: SEP 2013-05-28
		elsif ($edirectory =~ /Teleflora\s+(\w){3}\s+(\d\d?)[,]\s+(\d){4}/) {
		    my %mon2num = (
			jan => 1, feb => 2, mar => 3, apr => 4,
			may => 5, jun => 6, jul => 7, aug => 8,
			sep => 9, oct => 10, nov => 11, dec => 12,
		    );

		    my $edir_month_name = $edir_version_list[1];
		    my $edir_month_num = $mon2num{ lc(substr($edir_month_name, 0, 3)) };
		    $edir_month_num = sprintf("%02d", $edir_month_num);
		    my $edir_month_day = $edir_version_list[2];
		    $edir_month_day =~ s/,//;
		    $edir_month_day = sprintf("%02d", $edir_month_day);
		    my $edir_year = $edir_version_list[3];

		    $edirectory = $edir_year . '-' . $edir_month_num . '-' . $edir_month_day;
		    $edirectory = $edir_book . ' ' . $edirectory;
		}

		# unsupported contents
		else {
		    $edirectory = "Unknown";
		}

		#
		# Now, we want to append a suffix that conveys whether the
		# customer is a Telelfora only customer or a combined
		# Teleflora *and* FTD customer.
		#
		# This can be done by looking for the existence of the file
		# /d/daisy/control.ftd.
		#
		$edirectory .= (-e "$POSDIR/control.ftd") ? "CMB" : "TEL";
	}


	# POSType
	$postype = $POS;

	#
	# Public IP Address
	# Looks like "automation.whatismyip.com" is no longer valid.
	# Switching over to "icanhazip.com".
	#
	$publicip = 'Unknown';
	for (my $i=0; $i < 5; $i++) {
		open PIPE, "curl --silent http://icanhazip.com |";
		while (<PIPE>) {
			chomp;
			if (/((\d+){1,3}(\.)(\d+){1,3}(\.)(\d+){1,4}(\.)(\d+){1,3})/) {
				$publicip = $1;
				last;
			}
		}
		close PIPE;
		if ($publicip ne 'Unknown') {
			last;
		}
	}


	# Custom Inventory Version
	# Ie, version of this script.
	$string = '$Revision: 1.41 $';
	@array = split(/[[:space:]]/,$string);
	$custominv_version = $array[1];


	# Print our resultant record.
	# Note that Chad wants *one* row, with columns per data.
	# These columns need to be at least consistent with those in Dove POS.
	chomp($shopcode);
	chomp($POS);
	chomp($buildnum);
	chomp($installdate);
	chomp($installdir);
	chomp($edirectory);
	chomp($publicip);

	print "$shopcode,$postype,$buildnum,$installdate,$installdir";
	print ",$platform_id,$edirectory,$publicip,$custominv_version\n";
}


sub custominv_admin_expires
{
	my $line = "";
	my @array = ();
	my $user = "";
	my $expdate = "";
	my $lastchange = "";


	# Headers
	print ("AeX_CI_Teleflora_" . $POS . "_AdminAccounts\n");
	print ("Delimiters = \",\"\n");
	print ("string20 string20 string20 string20\n");
	print ("User ActiveStatus ExpDate LastChange\n");


	# Get a list of admin users.
	open(LIST, "$USERSCRIPT --list |");
	while(<LIST>) {
		$user = "";
		$expdate = "";
		$lastchange = "";
		next until(/Admin\)/i);


		@array = split(/[[:space:]]+/);
		$user = $array[0];


		open(PIPE, "$USERSCRIPT --info $user |");
		while(<PIPE>) {
			chomp;
			if (/(Password Expires:)(\s+)([[:print:]]+)/) {
				$expdate = $3;
			}
			if(/(Last Change:)(\s+)([[:print:]]+)/) {
				$lastchange = $3;
			}
		}
		close(PIPE);

		if( ("$user" ne "")
		&&  ("$expdate" ne "")
		&&  ("$lastchange" ne "") ) {
			$user =~ s/,/_/g;
			$expdate =~ s/,/_/g;
			$lastchange =~ s/,/_/g;
			print("$user,Unknown,$expdate,$lastchange\n");
		}

	}
	close(LIST);
}



# Helper function.
# Modified version from RTI install script.
#
sub get_bbj_pro5_version
{
	my $bbj_pro5_dir = "";
	my $bbj_pro5_version = "Unknown";

	# Determine where bbj executable lives, if none, look for pro5.
	# look in profile.d for BBJ_DIR=blah
	open FILE, "< /etc/profile.d/rti.sh";
	while(<FILE>) {
		chomp;
		if($bbj_pro5_dir eq "") {
			if(/^(\s*)(PRO5_DIR)(\s*)(=)(\s*)([[:print:]]+)/) {
				$bbj_pro5_dir = $6;
				if(! -f "$bbj_pro5_dir/bbj") {
					$bbj_pro5_dir = "";
				}
			}
		}
		if(/^(\s*)(BBJ_DIR)(\s*)(=)(\s*)([[:print:]]+)/) {
			$bbj_pro5_dir = $6;
		}
	}
	close FILE;

	if(! -f "$bbj_pro5_dir/bbj") {

		# Determine where pro5 executable lives if no bbj.
		# look in profile.d for PRO5_DIR=blah
		open FILE, "< /etc/profile.d/pro5.sh";
		while(<FILE>) {
			chomp;
			if(/^(\s*)(PRO5_DIR)(\s*)(=)(\s*)([[:print:]]+)/) {
				$bbj_pro5_dir = $6;
			}
		}
		close FILE;

		if(! -f "$bbj_pro5_dir/pro5") {
			return "$bbj_pro5_version";
		}
	}




	# Make sure this is the right version of bbj
	open FILE, "> /tmp/bbj_rev.$$";
		print FILE "PRINT;PRINT;PRINT REV;PRINT;PRINT;BYE\n";
	close FILE;
	if(-f "$bbj_pro5_dir/bbj") {
	open BBJ, "$bbj_pro5_dir/bbj -c$POSDIR/config/config.bbx < /tmp/bbj_rev.$$ |";
	} else {
	open BBJ, "$bbj_pro5_dir/pro5 -c$POSDIR/config/config.bbx < /tmp/bbj_rev.$$ |";
	}
	while(<BBJ>) {
		if( /^(REV)([[:space:]]+)(\d+\.\d+)/) {
			$bbj_pro5_version = $3;
			last;
		}
	}
	close BBJ;
	unlink("/tmp/bbj_rev.$$");

	chomp($bbj_pro5_version);

	if(-f "$bbj_pro5_dir/bbj") {
		$bbj_pro5_version = "BBjVersion," . $bbj_pro5_version;
	} else {
		$bbj_pro5_version = "Pro5Version," . $bbj_pro5_version;
	}

	return $bbj_pro5_version;
}



#############################################
sub custominv_rti_versions
{
	my @array = ();
	my $build = "";
	my $patchlvl = "";
	my $thisfile = "";
	my $filelist = "";
	my $value = "";


	return if ($POS ne "RTI");

	# Headers
	print "AeX_CI_Teleflora_RTI_Versions\n";
	print "Delimiters = \",\"\n";
	print "string40 string20\n";
	print "Program Version\n";


	# This script.
	$build = '$Revision: 1.41 $';
	@array = split(/\s/, $build);
	$build = $array[1];
	print basename($0) . "," . $build . "\n";



	# Get RTI Build
	$build = "Unknown";
	if(-f "$POSDIR/bbxd/RTI.ini") {
		open FILE, "< $POSDIR/bbxd/RTI.ini";
		while(<FILE>) {
			chomp;
			if(/^(VERSION)(\s*)(=)(\s*)([[:print:]]+)/) {
				$build = $5;
			}
			if(/^(PATCH)(\s*)(=)(\s*)([[:print:]]+)/) {
				$patchlvl = $5;
				last;
			}
		}
		$build = $build . $patchlvl;
		close FILE;
	} else {
		$build = "$POSDIR/config/RTI.ini file not found";
	}

	print "RTI Build,$build\n";




	# Get TCC Version
	$build = "Unknown";
	if(-e "$POSDIR/bin/tcc") {
		open PIPE, "$POSDIR/bin/tcc --version |";
		while(<PIPE>) {
			chomp;
			if(/(Version:)(\s*)([[:print:]]+)/) {
				$build = $3;
				last;
			}
		}
		close PIPE;
	}
	print "TCC,$build\n";



	# Pro-5 Version.
	$build = "Unknown";
	$build = get_bbj_pro5_version();
	print "$build\n";




	# Various RTI scripts, executables and BBx files.
	$filelist = "";
	$filelist .= " " . "$POSDIR/bbxps/*";
	$filelist .= " " . "$POSDIR/bbxp/*";
	$filelist .= " " . "$POSDIR/bin/*";
	open PIPE, "find $filelist -type f -print 2> /dev/null |";
	while(<PIPE>) {
		chomp;
		$thisfile = $_;

		# Scan this particular (binary) file for the
		# fingerprint of "$Revision: 1.41 $"
		#
		open FILE, "< $thisfile";
		while(<FILE>) {
			if(/(Revision: \S+)/) {
				@array = split(/[[:space:]]/,$1);
				$value = $array[1];
				$thisfile =~ s/,/_/g;
				print "$thisfile,$value\n";
				last;
			}
		}
		close FILE;
	}
	close PIPE;
}




sub custominv_rti_configs
{
	my $filelist = "";
	my $thisfile = "";
	my $key = "";
	my $value = "";


	return if ($POS ne "RTI");

	# Headers
	print "AeX_CI_Teleflora_RTI_Configurations\n";
	print "Delimiters = \",\"\n";
	print "string25 string100 string100\n";
	print "Key Value Filename\n";



	# .ini files.
	$filelist = "";
	$filelist .= " " . "$POSDIR/config/*.ini";
	$filelist .= " " . "$POSDIR/bbxd/*.ini";
	$filelist .= " " . "$POSDIR/config/config.bbx";
	$filelist .= " " . "/etc/profile.d/rti.sh";
	#if(-f $bbj_pro5_dir/pro5) {
		#$filelist .= " " . "/etc/profile.d/pro5.sh";
	#}
	open PIPE, "find $filelist -type f -print 2> /dev/null | sort |";
	while(<PIPE>) {
		chomp;
		$thisfile = $_;

		# Scan this particular (binary) file for the
		# fingerprint of FOO=BAR
		#
		open FILE, "< $thisfile";
		while(<FILE>) {


			# KEY = VALUE
			if(/^(\s*)(\S+)(\s*)(=)(\s*)([[:print:]]+)$/) {
				$thisfile =~ s/,/_/g;
				$key = $2;
				if($key ne "") {
					$key =~ s/,/_/g;
				}
				$value = $6;
				chomp($value);
				if($value ne "") {
					$value =~ s/,/_/g;
				}
				print "$key,$value,$thisfile\n";


			# Config.bbx "alias" lines.
			# alias LP "|lp -dreport1 -s 2>/dev/null" "HPLASERJET Report Printer" CR,PTON=1B451B266C37481B266C36441B287330501B266C372E323743,SP=1B2873313048,CP=1B2873313748,CPCOLS=255,SPCOLS=255
			} elsif (/^(\s*)(alias)(\s*)(\w+)(\s*)([[:print:]]+)$/i) {
				$key = "alias $4";
				$value = $6;
				$value =~ s/,/_/g;
				chomp($value);
				print "$key,$value,$thisfile\n";
			}

		}
		close FILE;
	}
	close PIPE;



	# rtiBackgr
	# Which "daemon" processes are running?
	$thisfile = "$POSDIR/config/rtiBackgr";
	open FILE, "< $thisfile";
	while(<FILE>) {
		chomp;
		if(/^(\s*)(\w+)/) {
			$key = $2;
			$key =~ s/,/_/g;
			$value = "Enabled";
			print "$key, $value, $thisfile\n";
		}
	}
	close FILE;
}





#
# Calculate error statistics
# Intended as a more numerical analysis of what is going on.
#
sub custominv_rti_errorstats
{
	my $logfile = "";
	my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime());

	return if ($POS ne "RTI");

	# 
	print "AeX_CI_Teleflora_RTI_Errorstats\n";
	print "Delimiters = \",\"\n";
	print "string20 string128 string100\n";
	print "Timestamp Description Value\n";



	# Credit Card Statistics
	$logfile = "$POSDIR/log/tcc.log";
	if(! -f $logfile) {
		my $errorcount = 0;
		my $warncount = 0;
		my $authsuccess_swipe = 0;
		my $authsuccess_keyed = 0;
		my $authfail_swipe = 0;
		my $authfail_keyed = 0;
		my $settsuccess = 0;
		my $settfail = 0;

		open FILE, "< $logfile";
		while(<FILE>) {
			

			if(/<E>/) {
				$errorcount++;
			}
			if(/<W>/) {
				$warncount++;
			}

			# Auth success stats.
			if(/Authorization Successful/) {

				if(/IsSwiped=\"true\"/) {
					$authsuccess_swipe++;
				} else {
					$authsuccess_keyed++;
				}


			# Auth Failure stats.
			} elsif (/Authorization Failed/) {
				if(/IsSwiped=\"true\"/) {
					$authfail_swipe++;
				} else {
					$authfail_keyed++;
				}

			# Settlement Success.
			} elsif (/Batch Settled with Settlement ID \"[0-9][A-Z][a-z]+/) {
				$settsuccess++;

			# Settlement Failure
			} elsif (/Batch.*.did not settle/) {
				$settfail++;
			}


		}
		close(FILE);

		print "$timestamp,Logged Errors (Total),$errorcount\n";
		print "$timestamp,Logged Warnings (Total),$warncount\n";

		print "$timestamp,Authorizations Successful (Total)," . ($authsuccess_swipe + $authsuccess_keyed) . "\n";
		print "$timestamp,Authorizations Successful (Swiped),$authsuccess_swipe\n";
		print "$timestamp,Authorizations Successful (Keyed),$authsuccess_keyed\n";

		print "$timestamp,Authorizations Failed (Total)," . ($authfail_swipe + $authfail_keyed) . "\n";
		print "$timestamp,Authorizations Failed (Swiped),$authfail_swipe\n";
		print "$timestamp,Authorizations Failed (Keyed),$authfail_keyed\n";

		print "$timestamp,Settlements Successful (Total), $settsuccess\n";
		print "$timestamp,Settlements Failed (Total), $settfail\n";
	}



	# Doveserver Statistics
	$logfile = strftime("$POSDIR/log/doveserver-Day_%d.log", localtime());
	if(! -f $logfile) {
		my $errorcount = 0;
		my $warncount = 0;


		open FILE, "< $logfile";
		while(<FILE>) {
			if(/<E>/) {
				$errorcount++;
			}
			if(/<W>/) {
				$warncount++;
			}


		}
		close(FILE);

		print "$timestamp,Doveserver Errors Total,$errorcount\n";
		print "$timestamp,Doveserver Warnings Total,$warncount\n";

	}


	# Callout Statistics
	$logfile = strftime("$POSDIR/log/callout-Day_%d.log", localtime());
	if(! -f $logfile) {
		my $errorcount = 0;
		my $warncount = 0;


		open FILE, "< $logfile";
		while(<FILE>) {
			if(/<E>/) {
				$errorcount++;
			}
			if(/<W>/) {
				$warncount++;
			}


		}
		close(FILE);

		print "$timestamp,Callout Errors Total,$errorcount\n";
		print "$timestamp,Callout Warnings Total,$warncount\n";
	}

}



sub custominv_rti_rtibbx_errors
{

	return if ($POS ne "RTI");

	# RTI_BBx
	print "AeX_CI_Teleflora_RTI_RTIBBx_Errors\n";
	print "Delimiters = \",\"\n";
	print "string20 string128 string100\n";
	print "Timestamp Message ErrorFile\n";
	custominv_rti_logfile( strftime("$POSDIR/log/RTI_BBx-Day_%d.log", localtime()));
}



sub custominv_rti_dove_errors
{
	my $logfile = "";

	return if ($POS ne "RTI");

	# Dove Errors
	print "AeX_CI_Teleflora_RTI_Dove_Errors\n";
	print "Delimiters = \",\"\n";
	print "string20 string128 string100\n";
	print "Timestamp Message ErrorFile\n";


	# Doveserver
	$logfile = strftime("$POSDIR/log/doveserver-Day_%d.log", localtime());
	if(! -f $logfile) {
		# RTI 12.0 Logging
		$logfile = strftime("$POSDIR/log/doveserver-%A.log", localtime());
		if(! -f $logfile) {
			$logfile = "";
		}
	}
	if($logfile ne "") {
		custominv_rti_logfile($logfile);
	}


	# Callout
	$logfile = strftime("$POSDIR/log/callout-Day_%d.log", localtime());
	if(! -f $logfile) {
		# RTI 12.0 Logging
		$logfile = strftime("$POSDIR/log/callout-%A.log", localtime());
		if(! -f $logfile) {
			$logfile = "";
		}
	}
	if($logfile ne "") {
		custominv_rti_logfile($logfile);
	}

}

sub custominv_rti_kiosk_errors
{
	my $logfile = "";

	return if ($POS ne "RTI");

	# Kiosk Log Errors
	print "AeX_CI_Teleflora_RTI_Kiosk_Errors\n";
	print "Delimiters = \",\"\n";
	print "string20 string128 string100\n";
	print "Timestamp Message ErrorFile\n";


	$logfile = strftime("$POSDIR/log/kioskserver-Day_%d.log", localtime());
	if(! -f $logfile) {
		# RTI 12.0 Logging
		$logfile = strftime("$POSDIR/log/callout-%A.log", localtime());
		if(! -f $logfile) {
			$logfile = "";
		}
	}
	if($logfile ne "") {
		custominv_rti_logfile($logfile);
	}

}


sub custominv_rti_watchrti_errors
{

	return if ($POS ne "RTI");

	# Kiosk Log Errors
	print "AeX_CI_Teleflora_RTI_Watchrti_Errors\n";
	print "Delimiters = \",\"\n";
	print "string20 string128 string100\n";
	print "Timestamp Message ErrorFile\n";
	custominv_rti_logfile( strftime("$POSDIR/log/watchrti-Day_%d.log", localtime()));
}



#
# Helper function. 
# Log contents of a specific logfile.
# if "logtype" of "errors" is passed, then, only '<E>' log entries
# are returned, and those are returned in *descending* order (ie, most
# recent error on top.
#
sub custominv_rti_logfile
{
	my $filename = $_[0];

	my $filestat = "";
	my $timestamp = "";
	my $log_year = 0;
	my $log_month = 0;
	my $log_day = 0;
	my $now_year = 0;
	my $now_month = 0;
	my $now_day = 0;
	my $severity = "";
	my $message = "";
	my $logcount = 0;


	if($filename eq "") {
		return "";
	}
	if(! -f $filename) {
		return "";
	}


	# If the file hasn't been modified in over 24 hours, it's probably not
	# work looking at.
	$filestat = stat($filename);
	if( time() -  ($filestat->mtime) > (60 * 60 * 24)) {
		next;
	}


	# Default our datestamp to the file's mtime.
	$log_year = strftime("%Y", localtime($filestat->ctime));
	$log_month = strftime("%m", localtime($filestat->ctime));
	$log_day = strftime("%d", localtime($filestat->ctime));




	open FILE, "< $filename";
	while(<FILE>) {
		chomp;

		# Log File Opened:Day, DD Month YYYY
		# This regex especially useful for the case of "legacy" TCC systems (RTI 12.0
		# and earlier RTI 12.5). In particular, this is a more accurate way of determining
		# the true date that a log entry was made.
		if(/(Log File Opened:)(\S+)(\s+)(\d+)(\s+)(\S+)(\s+)(\d+)/) {
			my $monthname = $6;

			$log_day = $4;
			$log_year = $8;
			if($monthname eq "Jan") {
				$log_month = "01";
			} elsif ($monthname eq "Feb") {
				$log_month = "02";
			} elsif ($monthname eq "Mar") {
				$log_month = "03";
			} elsif ($monthname eq "Apr") {
				$log_month = "04";
			} elsif ($monthname eq "May") {
				$log_month = "05";
			} elsif ($monthname eq "Jun") {
				$log_month = "06";
			} elsif ($monthname eq "Jul") {
				$log_month = "07";
			} elsif ($monthname eq "Aug") {
				$log_month = "08";
			} elsif ($monthname eq "Sep") {
				$log_month = "09";
			} elsif ($monthname eq "Oct") {
				$log_month = "10";
			} elsif ($monthname eq "Nov") {
				$log_month = "11";
			} elsif ($monthname eq "Dec") {
				$log_month = "12";
			}
		}


		# HH:MM:SS <E> blah
		if(/^(\d\d:\d\d:\d\d)([[:print:]]+)(<E>)(\s*)([[:print:]]+)/) {
			$timestamp = $1;
			$severity = $3;
			$message = $5;


		# YYYY-MM-DD HH:MM:SS <E> blah
		# In these "newer style" logfile entries, the datestamp is integrated into the particular log message,
		# thus giving us most accurate datestamps.
		} elsif(/^(\d\d\d\d)(-)(\d\d)(-)(\d\d)(\s+)(\d\d:\d\d:\d\d)([[:print:]]+)(<E>)(\s*)([[:print:]]+)/) {
			$log_year = $1;
			$log_month = $3;
			$log_day = $5;
			$timestamp = $7;
			$severity = $9;
			$message = $11;
		}


		# Actually log the entry here, only if the datestamp is from today.
		if(($message ne "")
		&& (int($log_year) == int(strftime("%Y", localtime(time()))))
		&& (int($log_month) == int(strftime("%m", localtime(time()))))
		&& (int($log_day) == int(strftime("%d", localtime(time())))) ){
			$message =~ s/,/_/g;
			print "$log_year-$log_month-$log_day $timestamp,$message,$filename\n";
			$logcount++;
		}
		last if($logcount >= 25);
	}
	close FILE;
}
