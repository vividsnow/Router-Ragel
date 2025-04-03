use strict;
use warnings;
use Test::More;

eval 'use Test::CPAN::Meta';
plan skip_all => 'Test::CPAN::Meta required' if $@;

# META.yml is only built into the dist tarball; in the source tree we have
# MYMETA.yml from `perl Makefile.PL`. Validate that against CPAN::Meta::Spec.
plan skip_all => 'MYMETA.yml not found - run `perl Makefile.PL` first'
    unless -f 'MYMETA.yml';

meta_spec_ok('MYMETA.yml');

done_testing;
