# $Id: 70_BOTVAC.pm 050 2018-11-17 12:34:56Z VuffiRaa$
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
# Version: 0.5.0
#
##############################################################################

package main;

use strict;
use warnings;


sub BOTVAC_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}    = "BOTVAC::Define";
    $hash->{GetFn}    = "BOTVAC::Get";
    $hash->{SetFn}    = "BOTVAC::Set";
    $hash->{UndefFn}  = "BOTVAC::Undefine";
    $hash->{DeleteFn} = "BOTVAC::Delete";
    $hash->{AttrFn}   = "BOTVAC::Attr";
    $hash->{AttrList} = "disable:0,1 " .
                        "actionInterval " .
                        "boundaries:textField-long " .
                         $::readingFnAttributes;
}


package BOTVAC;

use strict;
use warnings;
use POSIX;

use GPUtils qw(:all);  # wird für den Import der FHEM Funktionen aus der fhem.pl benötigt

use Time::HiRes qw(gettimeofday);
use JSON qw(decode_json);
#use IO::Socket::SSL::Utils qw(PEM_string2cert);
use Digest::SHA qw(hmac_sha256_hex);
use Encode qw(encode_utf8);

## Import der FHEM Funktionen
BEGIN {
    GP_Import(qw(
        AttrVal
        createUniqueId
        FmtDateTimeRFC1123
        getKeyValue
        getUniqueId
        InternalTimer
        InternalVal
        readingsSingleUpdate
        readingsBulkUpdate
        readingsBulkUpdateIfChanged
        readingsBeginUpdate
        readingsEndUpdate
        ReadingsNum
        ReadingsVal
        RemoveInternalTimer
        Log3
    ))
};

###################################
sub Define($$) {
    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );
    my $name = $hash->{NAME};

    Log3($name, 5, "BOTVAC $name: called function Define()");

    if ( int(@a) < 3 ) {
        my $msg =
          "Wrong syntax: define <name> BOTVAC <email> [<vendor>] [<poll-interval>]";
        Log3($name, 4, $msg);
        return $msg;
    }

    $hash->{TYPE} = "BOTVAC";

    my $email = $a[2];
    $hash->{EMAIL} = $email;

    # defaults
    my $vendor = "neato";
    my $interval = 85;

    if (defined($a[3])) {
      if ($a[3] =~ /^(neato|vorwerk)$/) {
        $vendor = $a[3];
        $interval = $a[4] if (defined($a[4]));
      } elsif ($a[3] =~ /^[0-9]+$/ and not defined($a[4])) {
        $interval = $a[3];
      } else {
        StorePassword($hash, $a[3]);
        if (defined($a[4])) {
          if ($a[4] =~ /^(neato|vorwerk)$/) {
            $vendor = $a[4];
            $interval = $a[5] if (defined($a[5]));
          } else {
            $interval = $a[5];
          }
        }
      }
    }
    $hash->{VENDOR} = $vendor;
    $hash->{INTERVAL} = $interval;

    unless ( defined( AttrVal( $name, "webCmd", undef ) ) ) {
        $::attr{$name}{webCmd} = 'startCleaning:stop:sendToBase';
    }

    # start the status update timer
    RemoveInternalTimer($hash);
    InternalTimer( gettimeofday() + 2, "BOTVAC::GetStatus", $hash, 1 );

    AddExtension($name, "BOTVAC::GetMap", "BOTVAC/$name/map");

    return;
}

#####################################
sub GetStatus($;$) {
    my ( $hash, $update ) = @_;
    my $name     = $hash->{NAME};
    my $interval = $hash->{INTERVAL};
    
    Log3($name, 5, "BOTVAC $name: called function GetStatus()");

    # use actionInterval if state is busy or paused
    $interval = AttrVal($name, "actionInterval", $interval) if (ReadingsVal($name, "stateId", "0") =~ /2|3/);

    RemoveInternalTimer($hash);
    InternalTimer( gettimeofday() + $interval, "BOTVAC::GetStatus", $hash, 0 );

    return if ( AttrVal($name, "disable", 0) == 1 );

    # check device availability
    if (!$update) {
      my @time = localtime();
      my $secs = ($time[2] * 3600) + ($time[1] * 60) + $time[0];

      if ($secs <= $interval) {
        # update once per day
        SendCommand( $hash, "dashboard", undef, undef, (["messages", "getRobotState"], ["messages", "getSchedule"]) ); 
      } else {
        SendCommand( $hash, "messages", "getRobotState", undef, ["messages", "getSchedule"] );
      }        
    }

    return;
}

###################################
sub Get($@) {
    my ( $hash, @a ) = @_;
    my $name = $hash->{NAME};
    my $what;

    Log3($name, 5, "BOTVAC $name: called function Get()");

    return "argument is missing" if ( int(@a) < 2 );

    $what = $a[1];

    if ( $what =~ /^(batteryPercent)$/ ) {
        if ( defined( $hash->{READINGS}{$what}{VAL} ) ) {
            return $hash->{READINGS}{$what}{VAL};
        } else {
            return "no such reading: $what";
        }
    } else {
        return "Unknown argument $what, choose one of batteryPercent:noArg";
    }
}

