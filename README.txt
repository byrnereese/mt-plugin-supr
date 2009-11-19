Installation Instructions for self-hosted URLs:

1. Checked the "My own short-urls" checkbox in plugin settings.

2. Please add these lines to your rewrite.conf or .htaccess:

<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule ^[a-zA-Z0-9]{1,4}$ /mt-static/plugins/Supr/php/supr.php?supr=$0&blog_id=<mt:BlogID>&cgipath=<mt:CGIServerPath>
RewriteRule ^supr_settings.json$ /mt-static/plugins/Supr/php/supr.php?check_install=$0&blog_id=<mt:BlogID>&cgipath=<mt:CGIServerPath>
</IfModule>

Note that the above URLs contain MT template tags.  It is recommended that you create an index template to build 
your .htaccess so that these template tags gets built.  Alternatively you can subsitute the tags for the 
appropriate values and paste into your existing .htaccess file.  You also may need modify the relative URL to 
your 'mt-static' directory if it is something other than '/mt-static/'.  

***TODO:  make this part easier by pre-building rules in some way.***

3. Visit http://su.pr/settings/ and enter your domain to the list of promoted websites.  Click Save and you 
should see the updated settings for your domain. Then click the "Synchronize" link. Once the 
features are enabled in your settings page, you are ready to go! Try to shorten a URL for web page on your 
website and you should have your very own short URL! 

4. Get more traffic with the Supr bar

To receive more traffic from StumbleUpon, be sure to display the Supr bar when visitors click on a Su.pr short
URL on your domain.  The bar will only be displayed to visitors that click on a Su.pr link (it will not be 
displayed to visitors that come to your website from other sources).

Simply add the following link to your header portion of your web page (usually in a header template file):

<script src="http://su.pr/hosted_js" type="text/javascript"></script>