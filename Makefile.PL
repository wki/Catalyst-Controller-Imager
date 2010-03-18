use inc::Module::Install;

name     'Catalyst-Controller-Imager';
all_from 'lib/Catalyst/Controller/Imager.pm';
author   'Wolfgang Kinkeldei <wki@cpan.org>';
license  'perl';
perl_version '5.8.0';

requires 'Moose'             => '0.74';
requires 'Catalyst::Runtime' => '5.80';
requires 'Path::Class'       => '0.16';
requires 'FindBin'           => '1.47';
requires 'Imager'            => '0.72';

test_requires 'Test::Builder'         => '0.86';
test_requires 'Test::Builder::Tester' => '1.18';
test_requires 'Test::More'            => '0.86';
test_requires 'Test::Exception'       => '0.27';
test_requires 'Test::Harness'         => '3.14';
test_requires 'Image::Info'           => '1.28';

auto_install;

repository 'http://github.com/wki/Catalyst-Controller-Imager.git';

WriteAll;
