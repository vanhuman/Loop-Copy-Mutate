/*
Loop/Copy/Mutate project Genetic Choir
Sample Station
*/

(
s.waitForBoot {

	// --- Variables ------------------------------------------------------------------------------------------------

	var
	verbose = false, // amount of information in post window
	noDevicesOverride = true, // if true the system shows the samplePad views independent of gamePad availability
	heightOffset = 80, // offset at the bottom to make space for rec/play/solo buttons
	copyRecs = true, // if true the recordings will be copied to a remote server
	remoteFileServer = "/Volumes/LCM/", // mounted remote server
	// remoteFileServer = "/Users/Robert/Desktop/LCM/", // mounted remote server
	maxRecord = 10, // max record time in seconds - after this time the recording stops automatically
	sampleLength = 2, // sample length to use in samplePads
	normalize = 1.5, // value to normalize samples to
	sameSample = true, // whether the samplePads should use the same sample
	playYellow = true, // whether the view of each samplePad should have a yellow background when playing
	showBufBounds = false; // whether to show the start and endpoint in seconds in each view

	var localAddr = NetAddr("127.0.0.1", 57120), sRate = s.sampleRate;
	var hidDevice = Array.newClear(4), samplePad = Array.newClear(4), sampleList, hidDeviceName, hidDeviceNameTmp;
	var paramMode, deviceText, fCopyRecs, deviceMap, devCount = 0, fSolo, synthListener;
	var wDummy, wSamStat, ctrView, button = (\rec: nil!2, \play: nil!2, \solo: nil!4), bWidth, bRec;
	var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height;
	var recplay = (
		path: Array.newClear(2), file: {SoundFile.new}!2, play: Array.newClear(2), len: Array.newClear(2),
		clockplay: Array.newClear(2), clockrec: Array.newClear(2), recording: false!2, playing: false!2
	);
	var config;

	// --- Initialize ------------------------------------------------------------------------------------------------

	config = "Config.scd".loadRelative[0].clump(4);
	sampleList = config[0];
	if(sameSample, {
		sampleList = sampleList[0]!(sampleList.size);
	});
	paramMode = config[1];
	hidDeviceName = config[2];
	hidDeviceNameTmp = hidDeviceName.copyRange(0,3);
	s.recChannels = 2;

	// --- SynthDef ------------------------------------------------------------------------------------------------

	SynthDef(\listener, { // to trigger recording
		arg inChan = 0;
		var in, amp, freq, hasFreq;
		in = Mix.ar(In.ar(inChan,2));
		amp = Amplitude.kr(in);
		SendReply.kr(Impulse.kr(100), "/listener", amp);
	}).add;

	// --- HID ------------------------------------------------------------------------------------------------

	deviceMap = ( // mapping of element id's to logical names
		'Destroyer Tiltpad': (
			\yellow: 3, \left: 6,
			\hat: 8, \hatUp: 1, \hatDown: 5,
			\x: 0, \y: 1
		),
		'WingMan RumblePad': (
			\yellow: 2,  \left: 6,
			\hat: 15, \hatUp: 0, \hatDown: 180,
			\x: 10, \y: 11
		),
		'Firestorm Wireless Gamepad': (
			\yellow: 2,  \left: 4,
			\hat: 15, \hatUp: 0, \hatDown: 180,
			\x: 12, \y: 13
		)
	);
	deviceText = ( // text to display
		'Destroyer Tiltpad': (
			\title: "Tiltpad",
			\yellow: "",
			\xtp: "Tilt left and right",
			\ytp: "Tilt forwards and backwards",
			\xsl: "Tilt left and right",
			\ysl: "Tilt forwards and backwards"
		),
		'WingMan RumblePad': (
			\title: "RumblePad",
			\yellow: "C",
			\xtp: "Move left joystick\nleft and right", // text for tremPitch paramMode
			\ytp: "Move left joystick\nup and down",
			\xsl: "Move left joystick left and right", // text for startLen paramMode
			\ysl: "Move left joystick up and down"
		),
		'Firestorm Wireless Gamepad': (
			\title: "Thrustmast",
			\yellow: "",
			\xtp: "Move left joystick\nleft and right", // text for tremPitch paramMode
			\ytp: "Move left joystick\nup and down",
			\xsl: "Move left joystick left and right", // text for startLen paramMode
			\ysl: "Move left joystick up and down"
		)
	);

	"### Initializing HID".postln;
	HID.findAvailable.collect { arg device, id; var index;
		index = hidDeviceNameTmp.indexOfEqual(device.productName.asSymbol);
		if(index.notNil, {
			hidDeviceNameTmp[index] = nil;
			hidDevice[index] = HID.openAt(id);
			devCount = devCount + 1;
		})
	};

	// --- MIDI ------------------------------------------------------------------------------------------------

	"### Initializing MIDI".postln;
	MIDIIn.connectAll;

	MIDIdef.noteOn(\LCMnon,{
		arg val, num, chan, src;
		// ["LCMnon", val, num, chan, src].postln;
		case
		{ num == 48 } { button[\rec][0].valueAction_( (button[\rec][0].value+1)%3 )}
		{ num == 50 } { button[\play][0].valueAction_( (button[\play][0].value+1)%2 )}
		{ num == 52 } { button[\rec][1].valueAction_( (button[\rec][1].value+1)%3 )}
		{ num == 53 } { button[\play][1].valueAction_( (button[\play][1].value+1)%2 )}
		{ num == 60 } { if(button[\solo][0].notNil, { button[\solo][0].valueAction_( (button[\solo][0].value+1)%2 ) }) }
		{ num == 62 } { if(button[\solo][1].notNil, { button[\solo][1].valueAction_( (button[\solo][1].value+1)%2 ) }) }
		{ num == 64 } { if(button[\solo][2].notNil, { button[\solo][2].valueAction_( (button[\solo][2].value+1)%2 ) }) }
		{ num == 65 } { if(button[\solo][3].notNil, { button[\solo][3].valueAction_( (button[\solo][3].value+1)%2 ) }) }
		;
	}
	).fix;

	MIDIdef.noteOff(\LCMnof,{
		arg val, num, chan, src;
		// ["LCMnof", val, num, chan, src].postln;
	}
	).fix;
	"### Done initializing MIDI".postln;

	// --- OSC ------------------------------------------------------------------------------------------------

	OSCdef(\listener, {
		arg msg;
		2.do { |i|
			if(button[\rec][i].value == 1 and: { msg[3] > 0 } and: { recplay.recording[i].not }, {
				("RECORDING" + s.recChannels + "channels").warn;
				recplay.path[i] =  Document.current.dir++"/Recordings/LCM_track_"++i++
					Date.getDate.format("_%y%m%d_%H%M%S.")++s.recHeaderFormat.toLower;
				s.record(recplay.path[i]);
				recplay.recording[i] = true;
				recplay.clockrec[i] = TempoClock(1).sched(maxRecord, { if(recplay.recording[i], { button[\rec][i].valueAction_(2) }) });
			})
		};

	}, "/listener").fix;

	// --- functions ------------------------------------------------------------------------------------------------

	fCopyRecs = { arg i;
		if(copyRecs and: { recplay.path[i].notNil }, {
			("cp \"" ++ recplay.path[i] ++ "\" \"" ++ remoteFileServer ++ "sampleStation" ++ i ++ ".aiff\"").unixCmd;
			("unixCmd: cp \"" ++ recplay.path[i] ++ "\" \"" ++ remoteFileServer ++"sampleStation" ++ i ++ ".aiff\"").postln;
		});
	};

	fSolo = {
		arg thisButton, value;
		if(value == 1, { // thisButton solo switched on
			button[\solo].size.do { |i| // unmute all devices that are muted
				if(button[\solo][i].notNil and: { i != thisButton } and: { button[\solo][i].value == 1 }, {
					button[\solo][i].valueAction_(0)
				});
			};
			button[\solo].size.do { |i| // mute devices except thisButton
				if(button[\solo][i].notNil and: { i != thisButton }, {
					samplePad[i].mute(1);
					("Mute device"+i).postln;
				});
			}
		}, { // solo switched off
			button[\solo].size.do { |i| // unmute all devices
				if(button[\solo][i].notNil and: { i != thisButton }, {
					samplePad[i].mute(0);
					("Unmute device"+i).postln;
				});
			}
		})
	};

	// --- GUI ------------------------------------------------------------------------------------------------

	wDummy = Window().front.close; // to prevent main window to start hidden behind sclang
	wSamStat = Window("Sample Station", Rect(0,0,screenWidth,screenHeight)).background_(Color.black);

	hidDevice.size.do { |index|
		if(hidDevice[index].notNil or: { noDevicesOverride }, {
			// define action for device
			if(hidDevice[index].notNil, {
				hidDevice[index].action = { | value, physValue, rawValue,  arrayValue, usage, page, elid |
					// [value, physValue,elid].postln;
					localAddr.sendMsg("/hid/samplepad"++index, elid, value, physValue);
				};
			});
			// startup samplePad instance for device
			samplePad[index] = SamplePad.new(
				index, // id of gamepad
				s, // server
				Document.dir ++ "Loop-Copy-Mutate/Samples/" ++ sampleList[index], // sample file
				paramMode[index], // param mode setting which parameters to use
				wSamStat, // main window
				deviceMap.at(hidDeviceName[index]), // map for HID device elids
				verbose, // amount of information to show in post window
				false, // start tremolo synth to move tremolo GUI element
				heightOffset, // space for bottom bar with record/play/mute buttons
				deviceText.at(hidDeviceName[index]), // text to show on GUI
				sampleLength, // sample length to use in samplePads
				normalize, // value to normalize samples to
				sameSample, // whether the view of each samplePad should have a yellow background when playing
				showBufBounds // whether to show the start and endpoint in seconds in each view
			);
			});
	};

	bRec = (SmoothButton(wSamStat, Rect(screenWidth / 2 - 50, screenHeight - heightOffset / 2 - 50, 100, 100))
		.radius_(50).border_(0).canFocus_(false).visible_(false).states_([["REC",Color.white,Color.red]]).font_(Font(Font.default, 30))
	);

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
					"RECORDING ARMED".warn;
					{ bRec.visible_(true) }.defer;
				}, {
					"RECORDING STOPPED".warn;
					s.stopRecording;
					recplay.clockrec[i].clear;
					recplay.recording[i] = false;
					{ bRec.visible_(false) }.defer;
					{ fCopyRecs.value(i) }.defer(0.1);
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
						recplay.clockplay[i] = TempoClock(1).sched(recplay.len[i], { button.valueAction_(0) });
					}, {
						{ button.value = 0 }.defer(0.2);
					});
				}, {
					recplay.clockplay[i].clear;
					recplay.play[i].stop;
					recplay.playing[i] = false;
				})
			})
		);
	};

	// mute buttons
	hidDevice.size.do { |index|
		if(hidDevice[index].notNil or: { noDevicesOverride }, {
			button[\solo][index] = (SmoothButton(ctrView, Rect(index * bWidth + (screenWidth / 2) + 10, 10, bWidth - 5, 25))
				.border_(1).radius_(2).canFocus_(false)
				.states_([
					[ "Solo "++deviceText[hidDeviceName[index]][\title]++"/"++index, Color.black, Color.white ],
					[ "Solo "++deviceText[hidDeviceName[index]][\title]++"/"++index, Color.white, Color.red ]
				])
				.action_({ arg button; fSolo.value(index, button.value);
				})
			);
		});
	};

	// key down actions
	wSamStat.view.keyDownAction = {
		arg view, char, modifiers, unicode, keycode, key;
		// keycode.postln;
		case
		{ keycode == 17 and: { modifiers.isAlt } } // alt-t
		{
			hidDevice.size.do { |index|
				if(hidDevice[index].notNil or: { noDevicesOverride }, { samplePad[index].tremSynth() });
			};
		}
		{ keycode == 1 and: { modifiers.isAlt } } // alt-s
		{
			showBufBounds = showBufBounds.not;
			hidDevice.size.do { |index|
				if(hidDevice[index].notNil or: { noDevicesOverride }, { samplePad[index].showBufBounds(showBufBounds) });
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
			MIDIdef(\LCMnon).free; MIDIdef(\LCMnof).free;
			OSCdef(\listener).free;
		};
		synthListener.free;
		// ("(OSCdefs after free:"+AbstractResponderFunc.allFuncProxies).postcs;
		// "osascript -e 'tell application \"SuperCollider\" to quit'".unixCmd;
	};

	if(devCount > 0 or: { noDevicesOverride }, {
		wSamStat.front;
	}, {
		"### No devices found!".postln;
	});

	// start recording listener
	synthListener = Synth(\listener, [\inChan, 0]);
}
)

