/*
Loop/Copy/Mutate project Genetic Choir
Sample Station

dropdown voor samplekeuze
eenvoud, vooral over samenspelen
speciale volgorde van activering van tiltpads?
left en right button niet gebruiken (of één knop voor X en Y samen), controllers altijd actief, len/start met lag zodat het niet te veel jittert
operator controls via midi keyboard, niet via laptopkeyboard


*/

(
s.waitForBoot {

	// --- Variables ------------------------------------------------------------------------------------------------

	var debug = false, noDevicesOverride = true;
	var localAddr = NetAddr("127.0.0.1", 57120);
	var sRate = s.sampleRate;
	var tiltDevice = Array.newClear(4), tiltPad = Array.newClear(4), tiltSample, tiltDeviceName, tiltDeviceNameTmp;
	var devCount = 0, paramMode, deviceMap;
	var wDummy, wSamStat, ctrView, button = ();
	var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height;
	var recFile;

	tiltDeviceName = ['Destroyer Tiltpad', 'Destroyer Tiltpad', 'Destroyer Tiltpad', 'WingMan RumblePad'];
	tiltSample = ["ME04_wrowrowmelody.wav", "TE07_Swieuwsiew.wav", "ME06_crying.wav", "TI08_bbrr-bbrr.wav"];
	paramMode = [\startLen,\tremPitch,\tremPitch, \startLen];

	tiltDeviceNameTmp = tiltDeviceName.copyRange(0,3);
	s.recChannels = 2;

	// --- HID ------------------------------------------------------------------------------------------------

	deviceMap = ( // mapping of element id's to logical names
		'WingMan RumblePad': (
			\yellow: 1, \green: 2, \left: 6, \right: 7,
			\hat: 15, \hatUp: 0, \hatDown: 180,
			\x: 10, \y: 14
		),
		'Destroyer Tiltpad': (
			\yellow: 3, \green: 4, \left: 6, \right: 7,
			\hat: 8, \hatUp: 1, \hatDown: 5,
			\x: 0, \y: 1
		)
	);

	"General: initializing HID".postln;
	HID.findAvailable.collect { arg device, id; var index;
		index = tiltDeviceNameTmp.indexOfEqual(device.productName.asSymbol);
		if(index.notNil, {
			tiltDeviceNameTmp[index] = nil;
			tiltDevice[index] = HID.openAt(id);
			devCount = devCount + 1;
		})
	};
	// HID.postAvailable;

	// --- GUI ------------------------------------------------------------------------------------------------

	wDummy = Window().front.close;
	wSamStat = Window("Sample Station", Rect(0,0,screenWidth,screenHeight)).background_(Color.black);

	tiltDevice.size.do { |index|
		if(tiltDevice[index].notNil or: { noDevicesOverride }, {
			// define action for device
			if(tiltDevice[index].notNil, {
				tiltDevice[index].action = { | value, physValue, rawValue,  arrayValue, usage, page, elid |
					localAddr.sendMsg("/hid/tiltpad"++index, elid, value, physValue);
				};
			});
			// startup TiltPad instance for device
			tiltPad[index] = TiltPad.new(
				index,
				s,
				Document.current.dir ++ "/Data/" ++ tiltSample[index],
				paramMode[index],
				wSamStat,
				deviceMap.at(tiltDeviceName[index]),
				debug,
				false
			);
			});
	};

	ctrView = View(wSamStat, Rect(4, screenHeight - 100, screenWidth - 8, 80)).background_(Color.white);
	// 4.do { arg i;
	// 	button[i.asSymbol] = (SmoothButton(ctrView, Rect(i*150+10,10,145,40))
	// 		.border_(1).radius_(2).canFocus_(false)
	// 		.states_([
	// 			[ (i+1)+"- start recording", Color.black, Color.white ],
	// 			[ (i+1)+"- stop recording", Color.black, Color.red ],
	// 			[ (i+1)+"- playback", Color.black, Color.green ],
	// 			[ (i+1)+"- playback again", Color.black, Color.green ],
	// 			[ (i+1)+"- playback last time", Color.black, Color.green ],
	// 			[ (i+1)+"- erase??", Color.black, Color.yellow ]
	// 		])
	// 		.action_({ arg button;
	// 			switch(button.value,
	// 				1, {
	// 					("RECORDING" + s.recChannels + "channels ############################\n").warn;
	// 					recFile = thisProcess.platform.recordingsDir++"/LCM_"++
	// 					Date.getDate.format("_%y%m%d_%H%M%S.")++s.recHeaderFormat.toLower;
	// 					s.record(recFile);
	// 				},
	// 				2, { s.stopRecording },
	// 				3, { DiskPlayer.new(s, recFile, bufFramePower: 16, autoplay: true, doneAction: 2) },
	// 				4, { DiskPlayer.new(s, recFile, bufFramePower: 16, autoplay: true, doneAction: 2) },
	// 				4, { DiskPlayer.new(s, recFile, bufFramePower: 16, autoplay: true, doneAction: 2) },
	// 				6, { ("mv"+recFile+recFile++".erased").unixCmd }
	// 			);
	// 		})
	// 	);
	// };

	wSamStat.view.keyDownAction = {
		arg view, char, modifiers, unicode, keycode, key;
		var nums = [18,19,20,21,23,22,26,28], buttonIndex;
		// keycode.postln;
		case
		{ keycode == 17 and: { modifiers.isAlt } }
		{
			tiltDevice.size.do { |index|
				if(tiltDevice[index].notNil or: { noDevicesOverride }, { tiltPad[index].tremSynth() });
			};
		}
		// { nums.indexOf(keycode).notNil }
		// {
		// 	buttonIndex = nums.indexOf(keycode).asSymbol;
		// 	button[buttonIndex].valueAction_( (button[buttonIndex].value+1)%button[buttonIndex].states.size );
		// }
		;
	};

	wSamStat.onClose = {
		tiltDevice.size.do { |index|
			if(tiltDevice[index].notNil or: { noDevicesOverride }, { tiltPad[index].cleanUp() });
		};
		// OSCdef.freeAll;
		// ("(OSCdefs after free:"+AbstractResponderFunc.allFuncProxies).postcs;
		{ HID.closeAll }.defer(0.5);
	};

	if(devCount > 0 or: { noDevicesOverride }, {
		wSamStat.front;
	}, {
		"General: no TiltPad devices found!".postln;
		{ HID.closeAll }.defer(0.5);
	});
}
)


a = DiskPlayer.new(s,"/Users/Robert/---data---/Audio/random samples/oguz004a.wav", bufFramePower: 16, autoplay: true)
a.stop
a.play
a.remove


// OSC IN monitor, format: OSC IN -- IP -- port -- message
thisProcess.oscInMonitor(true, addr:1);
thisProcess.oscInMonitor(true, addr:1, excl: ['/InBus','/hid/ex3d', '/ard/ana', '/midi/control']);
thisProcess.oscInMonitor(false);

