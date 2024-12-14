format PE64 console
entry setup

section ".text" code readable executable

input: dw "i", "n", "p", "u", "t", "1", ".", "t", "x", "t"
define INPUT_LEN 10

include "utils.asm"
include "setup.asm"

; rcx: input buffer
; rdx: number of lines
; r8: first output buffer
; r9: second output buffer
parse_lines:
    push rsi
    push rdi
    push rbx
    mov rdi, r8
    mov rsi, r9
    lea rbx, [rdi + 8 * rdx]
 .loop:
    cmp rdi, rbx
    je .exit
    cmp BYTE [rcx], 0xa
    jne .first_num
    inc rcx
    jmp .loop
 .first_num:
    call parse_u64_cstr
    mov QWORD [rdi], rax
 .spaces:
    cmp BYTE [rcx], ' '
    jne .second_num
    inc rcx
    jmp .spaces
 .second_num:
    call parse_u64_cstr
    mov QWORD [rsi], rax
    add rdi, 8
    add rsi, 8
    inc rcx
    jmp .loop
 .exit:
    pop rbx
    pop rdi
    pop rsi
    ret

; rcx = first list
; rdx = second list
; r8 = length
count_similarity:
    push rsi
    push rdi
    push rbx
    push r12
    push r13
    mov rsi, rcx
    mov rdi, rdx
    lea rbx, [rcx + 8 * r8]
    xor r12, r12
    mov r13, r8
 .loop:
    cmp rsi, rbx
    je .exit
    mov rdx, QWORD [rsi]
    mov rcx, rdi
    mov r8, r13
    call listq_count
    imul rax, rdx
    add r12, rax

    add rsi, 8
    jmp .loop
 .exit:
    mov rax, r12
    pop r13
    pop r12
    pop rbx
    pop rdi
    pop rsi
    ret

; rcx = first list
; rdx = second list
; r8 = length
count_distance:
    xor rax, rax
    lea r8, [rcx + 8 * r8]
 .loop:
    cmp r8, rcx
    je .exit
    mov r9, QWORD [rcx]
    sub r9, QWORD [rdx]
    mov r10, r9
    neg r10
    cmovl r10, r9
    add rax, r10
    add rcx, 8
    add rdx, 8
    jmp .loop
 .exit:
    ret

count:
    lea rax, [r8 + 1]
    ret

; rcx = ptr to input
; rdx = size of input
main:
    push rbp
    push rsi
    push rdi
    mov rbp, rsp

    mov rsi, rcx
    mov rdi, rdx

    xor r8, r8
    lea r9, [count]
    call fold_lines
    mov rdi, rax

    shl rax, 4
    call stack_alloc

    mov rcx, rsi
    mov rdx, rdi
    mov r8, rsp
    lea r9, [rsp + rdi * 8]
    call parse_lines

    mov rcx, rsp
    mov rdx, rdi
    call listq_sort

    lea rcx, [rsp + rdi * 8]
    mov rdx, rdi
    call listq_sort

    mov rcx, rsp
    lea rdx, [rsp + rdi * 8]
    mov r8, rdi
    call count_distance

    mov rcx, rax
    call print_u64

    mov rcx, rsp
    lea rdx, [rsp + rdi * 8]
    mov r8, rdi
    call count_similarity

    mov rcx, rax
    call print_u64

 .exit:
    xor rax, rax
    mov rsp, rbp
    pop rdi
    pop rsi
    pop rbp
    ret
