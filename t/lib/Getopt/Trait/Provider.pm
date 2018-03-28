package # hide from PAUSE
    Getopt::Trait::Provider;
use strict;
use warnings;

use decorators;
use decorators::from ':for_providers';

sub Opt : TagMethod { () }

1;
