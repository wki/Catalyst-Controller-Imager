use Test::More tests => 28;
use Test::Exception;
use Catalyst ();
use FindBin;
use Path::Class::File;
use Imager;
use Image::Info qw(image_info image_type dim);

# setup our Catalyst :-)
my $c = Catalyst->new();
$c->setup_log();
$c->setup_home("$FindBin::Bin");

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

### FIXME: clear cache directory, ensure cache keeps empty

# try to load catalyst logo
# original size = 171 x 244 pix
# original format = png

lives_ok { $controller->generate_image($c, 'catalyst_logo.png') }
         'original file retrieval lives';
ok(length($c->response->body) > 10000, 'size is reasonable');
is($c->response->headers->content_type, 'image/png', 'MIME type looks OK');
file_type_is('PNG');
file_dimension_is(171,244);

dies_ok { $controller->generate_image($c, 'rails_logo.png') }
         'unknown file retrieval dies';

# convert to jpg - same size
lives_ok { $controller->generate_image($c, 'catalyst_logo.png.jpg') }
         'converted file retrieval lives';
ok(length($c->response->body) > 1000, 'size is reasonable');
is($c->response->headers->content_type, 'image/jpeg', 'MIME type looks OK');
file_type_is('JPEG');
file_dimension_is(171,244);

# convert to gif - same size
lives_ok { $controller->generate_image($c, 'catalyst_logo.png.gif') }
         'converted file retrieval lives';
ok(length($c->response->body) > 10000, 'size is reasonable');
is($c->response->headers->content_type, 'image/gif', 'MIME type looks OK');
file_type_is('GIF');
file_dimension_is(171,244);


#
# helper subs
#
sub file_type_is {
    my $format = shift;
    my $msg = shift || "file type is '$format'";
    
    my $image_type = image_type(\do{ $c->response->body });
    ok(ref($image_type) eq 'HASH' &&
       exists($image_type->{file_type}) &&
       $image_type->{file_type} eq $format, $msg);
}

sub file_dimension_is {
    my $w = shift;
    my $h = shift;
    my $msg = shift || "dimension is $w x $h pixels";

    is_deeply([dim(image_info(\do { $c->response->body }))], [$w, $h], $msg);
}
