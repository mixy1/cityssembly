; =====================================================================
;  SPRITES - procedural voxel models for every piece of art in the game
;  All models are built at start-up and baked by vox_render.
; =====================================================================

%macro MAT 1
    mov dword [vox_mat], %1
%endmacro
%macro BOX 6
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov ecx, %4
    mov r8d, %5
    mov r9d, %6
    call vbox
%endmacro
%macro RFX 6
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov ecx, %4
    mov r8d, %5
    mov r9d, %6
    call vroof_x
%endmacro
%macro RFY 6
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov ecx, %4
    mov r8d, %5
    mov r9d, %6
    call vroof_y
%endmacro
%macro PYR 6
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov ecx, %4
    mov r8d, %5
    mov r9d, %6
    call vpyr
%endmacro
%macro CYL 5
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov ecx, %4
    mov r8d, %5
    call vcyl
%endmacro
%macro CONE 5
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov ecx, %4
    mov r8d, %5
    call vcone
%endmacro
%macro SPH 4
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov ecx, %4
    call vsphere
%endmacro
%macro PICK 2
    mov edi, %2
    call rand_range
    movzx eax, byte [%1+rax]
%endmacro
%macro BEGIN 3                ; grid size, height, seed
    mov edi, %1
    mov esi, %2
    mov edx, %3
    call vox_begin
    mov edi, [vox_seed]
    call hash32
    or eax, 1
    mov [rng_state], eax
    call rand
    call rand
%endmacro

ZONE_LEVELS  equ 5
ZONE_VARS    equ 4
VEH_TYPES    equ 6

section .bss
spr_grass       resd 4
spr_water       resd 16
spr_sand        resd 2
spr_dirt        resd 1
spr_rubble      resd 1
spr_road        resd 48            ; road type * 16 + mask
spr_busstop     resd 1
spr_construct2  resd 1
spr_lot         resd 8
spr_tree        resd 8
spr_zone        resd ZONE_TYPES*ZONE_LEVELS*ZONE_VARS
spr_zone2       resd ZONE_TYPES*3*2    ; 2x2 buildings, levels 3..5
spr_spec        resd 4*3*2             ; industry specialisations
spr_bld         resd BK_COUNT
spr_power       resd 16
spr_pylon       resd 1
spr_car         resd VEH_TYPES*4   ; type*4 + dir
spr_construct   resd 3
spr_rotor       resd 4
spr_flame       resd 2
spr_cursor      resd 1
loading_done    resd 1
loading_total   resd 1

section .data
lot_mats        db 0, M_ZONE_R, M_ZONE_C, M_ZONE_I, M_TEAL, M_LEAF, M_BLUE, 0
house_walls     db M_CREAM_WIN, M_WHITE_WIN, M_BRICK_WIN, M_BLUE_WIN
house_roofs     db M_ROOF_RED, M_ROOF_BLUE, M_ROOF_GREY, M_ROOF_BROWN, M_ROOF_GREEN
apt_walls       db M_BRICK_WIN, M_CREAM_WIN, M_WHITE_WIN
office_walls    db M_OFFICE, M_CREAM_OFFICE, M_TEAL_WIN, M_PURPLE_WIN
glass_mats      db M_GLASS, M_GLASS_BLUE
awning_mats     db M_AWN_RED, M_AWN_BLUE, M_AWN_GREEN
sign_mats       db M_SIGN_C, M_SIGN_P
shop_walls      db M_CREAM, M_WHITE, M_BRICK, M_TEAL
ind_walls       db M_METAL, M_TEAL_METAL, M_RUST
tree_leaves     db M_LEAF, M_LEAF, M_LEAF2
str_loading     db "Assembling the city...", 0
str_loading2    db "baking voxel sprites", 0
; cos/sin * 64 for 30-degree steps
sin30  db 0, 32, 55, 64, 55, 32, 0, -32, -55, -64, -55, -32
cos30  db 64, 55, 32, 0, -32, -55, -64, -55, -32, 0, 32, 55

section .text

; ---------------------------------------------------------------------
;  loading screen tick: redraw progress every few sprites
; ---------------------------------------------------------------------
FUNC loading_tick
    inc dword [loading_done]
    mov eax, [loading_done]
    and eax, 7
    jnz .out
    lea rdi, [event_buf]
    CALLC SDL_PollEvent
    call set_target_world
    mov edi, RAMP(R_ASPHALT, 0)
    call clear_target
    call set_target_ui
    xor edi, edi
    call clear_target
    mov eax, [ui_w]
    shr eax, 1
    mov r12d, eax
    mov eax, [ui_h]
    shr eax, 1
    mov r13d, eax
    mov dword [font_scale], 2
    mov edi, r12d
    lea esi, [r13-40]
    lea rdx, [str_loading]
    mov ecx, UI_GOLD
    call draw_text_centered
    mov dword [font_scale], 1
    mov edi, r12d
    lea esi, [r13-12]
    lea rdx, [str_loading2]
    mov ecx, UI_DIM
    call draw_text_centered
    ; bar
    lea edi, [r12-100]
    lea esi, [r13+4]
    mov edx, 200
    mov ecx, 10
    mov r8d, UI_BG2
    call draw_box
    mov eax, [loading_done]
    imul eax, 196
    xor edx, edx
    mov ecx, [loading_total]
    test ecx, ecx
    jz .out
    div ecx
    CLAMP eax, 0, 196
    mov edx, eax
    lea edi, [r12-98]
    lea esi, [r13+6]
    mov ecx, 6
    mov r8d, UI_GOLD
    call fill_rect
    call video_present
.out:
    RETURN

; finish a model: render + tick -> eax sprite id
FUNC finish_model
    call vox_render
    mov ebx, eax
    call loading_tick
    mov eax, ebx
    RETURN

; =====================================================================
;  ground tiles
; =====================================================================
FUNC gen_grass
    mov r12d, edi
    lea eax, [r12+100]
    BEGIN 16, 1, eax
    MAT M_GRASS
    BOX 0,0,0,16,16,1
    ; tufts and flowers
    mov ebx, 5
.t:
    mov edi, 16
    call rand_range
    mov r13d, eax
    mov edi, 16
    call rand_range
    mov r14d, eax
    MAT M_LEAF
    cmp r12d, 3
    jl .put
    mov edi, 4
    call rand_range
    cmp eax, 1
    jg .put
    MAT M_YELLOW
    test eax, eax
    jz .put
    MAT M_WHITE
.put:
    mov edi, r13d
    mov esi, r14d
    xor edx, edx
    call vset
    dec ebx
    jnz .t
    call finish_model
    RETURN

FUNC gen_water
    mov r12d, edi                   ; land mask
    lea eax, [r12+200]
    BEGIN 16, 1, eax
    MAT M_WATER
    BOX 0,0,0,16,16,1
    ; foam lines
    MAT M_BRIGHT
    test r12d, 1
    jz .f1
    BOX 0,2,0,16,3,1
.f1: test r12d, 2
    jz .f2
    BOX 13,0,0,14,16,1
.f2: test r12d, 4
    jz .f3
    BOX 0,13,0,16,14,1
.f3: test r12d, 8
    jz .f4
    BOX 2,0,0,3,16,1
.f4:
    MAT M_SAND
    test r12d, 1
    jz .s1
    BOX 0,0,0,16,2,1
.s1: test r12d, 2
    jz .s2
    BOX 14,0,0,16,16,1
.s2: test r12d, 4
    jz .s3
    BOX 0,14,0,16,16,1
.s3: test r12d, 8
    jz .s4
    BOX 0,0,0,2,16,1
.s4:
    call finish_model
    RETURN

FUNC gen_slab
    ; edi = material, esi = seed
    mov r12d, edi
    mov r13d, esi
    BEGIN 16, 1, r13d
    mov [vox_mat], r12d
    BOX 0,0,0,16,16,1
    call finish_model
    RETURN

FUNC gen_rubble
    BEGIN 16, 4, 77
    MAT M_DIRT
    BOX 0,0,0,16,16,1
    mov ebx, 26
