program nonaxe;

uses 	uCommons, 
	uConaxTransport, 
	uConaxCardInfo, 
	uConaxCard, 
	uCamd35Gateway, 
	uResetWatcher,
	{$IFDEF LINUX}
		uGpioResetWatcher,
        {$ENDIF}
	uFlowControlResetWatcher,
	IniFiles;

const
	CONFIG_SECTION_RESET = 'reset';
	CONFIG_RESET_TYPE = 'type';
var
	resetType: String;
	config: TMemIniFile;
	gateway: Camd35Gateway;
	resetWatcher: IResetWatcher;
	cardInfo: ConaxCardInfo;
	transport: ConaxTransport;
	card: ConaxCard;

begin

writeln('  ____   ____   ____ _____  ___  ___ ____ ');
writeln(' /    \ /  _ \ /    \\__  \ \  \/  // __ \'); 
writeln('|   |  (  <_> )   |  \/ __ \_>    <\  ___/'); 
writeln('|___|  /\____/|___|  (____  /__/\_ \\___  >');
writeln('    \/            \/     \/      \/    \/');

writeln('Native Conax Emulator');

config := TMemIniFile.Create('nonaxe.ini');

resetType:= config.readString(CONFIG_SECTION_RESET,CONFIG_RESET_TYPE,'flowcontrol');

transport:= ConaxTransport.new(config);
cardInfo:= ConaxCardInfo.new(config);
gateway:= Camd35Gateway.new(config);
{$IFDEF LINUX}
if resetType = 'gpio' then resetWatcher:= GpioResetWatcher.new(config);
{$ENDIF}
if resetType = 'flowcontrol' then resetWatcher:= FlowControlResetWatcher.new(config,transport.getHandle);
// insert more reset modules here

if (nil = resetWatcher) then begin
	writeln('No reset watcher defined');
	Halt(0);
end;

card:= ConaxCard.new(config,transport,cardInfo,resetWatcher,gateway);

card.runCard();

end.

