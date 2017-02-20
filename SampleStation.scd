/*
Loop/Copy/Mutate project Genetic Choir
Sample Station

GUI:
3. startPos / len als bufferview: issue met loslaten right front button, dan verspringt de size soms naar groot
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
	var tiltDevice = Array.newClear(4), tiltPad = Array.newClear(4), tiltSample = Array.newClear(4);
	var devCount = 0, paramMode;
	var wDummy, wSamStat;
	var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height;

	tiltSample = ["ME04_wrowrowmelody.wav", "TE07_Swieuwsiew.wav", "ME06_crying.wav", nil];
	paramMode = [\startLen,\tremPitch,\startLen,\tremPitch];

	// --- SynthDefs ------------------------------------------------------------------------------------------------
	TiltPad.loadSynthDefs(s.sampleRate);

	// --- HID ------------------------------------------------------------------------------------------------

	"General: initializing HID".postln;
	HID.findAvailable.collect { arg device, id;
		if(device.productName == "Destroyer Tiltpad", {
			tiltDevice[devCount] = HID.openAt(id);
			devCount = devCount + 1;
		})
	};

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
			tiltPad[index] = TiltPad.new(index, s, Document.current.dir ++ "/Data/" ++ tiltSample[index], paramMode[index], wSamStat, debug);
		});
	};

	wSamStat.onClose = {
		tiltDevice.size.do { |index|
			if(tiltDevice[index].notNil, { tiltPad[index].cleanUp() });
		};
		HID.closeAll;
	};

	if(devCount > 0, {
		wSamStat.front;
	}, {
		"General: no TiltPad devices found!".postln;
		HID.closeAll;
	});
}
)



// OSC IN monitor, format: OSC IN -- IP -- port -- message
thisProcess.oscInMonitor(true, addr:1);
thisProcess.oscInMonitor(true, addr:1, excl: ['/InBus','/hid/ex3d', '/ard/ana', '/midi/control']);
thisProcess.oscInMonitor(false);

