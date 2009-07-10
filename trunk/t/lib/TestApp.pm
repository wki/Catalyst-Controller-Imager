package TestApp;

use Moose;
extends 'Catalyst';

use Catalyst::Runtime '5.80';
use FindBin;

use Catalyst ( qw(-Log=error) );

__PACKAGE__->config(
        name => 'TestApp',
        home => "$FindBin::Bin",
);

__PACKAGE__->setup();

1;
