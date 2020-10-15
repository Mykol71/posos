#!/usr/bin/perl
#
# $Revision: 1.347 $
# Copyright 2009-2015 Teleflora.
#
# updateos.pl
#
# Apply updates to the underlying Linux operating system.
# Primarily:
#	Apply redhat errata.
#	Register with redhat
#	(Un) Register with redhat.
#	Upgrade packages as needed for either RTI v14 or Daisy 8.
#	and much more
#

use strict;
use warnings;
use POSIX;
use Socket;
use Getopt::Long;
use English;
use File::Spec;
use File::Basename;
use Sys::Hostname;
use Cwd;

use lib qw( /teleflora/ostools/modules /d/ostools/modules /usr2/ostools/modules );
use OSTools::Platform;
use OSTools::Hardware;
use OSTools::AppEnv;
use OSTools::Filesys;


my $CVS_REVISION = '$Revision: 1.347 $';
my $TIMESTAMP = strftime("%Y%m%d%H%M%S", localtime());
my $PROGNAME = basename($0);

my $EMPTY_STR   = q{};
my $SPACE       = q{ };
my $COMMA       = q{,};
my $COLON       = q{:};
my $ATSIGN      = q{@};
my $DOT         = q{.};
my $DOTDOT      = q{..};
my $SLASH       = q{/};
my $DASH        = q{-};
my $EQUALS      = q{=};
my $SINGLEQUOTE = q{'};

my $HELP = 0;
my $VERSION = 0;
my $VERBOSE = 0;
my $BAREMETAL = 0;
my $RTIV12 = 0;
my $RTIV14 = 0;
my $RTIV15 = 0;
my $DAISYV8 = 0;
my $DAISY_START = 0;
my $DAISY_STOP = 0;
my $DAISY_SHOPCODE = 0;
my $DAISY_SHOPNAME = 0;
my $RTI_SHOPCODE = 0;
my $RTI_SHOPNAME = 0;
my $AUDIT_SYSTEM_CONFIGURE = 0;
my $AUDIT_SYSTEM_RULES_FILE = $EMPTY_STR;
my $BBJ_GEN_SETTINGS_FILE = 0;
my $BBJ_GEN_PROPERTIES_FILE = 0;
my $REMOUNT_TF = "";
my $OSPATCHES = 0;
my $RHNSYSTEMID = 0;
my $RHNREG = 0;
my $SUB_MGR_IDENTITY = 0;
my $SUB_MGR_UNREGISTER = 0;
my $SUB_MGR_REGISTER = 0;
my $SUB_MGR_STATUS = 0;
my $REBOOT = 0;
my $SWAPON = 0;
my $REPORT_SWAP_SIZE = 0;
my $REPORT_ARCHITECTURE = 0;
my $MEMINFO_FILE = "";
my $FORENSICS = 0;
my $OSTOOLS = 0;
my $UPS = 0;
my $UPS_USB = 0;
my $UPS_SERIAL = 0;
my $UPS_SERIAL_PORT = "/dev/ttyS0";
my $MOTD = 0;
my $JAVA = 0;
my $JAVA_VERSION = "latest";
my $SAMBA = 0;
my $SAMBA_GEN_CONF = 0;
my $SAMBA_SET_PASSDB = 0;
my $SAMBA_REBUILD_PASSDB = 0;
my $ONETIMEROOT = 1;
my $IPADDR = "";
my $IPADDR_DEF = "192.168.1.21";
my $NETMASK = "";
my $NETMASK_DEF = "255.255.255.0";
my $GATEWAY = "";
my $GATEWAY_DEF = "192.168.1.1";
my $IF_NAME = "";
my $IF_NAME_DEF = "eth0";
my $NAMESERVER = "";
my $NAMESERVER_DEF = "8.8.8.8";
my $HOSTNAME = "";
my $TFSERVER = "rtihardware.homelinux.com";
my $KEEPDHCP = "";
my $KEEPKERNELS_MIN = 2;
my $KEEPKERNELS = 8;
my $YUMCONF = 0;
my $CONFIGURE_GRUB2 = 0;
my $INIT_CONSOLE_RES = 0;
my $ENABLE_BOOT_MSGS = 0;
my $DISABLE_KMS = 0;
my $SYSLOG_MARK = -1;
my $KLOG_MSG_PRIORITY = -1;
my $KLOG_MSG_PRIORITY_DEF = 3;
my $KERNEL_MSG_CONSOLE = "";
my $UNINSTALL_READAHEAD = 0;
my $GEN_I18N_CONF = 0;
my $EDIT_LOCALE_CONF = 0;
my $CONFIGURE_DEF_RUNLEVEL = 0;
my $CONFIGURE_DEF_TARGET = 0;
my $CONFIGURE_DEF_PASSWORD_HASH =0;
my $DRY_RUN = 0;

my $TEST_ARG = "";
my $TEST_CONFIG_FILE_PATH = "";
my $TEST_SYSCONFIG_HOSTNAME_CHANGE = 0;
my $TEST_HOSTS_CONFIG_FILE_CHANGE = 0;
my $TEST_EDIT_IFCFG = 0;
my $TEST_EDIT_HOSTS = 0;
my $TEST_GEN_RESOLVE_CONF = 0;
my $TEST_GEN_I18N_CONF = 0;
my $TEST_EDIT_YUM_CONF = 0;
my $TEST_EDIT_FSTAB = 0;
my $TEST_SAMBA_PASSDB = 0;
my $TEST_GEN_SAMBA_CONF = 0;
my $TEST_EDIT_CUPS_CONF = 0;
my $TEST_EDIT_SYSLOG_CONF = 0;

my $CUPSTMP = 0;
my $CUPSCONF = 0;
my $CUPSCONF_MAXJOBS = 1;
my $CUPSCONF_DISABLETEMPFILES = 1;
my $CUPSCONF_TIMEOUTS = 1;
my $CUPSCONF_ERRORPOLICY = 1;
my $CUPSCONF_RHEL6_TIMEOUT = 300;
my $CUPSCONF_RHEL5_TIMEOUT = 0;
my $PURGEPRINT = 0;
my $PURGERPMS = 0;
my $OS = plat_os_version();


# these are the types of USB APS hardware that can
# be discovered.
my $APC_USB_TYPE1 = 'American Power Conversion';
my $APC_USB_TYPE2 = 'Tripp Lite';

#
# Values for $ARCH: "", "i386" (32 bit), "x86_64" (64 bit)
#
my $ARCH = "";

#
# Values for $POSDIR: "", "/d/daisy", "/usr2/bbx"
#
my $POSDIR = "";

#
# $DAISY and $RTI are 0 (FALSE) or 1 (TRUE)
#
my $DAISY = 0;
my $RTI = 0;

#
# Path to the logfile - it will either be in the POS tree or if no POS
# has yet been installed, then the log file will be in /tmp.
#
my $LOGFILE_PATH = "";

#
# The rev numbers are "magic" and this script has to be edited and a new
# release of ostools produced if they change - less than desirable.
#
my $BBJ = "2145830.jar.gz";
my $BLM = "blm.2145830.jar.gz";

#
# Java release numbers for RTI15
#
my $RTI15_JAVA_REL = "8u65";
my $RTI15_JAVA_VER = "1.8.0_65";

my $RTI15_BBJ_INSTALL_FILE = "BBj1511_09-28-2015_1801.jar";


# Exit status values
my $EXIT_OK = 0;
my $EXIT_COMMAND_LINE = 1;
my $EXIT_MUST_BE_ROOT = 2;
my $EXIT_SAMBA_CONF = 3;
my $EXIT_GRUB_CONF = 4;
my $EXIT_ARCH = 5;
my $EXIT_NO_SWAP_PARTITIONS = 6;
my $EXIT_MODIFY_FSTAB = 7;
my $EXIT_RAMINFO = 8;
my $EXIT_JAVA_VERSION = 10;
my $EXIT_JAVA_DOWNLOAD = 11;
my $EXIT_JAVA_INSTALL = 12;
my $EXIT_RTI14 = 14;
my $EXIT_READAHEAD = 15;
my $EXIT_SAMBA_PASSDB = 17;
my $EXIT_KEEPKERNELS_MIN = 18;
my $EXIT_PURGE_KERNEL_RPM = 19;
my $EXIT_OSPATCHES = 20;
my $EXIT_WRONG_PLATFORM = 21;
my $EXIT_RHWS_CONVERT = 22;
my $EXIT_UP2DATE = 23;
my $EXIT_YUM_UPDATE = 24;
my $EXIT_DIGI_DRIVERS = 25;
my $EXIT_INITSCRIPTS = 26;
my $EXIT_RHN_NOT_REGISTERED = 27;
my $EXIT_HOSTNAME_CHANGE = 30;
my $EXIT_MOTD = 31;
my $EXIT_RTI_SHOPNAME = 32;
my $EXIT_RTI_SHOPCODE = 33;
my $EXIT_DAISY_SHOPCODE = 34;
my $EXIT_CUPS_CONF_MISSING = 35;
my $EXIT_CUPS_CONFIGURE = 36;
my $EXIT_CUPS_SERVICE_STOP = 37;
my $EXIT_CUPS_SERVICE_START = 38;
my $EXIT_DAISY_START = 39;
my $EXIT_SUB_MGR_IDENTIFICATION = 40;
my $EXIT_SUB_MGR_REGISTRATION = 41;
my $EXIT_SUB_MGR_UNREGISTRATION = 42;
my $EXIT_SUB_MGR_CONDITION = 43;
my $EXIT_DAISY_STOP = 44;
my $EXIT_DAISY_INSTALL_FSTAB = 45;
my $EXIT_DAISY_INSTALL_DHCP = 46;
my $EXIT_DAISY_SHOPNAME = 47;
my $EXIT_AUDIT_SYSTEM_CONFIGURE = 48;
my $EXIT_CONFIGURE_DEF_PASSWORD_HASH = 49;
my $EXIT_CONFIGURE_IP_ADDR = 50;
my $EXIT_CONFIGURE_HOSTNAME = 51;
my $EXIT_CONFIGURE_NAMESERVER = 52;
my $EXIT_CONFIGURE_I18N = 53;
my $EXIT_CONFIGURE_YUM = 54;
my $EXIT_CONFIGURE_LOCALE = 55;
my $EXIT_CONFIGURE_DEF_RUNLEVEL = 56;
my $EXIT_CONFIGURE_DEF_TARGET = 57;
my $EXIT_EDIT_FSTAB = 58;
my $EXIT_APCUPSD_INSTALL = 60;
my $EXIT_BBJ_INSTALL = 61;
my $EXIT_BLM_INSTALL = 62;
my $EXIT_SYSLOG_CONF_MISSING = 70;
my $EXIT_SYSLOG_CONF_CONTENTS = 71;
my $EXIT_SYSLOG_KERN_PRIORITY_VALUE = 72;
my $EXIT_SYSLOG_KERN_PRIORITY = 73;
my $EXIT_SYSLOG_MARK_VALUE = 74;
my $EXIT_SYSLOG_MARK_PERIOD = 75;
my $EXIT_SYSLOG_KERN_TARGET_VALUE = 76;
my $EXIT_SYSLOG_KERN_TARGET = 77;
my $EXIT_SYSLOG_RESTART = 78;
my $EXIT_GRUB2_CONFIGURE = 79;
my $EXIT_GRUB2_CONF_MISSING = 80;

# POS type
my $POS_TYPE_RTI = "rti";
my $POS_TYPE_DAISY = "daisy";

# Network attribute selector
my $NET_ATTR_IPADDR = 1;
my $NET_ATTR_BROADCAST = 2;
my $NET_ATTR_NETMASK = 3;

# operation types for configuring the syslog config file
my $SYSLOG_OPTYPE_KERN_MSG_PRIORITY  = 1;
my $SYSLOG_OPTYPE_MARK_INTERVAL      = 2;
my $SYSLOG_OPTYPE_KERN_TARGET = 3;

# path to the Linux meminfo file in /proc
my $LINUX_PROC_MEMINFO = '/proc/meminfo';

# default name for BBj settings file
my $DEF_BBJ_SETTINGS_FILE_NAME = 'bbjinstallsettings.txt';

# BBj properties file
my $DEF_BBJ_PROPERTIES_FILE_DIR = '/usr2/basis/cfg';
my $DEF_BBJ_PROPERTIES_FILE_NAME = 'BBj.properties';

my $DEF_DAISY_DIR                  = '/d/daisy';
my $DAISY_CONTROL_FILE_NAME        = 'control.dsy';
my $DAISY_SHOPCODE_FILE_NAME       = 'dovectrl.pos';

# audit system config files
my $AUDIT_SYSTEM_CONFIG_DIR        = '/etc/audit/rules.d';
my $RTI_AUDIT_SYSTEM_CONFIG_FILE   = 'rti.rules';
my $RTI_AUDIT_SYSTEM_CONFIG_PATH   =
	File::Spec->catdir($AUDIT_SYSTEM_CONFIG_DIR, $RTI_AUDIT_SYSTEM_CONFIG_FILE);
my $DAISY_AUDIT_SYSTEM_CONFIG_FILE = 'daisy.rules';
my $DAISY_AUDIT_SYSTEM_CONFIG_PATH =
	File::Spec->catdir($AUDIT_SYSTEM_CONFIG_DIR, $DAISY_AUDIT_SYSTEM_CONFIG_FILE);


GetOptions(
	"help" => \$HELP,
	"version" => \$VERSION,
	"verbose" => \$VERBOSE,
	"baremetal" => \$BAREMETAL,
	"rti12" => \$RTIV12,
	"rti14" => \$RTIV14,
	"rti15" => \$RTIV15,
	"daisy|daisy8" => \$DAISYV8,
	"daisy-start" => \$DAISY_START,
	"daisy-stop" => \$DAISY_STOP,
	"daisy-shopcode" => \$DAISY_SHOPCODE,
	"daisy-shopname" => \$DAISY_SHOPNAME,
	"rti-shopcode" => \$RTI_SHOPCODE,
	"rti-shopname" => \$RTI_SHOPNAME,
	"audit-system-configure" => \$AUDIT_SYSTEM_CONFIGURE,
	"audit-system-rules-file=s" => \$AUDIT_SYSTEM_RULES_FILE,
	"bbj-gen-settings-file" => \$BBJ_GEN_SETTINGS_FILE,
	"bbj-gen-properties-file" => \$BBJ_GEN_PROPERTIES_FILE,
	"remount=s" => \$REMOUNT_TF,
	"cupstmp" => \$CUPSTMP,
	"cupsconf" => \$CUPSCONF,
	"purgeprint" => \$PURGEPRINT,
	"purgerpms" => \$PURGERPMS,
	"ups" => \$UPS,
	"ups-usb" => \$UPS_USB,
	"ups-serial" => \$UPS_SERIAL,
	"ups-serial-port=s" => \$UPS_SERIAL_PORT,
	"motd" => \$MOTD,
	"java" => \$JAVA,
	"java-version=s" => \$JAVA_VERSION,
	"samba" => \$SAMBA,
	"samba-gen-conf" => \$SAMBA_GEN_CONF,
	"samba-set-passdb" => \$SAMBA_SET_PASSDB,
	"samba-rebuild-passdb" => \$SAMBA_REBUILD_PASSDB,
	"inittab|default-runlevel" => \$CONFIGURE_DEF_RUNLEVEL,
	"ospatches" => \$OSPATCHES,
	"ostools" => \$OSTOOLS,
	"rhnsystemid" => \$RHNSYSTEMID,
	"rhnreg" => \$RHNREG,
	"sub-mgr-identity" => \$SUB_MGR_IDENTITY,
	"sub-mgr-unregister" => \$SUB_MGR_UNREGISTER,
	"sub-mgr-register" => \$SUB_MGR_REGISTER,
	"sub-mgr-status" => \$SUB_MGR_STATUS,
	"hardboot" => \$REBOOT,
	"reboot" => \$REBOOT,
	"swapon" => \$SWAPON,
	"report-swap-size" => \$REPORT_SWAP_SIZE,
	"report-architecture" => \$REPORT_ARCHITECTURE,
	"meminfo-file=s" => \$MEMINFO_FILE,
	"forensics" => \$FORENSICS,
	"onetimeroot" => \$ONETIMEROOT,
	"ipaddr=s" => \$IPADDR,
	"netmask=s" => \$NETMASK,
	"gateway=s" => \$GATEWAY,
	"ifname=s" => \$IF_NAME,
	"nameserver=s" => \$NAMESERVER,
	"hostname=s" => \$HOSTNAME,
	"tfserver=s" => \$TFSERVER,
	"keepdhcp" => \$KEEPDHCP,
	"keepkernels=s" => \$KEEPKERNELS,
	"yumconf" => \$YUMCONF,
	"configure-grub2" => \$CONFIGURE_GRUB2,
	"init-console-res" => \$INIT_CONSOLE_RES,
	"enable-boot-msgs" => \$ENABLE_BOOT_MSGS,
	"disable-kms" => \$DISABLE_KMS,
	"syslog-mark=s" => \$SYSLOG_MARK,
	"klog-msg-priority=s" => \$KLOG_MSG_PRIORITY,
	"kernel-msg-console=s" => \$KERNEL_MSG_CONSOLE,
	"uninstall-readahead" => \$UNINSTALL_READAHEAD,
	"i18n|gen-i18n-conf" => \$GEN_I18N_CONF,
	"locale" => \$EDIT_LOCALE_CONF,
	"default-target" => \$CONFIGURE_DEF_TARGET,
	"default-password-hash" => \$CONFIGURE_DEF_PASSWORD_HASH,
	"dry-run" => \$DRY_RUN,
	"test-arg=s" => \$TEST_ARG,
	"test-config-file-path=s" => \$TEST_CONFIG_FILE_PATH,
	"test-sysconfig-hostname-change" => \$TEST_SYSCONFIG_HOSTNAME_CHANGE,
	"test-hosts-config-file-change" => \$TEST_HOSTS_CONFIG_FILE_CHANGE,
	"test-edit-ifcfg" => \$TEST_EDIT_IFCFG,
	"test-edit-hosts" => \$TEST_EDIT_HOSTS,
	"test-gen-resolv-conf" => \$TEST_GEN_RESOLVE_CONF,
	"test-gen-i18n-conf" => \$TEST_GEN_I18N_CONF,
	"test-edit-yum-conf" => \$TEST_EDIT_YUM_CONF,
	"test-edit-fstab" => \$TEST_EDIT_FSTAB,
	"test-samba-passdb" => \$TEST_SAMBA_PASSDB,
	"test-gen-samba-conf" => \$TEST_GEN_SAMBA_CONF,
	"test-edit-cups-conf" => \$TEST_EDIT_CUPS_CONF,
	"test-edit-syslog-conf" => \$TEST_EDIT_SYSLOG_CONF,
) || die "error: invalid command line option, exiting...\n";



# --version
if ($VERSION) {
	print "OSTools Version: 1.15.0\n";
	print "$PROGNAME: $CVS_REVISION\n";
	exit(0);
}

# --help
if ($HELP) {
	usage();
	exit(0);
}


if (-d '/d/daisy') {
	$POSDIR = '/d/daisy';
	$DAISY = 1;
}
elsif (-d '/usr2/bbx') {
	$POSDIR = '/usr2/bbx';
	$RTI = 1;
}
else {
	$POSDIR = "";
	loginfo("[main] could not detect that a POS has been installed - assuming none.");
}


$ARCH = processor_arch();


# We must be root to do these things.
unless (is_running_in_test_mode()) {
    if ($EUID != 0) {
	showinfo("[main] must run as root or with sudo");
	exit($EXIT_MUST_BE_ROOT);
    }
}

#########################################
######### TEST OPTIONS PARSER ###########
#########################################

# --test-sysconfig-hostname-change
if ($TEST_SYSCONFIG_HOSTNAME_CHANGE) {
    if ($TEST_CONFIG_FILE_PATH eq $EMPTY_STR) {
	$TEST_CONFIG_FILE_PATH = "/etc/sysconfig/network";
    }
    unless (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	showerror("value of --test-config-file-path insecure: $TEST_CONFIG_FILE_PATH");
	exit($EXIT_COMMAND_LINE);
    }
    unless (-e $TEST_CONFIG_FILE_PATH) {
	showerror("config file does not exist: $TEST_CONFIG_FILE_PATH");
	exit($EXIT_COMMAND_LINE);
    }
    if ($HOSTNAME eq $EMPTY_STR) {
	showerror("value for --hostname must be specified");
	exit($EXIT_COMMAND_LINE);
    }
    unless (is_arg_ok($HOSTNAME)) {
	showerror("value of --hostname insecure: $HOSTNAME");
	exit($EXIT_COMMAND_LINE);
    }

    exit(test_sysconfig_hostname_change($HOSTNAME, $TEST_CONFIG_FILE_PATH));
}

# --test-hosts-config-file-change
if ($TEST_HOSTS_CONFIG_FILE_CHANGE) {
    if ($TEST_CONFIG_FILE_PATH eq $EMPTY_STR) {
	$TEST_CONFIG_FILE_PATH = "/etc/hosts";
    }
    unless (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	showerror("value of --test-config-file-path insecure: $TEST_CONFIG_FILE_PATH");
	exit($EXIT_COMMAND_LINE);
    }
    unless (-e $TEST_CONFIG_FILE_PATH) {
	showerror("config file does not exist: $TEST_CONFIG_FILE_PATH");
	exit($EXIT_COMMAND_LINE);
    }
    if ($HOSTNAME eq $EMPTY_STR) {
	showerror("value for --hostname must be specified");
	exit($EXIT_COMMAND_LINE);
    }
    unless (is_arg_ok($HOSTNAME)) {
	showerror("value of --hostname insecure: $HOSTNAME");
	exit($EXIT_COMMAND_LINE);
    }

    exit(test_hosts_config_file_change($HOSTNAME, $TEST_CONFIG_FILE_PATH));
}

# --test-edit-ifcfg
if ($TEST_EDIT_IFCFG) {
    if ($TEST_CONFIG_FILE_PATH) {
	if (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	    if (-e $TEST_CONFIG_FILE_PATH) {
		if (test_edit_network_ifcfg($IPADDR, $NETMASK, $GATEWAY, $IF_NAME)) {
		    print "[test edit ifcfg] network ifcfg file edited: $TEST_CONFIG_FILE_PATH\n";
		}
		else {
		    print "[test edit ifcfg] could not edit network ifcfg file: $TEST_CONFIG_FILE_PATH\n";
		    exit($EXIT_CONFIGURE_IP_ADDR);
		}
	    }
	    else {
		print "[test edit ifcfg] file does not exist: $TEST_CONFIG_FILE_PATH\n";
		exit($EXIT_COMMAND_LINE);
	    }
	}
	else {
	    print "[test edit ifcfg] insecure value: $TEST_CONFIG_FILE_PATH\n";
	    exit($EXIT_COMMAND_LINE);
	}
    }

    exit($EXIT_OK);
}


# --test-edit-hosts
if ($TEST_EDIT_HOSTS) {
    if ($TEST_CONFIG_FILE_PATH) {
	if (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	    if (-e $TEST_CONFIG_FILE_PATH) {
		if (test_edit_hosts_file($IPADDR)) {
		    print "[test edit hosts] hosts file edited: $TEST_CONFIG_FILE_PATH\n";
		}
		else {
		    print "[test edit hosts] could not edit hosts file: $TEST_CONFIG_FILE_PATH\n";
		    exit($EXIT_CONFIGURE_IP_ADDR);
		}
	    }
	    else {
		print "[test edit hosts] file does not exist: $TEST_CONFIG_FILE_PATH\n";
		exit($EXIT_COMMAND_LINE);
	    }
	}
	else {
	    print "[test edit hosts] insecure value: $TEST_CONFIG_FILE_PATH\n";
	    exit($EXIT_COMMAND_LINE);
	}
    }

    exit($EXIT_OK);
}


# --test-gen-resolv-conf
if ($TEST_GEN_RESOLVE_CONF) {
    if ($TEST_CONFIG_FILE_PATH) {
	if (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	    if (test_generate_resolv_conf($NAMESERVER)) {
		print "[test gen resolv] generated new resolver: $TEST_CONFIG_FILE_PATH\n";
	    }
	    else {
		print "[test gen resolv] could not generate new resolver: $TEST_CONFIG_FILE_PATH\n";
		exit($EXIT_CONFIGURE_NAMESERVER);
	    }
	}
	else {
	    print "[test gen resolv] insecure value: $TEST_CONFIG_FILE_PATH\n";
	    exit($EXIT_COMMAND_LINE);
	}
    }

    exit($EXIT_OK);
}

# --test-gen-i18n-conf
if ($TEST_GEN_I18N_CONF) {
    if ($TEST_CONFIG_FILE_PATH) {
	if (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	    if (test_generate_i18n_conf()) {
		print "[test gen i18n] generated new i18n: $TEST_CONFIG_FILE_PATH\n";
	    }
	    else {
		print "[test gen i18n] could not generate new i18n: $TEST_CONFIG_FILE_PATH\n";
		exit($EXIT_CONFIGURE_I18N);
	    }
	}
	else {
	    print "[test gen i18n] insecure value: $TEST_CONFIG_FILE_PATH\n";
	    exit($EXIT_COMMAND_LINE);
	}
    }

    exit($EXIT_OK);
}


# --test-edit-yum-conf
if ($TEST_EDIT_YUM_CONF) {
    if ($TEST_CONFIG_FILE_PATH) {
	if (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	    if (test_edit_yum_conf()) {
		print "[test edit yum] edited yum config: $TEST_CONFIG_FILE_PATH\n";
	    }
	    else {
		print "[test edit yum] could not edit yum config: $TEST_CONFIG_FILE_PATH\n";
		exit($EXIT_CONFIGURE_YUM);
	    }
	}
	else {
	    print "[test edit yum] insecure value: $TEST_CONFIG_FILE_PATH\n";
	    exit($EXIT_COMMAND_LINE);
	}
    }

    exit($EXIT_OK);
}


# --test-edit-fstab
if ($TEST_EDIT_FSTAB) {
    if ($TEST_CONFIG_FILE_PATH) {
	if (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	    if (test_edit_fstab()) {
		print "[test edit fstab] edited fstab: $TEST_CONFIG_FILE_PATH\n";
	    }
	    else {
		print "[test edit fstab] could not edit fstab: $TEST_CONFIG_FILE_PATH\n";
		exit($EXIT_EDIT_FSTAB);
	    }
	}
	else {
	    print "[test edit fstab] insecure value: $TEST_CONFIG_FILE_PATH\n";
	    exit($EXIT_COMMAND_LINE);
	}
    }

    exit($EXIT_OK);
}


# --test-samba-passdb
if ($TEST_SAMBA_PASSDB) {
    if ($TEST_CONFIG_FILE_PATH) {
	if (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	    if (test_samba_passdb()) {
		print "[test samba passdb] edited samba conf: $TEST_CONFIG_FILE_PATH\n";
	    }
	    else {
		print "[test samba passdb] could not edit samba conf: $TEST_CONFIG_FILE_PATH\n";
		exit($EXIT_SAMBA_CONF);
	    }
	}
	else {
	    print "[test samba passdb] insecure value: $TEST_CONFIG_FILE_PATH\n";
	    exit($EXIT_COMMAND_LINE);
	}
    }

    exit($EXIT_OK);
}


# --test-gen-samba-conf
if ($TEST_GEN_SAMBA_CONF) {
    if ($TEST_CONFIG_FILE_PATH) {
	if (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	    if (test_generate_samba_conf()) {
		print "[test gen samba conf] generated new samba conf: $TEST_CONFIG_FILE_PATH\n";
	    }
	    else {
		print "[test gen samba conf] could not generate new samba conf: $TEST_CONFIG_FILE_PATH\n";
		exit($EXIT_SAMBA_CONF);
	    }
	}
	else {
	    print "[test gen samba conf] insecure value: $TEST_CONFIG_FILE_PATH\n";
	    exit($EXIT_COMMAND_LINE);
	}
    }

    exit($EXIT_OK);
}


# --test-edit-cups-conf
if ($TEST_EDIT_CUPS_CONF) {
    if ($TEST_CONFIG_FILE_PATH) {
	if (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	    if (test_edit_cups_conf()) {
		print "[test edit cups] edited cupsd conf: $TEST_CONFIG_FILE_PATH\n";
	    }
	    else {
		print "[test edit cups] could not edit cupsd conf: $TEST_CONFIG_FILE_PATH\n";
		exit($EXIT_EDIT_FSTAB);
	    }
	}
	else {
	    print "[test edit cups] insecure value: $TEST_CONFIG_FILE_PATH\n";
	    exit($EXIT_COMMAND_LINE);
	}
    }

    exit($EXIT_OK);
}


# --test-edit-syslog-conf
if ($TEST_EDIT_SYSLOG_CONF) {
    if ($TEST_CONFIG_FILE_PATH) {
	if (is_arg_ok($TEST_CONFIG_FILE_PATH)) {
	    if (test_edit_syslog_conf()) {
		print "[test edit syslog] edited syslog conf: $TEST_CONFIG_FILE_PATH\n";
	    }
	    else {
		print "[test edit syslog] could not edit syslog conf: $TEST_CONFIG_FILE_PATH\n";
		exit($EXIT_EDIT_FSTAB);
	    }
	}
	else {
	    print "[test edit syslog] insecure value: $TEST_CONFIG_FILE_PATH\n";
	    exit($EXIT_COMMAND_LINE);
	}
    }

    exit($EXIT_OK);
}


###########################################
######### PUBLIC OPTIONS PARSER ###########
###########################################

	loginfo("BEGIN $PROGNAME $CVS_REVISION");


	# --sub-mgr-identity
	if ($SUB_MGR_IDENTITY) {
	    exit(sub_mgr_identification());
	}

	# --sub-mgr-register
	if ($SUB_MGR_REGISTER) {
	    exit(sub_mgr_registration());
	}

	# --sub-mgr-unregister
	if ($SUB_MGR_UNREGISTER) {
	    exit(sub_mgr_unregistration());
	}

	# --sub-mgr-status
	if ($SUB_MGR_STATUS) {
	    exit(sub_mgr_report_status());
	}

	# --rhnsystemid
	if ($RHNSYSTEMID != 0) {
	    if ( ($OS eq 'RHEL5') ||($OS eq 'RHEL6') ) {
		exit(rhn_system_identification());
	    }

	    showinfo("Red Hat Network system id supported only on RHEL5 or RHEL6");
	    exit($EXIT_WRONG_PLATFORM);
	}

	# --rhnreg
	if ($RHNREG) {
	    if ( ($OS eq 'RHEL5') ||($OS eq 'RHEL6') ) {
		exit(rhn_system_registration());
	    }

	    showinfo("Red Hat Network registration supported only on RHEL5 and RHEL6");
	    exit($EXIT_WRONG_PLATFORM);
	}

	# --baremetal
	if($BAREMETAL != 0) {
		showinfo("Using Teleflora Package Server: \"$TFSERVER\"");
		exit(uos_baremetal_install());
	}

	# --remount=s
	if ($REMOUNT_TF) {
		if ( ($REMOUNT_TF eq '/usr2') || ($REMOUNT_TF eq '/d') ) {
		    exit(remount_filesystem('/teleflora', $REMOUNT_TF));
		}
		else {
		    showerror("remount option value must be '/usr2' or '/d'");
		    exit($EXIT_COMMAND_LINE);
		}
	}

	# --ospatches
	if ($OSPATCHES != 0) {
		exit(update_ospatches());
	}

	# --ostools
	if($OSTOOLS != 0) {
		exit(update_ostools());
	}

	# --configure-grub2
	if ($CONFIGURE_GRUB2) {
	    exit(uos_configure_grub2());
	}

	# --init-console-res
	if ($INIT_CONSOLE_RES != 0) {
		exit(init_console_res());
	}

	# --enable-boot-msgs
	if ($ENABLE_BOOT_MSGS != 0) {
		exit(enable_boot_msgs());
	}

	# --disable-kms
	if ($DISABLE_KMS != 0) {
		exit(disable_kms());
	}

	# --uninstall-readahead
	if ($UNINSTALL_READAHEAD) {
		exit(uninstall_readahead());
	}

	# --syslog-mark
	if ($SYSLOG_MARK != -1) {
		exit(uos_configure_syslog_mark($SYSLOG_MARK));
	}

	# --klog-msg-priority
	if ($KLOG_MSG_PRIORITY != -1) {
		exit(uos_configure_klog_msg_priority($KLOG_MSG_PRIORITY));
	}

	# --kernel-msg-console
	if ($KERNEL_MSG_CONSOLE) {
		exit(uos_configure_syslog_kernel_target($KERNEL_MSG_CONSOLE));
	}


	# --netmask=x.x.x.x
	if ( $NETMASK && ($IPADDR eq "") ) {
	    showerror("The --netmask option not allowed unless --ipaddr also specified");
	    exit(1);
	}

	# --gateway=x.x.x.x
	if ( $GATEWAY && ($IPADDR eq "") ) {
	    showerror("The --gateway option not allowed unless --ipaddr also specified");
	    exit(1);
	}

	# --ifname=string
	if ($IF_NAME) {
	    if ($IPADDR eq "") {
		showerror("The --ifname option not allowed unless --ipaddr also specified");
		exit(1);
	    }
	}
	else {
	    # if --ifname not specified, use the default value.
	    $IF_NAME = $IF_NAME_DEF;
	}


	# --bbj-gen-settings-file
	if ($BBJ_GEN_SETTINGS_FILE) {
	    exit(uos_bbj_gen_settings_file($DEF_BBJ_SETTINGS_FILE_NAME));
	}

	# --bbj-gen-properties-file
	if ($BBJ_GEN_PROPERTIES_FILE) {
	    exit(uos_bbj_gen_properties_file($DEF_BBJ_PROPERTIES_FILE_NAME));
	}

	# --rti15
	if ($RTIV15 != 0) {
	    exit(uos_rti15_install($IF_NAME));
	}

	# --rti14
	if ($RTIV14 != 0) {
	    exit(uos_rti14_install($IF_NAME));
	}

	# --rti12
	if ($RTIV12 != 0) {
	    exit(uos_rtiv12_install($IF_NAME));
	}

	# --daisy | --daisyv8
	if ($DAISYV8 != 0) {
	    exit(uos_daisy_install($IF_NAME));
	}

	# --daisy-start
	if ($DAISY_START) {
	    my $exit_status = $EXIT_OK;
	    if (uos_daisy_start()) {
		showinfo("[main] Daisy started");
	    }
	    else {
		showerror("[main] could not start Daisy");
		$exit_status = $EXIT_DAISY_START;
	    }
	    exit($exit_status);
	}

	# --daisy-stop
	if ($DAISY_STOP) {
	    my $exit_status = $EXIT_OK;
	    if (uos_daisy_stop()) {
		showinfo("[main] Daisy stopped");
	    }
	    else {
		showerror("[main] could not stop Daisy");
		$exit_status = $EXIT_DAISY_STOP;
	    }
	    exit($exit_status);
	}

	# --daisy-shopcode
	if ($DAISY_SHOPCODE) {
	    my $exit_status = $EXIT_OK;
	    my $shopcode = uos_daisy_shopcode();
	    if ($shopcode) {
		showinfo("[main] Daisy shopcode = $shopcode");
	    }
	    else {
		showerror("[main] could not get Daisy shopcode");
		$exit_status = $EXIT_DAISY_SHOPCODE;
	    }
	    exit($exit_status);
	}

	# --daisy-shopname
	if ($DAISY_SHOPNAME) {
	    my $exit_status = $EXIT_OK;
	    my $shopname = uos_daisy_shopname();
	    if ($shopname) {
		showinfo("[main] Daisy shopname = $shopname");
	    }
	    else {
		showerror("[main] could not get Daisy shopname");
		$exit_status = $EXIT_DAISY_SHOPNAME;
	    }
	    exit($exit_status);
	}

	# --rti-shopcode
	if ($RTI_SHOPCODE) {
	    my $exit_status = $EXIT_OK;
	    my $shopcode = uos_rti_shopcode();
	    if ($shopcode) {
		showinfo("[main] RTI shopcode = $shopcode");
	    }
	    else {
		showerror("[main] could not get RTI shopcode");
		$exit_status = $EXIT_RTI_SHOPCODE;
	    }
	    exit($exit_status);
	}

	# --rti-shopname
	if ($RTI_SHOPNAME) {
	    my $exit_status = $EXIT_OK;
	    my $shopname = uos_rti_shopname();
	    if ($shopname) {
		showinfo("[main] RTI shopname = $shopname");
	    }
	    else {
		showerror("[main] could not get RTI shopname");
		$exit_status = $EXIT_RTI_SHOPNAME;
	    }
	    exit($exit_status);
	}


	# --audit-system-configure
	if ($AUDIT_SYSTEM_CONFIGURE) {
	    my $exit_code = $EXIT_OK;

	    # if (--audit-system-rules-file=s) specfied, use it
	    my $rules_file = $EMPTY_STR;
	    if ($AUDIT_SYSTEM_RULES_FILE) {
		$rules_file = $AUDIT_SYSTEM_RULES_FILE;
	    }

	    # get the path of the appropriate config file
	    my $conf_file = uos_pathto_audit_system_config_file();

	    # configure the audit system
	    if (uos_audit_system_configure($conf_file, $rules_file)) {
		showinfo("[main] audit system configured: $conf_file");
	    }
	    else {
		showerror("[main] could not configure audit system");
		$exit_code = $EXIT_AUDIT_SYSTEM_CONFIGURE;
	    }

	    exit($exit_code);
	}


	# --ipaddr=x.x.x.x
	if ($IPADDR) {
	    if ($IPADDR eq $IPADDR_DEF) {
		if ($NETMASK eq $EMPTY_STR) {
		    $NETMASK = $NETMASK_DEF;
		}
		if ($GATEWAY eq $EMPTY_STR) {
		    $GATEWAY = $GATEWAY_DEF;
		}
	    }
	    else {
	        if ( ($NETMASK eq $EMPTY_STR || $GATEWAY eq $EMPTY_STR) ) {
		    showerror("[main] --netmask and --gateway must be specified if ip addr != $IPADDR_DEF");
		    exit($EXIT_COMMAND_LINE);
		}
	    }

	    if (uos_configure_ip_addr($IPADDR, $NETMASK, $GATEWAY, $IF_NAME)) {
		if ($HOSTNAME) {
		    if (uos_configure_hostname($HOSTNAME, $IPADDR, $IF_NAME)) {
			showinfo("[main] Reboot system or restart network to activate network changes");
			exit($EXIT_OK);
		    }
		    else {
			showerror("[main] could not change hostname");
			exit($EXIT_CONFIGURE_HOSTNAME);
		    }
		}
		else {
		    showinfo("[main] Reboot system or restart network to activate ip addr change");
		    exit($EXIT_OK);
		}
	    }
	    else {
		showerror("[main] could not configure ip address");
		exit($EXIT_CONFIGURE_IP_ADDR);
	    }
	}

	# --hostname=name
	if ($HOSTNAME) {
	    if (uos_configure_hostname($HOSTNAME, $IPADDR, $IF_NAME)) {
		showinfo("[main] Reboot system or restart network to activate hostname change");
		exit($EXIT_OK);
	    }
	    else {
		showerror("[main] could not change hostname");
		exit($EXIT_CONFIGURE_HOSTNAME);
	    }
	}

	# --nameserver=x.x.x.x
	if ($NAMESERVER) {
	    exit(uos_configure_nameserver($NAMESERVER));
	}

	# --(i18n|gen-i18n-conf)
	if ($GEN_I18N_CONF) {
	    if ($OS eq 'RHEL5' || $OS eq 'RHEL6') {
		exit(uos_configure_i18n());
	    }
	    elsif ($OS eq 'RHEL7') {
		showinfo("[main] --i18n is only supported on RHEL5 and RHEL6");
		exit($EXIT_WRONG_PLATFORM);
	    }
	    else {
		showinfo("[main] unsupported platform: $OS");
		exit($EXIT_WRONG_PLATFORM);
	    }
	}

	# --locale
	if ($EDIT_LOCALE_CONF) {
	    if ($OS eq 'RHEL5' || $OS eq 'RHEL6') {
		showinfo("[main] --locale is only supported on RHEL7");
		exit($EXIT_WRONG_PLATFORM);
	    }
	    elsif ($OS eq 'RHEL7') {
		exit(uos_set_system_locale());
	    }
	    else {
		showinfo("[main] unsupported platform: $OS");
		exit($EXIT_WRONG_PLATFORM);
	    }
	}

	# --cupstmp
	if ($CUPSTMP != 0) {
		cups_clean_tempfiles();
	}

	# --cupsconf
	if ($CUPSCONF != 0) {
		exit(uos_configure_cups());
	}

	# --purgeprint
	if($PURGEPRINT != 0) {
		exit(uos_purge_cups_jobs());
	}

	# --purgerpms
	if($PURGERPMS != 0) {
	    if ($KEEPKERNELS < $KEEPKERNELS_MIN) {
		showerror("[main] minimum value for --keepkernels: $KEEPKERNELS_MIN");
		exit($EXIT_KEEPKERNELS_MIN);
	    }
	    exit(uos_purge_rpms($KEEPKERNELS));
	}

	# --ups
	if ($UPS || $UPS_SERIAL) {
		exit(uos_install_apcupsd());
	}

	# --motd
	if($MOTD != 0) {
		exit(uos_modify_motd());
	}

	# --java
	if ($JAVA != 0) {
	    exit(uos_java_download_install($JAVA_VERSION));
	}

	# --samba
	# --samba-gen-conf
	if ( ($SAMBA != 0) || ($SAMBA_GEN_CONF != 0) ) {
		my $pos_type = ($RTI) ? $POS_TYPE_RTI : $POS_TYPE_DAISY;
		my $conf_file = uos_pathto_samba_conf();
		exit(uos_generate_samba_config($conf_file, $pos_type));
	}

	# --samba-set-passdb
	if ($SAMBA_SET_PASSDB != 0) {
		exit(uos_configure_samba_passdb());
	}

	# --samba-rebuild-passdb
	if ($SAMBA_REBUILD_PASSDB) {
		exit(uos_rebuild_samba_passdb());
	}

	# --inittab
	# --default-runlevel
	if ($CONFIGURE_DEF_RUNLEVEL != 0) {
		exit(uos_configure_default_runlevel());
	}

	# --default-target
	if ($CONFIGURE_DEF_TARGET) {
		exit(uos_configure_default_target());
	}

	# --default-password-hash
	if ($CONFIGURE_DEF_PASSWORD_HASH) {
		exit(uos_configure_default_password_hash());
	}

	# --hardboot
	# --reboot
	if($REBOOT != 0) {
		exit(uos_hard_reboot());
	}

	# --swapon
	if($SWAPON != 0) {
		exit(swapon());
	}

	# --report-swap-size
	if ($REPORT_SWAP_SIZE) {
		exit(uos_report_swap_size($MEMINFO_FILE));
	}

	# --report-architecture
	if ($REPORT_ARCHITECTURE) {
		exit(uos_report_architecture());
	}

	# --forensics
	if($FORENSICS != 0) {
		exit(forensics());
	}

	# --yumconf
	if ($YUMCONF) {
	    if (uos_configure_yum()) {
		loginfo("[main] yum configured to do kernel updates");
		exit($EXIT_OK);
	    }
	    else {
		showerror("[main] could not configure yum to do kernel updates");
		exit($EXIT_CONFIGURE_YUM);
	    }
	}

	loginfo("END $PROGNAME $CVS_REVISION");

exit(0);
###################################################
###################################################
###################################################


sub usage
{
	print(<< "EOF");
$PROGNAME Usage:

$PROGNAME --version
$PROGNAME --help
$PROGNAME --verbose
$PROGNAME --baremetal
$PROGNAME --rti14 [--tfserver=fqdn] [--ipaddr=x.x.x.x]
$PROGNAME --daisy [--tfserver=fqdn] [--ipaddr=x.x.x.x] [--keepdhcp]
$PROGNAME --daisy-start
$PROGNAME --daisy-stop
$PROGNAME --daisy-shopcode
$PROGNAME --daisy-shopname
$PROGNAME --rti-shopcode
$PROGNAME --rti-shopname
$PROGNAME --ostools
$PROGNAME --reboot

-- Defaults --
    --tfserver=rtihardware.homelinux.com
    --ipaddr=192.168.1.21
    --netmask=255.255.255.0
    --gateway=192.168.1.1
    --ifname=eth0
    --keepkernels=8

-- Advanced Options --
$PROGNAME --ipaddr=x.x.x.x [--netmask=x.x.x.x] [--gateway=x.x.x.x] [--ifname=name]
$PROGNAME --hostname=name
$PROGNAME --nameserver=x.x.x.x
$PROGNAME --remount=/usr2       # remount /teleflora as /usr2
$PROGNAME --remount=/d          # remount /teleflora as /d
$PROGNAME --keepkernels=n	# minimum value is 2
$PROGNAME --syslog-mark=n
$PROGNAME --klog-msg-priority=n
$PROGNAME --kernel-msg-console=/dev/ttyn
$PROGNAME --configure-grub2
$PROGNAME --init-console-res
$PROGNAME --enable-boot-msgs
$PROGNAME --disable-kms
$PROGNAME --uninstall-readahead       # if RHEL6, uninstall the "readahead" rpm
$PROGNAME --java
$PROGNAME --cupstmp
$PROGNAME --cupsconf
$PROGNAME --purgeprint
$PROGNAME --purgerpms
$PROGNAME --ups
$PROGNAME --ups-usb
$PROGNAME --ups-serial
$PROGNAME --ups-serial-port=/dev/ttySn 
$PROGNAME --motd
$PROGNAME --samba
$PROGNAME --samba-gen-conf            # generate appropriate smb.conf file
$PROGNAME --samba-set-passdb          # configure samba to use smbpasswd
$PROGNAME --samba-rebuild-passdb      # rebuild samba smbpasswd file
$PROGNAME --bbj-gen-settings-file     # generate BBj settings config file
$PROGNAME --bbj-gen-properties-file   # generate BBj properties config file
$PROGNAME --ospatches                 # download and apply OS patches
$PROGNAME --rhnsystemid               # report Red Hat Network ID
$PROGNAME --rhnreg                    # register with Red Hat Network
$PROGNAME --inittab
$PROGNAME --sub-mgr-identity
$PROGNAME --sub-mgr-unregister
$PROGNAME --sub-mgr-register
$PROGNAME --sub-mgr-status
$PROGNAME --i18n                      # generate appropriate i18n config file
$PROGNAME --locale                    # set the system locale to "en_US"
$PROGNAME --default-target            # make systemd default target "multi-user"
$PROGNAME --default-password-hash     # make system default password hash "sha512"
$PROGNAME --audit-system-configure    # configure the audit system
$PROGNAME --audit-system-rules-file=s # specify audit system rules file
$PROGNAME --swapon
$PROGNAME --yumconf
$PROGNAME --forensics > /tmp/forensics.txt
EOF

    return(1);
}


#
# search file for regular expression
#
# Returns
#   0 found regular expression
#   1 did not find regular expression
#
sub ost_util_fgrep
{
    my ($file_path, $re) = @_;

    my $rc = 1;
    if (open(my $fp, '<', $file_path)) {
	while (<$fp>) {
	    chomp;
	    if (/$re/) {
		$rc = 0;
		last;
	    }
        }
	close($fp);
    }

    return($rc);
}


###################################
####### TOP LEVEL TEST SUBS #######
###################################

# PCI 6.5.6
#
# Look for a list of patterns in an input string that might
# indicate that some insecure value was passed into the script.
# Example, no input scring should have the BACKQUOTE chars as
# part of the string... if there were, it could mean that
# someone was trying to get the script to run another unknown
# script as "root".
#
# Returns
#   1 if arg is OK
#   0 if arg is insecure
#
sub is_arg_ok
{
    my ($arg) = @_;

    return(1) if ($arg eq "");

    my $rc = 1;

    my @insecure_patterns = (
	'\`',               # `bad command`
	'(\$\()(.*.)(\))',  # $(bad command)
	'\;',               # stuff ; bad command
	'\&',               # stuff && bad command
	'\|',               # stuff | bad command
	'\>',               # stuff > bad command
	'\<',               # stuff < bad command
	'[[:cntrl:]]',      # non printables
    );

    foreach my $re (@insecure_patterns) {
	if ($arg =~ /$re/) {
	    $rc = 0;
	    last;
	}
    }

    return($rc);
}

sub is_running_in_test_mode
{
    my $rc = 0;

    if ($TEST_SYSCONFIG_HOSTNAME_CHANGE) {
	$rc = 1;
    }
    if ($TEST_HOSTS_CONFIG_FILE_CHANGE) {
	$rc = 1;
    }

    return($rc);
}


sub test_sysconfig_hostname_change
{
    my ($hostname, $config_file_path) = @_;

    my $rc = $EXIT_OK;

    if (set_sysconfig_hostname($hostname, $config_file_path)) {
	showinfo("[change sysconfig network] HOSTNAME set to $hostname in: $config_file_path");
    }
    else {
	logerror("[change sysconfig network] could not set HOSTNAME in config file: $config_file_path");
	$rc = $EXIT_HOSTNAME_CHANGE;
    }

    return($rc);
}


sub test_hosts_config_file_change
{
    my ($hostname, $config_file_path) = @_;

    my $rc = $EXIT_OK;

    my $ipaddr = get_network_attribute("eth0", $NET_ATTR_IPADDR);

    if (update_hosts_config_file($hostname, $ipaddr, $config_file_path)) {
	showinfo("[change hosts] hostname in $config_file_path changed to: $hostname");
    }
    else {
	logerror("[change hosts] could not change hostname in config file: $config_file_path");
	$rc = $EXIT_HOSTNAME_CHANGE;
    }

    return($rc);
}


sub test_edit_network_ifcfg
{
    my ($ipaddr, $netmask, $gateway, $if_name) = @_;

    my $rc = 1;

    my $conf_file = uos_pathto_network_ifcfg($if_name);
    if (uos_edit_network_ifcfg($conf_file, $ipaddr, $netmask, $gateway)) {
	loginfo("[test edit ifcfg] network ifcfg file edited: $conf_file");
    }
    else {
	showerror("[test edit ifcfg] could not edit network ifcfg file: $conf_file");
	$rc = 0;
    }

    return($rc);
}


sub test_edit_hosts_file
{
    my ($ipaddr) = @_;

    my $rc = 1;

    my $conf_file = uos_pathto_system_hosts();
    if (uos_edit_system_hosts_file($conf_file, $ipaddr)) {
	loginfo("[configure ip] ip address set to $ipaddr in hosts file: $conf_file");
    }
    else{
	showerror("[configure ip] could not edit hosts file: $conf_file");
	$rc = 0;
    }

    return($rc);
}


sub test_generate_resolv_conf
{
    my ($nameserver) = @_;

    my $rc = 1;

    my $conf_file = uos_pathto_resolv_conf();
    if (uos_generate_resolv_conf($conf_file, $nameserver)) {
	showinfo("[test gen resolv] new resolve conf file generated: $conf_file");
    }
    else {
	$rc = 0;
    }

    return($rc);
}


sub test_generate_i18n_conf
{
    my $rc = 1;

    my $conf_file = uos_pathto_resolv_conf();
    if (uos_generate_i18n_conf($conf_file)) {
	showinfo("[test gen i18n] new i18n conf file generated: $conf_file");
    }
    else {
	$rc = 0;
    }

    return($rc);
}

sub test_edit_yum_conf
{
    my $rc = 1;

    my $conf_file = uos_pathto_yum_conf();
    if (uos_edit_yum_conf($conf_file)) {
	showinfo("[test edit yum] yum conf edited: $conf_file");
    }
    else {
	$rc = 0;
    }

    return($rc);
}


sub test_edit_fstab
{
    my $rc = 1;

    my $conf_file = uos_pathto_fstab();
    if (uos_edit_fstab($conf_file, $TEST_ARG)) {
	showinfo("[test edit fstab] fstab edited: $conf_file");
    }
    else {
	$rc = 0;
    }

    return($rc);
}


sub test_samba_passdb
{
    my $rc = 1;

    my $conf_file = uos_pathto_samba_conf();
    if (uos_edit_samba_conf($conf_file)) {
	showinfo("[test samba passdb] samba conf edited: $conf_file");
    }
    else {
	$rc = 0;
    }

    return($rc);
}


sub test_generate_samba_conf
{
    my $pos_type = ($RTI) ? $POS_TYPE_RTI : $POS_TYPE_DAISY;
    my $conf_file = uos_pathto_samba_conf();
    my $rc = uos_generate_samba_config($conf_file, $pos_type);
    return(($rc == $EXIT_OK) ? 1 : 0);
}


sub test_edit_cups_conf
{
    my $rc = 1;

    my $conf_file = uos_pathto_cups_conf();
    if (uos_edit_cups_conf($conf_file)) {
	showinfo("[test edit cups] cups conf edited: $conf_file");
    }
    else {
	$rc = 0;
    }

    return($rc);
}


sub test_edit_syslog_conf
{
    my $rc = 1;

    my $conf_file = uos_pathto_syslog_conf();
    if (uos_edit_syslog_conf($conf_file, $SYSLOG_OPTYPE_KERN_MSG_PRIORITY, $TEST_ARG)) {
	showinfo("[test edit syslog] syslog conf edited: $conf_file");
    }
    else {
	$rc = 0;
    }

    return($rc);
}


###################################
####### PATHTO SUBS         #######
###################################

sub uos_pathto_audit_system_config_file
{
    if ($DAISY) {
	return($DAISY_AUDIT_SYSTEM_CONFIG_PATH);
    }
    if ($RTI) {
	return($RTI_AUDIT_SYSTEM_CONFIG_PATH);
    }
    return($EMPTY_STR);
}

sub uos_pathto_audit_system_ostools_rules_file
{
    my $rules_file_path = $EMPTY_STR;

    if ($DAISY) {
	my $config_dir_path = uos_pathto_ostools_configdir();
	$rules_file_path = File::Spec->catdir($config_dir_path, $DAISY_AUDIT_SYSTEM_CONFIG_FILE);
    }
    if ($RTI) {
	my $config_dir_path = uos_pathto_ostools_configdir();
	$rules_file_path = File::Spec->catdir($config_dir_path, $RTI_AUDIT_SYSTEM_CONFIG_FILE);
    }

    return($rules_file_path);
}

sub uos_pathto_grub2_conf()
{
    my $conf_file_path = '/etc/default/grub';

    return($conf_file_path);
}

sub uos_pathto_network_ifcfg
{
    my ($if_name) = @_;

    my $conf_file_path = "/etc/sysconfig/network-scripts/ifcfg-$if_name";

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_system_hosts
{
    my $conf_file_path = '/etc/hosts';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_resolv_conf
{
    my $conf_file_path = '/etc/resolv.conf';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_i18n_conf
{
    my $conf_file_path = '/etc/sysconfig/i18n';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_yum_conf
{
    my $conf_file_path = '/etc/yum.conf';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_fstab
{
    my $conf_file_path = '/etc/fstab';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_grub_conf
{
    my $conf_file_path = '/boot/grub/grub.conf';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_locale_conf
{
    my $conf_file_path = '/etc/locale.conf';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_inittab
{
    my $conf_file_path = '/etc/inittab';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_samba_conf
{
    my $conf_file_path = '/etc/samba/smb.conf';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_samba_password
{
    my $conf_file_path = '/etc/samba/smbpasswd';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_cups_conf
{
    my $conf_file_path = '/etc/cups/cupsd.conf';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_motd
{
    my $conf_file_path = '/etc/motd';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}


sub uos_pathto_syslog_conf
{
    my ($os) = @_;

    my $conf_file_path = $EMPTY_STR;

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }
    elsif ($os eq 'RHEL5') {
	$conf_file_path = '/etc/sysconfig/syslog';
    }
    elsif ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	$conf_file_path = '/etc/rsyslog.conf';
    }

    return($conf_file_path);
}


sub uos_pathto_apcupsd_configdir_path
{
    my $apcupsd_configdir_path = '/etc/apcupsd';

    return($apcupsd_configdir_path);
}


sub uos_pathto_apcupsd_conf
{
    my $conf_file_path = $EMPTY_STR;

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }
    else {
	my $apcupsd_configdir_path = uos_pathto_apcupsd_configdir_path();
	$conf_file_path = File::Spec->catdir($apcupsd_configdir_path, 'apcupsd.conf');
    }

    return($conf_file_path);
}


sub uos_pathto_apcupsd_onbatt_script
{
    my $apcupsd_configdir_path = uos_pathto_apcupsd_configdir_path();
    my $apcupsd_onbatt_script_path = File::Spec->catdir($apcupsd_configdir_path, 'onbattery');

    return($apcupsd_onbatt_script_path);
}


sub uos_pathto_ostools_dir
{
    my $ostools_dir_path = $EMPTY_STR;
    if (-d '/usr2/ostools') {
	$ostools_dir_path = '/usr2/ostools';
    }
    elsif (-d '/d/ostools') {
	$ostools_dir_path = '/d/ostools';
    }
    elsif (-d '/teleflora/ostools') {
	$ostools_dir_path = '/teleflora/ostools';
    }

    return($ostools_dir_path);
}


sub uos_pathto_ostools_bindir
{
    my $ostools_dir_path = uos_pathto_ostools_dir();
    my $ostools_bindir_path = ($ostools_dir_path) ?
			      File::Spec->catdir($ostools_dir_path, 'bin') : $EMPTY_STR;

    return($ostools_bindir_path);
}


sub uos_pathto_ostools_configdir
{
    my $ostools_dir_path = uos_pathto_ostools_dir();
    my $ostools_configdir_path = ($ostools_dir_path) ?
			      File::Spec->catdir($ostools_dir_path, 'config') : $EMPTY_STR;

    return($ostools_configdir_path);
}


sub uos_pathto_tf_onbatt_script
{
    my $ostools_dir_path = uos_pathto_ostools_bindir();
    my $tf_onbatt_script_path = ($ostools_dir_path) ?
				File::Spec->catdir($ostools_dir_path, 'tfups_onbattery.pl') : $EMPTY_STR;

    return($tf_onbatt_script_path);
}


sub uos_pathto_bbj_properties_file
{
    my $bbj_properties_file_path = File::Spec->catdir($DEF_BBJ_PROPERTIES_FILE_DIR, $DEF_BBJ_PROPERTIES_FILE_NAME);

    return($bbj_properties_file_path);
}


sub uos_pathto_system_auth_custom
{
    my $conf_file_path = '/etc/pam.d/system-auth-teleflora';

    if ($TEST_CONFIG_FILE_PATH) {
	$conf_file_path = $TEST_CONFIG_FILE_PATH;
    }

    return($conf_file_path);
}

sub uos_nameof_audit_system_config_file
{
    my $rules_file = $EMPTY_STR;

    if ($DAISY) {
	$rules_file = $DAISY_AUDIT_SYSTEM_CONFIG_FILE;
    }
    if ($RTI) {
	$rules_file = $RTI_AUDIT_SYSTEM_CONFIG_FILE;
    }

    return($rules_file);
}


###################################
####### REDHAT NETWORK SUBS #######
###################################

sub rhn_system_identification
{
    my $rhn_system_id = rhn_get_system_id();

    if ($rhn_system_id eq "") {
	$rhn_system_id = "unregistered";
    }
    showinfo("[rhn] Redhat Network System ID: $rhn_system_id\n");

    return($EXIT_OK);
}


sub rhn_system_registration
{
    my $rhn_system_id = rhn_get_system_id();
    if ($rhn_system_id) {
	showinfo("[rhn] system already registered with Red Hat Network: $rhn_system_id");
	return($EXIT_OK);
    }

    showinfo("[rhn] obtaining a Redhat License...");
    $rhn_system_id = rhn_register_redhat();
    if ($rhn_system_id) {
	showinfo("[rhn] Red Hat Network system id: $rhn_system_id");
    }
    else {
	showerror("[rhn] could not register system with Red Hat Network");
	return($EXIT_RHN_NOT_REGISTERED);
    }

    return($EXIT_OK);
}


#
# get the Red Hat Network system id
#
# Returns
#   rhn system id on success
#   empty string if not registered
#
sub rhn_get_system_id
{
    my $rhn_system_id = "";
    my $rhn_system_id_file = '/etc/sysconfig/rhn/systemid';

    #
    # If the rhn system id file does not exist, then the system is
    # not registered.
    #
    unless (-f $rhn_system_id_file) {
	return($rhn_system_id);
    }

    if (open(my $fh, '<', $rhn_system_id_file)) {
	while (<$fh>) {
	    if (/^<name>system_id/) {
		my $next_line = <$fh>;
		if ($next_line =~ /^<value><string>(.+)<\/string><\/value>/) {
		    $rhn_system_id = $1;
		    last;
		}
	    }
	}
	close($fh);
    }

    return($rhn_system_id);
}


# Register with the redhat portal.
# Make sure our rhn daemon is enabled.
sub rhn_register_redhat
{
	my $svctag = "";
	my $vendor = "";
	my $hardware = "";

	my $rhn_system_id = "";

	# get name of manufacturer and
	# get service tag number and
	# get the product name
	my $dmi_cmd = '/usr/sbin/dmidecode';
	if (open(my $pipe, '-|', "$dmi_cmd | grep -A 5 \"System Information\"")) {
	    while(<$pipe>) {
		chomp;
		if(/Manufacturer:\s+(\S+)/) {
			$vendor = $1;
		}
		if(/Serial Number:\s+(\S+)/) {
			$svctag = uc($1);
		}
		if(/Product Name:\s+([[:print:]]+)$/) {
			$hardware = $1;
		}

	    }
	    close($pipe);
	}
	else {
	    logerror("could not get system hardware info via: $dmi_cmd");
	    return($rhn_system_id);
	}


	my $profile_name = "--profilename \"$svctag $vendor $hardware\"";
	my $activation_key = "--activationkey=0ad77379739f3e7b6c3263070a1ab0dc";

	#system("/usr/sbin/rhnreg_ks --force $profile_name $activation_key");
	system("/usr/sbin/rhnreg_ks --username=michael_green --password=T3l3fl0r4# --force");


	foreach my $service_name ("rhnsd", "yum-updatesd") {
		if (-f "/etc/rc.d/init.d/$service_name") {
			system("/sbin/chkconfig --level 3 $service_name on");
			system("/sbin/chkconfig --level 5 $service_name on");
		}
	}

	#
	# Grab and print system ID here.
	# Verify that the Redhat Network Registration succeeded.
	# And let the user know.
	#
	$rhn_system_id = rhn_get_system_id();

	return($rhn_system_id);
}


#
# for RHEL7 systems, configure system to do NTP.
#
# returns
#	1 for success
#	0 for error
#
sub uos_configure_ntp
{
    my $rc = 0;

    my $cmd = '/bin/timedatectl';
    if (-x $cmd) {
	my $exit_status = system("$cmd set-ntp yes");
	if ($exit_status == 0) {
	    $rc = 1;
	}
	else {
	    $exit_status = exit_status_classify($exit_status);
	    logerror("[config ntp] exit status from $cmd: $exit_status");
	}
    }
    else {
	logerror("[config ntp] command not found: $cmd");
    }

    return($rc);
}


#
# rewrite the network interface config file
#
sub uos_rewrite_network_ifcfg
{
    my ($old, $new) = @_;

    while (<$old>) {
	if (/^# Generated by parse-kickstart/) {
	    next;
	}
	elsif (/^IPV6INIT=yes/) {
	    next;
	}
	elsif ( (/^BOOTPROTO=dhcp/) || (/^BOOTPROTO="dhcp"/) ) {
	    print {$new} "BOOTPROTO=\"static\"\n";
	}
	elsif (/^DHCPCLASS=/) {
	    next;
	}
	elsif (/^NM_CONTROLLED=/) {
	    next;
	}
	elsif (/^DEFROUTE=/) {
	    next;
	}
	elsif (/^PEERDNS=/) {
	    next;
	}
	elsif (/^PEERROUTES=/) {
	    next;
	}
	elsif (/^IPV6/) {
	    next;
	}
	elsif (/^NAME=/) {
	    next;
	}
	elsif (/^IPADDR=/) {
	    next;
	}
	elsif (/^GATEWAY=/) {
	    next;
	}
	elsif (/^NETMASK=/) {
	    next;
	}
	elsif (/^# Configuration generated by $PROGNAME/) {
	    next;
	}
	else {
	    # By default, just copy what we read.
	    print {$new} $_;
	}
    }

    return(1);
}


#
# setup network interface config file, eg /etc/sysconfig/network-scripts/ifcfg-eth0
#
# For all platforms, change:
#   BOOTPROTO="dhcp" --> BOOTPROTO="static"
# For all platforms, add
#   IPADDR="$ipaddr"
#   NETMASK="$netmask"
#   GATEWAY="$gateway"
# For RHEL6, add
#   NM_CONTROLLED="no"
#
# returns
#	1 for success
#	0 for error
#
sub uos_edit_network_ifcfg
{
    my ($conf_file, $ipaddr, $netmask, $gateway) = @_;

    if ($ipaddr !~ /^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)$/) {
	showerror("[edit ifcfg] invalid format for ip addr: $ipaddr");
	return(0);
    }

    my $rc = 1;

    my $new_conf_file = "$conf_file.$$";

    if (open(my $old, '<', $conf_file)) {
	if (open(my $new, '>', $new_conf_file)) {

	    if (uos_rewrite_network_ifcfg($old, $new)) {
		loginfo("[edit ifcfg] ifcfg file rewrite successful");
	    }
	    close($new);
	}
	else {
	    showerror("[edit ifcfg] could not open new file for write: $new_conf_file");
	    $rc = 0;
	}
	close($old);
    }
    else {
	showerror("[edit ifcfg] could not open existing file for read: $conf_file");
	$rc = 0;
    }

    #
    # ok, append some lines if rewrite was successful.
    #
    if ($rc) {

	# at this point, verify new conf file exists and is not zero length
	if (-s $new_conf_file) {

	    # open new conf file again to append some more lines.
	    if (open(my $new, '>>', $new_conf_file)) {
		print {$new} "# Configuration generated by $PROGNAME $CVS_REVISION $TIMESTAMP\n";
		print {$new} "IPADDR=\"$ipaddr\"\n";
		print {$new} "NETMASK=\"$netmask\"\n";
		print {$new} "GATEWAY=\"$gateway\"\n";

		if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
		    print {$new} "NM_CONTROLLED=\"no\"\n";
		}

		close($new);

		# again, verify new conf file exists and is not zero length
		if (-s $new_conf_file) {
		    system("chmod --reference=$conf_file $new_conf_file");
		    system("chown --reference=$conf_file $new_conf_file");
		    system("mv $new_conf_file $conf_file");
		}
		else {
		    my $err_type = (-f $new_conf_file) ? "is zero length" : "does not exist";
		    showerror("[edit ifcfg] after append, new conf file $err_type: $new_conf_file");
		    $rc = 0;
		}
	    }
	    else {
		showerror("[edit ifcfg] could not open file for append: $new_conf_file");
		$rc = 0;
	    }

	}
	else {
	    my $err_type = (-f $new_conf_file) ? "is zero length" : "does not exist";
	    showerror("[edit ifcfg] after write, new conf file $err_type: $new_conf_file");
	    $rc = 0;
	}
    }

    unlink $new_conf_file if (-f $new_conf_file);

    return($rc);
}


#
# rewrite hosts file
#
sub uos_rewrite_system_hosts_file
{
    my ($old, $new, $ipaddr) = @_;

    my $hostname = get_hostname();
    if ($hostname eq $EMPTY_STR) {
	logerror("[rewrite hosts] could not get hostname");
	return(0);
    }

    my $fqdn = "";
    my $domain = "teleflora.com";

    # if fully qualified domain name present, remove after saving it
    if ($hostname =~ /(.+)\.$domain/) {
	$fqdn = $hostname;
	$hostname =~ s/\.$domain//;
    }

    # if domain not present, form a fully qualified (if bogus) domain name
    else {
	$fqdn = $hostname . ".$domain";
    }

    # form a new line suitable for the /etc/hosts file
    my $hosts_file_entry = "$ipaddr\t$fqdn $hostname\n";

    while (<$old>) {

	# pass through blank lines and comment lines
	if (/^$/ || /^(\s*)#/) {
	    print {$new} $_;
	    next;
	}

	# pass through the loopback line
	elsif (/^127\.0\.0\.1/) {
	    print {$new} $_;
	    next;
	}

	# for non loopback lines:
	else {
	    if (/$hostname/) {
		$_ = $hosts_file_entry;
	    }
	}

	print {$new} $_;
    }

    return(1);
}


#
# edit the ip address in the system hosts file
#
# returns
#   1 for success
#   0 on error
#
sub uos_edit_system_hosts_file
{
    my ($conf_file, $ipaddr) = @_;

    my $rc = 1;

    # edit hosts file.
    my $new_conf_file = "$conf_file.$$";
    if (open(my $old, '<', $conf_file)) {
        if (open(my $new, '>', $new_conf_file)) {
	    if (uos_rewrite_system_hosts_file($old, $new, $ipaddr)) {
		loginfo("[edit hosts] hosts file rewrite successful: $conf_file");
	    }
	    else {
		logerror("[edit hosts] could not rewrite hosts file: $conf_file");
		$rc = 0;
	    }

	    close($new);
        }
	else {
	    logerror("[edit hosts] could not open new file for write: $new_conf_file");
	    $rc = 0;
	}

	close($old);
    }
    else {
	logerror("[edit hosts] could not open existing file for read: $conf_file");
	$rc = 0;
    }

    if ($rc) {
	if (-s $new_conf_file) {
	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");
	    system("mv $new_conf_file $conf_file");
	    loginfo("[edit hosts] new hosts file renamed: $new_conf_file became $conf_file");
	}
	else {
	    my $err_type = (-f $new_conf_file) ? "is zero length" : "does not exist";
	    showerror("[edit hosts] after rewrite, new conf file $err_type: $new_conf_file");
	    $rc = 0;
	}
    }

    unlink $new_conf_file if (-f $new_conf_file);

    return($rc);
}


#
# completely configure the ip address:
#   - edit the ifcfg file
#   - edit the hosts file
#
# returns
#   1 on success
#   0 on error
#
sub uos_configure_ip_addr
{
    my ($ipaddr, $netmask, $gateway, $if_name) = @_;

    my $rc = 1;

    my $conf_file = uos_pathto_network_ifcfg($if_name);
    if (uos_edit_network_ifcfg($conf_file, $ipaddr, $netmask, $gateway)) {
	loginfo("[configure ip] ip addr updated in ifcfg file: $ipaddr");
	$conf_file = uos_pathto_system_hosts();
	if (uos_edit_system_hosts_file($conf_file, $ipaddr)) {
	    loginfo("[configure ip] ip addr updated in hosts file: $ipaddr");
	}
	else{
	    showerror("[configure ip] could not edit hosts file: $conf_file");
	    $rc = 0;
	}
    }
    else {
	showerror("[configure ip] could not edit network ifcfg file: $conf_file");
	$rc = 0;
    }

    return($rc);
}


#
# For RHEL5 and RHEL6, the steps for changing the hostname are:
# 1) edit /etc/sysconfig/network
# 2) edit /etc/hosts
# 3) run the hostname(1) command
# 4) reboot or at least restart the network service
#
# For RHEL7,
# 1) hostnamectl set-hostname $name
# 2) edit /etc/hosts
#
# Four possible cases with respect to contents of /etc/hosts:
# 1) the hostname does not appear
# 2) the hostname is only on the localhost line
# 3) the hostname is only on a line by itself
# 4) the hostname is on both the localhost line and a line by itself
#
# returns
#   1 on success
#   0 if error
#
sub uos_configure_hostname
{
    my ($new_hostname, $new_ipaddr, $device) = @_;

    my $rc = 1;

    # just a warning
    if ($DAISY) {
	unless ($new_hostname =~ /^\d{8}-tsrvr/) {
	    showerror("Daisy hostnames should be of the form: shopcode-tsrvr");
	    showerror("Eg: for shopcode of \"12345600\", hostname would be: 12345600-tsrvr");
	}
    }

    # if IP address not changing, use current IP address
    if ($new_ipaddr eq "") {
	my $current_hostname = get_hostname();
	my $current_ipaddr = get_ipaddr($current_hostname);
	if ($current_ipaddr eq "") {
	    showerror("could not get current IP address");
	    return(0);
	}
	$new_ipaddr = $current_ipaddr;
    }

    #
    # step 0: strip domain if present
    #
    $new_hostname = strip_domain($new_hostname, "teleflora.com");

    #
    # step 1: edit the sysconfig network file
    #
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	my $config_file_path = '/etc/sysconfig/network';
	if (set_sysconfig_hostname($new_hostname, $config_file_path)) {
	    showinfo("HOSTNAME variable in $config_file_path changed to: $new_hostname");
	}
	else {
	    logerror("could not change HOSTNAME variable in config file: $config_file_path");
	    return(0);
	}
    }
    if ($OS eq 'RHEL7') {
	my $cmd = 'hostnamectl set-hostname';
	system("$cmd $new_hostname");
	if ($? == 0) {
	    showinfo("hostname changed via command: $cmd $new_hostname");
	}
	else {
	    showerror("command <$cmd $new_hostname> returned non-zero exit status: $?");
	    return(0);
	}
    }


    #
    # step 2: edit the hosts file
    #

    my $config_file_path = '/etc/hosts';
    if (update_hosts_config_file($new_hostname, $new_ipaddr, $config_file_path)) {
	showinfo("hostname in $config_file_path changed to: $new_hostname");
    }
    else {
	logerror("could not change hostname in config file: $config_file_path");
	return(0);
    }

    #
    # step 3: run the hostname(1) command
    #
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	my $cmd = 'hostname';
	system("$cmd $new_hostname");
	if ($? == 0) {
	    showinfo("hostname changed via command: $cmd $new_hostname");
	}
	else {
	    showerror("command <$cmd $new_hostname> returned non-zero exit status: $?");
	    return(0);
	}
    }

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	showinfo("Reboot system or restart network to complete hostname change to $new_hostname");
    }

    return($rc);
}


#
# generate a new nameserver config file
#
# returns
#   1 on success
#   0 if error
#
sub uos_generate_resolv_conf
{
    my ($conf_file, $nameserver) = @_;

    my $rc = 1;

    if (open(my $fh, '>', $conf_file)) {

	print {$fh} "; generated by $PROGNAME $CVS_REVISION $TIMESTAMP\n";
	print {$fh} "nameserver $nameserver\n";

	close($fh);
    }
    else {
	logerror("[generate resolv] could not open for write: $conf_file");
	$rc = 0;
    }

    return($rc);
}


#
# configure the DNS nameserver config file
#
# returns
#   $EXIT_OK on success
#   $EXIT_CONFIGURE_NAMESERVER on error
#
sub uos_configure_nameserver
{
    my ($nameserver) = @_;

    my $rc = $EXIT_OK;

    if ($nameserver eq $EMPTY_STR) {
	showerror("name server ip addr is an empty string - using default: $NAMESERVER_DEF");
	$nameserver = $NAMESERVER_DEF;
    }
    elsif ($nameserver !~ /^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)$/) {
	showerror("name server ip addr invalid ($nameserver) - using default: $NAMESERVER_DEF");
	$nameserver = $NAMESERVER_DEF;
    }

    my $conf_file = uos_pathto_resolv_conf();
    if (uos_generate_resolv_conf($conf_file, $nameserver)) {
	showinfo("generated new nameserver config file: $conf_file");
    }
    else {
	$rc = $EXIT_CONFIGURE_NAMESERVER;
    }

    return($rc);
}


#
# generate a new i18n config file
#
# returns
#   1 on success
#   0 if error
#
sub uos_generate_i18n_conf
{
    my ($conf_file) = @_;

    my $rc = 1;

    if (open(my $fh, '>', $conf_file)) {

	print {$fh} "LANG=\"en_US\"\n";
	print {$fh} "SYSFONT=\"latarcyrheb-sun16\"\n";
	print {$fh} "SUPPORTED=\"en_US.UTF-8:en_US:en\"\n";

	close($fh);

	# at this point, error if file does not exist or is zero length
	unless (-s $conf_file) {
	    logerror("[generate i18n] could not generate new i18n conf file: $conf_file");
	    $rc = 0;
	}
    }
    else {
	logerror("[generate i18n] could not open i18n conf file for write: $conf_file");
	$rc = 0;
    }

    return($rc);
}


#
# configure internationalization
#
# (did you know that the "18" in "i18n" stands for the
# 18 chars between "i" and "n" in "internationalization"?)
#
# returns
#   $EXIT_OK on success
#   $EXIT_CONFIGURE_I18N on error
#
sub uos_configure_i18n
{
    my $rc = $EXIT_OK;

    my $conf_file = uos_pathto_i18n_conf();
    my $new_conf_file = $conf_file . ".$$";
    if (uos_generate_i18n_conf($new_conf_file)) {
	system("chmod --reference=$conf_file $new_conf_file");
	system("chown --reference=$conf_file $new_conf_file");
	system("mv $new_conf_file $conf_file");
	showinfo("[configure i18n] generated new i18n config file: $conf_file");
    }
    else {
	showerror("[configure i18n] could not generate new i18n config file: $conf_file");
	$rc = $EXIT_CONFIGURE_I18N;
    }

    return($rc);
}


#
# mv a new conf file to the original name, thus replacing
# the original with a new instance.
#
# returns
#   1 on success
#   0 if error
#
sub uos_rename_conf
{
    my ($new_conf_file, $conf_file) = @_;

    my $rc = 1;

    if (-s $new_conf_file) {
	system("chmod --reference=$conf_file $new_conf_file");
	system("chown --reference=$conf_file $new_conf_file");
	system("mv $new_conf_file $conf_file");
	if ($? == 0) {
	    loginfo("[rename conf] rename of conf file successful: mv $new_conf_file $conf_file");
	}
	else {
	    logerror("[rename conf] could not rename conf file: from $new_conf_file to $conf_file");
	    $rc = 0;
	}
    }
    else {
	my $err_type = (-f $new_conf_file) ? "is zero length" : "does not exist";
	logerror("[rename conf] could not rename conf file: $new_conf_file $err_type");
	$rc = 0;
    }

    return($rc);
}


#
# rewrite the locale config file:
#   LANG="en_US.UTF-8"  becomes LANG="en_US"
#
# returns
#   1 on success
#   0 if error
#
sub uos_rewrite_locale_conf
{
    my ($ofh, $nfh) = @_;

    my $rc = 1;

    while (my $line = <$ofh>) {
	if ($line =~ /LANG=\"en_US.UTF-8\"/) {
	    $line = "LANG=\"en_US\"\n";
	}
	print {$nfh} $line;
    }

    return($rc);
}


#
# edit the system local config file
#
# returns
#   1 on success
#   0 if error
#
sub uos_edit_locale_conf
{
    my ($conf_file) = @_;

    my $rc = 0;

    my $new_conf_file = "$conf_file.$$";

    if (open(my $ofh, '<', $conf_file)) {
	if (open(my $nfh, '>', $new_conf_file)) {
	    if (uos_rewrite_locale_conf($ofh, $nfh)) {
		$rc = 1;
	    }
	    else {
		logerror("[edit locale] could not rewrite conf file: $conf_file");
	    }
	    close($nfh);
	}
	else {
	    logerror("[edit locale] could not open file for write: $new_conf_file");
	}
	close($ofh);
    }
    else {
	logerror("[edit locale] could not open file for read: $conf_file");
    }

    if ($rc) {
	$rc = uos_rename_conf($new_conf_file, $conf_file);
    }

    unlink $new_conf_file if (-f $new_conf_file);

    return($rc);
}


#
# testing demonstrates that the RHEL7 system locale control program
# sets the system locale and updates the system locale config file
# /etc/locale.conf.
#
# returns
#   $EXIT_OK on success
#   $EXIT_CONFIGURE_LOCALE if error
#
sub uos_set_system_locale
{
    my $rc = $EXIT_OK;

    my $locale = "LANG=en_US";
    system("localectl set-locale $locale");
    if ($? == 0) {
	loginfo("[control locale] system locale changed to: $locale");
    }
    else {
	showerror("[control locale] could not change system locale to: $locale");
	$rc = $EXIT_CONFIGURE_LOCALE;
    }

    return($rc);
}


#
# configure system locale
#
# returns
#   $EXIT_OK on success
#   $EXIT_CONFIGURE_LOCALE if error
#
sub uos_configure_locale
{
    my $rc = $EXIT_OK;

    my $conf_file = uos_pathto_locale_conf();
    if (uos_edit_locale_conf($conf_file)) {
	loginfo("[configure locale] system locale config file edit successful: $conf_file");

	uos_set_system_locale();

    }
    else {
	showerror("[configure locale] could not edit system locale config file: $conf_file");
	$rc = $EXIT_CONFIGURE_LOCALE;
    }

    return($rc);
}


#
# run a command needed to do os patches, and write output
# to STDOUT, the standard log file, and a temp log file.
#
# returns
#   1 on success
#   0 if error
#
sub uos_ospatches_log_cmd
{
    my ($cmd, $lfh, $tlfh) = @_;

    my $rc = 1;

    loginfo($cmd);

    if (open(my $pfh, '-|', "$cmd 2>&1")) {
	while (<$pfh>) {
	    print $_;
	    print {$lfh} $_;
	    print {$tlfh} $_;
	}
	if (!close($pfh)) {
	    showerror("[ospatches log] command ($cmd) returned non-zero status: $?");
	    $rc = 0;
	}
    }
    else {
	showerror("[ospatches log] could not open command as pipe: $cmd");
	$rc = 0;
    }

    return($rc);
}


sub update_ospatches_is_t300
{
    my $rc = 0;
    my $sub_name = 'update_ospatches_is_t300';

    my $cmd = '/usr/sbin/dmidecode';
    if (open(my $pipe, q{-|}, $cmd)) {
	while (my $line = <$pipe>) {
	    if ($line =~ /PowerEdge T300/) {
		$rc = 1;
		last;
	    }
	}
	close($pipe) or warn "[$sub_name] could not open pipe to: $cmd\n";;
    }

    return($rc);
}


sub update_ospatches_is_kernel_patch
{
    my $rc = 0;
    my $sub_name = 'update_ospatches_is_kernel_patch';

    my $cmd = 'yum check-update';
    if (open(my $pipe, q{-|}, $cmd)) {
	while (my $line = <$pipe>) {
	    if ($line =~ /kernel.x86_64/) {
		$rc = 1;
		last;
	    }
	}
	# per "perldoc close" documentation, need to check value of $!
	# when # closing a pipe and command run in the pipe might return
	# a non-zero exit value but still is not an error.
	close($pipe) or warn $OS_ERROR ? "[$sub_name] error: closing pipe for $cmd: $OS_ERROR\n"
                                       : "[$sub_name] warning: non-zero exit status $? from: $cmd\n";
    }

    return($rc);
}


#
# Return value of function is used as exit status of script when
# called via the "--ospatches" command line option.
#
# Return    Description
# =====================
#   1       The operating system was not RHEL5, RHEL6, RHEL7
#   4       The yum command failed on RHEL{5,6,7} failed

sub update_ospatches
{
	unless ( ($OS eq 'RHEL7') || ($OS eq 'RHEL6') || ($OS eq 'RHEL5') ) {
	    return($EXIT_WRONG_PLATFORM);
	}

	showinfo("Begin Installing OS Patches...");

	my $timestamp = "";
	$timestamp = strftime("%Y%m%d%H%M%S", localtime());
	showinfo("Timestamp: $timestamp");

	my $tmp_logfile = "/tmp/RHNupdate.log";
	my $hostname = get_hostname();
	my $recipient = "managedservicesar\@teleflora.com";

	# Do our OS Upgrade here.

	my $exit_status = $EXIT_OK;

	# comment out the line in /etc/yum.conf which disables kernel updates
	uos_configure_yum();

	#
	# drop down to 1 kernel for the duration of the update
	# if running on a T300 and there is a kernel patch -
	# if we lose Internet connection during update, we will
	# only have 1 kernel on the system but that can't be avoided
	# since there is not enough room in the /boot partition.
	#
	if (update_ospatches_is_t300()) {
	    if (update_ospatches_is_kernel_patch()) {
		uos_purge_rpms(1);
	    }
	}
	else {
	    uos_purge_rpms($KEEPKERNELS);
	}

	# run the yum clean command - send output in real time to stdout
	# as well as saving output in both log files.
	if (open(my $lfh, '>>', $LOGFILE_PATH)) {
	    if (open(my $tlfh, '>>', $tmp_logfile)) {
		my $cmd = "yum clean -y all";
		if (uos_ospatches_log_cmd($cmd, $lfh, $tlfh) != 1) {
		    $exit_status = $EXIT_YUM_UPDATE;
		}
		close($tlfh);
	    }
	    close($lfh);
	}

	if ($exit_status == $EXIT_OK) {

	    # run the yum update command - send output in real time to stdout
	    # as well as saving output in both log files.
	    if (open(my $lfh, '>>', $LOGFILE_PATH)) {
		if (open(my $tlfh, '>>', $tmp_logfile)) {
		    my $cmd = "yum update -y";
		    if (uos_ospatches_log_cmd($cmd, $lfh, $tlfh) != 1) {
			$exit_status = $EXIT_YUM_UPDATE;
		    }
		    close($tlfh);
		}
		close($lfh);
	    }
	}

	if ($exit_status == $EXIT_OK) {

	    # send both results via email
	    system("mail -s \"RHN update for $hostname\" $recipient < $tmp_logfile");

	    # only install the digi drivers into the kernel on RHEL5 RTI systems.
	    if ($RTI && ($OS eq 'RHEL5') ) {
		if (update_ospatches_kernel_fixup() != 0) {
		    $exit_status = $EXIT_DIGI_DRIVERS;
		}
	    }

	    # only fixup the "initscripts" on RHEL6 Daisy system
	    if ($DAISY && ($OS eq 'RHEL6')) {
		if (update_ospatches_initscripts_fixup() != 0) {
		    $exit_status = $EXIT_INITSCRIPTS;
		}
	    }

	    # always purge kernels to the minimum on T300 systems
	    if (update_ospatches_is_t300()) {
		uos_purge_rpms($KEEPKERNELS_MIN);
	    }
	}

	if (-f $tmp_logfile) {
	    unlink($tmp_logfile);
	}

	if ($exit_status == $EXIT_OK) {

	    # It is possible that our OS updated sshd, in which case,
	    # the 'tfremote' hard links should be re-established. By doing so,
	    # tfremote will use the 'newly updated' sshd.
	    if (-f "/usr/sbin/tfremote" && -f "/usr/sbin/sshd") {
		    system("rm -f /usr/sbin/tfremote");
		    system("ln /usr/sbin/sshd /usr/sbin/tfremote");
	    }
	}


        $timestamp = strftime("%Y%m%d%H%M%S", localtime());
	showinfo("Timestamp: $timestamp");

	showinfo("End Installing OS Patches...");

	return($exit_status);
}


#
# If the "initscripts" rpm package has been updated, two unwanted
# files will have been copied to "/etc/init".
#
# Returns 0 on success or 1 on error
#
sub update_ospatches_initscripts_fixup
{
    my @unwanted_files = qw(
	/etc/init/start-ttys.conf
	/etc/init/tty.conf
    );

    foreach (@unwanted_files) {
	unlink($_);
	return(1) if (-f $_);
    }

    return(0);
}


#
# For each installed kernel, install the Digi drivers if not already installed.
# If the drivers are needed and not downloaded yet, download them.
#
# Returns 0 on success or 1 on error
#
sub update_ospatches_kernel_fixup
{
	my $tmpdir = '/tmp';			# use /tmp for working storage
	my $kern_modules_path = '/lib/modules';	# location of kernel modules
	my $kern_drivers_dir = 'misc';		# subdir for kernel drivers

	# the digi drivers tar file is assumed to contain two files: dgap.ko and dgrp.ko
	my $digi_drivers_tarfile = 'ES4Digidrivers.tar.gz';
	if ( ($OS eq "RHEL5") || ($OS eq "RHWS5") ) {
		$digi_drivers_tarfile = 'WS5digi.tar.gz';
	}
	my $digi_dgap_file = 'dgap.ko';
	my $digi_dgrp_file = 'dgrp.ko';
	my $digi_drivers_path = "$tmpdir/$digi_drivers_tarfile";
	my $digi_dgap_path = "$tmpdir/$digi_dgap_file";
	my $digi_dgrp_path = "$tmpdir/$digi_dgrp_file";

	# the digi drivers tar file should be available on the ostools web site
	my $ostools_url = "http://$TFSERVER/ostools";
	my $digi_drivers_url = "$ostools_url/$digi_drivers_tarfile";

	showinfo("Installing Digi Drivers...");

	my @kernel_list = glob("$kern_modules_path/*");
	unless (@kernel_list) {
	    showerror("kernel modules directory empty: $kern_modules_path");
	    return(1);
	}

	foreach my $thiskern (@kernel_list) {

	    showinfo("Verifying presence of Digi drivers for kernel: $thiskern");

	    #
	    # This path should look like: /lib/modules/2.6.18-194.8.1.el/misc
	    #
	    my $kern_drivers_path = "$thiskern/$kern_drivers_dir";

	    # if there is no drivers dir, make one
	    unless (-d "$kern_drivers_path") {
		system("mkdir $kern_drivers_path");
	    }
	    unless (-d "$kern_drivers_path") {
		showerror("Can't make kernel drivers directory: $thiskern");
		return(1);
	    }

	    # if both drivers are present, nothing to do
	    if (-f "$kern_drivers_path/$digi_dgap_file" &&
		-f "$kern_drivers_path/$digi_dgrp_file") {
		showinfo("Digi drivers already installed for kernel: $thiskern");
		next;
	    }

	    #
	    # One or more drivers not installed...
	    # So download drivers if not already downloaded and then install them
	    #
	    unless (-f $digi_drivers_path) {

		showinfo("Downloading Digi Drivers from $digi_drivers_url...");

		system("curl -s -o $digi_drivers_path $digi_drivers_url");
		system("tar ztf $digi_drivers_path > /dev/null 2> /dev/null");
		if ($? != 0) {
		    showerror("download of digi drivers failed: $digi_drivers_url");
		    return(1);
		}
		system("cd $tmpdir && tar zxf $digi_drivers_path");
		if ($? != 0) {
		    showerror("untar of digi drivers failed: $digi_drivers_path.");
		    return(1);
		}
	    }

	    showinfo("Installing Digi Drivers for kernel: $thiskern");

	    system("cp $digi_dgap_path $kern_drivers_path");
	    system("chown root:root $kern_drivers_path/$digi_dgap_file");
	    system("chmod 664 $kern_drivers_path/$digi_dgap_file");
	    system("cp $digi_dgrp_path $kern_drivers_path");
	    system("chown root:root $kern_drivers_path/$digi_dgrp_file");
	    system("chmod 664 $kern_drivers_path/$digi_dgrp_file");
	}

	if (-f $digi_drivers_path) {
	    system("rm $digi_drivers_path");
	    system("rm $digi_dgap_path");
	    system("rm $digi_dgrp_path");
	}

	return(0);
}


sub uos_rewrite_yum_conf
{
    my ($old, $new) = @_;

    my $rc = 1;

    while (<$old>) {
	chomp;

	if ( /^(\s*)exclude=kernel/ ) {
	    print {$new} "# --- $PROGNAME $CVS_REVISION $TIMESTAMP ---\n";
	    print {$new} "# --- following line commented out ---\n";
	    print {$new} "# $_\n";
	}
	else {
	    print {$new} "$_\n";
	}
    }

    return($rc);
}


#
# edit the yum conf file to perform kern updates
#
# returns
#   1 on success
#   0 if error
#
sub uos_edit_yum_conf
{
    my ($conf_file) = @_;

    my $rc = 1;

    my $new_conf_file = $conf_file . ".$$";

    if (open(my $old, '<', $conf_file)) {
        if (open(my $new, '>', $new_conf_file)) {

	    if (uos_rewrite_yum_conf($old, $new)) {
		loginfo("[edit yum] yum conf rewritten: $conf_file");
	    }
	    else {
		showerror("[edit yum] could not rewrite yum conf: $conf_file");
		$rc = 0;
	    }

	    close($new);
        }
	else {
	    showerror("[edit yum] could not open config for write: $new_conf_file");
	    $rc = 0;
	}
	close($old);
    }
    else {
	showerror("[edit yum] could not open config for read: $conf_file");
	$rc = 0;
    }

    if ($rc) {
	if (-s $new_conf_file) {
	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");
	    system("mv $new_conf_file $conf_file");
	    loginfo("[edit yum] new yum conf file renamed: $new_conf_file became $conf_file");
	}
	else {
	    my $err_type = (-f $new_conf_file) ? "is zero length" : "does not exist";
	    showerror("[edit yum] new yum conf file $err_type: $new_conf_file");
	    $rc = 0;
	}
    }

    unlink $new_conf_file if (-f $new_conf_file);

    return($rc);
}


sub uos_configure_yum
{
    my $rc = 1;

    my $conf_file = uos_pathto_yum_conf();

    # non-zero means not found, thus yum IS configured to do kern updates
    if (ost_util_fgrep($conf_file, '^exclude=kernel')) {
	return($rc);
    }

    if (uos_edit_yum_conf($conf_file)) {
	loginfo("[configure yum] yum configured for kernel updates");
    }
    else {
	showerror("[configure yum] could not configure yum for kernel updates");
	$rc = 0;
    }

    return($rc);
}


# Just grab and run an install script from our website.
# Let that script do the hard work.
sub update_ostools
{
	print("Updating Teleflora OS Tools...\n");
	system("wget -O - http://$TFSERVER/ostools/install-ostools-1.15.pl | sudo perl - --update --norun-harden-linux");
	return($?);
}


sub uos_rewrite_system_auth_custom
{
    my ($ofh, $nfh) = @_;

    while (my $line = <$ofh>) {
	if ($line =~ /pam_unix.so\s+md5/x) {
	    $line =~ s/md5/sha512/;
	}
	print {$nfh} $line;
    }

    return(1);
}


sub uos_edit_system_auth_custom
{
    my ($conf_file) = @_;
    my $sub_name = 'uos_edit_system_auth_custom';

    my $rc = 0;

    my $new_conf_file = "$conf_file.$$";

    if (open(my $ofh, '<', $conf_file)) {
	if (open(my $nfh, '>', $new_conf_file)) {
	    uos_rewrite_system_auth_custom($ofh, $nfh);

	    $rc = 1;

	    close($nfh);
	}
	else {
	    logerror("[$sub_name] could not open file for write: $new_conf_file");
	}
	close($ofh);
    }
    else {
	logerror("[$sub_name] could not open file for read: $conf_file");
    }

    # if the config file was successfully rewritten, and now
    # that the files are closed, the rename can be attempted.
    if ($rc) {
	$rc = uos_rename_conf($new_conf_file, $conf_file);
    }

    unlink $new_conf_file if (-f $new_conf_file);

    return($rc);
}


sub uos_configure_default_password_hash
{
    my $rc = $EXIT_CONFIGURE_DEF_PASSWORD_HASH;
    my $sub_name = 'uos_configure_default_password_hash';

    # first run the command
    my $cmd = ($OS eq 'RHEL5' || $OS eq 'RHEL6') ? '/usr/bin/authconfig' : '/sbin/authconfig';
    my $hash = 'sha512';
    my $exit_status = system("$cmd --passalgo=$hash --update");
    if ($exit_status == 0) {
	showinfo("[$sub_name] default system password hash set to: $hash");
    }
    else {
	showerror("[$sub_name] could not set default password hash, error: $exit_status");
	return($rc);
    }

    # then edit the PAM config file if need be
    my $conf_file = uos_pathto_system_auth_custom();
    if (-f $conf_file) {
	if (ost_util_fgrep($conf_file, 'pam_unix.so sha512') == 0) {
	    showinfo("[$sub_name] PAM password hash already set to sha512 in: $conf_file");
	    $rc = $EXIT_OK;
	}
	else {
	    if (uos_edit_system_auth_custom($conf_file)) {
		showinfo("[$sub_name] PAM password hash set to sha512 in: $conf_file");
		$rc = $EXIT_OK;
	    }
	    else {
		showerror("[$sub_name] could not set PAM password hash in: $conf_file");
	    }
	}
    }
    else {
	loginfo("[$sub_name] custom PAM system auth file does not exist: $conf_file");
	loginfo("[$sub_name] execute 'harden_linux.pl' to configure PAM");
    }

    return($rc);
}


sub uos_rewrite_default_runlevel
{
    my ($oldfh, $newfh) = @_;

    while (my $line = <$oldfh>) {
	if ($line =~ /id: \d : \s* initdefault \s* :/xi) {
	    $line = "id:3:initdefault:\n";
	}
	print {$newfh} $line;
    }

    return(1);
}


#
# edit the line that sets the default runlevel in the
# /etc/inittab file.
#
# returns
#   1 on success
#   0 if error
#
sub uos_edit_default_runlevel
{
    my ($conf_file) = @_;

    my $rc = 0;

    my $new_conf_file = $conf_file . "_$$";

    if (open(my $oldfh, '<', $conf_file)) {
	if (open(my $newfh, '>', $new_conf_file)) {
	    uos_rewrite_default_runlevel($oldfh, $newfh);
	    close($newfh);
	    $rc = 1;
	}
	else {
	    logerror("[edit runlevel] could not open for write: $new_conf_file");
	}
	close($oldfh);
    }
    else {
	logerror("[edit runlevel] could not open for read: $conf_file");
    }

    if ($rc) {
	# file exists and is non-zero size
	if (-s $new_conf_file) {
	    system("mv $new_conf_file $conf_file");
	}
	# file is either zero size or does not exist
	else {
	    if (-e $new_conf_file) {
		logerror("[edit runlevel] generated conf file size is 0: $new_conf_file");
		unlink $new_conf_file;
	    }
	    else {
		logerror("[edit runlevel] generated conf file does not exist: $new_conf_file");
	    }
	    $rc = 0;
	}
    }

    return($rc);
}


#
# if the system has an inittab, make the default run level 3.
#
# returns
#   $EXIT_OK on success
#   $EXIT_CONFIGURE_DEF_RUNLEVEL if error
#
sub uos_configure_default_runlevel
{
    my $conf_file = uos_pathto_inittab();

    my $rc = $EXIT_CONFIGURE_DEF_RUNLEVEL;

    if (-f $conf_file) {
	if (uos_edit_default_runlevel($conf_file)) {
	    showinfo("[default runlevel] default run level set in: $conf_file");
	    $rc = $EXIT_OK;
	}
	else {
	    showerror("[default runlevel] could not set default run level in: $conf_file");
	}
    }
    else {
	showerror("[default runlevel] inittab file does not exist: $conf_file");
    }

    return($rc);
}


#
# RHEL7: set the systemd default target.
#
# returns
#   1 on success
#   0 if error
#
sub uos_edit_default_target
{
    my ($def_target) = @_;

    my $rc = 0;

    system("/bin/systemctl set-default $def_target");
    if ($? == 0) {
	$rc = 1;
    }
    else {
	logerror("[edit target] could not set default target to: $def_target");
    }

    return($rc);
}


#
# RHEL7: set the systemd default target to "multi-user".
#
# returns
#   $EXIT_OK on success
#   $EXIT_CONFIGURE_DEF_TARGET if error
#
sub uos_configure_default_target
{
    my $conf_dir = '/etc/systemd/system';
    my $def_target = 'multi-user.target';

    my $rc = $EXIT_CONFIGURE_DEF_TARGET;

    if (-d $conf_dir) {
	if (uos_edit_default_target($def_target)) {
	    showinfo("[configure target] systemd default target configured: $def_target");
	    $rc = $EXIT_OK;
	}
	else {
	    showerror("[configure target] could not configure default target: $def_target");
	}
    }
    else {
	showerror("[configure target] default target directory does not exist: $conf_dir");
    }

    return($rc);
}


sub uos_rewrite_fstab
{
    my ($oldfh, $newfh, $mount_pt) = @_;

    while (my $line = <$oldfh>) {
	my ($fs_spec, $fs_file, $fs_vfstype, $fs_mntops, $fs_freq, $fs_passno) = split(/\s+/, $line);
	if ($fs_file eq $mount_pt) {
	    if ($fs_mntops ne $EMPTY_STR) {
		$fs_mntops .= ',';
	    }
	    $fs_mntops .= "nofail";
	    print {$newfh} "$fs_spec\t$fs_file\t$fs_vfstype\t$fs_mntops\t$fs_freq $fs_passno\n";
	}
	else {
	    print {$newfh} $line;
	}
    }

    return(1);
}


#
# edit the fstab adding the "nofail" option
#
# returns
#   1 on success
#   0 if error
#
sub uos_edit_fstab
{
    my ($conf_file, $mount_pt) = @_;

    my $rc = 1;

    my $new_conf_file = $conf_file . ".$$";

    if (open(my $old, '<', $conf_file)) {
        if (open(my $new, '>', $new_conf_file)) {

	    if (uos_rewrite_fstab($old, $new, $mount_pt)) {
		loginfo("[edit fstab] fstab rewritten: $conf_file");
	    }
	    else {
		showerror("[edit fstab] could not rewrite fstab: $conf_file");
		$rc = 0;
	    }

	    close($new);
        }
	else {
	    showerror("[edit fstab] could not open fstab for write: $new_conf_file");
	    $rc = 0;
	}
	close($old);
    }
    else {
	showerror("[edit fstab] could not open fstab for read: $conf_file");
	$rc = 0;
    }

    if ($rc) {
	if (-s $new_conf_file) {
	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");
	    system("mv $new_conf_file $conf_file");
	    loginfo("[edit fstab] new fstab file renamed: $new_conf_file became $conf_file");
	}
	else {
	    my $err_type = (-f $new_conf_file) ? "is zero length" : "does not exist";
	    showerror("[edit fstab] new fstab file $err_type: $new_conf_file");
	    $rc = 0;
	}
    }

    unlink $new_conf_file if (-f $new_conf_file);

    return($rc);
}


#
# Clear out the login banner file, /etc/motd.
#
# There is no PCI requirement driving this file's contents.
#
# returns
#   $EXIT_OK on success
#   non-zero if error
#
sub uos_modify_motd
{
    my $conf_file = uos_pathto_motd();

    my $rc = $EXIT_MOTD;

    if (-f "$conf_file") {
	my $new_conf_file = "$conf_file.$$";

	# make new empty motd file
	system("touch $new_conf_file");

	# did we successfully make a new motd file?
	if (-f "$new_conf_file") {
	    # replace the old one with the new.
	    system("chmod --reference=$conf_file $new_conf_file");
	    system("chown --reference=$conf_file $new_conf_file");
	    system("mv $new_conf_file $conf_file");
	    if ($? == 0) {
		showinfo("[mod motd] login banner file truncated: $conf_file");
		my $rc = $EXIT_OK;
	    }
	    else {
		showerror("[mod motd] could not replace old motd file: $conf_file");
		system("rm -f $new_conf_file");
	    }
	}
	else {
	    showerror("[mod motd] could not make new motd file: $new_conf_file");
	}
    }
    else {
	showerror("[mod motd] motd file does not exist: $conf_file");
    }

    return($EXIT_OK);
}


sub uos_rewrite_samba_conf
{
    my ($ofh, $nfh) = @_;

    my $parameter = "passdb backend = smbpasswd";
    my $parameter2 = "smb passwd file = /etc/samba/smbpasswd";

    #
    # Copy all lines from old to new, but after the global section dec,
    # write the new parameter into the new conf file.
    #
    while (<$ofh>) {
	if (/^\s*\[global\]/) {
	    print {$nfh} $_;
	    print {$nfh} "#Following lines added by $PROGNAME, $CVS_REVISION, $TIMESTAMP\n";
	    print {$nfh} "$parameter\n";
	    print {$nfh} "$parameter2\n";
	    next;
	}
	else {
	    print {$nfh} $_;
	}
    }

    return(1);
}


sub uos_edit_samba_conf
{
    my ($conf_file) = @_;

    my $rc = 0;

    my $new_conf_file = "$conf_file.$$";

    if (open(my $ofh, '<', $conf_file)) {
	if (open(my $nfh, '>', $new_conf_file)) {
	    if (uos_rewrite_samba_conf($ofh, $nfh)) {
		$rc = 1;
	    }
	    else {
		logerror("[samba edit conf] could not rewrite conf file: $conf_file");
	    }
	    close($nfh);
	}
	else {
	    logerror("[samba edit conf] could not open file for write: $new_conf_file");
	}
	close($ofh);
    }
    else {
	logerror("[samba edit conf] could not open file for read: $conf_file");
    }

    # if the config file was successfully rewritten, and now
    # that the files are closed, the rename can be attempted.
    if ($rc) {
	$rc = uos_rename_conf($new_conf_file, $conf_file);
    }

    unlink $new_conf_file if (-f $new_conf_file);

    return($rc);
}


#
# configure the samba "passdb backend"  parameter to a value of
# "smbpasswd" in the samba config file.  This is a "global" parameter.
# This must be done for RHEL6 systems to be backwards compatabile
# with the way the pre-RHEL6 systems were configured.
#
# returns
#   $EXIT_OK on success
#   non-zero if error
#
sub uos_configure_samba_passdb
{
    my $conf_file = uos_pathto_samba_conf();

    my $rc = $EXIT_OK;

    # it's an error if samba file does not exist
    unless (-f $conf_file) {
	showerror("[config samba passdb] samba config file does not exist: $conf_file");
	return($EXIT_SAMBA_CONF);
    }

    # do nothing if a modified conf file is already in place.
    my $parameter = "passdb backend = smbpasswd";
    if (ost_util_fgrep($conf_file, $parameter) == 0) {
	showinfo("[config samba passdb] samba config file already modified: $conf_file");
	return($EXIT_OK);
    }

    if (uos_edit_samba_conf($conf_file)) {
	showinfo("[config samba passdb] samba passdb configured in: $conf_file");

	# restart the system service
	if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	    system("/sbin/service smb restart");
	}
	if ($OS eq 'RHEL7') {
	    system("/bin/systemctl restart smb");
	}
	showinfo("[config samba passdb] samba system service restarted");
    }
    else {
	showerror("[config samba passdb] could not configure samba passdb in: $conf_file");
	$rc = $EXIT_SAMBA_CONF;
    }

    return($rc);
}


#
# Copy all lines from old to new, but adjust the UID field if necessary.
#
# The structure of an smbpasswd entry is:
#
# username:uid:lanman_hash:nt_hash:flags:pw_lct
#
# username    - the user's login name.
# uid         - the user's UID
# lanman_hash - Windows stuff
# nt_hash     - Windows stuff
# flags       - Various single-character flags representing the type and
#               state of the user's account.
# pw_lct      - the timestamp of the user's last successful password change
#
sub uos_rewrite_samba_passdb
{
    my ($ofh, $nfh) = @_;

    my $rc = 1;

    while (my $line = <$ofh>) {
	if ($line =~ /^(\S+):(\d+):(.*)$/) {
	    my $username = $1;
	    my $uid = $2;
	    my $remainder = $3;

	    my $system_uid = getpwnam($username);
	    if (defined($system_uid)) {
		if ($uid ne $system_uid) {
		    $line = "$username" . ":" . "$system_uid" . ":" . "$remainder" . "\n";
		}
	    }
	}
	print($nfh $line);
    }

    return($rc);
}


sub uos_edit_samba_passdb
{
    my ($conf_file) = @_;

    my $rc = 0;

    my $new_conf_file = "$conf_file.$$";

    if (open(my $ofh, '<', $conf_file)) {
	if (open(my $nfh, '>', $new_conf_file)) {
	    if (uos_rewrite_samba_passdb($ofh, $nfh)) {
		$rc = 1;
	    }
	    else {
		logerror("[samba edit passdb] could not rewrite conf file: $conf_file");
	    }
	    close($nfh);
	}
	else {
	    logerror("[samba edit passdb] could not open file for write: $new_conf_file");
	}
	close($ofh);
    }
    else {
	logerror("[samba edit passdb] could not open file for read: $conf_file");
    }

    # if the config file was successfully rewritten, and now
    # that the files are closed, the rename can be attempted.
    if ($rc) {
	$rc = uos_rename_conf($new_conf_file, $conf_file);
    }

    unlink $new_conf_file if (-f $new_conf_file);

    return($rc);
}


#
# Make the UIDs in the "smbpasswd" file match those in /etc/passwd.
#
# returns
#   $EXIT_OK on success
#   non-zero on error
#
sub uos_rebuild_samba_passdb
{
    my $conf_file = uos_pathto_samba_password();

    if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	unless (-e $conf_file) {
	    $conf_file = "/var/lib/samba/private/smbpasswd";
	}
    }

    unless (-f $conf_file) {
	showerror("[samba rebuild passdb] config file does not exist: $conf_file");
	return($EXIT_SAMBA_CONF);
    }

    my $rc = $EXIT_OK;

    if (uos_edit_samba_passdb($conf_file)) {
	showinfo("[samba rebuild passdb] samba passdb file rebuilt: $conf_file");
    }
    else {
	showerror("[samba rebuild passdb] could not rebuild samba passdb file: $conf_file");
	$rc = $EXIT_SAMBA_PASSDB;
    }

    return($rc);
}


sub uos_service_status
{
    my ($servicename) = @_;
    my $retval = "";
    my $running_re = ' is running\.\.\.';

    if (open(my $pipe, '-|', "/sbin/service $servicename status")) {
	while (<$pipe>) {
	    chomp;
	    if (/$running_re/) {
		$retval = "running";
		last;
	    }
	}
	close($pipe);
    }

    return($retval);
}


#
# enable the the Samba system service ("smb") and start it.
#
# returns
#   1 on succes
#   0 if error
#
sub uos_config_samba_service
{
    my $rc = 1;

    my $service_name = 'smb';

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	system("/sbin/chkconfig $service_name on");
	my $service_status = uos_service_status($service_name);
	if ($service_status ne "running") {
	    system("/sbin/service $service_name start");
	}
    }
    elsif ($OS eq 'RHEL7') {
	my $sys_ctl_cmd = '/bin/systemctl';
	system("$sys_ctl_cmd -q is-enabled $service_name");
	if ($? != 0) {
	    system("$sys_ctl_cmd enable $service_name");
	    if ($? == 0) {
		loginfo("[config samba service] system service enabled: $service_name");
	    }
	    else {
		logerror("[config samba service] could not enable system service: $service_name");
	    }
	}
	system("$sys_ctl_cmd -q is-active $service_name");
	if ($? != 0) {
	    system("$sys_ctl_cmd start $service_name");
	    if ($? == 0) {
		loginfo("[config samba service] system service started: $service_name");
	    }
	    else {
		logerror("[config samba service] could not start system service: $service_name");
	    }
	}
    }
    else {
	logerror("[config samba service] unsupported platform: $OS");
	$rc = 0;
    }

    return($rc);
}


# restart the Samba system service
#
# returns
#   1 on success
#   0 if error
#
sub uos_restart_samba_service
{
    my $rc = 1;

    my $service_name = 'smb';
    my $exit_status = 1;

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	$exit_status = system("/sbin/service $service_name restart");
    }
    elsif ($OS eq 'RHEL7') {
	$exit_status = system("/bin/systemctl restart $service_name");
    }
    else {
	logerror("[restart samba service] unsupported platform: $OS");
    }

    $rc = 0 if ($exit_status != 0);

    return($rc);
}


sub uos_emit_rti_samba_conf
{
    my $samba_conf_body = q{
#
#======================= Global Settings =====================================
[global]


server string = RTI Server
hosts allow = 192.168. 127. 10. 172.16.
domain master = no
local master = no
preferred master = no
os level = 0
dns proxy = no
smb ports = 139,445
log file = /var/log/samba/%m.log
max log size = 50
socket options = TCP_NODELAY SO_RCVBUF=8192 SO_SNDBUF=8192
idmap uid = 16777216-33554431
idmap gid = 16777216-33554431
username map = /etc/samba/smbusers
passdb backend = smbpasswd
smb passwd file = /etc/samba/smbpasswd
security = user
server signing = auto



#======================= Printer Settings =====================================
printcap name = /etc/printcap
cups options = raw

[printers]
	comment = All Printers
	path = /var/spool/samba
	browseable = no
	printable = yes

#======================= Shares =====================================
[odbc_dict]
	comment = ODBC Data Dictionary
	path = /usr2/bbx/odbc_dict
	writeable = yes
	guest ok = yes
[mapping]
        comment = Mapping
        path = /usr2/bbx/delivery
        writeable = yes
        guest ok = yes
	create mask = 0666
[tmp]
        comment = Temporary Files
        path = /tmp
        writeable =  yes
   	read only = no
   	public = yes
        guest ok = yes
[wirerec]
        comment = Wire Service Reconciliations
        path = /usr2/bbx/bbxtmp
        read only = no
        guest ok = no

[reports]
        comment = RTI Reports
        path = /usr2/bbx/reports
        read only = no
        guest ok = no

    };

    return($samba_conf_body);
}


sub uos_emit_daisy_samba_conf
{
    my $samba_conf_body = q{
#
#======================= Global Settings =====================================
[global]

workgroup = daisy
server string = daisyhost
netbios name = daisyhost
hosts allow = 192.168. 127. 10. 172.16.
writable = yes
domain master = no
local master = no
preferred master = no
os level = 0
dns proxy = no
smb ports = 139,445
log file = /var/log/samba/%m.log
max log size = 50
socket options = TCP_NODELAY SO_RCVBUF=8192 SO_SNDBUF=8192
idmap uid = 16777216-33554431
idmap gid = 16777216-33554431
username map = /etc/samba/smbusers
guest account = daisy
encrypt passwords = yes
passdb backend = smbpasswd
smb passwd file = /etc/samba/smbpasswd
security = user
server signing = auto


#======================= Printer Settings =====================================
printcap name = /etc/printcap
cups options = raw

[printers]
	comment = All Printers
	path = /var/spool/samba
	browseable = yes
	guest ok = yes
	writeable = no
	printable = yes
	public = yes
	

#======================= Shares =====================================

[homes]
	comment = Home Directories
	browseable = no
        writable = no

[export]
        comment = Daisy share
        path = /d/daisy/export
        writable = yes
	browseable = yes
	guest ok = yes
	printable = no
	public = yes

    };

    return($samba_conf_body);
}


sub uos_emit_samba_header
{
    my $samba_conf_header = "# RTI Samba Configuration\n";
    $samba_conf_header .= "# Automatically generated by $PROGNAME $CVS_REVISION $TIMESTAMP\n";
    $samba_conf_header .= "#\n";

    return($samba_conf_header);
}


#
# generate a completely new Samba config file.
#
# returns
#   $EXIT_OK on success
#   non-zero if error
#
sub uos_generate_samba_config
{
    my ($conf_file, $pos_type) = @_;

    unless ($pos_type eq $POS_TYPE_RTI || $pos_type eq $POS_TYPE_DAISY) {
	$pos_type = '(null)' if ($pos_type eq $EMPTY_STR);
	showerror("[gen samba conf] unsupported POS type: $pos_type");
	return($EXIT_SAMBA_CONF);
    }

    unless (-f $conf_file) {
	showerror("[gen samba conf] Samba config file does not exist: $conf_file");
	return($EXIT_SAMBA_CONF);
    }

    my $rc = $EXIT_OK;

    # generate RTI or Daisy Samba config
    my $search_term = ($pos_type eq $POS_TYPE_RTI) ? 'usr2' : 'daisy';

    # Do nothing if a modified conf file is already in place.
    if (ost_util_fgrep($conf_file, $search_term) == 0) {
	loginfo("[gen samba conf] Samba config file already modified: $conf_file");
    }
    else {
	if (open(my $nfh, '>', $conf_file)) {
	    print {$nfh} uos_emit_samba_header();
	    if ($pos_type eq $POS_TYPE_RTI) {
		print {$nfh} uos_emit_rti_samba_conf();
	    }
	    if ($pos_type eq $POS_TYPE_DAISY) {
		print {$nfh} uos_emit_daisy_samba_conf();
	    }
	    close($nfh);

	    my $service_name = 'smb';
	    loginfo("[gen samba conf] generated new Samba config file: $service_name");

	    if (uos_restart_samba_service()) {
		loginfo("[gen samba conf] system service restarted: $service_name");
	    }
	    else {
		logerror("[gen samba conf] could not restart system service: $service_name");
		$rc = $EXIT_SAMBA_CONF;
	    }
	}
	else {
	    showerror("[gen samba conf] could not open Samba config file: $conf_file");
	    return($EXIT_SAMBA_CONF);
	}
    }

    return($rc);
}


#
# given the full path to a kernel file, find the name of the
# corresponding rpm and remove the rpm.
#
# returns
#   1 on success
#   0 if error
#
sub uos_remove_kernel_rpm
{
    my ($kernel_file) = @_;

    my $rc = 1;

    if (-e $kernel_file) {
	if (open(my $rpmfh, '-|', "rpm -qf $kernel_file")) {
	    while (my $rpm_name = <$rpmfh>) {
		chomp($rpm_name);
		system("rpm -e $rpm_name");
		if ($? != 0) {
		    logerror("[remove kernel rpm] could not remove rpm for: $kernel_file");
		    $rc = 0;
		}
	    }
	    close($rpmfh);
	}
	else {
	    logerror("[remove kernel rpm] could not get rpm name for: $kernel_file");
	    $rc = 0;
	}
    }

    return($rc);
}


#
# keep the "n" most recent kernels, where "n" == $keepkernels.
# remove all older kernels.
#
# returns
#   $EXIT_OK on success
#   non-zero if error
#
sub uos_purge_rpms
{
    my ($keepkernels) = @_;

    my $bootdir = '/boot';
    my $kernels = "$bootdir/vmlinuz-*";

    my $rc = $EXIT_OK;

    # list kernels newest first
    if (open(my $filesfh, '-|', "ls -dt $kernels 2>/dev/null")) {
	my $keepcount = 0;
	while (my $kernel_file = <$filesfh>) {
	    chomp($kernel_file);

	    # skip rescue kernel
	    next if ($kernel_file =~ m/vmlinuz.*-rescue.*/);

	    # skip specified number of kernels
	    if ($keepcount < $keepkernels) {
		if ($VERBOSE) {
		    showinfo("[purge rpms] kernel not purged: $kernel_file");
		}
		$keepcount++;
		next;
	    }

	    if ($VERBOSE) {
		showinfo("[purge rpms] keep kernel counter reached: $keepkernels");
	    }

	    if (uos_remove_kernel_rpm($kernel_file)) {
		showinfo("[purge rpms] kernel rpm purged for: $kernel_file");
	    }
	    else {
		showerror("[purge rpms] could not purge kernel rpm for: $kernel_file");
		$rc = $EXIT_PURGE_KERNEL_RPM;
	    }
	}
	close($filesfh);
    }

    return($rc);
}


#
# Sort of a "post install" set of steps for a new server.
#
sub uos_baremetal_install
{
	showinfo("[baremetal] obtaining a Red Hat License...");

	# no registration required for CentOS
	system("grep Cent /etc/redhat-release > /dev/null 2> /dev/null");
	if ($? == 0) {
	    showinfo("CentOS does not need to register.");
	}

	# required for Red Hat
	else {

	    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {

		# first check to see if already registered
		my $sub_mgr_status = sub_mgr_get_status();
		if ($sub_mgr_status eq 'Current') {
		    loginfo("[baremetal] already registered: status: $sub_mgr_status");
		}

		# not registered, try to register
		elsif (sub_mgr_register()) {
		    showinfo("[baremetal] system registered via subscription manager");
		    my $sub_mgr_id = sub_mgr_get_system_identity();
		    if ($sub_mgr_id) {
			showinfo("[baremetal] Red Hat subscription manager id: $sub_mgr_id");
		    }
		    else {
			showerror("[baremetal] system does not have Red Hat subscription manager id");
			return($EXIT_RHN_NOT_REGISTERED);
		    }
		}

		# registrations failed
		else {
		    showerror("[baremetal] could not register system via subscription manager");
		}
	    }
	}

	showinfo("[baremetal] configuring System...");

	remount_filesystem("/", "/");

	remount_swap();

	loginfo("[baremetal] root and swap files systems remounted");

	# if nmap is not installed, install it now
	system("rpm -qa | grep -q nmap");
	if ($? != 0) {
	    system("yum install -y nmap");
	}

	# pre-systemd: set default run level in inittab
	if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	    uos_configure_default_runlevel();
	}
	# systemd: set default target to multi-user
	if ($OS eq 'RHEL7') {
	    uos_configure_default_target();
	}

	# configure MOTD
	uos_modify_motd();

	# adjust some limits for CUPS
	uos_configure_cups();

	#
	# Set the kernel log message priority threshold - only messages
	# at the threshold or of greater priority are allowed to appear
	# on the console.  The priority will either be the value specified
	# on the command line or a default value.
	#
	my $klog_msg_priority = ($KLOG_MSG_PRIORITY != -1) ?
	    $KLOG_MSG_PRIORITY : $KLOG_MSG_PRIORITY_DEF;

	uos_configure_klog_msg_priority($klog_msg_priority);

	#
	# For RHEL6 systems:
	#   Edit grub.conf:
	#   1) init the console rez
	#   2) enable verbose boot msgs by removing "rhgb" and "quiet"
	#   3) disable kernel (video) mode setting
	#   Also:
	#   1) uninstall readahead rpm
	#
	if ($OS eq 'RHEL6') {
	    init_console_res();
	    enable_boot_msgs();
	    disable_kms();
	    uninstall_readahead();
	}

	#
	# For RHEL7 systems:
	#   1) configure grub2: enable verbose boot msgs by removing "rhgb" and "quiet"
	#   2) configure grub2: init the console rez
	#   3) configure grub2: disable kernel (video) mode setting
	#
	if ($OS eq 'RHEL7') {
	    uos_configure_grub2();
	}


	if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	    uos_install_apcupsd();
	}

	if ($OS eq 'RHEL7') {
	    if (uos_configure_ntp()) {
		loginfo("[baremetal] system configured to use NTP");
	    }
	}

	# set default system password hash function
	uos_configure_default_password_hash();

	return($EXIT_OK);
}


sub uos_java_package_name
{
    my ($java_version) = @_;

    my $jre_arch = "";
    my $jre_pkg = "";

    if ($ARCH eq "i386") {
	$jre_arch = "i586";
    }
    elsif ($ARCH eq "x86_64") {
	$jre_arch = "x64";
    }
    else {
	showerror("Can't happen: unsupported ARCH: $ARCH");
    }

    if ($jre_arch) {
	$jre_pkg = "jre-" . $java_version . "-linux-" . $jre_arch . "-rpm.bin";
    }

    return($jre_pkg);
}


#
# download the Java JRE.  If the package is already downloaded,
# don't download it again.
#
# returns
#   1 on success
#   0 if error
#
sub uos_java_download
{
    my ($jre_dir, $jre_pkg) = @_;

    my $rc = 1;

    my $jre_path = "$jre_dir/$jre_pkg";

    unless (-f $jre_path) {
	# Curl options:
	# -f : set exit value on failure
	# -s : no progress indication
	my $curl_fail = "-f";
	my $curl_silent = ($VERBOSE) ? "" : "-s";
	my $curl_opts = "$curl_fail $curl_silent";
	my $curl_cmd = "curl $curl_opts -o $jre_path http://$TFSERVER/ks/$jre_pkg";
	if ($DRY_RUN) {
	    system("echo $curl_cmd");
	}
	else {
	    system("$curl_cmd");
	    if ($? != 0) {
	    }
	}
    }

    return($rc);
}


#
# install the Java JRE
#
# returns
#   1 on success
#   0 if error
#
sub uos_java_install
{
    my ($jre_dir, $jre_pkg) = @_;

    my $rc = 1;

    my $jre_path = "$jre_dir/$jre_pkg";

    if ($DRY_RUN) {
	system("echo chmod a+rx $jre_path");
	system("echo $jre_path");
    }
    else {
	if (-f $jre_path) {
	    system("rm -rf /tmp/updateos.$$");
	    system("mkdir /tmp/updateos.$$");
	    system("chmod a+rx $jre_path");
	    system("cd /tmp/updateos.$$ && $jre_path");
	    if ($? != 0) {
		logerror("[java install] could not install Java JRE: $jre_pkg");
		$rc = 0;
	    }
	    else {
		system("rm -rf /tmp/updateos.$$");
	    }
	}
	else {
	    logerror("[java install] the Java JRE package does not exist: $jre_pkg");
	    $rc = 0;
	}
    }

    return($rc);
}


#
# download Java JRE and install it.
#
# returns
#   1 on success
#   0 if error
#
sub uos_java_download_install
{
    my ($java_version) = @_;

    my $rc = 1;

    my $jre_dir = '/tmp';

    my $jre_pkg = uos_java_package_name($java_version);
    if ($jre_pkg) {
	showinfo("[java download install] Java JRE version to download: $jre_pkg");
	if (uos_java_download($jre_dir, $jre_pkg)) {
	    showinfo("[java download install] Java JRE downloaded: $jre_pkg");
	    if (uos_java_install($jre_dir, $jre_pkg)) {
		showinfo("[java download install] Java JRE installed: $jre_pkg");
	    }
	    else {
		logerror("[java download install] could not install Java JRE: $jre_pkg");
		$rc = 0;
	    }
	}
	else {
	    logerror("[java download install] could not download Java JRE: $jre_pkg");
	    $rc = 0;
	}
    }
    else {
	logerror("[java download install] could not get Java JRE package name");
	$rc = 0;
    }

    return($rc);
}


#
# determine the size of system memory, and then calculate what
# the maximum java heap size should be, aka. the "xmx" value.
#
# returns
#   max heap size as string 
#
sub uos_java_max_heap_size
{
    my ($meminfo_file) = @_;

    my $xmx = "512m";

    if (open(my $memfh, '<', $meminfo_file)) {
	while (<$memfh>) {
	    chomp;

	    # line from /proc/meminfo looks like this:
	    # MemTotal:        1884488 kB
	    if (/MemTotal:/) {
		my ($mem_label, $mem_size, $mem_suffix) = split(/\s+/);

		# Less than a gig of memory
		if (int($mem_size) < 1000000) {
		    $xmx = "512m";
		}

		# Betweeen 1GB and 2GB
		elsif ( (int($mem_size) > 1000000) && (int($mem_size) < 2000000) ) {
		    $xmx = "768m";
		}

		# Betweeen 2GB and 3GB
		elsif ( (int($mem_size) > 2000000) && (int($mem_size) < 3000000) ) {
		    $xmx = "1024m";
		}

		# Betweeen 3GB and 4GB
		elsif ( (int($mem_size) > 3000000) && (int($mem_size) < 4000000) )  {
		    $xmx = "1536m";
		}

		# 4GB ++
		else {
		    $xmx = "2048m"
		}
	    }
	}
	close($memfh);
    }
    else {
	logerror("[java mem size] could not open for read: $meminfo_file");
    }

    return($xmx);
}


sub uos_bbj_gen_settings_file
{
    my ($bbj_settings_file) = @_;

    my $rc = 1;

    if (open(my $bbjfh, '>', $bbj_settings_file)) {
	print {$bbjfh} "-V LICENSE_ACCEPT_BUTTON=\"true\"\n";
	print {$bbjfh} "-V LICENSE_REJECT_BUTTON=\"false\"\n";
	print {$bbjfh} "-P installLocation=\"/usr2/basis/\"\n";
	print {$bbjfh} "-V IS_SELECTED_INSTALLATION_TYPE=custom\n";
	print {$bbjfh} "-P BBjFtrBean.active=true\n";
	print {$bbjfh} "-P BBjThinClientFtr_bean.active=true\n";
	print {$bbjfh} "-P BBjSvcs_FtrBean.active=true\n";
	print {$bbjfh} "-P BBjEUTFtr_bean.active=true\n";
	print {$bbjfh} "-P EMFeatureBean.active=true\n";
	print {$bbjfh} "-P adminFeatureBean.active=true\n";
	print {$bbjfh} "-P BBjUtilsFtr_bean.active=true\n";
	print {$bbjfh} "-P GMLFeatureBean.active=true\n";
	print {$bbjfh} "-P BWUFeatureBean.active=true\n";
	print {$bbjfh} "-P STDFeatureBean.active=true\n";
	print {$bbjfh} "-P EXTFeatureBean.active=true\n";
	print {$bbjfh} "-P MKRecoverFeatureBean.active=true\n";
	print {$bbjfh} "-P AutoLicFeatureBean.active=true\n";
	print {$bbjfh} "-P CLlibFeatureBean.active=true\n";
	print {$bbjfh} "-P JLlibFeatureBean.active=true\n";
	print {$bbjfh} "-P BBjDevelToolsFtr_bean.active=true\n";
	print {$bbjfh} "-P perfAnalyzerFeatureBean.active=false\n";
	print {$bbjfh} "-P compilerListerFeatureBean.active=true\n";
	print {$bbjfh} "-P configuratorFeatureBean.active=false\n";
	print {$bbjfh} "-P guiBuilderFeatureBean.active=false\n";
	print {$bbjfh} "-P blmFeatureBean.active=true\n";
	print {$bbjfh} "-P BLMadminFeatureBn.active=true\n";
	print {$bbjfh} "-P basisIDEfeatureBean.active=false\n";
	print {$bbjfh} "-P documentationFeatureBean.active=false\n";
	print {$bbjfh} "-P jdbcFeatureBean.active=true\n";
	print {$bbjfh} "-P TrainingfeatureBean.active=true\n";
	print {$bbjfh} "-P DemosBean.active=true\n";
	print {$bbjfh} "-P BaristafeatureBean.active=false\n";
	print {$bbjfh} "-P AddOnfeatureBean.active=false\n";

	close($bbjfh);
    }
    else {
	logerror("[gen bbj settings] could not open BBJ settings file for write: $bbj_settings_file");
	$rc = 0;
    }

    return($rc);
}


#
# return a multi-line string which represents the contents of
# the BBJ properties file.
#
# returns
#   string with file content
#
sub uos_bbj_properties_file_content
{
    # get appropriate value of Java "-Xmx" option
    my $xmx = uos_java_max_heap_size($LINUX_PROC_MEMINFO);

    my $content = "# BBj Properties File\n";
    $content .= "# This file auto-generated by $PROGNAME $CVS_REVISION $TIMESTAMP\n";
    $content .= "# This file auto-generated on date: " . localtime() . "\n";
    $content .= "#\n";
    $content .= "#\n";

    $content .= "#BBj Services Properties\n";
    $content .= "basis.cacheDirectory=/usr2/basis/cache\n";
    $content .= "basis.java.args.BBjCpl=-XX\\:NewSize\\=24m -client\n";
    $content .= "basis.java.args.BBjLst=-XX\\:NewSize\\=24m -client\n";

    $content .= "basis.java.args.BBjServices=-Xmx$xmx -Xms256m ";

    $content .= "-XX\\:MaxPermSize\\=96m -XX\\:NewSize\\=64m -XX\\:+UseConcMarkSweepGC -XX\\:+CMSIncrementalMode -XX\\:CMSIncrementalSafetyFactor\\=20 -XX\\:CMSInitiatingOccupancyFraction\\=70 -XX\\:MaxTenuringThreshold\\=4 -XX\\:SurvivorRatio\\=14 -server -XX\\:CompileCommandFile\\=/usr2/basis/cfg/.hotspot_compiler -Dnetworkaddress.cache.ttl\\=10 -Dsun.net.inetaddr.ttl\\=10 -Djava.awt.headless\\=true -verbose\\:gc -Xloggc\\:/usr2/basis/log/gc.log -XX\\:+PrintGCDetails -XX\\:+PrintGCTimeStamps -XX\\:+PrintGCApplicationConcurrentTime -XX\\:+PrintGCApplicationStoppedTime\n";

    $content .= "basis.java.args.BasisIDE=-XX\\:CompileCommandFile\\=/usr2/basis//cfg/.hotspot_compiler\n";
    $content .= "basis.java.args.Default=-Xmx128m -Xms128m -XX\\:NewRatio\\=4 -XX\\:MaxPermSize\\=128m -XX\\:NewSize\\=24m -client -XX\\:CompileCommandFile\\=/usr2/basis//cfg/.hotspot_compiler\n";
    $content .= "basis.java.classpath=/usr2/basis//lib/BBjUtil.jar\\:/usr2/basis//lib/BBjIndex.jar\\:/usr2/basis//lib/FontChooser.jar\\:/usr2/basis//lib/DemoClientFiles.jar\\:/usr2/basis//lib/ClientObjects.jar\\:/usr2/basis//lib/examples.jar\\:/usr2/basis//lib/jfreechart-experimental.jar\\:/usr2/basis//lib/jna.jar\\:/usr2/basis//lib/swingx.jar\\:/usr2/basis//lib/TimingFramework.jar\\:/usr/java/latest/lib/ext/jdic_stub_unix.jar\n";
    $content .= "basis.java.jvm.BBjServices=/usr/java/latest/bin/java\n";
    $content .= "basis.java.jvm.Default=/usr/java/latest/bin/java\n";
    $content .= "basis.java.skin=\n";
    $content .= "basis.pdf.fontpath=\n";
    $content .= "com.basis.bbj.bridge.BridgeServer.bindAddr=0.0.0.0\\:2007\n";
    $content .= "com.basis.bbj.bridge.BridgeServer.maxClients=100\n";
    $content .= "com.basis.bbj.bridge.BridgeServer.start=false\n";
    $content .= "com.basis.bbj.comm.FacadeFactory.suppressClientObjErrorsOnVoidMethods=true\n";
    $content .= "com.basis.bbj.comm.InterpreterServer.backLog=110\n";
    $content .= "com.basis.bbj.comm.InterpreterServer.bindAddr=127.0.0.1\:2005\n";
    $content .= "com.basis.bbj.comm.InterpreterServer.maxClients=500\n";
    $content .= "com.basis.bbj.comm.InterpreterServer.start=false\n";
    $content .= "com.basis.bbj.comm.PortRequestServer.bindAddr=127.0.0.1\\:2008\n";
    $content .= "com.basis.bbj.comm.PortRequestServer.maxClients=500\n";
    $content .= "com.basis.bbj.comm.PortRequestServer.start=true\n";
    $content .= "com.basis.bbj.comm.ProxyManagerServer.bindAddr=127.0.0.1\\:2009\n";
    $content .= "com.basis.bbj.comm.ProxyManagerServer.maxClients=100\n";
    $content .= "com.basis.bbj.comm.ProxyManagerServer.start=false\n";
    $content .= "com.basis.bbj.comm.RuntimeMgr.notifyUserOnInternalError=false\n";
    $content .= "com.basis.bbj.comm.RuntimeMgr.releaseOnLostConnection=true\n";
    $content .= "com.basis.bbj.comm.RuntimeMgr.requireAllSendMsgResponses=false\n";
    $content .= "com.basis.bbj.comm.RuntimeMgr.suppressPrinterAckBack=true\n";
    $content .= "com.basis.bbj.comm.RuntimeMgr.suppressUIAckBack=true\n";
    $content .= "com.basis.bbj.comm.RuntimeMgr.useDvkLicenseIfPresent=true\n";
    $content .= "com.basis.bbj.comm.SecureThinClientServer.backLog=110\n";
    $content .= "com.basis.bbj.comm.SecureThinClientServer.bindAddr=0.0.0.0\\:2103\n";
    $content .= "com.basis.bbj.comm.SecureThinClientServer.disallowConsole=true\n";
    $content .= "com.basis.bbj.comm.SecureThinClientServer.maxClients=500\n";
    $content .= "com.basis.bbj.comm.SecureThinClientServer.start=true\n";
    $content .= "com.basis.bbj.comm.SecureThinClientServer.webUser=rti\n";
    $content .= "com.basis.bbj.comm.TerminalServer.backLog=110\n";
    $content .= "com.basis.bbj.comm.TerminalServer.bindAddr=127.0.0.1\\:2004\n";
    $content .= "com.basis.bbj.comm.TerminalServer.maxClients=500\n";
    $content .= "com.basis.bbj.comm.TerminalServer.start=true\n";
    $content .= "com.basis.bbj.comm.ThinClientProxyServer.backLog=110\n";
    $content .= "com.basis.bbj.comm.ThinClientProxyServer.bindAddr=127.0.0.1\\:2006\n";
    $content .= "com.basis.bbj.comm.ThinClientProxyServer.err=/usr2/basis/log/ThinClientProxyServer.err\n";
    $content .= "com.basis.bbj.comm.ThinClientProxyServer.keepLogs=7\n";
    $content .= "com.basis.bbj.comm.ThinClientProxyServer.maxClients=500\n";
    $content .= "com.basis.bbj.comm.ThinClientProxyServer.out=/usr2/basis/log/ThinClientProxyServer.out\n";
    $content .= "com.basis.bbj.comm.ThinClientProxyServer.sizeM=10\n";
    $content .= "com.basis.bbj.comm.ThinClientProxyServer.start=false\n";
    $content .= "com.basis.bbj.comm.ThinClientProxyServer.waitTime=0\n";
    $content .= "com.basis.bbj.comm.ThinClientServer.backLog=110\n";
    $content .= "com.basis.bbj.comm.ThinClientServer.bindAddr=0.0.0.0\\:2003\n";
    $content .= "com.basis.bbj.comm.ThinClientServer.disallowConsole=true\n";
    $content .= "com.basis.bbj.comm.ThinClientServer.encryptConnection=true\n";
    $content .= "com.basis.bbj.comm.ThinClientServer.maxClients=500\n";
    $content .= "com.basis.bbj.comm.ThinClientServer.start=false\n";
    $content .= "com.basis.bbj.comm.ThinClientServer.translateAppletCmdLine=false\n";
    $content .= "com.basis.bbj.comm.ThinClientServer.translateCmdLine=false\n";
    $content .= "com.basis.bbj.comm.ThinClientServer.webUser=rti\n";
    $content .= "com.basis.bbj.serverPinning=true\n";
    $content .= "com.basis.bbj.sessionPinning=false\n";
    $content .= "com.basis.filesystem.localPort=2000\n";
    $content .= "com.basis.filesystem.localServer=127.0.0.1\n";
    $content .= "com.basis.filesystem.remote.securedataserver.encrypter=com.basis.filesystem.remote.securedataserver.DefaultEncrypter\n";
    $content .= "com.basis.server.LookAndFeel=default\n";
    $content .= "com.basis.server.admin.1.defaultPort=2002\n";
    $content .= "com.basis.server.admin.1.interface=0.0.0.0\n";
    $content .= "com.basis.server.admin.1.start=true\n";
    $content .= "com.basis.server.admin.1.useSSL=false\n";
    $content .= "com.basis.server.admin.log=/usr2/basis/log/AdminServer.log\n";
    $content .= "com.basis.server.allowPipe=true\n";
    $content .= "com.basis.server.autorun.config=/usr2/bbx/config/config.bbx\n";
    $content .= "com.basis.server.autorun.user=root\n";
    $content .= "com.basis.server.autorun.workingDirectory=/usr2/bbx/\n";
    $content .= "com.basis.server.configDirectory=/usr2/bbx/config\n";
    $content .= "com.basis.server.exclusiveAccess=true\n";
    $content .= "com.basis.server.filesystem.1.defaultPort=2000\n";
    $content .= "com.basis.server.filesystem.1.defaultTimeout=2000\n";
    $content .= "com.basis.server.filesystem.1.interface=0.0.0.0\n";
    $content .= "com.basis.server.filesystem.1.prefixes=\n";
    $content .= "com.basis.server.filesystem.1.start=true\n";
    $content .= "com.basis.server.filesystem.1.useSSL=true\n";
    $content .= "com.basis.server.filesystem.log=/usr2/basis/log/FilesystemServer.log\n";
    $content .= "com.basis.server.memStatFrequence=15\n";
    $content .= "com.basis.server.nio.override=false\n";
    $content .= "com.basis.server.passwordAuth=false\n";
    $content .= "com.basis.server.pro5ds.1.64bitMKeyed=false\n";
    $content .= "com.basis.server.pro5ds.1.advisoryLocking=true\n";
    $content .= "com.basis.server.pro5ds.1.defaultPort=2100\n";
    $content .= "com.basis.server.pro5ds.1.defaultTimeout=5\n";
    $content .= "com.basis.server.pro5ds.1.interface=0.0.0.0\n";
    $content .= "com.basis.server.pro5ds.1.maskMKeyedFID=false\n";
    $content .= "com.basis.server.pro5ds.1.prefixes=\n";
    $content .= "com.basis.server.pro5ds.1.scanAllRoots=false\n";
    $content .= "com.basis.server.pro5ds.1.start=false\n";
    $content .= "com.basis.server.pro5ds.1.tagged=false\n";
    $content .= "com.basis.server.pro5ds.1.umask=0000\n";
    $content .= "com.basis.server.pro5ds.1.useSSL=true\n";
    $content .= "com.basis.server.pro5ds.log=/usr2/basis/log/Pro5DSServer.log\n";
    $content .= "com.basis.server.programCacheFile=/usr2/basis/cfg/BBjCache.txt\n";
    $content .= "com.basis.server.programCacheSize=300\n";
    $content .= "com.basis.server.resourceCacheFile=/usr2/basis//cfg/BBjResourceCache.txt\n";
    $content .= "com.basis.server.skipProgramCacheFile=true\n";
    $content .= "com.basis.server.sqlengine.1.debugLevel=2\n";
    $content .= "com.basis.server.sqlengine.1.defaultPort=2001\n";
    $content .= "com.basis.server.sqlengine.1.interface=0.0.0.0\n";
    $content .= "com.basis.server.sqlengine.1.start=true\n";
    $content .= "com.basis.server.sqlengine.1.useSSL=true\n";
    $content .= "com.basis.server.sqlengine.log=/usr2/basis/log/SQLServer.log\n";
    $content .= "com.basis.server.status.defaultPort=11057\n";
    $content .= "com.basis.server.stdErr.keepLogs=7\n";
    $content .= "com.basis.server.stdErr.sizeM=1\n";
    $content .= "com.basis.server.stdErr=/usr2/basis/log/BBjServices.err\n";
    $content .= "com.basis.server.stdOut.keepLogs=7\n";
    $content .= "com.basis.server.stdOut.sizeM=1\n";
    $content .= "com.basis.server.stdOut=/usr2/basis/log/BBjServices.out\n";
    $content .= "com.basis.server.threadPoolSize=-1\n";
    $content .= "com.basis.server.workingDirectory=/usr2/bbx/\n";
    $content .= "com.basis.sql.logLevel=0\n";
    $content .= "com.basis.user.useFork=true\n";
    $content .= "default-config=/usr2/bbx/config/config.bbx\n";
    $content .= "default-user=root\n";
    $content .= "default-working-dir=/usr2/basis/bin\n";
    $content .= "sun.arch.data.model=32\n";

    return($content);
}


sub uos_bbj_gen_properties_file
{
    my ($bbj_properties_file) = @_;

    my $rc = 1;

    if (-f $bbj_properties_file) {
	system("rm -f $bbj_properties_file");
	if ($? == 0) {
	    loginfo("[gen bbj properties] old properties file removed: $bbj_properties_file");
	}
	else {
	    logerror("[gen bbj properties] could not remove old properties file: $bbj_properties_file");
	    return(0);
	}
    }

    if (open(my $propfh, '>', $bbj_properties_file)) {

	my $file_content = uos_bbj_properties_file_content();

	print {$propfh} $file_content;

	close($propfh);
    }
    else {
	logerror("[gen bbj properties] could not open BBJ properties file for write: $bbj_properties_file");
	$rc = 0;
    }

    return($rc);
}


#
# install BBj
#
sub uos_bbj_install
{
    if (-d '/usr2/basis') {
	system("mv /usr2/basis /usr2/basis-backup");
	if ($? == 0) {
	    loginfo("[bbj install] /usr2/basis moved to /usr2/basis-backup");
	}
	else {
	    logerror("[bbj install] could not move /usr2/basis to /usr2/basis-backup");
	    return(0);
	}
    }
    else {
	loginfo("[bbj install] /usr2/basis/ did not previously exist");
    }

    showinfo("[bbj install] installing BBj...");

    if (-f "/tmp/$BBJ") {
	loginfo("[bbj install] using previously downloaded BBj: /tmp/$BBJ");
    }
    else {
	system("wget --proxy=off --cache=off -O /tmp/$BBJ http://$TFSERVER/ks/$BBJ");
	if (-f "/tmp/$BBJ") {
	    loginfo("[bbj install] download successful: http://$TFSERVER/ks/$BBJ");
	}
	else {
	    logerror("[bbj install] could not download file: http://$TFSERVER/ks/$BBJ");
	    return(0);
	}
    }

    # generate and process a BBJ settings file
    my $bbj_settings_file_path = File::Spec->catdir('/tmp', $DEF_BBJ_SETTINGS_FILE_NAME);
    if (uos_bbj_gen_settings_file($bbj_settings_file_path)) {
	if (-f "/tmp/$BBJ") {
	    my ($bbj_filename, $bbj_dirs, $bbj_suffix) = fileparse($BBJ, qr/\.[^.]*/);
	    my $bbj_unzipped_file_path = File::Spec->catdir('/tmp', $bbj_filename);
	    system("gzip -dc /tmp/$BBJ > $bbj_unzipped_file_path");
	    if ($? != 0) {
		logerror("[bbj install] could not ungzip BBJ file: /tmp/$BBJ");
	    }
	    unless (-f $bbj_unzipped_file_path) {
		logerror("[bbj install] ungzipped BBJ file does not exist: $bbj_unzipped_file_path");
	    }
	    system("java -jar $bbj_unzipped_file_path -options $bbj_settings_file_path -silent");
	    if ($? == 0) {
		loginfo("[bbj install] BBJ settings file processed: $bbj_settings_file_path");
	    }
	    else {
		logerror("[bbj install] could not process BBJ settings file: $bbj_settings_file_path");
		return(0);
	    }
	}
    }
    else {
	logerror("[bbj install] could not generate BBJ settings file: $bbj_settings_file_path");
	return(0);
    }

    # at this point, we expect certain directories to exist
    unless (-d '/usr2/basis') {
	logerror("[bbj install] required directory does not exist: /usr2/basis");
	return(0);
    }
    unless (-d '/usr2/basis/cfg') {
	system("mkdir /usr2/basis/cfg");
	if (-d '/usr2/basis/cfg') {
	    system("chmod 755 /usr2/basis/cfg");
	}
	else {
	    logerror("[bbj install] required directory does not exist: /usr2/basis/cfg");
	    return(0);
	}
    }

    # generate BBj properties file
    my $bbj_properties_file_path = uos_pathto_bbj_properties_file();

    # if there is an existing BBj properties file, save a copy
    if (-f $bbj_properties_file_path) {
	my $old_bbj_properties_file_path = $bbj_properties_file_path . '.original';
	system("mv $bbj_properties_file_path $old_bbj_properties_file_path");
	loginfo("[bbj install] previous BBj properties file saved to: $old_bbj_properties_file_path");
    }

    # generate a new BBj properties file
    if (uos_bbj_gen_properties_file($bbj_properties_file_path)) {
	showinfo("[bbj install] new BBj properties file generated: $bbj_properties_file_path");
    }
    else {
	logerror("[bbj install] could not generate new BBj properties file: $bbj_properties_file_path");
	return(0);
    }

    return(1);
}


#
# install the Basis License Manager.
#
sub uos_blm_install
{
    # generate a BLM install settings file
    my $blm_install_settings_file = "/tmp/blm-install-settings.txt";
    if (open(my $blmfh, '>',  $blm_install_settings_file)) {
	print {$blmfh} "-V LICENSE_ACCEPT_BUTTON=\"true\"\n";
	print {$blmfh} "-V LICENSE_REJECT_BUTTON=\"false\"\n";
	print {$blmfh} "-V IS_SELECTED_INSTALLATION_TYPE=typical\n";
	close($blmfh);
    }
    else {
    }

    showinfo("Installing Basis License Manager...");

    # download BLM file if not present
    unless (-f "/tmp/$BLM") {
	system("wget --proxy=off --cache=off -O /tmp/$BLM http://$TFSERVER/ks/$BLM");
	if (-f "/tmp/$BLM") {
	    loginfo("[blm install] downloaded file: http://$TFSERVER/ks/$BBJ");
	}
	else {
	    logerror("[blm install] could not download file: http://$TFSERVER/ks/$BBJ");
	}
    }

    if ( (-f "/tmp/$BLM") && (-f $blm_install_settings_file) ) {
	# form name for unzipped file
	my ($blm_filename, $blm_dirs, $blm_suffix) = fileparse($BLM, qr/\.[^.]*/);
	my $blm_unzipped_file_path = File::Spec->catdir('/tmp', $blm_filename);
	# now unzip it and process it with Java
	system("gzip -dc /tmp/$BLM > $blm_unzipped_file_path");
	system("java -jar $blm_unzipped_file_path -options $blm_install_settings_file -silent");
    }

    return(1);
}


#
# Install OS pre-requisites for RTI v14.
#
# Not being registered with RHN is not considered a fatal error
# because the RPM repository may be a CentOS repository and
# there is no registration needed.
#
sub uos_rti14_install
{
    my ($if_name) = @_;

    my $ltag = '[rti14 install]';

    # if booting "DHCP", log an error and return
    my $conf_file = "/etc/sysconfig/network-scripts/ifcfg-$if_name";
    my $pattern = ($OS eq "RHEL6" || $OS eq "RHEL7") ? 'BOOTPROTO=\"dhcp\"' : 'BOOTPROTO=dhcp';
    system("grep $pattern $conf_file > /dev/null 2> /dev/null");
    if ($? == 0) {
	    showerror("$ltag Network must be configured with static ip first");
	    return($EXIT_RTI14);
    }

    showinfo("$ltag Installing RTI v14 Software Dependencies...");
    showinfo("$ltag Using Teleflora Package Server \"$TFSERVER\"");

    remount_filesystem("/teleflora", "/usr2");

    # for RHEL7, add the "nofail" mount option
    if ($OS eq 'RHEL7') {
	my $fstab = uos_pathto_fstab();
	uos_edit_fstab($fstab, "/usr2");
    }

    # report Red Hat Network registration status
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	my $rhn_system_id = rhn_get_system_id();
	if ($rhn_system_id) {
	    showinfo("$ltag Red Hat Network system id: $rhn_system_id");
	}
	else {
	    showinfo("$ltag system not registered with Red Hat Network");
	}
    }
    if ($OS eq 'RHEL7') {
	my $sub_mgr_id = sub_mgr_get_system_identity();
	if ($sub_mgr_id) {
	    showinfo("$ltag Red Hat subscription manager id: $sub_mgr_id");
	}
	else {
	    showinfo("$ltag system does not have Red Hat subscription manager id");
	}
    }

    # install some more rpm packages (ought to be done in kickstart)
    if ($OS eq 'RHEL5' || $OS eq 'RHEL6' || $OS eq 'RHEL7') {
	my @rpms = ('fetchmail', 'ksh', 'uucp', 'httpd');
	for my $rpm_name (@rpms) {
	    if ( ($rpm_name eq 'uucp') && ($OS ne 'RHEL5') ) {
		next;
	    }

	    system("yum -y install $rpm_name");
	    if ($? == 0) {
		loginfo("$ltag installed rpm: $rpm_name");
	    }
	    else {
		showerror("$ltag could not install rpm: $rpm_name");
	    }
	}
    }

    # add standard users
    uos_rti_make_default_users();

    # configure Samba
    my $samba_conf_file = uos_pathto_samba_conf();
    if (ost_util_fgrep($samba_conf_file, 'delivery')) {
	uos_generate_samba_config($samba_conf_file, $POS_TYPE_RTI);
	loginfo("$ltag generated new Samba config file: $samba_conf_file");
    }
    uos_rti_make_default_samba_users();

    showinfo("$ltag installing Java JRE");

    # download and install Java
    if (uos_java_download_install($JAVA_VERSION)) {
	showinfo("$ltag package installed: Java JRE");
    }
    else {
	logerror("$ltag could not install package: Java JRE");
	return($EXIT_JAVA_INSTALL);
    }
	
    showinfo("$ltag installing BBj");

    # download and install BBj
    if (uos_bbj_install()) {
	showinfo("$ltag installed: BBj");
    }
    else {
	logerror("$ltag could not install: BBj");
	return($EXIT_BBJ_INSTALL);
    }

    showinfo("$ltag installing BLM");

    # download and install BLM
    if (uos_blm_install()) {
	showinfo("$ltag installed: BLM");
    }
    else {
	logerror("$ltag could not install: BLM");
	return($EXIT_BLM_INSTALL);
    }

    # Basis Admin to setup BBj in general
    showinfo("Running Basis Admin Menu...");
    system("/usr2/basis/bin/admin");

    return($EXIT_OK);
}


sub uos_rtiv12_install
{
	my ($if_name) = @_;

	showinfo("Installing RTI v12 Software Dependencies...");
	showinfo("Using Teleflora Package Server \"$TFSERVER\"");

	# if booting "DHCP", log an error and return
	my $conf_file = "/etc/sysconfig/network-scripts/ifcfg-$if_name";
	my $pattern = ($OS eq "RHEL6" || $OS eq "RHEL7") ? 'BOOTPROTO=\"dhcp\"' : 'BOOTPROTO=dhcp';
	system("grep $pattern $conf_file > /dev/null 2> /dev/null");
	if ($? == 0) {
		showerror("Network must be configured with static ip first");
		return(1);
	}

	remount_filesystem("/teleflora", "/usr2");

	if ($OS eq 'RHEL7') {
	    # add the "nofail" mount option
	    my $fstab = uos_pathto_fstab();
	    uos_edit_fstab($fstab, "/usr2");
	}

	if(! -d "/usr2/bbx/bin") {
		# This step needed to ensure update_ostools succeeds.
		system("mkdir -p /usr2/bbx/bin");
	}

	uos_rti_make_default_users();


	showinfo("Installing Additional Packages...");
	system("yum groupinstall -y mail-server");
	system("yum install -y fetchmail");
	if ($OS ne "RHEL6" && $OS ne "RHEL7") {
		system("yum install -y uucp");
	}
	system("yum install -y ksh");


	# Samba
	my $samba_conf_file = uos_pathto_samba_conf();
	if (ost_util_fgrep($samba_conf_file, 'delivery')) {
	    uos_generate_samba_config($samba_conf_file, $POS_TYPE_RTI);
	}

	uos_rti_make_default_samba_users();

	#system("/usr2/bbx/bin/rtiuser.pl --add rti");

	return(0);
}


#
# Verify that Java is already (correctly) installed.
#
# Returns
#   1 if installed
#   0 if not
#

sub is_java_already_installed
{
    my ($java_chk) = @_;

    my $java_root = '/usr/java';
    my $java_jre_dir = "$java_root/jre" . $java_chk;
    my $java_jdk_dir = "$java_root/jdk" . $java_chk;

    if (-d $java_root) {
	if (-d $java_jre_dir || -d $java_jdk_dir) {
	    my $link = readlink "$java_root/latest";
	    if (index($link, $java_root) != 0) {
		$link = $java_root . "/" . $link;
	    }
	    if ($link eq $java_jre_dir || $link eq $java_jdk_dir) {
		return(1);
	    }
	}
    }

    return(0);
}


#
#
#### Install Java
#
#

sub get_and_load_java
{
	my ($java_file) = @_;

	my $url = "http://tposlinux.blob.core.windows.net/rtibbjupdate11";

	# come on - how about using fileparse() from File::Basename
	my $java_no_gz_test = $java_file ;
	chomp $java_no_gz_test;
	my @java_no_gz=split('.gz', $java_no_gz_test);
	my $java_no_gz=$java_no_gz[$#java_no_gz];

	unless (-f "/tmp/$java_file") {
		system("wget --proxy=off --cache=off -O /tmp/$java_file $url/$java_file");
	}
	unless (-f "/tmp/$java_file") {
		logerror("Could not download file $url/$java_file");
		exit(1);
	}

	loginfo("Installing Java...");
	mysystem("chmod a+rx /tmp/$java_file");
	mysystem("mv /tmp/$java_file /usr/java/");
	mysystem("cd /usr/java/ && gunzip $java_file");
	mysystem("cd /usr/java/ && tar xvf $java_no_gz");
	mysystem("cd /usr/java/ && rm -r latest");

	# come on - using java rel embedded in ln command
	my $returnval = mysystem("cd /usr/java/ && ln -s jdk1.8.0_65 latest");
	if ($returnval != 0) {
		logerror("Java install returned non-zero exitstatus: $returnval.");
		exit($returnval);
	}

	# Normally, clean up is a "good thing", but looks like the convention
	# for this script is to leave the Java download file.
	#loginfo("Cleaning Up...");
	#mysystem("rm -f /tmp/$java_file 2>/dev/null");
}


#
# Install BBj v15
#
sub install_bbj15_packages
{
	my $line = "";

	# Install BBj
	if(-d "/usr2/basis") {
		loginfo("Moving current /usr2/basis/ to /usr2/basis-old/...");
		mysystem("rm -rf /usr2/basis-old");
		my $returnval = mysystem("cp -r /usr2/basis /usr2/basis-old");
		if($returnval != 0) {
			logerror("Terminating update_bbj with return code $returnval.");
			exit($returnval);
		}
	} else {
		loginfo("/usr2/basis/ did not previously exist...");
	}


	
	loginfo("Installing BBj v15...");
	if(! -f "/tmp/$BBJ.gz") {
		system("wget --proxy=off --cache=off -O /tmp/$BBJ.gz http://tposlinux.blob.core.windows.net/rtibbjupdate11/$BBJ.gz");
		if(! -f "/tmp/$BBJ.gz") {
			logerror("Could not download file http://tposlinux.blob.core.windows.net/rtibbjupdate11/$BBJ.gz");
			exit(1);
		}
	}
#####
#Basis license Info
####

	loginfo("Getting AuthNumber for Basis License......");
 	if (-f "//usr2/basis/blm/Register.properties")
	{
	my $authnumtest = `grep AuthNum= /usr2/basis/blm/Register.properties 2>/dev/null`;
	chomp $authnumtest;
	my @authnum=split(/\=/, $authnumtest);
	my $Auth_Number=$authnum[$#authnum];
	loginfo("Auth_Number = $Auth_Number");

	loginfo("Getting Serial Number..... ");	
	my $serialnumtest = `grep SerialNum= /usr2/basis/blm/Register.properties 2>/dev/null`;
	chomp $serialnumtest;
	my @serialnum=split(/\=/, $serialnumtest);
	my $Serial_Number=$serialnum[$#serialnum];
	loginfo("Serial Number = $Serial_Number");
	
	loginfo("Getting HostName .....");
	my $hostnametest = `grep HostName /usr2/basis/blm/Register.properties 2>/dev/null`;
	chomp $hostnametest;
	my @hostname=split(/\=/, $hostnametest);
	my $Host_Name=$hostname[$#hostname];
	loginfo("Host Name = $Host_Name");
	
	loginfo("Getting Composite.....");
	my $hostidtest = `grep HostID /usr2/basis/blm/Register.properties 2>/dev/null`;
	chomp $hostidtest;
	my @hostid=split(/ID\=/, $hostidtest);
	my $Host_ID=$hostid[$#hostid];
	loginfo("Host ID = $Host_ID");

	my $bbjinstallsettings15 = "
################################################################################
# BASIS Installation and Configuration Wizard options for BBj 11.12 and higher
#
#
# A forward slash or two back slashes should be used when specifying directories or files
# Passwords will be encrypted when recorded.
#
#
################################################################################
# Wizard Settings
#
# The following variables set whether or not to run various BASIS
# installation and configuration wizards after the installation of the software.
# Setting a value to [interactive] will cause the specified wizard to be run
# interactively. Setting a value to [silent] will cause the specified wizard to
# be run silently. Setting a value to [off] will prevent that wizard from being run.
# The UAC wizard will only be run on Windows machines in which UAC is enabled. The
# license selection and finish wizards can not be run silently.
#
# The following value can be [interactive] [silent]. The default is [interactive].
INSTALL_WIZARD=silent
# The following values can be [off] [interactive] [silent]. The default is [off].
UAC_WIZARD=off
LICENSE_SELECTION_WIZARD=silent
LICENSE_REGISTER_WIZARD=silent
LICENSE_INSTALL_WIZARD=silent
BBJ_BRAND_WIZARD=off
BBJ_CFG_STARTUP_WIZARD=silent
BBJ_START_STOP_WIZARD=silent
BLM_CFG_STARTUP_WIZARD=silent
BLM_START_STOP_WIZARD=off
EM_WIZARD=off
FINISH_WIZARD=silent
#
################################################################################
# Global Wizard Detail Settings
#
# The following value can be [en] [nl] [fr] [de] [it] [es] [sv].
# The default is the current locale language.
LANGUAGE=en
#
# The splash image can be a png or jpg and can be found in the installable jar or on disk. By default the BASIS splash image will be used.
# The following value can be [none] which will skip the splash window. A GUI environment is needed to display the splash window.
SPLASH_IMAGE=
#
################################################################################
# Install Wizard Detail Settings
#
# The following value can be [true] [false]. Default is [false].
INSTALL_LICENSE_AGREE=true
# Specifies the installation target directory
INSTALL_TARGET_DIRECTORY_NON_WIN=/usr2/basis/
# Specifies the java directory
INSTALL_JAVA_DIRECTORY_NON_WIN=/usr/java/latest/
# The following value can be [true] [false]. Default is [false].
INSTALL_CUSTOM=false
# Specifies the comma separated custom features to install. The default is to install all available features
INSTALL_CUSTOM_FEATURES=
# The following value can be [true] [false]. Default is [false].
INSTALL_WEB_START_INSTALLATION=true
# The following properties are used to configure Web Start
# Specifies if a certificate should be generated in order to sign Web Start jars. This value can be [true] [false]. Default is [true].
INSTALL_GENERATE_CERTIFICATE=true
# Specifies the company name to use when generating a Web Start certificate
INSTALL_YOUR_COMPANY_NAME=Teleflora
# Specifies the Jetty host to use when generating a Web Start certificate. By default the web server host in BBj.properties will be used if it exists, otherwise the external IP address of the machine will be used.
INSTALL_JETTY_HOST=
# Specifies the Jetty port to use when generating a Web Start certificate. By default the web server port in BBj.properties will be used if it exists, otherwise 8888 will be used.
INSTALL_JETTY_PORT=
# Specifies if a CA certificate should be used to sign Web Start jars. This value can be [true] [false]. Default is [false].
INSTALL_USE_CA_CERTIFICATE=false
# Specifies the keystore to use when using a CA certificate to sign Web Start jars.
INSTALL_KEYSTORE=
# Specifies the keystore password to use when using a CA certificate to sign Web Start jars.
INSTALL_KEYSTORE_PASSWORD=
# Specifies the private key to use when using a CA certificate to sign Web Start jars.
INSTALL_PRIVATE_KEY=
# Specifies the private key password to use when using a CA certificate to sign Web Start jars.
INSTALL_PRIVATE_KEY_PASSWORD=
# The following properties can be specified to run a BBj program at the installation finish. The variable {dollarsign}InstallDir can be used in values that contain a path to be relative to the BBj installation directory.
INSTALL_BBEXEC_PROGRAM=
INSTALL_BBEXEC_CONFIG=
INSTALL_BBEXEC_WORKING_DIR=
INSTALL_BBEXEC_TERMINAL=
INSTALL_BBEXEC_USER=
# The following value can be [true] [false]. Default is [false].
INSTALL_BBEXEC_QUIET=
INSTALL_BBEXEC_APP_NAME=
INSTALL_BBEXEC_APP_USER_NAME=
INSTALL_BBEXEC_CLASSPATH_NAME=
# The following value can be [true] [false]. Default is [false].
INSTALL_BBEXEC_SECURE=
INSTALL_BBEXEC_LOCAL_PORT=
INSTALL_BBEXEC_REMOTE_PORT=
INSTALL_BBEXEC_ARGS=
# The following value can be [true] [false]. Default is [false].
INSTALL_BBEXEC_SYNC=
# The following value default is 6, a wait of 30 seconds will be performed between retries, for a total default retry time of 3 minutes.
INSTALL_BBEXEC_NUM_RETRIES=
# The following value can be [true] [false]. Default is [false].
INSTALL_BBEXEC_SHOW_PROGRESS=
# The following value can be [true] [false]. Default is [false].
INSTALL_BBEXEC_ALLOW_CANCEL=
INSTALL_BBEXEC_PROGRESS_TITLE=
INSTALL_BBEXEC_PROGRESS_TEXT=
INSTALL_BBEXEC_FAILURE_TITLE=
INSTALL_BBEXEC_FAILURE_TEXT=
#
################################################################################
# UAC Wizard Detail Settings
#
# The following value can be [true] [false]. Default is [false].
UAC_ELEVATE=
#
################################################################################
# License Selection Wizard Detail Settings
#
# The license regsistration, install, and brand wizards will
# be automatically added, depending on the user selection.
# The following value can be [register] [install] [blm]. Default is [register]
LICENSE_SELECTION_OPTION=register
#
################################################################################
# License Registration Wizard Detail Settings
#
# The following value can be [true] [false]
LICENSE_REGISTER_DEMOLIC=true
LICENSE_REGISTER_COMPANYNAME=Teleflora
LICENSE_REGISTER_FIRSTNAME=JJ
LICENSE_REGISTER_LASTNAME=Blankenship
LICENSE_REGISTER_EMAIL=jblankenship\@teleflora.com
LICENSE_REGISTER_FAX=
LICENSE_REGISTER_PHONE=800.621.8324
# The following are only used when LICENSE_REGISTER_DEMOLIC=[false]
# The following values can be left empty, so that they will be dynamically populated
LICENSE_REGISTER_SERIALNUM=$Serial_Number 
LICENSE_REGISTER_AUTHNUM=$Auth_Number
LICENSE_REGISTER_HOSTNAME=$Host_Name
LICENSE_REGISTER_HOSTID=$Host_ID
# The following are only used when LICENSE_REGISTER_DEMOLIC=[true]
LICENSE_REGISTER_DEMOUSERCOUNT=
LICENSE_REGISTER_DEMOSERIALNUM=
LICENSE_REGISTER_DEMOAUTHNUM=
# The following value can be [auto] [web] [email] [phone] [other]. Default is [auto]
LICENSE_REGISTER_REGMETHOD=auto
# The following value can be [web] [email]. Default is [web]. This setting is not
# used if LICENSE_REGISTER_REGMETHOD=[auto]
LICENSE_REGISTER_DELMETHOD=web
# The following value can be [true] [false]. Default is [true].
LICENSE_REGISTER_COUNTRYUSACANADA=true
# The following value can be [true] [false]. Default is [false].
LICENSE_REGISTER_WANTINFO=false
# The following value can be [true] [false]. Default is [false].
LICENSE_REGISTER_NOTEBOOK=false
# The following value is only used when LICENSE_REGMETHOD=[phone].
# Specify path and file name, a ASCII text file will be generated by the wizard.
LICENSE_REGISTER_PHONEFILE=
# The following value is only used when LICENSE_REGMETHOD=[other].
# Specify path and file name, a ASCII text file will be generated by the wizard.
LICENSE_REGISTER_OTHERFILE=
#
################################################################################
# License Install Wizard Detail Settings
#
# The following value can be [true] [false]. Default is [false].
LICENSE_INSTALL_ENTERLICINFO=false
# The following is only used when LICENSE_INSTALL_ENTERLICINFO=[false].
# Specify the location of an existing license file.
LICENSE_INSTALL_LICENSEFILE=/usr2/basis/blm/
# The following are only used when LICENSE_INSTALL_ENTERLICINFO=[true].
LICENSE_INSTALL_FEATURE=
LICENSE_INSTALL_ENCRYPTCODE=
LICENSE_INSTALL_LICREV=
LICENSE_INSTALL_HOSTID=
LICENSE_INSTALL_EXPDATE=
LICENSE_INSTALL_CHECKSUM=
LICENSE_INSTALL_NUMUSERS=
LICENSE_INSTALL_SERIALNUM=
#
################################################################################
# BBj Brand Wizard Detail Settings
#
# The following value can be [true] [false]. Default is [false].
BBJ_BRAND_REMOTE=false
BBJ_BRAND_SERVERNAME=
#
################################################################################
# BBj Configuration Startup Wizard Detail Settings
#
# On Windows the following value can be [service] [login] [manual]. Default is [service].
# On Non-Windows the following value can be [init] [manual]. Default is [init].
BBJ_CFG_STARTUP_TYPE=init
BBJ_CFG_STARTUP_TYPE_NON_WIN=init
BBJ_CFG_STARTUP_USERACCOUNT=root
BBJ_CFG_STARTUP_PASSWORD=
# The following value is only used when run as a service and can be [auto] [manual] [disabled]
BBJ_CFG_STARTUP_SERVICESTARTUPTYPE=auto
#
################################################################################
# BBj Services Wizard Detail Settings
#
# The following value can be [start] [stop] [restart]
BBJ_START_STOP_STARTUP=start
# The following values are only used if BBJ_START_STOP_STARTUP=[stop].
# The following default value is [localhost]
BBJ_START_STOP_SERVERNAME=localhost
# The following default value is [2002]
BBJ_START_STOP_ADMINPORT=2002
# The following default value is [admin]
BBJ_START_STOP_USERNAME=
# The following default value is [admin123] only in silent mode
BBJ_START_STOP_USERPASSWORD=
# The following default value is [false]
BBJ_START_STOP_WAITFORCLIENTS=false
#
################################################################################
# BLM Configuration Startup Wizard Detail Settings
#
# On Windows the following value can be [service] [login] [manual]. Default is [service].
# On Non-Windows the following value can be [init] [manual]. Default is [init].
BLM_CFG_STARTUP_TYPE=init
BLM_CFG_STARTUP_TYPE_NON_WIN=init
# The following value can be [auto] [manual] [disabled]
BLM_CFG_STARTUP_SERVICESTARTUPTYPE=auto
#
################################################################################
# BLM Services Wizard Detail Settings
#
# The following value can be [start] [stop] [restart]
BLM_START_STOP_STARTUP=start
#
################################################################################
# EM Wizard Detail Settings
#
EM_CURADMINPASSWORD=
EM_NEWADMINPASSWORD=
EM_SERVERNAME=
EM_ADMINPORT=
";
##EOF
		open(BBJINST, "> /tmp/bbjinstallsettings15.txt");
        	print BBJINST $bbjinstallsettings15;
		close(BBJINST);
	}
         else {
                loginfo("No Register.properties file exists...");
        }

loginfo("Removing existing /usr2/bbx/config/config.ini.....");
	mysystem("rm -r /usr2/bbx/config/config.ini");
loginfo("Creating new /usr2/bbx/config/config.ini.....");
my $config_ini = "
[RTI14]
DATEFORMAT.1=
DATEFORMAT.2=
RWUSERS=
DATESUFFIX.2=
CREATETABLETYPE=6
DATESUFFIX.1=
DICTIONARY=/usr2/bbx/dict/
DATABASE=RTI14
ROUSERS=
TRUNCATEIFTOOLONG=Y
ADVISORYLOCKING=Y
ADMINUSERS=
DATECOLUMNSSORTED=false
ACCESSPOLICY=ALL
Y2KWINDOW.1=0
DATESUFFIX=
Y2KWINDOW.2=0
CHARSET=
READONLY=N
Y2KWINDOW=0
DATA=/usr2/bbx/bbxd/
DATEFORMAT=
AUTO_ANALYZE_TABLES=false

[RTI]
DATEFORMAT.1=
DATEFORMAT.2=
RWUSERS=
DATESUFFIX.2=
CREATETABLETYPE=6
DATESUFFIX.1=
DICTIONARY=/usr2/bbx/odbc_dict/
DATABASE=RTI
ROUSERS=
TRUNCATEIFTOOLONG=Y
ADVISORYLOCKING=Y
ADMINUSERS=
DATECOLUMNSSORTED=false
ACCESSPOLICY=ALL
Y2KWINDOW.1=0
DATESUFFIX=
Y2KWINDOW.2=0
CHARSET=
READONLY=N
Y2KWINDOW=0
DATA=/usr2/bbx/bbxd/
DATEFORMAT=
AUTO_ANALYZE_TABLES=false";
open(BBJCFG, "> /usr2/bbx/config/config.ini");
        print BBJCFG $config_ini;
        close(BBJCFG);
	mysystem("chmod 775 /usr2/bbx/config/config.ini"); 
	mysystem("chown tfsupport:rtiadmins /usr2/bbx/config/config.ini"); 

	if( (-f "/tmp/$BBJ.gz")
	&&  (-f "/tmp/bbjinstallsettings15.txt")
	) {
		loginfo("Stopping RTI Programs.....");
		mysystem("/sbin/service rti stop");
		loginfo("Stopping BBj Services.....");
		mysystem ("$POSDIR/bin/bbjservice.pl --stop");
		loginfo("Stopping Basis License Manager.....");
		mysystem ("/sbin/service blm stop");
		loginfo("Creating /usr2/install_bbj directory.....");
		mysystem ("mkdir /usr2/install_bbj");
		mysystem ("mv /tmp/$BBJ.gz /usr2/install_bbj/");
		mysystem ("mv /tmp/bbjinstallsettings15.txt /usr2/install_bbj/"); 
		loginfo("Gunziping and untar $BBJ......");
		my $returnval = mysystem("gunzip /usr2/install_bbj/$BBJ.gz");
		if($returnval != 0) {
			logerror("Terminating update_bbj with return code $returnval.");
			exit($returnval);
		}
		$returnval = mysystem ("tar xvf /usr2/install_bbj/$BBJ -C /usr2/install_bbj/");
		if($returnval != 0) {
			logerror("Terminating update_bbj with return code $returnval.");
			exit($returnval);
		}
		loginfo("Removing existing jar files....");
			mysystem("rm -r /usr2/basis/lib/*");
		loginfo("Untaring $BBJ.......");
		loginfo("Installing $BBJ......");
		$returnval = mysystem("java -jar /usr2/install_bbj/$RTI15_BBJ_INSTALL_FILE -p /usr2/install_bbj/bbjinstallsettings15.txt");
		if($returnval != 0) {
			logerror("Terminating update_bbj with return code $returnval.");
			exit($returnval);
		}
	loginfo("Completed $BBJ Installation......");
	loginfo("Removing /var/www/lib/ files.....");
	loginfo("Webstart access is no longer accepted. Removing all files in /var/www/ relating to BBj.");
		mysystem("rm -r /var/www/lib/*");
	loginfo("removing /var/www/jnlp/ files.....");
		mysystem("rm -r /var/www/jnlp/*");
	loginfo("removing /var/www/cgi-bin/ files.....");
		mysystem("rm -r /var/www/cgi-bin/*");
	#loginfo("Copy new unsigned jars to /usr2/basis/lib/ .....");
	#	mysystem("cp -r /usr2/install_bbj/jars/unsigned/* /usr2/basis/lib/");
	# not putting new jars in place with v15 as we no longer allow webstart access
	# loginfo("Copy new signed jars to /var/www/lib/ .....");
	#	mysystem("cp -r /usr2/install_bbj/jars/signed/* /var/www/lib/");
	loginfo("Copy new librxtxSerial.so to /usr2/basis/lib/ .....");
		mysystem("cp -r /usr2/install_bbj/librxtxSerial.so /usr2/basis/lib/");
	# loginfo("Copy new jnlp.pl to /var/www/cgi-bin/ .....");
#		mysystem("cp -r /usr2/install_bbj/bin/jnlp.pl /var/www/cgi-bin/");
#		mysystem("chmod 775 /var/www/cgi-bin/jnlp.pl");
	loginfo("Changing settings in BBj.properties.....");
		open BBJPROP, "</usr2/basis/cfg/BBj.properties";
		my $foundulimit = "false";
		open BBJPROPOUT, ">/usr2/basis/cfg/BBj.properties.tmp"; 	
			while (<BBJPROP>) {
				$_ =~ s/com.basis.user.useFork=true/com.basis.user.useFork=false/g;
				$_ =~ s/basis.java.jvm.BBjServices=\/usr\/java\/usr\/java\/jre1.6.0_16\/bin\/java/basis.java.jvm.BBjServices=\/usr\/java\/latest\/bin\/java/g;
				$_ =~ s/basis.java.jvm.Default=\/usr\/java\/usr\/java\/jre1.6.0_16\/bin\/java/basis.java.jvm.Default=\/usr\/java\/latest\/bin\/java/g;
				$_ =~ s/com.basis.server.admin.1.useSSL=false/com.basis.server.admin.1.useSSL=true/g;
				$_ =~ s/com.basis.bbj.comm.ProxyManagerServer.start=false/com.basis.bbj.comm.ProxyManagerServer.start=true/g;
				$_ =~ s/com.basis.bbj.comm.ThinClientProxyServer.start=false/com.basis.bbj.comm.ThinClientProxyServer.start=true/g;
				$_ =~ s/com.basis.bbj.comm.ThinClientServer.start=false/com.basis.bbj.comm.ThinClientServer.start=true/g;
				$_ =~ s/\-verbose\\:gc/\-Dfile.encoding\\=ISO\-8859\-1 \-verbose\\:gc/g;
				if ($_ =~ m/bbjservices.ulimit.filedescriptors/)
				{
					$foundulimit = "true";
				}
				print BBJPROPOUT $_;
			}
			if ($foundulimit ne "true")
			{
				print BBJPROPOUT "bbjservices.ulimit.filedescriptors=16384\n";
			}
		close BBJPROP;
		close BBJPROPOUT;
		mysystem("mv /usr2/basis/cfg/BBj.properties /usr2/basis/cfg/BBj.properties.bak");
		mysystem("mv /usr2/basis/cfg/BBj.properties.tmp /usr2/basis/cfg/BBj.properties");
		$returnval = mysystem("chmod 644 /usr2/basis/cfg/BBj.properties");
# Adding /usr2/bbx/bin to the /usr2/basis/cfg/.envsetup file 
		$returnval=mysystem ("grep \"/usr2/bbx/bin\"/ /usr2/basis/bin/.envsetup > /dev/null 2> /dev/null");
     if($returnval != 0) {
           loginfo("Add /usr2/bbx/bin to the Basis env setup PATH.");
           mysystem("cp /usr2/basis/bin/.envsetup /usr2/basis/bin/.envsetup.bak");
           open ENVOLD, "< /usr2/basis/bin/.envsetup.bak";
           open ENVNEW, "> /usr2/basis/bin/.envsetup";
           while(<ENVOLD>) {
                my $line = $_;
                if ($line =~ m/PATH=/) {
                     print ENVNEW $line;
                     $line = "PATH=\"\$PATH:\${bbjHome}/bin:\${bbjHome}/lib:/usr2/bbx/bin/\"\n";
                }
                print ENVNEW $line;
           }
           close ENVNEW;
           close ENVOLD;
           mysystem("chmod 775 /usr2/basis/bin/.envsetup");
           mysystem("rm -f /usr2/basis/bin/.envsetup.bak");
     	}
	loginfo("Removing Installation Files........");
		mysystem("rm -fr /usr2/install_bbj");
	loginfo("Done with update to BBj v15.....");
	loginfo("Restarting Basis License Manager.....");
		mysystem("/sbin/service blm stop");
		sleep (2);
		mysystem("/sbin/service blm start");
	loginfo("Restarting BBj Services.....");
		mysystem("$POSDIR/bin/bbjservice.pl --stop");
		sleep (2);
		mysystem("$POSDIR/bin/bbjservice.pl --start");
		sleep (2);
	loginfo("Starting RTI Programs.....");
		mysystem("/sbin/service rti start");
	loginfo("Restart Complete......Finished!");
	}

	return(1);
}

sub install_java
{
    $ARCH = processor_arch();

    my $java_file = ($ARCH eq 'x86_64') ?
	"jdk-" . $RTI15_JAVA_REL . "-linux-x64.tar.gz" :
	"jdk-" . $RTI15_JAVA_REL . "-linux-i586.tar.gz";

    get_and_load_java($java_file);

    return(1);
}


#
# Install OS pre-requisites for RTI v15.
#
sub uos_rti15_install
{
    my ($if_name) = @_;

    my $ltag = '[rti15 install]';

    # if booting "DHCP", log an error and return
    my $conf_file = "/etc/sysconfig/network-scripts/ifcfg-$if_name";
    my $pattern = ($OS eq 'RHEL6' || $OS eq 'RHEL7') ? 'BOOTPROTO=\"dhcp\"' : 'BOOTPROTO=dhcp';
    system("grep $pattern $conf_file > /dev/null 2> /dev/null");
    if ($? == 0) {
	    showerror("$ltag Network must be configured with static ip first");
	    return($EXIT_RTI14);
    }

    showinfo("$ltag Installing RTI v15 Software Dependencies...");
    showinfo("$ltag Using Teleflora Package Server \"$TFSERVER\"");

    remount_filesystem('/teleflora', '/usr2');

    # for RHEL7, add the "nofail" mount option
    if ($OS eq 'RHEL7') {
	my $fstab = uos_pathto_fstab();
	uos_edit_fstab($fstab, '/usr2');
    }

    # report Red Hat Network registration status
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	my $rhn_system_id = rhn_get_system_id();
	if ($rhn_system_id) {
	    showinfo("$ltag Red Hat Network system id: $rhn_system_id");
	}
	else {
	    showinfo("$ltag system not registered with Red Hat Network");
	}
    }
    if ($OS eq 'RHEL7') {
	my $sub_mgr_id = sub_mgr_get_system_identity();
	if ($sub_mgr_id) {
	    showinfo("$ltag Red Hat subscription manager id: $sub_mgr_id");
	}
	else {
	    showinfo("$ltag system does not have Red Hat subscription manager id");
	}
    }

    # install some more rpm packages (ought to be done in kickstart)
    if ($OS eq 'RHEL5' || $OS eq 'RHEL6' || $OS eq 'RHEL7') {
	my @rpms = ('fetchmail', 'ksh', 'uucp', 'httpd');
	for my $rpm_name (@rpms) {
	    if ( ($rpm_name eq 'uucp') && ($OS ne 'RHEL5') ) {
		next;
	    }

	    system("yum -y install $rpm_name");
	    if ($? == 0) {
		loginfo("$ltag installed rpm: $rpm_name");
	    }
	    else {
		showerror("$ltag could not install rpm: $rpm_name");
	    }
	}
    }

    # add standard users
    uos_rti_make_default_users();

    # configure Samba
    my $samba_conf_file = uos_pathto_samba_conf();
    if (ost_util_fgrep($samba_conf_file, 'delivery')) {
	uos_generate_samba_config($samba_conf_file, $POS_TYPE_RTI);
	loginfo("$ltag generated new Samba config file: $samba_conf_file");
    }
    uos_rti_make_default_samba_users();


    if (is_java_already_installed($RTI15_JAVA_VER)) {
	loginfo("$ltag Java $RTI15_JAVA_VER is installed, skipping Java update");
    }
    else {
	showinfo("$ltag installing Java JRE");

	# After the Java distribution file is downloaded,
	# an rpm is extracted and any previous rpm files must
	# be removed before proceeding or "unzip" will want to
	# interact with the user hanging the process.
	loginfo("$ltag Removing old Java rpm packages...");
	mysystem("rm /tmp/jre-$RTI15_JAVA_REL-linux*.rpm");
	mysystem("rpm -e jre-$RTI15_JAVA_VER");
	mysystem("rpm -e jdk-$RTI15_JAVA_VER");

	loginfo("$ltag beginning Java update, Java is NOT installed: $RTI15_JAVA_VER");

	install_java();
    }


    install_bbj15_packages();


    return($EXIT_OK);
}

###################################
### RTI ONLY FUNCTIONS          ###
###################################

sub uos_rti_make_default_users
{
    my $rc = 1;

    system("/usr/sbin/groupadd rti");
    system("/usr/sbin/groupadd rtiadmins");

    # RTI 'tfsupport' system user
    system("grep \"^tfsupport:\" /etc/passwd > /dev/null 2> /dev/null");
    if ($? != 0) {
	system("/usr/sbin/useradd -g rti -G rti,rtiadmins -s /bin/bash tfsupport");
	print("\n");
	print("\n");
	print("\n");
	print(" Set 'tfsupport' User System Password...\n");
	system("passwd tfsupport");
    }

    # RTI 'rti' system user.
    system("grep \"^rti:\" /etc/passwd > /dev/null 2> /dev/null");
    if ($? != 0) {
	my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
	my $password = crypt("rti", $salt);
	system("/usr/sbin/useradd -p \"$password\" -g rti -s /bin/bash rti");
    }

    # RTI 'odbc' user for Samba
    system("grep \"^odbc:\" /etc/passwd > /dev/null 2> /dev/null");
    if ($? != 0) {
	system("/usr/sbin/useradd -g rti -s /sbin/nologin odbc");
    }

    # RTI 'delivery' user for Samba
    system("grep \"^delivery:\" /etc/passwd > /dev/null 2> /dev/null");
    if ($? != 0) {
	system("/usr/sbin/useradd -g rti -s /sbin/nologin delivery");
    }

    return($rc);
}

sub uos_rti_make_default_samba_users
{
    my $rc = 1;
    my $ml = '[rti_make_default_samba_users]';

    # RTI 'rti' Samba user.
    system("grep \"^rti:\" /etc/samba/smbpasswd > /dev/null 2> /dev/null");
    if ($? != 0) {
	showinfo("Adding 'rti' user to samba...");
	if (open(my $pipefh, '|-', 'smbpasswd -s -a rti')) {
	    print {$pipefh} "rti\n";
	    print {$pipefh} "rti\n";
	    close($pipefh);
	}
	else {
	    showerror("$ml could not open pipe to: smbpasswd -s -a rti");
	}
    }

    system("grep \"^odbc:\" /etc/samba/smbpasswd > /dev/null 2> /dev/null");
    if ($? != 0) {
	showinfo("Adding 'odbc' user to samba...");
	if (open(my $pipefh, '|-', "smbpasswd -s -a odbc")) {
	    print {$pipefh} "odbc99\n";
	    print {$pipefh} "odbc99\n";
	    close($pipefh);
	}
	else {
	    showerror("$ml could not open pipe to: smbpasswd -s -a odbc");
	}
    }

    system("grep \"^delivery:\" /etc/samba/smbpasswd > /dev/null 2> /dev/null");
    if ($? != 0) {
	showinfo("Adding 'delivery' user to samba...");
	if (open(my $pipefh, '|-', "smbpasswd -s -a delivery")) {
	    print {$pipefh} "delivery\n";
	    print {$pipefh} "delivery\n";
	    close($pipefh);
	}
	else {
	    showerror("$ml could not open pipe to: smbpasswd -s -a delivery");
	}
    }

    return($rc);
}


###################################
### DAISY ONLY FUNCTIONS        ###
###################################

#
# Set the system run level to value between 0 and 6.
#
# returns
#   1 on success
#   0 if error
#
sub uos_daisy_set_runlevel
{
    my ($new_runlevel) = @_;

    my $rc = 1;
    my $ml = '[daisy_set_runlevel]';

    my $cmd = "/sbin/telinit $new_runlevel";
    system("$cmd");
    if ($? == 0) {
	loginfo("$ml successful exit status from: $cmd");
    }
    else {
	logerror("$ml non-zero exit status ($?) from: $cmd");
	$rc = 0;
    }

    # The "init" man page mentions that "init" waits 5 seconds
    # between each of two kills, and testing reveals we need
    # to wait a bit for the runlevel to change.
    sleep(10);

    return($rc);
}

#
# Start Daisy.
#
# returns
#   1 on success
#   0 if error
#
sub uos_daisy_start
{
    my $ml = '[daisy_start]';

    if ($OS eq 'RHEL5' || $OS eq 'RHEL6') {
	my $new_runlevel = 3;
	if (uos_daisy_set_runlevel($new_runlevel)) {
	    loginfo("$ml successful change to runlevel: $new_runlevel");
	}
	else {
	    logerror("$ml could not change to runlevel: $new_runlevel");
	    return(0);
	}
    }

    if ($OS eq 'RHEL7') {
	my @tty_list = qw(
	    getty@tty1
	    getty@tty2
	    getty@tty3
	    getty@tty4
	    getty@tty5
	    getty@tty6
	    getty@tty7
	    getty@tty8
	    getty@tty9
	    getty@tty11
	);

	foreach (@tty_list) {
	    system("systemctl start $_");
	}

	loginfo("$ml gettys restarted");
    }

    return(1);
}

#
# stop the Daisy POS
#
# returns
#   1 on success
#   0 if error
#
sub uos_daisy_stop
{
    my $rc = 1;
    my $ml = '[daisy_stop]';

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	my $new_runlevel = 4;
	if (uos_daisy_set_runlevel($new_runlevel)) {
	    loginfo("$ml successful change to runlevel: $new_runlevel");
	}
	else {
	    logerror("$ml could not change to runlevel: $new_runlevel");
	    return(0);
	}
    }

    if ($OS eq 'RHEL7') {
	my @tty_list = qw(
	    getty@tty1
	    getty@tty2
	    getty@tty3
	    getty@tty4
	    getty@tty5
	    getty@tty6
	    getty@tty7
	    getty@tty8
	    getty@tty9
	    getty@tty11
	);

	foreach (@tty_list) {
	    system("systemctl stop $_");
	}
    }

    my $cmd = "/d/daisy/utils/killemall";
    if (-e $cmd) {
	system("$cmd");
	if ($? == 0) {
	    loginfo("$ml successful exit status from: $cmd");
	}
	else {
	    logerror("$ml non-zero exit status ($?) from: $cmd");
	    $rc = 0;
	}
    }
    else {
	logerror("$ml Daisy utility does not exist: $cmd");
	$rc = 0;
    }

    return($rc);
}


sub uos_daisy_install
{
    my ($if_name) = @_;

    my $ml = '[daisy_install]';

    showinfo("Configuring System for Daisy...");

    if (! $KEEPDHCP) {
	# if booting "DHCP", log an error and return
	my $conf_file = "/etc/sysconfig/network-scripts/ifcfg-$if_name";
	my $pattern = ($OS eq "RHEL6" || $OS eq "RHEL7") ? 'BOOTPROTO=\"dhcp\"' : 'BOOTPROTO=dhcp';
	system("grep $pattern $conf_file > /dev/null 2> /dev/null");
	if ($? == 0) {
	    showerror("$ml network must be configured with static ip first");
	    return($EXIT_DAISY_INSTALL_DHCP);
	}
    }

    remount_filesystem("/teleflora", "/d");

    if ($OS eq 'RHEL7') {
	# add the "nofail" mount option
	my $fstab = uos_pathto_fstab();
	uos_edit_fstab($fstab, "/d");
    }

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	# make an entry in /etc/fstab.
	my $conf_file = uos_pathto_fstab();
	if (ost_util_fgrep($conf_file, '/mnt/cdrom') != 0) {
	    if (open(my $fstab, '>>', $conf_file)) {
		print {$fstab} "/dev/scd0\t\t/mnt/cdrom\tiso9660\tro,exec\t0 0\n";
		close($fstab);
	    }
	    else {
		logerror("$ml could not add entry for cdrom to: $conf_file");
		# $EXIT_DAISY_INSTALL_FSTAB
	    }
	}
    }

    if (! -d "/mnt/cdrom") {
	system("mkdir /mnt/cdrom");
    }

    if (! -d "/mnt/usb") {
	system("mkdir /mnt/usb");
    }

    #
    # for Samba on RHEL7, the "daisy" user must exist BEFORE
    # trying to restart Samba after generating a new config file.
    #
    uos_daisy_make_default_users();

    #
    # if the Daisy export directory does not appear in the
    # samba conf file, assume that the samba package has
    # been installed but that the system service needs to be
    # be enabled and started and then generate a new conf file.
    #
    my $conf_file = uos_pathto_samba_conf();
    if (ost_util_fgrep($conf_file, '/d/daisy/export')) {
	uos_config_samba_service();
	uos_daisy_generate_samba_config($conf_file);
    }

    #
    # for daisy systems, since the following function sets
    # the samba password for the daisy account, samba must
    # already be running.
    #
    uos_daisy_make_default_samba_users();

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	# generate a new /etc/sysconfig/i18n
	uos_configure_i18n();
    }
    if ($OS eq 'RHEL7') {
	# set system locale
	uos_set_system_locale();
    }

    return($EXIT_OK);
}

sub uos_daisy_make_default_users
{
    system("/usr/sbin/groupadd daisy");
    system("/usr/sbin/groupadd dsyadmins");

    # Daisy 'tfsupport' system user.
    system("grep \"^tfsupport:\" /etc/passwd > /dev/null 2> /dev/null");
    if ($? != 0) {
	my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
	my $password = crypt("T3l3fl0r4#", $salt);
	system("/usr/sbin/useradd -p \"$password\" -g daisy -G daisy,dsyadmins -s /bin/bash tfsupport");
    }

    # Daisy 'daisy' system user.
    system("grep \"^daisy:\" /etc/passwd > /dev/null 2> /dev/null");
    if ($? != 0) {
	my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
	my $password = crypt("dai1sy#", $salt);
	system("/usr/sbin/useradd -p \"$password\" -g daisy -s /bin/bash daisy");
    }

    return(1);
}

#
# make the Daisy samba user.
#
# returns
#   always 1
#
sub uos_daisy_make_default_samba_users
{
    my $ml = '[daisy_make_default_samba_users]';

    system("grep \"^daisy:\" /etc/samba/smbpasswd > /dev/null 2> /dev/null");
    if ($? != 0) {
	showinfo("Adding 'daisy' user to samba...");
	if (open(my $pipefh, '|-', "smbpasswd -s -a daisy")) {
	    print {$pipefh} "dai1sy#\n";
	    print {$pipefh} "dai1sy#\n";
	    close($pipefh);
	}
	else {
	    showerror("$ml could not open pipe to: smbpasswd -s -a daisy");
	}
    }

    return(1);
}

#
# generate samba config file for Daisy.
#
# returns
#   $EXIT_OK on success
#   non-zero if error
#
sub uos_daisy_generate_samba_config
{
    my ($conf_file) = @_;

    return(uos_generate_samba_config($conf_file, $POS_TYPE_DAISY));
}


sub uos_daisy_shopcode
{
    my $shopcode_file = File::Spec->catdir($DEF_DAISY_DIR, $DAISY_SHOPCODE_FILE_NAME);
    my $shopcode = uos_daisy_get_shopcode($shopcode_file);

    return($shopcode);
}

#
# get the Daisy shop code
#
# returns
#   shop code on success
#   empty string if error
#
sub uos_daisy_get_shopcode
{
    my ($shopcode_file) = @_;

    my $shopcode = $EMPTY_STR;
    my $ml = '[daisy_get_shopcode]';

    if (-f $shopcode_file) {
	if (open(my $fh, '<', $shopcode_file)) {
	    my $buffer;
	    my $rc = sysread($fh, $buffer, 38);
	    if (defined($rc) && $rc != 0) {
		$shopcode = substr($buffer, 30, 8);
	    }
	    close($fh) or warn "$ml could not close $shopcode_file: $OS_ERROR\n";
	}
	else {
	    logerror("$ml could not open shopcode file: $shopcode_file");
	}
    }
    else {
	logerror("$ml Daisy shopcode file does not exist: $shopcode_file");
    }

    return($shopcode);
}

sub uos_daisy_shopname
{
    my $shopname_file = File::Spec->catdir($DEF_DAISY_DIR, $DAISY_CONTROL_FILE_NAME);
    my $shopname = uos_daisy_get_shopname($shopname_file);

    return($shopname);
}

#
# get the Daisy shop name
#
# returns
#   shop name on success
#   empty string if error
#
sub uos_daisy_get_shopname
{
    my ($shopname_file) = @_;

    my $shopname = $EMPTY_STR;
    my $ml = '[daisy_get_shopname]';

    if (-f $shopname_file) {
	if (open(my $fh, '<', $shopname_file)) {
	    my $buffer;
	    seek($fh, 0x2e3, 0);
	    my $rc = sysread($fh, $buffer, 40);
	    if (defined($rc) && $rc != 0) {
		$buffer =~ s/^\s+//;
		$buffer =~ s/\s+$//;
		$shopname = $buffer;
	    }
	    else {
		logerror("$ml could not read shop name file: $shopname_file");
	    }
	    close($fh) or warn "$ml could not close $shopname_file: $OS_ERROR\n";
	}
	else {
	    logerror("$ml could not open shop name file: $shopname_file");
	}
    }
    else {
	logerror("$ml shop name file does not exist: $shopname_file");
    }

    return($shopname);
}


sub uos_rti_shopcode
{
    my $shopcode_file = File::Spec->catdir('/usr2/bbx/config', 'dove.ini');
    my $shopcode = uos_rti_get_shopcode($shopcode_file);

    return($shopcode);
}

sub uos_rti_get_shopcode
{
    my ($shopcode_file) = @_;

    my $shopcode = $EMPTY_STR;
    my $ml = '[rti_get_shopcode]';

    if (-f $shopcode_file) {
	if (open(my $fh, '<', $shopcode_file)) {
	    while (<$fh>) {
		if (/DOVE_USERNAME\s*=\s*([[:print:]]+)/) {
		    $shopcode = $1;
		    last;
		}
	    }
	    close($fh) or warn "$ml could not close $shopcode_file: $OS_ERROR\n";

	    if ($shopcode) {
		loginfo("$ml RTI shopcode: $shopcode");
	    }
	    else {
		logerror("$ml RTI shopcode not found in file: $shopcode_file");
	    }
	}
	else {
	    logerror("$ml could not open RTI shopcode file: $shopcode_file");
	}
    }
    else {
	logerror("$ml RTI shopcode file does not exist: $shopcode_file");
    }

    return($shopcode);
}

sub uos_rti_shopname
{
    my $hostname = get_hostname();
    my $shopname = uos_rti_get_shopname($hostname);

    return($shopname);
}

#
# get the RTI shop name
#
# definition of "shopname" for RTI is:
#   1) hostname
#   2) use name to the left of the left most '.' (PERIOD)
#   3) use name to the left of the left most '-' (MINUS)
#   4) remove spaces from what's left
#
# Here is the Bash code:
#   echo $HOSTNAME | /usr/bin/cut -d'.' -f1 | /usr/bin/cut -d"-" -f1 | /usr/bin/tr -d '[:space:]'
#
# returns
#   shop name on success
#   empty string if error
#
sub uos_rti_get_shopname
{
    my ($hostname) = @_;

    my $ml = '[rti_get_shopname]';

    $hostname = (split(/\./, $hostname))[0]; # field left of PERIOD
    $hostname = (split(/\-/, $hostname))[0]; # field left of MINUS
    $hostname =~ s/\s+//g;

    return($hostname);
}


###################################
### AUDIT SYSTEM FUNCTIONS      ###
###################################

sub uos_audit_system_remote_rules_file
{
    my $ml = '[audit_system_remote_rules_file]';

    my $rules_file_name = uos_nameof_audit_system_config_file();
    my $rules_url = 'http://rtihardware.homelinux.com/ostools/' . $rules_file_name;
    my $rules_path = $EMPTY_STR;

    system("curl --output /dev/null --silent --head --fail $rules_url");
    if ($? == 0) {
	$rules_path = File::Spec->catdir('/tmp', $rules_file_name);
	system("curl --output $rules_path  --silent  $rules_url");
	loginfo("$ml audit system rules downloaded from: $rules_url");
    }

    return($rules_path);
}

sub uos_audit_system_generate_daisy_rules
{
    my ($rules_file) = @_;

    my $rc = 1;
    my $ml = '[audit_system_generate_daisy_rules]';

    if (open(my $cf, '>', $rules_file)) {
	print {$cf} "# Daisy PA DSS audit config file\n";
	print {$cf} "# Copyright 2009-2017 Teleflora\n";
	print {$cf} "#\n";
	print {$cf} "# This file contains the auditctl rules that are loaded\n";
	print {$cf} "# whenever the audit daemon is started via the initscripts.\n";
	print {$cf} "# The rules are simply the parameters that would be passed\n";
	print {$cf} "# to auditctl.\n";
	print {$cf} "#\n";
	print {$cf} "# -k key\n";
	print {$cf} "#    Set a filter key on an audit rule.\n";
	print {$cf} "# -p [r|w|x|a]\n";
	print {$cf} "#    Describe the permission access type that a file system watch\n";
	print {$cf} "#    will trigger on. r=read, w=write,  x=execute,  a=attribute change.\n";
	print {$cf} "# -w path\n";
	print {$cf} "#    Insert a watch for the file system object at path.\n";
	print {$cf} "\n";
	print {$cf} "-w /d/daisy -p wa -k daisypadss\n";
	close($cf) or warn "$ml could not close audit config file $rules_file: $OS_ERROR\n";
    }
    else {
	logerror("$ml could not open audit config file for write: $rules_file");
	$rc = 0;
    }

    return($rc);
}

sub uos_audit_system_generate_rti_rules
{
}

sub uos_audit_system_generate_rules
{
    my $rules_path = File::Spec->catdir('/tmp', uos_nameof_audit_system_config_file());

    if ($DAISY) {
	uos_audit_system_generate_daisy_rules($rules_path);
    }
    if ($RTI) {
	uos_audit_system_generate_RTI_rules($rules_path);
    }

    return($rules_path);
}

#
# audit system get or generate rules file
#
#   * if the rules file is specified in the environement via the variable
#     `AUDIT_SYSTEM_RULES_FILE`, the value will be verified as secure and
#     used as the rule file.
#
#   * else if on RTI systems, there is a rules file in the ostools config dir
#     named `rti.rules` or if on Daisy systems there is a rules file in the
#     ostools config dir named `daisy.rules`, it will be used as the rule file.
#
#   * else if on RTI systems, there is a rules file at the URL
#     `http://rtihardware.homelinux.com/ostools/rti.rules` or if
#     on Daisy systems, there is a rules file at URL
#     `http://rtihardware.homelinux.com/ostools/daisy.rules`, then
#     it will be used as the rule file.
#
#   * else a default rules file appropriate to the POS will be generated and
#     used as the rule file.
#
sub uos_audit_system_get_rules_file
{
    my $rules_file = $EMPTY_STR;
    my $ml = '[audit_system_get_rules_file]';

    $rules_file = $ENV{'AUDIT_SYSTEM_RULES_FILE'};
    if (defined($rules_file)) {
	if (is_arg_ok($rules_file)) {
	    loginfo("$ml rules file source: environment");
	    return($rules_file);
	}
	else {
	    logerror("$ml env rules file path improper: $rules_file");
	}
    }

    $rules_file = uos_pathto_audit_system_ostools_rules_file();
    if (-e $rules_file) {
	loginfo("$ml rules file source: ostools config dir");
	return($rules_file);
    }

    $rules_file = uos_audit_system_remote_rules_file();
    if ($rules_file) {
	loginfo("$ml rules file source: remote");
	return($rules_file);
    }

    $rules_file = uos_audit_system_generate_rules();

    return($rules_file);
}


sub uos_audit_system_install_rules
{
    my ($conf_file, $rules_file) = @_;

    my $rc = 1;
    my $ml = '[audit_system_install_rules]';

    system("rm -f $conf_file"); 
    my $exit_status = system("cp $rules_file $conf_file");
    if ($exit_status == 0) {
	loginfo("$ml audit system rules file ($rules_file) copied to: $conf_file");
	system("chown root:root $conf_file");
	system("chmod 0640 $conf_file");
    }
    else {
	showerror("$ml could not copy rules file ($rules_file) to: $conf_file");
	$rc = 0;
    }

    return($rc);
}

sub uos_audit_system_restart
{
    my $rc = 1;
    my $ml = '[audit_sysytem_restart]';

    my $system_service = 'auditd';
    my $exit_status = system("/sbin/service $system_service restart");
    if ($exit_status == 0) {
	showinfo("$ml system service restarted: $system_service");
    }
    else {
	showerror("$ml could not restart system service: $system_service");
	$rc = 0;
    }		

    return($rc);
}

#
# --audit-system-configure
#
# configure the audit system with an appropriate config file and
# restart the 'auditd' system service.
#
# don't do anything if already installed.
#
# the `--audit-system-rules-file=path` command line option does not have to
# be specified even if `--audit-system-configure` is spsecified - the
# strategy outlined below explains how a rule file is determined when
# `--audit-system-rules-file=path` is not specified.
#
# if both the `--audit-system-configure` command line option is specifed and
# the `--audit-system-rules-file=path` command line option is specified, then
# the value of "path" specified will be checked for security issues and
# if verified "OK", it will be copied to the directory `/etc/audit/rules.d` and
# the perms set appropriately.
#
# if the `--audit-system-configure` command line option is specifed and
# the `--audit-system-rules-file=path` command line option is NOT specified, then
# the following strategy will be used to determine where to find the rules file:
#   * if the rules file is specified in the environement via the variable
#     `AUDIT_SYSTEM_RULES_FILE`, the value will be verified as secure and
#     used as the rule file.
#
#   * else if on RTI systems, there is a rules file in the ostools config dir
#     named `rti.rules` or if on Daisy systems there is a rules file in the
#     ostools config dir named `daisy.rules`, it will be used as the rule file.
#
#   * else if on RTI systems, there is a rules file at the URL
#     `http://rtihardware.homelinux.com/ostools/rti.rules` or if
#     on Daisy systems, there is a rules file at URL
#     `http://rtihardware.homelinux.com/ostools/daisy.rules`, then
#     it will be used as the rule file.
#
#   * else a default rules file appropriate to the POS will be generated and
#     used as the rule file.
#
# returns
#   1 if successful
#   0 on error
#
sub uos_audit_system_configure
{
    my ($conf_file, $rules_file) = @_;

    my $rc = 1;
    my $ml = '[audit_system_configure]';

    # if conf file exists, audit system is already configured
    if (-e $conf_file) {
	showinfo("$ml audit system config file already exists: $conf_file");
	return($rc);
    }

    # if supplied, check out rules file name, and use it if ok
    if ($rules_file) {
	if (! is_arg_ok($rules_file)) {
	    showerror("$ml audit system rules file path unacceptable: $rules_file");
	    $rules_file = $EMPTY_STR;
	    $rc = 0;
	}
    }
    # if NOT supplied, look for one or generate one
    else {
	$rules_file = uos_audit_system_get_rules_file();
	if ($rules_file eq $EMPTY_STR) {
	    showerror("$ml could not get audit system rules file");
	    $rc = 0;
	}
    }

    # if we have a rules file, install it and restart service
    if ($rules_file) {
	if (uos_audit_system_install_rules($conf_file, $rules_file)) {
	    showinfo("$ml audit system rules installed: $conf_file");
	    uos_audit_system_restart();
	}
	else {
	    showerror("$ml could not install audit system rules: $conf_file");
	    $rc = 0;
	}
    }

    return($rc);
}


###################################
### UPC UPS FUNCTIONS           ###
###################################

#
# call the 'lsusb' command to try to determine the type of
# UPS hardware.  Currently, there only two types of
# UPS USB hardware.
#
# returns
#   "serial" if did NOT find UPS USB hardware
#   otherwise "usb"
#
sub uos_identify_ups_hardware
{
    my $lsusb_cmd = '/sbin/lsusb';

    my $ups_type = 'serial';

    unless (-x $lsusb_cmd) {
	return($ups_type);
    }

    if (open(my $pipe, '-|', $lsusb_cmd)) {
	while (<$pipe>) {
	    if (/$APC_USB_TYPE1/i || /$APC_USB_TYPE2/i) {
		$ups_type = 'usb';
		last;
	    }
	}
	close($pipe);
    }

    return($ups_type);
}


sub uos_rewrite_apcupsd_conf
{
    my ($cfh) = @_;

    my $ups_type;
    if ($UPS_SERIAL) {
	$ups_type = "serial";
    }
    elsif ($UPS_USB) {
	$ups_type = "usb";
    }
    else {
	$ups_type = uos_identify_ups_hardware();
    }

    #
    # The first line of the file must be in a special format or the
    # apcupsd binary will complain.
    #
    print {$cfh} "## apcupsd.conf v1.1 ##\n";

    print {$cfh} "#\n";
    print {$cfh} "# APC UPS Config File\n";
    print {$cfh} "# Generated by $PROGNAME $CVS_REVISION $TIMESTAMP\n";

    if ($ups_type eq "usb") {
	print {$cfh} "# USB Based Interface\n";
	print {$cfh} "UPSCABLE usb\n";
	print {$cfh} "UPSTYPE usb\n";
	print {$cfh} "DEVICE \n";
    }
    else {
	print {$cfh} "# Serial Based Interface\n";
	print {$cfh} "UPSCABLE smart\n";
	print {$cfh} "UPSTYPE smartups\n";
	print {$cfh} "DEVICE $UPS_SERIAL_PORT\n";
    }

    print {$cfh} "UPSNAME RTIUPS\n";
    print {$cfh} "LOCKFILE /var/lock\n";
    print {$cfh} "SCRIPTDIR /etc/apcupsd\n";
    print {$cfh} "PWRFAILDIR /etc/apcupsd\n";
    print {$cfh} "NOLOGINDIR /etc\n";
    print {$cfh} "ONBATTERYDELAY 20\n";
    print {$cfh} "BATTERYLEVEL 10\n";
    print {$cfh} "MINUTES 10\n";
    print {$cfh} "TIMEOUT 0\n";
    print {$cfh} "ANNOY 300\n";
    print {$cfh} "ANNOYDELAY 60\n";
    print {$cfh} "NOLOGON disable\n";
    print {$cfh} "KILLDELAY 0\n";
    print {$cfh} "\n";
    print {$cfh} "NETSERVER on\n";
    print {$cfh} "NISIP 127.0.0.1\n";
    print {$cfh} "NISPORT 3551\n";
    print {$cfh} "EVENTSFILE /var/log/apcupsd.events\n";
    print {$cfh} "EVENTSFILEMAX 10\n";
    print {$cfh} "\n";
    print {$cfh} "UPSCLASS standalone\n";
    print {$cfh} "UPSMODE disable\n";
    print {$cfh} "STATTIME 0\n";
    print {$cfh} "STATFILE /var/log/apcupsd.status\n";
    print {$cfh} "LOGSTATS off\n";
    print {$cfh} "DATATIME 0\n";

    return(1);
}


sub uos_install_apcupsd_conf
{
    my $rc = 1;

    #
    # Our default config file will indicate the use of USB based interfaces.
    # Check to see if the conf file has already been customized... if so,
    # nothing to do.
    #
    my $conf_file = uos_pathto_apcupsd_conf();
    unless (ost_util_fgrep($conf_file, 'updateos')) {
	return($rc);
    }

    # save a copy of the original conf file
    if (-f $conf_file) {
	my $saved_conf_file = $conf_file . '.orig';
	system("cp $conf_file $saved_conf_file");
    }

    if (open(my $cfh, '>', $conf_file)) {

	uos_rewrite_apcupsd_conf($cfh);

	close($cfh);
    }
    else {
	showerror("[install apcupsd conf] could not write new conf file: $conf_file");
	$rc = 0;
    }

    system("chown root:root $conf_file");
    system("chmod a+r $conf_file");

    showinfo("[install apcupsd conf] generated new APC UPS config file: $conf_file");

    return($rc);
}


#
# install the script that is run whenever the system begins
# running on battery power from the APS UPS.
#
# returns
#   1 if successful
#   0 on error
#
sub uos_install_apcupsd_onbattery_script
{
    my $apcupsd_configdir_path = uos_pathto_apcupsd_configdir_path();

    unless (-d $apcupsd_configdir_path) {
	showerror("install onbatt script] APC UPS config dir does not exist: $apcupsd_configdir_path");
	return(0);
    }

    my $tf_onbatt_script_path = uos_pathto_tf_onbatt_script();

    unless (-f $tf_onbatt_script_path) {
	showerror("install onbatt script] Teleflora battery script does not exist: $tf_onbatt_script_path");
	return(0);
    }

    my $apcupsd_onbatt_script_path = uos_pathto_apcupsd_onbatt_script();

    system("cp $tf_onbatt_script_path $apcupsd_onbatt_script_path");

    system("chown root:root $apcupsd_onbatt_script_path");
    system("chmod 555 $apcupsd_onbatt_script_path");

    showinfo("[install onbatt script] APC UPS battery script installed: $apcupsd_onbatt_script_path");

    return(1);
}


#
# Install software which listens for UPS notifications (power off, power on.)
# Un-install any previous UPS software (most notably, powerchute under RTI.
#
sub uos_install_apcupsd
{
    #
    # If the rpm is already installed, just deal with config files.
    #
    my $apcupsd_rpm_name = 'apcupsd';
    system("rpm -qa | grep $apcupsd_rpm_name > /dev/null 2> /dev/null");
    if ($? == 0) {
	showinfo("[install apcupsd] APC UPS software already installed: $apcupsd_rpm_name");

	uos_install_apcupsd_conf();
	uos_install_apcupsd_onbattery_script();
	return($EXIT_OK);
    }

    # remove any old versions previously downloaded
    my $tmp_rpm = "/tmp/apcupsd.rpm";
    system("rm -f $tmp_rpm");

    $ARCH = processor_arch();

    my $rpm_name = "";
    if ($OS eq 'RHEL5') {
	if ($ARCH eq "x86_64") {
	    $rpm_name = "apcupsd-3.14.8-1.el5.x86_64.rpm";
	}
	else {
	    $rpm_name = "apcupsd-3.14.8-1.el5.i386.rpm";
	}
    }
    elsif ($OS eq 'RHEL6') {
	$rpm_name = "apcupsd-3.14.10-1.el6.x86_64.rpm";
    }
    elsif ($OS eq 'RHEL7') {
	$rpm_name = "apcupsd-3.14.12-1.el7.x86_64.rpm";
    }
    else {
	showerror("[install apcupsd] unsupported platform: $OS");
	return($EXIT_WRONG_PLATFORM);
    }

    my $url = "$TFSERVER/rpms/packages/" . $rpm_name;

    # download and install the rpm
    system("cd /tmp && wget -O $tmp_rpm $url");
    if ($? == 0) {
	showinfo("[install apcupsd] APC UPS rpm downloaded from: $TFSERVER/rpms/packages");
    }
    else {
	showerror("[install apcupsd] could not download APC UPS rpm from: $TFSERVER/rpms/packages");
	return($EXIT_APCUPSD_INSTALL);
    }

    system("rpm -ihv $tmp_rpm");

    # verify the rpm was installed.
    system("rpm -qa | grep apcupsd > /dev/null 2> /dev/null");
    if ($? == 0) {
	showinfo("[install apcupsd] APC UPS rpm installed: $rpm_name");
    }
    else {
	showerror("[install apcupsd] could not install APC UPS rpm: $rpm_name");
	return($EXIT_APCUPSD_INSTALL);
    }

    # cleanup
    system("rm -f $tmp_rpm");

    my $apcupsd_configdir_path = uos_pathto_apcupsd_configdir_path();
    unless (-d $apcupsd_configdir_path) {
	showerror("[install apcupsd] can't happen: APC UPS config dir not found: $apcupsd_configdir_path");
	return($EXIT_APCUPSD_INSTALL);
    }

    # Turn off older APC (Java based) UPS Monitor.
    # Note that the APC software did not use 'chkconfig' to install PBEAgent, thus,
    # we will explicitly 'rm' the file.
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	if (-f '/etc/init.d/PBEAgent') {
	    system("/etc/init.d/PBEAgent stop");
	    system("chkconfig --level 3 PBEAgent off");
	    system("rm -f /etc/init.d/PBEAgent");
	}
    }

    uos_install_apcupsd_conf();

    uos_install_apcupsd_onbattery_script();

    # start the system service
    my $rc = $EXIT_APCUPSD_INSTALL;
    my $service_name = 'apcupsd';
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	$rc = system("/sbin/service $service_name start");
    }
    elsif ($OS eq 'RHEL7') {
	system("/bin/systemctl enable $service_name");
	$rc = system("/bin/systemctl start $service_name");
    }
    else {
	showerror("[install apcupsd] unsupported platform: $OS");
	$rc = $EXIT_WRONG_PLATFORM;
    }

    if ($rc == 0) {
	showinfo("[install apcupsd] system service started: $service_name");
    }
    else {
	showerror("[install apcupsd] could not start system service: $service_name");
    }

    return($rc);
}


#
# Uninstall the "readahead" rpm.
#
# Red Hat advises removal of RHEL6 readahead package:
#
# "Under some circumstances, the readahead service may cause
# the auditd service to stop. To work around this potential issue,
# disable the readahead collector by adding the following lines
# to the /etc/sysconfig/readahead configuration file:
#   READAHEAD_COLLECT="no"
#   READAHEAD_COLLECT_ON_RPM="no"
# Alternatively, the readahead package can be removed entirely."
#
sub uninstall_readahead
{
	my $redhat_docs = "http://docs.redhat.com/docs/en-US/";
	my $tech_notes = "Red_Hat_Enterprise_Linux/6/html-single/Technical_Notes/index.html";
	my $url = $redhat_docs . $tech_notes;
	my $rpm = "readahead";

	my $exit_status = $EXIT_OK;
	if ($OS eq "RHEL6") {
	    showinfo("Removing $OS $rpm rpm per Red Hat tech note...");
	    showinfo("Reference: $url");

	    # attempt to remove it
	    system("rpm -qa | grep -q $rpm");
	    if ($? == 0) {
		system("rpm -e $rpm");
	    }
	    # verify
	    system("rpm -qa | grep -q $rpm");
	    if ($? == 0) {
		showerror("Can't remove $rpm rpm");
		$exit_status = $EXIT_READAHEAD;
	    }
	    else {
		showinfo("$OS $rpm rpm removed");
	    }
	}

	return($exit_status);
}


#
# Initialize the console resolution by editing the kernel line
# in the GRUB config file.
#
# Returns 0 for success, non-zero for error
#
sub init_console_res
{
    my $conf_file = "/boot/grub/grub.conf";
    my $new_conf_file = "$conf_file.$$";

    unless ($OS eq "RHEL6") {
	showinfo("Initializing console rez supported on RHEL6 only");
	return(0);
    }

    unless (-e $conf_file) {
	showinfo("Can not initialize console rez: $conf_file: does not exist");
	return(0);
    }

    open(OLD, "< $conf_file");
    open(NEW, "> $new_conf_file");

    my $new_res = "video=640x480";
    my $line = "";
    while (<OLD>) {
	    $line = $_;

	    # look for kernel lines
	    if (/^(\s*)kernel(\s+)/) {

		    # change an existing setting or add one if none
		    if (/video=(\S+)/) {
			$line =~ s/video=(\S+)/$new_res/;
		    }
		    else {
			chomp($line);
			$line .= " $new_res\n";
		    }
		    print(NEW $line);
		    next;
	    }
	    print(NEW);
    }
    close(OLD);
    close(NEW);

    if (-s $new_conf_file) {
	system("mv $new_conf_file $conf_file");
	showinfo("GRUB conf file modified to change console rez: $conf_file");
    }
    else {
	system("rm $new_conf_file");
	showerror("Unexpected: new GRUB conf file has zero size: $new_conf_file");
	showerror("GRUB conf file unchanged: $conf_file");
	return($EXIT_GRUB_CONF);
    }

    return(0);
}


#
# Enable verbose boot messages by editing the kernel line
# in the GRUB config file.
#
# Returns 0 for success, non-zero for error
#
sub enable_boot_msgs
{
    my $conf_file = "/boot/grub/grub.conf";
    my $new_conf_file = "$conf_file.$$";

    unless ($OS eq "RHEL6") {
	showinfo("Enabling boot messages supported on RHEL6 only");
	return(0);
    }

    unless (-e $conf_file) {
	showinfo("Can not enable boot messages: $conf_file: does not exist");
	return(0);
    }

    open(OLD, "< $conf_file");
    open(NEW, "> $new_conf_file");

    my $line = "";
    while (<OLD>) {
	$line = $_;

	# look for kernel lines
	if (/^(\s*)kernel(\s+)/) {

	    # remove "rhgb" from middle of string
	    if ($line =~ / rhgb /) {
		$line =~ s/ rhgb / /;
	    }
	    # remove "rhgb" from end of string
	    elsif ($line =~ / rhgb$/) {
		$line =~ s/ rhgb$//;
	    }

	    # remove "quiet" from middle of string
	    if ($line =~ / quiet /) {
		$line =~ s/ quiet / /;
	    }
	    # remove "quiet" from end of string
	    elsif ($line =~ / quiet$/) {
		$line =~ s/ quiet$//;
	    }
	}

	print(NEW $line);
    }
    close(OLD);
    close(NEW);

    if (-s $new_conf_file) {
	system("mv $new_conf_file $conf_file");
	showinfo("GRUB conf file modified to enable console boot messages: $conf_file");
    }
    else {
	system("rm $new_conf_file");
	showerror("Unexpected: new GRUB conf file has zero size: $new_conf_file");
	showerror("GRUB conf file unchanged: $conf_file");
	return($EXIT_GRUB_CONF);
    }

    return(0);
}


#
# Disable kernel (video) mode setting by editing the kernel line
# in the GRUB config file.
#
# Returns 0 for success, non-zero for error
#
sub disable_kms
{
    my $conf_file = "/boot/grub/grub.conf";
    my $new_conf_file = "$conf_file.$$";

    unless ($OS eq "RHEL6") {
	showinfo("The --disable-kms option is only supported on RHEL6 platforms");
	showinfo("This platform is: $OS");
	return(0);
    }

    unless (-e $conf_file) {
	showinfo("Can not disable kernel mode setting: $conf_file: does not exist");
	return(0);
    }

    open(OLD, "< $conf_file");
    open(NEW, "> $new_conf_file");

    my $new_string = "nomodeset";
    my $line = "";
    my $lines_changed = 0;
    while (<OLD>) {
	    $line = $_;

	    # look for kernel lines
	    if (/^(\s*)kernel(\s+)/) {

		    # add kernel parameter if it does not exist
		    unless (/nomodeset/) {
			chomp($line);
			$line .= " $new_string\n";
			$lines_changed++;
		    }
		    print(NEW $line);
		    next;
	    }
	    print(NEW);
    }
    close(OLD);
    close(NEW);

    if ($lines_changed == 0) {
	system("rm $new_conf_file");
	showinfo("GRUB conf file unchanged: $conf_file");
    }
    elsif (-s $new_conf_file) {
	system("mv $new_conf_file $conf_file");
	showinfo("GRUB conf file modified to change/add nomodeset: $conf_file");
	showinfo("Number of lines changed: $lines_changed");
    }
    else {
	system("rm $new_conf_file");
	showerror("Unexpected: new GRUB conf file has zero size: $new_conf_file");
	showerror("GRUB conf file unchanged: $conf_file");
	return($EXIT_GRUB_CONF);
    }

    return(0);
}


sub uos_rewrite_grub2_conf
{
    my ($ofh, $nfh) = @_;

    while (my $line = <$ofh>) {

	# look for kernel lines
	if ($line =~ /^\s*GRUB_CMDLINE_LINUX\s*=/) {

	    # add
	    if ($line !~ /nomodeset/) {
		$line =~ s/\"$/ nomodeset\"/;
	    }

	    # add
	    if ($line !~ /video=640x480/) {
		$line =~ s/\"$/ video=640x480\"/;
	    }

	    #remove
	    if ($line =~ / rhgb /) {
		$line =~ s/ rhgb / /;
	    }
	    elsif ($line =~ / rhgb\"/) {
		$line =~ s/ rhgb\"/\"/;
	    }

	    #remove
	    if ($line =~ / quiet /) {
		$line =~ s/ quiet / /;
	    }
	    elsif ($line =~ / quiet\"/) {
		$line =~ s/ quiet\"/\"/;
	    }
	}

	print {$nfh} $line;
    }

    return(1);
}

sub uos_edit_grub2_conf
{
    my ($conf_file) = @_;

    my $rc = 0;

    my $new_conf_file = "$conf_file.$$";

    if (open(my $ofh, '<', $conf_file)) {
	if (open(my $nfh, '>', $new_conf_file)) {
	    if (uos_rewrite_grub2_conf($ofh, $nfh)) {
		loginfo("[edit_grub2] GRUB2 conf file rewrite successful: $conf_file");
		$rc = 1;
	    }
	    else {
		logerror("[edit_grub2] could not rewrite GRUB2 conf file: $conf_file");
	    }
	    close($nfh);
	}
	else {
	    logerror("[edit_grub2] could not open for write: $new_conf_file");
	}
	close($ofh);
    }
    else {
	logerror("[edit_grub2] could not open for read: $conf_file");
    }

    if ($rc) {
	$rc = uos_rename_conf($new_conf_file, $conf_file);
	if ($rc == 1) {
	    system("grub2-mkconfig > /boot/grub2/grub.cfg");
	}
    }

    return($rc);
}


sub uos_configure_grub2
{
    my $conf_file = uos_pathto_grub2_conf();

    my $rc = $EXIT_OK;

    if (-f $conf_file) {
	if (uos_edit_grub2_conf($conf_file)) {
	    showinfo("[configure_grub2] GRUB2 reconfigured: $conf_file");
	}
	else {
	    showerror("[configure_grub2] could not reconfigure GRUB2 $conf_file");
	    $rc = $EXIT_GRUB2_CONFIGURE;
	}

    }
    else {
	showerror("[configure_grub2] GRUB2 conf file does not exist: $conf_file");
	$rc = $EXIT_GRUB2_CONF_MISSING;
    }

    return($rc);
}


sub uos_update_syslog_mark_period
{
    my ($ofh, $nfh, $syslog_mark_period) = @_;

    if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	my $syslog_mark_secs = $syslog_mark_period * 60;
	print {$nfh} "# BEGIN --syslog-mark lines added by $PROGNAME $CVS_REVISION\n";
	print {$nfh} "\$ModLoad immark.so\n";
	print {$nfh} "\$MarkMessagePeriod $syslog_mark_secs\n";
	print {$nfh} "# END --syslog-mark lines added by $PROGNAME $CVS_REVISION\n";
    }

    while (<$ofh>) {
	if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	    next if (/^# BEGIN --syslog-mark lines added by $PROGNAME/);
	    next if (/^# END --syslog-mark lines added by $PROGNAME/);
	    next if (/^\$ModLoad\s+immark/);
	    next if (/^\$MarkMessagePeriod\s+\d/);
	}
	else {
	    if (/^(SYSLOGD_OPTIONS=\"-m\s+)(\d+)(.*)$/) {
		print {$nfh} "${1}$syslog_mark_period${3}\n";
		next;
	    }
	}

	print {$nfh} "$_";
    }

    return(1);
}


sub uos_update_syslog_klogd_options
{
    my ($ofh, $nfh, $klog_msg_priority) = @_;

    #
    # Always put the modload and configuration directives first in
    # the config file.
    #
    if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	print {$nfh} "# BEGIN --klog-msg-priority lines added by $PROGNAME $CVS_REVISION\n";
	print {$nfh} "\$ModLoad imklog.so\n";
	print {$nfh} "\$klogConsoleLogLevel $klog_msg_priority\n";
	print {$nfh} "# END --klog-msg-priority lines added by $PROGNAME $CVS_REVISION\n";
    }

    my $file_modified = 0;

    while (<$ofh>) {

	# remove any old modload and configuration directives
	if ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) {
	    next if (/^# BEGIN --klog-msg-priority lines added by $PROGNAME/);
	    next if (/^# END --klog-msg-priority lines added by $PROGNAME/);
	    next if (/^\$ModLoad\s+imklog/);
	    next if (/^\$klogConsoleLogLevel\s+\d/);
	}

	# old style
	else {
	    if (/^KLOGD_OPTIONS=/ && $file_modified) {
		next;
	    }

	    # handle case where KLOGD appears with "-c"
	    if (/^(KLOGD_OPTIONS=\")(.*)(-c\s*\d)(.*\")$/) {
		print {$nfh} "${1}${2}-c $klog_msg_priority${4}\n";
		$file_modified = 1;
		next;
	    }
	    # then KLOGD appears but no "-c"
	    elsif (/^(KLOGD_OPTIONS=\")(.*\")$/) {
		print {$nfh} "${1}-c $klog_msg_priority ${2}\n";
		$file_modified = 1;
		next;
	    }
	}

	print {$nfh} "$_";
    }

    return(1);
}


sub uos_update_syslog_kernel_target
{
    my ($ofh, $nfh, $syslog_kern_target) = @_;

    while (<$ofh>) {
	if (/^kern\..*/) {
	    next;
	}
	print {$nfh} "$_";
    }

    print {$nfh} "kern.*\t\t\t\t\t\t\t$syslog_kern_target\n";

    return(1);
}


sub uos_edit_syslog_conf
{
    my ($conf_file, $syslog_conf_op_type, $syslog_conf_op_value) = @_;

    my $rc = 0;

    my $new_conf_file = "$conf_file.$$";

    if (open(my $ofh, '<', $conf_file)) {
	if (open(my $nfh, '>', $new_conf_file)) {
	    if ($syslog_conf_op_type eq $SYSLOG_OPTYPE_KERN_MSG_PRIORITY) {
		$rc = uos_update_syslog_klogd_options($ofh, $nfh, $syslog_conf_op_value);
	    }
	    elsif ($syslog_conf_op_type eq $SYSLOG_OPTYPE_MARK_INTERVAL) {
		$rc = uos_update_syslog_mark_period($ofh, $nfh, $syslog_conf_op_value);
	    }
	    elsif ($syslog_conf_op_type eq $SYSLOG_OPTYPE_KERN_TARGET) {
		$rc = uos_update_syslog_kernel_target($ofh, $nfh, $syslog_conf_op_value);
	    }
	    else {
		logerror("[edit syslog conf] unknown edit operation: $syslog_conf_op_type");
	    }

	    if ($rc) {
		loginfo("[edit syslog conf] syslog conf file rewrite successful: $conf_file");
	    }
	    else {
		logerror("[edit syslog conf] could not rewrite syslog conf file: $conf_file");
	    }
	    close($nfh);
	}
	else {
	    logerror("[edit syslog conf] could not open for write: $conf_file");
	}
	close($ofh);
    }
    else {
	logerror("[edit syslog conf] could not open for read: $conf_file");
    }

    if ($rc) {
	$rc = uos_rename_conf($new_conf_file, $conf_file);
    }

    return($rc);
}


#
# restart the syslog system service
#
# returns
#   1 on success
#   0 if error
#
sub uos_syslog_service_restart
{
    my ($service_name) = @_;

    my $rc = 1;

    my $exit_status = 1;
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	$exit_status = system("/sbin/service $service_name restart");
    }
    if ($OS eq 'RHEL7') {
	$exit_status = system("/bin/systemctl restart $service_name");
    }

    $rc = ($exit_status == 0) ? 1 : 0;

    return($rc);
}


#
# configure the kernel log message priority
#
# For RHEL5 systems:
#   Edit the configuration file "/etc/sysconfig/syslog"
#   Change the value of the "KLOGD_OPTIONS" variable
#
# For RHEL6 and RHEL7 systems:
#   Edit the configuration file "/etc/rsyslog.conf"
#   Load the input module "imklog.so"
#   Set the "$klogConsoleLogLevel" configuration directive
#
# returns
#   $EXIT_OK on success
#   non-zero if error
#
sub uos_configure_klog_msg_priority
{
    my ($klog_msg_priority) = @_;

    if ( ($klog_msg_priority < 0) || ($klog_msg_priority > 7) ) {
	showerror("[config klog priority] kernel log message priority must be >= 0 and <= 7");
	return($EXIT_SYSLOG_KERN_PRIORITY_VALUE);
    }

    my $conf_file = uos_pathto_syslog_conf($OS);

    unless (-e $conf_file) {
	showerror("[config klog priority] syslog conf file does not exist: $conf_file");
	return($EXIT_SYSLOG_CONF_MISSING);
    }

    if ($OS eq 'RHEL5') {
	if (ost_util_fgrep($conf_file, 'KLOGD_OPTIONS=')) {
	    showerror("[config klog priority] non-standard syslog conf file: $conf_file");
	    return($EXIT_SYSLOG_CONF_CONTENTS);
	}
    }

    my $rc = $EXIT_OK;

    if (uos_edit_syslog_conf($conf_file, $SYSLOG_OPTYPE_KERN_MSG_PRIORITY, $klog_msg_priority)) {
	showinfo("[config klog priority] kernel log priority configured to: $klog_msg_priority");
    }
    else {
	showerror("[config klog priority] could not configure kernel log priority to: $klog_msg_priority");
	$rc = $EXIT_SYSLOG_KERN_PRIORITY;
    }

    my $service_name = ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) ? "rsyslog" : "syslog";
    if (uos_syslog_service_restart($service_name)) {
	showinfo("[config klog priority] system service restarted: $service_name");
    }
    else {
	showerror("[config klog priority] could not restart system service: $service_name");
	$rc = $EXIT_SYSLOG_RESTART;
    }

    return($rc);
}


#
# configure the syslog periodic mark message
#
# For rsyslog on RHEL6 and RHEL7:
#
# You must add two directives to the beginning of the conf file;
# the first to load the "immark" module, and the second to set
# the value of "MarkMessagePeriod" to the number of seconds
# between messags.
#
# Example:
#
# $ModLoad immark.so
# $MarkMessagePeriod 1200
#
# The value of "MarkMessagePeriod" specifies how often mark messages are
# to be written to output modules.  The time specified is in seconds.
# Specifying 0 is possible and disables mark messages. In that case,
# however, it is more efficient to NOT load the immark input module.
# Last directive to appear in file wins.  This directive is only
# available after the "immark" input module has been loaded.
#
# For syslog on RHEL5 and previous platforms:
#
# Set the value of the "-m" syslogd option to a non-zero value.  The
# default value is 20, which means 20 minutes between mark messages.
#
# Returns 0 for success, non-zero for error
#
sub uos_configure_syslog_mark
{
    my ($syslog_mark_period) = @_;	# value is in minutes

    if ($syslog_mark_period < 0) {
	showerror("[config syslog mark] syslog mark period must be >= 0");
	return($EXIT_SYSLOG_MARK_VALUE);
    }

    my $conf_file = uos_pathto_syslog_conf($OS);

    unless (-e $conf_file) {
	showerror("[config syslog mark] syslog conf file does not exist: $conf_file");
	return($EXIT_SYSLOG_CONF_MISSING);
    }

    if ($OS eq 'RHEL5') {
	if (ost_util_fgrep($conf_file, 'SYSLOGD_OPTIONS=\"-m')) {
	    showerror("[config syslog mark] non-standard syslog conf file: $conf_file");
	    showerror("[config syslog mark] 'SYSLOGD_OPTIONS' variable missing or has unexpected format");
	    return($EXIT_SYSLOG_CONF_CONTENTS);
	}
    }

    my $rc = $EXIT_OK;

    if (uos_edit_syslog_conf($conf_file, $SYSLOG_OPTYPE_MARK_INTERVAL, $syslog_mark_period)) {
	showinfo("[config syslog mark] syslog mark period configured to: $syslog_mark_period");
    }
    else {
	showerror("[config syslog mark] could not configure syslog mark period to: $syslog_mark_period");
	$rc = $EXIT_SYSLOG_MARK_PERIOD;
    }

    my $service_name = ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) ? "rsyslog" : "syslog";
    if (uos_syslog_service_restart($service_name)) {
	showinfo("[config syslog mark] system service restarted: $service_name");
    }
    else {
	showerror("[config syslog mark] could not restart system service: $service_name");
	$rc = $EXIT_SYSLOG_RESTART;
    }

    return($rc);
}


#
# configure the target for kernel syslog messages
#
# returns
#   $EXIT_OK on success
#   non-zero exit status code on error
#
sub uos_configure_syslog_kernel_target
{
    my ($syslog_kern_target) = @_;

    if ($syslog_kern_target eq $EMPTY_STR) {
	showerror("[syslog kern target] kernel message target value empty");
	return($EXIT_SYSLOG_KERN_TARGET_VALUE);
    }

    my $conf_file = uos_pathto_syslog_conf($OS);

    unless (-e $conf_file) {
	showerror("[syslog kern target] syslog conf file does not exist: $conf_file");
	return($EXIT_SYSLOG_CONF_MISSING);
    }

    my $rc = $EXIT_OK;

    if (uos_edit_syslog_conf($conf_file, $SYSLOG_OPTYPE_KERN_TARGET, $syslog_kern_target)) {
	showinfo("[syslog kern target] syslog kernel target configured to: $syslog_kern_target");
    }
    else {
	showerror("[syslog kern target] could not configure syslog kernel target to: $syslog_kern_target");
	$rc = $EXIT_SYSLOG_KERN_TARGET;
    }

    my $service_name = ( ($OS eq 'RHEL6') || ($OS eq 'RHEL7') ) ? "rsyslog" : "syslog";
    if (uos_syslog_service_restart($service_name)) {
	showinfo("[syslog kern target] system service restarted: $service_name");
    }
    else {
	showerror("[syslog kern target] could not restart system service: $service_name");
	$rc = $EXIT_SYSLOG_RESTART;
    }

    return($rc);
}


sub configure_kernel_boot_param
{
    my ($param_string, $param_value) = @_;

    return(0);
}


#
# rewrite lines of the form:
#   root=LABEL=/
# to:
#   root=/dev/blah
#
sub uos_rewrite_boot_config
{
    my ($old, $new, $mount_point, $devname) = @_;

    while (my $line = <$old>) {
	if ($line =~ /root=LABEL= \s* $mount_point/x) {
	    $line =~ s/root=LABEL= \s* $mount_point/root=$devname/x;
	}
	print {$new} $line;
    }

    return(1);
}


#
# edit the grup config file to convert the "root=LABEL" to
# "root=DEVICE" format.
#
# returns
#   1 on success
#   0 if error
#
sub uos_edit_boot_config
{
    my ($conf_file, $mount_point, $devname) = @_;

    my $rc = 1;

    my $new_conf_file = "$conf_file.$$";

    if (open(my $old, '<', $conf_file)) {
	if (open(my $new, '>', $new_conf_file)) {
	    uos_rewrite_boot_config($old, $new, $mount_point, $devname);
	    close($new);
	}
	else {
	    logerror("[edit boot config] could not open file for write: $new_conf_file");
	    $rc = 0;
	}

	close($old);
    }
    else {
	logerror("[edit boot config] could not open file for read: $conf_file");
	$rc = 0;
    }

    system("mv $new_conf_file $conf_file");

    return($rc);
}


#
# Modify /etc/fstab
#
# Input:
#   contents of "fs_spec" field (first field)
#   device name to be used in place of current "fs_spec" field
#   mount point
#
# Output:
#   (possibly) rewritten /etc/fstab
#
# Returns
#   1 if fstab changed
#   0 if fstab unchanged
#
sub modify_fstab
{
    my ($fs_spec, $devname, $mount_point) = @_;

    my $fstab_path = '/etc/fstab';
    my $new_fstab_path = "$fstab_path.$$";
    my @fields = ();
    my $changed = 0;

    if (open(my $oldfh, '<', $fstab_path)) {
	if (open(my $newfh, '>', $new_fstab_path)) {
	    while (<$oldfh>) {
		# if first field matches, substitute edited line
		if (/^(\s*)($fs_spec)(\s+)(.+)/) {
		    @fields = split(/\s+/);
		    print {$newfh} "$devname\t$mount_point";
		    print {$newfh} "\t$fields[2]\t$fields[3]\t$fields[4] $fields[5]\n";
		    $changed = 1;
		}
		# preserve line if no match
		else {
		    print {$newfh} $_;
		}
	    }
	    close($newfh);
	}
	close($oldfh);
    }

    # if the fstab was changed, replace old version with new.
    # else, remove new one.
    if ($changed) {
	system("mv $new_fstab_path $fstab_path");
    }
    else {
	system("rm $new_fstab_path");
    }

    return($changed);
}


#
# Given the "fs_spec" field from the fstab in the form of either
# "LABEL=string" or "UUID=string", match that to the output of
# the blkid command and convert to a device name.
#
# Note, the fstab field does not have the parameter value in QUOTES
# while the blkid does.
#
# Input:
#	file system id in the form of either LABEL=string or UUID=string
#
# Returns:
#	the block special device name
#
sub filesystem_id_to_devname
{
    my ($id) = @_;

    my $devname = "";

    my $cmd = '/sbin/findfs';
    system("$cmd $id > /dev/null 2> /dev/null");
    if ($? == 0) {
	$devname = qx($cmd $id);
	chomp $devname;
    }
    else {
	showerror("Could not convert filesys id to devname: $cmd returned non-zero exit status");
    }

    loginfo("Filesystem id $id converted to devname: $devname");

    return($devname);
}


#
# Given the mount point, Get the "fs_spec" field from the fstab 
#
# Input:
#	the "file system mount point", ie the second field of an fstab entry,
#	named the "fs_file" field
#
# Return:
#	return the "block special device name", ie the first field of the
#	fstab entry, the "fs_spec" field.
#
# Note, the "block special device name" could be one of several forms, even an
# actual device name but what we are looking for is:
#
# 1) LABEL=/teleflora
# 2) UUID=d78cf896-6f1a-4bb7-a2d7-71e4c2ee7d18
#
sub get_fstab_info
{
    my ($mount_point) = @_;

    my $fs_spec = "";
    my $uuid = "";
    my @fstab_entry = ();

    my $fstab_path = '/etc/fstab';
    if (open(my $fh, '<', $fstab_path)) {
	while (<$fh>) {

	    # skip comments or blank lines
	    next if ( (/^(\s*)#/) || (/^(\s*)$/) );

	    # break line into fields
	    @fstab_entry = split(/\s+/);
	    next unless (@fstab_entry);

	    if ($mount_point eq $fstab_entry[1]) {
		$fs_spec = $fstab_entry[0];
		last;
	    }
	}
	close($fh);
    }
    else {
	logerror("[fstab info] could not open fstab: $fstab_path");
    }

    return($fs_spec);
}


#
# By default, RHEL5 mounts file systems based on disk label and
# RHEL6 mounts file systems  based on UUID.
#
# Input:
#   current mount point of the file system
#   desired new mount point of the file system
#
# Returns:
#   0 for success
#   non-zero for error
#
# Side effects:
#   This function modifies /etc/fstab to remove Label based or
#   UUID based mounting for RHEL5 and RHEL6 respectively and
#   instead, uses block special device names in the first field
#   of the fstab.
#
sub remount_filesystem
{
    my ($mount_point, $new_mount_point) = @_;

    my $devname = "";
    my $fs_spec = "";

    if ($mount_point ne "/") {
	my $cwd = getcwd();
	if ($cwd =~ /^$mount_point/) {
	    showerror("[remount] cwd resides within file system to be remounted: $mount_point");
	    return(2);
	}
    }

    # get fs_spec field (first field) from fstab
    $fs_spec = get_fstab_info($mount_point);
    if ($fs_spec eq "") {
	showerror("[remount] could not find mount point in fstab: $mount_point");
	return(1);
    }

    # if the fs_spec field is in form of "LABEL=" or "UUID=", then use
    # the blkid command to convert to device name
    if ( ($fs_spec =~ /LABEL=/) || ($fs_spec =~ /UUID=/) ) {
	$devname = filesystem_id_to_devname($fs_spec);
    }
    else {
	$devname = $fs_spec;
    }

    showinfo("[remount] re-mounting: old: $fs_spec mounted on $mount_point");
    showinfo("[remount] re-mounting: new: $devname mounted on $new_mount_point");

    if ($new_mount_point ne "/") {
	system("umount $mount_point");
	if ($? != 0) {
	    logerror("[remount] warning: could not umount <$mount_point>");
	}
    }

    showinfo("[remount] re-writing fstab: changing entry with file system id $fs_spec to device $devname");
    if (modify_fstab($fs_spec, $devname, $new_mount_point)) {
	showinfo("[remount] fstab changed");
    }
    else {
	showinfo("[remount] fstab unchanged");
    }

    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	# for the root partition, we also need to modify grub.conf
	if ($mount_point eq "/") {
	    my $conf_file = uos_pathto_grub_conf();
	    if (uos_edit_boot_config($conf_file, $mount_point, $devname)) {
		loginfo("[remount] grub config file rewritten: $conf_file");
	    }
	    else {
		logerror("[remount] could not rewrite grub config file: $conf_file");
	    }
	}
    }

    # Make the new mount points if necessary.
    if( ("$new_mount_point" ne "swap") && (! -d "$new_mount_point") ) {
	system("mkdir -p $new_mount_point");
    }

    if ("$new_mount_point" ne "/") {
	system("mount $new_mount_point");
    }

    return(0);
}


#
# Input:
#	content type the block device holds
#
# Returns:
#	the LABEL or UUID field and the device name field
#
sub get_blkid_info
{
    my ($type) = @_;
    my $blkid_cmd = '/sbin/blkid';

    unless (open(PIPE, "$blkid_cmd |")) {
	showerror("Could not remount swap partition: could not run $blkid_cmd");
	return(2);
    }

    # get the device name and the "fs_spec" from the output of blkid
    my @fields = ();
    my $devname = "";
    my $fs_spec = "";
    my $content_type = "TYPE=\"$type\"";
    while(<PIPE>) {
	next until /$content_type/;

	@fields = split(/:/);
	$devname = $fields[0];

	@fields = split(/\s+/, $fields[1]);
	foreach my $field (@fields) {
	    if ( ($field =~ /LABEL=".+"/) || ($field =~ /UUID=".+"/) ) {
		$fs_spec = $field;
		last;
	    }
	}

	last;
    }
    close(PIPE);

    my @info_list = ($fs_spec, $devname);
    return(@info_list);
}


#
# The output of the blkid(8) command has everything we need...
# each line will be:
#
#   device name: parameter="value"...
#
# if there is a label, the line will have:
#   LABEL="label"
# if there is a UUID, the line will have:
#   UUID="uuid"
# for the swap partition, the line will have:
#   TYPE="swap"
#
sub remount_swap
{
    my $fs_spec = "";
    my $devname = "";

    # The "blkid" command provides info about the swap device:
    # 1) the fstab "fs_spec" field
    # 2) the device name
    ($fs_spec, $devname) = get_blkid_info("swap");
    if ( ($devname eq "") || ($fs_spec eq "") ) {
	logerror("[remount swap] blkid did not return info on swap device");
	return("");
    }

    # first, disable swap
    system("swapoff $devname");
    if ($? == 0) {
	loginfo("[remount swap] swap disabled: $devname");
    }
    else {
	logerror("[remount swap] could not disable swap: $devname");
	return("");
    }

    #
    # At this point, the fs_spec field looks like:
    #
    #	LABEL="label" or UUID="uuid"
    #
    # so we need to get rid of the quotes because fstab entries do not
    # use quotes around the value.
    #
    $fs_spec =~ s/"//g;

    # edit the fstab entry
    if (modify_fstab($fs_spec, $devname, "swap")) {
	loginfo("[remount swap] fstab changed");
    }
    else {
	loginfo("[remount swap] fstab unchanged");
    }

    # now, re-enable swap - it's now using a device in the
    # fstab instead of a label (RHEL5) or a UUID (RHEL6).
    system("swapon $devname");
    if ($? == 0) {
	loginfo("[remount swap] swap re-enabled: $devname");
    }
    else {
	logerror("[remount swap] could not re-enable swap: $devname");
	return("");
    }

    return($devname);
}


#
# find all processes holding the filesystem on specified device open, and
# kill them.
#
# lsof command looks like:
# $ sudo /usr/sbin/lsof /usr4
#
# command output looks like:
# COMMAND  PID USER   FD   TYPE DEVICE SIZE   NODE NAME
# bash    4283   jj  cwd    DIR  104,2 4096 961291 /usr4/jj/rev
#
# returns
#   1
#
sub uos_kill_obstructing_processes
{
    my ($device) = @_;

    if (open(my $lsof, '-|', "/usr/sbin/lsof $device")) {
	while (<$lsof>) {
	    chomp;
	    my @lsof_output = split(/\s+/);
	    my $pid = $lsof_output[1];
	    next if ($pid eq $EMPTY_STR);
	    next if ($pid eq "PID");
	    system("kill -HUP $pid");
	    system("kill -TERM  $pid");
	    system("kill -INT $pid");
	    system("kill -KILL $pid");
	    showinfo("[kill proc] HUP, TERM, INT, KILL sent to pid: $pid");
	}
	close($lsof);
    }

    return(1);
}


#
# umount the specified filesystem
#
sub uos_umount_filesystem
{
    my ($mountpoint, $device) = @_;

    print("Unmounting $mountpoint -> $device");
    system("umount $device");
    if ($? == 0) {
	showinfo("[umount filesys] filesystem unmounted: $device");
    }
    else {
	system("umount -f $device");
	if ($? == 0) {
	    showinfo("[umount filesys] filesystem unmounted by force: $device");
	}
	else {
	    showerror("[umount filesys] could not unmount $mountpoint -> $device");
	}
    }

    return(1);
}


sub uos_umount_all_filesystems
{
    my ($mountfh) = @_;

    my $device = $EMPTY_STR;
    my $mountpoint = $EMPTY_STR;

    while (my $line = <$mountfh>) {
	chomp($line);
	next until($line =~ m/ext[234]/);

	my @mount_info = split(/\s+/, $line);
	my $device = $mount_info[0];
	my $mountpoint = $mount_info[1];
	next if ($device eq $EMPTY_STR);
	next if ($mountpoint eq $EMPTY_STR);
	next if ($mountpoint eq '/');
	next if ($mountpoint eq '/proc');
	next if (! -b $device);

	uos_kill_obstructing_processes($device);

	uos_umount_filesystem($mountpoint, $device);
    }

    return($mountpoint, $device);
}


#
# Unmount all filesystems except '/'
# Useful if we need to perform a "power button" shutdown, to ensure that most of our 
# filesystems don't come up in a 'dirty' state.
#
# Notes:
# We explicity do not run 'sync' as, I have experienced in the past, cases where 'sync' hung,
# I believe because the backup device could not sync, and, "sync" works on all devices.
# The filesystem caches are all sycned when the FS is unmounted.
# This function should be run as root.
#
sub uos_hard_reboot
{
    my $pid = -1;
    my $childpid = -1;
    my $i = 0;

    showinfo("[hard reboot] performing hard reboot");

    # Run the "regular" shutdown here. If that works as expected, we should never actually
    # finish this function, as, we will be killed off.
    $pid = fork();
    if ($pid == 0) {
	exec("/sbin/shutdown -r now");
    }
    for ($i = 0; $i < 120; $i++) {
	$childpid = waitpid($pid, WNOHANG);
	last if ($childpid != 0);
	sleep(1);
    }
    if ($childpid < 0) {
	showinfo("waitpid() on PID $pid returned $childpid.");
    }

    if ($i >= 120) {
	showerror("We waited long enough (2 mins) for our shutdown to finish. Will manually reboot.");
	system("kill -TERM $pid");
    }
    else {
	showerror("the 'shutdown' sub process terminated in $i seconds, without terminating this process.");
	return(1);
    }

    # If we get this far, though "shutdown" ran, it never actually did anything.
    # We have seen this in the field in cases where sync() hangs (and hence, the 'shutdown' process 
    # also hangs.
    # At this point, we will manually unmount disks, kill off processes, and reboot the computer.
    # Note! Make sure *not* to run 'sync', as, that will almost certainly hang.
    showinfo("[hard reboot] server did not reboot normally, issuing hard reboot");
    sleep(5);

    # stop file sharing, email, and pos app
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	system("/sbin/service smb stop");
	system("/sbin/service sendmail stop");
	if (-f "/etc/init.d/rti") {
	    system("/sbin/service rti stop");
	}
	if ($DAISY) {
	    uos_daisy_stop();
	}
    }

    # If things are this un-healthy, then, we may have underlying disk issues.
    # If we simply reboot without the '/fsckoptions' file, then, chances are, the flower shop
    # owner will be presented with an ugly prompt saying 'fsck failed', and a '#' prompt.
    # By adding this particular file, according to /etc/rc.d/rc.sysinit, FSCK will use these
    # "force" and "dammit" options, thereby sparing the florist from having to type stuff in.
    if (open(my $fsckfh, '>', '/fsckoptions')) {
	print {$fsckfh} "-f -v -y\n";
	close($fsckfh);
    }
    else {
	showerror("[hard reboot] could not write fsck options file: /fsckoptions");
    }

    #
    # umount all the file systems.
    #
    if (open(my $mountfh, '<', '/proc/mounts')) {
	uos_umount_all_filesystems($mountfh);
	close($mountfh);
    }

    #
    # Try to do a standard reboot at this point, though we have seen
    # instances in the field where this does not work.
    #
    system("/sbin/reboot -n -f");

    #
    # This is the atom bomb for causing a reboot...
    #
    # For background on what the code below does, read this article:
    #	http://www.linuxjournal.com/content/rebooting-magic-way
    #
    system("echo 1 > /proc/sys/kernel/sysrq");
    system("echo b > /proc/sysrq-trigger");

    #
    # Should not reach this point... the system should have rebooted
    # before this.
    #

    return(2);
}



#
# Many of our original T300 servers came shipped with a swap partition in place, yet,
# a bug in /etc/fstab which would cause the swap partition to never "swapon".
# This routing fixes said bug.
#
sub swapon
{
    my @partitions = ();
    my @array = ();

    my $rc = $EXIT_OK;

    # only RTI systems
    if (-d "/d/daisy") {
	showinfo("[swapon] will not update swap space on a Daisy system.");
	return ($rc);
    }

    showinfo("[swapon] enabling swap space...");

    # Which partitions are formatted for swap?
    foreach my $thisdisk ("/dev/sda", "/dev/sdb") {
	if (open(my $fdisk, '-|', "/sbin/fdisk -l $thisdisk")) {
	    while (<my $fdisk>) {
		next until(/^\/dev\//);
		next unless(/(Linux)(\s+)(swap)/);
		@array = split(/\s+/);
		my $thispart = $array[0];
		if (-b "$thispart") {
		    push(@partitions, $thispart);
		}
	    }
	    close(my $fdisk);
	}
    }

    # were any swap partitions found?
    if ($#partitions < 0) {
	showerror("[swapon] no swap partitions were found on: /dev/sda or /dev/sdb");
	return($EXIT_NO_SWAP_PARTITIONS);
    }

    showinfo("[swapon] updating /etc/fstab...");

    # Modify /etc/fstab
    if (open(my $old, '<', '/etc/fstab')) {
	if (open(my $new, '>', "/etc/fstab.$$")) {
	    while (<$old>) {
		next if(/(\s+)(swap)(\s+)/);
		print {$new} $_;
	    }

	    # Record our known swap partitions.
	    foreach my $thispart (sort(@partitions)) {
		print {$new} "$thispart\t\tswap\t\tswap\tdefaults\t\t0\t0\n";
	    }
	    close($new);
	}
	else {
	    showerror("[swapon] could not open /etc/fstab.$$ for write");
	    $rc = $EXIT_MODIFY_FSTAB;
	}
	close($old);
    }
    else {
	showerror("[swapon] could not open /etc/fstab for read");
	$rc = $EXIT_MODIFY_FSTAB;
    }

    if ($rc == $EXIT_OK) {
	if (-s "/etc/fstab.$$" <= 0) {
	    showerror("[swapon] could not make new fstab file");
	    $rc = $EXIT_MODIFY_FSTAB;
	}
	else {
	    system("mv /etc/fstab.$$ /etc/fstab");

	    # Enable our swap partitions.
	    foreach my $thispart (sort(@partitions)) {
		showinfo("[swapon] enabling swap partition: $thispart");
		system("/sbin/mkswap $thispart");
		system("/sbin/swapon $thispart");
	    }

	    system("cat /proc/meminfo | grep Swap");

	    showinfo("[swapon] swap space updated");
	}
    }

    return($rc);
}


#
# report how big to make the swap device based on the amount of RAM.
#
# RedHat recommends 4 GB of swap for up to 3 GB of memory and
# ($mem_total + 2) GB for anything 4 GB of RAM or over.
#
# returns
#	1 for success
#	0 for error
#
sub uos_report_swap_size
{
    my ($meminfo_file) = @_;

    my $rc = $EXIT_OK;

    unless ($meminfo_file) {
	$meminfo_file = '/proc/meminfo';
    }
    my $ram_size = 0;

    if (open(my $pipe, '-|', "cat $meminfo_file")) {
	while (my $line=<$pipe>) {
	    if ($line =~ /MemTotal:\s*(\d+)\s+kB/) {
		$ram_size = $1;
	    }
	}
	close($pipe);
    }
    else {
	logerror("[swap size] could not info on RAM size: $meminfo_file"); 
	$rc = $EXIT_RAMINFO;
    }
    
    if ($ram_size > 0) {
	# convert from kb to GB
	$ram_size = int($ram_size / 1024);
	$ram_size = int($ram_size / 1024);
	$ram_size += (($ram_size + 2) % 2);
	if ($ram_size < 4) {
	    print "4096";
	}
	else {
	    printf "%s", ($ram_size * 1024) + 2048;
	}
    }

    return($rc);
}


#
# report the processor architecture
#
# returns
#   $EXIT_OK on success
#   non-zero if error
#
sub uos_report_architecture
{
    my $rc = $EXIT_OK;

    my $arch = get_arch_info();

    if ($arch) {
	print "$arch\n";
    }
    else {
	print "could not determine processor architecture - assuming: i386";
    }

    return($rc);
}


#
# Remove files from /var/spool/cups/tmp
# Earlier versions of RTI would leave behind lots of zero byte files in 
# this directory.
#
sub cups_clean_tempfiles
{
	showinfo("Cleanup CUPS Temporary Files...");
	system("find /var/spool/cups/tmp -type f -size 0b -print | xargs rm -f");
	if (-d '/usr2/bbx/bbxtmp') {
		system("find /usr2/bbx/bbxtmp -type f -size 0b -print | xargs rm -f");
	}
	return(0);
}


sub uos_add_rules_cups_conf
{
    my ($nfh) = @_;

    print {$nfh} "#updateos.pl# --- Start of additional lines ---\n";
    print {$nfh} "#updateos.pl# $PROGNAME $CVS_REVISION $TIMESTAMP\n";
    print {$nfh} "MaxJobs 10000\n";
    print {$nfh} "PreserveJobHistory No\n";
    print {$nfh} "PreserveJobFiles No\n";

    if ($OS eq "RHEL6" || $OS eq "RHEL7") {
	print {$nfh} "Timeout $CUPSCONF_RHEL6_TIMEOUT\n";
    }
    else {
	print {$nfh} "Timeout $CUPSCONF_RHEL5_TIMEOUT\n";
    }

    print {$nfh} "ErrorPolicy retry-job\n";
    print {$nfh} "#updateos.pl# --- End of additional lines ---\n";

    return(1);
}


sub uos_rewrite_cups_conf
{
    my ($ofh, $nfh) = @_;

    while (<$ofh>) {

	next if (/^#updateos.pl#/);

	#
	# CUPS has a default "max jobs" set to 500. For some of the
	# larger shops, this print queue size is too small.
	# Set the "Max Jobs" setting to a higher value.
	#
	if ($CUPSCONF_MAXJOBS) {
	    if(/^(\s*)(MaxJobs)(\s+)/) {
		print {$nfh} "#updateos.pl# $_";
		next;
	    }
	}

	#
	# Don't put files into /var/spool/cups/tmp at all.
	# Thus eliminating the need for the "cleanfiles"
	# patch elsewhere in this script.
	#
	if ($CUPSCONF_DISABLETEMPFILES) {
	    if (/^(\s*)(PreserveJobHistory)(\s+)/i) {
		print {$nfh} "#updateos.pl# $_";
		next;
	    }
	    if (/^(\s*)(PreserveJobFiles)(\s+)/i) {
		print {$nfh} "#updateos.pl# $_";
		next;
	    }
	}

	if ($CUPSCONF_TIMEOUTS) {
	    if (/^(\s*)(Timeout)(\s+)/i) {
		print {$nfh} "#updateos.pl# $_";
		next;
	    }
	}

	if ($CUPSCONF_ERRORPOLICY) {
	    if (/^(\s*)(ErrorPolicy)(\s+)/i) {
		print {$nfh} "#updateos.pl# $_";
		next;
	    }
	}
	print {$nfh} "$_";
    }

    # now that the old values are gone, add the new rules
    uos_add_rules_cups_conf($nfh);

    return(1);
}


sub uos_edit_cups_conf
{
    my ($conf_file) = @_;

    my $rc = 0;

    my $new_conf_file = "$conf_file.$$";

    if (open(my $ofh, '<', $conf_file)) {
	if (open(my $nfh, '>', $new_conf_file)) {
	    if (uos_rewrite_cups_conf($ofh, $nfh)) {
		loginfo("[edit cups] CUPS conf file rewrite successful: $conf_file");
		$rc = 1;
	    }
	    else {
		logerror("[edit cups] could not rewrite CUPS conf file: $conf_file");
	    }
	    close($nfh);
	}
	else {
	    logerror("[edit cups] could not open for write: $new_conf_file");
	}
	close($ofh);
    }
    else {
	logerror("[edit cups] could not open for read: $conf_file");
    }

    if ($rc) {
	$rc = uos_rename_conf($new_conf_file, $conf_file);
    }

    return($rc);
}

#
# configure CUPS.
#
# returns
#   $EXIT_OK on success
#   non-zero if error
#
sub uos_configure_cups
{
    my $conf_file = uos_pathto_cups_conf();

    unless (-f "$conf_file") {
	showerror("[config cups] CUPS conf file does not exist: $conf_file");
	return($EXIT_CUPS_CONF_MISSING);
    }

    my $rc = $EXIT_OK;

    if (uos_edit_cups_conf($conf_file)) {
	showinfo("[config cups] CUPS reconfigured: $conf_file");
    }
    else {
	showerror("[config cups] could not reconfigure CUPS: $conf_file");
	$rc = $EXIT_CUPS_CONFIGURE;
    }

    my $service_name = 'cups';
    my $exit_status = 1;
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	$exit_status = system("/sbin/service $service_name start");
    }
    if ($OS eq 'RHEL7') {
	$exit_status = system("/bin/systemctl start $service_name");
    }
    if ($exit_status == 0) {
	showinfo("[config cups] system service started: $service_name");
    }
    else {
	showerror("[config cups] could not start system service: $service_name");
    }

    return($rc);
}


sub uos_sys_service_status
{
    my ($service_name) = @_;

    # the RHEL7 cmd does not report anything when stoping or
    # starting the system service like on RHEL5/6 so we need
    # to at least report some status after starting
    my $service_status = $EMPTY_STR;
    my $cmd = "systemctl show --property=ActiveState $service_name";
    if (open(my $pfh, '-|', $cmd)) {
	while (<$pfh>) {
	    if (/^ActiveState=(.*)$/) {
		$service_status = $1;
		last;
	    }
	}
	close($pfh);
    }

    return($service_status);
}


#
# remove all CUPS print jobs from all print queues.
#
# returns
#   $EXIT_OK if success
#   non-zero on error
#
sub uos_purge_cups_jobs
{
    my $service_name = 'cups';

    my $rc = $EXIT_OK;

    # first, stop the service
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	system("/sbin/service $service_name stop");
    }
    if ($OS eq 'RHEL7') {
	system("/bin/systemctl stop $service_name");
	if ($? == 0) {
	    showinfo("[purge print jobs] system service stopped: $service_name");
	}
	else {
	    showerror("[purge print jobs] could not stop system service: $service_name");
	    return($EXIT_CUPS_SERVICE_STOP);
	}
    }

    # then, purge with a hammer
    my $cups_spool_dir = '/var/spool/cups';
    system("find $cups_spool_dir -type f -print | xargs rm -f");
    if ($? == 0) {
	showinfo("[purge print jobs] CUPS print jobs purged from: $cups_spool_dir");
    }
    else {
	showerror("[purge print jobs] could not purge CUPS print jobs from: $cups_spool_dir");
    }

    # finally, start the service
    if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	system("/sbin/service $service_name start");
    }
    if ($OS eq 'RHEL7') {
	system("/bin/systemctl start $service_name");
	if ($? == 0) {
	    showinfo("[purge print jobs] system service started: $service_name");
	}
	else {
	    showerror("[purge print jobs] could not start system service: $service_name");
	    $rc = $EXIT_CUPS_SERVICE_START;
	}

	# the RHEL7 cmd does not report anything when stoping or
	# starting the system service like on RHEL5/6 so we need
	# to at least report some status after starting
	my $sys_service_status = uos_sys_service_status($service_name);
	if ($sys_service_status) {
	    showinfo("[purge print jobs] system service status for $service_name: $sys_service_status");
	}
	else {
	    logerror("[prurge print jobs] could not get status on service: $service_name");
	}
    }

    return($rc);
}


sub get_arch_info
{
    my $arch = "";

    if (open(my $pipefh, '-|', "uname -i")) {
	while (<$pipefh>) {
	    if (/i386/) {
		$arch = "i386";
	    }
	    if (/x86_64/) {
		$arch = "x86_64";
	    }
	}
	close($pipefh);
    }

    return($arch);
}


#
# Which processor architecture are we running on?
#
sub processor_arch
{
    $ARCH = "";

    $ARCH = get_arch_info();

    if ($ARCH eq "") {
	showerror("Can't determine processor architecture - assuming: i386");
	$ARCH = "i386";
    }

    return($ARCH);
}


# strip domain name from fully qualified domain name if present.
#
# Returns
#   hostname
#
sub strip_domain
{
    my ($hostname, $domain) = @_;

    if ($hostname =~ /(.+)\.$domain/) {
	$hostname =~ s/\.$domain//;
    }

    return($hostname);
}


sub get_ipaddr
{
    my ($hostname) = @_;

    my $ip_addr_binary = gethostbyname($hostname);
    my $ip_addr = inet_ntoa($ip_addr_binary);

    return($ip_addr);
}


sub get_hostname
{
    my $hostname = hostname();

    return($hostname);
}


sub get_network_attribute
{
    my ($device, $selector) = @_;

    my $attribute_val = "";

    if (open(my $pipefh, '-|', "/sbin/ifconfig $device 2> /dev/null")) {
	while (<$pipefh>) {

	    my $pattern = "";
	    if ($selector eq $NET_ATTR_IPADDR) {
		$pattern = "inet addr";
	    }
	    elsif ($selector eq $NET_ATTR_BROADCAST) {
		$pattern = "Bcast";
	    }
	    elsif ($selector eq $NET_ATTR_NETMASK) {
		$pattern = "Mask";
	    }

	    if (/($pattern):(\d+\.\d+\.\d+\.\d+)/) {
		$attribute_val = $2;
	    }
	}
	close($pipefh);
    }

    return($attribute_val);
}


#
# change the value of the "HOSTNAME" variable in the sysconfig network
# file - normally "/etc/sysconfig/network" but could be different when
# testing.
#
# Returns
#   1 on success
#   0 on error
#
sub set_sysconfig_hostname
{
    my ($hostname, $config_file_path) = @_;

    my $rc = 1;

    system("perl -p -i -e 's/^HOSTNAME=.*/HOSTNAME=$hostname/' $config_file_path");
    if ($? != 0) {
	$rc = 0;
    }

    return($rc);
}


sub update_hosts_config_file
{
    my ($new_hostname, $ipaddr, $config_file_path) = @_;

    my $rc = 1;

    my $new_config_file_path = $config_file_path . '.' . "$$";

    my $current_hostname = get_hostname();

    # form a new line suitable for the /etc/hosts file
    my $fqdn = $new_hostname . ".teleflora.com";
    my $hosts_file_entry = "$ipaddr\t$fqdn $new_hostname\n";

    if (open(my $ocfh, '<', $config_file_path)) {
        if (open(my $ncfh, '>', $new_config_file_path)) {

	    my $hostname_replaced = 0;

	    while (<$ocfh>) {

		# if the loopback line:
		#   remove current hostname if it appears
		# else if line contains old hostname
		#   update current hostname
		# else
		#   pass through
		if (/^127\.0\.0\.1/) {
		    if ($current_hostname ne "localhost") {
			if (/$current_hostname/) {
			    s/$current_hostname(\s*)//;
			}
		    }
		}
		elsif (/$current_hostname/) {
		    $_ = $hosts_file_entry;
		    $hostname_replaced = 1;
		}

		print($ncfh $_);
	    }

	    close($ocfh);

	    # if the current hostname was not replaced,
	    # which means it did not appear in the /etc/hosts file, then
	    # just append a new entry now.
	    unless ($hostname_replaced) {
		print($ncfh $hosts_file_entry);
	    }

	    close($ncfh);
	}
	else {
	    $rc = 0;
	}
    }
    else {
	$rc = 0;
    }

    if ($rc) {
	system("mv $new_config_file_path $config_file_path");
    }

    return($rc);
}


#
# classify the exit status of external command
#
# Returns
#    -1 : did not execute or died from signal
#     0 : success
#   > 0 : error
#
sub exit_status_classify
{
    my ($exit_status) = @_;

    if ($exit_status == -1) {
	logerror("command failed to execute: $!");
    }
    elsif ($exit_status & 127) {
	my $signo = ($exit_status & 127);
	my $coredump = ($exit_status & 128) ? 'with' : 'without';
	logerror("command died from signal $coredump coredump: $signo");
	$exit_status = -1;
    }
    else {
	$exit_status = ($exit_status >> 8);
	if ($exit_status != 0) {
	    logerror("command returned non-zero exit status: $exit_status");
	}
    }

    # exit status of zero is success

    return($exit_status);
}


###################################
### REDHAT SUBSCRIPTION MANAGER ###
###################################

sub sub_mgr_identification
{
    my $rc = $EXIT_OK;
    my $ml = '[sub_mgr_identification]';

    my $sub_mgr_id = sub_mgr_get_system_identity();
    if ($sub_mgr_id) {
	showinfo("$ml subscription manager system identity: $sub_mgr_id");
    }
    else {
	showerror("$ml could not get subscription manager system identity");
	$rc = $EXIT_SUB_MGR_IDENTIFICATION;
    }

    return($rc);
}


sub sub_mgr_registration
{
    my $rc = $EXIT_OK;
    my $ml = '[sub_mgr_registration]';

    if (sub_mgr_register()) {
	showinfo("$ml system registered via subscription manager");
    }
    else {
	showerror("$ml could not register system via subscription manager");
	$rc = $EXIT_SUB_MGR_REGISTRATION;
    }

    return($rc);
}


sub sub_mgr_unregistration
{
    my $rc = $EXIT_OK;
    my $ml = '[sub_mgr_unregistration]';

    if (sub_mgr_unregister()) {
	showinfo("$ml system unregistered via subscription manager");
    }
    else {
	showerror("$ml could not unregister system via subscription manager");
	$rc = $EXIT_SUB_MGR_UNREGISTRATION;
    }

    return($rc);
}


sub sub_mgr_report_status
{
    my $rc = $EXIT_OK;
    my $ml = '[sub_mgr_report_status]';

    my $sub_mgr_status = sub_mgr_get_status();
    if ($sub_mgr_status) {
	showinfo("$ml subscription manager status: $sub_mgr_status");
    }
    else {
	showerror("$ml could not get subscription manager status");
	$rc = $EXIT_SUB_MGR_CONDITION;
    }

    return($rc);
}


#
# get the system identity from subscription manager.
#
# Returns
#   on success: non-empty identity string
#   on failure: empty string
#
sub sub_mgr_get_system_identity
{
    my $system_identity = $EMPTY_STR;
    my $ml = '[sub_mgr_get_system_identity]';
    my $cmd = '/usr/sbin/subscription-manager';

    # return unless the subscription-manager is available
    unless (-x $cmd) {
	loginfo("$ml command not available: $cmd");
	return($system_identity);
    }

    # add the sub-command
    my $sub_cmd = 'identity';
    $cmd = "$cmd $sub_cmd";

    if (open(my $pfh, '-|', "$cmd")) {
	while (<$pfh>) {
	    if (/^system identity:\s+(.+)$/) {
		$system_identity = $1;
	    }
	}
	unless (close($pfh)) {
	    logerror("$ml could not close pipe command: $cmd");
	}
    }
    else {
	logerror("$ml could not open pipe: $cmd");
    }

    return($system_identity);
}


#
# register a system via the subscription manager.
#
# Returns
#   on success: 1
#   on failure: 0
#
sub sub_mgr_register
{
    my $rc = 0;
    my $ml = '[sub_mgr_register]';

    # return unless the subscription-manager is available
    my $cmd = '/usr/sbin/subscription-manager';
    unless (-x $cmd) {
	loginfo("$ml command not available: $cmd");
	return($rc);
    }

    # gather info for --name=$profile option.  The format of the $profile
    # string is:
    #      $POSTYPE_$SHOPCODE_$SHOPNAME_$SERIAL_$SYSTEM_$OS
    # where
    # $POSTYPE is 'R' for RTI or 'D' for Daisy
    # $SHOPCODE is the 8 digit shop code
    # $SHOPNAME is the shop name
    # $SERIAL is the Dell service tag
    # $SYSTEM is the Dell system name
    # $OS is "RHEL6" or "RHEL7"

    my $postype = 'R';
    if ($DAISY) {
	$postype = 'D';
    }
    my $shopcode = uos_rti_shopcode();
    if ($DAISY) {
	$shopcode = uos_daisy_shopcode();
    }
    if ($shopcode eq $EMPTY_STR) {
	$shopcode = '00000000';
    }
    my $shopname = uos_rti_shopname();
    if ($DAISY) {
	$shopname = uos_daisy_shopname();
    }
    if ($shopname eq $EMPTY_STR) {
	$shopname = '00000000';
    }
    my $serial = OSTools::Hardware::hw_serial_number();
    my $system = OSTools::Hardware::hw_product_name();
    $system =~ s/\s+/_/g;

    my $profile = $postype . '_' . $shopcode . '_' . $shopname . '_' . $serial . '_' . $system . '_' . $OS;

    # the "register" sub-command and options
    my $sub_cmd = 'register';
    my $sub_cmd_options = "--activationkey=TelefloraPOS --org=4508688 --force --name=$profile";
    my $reg_cmd = "$cmd $sub_cmd $sub_cmd_options";
    loginfo("$ml register command: $reg_cmd");

    my $exit_status = system($reg_cmd);
    $exit_status = exit_status_classify($exit_status);
    if ($exit_status == 0) {
	# register successful
	loginfo("$ml register command successful");
	$rc = 1;
    }
    else {
	# register failed
	logerror("$ml could not register, exit status: $exit_status");
    }

    return($rc);
}


#
# unregister a system via the subscription manager.
#
# Returns
#   on success: 1
#   on failure: 0
#
sub sub_mgr_unregister
{
    my $rc = 0;
    my $ml = '[sub_mgr_unregister]';
    my $cmd = '/usr/sbin/subscription-manager';

    # return unless the subscription-manager is available
    unless (-x $cmd) {
	loginfo("$ml command not available: $cmd");
	return($rc);
    }

    # takes two commands to unregister
    my $full_cmd = "$cmd remove --all";
    if (exit_status_classify(system("$full_cmd")) == 0) {
	$full_cmd = "$cmd unregister";
	if (exit_status_classify(system("$full_cmd")) == 0) {
	    $rc = 1;
	}
    }

    return($rc);
}


#
# get the status from subscription manager.
#
# Returns
#   on success: non-empty string
#   on failure: empty string
#
sub sub_mgr_get_status
{
    my $sub_mgr_status = $EMPTY_STR;
    my $ml = '[sub_mgr_get_status]';
    my $cmd = '/usr/sbin/subscription-manager';

    # return unless the subscription-manager is available
    unless (-x $cmd) {
	loginfo("$ml command not available: $cmd");
	return($sub_mgr_status);
    }

    # add the sub-command
    my $sub_cmd = 'status';
    $cmd = "$cmd $sub_cmd";

    if (open(my $pfh, '-|', "$cmd")) {
	while (<$pfh>) {
	    if (/^Overall Status:\s+(.+)$/) {
		$sub_mgr_status = $1;
	    }
	}
	unless (close($pfh)) {
	    logerror("$ml could not close pipe command: $cmd");
	}
    }
    else {
	logerror("$ml could not open pipe: $cmd");
    }

    return($sub_mgr_status);
}


#
# return field value given field name from consumed subscripton output.
#
# types of info:
#   Subscription Name: Red Hat Enterprise Linux Server (1 socket) (Up to 1 guest) -
#   SKU:               RH0154946
#   Contract:          10229985
#   Account:           781941
#   Serial:            2656598660581304130
#   Pool ID:           8a85f9823fd475c2013fd4c7b7705331
#   Active:            True
#   Quantity Used:     1
#   Service Level:     PREMIUM
#   Service Type:      PSF
#   Subscription Type: Standard
#   Starts:            06/23/2014
#   Ends:              06/23/2015
#   System Type:       Physical
#
sub sub_mgr_info
{
    my ($search_term) = @_;

    my $rc = 1;
    my $ml = '[sub_mgr_info]';

    my @field_types = (
	"Subscription Name",
	"SKU",
	"Contract",
	"Account",
	"Serial",
	"Pool ID",
	"Active",
	"Quantity Used",
	"Service Level",
	"Service Type",
	"Subscription Type",
	"Starts",
	"Ends",
	"System Type",
    );

    my $field_value = $EMPTY_STR;

    if (grep {/$search_term/} @field_types) {

	my $cmd = "/usr/sbin/subscription-manager list --consumed";
	if (open(my $pfh, '-|', $cmd)) {
	    while(<$pfh>) {
		if (/$search_term:\s+(.*)$/) {
		    $field_value = $1;
		    last;
		}
	    }
	    unless (close($pfh)) {
		logerror("$ml close of pipe command: $cmd");
	    }
	}
	else {
	    logerror("$ml could not open pipe: $cmd");
	}
    }

    return($field_value);
}


#
# Gather some evidence if we believe there was a compromise or need performance
# statistics.
#
sub forensics
{
	unlink("/tmp/system-info.$$");

	system("/bin/echo '----- Basic Information -----' | tee --append /tmp/system-info.$$");
	system("date >> /tmp/system-info.$$");
	system("hostname >> /tmp/system-info.$$");


	system("/bin/echo '----- Network Information -----' | tee --append /tmp/system-info.$$");
	system("/sbin/ifconfig >> /tmp/system-info.$$");
	system("/bin/netstat -plan >> /tmp/system-info.$$");
	system("/sbin/route -n >> /tmp/system-info.$$");

	#
	# Run nmap discovery on all networks which we have a (known) route to.
	#
	my $cmd = '/sbin/route -n';
	if (open(my $pipe, '-|', $cmd)) {
	    while (<$pipe>) {
		if (/^\d/) {
		    my @routes = split(/(\s+)/);
		    next if ("$routes[0]" !~ /^192\.168\./);
		    system("/bin/echo '----- nmap $routes[0] -----' | tee --append /tmp/system-info.$$");
		    system("nmap -v -n -sS -O $routes[0]/24 >> /tmp/system-info.$$");
		}
	    }
	    close($pipe);
	}
	else {
	    logerror("[forensics] could not open pipe to command: $cmd");
	}


	system("/bin/echo '----- Processes (ps wwaux) -----' | tee --append /tmp/system-info.$$");
	system("ps wwaux >> /tmp/system-info.$$");

	# We may not be able to trust 'ps' results.
	system("/bin/echo '----- Processes (/proc) -----' | tee --append /tmp/system-info.$$");
	my @proc_files = glob("/proc/*");
	foreach my $proc_file (@proc_files) {
	    next unless (-d $proc_file);
	    next unless ($proc_file =~ /\/proc\/\d+/);
	    if (open(my $clfh, '<', "$proc_file/cmdline")) {
		my $raw_cmd = "";
		while (<$clfh>) {
		    $raw_cmd .= $_;
		}
		close($clfh);

		my $cmdline = join(' ', split(/\0/, $raw_cmd));
		chomp($cmdline);
		if (open(my $sifh, '>>', "/tmp/system-info.$$")) {
		    print {$sifh} "$proc_file/cmdline: $cmdline\n";
		    close($sifh);
		}
		else {
		    logerror("[forensics] could not open for append: /tmp/system-info.$$");
		}
	    }
	    else {
		logerror("[forensics] could not open for read: $proc_file/cmdline");
	    }
	}

	system("/bin/echo '----- System Performance -----' | tee --append /tmp/system-info.$$");
	system("cat /proc/meminfo >> /tmp/system-info.$$");
	system("vmstat 2 5 >> /tmp/system-info.$$");
	system("iostat -x 2 5 >> /tmp/system-info.$$");

	system("/bin/echo '----- Hardware Info -----' | tee --append /tmp/system-info.$$");
	system("/usr/sbin/dmidecode >> /tmp/system-info.$$");

	system("/bin/echo '----- OS Information -----' | tee --append /tmp/system-info.$$");
	system("uname -a >> /tmp/system-info.$$");
	system("cat /etc/redhat-release >> /tmp/system-info.$$");
	system("rpm --query --all --list >> /tmp/system-info.$$");
	system("rpm --verify --all >> /tmp/system-info.$$");
	system("dmesg >> /tmp/system-info.$$");
	if (-f "/usr/bin/yum") {
	    system("yum check-update >> /tmp/system-info.$$");
	}

	system("/bin/echo '----- User Information -----' | tee --append /tmp/system-info.$$");
	system("w >> /tmp/system-info.$$");
	system("last >> /tmp/system-info.$$");

	system("/bin/echo '----- POS Information -----' | tee --append /tmp/system-info.$$");
	if ($RTI) {
	    system("/usr2/bbx/bin/rtiuser.pl --list >> /tmp/system-info.$$");
	}
	if ($DAISY) {
	    system("/d/daisy/bin/dsyuser.pl --list >> /tmp/system-info.$$");
	}

	system("/bin/echo '----- PCI 2.2.2 -----' | tee --append /tmp/system-info.$$");
	if ( ($OS eq 'RHEL5') || ($OS eq 'RHEL6') ) {
	    system("/sbin/chkconfig --list | grep ':on' >> /tmp/system-info.$$");
	}
	if ($OS eq 'RHEL7') {
	    system("/bin/systemctl --type=service list-unit-files | grep 'enabled' >> /tmp/system-info.$$");
	}


	system("/bin/echo '----- PCI 2.2.3 -----' | tee --append /tmp/system-info.$$");
	system("/bin/echo '----- iptables Config -----' | tee --append /tmp/system-info.$$");
	system("/sbin/iptables-save >> /tmp/system-info.$$");
	system("/bin/echo '----- host access Config -----' | tee --append /tmp/system-info.$$");
	system("cat /etc/hosts.allow >> /tmp/system-info.$$");
	system("/bin/echo '----- PAM secure tty Config -----' | tee --append /tmp/system-info.$$");
	system("cat /etc/securetty >> /tmp/system-info.$$");
	system("/bin/echo '----- PAM system auth Config -----' | tee --append /tmp/system-info.$$");
	system("cat /etc/pam.d/system-auth-teleflora >> /tmp/system-info.$$");
	system("/bin/echo '----- PAM su Config -----' | tee --append /tmp/system-info.$$");
	system("cat /etc/pam.d/su >> /tmp/system-info.$$");
	system("/bin/echo '----- sudoers Config -----' | tee --append /tmp/system-info.$$");
	system("cat /etc/sudoers >> /tmp/system-info.$$");
	system("/bin/echo '----- sshd Config -----' | tee --append /tmp/system-info.$$");
	system("cat /etc/ssh/sshd_config >> /tmp/system-info.$$");


	# Create our resultant tarfile.
	system("/bin/echo '----- make tar file -----' | tee --append /tmp/system-info.$$");
	unlink("/tmp/system-info.$$.tar");
	system("cd /tmp && tar --append -f /tmp/system-info.$$.tar system-info.$$");
	system("cd / && tar --append -f /tmp/system-info.$$.tar /etc");
	system("cd /home && find . -type f -iname .bash_history -exec tar --append -f /tmp/system-info.$$.tar \\{\\} \\;");
	system("cd / && find /root -type f -iname .bash_history -exec tar --append -f /tmp/system-info.$$.tar \\{\\} \\;");
	system("cd / && tar --append -f /tmp/system-info.$$.tar root");
	system("cd / && tar --append -f /tmp/system-info.$$.tar var/log");
	if ($RTI) {
	    system("cd / && tar --append -f /tmp/system-info.$$.tar usr2/bbx/log");
	    system("cd / && tar --append -f /tmp/system-info.$$.tar usr2/bbx/config");
	}
	if ($DAISY) {
	    system("cd / && tar --append -f /tmp/system-info.$$.tar d/daisy/log");
	}

	system("gzip -v9 /tmp/system-info.$$.tar");
	system("ls -la /tmp/system-info.$$.tar.gz");


	return(0);
}



sub showinfo
{
	my ($message) = @_;

	print("$message\n");
	return(loginfo($message));
}

sub loginfo
{
	my ($message) = @_;

	return(logit($message, 'I'));
}

sub showerror
{
	my ($message) = @_;

	print("error: $message\n");
	return(logerror($message));
}

sub logerror
{
	my ($message) = @_;

	return(logit($message, 'E'));
}

sub logit
{
    my ($message, $type) = @_;

    my $logtime = strftime("%Y-%m-%d %H:%M:%S", localtime());

    chomp($message);

	# where is the logfile?
    if ($LOGFILE_PATH eq "") {
	if ( ($POSDIR ne "") && (-d "$POSDIR/log") ) {
	    $LOGFILE_PATH = "$POSDIR/log/RTI-Patches.log";
	}
	else {
	    $LOGFILE_PATH = "/tmp/RTI-Patches.log";
	}
    }

    if (open(my $lf, '>>', $LOGFILE_PATH)) {
	print $lf "$logtime ($PROGNAME-$$) <$type> $message\n";
	close($lf);
    }

    return("");
}


__END__

=pod

=head1 NAME

updateos.pl - Teleflora Operating System Updater

=head1 VERSION

This documenation refers to version: $Revision: 1.347 $


=head1 USAGE

updateos.pl

updateos.pl B<--version>

updateos.pl B<--help>

updateos.pl B<--verbose>

updateos.pl B<--baremetal>

updateos.pl B<--rti14>

updateos.pl B<--[no]rti14-truncated>

updateos.pl B<--daisy>

updateos.pl B<--daisy-start>

updateos.pl B<--daisy-stop>

updateos.pl B<--daisy-shopcode>

updateos.pl B<--daisy-shopname>

updateos.pl B<--rti-shopcode>

updateos.pl B<--rti-shopname>

updateos.pl B<--ospatches>

updateos.pl B<--ostools>

updateos.pl B<--java>

updateos.pl B<--java-version=s>

updateos.pl B<--ipaddr=s [--ifname=s] [--netmask=s --gateway=s]>

updateos.pl B<--namserver=s>

updateos.pl B<--(i18n|gen-i18n-conf)>

updateos.pl B<--locale>

updateos.pl B<--yum>

updateos.pl B<--ups [--(ups-serial|ups-usb)]>

updateos.pl B<--cupsconf>

updateos.pl B<--cupstmp>

updateos.pl B<--purgeprint>

updateos.pl B<--purgerpms>

updateos.pl B<--keepkernels=n>

updateos.pl B<--(inittab|default-runlevel)>

updateos.pl B<--default-target>

updateos.pl B<--default-password-hash>

updateos.pl B<--syslog-mark=n>

updateos.pl B<--kernel-msg-console=n>

updateos.pl B<--samba-gen-conf>

updateos.pl B<--samba-set-passdb>

updateos.pl B<--samba-rebuild-passdb>

updateos.pl B<--bbj-gen-settings-file>

updateos.pl B<--bbj-gen-properties-file>

updateos.pl B<--configure-grub2>

updateos.pl B<--init-console-res>

updateos.pl B<--enable-boot-msgs>

updateos.pl B<--disable-kms>

updateos.pl B<--uninstall-readahead>

updateos.pl B<--sub-mgr-identity>

updateos.pl B<--sub-mgr-register>

updateos.pl B<--sub-mgr-unregister>

updateos.pl B<--sub-mgr-status>

updateos.pl B<--audit-system-configure>

updateos.pl B<--audit-system-rules-file=s>

updateos.pl B<--swapon>

updateos.pl B<--report-swap-size>

updateos.pl B<--report-architecture>


=head1 OPTIONS

=over 4

=item B<--version>

Output the version number of the script and exit.

=item B<--help>

Output a short help message and exit.

=item B<--verbose>

For some operations, output more information.

=item B<--baremetal>

Perpare a system to be ready for installation of a POS,
either Daisy or RTI.
It is assumed that the system has been kickstarted but has had no other prep.

=item B<--rti14>

Assumes that the system has only had a kickstart and
C<updateos.pl --baremetal> run on it.
Verify that the system is ready for installation of the
RTI Point of Sales system and
further prepare for the installation of RTI.
Do not install Java, BBj, or BLM.

=item B<--[no]rti14-truncated>

The default action for B<--rti14> is a truncated RTI install, i.e.
B<--rti14-truncated> is the default.
To perform a full RTI install, specify B<--rti14 --norti14-truncated>.

=item B<--daisy>

Install the Daisy POS onto a system.
It is assumed that the system has been kickstarted and
only had B<--baremetal> run on it.

=item B<--daisy-start>

Start the Daisy POS application - assumes it is stopped.

=item B<--daisy-stop>

Stop the Daisy POS application - system will be at runlevel 4
after running this option.

=item B<--daisy-shopcode>

Output the Daisy shopcode.

=item B<--daisy-shopname>

Output the Daisy shopname.

=item B<--rti-shopcode>

Output the RTI shopcode.

=item B<--rti-shopname>

Output the RTI shopname.

=item B<--ospatches>

Configure yum to allow kernel updates.
Then, purge old kernels.
Finally, run a C<yum clean> and then a C<yum update> command.

=item B<--ostools>

Download the OSTools install script C<install-ostool.pl> from the
Teleflora Managed Services web site and execute it to
install the latest version of OSTools.
The B<--norun-harden-linux> is specified on the install script
command line so that the new C<harden_linux.pl> script is installed but
not executed.

=item B<--java>

Install the latest version of the Oracle Java JRE package.

=item B<--java-version=s>

Install the version of the Oracle Java JRE package specified.

=item B<--ipaddr=s>

Change the IP address of the system.

=item B<--nameserver=s>

Change the DNS name server of the system.

=item B<--(i18n|gen-i18n-conf)>

Generate a new instance of the internationalization config file.

=item B<--locale>

Set the system locale to "en_US".

=item B<--yum>

Edit the yum config file so that kernel updates will be perfomed.

=item B<--ups (--ups-serial|--ups-usb)>

Download and install the APC UPS software,
generate an appropriate config file, and
install an "APC on battery" script.

=item B<--cupsconf>

Edit several values in the F</etc/cups/cupsd.conf> file.

=item B<--cupstmp>

Remove all zero sized files from F</var/spool/cups/tmp>.

=item B<--purgeprint>

Remove ALL regular files recursively starting from F</var/spool/cups>.

=item B<--purgerpms>

Remove all old kernel RPMs older than the last 8 (default).
The value of the number of old kernels saved may be
changed via the B<--keepkernels=n> command line option.

=item B<--keepkernels=n>

The number of kernels saved saved via B<--ospatches> and
B<--purgerpms> may be set via the B<--keepkernels=s> commandline option.
The minimum value is 2.
If the script is run on is a Dell T300 system, then
the number of kernels saved is automatically set to the minimum due
to limited space in the C</boot> partition.

=item B<--(inittab|default-runlevel)>

Configure the default runlevel in the F</etc/inittab file>.

=item B<--default-target>

Configure the systemd default target to "multi-user".

=item B<--default-password-hash>

Configure the default password hash "sha512".

=item B<--syslog-mark=n>

Configure the syslog mark message period.

=item B<--kernel-msg-console=string>

Configure syslog to direct kernel messages to specified tty device.

=item B<--samba-gen-conf> or B<--samba>

Generate a Samba conf file appropriate to the POS installed.

=item B<--samba-set-passdb>

Configure samba to use a "passdb backend" of "smbpasswd".

=item B<--samba-rebuild-passdb>

Rebuild the samba "smbpasswd" file.

=item B<--bbj-gen-settings-file>

Generate a BBj settings file.

=item B<--bbj-gen-properties-file>

Generate a BBj properties file.

=item B<--configure-grub2>

For RHEL7 systems,
enable verbose boot messages by editing the GRUB2 config file and
then running the C<grub2-mkconfig> utility.

=item B<--init-console-res>

Initialize the console resolution by editing the GRUB config file.
All kernel lines in the config file that have not already been
appropriately modified will be changed.

=item B<--enable-boot-msgs>

Enable verbose boot messages by editing the GRUB config file.
All kernel lines in the config file that have not already been
appropriately modified will be changed.

=item B<--disable-kms>

Disable kernel (video) mode setting by editing the GRUB config file.
All kernel lines in the config file that have not already been
appropriately modified will be changed.

=item B<--uninstall-readahead>

If platform is "RHEL6", uninstall the "readahead" RPM package.

=item B<--sub-mgr-identity>

Report the subscription manager system identity.

=item B<--sub-mgr-register>

Register the system via subscription manager.

=item B<--sub-mgr-unregister>

Unregister the system via subscription manager.

=item B<--sub-mgr-status>

Report the subscription manager status.

=item B<--audit-system-configure>

Configure the audit system by installing a rules file in F</etc/audit/rules.d> and
restarting the B<auditd> system service.

=item B<--audit-system-rules-file=s>

Specify an audit system rules file for use by the
B<--audit-system-configure> option.

=item B<--swapon>

For RTI systems only, enable swap space.

=item B<--report-swap-size>

Report suggested sawp partition size in GB
for the current installed RAM size
according to Red Hat recommendations.

=item B<--report-architecture>

Report the system architecture.
Values are either "i386" or "x86_64".

=back


=head1 DESCRIPTION

This I<updateos.pl> script provides many essential methods used to setup and
configure a Red Hat Linux system for use as a Teleflora POS server.

=head2 COMMAND LINE OPTIONS

The B<"--java"> command line option downloads and installs
the Oracle Java SE JRE package.
The Java package file
for RHEL 32-bit servers is downloaded from
F<"http://rtihardware.homelinux.com/ks/jre-latest-linux-i586-rpm.bin">, and
for RHEL 64-bit servers is downloaded from
F<"http://rtihardware.homelinux.com/ks/jre-latest-linux-x64-rpm.bin">.

The B<"--java-version=s"> command line option may be used to specify a
specific version of the Java SE JRE package.
For example, to install the version of the Java JRE from package file
F<"jre-6u31-linux-x64-rpm.bin"> on a 64-bit server,
specify C<"--java-version=6u31">.
The default version is "latest".

The B<"--daisy"> command line option can be specified to make system
configuration changes appropriate for Daisy 8.0 and later systems.
These changes include the following:

=over 4

=item o

IP addr

Check the method of booting in F</etc/sysconfig/network-scripts/ifcfg-eth0> and
if it's "DHCP", log an error and exit.

=item o

File System Remounting

The F</teleflora> file system is remounted as the F</d> file system.

=item o

Mount Options

On RHEL7 systems, the "nofail" mount option is added to the entry for F</d>.

=item o

CDROM

On RHEL5 and RHEL6 systems, add an F</etc/fstab> entry for the CD-ROM.

=item o

Mount Points

Make mount points F</mnt/cdrom> and F</mnt/usb> if they do not exist.

=item o

Samba

If Samba has not been configured, generate and install a Samba
config file appropriate for Daisy.

=item o

Standard users

Make the standard Daisy users.

=item o

Locale

On RHEL5 and RHEL6 systems, generate a new F</etc/sysconfig/i18n> file.
On RHEL7 systems, set the system locale.

=back


The B<"--rti14"> command line option can be specified to make system
configuration changes appropriate for RTI version 14.
These changes include the following:

=over 4

=item o

Red Hat Network

Verify that the system is registered with the Red Hat Network.
If not, log an error message and exit.

=item o

IP addr

Check the method of booting in F</etc/sysconfig/network-scripts/ifcfg-eth0> and
if it's "DHCP", log an error and exit.
The default network device name is "eth0" but
an alternate network device name may be specified with the
C<--ifname> command line option.

=item o

File System Remounting

The F</teleflora> file system is remounted as the F</usr2> file system.

=item o

Mount Options

On RHEL7 systems, the "nofail" mount option is added to the entry for F</usr2>.

=item o

Red Hat Package Installation

On RHEL5, RHEL6, and RHEL7 platforms,
install the C<apache>, C<fetchmail>, and C<ksh> packages.
On RHEL5 platforms,
install the C<uucp> package.

=item o

Default RTI Users

Add the default RTI groups: "rti" and "rtiadmins".
Add the default RTI user accounts: "tfsupport" and "rti".
Add the default RTI samba accounts: "odbc" and "delivery".

=item o

Samba Configuration

If the Samba configuration has not already been modified,
generate the RTI Samba configuration file.
Add the RTI users "rti", "odbc", and "delivery" to the
Samba password file.

=item o

RTI Package Installation

If only the B<--rti14> option is specified, then
no further actions are performed.
If the B<--rti14 --norti14-trunc> is specified, then
additionally Java, BBj, BBj config files, BLM and BLM config files
are installed.

=back

The B<"--ipaddr=s"> command line option may be used to change
the IP address of any specified ethernet interface.
By default, the ethernet interface config file for the
ethernet interface named "eth0" is edited;
the path to that file is F</etc/sysconfig/network-scripts/ifcfg-eth0>.
Along with ifcfg file, the system hosts file F</etc/hosts> is also updated.
An alternate ifcfg file may be specified via the B<"--ifname=s"> command line option.
If the IP address specified is not the default value of "192.168.1.21", then
the B<"--netmask=s"> and the B<"--gateway=s"> command line options
must also be specified.
In order for the new IP address to take effect,
either the "network" service must be restarted or
the system must be rebooted.

The B<"--nameserver=s"> command line option actually generates
entirely new contents for the F</etc/resolv.conf> file.
The previous contents are removed so if you need to save them,
make a copy of the file before running this command.
The specified IP address is used as the IP address of the
DNS name server.

The B<"--(i18n|gen-i18n-conf)"> command line option actually generates
entirely new contents for the F</etc/sysconfig/i18n> config file.
The previous contents are removed so if you need to save them,
make a copy of the file before running this command.
This option is only valid on RHEL5 and RHEL6 systems.

The B<"--locale"> command line option issues the F<localectl set-locale>
command to set the system locale to "en_US".
This command also updates the system locale config file F</etc/locale/conf>
with the new value so it is preserved across reboots.
This command line option is only supported on RHEL7 platforms.

The B<"--yum"> command line option checks the contents of F</etc/yum.conf>.
If the line "exclude=kernel" appears, the file is edited to comment
out that line.

The B<"--(inittab|default-runlevel)"> command line option edits
the F</etc/inittab> file if there is one, and sets the default
system runlevel to "3", ie multi-user.
This option is only valid on RHEL5 and RHEL6 systems.

The B<"--default-target"> command line option sets the
systemd default target to "multi-user".
This option is only valid on RHEL7 systems.

The B<"--syslog-mark"> command line option can be specified to
configure I<syslog> on RHEL5 systems and I<rsyslog> on RHEL6 systems
to write a "mark" message to the syslog log file at
the specified period.

For I<rsyslog> on RHEL6:

The following 2 lines must be added to the beginning of
the I</etc/syslog.conf> conf file:

$ModLoad immark.so
$MarkMessagePeriod 1200

The "$ModLoad" line is a directive to load the input module "immark.so"
which provides the mark message feature.
The "$MarkMessagePeriod" line is a directive to specify the number of
seconds between mark messages.
This directive is only available after the
"immark" input module has been loaded.
Specifying 0 is possible and disables mark messages.
In that case, however, it is more efficient to NOT load
the "immark" input module.
In general, the last directive to appear in file wins.

For I<syslog> on RHEL5:

In the I</etc/sysconfig/syslog> conf file,
the "SYSLOGD" variable must have the "-m" option
changed to have a non-zero value if it appears.
If the "-m" option does not appear, then the default value for
the mark message period is 20 minutes.
If the value specified with the "-m" option is 0, then the
mark message is not written.


The B<"--kernel-msg-console"> command line option can be specified to
configure I<syslog> on RHEL5 systems and I<rsyslog> on RHEL6 systems
to direct kernel messages to specified tty device.
The syslog system service will be restarted after a succeful change
to the config file.

The B<"--samba-gen-conf"> command line option generates an entirely
new Samba conf file appropriate to POS installed,
either "RTI" or "Daisy".
The "RTI" and "Daisy" version of the Samba conf file are
considerably different.
If a new Samba conf file is generated, the Samba system service "smb"
is restarted.

The B<"--samba-set-passdb"> command line option can be used to
configure samba to use a "passdb backend" of "smbpasswd".
It does this by editing the existing Samba conf file, adding
the parameter "passdb backend = smbpasswd" to the "[global]"
section of the Samba conf file.
If the Samba conf file is already so configured,
then no change is done.
If the Samba conf file is modified, the Samba system service "smb"
is restarted.

The B<"--samba-rebuild-passdb"> command line option can be used to
rebuild the samba "smbpasswd" file.
The only field updated in "smbpasswd" file is the "UID" field:
if the value in the "UID" field of the "smbpasswd" file
does not match the "UID" field in the "/etc/passwd" file
for the username in the "username" field of the "smbpasswd" file,
then the UID from the "/etc/passwd" file is substituted for the
value in the "smbpasswd" file.

The B<--bbj-gen-settings-file> command line option is useful for
system stagers and OSTools testers to see what the contents of
the BBj settings file would be when produced for the B<--rti14> option.
The BBj settings file is written to the current working directory and
is available for inspection but is not used or incorporated into the
RTI system in any way.

The B<--bbj-gen-properties-file> command line option is useful for
system stagers and OSTools testers to see what the contents of
the BBj properties file would be when produced for the B<--rti14> option.
The BBj properties file is written to the current working directory and
is available for inspection but is not used or incorporated into the
RTI system in any way.

The B<"--disable-kms"> command line option is used to disable
kernel (video) mode setting.
For Daisy customers that use the console of the Daisy server as a workstation,
disabling KMS is required or Daisy application screens do not appear
correctly on the virtual consoles.
The code for this option is also executed when the
C<--baremetal> option is specified.

Specifying the B<"--cupsconf"> command line option will cause
F<udpateos.pl> to edit the values of several variables in the
F</etc/cups/cupsd.conf> CUPS config file.
The code for this option is also executed when the
B<"--baremetal"> option is specified.
The following variables are set to the specified values:

=over

=item o

MaxJobs is set to 10000

=item o

PreserveJobHistory is set to "No"

=item o

PreserveJobFiles is set to "No"

=item o

If the platform is "RHEL5", Timeout is set to 0.
If the platform is "RHEL6", Timeout is set to 300.

=item o

ErrorPolicy is set to "retry-job"

=back

=head2 Linux Audit System Configuration

The B<"--audit-system-configure"> command line option provides
a method of configuring the Linux Audit System with an appropriate
config file and restarting the B<auditd> system service.
If the audit system is already configured, then no configuration
is performed.

The B<"--audit-system-rules-file=path"> command line option can be used
in conjunction with B<"--audit-system-configure"> to explicitly specify a
"rules" file to be used as a configuration file for the audit system, ie,
it is copied to F</etc/audit/rules.d> and the "auditd" system service
is restarted.
Before the path specified with B<"--audit-system-rules-file=path"> is used,
it is checked for security issues and if verified "OK",
it will be used to configure the audit system.
If there are issues with the path, eg there are illegal characters in the
file name, a warning is output and no configuration is performed.

If B<"--audit-system-configure"> is specifed without
B<"--audit-system-rules-file=path">, then
the following strategy will be used to determine
where to find the rules file in the following order:

=over 

=item (1) from the environment

if the rules file is specified in the environement via the variable
`AUDIT_SYSTEM_RULES_FILE`, the value will be verified as secure and
used as the rule file.

=item (2) from the OSTools config dir

if on RTI systems, there is a rules file in the ostools config dir
named F<rti.rules> or if on Daisy systems there is a rules file in the
ostools config dir named F<daisy.rules>, it will be used as the rule file.

=item (3) from a remote server

if on RTI systems, there is a rules file at the URL
F<"http://rtihardware.homelinux.com/ostools/rti.rules"> or
if on Daisy systems, there is a rules file at URL
F<"http://rtihardware.homelinux.com/ostools/daisy.rules">, then
it will be used as the rule file.

=item (4) rules generated by script

a default rules file appropriate to the POS will be generated and
used as the rule file.

=back


=head1 EXAMPLES

=over

=item Perform a truncated RTI install

 $ sudo updateos.pl --rti14

=item Perform a full RTI install

 $ sudo updateos.pl --rti14 --norti14-trunc

=item Change IP address of network device "eth0" to 192.168.2.32

 $ sudo updateos.pl --ipaddr=192.168.2.32 --netmask=255.255.255.0 --gateway=192.168.2.1

=item Change IP address of network device "eth1" to 192.168.2.33

 $ sudo updateos.pl --ipaddr=192.168.2.33 --ifname=eth1 --netmask=255.255.255.0 --gateway=192.168.2.1

=item Get Status of Ungregistred System with Subscription Manager

 $ sudo updateos.pl --sub-mgr-status
 [sub-mgr] subscription manager status: Unknown

=item Register System with the Subscription Manager

 $ sudo updateos.pl --sub-mgr-register
 The system has been registered with ID: 2c1e0459-a8c3-42a4-92bf-d802a742c736 
 Installed Product Current Status:
 Product Name: Red Hat Enterprise Linux Server
 Status:       Subscribed

 [sub-mgr] system registered via subscription manager

=item Get Status of Registred System with Subscription Manager 

 $ sudo updateos.pl --sub-mgr-status
 [sub-mgr] subscription manager status: Current

=item Get Identity of Registered System with Subscription Manager 

 $ sudo updateos.pl --sub-mgr-identity
 [sub-mgr] subscription manager system identity: 2c1e0459-a8c3-42a4-92bf-d802a742c736

=item Unregister System with the Subscription Manager

 $ sudo updateos.pl --sub-mgr-unregister
 1 subscription removed at the server.
 1 local certificate has been deleted.
 System has been unregistered.
 [sub-mgr] system unregistered via subscription manager

=back


=head1 FILES

=over 4

=item F</usr2/bbx/log/RTI-Patches.log>

Logfile for RTI systems.

=item F</d/daisy/log/RTI-Patches.log>

Logfile for Daisy systems.

=item F</boot/grub/grub.conf>

The GRUB config file.

=item F</etc/default/grub>

For RHEL7 systems, the GRUB2 config file.

=item F</etc/sysconfig/syslog>

The configuration file for the syslog system service that
needs to be edited for configuring the heartbeat.
This is for RHEL5 only.

=item F</etc/rsyslog.conf>

For RHEL6 systems, the configuration file for the syslog system service that
needs to be edited for configuring the heartbeat.

=item F</etc/samba/smb.conf>

The Samba configuration file.

=item F</etc/samba/smbpasswd>

The Samba password file when the "passdb backend = smbpasswd" is
specified in the Samba conf file.

=item F</var/lib/samba/private/smbpasswd>

For RHEL6 and RHEL7 systems,
the Samba password file when the "passdb backend = smbpasswd" is
specified in the Samba conf file.

=item F<jre-latest-linux-i586-rpm.bin>

The latest version of the Java SE JRE package file
for RHEL 32-bit servers.

=item F<jre-latest-linux-x64-rpm.bin>

The latest version of the Java SE JRE package file
for RHEL 64-bit servers.

=item F</etc/cups/cupsd.conf>

The values of several variables are set.

=item F</var/spool/cups>

Directory containing files which represent
completed and in-process CUPS print jobs.

=item F</etc/sysconfig/network-scripts/ifcfg-eth0>

This file is edited when the B<"--ipaddr=s"> command line option
is specified.

=item F</etc/hosts>

This file is edited when the B<"--ipaddr=s"> command line option
is specified.

=item F</etc/resolv.conf>

A new instance of this file is generated when the B<"--nameserver=s">
command line option is specified.

=item F</etc/sysconfig/i18n>

For RHEL5 and RHELl6 platforms only,
a new instance of this file is generated when the B<"--(i18n|gen-i18n-conf)">
command line option is specified.
Also, a new instance is generated as part of all the other the changes
when F<--daisy> is specified.

=item F</etc/yum.conf>

If the line "exclude=kernel" appears in this file,
the line will be commented out by B<"--yum">.

=item F</etc/locale.conf>

On RHEL7 systems, this config file is edited to set the system locale.

=item F</etc/inittab>

On RHEL5 and RHEL6 systems, this config file is edited to set
the default runlevel of the system.

=item F</etc/systemd/system/default.target>

On RHEL7 systems, this symlink is edited to set
the default target of the system to "multi-user".

=item F</etc/fstab>

On RHEL7 systems, the "nofail" mount option is added to the
entries for F</usr2> and F</d>.

=item F</etc/audit/rules.d/daisy.rules>

The Linux Audit System rules file for Daisy systems.

=item F</etc/audit/rules.d/rti.rules>

The Linux Audit System rules file for RTI systems.

=item F</proc/meminfo>

The contents of this file is used for getting the size of RAM.

=item F<bbjinstallsettings.txt>

The BBj settings file generated for the B<--rti14> option and
only used during staging.

=item F</usr2/basis/cfg/BBj.properties>

The BBj properties file.

=back


=head1 DIAGNOSTICS

=over 4

=item Exit status 0 ($EXIT_OK)

Successful completion.

=item Exit status 1 ($EXIT_COMMAND_LINE)

In general, there was an issue with the syntax of the command line.

=item Exit status 2 ($EXIT_MUST_BE_ROOT)

For all command line options other than "--version" and "--help",
the user must be root or running under "sudo".

=item Exit status 3 ($EXIT_SAMBA_CONF)

During the execution of "--samba-set-passdb" or
"--samba-rebuild-passdb", either the Samba conf file is missing, or
can't be modified.

=item Exit status 4 ($EXIT_GRUB_CONF)

An unexpected error occurred during editing the GRUB config file.
The original GRUB config file will be left unchanged.

=item Exit status 5 ($EXIT_ARCH)

The machine architecture of the system is unsupported (should not happen).

=item Exit status 6 ($EXIT_NO_SWAP_PARTITIONS)

There were no swap partitions found on either F</dev/sda> or F</dev/sdb>
when attempting to enable swapping via B<--swapon>.

=item Exit status 7 ($EXIT_MODIFY_FSTAB)

Could not update the F</etc/fstab> file
when attempting to enable swapping via B<--swapon>.

=item Exit status 8 ($EXIT_RAMINFO)

Could not open the F</proc/meminfo> file for getting the size of RAM.

=item Exit status 10 ($EXIT_JAVA_VERSION)

The name of the Java JRE package to be downloaded from B<"rtihardware.homelinux.com">
could not be determined.

=item Exit status 11 ($EXIT_JAVA_DOWNLOAD)

The Java JRE package
from B<"rtihardware.homelinux.com"> could not be downloaded.

=item Exit status 12 ($EXIT_JAVA_INSTALL)

The RPM from the download of the Java JRE package
from B<"rtihardware.homelinux.com"> could not be installed.

=item Exit Status 13 ($EXIT_RTI14)

The "--rti14" command line option was run and the system was not
configured with a static IP address.

=item Exit Status 15 ($EXIT_READAHEAD)

The "--uninstall-readahead" command line option was specified
on a RHEL6 system, and the "readahead" RPM could not be removed.

=item Exit Status 17 ($EXIT_SAMBA_PASSDB)

Could not rebuild the Samba password database file.

=item Exit Status 18 ($EXIT_KEEPKERNELS_MIN)

The value specified with B<--keepkernels=s> was less than
the minimum.

=item Exit Status 19 ($EXIT_PURGE_KERNEL_RPM)

Could not purge an old kernel rpm.

=item Exit Status 21 ($EXIT_WRONG_PLATFORM)

A command line option was run on an unsupported platform.

=item Exit status 22  ($EXIT_RHWS_CONVERT)

The "--ospatches" option was run on a Red Hat Workstation 5 system and
the conversion from "workstation" to "server" failed.

=item Exit status 23 ($EXIT_UP2DATE)

The "--ospatches" option was run on a RHEL 4 server system and
the "up2date" process failed.

=item Exit status 24 ($EXIT_YUM_UPDATE)

The "--ospatches" option was run on a RHEL 5 or 6 server system and
the "yum" process failed.

=item Exit status 25 ($EXIT_DIGI_DRIVERS)

The "--ospatches" option was run and the installation of the Digi Drivers
failed.

=item Exit status 26 ($EXIT_INITSCRIPTS)

The "--ospatches" option was run and the "fixup" required for
RHEL6 Daisy systems failed.  This "fixup" is only required when
there is the installation of any updated "initscripts" pacakges;
however, the "fixup" is run anytime the "--ospatches" option is
run and the "yum" command which runs returns successful exit status.
(the "fixup" merely consists of removing two files if they exist:
F</etc/init/start-ttys.conf> and F</etc/init/tty.conf>)

=item Exit status 27 ($EXIT_RHN_NOT_REGISTERED)

The system is not registered with the Red Hat Network, and
thus patches can not be dowloaded from Red Hat.

=item Exit status 30 ($EXIT_HOSTNAME_CHANGE)

The attempt to change the hostname of the system failed.

=item Exit status 31 ($EXIT_MOTD)

Could not truncate the "Message of the Day" (aka login banner) file.

=item Exit status 32 ($EXIT_RTI_SHOPNAME)

Could not get the RTI shop name.

=item Exit status 33 ($EXIT_RTI_SHOPCODE)

Could not get the RTI shop code.

=item Exit status 34 ($EXIT_DAISY_SHOPCODE)

Could not get the DAISY shop code.

=item Exit status 35 ($EXIT_CUPS_CONF_MISSING)

The CUPS config file does not exist.
Some commands edit this file and if it does not exist,
it is considered an error.

=item Exit status 36 ($EXIT_CUPS_CONFIGURE)

The "--cupsconf" option was specified and there was an
error rewriting the CUPS config file.

=item Exit status 37 ($EXIT_CUPS_SERVICE_STOP)

Could not stop the CUPS system service.

=item Exit status 38 ($EXIT_CUPS_SERVICE_START)

Could not start the CUPS system service.

=item Exit status 39 ($EXIT_DAISY_START)

Could not start the Daisy POS application.

=item Exit status 40 ($EXIT_SUB_MGR_IDENTIFICATION)

The subscription manager identity could not be obtained.

=item Exit status 41 ($EXIT_SUB_MGR_REGISTRATION)

The system could not be registered via the subscription manager.

=item Exit status 42 ($EXIT_SUB_MGR_UNREGISTRATION)

The system could not be un-registered via the subscription manager.

=item Exit status 43 ($EXIT_SUB_MGR_CONDITION)

The subscription manager status could not be obtained.

=item Exit status 44 ($EXIT_DAISY_STOP)

Could not stop the Daisy POS application.

=item Exit status 46 ($EXIT_DAISY_INSTALL_DHCP)

In order to configure the system with B<--daisy>,
the network configuration must not be booting via DHCP.

=item Exit status 47 ($EXIT_DAISY_SHOPNAME)

Could not get Daisy shop name

=item Exit status 48 ($EXIT_AUDIT_SYSTEM_CONFIGURE)

Could not configure the Linux Audit System.

=item Exit status 49 ($EXIT_CONFIGURE_DEF_PASSWORD_HASH)

The default password hash of the system could not be changed.

=item Exit status 50 ($EXIT_CONFIGURE_IP_ADDR)

The IP address of the system could not be changed.

=item Exit status 51 ($EXIT_CONFIGURE_HOSTNAME)

The hostname of the system could not be changed.

=item Exit status 52 ($EXIT_CONFIGURE_NAMESERVER)

Could not generate a new nameserver file, ie F</etc/resolv.conf>.

=item Exit status 53 ($EXIT_CONFIGURE_I18N))

Could not generate a new i18n config file, ie F</etc/sysconfig/i18n>.

=item Exit status 54 ($EXIT_CONFIGURE_YUM)

Could not configure yum to do kernel updates.

=item Exit status 55 ($EXIT_CONFIGURE_LOCALE)

Could not configure the system wide locale.

=item Exit status 56 ($EXIT_CONFIGURE_DEF_RUNLEVEL)

Could not configure the default runlevel.

=item Exit status 57 ($EXIT_CONFIGURE_DEF_TARGET)

Could not configure the systemd default target.

=item Exit status 58 ($EXIT_EDIT_FSTAB)

Could not edit the fstab.

=item Exit status 60 ($EXIT_APCUPSD_INSTALL)

Could not install the APCUPSD rpm.

=item Exit status 61 ($EXIT_BBJ_INSTALL)

Could not install BBj.

=item Exit status 62 ($EXIT_BLM_INSTALL)

Could not install the Basis license manager.

=item Exit status 70 ($EXIT_SYSLOG_CONF_MISSING)

The syslog config file does not exist.

=item Exit status 71 ($EXIT_SYSLOG_CONF_CONTENTS)

The contents of the syslog conf file are non-standard and
thus can not be updated.

=item Exit status 72 ($EXIT_SYSLOG_KERN_PRIORITY_VALUE)

The value of the kernel log priority was out of range.

=item Exit status 73 ($EXIT_SYSLOG_KERN_PRIORITY)

The kernel log priority could not be configured.

=item Exit status 74 ($EXIT_SYSLOG_MARK_VALUE)

The syslog mark value was out of range.

=item Exit status 75 ($EXIT_SYSLOG_MARK_PERIOD)

The syslog mark period could not be configured.

=item Exit status 76 ($EXIT_SYSLOG_KERN_TARGET_VALUE)

The syslog kernel message target was the empty string.

=item Exit status 77 ($EXIT_SYSLOG_KERN_TARGET)

The syslog kernel message tarkget could not be configured.

=item Exit status 78 ($EXIT_SYSLOG_RESTART)

The syslog system service could not be restarted.

=item Exit status 79 ($EXIT_GRUB2_CONFIGURE)

There was an error rewriting the GRUB2 config file.

=item Exit status 80 ($EXIT_GRUB2_CONF_MISSING)

The grub2 config file is missing.

=back


=head1 SEE ALSO

RTI Admin Guide


=cut
