package Thruk::Controller::api_conf;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::api_conf - Thruk Controller via Icinga2 API

=head1 DESCRIPTION

Thruk Controller making use of Icinga2 API.

=head1 METHODS

=head2 index

This is the entry point 

=head2 selector

This displays the main scroll list och different type of objects

=head2 body

Some common initializations and setting main body variable for the template

=cut

BEGIN {
    # Not in use yet;
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
use JSON::XS qw(encode_json decode_json);

sub selector {
	my $q = CGI->new;
	my %pagetypes = (
		'hosts' => 'Hosts', 
	#	'hostdependencies' => 'Host Dependencies',
	#	'hostescalations' => 'Host Escalations', 
	#	'hostgroups' => 'Host Groups',
		'services' => 'Services',
	#	'servicegroups' => 'Service Groups',
	#	'servicedependencies' => 'Service Dependencies',
	#	'serviceescalations' => 'Service Escalations',
	#	'contacts' => 'Contacts',
	#	'contactgroups' => 'Contact Groups',
	#	'timeperiods' => 'Timeperiods',
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

	# Set up cgi
	my $q = CGI->new;
	my $params = $c->req->parameters;
	#Get host and see if this is the delete request or not
	my $host = $params->{'host'};
	my $confirm = $params->{'confirm'};
	my $cascading = $params->{'cascading'};

	# Read config file
	my $config_file = "/local/icinga2/conf/api-credentials.json";
	my $config = Config::JSON->new($config_file);

	# Setting up for api call
	my $api_user = $config->get('user');
	my $api_password = $config->get('password');
	my $api_realm = $config->get('realm');
	my $api_host = $config->get('host');
	my $api_port = $config->get('port');
	my $api_url = "https://$api_host:$api_port/v1/objects/hosts/$host";
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
                $host_page .= $q->checkbox('cascading',0,'true','Use cascading delete - WARNING');
		$host_page .= $q->submit(-name=>'confirm',
				-value=>'Confirm');
		$host_page .=  $q->end_form;

	}

	# This case is delete request
	elsif ($confirm eq "Confirm" and $host  =~ m/\..*\./  ) {
		if ($cascading eq "true") {
			$api_url .= '?cascade=1';
		}
		my $req = HTTP::Request->new(DELETE => $api_url);
		my $response = $ua->request($req);
		my @arr = decode_json $response->decoded_content;
		$host_page .= $q->p("Result from API was:");
		$host_page .= $q->p($arr[0]{results}[0]{status});
		$host_page .= $q->p($arr[0]{results}[0]{errors});
	}

	else {
		$host_page .= $q->h1('Delete Host');
		$host_page .= $q->p('Enter host to delete');
		$host_page .= $q->start_form(-method=>"POST",
			    -action=>"api_conf.cgi");
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
	my ($c) = @_; 
	my $q = CGI->new;
	my $params = $c->req->parameters;

	#Get host and see if this is the delete request or not
	my $host = $params->{'host'};
	my $confirm = $params->{'confirm'};
	my $submit = $params->{'submit'};
	my $service = $params->{'service'};

	# Read config file
	my $config_file = "/local/icinga2/conf/api-credentials.json";
	my $config = Config::JSON->new($config_file);

	# Setting up for api call
	my $api_user = $config->get('user');
	my $api_password = $config->get('password');
	my $api_realm = $config->get('realm');
	my $api_host = $config->get('host');
	my $api_port = $config->get('port');
	my $api_url = "https://$api_host:$api_port/v1/objects/services/$host!$service";
	my $ua = LWP::UserAgent->new( ssl_opts => {verify_hostname => 0 } );
	$ua->default_header('Accept' => 'application/json');
	$ua->credentials("$api_host:$api_port", $api_realm, $api_user, $api_password);

        # Get services
	my %check = ();
	foreach my $hash ($c->stash->{services} ) {
		foreach my $service (values $hash) {
			$check{ $service->{host_name} }{$service->{display_name} } =  $service->{check_command} ;
		}
	}
	my $service_page = '';

	$service_page .= $q->h1('Services');         # level 1 header
	if ( $host  =~ m/\..*\./ and not defined($confirm) and not $service =~ m/.+/ ) {
               $service_page .= $q->p("Enter service to modify for host: $host ");
               $service_page .= $q->start_form(-method=>"POST",
                           -action=>"api_conf.cgi");
               $service_page .= '<select name="service">';
               foreach my $checks ( sort keys $check{$host}) {
			$service_page .= "<li>$checks: $check{$host}{$checks}</li>";
			$service_page .= "<option value=\"$checks\">$check{$host}{$checks}</option>";
               }
               $service_page .= '</select">';
               $service_page .= $q->hidden('page_type',"services");
               $service_page .= $q->hidden('host',$host);
               $service_page .= $q->submit(-name=>'submit',
                               -value=>'Submit');
               $service_page .=  $q->end_form;
	} elsif ( $host  =~ m/\..*\./ and not defined($confirm) and $service =~ m/.+/ ) {
               $service_page .= $q->p('Are you sure you want to delete ' . $service . ' for host: ' . $host .'?<br/>');
               $service_page .= $q->start_form(-method=>"POST",
                            -action=>"api_conf.cgi");
               $service_page .= $q->hidden('host',$host);
               $service_page .= $q->hidden('page_type',"services");
               $service_page .= $q->hidden('service',$service);
               $service_page .= $q->submit(-name=>'confirm',
                                -value=>'Confirm');
               $service_page .=  $q->end_form;
	} elsif ( $host  =~ m/\..*\./ and $confirm  eq "Confirm" and $service =~ m/.+/ ) {
                my $req = HTTP::Request->new(DELETE => $api_url);
                my $response = $ua->request($req);
		my @arr = decode_json $response->decoded_content;
		$service_page .= $q->p("Result from API was:");
		$service_page .= $q->p($arr[0]{results}[0]{status});
		$service_page .= $q->p($arr[0]{results}[0]{errors});
	} else {
		$service_page .= $q->p('Enter host to modify');
		$service_page .= $q->start_form(-method=>"POST",
			    -action=>"api_conf.cgi");
		$service_page .= '<select name="host">';
		foreach my $service_host (sort keys %check ) {
			$service_page .= "<option value=\"$service_host\">$service_host</option>";
				
		}
		$service_page .= '</select">';
		$service_page .= $q->hidden('page_type',"services");
		$service_page .= $q->submit(-name=>'submit',
				-value=>'Submit');
		$service_page .=  $q->end_form;
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
	my ($c) = @_; 
	my $q = CGI->new;
	my $params = $c->req->parameters;

	#Get command and see if this is the delete request or not
	my $confirm = $params->{'confirm'};
	my $command = $params->{'command'};
	my $commandline = $params->{'commandline'};
	my $cascading = $params->{'cascading'};
	my $mode = $params->{'mode'};
	my $submit = $params->{'submit'};

	# Read config file
	my $config_file = "/local/icinga2/conf/api-credentials.json";
	my $config = Config::JSON->new($config_file);

	# Setting up for api call
	my $api_user = $config->get('user');
	my $api_password = $config->get('password');
	my $api_realm = $config->get('realm');
	my $api_host = $config->get('host');
	my $api_port = $config->get('port');
	my $api_url = "https://$api_host:$api_port/v1/objects/checkcommands/$command";
	my $ua = LWP::UserAgent->new( ssl_opts => {verify_hostname => 0 } );
	$ua->default_header('Accept' => 'application/json');
	$ua->credentials("$api_host:$api_port", $api_realm, $api_user, $api_password);
	my $command_page = '';
	
	if ( $mode eq "delete") {
		if ( not defined($confirm) and  $command =~ m/.+/ ) {
			$command_page .= $q->p('Are you sure you want to delete ' . $command . '?<br/>');
			$command_page .= $q->start_form(-method=>"POST",
				    -action=>"api_conf.cgi");
			$command_page .= $q->hidden('page_type',"commands");
			$command_page .= $q->hidden('command',$command);
			$command_page .= $q->hidden('mode',"delete");
			$command_page .= $q->checkbox('cascading',0,'true','Use cascading delete - WARNING');
			$command_page .= $q->submit(-name=>'confirm',
					-value=>'Confirm');
			$command_page .=  $q->end_form;
		} elsif ( $confirm eq "Confirm" and  $command =~ m/.+/ ) {
			if ($cascading eq "true") {
				$api_url .= '?cascade=1';
			}
			my $req = HTTP::Request->new(DELETE => $api_url);
			my $response = $ua->request($req);
			my @arr = decode_json $response->decoded_content;
			$command_page .= $q->p("Result from API was:");
			$command_page .= $q->p($arr[0]{results}[0]{status});
			$command_page .= $q->p($arr[0]{results}[0]{errors});
		} else {
			$command_page .= $q->p('Enter command to delete');
			$command_page .= $q->start_form(-method=>"POST",
				    -action=>"api_conf.cgi");
			$command_page .= '<select name="command">';
			foreach my $hash (values $c->stash->{commands}) {
				my $name = $hash->{name};
				$name =~ s/check_//g;
				$command_page .= "<option value=\"$name\">$hash->{name}</option>";
			}
			$command_page .= '</select">';
			$command_page .= $q->hidden('page_type',"commands");
			$command_page .= $q->hidden('mode',"delete");
			$command_page .= $q->submit(-name=>'submit',
					-value=>'Submit');
			$command_page .=  $q->end_form;

		}
	} elsif ($mode eq "create") {
		if ($confirm eq "Confirm" and $commandline =~ m/.+/  and  $command =~ m/.+/ ) {
			my $payload = '{ "templates": [ "plugin-check-command" ], "attrs": { "command": [ "' . $commandline . '" ]} }';	
			my $req = HTTP::Request->new(PUT => $api_url);
			$req->add_content( $payload );
			my $response = $ua->request($req);
			my @arr = decode_json $response->decoded_content;
			$command_page .= $q->p("Result from API was:");
			$command_page .= $q->p($arr[0]{results}[0]{status});
			$command_page .= $q->p($arr[0]{results}[0]{errors});
		} elsif ($submit eq "Submit" and $command =~ m/.+/ and $commandline =~ m/.+/ ) {
			$command_page .= $q->p('Are you sure you want to create ' . $command . ' with commandline: ' . $commandline . '?<br/>');
			$command_page .= $q->start_form(-method=>"POST",
				    -action=>"api_conf.cgi");
			$command_page .= $q->hidden('page_type',"commands");
			$command_page .= $q->hidden('command',$command);
			$command_page .= $q->hidden('commandline',$commandline);
			$command_page .= $q->hidden('mode',"create");
			$command_page .= $q->submit(-name=>'confirm',
					-value=>'Confirm');
			$command_page .=  $q->end_form;
		} else {
                        $command_page .= $q->start_form(-method=>"GET",
                            -action=>"api_conf.cgi");
                        $command_page .= $q->p("Enter command name (\"check_\" will be prepended automaticaly):");
                        $command_page .= $q->textfield('command','',50,80);
                        $command_page .= $q->p("Enter commandline to be executed:");
                        $command_page .= $q->textfield('commandline','',50,80);
                        $command_page .= $q->hidden('page_type',"commands");
                        $command_page .= $q->hidden('mode',"create");
                        $command_page .= $q->submit(-name=>'submit',
                                -value=>'Submit');
                	$command_page .=  $q->end_form;
		}
	} else {
		$command_page .= $q->p('Which do you want to do?');
		$command_page .= $q->start_form(-method=>"POST",
			    -action=>"api_conf.cgi");
		$command_page .= '<select name="mode">';
		$command_page .= "<option value=\"create\">Create</option>";
		$command_page .= "<option value=\"delete\">Destroy</option>";
		$command_page .= '</select">';
		$command_page .= $q->hidden('page_type',"commands");
		$command_page .= $q->submit(-name=>'submit',
				-value=>'Submit');
		$command_page .=  $q->end_form;
	}
	return  $command_page;
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
