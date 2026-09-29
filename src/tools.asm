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
BOOKMARKS   equ 4
bookmarks   resd BOOKMARKS*3        ; x, y, zoom (zoom 0: unset)
cam_prev    resd 3                  ; where the view was before a jump
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
    cmp dword [tl_n], 1
    jle .one
    call build_eval_many
    RETURN
.one:
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
    ; a row: every building in it (the first was drawn already)
    cmp dword [tl_n], 1
    jle .one
    mov ebx, 1
.row:
    cmp ebx, [tl_n]
    jge .mv
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    call tile_screen
    mov esi, eax
    mov eax, [build_kind]
    mov edi, [spr_bld+rax*4]
    mov ecx, 60000
    lea r8, [remap_green]
    cmp byte [tl_ok+rbx], 0
    jne .rg
    lea r8, [remap_red]
.rg:
    call blit_sprite
    inc ebx
    jmp .row
.one:
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
    lea rdi, [bookmarks]
    mov ecx, BOOKMARKS*3
    xor eax, eax
    rep stosd
    mov dword [cam_prev+8], 0
    pop rdi
    ret

; =====================================================================
;  road modes (beta): L-shape, straight (or Shift), freehand, grid;
;  pipes laid under new roads; Ctrl builds through homes and shops.
;  zone modes (beta): area, fill a block, along a road; lots too far
;  from a road are marked, and the price tag says what will grow.
; =====================================================================
RM_L        equ 0
RM_STRAIGHT equ 1
RM_FREE     equ 2
RM_GRID     equ 3
ZM_AREA     equ 0
ZM_FILL     equ 1
ZM_ROAD     equ 2

section .bss
fh_n        resd 1                  ; freehand path so far
fh_x        resd MAX_TL
fh_y        resd MAX_TL
fill_stamp  resb MAP_TILES          ; tiles taken this collect (fill_gen)
fill_gen    resd 1
tl_blocked  resd 1                  ; road tiles blocked by buildings
tl_far      resd 1                  ; zoned lots out of a road's reach
tl_farf     resb MAX_TL
ev_keys     resd 1                  ; modifiers during this evaluation
fill_q      resd MAX_TL
tl_here     resb MAP_TILES

section .data
s_rm_names  dq s_rm0, s_rm1, s_rm2, s_rm3
s_rm0       db "L-shape", 0
s_rm1       db "Straight", 0
s_rm2       db "Freehand", 0
s_rm3       db "Grid", 0
s_zm_names  dq s_zm0, s_zm1, s_zm2
s_zm0       db "Area", 0
s_zm1       db "Fill block", 0
s_zm2       db "Along road", 0
s_pipes_on  db "+ pipes: on", 0
s_pipes_off db "+ pipes: off", 0
s_blocks    db "Blocks: ", 0
s_blk_sub   db "-", 0
s_blk_add   db "+", 0
s_blocked1  db " tiles are blocked by buildings - hold Ctrl to build", 0
s_blocked2  db " through homes and shops.", 0
s_far1      db " lots too far from a road", 0
s_est1      db "~", 0
s_est2      db " now, up to ", 0
s_est_res   db " residents", 0
s_est_jobs  db " jobs", 0
s_modekey   db 6, "G: next mode", 0

section .text

; next generation of the fill stamps
fill_next_gen:
    inc dword [fill_gen]
    mov eax, [fill_gen]
    and eax, 255
    jnz .ok
    push rdi
    push rcx
    lea rdi, [fill_stamp]
    mov ecx, MAP_TILES/8
    xor eax, eax
    rep stosq
    pop rcx
    pop rdi
    mov dword [fill_gen], 1
.ok:
    ret

; tl_push unless the tile is already in the list (fill stamps)
; (edi x, esi y)
tl_push_once:
    cmp edi, MAP_W
    jae .o
    cmp esi, MAP_W
    jae .o
    mov eax, esi
    shl eax, MAP_SHIFT
    add eax, edi
    mov cl, [fill_gen]
    cmp [fill_stamp+rax], cl
    je .o
    mov [fill_stamp+rax], cl
    jmp tl_push
.o: ret

; the road tool's mode right now (the tour always draws L-shapes)
FUNC road_mode_now
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp dword [tut_step], 0
    jge .out
    mov eax, [set_road_mode]
    cmp eax, RM_GRID
    je .out
    push rax
    push rax
    call keys_held
    mov ecx, eax
    pop rax
    pop rax
    test ecx, 1
    jz .out
    mov eax, RM_STRAIGHT
.out:
    RETURN

; lay pipes under new roads? (beta, not in the tour)
road_pipes_now:
    xor eax, eax
    cmp dword [beta_on], 0
    je .o
    cmp dword [tut_step], 0
    jge .o
    mov eax, [set_road_pipes]
.o: ret

; the zone tool's mode right now
zone_mode_now:
    xor eax, eax
    cmp dword [beta_on], 0
    je .o
    cmp dword [tut_step], 0
    jge .o
    cmp dword [tool], T_ZONETOOL
    jne .o
    mov eax, [set_zone_mode]
.o: ret

; follow the pointer while a freehand road is dragged (every frame)
FUNC freehand_track
    cmp dword [drag_active], 0
    je .reset
    cmp dword [tool], T_ROAD
    jne .reset
    call road_mode_now
    cmp eax, RM_FREE
    jne .reset
    cmp dword [fh_n], 0
    jne .have
    mov eax, [drag_sx]
    mov [fh_x], eax
    mov eax, [drag_sy]
    mov [fh_y], eax
    mov dword [fh_n], 1
