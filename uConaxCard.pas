unit uConaxCard;

interface

uses 	uCommons, 
	uConaxCardInfo, 
	uConaxTransport, 
	uCamd35Gateway, 
	uResetWatcher, 
	uByteFifo,
	uConaxBuilder,
	uConaxDissector, 
	SysUtils,
	IniFiles,
	crt, 
	stopwatch;

type ConaxCard = class
const

	CW_SIZE = 16;

	CC_GET_ANSWER = $CA;

	CC_CARD_READ_RECORD = $26;
	CC_CARD_READ_SERIAL = $C2;
	CC_CARD_IDENTIFY = $82;

	CC_ECM = $A2;
	CC_EMM = $84;

	CC_RESPONSE_ACK_DATA = $98;
	CC_RESPONSE_ACK_EMPTY = $90;	
	
	CONFIG_SECTION_EMULATOR='emulator';
	CONFIG_DEBUG='debug';
	CONFIG_DEBUG_RESET='debugReset';
	CONFIG_DEBUG_TRACE='debugTrace';
	CONFIG_DEBUG_COMMAND_DUMP='debugCommandDump';
	CONFIG_DEBUG_ECM_DUMP='debugEcmDump';
	CONFIG_DEBUG_ECM_TIMING='debugEcmTiming';
	CONFIG_DEBUG_EMM_DUMP='debugEmmDump';


	CONFIG_NO_ACCESS_MODE='noAccessMode';
	CONFIG_ACCEPT_IDENTIFY='acceptIdentify';

private	
	debug : Boolean;
	debugReset : Boolean;
	debugTrace : Boolean;
	debugCommandDump : Boolean;
	debugEcmDump : Boolean;
	debugEcmTiming : Boolean;
	debugEmmDump : Boolean;

	acceptIdentify : Boolean;
	sendNoAccess : Boolean;
	errorCode : Byte;
	gateway : Camd35Gateway;
	resetWatcher : IResetWatcher;
	cardInfo: ConaxCardInfo;
	dissector: ConaxDissector;
	transport: ConaxTransport;
	ecmCounter: Cardinal;
	emmCounter: Cardinal;
	watch : TStopWatch;
	lastEcm: ByteArray;
	lastControlWord: ByteArray;
	
	answerQueue : ByteFifo;

	procedure reset();
	procedure handleCommand(const command:ByteArray);
	procedure handleAnswer(const command:ByteArray);
	procedure handleReadRecord(const command:ByteArray);
	procedure handleReadSerial(const command:ByteArray);
	procedure handleIdentify(const command:ByteArray);

	procedure handleEMM(const command:ByteArray);
	
	function handleECM(const command:ByteArray):Byte;

	
public
	constructor new(config: TMemIniFile; transport: ConaxTransport; cardInfo: ConaxCardInfo; resetWatcher:IResetWatcher; gateway:Camd35Gateway); 
	procedure runCard();
end;	

