; Project name	:	Assembly Library
; Description	:	Functions for register operations.


; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Math_DivQWatSSBPbyCX
;	Parameters:
;		[SS:BP]:	64-bit unsigned divident
;		CX:			16-bit unsigned divisor
;	Returns:
;		[SS:BP]:	64-bit unsigned quotient
;		DX:			16-bit unsigned remainder
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDECFG	; Not used in XTIDECFG
ALIGN JUMP_ALIGN
Math_DivQWatSSBPbyCX:
	xor		dx, dx
	mov		ax, [bp+6]		; Load highest divident WORD to DX:AX
	div		cx
	mov		[bp+6], ax		; Store quotient

	mov		ax, [bp+4]
	div		cx
	mov		[bp+4], ax

	mov		ax, [bp+2]
	div		cx
	mov		[bp+2], ax

	mov		ax, [bp]
	div		cx
	mov		[bp], ax
	ret
%endif


;--------------------------------------------------------------------
; Math_DivDXAXbyCX
;	Parameters:
;		DX:AX:	32-bit unsigned divident
;		CX:		16-bit unsigned divisor
;	Returns:
;		DX:AX:	32-bit unsigned quotient
;		BX:		16-bit unsigned remainder
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
%ifndef EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS OR EXCLUDE_FROM_XTIDECFG
ALIGN JUMP_ALIGN
Math_DivDXAXbyCX:	; This is currently unused (dead code)
	xor		bx, bx
	xchg	bx, ax
	xchg	dx, ax
	div		cx
	xchg	ax, bx
	div		cx
	xchg	dx, bx
	ret
%endif
