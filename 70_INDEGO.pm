# $Id$
##############################################################################
#
#     70_INDEGO.pm
#     An FHEM Perl module for controlling a Bosch Indego.
#
#     Copyright by Ulf von Mersewsky
#     e-mail: umersewsky at gmail.com
#
#     This file is part of fhem.
#
#     Fhem is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     Fhem is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
#
# Version: 0.1.0
#
##############################################################################

package main;

use 5.012;
use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use HttpUtils;
use JSON qw(decode_json);
use IO::Socket::SSL::Utils qw(PEM_string2cert);
use Digest::SHA qw(hmac_sha256_hex);

sub INDEGO_Set($@);
sub INDEGO_Get($@);
sub INDEGO_GetStatus($;$);
sub INDEGO_Define($$);
sub INDEGO_Undefine($$);

###################################
sub INDEGO_Initialize($) {
    my ($hash) = @_;

    Log3 $hash, 5, "INDEGO_Initialize: Entering";

    $hash->{GetFn}   = "INDEGO_Get";
    $hash->{SetFn}   = "INDEGO_Set";
    $hash->{DefFn}   = "INDEGO_Define";
    $hash->{UndefFn} = "INDEGO_Undefine";

    $hash->{AttrList} = "disable:0,1 " . $readingFnAttributes;

    return;
}

#####################################
sub INDEGO_GetStatus($;$) {
    my ( $hash, $update ) = @_;
    my $name     = $hash->{NAME};
    my $interval = $hash->{INTERVAL};

    Log3 $name, 5, "INDEGO $name: called function INDEGO_GetStatus()";

    RemoveInternalTimer($hash);
    InternalTimer( gettimeofday() + $interval, "INDEGO_GetStatus", $hash, 0 );

    return if ( AttrVal($name, "disable", 0) == 1 );

    # check device availability
    if (!$update) {
      INDEGO_SendCommand( $hash, "state" );
    }

    return;
}

###################################
sub INDEGO_Get($@) {
    my ( $hash, @a ) = @_;
    my $name = $hash->{NAME};
    my $what;

    Log3 $name, 5, "INDEGO $name: called function INDEGO_Get()";

    return "argument is missing" if ( int(@a) < 2 );

    $what = $a[1];

    if ( $what =~ /^(charge)$/ ) {
        if ( defined( $hash->{READINGS}{$what}{VAL} ) ) {
            return $hash->{READINGS}{$what}{VAL};
        } else {
            return "no such reading: $what";
        }
    } else {
        return "Unknown argument $what, choose one of charge:noArg";
    }
}

###################################
sub INDEGO_Set($@) {
    my ( $hash, @a ) = @_;
    my $name  = $hash->{NAME};

    Log3 $name, 5, "INDEGO $name: called function INDEGO_Set()";

    return "No Argument given" if ( !defined( $a[1] ) );

    my $usage = "Unknown argument " . $a[1] . ", choose one of";
    $usage .= " startCleaning:Eco,Turbo" if ( ReadingsVal($name, ".start", "0") );
    $usage .= " startSpot:Eco,Turbo"     if ( ReadingsVal($name, ".start", "0") );
    $usage .= " stop:noArg"              if ( ReadingsVal($name, ".stop", "0") );
    $usage .= " pause:noArg"             if ( ReadingsVal($name, ".pause", "0") );
    $usage .= " resume:noArg"            if ( ReadingsVal($name, ".resume", "0") );
    $usage .= " sendToBase:noArg"        if ( ReadingsVal($name, ".goToBase", "0") );
    $usage .= " schedule:on,off";

    my $cmd = '';
    my $result;


    # start
    if ( $a[1] eq "startCleaning" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1] . " " . $a[2];

        return "No argument given" if ( !defined( $a[2] ) );

        my $params = {
          "category"  => "2",
          "mode"      => $a[2] eq "Eco" ? "1" : "2",
          "modifier"  => "1"
        };
        INDEGO_SendCommand( $hash, "messages", "startCleaning", $params );
    }

    elsif ( $a[1] eq "startSpot" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1] . " " . $a[2];

        return "No argument given" if ( !defined( $a[2] ) );

        my $params = {
          "category"  => "3",
          "mode"      => $a[2] eq "Eco" ? "1" : "2",
          "modifier"  => "1"
        };
        INDEGO_SendCommand( $hash, "messages", "startCleaning", $params );
    }

    # stop
    elsif ( $a[1] eq "stop" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        INDEGO_SendCommand( $hash, "messages", "stopCleaning" );
    }

    # pause
    elsif ( $a[1] eq "pause" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        INDEGO_SendCommand( $hash, "messages", "pauseCleaning" );
    }

    # resume
    elsif ( $a[1] eq "resume" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        INDEGO_SendCommand( $hash, "messages", "resumeCleaning" );
    }

    # stop
    elsif ( $a[1] eq "stop" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        INDEGO_SendCommand( $hash, "messages", "stopCleaning" );
    }

    # sendToBase
    elsif ( $a[1] eq "sendToBase" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        INDEGO_SendCommand( $hash, "messages", "sendToBase" );
    }

    # schedule
    elsif ( $a[1] eq "schedule" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1] . " " . $a[2];

        return "No argument given" if ( !defined( $a[2] ) );

        my $switch = $a[2];
        if ($switch eq "on") {
            INDEGO_SendCommand( $hash, "messages", "enableSchedule" );
        } else {
            INDEGO_SendCommand( $hash, "messages", "disableSchedule" );
        }
    }

    # return usage hint
    else {
        return $usage;
    }

    return;
}

