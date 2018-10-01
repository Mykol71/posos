#
# $Revision: 1.3 $
# Copyright 2014 Teleflora
#
# Filesystem module for OSTools.
#

package OSTools::Filesys;

use strict;
use warnings;
use Carp;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default.

our @EXPORT = qw(
    filesys_module_version
    filesys_df
    filesys_uuid
);

# Perl module method of getting CVS/RCS version number into variable
our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);


# Preloaded methods go here.

sub filesys_module_version
{
    return($VERSION);
}


# Answers the question: how much space is left in the file system
# at the specified mount point?
#
# Parses the output of the "df" command which is assumed to look
# like this:
#
#Filesystem           1k-blocks          Used    Available Use% Mounted on
#/dev/cciss/c0d0p1     26204060      22578308      2294656  91% /
#
# fs_stats[0]       fs_stats[1]   fs_stats[2]  fs_stats[3]
#
# Returns
#   reference to a hash with keys:
#	{path}      = the path to the device file for the block
#                     device that contains the filesystem.
#	{blocks}    = the number of 1-k blocks contained in the filesystem.
#	{used}      = the number of 1-k blocks used in the filesystem.
#	{available} = the number of available 1-k blocks in the filesystem.
#	{mount}     = the path to the mount point of the filesystem.
#
sub filesys_df
{
    my ($mount_point) = @_;

    my %fs = ();

    if (-e $mount_point) {
	my $cmd = "df -k";
	if (open(my $pipe, '-|', "$cmd $mount_point")) {
	    while(<$pipe>) {
		next until(/$mount_point/);
		chomp;
		my @fs_stats = split(/\s+/);
		if (@fs_stats) {
		    $fs{path} = $fs_stats[0];
		    $fs{blocks} = $fs_stats[1];
		    $fs{used} = $fs_stats[2];
		    $fs{available} = $fs_stats[3];
		    $fs{mount} = $fs_stats[5];
		    last;
		}
	    }
	    close($pipe);
	}
	else {
	    carp "error opening pipe to $cmd to get free space for: $mount_point";
	}
    }
    else {
	carp "mount point does not exist: $mount_point";
    }

    return(\%fs);
}


#
# Get the file system UUID from the specified backup device.
#
# Returns
#   non-empty string with 36 character UUID
#   empty string if UUID can not be found
#
sub filesys_uuid
{
    my ($device) = @_;

    if ($device eq "") {
	return("");
    }

    my $filesys_uuid  = "";

    # UUIDs are 16 bytes numbers encoded in a string as 2 hex digits
    # per byte, with 4 hyphens in the string, in the form 8-4-4-4-12,
    # thus 36 chars long.
    my $UUID_LENGTH_MAGIC = 36;

    # Get a unique identifier for this particular file system. This uuid
    # changes whenever the device is formatted. This works on RHEL5
    # with both block devices and "file" images.
    my $cmd = "/sbin/dumpe2fs";
    my $cmd_opts = "-h";
    if (-f $cmd) {
	if (open(my $pipe, '-|', "$cmd $cmd_opts $device 2>&1")) {
	    while (<$pipe>) {
		if (/Filesystem UUID:\s+(\S+)/) {
		    $filesys_uuid = $1;
		}
	    }
	    close($pipe);
	}
	else {
	    carp "error opening pipe to: $cmd $cmd_opts $device";
	}
    }
    else {
	carp "command missing: $cmd";
    }

    if (length($filesys_uuid) == $UUID_LENGTH_MAGIC) {
	return($filesys_uuid);
    }

    # Try another way to get the UUID.
    $cmd = "/sbin/blkid";
    $cmd_opts = "-c /dev/null";
    if (-f $cmd) {
	if (open(my $pipe, '-|', "$cmd $cmd_opts $device")) {
	    while (<$pipe>) {
		if (/UUID=\"([^\"]+)\"/) {
		    $filesys_uuid = $1;
		}
	    }
	    close($pipe);
	}
	else {
	    carp "error opening pipe to: $cmd $cmd_opts $device";
	}
    }
    else {
	carp "command missing: $cmd";
    }

    unless (length($filesys_uuid) == $UUID_LENGTH_MAGIC) {
	$filesys_uuid  = "";
    }

    return($filesys_uuid);
}

1;


__END__

=head1 NAME

OSTools::Filesys - Perl module for library of filesystem functions


=head1 SYNOPSIS

  use lib '/usr/local/ostools/modules';

  use OSTools::Filesys;

  my $module_version = filesys_module_version();
  my $href = filesys_df("/");
  my $uuid = filesys_uuid("/dev/sda1");


=head1 DESCRIPTION

The C<OSTools::Filesys> module implements functions which
provide information about filesystems.

=head2 EXPORT

=over 4

=item function C<OSTools::Filesys::filesys_module_version>

A call to this function returns the version string of the module.
This version string is simply the CVS revision string of the
source file of the module.

=item function C<OSTools::Filesys::filesys_df>

The path to the mount point of a filesystem must be specified
as the input argument in a call to this function and
a reference to a hash is returned.

The keys available are:

C<{path}> = the path to the device file for the block
device that contains the filesystem.

C<{blocks}> = the number of 1-k blocks contained in the filesystem.

C<{used}> = the number of 1-k blocks used in the filesystem.

C<{available}> = the number of available 1-k blocks in the filesystem.

C<{mount}> = the path to the mount point of the filesystem.

=item function C<OSTools::Filesys::filesys_uuid>

The path to the device file for a block device with a
filesystem must be specified as the input argument
in a call to this function and
a string with the UUID is returned.

=back


=head1 SEE ALSO

B<updateos.pl>, B<rtibackup.pl>, B<tfsupport.pl>, B<dsyuser.pl>, B<harden_linux.pl>,
B<tfprinter.pl>, B<tfremote.pl>

B<http://rtihardware.homelinux.com/ostools/ostools.html>

=cut
