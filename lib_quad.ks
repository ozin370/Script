@LAZYGLOBAL on.

//modes
global m_hover is 2.
global m_land is 3.
global m_free is 4.
global m_bookmark is 5.
global m_pos is 6.
global m_follow is 7.
global m_patrol is 8.
global m_race is 9.
global m_fuel is 99.

function mode_string {
	if mode = m_hover return "hover".
	else if mode = m_land return "landing".
	else if mode = m_free return "freeroam".
	else if mode = m_pos return "position".
	else if mode = m_follow return "following " + tarVeh:name.
	else if mode = m_fuel return "refuel".
	else if mode = m_patrol return "patrolling".
	else if mode = m_race return "in race".
	else return "error".
}

function reverseLimit {
	parameter lex,limit,isPosEng.
	local reverseMod is lex["reverseMod"].
	local eng is lex["part"].
	local doReverse is false.
	
	//if isPosEng {
		if limit < -100 {
			set doReverse to true.
			if not(lex["inReverse"]) {
				reverseMod:doevent("Set Reverse Thrust").
				set lex["inReverse"] to true.
			}
			set limit to -limit - 200. 
			//limit is -200, = 0 + 100 = 100
			//limit is -101, = -99 + 100 = 1
		}
		else {
			if lex["inReverse"] {
				reverseMod:doevent("Set Normal Thrust").
				set lex["inReverse"] to false.
			}
		}
	//}
	
	set eng:thrustlimit to min(100, 100 + limit).
	
	return lex.
}

function dockSearch {
	parameter checkPart,originPart. //checkPart is the current part the function is working on, originPart is the part that called it (a child or parent).
	set result to core:part.
	
	for dockpart in core:element:dockingports {
		if checkPart = dockpart { set result to checkPart. } //found a match!
	}
	
	if result = core:part {	//while this is true, a match hasn't been found yet
		if checkPart:hasparent {
			if not(checkPart:parent = originPart) {
				set tempResult to dockSearch(checkPart:parent,checkPart).
				if not(tempResult = core:part) set result to tempResult. //parent returned a match.
			}
		}
		if checkPart:children:length > 0 and result = core:part {
			for child in checkPart:children {
				if not(child = originPart) and result = core:part {
					set tempResult to dockSearch(child,checkPart).
					if not(tempResult = core:part) set result to tempResult. //child returned a match.
				}
			}
		}
	}
	return result. //return the result to the caller (part or initial call from script)
}

function sortTargets {
	local sorted is list().
	list targets in tgs.
	
	local i is 0.
	local limited is false.
	
	local lowestTarget is 0.
	until i = tgs:length or i = 10 {
		local isValid is false.
		local lowestValue is 100000.
		for t in tgs {
			local tDistance is t:distance.
			if t:body = ship:body and tDistance < lowestValue and not sorted:contains(t) {
				set lowestValue to tDistance.
				set lowestTarget to t.
				set isValid to true.
			}
		}
		set i to i + 1.
		
		if isValid sorted:add(lowestTarget).
	}
	return sorted.
}

// parameter 1: A string or index number based on the list below.
// returns: a geoposition
function geo_bookmark {
	parameter bookmark.
	
	
	if bookmark = 1 or bookmark = "LAUNCHPAD" or bookmark = "KSC" return LATLNG(-0.0972078822701718, -74.5576864391954). //Kerbal space center
	else if bookmark = 2 or bookmark = "RUNWAY E" return LATLNG(-0.0502131096942382, -74.4951289901873). //East
	else if bookmark = 3 or bookmark = "RUNWAY W" return LATLNG(-0.0486697432694389, -74.7220377114077). //West
	else if bookmark = 4 or bookmark = "VAB" return LATLNG(-0.0967646955755359, -74.6187122587352). //VAB Roof
	
	else if bookmark = 5 or bookmark = "IKSC" return latlng(20.3926,-146.2514). //inland kerbal space center
	else if bookmark = 6 or bookmark = "ISLAND W" return LATLNG(-1.5173500701556, -71.9623911214353). //Island/airfield runway west
	else if bookmark = 7 or bookmark = "ISLAND E" return LATLNG(-1.51573303823027, -71.8571463011229).//Island/airfield runway east
	else if bookmark = 8 or bookmark = "POOL" return LATLNG(-0.0867719193943464, -74.6609773699654).
	//else if bookmark = "" return .
	
	
	else { print "ERROR: geolocation bookmark " + bookmark + " not found!". return latlng(90,0). }
}

