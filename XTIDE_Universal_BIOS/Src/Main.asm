; File name		:	Main.asm
; Project name	:	XTIDE Universal BIOS
; Created date	:	28.7.2007
; Last update	:	1.7.2010
; Author		:	Tomi Tilli
; Description	:	Main file for BIOS. This is the only file that needs
;					to be compiled since other files are included to this
;					file (so no linker needed, Nasm does it all).
;
;					Tomi Tilli
;					aitotat@gmail.com

ORG 000h						; Code start offset 0000h

; Included .inc files
%include "emulate.inc"			; Must be included first!
%include "BiosData.inc"			; For BIOS Data area equates
%include "Interrupts.inc"		; For interrupt equates
%include "ATA_ID.inc"			; For ATA Drive Information structs
%include "IdeRegisters.inc"		; For ATA Registers, flags and commands
%include "Int13h.inc"			; Equates for INT 13h functions
%include "CustomDPT.inc"		; For Disk Parameter Table
%include "CompatibleDPT.inc"	; For standard Disk Parameter Tables
%include "RomVars.inc"			; For ROMVARS and IDEVARS structs
%include "RamVars.inc"			; For RAMVARS struct
%include "BootVars.inc"			; For BOOTVARS and BOOTNFO structs
%include "BootMenu.inc"			; For Boot Menu
%include "IDE_8bit.inc"			; For IDE 8-bit data port macros


; Section containing code
SECTION .text

; ROM variables (must start at offset 0)
CNT_ROM_BLOCKS		EQU		16	; 16 * 512B = 8kB BIOS
istruc ROMVARS
	at	ROMVARS.wRomSign,	dw	0AA55h			; PC ROM signature
	at	ROMVARS.bRomSize,	db	CNT_ROM_BLOCKS	; ROM size in 512B blocks
	at	ROMVARS.rgbJump, 	jmp	Initialize_FromMainBiosRomSearch
	at	ROMVARS.rgbDate,	db	"07/01/10"		; Build data (mm/dd/yy)
	at	ROMVARS.rgbSign,	db	"XTIDE110"		; Signature for flash program
	at	ROMVARS.szTitle
		db	"-=XTIDE Universal BIOS"
%ifdef USE_AT
		db	" (AT)=-",STOP
%elifdef USE_186
		db	" (XT+)=-",STOP
%else
		db	" (XT)=-",STOP
%endif
	at	ROMVARS.szVersion,	db	"v1.1.1 (07/01/10)",STOP

;---------------------------;
; AT Build default settings ;
;---------------------------;
%ifdef USE_AT
	at	ROMVARS.wFlags,			dw	FLG_ROMVARS_FULLMODE | FLG_ROMVARS_DRVXLAT | FLG_ROMVARS_DRVNFO | FLG_ROMVARS_MAXSIZE
	at	ROMVARS.bIdeCnt,		db	3						; Number of supported controllers
	at	ROMVARS.bBootDrv,		db	80h						; Boot Menu default drive
	at	ROMVARS.bBootMnuH,		db	20						; Boot Menu maximum height
	at	ROMVARS.bBootDelay,		db	30						; Boot Menu selection delay (secs)
	at	ROMVARS.bBootLdrType,	db	BOOTLOADER_TYPE_MENU	; Boot loader type
	at	ROMVARS.bMinFddCnt, 	db	0						; Do not force minimum number of floppy drives
	at	ROMVARS.bStealSize,		db	1						; Steal 1kB from base memory

	at	ROMVARS.ideVars0+IDEVARS.wPort,			dw	1F0h			; Controller Command Block base port
	at	ROMVARS.ideVars0+IDEVARS.wPortCtrl,		dw	3F0h			; Controller Control Block base port
	at	ROMVARS.ideVars0+IDEVARS.bBusType,		db	BUS_TYPE_16		; Bus type
	at	ROMVARS.ideVars0+IDEVARS.bIRQ,			db	14				; IRQ
	at	ROMVARS.ideVars0+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars0+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	FLG_DRVPARAMS_BLOCKMODE

	at	ROMVARS.ideVars1+IDEVARS.wPort,			dw	170h			; Controller Command Block base port
	at	ROMVARS.ideVars1+IDEVARS.wPortCtrl,		dw	370h			; Controller Control Block base port
	at	ROMVARS.ideVars1+IDEVARS.bBusType,		db	BUS_TYPE_16		; Bus type
	at	ROMVARS.ideVars1+IDEVARS.bIRQ,			db	15				; IRQ
	at	ROMVARS.ideVars1+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars1+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	FLG_DRVPARAMS_BLOCKMODE

	at	ROMVARS.ideVars2+IDEVARS.wPort,			dw	300h			; Controller Command Block base port
	at	ROMVARS.ideVars2+IDEVARS.wPortCtrl,		dw	308h			; Controller Control Block base port
	at	ROMVARS.ideVars2+IDEVARS.bBusType,		db	BUS_TYPE_8_DUAL	; Bus type
	at	ROMVARS.ideVars2+IDEVARS.bIRQ,			db	0				; IRQ
	at	ROMVARS.ideVars2+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars2+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	FLG_DRVPARAMS_BLOCKMODE
