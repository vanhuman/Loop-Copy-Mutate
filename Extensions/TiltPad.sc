/*
TiltPad Class / developed for the Loop/Copy/Mutate project of the Genetic Choir / by Robert van Heumen
To trigger and control samples from a Gravis Destroyer Tiltpad
(c) 2017
*/

TiltPad {
	var id, server, path, paramMode, win, map, debug, startTremolo; // arguments
	var buffer, soundFileShort, soundFile, soundFileFound, numChans, numFrames, sRate;
	var name = "TiltPad", playSynth, tremSynth, spec, startPos, leftShift = 1, rightShift = 1, colorOffset = 0.3, tremoloName, tremMax;
	var pitchBus, lenBus, startPos, tremBus, volBus;
	var button, slider, bufferView, font, text, dropSample, sampleList, sampleListDisplay;

	*new {
		arg id = 0, server, path, paramMode = \startLen, win, map, debug = false, startTremolo = true;
		^super.newCopyArgs(id, server, path, paramMode, win, map, debug, startTremolo).initTiltPad;
	}

	initTiltPad {
		this.initVars();
		this.initBuffer();
		this.loadSynthDefs();
		server.sync;
		this.initOSC();
		this.buildGUI();
		if(startTremolo, { this.tremSynth() });
	}

	initVars {
		// init variables
		sRate = server.sampleRate;
		name = name ++ "-" ++ id;
		tremoloName = "tremolo"++id;
		playSynth = Array.newClear(2);
		pitchBus = Bus.control(server,1).set(1);
		tremBus = Bus.control(server,1).set(0.2);
		volBus = Bus.control(server,1).set(0.5);
		startPos = 0;
		spec = (
			pitch: Env.new([0.5,1,2],[0.5,0.5]),
			trem: Env.new([0.001,0.3],[1])
		);
		tremMax = 0.27; // above this speed the tremolo is switched off
		button = (); slider = (); text = ();
		font = "Avenir";

		// sample list for dropdown
		sampleList = (Document.current.dir++"/Data/*").pathMatch;
		sampleList.takeThese({ arg item, index; PathName.new(item).isFile.not });
		sampleListDisplay = sampleList.collect { arg sample; subStr(sample, sample.findBackwards("/")+1, sample.size) };
	}

	initBuffer {
		if(path.notNil, { // read soundfile in buffer
			soundFileShort = subStr(path, path.findBackwards("/",offset: max(0,(path.size - 30))), path.size);
			soundFile = SoundFile.new;
			if(soundFile.openRead(path), {
				buffer.free;
				soundFileFound = 1;
				numChans = soundFile.numChannels;
				numFrames = soundFile.numFrames;
				if( paramMode == \startLen, {
					spec[\len] = Env.new([0.5*numFrames/sRate, 0.01], [1], \exp);
					// spec[\start] = Env.new([0, 0.9*numFrames/sRate], [1], \lin);
					spec[\start] = Array.iota(20).resize(128, \step) / 20 * (0.9*numFrames/sRate); // 50 steps
				}, { // constant full length and startPos to 0
					spec[\len] = Env.new([numFrames/sRate,numFrames/sRate],[1]);
					spec[\start] = Env.new([0,0],[1]);
				});
				lenBus = Bus.control(server,1).set(0.1*numFrames/sRate);
				buffer = Buffer.read(server, path);
				soundFile.close;
				("\n" ++ name ++ "\nsoundfile: '" ++ soundFileShort ++ "'\nnumber of channels: " +
					numChans + "\nlength" + (numFrames/sRate).round(0.1) + "sec").postln;
			},{
				soundFileFound = 0;
				(name ++ ": ### ERROR ### soundfile: '" ++ soundFileShort ++ "' not found.").postln;
			});
		},{
			(name ++ ": ### ERROR ### so soundfile path argument.").postln;
		});
	}

	loadSynthDefs {
		[1,2].do { |num|
			SynthDef(\playStartLen++"_"++id++"_"++num, { arg gate = 1, buf, direction = 1, lenBus, start = 0, volBus;
				var sig, env, trig, lenVal, volVal;
				lenVal = In.kr(lenBus,1);
				volVal = In.kr(volBus,1);
				trig = Impulse.kr(1 / lenVal);
				env = EnvGen.kr(Env.adsr(0.01,0,1,0.01), gate, doneAction: 2);
				sig = PlayBufCF.ar(num, buf, direction, trig, start * sRate, 1);
				if(num == 1, { sig = sig.dup(2) });
				Out.ar(0, sig * env * volVal);
			}).add;
			SynthDef(\playTremPitch++"_"++id++"_"++num, { arg gate = 1, buf, direction = 1, pitchBus, tremBus, volBus, startPos = 0;
				var sig, env, tremolo, pitchVal, tremVal, volVal, tremLagged, tremOn;
				pitchVal = In.kr(pitchBus,1);
				tremVal = In.kr(tremBus,1);
				tremOn = (tremVal<tremMax);
				volVal = In.kr(volBus,1);
				env = EnvGen.kr(Env.adsr(0.01,0,1,0.01), gate, doneAction: 2);
				tremolo = EnvGen.kr(Env.new([0,1,1,0,0],[0.05,1,0.05,0.7]*tremVal,[\sin,\lin,\sin,\lin]).circle);
				tremLagged = Lag.kr(tremolo, 0.1);
				tremLagged = ( tremOn * tremLagged ) + ( (1 - tremOn) );
				SendReply.kr(Impulse.kr(100), "/tremolo"++id, tremLagged, direction);
				sig = PlayBufCF.ar(num, buf, pitchVal * direction, 1, startPos, 1);
				sig = ( tremOn * sig * tremolo ) + ( (1 - tremOn) * sig );
				if(num == 1, { sig = sig.dup(2) });
				Out.ar(0, sig * env * volVal);
			}).add;
		};
		SynthDef(\tremolo++id, { arg tremBus;
			var tremolo, tremVal, tremLagged, tremOn;
			tremVal = In.kr(tremBus,1);
			tremOn = (tremVal<tremMax);
			tremolo = EnvGen.kr(Env.new([0,1,1,0,0],[0.05,1,0.05,0.7]*tremVal,[\sin,\lin,\sin,\lin]).circle);
			tremLagged = Lag.kr(tremolo, 0.1);
			tremLagged = ( tremOn * tremLagged ) + ( (1 - tremOn) );
			SendReply.kr(Impulse.kr(100), "/tremolo"++id, tremLagged, 0);
		}).add;
	}

	initOSC {
		// OSCdef that catches all tiltpad OSC
		// ("(OSCdefs before:"+AbstractResponderFunc.allFuncProxies).postcs;
		OSCdef(name, { arg msg;
			var elid, value, physValue;
			// msg.postln;
			elid = msg[1];
			value = msg[2];
			physValue = msg[3];
			case
			{ elid == map[\yellow] } // yellow button
			{
				this.playBuffer(0,value);
				button[\yellow].valueAction_(value);
			}
			// { elid == map[\green] } // green button
			// {
			// 	this.playBuffer(1,value);
			// 	button[\green].value = value;
			// }
			{ elid == map[\left] } // left button
			{
				rightShift = 1 - value;
				leftShift = 1 - value;
				button[\left].value = value;
				// if(paramMode == \tremPitch, {
				// 	slider[\tremolo].knobColor = Color.blue(1,max(colorOffset,value));
				// 	}, {
				// 		if( rightShift == 0 and: { value == 0 },
				// 			{ { bufferView.setSelectionColor(0, Color.blue(1, colorOffset)) }.defer },
				// 			{ { bufferView.setSelectionColor(0, Color.blue(1, 0.5)) }.defer }
				// 		);
				// });
			}
			// { elid == map[\right] } // right button
			// {
			// 	rightShift = value;
			// 	button[\right].value = value;
			// 	if(paramMode == \tremPitch, {
			// 		slider[\pitch].hilightColor = Color.red(1,max(colorOffset,value));
			// 		}, {
			// 			if( leftShift == 0 and: { value == 0 },
			// 				{ { bufferView.setSelectionColor(0, Color.blue(1, colorOffset)) }.defer },
			// 				{ { bufferView.setSelectionColor(0, Color.blue(1, 0.5)) }.defer }
			// 			);
			// 	});
			// }
			{ elid == map[\hat] } // hatswitch
			{
				case
				{ physValue.asInt == map[\hatUp] }
				{ volBus.get { arg busVal; volBus.set(min(busVal + 0.1, 2)); } }
				{ physValue.asInt == map[\hatDown] }
				{ volBus.get { arg busVal; volBus.set(max(busVal - 0.1, 0.1)); } }
				;
			}
			{ elid == map[\x] and: { leftShift == 1 } } // X-axis
			{
				case
				{ paramMode == \startLen }
				{
					startPos = spec.start.at(value*127);
					{ bufferView.setSelectionStart(0, startPos * sRate) }.defer;
					2.do { arg playMode;
						if(playSynth[playMode].notNil, {
							if(debug, { ("set start:"+startPos).postln });
							this.playBuffer(playMode, 0, \nilBypass);
							this.playBuffer(playMode, 1, \nilBypass);
						});
					}
				}
				{ paramMode == \tremPitch } { tremBus.set(spec.trem.at(value)); if(debug, {("set trem:"+spec.trem.at(value)).postln});  }
				;
			}
			{ elid == map[\y] and: { rightShift == 1 } } // Y-axis
			{
				case
				{ paramMode == \startLen }
				{
					lenBus.set(spec.len.at(value));
					if(debug, {("set len:"+spec.len.at(value)).postln});
					lenBus.get({ arg busVal; { bufferView.setSelectionSize(0, busVal * sRate) }.defer }); // indirectly to prevent strange jumps
				}
				{ paramMode == \tremPitch } {
					pitchBus.set(spec.pitch.at(value)); if(debug, {("set pitch:"+spec.pitch.at(value)).postln});
					slider[\pitch].value = value;
				}
				;
			}
			;
		}, "/hid/tiltpad"++id ).fix;
		if(paramMode == \tremPitch, {
			OSCdef(tremoloName, { arg msg;
				var dir = msg[2], val = msg[3];
				case
				{ playSynth[0].notNil } // then use SendReply from 'direction=1'
				{ if(dir == 1, { slider[\tremolo].value_(val) }) }
				{ playSynth[1].notNil } // then use SendReply from 'direction=-1'
				{ if(dir == -1, { slider[\tremolo].value_(val) }) }
				{ true } // then use SendReply from 'direction=0' which is a special tremSynth
				{ if(dir == 0, { slider[\tremolo].value_(val) }) }
				;
			}, '/tremolo'++id ).fix;
		});
		// ("(OSCdefs after:"+AbstractResponderFunc.allFuncProxies).postcs;
	}

	tremSynth {
		if(paramMode == \tremPitch, {
			if(tremSynth.isNil,
				{ tremSynth = Synth(\tremolo++id, [\tremBus, tremBus.index]) },
				{ tremSynth.free; tremSynth = nil }
			);
		});
	}

	playBuffer {
		arg playMode, value, tag;
		if(value == 1, {
			if(playSynth[playMode].isNil or: { tag == \nilBypass }, {
				case
				{ paramMode == \startLen }
				{
					playSynth[playMode] = Synth(\playStartLen++"_"++id++"_"++numChans,
						[\buf, buffer, \direction, ( if(playMode==0) {1} {-1} ), \volBus, volBus.index, \lenBus, lenBus.index, \start, startPos])
				}
				{ paramMode == \tremPitch }
				{
					playSynth[playMode] = Synth(\playTremPitch++"_"++id++"_"++numChans,
						[\buf, buffer, \direction, ( if(playMode==0) {1} {-1} ), \volBus, volBus.index,\pitchBus, pitchBus.index,
							\tremBus, tremBus.index, \startPos, rrand(0,numFrames)])
				}
				;
			})
		}, {
			if(playSynth[playMode].notNil or: { tag == \nilBypass }, {
				playSynth[playMode].release(0.01);
				if(tag != \nilBypass, { playSynth[playMode] = nil });
			});
		});
	}

	buildGUI {
		var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height - 100;
		var border = 4, view, title;
		var width = screenWidth / 2 - (1.5*border), height = screenHeight / 2 - (1.5*border);
		var left = (id%2) * width + ((id%2+1)*border), top = (id > 1).asInt * height + (((id > 1).asInt + 1)*border);

		if(win.isNil, { // no window passed, create one
			win = Window(name, Rect(left, top, width, height)).onClose_({ this.cleanUp() }).front;
			win.keyDownAction = {
				arg view, char, modifiers, unicode, keycode, key;
				if(keycode == 17 and: { modifiers.isAlt }, { this.tremSynth() });
			};
			left = 0; top = 0;
		});

		view = View(win, Rect(left, top, width, height)).background_(Color.white);

		title = (StaticText(view, Rect(width/4 - 10, height - 30, width/4, 20))
			.string_(name + "sample:").align_(\right).font_(Font(font,12))
		);
		dropSample = (PopUpMenu(view, Rect(width/2 + 10, height - 30, width/4, 20))
			.items_(sampleListDisplay).font_(Font(font,12))
			.action_({ |drop|
				if(path != sampleList[drop.value], { path = sampleList[drop.value] });
				this.initBuffer();
				if(paramMode == \startLen, {
					bufferView.soundfile = soundFile;
					bufferView.read(0, numFrames, 512).refresh;
				});
			})
		);

		button[\left] = (SmoothButton(view, Rect(40,height - 140,100,100))
			.border_(1).radius_(5).canFocus_(false).font_(Font(font,30))
			.states_([ [ "left\nfront", Color.grey(0.5), Color.grey(0.9) ], [ "left\nfront", Color.white, Color.grey(0.5) ] ])
		);
		text[\left] = (StaticText(view, Rect(button[\left].bounds.left, button[\left].bounds.top - 40, button[\left].bounds.width, 30))
			.string_("- Pause Control -").font_(Font(font,12)).align_(\center)
		);
		button[\red] = (SmoothButton(view, Rect(width - 145,height - 145,110,110))
			.border_(1).radius_(55).canFocus_(false)
			.background_(Color.white)
		);
		button[\yellow] = (SmoothButton(view, Rect(width - 140,height - 140,100,100))
			.border_(1).radius_(50).canFocus_(false).font_(Font(font,30))
			.states_([ [ "", Color.black, Color.yellow(1,colorOffset) ], [ "", Color.black, Color.yellow(1,1) ] ])
			.action_({ |b| if(b.value == 1, { button[\red].background_(Color.red) }, { button[\red].background_(Color.white) }) })
		);
		text[\yellow] = (StaticText(view, Rect(button[\yellow].bounds.left, button[\yellow].bounds.top - 40, button[\yellow].bounds.width, 30))
			.string_("- Play Sample -").font_(Font(font,12)).align_(\center)
		);
		// button[\right] = (SmoothButton(view, Rect(width - 110,height/2,100,80))
		// 	.border_(1).radius_(5).canFocus_(false).font_(Font(Font.default,30))
		// 	.states_([ [ "right\nfront", Color.grey(0.5), Color.grey(0.9) ], [ "right\nfront", Color.white, Color.grey(0.5) ] ])
		// );
		// button[\green] = (SmoothButton(view, Rect(width - 220,height - 140,100,100))
		// 	.border_(1).radius_(50).canFocus_(false).font_(Font(Font.default,30))
		// 	.states_([ [ "", Color.black, Color.green(1,colorOffset) ], [ "", Color.black, Color.green(1,1) ] ])
		// );

		case
		{ paramMode == \startLen }
		{
			bufferView = (SoundFileView.new(view, Rect(10, 10, width - 20, height / 2 - 20))
				.gridOn_(false)
				.gridResolution_(10)
				.gridColor_(Color.grey)
				.timeCursorOn_(true)
				.timeCursorColor_(Color.black)
				.waveColors_([Color.green(0.3), Color.green(0.3)])
				.background_(Color.white)
				.canFocus_(false)
				.setSelectionColor(0, Color.blue(1,0.5));
			);
			bufferView.soundfile = soundFile;
			bufferView.read(0, numFrames, 512).refresh;
			bufferView.setSelectionStart(0, 0);
			lenBus.get {arg val; { bufferView.setSelectionSize(0, val * sRate) }.defer };
			text[\bufferview] = (StaticText(view, Rect(bufferView.bounds.left, bufferView.bounds.top + bufferView.bounds.height - 20, bufferView.bounds.width, 100))
				.string_("- Start and End Point -\nTilt left and right to change Start Point\nTilt forwards and backwards to change End Point")
				.font_(Font(font,12)).align_(\center)
			);
		}
		{ paramMode == \tremPitch }
		{
			// button[\left].bounds = Rect(10,height/4,100,80);
			// button[\right].bounds = Rect(width - 110,height/4,100,80);
			// button[\green].bounds = Rect(width - 110,height - 140,100,100);
			// button[\yellow].bounds = Rect(width - 220,height - 140,100,100);

			slider[\tremolo] = (SmoothSlider(view, Rect(width/2 - (width/8) - 10, 20, width/8, height - 60))
				.canFocus_(false).knobSize_(1).border_(1)
				.hilightColor_(Color.white).background_(Color.white).knobColor_(Color.blue(1,0.5)).borderColor_(Color.grey)
			);
			text[\tremolo] = (StaticText(view, Rect(slider[\tremolo].bounds.left - (width/4) - 25, slider[\tremolo].bounds.top, width/4, 50))
				.string_("- Tremolo -\nTilt from left to right\nto change speed")
				.font_(Font(font,12)).align_(\right)
			);
			slider[\pitch] = (SmoothSlider(view, Rect(width/2 + 10, 20, width/8, height - 60))
				.canFocus_(false).knobSize_(0.01).border_(1).value_(0.5)
				.hilightColor_(Color.blue(1,0.5)).background_(Color.white).knobColor_(Color.black).borderColor_(Color.grey)
			);
			text[\pitch] = (StaticText(view, Rect(slider[\pitch].bounds.left + (width/8) + 20, slider[\pitch].bounds.top, width/4, 50))
				.string_("- Pitch -\nTilt forwards and backwards\nto change")
				.font_(Font(font,12)).align_(\left)
			);
		}
		;

		// set initial sample in dropdown
		dropSample.value = sampleList.indexOfEqual(path);
	}

	cleanUp {
		tremSynth.free;
		2.do { |playMode| if(playSynth[playMode].notNil, { playSynth[playMode].release }) };
		(name ++ ": Synth released.").postln;
		buffer.free; buffer = nil;
		(name ++ ": buffer freed.").postln;
		OSCdef(name).free; OSCdef(tremoloName).free;
		(name ++ ": OSCdefs freed.").postln;
	}

	printOn { arg stream;
		stream << name << "Object with sample:" << path;

	}

}