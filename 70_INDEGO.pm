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
# Version: 0.2.8
#
##############################################################################

package main;

use 5.012;
use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use HttpUtils;
use JSON qw(decode_json encode_json);
use Encode qw(encode_utf8);

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

    $hash->{AttrList} = "disable:0,1 " .
                        "actionInterval " .
                        $readingFnAttributes;

    return;
}

#####################################
sub INDEGO_GetStatus($;$) {
    my ( $hash, $update ) = @_;
    my $name     = $hash->{NAME};
    my $interval = $hash->{INTERVAL};

    Log3 $name, 5, "INDEGO $name: called function INDEGO_GetStatus()";

    # use actionInterval if state is busy, paused, or returning
    $interval = AttrVal($name, "actionInterval", $interval) if (ReadingsVal($name, "stateId", "0") =~ /^[57]\d\d$/);

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

    if ( $what =~ /^(mapsvgcache)$/ ) {
        my $value = ReadingsVal($name, $what, "");
        if ($value eq "") {
          $value = ReadingsVal($name, ".$what", "");
          eval { require Compress::Zlib; };
          unless($@) {
            $value = Compress::Zlib::uncompress($value);
          }
        }
        if ( $value ne "" ) {
            return $value;
        } else {
            return "no such reading: $what";
        }
    } else {
        return "Unknown argument $what, choose one of mapsvgcache:noArg";
    }
}

###################################
sub INDEGO_Set($@) {
    my ( $hash, @a ) = @_;
    my $name  = $hash->{NAME};

    Log3 $name, 5, "INDEGO $name: called function INDEGO_Set()";

    return "No Argument given" if ( !defined( $a[1] ) );

    my $usage = "Unknown argument " . $a[1];
    $usage .= ", choose one of password renewContext:noArg mow:noArg pause:noArg returnToDock:noArg reloadMap:noArg smartMode:on,off";
    $usage .= " deleteAlert:noArg" if (ReadingsVal($name, "alert_id", "-") ne "-");
    $usage .= " calendar:0,1,2,3,4,5";

    # mow
    if ( $a[1] eq "mow" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        INDEGO_SendCommand( $hash, "state", "mow" );
        readingsSingleUpdate($hash, "state", "Set_Mowing", 1);
    }

    # pause
    elsif ( $a[1] eq "pause" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        INDEGO_SendCommand( $hash, "state", "pause" );
        readingsSingleUpdate($hash, "state", "Set_Paused", 1);
    }

    # returnToDock
    elsif ( $a[1] eq "returnToDock" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        INDEGO_SendCommand( $hash, "state", "returnToDock" );
        readingsSingleUpdate($hash, "state", "Set_Returning", 1);
    }

    # reloadMap
    elsif ( $a[1] eq "reloadMap" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        INDEGO_SendCommand( $hash, "map" );
    }

    # renewContext
    elsif ( $a[1] eq "renewContext" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        INDEGO_SendCommand( $hash, "authenticate" );
    }

    # deleteAlert
    elsif ( $a[1] eq "deleteAlert" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        INDEGO_SendCommand( $hash, "deleteAlert" );
    }

    # selectCalendar
    elsif ( $a[1] eq "calendar" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1] . " " . $a[2];

        return "No argument given" if ( !defined( $a[2] ) );

        INDEGO_SendCommand( $hash, "setCalendar", $a[2] );
    }

    # smartMode
    elsif ( $a[1] eq "smartMode" ) {
        Log3 $name, 2, "INDEGO set $name " . $a[1] . " " . $a[2];

        return "No argument given" if ( !defined( $a[2] ) );

        INDEGO_SendCommand( $hash, "smartMode", $a[2] );
    }

    # password
    elsif ( $a[1] eq "password") {
        Log3 $name, 2, "INDEGO set $name " . $a[1];

        return "No password given" if ( !defined( $a[2] ) );

        INDEGO_StorePassword( $hash, $a[2] );
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

    if ( int(@a) < 3 ) {
        my $msg =
          "Wrong syntax: define <name> INDEGO <email> [<poll-interval>]";
        Log3 $name, 4, $msg;
        return $msg;
    }

    $hash->{TYPE} = "INDEGO";

    my $email = $a[2];
    $hash->{helper}{EMAIL} = $email;

    # use interval of 300 sec if not defined
    my $interval = 300;

    if (defined($a[3])) {
      if ($a[3] =~ /^[0-9]+$/ and not defined($a[4])) {
        $interval = $a[3];
      } else {
        INDEGO_StorePassword($hash, $a[3]);
        $interval = $a[4] if (defined($a[4]));
      }
    }
    $hash->{INTERVAL} = $interval;

    unless ( defined( AttrVal( $name, "webCmd", undef ) ) ) {
        $attr{$name}{webCmd} = 'mow:pause:returnToDock';
    }

    # start the status update timer
    RemoveInternalTimer($hash);
    InternalTimer( gettimeofday() + 2, "INDEGO_GetStatus", $hash, 1 );

    INDEGO_addExtension($name, "INDEGO_GetMap", "INDEGO/$name/map");

    return;
}

