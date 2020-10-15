#!/usr/bin/perl
#
# $Revision: 1.16 $
# Copyright 2009 Teleflora
# 
# dsyperms.pl
#
# Setup file permissions in a Daisy tree.
#

use strict;
use warnings;
use POSIX;
use Getopt::Long;
use English;
use File::Basename;
use File::Find;


my $CVS_REVISION = '$Revision: 1.16 $';
my $TIMESTAMP = strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($0);

my $DEFAULT_DSYDIR = '/d/daisy';
my $DSYROOT = "/d";
my $DSYDIR = "";
my $HELP = 0;
my $VERSION = 0;
my $INSTALL = 0;
my $DRY_RUN = 0;
my $TOOLSDIR = "";


GetOptions(
	"help" => \$HELP,
	"version" => \$VERSION,
	"install" => \$INSTALL,
	"dry-run" => \$DRY_RUN,
) or exit(1);


# --help
if ($HELP) {
	usage();
	exit(0);
}


# --version
if ($VERSION) {
	print "OSTools Version: 1.15.a\n";
	print "$PROGNAME: $CVS_REVISION\n";
	exit(0);
}


# Where do "OSTOOLS" typically reside?
if (-e "/teleflora/ostools/bin") {
	$TOOLSDIR = "/teleflora/ostools";
}
elsif (-e "/usr2/ostools/bin") {
	$TOOLSDIR = "/usr2/ostools";
}
elsif (-e "/d/ostools/bin") {
	$TOOLSDIR = "/d/ostools";
}
unless (-d "$TOOLSDIR/bin") {
	logerror("required directory $TOOLSDIR/bin does not exist... can't continue");
	exit(1);
}

# --install
if ($INSTALL != 0) {
	install_dsyperms();
	exit(0);
}


#
# If there is more than one command line argument, it's an error.
# If there is one command line argument, use it as the path to the
# daisy database directory.  If there are no command line args,
# then use the default value.
#
if (@ARGV > 1) {
	usage();
	exit(1);
} elsif (@ARGV == 1) {
	$DSYDIR = $ARGV[0];
} else {
	$DSYDIR = $DEFAULT_DSYDIR;
}

#
# Validate user input.
#
$DSYDIR = validate_input($DSYDIR);
unless ($DSYDIR) {
	$DSYDIR = $DEFAULT_DSYDIR;
}

# make sure the daisy database dir is an absolute path
unless (substr($DSYDIR, 0, 1) eq '/') {
	print("$PROGNAME: the Daisy database dir must be an absolute path\n");
	usage();
	exit(1);
}

# make sure the daisy database dir is a directory located in "/d"
my $daisy_dir_name = basename($DSYDIR);
unless (-d "/d/$daisy_dir_name") {
	print("$PROGNAME: the Daisy database dir must be a dirctory located in \"/d\"\n");
	usage();
	exit(1);
}

# make sure it's a daisy database directory
unless (is_daisy_db_dir($DSYDIR)) {
	print("$PROGNAME: \"$DSYDIR\" is not a Daisy database directory\n");
	usage();
	exit(1);
}


# Make sure we are running as the root user.
if ($UID != 0) {
	print("$PROGNAME: sudo privileges are required for execution\n");
	exit(2);
}


# "New PABP" permission sets.
if (assign_pabp_permissions($DSYROOT, $DSYDIR) != 0) {
	exit(1);
}


exit(0);

###################################################################
###################################################################
###################################################################



