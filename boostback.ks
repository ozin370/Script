parameter runmode is 0, payload is ship.

clearvecdraws().
loaddist(80000). //flying and suborbital

wait until ship:unpacked.
for ms in core:part:modules { //for some reason terminal sometimes closes on dock
	set m to core:part:getmodule(ms).
	if m:hasaction("Open Terminal") m:doevent("Open Terminal").
}

print "Boostback script running.".
local gloc is LATLNG(-0.0972078822701718, -74.5576864391954). //Launchpad
//local gloc is LATLNG(-3.23298785264088, -7.00094930496598). //sandy shore
//local gloc is LATLNG(-6.7266088153308, 28.6039900741362). //kerbins heart
//local gloc is LATLNG(6.84003072705819, -62.3143155921253). //island resort


sas off.
rcs on.

local th is 0.
lock throttle to th.

kuniverse:forceactive(ship).

wait until addons:tr:hasimpact.
local st is vxcl(up:vector, gloc:position - addons:tr:impactpos:position).
//local st is heading(gloc:heading,0):vector.
lock steering to lookdirup(st,ship:facing:topvector).



set steeringmanager:pitchtorqueadjust to 2.
set steeringmanager:yawtorqueadjust to 2.

if runmode = 0 {
	wait 0.
	
	set steeringmanager:maxstoppingtime to 4.

	list engines in engs.
	for eng in engs {
		//set eng:gimbal:limit to 0.
		eng:shutdown().
	}

	wait until vang(steering:vector,facing:vector) < 20.
	
	//set steeringmanager:pitchtorqueadjust to 0.
	//set steeringmanager:yawtorqueadjust to 0.
	
	
	for eng in engs {
		//set eng:gimbal:limit to 100.
		eng:activate().
	}
	set th to 1.
}

when altitude < body:atm:height and verticalspeed < 0 then {
	for m in ship:modulesnamed("ModuleAnimateGeneric") {
		if m:hasevent("deploy fins") m:doevent("deploy fins").
	}
	return false.
}

set steeringmanager:maxstoppingtime to 2.5.
addons:tr:settarget(gloc).

set oldT to time:seconds - 0.02.
set oldV to verticalspeed.

local height_offset is estimate_height() + 5.
local th_pid is pidloop(0.3,0.1,0.001,-1,1).

set vd_hit to vecdraw(gloc:position,up:vector * 500, red, "", 1, true, 30).
set vd_tar to vecdraw(gloc:position,up:vector * 500, green, "", 1, true, 30).
set vd_error to vecdraw(v(0,0,0),v(0,0,0), yellow, "", 1, true, 0.5).

set burn_pitch to 23.
when altitude < 15000 and runmode = 1 then {
	set burn_pitch to vang(up:vector,-velocity:surface).
	print "pitch at burn start: " + round(burn_pitch,2) at (0,17).
	return false.
}

