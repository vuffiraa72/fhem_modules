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
# Version: 0.2.9.d7.2
#
##############################################################################

package main;

use 5.012;
use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use HttpUtils;
use JSON qw(decode_json);
#use IO::Socket::SSL::Utils qw(PEM_string2cert);
use Digest::SHA qw(hmac_sha256_hex);
use Encode qw(encode_utf8);

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
    $hash->{AttrFn}  = "BOTVAC_Attr";
    $hash->{AttrList} = "disable:0,1 " .
                        "Boundaries:textField-long " .
                         $readingFnAttributes;
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
      BOTVAC_SendCommand( $hash, "messages", "getRobotState", undef, ["messages", "getSchedule"] );
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

    my $arg = $a[1];
    $arg .= " ".$a[2] if (defined( $a[2] ));
    $arg .= " ".$a[3] if (defined( $a[3] ));

    my $usage = "Unknown argument " . $a[1] . ", choose one of";
    if (ReadingsVal($name, "srv_houseCleaning", "") eq "basic-1") {
      $usage .= " startCleaning:Eco,Turbo" if ( ReadingsVal($name, ".start", "0") );
    }elsif (ReadingsVal($name, "srv_houseCleaning", "") eq "basic-3") {
      $usage .= " startCleaning:Eco,Turbo" if ( ReadingsVal($name, ".start", "0") );  
    } else {
      $usage .= " startCleaning:Normal,ExtraCare" if ( ReadingsVal($name, ".start", "0") );
    }
    if (ReadingsVal($name, "srv_spotCleaning", "") eq "basic-1") {
      $usage .= " startSpot:Eco,Turbo" if ( ReadingsVal($name, ".start", "0") );
    } elsif (ReadingsVal($name, "srv_spotCleaning", "") eq "basic-3") {
      $usage .= " startSpot:Eco,Turbo" if ( ReadingsVal($name, ".start", "0") );  
    } else {
      $usage .= " startSpot:Normal,ExtraCare" if ( ReadingsVal($name, ".start", "0") );
    }
    $usage .= " stop:noArg"              if ( ReadingsVal($name, ".stop", "0") );
    $usage .= " pause:noArg"             if ( ReadingsVal($name, ".pause", "0") );
    $usage .= " pauseToBase:noArg"       if ( ReadingsVal($name, ".pause", "0") and ReadingsVal($name, "dockHasBeenSeen", "0") );
    $usage .= " resume:noArg"            if ( ReadingsVal($name, ".resume", "0") );
    $usage .= " sendToBase:noArg"        if ( ReadingsVal($name, ".goToBase", "0") );
    $usage .= " dismissCurrentAlert:noArg"  if ( ReadingsVal($name, "alert", "") ne "");
    $usage .= " findMe:noArg"            if (ReadingsVal($name, "srv_findMe", "") eq "basic-1");
    $usage .= " statusRequest:noArg reloadMaps:noArg schedule:on,off syncRobots:noArg";
    
    my @robots;
    if (defined($hash->{helper}{ROBOTS})) {
      @robots = @{$hash->{helper}{ROBOTS}};
      if (@robots > 1) {
        $usage .= " setRobot:";
        for (my $i = 0; $i < @robots; $i++) {
          $usage .= "," if ($i > 0);
          $usage .= $robots[$i]->{name};
        }
      }
    }

    if (ReadingsVal($name, "srv_maps", "") eq "advanced-1") {
      my @Boundaries;
      if (defined($hash->{helper}{BoundariesList})) {
        @Boundaries = @{$hash->{helper}{BoundariesList}};
        my @names;
        for (my $i = 0; $i < @Boundaries; $i++) {
          my $name = $Boundaries[$i]->{name};
          push @names,$name if (!(grep { $_ eq $name } @names) and ($name ne ""));
         }
         my $BoundariesList  = @names ? join(",", @names) : "textField";
         $usage .= " setBoundaries:".$BoundariesList;
       }
      else {
        $usage .= " setBoundaries:textField";
       }
     }

    my $cmd = '';
    my $result;


    # start
    if ( $a[1] eq "startCleaning" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        return "No argument given" if ( !defined( $a[2] ) );

        my %params;
        if (ReadingsVal($name, "srv_houseCleaning", "") eq "basic-1") {
          $params{"category"} = 2;
          $params{"mode"} = $a[2] eq "Eco" ? 1 : 2;
          $params{"modifier"} = 1;
        } elsif (ReadingsVal($name, "srv_houseCleaning", "") eq "minimal-2") {
          $params{"category"} = 2;
          $params{"navigationMode"} = $a[2] eq "Normal" ? 1 : 2;
        } elsif (ReadingsVal($name, "srv_houseCleaning", "") eq "basic-3") {
          $params{"category"} = (defined($a[3]) and $a[3] eq "Map") ? 4 : 2;
          $params{"navigationMode"} = 1; #1 normal 2 extra care 3 deep
          $params{"mode"} = $a[2] eq "Eco" ? 1 : 2;
        } else {
          return "HouseCleaning Service Version \":".ReadingsVal($name, "srv_houseCleaning", "")."\" not supported"
        }

        BOTVAC_SendCommand( $hash, "messages", "startCleaning", \%params );
    }

    elsif ( $a[1] eq "startSpot" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        return "No argument given" if ( !defined( $a[2] ) );

        my %params;
        if (ReadingsVal($name, "srv_spotCleaning", "") eq "basic-1") {
          $params{"category"} = 3;
          $params{"mode"} = $a[2] eq "Eco" ? 1 : 2;
          $params{"modifier"} = 1;
          $params{"spotWidth"} = 200;
          $params{"spotHeight"} = 200;
        } elsif (ReadingsVal($name, "srv_spotCleaning", "") eq "micro-2") {
          $params{"category"} = 3;
          $params{"navigationMode"} = $a[2] eq "Normal" ? 1 : 2;
        } elsif (ReadingsVal($name, "srv_spotCleaning", "") eq "minimal-2") {
          $params{"category"} = 3;
          $params{"modifier"} = 1;
          $params{"navigationMode"} = $a[2] eq "Normal" ? 1 : 2;
        } elsif (ReadingsVal($name, "srv_spotCleaning", "") eq "basic-3") {
          $params{"category"} = 3;
          $params{"spotWidth"} = 200;
          $params{"spotHeight"} = 200;
        } else {
          return "SpotCleaning Service Version \":".ReadingsVal($name, "srv_spotCleaning", "")."\" not supported"
        }

        BOTVAC_SendCommand( $hash, "messages", "startCleaning", \%params );
    }

    # stop
    elsif ( $a[1] eq "stop" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        BOTVAC_SendCommand( $hash, "messages", "stopCleaning" );
    }

    # pause
    elsif ( $a[1] eq "pause" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        BOTVAC_SendCommand( $hash, "messages", "pauseCleaning" );
    }

    # pauseToBase
    elsif ( $a[1] eq "pauseToBase" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        BOTVAC_SendCommand( $hash, "messages", "pauseCleaning", undef, (["messages", "sendToBase"]) );
    }

    # resume
    elsif ( $a[1] eq "resume" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        BOTVAC_SendCommand( $hash, "messages", "resumeCleaning" );
    }

    # sendToBase
    elsif ( $a[1] eq "sendToBase" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        BOTVAC_SendCommand( $hash, "messages", "sendToBase" );
    }

    # dismissCurrentAlert
    elsif ( $a[1] eq "dismissCurrentAlert" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        BOTVAC_SendCommand( $hash, "messages", "dismissCurrentAlert" );
    }

    # findMe 
    elsif ( $a[1] eq "findMe" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        BOTVAC_SendCommand( $hash, "messages", "findMe" );
    }

    # schedule
    elsif ( $a[1] eq "schedule" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        return "No argument given" if ( !defined( $a[2] ) );

        my $switch = $a[2];
        if ($switch eq "on") {
            BOTVAC_SendCommand( $hash, "messages", "enableSchedule" );
        } else {
            BOTVAC_SendCommand( $hash, "messages", "disableSchedule" );
        }
    }

    # syncRobots
    elsif ( $a[1] eq "syncRobots" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        BOTVAC_SendCommand( $hash, "dashboard" );
    }
    elsif ( $a[1] eq "statusRequest" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        BOTVAC_SendCommand( $hash, "messages", "getRobotState", undef, ["messages", "getSchedule"] );
    }

    # setRobot
    elsif ( $a[1] eq "setRobot" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        return "No argument given" if ( !defined( $a[2] ) );

        my $robot = 0;
        while($a[2] ne $robots[$robot]->{name} and $robot + 1 < @robots) {
          $robot++;
        }
        readingsBeginUpdate($hash);
        BOTVAC_SetRobot($hash, $robot);
        readingsEndUpdate( $hash, 1 );
    }
    
    # reloadMaps
    elsif ( $a[1] eq "reloadMaps" ) {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        BOTVAC_SendCommand( $hash, "maps" );
    }

    elsif ( $a[1] eq "setBoundaries") {
        Log3 $name, 2, "BOTVAC set $name " . $arg;

        return "No argument given" if ( !defined( $a[2] ) );

        my $setBoundaries = "";
        if ($a[2] =~ /^\{.*\}/){
          $setBoundaries = $a[2];
        }
        elsif (defined($hash->{helper}{BoundariesList})) {
          my @names = split ",",$a[2];
          my @Boundaries = @{$hash->{helper}{BoundariesList}};
          for (my $i = 0; $i < @Boundaries; $i++) {
            foreach my $name (@names) {
              if ($Boundaries[$i]->{name} eq $name) {
                $setBoundaries .= "," if ($setBoundaries =~ /^\{.*\}/);
                $setBoundaries .= encode_json($Boundaries[$i]);
              }
            }
          }
        }
        return "Argument of $a[1] is not a valid Boundarie name and also not a JSON string: \"$a[2]\"" if ($setBoundaries eq "");
        Log3 $name, 5, "BOTVAC set $name " . $a[1] . " " . $a[2] . " json: " . $setBoundaries;
        my %params;
        $params{"boundaries"} = "\[".$setBoundaries."\]";
        $params{"mapId"} = "\"".ReadingsVal($name, "map_persistent_id", "myHome")."\"";
        BOTVAC_SendCommand( $hash, "messages", "setMapBoundaries", \%params );
        return;
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
          "Wrong syntax: define <name> BOTVAC <email> <password> [<vendor>] [<poll-interval>]";
        Log3 $name, 4, $msg;
        return $msg;
    }

    $hash->{TYPE} = "BOTVAC";

    my $email = $a[2];
    $hash->{helper}{EMAIL} = $email;

    my $password = $a[3];
    $hash->{helper}{PASSWORD} = $password;
    
    my $param = $a[4] if (defined($a[4]));
    if (defined($param) and ($param eq "neato" or $param eq "vorwerk")) {
      $hash->{helper}{VENDOR} = $param;
      $param = $a[5];
    } else {
      $hash->{helper}{VENDOR} = "neato";
    }
    
    # use interval of 85 sec if not defined
    my $interval = $param || 85;
    $hash->{INTERVAL} = $interval;

    unless ( defined( AttrVal( $name, "webCmd", undef ) ) ) {
        $attr{$name}{webCmd} = 'startCleaning Eco:stop:sendToBase';
    }

    # start the status update timer
    RemoveInternalTimer($hash);
    InternalTimer( gettimeofday() + 2, "BOTVAC_GetStatus", $hash, 1 );

    BOTVAC_addExtension($name, "BOTVAC_GetMap", "BOTVAC/$name/map");

    return;
}

