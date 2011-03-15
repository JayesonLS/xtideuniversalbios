; Project name	:	Assembly Library
; Description	:	Functions for managing keyboard.

BUFFER_SIZE_FOR_WORD_INPUT		EQU		6	; 5 chars + NULL

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Reads user inputted word.
; Function returns when ENTER or ESC will be pressed.
;
; Keyboard_ReadUserInputtedWordWhilePrinting
;	Parameters
;		BX:		Numeric base (10 or 16)
;	Returns:
;		AX:		User inputted word
;		ZF:		Set if user cancellation
;	Corrupts registers:
;		DX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS
ALIGN JUMP_ALIGN
Keyboard_ReadUserInputtedWordWhilePrinting:
	push	ds
	push	si
	push	cx

	mov		cx, BUFFER_SIZE_FOR_WORD_INPUT
	call	Memory_ReserveCXbytesFromStackToDSSI

	call	Char_GetFilterFunctionToDXforNumericBaseInBX
	call	Registers_ExchangeDSSIwithESDI
	call	Keyboard_ReadUserInputtedStringToESDIWhilePrinting
	call	Registers_ExchangeDSSIwithESDI	; Does not modify FLAGS
	jz		SHORT .CancelledByUser

	call	String_ConvertWordToAXfromStringInDSSIwithBaseInBX
.CancelledByUser:
	add		sp, BYTE BUFFER_SIZE_FOR_WORD_INPUT
	test	cx, cx							; Set ZF if string length is zero
	pop		cx
	pop		si
	pop		ds
	ret
%endif


;--------------------------------------------------------------------
; Reads user inputted string to buffer. Character filter is
; supported to ignore unwanted characters.
; Function returns when ENTER or ESC will be pressed.
;
; Keyboard_ReadUserInputtedStringToESDIWhilePrinting
;	Parameters:
;		CX:		Buffer size (with NULL)
;		ES:DI:	Ptr to destination buffer
;		CS:DX:	Ptr to character filter function:
;					Parameters:
;						AL:		Character inputted by user
;					Returns:
;						CF:		Set if character is accepted
;								Cleared if character is rejected
;					Corrupts registers:
;						Nothing
;	Returns:
;		CX:		String length in characters (without NULL)
;		ZF:		Set if user cancellation
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS
ALIGN JUMP_ALIGN
Keyboard_ReadUserInputtedStringToESDIWhilePrinting:
	push	di
	push	si
	push	bx
	call	.PrepareDisplayContextForKeyboardInput
	jcxz	.ReturnAfterUpdatingZF

	xor		bx, bx								; Zero character counter
	dec		cx									; Decrement buffer size for NULL
	cld
ALIGN JUMP_ALIGN
.GetCharacterFromUser:
	call	Keyboard_GetKeystrokeToAXandWaitIfNecessary	; Get ASCII to AL
	call	.ProcessControlCharacter
	jz		SHORT .TerminateStringWithNULL
	jc		SHORT .PlayBellForRejectedCharacter
	call	dx									; Filter character
	jnc		SHORT .PlayBellForRejectedCharacter
	inc		bx									; Increment number of characters stored
	stosb										; Store from AL to ES:DI
	call	Keyboard_PrintInputtedCharacter
	loop	.GetCharacterFromUser
.PlayBellForRejectedCharacter:
	cmp		al, BS								; No bell for backspace
	je		SHORT .GetCharacterFromUser
	call	Keyboard_PlayBellForUnwantedKeystroke
	jmp		SHORT .GetCharacterFromUser

.TerminateStringWithNULL:
	stosb										; Terminate string with NULL
	mov		cx, bx								; String length now in CX

.ReturnAfterUpdatingZF:
	CALL_DISPLAY_LIBRARY PopDisplayContext
	test	cx, cx								; Clear or set ZF
	pop		bx
	pop		si
	pop		di
	ret

;--------------------------------------------------------------------
; .PrepareDisplayContextForKeyboardInput
;	Parameters:
;		Nothing
;	Returns:
;		Nothing (Display context pushed to stack)
;	Corrupts registers:
;		AX, BX, SI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.PrepareDisplayContextForKeyboardInput:
	pop		bx					; Pop return address to BX
	mov		si, di

	CALL_DISPLAY_LIBRARY PushDisplayContext
	mov		ax, CURSOR_NORMAL
	CALL_DISPLAY_LIBRARY SetCursorShapeFromAX
	CALL_DISPLAY_LIBRARY SynchronizeDisplayContextToHardware

	mov		di, si
	jmp		bx


