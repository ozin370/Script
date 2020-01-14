set config:ipu to 4000.
run cam.
clearvecdraws().

set tracking to false.
set camera_focus to false.
set camera_spin to false.
set kill_all to false.
set shoot_distance to 2000.
local missileDetectionRange is 1400.

// ### GUI
clearguis().

local g is gui(280).
set g:x to 4.
set g:y to 37. 
set g:style:padding:h to 5.
set g:style:padding:v to 5.
set g:skin:font to "Nimbus Mono".

local title is g:addhlayout().
set title:style:margin:top to 0.
	local title_label is title:addlabel("<b><color=yellow>[T]</color> - " + ship:name + "</b>").
	set title_label:style:fontsize to 14.
	//set title_label:style:font to "Nimbus Mono Bold".
	set title_label:style:margin:h to 2.
	set title_label:style:margin:v to 0.
	local g_enabled is title:addcheckbox("",tracking).
	set g_enabled:style:width to 20.
	set g_enabled:style:height to 20.
	set g_enabled:style:margin:v to 0.
	//set g_enabled:style:margin:h to 10.
	//set g_enabled:style:margin:v to 10.
	set g_enabled:ontoggle to { parameter b. set tracking to b. }.
	local g_hide is title:addbutton("S").
	set g_hide:style:margin:h to 0.
	set g_hide:style:margin:v to 0.
	set g_hide:toggle to true.
	set g_hide:style:width to 20.
	set g_hide:style:height to 20.
	set g_hide:ontoggle to { parameter b. if b g_b:hide(). else g_b:show(). }.

local g_t is g:addvbox().
set g_t:style:margin:h to 0.
set g_t:style:padding:h to 10.
set g_t:style:padding:v to 15.
	local g_target is g_t:addlabel("").
	local g_target_distance is g_t:addlabel("").
	local g_target_speed is g_t:addlabel("").
	local g_target_traveltime is g_t:addlabel("").
	local g_target_bulletspeed is g_t:addlabel("").

local g_b is g:addvbox().
set g_b:style:margin:h to 0.
set g_b:style:padding:h to 10.
set g_b:style:padding:v to 15.
	
	//g_b:addspacing(10). shoot_distance

	local g_dist_text is g_b:addlabel("Missile tracking distance:").
	set g_dist_text:style:margin:bottom to 0.
	local g_sliderbox is g_b:addhlayout().
		local g_distance is g_sliderbox:addhslider(2500,1000,6000).
		set g_distance:onchange to g_distance_change@.
		local g_dist_disp is g_sliderbox:addlabel("2500m").
		set g_dist_disp:style:width to 45.
	local g_shoot_dist_text is g_b:addlabel("Gun range:").
	set g_shoot_dist_text:style:margin:bottom to 0.
	local g_sliderbox2 is g_b:addhlayout().
		local g_shoot_distance is g_sliderbox2:addhslider(shoot_distance,300,5000).
		set g_shoot_distance:onchange to g_shoot_distance_change@.
		local g_shoot_dist_disp is g_sliderbox2:addlabel(shoot_distance + "m").
		set g_shoot_dist_disp:style:width to 45.
		
	local g_cam is g_b:addcheckbox("Camera focus targets",camera_focus).
	set g_cam:ontoggle to { parameter b. set camera_focus to b. }.
	local g_cam_spin is g_b:addcheckbox("Camera spin",camera_spin).
	set g_cam_spin:ontoggle to { parameter b. set camera_spin to b. }.
	local g_kill_all is g_b:addcheckbox("Shoot all the things",false).
	set g_kill_all:ontoggle to { parameter b. set kill_all to b. }.

function g_distance_change {
  parameter newValue.

  set missileDetectionRange to round(newValue / 100) * 100.
  set g_dist_disp:text to missileDetectionRange:tostring() + "m".
}
function g_shoot_distance_change {
  parameter newValue.

  set shoot_distance to round(newValue / 100) * 100.
  set g_shoot_dist_disp:text to shoot_distance:tostring() + "m".
}

g:show().

// ### New multi turret setup

