; Project name	:	BIOS Drive Information Tool
; Description	:	Reads and prints information from ATA ID.

;
; XTIDE Universal BIOS and Associated Tools
; Copyright (C) 2009-2010 by Tomi Tilli, 2011-2013 by XTIDE Universal BIOS Team.
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
; AtaInfo_DisplayAtaInformationForDriveDL
;	Parameters:
;		DL:		Drive Number
;	Returns:
;		Nothing
;	Corrupts registers:
;		All, except CX and DX
;--------------------------------------------------------------------
AtaInfo_DisplayAtaInformationForDriveDL:
	push	cx
	push	dx

	; Read ATA Information from the drive
	call	Bios_ReadAtaInfoFromDriveDLtoBX	; Unaltered ATA information
	call	Print_ErrorMessageFromAHifError	; AH=25h is not available on many BIOSes
	jc		SHORT .SkipAtaInfoSinceError

	; Print Drive Name
	call	Print_NameFromAtaInfoInBX

	; Print Drive P-CHS parameters
	call	DisplayPCHSusingAtaInfoFromDSBX	; Unaltered

	; Fix and display values (ATA Info will stay fixed)
	xor		ah, ah							; Successfully read ATA ID
	push	ds
	pop		es
	mov		si, bx
	call	AtaID_FixIllegalValuesFromESSI	; Modify ATA information if necessary
	mov		si, g_szWillBeModified
	call	Print_NullTerminatedStringFromSI
	call	DisplayPCHSusingAtaInfoFromDSBX	; Display fixed values

	; Print Drive CHS sector count
	test	WORD [bx+ATA1.wFields], A1_wFields_54to58
	jz		SHORT .SkipChsSectors
	call	DisplayPCHSsectorCountUsingAtaInfoFromDXBX
.SkipChsSectors:

	; Print Drive LBA28 sector count
	test	WORD [bx+ATA1.wCaps], A1_wCaps_LBA
	jz		SHORT .SkipLBA28
	call	DisplayLBA28sectorCountUsingAtaInfoFromDSBX
.SkipLBA28:

	; Print Drive LBA48 sector count
	test	WORD [bx+ATA6.wSetSup83], A6_wSetSup83_LBA48
	jz		SHORT .SkipLBA48
	call	DisplayLBA48sectorCountUsingAtaInfoFromDSBX
.SkipLBA48:

	; Print block mode information
	call	DisplayBlockModeInformationUsingAtaInfoFromDSBX

	; Print PIO mode information
	call	DisplayPioModeInformationUsingAtaInfoFromDSBX

	; Print L-CHS generated by XTIDE Universal BIOS
	call	DisplayXUBcompatibilityInfoUsingAtaInfoFromDSBX

.SkipAtaInfoSinceError:
	pop		dx
	pop		cx
	ret


;--------------------------------------------------------------------
; DisplayPCHSusingAtaInfoFromDSBX
;	Parameters:
;		BX:		Offset to ATA Information
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, BP, SI, DI
;--------------------------------------------------------------------
DisplayPCHSusingAtaInfoFromDSBX:
	mov		si, bx			; DS == ES
	call	AtaGeometry_GetPCHStoAXBLBHfromAtaInfoInESSI
	xchg	cx, ax
	eMOVZX	dx, bl
	eMOVZX	ax, bh
	call	Print_CHSfromCXDXAX
	mov		bx, si			; Restore BX
	ret


;--------------------------------------------------------------------
; DisplayPCHSsectorCountUsingAtaInfoFromDXBX
;	Parameters:
;		BX:		Offset to ATA Information
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX, BP, SI, DI
;--------------------------------------------------------------------
DisplayPCHSsectorCountUsingAtaInfoFromDXBX:
	mov		si, g_szChsSectors
	call	Print_NullTerminatedStringFromSI

	mov		si, bx
	mov		ax, [si+ATA1.dwCurSCnt]
	mov		dx, [si+ATA1.dwCurSCnt+2]
	xor		bx, bx
	call	Print_TotalSectorsFromBXDXAX
	mov		bx, si			; Restore BX
	ret


