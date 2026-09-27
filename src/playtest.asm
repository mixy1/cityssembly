; =====================================================================
;  scripted new-player session (--demo 1 file.bmp T): builds a small
;  town with the player's tools only, runs it and prints a report
; =====================================================================
section .data
pt_fmt1 db "PLAYTEST pump=%d,%d outlet=%d,%d wires=%d", 10, 0
pt_fmt2 db "PLAYTEST day %d pop=%d bld=%d powered=%d water=%d sewage=%d", 10, 0
pt_fmt3 db "PLAYTEST problems:", 0
pt_fmt4 db " %d", 0
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
    RETURN

FUNC playtest_build
    mov dword [welcome], 0
    mov r12d, [hwy_row]
    ; road off the highway, and a cross street
    mov dword [road_type], RT_STREET
    mov edi, T_ROAD
    mov esi, 22
    mov edx, r12d
    mov ecx, 40
    mov r8d, r12d
    call pt_drag
    mov edi, T_ROAD
    mov esi, 30
    lea edx, [r12-6]
    mov ecx, 30
    lea r8d, [r12+6]
    call pt_drag
    ; zones
    mov dword [zone_type], ZONE_R
    mov edi, T_ZONETOOL
    mov esi, 23
    lea edx, [r12-4]
    mov ecx, 29
    lea r8d, [r12-1]
    call pt_drag
    mov edi, T_ZONETOOL
    mov esi, 31
    lea edx, [r12+1]
    mov ecx, 38
    lea r8d, [r12+4]
    call pt_drag
    mov dword [zone_type], ZONE_C
    mov edi, T_ZONETOOL
    mov esi, 31
    lea edx, [r12-3]
    mov ecx, 38
    lea r8d, [r12-1]
    call pt_drag
    mov dword [zone_type], ZONE_I
    mov edi, T_ZONETOOL
    mov esi, 23
    lea edx, [r12+1]
    mov ecx, 29
    lea r8d, [r12+4]
    call pt_drag
    ; coal plant out of town, power line into town
    mov edi, BK_COAL
    mov esi, 47
    lea edx, [r12+9]
    call pt_place
    mov edi, T_POWERLN
    mov esi, 46
    lea edx, [r12+8]
    mov ecx, 39
    lea r8d, [r12+2]
    call pt_drag
    ; pump on the nearest shore, pipes to the crossroads
    mov dword [pt_px], -1000
    mov dword [pt_py], -1000
    mov edi, 30
    mov esi, r12d
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
    mov ecx, 30
    mov r8d, r12d
    call pt_drag
    mov edi, T_PIPE
    mov esi, 22
    mov edx, r12d
    mov ecx, 40
    mov r8d, r12d
    call pt_drag
    mov edi, T_PIPE
    mov esi, 30
    lea edx, [r12-6]
    mov ecx, 30
    lea r8d, [r12+6]
    call pt_drag
    mov edi, T_POWERLN
    mov esi, 39
    lea edx, [r12+2]
    mov ecx, [pt_px]
    mov r8d, [pt_py]
    call pt_drag
    ; sewage outlet well away from the pump
    mov edi, 30
    mov esi, r12d
    mov edx, 12
    call pt_shore
    mov [pt_ox], eax
    mov [pt_oy], edx
    mov edi, BK_SEWAGE
    mov esi, eax
    call pt_place
    mov edi, T_PIPE
    mov esi, [pt_ox]
    mov edx, [pt_oy]
    mov ecx, 30
    mov r8d, r12d
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
    ; play a few months
    mov r13d, 6
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
    dec r13d
    jnz .m
    mov dword [sim_speed], 1
    mov rax, [money]
    mov [money_shown], rax
    mov edi, 34
    mov esi, r12d
    call camera_center_tile
    RETURN
