unit uConaxTransport;

interface 

uses uCommons
     {$IFDEF LINUX}
	,LinuxSerial
     {$ENDIF}
     {$IFDEF WINDOWS}
	,WindowsSerial
     {$ENDIF}
     ,IniFiles, SysUtils,crt, StopWatch ;

type ConaxTransport = class
const 
	CONAX_CLASS = $DD;
	CC_GET_ANSWER = $CA;
	RECV_TIMEOUT = 1000;
	CONFIG_TRANSPORT_SECTION = 'transport';
	CONFIG_PORT = 'port';
	CONFIG_BAUD = 'baud';
	CONFIG_DEBUG = 'debug';
private 
	DEBUG: Boolean;
	port: String;
	baud: Integer;
	handle: TSerialHandle;
	watch: TStopWatch;
	
public
	constructor new(config: TMemIniFile);
	procedure init();
	procedure sendByte(toSend: Byte);
	procedure send(const toSend: ByteArray);
	function readPacket():ByteArray;
	procedure reset();
	procedure sendSynchronized(const toSend:ByteArray);

	function getHandle():TSerialHandle;

end;

implementation

	constructor ConaxTransport.new(config:TMemIniFile);
	begin
		self.port := config.readString(CONFIG_TRANSPORT_SECTION, CONFIG_PORT, '');
		self.baud := config.readInteger(CONFIG_TRANSPORT_SECTION, CONFIG_BAUD, 9600);
		self.DEBUG := config.readBool(CONFIG_TRANSPORT_SECTION, CONFIG_DEBUG, false);
		self.watch := TStopWatch.Create();

		self.init();

	end;

	procedure ConaxTransport.init();
	begin

		handle:=SerOpen(self.port);

		if handle <= 0 then begin
			debugLn(self.className,'error while opening port '+self.port);
			Halt(0);			
		end;

		SerSetParams(handle,self.baud,8,EvenParity,2,[]);

	end;

	procedure ConaxTransport.sendByte(toSend:Byte);
	var echo:Byte = 0;
	begin
		SerWrite(handle,toSend,1);
		SerFlush(handle);
		watch.reset;
		watch.start;
		while (echo <> toSend) do begin 
			while SerAvailable(handle) < 1 do begin
				watch.stop;
				Sleep(5);
				if watch.elapsedmilliseconds > RECV_TIMEOUT then begin
					debugLn(self.className,'[sendByte] Echo not heard, channel error.');
					reset();
					watch.reset;
					exit();
				end;
				watch.start;
			end;
			SerRead(handle,echo,1);
		end;
		watch.reset;
		
	end;

	procedure ConaxTransport.reset();
//	var
//		discardContainer:ByteArray;
	begin		
		SerFlush(handle);
//		SetLength(discardContainer,SerAvailable(handle));
//		SerRead(handle,discardContainer[0],Length(discardContainer));		
	end;

	procedure ConaxTransport.sendSynchronized(const toSend:ByteArray);
	var
		echoContainer:ByteArray;
		readByte: Byte;
	begin
		SetLength(echoContainer,Length(toSend));
		SerWrite(handle,toSend[0],Length(toSend));
		SerFlush(handle);
		watch.reset;
		watch.start;
		while not byteArrayCompare(toSend,echoContainer) do begin
			while SerAvailable(handle) < 1 do begin 
				watch.stop;
				Sleep(5);
				if watch.elapsedmilliseconds > RECV_TIMEOUT then begin
					debugLn(self.className,'[sendSynchronized] Unable to synchronize conversation. Channel error.');
					reset();
					watch.reset;
					exit;
				end;
				watch.start;
			end;
			if SerRead(handle,readByte,1) = 1 then byteArrayRollAdd(echoContainer,readByte) else begin
				debugLn(self.className,'[sendSynchronized] Channel insane. Is something else messing with the port? SerAvailable >1 but SerRead != 1');
			end;
		end;	
		watch.reset;
	end;

	procedure ConaxTransport.send(const toSend: ByteArray);
	var
		echoContainer:ByteArray;
	begin
		sendSynchronized(toSend);
		exit;
		SetLength(echoContainer,Length(toSend));
		SerWrite(handle,toSend[0],Length(toSend));
		watch.reset;
		watch.start;
		while SerAvailable(handle) < Length(toSend) do begin

			sleep(5);
			if watch.elapsedmilliseconds > RECV_TIMEOUT then begin
				debugLn(self.className,'[send] Echo not heard, channel error.');
				reset();
				watch.stop;
				exit();
			end;
		end;
		watch.stop;
		
		SerRead(handle,echoContainer[0],Length(echoContainer));



	end;

	function ConaxTransport.readPacket():ByteArray;
	var
		header:ByteArray;
		dataLen:Byte;
		data:ByteArray;
		packet:ByteArray;
	begin
		SetLength(header,5);

		if SerAvailable(handle) < 5 then begin
			Result:=nil;
			Exit;
		end;
		if (SerRead(handle,header[0],5) <> 5) then begin
			debugLn(self.className,'Available 5, but failed reading 5');
			Result:=nil;
			reset();
			Exit;
		end;
		if header[0] <> CONAX_CLASS then begin

			debugLn(self.className,'Beginning of malformed Conax APDU received '+IntToHex(header[0],2)+' buffer discarded.. dump:');			
			printBuf(header);
			reset();
			Result:=nil;
			Exit;

		end;	

		sendByte(header[1]);	 // instruction ACK

		dataLen := header[4];
				
		if header[1] = CC_GET_ANSWER then begin
			SetLength(data,6);
			Move(header[0],data[0],5);
			data[5] := dataLen;
			data[4] := 1;
			Result := data;
			Exit;	
		end;

		SetLength(data,dataLen);
		if (DEBUG) then debugLn(self.className,'dataLen:'+inttostr(dataLen));

		watch.reset;
		watch.start;
		while SerAvailable(handle) < dataLen do begin 
			watch.stop;
			Sleep(5);
			if watch.elapsedmilliseconds > RECV_TIMEOUT then begin
				debugLn(self.className,'Timeout receiving command. Len:'+inttostr(dataLen));
				printBuf(header);
				reset();
				watch.reset;
				Result:=nil;
				Exit;
			end;
			watch.start;
		end;
		watch.reset;

		if SerRead(handle,data[0],dataLen) <> dataLen then begin
			debugLn(self.className,'Error while reading command');
			reset();
			Result:=nil;
			Exit;
		end;

		if (DEBUG) then begin
			debugLn(self.className,'data:');
			printBuf(data);
		end;

		SetLength(packet,5+dataLen);
		Move(header[0],packet[0],5);
		Move(data[0],packet[5],dataLen);
		Result:=packet;		
		
	end;

	function ConaxTransport.getHandle():TSerialHandle;
	begin
		Result:=handle;
	end;

end.
