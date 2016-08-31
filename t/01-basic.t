use v6;
use lib <lib ../lib>;
use Net::DNS::BIND::Manage;
use Test;

plan 2;

# need a file for hashing
my $s = q:to/END/;
a quick red fox jumped
over the brown dog.
END
my $file = '.tmp';
my $fh = open $file, :w;
$fh.say($s);
close $fh;
my $hexhash = md5sum($file);
unlink $file;

# test 1
is $hexhash, '', 'hash file test';

my $ipv4 = '1.2.3.4';
my $revip = reverse-net($ipv4);

# test 2
is $revip, '4.3.2.1', 'reverse ipv4 test';

