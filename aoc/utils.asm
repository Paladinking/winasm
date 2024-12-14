; include inside .text segments

define OWORD DQWORD
define resq rq
define resd rd
define resw rw
define resb rb

; Converts a string to a 64 bit unsigned.
; rcx: ptr, will point at first non-number after.
parse_u64_cstr:
    xor rax, rax
    mov r9, 10
    mov r8b, BYTE [rcx]
    cmp r8b, 0x30
    jb .error
    cmp r8b, 0x39
    ja .error
 .loop:
    sub r8b, 0x30
    mul r9
    jc .error
    and r8, 0xff ; Needed?
    add rax, r8
    inc rcx
    mov r8b, BYTE [rcx]
    cmp r8b, 0x30 
    jb .exit
    cmp r8b, 0x39
    ja .exit
    jmp .loop
 .error:
    xor rax, rax
 .exit:
    ret

; rcx: value, rdx: buffer, r8: buffer size
format_u64:
    push rbx
    xor rbx, rbx
    mov r9, rdx
    dec r9
    mov rax, rcx
    mov rcx, 10
    cmp r8, 0
    je .error
    add r8, r9
    cmp rax, 0
    jne .loop
    mov BYTE [r9 + 1], 0x30
    mov rbx, 1
    jmp .exit
 .loop:
    cmp rax, 0
    je .move
    cmp r9, r8
    je .error
    xor rdx, rdx
    div rcx
    add rdx, 0x30
    mov BYTE [r8], dl
    inc rbx
    dec r8
    jmp .loop
 .error:
    xor rbx, rbx
 .move:
    lea rcx, [r8 + 1]
    lea rdx, [r9 + 1]
    mov r8, rbx
    call memcopy
 .exit:
    mov rax, rbx
    pop rbx
    ret

print_u64:
    sub rsp, 72
    lea rdx, [rsp + 51]
    mov r8, 20
    call format_u64
    lea rcx, [rsp + 51]
    lea rdx, [rax + 1]
    mov BYTE [rcx + rax], 0xA
    call print
 .exit:
    add rsp, 72
    ret

; rcx = ptr to string
; rdx = length of string
print_ln:
    sub rsp, 8
    call print
    mov BYTE [rsp], 0xA
    mov rcx, rsp
    mov rdx, 1
    call print
 .exit:
    add rsp, 8
    ret

; Copy r8 characters from rcx to rdx
; Destroys: rcx, rdx, r8, r9
memcopy:
    cmp r8, 0
    je .exit
    mov r9b, BYTE [rcx]
    mov BYTE [rdx], r9b
    inc rcx
    inc rdx
    dec r8
    jmp memcopy
 .exit:
    ret

; Move r8 potentialy overlapping characters from rcx to rdx
memmove:
    cmp rcx, rdx
    je .exit
    ja .greater
    lea rcx, [rcx + r8]
    lea rdx, [rdx + r8]
 .less:
    cmp r8, 0
    je .exit
    dec rcx
    dec rdx
    dec r8
    mov r9b, BYTE [rcx]
    mov BYTE [rdx], r9b
    jmp .less
 .greater:
    cmp r8, 0
    je .exit
    mov r9b, BYTE [rcx]
    mov BYTE [rdx], r9b
    inc rcx
    inc rdx
    dec r8
    jmp .greater
 .exit:
    ret

; rcx = ptr to input
; rdx = length of input
listq_sort:
    push rbp
    mov rbp, rsp
    mov r8, rdx
    lea rax, [rdx * 8]
    call stack_alloc
    mov rdx, rsp
    call mergesortq_list
 .exit:
    mov rsp, rbp
    pop rbp
    ret

