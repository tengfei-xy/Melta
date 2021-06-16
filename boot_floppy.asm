; create time: 2021/06/16 21:40
; update time: 2021/06/16 00:37
; author: taotengfei
; github: https://github.com/tengfei-xy/Melta
;
; module: boot
; introduction:The file is Melta's system from floppy boot code.
; usage:
; nasm -o boot_floppy.bin boot_floppy.asm
; dd if=boot_floppy.bin of=other/boot_floppy.img bs=512 count=1 conv=notrunc
; qemu-system-x86_64 -drive file=other/boot_floppy.img,index=0,format=raw,if=floppy

; set orgin address
org 0x7c00

; clear screen
mov eax, 0600h
mov ebx, 0000h
mov ecx, 0000h
mov edx, 0184fh
int 10h

; mouse force
mov eax, 0200h
mov ebx, 0000h
mov edx, 0000h
int 10h

; show startup log
mov eax, 1301h
mov ebx, 000fh
mov edx, 0000h
mov ecx, STARTUP_LOG_LEN
mov ebp, STARTUP_LOG
int 10h

; sleep
jmp $

; val
STARTUP_LOG: DB "Starting Melta...",0
STARTUP_LOG_LEN: EQU ($-STARTUP_LOG)

; fill in to floppy
times	510 - ($ - $$)	db	0
dw	0xaa55