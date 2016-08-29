use Panda::Builder;

use LWP::Simple;

class Build is Panda::Builder {
    method build($workdir) {

        # local dir for xxHash repo
        my $repodir = 'xxHash-git-repo-clone';
      
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
		++$binfils if $file.IO.f;
	    }
	    my $manfils = 0;
	    for @manfils -> $mf {
		my $file = $pref ~ '/share/man/man1' ~ $mf;
		++$manfils if $file.IO.f;
	    }
	    if $binfils == $binfils-needed && $manfils == $manfils-needed {
                #say "All dependencies found.";
                announce("All dependencies found.");
		$all-files-found = True;
		last FILE-CHECK;
	    }
	}

	# not finished if not all files found
	#if !$all-files-found {
	if True {
	    # need to download and build
            shell "rm -rf $repodir" if $repodir.IO.e;

	    my $gitrepo = "https://github.com/Cyan4973/xxHash.git";
            say "Cloning '$gitrepo' into '$repodir'";
	    shell "git clone https://github.com/Cyan4973/xxHash.git $repodir";

            say "DEBUG: Removing '$repodir'";
            shell "rm -rf $repodir" if $repodir.IO.e;
        }

    }
}
