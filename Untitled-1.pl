package My::Class::Foo;

use v5.24;
use warnings;

use experimental qw[ signatures postderef ];
use decorators   qw[ :accessors :constructors ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use parent 'Base::Foo';
use roles 'Role::Bar::Baz';
use slots (
    test0  => sub { 0 },
    test1  => sub { 1 },
    _test2 => sub { 2 },
);

# CONSTRUCTOR

sub BUILDARGS : strict(
    test_zero => test0,  # required parameter with a rename to internal name
    test_one? => test1,  # optional parameter with a rename to internal name
    test_two? => _test2, # optional parameter with a rename to internal name
);

sub BUILDARGS : positional(
    test0,  # value here will be used for 'test0'
    test1,  # value here will be used for 'test1'
    _test2, # value here will be used for '_test2'
);

# ACCESSORS

sub test0     : ro;        # infer the 'test0' name
sub get_test0 : ro;        # infer the 'test0' name ignoring the 'get_'
sub test_zero : ro(test0); # specify the 'test0' name explcitly

sub test1     : rw;        # infer the 'test1' name explcitly
sub rw_test1  : rw(test1); # specity the 'test1' name explcitly
sub set_test1 : wo;        # infer the 'test1' name ignoring the 'set_'

sub _test2    : ro;        # infer the '_test2' name
sub test2     : rw(_);     # infer the private version of the name (prefix with '_')
sub set_test2 : wo(_);     # infer the private version of the name (prefix with '_') ignoring the 'set_'
sub get_test2 : ro(_);     # infer the private version of the name (prefix with '_') ignoring the 'get_'

1;

__END__















