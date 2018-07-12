package MOPx::Decorators;
# ABSTRACT: MOP level abstraction for decorators attached to a namespace

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use MOP        ();
use MOP::Role  ();
use MOP::Util  ();
use List::Util ();

use constant DECORATOR_SUB_NAMESPACE => '__DECORATORS__';

use parent 'UNIVERSAL::Object::Immutable';
our %HAS; BEGIN {
    %HAS = (
        namespace => sub {},
        # internal data ...
        _role => sub {},
    )
}

sub BUILD {
    my ($self, $params) = @_;

    $self->{_role} = MOP::Role->new( $self->{namespace}.'::'.DECORATOR_SUB_NAMESPACE );
}

# providers ...

sub get_providers {
    my ($self) = @_;
    $self->{_role}->roles;
}

sub add_providers {
    my ($self, @providers) = @_;

    my @roles = $self->{_role}->roles;
    $self->{_role}->set_roles( List::Util::uniq( @roles, @providers ) );

    # Do we guard aginst this happening more than once? at runtime? does it matter?
    MOP::Util::compose_roles( $self->{_role} );
}

# decorators ...

sub has_decorator {
    my ($self, $name) = @_;
    # TODO;
    # This should check that this method
    # is a `Decorator` and throw an exception
    # otherwise.
    # - SL
    $self->{_role}->has_method( $name );
}

sub get_decorator {
    my ($self, $name) = @_;
    # TODO;
    # This should check that this method
    # is a `Decorator` and throw an exception
    # otherwise.
    # - SL
    $self->{_role}->get_method( $name );
}

1;

__END__

__END__

=pod

=head1 DESCRIPTION

This is a L<MOP> level abstraction for a set of decorators that
are attached to a given namespace.

This class has two responsibility, ...

The first is to handle composing of decorator providers.

We do this using role compositon, so that we can get the built in
conflict detection to avoid decorator name collisions.

The second is to handle accessing the set of available decorators.

=cut
