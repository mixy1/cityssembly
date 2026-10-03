; =====================================================================
;  SOUL (beta) - the city shows its wear
;
;  City builders are too clean: every tile a perfect square of lawn,
;  every house a copy of its neighbour, and a problem only shows in a
;  stats panel.  This pass lets the landscape speak for itself:
;    - grass without the tile grid, with worn patches, clover, stones,
;      flowers and dry spots picked by a stable hash of the tile
;    - homes get a yard: laundry, a shed, bins, a paddling pool, a
;      vegetable patch, a woodpile; small industry gets barrels and
;      pallets
;    - a building with garbage piling up, crime at the door, unhappy
;      people, or old age on cheap land is drawn worn: a shade darker,
;      streaked walls, half the windows dark, weeds in the yard, litter
;      around it; an abandoned one is derelict
;    - busy streets wear: patched asphalt and potholes
;    - a demolished building leaves its foundation for a couple of
;      years, and the weeds take it back
;    - autumn leaves gather on the grass under the trees
;  Everything is decided at draw time from the tile record and the
;  coverage maps; only the foundations need state (map_trace, saved as
;  the TRCE chunk).  Classic mode draws nothing of this.
; =====================================================================

TRACE_MONTHS equ 30                 ; a foundation shows this long
TRACE_FRESH  equ 14                 ; ... concrete until this many are left

section .bss
prop_sx         resd 1              ; where the props of this building go
prop_sy         resd 1
prop_depth      resd 1
prop_remap      resq 1
spr_turf        resd 8              ; grass without the grid line
spr_litter      resd 2
spr_heap        resd 1
spr_weeds       resd 2
spr_wear        resd 2              ; patched asphalt, a pothole
spr_leaves      resd 2
spr_trace       resd 2              ; a fresh foundation, an overgrown one
spr_yard        resd 6
spr_indprop     resd 2
spr_grime       resd MAX_SPRITES    ; sprite -> its worn twin (0: none)
map_trace       resb MAP_TILES      ; months a demolished building's foundation shows

section .data
; which turf a tile gets from 4 bits of its hash: plain most often
turf_pick   db 0,1,0,1,0,1,2,3, 0,1,4,5,0,1,6,7
s_cond      db "Condition: ", 0
s_c_fine    db "well kept", 0
s_c_derelict db "derelict", 0
s_c_worn    db "worn - ", 0
s_c_garbage db "garbage piling up", 0
s_c_unhappy db "nobody likes it here", 0
s_c_crime   db "crime at the door", 0
s_c_old     db "old, on cheap land", 0
pf_soul     db "PLAY soul kept %d worn %d derelict %d | garbage %d unhappy %d crime %d old %d", 10, 0

section .text

; ---------------------------------------------------------------------
;  scatter(edi count, esi lo, edx span, ecx height): columns of the
;  current material at random spots in [lo, lo+span)^2, from the ground
; ---------------------------------------------------------------------
FUNC scatter
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
.l:
    mov edi, r14d
    call rand_range
    lea ebx, [r13+rax]              ; x
    mov edi, r14d
    call rand_range
    add eax, r13d                   ; y
    mov edi, ebx
    mov esi, eax
    xor edx, edx
    lea ecx, [rbx+1]
    lea r8d, [rax+1]
    mov r9d, r15d
    call vbox
    dec r12d
    jnz .l
    RETURN

; a random spot in [lo, lo+span): (edi span, esi lo) -> eax
spot:
    push rsi
    call rand_range
    pop rsi
    add eax, esi
    ret

