; =====================================================================
;  SPRITES3 - neighbourhood architecture
;  Six styles of home, each with a low- and a high-density form, built
;  parametrically for levels 1..5 (edi = level, esi = variant):
;    Old Town   brownstone rows            brick tenements, water towers
;    Garden     gabled houses, fences      terraces with balconies, roof gardens
;    Shore      beach houses on stilts     glass condos with balcony rims
;    Worker     clapboard cottage rows     concrete / brick housing projects
;    Uptown     painted-lady victorians    art-deco towers with spires
;    Modern     white-and-timber boxes     glass towers
; =====================================================================

section .data
siding_mats   db M_WHITE_WIN, M_CREAM_WIN, M_YELLOW_WIN, M_GREEN_WIN, M_BLUE_WIN, M_PINK_WIN
sty_roofs   db M_ROOF_RED, M_ROOF_GREY, M_ROOF_SLATE, M_ROOF_BROWN, M_ROOF_BLUE
brown_mats    db M_BROWNST_WIN, M_BROWNST_WIN, M_BRICK_WIN, M_CREAM_WIN
beach_mats    db M_SAND_WIN, M_TEALP_WIN, M_PINK_WIN, M_WHITE_WIN, M_YELLOW_WIN, M_CORAL_WIN
beach_roofs   db M_WHITE, M_ROOF_BLUE, M_TEAL, M_ROOF_RED
worker_mats   db M_WHITE_WIN, M_CONC_WIN, M_CREAM_WIN, M_TEALP_WIN
worker_roofs  db M_ROOF_GREY, M_ROOF_SLATE, M_ROOF_RED
victor_mats   db M_LILAC_WIN, M_TEALP_WIN, M_YELLOW_WIN, M_PINK_WIN, M_GREEN_WIN, M_CORAL_WIN
tenement_mats db M_BRICK_WIN, M_BROWNST_WIN, M_CREAM_WIN, M_BRICK_WIN
terrace_mats  db M_CREAM_WIN, M_WHITE_WIN, M_YELLOW_WIN, M_SAND_WIN, M_BRICK_WIN
condo_mats    db M_GLASS, M_GLASS_TEAL, M_GLASS_BLUE
project_mats  db M_CONC_WIN, M_BRICK_WIN, M_CONC_WIN
deco_mats     db M_DECO_WIN, M_CREAM_OFFICE, M_DECO_WIN
tower_mats    db M_GLASS_BLUE, M_GLASS, M_GLASS_TEAL
store_awns    db M_AWN_RED, M_AWN_BLUE, M_AWN_GREEN
var_storey    db -4, 0, 4, 0          ; height nudge per variant (voxels)
section .text

; storeys helper: (edi level, esi base) -> eax = base + (level>=3) + (level>=5)
storeys_for:
    mov eax, esi
    cmp edi, 3
    jl .a
    inc eax
.a: cmp edi, 5
    jl .b
    inc eax
.b: ret

; a small street tree at voxel (edi, esi)
FUNC street_tree
    mov r12d, edi
    mov r13d, esi
    MAT M_TRUNK
    lea eax, [r12*2+1]
    lea ebx, [r13*2+1]
    CYL eax, ebx, 0, 1, 4
    MAT M_LEAF
    lea eax, [r12*2+1]
    lea ebx, [r13*2+1]
    SPH eax, ebx, 12, 4
    RETURN

; =====================================================================
;  low density
; =====================================================================

; ---- Old Town: brownstone rows with stoops and cornices
FUNC rl_oldtown, 32
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+5000]
    BEGIN 16, 30, eax
    ; 1..3 houses, 2..4 storeys
    mov ebx, 1
    cmp r12d, 2
    jl .n
    mov ebx, 2
    cmp r12d, 4
    jl .n
    mov ebx, 3
