; =====================================================================
;  SPRITES2 - the expanded model library
;  road types, density-specific zone buildings, 2x2 merged buildings,
;  industry specialisations, new services and vehicles
; =====================================================================

section .data
villa_walls     db M_WHITE_WIN, M_CREAM_WIN, M_BLUE_WIN, M_WHITE_WIN
lux_roofs       db M_ROOF_GREY, M_ROOF_RED, M_ROOF_BROWN, M_ROOF_BLUE, M_ROOF_GREEN
row_walls       db M_BRICK_WIN, M_CREAM_WIN, M_BLUE_WIN, M_WHITE_WIN, M_TEAL_WIN
tower_walls     db M_WHITE_WIN, M_CREAM_WIN, M_BRICK_WIN, M_TEAL_WIN
off_walls       db M_OFFICE, M_CREAM_OFFICE, M_TEAL_WIN, M_PURPLE_WIN, M_GLASS, M_GLASS_BLUE
neon_mats       db M_NEON_C, M_NEON_P, M_LAMP, M_BEACON
crop_mats       db M_GRASS, M_YELLOW, M_OLIVE, M_LEAF2
pile_mats       db M_RED, M_BLUE, M_YELLOW, M_WHITE, M_ZONE_R, M_ORANGE, M_PURPLE, M_DARK
section .text

; =====================================================================
;  roads: avenue and highway variants (mask in edi)
; =====================================================================
FUNC gen_avenue
    mov r12d, edi
    lea eax, [r12+420]
    BEGIN 16, 3, eax
    MAT M_CONCRETE
    BOX 0,0,0,16,16,2
    ; asphalt everywhere except a 1-voxel sidewalk on closed sides
    mov r13d, 1                     ; x0
    mov r14d, 1                     ; y0
    mov r15d, 15                    ; x1
    mov ebx, 15                     ; y1
    test r12d, 1
    jz .a1
    xor r14d, r14d
.a1:
    test r12d, 2
    jz .a2
    mov r15d, 16
.a2:
    test r12d, 4
    jz .a3
    mov ebx, 16
.a3:
    test r12d, 8
    jz .a4
    xor r13d, r13d
.a4:
    MAT M_ASPHALT
    mov edi, r13d
    mov esi, r14d
    xor edx, edx
    mov ecx, r15d
    mov r8d, ebx
    mov r9d, 1
    call vbox
    MAT 0
    mov edi, r13d
    mov esi, r14d
    mov edx, 1
    mov ecx, r15d
    mov r8d, ebx
    mov r9d, 3
    call vbox
    popcnt r13d, r12d
    ; straight pieces get a planted median and lane dashes
    cmp r12d, 5
    jne .noy
    MAT M_CONCRETE
    BOX 7,0,0,9,16,2
    MAT M_GRASS
    BOX 7,0,1,9,16,2
    MAT M_WHITE
    xor ebx, ebx
.dy:
    BOX 4,ebx,0,5,ebx,1
    lea eax, [rbx+2]
    mov edi, 4
    mov esi, ebx
    xor edx, edx
    mov ecx, 5
    mov r8d, eax
    mov r9d, 1
    call vbox
    lea eax, [rbx+2]
    mov edi, 11
    mov esi, ebx
    xor edx, edx
    mov ecx, 12
    mov r8d, eax
    mov r9d, 1
    call vbox
    add ebx, 5
    cmp ebx, 16
    jl .dy
    jmp .lamp
.noy:
    cmp r12d, 10
    jne .inter
    MAT M_CONCRETE
    BOX 0,7,0,16,9,2
    MAT M_GRASS
    BOX 0,7,1,16,9,2
    MAT M_WHITE
    xor ebx, ebx
.dx:
    lea eax, [rbx+2]
    mov edi, ebx
    mov esi, 4
    xor edx, edx
    mov ecx, eax
    mov r8d, 5
    mov r9d, 1
    call vbox
    lea eax, [rbx+2]
    mov edi, ebx
    mov esi, 11
    xor edx, edx
    mov ecx, eax
    mov r8d, 12
    mov r9d, 1
    call vbox
    add ebx, 5
    cmp ebx, 16
    jl .dx
    jmp .lamp
.inter:
    cmp r13d, 3
    jl .out
    ; crosswalk stripes on each open side
    MAT M_WHITE
    xor ebx, ebx
.cw:
    lea eax, [rbx*2+2]
    lea ecx, [rax+1]
    test r12d, 1
    jz .c1
    mov edi, eax
    xor esi, esi
    xor edx, edx
    mov r8d, 2
    mov r9d, 1
    push rcx
    push rcx
    call vbox
    pop rcx
    pop rcx
.c1:
    lea eax, [rbx*2+2]
    lea ecx, [rax+1]
    test r12d, 4
    jz .c2
    mov edi, eax
    mov esi, 14
    xor edx, edx
    mov r8d, 16
    mov r9d, 1
    push rcx
    push rcx
    call vbox
    pop rcx
    pop rcx
.c2:
    lea eax, [rbx*2+2]
    lea r8d, [rax+1]
    test r12d, 2
    jz .c3
    mov edi, 14
    mov esi, eax
    xor edx, edx
    mov ecx, 16
    mov r9d, 1
    push r8
    push r8
    call vbox
    pop r8
    pop r8