###################################
sub INDEGO_Undefine($$) {
    my ( $hash, $arg ) = @_;
    my $name = $hash->{NAME};

    Log3 $name, 5, "INDEGO $name: called function INDEGO_Undefine()";

    # De-Authenticate
    INDEGO_SendCommand($hash, "deauthenticate");

    # Stop the internal GetStatus-Loop and exit
    RemoveInternalTimer($hash);

    INDEGO_removeExtension("INDEGO/$name/map");

    return;
}

############################################################################################################
#
#   Begin of helper functions
#
############################################################################################################

#########################
sub INDEGO_addExtension($$$) {
    my ( $name, $func, $link ) = @_;

    my $url = "/$link";
    Log3 $name, 2, "Registering INDEGO $name for URL $url...";
    $data{FWEXT}{$url}{deviceName} = $name;
    $data{FWEXT}{$url}{FUNC}       = $func;
    $data{FWEXT}{$url}{LINK}       = $link;
}

#########################
sub INDEGO_removeExtension($) {
    my ($link) = @_;

    my $url  = "/$link";
    my $name = $data{FWEXT}{$url}{deviceName};
    Log3 $name, 2, "Unregistering INDEGO $name for URL $url...";
    delete $data{FWEXT}{$url};
}

###################################
sub INDEGO_SendCommand($$;$) {
    my ( $hash, $service, $type ) = @_;
    my $name        = $hash->{NAME};
    my $email       = $hash->{helper}{EMAIL};
    my $password    = INDEGO_ReadPassword($hash);
    my $timestamp   = gettimeofday();
    my $timeout     = 30;
    my $header;
    my $data;
    my $method      = "GET";

    Log3 $name, 5, "INDEGO $name: called function INDEGO_SendCommand()";

    my $URL = "https://api.indego.iot.bosch-si.com/api/v1/";
    
    if ($service ne "authenticate") {
      return if !INDEGO_CheckContext($hash);
    }

    Log3 $name, 4, "INDEGO $name: REQ $service";

    if ($service eq "authenticate") {
      $URL .= $service;
      $header = "Content-Type: application/json";
      $header .= "\r\nAuthorization: Basic ";
      $header .= encode_base64("$email:$password","");
      $data = "{\"device\":\"\", \"os_type\":\"Android\", \"os_version\":\"4.0\", \"dvc_manuf\":\"unknown\", \"dvc_type\":\"unknown\"}";
      $method = "POST";

    } elsif ($service eq "deauthenticate") {
      $URL .= $service;
      $header = "x-im-context-id: ".ReadingsVal($name, "contextId", "");
      $method = "DELETE";

    } elsif ($service eq "alerts") {
      $URL .= $service;
      $header = "x-im-context-id: ".ReadingsVal($name, "contextId", "");

    } elsif ($service eq "deleteAlert") {
      my $id = ReadingsVal($name, "alert_id", "-");
      return undef if ($id eq "-");

      $URL .= "alerts/$id";
      $header = "x-im-context-id: ".ReadingsVal($name, "contextId", "");
      $method = "DELETE";

    } elsif ($service eq "state") {
      $URL .= "alms/";
      $URL .= ReadingsVal($name, "alm_sn", "");
      $URL .= "/$service";
      $header = "x-im-context-id: ".ReadingsVal($name, "contextId", "");
      if (defined($type)) {
        $header .= "\r\nContent-Type: application/json";
        $data = "{\"state\":\"".$type."\"}";
        $method = "PUT";
      }

    } elsif ($service eq "longpollState") {
      $URL .= "alms/";
      $URL .= ReadingsVal($name, "alm_sn", "0");
      $URL .= "/state?longpoll=true&timeout=3600&last=";
      $URL .= ReadingsVal($name, "state_id", "0");
      
      $header = "x-im-context-id: ".ReadingsVal($name, "contextId", "");
      $timeout = 3600;
      
      $hash->{LONGPOLL} = time();

    } elsif ($service eq "setCalendar") {
      $URL .= "alms/";
      $URL .= ReadingsVal($name, "alm_sn", "");
      $URL .= "/calendar";
      $header = "x-im-context-id: ".ReadingsVal($name, "contextId", "");
      $header .= "\r\nContent-Type: application/json";
      $data = INDEGO_BuildCalendar($hash, $type);
      $method = "PUT";

    } elsif ($service eq "firmware") {
      $URL .= "alms/";
      $URL .= ReadingsVal($name, "alm_sn", "");
      $header = "x-im-context-id: ".ReadingsVal($name, "contextId", "");

    } elsif ($service eq "smartMode") {
      my $smartMode = (defined($type) && $type eq "on") ? "true" : "false";
      $URL .= "alms/";
      $URL .= ReadingsVal($name, "alm_sn", "");
      $URL .= "/predictive";
      $header = "x-im-context-id: ".ReadingsVal($name, "contextId", "");
      $header .= "\r\nContent-Type: application/json";
      $data  = "{\"enabled\":".$smartMode."}";
      $method = "PUT";

    } else {
      $URL .= "alms/";
      $URL .= ReadingsVal($name, "alm_sn", "");
      $URL .= "/$service";
      $header = "x-im-context-id: ".ReadingsVal($name, "contextId", "");

    }

    # send request via HTTP method
    Log3 $name, 5, "INDEGO $name: $method $URL (" . urlDecode($data) . ")"
      if ( defined($data) );
    Log3 $name, 5, "INDEGO $name: $method $URL"
      if ( !defined($data) );
    Log3 $name, 5, "INDEGO $name: header $header"
      if ( defined($header) );

    if ( defined($type) && $type eq "blocking" ) {
      my ($err, $data) = HttpUtils_BlockingGet(
          {
              url         => $URL,
              timeout     => 15,
              noshutdown  => 1,
              header      => $header,
              data        => $data,
              method      => $method,
              hash        => $hash,
              service     => $service,
              timestamp   => $timestamp,
          }
      );
      return $data;
    } else {
      HttpUtils_NonblockingGet(
          {
              url         => $URL,
              timeout     => $timeout,
              noshutdown  => 1,
              header      => $header,
              data        => $data,
              method      => $method,
              hash        => $hash,
              service     => $service,
              cmd         => $type,
              timestamp   => $timestamp,
              callback    => \&INDEGO_ReceiveCommand,
          }
      );
    }

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
                $return = decode_json( encode_utf8($data) );
            } elsif ( $service = "map" ) {
                if ( !defined($cmd) || $cmd eq "" ) {
                    Log3 $name, 4, "INDEGO $name: RES $service - $data";
                } else {
                    Log3 $name, 4, "INDEGO $name: RES $service/$cmd - $data";
                }
                $return = $data;
            } else {
                Log3 $name, 3, "INDEGO $name: RES ERROR $service\n" . $data;
                if ( !defined($cmd) || $cmd eq "" ) {
                    Log3 $name, 5, "INDEGO $name: RES ERROR $service\n$data";
                } else {
                    Log3 $name, 5, "INDEGO $name: RES ERROR $service/$cmd\n$data";
                }
                return undef;
            }
        }

        # state
        if ( $service eq "state" or $service eq "longpollState") {
          if ( ref($return) eq "HASH" and !defined($cmd)) {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "state",          INDEGO_BuildState($hash, $return->{state})) if (defined($return->{state}));
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "state_id",       $return->{state}) if (defined($return->{state}));
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "mowed",          $return->{mowed}) if (defined($return->{mowed}));
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "mowed_ts",       FmtDateTime(int($return->{mowed_ts}/1000))) if (defined($return->{mowed_ts}));
            #INDEGO_ReadingsBulkUpdateIfChanged($hash, "mapsvgcache_ts", FmtDateTime(int($return->{mapsvgcache_ts}/1000))) if (defined($return->{mapsvgcache_ts}));
            #INDEGO_ReadingsBulkUpdateIfChanged($hash, "map_update_available", $return->{map_update_available});
            if ( ref($return->{runtime}) eq "HASH" ) {
              my $runtime = $return->{runtime};
              if ( ref($runtime->{total}) eq "HASH" ) {
                my $total = $runtime->{total};
                my $operate = $total->{operate};
                my $charge = $total->{charge};
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "totalOperate", INDEGO_GetDuration($hash, $operate));
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "totalCharge",  INDEGO_GetDuration($hash, $charge));
              }
              if ( ref($runtime->{session}) eq "HASH" ) {
                my $session = $runtime->{session};
                my $operate = $session->{operate};
                my $charge = $session->{charge};
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "sessionOperate", INDEGO_GetDuration($hash, $operate));
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "sessionCharge",  INDEGO_GetDuration($hash, $charge));
              }
            }
            readingsEndUpdate( $hash, 1 );

            INDEGO_CheckLongpoll($hash) if ($service eq "state");

            INDEGO_SendCommand($hash, "longpollState") if ($service eq "longpollState");
            INDEGO_SendCommand($hash, "alerts");
            INDEGO_SendCommand($hash, "location");
            INDEGO_SendCommand($hash, "predictive");
            INDEGO_SendCommand($hash, "predictive/nextcutting");
            INDEGO_SendCommand($hash, "predictive/useradjustment");
            INDEGO_SendCommand($hash, "predictive/useradjustment?withProposal=true");
            INDEGO_SendCommand($hash, "map") if ($return->{map_update_available});
          }
        }
    
        # firmware
        elsif ( $service eq "firmware" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alm_name",             $return->{alm_name});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "service_counter",      $return->{service_counter});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "bareToolnumber",       $return->{bareToolnumber});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alm_firmware_version", $return->{alm_firmware_version});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "model",                INDEGO_GetModel($hash, $return->{bareToolnumber}))
                if (defined($return->{bareToolnumber}));

            readingsEndUpdate( $hash, 1 );
          }
        }

        # alerts
        elsif ( $service eq "alerts" ) {
          if ( ref($return) eq "ARRAY" and scalar(@{$return}) > 0) {
            my $date;
            my $alert;
            foreach $alert (@{$return}) {
              my $current_date = time_str2num(substr($alert->{date}, 0, 19));
              if (!defined($date) or $date < $current_date) {
                $date = $current_date;
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_number",   scalar(@{$return}));
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_id",       $alert->{alert_id});
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_headline", $alert->{headline});
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_date",     FmtDateTime($current_date + fhemTzOffset($current_date)));
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_message",  $alert->{message});
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_flag",     $alert->{flag});
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_status",   $alert->{read_status});
              }
            }
          }
          readingsEndUpdate( $hash, 1 );
        }

        # updates
        elsif ( $service eq "updates" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "updates", $return->{available} ? "available" : "unavailable");

            readingsEndUpdate( $hash, 1 );
          }
        }

        # security
        elsif ( $service eq "security" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "security", $return->{enabled} ? "enabled" : "disabled");
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "autolock", $return->{autolock} ? "true" : "false");

            readingsEndUpdate( $hash, 1 );
          }
        }

        # automaticUpdate
        elsif ( $service eq "automaticUpdate" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "allow_automatic_update", $return->{allow_automatic_update} ? "true" : "false");

            readingsEndUpdate( $hash, 1 );
          }
        }

        # location
        elsif ( $service eq "location" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "latitude",  $return->{latitude});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "longitude", $return->{longitude});

            readingsEndUpdate( $hash, 1 );
          }
        }

        # predictive/nextcutting
        elsif ( $service eq "predictive" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "fc_enabled",  $return->{enabled});

            readingsEndUpdate( $hash, 1 );
          }
        }

        # predictive/location
        elsif ( $service eq "predictive/location" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "fc_loc_latitude",  $return->{latitude});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "fc_loc_longitude", $return->{longitude});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "fc_loc_timezone",  $return->{timezone});

            readingsEndUpdate( $hash, 1 );
          }
        }

        # predictive/nextcutting
        elsif ( $service eq "predictive/nextcutting" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "mow_next",  $return->{mow_next});

            readingsEndUpdate( $hash, 1 );
          }
        }

        # predictive/useradjustment
        elsif ( $service eq "predictive/useradjustment" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "user_adjustment",  $return->{user_adjustment});

            readingsEndUpdate( $hash, 1 );
          }
        }

        # predictive/useradjustment?withProposal=true
        elsif ( $service eq "predictive/useradjustment?withProposal=true" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "user_adjustment_proposed",  $return->{user_adjustment});

            readingsEndUpdate( $hash, 1 );
          }
        }

        # calendar
        elsif ( $service eq "calendar" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "cal", $return->{sel_cal});

            my %currentCals;
            foreach ( keys %{ $hash->{READINGS} } ) {
              $currentCals{$_} = 1 if ( $_ =~ /^cal\d_.*/ );
            }

            if ( ref($return->{cals}) eq "ARRAY" ) {
              my @cals = @{$return->{cals}};
              my $cal;
              foreach $cal (@cals) {
                my @days = @{$cal->{days}};
                my $day;
                for $day (@days) {
                  my $schedule;
                  my @slots = @{$day->{slots}};
                  my $slot;
                  for $slot (@slots) {
                    if ($slot->{En}) {
                      my $slotStr = INDEGO_GetSlotFormatted($hash, $slot);
                      if (defined($schedule)) {
                        $schedule .= " ".$slotStr;
                      } else {
                        $schedule = $slotStr;
                      }
                    }
                  }
                  if (defined($schedule)) {
                    my $reading = "cal".$cal->{cal}."_".$day->{day}."_".INDEGO_GetDay($hash, $day->{day});
                    INDEGO_ReadingsBulkUpdateIfChanged($hash, $reading, $schedule) ;
                    delete $currentCals{$reading};
                  }
                }
              }
            }

            #remove outdated calendar information
            foreach ( keys %currentCals ) {
              delete( $hash->{READINGS}{$_} );
            }

            readingsEndUpdate( $hash, 1 );
          }
        }

        # predictive/calendar
        elsif ( $service eq "predictive/calendar" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "fc_cal", $return->{sel_cal});

            my %currentCals;
            foreach ( keys %{ $hash->{READINGS} } ) {
              $currentCals{$_} = 1 if ( $_ =~ /^fc_cal\d_.*/ );
            }

            if ( ref($return->{cals}) eq "ARRAY" ) {
              my @cals = @{$return->{cals}};
              my $cal;
              foreach $cal (@cals) {
                my @days = @{$cal->{days}};
                my $day;
                for $day (@days) {
                  my $schedule;
                  my @slots = @{$day->{slots}};
                  my $slot;
                  for $slot (@slots) {
                    if ($slot->{En}) {
                      my $slotStr = INDEGO_GetSlotFormatted($hash, $slot);
                      if (defined($schedule)) {
                        $schedule .= " ".$slotStr;
                      } else {
                        $schedule = $slotStr;
                      }
                    }
                  }
                  if (defined($schedule)) {
                    my $reading = "fc_cal".$cal->{cal}."_".$day->{day}."_".INDEGO_GetDay($hash, $day->{day});
                    INDEGO_ReadingsBulkUpdateIfChanged($hash, $reading, $schedule) ;
                    delete $currentCals{$reading};
                  }
                }
              }
            }

            #remove outdated calendar information
            foreach ( keys %currentCals ) {
              delete( $hash->{READINGS}{$_} );
            }

            readingsEndUpdate( $hash, 1 );
          }
        }

        # predictive/weather
        elsif ( $service eq "predictive/weather" ) {
          if ( ref($return) eq "HASH") {
            if ( ref($return->{LocationWeather}) eq "HASH" ) {
              my $weather = $return->{LocationWeather};
              if ( ref($weather->{location}) eq "HASH" ) {
                my $location = $weather->{location};
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "fc_loc_name",    $location->{name});
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "fc_loc_country", $location->{country});
                INDEGO_ReadingsBulkUpdateIfChanged($hash, "fc_loc_dtz",     $location->{dtz});
              }
            }

            readingsEndUpdate( $hash, 1 );
          }
        }

        # map
        elsif ( $service eq "map" ) {
          if ( defined($return) and !ref($return)) {
            my $map = $return;
            eval { require Compress::Zlib; };
            unless($@) {
              $map = Compress::Zlib::compress($map);
            }
            INDEGO_ReadingsBulkUpdateIfChanged($hash, ".mapsvgcache", $map );
  
            readingsEndUpdate( $hash, 1 );
          }
        }

        # authenticate
        elsif ( $service eq "authenticate" ) {
          if ( ref($return) eq "HASH") {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "contextId", $return->{contextId});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "userId",    $return->{userId});
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alm_sn",    $return->{alm_sn});

            readingsEndUpdate( $hash, 1 );
            
            # new context received - reload state
            INDEGO_SendCommand($hash, "state");
            INDEGO_TriggerFullDataUpdate($hash);
            
            # re-execute previous command
            if (defined($cmd)) {
              if ($cmd =~ /(\w+)\/(\w+)/) {
                INDEGO_SendCommand($hash, $1, $2);
              } else {
                INDEGO_SendCommand($hash, $cmd);
              }
            }
          }
        }
    
        # all other command results
        else {
            Log3 $name, 2, "INDEGO $name: ERROR: method to handle response of $service not implemented";
        }

    } else {
        if ($rc =~ /401/) {
            Log3 $name, 4, "INDEGO $name: authentication context invalidated"; 
            if ( $service =~ /deleteAlert|setCalendar/) {
                INDEGO_SendCommand($hash, "authenticate", "$service");
            } elsif ($service eq "state" and defined($cmd)) {
                INDEGO_SendCommand($hash, "authenticate", "$service/$cmd");
            } else {
                readingsSingleUpdate($hash, "contextId", "", 1);
            }
            $hash->{LONGPOLL} = 0 if ($service eq "longpollState");
        }

        # no alerts
        elsif ( $service eq "alerts" and $rc =~ /204 User found but no alerts were found/) {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_number", 0);
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_id",       "-");
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_headline", "-");
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_date",     "-");
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_message",  "-");
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_flag",     "-");
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "alert_status",   "-");
        }

        # deleteAlert
        elsif ( $service eq "deleteAlert" ) {
            INDEGO_SendCommand($hash, "alerts");
        }

        # setCalendar
        elsif ( $service eq "setCalendar" ) {
            INDEGO_SendCommand($hash, "calendar");
        }

        # smartMode
        elsif ( $service eq "smartMode" ) {
            INDEGO_ReadingsBulkUpdateIfChanged($hash, "fc_enabled", ($rc->{cmd} eq "on") ? 1 : 0)
                if ($rc->{httpheader} =~ /HTTP\/1.\d 200/);

            readingsEndUpdate( $hash, 1 );
        }
    }

    return;
}