.r:
    MAT M_CONCRETE
    call rand
    test eax, 1
    jz .m
    MAT M_BRICK
.m:
    mov edi, 12
    call rand_range
    lea r13d, [rax+2]
    mov edi, 12
    call rand_range
    lea r14d, [rax+2]
    mov edi, 3
    call rand_range
    lea r15d, [rax+1]
    lea ecx, [r13+2]
    lea r8d, [r14+2]
    lea r9d, [r15+1]
    mov edi, r13d
    mov esi, r14d
    mov edx, 1
    call vbox
    dec ebx
    jnz .r
    call finish_model
    RETURN

; zoned but empty lot, edi = zone (1..3)
FUNC gen_lot
    mov r12d, edi
    lea eax, [r12+300]
    BEGIN 16, 4, eax
    MAT M_GRASS
    BOX 0,0,0,16,16,1
    movzx eax, byte [lot_mats+r12]
    mov [vox_mat], eax
    mov r15d, eax
    ; dashed border
    xor ebx, ebx
.b:
    mov eax, ebx
    xor edx, edx
    mov ecx, 3
    div ecx
    test edx, edx
    jz .bn
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    call vset
    mov edi, ebx
    mov esi, 15
    xor edx, edx
    call vset
    xor edi, edi
    mov esi, ebx
    xor edx, edx
    call vset
    mov edi, 15
    mov esi, ebx
    xor edx, edx
    call vset
.bn:
    inc ebx
    cmp ebx, 16
    jl .b
    ; dense zones get a second, inner border
    cmp r12d, ZONE_O
    jb .stakes
    xor ebx, ebx
.b2:
    mov eax, ebx
    and eax, 1
    jnz .b2n
    lea edi, [rbx+2]
    mov esi, 2
    xor edx, edx
    call vset
    lea edi, [rbx+2]
    mov esi, 13
    xor edx, edx
    call vset
    mov edi, 2
    lea esi, [rbx+2]
    xor edx, edx
    call vset
    mov edi, 13
    lea esi, [rbx+2]
    xor edx, edx
    call vset
.b2n:
    inc ebx
    cmp ebx, 12
    jl .b2
.stakes:
    ; corner stakes
    BOX 1,1,1,2,2,3
    BOX 14,1,1,15,2,3
    BOX 1,14,1,2,15,3
    BOX 14,14,1,15,15,3
    call finish_model
    RETURN

; road with connection mask edi
FUNC gen_road
    mov r12d, edi
    lea eax, [r12+400]
    BEGIN 16, 2, eax
    MAT M_CONCRETE
    BOX 0,0,0,16,16,2
    ; asphalt: carve centre + arms (asphalt at z=0, air at z=1)
    MAT M_ASPHALT
    BOX 3,3,0,13,13,1
    MAT 0
    BOX 3,3,1,13,13,2
    xor ebx, ebx
.arm:
    bt r12d, ebx
    jnc .an
    mov eax, ebx
    shl eax, 2
    lea r13, [arm_boxes+rax*4]      ; x0,y0,x1,y1 dwords
    MAT M_ASPHALT
    mov edi, [r13]
    mov esi, [r13+4]
    xor edx, edx
    mov ecx, [r13+8]
    mov r8d, [r13+12]
    mov r9d, 1
    call vbox
    MAT 0
    mov edi, [r13]
    mov esi, [r13+4]
    mov edx, 1
    mov ecx, [r13+8]
    mov r8d, [r13+12]
    mov r9d, 2
    call vbox
.an:
    inc ebx
    cmp ebx, 4
    jl .arm
    ; markings
    popcnt r14d, r12d
    xor ebx, ebx
.mk:
    bt r12d, ebx
    jnc .mn
    cmp r14d, 3
    jge .cross
    ; dashed centre line from the edge to the middle
    MAT M_YELLOW
    xor r15d, r15d
.dash:
    mov eax, r15d
    and eax, 3
    cmp eax, 2
    jge .dn
    ; position along the arm
    mov eax, ebx
    shl eax, 2
    mov edi, [line_pts+rax*4]       ; x (or -1 = variable)
    mov esi, [line_pts+rax*4+4]
    cmp edi, -1
    jne .fx
    mov edi, [line_pts+rax*4+8]
    add edi, r15d
    jmp .put
.fx:
    mov esi, [line_pts+rax*4+8]
    add esi, r15d
.put:
    xor edx, edx
    call vset
.dn:
    inc r15d
    cmp r15d, 7
    jl .dash
    jmp .mn
.cross:
    MAT M_WHITE
    mov eax, ebx
    shl eax, 2
    lea r13, [cross_boxes+rax*4]
    xor r15d, r15d
.cw:
    mov eax, r15d
    shl eax, 1
    mov edi, [r13]
    mov esi, [r13+4]
    cmp dword [r13+8], 0
    jne .cwy
    add edi, eax
    jmp .cwp
.cwy:
    add esi, eax
.cwp:
    mov ecx, edi
    inc ecx
    mov r8d, esi
    inc r8d
    cmp dword [r13+8], 0
    jne .cwy2
    add r8d, 1
    jmp .cwb
.cwy2:
    add ecx, 1
.cwb:
    xor edx, edx
    mov r9d, 1
    call vbox
    inc r15d
    cmp r15d, 5
    jl .cw
.mn:
    inc ebx
    cmp ebx, 4
    jl .mk
    ; street lamp at a sidewalk corner for straight roads
    cmp r14d, 2
    jne .nolamp
    MAT M_DARK
    BOX 1,1,2,2,2,12
    MAT M_LAMP
    BOX 1,1,12,2,3,13
.nolamp:
    call finish_model
    RETURN

section .data
; arm boxes for mask bits: -y, +x, +y, -x   (x0,y0,x1,y1)
arm_boxes:
    dd 3,0,13,3
    dd 13,3,16,13
    dd 3,13,13,16
    dd 0,3,3,13
; centre line: fixed coord, fixed value, start of variable coord
;   (x fixed at 7 when running along y)
line_pts:
    dd 7, 0, 0, 0          ; -y arm: x=7, y from 0
    dd -1, 7, 9, 0         ; +x arm: y=7, x from 9
    dd 7, 0, 9, 0          ; +y arm: x=7, y from 9
    dd -1, 7, 0, 0         ; -x arm: y=7, x from 0
; crosswalk start x,y and orientation (0 = stripes step along x)
cross_boxes:
    dd 4, 0, 0, 0
    dd 14, 4, 1, 0
    dd 4, 14, 0, 0
    dd 0, 4, 1, 0
section .text

; steel lattice pylon (one model; wires are drawn live between pylons)
FUNC gen_pylon
    BEGIN 16, 30, 500
    MAT M_METAL
    ; four legs leaning in
    BOX 4,4,0,6,6,8
    BOX 10,4,0,12,6,8
    BOX 4,10,0,6,12,8
    BOX 10,10,0,12,12,8
    BOX 5,5,8,7,7,16
    BOX 9,5,8,11,7,16
    BOX 5,9,8,7,11,16
    BOX 9,9,8,11,11,16
    BOX 6,6,16,10,10,27
    MAT M_DARK
    ; cross bracing rings
    BOX 4,4,7,12,5,8
    BOX 4,11,7,12,12,8
    BOX 4,4,7,5,12,8
    BOX 11,4,7,12,12,8
    BOX 5,5,15,11,6,16
    BOX 5,10,15,11,11,16
    BOX 7,7,27,9,9,29
    ; cross arm, square to the view
    xor ebx, ebx
.arm:
    lea edi, [rbx+3]
    mov esi, 12
    sub esi, ebx
    lea ecx, [rdi+1]
    lea r8d, [rsi+1]
    mov edx, 24
    mov r9d, 26
    call vbox
    inc ebx
    cmp ebx, 10
    jl .arm
    ; insulators
    MAT M_WHITE
    BOX 3,12,22,4,13,24
    BOX 12,3,22,13,4,24
    call finish_model
    RETURN

