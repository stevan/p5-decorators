package # hide from PAUSE
    Getopt::Provider;
use strict;
use warnings;

use Getopt::Handler;

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

1;
