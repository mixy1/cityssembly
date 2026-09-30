; =====================================================================
;  UNDO - Ctrl+Z takes back your last actions
;  Before a tool changes the map the whole tile array is snapshotted;
;  afterwards only the tiles that actually changed are kept, with the
;  power wires and the money spent.  Undo puts those tiles back and
;  refunds the cost - whatever the city did elsewhere is untouched.
; =====================================================================
UNDO_ACTS    equ 24
UNDO_TILES   equ 24576
WIRE_BYTES   equ 4+MAX_WIRES*4

section .bss
alignb 16
undo_snap       resb MAP_TILES*TILE_BYTES
undo_idx        resd UNDO_TILES
undo_rec        resb UNDO_TILES*TILE_BYTES
undo_wires      resb UNDO_ACTS*WIRE_BYTES
undo_wtmp       resb WIRE_BYTES
act_start       resd UNDO_ACTS
act_count       resd UNDO_ACTS
act_cost        resd UNDO_ACTS
act_tool        resd UNDO_ACTS
n_acts          resd 1
n_redo          resd 1          ; undone actions that can be done again
undo_top        resd 1          ; entries in use
undo_armed      resd 1

section .data
s_undone    db "Undone - refunded ", 0
s_noundo    db "Nothing to undo.", 0
s_redone    db "Redone - cost ", 0
s_noredo    db "Nothing to redo.", 0

section .text
; copy the wires into rdi
wires_copy_out:
    mov eax, [n_wires]
    mov [rdi], eax
    lea rsi, [wire_a]
    add rdi, 4
    mov ecx, MAX_WIRES*4/8
    rep movsq
    ret

; restore the wires from rsi
wires_copy_in:
    mov eax, [rsi]
    mov [n_wires], eax
    add rsi, 4
    lea rdi, [wire_a]
    mov ecx, MAX_WIRES*4/8
    rep movsq
    ret

FUNC undo_begin
    lea rsi, [tiles]
    lea rdi, [undo_snap]
    mov ecx, MAP_TILES*TILE_BYTES/8
    rep movsq
    lea rdi, [undo_wtmp]
    call wires_copy_out
    mov dword [undo_armed], 1
    RETURN

; drop the oldest action to make room
FUNC undo_drop_oldest
    cmp dword [n_acts], 0
    je .out
    mov r12d, [act_count]           ; entries of action 0
    ; shift the entry arrays down
    mov ecx, [undo_top]
    sub ecx, r12d
    mov r13d, ecx
    lea rdi, [undo_idx]
    lea rsi, [undo_idx+r12*4]
    rep movsd
    mov eax, r12d
    shl eax, 5
    lea rsi, [undo_rec+rax]
    lea rdi, [undo_rec]
    mov ecx, r13d
    shl ecx, 2                      ; 32 bytes = 4 qwords
    rep movsq
    mov [undo_top], r13d
    ; shift the action table and wire copies
    xor ebx, ebx
.l:
    lea eax, [rbx+1]
    cmp eax, [n_acts]
    jge .d
    mov ecx, [act_start+rax*4]
    sub ecx, r12d
    mov [act_start+rbx*4], ecx
    mov ecx, [act_count+rax*4]
    mov [act_count+rbx*4], ecx
    mov ecx, [act_cost+rax*4]
    mov [act_cost+rbx*4], ecx
    mov ecx, [act_tool+rax*4]
    mov [act_tool+rbx*4], ecx
    imul esi, eax, WIRE_BYTES
    imul edi, ebx, WIRE_BYTES
    lea rsi, [undo_wires+rsi]
    lea rdi, [undo_wires+rdi]
    mov ecx, WIRE_BYTES
    rep movsb
    inc ebx
    jmp .l
.d:
    dec dword [n_acts]
.out:
    RETURN

; undo_end(edi cost): keep what the action changed
FUNC undo_end, 16
    cmp dword [undo_armed], 0
    je .out
    mov dword [undo_armed], 0
    mov [rbp-48], edi
    ; a new action: what was undone can't be redone any more
    cmp dword [n_redo], 0
    je .r0
    mov eax, [n_acts]
    mov eax, [act_start+rax*4]
    mov [undo_top], eax
    mov dword [n_redo], 0
.r0:
    ; room for another action
    cmp dword [n_acts], UNDO_ACTS
    jl .r1
    call undo_drop_oldest
.r1:
    mov r15d, [n_acts]
    mov eax, [undo_top]
    mov [act_start+r15*4], eax
    xor ebx, ebx                    ; tile
    xor r14d, r14d                  ; entries this action
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea rsi, [undo_snap+rax]
    lea rdi, [tiles+rax]
    mov rcx, [rsi]
    cmp rcx, [rdi]
    jne .diff
    mov rcx, [rsi+8]
    cmp rcx, [rdi+8]
    jne .diff
    mov rcx, [rsi+16]
    cmp rcx, [rdi+16]
    jne .diff
    mov rcx, [rsi+24]
    cmp rcx, [rdi+24]
    je .n
.diff:
    mov eax, [undo_top]
    cmp eax, UNDO_TILES
    jl .room
    ; out of room: forget the oldest action (or give up on this one)
    cmp dword [n_acts], 0
    je .abort
    push rsi
    push rsi
    call undo_drop_oldest
    pop rsi
    pop rsi
    dec r15d
    mov eax, [undo_top]
    sub eax, r14d
    mov [act_start+r15*4], eax
    mov eax, [undo_top]
    cmp eax, UNDO_TILES
    jge .abort
