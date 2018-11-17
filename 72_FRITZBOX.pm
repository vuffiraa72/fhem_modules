=pod
=item device
=item summary Controls some features of AVM's Fritz!Box, FRITZ!Repeater and Fritz!Fon.
=item summary_DE Steuert einige Funktionen von AVM's Fritz!Box, Fritz!Repeater und Fritz!Fon.

=begin html

<a name="FRITZBOX"></a>
<h3>FRITZBOX</h3>
<div> 
<ul>
   Controls some features of a Fritz!Box router or Fritz!Repeater. Connected Fritz!Fon's (MT-F, MT-D, C3, C4, C5) can be used as
   signaling devices. MP3 files and Text2Speech can be played as ring tone or when calling phones.
   <br>
   For detail instructions, look at and please maintain the <a href="http://www.fhemwiki.de/wiki/FRITZBOX"><b>FHEM-Wiki</b></a>.
   <br/><br/>
   The modul switches in local mode if FHEM runs on a Fritz!Box (as root user!). Otherwise, it tries to open a web or telnet connection to "fritz.box", so telnet (#96*7*) has to be enabled on the Fritz!Box. For remote access the password must <u>once</u> be set.
   <br/><br/>
   The box is partly controlled via the official TR-064 interface but also via undocumented interfaces between web interface and firmware kernel. The modul works best with Fritz!OS 6.24. AVM has removed internal interfaces (telnet, webcm) from later Fritz!OS versions without replacement. <b>For these versions, some modul functions are hence restricted or do not work at all (see remarks to required API).</b>
   <br>
   The modul was tested on Fritz!Box 7390 and 7490 with Fritz!OS 6.20 and higher.
   <br>
   Check also the other Fritz!Box moduls: <a href="#SYSMON">SYSMON</a> and <a href="#FB_CALLMONITOR">FB_CALLMONITOR</a>.
   <br>
   <i>The modul uses the Perl modul 'Net::Telnet', 'JSON::XS', 'LWP', 'SOAP::Lite' for remote access.</i>
   <br/><br/>
   <a name="FRITZBOXdefine"></a>
   <b>Define</b>
   <ul>
      <br>
      <code>define &lt;name&gt; FRITZBOX  [host]</code>
      <br/>
         The attribute <i>host</i> is the web address (name or IP) of the Fritz!Box. If it is missing, the modul switches in local mode or uses the default host address "fritz.box".
      <br/><br/>
      Example: <code>define Fritzbox FRITZBOX</code>
      <br/><br/>
      The FritzOS has a hidden function (easter egg).
      <br>
      <code>define MyEasterEgg weblink htmlCode { FRITZBOX_fritztris("Fritzbox") }</code>
      <br/><br/>
   </ul>
  
   <a name="FRITZBOXset"></a>
   <b>Set</b>
   <ul>
      <br>
      <li><code>set &lt;name&gt; alarm &lt;number&gt; [on|off] [time] [once|daily|Mo|Tu|We|Th|Fr|Sa|So]</code>
         <br>
         Switches the alarm number (1, 2 or 3) on or off (default is on). Sets the time and weekday. If no state is given it is switched on.
         <br>
         Requires the API: Telnet or webcm.
      </li><br>

      <li><code>set &lt;name&gt; call &lt;number&gt; [duration] [say:text|play:MP3URL]</code>
         <br>
         Calls for 'duration' seconds (default 60) the given number from an internal port (default 1 or attribute 'ringWithIntern'). If the call is taken a text or sound can be played as music on hold (moh). The internal port will also ring.
         Say and play requires the API: Telnet or webcm.
      </li><br>

      <li><code>set &lt;name&gt; checkAPIs</code>
         <br>
         Restarts the initial check of the programming interfaces of the FRITZ!BOX.
      </li><br>

      <li><code>set &lt;name&gt; customerRingTone &lt;internalNumber&gt; &lt;fullFilePath&gt;</code>
         <br>
         Uploads the file fullFilePath on the given handset. Only mp3 or G722 format is allowed.
         <br>
         The file has to be placed on the file system of the fritzbox.
         <br>
         The upload takes about one minute before the tone is available.
      </li><br>

      <li><code>set &lt;name&gt; dect &lt;on|off&gt;</code>
         <br>
         Switches the DECT base of the box on or off. Requires the API: Telnet or webcm.
      </li><br>

      <li><code>set &lt;name&gt; diversity &lt;number&gt; &lt;on|off&gt;</code>
         <br>
         Switches the call diversity number (1, 2 ...) on or off.
         A call diversity for an incoming number has to be created with the Fritz!Box web interface. Requires the API: Telnet, webcm or TR064 (>=6.50).
         <br>
         Note! Only a diversity for a concret home number and <u>without</u> filter for the calling number can be set. Hence, an approbriate <i>diversity</i>-reading must exist.
      </li><br>

      <li><code>set &lt;name&gt; guestWLAN &lt;on|off&gt;</code>
         <br>
         Switches the guest WLAN on or off. The guest password must be set. If necessary, the normal WLAN is also switched on.
      </li><br>

      <li><code>set &lt;name&gt; moh &lt;default|sound|customer&gt; [&lt;MP3FileIncludingPath|say:Text&gt;]</code>
         <br>
         Example: <code>set fritzbox moh customer say:Die Wanne ist voll</code>
         <br>
         <code>set fritzbox moh customer /var/InternerSpeicher/warnung.mp3</code>
         <br>
         Changes the 'music on hold' of the Box. The parameter 'customer' allows to upload a mp3 file. Alternatively a text can be spoken with "say:". The music on hold has <u>always</u> a length of 8.2 s. It is played continuously during the broking of calls or if the module rings a phone and the call is taken. So, it can be used to transmit little messages of 8 s.
         <br>
      </li><br>

      <li><code>set &lt;name&gt; password &lt;password&gt;</code>
         <br>
         Stores the password for remote telnet access.
      </li><br>

      <li><code>set &lt;name&gt; ring &lt;intNumbers&gt; [duration [ringTone]] [show:Text]  [say:Text | play:MP3URL]</code>
         <dt>Example:</dt>
         <dd>
         <code>set fritzbox ring 611,612 5 Budapest show:It is raining</code>
         <br>
         <code>set fritzbox ring 611 8 say:(en)It is raining</code>
         <br>
         <code>set fritzbox ring 610 10 play:http://raspberrypi/sound.mp3</code>
         </dd>
         Rings the internal numbers for "duration" seconds and (on Fritz!Fons) with the given "ring tone" name.
         Different internal numbers have to be separated by a comma (without spaces).
         <br>
         Default duration is 5 seconds. The Fritz!Box can create further delays. Default ring tone is the internal ring tone of the device.
         Ring tone will be ignored for collected calls (9 or 50). 
         <br>
         If the call is taken the callee hears the "music on hold" which can also be used to transmit messages.
         <br>
         The parameter <i>ringtone, show:, say:</i> and <i>play:</i> require the API Telnet or webcm.
         <br/><br/>
         If the <a href=#FRITZBOXattr>attribute</a> 'ringWithIntern' is specified, the text behind 'show:' will be shown as the callers name.
         Maximal 30 characters are allowed.
         <br/><br/>
         On Fritz!Fons the parameter 'say:' can be used to let the phone speak a message (max. 100 characters) instead of using the ringtone. 
         Alternatively, a MP3 link (from a web server) can be played with 'play:'. This creates the web radio station 'FHEM' and uses translate.google.com for text2speech. It will <u>always</u> play the complete text/sound. It will than ring with standard ring tone until the end of the 'ring duration' is reached.
         Say and play <u>may</u> work only with one single Fritz!Fon at a time.
         <br>
         The behaviour may vary depending on the Fritz!OS.
      </li><br>

      <li><code>set &lt;name&gt; sendMail [to:&lt;Address&gt;] [subject:&lt;Subject&gt;] [body:&lt;Text&gt;]</code>
         <br>
         Sends an email via the email notification service that is configured in push service of the Fritz!Box. 
         Use "\n" for line breaks in the body.
         All parameters can be omitted. Make sure the messages are not classified as junk by your email client.
         <br>
         Requires Telnet access to the box.
         <br>
      </li><br>

      <li><code>set &lt;name&gt; startRadio &lt;internalNumber&gt; [name or number]</code>
         <br>
         Plays the internet radio on the given Fritz!Fon. Default is the current <u>ring tone</u> radio station of the phone. 
         So, <b>not</b> the station that is selected at the handset.
         An available internet radio can be selected by its name or (reading) number.
         <br>
      </li><br>

      <li><code>set &lt;name&gt; tam &lt;number&gt; &lt;on|off&gt;</code>
         <br>
         Switches the answering machine number (1, 2 ...) on or off.
         The answering machine has to be created on the Fritz!Box web interface.
      </li><br>

      <li><code>set &lt;name&gt; update</code>
         <br>
         Starts an update of the device readings.
      </li><br>

      <li><code>set &lt;name&gt; wlan &lt;on|off&gt;</code>
         <br>
         Switches WLAN on or off.
      </li><br>
   </ul>  

   <a name="FRITZBOXget"></a>
   <b>Get</b>
   <ul>
      <br>

      <li><code>get &lt;name&gt; ringTones</code>
         <br>
         Shows the list of ring tones that can be used.
      </li><br>

      <li><code>get &lt;name&gt; shellCommand &lt;Command&gt;</code>
         <br>
         Runs the given command on the Fritz!Box shell and returns the result.
         Can be used to run shell commands not included in this modul.
         <br>
         Only available if the attribute "allowShellCommand" is set.
      </li><br>

      <li><code>get &lt;name&gt; tr064Command &lt;service&gt; &lt;control&gt; &lt;action&gt; [[argName1 argValue1] ...] </code>
         <br>
         Executes TR-064 actions (see <a href="http://avm.de/service/schnittstellen/">API description</a> of AVM).
         <br>
         argValues with spaces have to be enclosed in quotation marks.
         <br>
         Example: <code>get Fritzbox tr064Command X_AVM-DE_OnTel:1 x_contact GetDECTHandsetInfo NewDectID 1</code>
         <br>
         Only available if the attribute "allowTR064Command" is set.
      </li><br>

      <li><code>get &lt;name&gt; tr064ServiceListe</code>
         <br>
         Shows a list of TR-064 services and actions that are allowed on the device.
      </li><br>

   </ul>  
  
   <a name="FRITZBOXattr"></a>
   <b>Attributes</b>
   <ul>
      <br>
      <li><code>allowShellCommand &lt;0 | 1&gt;</code>
         <br>
         Enables the get command "shellCommand"
      </li><br>

      <li><code>allowTR064Command &lt;0 | 1&gt;</code>
         <br>
         Enables the get command "tr064Command"
      </li><br>

      <li><code>boxUser &lt;user name&gt;</code>
         <br>
         User name that is used for TR064 or other web based access. By default no user name is required to login.
         <br>
         If the Fritz!Box is configured differently, the user name has to be defined with this attribute.
      </li><br>

      <li><code>defaultCallerName &lt;Text&gt;</code>
         <br>
         The default text to show on the ringing phone as 'caller'.
         <br>
         This is done by temporarily changing the name of the calling internal number during the ring.
         <br>
         Maximal 30 characters are allowed. The attribute "ringWithIntern" must also be specified.
         <br>
         Required API: Telnet or webcmd
      </li><br>

      <li><code>defaultUploadDir &lt;fritzBoxPath&gt;</code>
         <br>
         This is the default path that will be used if a file name does not start with / (slash).
         <br>
         It needs to be the name of the path on the Fritz!Box. So, it should start with /var/InternerSpeicher if it equals in Windows \\ip-address\fritz.nas
      </li><br>

      <li><code>forceTelnetConnection &lt;0 | 1&gt;</code>
         <br>
         Always use telnet for remote access (instead of access via the WebGUI or TR-064).
         <br>
         This attribute should be enabled for older boxes/firmwares.
      </li><br>

      <li><code>fritzBoxIP &lt;IP Address&gt;</code>
         <br>
         Depreciated.
      </li><br>

     <li><code>INTERVAL &lt;seconds&gt;</code>
         <br>
         Polling-Interval. Default is 300 (seconds). Smallest possible value is 60.
      </li><br>

      <li><code>m3uFileLocal &lt;/path/fileName&gt;</code>
         <br>
         Can be used as a work around if the ring tone of a Fritz!Fon cannot be changed because of firmware restrictions (missing telnet or webcm).
         <br>
         How it works: If the FHEM server has also a web server running, the FritzFon can play a m3u file from this web server as an internet radio station.
         For this an internet radio station on the FritzFon must point to the server URL of this file and the internal ring tone must be changed to that station.
         <br>
         If the attribute is set, the server file "m3uFileLocal" (local address of the FritzFon URL) will be filled with the URL of the text2speech engine (say:) or a MP3-File (play:). The FritzFon will then play this URL.
      </li><br>

      <li><code>ringWithIntern &lt;1 | 2 | 3&gt;</code>
         <br>
         To ring a phone a caller must always be specified. Default of this module is 50 "ISDN:Wählhilfe".
         <br>
         To show a message (default: "FHEM") during a ring the internal phone numbers 1-3 can be specified here.
         The concerned analog phone socket <u>must</u> exist.
      </li><br>
      
      <li><code>telnetTimeOut &lt;seconds&gt;</code>
         <br>
         Maximal time to wait for an answer during a telnet session. Default is 10 s.
      </li><br>

      <li><code>telnetUser &lt;user name&gt;</code>
         <br>
         User name that is used for telnet access. By default no user name is required to login.
         <br>
         If the Fritz!Box is configured differently, the user name has to be defined with this attribute.
      </li><br>

      <li><code>useGuiHack &lt;0 | 1&gt;</code>
         <br>
         If the APIs do not allow the change of the ring tone (Fritz!OS >6.24), check the <a href="http://www.fhemwiki.de/wiki/FRITZBOX#Klingelton-Einstellung_und_Abspielen_von_Sprachnachrichten_bei_Fritz.21OS-Versionen_.3E6.24">WIKI</a> (German) to understand the use of this attribute.
      </li><br>

      <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
   </ul>
   <br>

   <a name="FRITZBOXreading"></a>
   <b>Readings</b>
   <ul><br>
      <li><b>alarm</b><i>1</i> - Name of the alarm clock <i>1</i></li>
      <li><b>alarm</b><i>1</i><b>_state</b> - Current state of the alarm clock <i>1</i></li>
      <li><b>alarm</b><i>1</i><b>_target</b> - Internal number of the alarm clock <i>1</i></li>
      <li><b>alarm</b><i>1</i><b>_time</b> - Alarm time of the alarm clock <i>1</i></li>
      <li><b>alarm</b><i>1</i><b>_wdays</b> - Weekdays of the alarm clock <i>1</i></li>
      <br>
      <li><b>box_dect</b> - Current state of the DECT base</li>
      <li><b>box_fwVersion</b> - Firmware version of the box, if outdated then '(old)' is appended</li>
      <li><b>box_guestWlan</b> - Current state of the guest WLAN</li>
      <li><b>box_guestWlanCount</b> - Number of devices connected to guest WLAN</li>
      <li><b>box_guestWlanRemain</b> - Remaining time until the guest WLAN is switched off</li>
      <li><b>box_ipExtern</b> - Internet IP of the Fritz!Box</li>
      <li><b>box_model</b> - Fritz!Box model</li>
      <li><b>box_moh</b> - music-on-hold setting</li>
      <li><b>box_model</b> - Fritz!Box model</li>
      <li><b>box_powerRate</b> - current power in percent of maximal power</li>
      <li><b>box_rateDown</b> - average download rate in the last update interval</li>
      <li><b>box_rateUp</b> - average upload rate in the last update interval</li>
      <li><b>box_stdDialPort</b> - standard caller port when using the dial function of the box</li>
      <li><b>box_tr064</b> - application interface TR-064 (needed by this modul)</li>
      <li><b>box_tr069</b> - provider remote access TR-069 (safety issue!)</li>
      <li><b>box_wlanCount</b> - Number of devices connected via WLAN</li>
      <li><b>box_wlan_2.4GHz</b> - Current state of the 2.4 GHz WLAN</li>
      <li><b>box_wlan_5GHz</b> - Current state of the 5 GHz WLAN</li>
      <br>
      <li><b>dect</b><i>1</i> - Name of the DECT device <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_alarmRingTone</b> - Alarm ring tone of the DECT device <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_custRingTone</b> - Customer ring tone of the DECT device <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_fwVersion</b> - Firmware Version of the DECT device <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_intern</b> - Internal number of the DECT device <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_intRingTone</b> - Internal ring tone of the DECT device <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_manufacturer</b> - Manufacturer of the DECT device <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_model</b> - Model of the DECT device <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_radio</b> - Current internet radio station ring tone of the DECT device <i>1</i></li>
      <br>
      <li><b>diversity</b><i>1</i> - Own (incoming) phone number of the call diversity <i>1</i></li>
      <li><b>diversity</b><i>1</i><b>_dest</b> - Destination of the call diversity <i>1</i></li>
      <li><b>diversity</b><i>1</i><b>_state</b> - Current state of the call diversity <i>1</i></li>
      <br>
      <li><b>fon</b><i>1</i> - Internal name of the analog FON port <i>1</i></li>
      <li><b>fon</b><i>1</i><b>_intern</b> - Internal number of the analog FON port <i>1</i></li>
      <li><b>fon</b><i>1</i><b>_out</b> - Outgoing number of the analog FON port <i>1</i></li>
      <br>
      <li><b>gsm_internet</b> - connection to internet established via GSM stick</li>
      <li><b>gsm_rssi</b> - received signal strength indication (0-100)</li>
      <li><b>gsm_state</b> - state of the connection to the GSM network</li>
      <li><b>gsm_technology</b> - GSM technology used for data transfer (GPRS, EDGE, UMTS, HSPA)</li>
      <br>
      <li><b>mac_</b><i>01_26_FD_12_01_DA</i> - MAC address and name of an active network device.
      <br>
      If connect via WLAN, the term "WLAN" and (from boxes point of view) the down- and upload rate and the signal strength is added. For LAN devices the LAN port and its speed is added. Inactive or removed devices get first the value "inactive" and will be deleted during the next update.</li>
      <br>
      <li><b>radio</b><i>01</i> - Name of the internet radio station <i>01</i></li>
      <br>
      <li><b>tam</b><i>1</i> - Name of the answering machine <i>1</i></li>
      <li><b>tam</b><i>1</i><b>_newMsg</b> - New messages on the answering machine <i>1</i></li>
      <li><b>tam</b><i>1</i><b>_oldMsg</b> - Old messages on the answering machine <i>1</i></li>
      <li><b>tam</b><i>1</i><b>_state</b> - Current state of the answering machine <i>1</i></li>
      <br>
      <li><b>user</b><i>01</i> - Name of user/IP <i>1</i> that is under parental control</li>
      <li><b>user</b><i>01</i>_thisMonthTime - this month internet usage of user/IP <i>1</i> (parental control)</li>
      <li><b>user</b><i>01</i>_todaySeconds - today's internet usage in seconds of user/IP <i>1</i> (parental control)</li>
      <li><b>user</b><i>01</i>_todayTime - today's internet usage of user/IP <i>1</i> (parental control)</li>
   </ul>
   <br>
</ul>
</div>

=end html

=begin html_DE

<a name="FRITZBOX"></a>
<h3>FRITZBOX</h3>
<div> 
<ul>
   Steuert gewisse Funktionen eines Fritz!Box Routers. Verbundene Fritz!Fon's (MT-F, MT-D, C3, C4) können als Signalgeräte genutzt werden. MP3-Dateien und Text (Text2Speech) können als Klingelton oder einem angerufenen Telefon abgespielt werden.
   <br>
   Für detailierte Anleitungen bitte die <a href="http://www.fhemwiki.de/wiki/FRITZBOX"><b>FHEM-Wiki</b></a> konsultieren und ergänzen.
   <br/><br/>
   Das Modul schaltet in den lokalen Modus, wenn FHEM auf einer Fritz!Box läuft (als root-Benutzer!). Ansonsten versucht es eine Web oder Telnet Verbindung zu "fritz.box" zu öffnen. D.h. Telnet (#96*7*) muss auf der Fritz!Box erlaubt sein. Für diesen Fernzugriff muss <u>einmalig</u> das Passwort gesetzt werden.
   <br/><br/>
   Die Steuerung erfolgt teilweise über die offizielle TR-064-Schnittstelle und teilweise über undokumentierte Schnittstellen zwischen Webinterface und Firmware Kern. Das Modul funktioniert am besten mit dem Fritz!OS 6.24. Bei den nachfolgenden Fritz!OS Versionen hat AVM einige interne Schnittstellen (telnet, webcm) ersatzlos gestrichen. <b>Einige Modul-Funktionen sind dadurch nicht oder nur eingeschränkt verfügbar (siehe Anmerkungen zu benötigten API).</b>
   <br>
   Bitte auch die anderen Fritz!Box-Module beachten: <a href="#SYSMON">SYSMON</a> und <a href="#FB_CALLMONITOR">FB_CALLMONITOR</a>.
   <br>
   <i>Das Modul nutzt das Perlmodule 'Net::Telnet', 'JSON::XS', 'LWP', 'SOAP::Lite' für den Fernzugriff.</i>
   <br/><br/>
   <a name="FRITZBOXdefine"></a>
   <b>Define</b>
   <ul>
      <br>
      <code>define &lt;name&gt; FRITZBOX [host]</code>
      <br/>
      Das Attribut <i>host</i> ist die Web-Adresse (Name oder IP) der Fritz!Box. Fehlt es, so schaltet das Modul in den lokalen Modus oder nutzt die Standardadresse "fritz.box".
      <br/><br/>
      Beispiel: <code>define Fritzbox FRITZBOX</code>
      <br/><br/>
      Das FritzOS hat eine versteckte Funktion (Osterei).
      <br>
      <code>define MyEasterEgg weblink htmlCode { FRITZBOX_fritztris("Fritzbox") }</code>
      <br/><br/>
   </ul>
  
   <a name="FRITZBOXset"></a>
   <b>Set</b>
   <ul>
      <br>
      <li><code>set &lt;name&gt; alarm &lt;Nummer&gt; [on|off] [time] [once|daily|Mo|Tu|We|Th|Fr|Sa|So]</code>
         <br>
         Schaltet den Weckruf Nummer 1, 2 oder 3 an oder aus (Standard ist on). Setzt die Zeit und den Wochentag.
         <br>
         Benötigt die API: Telnet oder webcm.
      </li><br>

      <li><code>set &lt;name&gt; call &lt;number&gt; [Dauer] [say:Text|play:MP3URL]</code>
         <br>
         Ruf für 'Dauer' Sekunden (Standard 60 s) die angegebene Telefonnummer von einem internen Telefonanschluss an (Standard ist 1 oder das Attribut 'ringWithIntern'). Wenn der Angerufene abnimmt, hört er die Wartemusik oder den angegebenen Text oder Klang.
         Der interne Telefonanschluss klingelt ebenfalls.
         <br>
         "say:" und "play:" benötigen die API: Telnet oder webcm.
      </li><br>

      <li><code>set &lt;name&gt; checkAPIs</code>
         <br>
         Startet eine erneute Abfrage der exitierenden Programmierschnittstellen der FRITZ!BOX.
      </li><br>

      <li><code>set &lt;name&gt; customerRingTone &lt;internalNumber&gt; &lt;MP3DateiInklusivePfad&gt;</code>
         <br>
         Lädt die MP3-Datei als Klingelton auf das angegebene Telefon. Die Datei muss im Dateisystem der Fritzbox liegen.
         <br>
         Das Hochladen dauert etwa eine Minute bis der Klingelton verfügbar ist. (API: Telnet)
      </li><br>

      <li><code>set &lt;name&gt; dect &lt;on|off&gt;</code>
         <br>
         Schaltet die DECT-Basis der Box an oder aus.
         <br>
         Benötigt die API: Telnet oder webcm.
      </li><br>

      <li><code>set &lt;name&gt; diversity &lt;number&gt; &lt;on|off&gt;</code>
         <br>
         Schaltet die Rufumleitung (Nummer 1, 2 ...) für einzelne Rufnummern an oder aus.
         <br>
         Die Rufumleitung muss zuvor auf der Fritz!Box eingerichtet werden. Benötigt die API: Telnet oder webcm.
         <br>
         Achtung! Es lassen sich nur Rufumleitungen für einzelne angerufene Telefonnummern (also nicht "alle") und <u>ohne</u> Abhängigkeit von der anrufenden Nummer schalten. 
         Es muss also ein <i>diversity</i>-Geräwert geben.
         <br>
         Benötigt die API: Telnet, webcm oder TR064 (>=6.50).
      </li><br>

      <li><code>set &lt;name&gt; guestWLAN &lt;on|off&gt;</code>
         <br>
         Schaltet das Gäste-WLAN an oder aus. Das Gäste-Passwort muss gesetzt sein. Wenn notwendig wird auch das normale WLAN angeschaltet.
      </li><br>

      <li><code>set &lt;name&gt; moh &lt;default|sound|customer&gt; [&lt;MP3DateiInklusivePfad|say:Text&gt;]</code>
         <br>
         Beispiel: <code>set fritzbox moh customer say:Die Wanne ist voll</code>
         <br>
         <code>set fritzbox moh customer /var/InternerSpeicher/warnung.mp3</code>
         <br>
         ändert die Wartemusik ('music on hold') der Box. Mit dem Parameter 'customer' kann eine eigene MP3-Datei aufgespielt werden.
         Alternativ kann mit "say:" auch ein Text gesprochen werden. Die Wartemusik hat <u>immer</u> eine Länge von 8,13 s. Sie wird kontinuierlich während des Makelns von Gesprächen aber auch bei Nutzung der internen Wählhilfe bis zum Abheben des rufenden Telefons abgespielt. Dadurch können über FHEM dem Angerufenen 8s-Nachrichten vorgespielt werden.
         <br>
      </li><br>
      
      <li><code>set &lt;name&gt; password &lt;Passwort&gt;</code>
         <br>
         Speichert das Passwort für den Fernzugriff über Telnet.
      </li><br>

      <li><code>set &lt;name&gt; ring &lt;intNummern&gt; [Dauer [Klingelton]] [show:Text] [say:Text | play:Link]</code>
         <dt>Beispiel:</dt>
         <dd>
         <code>set fritzbox ring 611,612 5 Budapest show:Es regnet</code>
         <br>
         <code>set fritzbox ring 610 8 say:Es regnet</code>
         <br>
         <code>set fritzbox ring 610 10 play:http://raspberrypi/sound.mp3</code>
         </dd>
         Lässt die internen Nummern für "Dauer" Sekunden und (auf Fritz!Fons) mit dem angegebenen "Klingelton" klingeln.
         <br>
         Mehrere interne Nummern müssen durch ein Komma (ohne Leerzeichen) getrennt werden.
         <br>
         Standard-Dauer ist 5 Sekunden. Es kann aber zu Verzögerungen in der Fritz!Box kommen. Standard-Klingelton ist der interne Klingelton des Gerätes.
         Der Klingelton wird für Rundrufe (9 oder 50) ignoriert. 
         <br>
         Wenn der Anruf angenommen wird, hört der Angerufene die Wartemusik (music on hold), welche ebenfalls zur Nachrichtenübermittlung genutzt werden kann.
         <br>
         Die Parameter <i>Klingelton, show:, say:</i> und <i>play:</i> benötigen die API Telnet oder webcm.
         <br/><br/>
         Wenn das <a href=#FRITZBOXattr>Attribut</a> 'ringWithIntern' existiert, wird der Text hinter 'show:' als Name des Anrufers angezeigt.
         Er darf maximal 30 Zeichen lang sein.
         <br/><br/>
         Auf Fritz!Fons wird der Text (max. 100 Zeichen) hinter dem Parameter 'say:' direkt angesagt und ersetzt den Klingelton.
         <br>
         Alternativ kann mit 'play:' auch ein MP3-Link (vom einem Webserver) abgespielt werden. Dabei wird die Internetradiostation 39 'FHEM' erzeugt und translate.google.com für Text2Speech genutzt. Es wird <u>immer</u> der komplette Text/Klang abgespielt. Bis zum Ende der 'Klingeldauer' klingelt das Telefon dann mit seinem Standard-Klingelton.
         Das Abspielen ist eventuell nicht auf mehreren Fritz!Fons gleichzeitig möglich.
         <br>
         Je nach Fritz!OS kann das beschriebene Verhalten abweichen.
         <br>
      </li><br>

      <li><code>set &lt;name&gt; sendMail [to:&lt;Address&gt;] [subject:&lt;Subject&gt;] [body:&lt;Text&gt;]</code>
         <br>
         Sendet eine Email über den Emailbenachrichtigungsservice der als Push Service auf der Fritz!Box konfiguriert wurde.
         Mit "\n" kann einen Zeilenumbruch im Textkörper erzeut werden.
         Alle Parameter können ausgelassen werden. Bitte kontrolliert, dass die Email nicht im Junk-Verzeichnis landet.
         <br>
         Benötigt einen Telnet Zugang zur Box.
         <br>
      </li><br>
      
      <li><code>set &lt;name&gt; startRadio &lt;internalNumber&gt; [Name oder Nummer]</code>
         <br>
         Startet das Internetradio auf dem angegebenen Fritz!Fon. Eine verfügbare Radiostation kann über den Namen oder die (Gerätewert)Nummer ausgewählt werden. Ansonsten wird die in der Box als Internetradio-Klingelton eingestellte Station abgespielt. (Also <b>nicht</b> die am Telefon ausgewählte.)
         <br>
      </li><br>
      
      <li><code>set &lt;name&gt; tam &lt;number&gt; &lt;on|off&gt;</code>
         <br>
         Schaltet den Anrufbeantworter (Nummer 1, 2 ...) an oder aus.
         Der Anrufbeantworter muss zuvor auf der Fritz!Box eingerichtet werden.
      </li><br>
      
      <li><code>set &lt;name&gt; update</code>
         <br>
         Startet eine Aktualisierung der Gerätewerte.
      </li><br>
      
      <li><code>set &lt;name&gt; wlan &lt;on|off&gt;</code>
         <br>
         Schaltet WLAN an oder aus.
      </li><br>
   </ul>  

   <a name="FRITZBOXget"></a>
   <b>Get</b>
   <ul>
      <br>
      <li><code>get &lt;name&gt; ringTones</code>
         <br>
         Zeigt die Liste der Klingeltöne, die benutzt werden können.
      </li><br>

      <li><code>get &lt;name&gt; shellCommand &lt;Befehl&gt;</code>
         <br>
         Führt den angegebenen Befehl auf der Fritz!Box-Shell aus und gibt das Ergebnis zurück.
         Kann benutzt werden, um Shell-Befehle auszuführen, die nicht im Modul implementiert sind.
         <br>
         Muss zuvor über das Attribute "allowShellCommand" freigeschaltet werden.
      </li><br>

      <li><code>get &lt;name&gt; tr064Command &lt;service&gt; &lt;control&gt; &lt;action&gt; [[argName1 argValue1] ...] </code>
         <br>
         Führt über TR-064 Aktionen aus (siehe <a href="http://avm.de/service/schnittstellen/">Schnittstellenbeschreibung</a> von AVM).
         <br>
         argValues mit Leerzeichen müssen in Anführungszeichen eingeschlossen werden.
         <br>
         Beispiel: <code>get Fritzbox tr064Command X_AVM-DE_OnTel:1 x_contact GetDECTHandsetInfo NewDectID 1</code>
         <br>
         Muss zuvor über das Attribute "allowTR064Command" freigeschaltet werden.
      </li><br>

      <li><code>get &lt;name&gt; tr064ServiceListe</code>
         <br>
         Zeigt die Liste der TR-064-Dienste und Aktionen, die auf dem Gerät erlaubt sind.
      </li><br>
   </ul>  
  
   <a name="FRITZBOXattr"></a>
   <b>Attributes</b>
   <ul>
      <br>
      <li><code>allowShellCommand &lt;0 | 1&gt;</code>
         <br>
         Freischalten des get-Befehls "shellCommand"
      </li><br>
      
      <li><code>allowTR064Command &lt;0 | 1&gt;</code>
         <br>
         Freischalten des get-Befehls "tr064Command" und "luaQuery"
      </li><br>
      
      <li><code>boxUser &lt;user name&gt;</code>
         <br>
         Benutzername für den TR064- oder einen anderen webbasierten Zugang. Normalerweise wird keine Benutzername für das Login benötigt.
         Wenn die Fritz!Box anders konfiguriert ist, kann der Nutzer über dieses Attribut definiert werden.
      </li><br>
    
      <li><code>defaultCallerName &lt;Text&gt;</code>
         <br>
         Standard-Text, der auf dem angerufenen internen Telefon als "Anrufer" gezeigt wird.
         <br>
         Dies erfolgt, indem während des Klingelns temporär der Name der internen anrufenden Nummer geändert wird.
         <br>
         Es sind maximal 30 Zeichen erlaubt. Das Attribute "ringWithIntern" muss ebenfalls spezifiziert sein.
         <br>
         Benötigt die API: Telnet oder webcmd      
         </li><br>
      
      <li><code>defaultUploadDir &lt;fritzBoxPath&gt;</code>
         <br>
         Dies ist der Standard-Pfad der für Dateinamen benutzt wird, die nicht mit einem / (Schrägstrich) beginnen.
         <br>
         Es muss ein Pfad auf der Fritz!Box sein. D.h., er sollte mit /var/InternerSpeicher starten, wenn es in Windows unter \\ip-address\fritz.nas erreichbar ist.
      </li><br>

      <li><code>forceTelnetConnection &lt;0 | 1&gt;</code>
         <br>
         Erzwingt den Fernzugriff über Telnet (anstatt über die WebGUI oder TR-064).
         <br>
         Dieses Attribut muss bei älteren Geräten/Firmware aktiviert werden.
      </li><br>

      <li><code>fritzBoxIP &lt;IP-Adresse&gt;</code>
         <br>
         Veraltet.
      </li><br>
     
      <li><code>INTERVAL &lt;Sekunden&gt;</code>
         <br>
         Abfrage-Interval. Standard ist 300 (Sekunden). Der kleinste mögliche Wert ist 60.
      </li><br>

      <li><code>ringWithIntern &lt;1 | 2 | 3&gt;</code>
         <br>
         Um ein Telefon klingeln zu lassen, muss in der Fritzbox eine Anrufer (Wählhilfe, Wert 'box_stdDialPort') spezifiziert werden.
         <br>
         Um während des Klingelns eine Nachricht (Standard: "FHEM") anzuzeigen, kann hier die interne Nummer 1-3 angegeben werden.
         Der entsprechende analoge Telefonanschluss muss vorhanden sein.
      </li><br>

      <li><code>telnetTimeOut &lt;Sekunden&gt;</code>
         <br>
         Maximale Zeit, bis zu der während einer Telnet-Sitzung auf Antwort gewartet wird. Standard ist 10 s.
      </li><br>

      <li><code>telnetUser &lt;user name&gt;</code>
         <br>
         Benutzername für den Telnetzugang. Normalerweise wird keine Benutzername für das Login benötigt.
         Wenn die Fritz!Box anders konfiguriert ist, kann der Nutzer über dieses Attribut definiert werden.
      </li><br>
    
      <li><code>useGuiHack &lt;0 | 1&gt;</code>
         <br>
         Falls die APIs der Box nicht mehr die änderung des Klingeltones unterstützen (Fritz!OS >6.24), kann dieses Attribute entsprechend der <a href="http://www.fhemwiki.de/wiki/FRITZBOX#Klingelton-Einstellung_und_Abspielen_von_Sprachnachrichten_bei_Fritz.21OS-Versionen_.3E6.24">WIKI-Anleitung</a> genutzt werden.
      </li><br>

      <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
   </ul>
   <br>

   <a name="FRITZBOXreading"></a>
   <b>Readings</b>
   <ul><br>
      <li><b>alarm</b><i>1</i> - Name des Weckrufs <i>1</i></li>
      <li><b>alarm</b><i>1</i><b>_state</b> - Aktueller Status des Weckrufs <i>1</i></li>
      <li><b>alarm</b><i>1</i><b>_target</b> - Interne Nummer des Weckrufs <i>1</i></li>
      <li><b>alarm</b><i>1</i><b>_time</b> - Weckzeit des Weckrufs <i>1</i></li>
      <li><b>alarm</b><i>1</i><b>_wdays</b> - Wochentage des Weckrufs <i>1</i></li>
      <br>
      <li><b>box_dect</b> - Aktueller Status des DECT-Basis</li>
      <li><b>box_fwVersion</b> - Firmware-Version der Box, wenn veraltet dann wird '(old)' angehangen</li>
      <li><b>box_guestWlan</b> - Aktueller Status des Gäste-WLAN</li>
      <li><b>box_guestWlanCount</b> - Anzahl der Geräte die über das Gäste-WLAN verbunden sind</li>
      <li><b>box_guestWlanRemain</b> - Verbleibende Zeit bis zum Ausschalten des Gäste-WLAN</li>
      <li><b>box_ipExtern</b> - Internet IP der Fritz!Box</li>
      <li><b>box_model</b> - Fritz!Box-Modell</li>
      <li><b>box_moh</b> - Wartemusik-Einstellung</li>
      <li><b>box_powerRate</b> - aktueller Stromverbrauch in Prozent der maximalen Leistung</li>
      <li><b>box_rateDown</b> - Download-Geschwindigkeit des letzten Intervals in kByte/s</li>
      <li><b>box_rateUp</b> - Upload-Geschwindigkeit des letzten Intervals in kByte/s</li>
      <li><b>box_stdDialPort</b> - Anschluss der geräteseitig von der Wählhilfe genutzt wird</li>
      <li><b>box_tr064</b> - Anwendungsschnittstelle TR-064 (wird auch von diesem Modul benötigt)</li>
      <li><b>box_tr069</b> - Provider-Fernwartung TR-069 (sicherheitsrelevant!)</li>
      <li><b>box_wlanCount</b> - Anzahl der Geräte die über WLAN verbunden sind</li>
      <li><b>box_wlan_2.4GHz</b> - Aktueller Status des 2.4-GHz-WLAN</li>
      <li><b>box_wlan_5GHz</b> - Aktueller Status des 5-GHz-WLAN</li>
      
      <br>
      <li><b>dect</b><i>1</i> - Name des DECT Telefons <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_alarmRingTone</b> - Klingelton beim Wecken über das DECT Telefon <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_custRingTone</b> - Benutzerspezifischer Klingelton des DECT Telefons <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_fwVersion</b> - Firmware-Version des DECT Telefons <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_intern</b> - Interne Nummer des DECT Telefons <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_intRingTone</b> - Interner Klingelton des DECT Telefons <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_manufacturer</b> - Hersteller des DECT Telefons <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_model</b> - Modell des DECT Telefons <i>1</i></li>
      <li><b>dect</b><i>1</i><b>_radio</b> - aktueller Internet-Radio-Klingelton des DECT Telefons <i>1</i></li>
      <br>
      <li><b>diversity</b><i>1</i> - Eigene Rufnummer der Rufumleitung <i>1</i></li>
      <li><b>diversity</b><i>1</i><b>_dest</b> - Zielnummer der Rufumleitung <i>1</i></li>
      <li><b>diversity</b><i>1</i><b>_state</b> - Aktueller Status der Rufumleitung <i>1</i></li>
      <br>
      <li><b>fon</b><i>1</i> - Name des analogen Telefonanschlusses <i>1</i> an der Fritz!Box</li>
      <li><b>fon</b><i>1</i><b>_intern</b> - Interne Nummer des analogen Telefonanschlusses <i>1</i></li>
      <li><b>fon</b><i>1</i><b>_out</b> - ausgehende Nummer des Anschlusses <i>1</i></li>
      <br>
      <li><b>gsm_internet</b> - Internetverbindung errichtet über Mobilfunk-Stick </li>
      <li><b>gsm_rssi</b> - Indikator der empfangenen GSM-Signalstärke (0-100)</li>
      <li><b>gsm_state</b> - Status der Mobilfunk-Verbindung</li>
      <li><b>gsm_technology</b> - GSM-Technologie, die für die Datenübertragung genutzt wird (GPRS, EDGE, UMTS, HSPA)</li>
      <br>
      <li><b>mac_</b><i>01_26_FD_12_01_DA</i> - MAC Adresse und Name eines aktiven Netzwerk-Gerätes.
      <br>
      Bei einer WLAN-Verbindung wird "WLAN" und (von der Box gesehen) die Sende- und Empfangsgeschwindigkeit und die Empfangsstärke angehangen. Bei einer LAN-Verbindung wird der LAN-Port und die LAN-Geschwindigkeit angehangen. Gast-Verbindungen werden mit "gWLAN" oder "gLAN" gekennzeichnet.
      <br>
      Inaktive oder entfernte Geräte erhalten zuerst den Werte "inactive" und werden beim nächsten Update gelöscht.</li>
      <br>
      <li><b>radio</b><i>01</i> - Name der Internetradiostation <i>01</i></li>
      <br>
      <li><b>tam</b><i>1</i> - Name des Anrufbeantworters <i>1</i></li>
      <li><b>tam</b><i>1</i><b>_newMsg</b> - Anzahl neuer Nachrichten auf dem Anrufbeantworter <i>1</i></li>
      <li><b>tam</b><i>1</i><b>_oldMsg</b> - Anzahl alter Nachrichten auf dem Anrufbeantworter <i>1</i></li>
      <li><b>tam</b><i>1</i><b>_state</b> - Aktueller Status des Anrufbeantworters <i>1</i></li>
      <br>
      <li><b>user</b><i>01</i> - Name von Nutzer/IP <i>1</i> für den eine Zugangsbeschränkung (Kindersicherung) eingerichtet ist</li>
      <li><b>user</b><i>01</i>_thisMonthTime - Internetnutzung des Nutzers/IP <i>1</i> im aktuellen Monat (Kindersicherung)</li>
      <li><b>user</b><i>01</i>_todaySeconds - heutige Internetnutzung des Nutzers/IP <i>1</i> in Sekunden (Kindersicherung)</li>
      <li><b>user</b><i>01</i>_todayTime - heutige Internetnutzung des Nutzers/IP <i>1</i> (Kindersicherung)</li>
   </ul>
   <br>
</ul>
</div>

=end html_DE

=cut--
