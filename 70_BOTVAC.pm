# $Id$
##############################################################################
#
#     70_BOTVAC.pm
#     An FHEM Perl module for controlling a Neato BotVacConnected.
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
# Version: 0.1.1
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

sub BOTVAC_Set($@);
sub BOTVAC_Get($@);
sub BOTVAC_GetStatus($;$);
sub BOTVAC_Define($$);
sub BOTVAC_Undefine($$);

###################################
sub BOTVAC_Initialize($) {
    my ($hash) = @_;

    Log3 $hash, 5, "BOTVAC_Initialize: Entering";

    $hash->{GetFn}   = "BOTVAC_Get";
    $hash->{SetFn}   = "BOTVAC_Set";
    $hash->{DefFn}   = "BOTVAC_Define";
    $hash->{UndefFn} = "BOTVAC_Undefine";

    $hash->{AttrList} = "disable:0,1 " . $readingFnAttributes;

    return;
}

#####################################
sub BOTVAC_GetStatus($;$) {
    my ( $hash, $update ) = @_;
    my $name     = $hash->{NAME};
    my $interval = $hash->{INTERVAL};

    Log3 $name, 5, "BOTVAC $name: called function BOTVAC_GetStatus()";

    RemoveInternalTimer($hash);
    InternalTimer( gettimeofday() + $interval, "BOTVAC_GetStatus", $hash, 0 );

    return if ( AttrVal($name, "disable", 0) == 1 );

    # check device availability
    if (!$update) {
      BOTVAC_SendCommand( $hash, "messages", "getRobotState" );
      BOTVAC_SendCommand( $hash, "messages", "getSchedule" );
    }

    return;
}

###################################
sub BOTVAC_Get($@) {
    my ( $hash, @a ) = @_;
    my $name = $hash->{NAME};
    my $what;

    Log3 $name, 5, "BOTVAC $name: called function BOTVAC_Get()";

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
sub BOTVAC_Set($@) {
    my ( $hash, @a ) = @_;
    my $name  = $hash->{NAME};

    Log3 $name, 5, "BOTVAC $name: called function BOTVAC_Set()";

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
        Log3 $name, 2, "BOTVAC set $name " . $a[1] . " " . $a[2];

        return "No argument given" if ( !defined( $a[2] ) );

        my $params = {
          "category"  => "2",
          "mode"      => $a[2] eq "Eco" ? "1" : "2",
          "modifier"  => "1"
        };
        BOTVAC_SendCommand( $hash, "messages", "startCleaning", $params );
    }

    elsif ( $a[1] eq "startSpot" ) {
        Log3 $name, 2, "BOTVAC set $name " . $a[1] . " " . $a[2];

        return "No argument given" if ( !defined( $a[2] ) );

        my $params = {
          "category"  => "3",
          "mode"      => $a[2] eq "Eco" ? "1" : "2",
          "modifier"  => "1"
        };
        BOTVAC_SendCommand( $hash, "messages", "startCleaning", $params );
    }

    # stop
    elsif ( $a[1] eq "stop" ) {
        Log3 $name, 2, "BOTVAC set $name " . $a[1];

        BOTVAC_SendCommand( $hash, "messages", "stopCleaning" );
    }

    # pause
    elsif ( $a[1] eq "pause" ) {
        Log3 $name, 2, "BOTVAC set $name " . $a[1];

        BOTVAC_SendCommand( $hash, "messages", "pauseCleaning" );
    }

    # resume
    elsif ( $a[1] eq "resume" ) {
        Log3 $name, 2, "BOTVAC set $name " . $a[1];

        BOTVAC_SendCommand( $hash, "messages", "resumeCleaning" );
    }

    # stop
    elsif ( $a[1] eq "stop" ) {
        Log3 $name, 2, "BOTVAC set $name " . $a[1];

        BOTVAC_SendCommand( $hash, "messages", "stopCleaning" );
    }

    # sendToBase
    elsif ( $a[1] eq "sendToBase" ) {
        Log3 $name, 2, "BOTVAC set $name " . $a[1];

        BOTVAC_SendCommand( $hash, "messages", "sendToBase" );
    }

    # schedule
    elsif ( $a[1] eq "schedule" ) {
        Log3 $name, 2, "BOTVAC set $name " . $a[1] . " " . $a[2];

        return "No argument given" if ( !defined( $a[2] ) );

        my $switch = $a[2];
        if ($switch eq "on") {
            BOTVAC_SendCommand( $hash, "messages", "enableSchedule" );
        } else {
            BOTVAC_SendCommand( $hash, "messages", "disableSchedule" );
        }
    }

    # return usage hint
    else {
        return $usage;
    }

    return;
}

