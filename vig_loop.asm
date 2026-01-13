.model small
.stack 10h

exit_dos MACRO
    mov AX, 4c00h
    int 21h
ENDM

open_file MACRO filename, handle, accesstype
    local file_open_error, file_open_success
    ;trying to open a file
    mov AH, 3Dh ;file open function code
    mov AL, accesstype ;open with access type
    lea DX, filename ;give address to filename
    int 21h ;call interrupt

    jc file_open_error ;if failed to open, jump
    mov handle, AX ;else, save handler to RAM
    jmp file_open_success

    file_open_error:
        mov handle, -1
    file_open_success:
ENDM

create_file MACRO filename, attribute, handle
    local file_open_error, file_open_success
    mov AH, 3Ch
    mov CX, attribute
    lea DX, filename
    int 21h

    jc file_open_error
    mov handle, AX
    jmp file_open_success

    file_open_error:
        mov handle, -1
    file_open_success:
ENDM

read_chunk MACRO handle, buffersize, buffer
    ;try to read from file into a buffer
    xor AX, AX
    mov AH, 3Fh
    mov BX, handle
    mov CX, buffersize
    lea DX, buffer
    int 21h
ENDM

write_chunk MACRO handle, buffersize, buffer
    xor AX, AX
    mov BX, handle
    mov AH, 40h
    mov CX, buffersize
    lea DX, buffer
    int 21h
ENDM


close_file MACRO handle
    xor AX, AX
    mov AH, 3Eh ;file close function code
    mov BX, handle ;load handler into BX
    int 21h ;call interrupt
ENDM

.data
    keyfname DB 'key.txt', 0
    ;foname DB 'out.enc', 0
    ;finame DB 'msg.txt', 0
    foname DB 'dec.txt', 0
    finame DB 'out.enc', 0
    keyhandle DW ?
    inhandle DW ?
    outhandle DW ?
    keystring DB 64 dup (03h)
    keysize DW ?
    buffer DB 64 dup (03h)
    encbuffer DB 64 dup (03h)
    remainder DB ?
    addition_result DB ?
    is_decryption DB 1 ;0 for encryption, 1 for decryption
.code
start:
    mov AX, @data
    mov DS, AX

    open_file finame, inhandle, 00h ;open plaintext file

    open_file keyfname, keyhandle, 00h ;open key text file
    read_chunk keyhandle, 64, keystring ;read the key into memory
    mov keysize, AX ;get the size fo key
    close_file keyhandle

    create_file foname, 00h, outhandle ;create file for encrypting


    ;file read loop
    while_read:
        read_chunk inhandle, keysize, buffer ;read the size of key, to xor
        cmp AX, 0 ;if EOF
        jz final ;exit loop

        cmp AX, keysize
        je xoring ;if the same size was read, jump to xor
        mov keysize, AX ;else, update size of key

        xoring:
            ;clear registers and prepare loop
            mov CX, keysize
            xor SI, SI
            xor DI, DI
            xor BX, BX
        xor_loop:
        ;A = 65
            mov AL, buffer[SI]     ;load byte from input buffer
            mov AH, keystring[DI] ;load key byte
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
                mov BH, addition_result ;get result from addition or subtraction
                push BX
                call ModuloWith26
                mov AL, remainder
                add AL, 65 ;add back to ascii
                mov encbuffer[SI], AL  ;store result into encbuffer
                inc SI
                inc DI
            loop xor_loop
            ;write encrypted buffer to output file
            write_chunk outhandle, keysize, encbuffer

        ;buffer and key should be the size of the key...
        jmp while_read

    final:
        close_file inhandle
        close_file outhandle
        exit_dos ;return 0

PrepEncryption proc near ;PrepEncryption(char a, char b) returns addition_result
    push BP
    mov BP, SP
    ;stack: BP, IP, a, b
    xor AX, AX
    mov AL, SS:[BP+5] ;get first byte from stack
    mov AH, SS:[BP+4] ;get second byte from stack
    add AL, AH
    mov addition_result, AL
    xor AX, AX
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
        mov addition_result, AL
        xor AX, AX
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
        mov remainder, AL
        xor AX, AX
        xor BX, BX
        pop BP
        ret 2 ;clear stack and give execution back to main
ModuloWith26 endp
end start
