package Catalyst::Controller::Imager;

use Moose;
# w/o BEGIN, :attrs will not work
BEGIN { extends 'Catalyst::Controller'; }

# use File::stat;
use Imager;
use MIME::Types;

our $VERSION = '0.01';

has root_dir       => (is => 'rw',
                       default => sub { 'static/images' } );
has cache_dir      => (is => 'rw',
                       default => sub { undef } );
has default_format => (is => 'rw',
                       default => sub { 'jpg' } );
has max_size       => (is => 'rw',
                       default => sub { 1000 } );
                       
our %imager_format_for = (
    gif => 'gif',
    jpg => 'jpeg',
    png => 'png',
);

### TODO: add some simple counters for cache_write, cache_hit counts...

=head1 NAME

Catalyst::Controller::Imager - Imager JS/CSS Files

=head1 SYNOPSIS

    # use the helper to create your Controller
    script/myapp_create.pl controller Image Imager
    
    # DONE. READY FOR USE.

    # Just use it in your template:
    # will deliver a 200 pixel wide version of some_image.png as jpg
    <img src="/image/w-200/some_image.png.jpg" />

=head1 DESCRIPTION

Catalyst Controller that generates image files in any size you request and
opttionally converts the image format.

Possible options are:

=over

=item w-n

specifies the width of the image to generate. The height is adjusted to
maintain the same ratio as the original image. The maximum size is controlled
by a configuration parameter C<max_size> that defaults to 1000.

Can be used in conjunction with h-n

=item h-n

specifies the height of the image to generate. The width is adjusted to
maintain the same ratio as the original image. The maximum size is controlled
by a configuration parameter C<max_size> that defaults to 1000.

Can be used in conjunction with w-n

=item f-xxx

specifies the format of the image to generate. An alternative way is to simply
append the format after the image name as in the example above.

=back

=head1 CONFIGURATION

A simple configuration of your Controller could look like this:

    __PACKAGE__->config(
        # the directory to look for files (inside root)
        # defaults to 'static/images'
        root_dir => 'static/images',
        
        # specify a cache dir if caching is wanted
        # defaults to no caching (more expensive)
        cache_dir => undef,
        
        # specify a maximum value for width and height of images
        # defaults to 1000 pixels
        max_size => 1000,
        
        # maintain a list of allowed formats
        # as a list of file-extensions
        # default: jpg, gif and png
        allowed_formats => [qw(jpg gif png)],
        
        ### TODO: imager_options
    );

=head1 METHODS

=head2 BUILD

constructor for this Moose-driven class

=cut

sub BUILD {
    my $self = shift;
    my $c = $self->_app;

    $c->log->warn(ref($self) . " - directory '" . $self->root_dir . "' not present.")
        if (!-d $c->path_to('root', $self->root_dir));
}

=head2 generate_image

the working horse that generates the image, directly sets
Catalyst's response body and headers

input: $self, $c, @(image params from uri)


=cut

sub generate_image :Private {
    my ( $self, $c, @args ) = @_;

    #
    # operate on options
    #
    my %option = (f => $self->default_format());
    my @path;
    my $file_found = 0;
    
    foreach my $arg (@args) {
        if ($arg =~ m{\A (\w+) - (.*) \z}xms) {
            # looks like an argument
            my $key = $1;
            my $value = $2;
            
            # simple sanity check for h,w
            next if (($key eq 'h' || $key eq 'w') &&
                     (!$value || $value !~ m{\A \d+ \z}xms || $value > $self->max_size()));
            
            # simple format checking
            next if ($key eq 'f' && !exists($imager_format_for{$value}));
            
            $option{$key} = $value;
        } elsif (-d $c->path_to('root', $self->root_dir, @path, $arg)) {
            # looks like a directory
            push @path, $arg;
        } elsif (-f $c->path_to('root', $self->root_dir, @path, $arg)) {
            # a file
            push @path, $arg;
            $file_found = 1;
            if ($arg =~ m{\.(\w+) \z}xms) {
                $option{f} = $1;
            }
        } elsif ($arg =~ m{\A (.+) \. (\w+) \z}xms &&
                 -f ($c->path_to('root', $self->root_dir, @path, $1))) {
            # a file plus conversion
            push @path, $1;
            if (exists($imager_format_for{$2})) {
                $option{f} = $2;
            } else {
                die "format not found.";
            }
            $file_found = 1;
        } else {
            # silently ignore it
            # push @{$option{ignored}}, $arg;
        }
    }
    die "no image found" if (!$file_found);

    #
    # define some vars
    #
    my $data; # holds our image data (from cache or by transformation)
    
    #
    # test for caching if wanted
    #
    my $cache_path;
    if ($self->cache_dir && -d $self->cache_dir && -w $self->cache_dir) {
        #
        # we cant caching and the cache directory is writable,
        # try to find it in cache.
        #
        $cache_path = $c->path_to( (map {"$_-$option{$_}"} sort keys(%option)), @path );
        if (-f $cache_path && 
            -M $cache_path > -M $c->path_to('root', $self->root_dir, @path)) {
            #
            # cache-hit! simply load.
            # clear the cache_path afterwards to avoid another write...
            #
            $data = $cache_path->slurp();
            $cache_path = undef;
        }
    }
    
    if (!$data) {
        #
        # image not yet processed / not found in cache
        # process the image
        #
        my $img = Imager->new();
        $img->read(file => $c->path_to('root', $self->root_dir, @path)) or die "cannot load image";

        if ($option{w} && !$option{h}) {
            $img = $img->scale(xpixels => $option{w});
        } elsif ($option{h} && !$option{w}) {
            $img = $img->scale(ypixels => $option{h});
        } elsif ($option{h} && $option{w}) {
            $img = $img->scale(xpixels => $option{w}, 
                               ypixels => $option{h}, 
                               type => 'min');
        }

        #
        # create destination image format
        #
        $img->write(type => $imager_format_for{$option{f}}, data => \$data);
    }
    
    #
    # put into cache if wanted
    #
    if ($cache_path && $data) {
        if (!-d $cache_path->dir) {
            $cache_path->dir->mkpath();
        }
        
        if (open(my $cache_file, '>', $cache_path)) {
            print $cache_file $data;
            close($cache_file);
        }
    }
    
    #
    # deliver the data we generated
    #
    if ($data) {
        my $types = MIME::Types->new();
        $c->response->headers->content_type($types->mimeTypeOf($option{f}) || $types->mimeTypeOf($path[-1]) || 'image/unknown');
        $c->response->body($data);
    } else {
        my $dump = '<pre>' . Data::Dumper->Dump([$file_found, \@args,\@path,\%option],[qw(file_found args path option)]) . '</pre>';
        $c->response->body("nothing to output... $dump");
    }
    
    #my $dump = '<pre>' . Data::Dumper->Dump([$file_found, \@args,\@path,\%option],[qw(file_found args path option)]) . '</pre>';
    #$c->response->body($c->path_to(@root_dir) . "Matched Wittmann::Controller::Image in Image, $dump");
}

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