###################################
sub BOTVAC_Define($$) {
    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );
    my $name = $hash->{NAME};

    Log3 $name, 5, "BOTVAC $name: called function BOTVAC_Define()";

    if ( int(@a) < 4 ) {
        my $msg =
          "Wrong syntax: define <name> BOTVAC <email> <password> [<poll-interval>]";
        Log3 $name, 4, $msg;
        return $msg;
    }

    $hash->{TYPE} = "BOTVAC";

    my $email = $a[2];
    $hash->{helper}{EMAIL} = $email;

    my $password = $a[3];
    $hash->{helper}{PASSWORD} = $password;
    
    # use interval of 85 sec if not defined
    my $interval = $a[4] || 85;
    $hash->{INTERVAL} = $interval;

    unless ( defined( AttrVal( $name, "webCmd", undef ) ) ) {
        $attr{$name}{webCmd} = 'startCleaning Eco:stop:sendToBase';
    }

    # start the status update timer
    RemoveInternalTimer($hash);
    InternalTimer( gettimeofday() + 2, "BOTVAC_GetStatus", $hash, 1 );

    return;
}

############################################################################################################
#
#   Begin of helper functions
#
############################################################################################################

###################################
sub BOTVAC_SendCommand($$;$$) {
    my ( $hash, $service, $cmd, $params ) = @_;
    my $name        = $hash->{NAME};
    my $email       = $hash->{helper}{EMAIL};
    my $password    = $hash->{helper}{PASSWORD};
    my $timestamp   = gettimeofday();
    my $timeout     = 15;
    my $header;
    my $data;

    Log3 $name, 5, "BOTVAC $name: called function BOTVAC_SendCommand()";

    my $URL;
    my $response;
    my $return;
    
    my %sslArgs;

    BOTVAC_CheckRegistration($hash) if ($service ne "sessions" && $service ne "dashboard");

    if ( !defined($cmd) ) {
        Log3 $name, 4, "BOTVAC $name: REQ $service";
    }
    else {
        Log3 $name, 4, "BOTVAC $name: REQ $service/$cmd";
    }
    Log3 $name, 4, "BOTVAC $name: REQ parameters $params" if (defined($params));

    $header = "Accept: application/vnd.neato.nucleo.v1";
    $header .= "\r\nContent-Type: application/json";

    if ($service eq "sessions") {
      my $token = createUniqueId() . createUniqueId();
      $URL = "https://beehive.neatocloud.com/sessions";
      $data = "{\"platform\": \"ios\", \"email\": \"$email\", \"token\": \"$token\", \"password\": \"$password\"}";

    } elsif ($service eq "dashboard") {
      $header .= "\r\nAuthorization: Token token=".ReadingsVal($name, "accessToken", "");
      $URL = "https://beehive.neatocloud.com/dashboard";

    } elsif ($service eq "messages") {
      my $serial = ReadingsVal($name, "serial", "");
      return if ($serial eq "");

      $URL = "https://nucleo.neatocloud.com/vendors/neato/robots/$serial/messages";
      $data = "{\"reqId\":\"1\",\"cmd\":\"$cmd\"";
      if (defined($params)) {
        $data .= ",\"params\":{";
        foreach( keys $params ) {
          $data .= "\"$_\":\"$params->{$_}\""; 
        }
        $data .= "}";
      }
      $data .= "}";

      my $date = gmtime();
      my $message = join("\n", (lc($serial), $date, $data));
      my $hmac = hmac_sha256_hex($message, ReadingsVal($name, "secretKey", ""));

      $header .= "\r\nDate: $date";
      $header .= "\r\nAuthorization: NEATOAPP $hmac";

      %sslArgs = ( SSL_ca =>  [ BOTVAC_GetCAKey( ) ] );
    }

    # send request via HTTP-POST method
    Log3 $name, 5, "BOTVAC $name: POST $URL (" . urlDecode($data) . ")"
      if ( defined($data) );
    Log3 $name, 5, "BOTVAC $name: GET $URL"
      if ( !defined($data) );
    Log3 $name, 5, "BOTVAC $name: header $header"
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
            sslargs     => { %sslArgs },
            callback    => \&BOTVAC_ReceiveCommand,
        }
    );

    return;
}

