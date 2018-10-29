NAME
    updateos.pl - Teleflora Operating System Updater

VERSION
    This documenation refers to version: $Revision: 1.347 $

USAGE
    updateos.pl

    updateos.pl --version

    updateos.pl --help

    updateos.pl --verbose

    updateos.pl --baremetal

    updateos.pl --rti14

    updateos.pl --[no]rti14-truncated

    updateos.pl --daisy

    updateos.pl --daisy-start

    updateos.pl --daisy-stop

    updateos.pl --daisy-shopcode

    updateos.pl --daisy-shopname

    updateos.pl --rti-shopcode

    updateos.pl --rti-shopname

    updateos.pl --ospatches

    updateos.pl --ostools

    updateos.pl --java

    updateos.pl --java-version=s

    updateos.pl --ipaddr=s [--ifname=s] [--netmask=s --gateway=s]

    updateos.pl --namserver=s

    updateos.pl --(i18n|gen-i18n-conf)

    updateos.pl --locale

    updateos.pl --yum

    updateos.pl --ups [--(ups-serial|ups-usb)]

    updateos.pl --cupsconf

    updateos.pl --cupstmp

    updateos.pl --purgeprint

    updateos.pl --purgerpms

    updateos.pl --keepkernels=n

    updateos.pl --(inittab|default-runlevel)

    updateos.pl --default-target

    updateos.pl --default-password-hash

    updateos.pl --syslog-mark=n

    updateos.pl --kernel-msg-console=n

    updateos.pl --samba-gen-conf

    updateos.pl --samba-set-passdb

    updateos.pl --samba-rebuild-passdb

    updateos.pl --bbj-gen-settings-file

    updateos.pl --bbj-gen-properties-file

    updateos.pl --configure-grub2

    updateos.pl --init-console-res

    updateos.pl --enable-boot-msgs

    updateos.pl --disable-kms

    updateos.pl --uninstall-readahead

    updateos.pl --sub-mgr-identity

    updateos.pl --sub-mgr-register

    updateos.pl --sub-mgr-unregister

    updateos.pl --sub-mgr-status

    updateos.pl --audit-system-configure

    updateos.pl --audit-system-rules-file=s

    updateos.pl --swapon

    updateos.pl --report-swap-size

    updateos.pl --report-architecture

OPTIONS
    --version
        Output the version number of the script and exit.

    --help
        Output a short help message and exit.

    --verbose
        For some operations, output more information.

    --baremetal
        Perpare a system to be ready for installation of a POS, either Daisy
        or RTI. It is assumed that the system has been kickstarted but has
        had no other prep.

    --rti14
        Assumes that the system has only had a kickstart and "updateos.pl
        --baremetal" run on it. Verify that the system is ready for
        installation of the RTI Point of Sales system and further prepare
        for the installation of RTI. Do not install Java, BBj, or BLM.

    --[no]rti14-truncated
        The default action for --rti14 is a truncated RTI install, i.e.
        --rti14-truncated is the default. To perform a full RTI install,
        specify --rti14 --norti14-truncated.

    --daisy
        Install the Daisy POS onto a system. It is assumed that the system
        has been kickstarted and only had --baremetal run on it.

    --daisy-start
        Start the Daisy POS application - assumes it is stopped.

    --daisy-stop
        Stop the Daisy POS application - system will be at runlevel 4 after
        running this option.

    --daisy-shopcode
        Output the Daisy shopcode.

    --daisy-shopname
        Output the Daisy shopname.

    --rti-shopcode
        Output the RTI shopcode.

    --rti-shopname
        Output the RTI shopname.

    --ospatches
        Configure yum to allow kernel updates. Then, purge old kernels.
        Finally, run a "yum clean" and then a "yum update" command.

    --ostools
        Download the OSTools install script "install-ostool.pl" from the
        Teleflora Managed Services web site and execute it to install the
        latest version of OSTools. The --norun-harden-linux is specified on
        the install script command line so that the new "harden_linux.pl"
        script is installed but not executed.

    --java
        Install the latest version of the Oracle Java JRE package.

    --java-version=s
        Install the version of the Oracle Java JRE package specified.

    --ipaddr=s
        Change the IP address of the system.

    --nameserver=s
        Change the DNS name server of the system.

    --(i18n|gen-i18n-conf)
        Generate a new instance of the internationalization config file.

    --locale
        Set the system locale to "en_US".

    --yum
        Edit the yum config file so that kernel updates will be perfomed.

    --ups (--ups-serial|--ups-usb)
        Download and install the APC UPS software, generate an appropriate
        config file, and install an "APC on battery" script.

    --cupsconf
        Edit several values in the /etc/cups/cupsd.conf file.

    --cupstmp
        Remove all zero sized files from /var/spool/cups/tmp.

    --purgeprint
        Remove ALL regular files recursively starting from /var/spool/cups.

    --purgerpms
        Remove all old kernel RPMs older than the last 8 (default). The
        value of the number of old kernels saved may be changed via the
        --keepkernels=n command line option.

    --keepkernels=n
        The number of kernels saved saved via --ospatches and --purgerpms
        may be set via the --keepkernels=s commandline option. The minimum
        value is 2. If the script is run on is a Dell T300 system, then the
        number of kernels saved is automatically set to the minimum due to
        limited space in the "/boot" partition.

    --(inittab|default-runlevel)
        Configure the default runlevel in the /etc/inittab file.

    --default-target
        Configure the systemd default target to "multi-user".

    --default-password-hash
        Configure the default password hash "sha512".

    --syslog-mark=n
        Configure the syslog mark message period.

    --kernel-msg-console=string
        Configure syslog to direct kernel messages to specified tty device.

    --samba-gen-conf or --samba
        Generate a Samba conf file appropriate to the POS installed.

    --samba-set-passdb
        Configure samba to use a "passdb backend" of "smbpasswd".

    --samba-rebuild-passdb
        Rebuild the samba "smbpasswd" file.

    --bbj-gen-settings-file
        Generate a BBj settings file.

    --bbj-gen-properties-file
        Generate a BBj properties file.

    --configure-grub2
        For RHEL7 systems, enable verbose boot messages by editing the GRUB2
        config file and then running the "grub2-mkconfig" utility.

    --init-console-res
        Initialize the console resolution by editing the GRUB config file.
        All kernel lines in the config file that have not already been
        appropriately modified will be changed.

    --enable-boot-msgs
        Enable verbose boot messages by editing the GRUB config file. All
        kernel lines in the config file that have not already been
        appropriately modified will be changed.

    --disable-kms
        Disable kernel (video) mode setting by editing the GRUB config file.
        All kernel lines in the config file that have not already been
        appropriately modified will be changed.

    --uninstall-readahead
        If platform is "RHEL6", uninstall the "readahead" RPM package.

    --sub-mgr-identity
        Report the subscription manager system identity.

    --sub-mgr-register
        Register the system via subscription manager.

    --sub-mgr-unregister
        Unregister the system via subscription manager.

    --sub-mgr-status
        Report the subscription manager status.

    --audit-system-configure
        Configure the audit system by installing a rules file in
        /etc/audit/rules.d and restarting the auditd system service.

    --audit-system-rules-file=s
        Specify an audit system rules file for use by the
        --audit-system-configure option.

    --swapon
        For RTI systems only, enable swap space.

    --report-swap-size
        Report suggested sawp partition size in GB for the current installed
        RAM size according to Red Hat recommendations.

    --report-architecture
        Report the system architecture. Values are either "i386" or
        "x86_64".

DESCRIPTION
    This *updateos.pl* script provides many essential methods used to setup
    and configure a Red Hat Linux system for use as a Teleflora POS server.

  COMMAND LINE OPTIONS
    The "--java" command line option downloads and installs the Oracle Java
    SE JRE package. The Java package file for RHEL 32-bit servers is
    downloaded from
    "http://rtihardware.homelinux.com/ks/jre-latest-linux-i586-rpm.bin", and
    for RHEL 64-bit servers is downloaded from
    "http://rtihardware.homelinux.com/ks/jre-latest-linux-x64-rpm.bin".

    The "--java-version=s" command line option may be used to specify a
    specific version of the Java SE JRE package. For example, to install the
    version of the Java JRE from package file "jre-6u31-linux-x64-rpm.bin"
    on a 64-bit server, specify "--java-version=6u31". The default version
    is "latest".

    The "--daisy" command line option can be specified to make system
    configuration changes appropriate for Daisy 8.0 and later systems. These
    changes include the following:

    o   IP addr

        Check the method of booting in
        /etc/sysconfig/network-scripts/ifcfg-eth0 and if it's "DHCP", log an
        error and exit.

    o   File System Remounting

        The /teleflora file system is remounted as the /d file system.

    o   Mount Options

        On RHEL7 systems, the "nofail" mount option is added to the entry
        for /d.

    o   CDROM

        On RHEL5 and RHEL6 systems, add an /etc/fstab entry for the CD-ROM.

    o   Mount Points

        Make mount points /mnt/cdrom and /mnt/usb if they do not exist.

    o   Samba

        If Samba has not been configured, generate and install a Samba
        config file appropriate for Daisy.

    o   Standard users

        Make the standard Daisy users.

    o   Locale

        On RHEL5 and RHEL6 systems, generate a new /etc/sysconfig/i18n file.
        On RHEL7 systems, set the system locale.

    The "--rti14" command line option can be specified to make system
    configuration changes appropriate for RTI version 14. These changes
    include the following:

    o   Red Hat Network

        Verify that the system is registered with the Red Hat Network. If
        not, log an error message and exit.

    o   IP addr

        Check the method of booting in
        /etc/sysconfig/network-scripts/ifcfg-eth0 and if it's "DHCP", log an
        error and exit. The default network device name is "eth0" but an
        alternate network device name may be specified with the "--ifname"
        command line option.

    o   File System Remounting

        The /teleflora file system is remounted as the /usr2 file system.

    o   Mount Options

        On RHEL7 systems, the "nofail" mount option is added to the entry
        for /usr2.

    o   Red Hat Package Installation

        On RHEL5, RHEL6, and RHEL7 platforms, install the "apache",
        "fetchmail", and "ksh" packages. On RHEL5 platforms, install the
        "uucp" package.

    o   Default RTI Users

        Add the default RTI groups: "rti" and "rtiadmins". Add the default
        RTI user accounts: "tfsupport" and "rti". Add the default RTI samba
        accounts: "odbc" and "delivery".

    o   Samba Configuration

        If the Samba configuration has not already been modified, generate
        the RTI Samba configuration file. Add the RTI users "rti", "odbc",
        and "delivery" to the Samba password file.

    o   RTI Package Installation

        If only the --rti14 option is specified, then no further actions are
        performed. If the --rti14 --norti14-trunc is specified, then
        additionally Java, BBj, BBj config files, BLM and BLM config files
        are installed.

    The "--ipaddr=s" command line option may be used to change the IP
    address of any specified ethernet interface. By default, the ethernet
    interface config file for the ethernet interface named "eth0" is edited;
    the path to that file is /etc/sysconfig/network-scripts/ifcfg-eth0.
    Along with ifcfg file, the system hosts file /etc/hosts is also updated.
    An alternate ifcfg file may be specified via the "--ifname=s" command
    line option. If the IP address specified is not the default value of
    "192.168.1.21", then the "--netmask=s" and the "--gateway=s" command
    line options must also be specified. In order for the new IP address to
    take effect, either the "network" service must be restarted or the
    system must be rebooted.

    The "--nameserver=s" command line option actually generates entirely new
    contents for the /etc/resolv.conf file. The previous contents are
    removed so if you need to save them, make a copy of the file before
    running this command. The specified IP address is used as the IP address
    of the DNS name server.

    The "--(i18n|gen-i18n-conf)" command line option actually generates
    entirely new contents for the /etc/sysconfig/i18n config file. The
    previous contents are removed so if you need to save them, make a copy
    of the file before running this command. This option is only valid on
    RHEL5 and RHEL6 systems.

    The "--locale" command line option issues the localectl set-locale
    command to set the system locale to "en_US". This command also updates
    the system locale config file /etc/locale/conf with the new value so it
    is preserved across reboots. This command line option is only supported
    on RHEL7 platforms.

    The "--yum" command line option checks the contents of /etc/yum.conf. If
    the line "exclude=kernel" appears, the file is edited to comment out
    that line.

    The "--(inittab|default-runlevel)" command line option edits the
    /etc/inittab file if there is one, and sets the default system runlevel
    to "3", ie multi-user. This option is only valid on RHEL5 and RHEL6
    systems.

    The "--default-target" command line option sets the systemd default
    target to "multi-user". This option is only valid on RHEL7 systems.

    The "--syslog-mark" command line option can be specified to configure
    *syslog* on RHEL5 systems and *rsyslog* on RHEL6 systems to write a
    "mark" message to the syslog log file at the specified period.

    For *rsyslog* on RHEL6:

    The following 2 lines must be added to the beginning of the
    */etc/syslog.conf* conf file:

    $ModLoad immark.so $MarkMessagePeriod 1200

    The "$ModLoad" line is a directive to load the input module "immark.so"
    which provides the mark message feature. The "$MarkMessagePeriod" line
    is a directive to specify the number of seconds between mark messages.
    This directive is only available after the "immark" input module has
    been loaded. Specifying 0 is possible and disables mark messages. In
    that case, however, it is more efficient to NOT load the "immark" input
    module. In general, the last directive to appear in file wins.

    For *syslog* on RHEL5:

    In the */etc/sysconfig/syslog* conf file, the "SYSLOGD" variable must
    have the "-m" option changed to have a non-zero value if it appears. If
    the "-m" option does not appear, then the default value for the mark
    message period is 20 minutes. If the value specified with the "-m"
    option is 0, then the mark message is not written.

    The "--kernel-msg-console" command line option can be specified to
    configure *syslog* on RHEL5 systems and *rsyslog* on RHEL6 systems to
    direct kernel messages to specified tty device. The syslog system
    service will be restarted after a succeful change to the config file.

    The "--samba-gen-conf" command line option generates an entirely new
    Samba conf file appropriate to POS installed, either "RTI" or "Daisy".
    The "RTI" and "Daisy" version of the Samba conf file are considerably
    different. If a new Samba conf file is generated, the Samba system
    service "smb" is restarted.

    The "--samba-set-passdb" command line option can be used to configure
    samba to use a "passdb backend" of "smbpasswd". It does this by editing
    the existing Samba conf file, adding the parameter "passdb backend =
    smbpasswd" to the "[global]" section of the Samba conf file. If the
    Samba conf file is already so configured, then no change is done. If the
    Samba conf file is modified, the Samba system service "smb" is
    restarted.

    The "--samba-rebuild-passdb" command line option can be used to rebuild
    the samba "smbpasswd" file. The only field updated in "smbpasswd" file
    is the "UID" field: if the value in the "UID" field of the "smbpasswd"
    file does not match the "UID" field in the "/etc/passwd" file for the
    username in the "username" field of the "smbpasswd" file, then the UID
    from the "/etc/passwd" file is substituted for the value in the
    "smbpasswd" file.

    The --bbj-gen-settings-file command line option is useful for system
    stagers and OSTools testers to see what the contents of the BBj settings
    file would be when produced for the --rti14 option. The BBj settings
    file is written to the current working directory and is available for
    inspection but is not used or incorporated into the RTI system in any
    way.

    The --bbj-gen-properties-file command line option is useful for system
    stagers and OSTools testers to see what the contents of the BBj
    properties file would be when produced for the --rti14 option. The BBj
    properties file is written to the current working directory and is
    available for inspection but is not used or incorporated into the RTI
    system in any way.

    The "--disable-kms" command line option is used to disable kernel
    (video) mode setting. For Daisy customers that use the console of the
    Daisy server as a workstation, disabling KMS is required or Daisy
    application screens do not appear correctly on the virtual consoles. The
    code for this option is also executed when the "--baremetal" option is
    specified.

    Specifying the "--cupsconf" command line option will cause udpateos.pl
    to edit the values of several variables in the /etc/cups/cupsd.conf CUPS
    config file. The code for this option is also executed when the
    "--baremetal" option is specified. The following variables are set to
    the specified values:

    o   MaxJobs is set to 10000

    o   PreserveJobHistory is set to "No"

    o   PreserveJobFiles is set to "No"

    o   If the platform is "RHEL5", Timeout is set to 0. If the platform is
        "RHEL6", Timeout is set to 300.

    o   ErrorPolicy is set to "retry-job"

  Linux Audit System Configuration
    The "--audit-system-configure" command line option provides a method of
    configuring the Linux Audit System with an appropriate config file and
    restarting the auditd system service. If the audit system is already
    configured, then no configuration is performed.

    The "--audit-system-rules-file=path" command line option can be used in
    conjunction with "--audit-system-configure" to explicitly specify a
    "rules" file to be used as a configuration file for the audit system,
    ie, it is copied to /etc/audit/rules.d and the "auditd" system service
    is restarted. Before the path specified with
    "--audit-system-rules-file=path" is used, it is checked for security
    issues and if verified "OK", it will be used to configure the audit
    system. If there are issues with the path, eg there are illegal
    characters in the file name, a warning is output and no configuration is
    performed.

    If "--audit-system-configure" is specifed without
    "--audit-system-rules-file=path", then the following strategy will be
    used to determine where to find the rules file in the following order:

    (1) from the environment
        if the rules file is specified in the environement via the variable
        `AUDIT_SYSTEM_RULES_FILE`, the value will be verified as secure and
        used as the rule file.

    (2) from the OSTools config dir
        if on RTI systems, there is a rules file in the ostools config dir
        named rti.rules or if on Daisy systems there is a rules file in the
        ostools config dir named daisy.rules, it will be used as the rule
        file.

    (3) from a remote server
        if on RTI systems, there is a rules file at the URL
        "http://rtihardware.homelinux.com/ostools/rti.rules" or if on Daisy
        systems, there is a rules file at URL
        "http://rtihardware.homelinux.com/ostools/daisy.rules", then it will
        be used as the rule file.

    (4) rules generated by script
        a default rules file appropriate to the POS will be generated and
        used as the rule file.

