use inc::Module::Install;

name     'Catalyst-Controller-Imager';
all_from 'lib/Catalyst/Controller/Imager.pm';
author   q{Wolfgang Kinkeldei <wolfgang@kinkeldei.de>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