; =====================================================================
;  ground: grass without the grid, decals that lie flat on a tile
; =====================================================================
FUNC gen_turf                       ; edi variant 0..7
    mov r12d, edi
    lea eax, [r12+9000]
    BEGIN 16, 2, eax
    mov dword [vox_noline], 1
    MAT M_GRASS
    BOX 0,0,0,16,16,1
    cmp r12d, 2
    je .clover
    cmp r12d, 3
    je .worn
    cmp r12d, 4
    je .flowers
    cmp r12d, 5
    je .stones
    cmp r12d, 6
    je .bumps
    cmp r12d, 7
    je .dry
    ; plain: a few tufts
    MAT M_LEAF
    mov edi, 4
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    jmp .d
.clover:
    MAT M_LEAF
    mov edi, 9
    mov esi, 2
    call spot
    mov r13d, eax
    mov edi, 9
    mov esi, 2
    call spot
    mov r14d, eax
    lea ecx, [r13+3]
    lea r8d, [r14+2]
    mov edi, r13d
    mov esi, r14d
    xor edx, edx
    mov r9d, 1
    call vbox
    mov edi, 4
    lea esi, [r13-2]
    mov edx, 7
    mov ecx, 1
    call scatter
    MAT M_LEAF2
    mov edi, 1
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    jmp .d
.worn:
    MAT M_DIRT
    mov edi, 9
    mov esi, 2
    call spot
    mov r13d, eax
    mov edi, 9
    mov esi, 2
    call spot
    mov r14d, eax
    lea ecx, [r13+4]
    lea r8d, [r14+3]
    mov edi, r13d
    mov esi, r14d
    xor edx, edx
    mov r9d, 1
    call vbox
    mov edi, 3
    lea esi, [r13-1]
    mov edx, 6
    mov ecx, 1
    call scatter
    MAT M_LEAF
    mov edi, 2
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    jmp .d
.flowers:
    MAT M_LEAF
    mov edi, 3
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    MAT M_YELLOW
    mov edi, 2
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    MAT M_WHITE
    mov edi, 2
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    jmp .d
.stones:
    MAT M_CONCRETE
    mov edi, 3
    mov esi, 2
    mov edx, 12
    mov ecx, 1
    call scatter
    MAT M_LEAF
    mov edi, 3
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    jmp .d
.bumps:                             ; (mixed greens)
    MAT M_LEAF
    mov edi, 3
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    MAT M_LEAF2
    mov edi, 3
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    jmp .d
.dry:
    MAT M_OLIVE
    mov edi, 8
    mov esi, 2
    call spot
    mov r13d, eax
    mov edi, 8
    mov esi, 2
    call spot
    mov r14d, eax
    lea ecx, [r13+5]
    lea r8d, [r14+3]
    mov edi, r13d
    mov esi, r14d
    xor edx, edx
    mov r9d, 1
    call vbox
    MAT M_LEAF
    mov edi, 2
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
.d:
    call finish_model
    mov dword [vox_noline], 0
    RETURN

FUNC gen_litter                     ; edi variant
    mov r12d, edi
    lea eax, [r12+9100]
    BEGIN 16, 2, eax
    mov dword [vox_noline], 1
    MAT M_WHITE
    mov edi, 3
    mov esi, 1
    mov edx, 14
    mov ecx, 1
    call scatter
    MAT M_CONCRETE
    mov edi, 2
    mov esi, 1
    mov edx, 14
    mov ecx, 1
    call scatter
    MAT M_RED
    mov edi, 1
    mov esi, 1
    mov edx, 14
    mov ecx, 1
    call scatter
    MAT M_YELLOW
    mov edi, 1
    mov esi, 1
    mov edx, 14
    mov ecx, 1
    call scatter
    MAT M_DARK
    mov edi, 1
    mov esi, 1
    mov edx, 14
    mov ecx, 2
    call scatter
    call finish_model
    mov dword [vox_noline], 0
    RETURN

FUNC gen_heap                       ; bags of garbage at the front corner
    BEGIN 16, 4, 9120
    MAT M_DARK
    BOX 11,11,0,13,13,2
    BOX 13,12,0,15,14,1
    MAT M_OLIVE
    BOX 12,13,0,14,15,2
    MAT M_DARK
    BOX 14,10,0,15,11,1
    MAT M_WHITE
    BOX 10,13,0,11,14,1
    BOX 14,15,0,15,16,1
    MAT M_CONCRETE
    BOX 12,10,0,13,11,1
    call finish_model
    RETURN