.n:
    mov [rbp-48], ebx
    mov edi, r12d
    mov esi, 2
    call storeys_for
    imul eax, eax, 5
    mov [rbp-52], eax               ; wall height
    ; house width
    mov eax, 14
    xor edx, edx
    div ebx
    mov [rbp-56], eax               ; w
    mov r14d, 1                     ; x0
    cmp ebx, 1
    jne .h0
    mov dword [rbp-56], 8
    mov r14d, 4
.h0:
    xor r15d, r15d
.h:
    PICK brown_mats, 4
    mov [vox_mat], eax
    mov eax, r14d
    add eax, [rbp-56]
    mov [rbp-60], eax               ; x1
    BOX r14d, 3, 0, [rbp-60], 12, [rbp-52]
    ; flat tar roof, and a cornice overhanging the street side
    MAT M_ROOF_GREY
    mov eax, [rbp-52]
    mov [rbp-64], eax
    inc eax
    mov [rbp-68], eax
    BOX r14d, 3, [rbp-64], [rbp-60], 12, [rbp-68]
    MAT M_CREAM
    mov eax, [rbp-52]
    dec eax
    mov [rbp-64], eax
    BOX r14d, 12, [rbp-64], [rbp-60], 13, [rbp-68]
    ; stoop and door
    MAT M_CREAM
    lea eax, [r14+1]
    mov [rbp-72], eax
    lea eax, [r14+3]
    mov [rbp-76], eax
    BOX [rbp-72], 12, 0, [rbp-76], 15, 1
    BOX [rbp-72], 12, 1, [rbp-76], 14, 2
    MAT M_DARK
    BOX [rbp-72], 12, 2, [rbp-76], 13, 6
    add r14d, [rbp-56]
    inc r15d
    cmp r15d, [rbp-48]
    jl .h
    ; a street tree in front
    cmp r12d, 2
    jl .out
    mov edi, 14
    mov esi, 14
    call street_tree
.out:
    call finish_model
    RETURN

; ---- Garden: gabled house, picket fence, yard, garage, pool
FUNC rl_garden, 32
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+5100]
    BEGIN 16, 26, eax
    mov edi, r12d
    mov esi, 1
    call storeys_for
    cmp eax, 3
    jl .s
    mov eax, 2
.s:
    imul eax, eax, 6
    mov [rbp-48], eax               ; wall height
    PICK siding_mats, 6
    mov [vox_mat], eax
    BOX 3, 3, 0, 11, 10, [rbp-48]
    PICK sty_roofs, 5
    mov [vox_mat], eax
    RFX 2, 2, [rbp-48], 12, 11, 5
    ; door and a path
    MAT M_DARK
    BOX 6, 10, 0, 8, 11, 4
    MAT M_CONCRETE
    BOX 6, 11, 0, 8, 16, 1
    ; chimney
    MAT M_BRICK
    mov eax, [rbp-48]
    add eax, 6
    mov [rbp-52], eax
    BOX 9, 4, [rbp-48], 10, 5, [rbp-52]
    ; picket fence along the street
    MAT M_WHITE
    BOX 0, 15, 1, 6, 16, 2
    BOX 8, 15, 1, 16, 16, 2
    xor ebx, ebx
.f:
    cmp ebx, 16
    jge .fd
    cmp ebx, 6
    je .fn
    lea eax, [rbx+1]
    mov [rbp-56], eax
    BOX ebx, 15, 0, [rbp-56], 16, 3
.fn:
    add ebx, 2
    jmp .f
.fd:
    ; garage and driveway for bigger lots
    cmp r12d, 3
    jl .t
    MAT M_WHITE
    BOX 11, 5, 0, 15, 10, 5
    MAT M_ROOF_GREY
    BOX 11, 5, 5, 15, 10, 6
    MAT M_ASPHALT
    BOX 11, 10, 0, 15, 15, 1
.t:
    mov edi, 1
    mov esi, 12
    call street_tree
    ; the big ones get a pool out back
    cmp r12d, 5
    jl .out
    MAT M_WHITE
    BOX 0, 0, 0, 7, 3, 1
    MAT M_WATER
    BOX 1, 0, 0, 6, 2, 1
