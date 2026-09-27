; =====================================================================
;  TRAILER - a scripted "director" that films the game.
;
;  cityssembly --trailer out.raw
;  Renders a fixed sequence of cinematic shots with the real engine and
;  writes raw BGRA frames (window size, 30 fps) to out.raw (use a FIFO
;  into ffmpeg).  Shot boundaries are printed to stdout.
; =====================================================================

section .bss
tr_rw           resq 1
tr_ui           resd 1
tr_cx           resd 1          ; camera in 1/16 px
tr_cy           resd 1
tr_vx           resd 1
tr_vy           resd 1
tr_frames       resd 1
tr_follow       resd 1          ; vehicle slot, -1 = off
tr_todspeed     resd 1
tr_reveal_d     resd 1
tr_backup       resb MAP_TILES*TILE_BYTES

section .data
str_trailer_flag db "--trailer", 0
str_shotfmt      db "SHOT %s %d", 10, 0
sh_valley   db "valley", 0
sh_build    db "build", 0
sh_grow     db "grow", 0
sh_follow   db "follow", 0
sh_district db "district", 0
sh_power    db "view_power", 0
sh_water    db "view_water", 0
sh_traffic  db "view_traffic", 0
sh_land     db "view_land", 0
sh_sunset   db "sunset", 0
sh_night    db "night", 0
sh_seasons  db "seasons", 0
sh_meteor   db "meteor", 0
sh_ui_build db "ui_build", 0
sh_ui_stats db "ui_stats", 0
sh_ui_water db "ui_water", 0
sh_finale   db "finale", 0
sh_wide     db "wide", 0

section .text

; mark the start of a shot on stdout (rdi name)
FUNC tr_mark
    mov rsi, rdi
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
    mov dword [tr_vx], 0
    mov dword [tr_vy], 0
    RETURN

; follow camera: ease toward the tracked vehicle
FUNC tr_follow_update
    mov eax, [tr_follow]
    cmp eax, -1
    je .out
    shl eax, 7
    lea rbx, [vehicles+rax]
    cmp byte [rbx+V_TYPE], 255
    jne .have
    call tr_pick_car
    cmp dword [tr_follow], -1
    je .out
    mov eax, [tr_follow]
    shl eax, 7
    lea rbx, [vehicles+rax]
.have:
    ; world pixel of the vehicle
    mov eax, [rbx+V_WX]
    sub eax, [rbx+V_WY]
    sar eax, 4
    add eax, ORIGIN_X
    mov ecx, [fb_w]
    shr ecx, 1
    sub eax, ecx
    shl eax, 4
    mov ecx, [rbx+V_WX]
    add ecx, [rbx+V_WY]
    sar ecx, 5
    sub ecx, 4
    mov edx, [fb_h]
    shr edx, 1
    sub ecx, edx
    shl ecx, 4
    ; ease 1/6 of the way
    sub eax, [tr_cx]
    cdq
    mov r8d, 6
    idiv r8d
    add [tr_cx], eax
    mov eax, ecx
    sub eax, [tr_cy]
    cdq
    idiv r8d
    add [tr_cy], eax
.out:
    RETURN

; choose a car with a long way to go
FUNC tr_pick_car
    mov dword [tr_follow], -1
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
    movzx eax, word [rcx+V_PLEN]
    movzx edx, word [rcx+V_PPOS]
    sub eax, edx
    cmp eax, r12d
    jle .n
    ; a car cruising along the main avenue
    movzx edx, word [rcx+V_TY]
    cmp edx, [hwy_row]
    jne .n
    movzx edx, word [rcx+V_TX]
    cmp edx, 23
    jl .n
    cmp edx, 30
    jg .n
    cmp byte [rcx+V_DIR], 1         ; heading east
    jne .n
    mov r12d, eax
    mov [tr_follow], ebx
.n:
    inc ebx
    jmp .l
.out:
    RETURN

; render and write one frame, then advance the camera
FUNC tr_frame
    call tr_follow_update
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

; reveal the backed-up town outward from the highway, one ring per frame
FUNC tr_reveal_step
    mov r15d, [tr_reveal_d]
    mov r13d, [hwy_row]
    xor r14d, r14d                  ; tile index
