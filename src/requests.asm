; =====================================================================
;  REQUESTS (beta) - the mayor's in-tray once the advisor's goals are
;  done: the council asks for something the city needs right now (fewer
;  jams, shorter commutes, happier people, water for every home, cleaner
;  air, more bus riders, or simply growth), with a deadline and a reward
;  of about three months' profit.  One at a time; a new one comes a
;  month or two after the last is met or missed.
; =====================================================================
RQ_NONE     equ 0
RQ_JAMS     equ 1
RQ_COMMUTE  equ 2
RQ_HAPPY    equ 3
RQ_POP      equ 4
RQ_WATER    equ 5
RQ_POLLUTE  equ 6
RQ_TRANSIT  equ 7
RQ_KINDS    equ 7

section .data
rq_text     dq 0, rq_t1, rq_t2, rq_t3, rq_t4, rq_t5, rq_t6, rq_t7
rq_t1       db "Get jammed roads under ", 0
rq_t2       db "Bring the average commute under ", 0
rq_t3       db "Raise happiness to ", 0
rq_t4       db "Grow the city to ", 0
rq_t5       db "Bring water to every home (under ", 0
rq_t6       db "Clear the air: pollution under ", 0
rq_t7       db "Carry this many bus riders a month: ", 0
rq_unit     dq 0, 0, rq_u_s, rq_u_pct, rq_u_ppl, rq_u_dry, 0, 0
rq_u_s      db " s", 0
rq_u_pct    db "%", 0
rq_u_ppl    db " people", 0
rq_u_dry    db " without)", 0
; smaller is better for these kinds
rq_less     db 0, 1, 1, 0, 0, 1, 1, 0
s_rq        db "REQUEST ", 0
s_rq_now    db " (now ", 0
s_rq_left   db ") - ", 0
s_rq_mo     db " mo left", 0
s_rq_rew    db "  reward ", 0
s_rq_new    db "The council has a request - see the top left.", 0
s_rq_done   db "Request met! The council pays ", 0
s_rq_fail   db "The deadline passed - the council is disappointed.", 0

section .text

; the month count now
rq_month:
    mov eax, [year]
    imul eax, eax, 12
    add eax, [month]
    ret

; what the city scores now on request kind edi -> eax
FUNC rq_value
    cmp edi, RQ_JAMS
    jne .c
    xor eax, eax
    xor ecx, ecx
.j:
    mov edx, ecx
    shl edx, TILE_SHIFT
    cmp byte [tiles+rdx+T_OBJ], OBJ_ROAD
    jne .jn
    cmp byte [tiles+rdx+T_JAM], 150
    jb .jn
    inc eax
.jn:
    inc ecx
    cmp ecx, MAP_TILES
    jl .j
    RETURN
.c:
    cmp edi, RQ_COMMUTE
    jne .h
    mov eax, [avg_commute]
    xor edx, edx
    mov ecx, 60
    div ecx
    RETURN
.h:
    cmp edi, RQ_HAPPY
    jne .p
    mov eax, [happy_avg]
    RETURN
.p:
    cmp edi, RQ_POP
    jne .w
    mov eax, [population]
    RETURN
.w:
    cmp edi, RQ_WATER
    jne .pl
    mov eax, [cnt_nowater]
    RETURN
.pl:
    cmp edi, RQ_POLLUTE
    jne .t
    mov eax, [avg_pollution]
    RETURN
.t:
    mov eax, [bus_riders]
    RETURN

; is kind edi worth asking for now?  -> eax 1, and ecx the target,
; edx the months given
FUNC rq_offer
    mov ebx, edi
    call rq_value
    mov r12d, eax                   ; value now
    xor eax, eax
    cmp ebx, RQ_JAMS
    jne .c
    cmp r12d, 20
    jl .no
    mov ecx, r12d
    shr ecx, 1
    mov edx, 12
    jmp .yes
.c:
    cmp ebx, RQ_COMMUTE
    jne .h
    cmp r12d, 12                    ; seconds
    jl .no
    lea ecx, [r12*4]
    xor edx, edx
    mov eax, ecx
    mov ecx, 5
    div ecx
    mov ecx, eax                    ; 80%
    mov edx, 12
    jmp .yes
.h:
    cmp ebx, RQ_HAPPY
    jne .p
    cmp r12d, 78
    jge .no
    lea ecx, [r12+6]
    mov edx, 12
    jmp .yes
.p:
    cmp ebx, RQ_POP
    jne .w
    cmp r12d, 1000
    jl .no
    ; +10%, rounded up to 500
    mov eax, r12d
    xor edx, edx
    mov ecx, 10
    div ecx
    add eax, r12d
    add eax, 499
    xor edx, edx
    mov ecx, 500
    div ecx
    imul ecx, eax, 500
    mov edx, 24
    jmp .yes
.w:
    cmp ebx, RQ_WATER
    jne .pl
    cmp r12d, 10
    jl .no
    mov eax, r12d
    xor edx, edx
    mov ecx, 10
    div ecx
    mov ecx, eax
    mov edx, 6
    jmp .yes
