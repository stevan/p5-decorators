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

sub set_providers {
    my ($self, @providers) = @_;
    $self->{_role}->set_roles( @providers );
}

# decorators ...

sub has_decorator {
    my ($self, $name) = @_;

    return unless $self->{_role}->has_method( $name );

    my $method = $self->{_role}->get_method( $name );
    return 1 if $method->origin_stash eq 'decorators::providers::for_providers';
    return 1 if $method->has_code_attributes('Decorator');
    return;
}

sub get_decorator {
    my ($self, $name) = @_;
    return unless $self->has_decorator( $name );
    return $self->{_role}->get_method( $name );
}

# composing

sub has_been_composed {
    my ($self) = @_;
    my $is_composed = MOP::Util::get_glob_slot( $self->{_role}, 'COMPOSED', 'SCALAR' );
    return 0 if not defined $is_composed;
    return $$is_composed;
}

sub compose {
    my ($self) = @_;
    Carp::confess('This decorator object has already been composed')
        if $self->has_been_composed;

    MOP::Util::compose_roles( $self->{_role} );
    MOP::Util::set_glob_slot( $self->{_role}, 'COMPOSED', \1 )
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
