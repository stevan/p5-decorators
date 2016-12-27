#!perl

use strict;
use warnings;

use Test::More;

BEGIN {
	use_ok('CODE::Attributes');
}

BEGIN {
	package Foo;

	use strict;
	use warnings;

	use B                      qw[ svref_2object ];
	use B::CompilerPhase::Hook qw[ enqueue_BEGIN enqueue_UNITCHECK ];
	use Data::Dumper;

	sub import {
		my $caller = caller;

		enqueue_BEGIN {
			no strict 'refs';
			@{$caller . '::ISA'} = ('Foo::HANDLER')
		};

		enqueue_UNITCHECK {
			no strict 'refs';
			@{$caller . '::ISA'} = ()
		};
	}

	sub Foo::HANDLER::MODIFY_CODE_ATTRIBUTES {
		warn join "\n" => "IN MODIFY_CODE_ATTRIBUTES", "GLOBAL_PHASE: ".${^GLOBAL_PHASE}, Dumper \@_;

		my ($class, $code, @attrs) = @_;

		warn $class;
		warn svref_2object( $code );
		my $name = svref_2object( $code )->GV->NAME;
		warn $name;

		{
			no strict 'refs';
			no warnings 'redefine';
			*{$class . '::' . $name} = sub { "HEY! " . $code->() };
		}

		();
	}
}


package Bar;

use strict;
use warnings;

# ... `use Foo`
BEGIN { Foo->import }

sub baz : GET(/) GET(/Bar) {
	"HELLO!"
}

package main;

is(Bar::baz(), 'HEY! HELLO!', '... got the expected value');

BEGIN { 
	ok(Bar->can('MODIFY_CODE_ATTRIBUTES'), '... inheritance is still in place in BEGIN');
};

ok(!Bar->can('MODIFY_CODE_ATTRIBUTES'), '... inheritance is no longer in place in RUN');


done_testing;