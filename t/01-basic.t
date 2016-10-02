use v6;
use lib <lib ../lib>;
use Test;

use Net::DNS::BIND::Manage;
use Net::IP::Lite :ALL;

# test 1
# need a file for hashing
my $s = "a quick red fox jumped\nover the brown dog.\n";
my $file = '.tmp';
spurt $file, $s;
my $hexhash = md5sum($file);
is $hexhash, '038d429cfb85209939198fb422acc9e6', 'hash (md5sum) file test';

# test 2
my $ipv4 = '1.2.3.4';
my $revip = ip-reverse-address($ipv4, 4);
is $revip, '4.3.2.1', 'reverse ipv4 test';

# test 3
#my $domain = 'mail.example.com';
#my $revdom = reverse-dotted-net($domain);
#is $revdom, 'com.example.mail', 'reverse domain test';

# test 4, 5
my $ipv4-good = '12.23.3.5';
my $ipv4-bad  = '12.23.3:5';
ok ip-is-ipv4($ipv4-good), 'is good ipv4 test';
nok ip-is-ipv4($ipv4-bad), 'is bad ipv4 test';

# test 6, 7
my $ipv6-good = '12::23:3:5';
my $ipv6-bad  = '12.23.3:5';
ok ip-is-ipv6($ipv6-good), 'is good ipv6 test';
nok ip-is-ipv6($ipv6-bad), 'is bad ipv6 test';

# test 8
my $soa = "  132 ; Serial\n";
spurt $file, $soa;
my $serial = read-zone-serial-from-file($file);
is $serial, '132', 'read serial from file';

unlink $file;

done-testing;

