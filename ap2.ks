@LAZYGLOBAL on.
// ### AP.ks - autopilot by ozin ###
// Required files (found in the same github where you got this):
// lib_UI.ks
// lib_menu.ks


set config:ipu to max(config:ipu,1000).


runoncepath("lib_UI.ks").
//runoncepath("steeringmanager.ks").

set loaddist to ship:loaddistance.
SET loaddist:LANDED:UNLOAD TO 20000.
SET loaddist:LANDED:LOAD TO 19500.
WAIT 0. 
SET loaddist:LANDED:PACK TO 29999.
SET loaddist:LANDED:UNPACK TO 19000.
WAIT 0. 

SET loaddist:PRELAUNCH:UNLOAD TO 20000.
SET loaddist:PRELAUNCH:LOAD TO 19500.
WAIT 0.
SET loaddist:PRELAUNCH:PACK TO 29999.
SET loaddist:PRELAUNCH:UNPACK TO 19000.
WAIT 0.

SET loaddist:FLYING:UNLOAD TO 30000.
SET loaddist:FLYING:LOAD TO 29500.
WAIT 0.
SET loaddist:FLYING:PACK TO 39999.
SET loaddist:FLYING:UNPACK TO 29000.
WAIT 0.

sas off.
set th to throttle.
lock throttle to th.

// #### PID controllers ###
// >>
	set maxBank to 50.
	//old
	set attackPid to PIDLOOP(3, 0, 3, -10, 10). //old: PIDLOOP(3, 0.0, 3, -10, 10).
	set pitchPid to PIDLOOP(3.0, 0.3, 3.0, -20, 20). //(3.0, 0.2, 3.0, -10, 30). //outputs extra climb angle to get the velocity climb angle corrected 
	
	//set throtPid to PIDLOOP(0.1, 0.011, 0.01, 0, 1). //not really used any more, keeping it here for reference
	
	
	
	set circlePid to PIDLOOP(0.1, 0.000, 0.01, 0, 1).
	set wheelPid to PIDLOOP(0.15, 0.000, 0.1, -1, 1).
	
	//NEW
	set pitchVelPid to PIDLOOP(1.2, 0.2, 0.5, -10, 20).
	set ppid to pidloop(10.2,0.5,0.2,-1,1).
	set rpid to pidloop(5.0,0.5,0.8,-1,1).
	
	set yawVelPid to PIDLOOP(1, 0, 0.5, -20, 20).
	set ypid to pidloop(2.0,0,0.2,-1,1).
// << 

// ### Initual Stuff / default vars ###
// >>
	
	local m_land is 1.
	local m_takeoff is 2.
	local m_manual is 3.
	local m_cruise is 4.
	local m_circle is 5.
	local m_taxi is 6.
	local m_waypoints is 7.
	local m_follow is 8.
	
	local mode is m_manual.
	local submode is m_manual.
	
	
	
	local modeString is "manual".
	local upVec is up:vector.
	
	local targetSpeed is round(airspeed).
	local targetAlt is round(altitude).
	local controlSpeed is true.
	local controlAlt is false.
	local followTarget is ship.
	local isLanded is true.
	
	
	local targetHeading is round(headingOf(ship:facing:vector),2).
	local targetPitch is 0.
	if airspeed > 10 and ship:status = "Flying" {
		set targetPitch to max(0,90 - vang(upVec,velocity:surface)).
	}
	
	//settings default vars
	local stallSpeed is 70.
	local maxBankSpeed is 120.
	local cruiseSpeed is 200.
	local cruiseAlt is 1500.

	local rollSpd is 2.
	local bankMult is 3.
	local bankHard is false.
	local updateCam is false.
	local clockwise is true.
	local landingRadius is 1800.
	local circleRadius is 2000.
	local heightOffset is 3.
	local heightOffset is 3.
	local descentAngle is 4.
	local maxClimbAngle is 15.
	
	local airbrakes is false.
	if ship:status = "Landed" or ship:status = "PRELAUNCH"  set heightOffset to round(alt:radar,2).
	
	//terrain checks:
	local terrainDetection is true.
	local totalTime is 20. 
	local steps is 8.
	local timeIncrement is totalTime / steps.
	local heightMargin is 80.
	local velLast is velocity:surface.
	local accLast is v(0,0,0.1).
	local lastTerrainClimb is 0.
	local terrainVecs is false.
	
	local vd_stTarget is vecdraw(v(0,0,0),v(0,0,0),green,"",1,true,0.2).
	//local vd_st is vecdraw(v(0,0,0),v(0,0,0),magenta,"",1,true,0.2).
	local vd_facing is vecdraw(v(0,0,0),v(0,0,0),rgba(1,0,1,0.2),"",1,true,0.2).
	local vd_vel is vecdraw(v(0,0,0),v(0,0,0),rgba(0,1,0,0.2),"",1,true,0.2).
	local vd_roll is vecdraw(v(0,0,0),v(0,0,0),cyan,"",1,true,0.2).
	//local vd_acc is vecdraw(v(0,0,0),v(0,0,0),rgba(1,0.6,0.1,0.8),"",1,true,0.2).
	//local vd_drag is vecdraw(v(0,0,0),v(0,0,0),red,"",1,true,0.2).
	//local vd_approach is vecdraw(v(0,0,0),v(0,0,0),red,"",1,true,0.8).
	local vd_pos1 is vecdraw(v(0,0,0),up:vector * 5,yellow,"",1,false,0.2).
	
	local vd_terrainlist is list().
	function createTerrainVecdraws {
		showTerrainVecdraws(false).
		set vd_terrainlist to list().
		for i in range(steps) {
			vd_terrainlist:add(vecdraw(v(0,0,0),v(0,0,0),rgba(1,i/steps,0,0.5),"",1,terrainVecs,8)).
		}
	}
	function showTerrainVecdraws {
		parameter p.
		for i in range(vd_terrainlist:length) { set vd_terrainlist[i]:show to p. } //color to rgba(1,i/steps,0,0.5). }
	}
	createTerrainVecdraws().
	
	local vd_pos is vecdraw(v(0,0,0),up:vector * 1000,rgba(1,1,0,0.3),"",1,false,8).
	
	local waypoints is list().
	local wp_lat is 0.
	local wp_lng is 90.
	local vd_waypoint_active is vecdraw(v(0,0,0),v(0,0,0),cyan,"",1,false,0.5).
	
	local vd_runway_edit is vecdraw(v(0,0,0),v(0,0,0),rgba(1,0.7,0,0.5),"",1,false,40).
	local vd_runway_normal is vecdraw(v(0,0,0),v(0,0,0),rgba(0.7,0,1,0.5),"",1,false,2).
	
	
	loadSettings().
	
	local runways is list().
	
	
	
	if not loadRunways() { 
		//loading runways from json failed, so use these as default and attempt save
		runways:add(list("KSC 09", 
			LATLNG(-0.0486697432694389, -74.7220377114077), LATLNG(-0.0502131096942382, -74.4951289901873), // <- the first two geolocations in the list make up the runway. The plane will land close to the first one facing the second, and will take off facing the same way as well.
			LATLNG(-0.0633901920593838,-74.6177340872895), LATLNG(-0.0667142201078598,-74.6245921697804),LATLNG(-0.0574241046721476,-74.6304580442504))). // <- taxi/parking waypoints. as many waypoints as you want, the last one being the parking spot
		runways:add(list("KSC 27", 
			LATLNG(-0.0502131096942382, -74.4951289901873), LATLNG(-0.0486697432694389, -74.7220377114077), 
			LATLNG(-0.0633901920593838,-74.6177340872895), LATLNG(-0.0667142201078598,-74.6245921697804),LATLNG(-0.0574241046721476,-74.6304580442504))). 
		runways:add(list("Island 09", 
			LATLNG(-1.51806713434498,-71.9686515236803), LATLNG(-1.51566431260178,-71.8513882426904),
			LATLNG(-1.52246003880166,-71.8951322255196), LATLNG(-1.52238917854372,-71.9029429161532))).
		runways:add(list("Island 27", 
			LATLNG(-1.51566431260178,-71.8513882426904), LATLNG(-1.51806713434498,-71.9686515236803),
			LATLNG(-1.52246003880166,-71.8951322255196), LATLNG(-1.52238917854372,-71.9029429161532))).
			
		saveRunways().
	}
	
	local runwayIndex is 0.
	local selectedRunway is runways[runwayIndex].
	