;--------------------------------------------------------------------
; DisplayLBA28sectorCountUsingAtaInfoFromDSBX
;	Parameters:
;		BX:		Offset to ATA Information
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX, BP, SI, DI
;--------------------------------------------------------------------
DisplayLBA28sectorCountUsingAtaInfoFromDSBX:
	mov		si, g_szLBA28
	call	Print_NullTerminatedStringFromSI

	mov		si, bx
	mov		ax, [si+ATA1.dwLBACnt]
	mov		dx, [si+ATA1.dwLBACnt+2]
	xor		bx, bx
	call	Print_TotalSectorsFromBXDXAX
	mov		bx, si			; Restore BX
	ret


;--------------------------------------------------------------------
; DisplayLBA48sectorCountUsingAtaInfoFromDSBX
;	Parameters:
;		BX:		Offset to ATA Information
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX, BP, SI, DI
;--------------------------------------------------------------------
DisplayLBA48sectorCountUsingAtaInfoFromDSBX:
	mov		si, g_szLBA48
	call	Print_NullTerminatedStringFromSI

	mov		si, bx
	mov		ax, [si+ATA6.qwLBACnt]
	mov		dx, [si+ATA6.qwLBACnt+2]
	mov		bx, [si+ATA6.qwLBACnt+4]
	call	Print_TotalSectorsFromBXDXAX
	mov		bx, si			; Restore BX
	ret


;--------------------------------------------------------------------
; DisplayBlockModeInformationUsingAtaInfoFromDSBX
;	Parameters:
;		BX:		Offset to ATA Information
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX, BP, SI, DI
;--------------------------------------------------------------------
DisplayBlockModeInformationUsingAtaInfoFromDSBX:
	eMOVZX	ax, [bx+ATA1.bBlockSel]	; ATA2+ has flag on high word
	cwd
	mov		dl, [bx+ATA1.bBlckSize]
	mov		si, g_szBlockMode
	jmp		Print_FormatStringFromSIwithParametersInAXDX


;--------------------------------------------------------------------
; DisplayPioModeInformationUsingAtaInfoFromDSBX
;	Parameters:
;		BX:		Offset to ATA Information
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, BP, SI, DI
;--------------------------------------------------------------------
DisplayPioModeInformationUsingAtaInfoFromDSBX:
	; Load standard timings (up to PIO-2)
	mov		al, [bx+ATA1.bPioMode]
	cbw
	mov		si, ax
	eSHL_IM	si, 1		; Shift for WORD lookup
	mov		dx, [si+.rgwStandardPioTimings]	; Load min cycle time
	mov		cx, -1		; IORDY not supported

	; Replace with advanced mode timings (PIO-3 and up)
	test	BYTE [bx+ATA2.wFields], A2_wFields_64to70
	jz		SHORT .NoAdvancedPioModesSupported

	mov		si, 0FFh
	and		si, [bx+ATA2.bPIOSupp]	; Advanced mode flags
	jz		SHORT .NoAdvancedPioModesSupported
.IncrementPioMode:
	inc		ax
	shr		si, 1
	jnz		SHORT .IncrementPioMode
	mov		dx, [bx+ATA2.wPIOMinCy]
	mov		cx, [bx+ATA2.wPIOMinCyF]

.NoAdvancedPioModesSupported:
	mov		si, g_szPIO
	jmp		Print_FormatStringFromSIwithParametersInAXDXCX

.rgwStandardPioTimings:
	dw		PIO_0_MIN_CYCLE_TIME_NS
	dw		PIO_1_MIN_CYCLE_TIME_NS
	dw		PIO_2_MIN_CYCLE_TIME_NS


;--------------------------------------------------------------------
; DisplayXUBcompatibilityInfoUsingAtaInfoFromDSBX
;	Parameters:
;		BX:		Offset to ATA Information
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX, BP, SI, DI
;--------------------------------------------------------------------
DisplayXUBcompatibilityInfoUsingAtaInfoFromDSBX:
	; Display header
	mov		ax, g_szXUBversion
	mov		si, g_szXUB
	call	Print_FormatStringFromSIwithParameterInAX

	; Display translation mode and L-CHS
	mov		si, bx				; DS == ES
	mov		dx, TRANSLATEMODE_AUTO
	call	AtaGeometry_GetLCHStoAXBLBHfromAtaInfoInESSIwithTranslateModeInDX
	MIN_U	ax, MAX_LCHS_CYLINDERS
	jmp		Print_ModeFromDLandCHSfromAXLBH
