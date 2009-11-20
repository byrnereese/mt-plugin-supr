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
	my $tweet_text;
    my $twitter_this;
    my $fb_this;
    
    my $app = MT->app;
    if ($app->can('param')) {
        my $q = $app->param;
        $tweet_text = remove_html($q->param('su_twitter')) if $q->param('su_twitter');
        $twitter_this = $q->param('twitter-this') if $q->param('twitter-this');
        $fb_this = $q->param('fb-this') if $q->param('fb-this');
    }

	my $field = 'title';

	$tweet_text = remove_html($entry->$field) unless $tweet_text;

	return if !$tweet_text;

	my $tweet = $tweet_text; 
	my $url = $entry->permalink;
	$tweet .= ' ' . $url;
	
	require WWW::Shorten::Supr;
	my $supr = WWW::Shorten::Supr->new(USER => $supr_username, APIKEY => $supr_apikey);
	my @services;
	push @services, 'twitter' if ($twitter_this); 
	push @services, 'facebook' if ($fb_this);
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

sub edit_entry_xfrm {
    my ($cb, $app, $tmpl) = @_;
    my $slug;
    $slug = <<END_TMPL;
<link rel="stylesheet" type="text/css" href="<mt:StaticWebPath>plugins/Supr/app.css" />
END_TMPL
$$tmpl =~ s{(<mt:setvarblock name="html_head" append="1">)}{$1 $slug}msgi;
}

sub edit_entry_param {
	my($cb, $app, $param, $tmpl) = @_;

    my $q = $app->param;
	my $entry_blog_id = $q->param('blog_id');
	my $author = $app->user;
	my $plugin = MT->component('Supr');
    my $config = $plugin->get_config_hash('blog:'.$entry_blog_id);
	return if !$config->{supr_enable};
	
	my $twitter_checked = "checked" if $config->{twitter_default};
	my $fb_checked = "checked" if $config->{fb_default};

    my $kw_field = $tmpl->getElementById('keywords')
        or return $app->error('cannot get the keywords block');
    my $su_field = $tmpl->createElement('app:setting', {
        id => 'su_twitter',
        label => $app->translate('Post on Twitter & Facebook with Su.pr'),  })
        or return $app->error('cannot create the su_twitter element');
## TODO: re-style the HTML below to match MT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	my $innerHTML = <<HTML;
<script type="text/javascript">
<!-- Begin
function countChars(field,cntfield) {
cntfield.value = 119 - field.value.length;
}
//  End -->
</script>
<textarea name="su_twitter" id="su_twitter" rows="2" cols="60"
onKeyDown="countChars(document.entry_form.su_twitter,document.entry_form.twitlength)"
onKeyUp="countChars(document.entry_form.su_twitter,document.entry_form.twitlength)"></textarea>
    
	<div class="supr-controls">
      <div class="char-counter">
        <input readonly type="text" name="twitlength" size="3" maxlength="3" value="119" /> characters left
      </div>
      <label class="twitter" for="supr-this"><input type="checkbox" name="twitter-this" $twitter_checked id="twitter-this" value="1"  /> Post this on Twitter</label>
      <label class="fb" for="fb-this"><input type="checkbox" name="fb-this" $fb_checked id="fb-this" value="1"  /> Post this on Facebook</label>
	  <p class="help">Twitter posts are a maximum of 140 characters; if your su.pr URL is appended to the end of your document, you have 119 characters available.</p>
    </div>
HTML
	$su_field->innerHTML( $innerHTML );
    $tmpl->insertAfter($su_field, $kw_field)
        or return $app->error('failed to insertAfter.');
	$param;
}


1;
