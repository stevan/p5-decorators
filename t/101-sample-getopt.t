#!perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN {
    use_ok('Method::Annotation');
}

=pod


=cut

BEGIN {
    package Getopt::Handler;
    use strict;
    use warnings;

    use Scalar::Util ();
    use Getopt::Long ();

    our %OPTS_BY_PACKAGE;

    sub set_opt_spec_for_slot {
        my ($class, $spec, $slot_name) = @_;
        my $opts = $OPTS_BY_PACKAGE{ $class } ||= {};
        $opts->{ $spec } = $slot_name;
    }

    sub get_opt_spec {
        my ($class) = @_;
        return $OPTS_BY_PACKAGE{ $class } ||= {};
    }

    sub get_options {
        my ($class) = @_;

        my $spec = get_opt_spec( $class );
        die 'Unable to find an option spec for class('.$class.')'
            unless $spec;

        my %opts = map { $_ => \(my $x) } keys %$spec;
        Getopt::Long::GetOptions( %opts );

        #use Data::Dumper;
        #warn Dumper $spec;
        #warn Dumper \%opts;

        return map {
            $spec->{ $_ },           # the spec key maps to the slot_name
            ${$opts{ $_ }}           # de-ref the scalar from Getopt::Long
        } grep defined ${$opts{$_}}, keys %opts;
    }

    package Getopt::Provider;
    use strict;
    use warnings;

    sub Opt {
        my ($meta, $method_name, $spec) = @_;

        # the spec defaults to the method-name
        $spec ||= $method_name;

        # split by | and assume last item will be slot name
        my $slot_name = (split /\|/ => $spec)[-1];
        # strip off any getopt::long type info as well
        $slot_name =~ s/\=\w$//;

        my $slot = $meta->get_slot( $slot_name )
                || $meta->get_slot_alias( $slot_name );

        die 'Cannot find slot ('.$slot_name.') for Opt('.$spec.') on `' . $method_name . '`'
            unless $slot;

        Getopt::Handler::set_opt_spec_for_slot(
            $meta->name,
            $spec,
            $slot->name
        );
    }
}

BEGIN {
    package MyApp;

    use strict;
    use warnings;

    use Method::Annotation qw[ Getopt::Provider ];

    our @ISA; BEGIN { @ISA = ('UNIVERSAL::Object') }
    our %HAS; BEGIN {
        %HAS = (
            name    => sub { __PACKAGE__ },
            verbose => sub { 0 },
            debug   => sub { 0 },
        )
    }

    sub app_name   : Opt('name=s')    { $_[0]->{name}    }
    sub is_verbose : Opt('v|verbose') { $_[0]->{verbose} }
    sub is_debug   : Opt('d|debug')   { $_[0]->{debug}   }

    sub new_from_options {
        my $class = shift;
        my %args  = Getopt::Handler::get_options( $class );

        #use Data::Dumper;
        #warn Dumper \%args;

        return $class->new( %args, @_ );
    }

}

{
    @ARGV = ();

    my $app = MyApp->new_from_options;
    isa_ok($app, 'MyApp');

    #use Data::Dumper;
    #warn Dumper $app;

    ok(!$app->is_verbose, '... got the right setting for verbose');
    ok(!$app->is_debug, '... got the right setting for debug');

    is($app->app_name, 'MyApp', '... got the expected app-name');
}

{
    @ARGV = ('--verbose', '--name', 'FooBarBaz');

    my $app = MyApp->new_from_options;
    isa_ok($app, 'MyApp');

    #use Data::Dumper;
    #warn Dumper $app;

    ok($app->is_verbose, '... got the right setting for verbose');
    ok(!$app->is_debug, '... got the right setting for debug');

    is($app->app_name, 'FooBarBaz', '... got the expected app-name');
}

{
    @ARGV = ('--verbose', '-d');

    my $app = MyApp->new_from_options;
    isa_ok($app, 'MyApp');

    #use Data::Dumper;
    #warn Dumper $app;

    ok($app->is_verbose, '... got the right setting for verbose');
    ok($app->is_debug, '... got the right setting for debug');

    is($app->app_name, 'MyApp', '... got the expected app-name');
}



done_testing;