###################################
sub INDEGO_Define($$) {
    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );
    my $name = $hash->{NAME};

    Log3 $name, 5, "INDEGO $name: called function INDEGO_Define()";

    if ( int(@a) < 4 ) {
        my $msg =
          "Wrong syntax: define <name> INDEGO <email> <password> [<poll-interval>]";
        Log3 $name, 4, $msg;
        return $msg;
    }

    $hash->{TYPE} = "INDEGO";

    my $email = $a[2];
    $hash->{helper}{EMAIL} = $email;

    my $password = $a[3];
    $hash->{helper}{PASSWORD} = $password;
    
    # use interval of 300 sec if not defined
    my $interval = $a[4] || 300;
    $hash->{INTERVAL} = $interval;

    unless ( defined( AttrVal( $name, "webCmd", undef ) ) ) {
        $attr{$name}{webCmd} = 'mow:pause:returnToDock';
    }

    # start the status update timer
    RemoveInternalTimer($hash);
    InternalTimer( gettimeofday() + 2, "INDEGO_GetStatus", $hash, 1 );

    return;
}

############################################################################################################
#
#   Begin of helper functions
#
############################################################################################################

###################################
sub INDEGO_SendCommand($$;$$) {
    my ( $hash, $service, $cmd, $params ) = @_;
    my $name        = $hash->{NAME};
    my $email       = $hash->{helper}{EMAIL};
    my $password    = $hash->{helper}{PASSWORD};
    my $timestamp   = gettimeofday();
    my $timeout     = 30;
    my $header;
    my $data;

    Log3 $name, 5, "INDEGO $name: called function INDEGO_SendCommand()";

    my $URL = "https://api.indego.iot.bosch-si.com/api/v1/";
    my $response;
    my $return;
    
    INDEGO_CheckContext($hash) if ($service ne "authenticate");

    if ( !defined($cmd) ) {
        Log3 $name, 4, "INDEGO $name: REQ $service";
    }
    else {
        Log3 $name, 4, "INDEGO $name: REQ $service/$cmd";
    }
    Log3 $name, 4, "INDEGO $name: REQ parameters $params" if (defined($params));

    if ($service eq "authenticate") {
      $URL .= $service;
      $header = "Content-Type: application/json";
      $header .= "\r\nAuthorization: Basic ";
      $header .= encode_base64("$email:$password","");
      $data = "{\"device\":\"\", \"os_type\":\"Android\", \"os_version\":\"4.0\", \"dvc_manuf\":\"unknown\", \"dvc_type\":\"unknown\"}";

    } elsif ($service eq "state" || $service eq "map") {
      $URL .= "alms/";
      $URL .= ReadingsVal($name, "alm_sn", "");
      $URL .= "/$service";
      $header = "x-im-context-id: ".ReadingsVal($name, "contextId", "");

    } elsif ($service eq "metadata") {
      $URL .= "alms/";
      $URL .= ReadingsVal($name, "alm_sn", "");
      $header = "x-im-context-id: ".ReadingsVal($name, "contextId", "");

    }

    # send request via HTTP-POST method
    Log3 $name, 5, "INDEGO $name: POST $URL (" . urlDecode($data) . ")"
      if ( defined($data) );
    Log3 $name, 5, "INDEGO $name: GET $URL"
      if ( !defined($data) );
    Log3 $name, 5, "INDEGO $name: header $header"
      if ( defined($header) );

    HttpUtils_NonblockingGet(
        {
            url         => $URL,
            timeout     => $timeout,
            noshutdown  => 1,
            header      => $header,
            data        => $data,
            hash        => $hash,
            service     => $service,
            cmd         => $cmd,
            timestamp   => $timestamp,
            callback    => \&INDEGO_ReceiveCommand,
        }
    );

    return;
}