sub usage
{
	print("$PROGNAME $CVS_REVISION\n");
	print("\n");
	print("Usage:\n");
	print("$PROGNAME --help\n");
	print("$PROGNAME --version\n");
	print("$PROGNAME --install\n");
	print("$PROGNAME [daisy_dir]\n");
	print("\n");
	print("--version:    Output version number and exit.\n");
	print("--help:       Output this Help Text and exit.\n");
	print("--install:    Install and exit.\n");
	print("--dry-run:    Just report actions, don't perform them.\n");
	print("daisy_dir:    path to a daisy database directory\n");
	print("no arguments: defaults to \"/d/daisy\"\n");

	return(1);
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
        my ($var) = @_;

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


sub install_dsyperms
{
	logit("---- BEGIN Installation $PROGNAME $CVS_REVISION ----", 'I');

	# If file exists and is the same, then it's already installed.
	my $already_installed = 0;
	if (-f "$TOOLSDIR/bin/dsyperms.pl") {
		system("diff $0 $TOOLSDIR/bin");
		$already_installed = 1 if ($? == 0);
	}

	# If file is not already installed, then copy instance to bin directory.
	unless ($already_installed) {
		system("cp $0 $TOOLSDIR/bin/dsyperms.pl");
	}

	# Always set owner:group and modes.
	system("chown tfsupport:daisy $TOOLSDIR/bin/dsyperms.pl");
	system("chmod 550 $TOOLSDIR/bin/dsyperms.pl");

	#
	# Always remember: there can be more than one daisy database dir.
	#
	# Now remove the old version in the "bin" directory of a daisy db dir and
	# make symlink to ostools script.
	#
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

		system("rm -f $daisy_db_dir/bin/dsyperms.pl");
		system("ln -sf $TOOLSDIR/bin/dsyperms.pl $daisy_db_dir/bin/dsyperms.pl");
	}

	logit("---- END Installation $PROGNAME $CVS_REVISION ----", 'I');

	return(1);
}

my @FilePaths = ();

