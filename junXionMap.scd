(

var localAddr = NetAddr("127.0.0.1", 57120);
var fSendMsg = { arg label, msg;
	var elid = ~deviceMap.at(~hidDeviceName[msg[1]]).at(label);
	var id = (msg[1] * 127).round(1);
	localAddr.sendMsg("/hid/samplepad"++id, elid, msg[2]);
};

(~docDir ++ "/LCM.j4xml").openOS;

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
	var elid = ~deviceMap.at(~hidDeviceName[msg[1]]).at(\hat);
	var id = (msg[1] * 127).round(1);
	var physVal;
	if(msg[2].round(0.01) ==  ~deviceMap.at(~hidDeviceName[msg[1]]).at(\jhatUp).round(0.01), {
		physVal = ~deviceMap.at(~hidDeviceName[msg[1]]).at(\hatUp)
	});
	if(msg[2].round(0.01) ==  ~deviceMap.at(~hidDeviceName[msg[1]]).at(\jhatDown).round(0.01), {
		physVal = ~deviceMap.at(~hidDeviceName[msg[1]]).at(\hatDown)
	});
	localAddr.sendMsg("/hid/samplepad"++id, elid, msg[2], physVal);
}, "/jx/hat").fix;

)
