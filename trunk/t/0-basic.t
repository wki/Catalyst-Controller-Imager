use Test::More tests => 19;
use Test::Exception;
use Catalyst ();
use FindBin;
use Path::Class::File;
use Imager;

# setup our Catalyst :-)
my $c = Catalyst->new();
$c->setup_log();
$c->setup_home("$FindBin::Bin");
# warn "home = $FindBin::Bin"; exit;

#
# check available imager formats
#
ok(scalar(keys(%Imager::formats)) > 0, 'Imager.pm tells some formats');
ok(exists($Imager::formats{png}),  'png format is possible');
ok(exists($Imager::formats{gif}),  'gif format is possible');
ok(exists($Imager::formats{jpeg}), 'jpeg format is possible');

BAIL_OUT('Imager.pm not configured as expected - please reinstall with gif, jpeg and png support!')
    if (!exists($Imager::formats{png}) || 
        !exists($Imager::formats{gif}) ||
        !exists($Imager::formats{jpeg}) );

#
# test start
#
# can we use it?
use_ok('Catalyst::Controller::Imager');
can_ok('Catalyst::Controller::Imager' => qw(generate_image));

# instantiate
my $controller;
lives_ok { $controller = Catalyst->setup_component('Catalyst::Controller::Imager') }
         'setup component worked';

is(ref($controller), 'Catalyst::Controller::Imager', 'controller class looks good');

# check default attributes
# checking default attributes
is($controller->root_dir, 'static/images', 'default root directory looks good');
is($controller->cache_dir, undef, 'default cache directory looks good');
is($controller->default_format, 'jpg', 'default format sub looks good');
is($controller->max_size, 1000, 'default max size looks good');

# try to load catalyst logo
# original size = 171 x 244 pix
# original format = png

lives_ok { $controller->generate_image($c, 'catalyst_logo.png') }
         'original file retrieval lives';
ok(length($c->response->body) > 10000, 'size is reasonable');
is($c->response->headers->content_type, 'image/png', 'MIME type looks OK');


dies_ok { $controller->generate_image($c, 'rails_logo.png') }
         'unknown file retrieval dies';


lives_ok { $controller->generate_image($c, 'catalyst_logo.png.jpg') }
         'converted file retrieval lives';
ok(length($c->response->body) > 1000, 'size is reasonable');
is($c->response->headers->content_type, 'image/jpeg', 'MIME type looks OK');

