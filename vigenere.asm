.model large
.stack 20h
exit_dos MACRO
	MOV AX, 4c00h
	INT 21h
ENDM

close_file MACRO handle
    xor AX, AX
    mov AH, 3Eh ;file close function code
    mov BX, handle ;load handler into BX
    int 21h ;call interrupt
ENDM

.data
    psp_seg dw 0
    keyFileName db 32 dup(0)        
    inputFileName db 32 dup(0)     
    outputFileName db 32 dup(0) 
    is_decryption DB 1 ;0 for encryption, 1 for decryption

    keySize dw ?                       
    chunkSize dw ?                     
    inputFileHandle dw ?              
    outputFileHandle dw ?              

    keyBuffer db 64 dup(?)           
    chunkBuffer db 64 dup(?)          

.code
start:
    mov dx, ds
    mov ax, @data
    mov ds, ax
    mov psp_seg, dx

    call parse_args
    cmp ax, 1
    jne skip_endProcessing1
    jmp endProcessing
skip_endProcessing1:
    lea ax, keyFileName
    push ax                ; pointer to file name
    lea ax, keyBuffer
    push ax                ; pointer to buffer
    mov ax, 64
    push ax                ; max buffer size
    call loadKeyFile
    cmp ax, 0
    jne skip_endProcessing2
    jmp endProcessing
skip_endProcessing2:
    mov keySize, ax

    ; open input file for reading
    lea ax, inputFileName
    push ax
    call openFileForRead
    cmp ax, 0FFFFh
    jne skip_endProcessing3
    jmp endProcessing
skip_endProcessing3:
    mov inputFileHandle, ax

    ; create output file for writing
    lea ax, outputFileName
    push ax
    call createFileForWrite
    cmp ax, 0FFFFh
    jne skip_closeInputAndExit
    jmp closeInputAndExit
skip_closeInputAndExit:
    mov outputFileHandle, ax

processChunks:
    ; read a chunk from the input file
    lea ax, chunkBuffer
    push ax                ; buffer offset
    mov ax, inputFileHandle
    push ax                ; file handle
    mov ax, keySize
    push ax                ; chunk size
    call readChunk
    mov chunkSize, ax
    cmp ax, 0
    jne skip_doneProcessing
    jmp doneProcessing
skip_doneProcessing:

    cmp AX, keySize
    je vig_start ;if the same size was read
    mov keySize, AX ;else, update size of key
    ;Encode/decode the chunk using Vigenère cipher
vig_start:
        ;clear registers and prepare loop
        mov CX, keySize
        xor SI, SI
        xor DI, DI
        xor BX, BX
vig_loop:
;A = 65
    mov AL, chunkBuffer[SI]     ;load byte from input buffer
    mov AH, keyBuffer[DI] ;load key byte
    ;vigenere logic
    sub AL, 65 ;subtract to get index
    sub AH, 65
    push AX
    cmp is_decryption, 0
    je do_encryption
    
    call PrepDecryption
    jmp modulo_computation

do_encryption:
    call PrepEncryption

modulo_computation:
    mov BH, AL ;get result from addition or subtraction
    push BX
    call ModuloWith26
    add AL, 65 ;add back to ascii
    mov chunkBuffer[SI], AL  ;store result into chunkBuffer
    inc SI
    inc DI
    loop vig_loop

    ; write the chunk to the output file
    lea ax, chunkBuffer
    push ax                ; buffer offset
    mov ax, outputFileHandle
    push ax                ; file handle
    mov ax, chunkSize
    push ax                ; chunk size
    call writeChunk

    jmp processChunks
doneProcessing:
    ; close input file
    mov bx, inputFileHandle
    close_file bx
    ; close output file
    mov bx, outputFileHandle
    close_file bx
    jmp endProcessing

closeInputAndExit:
    mov bx, inputFileHandle
    close_file bx

endProcessing:
    exit_dos

; load the key file into memory
; in: [bp+8]=pointer to file name, [bp+6]=pointer to buffer, [bp+4]=max buffer size
; out: AX = number of bytes read
loadKeyFile proc near
    push bp
    mov bp, sp

    mov ah, 3Dh
    xor al, al
    mov dx, [bp+8]
    int 21h
    jc fileKeyError
    mov bx, ax

    mov ax, 3F00h
    mov cx, [bp+4]
    mov dx, [bp+6]
    int 21h
    jc fileKeyError
    push ax

    mov ax, 3E00h
    int 21h
    pop ax
    jmp fileKeyDone

fileKeyError:
    mov ax, 0

fileKeyDone:
    pop bp
    ret 6
loadKeyFile endp

; open a file for reading
; in: [bp+4]=pointer to file name
; out: AX = file handle or 0FFFFh on error
openFileForRead proc near
    push bp
    mov bp, sp
    mov ax, 3D00h
    mov dx, [bp+4]
    int 21h
    jc openReadError
    jmp openReadDone

openReadError:
    mov ax, 0FFFFh
openReadDone:
    pop bp
    ret 2
openFileForRead endp

; create a file for writing
; in: [bp+4]=pointer to file name
; out: AX = file handle or 0FFFFh on error
createFileForWrite proc near
    push bp
    mov bp, sp
    mov ah, 3Ch
    xor cx, cx
    mov dx, [bp+4]
    int 21h
    jc createWriteError
    jmp createWriteDone

createWriteError:
    mov ax, 0FFFFh
createWriteDone:
    pop bp
    ret 2
createFileForWrite endp

