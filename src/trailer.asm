; =====================================================================
;  TRAILER - a scripted "director" that films the game.
;
;  cityssembly --trailer out.raw plan.bin [W H]
;  plan.bin is a little bytecode program written by trailer_work/plan.py:
;  it lays out the terrain and the city, grows it, and moves the camera,
;  the clock and the seasons while filming.  Frames go to out.raw as raw
;  BGRA at the window size (use a FIFO into ffmpeg); shot marks, road
;  tiles and followed vehicles are printed on stdout for the edit.
; =====================================================================

TR_PLAN_MAX equ 1<<20

section .bss
tr_rw           resq 1
tr_plan_file    resq 1
tr_pc           resq 1
tr_ui           resd 1
tr_cx           resd 1          ; camera in 1/16 px
tr_cy           resd 1
tr_vx           resd 1
tr_vy           resd 1
tr_frames       resd 1
tr_follow       resd 1          ; vehicle slot, -1 = off
tr_todspeed     resd 1
tr_acc          resd 1
tr_prob         resd 12
tr_plan         resb TR_PLAN_MAX

section .data
str_trailer_flag db "--trailer", 0
str_shotfmt      db "SHOT %d %d", 10, 0
str_tilefmt      db "TILE %d %d %d", 10, 0
str_carfmt       db "CAR %d %d %d", 10, 0
str_opfmt        db "bad trailer op %d", 10, 0
str_benchfmt     db "BENCH us/frame: palette %d world %d agents %d light %d present-copy %d", 10, 0
str_statfmt      db "STAT pop %d power %d/%d water %d/%d sewage %d/%d", 10, 0
str_statfmt3     db "STAT3 problems: power %d water %d sewage %d garbage %d goods %d workers %d", 10, 0
str_statfmt4     db "STAT4 fire %d road %d dirty %d route %d unemployed %d jobs %d", 10, 0
str_statfmt2     db "STAT2 unpowered %d nowater %d noroad %d abandon %d demand %d %d %d %d year %d", 10, 0

section .text

; next i16 argument of the plan -> eax (sign extended)
tr_arg:
    mov rcx, [tr_pc]
    movsx eax, word [rcx]
    add rcx, 2
    mov [tr_pc], rcx
    ret

; mark the start of a shot on stdout (edi id)
FUNC tr_mark
    mov esi, edi
    lea rdi, [str_shotfmt]
    mov edx, [tr_frames]
    xor eax, eax
    CALLC printf
    RETURN

; run n game ticks without keyboard control (edi = n)
FUNC tr_ticks
    mov ebx, edi
.l:
    test ebx, ebx
    jz .d
    inc dword [anim_tick]
    call sim_tick
    call agents_tick
    mov eax, [tr_todspeed]
    add [tod], eax
    and dword [tod], 0xFFFF
    inc dword [water_phase]
    dec ebx
    jmp .l
.d:
    RETURN

; point the camera at a tile (edi tx, esi ty)
FUNC tr_cam_tile
    call camera_center_tile
    mov eax, [cam_x]
    shl eax, 4
    mov [tr_cx], eax
    mov eax, [cam_y]
    shl eax, 4
    mov [tr_cy], eax
    RETURN

; report the followed vehicle's screen position for the edit
FUNC tr_follow_update
    mov eax, [tr_follow]
    cmp eax, -1
    je .out
    shl eax, 7
    lea rbx, [vehicles+rax]
    cmp byte [rbx+V_TYPE], 255
    je .out
    mov eax, [rbx+V_WX]
    sub eax, [rbx+V_WY]
    sar eax, 4
    add eax, ORIGIN_X
    sub eax, [cam_x]
    mov ecx, [rbx+V_WX]
    add ecx, [rbx+V_WY]
    sar ecx, 5
    sub ecx, [cam_y]
    lea rdi, [str_carfmt]
    mov esi, [tr_frames]
    mov edx, eax
    xor eax, eax
    CALLC printf
