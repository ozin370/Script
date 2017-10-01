@LAZYGLOBAL on.
// ### AP.ks - autopilot ###
set config:ipu to max(config:ipu,2000).

// autopilot
runoncepath("lib_UI.ks").
runoncepath("steeringmanager.ksm").
//set steeringmanager:yawpid:ki to 0.
//set steeringmanager:yawpid:kp to 5.
loadSteering().

sas off.
set st to lookdirup(ship:facing:vector,up:vector).
lock steering to st.
set th to throttle.
lock throttle to th.
//local cam is addons:camera:flightcamera.

// #### PID ###
// >>
	
	set maxBank to 50.
	function init_bank_pid {
	  return PIDLOOP(3, 0.00, 3, -maxBank, maxBank).
	}
	set bankPid to init_bank_pid().
	set bankHardPid to PIDLOOP(0.2, 0.01, 0.4, -90, 90).

	set attackPid to PIDLOOP(3, 0.0, 3, -10, 10). //old: PIDLOOP(3, 0.0, 10, -10, 10).
	set pitchPid to PIDLOOP(3.0, 0.2, 3.0, -10, 10). //(3.0, 0.3, 2.0, -15, 15). //outputs extra climb angle to get the velocity climb angle corrected
	
	
	// set rollPid to init_roll_pid().
	set throtPid to PIDLOOP(0.1, 0.011, 0.15, 0, 1).
	
	set climbPid to PIDLOOP(0.4, 0.0, 0.05, -30, 35).
	set circlePid to PIDLOOP(0.000, 0.000, 0.05, 0, 1).
	
	set wheelPid to PIDLOOP(0.15, 0.000, 0.1, -1, 1).
	
	set steeringmanager:rollcontrolanglerange to 180. //force steeringmanager not to ignore roll
// << 

