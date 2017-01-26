package Method::Annotation::Meta::Provider;
# ABSTRACT: Annotations for Annotations

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub OverwritesMethod { () }

1;

__END__

=pod

=head1 Annotations

=head2 OverwritesMethod

This means that the annotation handler will overwrite the
method with another copy. This means we need to re-fetch
the method before we run additional annotations.

=cut