EXAMPLES
    Perform a truncated RTI install
         $ sudo updateos.pl --rti14

    Perform a full RTI install
         $ sudo updateos.pl --rti14 --norti14-trunc

    Change IP address of network device "eth0" to 192.168.2.32
         $ sudo updateos.pl --ipaddr=192.168.2.32 --netmask=255.255.255.0 --gateway=192.168.2.1

    Change IP address of network device "eth1" to 192.168.2.33
         $ sudo updateos.pl --ipaddr=192.168.2.33 --ifname=eth1 --netmask=255.255.255.0 --gateway=192.168.2.1

    Get Status of Ungregistred System with Subscription Manager
         $ sudo updateos.pl --sub-mgr-status
         [sub-mgr] subscription manager status: Unknown

    Register System with the Subscription Manager
         $ sudo updateos.pl --sub-mgr-register
         The system has been registered with ID: 2c1e0459-a8c3-42a4-92bf-d802a742c736 
         Installed Product Current Status:
         Product Name: Red Hat Enterprise Linux Server
         Status:       Subscribed

         [sub-mgr] system registered via subscription manager

    Get Status of Registred System with Subscription Manager
         $ sudo updateos.pl --sub-mgr-status
         [sub-mgr] subscription manager status: Current

    Get Identity of Registered System with Subscription Manager
         $ sudo updateos.pl --sub-mgr-identity
         [sub-mgr] subscription manager system identity: 2c1e0459-a8c3-42a4-92bf-d802a742c736

    Unregister System with the Subscription Manager
         $ sudo updateos.pl --sub-mgr-unregister
         1 subscription removed at the server.
         1 local certificate has been deleted.
         System has been unregistered.
         [sub-mgr] system unregistered via subscription manager

FILES
    /usr2/bbx/log/RTI-Patches.log
        Logfile for RTI systems.

    /d/daisy/log/RTI-Patches.log
        Logfile for Daisy systems.

    /boot/grub/grub.conf
        The GRUB config file.

    /etc/default/grub
        For RHEL7 systems, the GRUB2 config file.

    /etc/sysconfig/syslog
        The configuration file for the syslog system service that needs to
        be edited for configuring the heartbeat. This is for RHEL5 only.

    /etc/rsyslog.conf
        For RHEL6 systems, the configuration file for the syslog system
        service that needs to be edited for configuring the heartbeat.

    /etc/samba/smb.conf
        The Samba configuration file.

    /etc/samba/smbpasswd
        The Samba password file when the "passdb backend = smbpasswd" is
        specified in the Samba conf file.

    /var/lib/samba/private/smbpasswd
        For RHEL6 and RHEL7 systems, the Samba password file when the
        "passdb backend = smbpasswd" is specified in the Samba conf file.

    jre-latest-linux-i586-rpm.bin
        The latest version of the Java SE JRE package file for RHEL 32-bit
        servers.

    jre-latest-linux-x64-rpm.bin
        The latest version of the Java SE JRE package file for RHEL 64-bit
        servers.

    /etc/cups/cupsd.conf
        The values of several variables are set.

    /var/spool/cups
        Directory containing files which represent completed and in-process
        CUPS print jobs.

    /etc/sysconfig/network-scripts/ifcfg-eth0
        This file is edited when the "--ipaddr=s" command line option is
        specified.

    /etc/hosts
        This file is edited when the "--ipaddr=s" command line option is
        specified.

    /etc/resolv.conf
        A new instance of this file is generated when the "--nameserver=s"
        command line option is specified.

    /etc/sysconfig/i18n
        For RHEL5 and RHELl6 platforms only, a new instance of this file is
        generated when the "--(i18n|gen-i18n-conf)" command line option is
        specified. Also, a new instance is generated as part of all the
        other the changes when --daisy is specified.

    /etc/yum.conf
        If the line "exclude=kernel" appears in this file, the line will be
        commented out by "--yum".

    /etc/locale.conf
        On RHEL7 systems, this config file is edited to set the system
        locale.

    /etc/inittab
        On RHEL5 and RHEL6 systems, this config file is edited to set the
        default runlevel of the system.

    /etc/systemd/system/default.target
        On RHEL7 systems, this symlink is edited to set the default target
        of the system to "multi-user".

    /etc/fstab
        On RHEL7 systems, the "nofail" mount option is added to the entries
        for /usr2 and /d.

    /etc/audit/rules.d/daisy.rules
        The Linux Audit System rules file for Daisy systems.

    /etc/audit/rules.d/rti.rules
        The Linux Audit System rules file for RTI systems.

    /proc/meminfo
        The contents of this file is used for getting the size of RAM.

    bbjinstallsettings.txt
        The BBj settings file generated for the --rti14 option and only used
        during staging.

    /usr2/basis/cfg/BBj.properties
        The BBj properties file.

DIAGNOSTICS
    Exit status 0 ($EXIT_OK)
        Successful completion.

    Exit status 1 ($EXIT_COMMAND_LINE)
        In general, there was an issue with the syntax of the command line.

    Exit status 2 ($EXIT_MUST_BE_ROOT)
        For all command line options other than "--version" and "--help",
        the user must be root or running under "sudo".

    Exit status 3 ($EXIT_SAMBA_CONF)
        During the execution of "--samba-set-passdb" or
        "--samba-rebuild-passdb", either the Samba conf file is missing, or
        can't be modified.

    Exit status 4 ($EXIT_GRUB_CONF)
        An unexpected error occurred during editing the GRUB config file.
        The original GRUB config file will be left unchanged.

    Exit status 5 ($EXIT_ARCH)
        The machine architecture of the system is unsupported (should not
        happen).

    Exit status 6 ($EXIT_NO_SWAP_PARTITIONS)
        There were no swap partitions found on either /dev/sda or /dev/sdb
        when attempting to enable swapping via --swapon.

    Exit status 7 ($EXIT_MODIFY_FSTAB)
        Could not update the /etc/fstab file when attempting to enable
        swapping via --swapon.

    Exit status 8 ($EXIT_RAMINFO)
        Could not open the /proc/meminfo file for getting the size of RAM.

    Exit status 10 ($EXIT_JAVA_VERSION)
        The name of the Java JRE package to be downloaded from
        "rtihardware.homelinux.com" could not be determined.

    Exit status 11 ($EXIT_JAVA_DOWNLOAD)
        The Java JRE package from "rtihardware.homelinux.com" could not be
        downloaded.

    Exit status 12 ($EXIT_JAVA_INSTALL)
        The RPM from the download of the Java JRE package from
        "rtihardware.homelinux.com" could not be installed.

    Exit Status 13 ($EXIT_RTI14)
        The "--rti14" command line option was run and the system was not
        configured with a static IP address.

    Exit Status 15 ($EXIT_READAHEAD)
        The "--uninstall-readahead" command line option was specified on a
        RHEL6 system, and the "readahead" RPM could not be removed.

    Exit Status 17 ($EXIT_SAMBA_PASSDB)
        Could not rebuild the Samba password database file.

    Exit Status 18 ($EXIT_KEEPKERNELS_MIN)
        The value specified with --keepkernels=s was less than the minimum.

    Exit Status 19 ($EXIT_PURGE_KERNEL_RPM)
        Could not purge an old kernel rpm.

    Exit Status 21 ($EXIT_WRONG_PLATFORM)
        A command line option was run on an unsupported platform.

    Exit status 22 ($EXIT_RHWS_CONVERT)
        The "--ospatches" option was run on a Red Hat Workstation 5 system
        and the conversion from "workstation" to "server" failed.

    Exit status 23 ($EXIT_UP2DATE)
        The "--ospatches" option was run on a RHEL 4 server system and the
        "up2date" process failed.

    Exit status 24 ($EXIT_YUM_UPDATE)
        The "--ospatches" option was run on a RHEL 5 or 6 server system and
        the "yum" process failed.

    Exit status 25 ($EXIT_DIGI_DRIVERS)
        The "--ospatches" option was run and the installation of the Digi
        Drivers failed.

    Exit status 26 ($EXIT_INITSCRIPTS)
        The "--ospatches" option was run and the "fixup" required for RHEL6
        Daisy systems failed. This "fixup" is only required when there is
        the installation of any updated "initscripts" pacakges; however, the
        "fixup" is run anytime the "--ospatches" option is run and the "yum"
        command which runs returns successful exit status. (the "fixup"
        merely consists of removing two files if they exist:
        /etc/init/start-ttys.conf and /etc/init/tty.conf)

    Exit status 27 ($EXIT_RHN_NOT_REGISTERED)
        The system is not registered with the Red Hat Network, and thus
        patches can not be dowloaded from Red Hat.

    Exit status 30 ($EXIT_HOSTNAME_CHANGE)
        The attempt to change the hostname of the system failed.

    Exit status 31 ($EXIT_MOTD)
        Could not truncate the "Message of the Day" (aka login banner) file.

    Exit status 32 ($EXIT_RTI_SHOPNAME)
        Could not get the RTI shop name.

    Exit status 33 ($EXIT_RTI_SHOPCODE)
        Could not get the RTI shop code.

    Exit status 34 ($EXIT_DAISY_SHOPCODE)
        Could not get the DAISY shop code.

    Exit status 35 ($EXIT_CUPS_CONF_MISSING)
        The CUPS config file does not exist. Some commands edit this file
        and if it does not exist, it is considered an error.

    Exit status 36 ($EXIT_CUPS_CONFIGURE)
        The "--cupsconf" option was specified and there was an error
        rewriting the CUPS config file.

    Exit status 37 ($EXIT_CUPS_SERVICE_STOP)
        Could not stop the CUPS system service.

    Exit status 38 ($EXIT_CUPS_SERVICE_START)
        Could not start the CUPS system service.

    Exit status 39 ($EXIT_DAISY_START)
        Could not start the Daisy POS application.

    Exit status 40 ($EXIT_SUB_MGR_IDENTIFICATION)
        The subscription manager identity could not be obtained.

    Exit status 41 ($EXIT_SUB_MGR_REGISTRATION)
        The system could not be registered via the subscription manager.

    Exit status 42 ($EXIT_SUB_MGR_UNREGISTRATION)
        The system could not be un-registered via the subscription manager.

    Exit status 43 ($EXIT_SUB_MGR_CONDITION)
        The subscription manager status could not be obtained.

    Exit status 44 ($EXIT_DAISY_STOP)
        Could not stop the Daisy POS application.

    Exit status 46 ($EXIT_DAISY_INSTALL_DHCP)
        In order to configure the system with --daisy, the network
        configuration must not be booting via DHCP.

    Exit status 47 ($EXIT_DAISY_SHOPNAME)
        Could not get Daisy shop name

    Exit status 48 ($EXIT_AUDIT_SYSTEM_CONFIGURE)
        Could not configure the Linux Audit System.

    Exit status 49 ($EXIT_CONFIGURE_DEF_PASSWORD_HASH)
        The default password hash of the system could not be changed.

    Exit status 50 ($EXIT_CONFIGURE_IP_ADDR)
        The IP address of the system could not be changed.

    Exit status 51 ($EXIT_CONFIGURE_HOSTNAME)
        The hostname of the system could not be changed.

    Exit status 52 ($EXIT_CONFIGURE_NAMESERVER)
        Could not generate a new nameserver file, ie /etc/resolv.conf.

    Exit status 53 ($EXIT_CONFIGURE_I18N))
        Could not generate a new i18n config file, ie /etc/sysconfig/i18n.

    Exit status 54 ($EXIT_CONFIGURE_YUM)
        Could not configure yum to do kernel updates.

    Exit status 55 ($EXIT_CONFIGURE_LOCALE)
        Could not configure the system wide locale.

    Exit status 56 ($EXIT_CONFIGURE_DEF_RUNLEVEL)
        Could not configure the default runlevel.

    Exit status 57 ($EXIT_CONFIGURE_DEF_TARGET)
        Could not configure the systemd default target.

    Exit status 58 ($EXIT_EDIT_FSTAB)
        Could not edit the fstab.

    Exit status 60 ($EXIT_APCUPSD_INSTALL)
        Could not install the APCUPSD rpm.

    Exit status 61 ($EXIT_BBJ_INSTALL)
        Could not install BBj.

    Exit status 62 ($EXIT_BLM_INSTALL)
        Could not install the Basis license manager.

    Exit status 70 ($EXIT_SYSLOG_CONF_MISSING)
        The syslog config file does not exist.

    Exit status 71 ($EXIT_SYSLOG_CONF_CONTENTS)
        The contents of the syslog conf file are non-standard and thus can
        not be updated.

    Exit status 72 ($EXIT_SYSLOG_KERN_PRIORITY_VALUE)
        The value of the kernel log priority was out of range.

    Exit status 73 ($EXIT_SYSLOG_KERN_PRIORITY)
        The kernel log priority could not be configured.

    Exit status 74 ($EXIT_SYSLOG_MARK_VALUE)
        The syslog mark value was out of range.

    Exit status 75 ($EXIT_SYSLOG_MARK_PERIOD)
        The syslog mark period could not be configured.

    Exit status 76 ($EXIT_SYSLOG_KERN_TARGET_VALUE)
        The syslog kernel message target was the empty string.

    Exit status 77 ($EXIT_SYSLOG_KERN_TARGET)
        The syslog kernel message tarkget could not be configured.

    Exit status 78 ($EXIT_SYSLOG_RESTART)
        The syslog system service could not be restarted.

    Exit status 79 ($EXIT_GRUB2_CONFIGURE)
        There was an error rewriting the GRUB2 config file.

    Exit status 80 ($EXIT_GRUB2_CONF_MISSING)
        The grub2 config file is missing.

SEE ALSO
    RTI Admin Guide

NAME
    harden_linux.pl - Linux operating systems security hardener

VERSION
    This documenation refers to version: $Revision: 1.136 $

USAGE
    harden_linux.pl --version

    harden_linux.pl --help

    harden_linux.pl --install [--upgrade-12-13]

    harden_linux.pl --install-configfile [--configfile=path]

    harden_linux.pl --convert-configfile [--configfile=path]

    harden_linux.pl --iptables-port=string

    harden_linux.pl [--configfile=path]

    harden_linux.pl --all [--configfile=path]

    harden_linux.pl (--ipv6 | --hostsallow | --pam | --services | --bastille
    | --logging | --logrotate | --ssh | --time | --ids) [--configfile=path]

    harden_linux.pl (--iptables | --sudo) [--configfile=path]
    [--revert-delay=n]

    harden_linux.pl (--revert-iptables | --revert-sudo)

OPTIONS
    --version
        Output the version number of the script and exit.

    --help
        Output a short help message and exit.

    --install
        Install the script.

    --upgrade-12-13
        Force an upgrade from the 1.12.x version of the script to a 1.13.x
        version.

    --all
        For convenience, this option is the same as specifying all options.

    --install-configfile
        Install a default version of the config file.

    --convert-configfile
        Convert any "append" directives to "directory" style.

    --configfile=path
        Specify the location of the config file. This option may be added to
        any of the other options.

    --revert-delay=n
        Setup an "at job" which will revert a change after 'n' minutes. This
        option may only be specified with the --iptables or --sudoers
        options.

    --revert-iptables
        Revert the last iptables change.

    --revert-sudo
        Revert the last sudo change.

    --iptables-port=string
        Allows specification of ports to open in the "iptables" firewall.

    --iptables
        Configure the iptables system service.

    --ipv6
        Disable the IPv6 features of the system.

    --hostsallow
        Generate a new "/etc/hosts.allow" file.

    --pam
        Configure login parameters via PAM.

    --sudo
        Generate a new "/etc/sudoers" file.

    --services
        Stop and disable system services not on an allowed white list.

    --bastille
        No function, present for backward compatability only.

    --logging|--logrotate
        Configure the log file rotation schedule.

    --ssh
        Generate a new instance of the sshd config file.

    --time
        Generate a new NTP "step-tickers" config file.

    --ids
        No function, present for backward compatability only.

