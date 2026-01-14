.model large
.stack 20h
exitDos macro
	mov AX, 4C00h
	int 21h
endm

closeFile macro handle
    xor AX, AX
    mov AH, 3Eh ;file close function code
    mov BX, handle ;load handler into BX
    int 21h ;call interrupt
endm

.data
    pspSeg dw 0
    keyFileName db 32 dup(0)        
    inputFileName db 32 dup(0)     
    outputFileName db 32 dup(0) 
    isDecryption db 1 ;0 for encryption, 1 for decryption

    keySize dw ?                       
    chunkSize dw ?                     
    inputFileHandle dw ?              
    outputFileHandle dw ?              

    keyBuffer db 64 dup(?)           
    chunkBuffer db 64 dup(?)          

.code
start:
    mov DX, DS
    mov AX, @data
    mov DS, AX
    mov pspSeg, DX

    call parseArgs
    cmp AX, 1
    jne skipEndProcessing1
    jmp endProcessing
skipEndProcessing1:
    lea AX, keyFileName
    push AX                ; pointer to file name
    lea AX, keyBuffer
    push AX                ; pointer to buffer
    mov AX, 64
    push AX                ; max buffer size
    call loadKeyFile
    cmp AX, 0
    jne skipEndProcessing2
    jmp endProcessing
skipEndProcessing2:
    mov keySize, AX

    ; open input file for reading
    lea AX, inputFileName
    push AX
    call openFileForRead
    cmp AX, 0FFFFh
    jne skipEndProcessing3
    jmp endProcessing
skipEndProcessing3:
    mov inputFileHandle, AX

    ; create output file for writing
    lea AX, outputFileName
    push AX
    call createFileForWrite
    cmp AX, 0FFFFh
    jne skipCloseInputAndExit
    jmp closeInputAndExit
skipCloseInputAndExit:
    mov outputFileHandle, AX

processChunks:
    ; read a chunk from the input file
    lea AX, chunkBuffer
    push AX                ; buffer offset
    mov AX, inputFileHandle
    push AX                ; file handle
    mov AX, keySize
    push AX                ; chunk size
    call readChunk
    mov chunkSize, AX
    cmp AX, 0
    jne skipDoneProcessing
    jmp doneProcessing
skipDoneProcessing:

    cmp AX, keySize
    je vigStart ;if the same size was read
    mov keySize, AX ;else, update size of key
    ;Encode/decode the chunk using Vigenère cipher
vigStart:
        ;clear registers and prepare loop
        mov CX, keySize
        xor SI, SI
        xor DI, DI
        xor BX, BX
vigLoop:
;A = 65
    mov AL, chunkBuffer[SI]     ;load byte from input buffer
    mov AH, keyBuffer[DI] ;load key byte
    ;vigenere logic
    sub AL, 65 ;subtract to get index
    sub AH, 65
    push AX
    cmp isDecryption, 0
    je doEncryption
    
    call prepDecryption
    jmp moduloComputation

doEncryption:
    call prepEncryption

moduloComputation:
    mov BH, AL ;get result from addition or subtraction
    push BX
    call moduloWith26
    add AL, 65 ;add back to ascii
    mov chunkBuffer[SI], AL  ;store result into chunkBuffer
    inc SI
    inc DI
    loop vigLoop

    ; write the chunk to the output file
    lea AX, chunkBuffer
    push AX                ; buffer offset
    mov AX, outputFileHandle
    push AX                ; file handle
    mov AX, chunkSize
    push AX                ; chunk size
    call writeChunk

    jmp processChunks
doneProcessing:
    ; close input file
    mov BX, inputFileHandle
    closeFile BX
    ; close output file
    mov BX, outputFileHandle
    closeFile BX
    jmp endProcessing

closeInputAndExit:
    mov BX, inputFileHandle
    closeFile BX

endProcessing:
    exitDos

; load the key file into memory
; in: [BP+8]=pointer to file name, [BP+6]=pointer to buffer, [BP+4]=max buffer size
; out: AX = number of bytes read
loadKeyFile proc near
    push BP
    mov BP, SP

    mov AH, 3Dh
    xor AL, AL
    mov DX, [BP+8]
    int 21h
    jc fileKeyError
    mov BX, AX

    mov AX, 3F00h
    mov CX, [BP+4]
    mov DX, [BP+6]
    int 21h
    jc fileKeyError
    push AX

    mov AX, 3E00h
    int 21h
    pop AX
    jmp fileKeyDone

fileKeyError:
    mov AX, 0

fileKeyDone:
    pop BP
    ret 6
loadKeyFile endp

; open a file for reading
; in: [BP+4]=pointer to file name
; out: AX = file handle or 0FFFFh on error
openFileForRead proc near
    push BP
    mov BP, SP
    mov AX, 3D00h
    mov DX, [BP+4]
    int 21h
    jc openReadError
    jmp openReadDone

openReadError:
    mov AX, 0FFFFh
openReadDone:
    pop BP
    ret 2
openFileForRead endp

; create a file for writing
; in: [BP+4]=pointer to file name
; out: AX = file handle or 0FFFFh on error
createFileForWrite proc near
    push BP
    mov BP, SP
    mov AH, 3Ch
    xor CX, CX
    mov DX, [BP+4]
    int 21h
    jc createWriteError
    jmp createWriteDone

createWriteError:
    mov AX, 0FFFFh
createWriteDone:
    pop BP
    ret 2
createFileForWrite endp