FUNC gen_weeds                      ; edi variant
    mov r12d, edi
    lea eax, [r12+9130]
    BEGIN 16, 3, eax
    mov dword [vox_noline], 1
    MAT M_OLIVE
    mov edi, 5
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    mov edi, 3
    xor esi, esi
    mov edx, 16
    mov ecx, 2
    call scatter
    MAT M_LEAF2
    mov edi, 3
    xor esi, esi
    mov edx, 16
    mov ecx, 2
    call scatter
    MAT M_DIRT
    mov edi, 3
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    call finish_model
    mov dword [vox_noline], 0
    RETURN

FUNC gen_wear                       ; edi 0 patched asphalt, 1 pothole
    mov r12d, edi
    lea eax, [r12+9140]
    BEGIN 16, 2, eax
    mov dword [vox_noline], 1
    mov edi, 7
    mov esi, 3
    call spot
    mov r13d, eax
    mov edi, 7
    mov esi, 3
    call spot
    mov r14d, eax
    MAT M_DARK
    test r12d, r12d
    jnz .hole
    lea ecx, [r13+4]
    lea r8d, [r14+3]
    mov edi, r13d
    mov esi, r14d
    xor edx, edx
    mov r9d, 1
    call vbox
    ; a crack running off the patch
    mov ebx, 4
.c:
    lea edi, [r13+rbx+3]
    lea esi, [r14+rbx+2]
    xor edx, edx
    call vset
    dec ebx
    jnz .c
    jmp .d
.hole:
    lea ecx, [r13+3]
    lea r8d, [r14+2]
    mov edi, r13d
    mov esi, r14d
    xor edx, edx
    mov r9d, 1
    call vbox
    MAT M_CONCRETE
    lea edi, [r13-1]
    mov esi, r14d
    xor edx, edx
    call vset
    lea edi, [r13+3]
    lea esi, [r14+1]
    xor edx, edx
    call vset
    MAT M_DIRT
    lea edi, [r13+1]
    lea esi, [r14+2]
    xor edx, edx
    call vset
.d:
    call finish_model
    mov dword [vox_noline], 0
    RETURN

FUNC gen_leaves                     ; edi variant
    mov r12d, edi
    lea eax, [r12+9150]
    BEGIN 16, 2, eax
    mov dword [vox_noline], 1
    MAT M_LEAF2
    mov edi, 7
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    MAT M_WOOD
    mov edi, 3
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    MAT M_ORANGE
    mov edi, 2
    xor esi, esi
    mov edx, 16
    mov ecx, 1
    call scatter
    call finish_model
    mov dword [vox_noline], 0
    RETURN

FUNC gen_trace                      ; edi 0 fresh foundation, 1 overgrown
    mov r12d, edi
    lea eax, [r12+9160]
    BEGIN 16, 3, eax
    mov dword [vox_noline], 1
    test r12d, r12d
    jnz .old
    MAT M_DIRT
    BOX 2,2,0,14,14,1
    MAT M_CONCRETE
    BOX 2,2,0,14,3,1
    BOX 2,13,0,14,14,1
    BOX 2,2,0,3,14,1
    BOX 13,2,0,14,14,1
    mov edi, 4
    mov esi, 3
    mov edx, 10
    mov ecx, 1
    call scatter
    jmp .d
.old:
    MAT M_DIRT
    mov edi, 10
    mov esi, 2
    mov edx, 12
    mov ecx, 1
    call scatter
    MAT M_CONCRETE
    BOX 2,2,0,3,3,1
    BOX 13,2,0,14,3,1
    BOX 2,13,0,3,14,1
    BOX 13,13,0,14,14,1
    MAT M_OLIVE
    mov edi, 4
    mov esi, 2
    mov edx, 12
    mov ecx, 1
    call scatter
    mov edi, 2
    mov esi, 2
    mov edx, 12
    mov ecx, 2
    call scatter
.d:
    call finish_model
    mov dword [vox_noline], 0
    RETURN