// ### Initual Stuff / default vars ###
// >>
	
	local m_land is 1.
	local m_takeoff is 2.
	local m_manual is 3.
	local m_cruise is 4.
	local m_circle is 5.
	local m_taxi is 6.
	
	local mode is m_manual.
	local submode is m_manual.
	
	local modeString is "manual".
	local upVec is up:vector.
	
	local targetSpeed is round(airspeed).
	local targetAlt is round(altitude).
	local controlSpeed is true.
	local controlAlt is false.
	
	
	
	local targetHeading is round(headingOf(ship:facing:vector),2).
	local targetPitch is 0.
	if airspeed > 10 and ship:status = "Flying" {
		set targetPitch to 90 - vang(upVec,velocity:surface).
	}
	local circleRadius is 2000.
	
	//settings default vars
	local stallSpeed is 60.
	local maxBankSpeed is 100.
	local aoaHigh is 8. //high speeds
	local aoaLow is 15. //at low speeds
	local bankFactor is 0.7.
	local bankHard is false.
	local updateCam is false.
	local clockwise is true.
	local landingRadius is 1600.
	local heightOffset is 3.
	local descentAngle is 5.
	local maxClimbAngle is 20.
	if ship:status = "Landed" or ship:status = "PRELAUNCH" set heightOffset to round(alt:radar,2).
	
	local vd_stTarget is vecs_add(v(0,0,0),v(0,0,0),green,"",0.2).
	local vd_st is vecs_add(v(0,0,0),v(0,0,0),magenta,"",0.2).
	local vd_facing is vecs_add(v(0,0,0),v(0,0,0),rgba(1,0,1,0.2),"",0.2).
	local vd_vel is vecs_add(v(0,0,0),velocity:surface,yellow,"",0.2).
	local vd_roll is vecs_add(v(0,0,0),v(0,0,0),cyan,"",0.2).
	
	local vd_pos is vecs_add(v(0,0,0),up:vector * 1000,yellow,"",10).
	set vecs[vd_pos]:show to false.
	
	function saveSettings {
		local lex is lexicon(
			"stallSpeed", stallSpeed,
			"maxBankSpeed",maxBankSpeed,
			"bankFactor",bankFactor,
			"maxBank",maxBank,
			"landingRadius",landingRadius,
			"heightOffset",heightOffset,
			"descentAngle",descentAngle,
			"maxClimbAngle",maxClimbAngle
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
			if lex:haskey("bankFactor") set bankFactor to lex["bankFactor"].
			if lex:haskey("maxBank") set maxBank to lex["maxBank"].
			if lex:haskey("landingRadius") set landingRadius to lex["landingRadius"].
			if lex:haskey("heightOffset") set heightOffset to lex["heightOffset"].
			if lex:haskey("descentAngle") set descentAngle to lex["descentAngle"].
			if lex:haskey("maxClimbAngle") set maxClimbAngle to lex["maxClimbAngle"].
			return true.
		}
		else return false.
	}
	
	loadSettings().
	
	
	local runways is list().
	runways:add(list("KSC E->W", 
		LATLNG(-0.0502131096942382, -74.4951289901873), LATLNG(-0.0486697432694389, -74.7220377114077), // <- the first two geolocations in the list make up the runway. The plane will land close to the first one facing the second, and will take off facing the same way as well.
		LATLNG(-0.0633901920593838,-74.6177340872895), LATLNG(-0.0667142201078598,-74.6245921697804),LATLNG(-0.0574241046721476,-74.6304580442504))). // <- taxi/parking waypoints. as many waypoints as you want, the last one being the parking spot
	runways:add(list("KSC W->E", 
		LATLNG(-0.0486697432694389, -74.7220377114077), LATLNG(-0.0502131096942382, -74.4951289901873),
		LATLNG(-0.0633901920593838,-74.6177340872895), LATLNG(-0.0667142201078598,-74.6245921697804),LATLNG(-0.0574241046721476,-74.6304580442504))).
	runways:add(list("Island W->E", 
		LATLNG(-1.51806713434498,-71.9686515236803), LATLNG(-1.51566431260178,-71.8513882426904),
		LATLNG(-1.52246003880166,-71.8951322255196), LATLNG(-1.52238917854372,-71.9029429161532))).
	runways:add(list("Island E->W", 
		LATLNG(-1.51566431260178,-71.8513882426904), LATLNG(-1.51806713434498,-71.9686515236803),
		LATLNG(-1.52246003880166,-71.8951322255196), LATLNG(-1.52238917854372,-71.9029429161532))).
	runways:add(list("Island Roof", 
		LATLNG(-1.84067446835453,-71.9819052653066), LATLNG(-1.76179578429485,-71.9823239609914))).
	runways:add(list("Field", 
		LATLNG(0.17358481490647,-74.9642214448504), LATLNG(0.232681172753888,-75.0955666284595))).
	runways:add(list("Inclined", 
		LATLNG(-0.7378812868294,-74.8004934841927), LATLNG(-0.628744824988205,-74.8807989589523))).
	runways:add(list("Mountain of Death", 
		LATLNG(0.501210374567098,-79.0620192967054), LATLNG(0.551044874260144,-79.1124370941125))).
	runways:add(list("Death Peak", 
		LATLNG(0.638609133472562,-79.3483162306698), LATLNG(0.677100551194089,-79.341714788505))).
	//non-stock runways
	//runways:add(list("Lake Landing", 
	//	LATLNG(11.1338539818121,-63.4266075453381), LATLNG(11.2797121236681,-63.5267638608701),
	//	LATLNG(11.2601379963262,-63.5049064266831), LATLNG(11.2564222580563,-63.502449653876),LATLNG(11.2543177537943,-63.505745748003))).
	//runways:add(list("Lake Take-off", 
	//	LATLNG(11.2797121236681,-63.5267638608701), LATLNG(11.1338539818121,-63.4266075453381))).
	//runways:add(list("Black Crags", 
	//	LATLNG(11.322420652578,-87.6872216129112), LATLNG(11.2554615165241,-87.6959890407062))).
	//runways:add(list("NP Landing", 
	//	LATLNG(79.4471941169014,-77.5627323048577), LATLNG(79.5755083506188,-77.4062036132134),
	//	LATLNG(79.5753842582846,-77.4291734065947), LATLNG(79.5749734051539,-77.4497455022557))).
	//runways:add(list("NP Take-off", 
	//	LATLNG(79.5755083506188,-77.4062036132134), LATLNG(79.4471941169014,-77.5627323048577))).
	
	local runwayIndex is 0.
	local selectedRunway is runways[runwayIndex].
	
// <<

// ### Console ###
// >>



set terminal:brightness to 1.
set terminal:width to 45.
set terminal:height to 36.
clearscreen.


// use the first two of these varables to set the position of the menu. The last two affect the width of the menu.
local startLine is 1.		//the first menu item will start at this line in the terminal window
local startColumn is 4.		//menu item description starts at this x coordinate, remember to leave some space for the marker on the left
local nameLength is 21.		//how many characters of the menu item names to display
local valueLength is 12.	//how many characters of the menu item values to display
local sv is -9.9993134. 	// just a value that is extremely unlikely to be set to any of the varibles we want to change with the menu

local runwaysMenu is list().
local i is 0.
until i >= runways:length {
	local rw is runways[i].
	if not rw[0]:contains("take-off") {
		runwaysMenu:add(list(rw[0],	"action" , 	{ set selectedRunway to rw. setMode(m_land). setMenu(mainMenu). })).
	}
	set i to i + 1.
}
runwaysMenu:add(list("-",				"line")).
runwaysMenu:add(list("[<] MAIN MENU",		"backmenu", { return mainMenu. })).