.c3:
    lea eax, [rbx*2+2]
    lea r8d, [rax+1]
    test r12d, 8
    jz .c4
    xor edi, edi
    mov esi, eax
    xor edx, edx
    mov ecx, 2
    mov r9d, 1
    call vbox
.c4:
    inc ebx
    cmp ebx, 6
    jl .cw
    jmp .out
.lamp:
    MAT M_DARK
    BOX 7,7,2,9,9,14
    MAT M_LAMP
    BOX 5,7,13,11,9,14
.out:
    call finish_model
    RETURN

FUNC gen_highway
    mov r12d, edi
    lea eax, [r12+440]
    BEGIN 16, 5, eax
    MAT M_DARK
    BOX 0,0,0,16,16,1
    ; guard rails along closed sides
    MAT M_BRIGHT
    test r12d, 1
    jnz .g1
    BOX 0,0,1,16,1,3
.g1:
    test r12d, 2
    jnz .g2
    BOX 15,0,1,16,16,3
.g2:
    test r12d, 4
    jnz .g3
    BOX 0,15,1,16,16,3
.g3:
    test r12d, 8
    jnz .g4
    BOX 0,0,1,1,16,3
.g4:
    ; straight pieces: jersey barrier + lane lines
    mov eax, r12d
    and eax, 5
    cmp eax, 5
    jne .nx
    test r12d, 10
    jnz .nx
    MAT M_CONCRETE
    BOX 7,0,1,9,16,3
    MAT M_WHITE
    xor ebx, ebx
.ly:
    lea r8d, [rbx+3]
    BOX 3,ebx,0,4,r8d,1
    lea r8d, [rbx+3]
    BOX 12,ebx,0,13,r8d,1
    add ebx, 6
    cmp ebx, 16
    jl .ly
    MAT M_YELLOW
    BOX 1,0,0,2,16,1
    BOX 14,0,0,15,16,1
    jmp .out
.nx:
    mov eax, r12d
    and eax, 10
    cmp eax, 10
    jne .out
    test r12d, 5
    jnz .out
    MAT M_CONCRETE
    BOX 0,7,1,16,9,3
    MAT M_WHITE
    xor ebx, ebx
.lx:
    lea ecx, [rbx+3]
    mov edi, ebx
    mov esi, 3
    xor edx, edx
    mov r8d, 4
    mov r9d, 1
    call vbox
    lea ecx, [rbx+3]
    mov edi, ebx
    mov esi, 12
    xor edx, edx
    mov r8d, 13
    mov r9d, 1
    call vbox
    add ebx, 6
    cmp ebx, 16
    jl .lx
    MAT M_YELLOW
    BOX 0,1,0,16,2,1
    BOX 0,14,0,16,15,1
.out:
    call finish_model
    RETURN

FUNC gen_busstop
    BEGIN 16, 12, 460
    MAT M_METAL
    BOX 1,12,2,2,13,9
    BOX 4,12,2,5,13,9
    MAT M_GLASS
    BOX 1,13,2,5,14,8
    MAT M_BLUE
    BOX 0,12,9,6,15,10
    MAT M_YELLOW
    BOX 6,14,2,7,15,11
    MAT M_BLUE
    BOX 6,13,9,7,15,11
    call finish_model
    RETURN

; =====================================================================
;  low density residential
; =====================================================================
FUNC res_villa                     ; house with pool and garden
    mov r12d, edi
    lea eax, [r12+1500]
    BEGIN 16, 28, eax
    PICK villa_walls, 4
    mov r13d, eax
    PICK lux_roofs, 5
    mov r14d, eax
    MAT M_LEAF
    BOX 0,0,0,16,1,2
    BOX 0,0,0,1,16,2
    mov [vox_mat], r13d
    BOX 2,2,0,10,10,11
    mov [vox_mat], r14d
    PYR 1,1,11,11,11,4
    ; pool with deck
    MAT M_WHITE
    BOX 9,10,0,15,15,1
    MAT M_WATER
    BOX 10,11,0,14,14,1
    MAT M_DARK
    BOX 5,9,0,7,10,5
    mov edi, 13
    mov esi, 4
    mov edx, 2
    mov ecx, M_LEAF2
    call tree_round
    call finish_model
    RETURN

FUNC res_rowhouse                  ; three narrow townhouses
    mov r12d, edi
    lea eax, [r12+1550]
    BEGIN 16, 30, eax
    PICK lux_roofs, 5
    mov r14d, eax
    xor ebx, ebx
.h:
    PICK row_walls, 5
    mov [vox_mat], eax
    lea r13d, [rbx*4+rbx+1]         ; x0 = 5i+1
    lea r15d, [r13+5]
    BOX r13d,3,0,r15d,12,13
    mov [vox_mat], r14d
    lea r15d, [r13+5]
    RFY r13d,2,13,r15d,13,3
    MAT M_DARK
    lea edi, [r13+2]
    mov esi, 11
    xor edx, edx
    lea ecx, [r13+3]
    mov r8d, 12
    mov r9d, 4
    call vbox
    inc ebx
    cmp ebx, 3
    jl .h
    MAT M_LEAF
    BOX 0,13,0,16,15,1
    call finish_model
    RETURN

