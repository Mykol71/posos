NAME
    dsyperms.pl - set the perms of files and directories in a Daisy tree

VERSION
    This documenation refers to version: $Revision: 1.16 $

USAGE
    dsyperms.pl --version

    dsyperms.pl --help

    dsyperms.pl --install

    dsyperms.pl [--dry-run] /path/to/daisydb

OPTIONS
    --version
        Output the version number of the script and exit.

    --help
        Output a short help message and exit.

    --install
        Copy the script to the ostools directory and make the links to it in
        all of the Daisy database directories.

    --dry-run
        Don't actually change any perms, merely output to stdout the list of
        files that would have been changed had this option not been
        specified and how they would be changed.

DESCRIPTION
    The *dsyperms.pl* script sets the perms and modes for all the files and
    directories in the Daisy database directory specified as the one and
    only allowed command line argument.

FILES
    /d/daisy
        The default Daisy database directory.

    /d/ostools/bin
        The ostools bin directory on a Daisy system.

DIAGNOSTICS
    Exit status 0
        Successful completion.

    Exit status 1
        In general, there was an issue with the syntax of the command line.

    Exit status 2
        Other than the command line options "--version" and "--help", the
        user must be root or running under "sudo".

SEE ALSO
    chmod(1), chown(1)

