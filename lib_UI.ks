local emptyString is "                                                                                                    ".

function horizontalLine {
	parameter line,char.
	local s is emptyString:substring(0,terminal:width - 1).
	set s to s:replace(" ",char).
	print s at (0,line).
}

function horizontalLineTo {
	parameter line,colStart,colEnd,char.
	local s is emptyString:substring(0,colEnd - colStart).
	set s to s:replace(" ",char).
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

// clears an entire line of the terminal
function clearLine {
	parameter line.
	print emptyString:substring(0,terminal:width - 1) at (0,line).
}

// clears a line from columnStart to columnEnd
function clearLineTo {
	parameter line,columnStart,columnEnd.
	local s is emptyString:substring(0,columnEnd-columnStart).
	print s at (columnStart,line).
}

function clearBox {
	parameter line,lineEnd,colStart,colEnd.
	
	until line > lineEnd {
		clearLineTo(line,colStart,colEnd).
		set line to line + 1.
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
	clearvecdraws().
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
	vecs:add(VECDRAWARGS(p, v, c, descr, 1, true,w)).
	return vecs:length - 1.
}


global vecs is list().
clearvecdraws().

////////////////////////////////////////////////////////// 