// <<

// ### Teminal menu setup ###
// >>

set terminal:brightness to 1.
set terminal:width to 56.
set terminal:height to 40.
clearscreen.


// use the first two of these varables to set the position of the menu. The last two affect the width of the menu.
global startLine is 1.		//the first menu item will start at this line in the terminal window
global startColumn is 4.		//menu item description starts at this x coordinate, remember to leave some space for the marker on the left
global nameLength is 22.		//how many characters of the menu item names to display
global valueLength is 22.	//how many characters of the menu item values to display
global sv is -9.9993134. 	// just a value that is extremely unlikely to be set to any of the varibles we want to change with the menu

local runwaysMenu is list().
local runwaysEditMenu is list().

createRunwaysMenues().

set vd_waypoint_list to list().
set editRunwayMenu to list().



set mainMenu to list(
	list("<color=white>ATMO AUTOPILOT</color>",		"text"),
	list("=",				"line"),
	list("",				"text"),
	list("[>] MODES",		"menu" , 	{ return modesMenu. }),
	list("",				"text"),
	list("Mode",			"display",	{ return modeString. }),
	list("Runway",			"display",	{ return selectedRunway[0] + " - " + round(selectedRunway[1]:distance/1000,1) + " km". }),
	list("-",				"line"),
	list("Speed setpoint:",	"number", 	{ parameter p is sv. if p <> sv set targetSpeed to max(0,round(p)). return round(targetSpeed). }, 10, " m/s"),
	list("Speed",			"display", 	{ return round(airspeed) + " m/s". }),
	list("",				"text"),
	list("Heading target:",	"number", 	{ parameter p is sv. if p <> sv {
											if p > 360 set p to p - 360. 
											else if p < 0 set p to 360 + p.
											set targetHeading to p.
											set updateCam to true.
										} 
										return round(targetHeading,2). }, 10),
	list("-",				"line"),
	list("Altitude control:","bool", 	{ parameter p is sv. if p <> sv set controlAlt to boolConvert(p). set mainMenu[14][1] to choose "display" if controlAlt else "number".  return controlAlt. }),

	
	list("Altitude target:","number", { parameter p is sv. if p <> sv set targetAlt to max(0,round(p,1)). return round(targetAlt,1). }, 100, " m"),
	list("Climb angle:",	"number", 	{ parameter p is sv. if p <> sv set targetPitch to max(-90,min(90,p)). return round(targetPitch,2). }, 1),
	list("-",				"line"),
	list("Terrain detection:","bool", 	{ parameter p is sv. if p <> sv set terrainDetection to boolConvert(p). return terrainDetection. }),
	list("[>] Detection settings","menu" , 	{ return terrainMenu. }),
	
	//list("Bank Hard:",	"bool", 	{ parameter p is sv. if p <> sv set bankHard to boolConvert(p). return bankHard. }),
	
	list("-",				"line"),
	list("Vecdraws:"		,"bool", 	{ parameter p is sv. if p <> sv { set showVecsVar to boolConvert(p). showVecs(showVecsVar). } return showVecsVar. }),
	
	list("[ Switch to vessel ]", 	"action", { kuniverse:forceactive(ship). }),
	list("[>] Runways editor",	"menu" , 	{ return runwaysEditMenu. }),
	list("[>] Vessel settings",	"menu" , 	{ return settingsMenu. }),
	list("[X] Exit", 			"action", { set done to true. })
).

set modesMenu to list(
	list("MODES SELECTION", "text"),
	list("=",				"line"),
	list("Manual",	"action", 	{ 
		if mode <> m_manual {
			setMode(m_manual).
			setMenu(mainMenu).
		}
	}),
	list("Take-off",	"action", 	{ 
		if mode <> m_takeoff {
			setMode(m_takeoff).
			setMenu(mainMenu).
		}
	}),
	
	list("Land",	"action", 	{  
		setMenu(runwaysMenu).
	}),
	list("Circle",	"action", 	{
		if mode <> m_circle {
			setMode(m_circle).
		}
		setMenu(circleModeMenu).
	}),
	list("Waypoints",	"action", 	{
		if mode <> m_waypoints setMode(m_waypoints).
		setMenu(waypointsMenu).
	}),
	list("Follow",	"action", 	{
		//if mode <> m_follow setMode(m_follow).
		createTargetsMenu().
		setMenu(followMenu).
	}),
	list("-",				"line"),
	list("[<] MAIN MENU",		"backmenu", { return mainMenu. })
).

set circleModeMenu to list(
	list("Circling settings",		"text"),
	list("=",				"line"),
	list("Circle Radius:",	"number", 	{ parameter p is sv. if p <> sv set circleRadius to max(100,round(p)). return circleRadius. }, 100),
	list("Clock-wise:",		"bool", 	{ parameter p is sv. if p <> sv set clockwise to boolConvert(p). return clockwise. }),
	list("-",				"line"),
	list("[<] MAIN MENU",		"backmenu", { return mainMenu. })
).

set waypointsMenu to list(
	list("Waypoints Editor", "text"),
	list("=",				"line"),
	list("New waypoint:",	"text"),
	list("Latitude:",	"number", 	{ parameter p is sv. if p <> sv set wp_lat to min(90,max(-90,round(p,4))). return wp_lat. }, 0.1),
	list("Longitude:",	"number", 	{ parameter p is sv. if p <> sv set wp_lng to min(180,max(-180,round(p,4))). return wp_lng. }, 0.1),
	list("[+] Add WP", 		"action", { waypoints:add(latlng(wp_lat,wp_lng)). }),
	list("",						"text"),
	list("Waypoints left:",			"display", { return waypoints:length. }),
	list("[-] Skip to next", 		"action", { if waypoints:length > 1 waypoints:remove(0). }),
	list("-",				"line"),
	list("Mountain Tour", 		"action", { set waypoints to list(). 
											waypoints:add(LATLNG(-0.0288843395763714,-78.3836648093183)).
											waypoints:add(LATLNG(0.67914185514754,-78.6913483853345)).
											waypoints:add(LATLNG(1.19860372319739,-78.6467231762604)).
											waypoints:add(LATLNG(1.63351531487006,-78.1687083922323)).
											waypoints:add(LATLNG(2.10981070528106,-78.0245233116159)).
											waypoints:add(LATLNG(2.45625794385979,-78.3769727412787)).
											waypoints:add(LATLNG(2.06879101827048,-78.8486743538358)).
											waypoints:add(LATLNG(0.32240593461724,-78.8082277454115)).
											waypoints:add(LATLNG(0.118015641463436,-79.0404589992632)).
											waypoints:add(LATLNG(0.237191058345154,-79.4342719546221)).
											waypoints:add(LATLNG(0.30283674256653,-79.8950644345877)).
											waypoints:add(LATLNG(-0.383336346233216,-80.2556035108905)).
											waypoints:add(LATLNG(-1.10275914709192,-80.6558477235641)).
											waypoints:add(LATLNG(-0.70247962754558,-80.2010409750887)).
											waypoints:add(LATLNG(-0.471668929400925,-79.7182573970127)).
											waypoints:add(LATLNG(-0.0714015441448632,-79.2614526472176)).
											waypoints:add(LATLNG(0.320130369101675,-79.14161965863)).
											waypoints:add(LATLNG(0.686130991310734,-79.3495663614867)).
										}),
	list("[<] MAIN MENU",		"backmenu", { return mainMenu. })
).



