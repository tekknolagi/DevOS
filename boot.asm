org 0x7C00
bits 16

jmp start

hang: jmp hang

Reset1:
	; If it takes more than 20 tries to reset floppy, assume failure:
	; This will be stored 
	mov cx, 0x00
	push cx

Reset:
	pop cx
	pop dx
	cmp cx, 0x0014
	je ReadErr
	push cx
	
	mov ah, 0x0E
	mov al, '.'
	mov bx, 0x000F
	int 0x10
	
	mov ah, 0x00
	int 0x13
	
	pop cx
	inc cx
	push dx
	push cx
	jc Reset
	
	pop cx
	
	; If it takes more than 20 tries to read sector, assume failure:
	; This will be stored 
	mov cx, 0x00
	push cx
	
	mov si, CRLF
	call Print
	mov si, ProgMSG
	call Print

Read_Sector:
	pop cx ; Fetch the no. tries off the stack
	pop dx ; Fetch the drive no. off the stack too (for int 0x13)
	cmp cx, 0x0014
	je ReadErr ; If 20 tries, problem
	push cx ; Put back the value so we don't lose it
	
	mov ah, 0x0E
	mov al, '.'
	mov bx, 0x000F
	int 0x10
	
	; We want to jump to 0x0800:0000, so with ES:BX
	; we need this:
	mov ax, 0x0800
	push es
	mov es, ax
	xor bx, bx   ; Quick-set bx to 0
	
	mov ah, 0x02 ; We're reading sectors
	mov al, 0x01 ; We want to load 1 sector
	mov ch, 0x00 ; Track 0
	mov cl, 0x02 ; Second sector
	mov dh, 0x00 ; Head 0
	
	int 0x13
	jnc Success
	
	pop es       ; es is on top of cx, so pop it off (we don't need it)
	pop cx       ; Get back the no. tries
	inc cx       ; No. tries has increased
	push dx      ; dx needs to be on the bottom of the stack
	push cx      ; cx needs to be on the top of the stack
	jmp Read_Sector
	
Success:
	pop es
	mov si, CRLF
	call Print
	mov si, SuccMSG ; mov success msg into si
	call Print
	
	mov bx, [0x81FF] ; All DevOS bootable sectors must end
	cmp bx, 0xAA     ; with 0xAA
	jne InvErr
	
	jmp 0x0800:0000 ; jump to the location of loaded sector and execute

ResetErr:
	mov si, CRLF
	call Print
	mov si, ResetErrMSG
	call Print
	
	mov ah, 0x0
	int 0x16
	
	int 0x18
	jmp hang

ReadErr:
	mov si, CRLF       ; There won't be a CR/LF after the dots
	call Print
	mov si, ReadErrMSG ; mov the error msg into si
	call Print
	
	mov ah, 0x0        ; Wait for user input
	int 0x16
	
	int 0x18           ; Execute BASIC in ROM
	jmp hang

InvErr:
	mov si, CRLF
	call Print
	mov si, InvErrMSG
	call Print
	
	mov ah, 0x0        ; Wait for user input
	int 0x16
	
	int 0x18
	jmp hang

Print:
	lodsb
	or al, al
	jz printdone
	mov ah, 0x0E
	int 0x10
	jmp Print

printdone: ret

setvideomode:
	mov ah, 0x00
	mov al, 0x13
	int 0x10

start:
	xor ax, ax
	mov ds, ax
	mov es, ax
	
	cli
	mov ss, ax      ; Stack starts at segment 0x0 (relative to 0x7C00)
	mov sp, 0x9C00  ; Offset 0x9C00 (SS:SP)
	sti
	
	push dx
	
	mov si, ResetMSG
	call Print
	
	jmp Reset1
	
ResetMSG db "Resetting floppy", 0
ResetErrMSG db "HANG: Error resetting floppy!", 0x0D, 0x0A, 0
ReadErrMSG db "HANG: Error reading sectors!", 0x0D, 0x0A, 0
InvErrMSG db "HANG: Invalid code at Sector 2!", 0x0D, 0x0A, 0
SuccMSG db "Loading stage2 kernel...", 0x0D, 0x0A, 0
ProgMSG db "Reading sectors", 0
CRLF db 0x0D, 0x0A, 0

times 510-($-$$) db 0
dw 0xAA55
