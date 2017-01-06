@LAZYGLOBAL on.
// autopilot
runoncepath("lib_UI.ks").
set terminal:brightness to 1.

//sas off.
set st to lookdirup(ship:facing:vector,up:vector).
//lock steering to st.
set th to throttle.
lock throttle to th.

// #### PID ###
// >>
	function init_pitch_pid {
	  return PIDLOOP(0.01, 0.005, 0.003, -1, 1).
	}
	function init_roll_pid {
	  return PIDLOOP(0.005, 0.00005, 0.001, -1, 1).
	}
	function init_bank_pid {
	  return PIDLOOP(3, 0.00, 5, -45, 45).
	}
	function init_throt_pid {
	  return PIDLOOP(0.1, 0.001, 0.05, 0, 1).
	}

	set pitchPid to init_pitch_pid().
	set bankPid to init_bank_pid().
	set rollPid to init_roll_pid().
	set throtPid to init_throt_pid().
// << 

// ### Initual Stuff / default vars ###
// >>
	set targetSpeed to 140.
	set targetAlt to 1000.
	set controlSpeed to true.
	set controlAlt to false.
	
	//settings default vars
	set stallSpeed to 70.
	set stableAoA to 10.
	set maxAoA to 15.
	
	set testString to "tada".
// <<

set hudString to "test".
function testFunction {
	parameter s.
	hudtext(s,5, 2, 35, yellow, false).
}

// ### Console ###
// >>



set defaultMenu to list(
	//list(name,type,get/set function,increment multiplier (for numbers)).

	list("Speed:",		"number", 	{ parameter p is "x". if p <> "x" set targetSpeed to p. return targetSpeed. }, 1),
	list("Altitude:",	"number", 	{ parameter p is "x". if p <> "x" set targetAlt to p. return targetAlt. }, 10),
	list("",			"text"),
	list("Throttle:",	"bool" , 	{ parameter p is "x". if p <> "x" set controlSpeed to p. return controlSpeed. }),
	list("Altitude:",	"bool" , 	{ parameter p is "x". if p <> "x" set controlAlt to p. return controlAlt. }),
	list("",			"text"),
	list("Test text",	"string",	{ parameter p is "x". if p <> "x" set hudString to p. return hudString. }),
	list("Show on HUD",	"action",	{ testFunction(hudString).}),
	list("",			"text"),
	list("[SETTINGS]",	"menu" , 	{ return settingsMenu. }),
	list("",			"text")
).

set settingsMenu to list(
	//list(name,type,get/set function,increment multiplier (for numbers)).

	list("Stall Spd:",	"number", 	{ parameter p is "x". if p <> "x" set stallSpeed to p. return stallSpeed. }, 1),
	list("AoA:",		"number", 	{ parameter p is "x". if p <> "x" set stableAoA to p. return stableAoA. }, 0.1),
	list("Max AoA:",	"number", 	{ parameter p is "x". if p <> "x" set maxAoA to p. return maxAoA. }, 0.1),
	list("",			"text"),
	list("[SUBMENU 1]",	"menu", 	{ return subMenu1. }),
	list("[SUBMENU 2]",	"menu", 	{ return subMenu2. }),
	list("[BACK]",		"backmenu", { return defaultMenu. })
).

set subMenu1 to list(
	//list(name,type,get/set function,increment multiplier (for numbers)).
	list("Just a dummy submenu","text"),
	list("Test str:",	"string", 	{ parameter p is "x". if p <> "x" set testString to p. return testString. }),
	list("[BACK]",	"backmenu" , 	{ return settingsMenu. })
).

set subMenu2 to list(
	//list(name,type,get/set function,increment multiplier (for numbers)).
	list("Another submenu","text"),
	list("[BACK]",	"backmenu" , 	{ return settingsMenu. })
).

// the list that defines the menu items: their names, types, and function
set menuItems to defaultMenu.