.l:
    cmp r14d, MAP_TILES
    jge .out
    mov eax, r14d
    and eax, MAP_W-1
    sub eax, 22
    mov ecx, eax
    sar ecx, 31
    xor eax, ecx
    sub eax, ecx
    mov edx, r14d
    shr edx, MAP_SHIFT
    sub edx, r13d
    mov ecx, edx
    sar ecx, 31
    xor edx, ecx
    sub edx, ecx
    add eax, edx
    cmp eax, r15d
    jne .n
    ; copy this tile from the finished layout
    mov eax, r14d
    shl eax, TILE_SHIFT
    lea rsi, [tr_backup+rax]
    lea rdi, [tiles+rax]
    mov r12, rdi
    mov ecx, TILE_BYTES
    rep movsb
    mov edi, r14d
    and edi, MAP_W-1
    mov esi, r14d
    shr esi, MAP_SHIFT
    mov [rbp-48], edi
    mov [rbp-52], esi
    call roads_update_around
    cmp byte [r12+T_OBJ], OBJ_NONE
    je .n
    cmp byte [r12+T_OBJ], OBJ_TREE
    je .n
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, 2
    mov ecx, PK_DUST
    mov r8d, 1
    call fx_burst
    cmp byte [r12+T_OBJ], OBJ_SERVICE
    jne .n
    test byte [r12+T_FLAGS], F_ANCHOR
    jz .n
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, 12
    mov ecx, PK_SPARK
    mov r8d, 12
    call fx_burst
.n:
    inc r14d
    jmp .l
.out:
    inc dword [tr_reveal_d]
    RETURN

%macro SHOTNAME 1
    lea rdi, [%1]
    call tr_mark
%endmacro
%macro ZOOM 1
    mov edi, %1
    call video_set_zoom
%endmacro
%macro CAM 2
    mov edi, %1
    lea esi, [%2]
    call tr_cam_tile
%endmacro
%macro VEL 2
    mov dword [tr_vx], %1
    mov dword [tr_vy], %2
%endmacro
%macro FILM 2
    mov edi, %1
    mov esi, %2
    call tr_shot
%endmacro

