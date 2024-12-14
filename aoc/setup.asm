
define OBJ_CASE_INSENSITIVE 0x40
define FILE_SYNCHRONOUS_IO_NONALERT 0x00000020
define FILE_OPEN 0x00000001
define FILE_SHARE_READ 0x00000001
define FILE_ATTRIBUTE_NORMAL 0x00000080
define ACCESS_MASK 0x80100080

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

setup:
    push rbp
    push rsi
    push rdi
    mov rbp, rsp

    lea rcx, [input]
    mov rdx, INPUT_LEN
    call file_open
    mov rsi, rax
    test rax, rax
    je .exit

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
    mov rdx, rdi
    call main

 .exit:
    mov rsp, rbp
    pop rdi
    pop rsi
    pop rbp