###################################
sub BOTVAC_ReceiveCommand($$$) {
    my ( $param, $err, $data ) = @_;
    my $hash    = $param->{hash};
    my $name    = $hash->{NAME};
    my $service = $param->{service};
    my $cmd     = $param->{cmd};

    my $rc = ( $param->{buf} ) ? $param->{buf} : $param;
    my $return;
    
    Log3 $name, 5, "BOTVAC $name: called function BOTVAC_ReceiveCommand() rc: $rc err: $err data: $data ";

    readingsBeginUpdate($hash);

    # device not reachable
    if ($err) {

        if ( !defined($cmd) || $cmd eq "" ) {
            Log3 $name, 4, "BOTVAC $name:$service RCV $err";
        } else {
            Log3 $name, 4, "BOTVAC $name:$service/$cmd RCV $err";
        }

        # keep last state
        #BOTVAC_ReadingsBulkUpdateIfChanged( $hash, "state", "Error" );
    }

    # data received
    elsif ($data) {
      
        if ( !defined($cmd) ) {
            Log3 $name, 4, "BOTVAC $name: RCV $service";
        } else {
            Log3 $name, 4, "BOTVAC $name: RCV $service/$cmd";
        }

        if ( $data ne "" ) {
            if ( $data =~ /^{/ || $data =~ /^\[/ ) {
                if ( !defined($cmd) || $cmd eq "" ) {
                    Log3 $name, 4, "BOTVAC $name: RES $service - $data";
                } else {
                    Log3 $name, 4, "BOTVAC $name: RES $service/$cmd - $data";
                }
                $return = decode_json( Encode::encode_utf8($data) );
            } else {
                Log3 $name, 5, "BOTVAC $name: RES ERROR $service\n" . $data;
                if ( !defined($cmd) || $cmd eq "" ) {
                    Log3 $name, 5, "BOTVAC $name: RES ERROR $service\n$data";
                } else {
                    Log3 $name, 5, "BOTVAC $name: RES ERROR $service/$cmd\n$data";
                }
                return undef;
            }
        }

        # messages
        if ( $service eq "messages" ) {
          if ( $cmd eq "getRobotState" ) {
            if ( ref($return) eq "HASH" ) {
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "version", $return->{version});
              BOTVAC_ReadingsBulkUpdateIfChanged( $hash, "result", $return->{result});
              BOTVAC_ReadingsBulkUpdateIfChanged( $hash, "error", $return->{error});
              #BOTVAC_ReadingsBulkUpdateIfChanged( $hash, "data", $return->{data});
              BOTVAC_ReadingsBulkUpdateIfChanged( $hash, "stateId", $return->{state});
              BOTVAC_ReadingsBulkUpdateIfChanged( $hash, "action", $return->{action});
              if ( ref($return->{cleaning}) eq "HASH" ) {
                my $cleaning = $return->{cleaning};
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "cleanCategorie",  $cleaning->{category});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "cleanMode",       $cleaning->{mode});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "cleanModifier",   $cleaning->{modifier});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "cleanSpotWidth",  $cleaning->{spotWidth});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "cleanSpotHeight", $cleaning->{spotHeight});
              }
              if ( ref($return->{details}) eq "HASH" ) {
                my $details = $return->{details};
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "isCharging",        $details->{isCharging});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "isDocked",          $details->{isDocked});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "isScheduleEnabled", $details->{isScheduleEnabled});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "dockHasBeenSeen",   $details->{dockHasBeenSeen});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "charge",            $details->{charge});
              }
              if ( ref($return->{availableCommands}) eq "HASH" ) {
                my $availableCommands = $return->{availableCommands};
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, ".start",    $availableCommands->{start});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, ".stop",     $availableCommands->{stop});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, ".pause",    $availableCommands->{pause});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, ".resume",   $availableCommands->{resume});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, ".goToBase", $availableCommands->{goToBase});
              }
              BOTVAC_ReadingsBulkUpdateIfChanged(
                  $hash,
                  "state",
                  BOTVAC_BuildState($hash, $return->{state}, $return->{action}, $return->{error}));
            }
          } elsif ( $cmd eq "getSchedule" ) {
            if ( ref($return->{data}) eq "HASH" ) {
              my $scheduleData = $return->{data};
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "scheduleType",    $scheduleData->{type});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "scheduleEnabled", $scheduleData->{enabled});
              if (ref($scheduleData->{events}) eq "ARRAY") {
                my @events = @{$scheduleData->{events}};
                for (my $i = 0; $i < @events; $i++) {
                  BOTVAC_ReadingsBulkUpdateIfChanged($hash, "event".$i."mode",      $events[$i]->{mode});
                  BOTVAC_ReadingsBulkUpdateIfChanged($hash, "event".$i."day",       $events[$i]->{day});
                  BOTVAC_ReadingsBulkUpdateIfChanged($hash, "event".$i."startTime", $events[$i]->{startTime});
                }
              }
            }
          }
        }
    
        # Sessions
        elsif ( $service eq "sessions" ) {
          if ( ref($return) eq "HASH" and defined($return->{access_token})) {
            BOTVAC_ReadingsBulkUpdateIfChanged($hash, "accessToken", $return->{access_token});
          }
        }
        
        # dashboard
        elsif ( $service eq "dashboard" ) {
          if ( ref($return) eq "HASH" ) {
            if ( ref($return->{robots}) eq "ARRAY" ) {
              my $robot = $return->{robots}[0];
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "serial",    $robot->{serial});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "name",      $robot->{name});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "model",     $robot->{model});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "secretKey", $robot->{secret_key});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "macAddr",   $robot->{mac_address});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "firmware",  $robot->{firmware});
            }
          }
        }
    
        # all other command results
        else {
            Log3 $name, 2, "BOTVAC $name: ERROR: method to handle response of $service not implemented";
        }

    }

    readingsEndUpdate( $hash, 1 );

    return;
}

