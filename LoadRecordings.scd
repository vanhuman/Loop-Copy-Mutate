// code to load recordings from /Volumes/LCM/ folder, possibly divided in subfolders
// used in conjunction with LAPIS

(

var path = "/Users/Robert/Desktop/LCM/";
var soundNotes = [72, 73];
var outChan = ~aBus.outA, outMono = 0;
var text;
var level = 1, dist = 1, rate = 1, ff = 20000, playSynth = Array.newClear(2);
var gameStationCount = 0,  micStationCount = 0;
var midiFilter = "MUL"; // MIDI filter for note msgs


~wLoadRecordings = Window("LCM load recordings", Rect(20, 400, 900, 100));
text = (StaticText(~wLoadRecordings, Rect(10,10, 880, 80)).string_("###").font_(Font("Monaco",30)));

OSCdef(\lcmNON, { |msg|
	var chan, note, vel, src;
	var index, sample, files, station;
	chan = msg[1]; note = msg[2]; vel = msg[3]; src = msg[4].asString;
	// ["LCM NON",chan,note,vel, src].postln;
	index = soundNotes.indexOfEqual(note);
	if( index.notNil && (src == midiFilter), {
		case
		{ index == 0 } {
			files = (path++"MicStation/*").pathMatch; station = "MicStation\n";
			if(files.size > 0, {
				sample = files[micStationCount];
				{ text.string = station++sample.subStr( sample.findBackwards("/") ) }.defer;
				playSynth[index] = DiskPlayer.new(s, sample, outChan, mono: outMono,
					loop: 0, bufPwr: 17, autoPlay: true, lev: level * dist, rate: rate, ff: ff);
				micStationCount = (micStationCount + 1) % files.size;
			}, {
				{ text.string = "NO SAMPLES FOUND!" }.defer;
			});
		}
		{ index == 1 } {
			files = (path++"GameStation/*").pathMatch; station = "GameStation\n";
			if(files.size > 0, {
				sample = files[gameStationCount];
				{ text.string = station++sample.subStr( sample.findBackwards("/") ) }.defer;
				playSynth[index] = DiskPlayer.new(s, sample, outChan, mono: outMono,
					loop: 0, bufPwr: 17, autoPlay: true, lev: level * dist, rate: rate, ff: ff);
				gameStationCount = (gameStationCount + 1) % files.size;
			}, {
				{ text.string = "NO SAMPLES FOUND!" }.defer;
			});
		}
		;
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
			level = value;
			2.do {|i| if(playSynth[i].notNil, {
				playSynth[i].set(\lev,level * dist);
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
		// distortion
		if((chan==0 && num==7), {
			dist = value.linexp(0,1,1,50);
			2.do {|i| if(playSynth[i].notNil, {
				playSynth[i].set(\lev,level * dist);
			}) };
		});
	});
},
"/midi/control"
).fix;


~wLoadRecordings.onClose = {
	OSCdef(\lcmNON).free; OSCdef(\lcmNOF).free; OSCdef(\lcmCCLPK).free;
};
~wLoadRecordings.front;

)

