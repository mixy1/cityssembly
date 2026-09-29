; =====================================================================
;  TOOLS - building tools in testing (?beta)
;
;  Special buildings go down over zoned buildings: those come down
;  first (the price tag says how many and who lived or worked there).
;  Roads only give way with Ctrl held, the regional highway and other
;  services never.  A spot that doesn't fit slides up to 2 tiles to the
;  nearest one that does.  A service remembers the zone it was built
;  over and gives it back when it goes.
;
;  The inspector can demolish a building, replace a zoned one with a
;  service, upgrade a service in place (clinic -> hospital, park ->
;  plaza, landfill -> incinerator, coal -> nuclear) and move one.
; =====================================================================

TE_LOCKED   equ 1
TE_NEEDW    equ 2
TE_NOTOWNED equ 3
TE_ROAD     equ 4
TE_WATER    equ 5
TE_BUILDING equ 6
TE_HIGHWAY  equ 7

section .bss
svc_zone    resb MAP_TILES          ; the zone each service was built over
fit_cost    resd 1                  ; clearing the spot
fit_repl    resd 1                  ; zoned buildings that come down
fit_res     resd 1                  ; their residents
fit_jobs    resd 1                  ; and jobs
fit_nanch   resd 1
fit_anch    resd 16
repl_open   resd 1                  ; the inspector's "replace with" list
repl_scroll resd 1
moving      resd 1                  ; the build tool is moving move_from
move_title  resb 64

section .data
move_from   dd -1                   ; tile of the service being moved / upgraded
; the order the footprint tries other spots in, nearest first
nudge_off   db 1,0, -1,0, 0,1, 0,-1, 1,1, 1,-1, -1,1, -1,-1
            db 2,0, -2,0, 0,2, 0,-2, 2,1, 2,-1, -2,1, -2,-1
            db 1,2, 1,-2, -1,2, -1,-2, 2,2, 2,-2, -2,2, -2,-2
NUDGE_N     equ 24
; upgrades in place: from, to
upgrade_t   dd BK_CLINIC, BK_HOSPITAL, BK_PARK, BK_PLAZA
            dd BK_LANDFILL, BK_INCIN, BK_COAL, BK_NUCLEAR, -1
te_msgs     dq 0, 0, 0, 0, s_te_road, s_te_water, s_te_bld, s_te_hwy
te_short    dq 0, 0, s_ts_needw, s_ts_owned, s_ts_road, s_ts_water, s_ts_bld, s_ts_hwy
s_te_road   db "A road is in the way - hold Ctrl to build over it.", 0
s_te_water  db "That can't be built on water.", 0
s_te_bld    db "Another service is in the way.", 0
s_te_hwy    db "The regional highway can't be built over.", 0
s_ts_needw  db "must touch water", 0
s_ts_owned  db "not your land", 0
s_ts_road   db "road in the way (hold Ctrl)", 0
s_ts_water  db "can't go on water", 0
s_ts_bld    db "a service is in the way", 0
s_ts_hwy    db "the highway is in the way", 0
s_replaces  db "replaces ", 0
s_bldgs     db " buildings", 0
s_bldg1     db " building", 0
s_resid     db " residents", 0
s_jobsn     db " jobs", 0
s_comma     db ", -", 0
s_colon     db ": -", 0
s_b_demol   db "Demolish", 0
s_b_repl    db "Replace with...", 0
s_b_move    db "Move", 0
s_b_up      db "Upgrade: ", 0
s_moving    db "Moving: ", 0
hx_moving   db "Click where it should go. It keeps", 10
            db "working until then. Moving costs", 10
            db "a quarter of building it new.", 10
            db 6, "Right-click to cancel.", 0
s_repl_t    db "Replace with", 0
s_nofit     db "no room", 0
s_moved     db "Moved.", 0
s_upgraded  db "Upgraded!", 0

section .text

; modifier keys held right now -> eax: 1 shift, 2 ctrl, 4 alt
FUNC keys_held
    xor edi, edi
    CALLC SDL_GetKeyboardState
    xor ecx, ecx
    mov dl, [rax+SC_LSHIFT]
    or dl, [rax+SC_RSHIFT]
    jz .s
    or ecx, 1
.s: mov dl, [rax+224]
    or dl, [rax+228]
    jz .c
    or ecx, 2
.c: mov dl, [rax+226]
    or dl, [rax+230]
    jz .a
    or ecx, 4