.out:
    RETURN

; choose a car near (edi x, esi y) with a long way to go
FUNC tr_pick_car
    mov dword [tr_follow], -1
    mov r13d, edi
    mov r14d, esi
    xor ebx, ebx
    xor r12d, r12d                  ; best remaining steps
.l:
    cmp ebx, MAX_VEH
    jge .out
    mov eax, ebx
    shl eax, 7
    lea rcx, [vehicles+rax]
    cmp byte [rcx+V_TYPE], VT_CAR
    jne .n
    movzx eax, word [rcx+V_TX]
    sub eax, r13d
    cdq
    xor eax, edx
    sub eax, edx
    movzx r8d, word [rcx+V_TY]
    sub r8d, r14d
    mov edx, r8d
    sar edx, 31
    xor r8d, edx
    sub r8d, edx
    add eax, r8d
    cmp eax, 10
    jg .n
    movzx eax, word [rcx+V_PLEN]
    movzx edx, word [rcx+V_PPOS]
    sub eax, edx
    cmp eax, r12d
    jle .n
    mov r12d, eax
    mov [tr_follow], ebx
.n:
    inc ebx
    jmp .l
.out:
    RETURN

; render and write one frame, then advance the camera
FUNC tr_frame
    mov eax, [tr_cx]
    sar eax, 4
    mov [cam_x], eax
    mov eax, [tr_cy]
    sar eax, 4
    mov [cam_y], eax
    mov eax, [shake]
    test eax, eax
    jz .ns
    dec dword [shake]
    shr eax, 2
    inc eax
    lea edi, [rax*2+1]
    call rand_range
    mov ecx, [shake]
    shr ecx, 3
    sub eax, ecx
    add [cam_x], eax
    mov edi, 5
    call rand_range
    sub eax, 2
    add [cam_y], eax
.ns:
    call palette_update
    call render_world
    mov dword [emit_now], 0
    call draw_agents
    cmp dword [tr_ui], 0
    je .noui
    call render_ui
    call draw_tool_preview
    jmp .comp
.noui:
    call set_target_ui
    xor edi, edi
    call clear_target
.comp:
    call compose_frame
    call tr_follow_update
    mov rdi, [tr_rw]
    lea rsi, [shotbuf]
    mov edx, [win_w]
    imul edx, [win_h]
    shl edx, 2
    mov ecx, 1
    CALLC SDL_RWwrite
    inc dword [tr_frames]
    mov eax, [tr_vx]
    add [tr_cx], eax
    mov eax, [tr_vy]
    add [tr_cy], eax
    RETURN

; film n frames with t ticks between them (edi n, esi t)
FUNC tr_shot
    mov r12d, edi
    mov r13d, esi
.l:
    test r12d, r12d
    jz .d
    call tr_frame
    mov edi, r13d
    call tr_ticks
    dec r12d
    jmp .l
.d:
    RETURN


; lay a straight road (edi x0, esi y0, edx x1, ecx y1, r8d type, r9d highway)
FUNC tr_road, 16
    mov [rbp-48], r8d
    mov [rbp-52], r9d
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
.l:
    mov edi, r12d
    mov esi, r13d
    mov edx, [rbp-48]
    call demo_road
    cmp dword [rbp-52], 0
    je .nh
    mov edi, r12d
    mov esi, r13d
    call tile_at
    test rax, rax
    jz .nh
    or byte [rax+T_FLAGS], F_HIGHWAY
.nh:
    cmp r12d, r14d
    jne .step
    cmp r13d, r15d
    je .out
.step:
    cmp r12d, r14d
    je .sy
    jl .xp
    dec r12d
    jmp .sy
.xp:
    inc r12d
.sy:
    cmp r13d, r15d
    je .l
    jl .yp
    dec r13d
    jmp .l
.yp:
    inc r13d
    jmp .l
.out:
    RETURN

