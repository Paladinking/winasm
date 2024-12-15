format PE64 console
entry setup

section ".text" code readable executable

input: dw "i", "n", "p", "u", "t", "6", ".", "t", "x", "t"
define INPUT_LEN 10

include "utils.asm"
include "setup.asm"


; rcx = ptr
; rdx = w
; rdx = x
; rax = y
find_guard:
    sub rsp, 8
    xor rax, rax
    mov r8, rdx
 .loop:
    cmp BYTE [rcx + rax], '^'
    je .exit
    inc rax
    jmp .loop
 .exit:
    xor rdx, rdx
    div r8
    add rsp, 8
    ret


; rax = ptr
; rdx = (h << 32 | w)
; r8 = x
; r9 = y
; r12 = dx
; r13 = dy
has_visited:
    push rdx
    push rsi
    mov rsi, rax
    mov eax, edx
    mul r9
    add rax, r8
    shl rax, 2
    cmp r12, 0
    je .ycoord
    lea rax, [rax + r12 + 1] ; 2, 0
    jmp .check
 .ycoord:
    lea rax, [rax + r13 + 2] ; 3, 1  
 .check:
    xor rdx, rdx
    cmp BYTE [rsi + rax], 0
    jne .exit
    mov rdx, 1
    mov BYTE [rsi + rax], 1
 .exit:
    mov rax, rdx
    pop rsi
    pop rdx
    ret

; rcx =  ptr
; rdx = (h << 32 | w) 
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

size:
    mov eax, edx
    shr r8, 32
    inc r8
    shl r8, 32
    or rax, r8
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


main:
    push rbp
    push rsi
    push rdi
    push r12
    push r13
    mov rbp, rsp
    sub rsp, 48

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

    mov rdi, rsi ; elem_end

    mov rcx, rsp
    mov rdx, r12
    call find_guard

    mov r8, rdx ; x
    mov r9, rax ; y
    mov QWORD [rbp - 24], rdx
    mov QWORD [rbp - 32], rax

    mov rdx, r13
    shl rdx, 32
    or rdx, r12 ; (h << 32 | w)

    mov QWORD [rbp - 8], rcx
    mov QWORD [rbp - 16], rdx

    xor r12, r12 ; dx
    mov r13, -1  ; dy
    xor r11, r11 ; count

 .loop:
    call at_pos
    cmp al, 0xff
    je .done
 .check_next:
    add r8, r12
    add r9, r13
    call at_pos
    sub r8, r12
    sub r9, r13
    cmp al, '#'
    jne .advance
 .rotate:
    mov r10, r12
    mov r12, r13
    neg r12
    mov r13, r10
    jmp .check_next
 .advance:
    mov r10, r9
    shl r10, 32
    or r10, r8
    push r10
    inc r11
    add r8, r12
    add r9, r13
    jmp .loop
 .done:
    mov rsi, rsp ; start of set
    mov rdx, r11

    test rsp, 0x8 ;
    je .get_set   ; Align stack to dividable by 16
    sub rsp, 8    ; 

 .get_set:
    mov rcx, rsi
    call listq_to_set
    mov rdi, rax ; size of set
    
    mov rcx, rax
    call print_u64
    
    mov rdx, QWORD [rbp - 16]
    mov rax, rdx
    shr rax, 30
    mul edx
    mov QWORD [rbp - 40], rax
    call stack_alloc

    mov QWORD [rbp - 48], 0

 .block_loop:
    mov rcx, rsp
    mov rdx, QWORD [rbp - 40]
    mov r8b, 0
    call memset

    cmp rdi, 0
    je .block_loop_done

    mov rcx, QWORD [rbp - 8]
    mov rdx, QWORD [rbp - 16]
    mov r8, QWORD [rbp - 24] ; x
    mov r9, QWORD [rbp - 32] ; y

    mov r10, QWORD [rsi + 8 * rdi - 8]
    dec rdi
    mov r11d, r10d
    shr r10, 32

    cmp r10, r9
    jne .block_loop_start
    cmp r11, r8
    je .block_loop
 .block_loop_start:
    mov eax, edx
    mul r10
    mov rdx, QWORD [rbp - 16]
    add rax, r11
    mov BYTE [rcx + rax], '#'
    xor r12, r12 ; dx
    mov r13, -1  ; dy
 .block_loop_inner:
    call at_pos
    cmp al, 0xff
    je .block_loop_next
    mov rax, rsp
    call has_visited
    test rax, rax
    je .block_loop_infinite
 .block_loop_check_next:
    add r8, r12
    add r9, r13
    call at_pos
    sub r8, r12
    sub r9, r13
    cmp al, '#'
    jne .block_loop_advance
 .block_loop_rotate:
    mov r10, r12
    mov r12, r13
    neg r12
    mov r13, r10
    jmp .block_loop_check_next
 .block_loop_advance:
    add r8, r12
    add r9, r13
    jmp .block_loop_inner
 .block_loop_infinite:
    inc QWORD [rbp - 48]
 .block_loop_next:
    mov r10, QWORD [rsi + 8 * rdi]
    mov rax, r10 
    shr rax, 32
    mul edx
    add eax, r10d
    mov BYTE [rcx + rax], '.'
    jmp .block_loop
 .block_loop_done:
    mov rcx, QWORD [rbp - 48]
    call print_u64
    
 .exit:
    xor rax, rax
    mov rsp, rbp
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbp
    ret
