; Project name	:	XTIDE Universal BIOS
; Description	:	Int 13h function AH=24h, Set Multiple Blocks.

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Int 13h function AH=24h, Set Multiple Blocks.
;
; AH24h_HandlerForSetMultipleBlocks
;	Parameters:
;		AL:		Same as in INTPACK
;		DL:		Translated Drive number
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Parameters on INTPACK:
;		AL:		Number of Sectors per Block (1, 2, 4, 8, 16, 32, 64 or 128)
;	Returns with INTPACK:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;--------------------------------------------------------------------
AH24h_HandlerForSetMultipleBlocks:
%ifndef USE_186
	call	AH24h_SetBlockSize
	jmp		Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
%else
	push	Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
	; Fall to AH24h_SetBlockSize
%endif


;--------------------------------------------------------------------
; AH24h_SetBlockSize
;	Parameters:
;		AL:		Number of Sectors per Block (1, 2, 4, 8, 16, 32, 64 or 128)
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Returns:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;	Corrupts registers:
;		AL, BX, CX, DX
;--------------------------------------------------------------------
AH24h_SetBlockSize:
	push	ax
	xchg	dx, ax			; DL = Block size (Sector Count Register)
	or		BYTE [di+DPT.bFlagsHigh], FLGH_DPT_BLOCK_MODE_SUPPORTED	; Assume success
	mov		al, COMMAND_SET_MULTIPLE_MODE
	mov		bx, TIMEOUT_AND_STATUS_TO_WAIT(TIMEOUT_DRDY, FLG_STATUS_DRDY)
	call	Idepack_StoreNonExtParametersAndIssueCommandFromAL
	pop		bx
	jnc		.StoreBlockSize
	mov		bl, 1	; Disable block mode
	and		BYTE [di+DPT.bFlagsHigh], ~FLGH_DPT_BLOCK_MODE_SUPPORTED
.StoreBlockSize:	; Store new block size to DPT and return
	mov		[di+DPT_ATA.bSetBlock], bl
	ret
