; Project name	:	Assembly Library
; Description	:	Menu loop for waiting keystrokes.

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; MenuLoop_Enter
;	Parameters
;		SS:BP:	Ptr to MENU
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX, SI, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
MenuLoop_Enter:
	call	KeystrokeProcessing
	call	TimeoutProcessing
%ifdef MENUEVENT_IDLEPROCESSING_ENABLE
	call	MenuEvent_IdleProcessing	; User idle processing
%endif
	test	BYTE [bp+MENU.bFlags], FLG_MENU_EXIT
	jz		SHORT MenuLoop_Enter
	ret


;--------------------------------------------------------------------
; KeystrokeProcessing
; TimeoutProcessing
;	Parameters
;		SS:BP:	Ptr to MENU
;	Returns:
;		Nothing
;	Corrupts registers:
;		All, except SS:BP
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
KeystrokeProcessing:
	call	Keyboard_GetKeystrokeToAX
	jnz		SHORT ProcessKeystrokeFromAX
NoKeystrokeToProcess:
	ret

ALIGN JUMP_ALIGN
TimeoutProcessing:
	call	MenuTime_UpdateSelectionTimeout
	jnc		NoKeystrokeToProcess
	mov		al, CR	; Fake ENTER to select item
	; Fall to ProcessKeystrokeFromAX


;--------------------------------------------------------------------
; ProcessKeystrokeFromAX
;	Parameters
;		AL:		ASCII character
;		AH:		BIOS scan code
;		SS:BP:	Ptr to MENU
;	Returns:
;		Nothing
;	Corrupts registers:
;		AX, BX, CX, DX, SI, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
ProcessKeystrokeFromAX:
	xchg	cx, ax
	call	MenuTime_StopSelectionTimeout
	xchg	ax, cx
	call	.ProcessMenuSystemKeystrokeFromAX
	jc		SHORT NoKeystrokeToProcess
	jmp		MenuEvent_KeyStrokeInAX

;--------------------------------------------------------------------
; .ProcessMenuSystemKeystrokeFromAX
;	Parameters
;		AL:		ASCII character
;		AH:		BIOS scan code
;		SS:BP:	Ptr to MENU
;	Returns:
;		CF:		Set if keystroke processed
;				Cleared if keystroke not processed
;		AL:		ASCII character (if CF cleared)
;		AH:		BIOS scan code (if CF cleared)
;	Corrupts registers:
;		BX, CX, DX, SI, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
.ProcessMenuSystemKeystrokeFromAX:
	cmp		al, ESC
	je		SHORT .LeaveMenuWithoutSelectingItem
	cmp		al, CR
	je		SHORT .SelectItem

	test	BYTE [bp+MENU.bFlags], FLG_MENU_USER_HANDLES_SCROLLING
	jz		SHORT MenuLoop_ProcessScrollingKeysFromAX
	ret		; Return with CF cleared since keystroke not processed

ALIGN JUMP_ALIGN
.LeaveMenuWithoutSelectingItem:
	call	MenuEvent_ExitMenu
	jnc		SHORT .CancelMenuExit
	call	MenuInit_CloseMenuWindow
	mov		WORD [bp+MENUINIT.wHighlightedItem], NO_ITEM_HIGHLIGHTED
.CancelMenuExit:
	stc
	ret

ALIGN JUMP_ALIGN
.SelectItem:
	mov		cx, [bp+MENUINIT.wHighlightedItem]
	call	MenuEvent_ItemSelectedFromCX
	stc
	ret


;--------------------------------------------------------------------
; MenuLoop_ProcessScrollingKeysFromAX
;	Parameters
;		AL:		ASCII character
;		AH:		BIOS scan code
;		SS:BP:	Ptr to MENU
;	Returns:
;		CF:		Set if keystroke processed
;				Cleared if keystroke not processed
;		AL:		ASCII character (if CF cleared)
;		AH:		BIOS scan code (if CF cleared)
;	Corrupts registers:
;		BX, CX, DX, SI, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
MenuLoop_ProcessScrollingKeysFromAX:
	xchg	ah, al
	cmp		al, MENU_KEY_PGUP
	je		SHORT .ChangeToPreviousPage
	cmp		al, MENU_KEY_PGDN
	je		SHORT .ChangeToNextPage
	cmp		al, MENU_KEY_HOME
	je		SHORT .SelectFirstItem
	cmp		al, MENU_KEY_END
	je		SHORT .SelectLastItem

	cmp		al, MENU_KEY_UP
	je		SHORT .DecrementSelectedItem
	cmp		al, MENU_KEY_DOWN
	je		SHORT .IncrementSelectedItem
	clc		; Clear CF since keystroke not processed
	xchg	ah, al
	ret

ALIGN JUMP_ALIGN
.ChangeToPreviousPage:
	call	MenuScrollbars_GetMaxVisibleItemsOnPageToCX
	xchg	ax, cx
	neg		ax
	mov		cx, [bp+MENUINIT.wHighlightedItem]
	add		cx, ax
	jge		SHORT .MoveHighlightedItemByAX	; No rotation for PgUp
	; Fall to .SelectFirstItem
ALIGN JUMP_ALIGN
.SelectFirstItem:
	mov		ax, [bp+MENUINIT.wHighlightedItem]
	neg		ax
	jmp		SHORT .MoveHighlightedItemByAX

ALIGN JUMP_ALIGN
.ChangeToNextPage:
	call	MenuScrollbars_GetMaxVisibleItemsOnPageToCX
	xchg	ax, cx
	mov		cx, [bp+MENUINIT.wHighlightedItem]
	add		cx, ax
	cmp		cx, [bp+MENUINIT.wItems]
	jb		SHORT .MoveHighlightedItemByAX	; No rotation for PgDn
	; Fall to .SelectLastItem
ALIGN JUMP_ALIGN
.SelectLastItem:
	stc
	mov		ax, [bp+MENUINIT.wItems]
	sbb		ax, [bp+MENUINIT.wHighlightedItem]
	jmp		SHORT .MoveHighlightedItemByAX

ALIGN JUMP_ALIGN
.DecrementSelectedItem:
	mov		ax, -1
	SKIP2B	cx	; mov cx, <next instruction>
.IncrementSelectedItem:
	mov		al, 1	; AH is already 0
ALIGN JUMP_ALIGN
.MoveHighlightedItemByAX:
	call	MenuScrollbars_MoveHighlightedItemByAX
	stc
	ret