set settingsMenu to list(
	//list(name,type,get/set function,increment multiplier (for numbers)).
	list("Vessel Settings", "text"),
	list("=",				"line"),
	list("Craft:",			"display", 	{ return ship:name. }),
	list("",				"text"),
	list("Stall Speed:",		"number", 	{ parameter p is sv. if p <> sv set stallSpeed to max(5,round(p)). return stallSpeed. }, 1),
	list("Full Bank Speed:",	"number", 	{ parameter p is sv. if p <> sv set maxBankSpeed to max(stallSpeed + 10,round(p)). return maxBankSpeed. }, 10),
	list("Cruise Speed:",		"number", 	{ parameter p is sv. if p <> sv set cruiseSpeed to max(maxBankSpeed,round(p)). return cruiseSpeed. }, 10),
	list("",				"text"),
	list("Cruise Altitude:",		"number", 	{ parameter p is sv. if p <> sv set cruiseAlt to max(0,round(p)). return cruiseAlt. }, 100),
	list("Airbrakes in flight:","bool", { parameter p is sv. if p <> sv set airbrakes to boolConvert(p). return airbrakes. }),
	list("Max Climb Angle:","number", 	{ parameter p is sv. if p <> sv set maxClimbAngle to max(5,round(p,1)). return maxClimbAngle. }, 0.1),
	list("",				"text"),
	list("Bank limit:",		"number", 	{ parameter p is sv. if p <> sv { set maxBank to max(10,round(p)). } return maxBank. }, 10),
	list("Bank sensitivity:",	"number", 	{ parameter p is sv. if p <> sv set bankMult to max(0.1,round(p,2)). return bankMult. }, 0.1),
	list("",				"text"),
	list("pitch kP:",		"number", 	{ parameter p is sv. if p <> sv { set ppid:kp to max(0,p). } return ppid:kp. }, 0.1),
	list("pitch kI:",		"number", 	{ parameter p is sv. if p <> sv { set ppid:ki to max(0,p). } return ppid:ki. }, 0.1),
	list("pitch kD:",		"number", 	{ parameter p is sv. if p <> sv { set ppid:kd to max(0,p). } return ppid:kd. }, 0.1),
	list("roll kP:",		"number", 	{ parameter p is sv. if p <> sv { set rpid:kp to max(0,p). } return rpid:kp. }, 0.1),
	list("roll kI:",		"number", 	{ parameter p is sv. if p <> sv { set rpid:ki to max(0,p). } return rpid:ki. }, 0.1),
	list("roll kD:",		"number", 	{ parameter p is sv. if p <> sv { set rpid:kd to max(0,p). } return rpid:kd. }, 0.1),
	
	list("",				"text"),
	list("Landing:",		"text"),
	list("Turn radius:",	"number", 	{ parameter p is sv. if p <> sv set landingRadius to max(500,round(p)). return landingRadius. }, 100),
	list("Descent angle:",	"number", 	{ parameter p is sv. if p <> sv set descentAngle to max(3,round(p,1)). return descentAngle. }, 1),
	list("",				"text"),
	list("Height offset:",	"number", 	{ parameter p is sv. if p <> sv set heightOffset to max(0.1,round(p,2)). return heightOffset. }, 0.1),
	
	
	list("-",				"line"),
	list("[ ] SAVE CHANGES TO ARCHIVE","action", 	{ saveSettings(). }),
	list("[<] MAIN MENU",	"backmenu", { return mainMenu. })
).

set terrainMenu to list(
	//list(name,type,get/set function,increment multiplier (for numbers)).
	list("Terrain detection settings", "text"),
	list("=",				"line"),
	list("Terrain Detection","text"),
	list("Enabled:",		"bool", 	{ parameter p is sv. if p <> sv set terrainDetection to boolConvert(p). return terrainDetection. }),
	list("Vecdraws:",		"bool", 	{ parameter p is sv. if p <> sv { set terrainVecs to boolConvert(p). showTerrainVecdraws(terrainVecs). } return terrainVecs. }),
	list("Minimum Radar-Alt:",	"number", 	{ parameter p is sv. if p <> sv set heightMargin to max(10,round(p)). return heightMargin. }, 10),
	list("",				"text"),
	list("Prediction Length:",	"number", 	{ parameter p is sv. if p <> sv { set totalTime to max(3,round(p)). set timeIncrement to totalTime / steps. } return totalTime. }, 10),
	list("Prediction Steps:",	"number", 	{ parameter p is sv. if p <> sv { set steps to max(1,round(p)). set timeIncrement to totalTime / steps. createTerrainVecdraws(). } return steps. }, 1),
	list("-",				"line"),
	list("[<] MAIN MENU",	"backmenu", { return mainMenu. })
).

// the list that defines the menu items: their names, types, and function
set activeMenu to mainMenu.
runpath("lib_menu.ks"). //this needs to be run after all the above setup, it contains all the terminal menu logic that this script uses

// <<

local showVecsVar is true.


set gravityMag to body:mu / body:position:sqrmagnitude.

set tarVessel to ship.
local done is false.
drawAll().

local runwayWater is false.
set lastVel to velocity:surface.
set acc to v(0,0,0).
set lastT to time:seconds.
set dt to 0.02.
wait 0.
local terminalCycle is 99.