###################################
sub Set($@) {
    my ( $hash, @a ) = @_;
    my $name  = $hash->{NAME};

    Log3($name, 5, "BOTVAC $name: called function Set()");

    return "No Argument given" if ( !defined( $a[1] ) );

    my $arg = $a[1];
    $arg .= " ".$a[2] if (defined( $a[2] ));
    $arg .= " ".$a[3] if (defined( $a[3] ));

    my $usage = "Unknown argument " . $a[1] . ", choose one of";

    $usage .= " password";
    if ( ReadingsVal($name, ".start", "0") ) {
      $usage .= " startCleaning:";
      $usage .= (GetServiceVersion($hash, "houseCleaning") eq "basic-3" ? "house,map" : "noArg");
      $usage .= " startSpot:noArg";
    }
    $usage .= " stop:noArg"                if ( ReadingsVal($name, ".stop", "0") );
    $usage .= " pause:noArg"               if ( ReadingsVal($name, ".pause", "0") );
    $usage .= " pauseToBase:noArg"         if ( ReadingsVal($name, ".pause", "0") and ReadingsVal($name, "dockHasBeenSeen", "0") );
    $usage .= " resume:noArg"              if ( ReadingsVal($name, ".resume", "0") );
    $usage .= " sendToBase:noArg"          if ( ReadingsVal($name, ".goToBase", "0") );
    $usage .= " reloadMaps:noArg"          if ( GetServiceVersion($hash, "maps") ne "" );
    $usage .= " dismissCurrentAlert:noArg" if ( ReadingsVal($name, "alert", "") ne "" );
    $usage .= " findMe:noArg"              if ( GetServiceVersion($hash, "findMe") eq "basic-1" );
    $usage .= " manualCleaningMode:noArg"  if ( GetServiceVersion($hash, "manualCleaning") ne "" );
    $usage .= " statusRequest:noArg schedule:on,off syncRobots:noArg";
    
    my $houseCleaningSrv = GetServiceVersion($hash, "houseCleaning");
    my $spotCleaningSrv = GetServiceVersion($hash, "spotCleaning");
    # house cleaning
    $usage .= " nextCleaningMode:eco,turbo" if ($houseCleaningSrv =~ /basic-\d/);
    $usage .= " nextCleaningNavigationMode:normal,extra#care" if ($houseCleaningSrv eq "minimal-2");
    $usage .= " nextCleaningNavigationMode:normal,extra#care,deep" if ($houseCleaningSrv eq "basic-3");
    #spot cleaning
    $usage .= " nextCleaningModifier:normal,double" if ($spotCleaningSrv eq "basic-1" or $spotCleaningSrv eq "minimal-2");
    if ($spotCleaningSrv =~ /basic-\d/) {
      $usage .= " nextCleaningSpotWidth:100,200,300,400";
      $usage .= " nextCleaningSpotHeight:100,200,300,400";
    }

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

    if (GetServiceVersion($hash, "maps") eq "advanced-1" or GetServiceVersion($hash, "maps") eq "macro-1") {
      if (defined($hash->{helper}{BoundariesList})) {
        my @Boundaries = @{$hash->{helper}{BoundariesList}};
        my @names;
        for (my $i = 0; $i < @Boundaries; $i++) {
          my $name = $Boundaries[$i]->{name};
          push @names,$name if (!(grep { $_ eq $name } @names) and ($name ne ""));
        }
        my $BoundariesList  = @names ? join(",", @names) : "textField";
        $usage .= " setBoundariesOnFloorplan_0:".$BoundariesList if (ReadingsVal($name, "floorplan_0_id" ,"") ne "");
        $usage .= " setBoundariesOnFloorplan_1:".$BoundariesList if (ReadingsVal($name, "floorplan_1_id" ,"") ne "");
        $usage .= " setBoundariesOnFloorplan_2:".$BoundariesList if (ReadingsVal($name, "floorplan_2_id" ,"") ne "");
      }
      else {
        $usage .= " setBoundariesOnFloorplan_0:textField" if (ReadingsVal($name, "floorplan_0_id" ,"") ne "");
        $usage .= " setBoundariesOnFloorplan_1:textField" if (ReadingsVal($name, "floorplan_1_id" ,"") ne "");
        $usage .= " setBoundariesOnFloorplan_2:textField" if (ReadingsVal($name, "floorplan_2_id" ,"") ne "");
      }
    }

    my $cmd = '';
    my $result;


    # house cleaning
    if ( $a[1] eq "startCleaning" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        my $option = "2";
        $option = "4" if (defined($a[2]) and $a[2] eq "map");
        SendCommand( $hash, "messages", "startCleaning", $option );
    }

    # spot cleaning
    elsif ( $a[1] eq "startSpot" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "messages", "startSpot" );
    }

    # stop
    elsif ( $a[1] eq "stop" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "messages", "stopCleaning" );
    }

    # pause
    elsif ( $a[1] eq "pause" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "messages", "pauseCleaning" );
    }

    # pauseToBase
    elsif ( $a[1] eq "pauseToBase" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "messages", "pauseCleaning", undef, (["messages", "sendToBase"]) );
    }

    # resume
    elsif ( $a[1] eq "resume" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "messages", "resumeCleaning" );
    }

    # sendToBase
    elsif ( $a[1] eq "sendToBase" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "messages", "sendToBase" );
    }

    # dismissCurrentAlert
    elsif ( $a[1] eq "dismissCurrentAlert" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "messages", "dismissCurrentAlert" );
    }

    # findMe
    elsif ( $a[1] eq "findMe" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "messages", "findMe" );
    }

    # manualCleaningMode
    elsif ( $a[1] eq "manualCleaningMode" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "messages", "getRobotManualCleaningInfo" );
    }

    # schedule
    elsif ( $a[1] eq "schedule" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        return "No argument given" if ( !defined( $a[2] ) );

        my $switch = $a[2];
        if ($switch eq "on") {
            SendCommand( $hash, "messages", "enableSchedule" );
        } else {
            SendCommand( $hash, "messages", "disableSchedule" );
        }
    }

    # syncRobots
    elsif ( $a[1] eq "syncRobots" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "dashboard" );
    }

    # statusRequest
    elsif ( $a[1] eq "statusRequest" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "messages", "getRobotState", undef, ["messages", "getSchedule"] );
    }

    # setRobot
    elsif ( $a[1] eq "setRobot" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        return "No argument given" if ( !defined( $a[2] ) );

        my $robot = 0;
        while($a[2] ne $robots[$robot]->{name} and $robot + 1 < @robots) {
          $robot++;
        }
        readingsBeginUpdate($hash);
        SetRobot($hash, $robot);
        readingsEndUpdate( $hash, 1 );
    }
    
    # reloadMaps
    elsif ( $a[1] eq "reloadMaps" ) {
        Log3($name, 2, "BOTVAC set $name $arg");

        SendCommand( $hash, "robots", "maps");
    }

    # setBoundaries
    elsif ( $a[1] =~ /^setBoundariesOnFloorplan_\d$/) {
        my $floorplan = substr($a[1],25,1);
        Log3($name, 2, "BOTVAC set $name $arg");

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
        Log3($name, 5, "BOTVAC set $name " . $a[1] . " " . $a[2] . " json: " . $setBoundaries);
        my %params;
        $params{"boundaries"} = "\[".$setBoundaries."\]";
        $params{"mapId"} = "\"".ReadingsVal($name, "floorplan_".$floorplan."_id", "myHome")."\"";
        SendCommand( $hash, "messages", "setMapBoundaries", \%params );
        return;
    }

    # nextCleaning
    elsif ( $a[1] =~ /nextCleaning/) {
        Log3($name, 2, "BOTVAC set $name $arg");

        return "No argument given" if ( !defined( $a[2] ) );

        readingsSingleUpdate($hash, $a[1], $a[2], 0);
    }
    
    # password
    elsif ( $a[1] eq "password") {
        Log3($name, 2, "BOTVAC set $name " . $a[1]);

        return "No password given" if ( !defined( $a[2] ) );

        StorePassword( $hash, $a[2] );
    }

    # return usage hint
    else {
        return $usage;
    }

    return;
}