sub BOTVAC_Attr(@)
{
  my ($cmd,$name,$attr_name,$attr_value) = @_;
  my $hash  = $defs{$name};
  my $err;
  if ($cmd eq "set")
  {
    if ($attr_name eq "Boundaries") {
      if ($attr_value !~ /^\{.*\}/){
        $err = "Invalid value $attr_value for attribute $attr_name. Must be a space separated list of JSON strings.";
      }
      else {
        my @Boundaries = split " ",$attr_value;
        my @areas;
        if (@Boundaries > 1){
          foreach my $area (@Boundaries) {
            push @areas,eval{decode_json $area};
          }
        }
        else {
          push @areas,eval{decode_json $attr_value};
        }
      $hash->{helper}{BoundariesList} = \@areas;
      }
    }
  }
  else
  {
    delete $hash->{helper}{BoundariesList} if ($attr_name eq "Boundaries");
  }
 return $err ? $err : undef;
}

############################################################################################################
#
#   Begin of helper functions
#
############################################################################################################

#########################
sub BOTVAC_addExtension($$$) {
    my ( $name, $func, $link ) = @_;

    my $url = "/$link";
    Log3 $name, 2, "Registering BOTVAC $name for URL $url...";
    $data{FWEXT}{$url}{deviceName} = $name;
    $data{FWEXT}{$url}{FUNC}       = $func;
    $data{FWEXT}{$url}{LINK}       = $link;
}

