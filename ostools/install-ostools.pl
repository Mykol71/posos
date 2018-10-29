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

