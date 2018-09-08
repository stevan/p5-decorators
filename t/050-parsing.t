#!perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;

=pod

This is a simple test using a single provider ...

=cut

{
    package Bar::Decorator::Provider;
    use strict;
    use warnings;

    use decorators ':for_providers';

    our $DECORATOR_USED = 0;

    sub Foo   : Decorator { $DECORATOR_USED++; return }
    sub Bar   : Decorator { $DECORATOR_USED++; return }
    sub Baz   : Decorator { $DECORATOR_USED++; return }
    sub Gorch : Decorator { $DECORATOR_USED++; return }

    package Foo;
    use strict;
    use warnings;

    use decorators 'Bar::Decorator::Provider';

    sub new { bless +{} => $_[0] }

    sub simple_list : Bar(
        'Baz',
        10 => 20,
        undef
    ) { 'FOO' }

    sub scalar          : Baz(Type) {}
    sub multi           : Baz([Type]) {}
    sub scalar_nullable : Baz(Type!) {}
    sub multi_nullable  : Baz([Type]!) {}

    sub signature : Foo(Type, [Type]? => Type[Type!]) {}
}

BEGIN {
    is($Bar::Decorator::Provider::DECORATOR_USED, 6, '...the trait was used in BEGIN');
    can_ok('Foo', 'MODIFY_CODE_ATTRIBUTES');
    can_ok('Foo', 'FETCH_CODE_ATTRIBUTES');
}

# and in runtime ...
#ok(!Foo->can('MODIFY_CODE_ATTRIBUTES'), '... the MODIFY_CODE_ATTRIBUTES has been removed');
can_ok('Foo', 'FETCH_CODE_ATTRIBUTES');

subtest '... simple_list test' => sub {

    my $method = MOP::Class->new( 'Foo' )->get_method('simple_list');
    isa_ok($method, 'MOP::Method');
    is_deeply(
        [ map $_->original, $method->get_code_attributes ],
        [
    q[Bar(
        'Baz',
        10 => 20,
        undef
    )]
        ],
        '... got the expected attributes'
    );

    my ($trait) = $method->get_code_attributes;
    isa_ok($trait, 'MOP::Method::Attribute');

    is($trait->name, 'Bar', '... got the expected trait name');
    is_deeply(
        $trait->args,
        [ 'Baz', 10, 20, undef ],
        '... got the values we expected'
    );
};

subtest '... scalar test' => sub {
    my $method = MOP::Class->new( 'Foo' )->get_method('scalar');
    isa_ok($method, 'MOP::Method');
    is_deeply(
        [ map $_->original, $method->get_code_attributes ],
        ['Baz(Type)'],
        '... got the expected attributes'
    );

    my ($trait) = $method->get_code_attributes;
    isa_ok($trait, 'MOP::Method::Attribute');

    is($trait->name, 'Baz', '... got the expected trait name');
    is_deeply($trait->args, [ 'Type' ], '... got the values we expected');
};

subtest '... scalar_nullable test' => sub {
    my $method = MOP::Class->new( 'Foo' )->get_method('scalar_nullable');
    isa_ok($method, 'MOP::Method');
    is_deeply(
        [ map $_->original, $method->get_code_attributes ],
        ['Baz(Type!)'],
        '... got the expected attributes'
    );

    my ($trait) = $method->get_code_attributes;
    isa_ok($trait, 'MOP::Method::Attribute');

    is($trait->name, 'Baz', '... got the expected trait name');
    is_deeply($trait->args, [ 'Type!' ], '... got the values we expected');
};

subtest '... multi test' => sub {
    my $method = MOP::Class->new( 'Foo' )->get_method('multi');
    isa_ok($method, 'MOP::Method');
    is_deeply(
        [ map $_->original, $method->get_code_attributes ],
        ['Baz([Type])'],
        '... got the expected attributes'
    );

    my ($trait) = $method->get_code_attributes;
    isa_ok($trait, 'MOP::Method::Attribute');

    is($trait->name, 'Baz', '... got the expected trait name');
    is_deeply($trait->args, [ '[Type]' ], '... got the values we expected');
};

subtest '... multi_nullable test' => sub {
    my $method = MOP::Class->new( 'Foo' )->get_method('multi_nullable');
    isa_ok($method, 'MOP::Method');
    is_deeply(
        [ map $_->original, $method->get_code_attributes ],
        ['Baz([Type]!)'],
        '... got the expected attributes'
    );

    my ($trait) = $method->get_code_attributes;
    isa_ok($trait, 'MOP::Method::Attribute');

    is($trait->name, 'Baz', '... got the expected trait name');
    is_deeply($trait->args, [ '[Type]!' ], '... got the values we expected');
};

subtest '... signature test' => sub {
    my $method = MOP::Class->new( 'Foo' )->get_method('signature');
    isa_ok($method, 'MOP::Method');
    is_deeply(
        [ map $_->original, $method->get_code_attributes ],
        ['Foo(Type, [Type]? => Type[Type!])'],
        '... got the expected attributes'
    );

    my ($trait) = $method->get_code_attributes;
    isa_ok($trait, 'MOP::Method::Attribute');

    is($trait->name, 'Foo', '... got the expected trait name');
    is_deeply($trait->args, [ 'Type', '[Type]?', 'Type[Type!]' ], '... got the values we expected');
};

done_testing;

