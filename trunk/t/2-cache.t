use Test::More 'no_plan'; #tests => 28;
use Test::Exception;
use Catalyst ();
use Catalyst::Controller::Imager;
use FindBin;
use Path::Class::File;
use Imager;
use Image::Info qw(image_info image_type dim);

# setup our Catalyst :-)
my $c = Catalyst->new();
$c->setup_log();
$c->setup_home("$FindBin::Bin");

my $controller;
lives_ok { $controller = Catalyst->setup_component('Catalyst::Controller::Imager') }
         'setup component worked';

### more things to come.

# clear cache, convert an image
# --> cache-dir still must be empty

# enable caching, convert an image
# --> image must be in cache
# --> cache-file must be newer and exactly identical with delivered one

# caching still enabled, set back original image-timestamp, convert image
# --> image must still be in cache
# --> image must come from cache and be identical with cache

# caching still enabled, set cache image-timestamp past original, convert image
# --> image must still be in cache
# --> image must get converted and get updated into cache

