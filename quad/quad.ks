@LAZYGLOBAL on.
// ### quad.ks ###


clearvecdraws().
clearscreen.
switch to 0.
global all_libs_loaded is false.
//runpath("lib_quad.ksm").
//runpath("lib_json.ksm").
//runpath("race.ksm").
global mode is m_pos.
global submode is m_pos.
global page is 1.
global focused is true.
entry("Booting up program..").

wait 0.

//undock if needed 
set hasMS to false.
if core:element:dockingports:length > 0 { 
	//set localPort to core:element:dockingports[0].
	set localPort to dockSearch(core:part:parent,core:part). //call to recursive search function that returns the cpu vessel's global dockingport
	entry("Found dockingport: " + localPort:name).
	set hasPort to true.
	if localPort:state = "Docked (docker)" or localPort:state = "Docked (dockee)" {
		set mothership to ship.
		set hasMS to true.
		localPort:undock.
		wait 0.
	}
	for ms in localPort:modules {
		global m is localPort:getmodule(ms).
		if m:hasevent("Decouple Node") {
			set mothership to ship.
			m:doevent("Decouple Node").
			set hasMS to true.
		}
		else if m:hasevent("Undock") m:doevent("Undock").
		wait 0.
	}
}
else set hasPort to false.
for curpart in ship:parts {
	for ms in curpart:modules {
		if ms = "ModuleCommand" {
			
			set dronePod to curpart.
			dronePod:controlfrom.
			lock throttle to 0. set ship:control:pilotmainthrottle to 0.
			entry("Probe core: " + dronePod:name).
		}
	}
}

brakes off. //ag1 off. ag2 off. ag3 off. ag4 off. ag5 off. ag6 off. ag7 off. ag8 off. ag9 off. ag10 off.
vecs_clear().

// ### engine/servo checks and preparations --------------------------------------------------------------------
// >>
set engDist to 0.
set deploying to false.
set canReverse to false.
list engines in engs.
set engsLexList to list().

global i is 0.
for eng in engs {
	//check for foldable engines, unfold
	global thisEngineCanReverse is false.
	global reverseMod is 0.
	for moduleStr in eng:modules {
		
		
		global mod is eng:getmodule(moduleStr).
		if mod:hasevent("Deploy Propeller") {
			mod:doevent("Deploy Propeller").
			set deploying to true.
		}
		
		if mod:hasevent("Set Reverse Thrust") {
			set canReverse to true.
			set thisEngineCanReverse to true.
			set reverseMod to mod.
		}
		
	}
	
	
	global currentLex is lexicon(). //temporary dummy lex
	currentLex:add("part",eng).
	//assign engines as pitch/roll
	if vdot(facing:starvector,eng:position) < -0.3 { 
		set eng_roll_pos to currentLex.
		currentLex:add("pitchMod",0).
		currentLex:add("rollMod",1). 
	}
	else if vdot(facing:starvector,eng:position) > 0.3 {
		set eng_roll_neg to currentLex.
		currentLex:add("pitchMod",0).
		currentLex:add("rollMod",-1).
	}
	else if vdot(facing:topvector,eng:position) < -0.3 {
		set eng_pitch_pos to currentLex.
		currentLex:add("pitchMod",1).
		currentLex:add("rollMod",0).
		
	}
	else if vdot(facing:topvector,eng:position) > 0.3 {
		set eng_pitch_neg to currentLex.
		currentLex:add("pitchMod",-1).
		currentLex:add("rollMod",0).
	}
	
	currentLex:add("canReverse",thisEngineCanReverse).
	if thisEngineCanReverse {
		currentLex:add("reverseMod",reverseMod).
		currentLex:add("inReverse",false).
	}
	
	set haslight to false.
	for p in eng:parent:parent:children {
		for ms in p:modules {
			local m is p:getmodule(ms).
			if m:hasfield("light r") {
				set haslight to true.
				currentLex:add("lightModule",m).
			}
		}
	}
	currentLex:add("hasLight",haslight).
	currentLex:add("thrustLimitDampened", eng:thrustlimit).
	
	currentLex:add("vd",vecdraw(eng:position,eng:facing:vector * eng:thrust,red,"",1, false, 0.3, true, false)).
	
	engsLexList:add(currentLex).
	set engDist to engDist + vxcl(facing:vector,eng:position):mag.
}
set engDist to engDist/4.
if deploying { entry("Deploying propellers.."). wait 2. }