.out:
    call finish_model
    RETURN

; ---- Shore: pastel beach house on stilts with a deck
FUNC rl_shore, 32
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+5200]
    BEGIN 16, 26, eax
    mov edi, r12d
    mov esi, 1
    call storeys_for
    cmp eax, 3
    jl .s
    mov eax, 2
.s:
    imul eax, eax, 6
    add eax, 4
    mov [rbp-48], eax               ; top of the walls
    ; pilings and deck
    MAT M_WOOD
    BOX 3, 3, 0, 4, 4, 3
    BOX 11, 3, 0, 12, 4, 3
    BOX 3, 11, 0, 4, 12, 3
    BOX 11, 11, 0, 12, 12, 3
    MAT M_DECK
    BOX 2, 2, 3, 14, 14, 4
    ; railing
    MAT M_WHITE
    BOX 2, 13, 4, 14, 14, 5
    BOX 13, 2, 4, 14, 14, 5
    ; steps down to the sand
    MAT M_DECK
    BOX 13, 14, 2, 15, 15, 3
    BOX 13, 15, 1, 15, 16, 2
    ; the house
    PICK beach_mats, 6
    mov [vox_mat], eax
    BOX 4, 4, 4, 11, 10, [rbp-48]
    PICK beach_roofs, 4
    mov [vox_mat], eax
    PYR 3, 3, [rbp-48], 12, 11, 4
    ; a parasol on the deck
    MAT M_WHITE
    CYL 25, 25, 4, 1, 9
    PICK store_awns, 3
    mov [vox_mat], eax
    CONE 25, 25, 8, 6, 3
    ; roof deck for the largest
    cmp r12d, 5
    jl .out
    MAT M_DECK
    mov eax, [rbp-48]
    mov [rbp-52], eax
    add eax, 1
    mov [rbp-56], eax
    BOX 5, 5, [rbp-52], 10, 9, [rbp-56]
.out:
    call finish_model
    RETURN

; ---- Worker: a row of small clapboard cottages with chimneys
FUNC rl_worker, 32
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+5300]
    BEGIN 16, 22, eax
    mov ebx, 2
    mov dword [rbp-52], 6           ; width
    mov r14d, 2                     ; x0
    cmp r12d, 3
    jl .n
    mov ebx, 3
    mov dword [rbp-52], 5
    mov r14d, 1
.n:
    mov [rbp-48], ebx
    mov eax, 5
    cmp r12d, 4
    jl .hh
    mov eax, 9
.hh:
    mov [rbp-56], eax               ; wall height
    PICK worker_roofs, 3
    mov [rbp-60], eax
    xor r15d, r15d
.h:
    PICK worker_mats, 4
    mov [vox_mat], eax
    mov eax, r14d
    add eax, [rbp-52]
    dec eax
    mov [rbp-64], eax               ; x1 (a gap between cottages)
    BOX r14d, 4, 0, [rbp-64], 11, [rbp-56]
    mov eax, [rbp-60]
    mov [vox_mat], eax
    RFY r14d, 3, [rbp-56], [rbp-64], 12, 3
    MAT M_DARK
    lea eax, [r14+1]
    mov [rbp-68], eax
    lea eax, [r14+2]
    mov [rbp-72], eax
    BOX [rbp-68], 11, 0, [rbp-72], 12, 4
    ; chimney
    MAT M_BRICK
    mov eax, [rbp-56]
    add eax, 4
    mov [rbp-76], eax
    BOX [rbp-68], 6, [rbp-56], [rbp-72], 7, [rbp-76]
    ; low front fence
    MAT M_WOOD
    BOX r14d, 14, 0, [rbp-64], 15, 1
    add r14d, [rbp-52]
    inc r15d
    cmp r15d, [rbp-48]
    jl .h
    call finish_model
    RETURN

; ---- Uptown: painted-lady victorian with a turret and porch
FUNC rl_uptown, 32
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+5400]
    BEGIN 16, 34, eax
    mov edi, r12d
    mov esi, 2
    call storeys_for
    cmp eax, 3
    jle .s
    mov eax, 3
