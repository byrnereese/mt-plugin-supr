# $Id: Supr.pm 110 2009-03-22 21:04:27Z mthacks $
# $Author: mthacks $
# $Date: 2009-11-09 02:34:27 +0530 (Mon, 23 Mar 2009) $
# Author: 
################################################################################################################################
package WWW::Shorten::Supr;

use warnings;
use strict;
use Carp;

use base qw( WWW::Shorten::generic Exporter );

use JSON::Any;

require XML::Simple;
require Exporter;

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(new version);

my @ISA = qw(Exporter);

use vars qw( @ISA @EXPORT );


=head1 NAME

WWW::Shorten::Supr - Interface to shortening URLs using L<http://su.pr>

=head1 VERSION

$Revision: 0.50 $

=cut

BEGIN {
    our $VERSION = do { my @r = (q$Revision: 0.50 $ =~ /\d+/g); sprintf "%1d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker
    $WWW::Shorten::Supr::VERBOSITY = 2;
}

# ------------------------------------------------------------


=head1 SYNOPSIS

WWW::Shorten::Supr provides an easy interface for shortening URLs using http://su.pr. In addition to shortening URLs, you can pull statistics that su.pr gathers regarding each shortened url
WWW::Shorten::Supr uses XML::Simple to convert the xml response for the meta info and click stats to create a hashref of the results.

WWW::Shorten::Supr provides two interfaces. The first is the common C<makeashorterlink> and C<makealongerlink> that WWW::Shorten provides. However, due to the way the su.pr API works, additional arguments are required. The second provides a better way of retrieving additional information and statistics about a su.pr URL.

use WWW::Shorten::Supr;

my $url = "http://www.example.com";

my $tmp = makeashorterlink($url, 'MY_SUPR_USERNAME', 'MY_SUPR_API_KEY');
my $tmp1 = makealongerlink($tmp, 'MY_SUPR_USERNAME', 'MY_SUPR_API_KEY');

or

use WWW::Shorten::Supr;

my $url = "http://www.example.com";
my $supr = WWW::Shorten::Supr->new(URL => $url,
USER => "my_user_id",
APIKEY => "my_api_key");

$supr->shorten(URL => $url);
print "shortened URL is $supr->{suprurl}\n";

$supr->expand(URL => $supr->{suprurl});
print "expanded/original URL is $supr->{longurl}\n";


=head1 FUNCTIONS

=head2 new

Create a new su.pr object using your su.pr user id and su.pr api key.

my $supr = WWW::Shorten::Supr->new(URL => "http://www.example.com/this_is_one_example.html",
USER => "supr_user_id",
APIKEY => "supr_api_key");

=cut

sub new {
    my ($class) = shift;
    my %args = @_;
	$args{source} = 'perlsuprmod';
    if (!defined $args{USER} || !defined $args{APIKEY}) {
        carp("USER and APIKEY are both required parameters.\n");
        return -1;
    }
    my $supr;
    $supr->{USER} = $args{USER};
    $supr->{APIKEY} = $args{APIKEY};
    $supr->{BASE} = "http://su.pr/api";
    $supr->{json} = JSON::Any->new;
    $supr->{browser} = LWP::UserAgent->new(agent => $args{source});
    $supr->{xml} = new XML::Simple(SuppressEmpty => 1);
    my ($self) = $supr;
    bless $self, $class;
}


=head2 makeashorterlink

The function C<makeashorterlink> will call the su.pr API site passing it
your long URL and will return the shorter su.pr version.

=cut

sub makeashorterlink #($;%)
{
    my $url = shift or croak('No URL passed to makeashorterlink');
    my ($user, $apikey) = @_; # or croak('No username or apikey passed to makeshorterlink');
#    if (!defined $url || !defined $user || !defined $apikey ) {
#        croak("url, user and apikey are required for shortening a URL with su.pr - in that specific order");
#        &help();
#    }
    my $ua = __PACKAGE__->ua();
    my $supr;
    $supr->{json} = JSON::Any->new;
    $supr->{xml} = new XML::Simple(SuppressEmpty => 1);
    my $supurl = "http://su.pr/api/shorten";
    $supr->{response} = $ua->post($supurl, [
        'version' => '1.0',
        'longUrl' => $url,
        'login' => $user,
        'apiKey' => $apikey,
    ]);
    $supr->{response}->is_success || die 'Failed to get su.pr link: ' . $supr->{response}->status_line;
    $supr->{suprurl} = $supr->{json}->jsonToObj($supr->{response}->{_content})->{results}->{$url}->{shortUrl};
    return unless $supr->{response}->is_success;
    return $supr->{suprurl};
}

=head2 makealongerlink

The function C<makealongerlink> does the reverse. C<makealongerlink>
will accept as an argument either the full su.pr URL or just the
su.pr identifier. 

If anything goes wrong, then the function will return C<undef>.

=cut

sub makealongerlink #($,%)
{
    my $url = shift or croak('No shortened su.pr URL passed to makealongerlink');
    my ($user, $apikey) = @_; # or croak('No username or apikey passed to makealongerlink');
    my $ua = __PACKAGE__->ua();
    my $supr;
    my @foo = split(/\//, $url);
    $supr->{json} = JSON::Any->new;
    $supr->{xml} = new XML::Simple(SuppressEmpty => 1);
    $supr->{response} = $ua->post('http://su.pr/api/expand', [
        'version' => '1.0',
        'shortUrl' => $url,
        'login' => $user,
        'apiKey' => $apikey,
    ]);
    $supr->{response}->is_success || die 'Failed to get su.pr link: ' . $supr->{response}->status_line;
    $supr->{longurl} = $supr->{json}->jsonToObj($supr->{response}->{_content})->{results}->{$foo[3]}->{longUrl};
    return undef unless $supr->{response}->is_success;
    my $content = $supr->{response}->content;
# return undef if $content eq 'ERROR';
    return $supr->{longurl};
}

=head2 shorten

Shorten a URL using http://su.pr. Calling the shorten method will return the shortened URL but will also store it in su.pr object until the next call is made.

my $url = "http://www.example.com";
my $shortstuff = $supr->shorten(URL => $url);

print "supurl is " . $supr->{suprurl} . "\n";
or
print "supurl is $shortstuff\n";

=cut


sub shorten {
    my $self = shift;
    my %args = @_;
    if (!defined $args{URL}) {
        croak("URL is required.\n");
        return -1;
    }
    $self->{response} = $self->{browser}->post($self->{BASE} . '/shorten', [
        'version' => '1.0',
        'longUrl' => $args{URL},
        'login' => $self->{USER},
        'apiKey' => $self->{APIKEY},
    ]);
    $self->{response}->is_success || die 'Failed to get su.pr link: ' . $self->{response}->status_line;
    return undef if ( $self->{json}->jsonToObj($self->{response}->{_content})->{errorCode} != 0 );
    $self->{suprurl} = $self->{json}->jsonToObj($self->{response}->{_content})->{results}->{$args{URL}}->{shortUrl};
    return $self->{suprurl} if ( $self->{json}->jsonToObj($self->{response}->{_content})->{errorCode} == 0 );
}

=head2 expand

Expands a shortened su.pr URL to the original long URL.

=cut
sub expand {
    my $self = shift;
    my %args = @_;
    if (!defined $args{URL}) {
        croak("URL is required.\n");
        return -1;
    }
    my @foo = split(/\//, $args{URL});
    $self->{response} = $self->{browser}->get($self->{BASE} . '/expand', [
        'version' => '1.0',
        'shortUrl' => $args{URL},
        'login' => $self->{USER},
        'apiKey' => $self->{APIKEY},
    ]);
    $self->{response}->is_success || die 'Failed to get su.pr link: ' . $self->{response}->status_line;
    return undef if ( $self->{json}->jsonToObj($self->{response}->{_content})->{errorCode} != 0 );
    $self->{longurl} = $self->{json}->jsonToObj($self->{response}->{_content})->{results}->{$foo[3]}->{longUrl};
    return $self->{longurl} if ( $self->{json}->jsonToObj($self->{response}->{_content})->{errorCode} == 0 );
}


=head2 post

Post Su.pr converted messages to associated services such as Twitter and Facebook. Authentication is required for this API. 

my $msg = "Check out this page http://www.example.com/this_is_cool.html";
my @services = ('twitter', 'facebook');
my $suprpost = $supr->post(msg => $msg, services => \@services);

print "suprmsg is " . $suprpost->{suprmsg} . "\n";

=cut


sub post {
    my $self = shift;
    my %args = @_;
    if (!defined $args{msg}) {
        croak("msg is required.\n");
        return -1;
    }
    $self->{response} = $self->{browser}->post($self->{BASE} . '/post', [
        'version' => '1.0',
        'msg' => $args{msg},
        'login' => $self->{USER},
        'apiKey' => $self->{APIKEY},
		$args{services} ? ( 'services[]' => $args{services} ) : (),
    ]);
    $self->{response}->is_success || die 'Failed to get su.pr msg: ' . $self->{response}->status_line;
    return undef if ( $self->{json}->jsonToObj($self->{response}->{_content})->{errorCode} != 0 );
    $self->{suprmsg} = $self->{json}->jsonToObj($self->{response}->{_content})->{results}->{shortMsg};
    return $self->{suprmsg} if ( $self->{json}->jsonToObj($self->{response}->{_content})->{errorCode} == 0 );
}

=head2 version

Gets the module version number

=cut
sub version {
    my $self = shift;
    my($version) = shift;# not sure why $version isn't being set. need to look at it
    warn "Version $version is later then $WWW::Shorten::Supr::VERSION. It may not be supported" if (defined ($version) && ($version > $WWW::Shorten::Supr::VERSION));
    return $WWW::Shorten::Supr::VERSION;
}#version


=head1 AUTHOR

Mark Carey, C<< <mark at mt-hacks.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-shorten-supr at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Shorten-Supr>. I will
be notified, and then you'll automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc WWW::Shorten::Supr


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Shorten-Supr>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Shorten-Supr>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Shorten-Supr>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Shorten-Supr/>

=back


=head1 ACKNOWLEDGEMENTS

=over

=item http://su.pr for a wonderful service.


=back

=head1 COPYRIGHT & LICENSE

=over

=item Copyright (c) 2009 Mark Carey, All Rights Reserved L<http://mt-hacks.com>.

=back

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=head1 SEE ALSO

L<perl>, L<WWW::Shorten>, L<http://su.pr>.

=cut

1; # End of WWW::Shorten::Supr