###################################
sub Undefine($$) {
    my ( $hash, $arg ) = @_;
    my $name = $hash->{NAME};

    Log3($name, 5, "BOTVAC $name: called function Undefine()");

    # Stop the internal GetStatus-Loop and exit
    RemoveInternalTimer($hash);

    RemoveExtension("BOTVAC/$name/map");

    return;
}

###################################
sub Delete($$) {
    my ( $hash, $arg ) = @_;
    my $name = $hash->{NAME};

    Log3($name, 5, "BOTVAC $name: called function Delete()");

    my $index = $hash->{TYPE}."_".$name."_passwd";
    setKeyValue($index,undef);

    return;
}

###################################
sub Attr(@)
{
  my ($cmd,$name,$attr_name,$attr_value) = @_;
  my $hash  = $::defs{$name};
  my $err;
  if ($cmd eq "set") {
    if ($attr_name eq "boundaries") {
      if ($attr_value !~ /^\{.*\}/){
        $err = "Invalid value $attr_value for attribute $attr_name. Must be a space separated list of JSON strings.";
      } else {
        my @boundaries = split " ",$attr_value;
        my @areas;
        if (@boundaries > 1) {
          foreach my $area (@boundaries) {
            push @areas,eval{decode_json $area};
          }
        } else {
          push @areas,eval{decode_json $attr_value};
        }
      $hash->{helper}{BoundariesList} = \@areas;
      }
    }
  } else {
    delete $hash->{helper}{BoundariesList} if ($attr_name eq "boundaries");
  }
  return $err ? $err : undef;
}

############################################################################################################
#
#   Begin of helper functions
#
############################################################################################################

#########################
sub AddExtension($$$) {
    my ( $name, $func, $link ) = @_;

    my $url = "/$link";
    Log3($name, 2, "Registering BOTVAC $name for URL $url...");
    $::data{FWEXT}{$url}{deviceName} = $name;
    $::data{FWEXT}{$url}{FUNC}       = $func;
    $::data{FWEXT}{$url}{LINK}       = $link;
}

#########################
sub RemoveExtension($) {
    my ($link) = @_;

    my $url  = "/$link";
    my $name = $::data{FWEXT}{$url}{deviceName};
    Log3($name, 2, "Unregistering BOTVAC $name for URL $url...");
    delete $::data{FWEXT}{$url};
}