implementation

	constructor ConaxCard.new(config: TMemIniFile; transport: ConaxTransport; cardInfo: ConaxCardInfo; resetWatcher:IResetWatcher; gateway:Camd35Gateway); 
	begin
		self.debug := config.readBool(CONFIG_SECTION_EMULATOR,CONFIG_DEBUG,false);
		self.debugReset := config.readBool(CONFIG_SECTION_EMULATOR,CONFIG_DEBUG_RESET,false);
		self.debugTrace := config.readBool(CONFIG_SECTION_EMULATOR,CONFIG_DEBUG_TRACE,false);
		self.debugCommandDump := config.readBool(CONFIG_SECTION_EMULATOR,CONFIG_DEBUG_COMMAND_DUMP,false);
		self.debugEcmDump := config.readBool(CONFIG_SECTION_EMULATOR,CONFIG_DEBUG_ECM_DUMP,false);
		self.debugEcmTiming := config.readBool(CONFIG_SECTION_EMULATOR,CONFIG_DEBUG_ECM_TIMING,false);
		self.debugEmmDump := config.readBool(CONFIG_SECTION_EMULATOR,CONFIG_DEBUG_EMM_DUMP,false);
		self.sendNoAccess := LowerCase(config.readString(CONFIG_SECTION_EMULATOR,CONFIG_NO_ACCESS_MODE,'error')) = 'error';
		self.acceptIdentify := config.readBool(CONFIG_SECTION_EMULATOR,CONFIG_ACCEPT_IDENTIFY,true);
		self.watch := TStopWatch.Create;
		self.transport := transport;
		self.cardInfo := cardInfo;
		self.resetWatcher := resetWatcher;
		self.gateway := gateway;
		
		emmCounter:=0;
		ecmCounter:=0;

		errorCode:=0;
		SetLength(lastControlWord,CW_SIZE);

		dissector := ConaxDissector.new();
		
		answerQueue := ByteFifo.new(255);

	end;
	procedure ConaxCard.reset();
	begin
		answerQueue.reset();
		if (debug and debugReset) then debugLn(self.className,'RESET!');
		sleep(50);
		transport.sendSynchronized(cardInfo.getAtr());
	end;
	
	procedure ConaxCard.runCard();
	var
		command:ByteArray;
	begin
		while true do begin

			if resetWatcher.isReset() then reset();
			
			command := transport.readPacket();

			if command <> nil then handleCommand(command);
			Sleep(5);
