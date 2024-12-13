format PE64 console
entry main

define OWORD DQWORD
define resq rq
define resd rd
define resw rw
define resb rb

define OBJ_CASE_INSENSITIVE 0x40
define FILE_SYNCHRONOUS_IO_NONALERT 0x00000020
define FILE_OPEN 0x00000001
define FILE_SHARE_READ 0x00000001
define FILE_ATTRIBUTE_NORMAL 0x00000080
define ACCESS_MASK 0x80100080

section '.text' code readable executable

; This should be in .data, but putting it in .text allows
; the whole program to only have 1 section
; UTF-16 string "input.txt"
input: dw "i", "n", "p", "u", "t", ".", "t", "x", "t"

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

; rcx =  ptr to string
; rdx = length of string
print:
    sub rsp, 104
    mov rax, [gs:0x60]              ;
    mov rax, [rax + 0x20]           ; Get stdout
    mov r10, [rax + 0x28]           ;
    xorps xmm0, xmm0                            ;
    movups OWORD [rsp + 80], xmm0       ; Zero memory for IO_STATUS_BLOCK
    xor r8, r8   ; Zero arguments
    xor r9, r9   ;
    lea rax, [rsp + 80]           ;
    mov QWORD [rsp + 40], rax ; Give ptr to IO_STATUS_BLOCK     ;
    mov QWORD [rsp + 48], rcx   ; Give ptr to string
    mov QWORD [rsp + 56], rdx ; Give string length
    xor rdx, rdx ; Zero argument
    mov QWORD [rsp + 64], r8  ;
    mov QWORD [rsp + 72], r8  ; Zero arguments
    mov rax, 0x8 ; syscall number NtWriteFile
    syscall
 .exit:
    add rsp, 104
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

; Does not even pretend to follow calling conventions...
; rax = stack space to allocate
; afterwards, rsp will have grown to fit allocation
stack_alloc:
    add rax, 16 ;
    shr rax, 4  ; Align pointer
    shl rax, 4  ; 
    sub rax, 8   ; Include ret address
    call chkstk
    sub rsp, rax
 .exit:
    mov rax, QWORD [rsp + rax]
    jmp rax

; Makes sure that stack addresses rax bytes forward are safe to access.
; Windows implements automatically growing stack by allocating a guard page
;  in front of the stack. Accessing this page triggers a fault that is handled
;  by the OS and more stack memory is allocated. Trying to decrease rsp by more
;  than one page therefore requires touching every page to make sure the guard
;  page is not skipped over.
chkstk:
    push rcx
    push rax
    cmp  rax, 0x1000
    lea  rcx, [rsp + 0x18]
    jb .exit
 .loop:
    sub rcx, 0x1000
    or qword [rcx], 0
    sub rax, 0x1000
    cmp rax, 0x1000
    ja .loop
 .exit:
    sub rcx,rax
    or qword [rcx], 0
    pop rax
    pop rcx
    ret

