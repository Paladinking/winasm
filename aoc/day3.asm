format PE64 console
entry setup

section ".text" code readable executable

input: dw "i", "n", "p", "u", "t", "3", ".", "t", "x", "t"
define INPUT_LEN 10

include "utils.asm"
include "setup.asm"


; rcx = ptr
; rdx = len
parse2:
    push rsi
    push rdi
    push rbp
    push r12
    push r13
    mov r13, 1
    mov rsi, rcx
    lea rdi, [rcx + rdx]
    xor r12, r12
 .loop:
    cmp rsi, rdi
    jae .exit
    inc rsi
    cmp BYTE [rsi - 1], 'm'
    je .mul
    cmp BYTE [rsi - 1], 'd'
    je .do
    jmp .loop
 .mul:
    lea r9, [rdi - 4]
    cmp rsi, r9
    jae .exit
    cmp DWORD [rsi - 1], 678196589 ; mul(
    jne .loop
    add rsi, 3
    mov rcx, rsi
    call parse_u64_cstr
    cmp rcx, rsi
    je .loop
    mov rsi, rcx
    mov rbp, rax
    lea r9, [rdi - 2]
    cmp rsi, r9
    jae .exit
    cmp BYTE [rsi], ','
    jne .loop
    inc rsi
    mov rcx, rsi
    call parse_u64_cstr
    cmp rcx, rsi
    je .loop
    mov rsi, rcx
    cmp BYTE [rsi], ')'
    jne .loop
    inc rsi
    test r13, r13
    je .loop
    mul rbp
    add r12, rax
    jmp .loop
 .do:
    lea r9, [rdi - 4]
    cmp rsi, r9
    jae .exit
    cmp DWORD [rsi - 1], 690515812 ; do()
    jne .dont
    add rsi, 3
    mov r13, 1
    jmp .loop
 .dont:
    cmp DWORD [rsi - 1], 661548900 ; don'
    jne .loop
    add rsi, 3
    lea r9, [rdi - 3]
    cmp rsi, r9
    jae .exit
    cmp BYTE [rsi], 't'
    jne .loop
    inc rsi
    cmp WORD [rsi], 10536 ; ()
    jne .loop
    add rsi, 2
    xor r13, r13
    jmp .loop
 .exit:
    mov rax, r12
    pop r13
    pop r12
    pop rbp
    pop rdi
    pop rsi
    ret


; rcx = ptr
; rdx = len
parse:
    push rsi
    push rdi
    push rbp
    push r12
    sub rsp, 8
    mov rsi, rcx
    lea rdi, [rcx + rdx]
    xor r12, r12
 .loop:
    cmp rsi, rdi
    jae .exit
    inc rsi
    cmp BYTE [rsi - 1], 'm'
    je .mul
    jmp .loop
 .mul:
    lea r9, [rdi - 4]
    cmp rsi, r9
    jae .exit
    cmp DWORD [rsi - 1], 678196589 ; 'mul('
    jne .loop
    add rsi, 3
    mov rcx, rsi
    call parse_u64_cstr
    cmp rcx, rsi
    je .loop
    mov rsi, rcx
    mov rbp, rax
    lea r9, [rdi - 2]
    cmp rsi, r9
    jae .exit
    cmp BYTE [rsi], ','
    jne .loop
    inc rsi
    mov rcx, rsi
    call parse_u64_cstr
    cmp rcx, rsi
    je .loop
    mov rsi, rcx
    cmp BYTE [rsi], ')'
    jne .loop
    inc rsi
    mul rbp
    add r12, rax
    jmp .loop
 .exit:
    mov rax, r12
    add rsp, 8
    pop r12
    pop rbp
    pop rdi
    pop rsi
    ret


main:
    push rbp
    push rsi
    push rdi
    mov rbp, rsp

    mov rsi, rcx
    mov rdi, rdx

    call parse

    mov rcx, rax
    call print_u64

    mov rcx, rsi
    mov rdx, rdi
    call parse2

    mov rcx, rax
    call print_u64
 .exit:
    xor rax, rax
    mov rsp, rbp
    pop rdi
    pop rsi
    pop rbp
    ret