.have:
    cmp dword [hover_valid], 0
    je .out
.step:
    mov ebx, [fh_n]
    mov r12d, [fh_x+rbx*4-4]
    mov r13d, [fh_y+rbx*4-4]
    mov eax, [hover_tx]
    sub eax, r12d
    mov ecx, [hover_ty]
    sub ecx, r13d
    mov edx, eax
    or edx, ecx
    jz .out
    ; one tile toward the pointer, along the longer way first
    mov r8d, eax
    sar r8d, 31
    mov r9d, eax
    xor r9d, r8d
    sub r9d, r8d                    ; |dx|
    mov r8d, ecx
    sar r8d, 31
    mov r10d, ecx
    xor r10d, r8d
    sub r10d, r8d                   ; |dy|
    cmp r9d, r10d
    jl .sy
    mov edx, 1
    test eax, eax
    jns .sx
    neg edx
.sx:
    add r12d, edx
    jmp .push
.sy:
    mov edx, 1
    test ecx, ecx
    jns .sy2
    neg edx
.sy2:
    add r13d, edx
.push:
    ; going back over the path takes the last tile off
    cmp ebx, 2
    jl .add
    cmp [fh_x+rbx*4-8], r12d
    jne .add
    cmp [fh_y+rbx*4-8], r13d
    jne .add
    dec dword [fh_n]
    jmp .step
.add:
    cmp ebx, MAX_TL
    jge .out
    mov [fh_x+rbx*4], r12d
    mov [fh_y+rbx*4], r13d
    inc dword [fh_n]
    jmp .step
.reset:
    mov dword [fh_n], 0
.out:
    RETURN

