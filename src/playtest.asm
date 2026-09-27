; =====================================================================
;  scripted new-player session (--demo 1 file.bmp T): builds a small
;  town with the player's tools only, runs it and prints a report
; =====================================================================
section .data
pt_fmt1 db "PLAYTEST pump=%d,%d outlet=%d,%d wires=%d", 10, 0
pt_fmt2 db "PLAYTEST day %d pop=%d bld=%d powered=%d water=%d sewage=%d", 10, 0
pt_fmt3 db "PLAYTEST problems:", 0
pt_fmt4 db " %d", 0
pt_fmt6 db "PLAYTEST money=%d income: res=%d com=%d ind=%d off=%d", 10, 0
pt_fmt7 db "PLAYTEST          other=%d  expense: roads=%d services=%d", 10, 0
pt_fmt8 db "PLAYTEST money after building=%d", 10, 0
pt_fmt9 db "PLAYTEST south plot status=%d milestone=%d", 10, 0
pt_fmt5 db 10, "PLAYTEST pump powered=%d pump problem=%d supply=%d demand=%d", 10, 0
section .bss
pt_px resd 1
pt_py resd 1
pt_ox resd 1
pt_oy resd 1
pt_hist resd 16
section .text

; pt_drag(edi tool, esi x0, edx y0, ecx x1, r8d y1)
FUNC pt_drag
    mov [tool], edi
    mov [drag_sx], esi
    mov [drag_sy], edx
    mov [hover_tx], ecx
    mov [hover_ty], r8d
    mov dword [hover_valid], 1
    mov dword [drag_active], 1
    call tool_collect
    call tool_apply
    mov dword [drag_active], 0
    RETURN

; pt_place(edi kind, esi x, edx y)
FUNC pt_place
    mov [build_kind], edi
    mov dword [tool], T_BUILD
    mov [hover_tx], esi
    mov [hover_ty], edx
    mov dword [hover_valid], 1
    mov dword [drag_active], 0
    call tool_collect
    call tool_apply
    RETURN

; shore tile nearest to (edi x, esi y), at least edx from (pt_px,pt_py)
; -> eax x, edx y (or -1)
FUNC pt_shore, 32
    mov [rbp-48], edi
    mov [rbp-52], esi
    mov [rbp-56], edx
    mov dword [rbp-60], 0x7fffffff
    mov dword [rbp-64], -1
    mov dword [rbp-68], -1
    xor r13d, r13d
.y:
    xor r12d, r12d
.x:
    mov edi, r12d
    mov esi, r13d
    call tile_at
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .n
    cmp byte [rax+T_OBJ], OBJ_NONE
    jne .n
    cmp byte [rax+T_ZONE], 0
    jne .n
    mov edi, r12d
    mov esi, r13d
    call tile_owned
    test eax, eax
    jz .n
    mov edi, r12d
    mov esi, r13d
    call count_water_near
    test eax, eax
    jz .n
    ; far enough from the pump?
    mov eax, r12d
    sub eax, [pt_px]
    imul eax, eax
    mov ecx, r13d
    sub ecx, [pt_py]
    imul ecx, ecx
    add eax, ecx
    mov ecx, [rbp-56]
    imul ecx, ecx
    cmp eax, ecx
    jl .n
    mov eax, r12d
    sub eax, [rbp-48]
    imul eax, eax
    mov ecx, r13d
    sub ecx, [rbp-52]
    imul ecx, ecx
    add eax, ecx
    cmp eax, [rbp-60]
    jge .n
    mov [rbp-60], eax
    mov [rbp-64], r12d
    mov [rbp-68], r13d
.n:
    inc r12d
    cmp r12d, MAP_W
    jl .x
    inc r13d
    cmp r13d, MAP_W
    jl .y
    mov eax, [rbp-64]
    mov edx, [rbp-68]
    RETURN

FUNC pt_report
    xor r12d, r12d          ; buildings
    xor r13d, r13d          ; powered
    xor r14d, r14d          ; water
    xor r15d, r15d          ; sewage
    lea rdi, [pt_hist]
    xor eax, eax
    mov ecx, 16
    rep stosd
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    cmp byte [rdi+T_OBJ], OBJ_ZONEBLD
    jne .n
    test byte [rdi+T_FLAGS], F_ANCHOR
    jz .n
    inc r12d
    movzx eax, byte [rdi+T_PROBLEM]
    and eax, 15
    inc dword [pt_hist+rax*4]
    test byte [rdi+T_FLAGS], F_POWER
    jz .a
    inc r13d
.a: test byte [rdi+T_FLAGS], F_WATER
    jz .b
    inc r14d
