.model large
.stack 40h
exit_dos MACRO
	MOV AX, 4c00h
	INT 21h
ENDM

.data
    psp_seg dw 0
    keyFileName db 128 dup(0)        
    messageFileName db 128 dup(0) 

    keySize dw ?                       
    chunkSize dw ?                     
    fileHandle dw ?                    

    keyBuffer db 256 dup(?)           
    chunkBuffer db 512 dup(?)          

.code
start:
    mov dx, ds
    mov ax, @data
    mov ds, ax
    mov psp_seg, dx

    call parse_args
    cmp ax, 1
    je endProcessing

    lea ax, keyFileName
    push ax                ; pointer to file name
    lea ax, keyBuffer
    push ax                ; [pointer to buffer
    mov ax, 256
    push ax                ; max buffer size
    call loadKeyFile
    cmp ax, 0
    je endProcessing
    mov keySize, ax

    lea ax, messageFileName
    push ax                ; pointer to file name
    call openFileForReadWrite
    cmp ax, 0FFFFh
    je endProcessing
    mov fileHandle, ax

processChunks:
    ; read a chunk from the message file
    lea ax, chunkBuffer
    push ax                ; buffer offset
    mov ax, fileHandle
    push ax                ; file handle
    mov ax, 512
    push ax                ; chunk size
    call readChunk
    mov chunkSize, ax
    cmp ax, 0
    je doneProcessing

    ;Encode/decode the chunk using Vigenère cipher

    ; write the chunk back to the file
    lea ax, chunkBuffer
    push ax                ; buffer offset
    mov ax, fileHandle
    push ax                ; file handle
    mov ax, chunkSize
    push ax                ; chunk size
    call writeChunk

    jmp processChunks
doneProcessing:
    mov bx, fileHandle
    mov ax, 3E00h
    int 21h
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

; open a file for read/write
; in: [bp+4]=pointer to file name
; out: AX = file handle
openFileForReadWrite proc near
    push bp
    mov bp, sp
    mov ax, 3D02h
    mov dx, [bp+4]
    int 21h
    jc openError
    jmp openFileDone

openError:
    mov ax, 0FFFFh
openFileDone:
    pop bp
    ret 2
openFileForReadWrite endp

; read a chunk from a file
; in: [bp+6]=buffer, [bp+4]=file handle, [bp+2]=chunk size
; out: AX = number of bytes read
readChunk proc near
    push bp
    mov bp, sp
    mov bx, [bp+4]
    mov dx, [bp+6]
    mov cx, [bp+2]
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

    mov ax, 4201h
    mov bx, [bp+6]
    mov cx, 0FFFFh
    mov dx, [bp+4]
    neg dx
    int 21h

    mov cx, [bp+4]
    mov dx, [bp+8]
    mov bx, [bp+6]
    mov ax, 4000h
    int 21h

    mov ax, 4201h
    mov bx, [bp+6]
    xor cx, cx
    mov dx, [bp+4]
    int 21h

writeChunkDone:
    pop bp
    ret 8
writeChunk endp

; parse command line arguments
; out: keyFileName = argument1, messageFileName = argument2
; AX = 0 if args found, 1 if no args
parse_args proc near
    mov es, word ptr psp_seg

    xor cx, cx
    mov cl, es:[80h]
    cmp cl, 0
    je no_args

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
    je end_of_line
    cmp al, ' '
    je arg1_done
    mov [di], al
    inc di
    inc si
    loop parse_arg1
    jmp end_of_line

arg1_done:
    mov byte ptr [di], 0

skip_spaces:
    mov al, es:[si]
    cmp al, ' '
    jne start_arg2
    inc si
    loop skip_spaces
    jmp end_of_line

start_arg2:
    mov di, offset messageFileName
parse_arg2:
    mov al, es:[si]
    cmp al, 0Dh     ; Carriage return
    je arg2_done
    mov [di], al
    inc di
    inc si
    loop parse_arg2

arg2_done:
    mov byte ptr [di], 0
    mov ax, 0
    ret 0

end_of_line:
    mov ax, 1
    ret 0

no_args:
    mov byte ptr [keyFileName], 0
    mov byte ptr [messageFileName], 0
    mov ax, 1
    ret 0
parse_args endp

end start