set servoList to list().
set i to 0.
for eng in engs {
	if not(eng:ignition) { eng:activate(). wait 0. }
	
	set eng:thrustlimit to 100.
	
	//check for yaw servos
	if eng:parent:hasmodule("ModuleRoboticRotationServo") {
		set rot to eng:parent:getmodule("ModuleRoboticRotationServo").
		rot:setfield("damping", 150).
		servoList:add(rot).
	}
	
	set i to i + 1.
}

//set servoKAL to ship:modulesnamed("ModuleRoboticController")[0].


wait random().
setLights(0,1,0).
// <<

//### camera stuff ---------------------------------------------------------------------
// >>
set hasGimbal to false.
set hasCam to false.
set hasCamRoll to false.
set hasCamArm to false.
set cam to ship:partstagged("camera").
set camRotH to ship:partstagged("horizontal").
set camRotV to ship:partstagged("vertical").
if cam:length > 0 and camRotH:length > 0 and camRotV:length > 0 {
	entry("Found camera and gimballing parts, enabling camera controls..").
	set hasGimbal to true.
	set cam to cam[0].
	//if false { 
		set hasCam to true.
		set camMod to cam:getmodule("MuMechModuleHullCameraZoom").
	//}
	
	set camRotH to camRotH[0].
	set rotHMod to camRotH:getmodule("MuMechToggle").
	set camRotV to camRotV[0].
	set rotVMod to camRotV:getmodule("MuMechToggle").
	rotHMod:setfield("acceleration",20). 
	rotVMod:setfield("acceleration",20).   
	
	if ship:partstagged("roll"):length > 0 {
		set camRotR to ship:partstagged("roll")[0].
		set rotRMod to camRotR:getmodule("MuMechToggle").
		set hasCamRoll to true.
		rotRMod:setfield("acceleration",20).
	}
	else set hasCamRoll to false.
	
	if ship:partstagged("arm"):length > 0 {
		set camArm to ship:partstagged("arm")[0].
		set armMod to camArm:getmodule("MuMechToggle").
		armMod:setfield("acceleration",20).
		set hasCamArm to true.
	}
	
	//set frontPart to camRotV.
	
	set g_cam:onclick to { camMod:doevent("Activate Camera"). }.
	
}
else set g_cam:visible to false.

if addons:ir:available and addons:ir:allservos:length > 0 {
	for servo in addons:ir:allservos {
		if servo:part = camRotH set servoH to servo.
		else if servo:part = camRotV set servoV to servo.
		
		if hasCamRoll {
			if servo:part = camRotR set servoR to servo.
		}
		if hasCamArm {
			if servo:part = camArm set servoArm to servo.
		}
	}
}
// <<

// ### Vecdraws ---------------------------
// >>
//global markThrustAcc is vecs_add(v(0,0,0),v(0,0,0),red,"Thr").
//global markStar is vecs_add(v(0,0,0),facing:starvector*5,rgba(1,1,0,0.1),"stb",0.2). 
//global markTop is vecs_add(v(0,0,0),facing:topvector*5,rgba(1,0.8,0,0.12),"top",0.2).
//global markFwd is vecs_add(v(0,0,0),facing:forevector*5,rgba(1,0.6,0,0.14),"fwd",0.2).
global targetVec is up:forevector.
global targetVecStar is v(0,0,0).
global targetVecTop is v(0,0,0).
global markTar is vecs_add(v(0,0,0),v(0,0,0),cyan,"tgt",0.2).
//global markTarP is vecs_add(v(0,0,0),v(0,0,0),cyan,"TP",0.2).
//global markTarY is vecs_add(v(0,0,0),v(0,0,0),cyan,"TY",0.2).
//global markAcc is vecs_add(v(0,0,0),v(0,0,0),green,"acc",0.2). 
global markHorV is vecs_add(v(0,0,0),v(0,0,0),blue,"vel",0.3).
global markDesired is vecs_add(v(0,0,0),v(0,0,0),yellow,"",0.3).
global markVMod is vecs_add(v(0,0,0),v(0,0,0),green,"",0.2).
global markDestination is vecs_add(v(0,0,0),-up:vector * 3,rgb(1,0.8,0),"",0.2).
global markGate is vecs_add(v(0,0,0),-up:vector * 40,rgb(0,1,0),"",10).

