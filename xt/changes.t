use strict;
use warnings;
use Test::More;

eval 'use Test::CPAN::Changes';
plan skip_all => 'Test::CPAN::Changes required' if $@;

changes_file_ok('Changes');

done_testing;
