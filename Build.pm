use Panda::Builder;

use LWP::Simple;

class Build is Panda::Builder {
    method build($workdir) {
        my $need-download = False;

        # no Windows support
        if $*DISTRO.is-win {
	    die "FATAL:  No support for Windows yet.";
	}
	elsif $*DISTRO.name ~~ /darwin/ {
	    die "FATAL:  No support for OS X yet.";
	}

	# hard-wired for now
	# required files for xxHash
	my @binfils = 'xxh32sum', 'xxh64sum', 'xxhsum';
	my @manfils = 'xxhsum.1';
	my $binfils-needed = @binfils.elems;
	my $manfils-needed = @manfils.elems;

	# all files must be in one of several places (PREFIX):
	my $all-files-found = False;
	my @prefs = '/usr', '/usr/local', '/opt/local';
	FILE-CHECK:
	for @prefs -> $pref {
	    my $binfils = 0;
	    for @binfils -> $bf {
		my $file = $pref ~ '/bin' ~ $bf;
		++$binfils if $file.IO ~ :e;
	    }
	    my $manfils = 0;
	    for @manfils -> $mf {
		my $file = $pref ~ '/share/man/man1' ~ $bf;
		++$manfils if $file.IO ~ :e;
	    }
	    if $binfils == $binfils-needed && $manfils == $manfils-needed {
		$all-files-found = True;
		last FILE-CHECK;
	    }
	}

	# not finished if not all files found
	if !$all-files-found {
	    # need to download and build
	    my $arch = "https://codeload.github.com/Cyan4973/{xxHash}/{tar.gz}/{v0.6.2}";
            say "Fetching  $arch";

=begin pod

            my $blob = LWP::Simple.get($arch);
            say "Unpacking  $f";
            spurt("$basedir\\$f", $blob);

            say "Verifying $f";
            my $hash = ps-hash("$basedir\\$f");
            if ($hash ne $h) {
                die "Bad download of $f (got: $hash; expected: $h)";
            }
            say "";

=end pod

        }

    }
}
