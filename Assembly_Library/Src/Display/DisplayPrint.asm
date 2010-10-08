; File name		:	Display.asm
; Project name	:	Assembly Library
; Created date	:	26.6.2010
; Last update	:	27.9.2010
; Author		:	Tomi Tilli
; Description	:	Functions for display output.

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Supports following formatting types:
;	%a		Specifies attribute for next character
;	%A		Specifies attribute for remaining string (or until next %A)
;	%d		Prints signed 16-bit decimal integer
;	%u		Prints unsigned 16-bit decimal integer
;	%x		Prints 16-bit hexadecimal integer
;	%s		Prints string (from CS segment)
;	%S		Prints string (far pointer)
;	%c		Prints character
;	%t		Prints character number of times (character needs to be pushed first, then repeat times)
;	%%		Prints '%' character (no parameter pushed)
;
;	Any placeholder can be set to minimum length by specifying
;	minimum number of characters. For example %8d would append spaces
;	after integer so that at least 8 characters would be printed.
;
;	When placing '-' after number, then spaces will be used for prepending.
;	For example %8-d would prepend integer with spaces so that at least
;	8 characters would be printed.
; 
; DisplayPrint_FormattedNullTerminatedStringFromCSSI
;	Parameters:
;		BP:		SP before pushing parameters
;		DS:		BDA segment (zero)
;		CS:SI:	Pointer to string to format
;		ES:DI:	Ptr to cursor location in video RAM
;		Stack:	Parameters for formatting placeholders.
;				Parameter for first placeholder must be pushed first.
;				Low word must pushed first for placeholders requiring
;				32-bit parameters (two words).
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayPrint_FormattedNullTerminatedStringFromCSSI:
	push	bp
	push	si
	push	cx
	push	bx
	push	WORD [VIDEO_BDA.displayContext+DISPLAY_CONTEXT.bAttribute]

	dec		bp					; Point BP to...
	dec		bp					; ...first stack parameter
	call	DisplayFormat_ParseCharacters

	; Pop original character attribute
	pop		ax
	mov		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.bAttribute], al

	pop		bx
	pop		cx
	pop		si
	pop		bp
	ret


;--------------------------------------------------------------------
; DisplayPrint_SignedWordFromAXWithBaseInBX
;	Parameters:
;		AX:		Word to display
;		BX:		Integer base (binary=2, octal=8, decimal=10, hexadecimal=16)
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayPrint_SignedWordFromAXWithBaseInBX:
	test	ax, ax
	jns		SHORT DisplayPrint_WordFromAXWithBaseInBX

	push	ax
	mov		al, '-'
	call	DisplayPrint_CharacterFromAL
	pop		ax
	neg		ax
	; Fall to DisplayPrint_WordFromAXWithBaseInBX

;--------------------------------------------------------------------
; DisplayPrint_WordFromAXWithBaseInBX
;	Parameters:
;		AX:		Word to display
;		BX:		Integer base (binary=2, octal=8, decimal=10, hexadecimal=16)
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayPrint_WordFromAXWithBaseInBX:
	push	cx
	push	bx

	xor		cx, cx
ALIGN JUMP_ALIGN
.DivideLoop:
	xor		dx, dx				; DX:AX now holds the integer
	div		bx					; Divide DX:AX by base
	push	dx					; Push remainder
	inc		cx					; Increment character count
	test	ax, ax				; All divided?
	jnz		SHORT .DivideLoop	;  If not, loop

	mov		bx, .rgcDigitToCharacter
ALIGN JUMP_ALIGN
.PrintNextDigit:
	pop		ax					; Pop digit
	eSEG	cs
	xlatb
	call	DisplayPrint_CharacterFromAL
	loop	.PrintNextDigit

	pop		bx
	pop		cx
	ret
.rgcDigitToCharacter:	db	"0123456789ABCDEF"


;--------------------------------------------------------------------
; DisplayPrint_CharacterBufferFromBXSIwithLengthInCX
;	Parameters:
;		CX:		Buffer length (characters)
;		BX:SI:	Ptr to NULL terminated string
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayPrint_CharacterBufferFromBXSIwithLengthInCX:
	jcxz	.NothingToPrintSinceZeroLength
	push	si
	push	cx

