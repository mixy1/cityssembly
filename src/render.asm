; =====================================================================
;  RENDER - camera and z-buffered isometric world drawing
;
;  world pixel of tile (tx,ty) back corner:
;     wx = (tx - ty) * 16 + ORIGIN_X        wy = (tx + ty) * 8
;  depth base of a tile = (tx + ty) * 16   (+ sprite-local nearness)
; =====================================================================

ORIGIN_X equ MAP_W*16

section .bss
eff_overlay     resd 1
prob_n          resd 1
prob_x          resd 256
prob_y          resd 256
prob_t          resb 256
mouse_x         resd 1          ; window pixels
mouse_y         resd 1
mouse_wx        resd 1          ; world pixels
mouse_wy        resd 1
hover_tx        resd 1
hover_ty        resd 1
hover_valid     resd 1
cam_vx          resd 1
cam_vy          resd 1
anim_tick       resd 1
shake           resd 1
overlay_mode    resd 1          ; 0 none, else OV_*
draw_sx         resd 1
draw_sy         resd 1

section .text

; screen position of a tile back corner: (edi tx, esi ty) -> eax sx, edx sy
tile_screen:
    mov eax, edi
    sub eax, esi
    shl eax, 4
    add eax, ORIGIN_X
    sub eax, [cam_x]
    lea edx, [rdi+rsi]
    shl edx, 3
    sub edx, [cam_y]
    ret

; world pixel -> tile: (edi wx, esi wy) -> eax tx, edx ty (may be off-map)
world_to_tile:
    sub edi, ORIGIN_X               ; a
    shl esi, 1                      ; 2wy
    lea eax, [rsi+rdi]
    sar eax, 5
    mov edx, esi
    sub edx, edi
    sar edx, 5
    ret

; ---------------------------------------------------------------------
;  update mouse world position + hovered tile
; ---------------------------------------------------------------------
update_hover:
    mov eax, [mouse_x]
    xor edx, edx
    div dword [zoom]
    add eax, [cam_x]
    mov [mouse_wx], eax
    mov eax, [mouse_y]
    xor edx, edx
    div dword [zoom]
    add eax, [cam_y]
    mov [mouse_wy], eax
    mov edi, [mouse_wx]
    mov esi, [mouse_wy]
    call world_to_tile
    mov [hover_tx], eax
    mov [hover_ty], edx
    xor ecx, ecx
    cmp eax, MAP_W
    jae .n
    cmp edx, MAP_W
    jae .n
    mov ecx, 1
.n:
    mov [hover_valid], ecx
    ret

; ---------------------------------------------------------------------
;  camera: keyboard scroll with easing, clamped to the map
; ---------------------------------------------------------------------
FUNC camera_update
    xor edi, edi
    CALLC SDL_GetKeyboardState
    mov rbx, rax
    ; target velocity
    mov ecx, 14
    xor edx, edx
    mov eax, ecx
    div dword [zoom]
    add eax, 3
    mov r12d, eax                   ; speed
    cmp byte [rbx+SC_LSHIFT], 0
    je .ns
    shl r12d, 1
.ns:
    xor r13d, r13d                  ; tvx
    xor r14d, r14d                  ; tvy
    cmp dword [text_input_active], 0
    jne .keysdone
    mov al, [rbx+SC_A]
    or al, [rbx+SC_LEFT]
    jz .nl
    sub r13d, r12d
.nl:
    mov al, [rbx+SC_D]
    or al, [rbx+SC_RIGHT]
    jz .nr
    add r13d, r12d
.nr:
    mov al, [rbx+SC_W]
    or al, [rbx+SC_UP]
    jz .nu
    sub r14d, r12d
.nu:
    mov al, [rbx+SC_S]
    or al, [rbx+SC_DOWN]
    jz .nd
    add r14d, r12d
.nd:
.keysdone:
    ; ease velocity toward target (1/4 per tick), in 1/16 px
    shl r13d, 4
    shl r14d, 4
    mov eax, r13d
    sub eax, [cam_vx]
    sar eax, 2
    add [cam_vx], eax
    mov eax, r14d
    sub eax, [cam_vy]
    sar eax, 2
    add [cam_vy], eax
    mov eax, [cam_vx]
    sar eax, 4
    add [cam_x], eax
    mov eax, [cam_vy]
    sar eax, 4
    add [cam_y], eax
    call camera_clamp
    RETURN