FUNC res_mansion
    mov r12d, edi
    lea eax, [r12+1600]
    BEGIN 16, 34, eax
    PICK villa_walls, 4
    mov r13d, eax
    PICK lux_roofs, 5
    mov r14d, eax
    MAT M_LEAF
    BOX 0,0,0,16,16,1
    MAT M_SAND
    BOX 7,10,0,9,16,1
    mov [vox_mat], r13d
    BOX 2,2,0,14,9,14
    BOX 2,9,0,6,13,10
    mov [vox_mat], r14d
    PYR 1,1,14,15,10,4
    PYR 1,8,10,7,14,3
    MAT M_WHITE
    CYL 22,24,0,4,2
    MAT M_WATER
    CYL 22,24,1,3,2
    MAT M_WHITE
    BOX 8,9,0,9,10,9
    BOX 12,9,0,13,10,9
    mov edi, 14
    mov esi, 13
    mov edx, 2
    mov ecx, M_LEAF
    call tree_round
    call finish_model
    RETURN

FUNC res_cabin                     ; small timber cabin
    mov r12d, edi
    lea eax, [r12+1650]
    BEGIN 16, 22, eax
    MAT M_WOOD
    BOX 4,4,0,12,11,6
    PICK house_roofs, 5
    mov [vox_mat], eax
    RFY 3,3,6,13,12,4
    MAT M_WOOD
    RFY 4,4,6,12,11,3
    MAT M_DARK
    BOX 6,10,0,8,11,4
    MAT M_GLASS
    BOX 9,10,2,11,11,4
    MAT M_BRICK
    BOX 10,5,6,11,6,11
    MAT M_WOOD
    BOX 4,11,0,12,14,1
    mov edi, 13
    mov esi, 3
    mov edx, 3
    call tree_cone
    call finish_model
    RETURN

FUNC res_duplex                    ; semi-detached pair
    mov r12d, edi
    lea eax, [r12+1680]
    BEGIN 16, 28, eax
    PICK house_walls, 4
    mov r13d, eax
    PICK house_roofs, 5
    mov r14d, eax
    mov [vox_mat], r13d
    BOX 2,3,0,14,12,11
    mov [vox_mat], r14d
    RFX 1,2,11,15,13,5
    mov [vox_mat], r13d
    RFX 2,3,11,14,12,4
    MAT M_WHITE
    BOX 7,3,0,9,12,12
    MAT M_DARK
    BOX 4,11,0,6,12,4
    BOX 10,11,0,12,12,4
    MAT M_LEAF
    BOX 1,13,0,7,15,2
    BOX 9,13,0,15,15,2
    call finish_model
    RETURN

FUNC res_modern                    ; flat-roofed glass house
    mov r12d, edi
    lea eax, [r12+1710]
    BEGIN 16, 24, eax
    MAT M_LEAF
    BOX 0,0,0,16,16,1
    MAT M_WHITE
    BOX 2,2,0,12,9,6
    BOX 5,5,6,14,12,11
    MAT M_GLASS_BLUE
    BOX 3,8,1,11,9,5
    BOX 13,6,7,14,11,10
    MAT M_WOOD
    BOX 5,11,6,14,12,11
    MAT M_WHITE
    BOX 2,9,0,5,14,1
    MAT M_WATER
    BOX 7,11,0,13,15,1
    call finish_model
    RETURN

; =====================================================================
;  high density residential
; =====================================================================
FUNC apt_walkup                    ; brick walk-up with fire escapes
    mov r12d, edi
    lea eax, [r12+1700]
    BEGIN 16, 44, eax
    PICK apt_walls, 3
    mov [vox_mat], eax
    mov edi, 2
    call rand_range
    imul eax, eax, 5
    lea r15d, [rax+25]
    BOX 2,2,0,14,14,r15d
    MAT M_ROOF_GREY
    lea edx, [r15-1]
    BOX 3,3,edx,13,13,r15d
    ; fire escape stairs on the +x face
    MAT M_DARK
    mov ebx, 5
.fe:
    lea r14d, [rbx+1]
    BOX 14,4,ebx,15,11,r14d
    add ebx, 5
    cmp ebx, r15d
    jl .fe
    BOX 14,4,4,15,5,r15d
    ; water tank
    MAT M_WOOD
    lea edx, [r15]
    lea r8d, [r15+6]
    CYL 12,12,edx,4,r8d
    PICK awning_mats, 3
    mov [vox_mat], eax
    BOX 5,14,4,11,16,5
    call finish_model
    RETURN

FUNC apt_tower                     ; tower with a setback crown
    mov r12d, edi
    lea eax, [r12+1750]
    BEGIN 16, 90, eax
    PICK tower_walls, 4
    mov r13d, eax
    mov edi, 3
    call rand_range
    imul eax, eax, 6
    lea r15d, [rax+46]
    mov [vox_mat], r13d
    BOX 3,3,0,13,13,r15d
    MAT M_CONCRETE
    mov ebx, 6
.b:
    lea r14d, [rbx+1]
    BOX 2,3,ebx,14,13,r14d
    BOX 3,2,ebx,13,14,r14d
    add ebx, 6
    cmp ebx, r15d
    jl .b
    mov [vox_mat], r13d
    lea r9d, [r15+8]
    BOX 5,5,r15d,11,11,r9d
    MAT M_ROOF_GREY
    lea edx, [r15+8]
    lea r9d, [r15+9]
    BOX 5,5,edx,11,11,r9d
    MAT M_LEAF
    BOX 3,3,r15d,5,13,r9d
    call finish_model
    RETURN

