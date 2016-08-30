unit module Net::DNS::BIND::Manage;

my @keywords = <
    mx
    nomx
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
            if @octets[0] == 10 || (@octets[0] == 192 && @octets[1] == 168) {
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