function turretSearch { //recursive function searching downwards in the parts tree, starting at the first parent servo of each turret
	parameter parentPart.
	
	for p in parentPart:children {
		if p:tag = "vertical" {
			lex:add("camRotV", p).
			lex:add("rotVMod", p:getmodule("MuMechToggle")).
			p:getmodule("MuMechToggle"):setfield("acceleration",50).
		}
		else if p:tag = "roll" {
			lex:add("camRotR", p).
			lex:add("rotRMod", p:getmodule("MuMechToggle")).
			p:getmodule("MuMechToggle"):setfield("acceleration",20).
			//set hasCamRoll to true.
		}
		else if p:tag = "arm" {
			lex:add("camArm", p).
			lex:add("armMod", p:getmodule("MuMechToggle")).
			p:getmodule("MuMechToggle"):setfield("acceleration",20).
		}
		else if p:tag = "camera" {
			lex:add("cam", p).
			lex:add("camMod", p:getmodule("MuMechModuleHullCameraZoom")).
			set hasCam to true.
		}
		else if p:modules:contains("ModuleWeapon") {
			//lex["guns"]:add(p).
			lex["gunMods"]:add(p:getmodule("ModuleWeapon")).
		}
		
		turretSearch(p). //search further down the tree
	}
}

local turrets is list().
for horPart in ship:partstagged("horizontal") { //for each turret
	set lex to lexicon().
	//lex:add("guns",list()). //probably not needed
	lex:add("gunMods",list()).
	lex:add("camRotH",horPart).
	lex:add("rotHMod", horPart:getmodule("MuMechToggle")).
	horPart:getmodule("MuMechToggle"):setfield("acceleration",50).
	turretSearch(horPart).
	
	set hasGimbal to true.
	
	
	for servo in addons:ir:allservos {
		if servo:part = lex["camRotH"] lex:add("servoH", servo).
		else if servo:part = lex["camRotV"] lex:add("servoV", servo).
		
		if lex:haskey("camRotR") {
			if servo:part = lex["camRotR"] lex:add("servoR", servo).
		}
		if lex:haskey("camArm") {
			if servo:part = lex["camArm"] lex:add("servoArm", servo).
		}
	}
	lex:add("horErrorI",0).
	lex:add("vertErrorI",0).
	lex:add("VD", vecdraw(v(0,0,0),v(0,0,0),red,"",1,true,0.1)).
	turrets:add(lex).
}



wait 0.1.
// <<

if hasGimbal { //turret stuff
	set horErrorI to 0.
	set vertErrorI to 0.
	set tarVelLast to v(0,0,0).
	set tarAcc to v(0,0,0).
	set tarAccOld to v(0,0,0).
	set accAngRot to 0.
	set accRotAxis to v(0,0,0).
	set lastCamPos to extcam:position.
	
	for p in ship:parts {
		if p:name = "bahaBrowningAnm2" set muzzleVel to 890.
		else if p:name:contains("vulcan") set muzzleVel to 1000.
		else if p:name = "bahaGau-8" set muzzleVel to 980.
	}
}

set camMove to 0.
//set targetLastPos to v(0,0,0).
set lastTickAtShip to true.
set tOld to time:seconds - 0.02.

set vd_target to vecdraw(v(0,0,0),v(0,0,0),magenta,"",1,true,0.4).
set vd_aim to vecdraw(v(0,0,0),v(0,0,0),red,"",1,true,0.1).
set vd_acc1 to vecdraw(v(0,0,0),v(0,0,0),green,"",1,true,0.2).
set vd_acc2 to vecdraw(v(0,0,0),v(0,0,0),yellow,"",1,true,0.2).


//return a list of the 5 closest vessels, sorted by distance
function sortTargetsDistance {
	local sorted is list().
	list targets in tars.
	local tgs is list(). //the list that will get sorted later
	for t in tars { //filter out distant vessels and debris
		if t:distance < missileDetectionRange  {
			if not t:name:endswith("Debris") or kill_all tgs:add(t).
		}
	}
	
	local i is 0.
	local limited is false.
	
	local lowestTarget is 0.
	until i = tgs:length or i = 3 { //sort the list, stop when the 5 closest targets have been found
		local isValid is false.
		local lowestValue is missileDetectionRange.
		for t in tgs {
			local tDistance is t:distance.
			if tDistance < lowestValue and not sorted:contains(t) {
				set lowestValue to tDistance.
				set lowestTarget to t.
				set isValid to true.
			}
		}
		if isValid sorted:add(lowestTarget).
		set i to i + 1.
	}
	return sorted.
}

local tarList is list().
local lastSorted is time:seconds - 2.

