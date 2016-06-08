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

sub selector {
	my $q = CGI->new;
	my $landing_page = '';
	$landing_page .= $q->h1('Select Type of Config Data You Wish To Edit or View');         # level 1 header
	$landing_page .= $q->p('Object Type:');
	$landing_page .= $q->start_form(-method=>"POST",
		    -action=>"api_conf.cgi");
	$landing_page .= $q->scrolling_list('page_type', ['Hosts','Host Groups','Services','Service Groups','Contacts','Contact Groups','Timeperiods','Commands'], 8, "false");
	$landing_page .= $q->submit(-name=>'submit',
			-value=>'Submit');
	$landing_page .=  $q->end_form;

	return $landing_page;
}

sub host {
	my ($c) = @_; 
	my $host_page = '';

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
		 $host_page .= $q->h1('Delete Host');         # level 1 header
		 $host_page .= $q->p('Are you sure you want to delete '. $host .'?<br/>');
		 $host_page .= $q->start_form(-method=>"POST",
			    -action=>"api_conf.cgi");
		 $host_page .= $q->hidden('host',$host);
		 $host_page .= $q->hidden('page_type',"Hosts");
		 $host_page .= $q->submit(-name=>'confirm',
				-value=>'Confirm');
		$host_page .=  $q->end_form;

	}

	# This case is delete request
	elsif ($confirm eq "Confirm" and $host  =~ m/\..*\./  ) {
		my $req = HTTP::Request->new(DELETE => $api_delete_url);
		my $response = $ua->request($req);
		$host_page .= $q->p("Result from API was:");
		$host_page .= $q->p($response->decoded_content);
		#$host_page .= "<script \"text/javascript\">window.location = \"$c->HTTP_COOKIE->HTTP_REFERER\"</script>";
	}

	else {
		 $host_page .= $q->h1('Delete Host');         # level 1 header
		 $host_page .= $q->p('Enter host to delete');
		 $host_page .= $q->start_form(-method=>"GET",
			    -action=>"api_conf.cgi");
		 $host_page .= $q->textfield(-name=>'host',-size=>50,-maxlength=>100);
		 $host_page .= $q->submit(-name=>'submit',
				-value=>'Submit');
		$host_page .=  $q->end_form;
	}
	$host_page .=  Dumper $c->cookie();
	return $host_page;
}

sub body {
	my $context = new IO::Socket::SSL::SSL_Context(
	  SSL_version => 'tlsv1',
	  SSL_verify_mode => Net::SSLeay::VERIFY_NONE(),
	  );
	IO::Socket::SSL::set_default_context($context);

	my ($c) = @_; 
	my $body = '';
        my $params = $c->req->parameters;
	my $page_type = $params->{'page_type'};	
	if ($page_type eq "Hosts") {
		$body = host $c;
	} else {
		$body = selector;
	}
	return $body;
}

sub index {
	my ( $c ) = @_;
	$c->stash->{readonly}        = 0;
	$c->stash->{title}           = 'API Conf';
	$c->stash->{template} = 'api_conf.tt';
	$c->stash->{testmode} = 1;
	if( !$c->check_user_roles("authorized_for_configuration_information")
        || !$c->check_user_roles("authorized_for_system_commands")) {
		$c->stash->{body} = "<h1>You are not authorized to access this page!</h1>";
	} else {
		$c->stash->{body} = body $c;
	}
}
=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
