#!/bin/sh

git clone https://github.com/tbrowder/Net-IP-Lite-Perl6.git
cd Net-IP-Lite-Perl6
TD=`pwd`
echo "==== working in dir '$TD' ============="
panda install .
