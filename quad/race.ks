@LAZYGLOBAL on.

function listGates {
	list targets in all_targets.
	set new_list to list().
	set counter to 0.
	set c to 0.
	until c = all_targets:length {
	   for target in all_targets {
		   if target:name = "Gate " + counter {
			  new_list:ADD(target).
			  set counter to counter +1.
		   }
	   }
	  set c to c + 1.
	}
	
	global gatesList is new_list.
	global gateI is -1.
}


function nextGate {
	if not(defined vd_gate) global vd_gate to vecdraw( {return v(0,0,0).}, up:vector * -50, rgba(0.1,0.5,0.1,0.6), "", 1, true, 1, true, true).
	
	set gateI to gateI + 1.
	if gateI = gatesList:length set gateI to 0.
	global targetGate is gatesList[gateI].
	
	local nextI is gateI + 1.
	if nextI = gatesList:length set nextI to 0.
	global nextTargetGate is gatesList[nextI].
	
	global gateLeft is targetGate:partstagged("left")[0].
	global gateRight is targetGate:partstagged("right")[0].
	global gateHeight is max(0,targetGate:geoposition:terrainheight).
	set vd_gate:startupdater to { return targetGate:position + up:vector * 60. }.
	
	if targetGate:rootpart:tag = "corner" set gateCorner to true.
	else set gateCorner to false.
	
	set targetString to targetGate:name.
	
	
	//setting the speed limit through the gate:
	
	local targetGateFacing is vxcl(upVector,targetGate:facing:vector):normalized.
	local nextGateFacing is vxcl(upVector,nextTargetGate:facing:vector):normalized.
		
	local gateToNextGate is vxcl(upVector,nextTargetGate:position - targetGate:position).
	local nextSideDist is vxcl(nextGateFacing,gateToNextGate):mag.
	local nextGateBehind is vdot(targetGateFacing,gateToNextGate) < 0.
	
	
	if (nextGateBehind) {
		set gateSpeed to sqrt(2*(gateToNextGate:mag / 3)*maxHA).
	}
	else if (vdot(gateToNextGate, targetGate:facing:starvector) > 0) = (vdot(gateToNextGate, nextTargetGate:facing:starvector) > 0) { //s-turn
		local facingAng is vang(targetGateFacing,gateToNextGate).
		local nextFacingAng is vang(nextGateFacing,gateToNextGate).
		
		local midDist is -20 + gateToNextGate:mag /
		(
			1.5   
			+ abs(90 - vang(up:vector, nextTargetGate:position - targetGate:position))/10 //lower speed with height slope
			+ (facingAng + nextFacingAng)/30   //lower speed with more total angle of the two turns in the s turn
		). 
		set gateSpeed to sqrt(2  * max(0.1,midDist) * maxHA).
		
		popup("S-turn SL: " + round(gateSpeed) + "m/s").
	}
	else {
		set nextGateSideVec to vcrs(upVector,nextGateFacing):normalized. //vector pointing out from the gate's *right* side
		if vang(nextGateSideVec,vxcl(upVector,targetGate:position - nextTargetGate:position)) < 90 set nextGateSideVec to -nextGateSideVec. 
		
		//set nextSideDist to nextSideDist / (1 + abs(90 - vang(up:vector, nextTargetGate:position - targetGate:position))/40). //lower speed with height slope
		
		
		local gateSideSpeed is sqrt(2*nextSideDist*maxHA).
		set nextSideDist to max(1,nextSideDist - gateSideSpeed * 0.5). //assume 0.5 second is used for orienting drone
		set gateSideSpeed to sqrt(2*nextSideDist*maxHA).
		global gateSpeed is gateSideSpeed / max(0.01,vdot(targetGateFacing,nextGateSideVec)).
	
	}
	
	
	
	
	
	//if vdot(targetGateFacing,gateToNextGate) < 0 set gateSpeed to 20 + gateToNextGate:mag/20. //next gate behind current one 
	
	set gateToNextGateOffset to gateToNextGate - nextGateFacing * min(400,gateToNextGate:mag/3).//min(min(400,abs(vdot(vcrs(upVector,targetGateFacing):normalized,gateToNextGate * 2))),gateToNextGate:mag/3).
	
	global angleToNextGate is vang(targetGateFacing,gateToNextGateOffset ).
	
	global maxApproachAngle is min(30,angleToNextGate).
	if targetGate:rootpart:tag = "straight" set maxApproachAngle to 0.5.
	if vdot(vcrs(upVector,targetGateFacing):normalized,gateToNextGateOffset) < 0 set maxApproachAngle to -maxApproachAngle.
	
	set tempFacing to angleaxis(maxApproachAngle, upVector) * targetGateFacing.
	set gateDistVecOld to gateToNextGate.
	
	
	
	set gateSpeed to max(30,min(340,gateSpeed)).
	if gateCorner set gateSpeed to min(30,gateSpeed).

	//set destinationLabel to targetString.
	
	//if kuniverse:activevessel = ship set target to targetGate.
	
	//GUI
	set g_race_gate:text to "Gate " + (gateI + 1) + "/" + gatesList:length.
	set g_race_gatespeed:text to "Speedlimit: " + round(gateSpeed) + " m/s".
	
	if defined raceLapStart and gateI = 1 and raceLapStart > 0 {
		set raceLaps to raceLaps + 1.
		local laptime is round(time:seconds - raceLapStart,2).
		if laptime < fastestLapTime and raceLaps > 1 {
			HUDTEXT("Completed lap at " + laptime + "s (-" + round(fastestLapTime - laptime,2) + "s)", 5, 2, 34, green, false).
			set fastestLapTime to laptime.
			entry("New fastest lap: " + laptime + "s").
		}
		else if raceLaps > 1 {
			HUDTEXT("Completed lap at " + laptime + "s (+" + round(laptime - fastestLapTime,2) + "s)", 5, 2, 34, red, false).
		}
		else {
			popup("Completed lap at " + laptime + "s").
			set fastestLapTime to laptime.
		}
		
		set g_race_laptime:text to "Laptime: " + laptime + "s".
		//raceLapsList:add(laptime).
		set raceLapStart to time:seconds.
		
		local lapFuelRate is max(0.0001,lastLapFuel-fuel)/laptime.
		if (fuel/lapFuelRate) <  (20 + 1.1 * laptime) and autoFuel brakes on. //refuel
		set lastLapFuel to fuel.
	}
	else if gateI = 1 {
		global raceLapStart is time:seconds.
		global lastLapFuel is fuel.
	}
}

function detectIntersect {
	local result is false.

	if gateDist < 10 {
		if vdot(h_vel:normalized,gateDistVec) < 2 {
			set sideVec to vcrs(h_vel,upVector):normalized.
			if vdot(-sideVec,gateRight:position) > 0 and vdot(sideVec,gateLeft:position) > 0 {
				set result to true.
			}
		}
	}
	return result.
}
//