.pl:
    cmp ebx, RQ_POLLUTE
    jne .t
    cmp r12d, 40
    jl .no
    lea ecx, [r12*2+r12]
    shr ecx, 2
    mov edx, 18
    jmp .yes
.t:
    ; buses: needs a depot, and riders under 1 in 15 residents
    cmp dword [svc_count+BK_BUSDEPOT*4], 0
    je .no
    mov eax, [population]
    xor edx, edx
    mov ecx, 15
    div ecx
    cmp r12d, eax
    jge .no
    mov ecx, eax
    mov edx, 12
.yes:
    mov eax, 1
    RETURN
.no:
    xor eax, eax
    RETURN

; month end (beta): check the request, or ask for a new one
FUNC requests_month
    cmp dword [beta_on], 0
    je .out
    mov eax, [goal_index]
    cmp eax, GOAL_COUNT
    jl .out
    cmp dword [req_kind], RQ_NONE
    je .new
    ; met?
    mov edi, [req_kind]
    call rq_value
    mov ecx, [req_kind]
    cmp byte [rq_less+rcx], 0
    je .more
    cmp eax, [req_target]
    jle .met
    jmp .due
.more:
    cmp eax, [req_target]
    jge .met
.due:
    call rq_month
    cmp eax, [req_due]
    jl .out
    lea rdi, [s_rq_fail]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    mov dword [req_kind], RQ_NONE
    mov dword [req_cool], 2
    jmp .out
.met:
    movsxd rax, dword [req_reward]
    add [money], rax
    call tb_reset
    lea rdi, [s_rq_done]
    call tb_str
    movsxd rdi, dword [req_reward]
    call tb_money
    lea rdi, [textbuf]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_CHIME
    call sfx_play
    mov dword [req_kind], RQ_NONE
    mov dword [req_cool], 1
    jmp .out
.new:
    cmp dword [req_cool], 0
    jle .pick
    dec dword [req_cool]
    jmp .out
.pick:
    ; the next kind after the last one asked that's worth asking for;
    ; growth when nothing else is
    mov r12d, [req_last]
    mov r13d, RQ_KINDS
.k:
    inc r12d
    cmp r12d, RQ_KINDS
    jle .k1
    mov r12d, 1
.k1:
    mov edi, r12d
    call rq_offer
    test eax, eax
    jnz .ask
    dec r13d
    jnz .k
    mov r12d, RQ_POP
    mov edi, r12d
    call rq_offer
    test eax, eax
    jz .out
.ask:
    mov [req_kind], r12d
    mov [req_last], r12d
    mov [req_target], ecx
    call rq_month
    add eax, edx
    mov [req_due], eax
    ; about three months' profit (at least $2,000, at most $150,000)
    mov eax, [income_last]
    sub eax, [expense_last]
    lea eax, [rax*2+rax]
    CLAMP eax, 2000, 150000
    mov [req_reward], eax
    lea rdi, [s_rq_new]
    mov esi, UI_GOLD
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; the request in the goal bar (beta) -> eax 1 if drawn
FUNC draw_request
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp dword [req_kind], RQ_NONE
    je .out
    mov eax, [goal_index]
    cmp eax, GOAL_COUNT
    jl .no
    mov ebx, [req_kind]
    call tb_reset
    mov rdi, [rq_text+rbx*8]
    call tb_str
    movsxd rdi, dword [req_target]
    call tb_num
    mov rdi, [rq_unit+rbx*8]
    test rdi, rdi
    jz .u
    call tb_str
.u:
    lea rdi, [s_rq_now]
    call tb_str
    mov edi, ebx
    call rq_value
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_rq_left]
    call tb_str
    call rq_month
    mov ecx, [req_due]
    sub ecx, eax
    CLAMP ecx, 0, 99
    movsxd rdi, ecx
    call tb_num
    lea rdi, [s_rq_mo]
    call tb_str
    ; the reward in its own colour after it
    lea rsi, [textbuf]
    lea rdi, [move_title]
    mov ecx, 63
    rep movsb
    mov byte [move_title+63], 0
    call tb_reset
    lea rdi, [s_rq_rew]
    call tb_str
    movsxd rdi, dword [req_reward]
    call tb_money
    lea rdi, [move_title]
    call text_width
    mov r12d, eax
    lea rdi, [s_rq]
    call text_width
    add r12d, eax
    lea rdi, [textbuf]
    call text_width
    add r12d, eax
    add r12d, 12
    mov edi, 4
    mov esi, 21
    mov edx, r12d
    mov ecx, 14
    call draw_panel
    mov edi, 8
    mov esi, 24
    lea rdx, [s_rq]
    mov ecx, UI_GOLD
    call draw_text
    mov edi, eax
    mov esi, 24
    lea rdx, [move_title]
    mov ecx, UI_TEXT
    call draw_text
    mov edi, eax
    mov esi, 24
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text
    mov eax, 1
    RETURN
.no:
    xor eax, eax
.out:
    RETURN
