/*
SamplePad Class / developed for the Loop/Copy/Mutate project of the Genetic Choir / by Robert van Heumen
To trigger and control samples from a Gravis Destroyer Tiltpad or other gamepads
(c) 2017
*/

SamplePad {
	var id, server, path, paramMode, win, map, debug, startTremolo, heightOffset, text, dir; // arguments
	var buffer, soundFile, numChans, numFrames, sRate;
	var name = "SamplePad", playSynth, tremSynth, spec, tremoloName, tremMax, button, slider, bufferView;
	var pitchBus, lenBus, tremBus, volBus, startPos, startPosPrev, muteBus;

	*new {
		arg id = 0, server, path, paramMode = \startLen, win, map, debug = false, startTremolo = true, heightOffset = 50, text, dir;
		^super.newCopyArgs(id, server, path, paramMode, win, map, debug, startTremolo, heightOffset, text, dir).initSamplePad;
	}

	initSamplePad {
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
		name = text[\title] ++ "/" ++ id;
		tremoloName = "tremolo"++id;
		playSynth = Array.newClear(2);
		pitchBus = Bus.control(server,1).set(1);
		tremBus = Bus.control(server,1).set(0.2);
		volBus = Bus.control(server,1).set(0.5);
		muteBus = Bus.control(server,1).set(0);
		startPos = 0;
		spec = (
			pitch: Env.new([0.5,1,2],[0.5,0.5]),
			trem: Env.new([0.001,0.3],[1])
		);
		tremMax = 0.27; // above this speed the tremolo is switched off
		button = (); slider = ();
	}

	initBuffer {
		var soundFileShort;
		if(path.notNil, { // read soundfile in buffer
			soundFileShort = subStr(path, path.findBackwards("/",offset: max(0,(path.size - 30))), path.size);
			soundFile = SoundFile.new;
			if(soundFile.openRead(path), {
				buffer.free;
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
				(name ++ ": ### ERROR ### soundfile: '" ++ soundFileShort ++ "' not found.").postln;
			});
		},{
			(name ++ ": ### ERROR ### so soundfile path argument.").postln;
		});
	}

	loadSynthDefs {
		[1,2].do { |num|
			SynthDef(\playStartLen++"_"++id++"_"++num, {
				arg gate = 1, buf, direction = 1, lenBus, start = 0, volBus, muteBus;
				var sig, env, trig, lenVal, volVal;
				lenVal = In.kr(lenBus,1);
				volVal = In.kr(volBus,1);
				trig = Impulse.kr(1 / lenVal);
				env = EnvGen.kr(Env.adsr(0.01,0,1,0.01), gate, doneAction: 2);
				sig = PlayBufCF.ar(num, buf, direction, trig, start * sRate, 1);
				if(num == 1, { sig = sig.dup(2) });
				Out.ar(0, sig * env * volVal * (1 - In.kr(muteBus,1)));
			}).add;
			SynthDef(\playTremPitch++"_"++id++"_"++num, {
				arg gate = 1, buf, direction = 1, pitchBus, tremBus, volBus, startPos = 0, muteBus;
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
				Out.ar(0, sig * env * volVal * (1 - In.kr(muteBus,1)));
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
		var leftShift = 1, rightShift = 1;
		// OSCdef that catches all gamepad OSC
		OSCdef(name, { arg msg;
			var elid, value, physValue;
			// [name,msg].postln;
			elid = msg[1];
			value = msg[2];
			physValue = msg[3];
			case
			{ elid == map[\yellow] } // yellow button
			{
				this.playBuffer(0,value);
				button[\yellow].valueAction_(value);
			}
			{ elid == map[\left] } // left button
			{
				leftShift = 1 - value;
				button[\left].value = value;
			}
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
					if(startPos != startPosPrev, {
						{ bufferView.setSelectionStart(0, startPos * sRate) }.defer;
						2.do { arg playMode;
							if(playSynth[playMode].notNil, {
								if(debug, { ("set start:"+startPos).postln });
								this.playBuffer(playMode, 0, \nilBypass);
								this.playBuffer(playMode, 1, \nilBypass);
							});
						};
						startPosPrev = startPos;
					});
				}
				{ paramMode == \tremPitch } { tremBus.set(spec.trem.at(value)); if(debug, {("set trem:"+spec.trem.at(value)).postln});  }
				;
			}
			{ elid == map[\y] and: { rightShift == 1 }  } // Y-axis
			{
				case
				{ paramMode == \startLen }
				{
					lenBus.set(spec.len.at(value));
					if(debug, {("set len:"+spec.len.at(value)).postln});
					// set length in GUI, indirectly to prevent strange jumps
					lenBus.get({ arg busVal; { bufferView.setSelectionSize(0, busVal * sRate) }.defer });
				}
				{ paramMode == \tremPitch } {
					pitchBus.set(spec.pitch.at(value)); if(debug, {("set pitch:"+spec.pitch.at(value)).postln});
					slider[\pitch].value = value;
				}
				;
			}
			;
		}, "/hid/samplepad"++id ).fix;
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
					playSynth[playMode] = Synth(\playStartLen++"_"++id++"_"++numChans, [
						\buf, buffer, \direction, ( if(playMode==0) {1} {-1} ),
						\volBus, volBus.index, \lenBus, lenBus.index, \start, startPos, \muteBus, muteBus.index
					])
				}
				{ paramMode == \tremPitch }
				{
					playSynth[playMode] = Synth(\playTremPitch++"_"++id++"_"++numChans, [
						\buf, buffer, \direction, ( if(playMode==0) {1} {-1} ),
						\volBus, volBus.index,\pitchBus, pitchBus.index,
						\tremBus, tremBus.index, \startPos, rrand(0,numFrames), \muteBus, muteBus.index
					])
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
		var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height - heightOffset;
		var border = 4, view, title, font = "Avenir", textGui = (), dropSample, sampleList, sampleListDisplay;
		var width = screenWidth / 2 - (1.5*border), height = screenHeight / 2 - (1.5*border);
		var left = (id%2) * width + ((id%2+1)*border), top = (id > 1).asInt * height + (((id > 1).asInt + 1)*border);

		// sample list for dropdown
		sampleList = (dir++"/Samples/*").pathMatch;
		sampleList.takeThese({ arg item, index; PathName.new(item).isFile.not });
		sampleListDisplay = sampleList.collect { arg sample; subStr(sample, sample.findBackwards("/")+1, sample.size) };

		if(win.isNil, { // no window passed, create one
			win = Window(name, Rect(left, top, width, height)).onClose_({ this.cleanUp() }).front;
			win.keyDownAction = {
				arg view, char, modifiers, unicode, keycode, key;
				if(keycode == 17 and: { modifiers.isAlt }, { this.tremSynth() });
			};
			left = 0; top = 0;
		});

		view = View(win, Rect(left, top, width, height)).background_(Color.white);

		title = (StaticText(view, Rect(width/4, height - 30, 120, 20))
			.string_(name + "sample:").font_(Font(font,12)).align_(\right)
		);
		dropSample = (PopUpMenu(view, Rect(width/4 + 125, height - 30, 140, 20))
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
		button[\setDefault]= (SmoothButton(view, Rect(width/4 + 275, height - 30, 70, 20))
			.border_(1).radius_(2).canFocus_(false).font_(Font(font,12))
			.states_([ [ "set default" ], [ "set default", Color.white, Color.grey(0.5) ] ])
			.action_({ |b|
				if(b.value == 1, {
					var file, fileContents, path;
					path = dir++"/Config.scd";
					fileContents = path.load;
					fileContents[id] = dropSample.item;
					file = File(path,"w");
					file.write(fileContents.asCompileString);
					file.close;
					{ b.value = 0 }.defer(0.1)
				});
			})
		);

		button[\left] = (SmoothButton(view, Rect(40,height - 140,100,100))
			.border_(1).radius_(5).canFocus_(false).font_(Font(font,30))
			.states_([ [ "left\nfront", Color.grey(0.5), Color.grey(0.9) ], [ "left\nfront", Color.white, Color.grey(0.5) ] ])
		);
		textGui[\left] = (StaticText(view, Rect(button[\left].bounds.left - 5, button[\left].bounds.top - 40, button[\left].bounds.width + 10, 30))
			.string_("- Pause X Control -").font_(Font(font,12)).align_(\center)
		);
		button[\red] = (SmoothButton(view, Rect(width - 145,height - 145,110,110))
			.border_(1).radius_(55).canFocus_(false)
			.background_(Color.white)
		);
		button[\yellow] = (SmoothButton(view, Rect(width - 140,height - 140,100,100))
			.border_(1).radius_(50).canFocus_(false).font_(Font(font,30))
			.states_([ [ text[\yellow], Color.black, Color.yellow(1,0.3) ], [ text[\yellow], Color.black, Color.yellow(1,1) ] ])
			.action_({ |b| if(b.value == 1, { button[\red].background_(Color.red) }, { button[\red].background_(Color.white) }) })
		);
		textGui[\yellow] = (StaticText(view, Rect(button[\yellow].bounds.left, button[\yellow].bounds.top - 40, button[\yellow].bounds.width, 30))
			.string_("- Play Sample -").font_(Font(font,12)).align_(\center)
		);

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
			textGui[\bufferview] = (StaticText(view, Rect(bufferView.bounds.left, bufferView.bounds.top + bufferView.bounds.height - 20, bufferView.bounds.width, 100))
				.string_("- Start and End Point -\n"++text[\xsl]++" to change Start Point\n"++text[\ysl]++" to change End Point")
				.font_(Font(font,12)).align_(\center)
			);
		}
		{ paramMode == \tremPitch }
		{
			slider[\tremolo] = (SmoothSlider(view, Rect(width/2 - (width/8) - 10, 20, width/8, height - 60))
				.canFocus_(false).knobSize_(1).border_(1)
				.hilightColor_(Color.white).background_(Color.white).knobColor_(Color.blue(1,0.5)).borderColor_(Color.grey)
			);
			textGui[\tremolo] = (StaticText(view, Rect(slider[\tremolo].bounds.left - (width/4) - 25, slider[\tremolo].bounds.top, width/4, 80))
				.string_("- Tremolo -\n"++text[\xtp]++"\nto change speed")
				.font_(Font(font,12)).align_(\right)
			);
			slider[\pitch] = (SmoothSlider(view, Rect(width/2 + 10, 20, width/8, height - 60))
				.canFocus_(false).knobSize_(0.01).border_(1).value_(0.5)
				.hilightColor_(Color.blue(1,0.5)).background_(Color.white).knobColor_(Color.black).borderColor_(Color.grey)
			);
			textGui[\pitch] = (StaticText(view, Rect(slider[\pitch].bounds.left + (width/8) + 20, slider[\pitch].bounds.top, width/4, 80))
				.string_("- Pitch -\n"++text[\ytp]++"\nto change")
				.font_(Font(font,12)).align_(\left)
			);
		}
		;

		// set initial sample in dropdown
		dropSample.value = sampleList.indexOfEqual(path);
	}

	mute { arg value;
		muteBus.set(value);
	}

	cleanUp {
		OSCdef(name).free; OSCdef(tremoloName).free;
		(name ++ ": OSCdefs freed.").postln;
		tremSynth.free;
		2.do { |playMode| if(playSynth[playMode].notNil, { playSynth[playMode].release(0.01) }) };
		(name ++ ": Synth released.").postln;
		buffer.free; buffer = nil;
		(name ++ ": buffer freed.").postln;
	}

	printOn { arg stream;
		stream << name << "Object with sample:" << path;

	}

}