global pList is list(). //terrain prediction vecs
pList:add(0).
pList:add(vecs_add(v(0,0,0),up:vector * 3,rgb(1,0,0.0),"",1.0)).
pList:add(vecs_add(v(0,0,0),up:vector * 3,rgb(1,0.2,0.0),"",1.0)).
pList:add(vecs_add(v(0,0,0),up:vector * 3,rgb(1,0.4,0.0),"",1.0)).
pList:add(vecs_add(v(0,0,0),up:vector * 3,rgb(1,0.6,0.0),"",1.0)).
pList:add(vecs_add(v(0,0,0),up:vector * 3,rgb(1,0.8,0.0),"",1.0)). 

set terMark to false.
set stMark to false.
set thMark to false.
set miscMark to false.

function updateVec {
	parameter targetVec.
	set targetVecStar to vxcl(facing:topvector, targetVec).
	set targetVecTop to vxcl(facing:starvector, targetVec).
	set vecs[markTar]:vec to targetVec*5.
	//set vecs[markTarP]:vec to targetVecTop*5.
	//set vecs[markTarY]:vec to targetVecStar*5.
}
// <<

// ### Cam modes ###
// >>
	
	function CamGimbal {
		return extcam:position * 0.2 + ((camRotV:facing:vector * -3) + upVector * -0.5 + camRotV:position) * 0.8.

	}
	
	function CamTarget {
		if hastarget {
			global camVec is target:position.
			set camVec:mag to camVec:mag + 15 .
			return extcam:position.// * 0.5 + (camVec+upVector * 2.5) * 0.5. 
		}
		else {
			gear on. //force next cam-mode
			return extcam:position.
		}
		 
	}
	
//<<

//### User input function ###

function inputs {

	// MISC CONTROLS ##########################################################################################################
	if not(isDocked) and not(charging) {
		if hasCam {
			if ship:control:pilottop > 0 {
				if lastCamActivation + 0.5 < time:seconds {
					camMod:doevent("Activate Camera").
					set lastCamActivation to time:seconds.
				}
			}
		}
		if submode = m_free { //manual direction
			if ship:control:pilotyaw <> 0 { // S+D
				set countHeading to countHeading + 1.
				if countHeading <= 10 set freeHeading to freeHeading + ship:control:pilotyaw/5.
				else set freeHeading to freeHeading + ship:control:pilotyaw * min(40,countHeading)/10.
				if freeHeading > 360 set freeHeading to freeHeading - 360.
				else if freeHeading < 0 set freeHeading to freeHeading + 360.
			}
			else {
				set countHeading to 0.
			}
			if ship:control:pilotpitch <> 0 { // W+S
				set freeSpeed to freeSpeed - ship:control:pilotpitch * min(5,max(0.5,abs(freeSpeed*0.1))).
				set freeSpeed to min(2000,max(0,freeSpeed)).
			}
		}
		else if mode = m_pos { //position shift
			if ship:control:pilotyaw <> 0 {
				set targetGeoPosP to targetGeoPos:position.
				set countE to min(150,countE + 1).
				//if countE <= 10 set eastShift to -ship:control:pilotyaw * 0.05.
				set eastShift to -ship:control:pilotyaw * 0.01 * (countE^1.5). 
				if mapview set eastShift to eastShift * 100.
				else set eastShift to eastShift * max(1,min(10,targetGeoPosP:mag ^ 0.1)).
				
				if mapview set targetGeoPosP to targetGeoPosP + vcrs(north:vector,up:vector):normalized * eastShift.
				else set targetGeoPosP to targetGeoPosP + vcrs(extcam:position,up:vector):normalized * -eastShift.
				set targetGeoPos to body:geopositionof(targetGeoPosP).
			}
			else {
				set countE to 0.
			}
			if ship:control:pilotpitch <> 0 { 
				set targetGeoPosP to targetGeoPos:position.
				set countN to min(150,countN + 1).
				set northShift to -ship:control:pilotpitch * 0.01 * (countN^1.5).
				if mapview set northShift to northShift * 100.
				else set northShift to northShift * max(1,min(10,targetGeoPosP:mag ^ 0.1)).
				
				if mapview set targetGeoPosP to targetGeoPosP + vxcl(up:vector,north:vector):normalized * northShift. 
				else set targetGeoPosP to targetGeoPosP + vxcl(up:vector,extcam:position):normalized * -northShift. 
				set targetGeoPos to body:geopositionof(targetGeoPosP).
				
			}
			else {
				set countN to 0.
			}
		}
	}
}

