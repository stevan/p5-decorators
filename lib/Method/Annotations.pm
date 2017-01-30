package Method::Annotations;
# ABSTRACT: Annotate your methods

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

use Method::Annotations::Annotation;

## ...

our %PROVIDERS_BY_PKG; # this hold the set of available annotations per package
our %ANNOTATION_MAP;   # mapping of CODE address to Annotations

## ...

sub import {
    shift;
    return unless @_;

    my @args = @_;
    if ( scalar(@args) == 1 && $args[0] eq ':for_providers' ) {
        # expand this to make it easier for providers
        $args[0] = 'Method::Annotations::Meta::Provider';
    }

    import_into( scalar caller, @args );
}

sub import_into {
    my ($pkg, @providers) = @_;
    my $meta = Scalar::Util::blessed( $pkg ) ? $pkg : MOP::Class->new( $pkg );
    add_annotation_providers( $meta, @providers );
    schedule_annotation_collector( $meta )
}

## ...

sub add_annotation_providers {
    my ($meta, @providers) = @_;

    # It does not make any sense to create
    # something that is meant to run in the
    # BEGIN phase *after* that phase is done
    # so catch this and error ...
    die 'Annotation collection must be scheduled during BEGIN time, not (' . ${^GLOBAL_PHASE}. ')'
        unless ${^GLOBAL_PHASE} eq 'START';

    Module::Runtime::use_package_optimistically( $_ )
        foreach @providers;

    $PROVIDERS_BY_PKG{ $meta->name } = []
        unless $PROVIDERS_BY_PKG{ $meta->name };

    push @{ $PROVIDERS_BY_PKG{ $meta->name } } => @providers;
}

sub get_annotation_providers {
    my ($meta) = @_;
    return @{ $PROVIDERS_BY_PKG{ $meta->name } };
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
                # return just the strings, as expected by attributes ...
                return map $_->original, @{ $ANNOTATION_MAP{ $code } };
            }
        );
        $meta->alias_method(
            MODIFY_CODE_ATTRIBUTES => sub {
                my ($pkg, $code, @attrs) = @_;

                my $annotations = parse_annotations( @attrs );
                my $unhandled   = find_unhandled_annotations( $pkg, $annotations );

                #use Data::Dumper;
                #warn "WE ARE IN $pkg for $code with " . join ', ' => @attrs;
                #warn "ATTRS: " . Dumper \@attrs;
                #warn "ANNOTATIONS: " . Dumper $annotations;
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
                my $method = apply_all_annotations(
                    MOP::Class->new( $pkg ),
                    MOP::Method->new( $code ),
                    $annotations
                );

                # store the annotations we applied ...
                $ANNOTATION_MAP{ $method->body } = $annotations;

                # all is well, so let the world know that ...
                return;
            }
        );
    };
}

sub parse_annotations {
    my @attrs = @_;

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
                Method::Annotations::Annotation->new(
                    original => "$_",
                    name     => $1,
                    args     => [
                        map {
                            my $arg = $_;
                            $arg =~ s/^\'//;
                            $arg =~ s/\'$//;
                            $arg;
                        } split /\,\s?/ => $2
                    ]
                );
            }
            elsif ( m/^([a-zA-Z_]*)$/ ) {
                #warn "parsed no-parens form for ($_)";
                Method::Annotations::Annotation->new(
                    original => "$_",
                    name     => $1,
                );
            }
            else {
                die 'Unable to parse annotation (' . $_ . ')';
            }
        } @attrs
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
                #warn "PROVIDER: $provider looking for: " . $_->[0];
                if ( my $anno = $provider->can( $_->name ) ) {
                    $_->handler( MOP::Method->new( $anno ) );
                    $stop++;
                    last;
                }
            }
            not( $stop );
        } @$annotations
    ];
}

sub apply_all_annotations {
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