; =====================================================================
;  trees
; =====================================================================
; tree_round(edi cx, esi cy, edx size, ecx material)
FUNC tree_round
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    MAT M_TRUNK
    lea eax, [r12*2+1]
    lea ebx, [r13*2+1]
    lea r8d, [r14+2]
    CYL eax, ebx, 0, 2, r8d
    mov [vox_mat], r15d
    lea eax, [r12*2+1]
    lea ebx, [r13*2+1]
    lea edx, [r14*4+2]              ; canopy centre z = 2*size+1
    lea ecx, [r14*2]
    mov edi, eax
    mov esi, ebx
    call vsphere
    RETURN

; tree_cone(edi cx, esi cy, edx size)
FUNC tree_cone
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    MAT M_TRUNK
    lea eax, [r12*2+1]
    lea ebx, [r13*2+1]
    CYL eax, ebx, 0, 2, 3
    MAT M_LEAF
    lea eax, [r12*2+1]
    lea ebx, [r13*2+1]
    lea ecx, [r14*2]
    lea r8d, [r14*2+r14]
    CONE eax, ebx, 2, ecx, r8d
    lea eax, [r12*2+1]
    lea ebx, [r13*2+1]
    lea edx, [r14*2+1]
    lea ecx, [r14*2-2]
    lea r8d, [r14*2]
    CONE eax, ebx, edx, ecx, r8d
    RETURN

FUNC gen_tree_tile
    mov r12d, edi                   ; variant
    lea eax, [r12+600]
    BEGIN 16, 30, eax
    mov edi, 3
    call rand_range
    lea ebx, [rax+1]                ; tree count
    cmp r12d, 2
    jge .loop
    mov ebx, 1
.loop:
    mov edi, 8
    call rand_range
    lea r13d, [rax+4]
    mov edi, 8
    call rand_range
    lea r14d, [rax+4]
    cmp ebx, 1
    jne .rnd
    ; single trees stand near the middle
    mov r13d, 8
    mov r14d, 8
.rnd:
    mov edi, 4
    call rand_range
    cmp eax, 1
    jle .cone
    mov edi, 3
    call rand_range
    lea r15d, [rax+3]
    PICK tree_leaves, 3
    mov ecx, eax
    mov edi, r13d
    mov esi, r14d
    mov edx, r15d
    call tree_round
    jmp .next
.cone:
    mov edi, 3
    call rand_range
    lea edx, [rax+3]
    mov edi, r13d
    mov esi, r14d
    call tree_cone
.next:
    dec ebx
    jnz .loop
    call finish_model
    RETURN

; =====================================================================
;  zone buildings.  edi = variant.  Each returns a sprite id.
; =====================================================================
FUNC res_1                         ; cottage
    mov r12d, edi
    lea eax, [r12+1000]
    BEGIN 16, 24, eax
    PICK house_walls, 4
    mov r13d, eax
    PICK house_roofs, 5
    mov r14d, eax
    ; hedge + garden
    MAT M_LEAF
    BOX 0,15,0,6,16,2
    BOX 10,15,0,16,16,2
    test r12d, 1
    jnz .ory
    mov [vox_mat], r14d
    RFX 3,3,6,13,13,5
    mov [vox_mat], r13d
    BOX 4,4,0,12,12,6
    RFX 4,4,6,12,12,4
    MAT M_DARK
    BOX 6,11,0,8,12,4
    MAT M_BRICK
    BOX 9,5,8,11,7,13
    jmp .tree
.ory:
    mov [vox_mat], r14d
    RFY 3,3,6,13,13,5
    mov [vox_mat], r13d
    BOX 4,4,0,12,12,6
    RFY 4,4,6,12,12,4
    MAT M_DARK
    BOX 11,6,0,12,8,4
    MAT M_BRICK
    BOX 5,9,8,7,11,13
.tree:
    cmp r12d, 2
    jne .d
    mov edi, 13
    mov esi, 2
    mov edx, 2
    mov ecx, M_LEAF
    call tree_round
.d:
    call finish_model
    RETURN

FUNC res_2                         ; family house, two storeys
    mov r12d, edi
    lea eax, [r12+1100]
    BEGIN 16, 30, eax
    PICK house_walls, 4
    mov r13d, eax
    PICK house_roofs, 5
    mov r14d, eax
    mov [vox_mat], r13d
    BOX 3,3,0,13,12,12
    ; garage annex
    MAT M_CREAM
    BOX 13,5,0,16,12,6
    MAT M_DARK
    BOX 15,6,0,16,11,5
    ; porch
    MAT M_WOOD
    BOX 5,12,0,11,15,1
    BOX 5,14,1,6,15,6
    BOX 10,14,1,11,15,6
    mov [vox_mat], r14d
    BOX 4,12,6,12,15,7
    PYR 2,2,12,14,13,5
    MAT M_DARK
    BOX 7,11,1,9,12,5
    mov [vox_mat], r14d
    BOX 13,5,6,16,12,7
    MAT M_LEAF
    BOX 0,13,0,4,15,2
    call finish_model
    RETURN

FUNC res_3                         ; townhouses / small apartments
    mov r12d, edi
    lea eax, [r12+1200]
    BEGIN 16, 40, eax
    PICK apt_walls, 3
    mov r13d, eax
    mov [vox_mat], r13d
    BOX 1,2,0,15,14,18
    MAT M_ROOF_GREY
    BOX 2,3,17,14,13,18
    MAT M_CONCRETE
    BOX 1,2,18,15,3,19
    BOX 1,13,18,15,14,19
    BOX 1,2,18,2,14,19
    BOX 14,2,18,15,14,19
    ; balconies on the +y face
    mov ebx, 6
.bal:
    MAT M_CONCRETE
    lea r14d, [rbx+1]
    BOX 3,14,ebx,7,15,r14d
    BOX 9,14,ebx,13,15,r14d
    add ebx, 6
    cmp ebx, 18
    jl .bal
    ; entrance canopy + ac units
    PICK awning_mats, 3
    mov [vox_mat], eax
    BOX 6,14,4,10,16,5
    MAT M_METAL
    BOX 4,5,18,6,7,20
    BOX 10,8,18,12,10,19
    call finish_model
    RETURN

FUNC res_4                         ; apartment block
    mov r12d, edi
    lea eax, [r12+1300]
    BEGIN 16, 56, eax
    PICK apt_walls, 3
    mov r13d, eax
    mov edi, 3
    call rand_range
    imul eax, eax, 6
    lea r15d, [rax+30]              ; height
    mov [vox_mat], r13d
    BOX 2,2,0,14,14,r15d
    ; balcony stacks on both visible faces
    mov ebx, 6
.bal:
    lea r14d, [rbx+1]
    MAT M_CONCRETE
    BOX 4,14,ebx,7,15,r14d
    BOX 9,14,ebx,12,15,r14d
    BOX 14,4,ebx,15,7,r14d
    BOX 14,9,ebx,15,12,r14d
    add ebx, 6
    cmp ebx, r15d
    jl .bal
    ; roof
    MAT M_CONCRETE
    lea eax, [r15+1]
    BOX 2,2,r15d,14,3,eax
    lea eax, [r15+1]
    BOX 2,13,r15d,14,14,eax
    lea eax, [r15+1]
    BOX 2,2,r15d,3,14,eax
    lea eax, [r15+1]
    BOX 13,2,r15d,14,14,eax
    ; water tank on legs
    MAT M_DARK
    lea r14d, [r15+3]
    BOX 6,6,r15d,7,7,r14d
    BOX 9,6,r15d,10,7,r14d
    BOX 6,9,r15d,7,10,r14d
    BOX 9,9,r15d,10,10,r14d
    MAT M_WOOD
    lea r8d, [r15+9]
    CYL 16,16,r14d,5,r8d
    MAT M_ROOF_GREY
    lea edx, [r15+9]
    lea r8d, [r15+10]
    CYL 16,16,edx,4,r8d
    call finish_model
    RETURN

