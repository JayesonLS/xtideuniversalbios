; Project name	:	XTIDE Universal BIOS
; Description	:	Displays Boot Menu.

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Displays Boot Menu and returns Drive or Function number.
;
; BootMenu_DisplayAndReturnSelection
;	Parameters:
;		DS:		RAMVARS segment
;	Returns:
;		DX:		Untranslated drive number to be used for booting (if CF cleared)
;				Function number (if CF set)
;		CF:		Cleared if drive selected
;				Set if function selected
;	Corrupts registers:
;		All General Purpose Registers
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenu_DisplayAndReturnSelection:
	call	DriveXlate_Reset
	call	BootMenuPrint_TheBottomOfScreen
	call	BootMenu_Enter			; Get selected menuitem index to CX
	call	BootMenuPrint_ClearScreen
	cmp		cx, BYTE NO_ITEM_SELECTED
	je		SHORT BootMenu_DisplayAndReturnSelection
	jmp		SHORT BootMenu_ConvertMenuitemFromCXtoDriveInDX


;--------------------------------------------------------------------
; Enters Boot Menu or submenu.
;
; BootMenu_Enter
;	Parameters:
;		Nothing
;	Returns:
;		CX:		Index of selected item or NO_ITEM_SELECTED
;	Corrupts registers:
;		BX, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenu_Enter:
	mov		bx, BootMenuEvent_Handler
	CALL_MENU_LIBRARY DisplayWithHandlerInBXandUserDataInDXAX
	xchg	cx, ax
	ret


;--------------------------------------------------------------------
; Returns number of menuitems in Boot Menu.
;
; BootMenu_GetMenuitemCountToCX
;	Parameters:
;		DS:		RAMVARS segment
;	Returns:
;		CX:		Number of boot menu items
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenu_GetMenuitemCountToCX:
	call	RamVars_GetHardDiskCountFromBDAtoCX
	xchg	ax, cx
	call	FloppyDrive_GetCount
	add		ax, cx
	ret


;--------------------------------------------------------------------
; BootMenu_GetHeightToALwithItemCountInCL
;	Parameters:
;		CL:		Number of menuitems
;	Returns:
;		AH:		Boot menu height
;	Corrupts registers:
;		AL, CL, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenu_GetHeightToAHwithItemCountInCL:
	add		cl, BOOT_MENU_HEIGHT_WITHOUT_ITEMS
	CALL_DISPLAY_LIBRARY GetColumnsToALandRowsToAH
	MIN_U	ah, cl
	ret


;--------------------------------------------------------------------
; BootMenu_ConvertAsciiHotkeyFromALtoMenuitemInCX
;	Parameters:
;		AL:		ASCII hotkey starting from upper case 'A'
;	Returns:
;		CX:		Menuitem index
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenu_ConvertAsciiHotkeyFromALtoMenuitemInCX:
	call	BootMenu_GetLetterForFirstHardDiskToCL
	cmp		al, cl						; Letter is for Hard Disk?
	jae		SHORT .StartFromHardDiskLetter
	sub		al, 'A'						; Letter to Floppy Drive menuitem
	xchg	ax, cx						; Menuitem index to CX
	ret
ALIGN JUMP_ALIGN
.StartFromHardDiskLetter:
	sub		al, cl						; Hard Disk index
	call	FloppyDrive_GetCount
	add		cx, ax						; Menuitem index
	ret

;--------------------------------------------------------------------
; Returns letter for first hard disk. Usually it will be 'c' but it
; can be higher if more than two floppy drives are found.
;
; BootMenu_GetLetterForFirstHardDiskToCL
;	Parameters:
;		Nothing
;	Returns:
;		CL:		Upper case letter for first hard disk
;	Corrupts registers:
;		CH
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenu_GetLetterForFirstHardDiskToCL:
	call	FloppyDrive_GetCount
	add		cl, 'A'
	MAX_U	cl, 'C'
	ret


;--------------------------------------------------------------------
; BootMenu_ConvertMenuitemFromCXtoDriveInDX
;	Parameters:
;		CX:		Index of menuitem selected from Boot Menu
;		DS:		RAMVARS segment
;	Returns:
;		DX:		Drive number to be used for booting
;	Corrupts registers:
;		CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenu_ConvertMenuitemFromCXtoDriveInDX:
	mov		dx, cx					; Copy menuitem index to DX
	call	FloppyDrive_GetCount
	cmp		dx, cx					; Floppy drive?
	jb		SHORT .ReturnFloppyDriveInDX
	sub		dx, cx					; Remove floppy drives from index
	or		dl, 80h
.ReturnFloppyDriveInDX:
	ret


;--------------------------------------------------------------------
; Converts Floppy or Hard Disk Drive number to menuitem index.
; This function does not check does the drive really exists.
;
; BootMenu_ConvertDriveToMenuitem
;	Parameters:
;		DL:		Drive number
;	Returns:
;		CX:		Menuitem index (assuming drive is available)
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenu_ConvertDriveToMenuitem:
	test	dl, 80h					; Floppy drive?
	jz		SHORT .ReturnFloppyMenuitem
	call	FloppyDrive_GetCount
	mov		ax, 7Fh					; Load mask to clear floppy bit
	and		ax, dx					; AX = Hard Disk index
	add		cx, ax					; Add hard disk index to floppy drive count
	ret
ALIGN JUMP_ALIGN
.ReturnFloppyMenuitem:
	eMOVZX	cx, dl					; Drive number and item index are equal
	ret


;--------------------------------------------------------------------
; Checks is drive number valid for this system.
;
; BootMenu_IsDriveInSystem
;	Parameters:
;		DL:		Drive number
;		DS:		RAMVARS segment
;	Returns:
;		CF:		Set if drive number is valid
;				Clear if drive is not present in system
;	Corrupts registers:
;		AX, CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
BootMenu_IsDriveInSystem:
	test	dl, 80h								; Floppy drive?
	jz		SHORT .IsFloppyDriveIsInSystem
	call	RamVars_GetHardDiskCountFromBDAtoCX	; Hard Disk count to CX
	or		cl, 80h								; Set Hard Disk bit to CX
	jmp		SHORT .CompareDriveNumberToDriveCount
.IsFloppyDriveIsInSystem:
	call	FloppyDrive_GetCount				; Floppy Drive count to CX
.CompareDriveNumberToDriveCount:
	cmp		dl, cl
	ret
