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
prob_tile       resd 256
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
wire_col        resd 1
wire_front      resd 1
pipe_col        resd 1
pipe_col2       resd 1

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
    ; edge scrolling (optional)
    cmp dword [set_edge], 0
    je .keysdone
    cmp dword [mouse_inside], 0
    je .keysdone
    cmp dword [rmb_down], 0
    jne .keysdone
    cmp dword [mouse_x], 6
    jge .e1
    sub r13d, r12d
.e1:
    mov eax, [win_w]
    sub eax, 7
    cmp [mouse_x], eax
    jle .e2
    add r13d, r12d
.e2:
    cmp dword [mouse_y], 6
    jge .e3
    sub r14d, r12d
.e3:
    mov eax, [win_h]
    sub eax, 7
    cmp [mouse_y], eax
    jle .keysdone
    add r14d, r12d
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
    ; sar rounds toward -infinity, so a small leftover velocity never
    ; decays to zero (the camera crept left / up after letting go):
    ; snap it to rest once the keys are up and it's nearly stopped
    test r13d, r13d
    jnz .vx
    mov eax, [cam_vx]
    add eax, 15
    cmp eax, 30
    ja .vx
    mov dword [cam_vx], 0
.vx:
    test r14d, r14d
    jnz .vy
    mov eax, [cam_vy]
    add eax, 15
    cmp eax, 30
    ja .vy
    mov dword [cam_vy], 0
.vy:
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
    lea rdi, [tintbuf]
    mov ecx, [fb_w]
    imul ecx, [fb_h]
    xor eax, eax
    rep stosb
    mov dword [blit_tint], 0
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
    ; land you don't own is drawn darker
    mov qword [rbp-56], 0
    cmp dword [sandbox], 0
    jne .owned
    mov edi, r12d
    mov esi, r13d
    call tile_owned
    test eax, eax
    jnz .owned
    lea rax, [remap_dim]
    mov [rbp-56], rax
.owned:
    mov dword [blit_tint], 0
    cmp dword [eff_overlay], 0
    je .notint
    mov rdi, rbx
    call overlay_tint
    mov [blit_tint], eax
    ; test modes can paint a plan over the map
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    movzx eax, byte [plan_map+rax]
    test eax, eax
    jz .notint
    mov dword [blit_tint], TINT_CYAN
    cmp eax, 1
    je .notint
    mov dword [blit_tint], TINT_PINK
.notint:
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
    mov r8, [rbp-56]
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
    push rdi
    push rdi
    mov esi, r12d
    mov edx, r13d
    call xray_set
    pop rdi
    pop rdi
    mov r8, [rbp-56]
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    mov ecx, r14d
    call blit_sprite
    mov dword [blit_dither], 0
    jmp .fires
.power:
    mov edi, [spr_pylon]
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
    movzx r8d, byte [rbx+T_SUB]     ; industry kind / home style
    call zone_sprite
    mov edi, eax
    mov [rbp-48], eax
    mov esi, r12d
    mov edx, r13d
    call xray_set
    mov rsi, rbx
    call building_remap
    mov r8, rax
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    mov ecx, r14d
    mov edi, [rbp-48]
    call blit_sprite
    mov dword [blit_dither], 0
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
    push rdi
    push rdi
    mov esi, r12d
    mov edx, r13d
    call xray_set
    pop rdi
    pop rdi
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    mov ecx, r14d
    call blit_sprite
    mov dword [blit_dither], 0
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
    mov r8, [rbp-56]
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
    mov dword [blit_tint], TINT_KEEP
    call draw_wires
    cmp dword [eff_overlay], OV_WATER
    jne .np
    call draw_pipes
.np:
    RETURN

; ---------------------------------------------------------------------
;  draw_wires: sagging cables between pylons (and into buildings)
; ---------------------------------------------------------------------
; wire_anchor(edi tile index, esi side -1/+1) -> eax sx, edx sy, ecx depth
wire_anchor:
    push rbx
    mov ebx, esi
    mov eax, edi
    shl eax, TILE_SHIFT
    movzx r8d, byte [tiles+rax+T_OBJ]
    mov esi, edi
    shr esi, MAP_SHIFT
    and edi, MAP_W-1
    lea ecx, [rdi+rsi]
    shl ecx, 4
    add ecx, 20                     ; in front of the tile's middle
    push rcx
    call tile_screen
    pop rcx
    add edx, 8                      ; tile centre
    cmp r8d, OBJ_ZONEBLD
    je .bld
    cmp r8d, OBJ_SERVICE
    je .bld
    imul ebx, 9
    add eax, ebx
    sub edx, 25
    pop rbx
    ret
.bld:
    imul ebx, 2
    add eax, ebx
    sub edx, 12
    pop rbx
    ret