// ### MAIN LOOP ###
until done {
	inputs(). //this function checks if the user is pressing any keys to interact with the terminal menu, should be called every physics tick (there is a "wait 0." at the end of this loop)
	
	if not(gear) and mode = m_land and submode = m_manual and not(runwayWater) {
		gear on.
	}
	else if gear and alt:radar > 50 and mode <> m_land {
		gear off.
	}
	
	set shipStatus to ship:status.
	set isLanded to shipStatus = "landed" or shipStatus = "splashed"  or shipStatus = "prelaunch".
	
	set shipfacing to ship:facing:vector.
	set vel to velocity:surface.
	set forwardSpeed to vdot(shipfacing,vel).
	
	set upVec to up:vector.
	local hVel is vxcl(upVec,vel).
	set heightOffsetVec to upVec * heightOffset.
	
	set gravity to -upVec * gravityMag.
	set thrustVec to shipfacing * getTotalThrust().
	
	//acceleration
	set dt to time:seconds - lastT.
	set lastT to time:seconds.
	set acc to (vel - lastVel)/dt.
	set lastVel to vel.
	
	
	//drag
	set engineAcc to thrustVec / mass.
	set dragVec to -engineAcc + acc.
	set dragFacingMag to vdot(shipfacing,dragVec).
	set dragVelMag to vdot(vel:normalized,dragvec).
	
	//set vd_acc:vec to acc.
	//set vd_acc:label to round(acc:mag,2):tostring().
	
	//set dragFacingVec to shipfacing * dragVelMag.
	//set vd_drag:vec to dragFacingVec.
	//set vd_drag:label to round(dragVelMag,2):tostring().
	
	
	//local hFacing is vxcl(upVec,ship:facing:vector).
	
	//local shipHeading is headingOf(hVel).
	
	if activeMenu = editRunwayMenu {
		local runway_edit_upvec is (runways[editRunwayI][1]:position-body:position):normalized * 10.
		
		if runways[editRunwayI][1]:terrainheight < 0 set vd_runway_edit:start to runways[editRunwayI][1]:altitudeposition(10).
		else set vd_runway_edit:start to runways[editRunwayI][1]:position + runway_edit_upvec.
		if runways[editRunwayI][2]:terrainheight < 0 set vd_runway_edit:vec to runways[editRunwayI][2]:altitudeposition(10) - vd_runway_edit:start.
		else set vd_runway_edit:vec to (runways[editRunwayI][2]:position + runway_edit_upvec) - vd_runway_edit:start.
		
		for i in range(0,vd_waypoint_list:length,1) {
			set vd_waypoint_list[i]:show to true.
			set vd_waypoint_list[i]:start to runways[editRunwayI][(3 + i)]:position.
			set vd_waypoint_list[i]:vec to upVec * 10.
		}
		
		if runway_normal_check > vd_runway_edit:vec:mag set runway_normal_check to 0.
		set runway_normal_check to runway_normal_check + 5.
		
		local runwayAverageNormal is vxcl(vd_runway_edit:vec,runway_edit_upvec).
		local normalVecPos is body:geopositionof(vd_runway_edit:start + vd_runway_edit:vec:normalized * runway_normal_check).
		local normalVec is geo_normalvector(normalVecPos,15).
		
		set vd_runway_normal:show to true.
		set vd_runway_normal:start to normalVecPos:position.
		set vd_runway_normal:vec to normalVec * 200.
		local normalVecAngle is vang(normalVec,runwayAverageNormal).
		set vd_runway_normal:color to rgba(normalVecAngle / 10, (10 - normalVecAngle) / 10, 0, 0.9).
		set vd_runway_normal:label to round(normalVecAngle,1):tostring().
	}
	
	//>> ### Mode specific stuff 
	if mode = m_takeoff {
		set controlAlt to false.
		updateRunwayPos().
		
		local side_dist is abs(vdot(vcrs(runwayVec,upVec):normalized, pos1)).
		
		local aimPosHeading is v(0,0,0).
		local offset is vdot(-runwayVecNormalized,pos1).
		if ship:status = "splashed" {
			set aimPosHeading to pos1 + runwayVecNormalized * (offset + max(0,groundspeed * 10 - side_dist/8)).
			set targetSpeed to 6 + max(2,side_dist^0.3).
		}
		else {
			set aimPosHeading to pos1 + runwayVecNormalized * (offset + max(0,groundspeed * 6 - side_dist/4)).
			set targetSpeed to 6.
		}
		
		
		set targetHeading to headingOf(aimPosHeading).
		
		
		if (vang(vxcl(upVec,runwayVec),hVel) < 6 and side_dist < 15 + groundspeed / 10) or not(isLanded) set targetSpeed to maxBankSpeed + 20.
		
		set targetPitch to max(0,min(maxClimbAngle*0.8,(forwardSpeed - stallSpeed) * 0.5)).
		
		local heightAbove is vdot(-upVec,pos1).
		if heightAbove > 200 {
			set mode to m_circle.
			set submode to m_circle.
			set modeString to "circling".
			set controlAlt to true.
			set targetAlt to selectedRunway[1]:terrainheight + 1500.
			set circleRadius to landingRadius.
			set circleLoc to body:geopositionof(vcrs(upVec,runwayVec):normalized * circleRadius).
			set clockwise to true.
			
			set vd_pos:show to true.
		}
		
	}
	else if mode = m_land {
		updateRunwayPos().
		
		local circleForwardOffset is 750 + landingRadius * max(1,airspeed/(targetSpeed + 10)) + 2200 - min(1100,200 * bankMult). //shorter approach for agile aircrafts
		
		if submode = m_manual 
		or RCS
		or (vang(vxcl(upVec,pos1),hVel) < 5 
		and vang(hVel,runwayVec) < 20 
		and 90 - vang(upVec,pos1) + descentAngle > -10
		//and altitude-targetAlt < 500 
		and pos1dist < (500 + circleForwardOffset) 
		and airspeed/targetSpeed < 1.2)
		{
			if submode = m_circle {
				set submode to m_manual.
				set vd_pos:show to false.
				ag10 on. //flaps
			}
			//force manual target pitch
			set controlAlt to false.
			set vd_pos1:show to true.
			
			
			//offset = distance to start of runway (negative if in front of us) along runway vector
			local offset is -vdot(runwayVecNormalized,pos1).
			
			//for heading: aim at point in front of runway, 6 seconds ahead of current position
			local aimPosHeading is pos1 + runwayVecNormalized * max(-3000,offset + max(15,groundspeed * 6)).
			set targetHeading to headingOf(aimPosHeading).
			
			//for pitch:
			
			local aimFrontOffset is max(-500,min(0,offset/3)).
			local pitchPosOffset is offset + 200 * (groundspeed/50) * ((3/descentAngle)^0.4) - aimFrontOffset.
			
			
			if pitchPosOffset < 0 {
				set descentVecNormalized to angleaxis(descentAngle,vcrs(upVec,runwayVecNormalized)) * runwayVecNormalized.
				set aimPosPitch to pos1 +  aimFrontOffset * runwayVecNormalized + (descentVecNormalized * pitchPosOffset).
			}
			else set aimPosPitch to pos1 + aimFrontOffset * runwayVecNormalized + runwayVecNormalized * pitchPosOffset.
			
			if offset > 0 and runwayStart:terrainheight >= 0 set aimPosPitch to body:geopositionof(aimPosPitch):position + heightOffsetVec.
			
			set targetPitch to 90 - vang(aimPosPitch,upVec).
			if offset > 0 set targetPitch to min(90 - vang(runwayVec,upVec) - min(1.2,0.25 + max(0,alt:radar - heightOffset)/4),targetPitch).
			 
			set vd_pos1:label to "o: " + round(offset) + ", po: " +  round(pitchPosOffset).
			set vd_pos1:start to aimPosPitch.
			//set vd_approach:vec to aimPosPitch.
			
			
			if isLanded { 
				set targetPitch to 0.
				set targetSpeed to 0. 
				
				if selectedRunway:length > 3 and groundspeed < 32 and vdot(runwayVec,selectedRunway[3]:position) > 0 { //runway has a designated parkingspot and it is ahead
					set submode to m_taxi.
					set waypointI to 2.
				}
				else if groundspeed < 5 setMode(m_manual).

				
			}
			else if alt:radar < 15 {
				set targetSpeed to 0.
			}
			else set targetSpeed to stallSpeed + max(0,vdot(runwayVecNormalized,pos1)/circleForwardOffset) * (maxBankSpeed + 10 - stallSpeed).
		}
		else if submode = m_taxi {
			
			
			if waypointI = 2 { //still on the runway, not arrived at the first waypoint yet
				set waypoint to pos1 + runwayVecNormalized * vdot(runwayVecNormalized,selectedRunway[3]:position - pos1).
				set targetSpeed to max(10,min(30,waypoint:mag/10)).
				if waypoint:mag < 42 and groundspeed > 20 { set targetSpeed to 0. setMode(m_manual). } //going too fast to turn off the runway, just continue until stopped.
			}
			else {
				set waypoint to selectedRunway[waypointI]:position + heightOffsetVec.
				set targetSpeed to min(8,waypoint:mag/2).
			}
			if waypoint:mag < 40 and selectedRunway:length > waypointI + 1 set waypointI to waypointI + 1.
			if selectedRunway:length > waypointI + 1 set targetSpeed to max(6,targetSpeed).
			set targetPitch to 0.
			set targetHeading to headingOf(waypoint).
			if vdot(shipfacing,waypoint) < 5 and selectedRunway:length = waypointI + 1 { set targetSpeed to 0. setMode(m_manual). }
		}
		else {
			set submode to m_circle.
			
			local pos1UpVec is (pos1 - body:position):normalized.
			local sidevec is vcrs(runwayVecNormalized,pos1UpVec).
			
			if runLandingSetup {
				if vdot(sidevec, pos1) > 0 { set clockwise to true. }
				else { set clockwise to false. }
				
				set runLandingSetup to false.
			}
			
			if clockwise set sidevec to -sidevec.
			
			set circleRadius to landingRadius * max(1,airspeed/(targetSpeed + 10)).
			local turnCenter is pos1 - runwayVecNormalized * circleForwardOffset + sideVec:normalized * (circleRadius + landingRadius/40).
			set circleLoc to body:geopositionof(turnCenter).
			
			
			local runwayAlt is max(0,runwayStart:terrainheight).
			
			local glideVec is -runwayVecNormalized * circleForwardOffset.
			set glideVec to angleaxis(descentAngle,vcrs(pos1UpVec,runwayVecNormalized)) * glideVec.
			
			//set glideVD to vecdraw(pos1,glideVec,red,"",1,true,20).
			
			local glideStartAlt is vdot(pos1UpVec,glideVec).
			
			set circleCenterDist to vxcl(upVec,circleLoc:position):mag.
			set controlAlt to true.
			if circleCenterDist < circleRadius + 500 { //in turn or close to it
				set targetAlt to runwayAlt + glideStartAlt.
			}
			else {
				set targetAlt to max(runwayAlt + glideStartAlt,targetAlt).
				set targetAlt to min(runwayAlt + glideStartAlt + max(0,circleCenterDist - circleRadius*4) / 6,targetAlt).
				
			}
			
			set targetSpeed to max(maxBankSpeed + 10,targetSpeed).
			set targetSpeed to min(maxBankSpeed + 10 + max(0,circleCenterDist - circleRadius*2) / 50,targetSpeed).
		}
	}
	else if mode = m_waypoints {
		//submode is m_circle
		//waypoints stored in: waypoints (list of geolocs)
		
		if activeMenu = waypointsMenu {
			set vd_waypoint_active:show to true.
			local waypoint_active is latlng(wp_lat,wp_lng).
			set vd_waypoint_active:start to waypoint_active:position.
			set vd_waypoint_active:vec to (vd_waypoint_active:start - body:position):normalized * 20000.
			if mapview set vd_waypoint_active:width to 0.5.
			else set vd_waypoint_active:width to 10 + waypoint_active:distance / 600.
		}
		else set vd_waypoint_active:show to false.
		
		if waypoints:length = 0 setMode(m_circle).
		else if waypoints:length = 1 set circleRadius to landingRadius * 2.
		else {
			
			if vxcl(upVec,waypoints[0]:position):mag < (2.2 * landingRadius) waypoints:remove(0).
			set circleRadius to 1.
		}
		set circleLoc to waypoints[0].
	}
	else if mode = m_follow {
		local targetVel is followTarget:velocity:surface.
		local targetPosition is followTarget:position.
		set targetPosition to targetPosition + upVec * max(0,min(50,  (200 - vdot(targetVel:normalized,targetPosition))/4  )). //add height offset if we're really close or ahead of the target we're following
		
		
		
		set controlAlt to false.
		set targetPitch to min(maxClimbAngle,max(-25, (90 - vang(upVec,targetPosition + targetVel)) / 1 )).
		//set targetAlt to followTarget:altitude + followTarget:verticalspeed * 6.
		
		
		set targetHeading to headingOf(
			targetPosition:normalized + followTarget:velocity:surface:normalized * max(0.5, 6 - followTarget:distance/200)
		).
		set targetSpeed to max(
			followTarget:airspeed 
			+ max(-20,min(0, vdot(targetVel:normalized,targetPosition) * 0.25)) 
			+ min(100,(max(1,vdot(targetVel:normalized,targetPosition))^1.3 - 400) / 100)
			//+ min(100,(max(1,vdot(targetVel:normalized,targetPosition))^0.9 * max(0,-dragVelMag)) / 100)
			, stallSpeed * 1.25).
	}
	
	
	if submode = m_circle { //<-this must not be an else-if!
		if kuniverse:activevessel = ship and mode <> m_land {
			if hasTarget set tarVessel to target.
			else set tarVessel to ship.
		}
		if tarVessel <> ship and mode <> m_land set circleLoc to tarVessel:geoposition.
		local centerPos is vxcl(upVec,circleLoc:position).
		//faceCamTo(centerPos).
		set currentRadius to centerPos:mag.
		
		local sign is 1.
		if clockwise set sign to -1.
		
		
		
		if currentRadius > circleRadius { //aim for the edge of the circle
			local theta is arcsin(circleRadius/currentRadius).
			set targetHeadingVec to centerPos * angleaxis(theta * sign,upVec).
		}
		else { //we're closer than we should be.
			local offset is circlePid:update(time:seconds, circleRadius - currentRadius ).
			set targetHeadingVec to sign * vcrs(upVec,centerPos):normalized * targetSpeed + centerPos:normalized * offset * targetSpeed.
		}
		
		set targetHeading to headingOf(targetHeadingVec).
		
		set vd_pos:start to circleLoc:position.
		set vd_pos:vec to upVec * 2000.
		//print "center dist: " + round(centerPos:mag) + "m   " at (1,terminal:height-1).
	}
	//<<
	
	// ### Abort ###
	if abort {
		abort off.
		setmode(m_manual).
		set controlAlt to true.
		set targetAlt to altitude + 2000.
		set targetSpeed to maxBankSpeed + 20.
		HUDTEXT("!!! PANIC !!!",10,2,30,red,false).
	}
	
	
	// ### ALT ###
	if controlAlt {
		local altError is targetAlt - altitude.
		local desiredVV is max(-airspeed,min(airspeed,altError / 10)).
		
		set targetPitch to 90 - arccos(desiredVV/max(0.1,airspeed)).
		set targetPitch to min(maxClimbAngle,max(-25,targetPitch)).
		
		
	}
	
	// Terrain avoidance
	if terrainDetection and not(isLanded) and (controlAlt or mode = m_land or mode = m_follow) {
		
		local hTargeVec is heading(targetHeading,0):vector.
		
		local velAngRot is min(45,vang(vel,velLast) / dT). //how much degrees we should rotate the accel vector between steps ("angular velocity" of the velocity vector)
		local velRotAxis is vcrs(velLast,vel).  //the axis that we should rotate the acc vec around
		local wrongWay is vdot(vxcl(vel,vel - velLast),hTargeVec) < 0.
		set velLast to vel.
		
		local velTemp is angleaxis(velAngRot * timeIncrement * 0.5,velRotAxis) * vel.
		local posTemp is v(0,0,0).

		local terrainClimb is -90.
		
		
		if submode = m_manual and mode = m_land set heightMarginVec to upVec * 20.
		else set heightMarginVec to upVec * heightMargin.
		
		
		
		
		for i in range(steps) { // (for each incremental step to check..)
			set posTemp to posTemp + velTemp * timeIncrement.
			
			if wrongWay { set velTemp to vel. } //currectly turning the wrong way
			else if submode = m_circle and currentRadius/circleRadius < 1.5 {
				set velTemp to angleaxis(velAngRot * timeIncrement,velRotAxis) * velTemp.
			}	
			else {				
				local hVelTemp is vxcl(upVec,velTemp).
				
				if vdot(velRotAxis,vcrs(hVelTemp,hTargeVec)) > 0 {
					set velTemp to angleaxis(velAngRot * timeIncrement,velRotAxis) * velTemp.
					
					//if this makes it turn too much, just set velTemp to the target vel (end the turn)
					if vdot(velRotAxis,vcrs(vxcl(upVec,velTemp),hTargeVec)) < 0 set velTemp to hTargeVec * velTemp:mag.
				}
				else set velTemp to hTargeVec * velTemp:mag.
			}
			
			local terrainPos is body:geopositionof(posTemp):position.
			if terrainVecs set vd_terrainlist[i]:start to terrainPos.
			set terrainPos to terrainPos + heightMarginVec.
			if terrainVecs set vd_terrainlist[i]:vec to terrainPos - vd_terrainlist[i]:start.
			local tempClimb is 90 - vang(upVec,terrainPos).
			
			if mode = m_land and submode = m_manual {
				if vdot(runwayVecNormalized,terrainPos-pos1) < -500 and tempClimb > terrainClimb set terrainClimb to tempClimb.
			}
			else if tempClimb > terrainClimb set terrainClimb to tempClimb.
		}
		if terrainClimb < lastTerrainClimb {
			if mode = m_land and submode = m_manual set terrainClimb to lastTerrainClimb * 0.99 + terrainClimb * 0.01.
			else set terrainClimb to lastTerrainClimb * 0.998 + terrainClimb * 0.002.
		}
		set lastTerrainClimb to terrainClimb.
		
		set targetPitch to max(targetPitch,terrainClimb).
	}
	
	// ### HEADING ###
	set stTarget to heading(targetHeading,targetPitch):vector.
	set vd_stTarget:vec to stTarget:normalized * 40.
	local hStTarget is vxcl(upVec,stTarget).
	
	//if updateCam faceCamTo(hStTarget). //update camera position if heading was manually changed
	
	local compassError is vang(hVel,hStTarget).
	
	
	
	//### pitch 
	set aoalimit to 15.
	set velPitch to vang(upVec, vel).
	set sp to max(velPitch - aoalimit,min(velPitch + aoalimit,vang(upVec,stTarget))).
	set pitchErr to velPitch - sp.
	
	if airspeed > stallSpeed * 0.7 or not(isLanded) {
		
		
		//set ppid:setpoint to max(-0.1,pitchErr / (40 + airspeed / 30)).
		set ppid:setpoint to pitchVelPid:update(time:seconds, -pitchErr) / (40 + airspeed / 30).
		set ship:control:pitch to ppid:update(time:seconds, -vdot(vxcl(up:vector,facing:starvector):normalized,ship:angularvel)).
	}
	else { set ship:control:pitch to ship:control:pitch * 0.99. pitchVelPid:reset(). }
	

	
	//### roll
	
	
	set angE to max(0,vang(vxcl(up:vector,stTarget),vxcl(up:vector, velocity:surface)) - 0) ^ 0.85.
	if vdot(vxcl(vel,facing:starvector),stTarget) < 0 set angE to -angE.
	
	if alt:radar < heightOffset * 2 + 6 set tr to 0.
	else set tr to min(maxBank,max(-maxBank,angE * bankMult)).
	
	if (pitchErr < -5) set tr to 0.
	
	set rollErr to tr - (vang(facing:starvector,upVec) - 90).
	set rpid:setpoint to (0.5*bankMult) * rollErr / (80 + airspeed / 20).
	set ship:control:roll to rpid:update(time:seconds, -vdot(shipfacing, ship:angularvel)).
	
	local rollVector is angleaxis(-tr,shipFacing) * vxcl(shipFacing,upVec).
	
	set vd_roll:vec to rollVector:normalized * 5.

	//### yaw
	if isLanded {
		set yawAngErr to min(30,vang(shipFacing , vxcl(facing:topvector,stTarget))).
		if vdot(facing:starvector,stTarget) < 0 set yawAngErr to -yawAngErr.
		
		set ypid:setpoint to yawVelPid:update(time:seconds, -yawAngErr) / (40 + airspeed / 30).
		set ship:control:yaw to ypid:update(time:seconds, -vdot(facing:topvector,ship:angularvel)).
	}
	else if abs(rollErr) < 5 and abs(tr) < 15 {
		//set yawAngErr to min(15,vang(vxcl(facing:topvector,vel) , vxcl(facing:topvector,stTarget))).
		//if vdot(vxcl(vel,facing:starvector),stTarget-vel) > 0 set yawAngErr to -yawAngErr.
		
		set yawAngErr to min(30,vang(shipFacing , vxcl(facing:topvector,stTarget))).
		if vdot(facing:starvector,stTarget) < 0 set yawAngErr to -yawAngErr.
		
		//set ypid:setpoint to  0.
		set ypid:setpoint to yawVelPid:update(time:seconds, -yawAngErr) / (40 + airspeed / 30).
		set ship:control:yaw to ypid:update(time:seconds, vdot(facing:topvector,ship:angularvel)).
	}
	else set ship:control:yaw to 0.
	
	//### wheelsteer
	if isLanded {
		//local wheelError is headingOf(facing:vector) - targetHeading .
		
		local wheelError is vang(vxcl(upVec,shipfacing),hStTarget).
		if vdot(facing:starvector,hStTarget) < 0 set wheelError to -wheelError.
		
		set wheelPid:kP to 0.015 / max(1,groundspeed/10).
		set wheelPid:kD to wheelPid:kP * (2/3).
		set ship:control:wheelsteer to wheelPid:update(time:seconds, wheelError).
		

		//set ship:control:wheelsteer to wheelError * 0.2 / max(10,groundspeed).
		if (forwardSpeed - targetSpeed) > 1 or targetSpeed = 0 brakes on.
		else brakes off.
		
		if forwardSpeed < 0 {
			set ship:control:wheelsteer to -ship:control:wheelsteer.
			brakes on.
		}
		
		if groundspeed < stallSpeed showVecs(false).
		else if showVecsVar showVecs(true).
		
		//if targetSpeed < 1 and groundspeed < 1 set st to lookdirup(shipfacing,facing:topvector).
	}
	else {
		if showVecsVar showVecs(true).
		set ship:control:wheelsteer to 0.
		
		if airbrakes {
			if (forwardSpeed - targetSpeed) > 10 brakes on.
			else brakes off.
		}
	}
	
	//### Throttle
	
	//simple pid version, no longer used
	//if ship:status = "landed" set th to throtPid:Update(time:seconds, forwardSpeed - targetSpeed).
	
	set speedError to forwardSpeed - targetSpeed.
	
	if brakes and speedError > 0 or targetSpeed = 0 set th to 0.
	else {
		
		if speedError > 1 and not(mode = m_land and submode = m_manual)  set wantedAcc to -speedError / 4.
		else set wantedAcc to -speedError / 2.
		
		set engineMaxAcc to ship:availablethrust / mass.
		set wantedThrot to (wantedAcc - dragFacingMag) / max(1,engineMaxAcc).
		set wantedThrust to wantedThrot * ship:availablethrust.
		
		set throtThingy to abs((thrustVec:mag - wantedThrust) / max(1,ship:availablethrust)).
		if throtThingy > 0.01 {
			//if wantedThrust > thrustVec:mag set th to 1.
			//else set th to 0.
			if wantedThrust > thrustVec:mag set th to wantedThrot + throtThingy^0.3.
			else set th to wantedThrot - throtThingy^0.7.
		}
		else set th to wantedThrot.
	}
	
	// Vecs >>
	set vd_vel:vec to vel:normalized * 40.
	//set vd_st:vec to stTarget * 40.
	set vd_facing:vec to shipfacing * 40.
	
	
	// <<
	
	set terminalCycle to terminalCycle + 1.
	if terminalCycle >= 5 { set terminalCycle to 0. refreshAll(). }
	
	set updateCam to false.
	wait 0.
} 
//end of main loop, below few lines are run when the user has selected exit in the menu
unlock throttle.
SET SHIP:CONTROL:NEUTRALIZE to TRUE.
clearvecdraws().

