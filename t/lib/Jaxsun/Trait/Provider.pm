package # hide from PAUSE
    Jaxsun::Trait::Provider;
use strict;
use warnings;

use decorators;
use decorators::from ':for_providers';

sub JSONProperty : TagMethod { () }

1;
