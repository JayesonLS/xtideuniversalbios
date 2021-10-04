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
	mov		bp, bx					; Flashvars now in SS:BP.

	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.DeviceNotDetected
	call	DetectSstDevice
	jc		SHORT .ExitOnError

	call	CalibrateSstTimeout
	
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.PollingTimeoutError
	mov		cx, [bp+FLASHVARS.wPagesToFlash]
	lds		si, [bp+FLASHVARS.fpNextSourcePage]
	les		di, [bp+FLASHVARS.fpNextDestinationPage]

ALIGN JUMP_ALIGN
.NextPage:
	; See if this page needs updating.
	push	si
	push	di
	push	cx
	mov		cx, [bp+FLASHVARS.wEepromPageSize]
	mov		bx, cx
	repe cmpsb
	pop		cx
	pop		di
	pop		si
	jnz		SHORT .FlashThisPage
	add		si, bx
	add		di, bx
	jmp		SHORT .ContinueLoop

.FlashThisPage:
	call	EraseSstPage
	jc		SHORT .ExitOnError
	call	WriteSstPage
	jc		SHORT .ExitOnError
.ContinueLoop:
	loop	.NextPage

	; The write process has already confirmed the results one byte at a time.
	; Here we do an additional verify check just in case there was some 
	; kind of oddity with pages / addresses.
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.DataVerifyError
	mov		ax, [bp+FLASHVARS.wPagesToFlash]
	mov		cl, SST_PAGE_SIZE_SHIFT
	shl		ax, cl
	mov		cx, ax
	lds		si, [bp+FLASHVARS.fpNextSourcePage]
	les		di, [bp+FLASHVARS.fpNextDestinationPage]
	repe cmpsb
	jnz		SHORT .ExitOnError

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
	les		di, [bp+FLASHVARS.fpNextDestinationPage]

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
	les		di, [bp+FLASHVARS.fpNextDestinationPage]
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
;		ES:DI:	Destination ptr.
;	Returns:
;		CF:		Set on error.
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
EraseSstPage:
	push	cx

	mov		BYTE [es:05555h], 0AAh	; Sector erase sequence.
	mov		BYTE [es:02AAAh], 055h
	mov		BYTE [es:05555h], 080h
	mov		BYTE [es:05555h], 0AAh
	mov		BYTE [es:02AAAh], 055h
	mov		BYTE [es:di], 030h

	mov		ax, 1163				; 1163 x ~215us = 250ms = 10x datasheet max
.TimeoutOuterLoop:
	mov		cx, [bp+FLASHVARS.wTimeoutCounter]
.TimeoutInnerLoop:
	cmp		BYTE [es:di], 0FFh		; Will return 0FFh when erase complete.
	jz		SHORT .Exit
	loop	.TimeoutInnerLoop
	dec		ax
	jnz		SHORT .TimeoutOuterLoop
	stc								; Timed out.
.Exit:
	pop		cx
	ret

;--------------------------------------------------------------------
; WriteSstPage
;	Parameters:
;		DS:SI:	Source ptr.
;		ES:DI:	Destination ptr.
;	Returns:
;		SI, DI:	Each advanced forward 1 page.
;		CF:		Set on error.
;	Corrupts registers:
;		AL, BX, DX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
WriteSstPage:
	push	cx

	mov		bx, [bp+FLASHVARS.wTimeoutCounter]
	mov		dx, [bp+FLASHVARS.wEepromPageSize]
	cli

.NextByte:
	lodsb
	mov		BYTE [es:05555h], 0AAh	; Byte program sequence.
	mov		BYTE [es:02AAAh], 055h
	mov		BYTE [es:05555h], 0A0h
	mov		[es:di], al

	mov		cx, bx
.WaitLoop:
	cmp		[es:di], al				; Device won't return actual data until 
	jz		SHORT .ByteFinished		; write complete. Timeout ~215us, or 
	loop	.WaitLoop				; ~10x 20us max program time from datasheet.

	stc								; Write timeout.
	jmp		SHORT .Exit

.ByteFinished:
	inc		di
	dec		dx
	jnz		SHORT .NextByte
	clc
.Exit:
	sti
	pop		cx
	ret
