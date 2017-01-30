package # hide from PAUSE
    Getopt::Handler;
use strict;
use warnings;

use Getopt::Long ();

our %OPTS_BY_PACKAGE;

sub set_opt_spec_for_slot {
    my ($class, $spec, $slot_name) = @_;
    my $opts = $OPTS_BY_PACKAGE{ $class } ||= {};
    $opts->{ $spec } = $slot_name;
}

sub get_opt_spec {
    my ($class) = @_;
    return $OPTS_BY_PACKAGE{ $class } ||= {};
}

sub get_options {
    my ($class) = @_;

    my $spec = get_opt_spec( $class );
    die 'Unable to find an option spec for class('.$class.')'
        unless $spec;

    my %opts = map { $_ => \(my $x) } keys %$spec;
    Getopt::Long::GetOptions( %opts );

    #use Data::Dumper;
    #warn Dumper $spec;
    #warn Dumper \%opts;

    return map {
        $spec->{ $_ },           # the spec key maps to the slot_name
        ${$opts{ $_ }}           # de-ref the scalar from Getopt::Long
    } grep defined ${$opts{$_}}, keys %opts;
}

1;
