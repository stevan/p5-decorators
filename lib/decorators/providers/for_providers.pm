package decorators::providers::for_providers;
# ABSTRACT: Decorators for Decorator Providers

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub CreateMethod { () }
sub WrapMethod   { () }
sub TagMethod    { () }

1;

__END__

=pod

=head1 DESCRIPTION

This is a decorator provider which contains some useful decorators
for people who are writing decorator providers.

=head1 TRAITS

=head2 CreateMethod

This means that the decorator handler will create the method exclusivily.
This means the method must be a bodyless method and in a given set of
decorators, there can only be one C<CreateMethod> decorator and it will
be executed first.

=head2 WrapMethod

This means that the decorator handle will override, or wrap, the method.
This means the method must exist already.

=head2 TagMethod

This means that the decorator is really just a tag added to the method.
These typically will be processed at runtime through introspection, so
can simply be no-op subroutines. As with C<WrapMethod> this means the
method must exist already.

=cut
