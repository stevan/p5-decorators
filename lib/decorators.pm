package decorators;
# ABSTRACT: Apply decorators to your methods

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Carp         ();
use Scalar::Util ();
use MOP          (); # this is how we do most of our work

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
    my (undef, $package, @args) = @_;

    Carp::confess('You must provide a valid package argument')
        unless $package;

    Carp::confess('The package argument cannot be a reference or blessed object')
        if ref $package;

    # convert this into a metaobject
    my $meta = MOP::Role->new( $package );

    Carp::confess('Cannot install decorator collectors, MODIFY_CODE_ATTRIBUTES method already exists')
        if $meta->has_method('MODIFY_CODE_ATTRIBUTES') || $meta->has_method_alias('MODIFY_CODE_ATTRIBUTES');

    Carp::confess('Cannot install decorator collectors, FETCH_CODE_ATTRIBUTES method already exists')
        if $meta->has_method('FETCH_CODE_ATTRIBUTES') || $meta->has_method_alias('FETCH_CODE_ATTRIBUTES');

    # now install the collectors ...

    my %accepted; # shared data between the collectors ...

    $meta->alias_method(
        FETCH_CODE_ATTRIBUTES => sub {
            my (undef, $code) = @_;
            # return just the strings, as expected by attributes ...
            return $accepted{ $code } ? @{ $accepted{ $code } } : ();
        }
    );

    $meta->alias_method(
        MODIFY_CODE_ATTRIBUTES => sub {
            my ($pkg, $code, @attrs) = @_;

            my $role       = MOP::Role->new( $pkg );
            my $method     = MOP::Method->new( $code );
            my @attributes = map MOP::Method::Attribute->new( $_ ), @attrs;

            my $decorators = MOP::Role->new( $role->name.'::__DECORATORS__' );
            my @unhandled  = map $_->original, grep !$decorators->has_method( $_->name ), @attributes;

            #use Data::Dumper;
            #warn Dumper {
            #    FROM       => __PACKAGE__,
            #    package    => $pkg,
            #    role       => [map $_->fully_qualified_name, MOP::Role->new( $role->name.'::__DECORATORS__' )->methods],
            #    attributes => \@attributes,
            #    unhandled  => \@unhandled,
            #};

            # return the bad decorators as strings, as expected by attributes ...
            return @unhandled if @unhandled;

            foreach my $attribute ( @attributes ) {
                my $h = $decorators->get_method( $attribute->name );

                $h or die 'This should never happen, as we have already checked this above ^^';

                $h->body->( $role, $method, @{ $attribute->args || [] } );

                if ( $h->has_code_attributes('OverwriteMethod') ) {
                    $method = $role->get_method( $method->name );
                    Carp::croak('Failed to find new overwriten method ('.$method->name.') in class ('.$role->name.')')
                        unless defined $method;
                }
            }

            # store the decorators we applied ...
            $accepted{ $method->body } = [ map $_->original, @attributes ];

            return;
        }
    );

    if ( @args ) {
        shift @args if $args[0] eq 'from';
        require decorators::from;
        decorators::from->import_into( $package, @args )
    }
}

1;

__END__

=pod

=head1 UNDER CONSTRUCTION

This module is still heavily under construction and there is a high likielihood
that the details will change, bear that in mind if you choose to use it.

=head1 DESCRIPTION

Decorators are subroutines that are run at compile time to modify the
behavior of a method. This can be something as drastic as replacing
the method body, or something as unintrusive as simply tagging the
method with metadata.

=head2 DECORATORS

A decorator is simply a callback which is associated with a given
subroutine and fired during compile time.

=head2 How are decorators registered?

Decorators are registered via a mapping of decorator providers, which
are just packages containing decorator subroutines, and the class in
which you intend to apply the decorators.

This is done by passing in the provider package name when using
the L<decorators::from> package, like so:

    package My::Class;
    use decorators;
    use decorators::from 'My::Provider';

This will make available all the decorators in F<My::Provider>
for use inside F<My::Class>.

=head2 How are decorators associated?

Decorators are associated to a subroutine using the "attribute"
feature of Perl. When the "attribute" mechanism is triggered for
a given method, we extract the name of the attribute and then
attempt to find a decorator of that name in the associated
providers.

This means that in the following code:

    package My::Class;
    use decorators::from 'My::Provider';

    sub foo : SomeTrait { ... }

We will encounter the C<foo> method and see that it has the
C<SomeTrait> "attribute". We will then look to see if there is a
C<SomeTrait> decorator available in the F<My::Provider> provider, and
if found, will call that decorator.

=head2 How are decorators called?

The decorators are called immediately when the "attribute" mechanism
is triggered. The decorator callbacks receieve at least two arguments,
the first being a L<MOP::Class> instance representing the
subroutine's package, the next being the L<MOP::Method> instance
representing the subroutine itself, and then, if there are any
arguments passed to the decorator, they are also passed along.

=head1 PERL VERSION COMPATIBILITY

For the moment I am going to require 5.14.4 because of the following quote
by Zefram in the L<Sub::WhenBodied> documentation:

  Prior to Perl 5.15.4, attribute handlers are executed before the body
  is attached, so see it in that intermediate state. (From Perl 5.15.4
  onwards, attribute handlers are executed after the body is attached.)
  It is otherwise unusual to see the subroutine in that intermediate
  state.

I am also using the C<${^GLOBAL_PHASE}> variable, which was introduced in
5.14.

It likely is possible using L<Devel::GlobalPhase> and C<Sub::WhenBodied>
to actually implment this all for pre-5.14 perls, but for now I am not
going to worry about that.

=cut