ALIGN JUMP_ALIGN
.PrintNextCharacter:
	mov		ds, bx
	lodsb
	LOAD_BDA_SEGMENT_TO	ds, dx
	call	DisplayPrint_CharacterFromAL
	loop	.PrintNextCharacter

	LOAD_BDA_SEGMENT_TO	ds, dx
	pop		cx
	pop		si
.NothingToPrintSinceZeroLength:
	ret


;--------------------------------------------------------------------
; DisplayPrint_NullTerminatedStringFromCSSI
;	Parameters:
;		CS:SI:	Ptr to NULL terminated string
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayPrint_NullTerminatedStringFromCSSI:
	push	bx
	mov		bx, cs
	call	DisplayPrint_NullTerminatedStringFromBXSI
	pop		bx
	ret


;--------------------------------------------------------------------
; DisplayPrint_NullTerminatedStringFromBXSI
;	Parameters:
;		DS:		BDA segment (zero)
;		BX:SI:	Ptr to NULL terminated string
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayPrint_NullTerminatedStringFromBXSI:
	push	si
	push	cx

	xor		cx, cx
ALIGN JUMP_ALIGN
.PrintNextCharacter:
	mov		ds, bx				; String segment to DS
	lodsb
	mov		ds, cx				; BDA segment to DS
	test	al, al				; NULL?
	jz		SHORT .EndOfString
	call	DisplayPrint_CharacterFromAL
	jmp		SHORT .PrintNextCharacter

ALIGN JUMP_ALIGN
.EndOfString:
	pop		cx
	pop		si
	ret


;--------------------------------------------------------------------
; DisplayPrint_ClearScreen
;	Parameters:
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayPrint_ClearScreen:
	push	di
	xor		ax, ax
	call	DisplayCursor_SetCoordinatesFromAX
	call	DisplayPage_GetColumnsToALandRowsToAH
	call	DisplayPrint_ClearAreaWithHeightInAHandWidthInAL
	pop		di
	mov		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.fpCursorPosition], di
	ret


;--------------------------------------------------------------------
; DisplayPrint_ClearAreaWithHeightInAHandWidthInAL
;	Parameters:
;		AH:		Area height
;		AL:		Area width
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayPrint_ClearAreaWithHeightInAHandWidthInAL:
	push	si
	push	cx
	push	bx

	xchg	bx, ax							; Area size to BX
	call	DisplayCursor_GetSoftwareCoordinatesToAX
	xchg	si, ax							; Software (Y,X) coordinates now in SI
	xor		cx, cx

ALIGN JUMP_ALIGN
.ClearRowLoop:
	mov		cl, bl							; Area width now in CX
	mov		al, SCREEN_BACKGROUND_CHARACTER
	call	DisplayPrint_RepeatCharacterFromALwithCountInCX

	xchg	ax, si							; Coordinates to AX
	inc		ah								; Increment row
	mov		si, ax
	call	DisplayCursor_SetCoordinatesFromAX
	dec		bh								; Decrement rows left
	jnz		SHORT .ClearRowLoop

	pop		bx
	pop		cx
	pop		si
	ret


;--------------------------------------------------------------------
; DisplayPrint_RepeatCharacterFromALwithCountInCX
;	Parameters:
;		AL:		Character to display
;		CX:		Repeat count
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayPrint_RepeatCharacterFromALwithCountInCX:
	jcxz	.NothingToRepeat
	push	cx

ALIGN JUMP_ALIGN
.RepeatCharacter:
	push	ax
	call	DisplayPrint_CharacterFromAL
	pop		ax
	loop	.RepeatCharacter

	pop		cx
.NothingToRepeat:
	ret


;--------------------------------------------------------------------
; DisplayPrint_Newline
;	Parameters:
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayPrint_Newline:
	mov		al, CR
	call	DisplayPrint_CharacterFromAL
	mov		al, LF
	; Fall to DisplayPrint_CharacterFromAL


;--------------------------------------------------------------------
; DisplayPrint_CharacterFromAL
;	Parameters:
;		AL:		Character to display
;		DS:		BDA segment (zero)
;		ES:DI:	Ptr to cursor location in video RAM
;	Returns:
;		DI:		Updated offset to video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayPrint_CharacterFromAL:
	mov		ah, [VIDEO_BDA.displayContext+DISPLAY_CONTEXT.bAttribute]
	jmp		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.fnCharOut]
