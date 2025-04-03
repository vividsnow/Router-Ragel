use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

# Verify every eg/ script at least parses, and run the self-contained ones.
my $eg = "$Bin/../eg";
my $lib = "$Bin/../lib";
my @scripts = sort glob "$eg/*.pl";

# Some scripts depend on optional modules; skip syntax-check if they're absent.
my %optional_deps = (
    'bench.pl' => [qw(Router::XS Router::R3 URI::Router Mojolicious::Routes)],
    'plack.pl' => ['Plack::Request'],
);

sub deps_available {
    my $names = $optional_deps{$_[0]} or return 1;
    for my $m (@$names) {
        my $f = $m; $f =~ s{::}{/}g; $f .= '.pm';
        return 0 unless eval { require $f; 1 };
    }
    1;
}

# perl -c on every example
for my $f (@scripts) {
    (my $name = $f) =~ s{.*/}{};
    SKIP: {
        unless (deps_available($name)) {
            skip "$name: optional deps missing (@{$optional_deps{$name}})", 1;
        }
        my $out = qx{$^X -I"$lib" -c "$f" 2>&1};
        like($out, qr/syntax OK/, "syntax OK: $name") or diag $out;
    }
}

# Execute the ones that don't need an external server or extra-router prereqs.
for my $name (qw(typed.pl recompile.pl dump-grammar.pl method-aware.pl)) {
    my $f = "$eg/$name";
    SKIP: {
        skip "$name not present", 1 unless -f $f;
        my $out = qx{$^X -I"$lib" "$f" 2>&1};
        is($? >> 8, 0, "runs cleanly: $name") or diag $out;
    }
}

# large.pl with a tiny N to keep the test fast.
{
    my $f = "$eg/large.pl";
    SKIP: {
        skip 'large.pl not present', 1 unless -f $f;
        my $out = qx{$^X -I"$lib" "$f" 30 2>&1};
        is($? >> 8, 0, 'runs cleanly: large.pl 30') or diag $out;
    }
}

done_testing;