FUNC res_5                         ; residential tower
    mov r12d, edi
    lea eax, [r12+1400]
    BEGIN 16, 100, eax
    mov edi, 3
    call rand_range
    imul eax, eax, 6
    lea r15d, [rax+60]
    MAT M_WHITE_WIN
    test r12d, 1
    jz .w
    MAT M_CREAM_WIN
.w:
    BOX 3,3,0,13,13,r15d
    ; vertical glass spine
    PICK glass_mats, 2
    mov [vox_mat], eax
    BOX 7,3,2,9,13,r15d
    BOX 3,7,2,13,9,r15d
    ; lobby
    MAT M_GLASS
    BOX 4,12,0,12,14,4
    ; crown
    MAT M_CONCRETE
    lea edx, [r15]
    lea r9d, [r15+3]
    BOX 4,4,edx,12,12,r9d
    MAT M_METAL
    lea edx, [r15+3]
    lea r8d, [r15+14]
    CYL 16,16,edx,1,r8d
    MAT M_BEACON
    lea edx, [r15+14]
    lea r9d, [r15+15]
    BOX 7,7,edx,9,9,r9d
    call finish_model
    RETURN

FUNC com_1                         ; corner shop
    mov r12d, edi
    lea eax, [r12+2000]
    BEGIN 16, 24, eax
    PICK shop_walls, 4
    mov [vox_mat], eax
    BOX 2,2,0,14,14,8
    MAT M_GLASS
    BOX 3,13,1,13,14,5
    BOX 13,3,1,14,13,5
    MAT M_DARK
    BOX 6,13,0,8,14,4
    PICK awning_mats, 3
    mov [vox_mat], eax
    BOX 2,14,5,14,16,6
    BOX 14,2,5,16,14,6
    MAT M_CONCRETE
    BOX 2,2,8,14,3,9
    BOX 2,2,8,3,14,9
    PICK sign_mats, 2
    mov [vox_mat], eax
    BOX 4,6,8,12,7,12
    call finish_model
    RETURN

FUNC com_2                         ; shops with offices above
    mov r12d, edi
    lea eax, [r12+2100]
    BEGIN 16, 36, eax
    PICK office_walls, 4
    mov [vox_mat], eax
    BOX 1,1,0,15,15,18
    MAT M_GLASS
    BOX 2,14,1,14,15,5
    BOX 14,2,1,15,14,5
    PICK awning_mats, 3
    mov [vox_mat], eax
    BOX 1,15,5,15,16,6
    BOX 15,1,5,16,15,6
    MAT M_ROOF_GREY
    BOX 2,2,17,14,14,18
    ; rooftop billboard on some, plant room on others
    test r12d, 1
    jz .plant
    MAT M_DARK
    BOX 4,8,18,5,9,22
    BOX 11,8,18,12,9,22
    PICK sign_mats, 2
    mov [vox_mat], eax
    BOX 3,8,22,13,9,28
    jmp .cdone
.plant:
    MAT M_METAL
    BOX 3,3,18,8,7,22
    MAT M_LEAF
    BOX 9,4,18,14,13,19
.cdone:
    call finish_model
    RETURN

FUNC com_3                         ; mid-rise office
    mov r12d, edi
    lea eax, [r12+2200]
    BEGIN 16, 56, eax
    mov edi, 3
    call rand_range
    imul eax, eax, 5
    lea r15d, [rax+28]
    PICK office_walls, 4
    mov [vox_mat], eax
    BOX 2,2,0,14,14,r15d
    MAT M_GLASS
    BOX 3,13,0,13,14,5
    BOX 13,3,0,14,13,5
    MAT M_CONCRETE
    lea r9d, [r15+1]
    BOX 2,2,r15d,14,3,r9d
    BOX 2,2,r15d,3,14,r9d
    BOX 2,13,r15d,14,14,r9d
    BOX 13,2,r15d,14,14,r9d
    MAT M_METAL
    lea r9d, [r15+4]
    BOX 5,5,r15d,10,9,r9d
    call finish_model
    RETURN

FUNC com_4                         ; glass office tower
    mov r12d, edi
    lea eax, [r12+2300]
    BEGIN 16, 100, eax
    mov edi, 4
    call rand_range
    imul eax, eax, 4
    lea r15d, [rax+56]
    PICK glass_mats, 2
    mov r13d, eax
    MAT M_CONCRETE
    BOX 1,1,0,15,15,6
    mov [vox_mat], r13d
    BOX 2,2,6,14,14,r15d
    MAT M_CONCRETE
    lea r9d, [r15+2]
    BOX 3,3,r15d,13,13,r9d
    mov [vox_mat], r13d
    lea edx, [r15+2]
    lea r9d, [r15+10]
    BOX 5,5,edx,11,11,r9d
    MAT M_NEON_C
    test r12d, 1
    jz .n
    MAT M_NEON_P
.n:
    lea edx, [r15-1]
    BOX 2,2,edx,14,14,r15d
    call finish_model
    RETURN

FUNC com_5                         ; skyscraper
    mov r12d, edi
    lea eax, [r12+2400]
    BEGIN 16, 140, eax
    MAT M_GLASS_BLUE
    BOX 1,1,0,15,15,24
    PICK glass_mats, 2
    mov r13d, eax
    mov [vox_mat], r13d
    BOX 2,2,24,14,14,80
    MAT M_CONCRETE
    BOX 2,2,50,14,14,52
    mov [vox_mat], r13d
    BOX 4,4,80,12,12,104
    MAT M_NEON_C
    cmp r12d, 1
    jne .nn
    MAT M_NEON_P
.nn:
    BOX 4,4,103,12,12,104
    MAT M_METAL
    PYR 4,4,104,12,12,4
    CYL 16,16,108,2,130
    MAT M_BEACON
    BOX 7,7,130,9,9,132
    call finish_model
    RETURN

FUNC ind_1                         ; warehouse
    mov r12d, edi
    lea eax, [r12+3000]
    BEGIN 16, 24, eax
    PICK ind_walls, 3
    mov [vox_mat], eax
    BOX 1,3,0,15,13,8
    MAT M_ROOF_GREY
    RFX 1,2,8,15,14,4
    MAT M_DARK
    BOX 3,12,0,7,13,6
    BOX 9,12,0,13,13,6
    MAT M_WOOD
    BOX 2,14,0,4,16,2
    BOX 13,14,0,15,16,3
    BOX 12,0,0,15,2,2
    call finish_model
    RETURN

FUNC ind_2                         ; factory with smokestack
    mov r12d, edi
    lea eax, [r12+3100]
    BEGIN 16, 48, eax
    PICK ind_walls, 3
    mov [vox_mat], eax
    BOX 1,1,0,11,15,12
    MAT M_ROOF_GREY
    RFY 1,1,12,6,15,3
    RFY 6,1,12,11,15,3
    MAT M_DARK
    BOX 3,14,0,8,15,7
    MAT M_STACK
    CYL 27,8,0,4,36
    MAT M_METAL
    BOX 11,10,0,15,15,6
    call finish_model
    RETURN

FUNC ind_3                         ; tank farm
    mov r12d, edi
    lea eax, [r12+3200]
    BEGIN 16, 40, eax
    PICK ind_walls, 3
    mov [vox_mat], eax
    BOX 1,1,0,8,15,10
    MAT M_ROOF_GREY
    RFY 1,1,10,8,15,3
    MAT M_WHITE
    CYL 23,9,0,7,15
    CYL 23,23,0,7,15
    SPH 23,9,28,6
    SPH 23,23,28,6
    MAT M_YELLOW
    BOX 8,4,8,12,5,9
    BOX 8,11,8,12,12,9
    MAT M_STACK
    CYL 5,5,10,2,30
    call finish_model
    RETURN

FUNC ind_4                         ; heavy plant
    mov r12d, edi
    lea eax, [r12+3300]
    BEGIN 16, 64, eax
    MAT M_RUST
    test r12d, 1
    jz .m
    MAT M_METAL