function updateGimbal {
	print " dt: " + dT2 at (0,terminal:height-6).
	
	set targetVes to ship.

	
	
	if tracking {
		if time:seconds - 0.2 > lastSorted {
			set tarList to sortTargetsDistance().
			set lastSorted to time:seconds.
		}
		
		//clearscreen. // debug 
		for t in tarList {
			//print t:name + " - " + t:distance. // debug
		
			if not(t:isdead) and vdot(-t:position,t:velocity:surface) > -100 {
				if t:name:startswith("Aim") or t:name:startswith("AGM") or t:name:startswith("BGM") or t:name:startswith("PAC-") {
					set targetVes to t.
					break.
				}
			}
		}
		if kill_all and tarList:length > 0 set targetVes to tarList[0].

		if hastarget and targetVes = ship and target:distance < 6000 { 
			set targetVes to target.
			if targetVes:istype("Part") set targetVes to targetVes:ship.
		}
	}
	
	if not(targetVes = ship) and camera_focus {
		if lastTickAtShip {
			set lastTickAtShip to false.
			set camMove to 1.1.
			set extcam:target to targetVes.
			set extcam:position to ship:position.
		}
		
		//set extcam:position to targetVes:position * (1-camMove).
		if camMove > 0 set extcam:cameradistance to max(15,(targetVes:distance * (camMove^0.5))).
		if camera_spin set extcam:heading to extcam:heading + 0.5.
		print "Missile Speed: " + round(targetVes:airspeed) + "m/s    " at (1,4).
		set camMove to max(0,camMove - 0.003 - 40/targetVes:distance).
	}
	else {
		set lastTickAtShip to true.
		set extcam:target to ship.
		if extcam:cameradistance > 50 set extcam:cameradistance to 49.
	}
	
	if not(targetVes = ship) { //valid target in range for tracking
		//### targeting code, this is where the target future position prediction happens
		local tarVel is targetVes:velocity:surface.
		local tarPos is targetVes:position.
		set bulletSpeed to muzzleVel + vdot(tarPos:normalized,shipVelocitySurface).
		set travelTime to tarPos:mag / bulletSpeed.
		
		set tarAcc to (tarVel - tarVelLast) / dT2. //tarAccOld * 0.9 + ((tarVel - tarVelLast) / dT2) * 0.1.
		local accAngRot is min(45,vang(tarAcc,tarAccOld) / dT2). //how much degrees we should rotate the accel vector between steps (when the target is turning)
		local accRotAxis is vcrs(tarAccOld,tarAcc).  //the axis that we should rotate the acc vec around
		set tarAccOld to tarAcc.
		set tarVelLast to tarVel.
		
		local tarAccTemp is angleaxis(accAngRot * travelTime * 0.5,accRotAxis) * tarAcc. //the average acceleration in a turn during the travelTime
		set tarPosNew to tarPos + tarVel * travelTime + tarAccTemp:normalized * (0.5*tarAccTemp:mag*(travelTime^2)).

		for i in Range(5) {
			set bulletSpeed to muzzleVel + vdot(tarPosNew:normalized,shipVelocitySurface).
			set travelTime to min(15, tarPosNew:mag / bulletSpeed).
			set tarAccTemp to angleaxis(accAngRot * travelTime * 0.5,accRotAxis) * tarAcc. //the average acceleration in a turn during the travelTime
			set tarPosNew to tarPos + tarVel * travelTime + tarAccTemp:normalized * (0.5*tarAccTemp:mag*(travelTime^2)).
		}
		set tarPosNew to tarPosNew + tarVel * dT2 - shipVelocitySurface * dT2.
		//set tarPosNew to tarPosNew + tarVel * dT2 * 0 - shipVelocitySurface * dT2 * 0.
		
		
		
		set h_vel to vxcl(upVector,shipVelocitySurface).
		local heightMod is upVector * (-verticalspeed * travelTime + 0.5*9.81*(travelTime^2)). //(0.5*9.81*(((tarPosNew:mag^1.002) / bulletSpeed)^2))). //taking gravity and initial vertical velocity of self into account
		local horMod is h_vel * -travelTime. //initial horizontal velocity  old: -(h_vel + h_acc*0.02) * travelTime.
		
		set focusPos to tarPosNew + heightMod + horMod.
		
		//update vecdraws
		//set vd_acc1 to vecdraw(tarPos,tarAcc,green,"",1,true,0.2).
		set vd_target:start to tarPos.
		set vd_target:vec to focusPos-tarPos.
		
		//set vd_acc1:start to tarPos.
		//set vd_acc1:vec to tarAcc.
		set vd_acc2:start to tarPos.
		set vd_acc2:vec to tarAccTemp.
		
		//print " bullet speed: " + round(bulletSpeed) + " m/s      " at (0,terminal:height-5).
		//print " travelTime: " + round(travelTime,2) + " s      " at (0,terminal:height-4).
		//print " height offset: " + round(heightMod:mag) + " m      " at (0,terminal:height-3).
		//print " horis offset: " + round(horMod:mag) + " m      " at (0,terminal:height-2).
		//print " horis error: " + round(vdot(cam:facing:starvector,focusPos) * 100) + " cm       " at (0,terminal:height-1).
		
		// ### GUI
		if not g_t:visible g_t:show().
		set g_target:text to "<b>Target: <color=orange>" + targetVes:name + "</color></b>".
		set g_target_distance:text to "Distance: <b>" + round(targetVes:distance) + "m</b>".
		set g_target_speed:text to "Velocity: " + round(tarVel:mag) + "m/s".
		
		set g_target_traveltime:text to "Impact: " + round(travelTime,2) + "s, " + round(tarPosNew:mag) + "m". 
		set g_target_bulletspeed:text to "Bullet speed: " + round(bulletSpeed) + "m/s".
	}
	//else if submode = m_follow set focusPos to tarVeh:position.
	else {
		//set focusPos to focusPos * 0.9 + (shipVelocitySurface) * 0.1.
		if g_t:visible g_t:hide().
		set focusPos to v(0,0,0).
		//set focusPos to desiredHV:normalized * 500.
	}
	
	rcs off. //default to not firing
	
	if focusPos:mag > 1 {
		for t in turrets {
			local localFocusPos is focusPos - t["cam"]:position.
			//vertical hinge
			set vertAngleErr to vang(t["cam"]:facing:topvector,vxcl(t["camRotV"]:facing:starvector,localFocusPos)).
			if vdot(t["camRotV"]:facing:topvector,localFocusPos) < 0 set vertAngleErr to -vertAngleErr. 
			
			if abs(vertAngleErr < 0.8) set t["vertErrorI"] to max(-2,min(2,t["vertErrorI"] - vertAngleErr * 0.1)).
			else set t["vertErrorI"] to 0.
			
			t["servoV"]:moveto(t["rotVMod"]:getfield("rotation") - vertAngleErr - vdot(t["camRotV"]:facing:starvector,ship:angularvel) * (180/constant:pi) * dT2 + t["vertErrorI"],50).  
			
			//horizontal rotatron
			
			set horAngleErr to vang(vxcl(t["camRotH"]:facing:vector,localFocusPos),-t["camRotH"]:facing:topvector). 
			if vdot(t["camRotH"]:facing:starvector,localFocusPos) < 0 set horAngleErr to -horAngleErr.  
			set targetRot to t["rotHMod"]:getfield("rotation") - horAngleErr.
			set targetRot to targetRot - vdot(t["camRotH"]:facing:vector * -1,ship:angularvel) * (180/constant:pi) * dT2. //compensate for angular velocity of the drone
			
			if abs(horAngleErr < 0.8) set t["horErrorI"] to max(-2,min(2,t["horErrorI"] - horAngleErr * 0.1)).
			else set t["horErrorI"] to 0.
			t["servoH"]:moveto(targetRot + 0.08 + t["horErrorI"], 50).//min(100,abs(horAngleErr) * 1) 
			
			//print "horErrorI offset: " + round(horErrorI,4) + "       " at (0,terminal:height-7).
			
			local aimError is vang(t["cam"]:facing:topvector,localFocusPos).
			if aimError < 1  {
				if aimError < 0.4 and localFocusPos:mag < shoot_distance rcs on.
				
				for gunMod in t["gunMods"] {
					if gunMod:getfield("status") = "Disabled" gunMod:doevent("Toggle").
				}
				
				set t["VD"]:show to true.
				set t["VD"]:start to t["cam"]:position.
				set t["VD"]:vec to t["cam"]:facing:topvector * localFocusPos:mag.
			}
			else {
				for gunMod in t["gunMods"] {
					if gunMod:getfield("status") = "Enabled" gunMod:doevent("Toggle").
				}
				set t["VD"]:show to false.
			}
		}
	}
	else {
		for t in turrets {
			t["servoV"]:moveto(0,1).
			t["servoH"]:moveto(0,1).
		}
	}
	
	//if hasCamRoll {
	//	set rollAng to vang(upVector,vxcl( vxcl(upVector,-camRotV:facing:vector) ,-camRotH:facing:vector)).
	//	if vdot(camRotH:facing:starvector,upVector) > 0 set rollAng to -rollAng.
	//	servoR:moveto(rollAng,5).
	//}
	//
	//if hasCamArm {
	//	if ag1 servoArm:moveto( ((alt:radar - 2 + vdot(upVector,cam:position))/3) * armMod:getfield("max") ,100).
	//	else servoArm:moveto(0,100).
	//}
}