.a: mov eax, ecx
    RETURN

; can the building being placed (build_kind) stand with its corner at
; (edi, esi)?  -> eax 0 or TE_*.  fit_cost: what clearing the spot
; costs; fit_repl / fit_res / fit_jobs: zoned buildings that come down
FUNC bld_fit, 32
    mov r12d, edi
    mov r13d, esi
    mov dword [fit_cost], 0
    mov dword [fit_repl], 0
    mov dword [fit_res], 0
    mov dword [fit_jobs], 0
    mov dword [fit_nanch], 0
    mov dword [rbp-48], 0           ; water touching the footprint
    call keys_held
    mov [rbp-52], eax
    mov edi, [build_kind]
    call bld_rec
    mov r15, rax
    movzx r14d, byte [r15+BI_SIZE]
    xor ebx, ebx
.fy:
    xor ecx, ecx
.fx:
    mov [rbp-56], ecx
    lea edi, [r12+rcx]
    lea esi, [r13+rbx]
    call tile_owned
    test eax, eax
    jnz .own
    mov eax, TE_NOTOWNED
    RETURN
.own:
    mov ecx, [rbp-56]
    lea edi, [r12+rcx]
    lea esi, [r13+rbx]
    call tile_at
    cmp byte [rax+T_TERRAIN], TER_WATER
    jne .land
    mov eax, TE_WATER
    RETURN
.land:
    movzx ecx, byte [rax+T_OBJ]
    cmp ecx, OBJ_NONE
    je .ok
    cmp ecx, OBJ_TREE
    je .ok
    cmp ecx, OBJ_RUBBLE
    je .ok
    cmp ecx, OBJ_POWER
    jne .nzp
    add dword [fit_cost], 5
    jmp .ok
.nzp:
    cmp ecx, OBJ_ROAD
    jne .nrd
    test byte [rax+T_FLAGS], F_HIGHWAY
    jz .rd1
    mov eax, TE_HIGHWAY
    RETURN
.rd1:
    test dword [rbp-52], 2
    jnz .rd2
    mov eax, TE_ROAD
    RETURN
.rd2:
    add dword [fit_cost], 5
    jmp .ok
.nrd:
    cmp ecx, OBJ_ZONEBLD
    je .zb
    cmp ecx, OBJ_SERVICE
    jne .bad
    ; the building being moved or upgraded may stand in its own way
    mov ecx, [rbp-56]
    lea edi, [r12+rcx]
    lea esi, [r13+rbx]
    call anchor_of
    shl edx, MAP_SHIFT
    add eax, edx
    cmp eax, [move_from]
    je .ok
.bad:
    mov eax, TE_BUILDING
    RETURN
.zb:
    ; a zoned building comes down: count each one once
    mov ecx, [rbp-56]
    lea edi, [r12+rcx]
    lea esi, [r13+rbx]
    call anchor_of
    mov edi, edx
    shl edi, MAP_SHIFT
    add edi, eax
    xor ecx, ecx
.an:
    cmp ecx, [fit_nanch]
    jge .anew
    cmp [fit_anch+rcx*4], edi
    je .ok
    inc ecx
    jmp .an
.anew:
    cmp ecx, 16
    jge .ok
    mov [fit_anch+rcx*4], edi
    inc dword [fit_nanch]
    inc dword [fit_repl]
    mov eax, edi
    shl eax, TILE_SHIFT
    movzx ecx, word [tiles+rax+T_POP]
    movzx edx, byte [tiles+rax+T_ZONE]
    cmp byte [zone_class+rdx], ZC_RES
    jne .jb
    add [fit_res], ecx
    jmp .pr
.jb:
    add [fit_jobs], ecx
.pr:
    ; priced like the bulldozer: by level, for each of its tiles
    movzx ecx, byte [tiles+rax+T_LEVEL]
    imul ecx, 12
    add ecx, 5
    movzx edx, byte [tiles+rax+T_SIZE]
    CLAMP edx, 1, 2
    imul edx, edx
    imul ecx, edx
    add [fit_cost], ecx
.ok:
    mov ecx, [rbp-56]
    lea edi, [r12+rcx]
    lea esi, [r13+rbx]
    call count_water_near
    add [rbp-48], eax
    mov ecx, [rbp-56]
    inc ecx
    cmp ecx, r14d
    jl .fx
    inc ebx
    cmp ebx, r14d
    jl .fy
    cmp byte [r15+BI_NEEDWATER], 0
    je .fits
    cmp dword [rbp-48], 0
    jne .fits
    mov eax, TE_NEEDW
    RETURN
