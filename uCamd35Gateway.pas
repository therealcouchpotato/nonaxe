unit uCamd35Gateway;

interface

uses uCommons, IniFiles, synacode, synacrypt, blcksock,sysutils;

type Camd35Gateway = class
const
	REQ_SIZE = 584; 
	CONFIG_CAMD_SECTION = 'camd35';
	CONFIG_DEBUG = 'debug';
	CONFIG_HOST = 'host';
	CONFIG_PORT = 'port';
	CONFIG_USER = 'user';
	CONFIG_PRVID = 'prvid';
	CONFIG_SRVID = 'srvid';
	CONFIG_CAID = 'caid';
	CONFIG_PASSWORD = 'password';
	CONFIG_SENDEMM = 'sendemm';
	CONFIG_ECM_TIMEOUT = 'ecmTimeout';

	COMMAND_ECM = $00;
	RESPONSE_ECM = $01;
	COMMAND_EMM = $06;
	RESPONSE_STOP = $08;
	OSCAM_ERROR = $44;
private
	debug : Boolean;
	ecmTimeout:Integer;
	prvid: ByteArray;
	srvid: ByteArray;
	caid: ByteArray;
	host: String;
	port: String;
	user: String;
	password: String;
	socket:	TUDPBlockSocket;
	token: ByteArray;	
	sendEMM: Boolean;
	crypter: TSynaAES;

	function makeToken(user: String):ByteArray;
	function encryptPacket(const buffer: ByteArray):ByteArray;
	function decryptPacket(const buffer: ByteArray):ByteArray;
	function initSocket(host: String; port: String):TUDPBlockSocket;
public
	constructor new(config: TMemIniFile);
	procedure doEMM(const emmPacket: ByteArray);
	function processECM(const ecmPacket:ByteArray):ByteArray;

end;