.b: test byte [rdi+T_FLAGS2], F2_SEWAGE
    jz .n
    inc r15d
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    lea rdi, [pt_fmt2]
    mov esi, [day_count]
    mov edx, [population]
    mov ecx, r12d
    mov r8d, r13d
    mov r9d, r14d
    push r15
    push r15
    xor eax, eax
%ifdef WIN64
    sub rsp, 48
    mov [rsp+32], r8
    mov [rsp+40], r9
    mov [rsp+48], r15
    mov r9, rcx
    mov r8, rdx
    mov rdx, rsi
    mov rcx, rdi
    call printf
    add rsp, 48
%else
    call printf
%endif
    pop r15
    pop r15
    lea rdi, [pt_fmt3]
    xor eax, eax
    CALLC printf
    xor ebx, ebx
.h:
    lea rdi, [pt_fmt4]
    mov esi, [pt_hist+rbx*4]
    xor eax, eax
    CALLC printf
    inc ebx
    cmp ebx, 11
    jl .h
    mov edi, [pt_px]
    mov esi, [pt_py]
    call tile_at
    movzx esi, byte [rax+T_FLAGS]
    and esi, F_POWER
    movzx edx, byte [rax+T_PROBLEM]
    lea rdi, [pt_fmt5]
    mov ecx, [water_supply]
    mov r8d, [water_demand]
    xor eax, eax
    CALLC printf
    lea rdi, [pt_fmt6]
    mov rsi, [money]
    mov edx, [inc_class]
    mov ecx, [inc_class+4]
    mov r8d, [inc_class+8]
    mov r9d, [inc_class+12]
    xor eax, eax
    CALLC printf
    lea rdi, [pt_fmt7]
    mov esi, [inc_other]
    mov edx, [exp_roads]
    mov ecx, [exp_services]
    xor eax, eax
    CALLC printf
    RETURN

FUNC playtest_build
    mov dword [welcome], 0
    ; main street off the highway, cross street
    mov dword [road_type], RT_STREET
    mov edi, T_ROAD
    mov esi, 26
    mov edx, 64
    mov ecx, 45
    mov r8d, 64
    call pt_drag
    mov edi, T_ROAD
    mov esi, 36
    mov edx, 54
    mov ecx, 36
    mov r8d, 74
    call pt_drag
    ; zones
    mov dword [zone_type], ZONE_R
    mov edi, T_ZONETOOL
    mov esi, 27
    mov edx, 59
    mov ecx, 35
    mov r8d, 63
    call pt_drag
    mov edi, T_ZONETOOL
    mov esi, 37
    mov edx, 59
    mov ecx, 45
    mov r8d, 63
    call pt_drag
    mov dword [zone_type], ZONE_C
    mov edi, T_ZONETOOL
    mov esi, 37
    mov edx, 65
    mov ecx, 45
    mov r8d, 68
    call pt_drag
    mov dword [zone_type], ZONE_I
    mov edi, T_ZONETOOL
    mov esi, 27
    mov edx, 65
    mov ecx, 35
    mov r8d, 70
    call pt_drag
    ; coal plant in the corner, a short line to the shops
    mov edi, BK_COAL
    mov esi, 43
    mov edx, 74
    call pt_place
    mov edi, T_POWERLN
    mov esi, 42
    mov edx, 73
    mov ecx, 40
    mov r8d, 70
    call pt_drag
    ; pump upstream (north), outlet downstream (south)
    mov dword [pt_px], -1000
    mov dword [pt_py], -1000
    mov edi, 46
    mov esi, 53
    xor edx, edx
    call pt_shore
    mov [pt_px], eax
    mov [pt_py], edx
    mov edi, BK_PUMP
    mov esi, eax
    call pt_place
    mov edi, T_PIPE
    mov esi, [pt_px]
    mov edx, [pt_py]
    mov ecx, 36
    mov r8d, [pt_py]
    call pt_drag
    mov edi, T_PIPE
    mov esi, 36
    mov edx, [pt_py]
    mov ecx, 36
    mov r8d, 64
    call pt_drag
    mov edi, T_PIPE
    mov esi, 26
    mov edx, 64
    mov ecx, 45
    mov r8d, 64
    call pt_drag
    mov edi, T_PIPE
    mov esi, 36
    mov edx, 54
    mov ecx, 36
    mov r8d, 74
    call pt_drag
    mov edi, T_POWERLN
    mov esi, [pt_px]
    mov edx, [pt_py]
    mov ecx, 44
    mov r8d, 61
    call pt_drag
    mov edi, 46
    mov esi, 76
    mov edx, 16
    call pt_shore
    mov [pt_ox], eax
    mov [pt_oy], edx
    mov edi, BK_SEWAGE
    mov esi, eax
    call pt_place
    mov edi, T_PIPE
    mov esi, [pt_ox]
    mov edx, [pt_oy]
    mov ecx, 36
    mov r8d, [pt_oy]
    call pt_drag
    mov edi, T_PIPE
    mov esi, 36
    mov edx, [pt_oy]
    mov ecx, 36
    mov r8d, 64
    call pt_drag
    mov dword [tool], T_INSPECT
    mov dword [net_dirty], 1
    call networks_update
    lea rdi, [pt_fmt1]
    mov esi, [pt_px]
    mov edx, [pt_py]
    mov ecx, [pt_ox]
    mov r8d, [pt_oy]
    mov r9d, [n_wires]
    xor eax, eax
    CALLC printf
    lea rdi, [pt_fmt8]
    mov rsi, [money]
    xor eax, eax
    CALLC printf
    ; play a few years, buying land when we can
    mov r13d, 12
