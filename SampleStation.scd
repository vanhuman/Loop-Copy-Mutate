/*
Loop/Copy/Mutate project Genetic Choir
Sample Station

GUI:
4. pitch als verticale slider?
5. tremolo als bewegende horizontale slider die volume aangeeft, tremolo in language zodat ie al in GUI runt voordat sample gestart is

Optie: eigen sample opnemen?? Dan:
1. play synth aanpassen, mono/stereo versie
2. lengte / startPos goed mappen


*/

(
s.waitForBoot {

	// --- Variables ------------------------------------------------------------------------------------------------

	var debug = false;
	var localAddr = NetAddr("127.0.0.1", 57120);
	var sRate = s.sampleRate;
	var tiltDevice = Array.newClear(4), tiltPad = Array.newClear(4), tiltSample, tiltDeviceName, tiltDeviceNameTmp;
	var devCount = 0, paramMode, deviceMap;
	var wDummy, wSamStat;
	var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height;

	tiltDeviceName = ['Destroyer Tiltpad', 'Destroyer Tiltpad', 'Destroyer Tiltpad', 'WingMan RumblePad'];
	tiltDeviceNameTmp = tiltDeviceName.copyRange(0,3);
	tiltSample = ["ME04_wrowrowmelody.wav", "TE07_Swieuwsiew.wav", "ME06_crying.wav", "TI08_bbrr-bbrr.wav"];
	paramMode = [\startLen,\tremPitch,\tremPitch, \startLen];

	// --- HID ------------------------------------------------------------------------------------------------

	deviceMap = (
		'WingMan RumblePad': (
			\yellow: 1, \green: 2, \left: 6, \right: 7,
			\hat: 15, \hatUp: 0, \hatDown: 180,
			\x: 10, \y: 13
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
	HID.postAvailable;

	// --- GUI ------------------------------------------------------------------------------------------------

	wDummy = Window().front.close;
	wSamStat = Window("Sample Station", Rect(0,0,screenWidth,screenHeight)).background_(Color.black);

	tiltDevice.size.do { |index|
		if(tiltDevice[index].notNil, {
			// define action for device
			tiltDevice[index].action = { | value, physValue, rawValue,  arrayValue, usage, page, elid |
				localAddr.sendMsg("/hid/tiltpad"++index, elid, value, physValue);
			};
			// startup TiltPad instance for device
			tiltPad[index] = TiltPad.new(
				index,
				s,
				Document.current.dir ++ "/Data/" ++ tiltSample[index],
				paramMode[index],
				wSamStat,
				deviceMap.at(tiltDeviceName[index]),
				debug
			);
		});
	};

	wSamStat.view.keyDownAction = {
		arg view, char, modifiers, unicode, keycode, key;
		// keycode.postln;
		case
		{ keycode == 17 and: { modifiers.isAlt } }
		{
				tiltDevice.size.do { |index|
					if(tiltDevice[index].notNil, { tiltPad[index].tremSynth() });
				};
		}
		;
	};

	wSamStat.onClose = {
		tiltDevice.size.do { |index|
			if(tiltDevice[index].notNil, { tiltPad[index].cleanUp() });
		};
		// OSCdef.freeAll;
		// ("(OSCdefs after free:"+AbstractResponderFunc.allFuncProxies).postcs;
		{ HID.closeAll }.defer(0.5);
	};

	if(devCount > 0, {
		wSamStat.front;
	}, {
		"General: no TiltPad devices found!".postln;
		{ HID.closeAll }.defer(0.5);
	});
}
)



// OSC IN monitor, format: OSC IN -- IP -- port -- message
thisProcess.oscInMonitor(true, addr:1);
thisProcess.oscInMonitor(true, addr:1, excl: ['/InBus','/hid/ex3d', '/ard/ana', '/midi/control']);
thisProcess.oscInMonitor(false);