; 2x2 courtyard block
FUNC apt_courtyard
    mov r12d, edi
    lea eax, [r12+1800]
    BEGIN 32, 50, eax
    PICK apt_walls, 3
    mov r13d, eax
    mov [vox_mat], r13d
    BOX 2,2,0,30,10,30
    BOX 2,10,0,10,30,30
    BOX 22,10,0,30,30,24
    BOX 10,24,0,22,30,18
    MAT M_LEAF
    BOX 10,10,0,22,24,1
    mov edi, 15
    mov esi, 16
    mov edx, 3
    mov ecx, M_LEAF2
    call tree_round
    MAT M_ROOF_GREY
    BOX 2,2,29,30,10,30
    BOX 2,10,29,10,30,30
    MAT M_METAL
    BOX 20,4,30,24,8,33
    PICK awning_mats, 3
    mov [vox_mat], eax
    BOX 12,30,4,20,32,5
    call finish_model
    RETURN

; 2x2 twin towers on a podium
FUNC apt_twin
    mov r12d, edi
    lea eax, [r12+1850]
    BEGIN 32, 130, eax
    PICK tower_walls, 4
    mov r13d, eax
    MAT M_GLASS
    BOX 1,1,0,31,31,10
    MAT M_LEAF
    BOX 2,2,10,30,30,11
    mov [vox_mat], r13d
    BOX 3,3,11,13,13,100
    BOX 18,18,11,28,28,84
    PICK glass_mats, 2
    mov [vox_mat], eax
    BOX 7,3,11,9,13,100
    BOX 22,18,11,24,28,84
    MAT M_CONCRETE
    BOX 4,4,100,12,12,104
    BOX 19,19,84,27,27,88
    MAT M_BEACON
    BOX 7,7,104,9,9,106
    call finish_model
    RETURN

; 2x2 luxury skyscraper with roof garden
FUNC apt_sky
    mov r12d, edi
    lea eax, [r12+1900]
    BEGIN 32, 170, eax
    PICK glass_mats, 2
    mov r13d, eax
    MAT M_CONCRETE
    BOX 2,2,0,30,30,12
    mov [vox_mat], r13d
    CYL 32,32,12,22,150
    MAT M_WHITE
    mov ebx, 20
.r:
    lea r8d, [rbx+1]
    CYL 32,32,ebx,23,r8d
    add ebx, 10
    cmp ebx, 150
    jl .r
    MAT M_LEAF
    CYL 32,32,150,20,152
    mov edi, 14
    mov esi, 14
    mov edx, 3
    mov ecx, M_LEAF2
    push rdi
    push rdi
    MAT M_TRUNK
    pop rdi
    pop rdi
    MAT M_LEAF2
    SPH 30,30,310,6
    call finish_model
    RETURN

; =====================================================================
;  low density commercial
; =====================================================================
FUNC com_cafe
    mov r12d, edi
    lea eax, [r12+2500]
    BEGIN 16, 24, eax
    PICK shop_walls, 4
    mov [vox_mat], eax
    BOX 3,2,0,14,10,9
    MAT M_GLASS
    BOX 4,9,1,13,10,6
    PICK awning_mats, 3
    mov [vox_mat], eax
    RFX 2,9,6,15,13,2
    ; parasols and tables
    xor ebx, ebx
.p:
    lea r13d, [rbx*4+rbx+3]
    MAT M_WOOD
    lea ecx, [r13+1]
    mov edi, r13d
    mov esi, 13
    xor edx, edx
    mov r8d, 14
    mov r9d, 4
    call vbox
    PICK awning_mats, 3
    mov [vox_mat], eax
    lea edi, [r13*2+1]
    mov esi, 27
    mov edx, 4
    mov ecx, 5
    mov r8d, 5
    call vcyl
    inc ebx
    cmp ebx, 3
    jl .p
    PICK sign_mats, 2
    mov [vox_mat], eax
    BOX 5,5,9,11,6,12
    call finish_model
    RETURN

FUNC com_diner                     ; chrome diner with a neon sign
    mov r12d, edi
    lea eax, [r12+2550]
    BEGIN 16, 30, eax
    MAT M_ASPHALT
    BOX 0,10,0,16,16,1
    MAT M_WHITE
    BOX 1,6,1,5,8,2
    BOX 10,11,1,14,13,2
    MAT M_BRIGHT
    BOX 2,2,0,14,9,7
    PICK neon_mats, 4
    mov [vox_mat], eax
    BOX 2,8,3,14,9,4
    MAT M_GLASS
    BOX 3,8,4,13,9,6
    MAT M_RED
    BOX 2,2,7,14,9,8
    MAT M_METAL
    BOX 13,12,1,14,13,16
    PICK neon_mats, 4
    mov [vox_mat], eax
    BOX 11,12,14,16,13,19
    call finish_model
    RETURN

