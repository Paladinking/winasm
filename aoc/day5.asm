format PE64 console
entry setup

section ".text" code readable executable

input: dw "i", "n", "p", "u", "t", "5", ".", "t", "x", "t"
define INPUT_LEN 10

include "utils.asm"
include "setup.asm"


; rcx = ptr
; rdx = length
; r8 = previous size
count_order_size:
    add r8, 8
 .number:
    add r8, 8
 .number_loop:
    cmp rdx, 0
    je .exit
    inc rcx
    dec rdx
    cmp BYTE [rcx - 1], ','
    je .number
    jmp .number_loop
 .exit:
    mov rax, r8
    ret

parse_order:
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

parse_rule:
    push rsi
    mov rsi, r8
    call parse_u64_cstr
    mov QWORD [rsi], rax
    inc rcx
    call parse_u64_cstr
    mov QWORD [rsi + 8], rax
    lea rax, [rsi + 16]
    pop rsi
    ret

count_rule:
    lea rax, [r8 + 16]
    ret

find_cutoff:
    mov rax, r8
    cmp rdx, 0
    cmove rax, rcx
    ret


; rcx = first rule
; rdx = number of rules
; r8 = n1
; r9 = n2
; Does not modify rcx or rdx
follows_rules:
    push rcx
    push rdx
    sub rsp, 8
    xor rax, rax
    shl rdx, 4
    lea rdx, [rcx + rdx]
 .loop: 
    cmp rcx, rdx
    jae .end
    cmp QWORD [rcx], r9
    jne .next_rule
    cmp QWORD [rcx + 8], r8
    je .exit
 .next_rule:
    add rcx, 16
    jmp .loop
 .end:
    mov rax, 1
 .exit:
    add rsp, 8
    pop rdx
    pop rcx
    ret

; rcx = first rule
; rdx = number of rules
; r8 = ptr to order
; Does not modify rcx or rdx
; r8 will point after order when done
order_fix_rules:
    push rsi
    push rdi
    push rbp
    push r12
    push r13
    push r14
    sub rsp, 8
    xor r13, r13
    mov rdi, QWORD [r8]
    lea rdi, [r8 + 8 * rdi + 8]
    mov r12, r8
 .start:
    xor r14, r14
    mov r8, r12
    lea rsi, [r8 + 8]
 .loop:
    lea rbp, [rsi + 8]
    cmp rbp, rdi
    jae .done
 .loop_2:
    mov r8, QWORD [rsi]
    mov r9, QWORD [rbp]
    call follows_rules
    test rax, rax
    je .false
 .next:
    add rbp, 8
    cmp rbp, rdi
    jb .loop_2
    add rsi, 8
    jmp .loop
 .false:
    mov r10, QWORD [rsi]
    mov r11, QWORD [rbp]
    mov QWORD [rbp], r10
    mov QWORD [rsi], r11
    mov r10, QWORD [r12]
    shr r10, 1
    mov r13, QWORD [r12 + r10 * 8 + 8]
    mov r14, 1
    jmp .next
 .done:
    test r14, r14
    jne .start
 .exit:
    mov r8, rdi
    mov rax, r13
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rdi
    pop rsi
    ret

; rcx = first rule
; rdx = number of rules
; r8 = ptr to order
; Does not modify rcx or rdx
; r8 will point after order when done
order_follows_rules:
    push rsi
    push rdi
    push rbp
    lea rsi, [r8 + 8]
    mov rdi, QWORD [r8]
    lea rdi, [rsi + 8 * rdi]
 .loop:
    lea rbp, [rsi + 8]
    cmp rbp, rdi
    jae .true
 .loop_2:
    mov r8, QWORD [rsi]
    mov r9, QWORD [rbp]
    call follows_rules
    test rax, rax
    je .false 
    add rbp, 8
    cmp rbp, rdi
    jb .loop_2
    add rsi, 8
    jmp .loop
 .false:
    xor rax, rax
    jmp .exit
 .true:
    mov rax, 1
 .exit:
    mov r8, rdi
    pop rbp
    pop rdi
    pop rsi
    ret

; rcx = ptr to first rule
; rdx = number of rules
; r8 = ptr to first order
; r9 = ptr after last order
count_correct:
    push rbp
    push rsi
    push rdi
    mov rsi, r9
    xor rbp, rbp
 .loop:
    cmp r8, rsi
    je .exit
    mov rdi, QWORD [r8]
    shr rdi, 1
    mov rdi, QWORD [r8 + rdi * 8 + 8]
    call order_follows_rules
    test rax, rax
    je .loop
    add rbp, rdi
    jmp .loop
 .exit:
    mov rax, rbp
    pop rdi 
    pop rsi
    pop rbp
    ret
   

; rcx = ptr to first rule
; rdx = number of rules
; r8 = ptr to first order
; r9 = ptr after last order
count_incorrect:
    push rbp
    push rsi
    push rdi
    mov rsi, r9
    xor rbp, rbp
 .loop:
    cmp r8, rsi
    je .exit
    call order_fix_rules
    add rbp, rax
    jmp .loop
 .exit:
    mov rax, rbp
    pop rdi
    pop rsi
    pop rbp
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
    lea r9, [find_cutoff]
    call fold_lines
    mov r12, rax

    sub rax, rsi

    mov rcx, rsi
    mov rdx, rax
    xor r8, r8
    lea r9, [count_rule]
    call fold_lines

    call stack_alloc
    mov r13, rsp

    mov rcx, rsi
    mov rdx, r12
    sub rdx, rsi
    mov r8, r13
    lea r9, [parse_rule]
    call fold_lines
    lea rsi, [rsi + rdi]
    mov rdi, rax
    sub rdi, r13
    shr rdi, 4

    inc r12
    cmp BYTE [r12], 0xA
    jne .count_order
    inc r12

 .count_order:

    mov rcx, r12
    mov rdx, rsi
    sub rdx, r12
    xor r8, r8
    lea r9, [count_order_size]
    call fold_lines

    call stack_alloc

    mov rcx, r12
    mov rdx, rsi
    sub rdx, r12
    mov r8, rsp
    lea r9, [parse_order]
    call fold_lines

    mov rsi, rax

    mov rcx, r13
    mov rdx, rdi
    mov r8, rsp
    mov r9, rsi
    call count_correct

    mov rcx, rax
    call print_u64

    mov rcx, r13
    mov rdx, rdi
    mov r8, rsp
    mov r9, rsi
    call count_incorrect

    mov rcx, rax
    call print_u64

 .exit:
    mov rsp, rbp
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbp
    ret