.s:
    imul eax, eax, 5
    mov [rbp-48], eax               ; wall height
    PICK victor_mats, 6
    mov [vox_mat], eax
    mov [rbp-52], eax
    BOX 3, 3, 0, 12, 11, [rbp-48]
    ; white trim at every floor
    MAT M_WHITE
    mov ebx, 5
.tr:
    cmp ebx, [rbp-48]
    jge .trd
    lea eax, [rbx+1]
    mov [rbp-56], eax
    BOX 3, 3, ebx, 12, 11, [rbp-56]
    add ebx, 5
    jmp .tr
.trd:
    ; steep slate roof
    MAT M_ROOF_SLATE
    RFX 2, 2, [rbp-48], 13, 12, 7
    ; corner turret with a witch's-hat roof
    mov eax, [rbp-52]
    mov [vox_mat], eax
    mov eax, [rbp-48]
    add eax, 3
    mov [rbp-60], eax
    CYL 24, 22, 0, 5, [rbp-60]
    MAT M_ROOF_SLATE
    CONE 24, 22, [rbp-60], 6, 7
    ; porch with columns
    MAT M_WHITE
    BOX 3, 11, 0, 11, 14, 1
    BOX 3, 13, 1, 4, 14, 5
    BOX 7, 13, 1, 8, 14, 5
    BOX 10, 13, 1, 11, 14, 5
    BOX 3, 11, 5, 11, 14, 6
    MAT M_DARK
    BOX 6, 11, 1, 7, 12, 5
    ; hedges for the grand ones
    cmp r12d, 4
    jl .out
    MAT M_LEAF
    BOX 0, 15, 0, 16, 16, 2
    BOX 0, 0, 0, 1, 15, 2
.out:
    call finish_model
    RETURN

; ---- Modern: white box, timber cantilever, glass, solar, pool
FUNC rl_modern, 32
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+5500]
    BEGIN 16, 20, eax
    MAT M_WHITE
    BOX 2, 3, 0, 11, 11, 6
    MAT M_GLASS
    BOX 3, 10, 1, 10, 11, 5
    BOX 10, 4, 1, 11, 10, 5
    MAT M_ROOF_GREY
    BOX 2, 3, 6, 11, 11, 7
    cmp r12d, 3
    jl .one
    ; timber-clad upper floor sliding out over the garden
    MAT M_CLADDING
    BOX 5, 2, 7, 15, 9, 12
    MAT M_GLASS
    BOX 14, 3, 8, 15, 8, 11
    BOX 6, 8, 8, 14, 9, 11
    MAT M_ROOF_GREY
    BOX 5, 2, 12, 15, 9, 13
    MAT M_SOLAR
    BOX 7, 3, 13, 13, 7, 14
    jmp .yard
.one:
    MAT M_SOLAR
    BOX 4, 4, 7, 9, 8, 8
.yard:
    ; a pool and deck for the bigger lots
    cmp r12d, 4
    jl .tree
    MAT M_DECK
    BOX 2, 12, 0, 15, 16, 1
    MAT M_WATER
    BOX 4, 13, 0, 13, 15, 1
.tree:
    mov edi, 1
    mov esi, 1
    call street_tree
    call finish_model
    RETURN

; =====================================================================
;  high density
; =====================================================================

; ---- Old Town: brick tenement, shopfront, fire escapes, water tower
FUNC rh_oldtown, 32
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+5600]
    BEGIN 16, 60, eax
    lea eax, [r12+4]
    shl eax, 2                      ; 5..9 storeys of 4
    movzx ecx, byte [var_storey+r13]
    movsx ecx, cl
    add eax, ecx
    mov [rbp-48], eax
    PICK tenement_mats, 4
    mov [vox_mat], eax
    BOX 2, 2, 0, 14, 13, [rbp-48]
    ; ground-floor shop with an awning
    MAT M_DARK
    BOX 3, 13, 0, 13, 14, 3
    PICK store_awns, 3
    mov [vox_mat], eax
    BOX 3, 13, 3, 13, 15, 4
    ; cornice
    MAT M_CREAM
    mov eax, [rbp-48]
    mov [rbp-52], eax
    inc eax
    mov [rbp-56], eax
    BOX 1, 1, [rbp-52], 15, 14, [rbp-56]
    ; fire escapes zig-zagging down the side
    MAT M_DARK
    mov ebx, 5