FUNC draw_wires
    mov dword [wire_front], 0
    mov dword [wire_col], RAMP(R_ASPHALT, 0)
    cmp dword [eff_overlay], OV_POWER
    jne .c
    mov dword [wire_col], RAMP(R_YELLOW, 7)
.c:
    xor ebx, ebx
.w:
    cmp ebx, [n_wires]
    jge .out
    movzx edi, word [wire_a+rbx*2]
    movzx esi, word [wire_b+rbx*2]
    call draw_wire
    inc ebx
    jmp .w
.out:
    RETURN

; draw_wire(edi tile a, esi tile b) in [wire_col]; [wire_front] = on top
FUNC draw_wire, 64
    mov [rbp-96], edi
    mov [rbp-100], esi
    mov dword [rbp-92], -1          ; side
.side:
    mov edi, [rbp-96]
    mov esi, [rbp-92]
    call wire_anchor
    mov [rbp-48], eax
    mov [rbp-52], edx
    mov [rbp-56], ecx
    mov edi, [rbp-100]
    mov esi, [rbp-92]
    call wire_anchor
    mov [rbp-60], eax
    mov [rbp-64], edx
    mov [rbp-68], ecx
    ; cull: both ends far off screen
    mov eax, [rbp-48]
    cmp eax, [rbp-60]
    jle .c1
    xchg eax, [rbp-60]
    mov [rbp-48], eax
    mov eax, [rbp-52]
    xchg eax, [rbp-64]
    mov [rbp-52], eax
    mov eax, [rbp-56]
    xchg eax, [rbp-68]
    mov [rbp-56], eax
.c1:
    mov eax, [rbp-60]
    cmp eax, -8
    jl .sn
    mov eax, [rbp-48]
    mov ecx, [fb_w]
    add ecx, 8
    cmp eax, ecx
    jg .sn
    ; steps = max(|dx|, |dy|)
    mov eax, [rbp-60]
    sub eax, [rbp-48]
    mov ecx, [rbp-64]
    sub ecx, [rbp-52]
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx
    cmp eax, ecx
    cmovl eax, ecx
    inc eax
    mov [rbp-72], eax               ; n
    ; sag depth in pixels ~ n / 10 + 2
    xor edx, edx
    mov ecx, 10
    div ecx
    add eax, 2
    mov [rbp-76], eax
    xor ebx, ebx
.px:
    cmp ebx, [rbp-72]
    jg .sn
    ; t = ebx / n
    mov eax, [rbp-60]
    sub eax, [rbp-48]
    imul eax, ebx
    cdq
    idiv dword [rbp-72]
    add eax, [rbp-48]
    mov r12d, eax                   ; x
    mov eax, [rbp-64]
    sub eax, [rbp-52]
    imul eax, ebx
    cdq
    idiv dword [rbp-72]
    add eax, [rbp-52]
    mov r13d, eax                   ; y
    ; sag = 4 s t (1-t)
    mov eax, [rbp-72]
    sub eax, ebx
    imul eax, ebx
    imul eax, [rbp-76]
    shl eax, 2
    mov ecx, [rbp-72]
    imul ecx, ecx
    inc ecx
    cdq
    idiv ecx
    add r13d, eax
    mov eax, [rbp-68]
    sub eax, [rbp-56]
    imul eax, ebx
    cdq
    idiv dword [rbp-72]
    add eax, [rbp-56]
    mov r14d, eax                   ; depth
    cmp dword [wire_front], 0
    je .col
    mov r14d, 65000
.col:
    mov edx, [wire_col]
    mov edi, r12d
    mov esi, r13d
    mov ecx, r14d
    call zpixel
    inc ebx
    jmp .px
.sn:
    cmp dword [rbp-92], 1
    je .out
    mov dword [rbp-92], 1
    jmp .side
.out:
    RETURN

; ---------------------------------------------------------------------
;  see-through: should this sprite (edi) at tile (esi, edx) be dithered?
;  near-cursor mode: only things in front of the pointed-at tile that
;  cover the cursor.  "all" mode: every building.
; ---------------------------------------------------------------------
xray_set:
    mov dword [blit_dither], 0
    mov eax, [set_xray]
    test eax, eax
    jz .o
    cmp eax, 2
    je .y
    cmp dword [hover_valid], 0
    je .o
    cmp dword [ui_captured], 0
    jne .o
    cmp dword [welcome], 0
    jne .o
    ; in front of the hovered tile?
    lea eax, [rsi+rdx]
    mov ecx, [hover_tx]
    add ecx, [hover_ty]
    cmp eax, ecx
    jle .o
    ; does the sprite cover the cursor (with a small margin)?
    shl edi, 4
    movsx eax, word [spr_table+rdi+4]
    mov ecx, [draw_sx]
    sub ecx, eax                    ; left
    movsx eax, word [spr_table+rdi+6]
    mov edx, [draw_sy]
    sub edx, eax                    ; top
    mov eax, [mouse_x]
    push rdx
    xor edx, edx
    div dword [zoom]
    pop rdx
    mov esi, eax                    ; cursor x in fb pixels
    sub esi, ecx
    add esi, 10
    js .o
    movzx eax, word [spr_table+rdi]
    add eax, 20
    cmp esi, eax
    jge .o
    mov eax, [mouse_y]
    push rdx
    xor edx, edx
    div dword [zoom]
    pop rdx
    sub eax, edx
    add eax, 10
    js .o
    movzx ecx, word [spr_table+rdi+2]
    add ecx, 20
    cmp eax, ecx
    jge .o