local done is false.
until done {
	if ship:status = "landed" break.
	
	if runmode = 0 {
		
		if addons:tr:hasimpact {
			local offset is vxcl(gloc:position-body:position,gloc:position).
			set offset:mag to 300.
			local st_vec is vxcl(up:vector, offset + gloc:position - addons:tr:impactpos:position).
			set st to st_vec.
			
			local steer_error is vang(facing:vector,st_vec).
			if steer_error < 20 set th to min(1,st_vec:mag / 15000).
			else set th to 0.
			set th to min(th,(20 - steer_error) / 20).
			
			print "dist " + round(st_vec:mag) + "          " at (0,10).
			if st_vec:mag < 150 {
				set runmode to 1.
				//if payload <> ship kuniverse:forceactive(payload). //switch to payload so it can circularize
			}
		}
		else {
			set st to vxcl(up:vector,-velocity:orbit).
			set th to 1.
		}
		
	}
	else if runmode = 1 {
		set th to 0.
		if alt:radar < 2000 gear on.
		
		set offset to vxcl(gloc:position-body:position,gloc:position).
		set offset:mag to burn_pitch * 4 * min(1,max(0,velocity:surface:mag - 300)/300).
		local target_pos is gloc:position + offset.
		set target_gloc to body:geopositionof(target_pos).
		
		set vd_hit:start to addons:tr:impactpos:position.
		set vd_tar:start to target_gloc:position.
		set vd_hit:vec to up:vector * (500 + altitude / 3).
		set vd_tar:vec to up:vector * (500 + altitude / 3).
		
		
		
		addons:tr:settarget(target_gloc).
		
		if kuniverse:activevessel = ship {
			set geo_diff to vxcl(up:vector, target_gloc:position - addons:tr:impactpos:position).
			print "dist " + round(geo_diff:mag) + "          " at (0,10).
		}
		
		set vd_error:vec to geo_diff.
		
		if vang(up:vector,facing:vector) < 80 and altitude < 15000 {
			local max_acc is ship:availablethrust / ship:mass.
			local gravityMag is body:mu / (body:radius + altitude)^2.
			//local gravityVec is -up:vector * gravityMag.
			
			if throttle = 0 {
				local dt is time:seconds - oldT.
				set oldT to time:seconds.
				set accel to (verticalspeed-oldV)/dt.
				set oldV to verticalspeed.
				
				set accel to max(0,accel - gravityMag).

				print "drag acc: " + round(accel,2) + " m/s2        " at (0,20).
				
			}
			else set accel to 0.
			
			local max_v_acc is vdot(up:vector,facing:vector) * max_acc - gravityMag. // + accel.
			
			set vdist to altitude - max(0,max(addons:tr:impactpos:terrainheight,gloc:terrainheight)) - 28. //height_offset.
			set desiredVV to -sqrt( 2 * max(0.01,vdist + verticalspeed * 0.04) * max_v_acc ).
			
			print "vertical dist: " + round(vdist/1000,1) + " km        " at (0,11).
			print "desired v speed: " + round(desiredVV) + " m/s        " at (0,14).
			print "speed error: " + round(verticalspeed - desiredVV,1) + " m/s        " at (0,16).
			
			print "height offset: " + round(height_offset,1) at (0,18).
			
			
			
			set th_pid:setpoint to min(-3,desiredVV).
			set th to 0 + th_pid:update(time:seconds,verticalspeed).
			
			if altitude < 20000 rcs off.
			
			if verticalspeed > -2 and altitude < 10000 set th to 0.
		}
		
		// ### Steering / gliding ###
		if altitude > body:atm:height set st to -velocity:surface.
		else if throttle > 0.05 {
			
			
			//set st to -velocity:surface * angleaxis(ang,axis).
			if velocity:surface:mag > 550 set st to -velocity:surface.
			else if vdist < 150 {
				set st to -velocity:surface + vxcl(up:vector,-velocity:surface) * min(2,(vdist - 200)/300).
			}
			else {
				set geo_diff to vxcl(up:vector, (gloc:position + offset * 0.5) - addons:tr:impactpos:position).
				local ang is 0.
				
				local strength is min(50,abs(300 - velocity:surface:mag))/ 50.
				if velocity:surface:mag > 300 set ang to -min(15,geo_diff:mag / 6) * strength.
				else set ang to min(20,geo_diff:mag / 3) * strength.
				
				local axis is vcrs(-velocity:surface,geo_diff).
				set st to -velocity:surface * angleaxis(ang,axis).
			}
			
			
		}
		else { //use body lift to decrease hit pos error
			local ang is min(15,geo_diff:mag / 5).
			local axis is vcrs(-velocity:surface,geo_diff).
			set st to -velocity:surface * angleaxis(-ang,axis).
		}
	}
	
	wait 0.
}

for m in ship:modulesnamed("ModuleAnimateGeneric") {
	if m:hasevent("retract fins") m:doevent("retract fins").
}

unlock throttle.
unlock steering.
set ship:control:pilotmainthrottle to 0.
sas on.
rcs on.

