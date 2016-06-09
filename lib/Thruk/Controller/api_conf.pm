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
	my %pagetypes = (
		'hosts' => 'Hosts', 
		'hostdependencies' => 'Host Dependencies',
		'hostescalations' => 'Host Escalations', 
		'hostgroups' => 'Host Groups',
		'services' => 'Services',
		'servicegroups' => 'Service Groups',
		'servicedependencies' => 'Service Dependencies',
		'serviceescalations' => 'Service Escalations',
		'contacts' => 'Contacts',
		'contactgroups' => 'Contact Groups',
		'timeperiods' => 'Timeperiods',
		'commands' =>'Commands',
	);

	my $landing_page = '<br><br>';
	$landing_page .= '<div class="reportSelectTitle" align="center">Select Type of Config Data You Wish To Edit</div>';
	$landing_page .= '<br>';
	$landing_page .= '<br>';
	$landing_page .= $q->start_form(-method=>"POST",
		    -action=>"api_conf.cgi");
	$landing_page .= '<div align="center">';
	$landing_page .= '<table border="0">';
	$landing_page .= '<tbody>';
	$landing_page .= '<tr>';
	$landing_page .= '<td class="reportSelectSubTitle" align="left">Object Type:</td>';
	$landing_page .= '</tr>';
	$landing_page .= '<tr>';
	$landing_page .= '<td class="reportSelectItem" align="left">';
	$landing_page .= '<select name="page_type">';
	foreach my $type ( sort keys %pagetypes ) {
		$landing_page .= "<option value=\"$type\">$pagetypes{$type}</option>";
	}
	$landing_page .= '</select">';
	$landing_page .= '</td>';
	$landing_page .= '</tr>';
	$landing_page .= '<tr>';
	$landing_page .= '<td class="reportSelectItem" >';
	$landing_page .= $q->submit(-name=>'continue',
			-value=>'Continue');
	$landing_page .=  $q->end_form;
	$landing_page .= '</td>';
	$landing_page .= '</tr>';
	$landing_page .= '</tbody>';
	$landing_page .= '</table>';
	$landing_page .= '</div>';

	return $landing_page;
}

sub hosts {
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
	my $api_realm = $config->get('realm');
	my $api_host = $config->get('host');
	my $api_port = $config->get('port');
	my $api_delete_url = "https://$api_host:$api_port/v1/objects/hosts/$host?cascade=1";
	my $ua = LWP::UserAgent->new( ssl_opts => {verify_hostname => 0 } );
	$ua->default_header('Accept' => 'application/json');
	$ua->credentials("$api_host:$api_port", $api_realm, $api_user, $api_password);

	# Get hosts
	my @temp_arr;
	for my $hashref (values $c->stash->{hosts}) {
        	push @temp_arr,  $hashref->{name};
	}
	my @host_arr = sort @temp_arr;

	# This case is first dialog
	if (not defined($confirm) and $host  =~ m/\..*\./  ) {
		 $host_page .= $q->h1('Delete Host');         # level 1 header
		 $host_page .= $q->p('Are you sure you want to delete '. $host .'?<br/>');
		 $host_page .= $q->start_form(-method=>"POST",
			    -action=>"api_conf.cgi");
		 $host_page .= $q->hidden('host',$host);
		 $host_page .= $q->hidden('page_type',"hosts");
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
	}

	else {
		$host_page .= $q->h1('Delete Host');         # level 1 header
		$host_page .= $q->p('Enter host to delete');
		$host_page .= $q->start_form(-method=>"GET",
			    -action=>"api_conf.cgi");
		#$host_page .= $q->textfield(-name=>'host',-size=>50,-maxlength=>100);
		$host_page .= '<select name="host">';
		for my $ho ( @host_arr ) {
			$host_page .= "<option value=\"$ho\">$ho</option>";
		}
		$host_page .= '</select">';
		$host_page .= $q->hidden('page_type',"hosts");
		$host_page .= $q->submit(-name=>'submit',
				-value=>'Submit');
		$host_page .=  $q->end_form;
	}
	return $host_page;
}

sub host_groups {
	return "Host Groups Placeholder";
}

sub host_escalations {
	return "Host Groups Placeholder";
}

sub host_dependencies {
	return "Host Groups Placeholder";
}

sub services {
	use JSON::XS qw(encode_json decode_json);
	use File::Slurp qw(read_file write_file);
	use Data::Dumper;

	my ($c) = @_; 

        # Get services
	my %check = ();
	foreach my $hash ($c->stash->{services} ) {
		foreach my $service (values $hash) {
			$check{ $service->{host_name} }{$service->{display_name} } =  $service->{check_command} ;
		}
	}
	my $service_page = '';
	foreach my $service_host (keys %check ) {
		$service_page .= "<p>$service_host</p>";
		$service_page .= "<ul>";
		foreach my $checks ( keys $check{$service_host}) {
			$service_page .= "<li>$checks: $check{$service_host}{$checks}</li>";
		}
		$service_page .= "</ul>";
			
	}
	return $service_page;
}

sub service_groups {
	return "Service Groups Placeholder";
}

sub contacts {
	return "Contacts Placeholder";
}

sub contact_groups {
	return "Contact Groups Placeholder";
}

sub timeperiods {
	return "Timeperiods Placeholder";
}

sub commands {
	return "Commands Placeholder";
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
	if ($page_type eq "hosts") {
		$body = hosts $c;
	} elsif ($page_type eq "hostgroups") {
		$body = host_groups $c;
	} elsif ($page_type eq "hostescalations") {
		$body = host_groups $c;
	} elsif ($page_type eq "hostdependencies") {
		$body = host_groups $c;
	} elsif ($page_type eq "services") {
		$body = services $c;
	} elsif ($page_type eq "servicegroups") {
		$body = service_groups $c;
	} elsif ($page_type eq "contacts") {
		$body = contacts $c;
	} elsif ($page_type eq "contactgroups") {
		$body = contact_groups $c;
	} elsif ($page_type eq "timeperiods") {
		$body = timeperiods $c;
	} elsif ($page_type eq "commands") {
		$body = commands $c;
	} else {
		$body = selector;
	}
	return $body;
}

sub index {
	my ( $c ) = @_;
	$c->stash->{readonly}        = 0;
	$c->stash->{title}           = 'API Conf';
	$c->stash->{subtitle}              = 'API Conf';
	$c->stash->{infoBoxTitle}          = 'API Conf';
	$c->stash->{'no_auto_reload'}      = 1;
	$c->stash->{template} = 'api_conf.tt';
	$c->stash->{testmode} = 1;
	$c->stash->{services} = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services')]); 
	$c->stash->{hosts} = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts')]); 
	$c->stash->{commands} = $c->{'db'}->get_commands(); 
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
