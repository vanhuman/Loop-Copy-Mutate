/*
TiltPad Class / developed for the Loop/Copy/Mutate project of the Genetic Choir / by Robert van Heumen
To trigger and control samples from a Gravis Destroyer Tiltpad
(c) 2017
*/

TiltPad {
	var id, server, path, paramMode, win, debug; // arguments
	var buffer, soundFileShort, soundFile, soundFileFound, numChans, numFrames, sRate;
	var name = "TiltPad", playSynth, spec, startPos, leftShift = 0, rightShift = 0;
	var view, title;
	var pitchBus, lenBus, startPos, tremBus;

	*new {
		arg id = 0, server, path, paramMode = \startLen, win, debug = false;
		^super.newCopyArgs(id, server, path, paramMode, win, debug).initTiltPad;
	}

	*loadSynthDefs {
		arg sRate;
		[1,2].do { |numChans|
			SynthDef(\playStartLen++numChans, { arg gate = 1, buf, lenBus, direction = 1, start = 0;
				var sig, env, trig, lenVal;
				lenVal = In.kr(lenBus,1);
				trig = Impulse.kr(1 / lenVal);
				env = EnvGen.kr(Env.adsr(0.01,0,1,0.01), gate, doneAction: 2);
				sig = PlayBufCF.ar(numChans, buf, direction, trig, start * sRate, 1);
				if(numChans == 1, { sig = sig.dup(2) });
				Out.ar(0, sig * env);
			}).add;
			SynthDef(\playTremPitch++numChans, { arg gate = 1, buf, pitchBus, direction = 1, tremBus;
				var sig, env, tremolo, pitchVal, tremVal;
				pitchVal = In.kr(pitchBus,1);
				tremVal = In.kr(tremBus,1);
				env = EnvGen.kr(Env.adsr(0.01,0,1,0.01), gate, doneAction: 2);
				tremolo = EnvGen.kr(Env.new([0,1,1,0,0],[0.05,1,0.05,0.7]*tremVal,[\sin,\lin,\sin,\lin]).circle);
				sig = PlayBufCF.ar(numChans, buf, pitchVal * direction, 1, 0, 1);
				if(numChans == 1, { sig = sig.dup(2) });
				Out.ar(0, sig * env * tremolo);
			}).add;
		};
		"\n### TiltPad Class Method: Loaded SynthDefs\n".postln;
	}

	initTiltPad {
		this.initVars();
		this.initBuffer();
		server.sync;
		this.initOSC();
		this.buildGUI();
	}

	initVars {
		// init variables
		sRate = server.sampleRate;
		name = name ++ "-" ++ id;
		playSynth = Array.newClear(2);
		pitchBus = Bus.control(server,1).set(1);
		tremBus = Bus.control(server,1).set(0.2);
		startPos = 0;
		spec = (
			pitch: Env.new([0.5,1,2],[0.5,0.5]),
			trem: Env.new([0.001,0.2],[1])
		);
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
					spec[\start] = Env.new([0, 0.5*numFrames/sRate], [1], \lin);
				}, { // constant full length and startPos to 0
					spec[\len] = Env.new([numFrames/sRate,numFrames/sRate],[1]);
					spec[\start] = Env.new([0,0],[1]);
				});
				lenBus = Bus.control(server,1).set(0.5*numFrames/sRate);
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

	initOSC {
		var elid, value;
		// OSCdef that catches all tiltpad OSC
		OSCdef(name, { arg msg;
			// msg.postln;
			elid = msg[1];
			value = msg[2];
			case
			{ elid == 3 } // yellow button
			{
				this.playBuffer(0,value);
			}
			{ elid == 4 } // green button
			{
				this.playBuffer(1,value);
			}
			{ elid == 6 } // left button
			{
				leftShift = value;
			}
			{ elid == 7 } // right button
			{
				rightShift = value;
			}
			{ elid == 0 and: { leftShift == 1 } } // X-axis
			{
				2.do { arg playMode;
					if(playSynth[playMode].notNil, {
						case
						{ paramMode == \startLen } {
							startPos = spec.start.at(value);
							if(debug, { ("set start:"+startPos).postln });
							this.playBuffer(playMode, 0);
							this.playBuffer(playMode, 1);
						}
						{ paramMode == \tremPitch } { tremBus.set(spec.trem.at(value)); if(debug, {("set trem:"+spec.trem.at(value)).postln});  }
						;
					});
				}
			}
			{ elid == 1 and: { rightShift == 1 } } // Y-axis
			{
				2.do { arg playMode;
					if(playSynth[playMode].notNil, {
						case
						{ paramMode == \startLen } { lenBus.set(spec.len.at(value)); if(debug, {("set len:"+spec.len.at(value)).postln}); }
						{ paramMode == \tremPitch } { pitchBus.set(spec.pitch.at(value)); if(debug, {("set pitch:"+spec.pitch.at(value)).postln}); }
						;
					});
				}
			}
			;
		}, "/hid/tiltpad"++id
		).fix;
	}

	playBuffer {
		arg playMode, value;
		if(value == 1 and: { playSynth[playMode].isNil }, {
			case
			{ paramMode == \startLen }
			{
				playSynth[playMode] = Synth(\playStartLen++numChans,
					[\buf, buffer, \direction, ( if(playMode==0) {1} {-1} ), \lenBus, lenBus.index, \start, startPos])
			}
			{ paramMode == \tremPitch }
			{
				playSynth[playMode] = Synth(\playTremPitch++numChans,
					[\buf, buffer, \direction, ( if(playMode==0) {1} {-1} ), \pitchBus, pitchBus.index, \tremBus, tremBus.index])
			}
			;
		});
		if(value == 0 and: { playSynth[playMode].notNil }, {
			playSynth[playMode].release; playSynth[playMode] = nil;
		});
	}

	buildGUI {
		var screenWidth = Window.screenBounds.width, screenHeight = Window.screenBounds.height;
		var width = screenWidth / 2, height = screenHeight / 2, left = (id%2) * width, top = (id > 1).asInt * height;
		if(win.isNil, { // no window passed, create one
			win = Window(name, Rect(left, top, width, height));
			win.onClose = {
				this.cleanUp();
			};
			win.front;
		}, { // place a view on the window
			view = View(win, Rect(left, top, width, height));
			title = StaticText(view, Rect(10,10,200,20)).string("TiltPad"+id);
		});
	}

	cleanUp {
		(name ++ ": Synth released.").postln;
		playSynth.do { arg synth; synth.release; };
		(name ++ ": buffer freed.").postln;
		buffer.free;
		buffer = nil;
		(name ++ ": OSCdef freed.").postln;
		OSCdef(name).free;
	}

	printOn { arg stream;
		stream << name << "Object with sample:" << path;

	}

}