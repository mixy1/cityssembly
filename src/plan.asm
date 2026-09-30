; =====================================================================
;  PLAN MODE (beta) - draw now, build as the money comes in
;
;  Shift+P turns plan mode on: roads, zones, services and the rest are
;  drawn as blue ghosts, not built and not paid for.  The plan box (bottom
;  left) shows what it will cost; Build puts up what the money covers now,
;  in the order it was drawn, and the rest is built at the months' ends as
;  money comes in.  Clear throws the plan away.
;
;  What a storm, a tornado, a meteor or a fire wrecks - services, roads,
;  power lines - goes into the plan as well, so the player sees what was
;  lost and can put it back with Build (nothing is rebuilt on its own).
; =====================================================================
PLAN_MAX    equ 32
PLAN_TILES  equ 16384

section .bss
plan_on     resd 1
plan_run    resd 1              ; (building from the plan)
plan_state:                     ; (saved: the PLAN chunk)
plan_auto   resd 1              ; build the rest as money comes in
plan_n      resd 1
plan_used   resd 1
plan_tool   resd PLAN_MAX
plan_kind   resd PLAN_MAX
plan_rt     resd PLAN_MAX
plan_zt     resd PLAN_MAX
plan_up     resd PLAN_MAX
plan_bz     resd PLAN_MAX
plan_cost   resd PLAN_MAX
plan_start  resd PLAN_MAX
plan_cnt    resd PLAN_MAX
plan_xy     resw PLAN_TILES     ; x | y << 8
plan_state_end:
plan_save   resd 8              ; the player's own tool, kept while building
rb_last     resd 1              ; the last action is a disaster's (its number)
rb_told     resd 1              ; the day the player was last told
rb_wires    resd 4

section .data
s_pl_on     db "PLAN MODE (Shift+P)", 0
s_pl_off    db "Plan", 0
s_pl_acts   db " actions, ", 0
s_pl_build  db "Build", 0
s_pl_clear  db "Clear", 0
s_pl_full   db "The plan is full - build or clear it first.", 0
s_pl_waits  db "The rest of the plan waits for money: it's built as it comes in.", 0
s_pl_done   db "The plan is built.", 0
s_pl_gone   db "A planned piece can't be built there any more - it was dropped.", 0
s_rb_note   db "What was wrecked is in the plan (bottom left): Build puts it back.", 0

section .text

plan_reset:
    mov dword [rb_last], 0
    mov dword [plan_n], 0
    mov dword [plan_used], 0
    mov dword [plan_auto], 0
    mov dword [plan_on], 0
    ret

; Shift+P (beta)
plan_toggle:
    xor dword [plan_on], 1
    ret

; in plan mode, tool_apply records instead of building -> eax 1 if it did
FUNC plan_record
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp dword [plan_on], 0
    je .out
    cmp dword [plan_run], 0
    jne .out
    cmp dword [force_place], 0
    jne .out
    cmp dword [moving], 0           ; (a move happens now, not later)
    jne .out
    ; not the tools that only look, or shape the land
    mov ecx, [tool]
    cmp ecx, T_INSPECT
    je .out
    cmp ecx, T_LAND
    je .out
    cmp ecx, T_DISTRICT
    jae .out
    mov r12d, [plan_n]
    cmp r12d, PLAN_MAX
    jge .full
    ; the tiles it covers
    mov eax, [plan_used]
    add eax, [tl_n]
    cmp eax, PLAN_TILES
    jg .full
    mov eax, [tool]
    mov [plan_tool+r12*4], eax
    mov eax, [build_kind]
    mov [plan_kind+r12*4], eax
    mov eax, [road_type]
    mov [plan_rt+r12*4], eax
    mov eax, [zone_type]
    mov [plan_zt+r12*4], eax
    mov eax, [up_type]
    mov [plan_up+r12*4], eax
    mov eax, [bz_filter]
    mov [plan_bz+r12*4], eax
    mov eax, [tl_cost]
    mov [plan_cost+r12*4], eax
    mov eax, [plan_used]
    mov [plan_start+r12*4], eax
    mov ecx, [tl_n]
    mov [plan_cnt+r12*4], ecx
    xor ebx, ebx
.t:
    cmp ebx, [tl_n]
    jge .td
    mov eax, [tl_y+rbx*4]
    shl eax, 8
    or eax, [tl_x+rbx*4]
    mov ecx, [plan_used]
    mov [plan_xy+rcx*2], ax
    inc dword [plan_used]
    inc ebx
    jmp .t
.td:
    inc dword [plan_n]
    mov dword [rb_last], 0
    mov edi, SFX_CLICK
    call sfx_play
    mov eax, 1
    jmp .out
