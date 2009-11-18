package Supr::Callbacks;
use strict;

use MT::Util qw ( trim remove_html );

sub entry_pre_save {
	my ($cb, $entry, $entry_orig) = @_;
	return if $entry->supr_url;   # alreaded supred
	my $plugin = MT->component('Supr');
	my $config = $plugin->get_config_hash('blog:'.$entry->blog_id);
	my $enabled = $config->{supr_enable};
	return if !$enabled;
	my $entry_id = $entry->id;
	my $supr_it = 0;
	
	if ($entry->status == 2) {
		if (!$entry_id) {
			$supr_it = 1;   # new entry with published status
		} else {
			# entry was previously saved in db -- now determine if it status has just been changed to published
			$entry->clear_cache();
			$entry->uncache_object();
			$entry_orig = MT->model('entry')->load($entry_id);
			if ($entry_orig->status != 2) {
				# now we know status has just been changed to published and we have no status_id on record - so supr it
				$supr_it = 1;
			}
		}
	}
	
	if ($supr_it) {
MT->log($entry->title . " just published and should be supred");
		$entry->{supr_it} = 'yes';
	}

}

sub entry_post_save {
	my ($cb, $entry, $entry_orig) = @_;
	return if $entry->supr_url;   # alreaded supred
	return unless $entry->{supr_it};
	my $entry_id = $entry->id;
	my $plugin = MT->component('Supr');
	my $config = $plugin->get_config_hash('blog:'.$entry->blog_id);
	my $enabled = $config->{supr_enable};
	return if !$enabled;
	my $supr_username = $config->{supr_username};
	my $supr_apikey = $config->{supr_apikey};
	return unless ($supr_username && $supr_apikey);
	
return unless ($entry->title =~ /supr/);												# REMOVE THIS LINE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	if ( $entry->authored_on =~
              m!(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})(?::(\d{2}))?! ) {
		my $s = $6 || 0;
		my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4, $5, $s;
		$entry->authored_on($ts);
	}

	my $field = 'title';
	my $tweet_text;
	if (0) {
		# handle case for tweet field here
	} else {
		$tweet_text = remove_html($entry->$field);
	}
	return if !$tweet_text;

	my $tweet = $tweet_text; 
	my $url = $entry->permalink;
	$tweet .= ' ' . $url;
	
	require WWW::Shorten::Supr;
	my $supr = WWW::Shorten::Supr->new(USER => $supr_username, APIKEY => $supr_apikey);
	my @services;
	push @services, 'twitter' if ($config->{twitter_default});   								#TODO add UI case if twitter_this
	push @services, 'facebook' if ($config->{fb_default});   								#TODO add UI case if fb_this
	my $suprurl;
	if (@services) {
		# one more services was requested so use 'post' API method
	    my $suprmsg = $supr->post( msg => $tweet, services => \@services );
	    $suprurl = extract_suprurl($suprmsg);
	} else {
		# no posting requested, but get su.pr url using 'shorten' API method
		$suprurl = $supr->shorten( URL => $url );
	}
use Data::Dumper;
MT->log("services is:" . Dumper(\@services));
MT->log("supr is:" . Dumper($supr));
#MT->log("suprmsg is:" . Dumper($suprmsg));
MT->log("suprurl is $suprurl");
	if ($suprurl) {
		$entry->supr_url($suprurl);
		$entry->save;
	}
	$entry->{supred} = 1;
	
	return 1;
}

sub extract_suprurl {
	my ($str) = @_;
	my $url;
    if ($str =~ m!(https?://[^\s<]+)!s) {
	    $url = $1;
    }
	return $url;
}

1;