.m:
    BOX 1,1,0,15,15,16
    MAT M_ROOF_GREY
    RFX 1,1,16,15,9,3
    MAT M_DARK
    BOX 1,9,16,15,15,18
    MAT M_STACK
    CYL 8,26,16,4,52
    CYL 20,26,16,4,56
    MAT M_YELLOW
    BOX 4,14,0,12,15,8
    MAT M_LAMP
    BOX 2,15,10,3,16,11
    call finish_model
    RETURN

FUNC ind_5                         ; high-tech campus
    mov r12d, edi
    lea eax, [r12+3400]
    BEGIN 16, 40, eax
    MAT M_WHITE
    BOX 2,2,0,14,14,18
    MAT M_GLASS_BLUE
    BOX 2,2,4,14,14,14
    MAT M_WHITE
    BOX 3,3,4,13,13,14
    MAT M_SOLAR
    BOX 3,3,18,13,13,19
    MAT M_METAL
    CYL 8,8,18,1,28
    MAT M_WHITE
    SPH 8,8,56,5
    MAT M_NEON_C
    BOX 2,14,16,14,15,17
    call finish_model
    RETURN

section .data
align 8
; zone type 1..6 x level 1..5 x 4 variants: each variant is a different
; building so streets never repeat the same model
zone_models:
    ; R low
    dq res_1, res_cabin, res_1, res_2
    dq res_2, res_duplex, res_rowhouse, res_2
    dq res_villa, res_duplex, res_rowhouse, res_modern
    dq res_mansion, res_villa, res_modern, res_duplex
    dq res_mansion, res_modern, res_villa, res_mansion
    ; C low
    dq com_1, com_cafe, com_1, com_gas
    dq com_cafe, com_diner, com_1, com_market
    dq com_diner, com_gas, com_market, com_cafe
    dq com_market, com_diner, com_gas, com_2
    dq com_market, com_2, com_diner, com_dept
    ; I
    dq ind_1, ind_2, ind_1, ind_3
    dq ind_2, ind_3, ind_1, ind_2
    dq ind_3, ind_4, ind_2, ind_3
    dq ind_4, ind_3, ind_4, ind_2
    dq ind_5, ind_5, ind_4, ind_5
    ; O
    dq off_small, off_mid, off_small, com_3
    dq off_mid, com_3, off_small, off_mid
    dq com_3, off_mid, off_tower, com_4
    dq off_tower, com_4, off_tower, com_5
    dq com_5, off_tower, com_5, off_tower
    ; R high
    dq res_3, apt_walkup, res_3, res_rowhouse
    dq apt_walkup, res_3, res_4, apt_walkup
    dq res_4, apt_walkup, apt_tower, res_4
    dq apt_tower, res_4, res_5, apt_tower
    dq res_5, apt_tower, res_5, apt_tower
    ; C high
    dq com_2, com_dept, com_market, com_2
    dq com_dept, com_2, com_3, com_hotel
    dq com_3, com_hotel, com_dept, com_4
    dq com_hotel, com_4, com_3, com_hotel
    dq com_4, com_5, com_hotel, com_4
; 2x2 buildings for zone 1..6, levels 3..5 (0 = none)
zone2_models:
    dq 0, 0, 0
    dq 0, 0, 0
    dq ind_big, ind_big, ind_big
    dq off_hq, off_hq, off_twin
    dq apt_courtyard, apt_twin, apt_sky
    dq com_mall, com_cinema, off_hq
; industry specialisation looks (farm, forestry, ore) x 3
spec_models:
    dq farm_field, farm_barn, farm_green
    dq forest_yard, forest_mill, forest_mill
    dq ore_quarry, ore_mine, ore_mine
section .text

; construction stage edi = 0..2
FUNC gen_construct
    mov r12d, edi
    lea eax, [r12+900]
    BEGIN 16, 40, eax
    lea r13d, [r12*8+8]             ; height
    MAT M_DIRT
    BOX 1,1,0,15,15,1
    MAT M_CONCRETE
    mov eax, r13d
    shr eax, 1
    lea r9d, [rax+1]
    BOX 4,4,0,12,12,r9d
    MAT M_WOOD
    BOX 2,2,0,3,3,r13d
    BOX 13,2,0,14,3,r13d
    BOX 2,13,0,3,14,r13d
    BOX 13,13,0,14,14,r13d
    mov ebx, 4
.pl:
    cmp ebx, r13d
    jg .cr
    lea r14d, [rbx+1]
    BOX 2,13,ebx,14,14,r14d
    BOX 13,2,ebx,14,14,r14d
    add ebx, 4
    jmp .pl
.cr:
    cmp r12d, 2
    jne .d
    MAT M_YELLOW
    CYL 9,9,0,2,34
    BOX 4,4,32,16,5,34
    MAT M_DARK
    BOX 14,4,26,15,5,32
.d:
    call finish_model
    RETURN

; =====================================================================
;  service buildings
; =====================================================================
FUNC bld_coal
    BEGIN 48, 80, 5000
    MAT M_BRICK_WIN
    BOX 4,6,0,30,40,24
    MAT M_ROOF_GREY
    RFX 4,5,24,30,41,6
    MAT M_METAL
    BOX 30,8,0,44,30,32
    MAT M_DARK
    BOX 30,8,32,44,30,33
    MAT M_STACK
    CYL 74,46,0,7,76
    CYL 60,72,0,7,70
    MAT M_DARK
    PYR 4,41,0,26,47,4
    MAT M_YELLOW
    BOX 30,34,0,34,46,4
    call finish_model
    RETURN

FUNC bld_wind
    BEGIN 16, 64, 5100
    MAT M_CONCRETE
    CYL 16,16,0,6,2
    MAT M_WHITE
    CYL 16,16,0,3,46
    BOX 6,7,44,11,10,48
    call finish_model
    RETURN

; rotor frame edi = 0..3 (30 degrees apart, three blades)
FUNC gen_rotor
    mov r12d, edi
    BEGIN 16, 64, 5150
    MAT M_BRIGHT
    BOX 10,8,45,12,10,47
    xor r13d, r13d                  ; blade
.bl:
    mov eax, r13d
    shl eax, 2                      ; 120 deg = 4 steps
    add eax, r12d
    xor edx, edx
    mov ecx, 12
    div ecx
    mov r14d, edx                   ; angle index
    mov ebx, 1                      ; radius
.r:
    movsx eax, byte [cos30+r14]
    imul eax, ebx
    sar eax, 6
    lea esi, [rax+8]                ; y
    movsx eax, byte [sin30+r14]
    imul eax, ebx
    sar eax, 6
    lea edx, [rax+46]               ; z
    mov edi, 11
    call vset
    inc ebx
    cmp ebx, 14
    jl .r
    inc r13d
    cmp r13d, 3
    jl .bl
    call finish_model
    RETURN

FUNC bld_solar
    BEGIN 32, 12, 5200
    MAT M_GRASS
    BOX 0,0,0,32,32,1
    xor ebx, ebx
.row:
    lea r13d, [rbx*4+3]
    lea r14d, [r13+2]
    MAT M_SOLAR
    BOX 2,r13d,1,30,r14d,2
    lea r14d, [r13+1]
    BOX 2,r13d,2,30,r14d,3
    MAT M_METAL
    lea r14d, [r13+1]
    BOX 3,r13d,0,4,r14d,1
    inc ebx
    cmp ebx, 7
    jl .row
    call finish_model
    RETURN

FUNC bld_nuclear
    BEGIN 48, 76, 5300
    MAT M_CONCRETE
    BOX 26,26,0,46,46,14
    MAT M_WHITE
    CYL 72,72,14,16,20
    SPH 72,72,40,16
    ; hyperboloid cooling tower
    xor ebx, ebx