.full:
    lea rdi, [s_pl_full]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    mov eax, 1
.out:
    RETURN

; the first planned action goes: the rest move up
FUNC plan_drop_first
    cmp dword [plan_n], 0
    je .out
    mov r12d, [plan_cnt]            ; its tiles
    ; the tiles
    xor ecx, ecx
    mov edx, [plan_used]
    sub edx, r12d
.m:
    cmp ecx, edx
    jge .md
    lea eax, [rcx+r12]
    movzx eax, word [plan_xy+rax*2]
    mov [plan_xy+rcx*2], ax
    inc ecx
    jmp .m
.md:
    sub [plan_used], r12d
    ; the actions
    xor ecx, ecx
.a:
    lea eax, [rcx+1]
    cmp eax, [plan_n]
    jge .ad
%macro PSHIFT 1
    mov edx, [%1+rax*4]
    mov [%1+rcx*4], edx
%endmacro
    PSHIFT plan_tool
    PSHIFT plan_kind
    PSHIFT plan_rt
    PSHIFT plan_zt
    PSHIFT plan_up
    PSHIFT plan_bz
    PSHIFT plan_cost
    PSHIFT plan_cnt
    mov edx, [plan_start+rax*4]
    sub edx, r12d
    mov [plan_start+rcx*4], edx
    inc ecx
    jmp .a
.ad:
    dec dword [plan_n]
    mov dword [rb_last], 0
.out:
    RETURN

; build the plan from the front while the money lasts -> eax 1 if the
; whole plan got built
FUNC plan_build
    ; the player's own tool, for after
    mov eax, [tool]
    mov [plan_save], eax
    mov eax, [build_kind]
    mov [plan_save+4], eax
    mov eax, [road_type]
    mov [plan_save+8], eax
    mov eax, [zone_type]
    mov [plan_save+12], eax
    mov eax, [up_type]
    mov [plan_save+16], eax
    mov eax, [bz_filter]
    mov [plan_save+20], eax
    mov dword [plan_run], 1
.next:
    cmp dword [plan_n], 0
    je .all
    ; the first action, as it was drawn
    mov eax, [plan_tool]
    mov [tool], eax
    mov eax, [plan_kind]
    mov [build_kind], eax
    mov eax, [plan_rt]
    mov [road_type], eax
    mov eax, [plan_zt]
    mov [zone_type], eax
    mov eax, [plan_up]
    mov [up_type], eax
    mov eax, [plan_bz]
    mov [bz_filter], eax
    mov ecx, [plan_cnt]
    mov [tl_n], ecx
    xor ebx, ebx
.t:
    cmp ebx, [tl_n]
    jge .td
    mov eax, [plan_start]
    add eax, ebx
    movzx eax, word [plan_xy+rax*2]
    mov ecx, eax
    and ecx, 255
    mov [tl_x+rbx*4], ecx
    shr eax, 8
    mov [tl_y+rbx*4], eax
    mov byte [tl_ok+rbx], 0         ; (evaluated afresh below)
    inc ebx
    jmp .t
.td:
    call tool_evaluate
    cmp dword [tl_valid], 0
    jne .v
    ; it can't go there any more
    call plan_drop_first
    lea rdi, [s_pl_gone]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .next
.v:
    movsxd rax, dword [tl_cost]
    cmp rax, [money]
    jg .wait
    mov dword [force_place], 1
    call tool_apply
    mov dword [force_place], 0
    call plan_drop_first
    jmp .next
.wait:
    mov dword [plan_auto], 1
    xor ebx, ebx
    jmp .back
.all:
    mov dword [plan_auto], 0
    mov ebx, 1
.back:
    mov dword [plan_run], 0
    mov dword [tl_n], 0
    mov eax, [plan_save]
    mov [tool], eax
    mov eax, [plan_save+4]
    mov [build_kind], eax
    mov eax, [plan_save+8]
    mov [road_type], eax
    mov eax, [plan_save+12]
    mov [zone_type], eax
    mov eax, [plan_save+16]
    mov [up_type], eax
    mov eax, [plan_save+20]
    mov [bz_filter], eax
    mov eax, ebx
    RETURN

