#!perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN {
    use_ok('MOP');
}

=pod

This test

=cut

{
    package Bar::Annotation::Provider;
    use strict;
    use warnings;

    our $ANNOTATION_USED = 0;

    sub Bar { $ANNOTATION_USED++; return }

    package Baz::Annotation::Provider;
    use strict;
    use warnings;

    our $ANNOTATION_USED = 0;

    sub Baz { $ANNOTATION_USED++; return }

    package Foo;
    use strict;
    use warnings;

    use Method::Annotation 'Bar::Annotation::Provider';
    use Method::Annotation 'Baz::Annotation::Provider';

    sub new { bless +{} => $_[0] }

    sub foo : Bar { 'FOO' }
    sub bar : Baz { 'BAR' }
}

BEGIN {
    is($Bar::Annotation::Provider::ANNOTATION_USED, 1, '...the annotation was used in BEGIN');
    is($Baz::Annotation::Provider::ANNOTATION_USED, 1, '...the annotation was used in BEGIN');
}

{
    my $foo = Foo->new;
    isa_ok($foo, 'Foo');

    can_ok($foo, 'foo');
    can_ok($foo, 'bar');

    is($foo->foo, 'FOO', '... the method worked as expected');
    is($foo->bar, 'BAR', '... the method worked as expected');
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

{
    my $method = MOP::Class->new( 'Foo' )->get_method('bar');
    isa_ok($method, 'MOP::Method');
    is_deeply(
        [ $method->get_code_attributes ],
        [qw[ Baz ]],
        '... got the expected attributes'
    );
}

done_testing;

