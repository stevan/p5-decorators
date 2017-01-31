package Method::Traits;
# ABSTRACT: Apply traits your methods

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Scalar::Util           ();
use MOP                    ();
use attributes             (); # this is where we store the annotations
use B::CompilerPhase::Hook (); # multi-phase programming
use Module::Runtime        (); # annotation provider loading

## ...

use Method::Traits::Trait;

## ...

our %PROVIDERS_BY_PKG; # this hold the set of available annotations per package
our %TRAIT_BY_CODE;    # mapping of CODE address to Trait

## ...

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
    add_trait_providers( $meta, @providers );
    schedule_trait_collection( $meta )
}

## ...

sub add_trait_providers {
    my ($meta, @providers) = @_;

    # It does not make any sense to create
    # something that is meant to run in the
    # BEGIN phase *after* that phase is done
    # so catch this and error ...
    die 'Annotation collection must be scheduled during BEGIN time, not (' . ${^GLOBAL_PHASE}. ')'
        unless ${^GLOBAL_PHASE} eq 'START';

    Module::Runtime::use_package_optimistically( $_ )
        foreach @providers;

    push @{ $PROVIDERS_BY_PKG{ $meta->name } ||= [] } => @providers;
}

sub get_trait_providers {
    my ($meta) = @_;
    return @{ $PROVIDERS_BY_PKG{ $meta->name } };
}

sub schedule_trait_collection {
    my ($meta) = @_;

    # It does not make any sense to create
    # something that is meant to run in the
    # BEGIN phase *after* that phase is done
    # so catch this and error ...
    die 'Annotation collection must be scheduled during BEGIN time, not (' . ${^GLOBAL_PHASE}. ')'
        unless ${^GLOBAL_PHASE} eq 'START';

    # This next step, we want to do
    # immediately after this method
    # (and the BEGIN block it is
    # contained within) finishes.

    # Since these are BEGIN blocks,
    # they need to be enqueued in
    # the reverse order they will
    # run in order to have the method
    # not trip up role composiiton
    B::CompilerPhase::Hook::enqueue_BEGIN {
        #warn "IN FIRST BEGIN BLOCK";

        # we remove the modifier, but leave
        # the fetcher because that is how
        # attributes::get will find this info
        $meta->delete_method_alias('MODIFY_CODE_ATTRIBUTES')
    };
    B::CompilerPhase::Hook::enqueue_BEGIN {
        #warn "IN SECOND BEGIN BLOCK";
        $meta->alias_method(
            FETCH_CODE_ATTRIBUTES => sub {
                my ($pkg, $code) = @_;
                return unless exists $TRAIT_BY_CODE{ $code };
                # return just the strings, as expected by attributes ...
                return map $_->original, @{ $TRAIT_BY_CODE{ $code } };
            }
        );
        $meta->alias_method(
            MODIFY_CODE_ATTRIBUTES => sub {
                my ($pkg, $code, @attrs) = @_;

                my @traits    = map Method::Traits::Trait->new( $_ ), @attrs;
                my $unhandled = find_unhandled_traits( $pkg, \@traits );

                #use Data::Dumper;
                #warn "WE ARE IN $pkg for $code with " . join ', ' => @attrs;
                #warn "ATTRS: " . Dumper \@attrs;
                #warn "ANNOTATIONS: " . Dumper $traits;
                #warn "UNHANDLED: " . Dumper $unhandled;

                # bad annotations are bad,
                # return the originals that
                # we do not handle
                return map $_->original, @$unhandled if @$unhandled;

                # NOTE:
                # ponder the idea of moving this
                # call to UNITCHECK phase, not sure
                # if that actually makes sense or not
                # so it will need to be explored.
                # - SL
                my $method = apply_all_trait_handlers(
                    MOP::Class->new( $pkg ),
                    MOP::Method->new( $code ),
                    \@traits
                );

                # store the annotations we applied ...
                $TRAIT_BY_CODE{ $method->body } = \@traits;

                # all is well, so let the world know that ...
                return;
            }
        );
    };
}

sub find_unhandled_traits {
    my ($pkg, $traits) = @_;

    # Now loop through the annotations and look to
    # see if we have any ones we cannot handle
    # and collect them for later ...
    return [
        grep {
            my $stop;
            foreach my $provider ( @{ $PROVIDERS_BY_PKG{ $pkg } } ) {
                #warn "PROVIDER: $provider looking for: " . $_->[0];
                if ( my $anno = $provider->can( $_->name ) ) {
                    $_->handler( MOP::Method->new( $anno ) );
                    $stop++;
                    last;
                }
            }
            not( $stop );
        } @$traits
    ];
}

sub apply_all_trait_handlers {
    my ($meta, $method, $annotations) = @_;

    # now we need to loop through the traits
    # that we parsed and apply the annotation function
    # to our method accordingly

    my $method_name = $method->name;

    foreach my $annotation ( @$annotations ) {
        my ($args, $anno) = ($annotation->args, $annotation->handler);
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

Nothing to see here

=cut