on ag10 {
	set doFlip to true.
	if vdot(desiredHV,facing:vector) < 0 set frontFlip to true.
	else set frontFlip to false.
	return true.
}
on ag9 { toggleCamMode(). return true. }
on ag8 {
	if mode = m_race {
		set focusCamPos to vxcl(upVector,targetGate:position) * (0.5 + random() * 0.5) + upVector * random() * 30.
	}
	return true.
}

function toggleCamMode {
	if hasCamAddon {
		
		set camMode to camMode + 1.
		if camMode = 2 and mode <> m_race set camMode to camMode + 1.
		if camMode = 3 and mode <> m_race set camMode to camMode + 1.
		if camMode = 4 and not(hasGimbal) set camMode to camMode + 1.
		if camMode = 5 and not(hastarget) set camMode to camMode + 1.
		if camMode >= 6 set camMode to 0.
		
		set extcam:target to ship.
		
		if camMode = 1 {
			set extcam:positionupdater to DoNothing.
			set extcam:camerafov to 65.
			//set extcam:positionupdater to CamChase@.
			when true then {
				if (h_vel_mag > 0.1){
					set desiredHV_capped to desiredHV:normalized * min(velocity:surface:mag,desiredHV:mag).
					set focusCamPos to focusCamPos + velocity:surface * 0.03 + desiredHV_capped * 0.05. 
					set focusCamPos:mag to max(10,velocity:surface:mag).
					
					set extcam:position to (angleaxis(8,vcrs(upVector,focusCamPos)) * -focusCamPos):normalized *  (8 + groundspeed/20).
				}
				if camMode = 1 return true.
			}
			entry("Camera mode: Smooth Chase").
		}
		else if camMode = 2 { 
			//set extcam:positionupdater to CamRace1@. 
			set extcam:positionupdater to DoNothing.
			when true then {
				//set focusCamPos to focusCamPos * 0.99 + 0.01 * (targetGate:position + upVector * 20 - gateFacing * (80 + targetGate:position:mag * 0.3)).
				set focusCamPos to focusCamPos * 0.99 + 0.01 * (-targetGate:position:normalized * 20 + upVector * -1).
				set extcam:camerafov to arctan(15/(focusCamPos:mag^0.7)). 
				set extcam:position to focusCamPos.
				if camMode = 2 return true.
			}
			entry("Camera mode: Race").
		}
		else if camMode = 3 { //VAB
			set extcam:positionupdater to DoNothing.
			
			when true then {
				local vabPos is LATLNG(-0.0967646955755359, -74.6187122587352):position.
				set focusCamPos to  (vabPos + upVector * 20 + vxcl(upVector,vabPos):normalized * -20).
				set extcam:camerafov to arctan(15/(focusCamPos:mag^0.7)).  
				
				set extcam:position to focusCamPos.
				
				if camMode = 3 return true.
				else { set extcam:camerafov to 70. set extcam:cameradistance to 10. }
			}
			entry("Camera mode: VAB").
		}
		else if camMode = 4 {
			set extcam:target to Cam.
			set extcam:positionupdater to CamGimbal@.
			entry("Camera mode: Gimbal lock"). 
		}
		else if camMode = 5 {
			set extcam:target to target.
			set extcam:positionupdater to CamTarget@.
			entry("Camera mode: Target").
		}
		else {
			set extcam:positionupdater to DoNothing.
			set extcam:camerafov to 70.
			set extcam:cameradistance to 10.
			entry("Camera mode: Free").
		}
	}
}

function taggedPart {
	set tagged to tarVeh:PARTSTAGGED("attach").
	if tagged:length > 0 { 
		set tarPart to tagged[0].
		set destinationLabel to tarVeh:name + " - " + tarPart:name.
	}
	else { set tarPart to tarVeh:rootpart. set destinationLabel to tarVeh:name. }
}

//### Angular momentum / inertia / acceleration stuff ###
// >>

function getInertia { //moment of inertia around an axis
	parameter axis. //vector
	
	global inertia is 0.
	for p in ship:parts {
		set inertia to inertia + p:mass * (vxcl(axis,p:position):mag^2).
	}
	return inertia.
}
set roll_inertia to getInertia(facing:topvector).
set pitch_inertia to getInertia(facing:starvector).

set shipFacing to ship:facing:vector.
function getTorque {
	parameter p. 
	return vxcl(shipFacing,p:position):mag * (p:maxthrust * vdot(shipFacing,p:facing:vector)).
}

set pitch_torque to (getTorque(eng_pitch_pos["part"]) + getTorque(eng_pitch_neg["part"])) / 2.
set roll_torque to (getTorque(eng_roll_pos["part"]) + getTorque(eng_roll_neg["part"])) / 2.