%else
;-----------------------------------;
; XT and XT+ Build default settings ;
;-----------------------------------;
	at	ROMVARS.wFlags,			dw	FLG_ROMVARS_LATE | FLG_ROMVARS_DRVXLAT | FLG_ROMVARS_ROMBOOT | FLG_ROMVARS_DRVNFO | FLG_ROMVARS_MAXSIZE
	at	ROMVARS.bIdeCnt,		db	1						; Number of supported controllers
	at	ROMVARS.bBootDrv,		db	80h						; Boot Menu default drive
	at	ROMVARS.bBootMnuH,		db	20						; Boot Menu maximum height
	at	ROMVARS.bBootDelay,		db	30						; Boot Menu selection delay (secs)
	at	ROMVARS.bBootLdrType,	db	BOOTLOADER_TYPE_MENU	; Boot loader type
	at	ROMVARS.bMinFddCnt, 	db	1						; Assume at least 1 floppy drive present if autodetect fails
	at	ROMVARS.bStealSize,		db	1						; Steal 1kB from base memory in full mode

	at	ROMVARS.ideVars0+IDEVARS.wPort,			dw	300h			; Controller Command Block base port
	at	ROMVARS.ideVars0+IDEVARS.wPortCtrl,		dw	308h			; Controller Control Block base port
	at	ROMVARS.ideVars0+IDEVARS.bBusType,		db	BUS_TYPE_8_DUAL	; Bus type
	at	ROMVARS.ideVars0+IDEVARS.bIRQ,			db	0				; IRQ
	at	ROMVARS.ideVars0+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars0+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	FLG_DRVPARAMS_BLOCKMODE
%endif
iend


; Include .asm files (static data and libraries)
%include "Strings.asm"			; For BIOS message strings
%include "math.asm"				; For Math library
%include "string.asm"			; For String library
%include "print.asm"			; For Print library
%include "keys.asm"				; For keyboard library (required by menu library)
%include "menu.asm"				; For menu library
%include "PrintString.asm"		; Customized printing for this BIOS
%include "SoftDelay.asm"		; For software delay loops

; Include .asm files (Initialization and drive detection)
%include "Initialize.asm"		; For BIOS initialization
%include "RamVars.asm"			; For RAMVARS initialization and access
%include "CreateDPT.asm"		; For creating DPTs
%include "FindDPT.asm"			; For finding DPTs
%include "AccessDPT.asm"		; For accessing DPTs
%include "CompatibleDPT.asm"	; For creating compatible DPTs
%include "BootInfo.asm"			; For creating BOOTNFO structs
%include "AtaID.asm"			; For ATA Identify Device information
%include "DetectDrives.asm"		; For detecting IDE drives
%include "DetectPrint.asm"		; For printing drive detection strings

; Include .asm files (boot menu)
%include "BootVars.asm"			; For accessing BOOTVARS struct
%include "BootMenu.asm"			; For Boot Menu operations
%include "BootMenuEvent.asm"	; For menu library event handling
%include "FloppyDrive.asm"		; Floppy Drive related functions
%include "BootMenuPrint.asm"	; For printing Boot Menu strings
%include "BootMenuPrintCfg.asm"	; For printing hard disk configuration

; Include .asm files (general drive accessing)
%include "DriveXlate.asm"		; For swapping drive numbers
%include "HAddress.asm"			; For sector address translations
%include "HCapacity.asm"		; For calculating drive capacity
%include "HError.asm"			; For error checking
%include "HPIO.asm"				; For PIO transfers
%include "HIRQ.asm"				; For IRQ handling
%include "HStatus.asm"			; For reading hard disk status
%include "HDrvSel.asm"			; For selecting drive to access
%include "HCommand.asm"			; For outputting command and parameters

; Include .asm files (Interrupt handlers)
%include "Int13h.asm"			; For Int 13h, Disk functions
%include "Int18h.asm"			; For Int 18h, ROM Boot and Boot error
%include "Int19h.asm"			; For Int 19h, Boot Loader
%include "Int19hMenu.asm"		; For Int 19h, Boot Loader for Boot Menu
%include "BootPrint.asm"		; For printing boot information

; Include .asm files (Hard Disk BIOS functions)
%include "AH0h_HReset.asm"		; Required by Int13h_Jump.asm
%include "AH1h_HStatus.asm"		; Required by Int13h_Jump.asm
%include "AH2h_HRead.asm"		; Required by Int13h_Jump.asm
%include "AH3h_HWrite.asm"		; Required by Int13h_Jump.asm
%include "AH4h_HVerify.asm"		; Required by Int13h_Jump.asm
%include "AH5h_HFormat.asm"		; Required by Int13h_Jump.asm
%include "AH8h_HParams.asm"		; Required by Int13h_Jump.asm
%include "AH9h_HInit.asm"		; Required by Int13h_Jump.asm
%include "AHCh_HSeek.asm"		; Required by Int13h_Jump.asm
%include "AHDh_HReset.asm"		; Required by Int13h_Jump.asm
%include "AH10h_HReady.asm"		; Required by Int13h_Jump.asm
%include "AH11h_HRecal.asm"		; Required by Int13h_Jump.asm
%include "AH14h_HDiag.asm"		; Required by Int13h_Jump.asm
%include "AH15h_HSize.asm"		; Required by Int13h_Jump.asm
%include "AH23h_HFeatures.asm"	; Required by Int13h_Jump.asm
%include "AH24h_HSetBlocks.asm"	; Required by Int13h_Jump.asm
%include "AH25h_HDrvID.asm"		; Required by Int13h_Jump.asm



; Fill with zeroes until size is what we want
times (CNT_ROM_BLOCKS*512)-($-$$) db 0
