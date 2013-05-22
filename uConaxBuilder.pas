unit uConaxBuilder;

interface

uses uCommons;

type ConaxBuilder = class
private
	buffer: ByteArray;
public
	constructor new();
	procedure append(nano:Byte; packet:ByteArray);
	function getBuffer():ByteArray;
end;

implementation

	constructor ConaxBuilder.new();
	begin
	end;
	
	procedure ConaxBuilder.append(nano:Byte; packet:ByteArray);
	var offset:Integer;
	begin
		offset:=Length(buffer);
		SetLength(buffer, Length(buffer)+Length(packet)+2);
		buffer[offset]:= nano;
		buffer[offset+1]:= Length(packet);
		Move(packet[0],buffer[offset+2],Length(packet));
	end;

	function ConaxBuilder.getBuffer():ByteArray;
	begin
		Result:= buffer;
	end;

	
end.
	