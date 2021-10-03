; Project name	:	XTIDE Universal BIOS Configurator v2
; Description	:	Functions for flashing SST flash devices.

;
; Created by Jayeson Lee-Steere
; Hereby placed into the public domain.
;

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; FlashSst_WithFlashvarsInDSSI
;	Parameters:
;		DS:BX:	Ptr to FLASHVARS
;	Returns:
;		Updated FLASHVARS in DS:BX
;	Corrupts registers:
;		AX, DX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
FlashSst_WithFlashvarsInDSBX:
	push	ds
	push	es
	push	bx
	push	cx
	push	si
	push	bp
	mov		bp, bx									; Flashvars now in SS:BP

	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.DeviceNotDetected
	call	DetectSstDevice
	jc		SHORT .ExitOnError

	call	CalibrateSstTimeout
	
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.PollingTimeoutError
	mov		cx, [bp+FLASHVARS.wPagesToFlash]
	; TODO: load DS:SI and ES:DI with source/dest.
ALIGN JUMP_ALIGN
.FlashNextPage:
	call	EraseSstPage
	jc		SHORT .ExitOnError
	call	WriteSstPage
	jc		SHORT .ExitOnError
	loop	.FlashNextPage

	; TODO: load DS:SI and ES:DI with source/dest.

	; TODO: Verify results match.
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.DataVerifyError

%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
%if FLASH_RESULT.success = 0	; Just in case this should ever change
	mov		[bp+FLASHVARS.flashResult], cl
%else
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.success
%endif
%endif
ALIGN JUMP_ALIGN
.ExitOnError:
	pop		bp
	pop		si
	pop		cx
	pop		bx
	pop		es
	pop		ds
	ret

;--------------------------------------------------------------------
; GetDestinationFarPtr
;	Parameters:
;		SS:BP:	Ptr to FLASHVARS
;	Returns:
;		ES:DI:	Ptr to destination location
;	Corrupts registers:
;		Nothing
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
GetDestinationFarPtr:
	mov		di, [bp+FLASHVARS.fpNextDestinationPage+2]
	mov		es, di
	mov		di, [bp+FLASHVARS.fpNextDestinationPage]
	ret

;--------------------------------------------------------------------
; DetectSstDevice
;	Parameters:
;		SS:BP:	Ptr to FLASHVARS
;	Returns:
;		CF:	Clear if supported SST device found
;			Set if supported SST device not found
;	Corrupts registers:
;		AX, DI, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
DetectSstDevice:
	call	GetDestinationFarPtr

	cli
	mov		BYTE [es:05555h], 0AAh	; Enter software ID sequence.
	mov		BYTE [es:02AAAh], 055h
	mov		BYTE [es:05555h], 090h
	mov		al, [es:di]				; Extra reads to be sure device
	mov		al, [es:di]				; has time to respond.
	mov		al, [es:di]
	mov		ah, [es:di]				; Vendor ID in AH.
	mov		al, [es:di + 1]			; Device ID in AL.
	mov		BYTE [es:05555h], 0F0h	; Exit software ID.
	sti

	cmp		al, 0B4h
	jb		SHORT .NotValidDevice
	cmp		al, 0B7h
	ja		SHORT .NotValidDevice
	cmp		ah, 0BFh
	jne		SHORT .NotValidDevice
	ret

.NotValidDevice:
	stc
	ret
	
;--------------------------------------------------------------------
; CalibrateSstTimeout
;	Parameters:
;		SS:BP:	Ptr to FLASHVARS
;	Returns:
;		FLASHVARS.wTimeoutCounter
;	Corrupts registers:
;		AX, BX, CX, SI, DI, DS, ES
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
CalibrateSstTimeout:
	LOAD_BDA_SEGMENT_TO	ds, ax
	call	GetDestinationFarPtr
	xor		cx, cx
	mov		si, cx
	mov		di, cx
	mov		al, [es:di]
	not		al							; Forces poll to fail.

	mov		bx, [BDA.dwTimerTicks]		; Read low word only.
	inc		bx
.WaitForFirstIncrement:
	cmp		bx, [BDA.dwTimerTicks]
	jnz		SHORT .WaitForFirstIncrement

	inc		bx

.WaitForSecondIncrement:
	inc		ch							; cx now 0x0100
.PollLoop:								; Identical to poll loop used 
	cmp		[es:di], al					; during programming
	jz		SHORT .PollComplete			; Will never branch in this case
	loop	.PollLoop
.PollComplete:
	add		si, 1						; number of poll loops completed
	jc		SHORT .countOverflow
	cmp		bx, [BDA.dwTimerTicks]
	jnz		SHORT .WaitForSecondIncrement

.CalComplete:
	; SI ~= number of polling loops in 215us.
	mov		[bp+FLASHVARS.wTimeoutCounter], si
	ret
		
.countOverflow:
	; Clamp on overflow, although it should not be possible on
	; real hardware. In principle SI could overflow on a very
	; fast CPU. However the SST device is on a slow bus. Even
	; running at the min read cycle time of fastest version of
	; the device, SI can not overflow.
	dec		si
	jmp		SHORT .CalComplete

;--------------------------------------------------------------------
; EraseSstPage
;	Parameters:
;		TODO
;	Returns:
;		TODO
;	Corrupts registers:
;		TODO
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
EraseSstPage:
	ret

;--------------------------------------------------------------------
; EraseSstPage
;	Parameters:
;		TODO
;	Returns:
;		TODO
;	Corrupts registers:
;		TODO
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
WriteSstPage:
	ret