camera_clamp:
    ; x in [-fb_w/2, MAP_W*32 - fb_w/2]
    mov eax, [fb_w]
    shr eax, 1
    neg eax
    cmp [cam_x], eax
    jge .x1
    mov [cam_x], eax
.x1:
    mov eax, [fb_w]
    shr eax, 1
    mov ecx, MAP_W*32
    sub ecx, eax
    cmp [cam_x], ecx
    jle .x2
    mov [cam_x], ecx
.x2:
    mov eax, [fb_h]
    shr eax, 1
    neg eax
    sub eax, 60
    cmp [cam_y], eax
    jge .y1
    mov [cam_y], eax
.y1:
    mov eax, [fb_h]
    shr eax, 1
    mov ecx, MAP_W*16
    sub ecx, eax
    cmp [cam_y], ecx
    jle .y2
    mov [cam_y], ecx
.y2:
    ret

; centre camera on tile (edi tx, esi ty)
camera_center_tile:
    mov eax, edi
    sub eax, esi
    shl eax, 4
    add eax, ORIGIN_X
    mov ecx, [fb_w]
    shr ecx, 1
    sub eax, ecx
    mov [cam_x], eax
    lea eax, [rdi+rsi]
    shl eax, 3
    mov ecx, [fb_h]
    shr ecx, 1
    sub eax, ecx
    mov [cam_y], eax
    ret

; ---------------------------------------------------------------------
;  water shore mask for tile (edi x, esi y): bit set = land neighbour
; ---------------------------------------------------------------------
FUNC water_mask
    mov r12d, edi
    mov r13d, esi
    xor ebx, ebx
    xor r14d, r14d
.d:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+r14*4]
    add esi, [dir_dy+r14*4]
    call tile_at
    test rax, rax
    jz .n
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .n
    cmp byte [rax+T_OBJ], OBJ_ROAD
    je .n                           ; bridges keep the water open
    bts ebx, r14d
.n:
    inc r14d
    cmp r14d, 4
    jl .d
    mov eax, ebx
    RETURN

section .data
grass_pick db 0,0,1,1,0,1,2,3
section .text

; ---------------------------------------------------------------------
;  ground_sprite(rdi tile ptr, esi x, edx y) -> eax sprite id
; ---------------------------------------------------------------------
FUNC ground_sprite
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_ROAD
    jne .nr
    movzx eax, byte [rbx+T_ROADTYPE]
    CLAMP eax, 0, 2
    shl eax, 4
    movzx ecx, byte [rbx+T_SUB]
    add eax, ecx
    mov eax, [spr_road+rax*4]
    RETURN
.nr:
    cmp eax, OBJ_RUBBLE
    jne .nrub
    mov eax, [spr_rubble]
    RETURN
.nrub:
    cmp eax, OBJ_ZONEBLD
    jne .nzb
    test byte [rbx+T_FLAGS], F_BUILD
    jz .grass
    mov eax, [spr_dirt]
    RETURN
.nzb:
    cmp eax, OBJ_NONE
    jne .terrain
    movzx eax, byte [rbx+T_ZONE]
    test eax, eax
    jz .terrain
    mov eax, [spr_lot+rax*4]
    RETURN
.terrain:
    movzx eax, byte [rbx+T_TERRAIN]
    cmp eax, TER_WATER
    jne .nw
    mov edi, r12d
    mov esi, r13d
    call water_mask
    mov eax, [spr_water+rax*4]
    RETURN
.nw:
    cmp eax, TER_SAND
    jne .grass
    movzx eax, byte [rbx+T_VARIANT]
    and eax, 1
    mov eax, [spr_sand+rax*4]
    RETURN
.grass:
    movzx eax, byte [rbx+T_VARIANT]
    and eax, 7
    movzx eax, byte [grass_pick+rax]
    mov eax, [spr_grass+rax*4]
    RETURN