set mainMenu to list(
	//list("Modes",		"text"),
	list("[>] MODES",		"menu" , 	{ return modesMenu. }),
	list("",				"text"),
	list("Mode:",			"display",	{ return modeString. }),
	list("Runway:",			"display",	{ return selectedRunway[0]. }),
	list("-",				"line"),
	list("Speed:",			"number", 	{ parameter p is sv. if p <> sv set targetSpeed to max(0,round(p)). return round(targetSpeed). }, 10),
	list("",				"text"),
	list("Heading:",		"number", 	{ parameter p is sv. if p <> sv {
											if p > 360 set p to p - 360. 
											else if p < 0 set p to 360 + p.
											set targetHeading to p.
											set updateCam to true.
										} 
										return round(targetHeading,2). }, 1),
	list("-",				"line"),
	list("Climb angle:",	"number", 	{ parameter p is sv. if p <> sv set targetPitch to max(-90,min(90,p)). return round(targetPitch,2). }, 1),
	list("",				"text"),
	list("Altitude control:","bool", 	{ parameter p is sv. if p <> sv set controlAlt to boolConvert(p). return controlAlt. }),
	list("Altitude target:","number", { parameter p is sv. if p <> sv set targetAlt to max(0,round(p,1)). return round(targetAlt,1). }, 10),
	
	//list("Bank Hard:",	"bool", 	{ parameter p is sv. if p <> sv set bankHard to boolConvert(p). return bankHard. }),
	
	list("-",			"line"),
	list("[>] STEERINGMANAGER",	"menu" , 	{ return steeringMenu. }),
	list("[>] VESSEL SETTINGS",	"menu" , 	{ return settingsMenu. }),
	list("[X] Exit", 			"action", { set done to true. })
).

function setMode {
	parameter m.
	set mode to m.
	
	if mode = m_land {
		if ship:status = "Landed" {
			set submode to m_manual.
			set vecs[vd_pos]:show to false.
		}
		else {
			set submode to m_circle.
			set vecs[vd_pos]:show to true.
		}
		set modeString to "landing".
		

		set runwayStart to selectedRunway[1].
		set runwayEnd to selectedRunway[2].
		set runLandingSetup to true.
	}
	else if mode = m_manual {
		set submode to m_manual.
		set modeString to "manual".
		set targetPitch to 0.
		set targetHeading to round(headingOf(ship:facing:vector),2).
		set vecs[vd_pos]:show to false.
	}
	else if mode = m_takeoff {
		set submode to m_takeoff.
		set modeString to "take-off".
		findRunway().
	}
	else if mode = m_circle {
		set submode to m_circle.
		set modeString to "circling".
		set circleLoc to ship:geoposition.
		set vecs[vd_pos]:show to true.
	}
}


set modesMenu to list(
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
	list("-",				"line"),
	list("[<] MAIN MENU",		"backmenu", { return mainMenu. })
).

set circleModeMenu to list(
	list("Circle Radius:",	"number", 	{ parameter p is sv. if p <> sv set circleRadius to max(100,round(p)). return circleRadius. }, 100),
	list("Clock-wise:",		"bool", 	{ parameter p is sv. if p <> sv set clockwise to boolConvert(p). return clockwise. }),
	list("-",				"line"),
	list("[<] MAIN MENU",		"backmenu", { return mainMenu. })
).


