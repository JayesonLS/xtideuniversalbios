; Project name	:	XTIDE Universal BIOS
; Description	:	Int 13h function AH=48h, Get Extended Drive Parameters.

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Int 13h function AH=48h, Get Extended Drive Parameters.
;
; AH48h_GetExtendedDriveParameters
;	Parameters:
;		SI:		Same as in INTPACK
;		DL:		Translated Drive number
;		DS:DI:	Ptr to DPT (in RAMVARS segment)
;		SS:BP:	Ptr to IDEPACK
;	Parameters on INTPACK:
;		DS:SI:	Ptr to Extended Drive Information Table to fill
;	Returns with INTPACK:
;		AH:		Int 13h return status
;		DS:SI:	Ptr to Extended Drive Information Table
;		CF:		0 if successful, 1 if error
;--------------------------------------------------------------------
AH48h_HandlerForGetExtendedDriveParameters:
	call	AccessDPT_GetPointerToDRVPARAMStoCSBX
	push	bx
	call	AccessDPT_GetLbaSectorCountToBXDXAX
	pop		di			; CS:DI now points to DRVPARAMS

	; Point DS:SI to Extended Drive Information Table to fill
	mov		ds, [bp+IDEPACK.intpack+INTPACK.ds]
	mov		cx, MINIMUM_EDRIVEINFO_SIZE
	cmp		[si+EDRIVE_INFO.wSize], cx
	jb		Prepare_ReturnFromInt13hWithInvalidFunctionError
	je		SHORT .SkipEddConfigurationParameters

	; We do not support EDD Configuration Parameters so set to FFFF:FFFFh
	mov		cx, -1		; FFFFh
	mov		[si+EDRIVE_INFO.fpEDDparams], cx
	mov		[si+EDRIVE_INFO.fpEDDparams+2], cx
	mov		cx, EDRIVE_INFO_size

	; Fill Extended Drive Information Table in DS:SI
.SkipEddConfigurationParameters:
	mov		[si+EDRIVE_INFO.wSize], cx
	mov		WORD [si+EDRIVE_INFO.wFlags], FLG_DMA_BOUNDARY_ERRORS_HANDLED_BY_BIOS

	; Store total sector count
	mov		[si+EDRIVE_INFO.qwTotalSectors], ax
	xor		ax, ax									; Return with success
	mov		[si+EDRIVE_INFO.qwTotalSectors+2], dx
	mov		[si+EDRIVE_INFO.qwTotalSectors+4], bx
	mov		[si+EDRIVE_INFO.qwTotalSectors+6], ax	; Always zero
	mov		WORD [si+EDRIVE_INFO.wSectorSize], 512

.ReturnWithError:
	jmp		Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
