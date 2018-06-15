package decorators::providers::for_providers;
# ABSTRACT: Decorators for Decorator Providers

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub OverwriteMethod { () }
sub TagMethod       { () }

1;

__END__

=pod

=head1 DESCRIPTION

This is a decorator provider which contains some useful decorators
for people who are writing decorator providers.

=head1 TRAITS

=head2 OverwriteMethod

This means that the decorator handler will overwrite the method with
another copy. This means we need to re-fetch the method before we run
additional decorator handlers.

=head2 TagMethod

This means that the decorator is really just a tag added to the method.
These typically will be processed at runtime through introspection, so
can simply be no-op subroutines.

=cut