; at the month's end: the rest of the plan, if the money's there (beta)
FUNC plan_month
    cmp dword [beta_on], 0
    je .out
    cmp dword [tut_bubble], 0       ; (not in the tour's village)
    jne .out
    cmp dword [plan_auto], 0
    je .out
    cmp dword [plan_n], 0
    je .out
    call plan_build
    test eax, eax
    jz .out
    lea rdi, [s_pl_done]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; the ghosts of the plan (the world, with the tool's preview)
FUNC plan_draw, 16
    cmp dword [plan_n], 0
    je .out
    xor r12d, r12d                  ; action
.a:
    cmp r12d, [plan_n]
    jge .out
    ; a building: its footprint, once
    mov r14d, 1
    cmp dword [plan_tool+r12*4], T_BUILD
    jne .t0
    mov edi, [plan_kind+r12*4]
    call bld_rec
    movzx r14d, byte [rax+BI_SIZE]
.t0:
    xor r13d, r13d
.t:
    cmp r13d, [plan_cnt+r12*4]
    jge .an
    mov eax, [plan_start+r12*4]
    add eax, r13d
    movzx eax, word [plan_xy+rax*2]
    mov edi, eax
    and edi, 255
    mov esi, eax
    shr esi, 8
    mov edx, r14d
    mov ecx, RAMP(R_BLUE, 6)
    call draw_diamond
    cmp r14d, 1
    jne .an
    inc r13d
    jmp .t
.an:
    inc r12d
    jmp .a
.out:
    RETURN

; the plan box, bottom left (beta, ui)
FUNC draw_plan_box, 16
    cmp dword [beta_on], 0
    je .out
    cmp dword [plan_on], 0
    jne .show
    cmp dword [plan_n], 0
    je .out
.show:
    cmp dword [photo_mode], 0
    jne .out
    cmp dword [submenu], -1         ; (a menu from the dock covers it)
    jne .out
    ; above the dock, and above a scenario's line
    mov r12d, 4
    mov r13d, [ui_h]
    sub r13d, DOCK_BTN+74
    cmp dword [scen_id], 0
    je .y
    cmp dword [tool], T_DISTRICT
    je .y
    sub r13d, 34
.y:
    mov edi, r12d
    mov esi, r13d
    mov edx, 160
    mov ecx, 48
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 160
    mov ecx, 48
    call ui_over
    lea rdx, [s_pl_off]
    mov ecx, UI_TEXT
    cmp dword [plan_on], 0
    je .t
    lea rdx, [s_pl_on]
    mov ecx, UI_GOLD
.t:
    lea edi, [r12+6]
    lea esi, [r13+4]
    call draw_text
    ; what's in it
    xor eax, eax
    xor ecx, ecx
.c:
    cmp ecx, [plan_n]
    jge .cd
    add eax, [plan_cost+rcx*4]
    inc ecx
    jmp .c
.cd:
    mov [rbp-48], eax
    call tb_reset
    movsxd rdi, dword [plan_n]
    lea rsi, [s_pl_acts]
    call tb_count
    movsxd rdi, dword [rbp-48]
    call tb_money
    lea edi, [r12+6]
    lea esi, [r13+16]
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call draw_text
    cmp dword [plan_n], 0
    je .out
    lea edi, [r12+6]
    lea esi, [r13+30]
    mov edx, 72
    lea rcx, [s_pl_build]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .b2
    call plan_build
    test eax, eax
    jnz .b2
    lea rdi, [s_pl_waits]
    mov esi, UI_TEXT
    mov edx, -1
    mov ecx, -1
    call notify
.b2:
    lea edi, [r12+82]
    lea esi, [r13+30]
    mov edx, 72
    lea rcx, [s_pl_clear]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .out
    mov dword [plan_n], 0
    mov dword [plan_used], 0
    mov dword [plan_auto], 0
    mov dword [rb_last], 0
.out:
    RETURN

; ---------------------------------------------------------------------
;  the rebuild assist
; ---------------------------------------------------------------------
; a disaster is about to wreck tile (edi x, esi y): what stands there
; goes into the plan, to be built again when the player says (beta)
FUNC rebuild_note, 32
    cmp dword [beta_on], 0
    je .out
    cmp dword [tut_bubble], 0       ; (the tour's meteors aren't the city's)
    jne .out
    mov [rbp-48], edi
    mov [rbp-52], esi
    call tile_at
    test rax, rax
    jz .out
    movzx ecx, byte [rax+T_OBJ]
    cmp ecx, OBJ_SERVICE
    je .svc
    cmp ecx, OBJ_POWER
    je .pow
    cmp ecx, OBJ_ROAD
    jne .out
    ; a road (not the highway)
    test byte [rax+T_FLAGS], F_HIGHWAY
    jnz .out
    movzx r13d, byte [rax+T_ROADTYPE]
    cmp r13d, RT_HIGHWAY
    jae .out
    mov r12d, T_ROAD
    mov r14d, [road_costs+r13*4]
    xor r15d, r15d
    ; with the last one, if that's the same disaster's road
    mov eax, [plan_n]
    test eax, eax
    jz .new
    cmp eax, [rb_last]
    jne .new
    dec eax
    cmp dword [plan_tool+rax*4], T_ROAD
    jne .new
    cmp [plan_rt+rax*4], r13d
    jne .new
    cmp dword [plan_cnt+rax*4], MAX_TL
    jge .new
    cmp dword [plan_used], PLAN_TILES
    jge .out
    inc dword [plan_cnt+rax*4]
    add [plan_cost+rax*4], r14d
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call rb_put
    jmp .told
.svc:
    movzx r15d, byte [rax+T_SUB]
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call anchor_of
    mov [rbp-48], eax
    mov [rbp-52], edx
    ; not twice
    shl edx, 8
    or edx, eax
    xor ecx, ecx
.dup:
    cmp ecx, [plan_n]
    jge .nd
    cmp dword [plan_tool+rcx*4], T_BUILD
    jne .dn
    mov eax, [plan_start+rcx*4]
    cmp [plan_xy+rax*2], dx
    je .out
.dn:
    inc ecx
    jmp .dup
.nd:
    mov edi, r15d
    call bld_rec
    mov r14d, [rax+BI_COST]
    mov r12d, T_BUILD
    xor r13d, r13d
    jmp .new
.pow:
    ; a pylon, and the wires to its neighbours (strung again in order:
    ; n1, pylon, n2, pylon, n3)
    mov r12d, T_POWERLN
    xor r13d, r13d
    mov r14d, PYLON_COST
    xor r15d, r15d
    mov eax, [rbp-52]
    shl eax, MAP_SHIFT
    add eax, [rbp-48]
    mov [rbp-56], eax               ; the pylon's index
    mov dword [rbp-60], 0           ; neighbours
    xor ebx, ebx
.w:
    cmp ebx, [n_wires]
    jge .wd
    cmp dword [rbp-60], 3
    jge .wd
    movzx eax, word [wire_a+rbx*2]
    movzx ecx, word [wire_b+rbx*2]
    cmp eax, [rbp-56]
    je .wb
    cmp ecx, [rbp-56]
    jne .wn
    mov ecx, eax
.wb:
    mov eax, [rbp-60]
    mov [rb_wires+rax*4], ecx
    inc dword [rbp-60]
.wn:
    inc ebx
    jmp .w
.wd:
    ; room for it all?
    cmp dword [plan_n], PLAN_MAX
    jge .out
    mov eax, [plan_used]
    add eax, 6
    cmp eax, PLAN_TILES
    jge .out
    call rb_action
    mov ebx, [plan_n]
    dec ebx
    xor r12d, r12d                  ; tiles in the run
    cmp dword [rbp-60], 0
    je .p0
    mov edi, [rb_wires]
    call rb_put_idx
    inc r12d
.p0:
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call rb_put
    inc r12d
    xor r13d, r13d
.p1:
    inc r13d
    cmp r13d, [rbp-60]
    jge .p2
    cmp r13d, 1
    je .p1n
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call rb_put
    inc r12d
.p1n:
    mov edi, [rb_wires+r13*4]
    call rb_put_idx
    inc r12d
    jmp .p1
.p2:
    mov [plan_cnt+rbx*4], r12d
    jmp .told
.new:
    cmp dword [plan_n], PLAN_MAX
    jge .out
    cmp dword [plan_used], PLAN_TILES
    jge .out
    call rb_action
    mov eax, [plan_n]
    dec eax
    mov dword [plan_cnt+rax*4], 1
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call rb_put
.told:
    ; tell the player, once a day
    mov eax, [day_count]
    cmp eax, [rb_told]
    je .out
    mov [rb_told], eax
    lea rdi, [s_rb_note]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; a new action for the plan (r12d tool, r13d road type, r14d cost,
; r15d building kind), no tiles yet
rb_action:
    mov eax, [plan_n]
    mov [plan_tool+rax*4], r12d
    mov [plan_kind+rax*4], r15d
    mov [plan_rt+rax*4], r13d
    mov dword [plan_zt+rax*4], 0
    mov dword [plan_up+rax*4], 0
    mov dword [plan_bz+rax*4], 0
    mov [plan_cost+rax*4], r14d
    mov ecx, [plan_used]
    mov [plan_start+rax*4], ecx
    mov dword [plan_cnt+rax*4], 0
    inc eax
    mov [plan_n], eax
    mov [rb_last], eax
    ret

; the next tile of the plan: (edi x, esi y), or a tile index edi
rb_put_idx:
    mov esi, edi
    shr esi, MAP_SHIFT
    and edi, MAP_W-1
rb_put:
    shl esi, 8
    or esi, edi
    mov eax, [plan_used]
    mov [plan_xy+rax*2], si
    inc dword [plan_used]
    ret
