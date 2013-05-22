unit uCommons;

interface

uses SysUtils,md5;

type ByteArray = array of Byte;
function hexStringToByteArray(hexString: String):ByteArray;
function Swap32(Value: Cardinal):Cardinal;
function wrapByte(value:Byte; size:Byte):ByteArray;
procedure printBuf(buf: ByteArray); overload;
procedure printBuf(buf: AnsiString); overload;
function readConst(const constArray: array of byte):ByteArray;

function byteArrayCompare(ba1: ByteArray; ba2:ByteArray):Boolean;
procedure byteArrayRollAdd(var ba1: ByteArray; toAdd: Byte);
procedure byteArrayClear(var ba1: ByteArray);

function hashMD5(content:String):AnsiString;
procedure debugLn(className:String; message:String);

implementation

	function Swap32(Value:Cardinal):Cardinal;
	begin
		Result:=
		((Value and $000000FF) shl 24) or
		((Value and $0000FF00) shl 8) or
		((Value and $00FF0000) shr 8) or
		((Value and $FF000000) shr 24); 
	end;

	function hexStringToByteArray(hexString: String):ByteArray;
	var i : Integer;
	    hex : String;
	    ba : ByteArray;
	begin
		if Length(hexString) mod 2 <> 0 then begin
			Result:=nil;
		end;
		SetLength(ba,Length(hexString) div 2);
	
		for i:=0 to (Length(hexString) div 2 )-1 do begin
			hex:='$'+hexString[1+i*2];
			hex:=hex+ hexString[2+i*2];
			ba[i] := strtoint(hex);		
			hex:='';
		end;
		Result:=ba;
	
	end;

	function wrapByte(value:Byte; size:Byte):ByteArray;
	var
		ba: ByteArray;
	begin
		setLength(ba,size);
		Move(value,ba[size-1],1);
		Result:=ba;
	end;

	procedure printBuf(buf: ByteArray); overload;
	var
		i:Integer;
	begin
		for i:=0 to Length(buf)-1 do
			write(IntToHex(buf[i],2));

		writeln();
	end;

	procedure printBuf(buf: AnsiString); overload;
	var
		i:Integer;
	begin
		for i:=1 to Length(buf) do
			write(IntToHex(ord(buf[i]),2));

		writeln();
	end;


	function readConst(const constArray: array of byte):ByteArray;
	var
		ba:ByteArray;
	begin
		SetLength(ba,Length(constArray));
		Move(constArray[0],ba[0],Length(constArray));
		Result:=ba;		
	end;

	function hashMD5(content:String):AnsiString;
	var ba:ByteArray;
	    res:AnsiString;
	begin
		ba:=hexStringToByteArray(MD5Print(MD5String(content)));
		SetLength(res,length(ba));
		Move(ba[0],res[1],length(ba));
		Result:=res;
	end;
	
	function byteArrayCompare(ba1: ByteArray; ba2:ByteArray):Boolean;
	var
		i:Cardinal;
	begin
		Result:=false;

		if Length(ba1) <> Length(ba2) then Exit;
		
		for i:=0 to Length(ba1)-1 do begin
			if ba1[i] <> ba2[i] then Exit;
		end;

		Result:=true;
		
	end;
	
	procedure byteArrayRollAdd(var ba1: ByteArray; toAdd: Byte);
	var
		i:Cardinal;
	begin
		if (Length(ba1) > 1) then begin
			for i:=1 to Length(ba1)-1 do
				ba1[i-1] := ba1[i];
			ba1[Length(ba1)-1] := toAdd;
		end else begin
			ba1[0]:=toAdd;
		end;
		
	end;

	procedure debugLn(className: String; message:String);
	begin
		writeln('['+className+'] '+DateTimeToStr(Now)+' '+message);
	end;

	procedure byteArrayClear(var ba1: ByteArray);
	var
		i:Cardinal;
	begin
		for i:=0 to Length(ba1) -1 do
			ba1[i] := 0;
	end;
end.