.m:
    mov dword [sim_speed], 3
    mov ebx, 700
.ff:
    call sim_tick
    call agents_tick
    inc dword [anim_tick]
    dec ebx
    jnz .ff
    call pt_report
    ; try the plot to the south
    mov dword [hover_valid], 1
    mov dword [hover_tx], 36
    mov dword [hover_ty], 85
    mov edi, START_PLOT+PLOTS
    call plot_status
    lea rdi, [pt_fmt9]
    mov esi, eax
    mov edx, [milestone]
    push rax
    push rax
    xor eax, eax
    CALLC printf
    pop rax
    pop rax
    test eax, eax
    jnz .nb
    call land_click
.nb:
    dec r13d
    jnz .m
    mov dword [sim_speed], 1
    mov rax, [money]
    mov [money_shown], rax
    mov dword [ms_card], 0
    mov dword [tool], T_LAND
    mov edi, 1
    call video_set_zoom
    mov edi, 40
    mov esi, 64
    call camera_center_tile
    RETURN

; ---------------------------------------------------------------------
;  --demo 1 out.bmp L : load city.sav and explain its water / sewage
; ---------------------------------------------------------------------
section .data
dg_fmt1 db "DIAG pop=%d money=%d milestone=%d plots=%d", 10, 0
dg_fmt2 db "DIAG net %d: tiles=%d supply=%d sewcap=%d demand=%d users=%d (water %d, sewage %d)", 10, 0
dg_fmt3 db "DIAG buildings=%d water=%d sewage=%d nopipe=%d", 10, 0
dg_fmt4 db "DIAG %s at %d,%d net=%d powered=%d", 10, 0
dg_pump db "pump", 0
dg_out  db "outlet", 0
dg_tow  db "tower", 0
section .bss
dg_tiles resd 512
dg_users resd 512
dg_wat   resd 512
dg_sew   resd 512
section .text

FUNC pt_diagnose, 32
    call water_flood
    call plots_owned
    mov r8d, eax
    lea rdi, [dg_fmt1]
    mov esi, [population]
    mov rdx, [money]
    mov ecx, [milestone]
    xor eax, eax
    CALLC printf
    lea rdi, [dg_tiles]
    xor eax, eax
    mov ecx, 512*4
    rep stosd
    xor ebx, ebx
    xor r12d, r12d          ; buildings
    xor r13d, r13d          ; water
    xor r14d, r14d          ; sewage
    xor r15d, r15d          ; no pipe
.l:
    movzx eax, word [comp_map+rbx*2]
    cmp eax, 511
    ja .nt
    inc dword [dg_tiles+rax*4]
.nt:
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    ; water buildings
    cmp byte [rdi+T_OBJ], OBJ_SERVICE
    jne .z
    test byte [rdi+T_FLAGS], F_ANCHOR
    jz .z
    movzx eax, byte [rdi+T_SUB]
    lea rsi, [dg_pump]
    cmp eax, BK_PUMP
    je .svc
    lea rsi, [dg_out]
    cmp eax, BK_SEWAGE
    je .svc
    lea rsi, [dg_tow]
    cmp eax, BK_WTOWER
    jne .z
.svc:
    push rdi
    push rdi
    movzx r9d, byte [rdi+T_FLAGS]
    and r9d, F_POWER
    movzx r8d, word [comp_map+rbx*2]
    mov edx, ebx
    and edx, MAP_W-1
    mov ecx, ebx
    shr ecx, MAP_SHIFT
    lea rdi, [dg_fmt4]
    xor eax, eax
    CALLC printf
    pop rdi
    pop rdi
.z:
    cmp byte [rdi+T_OBJ], OBJ_ZONEBLD
    jne .n
    test byte [rdi+T_FLAGS], F_ANCHOR
    jz .n
    inc r12d
    movzx eax, word [cons_comp+rbx*2]
    test eax, eax
    jnz .has
    inc r15d
.has:
    cmp eax, 511
    ja .n
    inc dword [dg_users+rax*4]
    test byte [rdi+T_FLAGS], F_WATER
    jz .a
    inc r13d
    inc dword [dg_wat+rax*4]