sub INDEGO_CheckContext($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $contextId = ReadingsVal($name, "contextId", "");
  my $contextAge = ReadingsAge($name, "contextId", 0);

  if ($contextId eq "" or $contextAge > 7200) {
    INDEGO_SendCommand($hash, "authenticate");
    return;
  }
  
  return $contextId;
}

sub INDEGO_CheckLongpoll($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  return if ( AttrVal($name, "disable", 0) == 1 );

  if (!defined($hash->{LONGPOLL}) or time() - $hash->{LONGPOLL} > 3600) {
    Log3 $name, 4, "INDEGO $name: Request GET state (longPoll)";
    INDEGO_SendCommand($hash, "longpollState");
  }
}

sub INDEGO_TriggerFullDataUpdate($) {
  my ( $hash ) = @_;
  
  INDEGO_SendCommand($hash, "firmware");
  INDEGO_SendCommand($hash, "automaticUpdate");
  INDEGO_SendCommand($hash, "calendar");
  INDEGO_SendCommand($hash, "updates");
  INDEGO_SendCommand($hash, "security");
  INDEGO_SendCommand($hash, "predictive/calendar");
  INDEGO_SendCommand($hash, "predictive/location");
  INDEGO_SendCommand($hash, "predictive/weather");
  INDEGO_SendCommand($hash, "map");
}

