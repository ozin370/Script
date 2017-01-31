parameter nn is nextnode.
HUDTEXT("Starting execute node script.", 4, 2, 30, yellow, false).

sas off.
set th to 0.
lock throttle to th.
lock steering to lookdirup(nn:deltav, ship:facing:topvector). //points to node, keeping roll the same.
wait until vang(facing:vector, steering:vector) < 1.


set maxthr to ship:maxthrust.
set max_acc to maxthr/ship:mass.
set burn_duration to nn:deltav:mag/max_acc.

HUDTEXT("Estimated burn duration: " + round(burn_duration,1) + "s", 15, 2, 20, yellow, false).

set kuniverse:timewarp:warp to 0.

set node_time to time:seconds + nn:eta.
set warp_target to eta:apoapsis + time:seconds - 15 - burn_duration/2.
		
if warp_target > time:seconds {
	set kuniverse:timewarp:mode to "rails".
	wait 0.
	kuniverse:timewarp:warpto(warp_target).
}


wait until eta:apoapsis - burn_duration/2 <= 0. //wait until we are close to executing the node
set kuniverse:timewarp:mode to "physics". //se we can manually physics warp during a burn

HUDTEXT("Begin burn. Physics warp is possible.", 5, 2, 20, yellow, false).

set dv0 to nn:deltav.

local done is false.
until done {
	if nn:deltav:mag/(max_acc*10) < 1 set warp to 0. //warp
	
	set max_acc to maxthr/ship:mass.
	if vang(facing:vector, steering:vector) > 1 { set th to 0. }
	else { set th to min(nn:deltav:mag/(max_acc*1.2), 1). }
	

	
	
	LIST engines IN engs.
	for eng in engs { if eng:ignition = true and eng:flameout = true and stage:ready { stage. } }
	
	if nn:deltav:mag < 0.05 set done to true.
	wait 0.
}

HUDTEXT("Manouver mode has been executed!", 4, 2, 30, yellow, false).

set kuniverse:timewarp:mode to "rails".
unlock steering.
set th to 0.
unlock throttle.
set ship:control:pilotmainthrottle to 0.
remove nn.