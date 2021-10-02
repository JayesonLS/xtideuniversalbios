; Project name	:	XTIDE Universal BIOS Configurator v2
; Description	:	Functions for flashing SST flash devices.

;
; Created by Jayeson Lee-Steere
; Hereby placed into the public domain.
;

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Flash_SstWithFlashvarsInDSSI
;	Parameters:
;		DS:SI:	Ptr to FLASHVARS
;	Returns:
;		FLASHVARS.flashResult
;	Corrupts registers:
;		All, including segments
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Flash_SstWithFlashvarsInDSSI:
	mov		bp, si									; Flashvars now in SS:BP
	mov		cx, 1 ; TODO
ALIGN JUMP_ALIGN
.FlashNextPage:

; TODO:

	loop	.FlashNextPage
%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
%if FLASH_RESULT.success = 0	; Just in case this should ever change
	mov		[bp+FLASHVARS.flashResult], cl
%else
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.success
%endif
%endif
	ret

.DeviceDetectionError:
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.DeviceNotDetected
	ret
.PollingError:
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.PollingTimeoutError
	ret
.DataVerifyError:
	mov		BYTE [bp+FLASHVARS.flashResult], FLASH_RESULT.DataVerifyError
	ret



