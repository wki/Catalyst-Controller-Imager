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
has thumbnail_size => (is => 'rw',
                       default => sub { 80 } );
                       
# our %imager_format_for = ( ### FIXME: use Imager::def_guess_type() instead!
#     gif => 'gif',
#     jpg => 'jpeg',
#     png => 'png',
# );

=head1 NAME

Catalyst::Controller::Imager - generate scaled or mangled images

=head1 SYNOPSIS

    # use the helper to create your Controller
    script/myapp_create.pl controller Image Imager
    
    # DONE. READY FOR USE.
    
    ### TODO: describe configutation

    # Just use it in your template:
    # will deliver a 200 pixel wide version of some_image.png as jpg
    <img src="/image/w-200/some_image.png.jpg" />
    
    # will deliver a 210 by 300 pixel sized image without conversion
    # (empty areas will be white)
    <img src="/image/w-210-h-300/other_image.jpg" />

=head1 DESCRIPTION

Catalyst Controller that generates image files in any size you request and
optionally converts the image format. Images are taken from a cache directory
if possible and desired or generated on the fly. The Cache-directory has a
structure that is very similar to the URI scheme, so a redirect rule in your
webserver's setup would do this job also.

Every single option that is desired is added to the URL of the image requested
to load. The format desired is simply added to the original file name by
appending C<.ext> to the original file name.

A Controller that is derived from C<Catalyst::Controller::Imager> may define
its own image conversion functions. See EXTENDING below.

Possible initially defined options are:

=over

=item w-n

specifies the width of the image to generate. The height is adjusted to
maintain the same ratio as the original image. The maximum size is controlled
by a configuration parameter C<max_size> that defaults to 1000.

Can be used in conjunction with h-n. However, if both options are given, the
minimum of both will win in order to maintain the aspect ratio of the original
image.

=item h-n

specifies the height of the image to generate. The width is adjusted to
maintain the same ratio as the original image. The maximum size is controlled
by a configuration parameter C<max_size> that defaults to 1000.

Can be used in conjunction with w-n. However, if both options are given, the
minimum of both will win in order to maintain the aspect ratio of the original
image.

=back

=head1 EXTENDING

The magic behind all the conversions is the existence of specially named
action methods (their name starts with 'want_') that prepare a set of
stash-variables. After all scaling options have been processed, the image
mangling itself will start.

If you plan to offer URIs like:

    /image/thumbnail/image.jpg
    /image/size-200-300/image.jpg
    /image/watermark/image.jpg
    
    # or a combination of them:
    /image/size-200-300-watermark/image.jpg
    
    # but not invalid things:
    /image/size-200/image.jpg

you may build these action methods:

    sub want_thumbnail :Action :Args(0) {
        my ($self, $c) = @_;
        
        $c->stash(scale => {w => 80, h => 80, mode => 'fit'});
    }

    sub want_size :Action :Args(2) {
        my ($self, $c, $w, $h) = @_;
        
        $c->stash(scale => {w => $w, h => $h, mode => 'fit'});
    }
    
    sub want_watermark :Action :Args(0) {
        my ($self, $c) = @_;
        
        push @{$c->stash->{after_scale}}, \&watermark_generator;
    }

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

#
# stash variables:
#   - image_path   == relative path to original image
#   - image        == Imager Object as soon as image is loaded
#   - image_data   == binary image data after conversion or from cache
#   - cache_path   == relative path to cached image
#   - format       == format for conversion
#   - scale        == { w => n, h => n, mode => min/max/fit }
#   - before_scale == list of Actions executed before scaling
#   - after_scale  == list of Actions executed after scaling
#

# start of our chain -- eats package namespace, eg. /image
sub base :Chained :PathPrefix :CaptureArgs(0) {
    my ($self, $c) = @_;
    
    # init stash
    $c->stash(image_path   => []);               # path-parts to the image
    $c->stash(image        => undef);            # Imager object
    $c->stash(image_data   => undef);            # binary data for delivery
    $c->stash(cache_path   => []);               # part-parts to cached image
    $c->stash(scale        => {
                                w => undef,
                                h => undef,
                                mode => 'min',
                              });
    $c->stash(format       => undef);            # file format
    $c->stash(before_scale => []);               # actions to run before scale
    $c->stash(after_scale  => []);               # actions to run after scale
}

# second chain step -- eat up scaling parameter(s)
# must be characters separated by '-'
# if the first word matches an action, it is called with
# the next x args depending on the :Arg() attribute of the
# action called. As long as things remain more actions are invoked.
sub scale :Chained('base') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $capture) = @_;
    
    #$c->log->debug('captures: ' . join(',', @{$c->req->captures}));
    #$c->log->debug("capture=$capture");
    
    push @{$c->stash->{cache_path}}, $capture;
    
    my @args = split(/-/, $capture);
    while (scalar(@args)) {
        my $action_name = 'want_' . shift @args;
        # my $action = $c->controller->action_for($action_name);
        my $action = $self->action_for($action_name);
        die "unknown action: $action_name" if (!$action);
        
        my $nr_args = ($action->attributes->{Args} || [])->[0] || 0;
        #$c->log->debug("action: $action_name: $action, args = $nr_args");
        
        $c->forward($action, [ splice(@args, 0, $nr_args) ]);
    }
}

