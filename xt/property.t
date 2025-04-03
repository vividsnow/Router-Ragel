use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Router::Ragel;

# Property-based: generate well-formed (pattern, path) pairs where the path
# is constructed from the pattern by substituting valid values for each
# placeholder. Assert match always succeeds and captures equal the values.
# Negative property: appending an extra segment never matches.

srand($ENV{ROUTER_RAGEL_PROPERTY_SEED} // 42);
my $iters = $ENV{ROUTER_RAGEL_PROPERTY_ITERS} // 50;

sub rstr { my $n = shift; my @c = ('a'..'z', '0'..'9'); join '', map $c[rand @c], 1..$n }
sub rname { my @c = ('a'..'z'); join '', map $c[rand @c], 1..(int(rand 5) + 1) }
sub rhex {
    my @c = ('0'..'9', 'a'..'f');
    join '', map $c[rand @c], 1..(int(rand 6) + 1);
}

sub generate_pair {
    my $nsegs = int(rand 4) + 1;
    my (@pat_segs, @vals);
    for (1..$nsegs) {
        my $r = rand;
        if ($r < 0.4) {
            my $lit = rstr(int(rand 6) + 1);
            push @pat_segs, $lit;
            # No capture for literal segments.
        } elsif ($r < 0.6) {
            push @pat_segs, ':' . rname();
            push @vals, rstr(int(rand 6) + 1);
        } elsif ($r < 0.8) {
            push @pat_segs, ':' . rname() . '<int>';
            push @vals, int(rand 1_000_000) + 1;
        } else {
            push @pat_segs, ':' . rname() . '<hex>';
            push @vals, rhex();
        }
    }
    # Build path: literal segments echo themselves; placeholder segments
    # consume the next item from @vals.
    my @path_segs;
    my $vi = 0;
    for my $p (@pat_segs) {
        if ($p =~ /^:/) { push @path_segs, $vals[$vi++] }
        else            { push @path_segs, $p }
    }
    return ('/' . join('/', @pat_segs), '/' . join('/', @path_segs), \@vals);
}

my $failures = 0;
my @samples;
for (1..$iters) {
    my ($pat, $path, $vals) = generate_pair();
    my $r = eval { Router::Ragel->new->add($pat, 'OK')->compile };
    unless ($r) {
        $failures++;
        push @samples, "compile failed: $pat ($@)" if @samples < 5;
        next;
    }
    my @res = $r->match($path);
    if (!@res || $res[0] ne 'OK') {
        $failures++;
        push @samples, "no match: pat=$pat path=$path" if @samples < 5;
        next;
    }
    my @captured = @res[1..$#res];
    if ("@captured" ne "@$vals") {
        $failures++;
        push @samples, "captures mismatch: pat=$pat path=$path got=[@captured] want=[@$vals]" if @samples < 5;
        next;
    }
    # Negative: appending an extra segment must not match
    my @extra = $r->match($path . '/extra');
    if (@extra && $extra[0] eq 'OK') {
        $failures++;
        push @samples, "extra segment matched: pat=$pat path=$path" if @samples < 5;
    }
}

is($failures, 0, "$iters generated patterns round-trip correctly")
    or diag join "\n", @samples;

done_testing;