; ---------------------------------------------------------------------
;  render_world
; ---------------------------------------------------------------------
FUNC render_world, 32
    call compute_eff_overlay
    mov dword [prob_n], 0
    call set_target_world
    mov edi, RAMP(R_DEEPWATER, 1)
    call clear_target
    ; clear z-buffer
    lea rdi, [zbuf]
    mov ecx, [fb_w]
    imul ecx, [fb_h]
    shr ecx, 1
    inc ecx
    xor eax, eax
    rep stosd

    ; visible tile range: iterate diagonally-bounded rectangle
    xor r13d, r13d                  ; ty
.ty:
    xor r12d, r12d                  ; tx
.tx:
    mov edi, r12d
    mov esi, r13d
    call tile_screen
    ; horizontal cull (buildings are at most 3 tiles wide)
    cmp eax, -56
    jl .next
    mov ecx, [fb_w]
    add ecx, 56
    cmp eax, ecx
    jg .next
    cmp edx, -56
    jl .next
    mov ecx, [fb_h]
    add ecx, 200
    cmp edx, ecx
    jg .next
    mov [draw_sx], eax
    mov [draw_sy], edx
    mov edi, r12d
    mov esi, r13d
    call tile_at
    mov rbx, rax
    lea r14d, [r12+r13]
    shl r14d, 4                     ; depth base
    ; ground (only if the tile's own diamond is on screen)
    mov edx, [draw_sy]
    cmp edx, [fb_h]
    jg .objs
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    call ground_sprite
    mov edi, eax
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    mov ecx, r14d
    xor r8d, r8d
    cmp dword [eff_overlay], 0
    je .gblit
    push rax
    push rax
    mov rdi, rbx
    call overlay_remap
    mov r8, rax
    pop rax
    pop rax
    mov edi, eax
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    mov ecx, r14d
.gblit:
    call blit_sprite
.objs:
    cmp dword [emit_now], 0
    je .noemit
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    call emit_tile
.noemit:
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_TREE
    je .tree
    cmp eax, OBJ_POWER
    je .power
    cmp eax, OBJ_ZONEBLD
    je .zbld
    cmp eax, OBJ_SERVICE
    je .svc
    cmp eax, OBJ_ROAD
    je .road
    jmp .next
.road:
    test byte [rbx+T_FLAGS2], F2_BUSSTOP
    jz .next
    mov edi, [spr_busstop]
    jmp .blitobj
.tree:
    movzx eax, byte [rbx+T_SUB]
    movzx ecx, byte [rbx+T_VARIANT]
    shr ecx, 3
    and ecx, 1
    lea eax, [rax*2+rcx]
    and eax, 7
    mov edi, [spr_tree+rax*4]
    jmp .blitobj
.power:
    movzx eax, byte [rbx+T_SUB]
    mov edi, [spr_power+rax*4]
    jmp .blitobj
.zbld:
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .next
    test byte [rbx+T_FLAGS], F_BUILD
    jz .grown
    mov edi, [spr_construct2]
    cmp byte [rbx+T_SIZE], 2
    je .blitobj
    movzx eax, byte [rbx+T_TIMER]
    shr eax, 5
    CLAMP eax, 0, 2
    mov edi, [spr_construct+rax*4]
    jmp .blitobj
.grown:
    movzx edi, byte [rbx+T_ZONE]
    movzx esi, byte [rbx+T_LEVEL]
    CLAMP esi, 1, 5
    movzx edx, byte [rbx+T_VARIANT]
    movzx ecx, byte [rbx+T_SIZE]
    xor r8d, r8d
    cmp edi, ZONE_I
    jne .gz
    movzx r8d, byte [rbx+T_SUB]
.gz:
    call zone_sprite
    mov edi, eax
    mov [rbp-48], eax
    mov rsi, rbx
    call building_remap
    mov r8, rax
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    mov ecx, r14d
    mov edi, [rbp-48]
    call blit_sprite
    mov edi, [rbp-48]
    call note_problem
    jmp .fires
.svc:
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .next
    movzx eax, byte [rbx+T_SUB]
    mov edi, [spr_bld+rax*4]
    mov [rbp-48], edi
    push rax
    push rax
    mov rsi, rbx
    call building_remap
    mov r8, rax
    pop rax
    pop rax
    mov edi, [rbp-48]
.svc2:
    mov r15d, eax
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    mov ecx, r14d
    call blit_sprite
    cmp r15d, BK_WIND
    jne .fires
    ; spinning rotor (unpowered world still spins: wind!)
    mov eax, [anim_tick]
    shr eax, 2
    and eax, 3
    mov edi, [spr_rotor+rax*4]
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    mov ecx, r14d
    xor r8d, r8d
    call blit_sprite
    jmp .fires
.blitobj:
    xor r8d, r8d
.blit2:
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    mov ecx, r14d
    call blit_sprite
.fires:
    test byte [rbx+T_FLAGS], F_FIRE
    jz .next
    mov eax, [anim_tick]
    add eax, r12d
    shr eax, 3
    and eax, 1
    mov edi, [spr_flame+rax*4]
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    lea ecx, [r14+4]
    xor r8d, r8d
    call blit_sprite
.next:
    inc r12d
    cmp r12d, MAP_W
    jl .tx
    inc r13d
    cmp r13d, MAP_W
    jl .ty
    cmp dword [eff_overlay], OV_WATER
    jne .np
    call draw_pipes
.np:
    RETURN

; ---------------------------------------------------------------------
;  building_remap(rsi tile) -> rax colour table for info views
; ---------------------------------------------------------------------
building_remap:
    xor eax, eax
    test byte [rsi+T_FLAGS], F_FIRE
    jz .a
    lea rax, [remap_fire]
    ret
.a: test byte [rsi+T_FLAGS], F_ABANDON
    jz .b
    lea rax, [remap_dark]
    ret
.b: mov ecx, [eff_overlay]
    cmp ecx, OV_POWER
    jne .c
    test byte [rsi+T_FLAGS], F_POWER
    jnz .ok
    lea rax, [remap_red]
    ret
.c: cmp ecx, OV_WATER
    jne .ok
    cmp byte [rsi+T_OBJ], OBJ_ZONEBLD
    jne .ok
    test byte [rsi+T_FLAGS], F_WATER
    jnz .ok
    lea rax, [remap_red]
    ret
.ok:
    ret

; ---------------------------------------------------------------------
;  note_problem(edi sprite): remember an icon above this building
; ---------------------------------------------------------------------
note_problem:
    movzx eax, byte [rbx+T_PROBLEM]
    test eax, eax
    jz .o
    mov ecx, [prob_n]
    cmp ecx, 256
    jge .o
    mov [prob_t+rcx], al
    mov eax, [draw_sx]
    mov [prob_x+rcx*4], eax
    shl edi, 4
    movsx eax, word [spr_table+rdi+6]
    mov edx, [draw_sy]
    sub edx, eax
    sub edx, 4
    mov [prob_y+rcx*4], edx
    inc dword [prob_n]
.o: ret

; ---------------------------------------------------------------------
;  draw_pipes: the water / sewage network, shown in the water view
; ---------------------------------------------------------------------
FUNC draw_pipes, 32
    xor r13d, r13d
.ty:
    xor r12d, r12d
.tx:
    mov edi, r12d
    mov esi, r13d
    call tile_at
    mov rbx, rax
    mov rdi, rbx
    call is_pipe_node
    test eax, eax
    jz .next
    mov edi, r12d
    mov esi, r13d
    call tile_screen
    cmp eax, -20
    jl .next
    mov ecx, [fb_w]
    add ecx, 20
    cmp eax, ecx
    jg .next
    cmp edx, -20
    jl .next
    mov ecx, [fb_h]
    add ecx, 20
    cmp edx, ecx
    jg .next
    mov [rbp-48], eax               ; top x
    add edx, 8
    mov [rbp-52], edx               ; centre y
    xor r14d, r14d
.d:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+r14*4]
    add esi, [dir_dy+r14*4]
    call tile_at
    test rax, rax
    jz .dn
    mov rdi, rax
    call is_pipe_node
    test eax, eax
    jz .dn
    ; segment from the centre to the shared edge
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, [pipe_ex+r14*4]
    add edx, edi
    mov ecx, [pipe_ey+r14*4]
    add ecx, esi
    call pipe_line