#########################
sub BOTVAC_removeExtension($) {
    my ($link) = @_;

    my $url  = "/$link";
    my $name = $data{FWEXT}{$url}{deviceName};
    Log3 $name, 2, "Unregistering BOTVAC $name for URL $url...";
    delete $data{FWEXT}{$url};
}

###################################
sub BOTVAC_SendCommand($$;$$@) {
    my ( $hash, $service, $cmd, $params, @successor ) = @_;
    my $name        = $hash->{NAME};
    my $email       = $hash->{helper}{EMAIL};
    my $password    = $hash->{helper}{PASSWORD};
    my $timestamp   = gettimeofday();
    my $timeout     = 42;
    my $header;
    my $data;

    Log3 $name, 5, "BOTVAC $name: called function BOTVAC_SendCommand()";

    my $URL = "https://";
    my $response;
    my $return;
    
    my %sslArgs;

    if ($service ne "sessions" && $service ne "dashboard") {
        return if (BOTVAC_CheckRegistration($hash, $service, $cmd, $params, @successor));
    }

    if ( !defined($cmd) ) {
        Log3 $name, 4, "BOTVAC $name: REQ $service";
    }
    else {
        Log3 $name, 4, "BOTVAC $name: REQ $service/$cmd";
    }
    Log3 $name, 4, "BOTVAC $name: REQ parameters $params" if (defined($params));
    my $msg = "BOTVAC $name: REQ successors";
    my @succ_item;
    for (my $i = 0; $i < @successor; $i++) {
      @succ_item = @{$successor[$i]};
      $msg .= " $i: ";
      $msg .= join(",", map { defined($_) ? $_ : '' } @succ_item);
    }
    Log3 $name, 4, $msg;

    $header = "Accept: application/vnd.neato.nucleo.v1";
    $header .= "\r\nContent-Type: application/json";

    if ($service eq "sessions") {
      my $token = createUniqueId() . createUniqueId();
      $URL .= BOTVAC_GetBeehiveHost($hash->{helper}{VENDOR});
      $URL .= "/sessions";
      $data = "{\"platform\": \"ios\", \"email\": \"$email\", \"token\": \"$token\", \"password\": \"$password\"}";
      %sslArgs = ( SSL_verify_mode => 0 );

    } elsif ($service eq "dashboard") {
      $header .= "\r\nAuthorization: Token token=".ReadingsVal($name, "accessToken", "");
      $URL .= BOTVAC_GetBeehiveHost($hash->{helper}{VENDOR});
      $URL .= "/dashboard";
      %sslArgs = ( SSL_verify_mode => 0 );

    } elsif ($service eq "maps") {
      my $serial = ReadingsVal($name, "serial", "");
      return if ($serial eq "");

      $header .= "\r\nAuthorization: Token token=".ReadingsVal($name, "accessToken", "");
      $URL .= BOTVAC_GetBeehiveHost($hash->{helper}{VENDOR});
      $URL .= "/users/me/robots/$serial/maps";
      %sslArgs = ( SSL_verify_mode => 0 );

    } elsif ($service eq "messages") {
      my $serial = ReadingsVal($name, "serial", "");
      return if ($serial eq "");

      $URL .= BOTVAC_GetNucleoHost($hash->{helper}{VENDOR});
      $URL .= "/vendors/";
      $URL .= $hash->{helper}{VENDOR};
      $URL .= "/robots/$serial/messages";
      
      $data = "{\"reqId\":\"1\",\"cmd\":\"$cmd\"";
      if (defined($params) and ref($params) eq "HASH") {
        $data .= ",\"params\":{";
        foreach( keys %$params ) {
          $data .= "\"$_\":$params->{$_},"; 
        }
        my $tmp = chop($data);  #remove last ","
        $data .= "}";
      }
      $data .= "}";

      my $date = gmtime();
      my $message = join("\n", (lc($serial), $date, $data));
      my $hmac = hmac_sha256_hex($message, ReadingsVal($name, "secretKey", ""));

      $header .= "\r\nDate: $date";
      $header .= "\r\nAuthorization: NEATOAPP $hmac";

      #%sslArgs = ( SSL_ca =>  [ BOTVAC_GetCAKey( $hash ) ] );
      %sslArgs = ( SSL_verify_mode => 0 );
    } elsif ($service eq "loadmap") {
      $URL = $cmd;
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
            successor   => \@successor,
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
    my $hash      = $param->{hash};
    my $name      = $hash->{NAME};
    my $service   = $param->{service};
    my $cmd       = $param->{cmd};
    my @successor = @{$param->{successor}};

    my $rc = ( $param->{buf} ) ? $param->{buf} : $param;
    
    my $loadMap;
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
        my $msg = "BOTVAC $name: RCV successors";
        my @succ_item;
        for (my $i = 0; $i < @successor; $i++) {
          @succ_item = @{$successor[$i]};
          $msg .= " $i: ";
          $msg .= join(",", map { defined($_) ? $_ : '' } @succ_item);
        }
        Log3 $name, 4, $msg;

        if ( $data ne "" ) {
            if ( $service eq "loadmap" ) {
                # use $data later
            } elsif ( $data =~ /^{/ || $data =~ /^\[/ ) {
                if ( !defined($cmd) || $cmd eq "" ) {
                    Log3 $name, 4, "BOTVAC $name: RES $service - $data";
                } else {
                    Log3 $name, 4, "BOTVAC $name: RES $service/$cmd - $data";
                }
                $return = decode_json( encode_utf8($data) );
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
          if ( $cmd =~ /Schedule/ ) {
            # getSchedule, enableSchedule, disableSchedule
            if ( ref($return->{data}) eq "HASH" ) {
              my $scheduleData = $return->{data};
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "scheduleType",    $scheduleData->{type});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "scheduleEnabled", $scheduleData->{enabled});
              if (ref($scheduleData->{events}) eq "ARRAY") {
                my @events = @{$scheduleData->{events}};
                for (my $i = 0; $i < @events; $i++) {
                  BOTVAC_ReadingsBulkUpdateIfChanged($hash, "event".$i."mode",      BOTVAC_GetModeText($events[$i]->{mode}))
                      if (defined($events[$i]->{mode}));
                  BOTVAC_ReadingsBulkUpdateIfChanged($hash, "event".$i."day",       BOTVAC_GetDayText($events[$i]->{day}));
                  BOTVAC_ReadingsBulkUpdateIfChanged($hash, "event".$i."startTime", $events[$i]->{startTime});
                }
              }
            }
          } 
          elsif ( $cmd eq "getMapBoundaries" ) {
              if ( ref($return->{data}) eq "HASH" ) {
                my $boundariesData = $return->{data};
                if (ref($boundariesData->{boundaries}) eq "ARRAY") {
                  my @boundaries = @{$boundariesData->{boundaries}};
                  my $tmp = "";
                  my $boundariesList = "";
                  for (my $i = 0; $i < @boundaries; $i++) {
                    $boundariesList .= "{\"type\":\"".$boundaries[$i]->{type}."\",";
                    if (ref($boundaries[$i]->{vertices}) eq "ARRAY") {
                      my @vertices = @{$boundaries[$i]->{vertices}};
                      $boundariesList .= "\"vertices\":[";
                      for (my $e = 0; $e < @vertices; $e++) {
                        if (ref($vertices[$e]) eq "ARRAY") {
                          my @xy = @{$vertices[$e]};
                          $boundariesList .= "[".$xy[0].",".$xy[1]."],";
                        }
                      }
                    $tmp = chop($boundariesList);  #remove last ","
                    $boundariesList .= "],";
                    }
                    $boundariesList .= "\"name\":\"".$boundaries[$i]->{name}."\",";
                    $boundariesList .= "\"color\":\"".$boundaries[$i]->{color}."\",";
                    $tmp = $boundaries[$i]->{enabled} eq "1" ? "true" : "false";
                    $boundariesList .= "\"enabled\":".$tmp.",";
                    $tmp = chop($boundariesList);  #remove last ","
                    $boundariesList .= "},";
                  }
                  $tmp = chop($boundariesList);  #remove last ","
                  BOTVAC_ReadingsBulkUpdateIfChanged($hash, "boundaries", $boundariesList);
                }
              }
          } 
          else {
            # getRobotState, startCleaning, pauseCleaning, stopCleaning, resumeCleaning, sendToBase
            if ( ref($return) eq "HASH" ) {
              push(@successor , ["maps"])
                  if (defined($return->{state}) and
                      ($return->{state} == 1 or $return->{state} == 4) and   # Idle or Error
                      $return->{state} != ReadingsNum($name, "stateId", $return->{state}));
              
              #BOTVAC_ReadingsBulkUpdateIfChanged($hash, "version", $return->{version});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "result", $return->{result});
              my $error = ($return->{error}) ? $return->{error} : "";
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "error", $error);
              my $alert = ($return->{alert}) ? $return->{alert} : "";
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "alert", $alert);
              #BOTVAC_ReadingsBulkUpdateIfChanged($hash, "data", $return->{data});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "stateId", $return->{state});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "action", $return->{action});
              if ( ref($return->{cleaning}) eq "HASH" ) {
                my $cleaning = $return->{cleaning};
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "cleanCategory",  BOTVAC_GetCategoryText($cleaning->{category}));
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "cleanMode",       BOTVAC_GetModeText($cleaning->{mode}));
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "cleanModifier",   BOTVAC_GetModifierText($cleaning->{modifier}));
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "cleanNavigationMode",  BOTVAC_GetNavigationModeText($cleaning->{navigationMode}));
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
              if ( ref($return->{availableServices}) eq "HASH" ) {
                my $availableServices = $return->{availableServices};
                foreach (keys %$availableServices) {
                  BOTVAC_ReadingsBulkUpdateIfChanged($hash, "srv_$_", $availableServices->{$_});
                }
              }
              if ( ref($return->{meta}) eq "HASH" ) {
                my $meta = $return->{meta};
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "model",    $meta->{modelName});
                BOTVAC_ReadingsBulkUpdateIfChanged($hash, "firmware", $meta->{firmware});
              }
              BOTVAC_ReadingsBulkUpdateIfChanged(
                  $hash,
                  "state",
                  BOTVAC_BuildState($hash, $return->{state}, $return->{action}, $return->{error}));
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
            if ( ref($return->{robots} ) eq "ARRAY" ) {
              my @robotList = ();
              my @robots = @{$return->{robots}};
              for (my $i = 0; $i < @robots; $i++) {
                my $r = {
                  "name"      => $robots[$i]->{name},
                  "serial"    => $robots[$i]->{serial},
                  "secretKey" => $robots[$i]->{secret_key},
                  "macAddr"   => $robots[$i]->{mac_address}
                };
                push(@robotList, $r);
              }
              $hash->{helper}{ROBOTS} = \@robotList;

              BOTVAC_SetRobot($hash, ReadingsNum($name, "robot", 0));
              
              push(@successor , ["maps"]);
            }
          }
        }
    
        # maps
        elsif ( $service eq "maps" ) {
          if ( ref($return) eq "HASH" ) {
            if ( ref($return->{maps} ) eq "ARRAY" ) {
              my @mapList = ();
              my @maps = @{$return->{maps}};
              # take first - newest
              my $map = $maps[0];
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "map_status", $map->{status});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "map_id",     $map->{id});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "map_date",   FmtDateTime(str2time($map->{generated_at})));
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, "map_area",   $map->{cleaned_area});
              BOTVAC_ReadingsBulkUpdateIfChanged($hash, ".map_url",   $map->{url});
              $loadMap = 1;
              # search newest persistent map
              for (my $i = 0; $i < @maps; $i++) {
                if ($maps[$i]->{valid_as_persistent_map} == true){
                  Log3 $name, 5, "BOTVAC $name: found persistent mapId: $maps[$i]->{id}";
                  BOTVAC_ReadingsBulkUpdateIfChanged($hash, "map_persistent_id", $maps[$i]->{id});
                  # getMapBoundaries
                  if (ReadingsVal($name, "srv_maps", "") eq "advanced-1") {
                    my %params;
                    $params{"mapId"} = "\"".$maps[$i]->{id}."\"";
                    push(@successor , ["messages", "getMapBoundaries", \%params]);
                  }
                  last;
                }
              }
            }
          }
        }
        
        # loadmap
        elsif ( $service eq "loadmap" ) {
          readingsBulkUpdate($hash, ".map_cache", $data)
        }

        # all other command results
        else {
            Log3 $name, 2, "BOTVAC $name: ERROR: method to handle response of $service not implemented";
        }

    }

    readingsEndUpdate( $hash, 1 );
    
    if ($loadMap) {
      my $url = ReadingsVal($name, ".map_url", "");
    #  BOTVAC_SendCommand($hash, "loadmap", $url) if ($url ne "");
      push(@successor , ["loadmap", $url]) if ($url ne "");
    }
    
    if (@successor) {
      my @nextCmd = @{shift(@successor)};
      my $cmdLength = @nextCmd;
      my $cmdService = $nextCmd[0];
      my $cmdCmd;
      my $cmdParams;
      $cmdCmd    = $nextCmd[1] if ($cmdLength > 1);
      $cmdParams = $nextCmd[2] if ($cmdLength > 2);

      BOTVAC_SendCommand($hash, $cmdService, $cmdCmd, $cmdParams, @successor)
          if ($service ne $cmdService or $cmd ne $cmdCmd);
    }

    return;
}

