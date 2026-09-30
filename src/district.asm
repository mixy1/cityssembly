; =====================================================================
;  DISTRICTS (beta) - named parts of the city with their own policies
;
;  Zones > Districts paints areas into one of eight districts (drag a
;  rectangle; "Erase district" takes them out).  While painting, a bar
;  above the dock picks the district and switches its policies:
;
;    High-rise ban   dense zones stop at level 3 here
;    Quiet streets   homes here are happier; industry wants to be here less
;    Free transit    trips from here by bus, tram or metro cost nothing
;                    (more riders, no fares)
;    Tourism zone    shops here do well; homes put up with the crowds
;
;  Each policy costs $1 a building in the district a month.  The
;  districts view shows them in colour, with their names.
; =====================================================================
DS_N        equ 8
DP_HIGHRISE equ 1
DP_QUIET    equ 2
DP_FREE     equ 4
DP_TOURISM  equ 8
OV_DISTRICT equ 24

section .bss
alignb 8
dist_state:                     ; (saved: "DIST")
map_district resb MAP_TILES     ; 0 none, 1..8
dist_pol    resd DS_N+1         ; policies of each district
dist_state_end:
dist_cur    resd 1              ; the district being painted (1..8)
dist_erase  resd 1              ; the tool takes tiles out
dist_bld    resd DS_N+1         ; buildings in each (monthly)
dist_pop    resd DS_N+1
dist_cx     resd DS_N+1         ; where its name goes (a middle)
dist_cy     resd DS_N+1

section .data
ds_names    dq 0, dsn1, dsn2, dsn3, dsn4, dsn5, dsn6, dsn7, dsn8
dsn1        db "Downtown", 0
dsn2        db "Old Town", 0
dsn3        db "Harbour", 0
dsn4        db "Uptown", 0
dsn5        db "Riverside", 0
dsn6        db "Hillside", 0
dsn7        db "Market", 0
dsn8        db "Parkside", 0
ds_tints    db 0, TINT_YELLOW, TINT_ORANGE, TINT_BLUE, TINT_PINK, TINT_CYAN, TINT_BROWN, TINT_RED, TINT_GREEN
ds_pnames   dq dsp0, dsp1, dsp2, dsp3
dsp0        db "High-rise ban", 0
dsp1        db "Quiet streets", 0
dsp2        db "Free transit", 0
dsp3        db "Tourism zone", 0
ds_ptips    dq dst0, dst1, dst2, dst3
dst0        db "Dense zones stop at level 3 in this district", 0
dst1        db "Homes here are happier; industry wants to be here less", 0
dst2        db "Trips from here by bus, tram or metro are free: more riders, no fares", 0
dst3        db "Shops here do well; homes put up with the crowds", 0
ti_dist     db "Districts", 0
ti_undist   db "Erase district", 0
hx_dist     db "Drag to paint a district. Pick", 10
            db "which one, and its policies, in", 10
            db "the bar above the dock.", 0
hx_undist   db "Drag to take tiles out of their", 10
            db "district.", 0
s_ds_bld    db " buildings, ", 0
s_ds_ppl    db " people", 0
s_ds_cost   db "Each policy: $1 a building a month", 0
ov_dist_n   db "Districts", 0
oh_dist     db 1, "each district its colour", 0

section .text

dist_reset:
    push rdi
    push rcx
    lea rdi, [dist_state]
    mov ecx, dist_state_end - dist_state
    xor eax, eax
    rep stosb
    mov dword [dist_cur], 1
    pop rcx
    pop rdi
    ret

; the policies of tile edi's district -> eax (0 none; beta)
dist_pol_of:
    xor eax, eax
    cmp dword [beta_on], 0
    je .o
    movzx ecx, byte [map_district+rdi]
    test ecx, ecx
    jz .o
    mov eax, [dist_pol+rcx*4]
.o: ret

; the district tool on a tile (r12 tile, rbx its tl index) -> eax
; cost or -1
dist_tile_cost:
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    shl esi, MAP_SHIFT
    add esi, edi
    movzx ecx, byte [map_district+rsi]
    xor eax, eax
    cmp dword [dist_erase], 0
    je .p
    test ecx, ecx
    jz .no
    ret
