package Supr::Tags;
use strict;

sub _hdlr_supr_url {
    my ($ctx, $args) = @_;
    my $entry = $ctx->stash('entry');
    return $entry->meta('supr_url') || '';
}

1;