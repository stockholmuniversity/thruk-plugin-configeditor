package Thruk::Controller::api_conf;
use strict;
use warnings;

=head1 NAME

Thruk::Controller::api_conf - Thruk Controller via Icinga2 API

=head1 DESCRIPTION

Thruk Controller making use of Icinga2 API.

=head1 METHODS

We build our page by using one method per page type, plus some common helper functions 

=cut

BEGIN {
    # Not in use yet;
}
##########################################################
use CGI;
use Config::JSON;
use Data::Dumper;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use File::Basename qw( dirname basename );
use HTML::Entities;
use HTTP::Request::Common;
use IO::Socket::SSL;
use JSON::XS qw(encode_json decode_json);
use JSON;
use LWP::Protocol::https;
use LWP::UserAgent;
use Net::SSLGlue::LWP;
use Test::JSON;
use URI::Escape;

# This is the form method for dialogs, useful to change all for debug purposes
my $METHOD = "GET";

#my $METHOD = "POST";
my @service_keys = (
    "vars",         "action_url", "check_command", "check_interval",
    "display_name", "notes_url",  "event_command"
);
my @command_keys = ( "arguments", "command", "vars" );

my @host_keys = (
    "address6", "address",    "display_name", "event_command",
    "groups",   "action_url", "notes_url",    "vars"
);

=head2 api_call

This function reads api config and makes api calls

=head3 Parameters

=over 

=item *

confdir (typically  $c->stash->{'confdir'} )

=item *

verb (GET, PUT, DELETE, POST)

=item *

endpoint (e.g. objects/hosts/<hostname>)

=item *

payload (optional, {  "attrs": { "check_command": "<command name>", "check_interval": 1,"retry_interval": 1 } })

=back

=cut

sub api_call {
    my ( $confdir, $verb, $endpoint, $payload ) = @_;

    # Read config file
    my $config_file = "$confdir/icinga-api-credentials.json";
    my $config      = Config::JSON->new($config_file);

    # Setting up for api call
    my $api_user     = $config->get('user');
    my $api_password = $config->get('password');
    my $api_realm    = $config->get('realm');
    my $api_host     = $config->get('host');
    my $api_port     = $config->get('port');
    my $api_path     = $config->get('path');
    my $api_url      = "https://$api_host:$api_port/$api_path/$endpoint";
    my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
    $ua->default_header( 'Accept' => 'application/json' );
    $ua->credentials( "$api_host:$api_port", $api_realm, $api_user,
        $api_password );
    my $req = HTTP::Request->new( $verb => $api_url );

    if ($payload) {
        $payload =~ s/&nbsp;/ /g;
        $payload =~ s/\s+/ /g;
        $req->add_content($payload);
    }
    my $response = $ua->request($req);
    return decode_json $response->decoded_content;
}

=head2 csv_from_arr

This function returns a comma seperated string from an array

=head3 Parameters

=over

=item *

array of items

=back

=cut

sub csv_from_arr {
    my $str = '';
    foreach my $s (@_) {
        $str .= $s . ', ';
    }
    $str =~ s/, $//;
    return $str;
}

=head2 display_multi_select

This function returns javascript for multi select

=head3 Parameters

=over

=item *

id for select

=item *

array of items

=back

=cut

sub display_multi_select {
    my ( $id, @items ) = @_;
    my $html = '';

    # Dont try with too many items, or it will fail
    if ( scalar @items > 300 ) {
        $html .=
          '<a href=\'#\' id=\'select-300\'>Select first 300</a><br>' . "\n";
    }
    else {
        $html .= '<a href=\'#\' id=\'select-all\'>Select all</a><br>' . "\n";
    }
    $html .= '<a href=\'#\' id=\'deselect-all\'>Deselect all</a>' . "\n";
    $html .= '<script type="text/javascript">' . "\n";
    $html .= ';(function($) {' . "\n";
    $html .= '$(\'#' . $id . '\').multiSelect({ ' . "\n";
    $html .= 'selectableHeader: "<div>Available items</div>",' . "\n";
    $html .= 'selectionHeader: "<div>Selected items</div>",' . "\n";
    $html .= '});' . "\n";

    if ( scalar @items > 300 ) {
        $html .= '$(\'#select-300\').click(function(){' . "\n";
        $html .= '$(\'#' . $id . '\').multiSelect(\'select\', [';
        foreach my $i ( 0 .. 298 ) {
            $html .= "\'$items[$i]\', ";
        }
        $html .= "\'$items[299]\'";
        $html .= ']);' . "\n";
        $html .= 'return false;' . "\n";
        $html .= '});' . "\n";
    }
    else {
        $html .= '$(\'#select-all\').click(function(){' . "\n";
        $html .= '$(\'#' . $id . '\').multiSelect(\'select_all\');' . "\n";
        $html .= 'return false;' . "\n";
        $html .= '});' . "\n";
    }
    $html .= '$(\'#deselect-all\').click(function(){' . "\n";
    $html .= '$(\'#' . $id . '\').multiSelect(\'deselect_all\');' . "\n";
    $html .= 'return false;' . "\n";
    $html .= '});' . "\n";
    $html .= "})(jQuery);\n";
    $html .= "</script>\n";
    return $html;
}

=head2 display_back_button

This function returns the back button

=head3 Parameters

=over

=item * 

mode 

=item * 

page_type 

=back

=cut

sub display_back_button {
    my $mode = shift;
    my ($page_type) = @_;

    # A cgi object to help with some html creation
    my $q    = CGI->new;
    my $page = $q->p('Go back?');
    $page .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $page .= $q->hidden( 'page_type', "$page_type" );
    $page .= $q->hidden( 'mode',      "$mode" );
    $page .= $q->submit(
        -name  => 'return',
        -value => 'Return'
    );
    $page .= $q->end_form;
    return $page;
}

=head2 display_create_delete_modify_dialog

This function returns the create/delete dialog

=head3 Parameters

=over

=item * 

page_type 

=back

=cut

