package Method::Annotation::Meta::Provider;

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub Destructive { () }
sub Marker      { () }

1;

__END__

=pod

=head1 Annotations

=head2 Destructive

This means that the annotation handler has done something to the
method itself, exactly what is not relevant, only that it changed
something. This could be anything from replacing the underlying
method itself with a new one, or just simply performing some kind
of side-effectual action.

=head2 Marker

This means that the annotation handler will not do anything to the
method, instead this is mean to be a metadata marker that can
be read back at a later time.

=cut