set steeringMenu to list(
	list("[>] Angular Velocity PID",	"menu", { return pidMenu. }),
	list("-",						"line"),
	list("Pitch settling time:",	"number", { parameter p is sv. if p <> sv set steeringmanager:pitchts to max(0.01,round(p,2)). return steeringmanager:pitchts. }, 0.1),
	list("Yaw settling time:",		"number", { parameter p is sv. if p <> sv set steeringmanager:yawts to max(0.01,round(p,2)). return steeringmanager:yawts. }, 0.1),
	list("Roll settling time:",		"number", { parameter p is sv. if p <> sv set steeringmanager:rollts to max(0.01,round(p,2)). return steeringmanager:rollts. }, 0.1),
	list("",						"text"),
	list("Max stopping time:",		"number", { parameter p is sv. if p <> sv set steeringmanager:maxstoppingtime to max(0.01,round(p,2)). return steeringmanager:maxstoppingtime. }, 0.1),
	list("Roll ctrl ang range:",	"number", { parameter p is sv. if p <> sv set steeringmanager:rollcontrolanglerange to round(p,2). return steeringmanager:rollcontrolanglerange. }, 1),
	list("",						"text"),
	list("Angle error:",			"display", { return round(steeringmanager:angleerror,2). }),
	list("Pitch error:",			"display", { return round(steeringmanager:pitcherror,2). }),
	list("Yaw error:",				"display", { return round(steeringmanager:yawerror,2). }),
	list("Roll error:",				"display", { return round(steeringmanager:rollerror,2). }),
	list("-",						"line"),
	list("Pitch torq adjust:",		"number", { parameter p is sv. if p <> sv set steeringmanager:pitchtorqueadjust to round(p,2). return steeringmanager:pitchtorqueadjust. }, 1),
	list("Pitch torq factor:",		"number", { parameter p is sv. if p <> sv set steeringmanager:pitchtorquefactor to max(0.01,round(p,2)). return steeringmanager:pitchtorquefactor. }, 0.1),
	list("",						"text"),
	list("Yaw torq adjust:",		"number", { parameter p is sv. if p <> sv set steeringmanager:yawtorqueadjust to round(p,2). return steeringmanager:yawtorqueadjust. }, 1),
	list("Yaw torq factor:",		"number", { parameter p is sv. if p <> sv set steeringmanager:yawtorquefactor to max(0.01,round(p,2)). return steeringmanager:yawtorquefactor. }, 0.01),
	list("",						"text"),
	list("Roll torq adjust:",		"number", { parameter p is sv. if p <> sv set steeringmanager:rolltorqueadjust to round(p,2). return steeringmanager:rolltorqueadjust. }, 1),
	list("Roll torq factor:",		"number",	{ parameter p is sv. if p <> sv set steeringmanager:rolltorquefactor to max(0.01,round(p,2)). return steeringmanager:rolltorquefactor. }, 0.01),
	list("-",						"line"),
	list("Facing vecs:",			"bool", { parameter p is sv. if p <> sv set steeringmanager:showfacingvectors to boolConvert(p). return steeringmanager:showfacingvectors. }),
	list("Angular vecs:",			"bool", { parameter p is sv. if p <> sv set steeringmanager:showangularvectors to boolConvert(p). return steeringmanager:showangularvectors. }),
	list("Write CSV files:",		"bool", { parameter p is sv. if p <> sv set steeringmanager:writecsvfiles to boolConvert(p). return steeringmanager:writecsvfiles. }),
	list("-",						"line"),
	list("[ ] REVERT CHANGES", 		"action", { loadSteering(). }),
	list("", 						"text"),
	list("[ ] SAVE CHANGES", 		"action", { saveSteering(). }),
	list("[<] MAIN MENU",			"backmenu", { return mainMenu. })
).

set pidMenu to list(
	list("Pitch kP:", "number", { parameter p is sv. if p <> sv set steeringmanager:pitchpid:kp to max(0,round(p,3)). return steeringmanager:pitchpid:kp. }, 0.1),
	list("Pitch kI:", "number", { parameter p is sv. if p <> sv set steeringmanager:pitchpid:ki to max(0,round(p,3)). return steeringmanager:pitchpid:ki. }, 0.1),
	list("Pitch kD:", "number", { parameter p is sv. if p <> sv set steeringmanager:pitchpid:kd to max(0,round(p,3)). return steeringmanager:pitchpid:kd. }, 0.1),
	list("Setpoint:", "display", { return round(steeringmanager:pitchpid:setpoint,2). }, 1),
	list("Error:", "display", { return round(steeringmanager:pitchpid:error,2). }, 1),
	list("Output:", "display", { return round(steeringmanager:pitchpid:output,2). }, 1),
	list("-", "line"),
	list("Yaw kP:", "number", { parameter p is sv. if p <> sv set steeringmanager:yawpid:kp to max(0,round(p,3)). return steeringmanager:yawpid:kp. }, 0.1),
	list("Yaw kI:", "number", { parameter p is sv. if p <> sv set steeringmanager:yawpid:ki to max(0,round(p,3)). return steeringmanager:yawpid:ki. }, 0.1),
	list("Yaw kD:", "number", { parameter p is sv. if p <> sv set steeringmanager:yawpid:kd to max(0,round(p,3)). return steeringmanager:yawpid:kd. }, 0.1),
	list("Setpoint:", "display", { return round(steeringmanager:yawpid:setpoint,2). }, 1),
	list("Error:", "display", { return round(steeringmanager:yawpid:error,2). }, 1),
	list("Output:", "display", { return round(steeringmanager:yawpid:output,2). }, 1),
	list("-", "line"),
	list("Roll kP:", "number", { parameter p is sv. if p <> sv set steeringmanager:rollpid:kp to max(0,round(p,3)). return steeringmanager:rollpid:kp. }, 0.1),
	list("Roll kI:", "number", { parameter p is sv. if p <> sv set steeringmanager:rollpid:ki to max(0,round(p,3)). return steeringmanager:rollpid:ki. }, 0.1),
	list("Roll kD:", "number", { parameter p is sv. if p <> sv set steeringmanager:rollpid:kd to max(0,round(p,3)). return steeringmanager:rollpid:kd. }, 0.1),
	list("Setpoint:", "display", { return round(steeringmanager:rollpid:setpoint,2). }, 1),
	list("Error:", "display", { return round(steeringmanager:rollpid:error,2). }, 1),
	list("Output:", "display", { return round(steeringmanager:rollpid:output,2). }, 1),
	list("-", "line"),
	list("[ ] Reset PIDs", "action", { steeringmanager:resetpids(). }),
	list("[ ] REVERT CHANGES", "action", { loadSteering(). }),
	list("", "text"),
	list("[ ] SAVE CHANGES", "action", { saveSteering(). }),
	list("[<] BACK",		"backmenu", { return steeringMenu. })
).

