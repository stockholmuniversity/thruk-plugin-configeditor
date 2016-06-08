package Thruk::Controller::api_conf;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::api_conf - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

BEGIN {
    #use Thruk::Timer qw/timing_breakpoint/;
}


##########################################################
use CGI;
use HTTP::Request::Common;
use LWP::UserAgent;
use LWP::Protocol::https;
use Config::JSON;

use Net::SSLGlue::LWP;
use IO::Socket::SSL;
use Data::Dumper;
=head2 index
=head2 body
=cut

sub body {
	my ($c) = @_; 
	my $body = '';

	my $context = new IO::Socket::SSL::SSL_Context(
	  SSL_version => 'tlsv1',
	  SSL_verify_mode => Net::SSLeay::VERIFY_NONE(),
	  );
	IO::Socket::SSL::set_default_context($context);

	# Read config file
	my $config_file = "/local/icinga2/conf/api-credentials.json";
	my $config = Config::JSON->new($config_file);

	# Set up cgi
	my $q = CGI->new;
	my $params = $c->req->parameters;
	#Get host and see if this is the delete request or not
	my $host = $params->{'host'};
	my $confirm = $params->{'confirm'};

	# Setting up for api call
	my $api_user = $config->get('user');
	my $api_password = $config->get('password');
	my $api_realm = "Icinga 2";
	my $api_host = "icinga-lab.it.su.se";
	my $api_port = "5665";
	my $api_delete_url = "https://$api_host:$api_port/v1/objects/hosts/$host?cascade=1";
	my $ua = LWP::UserAgent->new( ssl_opts => {verify_hostname => 0 } );
	$ua->default_header('Accept' => 'application/json');
	$ua->credentials("$api_host:$api_port", $api_realm, $api_user, $api_password);


	# This case is first dialog
	if (not defined($confirm) and $host  =~ m/\..*\./  ) {
		 $body .= $q->h1('Delete Host');         # level 1 header
		 $body .= $q->p('Are you sure you want to delete '. $host .'?<br/>If not, just close this page.<br/>');
		 $body .= $q->start_form(-method=>"POST",
			    -action=>"api_conf.cgi");
		 $body .= $q->hidden('host',$host);
		 $body .= $q->submit(-name=>'confirm',
				-value=>'Confirm');
		$body .=  $q->end_form;

	}

	# This case is delete request
	elsif ($confirm eq "Confirm" and $host  =~ m/\..*\./  ) {
		my $req = HTTP::Request->new(DELETE => $api_delete_url);
		my $response = $ua->request($req);
		$body .= $q->p("Close this window, result from API was:");
		$body .= $q->p($response->decoded_content);
		#$body .= "<script \"text/javascript\">window.location = \"$c->HTTP_COOKIE->HTTP_REFERER\"</script>";
	}

	# This is a misspeld hostname, i.e someone is url hacking
	#elsif ( ! $host  =~ m/\..*\./ ) {
	#	 $body .= $q->h1('Host name incorrect');
	#	 $body .= $q->p("Close this window and try again");
	#}
	else {
		 $body .= $q->h1('Delete Host');         # level 1 header
		 $body .= $q->p('Enter host to delete');
		 $body .= $q->start_form(-method=>"GET",
			    -action=>"api_conf.cgi");
		 $body .= $q->textfield(-name=>'host',-size=>50,-maxlength=>100);
		 $body .= $q->submit(-name=>'submit',
				-value=>'Submit');
		$body .=  $q->end_form;
	}
	$body .=  Dumper $c->cookie();
	return $body;
}

sub index {
	my ( $c ) = @_;
	$c->stash->{readonly}        = 0;
	$c->stash->{title}           = 'API Conf';
	$c->stash->{'extjs_version'} = "6.0.1";
	$c->stash->{template} = 'api_conf.tt';
	$c->stash->{testmode} = 1;
	$c->stash->{body} = body $c;
}
=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
