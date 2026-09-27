; =====================================================================
;  THREADS - a small pool of worker threads for per-pixel passes
;
;  par_rows(rdi fn, esi rows, edx align) splits [0, rows) into one band
;  per core (band starts are multiples of align) and runs fn(y0, y1) on
;  each band at once, the calling thread taking the first.  Jobs must
;  only write their own rows.  In the browser the pool needs shared
;  memory (a cross-origin isolated page); without it everything runs on
;  the one thread.
; =====================================================================

section .bss
th_count    resd 1              ; worker threads (not counting the caller)
th_fn       resq 1
th_quit     resd 1
th_done     resq 1              ; semaphore: a worker finished its band
th_start    resq TH_MAX         ; semaphore per worker
th_y0       resd TH_MAX
th_y1       resd TH_MAX
th_band     resd 1              ; rows per band of the current job

section .data
th_name     db "cityssembly-worker", 0

section .text

FUNC threads_init
    mov dword [th_count], 0
%ifdef NOTHREADS
    RETURN
%endif
    CALLC SDL_GetCPUCount
    dec eax
    CLAMP eax, 0, TH_MAX
    mov r12d, eax
    test r12d, r12d
    jz .out
    xor edi, edi
    CALLC SDL_CreateSemaphore
    test rax, rax
    jz .out
    mov [th_done], rax
    xor ebx, ebx
.l:
    cmp ebx, r12d
    jge .out
    xor edi, edi
    CALLC SDL_CreateSemaphore
    test rax, rax
    jz .out
    mov [th_start+rbx*8], rax
    lea rdi, [th_entry]
    lea rsi, [th_name]
    mov edx, ebx
%ifdef WIN64
    xor ecx, ecx                    ; default _beginthreadex / _endthreadex
    xor r8d, r8d
%endif
    CALLC SDL_CreateThread
    test rax, rax
    jz .out
    inc ebx
    mov [th_count], ebx
    jmp .l
.out:
    RETURN

; thread start: int fn(void *data) in the platform's convention
th_entry:
%ifdef WIN64
    push rdi
    push rsi
    sub rsp, 8
    mov edi, ecx
    call th_main
    add rsp, 8
    pop rsi
    pop rdi
    ret
%else
    jmp th_main
%endif

FUNC th_main
    mov ebx, edi                    ; worker index
.wait:
    mov rdi, [th_start+rbx*8]
    CALLC SDL_SemWait
    cmp dword [th_quit], 0
    jne .out
    mov edi, [th_y0+rbx*4]
    mov esi, [th_y1+rbx*4]
    cmp edi, esi
    jge .done
    call [th_fn]
.done:
    mov rdi, [th_done]
    CALLC SDL_SemPost
    jmp .wait
.out:
    xor eax, eax
    RETURN

; ---------------------------------------------------------------------
FUNC par_rows, 16
    mov r12, rdi                    ; fn
    mov r13d, esi                   ; rows
    mov r14d, edx                   ; align
    mov r15d, [th_count]
    test r15d, r15d
    jz .single
    cmp r13d, 64
    jl .single
    ; band = ceil(rows / (workers + 1)), rounded up to align
    lea ecx, [r15+1]
    mov eax, r13d
    add eax, ecx
    dec eax
    xor edx, edx
    div ecx
    add eax, r14d
    dec eax
    xor edx, edx
    div r14d
    imul eax, r14d
    mov [rbp-48], eax               ; band
    mov [th_band], eax
    mov [th_fn], r12
    xor ebx, ebx
.post:
    cmp ebx, r15d
    jge .mine
    lea eax, [rbx+1]
    imul eax, [rbp-48]
    CLAMP eax, 0, r13d
    mov [th_y0+rbx*4], eax
    add eax, [rbp-48]
    CLAMP eax, 0, r13d
    mov [th_y1+rbx*4], eax
    mov rdi, [th_start+rbx*8]
    CALLC SDL_SemPost
    inc ebx
    jmp .post
.mine:
    xor edi, edi
    mov esi, [rbp-48]
    CLAMP esi, 0, r13d
    call r12
    xor ebx, ebx
.join:
    cmp ebx, r15d
    jge .out
    mov rdi, [th_done]
    CALLC SDL_SemWait
    inc ebx
    jmp .join
.single:
    mov [th_band], r13d
    xor edi, edi
    mov esi, r13d
    call r12
.out:
    RETURN