if (ship:status = "landed" or ship:status = "prelaunch" or ship:status = "splashed") and groundspeed < stallSpeed brakes on.
else sas on.

clearscreen.
print "Autopilot shutdown.".
reboot.
//end of program





//>> ### Functions

//called when changing the program mode
function setMode {
	parameter m.
	set mode to m.
	
	if (ship:status = "Landed" or ship:status = "splashed" or ship:status = "prelaunch") and not(mode = m_takeoff or mode = m_manual) {
		set nextmode to m.
		set nextrw to selectedRunway.
		when (alt:radar > 200) then {
			set selectedRunway to nextrw.
			setMode(nextmode).
		}
		
		set mode to m_takeoff.
	}
	
	if mode = m_takeoff {
		set submode to m_takeoff.
		set modeString to "take-off".
		findRunway().
		set runwayStart to selectedRunway[1].
		set runwayEnd to selectedRunway[2].
		
	}
	else if mode = m_land {
		if ship:status = "Landed" or ship:status = "splashed" {
			set submode to m_manual.
			set vd_pos:show to false.
		}
		else {
			set submode to m_circle.
			set vd_pos:show to true.
		}
		set modeString to "landing".
		

		set runwayStart to selectedRunway[1].
		set runwayEnd to selectedRunway[2].
		set runLandingSetup to true.
		set targetSpeed to max(targetSpeed,cruiseSpeed).
		set targetAlt to max(targetAlt,cruiseAlt).
	}
	else if mode = m_manual {
		set submode to m_manual.
		set modeString to "manual".
		set targetPitch to 0.
		set targetHeading to round(headingOf(ship:facing:vector),2).
		set vd_pos:show to false.
	}
	else if mode = m_circle {
		set submode to m_circle.
		set modeString to "circling".
		set circleLoc to ship:geoposition.
		set vd_pos:show to true.
	}
	else if mode = m_waypoints {
		set submode to m_circle.
		set modeString to "waypoints".
		set waypoints to list().
		set circleRadius to landingRadius.
		waypoints:add(body:geopositionof(vxcl(up:vector,ship:facing:vector):normalized * landingRadius * 2)).
		set wp_lat to round(waypoints[0]:lat,4).
		set wp_lng to round(waypoints[0]:lng,4).
		set controlAlt to true.
		set vd_pos:show to true.
		set vd_waypoint_active:show to true.
	}
	else if mode = m_follow {
		set submode to m_follow.
		set modeString to "follow".
		set vd_pos:show to false.
	}
}