.dn:
    inc r14d
    cmp r14d, 4
    jl .d
    ; junction dot
    mov edi, [rbp-48]
    dec edi
    mov esi, [rbp-52]
    dec esi
    mov edx, 3
    mov ecx, 2
    mov r8d, RAMP(R_GLASS, 7)
    call fill_rect
.next:
    inc r12d
    cmp r12d, MAP_W
    jl .tx
    inc r13d
    cmp r13d, MAP_W
    jl .ty
    RETURN

section .data
pipe_ex dd 8, 8, -8, -8
pipe_ey dd -4, 4, 4, -4
section .text

; thick pipe line (edi x0, esi y0, edx x1, ecx y1): 2:1 isometric steps
FUNC pipe_line
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    ; steps along x (always 8 px, with y changing by 4)
    xor ebx, ebx
.l:
    cmp ebx, 8
    jg .o
    mov eax, r14d
    sub eax, r12d
    imul eax, ebx
    sar eax, 3
    lea edi, [r12+rax]
    mov eax, r15d
    sub eax, r13d
    imul eax, ebx
    sar eax, 3
    lea esi, [r13+rax]
    push rdi
    push rsi
    dec edi
    mov edx, 3
    mov ecx, 2
    mov r8d, RAMP(R_DEEPWATER, 1)
    call fill_rect
    pop rsi
    pop rdi
    mov edx, 2
    mov ecx, 1
    mov r8d, RAMP(R_GLASS, 7)
    call fill_rect
    inc ebx
    jmp .l
