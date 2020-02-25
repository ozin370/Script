@LAZYGLOBAL on.
//This is the entry point for the quad drone program

SET CONFIG:STAT TO false.
set terminal:brightness to 1.

runoncepath("cpu_light.ks").
setLights(0,0.5,0.5).


//now run the damned thing already

clearguis().
runoncepath("cam.ks").
runoncepath("quad/lib_quad.ks").
runoncepath("quad/lib_json.ks").
runoncepath("quad/race.ks").
runoncepath("quad/lib_formation.ks").
runoncepath("quad/quad_loop.ks").
runoncepath("quad/quad_GUI.ks").
print "Running Quad setup..".
set terminal:width to 80.
set terminal:height to 60.
core:doaction("close terminal",true).

//main program
runpath("quad/quad.ks").


reboot.