; ---------------------------------------------------------------------
FUNC trailer_run, 16
    mov rdi, [shot_file]
    lea rsi, [str_wb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz .out
    mov [tr_rw], rax
    mov dword [welcome], 0
    mov dword [tr_follow], -1
    mov dword [tod_lock], 0
    mov dword [tr_todspeed], 0
    mov dword [disasters_on], 0
    mov r12d, [hwy_row]

    ; ---- 1. the untouched valley at dawn ----
    SHOTNAME sh_valley
    mov dword [tod], 62*256
    mov dword [tr_todspeed], 6
    mov dword [season_pos], 100
    ZOOM 2
    CAM 94, 57
    VEL 14, 2
    FILM 96, 2

    ; ---- 2. the town is drawn out from the highway ----
    ; build the whole layout, keep it aside, restore the empty land
    lea rsi, [tiles]
    lea rdi, [tr_backup]
    mov ecx, MAP_TILES*TILE_BYTES/8
    rep movsq
    mov dword [demo_no_ff], 1
    call demo_build
    mov dword [welcome], 0
    lea rsi, [tiles]
    lea rdi, [tr_backup+0]
    ; swap: tr_backup <- built, tiles <- empty
    mov ecx, MAP_TILES*TILE_BYTES/8
.swap:
    mov rax, [rsi]
    mov rdx, [rdi]
    mov [rsi], rdx
    mov [rdi], rax
    add rsi, 8
    add rdi, 8
    dec ecx
    jnz .swap
    SHOTNAME sh_build
    mov dword [tod], 110*256
    mov dword [tr_todspeed], 0
    mov dword [season_pos], 240
    ZOOM 2
    CAM 30, r12
    VEL 22, -4
    ; the first few rings are already drawn when the shot opens
    mov dword [tr_reveal_d], 0
    mov ebx, 5
.pre:
    call tr_reveal_step
    dec ebx
    jnz .pre
    mov ebx, 108
.rv:
    ; two rings every three frames
    mov eax, ebx
    xor edx, edx
    mov ecx, 3
    div ecx
    test edx, edx
    jz .rvs
    call tr_reveal_step
.rvs:
    call tr_frame
    mov edi, 2
    call tr_ticks
    dec ebx
    jnz .rv
    ; make sure every tile is revealed, networks up to date
    lea rsi, [tr_backup]
    lea rdi, [tiles]
    mov ecx, MAP_TILES*TILE_BYTES/8
    rep movsq
    call roads_update_all
    mov dword [net_dirty], 1
    call networks_update
    call coverage_update
    call stats_update

    ; ---- 3. time-lapse: the city grows ----
    SHOTNAME sh_grow
    mov dword [sim_speed], 3
    ZOOM 1
    CAM 38, r12
    VEL 6, -3
    mov dword [tr_todspeed], 0
    mov dword [tod], 120*256
    FILM 90, 3
    FILM 90, 7
    FILM 120, 14
    mov dword [sim_speed], 1

    ; ---- 4. following a car ----
    SHOTNAME sh_follow
    ZOOM 3
    call tr_pick_car
    CAM 38, r12
    FILM 150, 2
    mov dword [tr_follow], -1

    ; ---- 5. drift over the dense district ----
    SHOTNAME sh_district
    ZOOM 3
    CAM 47, r12-8
    VEL -10, 4
    FILM 120, 2

    ; ---- 6. info views ----
    ZOOM 1
    CAM 38, r12
    VEL 0, 0
    SHOTNAME sh_power
    mov dword [overlay_mode], OV_POWER
    FILM 36, 2
    SHOTNAME sh_water
    mov dword [overlay_mode], OV_WATER
    FILM 36, 2
    SHOTNAME sh_traffic
    mov dword [overlay_mode], OV_TRAFFIC
    FILM 36, 2
    SHOTNAME sh_land
    mov dword [overlay_mode], OV_LANDVAL
    FILM 36, 2
    mov dword [overlay_mode], 0

    ; ---- 7. sunset into night ----
    SHOTNAME sh_sunset
    ZOOM 2
    CAM 32, r12-4
    VEL 14, 4
    mov dword [tod], 160*256
    mov dword [tr_todspeed], 48
    FILM 150, 2
    SHOTNAME sh_night
    mov dword [tod], 12*256
    mov dword [tr_todspeed], 0
    CAM 43, r12+2
    VEL -12, -3
    FILM 120, 2

    ; ---- 8. four seasons ----
    SHOTNAME sh_seasons
    ZOOM 1
    CAM 36, r12-2
    VEL 0, 0
    mov dword [tod], 118*256
    xor ebx, ebx
.sea:
    mov eax, ebx
    shl eax, 3
    add eax, 128
    and eax, 1023
    mov [season_pos], eax
    call tr_frame
    mov edi, 2
    call tr_ticks
    inc ebx
    cmp ebx, 128
    jl .sea
    mov dword [season_pos], 240

    ; ---- 9. disaster ----
    SHOTNAME sh_meteor
    ZOOM 2
    CAM 30, r12+10
    mov dword [sim_speed], 2
    FILM 20, 2
    mov edi, 30
    lea esi, [r12+10]
    call meteor_strike
    FILM 160, 3
    mov dword [sim_speed], 1

    ; ---- 10. the interface ----
    mov dword [tr_ui], 1
    lea rdi, [notif_time]
    xor eax, eax
    mov ecx, NOTIFS
    rep stosd
    mov dword [mouse_x], 470
    mov dword [mouse_y], 250
    SHOTNAME sh_ui_build
    ZOOM 2
    CAM 36, r12+9
    mov dword [tool], T_BUILD
    mov dword [build_kind], BK_STADIUM
    FILM 45, 2
    SHOTNAME sh_ui_stats
    mov dword [tool], T_INSPECT
    mov dword [panel], PANEL_STATS
    mov dword [mouse_x], 900
    mov dword [mouse_y], 500
    FILM 45, 2
    SHOTNAME sh_ui_water
    mov dword [panel], PANEL_NONE
    mov dword [submenu], 3
    mov dword [submenu_x], 250
    mov dword [mouse_x], 300
    mov dword [mouse_y], 440
    FILM 45, 2
    mov dword [submenu], -1
    mov dword [tr_ui], 0

    ; ---- 11. golden hour finale ----
    SHOTNAME sh_finale
    ZOOM 2
    CAM 44, r12-3
    VEL -16, 2
    mov dword [tod], 178*256
    mov dword [tr_todspeed], 3
    FILM 150, 2

    ; ---- 12. wide establishing (for the end card) ----
    SHOTNAME sh_wide
    ZOOM 1
    CAM 40, r12
    VEL 4, -2
    mov dword [tod], 186*256
    FILM 120, 2

    mov rdi, [tr_rw]
    CALLC SDL_RWclose
.out:
    RETURN