sub display_create_delete_modify_dialog {
    my ($page_type) = @_;

    # Show modify option for only these pagetypes
    #	my @display_modify_arr = ("hostgroups");
    my @display_modify_arr = ( "commands", "hosts", "services" );

    # A cgi object to help with some html creation
    my $q    = CGI->new;
    my $page = $q->p('What do you want to do?');
    $page .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $page .= '<select name="mode">';
    $page .= "<option value=\"create\">Create</option>";
    $page .= "<option value=\"delete\">Delete</option>";
    if ( grep { $_ eq $page_type } @display_modify_arr ) {
        $page .= "<option value=\"modify\">Modify</option>";
    }
    $page .= '</select">';
    $page .= $q->hidden( 'page_type', "$page_type" );
    $page .= $q->submit(
        -name  => 'submit',
        -value => 'Submit'
    );
    $page .= $q->end_form;
    return $page;
}

=head2 display_api_response

This function displays the api response

=head3 Parameters

=over

=item * 

arr is the api response

=item * 

optional: payload 

=back

=cut

sub display_api_response {
    my @arr     = $_[0];
    my $payload = '';
    if ( $_[1] ) {
        $payload = $_[1];
    }

    # A cgi object to help with some html creation
    my $q      = CGI->new;
    my $result = $q->p("Result from API was:");
    $result .= $q->p( $arr[0]{results}[0]{status} );
    $result .= $q->p( $arr[0]{results}[0]{errors} );
    if ( $payload =~ m/.+/ ) {
        $result .= $q->p("Payload was: $payload");
    }
    return $result;
}

=head2 display_modify_textbox
This function gets the editable json of a configuration object
=head3 Parameters
=over
=item *
page_type (services, hosts, etc)
=item *
endpoint (e.g. objects/services/<hostname>!<servicename>)
=item *
keys to extract from "attrs" ("vars", "action_url", "check_command" ...)
=back
=cut

sub display_modify_textbox {
    my ( $c, $hidden, $endpoint, @keys ) = @_;
    my $q = CGI->new;

    #my $json_text = encode_entities(get_json( $c, $endpoint, @keys ));
    my $json_text = get_json( $c, $endpoint, @keys );
    my $rows = () = $json_text =~ /\n/g;
    my $cols = 0;
    open my $fh, '<', \$json_text or die $!;
    while (<$fh>) {
        my $len = length($_);
        if ( $len > $cols ) {
            $cols = $len;
        }
    }
    close $fh or die $!;

    # Pretty print
    $json_text =~ s/ /&nbsp;/g;
    print "Printing json: " . $json_text;
    my $textbox;
    $textbox .= $q->p("Object editor for endpoint: <b>$endpoint</b><br/>");
    $textbox .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    foreach my $key ( keys $hidden ) {
        $textbox .= $q->hidden( $key, $hidden->{"$key"} );
    }
    $textbox .= $q->hidden( 'mode', "modify" );
    $textbox .= $q->textarea(
        -name    => "attributes",
        -default => $json_text,
        -rows    => $rows,
        -columns => $cols
    );
    $textbox .= "<br/>";
    $textbox .= $q->submit(
        -name  => "submit",
        -value => 'Submit'
    );
    $textbox .= $q->end_form;
    return decode_entities($textbox);
}

=head2 display_command_confirmation
This function gets a confirmation dialog
=head3 Parameters
=over
=item *
$c - a context
=item *
mode, create, delete or modify
=item *
commandname
=item *
attributes, i.e. the json to send to the api
=back
=cut

sub display_generic_confirmation {
    my $q = CGI->new;
    my ( $c, $mode, $name, $attributes ) = @_;
    my $generic_form;
    $generic_form .= $q->p("Are you sure you want to $mode $name?<br/>");
    if ( $mode eq "modify" and $attributes ) {
        $generic_form .= $q->p("Attributes are: <br/>$attributes<br/>");
    }
    $generic_form .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $generic_form .= $q->hidden( 'page_type', "commands" );
    $generic_form .= $q->hidden( 'command',   $name );
    $generic_form .= $q->hidden( 'mode',      $mode );

    if ( $mode eq "delete" ) {
        $generic_form .= $q->checkbox( 'cascading', 0, 'true',
            'Use cascading delete - WARNING' );
    }
    elsif ( $mode eq "modify" and $attributes ) {
        $generic_form .= $q->hidden( 'attributes', $attributes );
    }
    $generic_form .= $q->submit(
        -name  => 'confirm',
        -value => 'Confirm'
    );
    $generic_form .= $q->end_form;
    return $generic_form;
}

=head2 display_service_confirmation
This function gets a confirmation dialog
=head3 Parameters
=over
=item *
$c - a context
=item *
mode, create, delete or modify
=item *
host
=item *
servicename
=item *
attributes, i.e. the json to send to the api
=back
=cut

sub display_service_confirmation {
    my $q = CGI->new;
    my ( $c, $mode, $host, $servicename, $attributes ) = @_;
    my $service_form;
    $service_form .= $q->p(
        "Are you sure you want to $mode $servicename for host: $host?<br/>");
    if ($attributes) {
        $service_form .= $q->p("Attributes are: <br/> $attributes<br/>");
    }
    $service_form .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $service_form .= $q->hidden( 'host',      $host );
    $service_form .= $q->hidden( 'page_type', "services" );
    $service_form .= $q->hidden( 'mode',      $mode );
    if ($attributes) {
        $service_form .= $q->hidden( 'attributes', $attributes );
    }
    $service_form .= $q->hidden( 'servicename', $servicename );
    $service_form .= $q->submit(
        -name  => 'confirm',
        -value => 'Confirm'
    );
    $service_form .= $q->end_form;
}

=head2 display_service_selection
This function gets the command selection
=head3 Parameters
=over
=item *
$c - a context
=item *
mode, create, delete or modify
=back
=cut