; zone a rectangle (edi x0, esi y0, edx x1, ecx y1, r8d zone)
FUNC tr_zone, 16
    mov [rbp-48], r8d
    mov [rbp-52], edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
.y:
    cmp r13d, r15d
    jg .out
    mov r12d, [rbp-52]
.x:
    cmp r12d, r14d
    jg .yn
    mov edi, r12d
    mov esi, r13d
    call tile_at
    test rax, rax
    jz .n
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .n
    mov cl, [rax+T_OBJ]
    cmp cl, OBJ_NONE
    je .ok
    cmp cl, OBJ_TREE
    jne .n
.ok:
    mov byte [rax+T_OBJ], OBJ_NONE
    mov ecx, [rbp-48]
    mov [rax+T_ZONE], cl
.n:
    inc r12d
    jmp .x
.yn:
    inc r13d
    jmp .y
.out:
    RETURN

; terrain from the plan: one byte per tile
;   bits 0-1 terrain, bit 2 tree, bits 3-4 tree kind, bits 5-6 resource
FUNC tr_terrain
    mov r12, [tr_pc]
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    movzx r13d, byte [r12+rbx]
    ; keep the variant, reset the rest
    mov r14b, [rdi+T_VARIANT]
    push rdi
    push rdi
    xor eax, eax
    mov ecx, TILE_BYTES
    rep stosb
    pop rdi
    pop rdi
    mov [rdi+T_VARIANT], r14b
    mov eax, r13d
    and eax, 3
    mov [rdi+T_TERRAIN], al
    test r13d, 4
    jz .nt
    mov byte [rdi+T_OBJ], OBJ_TREE
    mov eax, r13d
    shr eax, 3
    and eax, 3
    mov [rdi+T_SUB], al
.nt:
    mov eax, r13d
    shr eax, 5
    and eax, 3
    mov [rdi+T_RES], al
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    add r12, MAP_TILES
    mov [tr_pc], r12
    mov dword [n_wires], 0
    RETURN

; networks, coverage and stats after building
FUNC tr_nets
    call roads_update_all
    mov dword [net_dirty], 1
    call networks_update
    call coverage_update
    call stats_update
    RETURN

; animate a road being drawn (x0 y0 x1 y1 type rate ticks)
; rate = tiles per frame in 1/16
FUNC tr_roadanim, 32
    call tr_arg
    mov r12d, eax
    call tr_arg
    mov r13d, eax
    call tr_arg
    mov [rbp-48], eax               ; x1
    call tr_arg
    mov [rbp-52], eax               ; y1
    call tr_arg
    mov [rbp-56], eax               ; type
    call tr_arg
    mov [rbp-60], eax               ; rate
    call tr_arg
    mov [rbp-64], eax               ; ticks
    mov dword [tr_acc], 0
.frame:
    mov eax, [rbp-60]
    add [tr_acc], eax
.tile:
    cmp dword [tr_acc], 16
    jl .film
    sub dword [tr_acc], 16
    mov edi, r12d
    mov esi, r13d
    mov edx, [rbp-56]
    call demo_road
    mov edi, r12d
    mov esi, r13d
    call roads_update_around
    mov edi, r12d
    mov esi, r13d
    mov edx, 3
    mov ecx, PK_DUST
    mov r8d, 1
    call fx_burst
    lea rdi, [str_tilefmt]
    mov esi, [tr_frames]
    mov edx, r12d
    mov ecx, r13d
    xor eax, eax
    CALLC printf
    cmp r12d, [rbp-48]
    jne .adv
    cmp r13d, [rbp-52]
    je .last
.adv:
    cmp r12d, [rbp-48]
    je .ay
    jl .ax
    dec r12d
    jmp .tile
.ax:
    inc r12d
    jmp .tile
.ay:
    cmp r13d, [rbp-52]
    jl .ayp
    dec r13d
    jmp .tile
.ayp:
    inc r13d
    jmp .tile
.film:
    call tr_frame
    mov edi, [rbp-64]
    call tr_ticks
    jmp .frame
