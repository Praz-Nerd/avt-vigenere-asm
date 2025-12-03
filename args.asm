.model small
.stack 10h
exit_dos MACRO
	MOV AX, 4c00h
	INT 21h
ENDM
.data
    psp_seg dw 0
    arg1 db 128 dup('$')
    arg2 db 128 dup('$') 
    newline db 0Dh, 0Ah, '$'
    no_args_msg db 'No arguments provided.$'
    one_arg_msg db 'Only one argument provided.$'
    arg1_msg db 'Argument 1: $'
    arg2_msg db 'Argument 2: $'
.code
start:
    mov dx, ds
    mov ax, @data
    mov ds, ax
    mov psp_seg, dx

    call parse_args
    
    call print_args

    exit_dos
parse_args proc near
    ; ES = PSP segment
    mov es, word ptr psp_seg
    
    ; Get command line length
    mov cl, es:[80h]
    cmp cl, 0
    je no_args
    
    ; Point to command line text
    mov si, 81h
    xor ch, ch      ; Clear high byte of CX
    
    ; Skip leading spaces
skip_leading:
    mov al, es:[si]
    cmp al, ' '
    jne start_arg1
    inc si
    loop skip_leading
    jmp no_args     ; Only spaces found
    
start_arg1:
    ; Parse first argument
    mov di, offset arg1
parse_arg1:
    mov al, es:[si]
    cmp al, 0Dh     ; Carriage return
    je end_of_line
    cmp al, ' '     ; Space
    je arg1_done
    mov [di], al
    inc di
    inc si
    loop parse_arg1
    jmp end_of_line ; No more characters
    
arg1_done:
    ; Null terminate arg1 (or use '$' for DOS string)
    mov byte ptr [di], '$'
    
    ; Skip spaces between arguments
skip_spaces:
    mov al, es:[si]
    cmp al, ' '
    jne start_arg2
    inc si
    loop skip_spaces
    jmp end_of_line ; No second argument
    
start_arg2:
    ; Parse second argument
    mov di, offset arg2
parse_arg2:
    mov al, es:[si]
    cmp al, 0Dh     ; Carriage return
    je arg2_done
    mov [di], al
    inc di
    inc si
    loop parse_arg2
    
arg2_done:
    mov byte ptr [di], '$'
    
end_of_line:
    ret 0
    
no_args:
    ; Set both arguments to empty strings
    mov byte ptr [arg1], '$'
    mov byte ptr [arg2], '$'
    ret 0
parse_args endp

print_args proc near
    ; Check if arg1 is empty
    cmp byte ptr [arg1], '$'
    je no_arguments
    
    ; Print "Argument 1: "
    mov dx, offset arg1_msg
    mov ah, 09h
    int 21h
    
    ; Print first argument
    mov dx, offset arg1
    mov ah, 09h
    int 21h
    
    ; Print newline
    mov dx, offset newline
    mov ah, 09h
    int 21h
    
    ; Check if arg2 is empty
    cmp byte ptr [arg2], '$'
    je only_one_arg
    
    ; Print "Argument 2: "
    mov dx, offset arg2_msg
    mov ah, 09h
    int 21h
    
    ; Print second argument
    mov dx, offset arg2
    mov ah, 09h
    int 21h
    
    ; Print newline
    mov dx, offset newline
    mov ah, 09h
    int 21h
    
    ret 0
    
only_one_arg:
    ; Print message about only one argument
    mov dx, offset one_arg_msg
    mov ah, 09h
    int 21h
    ret 0
    
no_arguments:
    ; Print no arguments message
    mov dx, offset no_args_msg
    mov ah, 09h
    int 21h
    ret 0
    
print_args endp
end start