; the road tool's tiles in beta modes (r14d, r15d start; r12d, r13d
; end) -> eax 0: draw the L-shape, 1: done, 2: straight (L with the
; end moved onto the start's row or column)
FUNC road_collect_beta, 32
    mov [rbp-48], edi
    mov [rbp-52], esi
    mov [rbp-56], edx
    mov [rbp-60], ecx
    call road_mode_now
    cmp eax, RM_STRAIGHT
    je .straight
    cmp eax, RM_FREE
    je .free
    cmp eax, RM_GRID
    je .grid
    xor eax, eax
    RETURN
.straight:
    mov eax, 2
    RETURN
.free:
    xor ebx, ebx
.fl:
    cmp ebx, [fh_n]
    jge .done
    mov edi, [fh_x+rbx*4]
    mov esi, [fh_y+rbx*4]
    call tl_push
    inc ebx
    jmp .fl
.grid:
    ; the rectangle, with a road every set_grid_step tiles both ways
    ; and along the far edges; roads already there are left alone
    mov eax, [rbp-48]
    mov ecx, [rbp-56]
    cmp eax, ecx
    jle .gx
    xchg eax, ecx
.gx:
    mov r12d, eax                   ; x0
    mov r13d, ecx                   ; x1
    mov eax, [rbp-52]
    mov ecx, [rbp-60]
    cmp eax, ecx
    jle .gy
    xchg eax, ecx
.gy:
    mov r14d, eax                   ; y0
    mov r15d, ecx                   ; y1
    mov ebx, r14d
.yl:
    cmp ebx, r15d
    jg .done
    ; a row line?
    mov eax, ebx
    sub eax, r14d
    xor edx, edx
    div dword [set_grid_step]
    xor r8d, r8d
    test edx, edx
    jnz .r1
    mov r8d, 1
.r1:
    cmp ebx, r15d
    jne .r2
    mov r8d, 1
.r2:
    mov [rbp-64], r8d
    mov ecx, r12d
.xl:
    cmp ecx, r13d
    jg .yn
    mov [rbp-68], ecx
    cmp dword [rbp-64], 0
    jne .on
    mov eax, ecx
    sub eax, r12d
    xor edx, edx
    div dword [set_grid_step]
    test edx, edx
    jz .on
    cmp ecx, r13d
    jne .xn
.on:
    mov edi, [rbp-68]
    mov esi, ebx
    call is_road
    test eax, eax
    jnz .xn
    mov edi, [rbp-68]
    mov esi, ebx
    call tl_push
.xn:
    mov ecx, [rbp-68]
    inc ecx
    jmp .xl
.yn:
    inc ebx
    jmp .yl
.done:
    mov eax, 1
    RETURN

; extra cost of a road tile (r12 its tile): a pipe laid under it
road_pipe_cost:
    xor eax, eax
    test byte [r12+T_FLAGS2], F2_PIPE
    jnz .o
    push rcx
    push rdx
    call road_pipes_now
    pop rdx
    pop rcx
    test eax, eax
    jz .o
    mov eax, 5
.o: ret

; can the road go through what's on this tile (r12 tile, ecx object)?
; -> eax extra cost, or -1 if not.  Ctrl held: homes, shops and pylons
; make way (beta).  Counts the blocked tiles.
road_through_cost:
    cmp dword [beta_on], 0
    je .no
    cmp ecx, OBJ_ZONEBLD
    je .z
    cmp ecx, OBJ_POWER
    je .p
    cmp ecx, OBJ_SERVICE
    jne .no
    inc dword [tl_blocked]
    jmp .no
.z:
    test dword [ev_keys], 2
    jz .blk
    movzx eax, byte [r12+T_LEVEL]
    imul eax, 12
    add eax, 5
    ret
.p:
    test dword [ev_keys], 2
    jz .blk
    mov eax, 5
    ret
.blk:
    inc dword [tl_blocked]
.no:
    mov eax, -1
    ret

; before a road goes on a tile (r12 tile; r13d, r14d its x, y): what
; was built there comes down (beta, Ctrl)
FUNC road_clear_tile
    cmp byte [r12+T_OBJ], OBJ_ZONEBLD
    jne .out
    mov edi, r13d
    mov esi, r14d
    call destroy_to_rubble
.out:
    RETURN

; after the road tool (beta): pipes under the new roads, the rubble of
; homes it went through swept (their zones stay), and a word about
; tiles buildings blocked
FUNC road_after_beta, 16
    cmp dword [beta_on], 0
    je .out
    call road_pipes_now
    mov [rbp-48], eax
    xor ebx, ebx
.l:
    cmp ebx, [tl_n]
    jge .msg
    cmp byte [tl_ok+rbx], 0
    je .n
    mov r13d, [tl_x+rbx*4]
    mov r14d, [tl_y+rbx*4]
    mov edi, r13d
    mov esi, r14d
    call tile_at
    test rax, rax
    jz .n
    cmp dword [rbp-48], 0
    je .sw
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .sw
    or byte [rax+T_FLAGS2], F2_PIPE
.sw:
    mov r15d, -1
.sy:
    mov r12d, -1
.sx:
    lea edi, [r13+r12]
    lea esi, [r14+r15]
    call tile_at
    test rax, rax
    jz .snx
    cmp byte [rax+T_OBJ], OBJ_RUBBLE
    jne .snx
    cmp byte [rax+T_ZONE], 0
    je .snx
    mov byte [rax+T_OBJ], OBJ_NONE
.snx:
    inc r12d
    cmp r12d, 1
    jle .sx
    inc r15d
    cmp r15d, 1
    jle .sy
.n:
    inc ebx
    jmp .l
.msg:
    call wires_cleanup
    call road_blocked_msg
.out:
    RETURN

; "5 tiles are blocked by buildings - hold Ctrl ..."
FUNC road_blocked_msg
    cmp dword [beta_on], 0
    je .out
    cmp dword [tool], T_ROAD
    jne .out
    cmp dword [tl_blocked], 0
    je .out
    test dword [ev_keys], 2
    jnz .out
    call tb_reset
    movsxd rdi, dword [tl_blocked]
    call tb_num
    lea rdi, [s_blocked1]
    call tb_str
    lea rdi, [s_blocked2]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; can this tile be zoned (edi x, esi y)? -> eax 1
FUNC zonable
    mov r12d, edi
    mov r13d, esi
    call tile_owned
    test eax, eax
    jz .no
    mov edi, r12d
    mov esi, r13d
    call tile_at
    test rax, rax
    jz .no
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .no
    movzx ecx, byte [rax+T_OBJ]
    cmp ecx, OBJ_NONE
    je .y
    cmp ecx, OBJ_TREE
    je .y
    cmp ecx, OBJ_RUBBLE
    je .y
    cmp ecx, OBJ_ZONEBLD
    je .y
.no:
    xor eax, eax
    RETURN
.y:
    mov eax, 1
    RETURN

; fill: every zonable lot a road reaches, connected to (edi, esi)
; without crossing roads or buildings -> tl
FUNC zone_fill_collect, 16
    mov [rbp-48], edi
    mov [rbp-52], esi
    call fill_next_gen
    call zonable
    test eax, eax
    jz .out
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call road_near
    test eax, eax
    jz .out
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call tl_push_once
    xor ebx, ebx                    ; queue head (the tl list is the queue)
.q:
    cmp ebx, [tl_n]
    jge .out
    xor r14d, r14d
.d:
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    add edi, [dir_dx+r14*4]
    add esi, [dir_dy+r14*4]
    mov r12d, edi
    mov r13d, esi
    cmp edi, MAP_W
    jae .dn
    cmp esi, MAP_W
    jae .dn
    mov eax, esi
    shl eax, MAP_SHIFT
    add eax, edi
    mov cl, [fill_gen]
    cmp [fill_stamp+rax], cl
    je .dn
    call zonable
    test eax, eax
    jz .dn
    mov edi, r12d
    mov esi, r13d
    call road_near
    test eax, eax
    jz .dn
    mov edi, r12d
    mov esi, r13d
    call tl_push_once
.dn:
    inc r14d
    cmp r14d, 4
    jl .d
    inc ebx
    jmp .q
.out:
    RETURN

; along a road: from (edi, esi) to (edx, ecx) as an L, every zonable lot
; within 3 steps of a road tile on the way -> tl
FUNC zone_along_collect, 32
    mov [rbp-48], edi
    mov [rbp-52], esi
    mov [rbp-56], edx
    mov [rbp-60], ecx
    call fill_next_gen
    ; walk the L: x first, then y
    mov r12d, [rbp-48]
    mov r13d, [rbp-52]
.walk:
    ; the road under the pointer, or right next to it
    mov edi, r12d
    mov esi, r13d
    call is_road
    test eax, eax
    jnz .lots
    xor ebx, ebx
.nb:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+rbx*4]
    add esi, [dir_dy+rbx*4]
    call is_road
    test eax, eax
    jnz .lots
    inc ebx
    cmp ebx, 4
    jl .nb
    jmp .next
.lots:
    ; lots within 3 steps
    mov r15d, -3
.dy:
    mov r14d, -3
.dx:
    mov eax, r14d
    cdq
    xor eax, edx
    sub eax, edx
    mov ecx, r15d
    sar ecx, 31
    mov edx, r15d
    xor edx, ecx
    sub edx, ecx
    add eax, edx
    cmp eax, 3
    jg .dn
    lea edi, [r12+r14]
    lea esi, [r13+r15]
    call zonable
    test eax, eax
    jz .dn
    lea edi, [r12+r14]
    lea esi, [r13+r15]
    call tl_push_once
