#!/usr/bin/env perl6

use lib <../lib ../../../../lib>;
use Net::DNS::BIND::Manage;

=begin pod

This program has two major modes:

  1. create master zone files (new or updated)

  2. check existing zone files

When creating, existing (base) files are read to get the current
serial number.  Then a backup version is created with the same serial
number.  The two files's hashes are then compared to see if they are
the same.  If they are the same, the backup is deleted.  If they are
different, the backup is deleted and the base file rewritten with an
updated serial number.  Note that backups are NOT deleted if the debug
option is selected.

Checking at the moment merely checks the serial number and existence of
the files. Eventually, the check will be by the appropriate bind9
utility program.

All is based on the list of domains, hosts, and reverse mapped
domains.

=end pod

##### option handling ##############################
my $resp    = 0;
my $create  = 0;
my $check   = 0;
my $debug   = 0;
my $verbose = 0;
my $rdns    = 0;
my $tmpl    = 0;
sub usage() {
    say qq:to/END/;
    Usage: $*PROGRAM -c | -C [-v, -d, -r, -R, -f]

    Creates or checks Bind 9 zone files.

    Modes:

      -c create forward DNS zone files
      -C check zone files

    Options:

      -R <reponsible party e-mail> default: 'root@domain'
      -f <hosts file>              default: 'hosts'
      -r create rDNS (reverse mapping) zone files
      -v verbose
      -d debug
    END

    exit;
}

=begin pod
# check for proper getopts signature
usage() if !getopts(
    'CcdvrR:f:',    # option string
    %opts,
    @*ARGS
);
usage() if !%opts;
if %opts<c>:exists {
    $create = True;
}
else {
    $check = True;
}
$debug   = True if %opts<d>:exists;

$verbose = True if %opts<v>:exists || $debug;
$rdns    = True if %opts<r>:exists;
=end pod
if !@*ARGS {
    usage();
}

my %opts;
##### end option handling ##########################


# responsible party
my $rp  = 'tom\.browder.gmail.com';
my $ttl = '3h'; # standard, may shorten when doing maintenance or changes

check-or-create-file :%opts, :$ttl;

if $check {
    say 'Exiting after check.';
    exit;
}

# dump data
# say "Dumping \%net:";
# say %net.gist;
# say "Dumping \%domhosts:";
# say %domhosts.gist;
# say "debug exit"; exit;

if 0 && $debug {
    say "testing octet reverse:";
    my $ip = '1.2.3.4';
    say "IP: '$ip'";
    my $rip = reverse-net($ip);
    say "rIP: '$rip'";
}

=begin pod

# old stuff

# domain forward mapping
for @domains -> $d {
  say "Working domain '$d'...";

  # need several files
  my $fp = open "./master/db.$d", :w;
  write-soa($fp, $d);
  write-named-master($fm, $d);
  write-named-slave($fs, $d);

  # NS records
  # CNAME records
  # MX record
}

say "Working domain '$mxnet' reverse mapping to '$mxr'...";
my $fp = open "./master/db.$mxr", :w;
write-soa($fp, $mxr);
write-zone-master($fm, $mxr);
write-zone-slave($fs, $mxr);

=end pod