//////////////////// User Interface stuff /////////////////// 
function toggleTerVec {
	if terMark { set terMark to false. }
	else set terMark to true.
	
	local i is 1.
	until i = 6 {
		set pm to pList[i].
		set vecs[pm]:show to terMark.
		set i to i + 1.
	}
}
function toggleVelVec {
	if submode = m_free {
		set vecs[markHorV]:show to true.
		set vecs[markDesired]:show to true.
	}
	else {
		if stMark { set stMark to false. }
		else set stMark to true.
		
		set vecs[markHorV]:show to stMark.
		set vecs[markDesired]:show to stMark.
		popup("Velocity and target velocity vector display toggled").
	}
}
function toggleThrVec {
	if thMark { set thMark to false. }
	else set thMark to true.
	
	set i to 0.
	for eng in engs {
		set vecs[i]:show to thMark.
		set i to i + 1.
	}
	popup("Thrust balance vector display toggled").
	//set vecs[markThrustAcc]:show to true.
}
function toggleAccVec {
	if miscMark { set miscMark to false. }
	else set miscMark to true.
	set vecs[markTar]:show to miscMark.
	//set vecs[markAcc]:show to miscMark.
	
	popup("Steering and acceleration vector display toggled").
}

function horizontalLine {
	parameter line,char.
	local i is 0.
	local s is "".
	until i = terminal:width {
		set s to char + s.
		set i to i + 1.
	}
	if line < 0 print s. //print to next line
	else print s at (0,line).
}
function horizontalLineTo {
	parameter line,colStart,colEnd,char.
	local column is colStart.
	local s is "".
	until column > colEnd {
		set s to char + s.
		set column to column + 1.
	}
	print s at (colStart,line).
}
function verticalLineTo {
	parameter column,lineStart,lineEnd,char.
	local line is lineStart.
	until line > lineEnd {
		print char at (column,line).
		set line to line + 1.
	}
}
function printQuad {
	parameter column1,column2,line1,line2,char.
	local column is column1.
	local s is "".
	until column > column2 {
		set s to char + s.
		set column to column + 1.
	}
	local line is line1.
	until line > line2 {
		print s at (column1,line).
		set line to line + 1.
	}
}

function clearLine {
	parameter line.
	local i is 0.
	local s is "".
	until i = terminal:width {
		set s to " " + s.
		set i to i + 1.
	}
	print s at (0,line).
}
function popup {
	parameter s.
	HUDTEXT(s, 5, 2, 60, yellow, false).
	if addons:available("tts") addons:tts:say(s).
	
	// context: HUDTEXT( Message, delaySeconds, style, size, colour, boolean doEcho).
	//style: - 1 = upper left - 2 = upper center - 3 = lower right - 4 = lower center
}
function warning {
	parameter s.
	HUDTEXT(s, 5, 2, 70, red, false).
	if addons:available("tts") addons:tts:say("Warning!" + s).
	
	// context: HUDTEXT( Message, delaySeconds, style, size, colour, boolean doEcho).
	//style: - 1 = upper left - 2 = upper center - 3 = lower right - 4 = lower center
}

global backlog is list().
function entry {
	parameter s.
	backlog:add(s).
	if focused console_backlog().
}
function console_backlog {
	
	local emptyLine is "                                                  ".
	local maxLines is terminal:height - bd.
	local counter is 1.
	local i is backlog:length - 1.
	until counter > maxLines or counter > backlog:length {
		print emptyLine at (0,bd+counter+1).
		print backlog[i] at (0,bd+counter+1).
		set counter to counter + 1.
		set i to i - 1.
	}
}

