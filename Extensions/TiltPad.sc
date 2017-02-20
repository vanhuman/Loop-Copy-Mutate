/*
TiltPad Class / developed for the Loop/Copy/Mutate project of the Genetic Choir / by Robert van Heumen
To trigger and control samples from a Gravis Destroyer Tiltpad
(c) 2017

len helft van sample len, en startpos verschuiven, alsof je loopt rond het 'midden'
verander startPos naar beetje later als length kleiner dan 0.2



*/

TiltPad {
	var id, server, path, paramMode, win, left, top; // arguments
	var buffer, soundFileShort, soundFile, soundFileFound, numChan, numFrames;
	var name = "TiltPad", playSynth, spec, sRate, startPos;
	var view, title;

	*new {
		arg id = 0, server, path, paramMode = \startLen, win, left = 100, top = 300;
		^super.newCopyArgs(id, server, path, paramMode, win, left, top).initTiltPad;
	}

	initTiltPad {
		// init variables
		name = name ++ "-" ++ id;
		playSynth = ();
		sRate = server.sampleRate;
		spec = (
			pitch: Env.new([0.5,1,2],[0.5,0.5])
		);
		this.initBuffer();
		server.sync;
		this.initOSC();
		this.buildGUI();
	}

	initBuffer {
		if(path.notNil, { // read soundfile in buffer
			soundFileShort = subStr(path, path.findBackwards("/",offset: max(0,(path.size - 30))), path.size);
			soundFile = SoundFile.new;
			if(soundFile.openRead(path), {
				soundFileFound = 1;
				numChan = soundFile.numChannels;
				numFrames = soundFile.numFrames;
				if( paramMode == \startLen,
					{ spec[\len] = Env.new([0.01, numFrames/sRate], [1])},
					{ spec[\len] = Env.new([numFrames/sRate,numFrames/sRate],[1]) } // constant full length
				);
				buffer = Buffer.read(server, path);
				soundFile.close;
				("\n" ++ name ++ "\nsoundfile: '" ++ soundFileShort ++ "'\nnumber of channels: " +
					numChan + "\nlength" + (numFrames/sRate).round(0.1) + "sec").postln;
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
				this.playBuffer(\fwd,value);
			}
			{ elid == 5 } // blue button
			{
				this.playBuffer(\bwd,value);
			}
			{ elid == 0 } // X-axis
			{
				playSynth.do { arg synth;
					if(synth.notNil, {
						case
						{ paramMode == \startLen } {  } // startPos
						{ paramMode == \tremPitch } {  } // tremolo speed
						;
					});
				}
			}
			{ elid == 1 } // Y-axis
			{
				playSynth.do { arg synth;
					if(synth.notNil, {
						case
						{ paramMode == \startLen } { synth.set(\len, spec.len.at(value)); ("set len:"+spec.len.at(value)).postln; }
						{ paramMode == \tremPitch } { synth.set(\pitch, spec.pitch.at(value)); ("set pitch:"+spec.pitch.at(value)).postln; }
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
		if(value == 1, {
			if(playSynth[playMode].isNil, { playSynth[playMode] = Synth(\play++paramMode,
				[\buf, buffer, \direction, ( if(playMode==\fwd) {1} {-1} ), \pitch, spec.pitch.at(0.5), \len, spec.len.at(0.5)]) });
		},{
			if(playSynth[playMode].notNil, { playSynth[playMode].release; playSynth[playMode] = nil; })
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