; =====================================================================
;  props: what people leave in their yards
; =====================================================================
FUNC gen_yard                       ; edi 0..5
    mov r12d, edi
    lea eax, [r12+9170]
    BEGIN 16, 8, eax
    cmp r12d, 1
    je .shed
    cmp r12d, 2
    je .bins
    cmp r12d, 3
    je .pool
    cmp r12d, 4
    je .veg
    cmp r12d, 5
    je .wood
    ; laundry on a line between two posts
    MAT M_WOOD
    BOX 14,2,0,15,3,6
    BOX 14,9,0,15,10,6
    MAT M_DARK
    BOX 14,3,4,15,9,5
    MAT M_RED
    BOX 13,3,2,15,4,4
    MAT M_WHITE
    BOX 13,5,2,15,6,4
    MAT M_BLUE
    BOX 13,7,2,15,8,4
    jmp .d
.shed:
    MAT M_WOOD
    BOX 12,0,0,16,4,3
    MAT M_ROOF_GREY
    BOX 12,0,3,16,4,4
    MAT M_DARK
    BOX 13,3,0,14,4,2
    jmp .d
.bins:
    MAT M_CONCRETE
    CYL 29,27,0,2,3
    MAT M_TEAL
    CYL 29,21,0,2,3
    MAT M_DARK
    BOX 14,13,3,15,14,4
    BOX 14,10,3,15,11,4
    jmp .d
.pool:
    MAT M_WHITE
    BOX 1,1,0,6,6,1
    MAT M_BLUE
    BOX 2,2,0,5,5,1
    MAT M_RED
    BOX 7,2,0,8,3,1
    MAT M_YELLOW
    BOX 2,7,0,3,8,1
    BOX 7,4,0,8,5,2
    jmp .d
.veg:
    MAT M_DIRT
    BOX 0,0,0,5,9,1
    MAT M_LEAF
    BOX 1,1,0,2,2,2
    BOX 1,4,0,2,5,2
    BOX 1,7,0,2,8,2
    BOX 3,1,0,4,2,2
    BOX 3,4,0,4,5,2
    BOX 3,7,0,4,8,2
    jmp .d
.wood:
    MAT M_WOOD
    BOX 12,12,0,16,15,2
    MAT M_TRUNK
    CYL 5,25,0,3,2
    MAT M_LEAF
    BOX 1,15,0,2,16,1
.d:
    call finish_model
    RETURN

FUNC gen_indprop                    ; edi 0 barrels, 1 pallets
    mov r12d, edi
    lea eax, [r12+9180]
    BEGIN 16, 8, eax
    test r12d, r12d
    jnz .pallets
    MAT M_RUST
    CYL 13,3,0,2,3
    CYL 17,3,0,2,3
    MAT M_METAL
    CYL 15,7,0,2,3
    MAT M_DARK
    BOX 9,0,0,10,1,1
    jmp .d
.pallets:
    MAT M_WOOD
    BOX 5,0,0,9,4,1
    BOX 5,0,1,9,4,2
    MAT M_CONCRETE
    BOX 6,1,2,8,3,4
    MAT M_WOOD
    BOX 10,0,0,14,3,1
.d:
    call finish_model
    RETURN

; ---------------------------------------------------------------------
;  sprite_twin(edi id) -> eax: a worn copy of a baked sprite - a shade
;  darker, streaks running down the walls, half the windows dark
; ---------------------------------------------------------------------
FUNC sprite_twin, 16
    mov eax, edi
    mov [rbp-48], eax               ; source id (salts the hashes)
    shl eax, 4
    lea r12, [spr_table+rax]
    movzx r13d, word [r12]          ; w
    movzx r14d, word [r12+2]        ; h
    mov edi, r13d
    mov esi, r14d
    call sprite_new
    mov r15d, eax
    mov rdi, rdx
    mov eax, [r12+8]
    lea rsi, [arena+rax]
    mov eax, r13d
    imul eax, r14d
    lea ecx, [rax+rax*2]            ; colour, depth and height planes
    rep movsb
    mov eax, r15d
    shl eax, 4
    lea rbx, [spr_table+rax]
    mov eax, [r12+4]                ; anchor
    mov [rbx+4], eax
    mov eax, [r12+12]               ; shared height map (same shape)
    mov [rbx+12], eax
    mov eax, [rbx+8]
    lea rbx, [arena+rax]            ; colour plane of the twin
    xor r8d, r8d                    ; y