.fits:
    xor eax, eax
    RETURN

; the building's spot: (edi, esi) if it fits there, else the nearest
; spot up to 2 tiles away that does -> eax 0 and (r8d, r9d) the corner,
; or the error at (edi, esi)
FUNC bld_nudge, 16
    mov r12d, edi
    mov r13d, esi
    call bld_fit
    test eax, eax
    jz .here
    mov [rbp-48], eax
    xor ebx, ebx
.l:
    cmp ebx, NUDGE_N
    jge .none
    movsx r14d, byte [nudge_off+rbx*2]
    movsx r15d, byte [nudge_off+rbx*2+1]
    lea edi, [r12+r14]
    lea esi, [r13+r15]
    call bld_fit
    test eax, eax
    jz .found
    inc ebx
    jmp .l
.found:
    lea r8d, [r12+r14]
    lea r9d, [r13+r15]
    xor eax, eax
    RETURN
.none:
    ; leave the numbers of the spot under the pointer
    mov edi, r12d
    mov esi, r13d
    call bld_fit
    mov eax, [rbp-48]
.here:
    mov r8d, r12d
    mov r9d, r13d
    RETURN

; free the vehicles that belong to depot tile edi
vehicles_of_free:
    push rbx
    push r12
    push r13
    mov r12d, edi
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, 7
    lea rdi, [vehicles+rax]
    cmp byte [rdi+V_TYPE], 255
    je .n
    cmp [rdi+V_HOME], r12d
    jne .n
    call vehicle_free
.n:
    inc ebx
    cmp ebx, MAX_VEH
    jl .l
    pop r13
    pop r12
    pop rbx
    ret

; take away the service whose corner is (edi, esi), leaving edx
; (OBJ_NONE, or OBJ_RUBBLE for the bulldozer to sweep): its lot gets
; back the zone it had, its vehicles are gone
FUNC svc_remove, 16
    mov r12d, edi
    mov r13d, esi
    mov [rbp-48], edx
    call tile_at
    test rax, rax
    jz .out
    cmp byte [rax+T_OBJ], OBJ_SERVICE
    jne .out
    mov rdi, rax
    call footprint_size
    mov r14d, eax
    mov edi, r13d
    shl edi, MAP_SHIFT
    add edi, r12d
    call vehicles_of_free
    xor ebx, ebx
.y:
    xor r15d, r15d
.x:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call tile_at
    test rax, rax
    jz .n
    mov ecx, [rbp-48]
    mov [rax+T_OBJ], cl
    mov byte [rax+T_FLAGS], 0
    and byte [rax+T_FLAGS2], F2_PIPE
    mov byte [rax+T_LEVEL], 0
    mov byte [rax+T_TIMER], 0
    mov word [rax+T_POP], 0
    mov byte [rax+T_ANCHOR], 0
    mov byte [rax+T_SUB], 0
    mov byte [rax+T_PROBLEM], 0
    lea edi, [r13+rbx]
    shl edi, MAP_SHIFT
    add edi, r12d
    add edi, r15d
    movzx ecx, byte [svc_zone+rdi]
    mov [rax+T_ZONE], cl
    mov byte [svc_zone+rdi], 0
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call roads_update_around
.n:
    inc r15d
    cmp r15d, r14d
    jl .x
    inc ebx
    cmp ebx, r14d
    jl .y
    mov edi, r12d
    mov esi, r13d
    call fx_smoke_burst
    mov dword [net_dirty], 1
    mov dword [cov_dirty], 1
.out:
    RETURN

; clear the spot with its corner at (edi, esi) for the building being
; placed: the moved building leaves, zoned buildings come down whole,
; roads and pylons go; the zones underneath are remembered
FUNC bld_clear, 16
    mov r12d, edi
    mov r13d, esi
    mov eax, [move_from]
    test eax, eax
    js .nm
    mov edi, eax
    and edi, MAP_W-1
    mov esi, eax
    shr esi, MAP_SHIFT
    mov edx, OBJ_NONE
    call svc_remove
.nm:
    mov edi, [build_kind]
    call bld_rec
    movzx r14d, byte [rax+BI_SIZE]
    xor ebx, ebx
.y:
    xor r15d, r15d