// console
function console_init {
	if focused = false {
		set terminal:height to 5.
		set terminal:width to 51.
		clearscreen.
		if mode = m_follow local appendStr is tarVeh:name.
		else if mode = m_pos local appendStr is destinationLabel.
		else local appendStr is "".
		print ship:name + " | Mode: " + mode_string() + " " + appendStr at (0,1).
		horizontalLine(2,"_"). 
		print "Speed:         | Fuel:     " at (0,4). 
	}
	else {
		global ld1 is 14.
		global c1 is 13.
		global c2 is 26.
		global c3 is 42.
		global rd1 is 6.
		global rd2 is rd1 + 13.
		global bd is rd2 + 11.
		
		set terminal:width to 51.
		//set terminal:height to max(terminal:height,40).
		set terminal:height to max(terminal:height, bd + 2 + 6). //6+ lines for backlog
		clearscreen.
		
		console_backlog().
		
		//local i is 0. 
		//until i = (bd+1) { print " ". set i to i + 1. }
		
		print "  HOVERBOT OS  [" + ship:name + "]" at (0,0).
		print "at " at (terminal:width-9,0).
		horizontalLine(1,"_").
		//left
		if page = 1 {
			
			print "  1 - Options" at (0,3).
			print "  2 - Hover " at (0,4).
			print "  3 - Land " at (0,5).
			print "  4 - Freeroam " at (0,6).
			print "  5 - Go to bookmark " at (0,7).
			print "  6 - Go to position  " at (0,8).
			print "  7 - Chase vessel " at (0,9).
			print "  8 - Patrol area" at (0,10).
			print "  9 - Racing course" at (0,11).
			print "  0 - Exit " at (0,12).
			if mode = m_free and doLanding local modeMarker is m_free - 1.
			else local modeMarker is mode.
			if mode < 11 {
				print "->" at (0,2 + modeMarker).
				print "<-" at (c2-5,2 + modeMarker).
			}

		}
		else {
			if showstats {
				print " 6 - Back " at (0,3).
				print " MoI pitch: " + round(pitch_inertia,3) at (0,6).
				print " MoI roll:  " + round(roll_inertia,3) at (0,7).
				print " T pitch: " + round(pitch_torque,1) at (0,9).
				print " T roll:  " + round(roll_torque,1) at (0,10).
				print " Acc pitch: " + round(pitch_acc,3) + " (" + round((pitch_torque*throttle)/pitch_inertia,3) at (0,12).
				print " Acc roll:  " + round(roll_acc,3) at (0,13).
				
				print " Speedlimit: " at (0,15).
			}
			else {
				print "  1 - Run Modes" at (0,3).
				print "  2 - Force Dock" at (0,4).
				print "  3 - Auto Refuel" at (0,5).
				print "  4 - Auto land" at (0,6).
				print "  5 - Agressive Chase" at (0,7).
				print "  6 - Vessel Stats" at (0,8).
				print "  7 - Terrain Prediction" at (0,9).
				print "  8 - Steering Display" at (0,10).
				print "  9 - Thrust Display" at (0,11).
				print "  0 - Misc Display" at (0,12).
				if mode > 10 and mode < 21 {
					print "->" at (0,2 + mode - 10).
					print "<-" at (c2-5,2 + mode - 10).
				}
				local char is "X".
				if forceDock print char at (4,4).
				if autoFuel print char at (4,5).
				if autoLand print char at (4,6).
				if agressiveChase print char at (4,7).
				
				if terMark print char at (4,9).
				if stMark print char at (4,10).
				if thMark print char at (4,11).
				if miscMark print char at (4,12).
			}
			
		}

		
		
		if all_libs_loaded { 
			if not(showstats) {
				if mode = m_hover print "Maintaining height." at (1,ld1 + 2).
				else if mode = m_land print "Landing." at (1,ld1 + 2).
				else if mode = m_free { 
					print "[WASD to steer]" at (1,ld1 + 2).
					print "Heading: " at (1,ld1 + 4). 
					print "Speedlimit:" at (1,ld1 + 6). 
				}
				else if mode = m_race {
					print "RACE ON!" at (1,ld1 + 2).
				}
				else {
					if submode = m_follow {
						print "Chasing vessel:" at (1,ld1 + 2).
						print tarVeh:name at (1,ld1 + 4).
						if tarVeh:loaded { print tarPart:name at (1,ld1 + 5). } 
					}
					else if mode = m_patrol print "Patrolling area. [WASD]" at (1,ld1 + 2).
					else {
						print "Going to destination." at (1,ld1 + 2).
						print "Pos: " + destinationLabel at (1,ld1 + 4). 
					}
					print "Distance:" at (1,ld1 + 7).
					print "Height D:" at (1,ld1 + 8).
					print "LAT:" at (1,ld1 + 10).
					print "LNG:" at (11,ld1 + 10).
					print "Heading:" at (1,ld1 + 11).
				}
			
			
			
			
				//right
				
				print "Hover Height:" at (c2,3).
				
				print "Velocity limit:" at (c2,5).
				
				
				print "--------[STATS]---------" at (c2,rd1 + 3).
				print "FUEL |                 |" at (c2,rd1 + 5).
				print "TWR (local):" at (c2,rd1 + 7).
				
				print "Drone Mass:" at (c2,rd1 + 9).
				print "Payload:" at (c2,rd1 + 10).
				
				print "--------[FLIGHT]--------" at (c2, rd2).
				print "  Vertical V:" at (c2,rd2 + 2).
				print "Horizontal V:" at (c2,rd2 + 3).
				print "Radar height:" at (c2,rd2 + 5).
				print "Height error:" at (c2,rd2 + 6).
				
				horizontalLineTo(ld1,0,22,"-").
				horizontalLineTo(rd1,c2-1,terminal:width-1,"_").
				verticalLineTo(c2-3,2,bd-1,"||").
			}
		}
		else print "Configuring stuff.." at (1,ld1 + 2).
		
		
		horizontalLine(bd,"=").
	}
}