.y:
    cmp r8d, r14d
    jge .out
    xor r9d, r9d                    ; x
.x:
    cmp r9d, r13d
    jge .yn
    mov eax, r8d
    imul eax, r13d
    add eax, r9d
    movzx ecx, byte [rbx+rax]
    test ecx, ecx
    jz .xn
    cmp ecx, PAL_GLOW
    jb .ramp
    cmp ecx, PAL_GLOW+8
    jae .xn
    ; a lit window: every other one goes dark
    push rax
    push r8
    push r9
    imul edi, r9d, 7
    imul edx, r8d, 13
    add edi, edx
    add edi, [rbp-48]
    call hash32
    mov ecx, eax
    pop r9
    pop r8
    pop rax
    test ecx, 1
    jz .xn
    mov byte [rbx+rax], RAMP(R_GREY, 3)
    jmp .xn
.ramp:
    cmp ecx, RAMP_BASE
    jb .xn
    cmp ecx, PAL_WATER
    jae .xn
    ; a streak down a quarter of the columns, below the roofline
    push rax
    push r8
    push r9
    mov edi, r9d
    imul edi, edi, 131
    add edi, [rbp-48]
    call hash32
    mov ecx, eax
    pop r9
    pop r8
    pop rax
    movzx edx, byte [rbx+rax]
    and edx, 7                      ; shade (RAMP_BASE is a multiple of 8)
    dec edx
    and ecx, 3
    jnz .base
    lea ecx, [r8*3]
    cmp ecx, r14d                   ; y > h/3
    jb .base
    dec edx
.base:
    ; grime gathers at the foot of the walls
    lea ecx, [r8*3]
    mov edi, r14d
    add edi, edi
    cmp ecx, edi                    ; y > 2h/3
    jb .st
    dec edx
.st:
    test edx, edx
    jns .sok
    xor edx, edx
.sok:
    movzx ecx, byte [rbx+rax]
    and ecx, ~7
    or ecx, edx
    mov [rbx+rax], cl
.xn:
    inc r9d
    jmp .x
.yn:
    inc r8d
    jmp .y
.out:
    mov eax, r15d
    RETURN

; twins for every sprite in a table (rdi table, esi count)
FUNC twin_table
    mov r12, rdi
    mov r13d, esi
    xor ebx, ebx
.l:
    cmp ebx, r13d
    jge .out
    mov edi, [r12+rbx*4]
    test edi, edi
    jz .n
    cmp dword [spr_grime+rdi*4], 0
    jne .n
    mov r14d, edi
    call sprite_twin
    mov [spr_grime+r14*4], eax
.n:
    inc ebx
    jmp .l
.out:
    RETURN

FUNC soul_sprites_init
    xor ebx, ebx
.t:
    mov edi, ebx
    call gen_turf
    mov [spr_turf+rbx*4], eax
    inc ebx
    cmp ebx, 8
    jl .t
    xor ebx, ebx
.two:
    mov edi, ebx
    call gen_litter
    mov [spr_litter+rbx*4], eax
    mov edi, ebx
    call gen_weeds
    mov [spr_weeds+rbx*4], eax
    mov edi, ebx
    call gen_wear
    mov [spr_wear+rbx*4], eax
    mov edi, ebx
    call gen_leaves
    mov [spr_leaves+rbx*4], eax
    mov edi, ebx
    call gen_trace
    mov [spr_trace+rbx*4], eax
    mov edi, ebx
    call gen_indprop
    mov [spr_indprop+rbx*4], eax
    inc ebx
    cmp ebx, 2
    jl .two
    call gen_heap
    mov [spr_heap], eax
    xor ebx, ebx
