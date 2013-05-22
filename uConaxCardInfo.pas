unit uConaxCardInfo;

interface

uses uCommons,IniFiles;

type ConaxCardInfo = class
const
	CONFIG_SECTION_CARD = 'card';
	CONFIG_ATR = 'atr';
	CONFIG_CARD_SERIAL = 'cardSerial';
	CONFIG_GROUP_SERIAL = 'groupSerial';
	CONFIG_LANGUAGE_ID = 'languageId';
	CONFIG_SYSTEM_ID = 'systemId';
	CONFIG_INTERFACE_VERSION = 'interfaceVersion';
	CONFIG_RESTRICTION_LEVEL = 'restrictionLevel';
	CONFIG_CARD_SESSIONS = 'sessions';
	CONFIG_CARD_PIN = 'cardPin';
private
	atr: ByteArray;
	cardSerial: ByteArray;
	groupSerial: ByteArray;
	languageId: ByteArray;
	systemId: ByteArray;
	interfaceVersion:Byte;
	restrictionLevel:Byte;
	sessions:Byte;
	cardPin:String;
public
	constructor new(config: TMemIniFile);
	function getATR():ByteArray;
	function getCardSerial():ByteArray;
	function getGroupSerial():ByteArray;
	function getLanguageId():ByteArray;
	function getSystemId():ByteArray;
	function getSessions():Byte;
	function getRestrictionLevel():Byte;
	function getInterfaceVersion():Byte;
	function getCardPin():String;
end;


implementation

	constructor ConaxCardInfo.new(config: TMemIniFile);
	begin
		atr:= hexStringToByteArray(config.readString(CONFIG_SECTION_CARD,CONFIG_ATR,''));
		cardSerial:= hexStringToByteArray(config.readString(CONFIG_SECTION_CARD,CONFIG_CARD_SERIAL,''));
		groupSerial:= hexStringToByteArray(config.readString(CONFIG_SECTION_CARD,CONFIG_GROUP_SERIAL,''));
		languageId:= hexStringToByteArray(config.readString(CONFIG_SECTION_CARD,CONFIG_LANGUAGE_ID,''));
		systemId:= hexStringToByteArray(config.readString(CONFIG_SECTION_CARD,CONFIG_SYSTEM_ID,''));
		interfaceVersion:= config.readInteger(CONFIG_SECTION_CARD,CONFIG_INTERFACE_VERSION,$00);
		restrictionLevel:= config.readInteger(CONFIG_SECTION_CARD,CONFIG_RESTRICTION_LEVEL,8);
		sessions:= config.readInteger(CONFIG_SECTION_CARD,CONFIG_CARD_SESSIONS,1);
		cardPin:= config.readString(CONFIG_SECTION_CARD,CONFIG_CARD_PIN,'1234');
	end;
	
	function ConaxCardInfo.getATR():ByteArray;
	begin
		Result:=atr;
	end;

	function ConaxCardInfo.getCardSerial():ByteArray;
	begin
		Result:=cardSerial;
	end;
	
	function ConaxCardInfo.getGroupSerial():ByteArray;
	begin
		Result:=groupSerial;
	end;

	function ConaxCardInfo.getLanguageId():ByteArray;
	begin
		Result:=languageId;
	end;
	
	function ConaxCardInfo.getSystemId():ByteArray;
	begin
		Result:=systemId;
	end;

	function ConaxCardInfo.getSessions():Byte;
	begin
		Result:=sessions;
	end;

	function ConaxCardInfo.getRestrictionLevel():Byte;
	begin
		Result:=restrictionLevel;
	end;

	function ConaxCardInfo.getInterfaceVersion():Byte;
	begin
		Result:=interfaceVersion;
	end;
	function ConaxCardInfo.getCardPin():String;
	begin
		Result:=cardPin;
	end;
	

end.