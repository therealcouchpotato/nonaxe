unit uFlowControlResetWatcher;

interface

uses uResetWatcher, IniFiles, SysUtils, uCommons
     {$IFDEF LINUX}
	,LinuxSerial
     {$ENDIF}
     {$IFDEF WINDOWS}
	,WindowsSerial
     {$ENDIF}
     ;

type FlowControlResetWatcher = class(TInterfacedObject, IResetWatcher)
const
	CONFIG_SECTION_FLOWCONTROLRESET='flowControlReset';
	CONFIG_PIN='pin';
	CONFIG_INVERTED='inverted';
	CTS = 1;
	DSR = 2;
	RI = 3;
private
	pin:Byte;
	state:Boolean;		
	idleState:Boolean;
	handle:TSerialHandle;
	function getState():Boolean;
public
	constructor new(config: TMemIniFile; handle: TSerialHandle);
	function isReset():Boolean;
end;		

implementation

	constructor FlowControlResetWatcher.new(config: TMemIniFile; handle: TSerialHandle);
	var 
		pinName:String;
	begin
		pinName:=UpperCase(config.readString(CONFIG_SECTION_FLOWCONTROLRESET,CONFIG_PIN,'CTS'));

		if (pinName = 'CTS') then begin
			pin:=CTS;
		end else if (pinName = 'DSR') then begin
			pin:=DSR;
		end else if (pinName = 'RI') then begin
			pin:=RI;
		end else begin
			debugLn(self.className,'Pin name defined in config is invalid. valid: cts,dsr,ri');
			Halt(0);
		end;
		
		idleState := config.readBool(CONFIG_SECTION_FLOWCONTROLRESET,CONFIG_INVERTED,false) = false;		
		self.handle := handle;

		debugLn(self.className,'Using pin: '+pinName);
	end;

	function FlowControlResetWatcher.getState():Boolean;
	begin	    	
	     case pin of
		CTS: Result:= SerGetCTS(handle);
		DSR: Result:= SerGetDSR(handle);
		RI: Result:= SerGetRI(handle);	     
	     end;	
	end;

       	function FlowControlResetWatcher.isReset():Boolean;
	var newState:boolean;	
	begin
		Result:=false;
		newState:=getState();
		if (state = idleState) and (newState = not idleState) then Result:=true;
		state:=newState;
	end;

	

end.