.room:
    mov [undo_idx+rax*4], ebx
    shl eax, 5
    lea rdi, [undo_rec+rax]
    mov rcx, [rsi]
    mov [rdi], rcx
    mov rcx, [rsi+8]
    mov [rdi+8], rcx
    mov rcx, [rsi+16]
    mov [rdi+16], rcx
    mov rcx, [rsi+24]
    mov [rdi+24], rcx
    inc dword [undo_top]
    inc r14d
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    ; wires changed?
    mov eax, [n_wires]
    cmp eax, [undo_wtmp]
    jne .keep
    test r14d, r14d
    jz .out                         ; nothing happened
.keep:
    mov [act_count+r15*4], r14d
    mov eax, [rbp-48]
    mov [act_cost+r15*4], eax
    mov eax, [tool]
    mov [act_tool+r15*4], eax
    imul edi, r15d, WIRE_BYTES
    lea rdi, [undo_wires+rdi]
    lea rsi, [undo_wtmp]
    mov ecx, WIRE_BYTES
    rep movsb
    inc r15d
    mov [n_acts], r15d
    jmp .out
.abort:
    mov eax, [act_start+r15*4]
    mov [undo_top], eax
.out:
    RETURN

; forget every action (a new or loaded city)
undo_reset:
    mov dword [n_acts], 0
    mov dword [n_redo], 0
    mov dword [undo_top], 0
    mov dword [undo_armed], 0
    jmp plan_reset                  ; (and the plan)

; swap the tiles and wires of action edi with the map's: what the action
; put back comes out, and the other way round (undo and redo alike)
FUNC undo_swap
    mov r15d, edi
    mov r12d, [act_start+r15*4]
    mov r13d, [act_count+r15*4]
    xor ebx, ebx
.l:
    cmp ebx, r13d
    jge .w
    lea eax, [r12+rbx]
    mov r14d, [undo_idx+rax*4]
    shl eax, 5
    lea rsi, [undo_rec+rax]
    mov eax, r14d
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    ; keep live traffic counters: cars on the road now are still there
    mov r8d, [rdi+T_OCC]
    mov r9b, [rdi+T_JAM]
    mov r10b, [rdi+T_TRAFFIC]
    mov rcx, [rsi]
    mov rdx, [rdi]
    mov [rdi], rcx
    mov [rsi], rdx
    mov rcx, [rsi+8]
    mov rdx, [rdi+8]
    mov [rdi+8], rcx
    mov [rsi+8], rdx
    mov rcx, [rsi+16]
    mov rdx, [rdi+16]
    mov [rdi+16], rcx
    mov [rsi+16], rdx
    mov rcx, [rsi+24]
    mov rdx, [rdi+24]
    mov [rdi+24], rcx
    mov [rsi+24], rdx
    cmp byte [rdi+T_OBJ], OBJ_ROAD
    jne .nr
    mov [rdi+T_OCC], r8d
    mov [rdi+T_JAM], r9b
    mov [rdi+T_TRAFFIC], r10b
.nr:
    inc ebx
    jmp .l
.w:
    lea rdi, [undo_wtmp]
    call wires_copy_out
    imul esi, r15d, WIRE_BYTES
    lea rsi, [undo_wires+rsi]
    push rsi
    push rsi
    call wires_copy_in
    pop rdi
    pop rdi
    lea rsi, [undo_wtmp]
    mov ecx, WIRE_BYTES
    rep movsb
    call roads_update_all
    mov dword [net_dirty], 1
    mov dword [cov_dirty], 1
    call networks_update
    call coverage_update
    RETURN

FUNC undo_do
    mov r15d, [n_acts]
    test r15d, r15d
    jnz .go
    lea rdi, [s_noundo]
    mov esi, UI_DIM
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_ERROR
    call sfx_play
    jmp .out
.go:
    dec r15d
    mov edi, r15d
    call undo_swap
    mov [n_acts], r15d
    inc dword [n_redo]
    movsxd rax, dword [act_cost+r15*4]
    add [money], rax
    call tb_reset
    lea rdi, [s_undone]
    call tb_str
    movsxd rdi, dword [act_cost+r15*4]
    call tb_money
    lea rdi, [textbuf]
    mov esi, UI_TEXT
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_BULLDOZE
    call sfx_play
.out:
    RETURN

; Ctrl+Y: do the last undone action again
FUNC redo_do
    cmp dword [n_redo], 0
    jne .go
    lea rdi, [s_noredo]
    mov esi, UI_DIM
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_ERROR
    call sfx_play
    jmp .out
.go:
    mov r15d, [n_acts]
    movsxd rax, dword [act_cost+r15*4]
    cmp rax, [money]
    jle .pay
    lea rdi, [s_nomoney]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_ERROR
    call sfx_play
    jmp .out
.pay:
    sub [money], rax
    mov edi, r15d
    call undo_swap
    inc dword [n_acts]
    dec dword [n_redo]
    call tb_reset
    lea rdi, [s_redone]
    call tb_str
    movsxd rdi, dword [act_cost+r15*4]
    call tb_money
    lea rdi, [textbuf]
    mov esi, UI_TEXT
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_ROAD
    call sfx_play
.out:
    RETURN
