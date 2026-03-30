BITS 64

buffer_size equ 0x1000
max_int_itoa_len equ 20
SYS_READ equ 0x0
SYS_WRITE equ 0x1
SYS_OPEN equ 0x2
SYS_EXIT equ 0x3c

stdin equ 0x0
stdout equ 0x1
stderr equ 0x2

global _start

section .rodata
    newline: db 0xa, 0x0
    fail_message: db "wc: input error", 0xa, 0x0
    fail_message_len: equ $ - fail_message

section .bss
    buffer: resb buffer_size
    bytes_count_string: resb max_int_itoa_len
    words_count_string: resb max_int_itoa_len
    lines_count_string: resb max_int_itoa_len

section .text
_start:
    ; get argc from stack
    mov rax, [rsp] ; copy argc to $rax

    cmp rax, 0x2 ; check that argv contains 2 arguments (binary name + user argument)
    jb fail

    ; get argv[1]
    mov rdi, [rsp+0x10]

    ; open argv[1]
    call open
    test rax, rax ; update RFLAGS
    js fail ; jump if rax is negative
    mov r12, rax ; store fd number

    xor r13, r13 ; file bytes

.main_loop:
    mov rdi, r12
    call read_to_buffer

    test rax, rax
    js fail
    cmp rax, 0x0
    je .main_loop_done

    add r13, rax
    jmp .main_loop
.main_loop_done:

    mov rdi, r13
    mov rsi, bytes_count_string
    call itoa

    ; this is because lea only accepts [base (address or register), index (register)*scale (1, 2, 8), constant]
    mov rbx, rax
    neg rbx
    lea rdi, [bytes_count_string + max_int_itoa_len + rbx] ; shift to the start of integer: bytes_count_string + max_int_itoa_len - length

    call print

    mov rdi, newline
    call print

    ; exit(0)
    mov rax, SYS_EXIT
    xor rdi, rdi ; exit code zero
    syscall

; strlen(text)
; rdi: pointer to text
; rax: result
strlen:
    xor rax, rax
.loop:
    cmp byte [rdi + rax], 0x0
    je .done
    inc rax
    jmp .loop
.done:
    ret

; print(text)
; rdi: pointer to text
print:
    call strlen
    mov rdx, rax

    mov rsi, rdi ; move first argument to syscall second argument
    mov rax, SYS_WRITE
    mov rdi, stdout
    syscall

    ret

; open(filename)
; rdi: pointer to filename
; rax: fd number
open:
    xor rsi, rsi ; 0x0 is O_RDONLY (/usr/include/asm-generic/fcntl.h)
    xor rdx, rdx

    mov rax, SYS_OPEN

    syscall

    ret

; read_to_buffer(fd)
; rdi: fd number
; rax: bytes read
read_to_buffer:
    mov rax, SYS_READ
    mov rsi, buffer ; where to write pointer
    mov rdx, buffer_size ; read size

    syscall

    ret

; itoa(N, buf)
; rdi: number
; rsi: buf address
; rax: bytes written
itoa:
    mov r13, rdi
    lea rbx, [rsi+max_int_itoa_len] ; start from the end
    xor rcx, rcx ; length = 0

.loop:
    cmp r13, 0
    je .loop_done

    xor rdx, rdx ; prepare for div
    mov rax, r13
    mov r8, 0xa
    div r8 ; rax = rax / r8, rdx = rax % r8

    add dl, '0' ; convert number to latin_1 (ASCII)

    dec rbx
    mov [rbx], dl
    inc rcx
    mov r13, rax

    jmp .loop

.loop_done:
    cmp rcx, 0
    jne .done

    ; if length is 0, then write '0'
    dec rbx
    mov byte [rbx], '0'
    mov rcx, 1

.done:
    mov rax, rcx
    ret

; fail()
fail:
    ; write(2, text, text_len)
    mov rax, SYS_WRITE
    mov rdi, stderr
    mov rsi, fail_message ; text
    mov rdx, fail_message_len ; text length
    syscall

    ; exit(1)
    mov rax, SYS_EXIT
    mov rdi, 1 ; exit non-zero
    syscall

