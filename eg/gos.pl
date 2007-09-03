#!/usr/bin/perl 
use strict;
use warnings;

use Math::Telephony::ErlangB qw( gos );

$|++;
print "traffic: "; chomp(my $traffic = <STDIN>);
print "servers: "; chomp(my $servers = <STDIN>);
printf "blocking probability for $servers servers and $traffic Erlang of traffic is %.1f%%\n", gos($traffic, $servers) * 100;