//			if KeyPressed then Halt(0);

		end;
		
	end;

	procedure ConaxCard.handleCommand(const command: ByteArray);
	var commandByte: Byte;	    
	    response:ByteArray;
	begin
		if (debug and debugTrace) then debugLn(self.className,'TRACE: handleCommand');
		SetLength(response,2);

		if (debug and debugCommandDump) then begin
			debugLn(self.className, 'Received:');
			printBuf(command);
		end;

		commandByte:=command[1];
		case commandByte of
			CC_GET_ANSWER: handleAnswer(command);			
			CC_CARD_READ_RECORD: handleReadRecord(command);			
			CC_CARD_READ_SERIAL: handleReadSerial(command);
			CC_CARD_IDENTIFY: handleIdentify(command);
			CC_EMM: handleEMM(command);
			CC_ECM: errorCode:=handleECM(command);

			else begin
				debugLn(self.className,'Unhandled Command:' +IntToStr(commandByte));				
			end;
		
		end;

		if answerQueue.available >0 then begin
			if (debug and debugCommandDump) then debugLn(self.className,'ACK ('+IntToStr(answerQueue.available)+' bytes available)');
			response[0] := CC_RESPONSE_ACK_DATA;
			response[1] := answerQueue.available;
			transport.send(response);
			errorCode:=0;
		end else begin
			if (debug and debugCommandDump) then debugLn(self.className,'ACK (no more data, errorCode:'+IntTostr(errorCode)+')');
			response[0] := CC_RESPONSE_ACK_EMPTY;
			response[1] := errorCode;
			transport.send(response);
			errorCode:=0;
		end;
	end;

	procedure ConaxCard.handleAnswer(const command:ByteArray);
	var
		packet:ByteArray;
		responseLength:Byte;
		response:ByteArray;
	begin
		if (debug and debugTrace) then debugLn(self.className,'TRACE: handleAnswer');

		packet:=dissector.getPacket(command);
		responseLength:=packet[0];
		if responseLength <=0 then begin
			debugLn(self.className,'Requested null answer.');
			Halt(0);
		end;
		if responseLength>answerQueue.available then begin
			debugLn(self.className,'Requested over bounds.');
			Halt(0);
		end;	
		
		SetLength(response,responseLength);
		answerQueue.read(response);

		if (debug and debugCommandDump) then begin 
			debugLn(self.className,'getAnswer reply Length '+IntTostr(responseLength));
			printBuf(response);
		end;    

		transport.send(response);
		
	end;

	procedure ConaxCard.handleReadRecord(const command:ByteArray);
	const
		NANO_INTERFACE_VERSION = $20;
		NANO_SYSTEM_ID = $28;
		NANO_LANGUAGE_ID = $2F;
		NANO_RESTRICTION_LEVEL = $30;
		NANO_SESSIONS = $23;
	var packet: ByteArray;
	    padPacket: ByteArray;
	    recordNum: Cardinal;
	    builder: ConaxBuilder;
	    response: ByteArray;
	begin
		if (debug and debugTrace) then debugLn(self.className,'TRACE: handleReadRecord');
		packet:= dissector.getPacket(command);
		if Length(packet) > 4 then begin
			debugLn(self.className,'readRecord param length wrong. Unknown format?');
			Exit;
		end;
		setLength(padPacket,4);
		Move(packet[0],padPacket[4-Length(packet)],Length(packet));
		Move(padPacket[0],recordNum,4);
		recordNum := BEtoN(recordNum);
		case recordNum of
			$100140: begin
				builder:=ConaxBuilder.new();
				builder.append(NANO_INTERFACE_VERSION,wrapByte(cardInfo.getInterfaceVersion(),1));
				builder.append(NANO_SYSTEM_ID,cardInfo.getSystemId());
				builder.append(NANO_LANGUAGE_ID,cardInfo.getLanguageId());
				builder.append(NANO_RESTRICTION_LEVEL,wrapByte(cardInfo.getRestrictionLevel(),1));
				builder.append(NANO_SESSIONS,wrapByte(cardInfo.getSessions(),1));
				response:=builder.getBuffer();
				builder.Free;

				answerQueue.write(response);
				
			end;

			$6C021001: begin
				debugLn(self.className,'Warning! Box is requesting Type B pairing. Box is LOCKED and cannot be used. Channels will NOT work.');
				Exit;
			end;
			else begin
				if (debug and debugCommandDump) then debugLn(self.className,'returning "Ok, but no data" response for record read. Id: '+IntToHex(recordNum,4));
			end;

		end;
		
	end;
	
	procedure ConaxCard.handleReadSerial(const command:ByteArray);
	const
		NANO_CARD_SERIAL = $74;
	var packet: ByteArray;
	    recordId: Word;
	    builder: ConaxBuilder;
	    response: ByteArray;
	begin
		if (debug and debugTrace) then debugLn(self.className,'TRACE: handleReadSerial');

		packet:=dissector.getPacket(command);
		if Length(packet) <> 2 then begin
			debugLn(self.className,'handleReadSerial received unknown parameter length. Exiting preemptively.');
			Halt(0);
		end;
		Move(packet[0],recordId,2);
		recordId := BEtoN(recordId);
		case recordId of
			$6600: begin
				builder:=ConaxBuilder.new();
				builder.append(NANO_CARD_SERIAL, cardInfo.getCardSerial());
				response:= builder.getBuffer();
				builder.Free;
				answerQueue.write(response);
			end;
			else begin				
				debugLn(self.className,'handleReadSerial received unknown parameter'+IntToHex(recordId,2)+'. Exiting preemptively.');
				Halt(0);
			end;
		end;
		
	end;

	procedure ConaxCard.handleEMM(const command:ByteArray);
	const
		NANO_EMM = $12;
	var
		emmNano: ByteArray;		
	begin

		if (debug and debugTrace) then debugLn(self.className,'TRACE: handleEMM');

		emmNano:=dissector.getNano(command,NANO_EMM,0);

		if (debug and debugEmmDump) then begin
			debugLn(self.className,'EMM dump:');
			printBuf(emmNano);
		end;

		gateway.doEMM(emmNano);
		
	end;
	
	function ConaxCard.handleECM(const command:ByteArray):Byte;
	const
		ECM_MIN_SIZE = 100; // TODO: what's a sensible minimum size for a conax ECM command?
		NANO_ECM = $14;
		NANO_ECM_CONTROL_WORD = $25;
		NANO_ECM_RESPONSE_STATE = $31;
		NANOPACKET_ECM_OK : array[0..1] of byte = ($40,00);
		NANOPACKET_ECM_NO_ACCESS : array[0..1] of byte = (0,0);
