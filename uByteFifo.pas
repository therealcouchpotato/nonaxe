unit uByteFifo;

interface

	uses uCommons;

	type ByteFifo = class
	private
		fifoBuffer:Pointer;
		fifoSize:Cardinal;
		fifoCapacity:Cardinal;

	public
		constructor new(capacity: Cardinal);
		function read(var buffer:ByteArray):Cardinal;
		function write(const buffer:ByteArray):Cardinal;	
		function available():Cardinal;	
		procedure reset();
	end;

implementation

	constructor ByteFifo.new(capacity: Cardinal);
	begin
		GetMem(fifoBuffer,capacity);
		fifoSize:=0;
		fifoCapacity:=capacity;
	end;
	
	function ByteFifo.read(var buffer:ByteArray):Cardinal;
	var
		dataSize:Cardinal;
	begin
		Result:=0;

		dataSize:=Length(buffer);
	
		if (fifoSize > 0) and (dataSize > 0) then
		begin
			if fifoSize >= dataSize then begin // if we have enough data
				Move(fifoBuffer^, buffer[0], dataSize);
				fifoSize := fifoSize - dataSize;
				Move(Pointer(PByte(fifoBuffer) + dataSize)^,fifoBuffer^,fifoSize); // move remainder to front
// pointless:			FillChar(Pointer(PByte(fifoBuffer) + dataSize)^, fifoCapacity-fifoSize, 0);				
				Result:= dataSize;
			end;
		end;		
			
	end;

	function ByteFifo.write(const buffer:ByteArray):Cardinal;
	var
		dataSize:Cardinal;
	begin
		dataSize:=Length(buffer);
		if fifoSize+dataSize > fifoCapacity then begin
			Result:=0;
			Exit;
		end;
		Move(buffer[0],Pointer(PByte(fifoBuffer)+fifoSize)^,dataSize);
		fifoSize := fifoSize + dataSize;
		Result:=dataSize;
		
	end;

	function ByteFifo.available():Cardinal;
	begin
		Result:= fifoSize;
	end;

	procedure ByteFifo.reset();
	begin
		FreeMem(fifoBuffer,fifoCapacity);
		GetMem(fifoBuffer,fifoCapacity);
		fifoSize:=0;
	end;

end.
