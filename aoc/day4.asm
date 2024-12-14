format PE64 console
entry setup

section ".text" code readable executable

input: dw "i", "n", "p", "u", "t", "4", ".", "t", "x", "t"
define INPUT_LEN 10

include "utils.asm"
include "setup.asm"

count_masx:
    push r8
    push r9
    push r12

    call at_pos
    cmp al, 'A'
    jne .false

 .top_left:
    mov r12b, 'M'
    sub r8, 1
    sub r9, 1
    call at_pos
    add r8, 2
    cmp al, 'S'
    je .bottom_right
    cmp al, 'M'
    jne .false
    mov r12b, 'S'
 .bottom_right:
    add r9, 2
    call at_pos
    sub r9, 2
    cmp al, r12b
    jne .false
 .top_right:
    mov r12b, 'M'
    call at_pos
    cmp al, 'S'
    je .bottom_left
    cmp al, 'M'
    jne .false
    mov r12b, 'S'
 .bottom_left:
    sub r8, 2
    add r9, 2
    call at_pos
    cmp al, r12b
    jne .false
    mov rax, 1
    jmp .exit
 .false:
    xor rax, rax
 .exit:
    pop r12
    pop r9
    pop r8
    ret

; rcx = ptr
; rdx = (h << 64 | w)
; r8 = x
; r9 = y
count_xmas:
    push rbp
    push r12
    push r13

    xor rbp, rbp
    call at_pos
    cmp al, 'X'
    jne .exit

    mov r12, 1
    mov r13, -1
    call .dir
    add rbp, rax
    mov r12, 1
    mov r13, 0
    call .dir
    add rbp, rax
    mov r12, 1
    mov r13, 1
    call .dir
    add rbp, rax
    mov r12, 0
    mov r13, -1
    call .dir
    add rbp, rax
    mov r12, 0
    mov r13, 1
    call .dir
    add rbp, rax
    mov r12, -1
    mov r13, -1
    call .dir
    add rbp, rax
    mov r12, -1
    mov r13, 0
    call .dir
    add rbp, rax
    mov r12, -1
    mov r13, 1
    call .dir
    add rbp, rax
    jmp .exit
 .dir:
    push r8
    push r9
    xor rax, rax
    add r8, r12
    add r9, r13
    call at_pos
    cmp al, 'M'
    jne .dir.false
    add r8, r12
    add r9, r13
    call at_pos
    cmp al, 'A'
    jne .dir.false
    add r8, r12
    add r9, r13
    call at_pos
    cmp al, 'S'
    jne .dir.false
    mov rax, 1
    jmp .dir.exit
 .dir.false:
    xor rax, rax
 .dir.exit:
    pop r9
    pop r8 
    ret
 .exit:
    mov rax, rbp
    pop r13
    pop r12
    pop rbp
    ret

; rcx =  ptr
; rdx = (h << 64 | w) 
; r8 = x
; r9 = y
; perserves all registers except rax
at_pos:
    push rdx
    push rcx
    push r8
    cmp r8d, 0
    jl .out_of_bounds
    cmp r9d, 0
    jl .out_of_bounds
    cmp r8d, edx
    jge .out_of_bounds
    add rcx, r8
    mov r8, r9
    imul r8d, edx
    add rcx, r8
    shr rdx, 32
    cmp r9d, edx
    jge .out_of_bounds 
    mov al, BYTE [rcx]
    jmp .exit
 .out_of_bounds:
    mov al, 0xff
 .exit:
    pop r8
    pop rcx
    pop rdx
    ret


copy_row:
    push rsi
    lea rsi, [r8 + rdx]
    mov r9, rdx
    mov rdx, r8
    mov r8, r9
    call memcopy
    mov rax, rsi
    pop rsi
    ret

size:
    mov eax, edx
    shr r8, 32
    inc r8
    shl r8, 32
    or rax, r8
    ret


main:
    push rbp
    push rsi
    push rdi
    push r12
    push r13
    mov rbp, rsp

    mov rsi, rcx
    mov rdi, rdx

    xor r8, r8
    lea r9, [size]
    call fold_lines

    mov r12d, eax ; w
    shr rax, 32
    mov r13, rax  ; h

    mul r12
    call stack_alloc

    mov rcx, rsi
    mov rdx, rdi
    mov r8, rsp
    lea r9, [copy_row]
    call fold_lines

    mov rcx, rsp
    mov rdx, r13
    shl rdx, 32
    or rdx, r12

    xor r8, r8
    xor rdi, rdi
    xor rsi, rsi
 .loop_x: 
    cmp r8, r12
    jge .loop_x_end
    xor r9, r9
 .loop_y:
    cmp r9, r13
    jge .loop_y_end
    call count_xmas
    add rdi, rax
    call count_masx
    add rsi, rax
    inc r9
    jmp .loop_y
 .loop_y_end:
    inc r8
    jmp .loop_x
 .loop_x_end:

    mov rcx, rdi
    call print_u64

    mov rcx, rsi
    call print_u64

 .exit:
    mov rsp, rbp
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbp
    ret