.ct:
    mov eax, ebx
    sub eax, 44
    imul eax, eax
    xor edx, edx
    mov ecx, 70
    div ecx
    lea r13d, [rax+22]              ; r2
    MAT M_CONCRETE
    lea r8d, [rbx+1]
    CYL 36,36,ebx,r13d,r8d
    MAT 0
    lea r8d, [rbx+1]
    lea ecx, [r13-3]
    CYL 36,36,ebx,ecx,r8d
    inc ebx
    cmp ebx, 60
    jl .ct
    MAT M_YELLOW
    BOX 2,40,0,20,46,3
    call finish_model
    RETURN

FUNC bld_pump
    BEGIN 16, 24, 5400
    MAT M_TEAL
    BOX 3,3,0,12,12,8
    MAT M_ROOF_BLUE
    BOX 3,3,8,12,12,9
    MAT M_BLUE
    CYL 28,14,0,4,5
    BOX 12,6,1,16,8,3
    MAT M_DARK
    BOX 6,11,0,8,12,5
    call finish_model
    RETURN

FUNC bld_wtower
    BEGIN 16, 40, 5500
    MAT M_METAL
    BOX 4,4,0,5,5,20
    BOX 11,4,0,12,5,20
    BOX 4,11,0,5,12,20
    BOX 11,11,0,12,12,20
    BOX 4,8,10,12,9,11
    MAT M_BLUE
    CYL 16,16,20,11,30
    MAT M_WHITE
    CYL 16,16,30,9,32
    CYL 16,16,32,5,34
    call finish_model
    RETURN

FUNC bld_police
    BEGIN 32, 40, 5600
    MAT M_WHITE_WIN
    BOX 3,3,0,29,21,14
    MAT M_BLUE
    BOX 3,3,6,29,21,7
    MAT M_CONCRETE
    BOX 3,3,14,29,4,15
    BOX 3,20,14,29,21,15
    BOX 3,3,14,4,21,15
    BOX 28,3,14,29,21,15
    MAT M_GLASS
    BOX 12,20,0,20,21,5
    ; parking with two squad cars
    MAT M_ASPHALT
    BOX 2,23,0,30,31,1
    MAT M_WHITE
    BOX 5,25,1,11,29,3
    BOX 18,25,1,24,29,3
    MAT M_BLUE
    BOX 6,25,3,10,29,4
    BOX 19,25,3,23,29,4
    MAT M_BEACON
    BOX 7,26,4,8,28,5
    BOX 20,26,4,21,28,5
    MAT M_NEON_C
    BOX 8,26,4,9,28,5
    BOX 21,26,4,22,28,5
    ; flag
    MAT M_METAL
    BOX 26,24,0,27,25,20
    MAT M_BLUE
    BOX 26,25,16,27,29,19
    call finish_model
    RETURN

FUNC bld_fire
    BEGIN 32, 44, 5700
    MAT M_BRICK_WIN
    BOX 3,3,0,29,22,14
    MAT M_RED
    BOX 5,21,0,11,22,9
    BOX 13,21,0,19,22,9
    MAT M_ROOF_GREY
    RFX 3,2,14,29,23,5
    MAT M_BRICK
    BOX 22,4,0,28,10,28
    MAT M_ROOF_RED
    PYR 21,3,28,29,11,4
    MAT M_CONCRETE
    BOX 3,22,0,21,31,1
    MAT M_RED
    BOX 6,24,1,10,30,4
    MAT M_WHITE
    BOX 6,24,4,10,26,5
    call finish_model
    RETURN

FUNC bld_clinic
    BEGIN 16, 28, 5800
    MAT M_WHITE_WIN
    BOX 2,2,0,14,14,12
    MAT M_CONCRETE
    BOX 2,2,12,14,3,13
    BOX 2,2,12,3,14,13
    MAT M_RED
    BOX 5,7,12,11,9,13
    BOX 7,5,12,9,11,13
    BOX 7,13,6,9,14,11
    BOX 6,13,7,10,14,10
    MAT M_GLASS
    BOX 5,13,0,11,14,4
    call finish_model
    RETURN

FUNC bld_hospital
    BEGIN 32, 56, 5900
    MAT M_WHITE_WIN
    BOX 2,2,0,30,24,18
    BOX 5,5,18,21,21,40
    MAT M_ASPHALT
    BOX 6,6,40,20,20,41
    MAT M_WHITE
    BOX 9,9,40,10,17,41
    BOX 16,9,40,17,17,41
    BOX 10,12,40,16,14,41
    MAT M_RED
    BOX 12,20,30,14,21,37
    BOX 10,20,32,16,21,35
    MAT M_CONCRETE
    BOX 8,24,6,24,30,7
    BOX 8,29,0,9,30,6
    BOX 23,29,0,24,30,6
    MAT M_GLASS
    BOX 10,23,0,22,24,5
    call finish_model
    RETURN

FUNC bld_school
    BEGIN 32, 36, 6000
    MAT M_BRICK_WIN
    BOX 2,2,0,30,12,14
    BOX 2,12,0,12,28,14
    MAT M_ROOF_RED
    RFX 2,1,14,30,13,6
    RFY 1,13,14,13,28,6
    MAT M_ASPHALT
    BOX 15,15,0,29,29,1
    MAT M_WHITE
    BOX 15,21,0,29,22,1
    MAT M_ORANGE
    BOX 16,16,1,17,17,7
    BOX 27,27,1,28,28,7
    MAT M_METAL
    BOX 13,3,14,14,4,30
    MAT M_RED
    BOX 13,4,26,14,9,29
    call finish_model
    RETURN

FUNC bld_univ
    BEGIN 48, 64, 6100
    MAT M_GRASS
    BOX 0,0,0,48,48,1
    MAT M_SAND
    BOX 22,30,0,26,48,1
    BOX 4,40,0,44,42,1
    MAT M_CREAM_WIN
    BOX 6,6,0,42,30,18
    MAT M_ROOF_GREY
    BOX 6,6,18,42,30,19
    ; portico columns
    MAT M_WHITE
    mov ebx, 14
.col:
    lea r13d, [rbx+2]
    BOX ebx,31,0,r13d,33,16
    add ebx, 5
    cmp ebx, 36
    jl .col
    BOX 13,30,16,36,34,18
    RFX 13,30,18,36,34,3
    ; dome
    MAT M_WHITE
    CYL 48,36,18,16,24
    MAT M_ROOF_GREEN
    SPH 48,36,48,15
    MAT M_GOLD
    CYL 48,36,40,2,46
    ; trees on the quad
    mov edi, 8
    mov esi, 38
    mov edx, 3
    mov ecx, M_LEAF
    call tree_round
    mov edi, 40
    mov esi, 38
    mov edx, 3
    mov ecx, M_LEAF2
    call tree_round
    call finish_model
    RETURN

FUNC bld_park
    BEGIN 16, 24, 6200
    MAT M_GRASS
    BOX 0,0,0,16,16,1
    MAT M_SAND
    BOX 7,0,0,9,16,1
    BOX 0,7,0,16,9,1
    MAT M_CONCRETE
    CYL 16,16,0,7,2
    MAT M_WATER
    CYL 16,16,1,5,2
    MAT M_WHITE
    CYL 16,16,2,1,5
    mov edi, 3
    mov esi, 3
    mov edx, 3
    mov ecx, M_LEAF
    call tree_round
    mov edi, 12
    mov esi, 12
    mov edx, 2
    mov ecx, M_LEAF2
    call tree_round
    MAT M_WOOD
    BOX 11,3,1,14,4,2
    BOX 3,11,1,4,14,2
    call finish_model
    RETURN

FUNC bld_plaza
    BEGIN 32, 30, 6300
    MAT M_CONCRETE
    BOX 0,0,0,32,32,1
    MAT M_SAND
    BOX 2,2,0,30,30,1
    MAT M_CONCRETE
    BOX 4,4,0,28,28,1
    MAT M_WHITE
    CYL 32,32,0,12,3
    MAT M_WATER
    CYL 32,32,1,10,3
    MAT M_WHITE
    CYL 32,32,3,2,8
    MAT M_WATER
    CYL 32,32,8,3,9
    mov r12d, 0