.a: test byte [rdi+T_FLAGS2], F2_SEWAGE
    jz .n
    inc r14d
    inc dword [dg_sew+rax*4]
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    lea rdi, [dg_fmt3]
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    mov r8d, r15d
    xor eax, eax
    CALLC printf
    mov ebx, 1
.c:
    cmp dword [dg_tiles+rbx*4], 0
    je .cn
    lea rdi, [dg_fmt2]
    mov esi, ebx
    mov edx, [dg_tiles+rbx*4]
    mov ecx, [comp_supply+rbx*4]
    mov r8d, [comp_sewcap+rbx*4]
    mov r9d, [comp_demand+rbx*4]
    mov eax, [dg_sew+rbx*4]
    push rax
    mov eax, [dg_wat+rbx*4]
    push rax
    mov eax, [dg_users+rbx*4]
    push rax
    xor eax, eax
%ifdef WIN64
    sub rsp, 8
%endif
    call pt_printf8
%ifdef WIN64
    add rsp, 8
%endif
    add rsp, 24
.cn:
    inc ebx
    cmp ebx, 512
    jl .c
    RETURN

; printf with 3 extra stack args already pushed (SysV) - Linux only helper
pt_printf8:
%ifdef WIN64
    ret
%else
    sub rsp, 8
    push qword [rsp+32]
    push qword [rsp+32]
    push qword [rsp+32]
    call printf
    add rsp, 32
    ret
%endif

; after loading: look at the water view over the town
FUNC pt_diag_view
    mov dword [tool], T_PIPE
    mov edi, 2
    call video_set_zoom
    mov edi, 38
    mov esi, 64
    call camera_center_tile
    ; hover the treasury so its tooltip shows in the shot
    mov dword [mouse_x], 360
    mov dword [mouse_y], 12
    RETURN

; --demo 1 out.bmp D : click every dock button, print what opens
section .data
dk_fmt db "DOCK button %d -> tool=%d submenu=%d panel=%d", 10, 0
section .text
FUNC pt_dock_test, 16
    mov dword [welcome], 0
    xor ebx, ebx
.l:
    cmp ebx, DOCK_COUNT
    jge .out
    mov dword [panel], PANEL_NONE
    mov dword [submenu], -1
    mov dword [tool], T_INSPECT
    mov eax, DOCK_COUNT
    imul eax, DOCK_BTN+2
    add eax, 8
    mov ecx, [ui_w]
    sub ecx, eax
    shr ecx, 1
    imul eax, ebx, DOCK_BTN+2
    lea eax, [rcx+rax+4+10]
    imul eax, [ui_scale]
    mov [mouse_x], eax
    mov eax, [ui_h]
    sub eax, DOCK_BTN+8-3-10
    imul eax, [ui_scale]
    mov [mouse_y], eax
    mov dword [click_pending], 1
    call render_ui
    lea rdi, [dk_fmt]
    mov esi, ebx
    mov edx, [tool]
    mov ecx, [submenu]
    mov r8d, [panel]
    xor eax, eax
    CALLC printf
    inc ebx
    jmp .l
.out:
    mov dword [panel], PANEL_NONE
    RETURN

; --demo 1 out.bmp M : click the minimap, print the camera
section .data
mm_fmt db "MINIMAP click on tile %d,%d -> view centred on %d,%d", 10, 0
mm_tx dd 30, 100, 64, 10
mm_ty dd 64, 20, 110, 10
section .text
FUNC pt_minimap_test, 32
    mov dword [welcome], 0
    mov dword [minimap_on], 1
    call render_ui
    ; click where tile (tx,ty) is drawn: px=(x-y)/2+64, py=(x+y)/4
    xor ebx, ebx
.t:
    cmp ebx, 4
    jge .out
    mov r14d, [mm_tx+rbx*4]
    mov r15d, [mm_ty+rbx*4]
    mov edi, r14d
    mov esi, r15d
    call tile_to_minimap
    push r12
    push r13
    push rax
    push rdx
    call minimap_pos
    pop rdx
    pop rax
    lea eax, [rax+r12+3]
    lea edx, [rdx+r13+3]
    pop r13
    pop r12
    imul eax, [ui_scale]
    mov [mouse_x], eax
    imul edx, [ui_scale]
    mov [mouse_y], edx
    mov dword [lmb_down], 0
    mov dword [click_pending], 1
    call render_ui
    ; which tile is at the screen centre now?
    mov edi, [fb_w]
    shr edi, 1
    add edi, [cam_x]
    mov esi, [fb_h]
    shr esi, 1
    add esi, [cam_y]
    call world_to_tile
    lea rdi, [mm_fmt]
    mov esi, r14d
    mov ecx, eax
    mov r8d, edx
    mov edx, r15d
    xor eax, eax
    call printf
    inc ebx
    jmp .t
