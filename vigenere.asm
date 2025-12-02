.model large
.stack 40h
exit_dos MACRO
	MOV AX, 4c00h
	INT 21h
ENDM

.data
    keyFileName db "key.txt", 0        
    messageFileName db "message.txt", 0 

    keySize dw ?                       
    chunkSize dw ?                     
    fileHandle dw ?                    

    keyBuffer db 256 dup(?)           
    chunkBuffer db 512 dup(?)          

.code
start:
    mov ax, @data
    mov ds, ax

    lea ax, keyFileName
    push ax
    lea ax, keyBuffer
    push ax
    mov ax, 256 
    push ax
    call loadKeyFile
    cmp ax, 0
    je endProcessing
    mov keySize, ax

    lea ax, messageFileName
    push ax
    call openFileForReadWrite
    cmp ax, 0FFFFh
    je endProcessing
    mov fileHandle, ax

processChunks:
    ; read a chunk from the message file
    ; DX = buffer offset, BX = file handle, CX = chunk size
    mov bx, fileHandle
    lea dx, chunkBuffer
    mov cx, 512
    call readChunk
    mov chunkSize, ax 
    cmp ax, 0 
    je doneProcessing
    
    ;Encode/decode the chunk using Vigenère cipher

    ; write the chunk back to the file
    ; DX = buffer offset, BX = file handle, CX = chunk size
    lea ax, chunkBuffer
    push ax
    mov ax, fileHandle
    push ax
    mov ax, chunkSize
    push ax
    call writeChunk

    jmp processChunks
doneProcessing:
    mov bx, fileHandle
    mov ax, 3E00h
    int 21h
endProcessing:
    exit_dos


; load the key file into memory
; in: pointer to file name, pointer to buffer, max buffer size
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
; in: pointer to file name
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
; in: DX = buffer, BX = file handle, CX = chunk size
; out: AX = number of bytes read
readChunk proc near
    mov ax, 3F00h
    int 21h
    jc readError
    ret 0
readError:
    mov ax, 0  
    ret 0
readChunk endp

; write a chunk to a file
; in: buffer offset, file handle, chunk size
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
    mov ax, 4000h
    int 21h

    mov ax, 4201h
    mov bx, [bp+6]  
    xor cx, cx
    mov dx, [bp+4]
    int 21h

writeChunkDone:
    pop bp
    ret 6
writeChunk endp


end start