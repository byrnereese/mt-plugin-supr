package Supr::Callbacks;
use strict;

use MT::Util qw ( trim remove_html relative_date );

sub entry_pre_save {
    my ( $cb, $entry, $entry_orig ) = @_;
    return if $entry->supr_url;    # alreaded supred
    my $plugin  = MT->component('Supr');
    my $config  = $plugin->get_config_hash( 'blog:' . $entry->blog_id );
    my $enabled = $config->{supr_enable};
    return if !$enabled;
    my $entry_id = $entry->id;
    my $supr_it  = 1;

    if ( $entry->status == MT->model('entry')->RELEASE() ) {
        if ( !$entry_id ) {
            $supr_it = 1;          # new entry with published status
        }
        else {
            # entry was previously saved in db -- now determine if it status has 
            # just been changed to published
            $entry->clear_cache();
            $entry->uncache_object();
            $entry_orig = MT->model('entry')->load($entry_id);
            if ( $entry_orig->status != MT->model('entry')->RELEASE() ) {
                # now we know status has just been changed to published and we have 
                # no status_id on record - so supr it
                $supr_it = 1;
            }
        }
    }

    if ($supr_it) {
        MT->log(
            {
                blog_id => $entry->blog_id,
                message => $entry->title . " just published and should be supred"
            }
        );
        $entry->{supr_it} = 'yes';
    }
    return 1;
}

sub entry_post_save {
    my ( $cb, $entry, $entry_orig ) = @_;
    require MT::Request;
    my $r = MT::Request->instance();
    return if $r->stash('supred_already_this_session');

    my $app = MT->app;
    my $q = $app->param;
    my $plugin   = MT->component('Supr');
    my $config   = $plugin->get_config_hash( 'blog:' . $entry->blog_id );
    my $enabled  = $config->{supr_enable};
    return if !$enabled;

    my $supr_username = $config->{supr_username};
    my $supr_apikey   = $config->{supr_apikey};
    return unless ( $supr_username && $supr_apikey );

    return if $entry->supr_url && !$q->param('supr_repost');    # alreaded supred
    return unless $entry->{supr_it} || $q->param('supr_repost');

    if ( $entry->authored_on =~
        m!(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})(?::(\d{2}))?! )
    {
        my $s = $6 || 0;
        my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4, $5, $s;
        $entry->authored_on($ts);
    }
    my ($tweet_text,$twitter_this,$fb_this,@services);
    if ( $app->can('param') ) {
        $tweet_text = remove_html( $q->param('su_twitter') )
          if $q->param('su_twitter');
        push @services, 'twitter' if $q->param('twitter-this');
        push @services, 'facebook' if $q->param('fb-this');
    }
    return if !$tweet_text;

    my $url   = $entry->permalink;
    if ($q->param('supr_repost')) {
	MT->log("Tweet text BEFORE: $tweet_text");
	$tweet_text = _str_replace($entry->supr_url,$url,$tweet_text);
	MT->log("Tweet text AFTER: $tweet_text");
    } else {
	$tweet_text .= ' ' . $url;
    }

    require WWW::Shorten::Supr;
    my $supr =
      WWW::Shorten::Supr->new( USER => $supr_username, APIKEY => $supr_apikey );

    my ($supr_url,$supr_msg);
    if (@services) {
        # one more services was requested so use 'post' API method
	MT->log("Posting $tweet_text");
        $supr_msg = $supr->post( msg => $tweet_text, services => \@services );
        $supr_url = extract_suprurl($supr_msg);
    }
    else {
        # no posting requested, but get su.pr url using 'shorten' API method
        $supr_url = $supr->shorten( URL => $url );
    }
    if ( $supr->is_error ) {
        MT->log(
            {
                blog_id => $entry->blog_id,
                message => "There was an error shortening '"
                  . $entry->title . "': "
                  . $supr->error_message
            }
        );
        $entry->{supred_already_this_session} = 0;
        return 1;
    }

    if ($supr_url) {
        $entry->supr_url($supr_url);
        $entry->supr_text($supr_msg);
	$entry->supr_posted_to(join(',',@services));

        my @ts = MT::Util::offset_time_list(time, $entry->blog_id);
        my $ts = sprintf '%04d%02d%02d%02d%02d%02d',
	$ts[5]+1900, $ts[4]+1, @ts[3,2,1,0];
        $entry->supr_posted_on($ts);

	$r->stash('supred_already_this_session',1);
        $entry->save;
    }

    return 1;
}

