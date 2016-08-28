#!/usr/bin/env perl6

use Getopt::Std;

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
my ($create, $check, $debug, $verbose)
 = (False, False, False, False);
sub usage() {
    say qq:to/END/;
    Usage: $*PROGRAM -c | -C [-v, -d]

    Creates or checks bind9 zone files.

    Options:

      -c create
      -C check
      -v verbose
      -d debug
    END

    exit;
}
# check for proper getopts signature
usage() if !getopts(
    'Ccdv',    # option string
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
##### end option handling ##########################

# some global vars (defined in BEGIN block at EOF)
my (%h, @domains, %net, %host, $max-serial-len,
    $soa-spaces, $soa-cmn, $bakdir,
    $fhnamedmaster, $fhnamedslave);

# address of most domains:
my $dnet = '142.54.186.2';
# address of the mailer
my $mxnet = '142.54.186.3';

# domain reverse mapping (just for the mail server)
# reverse mapping of mailer
my $mxr = reverse-net($mxnet);

# name server addresses
my $ns1net = '159.203.190.205';
my $ns2net = '142.54.186.6';
# name server names
my $ns1 = 'ns1.tbrowder.net'; # primary name server
my $ns2 = 'ns2.tbrowder.net'; # primary name server
# responsible party
my $rp  = 'tom\.browder.gmail.com';

my $ttl = '3h'; # standard, shorten when doing maintenance or changes
check-or-create-files($ttl, $create);

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


##### subroutines #####
sub read-zone-serial-from-file($file) returns Int {
    my Int $serial = $0;
    # given a file handle for a zone file
    my $fh = open $file;
    for $fh.IO.lines -> $line {
	if $line ~~ /^ \s* (\d+) \s* ';' \s* 'Serial' \s* $/ {
	    say "DEBUG: line = '$line'" if $debug;
	    say "DEBUG: \$0 = '$0'" if $debug;
	    $serial = +$0;
	    return $serial; # the serial number
	}
    }
    return $serial;
}

sub write-soa($fp, $domain, $serial, $ttl = '3h') {
    $fp.say("\$TTL $ttl");
    $fp.say("$domain. IN SOA $ns1. $rp. (");

    my $len = $max-serial-len;
    my $sp  = $soa-spaces;
    $fp.print(sprintf("$sp %-*.*s $sp; Serial\n", $len, $len, $serial));
    $fp.print($soa-cmn);
}

sub write-rr($fp, $domain) {
}

sub write-ns($fp, $domain) {
    my $s = qq:to/END/;
    ;
    ; Name servers (the name @ is implied)
    ;
             IN NS  $ns1net.
             IN NS  $ns2net.
    END

    $fp.print($s);
}

sub write-mx($fp, $domain) {
}

sub reverse-net($dotted-token) {
    # from h2n, sub REVERSE:
    #
    # Reverse the octets of a network specification or the labels of a
    # domain name.  Only unescaped "." characters are recognized as
    # octet/label delimiters.

    my $d = $dotted-token;

    #say "================";
    #say "\$ip in = '$d'";
    $d ~~ s:g:s/([^\\])'.'/$0 /;
    #say "\$ip spaces for dots = '$d'";
    #say "================";

    $d = $dotted-token;
    #say "\$ip in = '$d'";
    if $d ~~ m:s/(<-[\\]>)'.'/ {
	#say "\$0 = '$0'";
        $d ~~ s:g:s/(<-[\\]>)\./$0 /;
    }
    else {
	#say "no match";
    }
    #say "\$ip spaces = '$d'";
    my @d = $d.words;
    #print "\$ip split = ";
    #say @d.gist;
    $d = join '.', reverse @d;
    #say "\$ip reversed = '$d'";
    return $d;
}

sub my-hash($file) {
    my $proc = shell "xxhsum $file", :out;
    my $resp = $proc.out.slurp-rest;
    my $hash = $resp.words[0];
    return $hash;
}

sub write-soa-cmn()  {
    # all below is common to all domains and should be done once
    # globally:

    my @s[4];
    @s[0] = '3h';
    @s[1] = '1h';
    @s[2] = '1w';
    @s[3] = '1h )';

    my $len = $max-serial-len;
    my $sp  = $soa-spaces;
    # ready to pretty print
    @s[0] = sprintf("$sp %-*.*s $sp; Refresh interval", $len, $len, @s[0]);
    @s[1] = sprintf("$sp %-*.*s $sp; Retry interval", $len, $len, @s[1]);
    @s[2] = sprintf("$sp %-*.*s $sp; Expiry interval", $len, $len, @s[2]);
    @s[3] = sprintf("$sp %-*.*s $sp; Negative caching interval", $len, $len, @s[3]);
    my $cmn = '';
    for @s -> $s {
        #say "'$s'";
        #$fp.say($s);
	$cmn ~= $s;
	$cmn ~= "\n";
    }
    return $cmn;
}

sub check-or-create-files($ttl, $create = False) {
    # need to check and update serial numbers if necessary
    # scheme:
    #   assemble hash (%h) of zone master file names to be written or checked
    #     for each file in hash
    #       if file exists
    #         set %h<file><hash> to file hash
    #         read file to get file serial
    #         set %h<file><serial> to file serial
    #       else
    #         set %h<file><hash> to zero
    #         set %h<file><serial> to zero
    #

    # info needed for create option
    if $create {
	# soa boiler plate:
	$soa-cmn = write-soa-cmn();
	# named.conf for master and slave
	$fhnamedmaster = open './master/named.conf', :w;
	$fhnamedslave  = open './slave/named.conf', :w;
	create-named-master($fhnamedmaster);
	create-named-slave($fhnamedslave);
    }

    # collect file data into %h
    for @domains -> $d {
	%h{$d}<file>    = "master/db.$d";
	%h{$d}<bakfile> = "$bakdir/db.$d.bak";
    }
    %h{$mxr}<file>    = "master/db.$mxr";
    %h{$mxr}<bakfile> = "$bakdir/db.$mxr.bak";

    my $nfiles = 0;
    my $nfound = 0;
    for %h.keys -> $d {
	++$nfiles;

	# is this a reverse mapping?
	my $is-reverse = $d ~~ /\d+'.'\d+'.'\d+/ ?? True !! False;

	my $file = %h{$d}<file>; # base file
	say "Checking for file '$file'..." if $verbose;
	# file exists?
	if $file.IO ~~ :e {
	    ++$nfound;
	    say "  True: Found file '$file'..." if $verbose;
	    # get the serial number
	    my Int $serial = read-zone-serial-from-file($file);
	    say "  Serial is '$serial'..." if $verbose;

	    # get its hash
	    my $hash = my-hash($file);
	    say "  Hash is       '$hash'..." if $verbose;
            if $create {
                my $bf = %h{$d}<bakfile>;
		if !$is-reverse {
                    create-zone-master-db($d, $serial, $bf, $ttl);
		}
		else {
		    warn "fix this";
		}
                my $bh = my-hash($bf);
                if $hash ~~ $bh {
                    # no diff, no change needed
		    say "  Base and bak files are the same--no change needed." if $verbose;
                }
                else {
		    say "  Base and bak files are NOT the same--new file and serial needed." if $verbose;
                    # need a new file
		    say "    Old serial: $serial";
                    ++$serial;
		    say "    New serial: $serial";
		    if !$is-reverse {
			create-zone-master-db($d, $serial, $file, $ttl);
		    }
		    else {
			warn "fix this";
		    }
                }
                unlink $bf if !$debug;
            }
	}
	else {
	    # set values
	    say "  False: File '$file' NOT found..." if $verbose;
            if $create {
                # need a new file
		say "  Creating a new base file with serial = 1." if $verbose;
                my $serial = 1;
		if !$is-reverse {
                    create-zone-master-db($d, $serial, $file);
		}
		else {
		    warn "fix this";
		}
            }
	}

    }

    if $verbose {
	my $s = $nfiles > 1 ?? 's' !! '';
	my $nm = $nfiles - $nfound;
	if $check {
	    say "Checked for $nfiles file$s.  Found $nfound.";
	    say "Missing $nm to be created anew.";
	}
	else {
	    # create
	}
    }
}

sub create-zone-master-db($domain, $serial, $file, $ttl = '3h') {
    my $fp = open $file, :w;
    # soa
    write-soa($fp, $domain, $serial, $ttl);
    append-to-named-master($fhnamedmaster, $domain);
    append-to-named-slave($fhnamedslave, $domain);
}

sub create-reverse-zone-master-db($reverse-net, $domain, $serial, $file, $ttl = '3h') {
    # use global vars %h and %hosts for data
}

sub create-named-master(IO::Handle:D $fh) {
    my $s = qq:to/END/;
    // this file should be placed in directory "/etc" as "/etc/named.conf"
    // BIND configuration (from "DNS and BIND", p. 67)
    options = \{
	directory "var/named";
	// place additional options here
	// from p. 73, BIND defaults
	check-names master fail;
	check-names slave warn;
	check-names response ignore;
    };
    END

    $fh.print($s);
}

sub create-named-slave(IO::Handle:D $fh) {
    my $s = qq:to/END/;
    // this file should be placed in directory "/etc" as "/etc/named.conf"
    // BIND configuration (from "DNS and BIND", p. 67)
    options = \{
	directory "/var/named";
	// place addiitonal options here
	// from p. 73, BIND defaults
	check-names master fail;
	check-names slave warn;
	check-names response ignore;
    };
    END

    $fh.print($s);
}

sub append-to-named-master(IO::Handle:D $fh, $domain) {
    my $s = qq:to/END/;

    zone "$domain" in \{
	type master;
	file "db.$domain";
    };
    END

    $fh.print($s);
}

sub append-to-named-slave(IO::Handle:D $fh, $domain) {
    my $s = qq:to/END/;

    zone "$domain" in \{
	type slave;
	file "bak.$domain";
	masters \{ $ns1net; };
    };
    END

    $fh.print($s);
}

############ end subroutines ################
BEGIN {
    # define some global vars

    $bakdir = 'bak';
    $fhnamedmaster = Nil;
    $fhnamedslave  = Nil;

    $soa-spaces = ' ' x 9;
    # assumes serial number is no more than 10 chars
    $max-serial-len = 10;

    # list of domains for the public
    @domains = <
        f-111.org
        tbrowder.net
        highlandsprings61.org
    >;

    # hash of special needs by net and domain
    %net = [
	# keyed by network
	'142.54.186.2/31' => {},
	'142.54.186.4/31' => {},
	'142.54.186.6/32' => {},
    ];

    # domains with hosts
    %host = [
	'tbrowder.net' => {
	    hosts => [
		'bigtom',
		'ns1',
		'ns2',
		'mail'
	    ]
	},
    ];
}
