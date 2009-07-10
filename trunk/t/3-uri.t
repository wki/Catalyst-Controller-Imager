use Test::More 'no_plan';
use Test::Exception;
use Image::Info qw(image_info image_type dim);
use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestApp';

#
# sanity check -- controller there?
#
my $controller = TestApp->controller('Image');
is(ref($controller), 'TestApp::Controller::Image', 'Controller is OK');

#
# get a context object
#
my ($res, $c) = ctx_request('/image/thumbnail/catalyst_logo.png');
is( ref($c), 'TestApp', 'context is OK' );

#
# fire some requests
#
my $content;
lives_ok { $content = get('/image/thumbnail/catalyst_logo.png'); }
         'retrieval works';
#die $content;
ok(length($content) > 1000, 'length is OK');
file_type_is('catalyst_logo.png', 'PNG');
file_dimension_is('catalyst_logo.png', 56,80);




#################################################
#
# helper subs
#
sub file_type_is {
    my $name = shift;
    my $format = shift;

    my $image_type = image_type(\$content);
    ok(ref($image_type) eq 'HASH' &&
       exists($image_type->{file_type}) &&
       $image_type->{file_type} eq $format, "$name is '$format'");
}

sub file_dimension_is {
    my $name = shift;
    my $w = shift;
    my $h = shift;

    is_deeply([dim(image_info(\$content))], [$w, $h], "$name is $w x $h");
}