.x:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call tile_at
    test rax, rax
    jz .n
    movzx ecx, byte [rax+T_OBJ]
    cmp ecx, OBJ_ZONEBLD
    jne .nz
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call destroy_to_rubble
    jmp .n
.nz:
    cmp ecx, OBJ_ROAD
    je .clr
    cmp ecx, OBJ_POWER
    jne .n
.clr:
    mov byte [rax+T_OBJ], OBJ_NONE
    mov byte [rax+T_FLAGS], 0
    and byte [rax+T_FLAGS2], F2_PIPE
    mov byte [rax+T_LEVEL], 0
    mov word [rax+T_POP], 0
    mov dword [rax+T_OCC], 0
    mov byte [rax+T_ROADTYPE], 0
.n:
    inc r15d
    cmp r15d, r14d
    jl .x
    inc ebx
    cmp ebx, r14d
    jl .y
    ; rubble around it (big buildings reach outside the spot): cleared,
    ; its zone stays and grows again
    mov ebx, -1
.ry:
    mov r15d, -1
.rx:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call tile_at
    test rax, rax
    jz .rn
    cmp byte [rax+T_OBJ], OBJ_RUBBLE
    jne .rn
    mov byte [rax+T_OBJ], OBJ_NONE
.rn:
    inc r15d
    cmp r15d, r14d
    jle .rx
    inc ebx
    cmp ebx, r14d
    jle .ry
    call wires_cleanup
    RETURN

; ---------------------------------------------------------------------
;  the tool: evaluate (tl_x/tl_y[0] is the corner under the pointer)
; ---------------------------------------------------------------------
FUNC build_eval_beta
    mov edi, [tl_x]
    mov esi, [tl_y]
    call bld_nudge
    test eax, eax
    jz .ok
    mov [last_tool_err], eax
    RETURN
.ok:
    mov [tl_x], r8d
    mov [tl_y], r9d
    mov byte [tl_ok], 1
    mov dword [tl_valid], 1
    mov edi, [build_kind]
    call bld_rec
    mov eax, [rax+BI_COST]
    cmp dword [moving], 0
    je .c
    shr eax, 2                      ; moving: a quarter
.c:
    add eax, [fit_cost]
    mov [tl_cost], eax
    RETURN

; world preview extras: what comes down, where a moved building was
FUNC build_preview_beta, 16
    cmp dword [tl_valid], 0
    je .mv
    mov edi, [build_kind]
    call bld_rec
    movzx r14d, byte [rax+BI_SIZE]
    xor ebx, ebx
.y:
    xor r15d, r15d
.x:
    mov edi, [tl_x]
    add edi, r15d
    mov esi, [tl_y]
    add esi, ebx
    call tile_at
    test rax, rax
    jz .n
    movzx ecx, byte [rax+T_OBJ]
    cmp ecx, OBJ_ZONEBLD
    je .mark
    cmp ecx, OBJ_ROAD
    je .mark
    cmp ecx, OBJ_POWER
    jne .n
.mark:
    mov edi, [tl_x]
    add edi, r15d
    mov esi, [tl_y]
    add esi, ebx
    mov edx, 1
    mov ecx, RAMP(R_ORANGE, 6)
    call draw_diamond
.n:
    inc r15d
    cmp r15d, r14d
    jl .x
    inc ebx
    cmp ebx, r14d
    jl .y
.mv:
    mov eax, [move_from]
    test eax, eax
    js .out
    mov edi, eax
    and edi, MAP_W-1
    mov esi, eax
    shr esi, MAP_SHIFT
    call tile_at
    test rax, rax
    jz .out
    mov rdi, rax
    call footprint_size
    mov edx, eax
    mov eax, [move_from]
    mov edi, eax
    and edi, MAP_W-1
    mov esi, eax
    shr esi, MAP_SHIFT
    mov ecx, RAMP(R_GLASS, 5)
    call draw_diamond
.out:
    RETURN

; the price tag's second line: "replaces 2 buildings: -34 residents"
; into textbuf -> eax 1 if there is one
FUNC build_repl_text
    xor eax, eax
    cmp dword [fit_repl], 0
    je .out
    call tb_reset
    lea rdi, [s_replaces]
    call tb_str
    movsxd rdi, dword [fit_repl]
    call tb_num
    lea rdi, [s_bldgs]
    cmp dword [fit_repl], 1
    jne .p
    lea rdi, [s_bldg1]