.p:
    cmp ecx, [dist_cur]
    je .no
    cmp byte [r12+T_TERRAIN], TER_WATER
    je .no
    ret
.no:
    mov eax, -1
    ret

; paint a tile (r13d, r14d its x, y)
dist_lay_tile:
    mov eax, r14d
    shl eax, MAP_SHIFT
    add eax, r13d
    xor ecx, ecx
    cmp dword [dist_erase], 0
    jne .e
    mov ecx, [dist_cur]
.e:
    mov [map_district+rax], cl
    ret

; the month: buildings and people in each district, where the names
; go -> eax what the policies cost (beta; with the city's policies)
FUNC dist_month
    cmp dword [beta_on], 0
    je .out
    lea rdi, [dist_bld]
    mov ecx, (DS_N+1)*4
    xor eax, eax
    rep stosd
    ; (dist_bld, dist_pop, dist_cx, dist_cy are consecutive)
    xor ebx, ebx
.l:
    movzx ecx, byte [map_district+rbx]
    test ecx, ecx
    jz .n
    mov eax, ebx
    and eax, MAP_W-1
    add [dist_cx+rcx*4], eax
    mov eax, ebx
    shr eax, MAP_SHIFT
    add [dist_cy+rcx*4], eax
    inc dword [dist_pop+rcx*4]      ; (tiles, for now)
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    ; the middles (sum / tiles)
    mov ebx, 1
.m:
    mov ecx, [dist_pop+rbx*4]
    test ecx, ecx
    jz .mn
    mov eax, [dist_cx+rbx*4]
    xor edx, edx
    div ecx
    mov [dist_cx+rbx*4], eax
    mov eax, [dist_cy+rbx*4]
    xor edx, edx
    div ecx
    mov [dist_cy+rbx*4], eax
.mn:
    mov dword [dist_pop+rbx*4], 0
    inc ebx
    cmp ebx, DS_N
    jle .m
    ; buildings and people
    xor ebx, ebx
.b:
    movzx ecx, byte [map_district+rbx]
    test ecx, ecx
    jz .bn
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ZONEBLD
    jne .bn
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .bn
    inc dword [dist_bld+rcx*4]
    movzx edx, byte [tiles+rax+T_ZONE]
    cmp byte [zone_class+rdx], ZC_RES
    jne .bn
    movzx edx, word [tiles+rax+T_POP]
    add [dist_pop+rcx*4], edx
.bn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .b
    ; the policies' cost
    xor r12d, r12d
    mov ebx, 1
.c:
    mov eax, [dist_pol+rbx*4]
    popcnt eax, eax
    imul eax, [dist_bld+rbx*4]
    add r12d, eax
    inc ebx
    cmp ebx, DS_N
    jle .c
    mov eax, r12d
    RETURN
.out:
    xor eax, eax
    RETURN

; the districts view: each district its colour (rdi tile, esi index)
dist_tint:
    movzx eax, byte [map_district+rsi]
    test eax, eax
    jz .no
    movzx eax, byte [ds_tints+rax]
    ret
.no:
    xor eax, eax
    ret

; the district tool wants the districts view
dist_view_wanted:
    xor eax, eax
    cmp dword [tool], T_DISTRICT
    jne .o
    mov eax, OV_DISTRICT
.o: ret

; the bar above the dock while painting (beta, ui)
FUNC draw_dist_bar, 16
    cmp dword [beta_on], 0
    je .out
    cmp dword [tool], T_DISTRICT
    jne .out
    cmp dword [dist_erase], 0
    jne .out
    ; left of the minimap, above the dock
    mov r13d, [ui_h]
    sub r13d, DOCK_BTN+80
    mov r12d, 8
    mov edi, r12d
    sub edi, 4
    mov esi, r13d
    sub esi, 4
    mov edx, DS_N*56+8
    mov ecx, 60
    call draw_panel
    mov edi, r12d
    sub edi, 4
    mov esi, r13d
    sub esi, 4
    mov edx, DS_N*56+8
    mov ecx, 60
    call ui_over
    ; the districts
    mov ebx, 1
.d:
    lea eax, [rbx-1]
    imul edi, eax, 56
    add edi, r12d
    mov esi, r13d
    mov edx, 54
    mov rcx, [ds_names+rbx*8]
    xor r8d, r8d
    cmp ebx, [dist_cur]
    sete r8b
    call text_button
    test eax, eax
    jz .dn
    mov [dist_cur], ebx
.dn:
    inc ebx
    cmp ebx, DS_N
    jle .d
    ; its policies
    add r13d, 18
    mov r14d, [dist_cur]
    xor ebx, ebx
.p:
    imul edi, ebx, 112
    add edi, r12d
    mov esi, r13d
    mov edx, 108
    mov rcx, [ds_pnames+rbx*8]
    xor r8d, r8d
    bt dword [dist_pol+r14*4], ebx
    setc r8b
    call text_button
    test eax, eax
    jz .pt
    btc dword [dist_pol+r14*4], ebx
.pt:
    imul edi, ebx, 112
    add edi, r12d
    mov esi, r13d
    mov edx, 108
    mov ecx, 14
    call ui_over
    test eax, eax
    jz .pn
    mov rax, [ds_ptips+rbx*8]
    mov [tooltip], rax
.pn:
    inc ebx
    cmp ebx, 4
    jl .p
    ; what's in it, and what the policies cost
    add r13d, 19
    call tb_reset
    movsxd rdi, dword [dist_bld+r14*4]
    call tb_num
    lea rdi, [s_ds_bld]
    call tb_str
    movsxd rdi, dword [dist_pop+r14*4]
    call tb_num
    lea rdi, [s_ds_ppl]
    call tb_str
    lea edi, [r12+2]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call draw_text
    lea edi, [r12+DS_N*56-4]
    mov esi, r13d
    lea rdx, [s_ds_cost]
    mov ecx, UI_DIM
    call draw_text_right
.out:
    RETURN

; the districts' names in the districts view (beta, ui)
FUNC dist_labels
    cmp dword [beta_on], 0
    je .out
    cmp dword [eff_overlay], OV_DISTRICT
    jne .out
    mov ebx, 1
.l:
    mov eax, [dist_cx+rbx*4]
    or eax, [dist_cy+rbx*4]
    jz .n
    mov edi, [dist_cx+rbx*4]
    shl edi, 8
    add edi, 128
    mov esi, [dist_cy+rbx*4]
    shl esi, 8
    add esi, 128
    mov edx, 16*16
    call world_proj
    mov r13d, edx
    imul eax, [zoom]
    cdq
    idiv dword [ui_scale]
    mov r12d, eax
    mov eax, r13d
    imul eax, [zoom]
    cdq
    idiv dword [ui_scale]
    mov esi, eax
    mov edi, r12d
    mov rdx, [ds_names+rbx*8]
    mov ecx, UI_GOLD
    call draw_text_centered
.n:
    inc ebx
    cmp ebx, DS_N
    jle .l
.out:
    RETURN

; is the ride from building r12d free (the policy, or its district)?
; ZF clear if so; keeps every register
free_ride:
    push rax
    push rcx
    test dword [policies], P_FREEBUS
    jnz .y
    movzx ecx, byte [map_district+r12]
    test ecx, ecx
    jz .n
    test dword [dist_pol+rcx*4], DP_FREE
    jnz .y
.n:
    xor ecx, ecx
    test ecx, ecx
    pop rcx
    pop rax
    ret
.y:
    or ecx, 1
    pop rcx
    pop rax
    ret

; how a district changes a building's score (edi tile, esi zone class)
; -> eax (added to it; beta)
dist_score:
    xor eax, eax
    cmp dword [beta_on], 0
    je .o
    movzx ecx, byte [map_district+rdi]
    test ecx, ecx
    jz .o
    mov ecx, [dist_pol+rcx*4]
    cmp esi, ZC_IND
    jne .c
    test ecx, DP_QUIET
    jz .o
    mov eax, -12
    ret
.c:
    cmp esi, ZC_COM
    jne .o
    test ecx, DP_TOURISM
    jz .o
    mov eax, 12
.o: ret

; how a district changes a home's happiness (edi tile) -> eax taken off
dist_unhappy:
    xor eax, eax
    movzx ecx, byte [map_district+rdi]
    test ecx, ecx
    jz .o
    mov ecx, [dist_pol+rcx*4]
    test ecx, DP_QUIET
    jz .t
    sub eax, 6
.t:
    test ecx, DP_TOURISM
    jz .o
    add eax, 4
.o: ret