###################################
sub INDEGO_ReceiveCommand($$$) {
    my ( $param, $err, $data ) = @_;
    my $hash    = $param->{hash};
    my $name    = $hash->{NAME};
    my $service = $param->{service};
    my $cmd     = $param->{cmd};

    my $rc = ( $param->{buf} ) ? $param->{buf} : $param;
    my $return;
    
    Log3 $name, 5, "INDEGO $name: called function INDEGO_ReceiveCommand() rc: $rc err: $err data: $data ";

    readingsBeginUpdate($hash);

    # device not reachable
    if ($err) {

        if ( !defined($cmd) || $cmd eq "" ) {
            Log3 $name, 4, "INDEGO $name:$service RCV $err";
        } else {
            Log3 $name, 4, "INDEGO $name:$service/$cmd RCV $err";
        }

        # keep last state
        #INDEGO_ReadingsBulkUpdateIfChanged( $hash, "state", "Error" );
    }

    # data received
    elsif ($data) {
      
        if ( !defined($cmd) ) {
            Log3 $name, 4, "INDEGO $name: RCV $service";
        } else {
            Log3 $name, 4, "INDEGO $name: RCV $service/$cmd";
        }

        if ( $data ne "" ) {
            if ( $data =~ /^{/ || $data =~ /^\[/ ) {
                if ( !defined($cmd) || $cmd eq "" ) {
                    Log3 $name, 4, "INDEGO $name: RES $service - $data";
                } else {
                    Log3 $name, 4, "INDEGO $name: RES $service/$cmd - $data";
                }
                $return = decode_json( Encode::encode_utf8($data) );
            } else {
                Log3 $name, 5, "INDEGO $name: RES ERROR $service\n" . $data;
                if ( !defined($cmd) || $cmd eq "" ) {
                    Log3 $name, 5, "INDEGO $name: RES ERROR $service\n$data";
                } else {
                    Log3 $name, 5, "INDEGO $name: RES ERROR $service/$cmd\n$data";
                }
                return undef;
            }
        }

        # state
        if ( $service eq "state" ) {
          if ( ref($return) eq "HASH" ) {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "stateId",              $return->{state});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "mowed",                $return->{mowed});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "mowed_ts",             $return->{mowed_ts});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "mapsvgcache_ts",       $return->{mapsvgcache_ts});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "map_update_available", $return->{map_update_available});
            if ( ref($return->{runtime}) eq "HASH" ) {
              my $runtime = $return->{runtime};
              if ( ref($runtime->{total}) eq "HASH" ) {
                my $total = $runtime->{total};
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "totalOperate", $total->{operate});
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "totalCharge",  $total->{charge});
              }
              if ( ref($runtime->{session}) eq "HASH" ) {
                my $session = $runtime->{session};
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "sessionOperate", $session->{operate});
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "sessionCharge",  $session->{charge});
              }
            }
            if (ReadingsVal($name, "firmware", "") eq "") {
              INDEGO_SendCommand($hash, "metadata");
            }
          }
        }
    
        # metadata
        elsif ( $service eq "metadata" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alm_name",             $return->{alm_name});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "service_counter",      $return->{service_counter});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "bareToolnumber",       $return->{bareToolnumber});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alm_firmware_version", $return->{alm_firmware_version});
          }
        }

        # authenticate
        elsif ( $service eq "authenticate" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "contextId", $return->{contextId});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "userId",    $return->{userId});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alm_sn",    $return->{alm_sn});
          }
        }
    
        # all other command results
        else {
            Log3 $name, 2, "INDEGO $name: ERROR: method to handle response of $service not implemented";
        }

    }

    readingsEndUpdate( $hash, 1 );

    return;
}