.p:
    call tb_str
    lea r12, [s_colon]
    cmp dword [fit_res], 0
    je .j
    mov rdi, r12
    call tb_str
    movsxd rdi, dword [fit_res]
    call tb_num
    lea rdi, [s_resid]
    call tb_str
    lea r12, [s_comma]
.j:
    cmp dword [fit_jobs], 0
    je .d
    mov rdi, r12
    call tb_str
    movsxd rdi, dword [fit_jobs]
    call tb_num
    lea rdi, [s_jobsn]
    call tb_str
.d:
    mov eax, 1
.out:
    RETURN

; ---------------------------------------------------------------------
;  inspector actions
; ---------------------------------------------------------------------
; the spot for a kind (edi) over the selected building -> eax 0 and
; (r8d, r9d) its corner, else an error.  The new footprint covers the
; old building's corner; the spot nearest the middle wins.
FUNC spot_over_sel, 48
    mov [rbp-48], edi
    mov eax, [build_kind]
    mov [rbp-52], eax
    mov [build_kind], edi
    mov edi, [sel_x]
    mov esi, [sel_y]
    call tile_at
    mov rdi, rax
    call footprint_size
    mov [rbp-56], eax               ; old size
    mov edi, [rbp-48]
    call bld_rec
    movzx eax, byte [rax+BI_SIZE]
    mov [rbp-60], eax               ; new size
    ; corners from sel + min(0, s-S) .. sel + max(0, s-S)
    mov ecx, [rbp-56]
    sub ecx, eax
    xor edx, edx
    mov r8d, ecx
    cmp ecx, 0
    cmovg r8d, edx                  ; lo offset
    cmovl ecx, edx                  ; hi offset
    mov [rbp-64], r8d
    mov [rbp-68], ecx
    ; the middle: (s - S) / 2
    mov eax, [rbp-56]
    sub eax, [rbp-60]
    sar eax, 1
    mov [rbp-72], eax
    mov dword [rbp-76], 1000        ; best distance
    mov dword [rbp-80], TE_BUILDING ; error if none fits
    mov ebx, [rbp-64]
.y:
    cmp ebx, [rbp-68]
    jg .done
    mov r12d, [rbp-64]
.x:
    cmp r12d, [rbp-68]
    jg .yn
    mov edi, [sel_x]
    add edi, r12d
    mov esi, [sel_y]
    add esi, ebx
    call bld_fit
    test eax, eax
    jz .fits
    mov [rbp-80], eax
    jmp .xn
.fits:
    mov eax, r12d
    sub eax, [rbp-72]
    cdq
    xor eax, edx
    sub eax, edx
    mov ecx, ebx
    sub ecx, [rbp-72]
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx
    add eax, ecx
    cmp eax, [rbp-76]
    jge .xn
    mov [rbp-76], eax
    mov [rbp-84], r12d
    mov [rbp-88], ebx
.xn:
    inc r12d
    jmp .x
.yn:
    inc ebx
    jmp .y
.done:
    cmp dword [rbp-76], 1000
    je .fail
    ; the numbers for the chosen spot
    mov r13d, [sel_x]
    add r13d, [rbp-84]
    mov r14d, [sel_y]
    add r14d, [rbp-88]
    mov edi, r13d
    mov esi, r14d
    call bld_fit
    mov r8d, r13d
    mov r9d, r14d
    xor eax, eax
    jmp .out
.fail:
    mov eax, [rbp-80]
.out:
    mov ecx, [rbp-52]
    mov [build_kind], ecx
    RETURN

; put building kind edi over the selected building for eax money:
; a normal placement (undo, dust, sound); the inspector then shows it
FUNC place_over_sel, 16
    mov [rbp-48], edi
    mov [rbp-52], esi               ; price (without clearing)
    call spot_over_sel
    test eax, eax
    jz .fits
    mov rdi, [te_msgs+rax*8]
    test rdi, rdi
    jnz .msg
    lea rdi, [s_te_bld]
.msg:
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_ERROR
    call sfx_play
    xor eax, eax
    RETURN
