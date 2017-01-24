package CODE::Annotation;

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use MOP                    ();
use attributes             (); # this is where we store the annotations
use B::CompilerPhase::Hook (); # multi-phase programming

## ...

our %PROVIDERS_BY_PKG; # this hold the set of available annotations per package
our %ANNOTATION_MAP;   # mapping of CODE address to Annotations

## ...

sub add_annotation_provider {
    my ($meta, $provider) = @_;
    #warn "Hey there, got $provider";
    $PROVIDERS_BY_PKG{ $meta->name } = [] unless $PROVIDERS_BY_PKG{ $meta->name };
    push @{ $PROVIDERS_BY_PKG{ $meta->name } } => $provider;
}

sub schedule_annotation_collector {
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
                return unless exists $ANNOTATION_MAP{ $code };
                return @{ $ANNOTATION_MAP{ $code } };
            }
        );
        $meta->alias_method(
            MODIFY_CODE_ATTRIBUTES => sub {
                my ($pkg, $code, @attrs) = @_;

                #use Data::Dumper;
                #warn "ATTRS: " . Dumper \@attrs;

                my $annotations = parse_annotations( $pkg, \@attrs );

                #warn "ANNOTATIONS: " . Dumper $annotations;

                my $unhandled   = find_unhandled_annotations( $pkg, $annotations );

                #warn "UNHANDLED: " . Dumper $unhandled;

                # bad annotations are bad,
                # return the originals that
                # we do not handle
                return map $_->[2], @$unhandled if @$unhandled;

                my $method = MOP::Method->new( $code );
                apply_all_annotations( $pkg, $method->name, $annotations );

                _store_annotations( $meta, $method, $annotations );

                # all is well, so let the world know that ...
                return;
            }
        );
    };
}

sub parse_annotations {
    my ($pkg, $attrs) = @_;

    # First lets parse the traits, currently
    # we are not terribly sophisticated, but
    # we accept `foo` calls (no-parens) and
    # we accept `foo(1, 2, 3)` calls (parens
    # with comma seperated args).

    # NOTE:
    # None of the args are eval-ed and they are
    # basically just a list of strings.

    return [
        map {
            #warn "Trying to parse ($_)";
            if ( m/^([a-zA-Z_]*)\((.*)\)$/ ) {
                #warn "parsed paren/args form for ($_)";
                [ $1, [ split /\,/ => $2 ], $_ ]
            }
            elsif ( m/^([a-zA-Z_]*)$/ ) {
                #warn "parsed no-parens form for ($_)";
                [ $1, [], $_ ]
            }
            else {
                die 'Unable to parse annotation (' . $_ . ')';
            }
        } @$attrs
    ];
}

sub find_unhandled_annotations {
    my ($pkg, $annotations) = @_;

    # Now loop through the annotations and look to
    # see if we have any ones we cannot handle
    # and collect them for later ...
    return [
        grep {
            my $stop;
            foreach my $provider ( @{ $PROVIDERS_BY_PKG{ $pkg } } ) {
                if ( $provider->can( $_->[0] ) ) {
                    $stop++;
                    last;
                }
            }
            not( $stop );
        } @$annotations
    ];
}

sub apply_all_annotations {
    my ($pkg, $method_name, $annotations) = @_;

    # now we need to loop through the traits
    # that we parsed and apply the annotation function
    # to our method accordingly

    foreach my $annotation ( @$annotations ) {
        my ($anno, $args) = @$annotation;
        foreach my $provider ( @{ $PROVIDERS_BY_PKG{ $pkg } } ) {
            if ( my $m = $provider->can( $anno ) ) {
                #warn "Found a provider for $anno in $provider";
                $m->( $pkg, $method_name, @$args );
                last;
            }
        }
    }
}

## private utility methods

sub _store_annotations {
    my ( $meta, $method, $annotations ) = @_;
    # next we need to fetch the latest version
    # of the method installed in the stash, or
    # if that cannot be found, use the original
    # one, and we then need to store the info
    # about the traits so it can be retrieved
    # via attributes::get

    if ( my $generated = $meta->get_method( $method->name ) || $method ) {

        #use Data::Dumper;
        #warn Dumper [ $generated->name, $annotations ];

        # NOTE:
        # we store what we were originally given
        # if we want that re-parsed, use the
        # parse function above to get that.
        # - SL
        $ANNOTATION_MAP{ $generated->body } = [ map $_->[2], @$annotations ];
    }
}


1;

__END__

=pod

=head1 DESCRIPTION

Nothing to see here

=cut