DESCRIPTION
    The "harden_linux.pl" improves the security of the system, chiefly with
    respect to PCI security requirements. It performs this system
    "hardening", in a manner of speaking, by editing or generating config
    files which control or dictate the actions of several of the system
    facilities; some of these system facilities include: iptables, PAM,
    sudoers, hosts.allow, system services, ssh, etc.

    The "harden script" must be run as "root", ie either from the "root"
    account or via the "sudo" command; if not, the script will exit with a
    non-zero exit status .

    Each of these facilities may be changed all at once, or individually.
    The selection of which facilities to configure is accomplished via the
    configuration command line options.

    Running "harden_linux.pl" with no configuration command line options
    means to configure all the facilities under the purview of
    "harden_linux.pl". Likewise, the "--all" option is the same as if no
    configuration command line options were specified.

    There are no command line arguments expected and any specifed are
    ignored.

    Running "harden_linux.pl" with select configuration options means to
    configure just the facility specified. For example, the command:

        harden_linux.pl --iptables

    will only configure the iptables facility.

    There are other command line options that deal with details other than
    the facility to configure. There are options like "--version" to report
    the version number, and "--help" to output a brief help message.

  CONFIG FILE
    There is a config file for the "harden_linux.pl" command. The name of
    the config file is "harden_linux.conf". The default location of the
    config file is located in "/usr2/ostools/config" for RTI systems and in
    "/d/ostools/config" for Daisy systems. The path to a custom config file
    may be specified with the "--configfile=path" command line option.

    Blank lines, or lines that have only "white space", or lines that begin
    with a "#" character are ignored. Otherwise, each line is considered a
    config file directive. Each directive can tailor the behavior of
    harden_linux.pl in some way. There can be one or more directives in the
    config file.

    The are several types of directives - the first type can enable or
    disable any of the configuration options. Thus, there corresponds a
    directive for each of these options. However, if an option is enabled in
    the config file, the action associated with an option is only performed
    by "harden_linux.pl" if it is *also* specified on the command line. And
    on the contrary, an option that is disabled in the config file, then the
    action associated with that option is NOT performed even if it is
    specified on the command line. Thus, for the revertable and
    non-revertable configuration options, the config file is best used as a
    way to keep some options from being performed. This is quite useful when
    running on a host that is known to be incompatible with one of more of
    the configuration options.

    The second type of directive is the "append" directive which provides a
    method of adding content to a generated config file. Currently, the two
    config files supported are "/etc/hosts.allow" and "/etc/sudoers".

    An as example of the first type of directive, the "harden_linux.pl"
    config file can contain lines like:

     iptables=yes
     sudo=no
     ids=no

    and so on, one for each of the configuration options. The value of the
    directive is the word to the right of the EQUAL SIGN; for the
    configuration options, the word may either be "yes" or "no", "true" or
    "false", "1" or "0". The default value of a configuration option
    directive is considered to be "true".

    As an example, the "iptables" directive can be used to prevent
    configuration of the iptables facility. If the config file contains the
    line:

     iptables=no

    then when the "harden_linux.pl" script runs, the iptables facility will
    not be configured. The config file overrides any command line options.
    This can be useful for sites that are known to have networks that are
    not supported by the "harden_linux.pl --iptables" command.

    The second directive type provides a method for specifying the text that
    will be appended to the contents of a generated config file. This may be
    used to specify site dependent contents to be added to the contents
    generated by "harden_linux.pl". The syntax of this "append" command is
    very similar to the BASH Shell "here" document.

    The following command;

     harden_linux.pl --hostsallow

    generates a new "/etc/hosts.allow" config file with standard contents.
    The append directive may be used as a way to add additional, site
    dependent contents to "/etc/hosts.allow".

    For example, if the "harden_linux.pl" config file contains:

     append /etc/hosts.allow << EOF
     #Fred
     sshd:   10.10.6.0 except 10.10.6.1
     #Barney
     sshd:   10.10.7.0 except 10.10.7.1
     #Wilma
     sshd:   10.10.8.0 except 10.10.8.1
     EOF

    then the lines between the "append" line and the "marker" line, ie the
    line containing only "EOF", will be appended to "/etc/hosts.allow"
    whenever a new instance of "/etc/hosts.allow" is generated.

    Another form of the "append" command allows the specification of the
    path to a file whose contents will be appended to the "/etc/sudoers"
    config file.

    For example, if the "harden_linux.pl" config file contains:

     append /etc/sudoers == /etc/sudoers.local

    then the contents of "/etc/sudoers.local" will be appended to the
    "/etc/sudoers" file generated by "harden_linux.pl".

    Yet another method to append site specific content to "/etc/sudoers"
    file is to specify the path to a directory in the "append" directive.
    Then, the conents of any files in the directory that have a file
    extension of ".conf" will all be appended to the generated "sudoers"
    file.

    For example, if the "harden_linux.pl" config file contains:

     append /etc/sudoers == /d/ostools/config/sudoers.d

    and "/d/ostools/config/sudoers.d" is a directory, and the directory
    contains the files "tfspec.conf", "tfdefault.conf", and
    "tfdefault.conf.old", then the contents of the files "tfspec.conf" and
    "tfdefault.conf" will be concatenated and appended to the "/etc/sudoers"
    file.

    If mutltiple types of "append" directives appear in the
    "harden_linux.pl" config file, then the last "append" directive in the
    conf file will be the one that actually takes effect.

    A third directive available is the "iptables-port=n" directive. This
    directive allows the specification of additional inbound ports to open
    in the iptables "INPUT" chain of the "filter" table. One or more of
    these directives are allowed. For each directive, only 1 port number is
    allowed. The allowed value of "n" is 0 to 65535.

  COMMAND LINE OPTIONS
    The "--install" command line option performs all the steps necessary to
    install the "harden_linux.pl" script onto the system. First, a new
    default config file is installed - please see the description for the
    "--install-configfile" option for the details. Then, the version of the
    currently installed "harden_linux.pl" script is compared with the new
    version to be installed. If the old version was 1.12.x and the new
    version is 1.13.x, then the custom rules from "/etc/hosts.allow" are
    migrated to the "harden_linux.conf" file. For some situations where the
    automatic detection of an upgrade may not be possible, ie when a whole
    new OSTools package is being stalled, the upgrade step may be forced by
    specifying the "--upgrade-12-13" command line option. Thus, when
    "harden_linux.pl --all" or "harden_linux.pl --hostsallow" is run and a
    new "/etc/hosts.allow" config file is generated, these rules will be in
    place in the config file and thus be included in the new instance of the
    "/etc/hosts.allow" config file.

    The "--all" command line option is a convenience alias; this option is
    the same as specifying --iptables, --ipv6, --hostsallow, --pam, --sudo,
    --services, --bastille, --logging, --ssh, --time, and --ids.

    The "--install-configfile" command line option specifies that the
    default config file is to be installed. If a config file already exists,
    then the existing config will be left, and the new version will be
    written with the suffix ".new".

    The "--configfile=path" command line option is a way to specify an
    alternate location for the config file. The default location is in the
    OSTools directory in a directory named "config". For example, on a Daisy
    system, the default location of the config file is
    "/d/ostools/config/harden_linux.config". If the "--install-configfile"
    and "--configfile=path" are both specified on the same command line, the
    default config file will be installed at the alternate location.

    The "--revert-delay=n" command line option provides a way to revert a
    change made to the iptables config file or to the "sudo" config file.
    Changes to either of these config files could seriously subvert the
    security of the system, deny required services to the system, or prevent
    privledged access to the system. Thus, changes to them should not be
    taken lightly.

    If a change is made via "--iptables" or "--sudo", and if the
    "--revert-delay" option is also specified on the command line, then
    after the change to the system is made, an "at job" is submitted which
    will revert the system back to the way it was before the change. If the
    change made to the system was determined to be appropriate and working
    as desired, the "at job" can be cancelled (via "sudo at -d <job_nr>")
    and the change will stand. If the change did not work as desired, it
    would be reverted automatically.

    As an example, assume that the harden_linux.pl config file has a
    directive like:

     append /etc/sudoers == /d/ostools/config/sudoers.local

    which causes the contents of "/d/ostools/config/sudoers.local" to be
    appended to "/etc/sudoers" after it's generated by "harden_linux.pl". If
    the command

     harden_linux.pl --sudo --revert-delay=5

    is run, a new instance of the "/etc/sudoers" file is generated and an
    "at job" is submitted that will revert the change after 5 mintues. If
    that change happens to lock out privledged access to the system for the
    "tfsupport" account, after the time specified with the "--revert-delay"
    option has elapsed, the system will revert the change and privledged
    access will be returned.

    The "--revert-iptables" command line option will revert to the last
    change made to the iptables config file.

    The "--revert-sudo" command line option will revert to the last change
    made to sudo config file, ie "/etc/sudoers".

    The "--iptables-port=string" command line option allows the user to
    specify a comma separated list of ports to open in the "INPUT" chain of
    the "filter" table of the iptables firewall.

    The "--iptables" command line option generates a new set of iptables
    firewall rules. Currently, only hosts on the 10.0.0.0/8, 172.16.0.0/12,
    and 192.168.0.0/24 networks are supported. For systems on networks other
    than these networks, do not run the "harden_linux.pl" script with
    "--iptables" option. In fact, it is suggested that the line
    "iptables=no" be put in the "harden_linux.pl" config file so that even
    if "--iptables" is specified on the command line, it will not be done.

    The "--ipv6" command line option disables support for the IPv6 network
    protocol.

    The "--hostsallow" command line option generates a new
    "/etc/hosts.allow" file. The contents generated for the file
    "/etc/hosts.allow" will depend on the network configuration and any site
    dependent configuration specified in the harden_linux.pl conf file.
    Currently, for generation of the rule for "sshd" access to the server
    from hosts on the local network, only hosts on the 10.0.0.0/8,
    172.16.0.0/12, and 192.168.0.0/24 networks are supported. For systems on
    networks other than these networks, add a site specific rule to the
    "harden_linux.pl" conf file. For example, if your server IP address is
    193.193.1.21 and your gateway is at ip address 193.193.1.254, add a rule
    like the following to the "harden_linux.pl" conf file - this rule will
    be appended to the contents of the "/etc/hosts.allow" file after the
    contents generated by "harden_linux.pl":

     append /etc/hosts.allow << EOF
     sshd: 193.193. except 193.193.1.254
     EOF

    The "--pam" command line option configures login parameters via PAM.
    Examples are minimum length of account passwords, number of incorrect
    login attempts allowed before 30 minute timeout applied, etc.

    For RHEL5 and RHEL6 systems, a new PAM conf file named
    "/etc/pamd.d/system-auth-teleflora" is generated and a symlink named
    "/etc/pam.d/system-auth" is made to point at it. For RHEL6 systems, a
    symlink named "/etc/pam.d/passwd-auth" is also made to point at it. The
    first symlink takes care of enforcing login rules for non-SSH logins,
    while the second symlink takes care of SSH logins.

    It modifies the "/etc/securetty" file so that root logins are allowed on
    "tty12"; it modifies "/etc/security/limits.conf" so that only 1
    simultaneous Daisy admin account login is allowed, 10 simultaneous
    "root" logins are allowed, and 10 simultaneous "tfsupport" logins are
    allowed; modifies "/etc/pam.d/su" so that an "su -" will only work if
    entered on one of the white listed tty lines or virtual consoles.
    Basically, this disallows remote access to the "root" account.

    The "--sudo" command line option generates a new "/etc/sudoers" file.
    One of the directives within the new "/etc/sudoers" file establishes a
    log file named "/var/log/sudo.log" which records all commands executed
    with "sudo". Since this log file is subject to the PA-DSS rules for
    rotating and retaining log files, a "logrotate" config file named
    "/etc/logrotate.d/sudo" is generated to manage that requirment.

    There is one issue with this strategy: one some systems, the "syslog"
    log rotate config file may contain a reference to "sudo". If so, that
    reference must be removed since the "logrotate" code can not tolerate a
    reference to "sudo" in the "syslog" log rotate config file and in a
    separate log rotate config file.

    The "--services" command line option disables all systerm services that
    are not on a list of allowed system services, ie a "whitelist" of system
    services.

    The list of allowed system services for RHEL5 and RHEL6 is:

            acpid
            apcupsd
            anacron
            atd
            auditd
            blm
            bbj
            cpuspeed
            crond
            cups
            cups-config-daemon
            daisy
            dgap
            dgrp_daemon
            dgrp_ditty
            dsm_sa_ipmi
            firstboot
            httpd
            instsvcdrv
            ipmi
            iptables
            irqbalance
            kagent-TLFRLC38702197701560
            kagent-TLFRLC81288907470344
            lm_sensors
            lpd
            lvm2-monitor
            mdmonitor
            mdmpd
            messagebus
            microcode_ctl
            multipathd
            network, ntpd
            readahead_early
            readahead_later
            restorecond
            rhnsd
            rsyslog
            rti
            sendmail
            smartd
            smb
            sshd
            syslog, 
            sysstat
            tfremote
            yum
            yum-updatesd
            zeedaisy
            PBEAgent

    The list of allowed system services for RHEL7 is as follows:

            abrt-ccpp.service
            abrt-oops.service
            abrt-vmcore.service,
            abrt-xorg.service
            abrtd.service
            apcupsd.service
            atd.service
            auditd.service,
            crond.service
            cups.service,
            dbus-org.freedesktop.network1.service
            dbus-org.freedesktop.NetworkManager.service,
            dbus-org.freedesktop.nm-dispatcher.service,
            dmraid-activation.service,
            getty@.service,
            getty@tty1.service, getty@tty2.service, getty@tty3.service
            getty@tty4.service, getty@tty5.service, getty@tty6.service
            getty@tty7.service, getty@tty8.service, getty@tty9.service,
            getty@tty11.service
            httpd.service,
            iptables.service,
            irqbalance.service,
            kdump.service,
            libstoragemgmt.service,
            lvm2-monitor.service,
            mdmonitor.service,
            microcode.service,
            ntpd.service,
            rhsmcertd.service,
            rngd.service,
            rsyslog.service,
            sendmail.service
            sm-client.service
            smartd.service
            smb.service       
            sshd.service
            sysstat.service
            systemd-readahead-collect.service
            systemd-readahead-drop.service
            systemd-readahead-replay.service 
            tfremote.service
            tuned.service

    The "--whitelist-enforce" command line option can be used to modify the
    behavior of the "--services" option for RHEL7 systems. Currently, on
    RHEL7 systems, the default behavour is to not enforce the system
    services "whitelist" since the final list of allowed system services has
    not yet been decided. By specifying "--whitelist-enforce", the system
    services "whitelist" will be enforced as is done on RHEL5 and RHEL6.
    Note, enabling enforcement of the system services "whitelist" is also
    available as a config file statement. To enable enforcement, add the
    following line to the config file:

        whitelist-enforce=1

    The "--bastille" command line option no longer performas any changes, it
    is just present for backward compatability.

    The "--logging|--logrotate" command line option modifies the log file
    rotation schedule so that log files are rotated on a monthly basis and
    only deleted after one year.

    The log rotate conf files that are modified:

    "/etc/logrotate.conf"
    "/etc/logrotate.d/syslog"
    "/etc/logrotate.d/httpd"
    "/etc/logrotate.d/samba"

    The "--ssh" command line option modifies the existing "sshd" config file
    by making the following changes: the "ListenAddress" is set to
    "0.0.0.0", logins with the root account are disallowed over ssh, TCP
    forwarding is enabled, X11 forwarding is disabled, and password
    authentication is enabled.

    The "--time" command line option adds "clock.redhat.com" and
    "time.nist.gov" to the "/etc/ntp/step-tickers" NTP config file and on
    RHEL5 and RHEL6, restarts the "ntpd" system service.

    The "--ids" command line option no longer performas any changes, it is
    just present for backward compatability.

FILES
    /usr2/ostools/config/harden_linux.conf
    /d/ostools/config/harden_linux.conf
    /etc/sysconfig/iptables
    /etc/sysconfig/network
    /etc/modprobe.d/tf-disable-ipv6.conf
    /etc/hosts.deny
    /etc/hosts.allow
    /etc/securetty
    /etc/security/limits.conf
    /etc/pamd.d/system-auth-teleflora
    /etc/pam.d/su
    /etc/sudoers
    /etc/logrotate.d/sudo
    /etc/logrotate.d/syslog
    /etc/ssh/sshd_config
    /etc/ntp/step-tickers