set pitch_acc to pitch_torque / pitch_inertia.
set roll_acc to roll_torque / roll_inertia.

// <<

//### resource stuff ###
//>>
set drone_resources to core:element:resources.
set fuelType to "ELECTRICCHARGE".
for res in drone_resources {
	if res:name = "LIQUIDFUEL" {
		if res:amount > 1 {
			set fuelType to "LIQUIDFUEL".
			set droneRes to res.
		}
	}
	
} 
if fuelType = "ELECTRICCHARGE" {
	for res in drone_resources {
		if res:name = "ELECTRICCHARGE" set droneRes to res.
	}
}
entry("Fuel type: " + fuelType).
//<<

//### Vars initial ###
//>>
global th is 0.
lock throttle to th.


set sampleInterval to 0.2.
set lastTargetCycle to 0.
set doLanding to false.
set rotateSpeed to 0.
list targets in targs.
set target_i to 0.
set tarPart to 0.
set adjustedMass to mass.
set localTWR to (ship:maxthrust / adjustedMass)/(body:mu / body:position:mag^2).
set TWR to (ship:maxthrust / adjustedMass)/9.81.
set v_acc_e_old to 0.
set h_acc_e_old to v(0,0,0).
global tOld is time:seconds. global velold is velocity:surface. global dT is 1. global tarVelOld is v(0,0,0).
global tHeight is round(min(10,alt:radar + 3.5),2).
set g_height:value to tHeight.
global posI is 0.
global accI is 0.
global throtOld is 0.
global lastT is time:seconds - 1000.
global acc_list is list().
set i to 0. until i = 5 { acc_list:add(0). set i to i + 1. }
global posList is list().
set i to 0. until i = 10 { posList:add(ship:geoposition:terrainheight). set i to i + 1. }
set targetGeoPos to ship:geoposition.
set targetString to "LOCAL".
set massOffset to 0.
set charging to false.
set speedlimitmax to 225.
set consoleTimer to time:seconds.
set slowTimer to time:seconds.
set forceUpdate to true.
set desiredHV to v(0,0,0).
set v_acc_dif_average to 0.
set followDist to 0.
set forceDock to false.
if hasPort set autoFuel to true.
else set autoFuel to false.
set autoLand to true.
set patrolRadius to 10.
set massOffset to 0.
set engineCheck to 0.
set stVec to v(0,0,0).
set agressiveChase to false.
set focusPos to facing:topvector * 10.
set focusCamPos to facing:topvector * 1.
set desiredHV_capped to focusCamPos.
set vMod to 0.
set fuel to 100.
set gravitymod to 1.2.
set thrustmod to 0.92.
set climbDampening to 0.3.
set angVelMult to 0.15.
set h_vel to v(0,0,0).
set isDocked to false.
set ipuMod to sqrt(min(2000,config:ipu)/2000). //used to slow things down if low IPU setting 
set camMode to 0.
set destinationLabel to "".
set lastCamActivation to 0.
set showstats to false.
set fuelRate to 0.
set lastFuel to 100.
set localFocusPos to v(0,0,0).
set thAvg to 0.
set correctingYaw to false.
set gravityMag to body:mu / body:position:sqrmagnitude.
set upVector to up:vector.
set gravity to -upVector * gravityMag.
set weightRatio to gravityMag/9.81.

global doFlip is false.
set dTavg to 0.02. 

global terrainChecks is 5.
set availableTWR to ship:maxthrust / ship:mass.
set engineThrustLimitList to list(0,0,0,0).
set gearMods to ship:modulesnamed("ModuleWheelDeployment").
set upVector to up:vector.
set minAlt to 0.
set minimumDockTime to time:seconds.
set h_acc to v(0,0,0).
set winchModules to ship:modulesnamed("KASModuleWinch").
if winchModules:length > 0 set hasWinch to true.
else set hasWinch to false.

if hasMS {
	set mode to m_follow.
	set submode to m_follow.
	set followDist to 10.
	set tarVeh to mothership. 
	set tarPart to tarVeh:rootpart.
}
//<<

//### PID controllers ###
//>>
set base_kP to 50.
global PID_pitch is pidloop(base_kP, 0, 0.3, -150, 150). //(75, 0, 2, -100, 100).  
//global PID_pitch is P_init(50.0,-100,100). //P_init(50.0,-100,100). 
global PID_roll is pidloop(base_kP, 0, 0.3, -150, 150). //(75, 0, 2, -100, 100).
//global PID_roll is P_init(50.0,-100,100). //P_init(50.0,-100,100). 

