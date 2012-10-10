; Project name	:	XTIDE Universal BIOS
; Description	:	Sets IDE Device specific parameters to DPT.

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

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; IdeDPT_Finalize
;	Parameters:
;		DS:DI:	Ptr to Disk Parameter Table
;		ES:SI:	Ptr to 512-byte ATA information read from the drive
;		CS:BP:	Ptr to IDEVARS for the controller
;	Returns:
;		CF:		Clear, IDE interface only supports hard disks
;	Corrupts registers:
;		AX, BX, CX, DX
;--------------------------------------------------------------------
IdeDPT_Finalize:

%ifdef MODULE_FEATURE_SETS
;--------------------------------------------------------------------
; .DetectPowerManagementSupport
;	Parameters:
;		DS:DI:	Ptr to Disk Parameter Table
;		ES:SI:	Ptr to 512-byte ATA information read from the drive
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
.DetectPowerManagementSupport:
	test	BYTE [es:si+ATA6.wSetSup82], A6_wSetSup82_POWERMAN
	jz		SHORT .NoPowerManagementSupport
	or		BYTE [di+DPT.bFlagsHigh], FLGH_DPT_POWER_MANAGEMENT_SUPPORTED
.NoPowerManagementSupport:
%endif ; MODULE_FEATURE_SETS


;--------------------------------------------------------------------
; .StoreDeviceType
;	Parameters:
;		DS:DI:	Ptr to Disk Parameter Table
;		CS:BP:	Ptr to IDEVARS for the controller
;	Returns:
;		Nothing
;	Corrupts registers:
;		AL
;--------------------------------------------------------------------
.StoreDeviceType:
	call	IdeDPT_StoreDeviceTypeToDPTinDSDIfromIdevarsInCSBP


;--------------------------------------------------------------------
; .StoreBlockMode
;	Parameters:
;		DS:DI:	Ptr to Disk Parameter Table
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
.StoreBlockMode:
	mov		BYTE [di+DPT_ATA.bBlockSize], 1


%ifdef MODULE_ADVANCED_ATA
;--------------------------------------------------------------------
; .StorePioModeAndTimings
;	Parameters:
;		DS:DI:	Ptr to Disk Parameter Table
;		ES:SI:	Ptr to 512-byte ATA information read from the drive
;		CS:BP:	Ptr to IDEVARS for the controller
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX
;--------------------------------------------------------------------
.StorePioMode:
	call	AtaID_GetMaxPioModeToAXandMinCycleTimeToCX
	mov		[di+DPT_ADVANCED_ATA.wMinPioCycleTime], cx
	mov		[di+DPT_ADVANCED_ATA.bPioMode], al
	or		[di+DPT.bFlagsHigh], ah


;--------------------------------------------------------------------
; .DetectAdvancedIdeController
;	Parameters:
;		DS:DI:	Ptr to Disk Parameter Table
;		ES:SI:	Ptr to 512-byte ATA information read from the drive
;		CS:BP:	Ptr to IDEVARS for the controller
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX
;--------------------------------------------------------------------
.DetectAdvancedIdeController:
	mov		bx, [di+DPT.wBasePort]
	call	AdvAtaInit_DetectControllerForIdeBaseInBX
	mov		[di+DPT_ADVANCED_ATA.wControllerID], ax	; Store zero if none detected
	mov		[di+DPT_ADVANCED_ATA.wControllerBasePort], dx
	jnc		SHORT .NoAdvancedControllerDetected

	; Use highest common PIO mode from controller and drive.
	; Many VLB controllers support PIO modes up to 2.
	call	AdvAtaInit_GetControllerMaxPioModeToAL
	jnc		SHORT .ChangeTo32bitDevice
	and		BYTE [di+DPT.bFlagsHigh], ~FLGH_DPT_IORDY	; No IORDY supported if need to limit
	MIN_U	[di+DPT_ADVANCED_ATA.bPioMode], al

	; We have detected 32-bit controller so change Device Type since
	; it might have been set to 16-bit on IDEVARS
.ChangeTo32bitDevice:
	mov		BYTE [di+DPT_ATA.bDevice], DEVICE_32BIT_ATA
.NoAdvancedControllerDetected:
%endif	; MODULE_ADVANCED_ATA


; End DPT
	clc
	ret


;--------------------------------------------------------------------
; IdeDPT_StoreDeviceTypeToDPTinDSDIfromIdevarsInCSBP
;	Parameters:
;		DS:DI:	Ptr to Disk Parameter Table
;		CS:BP:	Ptr to IDEVARS for the controller
;	Returns:
;		Nothing
;	Corrupts registers:
;		AL
;--------------------------------------------------------------------
IdeDPT_StoreDeviceTypeToDPTinDSDIfromIdevarsInCSBP:
	mov		al, [cs:bp+IDEVARS.bDevice]
	mov		[di+DPT_ATA.bDevice], al
	ret