.dn:
    inc r14d
    cmp r14d, 3
    jle .dx
    inc r15d
    cmp r15d, 3
    jle .dy
.next:
    cmp r12d, [rbp-56]
    je .ydir
    jl .xi
    dec r12d
    jmp .walk
.xi:
    inc r12d
    jmp .walk
.ydir:
    cmp r13d, [rbp-60]
    je .out
    jl .yi
    dec r13d
    jmp .walk
.yi:
    inc r13d
    jmp .walk
.out:
    RETURN

; zone tool tiles in beta modes -> eax 1 if the list was made
FUNC zone_collect_beta
    call zone_mode_now
    cmp eax, ZM_FILL
    je .fill
    cmp eax, ZM_ROAD
    je .road
    xor eax, eax
    RETURN
.fill:
    cmp dword [hover_valid], 0
    je .none
    mov edi, [hover_tx]
    mov esi, [hover_ty]
    cmp dword [drag_active], 0
    je .f1
    mov edi, [drag_sx]
    mov esi, [drag_sy]
.f1:
    call zone_fill_collect
    mov eax, 1
    RETURN
.road:
    cmp dword [hover_valid], 0
    je .none
    mov edi, [hover_tx]
    mov esi, [hover_ty]
    mov edx, edi
    mov ecx, esi
    cmp dword [drag_active], 0
    je .r1
    mov edi, [drag_sx]
    mov esi, [drag_sy]
.r1:
    call zone_along_collect
.none:
    mov eax, 1
    RETURN

; a zoned lot's reach (beta): rbx its list index, (edi, esi) the tile
; -> marks lots no road reaches
FUNC zone_reach_mark
    mov byte [tl_farf+rbx], 0
    cmp dword [beta_on], 0
    je .out
    call road_near
    test eax, eax
    jnz .out
    mov byte [tl_farf+rbx], 1
    inc dword [tl_far]
.out:
    RETURN

; the zone tool's notes by the cursor (beta): what may grow, what won't
FUNC zone_notes
    cmp dword [beta_on], 0
    je .out
    cmp dword [tool], T_ZONETOOL
    jne .out
    mov eax, [tl_valid]
    sub eax, [tl_far]
    jle .far
    mov r12d, eax                   ; lots that can grow
    mov ecx, [zone_type]
    imul ecx, ecx, 6
    mov eax, [zone_pop+rcx*4+4]
    imul eax, r12d
    mov r13d, eax                   ; at level 1
    mov eax, [zone_pop+rcx*4+20]
    imul eax, r12d
    mov r14d, eax                   ; at level 5
    call tb_reset
    lea rdi, [s_est1]
    call tb_str
    movsxd rdi, r13d
    call tb_num
    lea rdi, [s_est2]
    call tb_str
    movsxd rdi, r14d
    call tb_num
    lea rdi, [s_est_res]
    mov eax, [zone_type]
    cmp byte [zone_class+rax], ZC_RES
    je .e
    lea rdi, [s_est_jobs]
.e:
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_TEXT
    mov edx, 1
    call cursor_note
.far:
    cmp dword [tl_far], 0
    je .out
    call tb_reset
    movsxd rdi, dword [tl_far]
    call tb_num
    lea rdi, [s_far1]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_BAD
    mov edx, 2
    call cursor_note
.out:
    RETURN

; mode buttons under the road / zone hint (beta) at y edi -> eax rows
FUNC tool_mode_chips, 32
    mov [rbp-48], edi
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp dword [tut_step], 0
    jge .out
    cmp dword [tool], T_ROAD
    je .road
    cmp dword [tool], T_ZONETOOL
    je .zone
    xor eax, eax
    jmp .out
.road:
    xor ebx, ebx
.rb:
    imul edi, ebx, 46
    add edi, 10
    mov esi, [rbp-48]
    mov edx, 44
    mov rcx, [s_rm_names+rbx*8]
    xor r8d, r8d
    cmp ebx, [set_road_mode]
    sete r8b
    call text_button
    test eax, eax
    jz .rbn
    mov [set_road_mode], ebx
    call settings_save
.rbn:
    inc ebx
    cmp ebx, 4
    jl .rb
    ; pipes, and the grid's block size
    mov esi, [rbp-48]
    add esi, 17
    mov edi, 10
    mov edx, 80
    lea rcx, [s_pipes_on]
    cmp dword [set_road_pipes], 0
    jne .p1
    lea rcx, [s_pipes_off]
.p1:
    mov r8d, [set_road_pipes]
    call text_button
    test eax, eax
    jz .p2
    xor dword [set_road_pipes], 1
    call settings_save
.p2:
    cmp dword [set_road_mode], RM_GRID
    jne .two
    call tb_reset
    lea rdi, [s_blocks]
    call tb_str
    mov eax, [set_grid_step]
    dec eax
    movsxd rdi, eax
    call tb_num
    mov edi, 100
    mov esi, [rbp-48]
    add esi, 20
    mov ecx, UI_TEXT
    call tb_draw
    mov edi, 150
    mov esi, [rbp-48]
    add esi, 17
    mov edx, 16
    lea rcx, [s_blk_sub]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .g1
    mov edi, -1
    call grid_step_add
.g1:
    mov edi, 168
    mov esi, [rbp-48]
    add esi, 17
    mov edx, 16
    lea rcx, [s_blk_add]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .two
    mov edi, 1
    call grid_step_add