sub INDEGO_ReadingsBulkUpdateIfChanged($$$) {
  my ($hash,$reading,$value) = @_;
  my $name = $hash->{NAME};
  
  $value = "" if (!defined($value));
  readingsBulkUpdate($hash, $reading, $value) if (ReadingsVal($name, $reading, "") ne $value);
}

sub INDEGO_GetSlotFormatted($$) {
  my ($hash,$slot) = @_;
  
  return sprintf("%02d:%02d-%02d:%02d", $slot->{StHr}, $slot->{StMin}, $slot->{EnHr}, $slot->{EnMin});  
}

sub INDEGO_GetDuration($$) {
  my ($hash,$duration) = @_;
  
  return sprintf("%d:%02d", int($duration/60), $duration-int($duration/60)*60);  
}

sub INDEGO_GetDay($$) {
    my ($hash,$day) = @_;
    my $days = {
        '0' => "Mon",
        '1' => "Tue",
        '2' => "Wed",
        '3' => "Thu",
        '4' => "Fri",
        '5' => "Sat",
        '6' => "Sun",
    };

    return $days->{$day};
}

sub INDEGO_GetModel($$) {
    my ($hash,$baretool) = @_;
    my $models = {
        "3600HA2300" => "1000",
        "3600HA2301" => "1200",
        "3600HA2302" => "1100",
        "3600HA2303" => "13C",
        "3600HA2304" => "10C",
        "3600HB0100" => "350",
        "3600HB0101" => "400"
    };
    
    if (defined( $models->{$baretool})) {
        return $models->{$baretool};
    } else {
        return $models;
    }
}