//menu related functions
function createRunwaysMenues { //creates the menu list that will contain all of our created runways
	set runwaysMenu to list().
	set runwaysEditMenu to list().
	local i is 0.
	until i >= runways:length {
		local rw is runways[i].
		local rwI is i.
		if not rw[0]:contains("take-off") {
			runwaysMenu:add(list(rw[0],	"action" , 	{ set selectedRunway to rw. setMode(m_land). setMenu(mainMenu). })).
		}
		runwaysEditMenu:add(list(rw[0],	"action" , 	{ set editRunway to rw. set editRunwayI to rwI. BuildEditRunwayMenu(). set vd_runway_edit:show to true. setMenu(editRunwayMenu). })).
		set i to i + 1.
	}
	runwaysMenu:add(list("Land straight ahead",	"action" , 	{ set selectedRunway to list("temporary",ship:geoposition, body:geopositionof(vxcl(upVec,shipFacing) * 5000)). setMode(m_land). setMenu(mainMenu). })).
	runwaysMenu:add(list("-",				"line")).
	runwaysMenu:add(list("[<] MAIN MENU",		"backmenu", { return mainMenu. })).
	
	runwaysEditMenu:add(list("[+] New runway",			"action", 	{ runways:add(list("New runway",ship:geoposition,ship:geoposition)). set editRunwayI to i. BuildEditRunwayMenu(). set vd_runway_edit:show to true. setMenu(editRunwayMenu). })).
	runwaysEditMenu:add(list("-",						"line")).
	runwaysEditMenu:add(list("[Reload] all from JSON",	"action", 	{ loadRunways(). createRunwaysMenues(). setMenu(runwaysEditMenu). })).
	runwaysEditMenu:add(list("[Save] all to JSON",		"action", 	{ saveRunways(). setMenu(mainMenu). })).
	runwaysEditMenu:add(list("[<] MAIN MENU",			"backmenu", { return mainMenu. })).
}