function drawAll {
	set terminal:width to 51.
	set terminal:height to 40.
	clearscreen.
	terminal:input:clear(). //clear inputs for new menues just in case..
	set selectedLine to 0.
	
	//column starts
	set C1 to 3. //menu item description starts here
	set C2 to C1 + 12. //menu item values start here
	set C3 to C2 + 8. //the increment display thingy starts here
	
	set menuL to 6. //menu option #1 starts at this line
	
	print "TEST TEST TEST TEST TEST TEST TEST TEST" at (0,0).
	print "AutoPilot - " + ship:name at (1,1).
	horizontalLine(2,"_").
	
	print "Targets:" at (C1,menuL-2).
	horizontalLineTo(menuL-1,C1,C3-1,"-").
	horizontalLineTo(menuL + menuItems:length,C1,C3-1,"-").
	
	local notFoundSelectable is true.
	local i is 0.
	inputs().
	until i = menuItems:length {
		if notFoundSelectable and menuItems[i][1] <> "text" {
			set selectedLine to i.
			set notFoundSelectable to false.
		}
		updateLine(i).
		
		//debug
		print menuItems[i][0] + " = " + menuItems[i][1] at (1,menuL + menuItems:length + 2 + i).
		
		set i to i + 1.
	}
	drawMarker().
}

function drawMarker {
	print ">> " at (C1-3,menuL + selectedLine).
	if lineType = "number" {
		set suffixString to "-+" + incrOptions[incrI] * menuItems[selectedLine][3].
		print suffixString at (C3 + 1,menuL + selectedLine).
	}
	else if lineType = "bool" {
		set suffixString to menuItems[selectedLine][2]():tostring().
		print suffixString at (C3 + 1,menuL + selectedLine).
	}
}

function clearMarkers {
	print "   " at (C1-3,menuL + selectedLine).
	
	if lineType = "number" or lineType = "bool" {
		local emptyString is "                             ".
		print emptyString:substring(0,suffixString:length) at (C3 + 1,menuL + selectedLine).
	}
}
// <<

// ### Input ###
// >>
set typingNumber to false.
set typingString to false.
set lineType to menuItems[0][1].
set selectedLine to 0.

function inputs {
	if typingNumber { //currently recording numbers, so ignore all other commands
		updateLine(selectedLine,numberString).
		if terminal:input:haschar() {
			local inp is terminal:input.
			local ch is inp:getchar().
			if ch:tonumber(99) <> 99 or ch = "." or ch = "-" {
				set numberString to numberstring + ch.
				
			}
			else if ch = inp:backspace {
				if numberString:length > 0 set numberString to numberString:remove(numberString:length-1,1).
			}
			else if ch = inp:enter or ch = "d" or ch = "w" or ch = "s"{
				set typingNumber to false.
				local converted is numberString:tonumber(-9999).
				if converted <> -9999 { //valid
					updateLine(selectedLine,numberString).
					menuItems[selectedLine][2](converted). //change the actual variable through the function stored in the lex
				}
				set numberString to "".
			}
		}
	}
	else if typingString { //currently recording text
		updateLine(selectedLine,stringString).
		if terminal:input:haschar() {
			local inp is terminal:input.
			local ch is inp:getchar().
			
			if ch = inp:enter {
				set typingString to false.
				updateLine(selectedLine,stringString).
				menuItems[selectedLine][2](stringString).
				set stringString to "".
			}
			else if ch = inp:backspace {
				if stringString:length > 0 set stringString to stringString:remove(stringString:length-1,1).
			}
			else set stringString to stringString + ch.
		}
	}
		
	else if terminal:input:haschar() { //not recording, so enable all other commands
		local inp is terminal:input.
		local ch is inp:getchar().
		set lineType to menuItems[selectedLine][1].

		local oldLine is selectedLine.
		if ch = "w" or ch = inp:upcursorone {
			clearMarkers().
			
			set selectedLine to selectedLine - 1.
			if selectedLine < 0 set selectedLine to menuItems:length - 1.
			until menuItems[selectedLine][1] <> "text" { //skip text lines as they have no values
				set selectedLine to selectedLine - 1.
				if selectedLine < 0 set selectedLine to menuItems:length - 1.
			}
			
			set incrI to 2.
			updateLine(oldLine).
		}
		else if ch = "s" or ch = inp:downcursorone {
			clearMarkers().
			set selectedLine to selectedLine + 1.
			if selectedLine >= menuItems:length set selectedLine to 0.
			until menuItems[selectedLine][1] <> "text" { //skip text lines as they have no values
				set selectedLine to selectedLine + 1.
				if selectedLine >= menuItems:length set selectedLine to 0.
			}
			
			set incrI to 2.
			updateLine(oldLine).
		}
		else if ch = "a" or ch = inp:leftcursorone adjust(-1).
		else if ch = "d" or ch = inp:rightcursorone adjust(1).
		else if ch = "q" { set incrI to max(0,incrI - 1). }
		else if ch = "e" { set incrI to min(incrOptions:length - 1,incrI + 1). }
		else if lineType = "number" and (ch:tonumber(99) <> 99 or ch = "-" or ch = inp:enter) {
			set typingNumber to true.
			if ch = inp:enter set numberString to menuItems[selectedLine][2]():tostring().
			else set numberString to ch. 
		}
		else if ch = inp:enter {
			if lineType = "menu" or lineType = "backmenu" or lineType = "bool" or lineType = "action" adjust(0).
			else if lineType = "string" {
				set stringString to menuItems[selectedLine][2]().
				set typingString to true.
			}
			//else if lineType = "action" menuItems[selectedLine][2]().
		}
		else if ch = inp:backspace {
			local i is 0.
			until i >= menuItems:length {
				if menuItems[i][1] = "backmenu" {
					set selectedLine to i.
					adjust(1).
					set i to menuItems:length.
				}
				set i to i + 1.
			}
		}
		
		set lineType to menuItems[selectedLine][1].
		clearMarkers().
		drawMarker().
		updateLine(selectedLine).
		
		inp:clear().
	}
	
}

