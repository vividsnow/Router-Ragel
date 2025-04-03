use strict;
use warnings;
use Test::More;

eval 'use Test::Spelling 0.12';
plan skip_all => 'Test::Spelling 0.12 required' if $@;

add_stopwords(qw(
    Ragel Inline DFA dlopen UTF MetaCPAN PCRE
    croak croaks recompile recompiles uncompileable
    placeholder placeholders matcher
    positionally unterminated
    Korablev vividsnow
    Ragel's Perl's
    XSUB XSUBs alnum xdigit
    NUL lookaround trie
    PSGI reproducibility
));

all_pod_files_spelling_ok();