sub BOTVAC_SetRobot($$) {
    my ( $hash, $robot ) = @_;
    my $name = $hash->{NAME};

    Log3 $name, 4, "BOTVAC $name: set active robot $robot";

    my @robots = @{$hash->{helper}{ROBOTS}};
    BOTVAC_ReadingsBulkUpdateIfChanged($hash, "serial",    $robots[$robot]->{serial});
    BOTVAC_ReadingsBulkUpdateIfChanged($hash, "name",      $robots[$robot]->{name});
    BOTVAC_ReadingsBulkUpdateIfChanged($hash, "secretKey", $robots[$robot]->{secretKey});
    BOTVAC_ReadingsBulkUpdateIfChanged($hash, "macAddr",   $robots[$robot]->{macAddr});
    BOTVAC_ReadingsBulkUpdateIfChanged($hash, "robot",     $robot);
}

###################################
sub BOTVAC_Undefine($$) {
    my ( $hash, $arg ) = @_;
    my $name = $hash->{NAME};

    Log3 $name, 5, "BOTVAC $name: called function BOTVAC_Undefine()";

    # Stop the internal GetStatus-Loop and exit
    RemoveInternalTimer($hash);

    BOTVAC_removeExtension("BOTVAC/$name/map");

    return;
}

sub BOTVAC_CheckRegistration($$$$$) {
  my ( $hash, $service, $cmd, $params, @successor ) = @_;
  my $name = $hash->{NAME};

  if (ReadingsVal($name, "secretKey", "") eq "") {
    my @nextCmd = ($service, $cmd, $params);
    unshift(@successor, [$service, $cmd, $params]);
      
      my @succ_item;
      my $msg = " successor:";
      for (my $i = 0; $i < @successor; $i++) {
        @succ_item = @{$successor[$i]};
        $msg .= " $i: ";
        $msg .= join(",", map { defined($_) ? $_ : '' } @succ_item);
      }
      Log3 $name, 4, "BOTVAC created".$msg;
      
    BOTVAC_SendCommand($hash, "sessions", undef, undef, @successor)   if (ReadingsVal($name, "accessToken", "") eq "");
    BOTVAC_SendCommand($hash, "dashboard", undef, undef, @successor)  if (ReadingsVal($name, "accessToken", "") ne "");
    
    return 1;
  }
  
  return;
}

