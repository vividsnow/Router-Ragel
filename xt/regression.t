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
#
# Recording a baseline SKIPS rather than passes: a fresh CI runner has no
# baseline, and reporting a pass there would advertise coverage this test did
# not provide. It only asserts on a host that has run it before.

my $baseline_file = "$Bin/regression-baseline.json";
my $threshold = $ENV{ROUTER_RAGEL_REGRESSION_THRESHOLD} || 0.85;
my $have_baseline = -f $baseline_file && !$ENV{ROUTER_RAGEL_REWRITE_BASELINE};

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

# Take the best of several passes. What we want to detect is a change in the
# hot path; a slow pass means the machine was busy, not that matching got
# slower. Measuring the minimum makes the tripwire survive a loaded box (a
# single-pass version of this test swung between 81% and 99% of baseline on
# one host purely with background load).
my $reps = $ENV{ROUTER_RAGEL_REGRESSION_REPS} // 3;
my $rate = 0;
for my $rep (1 .. $reps) {
    my $start = time;
    for (1..$iters) { Router::Ragel::match($r, $_) for @paths }
    my $elapsed = time - $start;
    my $this = ($iters * @paths) / $elapsed;
    note(sprintf 'pass %d/%d: %.0f matches/sec (%.3fs for %d calls)',
         $rep, $reps, $this, $elapsed, $iters * scalar @paths);
    $rate = $this if $this > $rate;
}
note(sprintf 'rate: %.0f matches/sec (best of %d)', $rate, $reps);

if ($have_baseline) {
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
    done_testing;
} else {
    open my $fh, '>', $baseline_file or die "open $baseline_file: $!";
    print $fh encode_json({ rate => $rate, recorded => scalar localtime });
    close $fh;
    plan skip_all => sprintf
        'no baseline for this host; recorded %.0f matches/sec, re-run to assert against it',
        $rate;
}
