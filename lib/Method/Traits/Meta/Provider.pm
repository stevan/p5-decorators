package Method::Traits::Meta::Provider;
# ABSTRACT: Traits for Trait Providers

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub OverwritesMethod { () }

1;

__END__

=pod

=head1 DESCRIPTION

This is a trait provider which contains some useful traits
for people who are writing trait providers.

=head1 TRAITS

=head2 OverwritesMethod

This means that the trait handler will overwrite the
method with another copy. This means we need to re-fetch
the method before we run additional trait handlers.

=cut
