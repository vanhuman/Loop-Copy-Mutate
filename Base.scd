
// OSC IN monitor, format: OSC IN -- IP -- port -- message
thisProcess.oscInMonitor(true, addr:1);
thisProcess.oscInMonitor(true, addr:1, excl: ['/InBus','/hid/ex3d', '/ard/ana', '/midi/control']);
thisProcess.oscInMonitor(true, addr:1, excl: ['/InBus','/hid/ex3d', '/ard/ana']);
thisProcess.oscInMonitor(true, addr:1, excl: ['/hid/ex3d','/hybridCtr','/act']);
thisProcess.oscInMonitor(false);
