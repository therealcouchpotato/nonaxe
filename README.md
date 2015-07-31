nonaxe
======

Season Interface card emulator

Disclaimer and notes:

	* Emulator is for educational purposes only
		Make sure you don't violate local laws or your service contract. 
		I take no responsibility for anything resulting	from the use of this source code.
	* Emulator does not support pairing
		Implementing TypeA pairing should be possible at least but I'm not going to do it.
		TypeB pairing on the other hand has never been reverse engineered
	* Emulator is released under the GPLv3 license
		Feel free to modify but make sure you share.
		http://www.gnu.org/licenses/gpl-3.0.html
	* Emulator is unsupported
		I've only tested it on linux using the gpio reset watcher on an embedded system.
		Any deviation from my test setup and you can run into bugs that you'll need to fix.
		Good luck!
	* Timings are evil (sometimes)
		CAS7 cards take their time processing ECMs (probably a deliberate delay)
		When two clients are watching different channels and the ecm timing of those drift
		and converge then one of those ECMs can take average response time * 2 to process.
		You don't have very long to respond to an ECM command. Around 1 second is it.
		If your card processes a request in 500ms+ then it's obvious that one of your clients 
		will be over limit and skip and that's with only 2 clients.
		This is probably provider and technology (DVB-S/T/C) dependent but keep it in mind.
	* Fine tune OSCAM for best results
		When AU is enabled, the first ECM request gets discarded as OSCAM sends two 
		EMM_REQUESTs to the new AU-enabled client connection before processing ECMs.
		This can lead to the first channel open after power-on taking 30+ seconds.
			Solution: Set the AU user account's session timeout to a large number.
		EMMs take longer to process than ECMs, hogging precious card time.
			Solution: Enable EMM caching with a low rewrite count.
		Etc..
			Experiment!		
		
Requirements:

	* Access to an OSCAM or other card server instance that supports the camd35 UDP protocol
	* Some type of Season interface connected to something you want to run the emu on
	* _UNPAIRED_ target device (CAM or Set-top-box)

To use:

	0. Compile the emu
	1. Fill in your card info (ATR, IDs, serials) below
		Hint: OSCAM can show you most of them, STB info menus may show you the rest.
		Don't change the length of IDs and serials in the example config. 
		Prepend with 00s instead if shorter
		ATR length is arbitrary
	2. Configure the reset according to your interface
	3. Configure the port and speed (note that unstandard bauds are not handled. 
	   if you need them buy a CP2102 based interface and use the manufacturer tool to 
	   modify the baud rate table, it works great, no headaches. 
	   ... or implement the functionality in the serial classes yourself.)
	4. Fill in your card server access details (emu has been tested with OSCAM only)
	5. Rename this file to nonaxe.ini 
		You may remove this large readme section if you wish
	6. Deploy and run