sub display_command_selection {
    my ( $c, $mode ) = @_;
    my $q = CGI->new;
    my $command_form .= $q->p("Enter command to $mode");
    $command_form .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $command_form .= '<select name="command">';
    foreach my $hash ( values $c->stash->{commands} ) {
        my $name = $hash->{name};
        $name =~ s/check_//g;
        $command_form .= "<option value=\"$name\">$hash->{name}</option>";
    }
    $command_form .= '</select">';
    $command_form .= $q->hidden( 'page_type', "commands" );
    $command_form .= $q->hidden( 'mode', $mode );
    $command_form .= $q->submit(
        -name  => 'submit',
        -value => 'Submit'
    );
    $command_form .= $q->end_form;
    return $command_form;
}

=head2 display_service_selection
This function gets the service selection
=head3 Parameters
=over
=item *
$c - a context
=item *
mode, create, delete or modify
=item *
host
=back
=cut

sub display_service_selection {
    my $q = CGI->new;
    my ( $c, $mode, $host ) = @_;
    my $service_form;

    # Get services
    my %services = ();
    foreach my $hash ( $c->stash->{services} ) {
        foreach my $service ( values $hash ) {
            $services{ $service->{host_name} }{ $service->{description} } =
              $service->{display_name};
        }
    }
    $service_form .= $q->p("Enter service to $mode for host: $host ");
    $service_form .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $service_form .= '<select name="servicename">';

    # Loop all services asscoiated with the host
    foreach my $service ( sort keys $services{$host} ) {
        $service_form .=
          "<option value=\"$service\">$services{$host}{$service}</option>";
    }
    $service_form .= '</select">';
    $service_form .= $q->hidden( 'page_type', "services" );
    $service_form .= $q->hidden( 'mode', $mode );
    $service_form .= $q->hidden( 'host', $host );
    $service_form .= $q->submit(
        -name  => 'submit',
        -value => 'Submit'
    );
    $service_form .= $q->end_form;
}

=head2 display_single_host_selection
This function gets a list of hosts where you can select one and one only 
=head3 Parameters
=over
=item *
$c - a context
=item *
mode, create, delete or modify
=item *
page_type, services, hosts etc
=back
=cut

sub display_single_host_selection {
    my $q = CGI->new;
    my ( $c, $mode, $page_type ) = @_;
    my $service_form;

    # Get services
    my %services = ();
    foreach my $hash ( $c->stash->{services} ) {
        foreach my $service ( values $hash ) {
            $services{ $service->{host_name} }{ $service->{description} } =
              $service->{display_name};
        }
    }
    $service_form = $q->p("Enter host to $mode");
    $service_form .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $service_form .= '<select name="host">';
    foreach my $service_host ( sort keys %services ) {
        $service_form .=
          "<option value=\"$service_host\">$service_host</option>";
    }
    $service_form .= '</select">';
    $service_form .= $q->hidden( 'page_type', $page_type );
    $service_form .= $q->hidden( 'mode', $mode );
    $service_form .= $q->submit(
        -name  => 'submit',
        -value => 'Submit'
    );
    $service_form .= $q->end_form;
    return $service_form;
}

=head2 get_json
This function gets the editable json of a configuration object
=head3 Parameters
=over
=item *
endpoint (e.g. objects/services/<hostname>!<servicename>)
=item *
keys to extract from "attrs" ("vars", "action_url", "check_command" ...)
=back
=cut

sub get_json {
    my ( $c, $endpoint, @keys ) = @_;
    my $result = api_call( $c->stash->{'confdir'}, "GET", $endpoint );
    my %to_json;
    foreach my $key ( sort @keys ) {
        $to_json{"attrs"}{$key} = $result->{"results"}[0]{"attrs"}{$key};
    }
    my $json = JSON->new;
    $json->pretty->canonical(1);
    return $json->pretty->encode( \%to_json );
}

=head2 selector

This displays the main scroll list och different type of objects

=cut

sub selector {

    # A cgi object to help with some html creation
    my $q = CGI->new;

    # These are the different kinds of objects we can manipulate
    my %pagetypes = (
        'hosts' => 'Hosts',

    #	'hostdependencies' => 'Host Dependencies',
    #	'hostescalations' => 'Host Escalations',
    #	'hostgroups' => 'Host Groups', # Create and delete is implemented for this
        'services' => 'Services',

        #	'servicegroups' => 'Service Groups',
        #	'servicedependencies' => 'Service Dependencies',
        #	'serviceescalations' => 'Service Escalations',
        #	'contacts' => 'Contacts',
        #	'contactgroups' => 'Contact Groups',
        #	'timeperiods' => 'Timeperiods',
        'commands' => 'Commands',
    );

    # This is where you land if you are not in a specific page_type allready
    my $landing_page = '<br><br>';
    $landing_page .=
'<div class="reportSelectTitle" align="center">Select Type of Config Data You Wish To Edit</div>';
    $landing_page .= '<br>';
    $landing_page .= '<br>';
    $landing_page .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $landing_page .= '<div align="center">';
    $landing_page .= '<table border="0">';
    $landing_page .= '<tbody>';
    $landing_page .= '<tr>';
    $landing_page .=
      '<td class="reportSelectSubTitle" align="left">Object Type:</td>';
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
    $landing_page .= $q->submit(
        -name  => 'continue',
        -value => 'Continue'
    );
    $landing_page .= $q->end_form;
    $landing_page .= '</td>';
    $landing_page .= '</tr>';
    $landing_page .= '</tbody>';
    $landing_page .= '</table>';
    $landing_page .= '</div>';
    return $landing_page;
}

=head2 hosts

This where we manipulate host objects

=cut

