/*
Loop/Copy/Mutate project Genetic Choir
Sample Station

speciale volgorde van activering van gamepads?
*/

(
~docDir = "/Users/Robert/---data---/audio/SC-2017/Loop-Copy-Mutate"; // needed for SC3.6.6. only
s.waitForBoot {

	// --- Variables ------------------------------------------------------------------------------------------------

	var osc = \hid; // \jx: get data via junXion, \hid: get data directly
	var debug = false, noDevicesOverride = false, heightOffset = 80, copyRecs = true;
	var localAddr = NetAddr("127.0.0.1", 57120);
	var remoteFileServer = "/Volumes/LCM/";
	// var remoteFileServer = "/Users/Robert/Desktop/";
	var sRate = s.sampleRate;
	var hidDevice = Array.newClear(4), samplePad = Array.newClear(4), sampleList;
	var paramMode, deviceText, fCopyRecs;
	var wDummy, wSamStat, ctrView, button = (\rec: nil!2, \play: nil!2, \mute: nil!4), bWidth;
	var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height;
	var recplay = (
		path: Array.newClear(2), file: {SoundFile.new}!2, play: Array.newClear(2), len: Array.newClear(2),
		clock: Array.newClear(2), recording: false!2, playing: false!2
	);
	var config;

	// --- Initialize ------------------------------------------------------------------------------------------------

	config = "Config.scd".loadRelative[0].clump(4);
	sampleList = config[0];
	paramMode = config[1];
	~hidDeviceName = config[2];
	~hidDeviceNameTmp = ~hidDeviceName.copyRange(0,3);
	s.recChannels = 2;

	// --- HID ------------------------------------------------------------------------------------------------

	~deviceMap = ( // mapping of element id's to logical names
		'Destroyer Tiltpad': (
			\yellow: 3, \left: 6,
			\hat: 8, \hatUp: 1, \hatDown: 5, \jhatUp: 1, \jhatDown: 0.57,
			\x: 0, \y: 1
		),
		'WingMan RumblePad': (
			\yellow: 2,  \left: 6,
			\hat: 15, \hatUp: 0, \hatDown: 180, \jhatUp: 0, \jhatDown: 0.57,
			\x: 10, \y: 11
		)
	);
	deviceText = ( // text to display
		'WingMan RumblePad': (
			\title: "RumblePad",
			\yellow: "C",
			\xtp: "Move left joystick\nleft and right", // text for tremPitch paramMode
			\ytp: "Move left joystick\nup and down",
			\xsl: "Move left joystick left and right", // text for startLen paramMode
			\ysl: "Move left joystick up and down"
		),
		'Destroyer Tiltpad': (
			\title: "Tiltpad",
			\yellow: "",
			\xtp: "Tilt left and right",
			\ytp: "Tilt forwards and backwards",
			\xsl: "Tilt left and right",
			\ysl: "Tilt forwards and backwards"
		)
	);

	if(osc == \hid, {
		"### Initializing HID".postln;
		~devCount = 0;
		hidDevice = "HIDinit.scd".loadRelative()[0];
	}, {
		"### Bypassing HID, using JunXion instead".postln;
		noDevicesOverride = true;
		~devCount = 4;
		"junXionMap.scd".loadRelative()[0];
	});

	// --- MIDI ------------------------------------------------------------------------------------------------

	"### Initializing MIDI".postln;
	MIDIIn.connectAll;

	MIDIdef.noteOn(\LCMnon,{
		arg val, num, chan, src;
		["LCMnon", val, num, chan, src].postln;
		case
		{ num == 48 } { button[\rec][0].valueAction_( (button[\rec][0].value+1)%3 )}
		{ num == 52 } { button[\play][0].valueAction_( (button[\play][0].value+1)%2 )}
		{ num == 55 } { button[\rec][1].valueAction_( (button[\rec][1].value+1)%3 )}
		{ num == 59 } { button[\play][1].valueAction_( (button[\play][1].value+1)%2 )}
		{ num == 62 } { if(button[\mute][0].notNil, { button[\mute][0].valueAction_( (button[\mute][0].value+1)%2 ) }) }
		{ num == 65 } { if(button[\mute][1].notNil, { button[\mute][1].valueAction_( (button[\mute][1].value+1)%2 ) }) }
		{ num == 69 } { if(button[\mute][2].notNil, { button[\mute][2].valueAction_( (button[\mute][2].value+1)%2 ) }) }
		{ num == 72 } { if(button[\mute][3].notNil, { button[\mute][3].valueAction_( (button[\mute][3].value+1)%2 ) }) }
		;
	}
	).fix;

	MIDIdef.noteOff(\LCMnof,{
		arg val, num, chan, src;
		// ["LCMnof", val, num, chan, src].postln;
	}
	).fix;
	"### Done initializing MIDI".postln;

	// --- functions ------------------------------------------------------------------------------------------------

	fCopyRecs = { arg path;
		if(copyRecs and: { path.notNil }, {
			("cp \"" ++ path ++ "\" \"" ++ remoteFileServer ++ "\"").unixCmd;
			("unixCmd: cp \"" ++ path ++ "\" \"" ++ remoteFileServer ++ "\"").postln;
		});
	};

	// --- GUI ------------------------------------------------------------------------------------------------

	wDummy = Window().front.close; // to prevent main window to start hidden behind sclang
	wSamStat = Window("Sample Station", Rect(0,0,screenWidth,screenHeight)).background_(Color.black);

	hidDevice.size.do { |index|
		if(hidDevice[index].notNil or: { noDevicesOverride }, {
			// define action for device
			if(hidDevice[index].notNil, {
				hidDevice[index].action = { | value, physValue, rawValue,  arrayValue, usage, page, elid |
					if(elid == 8, {
						[value, physValue, rawValue,  arrayValue].postln;
					});
					localAddr.sendMsg("/hid/samplepad"++index, elid, value, physValue);
				};
			});
			// startup samplePad instance for device
			samplePad[index] = SamplePad.new(
				index,
				s,
				~docDir ++ "/Samples/" ++ sampleList[index],
				paramMode[index],
				wSamStat,
				~deviceMap.at(~hidDeviceName[index]),
				debug,
				false, // start tremolo
				heightOffset, // space for bottom bar with record/play/mute buttons
				deviceText.at(~hidDeviceName[index]),
				~docDir
			);
			});
	};

	// operator section
	ctrView = View(wSamStat, Rect(4, screenHeight - heightOffset, screenWidth - 8, 80)).background_(Color.black);
	bWidth = screenWidth / 8 - 5;

	// record and play buttons
	2.do { arg i;
		button[\rec][i] = (SmoothButton(ctrView, Rect(2 * i * bWidth + 10, 10, bWidth - 5, 25))
			.border_(1).radius_(2).canFocus_(false)
			.states_([
				[ (i+1)+": start recording", Color.black, Color.white ],
				[ (i+1)+": stop recording", Color.black, Color.red ],
				[ (i+1)+": record again", Color.black, Color.green ]
			])
			.action_({ arg button;
				if(button.value == 0, { button.value = 1 });
				if(button.value == 1, {
						"".postln;
						("RECORDING" + s.recChannels + "channels").warn;
					recplay.path[i] =  ~docDir++"/Recordings/LCM_track_"++i++
					Date.getDate.format("_%y%m%d_%H%M%S.")++s.recHeaderFormat.toLower;
					s.record(recplay.path[i]);
					recplay.recording[i] = true;
					{ if(recplay.recording[i], { button.valueAction_(2) }) }.defer(30);
				}, {
					s.stopRecording;
					recplay.recording[i] = false;
					{ fCopyRecs.value(recplay.path[i]) }.defer(0.1);
				});
			})
		);
		button[\play][i] = (SmoothButton(ctrView, Rect( (i*2 + 1) * bWidth + 10, 10, bWidth - 5, 25))
			.border_(1).radius_(2).canFocus_(false)
			.states_([
				[ (i+1)+": start playback", Color.black, Color.white ],
				[ (i+1)+": stop playback", Color.white, Color.blue(1,0.5) ]
			])
			.action_({ arg button;
				if(button.value == 1, {
					if(recplay.path[i].notNil, {
						if(recplay.file[i].openRead(recplay.path[i]), {
							recplay.len[i] = recplay.file[i].numFrames / sRate;
						});
						recplay.play[i] = DiskPlayer.new(s,recplay.path[i], bufPwr: 17, autoPlay: true);
						recplay.playing[i] = true;
						recplay.clock[i] = TempoClock(1).sched(recplay.len[i], { button.valueAction_(0) });
					}, {
						{ button.value = 0 }.defer(0.2);
					});
				}, {
					recplay.clock[i].clear;
					recplay.play[i].stop;
					recplay.playing[i] = false;
				})
			})
		);
	};

	// mute buttons
	hidDevice.size.do { |index|
		if(hidDevice[index].notNil or: { noDevicesOverride }, {
			button[\mute][index] = (SmoothButton(ctrView, Rect(index * bWidth + (screenWidth / 2) + 10, 10, bWidth - 5, 25))
				.border_(1).radius_(2).canFocus_(false)
				.states_([
					[ "Mute "++deviceText[~hidDeviceName[index]][\title]++"/"++index, Color.black, Color.white ],
					[ "Unmute "++deviceText[~hidDeviceName[index]][\title]++"/"++index, Color.white, Color.red ]
				])
				.action_({ arg button; samplePad[index].mute(button.value) })
			);
		});
	};

	wSamStat.view.keyDownAction = {
		arg view, char, modifiers, unicode, keycode, key;
		var nums = [18,19,20,21,23,22,26,28], buttonIndex;
		// keycode.postln;
		case
		{ keycode == 17 and: { modifiers.isAlt } }
		{
			hidDevice.size.do { |index|
				if(hidDevice[index].notNil or: { noDevicesOverride }, { samplePad[index].tremSynth() });
			};
		}
		;
	};

	wSamStat.onClose = {
		hidDevice.size.do { |index|
			if(hidDevice[index].notNil or: { noDevicesOverride }, {
				if(hidDevice[index].notNil, { hidDevice[index].close });
				samplePad[index].cleanUp();
			});
		};
		if(osc == \jx, {
			OSCdef(\jx_x).free;
			OSCdef(\jx_y).free;
			OSCdef(\jx_yellow).free;
			OSCdef(\jx_leftfront).free;
			OSCdef(\jx_hat).free;
		});
	};

	if(~devCount > 0 or: { noDevicesOverride }, {
		wSamStat.front;
	}, {
		"### No devices found!".postln;
	});

}
)

