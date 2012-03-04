; Project name	:	XTIDE Universal BIOS
; Description	:	Functions for detecting drive for the BIOS.

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Detects all IDE hard disks to be controlled by this BIOS.
;
; DetectDrives_FromAllIDEControllers
;	Parameters:
;		DS:		RAMVARS segment
;		ES:		BDA segment (zero)
;	Returns:
;		Nothing
;	Corrupts registers:
;		All (not segments)
;--------------------------------------------------------------------
DetectDrives_FromAllIDEControllers:
	call	RamVars_GetIdeControllerCountToCX
	mov		bp, ROMVARS.ideVars0			; CS:BP now points to first IDEVARS

.DriveDetectLoop:							; Loop through IDEVARS
	push	cx

	mov		cx, g_szDetectMaster
	mov		bh, MASK_DRVNHEAD_SET								; Select Master drive
	call	StartDetectionWithDriveSelectByteInBHandStringInCX	; Detect and create DPT + BOOTNFO

	mov		cx, g_szDetectSlave
	mov		bh, MASK_DRVNHEAD_SET | FLG_DRVNHEAD_DRV
	call	StartDetectionWithDriveSelectByteInBHandStringInCX

	pop		cx

	add		bp, BYTE IDEVARS_size			; Point to next IDEVARS

%ifdef MODULE_SERIAL
	jcxz	.AddHardDisks					; Set to zero on .ideVarsSerialAuto iteration (if any)
%endif

	loop	.DriveDetectLoop

