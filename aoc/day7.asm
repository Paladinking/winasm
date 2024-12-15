format PE64 console
entry setup

section ".text" code readable executable

input: dw "i", "n", "p", "u", "t", "7", ".", "t", "x", "t"
define INPUT_LEN 10

include "utils.asm"
include "setup.asm"



; rcx = first number
; rdx = second number
concat:
    push r8
    mov rax, rdx
    mov r8, 10
    mov r10, rdx
    xor r9, r9
 .count_digits:
    inc r9
    cmp rax, 10
    jb .count_digits_end
    xor rdx, rdx
    div r8
    jmp .count_digits
 .count_digits_end:
    mov rax, 1
 .pow:
    mul r8
    dec r9
    ja .pow
    mul rcx
    add rax, r10
    pop r8
    ret

; rcx = ptr to numbers
; rdx = number of numbers
; r8 = solution to reach
; r9 = accumulated
solve_equation2:
    push rsi
    push rdi
    push rbp
    cmp rdx, 0
    je .last
    mov rsi, rcx
    mov rdi, rdx
    mov rbp, r9

    mov r9, QWORD [rsi]
    add r9, rbp
    lea rcx, [rsi + 8]
    lea rdx, [rdi - 1]
    call solve_equation2
    cmp rax, 0
    jne .exit

    mov rax, QWORD [rsi]
    mul rbp
    mov r9, rax
    lea rcx, [rsi + 8]
    lea rdx, [rdi - 1]
    call solve_equation2
    cmp rax, 0
    jne .exit

    mov rcx, rbp
    mov rdx, QWORD [rsi]
    call concat
    mov r9, rax
    lea rcx, [rsi + 8]
    lea rdx, [rdi - 1]
    call solve_equation2
    jmp .exit

 .last:
    xor rax, rax
    cmp r8, r9
    cmove rax, r8 
 .exit:
    pop rbp
    pop rdi
    pop rsi
    ret


; rcx = ptr to numbers
; rdx = number of numbers
; r8 = solution to reach
; r9 = accumulated
solve_equation:
    push rsi
    push rdi
    push rbp
    cmp rdx, 0
    je .last
    mov rsi, rcx
    mov rdi, rdx
    mov rbp, r9

    mov r9, QWORD [rsi]
    add r9, rbp
    lea rcx, [rsi + 8]
    lea rdx, [rdi - 1]
    call solve_equation
    cmp rax, 0
    jne .exit

    mov rax, QWORD [rsi]
    mul rbp
    mov r9, rax
    lea rcx, [rsi + 8]
    lea rdx, [rdi - 1]
    call solve_equation
    jmp .exit
 .last:
    xor rax, rax
    cmp r8, r9
    cmove rax, r8 
 .exit:
    pop rbp
    pop rdi
    pop rsi
    ret


; rcx = ptr
; rdx = length
; r8 = previous size
count_equation_size:
    add r8, 16
 .result_loop:
    inc rcx
    dec rdx
    cmp BYTE [rcx - 1], ':'
    jne .result_loop
    inc rcx
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

parse_equation:
    push rsi
    push rdi
    push rbp
    lea rsi, [r8 + 16]
    lea rdi, [rcx + rdx]
    xor rbp, rbp
    call parse_u64_cstr
    mov QWORD [rsi - 16], rax
    add rcx, 2
 .loop:
    inc rbp
    call parse_u64_cstr
    mov QWORD [rsi], rax
    add rsi, 8
    cmp rcx, rdi
    jae .exit
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


; rcx = ptr to start
; rdx = ptr after end
; r9 = function to use
solve_equations:
    push rsi
    push rdi
    push rbp
    push r12
    sub rsp, 8
    mov rsi, rcx
    mov rdi, rdx
    xor rbp, rbp
    mov r12, r8
 .loop:
    cmp rsi, rdi
    jae .exit
    mov r8, QWORD [rsi]
    mov rdx, QWORD [rsi + 8]
    lea rcx, [rsi + 24]
    lea rsi, QWORD [rsi + 8 * rdx + 16]
    dec rdx
    mov r9, QWORD [rcx - 8]
    call r12
    add rbp, rax
    jmp .loop
 .exit:
    mov rax, rbp
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

    xor r8, r8
    lea r9, [count_equation_size]
    call fold_lines

    call stack_alloc

    mov rcx, rsi
    mov rdx, rdi
    mov r8, rsp
    lea r9, [parse_equation]
    call fold_lines

    mov rsi, rsp
    mov rdi, rax

    mov rcx, rsi
    mov rdx, rdi
    lea r8, [solve_equation]
    call solve_equations

    mov rcx, rax
    call print_u64

    mov rcx, rsi
    mov rdx, rdi
    lea r8, [solve_equation2]
    call solve_equations

    mov rcx, rax
    call print_u64
 .exit:
    mov rsp, rbp
    pop rdi
    pop rsi
    pop rbp
    ret
