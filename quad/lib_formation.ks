//follower lib, for both slave and master
global Followers is uniqueset().
global isLeading is false.
global isFollowing is false.
global formationLastUpdate is time:seconds - 1.
global formationTarget is list(0).

//Message types (from point of view from the reciever):
//	1: Add me as follower (from slave to master)
//	2: Remove me (as master), 
//  3: Stop following (as follower)
//	4: Update (as reciever)

function formationComUpdate {
	set shipMessages to ship:messages.
	until shipMessages:empty {
		set msg to shipMessages:pop.
		set cnt to msg:content.
		local msgtype is cnt[0].
		
		if msgtype = 1 { //add sender as follower
			Followers:add(msg:sender).
			set isLeading to true.
		}
		else if msgtype = 2 {
			Followers:remove(msg:sender).
			if Followers:length = 0 set isLeading to false.
		}
		else if msgtype = 4 {
			set formationLastUpdate to time:seconds.
			set formationTarget to cnt.
		}
		else if msgtype = 5 {
			set r_race:pressed to true. //start race mode 
			msg:sender:connection:sendmessage(list(2)).
		}
	}
}

//parameters: 4, 
function formationBroadcast {
	parameter velocityVec is v(0,0,0), positionVec is v(0,0,0).
	
	local i is 0.
	for f in Followers {
		local followerDist is 10 + 10 * floor(i / 2). //the first two 10m, the next two 20m etc
		
		if mod(i,2) = 0 set followerPos to angleaxis(120,up:vector) * (positionVec * followerDist).
		else set followerPos to angleaxis(-120,up:vector) * (positionVec * followerDist).
		
		f:connection:sendmessage(list(4,velocityVec,followerPos)).
		set i to i + 1.
	}
}

function raceBroadcast {
	for f in Followers {
		f:connection:sendmessage(list(5)).
	}
}