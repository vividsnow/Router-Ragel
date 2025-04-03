use strict;
use warnings;
use Test::More;

eval 'use Test::Pod::Coverage 1.08';
plan skip_all => 'Test::Pod::Coverage 1.08 required' if $@;

# match_${id} are per-instance Inline-generated XSUBs; store_func_ptr is the
# trampoline-installer XSUB. Neither is part of the public API.
all_pod_coverage_ok({
    also_private => [qr/^(?:store_func_ptr|match_\w+)$/],
});
