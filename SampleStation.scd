/*
Loop/Copy/Mutate project Genetic Choir
Sample Station
*/

(
if(~standalone.isNil, {~standalone = false});
s.waitForBoot {

	// --- Variables ------------------------------------------------------------------------------------------------

	var
	skins = (
		Pink: (
			backgroundWindow: Color.new255(255, 192, 203, 120),
			record: Color.red,
			recordAgain: Color.red(1,0.5),
			recText: Color.black,
			play: Color.red,
			playText: Color.black,
			playYellow: false,
			playButtonOff: Color.red(1,0.1),
			playButtonOn: Color.red,
			playButtonBorder: Color.black,
			controls: Color.red(1,0.1),
			backgroundPlayer: Color.new255(255, 192, 203)
		),
		Blue: (
			backgroundWindow: Color.blue(1,0.2),
			record: Color.blue(0.9),
			recordAgain: Color.blue(1,0.5),
			recText: Color.white,
			play: Color.blue(0.9),
			playText: Color.white,
			playYellow: false,
			playButtonOff: Color.blue(1,0.5),
			playButtonOn: Color.blue(1,1),
			playButtonBorder: Color.black,
			controls: Color.blue(1,0.5),
			backgroundPlayer: Color.white
		),
		Silver: (
			backgroundWindow: Color.grey(0.8,0.2),
			record: Color.red,
			recordAgain: Color.grey(0.8),
			recText: Color.black,
			play: Color.grey(0.6),
			playText: Color.black,
			playYellow: false,
			playButtonOff: Color.grey(0.9),
			playButtonOn: Color.yellow(1,1),
			playButtonBorder: Color.black,
			controls: Color.grey(0.6),
			backgroundPlayer: Color.new255(192,192,192)
		)
	),
	skin = if(~skin.notNil, { skins[~skin] }, { skins[\Silver] }),
	sampleFolder = if(~standalone, { Platform.resourceDir ++ "/SampleStation_files/Samples/" }, { Document.current.dir ++ "/Samples/" }),
	configFolder = if(~standalone, { Platform.resourceDir ++ "/SampleStation_files/" }, { Document.current.dir ++ "/" }),
	fullscreen = false, // if true than window will be fullscreen on startup
	showAltWMessage = false, // if fullscreen = true then this determines if a short message about closing with Alt-W is shown
	quitOnClose = true, // if true than closing the window will quit SC
	enableSend = false, // if true then 'Send' buttons are shown to send samples to a server
	verbose = false, // amount of information in post window
	noDevicesOverride = true, // if true the system shows the samplePad views independent of gamePad availability
	heightOffset = 40, // offset at the bottom to make space for rec/play/solo buttons
	copyRecs = true, // if true the recordings will be copied to a remote server
	remoteFileServer = "/Volumes/LCM/", // mounted remote server
	// remoteFileServer = "/Users/Robert/Desktop/LCM/", // mounted remote server
	maxRecord = 10, // max record time in seconds - after this time the recording stops automatically
	removeRecordingsOnClose = false, // whether to remove the recordings on close, only for the non-standalone version
	sampleLength = 2, // sample length to use in samplePads
	normalize = 1, // value to normalize samples to
	sameSample = false, // whether the samplePads should use the same sample
	playYellow = skin[\playYellow], // whether the view of each samplePad should have a yellow background when playing
	showBufBounds = false, // whether to show the start and endpoint in seconds in each view
	showNumber = true, // whether to show the gamepad number instead of the left button
	showSampleSelect = true; // whether to show sample selection dropdown

	var localAddr = NetAddr("127.0.0.1", 57120), sRate = s.sampleRate;
	var hidDeviceMap = (
		\none: 'Player',
		\dest: 'Destroyer Tiltpad',
		\att: 'Logitech Attack 3',
		\fire: 'Firestorm Wireless Gamepad',
		\wing: 'WingMan RumblePad'
	);
	var
	hidDevice = Array.newClear(4), // holds the actual HID devices
	hidDeviceId = Array.newClear(4), // the device id's (\none, \att, etc)
	hidDeviceName = Array.newClear(4), // the device names (Player, Destroyer Tiltpad, etc)
	hidDeviceNameTmp = Array.newClear(4); // temp copy of above
	var samplePad = Array.newClear(4), sampleList;
	var paramMode, deviceText, fCopyRecs, deviceMap, devCount = 0, fSolo, synthListener, fButtonControl, buttonsEnabled = true;
	var wDummy, wSamStat, ctrView, button = (\rec: nil!2, \play: nil!2, \send: nil!4, \solo: nil!4), bWidth, bRec, bFont, bCloseMsg;
	var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height;
	var recplay = (
		path: Array.newClear(2), file: {SoundFile.new}!2, play: Array.newClear(2), len: Array.newClear(2),
		clockplay: Array.newClear(2), clockrec: Array.newClear(2), recording: false!2, playing: false!2
	);
	var config, fStopPlay;

	// --- Initialize ------------------------------------------------------------------------------------------------

	if(fullscreen.not, {
		heightOffset = heightOffset + 50;
	});
	config = "Config.scd".loadRelative[0].clump(4);
	sampleList = config[0];
	if(sameSample, {
		sampleList = sampleList[0]!(sampleList.size);
	});
	paramMode = config[1];
	hidDeviceId = config[2];
	if(~hidDevices.notNil and: {~hidDevices.isArray} and: {~hidDevices.size == 4}, {
		("Selected devices by id:" + ~hidDevices).postln;
		hidDeviceId = ~hidDevices;
	}, {
		("Devices by id:" + hidDeviceId).postln;
	});
	hidDeviceId.size.do { arg i;
		hidDeviceName[i] = hidDeviceMap.at(hidDeviceId[i]);
	};
	("Devices by name:" + hidDeviceName).postln;
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
		),
		'Logitech Attack 3': (
			\yellow: 0,  \left: 6,
			\hat: 15, \hatUp: 0, \hatDown: 180,
			\x: 11, \y: 12
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
			\title: "Rumble",
			\yellow: "C",
			\xtp: "Move left joystick\nleft and right", // text for tremPitch paramMode
			\ytp: "Move left joystick\nup and down",
			\xsl: "Move left joystick left and right", // text for startLen paramMode
			\ysl: "Move left joystick up and down"
		),
		'Firestorm Wireless Gamepad': (
			\title: "Thrust",
			\yellow: "",
			\xtp: "Move left joystick\nleft and right", // text for tremPitch paramMode
			\ytp: "Move left joystick\nup and down",
			\xsl: "Move left joystick left and right", // text for startLen paramMode
			\ysl: "Move left joystick up and down"
		),
		'Logitech Attack 3': (
			\title: "Attack",
			\yellow: "",
			\xtp: "Move left joystick\nleft and right", // text for tremPitch paramMode
			\ytp: "Move left joystick\nforward and backward",
			\xsl: "Move left joystick left and right", // text for startLen paramMode
			\ysl: "Move left joystick forward and backward"
		),
		'Player': (
			\title: "Player",
			\yellow: "",
			\xtp: "Click in the fader\n(lower is faster)", // text for tremPitch paramMode
			\ytp: "Move fader up and down",
			\xsl: "Make a selection", // text for startLen paramMode
			\ysl: "Shift-click"
		)
	);

	s.sync;

	"### Initializing HID".postln;
	HID.findAvailable.collect { arg device, id; var index;
		("Checking device:" + device).postln;
		index = hidDeviceNameTmp.indexOfEqual(device.productName.asSymbol);
		if(index.notNil, {
			("HID initializing" + hidDeviceNameTmp[index]).postln;
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
		{ num == 48 and: { buttonsEnabled } } { button[\rec][0].valueAction_( (button[\rec][0].value+1)%3 )}
		{ num == 49 and: { button[\send][0].notNil } and: { buttonsEnabled } } { button[\send][0].valueAction_(1)}
		{ num == 52 } { button[\play][0].valueAction_( (button[\play][0].value+1)%2 )}
		{ num == 55 and: { buttonsEnabled } } { button[\rec][1].valueAction_( (button[\rec][1].value+1)%3 )}
		{ num == 56 and: { button[\send][1].notNil } and: { buttonsEnabled } } { button[\send][1].valueAction_(1)}
		{ num == 59 } { button[\play][1].valueAction_( (button[\play][1].value+1)%2 )}
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
				recplay.path[i] = if(~standalone, { Platform.resourceDir ++ "/SampleStation_files" }, { Document.current.dir })
				++ "/Recordings/LCM_track_" ++ i ++ Date.getDate.format("_%y%m%d_%H%M%S.")++s.recHeaderFormat.toLower;
				s.record(recplay.path[i]);
				recplay.recording[i] = true;
				recplay.clockrec[i] = TempoClock(1).sched(maxRecord, { if(recplay.recording[i], { button[\rec][i].valueAction_(2) }) });
			})
		};

	}, "/listener").fix;

	// --- functions ------------------------------------------------------------------------------------------------

	fCopyRecs = { arg i;
		if(copyRecs and: { recplay.path[i].notNil }, {
			("cp \"" ++ recplay.path[i] ++ "\" \"" ++ remoteFileServer ++ "GameStation/\"").unixCmd;
			("unixCmd: cp \"" ++ recplay.path[i] ++ "\" \"" ++ remoteFileServer ++"GameStation/\"").postln;
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

	fButtonControl = { arg action;
		2.do { arg i;
			button[\rec][i].enabled_(action==\enable);
			button[\send][i].enabled_(action==\enable);
			buttonsEnabled = (action==\enable);
		}
	};

	fStopPlay = {
		2.do {|i|
			recplay.clockplay[i].clear;
			recplay.play[i].stop;
		}
	};

	// --- GUI ------------------------------------------------------------------------------------------------

	wDummy = Window().front.close; // to prevent main window to start hidden behind sclang
	wSamStat = Window("SampleStation", Rect(0,0,screenWidth,screenHeight)).background_(skin[\backgroundWindow]);

	hidDevice.size.do { |index|
		if(hidDevice[index].notNil or: { noDevicesOverride }, {
			var device;
			// define action for device
			if(hidDevice[index].notNil, {
				device = hidDeviceName[index];
				hidDevice[index].action = { | value, physValue, rawValue,  arrayValue, usage, page, elid |
					// [value, physValue,elid].postln;
					localAddr.sendMsg("/hid/samplepad"++index, elid, value, physValue);
				};
			}, {
				device = \Player;
			});
			// startup samplePad instance for device
			samplePad[index] = SamplePad.new(
				index, // id of gamepad
				s, // server
				sampleList[index], // sample file
				paramMode[index], // param mode setting which parameters to use
				wSamStat, // main window
				deviceMap.at(hidDeviceName[index]), // map for HID device elids
				verbose, // amount of information to show in post window
				false, // start tremolo synth to move tremolo GUI element
				heightOffset, // space for bottom bar with record/play/mute buttons
				deviceText.at(device), // text to show on GUI
				sampleLength, // sample length to use in samplePads
				normalize, // value to normalize samples to
				sameSample, // whether the view of each samplePad should have a yellow background when playing
				playYellow, // whether the view of each samplePad should have a yellow background when playing
				showBufBounds, // whether to show the start and endpoint in seconds in each view
				showNumber, // whether to show the gamepad number instead of the left button
				showSampleSelect, // whether to show sample selection dropdown
				sampleFolder, // samples location
				configFolder, // config location
				skin // color settings
			);
			});
	};

	bRec = (SmoothButton(wSamStat, Rect(screenWidth / 2 - 50, screenHeight - heightOffset / 2 - 50, 100, 100))
		.radius_(50).border_(0).canFocus_(false).visible_(false).states_([["REC",Color.white, skin[\record]]]).font_(Font(Font.default, 30))
	);
	if(fullscreen && showAltWMessage, {
		bCloseMsg = (SmoothButton(wSamStat, Rect(screenWidth / 2 - 75, screenHeight - heightOffset / 2 - 40, 150, 80))
			.radius_(2).border_(1).canFocus_(false).visible_(true)
			.states_([["Close application\n with Alt-w",Color.green,Color.black]]).font_(Font(Font.default, 15))
		);
		{ bCloseMsg.visible_(false) }.defer(5);
	});

	// operator section
	ctrView = View(wSamStat, Rect(4, screenHeight - heightOffset, screenWidth - 8, 80)).background_(skin[\backgroundWindow]);
	bWidth = screenWidth / 11.5 - 5;
	bFont = Font(Font.default,10);

	// record and play buttons
	2.do { arg i;
		button[\rec][i] = (SmoothButton(ctrView, Rect(i * 3.3 * bWidth, 10, bWidth - 5, 25))
			.border_(1).radius_(2).canFocus_(false).font_(bFont).background_(Color.white)
			.states_([
				[ "start rec slot" + (i+1), Color.black, Color.white ],
				[ "stop rec slot" + (i+1), skin[\recText], skin[\record] ],
				[ "start rec" + (i+1) + "again", skin[\recText], skin[\recordAgain] ]
			])
			.action_({ arg button;
				if(button.value == 0, { button.value = 1 });
				if(button.value == 1, {
					"".postln;
					"RECORDING ARMED".warn;
					{ bRec.visible_(true); if(bCloseMsg.notNil, { bCloseMsg.visible_(false); }) }.defer;
				}, {
					"RECORDING STOPPED".warn;
					s.stopRecording;
					recplay.clockrec[i].clear;
					recplay.recording[i] = false;
					{ bRec.visible_(false) }.defer;
						// { fCopyRecs.value(i) }.defer(0.1);
				});
			})
		);
		button[\play][i] = (SmoothButton(ctrView, Rect( (i*3.3 + 1) * bWidth, 10, bWidth - 5, 25))
			.border_(1).radius_(2).canFocus_(false).font_(bFont).background_(Color.white)
			.states_([
				[ "start play slot" + (i+1), Color.black, Color.white ],
				[ "stop play slot" + (i+1), skin[\playText], skin[\play] ]
			])
			.action_({ arg button;
				if(button.value == 1, {
					if(recplay.path[i].notNil, {
						if(recplay.file[i].openRead(recplay.path[i]), {
							recplay.len[i] = recplay.file[i].numFrames / sRate;
						});
						recplay.play[i] = DiskPlayer.new(s,recplay.path[i], loop: 1, bufPwr: 17, autoPlay: true);
						recplay.playing[i] = true;
						// recplay.clockplay[i] = TempoClock(1).sched(recplay.len[i], { button.valueAction_(0) });
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
		if (enableSend, {
			button[\send][i] = (SmoothButton(ctrView, Rect( (i*3.3 + 2) * bWidth, 10, bWidth - 5, 25))
				.border_(1).radius_(2).canFocus_(false).font_(bFont).background_(Color.white)
				.states_([
					[ "send slot" + (i+1), Color.black, Color.white ],
					[ "send slot" + (i+1), skin[\playText], skin[\play] ]
				])
				.action_({ arg button;
					if(button.value == 1, {
						"RECORDING SEND TO SERVER".warn;
						{ fButtonControl.value(\disable) }.defer();
						fCopyRecs.value(i);
						{ button.value = 0 }.defer(0.2);
					})
				})
			);
		});
	};

	// mute buttons
	hidDevice.size.do { |index|
		if(hidDevice[index].notNil or: { noDevicesOverride }, {
			var device;
			if(hidDevice[index].notNil, { device = hidDeviceName[index] }, { device = \Player });
			button[\solo][index] = (SmoothButton(ctrView, Rect( (index+6.6) * bWidth , 10, bWidth - 5, 25))
				.border_(1).radius_(2).canFocus_(false).font_(bFont).background_(Color.white)
				.states_([
					[ "Solo "++deviceText[device][\title]++"/"++index, Color.black, Color.white ],
					[ "Solo "++deviceText[device][\title]++"/"++index, Color.white, skin[\record] ]
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
		{ keycode == 17 and: { modifiers.isAlt } } // alt-T
		{
			hidDevice.size.do { |index|
				if(hidDevice[index].notNil or: { noDevicesOverride }, { samplePad[index].tremSynth() });
			};
		}
		{ keycode == 1 and: { modifiers.isAlt } } // alt-S
		{
			showBufBounds = showBufBounds.not;
			hidDevice.size.do { |index|
				if(hidDevice[index].notNil or: { noDevicesOverride }, { samplePad[index].showBufBounds(showBufBounds) });
			};
		}
		{ keycode == 15 and: { modifiers.isAlt } } // alt-R
		{
			fButtonControl.value(\enable);
			buttonsEnabled = true;
		}
		{ ( keycode == 13 and: { modifiers.isAlt } ) or: { ( keycode == 12 and: { modifiers.isCmd } ) } } // alt-W & cmd-Q
		{
			wSamStat.endFullScreen;
			wSamStat.close;
		}
		;
	};

	wSamStat.onClose = {
		hidDevice.size.do { |index|
			if(hidDevice[index].notNil or: { noDevicesOverride }, {
				if(hidDevice[index].notNil, {
					hidDevice[index].close;
					("HID device" + hidDeviceName[index] + "closed").postln;
				});
				samplePad[index].cleanUp();
			});
			MIDIdef(\LCMnon).free; MIDIdef(\LCMnof).free;
			OSCdef(\listener).free;
		};
		synthListener.free;
		fStopPlay.value;
		~hidDevices = nil;
		// remove all recordings made
		if(~standalone, {
			("rm " ++ Platform.resourceDir ++ "/SampleStation_files/Recordings/*").unixCmd;
		}, {
			if(removeRecordingsOnClose, {
				("rm " ++ Document.current.dir ++ "/Recordings/*").unixCmd;
			});
		});
		// ("(OSCdefs after free:"+AbstractResponderFunc.allFuncProxies).postcs;
		if(quitOnClose && ~standalone, {
			// clean up all processes
			thisProcess.shutdown;
			// stop sclang
			0.exit;
			// stop the IDE
			"osascript -e 'tell application \"SampleStation\" to quit'".unixCmd;
		});
	};

	if(devCount > 0 or: { noDevicesOverride }, {
		wSamStat.front;
	}, {
		"### No devices found!".postln;
	});

	// start recording listener
	synthListener = Synth(\listener, [\inChan, 0]);
	if(fullscreen, { wSamStat.fullScreen });
	// close setup window
	if(~wSetup.notNil, {
		~wSetup.onClose = {};
		~wSetup.close;
	});
}
)

