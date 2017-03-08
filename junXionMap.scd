(

var localAddr = NetAddr("127.0.0.1", 57120);
var fSendMsg = { arg label, msg;
	var id = (msg[1] * 127).round(1);
	var elid = ~deviceMap.at(~hidDeviceName[id]).at(label);
	// [id,msg].postln;
	// ["/hid/samplepad"++id, elid, msg[2]].postln;
	localAddr.sendMsg("/hid/samplepad"++id, elid, msg[2]);
};

// (~docDir ++ "/LCM.j4xml").openOS;

OSCdef(\jx_x, { arg msg;
	fSendMsg.value(\x, msg);
}, "/jx/x").fix;

OSCdef(\jx_y, { arg msg;
	fSendMsg.value(\y, msg);
}, "/jx/y").fix;

OSCdef(\jx_yellow, { arg msg;
	fSendMsg.value(\yellow, msg);
}, "/jx/yellow").fix;

OSCdef(\jx_left, { arg msg;
	fSendMsg.value(\left, msg);
}, "/jx/left").fix;

OSCdef(\jx_hat, { arg msg;
	var id = (msg[1] * 127).round(1);
	var elid = ~deviceMap.at(~hidDeviceName[id]).at(\hat);
	var physVal = 1000;
	if(msg[2].round(0.01) ==  ~deviceMap.at(~hidDeviceName[id]).at(\jhatUp).round(0.01), {
		physVal = ~deviceMap.at(~hidDeviceName[id]).at(\hatUp)
	});
	if(msg[2].round(0.01) ==  ~deviceMap.at(~hidDeviceName[id]).at(\jhatDown).round(0.01), {
		physVal = ~deviceMap.at(~hidDeviceName[id]).at(\hatDown)
	});
	// [id,msg].postln;
	// ["/hid/samplepad"++id, elid, msg[2], physVal].postln;
	localAddr.sendMsg("/hid/samplepad"++id, elid, msg[2], physVal);
}, "/jx/hat").fix;

)