.fe:
    cmp ebx, [rbp-48]
    jge .fed
    lea eax, [rbx+1]
    mov [rbp-60], eax
    BOX 14, 4, ebx, 15, 11, [rbp-60]
    add ebx, 4
    jmp .fe
.fed:
    mov eax, [rbp-48]
    mov [rbp-60], eax
    BOX 14, 4, 5, 15, 5, [rbp-60]
    ; rooftop stair bulkhead and (mostly) the wooden water tower
    cmp r13d, 2
    je .notower
    MAT M_BRICK
    mov eax, [rbp-56]
    add eax, 3
    mov [rbp-64], eax
    BOX 3, 3, [rbp-56], 6, 6, [rbp-64]
    MAT M_DARK
    mov eax, [rbp-56]
    add eax, 3
    mov [rbp-68], eax
    BOX 9, 8, [rbp-56], 10, 9, [rbp-68]
    BOX 12, 8, [rbp-56], 13, 9, [rbp-68]
    BOX 9, 11, [rbp-56], 10, 12, [rbp-68]
    BOX 12, 11, [rbp-56], 13, 12, [rbp-68]
    MAT M_WOOD
    mov eax, [rbp-68]
    add eax, 6
    mov [rbp-72], eax
    CYL 22, 20, [rbp-68], 5, [rbp-72]
    MAT M_ROOF_GREY
    CONE 22, 20, [rbp-72], 6, 3
.notower:
    call finish_model
    RETURN

; ---- Garden: terraces with balconies, planters and a roof garden
FUNC rh_garden, 32
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+5700]
    BEGIN 16, 44, eax
    lea eax, [r12+2]
    shl eax, 2                      ; 3..7 storeys
    movzx ecx, byte [var_storey+r13]
    movsx ecx, cl
    add eax, ecx
    mov [rbp-48], eax
    PICK terrace_mats, 5
    mov [vox_mat], eax
    BOX 2, 2, 0, 14, 12, [rbp-48]
    ; balconies with planters every floor
    mov ebx, 4
.b:
    cmp ebx, [rbp-48]
    jge .bd
    MAT M_WHITE
    lea eax, [rbx+1]
    mov [rbp-52], eax
    BOX 2, 12, ebx, 14, 14, [rbp-52]
    MAT M_LEAF
    lea eax, [rbx+2]
    mov [rbp-56], eax
    BOX 3, 13, [rbp-52], 5, 14, [rbp-56]
    BOX 8, 13, [rbp-52], 10, 14, [rbp-56]
    BOX 12, 13, [rbp-52], 13, 14, [rbp-56]
    add ebx, 4
    jmp .b
.bd:
    ; roof garden with two trees
    MAT M_GRASS
    mov eax, [rbp-48]
    mov [rbp-52], eax
    inc eax
    mov [rbp-56], eax
    BOX 2, 2, [rbp-52], 14, 12, [rbp-56]
    MAT M_LEAF
    mov eax, [rbp-56]
    lea eax, [rax*2+4]
    mov [rbp-60], eax
    SPH 10, 10, [rbp-60], 5
    SPH 20, 14, [rbp-60], 4
    ; a courtyard tree in front
    mov edi, 14
    mov esi, 14
    call street_tree
    call finish_model
    RETURN