set settingsMenu to list(
	//list(name,type,get/set function,increment multiplier (for numbers)).

	list("Stall Spd:",		"number", 	{ parameter p is sv. if p <> sv set stallSpeed to max(5,round(p)). return stallSpeed. }, 1),
	list("Max Climb Angle:","number", 	{ parameter p is sv. if p <> sv set maxClimbAngle to max(5,round(p,1)). return maxClimbAngle. }, 0.1),
	list("",				"text"),
	list("Bank limit:",		"number", 	{ parameter p is sv. if p <> sv { set maxBank to max(10,round(p)). set bankPid to init_bank_pid(). } return maxBank. }, 10),
	list("Bank Factor:",	"number", 	{ parameter p is sv. if p <> sv set bankFactor to max(0.1,round(p,2)). return bankFactor. }, 0.1),
	list("Full Bank Spd:",	"number", 	{ parameter p is sv. if p <> sv set maxBankSpeed to max(stallSpeed + 10,round(p)). return maxBankSpeed. }, 10),
	list("",				"text"),
	list("Landing:",		"text"),
	list("Turn radius:",	"number", 	{ parameter p is sv. if p <> sv set landingRadius to max(500,round(p)). return landingRadius. }, 100),
	list("Descent angle:",	"number", 	{ parameter p is sv. if p <> sv set descentAngle to max(3,round(p,1)). return descentAngle. }, 1),
	list("",				"text"),
	list("Height offset:",	"number", 	{ parameter p is sv. if p <> sv set heightOffset to max(0.1,round(p,2)). return heightOffset. }, 0.1),
	
	
	list("-",				"line"),
	list("[ ] SAVE CHANGES","action", 	{ saveSettings(). }),
	list("[<] MAIN MENU",	"backmenu", { return mainMenu. })
).

// the list that defines the menu items: their names, types, and function
set activeMenu to mainMenu.
runpath("lib_menu.ksm").

// <<