sub assign_pabp_permissions
{
	my ($dsyroot, $dsydir) = @_;

	if ( (! defined $dsyroot) or ($dsyroot eq "") ) {
		return(-1);
	}

	# top level directories
	my @dsy_top_level_dirs = qw(
		backup
		config
		daisy
		menus
		ostools
		putty
		server
		startup
		utils
	); 

	#
	# Always remember, there can be daisy database dirs other than '/d/daisy'.
	# So add the current daisy db dir to the list if it's not '/d/daisy'.
	#
	if ($dsydir ne '/d/daisy') {
		push(@dsy_top_level_dirs, basename($dsydir));
	}

	foreach my $thisdir (@dsy_top_level_dirs) {

		# the "ostools" dir does not have to exist
		if ($thisdir eq "ostools") {
			next if (! -d "$dsyroot/$thisdir");
		}

		unless (-d "$dsyroot/$thisdir") {
			print("Warning! Expecting to find \"$dsyroot/$thisdir\" but directory not found!\n");
			next;
		}

		if ($thisdir eq "backup" || $thisdir eq "config") {
			if ($DRY_RUN) {
			    dry_run_chown("root", "root", "$dsyroot/$thisdir");
			    dry_run_chmod("770", "$dsyroot/$thisdir");
			}
			else {
			    system("chown root:root $dsyroot/$thisdir");
			    system("chmod 770 $dsyroot/$thisdir");
			}
		} else {
			if ($DRY_RUN) {
			    dry_run_chown("tfsupport", "daisy", "$dsyroot/$thisdir");
			    dry_run_chmod("770", "$dsyroot/$thisdir");
			}
			else {
			    system("chown tfsupport:daisy $dsyroot/$thisdir");
			    system("chmod 770 $dsyroot/$thisdir");
			}
		}
	}


	#
	# Default permissions for all directories at the top of the daisy tree that
	# are not in the list of known directories.
	#
	# Each file should be owned by the "support" user and in the "admins" group.
	# We do not want the "non-privileged" daisy user being able to write these files.
	#
	# Note that skip setting defaults for known files/directories at the top level.
	# If this script is executed on a running system we could break software when
	# we "flip" file permissions from writable, to readable, back to writable.
	# See tracker 104357.
	#
	opendir(DIR, "$dsyroot");
	foreach my $thisdir (readdir(DIR)) {
		#
		# Skip the typical file system stuff
		#
		next if ($thisdir =~ /\.$/);
		next if ($thisdir =~ /\.\.$/);
		next if ($thisdir =~ /lost\+found/);

		#
		# Skip the standard, expected dirs
		#
		next if (grep { /$thisdir/ }  @dsy_top_level_dirs); 

		#
		# Remember, there can be daisy database dirs other than '/d/daisy'
		# at the top level... so determine if a dir is a daisy db dir, and
		# if it is, skip it.  A directory is classified as a daisy db dir
		# if it is a dir in the top level, ie in "/d", and it contains a
		# file named "control.dsy".
		#
		if (-d "$dsyroot/$thisdir") {
			next if (-f "$dsyroot/$thisdir/control.dsy");
		}

		#
		# Don't know what this file is, so log a message and leave it
		# alone. (formerly, items like this were affected but that
		# policy backfired when adding new directories and this script
		# could not be changed in unison - think offcycle edir project)
		#
		logit("unknown directory entry: $dsyroot/$thisdir", 'W');

	}
	closedir(DIR);


	my @dsy_bin_dirs = qw(
		bin
		utils
	);

	# Executable directories and their contents in /d/daisy
	foreach my $thisdir (@dsy_bin_dirs) {

		if (! -d "$dsydir/$thisdir") {
			print("Warning! \"$dsydir/$thisdir\" directory not found!\n");
			next;
		}

		# very special case - if the symlink "/d/daisy/bin/pcl6" exists,
		# it comes out of the tar archive with arbitarary owner and group
		# so it needs to be set.
		if ($thisdir eq "bin") {
		    if (-e "$dsydir/$thisdir/pcl6") {
			system("chown -h root:root $dsydir/$thisdir/pcl6");
		    }
		}

		# directory
		if ($DRY_RUN) {
		    dry_run_chown("tfsupport", "daisy", "$dsydir/$thisdir");
		    dry_run_chmod("770", "$dsydir/$thisdir");
		}
		else {
		    system("chown tfsupport:daisy $dsydir/$thisdir");
		    system("chmod 770 $dsydir/$thisdir");
		}
		# files & files referenced by symlinks
		if ($DRY_RUN) {
		    foreach my $path (glob("$dsydir/$thisdir/*")) {
			# if the directory is "utils" and it's a "screen file"
			# (why are there any screen files in "utils"???), then
			# the mode is set to "660" later on.
			my $mode = "550";
			if (($thisdir eq "utils") && ($path =~ /\.scr$/)) {
			    $mode = "660";
			}
			dry_run_chown("tfsupport", "daisy", $path);
			dry_run_chmod($mode, $path);
		    }
		}
		else {
		    system("chown tfsupport:daisy $dsydir/$thisdir/*");
		    system("chmod 550 $dsydir/$thisdir/*");
		}
	}

	# Explicitly handle tools from OSTools package since they are vital to daisy
	if ($DRY_RUN) {
	    dry_run_chown("tfsupport", "daisy", "$dsyroot/ostools");
	    dry_run_chmod("770", "$dsyroot/ostools");
	    dry_run_chown("tfsupport", "daisy", "$dsyroot/ostools/bin");
	    dry_run_chmod("770", "$dsyroot/ostools/bin");
	    foreach my $path (glob("$dsyroot/ostools/bin/*")) {
		dry_run_chown("tfsupport", "daisy", $path);
		dry_run_chmod("550", $path);
	    }
	}
	else {
	    system("chown tfsupport:daisy $dsyroot/ostools");
	    system("chmod 770 $dsyroot/ostools");
	    system("chown tfsupport:daisy $dsyroot/ostools/bin");
	    system("chmod 770 $dsyroot/ostools/bin");
	    system("chown tfsupport:daisy $dsyroot/ostools/bin/*");
	    system("chmod 550 $dsyroot/ostools/bin/*");
	}

	my @dsy_dirs = qw(
		backup.dir
		blankdata
		comms
		config
		cubby
		dcom_email
		docs
		dsy
		errors
		export
		reports
		log
		pospool
		recv
		submit
		tfm
	);

	# Directories and their contents in /d/daisy
	foreach my $thisdir (@dsy_dirs) {

		if (! -d "$dsydir/$thisdir") {
			print("Warning! \"$dsydir/$thisdir\" directory not found!\n");
			next;
		}

		# Since the "export" directory is mainly for exchanging
		# files with Windows PCs, don't try to set anything
		# inside that directory.
		if ($thisdir eq "export") {
		    if ($DRY_RUN) {
			dry_run_chown("tfsupport", "daisy", "$dsydir/$thisdir");
			dry_run_chmod("770", "$dsydir/$thisdir");
		    }
		    else {
			system("chown tfsupport:daisy $dsydir/$thisdir");
         system("chown -R daisy:daisy $dsydir/$thisdir/*");
			system("chmod 770 $dsydir/$thisdir");
         # Process subdirectories and files under these too
			system("find $dsydir/$thisdir" . ' -type d -exec chmod 770 {} \;');
			system("find $dsydir/$thisdir" . ' -type f -exec chmod 660 {} \;');

		    }
		    next;
		}

		# it's unknown how the Daisy code uses this directory -
		# set it to known value rather than leaving it as it comes
		# out of the tar archive and don't do anything with it's
		# contents.
		if ($thisdir eq "dcom_email") {
		    if ($DRY_RUN) {
			dry_run_chown("daisy", "daisy", "$dsydir/$thisdir");
			dry_run_chmod("750", "$dsydir/$thisdir");
		    }
		    else {
			system("chown daisy:daisy $dsydir/$thisdir");
			system("chmod 750 $dsydir/$thisdir");
		    }
		    next;
		}

		if ($thisdir eq "reports") {
		    if ($DRY_RUN) {
			dry_run_chown("daisy", "daisy", "$dsydir/$thisdir");
			dry_run_chmod("750", "$dsydir/$thisdir");
		    }
		    else {
			system("chown -R daisy:daisy $dsydir/$thisdir");
			system("chmod 770 $dsydir/$thisdir");
			system("find $dsydir/$thisdir" . ' -type d -exec chmod 770 {} \;');
			system("find $dsydir/$thisdir" . ' -type f -exec chmod 660 {} \;');
			}
			next;
		}

		if ($thisdir eq "config") {
		    if ($DRY_RUN) {
			dry_run_chown("tfsupport", "daisy", "$dsydir/$thisdir");
			dry_run_chmod("770", "$dsydir/$thisdir");
		    }
		    else {
			system("chown tfsupport:daisy $dsydir/$thisdir");
			system("chmod 770 $dsydir/$thisdir");
		    }
		    next;
		}

		if ($DRY_RUN) {
		    dry_run_find_file_paths("$dsydir/$thisdir");
		    foreach my $path (@FilePaths) {
			dry_run_chown("tfsupport", "daisy", $path);
		    }
		    dry_run_chmod("770", "$dsydir/$thisdir");
		}
		else {
		    system("chown -R tfsupport:daisy $dsydir/$thisdir");
		    system("chmod 770 $dsydir/$thisdir");
		}

		if ($thisdir eq "log") {
			foreach my $logpath (glob("$dsydir/$thisdir/*")) {
				my $logfile = basename($logpath);
				if ($logfile =~ /dove-.*\.log/) {
				    if ($DRY_RUN) {
					dry_run_chmod("660", "$dsydir/$thisdir/$logfile");
				    }
				    else {
					system("chmod 660 $dsydir/$thisdir/$logfile");
				    }
				} elsif ($logfile =~ /dove\.log/) {
				    if ($DRY_RUN) {
					dry_run_chmod("664", "$dsydir/$thisdir/$logfile");
				    }
				    else {
					system("chmod 664 $dsydir/$thisdir/$logfile");
				    }
				} elsif ($logfile =~ /rtibackup-.*\.log/) {
				    if ($DRY_RUN) {
					foreach my $path (glob("$dsyroot/$thisdir/$logfile*")) {
					    dry_run_chmod("666", "$path");
					}
				    }
				    else {
					system("chmod 666 $dsydir/$thisdir/$logfile*");
				    }
				}
			}

		}
		elsif ($thisdir eq "comms") {
			if (-d "$dsydir/$thisdir/tmp") {
			    if ($DRY_RUN) {
				dry_run_chmod("770", "$dsydir/$thisdir/tmp");
			    }
			    else {
				system("chmod 770 $dsydir/$thisdir/tmp");
			    }
			}
		}
		else {
			# following dirs set explicitly below
			next if ($thisdir eq "dsy");
			next if ($thisdir eq "config");

			if (count_dir_entries("$dsydir/$thisdir") > 2) {
			    if ($DRY_RUN) {
				foreach my $path (glob("$dsydir/$thisdir/*")) {
				    dry_run_find_file_paths("$path");
				    foreach my $file_path (@FilePaths) {
					dry_run_chmod("660", $file_path);
				    }
				}
			    }
			    else {
				system("chmod -R 660 $dsydir/$thisdir/*");
			    }
			}
		}
	}

	# Files in daisy db dir config directories
	my @dsy_config_files = (
		[ '.',        'control.dsy',        'tfsupport', 'daisy', '660' ],
		[ 'config',   'backups.config',     'tfsupport', 'daisy', '440' ],
		[ 'config',   'backups.config.new', 'tfsupport', 'daisy', '660' ],
		[ 'config',   'consolechars',       'tfsupport', 'daisy', '770' ],
		[ 'config',   'daisybuildinfo.txt', 'tfsupport', 'daisy', '440' ],
		[ 'config',   'daisy-init.d',       'tfsupport', 'daisy', '770' ],
		[ 'config',   'dell5200.ppd',       'tfsupport', 'daisy', '660' ],
		[ 'config',   'dos.sfm',            'tfsupport', 'daisy', '770' ],
		[ 'config',   'edir_update.conf',   'tfsupport', 'daisy', '660' ],
		[ 'config',   'hpjl4200.ppd',       'tfsupport', 'daisy', '660' ],
		[ 'config',   'hplj4200.ppd',       'tfsupport', 'daisy', '660' ],
		[ 'config',   'zeedaisy-init.d',    'tfsupport', 'daisy', '770' ],
		[ 'dsy',      'control.dsy',        'tfsupport', 'daisy', '440' ],
		[ 'dsy',      'printers',           'tfsupport', 'daisy', '440' ],
	);

	for my $i (0 .. $#dsy_config_files) {
		my $cfgdir = $dsy_config_files[$i][0];
		my $filename = $dsy_config_files[$i][1];
		my $owner = $dsy_config_files[$i][2];
		my $group = $dsy_config_files[$i][3];
		my $mode = $dsy_config_files[$i][4];
		if (-f "$dsydir/$cfgdir/$filename") {
		    if ($DRY_RUN) {
			dry_run_chown($owner, $group, "$dsydir/$cfgdir/$filename");
			dry_run_chmod($mode, "$dsydir/$cfgdir/$filename");
		    }
		    else {
			system("chown $owner:$group $dsydir/$cfgdir/$filename");
			system("chmod $mode $dsydir/$cfgdir/$filename");
		    }
		}
	}

	# Executable files in daisy db dir
	my @dsy_bin_files = qw(
		0branch
		actions
		convpos crd crdmenu crdpos crdterm crunch custpro
		daisy data dayend dcom delvmgr delvzip designer dove dpos drawer dump
		fileutil edir einvoice eroa
		glexport
		invlist invoice import
		actionbot logevent
		marketpr map
		payroll pool poolmain pos posctrl poslist posmerc posxfer pzlookup
		qrest
		route rundriv
		setup
		terreset timeclck
		*.sh
		pdayend.new
	);

	# are there any typical extra files in daisy db dir
	my @dsy_extra_file_types = qw(
		*.sh.orig
		*.new.orig
	);
	for my $file_type (@dsy_extra_file_types) {
	    my @extra_files = glob($file_type);
	    if (scalar(@extra_files)) {
		push(@dsy_bin_files, $file_type);
	    }
	}

	# these files were either added or dropped as of Daisy 9.2
	my @changed_bin_files = qw(
		activate
		poll
		dquery
		posdraw
		posfax
	);

	# so only add them to Daisy binary file list if they exist
	foreach my $changed_bin_file (@changed_bin_files) {
	    if (-e "$dsydir/$changed_bin_file") {
		push(@dsy_bin_files, $changed_bin_file);
	    }
	}

	# Change permissions of all daisy executable files
	foreach my $file (@dsy_bin_files) {
	    if ($DRY_RUN) {
		foreach my $path (glob("$dsydir/$file")) {
		    if (-e $path) {
			dry_run_chown("tfsupport", "daisy", "$path");
			dry_run_chmod(550, "$path");
		    }
		}
	    }
	    else {
		system("chown tfsupport:daisy $dsydir/$file");
		system("chmod 550 $dsydir/$file");
	    }
	}

	my @dsy_data_files = qw(
		*.arc
		*.dsy
		*.ftd
		*.hsp
		*.idx
		*.lok
		*.log
		*.map
		*.pr
		*.pos
		*.sal
		*.scr
		*.tel
		*.tgz
		*.txt
		*.rep
		hp5ctrl.*
		dcom.alv
		dcom_lock
		macros
		macros.*
		panelp.cnf
		poolflor.dat
		printers
		tcktlist.dat
		pospool/poolflor.*
		pospool/ticket.*
	);

	# Set permissions of all daisy data files
	foreach my $file (@dsy_data_files) {

		foreach my $datafile (glob("$dsydir/$file")) {
			my $owner = "tfsupport";
			my $group;
			my $perms;

			# control.dsy was already taken care of
			next if ($datafile eq "$dsydir/control.dsy");

			next unless (-e "$datafile");

			if ($datafile eq "$dsydir/crddata.pos") {
				$group = "dsyadmins";
				$perms = "464";
			}
			elsif ($datafile eq "$dsydir/dcom.alv") {
				$owner = "daisy";
				$group = "daisy";
				$perms = "664";
			}
			elsif ($datafile eq "$dsydir/dcom_lock") {
				$owner = "daisy";
				$group = "daisy";
				$perms = "755";
			}
			else {
				$group = "daisy";
				$perms = "660";
			}

			if ($DRY_RUN) {
			    dry_run_chown($owner, $group, $datafile);
			    dry_run_chmod($perms, $datafile);
			}
			else {
			    system("chown $owner:$group $datafile");
			    system("chmod $perms $datafile");
			}
		}
	}

	# list of files in /d/backup
	my @backup_dir_files = qw(
		error.txt
		log
		verify
	);

	# Change owners and modes for files in /d/backup dir
	foreach my $file (@backup_dir_files) {

		my $file_path = "$dsyroot/backup/$file";

		if (-d $file_path) {
			system("chown -R tfsupport:daisy $file_path");
			system("chmod 660 $file_path");
		}

		unless (-f $file_path) {
			next;
		}

		system("chown tfsupport:daisy $file_path");
		system("chmod 660 $file_path");
	}

	# Change permissions on the config files (if any)
	if (-d "$dsyroot/config/stuff") {
		system("chown -R root:root $dsyroot/config/*");
		system("chmod 750 $dsyroot/config/*");
	}

	# Change permissions on the crawl menu files
	# Note: skip changing the perms on the "market_input" script which
	# is a perl script that used to be located in /d/daisy/menus but is
	# is located in /d/daisy/bin... now there is just a symlink pointing
	# from /d/daisy/menus to /d/daisy/bin.

	foreach my $menufile (glob("$dsyroot/menus/*")) {

		next if ($menufile eq "$dsyroot/menus/market_input");

		system("chown tfsupport:dsyadmins $menufile");
		system("chmod 444 $menufile");
	}

	# Change permissions on the crawl program files
	my @crawl_prog_files = qw(
		crawlmenu
	);
	foreach my $file (@crawl_prog_files) {
		system("chown tfsupport:dsyadmins $dsyroot/menus/$file");
		system("chmod 555 $dsyroot/menus/$file");
	}

	# Change permissions on the putty config files
	system("chown tfsupport:dsyadmins $dsyroot/putty/*");
	system("chmod 755 $dsyroot/putty/*");

	# Change permissions on the "server" (misnomer!) scripts
	system("chown tfsupport:daisy $dsyroot/server/*");
	system("chmod 750 $dsyroot/server/*");

	# Change permissions on the startup scripts
	system("chown tfsupport:daisy $dsyroot/startup/*");
	system("chmod 750 $dsyroot/startup/*");

	# Change perms on tcc dir and files
	system("chown -R tfsupport:daisy $dsydir/tcc");
	system("chmod 770 $dsydir/tcc");
	system("chown -R tfsupport:daisy $dsydir/tcc/*");
	system("chmod 550 $dsydir/tcc/*");

	# handle one or more optional credit card processing directories
	# within daisy db dir... usually there is only "crd2" if any.

	my @alt_crd_dirs = qw(
		crd2
		crd3
		crd4
		crd5
	);

	foreach my $alt_crd_dir (@alt_crd_dirs) {

		my $alt_crd_dir_path = "$dsydir/$alt_crd_dir";

		next unless (-d $alt_crd_dir_path);

		# The alternate card dir itself
		system("chown tfsupport:daisy $alt_crd_dir_path");
		system("chmod 770 $alt_crd_dir_path");

		# Executable files in alternate card dir
		my @alt_crd_binaries = qw(
			crd
			crdmenu
			crdpos
			crdterm
		);
		foreach my $binary (@alt_crd_binaries) {
			next unless (-f "$alt_crd_dir_path/$binary");
			system("chown tfsupport:daisy $alt_crd_dir_path/$binary");
			system("chmod 550 $alt_crd_dir_path/$binary");
		}

		# Data files in alternate card dir
		my @alt_crd_datafiles = qw(
			authdat.pos
			crdaudi0.pos
			crdaudi1.pos
			crdaudi2.pos
			crdctrl.pos
			crdinet.pos
			crdinput.pos
			crdmodem.pos
			crd_scr.scr
			cutilscr.scr
			doserror.log
			firsctrl.pos
			moductrl.pos
			ncrctrl.pos
			ndc2ctrl.pos
			panelp.cnf
			paymctrl.pos
			posctrl.pos
			prsetscr.scr
			settfil0.pos
			settfil1.pos
			settfil2.pos
			settfile.pos
			vnetctrl.pos
		);
		foreach my $datafile (@alt_crd_datafiles) {
			next unless (-f "$alt_crd_dir_path/$datafile");
			system("chown tfsupport:daisy $alt_crd_dir_path/$datafile");
			system("chmod 660 $alt_crd_dir_path/$datafile");
		}

		# Sub directories in alternate card dir
		my @alt_crd_subdirs = qw(
			dsy
		);
		foreach my $subdir (@alt_crd_subdirs) {
			next unless (-d "$alt_crd_dir_path/$subdir");
			system("chown tfsupport:daisy $alt_crd_dir_path/$subdir");
			system("chmod 770 $alt_crd_dir_path/$subdir");

			next unless (-d "$alt_crd_dir_path/$subdir/printers");
			system("chown tfsupport:daisy $alt_crd_dir_path/$subdir/printers");
			system("chmod 660 $alt_crd_dir_path/$subdir/printers");
		}

		# The tcc sub dir in the alternate card dir

		next unless (-d "$alt_crd_dir_path/tcc");

		system("chown -R tfsupport:daisy $alt_crd_dir_path/tcc");
		system("chmod 770 $alt_crd_dir_path/tcc");
		system("chown -R tfsupport:daisy $alt_crd_dir_path/tcc/*");
		system("chmod 550 $alt_crd_dir_path/tcc/*");
	}

	return 0;
}


