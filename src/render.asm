; =====================================================================
;  RENDER - camera and z-buffered isometric world drawing
;
;  world pixel of tile (tx,ty) back corner:
;     wx = (tx - ty) * 16 + ORIGIN_X        wy = (tx + ty) * 8
;  depth base of a tile = (tx + ty) * 16   (+ sprite-local nearness)
; =====================================================================

ORIGIN_X equ MAP_W*16

section .bss
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
    movzx eax, byte [rbx+T_SUB]
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
    cmp dword [overlay_mode], 0
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
    jmp .next
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
    test byte [rbx+T_FLAGS], F_BUILD
    jz .grown
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
    call zone_sprite
    mov edi, eax
    xor r8d, r8d
    test byte [rbx+T_FLAGS], F_ABANDON
    jz .nab
    lea r8, [remap_dark]
.nab:
    test byte [rbx+T_FLAGS], F_FIRE
    jz .blit2
    lea r8, [remap_fire]
    jmp .blit2
.svc:
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .next
    movzx eax, byte [rbx+T_SUB]
    mov edi, [spr_bld+rax*4]
    xor r8d, r8d
    test byte [rbx+T_FLAGS], F_FIRE
    jz .svc2
    lea r8, [remap_fire]
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

; overlay_remap(rdi tile) -> rax remap table (heat colour tint)
FUNC overlay_remap
    mov rbx, rdi
    mov r12, rdi
    sub r12, tiles
    shr r12, TILE_SHIFT             ; map index
    mov eax, [overlay_mode]
    cmp eax, OV_POWER
    jne .w
    mov edi, F_POWER
    mov r13d, 6
    mov r14d, 14
    jmp .util
.w:
    cmp eax, OV_WATER
    jne .maps
    mov edi, F_WATER
    mov r13d, 2
    mov r14d, 13
.util:
    test [rbx+T_FLAGS], dil
    jnz .good
    ; only mark things that want the utility
    push rdi
    push rdi
    mov rdi, rbx
    xor esi, esi
    call conductive
    pop rdi
    pop rdi
    test eax, eax
    jz .ident
    mov eax, r14d
    jmp .tab
.good:
    mov eax, r13d
    jmp .tab
.maps:
    cmp eax, OV_TRAFFIC
    jne .m2
    cmp byte [rbx+T_OBJ], OBJ_ROAD
    jne .ident
    movzx eax, byte [rbx+T_TRAFFIC]
    jmp .bad
.m2:
    cmp eax, OV_HAPPY
    jne .m3
    cmp byte [rbx+T_ZONE], ZONE_R
    jne .ident
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .ident
    movzx eax, byte [rbx+T_HAPPY]
    imul eax, 5
    shr eax, 1
    jmp .goodv
.m3:
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

section .data
align 8
ov_maps dq 0, 0, 0, map_pol, map_crime, map_lv, 0, map_police, map_fire, map_health, map_edu, 0
ov_good db 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1
section .text
