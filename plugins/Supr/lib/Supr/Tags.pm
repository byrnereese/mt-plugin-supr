package Supr::Tags;
use strict;

sub _hdlr_supr_url {
    my ( $ctx, $args ) = @_;
    my $entry = $ctx->stash('entry');
    return '' if !$entry;
    return $entry->meta('supr_url') || '';
}

sub _hdlr_supr_text {
    my ( $ctx, $args ) = @_;
    my $entry = $ctx->stash('entry');
    return '' if !$entry;
    return $entry->meta('supr_text') || '';
}

1;
