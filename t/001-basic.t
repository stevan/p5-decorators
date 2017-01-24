#!perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN {
	use_ok('CODE::Annotation');
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

	sub JSONProperty { () }
}

BEGIN {
	package Person;

	use strict;
	use warnings;

	use MOP;
	use UNIVERSAL::Object;

	BEGIN {
		my $meta = MOP::Class->new(__PACKAGE__);
		CODE::Annotation::add_annotation_provider( $meta, 'JSONinator::Annotation::Provider' );
		CODE::Annotation::schedule_annotation_collector( $meta )
	}

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

my $JSON = JSONinator->new( JSON::MaybeXS->new->pretty->canonical );

my $p = Person->new( first_name => 'Bob', last_name => 'Smith' );
warn Dumper $p;

my $json = $JSON->collapse( $p );
warn $json;

my $obj = $JSON->expand( Person => $json );
warn Dumper $obj;

done_testing;