.out:
    RETURN

; --demo 1 out.bmp R : load city.sav, simulate, report traffic
section .data
tr_f1 db "TRAFFIC pop=%d flow=%d%% trips ok=%d failed=%d commute=%d links=%d", 10, 0
tr_f2 db "TRAFFIC roads: street=%d avenue=%d highway=%d  vehicles=%d waiting=%d", 10, 0
tr_f3 db "TRAFFIC purpose %d: %d vehicles", 10, 0
tr_f4 db "TRAFFIC hot %d,%d type=%d jam=%d traffic=%d queued=%d mask=%d", 10, 0
tr_f5 db "TRAFFIC link %d,%d", 10, 0
tr_cam db "CAM %d %d %d", 10, 0
tr_f6 db "TRAFFIC buildings with no route: %d  zone bld=%d", 10, 0
tr_f7 db "TRAFFIC vehicles on the north link: %d  mask(44,18)=%d mask(44,17)=%d", 10, 0
section .data
pt_ticks dd 700
section .bss
tr_q    resw MAP_TILES
tr_pur  resd 16
tr_best resd 16
section .text
FUNC pt_traffic, 32
    mov dword [sim_speed], 3
    mov dword [trips_ok], 0
    mov dword [trips_failed], 0
    mov ebx, [pt_ticks]
.ff:
    call sim_tick
    call agents_tick
    inc dword [anim_tick]
    dec ebx
    jnz .ff
    ; queues right now
    lea rdi, [tr_q]
    xor eax, eax
    mov ecx, MAP_TILES/2
    rep stosd
    lea rdi, [tr_pur]
    mov ecx, 16
    rep stosd
    xor ebx, ebx
    xor r12d, r12d                  ; active
    xor r13d, r13d                  ; waiting
.v:
    mov eax, ebx
    shl eax, 7
    lea rdi, [vehicles+rax]
    cmp byte [rdi+V_TYPE], 255
    je .vn
    inc r12d
    movzx eax, byte [rdi+V_PURP]
    and eax, 15
    inc dword [tr_pur+rax*4]
    cmp word [rdi+V_WAIT], 30
    jb .vn
    inc r13d
    movzx eax, word [rdi+V_TY]
    shl eax, MAP_SHIFT
    movzx ecx, word [rdi+V_TX]
    add eax, ecx
    inc word [tr_q+rax*2]
.vn:
    inc ebx
    cmp ebx, MAX_VEH
    jl .v
    mov [rbp-48], r12d
    mov [rbp-52], r13d
    ; anyone on column 44 north of the town?
    xor ebx, ebx
    xor r14d, r14d
.nk:
    mov eax, ebx
    shl eax, 7
    lea rdi, [vehicles+rax]
    cmp byte [rdi+V_TYPE], 255
    je .nkn
    cmp word [rdi+V_TX], 44
    jne .nkn
    cmp word [rdi+V_TY], 48
    jae .nkn
    inc r14d
.nkn:
    inc ebx
    cmp ebx, MAX_VEH
    jl .nk
    mov edi, 44
    mov esi, 18
    call tile_at
    movzx edx, byte [rax+T_SUB]
    push rdx
    mov edi, 44
    mov esi, 17
    call tile_at
    movzx ecx, byte [rax+T_SUB]
    pop rdx
    lea rdi, [tr_f7]
    mov esi, r14d
    xor eax, eax
    call printf
    lea rdi, [tr_f1]
    mov esi, [population]
    mov edx, [flow_pct]
    mov ecx, [trips_ok]
    mov r8d, [trips_failed]
    mov r9d, [avg_commute]
    push qword [n_links]
    push qword [n_links]
    xor eax, eax
    call printf
    add rsp, 16
    ; road counts
    xor ebx, ebx
    xor r12d, r12d
    xor r13d, r13d
    xor r14d, r14d
    xor r15d, r15d                  ; no-route buildings
    mov dword [rbp-56], 0
.r:
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    cmp byte [rdi+T_OBJ], OBJ_ZONEBLD
    jne .rr
    test byte [rdi+T_FLAGS], F_ANCHOR
    jz .rn
    inc dword [rbp-56]
    cmp byte [rdi+T_PROBLEM], PR_ROUTE
    jne .rn
    inc r15d
    jmp .rn
.rr:
    cmp byte [rdi+T_OBJ], OBJ_ROAD
    jne .rn
    movzx eax, byte [rdi+T_ROADTYPE]
    cmp eax, 1
    je .ra
    ja .rh
    inc r12d
    jmp .rn
.ra: inc r13d
    jmp .rn
