<?php // $Id
/*
Installation Instructions:
1. Upload supr.php to your website's root director
2. Please add these lines to your rewrite.conf or .htaccess:

<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule ^[a-zA-Z0-9]{1,4}$ supr.php?supr=$0&blog_id=<mt:BlogID>&cgipath=<mt:CGIServerPath>
RewriteRule ^supr_settings.json$ supr.php?check_install=$0&blog_id=<mt:BlogID>&cgipath=<mt:CGIServerPath>
</IfModule>

*/

global $cgipath;
// $blog_id = <mt:BlogID>;
// $cgipath = "<mt:CGIServerPath>";
$blog_id = $_GET['blog_id'];
$cgipath = $_GET['cgipath'];

include("$cgipath/php/mt.php");
$mt = new MT($blog_id, "$cgipath/mt-config.cgi");
$ctx = &$mt->context();
$config = $ctx->mt->db->fetch_plugin_config('Supr', 'blog:' . $blog_id);
$login = $config['supr_username'];
$apikey = $config['supr_apikey'];
$blog = $ctx->mt->db->fetch_blog($blog_id);
$domain = $blog['blog_site_url'];

// supr CONFIG : replace with your info //
// $domain = "<mt:BlogURL>";
// $login = "myusername";
// $apikey = "xxxxxxx";


define('USER_AGENT', 'SuprMTPlugin');
require_once("$cgipath/plugins/Supr/php/extlib/urlopen.php");

if ( !function_exists('json_decode') ){
   require_once("$cgipath/plugins/Supr/php/extlib/JSON.php");
   function json_decode($content, $assoc=false){
      if ( $assoc ){
          $json = new Services_JSON(SERVICES_JSON_LOOSE_TYPE);
      } else {
          $json = new Services_JSON;
      }
      return $json->decode($content);
   }
}

if ( !function_exists('json_encode') ){
    require_once("$cgipath/plugins/Supr/php/extlib/JSON.php");
    function json_encode($content){
        $json = new Services_JSON;
        return $json->encode($content);
    }
}

function supr_check_install()
{
	$headers = new stdClass;
	$headers->version = "1";
	$headers->is_301 = "1"; // set to 1 for search engine redirects for your short URLs
	$headers->is_shorturl = "1";  // set to 1 for short URLs on your own domain. 0 to turn this off
	$settings = json_encode($headers);
	print $settings;
	exit();
}

// Do not edit below this line //

function immediate_redirect($url)
{
	header("Location: $url");
	header("Content-Length: 0");
	header("Connection: close");
	flush();
}


if(isset($_GET['check_install']))
{
	supr_check_install();
}

if (isset($_GET['supr']))
	$hash = $_GET['supr'];
else
	immediate_redirect($domain);

$url = "http://su.pr/api/forward?domain=".urlencode($domain)."&hash=".$hash."&login=".$login."&apiKey=".$apikey;

$response = @urlopen($url);
$data = $response['data'];
$results = json_decode($data, true);
if (isset($results['results'][$hash]['forwardUrl']))
	$redir = $results['results'][$hash]['forwardUrl'];
else
	$redir = $domain;

immediate_redirect($redir);
?>