.y:
    mov edi, ebx
    call gen_yard
    mov [spr_yard+rbx*4], eax
    inc ebx
    cmp ebx, 6
    jl .y
    ; worn twins of every zone building
    lea rdi, [spr_zone]
    mov esi, ZONE_TYPES*ZONE_LEVELS*ZONE_VARS
    call twin_table
    lea rdi, [spr_zone2]
    mov esi, ZONE_TYPES*3*2
    call twin_table
    lea rdi, [spr_spec]
    mov esi, 4*3*2
    call twin_table
    lea rdi, [spr_style]
    mov esi, 2*6*5*4
    call twin_table
    RETURN

; =====================================================================
;  state: foundations of what was demolished
; =====================================================================
soul_reset:
    push rdi
    lea rdi, [map_trace]
    mov ecx, MAP_TILES/8
    xor eax, eax
    rep stosq
    pop rdi
    ret

; soul_demolish(rdi tile): a building is coming down here
soul_demolish:
    cmp byte [rdi+T_OBJ], OBJ_ZONEBLD
    je .y
    cmp byte [rdi+T_OBJ], OBJ_SERVICE
    jne .n
.y:
    mov rax, rdi
    sub rax, tiles
    shr rax, TILE_SHIFT
    mov byte [map_trace+rax], TRACE_MONTHS
.n:
    ret

; the foundations fade, a month at a time
soul_month:
    xor ecx, ecx
.l:
    cmp byte [map_trace+rcx], 0
    je .n
    dec byte [map_trace+rcx]
.n:
    inc ecx
    cmp ecx, MAP_TILES
    jl .l
    ret

; =====================================================================
;  what a building is in: soul_condition(rsi tile, edi map index)
;  -> eax 0 well kept, 1 worn, 2 derelict; rdx the reason (worn)
; =====================================================================
soul_condition:
    xor edx, edx
    test byte [rsi+T_FLAGS], F_ABANDON
    jz .a
    mov eax, 2
    ret
.a: test byte [rsi+T_FLAGS2], F2_GARBAGE
    jz .b
    lea rdx, [s_c_garbage]
    jmp .worn
.b: movzx eax, byte [rsi+T_HAPPY]
    test eax, eax                   ; (0: not yet lived in)
    jz .c
    cmp eax, 35
    jae .c
    lea rdx, [s_c_unhappy]
    jmp .worn
.c: cmp byte [map_crime+rdi], 150
    jb .d
    lea rdx, [s_c_crime]
    jmp .worn
.d: cmp byte [rsi+T_AGE], 96
    jb .ok
    cmp byte [map_lv+rdi], 70
    jae .ok
    lea rdx, [s_c_old]
.worn:
    mov eax, 1
    ret
.ok:
    xor eax, eax
    ret

; soul_sprite(edi sprite, rsi tile, edx map index) -> eax: the worn
; twin when the building is worn or derelict (beta)
FUNC soul_sprite
    mov ebx, edi
    cmp dword [beta_on], 0
    je .out
    mov edi, edx
    call soul_condition
    test eax, eax
    jz .out
    mov eax, [spr_grime+rbx*4]
    test eax, eax
    jz .out
    mov ebx, eax
.out:
    mov eax, ebx
    RETURN

; =====================================================================
;  draw hooks (beta): rbx tile, r12d x, r13d y, r14d depth base,
;  [draw_sx]/[draw_sy] the tile on screen, rdi the land remap
; =====================================================================
; decals over a ground tile that was just drawn
FUNC soul_ground, 32
    mov [rbp-48], rdi
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    mov [rbp-56], eax               ; map index
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_ROAD
    je .road
    cmp eax, OBJ_RUBBLE
    je .rubble
    cmp eax, OBJ_NONE
    jne .out
    ; a foundation left by a demolished building
    mov eax, [rbp-56]
    movzx eax, byte [map_trace+rax]
    test eax, eax
    jz .leaves
    mov edi, [spr_trace]
    cmp eax, TRACE_FRESH
    ja .blit
    mov edi, [spr_trace+4]
    jmp .blit