.two:
    mov eax, 2
    jmp .out
.zone:
    xor ebx, ebx
.zb:
    imul edi, ebx, 60
    add edi, 10
    mov esi, [rbp-48]
    mov edx, 58
    mov rcx, [s_zm_names+rbx*8]
    xor r8d, r8d
    cmp ebx, [set_zone_mode]
    sete r8b
    call text_button
    test eax, eax
    jz .zbn
    mov [set_zone_mode], ebx
    call settings_save
.zbn:
    inc ebx
    cmp ebx, 3
    jl .zb
    mov eax, 1
.out:
    RETURN

; grid block size +/- edi (3..12 tiles apart)
grid_step_add:
    mov eax, [set_grid_step]
    add eax, edi
    CLAMP eax, 3, 12
    mov [set_grid_step], eax
    jmp settings_save

; G: the next mode of the road or zone tool (beta) -> eax 1 if taken
FUNC tool_next_mode
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp dword [tool], T_ROAD
    jne .z
    mov eax, [set_road_mode]
    inc eax
    and eax, 3
    mov [set_road_mode], eax
    jmp .saved
.z:
    cmp dword [tool], T_ZONETOOL
    jne .out
    mov eax, [set_zone_mode]
    inc eax
    cmp eax, 3
    jl .z1
    xor eax, eax
.z1:
    mov [set_zone_mode], eax
.saved:
    call settings_save
    mov eax, 1
.out:
    RETURN

; rows of mode buttons under the tool hint (beta) -> eax
tool_mode_rows:
    xor eax, eax
    cmp dword [beta_on], 0
    je .o
    cmp dword [welcome], 0
    jne .o
    cmp dword [tut_step], 0
    jge .o
    cmp dword [tool], T_ROAD
    jne .z
    mov eax, 2
    ret
.z: cmp dword [tool], T_ZONETOOL
    jne .o
    mov eax, 1
.o: ret

; the tool list as a map (tl_here), for quick "is this tile in the
; drag" questions while previewing
tl_here_mark:
    xor ecx, ecx
.l: cmp ecx, [tl_n]
    jge .o
    mov eax, [tl_y+rcx*4]
    cmp eax, MAP_W
    jae .n
    shl eax, MAP_SHIFT
    mov edx, [tl_x+rcx*4]
    cmp edx, MAP_W
    jae .n
    add eax, edx
    mov byte [tl_here+rax], 1
.n: inc ecx
    jmp .l
.o: ret

tl_here_clear:
    xor ecx, ecx
.l: cmp ecx, [tl_n]
    jge .o
    mov eax, [tl_y+rcx*4]
    cmp eax, MAP_W
    jae .n
    shl eax, MAP_SHIFT
    mov edx, [tl_x+rcx*4]
    cmp edx, MAP_W
    jae .n
    add eax, edx
    mov byte [tl_here+rax], 0
.n: inc ecx
    jmp .l
.o: ret

; Ctrl+wheel over the grid road tool: blocks bigger / smaller (beta)
; -> eax 1 if the wheel was taken
FUNC grid_wheel
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp dword [tool], T_ROAD
    jne .out
    cmp dword [set_road_mode], RM_GRID
    jne .out
    call keys_held
    test eax, 2
    jz .no
    mov edi, 1
    cmp dword [event_buf+EV_MW_Y], 0
    jg .a
    mov edi, -1
.a:
    call grid_step_add
    mov eax, 1
    RETURN
.no:
    xor eax, eax
.out:
    RETURN

; =====================================================================
;  sandbox cities, city files on the web, the eyedropper, rows of small
;  buildings and bus stops (beta)
; =====================================================================
section .data
s_expfile   db "export.sav", 0
s_expname   db "cityssembly.sav", 0
s_sandbox_n db "Sandbox: money never runs out, all land is yours and", 0
s_sandbox_2 db " everything is unlocked.", 0
s_eye_none  db "Nothing to pick up here.", 0
BUS_SPACING equ 5

section .text

; extra menu rows (beta) -> eax
menu_extra_rows:
    xor eax, eax
    cmp dword [beta_on], 0
    je .o
    inc eax
%ifdef WEB
    add eax, 2
%endif
.o: ret

; a new city with money that never runs out, all the land and
; everything unlocked; no welcome card, no tour
FUNC new_sandbox_city
    call new_city
    mov dword [free_mode], 1
    mov qword [money], 1000000
    mov qword [money_shown], 1000000
    mov dword [milestone], 9
    lea rdi, [plot_owned]
    mov al, 1
    mov ecx, PLOTS*PLOTS
    rep stosb
    mov dword [welcome], 0
    call tb_reset
    lea rdi, [s_sandbox_n]
    call tb_str
    lea rdi, [s_sandbox_2]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_GOLD
    mov edx, -1
    mov ecx, -1
    call notify
    RETURN

%ifdef WEB
; save the city and hand the file to the browser
FUNC city_export
    mov dword [save_quiet], 1
    lea rdi, [s_expfile]
    call save_city_to
    lea rdi, [s_expfile]
    lea rsi, [s_expname]
    call web_export
    RETURN
%endif

; a city file the player chose has arrived: open it (every frame)
FUNC web_import_poll
%ifdef WEB
    cmp dword [beta_on], 0
    je .out
    call web_import_ready
    test rax, rax
    jz .out
    mov rdi, rax
    call load_city_from
.out:
%endif
    RETURN

