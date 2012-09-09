; Project name	:	XTIDE Univeral BIOS Configurator v2
; Description	:	Program start and exit.

;
; XTIDE Universal BIOS and Associated Tools 
; Copyright (C) 2009-2010 by Tomi Tilli, 2011-2012 by XTIDE Universal BIOS Team.
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
; 
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.		
; Visit http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
;		

; Include .inc files
		
%define INCLUDE_MENU_DIALOGS
%define INCLUDE_SERIAL_LIBRARY
		
%include "AssemblyLibrary.inc"	; Assembly Library. Must be included first!
%include "Romvars.inc"			; XTIDE Universal BIOS variables

%include "Version.inc"
%include "MenuCfg.inc"
%include "MenuStructs.inc"
%include "Variables.inc"


; Section containing code
SECTION .text


; Program first instruction.
ORG	100h						; Code starts at offset 100h (DOS .COM)
Start:
	jmp		Main_Start

; Include library sources
%include "AssemblyLibrary.asm"

; Include sources for this program
%include "BiosFile.asm"
%include "Buffers.asm"
%include "Dialogs.asm"
%include "EEPROM.asm"
%include "Flash.asm"
%include "MenuEvents.asm"
%include "Menuitem.asm"
%include "MenuitemPrint.asm"
%include "Menupage.asm"
%include "Strings.asm"

%include "BootMenuSettingsMenu.asm"
%include "ConfigurationMenu.asm"
%include "FlashMenu.asm"
%include "IdeControllerMenu.asm"
%include "MainMenu.asm"
%include "MasterSlaveMenu.asm"



;--------------------------------------------------------------------
; Program start
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Main_Start:
	mov		ax, SCREEN_BACKGROUND_CHARACTER_AND_ATTRIBUTE
	call	InitializeScreenWithBackgroudCharAndAttrInAX

	call	Main_InitializeCfgVars
	call	MenuEvents_DisplayMenu
	mov		ax, DOS_BACKGROUND_CHARACTER_AND_ATTRIBUTE
	call	InitializeScreenWithBackgroudCharAndAttrInAX

	; Exit to DOS
	mov 	ax, 4C00h			; Exit to DOS
	int 	21h


;--------------------------------------------------------------------
; InitializeScreenWithBackgroudCharAndAttrInAX
;	Parameters:
;		AL:		Background character
;		AH:		Background attribute
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
InitializeScreenWithBackgroudCharAndAttrInAX:
	xchg	dx, ax
	CALL_DISPLAY_LIBRARY InitializeDisplayContext	; Reset cursor etc
	xchg	ax, dx
	CALL_DISPLAY_LIBRARY ClearScreenWithCharInALandAttrInAH
	ret


;--------------------------------------------------------------------
; Main_InitializeCfgVars
;	Parameters:
;		DS:		Segment to CFGVARS
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Main_InitializeCfgVars:
	push	es

	call	Buffers_Clear
	call	EEPROM_FindXtideUniversalBiosROMtoESDI
	jnc		SHORT .InitializationCompleted
	mov		[CFGVARS.wEepromSegment], es
.InitializationCompleted:
	pop		es
	ret


; Section containing initialized data
SECTION .data

ALIGN WORD_ALIGN
g_cfgVars:
istruc CFGVARS
	at	CFGVARS.pMenupage,			dw	g_MenupageForMainMenu
	at	CFGVARS.wFlags,				dw	DEFAULT_CFGVARS_FLAGS
	at	CFGVARS.wEepromSegment,		dw	0
	at	CFGVARS.bEepromType,		db	DEFAULT_EEPROM_TYPE
	at	CFGVARS.bEepromPage,		db	DEFAULT_PAGE_SIZE
	at	CFGVARS.bSdpCommand,		db	DEFAULT_SDP_COMMAND
iend


; Section containing uninitialized data
SECTION .bss
