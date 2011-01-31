; Project name	:	Assembly Library
; Description	:	Functions for managing display cursor.

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; DisplayCursor_SetShapeFromAX
;	Parameters:
;		AX:		Cursor shape (AH=Start scan line, AL=End scan line)
;		DS:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayCursor_SetShapeFromAX:
	mov		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.wCursorShape], ax
	ret


;--------------------------------------------------------------------
; DisplayCursor_SetCoordinatesFromAX
;	Parameters:
;		AL:		Cursor column (X-coordinate)
;		AH:		Cursor row (Y-coordinate)
;		DS:		BDA segment (zero)
;	Returns:
;		DI:		Offset to cursor location in video RAM
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayCursor_SetCoordinatesFromAX:
	xchg	dx, ax
	mov		ax, [VIDEO_BDA.wColumns]		; Column count, 40 or 80
	mul		dh								; AX = Column count * row index
	xor		dh, dh
	add		ax, dx							; Add column offset
	shl		ax, 1							; Convert to WORD offset
	add		ax, [VIDEO_BDA.wPageOffset]		; AX = Video RAM offset
	mov		[VIDEO_BDA.displayContext+DISPLAY_CONTEXT.fpCursorPosition], ax
	xchg	di, ax
	ret


;--------------------------------------------------------------------
; DisplayCursor_GetSoftwareCoordinatesToAX
;	Parameters:
;		AX:		Offset to cursor location in selected page
;		DS:		BDA segment (zero)
;	Returns:
;		AL:		Cursor column (X-coordinate)
;		AH:		Cursor row (Y-coordinate)
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayCursor_GetSoftwareCoordinatesToAX:
	mov		ax, [VIDEO_BDA.displayContext+DISPLAY_CONTEXT.fpCursorPosition]
	sub		ax, [VIDEO_BDA.wPageOffset]
	shr		ax, 1							; WORD offset to character offset
	div		BYTE [VIDEO_BDA.wColumns]		; AL = full rows, AH = column index for last row
	xchg	al, ah
	ret


;--------------------------------------------------------------------
; DisplayCursor_GetHardwareCoordinatesToAX
;	Parameters:
;		DS:		BDA segment (zero)
;	Returns:
;		AL:		Hardware cursor column (X-coordinate)
;		AH:		Hardware cursor row (Y-coordinate)
;	Corrupts registers:
;		DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayCursor_GetHardwareCoordinatesToAX:
	push	cx
	push	bx

	mov		ah, GET_CURSOR_POSITION_AND_SIZE
	mov		bh, [VIDEO_BDA.bActivePage]
	int		BIOS_VIDEO_INTERRUPT_10h
	xchg	ax, dx

	pop		bx
	pop		cx
	ret


;--------------------------------------------------------------------
; DisplayCursor_SynchronizeShapeToHardware
;	Parameters:
;		DS:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayCursor_SynchronizeShapeToHardware:
	mov		dx, [VIDEO_BDA.displayContext+DISPLAY_CONTEXT.wCursorShape]
	; Fall to .SetHardwareCursorShapeFromDX

;--------------------------------------------------------------------
; .SetHardwareCursorShapeFromDX
;	Parameters:
;		DX:		Cursor shape
;		DS:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
.SetHardwareCursorShapeFromDX:
	cmp		dx, [VIDEO_BDA.wCursorShape]
	je		SHORT .Return					; Return if no changes
	push	cx
	mov		cx, dx							; BIOS wants cursor shape in CX
	mov		al, [VIDEO_BDA.bMode]			; Load video mode to prevent lock ups on some BIOSes
	mov		ah, SET_TEXT_MODE_CURSOR_SHAPE
	int		BIOS_VIDEO_INTERRUPT_10h
	pop		cx
.Return:
	ret


;--------------------------------------------------------------------
; DisplayCursor_SynchronizeCoordinatesToHardware
;	Parameters:
;		DS:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DisplayCursor_SynchronizeCoordinatesToHardware:
	call	DisplayCursor_GetSoftwareCoordinatesToAX
	; Fall to .SetHardwareCursorCoordinatesFromAX

;--------------------------------------------------------------------
; .SetHardwareCursorCoordinatesFromAX
;	Parameters:
;		AL:		Cursor column (X-coordinate)
;		AH:		Cursor row (Y-coordinate)
;		DS:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
.SetHardwareCursorCoordinatesFromAX:
	push	bx
	xchg	dx, ax							; BIOS wants coordinates in DX
	mov		ah, SET_CURSOR_POSITION
	mov		bh, [VIDEO_BDA.bActivePage]
	int		BIOS_VIDEO_INTERRUPT_10h
	pop		bx
	ret
