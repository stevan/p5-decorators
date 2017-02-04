package Method::Traits;
# ABSTRACT: Apply traits your methods

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Scalar::Util           ();
use MOP                    ();
use attributes             (); # this is where we store the traits
use B::CompilerPhase::Hook (); # multi-phase programming
use Module::Runtime        (); # trait provider loading

## ...

use Method::Traits::Trait;
use Method::Traits::Meta::Provider;

## --------------------------------------------------------
## Importers
## --------------------------------------------------------

sub import {
    shift;
    return unless @_;

    my @args = @_;
    if ( scalar(@args) == 1 && $args[0] eq ':for_providers' ) {
        # expand this to make it easier for providers
        $args[0] = 'Method::Traits::Meta::Provider';
    }

    import_into( scalar caller, @args );
}

sub import_into {
    my ($pkg, @providers) = @_;
    my $meta = Scalar::Util::blessed( $pkg ) ? $pkg : MOP::Class->new( $pkg );
    schedule_trait_collection( $meta, @providers );
}

## --------------------------------------------------------
## Storage
## --------------------------------------------------------

our %PROVIDERS_BY_PKG; # this hold the set of available traits per package
our %TRAIT_BY_CODE;    # mapping of CODE address to Trait

## Per-Package Provider Management

sub add_trait_providers {
    my ($meta, @providers) = @_;
    Module::Runtime::use_package_optimistically( $_ ) foreach @providers;
    push @{ $PROVIDERS_BY_PKG{ $meta->name } ||=[] } => @providers;
}

sub get_trait_providers {
    my ($meta) = @_;
    return @{ $PROVIDERS_BY_PKG{ $meta->name } ||=[] };
}

## Per-CODE Trait Management

sub add_traits_for {
    my ($method, @traits) = @_;
    push @{ $TRAIT_BY_CODE{ $method->body } ||=[] } => @traits;
}

sub get_traits_for {
    my ($method) = @_;
    return @{ $TRAIT_BY_CODE{ $method->body } ||=[] };
}

## --------------------------------------------------------
## Trait collection
## --------------------------------------------------------

sub schedule_trait_collection {
    my ($meta, @providers) = @_;

    # It does not make any sense to create
    # something that is meant to run in the
    # BEGIN phase *after* that phase is done
    # so catch this and error ...
    die 'Trait collection must be scheduled during BEGIN time, not (' . ${^GLOBAL_PHASE}. ')'
        unless ${^GLOBAL_PHASE} eq 'START';

    # add in the providers, so we can
    # get to them in other BEGIN blocks
    add_trait_providers( $meta, @providers );

    # no need to install the collectors
    # if they have already been installed
    # as they are not different
    return
        if $meta->has_method_alias('FETCH_CODE_ATTRIBUTES')
        && $meta->has_method_alias('MODIFY_CODE_ATTRIBUTES');

    # now install the collectors ...
    $meta->alias_method(
        FETCH_CODE_ATTRIBUTES => sub {
            my ($pkg, $code) = @_;
            # return just the strings, as expected by attributes ...
            return map $_->original, get_traits_for( MOP::Method->new( $code ) );
        }
    );
    $meta->alias_method(
        MODIFY_CODE_ATTRIBUTES => sub {
            my ($pkg, $code, @attrs) = @_;

            my $klass  = MOP::Class->new( $pkg );
            my $method = MOP::Method->new( $code );

            my @traits    = map Method::Traits::Trait->new( $_ ), @attrs;
            my @unhandled = find_unhandled_traits( $klass, @traits );

            #use Data::Dumper;
            #warn "WE ARE IN $pkg for $code with " . join ', ' => @attrs;
            #warn "ATTRS: " . Dumper \@attrs;
            #warn "TRAITS: " . Dumper \@traits;
            #warn "UNHANDLED: " . Dumper $unhandled;

            # bad traits are bad,
            # return the originals that
            # we do not handle
            return map $_->original, @unhandled if @unhandled;

            # NOTE:
            # ponder the idea of moving this
            # call to UNITCHECK phase, not sure
            # if that actually makes sense or not
            # so it will need to be explored.
            # - SL
            $method = apply_all_trait_handlers( $klass, $method, \@traits );

            # store the traits we applied ...
            add_traits_for( $method, @traits );

            # all is well, so let the world know that ...
            return;
        }
    );

    B::CompilerPhase::Hook::enqueue_CHECK {
        #warn "STEP 2";
        $meta->delete_method_alias('MODIFY_CODE_ATTRIBUTES');
    };
}

sub find_unhandled_traits {
    my ($meta, @traits) = @_;

    # Now loop through the traits and look to
    # see if we have any ones we cannot handle
    # and collect them for later ...
    return grep {
        my $stop;
        foreach my $provider ( get_trait_providers( $meta ) ) {
            #warn "PROVIDER: $provider looking for: " . $_->[0];
            if ( my $anno = $provider->can( $_->name ) ) {
                $_->handler( MOP::Method->new( $anno ) );
                $stop++;
                last;
            }
        }
        not( $stop );
    } @traits;
}

sub apply_all_trait_handlers {
    my ($meta, $method, $traits) = @_;

    # now we need to loop through the traits
    # that we parsed and apply the trait function
    # to our method accordingly

    my $method_name = $method->name;

    foreach my $trait ( @$traits ) {
        my ($args, $anno) = ($trait->args, $trait->handler);
        $anno->body->( $meta, $method_name, @$args );
        if ( $anno->has_code_attributes('OverwritesMethod') ) {
            $method = $meta->get_method( $method_name );
            die 'Failed to find new overwriten method ('.$method_name.') in class ('.$meta->name.')'
                unless defined $method;
        }
    }

    return $method;
}

1;

__END__

=pod

=head1 DESCRIPTION

Traits are subroutines that are run at compile time to modify the
behavior of a method. This can be something as drastic as replacing
the method body, or something as unintrusive as simply tagging the
method with metadata.

=cut
