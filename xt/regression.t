use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Time::HiRes qw(time);
use JSON::PP;
use Router::Ragel;

# Hot-path regression tripwire. Records a per-machine baseline on first run
# (also when ROUTER_RAGEL_REWRITE_BASELINE is set), then asserts subsequent
# runs stay within ROUTER_RAGEL_REGRESSION_THRESHOLD (default 0.85, i.e. up
# to a 15% drop allowed) of that baseline. Numbers vary across hardware, so
# the baseline file is host-specific and not shipped in the dist.

my $baseline_file = "$Bin/regression-baseline.json";
my $threshold = $ENV{ROUTER_RAGEL_REGRESSION_THRESHOLD} || 0.85;

my $r = Router::Ragel->new
    ->add('/qest/qwe', 1)
    ->add('/jest/route/other/:a', 2)
    ->add('/test/:id<int>/:param/:aa/:bb/get', 3)
    ->add('/another/:route/add', 4)
    ->add('/asd/:bb', 5)
    ->compile;

my @paths = (
    '/qest/qwe',
    '/jest/route/other/aa',
    '/test/42/param/x/y/get',
    '/another/route/add',
    '/asd/foo',
    '/no/match/here',
);

# warmup
for (1..5000) { Router::Ragel::match($r, $_) for @paths }

my $iters = $ENV{ROUTER_RAGEL_REGRESSION_ITERS} // 50_000;
my $start = time;
for (1..$iters) { Router::Ragel::match($r, $_) for @paths }
my $elapsed = time - $start;
my $rate = ($iters * @paths) / $elapsed;
note(sprintf 'rate: %.0f matches/sec (%.3fs for %d calls)',
     $rate, $elapsed, $iters * scalar @paths);

if (-f $baseline_file && !$ENV{ROUTER_RAGEL_REWRITE_BASELINE}) {
    open my $fh, '<', $baseline_file or die "open $baseline_file: $!";
    my $data = decode_json(do { local $/; <$fh> });
    close $fh;
    my $baseline = $data->{rate};
    note(sprintf 'baseline: %.0f matches/sec (recorded %s)',
         $baseline, $data->{recorded} // 'unknown');
    note(sprintf 'current is %.1f%% of baseline', 100 * $rate / $baseline);
    ok($rate >= $baseline * $threshold,
       sprintf('rate %.0f >= %.0f * %g (%.0f)',
               $rate, $baseline, $threshold, $baseline * $threshold));
} else {
    open my $fh, '>', $baseline_file or die "open $baseline_file: $!";
    print $fh encode_json({ rate => $rate, recorded => scalar localtime });
    close $fh;
    pass(sprintf 'wrote baseline (%.0f matches/sec) to %s', $rate, $baseline_file);
    diag 'Baseline created. Re-run to assert against it.';
}

done_testing;
