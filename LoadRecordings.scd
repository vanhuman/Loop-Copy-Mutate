// code to load recordings from /Volumes/LCM/ folder, possibly divided in subfoders

(

// var path = "/Volumes/LCM/";
var path = "/Users/Robert/Desktop/LCM/";
var soundTypes = [\texture, \melody];
var soundNotes = [72, 73];
var win, text;
var level = 1, rate = 1, ff = 20000, soundLists = [ [ ], [ ] ], soundListsDisp = [ [ ], [ ] ], playSynth = Array.newClear(2);

// initialize
soundTypes.size.do { arg index;
	soundLists[index] = (path++soundTypes[index]++"/*").pathMatch;
	soundListsDisp[index] = Array.newClear(soundLists[index].size);
	soundLists[index].size.do { |i|
		var path = soundLists[index][i];
		soundListsDisp[index][i] = subStr(path, path.findBackwards("/") + 1, path.size);
	};
	("\nSound type " ++ soundTypes[index] ++ ":\n" ++ soundListsDisp[index]).postln;
};

win = Window("LCM load recordings", Rect(20, 300, 700, 100));
text = (StaticText(win, Rect(10,10, 680, 80)).string_("###").font_(Font("Monaco",30)));

OSCdef(\lcmNON, { |msg|
	var chan, note, vel, src;
	var index, sample, chosen;
	chan = msg[1]; note = msg[2]; vel = msg[3]; src = msg[4].asString;
	// ["LCM NON",chan,note,vel, src].postln;
	index = soundNotes.indexOfEqual(note);
	if( index.notNil, {
		chosen = rand( soundLists[index].size );
		sample = soundLists[index].at(chosen);
		("\nSample of type" + soundTypes[index] + "chosen:" + soundListsDisp[index].at(chosen)).postln;
		{ text.string = soundTypes[index] ++ ":" + soundListsDisp[index].at(chosen) }.defer;
		playSynth[index] = DiskPlayer.new(s, sample, ~aBus.outMain, loop: 1, bufPwr: 17, autoPlay: true, lev: level, rate: rate, ff: ff);
	});

}, "/midi/noteOn").fix;

OSCdef(\lcmNOF, { |msg|
	var chan, note, vel, src;
	var index;
	chan = msg[1]; note = msg[2]; vel = msg[3]; src = msg[4].asString;
	// ["LCM NOF",chan,note,vel, src].postln;
	index = soundNotes.indexOfEqual(note);
	if( index.notNil, {
		playSynth[index].remove;
		playSynth[index] = nil;
	});
}, "/midi/noteOff").fix;

OSCdef(\lcmCCLPK, { |msg|
	var chan, num, value, src;
	chan = msg[1];
	num = msg[2];
	value = msg[3];
	src = msg[4].asString;
	// ["OSC: lcmCCLPK",chan,num,value, src].postln;

	// only process midi if coming from the right source
	if(src == "LPK", {
		// volume
		if((chan==0 && num==3), {
			level = value.linlin(0,1,0,3);
			2.do {|i| if(playSynth[i].notNil, {
				playSynth[i].set(\lev,level);
			}) };
		});
		// filter frequency
		if((chan==0 && num==2), {
			ff = value.linexp(0,1,50,20000);
			2.do {|i| if(playSynth[i].notNil, {
				playSynth[i].set(\ff,ff);
			}) };
		});
		// rate
		if((chan==0 && num==1), {
			rate = value.linlin(0,1,0.8,1.2);
			2.do {|i| if(playSynth[i].notNil, {
				playSynth[i].set(\rate,rate);
			}) };
		});
	});
},
"/midi/control"
).fix;


win.onClose = {
	OSCdef(\lcmNON).free; OSCdef(\lcmNOF).free; OSCdef(\lcmCCLPK).free;
};
win.front;

)