; rcx = ptr to first element of input
; rdx = ptr to second buffer
; r8 = length of input
mergesortq_list:
    push rsi
    push rdi
    push rbp
    cmp r8, 1
    je .exit
    mov rsi, rcx
    cmp r8, 2
    jne .divide
    mov rcx, QWORD [rsi]
    mov rdx, QWORD [rsi + 8]
    cmp rcx, rdx
    jle .exit
    mov QWORD [rsi + 8], rcx
    mov QWORD [rsi], rdx
    jmp .exit
 .divide:
    mov rdi, rdx
    mov rbp, r8
    lea r8, [r8 * 8]
    call memcopy
    mov rcx, rdi
    mov rdx, rsi
    mov r8, rbp
    shr r8, 1
    call mergesortq_list
    mov r8, rbp
    mov r9, rbp
    shr r9, 1
    sub r8, r9
    lea rcx, [rdi + 8 * r9]
    mov rdx, rsi
    call mergesortq_list
    mov r10, rbp
    mov r11, rbp
    shr r10, 1
    sub r11, r10
    lea rbp, [rdi + 8 * r10]
    mov r10, rbp
    lea r11, [rbp + 8 * r11]
 .merge:
    cmp rdi, r10
    je .merge_check_second
    cmp rbp, r11
    jne .merge_cmp
 .merge_first:
    mov rcx, QWORD [rdi]
    mov QWORD [rsi], rcx
    add rsi, 8
    add rdi, 8
    jmp .merge
 .merge_check_second:
    cmp rbp, r11
    je .exit
 .merge_second:
    mov rcx, QWORD [rbp]
    mov QWORD [rsi], rcx
    add rsi, 8
    add rbp, 8
    jmp .merge
 .merge_cmp:
    mov rcx, QWORD [rdi]
    mov rdx, QWORD [rbp]
    cmp rcx, rdx
    jle .merge_first
    jmp .merge_second
 .exit:
    pop rbp
    pop rdi
    pop rsi
    ret

; rcx = ptr, dl = byte to count
; r8 = number of characters
memcount:
    xor rax, rax
 .loop:
    cmp r8, 0
    je .exit
    dec r8
    inc rcx
    cmp BYTE [rcx - 1], dl
    jne .loop
    inc rax
    jmp .loop
 .exit:
    ret

; rcx = ptr
; rdx = qword to count
; r8  = number of items
listq_count:
    xor rax, rax
 .loop:
    cmp r8, 0
    je .exit
    dec r8
    add rcx, 8
    cmp QWORD [rcx - 8], rdx
    jne .loop
    inc rax
    jmp .loop
 .exit:
    ret


; rcx = ptr to buffer
; rdx = size of buffer
; r8 = aux passed as third argument to function
; r9 = ptr to function
fold_lines:
    push rsi
    push rdi
    push rbp
    mov rsi, rcx
    lea rdi, [rcx + rdx]
    mov rbp, r9
 .loop:
    cmp rsi, rdi
    jae .exit
    mov r9, rsi
 .size:
    cmp rsi, rdi
    jae .found_newline
    cmp BYTE [rsi], 0xA
    je .found_newline
    cmp BYTE [rsi], 0xD
    je .found_cr
    inc rsi
    jmp .size
 .found_cr:
    inc rsi
    cmp rsi, rdi
    jae .found_cr_nolf
    cmp BYTE [rsi], 0xA
    jne .found_cr_nolf
    lea rdx, [rsi - 1]
    sub rdx, r9
    jmp .call_fun
 .found_cr_nolf:
    dec rsi
 .found_newline:
    mov rdx, rsi
    sub rdx, r9
 .call_fun:
    mov rcx, r9
    call rbp
    mov r8, rax
    inc rsi
    jmp .loop
 .exit:
    mov rax, r8
    pop rbp
    pop rdi
    pop rsi
    ret


; rcx = size in bytes
; Stack
alloc:
    sub rsp, 72

    mov QWORD [rsp + 56], rcx
    mov QWORD [rsp + 64], 0

    mov QWORD [rsp + 48], 0x4    ; PAGE_READWRITE
    mov QWORD [rsp + 40], 0x3000 ; MEM_RESERVE | MEM_COMMIT
    lea r9, [rsp + 56]
    xor r8, r8
    lea rdx, [rsp + 64]
    mov r10, 0xffffffffffffffff
    mov rax, 0x18
    syscall
    mov rcx, rax
    xor rax, rax
    test rcx, rcx
    jne .exit
    mov rax, QWORD [rsp + 64]
 .exit:
    add rsp, 72
    ret


