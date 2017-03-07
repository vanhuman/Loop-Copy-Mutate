(
var hidDevice = Array.newClear(4);

~docDir = Document.current.dir;

HID.findAvailable.collect { arg device, id; var index;
	index = ~hidDeviceNameTmp.indexOfEqual(device.productName.asSymbol);
	if(index.notNil, {
		~hidDeviceNameTmp[index] = nil;
		hidDevice[index] = HID.openAt(id);
		~devCount = ~devCount + 1;
	})
};

hidDevice
)