function BuildEditRunwayMenu {
	set editRunwayMenu to list(
		list("Runway name:",		"string",	{ parameter p is sv. if p <> sv set runways[editRunwayI][0] to p. return runways[editRunwayI][0]. }),
		list("-",					"line"),
		list("Start Lat:",			"number", 	{ parameter p is sv. if p <> sv set runways[editRunwayI][1] to latlng(min(90,max(-90,round(p,5))),runways[editRunwayI][1]:lng). return round(runways[editRunwayI][1]:lat,5). }, 0.01),
		list("Start Lng:",			"number", 	{ parameter p is sv. if p <> sv set runways[editRunwayI][1] to latlng(runways[editRunwayI][1]:lat,min(180,max(-180,round(p,5)))). return round(runways[editRunwayI][1]:lng,5). }, 0.01),
		list("",					"text"),
		list("End Lat:",			"number", 	{ parameter p is sv. if p <> sv set runways[editRunwayI][2] to latlng(min(90,max(-90,round(p,5))),runways[editRunwayI][2]:lng). return round(runways[editRunwayI][2]:lat,5). }, 0.01),
		list("End Lng:",			"number", 	{ parameter p is sv. if p <> sv set runways[editRunwayI][2] to latlng(runways[editRunwayI][2]:lat,min(180,max(-180,round(p,5)))). return round(runways[editRunwayI][2]:lng,5). }, 0.01),
		list("",					"text"),
		list("Length",				"display",	{ return round((runways[editRunwayI][2]:position - runways[editRunwayI][1]:position):mag). }),
		list("Inclination",			"display",	{ return round(90 - vang(runways[editRunwayI][1]:position - body:position, runways[editRunwayI][2]:position - runways[editRunwayI][1]:position),4). }),
		list("=",					"line"),
		list("[+] Add Taxi WP",		"action",	{ runways[editRunwayI]:add(runways[editRunwayI][runways[editRunwayI]:length-1]). BuildEditRunwayMenu(). setMenu(editRunwayMenu). }),
		list("[X] Delete Runway", 	"action",	{ remove_waypoint_vecdraws(). runways:remove(editRunwayI). createRunwaysMenues(). setMenu(runwaysEditMenu). set vd_runway_edit:show to false. set vd_runway_normal:show to false. }),
		list("[<] Done", 			"action",	{ createRunwaysMenues(). setMenu(runwaysEditMenu). set vd_runway_edit:show to false. set vd_runway_normal:show to false. remove_waypoint_vecdraws(). })
	).
	
	set runway_normal_check to 0.
	remove_waypoint_vecdraws().
	
	for wp in range(3,runways[editRunwayI]:length,1) {
		local i is wp.
		if wp = 3 editRunwayMenu:insert(editRunwayMenu:length - 4, list("-", "line")).
		else editRunwayMenu:insert(editRunwayMenu:length - 4, list("", "text")).
		editRunwayMenu:insert(editRunwayMenu:length - 4, list("Waypoint " + (i - 2) + " [Remove]","action",	{ runways[editRunwayI]:remove(i). BuildEditRunwayMenu(). setMenu(editRunwayMenu). })).
		editRunwayMenu:insert(editRunwayMenu:length - 4, list("Latitude:", "number", { parameter p is sv. if p <> sv set runways[editRunwayI][i] to latlng(min(90,max(-90,round(p,5))),runways[editRunwayI][i]:lng). return round(runways[editRunwayI][i]:lat,5). }, 0.001)).
		editRunwayMenu:insert(editRunwayMenu:length - 4, list("Longitude:",	"number", 	{ parameter p is sv. if p <> sv set runways[editRunwayI][i] to latlng(runways[editRunwayI][i]:lat,min(180,max(-180,round(p,5)))). return round(runways[editRunwayI][i]:lng,5). }, 0.001)).
	
		vd_waypoint_list:add(vecdraw(v(0,0,0),v(0,0,0),green,(i-2):tostring(),1,false,0.5)).
	}
}
function remove_waypoint_vecdraws {
	for i in range(0,vd_waypoint_list:length,1) {
		set vd_waypoint_list[i]:show to false.
	}
	set vd_waypoint_list to list().
}
function createTargetsMenu {
	set followMenu to list().
	list targets in tgts.
	local followTargets is list().
	for t in tgts {
		if t:distance < 500000 followTargets:add(t).
	}
	set targetsMenu to list().
	local i is 0.
	until i >= followTargets:length {
		local t is followTargets[i].
		followMenu:add(list(t:name,	"action" , 	{ set followTarget to t. setMode(m_follow). setMenu(mainMenu). })).
		set i to i + 1.
	}
	followMenu:add(list("-",				"line")).
	followMenu:add(list("[<] MAIN MENU",		"backmenu", { return mainMenu. })).
}

//utility functions