.leaves:
    cmp byte [rbx+T_TERRAIN], TER_GRASS
    jne .out
    cmp byte [rbx+T_ZONE], 0        ; lots keep their marks
    jne .out
    mov eax, [season_pos]
    and eax, 1023
    shr eax, 8
    cmp eax, 2                      ; autumn
    jne .out
    xor r15d, r15d
.nb:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+r15*4]
    add esi, [dir_dy+r15*4]
    call tile_at
    test rax, rax
    jz .nn
    cmp byte [rax+T_OBJ], OBJ_TREE
    je .tree
.nn:
    inc r15d
    cmp r15d, 4
    jl .nb
    jmp .out
.tree:
    mov edi, r12d
    mov esi, r13d
    mov edx, 8
    call hash3
    test eax, 3
    jz .out                         ; three in four tiles under the trees
    shr eax, 2
    and eax, 1
    mov edi, [spr_leaves+rax*4]
    jmp .blit
.road:
    ; busy streets wear: patches on every other tile, potholes on the worst
    cmp byte [rbx+T_TERRAIN], TER_WATER
    je .out
    cmp byte [rbx+T_ROADTYPE], RT_AVENUE
    ja .out
    movzx r15d, byte [rbx+T_TRAFFIC] ; (a smoothed count: 60 is a busy street)
    cmp r15d, 24
    jb .out
    mov edi, r12d
    mov esi, r13d
    mov edx, 5
    call hash3
    test eax, 1
    jnz .out                        ; every other tile of a busy street
    mov edi, [spr_wear]
    cmp r15d, 56
    jb .blit
    test eax, 2
    jz .blit
    mov edi, [spr_wear+4]
    jmp .blit
.rubble:
    mov edi, r12d
    mov esi, r13d
    mov edx, 6
    call hash3
    test eax, 1
    jz .out
    shr eax, 1
    and eax, 1
    mov edi, [spr_weeds+rax*4]
.blit:
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    mov ecx, r14d
    mov r8, [rbp-48]
    call blit_sprite
.out:
    RETURN

; props, litter and weeds around a grown zone building (after its
; sprite); for a 2x2 building they go on its front tile
FUNC soul_building, 32
    mov [prop_remap], rdi
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    mov [rbp-56], eax               ; map index
    mov eax, [draw_sx]
    mov [prop_sx], eax
    mov eax, [draw_sy]
    mov [prop_sy], eax
    mov [prop_depth], r14d
    cmp byte [rbx+T_SIZE], 2
    jne .pos
    lea edi, [r12+1]
    lea esi, [r13+1]
    call tile_screen
    mov [prop_sx], eax
    mov [prop_sy], edx
    add dword [prop_depth], 32
.pos:
    mov rsi, rbx
    mov edi, [rbp-56]
    call soul_condition
    mov r15d, eax
    ; litter where the garbage isn't collected
    movzx eax, byte [rbx+T_GARBAGE]
    cmp eax, 110
    jb .nolitter
    mov edi, [spr_heap]
    cmp eax, 190
    jae .lb
    mov edi, r12d
    mov esi, r13d
    mov edx, 9
    call hash3
    and eax, 1
    mov edi, [spr_litter+rax*4]
.lb:
    call prop_blit
.nolitter:
    test r15d, r15d
    jnz .weeds
    ; well kept: what people put in their yards
    cmp byte [rbx+T_SIZE], 2
    je .out
    movzx eax, byte [rbx+T_ZONE]
    cmp eax, ZONE_R
    je .home
    cmp eax, ZONE_I
    jne .out
    cmp byte [rbx+T_LEVEL], 3
    ja .out
    mov edi, r12d
    mov esi, r13d
    mov edx, 12
    call hash3
    and eax, 3
    cmp eax, 2
    jae .out
    mov edi, [spr_indprop+rax*4]
    call prop_blit
    jmp .out
