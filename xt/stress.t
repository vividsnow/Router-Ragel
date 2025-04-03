use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Router::Ragel;

my $n = $ENV{ROUTER_RAGEL_STRESS_N} // 1000;

my $r = Router::Ragel->new;
$r->add("/route$_/:id<int>/:slug", "h$_") for 1..$n;
# A single deep route stresses the per-route capture array dimensioning.
$r->add('/deep/:a/:b/:c/:d/:e/:f/:g/:h/:i/:j', 'deep');
ok($r->compile, "compiled $n routes");

for my $i (1, int($n / 2), $n) {
    my @ret = $r->match("/route$i/42/widget");
    is($ret[0], "h$i", "route $i matched");
    is($ret[1], '42', "route $i id captured");
    is($ret[2], 'widget', "route $i slug captured");
}

my @deep = $r->match('/deep/1/2/3/4/5/6/7/8/9/10');
is($deep[0], 'deep', '10-capture route matched');
is_deeply([@deep[1..10]], [1..10], '10 captures returned in order');

is_deeply([$r->match("/no/such/route")], [], 'non-matching path returns empty');

done_testing;
