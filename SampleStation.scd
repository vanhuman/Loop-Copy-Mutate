/*
Loop/Copy/Mutate project Genetic Choir
Sample Station

speciale volgorde van activering van tiltpads?
overzetten recordings naar andere computer via file sharing?

*/

(
s.waitForBoot {

	// --- Variables ------------------------------------------------------------------------------------------------

	var debug = false, noDevicesOverride = false, heightOffset = 80;
	var localAddr = NetAddr("127.0.0.1", 57120);
	var sRate = s.sampleRate;
	var tiltDevice = Array.newClear(4), tiltPad = Array.newClear(4), tiltSample, tiltDeviceName, tiltDeviceNameTmp;
	var devCount = 0, paramMode, deviceMap;
	var wDummy, wSamStat, ctrView, button = (\rec: nil!2, \play: nil!2, \mute: nil!4), bWidth;
	var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height;
	var recplay = (
		path: Array.newClear(2), file: {SoundFile.new}!2, play: Array.newClear(2), len: Array.newClear(2),
		clockrec: Array.newClear(2), recording: false!2, playing: false!2
	);
	var config;

	// --- Initialize ------------------------------------------------------------------------------------------------

	config = "Config.scd".loadRelative[0].clump(4);
	tiltSample = config[0];
	paramMode = config[1];
	tiltDeviceName = config[2];
	tiltDeviceNameTmp = tiltDeviceName.copyRange(0,3);
	s.recChannels = 2;

	// --- HID ------------------------------------------------------------------------------------------------

	deviceMap = ( // mapping of element id's to logical names
		'WingMan RumblePad': (
			\yellow: 1,  \left: 6,
			// \green: 2, \right: 7,
			\hat: 15, \hatUp: 0, \hatDown: 180,
			\x: 10, \y: 14
		),
		'Destroyer Tiltpad': (
			\yellow: 3, \left: 6,
			// \green: 4, \right: 7,
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
				true,
				heightOffset
			);
			});
	};

	ctrView = View(wSamStat, Rect(4, screenHeight - heightOffset, screenWidth - 8, 80)).background_(Color.black);
	bWidth = screenWidth / 8 - 5;
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
					{ if(recplay.recording[i], { button.valueAction_(2) }) }.defer(30);
				}, {
					s.stopRecording;
					recplay.recording[i] = false;
				});
			})
		);
		button[\play][i] = (SmoothButton(ctrView, Rect( (i*2 + 1) * bWidth + 10, 10, bWidth - 5, 25))
			.border_(1).radius_(2).canFocus_(false)
			.states_([
				[ (i+1)+": playback", Color.black, Color.white ],
				[ (i+1)+": playback", Color.white, Color.blue(1,0.5) ]
			])
			.action_({ arg button;
				if(button.value == 1, {
					if(recplay.path[i].notNil, {
						if(recplay.file[i].openRead(recplay.path[i]), {
							recplay.len[i] = recplay.file[i].numFrames / sRate;
						});
						recplay.play[i] = DiskPlayer.new(s,recplay.path[i], bufFramePower: 17, autoplay: true);
						recplay.playing[i] = true;
						{ if(recplay.playing[i], { button.valueAction_(0) }) }.defer(recplay.len[i]);
					}, {
						{ button.value = 0 }.defer(0.2);
					});
				}, {
					recplay.play[i].stop;
					recplay.playing[i] = false;
				})
			})
		);
	};

	tiltDevice.size.do { |index|
		if(tiltDevice[index].notNil or: { noDevicesOverride }, {
			button[\mute][index] = (SmoothButton(ctrView, Rect(index * bWidth + (screenWidth / 2) + 10, 10, bWidth - 5, 25))
				.border_(1).radius_(2).canFocus_(false)
				.states_([
					[ "Mute TiltPad-"++index, Color.black, Color.white ],
					[ "Unmute TiltPad-"++index, Color.white, Color.blue(1,0.5) ]
				])
				.action_({ arg button; tiltPad[index].mute(button.value) })
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
			tiltDevice.size.do { |index|
				if(tiltDevice[index].notNil or: { noDevicesOverride }, { tiltPad[index].tremSynth() });
			};
		}
		;
	};

	wSamStat.onClose = {
		tiltDevice.size.do { |index|
			if(tiltDevice[index].notNil or: { noDevicesOverride }, {
				if(tiltDevice[index].notNil, { tiltDevice[index].close });
				tiltPad[index].cleanUp();
			});
		};
	};

	if(devCount > 0 or: { noDevicesOverride }, {
		wSamStat.front;
	}, {
		"General: no TiltPad devices found!".postln;
	});

}
)



// OSC IN monitor, format: OSC IN -- IP -- port -- message
thisProcess.oscInMonitor(true, addr:1);
thisProcess.oscInMonitor(true, addr:1, excl: ['/InBus','/hid/ex3d', '/ard/ana', '/midi/control']);
thisProcess.oscInMonitor(false);

