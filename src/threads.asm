; =====================================================================
;  THREADS - a small pool of worker threads for per-pixel passes
;
;  par_rows(rdi fn, esi rows, edx align) splits [0, rows) into bands
;  (their starts are multiples of align) and runs fn(y0, y1) on every
;  band, the workers and the calling thread each taking the next band
;  left until none are.  Tall jobs get about four bands per core, so the
;  cores that land on light rows (open land) help with the heavy ones
;  (downtown, water) instead of waiting.  Jobs must only write their own
;  rows.  In the browser the pool needs shared
;  memory (a cross-origin isolated page); without it everything runs on
;  the one thread.
; =====================================================================

section .bss
th_count    resd 1              ; worker threads (not counting the caller)
th_fn       resq 1
th_quit     resd 1
th_done     resq 1              ; semaphore: a worker finished its band
th_start    resq TH_MAX         ; semaphore per worker
th_band     resd 1              ; rows per band of the current job
th_rows     resd 1              ; rows of the current job
th_next     resd 1              ; the next band to take

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
    call par_take
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
    ; bands per core: four for tall jobs, one for short ones (their
    ; bands would be too thin to be worth the setup)
    lea ecx, [r15+1]
    cmp r13d, 256
    jl .one
    shl ecx, 2
.one:
    ; band = ceil(rows / bands), rounded up to align
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
    mov [th_band], eax
    mov [th_rows], r13d
    mov [th_fn], r12
    mov dword [th_next], 0
    xor ebx, ebx
.post:
    cmp ebx, r15d
    jge .mine
    mov rdi, [th_start+rbx*8]
    CALLC SDL_SemPost
    inc ebx
    jmp .post
.mine:
    call par_take
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

; take bands of the current job until none are left
FUNC par_take
.l:
    mov eax, 1
    lock xadd [th_next], eax        ; eax = this band
    imul eax, [th_band]             ; its first row
    cmp eax, [th_rows]
    jge .out
    mov edi, eax
    mov esi, eax
    add esi, [th_band]
    cmp esi, [th_rows]
    jle .ok
    mov esi, [th_rows]
.ok:
    call [th_fn]
    jmp .l
.out:
    RETURN
