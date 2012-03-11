; Project name	:	BIOS Drive Information Tool
; Description	:	Functions to print information read from BIOS.


; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Use DOS standard output so strings can be redirected to a file.
;
; Print_DosCharOut
;	Parameters:
;		AL:		Character to output
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to video memory where to output
;	Returns:
;		DI:		Incremented for next character
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Print_DosCharOut:
	xchg	dx, ax
	mov		ah, 02h		; DOS 1+ - WRITE CHARACTER TO STANDARD OUTPUT
	int		21h			; Call DOS
	ret


;---------------------------------------------------------------------
; Print_ErrorMessageFromAHifError
;	Parameters:
;		AH:		BIOS error code
;		CF:		Set if error, cleared otherwise
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BP, SI, DI (CF remains unchanged)
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Print_ErrorMessageFromAHifError:
	jnc		SHORT .NoErrors
	eMOVZX	ax, ah
	mov		si, g_szBiosError
	call	Print_BiosFunctionNumberFromAXusingFormatStringInSI
	stc		; Keep the CF set
ALIGN JUMP_ALIGN
.NoErrors:
	ret


;---------------------------------------------------------------------
; Print_DriveNumberFromDLusingFormatStringInSI
; Print_BiosFunctionNumberFromAXusingFormatStringInSI
; Print_SectorSizeFromAXusingFormatStringInSI
;	Parameters:
;		DL:		Drive Number
;		AX:		Function number
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BP, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Print_DriveNumberFromDLusingFormatStringInSI:
	eMOVZX	ax, dl
Print_BiosFunctionNumberFromAXusingFormatStringInSI:
Print_SectorSizeFromAXusingFormatStringInSI:
	mov		bp, sp
	push	ax
	jmp		SHORT JumpToFormatNullTerminatedStringFromSI


;---------------------------------------------------------------------
; Print_CHSfromCXDXAX
;	Parameters:
;		CX:		Number of cylinders (1...16383)
;		DX:		Number of heads (1...255)
;		AX:		Sectors per track (1...63)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BP, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Print_CHSfromCXDXAX:
	push	si

	mov		bp, sp
	push	cx
	push	dx
	push	ax
	mov		si, g_szFormatCHS
	CALL_DISPLAY_LIBRARY	FormatNullTerminatedStringFromCSSI

	pop		si
	ret


;---------------------------------------------------------------------
; Print_NameFromAtaInfoInBX
;	Parameters:
;		DS:BX:	Ptr to ATA information
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, BP, SI, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Print_NameFromAtaInfoInBX:
	cld
	lea		si, [bx+ATA1.strModel]
	mov		di, si
	mov		cx, A1_MODEL_NUMBER_LENGTH/2
ALIGN JUMP_ALIGN
.ReverseNextWord:
	lodsw
	xchg	al, ah
	stosw
	loop	.ReverseNextWord
	dec		di
	xor		ax, ax
	stosb				; Terminate with NULL

	mov		bp, sp
	lea		si, [bx+ATA1.strModel]
	push	si
	mov		si, g_szFormatDrvName
	jmp		SHORT JumpToFormatNullTerminatedStringFromSI


;---------------------------------------------------------------------
; Print_TotalSectorsFromBXDXAX
;	Parameters:
;		BX:DX:AX:	Total number of sectors
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, BP, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Print_TotalSectorsFromBXDXAX:
	ePUSH_T	di, 0
	push	bx
	push	dx
	push	ax
	mov		bp, sp
	mov		bx, 10
	CALL_DISPLAY_LIBRARY	PrintQWordFromSSBPwithBaseInBX
	add		sp, BYTE 8

	CALL_DISPLAY_LIBRARY	PrintNewlineCharacters
	ret


;---------------------------------------------------------------------
; Print_EbiosVersionFromBXandExtensionsFromCX
;	Parameters:
;       BX:		Version of extensions
;		CX:		Interface support bit map
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BP, SI, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Print_EbiosVersionFromBXandExtensionsFromCX:
	mov		bp, sp
	push	bx
	push	cx
	mov		si, g_szNewExtensions
	jmp		SHORT JumpToFormatNullTerminatedStringFromSI


;---------------------------------------------------------------------
; JumpToFormatNullTerminatedStringFromSI
;	Parameters:
;		BP:		SP before pushing parameters
;		CS:SI:	Ptr to format string
;	Returns:
;		Pushed parameters are cleaned from stack
;	Corrupts registers:
;		AX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
JumpToFormatNullTerminatedStringFromSI:	
	CALL_DISPLAY_LIBRARY 	FormatNullTerminatedStringFromCSSI
	ret


;---------------------------------------------------------------------
; Print_NullTerminatedStringFromSI
;	Parameters:
;		CS:SI:	Ptr to string to display
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Print_NullTerminatedStringFromSI:
	CALL_DISPLAY_LIBRARY	PrintNullTerminatedStringFromCSSI
	ret
