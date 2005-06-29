package Math::Telephony::ErlangB;

=head1 NAME

Math::Telephony::ErlangB - Perl extension for Erlang B calculations

=head1 SYNOPSIS

  use Math::Telephony::ErlangB qw( :all );

  # Evaluate blocking probability
  $bprob = blocking_probability($traffic, $servers);
  $gos = gos($traffic, $servers); # Same result as above

  # Dimension minimum number of needed servers
  $servers = servers($traffic, $gos);

  # Calculate maximum serveable traffic
  $traffic = traffic($servers, $gos); # Default precision 0.001
  $traffic = traffic($servers, $gos, 1e-10);


=head1 DESCRIPTION

This module contains various functions to deal with Erlang B calculations.

The Erlang B model allows dimensioning the number of servers in a
M/M/S/0/inf model (Kendall notation):

=over

=item *

The input process is Markovian (Poisson in this case)

=item *

The serving process is Markovian (ditto)

=item *

There are S servers

=item *

There's no wait line (pure loss)

=item *

The input population is infinite

=back

=head2 EXPORT

None by default. Following functions can be imported at once via the
":all" keyword.

=cut

use 5.008000;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Math::Telephony::ErlangB ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ('all' => [qw( blocking_probability gos servers traffic )]);

our @EXPORT_OK = (@{$EXPORT_TAGS{'all'}});

our @EXPORT = qw();

our $VERSION = '0.05';

# Preloaded methods go here.

# Workhorse functions, no check on input value is done!
sub _blocking_probability {
   my ($traffic, $servers) = @_;
   my $gos = 1;
   for my $m (1 .. $servers) {
      my $tmp = $gos * $traffic;
      $gos = $tmp / ($m + $tmp);
   }
   return $gos;
} ## end sub _gos

sub _generic_servers {
   my $cost = shift;

   # Exponential "backoff"
   my $servers = 1;
   $servers *= 2 while ($cost->($servers) > 0);
   return $servers if ($servers <= 2);

   # Binary search
   my ($minservers, $maxservers) = ($servers / 2, $servers);
   while ($maxservers - $minservers > 1) {
      $servers = int(($maxservers + $minservers) / 2);
      if ($cost->($servers) > 0) {
         $minservers = $servers;
      }
      else {
         $maxservers = $servers;
      }
   }
   return $maxservers;
}

sub _generic_traffic {
   my ($cond, $prec, $hint) = @_;

   # Establish some upper limit
   my ($inftraffic, $suptraffic) = (0, $hint || 1);
   while ($cond->($suptraffic)) {
		$inftraffic = $suptraffic;
		$suptraffic *= 2;
	}

   # Binary search
   while (($suptraffic - $inftraffic) > $prec) {
      my $traffic = ($suptraffic + $inftraffic) / 2;
      if ($cond->($traffic)) {
         $inftraffic = $traffic;
      }
      else {
         $suptraffic = $traffic;
      }
   } ## end while (($suptraffic - $inftraffic...
   return $inftraffic;
}


=head2 VARIABLES

These variables control different aspects of this module, such as
default values.

=over

=item B<$default_precision = 0.001;>

This variable is the default precision used when evaluating the maximum
traffic sustainable using the B<traffic()> function below.

=back

=cut


our $default_precision;
BEGIN {
   $default_precision = 0.001;
}


=head2 FUNCTIONS

The following functions are available for exporting. Three "concepts"
are common to them all:

=over

=item *

B<traffic> is the offered traffic expressed in Erlang. When an input
parameter, this value must be defined and greater or equal to 0.

=item *

B<servers> is the number of servers in the queue. When an input parameter,
this must be a defined value, greater or equal to 0.

=item *

B<blocking probability> is the probability that a given service request
will be blocked due to congestion.

=item *

B<gos> is the I<grade of service>, that corresponds to the blocking
probability for Erlang B calculation. The concept of Grade of Service is
a little different in perspective: in general, it should give us an
estimate of how the service is good (or bad). In the Erlang B model
this role is played by the blocking probability, thus the B<gos> is
equal to it.

=back


=over

=item B<$bprob = blocking_probability($traffic, $servers);>

Evaluate the blocking probability from given traffic and numer of
servers.

=cut

sub blocking_probability {
   my ($traffic, $servers) = @_;

   return undef
     unless defined($traffic)
     && ($traffic >= 0)
     && defined($servers)
     && ($servers >= 0)
     && (int($servers) == $servers);
   return 0 unless $traffic > 0;
   return 1 unless $servers > 0;

   _blocking_probability($traffic, $servers);
} ## end sub gos


=item B<$gos = gos($traffic, $servers);>

Evaluate the grade of service from given traffic and number of servers.
For Erlang B, the GoS figure corresponds to the blocking probability.

=cut

sub gos { blocking_probability(@_) }

=item B<$servers = servers($traffic, $bprob);>

Calculate minimum number of servers needed to serve the given traffic
with a blocking probability not greater than that given.

=cut

sub servers {
   my ($traffic, $gos) = @_;

   return undef
     unless defined($traffic)
     && ($traffic >= 0)
     && defined($gos)
     && ($gos >= 0) && ($gos <= 1);
   return 0 unless ($traffic > 0 && $gos < 1);
   return undef unless ($gos > 0);

   _generic_servers(sub {_blocking_probability($traffic, $_[0]) > $gos});
} ## end sub servers

=item B<$traffic = traffic($servers, $bprob);>

=item B<$traffic = traffic($servers, $bprob, $prec);>

Calculate the maximum offered traffic that can be served by the given
number of serves with a blocking probability not greater than that given.

The prec parameter allows to set the precision in this traffic calculation.
If undef it defaults to $default_precision in this package.

=back

=cut

sub traffic {
   my ($servers, $gos, $prec) = @_;

   return undef
     unless defined($servers)
     && ($servers >= 0)
     && (int($servers) == $servers)
     && defined($gos)
     && ($gos >= 0)
     && ($gos <= 1);
   return 0 unless ($servers > 0 && $gos > 0);
   return undef unless ($gos < 1);

   $prec = $default_precision unless defined $prec;
   return undef unless ($prec > 0);

	_generic_traffic(sub {_blocking_probability($_[0], $servers) < $gos }, $prec, $servers);
} ## end sub traffic

1;
__END__

=head1 SEE ALSO

You can I<google> for plenty of information about Erlang B.

=head1 AUTHOR

Flavio Poletti E<lt>flavio@polettix.itE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Flavio Poletti

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.


=cut