DIAGNOSTICS
    Exit status: 0
        Successful completion or when the "--version" and "--help" command
        line options are specified. Internal symbol: $EXIT_OK.

    Exit status: 1
        In general, there was an issue with the syntax of the command line.
        Internal symbol: $EXIT_COMMAND_LINE.

    Exit status: 2
        For all command line options other than "--version" and "--help",
        the user must be root or running under "sudo". Internal symbol:
        $EXIT_MUST_BE_ROOT.

    Exit status: 9
        An error occurred converting the "sudoers" append directives in the
        config file from "here documents" and single files to a directory of
        "sudoers" config files. Internal symbol: $EXIT_CONVERT_CONFIG.

    Exit status: 11
        An error occurred reverting to the previous iptables config.
        Internal symbol: $EXIT_REVERT_IPTABLES.

    Exit status: 12
        An error occurred reverting to the previous sudo config. Internal
        symbol: $EXIT_REVERT_SUDO.

    Exit status: 15
        The script could not get the version number of the installed
        OSTools. Internal symbol: $EXIT_OSTOOLS_VERSION.

    Exit status: 20
        An error occurred configuring iptables. Internal symbol:
        $EXIT_IPTABLES.

    Exit status: 21
        An error occurred disabling IPv6. Internal symbol: $EXIT_IPV6.

    Exit status: 22
        An error occurred generating a new /etc/hosts.allow file. Internal
        symbol: $EXIT_HOSTS_ALLOW.

    Exit status: 23
        An error occurred configuring PAM rules. Internal symbol: $EXIT_PAM.

    Exit status: 24
        An error occurred generating a new /etc/sudoers file. Internal
        symbol: $EXIT_SUDO.

    Exit status: 25
        An error occurred configuring allowed system services. Internal
        symbol: $EXIT_SERVICES.

    Exit status: 26
        An error occurred removing the SETUID bit from certain programs or
        removing the "rsh" programs. Internal symbol: $EXIT_BASTILLE.

    Exit status: 27
        An error occurred configuring the log file rotation schedule.
        Internal symbol: $EXIT_LOGGING.

    Exit status: 28
        An error occurred modifying the sshd config file. Internal symbol:
        $EXIT_SSH.

    Exit status: 29
        An error occurred generating the NTP server config file. Internal
        symbol: $EXIT_TIME.

    Exit status: 30
        An error occurred updating the Aide intrusion detection system
        database. Internal symbol: $EXIT_IDS.

BUGS
    The iptables configuration currently only supports the 192.168.0.0/24,
    10.0.0.0/8, and 172.16.0.0/12 networks.

SEE ALSO
    /var/log/messages, /var/log/secure

NAME
    tfrsync.pl - synchronize production server files to a backup
    destination.

VERSION
    This documenation refers to version: $Revision: 1.227 $

SYNOPSIS
    tfrsync.pl --help

    tfrsync.pl --version

    tfrsync.pl --install-primary (--server | --cloud) [--rsync-account=name]
    [--network-device=s]

    tfrsync.pl --uninstall-primary [--rsync-account=name]

    tfrsync.pl --info-primary [--rsync-account=name]

    tfrsync.pl --install-secondary [--primary-server=addr]
    [--rsync-account=name]

    tfrsync.pl --uninstall-secondary [--rsync-account=name]

    tfrsync.pl --info-secondary [--rsync-account=name]

    tfrsync.pl --install-cloud [--cloud-server=addr] [---rsync-account=name]

    tfrsync.pl --uninstall-cloud [--cloud-server=addr]
    [---rsync-account=name]

    tfrsync.pl --generate-permfiles

    tfrsync.pl --upload-permfiles [--cloud-server=addr]
    [--rsync-account=name]

    tfrsync.pl --download-permfiles [--cloud-server=addr]
    [--rsync-account=name]

    tfrsync.pl --restore-from-permfiles [--cloud-server=addr]
    [--rsync-account=name]

    tfrsync.pl --backup=type [--luks] [--luks-key=s]

    tfrsync.pl --backup=type --cloud [--cloud-server=addr]
    [--rsync-account=name]

    tfrsync.pl --backup=type --server [--rsync-server=addr]
    [--rsync-account=name]

    tfrsync.pl --restore=type --cloud [--cloud-server=addr]
    [--rsync-account=name]

    tfrsync.pl --restore=type --server [--rsync-server=addr]
    [--rsync-account=name]

    tfrsync.pl --list=type

    tfrsync.pl --mount [--device=s]

    tfrsync.pl --unmount [--device=s]

    tfrsync.pl --luks-install [--luks] [--device=s]

    tfrsync.pl --luks-init [--luks] [--device=s]

    tfrsync.pl --luks-is-luks [--luks] [--device=s]

    tfrsync.pl --luks-verify [--luks] [--device=s]

    tfrsync.pl --luks-mount [--luks] [--device=s]

    tfrsync.pl --luks-umount [--luks] [--device=s]

    tfrsync.pl --luks-uuid [--luks] [--device=s]

    tfrsync.pl --luks-label [--luks] [--device=s]

    tfrsync.pl --luks-status [--luks] [--device=s]

    tfrsync.pl --luks-getinfo [--luks] [--device=s]

    tfrsync.pl --luks-showkey [--luks] [--device=s]

    tfrsync.pl --luks-validate-key [--luks-key=s] [--luks] [--device=s]

    tfrsync.pl --luks-backup-date [--luks] [--device=s]

    tfrsync.pl --luks-file-verify=s [--luks] [--luks-dir=s] [--device=s]

    tfrsync.pl --luks-file-restore=s [--luks] [--luks-dir=s] [--rootdir=s]
    [--device=s]

    tfrsync.pl --report-configfile

    tfrsync.pl --report-logfile

    tfrsync.pl --report-device

    tfrsync.pl --report-backup-method

    tfrsync.pl --gen-default-configfile

    tfrsync.pl --finddev

    tfrsync.pl --showkey

    tfrsync.pl --validate-cryptkey

    tfrsync.pl --format [--force-format]

    tfrsync.pl --runtime-cleanup ( --cloud | --server )

    tfrsync.pl --send-test-email

