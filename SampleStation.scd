/*
Loop/Copy/Mutate project Genetic Choir
Sample Station

synthDef in this file

twee param modes:
1. startPos & length
2. pitch & tremolospeed / tremolo in language zodat ie al in GUI runt voordat sample gestart is

GUI:
1. left/right front buttons links en rechtsboven
2. hatswitch en kleurbuttons letterlijk in de interface
3. startPos / len als rangeslider met waveform display
4. pitch als verticale slider?
5. tremolo als bewegende horizontale slider die volume aangeeft

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

	tiltSample = ["ME04_wrowrowmelody.wav", "TE07_Swieuwsiew.wav", nil, nil];
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
	wSamStat = Window("Sample Station", Rect(0,0,screenWidth,screenHeight)).background_(Color.white);

	tiltDevice.size.do { |index|
		if(tiltDevice[index].notNil, {
			// define action for device
			tiltDevice[index].action = { | value, physValue, rawValue,  arrayValue, usage, page, elid |
				localAddr.sendMsg("/hid/tiltpad"++index, elid, value);
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

