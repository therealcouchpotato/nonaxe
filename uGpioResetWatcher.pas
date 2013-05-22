unit uGpioResetWatcher;

interface

uses uResetWatcher, BaseUnix, IniFiles, SysUtils, uCommons;

type GpioResetWatcher = class(TInterfacedObject, IResetWatcher)
const
	CONFIG_SECTION_GPIORESET='gpioReset';
	CONFIG_GPIO_DEVICE='device';
	CONFIG_GPIO_PIN='pin';
	GPIO_DIR_IN : Cardinal = $2000420D;
	GPIO_DIR_OUT : Cardinal = $2000420E;
	GPIO_GET : Cardinal = $2000420A;
	GPIO_SET : Cardinal = $2000420B;
	GPIO_CLEAR : Cardinal = $2000420C;
private
	gpioDevFd:Cint;
	device:String;
	pin:Cardinal;
	state:Boolean;
	procedure initPin(device:String; pin:Integer);

public

	constructor new(config:TMemIniFile);
	function getState():Boolean;
	function isReset():Boolean;
end;

implementation

	constructor GpioResetWatcher.new(config:TMemIniFile);
	begin
		device:=config.readString(CONFIG_SECTION_GPIORESET,CONFIG_GPIO_DEVICE,'/dev/gpio');
		pin:=config.ReadInteger(CONFIG_SECTION_GPIORESET,CONFIG_GPIO_PIN,3);
		
		debugLn(self.className, 'Using '+device+' pin:'+IntToStr(pin));
		
		initPin(device, pin);

		state:=false; // Reset is active high, initial state = low
	end;

	procedure GpioResetWatcher.initPin(device:String; pin: Integer);
	begin
		gpioDevFd:=fpOpen(device,O_RdWr);
		if gpioDevFd < 0 then begin
			debugLn(self.className,'Unable to open gpio device');			
			Halt(0);			
		end;
		if fpIoCtl(gpioDevFd,GPIO_DIR_IN, Pointer(pin)) < 0 then begin
			debugLn(self.className,'Unable to set pin direction');			
			Halt(0);			
		end;
		state:=getState();

	end;

	function GpioResetWatcher.getState():Boolean;
	begin	    		     
	     Result:= fpIoCtl(gpioDevFd,GPIO_GET,Pointer(pin)) > 0;
	end;

	function GpioResetWatcher.isReset():Boolean;
	var newState:boolean;	
	begin
		Result:=false;
		newState:=getState();
		if (state = false) and (newState = true) then Result:=true; // _|~
		state:=newState;
	end;

end.