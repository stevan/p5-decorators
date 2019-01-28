#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Data::Dumper;

=pod

This test

=cut

{
    package Foo::WithFoo;
    use strict;
    use warnings;

    use decorators ':constructor';

    use parent 'UNIVERSAL::Object';

    our %HAS; BEGIN { %HAS = ( foo => sub { 'foo' } ) }

    sub BUILD : assert( foo => Str );    

    # sub BUILD : assert(
    #     operation            => where { Graph::QL::Core::OperationKind->is_operation_kind( $_ ) },
    #     name                 => InstanceOf[Graph::QL::AST::Node::Name] where { exists $params->{name} },
    #     variable_definitions => ArrayRef[InstanceOf[Graph::QL::AST::Node::VariableDefinition]],
    #     directives           => ArrayRef[InstanceOf[Graph::QL::AST::Node::Directive]],
    #     selection_set        => InstanceOf[Graph::QL::AST::Node::SelectionSet],
    # );
}


subtest '... Foo( foo ) is a Str' => sub {
    {
        my $foo;
        is(exception { $foo = Foo::WithFoo->new( foo => 'BAR' ) }, undef, '... no exception');
        isa_ok($foo, 'Foo::WithFoo');

        is($foo->{foo}, 'BAR', '... got the expected slot');
    }

};

done_testing;

