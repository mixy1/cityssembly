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
mm_fmt db "MINIMAP click at ui %d,%d: cam %d,%d -> %d,%d", 10, 0
section .text
FUNC pt_minimap_test, 16
    mov dword [welcome], 0
    mov dword [minimap_on], 1
    call render_ui
    mov r12d, [ui_w]
    sub r12d, 136-20
    mov r13d, [ui_h]
    sub r13d, DOCK_BTN+86-20
    mov eax, r12d
    imul eax, [ui_scale]
    mov [mouse_x], eax
    mov eax, r13d
    imul eax, [ui_scale]
    mov [mouse_y], eax
    mov r14d, [cam_x]
    mov r15d, [cam_y]
    mov dword [lmb_down], 0          ; released within the frame
    mov dword [click_pending], 1
    call render_ui
    call world_input
    lea rdi, [mm_fmt]
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    mov r8d, r15d
    mov r9d, [cam_x]
    push qword [cam_y]
    push qword [cam_y]
    xor eax, eax
    call printf
    add rsp, 16
    RETURN
