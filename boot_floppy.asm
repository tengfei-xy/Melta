; create time: 2021/06/16 21:40
; update time: 2021/06/24 20:57
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

; FAT12 format
; Base_Of_Loader and Offset_Of_Loader are combined to form the starting physical address of the program.
; Base_Of_Loader << 4 + Offset_Of_Loader
Base_Of_Loader equ 0x1000
Offset_Of_Loader equ 0x00
; RootDirSectors define the number of sectors occupied by the root directory.
; RootDirSectors = ( BPB_RootEntCnt * 32 + BPB_BytesPerSec - 1 ) / BPB_BytesPerSec
RootDirSectors equ 14
; SectorNum_Of_RootDirStart define the start sector number of the root directory
; SectorNum_Of_RootDirStart = BPB_RsvdSecCnt + BPB_FATSz16 * BPB_NumFATs
SectorNum_Of_RootDirStart equ 19
; SectorNum_Of_FAT1Start define the start sectornumber of FAT1 table
SectorNum_Of_FAT1Start equ 1
; SectorBalance is The starting cluster number of a valid data area
; SectorBalance = SectorNum_Of_RootDirStart - 2
SectorBalance equ 17 

jmp short Label_Start
nop
BS_OEMName db 'Melta   '
BPB_BytesPerSec dw 512
BPB_SecPerClus db 1
BPB_RsvdSecCnt dw 1
BPB_NumFATs db 2
BPB_RootEntCnt dw 224
BPB_TotSec16 dw 2880
BPB_Media db 0xf0
BPB_FATSz16 dw 9
BPB_SecPerTrk dw 18
BPB_NumHeads dw 2
BPB_HiddSec dd 0
BPB_TotSec32 dd 0
BS_DrvNum db 0
BS_Reserved1 db 0
BS_BootSig db 0x29
BS_VolID dd 0
BS_VolLab db 'boot loader'
BS_FileSysType db 'FAT12   '

Label_Start:
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
    mov ecx, Startup_Log_Len
    mov ebp, Startup_Log
    int 10h

    ; search loader.bin
    mov word [SectorNo], SectorNum_Of_RootDirStart

; 存在的作用 除了表名下面这段代码的作用，还能跳转到这里
; 但上面的命令执行完后，会按顺序执行，标签不是函数
Lable_Search_In_RootDir_Begin:

    ; 第一次 RootDirSize_For_Loop = 14
    cmp word [RootDirSize_For_Loop], 0
    ; 当RootDirSize_For_Loop = 0时，找不到loder.bin
    jz Label_Display_No_LoaderBin
    ; 自减 1
    dec word [RootDirSize_For_Loop]

    mov ax, 00h
    mov es, ax

    ; 第一次是19
    mov ax, [SectorNo]
    mov bx,  6000h
    mov cl, 1
    call Func_ReadOneSector

    mov si, LoaderFile
    mov di,  6000h
    cld ;清除DF标志位
    ; 每个有扇区512/32=16d=10h个目录
    mov dx, 10h
    
Label_Search_For_LoaderBin:

    ; 如果是0，就跳到到下一个扇区
    ; 否则 
    cmp dx, 0
    jz Label_Goto_Next_Sector_In_RootDir
    dec dx     ;dx自减
    mov cx, 11 ;文件名长度=文件名+扩展名

Label_Cmp_FileName:

    ; cx=0时表示文件找到
    cmp cx, 0
    jz Label_FileNameFound
    dec cx

    ; 将DS:SI寄存器的地址送到AX寄存器
    lodsb
    cmp al, byte [es:di]
    jz Label_Go_On
    jmp Label_Different

Label_Go_On:
    
    inc di
    jmp Label_Cmp_FileName

Label_Different:

    and di, 0ffe0h
    add di, 20h
    mov si, LoaderFile
    jmp Label_Search_For_LoaderBin

Label_Goto_Next_Sector_In_RootDir:
    
    add word [SectorNo], 1
    jmp Lable_Search_In_RootDir_Begin
    
;======= display on screen : ERROR:No LOADER Found

Label_Display_No_LoaderBin:

    mov ax, 1301h
    mov bx, 008ch
    mov cx, NoLoaderMessage_Len
    mov dx, 0100h
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, NoLoaderMessage
    int 10h
    jmp $

