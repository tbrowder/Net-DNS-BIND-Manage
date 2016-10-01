PERL6     := perl6
LIBPATH   := lib

# set below to 1 for no effect, 1 for debugging messages
DEBUG := NET_DNS_BIND_Manage=0

# set below to 0 for no effect, 1 to die on first failure
EARLYFAIL := PERL6_TEST_DIE_ON_FAIL=0

# set below for 0 for no effect and 1 to run Test::META
TA := TEST_AUTHOR=1

.PHONY: test-funcs test test-orig bad good

default: test

TESTS     := t/*.t
BADTESTS  := bad-tests/*.t
GOODTESTS := good-tests/*.t

#test-funcs:
#	$(EARLYFAIL) PERL6LIB=$(LIBPATH) prove -v --exec=$(PERL6) t/99-exported-funcs.t


# the original test suite (i.e., 'make test')
test:
	for f in $(TESTS) ; do \
	    $(EARLYFAIL) PERL6LIB=$(LIBPATH) prove -v --exec=$(PERL6) $$f ; \
	done

bad:
	for f in $(BADTESTS) ; do \
	    $(EARLYFAIL) PERL6LIB=$(LIBPATH) prove -v --exec=$(PERL6) $$f ; \
	done

good:
	for f in $(GOODTESTS) ; do \
	    $(EARLYFAIL) PERL6LIB=$(LIBPATH) prove -v --exec=$(PERL6) $$f ; \
	done

test-orig:
	$(PERL) test/test_ellipsoid.pl > res.txt

	diff res.txt test/results.txt
