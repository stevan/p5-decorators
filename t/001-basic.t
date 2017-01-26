#!perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN {
	use_ok('Method::Annotation');
}

BEGIN {
	package JSONinator;
	use strict;
	use warnings;

	use MOP;
	use JSON::MaybeXS;
	use Data::Dumper;

	sub new {
		my ($class, $JSON) = @_;
		bless {
			JSON => $JSON // JSON::MaybeXS->new,
		} => $class;
	}

	sub collapse {
		my $self    = shift;
		my $object  = shift;
		my $klass   = MOP::Class->new( ref $object );
		my @methods = grep {
			!($_->is_required)
				&&
			$_->has_code_attributes('JSONProperty')
		} $klass->all_methods;

		my %data;
		foreach my $m ( @methods ) {
			my $name = $m->name;
			$data{ $name } = $object->$name();
		}

		return $self->{JSON}->encode( \%data );
	}

	sub expand {
		my $self    = shift;
		my $klass   = MOP::Class->new( shift );
		my $json    = $self->{JSON}->decode( shift );
		my @methods = grep {
			!($_->is_required)
				&&
			$_->has_code_attributes('JSONProperty')
		} $klass->all_methods;

		my $object = $klass->name->new;
		foreach my $m ( @methods ) {
			my $name = $m->name;
			$object->$name( $json->{ $name } );
		}

		return $object;
	}
}

BEGIN {
	package JSONinator::Annotation::Provider;
	use strict;
	use warnings;

	use Method::Annotation 'Provider';

	sub JSONProperty : Marker { () }
}

BEGIN {
	package Person;

	use strict;
	use warnings;

	use MOP;
	use UNIVERSAL::Object;

	use Method::Annotation qw[ JSONinator::Annotation::Provider ];

	our @ISA; BEGIN { @ISA = ('UNIVERSAL::Object') }
	our %HAS; BEGIN {
		%HAS = (
			first_name => sub { "" },
			last_name  => sub { "" },
		)
	}

	sub first_name : JSONProperty {
		my $self = shift;
		$self->{first_name} = shift if @_;
		$self->{first_name};
	}

	sub last_name : JSONProperty {
		my $self = shift;
		$self->{last_name} = shift if @_;
		$self->{last_name};
	}
}

my $JSON = JSONinator->new( JSON::MaybeXS->new->canonical );

my $p = Person->new( first_name => 'Bob', last_name => 'Smith' );
isa_ok($p, 'Person');

is($p->first_name, 'Bob', '... got the expected first_name');
is($p->last_name, 'Smith', '... got the expected last_name');

my $json = $JSON->collapse( $p );
is($json, q[{"first_name":"Bob","last_name":"Smith"}], '... got the JSON we expected');

my $obj = $JSON->expand( Person => $json );
isa_ok($obj, 'Person');

is($obj->first_name, 'Bob', '... got the expected first_name');
is($obj->last_name, 'Smith', '... got the expected last_name');

done_testing;

