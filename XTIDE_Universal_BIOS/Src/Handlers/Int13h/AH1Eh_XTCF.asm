; Project name	:	XTIDE Universal BIOS
; Description	:	Int 13h function AH=1Eh, Lo-tech XT-CF features.

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
; Int 13h function AH=1Eh, Lo-tech XT-CF features.
; This function is supported only by XTIDE Universal BIOS.
;
; AH1Eh_HandlerForXTCFfeatures
;	Parameters:
;		AL, CX:	Same as in INTPACK
;		DL:		Translated Drive number
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Parameters on INTPACK:
;		AL:		XT-CF subcommand (see XTCF.inc for more info)
;	Returns with INTPACK:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;--------------------------------------------------------------------
AH1Eh_HandlerForXTCFfeatures:
%ifndef USE_186
	call	ProcessXTCFsubcommandFromAL
	jmp		Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
%else
	push	Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
	; Fall to ProcessXTCFsubcommandFromAL
%endif


;--------------------------------------------------------------------
; ProcessXTCFsubcommandFromAL
;	Parameters:
;		AL:		XT-CF subcommand (see XTCF.inc for more info)
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;	Corrupts registers:
;		AL, BX, CX, DX, SI
;--------------------------------------------------------------------
ProcessXTCFsubcommandFromAL:
	; IS_THIS_DRIVE_XTCF. We check this for all commands.
	call	AccessDPT_IsThisDeviceXTCF
	jne		SHORT XTCFnotFound
	and		ax, BYTE 7Fh				; Subcommand now in AX (clears AH and CF)
	jz		SHORT .ReturnWithSuccess	; IS_THIS_DRIVE_XTCF

	; READ_XTCF_CONTROL_REGISTER_TO_DH
	dec		ax							; Subcommand
	jnz		SHORT .SkipReadXtcfControlRegisterToDH
	mov		dx, [di+DPT.wBasePort]
	add		dl, XTCF_CONTROL_REGISTER	; Will never overflow (keeps CF cleared)
	in		al, dx
	mov		[bp+IDEPACK.intpack+INTPACK.dh], al
.ReturnWithSuccess:
	ret		; With AH and CF cleared

.SkipReadXtcfControlRegisterToDH:
	; WRITE_DH_TO_XTCF_CONTROL_REGISTER
	dec		ax							; Subcommand
	jnz		SHORT XTCFnotFound			; Invalid subcommand
	mov		al, [bp+IDEPACK.intpack+INTPACK.dh]
	; Fall to AH1Eh_ChangeXTCFmodeBasedOnControlRegisterInAL


;--------------------------------------------------------------------
; AH1Eh_ChangeXTCFmodeBasedOnControlRegisterInAL
;	Parameters:
;		AL:		XT-CF Control Register
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;	Corrupts registers:
;		AL, BX, CX, DX, SI
;--------------------------------------------------------------------
AH1Eh_ChangeXTCFmodeBasedOnControlRegisterInAL:
	; Output Control Register
	mov		dx, [di+DPT.wBasePort]
	add		dl, XTCF_CONTROL_REGISTER
	out		dx, al

	; We always need to enable 8-bit mode since 16-bit mode is restored
	; when controller is reset (AH=00h or 0Dh)
	ePUSH_T	bx, AH23h_Enable8bitPioMode

	; Convert Control Register Contents to device code
	test	al, al
	jz		SHORT .Set8bitPioMode
	cmp		al, XTCF_MEMORY_MAPPED_MODE
	jae		SHORT .SetMemoryMappedMode

; We need to limit block size here. Consider this scenario;
; 1. While in PIO mode or memory mapped mode, the drive is set to do
;    block transfers larger than XTCF_DMA_MODE_MAX_BLOCK_SIZE.
; 2. A call is subsequently made to change device mode to DEVICE_8BIT_XTCF_DMA.
; 3. The call to AH24h_SetBlockSize fails but the change in device mode has been made.

	; Set DMA Mode
	mov		BYTE [di+DPT_ATA.bDevice], DEVICE_8BIT_XTCF_DMA
	mov		al, [di+DPT_ATA.bBlockSize]
	MIN_U	al, XTCF_DMA_MODE_MAX_BLOCK_SIZE
	jmp		SHORT AH24h_SetBlockSize	; Returns via AH23h_Enable8bitPioMode

.SetMemoryMappedMode:
	mov		al, DEVICE_8BIT_XTCF_MEMMAP
	SKIP2B	bx

.Set8bitPioMode:
	mov		al, DEVICE_8BIT_XTCF_PIO8
	mov		[di+DPT_ATA.bDevice], al
	ret		; Via AH23h_Enable8bitPioMode


;--------------------------------------------------------------------
; AH1Eh_DetectXTCFwithBasePortInDX
;	Parameters:
;		DX:		Base I/O port address to check
;	Returns:
;		AH:		RET_HD_SUCCESS if XT-CF is found from port
;				RET_HD_INVALID if XT-CF is not found
;		CF:		Cleared if XT-CF found
;				Set if XT-CF not found
;	Corrupts registers:
;		AL
;--------------------------------------------------------------------
AH1Eh_DetectXTCFwithBasePortInDX:
	push	dx
	add		dl, XTCF_CONTROL_REGISTER_INVERTED_in	; set DX to XT-CF config register (inverted)
	in		al, dx		; get value
	mov		ah, al		; save in ah
	inc		dx			; set DX to XT-CF config register (non-inverted)
	in		al, dx		; get value
	not		al			; invert value
	pop		dx
	sub		ah, al		; do they match? (clear AH if they do)
	jz		SHORT XTCFfound

XTCFnotFound:
AH1Eh_LoadInvalidCommandToAHandSetCF:
	stc					; set carry flag since XT-CF not found
	mov		ah, RET_HD_INVALID
XTCFfound:
	ret					; and return
