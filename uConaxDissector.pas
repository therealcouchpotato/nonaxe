unit uConaxDissector;

interface

uses uCommons;

type ConaxDissector = class
const
	CONAX_CLASS = $DD;
private
	function validate(const commandBuffer: ByteArray):boolean;

public
	constructor new();
	// extracts the "index"th nano with ID "nano" from "commandBuffer"
	function getNano(const commandBuffer: ByteArray; nano: Byte; index: Byte):ByteArray;
	function getNano(const commandBuffer: ByteArray; nano: Byte; index: Byte; leadingSkip:Integer; dataSkip:Integer):ByteArray; overload;
	function getPacket(const commandBuffer: ByteArray): ByteArray;
	// counts the number of nanos in the "commandBuffer" with ID "nano"
	function count(const commandBuffer: ByteArray; nano: Byte; leadingSkip: Byte): Integer;
	function count(const commandBuffer: ByteArray; leadingSkip:Byte): Integer; overload;
	function count(const commandBuffer: ByteArray): Integer; overload;
	
	
end;

implementation
	constructor ConaxDissector.new();
	begin
	end;

	function ConaxDissector.validate(const commandBuffer: ByteArray):boolean;
	begin
		Result:=false;
		
		if commandBuffer[0] <> CONAX_CLASS then Exit;	// CLASS
		if (commandBuffer[2] <> 0) or (commandBuffer[3] <> 0) then Exit; // P1, P2
		if Length(commandBuffer) <> commandBuffer[4]+5 then Exit;		

		Result:=true;		

	end;

	function ConaxDissector.getNano(const commandBuffer: ByteArray; nano: Byte; index: Byte; leadingSkip:Integer; dataSkip:Integer):ByteArray;
	var
		loc:Integer;
		targetCount:Integer;
		nanoPacket:ByteArray;
	begin
		Result:=nil;
		if not validate(commandBuffer) then Exit;

		loc:=5+leadingSkip;
		targetCount:=0;
		while loc < Length(commandBuffer)-1 do begin
			if commandBuffer[loc] = nano then begin
				if targetCount = index then begin
					inc(loc);
					if commandBuffer[loc] - dataSkip <= 0 then Exit; // skipped too much
					SetLength(nanoPacket,commandBuffer[loc]-dataSkip);
					inc(loc,1+dataSkip);
					Move(commandBuffer[loc],nanoPacket[0],Length(nanoPacket));
					Result:=nanoPacket;
					Exit;
				end;
				inc(targetCount);
			end;

			inc(loc);	// size
			inc(loc,commandBuffer[loc]);   // length		
		
		end;			
	end;

	function ConaxDissector.getNano(const commandBuffer: ByteArray; nano: Byte; index: Byte):ByteArray;
	begin
		Result:=getNano(commandBuffer,nano,index,0,0);
	end;
	
	function ConaxDissector.count(const commandBuffer: ByteArray; nano: Byte; leadingSkip: Byte): Integer;
	var
		nanoCount:Integer;
		loc:Integer;
	begin
		Result:=0;
		if not validate(commandBuffer) then Exit;
		
		nanoCount:=0;
		loc:=5+leadingSkip;

		while loc < Length(commandBuffer)-1 do begin
			if nano <> 0 then begin
				if commandBuffer[loc] = nano then inc(nanoCount)
			end else inc(nanoCount);

			inc(loc);	// size
			inc(loc,commandBuffer[loc]);   // length					
		end;
		
		Result:=nanoCount;		
			
	end;

	function ConaxDissector.count(const commandBuffer: ByteArray): Integer; overload;
	begin
		Result:=count(commandBuffer,0,0);
	end;
	

	function ConaxDissector.count(const commandBuffer: ByteArray; leadingSkip:Byte): Integer; overload;
	begin
		Result:=count(commandbuffer,0,leadingSkip);
	end;

	function ConaxDissector.getPacket(const commandBuffer: ByteArray):ByteArray;
	var packet:ByteArray;
	begin
		Result:=nil;
		if not validate(commandBuffer) then Exit;

		SetLength(packet,commandBuffer[4]);
		Move(commandBuffer[5],packet[0],length(packet));
		Result:=packet;

	end;

end.