###################################
sub SendCommand($$;$$@) {
    my ( $hash, $service, $cmd, $option, @successor ) = @_;
    my $name        = $hash->{NAME};
    my $email       = $hash->{EMAIL};
    my $password    = ReadPassword($hash);
    my $timestamp   = gettimeofday();
    my $timeout     = 180;
    my $header;
    my $data;
    my $reqId = 0;

    Log3($name, 5, "BOTVAC $name: called function SendCommand()");

    my $URL = "https://";
    my $response;
    my $return;
    
    my %sslArgs;

    if ($service ne "sessions" && $service ne "dashboard") {
        return if (CheckRegistration($hash, $service, $cmd, $option, @successor));
    }

    if ( !defined($cmd) ) {
        Log3($name, 4, "BOTVAC $name: REQ $service");
    }
    else {
        Log3($name, 4, "BOTVAC $name: REQ $service/$cmd");
    }
    Log3($name, 4, "BOTVAC $name: REQ option $option") if (defined($option));
    my $msg = "BOTVAC $name: REQ successors";
    my @succ_item;
    for (my $i = 0; $i < @successor; $i++) {
      @succ_item = @{$successor[$i]};
      $msg .= " $i: ";
      $msg .= join(",", map { defined($_) ? $_ : '' } @succ_item);
    }
    Log3($name, 4, $msg);

    $header = "Accept: application/vnd.neato.nucleo.v1";
    $header .= "\r\nContent-Type: application/json";

    if ($service eq "sessions") {
      return if (!defined($password));
      my $token = createUniqueId() . createUniqueId();
      $URL .= GetBeehiveHost($hash->{VENDOR});
      $URL .= "/sessions";
      $data = "{\"platform\": \"ios\", \"email\": \"$email\", \"token\": \"$token\", \"password\": \"$password\"}";
      %sslArgs = ( SSL_verify_mode => 0 );

    } elsif ($service eq "dashboard") {
      $header .= "\r\nAuthorization: Token token=".ReadingsVal($name, "accessToken", "");
      $URL .= GetBeehiveHost($hash->{VENDOR});
      $URL .= "/dashboard";
      %sslArgs = ( SSL_verify_mode => 0 );

    } elsif ($service eq "robots") {
      my $serial = ReadingsVal($name, "serial", "");
      return if ($serial eq "");

      $header .= "\r\nAuthorization: Token token=".ReadingsVal($name, "accessToken", "");
      $URL .= GetBeehiveHost($hash->{VENDOR});
      $URL .= "/users/me/robots/$serial/";
      $URL .= (defined($cmd) ? $cmd : "maps");
      %sslArgs = ( SSL_verify_mode => 0 );

    } elsif ($service eq "messages") {
      my $serial = ReadingsVal($name, "serial", "");
      return if ($serial eq "");

      $URL = ReadingsVal($name, "nucleoUrl", "https://".GetNucleoHost($hash->{VENDOR}));
      $URL .= "/vendors/";
      $URL .= $hash->{VENDOR};
      $URL .= "/robots/$serial/messages";

      if (defined($option) and ref($option) eq "HASH" ) {
        if (defined($option->{reqId})) {
          $reqId = $option->{reqId};
        }
      }

      $data = "{\"reqId\":\"$reqId\",\"cmd\":\"$cmd\"";
      if ($cmd eq "startCleaning") {
        $data .= ",\"params\":{";
        my $version = GetServiceVersion($hash, "houseCleaning");
        if ($version eq "basic-1") {
          $data .= "\"category\":2";
          $data .= ",\"mode\":";
          $data .= (GetCleaningParameter($hash, "cleaningMode", "eco") eq "eco" ? "1" : "2");
          $data .= ",\"modifier\":1"; 
        } elsif ($version eq "minimal-2") {
          $data .= "\"category\":2";
          $data .= ",\"navigationMode\":";
          $data .= (GetCleaningParameter($hash, "cleaningNavigationMode", "normal") eq "normal" ? "1" : "2");
        } elsif ($version eq "basic-3") {
          $data .= "\"category\":";
          $data .= (defined($option) ? $option : "2");
          $data .= ",\"mode\":";
          my $cleanMode = GetCleaningParameter($hash, "cleaningMode", "eco");
          $data .= ($cleanMode eq "eco" ? "1" : "2");
          $data .= ",\"navigationMode\":";
          my $navMode = GetCleaningParameter($hash, "cleaningNavigationMode", "normal");
          if ($navMode eq "deep" and $cleanMode = "turbo") {
            $data .= "3";
          } elsif ($navMode eq "extra care") {
            $data .= "2";
          } else {
            $data .= "1";
          }
        }          
        $data .= "}";
      }
      elsif ($cmd eq "startSpot") {
        $data = "{\"reqId\":\"$reqId\",\"cmd\":\"startCleaning\"";
        $data .= ",\"params\":{";
        $data .= "\"category\":3";
        my $version = GetServiceVersion($hash, "spotCleaning");
        if ($version eq "basic-1") {
          $data .= ",\"mode\":";
          $data .= (GetCleaningParameter($hash, "cleaningMode", "eco") eq "eco" ? "1" : "2");
        }
        if ($version eq "basic-1" or $version eq "minimal-2") {
          $data .= ",\"modifier\":"; 
          $data .= (GetCleaningParameter($hash, "cleaningModifier", "normal") eq "normal" ? "1" : "2");
        }
        if ($version eq "micro-2" or $version eq "minimal-2") {
          $data .= ",\"navigationMode\":";
          $data .= (GetCleaningParameter($hash, "cleaningNavigationMode", "normal") eq "normal" ? "1" : "2");
        }
        if ($version eq "basic-1" or $version eq "basic-3") {
          $data .= ",\"spotWidth\":"; 
          $data .= GetCleaningParameter($hash, "cleaningSpotWidth", "200");
          $data .= ",\"spotHeight\":"; 
          $data .= GetCleaningParameter($hash, "cleaningSpotHeight", "200");
        }          
        $data .= "}";
      }
      elsif ($cmd eq "setMapBoundaries" or $cmd eq "getMapBoundaries") {   
        if (defined($option) and ref($option) eq "HASH") {
          $data .= ",\"params\":{";
          foreach( keys %$option ) {
            $data .= "\"$_\":$option->{$_}," if ($_ ne "reqId");
          }
          my $tmp = chop($data);  #remove last ","
          $data .= "}";
        }
      }
      
      $data .= "}";

      my $now = time();
      my $date = FmtDateTimeRFC1123($now);
      my $message = join("\n", (lc($serial), $date, $data));
      my $hmac = hmac_sha256_hex($message, ReadingsVal($name, "secretKey", ""));

      $header .= "\r\nDate: $date";
      $header .= "\r\nAuthorization: NEATOAPP $hmac";

      #%sslArgs = ( SSL_ca =>  [ GetCAKey( $hash ) ] );
      %sslArgs = ( SSL_verify_mode => 0 );
    } elsif ($service eq "loadmap") {
      $URL = $cmd;
    }

    # send request via HTTP-POST method
    Log3($name, 5, "BOTVAC $name: POST $URL (" . ::urlDecode($data) . ")")
      if ( defined($data) );
    Log3($name, 5, "BOTVAC $name: GET $URL")
      if ( !defined($data) );
    Log3($name, 5, "BOTVAC $name: header $header")
      if ( defined($header) );

    ::HttpUtils_NonblockingGet(
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
            callback    => \&ReceiveCommand,
        }
    );

    return;
}