; rcx: pointer to UTF-16 filename
; rdx: length of filename (in wchar_t count)
; Note: only accepts relative paths
; File is opened as readonly
; Stack:
; rsp + 0 ... rsp + 88: Args
; rsp + 96 ... rsp + 104: IO_STATUS_BLOCK 
; rsp + 112 ... rsp + 160: OBJECT_ATTRIBUTES
; rsp + 168: handle
; rsp + 176 ... rsp + 184: UNICODE_STRING
; Rounded -> 200
file_open:
    sub rsp, 200
    shl dx, 1 ; convert length to byte count

    mov WORD [rsp + 176], dx   ;
    mov WORD [rsp + 178], dx   ; Set UNICODE_STRING to filename
    mov QWORD [rsp + 184], rcx  ;

    mov rax, QWORD [gs:0x60]            ;
    mov rax, QWORD [rax + 0x20]         ; Get handle to working directory
    mov rax, QWORD [rax + 0x48]         ;

    mov DWORD [rsp + 112], 48    ; size
    mov QWORD [rsp + 120], rax ; directory handle
    lea rax, [rsp + 176]         ;
    mov QWORD [rsp + 128], rax   ; Path
    mov DWORD [rsp + 136], OBJ_CASE_INSENSITIVE ; Attributes
    xor rax, rax
    mov QWORD [rsp + 144], rax ; Security descriptor
    mov QWORD [rsp + 152], rax ; Security QOS

    xorps xmm0, xmm0                 ; Zero IO_STATUS_BLOCK
    movups OWORD [rsp + 96], xmm0    ;

    mov QWORD [rsp + 88], rax ; 11
    mov QWORD [rsp + 80], rax ; 10
    mov QWORD [rsp + 72], FILE_SYNCHRONOUS_IO_NONALERT ; 9
    mov QWORD [rsp + 64], FILE_OPEN ; 8
    mov QWORD [rsp + 56], FILE_SHARE_READ ; 7
    mov QWORD [rsp + 48], FILE_ATTRIBUTE_NORMAL ; 6
    mov QWORD [rsp + 40], rax ; 5
    lea r9, [rsp + 96] ; 4
    lea r8, [rsp + 112] ; 3
    mov rdx, ACCESS_MASK ; 2
    lea r10, [rsp + 168] ; 1
    mov rax, 0x55 ; syscall number NtCreateFile
    syscall
    mov rcx, rax
    xor rax, rax
    test rcx, rcx
    jne .exit
    mov rax, QWORD [rsp + 168]
 .exit:
    add rsp, 200
    ret

; rcx = handle
; Stack
; Rsp + 0 ... Rsp + 40: Args
; Rsp + 48 ... Rsp + 64: FILE_STANDARD_INFORMATION
; Rsp + 80 ... Rsp + 88: IO_STATUS_BLOCK
; Rounded => 104
file_size:
    sub rsp, 104

    xorps xmm0, xmm0               ;
    movups OWORD [rsp + 80], xmm0  ; Zero IO_STATUS_BLOCK

    mov QWORD [rsp + 40], 5 ; FileStandardInformation
    mov r9, 24 ; sizeof(FILE_STANDARD_INFORMATION)
    lea r8, [rsp + 48]
    lea rdx, [rsp + 80]
    mov r10, rcx
    mov rax, 0x11 ; syscall number NtQueryInformationFile
    syscall
    mov rcx, rax
    mov rax, -1
    test rcx, rcx
    jne .exit
    mov rax, QWORD [rsp + 56]
 .exit:
    add rsp, 104
    ret

; rcx = handle
; rdx = out buffer
; r8  = no of bytes to read
; Stack
; Rsp + 0 ... Rsp + 72: Args
; Rsp + 80 .. Rsp + 88: IO_STATUS_BLOCK
; Rounded => 104
file_read:
    sub rsp, 104

    xorps xmm0, xmm0               ;
    movups OWORD [rsp + 80], xmm0  ; Zero IO_STATUS_BLOCK
    
    xor rax, rax
    mov QWORD [rsp + 72], rax
    mov QWORD [rsp + 64], rax
    mov QWORD [rsp + 56], r8
    mov QWORD [rsp + 48], rdx
    lea rax, [rsp + 80]
    mov QWORD [rsp + 40], rax
    xor r9, r9
    xor r8, r8
    xor rdx, rdx
    mov r10, rcx
    mov rax, 0x6 ; syscall number NtReadFile
    syscall
    mov rcx, rax
    xor rax, rax
    test rcx, rcx
    jne .exit
    mov rax, QWORD [rsp + 88]
 .exit:
    add rsp, 104
    ret

; rcx = handle
; Stack
; Rsp + 0 .. Rsp + 32: Args
; Rounded => 40
file_close:
    sub rsp, 40
    mov r10, rcx
    mov rax, 0xf ; syscall number NtClose
    syscall
 .exit:
    add rsp, 40
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

main:
    push rbp
    push rsi
    push rdi
    mov rbp, rsp

    lea rcx, [input]
    mov rdx, 9
    call file_open
    mov rsi, rax

    mov rcx, rax
    call file_size
    mov rdi, rax

    call stack_alloc

    mov rcx, rsi
    mov rdx, rsp
    mov r8, rdi
    call file_read

    mov rcx, rsi
    call file_close

    mov rcx, rsp
    mov dl, 0xA
    mov r8, rdi
    call memcount
    mov rdi, rax

    mov rsi, rsp

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