sub dry_run_process_file
{
    if ($File::Find::name ne "") {
	push(@FilePaths, $File::Find::name);
    }
}
 
sub dry_run_find_file_paths
{
    my (@dir_path) = @_;

    @FilePaths = ();
    find(\&dry_run_process_file, @dir_path);
}

sub dry_run_chown
{
    my ($owner, $group, $path) = @_;

    my $file_owner = getpwuid((stat($path))[4]);
    my $file_group = getgrgid((stat($path))[5]);

    if ($file_owner ne $owner && $file_group ne $group) {
	print "chown $owner:$group $path\n";
    }
    elsif ($file_owner ne $owner) {
	print "chown $owner $path\n";
    }
    elsif ($file_group ne $group) {
	print "chgrp $group $path\n";
    }

    return(1);
}

sub dry_run_chmod
{
    my ($mode, $path) = @_;

    my $file_mode = sprintf '%03o', (stat $path)[2] & 07777;

    if ($file_mode ne $mode) {
	print "chmod $mode $path\n";
    }

    return(1);
}


#
# Function to determine if an arbitrary path is a path to a
# daisy databse directory.
#
sub is_daisy_db_dir
{
	my ($path) = @_;

	# must begin with '/d/'
	return(0) unless ($path =~ /^\/d\//);

	# must be a directory
	return(0) unless (-d $path);

	# skip old daisy dirs
	return(0) if ($path =~ /^\/d\/.+-\d{12}$/);

	# must contain the magic files
	return(0) unless (-e "$path/flordat.tel");
	return(0) unless (-e "$path/control.dsy");

	# must be daisy 8.0+
	return(0) unless (-d "$path/bin");

	return(1);
}


sub count_dir_entries
{
        my ($dirpath) = @_;

        opendir(DIR, $dirpath) or return(0);
                my @dirents = readdir(DIR) or return(0);
        closedir(DIR);

        return(scalar @dirents);
}


sub set_dir_perms
{
	my ($dirpath, $perms) = @_;

	opendir(DIR, $dirpath);
	foreach my $dirent (readdir(DIR)) {
		next if ($dirent =~ /\.$/);     # Non-admin writable directory
		next if ($dirent =~ /\.\.$/);   # A must have "skip".

		system("chmod -R $perms $dirpath/$dirent");

	}
	closedir(DIR);

	return(1);
}

sub loginfo
{
	my ($msg) = @_;

	print("$msg\n");
	logit($msg, 'I');

	return(1);
}

sub logwarning
{
	my ($msg) = @_;

	print("Warning: $msg\n");
	logit($msg, 'W');

	return(1);
}

sub logerror
{
	my ($msg) = @_;

	print("Error: $msg\n");
	logit($msg, 'E');

	return(1);
}

sub logit
{
        my ($msg, $msg_type) = @_;
        my $tag = "$PROGNAME";

        system("/usr/bin/logger -i -t $tag -- \"$UID: <$msg_type> $msg\"");

	return($?);
}


__END__

=pod

=head1 NAME

dsyperms.pl - set the perms of files and directories in a Daisy tree


=head1 VERSION

This documenation refers to version: $Revision: 1.16 $


=head1 USAGE

dsyperms.pl B<--version>

dsyperms.pl B<--help>

dsyperms.pl B<--install>

dsyperms.pl [--dry-run] /path/to/daisydb


=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--install>

Copy the script to the ostools directory and
make the links to it in all of the Daisy database directories.

=item B<--dry-run>

Don't actually change any perms, merely output to stdout
the list of files that would have been changed had this option
not been specified and how they would be changed.

=back


=head1 DESCRIPTION

The I<dsyperms.pl> script sets the perms and modes for all the files and
directories in the Daisy database directory specified as the one and only
allowed command line argument.


=head1 FILES

=over 4

=item B</d/daisy>

The default Daisy database directory.

=item B</d/ostools/bin>

The ostools bin directory on a Daisy system.

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status 0

Successful completion.

=item Exit status 1

In general, there was an issue with the syntax of the command line.

=item Exit status 2

Other than the command line options "--version" and "--help",
the user must be root or running under "sudo".

=back


=head1 SEE ALSO

chmod(1), chown(1)


=cut