sub INDEGO_BuildState($$) {
    my ($hash,$state) = @_;
    my $states = {
           '0' => "Reading status",
         '257' => "Charging",
         '258' => "Docked",
         '259' => "Docked - Software update",
         '260' => "Docked",
         '261' => "Docked",
         '262' => "Docked - Loading map",
         '263' => "Docked - Saving map",
         '512' => "Leaving dock",
         '513' => "Mowing",
         '514' => "Relocalising",
         '515' => "Loading map",
         '516' => "Learning lawn",
         '517' => "Paused",
         '518' => "Border cut",
         '519' => "Idle in lawn",
         '520' => "Learning lawn",
         '768' => "Returning to dock",
         '769' => "Returning to dock",
         '770' => "Returning to dock",
         '771' => "Returning to dock - Battery low",
         '772' => "Returning to dock - Calendar timeslot ended",
         '773' => "Returning to dock - Battery temp range",
         '774' => "Returning to dock",
         '775' => "Returning to dock - Lawn complete",
         '776' => "Returning to dock - Relocalising",
        '1025' => "Diagnostic mode",
        '1026' => "End of live",
        '1281' => "Software update",
        '1537' => "Low power mode"
    };

    if (defined( $states->{$state})) {
        return $states->{$state};
    } else {
        return $state;
    }
}

