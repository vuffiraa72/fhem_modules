=pod
=item device
=item summary 		Robot Vacuums
=item summary_DE	Staubsauger Roboter

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
	<code> set &lt;name&gt; nextCleaningMode</code>
	<br>
	Depending on Model, there are Arguments available: eco/turbo
	</li>
<br>
	<li>
	<code> set &lt;name&gt; nextCleaningNavigationMode</code>
	<br>
	 The navigation mode is used for the next house cleaning.
	 Depending on Model, there are Arguments available: normal/extraCare/deep
	</li>
<br>
	<li>
	<code> set &lt;name&gt; nextCleaningNavigationModifier</code>
	<br>
	 The modifier is used for next spot cleaning.
	 Depending on Model, there are Arguments available: normal/double
	</li>
<br>
	<li>
	<code> set &lt;name&gt; nextCleaningZone</code>
	<br>
	Depending on Model, the ID of the zone that will be used for the next zone cleaning can be set.
	</li>
<br>
	<li>
	<code> set &lt;name&gt; nextCleaningSpotHeight</code>
	<br>
	Is defined as number between 100 - 400. The unit is cm.
	</li>
<br>
	<li>
	<code> set &lt;name&gt; nextCleaningSpotWidth</code>
	<br>
	Is defined as number between 100 - 400. The unit is cm.
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
  <li>
	<code> set &lt;name&gt; setRobot</code>
	<br>
	choose robot if more than one is registered at the used account
	</li>
<br>
	<li>
	<code> set &lt;name&gt; startCleaning ([house|map|zone])</code>
	<br>
	start the Cleaning from the scratch.
	If the robot supports boundaries/nogo lines/zones, the additional parameter can be used as:
	<ul>
  <li><code>house</code> - cleaning without a persisted map</li>
  <li><code>map</code> - cleaning with a persisted map</li>
  <li><code>zone</code> - cleaning in a specific zone, set zone with nextCleaningZone</li>
  </ul>
	</li>
<br>
	<li>
	<code> set &lt;name&gt; startSpot</code>
	<br>
	start spot-Cleaning from actual position.
	</li>
<br>
  <li>
  <code> set &lt;name&gt; startManual</code>
  <br>
  start Manual Cleaning. This cleaning mode opens a direct websocket connection to the robot.
  Therefore robot and FHEM installation has to reside in the same LAN.
  Even though an internet connection is necessary as the initialization is triggered by a remote call.
  <br>
  <em>Note:</em> If the robot does not receive any messages for 30 seconds it will exit Manual Cleaning,
  but it will not close the websocket connection automaticaly.
  </li>
<br>
	<li>
	<code> set &lt;name&gt; statusRequest</code>
	<br>
	pull update of all readings. necessary because NEATO/VORWERK does not send updates at their own.
	</li>
<br>
	<li>
	<code> set &lt;name&gt; stop</code>
	<br>
	stop cleaning and in case of manual cleaning mode close also the websocket connection
	</li>
<br>
	<li>
	<code> set &lt;name&gt; syncRobots</code>
	<br>
	sync robot data with online account. Useful if one has more then one robot registered
	</li>
<br>
	<li>
	<code> set &lt;name&gt; wsCommand</code>
	<br>
	Commands start or stop cleaning activities.
  <ul>
  <li><code>eco-on</code></li>
  <li><code>eco-off</code></li>
  <li><code>turbo-on</code></li>
  <li><code>turbo-off</code></li>
  <li><code>brush-on</code></li>
  <li><code>brush-off</code></li>
  <li><code>vacuum-on</code></li>
  <li><code>vacuum-off</code></li>
  </ul>
	</li>
<br>
	<li>
	<code> set &lt;name&gt; wsCombo</code>
	<br>
  Combos specify a behavior on the robot. They need to be sent with less than 1Hz frequency.
  If the robot doesn't receive a combo with the specified frequency it will stop moving.
  <ul>
  <li><code>forward</code> issues a continuous forward motion.</li>
  <li><code>back</code> issues a discontinuous backward motion in ~30cm intervals as a safety measure since the robot has no sensors at the back.</li>
  <li><code>arc-left</code> issues a 450 turn counter-clockwise while going forward.</li>
  <li><code>arc-right</code> issues a 450 turn clockwise while going forward.</li>
  <li><code>pivot-left</code> issues a 900 turn counter-clockwise.</li>
  <li><code>pivot-right</code> issues a 900 turn clockwise.</li>
  <li><code>stop</code> issues an immediate stop.</li>
  </ul>
  Also, if the robot does not receive any messages for 30 seconds it will exit Manual Cleaning.
  </li>
<br>
</ul>
<a name="BOTVACattr"></a>
<b>Attributes</b>
<ul>
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
=cut