# final chain step
# - consume image path relative to root_dir
# - plus optional format extension for conversion
sub image :Chained('scale') :PathPart('') :Args {
    my ($self, $c, @path) = @_;

    die 'no file name given' if (!scalar(@path));
    $c->log->debug("path=" . join('|', @path));
    
    push @{$c->stash->{cache_path}}, @path;
    my $last_uri_part = pop @path;
    my $file_name = $last_uri_part;
    
    # guess file format
    if ($last_uri_part =~ m{(\.\w+) \z}xms) {
        $c->stash->{format} ||= Imager::def_guess_type($1);
    }
    
    # find real image file by stripping extensions
    while (!-f $c->path_to('root', $self->root_dir, @path, $file_name)) {
        die 'requested image file not found' if ($file_name !~ s{\. \w+ \z}{}xms);
    }
    
    push @{$c->stash->{image_path}}, @path, $file_name;
    
    # request conversion or cache-retrieval
    $c->forward('convert_image');
}

# do the conversion
# all args in stash
sub convert_image :Action {
    my ($self, $c) = @_;
    
    my $cache_dir  = $self->cache_dir 
                     ? $c->path_to($self->cache_dir) 
                     : undef;
    my $cache_path = $self->cache_dir
                     ? $c->path_to($self->cache_dir, @{$c->stash->{cache_path}})
                     : undef;
    my $file_path  = $c->path_to('root', $self->root_dir, @{$c->stash->{image_path}});
    
    if ($cache_path && -f $cache_path && -M $cache_path > -M $file_path) {
        #
        # caching wanted and cached image available
        #
        $c->stash->{image_data} = $cache_path->slurp();
    } else {
        #
        # we must calculate
        #
        $c->stash->{image} = Imager->new();
        $c->stash->{image}->read(file => $file_path) or die "cannot load image '$file_path'";
        
        #
        # apply things requested before scaling
        #
        $c->forward($_)
            for @{$c->stash->{before_scale}};
        
        #
        # scale
        #
        my $scale = $c->stash->{scale} || {};
        if ($scale->{w} && !$scale->{h}) {
            $c->stash->{image} = $c->stash->{image}->scale(xpixels => $scale->{w});
        } elsif ($scale->{h} && !$scale->{w}) {
            $c->stash->{image} = $c->stash->{image}->scale(ypixels => $scale->{h});
        } elsif ($scale->{h} && $scale->{w}) {
            $c->stash->{image} = $c->stash->{image}->scale(xpixels => $scale->{w}, 
                                                           ypixels => $scale->{h}, 
                                                           type => 'min');
        }

        #
        # apply things requested after scaling
        #
        $c->forward($_)
            for @{$c->stash->{after_scale}};
        
        #
        # create destination image format
        #
        my $data;
        $c->stash->{image}->write(type => $c->stash->{format} || 'jpeg', data => \$data);
        $c->stash->{image_data} = $data;

        #
        # put into cache if wanted
        #
        if ($cache_path && -d $cache_dir && -w $cache_dir && $data) {
            if (!-d $cache_path->dir) {
                $cache_path->dir->mkpath();
            }

            if (open(my $cache_file, '>', $cache_path)) {
                print $cache_file $data;
                close($cache_file);
            }
        }
    }
}

# deliver the data
sub end :Action {
    my ($self, $c) = @_;

    if (scalar(@{$c->error}) || !$c->stash->{image_data}) {
        $c->log->debug('error_encountered: ' . join(',', @{$c->error}));
        $c->response->body('image error...' . join(',', @{$c->error}));
        $c->response->status(404);
        $c->clear_errors;
    } else {
        my $types = MIME::Types->new();
        my $mime = $types->mimeTypeOf($c->stash->{format});
        $c->response->headers->content_type($mime || 'image/unknown');
        $c->response->body($c->stash->{image_data});
    }
}


# examples
sub want_thumbnail :Action :Args(0) {
    my ($self, $c) = @_;
    
    $c->stash(scale => {w => $self->thumbnail_size, h => $self->thumbnail_size, mode => 'fit'});
}

sub want_w :Action :Args(1) {
    my ($self, $c, $arg) = @_;
    
    die 'width must be numeric' if ($arg =~ m{\A \d+ \z}xms);
    die 'width out of range' if ($arg < 1 || $arg > $self->max_size);
    
    $c->stash(scale => {w => $arg, mode => 'min'});
}

sub want_h :Action :Args(1) {
    my ($self, $c, $arg) = @_;
    
    die 'height must be numeric' if ($arg =~ m{\A \d+ \z}xms);
    die 'height out of range' if ($arg < 1 || $arg > $self->max_size);
    
    $c->stash(scale => {h => $arg, mode => 'min'});
}

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