.fits:
    mov r12d, r8d
    mov r13d, r9d
    mov eax, [tool]
    mov [rbp-56], eax
    mov eax, [build_kind]
    mov [rbp-60], eax
    mov eax, [rbp-48]
    mov [build_kind], eax
    mov dword [tool], T_BUILD
    mov dword [tl_n], 1
    mov [tl_x], r12d
    mov [tl_y], r13d
    mov byte [tl_ok], 1
    mov dword [tl_valid], 1
    mov eax, [rbp-52]
    add eax, [fit_cost]
    mov [tl_cost], eax
    mov dword [last_tool_err], 0
    mov dword [force_place], 1
    mov r14, [money]
    call tool_apply
    mov dword [force_place], 0
    mov eax, [rbp-56]
    mov [tool], eax
    mov eax, [rbp-60]
    mov [build_kind], eax
    ; placed?  (the money went)
    xor eax, eax
    cmp r14, [money]
    je .out
    mov [sel_x], r12d
    mov [sel_y], r13d
    mov dword [repl_open], 0
    mov eax, 1
.out:
    mov dword [move_from], -1
    RETURN

; demolish the selected building, priced like the bulldozer
FUNC insp_demolish, 16
    mov edi, [sel_x]
    mov esi, [sel_y]
    call tile_at
    test rax, rax
    jz .out
    mov rbx, rax
    mov rdi, rax
    call footprint_size
    mov r14d, eax
    imul eax, eax
    mov ecx, 40
    cmp byte [rbx+T_OBJ], OBJ_SERVICE
    je .c
    movzx ecx, byte [rbx+T_LEVEL]
    imul ecx, 12
    add ecx, 5
.c:
    imul eax, ecx
    mov [rbp-48], eax               ; cost
    movsxd rax, eax
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
    call undo_begin
    mov r12d, [sel_x]
    mov r13d, [sel_y]
    cmp byte [rbx+T_OBJ], OBJ_SERVICE
    jne .zone
    mov edi, r12d
    mov esi, r13d
    mov edx, OBJ_NONE
    call svc_remove
    jmp .done
.zone:
    mov edi, r12d
    mov esi, r13d
    call destroy_to_rubble
    ; the rubble is cleared away, the zone stays
    xor ebx, ebx
.y:
    xor r15d, r15d
.x:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call tile_at
    test rax, rax
    jz .n
    cmp byte [rax+T_OBJ], OBJ_RUBBLE
    jne .n
    mov byte [rax+T_OBJ], OBJ_NONE
.n:
    inc r15d
    cmp r15d, r14d
    jl .x
    inc ebx
    cmp ebx, r14d
    jl .y