; ---- Shore: glass condo tower ringed with balconies
FUNC rh_shore, 32
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+5800]
    BEGIN 16, 72, eax
    lea eax, [r12*8+16]             ; 24..56
    movzx ecx, byte [var_storey+r13]
    movsx ecx, cl
    lea eax, [rax+rcx*2]
    mov [rbp-48], eax
    ; podium
    MAT M_WHITE
    BOX 1, 1, 0, 15, 15, 3
    PICK condo_mats, 3
    mov [vox_mat], eax
    BOX 3, 3, 3, 13, 13, [rbp-48]
    ; balcony rims
    MAT M_WHITE
    mov ebx, 6
.r:
    cmp ebx, [rbp-48]
    jge .rd
    lea eax, [rbx+1]
    mov [rbp-52], eax
    BOX 2, 2, ebx, 14, 14, [rbp-52]
    add ebx, 4
    jmp .r
.rd:
    ; penthouse and (for the best) a rooftop pool
    mov eax, [rbp-48]
    mov [rbp-52], eax
    add eax, 4
    mov [rbp-56], eax
    MAT M_WHITE
    BOX 5, 3, [rbp-52], 11, 8, [rbp-56]
    cmp r12d, 4
    jl .out
    MAT M_WATER
    mov eax, [rbp-52]
    inc eax
    mov [rbp-60], eax
    BOX 4, 9, [rbp-52], 12, 12, [rbp-60]
.out:
    call finish_model
    RETURN

; ---- Worker: concrete (or brick) housing project, tower-in-the-park
FUNC rh_worker, 32
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+5900]
    BEGIN 16, 60, eax
    imul eax, r12d, 6
    add eax, 20                     ; 26..50
    movzx ecx, byte [var_storey+r13]
    movsx ecx, cl
    lea eax, [rax+rcx*2]
    mov [rbp-48], eax
    PICK project_mats, 3
    mov [vox_mat], eax
    mov [rbp-52], eax
    BOX 1, 5, 0, 15, 11, [rbp-48]
    cmp r12d, 3
    jl .roof
    ; the cross-shaped tower
    mov eax, [rbp-48]
    sub eax, 8
    mov [rbp-56], eax
    BOX 5, 1, 0, 11, 15, [rbp-56]
.roof:
    MAT M_METAL
    mov eax, [rbp-48]
    mov [rbp-60], eax
    add eax, 3
    mov [rbp-64], eax
    BOX 3, 6, [rbp-60], 6, 9, [rbp-64]
    BOX 10, 6, [rbp-60], 13, 9, [rbp-64]
    ; a lamp post and a bench out front
    MAT M_DARK
    BOX 14, 14, 0, 15, 15, 6
    MAT M_LAMP
    BOX 14, 14, 6, 15, 15, 7
    MAT M_WOOD
    BOX 1, 13, 0, 4, 14, 1
    call finish_model
    RETURN

; ---- Uptown: art-deco tower with setbacks, gold crown and spire
FUNC rh_uptown, 48
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+6000]
    BEGIN 16, 110, eax
    imul eax, r12d, 14
    add eax, 30                     ; 44..100
    movzx ecx, byte [var_storey+r13]
    movsx ecx, cl
    lea eax, [rax+rcx*2]
    mov [rbp-48], eax               ; total
    ; tier heights at ~45 %, 70 %, 85 %
    imul ecx, eax, 45
    mov eax, ecx
    xor edx, edx
    mov ecx, 100
    div ecx
    mov [rbp-52], eax
    mov eax, [rbp-48]
    imul eax, eax, 70
    xor edx, edx
    div ecx
    mov [rbp-56], eax
    mov eax, [rbp-48]
    imul eax, eax, 85
    xor edx, edx
    div ecx
    mov [rbp-60], eax
    PICK deco_mats, 3
    mov [vox_mat], eax
    BOX 1, 1, 0, 15, 15, [rbp-52]
    BOX 3, 3, [rbp-52], 13, 13, [rbp-56]
    BOX 5, 5, [rbp-56], 11, 11, [rbp-60]
    ; limestone piers up the corners of the lower tiers
    MAT M_DECO
    BOX 1, 1, 0, 2, 2, [rbp-52]
    BOX 14, 1, 0, 15, 2, [rbp-52]
    BOX 1, 14, 0, 2, 15, [rbp-52]
    BOX 14, 14, 0, 15, 15, [rbp-52]
    BOX 3, 12, [rbp-52], 4, 13, [rbp-56]
    BOX 12, 12, [rbp-52], 13, 13, [rbp-56]
    ; gold band over the entrance, gold crown
    MAT M_GOLD
    BOX 1, 14, 4, 15, 15, 5
    mov eax, [rbp-60]
    add eax, 4
    mov [rbp-64], eax
    BOX 6, 6, [rbp-60], 10, 10, [rbp-64]
    ; spire for the grandest, a stepped cap otherwise
    cmp r12d, 4
    jl .cap
    mov eax, [rbp-48]
    sub eax, [rbp-64]
    add eax, 6
    mov [rbp-68], eax
    CONE 16, 16, [rbp-64], 3, [rbp-68]
    jmp .out