sub INDEGO_BuildCalendar($$) {
    my ($hash,$selected) = @_;
    my $name = $hash->{NAME};

    # create calendar object
    my @cals;
    for (my $i=1; $i<=5; $i++) {
      my @days;
      for (my $j=0; $j<=6; $j++) {
        my @slots;
        for (my $k=0; $k<2; $k++) {
          my %slot = (
            "En"    => \0,
            "StHr"  => 0,
            "StMin" => 0,
            "EnHr"  => 0,
            "EnMin" => 0
          );
          push(@slots, \%slot);
        }
        my %day = (
          "day"   => $j,
          "slots" => \@slots
        );
        push(@days, \%day);
      }
      my %cal = (
        "cal"  => $i,
        "days" => \@days
      );
      push(@cals, \%cal);
    }

    # set current data
    foreach ( keys %{ $hash->{READINGS} } ) {
      if ( $_ =~ /^cal(\d)_(\d)_.*/ ) {
        my $calnr = $1;
        $calnr--; # array starts with 0
        my $daynr = $2;
        my $value = ReadingsVal($name, $_, "");
        Log3 $name, 3, "--> $value";
        if ($value =~ /^(\d{2}):(\d{2})-(\d{2}):(\d{2}) (\d{2}):(\d{2})-(\d{2}):(\d{2})$/) {
          my $slot1 = $cals[$calnr]->{days}[$daynr]->{slots}[0];
          $slot1->{En}    = \1;
          $slot1->{StHr}  = int($1);
          $slot1->{StMin} = int($2);
          $slot1->{EnHr}  = int($3);
          $slot1->{EnMin} = int($4);
          my $slot2 = $cals[$calnr]->{days}[$daynr]->{slots}[1];
          $slot2->{En}    = \1;
          $slot2->{StHr}  = int($5);
          $slot2->{StMin} = int($6);
          $slot2->{EnHr}  = int($7);
          $slot2->{EnMin} = int($8);
        } elsif ($value =~ /^(\d{2}):(\d{2})-(\d{2}):(\d{2})$/) {
          my $slot1 = $cals[$calnr]->{days}[$daynr]->{slots}[0];
          $slot1->{En}    = \1;
          $slot1->{StHr}  = int($1);
          $slot1->{StMin} = int($2);
          $slot1->{EnHr}  = int($3);
          $slot1->{EnMin} = int($4);
        }
      }
    }
    
    my %calendar = (
      "sel_cal" => int($selected),
      "cals"    => \@cals
    );
    return encode_json(\%calendar);
}

