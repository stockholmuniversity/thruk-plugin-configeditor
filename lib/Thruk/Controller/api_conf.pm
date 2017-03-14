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
use Data::Dumper;
use File::Basename qw( dirname basename );
use HTML::Entities;
use HTTP::Request::Common;
use IO::Socket::SSL;
use JSON::XS qw(encode_json decode_json);
use JSON;
use LWP::Protocol::https;
use LWP::UserAgent;
use URI::Escape;

# A cgi object to help with some html creation
my $q = CGI->new;

# This is the form method for dialogs, useful to change all for debug purposes
#my $METHOD = "GET";

my $METHOD = "POST";

my @command_keys = ( "arguments", "command", "env", "vars", "timeout" );

my @contact_keys = (
    "display_name", "email",  "enable_notifications", "pager",
    "states",       "period", "vars"
);

my @contactgroup_keys = ( "display_name", "vars" );
my @host_keys = (
    "address6",      "address",        "check_command", "display_name",
    "event_command", "action_url",     "notes_url",     "vars",
    "icon_image",    "icon_image_alt", "check_interval"
);

my @hostgroup_keys         = ();
my @hostescalation_keys    = ();
my @hostdependency_keys    = ();
my @servicedependency_keys = ();
my @serviceescalation_keys = ();
my @service_keys           = (
    "vars",          "action_url",
    "check_command", "check_interval",
    "display_name",  "notes_url",
    "event_command", "max_check_attempts",
    "retry_interval"
);
my @servicegroup_keys = ();
my @timeperiod_keys   = ();

my @command_dl_keys           = @command_keys;
my @contact_dl_keys           = @contact_keys;
my @contactgroup_dl_keys      = @contactgroup_keys;
my @host_dl_keys              = @host_keys;
my @hostdependency_dl_keys    = @hostdependency_keys;
my @hostescalation_dl_keys    = @hostescalation_keys;
my @hostgroup_dl_keys         = @hostgroup_keys;
my @service_dl_keys           = @service_keys;
my @servicedependency_dl_keys = @servicedependency_keys;
my @serviceescalation_dl_keys = @serviceescalation_keys;
my @servicegroup_dl_keys      = @servicegroup_keys;
my @timeperiod_dl_keys        = @timeperiod_keys;

push @command_dl_keys,      ( "templates", "zone" );
push @contact_dl_keys,      ( "groups",    "templates", "zone" );
push @contactgroup_dl_keys, ( "groups",    "templates", "zone" );
push @host_dl_keys,
  (
    "check_period",          "check_timeout",
    "enable_active_checks",  "enable_event_handler",
    "enable_flapping",       "enable_notifications",
    "enable_passive_checks", "enable_perfdata",
    "groups",                "notes",
    "retry_interval",        "templates",
    "zone"
  );
push @service_dl_keys,
  (
    "check_period",          "check_timeout",
    "enable_active_checks",  "enable_event_handler",
    "enable_flapping",       "enable_notifications",
    "enable_passive_checks", "enable_perfdata",
    "groups",                "icon_image",
    "icon_image_alt",        "notes",
    "templates",             "zone"
  );

=head2 api_call

This function reads api config and makes api calls

=head3 Parameters

=over 

=item *

$c - a context

=item *

$verb (GET, PUT, DELETE, POST)

=item *

$endpoint (e.g. objects/hosts/<hostname>)

=item *

$payload (optional, {  "attrs": { "check_command": "<command name>", "check_interval": 1,"retry_interval": 1 } })

=back

=cut