.cap:
    PYR 6, 6, [rbp-64], 10, 10, 3
.out:
    call finish_model
    RETURN

; ---- Modern: glass tower with white fins and a sloped crown
FUNC rh_modern, 32
    mov r12d, edi
    mov r13d, esi
    lea eax, [r12*4+r13+6100]
    BEGIN 16, 112, eax
    imul eax, r12d, 12
    add eax, 34                     ; 46..94
    movzx ecx, byte [var_storey+r13]
    movsx ecx, cl
    lea eax, [rax+rcx*2]
    mov [rbp-48], eax
    PICK tower_mats, 3
    mov [vox_mat], eax
    mov [rbp-52], eax
    BOX 3, 3, 0, 13, 13, [rbp-48]
    ; white fins at the corners
    MAT M_WHITE
    BOX 3, 3, 0, 4, 4, [rbp-48]
    BOX 12, 3, 0, 13, 4, [rbp-48]
    BOX 3, 12, 0, 4, 13, [rbp-48]
    BOX 12, 12, 0, 13, 13, [rbp-48]
    ; lobby
    MAT M_BRIGHT
    BOX 2, 2, 0, 14, 14, 3
    ; the crown: a sloped glass roof and an antenna with a beacon
    mov eax, [rbp-52]
    mov [vox_mat], eax
    RFX 3, 3, [rbp-48], 13, 13, 6
    MAT M_METAL
    mov eax, [rbp-48]
    add eax, 4
    mov [rbp-56], eax
    add eax, 8
    mov [rbp-60], eax
    CYL 16, 16, [rbp-56], 1, [rbp-60]
    MAT M_BEACON
    mov eax, [rbp-60]
    mov [rbp-64], eax
    inc eax
    mov [rbp-68], eax
    BOX 7, 7, [rbp-64], 9, 9, [rbp-68]
    call finish_model
    RETURN

; =====================================================================
;  build every style x level x variant
; =====================================================================
N_STYLES     equ 7          ; 0 = classic (the older model pool)
section .bss
spr_style    resd 2*6*5*4   ; (low/high) x style 1..6 x level x 4 variants
section .data
style_gens   dq rl_oldtown, rl_garden, rl_shore, rl_worker, rl_uptown, rl_modern
             dq rh_oldtown, rh_garden, rh_shore, rh_worker, rh_uptown, rh_modern
section .text

FUNC gen_styles
    xor r12d, r12d                  ; generator 0..11
.g:
    mov r13d, 1                     ; level
.l:
    xor r14d, r14d                  ; variant
.v:
    mov edi, r13d
    mov esi, r14d
    call [style_gens+r12*8]
    ; index = ((gen*5) + level-1)*4 + variant
    imul ecx, r12d, 5
    lea ecx, [rcx+r13-1]
    lea ecx, [rcx*4+r14]
    mov [spr_style+rcx*4], eax
    inc r14d
    cmp r14d, 4
    jl .v
    inc r13d
    cmp r13d, 6
    jl .l
    inc r12d
    cmp r12d, 12
    jl .g
    RETURN