; E: take the tool that built what's under the pointer
FUNC eyedropper
    cmp dword [beta_on], 0
    je .out
    cmp dword [hover_valid], 0
    je .out
    mov edi, [hover_tx]
    mov esi, [hover_ty]
    call tile_at
    test rax, rax
    jz .out
    mov rbx, rax
    movzx ecx, byte [rbx+T_OBJ]
    cmp ecx, OBJ_ROAD
    jne .n1
    test byte [rbx+T_FLAGS2], F2_BUSSTOP
    jz .rd
    mov edi, SI_BUSSTOP
    jmp .sel
.rd:
    movzx edi, byte [rbx+T_ROADTYPE]
    CLAMP edi, 0, 2
    add edi, SI_STREET
    jmp .sel
.n1:
    cmp ecx, OBJ_SERVICE
    jne .n2
    movzx edi, byte [rbx+T_SUB]
    jmp .sel
.n2:
    cmp ecx, OBJ_POWER
    jne .n3
    mov edi, SI_POWERLN
    jmp .sel
.n3:
    cmp ecx, OBJ_TREE
    jne .n4
    mov dword [tool], T_TREE
    mov dword [submenu], -1
    jmp .out
.n4:
    movzx edi, byte [rbx+T_ZONE]
    test edi, edi
    jz .n5
    add edi, SI_ZONE
    jmp .sel
.n5:
    test byte [rbx+T_FLAGS2], F2_PIPE
    jz .none
    mov edi, SI_PIPE
.sel:
    call submenu_select
    jmp .out
.none:
    lea rdi, [s_eye_none]
    mov esi, UI_DIM
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; is the current tool dragged into a row of buildings or bus stops?
; (beta; one-tile buildings) -> eax 1
FUNC drag_places
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp dword [tut_step], 0
    jge .out
    cmp dword [tool], T_BUSSTOP
    je .y
    cmp dword [tool], T_BUILD
    jne .out
    cmp dword [moving], 0
    jne .out
    mov edi, [build_kind]
    call bld_rec
    cmp byte [rax+BI_SIZE], 1
    jne .no
.y:
    mov eax, 1
    RETURN
.no:
    xor eax, eax
.out:
    RETURN

; the row: (edi, esi) to (edx, ecx), straight along the longer way.
; Small buildings go on every tile (parks) or every other one; bus
; stops on every BUS_SPACING-th road tile.  A drag that hasn't moved is
; just the tile (a building centres as usual).
FUNC drag_places_collect, 32
    mov [rbp-48], edi
    mov [rbp-52], esi
    mov [rbp-56], edx
    mov [rbp-60], ecx
    ; straight: the end onto the start's row or column
    mov eax, edx
    sub eax, edi
    cdq
    xor eax, edx
    sub eax, edx
    mov ecx, [rbp-60]
    sub ecx, [rbp-52]
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx
    cmp eax, ecx
    jl .v
    mov eax, [rbp-52]
    mov [rbp-60], eax
    jmp .step
.v:
    mov eax, [rbp-48]
    mov [rbp-56], eax
.step:
    ; spacing
    mov dword [rbp-64], BUS_SPACING
    cmp dword [tool], T_BUSSTOP
    je .walk0
    mov dword [rbp-64], 1
    cmp dword [build_kind], BK_PARK
    je .walk0
    mov dword [rbp-64], 2
.walk0:
    mov r12d, [rbp-48]
    mov r13d, [rbp-52]
    xor r14d, r14d                  ; tiles since the last one placed
    mov r15d, [rbp-64]              ; (the first goes down at once)
.walk:
    cmp dword [tool], T_BUSSTOP
    jne .any
    ; stops: road tiles only (not highways), counted along the road
    mov edi, r12d
    mov esi, r13d
    call tile_at
    test rax, rax
    jz .next
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .next
    cmp byte [rax+T_ROADTYPE], RT_HIGHWAY
    je .next
.any:
    cmp r15d, [rbp-64]
    jl .skip
    mov edi, r12d
    mov esi, r13d
    call tl_push
    xor r15d, r15d
.skip:
    inc r15d
.next:
    cmp r12d, [rbp-56]
    je .ydir
    jl .xi
    dec r12d
    jmp .walk
.xi:
    inc r12d
    jmp .walk
.ydir:
    cmp r13d, [rbp-60]
    je .out
    jl .yi
    dec r13d
    jmp .walk
.yi:
    inc r13d
    jmp .walk
.out:
    RETURN

; evaluate a row of buildings (tl_n > 1): each where it stands
FUNC build_eval_many
    mov edi, [build_kind]
    call bld_rec
    mov r15d, [rax+BI_COST]
    xor ebx, ebx
.l:
    cmp ebx, [tl_n]
    jge .out
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    call bld_fit
    test eax, eax
    jz .ok
    mov [last_tool_err], eax
    jmp .n
.ok:
    mov byte [tl_ok+rbx], 1
    inc dword [tl_valid]
    mov eax, r15d
    add eax, [fit_cost]
    add [tl_cost], eax
.n:
    inc ebx
    jmp .l
.out:
    cmp dword [tl_valid], 0
    je .o2
    mov dword [last_tool_err], 0
.o2:
    RETURN