sub hosts {

    # $c holds all our context info
    my ($c) = @_;

    # $host_page is the html for the hosts
    my $host_page = '<div class="reportSelectTitle" align="center">Hosts</div>';

    # Set up cgi
    my $q      = CGI->new;
    my $params = $c->req->parameters;

    #Extract parameters from the request
    my @hosts = ();
    my $host  = '';
    if ( ref $params->{'host'} eq 'ARRAY' ) {
        foreach my $hst ( values $params->{'host'} ) {
            push @hosts, $hst;
        }
        $host = $hosts[0];
    }
    else {
        $host = $params->{'host'};
        push @hosts, $host;
    }
    my $attributes = $params->{'attributes'};
    my $ip         = $params->{'ip'};
    my $os         = $params->{'os'};
    my $zone       = $params->{'zone'};
    my $confirm    = $params->{'confirm'};
    my $cascading  = $params->{'cascading'};
    my $mode       = $params->{'mode'};
    my $submit     = $params->{'submit'};
    my $command    = $params->{'command'};
    my $templates  = $params->{'templates'};

    # Get hosts
    my @temp_arr;
    for my $hashref ( values $c->stash->{hosts} ) {
        push @temp_arr, $hashref->{name};
    }
    my @host_arr = sort @temp_arr;

    # Delete mode
    if ( $mode eq "delete" ) {

        # This case is first dialog
        if ( not defined($confirm) and $host =~ m/\..*\./ ) {
            my $hoststr = csv_from_arr(@hosts);
            $host_page .=
              $q->p( 'Are you sure you want to delete ' . $hoststr . '?<br/>' );
            $host_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            foreach my $hst (@hosts) {
                $host_page .= $q->hidden( 'host', $hst );
            }
            $host_page .= $q->hidden( 'page_type', "hosts" );
            $host_page .= $q->hidden( 'mode',      "delete" );
            $host_page .= $q->checkbox( 'cascading', 0, 'true',
                'Use cascading delete - WARNING' );
            $host_page .= $q->submit(
                -name  => 'confirm',
                -value => 'Confirm'
            );
            $host_page .= $q->end_form;
        }

        # This case is delete request
        elsif ( $confirm eq "Confirm" and $host =~ m/\..*\./ ) {
            my $cascade = '';
            if ( $cascading eq "true" ) {
                $cascade = '?cascade=1';
            }
            foreach my $hst (@hosts) {
                my @arr = api_call( $c->stash->{'confdir'},
                    "DELETE", "objects/hosts/$hst$cascade" );
                $host_page .= display_api_response(@arr);
            }
            $host_page .= display_back_button( $mode, 'hosts' );
        }

        # Main dialog box of the delete mode for hosts page
        else {
            $host_page .= $q->p('Select one or more hosts to delete.');
            if ( scalar @host_arr > 300 ) {
                $host_page .= $q->p(
'Please don\'t try with more than ~300 at a time or it will fail'
                );
            }
            $host_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $host_page .=
              "<select name='host' id='host-select' multiple='multiple'>\n";
            for my $ho (@host_arr) {
                $host_page .= "<option value=\"$ho\">$ho</option>\n";
            }
            $host_page .= "</select>\n";
            $host_page .= $q->hidden( 'page_type', "hosts" );
            $host_page .= $q->hidden( 'mode', "delete" );
            $host_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $host_page .= $q->end_form;
            $host_page .= display_multi_select( 'host-select', @host_arr );
        }

        # This is create mode
    }
    elsif ( $mode eq "create" ) {

        # This case is confirm dialog
        if (    $host =~ m/\..*\./
            and ( is_ipv4($ip) or is_ipv6($ip) )
            and $confirm ne "Confirm" )
        {
            $host_page .=
              $q->p('Are you sure you want to create '
                  . $host
                  . ' with ip address: '
                  . $ip
                  . ' and checkcommand: '
                  . $command
                  . '?<br/>' );
            $host_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $host_page .= $q->hidden( 'host',      $host );
            $host_page .= $q->hidden( 'page_type', "hosts" );
            $host_page .= $q->hidden( 'mode',      "create" );
            $host_page .= $q->hidden( 'ip',        $ip );
            $host_page .= $q->hidden( 'zone',      $zone );
            $host_page .= $q->hidden( 'command',   $command );
            $host_page .= $q->hidden( 'templates', $templates );
            $host_page .= $q->hidden( 'os',        $os );
            $host_page .= $q->submit(
                -name  => 'confirm',
                -value => 'Confirm'
            );
            $host_page .= $q->end_form;

            # This case is the  actual creation
        }
        elsif ( $host =~ m/\..*\./
            and ( is_ipv4($ip) or is_ipv6($ip) )
            and $confirm eq "Confirm"
            and $os =~ m/.+/
            and $zone )
        {
            my $payload = '{ ';
            if ( $templates =~ m/.+/ ) {
                $payload .= '"templates": [';
                for my $template ( split( ',', $templates ) ) {
                    $payload .= '"' . $template . '", ';
                }
                $payload =~ s/, $/],/;
            }
            $payload .=
                '"attrs": { "zone": "'
              . $zone
              . '", "address": "'
              . $ip
              . '", "check_command": "'
              . $command
              . '", "vars.os" : "'
              . $os . '" } }';
            my @arr = api_call(
                $c->stash->{'confdir'}, "PUT",
                "objects/hosts/$host",  $payload
            );
            $host_page .= display_api_response( @arr, $payload );
            $host_page .= display_back_button( $mode, 'hosts' );

            # This is the main host creation dialog
        }
        else {
            my %zones =
              %{ api_call( $c->stash->{'confdir'}, "GET", "objects/zones" ) };
            $host_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $host_page .= $q->p("Enter hostname:");
            $host_page .= $q->textfield( 'host', '', 50, 80 );
            $host_page .= $q->p("Enter ip address:");
            $host_page .= $q->textfield( 'ip', '', 50, 80 );
            $host_page .=
              $q->p("Enter templates, optional comma separated list:");
            $host_page .= $q->textfield( 'templates', '', 50, 80 );
            $host_page .= $q->p("Enter zone:");
            $host_page .= '<select name="zone">';

            # Loop through the zones
            for my $zone ( values $zones{results} ) {
                $host_page .=
                  "<option value=\"$zone->{name}\">$zone->{name}</option>";
            }
            $host_page .= '</select>';
            $host_page .= $q->p("Enter host check command:");
            $host_page .= '<select name="command">';

            # We select check_hostalive as default command if it exists
            # TODO: Move default checkcommand to conf file?
            foreach my $hash ( values $c->stash->{commands} ) {
                my $selected = '';
                if ( $hash->{name} eq "check_hostalive" ) {
                    $selected = 'selected="selected" ';
                }
                my $name = $hash->{name};
                $name =~ s/check_//g;
                $host_page .=
                  "<option value=\"$name\" $selected>$hash->{name}</option>";
            }
            $host_page .= '</select>';
            $host_page .= $q->p("Enter OS:");
            $host_page .= $q->textfield( 'os', '', 50, 80 );
            $host_page .= $q->hidden( 'page_type', "hosts" );
            $host_page .= $q->hidden( 'mode',      "create" );
            $host_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $host_page .= $q->end_form;
        }
    }
    elsif ( $mode eq "modify" ) {

        # This is where we make api call
        if ( $host and $attributes and $confirm eq "Confirm" ) {

            print "Placeholder";

        }

        # This is where we show confirm
        elsif ( $host  and $attributes and $submit eq "Submit" ) {
            $host_page .=
              display_generic_confirmation( $c, $mode, $host, $attributes );

        }

        # This is where we edit
        elsif ( $host and $submit eq "Submit" ) {
            my %hidden = (
                "page_type" => "hosts",
                "host"      => $host
            );
            my $endpoint = "objects/hosts/$host";
            $host_page .=
              display_modify_textbox( $c, \%hidden, $endpoint, @host_keys );

        }

        # This is where we show single host selection dialog
        else {

            $host_page .= display_single_host_selection( $c, $mode, "hosts" )

        }
    }
    else {
        $host_page .= display_create_delete_modify_dialog("hosts");
    }
    return $host_page;
}

