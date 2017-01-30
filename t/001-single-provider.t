#!perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN {
    use_ok('MOP');
}

=pod

This is a simple test using a single provider ...

=cut

{
    package Bar::Annotation::Provider;
    use strict;
    use warnings;

    our $ANNOTATION_USED = 0;

    sub Bar { $ANNOTATION_USED++; return }

    package Foo;
    use strict;
    use warnings;

    use Method::Annotation 'Bar::Annotation::Provider';

    sub new { bless +{} => $_[0] }

    sub foo : Bar { 'FOO' }
}

BEGIN {
    is($Bar::Annotation::Provider::ANNOTATION_USED, 1, '...the annotation was used in BEGIN');
}

{
    my $foo = Foo->new;
    isa_ok($foo, 'Foo');

    can_ok($foo, 'foo');

    is($foo->foo, 'FOO', '... the method worked as expected');
}

{
    my $method = MOP::Class->new( 'Foo' )->get_method('foo');
    isa_ok($method, 'MOP::Method');
    is_deeply(
        [ $method->get_code_attributes ],
        [qw[ Bar ]],
        '... got the expected attributes'
    );
}

done_testing;