###################################
sub INDEGO_Undefine($$) {
    my ( $hash, $arg ) = @_;
    my $name = $hash->{NAME};

    Log3 $name, 5, "INDEGO $name: called function INDEGO_Undefine()";

    # Stop the internal GetStatus-Loop and exit
    RemoveInternalTimer($hash);

    return;
}

sub INDEGO_CheckContext($) {
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  INDEGO_SendCommand($hash, "authenticate") if (ReadingsVal($name, "contextId", "") eq "");
}

sub INDEGO_ReadingsBulkUpdateIfChanged($$$) {
  my ($hash,$reading,$value) = @_;
  my $name = $hash->{NAME};

  readingsBulkUpdate($hash, $reading, $value) if (ReadingsVal($name, $reading, "") ne $value);
}

sub INDEGO_BuildState($$$$) {
    my ($hash,$state,$action,$error) = @_;
    my $states = {
        '1'       => "Ready",
        '2'       => "Action",
        '3'       => "Paused",
        '4'       => "Error"
    };

    if ($state == 2) {
        return INDEGO_GetActionText($action);
    } elsif ($state == 3) {
        return "Paused: ".INDEGO_GetActionText($action);
    } elsif ($state == 4) {
      return INDEGO_GetErrorText($error);
    } elsif (defined( $states->{$state})) {
        return $states->{$state};
    } else {
        return $state;
    }
}

sub INDEGO_GetActionText($) {
    my ($action) = @_;
    my $actions = {
        '0'       => "No Action",
        '1'       => "Cleaning",
        '2'       => "Spot Cleaning",
        '4'       => "Go to Base",
        '5'       => "Setup"
    };

    if (defined( $actions->{$action})) {
        return $actions->{$action};
    } else {
        return $action;
    }
}

sub INDEGO_GetErrorText($) {
    my ($error) = @_;
    my $errors = {
        'ui_alert_invalid'                => 'Ok',
        'ui_alert_dust_bin_full'          => 'Dust Bin Is Full!',
        'ui_alert_recovering_location'    => 'I\'m Recovering My Location!',
        'ui_error_picked_up'              => 'Picked Up!',
        'ui_error_brush_stuck'            => 'Brush Stuck!',
        'ui_error_stuck'                  => 'I\'m Stuck!',
        'ui_error_dust_bin_emptied'       => 'Dust Bin Has Been Emptied!',
        'ui_error_dust_bin_missing'       => 'Dust Bin Is Missing!',
        'ui_error_navigation_falling'     => 'Please Clear My Path!',
        'ui_error_navigation_noprogress'  => 'Please Clear My Path!'
    };

    if (defined( $errors->{$error})) {
        return $errors->{$error};
    } else {
        return $error;
    }
}

sub INDEGO_ShowMap($) {
    my ($name) = @_;
    my $hash = $main::defs{$name};

    INDEGO_SendCommand($hash, "map");
}