FUNC com_gas                       ; gas station
    mov r12d, edi
    lea eax, [r12+2600]
    BEGIN 16, 20, eax
    MAT M_ASPHALT
    BOX 0,0,0,16,16,1
    MAT M_CREAM
    BOX 1,1,0,6,7,7
    MAT M_GLASS
    BOX 1,6,1,6,7,5
    MAT M_METAL
    BOX 8,7,1,9,8,10
    BOX 14,7,1,15,8,10
    BOX 8,12,1,9,13,10
    BOX 14,12,1,15,13,10
    PICK awning_mats, 3
    mov [vox_mat], eax
    BOX 7,6,10,16,14,12
    MAT M_WHITE
    BOX 10,9,1,11,11,4
    BOX 12,9,1,13,11,4
    PICK sign_mats, 2
    mov [vox_mat], eax
    BOX 1,14,1,2,15,15
    BOX 0,14,12,4,15,16
    call finish_model
    RETURN

FUNC com_market                    ; grocery with a parking lot
    mov r12d, edi
    lea eax, [r12+2650]
    BEGIN 16, 24, eax
    MAT M_ASPHALT
    BOX 0,9,0,16,16,1
    MAT M_WHITE
    BOX 2,11,1,3,15,1
    BOX 6,11,1,7,15,1
    BOX 10,11,1,11,15,1
    PICK shop_walls, 4
    mov [vox_mat], eax
    BOX 1,1,0,15,9,9
    MAT M_GLASS
    BOX 3,8,1,13,9,5
    PICK awning_mats, 3
    mov [vox_mat], eax
    BOX 1,8,5,15,10,6
    PICK sign_mats, 2
    mov [vox_mat], eax
    BOX 4,6,9,12,7,13
    call finish_model
    RETURN

; =====================================================================
;  high density commercial
; =====================================================================
FUNC com_dept                      ; department store
    mov r12d, edi
    lea eax, [r12+2700]
    BEGIN 16, 40, eax
    PICK shop_walls, 4
    mov [vox_mat], eax
    BOX 1,1,0,15,15,22
    MAT M_GLASS_BLUE
    BOX 1,14,1,15,15,20
    BOX 14,1,1,15,15,20
    MAT M_CONCRETE
    BOX 1,14,6,15,16,7
    BOX 14,1,6,16,15,7
    BOX 1,14,13,15,16,14
    BOX 14,1,13,16,15,14
    PICK neon_mats, 4
    mov [vox_mat], eax
    BOX 3,15,15,13,16,19
    MAT M_ROOF_GREY
    BOX 2,2,21,14,14,22
    call finish_model
    RETURN

FUNC com_hotel
    mov r12d, edi
    lea eax, [r12+2750]
    BEGIN 16, 90, eax
    PICK tower_walls, 4
    mov r13d, eax
    mov edi, 3
    call rand_range
    imul eax, eax, 6
    lea r15d, [rax+54]
    mov [vox_mat], r13d
    BOX 3,3,0,13,13,r15d
    MAT M_GLASS
    BOX 2,2,0,14,14,6
    PICK awning_mats, 3
    mov [vox_mat], eax
    BOX 2,14,6,14,16,7
    ; vertical neon sign
    PICK neon_mats, 4
    mov [vox_mat], eax
    lea r9d, [r15-4]
    BOX 13,7,20,15,9,r9d
    MAT M_ROOF_GREY
    lea r9d, [r15+2]
    BOX 4,4,r15d,12,12,r9d
    MAT M_METAL
    lea edx, [r15+2]
    lea r9d, [r15+6]
    BOX 6,6,edx,10,8,r9d
    call finish_model
    RETURN

; 2x2 shopping mall
FUNC com_mall
    mov r12d, edi
    lea eax, [r12+2800]
    BEGIN 32, 40, eax
    MAT M_ASPHALT
    BOX 0,20,0,32,32,1
    MAT M_WHITE
    mov ebx, 2
.pk:
    lea ecx, [rbx+1]
    mov edi, ebx
    mov esi, 23
    xor edx, edx
    mov r8d, 30
    mov r9d, 1
    call vbox
    add ebx, 4
    cmp ebx, 32
    jl .pk
    PICK shop_walls, 4
    mov [vox_mat], eax
    BOX 2,2,0,30,20,14
    MAT M_GLASS
    PYR 10,6,14,22,16,5
    BOX 12,19,0,20,20,10
    PICK neon_mats, 4
    mov [vox_mat], eax
    BOX 8,19,11,24,21,13
    ; a few parked cars
    xor ebx, ebx
.car:
    PICK pile_mats, 8
    mov [vox_mat], eax
    lea edi, [rbx*8+3]
    lea ecx, [rdi+3]
    mov esi, 25
    mov edx, 1
    mov r8d, 29
    mov r9d, 3
    call vbox
    inc ebx
    cmp ebx, 4
    jl .car
    call finish_model
    RETURN

; 2x2 cinema multiplex
FUNC com_cinema
    mov r12d, edi
    lea eax, [r12+2850]
    BEGIN 32, 50, eax
    MAT M_PURPLE
    BOX 2,2,0,30,24,20
    MAT M_DARK
    BOX 2,2,20,30,24,21
    MAT M_GLASS
    BOX 6,23,0,26,24,8
    MAT M_CONCRETE
    BOX 4,24,8,28,28,9
    PICK neon_mats, 4
    mov [vox_mat], eax
    BOX 4,27,9,28,28,13
    MAT M_BEACON
    BOX 8,27,13,10,28,14
    BOX 22,27,13,24,28,14
    MAT M_METAL
    BOX 14,14,21,15,15,36
    MAT M_NEON_C
    BOX 10,14,34,20,15,40
    call finish_model
    RETURN

