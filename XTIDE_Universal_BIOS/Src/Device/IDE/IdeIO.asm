; Project name	:	XTIDE Universal BIOS
; Description	:	IDE Register I/O functions.

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
; IdeIO_OutputALtoIdeControlBlockRegisterInDL
;	Parameters:
;		AL:		Byte to output
;		DL:		IDE Control Block Register
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;	Returns:
;		Nothing
;	Corrupts registers:
;		BX, DX
;--------------------------------------------------------------------
IdeIO_OutputALtoIdeControlBlockRegisterInDL:
	%ifdef MODULE_8BIT_IDE
		mov		dh, [di+DPT_ATA.bDevice]
		%ifdef MODULE_JRIDE
			test	dh, dh
			jnz		SHORT .OutputToIoMappedIde
		
			add		dx, JRIDE_CONTROL_BLOCK_REGISTER_WINDOW_OFFSET
			jmp		SHORT OutputToJrIdeRegister
		.OutputToIoMappedIde:
		%endif	; MODULE_JRIDE
	%endif	; MODULE_8BIT_IDE

	mov		bl, IDEVARS.wPortCtrl
	jmp		SHORT OutputALtoIdeRegisterInDLwithIdevarsOffsetToBasePortInBL


;--------------------------------------------------------------------
; IdeIO_OutputALtoIdeRegisterInDL
;	Parameters:
;		AL:		Byte to output
;		DL:		IDE Command Block Register
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;	Returns:
;		Nothing
;	Corrupts registers:
;		BX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdeIO_OutputALtoIdeRegisterInDL:
	%ifdef MODULE_8BIT_IDE
		mov		dh, [di+DPT_ATA.bDevice]
		%ifdef MODULE_JRIDE
			test	dh, dh
			jnz		SHORT OutputALtoIOmappedIdeRegisterInDL
		
		%if JRIDE_COMMAND_BLOCK_REGISTER_WINDOW_OFFSET & 0FFh = 0
			mov		dh, JRIDE_COMMAND_BLOCK_REGISTER_WINDOW_OFFSET >> 8
		%else
			add		dx, JRIDE_COMMAND_BLOCK_REGISTER_WINDOW_OFFSET
		%endif
		OutputToJrIdeRegister:
			mov		bx, dx
			mov		[cs:bx], al
			ret
		ALIGN JUMP_ALIGN
		OutputALtoIOmappedIdeRegisterInDL:
		%endif	; MODULE_JRIDE
	%endif	; MODULE_8BIT_IDE

	mov		bl, IDEVARS.wPort
OutputALtoIdeRegisterInDLwithIdevarsOffsetToBasePortInBL:
	call	GetIdePortToDX
	out		dx, al
	ret


;--------------------------------------------------------------------
; IdeIO_InputStatusRegisterToAL
;	Parameters:
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;	Returns:
;		AL:		IDE Status Register contents
;	Corrupts registers:
;		BX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
IdeIO_InputStatusRegisterToAL:
	mov		dl, STATUS_REGISTER_in
	; Fall to IdeIO_InputToALfromIdeRegisterInDL

;--------------------------------------------------------------------
; IdeIO_InputToALfromIdeRegisterInDL
;	Parameters:
;		DL:		IDE Register
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;	Returns:
;		AL:		Inputted byte
;	Corrupts registers:
;		BX, DX
;--------------------------------------------------------------------
IdeIO_InputToALfromIdeRegisterInDL:
	%ifdef MODULE_8BIT_IDE
		mov		dh, [di+DPT_ATA.bDevice]
		%ifdef MODULE_JRIDE
			test	dh, dh
			jnz		SHORT .InputToALfromIOmappedIdeRegisterInDL
		
		%if JRIDE_COMMAND_BLOCK_REGISTER_WINDOW_OFFSET & 0FFh = 0
			mov		dh, JRIDE_COMMAND_BLOCK_REGISTER_WINDOW_OFFSET >> 8
		%else
			add		dx, JRIDE_COMMAND_BLOCK_REGISTER_WINDOW_OFFSET
		%endif
			mov		bx, dx
			mov		al, [cs:bx]
			ret
		.InputToALfromIOmappedIdeRegisterInDL:
		%endif	; MODULE_JRIDE
	%endif	; MODULE_8BIT_IDE
	mov		bl, IDEVARS.wPort
	call	GetIdePortToDX
	in		al, dx
	ret


;--------------------------------------------------------------------
; GetIdePortToDX
;	Parameters:
;		BL:		Offset to port in IDEVARS (IDEVARS.wPort or IDEVARS.wPortCtrl)
;		DH:		Device Type (IDEVARS.bDevice)
;		DL:		IDE Register
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;	Returns:
;		DX:		Source/Destination Port
;	Corrupts registers:
;		BX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
GetIdePortToDX:
%ifdef MODULE_8BIT_IDE
	; Point CS:BX to IDEVARS
	xor		bh, bh
	add		bl, [di+DPT.bIdevarsOffset]			; CS:BX now points port address

	; Load port address and check if A0 and A3 address lines need to be reversed
	cmp		dh, DEVICE_8BIT_XTIDE_REV1
	mov		dh, bh								; DX now has IDE register offset
	jae		SHORT .ReturnUntranslatedPortInDX	; No need to swap address lines

	; Exchange address lines A0 and A3 from DL
	add		dx, [cs:bx]							; DX now has port address
	mov		bl, dl								; Port low byte to BL
	and		bl, MASK_A3_AND_A0_ADDRESS_LINES	; Clear all bits except A0 and A3
	jz		SHORT .ReturnTranslatedPortInDX		; A0 and A3 both zeroes, no change needed
	cmp		bl, MASK_A3_AND_A0_ADDRESS_LINES
	je		SHORT .ReturnTranslatedPortInDX		; A0 and A3 both ones, no change needed
	xor		dl, MASK_A3_AND_A0_ADDRESS_LINES	; Invert A0 and A3
.ReturnTranslatedPortInDX:
	ret

.ReturnUntranslatedPortInDX:
	add		dx, [cs:bx]
	ret

%else	; Only standard IDE devices
	xor		bh, bh
	add		bl, [di+DPT.bIdevarsOffset]			; CS:BX now points port address
	xor		dh, dh
	add		dx, [cs:bx]							; DX now has port address
	ret
%endif