sub INDEGO_StorePassword($$) {
    my ($hash, $password) = @_;
    my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
    my $key = getUniqueId().$index;
    my $enc_pwd = "";

    if(eval "use Digest::MD5;1") {
      $key = Digest::MD5::md5_hex(unpack "H*", $key);
      $key .= Digest::MD5::md5_hex($key);
    }
    
    for my $char (split //, $password) {
      my $encode=chop($key);
      $enc_pwd.=sprintf("%.2x",ord($char)^ord($encode));
      $key=$encode.$key;
    }
    
    my $err = setKeyValue($index, $enc_pwd);
    return "error while saving the password - $err" if(defined($err));

    return "password successfully saved";
}

sub INDEGO_ReadPassword($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
    my $key = getUniqueId().$index;
    my ($password, $err);
    
    Log3 $name, 4, "INDEGO $name: Read password from file";
    
    ($err, $password) = getKeyValue($index);

    if ( defined($err) ) {
      Log3 $name, 3, "INDEGO $name: unable to read password from file: $err";
      return undef; 
    }
    
    if ( defined($password) ) {
      if ( eval "use Digest::MD5;1" ) {
        $key = Digest::MD5::md5_hex(unpack "H*", $key);
        $key .= Digest::MD5::md5_hex($key);
      }
      my $dec_pwd = '';
      for my $char (map { pack('C', hex($_)) } ($password =~ /(..)/g)) {
        my $decode=chop($key);
        $dec_pwd.=chr(ord($char)^ord($decode));
        $key=$decode.$key;
      }
      return $dec_pwd;
    } else {
      Log3 $name, 3, "INDEGO $name: No password in file";
      return undef;
    }
}