function estimate_height {
	local highest is 0.
	for p in ship:parts {
		local part_h is vdot(-facing:vector,p:position).
		set highest to max(part_h,highest).
	}
	return highest.
}

function loaddist {
	parameter dist.
	// 30 km for in-flight
	// Note the order is important.  set UNLOAD BEFORE LOAD,
	// and PACK before UNPACK.  Otherwise the protections in
	// place to prevent invalid values will deny your attempt
	// to change some of the values:
	SET KUNIVERSE:DEFAULTLOADDISTANCE:FLYING:UNLOAD TO dist.
	SET KUNIVERSE:DEFAULTLOADDISTANCE:FLYING:LOAD TO dist-500.
	WAIT 0.
	SET KUNIVERSE:DEFAULTLOADDISTANCE:FLYING:PACK TO dist - 1.
	SET KUNIVERSE:DEFAULTLOADDISTANCE:FLYING:UNPACK TO dist - 1000.
	WAIT 0.

	SET KUNIVERSE:DEFAULTLOADDISTANCE:SUBORBITAL:UNLOAD TO dist.
	SET KUNIVERSE:DEFAULTLOADDISTANCE:SUBORBITAL:LOAD TO dist-500.
	WAIT 0.
	SET KUNIVERSE:DEFAULTLOADDISTANCE:SUBORBITAL:PACK TO dist - 1.
	SET KUNIVERSE:DEFAULTLOADDISTANCE:SUBORBITAL:UNPACK TO dist - 1000.
	WAIT 0.
}

function simulate_landing {
	parameter
		v_init,  // initial velocity vector at start position of burn.
		t_delta is 0.5. // seconds per timestep in the simulation loop.

	local pos is V(0,0,0). // current new position relative to start pos.
	local t is 0. // elapsed time since burn start.
	local vel is v_init. // current new velocity.  Goal is for this to zero out.
	local prev_vel is v_init*2. // force `reverse` flag not to trigger the first time.
	local prev_a_vec is v(0,0,0).
	local m is ship:mass. // current mass (m_init minus spent fuel).
	local isp is simple_isp().

	// (if the sim loop starts with the velocity *already* ascending, then it doesn't
	// start checking for ascending until after it has started descending at least
	// once during the sim loop.)

	until false { // will break explicitly down below.
		local up_vec is (pos - body:position).             // vector up from center of body to cur position.
		local up_unit is up_vec:NORMALIZED.

		local reversed is (VDOT(vel, prev_vel) < 0).
		if reversed {
			break.
		}
		

		local r_square is up_vec:SQRMAGNITUDE.
		local g is body:mu/r_square.                           // grav accel, as scalar.
		local eng_a_vec is ship:availablethrustat(1)*(- vel:normalized) / m.  // engine accel, as vector.
		local a_vec is eng_a_vec - up_unit*g.             // total accel, as vector.

		set prev_vel to vel.
		set prev_a_vec to a_vec.
		local avg_a_vec is 0.5*(a_vec+prev_a_vec). 
		set vel to vel + avg_a_vec*t_delta.             // new velocity = old vel + accel*deltaT
		local avg_vel is 0.5*(vel+prev_vel).
		local prev_pos is pos.
		set pos to pos + avg_vel*t_delta.               // new pos = old pos + velocity*deltaT.
		set m to m - (ship:availablethrustat(1) / (9.802*isp)*t_delta). // new mass = old mass minus fuel we just spent.
		if m <= 0 { break. } // Ship is not allowed to be composed of anti-matter.
		set t to t + t_delta.
	}


	return Lex(
	"pos", pos,    // position where it stops relative to a start position of v(0,0,0)
	"vel", vel,    // velocity at the moment it ends
	"seconds", t,  // how many seconds will it take to stop.
	"mass", m,     // what will be the new mass after the burn due to spent fuel.  if <=0, then it aborts early.
	"draws", draws // vecdraws to display.
	).
}