; read a chunk from a file
; in: [bp+8]=buffer, [bp+6]=file handle, [bp+4]=chunk size
; out: AX = number of bytes read
readChunk proc near
    push bp
    mov bp, sp
    mov bx, [bp+6]
    mov dx, [bp+8]
    mov cx, [bp+4]
    mov ax, 3F00h
    int 21h
    jc readError
    pop bp
    ret 6
readError:
    mov ax, 0
    pop bp
    ret 6
readChunk endp

; write a chunk to a file
; in: [bp+8]=buffer offset, [bp+6]=file handle, [bp+4]=chunk size
writeChunk proc near
    push bp
    mov bp, sp
    mov cx, [bp+4]
    mov dx, [bp+8]
    mov bx, [bp+6]
    mov ax, 4000h
    int 21h

    pop bp
    ret 8
writeChunk endp

; parse command line arguments
; out: keyFileName = arg1, inputFileName = arg2, outputFileName = arg3, is_decryption = arg4 (E/D)
; AX = 0 if args found, 1 if not enough args or invalid mode
parse_args proc near
    mov es, word ptr psp_seg

    xor cx, cx
    mov cl, es:[80h]
    cmp cl, 0
    jne skip_no_args
    jmp no_args
skip_no_args:

    mov si, 81h

skip_leading:
    mov al, es:[si]
    cmp al, ' '
    jne start_arg1
    inc si
    loop skip_leading
    jmp no_args

start_arg1:
    mov di, offset keyFileName
parse_arg1:
    mov al, es:[si]
    cmp al, 0Dh     ; Carriage return
    jne skip_end_of_line1
    jmp end_of_line
skip_end_of_line1:
    cmp al, ' '
    je arg1_done
    mov [di], al
    inc di
    inc si
    loop parse_arg1
    jmp end_of_line

arg1_done:
    mov byte ptr [di], 0

skip_spaces1:
    mov al, es:[si]
    cmp al, ' '
    jne start_arg2
    inc si
    loop skip_spaces1
    jmp end_of_line

start_arg2:
    mov di, offset inputFileName
parse_arg2:
    mov al, es:[si]
    cmp al, 0Dh     ; Carriage return
    jne skip_end_of_line2
    jmp end_of_line
skip_end_of_line2:
    cmp al, ' '
    je arg2_done
    mov [di], al
    inc di
    inc si
    loop parse_arg2
    jmp end_of_line

arg2_done:
    mov byte ptr [di], 0

skip_spaces2:
    mov al, es:[si]
    cmp al, ' '
    jne start_arg3
    inc si
    loop skip_spaces2
    jmp end_of_line

start_arg3:
    mov di, offset outputFileName
parse_arg3:
    mov al, es:[si]
    cmp al, 0Dh     ; Carriage return
    jne skip_end_of_line3
    jmp end_of_line
skip_end_of_line3:
    cmp al, ' '
    je arg3_done
    mov [di], al
    inc di
    inc si
    loop parse_arg3

arg3_done:
    mov byte ptr [di], 0

skip_spaces3:
    mov al, es:[si]
    cmp al, ' '
    jne start_arg4
    inc si
    loop skip_spaces3
    jmp end_of_line

start_arg4:
    mov al, es:[si]
    cmp al, 0Dh
    jne skip_end_of_line4
    jmp end_of_line
skip_end_of_line4:
    ; Accept only one char for mode
    cmp al, 'E'
    je set_encrypt
    cmp al, 'e'
    je set_encrypt
    cmp al, 'D'
    je set_decrypt
    cmp al, 'd'
    je set_decrypt
    jmp end_of_line

set_encrypt:
    mov byte ptr [is_decryption], 0
    mov ax, 0
    ret 0

set_decrypt:
    mov byte ptr [is_decryption], 1
    mov ax, 0
    ret 0

end_of_line:
    mov ax, 1
    ret 0

no_args:
    mov byte ptr [keyFileName], 0
    mov byte ptr [inputFileName], 0
    mov byte ptr [outputFileName], 0
    mov ax, 1
    ret 0
parse_args endp

PrepEncryption proc near ;PrepEncryption(char a, char b) returns addition_result
    push BP
    mov BP, SP
    ;stack: BP, IP, a, b
    xor AX, AX
    mov AL, SS:[BP+5] ;get first byte from stack
    mov AH, SS:[BP+4] ;get second byte from stack
    add AL, AH
    xor AH, AH
    pop BP
    ret 2 ;clear stack and give execution back to main
PrepEncryption endp

PrepDecryption proc near ;PrepDecryption(char a, char b) returns addition_result
    push BP
    mov BP, SP
    ;stack: BP, IP, a, b
    xor AX, AX
    mov AH, SS:[BP+5] ;get first byte from stack
    mov AL, SS:[BP+4] ;get second byte from stack
    sub AL, AH
    cmp AL, 0 ;handle negative values
    jge no_wrap
    add AL, 26
    no_wrap:
        xor AH, AH
        pop BP
        ret 2 ;clear stack and give execution back to main
PrepDecryption endp

ModuloWith26 proc near ;ModuloWith26(char a)
    push BP
    mov BP, SP
    ;stack: BP, IP, a
    xor AX, AX
    xor BX, BX
    mov AL, SS:[BP+5] ;get byte from stack
    mov BL, 26
    cmp AL, BL
    jl no_computation ;if less than 26, that is modulo result
    ;else, do modulo computation
    div BL ;AX = AL / 26, AH = remainder
    mov AL, AH ;move remainder to AL

    no_computation:
        xor AH, AH
        xor BX, BX
        pop BP
        ret 2 ;clear stack and give execution back to main
ModuloWith26 endp

end start