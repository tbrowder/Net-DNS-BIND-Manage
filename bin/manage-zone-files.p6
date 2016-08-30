#!/usr/bin/env perl6

use Getopt::Std;

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

All is based on the list of domains, hosts, and reverse mapped domains.

=end pod

##### option handling ##############################
my %opts;
my ($create, $check, $debug, $verbose, $rdns, $tmpl);
sub usage() {
    say qq:to/END/;
    Usage: $*PROGRAM -c | -C [-v, -d, -r, -R]

    Creates or checks Bind 9 zone files.

    Modes:

      -c create forward DNS zone files
      -C check zone files

    Options:

      -R 
      -r create rDNS (reverse mapping) zone files
      -v verbose
      -d debug
    END

    exit;
}
# check for proper getopts signature
usage() if !getopts(
    'CcdvrR:',    # option string
    %opts,
    @*ARGS
);
usage() if !%opts;
if %opts<c> {
    $create = True;
}
else {
    $check = True;
}
$debug   = True if %opts<d>;
$verbose = True if %opts<v> || $debug;
$rdns    = True if %opts<r>;
##### end option handling ##########################

# address of most domains:
my $dnet = '142.54.186.2';
# address of the mailer
my $mxnet = '142.54.186.3';

# domain reverse mapping (just for the mail server)
# reverse mapping of mailer
#my $mxr = reverse-net($mxnet);

# name server addresses
my $ns1net = '159.203.190.205';
my $ns2net = '142.54.186.6';
# name server names
my $ns1 = 'ns1.tbrowder.net'; # primary name server
my $ns2 = 'ns2.tbrowder.net'; # primary name server
# responsible party
my $rp  = 'tom\.browder.gmail.com';

my $ttl = '3h'; # standard, shorten when doing maintenance or changes
check-or-create-files(:%opts, :$ttl, :$rdns, :$create);

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

if $debug {
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