.done:
    call wires_cleanup
    mov dword [net_dirty], 1
    mov dword [cov_dirty], 1
    ; (undo remembers the tool: this was the bulldozer's job)
    mov eax, [tool]
    mov [rbp-52], eax
    mov dword [tool], T_BULLDOZE
    mov edi, [rbp-48]
    call undo_end
    mov eax, [rbp-52]
    mov [tool], eax
    mov edi, SFX_BULLDOZE
    call sfx_play
    mov dword [sel_x], -1
.out:
    RETURN

; the upgrade of a service kind (edi) -> eax new kind or -1
upgrade_of:
    xor ecx, ecx
.l:
    mov eax, [upgrade_t+rcx*8]
    cmp eax, -1
    je .no
    cmp eax, edi
    je .y
    inc ecx
    jmp .l
.y: mov eax, [upgrade_t+rcx*8+4]
    ret
.no:
    mov eax, -1
    ret

; a small button with a label and an optional price after it
; (edi x, esi y, edx w, rcx label, r8d price or 0) -> eax clicked
FUNC price_button, 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15, rcx
    mov [rbp-48], r8d
    mov ecx, 13
    mov r8, r15
    call ui_note_button
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, 13
    xor r8d, r8d
    call button
    mov ebx, eax
    call tb_reset
    mov rdi, r15
    call tb_str
    cmp dword [rbp-48], 0
    je .d
    mov edi, ' '
    call tb_char
    mov edi, 7
    call tb_char
    movsxd rdi, dword [rbp-48]
    call tb_money
.d:
    mov edi, r14d
    shr edi, 1
    add edi, r12d
    lea esi, [r13+3]
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call draw_text_centered
    mov eax, ebx
    RETURN

; the inspector's buttons for the selected building, drawn at row_y
FUNC insp_actions, 32
    cmp dword [beta_on], 0
    je .out
    cmp dword [sel_x], 0
    jl .out
    mov edi, [sel_x]
    mov esi, [sel_y]
    call tile_at
    test rax, rax
    jz .out
    mov rbx, rax
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_ZONEBLD
    je .zone
    cmp eax, OBJ_SERVICE
    je .svc
    jmp .out
.zone:
    test byte [rbx+T_FLAGS], F_BUILD
    jnz .out
    add dword [row_y], 3
    mov rdi, rbx
    call footprint_size
    imul eax, eax
    movzx ecx, byte [rbx+T_LEVEL]
    imul ecx, 12
    add ecx, 5
    imul eax, ecx
    mov r8d, eax
    mov edi, [row_x]
    add edi, 6
    mov esi, [row_y]
    mov edx, 82
    lea rcx, [s_b_demol]
    call price_button
    test eax, eax
    jz .z1
    call insp_demolish
    jmp .out
.z1:
    mov edi, [row_x]
    add edi, 92
    mov esi, [row_y]
    mov edx, 82
    lea rcx, [s_b_repl]
    xor r8d, r8d
    call price_button
    test eax, eax
    jz .z2
    xor dword [repl_open], 1
    mov dword [repl_scroll], 0
.z2:
    add dword [row_y], 16
    jmp .out
.svc:
    add dword [row_y], 3
    mov rdi, rbx
    call footprint_size
    imul eax, eax
    imul r8d, eax, 40
    mov edi, [row_x]
    add edi, 6
    mov esi, [row_y]
    mov edx, 82
    lea rcx, [s_b_demol]
    call price_button
    test eax, eax
    jz .s1
    call insp_demolish
    jmp .out
.s1:
    movzx edi, byte [rbx+T_SUB]
    call bld_rec
    mov r8d, [rax+BI_COST]
    shr r8d, 2
    mov edi, [row_x]
    add edi, 92
    mov esi, [row_y]
    mov edx, 82
    lea rcx, [s_b_move]
    call price_button
    test eax, eax
    jz .s2
    ; pick it up: the build tool, placing this building again
    movzx eax, byte [rbx+T_SUB]
    mov [build_kind], eax
    mov eax, [sel_y]
    shl eax, MAP_SHIFT
    add eax, [sel_x]
    mov [move_from], eax
    mov dword [moving], 1
    mov dword [tool], T_BUILD
    mov dword [sel_x], -1
    mov dword [repl_open], 0
    jmp .out
.s2:
    add dword [row_y], 16
    ; an upgrade, if it has one and it's unlocked
    movzx edi, byte [rbx+T_SUB]
    call upgrade_of
    cmp eax, -1
    je .out
    mov r12d, eax
    mov edi, r12d
    call bld_rec
    mov r13, rax
    mov ecx, [r13+BI_UNLOCK]
    call unlocked_pop
    cmp eax, ecx
    jl .out
    ; the new one, less half of what the old one cost
    movzx edi, byte [rbx+T_SUB]
    call bld_rec
    mov eax, [rax+BI_COST]
    shr eax, 1
    mov r14d, [r13+BI_COST]
    sub r14d, eax
    call tb_reset
    lea rdi, [s_b_up]
    call tb_str
    mov rdi, [r13+BI_NAME]
    call tb_str
    lea rsi, [textbuf]
    lea rdi, [ms_tipbuf]
    mov ecx, 95
    rep movsb
    mov byte [ms_tipbuf+95], 0
    mov edi, [row_x]
    add edi, 6
    mov esi, [row_y]
    mov edx, 168
    lea rcx, [ms_tipbuf]
    mov r8d, r14d
    call price_button
    add dword [row_y], 16
    test eax, eax
    jz .out
    ; the old building makes way for the new one
    mov eax, [sel_y]
    shl eax, MAP_SHIFT
    add eax, [sel_x]
    mov [move_from], eax
    mov edi, r12d
    mov esi, r14d
    call place_over_sel
    test eax, eax
    jz .out
    lea rdi, [s_upgraded]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; the "replace with" list next to the inspector: every unlocked service
; with its price over the selected building, in two columns
RL_W equ 150
FUNC draw_replace_list, 48
    cmp dword [repl_open], 0
    je .out
    cmp dword [beta_on], 0
    je .out
    cmp dword [sel_x], 0
    jl .close
    cmp dword [tool], T_INSPECT
    jne .close
    mov edi, [sel_x]
    mov esi, [sel_y]
    call tile_at
    test rax, rax
    jz .close
    cmp byte [rax+T_OBJ], OBJ_ZONEBLD
    jne .close
    ; count the unlocked kinds
    xor ebx, ebx
    xor r12d, r12d
.c:
    mov edi, ebx
    call bld_rec
    mov ecx, [rax+BI_UNLOCK]
    call unlocked_pop
    cmp eax, ecx
    jl .cn
    inc r12d
.cn:
    inc ebx
    cmp ebx, BK_COUNT
    jl .c
    inc r12d
    shr r12d, 1                     ; rows
    mov [rbp-68], r12d
    imul ecx, r12d, 15
    add ecx, 22
    mov r13d, 192                   ; x
    mov r14d, 38                    ; y
    mov edi, r13d
    mov esi, r14d
    mov edx, RL_W*2+10
    call draw_panel
    lea edi, [r13+6]
    lea esi, [r14+4]
    lea rdx, [s_repl_t]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [rbp-72], 0           ; entries so far
    xor ebx, ebx
.k:
    cmp ebx, BK_COUNT
    jge .out
    mov edi, ebx
    call bld_rec
    mov r15, rax
    mov ecx, [r15+BI_UNLOCK]
    call unlocked_pop
    cmp eax, ecx
    jl .kn
    ; its place: down the first column, then the second
    mov eax, [rbp-72]
    xor edx, edx
    div dword [rbp-68]
    imul eax, RL_W+2
    lea eax, [r13+rax+4]
    mov [rbp-76], eax               ; x
    imul edx, 15
    lea edx, [r14+rdx+18]
    mov [rbp-52], edx               ; y
    inc dword [rbp-72]
    ; does it fit, and for how much?
    mov edi, ebx
    call spot_over_sel
    mov [rbp-56], eax
    mov eax, [r15+BI_COST]
    add eax, [fit_cost]
    mov [rbp-60], eax
    mov edi, [rbp-76]
    mov esi, [rbp-52]
    mov edx, RL_W
    mov ecx, 14
    mov r8, [r15+BI_NAME]
    call ui_note_button
    mov edi, [rbp-76]
    mov esi, [rbp-52]
    mov edx, RL_W
    mov ecx, 14
    xor r8d, r8d
    call button
    mov [rbp-64], eax
    mov edi, [rbp-76]
    add edi, 4
    mov esi, [rbp-52]
    add esi, 3
    mov rdx, [r15+BI_NAME]
    mov ecx, UI_TEXT
    cmp dword [rbp-56], 0
    je .nm
    mov ecx, UI_DIM
.nm:
    call draw_text
    call tb_reset
    cmp dword [rbp-56], 0
    jne .nf
    movsxd rdi, dword [rbp-60]
    call tb_money
    mov ecx, UI_GOLD
    jmp .pr
.nf:
    lea rdi, [s_nofit]
    call tb_str
    mov ecx, UI_BAD
.pr:
    mov edi, [rbp-76]
    add edi, RL_W-3
    mov esi, [rbp-52]
    add esi, 3
    lea rdx, [textbuf]
    call draw_text_right
    cmp dword [rbp-64], 0
    je .kn
    cmp dword [rbp-56], 0
    jne .kn
    mov edi, ebx
    mov esi, [r15+BI_COST]
    call place_over_sel
    jmp .out
.kn:
    inc ebx
    jmp .k
.close:
    mov dword [repl_open], 0
.out:
    RETURN

; after the build tool placed a building (edi x, esi y corner): a moved
; building is done moving and gets inspected where it now stands
FUNC build_placed_beta
    cmp dword [moving], 0
    je .out
    mov dword [moving], 0
    mov dword [move_from], -1
    mov [sel_x], edi
    mov [sel_y], esi
    mov dword [tool], T_INSPECT
    lea rdi, [s_moved]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; the hint panel's title while moving -> rax (or 0 when not moving)
FUNC move_hint_title
    xor eax, eax
    cmp dword [moving], 0
    je .out
    call tb_reset
    lea rdi, [s_moving]
    call tb_str
    mov edi, [build_kind]
    call bld_rec
    mov rdi, [rax+BI_NAME]
    call tb_str
    lea rsi, [textbuf]
    lea rdi, [move_title]
    mov ecx, 63
    rep movsb
    mov byte [move_title+63], 0
    lea rax, [move_title]
.out:
    RETURN

; forget the building state of a city (new or loaded)
extra_reset:
    push rdi
    lea rdi, [svc_zone]
    mov ecx, MAP_TILES/8
    xor eax, eax
    rep stosq
    mov dword [move_from], -1
    mov dword [moving], 0
    mov dword [repl_open], 0
    pop rdi
    ret