; =====================================================================
;  office
; =====================================================================
FUNC off_small
    mov r12d, edi
    lea eax, [r12+3500]
    BEGIN 16, 30, eax
    PICK off_walls, 6
    mov [vox_mat], eax
    BOX 2,2,0,14,14,16
    MAT M_CONCRETE
    BOX 1,1,0,15,15,2
    MAT M_GLASS
    BOX 5,13,2,11,14,6
    MAT M_ROOF_GREY
    BOX 3,3,16,13,13,17
    MAT M_METAL
    BOX 5,5,17,9,9,20
    call finish_model
    RETURN

FUNC off_mid
    mov r12d, edi
    lea eax, [r12+3550]
    BEGIN 16, 56, eax
    PICK off_walls, 6
    mov r13d, eax
    mov edi, 3
    call rand_range
    imul eax, eax, 4
    lea r15d, [rax+30]
    mov [vox_mat], r13d
    BOX 2,2,0,14,14,r15d
    MAT M_GLASS
    BOX 2,2,0,14,14,5
    PICK glass_mats, 2
    mov [vox_mat], eax
    BOX 2,6,5,14,10,r15d
    MAT M_CONCRETE
    lea r9d, [r15+2]
    BOX 3,3,r15d,13,13,r9d
    call finish_model
    RETURN

FUNC off_tower
    mov r12d, edi
    lea eax, [r12+3600]
    BEGIN 16, 110, eax
    PICK glass_mats, 2
    mov r13d, eax
    mov edi, 4
    call rand_range
    imul eax, eax, 6
    lea r15d, [rax+62]
    MAT M_CONCRETE
    BOX 2,2,0,14,14,6
    mov [vox_mat], r13d
    BOX 3,3,6,13,13,r15d
    ; crown style by variant
    mov eax, r12d
    and eax, 3
    cmp eax, 1
    je .pyr
    cmp eax, 2
    je .heli
    MAT M_METAL
    lea r9d, [r15+10]
    BOX 5,5,r15d,11,11,r9d
    lea edx, [r15+10]
    lea r8d, [r15+24]
    CYL 16,16,edx,1,r8d
    MAT M_BEACON
    lea edx, [r15+24]
    lea r9d, [r15+25]
    BOX 7,7,edx,9,9,r9d
    jmp .d
.pyr:
    MAT M_GOLD
    PYR 3,3,r15d,13,13,6
    jmp .d
.heli:
    MAT M_ASPHALT
    lea r9d, [r15+1]
    BOX 2,2,r15d,14,14,r9d
    MAT M_WHITE
    lea r9d, [r15+2]
    BOX 5,7,r15d,6,9,r9d
    BOX 10,7,r15d,11,9,r9d
    BOX 6,8,r15d,10,9,r9d
.d:
    call finish_model
    RETURN

; 2x2 corporate headquarters
FUNC off_hq
    mov r12d, edi
    lea eax, [r12+3650]
    BEGIN 32, 170, eax
    PICK glass_mats, 2
    mov r13d, eax
    MAT M_CONCRETE
    BOX 1,1,0,31,31,14
    MAT M_GLASS
    BOX 2,2,1,30,30,12
    mov [vox_mat], r13d
    BOX 5,5,14,27,27,80
    BOX 8,8,80,24,24,130
    BOX 11,11,130,21,21,150
    MAT M_WHITE
    BOX 5,5,40,27,27,42
    BOX 8,8,105,24,24,107
    MAT M_METAL
    CYL 32,32,150,2,168
    MAT M_BEACON
    BOX 15,15,168,17,17,170
    MAT M_NEON_C
    BOX 5,26,70,27,27,74
    call finish_model
    RETURN

; 2x2 twin office towers joined by a skybridge
FUNC off_twin
    mov r12d, edi
    lea eax, [r12+3700]
    BEGIN 32, 175, eax
    PICK glass_mats, 2
    mov r13d, eax
    MAT M_CONCRETE
    BOX 1,1,0,31,31,8
    mov [vox_mat], r13d
    BOX 3,3,8,14,14,150
    BOX 18,18,8,29,29,150
    MAT M_METAL
    BOX 10,10,90,22,22,94
    PYR 3,3,150,14,14,6
    PYR 18,18,150,29,29,6
    CYL 17,17,155,1,172
    CYL 47,47,155,1,172
    call finish_model
    RETURN

; =====================================================================
;  industry: big factory (2x2) and specialisations
; =====================================================================
FUNC ind_big
    mov r12d, edi
    lea eax, [r12+3800]
    BEGIN 32, 80, eax
    PICK ind_walls, 3
    mov [vox_mat], eax
    BOX 1,1,0,31,20,18
    MAT M_ROOF_GREY
    mov ebx, 1
.saw:
    lea ecx, [rbx+5]
    RFY ebx,1,18,ecx,20,3
    add ebx, 5
    cmp ebx, 31
    jl .saw
    MAT M_STACK
    CYL 10,52,0,5,64
    CYL 26,52,0,5,70
    CYL 42,52,0,5,58
    MAT M_WHITE
    CYL 56,54,0,7,20
    MAT M_YELLOW
    BOX 4,20,0,20,22,8
    call finish_model
    RETURN