.o:
    RETURN

; ---------------------------------------------------------------------
;  diamond outline for an n x n footprint at tile (edi tx, esi ty)
;  edx = n, ecx = colour. Drawn on top of everything (no depth).
; ---------------------------------------------------------------------
FUNC draw_diamond, 16
    mov r15d, ecx                   ; colour
    mov [rbp-48], edx               ; n
    call tile_screen
    mov r12d, eax                   ; top x
    mov r13d, edx                   ; top y
    mov eax, [rbp-48]
    shl eax, 4
    mov r14d, eax                   ; 16n = half width
    xor ebx, ebx
.l:
    cmp ebx, r14d
    jge .d
    mov eax, ebx
    shr eax, 1
    mov [rbp-52], eax               ; dy
    ; top -> right
    lea edi, [r12+rbx]
    lea esi, [r13+rax]
    mov edx, r15d
    call put_pixel
    ; top -> left
    mov edi, r12d
    sub edi, ebx
    dec edi
    mov esi, r13d
    add esi, [rbp-52]
    mov edx, r15d
    call put_pixel
    ; bottom -> right   (bottom vertex at r13 + 16n)
    lea edi, [r12+rbx]
    mov esi, r13d
    add esi, r14d
    sub esi, [rbp-52]
    dec esi
    mov edx, r15d
    call put_pixel
    ; bottom -> left
    mov edi, r12d
    sub edi, ebx
    dec edi
    mov esi, r13d
    add esi, r14d
    sub esi, [rbp-52]
    dec esi
    mov edx, r15d
    call put_pixel
    inc ebx
    jmp .l
.d:
    RETURN

; overlay_remap(rdi tile) -> rax remap table for the ground
FUNC overlay_remap
    mov rbx, rdi
    mov r12, rdi
    sub r12, tiles
    shr r12, TILE_SHIFT             ; map index
    mov eax, [eff_overlay]
    cmp eax, OV_POWER
    jne .w
    test byte [rbx+T_FLAGS], F_POWER
    jnz .g6
    mov rdi, rbx
    call power_conductive
    test eax, eax
    jz .ident
    mov eax, 14
    jmp .tab
.g6:
    mov eax, 6
    jmp .tab
.w:
    cmp eax, OV_WATER
    jne .tr
    cmp byte [rbx+T_TERRAIN], TER_WATER
    jne .wl
    ; water pollution on rivers and lakes
    movzx eax, byte [map_wpol+r12]
    test eax, eax
    jz .wc
    shr eax, 4
    add eax, 8
    CLAMP eax, 8, 15
    jmp .tab
.wc:
    mov eax, 2
    jmp .tab