set blink to 0.
function updateLine {
	parameter line,val is "x".
	local nameStr is menuItems[line][0].
	local valType is menuItems[line][1].
	
	if val = "x" and valType <> "text" and valType <> "action" { 
		set val to menuItems[line][2]().
		if valType = "number" set val to val:tostring().
	}
	
	local blinkStr is "".
	if (typingNumber or typingString) and line = selectedLine { //blinking cursor when typing in
		if blink < 10 set blinkStr to "_".
		else set blinkStr to " ".
		set blink to blink + 1.
		if blink > 20 set blink to 0.
	}
	
	
	local valStr is "".
	if valType = "bool" {
		if val set valStr to "[ X ]".
		else set valStr to   "[   ]".
	}
	else if valType = "number" {
		//if not typingNumber and val:tonumber(-99.9999) <> -99.9999 and val:tonumber() > 9999 set valStr to round(val:tonumber() / 1000,1) + "K".
		if not typingNumber and val > 9999 set valStr to round(val:tonumber() / 1000,1) + "K".
		else set valStr to val:tostring + blinkStr.
	}
	else if valType = "string" {
		set val to val + blinkStr.
		set valStr to val:substring(max(0,val:length - (C3-C2)),min(val:length,C3-C2)).
	}
	else set valStr to "".
	set valStr to valStr:padleft(C3-C2).
	local finalStr is nameStr:padright(C2-C1):substring(0,C2-C1) + valStr.
	print finalStr at (C1,menuL + line).
}


set incrOptions to list (0.1,1,10,100,1000).
set incrI to 2.

function adjust {
	parameter sign.
	local func is menuItems[selectedLine][2].
	set lineType to menuItems[selectedline][1].
	
	if lineType = "number" {
		func(func() + sign * incrOptions[incrI] * menuItems[selectedLine][3]).
	}
	else if lineType = "bool" {
		local val is func().
		if sign = 0 toggle val.
		else if sign < 0 set val to false.
		else set val to true.
		func(val).
	}
	else if lineType = "menu" or lineType = "backmenu" { // d
		set menuItems to func().
		drawAll().
	}
	else if lineType = "action" func().
}

// <<

drawAll().


// ### LOOP ###
until false {
	inputs().
	
	set forwardSpeed to vdot(ship:facing:vector,velocity:surface).
	set th to throtPid:Update(time:seconds, forwardSpeed - targetSpeed).
	
	
	
	
	
	wait 0.
}