=head2 host_groups

TODO: Implement this

=cut

sub host_groups {

    # $c holds all our context info
    my ($c) = @_;

    # $host_page is the html for the hosts
    my $hostgroup_page =
      '<div class="reportSelectTitle" align="center">Host Groups</div>';

    # Set up cgi
    my $q      = CGI->new;
    my $params = $c->req->parameters;

    #Extract parameters from the request
    my $hostgroup   = $params->{'hostgroup'};
    my $displayname = $params->{'displayname'};
    my $confirm     = $params->{'confirm'};
    my $cascading   = $params->{'cascading'};
    my $mode        = $params->{'mode'};
    my $templates   = $params->{'templates'};

    # Get hosts
    my @temp_arr;
    for my $hashref ( values $c->stash->{hosts} ) {
        push @temp_arr, $hashref->{name};
    }
    my @host_arr = sort @temp_arr;
    if ( $mode eq "create" ) {

# If we have selected a hostgroup but have not yet confirmed, i.e. we show confirm dialog
        if ( $hostgroup =~ m/.+/ and $confirm ne "Confirm" ) {
            if ( !$displayname =~ m/.+/ ) {
                $displayname = $hostgroup;
            }
            $hostgroup_page .= $q->p(
                'Are you sure you want to create ' . $hostgroup . '?<br/>' );
            $hostgroup_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $hostgroup_page .= $q->hidden( 'hostgroup',   $hostgroup );
            $hostgroup_page .= $q->hidden( 'page_type',   "hostgroups" );
            $hostgroup_page .= $q->hidden( 'templates',   $templates );
            $hostgroup_page .= $q->hidden( 'displayname', $displayname );
            $hostgroup_page .= $q->hidden( 'mode',        "create" );
            $hostgroup_page .= $q->submit(
                -name  => 'confirm',
                -value => 'Confirm'
            );
            $hostgroup_page .= $q->end_form;

           # If we have both hostgroup and confirm, i.e. we  create via api call
        }
        elsif ( $hostgroup =~ m/.+/ and $confirm eq "Confirm" ) {
            my $payload = '{ "attrs": {"display_name":"' . $displayname . '"';

            # templates are otional so we can only add them if they exist
            if ( $templates =~ m/.+/ ) {
                $payload .= ', "templates": [';
                for my $template ( split( ',', $templates ) ) {
                    $payload .= '"' . $template . '", ';
                }
                $payload =~ s/, $/]/;
            }
            $payload .= ' } }';
            my @arr = api_call(
                $c->stash->{'confdir'},          "PUT",
                "objects/hostgroups/$hostgroup", $payload
            );
            $hostgroup_page .= display_api_response( @arr, $payload );
            $hostgroup_page .= display_back_button( $mode, 'hostgroups' );

            # This is the create dialog
        }
        else {
            $hostgroup_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $hostgroup_page .= $q->p("Enter hostgroupname:");
            $hostgroup_page .= $q->textfield( 'hostgroup', '', 50, 80 );
            $hostgroup_page .= $q->p("Enter displayname:");
            $hostgroup_page .= $q->textfield( 'displayname', '', 50, 80 );
            $hostgroup_page .=
              $q->p("Enter templates, optional comma separated list:");
            $hostgroup_page .= $q->textfield( 'templates', '', 50, 80 );
            $hostgroup_page .= $q->hidden( 'page_type', "hostgroups" );
            $hostgroup_page .= $q->hidden( 'mode',      "create" );
            $hostgroup_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $hostgroup_page .= $q->end_form;
        }
    }
    elsif ( $mode eq "delete" ) {

# If we have selected a hostgroup but have not yet confirmed, i.e. we show confirm dialog
        if ( $hostgroup =~ m/.+/ and $confirm ne "Confirm" ) {
            $hostgroup_page .= $q->p(
                'Are you sure you want to delete ' . $hostgroup . '?<br/>' );
            $hostgroup_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $hostgroup_page .= $q->hidden( 'hostgroup', $hostgroup );
            $hostgroup_page .= $q->hidden( 'page_type', "hostgroups" );
            $hostgroup_page .= $q->hidden( 'mode',      "delete" );
            $hostgroup_page .= $q->checkbox( 'cascading', 0, 'true',
                'Use cascading delete - WARNING' );
            $hostgroup_page .= $q->submit(
                -name  => 'confirm',
                -value => 'Confirm'
            );
            $hostgroup_page .= $q->end_form;

            # If we have both hostgroup and confirm, i.e. we delete via api call
        }
        elsif ( $hostgroup =~ m/.+/ and $confirm eq "Confirm" ) {
            my $cascade = '';
            if ( $cascading eq "true" ) {
                $cascade .= '?cascade=1';
            }
            my @arr = api_call( $c->stash->{'confdir'},
                "DELETE", "objects/hostgroups/$hostgroup$cascade" );
            $hostgroup_page .= display_api_response(@arr);
            $hostgroup_page .= display_back_button( $mode, 'hostgroups' );

            # Fall back on a drop down list
        }
        else {
            $hostgroup_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $hostgroup_page .= $q->p("Enter hostgroupname:");
            $hostgroup_page .= '<select name="hostgroup">';
            foreach my $hostgroup ( values $c->stash->{hostgroups} ) {
                $hostgroup_page .=
"<option value=\"$hostgroup->{name}\">$hostgroup->{alias}</option>";
            }
            $hostgroup_page .= '</select>';
            $hostgroup_page .= $q->hidden( 'page_type', "hostgroups" );
            $hostgroup_page .= $q->hidden( 'mode', "delete" );
            $hostgroup_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $hostgroup_page .= $q->end_form;
        }

        #	} elsif ($mode eq "modify") {
        #		$hostgroup_page .= "Modification";
        #		$hostgroup_page .= Dumper $c->stash->{hostgroups};
    }
    else {
        $hostgroup_page .= display_create_delete_modify_dialog("hostgroups");
    }
    return $hostgroup_page;
}