sub BOTVAC_ReadingsBulkUpdateIfChanged($$$) {
  my ($hash,$reading,$value) = @_;
  my $name = $hash->{NAME};

  readingsBulkUpdate($hash, $reading, $value)
      if (defined($value) and ReadingsVal($name, $reading, "") ne $value);
}

sub BOTVAC_BuildState($$$$) {
    my ($hash,$state,$action,$error) = @_;
    my $states = {
        '0'       => "Invalid",
        '1'       => "Idle",
        '2'       => "Busy",
        '3'       => "Paused",
        '4'       => "Error"
    };

    if (!defined($state)) {
        return "Unknown";
    } elsif ($state == 2) {
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
        '0'       => "Invalid",
        '1'       => "House Cleaning",
        '2'       => "Spot Cleaning",
        '3'       => "Manual Cleaning",
        '4'       => "Docking",
        '5'       => "User Menu Active",
        '6'       => "Suspended Cleaning",
        '7'       => "Updating",
        '8'       => "Copying Logs",
        '9'       => "Recovering Location",
        '10'      => "IEC Test",
        '11'      => "Map cleaning",
        '12'      => "Exploring map (creating a persistent map)",
        '13'      => "Acquiring Persistent Map IDs",
        '14'      => "Creating & Uploading Map",
        '15'      => "Suspended Exploration"
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

sub BOTVAC_GetCategoryText($) {
    my ($category) = @_;
    my $categorys = {
        '1'       => "manual",
        '2'       => "house",
        '3'       => "spot",
        '4'       => "map"
    };

    if (defined( $categorys->{$category})) {
        return $categorys->{$category};
    } else {
        return $category;
    }
}

sub BOTVAC_GetModeText($) {
    my ($mode) = @_;
    my $modes = {
        '1'       => "eco",
        '2'       => "turbo"
    };

    if (defined( $modes->{$mode})) {
        return $modes->{$mode};
    } else {
        return $mode;
    }
}

sub BOTVAC_GetModifierText($) {
    my ($modifier) = @_;
    my $modifiers = {
        '1'       => "normal",
        '2'       => "double"
    };

    if (defined( $modifiers->{$modifier})) {
        return $modifiers->{$modifier};
    } else {
        return $modifier;
    }
}

sub BOTVAC_GetNavigationModeText($) {
    my ($navigationMode) = @_;
    my $navigationModes = {
        '1'       => "normal",
        '2'       => "extra care",
        '3'       => "deep"
    };

    if (defined( $navigationModes->{$navigationMode})) {
        return $navigationModes->{$navigationMode};
    } else {
        return $navigationMode;
    }
}

sub BOTVAC_GetDayText($) {
    my ($day) = @_;
    my $days = {
        '0'       => "Sunday",
        '1'       => "Monday",
        '2'       => "Tuesday",
        '3'       => "Wednesday",
        '4'       => "Thursday",
        '5'       => "Friday",
        '6'       => "Saturda"
    };

    if (defined( $days->{$day})) {
        return $days->{$day};
    } else {
        return $day;
    }
}

sub BOTVAC_GetBeehiveHost($) {
    my ($vendor) = @_;
    my $vendors = {
        'neato'   => 'beehive.neatocloud.com',
        'vorwerk' => 'vorwerk-beehive-production.herokuapp.com',
    };

    if (defined( $vendors->{$vendor})) {
        return $vendors->{$vendor};
    } else {
        return $vendors->{neato};
    }
}

sub BOTVAC_GetNucleoHost($) {
    my ($vendor) = @_;
    my $vendors = {
        'neato'   => 'nucleo.neatocloud.com',
        'vorwerk' => 'nucleo.ksecosys.com',
    };

    if (defined( $vendors->{$vendor})) {
        return $vendors->{$vendor};
    } else {
        return $vendors->{neato};
    }
}

sub BOTVAC_ShowMap($;$$) {
    my ($name,$width,$height) = @_;

    my $img = '<img src="/fhem/BOTVAC/'.$name.'/map"';
    $img   .= ' width="'.$width.'"'  if (defined($width));
    $img   .= ' width="'.$height.'"' if (defined($height));
    $img   .= ' alt="Map currently not available">';
    
    return $img;
}

sub BOTVAC_GetMap() {
    my ($request) = @_;
    
    if ($request =~ /^\/BOTVAC\/(\w+)\/map/) {
      my $name   = $1;
      my $width  = $3;
      my $height = $5;
      
      return ("image/png", ReadingsVal($name, ".map_cache", ""));
    }

    return ("text/plain; charset=utf-8", "No BOTVAC device for webhook $request");
    
}

#sub BOTVAC_GetCAKey($) {
#  my ( $hash ) = @_;
#  
#  my $ca_key = q{-----BEGIN CERTIFICATE-----
#MIIE3DCCA8SgAwIBAgIJALHphD11lrmHMA0GCSqGSIb3DQEBBQUAMIGkMQswCQYD
#VQQGEwJVUzELMAkGA1UECBMCQ0ExDzANBgNVBAcTBk5ld2FyazEbMBkGA1UEChMS
#TmVhdG8gUm9ib3RpY3MgSW5jMRcwFQYDVQQLEw5DbG91ZCBTZXJ2aWNlczEZMBcG
#A1UEAxQQKi5uZWF0b2Nsb3VkLmNvbTEmMCQGCSqGSIb3DQEJARYXY2xvdWRAbmVh
#dG9yb2JvdGljcy5jb20wHhcNMTUwNDIxMTA1OTA4WhcNNDUwNDEzMTA1OTA4WjCB
#pDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAkNBMQ8wDQYDVQQHEwZOZXdhcmsxGzAZ
#BgNVBAoTEk5lYXRvIFJvYm90aWNzIEluYzEXMBUGA1UECxMOQ2xvdWQgU2Vydmlj
#ZXMxGTAXBgNVBAMUECoubmVhdG9jbG91ZC5jb20xJjAkBgkqhkiG9w0BCQEWF2Ns
#b3VkQG5lYXRvcm9ib3RpY3MuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
#CgKCAQEAur0WFcJ2YvnL3dtXJFv3lfCQtELLHVcux88tH7HN/FTeUvCqdleDNv4S
#mXWgxVOdUUuhV885wppYyXNzDDrwCyjPmYj0m1EZ4FqTCcjFmk+xdEJsPsKPgRt5
#QqaO0CA/T7dcIhT/PtQnJtcjn6E6vt2JLhsLz9OazadwjvdkejmfrOL643FGxsIP
#8hu3+JINcfxnmff85zshe0yQH5yIYkmQGUPQz061T6mMzFrED/hx9zDpiB1mfkUm
#uG3rBVcZWtrdyMvqB9LB1vqKgcCRANVg5S0GKpySudFlHOZjekXwBsZ+E6tW53qx
#hvlgmlxX80aybYC5hQaNSQBaV9N4lwIDAQABo4IBDTCCAQkwHQYDVR0OBBYEFM3g
#l7v7HP6zQgF90eHIl9coH6jhMIHZBgNVHSMEgdEwgc6AFM3gl7v7HP6zQgF90eHI
#l9coH6jhoYGqpIGnMIGkMQswCQYDVQQGEwJVUzELMAkGA1UECBMCQ0ExDzANBgNV
#BAcTBk5ld2FyazEbMBkGA1UEChMSTmVhdG8gUm9ib3RpY3MgSW5jMRcwFQYDVQQL
#Ew5DbG91ZCBTZXJ2aWNlczEZMBcGA1UEAxQQKi5uZWF0b2Nsb3VkLmNvbTEmMCQG
#CSqGSIb3DQEJARYXY2xvdWRAbmVhdG9yb2JvdGljcy5jb22CCQCx6YQ9dZa5hzAM
#BgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUAA4IBAQB93p+MUmKH+MQI3pEVvPUW
#y+VDB5qt1spE5J0awVwUzhQ7QXkEqgFfOk0kzufvxdha9wz+05E1glQ8l5CzlATu
#kA7V5OsygYB+TgqjvhfFHkSI6TJ8OlKcAJuZ2yQE8s2+LVo92NLwpooZLA6BCahn
#fX+rzmo6b4ylhyX98Tm3upINNH3whV355PJFgk74fw9N7U6cFlBrqXXssKOse2D2
#xY65IK7OQxSq5K5OPFLwN3h/eURo5kwl7jhpJhJbFL4I46OkpgqWHxQEqSxQnS0d
#AC62ApwWkm42i0/DGODms2tnGL/DaCiTkgEE+8EEF9kfvQDtMoUDNvIkl7Vvm914
#-----END CERTIFICATE-----};
#
#  my $ca_key_vorwerk = q{-----BEGIN CERTIFICATE-----
#MIIFCTCCA/GgAwIBAgIJAMOv+HZbfpj5MA0GCSqGSIb3DQEBBQUAMIGzMQswCQYD
#VQQGEwJERTEcMBoGA1UECBMTTm9yZHJoZWluLVdlc3RmYWxlbjESMBAGA1UEBxMJ
#V3VwcGVydGFsMRkwFwYDVQQKFBBWb3J3ZXJrICYgQ28uIEtHMQ4wDAYDVQQLEwVD
#bG91ZDEXMBUGA1UEAxQOKi5rc2Vjb3N5cy5jb20xLjAsBgkqhkiG9w0BCQEWH3Zv
#cndlcmstY2xvdWRAbmVhdG9yb2JvdGljcy5jb20wHhcNMTUwNjMwMDkzMzM0WhcN
#NDUwNjIyMDkzMzM0WjCBszELMAkGA1UEBhMCREUxHDAaBgNVBAgTE05vcmRyaGVp
#bi1XZXN0ZmFsZW4xEjAQBgNVBAcTCVd1cHBlcnRhbDEZMBcGA1UEChQQVm9yd2Vy
#ayAmIENvLiBLRzEOMAwGA1UECxMFQ2xvdWQxFzAVBgNVBAMUDioua3NlY29zeXMu
#Y29tMS4wLAYJKoZIhvcNAQkBFh92b3J3ZXJrLWNsb3VkQG5lYXRvcm9ib3RpY3Mu
#Y29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7gtMukRfXrkNB5/C
#kSyRYWC7Na8QA7ryRUY1pk/NiuehHCG5DfLUNrtBauJPTSrLIrEQGo+E07WYDUmg
#7vTeIwUgUrp1EAPe/2ebL8/z+U74o46vVo4r7x2ANd1CP7nUqcwXaPVOCwvZmWT0
#5sdpOkeUbjqeaIGKATEfFYp0/58xaQwLiVh3ujd9CfsB+7ttH6H4NF9iU0xZuqO4
#A5pQVrUEme+wwj3XrSLDpQehvjNG9nsA1urmdaPXSMHUSvCdasuxCHVmzyrP8+78
#Luum6lGKxxfW/uC2zXXTlyVtNUkJJji+JGIkZ+wY9OXflW213zeDIHdAhbvPxJT0
#CnQJawIDAQABo4IBHDCCARgwHQYDVR0OBBYEFNO5y/NI8+UR3GhGZ7ru6EMO+soU
#MIHoBgNVHSMEgeAwgd2AFNO5y/NI8+UR3GhGZ7ru6EMO+soUoYG5pIG2MIGzMQsw
#CQYDVQQGEwJERTEcMBoGA1UECBMTTm9yZHJoZWluLVdlc3RmYWxlbjESMBAGA1UE
#BxMJV3VwcGVydGFsMRkwFwYDVQQKFBBWb3J3ZXJrICYgQ28uIEtHMQ4wDAYDVQQL
#EwVDbG91ZDEXMBUGA1UEAxQOKi5rc2Vjb3N5cy5jb20xLjAsBgkqhkiG9w0BCQEW
#H3ZvcndlcmstY2xvdWRAbmVhdG9yb2JvdGljcy5jb22CCQDDr/h2W36Y+TAMBgNV
#HRMEBTADAQH/MA0GCSqGSIb3DQEBBQUAA4IBAQCgcAC1QbiITOdesQcoEzSCULXE
#3DzOg3Cs6sSBMc8uZ+LRRaJNEvzR6QVA9l1poKY0yQQ7U32xFBadxXGFk5YZlMr+
#MkFzcQxywTKuGDCkOqf8M6NtZjmH3DNAP9bBHhMb80IVwkZhOM7F5nSbZkDxOANo
#O8KtJgpH5rQWGh3FH0SaV0VCjIBK6fLuGZmGvrN06T4bl08QBa2iaodNBQh7IvCG
#eXkUm1eYWDZ4Kzzi7rDgHYHOBlTlDoxfb3ravORZqr0+HYzOP90QbVYtO3a2nyoZ
#L+zBelsUcVFQYsM2oiY6AvCCPQLAYF9X9r9yLBPteLrWZUGjcuzmWe0QEhE+
#-----END CERTIFICATE-----
#    
#  };
#
#  if ($hash->{helper}{VENDOR} eq "vorwerk") {
#    return PEM_string2cert($ca_key_vorwerk);
#  } else {
#    return PEM_string2cert($ca_key);
#  }
#}

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