###################################
sub ReceiveCommand($$$) {
    my ( $param, $err, $data ) = @_;
    my $hash      = $param->{hash};
    my $name      = $hash->{NAME};
    my $service   = $param->{service};
    my $cmd       = $param->{cmd};
    my @successor = @{$param->{successor}};

    my $rc = ( $param->{buf} ) ? $param->{buf} : $param;
    
    my $loadMap;
    my $return;
    my $reqId = 0;

    Log3($name, 5, "BOTVAC $name: called function ReceiveCommand() rc: $rc err: $err data: $data ");

    readingsBeginUpdate($hash);

    # device not reachable
    if ($err) {

        if ( !defined($cmd) || $cmd eq "" ) {
            Log3($name, 4, "BOTVAC $name:$service RCV $err");
        } else {
            Log3($name, 4, "BOTVAC $name:$service/$cmd RCV $err");
        }

        # keep last state
        #readingsBulkUpdateIfChanged( $hash, "state", "Error" );
    }

    # data received
    elsif ($data) {
      
        if ( !defined($cmd) ) {
            Log3($name, 4, "BOTVAC $name: RCV $service");
        } else {
            Log3($name, 4, "BOTVAC $name: RCV $service/$cmd");
        }
        my $msg = "BOTVAC $name: RCV successors";
        my @succ_item;
        for (my $i = 0; $i < @successor; $i++) {
          @succ_item = @{$successor[$i]};
          $msg .= " $i: ";
          $msg .= join(",", map { defined($_) ? $_ : '' } @succ_item);
        }
        Log3($name, 4, $msg);

        if ( $data ne "" ) {
            if ( $service eq "loadmap" ) {
                # use $data later
            } elsif ( $data =~ /^{/ || $data =~ /^\[/ ) {
                if ( !defined($cmd) || $cmd eq "" ) {
                    Log3($name, 4, "BOTVAC $name: RES $service - $data");
                } else {
                    Log3($name, 4, "BOTVAC $name: RES $service/$cmd - $data");
                }
                $return = decode_json( encode_utf8($data) );
            } else {
                Log3($name, 5, "BOTVAC $name: RES ERROR $service\n" . $data);
                if ( !defined($cmd) || $cmd eq "" ) {
                    Log3($name, 5, "BOTVAC $name: RES ERROR $service\n$data");
                } else {
                    Log3($name, 5, "BOTVAC $name: RES ERROR $service/$cmd\n$data");
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
              readingsBulkUpdateIfChanged($hash, "scheduleType",    $scheduleData->{type});
              readingsBulkUpdateIfChanged($hash, "scheduleEnabled", $scheduleData->{enabled});
              if (ref($scheduleData->{events}) eq "ARRAY") {
                my @events = @{$scheduleData->{events}};
                for (my $i = 0; $i < @events; $i++) {
                  readingsBulkUpdateIfChanged($hash, "event".$i."mode",      GetModeText($events[$i]->{mode}))
                      if (defined($events[$i]->{mode}));
                  readingsBulkUpdateIfChanged($hash, "event".$i."day",       GetDayText($events[$i]->{day}));
                  readingsBulkUpdateIfChanged($hash, "event".$i."startTime", $events[$i]->{startTime});
                }
              }
            }
          } 
          elsif ( $cmd eq "getMapBoundaries" ) {
              if ( ref($return->{data}) eq "HASH" ) {
                $reqId = $return->{reqId};
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
                  readingsBulkUpdateIfChanged($hash, "floorplan_".$reqId."_boundaries", $boundariesList);
                }
              }
          } 
          else {
            # getRobotState, startCleaning, pauseCleaning, stopCleaning, resumeCleaning,
            # sendToBase, setMapBoundaries, getRobotManualCleaningInfo
            if ( ref($return) eq "HASH" ) {
              push(@successor , ["robots", "maps"])
                  if ($cmd eq "setMapBoundaries" or 
                      (defined($return->{state}) and
                       ($return->{state} == 1 or $return->{state} == 4) and   # Idle or Error
                       $return->{state} != ReadingsNum($name, "stateId", $return->{state})));
              
              #readingsBulkUpdateIfChanged($hash, "version", $return->{version});
              #readingsBulkUpdateIfChanged($hash, "data", $return->{data});
              readingsBulkUpdateIfChanged($hash, "result", $return->{result});

              if ($cmd eq "getRobotManualCleaningInfo") {
                if ( ref($return->{data}) eq "HASH") {
                  my $data = $return->{data};
                  readingsBulkUpdateIfChanged($hash, "wlanIpAddress", $data->{ip_address});
                  readingsBulkUpdateIfChanged($hash, "wlanPort",      $data->{port});
                  readingsBulkUpdateIfChanged($hash, "wlanSsid",      $data->{ssid});
                  readingsBulkUpdateIfChanged($hash, "wlanToken",     $data->{token});
                  readingsBulkUpdateIfChanged($hash, "wlanValidity",  GetValidityEnd($data->{valid_for_seconds}));
                } else {
                  readingsBulkUpdateIfChanged($hash, "wlanValidity",  "unavailable");
                }
              }
              if ( ref($return->{cleaning}) eq "HASH" ) {
                my $cleaning = $return->{cleaning};
                readingsBulkUpdateIfChanged($hash, "cleaningCategory",       GetCategoryText($cleaning->{category}));
                readingsBulkUpdateIfChanged($hash, "cleaningMode",           GetModeText($cleaning->{mode}));
                readingsBulkUpdateIfChanged($hash, "cleaningModifier",       GetModifierText($cleaning->{modifier}));
                readingsBulkUpdateIfChanged($hash, "cleaningNavigationMode", GetNavigationModeText($cleaning->{navigationMode}));
                readingsBulkUpdateIfChanged($hash, "cleaningSpotWidth",      $cleaning->{spotWidth});
                readingsBulkUpdateIfChanged($hash, "cleaningSpotHeight",     $cleaning->{spotHeight});
              }
              if ( ref($return->{details}) eq "HASH" ) {
                my $details = $return->{details};
                readingsBulkUpdateIfChanged($hash, "isCharging",        $details->{isCharging});
                readingsBulkUpdateIfChanged($hash, "isDocked",          $details->{isDocked});
                readingsBulkUpdateIfChanged($hash, "isScheduleEnabled", $details->{isScheduleEnabled});
                readingsBulkUpdateIfChanged($hash, "dockHasBeenSeen",   $details->{dockHasBeenSeen});
                readingsBulkUpdateIfChanged($hash, "batteryPercent",    $details->{charge});
              }
              if ( ref($return->{availableCommands}) eq "HASH" ) {
                my $availableCommands = $return->{availableCommands};
                readingsBulkUpdateIfChanged($hash, ".start",    $availableCommands->{start});
                readingsBulkUpdateIfChanged($hash, ".stop",     $availableCommands->{stop});
                readingsBulkUpdateIfChanged($hash, ".pause",    $availableCommands->{pause});
                readingsBulkUpdateIfChanged($hash, ".resume",   $availableCommands->{resume});
                readingsBulkUpdateIfChanged($hash, ".goToBase", $availableCommands->{goToBase});
              }
              if ( ref($return->{availableServices}) eq "HASH" ) {
                SetServices($hash, $return->{availableServices});
              }
              if ( ref($return->{meta}) eq "HASH" ) {
                my $meta = $return->{meta};
                readingsBulkUpdateIfChanged($hash, "model",    $meta->{modelName});
                readingsBulkUpdateIfChanged($hash, "firmware", $meta->{firmware});
              }
              if (defined($return->{state})){ #State Response
                my $error = ($return->{error}) ? $return->{error} : "";
                readingsBulkUpdateIfChanged($hash, "error", $error);
                my $alert = ($return->{alert}) ? $return->{alert} : "";
                readingsBulkUpdateIfChanged($hash, "alert", $alert);
                readingsBulkUpdateIfChanged($hash, "stateId", $return->{state});
                readingsBulkUpdateIfChanged($hash, "action", $return->{action});
                readingsBulkUpdateIfChanged(
                  $hash,
                  "state",
                  BuildState($hash, $return->{state}, $return->{action}, $return->{error}));
              }
            }
          }
        }
    
        # Sessions
        elsif ( $service eq "sessions" ) {
          if ( ref($return) eq "HASH" and defined($return->{access_token})) {
            readingsBulkUpdateIfChanged($hash, "accessToken", $return->{access_token});
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
                  "model"     => $robots[$i]->{model},
                  "serial"    => $robots[$i]->{serial},
                  "secretKey" => $robots[$i]->{secret_key},
                  "macAddr"   => $robots[$i]->{mac_address},
                  "nucleoUrl" => $robots[$i]->{nucleo_url}
                };
                $r->{recentFirmware} = $return->{recent_firmwares}{$r->{model}}{version}
                  if ( ref($return->{recent_firmwares} ) eq "HASH" );

                push(@robotList, $r);
              }
              $hash->{helper}{ROBOTS} = \@robotList;

              SetRobot($hash, ReadingsNum($name, "robot", 0));
              
              push(@successor , ["robots", "maps"]);
            }
          }
        }

        # robots
        elsif ( $service eq "robots" ) {
          if ( $cmd eq "maps" ) {
            if ( ref($return) eq "HASH" ) {
              if ( ref($return->{maps} ) eq "ARRAY" ) {
                my @mapList = ();
                my @maps = @{$return->{maps}};
                # take first - newest
                my $map = $maps[0];
                readingsBulkUpdateIfChanged($hash, "map_status", $map->{status});
                readingsBulkUpdateIfChanged($hash, "map_id",     $map->{id});
                readingsBulkUpdateIfChanged($hash, "map_date",   GetTimeFromString($map->{generated_at}));
                readingsBulkUpdateIfChanged($hash, "map_area",   $map->{cleaned_area});
                readingsBulkUpdateIfChanged($hash, ".map_url",   $map->{url});
                $loadMap = 1;
                # getPersistentMaps
                push(@successor , ["robots", "persistent_maps"]);
              }
            }
          }
          elsif ( $cmd eq "persistent_maps" ) {
            if ( ref($return) eq "ARRAY" ) {
              my @persistent_maps = @{$return};
              for (my $i = 0; $i < @persistent_maps; $i++) {
                readingsBulkUpdateIfChanged($hash, "floorplan_".$i."_name", $persistent_maps[$i]->{name});
                readingsBulkUpdateIfChanged($hash, "floorplan_".$i."_id", $persistent_maps[$i]->{id});
                # getMapBoundaries
                if (GetServiceVersion($hash, "maps") eq "advanced-1" or GetServiceVersion($hash, "maps") eq "macro-1"){
                  my %params;
                  $params{"reqId"} = $i;
                  $params{"mapId"} = "\"".$persistent_maps[$i]->{id}."\"";
                  push(@successor , ["messages", "getMapBoundaries", \%params]);
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
            Log3($name, 2, "BOTVAC $name: ERROR: method to handle response of $service not implemented");
        }

    }

    readingsEndUpdate( $hash, 1 );
    
    if ($loadMap) {
      my $url = ReadingsVal($name, ".map_url", "");
      push(@successor , ["loadmap", $url]) if ($url ne "");
    }
    
    if (@successor) {
      my @nextCmd = @{shift(@successor)};
      my $cmdLength = @nextCmd;
      my $cmdService = $nextCmd[0];
      my $cmdCmd;
      my $cmdOption;
      $cmdCmd    = $nextCmd[1] if ($cmdLength > 1);
      $cmdOption = $nextCmd[2] if ($cmdLength > 2);

      my $cmdReqId;
      my $newReqId = "false";
      if (defined($cmdOption) and ref($cmdOption) eq "HASH" ) {
        if (defined($cmdOption->{reqId})) {
          $cmdReqId = $cmdOption->{reqId};
          $newReqId = "true" if ($reqId ne $cmdReqId);
        }
      }

      SendCommand($hash, $cmdService, $cmdCmd, $cmdOption, @successor)
          if (($service ne $cmdService) or ($cmd ne $cmdCmd) or ($newReqId = "true"));
    }

    return;
}

sub GetTimeFromString($) {
  my ($timeStr) = @_;
  
  eval {
    use Time::Local;
    if(defined($timeStr) and $timeStr =~ m/^(\d{4})-(\d{2})-(\d{2})T([0-2]\d):([0-5]\d):([0-5]\d)Z$/) {
        my $time = timelocal($6, $5, $4, $3, $2 - 1, $1 - 1900);
        return FmtDateTime($time + fhemTzOffset($time));
    }
  }
}

sub SetRobot($$) {
    my ( $hash, $robot ) = @_;
    my $name = $hash->{NAME};

    Log3($name, 4, "BOTVAC $name: set active robot $robot");

    my @robots = @{$hash->{helper}{ROBOTS}};
    readingsBulkUpdateIfChanged($hash, "serial",    $robots[$robot]->{serial});
    readingsBulkUpdateIfChanged($hash, "name",      $robots[$robot]->{name});
    readingsBulkUpdateIfChanged($hash, "model",     $robots[$robot]->{model});
    readingsBulkUpdateIfChanged($hash, "recentFirmware", $robots[$robot]->{recentFirmware});
    readingsBulkUpdateIfChanged($hash, "secretKey", $robots[$robot]->{secretKey});
    readingsBulkUpdateIfChanged($hash, "macAddr",   $robots[$robot]->{macAddr});
    readingsBulkUpdateIfChanged($hash, "nucleoUrl", $robots[$robot]->{nucleoUrl});
    readingsBulkUpdateIfChanged($hash, "robot",     $robot);
}

sub GetCleaningParameter($$$) {
  my ($hash, $param, $default) = @_;
  my $name = $hash->{NAME};

  my $nextReading = "next".ucfirst($param);
  return ReadingsVal($name, $nextReading, ReadingsVal($name, $param, $default));
}

sub GetServiceVersion($$) {
  my ($hash, $service) = @_;
  my $name = $hash->{NAME};

  my $serviceList = InternalVal($name, "SERVICES", "");
  if ($serviceList =~ /$service:([^,]*)/) {
    return $1;
  }
  return "";
}

sub SetServices {
  my ($hash, $services) = @_;
  my $name = $hash->{NAME};
  my $serviceList = join(", ", map { "$_:$services->{$_}" } keys %$services);;

  $hash->{SERVICES} = $serviceList if (!defined($hash->{SERVICES}) or $hash->{SERVICES} ne $serviceList);
}

sub StorePassword($$) {
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

sub ReadPassword($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
    my $key = getUniqueId().$index;
    my ($password, $err);
    
    Log3($name, 4, "BOTVAC $name: Read password from file");
    
    ($err, $password) = getKeyValue($index);

    if ( defined($err) ) {
      Log3($name, 3, "BOTVAC $name: unable to read password from file: $err");
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
      Log3($name, 3, "BOTVAC $name: No password in file");
      return undef;
    }
}

sub CheckRegistration($$$$$) {
  my ( $hash, $service, $cmd, $option, @successor ) = @_;
  my $name = $hash->{NAME};

  if (ReadingsVal($name, "secretKey", "") eq "") {
    my @nextCmd = ($service, $cmd, $option);
    unshift(@successor, [$service, $cmd, $option]);
      
      my @succ_item;
      my $msg = " successor:";
      for (my $i = 0; $i < @successor; $i++) {
        @succ_item = @{$successor[$i]};
        $msg .= " $i: ";
        $msg .= join(",", map { defined($_) ? $_ : '' } @succ_item);
      }
      Log3($name, 4, "BOTVAC created".$msg);
      
    SendCommand($hash, "sessions", undef, undef, @successor)   if (ReadingsVal($name, "accessToken", "") eq "");
    SendCommand($hash, "dashboard", undef, undef, @successor)  if (ReadingsVal($name, "accessToken", "") ne "");
    
    return 1;
  }
  
  return;
}

sub BuildState($$$$) {
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
        return GetActionText($action);
    } elsif ($state == 3) {
        return "Paused: ".GetActionText($action);
    } elsif ($state == 4) {
      return GetErrorText($error);
    } elsif (defined( $states->{$state})) {
        return $states->{$state};
    } else {
        return $state;
    }
}

sub GetActionText($) {
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

sub GetErrorText($) {
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

sub GetDayText($) {
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

sub GetCategoryText($) {
    my ($category) = @_;
    my $categories = {
        '1' => 'manual',
        '2' => 'house',
        '3' => 'spot',
        '4' => 'map'
    };

    if (defined($category) && defined($categories->{$category})) {
        return $categories->{$category};
    } else {
        return $category;
    }
}

sub GetModeText($) {
    my ($mode) = @_;
    my $modes = {
        '1' => 'eco',
        '2' => 'turbo'
    };

    if (defined($mode) && defined($modes->{$mode})) {
        return $modes->{$mode};
    } else {
        return $mode;
    }
}

sub GetModifierText($) {
    my ($modifier) = @_;
    my $modifiers = {
        '1' => 'normal',
        '2' => 'double'
    };

    if (defined($modifier) && defined($modifiers->{$modifier})) {
        return $modifiers->{$modifier};
    } else {
        return $modifier;
    }
}

sub GetNavigationModeText($) {
    my ($navMode) = @_;
    my $navModes = {
        '1' => 'normal',
        '2' => 'extra care',
        '3' => 'deep'
    };

    if (defined($navMode) && defined($navModes->{$navMode})) {
        return $navModes->{$navMode};
    } else {
        return $navMode;
    }
}

sub GetBeehiveHost($) {
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

sub GetNucleoHost($) {
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

sub GetValidityEnd($) {
    my ($validFor) = @_;
    return ($validFor =~ /\d+/ ? FmtDateTime(time() + $validFor) : $validFor);
}

sub ShowMap($;$$) {
    my ($name,$width,$height) = @_;

    my $img = '<img src="/fhem/BOTVAC/'.$name.'/map"';
    $img   .= ' width="'.$width.'"'  if (defined($width));
    $img   .= ' width="'.$height.'"' if (defined($height));
    $img   .= ' alt="Map currently not available">';
    
    return $img;
}

sub GetMap() {
    my ($request) = @_;
    
    if ($request =~ /^\/BOTVAC\/(\w+)\/map/) {
      my $name   = $1;
      my $width  = $3;
      my $height = $5;
      
      return ("image/png", ReadingsVal($name, ".map_cache", ""));
    }

    return ("text/plain; charset=utf-8", "No BOTVAC device for webhook $request");
    
}

#sub GetCAKey($) {
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
=item device
=item summary     Robot Vacuums
=item summary_DE  Staubsauger Roboter

=begin html

<a name="BOTVAC"></a>
<h3>BOTVAC</h3>
<div>
<ul>
  This module controls Neato Botvac Connected and Vorwerk Robot Vacuums.<br/>
  For issuing commands or retrieving Readings it's necessary to fetch the information from the NEATO/VORWERK Server.
  In this way, it can happen, that it's not possible to send commands to the Robot until the corresponding Values are fetched.
  This means, it can need some time until your Robot will react on your command.
  <br/><br/>

<a name="BOTVACDefine"></a>
<b>Define</b>
<ul>
  <br>
  <code>define &lt;name&gt; BOTVAC &lt;email&gt; [NEATO|VORWERK] [&lt;polling-interval&gt;]</code>
  <br/><br/>
  Example:&nbsp;<code>define myNeato BOTVAC myemail@myprovider.com NEATO 300</code>
  <br/><br/>

  After defining the Device, it's necessary to enter the password with "set &lt;name&gt; password &lt;password&gt;"<br/>
  It is exactly the same Password as you use on the Website or inside the App.
  <br/><br/>
  Example:&nbsp;<code>set NEATO passwort mySecretPassword</code>
  <br/><br/>
</ul>

<a name="BOTVACget"></a>
<b>Get</b>
<ul>
<br>
  <li><code>get &lt;name&gt; batteryPercent</code>
  <br>
  requests the state of the battery from Robot
  </li><br>
</ul>

<a name="BOTVACset"></a>
<b>Set</b>
<ul>
<br>
  <li>
  <code> set &lt;name&gt; findMe</code>
  <br>
  plays a sound and let the LED light for easier finding of a stuck robot
  </li>
<br>
  <li>
  <code> set &lt;name&gt; dismissCurrentAlert</code>
  <br>
        reset an actual Warning (e.g. dustbin full)
  </li>
<br>
  <li>
  <code> set &lt;name&gt; manualCleaningMode</code>
  <br>
  MISSING
  </li>
<br>
  <li>
  <code> set &lt;name&gt; nextCleaningMode</code>
  <br>
  MISSING
  </li>
<br>
  <li>
  <code> set &lt;name&gt; nextCleaningNavigationMode</code>
  <br>
  MISSING
  </li>
<br>
  <li>
  <code> set &lt;name&gt; nextCleaningSpotHeight</code>
  <br>
  MISSING
  </li>
<br>
  <li>
  <code> set &lt;name&gt; nextCleaningSpotWidth</code>
  <br>
  MISSING
  </li>
<br>
  <li>
  <code> set &lt;name&gt; password &lt;password&gt;</code>
  <br>
        set the password for the NEATO/VORWERK account
  </li>
<br>
  <li>
  <code> set &lt;name&gt; pause</code>
  <br>
        interrupts the cleaning
  </li>
<br>
  <li>
  <code> set &lt;name&gt; pauseToBase</code>
  <br>
  stops cleaning and returns to base
  </li>
<br>
  <li>
  <code> set &lt;name&gt; reloadMaps</code>
  <br>
        load last map from server into the cache of the module. no file is stored!
  </li>
<br>
  <li>
  <code> set &lt;name&gt; resume</code>
  <br>
  resume cleaning after pause
  </li>
<br>
  <li>
  <code> set &lt;name&gt; schedule</code>
  <br>
        on and off, switch time control
  </li>
<br>
  <li>
  <code> set &lt;name&gt; sendToBase</code>
  <br>
  send roboter back to base
  </li>
<br>
  <li>
  <code> set &lt;name&gt; setBoundaries</code>
  <br>
  set boundaries/nogo lines
  </li>
<br>
  <li>
  <code> set &lt;name&gt; setBoundariesOnFloorplan_&lt;floor plan&gt; &lt;name|{JSON String}&gt;</code>
  <br>
    Set boundaries/nogo lines in the corresponding floor plan.<br>
    The paramter can either be a name, which is already defined by attribute "boundaries", or alternatively a JSON string.
    (A comma-separated list of names is also possible.)<br>
    Description of syntax at <a href>https://developers.neatorobotics.com/api/robot-remote-protocol/maps</a><br>
    <br>
    Examples:<br>
    set &lt;name&gt; setBoundariesOnFloorplan_0 Bad<br>
    set &lt;name&gt; setBoundariesOnFloorplan_0 Bad,Kueche<br>
    set &lt;name&gt; setBoundariesOnFloorplan_0 {"type":"polyline","vertices":[[0.710,0.6217],[0.710,0.6923]],
      "name":"Bad","color":"#E54B1C","enabled":true}
  </li>
<br>
  <code> set &lt;name&gt; setRobot</code>
  <br>
  choose robot if more than one is registered at the used account
  </li>
<br>
  <li>
  <code> set &lt;name&gt; startCleaning</code>
  <br>
  start the Cleaning from the scratch. Depending on Model, there are additional Arguments available: eco/turbo ; normal/extraCare
  </li>
<br>
  <li>
  <code> set &lt;name&gt; startSpot</code>
  <br>
  start spot-Cleaning from actual position. Depending on Model, there are additional Arguments available: eco/turbo ; normal/extraCare
  </li>
<br>
  <li>
  <code> set &lt;name&gt; statusRequest</code>
  <br>
  pull update of all readings. necessary because NEATO/VORWERK does not send updates at their own.
  </li>
<br>
  <li>
  <code> set &lt;name&gt; stop cleaning</code>
  <br>
  stop cleaning
  </li>
<br>
  <li>
  <code> set &lt;name&gt; syncRobots</code>
  <br>
  sync robot data with online account. Useful if one has more then one robot registered
  </li>
<br>
  <li>
  <code> set &lt;name&gt; stopCleaning</code>
  <br>
  stopCleaning and stay where you are
  </li>
<br>
</ul>
<a name="BOTVACattr"></a>
<b>Attributes</b>
<ul>
<br>


  <li>
  <code> myFirstAttr</code>
  <br>
  Explanation
  </li>
<br>
  <li>
  <code>actionInterval</code>
  <br>
  time in seconds between status requests while Device is working
  </li>
<br>
  <li>
  <code>boundaries</code>
  <br>
  Boundary entries separated by space in JSON format, e.g.<br>
  {"type":"polyline","vertices":[[0.710,0.6217],[0.710,0.6923]],"name":"Bad","color":"#E54B1C","enabled":true}<br>
  {"type":"polyline","vertices":[[0.7139,0.4101],[0.7135,0.4282],[0.4326,0.3322],[0.4326,0.2533],[0.3931,0.2533],
    [0.3931,0.3426],[0.7452,0.4637],[0.7617,0.4196]],"name":"Kueche","color":"#000000","enabled":true}<br>
  For description of syntax see: <a href>https://developers.neatorobotics.com/api/robot-remote-protocol/maps</a><br>
  The value of paramter "name" is used as setListe for "setBoundariesOnFloorplan_&lt;floor plan&gt;".
  It is also possible to save more than one boundary with the same name.
  The command "setBoundariesOnFloorplan_&lt;floor plan&gt; &lt;name&gt;" sends all boundary with the same name.
  </li>
<br>
</ul>

</ul>

=end html

=begin html_DE
<a name="BOTVAC"></a>

<h3>BOTVAC</h3>

<ul>

  Dieses Module steuert Neato Botvac Connected und Vorwerk Staubsaugerroboter

  <br><br>

  <b>Define</b>

</ul>



=end html_DE

=cut