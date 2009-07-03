use Module::Build::Compat;

my $build = Module::Build->new(
    module_name => 'Catalyst::Controller::Imager',
    license => 'perl',
    dist_author => 'Wolfgang Kinkeldei <wki@cpan.org>',
    requires => {
        'perl'                  => '5.8.8',
        'Moose'                 => '0.74',
        'Catalyst::Runtime'     => '5.80',
        'File::stat'            => '1.00',
        'List::Util'            => '1.19',
        'Path::Class'           => '0.16',
        'FindBin'               => '1.47',
        'Test::Builder'         => '0.86',
        'Test::Builder::Tester' => '1.18',
        'Test::More'            => '0.86',
        'Test::Exception'       => '0.27',
        'Test::Harness'         => '3.14',
        'Imager'                => '0.67',
    },
    create_makefile_pl => 'traditional',
    create_readme => 1,
    # sign => 1,
);
$build->create_build_script;
Module::Build::Compat->create_makefile_pl(traditional => $build);