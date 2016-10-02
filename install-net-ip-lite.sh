#!/bin/sh
git clone https://github.com/tbrowder/Net-IP-Lite-Perl6.git

#cd Net-IP-Lite-Perl6

# the following two lines are for added info in the travis build log"
TD=`pwd`
echo "=== now working in dir '$TD' ==="
# the coup de grace:
panda install Net-IP-Lite-Perl6/
#panda install ./Net-IP-Lite-Perl6
#panda install .
