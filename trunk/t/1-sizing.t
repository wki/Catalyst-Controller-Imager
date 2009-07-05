use Test::More tests => 41;
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

### FIXME: clear cache directory, ensure cache keeps empty

# use catalyst logo
# original size = 171 x 244 pix
# original format = png

# invalid option that will get ignored
lives_ok { $controller->generate_image($c, 'x-200', 'catalyst_logo.png') }
         'useless option image generation lives';
ok(length($c->response->body) > 10000, 'size is reasonable');
is($c->response->headers->content_type, 'image/png', 'MIME type looks OK');
file_type_is('PNG');
file_dimension_is(171,244);



# scale to a different width below 1000 (height will get increased by same factor)
lives_ok { $controller->generate_image($c, 'w-200', 'catalyst_logo.png') }
         'useless option image generation lives';
ok(length($c->response->body) > 10000, 'size is reasonable');
is($c->response->headers->content_type, 'image/png', 'MIME type looks OK');
file_type_is('PNG');
file_dimension_is(200,285);

# scale to a different width above 1000 (will be ignored)
lives_ok { $controller->generate_image($c, 'w-2000', 'catalyst_logo.png') }
         'useless option image generation lives';
ok(length($c->response->body) > 10000, 'size is reasonable');
is($c->response->headers->content_type, 'image/png', 'MIME type looks OK');
file_type_is('PNG');
file_dimension_is(171,244);



# scale to a different height below 1000 (width will get increased by same factor)
lives_ok { $controller->generate_image($c, 'h-200', 'catalyst_logo.png') }
         'useless option image generation lives';
ok(length($c->response->body) > 10000, 'size is reasonable');
is($c->response->headers->content_type, 'image/png', 'MIME type looks OK');
file_type_is('PNG');
file_dimension_is(140,200);

# scale to a different height above 1000 (will be ignored)
lives_ok { $controller->generate_image($c, 'h-2000', 'catalyst_logo.png') }
         'useless option image generation lives';
ok(length($c->response->body) > 10000, 'size is reasonable');
is($c->response->headers->content_type, 'image/png', 'MIME type looks OK');
file_type_is('PNG');
file_dimension_is(171,244);



# scale w+h simultanously (w is too high, h will win...)
lives_ok { $controller->generate_image($c, 'w-400','h-150', 'catalyst_logo.png') }
         'useless option image generation lives';
ok(length($c->response->body) > 10000, 'size is reasonable');
is($c->response->headers->content_type, 'image/png', 'MIME type looks OK');
file_type_is('PNG');
file_dimension_is(105,150);

# different order should not hurt
lives_ok { $controller->generate_image($c, 'h-150','w-400', 'catalyst_logo.png') }
         'useless option image generation lives';
ok(length($c->response->body) > 10000, 'size is reasonable');
is($c->response->headers->content_type, 'image/png', 'MIME type looks OK');
file_type_is('PNG');
file_dimension_is(105,150);

# repeating a parameter makes the last occurence win
lives_ok { $controller->generate_image($c, 'w-100','h-150','w-400', 'catalyst_logo.png') }
         'useless option image generation lives';
ok(length($c->response->body) > 10000, 'size is reasonable');
is($c->response->headers->content_type, 'image/png', 'MIME type looks OK');
file_type_is('PNG');
file_dimension_is(105,150);

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