.home:
    cmp byte [rbx+T_LEVEL], 3
    ja .out
    mov edi, r12d
    mov esi, r13d
    mov edx, 11
    call hash3
    and eax, 7
    cmp eax, 6
    jae .out
    mov edi, [spr_yard+rax*4]
    call prop_blit
    jmp .out
.weeds:
    ; worn homes let the weeds in; derelict buildings of every kind
    cmp r15d, 2
    je .der
    cmp byte [rbx+T_ZONE], ZONE_R
    jne .out
    mov edi, r12d
    mov esi, r13d
    mov edx, 13
    call hash3
    and eax, 1
    mov edi, [spr_weeds+rax*4]
    call prop_blit
    jmp .out
.der:
    mov edi, r12d
    mov esi, r13d
    mov edx, 13
    call hash3
    mov r15d, eax
    and eax, 1
    mov edi, [spr_weeds+rax*4]
    call prop_blit
    test r15d, 2
    jz .out
    cmp byte [rbx+T_GARBAGE], 110   ; (unless litter is already there)
    jae .out
    mov eax, r15d
    shr eax, 2
    and eax, 1
    mov edi, [spr_litter+rax*4]
    call prop_blit
.out:
    RETURN

; prop_blit(edi sprite): at the building's prop spot
prop_blit:
    mov esi, [prop_sx]
    mov edx, [prop_sy]
    mov ecx, [prop_depth]
    mov r8, [prop_remap]
    jmp blit_sprite

; =====================================================================
;  the inspector's condition row (rbx tile, r15d map index)
; =====================================================================
FUNC soul_inspect_row
    cmp dword [beta_on], 0
    je .out
    mov rsi, rbx
    mov edi, r15d
    call soul_condition
    mov r12d, eax
    mov r13, rdx
    call tb_reset
    lea rdi, [s_cond]
    call tb_str
    mov ecx, UI_GOOD
    lea rdi, [s_c_fine]
    test r12d, r12d
    jz .say
    mov ecx, UI_BAD
    lea rdi, [s_c_derelict]
    cmp r12d, 2
    je .say
    mov ecx, UI_WARN
    lea rdi, [s_c_worn]
    push rcx
    push rcx
    call tb_str
    pop rcx
    pop rcx
    mov rdi, r13
.say:
    push rcx
    push rcx
    call tb_str
    pop rcx
    pop rcx
    lea rdx, [textbuf]
    call row_text
.out:
    RETURN

; a census for the test scripts: how the buildings look
%ifndef WEB
FUNC soul_report, 48
    lea rdi, [LOCAL(28)]
    mov ecx, 7
    xor eax, eax
    rep stosd                       ; kept, worn, derelict, 4 reasons
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea rsi, [tiles+rax]
    cmp byte [rsi+T_OBJ], OBJ_ZONEBLD
    jne .n
    test byte [rsi+T_FLAGS], F_ANCHOR
    jz .n
    test byte [rsi+T_FLAGS], F_BUILD
    jnz .n
    mov edi, ebx
    call soul_condition
    inc dword [LOCAL(28)+rax*4]
    cmp eax, 1
    jne .n
    lea rcx, [s_c_garbage]
    xor eax, eax
    cmp rdx, rcx
    je .r
    inc eax
    lea rcx, [s_c_unhappy]
    cmp rdx, rcx
    je .r
    inc eax
    lea rcx, [s_c_crime]
    cmp rdx, rcx
    je .r
    inc eax
.r: inc dword [LOCAL(16)+rax*4]
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    lea rdi, [pf_soul]
    mov esi, [LOCAL(28)]
    mov edx, [LOCAL(24)]
    mov ecx, [LOCAL(20)]
    mov r8d, [LOCAL(16)]
    mov r9d, [LOCAL(12)]
    mov eax, [LOCAL(8)]
    mov [rsp], rax
    mov eax, [LOCAL(4)]
    mov [rsp+8], rax
    xor eax, eax
    CALLC printf
    RETURN
%endif