.t:
    mov eax, r12d
    mov edi, [plaza_trees+rax*8]
    mov esi, [plaza_trees+rax*8+4]
    mov edx, 3
    mov ecx, M_LEAF2
    test r12d, 1
    jz .l
    mov ecx, M_LEAF
.l:
    call tree_round
    inc r12d
    cmp r12d, 4
    jl .t
    MAT M_LEAF2
    BOX 12,2,0,20,4,2
    BOX 2,12,0,4,20,2
    call finish_model
    RETURN
section .data
plaza_trees dd 5,5, 26,5, 5,26, 26,26
section .text

FUNC bld_stadium
    BEGIN 48, 40, 6400
    MAT M_CONCRETE
    BOX 0,0,0,48,48,1
    ; tiers: for every column compute distance from centre
    xor r13d, r13d                  ; y
.y:
    xor r12d, r12d                  ; x
.x:
    lea eax, [r12*2+1]
    sub eax, 48
    imul eax, eax
    lea ecx, [r13*2+1]
    sub ecx, 48
    imul ecx, ecx
    ; ellipse: stretch x a little
    imul eax, 3
    shr eax, 2
    add eax, ecx                    ; d^2 in half-voxel units
    cmp eax, 30*30
    jl .field
    cmp eax, 46*46
    jg .xn
    ; stand height grows outward
    mov ebx, eax
    sub ebx, 30*30
    shr ebx, 6
    add ebx, 2
    CLAMP ebx, 2, 22
    MAT M_BLUE
    mov eax, r12d
    add eax, r13d
    and eax, 4
    jz .sm
    MAT M_RED
.sm:
    cmp eax, 44*44
    lea r9d, [rbx]
    mov edi, r12d
    mov esi, r13d
    xor edx, edx
    lea ecx, [r12+1]
    lea r8d, [r13+1]
    call vbox
    MAT M_CONCRETE
    mov edi, r12d
    mov esi, r13d
    xor edx, edx
    lea ecx, [r12+1]
    lea r8d, [r13+1]
    lea r9d, [rbx-1]
    call vbox
    jmp .xn
.field:
    MAT M_GRASS
    mov eax, r12d
    shr eax, 2
    test eax, 1
    jz .fs
    MAT M_LEAF
.fs:
    mov edi, r12d
    mov esi, r13d
    xor edx, edx
    lea ecx, [r12+1]
    lea r8d, [r13+1]
    mov r9d, 2
    call vbox
.xn:
    inc r12d
    cmp r12d, 48
    jl .x
    inc r13d
    cmp r13d, 48
    jl .y
    ; floodlights
    MAT M_METAL
    BOX 3,3,0,4,4,36
    BOX 44,3,0,45,4,36
    BOX 3,44,0,4,45,36
    BOX 44,44,0,45,45,36
    MAT M_LAMP
    BOX 2,2,36,6,6,38
    BOX 42,2,36,46,6,38
    BOX 2,42,36,6,46,38
    BOX 42,42,36,46,46,38
    call finish_model
    RETURN

FUNC bld_cityhall
    BEGIN 32, 60, 6500
    MAT M_CONCRETE
    BOX 1,1,0,31,31,1
    MAT M_WHITE_WIN
    BOX 4,4,0,28,26,18
    MAT M_ROOF_GREY
    BOX 4,4,18,28,26,19
    MAT M_WHITE
    mov ebx, 8
.col:
    lea r13d, [rbx+2]
    BOX ebx,27,1,r13d,29,16
    add ebx, 4
    cmp ebx, 24
    jl .col
    BOX 7,26,16,25,30,18
    RFX 7,26,18,25,30,3
    CYL 32,30,19,12,28
    MAT M_GOLD
    SPH 32,30,56,12
    CYL 32,30,40,1,52
    MAT M_BLUE
    BOX 16,15,46,17,19,50
    call finish_model
    RETURN

FUNC bld_landmark
    BEGIN 32, 190, 6600
    MAT M_GLASS_BLUE
    BOX 4,4,0,28,28,20
    MAT M_CONCRETE
    BOX 3,3,0,29,29,2
    MAT M_GLASS
    CYL 32,32,20,16,128
    MAT M_NEON_C
    mov ebx, 36
.ring:
    lea r8d, [rbx+1]
    CYL 32,32,ebx,17,r8d
    add ebx, 16
    cmp ebx, 128
    jl .ring
    MAT M_WHITE
    CYL 32,32,128,24,134
    MAT M_GLASS_BLUE
    CYL 32,32,134,22,142
    MAT M_WHITE
    CYL 32,32,142,20,146
    MAT M_METAL
    CONE 32,32,146,8,40
    MAT M_BEACON
    BOX 15,15,184,17,17,187
    call finish_model
    RETURN

section .data
align 8
bld_models:
    dq bld_coal, bld_wind, bld_solar, bld_nuclear, bld_pump, bld_wtower
    dq bld_sewage, bld_landfill, bld_incin
    dq bld_police, bld_fire, bld_clinic, bld_hospital
    dq bld_elem, bld_school, bld_univ, bld_busdepot
    dq bld_park, bld_plaza, bld_stadium, bld_cityhall, bld_landmark
section .text

; =====================================================================
;  vehicles.  car_box maps car-local (forward f, lateral l) to world.
; =====================================================================
section .bss
car_dir resd 1
section .text

; car_box(edi f0, esi l0, edx z0, ecx f1, r8d l1, r9d z1)
car_box:
    mov eax, [car_dir]
    cmp eax, 1
    je .px
    cmp eax, 3
    je .nx
    cmp eax, 2
    je .py
    ; 0: forward = -y : x = l, y = 16 - f
    mov eax, 16
    sub eax, ecx
    mov r10d, 16
    sub r10d, edi
    mov edi, esi
    mov esi, eax
    mov ecx, r8d
    mov r8d, r10d
    jmp vbox
.px:            ; forward = +x : x = f, y = 16 - l
    mov eax, 16
    sub eax, r8d
    mov r10d, 16
    sub r10d, esi
    mov esi, eax
    mov r8d, r10d
    jmp vbox
.nx:            ; forward = -x : x = 16 - f, y = l
    mov eax, 16
    sub eax, ecx
    mov r10d, 16
    sub r10d, edi
    mov edi, eax
    mov ecx, r10d
    jmp vbox
.py:            ; forward = +y : x = 16 - l, y = f
    mov eax, 16
    sub eax, r8d
    mov r10d, 16
    sub r10d, esi
    mov r11d, edi
    mov edi, eax
    mov r9d, r9d
    mov esi, r11d
    mov eax, ecx
    mov ecx, r10d
    mov r8d, eax
    jmp vbox

%macro CBOX 6
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov ecx, %4
    mov r8d, %5
    mov r9d, %6
    call car_box
%endmacro

; gen_car(edi type, esi dir)   type 0 car, 1 truck, 2 bus
FUNC gen_car
    mov r12d, edi
    mov [car_dir], esi
    BEGIN 16, 10, 7000
    cmp r12d, 1
    je .truck
    cmp r12d, 2
    je .bus
    MAT M_DARK
    CBOX 5,6,0,7,10,1
    CBOX 9,6,0,11,10,1
    MAT M_RED
    CBOX 4,6,1,12,10,3
    MAT M_GLASS
    CBOX 6,6,3,10,10,5
    MAT M_RED
    CBOX 7,6,5,9,10,5
    MAT M_LAMP
    CBOX 11,6,1,12,7,2
    CBOX 11,9,1,12,10,2
    jmp .d
.truck:
    MAT M_DARK
    CBOX 3,6,0,5,10,1
    CBOX 10,6,0,12,10,1
    MAT M_WHITE
    CBOX 2,6,1,10,10,6
    MAT M_RED
    CBOX 10,6,1,13,10,4
    MAT M_GLASS
    CBOX 11,6,4,12,10,5
    MAT M_RED
    CBOX 10,6,4,11,10,5
    jmp .d