.rh: inc r14d
.rn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .r
    lea rdi, [tr_f2]
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    mov r8d, [rbp-48]
    mov r9d, [rbp-52]
    xor eax, eax
    call printf
    lea rdi, [tr_f6]
    mov esi, r15d
    mov edx, [rbp-56]
    xor eax, eax
    call printf
    xor ebx, ebx
.p:
    cmp dword [tr_pur+rbx*4], 0
    je .pn
    lea rdi, [tr_f3]
    mov esi, ebx
    mov edx, [tr_pur+rbx*4]
    xor eax, eax
    call printf
.pn:
    inc ebx
    cmp ebx, 11
    jl .p
    xor ebx, ebx
.lk:
    cmp ebx, [n_links]
    jge .hot
    movzx eax, word [links+rbx*2]
    mov esi, eax
    and esi, MAP_W-1
    mov edx, eax
    shr edx, MAP_SHIFT
    lea rdi, [tr_f5]
    xor eax, eax
    call printf
    inc ebx
    jmp .lk
.hot:
    call pt_ascii
    ; 14 worst tiles by queued cars, then jam
    mov dword [rbp-60], 0
.pick:
    cmp dword [rbp-60], 14
    jge .out
    mov r12d, -1                    ; best score
    mov r13d, -1                    ; best tile
    xor ebx, ebx
.t:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    jne .tn
    movzx ecx, word [tr_q+rbx*2]
    shl ecx, 8
    movzx edx, byte [tiles+rax+T_JAM]
    add ecx, edx
    test ecx, ecx
    jz .tn
    cmp ecx, r12d
    jle .tn
    mov r12d, ecx
    mov r13d, ebx
.tn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .t
    cmp r13d, 0
    jl .out
    mov eax, [rbp-60]
    mov [tr_best+rax*4], r13d
    mov eax, r13d
    shl eax, TILE_SHIFT
    lea rdi, [tr_f4]
    mov esi, r13d
    and esi, MAP_W-1
    mov edx, r13d
    shr edx, MAP_SHIFT
    movzx ecx, byte [tiles+rax+T_ROADTYPE]
    movzx r8d, byte [tiles+rax+T_JAM]
    movzx r9d, byte [tiles+rax+T_TRAFFIC]
    movzx r10d, byte [tiles+rax+T_SUB]
    movzx r11d, word [tr_q+r13*2]
    mov byte [tiles+rax+T_JAM], 0   ; exclude from the next pick
    mov word [tr_q+r13*2], 0
    push r10
    push r11
    xor eax, eax
    call printf
    add rsp, 16
    inc dword [rbp-60]
    jmp .pick
.out:
    ; show the worst spot in the traffic view
    mov dword [overlay_mode], OV_TRAFFIC
    mov edi, 1
    call video_set_zoom
    mov edi, 30
    mov esi, 62
    call camera_center_tile
    mov dword [mouse_x], 1275
    mov dword [mouse_y], 400
    lea rdi, [tr_cam]
    mov esi, [cam_x]
    mov edx, [cam_y]
    mov ecx, [zoom]
    xor eax, eax
    call printf
    RETURN

; ascii map of x 8..71, y 36..91 (after pt_traffic)
section .data
am_row db "%2d ", 0
am_ch  db "%c", 0
am_nl  db 10, 0
am_hdr db "   x=8 -> 71", 10, 0
section .text
FUNC pt_ascii
    lea rdi, [am_hdr]
    xor eax, eax
    call printf
    mov r13d, 36
.y:
    lea rdi, [am_row]
    mov esi, r13d
    xor eax, eax
    call printf
    mov r12d, 8
.x:
    mov edi, r12d
    mov esi, r13d
    call tile_at
    mov rbx, rax
    movzx eax, byte [rbx+T_OBJ]
    mov esi, '.'
    cmp byte [rbx+T_TERRAIN], TER_WATER
    jne .a
    mov esi, '~'
.a: cmp eax, OBJ_ROAD
    jne .b
    movzx ecx, byte [rbx+T_ROADTYPE]
    mov esi, '+'
    cmp ecx, 1
    jne .a2
    mov esi, '='
.a2:
    cmp ecx, 2
    jne .a3
    mov esi, 'H'
.a3:
    ; queued cars show as digits
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    movzx ecx, word [tr_q+rax*2]
    test ecx, ecx
    jz .p
    CLAMP ecx, 1, 9
    lea esi, [rcx+'0']
    jmp .p
.b: cmp eax, OBJ_ZONEBLD
    jne .c
    movzx ecx, byte [rbx+T_ZONE]
    movzx esi, byte [am_zone+rcx]
    jmp .p
.c: cmp eax, OBJ_SERVICE
    jne .d
    mov esi, 'S'
    jmp .p
.d: cmp eax, OBJ_POWER
    jne .e
    mov esi, 'p'
    jmp .p
.e: cmp eax, OBJ_TREE
    jne .p
    mov esi, 't'
