package Method::Annotations::Annotation;
# ABSTRACT: The Annotation object

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use UNIVERSAL::Object;

our @ISA; BEGIN { @ISA = ('UNIVERSAL::Object') }
our %HAS; BEGIN {
    %HAS = (
        original => sub { die '`original` is required' },
        name     => sub { die '`name` is required' },
        args     => sub { +[] },
        handler  => sub {},
    )
}

sub original { $_[0]->{original} }

sub name { $_[0]->{name} }
sub args { $_[0]->{args} }

sub handler {
    $_[0]->{handler} = $_[1] if defined $_[1];
    $_[0]->{handler}
}

1;

__END__

=pod

=cut