=head2 host_escalations

TODO: Implement this

=cut

sub host_escalations {
    return "Host Escalations Placeholder";
}

=head2 host_dependencies

TODO: Implement this

=cut

sub host_dependencies {
    return "Host Dependencies Placeholder";
}

=head2 services

This is where we produce the services page_type

=cut

sub services {
    my ($c)    = @_;
    my $q      = CGI->new;
    my $params = $c->req->parameters;

    #Get host and see if this is the delete request or not
    my @hosts = ();
    my $host  = '';
    if ( ref $params->{'host'} eq 'ARRAY' ) {
        foreach my $hst ( values $params->{'host'} ) {
            push @hosts, $hst;
        }
        $host = $hosts[0];
    }
    else {
        $host = $params->{'host'};
        push @hosts, $host;
    }
    my $confirm     = $params->{'confirm'};
    my $submit      = $params->{'submit'};
    my $check       = $params->{'check'};
    my $mode        = $params->{'mode'};
    my $servicename = $params->{'servicename'};
    my $displayname = $params->{'displayname'};
    my $attributes  = $params->{'attributes'};
    my $service_page =
      '<div class="reportSelectTitle" align="center">Services</div>';

    # Get services
    my %services = ();
    foreach my $hash ( $c->stash->{services} ) {
        foreach my $service ( values $hash ) {
            $services{ $service->{host_name} }{ $service->{description} } =
              $service->{display_name};
        }
    }

    # This is the delete mode
    if ( $mode eq "delete" ) {

        # This is the service deletion dialog for a specific host
        if (    $host =~ m/\..*\./
            and $confirm ne "Confirm"
            and not $servicename =~ m/.+/ )
        {
            $service_page .= display_service_selection( $c, $mode, $host );

            # This case is confirmation dialog for delete mode
        }
        elsif ( $host =~ m/\..*\./
            and $confirm ne "Confirm"
            and $servicename =~ m/.+/ )
        {
            $service_page .=
              display_service_confirmation( $c, $mode, $host, $servicename );

            # This case is actual deletion via api_call
        }
        elsif ( $host =~ m/\..*\./
            and $confirm eq "Confirm"
            and $servicename =~ m/.+/ )
        {
            my @arr = api_call( $c->stash->{'confdir'},
                "DELETE", "objects/services/$host!$servicename" );
            $service_page .= display_api_response(@arr);
            $service_page .= display_back_button( $mode, 'services' );

            # Host selection dialog i.e. the main dialog for service deletion
        }
        else {
            $service_page .=
              display_single_host_selection( $c, $mode, "services" );
        }

        # Creation mode
    }
    elsif ( $mode eq "create" ) {

        # This is the confirm dialog
        if (    $host =~ m/\..*\./
            and $check =~ m/.+/
            and $displayname =~ m/.+/
            and $servicename =~ m/.+/
            and $confirm ne "Confirm" )
        {
            my $hoststr = csv_from_arr(@hosts);
            $service_page .=
                '<p>Are you sure you want to add the service '
              . $servicename
              . ' to the host(s): '
              . $hoststr;
            if ( $attributes =~ m/.+/ ) {
                $service_page .= ' with attributes: ' . $attributes;
            }
            $service_page .= '?</p><br/>';
            $service_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            foreach my $hst (@hosts) {
                $service_page .= $q->hidden( 'host', $hst );
            }
            $service_page .= $q->hidden( 'page_type',   "services" );
            $service_page .= $q->hidden( 'mode',        "create" );
            $service_page .= $q->hidden( 'servicename', $servicename );
            $service_page .= $q->hidden( 'displayname', $displayname );
            $service_page .= $q->hidden( 'attributes',  $attributes );
            $service_page .= $q->hidden( 'check',       $check );
            $service_page .= $q->submit(
                -name  => 'confirm',
                -value => 'Confirm'
            );
            $service_page .= $q->end_form;

            # This is the actual creation via api_call
        }
        elsif ( $host =~ m/\..*\./
            and $check =~ m/.+/
            and $displayname =~ m/.+/
            and $servicename =~ m/.+/
            and $confirm eq "Confirm" )
        {
            my $payload =
                '{  "attrs": { "check_command": "'
              . $check
              . '", "display_name": "'
              . $displayname
              . '", "check_interval": 1,"retry_interval": 1';

            # attributes are otional so we can only add them if they exist
            if ( $attributes =~ m/.+/ ) {
                for my $commas ( split( ',', $attributes ) ) {
                    my @colon = split( ':', $commas );
                    $payload .= ", \"$colon[0]\": \"$colon[1]\"";
                }
            }
            $payload .= ' } }';
            foreach my $hst (@hosts) {
                my @arr = api_call( $c->stash->{'confdir'},
                    "PUT", "objects/services/$hst!$servicename", $payload );
                $service_page .= display_api_response( @arr, $payload );
            }
            $service_page .= display_back_button( $mode, 'services' );

            # This is the main dialog for service creation
        }
        else {

            # Get hosts
            my @temp_arr;
            for my $hashref ( values $c->stash->{hosts} ) {
                push @temp_arr, $hashref->{name};
            }
            my @host_arr = sort @temp_arr;
            $service_page .= $q->p('Select host to modify:');
            $service_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $service_page .=
              '<select name="host" id="host-select" multiple="multiple"">';
            for my $ho (@host_arr) {
                my $selected = '';
                if ( $host =~ m/$ho/ ) {
                    $selected = 'selected="selected" ';
                }
                $service_page .= "<option value=\"$ho\" $selected>$ho</option>";
            }
            $service_page .= '</select><br>';
            $service_page .= display_multi_select( "host-select", @host_arr );
            $service_page .= $q->p('Select check command:');
            $service_page .= '<select name="check">';
            foreach my $hash ( values $c->stash->{commands} ) {
                my $name = $hash->{name};
                $name =~ s/check_//g;
                $service_page .=
                  "<option value=\"$name\">$hash->{name}</option>";
            }
            $service_page .= '</select>';
            $service_page .= $q->p("Enter service displayname:");
            $service_page .= $q->textfield( 'displayname', '', 50, 80 );
            $service_page .= $q->p("Enter servicename:");
            $service_page .= $q->textfield( 'servicename', '', 50, 80 );
            $service_page .= $q->p("Enter additional attributes (optional):");
            $service_page .= $q->textfield( 'attributes', '', 50, 80 );
            $service_page .= $q->hidden( 'page_type', "services" );
            $service_page .= $q->hidden( 'mode',      "create" );
            $service_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $service_page .= $q->end_form;
        }

       # This is the first selection page i.e. create/delete dialog for services
    }
    elsif ( $mode eq "modify" ) {

        # This is the editor
        if ( $host and $servicename and $attributes and $confirm eq "Confirm" )
        {
            # Do api magic here
            my $payload = uri_unescape($attributes);
            my @arr     = api_call( $c->stash->{'confdir'},
                "POST", "objects/services/$host!$servicename", $payload );
            $service_page .= display_api_response( @arr, $payload );
            $service_page .= display_back_button( $mode, 'services' );
        }
        elsif ( $host
            and $servicename
            and $attributes
            and $submit eq "Submit" )
        {
            $service_page .=
              display_service_confirmation( $c, $mode, $host, $servicename,
                $attributes );
        }
        elsif ( $host and $servicename ) {
            my %hidden = (
                "page_type"   => "services",
                "host"        => $host,
                "servicename" => $servicename
            );
            $service_page .=
              display_modify_textbox( $c, \%hidden,
                "objects/services/$host!$servicename",
                @service_keys );
        }
        elsif ($host) {
            $service_page .= display_service_selection( $c, $mode, $host );
        }
        else {
            $service_page .=
              display_single_host_selection( $c, $mode, "services" );
        }
    }
    else {
        $service_page .= display_create_delete_modify_dialog("services");
    }
    return $service_page;
}