OPTIONS
    There are two types of options. The first is essentially a command since
    without this type of option, the script will do nothing. The second type
    is a modifier to a command option; it tailors the behavior of the
    command.

  Commands
    --version
        Output the version number of the script and exit.

    --help
        Output a usage help message and exit.

    --install|install-primary
        Install the *tfrsync.pl* script on the production server and perform
        other steps to prep the production server.

    --uninstall-primary
        Undo what was done to install *tfrsync.pl* on the production server.

    --info-primary
        Report configuration of production server.

    --install-secondary
        Prepare the secondary server.

    --uninstall-secondary
        Undo what was done to install *tfrsync.pl* on the secondary server.

    --info-secondary
        Report configuration of backup server.

    --generate-permfiles
        Generate perm files for all backup types. For all the files that
        make up a backup type, the getfacl(1) command is used to capture the
        file perms of the files that make up the backup type. It writes the
        captured info into a perm file corresponding to the backup type. If
        an error occurs while iterating through the list of files for any
        backup type, the error is logged but the generation will continue.
        Thus, if there are any errors reported, the contents of the perm
        file may not be complete. An example of an error that may occur is
        one caused when there are stale symlinks in the set of files of a
        backup type.

    --backup=type
        Perform a backup of the specified *type*. The *type* may be one or
        more of the following:

                all
                usr2
                daisy
                printconfigs
                rticonfigs
                daisyconfigs
                osconfigs
                netconfigs
                userconfigs
                userfiles
                logfiles
                posusersinfo
                pserverinfo
                pservercloister
                bbxd
                bbxps
                singlefile

        Modifiers: --device=s, --usb-device, --backup-exclude=list,
        --rsync-server=addr, --rsync-dir=path, --retry-backup,
        --retry-reps=number, --retry-wait=seconds, --singlefile=path, and
        --send-summary

    --restore=type
        Restore files of specified "type" from a backup. The *type* may be
        one or more of the following:

                all
                usr2
                daisy
                printconfigs
                rticonfigs
                daisyconfigs
                osconfigs
                netconfigs
                userconfigs
                userfiles
                logfiles
                bbxd
                bbxps
                singlefile

        Modifiers: --device=s, --usb-device, --restore-exclude=list,
        --rootdir=s, --[no]harden-linux, --singlefile=path and --dry-run

    --list=type
        List the files on a backup server or device for the specified backup
        type (see --backup=type option. If no backup type is specfied, the
        default is *all*. This option may not be used with the --cloud
        option.

        Modifiers: --device=s, --usb-device, --rsync-server=addr,
        --rsync-dir=path

    --finddev | --report-device
        Search for a USB or Passport backup disk device.

    --report-backup-method
        Report what type of backup is installed, ie, "cloud", "server", or
        "LUKS".

    --showkey
        Output the string being used as the LUKS key.

    --format
        Format a backup device.

    --getinfo
        Get and report info about the backups on a backup device.

    --mount
        Mount a backup device.

    --unmount|--umount
        Unmount a backup device.

    --runtime-cleanup
        If the script crashed rather than ending with a clean exit, there
        possibly will be a process lock file and/or a SSH tunnel socket left
        behind. This command can be used to cleanup those dangling files.
        For cloud, server, or device backup operations, the process lock
        file will be removed. For server or cloud, the SSH tunnel socket
        will be removed.

    --send-test-email
        Send an email message via the email configuration to test whether an
        email message would make it through to any configured recepients.

    --report-configfile
        Parse the config file, and report it's contents.

    --report-backup-method
        Information about how the decision of what backup method was
        installed will be in the device log file.

    --gen-default-configfile
        Generate a new default config file and put it into the OSTools
        config directory. If there is already an existing config file, do
        not overwrite the old config file - rather, add the extension .new
        before installation.

    --luks-install
        Like --production-install, sets up a production server to be ready
        to perform backups to a LUKS device. Modifiers allowed: [--luks],
        [--device=s].

    --luks-init
        Writes the LUKS header to the backup disk and puts an ext2 file
        system on the LUKS device.

    --luks-is-luks
        Verify the current backup disk is a LUKS device. This command uses
        the "cryptsetup isLuks" command.

    --luks-verify
        Verify the current backup disk is a LUKS device. This command uses
        the "cryptsetup luksDump" command.

    --luks-mount
        Mount a LUKS disk device.

    --luks-umount
        Unmount (aka eject) a LUKS device.

    --luks-uuid
        Output the UUID of the LUKS device.

    --luks-label
        Output the disk label of a LUKS device.

    --luks-status
        Output low level system inforation about the LUKS device.

    --luks-getinfo
        For the currently selected backup disk, output the backup type, the
        block device name of the LUKS device, the LUKS device name, the
        mount point for file system on the LUKS device, and the free space
        on the LUKS device.

    --luks-showkey
        Output the encryption key for the LUKS disk device.

    --luks-validate-key
        Validate the default or specified LUKS disk device encryption key by
        trying to mount the LUKS disk device.

  Command Modifiers
    --luks
        This option specifies a backup type of "LUKS disk device". While it
        may be ommitted since the script can deduce what should be done from
        other options, specifying this option makes explicit what is desired
        and makes communication clearer.

    --luks-key=s
        Specify the LUKS key. If this option is not specified the hardware
        serial number is used. Note, if the LUKS device is moved to another
        system, the LUKS key must be noted and used in order to access the
        files on the LUKS device.

    --luks-dir=s
        This command line option allows the user to specify which "bucket"
        on the LUKS disk device is to be used for listing, searching, and
        restoring.

    --server
        Specify this option when performing a backup from a production
        server to a backup server. Sets the default values of
        --rsync-server=s and --rsync-account=s if not set.

    --cloud
        Specify this option when performing a backup from a production
        server to a cloud server. Sets the default values of
        --cloud-server=s and --rsync-account=s.

    --cloud-server=addr
        Specify the FQDN or IP address of the cloud server.

    --primary-server=addr
        Sets the hostname or IP address of the production server. May only
        be used with --install-secondary.

    --rsync-server=addr
        Specify the hostname or IP address of the rsync backup server.

    --rsync-dir=path
        Specify the directory to write files to on the rsync server if
        --rsync-server is specified or to a local file system if
        --rsync-server is not specified.

    --rsync-account=s
        Sets the name of the account on the rsync server. May be used with
        --install-primary, --uninstall-primary, --info-primary,
        --install-secondary, --uninstall-secondary, --info-secondary,
        --install-cloud, --uninstall-cloud, --upload-permfiles,
        --download-permfiles, --restore-from-permfiles, --backup=type, and
        --restore=type.

    --force-rsync-account-name
        If the --cloud option is specified, the default account name used is
        of the form "name-nnnnnnnn" where "name" is "tfrsync" and "nnnnnnnn"
        is the shopcode of the system. If a cloud account name is specified
        on the command line that does not contain the shopcode matching the
        system, then the account name is not allowed unless
        --force-rsync-account-name is also specified on the command line.

    --rsync-trial
        Run the *rsync* command in trial mode (accomplished by adding the -n
        option to the *rsync* command that gets generated). This provides a
        method to determine what files will be synchronized without actually
        synchronizing them.

    --rsync-options=s
        Specify a list of one or more comma separated *rsync* options to be
        added to the *rsync* command line.

    --rsync-timeout=s
        All *rsync* commands generated have the --timeout=s option with a
        default value of 600 seconds. Specify this option to change that
        value. A value of zero means no timeout.

    --[no]rsync-nice
        Run the "rsync" command with "nice"; this is the default behavior.
        Specify *--norsync-nice* on the command line to run the "rsync"
        command without "nice".

    --[no]rsync-metadata
        The default behavior when doing a backup to the "cloud" is to
        generated metadata files for each of the backup types. To keep from
        generating metadata files, specify the "--norsync-metatdata" option
        on the command line.

    --rsync-compression
        By default, there is no compression of files during the transfer by
        rsync, ie the -z option is not present on the rsync command. If the
        --rsync-compression option is specified with the --backup=type
        option, then the -z option will be added to the rsync command
        issued. Note that adding this option can increase the time required
        to perform a backup when backing up very large files.

    --retry-backup
        If present, enables the backup retry policy. Note that retries are
        only applicable for instances when rsync(1) returns a value of 12
        (rsync protocol), 30 (I/O error) or 255 (SSH connection error).

    --retry-reps=number
        If present, sets the number of retries to "number". This option is
        ignored unless --retry-backup is also specified. The value specified
        must be >= 0 and <= 10. If --retry-backup is specified and
        --retry-reps=number is not specified or if --retry-reps=0 is
        specified, then the default value of 3 retries is used.

    --retry-wait=number
        If present, sets the retry wait time to "number" seconds. This
        option is ignored unless --retry-backup is also specified. The value
        specified must be >= 0 and <= 3600. If --retry-backup is specified
        and --retry-wait=number is not specified or if --retry-wait=0 is
        specified, then the default value of 120 seconds is used.

    --force-format
        Unless specified with the --format option, the user is asked a
        "yes/no" question on STDIN to verify that a format of the file
        system is really desired. If <--force-format> is specified, it's
        equivalent to "yes" being answered.

    --singlefile=path
        Provides the method to specify one or more files to backup or
        restore. The files are specified by a list of one or more comma
        separated paths. This option may only be used in conjunction with
        the --backup=type or --restore=type commands.

    --restore-upgrade
        An option that may only be used when both --cloud and --restore=type
        are specified, ie that a restore is being done from a cloud server
        to a staged production server. The set of backup files being
        restored may or may not be from the same platform as the staged
        server, ie the backup files may be from a RHEL5 system and the
        staged server may be a RHEL6 system.

    --network-device=s
        This option allows the specification of a network interface device
        name, eg "eth0" or "eth1", and is only used to produce the contents
        of the production server info file when performing a backup. The
        default value is "eth0" so if you are using that interface for your
        network tap, there is no need to specify this option.

    --send-summary
        A summary report is sent to a list of one or more email addresses if
        email is configured.

    --rti
        Specify that the system is a RTI system.

    --daisy
        Specify that the system is a Daisy system.

    --email=recipients
        Specifies a list of email addresses.

    --printer=names
        Specifies a comma separated list of printer names. If printers are
        configured, the backup summary report will be output to all named
        printers. Also, if the backup class is "device" and there is no
        backup device discovered, and printers are configured, an error
        message will be output to all named printers.

    --rootdir=path
        Specifies the destination directory for restore.

    --configfile=path
        Specifies the path to the config file.

    --logfile=path
        Specifies the path to the logfile.

    --summary-log-max-save=n
        Specifies the maximum number of saved summary log files.

    --summary-log-min-save=n
        Specifies the minimum number of saved summary log files.

    --summary-log-rotate
        Enable summary log file rotation (by default, disabled).

    --backup-exclude=list
        Specifies a list of one or more comma separated files and/or
        directories to exclude from a backup.

    --restore-exclude=list
        Specifies a list of one ore more comma separated files and/or
        directories to exclude from a restore.

    --device=path
        Specifies the path to the device special file for the backup device.
        It can also have the special value of *show-only* whose meaning is
        described under the --show-only option description.

        Each backup device is classified as to type. There are several
        different device types supported:

         1. "passport"    - a Western Digital Passport USB disk
         2. "rev"         - an IOmega Rev drive
         3. "usb"         - a USB disk with Teleflora label
         4. "image"       - an image file
         5. "server"      - ip address of backup server
         6. "file system" - locally mounted file system
         7. "block"       - either "passport", "rev", or "usb"
         8. "show-only"   - special device, same thing as "--show-only"

    --usb-device
        Use a disk plugged into the USB bus which has been formatted with
        --format as the backup device.

    --dry-run
        Report what an operation would do but don't actually do it.

    --show-only
        Change the behavior of --backup to only show the filenames of the
        backup type not actually back up any files. Another way to think
        about this option is that it is an alias for --device=show-only, ie
        you are specifying a special device named *show-only* which does not
        backup any data but rather reports the filenames to be backed up.

    --verbose
        Report extra information.

    --[no]harden-linux
        Run (or don't run) the *harden_linux.pl* script. The
        --harden-linux|--noharden-linux command line option provides a way
        to specify whether or not the *harden_linux.pl* script should be run
        by the *tfrsync.pl* script. The default behavior for *tfrsync.pl* is
        to run *harden_linux.pl* after performing any of the following
        restore types: "all", "rticonfigs", "daisy", "daisyconfigs",
        "osconfigs" and "netconfigs". The *harden_linux.pl* script will only
        be run once after all restores are finished. To prevent
        *harden_linux.pl* from running, specify the following option:
        --noharden-linux.

DESCRIPTION
    The *tfrsync.pl* script may be used to synchronize data from a Teleflora
    RTI or Daisy Point of Sale server, referred to below as the "production
    server", to a cloud server, a backup server, a backup device, or a local
    file system. It is essentially a front end to the *rsync(1)* command
    which does the real work of reading and writing the data. For maximum
    versatility, there are many options and many ways that the script can be
    used.

    Since the backup strategy is one based on *rsync(1)*, implied is that
    the first backup performed copies all files of interest from the
    production server to the backup destination and could take a significant
    amount of time depending on the characteristics of the destination. For
    example, if there is a 25 GB of data to backup, if the distination is a
    cloud server, and if the upload bandwidth to the cloud server is
    typical, it should take 10 hours or less. Subsequent backups are
    incremental and only the files that have changed are copied to the
    backup destination. This results in a significant savings in time, with
    a typical installation taking 30 minutes and usually less.

  Installation
    Before *tfrsync.pl* can be used on either the production server or the
    backup server, it must be installed. The *tfrsync.pl* script itself will
    have been installed when the OSTools package was installed. However, the
    *tfrsync.pl* must install a framework of directories and files in order
    to accomplish it's job. This installation must be performed on both the
    production server and the backup server separately. The sections which
    follow outline what is done during production and backup server
    installations.

  Installation on the Production Server
    The --install-primary command line option performs all the steps
    necessary to install the *tfrsync.pl* script onto a RTI production
    server, aka a production server.

    The OSTools installation process will already have copied the
    *tfrsync.pl* script to the OSTools bin directory and made a symlink from
    the RTI bin directory to it which makes it available from the command
    line for the *tfsupport* account.

    The steps performed during the installation of the production server are
    outlined below:

    1.  make the *tfrsync.pl* backup directory if it does not exist. For a
        RTI system, this is /usr2/tfrsync, and for a Daisy system, this is
        /d/tfrsync.

    2.  make the production server transfer directory if it does not exist.
        This directory is located in the home directory of the *tfsupport*
        account and is named pserver_xfer.d. The transfer directory is used
        to hold files that are to be copied from the production server to
        the backup server.

    3.  make the production server info directory if it does not exist. This
        directory is located in the *tfrsync.pl* backup directory and is
        named pserver_info.d. The production server info directory is the
        location of the production server info file which is named
        pserver_info.txt. The production server info file is generated each
        time a backup transaction occurs.

    4.  make the production server cloister directory if it does not exist.
        This directory is located in the *tfrsync.pl* backup directory and
        is named pserver_cloister.d. The cloister directory is used to hold
        backup copies of certain files that need to be backed up but need to
        be segregated into a special location rather than be copied "in
        place" like the bulk of the files to be backed up. Examples of such
        files are /var/spool/cron and /etc/cron.d. These files need
        segregation because if they are copied "in place" to the backup
        server, they would cause behavior on the backup server that would
        not be wanted, ie they would cause cron jobs to run.

    5.  make the users info directory if it does not exist. This directory
        is located in the *tfrsync.pl* backup directory and is named
        users_info.d. The users info directory is used to hold files
        containing info about the POS users on the production server. These
        files are copied to the backup server and are required for
        transforming a backup server into a production server.

    6.  if the *tfrsync.pl* account does not exist, add the *tfrsync.pl*
        account.

    7.  generate a password-less SSH key-pair for the *tfrsyc* account and
        copy the public SSH key file that was just generated to the
        production server transfer directory. The name of the public key
        file is id_rsa.pub.

    8.  add a new cron job file named tfrsync to the directory /etc/cron.d.
        If there is an existing cron job file there, then the cron job file
        is placed in the OSTools config directory instead.

    9.  generate a new config file and put it into the OSTools config
        directory. If there is already an existing config file for
        *tfrsync.pl*, then do not overwrite the old config file - rather,
        put the new config file into the OSTools config dir with the
        extension .new.

  Installation on the Backup Server
    In addition to installation of *tfrsync.pl* on the RTI production
    server, there are several installation steps that must also be performed
    on the backup server, aka secondary server. To install *tfrsync.pl* on
    the backup server, first install the OSTools package on the secondary
    server. Then, run the *tfrsync.pl* script on the backup server
    specifying the --install-secondary command line option. The
    --primary-server=s may also be specified with the --install-secondary
    option; it is used to specify the hostname or IP address of the
    production server. If the --primary-server=s option is not specifed,
    then the default value for the IP address of the production server is
    used. The default value is 192.168.1.21. The following steps are
    performed:

    1.  an account named *tfrsync* is added if it does not exist

    2.  the account name *tfrsync* is added to the /etc/sudoers file to
        allow the *tfrsync* account to run the "rsync" command as root
        without being prompted for a password. This is accomplished by
        adding the account name *tfrsync* to the OSTools harden_linux.pl
        config file and then running the "harden_linux.pl --sudo" command.

    3.  the public key of the *tfrsync* account on the production server is
        added to the .ssh/authorized_keys file of the *tfrsync* account on
        the backup server

    4.  service httpd stop and chkconfig httpd off

    5.  service rti stop and chkconfig rti off

    6.  move /usr2/bbx/bin/doveserver.pl to /usr2/bbx/bin/doveserver.pl.save

    7.  service blm stop and chkconfig blm off

    8.  service bbj stop and chkconfig bbj off

  Uninstall on the Backup Server
    The --uninstall-secondary command line option undoes what was done to
    install the *tfrsync.pl* script on the secondary server.

    1.  the account named *tfrsync* is removed from the "/etc/sudoers" file
        by removing the "harden_linux.pl" sudoers content file from the
        "harden_linux.pl" sudoers config directory,
        "/d/ostools/config/sudoers.d" on Daisy systems and
        "/usr2/ostools/config/suders.d" on RTI systems, and then running the
        "harden_linux.pl --sudo" command.

    2.  the public key of the *tfrsync* account on the production server is
        removed from the "~tfrsync/.ssh/authorized_keys" file on the backup
        server.

    3.  the account named *tfrsync* is removed from the backup server.

  Backup Retries
    When doing a backup to a cloud server, if the Internet connection is
    inconsistent and unreliable, the rsync command can fail with a protocol
    error, or an i/o error, or an ssh connection error. For systems
    experiencing these conditions, the command line options --retry-backup,
    --retry-reps=n and --retry-wait=secs can be very useful. When
    --retry-backup is specified, if there is an rsync error as described
    above, the entire backup operation is retried one or more times with a
    wait between each retry. The default number of times to retry is 3. The
    default time to wait between retries is 2 minutes (120 seconds). The
    --retry-reps=n and --retry-wait=secs allows you to tune the retry and
    wait values to best suite your situation. These options are also
    supported in the config file so they can be specified on the command
    line as well as the config file.

  Sending Email
    The *tfrsync.pl* script can be configured to send email depending on one
    of several conditions. First, described below is when an email message
    is sent, and second, how an email message is sent.

    Could not start new instance
        If there are email recipients specified on the command line or in
        the config file, and the *tfrsync.pl* script can not execute because
        an instance of the *tfrsync.pl* script is aleady running as
        indicated by not being able to obtain the process lock, an error
        message will be sent to each of the recipients.

    Backup device not found
        If there are email recipients specified on the command line or in
        the config file, and a backup device is not found, an error message
        will be sent to each of the recipients.

    Backup error
        If there are email recipients specified on the command line or in
        the config file, and an error occurred during a backup operation,
        then a status message will be sent to each of the recipients.

    Backup summary report
        If there are email recipients specified on the command line or in
        the config file, and the "--send-summary" command line option is
        specified or the "send-summary" statement is set to true in the
        config file, then a summary report will be sent to each of the
        recipients.

    Given that one or more email recipients are specified, and one of the
    conditions upon which the script will attempt to send an email message
    occurs, then the message can be sent one of the following methods. Note,
    if there is no email server configured in the config file, then no mail
    message will be sent even if there are recipients specified.

    Sendmail
        If the "email_server" config file statement is specified with a
        value of "sendmail", then any email messages sent by the script will
        directly invoke the "/usr/lib/sendmail -oi -t" program with a from
        address of "tfrsync.pl@HOSTNAME.teleflora.com" where HOSTNAME will
        be substituted with the hostname of the system.

    SMTP Server
        If the "email_server" config file statement is specified with a
        value of the FQDN of an SMTP server, and the "email_user" and
        "email_password" config file statements have valid credentials for
        the specified SMTP server, then any email messages sent by the
        script will use the Perl module "Net::SMTP" with a from address of
        "backups@HOSTNAME" where HOSTNAME will be substituted with the
        hostname of the system.

  Rsync of Summary Log File
    After a backup operation is complete, ie after all changed files have
    been written to the backup device or to the backup server or to the
    cloud server, a summary log file is written locally to the POS log
    directory. Thus, this summary log file will not be transferred to the
    backup device until the next time a backup operation is performed. In
    order to backup the summary log file and to have convenient access to
    this file for monitoring and reporting, a resync of the summary log file
    is performed after the backup operation is complete and the summary log
    file has been written.

  Config File
    The *tfrsync.pl* script supports one or more config files. The default
    config file name and location is specified in the FILES section below.
    There are many configuration attributes that can be set in the config
    file. Refer to the comments in the generated default config file for a
    list of attributes, their meaning, and their values.

  Backup to a LUKS Device
    In addition to "cloud" and "server" backup, the *tfrsync.pl* script
    supports backing up files to a LUKS device, ie a locally connected disk
    drive that has been specially initialized according to the LUKS
    specification. A LUKS device is one that complies with the "Linux
    Unified Key Setup" disk encryption specification. For more info, see the
    Wikipedia entry: <https://en.wikipedia.org/wiki/Linux_Unified_Key_Setup>
    Essentially, the backups are written to an encrypted file system which
    resides on a locally connected block device that has been configured to
    be a LUKS device. Files written to or read from the LUKS device are
    encrypted or decrypted by the Linux kernel automatically.

    To configure a local disk drive as a LUKS device, two steps are
    required. First, install the *tfrsync.pl* script using the
    --luks-install command line option, and then initialize the backup disk
    as a LUKS device with the --luks-init command line option. Then the
    backup disk is ready to be used as a LUKS device. After script
    installation and backup disk initialization, the LUKS device can be used
    as a backup disk, using the --backup= command line option to specify the
    set of files to write to the disk. See the EXAMPLES section below for
    specific command lines.

    By default, the backup disk is expected to be a Western Digital
    Passport. When the script starts, it will automatically look for a
    Passport as the backup disk. Upon finding a Passport, it will determine
    it's block device name but a specific block device name can be specified
    via the --device= option. In order to automatically find the Passport,
    it must be connected to the system and the block device name for it must
    be one of "/dev/sda" through "/dev/sdg".

    The *tfrsync.pl* script maintains 4 separate trees of files on the LUKS
    device being used as the backup disk. The head of each tree is a
    directory at the top of the file system on the LUKS device. These
    directories are named "today, "yesterday", "weekly" and "monthly". When
    the script runs, if the current day of the month matches the day of the
    month of the "mtime" field of the "today" directory, then the backup
    operation is performed against that tree. If the current day of the
    month does not match, then the "yesterday" tree is renamed to "today",
    and the "today" tree is renamed to "yesterday", and then the backup
    operation is performed against the new "today" tree. After the backup
    operation is complete, if the current day of the week is Sunday, then
    the "weekly" tree is updated. Similarly, if the current day of the month
    is the first day of the month, then the "monthly" tree is updated.

    Thus, with this strategy, the 4 trees on the LUKS device will have a
    backup that is the current backup less than one day old, a backup that
    is 1 day old, a backup this is 1 week old, and finally a backup that is
    1 month old.

    The LUKS device encrption scheme uses the AES block cypher, with a
    256-bit key, and if you don't specify a LUKS key when initializing the
    LUKS device, the DELL service tag will be used. The LUKS initialization
    step writes the LUKS header on the disk; the header is where the key is
    stored. The LUKS "key" is really a passphrase used for encrypting a
    master key which is automatically generated by the system. Thus, the
    LUKS key is not the key used to encrypt the data but merely allows
    access to the use of the master key.

  Production Server Info File
    The production server info file, aka pserver info file, contains key
    information about the production server. It is generated each time a
    backup is performed and is copied to the backup server, or cloud server,
    or device each time there is a backup.

    The name of the pserver info file is pserver_info.txt and is located in
    the /usr2/tfrsync/pserver_info.d directory on an RTI system and in the
    /d/tfrsync/pserver_info.d directory on a Daisy system. The file is a
    simple ASCII text file, with each line consisting of an attribute/value
    pair, separated by an EQUALS SIGN.

    The pserver info file contains the following attributes;

    platform
        The value is the name of the platform, either "RHEL5", or "RHEL6",
        or "RHEL7".

    hostname
        The value is the hostname of the production server.

    ipaddr
        The IP address of the production server

    netmask
        The netmask of the production server

    gateway
        The IP address of the "gateway", ie the router.

    As a concrete example, if the production server was a Daisy "RHEL5"
    system, the pserver info file would look similar to the following, with
    values adjusted as appropriate:

     platform=RHEL5
     hostname=77777700-tsrvr
     ipaddr=192.168.1.21
     netmask=255.255.255.0
     gateway=192.168.1.1

  Backup Summary Log File
    The backup summary log file contains an entry for each execution of the
    *tfrsync.pl* script. Each entry is about 750 bytes long and is a short
    summary of the backup result. This file grows without bound, but due to
    the relatively small entry size and frequency of execution, it should
    not be a factor in disk space usage. The backup summary log file can be
    rotated each year if desired. This rotation is disabled by default, but
    can be enabled via the "--summary-log-rotate" command line option or the
    "summary-log-rotate=true" statement in the config file. If summary log
    file rotation is enabled, then upon each execution of *tfrsync.pl*, the
    script determines the date of the earliest entry in the summary log file
    - if the date is more than 1 year earlier than the current date, then
    the current file is renamed with a name that includes the date of the
    earliest entry. Then a new summary log file will be established and used
    for another year. By default, a minimum of 3 copies of the summary log
    file is kept, and a maximum of 10; these values are configurable on the
    command line or through the config file.

    Each entry in the summary log file consists of a record of 17 lines, one
    line per field, in the format oulined below. If the value of an entry is
    not applicable to the type of backup being performed, the value of the
    field will be the string "NA".

    separator line
        A line of 80 "=" chars.

    script name
        The file name of the script, *tfrsync.pl*.

    script version
        The CVS revision number of the script.

    command line
        The command line used to invoke the script.

    execution start time
        The execution start time in the format of "YMD-HMS", which for
        example, Jan 27, 2014 at 10:40 and 24 seconds would be
        "20150127-104024".

    execution stop time
        The execution stop time in the format of "YMD-HMS", which for
        example, Jan 27, 2014 at 10:40 and 24 seconds would be
        "20150127-104024".

    execution duration
        The length of time for the execution in the format of "H:M:S", which
        for example, a duration of 0 hours, 10 minutes, and 27 seconds would
        be "00:10:27".

    device type
        The backup device type, would will usually be "cloud", "server",
        "passport", or "usb".

    result description
        The english equivaliant of the exit status.

    rsync exit status
        The exit status reported by the rsync command used to perform the
        backup.

    rsync backup retries
        The number of times that the rsync command was retried.

    rsync warnings
        A list of one or more rsync exit status values that are considered
        to be just warnings. If there are no warnings, then the value is
        just "0".

    bytes written
        The total number of bytes written by rsync.

    server IP addr
        The hostname or IP address of the cloud server or the backup server.

    path on server
        The value of the --rsync-dir option if it was specified. Not
        applicable for "cloud" backup.

    device file path
        The path of the device file for the backup device, which, for
        example, might be /dev/sdb1 for a Passport device. Not applicable
        for "cloud" backup.

    backup device capacity
        The total capacity of the backup device. Not applicable for "cloud"
        backup.

    backup device available space
        The available space left on the backup device. Not applicable for
        "cloud" backup.

    separator line
        A line of 80 "=" chars.

    Here is an example of the contents of a summary log file:

     ================================================================================
         PROGRAM: tfrsync.pl
         VERSION: $Revision: 1.227 $
         COMMAND: /home/tfsupport/tfrsync.pl --server --backup=osconfigs
           BEGIN: 20150210-133052
             END: 20150210-133103
        DURATION: 00:00:11
          DEVICE: server
          RESULT: Exit OK
           RSYNC: 0
         RETRIES: 0
        WARNINGS: 0
      BYTES SENT: 374.17KB
          SERVER: 192.168.2.31
            PATH: /tmp
     DEVICE FILE: NA
        CAPACITY: NA
       AVAILABLE: NA
     ================================================================================

EXAMPLES
    To install the *tfrsync.pl* script on a Teleflora POS system and
    configure it as the production server, enter the following:

     sudo tfrsync.pl --server --install-production-server

    To get info about the installation on the primary server, you can enter
    the following:

     sudo tfrsync.pl --info-production-server

    To install the *tfrsync.pl* script on a Teleflora POS system and
    configure it as the backup server, enter the following:

     sudo tfrsync.pl --install-secondary --production-server=192.168.1.21

    On an RTI system, to backup all files in all backup types to the backup
    server at IP addr 192.168.1.22, in the directory /usr2/tfrsync, enter
    the following:

     sudo tfrsync.pl --server --backup=all --rsync-server=192.168.1.22

    To display the filenames contained in the backup type "netconfigs",
    enter the following:

     sudo tfrsync.pl --server --backup=netconfigs --show-only

    To perform a backup operation to a cloud server with retries, with the
    number of retries 5 and the time of 3 minutes to wait between each
    retry, enter the following:

     sudo tfrsync.pl --cloud --backup=all --retry-backup --retry-reps=5 --retry-wait=180

    To backup a single file, say /etc/motd, from the production server to
    the backup server and put it in /tmp on the backup server, enter the
    following:

     sudo tfrsync.pl --server --singlefile=/etc/motd --backup=singlefile --rsync-dir=/tmp

    To restore the single file /tmp/etc/printcap from the backup server and
    put it in the /tmp directory on the production server, enter the
    following:

     sudo tfrsync.pl --server --singlefile=/etc/printcap --restore=singlefile \
        --rsync-dir=/tmp --rootdir=/tmp

    To use an external USB Western Digital Passport as a LUKS backup device,
    first install the *tfrsync.pl* script for use with a LUKS device, then
    initialize the Passport as a LUKS device, and then you can use it as a
    backup device. To install the *tfrsync.pl* script for use with a LUKS
    device, enter:

     sudo tfrsync.pl --luks-install

    To initialize the LUKS device, enter the following command - note, by
    not specifying the --device=s option, the script will look for a Western
    Digitial Passport connected to the system as block device "/dev/sda"
    through "/dev/sdg". Also not that if you don't specify the LUKS key, the
    DELL service tag will be used.

     sudo tfrsync.pl --luks --luks-key=fred --luks-init

    To use the Western Digital Passport as the LUKS backup device, enter the
    command:

     sudo tfrsync.pl --backup=all

    To get the date of the last backup to the LUKS device, enter the
    command:

     sudo tfrsync.pl --luks --luks-backup-date

    To get more information about the LUKS device, enter:

     sudo tfrsync.pl --luks --luks-getinfo

    To get low level system information about the LUKS device, enter:

     sudo tfrsync.pl --luks --luks-status

    To view files on the LUKS device, first mount the LUKS device, use
    ordinary shell commands to view or manipulate files on the LUKS device,
    and then make sure to umount the LUKS device:

     sudo tfrsync.pl --luks --luks-key=fred --luks-mount
     ls -l /mnt/backups
     cp -pr /mnt/backups/yesterday/etc /tmp
     sudo tfrsync.pl --luks --luks-key=fred --luks-umount

FILES
    /usr2/tfrsync
        The *tfrsync.pl* backup directory for a RTI system.

    /d/tfrsync
        The *tfrsync.pl* backup directory for a Daisy system.

    /home/tfrsync
        The home directory of the *tfrsync* account.

    /home/tfsupport
        The home directory of the Teleflora support account

    /home/tfsupport/pserver_xfer.d
        The production server transfer directory.

    pserver_cloister.d
        The production server cloister directory is located in the
        tfrsync.pl backup directory.

    pserver_info.d
        the production server info directory and is located in the
        tfrsync.pl backup directory.

    pserver_info.txt
        The production server info file - it contains information about the
        production server and is located in the production server info
        directory. The production server info file is generated each time a
        backup transaction occurs. Contents include the production server
        platform string (either "RHEL5", or "RHEL6", or "RHEL7"), the
        production server's hostname, IP address, and netmask, and the
        gateway IP address.

    users_info.d
        The users info directory is located in the tfrsync.pl backup
        directory.

    /usr2/tfrsync/users_info.d/rti_users_listing.txt
        The RTI users listing file.

    /usr2/tfrsync/users_info.d/rti_users_shadow.txt
        The shadow file entries for the users in the RTI users listing file.

    /d/tfrsync/users_info.d/daisy_users_listing.txt
        The Daisy users listing file.

    /d/tfrsync/users_info.d/daisy_users_shadow.txt
        The shadow file entries for the users in the Daisy users listing
        file.

    id_rsa.pub
        The name of the public SSH key file.

    /etc/cron.d/tfrsync
        the tfrsync.pl cron job file.

    tfrsync-server-Day_nn.log
        The name of the log file for destination class "server". The string
        *nn* is replaced by the zero filled, two digit day of the month.

    tfrsync-cloud-Day_nn.log
        The name of the log file for destination class "cloud". The string
        *nn* is replaced by the zero filled, two digit day of the month.

    tfrsync-device-Day_nn.log
        The name of the log file for destination class "device". The string
        *nn* is replaced by the zero filled, two digit day of the month.

    tfrsync-summary.log
        The summary log file contains an entry for each execution of the
        *tfrsync.pl* script with a short summary of the result.

    /usr2/bbx/log
        On an RTI system, the location of the log files. If this directory
        does not exist, the log files will be put in /tmp.

    /d/daisy/log
        On a Daisy system, the location of the log files. If this directory
        does not exist, the log files will be put in /tmp.

    /usr2/ostools/config
        The location of the default *tfrsync.pl* config file for an RTI
        system.

    /d/ostools/config
        The location of the default *tfrsync.pl* config file for a Daisy
        system.

    tfrsync.conf
        The name of the default *tfrsync.pl* config file.

    /usr2/ostools/config/tfrsync.d
        The location of optional custom config files for an RTI system.

    /d/ostools/config/tfrsync.d
        The location of optional custom config files for a Daisy system.

    /mnt/backups
        Mount point for backup devices.

    /etc/redhat-release
        Contents determines OS type.

    /sys/block/{sda,sdb,sdc,sde,sdd}/device/vendor
        This file contains the vendor string for the block device, ie disk,
        that has special device file "/dev/sda", or "/dev/sdb", etc.

    /sys/block/{sda,sdb,sdc,sde,sdd}/device/model
        This file contains the model string for the block device, ie disk,
        that has special device file "/dev/sda", or "/dev/sdb", etc.

    /usr2/tfrsync/$backuptype-perms.txt
        The metadata files generated on a RTI system when doing a backup to
        the cloud. See the output of tfrsync.pl --help for a list of backup
        type values that "$backuptype" may take.

    /d/tfrsync/$backuptype-perms.txt
        The metadata files generated on a Daisy sysstem when doing a backup
        to the cloud. See the output of tfrsync.pl --help for a list of
        backup type values that "$backuptype" may take.

    /var/lock/tfrsync-server.lock
    /var/lock/tfrsync-cloud.lock
    /var/lock/tfrsync-device.lock
        The process lock file. There is a separate process lock file for
        each of the device types. The process lock file path will be one of
        the paths above, for either the "server", "cloud", or "device",
        which corresponds to each of the device types. When the script
        starts, an attempt is made to acquire the lock file corresponding to
        the device type; if the lock file already exists when this check is
        made, then it indicates that an existing process has the lock for
        that device type and thus, a new process is not allowed to proceed.

    /var/run/tfrsync-server.socket
    /var/run/tfrsync-cloud.socket
        The SSH tunnel socket. There is a separate SSH tunnel socket for
        each of the destination classes. For the backup destination class
        "server", the name of the socket is tfrsync-server.socket. For the
        "cloud" destination class, the name is tfrsync-cloud.socket. When a
        backup or restore operation is performed, an attempt is made to
        establish an SSH tunnel on a socket at the appropriate path. If the
        socket already exists, it indicates that a previous process used the
        socket for a connection to the remote device and crashed without
        cleaning up the socket; the --runtime-cleanup command can be used to
        cleanup stale sockets. If the SSH command returns an exit status of
        255, the script makes 3 attempts to open the socket before returning
        an error.

    /tmp/tfrsync-rsyncstats-XXXXXXX
        A temp file to hold the stats generated during a successful rsync
        command. The stats are compiled immedately after a rsync command
        completes and then the temp file is deleted.

DIAGNOSTICS
    "Error: invalid command line option, exiting..."
        This message is output if an invalid command line option was
        entered.

    "--cloud and --server are mutually exclusive"
        Only one of the "--cloud" and "--server" command line options may
        appear on the command line at an execution of the script - either
        you are doing a "cloud" backup or a "server" backup. If your
        production server is configured to be backed up to both, then you
        must run "tfrsync.pl" twice, once for "cloud", and once for
        "server".

    "tfrsync.pl must be run as root or with sudo"
        You can run the "tfrsync.pl" script with the "--help" or "--version"
        command line options as a non-root user, but any other usage must be
        run as root.

    "[tfr_finddev] backup device not found"
        Error message if the --finddev or --report-device command line
        option is specified and a USB or Passport backup device is not
        found.

EXIT STATUS
    Exit status 0 ($EXIT_OK)
        Successful completion.

    Exit status 1 ($EXIT_COMMAND_LINE)
        In general, there was an issue with the syntax of the command line.

    Exit status 2 ($EXIT_MUST_BE_ROOT)
        The script must run as root or with sudo(1).

    Exit status 3 ($EXIT_ROOTDIR)
        The directory specified for --rootdir does not exist.

    Exit status 4 ($EXIT_TOOLSDIR)
        The OSTools directory does not exist.

    Exit status 5 ($EXIT_BACKUP_DEVICE_NOT_FOUND)
        A backup device of any kind was not found.

    Exit status 6 ($EXIT_USB_DEVICE_NOT_FOUND)
        The --usb-device option was specified but a USB backup device was
        not found.

    Exit status 7 ($EXIT_BACKUP_TYPE)
        The backup type specified with --backup is not supported.

    Exit status 8 ($EXIT_MOUNT_ERROR)
        An error occurred when trying to mount a backup device that was of
        type block device or image file.

    Exit status 9 ($EXIT_RESTORE)
        An unsupported restore type was specified on the command line.

    Exit status 10 ($EXIT_DEVICE_NOT_SPECIFIED)
        A backup device was not specified nor could be found

    Exit status 11 ($EXIT_DEVICE_VERIFY)
        The specified backup device is either not a block device or is not
        an image file of minimum size.

    Exit status 12 ($EXIT_USB_DEVICE_UNSUPPORTED)
        USB devices other than WD Passports are not supported on RHEL4.

    Exit status 13 ($EXIT_CRON_JOB_FILE)
        An error occurred when installing the cron job file.

    Exit status 14 ($EXIT_DEF_CONFIG_FILE)
        An error occurred when installing the default config file.

    Exit status 15 ($EXIT_FORMAT)
        An error occurred when formatting the backup device.

    Exit status 16 ($EXIT_LIST_UNSUP)
        An unsupported list type was specified on the command line.

    Exit status 17 ($EXIT_LIST)
        The files of the specified backup type could not be listed.

    Exit status 18 ($EXIT_SIGINT)
        Script received interrupt signal during a rsync transaction.

    Exit status 19 ($EXIT_RSYNC_ACCOUNT)
        An error occurred either when making the *tfrsync* account while
        installing or when removing the *tfrsync* account while
        uninstalling.

    Exit status 20 ($EXIT_SSH_GENERATE_KEYS)
        An error occurred when generating the RSA keypair for the account
        used to run the rsync command.

    Exit status 21 ($EXIT_SSH_GET_PUBLIC_KEY)
        An error occurred when getting the public key for an "rsync" account
        on the production server.

    Exit status 22 ($EXIT_SSH_GET_PRIVATE_KEY)
        An error occurred when getting the private key for an "rsync"
        account on the production server.

    Exit status 23 ($EXIT_SSH_SUDO_CONF)
        An error occurred configuring the /etc/sudoers file to allow an
        "rsync" account to run *rsync* command via *sudo*; this is
        accomplished not by directly editing /etc/sudoers, but rather by
        using the mechanism for doing this provided in the *harden_linux.pl*
        config file.

    Exit status 24 ($EXIT_SSH_TUNNEL_OPEN)
        An error occurred opening SSH tunnel.

    Exit status 25 ($EXIT_SSH_TUNNEL_CLOSE)
        An error occurred closing SSH tunnel.

    Exit status 26 ($EXIT_SSH_COPY_PUBLIC_KEY)
        An error occurred when trying to copy the newly generated public key
        of the "rsync" account to the default SSH dir of the *tfsupport*
        account.

    Exit status 27 ($EXIT_SSH_ID_FILE)
        The path to the SSH identity file for a specified account could not
        be found.

    Exit status 29 ($EXIT_CLOUD_ACCOUNT_NAME)
        An error occurred forming the name of the cloud account.

    Exit status 30 ($EXIT_GENERATE_PERMS)
        An error occurred generating the perm file for a backup type.

    Exit status 31 ($EXIT_UPLOAD_PERMS)
        An error occurred uploading a perm file to the cloud server.

    Exit status 32 ($EXIT_RESTORE_PERMS)
        When restoring perms from a perm file via the
        --restore-from-permfiles command line option, there was an error
        restoring the perms on the files corresponding to the specified
        backup type.

    Exit status 33 ($EXIT_DOWNLOAD_PERMS)
        When downloading a perm file via the --download-permfiles command
        line option, the perm file corresponding to the specified backup
        type can not be downloaded from the cloud server.

    Exit status 34 ($EXIT_PERM_FILE_MISSING)
        When restoring permissions from a perm file via the
        --restore-from-permfiles command line option, the perm file
        corresponding to the specified backup type can not be found.

    Exit status 40 ($EXIT_LOCK_ACQUISITION)
        Could not acquire the appropriate lockfile which means some previous
        instance of the script is still running.

    Exit status 41 ($EXIT_BACKUP_DEVICE_CONFLICT)
        If a backup device is specified with --device or a usb device is
        specified with --usb-device and --rsync-server is specified, this
        error results. You may not back up to both a device and an rsync
        server at the same time.

        Likewise, if a backup device is specified with --device or a usb
        device is specified with --usb-device and --rsync-dir is specified
        and not --rsync-server, this error results. You may not back up to
        both a device and a file system at the same time.

    Exit status 42 ($EXIT_PLATFORM)
        Unknown operating system.

    Exit status 43 ($EXIT_RSYNC_ERROR)
        The rsync command returned an error. This script response is to stop
        backup transactions and exit.

    Exit status 44 ($EXIT_USERS_INFO_SAVE)
        The users info files could not be generated and saved when
        attempting a backup.

    Exit status 45 ($EXIT_PSERVER_INFO_SAVE)
        The pserver info file could not be saved when attempting a backup.

    Exit status 46 ($EXIT_PSERVER_CLOISTER_FILES_SAVE)
        The pserver cloister files cound not saved when attempting a backup.

    Exit status 50 ($EXIT_XFERDIR_WRITE_ERROR)
        An error occurred when attempting to write a file in the xfer dir.

    Exit status 51 ($EXIT_XFERDIR_MKDIR)
        An error occurred when attempting to make the transfer directory.
        This could happen during installation on the production or the
        backup server.

    Exit status 52 ($EXIT_XFERDIR_RMDIR)
        An error occurred when attempting to remove the transfer directory.

    Exit status 53 ($EXIT_INFODIR_MKDIR)
        An error occurred when attempting to make the production server info
        directory.

    Exit status 54 ($EXIT_INFODIR_RMDIR)
        An error occurred when attempting to remove the production server
        info directory.

    Exit status 55 ($EXIT_USERSDIR_MKDIR)
        An error occurred when attempting to make the users info directory.

    Exit status 56 ($EXIT_USERSDIR_RMDIR)
        An error occurred when attempting to remove the users info
        directory.

    Exit status 57 ($EXIT_TOP_LEVEL_MKDIR)
        Could not make the top level backup dir, ie /usr2/tfrsync on RTI, or
        /d/tfrsync on Daisy.

    Exit status 58 ($EXIT_INSTALL_PSERVER_INFO_FILE)
        An error occurred when attempting to copy the info file from the
        production server to the backup server.

    Exit status 59 ($EXIT_DOVE_SERVER_MISSING)
        During installation on the backup server, the script verifies that
        the Dove server script exists and if it does not, the script exits
        with this exit status.

    Exit status 60 ($EXIT_DOVE_SERVER_SAVE_EXISTS)
        During installation on the backup server, the script verifies that
        the saved Dover server script does NOT exist, and if it does, the
        script exits with this exit status.

    Exit status 62 ($EXIT_CLOISTERDIR_MKDIR)
        An error occurred when attempting to make the directory for the
        production server cloistered files.

    Exit status 63 ($EXIT_CLOISTERDIR_RMDIR)
        An error occurred when attempting to remove the directory for the
        production server cloistered files.

    Exit status 64 ($EXIT_RUNTIME_CLEANUP)
        Could not cleanup the process lock or the SSH tunnel socket.

    Exit status 70 ($EXIT_COULD_NOT_EXECUTE)
        The script was attempting to exec a program, typically via the
        builtin fuction "system", and the exec of the program failed.

    Exit status 71 ($EXIT_FROM_SIGNAL)
        The script execed a program and the program exited because it caught
        a signal.

    Exit status 72 ($EXIT_LOGFILE_SETUP)
        An error occurred while attempting to establish the location for the
        log files.

    Exit status 73 ($EXIT_NET_IPADDR)
        Could not get the ip address of the network device.

    Exit status 74 ($EXIT_NET_NETMASK)
        Could not get the netmask of the network device.

    Exit status 75 ($EXIT_NET_GATEWAY)
        Could not get the ip address of the gateway (router).

    Exit status 92 ($EXIT_SEND_TEST_EMAIL)
        Could not send a test email message.

    Exit status 93 ($EXIT_LUKS_UUID)
        Could not get UUID for LUKS device.

    Exit status 94 ($EXIT_LUKS_STATUS)
        Could not get status for LUKS device.

    Exit status 95 ($EXIT_LUKS_GETINFO)
        Could not get info about LUKS device.

SEE ALSO
    *rsync(1)*, *rtibackup.pl*, *harden_linux.pl*

NAME
    rtibackup.pl - OSTools backup script for RTI and Daisy

VERSION
    This documenation refers to version: $Revision: 1.367 $

OPTIONS
    --version
        Output the version number of the script and exit.

    --help
        Output a short help message and exit.

    --install
        Install the script.

    --backup=s
        Perform a backup.

        Modifiers: --device=s, --usb-device, --compress, --nocc,
        --cryptkey=s, --rti, and --daisy.

    --restore=s
        Restore files from a backup.

        Modifiers: --device, --usb-device, --restore-exclude=s,
        --decompress, --cryptkey=s, --force, --rootdir=s,
        --[no]harden-linux, --dry-run and --upgrade.

    --list=s
        List the files in a backup.

        Modifiers: --device, --usb-device, --rti and --daisy.

    --verify
        Verify a backup.

        Modifiers: --console, --[no]autocheckmedia, --verbose, --rti, and
        --daisy.

    --checkmedia
        Check the media of a backup device. May be used with --backup=s.

        Modifiers: --checkmedia, --email=s, and --printer=s.

    --format
        Format the backup device. May be used with --backup=s.

        Modifiers: --force, and --verbose.

    --eject
        Eject the media from a backup device.

    --finddev
        Find a backup device and report it's device special file.

    --getinfo
        Get and report info about the backups on a backup device.

    --showkey
        Output the encryption key.

        Modifers: --cryptkey=s.

    --validate-cryptkey
        Verify that the encryption key will actually decrypt the backup
        files.

        Modifers: --cryptkey=s.

    --mount
        Mount a backup device.

    --unmount|--umount
        Unmount a backup device.

        Modifers: --verbose.

    --report-configfile
        Parse the config file, and report it's contents.

    --report-is-backup-enabled
        Report whether the backup script is installed and enabled.

    --checkfile args [args ...]
        Verify the files listed as command arguments.

    --rti
        Modifier: specify that the system is a RTI system.

    --daisy
        Modifier: specify that the system is a Daisy system.

    --email=s
        Modifier: specifies a list of email addresses.

    --printer=s
        Modifier: specifies a list of printer names.

    --rootdir=s
        Modifier: specifies the destination directory for restore; used as
        the -C=dir option for the tar(1) command.

    --configfile=s
        Modifier: specifies the path to the config file.

    --logfile=s
        Modifier: specifies the path to the logfile.

    --restore-exclude=s
        Modifier: specifiesy a list of files to exclude from a restore.

    --device=s
        Modifier: specifies the path to the device special file for the
        backup device.

    --device-vendor=s
        Modifier: specifies the vendor name of the backup device.

    --device-model=s
        Modifier: specifies the model name of the backup device.

    --usb-device
        Modifier: use a disk plugged into the USB bus which has been
        formatted with --format as the backup device.

    --compress
        Modifier: compress the files when writing to the backup device.

    --decompress
        Modifier: decompress the files when reading from the backup device.

    --keep-old-files
        Modifer: don't overwrite files when doing a restore.

    --upgrade
        Modifier: perform extra operations when doing a restore.

    --dry-run
        Modifer: report what an operation would do but don't actually do it.

    --verbose
        Modifier: report extra information.

    --[no]autocheckmedia
        Modifier: don't check media on errors during a backup.

    --[no]harden-linux
        Modifier: don't run the harden_linux.pl script.

DESCRIPTION
    This *rtibackup.pl* script is used to backup and restore data for a
    Teleflora RTI or Daisy Point of Sale system. It is essentially an
    elaborate front end to the tar(1) command which does the real work of
    reading and writing the data files. Due to the complexity of the
    requirements, there are many options and many ways that the script can
    be used.

  Command Line Options
    The --install command line option performs all the steps necessary to
    install the "rtibackup.pl" script onto the system. First, the script is
    copied to the OSTools bin directory, and it's file owner, group, and
    perms are set. Then, a symlink is made from the POS bin directory
    pointing to the script in the OSTools bin directory. Next, the cron job
    file is installed. If any old style cron job files exist, they are
    removed. The new cron job file named "nightly-backup" is generated and
    copied into directory "/etc/cron.d". However, if there is an existing
    cron job file in "/etc/cron.d", then the cron job file is copied to the
    OSTools config directory instead.

    The --restore=s command line option restores file from a backup. The
    options --restore-exclude=s, --cryptkey=s, --force, and --rootdir=s may
    be used with --restore.

    The --harden-linux|--noharden-linux command line option provides a way
    to specify whether or not the "harden_linux.pl" script should be run by
    the "rtibackup.pl" script. The default behavior for "rtibackup.pl" is to
    run "harden_linux.pl" after performing any of the following restore
    types: "all", "rticonfigs", "daisy", "daisyconfigs", "osconfigs" and
    "netconfigs". The "harden" script will only be run once after all
    restores are finished. To prevent harden_linux.pl from running, specify
    the following option: "--noharden-linux".

  Definition of Installed and Enabled
    The --report-is-backup-enabled runs through an algorithm to determine if
    the backup script is installed and enabled. The definition of "installed
    and enabled" is:

    1.  the "rtibackup.pl" script exists in OSTools bin directory.

    2.  a symlink for the "rtibackup.pl" script exists in the RTI or Daisy
        bin directory which points to the actual script in the OSTools bin
        directory.

    3.  the mount point exists.

    4.  the cron job file exists and the line which executes "rtibackup.pl"
        is not commented out.

  Daisy Logevents
    When run on a Daisy system and the --backup command line option is
    specified, the "rtibackup.pl" script is coded to send a Daisy "logevent"
    indicating either success or failure of the backup. If the backup was
    successful, only a Daisy "logevent" is sent to the Daisy system, with a
    message stating that the backup succeeded and includes the Linux device
    name. If the backup failed, a Daisy "action" is sent to the Daisy
    system, with a message stating that the backup failed, includes the
    Linux device name, and provides advice on how to address the issue.
    Also, a Daisy "logevent" is sent to the Daisy system, with a message
    stating that the backup failed and includes the Linux device name.

  Sending Email
    The "rtibackup.pl" script can be configured to send email depending on
    one of several conditions. First, described below is when an email
    message is sent, and second, how an email message is sent.

    Backup device not found
        If there are email recipients specified on the command line or in
        the config file, and a backup device is not found, an error message
        will be sent to each of the recipients.

    Verify Status
        If there are email recipients specified on the command line or in
        the config file, and the "--verify" command line option is specified
        along with the "--backup" command line option, then a status message
        will be sent to each of the recipients. Note that the default cron
        job installed by the script specifies both "--backup" and "--verify"
        on the command line invoking "rtibackup.pl" so the default case is
        that an email message will be sent after the backups are completed
        each night.

    Checkmedia Results
        If there are email recipients specified on the command line or in
        the config file, and the "--checkmedia" command line option is
        specified and the "--backup" command line option is NOT specified,
        then a message containing the results of the checkmedia will be sent
        to each of the recipients.

    Given that one or more email recipients are specified, and one of the
    conditions upon which the script will attempt to send an email message
    occurs, then the message can be sent one of the following 3 methods.

    Sendmail
        If the "email_server" config file statement is specified with a
        value of "sendmail", then any email messages sent by the script will
        directly invoke the "/usr/lib/sendmail -oi -t" program with a from
        address of "rtibackup.pl@HOSTNAME.teleflora.com" where HOSTNAME will
        be substituted with the hostname of the system.

    SMTP Server
        If the "email_server" config file statement is specified with a
        value of the FQDN of an SMTP server, and the "email_user" and
        "email_password" config file statements have valid credentials for
        the specified SMTP server, then any email messages sent by the
        script will use the Perl module "Net::SMTP" with a from address of
        "backups@HOSTNAME" where HOSTNAME will be substituted with the
        hostname of the system.

    MUTT
        If the "email_server" config file statement is NOT specified in the
        config file, the message will be sent via the "mutt" command with a
        from address of "tfsupport@HOSTNAME" where, HOSTNAME will be
        substituted with the hostname of the system.

EXAMPLES
    During a backup of types "all" or "osconfigs", a backup of the complete
    /etc sub-tree is written to the backup device. It is sometimes useful to
    reference or restore one file from this copy of /etc. When retrieving a
    file from the backup of /etc, it's generally a good idea a temporary
    directory to hold the extracted files. Thus, the *rtibackup.pl* script
    is directed to write the file to the temporary directory via the use of
    the *--rootdir* command line option. The command line to restore a
    single file from the backup of /etc, for example
    /etc/sysconfig/tfremote, enter the following command:

     sudo rtibackup.pl --rootdir=/tmp --restore /etc/sysconfig/tfremote

    There are several issues to take note of: first, if the *rtibackup.pl*
    script is not in your $PATH, then you will have to specify the whole
    path to the script; second, it takes longer to restore from /etc than
    other restore types since the script looks in every backup set on the
    backup device and does not stop when the file is found - even after
    finding the file, it continues on through all the remaining backup
    types. The restored file will be found in /tmp/etc/sysconfig/tfremote.
    The file can be referenced at that path and copied into it's actual spot
    in the /etc sub-tree as desired.

FILES
    /usr2/bbx/bin and /d/daisy/bin
        The path to the bin directory for RTI and Daisy systems
        respectively.

    /usr2/ostools/bin and /d/ostools/bin
        The path to the OSTools bin directory for RTI and Daisy systems
        respectively.

    /usr2/ostools/config and /d/ostools/config
        The path to the OSTools config directory for RTI and Daisy system
        respectively.

    /etc/cron.d/nightly-backup
        The path to the cron job file.

    /mnt/backups
        Mount point for backup device.

    /etc/redhat-release
        Contents determines OS type, and is used for validating crypt key.

    /sys/block/{sda,sdb,sdc,sde,sdd}/device/vendor
        This file contains the vendor string for the block device, ie disk,
        that has special device file "/dev/sda", or "/dev/sdb", etc.

    /sys/block/{sda,sdb,sdc,sde,sdd}/device/model
        This file contains the model string for the block device, ie disk,
        that has special device file "/dev/sda", or "/dev/sdb", etc.

DIAGNOSTICS
    Exit status 0 ($EXIT_OK)
        Successful completion.

    Exit status 1 ($EXIT_COMMAND_LINE)
        In general, there was an issue with the syntax of the command line.

    Exit status 2 ($EXIT_PLATFORM)
        Unknown operating system.

    Exit status 3 ($EXIT_ROOTDIR)
        The directory specified for --rootdir does not exist.

    Exit status 4 ($EXIT_TOOLSDIR)
        The OSTools directory does not exist.

    Exit status 5 ($EXIT_BACKUP_DEVICE_NOT_FOUND)
        A backup device of any kind was not found.

    Exit status 6 ($EXIT_USB_DEVICE_NOT_FOUND)
        The --usb-device option was specified but a USB backup device was
        not found.

    Exit status 7 ($EXIT_BACKUP_TYPE)
        The backup type specified with --backup is not supported.

    Exit status 10 ($EXIT_LIST)
        The backup type specified with --list was not recognized.

    Exit status 11 ($EXIT_DEVICE_VERIFY)
        The specified backup device is either not a block device or is not
        an image file of minimum size.

    Exit status 12 ($EXIT_USB_DEVICE_UNSUPPORTED)
        USB devices other than WD Passports are not supported on RHEL4.

    Exit status 13 ($EXIT_MOUNT_POINT)
        The default mount point for the backup device did not exist and one
        could not be made.

    Exit status 14 ($EXIT_IS_BACKUP_ENABLED)
        It could not be determined if the "rtibackup.pl" script was enabled
        or not.

    Exit status 23 ($EXIT_SAMBA_CONF)
        An error occurred while modifying one of the Samba conf files.

SEE ALSO
    tar(1), openssl(1)

NAME
    rtiuser.pl - Manage RTI User Accounts

VERSION
    This documenation refers to version: $Revision: 1.13 $

USAGE
    rtiuser.pl

    rtiuser.pl --version

    rtiuser.pl --help

    rtiuser.pl --list

    rtiuser.pl --info username

    rtiuser.pl --add username

    rtiuser.pl --remove username

    rtiuser.pl --update username

    rtiuser.pl --lock username

    rtiuser.pl --unlock username

    rtiuser.pl --resetpw username [password]

    rtiuser.pl --enable-admin username [password]

    rtiuser.pl --disable-admin username

OPTIONS
    --version
        Output the version number of the script and exit.

    --help
        Output a short help message and exit.

    --list
        List the current RTI users and admins.

    --info username
        Get information about the specified user.

    --add username
        Add the specified user to the system as an RTI user.

    --remove username
        Remove the specified user from the system.

    --update username
        Update the settings for the specified user.

    --lock username
        Disable, but do not remove, the account of the specified user.

    --unlock username
        Enable the account of the specified user but do not modify the
        password.

    --resetpw username [password]
        Reset the password for the specified user, either interactively or
        optionally from the command line.

    --enable-admin username [password]
        Grant the specified RTI user 'admin' privileges.

    --disable-admin username
        Remove 'admin' privileges from the specified RTI user.

DESCRIPTION
    This "rtiuser.pl" script manages many aspects of RTI user accounts on
    the system including adding and removing users, setting their passwords,
    enabling/disabling accounts, and enabling/disabling 'admin' privs.

    When adding a new "rti" user via "--add username" option, the new
    account will also be added to the following system groups:

    "rti"
    "floppy"
    "lp"
    "lock"

    On "RHEL5" and "RHEL6", it will also be added to the "uucp" group.

    On "RHEL6" and "RHEL7", it will also be added to the "dialout" group.

    When granting 'admin' privs with the "--enable-admin username" option,
    the user "rti" may not be specified as the username.

FILES
    "/var/log/faillog"
        The log file for recording login failures on platforms that do not
        not the "/sbin/pam_tally2" command.

    "/var/log/tallylog"
        The log file for recording login failures on platforms that do have
        the "/sbin/pam_tally2" command.

    "/var/log/messages"
        The default log file. Log file messages are written via the "logger"
        command.

    "~/.bash_profile"
        This "bash" startup script is modified by the "--add", "--update",
        "--enable-admin", and "--disable-admin" options.

DIAGNOSTICS
    Exit status 0
        Successful completion.

    Exit status 1
        In general, there was an issue with the syntax of the command line.
        Specifically, if the username "rti" was specified with the
        "--enable-admin" option.

    Exit status 2
        For all command line options other than "--version" and "--help",
        the user must be root or running under "sudo".

    Exit status 3
        The specified username did not pass validation, eg it may have had
        characters that are considered a security issue.

    Exit status 4
        The specified password did not pass validation, eg it may have had
        characters that are considered a security issue.

SEE ALSO
    chage(1), faillog(1), pam_tally2(1), useradd(1), usermod(1)

NAME
    tfinfo.pl - report information about the Teleflora Daisy POS

VERSION
    This documenation refers to version: $Revision: 1.9 $

USAGE
    tfinfo.pl [--rti] [--daisy]

    tfinfo.pl --version

    tfinfo.pl --help

OPTIONS
    --version
        Output the version number of the script and exit.

    --help
        Output a short help message and exit.

    --rti
        Report info on a RTI POS

    --daisy
        Report info on a Daisy POS

DESCRIPTION
    The *tfinfo.pl* script gathers information about a RTI or Daisy system,
    such as Dove activity, the florist directory release date, the TCC
    version number, and POS application version number, and writes a short
    summary to stdout.

    The script "identify_daisy_distro.pl" is used to get the Daisy version
    number.

    On RTI systems, the file "/usr2/bbx/tcc_tws" is used to get the version
    of TCC.

    On Daisy systems, the fine "/d/daisy/tcc/tcc" is used to get the version
    of TCC.

EXAMPLE
    The output looks like this:

        $ perl tfinfo.pl
        Teleflora Dove ID: 01234500
        Teleflora florist directory release: Sep 2015
        TCC version: 1.8.3
        Daisy version: 9.3.15

FILES
    /usr2/bbx/bbxd/RTI.ini
        The RTI application "ini" file - contains the RTI version number.

    /usr2/bbx/bbxd/ONRO01
        The RTI file which contains the RTI florist directory release date.

    /usr2/bbx/config/dove.ini
        The RTI file which contains the Teleflora shop id.

    /d/daisy/control.dsy
        The Daisy control file.

    /d/daisy/control.tel
        The Daisy edir control file.

    /d/daisy/dovectrl.pos
        The Daisy Dove control file.

DIAGNOSTICS
    Exit status 0 ($EXIT_OK)
        Successful completion.

    Exit status 1 ($EXIT_COMMAND_LINE)
        In general, there was an issue with the syntax of the command line.

SEE ALSO
    identify_daisy_distro.pl

NAME
    *tfmkpserver.pl* - Script to make a backup server into a production
    server.

VERSION
    This documentation refers to version: $Revision: 1.32 $

SYNOPSIS
    tfmkpserver.pl --help

    tkmkpserver.pl --version

    tkmkpserver.pl [--verbose] [--dry-run] [--logfile=path] [--keep-ip-addr]
    --convert

    tkmkpserver.pl [--verbose] [--dry-run] [--logfile=path] --revert

    tkmkpserver.pl [--verbose] [--dry-run] [--logfile=path] --report-files

DESCRIPTION
  Overview
    The tkmkpserver.pl script is used to convert a backup server into a
    production server.

  Details
    Here is a detailed outline of how tfmkpserver.pl converts the backup
    server to a production serverby performing

    1.  The script verifies the following list of pre-requesites are
        fulfilled:

        a.  verify the platform is "RHEL5" or "RHEL6" or "RHEL7".

        b.  verify that the "production server info file" is present and
            contains values for each of the possible fields allowed.

        c.  verify that the OSTools package is installed.

        d.  if RTI, verify that /usr2 exists and is a directory.

        e.  if RTI, verify that the RTI /etc/init.d scripts exist.

        f.  if RTI, verify that the TCC package is installed.

        g.  if Daisy, verify that /d exists and is a directory.

    2.  restore special files like /usr2/bbx/bin/doveserver.pl. The
        restoration involves renaming the file to it's actual name, and
        setting the perms, owner, and group to there proper values.

    3.  restore a select set of system files from the production server, for
        example, /etc/samba/smb.conf.

    4.  configure the TCC package as appropriate for the platform.

    5.  configure the network by setting the hostname, the ip addr, the
        netmask, and the gateway ipaddr of the backup server to that of the
        production server.

    6.  add any POS users from the production server to the backup server.

    7.  reconcile the UIDs in the Samba password file from the production
        server with those in the password file of the backup server.

    8.  Configure and start the RTI system services: http, bbj, blm, and
        rti.

        The script exits with the exit status returned by tf_make_pserver().
        See section on "EXIT STATUS" below for actual exit status values and
        the the reason why each status would be reported.

  Command Line Options
    --version
        Output the version number of the script and exit.

    --help
        Output a short help message and exit.

    --verbose
        Modifier: report extra information.

    --report-files
        List paths to important files and directories.

    --convert
        Convert a backup server to a production server.

    --revert
        Revert a production server that had once been a backup server back
        to being a backup server.

    --logfile=path
        Specify path to log file.

    --keep-ip-addr
        When converting from a backup server to a production server, keep
        the current ip address of the backup server.

    --dry-run
        Report what an operation would do but don't actually do it.

    --debugmode
        If specified, run in debug mode.

EXAMPLES
    To list the locations of important files and directories, enter the
    following:

     sudo tfmkpserver.pl --report-files

FILES
    /usr2
        The top of the RTI filesystem.

    /usr2/tfrsync
        This directory contains files from the production system.

    /usr2/bbx
        The default RTI directory - this directory must exist and contain a
        standard RTI POS installation.

    /usr2/bbx/log/tfmkpserver.log
        The log file produced by this script.

EXIT STATUS
    Exit status 0 ($EXIT_OK)
        Successful completion.

    Exit status 1 ($EXIT_COMMAND_LINE)
        In general, there was an issue with the syntax of the command line.

    Exit status 2 ($EXIT_MUST_BE_ROOT)
        The script must run as root or with sudo(1).

    Exit status 10 ($EXIT_PREREQS)
        One or more of the prerequisites could not be verified. These
        "prereqs" include conditions like the platform the script is running
        on, the installation of the OSTools package, the existence of
        specific files, directories, and scripts, and the existence of an
        installed POS, either RTI or Daisy.

    Exit status 12 ($EXIT_START_RTI)
        The RTI point of sales application could not be started.

    Exit status 13 ($EXIT_TCC_CONFIG)
        The TCC symlinks for RTI could not be configured.

    Exit status 14 ($EXIT_NETWORK_CONFIG)
        The network configuration of the backup server could not be changed
        to that of the production server.

    Exit status 15 ($EXIT_RESTORING_SPECIAL_FILES)
        The set of files requiring special handling could not be restored.
        Examples include doveserver.pl.

    Exit status 16 ($EXIT_RESTORING_USERS)
        The set of POS users from the production server and their info such
        as passwords, could not be restored on the backup server.

    Exit status 17 ($EXIT_SAMBA_PW_BACKEND)
        The Samba password backend configuration could not be updated on a
        RHEL6 or RHEL7 system.

    Exit status 18 ($EXIT_SAMBA_USERS)
        The Samba uid values in the Samba password file could not be
        updated.

    Exit status 19 ($EXIT_RESTORING_SYSTEM_FILES)
        The backup sets that could not be stored "in place" could not be
        copied into place.

    Exit status 20 ($EXIT_MKDIR_SERVER_INFO_DIR)
        Could not mkdir the server info directory.

    Exit status 21 ($EXIT_GEN_BSERVER_INFO_FILE)
        Could not generate a new backup server info file.

  SEE ALSO
    *tfrsync.pl*

NAME
    tfprinter.pl - Teleflora Printer Maintenance

VERSION
    This documenation refers to version: $Revision: 1.32 $

USAGE
    ./tfprinter.pl --help

    ./tfprinter.pl --version

    ./tfprinter.pl --list

    sudo ./tfprinter.pl --add spoolname:/dev/lp0

    sudo ./tfprinter.pl --add spoolname:/dev/ttyS0

    sudo ./tfprinter.pl --add spoolname:/dev/usb/lp0

    sudo ./tfprinter.pl [--dryrun] --add spoolname:printer.ip.address

    sudo ./tfprinter.pl (--jetdirect | --ipp | --samba | --lpd)
    --ppd=ppd_file --add spoolname:printer.ip.address

    sudo ./tfprinter.pl --user=username --password=pw --share=sharename
    --workgroup=smbwkgrp --add spoolname:printer.ip.address

    sudo ./tfprinter.pl --delete spoolname

    sudo ./tfprinter.pl --clear spoolname

    echo "Stuff to print" | ./tfprinter.pl --print null

    echo "Stuff to print" | ./tfprinter.pl --print screen

    echo "Stuff to print" | ./tfprinter.pl --print spoolname

    echo "Stuff to print" | ./tfprinter.pl --print
    spoolname,spool2name,spool3name,...

    echo "Stuff to print" | ./tfprinter.pl --print pdf >
    /path/to/somefile.pdf

OPTIONS
    --version
        Output the version number of the script and exit.

    --help
        Output a short help message and exit.

    --dryrun
        Output what the command will do without actually making the changes.

DESCRIPTION
    This script

FILES
    /var/log/messages
        The default log file.

    /etc/redhat-release
        The file that contains the platform release version information.

    /var/log/cups
        Location of printing log files.

DIAGNOSTICS
    Exit status 0
        Successful completion.

SEE ALSO
    "/etc/cups/cupsd.conf", cupsenable(1), cupsdisable(1), lpadmin(1),
    lpstat(1), "/etc/init.d/cups", "/var/log/cups",

NAME
    tfremote.pl - script for remote access to a Teleflora POS

VERSION
    This documenation refers to version: $Revision: 1.56 $

USAGE
    tfremote.pl

    tfremote.pl --version

    tfremote.pl --help

    tfremote.pl --install

    tfremote.pl --start

    tfremote.pl --stop

    tfremote.pl --status

    tfremote.pl --connect=s

OPTIONS
    --version
        Output the version number of the script and exit.

    --help
        Output a short help message and exit.

    --install
        Run only once, installs the tfremote.pl script, the tfremote system
        service, and the config file. Must be root to run this option.

    --connect=s
        This option is used mainly on the Teleflora customer service servers
        to connect to customer machines, setting up appropriate security
        parameters, as well as port forwarding rules.

    --start
        Starts the tfremote system service. Must be root to run this option.

    --stop
        Stops the tfremote system service. Must be root to run this option.

    --status
        Reports the status of the tfremote system service.

DESCRIPTION
    The *tfremote.pl* script sets up a "parallel" SSHd service called
    "tfremote". The only authentication method allowed is "SSH public key".

FILES
    /etc/init.d/tfremote
        Only used on RHEL5 and RHEL6, an edited copy of /etc/init.d/sshd.

    /etc/ssh/tfremote_config
        An edited copy of /etc/ssh/sshd_config.

    /etc/sysconfig/tfremote
        Only used on RHEL5 and RHEL6, an edited copy of /etc/sysonfig/sshd.

    /usr/sbin/tfremote
        Only used on RHEL5 and RHEL6, a copy of /usr/sbin/sshd.

    /etc/systemd/system/tfremote.service
        Only used on RHEL7, the unit service file for the tfremote system
        service.

    /usr/lib/systemd/system/sshd.service
        Only used on RHEL7, the unit service file for the sshd system
        service.

DIAGNOSTICS
    Exit status 0 ($EXIT_OK)
        Successful completion.

    Exit status 1 ($EXIT_MUST_BE_ROOT)
        For the "--start", "--stop", and "--install" command line options,
        the user must be root or running under "sudo".

    Exit status 2 ($EXIT_COMMAND_LINE)
        The command line entered was not recognized.

    Exit status 3 ($EXIT_PLATFORM)
        The operating system was not recognized.

SEE ALSO
    sshd(8), sshd_config(5)

NAME
    rtiuser.pl - Manage RTI User Accounts

VERSION
    This documenation refers to version: $Revision: 1.13 $

USAGE
    rtiuser.pl

    rtiuser.pl --version

    rtiuser.pl --help

    rtiuser.pl --list

    rtiuser.pl --info username

    rtiuser.pl --add username

    rtiuser.pl --remove username

    rtiuser.pl --update username

    rtiuser.pl --lock username

    rtiuser.pl --unlock username

    rtiuser.pl --resetpw username [password]

    rtiuser.pl --enable-admin username [password]

    rtiuser.pl --disable-admin username

OPTIONS
    --version
        Output the version number of the script and exit.

    --help
        Output a short help message and exit.

    --list
        List the current RTI users and admins.

    --info username
        Get information about the specified user.

    --add username
        Add the specified user to the system as an RTI user.

    --remove username
        Remove the specified user from the system.

    --update username
        Update the settings for the specified user.

    --lock username
        Disable, but do not remove, the account of the specified user.

    --unlock username
        Enable the account of the specified user but do not modify the
        password.

    --resetpw username [password]
        Reset the password for the specified user, either interactively or
        optionally from the command line.

    --enable-admin username [password]
        Grant the specified RTI user 'admin' privileges.

    --disable-admin username
        Remove 'admin' privileges from the specified RTI user.

DESCRIPTION
    This "rtiuser.pl" script manages many aspects of RTI user accounts on
    the system including adding and removing users, setting their passwords,
    enabling/disabling accounts, and enabling/disabling 'admin' privs.

    When adding a new "rti" user via "--add username" option, the new
    account will also be added to the following system groups:

    "rti"
    "floppy"
    "lp"
    "lock"

    On "RHEL5" and "RHEL6", it will also be added to the "uucp" group.

    On "RHEL6" and "RHEL7", it will also be added to the "dialout" group.

    When granting 'admin' privs with the "--enable-admin username" option,
    the user "rti" may not be specified as the username.

FILES
    "/var/log/faillog"
        The log file for recording login failures on platforms that do not
        not the "/sbin/pam_tally2" command.

    "/var/log/tallylog"
        The log file for recording login failures on platforms that do have
        the "/sbin/pam_tally2" command.

    "/var/log/messages"
        The default log file. Log file messages are written via the "logger"
        command.

    "~/.bash_profile"
        This "bash" startup script is modified by the "--add", "--update",
        "--enable-admin", and "--disable-admin" options.

DIAGNOSTICS
    Exit status 0
        Successful completion.

    Exit status 1
        In general, there was an issue with the syntax of the command line.
        Specifically, if the username "rti" was specified with the
        "--enable-admin" option.

    Exit status 2
        For all command line options other than "--version" and "--help",
        the user must be root or running under "sudo".

    Exit status 3
        The specified username did not pass validation, eg it may have had
        characters that are considered a security issue.

    Exit status 4
        The specified password did not pass validation, eg it may have had
        characters that are considered a security issue.

SEE ALSO
    chage(1), faillog(1), pam_tally2(1), useradd(1), usermod(1)

NAME
    tfremote.pl - script for remote access to a Teleflora POS

VERSION
    This documenation refers to version: $Revision: 1.56 $

USAGE
    tfremote.pl

    tfremote.pl --version

    tfremote.pl --help

    tfremote.pl --install

    tfremote.pl --start

    tfremote.pl --stop

    tfremote.pl --status

    tfremote.pl --connect=s

OPTIONS
    --version
        Output the version number of the script and exit.

    --help
        Output a short help message and exit.

    --install
        Run only once, installs the tfremote.pl script, the tfremote system
        service, and the config file. Must be root to run this option.

    --connect=s
        This option is used mainly on the Teleflora customer service servers
        to connect to customer machines, setting up appropriate security
        parameters, as well as port forwarding rules.

    --start
        Starts the tfremote system service. Must be root to run this option.

    --stop
        Stops the tfremote system service. Must be root to run this option.

    --status
        Reports the status of the tfremote system service.

DESCRIPTION
    The *tfremote.pl* script sets up a "parallel" SSHd service called
    "tfremote". The only authentication method allowed is "SSH public key".

FILES
    /etc/init.d/tfremote
        Only used on RHEL5 and RHEL6, an edited copy of /etc/init.d/sshd.

    /etc/ssh/tfremote_config
        An edited copy of /etc/ssh/sshd_config.

    /etc/sysconfig/tfremote
        Only used on RHEL5 and RHEL6, an edited copy of /etc/sysonfig/sshd.

    /usr/sbin/tfremote
        Only used on RHEL5 and RHEL6, a copy of /usr/sbin/sshd.

    /etc/systemd/system/tfremote.service
        Only used on RHEL7, the unit service file for the tfremote system
        service.

    /usr/lib/systemd/system/sshd.service
        Only used on RHEL7, the unit service file for the sshd system
        service.

DIAGNOSTICS
    Exit status 0 ($EXIT_OK)
        Successful completion.

    Exit status 1 ($EXIT_MUST_BE_ROOT)
        For the "--start", "--stop", and "--install" command line options,
        the user must be root or running under "sudo".

    Exit status 2 ($EXIT_COMMAND_LINE)
        The command line entered was not recognized.

    Exit status 3 ($EXIT_PLATFORM)
        The operating system was not recognized.

SEE ALSO
    sshd(8), sshd_config(5)