sub extract_suprurl {
    my ($str) = @_;
    my $url;
    if ( $str =~ m!(https?://[^\s<]+)!s ) {
        $url = $1;
    }
    return $url;
}

sub edit_entry_xfrm {
    my ( $cb, $app, $tmpl ) = @_;
    my $slug;
    $slug = <<END_TMPL;
<link rel="stylesheet" type="text/css" href="<mt:StaticWebPath>plugins/Supr/app.css" />
<script type="text/javascript" src="<mt:StaticWebPath>jquery/jquery.js"></script>
<script type="text/javascript" src="<mt:StaticWebPath>plugins/Supr/jquery.clipboard.min.js"></script>
END_TMPL
    $$tmpl =~ s{(<mt:setvarblock name="html_head" append="1">)}{$1 $slug}msi;
}

sub edit_entry_param {
    my ( $cb, $app, $param, $tmpl ) = @_;

    my $blog          = $app->blog;
    my $q             = $app->param;
    my $author        = $app->user;
    my $plugin        = MT->component('Supr');
    my $config        = $plugin->get_config_hash( 'blog:' . $blog->id );
    return if !$config->{supr_enable};

    my ($entry,$posted_to,$posted_on,$supr_text);
    my ($twitter_checked,$fb_checked);
    if ($param->{id}) {
	$entry = MT->model('entry')->load($param->{id});
	$posted_to = join(' and ',split(',',$entry->supr_posted_to()));
	$posted_on = relative_date( $entry->supr_posted_on, time, $entry->blog );
	$supr_text = $entry->supr_text();
    }
    if ($entry && $posted_to) {
	$twitter_checked = "checked" if $entry->supr_posted_to =~ /twitter/;
	$fb_checked      = "checked" if $entry->supr_posted_to =~ /facebook/;
    } else {
	$twitter_checked = "checked" if $config->{twitter_default};
	$fb_checked      = "checked" if $config->{fb_default};
    }
    my $supr_dis        = ( $supr_text ne '' ? 'disabled="disabled"' : '' );

    my $kw_field = $tmpl->getElementById('keywords')
      or return $app->error('cannot get the keywords block');
    my $su_field = $tmpl->createElement(
        'app:setting',
        {
            id    => 'su_twitter',
	    class => $supr_text ne '' ? "already-posted" : "",
            label => $app->translate('Post on Twitter & Facebook with Su.pr'),
        }
    ) or return $app->error('cannot create the su_twitter element');
    my $postedHTML;
    if ($posted_to) {
	$postedHTML = "Posted to $posted_to " . ($posted_on =~ /ago/ ? "" : " on ") 
	    . $posted_on;
    }
    my $innerHTML = <<HTML;
<script type="text/javascript">
<!-- Begin
function countChars() {
  \$('.supr-controls .char-counter span').html(140 - \$('#su_twitter').val().length);
}
\$(document).ready( function() {
    \$('#su_twitter-field .posted a').click( function() {
	\$('#su_twitter-field .posted').hide();
	\$('#su_twitter-field .post').show();
	\$('#su_twitter').removeAttr('disabled');
	\$('#su_twitter-field').removeClass('already-posted');
	\$(this).parent().find('input[name=supr_repost]').val(1);
    });
    countChars();
});
    \$.clipboardReady(function(){
	$\( '#urls-field a.copy' ).click(function(){
          var txt = \$(this).parent().find('span a').html();
	  \$.clipboard( txt );
          return false;
	});
    }, { swfpath: "<mt:StaticWebPath>plugins/Supr/jquery.clipboard.swf", debug: true } );
// End -->
</script>
    <textarea name="su_twitter" id="su_twitter" rows="3" cols="60" $supr_dis
      onKeyDown="countChars()" onKeyUp="countChars()">$supr_text</textarea>
    
    <div class="supr-controls">
      <div class="char-counter">
        <span>140</span> characters left
      </div>
      <div class="post pkg">
        <span>Post to:</span>
        <label class="twitter" for="supr-this"><input type="checkbox" name="twitter-this" $twitter_checked id="twitter-this" value="1"  /> Twitter</label>
        <label class="fb" for="fb-this"><input type="checkbox" name="fb-this" $fb_checked id="fb-this" value="1"  /> Facebook</label>
      </div>
HTML
    if ($posted_on) {
	$innerHTML .= <<HTML;
      <div class="posted pkg">
        <p>$postedHTML</p>
        <input type="hidden" name="supr_repost" value="0" />
        <a href="javascript:void(0)" id="supr_repost" onclick="repost()">repost</a>
      </div>
HTML
    }
    $innerHTML .= "    </div>";
    $su_field->innerHTML($innerHTML);
    $tmpl->insertAfter( $su_field, $kw_field )
      or return $app->error('failed to insertAfter.');

    if ($entry) {
	my $title_field = $tmpl->getElementById('title')
	    or return $app->error('cannot get the title block');
	my $urls_field = $tmpl->createElement(
					      'app:setting',
					      {
						  id    => 'urls',
						  show_label => 0,
						  label => $app->translate('Post URLs'),
					      }
					      ) or return $app->error('cannot create the URLs element');
	$innerHTML = "<ul>";
	$innerHTML .= '<li class="pkg"><label>URL:</label><span><a href="'.$entry->permalink.'" target="_new">'.
	    $entry->permalink.'</a></span><a class="copy" href="javascript:void(0)"><img src="<$mt:StaticWebPath$>plugins/Supr/copy.png" width="16" height="15" /></a></li>'
	    if ($entry->status == MT->model('entry')->RELEASE());
	$innerHTML .= '<li class="pkg"><label>Short URL:</label><span><a href="'.$entry->supr_url.'" target="_new">'.
	    $entry->supr_url.'</a></span><a class="copy" href="javascript:void(0)"><img src="<$mt:StaticWebPath$>plugins/Supr/copy.png" width="16" height="15" /></a></li>'
	    if ($entry->supr_url);
	$innerHTML .= "</ul>";
	
	$urls_field->innerHTML($innerHTML);
	$tmpl->insertAfter( $urls_field, $title_field )
	    or return $app->error('failed to insertAfter.');
    }

    $param;
}

sub _str_replace {
    my $replace_this = shift;
    my $with_this  = shift; 
    my $string   = shift;

    MT->log("Replacing $replace_this with $with_this");
    
    my $length = length($string);
    my $target = length($replace_this);
    
    for(my $i=0; $i<$length - $target + 1; $i++) {
	if(substr($string,$i,$target) eq $replace_this) {
	    $string = substr($string,0,$i) . $with_this . substr($string,$i+$target);
	    return $string; #Comment this if you what a global replace
	}
    }
    return $string;
}

1;