%ifdef MODULE_SERIAL
;----------------------------------------------------------------------
;
; if serial drive detected, do not scan (avoids duplicate drives and isn't needed - we already have a connection)
;
	call	FindDPT_ToDSDIforSerialDevice
	jnc		.AddHardDisks

	mov		bp, ROMVARS.ideVarsSerialAuto	; Point to our special IDEVARS structure, just for serial scans

	mov		al,[cs:ROMVARS.wFlags]			; Configurator set to always scan?
	or		al,[es:BDA.bKBFlgs1]			; Or, did the user hold down the ALT key?
	and		al,8							; 8 = alt key depressed, same as FLG_ROMVARS_SERIAL_ALWAYSDETECT
	jnz		.DriveDetectLoop
%endif

.AddHardDisks:
;----------------------------------------------------------------------
;
; Add in hard disks to BDA, finalize our Count and First variables
;
; Note that we perform the add to bHDCount and store bFirstDrv even if the count is zero.
; This is done because we use the value of .bFirstDrv to know how many drives were in the system
; at the time of boot, and to return that number on int13h/8h calls.  Because the count is zero,
; FindDPT_ForDriveNumber will not find any drives that are ours.
;
	mov		cx, [RAMVARS.wDrvCntAndFlopCnt]		; Our count of hard disks

	mov		al, [es:BDA.bHDCount]
	add		cl, al						; Add our drives to the system count
	mov		[es:BDA.bHDCount], cl
	or		al, 80h						; Or in hard disk flag
	mov		[RAMVARS.bFirstDrv], al		; Store first drive number

.AddFloppies:
%ifdef MODULE_SERIAL_FLOPPY
;----------------------------------------------------------------------
;
; Add in any emulated serial floppy drives, finalize our packed Count and First variables
;
	dec		ch
	mov		al, ch
	js		.NoFloppies						; if no drives are present, we store 0ffh

	call	FloppyDrive_GetCountFromBIOS_or_BDA

	push	ax

	add		al, ch							; Add our drives to existing drive count
	cmp		al, 3							; For BDA, max out at 4 drives (ours is zero based)
	jb		.MaxBDAFloppiesExceeded
	mov		al, 3
.MaxBDAFloppiesExceeded:
	eROR_IM	al, 2							; move to bits 6-7
	inc		ax								; low order bit, indicating floppy drive exists

	mov		ah, [es:BDA.wEquipment]			; Load Equipment WORD low byte
	and		ah, 03eh						; Mask off drive number and drives present bit
	or		al, ah							; Or in new values
	mov		[es:BDA.wEquipment], al			; and store

	mov		al, 1eh							; BDA pointer to Floppy DPT
	mov		si, AH8h_FloppyDPT
	call	Interrupts_InstallHandlerToVectorInALFromCSSI

	pop		ax

	shr		ch, 1							; number of drives, 1 or 2 only, to CF flag (clear=1, set=2)
	rcl		al, 1							; starting drive number in upper 7 bits, number of drives in low bit
.NoFloppies:
	mov		[RAMVARS.xlateVars+XLATEVARS.bFlopCntAndFirst], al
%endif

	ret

%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS
	%if FLG_ROMVARS_SERIAL_SCANDETECT != 8
		%error "DetectDrives is currently coded to assume that FLG_ROMVARS_SERIAL_SCANDETECT is the same bit as the ALT key code in the BDA.  Changes in the code will be needed if these values are no longer the same."
	%endif
%endif


;--------------------------------------------------------------------
; StartDetectionWithDriveSelectByteInBHandStringInCX
;	Parameters:
;		BH:		Drive Select byte for Drive and Head Register
;		CX:		Offset to "Master" or "Slave" string
;		CS:BP:	Ptr to IDEVARS for the drive
;		DS:		RAMVARS segment
;		ES:		Zero (BDA segment)
;	Returns:
;       None
;	Corrupts registers:
;		AX, BX, CX, DX, SI, DI
;--------------------------------------------------------------------
StartDetectionWithDriveSelectByteInBHandStringInCX:
	call	DetectPrint_StartDetectWithMasterOrSlaveStringInCXandIdeVarsInCSBP
	; Fall to .ReadAtaInfoFromHardDisk

;--------------------------------------------------------------------
; .ReadAtaInfoFromHardDisk
;	Parameters:
;		BH:		Drive Select byte for Drive and Head Register
;		CS:BP:	Ptr to IDEVARS for the drive
;		DS:		RAMVARS segment
;		ES:		Zero (BDA segment)
;	Returns:
;		CF:		Cleared if ATA-information read successfully
;				Set if any error
;	Corrupts registers:
;		AX, BL, CX, DX, SI, DI
;--------------------------------------------------------------------
.ReadAtaInfoFromHardDisk:
	mov		si, BOOTVARS.rgbAtaInfo		; ES:SI now points to ATA info location
	push	es
	push	si
	push	bx
	call	Device_IdentifyToBufferInESSIwithDriveSelectByteInBH
	pop		bx
	pop		si
	pop		es
	jnc		SHORT CreateBiosTablesForHardDisk
	; Fall to .ReadAtapiInfoFromDrive

.ReadAtapiInfoFromDrive:				; Not yet implemented
	;call	ReadAtapiInfoFromDrive		; Assume CD-ROM
	;jnc	SHORT _CreateBiosTablesForCDROM

	;jmp	short DetectDrives_DriveNotFound
;;; fall-through instead of previous jmp instruction
;--------------------------------------------------------------------
; DetectDrives_DriveNotFound
;	Parameters:
;		Nothing
;	Returns:
;		CF:     Set (from BootMenuPrint_NullTerminatedStringFromCSSIandSetCF)
;	Corrupts registers:
;		AX, SI
;--------------------------------------------------------------------
DetectDrives_DriveNotFound:
	mov		si, g_szNotFound
	jmp		BootMenuPrint_NullTerminatedStringFromCSSIandSetCF


;--------------------------------------------------------------------
; CreateBiosTablesForHardDisk
;	Parameters:
;		BH:		Drive Select byte for Drive and Head Register
;		CS:BP:	Ptr to IDEVARS for the drive
;		ES:SI	Ptr to ATA information for the drive
;		DS:		RAMVARS segment
;		ES:		BDA/Bootnfo segment
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX, SI, DI
;--------------------------------------------------------------------
CreateBiosTablesForHardDisk:
	call	CreateDPT_FromAtaInformation
	jc		SHORT DetectDrives_DriveNotFound
	call	BootMenuInfo_CreateForHardDisk
	jmp		short DetectPrint_DriveNameFromBootnfoInESBX


