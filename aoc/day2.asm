format PE64 console
entry setup

section ".text" code readable executable

input: dw "i", "n", "p", "u", "t", "2", ".", "t", "x", "t"
define INPUT_LEN 10

include "utils.asm"

; rcx = ptr
; rdx = length
; r8 = previous size
count_size:
    add r8, 8
 .number:
    add r8, 8
 .number_loop:
    cmp rdx, 0
    je .exit
    inc rcx
    dec rdx
    cmp BYTE [rcx - 1], ' '
    je .number
    jmp .number_loop
 .exit:
    mov rax, r8
    ret

parse_line:
    push rsi
    push rdi
    push rbp
    lea rsi, [r8 + 8]
    lea rdi, [rcx + rdx]
    xor rbp, rbp
    mov QWORD [rsi - 8], r8

    cmp rcx, rdi
    je .exit
 .loop:
    inc rbp
    call parse_u64_cstr
    mov QWORD [rsi], rax
    add rsi, 8
    cmp rcx, rdi
    je .exit
    inc rcx
    jmp .loop
 .exit:
    mov rdx, rsi
    lea r8, [rbp * 8 + 8]
    sub rdx, r8
    mov QWORD [rdx], rbp

    mov rax, rsi
    pop rbp
    pop rdi
    pop rsi
    ret

; rcx = ptr to first
; rdx = ptr after last
; rax will be 0 or 1
is_safe:
    mov rax, 1
    lea rcx, [rcx + 8]
    cmp rcx, rdx
    jae .exit
    mov r8, QWORD [rcx - 8]     ; r8 = 77
    sub r8, QWORD [rcx]         ; r8 = -2
    je .unsafe
    jg .decreasing
 .increasing:
    cmp r8, -3
    jl .unsafe
    add rcx, 8
    cmp rcx, rdx
    jae .exit
    mov r8, QWORD [rcx - 8]
    sub r8, QWORD [rcx]
    jge .unsafe
    jmp .increasing
 .decreasing:
    cmp r8, 3
    jg .unsafe
    add rcx, 8
    cmp rcx, rdx
    jae .exit
    mov r8, QWORD [rcx - 8]
    sub r8, QWORD [rcx]
    jle .unsafe
    jmp .decreasing
 .unsafe:
    xor rax, rax
 .exit:
    ret


; rcx = ptr to first
; rdx = ptr after last
; rax will be 0 or 1
is_safe_modified:
    push rbp
    push rsi
    push rdi
    push r12
    sub rsp, 8
    mov rsi, rcx
    mov r12, rsi
    mov rdi, rdx
    call is_safe
    test rax, rax
    jne .exit
 .loop:
    xor rax, rax
    cmp rsi, rdi
    je .exit
    mov rbp, QWORD [rsi]
    lea rcx, [rsi + 8]
    mov rdx, rsi
    mov r8, rdi
    sub r8, rsi
    call memmove
    mov rcx, r12
    lea rdx, [rdi - 8]
    call is_safe
    test rax, rax
    jne .exit
    mov rcx, rsi
    lea rdx, [rsi + 8]
    mov r8, rdi
    sub r8, rsi
    call memmove
    mov QWORD [rsi], rbp
    add rsi, 8
    jmp .loop
 .exit:
    add rsp, 8
    pop r12
    pop rdi
    pop rsi
    pop rbp
    ret


; rcx = ptr to first
; rdx = ptr after last
; r8 = ptr to function
count_safe:
    push rbp
    push rsi
    push rdi
    push r12
    sub rsp, 8
    mov rsi, rcx
    mov rdi, rdx
    mov r12, r8
    xor rbp, rbp
 .loop:
    cmp rsi, rdi
    jae .exit
    mov rcx, QWORD [rsi]
    lea rdx, [rsi + 8 * rcx + 8]
    lea rcx, [rsi + 8]
    mov rsi, rdx
    call r12
    add rbp, rax 
    jmp .loop
 .exit:
    mov rax, rbp
    add rsp, 8
    pop r12
    pop rdi
    pop rsi
    pop rbp
    ret


main:
    push rbp
    push rsi
    push rdi
    mov rbp, rsp

    mov rsi, rcx
    mov rdi, rdx
    
    xor r8, r8
    lea r9, [count_size]
    call fold_lines

    call stack_alloc

    mov rcx, rsi
    mov rdx, rdi
    mov r8, rsp
    lea r9, [parse_line]
    call fold_lines

    mov rdi, rax

    mov rcx, rsp
    mov rdx, rdi
    lea r8, [is_safe]
    call count_safe

    mov rcx, rax
    call print_u64

    mov rcx, rsp
    mov rdx, rdi
    lea r8, [is_safe_modified]
    call count_safe

    mov rcx, rax
    call print_u64

 .exit:
    xor rax, rax
    mov rsp, rbp
    pop rdi
    pop rsi
    pop rbp
    ret