function headingOf {
	parameter vect. //0 = north, 90 = east
	local ang is vang( vxcl(up:vector,vect) , north:vector ).
	if vdot(heading(270,0):vector,vect) > 0 set ang to 360 - ang.
	return ang.
}
function getBank { //thank you dunbaratu for letting me steal this one. 
	local raw is vang(up:vector, - facing:starvector).
	if vang(up:vector, facing:topvector) > 90 {
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
	
	if lowestDist = 10000 {	//found no closeby runway
		setMode(m_manual).
	}
	else {
		local runwayVec is selectedRunway[2]:position - selectedRunway[1]:position.
		
		local side_dist is vdot(vcrs(runwayVec,upVec):normalized, selectedRunway[1]:position).
		if abs(side_dist) > 500 {
			setMode(m_manual).
		}
	}
}

// >> ### Camera ###
//function faceCamTo {
//	parameter horizontalVec.
//	
//	//uncomment if camera addon is installed
//	set cam:position to angleaxis(cam:pitch,vcrs(up:vector,horizontalVec)) * -horizontalVec:normalized * cam:distance.
//}
// <<

function showVecs {
	parameter b.
	
	if vecs[vd_vel]:show and not(b) {
		set vecs[vd_vel]:show to false.
		set vecs[vd_st]:show to false.
		set vecs[vd_facing]:show to false.
		set vecs[vd_roll]:show to false.
	}
	else if not(vecs[vd_vel]:show) and b {
		set vecs[vd_vel]:show to true.
		set vecs[vd_st]:show to true.
		set vecs[vd_facing]:show to true.
		set vecs[vd_roll]:show to true.
	}
}

set tarVessel to ship.
local done is false.
drawAll(). wait 0.
// ### LOOP ###
until done {
	inputs().
	
	if not(gear) and mode = m_land and submode = m_manual {
		gear on.
	}
	else if gear and alt:radar > 50 and mode <> m_land {
		gear off.
	}
	
	local shipfacing is ship:facing:vector.
	local vel is velocity:surface.
	set forwardSpeed to vdot(shipfacing,vel).
	set th to throtPid:Update(time:seconds, forwardSpeed - targetSpeed).
	
	
	set upVec to up:vector.
	local hVel is vxcl(upVec,vel).
	set heightOffsetVec to upVec * heightOffset.
	//local hFacing is vxcl(up:vector,ship:facing:vector).
	
	//local shipHeading is headingOf(hVel).
	
	if mode = m_takeoff {
		set controlAlt to false.
		local pos1 is selectedRunway[1]:position + heightOffsetVec.
		local pos1dist is vxcl(upVec,pos1):mag.
		local pos2 is selectedRunway[2]:position + heightOffsetVec.
		local runwayVec is vxcl(upVec,pos2-pos1).
		local runwayVecNormalized is runwayVec:normalized.
		local side_dist is abs(vdot(vcrs(runwayVec,upVec):normalized, selectedRunway[1]:position)).
		
		local offset is vdot(-runwayVecNormalized,pos1).
		local aimPosHeading is pos1 + runwayVecNormalized * (offset + max(0,groundspeed * 5 - side_dist/4)).
		
		
		set targetHeading to headingOf(aimPosHeading).
		set targetSpeed to 6.
		
		if (vang(vxcl(upVec,runwayVec),vxcl(upVec,shipfacing)) < 6 and side_dist < 15) or ship:status = "Flying" set targetSpeed to maxBankSpeed + 20.
		
		set targetPitch to max(0,min(maxClimbAngle,(forwardSpeed - stallSpeed) * 0.5)).
		
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
			
			set vecs[vd_pos]:show to true.
		}
		
	}
	else if mode = m_land {
		//selectedRunway(namestr,geo1,geo2)
		
		local pos1 is runwayStart:position + heightOffsetVec.
		local pos1dist is vxcl(upVec,pos1):mag.
		local pos2 is runwayEnd:position + heightOffsetVec.
		local runwayVec is pos2-pos1.
		local runwayVecNormalized is runwayVec:normalized.
		local circleForwardOffset is landingRadius + 800 + 20 * maxBankSpeed.
		
		if submode = m_manual or (vang(vxcl(upVec,pos1),hVel) < 5 and vang(hVel,runwayVec) < 20 and altitude-targetAlt < 200 and pos1dist < (300 + circleForwardOffset)) {
			if submode = m_circle {
				set submode to m_manual.
				set vecs[vd_pos]:show to false.
				ag10 on. //flaps
			}
			set controlAlt to false.
			
			local offset is vdot(-runwayVecNormalized,pos1).
			
			
			
			local aimPosHeading is pos1 + runwayVecNormalized * max(-2500,offset + max(15,groundspeed * 6)).
			
			local pitchPosOffset is offset + 200 * (stallSpeed/50).
			
			if pitchPosOffset < 0 set runwayVecNormalized to angleaxis(descentAngle,vcrs(upVec,runwayVecNormalized)) * runwayVecNormalized.
			local aimPosPitch is pos1 + runwayVecNormalized * pitchPosOffset.
			
			if pitchPosOffset > 0 set aimPosPitch to body:geopositionof(aimPosPitch):position + heightOffsetVec.
			
			set targetPitch to 90 - vang(aimPosPitch,upVec).
			if pitchPosOffset > 0 set targetPitch to min(90 - vang(runwayVec,upVec) - 1,targetPitch).
			 
			set targetHeading to headingOf(aimPosHeading).
			
			
			if ship:status = "landed" { 
				set targetPitch to 0.
				set targetSpeed to 0. 
				
				if selectedRunway:length > 3 and groundspeed < 30 and vdot(runwayVec,selectedRunway[3]:position) > 0 { //runway has a designated parkingspot and it is ahead
					set submode to m_taxi.
					set waypointI to 2.
				}

				ag10 off.
			}
			else if alt:radar < 15 {
				set targetSpeed to 0.
			}
			else set targetSpeed to stallSpeed + max(0,vdot(runwayVecNormalized,pos1)/circleForwardOffset) * (maxBankSpeed + 10 - stallSpeed).
		}
		else if submode = m_taxi {
			
			
			if waypointI = 2 {
				set waypoint to pos1 + runwayVecNormalized * vdot(runwayVecNormalized,selectedRunway[3]:position - pos1).
				set targetSpeed to max(10,min(30,waypoint:mag/10)).
			}
			else {
				set waypoint to selectedRunway[waypointI]:position + heightOffsetVec.
				set targetSpeed to min(8,waypoint:mag/2).
			}
			if waypoint:mag < 40 and selectedRunway:length > waypointI + 1 set waypointI to waypointI + 1.
			if selectedRunway:length > waypointI + 1 set targetSpeed to max(6,targetSpeed).
			set targetPitch to 0.
			set targetHeading to headingOf(waypoint).
			if vdot(shipfacing,waypoint) < 0 and selectedRunway:length = waypointI + 1 { set targetSpeed to 0. setMode(m_manual). }
		}
		else {
			set submode to m_circle.
			
			local pos1UpVec is (pos1 - body:position):normalized. //we might be far away from the runway at this point, so use upVec of runway instead of local
			if runLandingSetup {
				local sideVec is -vxcl(pos1UpVec,vxcl(runwayVecNormalized,pos1)).
				
				if vang(sideVec, vcrs(pos1UpVec,runwayVecNormalized)) < 90 set clockwise to true.
				else set clockwise to false.
				
				set circleRadius to landingRadius.
				local turnCenter is pos1 - runwayVecNormalized * circleForwardOffset + sideVec:normalized * circleRadius.
				set circleLoc to body:geopositionof(turnCenter).
				
				set runLandingSetup to false.
			}
			
			local runwayAlt is runwayStart:terrainheight.
			
			local glideVec is -runwayVecNormalized * circleForwardOffset.
			set glideVec to angleaxis(descentAngle,vcrs(pos1UpVec,runwayVecNormalized)) * glideVec.
			
			//set glideVD to vecdraw(pos1,glideVec,red,"",1,true,20).
			
			local glideStartAlt is vdot(pos1UpVec,glideVec).
			
			local circleCenterDist is vxcl(upVec,circleLoc:position):mag.
			set controlAlt to true.
			if circleCenterDist < circleRadius + 500 { //in turn or close to it
				set targetAlt to runwayAlt + glideStartAlt.
				set targetSpeed to maxBankSpeed + 10.
			}
			else {
				set targetAlt to max(runwayAlt + glideStartAlt,targetAlt).
				set targetAlt to min(runwayAlt + glideStartAlt + max(0,circleCenterDist - circleRadius*4) / 6,targetAlt).
				set targetSpeed to max(maxBankSpeed + 20,targetSpeed).
				set targetSpeed to min(maxBankSpeed + 20 + max(0,circleCenterDist - circleRadius*3) / 100,targetSpeed).
			}
		}
		
	}
	
	if submode = m_circle {
		if kuniverse:activevessel = ship and mode <> m_land {
			if hasTarget set tarVessel to target.
			else set tarVessel to ship.
		}
		if tarVessel <> ship and mode <> m_land set circleLoc to tarVessel:geoposition.
		local centerPos is vxcl(upVec,circleLoc:position).
		//faceCamTo(centerPos).
		local currentRadius is centerPos:mag.
		
		local sign is 1.
		if clockwise set sign to -1.
		
		
		
		if currentRadius > circleRadius { //aim for the edge of the circle
			local theta is arcsin(circleRadius/currentRadius).
			set targetHeadingVec to centerPos * angleaxis(theta * sign,up:vector).
		}
		else { //we're closer than we should be.
			local offset is circlePid:update(time:seconds, circleRadius - currentRadius ).
			set targetHeadingVec to sign * vcrs(upVec,centerPos):normalized * targetSpeed + centerPos:normalized * offset * targetSpeed.
		}
		
		set targetHeading to headingOf(targetHeadingVec).
		
		set vecs[vd_pos]:start to circleLoc:position.
		print "r dist: " + round(centerPos:mag) + "m   " at (round(terminal:width*0.5),terminal:height-2).
	}
	
	// ### ALT ###
	if controlAlt {
		//set targetPitch to climbPid:update(time:seconds, (altitude + verticalspeed * 0.5) - targetAlt). 
		
		local altError is targetAlt - altitude.
		
		local desiredVV is max(-airspeed,min(airspeed,altError / 10)).
		
		//set verticalTarget to min(50,max(-50,(targetAlt - altitude)*0.3)).
		//set targetPitch to min(targetPitch + 0.1,max(targetPitch - 0.1,climbPid:update(time:seconds, verticalspeed - desiredVV))). 
		
		set targetPitch to 90 - arccos(desiredVV/max(0.1,airspeed)).
		set targetPitch to min(maxClimbAngle,max(-25,targetPitch)).
	}
	//else {
	//	set targetAlt to round(altitude,1).
	//}
	
	// ### HEADING ###
	set stTarget to heading(targetHeading,targetPitch):vector.
	set vecs[vd_stTarget]:vec to stTarget:normalized * 40.
	local hStTarget is vxcl(upVec,stTarget).
	
	//if updateCam faceCamTo(hStTarget). //update camera position if heading was manually changed
	
	local compassError is vang(hVel,hStTarget).
	if compassError < 45 { //kind of hurts to do these 4 calculations an additional time...
		set stNormal to vcrs(hVel,hStTarget).
		set stTarget to angleaxis(vang(hVel,hStTarget)^0.5,stNormal) * stTarget.
		set hStTarget to vxcl(upVec,stTarget).
		set compassError to vang(hVel,hStTarget).
	}
	
	local velPitch is 90 - vang(upVec,vel).
	
	if bankHard and compassError > -20 {
		if vdot(vcrs(upVec,hVel),hStTarget) > 0 set compassError to -compassError.
		
		set stNormal to vcrs(vel,stTarget).
		set st to angleaxis(min(15,vang(vel,stTarget)),stNormal) * vel.
		
		set stRoll to 90 + bankHardPid:update(time:seconds, targetPitch - velPitch ).
		if compassError < 0 set stRoll to -stRoll.
		
		local rollVector is angleaxis(stRoll,shipfacing) * upVec.
		set st to lookdirup(st,rollVector).
	}
	else {
		local attackAngle is 10 + attackPid:update(time:seconds, velPitch - targetPitch). 
			print "st attack ang: " + round(attackangle,2) + "   " at (1,terminal:height-2).
		set stNormal to vcrs(vel,stTarget).
		set st to angleaxis(min(attackAngle,vang(vel,stTarget)),stNormal) * vel.
		
		print "bank ang: " + round(getBank(),2) + "   " at (1,terminal:height-3).
		local pitchError is velPitch - targetPitch.
		//if abs(pitchError) > 5 pitchPid:reset().
		local pitchAdjust is pitchPid:update(time:seconds, pitchError * cos(abs(getBank()))) .
		set st to angleaxis(pitchAdjust,vcrs(hVel,upVec)) * st.
		
		//local aoaLimit is aoaHigh.
		//if vang(vel,st) > aoaLimit {
		//	set stNormal to vcrs(vel,st).
		//	set st to angleaxis(aoaLimit,stNormal) * vel.
		//}
		
		//roll w/ no pid
		//local stRoll is min(maxBank,vang(hVel,hStTarget) * 1.5).
		//if vdot(vcrs(upVec,hVel),stTarget) > 0 set stRoll to -stRoll.
		
		//### roll with pid
		if alt:radar < 12 set st to lookdirup(st,upVec).
		else  {
			local bankCap is min(maxBank,maxBank + 10 - abs(pitchError)^1.4).
			set bankPid:maxoutput to max(5,min(bankCap,maxBank * (forwardSpeed - stallSpeed)/(maxBankSpeed-stallSpeed))).
			set bankPid:minoutput to -bankPid:maxoutput.
			
			if vdot(vcrs(upVec,hVel),hStTarget) > 0 set compassError to -compassError.
			set stRoll to bankPid:update(time:seconds, -compassError * bankFactor * max(0.05,min(1,(forwardSpeed - stallSpeed)/(maxBankSpeed-stallSpeed))) ).  
			print "req bank: " + round(stRoll,2) + "   " at (1,terminal:height-4).
			
			
			local rollVector is angleaxis(stRoll,shipFacing) * vxcl(shipFacing,upVec).
			set vecs[vd_roll]:vec to rollVector:normalized * 5.
			set st to lookdirup(st,rollVector).
		}
	}
	
	//### wheelsteer
	
	if ship:status = "Landed" or ship:status = "PRELAUNCH" {
		//local wheelError is headingOf(facing:vector) - targetHeading .
		
		local wheelError is vang(vxcl(upVec,shipfacing),hStTarget).
		if vdot(ship:facing:starvector,hStTarget) < 0 set wheelError to -wheelError.
		
		//set wheelPid to PIDLOOP(0.15, 0.000, 0.1, -1, 1).
		set wheelPid:kP to 0.015 / max(1,groundspeed/10).
		set wheelPid:kD to wheelPid:kP * (2/3).
		set ship:control:wheelsteer to wheelPid:update(time:seconds, wheelError).

		//set ship:control:wheelsteer to wheelError * 0.2 / max(10,groundspeed).
		if (forwardSpeed - targetSpeed) > 0.1 or targetSpeed = 0 brakes on.
		else brakes off.
		
		if groundspeed < stallSpeed showVecs(false).
		else showVecs(true).
	}
	else {
		showVecs(true).
		set ship:control:wheelsteer to 0.
		
		if (forwardSpeed - targetSpeed) > 10 brakes on.
		else brakes off.
	}
	
	// Vecs >>
	set vecs[vd_vel]:vec to vel:normalized * 40.
	set vecs[vd_st]:vec to st:vector:normalized * 40.
	set vecs[vd_facing]:vec to shipfacing * 40.
	
	
	// <<
	
	
	refreshAll().
	set updateCam to false.
	wait 0.
}
unlock steering.
unlock throttle.
SET SHIP:CONTROL:NEUTRALIZE to TRUE.
clearvecdraws().
sas on.
if (ship:status = "landed" or ship:status = "prelaunch") and groundspeed < 35 brakes on.
clearscreen.
print "Autopilot shutdown.".