sub api_call {
    my ( $c, $verb, $endpoint, $payload ) = @_;

    # Read config
    my $api_host     = $c->config->{'icinga2_api_host'};
    my $api_password = $c->config->{'icinga2_api_password'};
    my $api_path     = $c->config->{'icinga2_api_path'};
    my $api_port     = $c->config->{'icinga2_api_port'};
    my $api_realm    = $c->config->{'icinga2_api_realm'};
    my $api_url      = "https://$api_host:$api_port/$api_path/$endpoint";
    my $api_user     = $c->config->{'icinga2_api_user'};

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

    my $result = $q->p("Result from API was:");
    $result .= $q->p( $arr[0]{results}[0]{status} );
    $result .= $q->p( $arr[0]{results}[0]{errors} );
    if ( $payload =~ m/.+/ ) {
        $result .= $q->p("Payload was: $payload");
    }
    return $result;
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

=head2 display_command_selection

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
    my $command_form .= $q->p("Enter command to $mode");
    $command_form .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $command_form .= '<select name="command">';
    my @names;
    foreach my $hash ( sort values @{ $c->stash->{commands} } ) {
        push @names, $hash->{name};
    }
    foreach my $temp ( sort @names ) {
        my $name = $temp;
        $name =~ s/check_//g;
        $command_form .= "<option value=\"$name\">$temp</option>";
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

=head2 display_create_delete_modify_dialog

This function returns the create/delete dialog

=head3 Parameters

=over

=item *

$page_type 

=back

=cut

sub display_create_delete_modify_dialog {
    my ($page_type) = @_;

    # A cgi object to help with some html creation
    my $page = $q->p('What do you want to do?');
    $page .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $page .= '<select name="mode">';
    $page .= "<option value=\"create\">Create</option>";
    $page .= "<option value=\"delete\">Delete</option>";
    $page .= "<option value=\"modify\">Modify</option>";
    $page .= '</select">';
    $page .= $q->hidden( 'page_type', "$page_type" );
    $page .= $q->submit(
        -name  => 'submit',
        -value => 'Submit'
    );
    $page .= $q->end_form;
    return $page;
}

=head2 display_delete_confirmation

This function returns the delete confirmation

=head3 Parameters

=over

=item *

$name

=item *

$page_type

=item *

@array - to delete

=back

=cut

sub display_delete_confirmation {
    my ( $name, $page_type, @arr ) = @_;

    my $str  = csv_from_arr(@arr);
    my $html = $q->p( 'Are you sure you want to delete ' . $str . '?<br/>' );
    $html .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    foreach my $elem (@arr) {
        $html .= $q->hidden( $name, $elem );
    }
    $html .= $q->hidden( 'page_type', $page_type );
    $html .= $q->hidden( 'mode',      "delete" );
    $html .=
      $q->checkbox( 'cascading', 0, 'true', 'Use cascading delete - WARNING' );
    $html .= $q->submit(
        -name  => 'confirm',
        -value => 'Confirm'
    );
    $html .= $q->end_form;

}

=head2 display_editor
This function gets the editable json of a configuration object
=head3 Parameters
=over
=item *
hidden - a hashref with key/values you want to display ass hidden form elements
=item *
page_type (services, hosts, etc)
=item *
a context
=item *
endpoint (e.g. objects/services/<hostname>!<servicename>)
=back
=cut

sub display_editor {
    my ( $page_type, $hidden, $c, $endpoint, ) = @_;
    my $name = $page_type;
    $name =~ s/s$//;
    my $mode = "create";
    if ($c) {
        $mode = "modify";
    }
    my $json_text = '';
    my $head      = 'Object editor';
    if ( $mode eq "modify" ) {
        my @keys = get_keys($page_type);
        $json_text = get_json( $c, $endpoint, @keys );
        $head .= " for endpoint: <b>$endpoint</b>";
    }
    else {
        $json_text = get_defaults($page_type);
    }

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

    if ( $mode eq "create" ) {

        # We want some extra space for the editor window
        $cols = $cols + 50;
    }

    # Pretty print
    $json_text =~ s/ /&nbsp;/g;
    my $textbox = '<script type="text/javascript">
	function popitup(str) {
		newwindow=window.open("","JSON Error","height=400,width=400");
		if (window.focus) {
			newwindow.focus()
		}
		newwindow.document.write("<html><body>" + str + "</body></html>")
		return false;
	}
	function validateJSON() {
          var success = true;
          var error = "";
	  var str = document.getElementById("JSONText").value;
	  str = str.replace(/\u00A0/g, " ");
	  try {
            JSON.parse(str);
	  } catch (e) {
            error = e;
            success = false;
          }
	  if ( success) {
	     return true;
	  } else { 
	     popitup("Invalid JSON! Please fix. " + error + ". Visit a <a href=\"http://jsonlint.com/?json=" + encodeURIComponent(str) + "\" target=\"_blank\" onclick=\"window.close()\">JSON validator</a> if you need help.");
	     return false;
	  }
	}
</script>';
    $textbox .= $q->p($head);
    unless ( $page_type eq "services" and $mode eq "create" ) {
        $textbox .= $q->start_form(
            -method   => $METHOD,
            -action   => "api_conf.cgi",
            -id       => "JSONForm",
            -onSubmit => "return validateJSON()"
        );
    }
    if ( $mode eq "create" ) {
        $textbox .= $q->p("Enter $name name:");
        $textbox .= $q->textfield( $name, '', 50, 80 );
        $textbox .= $q->p("Editor:");
    }
    if ($hidden) {
        foreach my $key ( keys %{$hidden} ) {
            $textbox .= $q->hidden( $key, $hidden->{"$key"} );
        }
    }
    $textbox .= $q->hidden( 'mode',      $mode );
    $textbox .= $q->hidden( 'page_type', $page_type );
    $textbox .= $q->textarea(
        -name    => "attributes",
        -default => $json_text,
        -rows    => $rows,
        -columns => $cols,
        -id      => "JSONText"
    );
    $textbox .= "<br/>";
    unless ( $page_type eq "services" and $mode eq "create" ) {
        $textbox .= $q->submit(
            -name  => "submit",
            -value => 'Submit'
        );
        $textbox .= $q->end_form;
    }
    if ( $mode eq "modify" ) {
        $textbox .= display_download_button( $c, $endpoint, $page_type );
    }
    return decode_entities($textbox);
}

=head2 display_generic_confirmation

This function gets a confirmation dialog

=head3 Parameters

=over

=item *

$c - a context

=item *

$mode, create, delete or modify

=item *

$name

=item *

$attributes, i.e. the json to send to the api

=back

=cut

sub display_generic_confirmation {
    my ( $c, $mode, $name, $page_type, $attributes ) = @_;
    my $type = $page_type;
    $type =~ s/s$//;
    my $nice_name = $name;
    $nice_name =~ s/_/ /g;
    my $generic_form;
    $generic_form .= $q->p("Are you sure you want to $mode $nice_name?<br/>");

    if ($attributes) {
        $generic_form .= $q->p("Attributes are: <br/>$attributes<br/>");
    }
    $generic_form .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $generic_form .= $q->hidden( 'page_type', $page_type );
    $generic_form .= $q->hidden( $type,       $name );
    $generic_form .= $q->hidden( 'mode',      $mode );

    if ( $mode eq "delete" ) {
        $generic_form .= $q->checkbox( 'cascading', 0, 'true',
            'Use cascading delete - WARNING' );
    }
    elsif ($attributes) {
        $generic_form .= $q->hidden( 'attributes', $attributes );
    }
    $generic_form .= $q->submit(
        -name  => 'confirm',
        -value => 'Confirm'
    );
    $generic_form .= $q->end_form;
    return $generic_form;
}

=head2 display_multi_select

This function returns javascript for multi select

=head3 Parameters

=over

=item *

$id for select

=item *

@input - array of items

=back

=cut

sub display_multi_select {
    my ( $id, @input ) = @_;
    my $html  = '';
    my @items = sort @input;

    # Dont try with too many items, or it will fail
    if ( scalar @items > 300 ) {
        $html .=
            '<a href=\'#\' id=\'select-300'
          . $id
          . '\'>Select first 300</a><br>' . "\n";
    }
    else {
        $html .=
            '<a href=\'#\' id=\'select-all'
          . $id
          . '\'>Select all</a><br>' . "\n";
    }
    $html .=
      '<a href=\'#\' id=\'deselect-all' . $id . '\'>Deselect all</a>' . "\n";
    $html .= '<script type="text/javascript">' . "\n";
    $html .= ';(function($) {' . "\n";
    $html .= '$(\'#' . $id . '\').multiSelect({ ' . "\n";
    $html .= 'selectableHeader: "<div>Available items</div>",' . "\n";
    $html .= 'selectionHeader: "<div>Selected items</div>",' . "\n";
    $html .= '});' . "\n";

    if ( scalar @items > 300 ) {
        $html .= '$(\'#select-300' . $id . '\').click(function(){' . "\n";
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
        $html .= '$(\'#select-all' . $id . '\').click(function(){' . "\n";
        $html .= '$(\'#' . $id . '\').multiSelect(\'select_all\');' . "\n";
        $html .= 'return false;' . "\n";
        $html .= '});' . "\n";
    }
    $html .= '$(\'#deselect-all' . $id . '\').click(function(){' . "\n";
    $html .= '$(\'#' . $id . '\').multiSelect(\'deselect_all\');' . "\n";
    $html .= 'return false;' . "\n";
    $html .= '});' . "\n";
    $html .= "})(jQuery);\n";
    $html .= "</script>\n";
    return $html;
}

=head2 display_service_confirmation

This function gets a confirmation dialog

=head3 Parameters

=over

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
    my ( $mode, $host, $servicename, $attributes ) = @_;
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
    $service_form .= $q->hidden( 'service', $servicename );
    if ( $mode eq "delete" ) {
        $service_form .= $q->checkbox( 'cascading', 0, 'true',
            'Use cascading delete - WARNING' );
    }
    $service_form .= $q->submit(
        -name  => 'confirm',
        -value => 'Confirm'
    );
    $service_form .= $q->end_form;
}

=head2 display_service_selection

This function gets the service selection

=head3 Parameters

=over

=item *

$c - a context

=item *

$mode, create, delete or modify

=item *

$host

=back

=cut

sub display_service_selection {
    my ( $c, $mode, $host ) = @_;
    my $service_form;

    # Get services
    my %services = ();
    foreach my $hash ( $c->stash->{services} ) {
        foreach my $service ( values @{$hash} ) {
            $services{ $service->{host_name} }{ $service->{description} } =
              $service->{display_name};
        }
    }
    $service_form .= $q->p("Enter service to $mode for host: $host ");
    $service_form .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $service_form .= '<select name="service">';

    # Loop all services asscoiated with the host
    foreach my $service ( sort keys %{ $services{$host} } ) {
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

$mode, create, delete or modify

=item *

$page_type, services, hosts etc

=back

=cut

sub display_single_host_selection {
    my ( $c, $mode, $page_type ) = @_;
    my $service_form;

    # Get services
    my %services = ();
    foreach my $hash ( $c->stash->{services} ) {
        foreach my $service ( values @{$hash} ) {
            $services{ $service->{host_name} }{ $service->{description} } =
              $service->{display_name};
        }
    }
    $service_form = $q->p("Enter host to $mode");
    $service_form .= $q->start_form(
        -method => $METHOD,
        -action => "api_conf.cgi"
    );
    $service_form .=
      display_select( "host", "host-select", "", sort keys %services );
    $service_form .= $q->hidden( 'page_type', $page_type );
    $service_form .= $q->hidden( 'mode',      $mode );
    $service_form .= $q->submit(
        -name  => 'submit',
        -value => 'Submit'
    );
    $service_form .= $q->end_form;
    return $service_form;
}

=head2 display_select

This function create a select object from an array

=head3 Parameters

=over

=item *

$name - the name for the select

=item *

$id - the html id of the select

=item *

$multiple - true if you want to be able to select more than one item

=back

=cut

sub display_select {
    my ( $name, $id, $multiple, @arr ) = @_;
    my $mult  = "";
    my @items = sort @arr;
    if ($multiple) {
        $mult = "multiple='multiple'";
    }
    my $select .= "<select name='$name' id='$id' $mult>\n";
    for my $elem (@items) {
        $select .= "<option value=\"$elem\">$elem</option>\n";
    }
    $select .= "</select>\n";

    return $select;

}

=head2 display_download_button

This function create a download button for json files

=head3 Parameters

=over

=item *

$c - a context

=item *

$endpoint - endpoint (e.g. objects/hosts/<hostname>)

=item *

$page_type - hosts, services etc

=back

=cut

sub display_download_button {
    my ( $c, $endpoint, $page_type ) = @_;
    my $json = get_json( $c, $endpoint, get_keys( $page_type, "true" ) );
    my $filename = $endpoint;
    $filename =~ s/\//_/g;
    $filename .= ".json";
    my $html = '<button type="button" id="dwlbutton" >Export object</button>';
    $html .= '<script type="text/javascript">function download() {
  var element = document.createElement("a");
  var text = ' . $json . ';
  element.setAttribute("href", "data:text/plain;charset=utf-8," + encodeURIComponent(JSON.stringify(text, "", 2)));
  element.setAttribute("download", "' . $filename . '");

  element.style.display = "none";
  document.body.appendChild(element);

  element.click();

  document.body.removeChild(element);
}
document.getElementById ("dwlbutton").addEventListener ("click", download, false);
</script>';

    return $html;

}

=head2 get_defaults

This function gets default json for the editor

=head3 Parameters

=over

=item *

$page_type - hosts, services etc

=back

=cut

sub get_defaults {

    my ($page_type) = @_;

    my @keys = get_keys($page_type);

    my %to_json;

    # Initialize to null for all, over write below
    foreach my $key ( sort @keys ) {
        $to_json{"attrs"}{$key} = undef;
    }

    if ( $page_type eq "commands" ) {
        $to_json{"attrs"}{"arguments"} = {
            "--wps_id"      => { "order" => -2, "value" => '$wps_id$' },
            "--wrapper_cmd" => {
                "order" => -1,
                "value" => "/local/icinga2/PluginDir/check_su_example"
            },
            "-H" => { "value" => '$host.name$' },
            "-C" => { "value" => "%%PASSWORD%%" },
            "-w" => { "value" => 2 },
            "-c" => { "value" => 3 }
        };
        $to_json{"attrs"}{"command"}   = ["/local/wps/libexec/wrapper_su_wps"];
        $to_json{"attrs"}{"templates"} = ["plugin-check-command"];
    }
    elsif ( $page_type eq "contactgroups" ) {
        $to_json{"attrs"}{"display_name"} = "Example name";

    }
    elsif ( $page_type eq "contacts" ) {
        $to_json{"attrs"}{"display_name"} = "Example Name";
        $to_json{"attrs"}{"email"}        = 'example.name@su.se';
        $to_json{"attrs"}{"pager"}        = "4612345678";
        $to_json{"attrs"}{"enable_notifications"} =
          bless( do { \( my $o = 1 ) }, 'JSON::XS::Boolean' );
        $to_json{"attrs"}{"groups"} = [ "Example group1", "Example groups2" ];
        $to_json{"attrs"}{"period"} = "24x7";
        $to_json{"attrs"}{"states"} = [ "Critical", "Unknown" ];

    }
    elsif ( $page_type eq "hostdependencies" ) {

    }
    elsif ( $page_type eq "hostescalations" ) {

    }
    elsif ( $page_type eq "hostgroups" ) {

    }
    elsif ( $page_type eq "hosts" ) {
        $to_json{"attrs"}{"address"}        = "127.0.0.1";
        $to_json{"attrs"}{"check_command"}  = "hostalive";
        $to_json{"attrs"}{"check_interval"} = 60;
        $to_json{"attrs"}{"check_period"}   = "24x7";
        $to_json{"attrs"}{"display_name"}   = "example-prod-srv01.it.su.se";
        $to_json{"attrs"}{"icon_image"}     = "base/linux40.png";
        $to_json{"attrs"}{"icon_image_alt"} = "Linux";
        $to_json{"attrs"}{"templates"}      = ["linux-host"];
        $to_json{"attrs"}{"vars"}           = {
            "graphite_prefix" => "server",
            "os"              => "linux",
            "ticket_queue"    => "linfra"
        };
        $to_json{"attrs"}{"zone"}           = "master";
        $to_json{"attrs"}{"groups"}         = [ "hdbe", "surveillance" ];
        $to_json{"attrs"}{"retry_interval"} = 30;

    }
    elsif ( $page_type eq "servicedependencies" ) {

    }
    elsif ( $page_type eq "serviceescalations" ) {

    }
    elsif ( $page_type eq "servicegroups" ) {

    }
    elsif ( $page_type eq "services" ) {
        $to_json{"attrs"}{"check_command"}  = "su_example";
        $to_json{"attrs"}{"check_interval"} = 300;
        $to_json{"attrs"}{"check_period"}   = "24x7";
        $to_json{"attrs"}{"display_name"}   = "Example Name";

    }
    elsif ( $page_type eq "timeperiods" ) {

    }
    unless ( $to_json{"attrs"}{"vars"} ) {
        $to_json{"attrs"}{"vars"} = {};
    }
    my $json = JSON->new;
    $json->pretty->canonical(1);

    my $json_text = $json->pretty->encode( \%to_json );

    return $json_text;
}

=head2 get_json

This function gets the editable json of a configuration object

=head3 Parameters

=over

=item *
$c - a context
=item *

$endpoint (e.g. objects/services/<hostname>!<servicename>)

=item *

@keys to extract from "attrs" ("vars", "action_url", "check_command" ...)

=back

=cut

sub get_json {
    my ( $c, $endpoint, @keys ) = @_;
    my $result = api_call( $c, "GET", $endpoint );
    my %to_json;
    foreach my $key ( sort @keys ) {
        $to_json{"attrs"}{$key} = $result->{"results"}[0]{"attrs"}{$key};
    }
    my $json = JSON->new;
    $json->pretty->canonical(1);
    return $json->pretty->encode( \%to_json );
}

=head2 get_keys

This function create a download button for json files

=head3 Parameters

=over

=item *

$page_type - hosts, services etc

=item *

$dl - is this meant for download/creation or modification

=back

=cut

sub get_keys {
    my ( $page_type, $dl ) = @_;
    my @keys;
    my @dl_keys;
    if ( $page_type eq "commands" ) {
        @keys    = @command_keys;
        @dl_keys = @command_dl_keys;
    }
    elsif ( $page_type eq "contactgroups" ) {
        @keys    = @contactgroup_keys;
        @dl_keys = @contactgroup_dl_keys;
    }
    elsif ( $page_type eq "contacts" ) {
        @keys    = @contact_keys;
        @dl_keys = @contact_dl_keys;
    }
    elsif ( $page_type eq "hostdependencies" ) {
        @keys    = @hostdependency_keys;
        @dl_keys = @hostdependency_dl_keys;
    }
    elsif ( $page_type eq "hostescalations" ) {
        @keys    = @hostescalation_keys;
        @dl_keys = @hostescalation_dl_keys;

    }
    elsif ( $page_type eq "hostgroups" ) {
        @keys    = @hostgroup_keys;
        @dl_keys = @hostgroup_dl_keys;

    }
    elsif ( $page_type eq "hosts" ) {
        @keys    = @host_keys;
        @dl_keys = @host_dl_keys;

    }
    elsif ( $page_type eq "servicedependencies" ) {

        @keys    = @servicedependency_keys;
        @dl_keys = @servicedependency_dl_keys;
    }
    elsif ( $page_type eq "serviceescalations" ) {

        @keys    = @serviceescalation_keys;
        @dl_keys = @serviceescalation_dl_keys;
    }
    elsif ( $page_type eq "servicegroups" ) {

        @keys    = @servicegroup_keys;
        @dl_keys = @servicegroup_dl_keys;
    }
    elsif ( $page_type eq "services" ) {

        @keys    = @service_keys;
        @dl_keys = @service_dl_keys;
    }

    elsif ( $page_type eq "timeperiods" ) {
        @keys    = @timeperiod_keys;
        @dl_keys = @timeperiod_dl_keys;

    }
    if ($dl) {
        return @dl_keys;
    }
    else {
        return @keys;
    }
}

=head2 selector

This displays the main scroll list och different type of objects

=cut

sub selector {

    # These are the different kinds of objects we can manipulate
    my %pagetypes = (
        'contacts'      => 'Contacts',
        'contactgroups' => 'Contact Groups',
        'commands'      => 'Commands',
        'hosts'         => 'Hosts',
        'services'      => 'Services',

    #	'hostdependencies' => 'Host Dependencies',
    #	'hostescalations' => 'Host Escalations',
    #	'hostgroups' => 'Host Groups', # Create and delete is implemented for this
    #	'servicegroups' => 'Service Groups',
    #	'servicedependencies' => 'Service Dependencies',
    #	'serviceescalations' => 'Service Escalations',
    #	'timeperiods' => 'Timeperiods',
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

    my $params = $c->req->parameters;

    #Extract parameters from the request
    my @hosts = ();
    my $host  = '';
    if ( ref $params->{'host'} eq 'ARRAY' ) {
        foreach my $hst ( values @{ $params->{'host'} } ) {
            push @hosts, $hst;
        }
        $host = $hosts[0];
    }
    else {
        $host = $params->{'host'};
        push @hosts, $host;
    }
    my $attributes = $params->{'attributes'};
    my $cascading  = $params->{'cascading'};
    my $confirm    = $params->{'confirm'};
    my $mode       = $params->{'mode'};
    my $submit     = $params->{'submit'};

    unless ($mode) {
        $mode = "";
    }
    unless ($confirm) {
        $confirm = "";
    }

    # Get hosts
    my @temp_arr;
    for my $hashref ( values @{ $c->stash->{hosts} } ) {
        push @temp_arr, $hashref->{name};
    }
    my @host_arr = sort @temp_arr;

    # Delete mode
    if ( $mode eq "delete" ) {

        # This case is first dialog
        if ( not defined($confirm) and $host =~ m/\..*\./ ) {
            $host_page .=
              display_delete_confirmation( 'host', 'hosts', @hosts );
        }

        # This case is delete request
        elsif ( $confirm eq "Confirm" and $host =~ m/\..*\./ ) {
            my $cascade = '';
            if ( $cascading eq "true" ) {
                $cascade = '?cascade=1';
            }
            foreach my $hst (@hosts) {
                my @arr =
                  api_call( $c, "DELETE", "objects/hosts/$hst$cascade" );
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
              display_select( "host", "host-select", "true", @host_arr );
            $host_page .= $q->hidden( 'page_type', "hosts" );
            $host_page .= $q->hidden( 'mode',      "delete" );
            $host_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $host_page .= $q->end_form;
            $host_page .= display_multi_select( 'host-select', @host_arr );
        }

    }

    # This is create mode
    elsif ( $mode eq "create" ) {

        # This case is the  actual creation
        if ( $host and $attributes and $confirm eq "Confirm" ) {
            my $payload = uri_unescape($attributes);
            my @arr = api_call( $c, "PUT", "objects/hosts/$host", $payload );
            $host_page .= display_api_response( @arr, $payload );
            $host_page .= display_back_button( $mode, 'hosts' );

        }

        # This case is confirm dialog
        elsif ( $host and $attributes ) {
            $host_page .=
              display_generic_confirmation( $c, $mode, $host, "hosts",
                $attributes );

        }

        # This is the main host creation dialog
        else {
            $host_page .= display_editor("hosts");
        }
    }
    elsif ( $mode eq "modify" ) {

        # This is where we make api call
        if ( $host and $attributes and $confirm eq "Confirm" ) {

            # Do api magic here
            my $payload = uri_unescape($attributes);
            my @arr = api_call( $c, "POST", "objects/hosts/$host", $payload );
            $host_page .= display_api_response( @arr, $payload );
            $host_page .= display_back_button( $mode, 'hosts' );

        }

        # This is where we show confirm
        elsif ( $host and $attributes and $submit eq "Submit" ) {
            $host_page .=
              display_generic_confirmation( $c, $mode, $host, "hosts",
                $attributes );

        }

        # This is where we edit
        elsif ($host) {
            my %hidden = ( "host" => $host );
            my $endpoint = "objects/hosts/$host";
            $host_page .= display_editor( "hosts", \%hidden, $c, $endpoint );

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

TODO: Implement this, it is not done yet and not visible

=cut

sub host_groups {

    # $c holds all our context info
    my ($c) = @_;

    # $host_page is the html for the hosts
    my $hostgroup_page =
      '<div class="reportSelectTitle" align="center">Host Groups</div>';

    my $params = $c->req->parameters;

    #Extract parameters from the request
    my $hostgroup   = $params->{'hostgroup'};
    my $displayname = $params->{'displayname'};
    my $confirm     = $params->{'confirm'};
    my $cascading   = $params->{'cascading'};
    my $mode        = $params->{'mode'};
    my $templates   = $params->{'templates'};

    unless ($mode) {
        $mode = "";
    }
    unless ($confirm) {
        $confirm = "";
    }

    # Get hosts
    my @temp_arr;
    for my $hashref ( values @{ $c->stash->{hosts} } ) {
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

        }

        # If we have both hostgroup and confirm, i.e. we  create via api call
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
            my @arr =
              api_call( $c, "PUT", "objects/hostgroups/$hostgroup", $payload );
            $hostgroup_page .= display_api_response( @arr, $payload );
            $hostgroup_page .= display_back_button( $mode, 'hostgroups' );

        }

        # This is the create dialog
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

        }

        # If we have both hostgroup and confirm, i.e. we delete via api call
        elsif ( $hostgroup =~ m/.+/ and $confirm eq "Confirm" ) {
            my $cascade = '';
            if ( $cascading eq "true" ) {
                $cascade .= '?cascade=1';
            }
            my @arr =
              api_call( $c, "DELETE", "objects/hostgroups/$hostgroup$cascade" );
            $hostgroup_page .= display_api_response(@arr);
            $hostgroup_page .= display_back_button( $mode, 'hostgroups' );

        }

        # Fall back on a drop down list
        else {
            $hostgroup_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $hostgroup_page .= $q->p("Enter hostgroupname:");
            $hostgroup_page .= '<select name="hostgroup">';
            foreach my $hostgroup ( values @{ $c->stash->{hostgroups} } ) {
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
    my ($c) = @_;
    my $params = $c->req->parameters;

    # Capture parameters sent to page by user dialogs
    my $mode = $params->{'mode'};
    my $confirm = $params->{'confirm'};
    unless ($mode) {
        $mode = "";
    }
    unless ($confirm) {
        $confirm = "";
    }
    return "Host Escalations Placeholder";
}

=head2 host_dependencies

TODO: Implement this

=cut

sub host_dependencies {
    my ($c) = @_;
    my $params = $c->req->parameters;

    # Capture parameters sent to page by user dialogs
    my $attributes = $params->{'attributes'};
    my $cascading  = $params->{'cascading'};
    my $command    = $params->{'command'};
    my $confirm    = $params->{'confirm'};
    my $mode       = $params->{'mode'};
    unless ($mode) {
        my $mode = "";
    }
    unless ($confirm) {
        $confirm = "";
    }
    return "Host Dependencies Placeholder";
}

=head2 services

This is where we produce the services page_type

=cut

sub services {
    my ($c) = @_;
    my $params = $c->req->parameters;

    #Get host and see if this is the delete request or not
    my @hosts = ();
    my $host  = '';
    if ( ref $params->{'host'} eq 'ARRAY' ) {
        foreach my $hst ( values @{ $params->{'host'} } ) {
            push @hosts, $hst;
        }
        $host = $hosts[0];
    }
    else {
        $host = $params->{'host'};
        push @hosts, $host;
    }
    my $attributes  = $params->{'attributes'};
    my $cascading   = $params->{'cascading'};
    my $confirm     = $params->{'confirm'};
    my $mode        = $params->{'mode'};
    my $servicename = $params->{'service'};
    my $submit      = $params->{'submit'};

    unless ($mode) {
        $mode = "";
    }
    unless ($confirm) {
        $confirm = "";
    }

    my $service_page =
      '<div class="reportSelectTitle" align="center">Services</div>';

    # Get services
    my %services = ();
    foreach my $hash ( $c->stash->{services} ) {
        foreach my $service ( values @{$hash} ) {
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

        }

        # This case is confirmation dialog for delete mode
        elsif ( $host =~ m/\..*\./
            and $confirm ne "Confirm"
            and $servicename =~ m/.+/ )
        {
            $service_page .=
              display_service_confirmation( $mode, $host, $servicename );

        }

        # This case is actual deletion via api_call
        elsif ( $host =~ m/\..*\./
            and $confirm eq "Confirm"
            and $servicename =~ m/.+/ )
        {
            my $cascade = '';
            if ( $cascading eq "true" ) {
                $cascade = '?cascade=1';
            }
            my @arr = api_call( $c,
                "DELETE", "objects/services/$host!$servicename$cascade" );
            $service_page .= display_api_response(@arr);
            $service_page .= display_back_button( $mode, 'services' );

        }

        # Host selection dialog i.e. the main dialog for service deletion
        else {
            $service_page .=
              display_single_host_selection( $c, $mode, "services" );
        }

    }

    # Creation mode
    elsif ( $mode eq "create" ) {

        # This is the actual creation via api_call
        if ( $host and $attributes and $confirm eq "Confirm" ) {
            my $payload = uri_unescape($attributes);
            foreach my $hst (@hosts) {
                my @arr = api_call( $c,
                    "PUT", "objects/services/$hst!$servicename", $payload );
                $service_page .= display_api_response( @arr, $payload );
            }
            $service_page .= display_back_button( $mode, 'services' );

        }

        # This is the confirm dialog
        elsif ( $host and $attributes ) {
            my $hoststr = csv_from_arr(@hosts);
            $service_page .=
                '<p>Are you sure you want to add the service '
              . $servicename
              . ' with attributes: '
              . $attributes
              . ' to the host(s): '
              . $hoststr
              . '?</p><br/>';
            $service_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            foreach my $hst (@hosts) {
                $service_page .= $q->hidden( 'host', $hst );
            }
            $service_page .= $q->hidden( 'attributes', $attributes );
            $service_page .= $q->hidden( 'mode',       "create" );
            $service_page .= $q->hidden( 'page_type',  "services" );
            $service_page .= $q->hidden( 'service',    $servicename );
            $service_page .= $q->submit(
                -name  => 'confirm',
                -value => 'Confirm'
            );
            $service_page .= $q->end_form;

        }

        # This is the main dialog for service creation
        else {

            # Get hosts
            my @temp_arr;
            for my $hashref ( values @{ $c->stash->{hosts} } ) {
                push @temp_arr, $hashref->{name};
            }
            my @host_arr = sort @temp_arr;
            $service_page .= $q->p('Select host(s) to modify:');
            $service_page .= $q->start_form(
                -method   => $METHOD,
                -action   => "api_conf.cgi",
                -id       => "JSONForm",
                -onSubmit => "return validateJSON()"
            );
            $service_page .=
              '<select name="host" id="host-select" multiple="multiple"">';
            for my $ho (@host_arr) {
                my $selected = '';
                if ( $host eq $ho ) {
                    $selected = 'selected="selected" ';
                }
                $service_page .= "<option value=\"$ho\" $selected>$ho</option>";
            }
            $service_page .= '</select><br>';
            $service_page .= display_multi_select( "host-select", @host_arr );
            $service_page .= display_editor("services");
            $service_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $service_page .= $q->end_form;
        }

    }

    # This is the modification section
    elsif ( $mode eq "modify" ) {

        # This is the editor
        if ( $host and $servicename and $attributes and $confirm eq "Confirm" )
        {
            # Do api magic here
            my $payload = uri_unescape($attributes);
            my @arr     = api_call( $c,
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
              display_service_confirmation( $mode, $host, $servicename,
                $attributes );
        }
        elsif ( $host and $servicename ) {
            my %hidden = (
                "host"    => $host,
                "service" => $servicename
            );
            $service_page .=
              display_editor( "services", \%hidden, $c,
                "objects/services/$host!$servicename" );
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

This is where we handle contacts/users

=cut

sub contacts {
    my ($c) = @_;
    my $params = $c->req->parameters;

    # Capture parameters sent to page by user dialogs
    my $attributes = $params->{'attributes'};
    my $confirm    = $params->{'confirm'};

    my @contacts = ();
    my $contact  = '';
    if ( ref $params->{'contact'} eq 'ARRAY' ) {
        foreach my $cnt ( values @{ $params->{'contact'} } ) {
            push @contacts, $cnt;
        }
        $contact = $contacts[0];
    }
    else {
        $contact = $params->{'contact'};
        push @contacts, $contact;
    }

    my $cascading = $params->{'cascading'};
    my $mode      = $params->{'mode'};
    my $submit    = $params->{'submit'};

    unless ($mode) {
        $mode = "";
    }
    unless ($confirm) {
        $confirm = "";
    }

    my @temp_arr;
    for my $hashref ( values @{ $c->{'db'}->get_contacts() } ) {
        push @temp_arr, $hashref->{'name'};
    }
    my @contact_arr = sort @temp_arr;

    my $contacts_page =
      '<div class="reportSelectTitle" align="center">Contacts</div>';

    if ( $mode eq "create" ) {

        # This is the contact confirmation api call
        if ( $contact and $attributes and $confirm eq "Confirm" ) {
            my $payload = uri_unescape($attributes);
            my @arr = api_call( $c, "PUT", "objects/users/$contact", $payload );
            $contacts_page .= display_api_response( @arr, $payload );
            $contacts_page .= display_back_button( $mode, 'contacts' );

            # This is the contact creation confirmation
        }
        elsif ( $contact and $submit eq "Submit" ) {
            $contacts_page .=
              display_generic_confirmation( $c, $mode, $contact, "contacts",
                $attributes )

              # This is the contact creation dialog
        }
        else {
            $contacts_page .= display_editor("contacts");
        }

    }
    elsif ( $mode eq "delete" ) {

        # This is api call
        if ( $contact and $confirm eq "Confirm" ) {
            my $cascade = '';
            if ( $cascading eq "true" ) {
                $cascade = '?cascade=1';
            }
            foreach my $cnt (@contacts) {
                my @arr =
                  api_call( $c, "DELETE", "objects/users/$cnt$cascade" );
                $contacts_page .= display_api_response(@arr);
            }
            $contacts_page .= display_back_button( $mode, 'contacts' );
        }

        # This is confirmation
        elsif ($contact) {
            $contacts_page .=
              display_delete_confirmation( 'contact', 'contacts', @contacts );
        }

        # This is selection
        else {
            $contacts_page .= $q->p("Select contact(s) to delete:");
            $contacts_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $contacts_page .=
              display_select( "contact", "contact-select", "true",
                @contact_arr );
            $contacts_page .= $q->hidden( 'page_type', "contacts" );
            $contacts_page .= $q->hidden( 'mode',      "delete" );
            $contacts_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $contacts_page .= $q->end_form;
            $contacts_page .=
              display_multi_select( 'contact-select', @contact_arr );
        }

    }
    elsif ( $mode eq "modify" ) {

        # This is api call
        if ( $contact and $attributes and $confirm eq "Confirm" ) {

            # Do api magic here
            my $payload = uri_unescape($attributes);
            my @arr =
              api_call( $c, "POST", "objects/users/$contact", $payload );
            $contacts_page .= display_api_response( @arr, $payload );
            $contacts_page .= display_back_button( $mode, 'contacts' );
        }

        # This is confirmation
        elsif ( $contact and $attributes and $submit eq "Submit" ) {
            $contacts_page .=
              display_generic_confirmation( $c, $mode, $contact, "contacts",
                $attributes );
        }

        # This is editor
        elsif ($contact) {
            my %hidden = ( "contact" => $contact );
            my $endpoint = "objects/users/$contact";
            $contacts_page .=
              display_editor( "contacts", \%hidden, $c, $endpoint );
        }

        # This is selection
        else {
            $contacts_page .= $q->p("Select contact to edit:");
            $contacts_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $contacts_page .=
              display_select( "contact", "contact-select", "", @contact_arr );
            $contacts_page .= $q->hidden( 'page_type', "contacts" );
            $contacts_page .= $q->hidden( 'mode',      "modify" );
            $contacts_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $contacts_page .= $q->end_form;
        }

    }
    else {
        $contacts_page .= display_create_delete_modify_dialog("contacts");
    }

    return $contacts_page;
}

=head2 contact_groups

This is where we handle contact/user groups

=cut

sub contact_groups {

    my ($c) = @_;

    my $params = $c->req->parameters;

    my $attributes   = $params->{'attributes'};
    my $cascading    = $params->{'cascading'};
    my $confirm      = $params->{'confirm'};
    my $contactgroup = $params->{'contactgroup'};
    my $mode         = $params->{'mode'};
    my $submit       = $params->{'submit'};

    unless ($mode) {
        $mode = "";
    }
    unless ($confirm) {
        $confirm = "";
    }

    my @groups = ();
    my $group  = '';
    if ( ref $params->{'groups'} eq 'ARRAY' ) {
        foreach my $grp ( values @{ $params->{'groups'} } ) {
            push @groups, $grp;
        }
        $group = $groups[0];
    }
    else {
        $group = $params->{'groups'};
        push @groups, $group;
    }

    my @temp_arr;
    for my $hashref ( values @{ $c->{'db'}->get_contactgroups() } ) {
        push @temp_arr, $hashref->{'name'};
    }
    my @contactgroups_arr = sort @temp_arr;

    my $contactgroups_page =
      '<div class="reportSelectTitle" align="center">Contact Groups</div>';

    if ( $mode eq "create" ) {

        # This is api call
        if ( $contactgroup and $attributes and $confirm eq "Confirm" ) {
            my $payload = uri_unescape($attributes);
            my @arr     = api_call( $c,
                "PUT", "objects/usergroups/$contactgroup", $payload );
            $contactgroups_page .= display_api_response( @arr, $payload );
            $contactgroups_page .=
              display_back_button( $mode, 'contactgroups' );

        }

        # This is confirmation
        elsif ( $contactgroup and $attributes ) {
            $contactgroups_page .=
              display_generic_confirmation( $c, $mode, $contactgroup,
                "contactgroups", $attributes );

        }

        # This is creation dialog
        else {
            $contactgroups_page .= display_editor("contactgroups");
        }

    }
    elsif ( $mode eq "delete" ) {

        # This is api call
        if ( $group and $confirm eq "Confirm" ) {
            my $cascade = '';
            if ( $cascading eq "true" ) {
                $cascade = '?cascade=1';
            }
            foreach my $grp (@groups) {
                my @arr =
                  api_call( $c, "DELETE", "objects/usergroups/$grp$cascade" );
                $contactgroups_page .= display_api_response(@arr);
            }
            $contactgroups_page .=
              display_back_button( $mode, 'contactgroups' );
        }

        # This is confirmation
        elsif ($group) {
            $contactgroups_page .=
              display_delete_confirmation( 'groups', 'contactgroups', @groups );
        }

        # This is selection
        else {
            $contactgroups_page .= $q->p("Select contactgroup(s) to delete:");
            $contactgroups_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $contactgroups_page .=
              display_select( "groups", "group-select", "true",
                @contactgroups_arr );
            $contactgroups_page .= $q->hidden( 'page_type', "contactgroups" );
            $contactgroups_page .= $q->hidden( 'mode',      "delete" );
            $contactgroups_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $contactgroups_page .= $q->end_form;
            $contactgroups_page .=
              display_multi_select( 'group-select', @contactgroups_arr );
        }

    }
    elsif ( $mode eq "modify" ) {

        # This is api call
        if ( $contactgroup and $attributes and $confirm eq "Confirm" ) {

            # Do api magic here
            my $payload = uri_unescape($attributes);
            my @arr     = api_call( $c, "POST",
                "objects/usergroups/$contactgroup", $payload );
            $contactgroups_page .= display_api_response( @arr, $payload );
            $contactgroups_page .=
              display_back_button( $mode, 'contactgroups' );
        }

        # This is confirmation
        elsif ( $contactgroup and $attributes and $submit eq "Submit" ) {
            $contactgroups_page .=
              display_generic_confirmation( $c, $mode, $contactgroup,
                "contactgroups", $attributes );
        }

        # This is editor
        elsif ($contactgroup) {
            my %hidden = ( "contactgroup" => $contactgroup );
            my $endpoint = "objects/usergroups/$contactgroup";
            $contactgroups_page .=
              display_editor( "contactgroups", \%hidden, $c, $endpoint );
        }

        # This is selection
        else {
            $contactgroups_page .= $q->p("Select contact group to edit:");
            $contactgroups_page .= $q->start_form(
                -method => $METHOD,
                -action => "api_conf.cgi"
            );
            $contactgroups_page .=
              display_select( "contactgroup", "contactgroup-select", "",
                @contactgroups_arr );
            $contactgroups_page .= $q->hidden( 'page_type', "contactgroups" );
            $contactgroups_page .= $q->hidden( 'mode',      "modify" );
            $contactgroups_page .= $q->submit(
                -name  => 'submit',
                -value => 'Submit'
            );
            $contactgroups_page .= $q->end_form;
        }
    }
    else {
        $contactgroups_page .=
          display_create_delete_modify_dialog("contactgroups");
    }

    return $contactgroups_page;
}

=head2 timeperiods

TODO: Implement this

=cut

sub timeperiods {
    my ($c) = @_;
    my $params = $c->req->parameters;

    # Capture parameters sent to page by user dialogs
    my $attributes = $params->{'attributes'};
    my $cascading  = $params->{'cascading'};
    my $command    = $params->{'command'};
    my $confirm    = $params->{'confirm'};
    my $mode       = $params->{'mode'};
    unless ($mode) {
        $mode = "";
    }
    unless ($confirm) {
        $confirm = "";
    }

    return "Timeperiods Placeholder";
}

=head2 commands

This is the page_type commands

=cut

sub commands {
    my ($c) = @_;
    my $params = $c->req->parameters;

    # Capture parameters sent to page by user dialogs
    my $attributes = $params->{'attributes'};
    my $cascading  = $params->{'cascading'};
    my $command    = $params->{'command'};
    my $confirm    = $params->{'confirm'};
    my $mode       = $params->{'mode'};
    my $submit     = $params->{'submit'};

    unless ($mode) {
        $mode = "";
    }
    unless ($confirm) {
        $confirm = "";
    }

    my $command_page =
      '<div class="reportSelectTitle" align="center">Commands</div>';

    # This is delete mode
    if ( $mode eq "delete" ) {

        # This case is the confirmation dialog
        if ( $confirm ne "Confirm" and $command =~ m/.+/ ) {
            $command_page .=
              display_generic_confirmation( $c, $mode, $command, "commands" );

        }

        # This is the actual deletion via api call
        elsif ( $confirm eq "Confirm" and $command =~ m/.+/ ) {
            my $cascade = '';
            if ( $cascading eq "true" ) {
                $cascade .= '?cascade=1';
            }
            my @arr = api_call( $c,
                "DELETE", "objects/checkcommands/$command$cascade" );
            $command_page .= display_api_response(@arr);
            $command_page .= display_back_button( $mode, 'commands' );

        }

        # This is the main dialog for command deletion
        else {
            $command_page .= display_command_selection( $c, $mode );
        }

    }

    # Creation dialog
    elsif ( $mode eq "create" ) {

        # This is actual creation via api call
        if ( $confirm eq "Confirm" and $attributes and $command ) {
            my $payload = uri_unescape($attributes);

            my @arr =
              api_call( $c, "PUT", "objects/checkcommands/$command", $payload );
            $command_page .= display_api_response( @arr, $payload );
            $command_page .= display_back_button( $mode, 'commands' );

        }

        # This is confirmation dialog for command creation
        elsif ( $submit eq "Submit" and $command and $attributes ) {
            $command_page .=
              display_generic_confirmation( $c, $mode, $command, "commands",
                $attributes );

        }

        # This is main command creation dialog
        else {
            $command_page .= display_editor("commands");
        }

    }
    elsif ( $mode eq "modify" ) {

        if ( $command and ( $confirm eq "Confirm" ) and $attributes ) {

            # Do api magic here
            my $payload = uri_unescape($attributes);

            my @arr = api_call( $c, "POST",
                "objects/checkcommands/$command", $payload );

            $command_page .= display_api_response( @arr, $payload );
            $command_page .= display_back_button( $mode, 'commands' );

            # Do edit here
        }

        # Do confirmation here
        elsif ( $command and $attributes ) {
            $command_page .=
              display_generic_confirmation( $c, $mode, $command, "commands",
                $attributes );

            # Do api call here
        }
        elsif ( $command and $submit eq "Submit" ) {
            my %hidden = ( "command" => $command );

            my $endpoint = "objects/checkcommands/$command";

            $command_page =
              display_editor( "commands", \%hidden, $c, $endpoint );
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
    unless ($page_type) {
        $page_type = "";
    }
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
    $c->stash->{'infoBoxTitle'}   = 'Configuration Editor';
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'readonly'}       = 0;
    $c->stash->{'subtitle'}       = 'Configuration Editor';
    $c->stash->{'template'}       = 'api_conf.tt';
    $c->stash->{'testmode'}       = 1;
    $c->stash->{'title'}          = 'Configuration Editor';

    # This is data we need to have handy
    $c->stash->{'services'} = $c->{'db'}->get_services(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ] );

    $c->stash->{'hosts'} = $c->{'db'}->get_hosts(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );

    $c->stash->{'hostgroups'} = $c->{'db'}->get_hostgroups(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ) ] );

    $c->stash->{'commands'} = $c->{'db'}->get_commands();

    $c->stash->{body} = body $c;
}

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