.last:
    call tr_frame
    mov edi, [rbp-64]
    call tr_ticks
    RETURN

; plant trees on empty grass in a rectangle (x0 y0 x1 y1 percent)
FUNC tr_trees, 16
    call tr_arg
    mov [rbp-48], eax
    call tr_arg
    mov r13d, eax
    call tr_arg
    mov r14d, eax
    call tr_arg
    mov r15d, eax
    call tr_arg
    mov [rbp-52], eax
.y:
    cmp r13d, r15d
    jg .out
    mov r12d, [rbp-48]
.x:
    cmp r12d, r14d
    jg .yn
    mov edi, r12d
    mov esi, r13d
    call tile_at
    test rax, rax
    jz .n
    mov rbx, rax
    cmp byte [rbx+T_TERRAIN], TER_GRASS
    jne .n
    cmp byte [rbx+T_OBJ], OBJ_NONE
    jne .n
    cmp byte [rbx+T_ZONE], 0
    jne .n
    mov edi, 100
    call rand_range
    cmp eax, [rbp-52]
    jge .n
    mov byte [rbx+T_OBJ], OBJ_TREE
    call rand
    and eax, 3
    mov [rbx+T_SUB], al
.n:
    inc r12d
    jmp .x
.yn:
    inc r13d
    jmp .y
.out:
    RETURN

; bulldoze a rectangle to grass (x0 y0 x1 y1)
FUNC tr_clear, 16
    call tr_arg
    mov [rbp-48], eax
    call tr_arg
    mov r13d, eax
    call tr_arg
    mov r14d, eax
    call tr_arg
    mov r15d, eax
.y:
    cmp r13d, r15d
    jg .out
    mov r12d, [rbp-48]
.x:
    cmp r12d, r14d
    jg .yn
    mov edi, r12d
    mov esi, r13d
    call tile_at
    test rax, rax
    jz .n
    mov byte [rax+T_OBJ], OBJ_NONE
    mov byte [rax+T_ZONE], 0
    mov byte [rax+T_FLAGS], 0
    mov byte [rax+T_FLAGS2], 0
    mov byte [rax+T_TERRAIN], TER_GRASS
.n:
    inc r12d
    jmp .x
.yn:
    inc r13d
    jmp .y
.out:
    RETURN

; set a building on fire near (edi x, esi y)
FUNC tr_fire
    mov r12d, edi
    mov r13d, esi
    call tile_at
    test rax, rax
    jz .out
    mov rbx, rax
    ; walk back to the anchor of a multi-tile building
    movzx eax, byte [rbx+T_ANCHOR]
    mov ecx, eax
    and eax, 15
    shr ecx, 4
    sub r12d, eax
    sub r13d, ecx
    mov edi, r12d
    mov esi, r13d
    call tile_at
    test rax, rax
    jz .out
    cmp byte [rax+T_OBJ], OBJ_ZONEBLD
    jne .out
    or byte [rax+T_FLAGS], F_FIRE
    mov byte [rax+T_TIMER], 0
.out:
    RETURN

section .data
align 8
tr_ops:
    dq tr_op_end, tr_op_terrain, tr_op_road, tr_op_zone, tr_op_place
    dq tr_op_pline, tr_op_stop, tr_op_nets, tr_op_ff, tr_op_mark
    dq tr_op_cam, tr_op_zoom, tr_op_vel, tr_op_tod, tr_op_season
    dq tr_op_film, tr_op_roadanim, tr_op_follow, tr_op_overlay, tr_op_meteor
    dq tr_op_fire, tr_op_speed, tr_op_year, tr_op_confetti, tr_op_trees
    dq tr_op_clear, tr_op_load, tr_op_light, tr_op_money, tr_op_lock
    dq tr_op_save, tr_op_drag, tr_op_stat, tr_op_lforce, tr_op_bench
TR_NOPS equ ($-tr_ops)/8
section .text