###################################
sub BOTVAC_Undefine($$) {
    my ( $hash, $arg ) = @_;
    my $name = $hash->{NAME};

    Log3 $name, 5, "BOTVAC $name: called function BOTVAC_Undefine()";

    # Stop the internal GetStatus-Loop and exit
    RemoveInternalTimer($hash);

    return;
}

sub BOTVAC_CheckRegistration($) {
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  if (ReadingsVal($name, "secretKey", "") eq "") {
    BOTVAC_SendCommand($hash, "sessions") if (ReadingsVal($name, "accessToken", "") eq "");
    BOTVAC_SendCommand($hash, "dashboard")  if (ReadingsVal($name, "accessToken", "") ne "");
  }
}

sub BOTVAC_ReadingsBulkUpdateIfChanged($$$) {
  my ($hash,$reading,$value) = @_;
  my $name = $hash->{NAME};

  readingsBulkUpdate($hash, $reading, $value) if (ReadingsVal($name, $reading, "") ne $value);
}

sub BOTVAC_BuildState($$$$) {
    my ($hash,$state,$action,$error) = @_;
    my $states = {
        '1'       => "Ready",
        '2'       => "Action",
        '3'       => "Paused",
        '4'       => "Error"
    };

    if ($state == 2) {
        return BOTVAC_GetActionText($action);
    } elsif ($state == 3) {
        return "Paused: ".BOTVAC_GetActionText($action);
    } elsif ($state == 4) {
      return BOTVAC_GetErrorText($error);
    } elsif (defined( $states->{$state})) {
        return $states->{$state};
    } else {
        return $state;
    }
}

sub BOTVAC_GetActionText($) {
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

sub BOTVAC_GetErrorText($) {
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

sub BOTVAC_GetCAKey() {
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

<a name="BOTVAC"></a>
<h3>BOTVAC</h3>
<ul>
  This module controls a Neato Botvac Connected.
  <br><br>
  <b>Define</b>
</ul>

=end html
=begin html_DE

<a name="BOTVAC"></a>
<h3>BOTVAC</h3>
<ul>
  Diese Module dient zur Steuerung eines Neato Botvac Connected 
  <br><br>
  <b>Define</b>
</ul>

=end html_DE
=cut
