.model small
.stack 10h
exit_dos MACRO
	MOV AX, 4c00h
	INT 21h
ENDM
.data
    msg1 db 'Arg1: $'
    msg2 db 13,10,'Arg2: $'
    buffer db 128 dup('$')
.code
start:
    mov ax, @data
    mov ds, ax

        ; Get command line from PSP (offset 80h)
    mov si, 80h
    mov es, ds
    mov di, offset buffer
    mov cx, [es:si]         ; Length of command line
    inc si                  ; Point to first char
    cmp cx, 0
    je no_args

    ; Copy command line to buffer
    rep movsb

    ; Parse first argument (skip leading spaces)
    mov si, offset buffer
skip_space1:
    cmp byte ptr [si], ' '
    jne arg1_start
    inc si
    jmp skip_space1

arg1_start:
    mov di, si
    ; Find end of first argument
find_arg1_end:
    cmp byte ptr [di], ' '
    je arg1_end
    cmp byte ptr [di], 0
    je arg1_end
    inc di
    jmp find_arg1_end

arg1_end:
    mov byte ptr [di], 0    ; Null-terminate first argument

    ; Print Arg1
    mov dx, offset msg1
    mov ah, 09h
    int 21h
    mov dx, si
    mov ah, 09h
    int 21h

    ; Find start of second argument
    inc di
skip_space2:
    cmp byte ptr [di], ' '
    jne arg2_start
    inc di
    jmp skip_space2

arg2_start:
    cmp byte ptr [di], 0
    je no_arg2
    mov si, di
    ; Find end of second argument
find_arg2_end:
    cmp byte ptr [di], ' '
    je arg2_end
    cmp byte ptr [di], 0
    je arg2_end
    inc di
    jmp find_arg2_end

arg2_end:
    mov byte ptr [di], 0    ; Null-terminate second argument

    ; Print Arg2
    mov dx, offset msg2
    mov ah, 09h
    int 21h
    mov dx, si
    mov ah, 09h
    int 21h
    jmp done

no_arg2:
    mov dx, offset msg2
    mov ah, 09h
    int 21h

no_args:
done:
    exit_dos
end start