/////////////////////// VECTORS ///////////////////////////

// vecs_clear().
function vecs_clear {
	if vecs:length > 0 {
		for vd in vecs {
			set vd:SHOW TO false.
		}
		vecs:clear.
	}
}

// set [variable] to vecs_add([position],[vector],[color],[string]).
// returns: list index. 
// example: 
//  Create a vecdraw:
//  set velocityVec to vecs_add(ship:position,velocity:orbit,blue,round(velocity:orbit:mag) + " m/s").
//  Update it's starting position:
//  set vecs[velocityVec]:start to ship:position.
function vecs_add {
	parameter p,v,c,descr,w.
	vecs:add(VECDRAWARGS(p, v, c, descr, 1, false,w)).
	return vecs:length - 1.
}
function vecs_add_v {
	parameter p,v,c,descr,w.
	vecs:add(VECDRAWARGS(p, v, c, descr, 1, true,w)).
	return vecs:length - 1.
}

global vecs is list().
if vecs:length > 0 vecs_clear().

////////////////////////////////////////////////////////// 

function MaxShipThrust
{
    local mth to 0.
    for eng in engs {
		set mth to mth + eng:MAXTHRUST* (eng:ISP/eng:VISP).
    }
    return mth.
}
function availableShipThrust
{
    local ath to 0.
    for eng in engs {
		//set ath to ath + vdot(ship:facing:vector,eng:facing:vector * eng:AVAILABLETHRUST). 
		set ath to ath + eng:AVAILABLETHRUST.
    }
    return ath.
}

function nz { //"not zero" , NaN protection
	parameter float.
	if abs(float) < 0.001 {
		set float to 0.001.
	}
	return float.
}

function toRad {
	parameter n.
	return n * ( constant:pi / 180).
}

///////////////////////// ksLIB team's PID controller ////////////////////////////
// This file is distributed under the terms of the MIT license, (c) the KSLib team



function PID_init {
  parameter
    Kp,      // gain of position
    Ki,      // gain of integral
    Kd,      // gain of derivative
    cMin,  // the bottom limit of the control range (to protect against integral windup)
    cMax.  // the the upper limit of the control range (to protect against integral windup)

  local SeekP is 0. // desired value for P (will get set later).
  local P is 0.     // phenomenon P being affected.
  local I is 0.     // crude approximation of Integral of P.
  local D is 0.     // crude approximation of Derivative of P.
  local oldT is -1. // (old time) start value flags the fact that it hasn't been calculated
  local oldInput is 0. // previous return value of PID controller.

  // Because we don't have proper user structures in kOS (yet?)
  // I'll store the PID tracking values in a list like so:
  //
  local PID_array is list(Kp, Ki, Kd, cMin, cMax, SeekP, P, I, D, oldT, oldInput).

  return PID_array.
}.