;--------------------------------------------------------------------
; .ProcessControlCharacter
;	Parameters:
;		AL:		Character inputted by user
;		CX:		Number of bytes left in buffer
;		BX:		Total number of characters inputted
;		ES:DI:	Ptr where to store next character
;	Returns:
;		AL:		Character inputted by user or NULL if end of input
;		BX:		Cleared if user cancellation
;		ZF:		Set if user has ended or cancelled key input
;		CF:		Set if character is rejected
;	Corrupts registers:
;		AH
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.ProcessControlCharacter:
	cmp		al, CR								; ENTER to terminate string?
	je		SHORT .EndCharacterInput
	cmp		al, ESC								; Cancel input?
	je		SHORT .CancelCharacterInput
	cmp		al, BS								; Backspace?
	je		SHORT .Backspace
	jcxz	.RejectCharacter
	clc											; Clear CF (ZF is already cleared)
	ret

.Backspace:
	test	bx, bx								; At the beginning?
	jz		SHORT .RejectCharacter
	inc		cx									; Increment bytes left
	dec		bx									; Decrement characters inputted
	dec		di
	call	Keyboard_PrintBackspace
	mov		al, BS								; Restore character
.RejectCharacter:
	test	al, al								; Clear ZF...
	stc											; ...and set CF
	ret

.CancelCharacterInput:
	xor		bx, bx
.EndCharacterInput:
	xor		al, al								; Set ZF and clear CF
	ret
%endif ; EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS


;--------------------------------------------------------------------
; Keyboard_PrintBackspace
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS
ALIGN JUMP_ALIGN
Keyboard_PrintBackspace:
	mov		al, BS
	call	Keyboard_PrintInputtedCharacter
	mov		al, ' '
	call	Keyboard_PrintInputtedCharacter
	mov		al, BS
	jmp		SHORT Keyboard_PrintInputtedCharacter
%endif


;--------------------------------------------------------------------
; Keyboard_PlayBellForUnwantedKeystroke
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS
ALIGN JUMP_ALIGN
Keyboard_PlayBellForUnwantedKeystroke:
	mov		al, BELL
	; Fall to Keyboard_PrintInputtedCharacter
%endif

;--------------------------------------------------------------------
; Keyboard_PrintInputtedCharacter
;	Parameters:
;		AL:		Character inputted by user
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS
ALIGN JUMP_ALIGN
Keyboard_PrintInputtedCharacter:
	push	di
	CALL_DISPLAY_LIBRARY PrintCharacterFromAL
	CALL_DISPLAY_LIBRARY SynchronizeDisplayContextToHardware	; Hardware cursor
	pop		di
	ret
%endif


;--------------------------------------------------------------------
; Keyboard_RemoveAllKeystrokesFromBuffer
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS	; Only used when debugging
ALIGN JUMP_ALIGN
Keyboard_RemoveAllKeystrokesFromBuffer:
	call	Keyboard_GetKeystrokeToAX
	jnz		SHORT Keyboard_RemoveAllKeystrokesFromBuffer
	ret
%endif


;--------------------------------------------------------------------
; Keyboard_GetKeystrokeToAX
; Keyboard_GetKeystrokeToAXandLeaveItToBuffer
; Keyboard_GetKeystrokeToAXandWaitIfNecessary
;	Parameters:
;		Nothing
;	Returns:
;		AL:		ASCII character (if keystroke available)
;		AH:		BIOS scan code (if keystroke available)
;		ZF:		Set if no keystroke available
;				Cleared if keystroke available
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Keyboard_GetKeystrokeToAXandLeaveItToBuffer:
	mov		ah, CHECK_FOR_KEYSTROKE
	int		BIOS_KEYBOARD_INTERRUPT_16h
	ret
ALIGN JUMP_ALIGN
Keyboard_GetKeystrokeToAX:
	call	Keyboard_GetKeystrokeToAXandLeaveItToBuffer
	jz		SHORT Keyboard_GetKeystrokeToAXReturn
	; Fall to Keyboard_GetKeystrokeToAXandWaitIfNecessary
ALIGN JUMP_ALIGN
Keyboard_GetKeystrokeToAXandWaitIfNecessary:
	xor		ah, ah						; GET_KEYSTROKE
	int		BIOS_KEYBOARD_INTERRUPT_16h
	test	ax, ax						; Clear ZF
Keyboard_GetKeystrokeToAXReturn:
	ret