.y: mov dword [blit_dither], 1
.o: ret

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
.b:
    ; buildings eight years and older are weathered
    cmp byte [rsi+T_OBJ], OBJ_ZONEBLD
    jne .ok
    cmp byte [rsi+T_AGE], 96
    jb .ok
    lea rax, [remap_aged]
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
    mov rax, rbx
    sub rax, tiles
    shr rax, TILE_SHIFT
    mov [prob_tile+rcx*4], eax
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
    ; live pipes glow, pipes with no pump behind them stay grey
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    mov dword [pipe_col], RAMP(R_GLASS, 7)
    mov dword [pipe_col2], RAMP(R_DEEPWATER, 1)
    test byte [map_waterarea+rax], 2
    jnz .live
    mov dword [pipe_col], RAMP(R_GREY, 5)
    mov dword [pipe_col2], RAMP(R_GREY, 1)
.live:
    test byte [map_waterarea+rax], 4
    jz .sewok
    mov dword [pipe_col], RAMP(R_ORANGE, 7)
    mov dword [pipe_col2], RAMP(R_ORANGE, 2)
.sewok:
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
    mov r8d, [pipe_col]
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
    mov r8d, [pipe_col2]
    call fill_rect
    pop rsi
    pop rdi
    mov edx, 2
    mov ecx, 1
    mov r8d, [pipe_col]
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

; overlay_tint(rdi tile) -> eax TINT_* value for everything on the tile
FUNC overlay_tint
    mov rbx, rdi
    mov r12, rdi
    sub r12, tiles
    shr r12, TILE_SHIFT             ; map index
    mov eax, [eff_overlay]
    cmp eax, OV_LAND
    jne .p0
    ; land view: yours vivid, buyable gold, the rest dimmed
    mov edi, r12d
    and edi, MAP_W-1
    mov esi, r12d
    shr esi, MAP_SHIFT
    call plot_of
    mov edi, eax
    call plot_status
    mov ecx, eax
    mov eax, TINT_KEEP
    cmp ecx, 1
    je .ret
    mov eax, TINT_YELLOW
    test ecx, ecx
    jz .ret
    xor eax, eax
    cmp ecx, 4
    jne .ret
    mov eax, TINT_BROWN
    RETURN
.p0:
    cmp eax, OV_POWER
    jne .w
    ; buildings: powered or not.  ground: where power reaches
    mov rdi, rbx
    call power_conductive
    test eax, eax
    jz .parea
    cmp byte [rbx+T_OBJ], OBJ_POWER
    je .parea
    mov eax, TINT_YELLOW
    test byte [rbx+T_FLAGS], F_POWER
    jnz .ret
    mov eax, TINT_RED
    RETURN
.parea:
    xor eax, eax
    cmp byte [map_powerarea+r12], 0
    je .ret
    mov eax, TINT_YELLOW
    RETURN
.w:
    cmp eax, OV_WATER
    jne .tr
    cmp byte [rbx+T_TERRAIN], TER_WATER
    jne .wl
    ; rivers and lakes: clean blue, sewage brown
    mov eax, TINT_BLUE
    cmp byte [map_wpol+r12], 24
    jb .ret
    mov eax, TINT_BROWN
    RETURN
.wl:
    cmp byte [rbx+T_ZONE], 0
    jne .wz
    cmp byte [rbx+T_OBJ], OBJ_SERVICE
    je .wz
    xor eax, eax
    test byte [map_waterarea+r12], 1
    jz .ret
    mov eax, TINT_BLUE
    RETURN
.wz:
    mov eax, TINT_RED
    test byte [rbx+T_FLAGS], F_WATER
    jz .ret
    mov eax, TINT_BROWN
    test byte [rbx+T_FLAGS2], F2_DIRTY
    jnz .ret
    ; water in, but nowhere for the sewage to go
    mov eax, TINT_ORANGE
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .wok
    test byte [rbx+T_FLAGS2], F2_SEWAGE
    jz .ret
.wok:
    mov eax, TINT_BLUE
.ret:
    RETURN
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
    inc eax
    RETURN
.ident:
    xor eax, eax
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
