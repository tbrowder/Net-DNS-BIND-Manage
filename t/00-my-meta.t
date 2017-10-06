use v6;
use lib 'lib';
use Test;

plan 1;

constant AUTHOR = ?%*ENV<TEST_AUTHOR>;

if 0 && AUTHOR {
    require Test::META <&meta-ok>;
    meta-ok;
    done-testing;
}
else {
     skip-rest "Skipping author test";
     exit;
}