sub INDEGO_ShowMap($;$$) {
    my ($name,$width,$height) = @_;
    my $hash = $main::defs{$name};
    my $compress = 0;

    eval { require Compress::Zlib; };
    unless($@) {
      $compress = 1;
    } 

    my $map = ReadingsVal($name, ".mapsvgcache", "");
    my $data = $map;

    $width  = 800 if (!defined($width));

    if ($map eq "") {
      $map = INDEGO_SendCommand($hash, "map", "blocking");
      $data = $map;
      $map = Compress::Zlib::compress($map) if ($compress);
      readingsSingleUpdate($hash, ".mapsvgcache", $map, 1);
    } else {
      $data = Compress::Zlib::uncompress($data) if ($compress);
    }

    if (defined($data)) {
      if (!defined($height) and $data =~ /viewBox="0 0 (\d+) (\d+)"/) {
        my $factor = $1/$width;
        $height = int($2/$factor);
      }
      my $html = '<svg style="width:'.$width.'px; height:'.$height.'px;"' if (defined($height));
      $html .= substr($data, 4);
   
  
      return $html;
    }
    
    return 'Map currently not available';
}

sub INDEGO_GetMap() {
    my ($request) = @_;
    
    if ($request =~ /^\/INDEGO\/(\w+)\/map(\/(\d+)(\/(\d+))?)?/) {
      my $name   = $1;
      my $width  = $3;
      my $height = $5;
      
      return ("text/html; charset=utf-8", INDEGO_ShowMap($name, $width, $height));
    }

    return ("text/plain; charset=utf-8", "No INDEGO device for webhook $request");
    
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
