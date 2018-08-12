package decorators::from;
# ABSTRACT: Load decorators into scope

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Carp            ();
use Scalar::Util    ();
use List::Util      ();
use MOP             (); # this is how we do most of our work
use Module::Runtime (); # decorator provider loading

use MOPx::Decorators;

# ...

use decorators::providers::for_providers;

## --------------------------------------------------------
## Importers
## --------------------------------------------------------

sub import {
    my $class = shift;
    $class->import_into( scalar caller, @_ );
}

## --------------------------------------------------------
## Trait collection
## --------------------------------------------------------

sub import_into {
    my (undef, $package, @providers) = @_;

    Carp::confess('You must provide a valid package argument')
        unless $package;

    Carp::confess('The package argument cannot be a reference or blessed object')
        if ref $package;

    Carp::confess('You must supply at least one provider')
        unless scalar @providers;

    # so we can use lowercase attributes ...
    warnings->unimport('reserved')
        if grep /^:/, @providers;

    # expand any tags, they should match
    # the provider names available in the
    # decorators::providers::* namespace
    @providers = map /^\:/ ? 'decorators::providers:'.$_ : $_, @providers;

    # load the providers, and then ...
    Module::Runtime::use_package_optimistically( $_ ) foreach @providers;

    my $trait_role = MOPx::Decorators->new( namespace => $package );
    $trait_role->add_providers( @providers );

    return;
}

1;

__END__

=pod

=head1 DESCRIPTION

... no user serviceable parts inside

=cut