;======= found loader.bin name in root director struct

Label_FileNameFound:

    mov ax, RootDirSectors
    and di, 0ffe0h
    add di, 01ah
    mov cx, word [es:di]
    push cx
    add cx, ax
    add cx, SectorBalance
    mov ax, Base_Of_Loader
    mov es, ax
    mov bx, Offset_Of_Loader
    mov ax, cx

Label_Go_On_Loading_File:
    push ax
    push bx
    mov ah, 0eh
    mov al, '.'
    mov bl, 0fh
    int 10h

    pop bx
    pop axkok
    mov cl, 1
    call Func_ReadOneSector
    
    pop ax
    call Func_GetFATEntry
    cmp ax, 0fffh
    jz Label_File_Loaded
    push ax
    mov dx, RootDirSectors
    add ax, dx
    add ax, SectorBalance
    add bx, [BPB_BytesPerSec]
    jmp Label_Go_On_Loading_File

Label_File_Loaded:
    
    jmp Base_Of_Loader:Offset_Of_Loader

;read one sector from floppy
Func_ReadOneSector:

    ; cl在接下来的除法运算中会被覆盖，所以先保存cl
    push bp
    mov bp, sp
    ; 开辟2个字节空间
    sub esp, 2
    ; cl将保存在bp-2的新开辟的栈空间中
    mov byte [bp - 2], cl

    Label_div:
        ; BPB_SecPerTrk = 18
        ; bx 在接下来的除法运算中会被覆盖，所以先保存bx
        push bx
        mov bl, [BPB_SecPerTrk]

        ; 除法运算:LBA扇区号(ax) / 每磁道扇区数(bl)
        div bl

        ; 余数处理
        inc ah      ; ah是余数
        mov cl, ah  ; cl起始扇区号由ah余数+1

        ; 商处理
        mov dh, al ; al是商
        shr al, 1   ; al偏移后赋值给ch
        mov ch, al ; ch柱面号>>1
        and dh, 1   ; dh磁头号&1
        pop bx  ; bx= 6000h 目标缓存区起始地址
                    ; 除法运算做完，需要原来的值
        mov dl, [BS_DrvNum]    ; dl是int 13h的驱动器号

    Label_Go_On_Reading:
        ; AH=02h中断只处理CHS格式
        mov ah, 2
        mov al, byte [bp - 2] ;[bp-2]是cl,扇区数
        int 13h
        ; 进位标志位置位则跳转，CF=1
        jc Label_Go_On_Reading

    ;归还2个字节·                     qa'w的空间，保持栈的平衡
    add esp, 2
    pop bp
    ret

; 找到loader.bin后，
; 根据FAT表项提供的簇号一次加载扇区数据到内存
Func_GetFATEntry:

    push es
    push bx
    push ax
    mov ax, 00
    mov es, ax
    pop ax
    mov byte [Odd], 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    cmp dx, 0
    jz Label_Even
    mov byte [Odd], 1

    Label_Even:

        xor dx, dx
        mov bx, [BPB_BytesPerSec]
        div bx
        push dx

        ; 调用Func_ReadOneSector完成读取一个扇区需要
        ; es:bx 目标缓存区起始地址
        ; ax 待读取的磁盘起始扇区号
        ; cl 读取的扇区号 
        mov bx,  6000h
        add ax, SectorNum_Of_FAT1Start
        mov cl, 2
        call Func_ReadOneSector
        
        pop dx
        add bx, dx
        mov ax, [es:bx]
        cmp byte [Odd], 1
        jnz Label_Even_2
        shr ax, 4

    Label_Even_2:
        and ax, 0fffh
        pop bx
        pop es
    ret
;======= tmp variable
 
RootDirSize_For_Loop dw RootDirSectors
SectorNo  dw 0
Odd   db 0

NoLoaderMessage:        DB "No Loader File Found!",0
NoLoaderMessage_Len:    EQU ($-NoLoaderMessage)
LoaderFile:             DB "LOADER  BIN",0
LoaderFile_Len:         EQU ($-LoaderFile)
Startup_Log:            DB "Starting Melta...",0

; fill in to floppy
times 510 - ($ - $$) db 0
dw 0xaa55