.p:
    lea rdi, [am_ch]
    xor eax, eax
    call printf
    inc r12d
    cmp r12d, 72
    jl .x
    lea rdi, [am_nl]
    xor eax, eax
    call printf
    inc r13d
    cmp r13d, 92
    jl .y
    RETURN
section .data
am_zone db ".rciorc"
section .text

section .data
po_fmt db "PLOTS row %d: %d %d %d %d %d", 10, 0
sv_fmt db "SVC kind %d x%d", 10, 0
section .text
FUNC pt_plots
    xor ebx, ebx
.r:
    imul eax, ebx, PLOTS
    lea rdi, [po_fmt]
    mov esi, ebx
    movzx edx, byte [plot_owned+rax]
    movzx ecx, byte [plot_owned+rax+1]
    movzx r8d, byte [plot_owned+rax+2]
    movzx r9d, byte [plot_owned+rax+3]
    movzx eax, byte [plot_owned+rax+4]
    push rax
    push rax
    xor eax, eax
    call printf
    add rsp, 16
    inc ebx
    cmp ebx, PLOTS
    jl .r
    xor ebx, ebx
.s:
    cmp dword [svc_count+rbx*4], 0
    je .sn
    lea rdi, [sv_fmt]
    mov esi, ebx
    mov edx, [svc_count+rbx*4]
    xor eax, eax
    call printf
.sn:
    inc ebx
    cmp ebx, BK_COUNT
    jl .s
    RETURN

; experiments on a loaded city before simulating
section .data
up_fmt  db "UPGRADE %s %d: %d..%d (%d tiles)", 10, 0
up_row  db "row", 0
up_col  db "col", 0
up_tot  db "UPGRADE total %d tiles, about $%d", 10, 0
section .bss
up_count resd 1
plan_mark resd 1                    ; 1: only mark the runs, don't build
plan_map resb MAP_TILES
section .text
; upgrade straight street runs of at least edi tiles to avenues
FUNC pt_upgrade_runs, 16
    mov [rbp-48], edi
    mov dword [up_count], 0
    xor r15d, r15d                  ; 0 rows, 1 cols
.dir:
    xor r13d, r13d                  ; line
.line:
    xor r12d, r12d                  ; position
.pos:
    cmp r12d, MAP_W
    jge .ln
    call .tile
    test eax, eax
    jz .pn
    ; run start
    mov r14d, r12d
.run:
    inc r12d
    cmp r12d, MAP_W
    jge .rend
    call .tile
    test eax, eax
    jnz .run
.rend:
    mov eax, r12d
    sub eax, r14d
    cmp eax, [rbp-48]
    jl .pos
    ; upgrade r14..r12-1
    mov [rbp-52], eax
    mov ebx, r14d
.up:
    cmp ebx, r12d
    jge .upd
    mov edi, ebx
    mov esi, r13d
    test r15d, r15d
    jz .u1
    mov edi, r13d
    mov esi, ebx
.u1:
    call tile_at
    cmp dword [plan_mark], 0
    je .ubuild
    sub rax, tiles
    shr eax, TILE_SHIFT
    mov byte [plan_map+rax], 1
    inc dword [up_count]
    jmp .u2
.ubuild:
    cmp byte [rax+T_ROADTYPE], RT_AVENUE
    je .u2
    mov byte [rax+T_ROADTYPE], RT_AVENUE
    inc dword [up_count]
.u2:
    inc ebx
    jmp .up
.upd:
    lea rdi, [up_fmt]
    lea rsi, [up_row]
    test r15d, r15d
    jz .u3
    lea rsi, [up_col]
.u3:
    mov edx, r13d
    mov ecx, r14d
    lea r8d, [r12-1]
    mov r9d, [rbp-52]
    xor eax, eax
    call printf
    jmp .pos
.pn:
    inc r12d
    jmp .pos
.ln:
    inc r13d
    cmp r13d, MAP_W
    jl .line
    inc r15d
    cmp r15d, 2
    jl .dir
    call roads_update_all
    lea rdi, [up_tot]
    mov esi, [up_count]
    imul edx, esi, 25
    xor eax, eax
    call printf
    RETURN
.tile:                              ; street (not highway) at the scan point?
    mov edi, r12d
    mov esi, r13d
    test r15d, r15d
    jz .t1
    mov edi, r13d
    mov esi, r12d
.t1:
    call tile_at
    xor ecx, ecx
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .t2
    test byte [rax+T_FLAGS], F_HIGHWAY
    jnz .t2
    cmp byte [rax+T_ROADTYPE], RT_HIGHWAY
    je .t2
    mov ecx, 1
.t2:
    mov eax, ecx
    ret

; avenue from the end of the north highway down into the town
FUNC pt_north_link
    mov ebx, 18