=head2 service_groups

TODO: Implement this

=cut

sub service_groups {
    return "Service Groups Placeholder";
}

=head2 contacts

TODO: Implement this

=cut

sub contacts {
    return "Contacts Placeholder";
}

=head2 contact_groups

TODO: Implement this

=cut

sub contact_groups {
    return "Contact Groups Placeholder";
}

=head2 timeperiods

TODO: Implement this

=cut

sub timeperiods {
    return "Timeperiods Placeholder";
}

=head2 commands

This is the page_type commands

=cut

sub commands {
    my ($c)    = @_;
    my $q      = CGI->new;
    my $params = $c->req->parameters;

    # Capture parameters sent to page by user dialogs
    my $confirm     = $params->{'confirm'};
    my $command     = $params->{'command'};
    my $commandline = $params->{'commandline'};
    my $cascading   = $params->{'cascading'};
    my $mode        = $params->{'mode'};
    my $submit      = $params->{'submit'};
    my $arguments   = $params->{'arguments'};
    my $attributes  = $params->{'attributes'};

    my $command_page =
      '<div class="reportSelectTitle" align="center">Commands</div>';

    # This is delete mode
    if ( $mode eq "delete" ) {

        # This case is the confirmation dialog
        if ( $confirm ne "Confirm" and $command =~ m/.+/ ) {
            $command_page .=
              display_generic_confirmation( $c, $mode, $command );

            # This is the actual deletion via api call
        }
        elsif ( $confirm eq "Confirm" and $command =~ m/.+/ ) {
            my $cascade = '';
            if ( $cascading eq "true" ) {
                $cascade .= '?cascade=1';
            }
            my @arr = api_call( $c->stash->{'confdir'},
                "DELETE", "objects/checkcommands/$command$cascade" );
            $command_page .= display_api_response(@arr);
            $command_page .= display_back_button( $mode, 'commands' );

            # This is the main dialog for command deletion
        }
        else {
            $command_page .= display_command_selection( $c, $mode );
        }

        # Creation dialog
    }
    elsif ( $mode eq "create" ) {

        # This is actual creation via api call
        if (    $confirm eq "Confirm"
            and $commandline =~ m/.+/
            and $command =~ m/.+/ )
        {
            my $payload =
'{ "templates": [ "plugin-check-command" ], "attrs": { "command": [ "'
              . $commandline . '" ]';

            # Arguments are optional so we only add them if they exist
            if ( $arguments =~ m/.+/ and is_valid_json $arguments ) {
                $payload .= ', "arguments": ' . $arguments;
            }
            $payload .= ' } }';
            my @arr = api_call(
                $c->stash->{'confdir'},           "PUT",
                "objects/checkcommands/$command", $payload
            );
            $command_page .= display_api_response( @arr, $payload );
            $command_page .= display_back_button( $mode, 'commands' );

            # This is confirmation dialog for command creation
        }
        elsif ( $submit eq "Submit"
            and $command =~ m/.+/
            and $commandline =~ m/.+/ )
        {
            my $mess =
                'Are you sure you want to create '
              . $command
              . ' with commandline: '
              . $commandline;
            $mess .=
              $arguments =~ m/.+/ ? " and arguments: $arguments?<br>" : "?<br>";
            my $all_is_well = 1;
            unless ( is_valid_json $arguments or $arguments eq "" ) {
                $command_page .= "<p>You supplied faulty json.</p>";
                $all_is_well = 0;
            }
            unless ( basename($commandline) =~ m/^check_/ ) {
                $command_page .=
"<p>Basename of your commandline must start with check_, e.g.: /usr/local/bin/check_test. Please try again.</p>";
                $all_is_well = 0;
            }
            if ($all_is_well) {
                $command_page .= $q->p($mess);
                $command_page .= $q->start_form(
                    -method => $METHOD,
                    -action => "api_conf.cgi"
                );
                $command_page .= $q->hidden( 'page_type',   "commands" );
                $command_page .= $q->hidden( 'command',     $command );
                $command_page .= $q->hidden( 'arguments',   $arguments );
                $command_page .= $q->hidden( 'commandline', $commandline );
                $command_page .= $q->hidden( 'mode',        "create" );
                $command_page .= $q->submit(
                    -name  => 'confirm',
                    -value => 'Confirm'
                );
                $command_page .= $q->end_form;
            }
            else {
                $command_page .= display_back_button( $mode, 'commands' );
            }

            # This is main command creation dialog
        }
        else {
            $command_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $command_page .= $q->p(
"Enter command name (\"check_\" will be prepended automaticaly):"
            );
            $command_page .= $q->textfield( 'command', '', 50, 80 );
            $command_page .= $q->p("Enter commandline to be executed:");
            $command_page .= $q->textfield( 'commandline', '', 50, 80 );
            $command_page .= $q->p(
'Enter arguments (an optional json string e.g. {"--some_long_arg": { "value": "$a_macro$" }, "-s": {"value": "$another_macro$" }} ):'
            );
            $command_page .= $q->textarea( 'arguments', '', 20, 50 );
            $command_page .= $q->hidden( 'page_type', "commands" );
            $command_page .= $q->hidden( 'mode',      "create" );
            $command_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $command_page .= $q->end_form;
        }

        # This is create/delete dialog
    }
    elsif ( $mode eq "modify" ) {

        # Do confirmation here
        if ( $command and $attributes ) {
            $command_page .=
              display_generic_confirmation( $c, $mode, $command, $attributes );

            # Do api call here
        }
        elsif ( $command and $confirm eq "Confirm" ) {
            print "Placeholder";

            # Do edit here
        }
        elsif ( $command and $submit eq "Submit" ) {
            my %hidden = (
                "page_type" => "commands",
                "command"   => $command
            );
            my $endpoint = "objects/checkcommands/$command";
            $command_page =
              display_modify_textbox( $c, \%hidden, $endpoint, @command_keys );
        }
        else {
            $command_page = display_command_selection( $c, $mode );
        }
    }
    else {
        $command_page .= display_create_delete_modify_dialog("commands");
    }
    return $command_page;
}

