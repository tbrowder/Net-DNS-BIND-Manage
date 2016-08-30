unit module Net::DNS::BIND::Manage;

my @keywords = <
    mx
    nomx
    ns1
    ns2
    priority
    rdns
>;

sub read-hosts(:$file, :%hosts, :%net) is export {
    my $fh = open $fiie;
    LINE:
    for $fh.IO.lines -> $line is rw {
        my $idx = index $line, '#';
        my $coment;
        if $idx {
            $comment = substr $line, $idx + 1;
            $line    = substr $line, 0, $idx
        }
        # extract info from $line: ip, domain, aliases
        my @words = $line.words;

        my $ip = @words.shift;
        # v4 or v6?
        my $typ = 4; # for now
        # ignore lines with public IPs
        if $typ == 4 {
            my @octets = $ip.split('.');
            if @octets[0] == 10 || @octets[0] == 127
	        || (@octets[0] == 192 && @octets[1] == 168) {
                next LINE;
            }
        }

        my $domain = @words.shift;
        %domain{$domain}<net> = $ip;

        my @aiases = @words;
        %domain{$domain}<aliases> = @aliases;

        # extract info from any comment: key words
        if $comment {
            for @keywords -> $kw {
                if $comment ~~ / '[' $kw \s* ['=' \s* (<[\w\d]+>) \s* ']' / {
                    my $val = $0;
                    %domain{$domain}<keywords>{$kw} = $val;
                }
            }
        }
    }
}

sub xx-hash($file) is export {
}

sub read-template($file) is export {
    return slurp($file);
}

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

sub check-or-create-files($ttl, $create = False) is export {
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