; read a chunk from a file
; in: [BP+8]=buffer, [BP+6]=file handle, [BP+4]=chunk size
; out: AX = number of bytes read
readChunk proc near
    push BP
    mov BP, SP
    mov BX, [BP+6]
    mov DX, [BP+8]
    mov CX, [BP+4]
    mov AX, 3F00h
    int 21h
    jc readError
    pop BP
    ret 6
readError:
    mov AX, 0
    pop BP
    ret 6
readChunk endp

; write a chunk to a file
; in: [BP+8]=buffer offset, [BP+6]=file handle, [BP+4]=chunk size
writeChunk proc near
    push BP
    mov BP, SP
    mov CX, [BP+4]
    mov DX, [BP+8]
    mov BX, [BP+6]
    mov AX, 4000h
    int 21h

    pop BP
    ret 8
writeChunk endp

; parse command line arguments
; out: keyFileName = arg1, inputFileName = arg2, outputFileName = arg3, isDecryption = arg4 (E/D)
; AX = 0 if args found, 1 if not enough args or invalid mode
parseArgs proc near
    mov ES, word ptr pspSeg

    xor CX, CX
    mov CL, ES:[80h]
    cmp CL, 0
    jne skipNoArgs
    jmp noArgs
skipNoArgs:

    mov SI, 81h

skipLeading:
    mov AL, ES:[SI]
    cmp AL, ' '
    jne startArg1
    inc SI
    loop skipLeading
    jmp noArgs

startArg1:
    mov DI, offset keyFileName
parseArg1:
    mov AL, ES:[SI]
    cmp AL, 0Dh     ; Carriage return
    jne skipEndOfLine1
    jmp endOfLine
skipEndOfLine1:
    cmp AL, ' '
    je arg1Done
    mov [DI], AL
    inc DI
    inc SI
    loop parseArg1
    jmp endOfLine

arg1Done:
    mov byte ptr [DI], 0

skipSpaces1:
    mov AL, ES:[SI]
    cmp AL, ' '
    jne startArg2
    inc SI
    loop skipSpaces1
    jmp endOfLine

startArg2:
    mov DI, offset inputFileName
parseArg2:
    mov AL, ES:[SI]
    cmp AL, 0Dh     ; Carriage return
    jne skipEndOfLine2
    jmp endOfLine
skipEndOfLine2:
    cmp AL, ' '
    je arg2Done
    mov [DI], AL
    inc DI
    inc SI
    loop parseArg2
    jmp endOfLine

arg2Done:
    mov byte ptr [DI], 0

skipSpaces2:
    mov AL, ES:[SI]
    cmp AL, ' '
    jne startArg3
    inc SI
    loop skipSpaces2
    jmp endOfLine

startArg3:
    mov DI, offset outputFileName
parseArg3:
    mov AL, ES:[SI]
    cmp AL, 0Dh     ; Carriage return
    jne skipEndOfLine3
    jmp endOfLine
skipEndOfLine3:
    cmp AL, ' '
    je arg3Done
    mov [DI], AL
    inc DI
    inc SI
    loop parseArg3

arg3Done:
    mov byte ptr [DI], 0

skipSpaces3:
    mov AL, ES:[SI]
    cmp AL, ' '
    jne startArg4
    inc SI
    loop skipSpaces3
    jmp endOfLine

startArg4:
    mov AL, ES:[SI]
    cmp AL, 0Dh
    jne skipEndOfLine4
    jmp endOfLine
skipEndOfLine4:
    ; Accept only one char for mode
    cmp AL, 'E'
    je setEncrypt
    cmp AL, 'e'
    je setEncrypt
    cmp AL, 'D'
    je setDecrypt
    cmp AL, 'd'
    je setDecrypt
    jmp endOfLine

setEncrypt:
    mov byte ptr [isDecryption], 0
    mov AX, 0
    ret 0

setDecrypt:
    mov byte ptr [isDecryption], 1
    mov AX, 0
    ret 0

endOfLine:
    mov AX, 1
    ret 0

noArgs:
    mov byte ptr [keyFileName], 0
    mov byte ptr [inputFileName], 0
    mov byte ptr [outputFileName], 0
    mov AX, 1
    ret 0
parseArgs endp

prepEncryption proc near ;prepEncryption(char a, char b) returns addition_result
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
prepEncryption endp

prepDecryption proc near ;prepDecryption(char a, char b) returns addition_result
    push BP
    mov BP, SP
    ;stack: BP, IP, a, b
    xor AX, AX
    mov AH, SS:[BP+5] ;get first byte from stack
    mov AL, SS:[BP+4] ;get second byte from stack
    sub AL, AH
    cmp AL, 0 ;handle negative values
    jge noWrap
    add AL, 26
    noWrap:
        xor AH, AH
        pop BP
        ret 2 ;clear stack and give execution back to main
prepDecryption endp

moduloWith26 proc near ;moduloWith26(char a)
    push BP
    mov BP, SP
    ;stack: BP, IP, a
    xor AX, AX
    xor BX, BX
    mov AL, SS:[BP+5] ;get byte from stack
    mov BL, 26
    cmp AL, BL
    jl noComputation ;if less than 26, that is modulo result
    ;else, do modulo computation
    div BL ;AX = AL / 26, AH = remainder
    mov AL, AH ;move remainder to AL

    noComputation:
        xor AH, AH
        xor BX, BX
        pop BP
        ret 2 ;clear stack and give execution back to main
moduloWith26 endp

end start