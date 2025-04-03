use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Router::Ragel;

# Fuzz: feed compile() and match() random byte strings. Allowed outcomes are
# "croaks gracefully" or "compiles/matches without crashing". Segfaults,
# infinite loops, or assertion failures fail the test by virtue of not
# reaching the final ok().

srand($ENV{ROUTER_RAGEL_FUZZ_SEED} // 1337);
my $iters = $ENV{ROUTER_RAGEL_FUZZ_ITERS} // 100;

# Phase 1: fuzz compile() with random pattern bytes.
# Restricted to characters our parser interprets -- keeps the test focused on
# our own validation and literal-escape paths and avoids the
# typed-placeholder verbatim-passthrough channel into Ragel.
my @alphabet = ('a'..'z', '0'..'9', '/', ':', '_', '.');
for (1..$iters) {
    my $len = int(rand 30) + 1;
    my $bytes = '/' . join '', map $alphabet[int rand @alphabet], 1..$len;
    my $r = Router::Ragel->new;
    eval { $r->add($bytes, 1); $r->compile };
    # No segfault required; eval traps croaks.
}

# Phase 2: fuzz match() with random path bytes against a fixed router.
my $r = Router::Ragel->new
    ->add('/x/:id<int>', 'a')
    ->add('/y/:hash<hex>', 'b')
    ->add('/v/:m<int>.:n<int>', 'c')
    ->add('/z/:rest<[a-z0-9\-]+>', 'd')
    ->compile;

for (1..$iters) {
    my $nsegs = int(rand 5) + 1;
    my @segs;
    for (1..$nsegs) {
        my $slen = int(rand 8);
        push @segs, join '', map chr(int(rand 90) + 32), 1..$slen;
    }
    my $path = '/' . join '/', @segs;
    eval { $r->match($path) };
}

ok(1, "fuzz: 2 * $iters iterations completed without crash");
done_testing;
