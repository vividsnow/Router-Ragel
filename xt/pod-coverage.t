use strict;
use warnings;
use Test::More;

eval 'use Test::Pod::Coverage 1.08';
plan skip_all => 'Test::Pod::Coverage 1.08 required' if $@;

# store_func_ptr is the Inline-generated XSUB that installs the compiled
# matcher's address on the router; it is not part of the public API. (The
# per-machine match_* functions are static and never bound into the package.)
# STORABLE_freeze/STORABLE_thaw are Storable's hooks, called by Storable and
# not by users; their contract is described under LIMITATIONS. (The generated
# matchers are static and never bound; _func_ptr is private by its name.)
all_pod_coverage_ok({
    also_private => [qr/^STORABLE_(?:freeze|thaw)$/],
});