implementation

	constructor Camd35Gateway.new(config: TMemIniFile);
	begin             
		debug := config.readBool(CONFIG_CAMD_SECTION,CONFIG_DEBUG,false);
		host := config.ReadString(CONFIG_CAMD_SECTION,CONFIG_HOST,'');
		port := config.ReadString(CONFIG_CAMD_SECTION,CONFIG_PORT,'');
		user := config.ReadString(CONFIG_CAMD_SECTION,CONFIG_USER,'');
    prvid := hexStringToByteArray(config.readString(CONFIG_CAMD_SECTION,CONFIG_PRVID,'00000000'));
    srvid := hexStringToByteArray(config.readString(CONFIG_CAMD_SECTION,CONFIG_SRVID,'0000'));
    caid := hexStringToByteArray(config.readString(CONFIG_CAMD_SECTION,CONFIG_CAID,'0000'));    
		password := config.ReadString(CONFIG_CAMD_SECTION,CONFIG_PASSWORD,'');
		sendEMM := config.ReadBool(CONFIG_CAMD_SECTION,CONFIG_SENDEMM,false);
		ecmTimeout := config.ReadInteger(CONFIG_CAMD_SECTION,CONFIG_ECM_TIMEOUT,1000);

		token := makeToken(self.user);
		
		socket := initSocket(host, port);

		crypter := TSynaAES.Create(hashMD5(password));

		debugLn(self.className,'Init ok.');
	end;
	
	function Camd35Gateway.makeToken(user: String):ByteArray;
	var
		userMd5: AnsiString;
		tokenCrc: Cardinal;
		token: ByteArray;
	begin
		SetLength(token,4);

		userMd5 := hashMD5(user);
		tokenCrc := NToBe(CRC32(userMd5));
		
		Move(tokenCrc,token[0],4);
		
		Result:=token;
				
	end;

	function Camd35Gateway.initSocket(host: String; port: String):TUDPBlockSocket;
	var
		socket: TUDPBlockSocket;
	begin


		socket := TUDPBlockSocket.Create;

		socket.Connect(host,port);

		if socket.LastError <> 0 then begin
			debugLn(self.className,'Unable to open UDP socket. Error: '+ socket.LastErrorDesc);
			Halt(0);
		end;	
	
		Result:=socket;

	end;

	function Camd35Gateway.encryptPacket(const buffer: ByteArray): ByteArray;
	var	block:AnsiString;
	    	encBlock:AnsiString;
	    	wholeBlocks:Integer;    
	    	remainderLength:Integer;
	    	i:Integer;
	    	encPacket:ByteArray;
	begin

		SetLength(block,16);
		wholeBlocks := Length(buffer) div 16;
		remainderLength := Length(buffer) - (wholeBlocks*16);
		if (remainderLength>0) then SetLength(encPacket,((wholeBlocks+1)*16)) else SetLength(encPacket,wholeBlocks*16);	
	
	
		for i:=0 to wholeBlocks-1 do begin
			Move(buffer[i*16],block[1],16);
			encBlock:=crypter.EncryptECB(block);
			Move(encBlock[1],encPacket[i*16],16);
		end;
	
		if (remainderLength>0) then begin
			FillChar(block[1],16,0); // nullpadding because padding is basically ignored
			Move(buffer[wholeBlocks*16],block[1],remainderLength);
			encBlock:=crypter.EncryptECB(block);
			Move(encBlock[1],encPacket[wholeBlocks*16],16);
		end;
	
		Result:=encPacket;			
	end;

	function Camd35Gateway.decryptPacket(const buffer: ByteArray): ByteArray;
	var 	block: AnsiString;
		encBlock: AnsiString;
		blocks: Integer;
		packet: ByteArray;
		i: integer;
	begin

		if (Length(buffer) mod 16 <> 0) then begin
			debugLn(self.className,'decryptPacket must receive whole cypher blocks');
			Result:=nil;
		end;
		blocks := Length(buffer) div 16;
		SetLength(packet,blocks*16);
		SetLength(block,16);
		SetLength(encBlock,16);
		
		for i:=0 to blocks-1 do begin
			Move(buffer[i*16],encblock[1],16);
			block:=crypter.DecryptECB(encBlock);
			Move(block[1],packet[i*16],16);
		end;
		
		Result:=packet;		
		
	end;

	procedure Camd35Gateway.doEMM(const emmPacket: ByteArray);
	var
		crc: Cardinal;
		packet:AnsiString;
		payload: ByteArray;		
		encryptedCommand: ByteArray;		
		finalPacket: AnsiString;
	begin		

		if not sendEMM then Exit;

		SetLength(packet,Length(emmPacket));
		Move(emmPacket[0],packet[1],Length(emmPacket));
		crc:=NToBe(Crc32(packet));

		SetLength(payload,REQ_SIZE);
		payload[0] := COMMAND_EMM;
		payload[1] := Length(emmPacket);
		payload[2] := $FF;
		payload[3] := $FF;
		Move(crc,payload[4],4);
		Move(srvid[0],payload[8],2);
		Move(caid[0],payload[10],2);
		Move(prvid[0],payload[12],4);
		
		Move(emmPacket[0],payload[20],Length(emmPacket));

		encryptedCommand:=encryptPacket(payload);

		SetLength(finalPacket,4+Length(encryptedCommand));
		Move(token[0],finalPacket[1],4);
		Move(encryptedCommand[0],finalPacket[5],Length(encryptedCommand));
		
		socket.SendString(finalPacket); 
		
	end;

	function Camd35Gateway.processECM(const ecmPacket: ByteArray):ByteArray;
	var
		crc: Cardinal;
		packet:AnsiString;
		payload: ByteArray;
		encryptedCommand: ByteArray;		
		finalPacket: AnsiString;
		response : AnsiString;
		responsePayload: ByteArray;
		responsePacket: ByteArray;
		controlWord:ByteArray;
	begin		
		Result:=nil;

		SetLength(packet,Length(ecmPacket));
		Move(ecmPacket[0],packet[1],Length(ecmPacket));
		crc:=NToBe(Crc32(packet));

		SetLength(payload,REQ_SIZE);
		payload[0] := COMMAND_ECM;
		payload[1] := $FF;
		payload[2] := $FF;
		payload[3] := $FF;
		Move(crc,payload[4],4);
		Move(srvid[0],payload[8],2);
		Move(caid[0],payload[10],2);
		Move(prvid[0],payload[12],4);
		
		Move(ecmPacket[0],payload[20],Length(ecmPacket)); // as it turns out size can be extracted from within the ECM packet
								  // that's what oscam does now. re: lack of size info in header
		encryptedCommand:=encryptPacket(payload);

		SetLength(finalPacket,4+Length(encryptedCommand));
		Move(token[0],finalPacket[1],4);
		Move(encryptedCommand[0],finalPacket[5],Length(encryptedCommand));
				
		socket.Purge; // kill any delayed response that might have arrived after a previous timeout

		socket.SendString(finalPacket); 

		response:= socket.RecvPacket(ecmTimeout);

		if Length(response) < 20 then begin // 1 cypherblock = 16 bytes plus the checksum (4)
			if (debug) then debugLn(self.className,'Timeout or wrong response. Len:'+inttostr(Length(response)));
			Result:=nil;
			Exit;
		end;	
		
		SetLength(responsePayload,Length(response)-4);
		Move(response[5],responsePayload[0],Length(response)-4);

		responsePacket:=decryptPacket(responsePayload);		

		if (Length(responsePacket) < 16) then begin
			if (debug) then begin
				 debugLn(self.className,' Could not decrypt ECM response');
				 printBuf(responsePacket);
			end;
			Result:=nil;
			Exit;
		end;
		
		if (responsePacket[0] = RESPONSE_ECM) then begin
			SetLength(controlWord,16);
			Move(responsePacket[20],controlWord[0],16);				
			Result:=controlWord;
		end else begin
			if (debug) then begin
				 debugLn(self.className,' Wrong response. Id:0x'+IntToHex(responsePacket[0],2));
				 printBuf(ecmPacket);
			end;

		end;
		
	end;


end.