; ---------------------------------------------------------------------
FUNC trailer_run, 96
    ; the plan
    mov rdi, [tr_plan_file]
    test rdi, rdi
    jz tr_done
    lea rsi, [str_rb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz tr_done
    mov r12, rax
    mov rdi, r12
    lea rsi, [tr_plan]
    mov edx, 1
    mov ecx, TR_PLAN_MAX
    CALLC SDL_RWread
    mov rdi, r12
    CALLC SDL_RWclose
    lea rax, [tr_plan]
    mov [tr_pc], rax
    ; the film
    mov rdi, [shot_file]
    lea rsi, [str_wb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz tr_done
    mov [tr_rw], rax
    mov dword [welcome], 0
    mov dword [tr_follow], -1
    mov dword [tod_lock], 0
    mov dword [tr_todspeed], 0
    mov dword [disasters_on], 0
    mov dword [tr_ui], 0
    mov dword [overlay_mode], 0
    mov dword [light_force], 1
    mov edi, 1
    call video_set_zoom
.next:
    mov rcx, [tr_pc]
    movzx eax, byte [rcx]
    inc rcx
    mov [tr_pc], rcx
    cmp eax, TR_NOPS
    jae .bad
    jmp [tr_ops+rax*8]
.bad:
    mov esi, eax
    lea rdi, [str_opfmt]
    xor eax, eax
    CALLC printf
tr_op_end:
    mov rdi, [tr_rw]
    CALLC SDL_RWclose
tr_done:
    RETURN

%macro TRARGS 1-*
%rep %0
    call tr_arg
    mov %1, eax
%rotate 1
%endrep
%endmacro

tr_op_terrain:
    call tr_terrain
    jmp trailer_run.next
tr_op_road:
    TRARGS [rbp-48], [rbp-52], [rbp-56], [rbp-60], [rbp-64], [rbp-68]
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, [rbp-56]
    mov ecx, [rbp-60]
    mov r8d, [rbp-64]
    mov r9d, [rbp-68]
    call tr_road
    jmp trailer_run.next
tr_op_zone:
    TRARGS [rbp-48], [rbp-52], [rbp-56], [rbp-60], [rbp-64]
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, [rbp-56]
    mov ecx, [rbp-60]
    mov r8d, [rbp-64]
    call tr_zone
    jmp trailer_run.next
tr_op_place:
    TRARGS [rbp-48], [rbp-52], [rbp-56]
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, [rbp-56]
    call demo_force
    jmp trailer_run.next
tr_op_pline:
    TRARGS [rbp-48], [rbp-52], [rbp-56], [rbp-60]
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, [rbp-56]
    mov ecx, [rbp-60]
    call demo_pline
    jmp trailer_run.next
tr_op_stop:
    TRARGS [rbp-48], [rbp-52]
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call demo_stop
    jmp trailer_run.next
tr_op_nets:
    call tr_nets
    jmp trailer_run.next
tr_op_ff:
    TRARGS [rbp-48], [rbp-52]
    mov eax, [rbp-52]
    mov [sim_speed], eax
    mov ebx, [rbp-48]
.ff:
    test ebx, ebx
    jz .ffd
    call sim_tick
    call agents_tick
    inc dword [anim_tick]
    dec ebx
    jmp .ff
.ffd:
    mov rax, [money]
    mov [money_shown], rax
    jmp trailer_run.next
tr_op_mark:
    TRARGS [rbp-48]
    mov edi, [rbp-48]
    call tr_mark
    jmp trailer_run.next
tr_op_cam:
    TRARGS [rbp-48], [rbp-52], [rbp-56], [rbp-60]
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call tr_cam_tile
    mov eax, [rbp-56]
    shl eax, 4
    add [tr_cx], eax
    mov eax, [rbp-60]
    shl eax, 4
    add [tr_cy], eax
    jmp trailer_run.next
tr_op_zoom:
    TRARGS [rbp-48]
    mov edi, [rbp-48]
    call video_set_zoom
    jmp trailer_run.next
tr_op_vel:
    TRARGS [tr_vx], [tr_vy]
    jmp trailer_run.next
tr_op_tod:
    TRARGS [rbp-48], [tr_todspeed]
    mov eax, [rbp-48]
    shl eax, 8
    mov [tod], eax
    jmp trailer_run.next
tr_op_season:
    TRARGS [season_pos]
    jmp trailer_run.next
tr_op_film:
    TRARGS [rbp-48], [rbp-52]
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call tr_shot
    jmp trailer_run.next
tr_op_roadanim:
    call tr_roadanim
    jmp trailer_run.next
tr_op_follow:
    TRARGS [rbp-48], [rbp-52]
    mov dword [tr_follow], -1
    cmp dword [rbp-48], 0
    jl trailer_run.next
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call tr_pick_car
    jmp trailer_run.next
tr_op_overlay:
    TRARGS [overlay_mode]
    jmp trailer_run.next
tr_op_meteor:
    TRARGS [rbp-48], [rbp-52]
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call meteor_strike
    jmp trailer_run.next
tr_op_fire:
    TRARGS [rbp-48], [rbp-52]
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call tr_fire
    jmp trailer_run.next
tr_op_speed:
    TRARGS [sim_speed]
    jmp trailer_run.next
tr_op_year:
    TRARGS [year]
    jmp trailer_run.next
tr_op_confetti:
    TRARGS [rbp-48], [rbp-52]
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, 40
    mov ecx, PK_CONFETTI
    mov r8d, 30
    call fx_burst
    jmp trailer_run.next
tr_op_trees:
    call tr_trees
    jmp trailer_run.next
tr_op_clear:
    call tr_clear
    jmp trailer_run.next
tr_op_load:
    ; a NUL-terminated file name follows
    mov rdi, [tr_pc]
    mov rbx, rdi
.ls:
    cmp byte [rbx], 0
    je .le
    inc rbx
    jmp .ls
.le:
    inc rbx
    mov [tr_pc], rbx
    call load_city_from
    mov dword [welcome], 0
    mov dword [panel], PANEL_NONE
    jmp trailer_run.next
tr_op_light:
    TRARGS [rbp-48]
    mov eax, [rbp-48]
    xor eax, 1
    mov [light_off], eax
    jmp trailer_run.next
tr_op_money:
    mov qword [money], 5000000
    jmp trailer_run.next
tr_op_lock:
    TRARGS [tod_lock]
    jmp trailer_run.next
tr_op_save:
    mov rdi, [tr_pc]
    mov rbx, rdi
.ss:
    cmp byte [rbx], 0
    je .se
    inc rbx
    jmp .ss
.se:
    inc rbx
    mov [tr_pc], rbx
    mov dword [save_quiet], 1
    call save_city_to
    jmp trailer_run.next
; drag a tool like the player does (tool, arg, x0 y0 x1 y1)
tr_op_drag:
    TRARGS [tool], [zone_type], [drag_sx], [drag_sy], [hover_tx], [hover_ty]
    mov dword [hover_valid], 1
    mov dword [drag_active], 1
    call tool_collect
    call tool_apply
    mov dword [drag_active], 0
    mov dword [tool], T_INSPECT
    jmp trailer_run.next
tr_op_stat:
    call stats_update
    lea rdi, [str_statfmt]
    mov esi, [population]
    mov edx, [power_supply]
    mov ecx, [power_demand]
    mov r8d, [water_supply]
    mov r9d, [water_demand]
    mov eax, [sewage_demand]
    push rax
    mov eax, [sewage_cap]
    push rax
    xor eax, eax
    call printf
    add rsp, 16
    lea rdi, [str_statfmt2]
    mov esi, [cnt_unpowered]
    mov edx, [cnt_nowater]
    mov ecx, [cnt_noroad]
    mov r8d, [cnt_abandon]
    mov r9d, [demand]
    sub rsp, 8
    push qword [year]
    push qword [demand+12]
    push qword [demand+8]
    push qword [demand+4]
    xor eax, eax
    call printf
    add rsp, 40
    ; problem counts over anchors of grown buildings
    lea rdi, [tr_prob]
    xor eax, eax
    mov ecx, 12
    rep stosd
    xor ecx, ecx
.pc:
    cmp ecx, MAP_TILES
    jge .pd
    mov eax, ecx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ZONEBLD
    jne .pn
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .pn
    movzx edx, byte [tiles+rax+T_PROBLEM]
    CLAMP edx, 0, 11
    inc dword [tr_prob+rdx*4]
.pn:
    inc ecx
    jmp .pc
.pd:
    lea rdi, [str_statfmt3]
    mov esi, [tr_prob+4]
    mov edx, [tr_prob+8]
    mov ecx, [tr_prob+12]
    mov r8d, [tr_prob+16]
    mov r9d, [tr_prob+20]
    sub rsp, 8
    push qword [tr_prob+24]
    xor eax, eax
    call printf
    add rsp, 16
    lea rdi, [str_statfmt4]
    mov esi, [tr_prob+28]
    mov edx, [tr_prob+32]
    mov ecx, [tr_prob+36]
    mov r8d, [tr_prob+40]
    mov r9d, [unemployed]
    sub rsp, 8
    push qword [workers]
    xor eax, eax
    call printf
    add rsp, 16
    jmp trailer_run.next
tr_op_lforce:
    TRARGS [light_force]
    jmp trailer_run.next
; time the stages of a frame over n frames (n)
%macro TRT 1
    CALLC SDL_GetPerformanceCounter
    mov rcx, rax
    sub rax, [rbp-64]
    add [rbp-%1], rax
    mov [rbp-64], rcx
%endmacro
tr_op_bench:
    TRARGS [rbp-48]
    xor eax, eax
    mov [rbp-56], rax
    mov [rbp-72], rax
    mov [rbp-80], rax
    mov [rbp-88], rax
    mov [rbp-96], rax
    mov [rbp-104], rax
    mov ebx, [rbp-48]
.bl:
    CALLC SDL_GetPerformanceCounter
    mov [rbp-64], rax
    call palette_update
    TRT 72
    call render_world
    TRT 80
    mov dword [emit_now], 0
    call draw_agents
    TRT 88
    call light_compose
    TRT 96
    ; what video_present does with the result: copy rows to a texture
    lea rdi, [shotbuf]
    lea rsi, [litbuf]
    mov ecx, [fb_w]
    imul ecx, [fb_h]
    rep movsd
    TRT 104
    dec ebx
    jnz .bl
    CALLC SDL_GetPerformanceFrequency
    mov rcx, rax
    xor edx, edx
    mov eax, 1000000
    ; us per frame = ticks * 1e6 / freq / n
%macro TRUS 2
    mov rax, [rbp-%1]
    imul rax, rax, 1000
    xor edx, edx
    div rcx
    imul rax, rax, 1000
    movsxd r8, dword [rbp-48]
    xor edx, edx
    div r8
    mov %2, eax
%endmacro
    mov [rbp-56], rcx
    mov rcx, [rbp-56]
    TRUS 72, esi
    mov rcx, [rbp-56]
    TRUS 80, edx
    mov [rbp-112], edx
    mov rcx, [rbp-56]
    TRUS 88, eax
    mov [rbp-116], eax
    mov rcx, [rbp-56]
    TRUS 96, eax
    mov [rbp-120], eax
    mov rcx, [rbp-56]
    TRUS 104, eax
    mov [rbp-124], eax
    lea rdi, [str_benchfmt]
    mov edx, [rbp-112]
    mov ecx, [rbp-116]
    mov r8d, [rbp-120]
    mov r9d, [rbp-124]
    xor eax, eax
    call printf
    jmp trailer_run.next
