unit module Net::DNS::BIND::Manage;

sub read-hosts(:$file, :%hosts, :%net) is export {
   
}

sub xx-hash($file) is export {
}

sub read-template($file) is export {
    return slurp($file);
}