function PID_seek {
  parameter
    PID_array, // array built with PID_init.
    seekVal,   // value we want.
    curVal.    // value we currently have.

  // Using LIST() as a poor-man's struct.

  local Kp   is PID_array[0].
  local Ki   is PID_array[1].
  local Kd   is PID_array[2].
  local cMin is PID_array[3].
  local cMax is PID_array[4].
  local oldS   is PID_array[5].
  local oldP   is PID_array[6].
  local oldI   is PID_array[7].
  local oldD   is PID_array[8].
  local oldT   is PID_array[9]. // Old Time
  local oldInput is PID_array[10]. // prev return value, just in case we have to do nothing and return it again.

  local P is seekVal - curVal.
  local D is oldD. // default if we do no work this time.
  local I is oldI. // default if we do no work this time.
  local newInput is oldInput. // default if we do no work this time.

  local t is time:seconds.
  local dT is t - oldT.

  if oldT < 0 {
    // I have never been called yet - so don't trust any
    // of the settings yet.
  } else {
    if dT > 0 { // Do nothing if no physics tick has passed from prev call to now.
     set D to (P - oldP)/dT. // crude fake derivative of P
     local onlyPD is Kp*P + Kd*D.
     if (oldI > 0 or onlyPD > cMin) and (oldI < 0 or onlyPD < cMax) { // only do the I turm when within the control range
      set I to oldI + P*dT. // crude fake integral of P
     }.
     set newInput to onlyPD + Ki*I.
    }.
  }.

  set newInput to max(cMin,min(cMax,newInput)).

  // remember old values for next time.
  set PID_array[5] to seekVal.
  set PID_array[6] to P.
  set PID_array[7] to I.
  set PID_array[8] to D.
  set PID_array[9] to t.
  set PID_array[10] to newInput.

  return newInput.
}.

//

function PD_init {
  parameter
    Kp,      // gain of position
    Kd,      // gain of derivative
    cMin,  // the bottom limit of the control range (to protect against integral windup)
    cMax.  // the the upper limit of the control range (to protect against integral windup)

  local SeekP is 0. // desired value for P (will get set later).
  local P is 0.     // phenomenon P being affected.
  local D is 0.     // crude approximation of Derivative of P.
  local oldT is -1. // (old time) start value flags the fact that it hasn't been calculated
  local oldInput is 0. // previous return value of PID controller.

  // Because we don't have proper user structures in kOS (yet?)
  // I'll store the PID tracking values in a list like so:
  //
  local PD_array is list(Kp, Kd, cMin, cMax, SeekP, P, D, oldT, oldInput).

  return PD_array.
}.

function PD_seek {
  parameter
    PID_array, // array built with PID_init.
    seekVal,   // value we want.
    curVal.    // value we currently have.

  // Using LIST() as a poor-man's struct.

  local Kp   is PID_array[0].
  local Kd   is PID_array[1].
  local cMin is PID_array[2].
  local cMax is PID_array[3].
  local oldS   is PID_array[4].
  local oldP   is PID_array[5].
  local oldD   is PID_array[6].
  local oldT   is PID_array[7]. // Old Time
  local oldInput is PID_array[8]. // prev return value, just in case we have to do nothing and return it again.

  local P is seekVal - curVal.
  local D is oldD. // default if we do no work this time.
  local newInput is oldInput. // default if we do no work this time.

  local t is time:seconds.
  local dT is t - oldT.

  if oldT < 0 {
    // I have never been called yet - so don't trust any
    // of the settings yet.
  } else {
    if dT > 0 { // Do nothing if no physics tick has passed from prev call to now.
     set D to (P - oldP)/dT. // crude fake derivative of P
     set newInput to Kp*P + Kd*D.
    }.
  }.

  set newInput to max(cMin,min(cMax,newInput)).

  // remember old values for next time.
  set PID_array[4] to seekVal.
  set PID_array[5] to P.
  set PID_array[6] to D.
  set PID_array[7] to t.
  set PID_array[8] to newInput.

  return newInput.
}.

//

function P_init {
	parameter
	Kp,      // gain of position
	cMin,  // the bottom limit of the control range (to protect against integral windup)
	cMax.  // the the upper limit of the control range (to protect against integral windup)

	local PD_array is list(Kp, cMin, cMax).
	return PD_array.
}.

function P_seek {
	parameter
	PID_array, // array built with PID_init.
	seekVal,   // value we want.
	curVal.    // value we currently have.

	local Kp   is PID_array[0].
	local cMin is PID_array[1].
	local cMax is PID_array[2].

	local P is seekVal - curVal.
	return max(cMin,min(cMax,Kp*P)).
}.

print "library loaded.".
