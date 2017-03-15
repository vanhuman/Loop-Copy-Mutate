/*
Loop/Copy/Mutate project Genetic Choir
Sample Station

Solo ipv mute, en geen button maar duidelijke kleur in kwartier

*/

(
s.waitForBoot {

	// --- Variables ------------------------------------------------------------------------------------------------

	var debug = false, noDevicesOverride = false, heightOffset = 80, copyRecs = true, maxRecord = 60;
	var remoteFileServer = "/Volumes/LCM/", type = "melody/";
	var localAddr = NetAddr("127.0.0.1", 57120), sRate = s.sampleRate;
	var hidDevice = Array.newClear(4), samplePad = Array.newClear(4), sampleList, hidDeviceName, hidDeviceNameTmp;
	var paramMode, deviceText, fCopyRecs, deviceMap, devCount = 0, fSolo;
	var wDummy, wSamStat, ctrView, button = (\rec: nil!2, \play: nil!2, \solo: nil!4), bWidth;
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
	hidDeviceName = config[2];
	hidDeviceNameTmp = hidDeviceName.copyRange(0,3);
	s.recChannels = 2;

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

	// --- functions ------------------------------------------------------------------------------------------------

	fCopyRecs = { arg path;
		if(copyRecs and: { path.notNil }, {
			("cp \"" ++ path ++ "\" \"" ++ remoteFileServer ++ type ++ "\"").unixCmd;
			("unixCmd: cp \"" ++ path ++ "\" \"" ++ remoteFileServer ++ type ++ "\"").postln;
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
					// [value, physValue,elid].postln;
					localAddr.sendMsg("/hid/samplepad"++index, elid, value, physValue);
				};
			});
			// startup samplePad instance for device
			samplePad[index] = SamplePad.new(
				index,
				s,
				Document.dir ++ "Loop-Copy-Mutate/Samples/" ++ sampleList[index],
				paramMode[index],
				wSamStat,
				deviceMap.at(hidDeviceName[index]),
				debug,
				false, // start tremolo
				heightOffset, // space for bottom bar with record/play/mute buttons
				deviceText.at(hidDeviceName[index])
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
					recplay.path[i] =  Document.current.dir++"/Recordings/LCM_track_"++i++
					Date.getDate.format("_%y%m%d_%H%M%S.")++s.recHeaderFormat.toLower;
					s.record(recplay.path[i]);
					recplay.recording[i] = true;
					{ if(recplay.recording[i], { button.valueAction_(2) }) }.defer(maxRecord);
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
			MIDIdef(\LCMnon).free; MIDIdef(\LCMnof).free;
		};
	};

	if(devCount > 0 or: { noDevicesOverride }, {
		wSamStat.front;
	}, {
		"### No devices found!".postln;
	});

}
)

