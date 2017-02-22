/*
TiltPad Class / developed for the Loop/Copy/Mutate project of the Genetic Choir / by Robert van Heumen
To trigger and control samples from a Gravis Destroyer Tiltpad
(c) 2017
*/

TiltPad {
	var id, server, path, paramMode, win, debug; // arguments
	var buffer, soundFileShort, soundFile, soundFileFound, numChans, numFrames, sRate;
	var name = "TiltPad", playSynth, tremSynth, spec, startPos, leftShift = 0, rightShift = 0, colorOffset = 0.3;
	var pitchBus, lenBus, startPos, tremBus, volBus;
	var button, slider, bufferView;

	*new {
		arg id = 0, server, path, paramMode = \startLen, win, debug = false;
		^super.newCopyArgs(id, server, path, paramMode, win, debug).initTiltPad;
	}

	initTiltPad {
		this.initVars();
		this.initBuffer();
		this.loadSynthDefs();
		server.sync;
		this.initOSC();
		this.startTremSynth();
		this.buildGUI();
	}

	initVars {
		// init variables
		sRate = server.sampleRate;
		name = name ++ "-" ++ id;
		playSynth = Array.newClear(2);
		pitchBus = Bus.control(server,1).set(1);
		tremBus = Bus.control(server,1).set(0.2);
		volBus = Bus.control(server,1).set(0.5);
		startPos = 0;
		spec = (
			pitch: Env.new([0.5,1,2],[0.5,0.5]),
			trem: Env.new([0.001,0.2],[1])
		);
		button = ();
		slider = ();
	}

	initBuffer {
		if(path.notNil, { // read soundfile in buffer
			soundFileShort = subStr(path, path.findBackwards("/",offset: max(0,(path.size - 30))), path.size);
			soundFile = SoundFile.new;
			if(soundFile.openRead(path), {
				soundFileFound = 1;
				numChans = soundFile.numChannels;
				numFrames = soundFile.numFrames;
				if( paramMode == \startLen, {
					spec[\len] = Env.new([0.5*numFrames/sRate, 0.01], [1], \exp);
					spec[\start] = Env.new([0, 0.9*numFrames/sRate], [1], \lin);
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
		[1,2].do { |numChans|
			SynthDef(\playStartLen++id++numChans, { arg gate = 1, buf, direction = 1, lenBus, start = 0, volBus;
				var sig, env, trig, lenVal, volVal;
				lenVal = In.kr(lenBus,1);
				volVal = In.kr(volBus,1);
				trig = Impulse.kr(1 / lenVal);
				env = EnvGen.kr(Env.adsr(0.01,0,1,0.01), gate, doneAction: 2);
				sig = PlayBufCF.ar(numChans, buf, direction, trig, start * sRate, 1);
				if(numChans == 1, { sig = sig.dup(2) });
				Out.ar(0, sig * env * volVal);
			}).add;
			SynthDef(\playTremPitch++id++numChans, { arg gate = 1, buf, direction = 1, pitchBus, tremBus, volBus;
				var sig, env, tremolo, pitchVal, tremVal, volVal, tremLagged;
				pitchVal = In.kr(pitchBus,1);
				tremVal = In.kr(tremBus,1);
				volVal = In.kr(volBus,1);
				env = EnvGen.kr(Env.adsr(0.01,0,1,0.01), gate, doneAction: 2);
				tremolo = EnvGen.kr(Env.new([0,1,1,0,0],[0.05,1,0.05,0.7]*tremVal,[\sin,\lin,\sin,\lin]).circle);
				tremLagged = Lag.kr(tremolo, 0.1);
				SendReply.kr(Impulse.kr(100), "/tremolo"++id, tremLagged, direction);
				sig = PlayBufCF.ar(numChans, buf, pitchVal * direction, 1, 0, 1);
				if(numChans == 1, { sig = sig.dup(2) });
				Out.ar(0, sig * env * tremolo * volVal);
			}).add;
		};
		SynthDef(\tremolo++id, { arg tremBus;
			var tremolo, tremVal, tremLagged;
			tremVal = In.kr(tremBus,1);
			tremolo = EnvGen.kr(Env.new([0,1,1,0,0],[0.05,1,0.05,0.7]*tremVal,[\sin,\lin,\sin,\lin]).circle);
			tremLagged = Lag.kr(tremolo, 0.1);
			SendReply.kr(Impulse.kr(100), "/tremolo"++id, tremLagged, 0);
		}).add;
	}

	initOSC {
		var elid, value, physValue;
		// OSCdef that catches all tiltpad OSC
		OSCdef(name, { arg msg;
			// msg.postln;
			elid = msg[1];
			value = msg[2];
			physValue = msg[3];
			case
			{ elid == 3 } // yellow button
			{
				this.playBuffer(0,value);
				button[\yellow].value = value;
			}
			{ elid == 4 } // green button
			{
				this.playBuffer(1,value);
				button[\green].value = value;
			}
			{ elid == 6 } // left button
			{
				leftShift = value;
				button[\left].value = value;
				if(paramMode == \tremPitch, {
					slider[\tremolo].knobColor = Color.blue(1,max(colorOffset,value));
				}, {
					if( rightShift == 0 and: { value == 0 },
						{ { bufferView.setSelectionColor(0, Color.blue(1, colorOffset)) }.defer },
						{ { bufferView.setSelectionColor(0, Color.blue(1, 0.5)) }.defer }
					);
				});
			}
			{ elid == 7 } // right button
			{
				rightShift = value;
				button[\right].value = value;
				if(paramMode == \tremPitch, {
					slider[\pitch].hilightColor = Color.red(1,max(colorOffset,value));
				}, {
					if( leftShift == 0 and: { value == 0 },
						{ { bufferView.setSelectionColor(0, Color.blue(1, colorOffset)) }.defer },
						{ { bufferView.setSelectionColor(0, Color.blue(1, 0.5)) }.defer }
					);
				});
			}
			{ elid == 8 } // hatswitch
			{
				case
				{ physValue == 1 }
				{ volBus.get { arg busVal; volBus.set(min(busVal + 0.1, 2)); } }
				{ physValue == 5 }
				{ volBus.get { arg busVal; volBus.set(max(busVal - 0.1, 0.1)); } }
				;
			}
			{ elid == 0 and: { leftShift == 1 } } // X-axis
			{
				case
				{ paramMode == \startLen }
				{
					startPos = spec.start.at(value);
					{ bufferView.setSelectionStart(0, startPos * sRate) }.defer;
					2.do { arg playMode;
						if(playSynth[playMode].notNil, {
							if(debug, { ("set start:"+startPos).postln });
							this.playBuffer(playMode, 0);
							this.playBuffer(playMode, 1);
						});
					}
				}
				{ paramMode == \tremPitch } { tremBus.set(spec.trem.at(value)); if(debug, {("set trem:"+spec.trem.at(value)).postln});  }
				;
			}
			{ elid == 1 and: { rightShift == 1 } } // Y-axis
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
			OSCdef(\tremolo++id, { arg msg;
				var dir = msg[2], val = msg[3];
				case
				{ playSynth[0].notNil } // then use SendReply from 'direction=1'
				{ if(dir == 1, { slider[\tremolo].value_(val) }) }
				{ playSynth[1].notNil } // then use SendReply from 'direction=-1'
				{ if(dir == -1, { slider[\tremolo].value_(val) }) }
				{ true }
				{ if(dir == 0, { slider[\tremolo].value_(val) }) }
				;
			}, '/tremolo'++id).fix;
		});
	}

	startTremSynth {
		if(paramMode == \tremPitch, { tremSynth = Synth(\tremolo++id, [\tremBus, tremBus.index]) });
	}

	playBuffer {
		arg playMode, value;
		if(value == 1 and: { playSynth[playMode].isNil }, {
			case
			{ paramMode == \startLen }
			{
				playSynth[playMode] = Synth(\playStartLen++id++numChans,
					[\buf, buffer, \direction, ( if(playMode==0) {1} {-1} ), \volBus, volBus.index, \lenBus, lenBus.index, \start, startPos])
			}
			{ paramMode == \tremPitch }
			{
				playSynth[playMode] = Synth(\playTremPitch++id++numChans,
					[\buf, buffer, \direction, ( if(playMode==0) {1} {-1} ), \volBus, volBus.index,\pitchBus, pitchBus.index, \tremBus, tremBus.index])
			}
			;
		});
		if(value == 0 and: { playSynth[playMode].notNil }, {
			playSynth[playMode].release; playSynth[playMode] = nil;
		});
	}

	buildGUI {
		var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height - 50;
		var border = 4, view, title;
		var width = screenWidth / 2 - (1.5*border), height = screenHeight / 2 - (1.5*border);
		var left = (id%2) * width + ((id%2+1)*border), top = (id > 1).asInt * height + (((id > 1).asInt + 1)*border);

		if(win.isNil, { // no window passed, create one
			win = Window(name, Rect(left, top, width, height)).onClose_({ this.cleanUp() }).front;
			left = 0; top = 0;
		});

		view = View(win, Rect(left, top, width, height)).background_(Color.white);
		// title = StaticText(view, Rect(110,height - 140,100,100)).string_(id).font_(Font(Font.default,120,true)).stringColor_(Color.grey);
		title = StaticText(view, Rect(0,height - 30,width,20)).string_(name).align_(\center).background_(Color.grey(0.7));
		button[\left] = (SmoothButton(view, Rect(10,height/2,100,80))
			.border_(1).radius_(5).canFocus_(false).font_(Font(Font.default,30))
			.states_([ [ "left\nfront", Color.grey(0.5), Color.grey(0.9) ], [ "left\nfront", Color.white, Color.grey(0.5) ] ])
		);
		button[\right] = (SmoothButton(view, Rect(width - 110,height/2,100,80))
			.border_(1).radius_(5).canFocus_(false).font_(Font(Font.default,30))
			.states_([ [ "right\nfront", Color.grey(0.5), Color.grey(0.9) ], [ "right\nfront", Color.white, Color.grey(0.5) ] ])
		);
		button[\green] = (SmoothButton(view, Rect(width - 220,height - 140,100,100))
			.border_(1).radius_(50).canFocus_(false).font_(Font(Font.default,30))
			.states_([ [ "", Color.black, Color.green(1,colorOffset) ], [ "", Color.black, Color.green(1,1) ] ])
		);
		button[\yellow] = (SmoothButton(view, Rect(width - 330,height - 140,100,100))
			.border_(1).radius_(50).canFocus_(false).font_(Font(Font.default,30))
			.states_([ [ "", Color.black, Color.yellow(1,colorOffset) ], [ "", Color.black, Color.yellow(1,1) ] ])
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
				.setSelectionColor(0, Color.blue(1,colorOffset));
			);
			bufferView.soundfile = soundFile;
			bufferView.read(0, numFrames, 512).refresh;
			bufferView.setSelectionStart(0, 0);
			lenBus.get {arg val; { bufferView.setSelectionSize(0, val * sRate) }.defer };
		}
		{ paramMode == \tremPitch }
		{
			button[\left].bounds = Rect(10,height/4,100,80);
			button[\right].bounds = Rect(width - 110,height/4,100,80);
			button[\green].bounds = Rect(width - 110,height - 140,100,100);
			button[\yellow].bounds = Rect(width - 220,height - 140,100,100);

			slider[\tremolo] = (SmoothSlider(view, Rect(width/4, 20, width/8, height - 60))
				.canFocus_(false).knobSize_(1).border_(1)
				.hilightColor_(Color.white).background_(Color.white).knobColor_(Color.blue(1,colorOffset)).borderColor_(Color.grey)
			);
			slider[\pitch] = (SmoothSlider(view, Rect(3*width/8 + 20, 20, width/8, height - 60))
				.canFocus_(false).knobSize_(0.01).border_(1).value_(0.5)
				.hilightColor_(Color.red(1,colorOffset)).background_(Color.white).knobColor_(Color.black).borderColor_(Color.grey)
			);
		}
		;
	}

	cleanUp {
		(name ++ ": Synth released.").postln;
		2.do { |playMode| if(playSynth[playMode].notNil, { playSynth[playMode].release }) };
		if(paramMode == \tremPitch, { tremSynth.free });
		(name ++ ": buffer freed.").postln;
		buffer.free;
		buffer = nil;
		(name ++ ": OSCdef freed.").postln;
		OSCdef(name).free;
		OSCdef(\tremolo++id).free;
	}

	printOn { arg stream;
		stream << name << "Object with sample:" << path;

	}

}