.wl:
    test byte [rbx+T_FLAGS], F_WATER
    jz .ident
    mov eax, 3
    test byte [rbx+T_FLAGS2], F2_DIRTY
    jz .tab
    mov eax, 11
    jmp .tab
.tr:
    cmp eax, OV_TRAFFIC
    jne .m2
    cmp byte [rbx+T_OBJ], OBJ_ROAD
    jne .ident
    ; green = flowing, yellow = busy, red = jammed
    movzx eax, byte [rbx+T_JAM]
    shl eax, 1
    movzx ecx, byte [rbx+T_TRAFFIC]
    shr ecx, 2
    add eax, ecx
    CLAMP eax, 0, 255
    imul eax, 10
    shr eax, 8
    add eax, 5
    jmp .tab
.m2:
    cmp eax, OV_HAPPY
    jne .m3
    cmp byte [rbx+T_ZONE], 0
    je .ident
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .ident
    movzx eax, byte [rbx+T_HAPPY]
    imul eax, 5
    shr eax, 1
    jmp .goodv
.m3:
    cmp eax, OV_GARBAGE
    jne .m4
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .gcov
    movzx eax, byte [rbx+T_GARBAGE]
    jmp .bad
.gcov:
    movzx eax, byte [map_garb+r12]
    test eax, eax
    jz .ident
    jmp .goodv
.m4:
    cmp eax, OV_RESOURCE
    jne .m5
    movzx eax, byte [rbx+T_RES]
    test eax, eax
    jz .ident
    movzx eax, byte [res_heat+rax]
    jmp .tab
.m5:
    cmp eax, OV_EDU
    jne .m6
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .ecov
    movzx eax, byte [rbx+T_ZONE]
    cmp byte [zone_class+rax], ZC_RES
    jne .ecov
    movzx eax, byte [rbx+T_EDU]
    jmp .goodv
.ecov:
    movzx eax, byte [map_elem+r12]
    movzx ecx, byte [map_high+r12]
    add eax, ecx
    movzx ecx, byte [map_uni+r12]
    add eax, ecx
    shr eax, 1
    test eax, eax
    jz .ident
    jmp .goodv
.m6:
    cmp eax, OV_DESIRE_R
    jb .m7
    ; zone desirability preview
    cmp byte [rbx+T_TERRAIN], TER_WATER
    je .ident
    mov edi, eax
    sub edi, OV_DESIRE_R
    mov esi, r12d
    call desirability_at
    jmp .goodv
.m7:
    mov rcx, [ov_maps+rax*8]
    test rcx, rcx
    jz .ident
    movzx edx, byte [ov_good+rax]
    movzx eax, byte [rcx+r12]
    test edx, edx
    jnz .goodv
.bad:
    CLAMP eax, 0, 255
    shr eax, 4
    jmp .tab
.goodv:
    CLAMP eax, 0, 255
    shr eax, 4
    mov ecx, 13
    sub ecx, eax
    CLAMP ecx, 1, 15
    mov eax, ecx
.tab:
    shl eax, 8
    lea rax, [remap_heat+rax]
    RETURN
.ident:
    lea rax, [remap_dark]
    RETURN

; quick desirability for a zone class (edi class, esi map index) -> eax
desirability_at:
    movzx eax, byte [map_lv+rsi]
    cmp edi, ZC_IND
    jne .n1
    shr eax, 1
    add eax, 60
    movzx ecx, byte [map_crime+rsi]
    shr ecx, 2
    sub eax, ecx
    jmp .o
.n1:
    movzx ecx, byte [map_pol+rsi]
    sub eax, ecx
    cmp edi, ZC_RES
    jne .n2
    movzx ecx, byte [map_noise+rsi]
    shr ecx, 1
    sub eax, ecx
    movzx ecx, byte [map_park+rsi]
    shr ecx, 2
    add eax, ecx
    jmp .o
.n2:
    movzx ecx, byte [map_noise+rsi]
    shr ecx, 2
    add eax, ecx
.o: CLAMP eax, 0, 255
    ret

section .data
align 8
ov_maps dq 0, 0, 0, map_pol, map_noise, map_crime, map_lv, 0, map_police, map_fire, map_health, 0, 0, map_transit, 0, 0
ov_good db 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1
res_heat db 0, 6, 4, 10
section .text