=head2 body

Some common initializations and setting main body variable for the template

=cut

sub body {
    my ($c)       = @_;
    my $body      = '';
    my $params    = $c->req->parameters;
    my $page_type = $params->{'page_type'};
    if ( $page_type eq "hosts" ) {
        $body = hosts $c;
    }
    elsif ( $page_type eq "hostgroups" ) {
        $body = host_groups $c;
    }
    elsif ( $page_type eq "hostescalations" ) {
        $body = host_groups $c;
    }
    elsif ( $page_type eq "hostdependencies" ) {
        $body = host_groups $c;
    }
    elsif ( $page_type eq "services" ) {
        $body = services $c;
    }
    elsif ( $page_type eq "servicegroups" ) {
        $body = service_groups $c;
    }
    elsif ( $page_type eq "contacts" ) {
        $body = contacts $c;
    }
    elsif ( $page_type eq "contactgroups" ) {
        $body = contact_groups $c;
    }
    elsif ( $page_type eq "timeperiods" ) {
        $body = timeperiods $c;
    }
    elsif ( $page_type eq "commands" ) {
        $body = commands $c;
    }
    else {
        $body = selector;
    }
    return $body;
}

=head2 index

This is the entry point 

=cut

sub index {
    my $context = new IO::Socket::SSL::SSL_Context(
        SSL_version     => 'tlsv1',
        SSL_verify_mode => Net::SSLeay::VERIFY_NONE(),
    );
    IO::Socket::SSL::set_default_context($context);
    my ($c) = @_;

    # Limit access to authorized personell only
    return
      unless Thruk::Action::AddDefaults::add_defaults( $c,
        Thruk::ADD_SAFE_DEFAULTS );
    if (   !$c->check_user_roles("authorized_for_configuration_information")
        || !$c->check_user_roles("authorized_for_system_commands") )
    {
        return $c->detach('/error/index/8');
    }

    # This is Configuration options used by Thruk
    $c->stash->{'readonly'}       = 0;
    $c->stash->{'title'}          = 'Configuration Editor';
    $c->stash->{'subtitle'}       = 'Configuration Editor';
    $c->stash->{'infoBoxTitle'}   = 'Configuration Editor';
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'template'}       = 'api_conf.tt';
    $c->stash->{'testmode'}       = 1;
    my $hostname = `hostname --fqdn`;
    chomp $hostname;
    $c->stash->{'hostname'} = $hostname;

    # This is data we need to have handy
    $c->stash->{services} = $c->{'db'}->get_services(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ] );
    $c->stash->{hosts} = $c->{'db'}->get_hosts(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
    $c->stash->{hostgroups} = $c->{'db'}->get_hostgroups(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ) ] );
    $c->stash->{commands} = $c->{'db'}->get_commands();
    my $confdir = '/etc/thruk';
    if ( $c->stash->{usercontent_folder} =~ m/\// ) {
        $confdir = dirname( $c->stash->{usercontent_folder} );
    }
    $c->stash->{'confdir'} = $confdir;
    $c->stash->{body} = body $c;
}

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
