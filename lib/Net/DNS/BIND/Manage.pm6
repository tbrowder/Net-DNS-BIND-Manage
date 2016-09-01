unit module Net::DNS::BIND::Manage;

##### local vars #####
constant $bdir = 'bak';
constant $mdir = 'master';
constant $sdir = 'slave';
constant $soa-spaces = ' ' x 9;
# assumes serial number is no more than 10 chars
constant $max-serial-len = 10;
my $fhnamedmaster = Nil;
my $fhnamedslave  = Nil;
my $soa-cmn       = Nil;
my $debug         = False;
my %domain;
my %misc;
my $ns1net; # IPv4
my $ns2net; # IPv4
my $ns1domain;
my $ns2domain;
my $rp;

=begin pod
    my (%h, @domains, %net, %host, $max-serial-len,
    $soa-spaces, $soa-cmn, $bakdir,
    $fhnamedmaster, $fhnamedslave);
=end pod

my @keywords = <
    mx
    nomx
    ns1
    ns2
    priority
    rdns
>;

##### exported subs #####
sub check-or-create-files(:%opts, Str :$ttl = '3h') is export {
    my $do-rdns = ?%opts<r>;
    my $create  = ?%opts<c>;
    my $check   = !$create;
    my $verbose = ?%opts<c>;
    my $file    = %opts<f> ?? %opts<f> !! 'hosts';
    $debug      = ?%opts<d>;
    $rp         = %opts<R> ?? %opts<R> !! Nil;

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

    # need some dirs they don't exist
    for $bdir, $mdir, $sdir -> $d {
	mkdir $d if !$d.IO.e;
    }

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

    # collect file data into hashes
    read-hosts-file($file);
    for %domain.keys -> $d {
	%domain{$d}<file>    = "$mdir/db.$d";
	%domain{$d}<bakfile> = "$bdir/db.$d.bak";
    }
    if $do-rdns {
	die 'fix this';
	#%domain{$mxr}<file>    = "$mdir/db.$mxr";
	#%domain{$mxr}<bakfile> = "$bdir/db.$mxr.bak";
    }

    my $nfiles = 0;
    my $nfound = 0;
    for %domain.keys -> $d {
	++$nfiles;

	# is this a reverse mapping?
	my $is-reverse = $d ~~ /\d+'.'\d+'.'\d+/ ?? True !! False;

	my $file = %domain{$d}<file>; # base file
	say "Checking for file '$file'..." if %opts<v>;
	# file exists?
	if $file.IO.f {
	    ++$nfound;
	    say "  True: Found file '$file'..." if %opts<v>;
	    # get the serial number
	    my Int $serial = read-zone-serial-from-file($file);
	    say "  Serial is '$serial'..." if %opts<v>;

	    # get its hash
	    my $hash = md5sum($file);
	    say "  Hash is       '$hash'..." if %opts<v>;
            if $create {
                my $bf = %domain{$d}<bakfile>;
		if !$is-reverse {
                    create-zone-master-db($d, $serial, $bf, $ttl);
		}
		else {
		    warn "fix this";
		}
                my $bh = md5sum($bf);
                if $hash ~~ $bh {
                    # no diff, no change needed
		    say "  Base and bak files are the same--no change needed."
                        if %opts<v>;
                }
                else {
		    say "  Base and bak files are NOT the same--new file and serial needed."
                        if %opts<v>;
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
	    say "  False: File '$file' NOT found..." if %opts<v>;
            if $create {
                # need a new file
		say "  Creating a new base file with serial = 1." if %opts<v>;
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

    if %opts<v> {
	my $s = $nfiles > 1 ?? 's' !! '';
	my $nm = $nfiles - $nfound;
	if !$create {
	    say "Checked for $nfiles file$s.  Found $nfound.";
	    say "Missing $nm to be created anew.";
	}
    }
}

sub is-ipv4($data) is export {
    my $d = $data;

    if $d ~~ m:s/(<-[\\]>)'.'/ {
	#say "\$0 = '$0'";
        $d ~~ s:g:s/(<-[\\]>)\./$0 /;
	my @d = $d.words;
	my $n = @d.elems;
	return False if $n == 0 || $n > 4;

	# if we have one to four octets of numbers 255 or less we consider it an IPv4
	for @d -> $d {
	    return False if $d !~~ /^ \d ** 1..3 $/;
	    return False if $d > 255;
	}
	return True;
    }
    return False;
}

sub is-ipv6($data) is export {
    my $d = $data;

    my @d = $d.split(':');
    my $n = @d.elems;
    return False if $n == 0 || $n > 15;

    for @d -> $d {
	return False if $d !~~ /^ \d ** 1..8 $/;
	return False if $d > 0xffff_ffff;
    }
    return True;
}

sub reverse-dotted-net($dotted-token) is export {
    # from h2n, sub REVERSE:
    #
    # Reverse the octets of a network specification or the labels of a
    # domain name.  Only unescaped "." characters are recognized as
    # octet/label delimiters.

    my $d = $dotted-token;

=begin pod

    #say "================";
    #say "\$ip in = '$d'";
    #$d ~~ s:g:s/([^\\])'.'/$0 /;
    #say "\$ip spaces for dots = '$d'";
    #say "================";

    $d = $dotted-token;
    #say "\$ip in = '$d'";

=end pod

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

sub reverse-ipv6($ipv6) is export {
    # may be in one of many forms!!
}

sub read-zone-serial-from-file($file) returns Int is export {
    my Int $serial = 0;
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

sub md5sum($file) is export {
    use Digest::MD5;
    my $d = Digest::MD5.new;
    my $data = slurp $file;
    my $hexhash = $d.md5_hex($data);
    return $hexhash;
}
##### end exported subs #####

##### local subs #####
sub read-hosts-file($file)  {
    my $fh = open $file;
    my $lnum = 0;
    LINE:
    for $fh.IO.lines {
        ++$lnum;
        my $line = $_;
        say "\$line $lnum = '$line'" if $debug;
        my $idx = index $line, '#';
        say "\$idx = '$idx'" if $debug && $idx.defined;
        my $comment;
        if $idx.defined {
            $comment = substr $line, $idx + 1;
            $line    = substr $line, 0, $idx
        }
        # extract info from9 $line: ip, domain, aliases
        my @words = $line.words;
        next if !@words.elems;

        my $ip = @words.shift;
        # v4 or v6?
        my $typ = 4; # for now
        # ignore lines with public IPs
        if $typ == 4 {
            my @octets = $ip.split('.');
            if @octets[0] ~~ /^[10 | 127]$/
	        || (@octets[0] ~~ /192/ && @octets[1] ~~ /168/) {
                next LINE;
            }
        }

        my $domain = @words.shift;
        %domain{$domain}<net> = $ip;

        my @aliases = @words;
        %domain{$domain}<aliases> = @aliases;

        # extract info from any comment: key words
        if $comment {
            for @keywords -> $kw {
                if $comment ~~ / '[' $kw \s* [ '=' \s* (<[\w\d]>*) \s* ]? ']' / {
                    my $val = $0;
                    %domain{$domain}<keywords>{$kw} = $val;
                    $ns1net    = $ip if $kw ~~ /ns1/;
                    $ns2net    = $ip if $kw ~~ /ns2/;
                    $ns1domain = $domain if $kw ~~ /ns1/;
                    $ns2domain = $domain if $kw ~~ /ns2/;
                }
            }
        }
    }
}

sub read-template($file) {
    return slurp($file);
}

sub write-soa($fp, $domain, $serial, $ttl = '3h') {
    my $d = $domain;
    $fp.say("\$TTL $ttl");
    my $rp = %domain{$d}<rp> ?? %domain{$d}<rp> !! "root.$d";
    $fp.say("$domain. IN SOA $ns1net. $rp. (");

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
