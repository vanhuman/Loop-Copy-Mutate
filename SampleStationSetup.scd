(
var wSetup = Window("Setup", Rect(200, Window.screenBounds.height - 600, 540, 450)).background_(Color.new255(192,192,192));
var hidChooser = Array.newClear(4);
var hidDeviceName = ["No Game Controller", "Destroyer Gamepad", "Logitech Attack 3", "Firestorm Wireless Gamepad", "WingMan RumblePad"];
var hidDeviceId = [\none, \dest, \att, \fire, \wing];
var bStart, startText, bStartBack, styleChooser, styleText, fSaveSettings, fReadSettings;
var font = "Didot";
var configFolder = if(~standalone.notNil and: { ~standalone },
	{ Platform.resourceDir ++ "/SampleStation_files/" }, { Document.current.dir ++ "/" });

~hidDevices = Array.newClear(4);
~skins = [\Silver, \Pink, \Blue];
~skin = \Silver;
if(~standalone.isNil, {~standalone = false});

// hide IDE
if(~standalone, {
	"osascript -e 'tell application \"System Events\" to set visible of process \"SampleStation\" to false'".unixCmd;
});

// functions
fReadSettings = {
	// read config
	var config = "Config.scd".loadRelative[0].clump(4);
	~skin = config[3][0];
	~hidDevices = config[2];

	// set values from config file
	styleChooser.valueAction_(~skins.indexOf(~skin));
	4.do { |i|
		hidChooser[i].valueAction_(hidDeviceId.indexOf(~hidDevices[i]	));
	};
};

fSaveSettings = {
	var file, fileContents, path, deviceOffset = 8, skinLocation = 12;
	path = configFolder++"Config.scd";
	fileContents = path.load;
	fileContents[skinLocation] = ~skin;
	4.do { |i|
		fileContents[deviceOffset + i] = ~hidDevices[i];
	};
	file = File(path,"w");
	file.write(fileContents.asCompileString);
	file.close;
};

// GUI
StaticText(wSetup, Rect(20, 30, wSetup.bounds.width - 40, 50)).string_("LOOP-COPY-MUTATE")
.font_(Font(font, 40, true)).align_(\center).stringColor_(Color.white);
StaticText(wSetup, Rect(20, 90, wSetup.bounds.width - 40, 60)).string_("SampleStation | Setup")
.font_(Font(font, 30)).align_(\center).stringColor_(Color.white);

4.do { arg index;
	var left = index%2 * 260, top = (index/2).floor * 80;
	StaticText(wSetup, Rect(20 + left, 180 + top, 240, 24)).string_("Choose game controller number" + (index+1))
	.font_(Font(Font.default, 10));
	hidChooser[index] = (PopUpMenu(wSetup, Rect(20 + left, 205 + top, 240, 24))
		.items_(hidDeviceName)
	);
};

styleText = StaticText(wSetup, Rect(20, 335, 240, 24)).string_("Choose skin").font_(Font(Font.default, 10));
styleChooser = (PopUpMenu(wSetup, Rect(20, 360, 240, 24))
	.items_(~skins)
	.action_({ |p|
		~skin = ~skins[p.value];
	})
);

startText = (StaticText(wSetup, Rect(20, 360, 500, 24)).string_("Please wait while the application is starting up...")
	.visible_(false).align_(\center)
);
bStartBack = StaticText(wSetup, Rect(277, 357, 246, 30)).background_(Color.white);
bStart = (SmoothButton(wSetup, Rect(280, 360, 240, 24))
	.states_([ [ "Start SampleStation", Color.white, Color.grey(0.8) ], [ "Start SampleStation", Color.white, Color.black ] ])
	.border_(1).radius_(2).canFocus_(false)
	.action_({
		// hide start button and periferals
		bStart.visible = false;
		bStartBack.visible = false;
		styleChooser.visible = false;
		styleText.visible = false;
		// show starting up text
		startText.visible = true;
		// pass chosen devices
		4.do { arg index;
			~hidDevices[index] = hidDeviceId[ hidChooser[index].value ];
		};
		// save chosen devices and skin
		fSaveSettings.value();
		// load sample station
		if(~standalone, {
			(Platform.resourceDir ++ "/SampleStation_files/SampleStation.scd").load;
		}, {
			(Document.current.dir ++ "/SampleStation.scd").load;
		});
	})
);

StaticText(wSetup, Rect(20, 400, wSetup.bounds.width - 40, 50)).string_("© Robert van Heumen 2018")
.font_(Font(Font.default, 10)).align_(\center);

if(~standalone, {
	wSetup.onClose = {
		// stop sclang
		0.exit;
		// stop the IDE
		"osascript -e 'tell application \"SampleStation\" to quit'".unixCmd;
	};
});

// key down actions
wSetup.view.keyDownAction = {
	arg view, char, modifiers, unicode, keycode, key;
	// keycode.postln;
	case
	{ ( keycode == 12 and: { modifiers.isCmd } ) } { wSetup.close }; // cmd-Q
	};

fReadSettings.value();

wSetup.front;
~wSetup = wSetup;
)