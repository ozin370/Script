set foreVec to vecdraw(v(0,0,0),v(0,0,0),cyan,"fore",1,true,0.2).
set topVec to vecdraw(v(0,0,0),v(0,0,0),magenta,"top",1,true,0.2).
set starVec to vecdraw(v(0,0,0),v(0,0,0),green,"star",1,true,0.2).

set local_parts to list().
set local_modules to list().
for cur_part in ship:parts {
	clearscreen.
	local foo is highlight(cur_part,RGB(0,1,1)).
	ag1 off.
	set detected to false.
	print cur_part:name.
	print "---------------------------".
	for cur_module_str in cur_part:modules {
		set cur_module to cur_part:GETMODULE(cur_module_str).
		print cur_module:name.
		if cur_module:allfields:length > 0 { 
			for i in cur_module:allfields { 
				print "...f: " + i.
				
			}
		}
		if cur_module:allevents:length > 0 { for i in cur_module:allevents { print "...e: " + i. } }
		if cur_module:allactions:length > 0 { for i in cur_module:allactions { print "...A: " + i. } }
		if cur_module:hasfield("crossfeed") { print "Crossfeed: " + cur_module:getfield("crossfeed"). }
		//if cur_module:HASFIELD("port name") { local_parts:add(cur_part). set detected to true. }
	}
	if cur_part = ship:rootpart { print "children: ". print cur_part:children. }
	else {
		print "parent: " + cur_part:parent.
		print "children: ".
		print cur_part:children.
		print "Number of resources: " + cur_part:resources:length.
	}
	print "stage: " + cur_part:stage.
	print "------------------------------------".
	
	
	set foreVec:start to cur_part:position.
	set topVec:start to cur_part:position.
	set starVec:start to cur_part:position.
	
	set foreVec:vec to cur_part:facing:vector.
	set topVec:vec to cur_part:facing:topvector.
	set starVec:vec to cur_part:facing:starvector.
	
	wait until ag1.
	set foo:ENABLED to false.
	//for cur_module in cur_part:modules {
	//	if cur_part:GETMODULE(cur_module):HASEVENT("control from here") and detected {
	//		local_modules:add(cur_part:GETMODULE(cur_module)). 
	//	}
	//}
	
}