; put one small (1x1) service of build_kind at (edi, esi), clearing
; the spot first
FUNC svc_put_one
    mov r12d, edi
    mov r13d, esi
    call bld_clear
    mov edi, r12d
    mov esi, r13d
    call tile_at
    test rax, rax
    jz .out
    mov edx, r13d
    shl edx, MAP_SHIFT
    add edx, r12d
    mov cl, [rax+T_ZONE]
    mov [svc_zone+rdx], cl
    mov byte [rax+T_OBJ], OBJ_SERVICE
    mov ecx, [build_kind]
    mov [rax+T_SUB], cl
    mov byte [rax+T_ZONE], 0
    mov byte [rax+T_FLAGS], F_ANCHOR
    mov byte [rax+T_TIMER], 0
    mov word [rax+T_POP], 0
    mov byte [rax+T_PROBLEM], 0
    mov byte [rax+T_ANCHOR], 0
    mov edi, r12d
    mov esi, r13d
    mov edx, 3
    mov ecx, PK_DUST
    mov r8d, 2
    call fx_burst
    mov edi, r12d
    mov esi, r13d
    call roads_update_around
.out:
    RETURN

; the build tool placed a row (money paid, undo begun): every valid spot
FUNC build_many
    xor ebx, ebx
.l:
    cmp ebx, [tl_n]
    jge .d
    cmp byte [tl_ok+rbx], 0
    je .n
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    call svc_put_one
.n:
    inc ebx
    jmp .l
.d:
    mov dword [net_dirty], 1
    call networks_update
    call coverage_update
    mov edi, [tl_cost]
    call undo_end
    mov edi, SFX_PLACE
    call sfx_play
    call cost_float
    RETURN

; =====================================================================
;  bookmarks and the way back (beta), assists (beta)
; =====================================================================
section .data
s_bm_set    db "View marked - Shift+", 0
s_bm_set2   db " comes back here.", 0
s_bm_none   db "No view marked on that key yet (Ctrl+number marks one).", 0
s_rubble_n  db " piles of rubble swept up.", 0
s_aband_n   db " abandoned buildings cleared away.", 0
section .text

; remember the view before a jump (Backspace comes back)
cam_remember:
    push rax
    mov eax, [cam_x]
    mov [cam_prev], eax
    mov eax, [cam_y]
    mov [cam_prev+4], eax
    mov eax, [zoom]
    mov [cam_prev+8], eax
    pop rax
    ret

; the same, keeping edi / esi (a jump about to happen)
cam_remember_keep:
    jmp cam_remember

; Backspace: back to the view before the last jump
FUNC cam_back
    cmp dword [beta_on], 0
    je .out
    mov eax, [cam_prev+8]
    test eax, eax
    jz .out
    ; swap, so Backspace again returns
    mov r12d, [cam_x]
    mov r13d, [cam_y]
    mov r14d, [zoom]
    mov edi, eax
    call video_set_zoom
    mov eax, [cam_prev]
    mov [cam_x], eax
    mov eax, [cam_prev+4]
    mov [cam_y], eax
    call camera_clamp
    mov [cam_prev], r12d
    mov [cam_prev+4], r13d
    mov [cam_prev+8], r14d
.out:
    RETURN

; Ctrl+1..4: mark this view; Shift+1..4: go to the marked view (beta)
; (edi scancode) -> eax 1 if taken
FUNC bookmark_key
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp edi, SC_1
    jl .out
    cmp edi, SC_1+BOOKMARKS-1
    jg .out
    lea ebx, [rdi-SC_1]
    imul ebx, ebx, 12
    test dword [key_mod], 0xC0
    jnz .mark
    test dword [key_mod], 3
    jz .out
    ; go there
    mov eax, [bookmarks+rbx+8]
    test eax, eax
    jz .none
    call cam_remember
    mov edi, [bookmarks+rbx+8]
    call video_set_zoom
    mov eax, [bookmarks+rbx]
    mov [cam_x], eax
    mov eax, [bookmarks+rbx+4]
    mov [cam_y], eax
    call camera_clamp
    mov eax, 1
    RETURN
.none:
    lea rdi, [s_bm_none]
    mov esi, UI_DIM
    mov edx, -1
    mov ecx, -1
    call notify
    mov eax, 1
    RETURN
.mark:
    mov eax, [cam_x]
    mov [bookmarks+rbx], eax
    mov eax, [cam_y]
    mov [bookmarks+rbx+4], eax
    mov eax, [zoom]
    mov [bookmarks+rbx+8], eax
    call tb_reset
    lea rdi, [s_bm_set]
    call tb_str
    mov eax, ebx
    xor edx, edx
    mov ecx, 12
    div ecx
    lea edi, [rax+'1']
    call tb_char
    lea rdi, [s_bm_set2]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
    mov eax, 1
.out:
    RETURN

; month end (beta): abandoned buildings cleared, rubble swept
FUNC assists_month, 16
    cmp dword [beta_on], 0
    je .out
    mov dword [rbp-48], 0           ; cleared
    mov dword [rbp-52], 0           ; swept
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea r12, [tiles+rax]
    movzx ecx, byte [r12+T_OBJ]
    cmp ecx, OBJ_ZONEBLD
    jne .rb
    cmp dword [set_clear_abandoned], 0
    je .n
    test byte [r12+T_FLAGS], F_ABANDON
    jz .n
    test byte [r12+T_FLAGS], F_ANCHOR
    jz .n
    test byte [r12+T_FLAGS], F_FIRE
    jnz .n
    mov edi, ebx
    and edi, MAP_W-1
    mov esi, ebx
    shr esi, MAP_SHIFT
    call destroy_to_rubble
    inc dword [rbp-48]
    jmp .n
.rb:
    cmp ecx, OBJ_RUBBLE
    jne .n
    cmp dword [set_sweep_rubble], 0
    je .n
    mov byte [r12+T_OBJ], OBJ_NONE
    inc dword [rbp-52]
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    ; the cleared buildings' rubble goes at once (zones stay)
    cmp dword [rbp-48], 0
    je .msg
    xor ebx, ebx
