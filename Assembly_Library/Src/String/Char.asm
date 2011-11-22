; Project name	:	Assembly Library
; Description	:	Functions for handling characters.

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; This macro can only be used within this source file!!!
; IS_BETWEEN_IMMEDIATES
;	Parameters:
;		%1:		Value to check
;		%2:		First accepted value in range
;		%3:		Last accepted value in range
;	Returns:
;		CF:		Set if character is range
;				(Jumps to Char_CharIsNotValid if before range)
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%macro IS_BETWEEN_IMMEDIATES 3
	cmp		%1, %2
	jb		SHORT Char_CharIsNotValid
	cmp		%1, (%3)+1				; Set CF if %1 is lesser
%endmacro


;--------------------------------------------------------------------
; Char_IsLowerCaseLetterInAL
;	Parameters:
;		AL:		Character to check
;	Returns:
;		CF:		Set if character is lower case letter ('a'...'z')
;				Cleared if character is not lower case letter
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Char_IsLowerCaseLetterInAL:
	IS_BETWEEN_IMMEDIATES al, 'a', 'z'
	ret

;--------------------------------------------------------------------
; Char_IsUpperCaseLetterInAL
;	Parameters:
;		AL:		Character to check
;	Returns:
;		CF:		Set if character is upper case letter ('A'...'Z')
;				Cleared if character is not upper case letter
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS
ALIGN JUMP_ALIGN
Char_IsUpperCaseLetterInAL:
	IS_BETWEEN_IMMEDIATES al, 'A', 'Z'
	ret
%endif

;--------------------------------------------------------------------
; Char_IsHexadecimalDigitInAL
;	Parameters:
;		AL:		Character to check
;	Returns:
;		AL:		Character converted to lower case
;		CF:		Set if character is decimal digit ('0'...'F')
;				Cleared if character is not decimal digit
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS
ALIGN JUMP_ALIGN
Char_IsHexadecimalDigitInAL:
	call	Char_IsDecimalDigitInAL
	jc		SHORT Char_CharIsValid
	call	Char_ALtoLowerCaseLetter
	IS_BETWEEN_IMMEDIATES al, 'a', 'f'
	ret
%endif

;--------------------------------------------------------------------
; Char_IsDecimalDigitInAL
;	Parameters:
;		AL:		Character to check
;	Returns:
;		CF:		Set if character is decimal digit ('0'...'9')
;				Cleared if character is not decimal digit
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%ifndef MODULE_STRINGS_COMPRESSED
ALIGN JUMP_ALIGN
Char_IsDecimalDigitInAL:
	IS_BETWEEN_IMMEDIATES al, '0', '9'
	ret
%endif

;--------------------------------------------------------------------
; Char_ConvertIntegerToALfromDigitInALwithBaseInBX
;	Parameters:
;		AL:		Character to convert
;		BX:		Numeric base (10 or 16)
;	Returns:
;		AL:		Character converted to integer
;		CF:		Set if character was valid
;				Cleared if character was invalid
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS
ALIGN JUMP_ALIGN
Char_ConvertIntegerToALfromDigitInALwithBaseInBX:
	push	dx
	call	Char_GetFilterFunctionToDXforNumericBaseInBX
	call	dx						; Converts to lower case
	pop		dx
	jnc		SHORT Char_CharIsNotValid

	cmp		al, '9'					; Decimal digit
	jbe		SHORT .ConvertToDecimalDigit
	sub		al, 'a'-'0'-10			; Convert to hexadecimal integer
ALIGN JUMP_ALIGN
.ConvertToDecimalDigit:
	sub		al, '0'					; Convert to decimal integer
	; Fall to Char_CharIsValid
%endif

;--------------------------------------------------------------------
; Char_CharIsValid
; Char_CharIsNotValid
;	Parameters:
;		Nothing
;	Returns:
;		CF:		Set for Char_CharIsValid
;				Cleared for Char_CharIsNotValid
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS
ALIGN JUMP_ALIGN
Char_CharIsValid:
	stc
	ret
%endif

ALIGN JUMP_ALIGN
Char_CharIsNotValid:
	clc
	ret


;--------------------------------------------------------------------
; Char_ALtoLowerCaseLetter
;	Parameters:
;		AL:		Character to convert
;	Returns:
;		AL:		Character with possible conversion
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS
ALIGN JUMP_ALIGN
Char_ALtoLowerCaseLetter:
	call	Char_IsUpperCaseLetterInAL	; Is upper case character?
	jmp		SHORT Char_ALtoUpperCaseLetter.CheckCF
%endif

;--------------------------------------------------------------------
; Char_ALtoUpperCaseLetter
;	Parameters:
;		AL:		Character to convert
;	Returns:
;		AL:		Character with possible conversion
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Char_ALtoUpperCaseLetter:
	call	Char_IsLowerCaseLetterInAL	; Is lower case character?
.CheckCF:
	jnc		SHORT Char_ChangeCaseInAL.Return
	; Fall to Char_ChangeCaseInAL

;--------------------------------------------------------------------
; Char_ChangeCaseInAL
;	Parameters:
;		AL:		Character to convert (must be A-Z or a-z)
;	Returns:
;		AL:		Character converted
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
Char_ChangeCaseInAL:
	xor		al, 32
.Return:
	ret

;--------------------------------------------------------------------
; Char_GetFilterFunctionToDXforNumericBaseInBX
;	Parameters
;		BX:		Numeric base (10 or 16)
;	Returns:
;		CS:DX:	Ptr to character filter function
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS
ALIGN JUMP_ALIGN
Char_GetFilterFunctionToDXforNumericBaseInBX:
	mov		dx, Char_IsDecimalDigitInAL
	cmp		bl, 10
	je		SHORT .Return
	mov		dx, Char_IsHexadecimalDigitInAL
.Return:
	ret
%endif