//		NANOPACKET_ECM_RESTRICTED : array[0..2] of byte = (2,0,9);
		ERROR_ECM_NO_ACCESS = $12;
	var
		ecmNano: ByteArray;
		ecm: ByteArray;
		controlWord :ByteArray = nil;
		builder: ConaxBuilder;
		response: ByteArray;
		cwPart : ByteArray;
	begin
		if (debug and debugTrace) then debugLn(self.className,'TRACE: handleECM');
		
		ecmNano:= dissector.getNano(command, NANO_ECM, 0);
		if ((ecmNano = nil) or ((ecmNano <> nil) and ((ecmNano[0] <> 0) or (Length(ecmNano) < ECM_MIN_SIZE)))) then begin
			debugLn(self.className,'ECM format unrecognized.. Dumping command:');
			printBuf(command);
			
			builder:= ConaxBuilder.new();
			builder.append(NANO_ECM_RESPONSE_STATE,readConst(NANOPACKET_ECM_NO_ACCESS));
			response:= builder.getBuffer();
			builder.Free;
			answerQueue.write(response);
			Result:=ERROR_ECM_NO_ACCESS;
			Exit;			
		end;

		if (debug) then debugLn(self.className,'ECM format recognized');

		SetLength(ecm,Length(ecmNano)-1);
		Move(ecmNano[1],ecm[0],Length(ecm));

		if (debug and debugEcmDump) then begin
			debugLn(self.className,'ECM dump:');
			printBuf(ecm);
		end;

		if byteArrayCompare(lastEcm,ecm) then begin		// some STBs request ECMs for all streams separately. some (most?) networks use the same ECMs for all streams
			if (debug) then debugLn(self.className,'[ConaxCard] Returning cached CW');
			SetLength(controlWord, CW_SIZE);
			Move(lastControlWord[0], controlWord[0], CW_SIZE);	// why bother the cardserver with it if we already know the CW?
		end else begin				
			if (debug) then debugLn(self.className,'[ConaxCard] Asking cardserver');
			if (debug and debugEcmTiming) then watch.reset;
			if (debug and debugEcmTiming) then watch.start;				
        		controlWord := gateway.processECM(ecm);			
			if (debug and debugEcmTiming) then begin
				watch.stop;
				debugLn(self.className,'ECM took '+inttostr(watch.elapsedmilliseconds));				
			end;
			if ((controlWord <> nil) and (Length(controlWord) = CW_SIZE)) then begin
				if Length(lastEcm) <> Length(ecm) then SetLength(lastEcm,Length(ecm));
				Move(ecm[0], lastEcm[0], Length(ecm));		// store the ecm for aformentioned purposes
	        		Move(controlWord[0], lastControlWord[0], CW_SIZE);   // store the ecm's controlword for aforementioned purposes
				if (debug) then debugLn(self.className,'[ConaxCard] CW cached');
			end else begin
				SetLength(lastEcm,0);
			end;
		end;

		if ((controlWord = nil) and (not sendNoAccess)) then begin 
			if (debug) then debugLn(self.className,'No Access! Adding null cw');
			SetLength(controlWord, CW_SIZE);	// make an empty control word to preempt sending no access error
		end;
				
		if ((controlWord <> nil) and (Length(controlWord) = CW_SIZE)) then begin
			if (debug) then begin 
				debugLn(self.className,'Sending received controlword:');
				printBuf(controlWord);
			end;

			if (debug and debugTrace) then debugLn(self.className,'Enter BuildECMResponse');	
			builder:= ConaxBuilder.new();
			SetLength(cwPart,$D);
			     
			cwPart[2] := 1;
			Move(controlWord[8],cwPart[5],8);
			builder.append(NANO_ECM_CONTROL_WORD,cwPart);

			cwPart[2] := 0;
			Move(controlWord[0],cwPart[5],8);
			builder.append(NANO_ECM_CONTROL_WORD,cwPart);

			builder.append(NANO_ECM_RESPONSE_STATE,readConst(NANOPACKET_ECM_OK));
			response:=builder.getBuffer();
			builder.Free;
			if (debug and debugEcmDump) then begin
				debugLn(self.className,'Adding ECM Response:');
				printBuf(response);
			end;

			answerQueue.write(response);	
			
			Result:=0;
			
		end else begin

			builder:= ConaxBuilder.new();
			builder.append(NANO_ECM_RESPONSE_STATE,readConst(NANOPACKET_ECM_NO_ACCESS));
			response:= builder.getBuffer();
			builder.Free;
			answerQueue.write(response);
			Result:=ERROR_ECM_NO_ACCESS;
			if (debug and debugEcmTiming) then begin
				 debugLn(self.className,'Sent NO ACCESS.. waited '+inttostr(watch.elapsedmilliseconds));			
			end;
		end;
		
	end;

	// Note: CAMID may not actually be a CAM ID as it seems to be the same across devices
	// It does have to be included in the response as it is sent in the request.
	procedure ConaxCard.handleIdentify(const command:ByteArray);
	const
		NANO_CAM_IDENTITY_RECORD = $11;
		NANO_CARD_IDENTITY_RECORD = $22;
		NANO_CAM_ID = $9;
		NANO_SERIAL = $23;
	var
		camIdNano: ByteArray;
		camId:ByteArray;
		tempSerial:ByteArray;
		paddedTempSerial:ByteArray;
		builder:ConaxBuilder;
		preResponse:ByteArray;
		response:ByteArray;
	begin	
		if (debug and debugTrace) then debugLn(self.className,'TRACE: handleIdentify');	

		if (not acceptIdentify) then exit;

		SetLength(paddedTempSerial,7);
		camIdNano:= dissector.getNano(command,NANO_CAM_IDENTITY_RECORD,0);
		if camIdNano <> nil then begin
			if (debug and debugTrace) then debugLn(self.className,'TRACE: CAMIDNANO ok.');
			if (camIdNano[8] = 9) and (camIdNano[9] = 4) then begin
				if (debug and debugTrace) then debugLn(self.className,'TRACE: CAMIDNANO format ok.');
				SetLength(camId,4);
				Move(camIdNano[10],camId[0],4);
				builder:=ConaxBuilder.new();
				builder.append(NANO_CAM_ID,camId);
				
				tempSerial:=cardInfo.getCardSerial();
				Move(tempSerial[0],paddedTempSerial[7-length(tempSerial)],length(tempSerial));
				builder.append(NANO_SERIAL,paddedTempSerial);
				
				byteArrayClear(paddedTempSerial);
				tempSerial:=cardInfo.getGroupSerial();
				Move(tempSerial[0],paddedTempSerial[7-length(tempSerial)],length(tempSerial));
				builder.append(NANO_SERIAL,paddedTempSerial);
				preResponse:=builder.getBuffer();
				builder.Free;
				SetLength(response,Length(preResponse)+2);
				response[0]:=NANO_CARD_IDENTITY_RECORD;
				response[1]:=Length(preResponse);
				Move(preResponse[0],response[2],Length(preResponse));

				answerQueue.write(response);

				if (debug) then begin 
					debugLn(self.className,'Processed an identify');
				end;
				
			end else begin
				if (debug) then debugLn(self.className, 'Identify request format is unknown. We probably wont get EMMs');
				exit;
			end;

		end;
	end;
end.