FUNC farm_field                    ; crops + shed
    mov r12d, edi
    lea eax, [r12+3900]
    BEGIN 16, 16, eax
    PICK crop_mats, 4
    mov r13d, eax
    xor ebx, ebx
.row:
    MAT M_DIRT
    mov eax, ebx
    xor edx, edx
    mov ecx, 3
    div ecx
    test edx, edx
    jz .dirt
    mov [vox_mat], r13d
    lea ecx, [rbx+1]
    mov edi, ebx
    xor esi, esi
    mov edx, 0
    mov r8d, 16
    mov r9d, 2
    call vbox
    jmp .rn
.dirt:
    lea ecx, [rbx+1]
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov r8d, 16
    mov r9d, 1
    call vbox
.rn:
    inc ebx
    cmp ebx, 16
    jl .row
    MAT M_WOOD
    BOX 11,11,0,15,15,6
    MAT M_ROOF_RED
    RFX 11,10,6,15,16,3
    call finish_model
    RETURN

FUNC farm_barn                     ; red barn and silo
    mov r12d, edi
    lea eax, [r12+3950]
    BEGIN 16, 32, eax
    PICK crop_mats, 4
    mov [vox_mat], eax
    BOX 0,10,0,16,16,2
    MAT M_RED
    BOX 2,2,0,11,10,10
    MAT M_ROOF_GREY
    RFX 2,1,10,11,11,5
    MAT M_WHITE
    BOX 5,9,0,8,10,7
    MAT M_METAL
    CYL 27,9,0,5,24
    MAT M_ROOF_GREY
    SPH 27,9,48,5
    call finish_model
    RETURN

FUNC farm_green                    ; greenhouses
    mov r12d, edi
    lea eax, [r12+4000]
    BEGIN 16, 16, eax
    MAT M_DIRT
    BOX 0,0,0,16,16,1
    MAT M_GLASS
    RFX 1,1,1,15,7,4
    RFX 1,9,1,15,15,4
    MAT M_WHITE
    BOX 1,1,1,2,7,4
    BOX 1,9,1,2,15,4
    call finish_model
    RETURN

FUNC forest_yard                   ; log piles among pines
    mov r12d, edi
    lea eax, [r12+4050]
    BEGIN 16, 26, eax
    MAT M_DIRT
    BOX 0,0,0,16,16,1
    MAT M_TRUNK
    BOX 2,8,1,10,14,3
    BOX 3,9,3,9,13,5
    BOX 11,2,1,15,7,3
    mov edi, 4
    mov esi, 3
    mov edx, 3
    call tree_cone
    mov edi, 13
    mov esi, 12
    mov edx, 3
    call tree_cone
    call finish_model
    RETURN

FUNC forest_mill                   ; sawmill
    mov r12d, edi
    lea eax, [r12+4100]
    BEGIN 16, 30, eax
    MAT M_WOOD
    BOX 1,2,0,12,12,9
    MAT M_ROOF_GREY
    RFX 1,1,9,12,13,4
    MAT M_TRUNK
    BOX 12,3,0,16,7,2
    BOX 12,9,0,16,14,3
    MAT M_METAL
    BOX 8,12,3,15,13,4
    MAT M_STACK
    CYL 6,6,9,2,24
    call finish_model
    RETURN

FUNC ore_quarry
    mov r12d, edi
    lea eax, [r12+4150]
    BEGIN 16, 20, eax
    MAT M_DIRT
    BOX 0,0,0,16,16,1
    MAT M_CONCRETE
    PYR 1,1,0,9,9,5
    MAT M_DARK
    PYR 8,7,0,15,14,4
    MAT M_YELLOW
    BOX 2,11,1,6,14,3
    BOX 2,12,3,4,14,4
    call finish_model
    RETURN

FUNC ore_mine                      ; headframe and conveyor
    mov r12d, edi
    lea eax, [r12+4200]
    BEGIN 16, 40, eax
    MAT M_DIRT
    BOX 0,0,0,16,16,1
    MAT M_RUST
    BOX 2,2,0,3,3,30
    BOX 8,2,0,9,3,30
    BOX 2,8,0,3,9,30
    BOX 8,8,0,9,9,30
    BOX 2,2,28,9,9,30
    MAT M_RED
    CYL 11,11,30,3,32
    MAT M_METAL
    BOX 10,10,0,15,15,8
    MAT M_DARK
    PYR 10,1,0,16,7,4
    call finish_model
    RETURN

; =====================================================================
;  new services
; =====================================================================
FUNC bld_sewage
    BEGIN 16, 16, 6700
    MAT M_CONCRETE
    BOX 2,2,0,14,14,4
    MAT M_DARK
    CYL 28,16,0,5,6
    MAT M_DIRT
    CYL 28,16,0,3,6
    MAT M_METAL
    BOX 4,4,4,7,7,8
    call finish_model
    RETURN

FUNC bld_landfill
    BEGIN 32, 20, 6750
    MAT M_DIRT
    BOX 0,0,0,32,32,1
    MAT M_WOOD
    BOX 0,0,1,32,1,3
    BOX 0,0,1,1,32,3
    ; colourful garbage heaps
    xor ebx, ebx
