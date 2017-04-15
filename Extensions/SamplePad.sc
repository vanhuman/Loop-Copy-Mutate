/*
SamplePad Class / developed for the Loop/Copy/Mutate project of the Genetic Choir / by Robert van Heumen
To trigger and control samples from a Gravis Destroyer Tiltpad or other gamepads
(c) 2017
*/

SamplePad {
	// arguments
	var id, server, path, paramMode, win, map, verbose, startTrem, hOffset, text, sLen, norm, samSam, bgYel,
	bufBounds, showNbr, showSampleSelect;

	// other variables
	var buffer, soundFile, numChans, numFrames, sRate, startOffset, localAddr, stereoLocation;
	var instance, playSynth, tremSynth, spec, tremMax, sampleList, sampleListDisplay, oscTrem, oscSamSel;
	var button, slider, bufferView, viewCover, popSample, bufferBounds;
	var pitchBus, lenBus, tremBus, volBus, startPos, startPosPrev, muteBus;

	*new {

		arg id = 0, server, path, paramMode = \startLen, win, map, verbose = true, startTrem = true, hOffset = 50,
			text, sLen = 0, norm = 1, samSam = false, bgYel = false, bufBounds = false, showNbr = false, showSampleSelect;
		^super.newCopyArgs(
			id, server, path, paramMode, win, map, verbose, startTrem, hOffset, text, sLen, norm, samSam, bgYel,
			bufBounds, showNbr, showSampleSelect
		).initSamplePad;

	}

	initSamplePad {

		this.initVars();
		this.initBuffer();
		this.loadSynthDefs();
		server.sync;
		this.initOSC();
		this.buildGUI();
		if(startTrem, { this.tremSynth() });

	} // initSamplePad

	initVars {

		// init variables
		localAddr = NetAddr("127.0.0.1", 57120);
		sRate = server.sampleRate;
		startOffset = 0;
		instance = text[\title] ++ "/" ++ id;
		oscTrem = \tremolo++id;
		oscSamSel = \sampleSelect++id;
		playSynth = Array.newClear(2);
		pitchBus = Bus.control(server,1).set(1);
		tremBus = Bus.control(server,1).set(0.2); if(paramMode == \pitch, { tremBus.set(1) });
		volBus = Bus.control(server,1).set(0.5);
		muteBus = Bus.control(server,1).set(0);
		startPos = 0;
		spec = (
			pitch: Env.new([0.5,1,2],[0.5,0.5]),
			trem: Env.new([0.001,0.3],[1])
		);
		tremMax = 0.27; // above this speed the tremolo is switched off
		button = (); slider = ();
		stereoLocation = [-2,2,-1,1];
		bufferBounds = ();

	} // initVars

	initBuffer {

		var soundFileShort, outpath, extension, sLenLocal;

		if(path.notNil, { // read soundfile in buffer
			soundFileShort = subStr(path, path.findBackwards("/",offset: max(0,(path.size - 30))), path.size);
			soundFile = SoundFile.new;
			if(soundFile.openRead(path), {
				buffer.free;
				numChans = soundFile.numChannels;
				numFrames = soundFile.numFrames;
				startOffset = 0;
				sLenLocal = 0;

				// when sLen > 0 only use a section of the sample
				if(sLen > 0, {
					sLenLocal = sLen - rrand(0.25 * sLen.neg, 0.25 * sLen);
					if(sLenLocal*sRate < numFrames, {
						startOffset = (numFrames - (sLenLocal * sRate)) / 4;
						startOffset = rrand(startOffset / 2, startOffset);
						numFrames = min(sLenLocal * sRate, numFrames);
					});
				});

				// set startPos en len specs depending on paramMode
				case
				{ paramMode == \startLen }
				{
					spec[\start] = Array.iota(20).resize(128, \step) / 20 * (0.9*numFrames/sRate); // 50 steps
					spec[\len] = Env.new([0.5*numFrames/sRate, 0.01], [1], \exp);
				}
				{ paramMode == \start }
				{
					spec[\start] = Array.iota(20).resize(128, \step) / 20 * (0.9*numFrames/sRate); // 50 steps
					spec[\len] = Env.new([numFrames/sRate,numFrames/sRate]*0.05,[1]); // fixed to 0.1*length
				}
				{ paramMode == \len }
				{
					startPos = rand(0.9*numFrames/sRate);
					spec[\len] = Env.new([0.5*numFrames/sRate, 0.01], [1], \exp);
					spec[\start] = Env.new([startPos,startPos],[1]); // random value
				}
				{ [\tremPitch,\trem,\pitch].indexOfEqual(paramMode).notNil }
				{
					// constant full length and startPos to 0
					spec[\len] = Env.new([numFrames/sRate,numFrames/sRate],[1]);
					spec[\start] = Env.new([0,0],[1]);
				}
				;
				lenBus = Bus.control(server,1).set(0.1*numFrames/sRate);

				// read file in buffer
				buffer = Buffer.read(server, path, startOffset, numFrames).normalize(norm);

				soundFile.close;
				("\n" ++ instance ++ "\nsoundfile: '" ++ soundFileShort ++ "'\nnumber of channels: " +
					numChans + "\nlength" + (numFrames/sRate).round(0.1) + "sec").postln;
			},{
				(instance ++ ": ### ERROR ### soundfile: '" ++ soundFileShort ++ "' not found.").postln;
			});
		},{
			(instance ++ ": ### ERROR ### so soundfile path argument.").postln;
		});

	} // initBuffer

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
				sig = Splay.ar(sig, 1, 1, stereoLocation[id]);
				sig = sig * env * volVal * (1 - In.kr(muteBus,1));
				Out.ar(0, sig);
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
				sig = sig * env * volVal * (1 - In.kr(muteBus,1));
				Out.ar(0, sig);
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

	} // loadSynthDefs

	initOSC {

		var leftShift = 1, rightShift = 1;

		// OSCdef that catches all gamepad OSC
		OSCdef(instance, { arg msg;
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
				{ paramMode == \startLen or: { paramMode == \start } }
				{
					// set start position
					startPos = spec.start.at(value*127);

					// if startPos changed, update bufferView and restart synths that were running
					if(startPos != startPosPrev, {
						{ bufferView.setSelectionStart(0, startPos * sRate) }.defer;
						2.do { arg playMode;
							if(playSynth[playMode].notNil, {
								if(verbose, { ("set start:"+startPos).postln });
								this.playBuffer(playMode, 0, \nilBypass);
								this.playBuffer(playMode, 1, \nilBypass);
							});
						};
						startPosPrev = startPos;
					});
				}
				{ paramMode == \tremPitch or: { paramMode == \trem } }
				{ tremBus.set(spec.trem.at(value)); if(verbose, {("set trem:"+spec.trem.at(value)).postln});  }
				;
			}
			{ elid == map[\y] and: { rightShift == 1 }  } // Y-axis
			{
				case
				{ paramMode == \startLen or: { paramMode == \len } }
				{
					lenBus.set(spec.len.at(value));
					if(verbose, {("set len:"+spec.len.at(value)).postln});

					// update bufferView, indirectly to prevent strange jumps
					lenBus.get({ arg busVal; { bufferView.setSelectionSize(0, busVal * sRate) }.defer });
				}
				{ paramMode == \tremPitch or: { paramMode == \pitch } }
				{
					pitchBus.set(spec.pitch.at(value));
					if(verbose, {("set pitch:"+spec.pitch.at(value)).postln});
					slider[\pitch].value = value;
				}
				;
			}
			;
		}, "/hid/samplepad"++id ).fix;

		// OSCdef to catch tremolo values
		if(paramMode == \tremPitch or: { paramMode == \trem }, {
			OSCdef(oscTrem, { arg msg;
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

		// OSCdef to catch new selected sample, if appropriate
		if(samSam, {
			OSCdef(oscSamSel, { arg msg;
				// msg.postln;
				// sampleListDisplay.postln;
				{
					popSample.value = sampleListDisplay.indexOfEqual(msg[1].asString);
					this.loadSample(sampleListDisplay.indexOfEqual(msg[1].asString), \osc);
				}.defer;
			}, '/sample' ).fix;
		});
	}

	// start tremolo synth that spits out tremolo values, to run the GUI if the other synths are not running
	tremSynth {
		if(paramMode == \tremPitch or: { paramMode == \trem }, {
			if(tremSynth.isNil,
				{ tremSynth = Synth(\tremolo++id, [\tremBus, tremBus.index]) },
				{ tremSynth.free; tremSynth = nil }
			);
		});

	} // initOSC

	playBuffer {

		arg playMode, value, tag;

		if(value == 1, {
			if(playSynth[playMode].isNil or: { tag == \nilBypass }, {
				case
				{ [\startLen,\start,\len].indexOfEqual(paramMode).notNil }
				{
					playSynth[playMode] = Synth(\playStartLen++"_"++id++"_"++numChans, [
						\buf, buffer, \direction, ( if(playMode==0) {1} {-1} ),
						\volBus, volBus.index, \lenBus, lenBus.index, \start, startPos, \muteBus, muteBus.index
					]);
				}
				{ [\tremPitch,\trem,\pitch].indexOfEqual(paramMode).notNil }
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

	} // playBuffer

	loadSample {

		arg value, mode = \direct;

		// if the path to a sample file is different than the current one, change the path
		if(path != sampleList[value], { path = sampleList[value] });

		// initialize the buffer and load the sample file
		this.initBuffer();

		// update the bufferView
		if([\startLen,\start,\len].indexOfEqual(paramMode).notNil, {
			bufferView.soundfile = soundFile;
			bufferView.read(startOffset, numFrames, 512).refresh;
			bufferView.setSelectionStart(0, startPos * sRate);
			lenBus.get {arg val; { bufferView.setSelectionSize(0, val * sRate) }.defer };
		});

		bufferBounds[\start].string_((startOffset / sRate).round(0.1)+"sec");
		bufferBounds[\end].string_((startOffset + numFrames / sRate).round(0.1)+"sec");

		// if all samplePads should have the same sample, force other samplePad instances to change to this sample
		if(samSam and: { mode == \direct }, { localAddr.sendMsg(\sample, sampleListDisplay[value]) });

	} // loadSample

	buildGUI {

		var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height - hOffset;
		var border = 4, view, title, font = "Avenir", textGui = (), number;
		var width = screenWidth / 2 - (1.5*border), height = screenHeight / 2 - (1.5*border);
		var left = (id%2) * width + ((id%2+1)*border), top = (id > 1).asInt * height + (((id > 1).asInt + 1)*border);

		// sample list for dropdown
		sampleList = (Document.dir++"Loop-Copy-Mutate/Samples/*").pathMatch;
		sampleList.takeThese({ arg item, index; PathName.new(item).isFile.not });
		sampleListDisplay = sampleList.collect { arg sample; subStr(sample, sample.findBackwards("/")+1, sample.size) };

		if(win.isNil, { // no window passed, create one
			win = Window(instance, Rect(left, top, width, height)).onClose_({ this.cleanUp() }).front;
			win.keyDownAction = {
				arg view, char, modifiers, unicode, keycode, key;
				if(keycode == 17 and: { modifiers.isAlt }, { this.tremSynth() });
			};
			left = 0; top = 0;
		});

		view = View(win, Rect(left, top, width, height)).background_(Color.white);

		title = (StaticText(view, Rect(width/4, height - 30, 120, 20))
			.string_(instance + "sample:").font_(Font(font,12)).align_(\right)
		);
		popSample = (PopUpMenu(view, Rect(width/4 + 125, height - 30, 140, 20))
			.items_(sampleListDisplay).font_(Font(font,12))
			.action_({ arg pop;
				this.loadSample(pop.value, \direct);
			})
		);
		button[\setDefault]= (SmoothButton(view, Rect(width/4 + 275, height - 30, 70, 20))
			.border_(1).radius_(2).canFocus_(false).font_(Font(font,12))
			.states_([ [ "set default" ], [ "set default", Color.white, Color.grey(0.5) ] ])
			.action_({ |b|
				if(b.value == 1, {
					var file, fileContents, path;
					path = Document.dir++"Loop-Copy-Mutate/Config.scd";
					fileContents = path.load;
					fileContents[id] = popSample.item;
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
		number = (StaticText(view, Rect(40,height - 140,100,100))
			.canFocus_(false).font_(Font(font,70))
			.string_( (id+1).asString )
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
			.action_({ |b| if(b.value == 1, {
				button[\red].background_(Color.red);
				if(bgYel, { { view.background_(Color.yellow) }.defer });
			}, {
				button[\red].background_(Color.white);
				if(bgYel, { { view.background_(Color.white) }.defer });
			}) })
		);
		textGui[\yellow] = (StaticText(view,
			Rect(button[\yellow].bounds.left, button[\yellow].bounds.top - 40, button[\yellow].bounds.width, 30))
			.string_("- Play Sample -").font_(Font(font,12)).align_(\center)
		);

		case
		{ [\startLen,\start,\len].indexOfEqual(paramMode).notNil }
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
			bufferView.read(startOffset, numFrames, 512).refresh;
			bufferView.setSelectionStart(0, startPos * sRate);
			lenBus.get {arg val; { bufferView.setSelectionSize(0, val * sRate) }.defer };
			textGui[\bufferview] = (StaticText(view,
				Rect(bufferView.bounds.left, bufferView.bounds.top + bufferView.bounds.height - 20, bufferView.bounds.width, 100))
				.string_("- Start and End Point -\n"++text[\xsl]++" to change Start Point\n"++text[\ysl]++" to change End Point")
				.font_(Font(font,12)).align_(\center)
			);
		}
		{ [\tremPitch,\trem,\pitch].indexOfEqual(paramMode).notNil }
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

		bufferBounds[\start] = (StaticText(view, Rect(10, 0, 50, 30))
			.string_((startOffset / sRate).round(0.1)+"sec")
			.font_(Font(font,8)).visible_(bufBounds)
		);
		bufferBounds[\end] = (StaticText(view, Rect(view.bounds.width - 35, 0, 50, 30))
			.string_((startOffset + numFrames / sRate).round(0.1)+"sec")
			.font_(Font(font,8)).visible_(bufBounds)
		);

		// hide GUI elements if not applicable
		case
		{ paramMode == \trem } { textGui[\pitch].visible = false; slider[\pitch].visible = false }
		{ paramMode == \pitch } { textGui[\tremolo].visible = false; slider[\tremolo].visible = false }
		{ paramMode == \len } { textGui[\bufferview].string =
			"- Start and End Point -\n"++text[\ysl]++" to change End Point";
		}
		{ paramMode == \start } { textGui[\bufferview].string =
			"- Start and End Point -\n"++text[\xsl]++" to change Start Point\n";
		}
		;
		if([\start,\len,\pitch,\trem].indexOfEqual(paramMode).notNil, {
			textGui[\left].visible = false; button[\left].visible = false;
		});
		if(showNbr, {
			textGui[\left].visible = false; button[\left].visible = false;
		}, {
			number.visible = false;
		});
		if( showSampleSelect.not, {
			title.visible = false; popSample.visible = false; button[\setDefault].visible = false;
		});

		// mute/unmute layover
		viewCover = View(win, Rect(left, top, width, height)).background_(Color.grey).visible_(false);

		// set initial sample in dropdown
		popSample.value = sampleList.indexOfEqual(path);

	} // buildGUI

	mute { arg value;

		muteBus.set(value);
		{ switch(value, 0, { viewCover.visible_(false) }, 1, { viewCover.visible_(true) }) }.defer;

	} // mute

	cleanUp {

		OSCdef(instance).free; OSCdef(oscTrem).free; OSCdef(oscSamSel).free;
		(instance ++ ": OSCdefs freed.").postln;
		tremSynth.free;
		2.do { |playMode| if(playSynth[playMode].notNil, { playSynth[playMode].release(0.01) }) };
		(instance ++ ": Synth released.").postln;
		buffer.free; buffer = nil;
		(instance ++ ": buffer freed.").postln;

	} // cleanUp

	showBufBounds { arg value;

		bufBounds = value;
		bufferBounds[\start].visible_(bufBounds);
		bufferBounds[\end].visible_(bufBounds);

	}

	printOn {

		arg stream;

		stream << instance << "Object with sample:" << path;

	} // printOn

} // SamplePad