.c:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_RUBBLE
    jne .cn
    cmp byte [tiles+rax+T_ZONE], 0
    je .cn
    mov byte [tiles+rax+T_OBJ], OBJ_NONE
.cn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .c
    call tb_reset
    movsxd rdi, dword [rbp-48]
    call tb_num
    lea rdi, [s_aband_n]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_DIM
    mov edx, -1
    mov ecx, -1
    call notify
.msg:
    mov dword [net_dirty], 1
.out:
    RETURN

; pause for an emergency (beta, if asked for)
FUNC emergency_pause
    cmp dword [beta_on], 0
    je .out
    cmp dword [set_emerg_pause], 0
    je .out
    cmp dword [sim_speed], 0
    je .out
    mov eax, [sim_speed]
    mov [saved_speed], eax
    mov dword [sim_speed], 0
.out:
    RETURN

; =====================================================================
;  difficulty (beta): what running a city costs
;    Relaxed  the classic costs
;    Normal   services cost 1.5x, more as the city grows (x2.4 at
;             35,000 people); roads $1 / $2 / $3 a tile a month, and $1
;             more where traffic wears them
;    Hard     services 2x and growing twice as fast; roads 1.5x that
; =====================================================================
DIFF_NORMAL  equ 0
DIFF_RELAXED equ 1
DIFF_HARD    equ 2
section .data
diff_names  dq s_df0, s_df1, s_df2
s_df0       db "Normal", 0
s_df1       db "Relaxed", 0
s_df2       db "Hard", 0
s_df_lbl    db "Difficulty: ", 0
s_df_tip    db "Relaxed: classic costs. Normal: services cost", 10
            db "more as the city grows, roads cost upkeep and", 10
            db "wear. Hard: all of it, much more so.", 0
; the welcome card's order: relaxed, normal, hard
diff_order  dd DIFF_RELAXED, DIFF_NORMAL, DIFF_HARD
section .text

; month end (beta): road and service costs by difficulty
FUNC economy_scale
    cmp dword [beta_on], 0
    je .out
    cmp dword [free_mode], 0
    jne .out
    mov eax, [difficulty]
    cmp eax, DIFF_RELAXED
    je .out
    ; roads: a dollar per tile per lane size, and wear on busy ones
    xor ecx, ecx
    xor ebx, ebx
.w:
    mov eax, ecx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    jne .wn
    cmp byte [tiles+rax+T_TRAFFIC], 160
    jb .wn
    inc ebx
.wn:
    inc ecx
    cmp ecx, MAP_TILES
    jl .w
    mov eax, [road_cost]
    add eax, ebx
    cmp dword [difficulty], DIFF_HARD
    jne .r
    lea eax, [rax*2+rax]
    shr eax, 1
.r:
    mov [exp_roads], eax
    ; services: x1.5 plus the size of the city (hard: x2, twice as fast)
    mov eax, [population]
    shl eax, 8
    xor edx, edx
    mov ecx, 40000
    mov r12d, 384
    cmp dword [difficulty], DIFF_HARD
    jne .m
    mov ecx, 25000
    mov r12d, 512
.m:
    div ecx
    add r12d, eax                   ; multiplier x256
    mov eax, [exp_services]
    imul rax, r12
    shr rax, 8
    mov [exp_services], eax
    xor ebx, ebx
.c:
    mov eax, [exp_cat+rbx*4]
    imul rax, r12
    shr rax, 8
    mov [exp_cat+rbx*4], eax
    inc ebx
    cmp ebx, 8
    jl .c
.out:
    RETURN

; the difficulty buttons on the welcome card (beta; edi x, esi y)
FUNC welcome_difficulty
    cmp dword [beta_on], 0
    je .out
    mov r12d, edi
    mov r13d, esi
    xor ebx, ebx
.b:
    imul edi, ebx, 54
    add edi, r12d
    mov esi, r13d
    mov edx, 52
    mov eax, [diff_order+rbx*4]
    mov rcx, [diff_names+rax*8]
    xor r8d, r8d
    cmp eax, [difficulty]
    sete r8b
    call text_button
    test eax, eax
    jz .n
    mov eax, [diff_order+rbx*4]
    mov [difficulty], eax
.n:
    imul edi, ebx, 54
    add edi, r12d
    mov esi, r13d
    mov edx, 52
    mov ecx, 14
    call ui_over
    test eax, eax
    jz .nt
    lea rax, [s_df_tip]
    mov [tooltip], rax
.nt:
    inc ebx
    cmp ebx, 3
    jl .b
.out:
    RETURN

; the budget panel's difficulty button (beta; edi x, esi y): cycles
FUNC budget_difficulty
    cmp dword [beta_on], 0
    je .out
    cmp dword [free_mode], 0
    jne .out
    mov r12d, edi
    mov r13d, esi
    call tb_reset
    lea rdi, [s_df_lbl]
    call tb_str
    mov eax, [difficulty]
    mov rdi, [diff_names+rax*8]
    call tb_str
    lea rsi, [textbuf]
    lea rdi, [move_title]
    mov ecx, 63
    rep movsb
    mov edi, r12d
    mov esi, r13d
    mov edx, 110
    lea rcx, [move_title]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .t
    mov eax, [difficulty]
    inc eax
    cmp eax, 3
    jl .s
    xor eax, eax
.s:
    mov [difficulty], eax
.t:
    mov edi, r12d
    mov esi, r13d
    mov edx, 110
    mov ecx, 14
    call ui_over
    test eax, eax
    jz .out
    lea rax, [s_df_tip]
    mov [tooltip], rax
.out:
    RETURN
