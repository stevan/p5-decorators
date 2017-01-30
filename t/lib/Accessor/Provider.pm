package # hide from PAUSE ...
    Accessor::Provider;
use strict;
use warnings;

use Method::Annotations ':for_providers';

sub Accessor : OverwritesMethod {
    my ($meta, $method_name, $type, $slot_name) = @_;

    $meta->add_method( $method_name => sub {
        die 'ro accessor' if $_[1];
        $_[0]->{$slot_name};
    })
        if $type eq 'ro';

    $meta->add_method( $method_name => sub {
        $_[0]->{$slot_name} = $_[1] if $_[1];
        $_[0]->{$slot_name};
    })
        if $type eq 'rw';
}

1;