function headingOf {
	parameter vect. //0 = north, 90 = east
	local ang is vang( vxcl(upVec,vect) , north:vector ).
	if vdot(heading(270,0):vector,vect) > 0 set ang to 360 - ang.
	return ang.
}
function getBank { //thank you dunbaratu for letting me steal this one. 
	local raw is vang(upVec, - facing:starvector).
	if vang(upVec, facing:topvector) > 90 {
		if raw > 90 return raw - 270.
		else return raw + 90.
	} else {
		return 90 - raw.
	}
}

function findRunway {
	local lowestDist is 10000.
	for runway in runways {
		if runway[1]:position:mag < lowestDist and not(runway[0]:contains("landing")) {
			set lowestDist to runway[1]:position:mag.
			set selectedRunway to runway.
		}
	}
	
	local createTemp is true.
	if lowestDist <> 10000 {
		local runwayVec is selectedRunway[2]:position - selectedRunway[1]:position.
		
		local side_dist is vdot(vcrs(runwayVec,upVec):normalized, selectedRunway[1]:position).
		if abs(side_dist) < 2500 {
			
			set createTemp to false.
		}
	}
	if createTemp {
		set selectedRunway to list("temporary", ship:geoposition, body:geopositionof(vxcl(upVec,shipFacing) * 5000)).
	}
}

function geo_normalvector {
	parameter geopos,size_.
	local center is geopos:position.
	local fwd is vxcl(center-body:position,body:angularvel):normalized.
	local right is vcrs(fwd,center-body:position):normalized.
	local p1 is body:geopositionof(center + fwd * size_ + right * size_).
	local p2 is body:geopositionof(center + fwd * size_ - right * size_).
	local p3 is body:geopositionof(center - fwd * size_).
	
	local vec1 is p1:position-p3:position.
	local vec2 is p2:position-p3:position.
	return vcrs(vec1,vec2):normalized.
}

function getTotalThrust {
	list engines in engs.
	local t is 0.
	for eng in engs {
		set t to t + eng:thrust.
	}
	return t.
}

function showVecs {
	parameter b.
	
	if vd_vel:show and not(b) {
		set vd_vel:show to false.
		//set vd_st:show to false.
		set vd_facing:show to false.
		set vd_roll:show to false.
		if not(showVecsVar) set vd_stTarget:show to false.
	}
	else if not(vd_vel:show) and b {
		set vd_vel:show to true.
		//set vd_st:show to true.
		set vd_facing:show to true.
		set vd_roll:show to true.
		set vd_stTarget:show to true.
	}
}

function updateRunwayPos {
	if runwayStart:terrainheight < 0 { 
		set pos1 to runwayStart:altitudeposition(heightOffset).
		set runwayWater to true.
	}
	else {
		set pos1 to runwayStart:position + heightOffsetVec.
		set runwayWater to false.
	}
	set pos1dist to vxcl(upVec,pos1):mag.
	
	if runwayEnd:terrainheight < 0 set pos2 to runwayEnd:altitudeposition(heightOffset).
	else set pos2 to runwayEnd:position + heightOffsetVec.
	set runwayVec to pos2-pos1.
	set runwayVecNormalized to runwayVec:normalized.
}

//saving and loading functions for vessel and steeringmanager
function saveSettings {
	local lex is lexicon(
		"stallSpeed", stallSpeed,
		"maxBankSpeed",maxBankSpeed,
		"bankMult",bankMult,
		"maxBank",maxBank,
		"landingRadius",landingRadius,
		"heightOffset",heightOffset,
		"descentAngle",descentAngle,
		"maxClimbAngle",maxClimbAngle,
		"airbrakes",airbrakes,
		"cruiseSpeed",cruiseSpeed,
		"cruiseAlt",cruiseAlt,
		
		"ppid-kp",ppid:kp,
		"ppid-ki",ppid:ki,
		"ppid-kd",ppid:kd,
		
		"rpid-kp",rpid:kp,
		"rpid-ki",rpid:ki,
		"rpid-kd",rpid:kd
	).
	
	local filePath is path("0:/json/" + ship:name + "/autopilot.json").
	writejson(lex, filePath).
}

function loadSettings {
	local filePath is path("0:/json/" + ship:name + "/autopilot.json").
	
	if exists(filePath) {
		local lex is readjson(filePath).
		
		if lex:haskey("stallSpeed") set stallSpeed to lex["stallSpeed"].
		if lex:haskey("maxBankSpeed") set maxBankSpeed to lex["maxBankSpeed"].
		if lex:haskey("bankMult") set bankMult to lex["bankMult"].
		if lex:haskey("maxBank") set maxBank to lex["maxBank"].
		if lex:haskey("landingRadius") set landingRadius to lex["landingRadius"].
		if lex:haskey("heightOffset") set heightOffset to lex["heightOffset"].
		if lex:haskey("descentAngle") set descentAngle to lex["descentAngle"].
		if lex:haskey("maxClimbAngle") set maxClimbAngle to lex["maxClimbAngle"].
		if lex:haskey("airbrakes") set airbrakes to lex["airbrakes"].
		if lex:haskey("cruiseSpeed") set cruiseSpeed to lex["cruiseSpeed"].
		if lex:haskey("cruiseAlt") set cruiseAlt to lex["cruiseAlt"].
		
		if lex:haskey("ppid-kp") set ppid:kp to lex["ppid-kp"].
		if lex:haskey("ppid-ki") set ppid:ki to lex["ppid-ki"].
		if lex:haskey("ppid-kd") set ppid:kd to lex["ppid-kd"].
		if lex:haskey("rpid-kp") set rpid:kp to lex["rpid-kp"].
		if lex:haskey("rpid-ki") set rpid:ki to lex["rpid-ki"].
		if lex:haskey("rpid-kd") set rpid:kd to lex["rpid-kd"].
		
		HUDTEXT("Loaded vessel settings from " + filePath,15,2,18,cyan,false).
		return true.
	}
	else return false.
}



//### Load/save runways, need to wait for issue #2105 to be fixed before it can be used:
//function saveRunways {
//	local filePath is path("json/runways/" + body:name + ".json").
//	writejson(runways, filePath).
//}
//
//function loadRunways {
//	local filePath is path("json/runways/" + body:name + ".json").
//	
//	if exists(filePath) {
//		set runways to readjson(filePath).
//		return true.
//	}
//	else return false.
//}

//load and save workaround, since loading geocoordinates from jsons is currently bugged:
function saveRunways {
	local filePath is path("0:/json/runways/" + body:name + ".json").
	local runwaysConverted is list().
	
	for rw in runways {
		local rwTemp is list().
		rwTemp:add(rw[0]). //name string
		
		//convert each geocoordinate item to a pair of lat and lng numbers and store those in the runway list instead.
		for i in range(1,rw:length,1) {
			rwTemp:add(rw[i]:lat).
			rwTemp:add(rw[i]:lng).
		}
		runwaysConverted:add(rwTemp).
	}
	writejson(runwaysConverted, filePath).
	HUDTEXT("Saved " + runways:length + " runways to " + filePath,21,1,25,yellow,false).
}

function loadRunways {
	local filePath is path("0:/json/runways/" + body:name + ".json").
	
	if exists(filePath) {
		set runwaysConverted to readjson(filePath).
		set runways to list().
		
		for rwTemp in runwaysConverted {
			local rw is list().
			rw:add(rwTemp[0]). //name string
			
			for i in range(1,rwTemp:length-1,2) { //starting at index 1, increment by 2 (to get lat-lng pairs)
				rw:add(latlng(rwTemp[i],rwTemp[i+1])).
			}
			runways:add(rw).
		}
		if runways:length > 0 {
			HUDTEXT("Loaded " + runways:length + " runways from " + filePath,15,1,18,green,false).
			return true.
		}
		else { 
			HUDTEXT(filePath + " found, but contains no runways!",20,1,18,red,true).
			return false.
		}
	}
	else {
		HUDTEXT("No runways loaded, " + filePath + " does not exist",20,1,18,red,true).
		return false.
	}
}