.bus:
    MAT M_DARK
    CBOX 3,6,0,5,10,1
    CBOX 11,6,0,13,10,1
    MAT M_YELLOW
    CBOX 1,6,1,15,10,6
    MAT M_GLASS
    CBOX 2,6,3,14,10,5
.d:
    call finish_model
    RETURN

; flame frames
FUNC gen_flame
    mov r12d, edi
    lea eax, [r12+7100]
    BEGIN 16, 30, eax
    mov ebx, 70
.f:
    mov edi, 12
    call rand_range
    lea r13d, [rax+2]
    mov edi, 12
    call rand_range
    lea r14d, [rax+2]
    ; height higher toward centre
    mov eax, r13d
    sub eax, 8
    imul eax, eax
    mov ecx, r14d
    sub ecx, 8
    imul ecx, ecx
    add eax, ecx
    mov ecx, 90
    sub ecx, eax
    jle .fn
    shr ecx, 2
    mov edi, ecx
    call rand_range
    mov r15d, eax
    MAT M_FIRE
    mov edi, 3
    call rand_range
    test eax, eax
    jnz .m
    MAT M_YELLOW
.m:
    lea r9d, [r15+2]
    lea ecx, [r13+1]
    lea r8d, [r14+1]
    mov edi, r13d
    mov esi, r14d
    mov edx, r15d
    call vbox
.fn:
    dec ebx
    jnz .f
    call finish_model
    RETURN

; =====================================================================
;  sprites_init - build everything
; =====================================================================
FUNC sprites_init
    mov dword [loading_total], 340
    call remaps_init
    ; ground
    xor ebx, ebx
.gr:
    mov edi, ebx
    call gen_grass
    mov [spr_grass+rbx*4], eax
    inc ebx
    cmp ebx, 4
    jl .gr
    xor ebx, ebx
.wa:
    mov edi, ebx
    call gen_water
    mov [spr_water+rbx*4], eax
    inc ebx
    cmp ebx, 16
    jl .wa
    mov edi, M_SAND
    mov esi, 31
    call gen_slab
    mov [spr_sand], eax
    mov edi, M_SAND
    mov esi, 32
    call gen_slab
    mov [spr_sand+4], eax
    mov edi, M_DIRT
    mov esi, 33
    call gen_slab
    mov [spr_dirt], eax
    call gen_rubble
    mov [spr_rubble], eax
    call gen_pylon
    mov [spr_pylon], eax
    xor ebx, ebx
.rd:
    mov edi, ebx
    call gen_road
    mov [spr_road+rbx*4], eax
    mov edi, ebx
    call gen_avenue
    mov [spr_road+rbx*4+64], eax
    mov edi, ebx
    call gen_highway
    mov [spr_road+rbx*4+128], eax
    inc ebx
    cmp ebx, 16
    jl .rd
    mov ebx, 1
.lot:
    mov edi, ebx
    call gen_lot
    mov [spr_lot+rbx*4], eax
    inc ebx
    cmp ebx, ZONE_TYPES
    jl .lot
    ; trees
    xor ebx, ebx
.tr:
    mov edi, ebx
    call gen_tree_tile
    mov [spr_tree+rbx*4], eax
    inc ebx
    cmp ebx, 8
    jl .tr
    ; zone buildings: 6 zone types x 5 levels x 4 variant models
    xor r12d, r12d                  ; (zone-1)*5 + level-1
.zm:
    xor r13d, r13d                  ; variant
.zv:
    lea eax, [r12*4+r13]
    mov edi, r13d
    add edi, r12d                   ; vary the colour seed too
    call [zone_models+rax*8]
    lea ecx, [r12+ZONE_LEVELS]      ; skip zone 0
    imul ecx, ecx, ZONE_VARS
    add ecx, r13d
    mov [spr_zone+rcx*4], eax
    inc r13d
    cmp r13d, ZONE_VARS
    jl .zv
    inc r12d
    cmp r12d, 30
    jl .zm
    ; 2x2 buildings
    xor r12d, r12d
.z2:
    mov rax, [zone2_models+r12*8]
    test rax, rax
    jz .z2n
    xor r13d, r13d
.z2v:
    mov edi, r13d
    mov rax, [zone2_models+r12*8]
    call rax
    lea ecx, [r12+3]                ; zone offset (zone 0 row)
    imul ecx, ecx, 2
    add ecx, r13d
    mov [spr_zone2+rcx*4], eax
    inc r13d
    cmp r13d, 2
    jl .z2v
.z2n:
    inc r12d
    cmp r12d, 18
    jl .z2
    ; industry specialisations
    xor r12d, r12d
.sp:
    xor r13d, r13d
.spv:
    mov edi, r13d
    call [spec_models+r12*8]
    lea ecx, [r12+3]
    imul ecx, ecx, 2
    add ecx, r13d
    mov [spr_spec+rcx*4], eax
    inc r13d
    cmp r13d, 2
    jl .spv
    inc r12d
    cmp r12d, 9
    jl .sp
    ; construction
    xor ebx, ebx
.co:
    mov edi, ebx
    call gen_construct
    mov [spr_construct+rbx*4], eax
    inc ebx
    cmp ebx, 3
    jl .co
    ; services
    xor ebx, ebx
.bl:
    call [bld_models+rbx*8]
    mov [spr_bld+rbx*4], eax
    inc ebx
    cmp ebx, BK_COUNT
    jl .bl
    xor ebx, ebx
.ro:
    mov edi, ebx
    call gen_rotor
    mov [spr_rotor+rbx*4], eax
    inc ebx
    cmp ebx, 4
    jl .ro
    ; vehicles
    xor r12d, r12d
.ct:
    xor r13d, r13d
.cd:
    mov edi, r12d
    mov esi, r13d
    call gen_car
    lea ecx, [r12*4+r13]
    mov [spr_car+rcx*4], eax
    inc r13d
    cmp r13d, 4
    jl .cd
    inc r12d
    cmp r12d, 3
    jl .ct
    ; service vehicles (types 3..5)
    mov r12d, 3
.v2:
    xor r13d, r13d
.v2d:
    mov edi, r12d
    mov esi, r13d
    call gen_vehicle2
    lea ecx, [r12*4+r13]
    mov [spr_car+rcx*4], eax
    inc r13d
    cmp r13d, 4
    jl .v2d
    inc r12d
    cmp r12d, VEH_TYPES
    jl .v2
    call gen_busstop
    mov [spr_busstop], eax
    call gen_construct2
    mov [spr_construct2], eax
    mov edi, 0
    call gen_flame
    mov [spr_flame], eax
    mov edi, 1
    call gen_flame
    mov [spr_flame+4], eax
    RETURN

; zone_sprite(edi zone 1..6, esi level 1..5, edx variant, ecx size,
;             r8d industry spec) -> eax sprite id
zone_sprite:
    and edx, 0xFF
    cmp ecx, 2
    je .big
    cmp edi, ZONE_I
    jne .std
    test r8d, r8d
    jz .std
    ; specialised industry: 3 looks, levels 1-2, 3-4, 5
    mov eax, esi
    dec eax
    shr eax, 1
    cmp eax, 2
    jbe .sl
    mov eax, 2
.sl:
    lea ecx, [r8*2+r8]
    add eax, ecx                    ; spec*3 + look
    shl eax, 1
    and edx, 1
    add eax, edx
    mov eax, [spr_spec+rax*4]
    ret
.big:
    mov eax, esi
    sub eax, 3
    jns .b1
    xor eax, eax
.b1:
    cmp eax, 2
    jbe .b2
    mov eax, 2
.b2:
    imul ecx, edi, 3
    add eax, ecx
    shl eax, 1
    and edx, 1
    add eax, edx
    mov eax, [spr_zone2+rax*4]
    ret
.std:
    imul edi, edi, ZONE_LEVELS
    add edi, esi
    dec edi
    imul edi, edi, ZONE_VARS
    and edx, ZONE_VARS-1
    add edi, edx
    mov eax, [spr_zone+rdi*4]
    ret
