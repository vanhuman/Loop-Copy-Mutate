

Freesound.authType = "token";// default, only needed if you changed it
Freesound.token="oC4YE20F2RWasWq428IZ0YBFxGcrU3zTBcPF5JtL";

(
FSSound.getSound(370700, {|f|
    ~snd = f;
    ~snd["name"].postln;
});
)

(
~snd.getSimilar( action:{|p|
	p.size.postln;
	10.do { |i| p[i].name.postln }
})
)

~snd.dict.keys;
~snd.name;
~snd["name"];
~snd.tags;
~snd.duration;
~snd.url;
// preview url keys have dashes, only work as dict keys
~snd.previews["preview-hq-ogg"];

// download preview (Buffer.read requires recent libsndfile)
~preview = ~snd.retrievePreview("/tmp/", {
        ~buf = Buffer.read(s, "/tmp/" ++ ~snd.previewFilename);
        "done!".postln;
});

"/tmp/" ++ ~snd.previewFilename.postln;
~buf.play;

~snd.getSimilar( action:{|p| ~snd = p[1] ; })
~snd["name"].postln;

~preview = ~snd.retrievePreview("/tmp/", {
        ~buf = Buffer.read(s, "/tmp/" ++ ~snd.previewFilename);
        "done!".postln;
});
~buf.play;

~snd.getAnalysis( "lowlevel.pitch", {|val|
            val.lowlevel.pitch.mean.postln;
}, true)