sub INDEGO_GetCAKey() {
    my $ca_key = q{-----BEGIN CERTIFICATE-----
MIIE3DCCA8SgAwIBAgIJALHphD11lrmHMA0GCSqGSIb3DQEBBQUAMIGkMQswCQYD
VQQGEwJVUzELMAkGA1UECBMCQ0ExDzANBgNVBAcTBk5ld2FyazEbMBkGA1UEChMS
TmVhdG8gUm9ib3RpY3MgSW5jMRcwFQYDVQQLEw5DbG91ZCBTZXJ2aWNlczEZMBcG
A1UEAxQQKi5uZWF0b2Nsb3VkLmNvbTEmMCQGCSqGSIb3DQEJARYXY2xvdWRAbmVh
dG9yb2JvdGljcy5jb20wHhcNMTUwNDIxMTA1OTA4WhcNNDUwNDEzMTA1OTA4WjCB
pDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAkNBMQ8wDQYDVQQHEwZOZXdhcmsxGzAZ
BgNVBAoTEk5lYXRvIFJvYm90aWNzIEluYzEXMBUGA1UECxMOQ2xvdWQgU2Vydmlj
ZXMxGTAXBgNVBAMUECoubmVhdG9jbG91ZC5jb20xJjAkBgkqhkiG9w0BCQEWF2Ns
b3VkQG5lYXRvcm9ib3RpY3MuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
CgKCAQEAur0WFcJ2YvnL3dtXJFv3lfCQtELLHVcux88tH7HN/FTeUvCqdleDNv4S
mXWgxVOdUUuhV885wppYyXNzDDrwCyjPmYj0m1EZ4FqTCcjFmk+xdEJsPsKPgRt5
QqaO0CA/T7dcIhT/PtQnJtcjn6E6vt2JLhsLz9OazadwjvdkejmfrOL643FGxsIP
8hu3+JINcfxnmff85zshe0yQH5yIYkmQGUPQz061T6mMzFrED/hx9zDpiB1mfkUm
uG3rBVcZWtrdyMvqB9LB1vqKgcCRANVg5S0GKpySudFlHOZjekXwBsZ+E6tW53qx
hvlgmlxX80aybYC5hQaNSQBaV9N4lwIDAQABo4IBDTCCAQkwHQYDVR0OBBYEFM3g
l7v7HP6zQgF90eHIl9coH6jhMIHZBgNVHSMEgdEwgc6AFM3gl7v7HP6zQgF90eHI
l9coH6jhoYGqpIGnMIGkMQswCQYDVQQGEwJVUzELMAkGA1UECBMCQ0ExDzANBgNV
BAcTBk5ld2FyazEbMBkGA1UEChMSTmVhdG8gUm9ib3RpY3MgSW5jMRcwFQYDVQQL
Ew5DbG91ZCBTZXJ2aWNlczEZMBcGA1UEAxQQKi5uZWF0b2Nsb3VkLmNvbTEmMCQG
CSqGSIb3DQEJARYXY2xvdWRAbmVhdG9yb2JvdGljcy5jb22CCQCx6YQ9dZa5hzAM
BgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUAA4IBAQB93p+MUmKH+MQI3pEVvPUW
y+VDB5qt1spE5J0awVwUzhQ7QXkEqgFfOk0kzufvxdha9wz+05E1glQ8l5CzlATu
kA7V5OsygYB+TgqjvhfFHkSI6TJ8OlKcAJuZ2yQE8s2+LVo92NLwpooZLA6BCahn
fX+rzmo6b4ylhyX98Tm3upINNH3whV355PJFgk74fw9N7U6cFlBrqXXssKOse2D2
xY65IK7OQxSq5K5OPFLwN3h/eURo5kwl7jhpJhJbFL4I46OkpgqWHxQEqSxQnS0d
AC62ApwWkm42i0/DGODms2tnGL/DaCiTkgEE+8EEF9kfvQDtMoUDNvIkl7Vvm914
-----END CERTIFICATE-----};

    return PEM_string2cert($ca_key);
}

1;
=pod
=begin html

<a name="INDEGO"></a>
<h3>INDEGO</h3>
<ul>
  This module controls a Bosch Indego.
  <br><br>
  <b>Define</b>
</ul>

=end html
=begin html_DE

<a name="INDEGO"></a>
<h3>INDEGO</h3>
<ul>
  Diese Module dient zur Steuerung eines Bosch Indego
  <br><br>
  <b>Define</b>
</ul>

=end html_DE
=cut