.l:
    mov edi, 44
    mov esi, ebx
    call tile_at
    cmp byte [rax+T_OBJ], OBJ_ROAD
    je .n
    mov byte [rax+T_OBJ], OBJ_ROAD
    mov byte [rax+T_ROADTYPE], RT_AVENUE
    mov byte [rax+T_ZONE], 0
    mov byte [rax+T_FLAGS], 0
.n:
    inc ebx
    cmp ebx, 48
    jl .l
    call roads_update_all
    mov dword [net_dirty], 1
    RETURN

; --demo 1 out.bmp Z : build, undo, check
section .data
uz_fmt db "UNDO %s money=%d roads=%d zoned=%d services=%d pylons=%d wires=%d acts=%d", 10, 0
uz_a db "start  ", 0
uz_b db "built  ", 0
uz_c db "undo1  ", 0
uz_d db "undo2  ", 0
uz_e db "undo3  ", 0
uz_f db "undo4  ", 0
uz_g db "undo5  ", 0
section .text
FUNC pt_undo_report, 16
    mov [rbp-48], rdi
    xor ebx, ebx
    xor r12d, r12d
    xor r13d, r13d
    xor r14d, r14d
    xor r15d, r15d
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    movzx ecx, byte [tiles+rax+T_OBJ]
    cmp ecx, OBJ_ROAD
    jne .a
    test byte [tiles+rax+T_FLAGS], F_HIGHWAY
    jnz .a
    inc r12d
.a: cmp byte [tiles+rax+T_ZONE], 0
    je .b
    inc r13d
.b: cmp ecx, OBJ_SERVICE
    jne .c
    inc r14d
.c: cmp ecx, OBJ_POWER
    jne .n
    inc r15d
.n: inc ebx
    cmp ebx, MAP_TILES
    jl .l
    lea rdi, [uz_fmt]
    mov rsi, [rbp-48]
    mov rdx, [money]
    mov ecx, r12d
    mov r8d, r13d
    mov r9d, r14d
    mov eax, [n_acts]
    push rax
    mov eax, [n_wires]
    push rax
    push r15
    xor eax, eax
    call pt_printf8
    add rsp, 24
    RETURN

FUNC pt_undo_test
    mov dword [welcome], 0
    lea rdi, [uz_a]
    call pt_undo_report
    mov dword [road_type], RT_STREET
    mov edi, T_ROAD
    mov esi, 26
    mov edx, 64
    mov ecx, 40
    mov r8d, 64
    call pt_drag
    mov dword [zone_type], ZONE_R
    mov edi, T_ZONETOOL
    mov esi, 27
    mov edx, 60
    mov ecx, 35
    mov r8d, 63
    call pt_drag
    mov edi, BK_COAL
    mov esi, 43
    mov edx, 72
    call pt_place
    mov edi, T_POWERLN
    mov esi, 42
    mov edx, 71
    mov ecx, 30
    mov r8d, 66
    call pt_drag
    ; bulldoze part of the road
    mov edi, T_BULLDOZE
    mov esi, 30
    mov edx, 64
    mov ecx, 33
    mov r8d, 64
    call pt_drag
    lea rdi, [uz_b]
    call pt_undo_report
    call undo_do
    lea rdi, [uz_c]
    call pt_undo_report
    call undo_do
    lea rdi, [uz_d]
    call pt_undo_report
    call undo_do
    lea rdi, [uz_e]
    call pt_undo_report
    call undo_do
    lea rdi, [uz_f]
    call pt_undo_report
    call undo_do
    lea rdi, [uz_g]
    call pt_undo_report
    RETURN

; --demo 3 out.bmp m : queue a minimap click and let the real loop run
section .data
ml_fmt db "LOOP minimap click on 100,20 -> view centred on %d,%d", 10, 0
section .text
FUNC pt_minimap_loop_setup
    mov dword [welcome], 0
    mov dword [minimap_on], 1
    mov dword [shake], 40           ; shaking, like after a meteor
    mov edi, 100
    mov esi, 20
    call tile_to_minimap
    push r12
    push r13
    push rax
    push rdx
    call minimap_pos
    pop rdx
    pop rax
    lea eax, [rax+r12+3]
    lea edx, [rdx+r13+3]
    pop r13
    pop r12
    imul eax, [ui_scale]
    mov [mouse_x], eax
    imul edx, [ui_scale]
    mov [mouse_y], edx
    mov dword [click_pending], 1
    mov dword [minimap_age], 0
    RETURN

FUNC pt_minimap_loop_report
    mov edi, [fb_w]
    shr edi, 1
    add edi, [cam_x]
    mov esi, [fb_h]
    shr esi, 1
    add esi, [cam_y]
    call world_to_tile
    lea rdi, [ml_fmt]
    mov esi, eax
    xor eax, eax
    CALLC printf
    RETURN
