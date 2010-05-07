; File name		:	BootMenuPrintCfg.asm
; Project name	:	IDE BIOS
; Created date	:	28.3.2010
; Last update	:	9.4.2010
; Author		:	Tomi Tilli
; Description	:	Functions for printing drive configuration
;					information on Boot Menu.

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Prints Hard Disk configuration for drive handled by our BIOS.
; Cursor is set to configuration header string position.
;
; BootMenuPrintCfg_ForOurDrive
;	Parameters:
;		DS:DI:	Ptr to DPT
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX, SI, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenuPrintCfg_ForOurDrive:
	call	BootMenuPrintCfg_HeaderAndChangeLine
	call	BootMenuPrintCfg_GetPointers
	call	BootMenuPrintCfg_PushAndFormatCfgString
	jmp		BootMenuPrint_ClearOneInfoLine


;--------------------------------------------------------------------
; Prints configuration header and changes for printing values.
;
; BootMenuPrintCfg_HeaderAndChangeLine
;	Parameters:
;		Nothing
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenuPrintCfg_HeaderAndChangeLine:
	mov		si, g_szCfgHeader
	call	PrintString_FromCS
	jmp		BootMenuPrint_ClearOneInfoLine


;--------------------------------------------------------------------
; Return all necessary pointers to drive information structs.
;
; BootMenuPrintCfg_GetPointers
;	Parameters:
;		DS:DI:	Ptr to DPT
;	Returns:
;		DS:DI:	Ptr to DPT
;		ES:BX:	Ptr to BOOTNFO
;		CS:SI:	Ptr to IDEVARS
;	Corrupts registers:
;		AX, DL
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenuPrintCfg_GetPointers:
	mov		dl, [di+DPT.bDrvNum]		; Load Drive number to DL
	call	BootInfo_GetOffsetToBX		; ES:BX now points...
	LOAD_BDA_SEGMENT_TO	es, ax			; ...to BOOTNFO
	mov		al, [di+DPT.bIdeOff]
	xchg	si, ax						; CS:SI now points to IDEVARS
	ret


;--------------------------------------------------------------------
; Pushes all string formatting parameters and prints
; formatted configuration string.
;
; BootMenuPrintCfg_PushAndFormatCfgString
;	Parameters:
;		DS:DI:	Ptr to DPT
;		ES:BX:	Ptr to BOOTNFO
;		CS:SI:	Ptr to IDEVARS
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, SI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenuPrintCfg_PushAndFormatCfgString:
	; Fall to first push below

;--------------------------------------------------------------------
; BootMenuPrintCfg_PushResetStatus
;	Parameters:
;		DS:DI:	Ptr to DPT
;		ES:BX:	Ptr to BOOTNFO
;		CS:SI:	Ptr to IDEVARS
;	Returns:
;		Nothing (falls to next push below)
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
BootMenuPrintCfg_PushResetStatus:
	eMOVZX	ax, BYTE [di+DPT.bReset]
	push	ax

;--------------------------------------------------------------------
; BootMenuPrintCfg_PushIRQ
;	Parameters:
;		DS:DI:	Ptr to DPT
;		ES:BX:	Ptr to BOOTNFO
;		CS:SI:	Ptr to IDEVARS
;	Returns:
;		Nothing (falls to next push below)
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
BootMenuPrintCfg_PushIRQ:
	mov		dl, ' '						; Load space to DL
	mov		al, [cs:si+IDEVARS.bIRQ]
	test	al, al						; Interrupts disabled?
	jz		SHORT .PushIrqDisabled
	add		al, '0'						; Digit to ASCII
	cmp		al, '9'						; Only one digit needed?
	jbe		SHORT .PushCharacters

	; Two digits needed
	sub		al, 10						; Limit to single digit ASCII
	mov		dl, '1'						; Load '1 to DX
	jmp		SHORT .PushCharacters
ALIGN JUMP_ALIGN
.PushIrqDisabled:
	mov		al, '-'						; Load line to AL
	xchg	ax, dx						; Space to AL, line to DL
ALIGN JUMP_ALIGN
.PushCharacters:
	push	ax
	push	dx

;--------------------------------------------------------------------
; BootMenuPrintCfg_PushBusType
;	Parameters:
;		DS:DI:	Ptr to DPT
;		ES:BX:	Ptr to BOOTNFO
;		CS:SI:	Ptr to IDEVARS
;	Returns:
;		Nothing (jumps to next push below)
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
BootMenuPrintCfg_PushBusType:
	xchg	ax, bx		; Store BX to AX
	eMOVZX	bx, BYTE [cs:si+IDEVARS.bBusType]
	mov		bx, [cs:bx+.rgwBusTypeValues]	; Char to BL, Int to BH	
	eMOVZX	dx, bh
	push	dx			; Push 8, 16 or 32
	push	bx			; Push character
	xchg	bx, ax		; Restore BX
	jmp		SHORT .NextPush
ALIGN WORD_ALIGN
.rgwBusTypeValues:
	db		'D', 8		; BUS_TYPE_8_DUAL
	db		' ', 16		; BUS_TYPE_16
	db		' ', 32		; BUS_TYPE_32
	db		'S', 8		; BUS_TYPE_8_SINGLE
ALIGN JUMP_ALIGN
.NextPush:

;--------------------------------------------------------------------
; BootMenuPrintCfg_PushBlockMode
;	Parameters:
;		DS:DI:	Ptr to DPT
;		ES:BX:	Ptr to BOOTNFO
;		CS:SI:	Ptr to IDEVARS
;	Returns:
;		Nothing (falls to next push below)
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
BootMenuPrintCfg_PushBlockMode:
	eMOVZX	ax, BYTE [di+DPT.bSetBlock]
	push	ax

;--------------------------------------------------------------------
; BootMenuPrintCfg_PushAddressingMode
;	Parameters:
;		DS:DI:	Ptr to DPT
;		ES:BX:	Ptr to BOOTNFO
;		CS:SI:	Ptr to IDEVARS
;	Returns:
;		Nothing (jumps to next push below)
;	Corrupts registers:
;		AX, DX
;--------------------------------------------------------------------
BootMenuPrintCfg_PushAddressingMode:
	mov		dx, bx				; Backup BX to DX
	mov		bx, MASK_DPT_ADDR	; Load addressing mode mask
	and		bl, [di+DPT.bFlags]	; Addressing mode now in BX
	push	WORD [cs:bx+.rgszAddressingModeString]
	mov		bx, dx
	jmp		SHORT .NextPush
ALIGN WORD_ALIGN
.rgszAddressingModeString:
	dw	g_szLCHS
	dw	g_szPCHS
	dw	g_szLBA28
	dw	g_szLBA48
ALIGN JUMP_ALIGN
.NextPush:

;--------------------------------------------------------------------
; Prints formatted configuration string from parameters pushed to stack.
;
; BootMenuPrintCfg_ValuesFromStack
;	Parameters:
;		Stack:	All formatting parameters
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, CX, DX, SI
;--------------------------------------------------------------------
BootMenuPrintCfg_ValuesFromStack:
	mov		si, g_szCfgFormat
	mov		dh, 14						; 14 bytes pushed to stack
	jmp		PrintString_JumpToFormat