.h:
    PICK pile_mats, 8
    mov [vox_mat], eax
    mov edi, 22
    call rand_range
    lea r13d, [rax+3]
    mov edi, 22
    call rand_range
    lea r14d, [rax+3]
    mov edi, 4
    call rand_range
    lea r9d, [rax+2]
    lea ecx, [r13+6]
    lea r8d, [r14+6]
    mov edi, r13d
    mov esi, r14d
    mov edx, 1
    call vpyr
    inc ebx
    cmp ebx, 14
    jl .h
    MAT M_YELLOW
    BOX 22,24,1,28,28,4
    MAT M_GLASS
    BOX 23,24,4,26,27,6
    call finish_model
    RETURN

FUNC bld_incin
    BEGIN 32, 80, 6800
    MAT M_METAL
    BOX 2,2,0,24,22,16
    MAT M_ROOF_GREY
    RFX 2,1,16,24,23,4
    MAT M_CONCRETE
    BOX 4,22,0,20,30,6
    MAT M_DARK
    BOX 6,24,6,18,30,7
    MAT M_STACK
    CYL 54,14,0,5,76
    MAT M_ORANGE
    BOX 2,21,6,24,22,8
    call finish_model
    RETURN

FUNC bld_elem
    BEGIN 16, 28, 6850
    MAT M_BRICK_WIN
    BOX 2,2,0,14,9,10
    MAT M_ROOF_RED
    RFX 2,1,10,14,10,4
    MAT M_ASPHALT
    BOX 2,10,0,15,15,1
    MAT M_ORANGE
    BOX 3,11,1,4,12,5
    MAT M_YELLOW
    BOX 8,11,1,13,14,2
    MAT M_METAL
    BOX 14,2,0,15,3,18
    MAT M_BLUE
    BOX 14,3,15,15,7,18
    call finish_model
    RETURN

FUNC bld_busdepot
    BEGIN 32, 30, 6900
    MAT M_ASPHALT
    BOX 0,0,0,32,32,1
    MAT M_CONCRETE
    BOX 2,2,0,30,18,12
    MAT M_ROOF_GREY
    mov ebx, 2
.s:
    lea ecx, [rbx+7]
    RFY ebx,2,12,ecx,18,3
    add ebx, 7
    cmp ebx, 30
    jl .s
    MAT M_DARK
    BOX 4,17,0,10,18,8
    BOX 13,17,0,19,18,8
    BOX 22,17,0,28,18,8
    ; parked buses
    MAT M_YELLOW
    BOX 4,21,1,16,25,6
    BOX 4,27,1,16,31,6
    BOX 19,21,1,31,25,6
    MAT M_GLASS
    BOX 5,21,3,15,25,5
    BOX 5,27,3,15,31,5
    BOX 20,21,3,30,25,5
    call finish_model
    RETURN

; =====================================================================
;  more vehicles (car_box transform, types 3..5)
; =====================================================================
FUNC gen_vehicle2
    mov r12d, edi
    mov [car_dir], esi
    BEGIN 16, 12, 7300
    cmp r12d, 3
    je .fire
    cmp r12d, 4
    je .garbage
    ; police car
    MAT M_DARK
    CBOX 5,6,0,7,10,1
    CBOX 9,6,0,11,10,1
    MAT M_WHITE
    CBOX 4,6,1,12,10,3
    MAT M_BLUE
    CBOX 6,6,3,10,10,5
    MAT M_BEACON
    CBOX 7,6,5,8,8,6
    MAT M_NEON_C
    CBOX 7,8,5,8,10,6
    jmp .d
.fire:
    MAT M_DARK
    CBOX 2,6,0,4,10,1
    CBOX 10,6,0,12,10,1
    MAT M_RED
    CBOX 1,6,1,13,10,5
    MAT M_GLASS
    CBOX 11,6,3,13,10,5
    MAT M_BRIGHT
    CBOX 2,7,5,10,9,6
    MAT M_BEACON
    CBOX 11,7,5,12,9,6
    jmp .d
.garbage:
    MAT M_DARK
    CBOX 2,6,0,4,10,1
    CBOX 10,6,0,12,10,1
    MAT M_ZONE_R
    CBOX 1,6,1,10,10,7
    MAT M_WHITE
    CBOX 10,6,1,13,10,5
    MAT M_GLASS
    CBOX 11,6,3,13,10,5
.d:
    call finish_model
    RETURN

FUNC gen_construct2
    BEGIN 32, 50, 7400
    MAT M_DIRT
    BOX 1,1,0,31,31,1
    MAT M_CONCRETE
    BOX 6,6,0,26,26,14
    MAT M_WOOD
    mov ebx, 2
.p:
    BOX ebx,2,0,ebx,2,0
    lea ecx, [rbx+1]
    mov edi, ebx
    mov esi, 2
    xor edx, edx
    mov r8d, 3
    mov r9d, 24
    call vbox
    lea ecx, [rbx+1]
    mov edi, ebx
    mov esi, 29
    xor edx, edx
    mov r8d, 30
    mov r9d, 24
    call vbox
    add ebx, 9
    cmp ebx, 31
    jl .p
    BOX 2,2,8,30,3,9
    BOX 2,2,16,30,3,17
    BOX 29,2,8,30,30,9
    BOX 29,2,16,30,30,17
    MAT M_YELLOW
    CYL 17,17,0,2,46
    BOX 6,6,44,30,7,46
    call finish_model
    RETURN