if true {
	on ag1 {
		set PID_pitch:kD to PID_pitch:kD - 0.1.
		set PID_roll:kD to PID_roll:kD - 0.1.
		popup("Engine balance PID kD: " + PID_pitch:kD).
		return true.
	}
	on ag2 {
		set PID_pitch:kD to PID_pitch:kD + 0.1.
		set PID_roll:kD to PID_roll:kD + 0.1.
		popup("Engine balance PID kD: " + PID_pitch:kD).
		return true.
	}
	on ag3 {
		set base_kP to base_kP * 0.75.
		popup("Engine balance PID kP: " + base_kP). 
		return true.
	}
	on ag4 {
		set base_kP to base_kP * 1.25.
		popup("Engine balance PID kP: " + base_kP).
		return true.
	}
	on ag5 {
		set angVelMult to angVelMult - 0.05.
		popup("Angvel mult: " + angVelMult). 
		return true.
	}
	on ag6 {
		set angVelMult to angVelMult + 0.05.
		popup("Angvel mult: " + angVelMult). 
		return true.
	}
	
}


global PID_vAcc is pidloop(6,0,0.3,-90,90). //pidloop(8,0,0.5,-90,90).
set PID_vAcc:setpoint to 0.

global PID_hAcc is pidloop(1.6 * ipuMod,0,0.2,0,90). // pidloop(1.4 * ipuMod,0.2,0.1,0,90).  //global PID_hAcc is pidloop(2.1,0,0.1,0,90).   //(3,0,0.3,0,90).  
set PID_hAcc:setpoint to 0.

//<<

load_json(). //load saved settings on the local drive, if any.
  
set all_libs_loaded to true.
entry("All systems ready. Initializing controllers.").




//when camMode > 0 then {
//	if camMode = 1 and h_vel_mag > 0.1 { //chase cam mode
//		
//		set desiredHV_capped to desiredHV:normalized * min(shipVelocitySurface:mag,desiredHV:mag).
//		set focusCamPos to focusCamPos + shipVelocitySurface * 0.05 + desiredHV_capped * 0.05. 
//		set focusCamPos:mag to max(10,shipVelocitySurface:mag).
//		
//		set extcam:position to angleaxis(8,vcrs(upVector,focusCamPos)) * -focusCamPos.
//		set extcam:cameradistance to 8 + 6 * (h_vel_mag/100).
//
//	}
//	else if camMode = 2 {
//		global focusCamPos is (targetGate:position + upVector * 20 - gateFacing * (80 + targetGate:position:mag * 0.3)). 
//		
//		set extcam:camerafov to arctan(15/(focusCamPos:mag^0.7)). 
//		set extcam:position to focusCamPos.
//	}
//	return true.
//}

initializeTrigger(). //the trigger in this will be run at the beginning of every tick
wait 0. //just to make sure the triggers run once before main loop


gear off.
set bootTime to time:seconds.
when bootTime + 0.02 < time:seconds then set r_free:pressed to true. //selectMode(r_free).
// Retract gears (if any)
for m in gearMods {
	if m:hasaction("extend/retract") m:doaction("extend/retract",false).
}


//main controller loop
set exit to false.
set lockToggle to false.

// CONFIG:STAT TO TRUE.
until exit {
	flightcontroller().
	if lockToggle { set lockToggle to false. lock throttle to th. }
}
//log profileresult() to quadProfile.csv.

ag1 off.
set mode to 10.
set submode to 10.

set extcam:target to ship.
set extcam:positionupdater to DoNothing.

save_json().

vecs_clear().
clearvecdraws().
for eng in engs {
	for moduleStr in eng:modules {
		global mod is eng:getmodule(moduleStr).
		if mod:hasevent("Retract Propeller") {
			mod:doevent("Retract Propeller").
		}
	}
	eng:shutdown().
	set eng:thrustlimit to 100.
}
if hasGimbal { 
	rotHMod:doaction("move +",false). rotHMod:doaction("move -",false). 
	rotVMod:doaction("move +",false). rotVMod:doaction("move -",false). 
}

for s in servoList  s:setfield("target angle", 0).

set th to 0.
unlock throttle.
set ship:control:pilotmainthrottle to 0.
entry("Program ended.").
setLights(1,0.1,0.1).
wait 0.2.