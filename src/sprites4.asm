; =====================================================================
;  SPRITES 4 - railways (beta): track for every junction shape (on
;  land and on bridges), rails over level crossings, trains, stations
;  and freight yards
; =====================================================================
section .bss
spr_rail        resd 32         ; mask (+16 on a bridge)
spr_railx       resd 2          ; rails over a road: along x, along y
spr_train       resd 12         ; (loco, coach, wagon) * 4 + dir
rail_bridge     resd 1

section .data
; per arm (mask bit): ballast box, then the axis (0 along y, 1 along x)
rail_arm    dd 5,0,11,8, 0
            dd 8,5,16,11, 1
            dd 5,8,11,16, 0
            dd 0,5,8,11, 1

section .text

; one tile of track: edi mask, esi 1 on a bridge
FUNC gen_rail, 16
    mov r12d, edi
    mov [rail_bridge], esi
    lea eax, [r12+480]
    BEGIN 16, 3, eax
    ; the ground under it (a deck over water)
    MAT M_GRASS
    cmp dword [rail_bridge], 0
    je .g
    MAT M_CONCRETE
.g:
    BOX 0,0,0,16,16,1
    ; ballast in the middle
    MAT M_DIRT
    BOX 5,5,1,11,11,2
    xor ebx, ebx
.arm:
    bt r12d, ebx
    jnc .an
    imul eax, ebx, 20
    lea r13, [rail_arm+rax]
    ; ballast
    MAT M_DIRT
    mov edi, [r13]
    mov esi, [r13+4]
    mov edx, 1
    mov ecx, [r13+8]
    mov r8d, [r13+12]
    mov r9d, 2
    call vbox
    ; sleepers every other voxel, across the arm
    MAT M_WOOD
    xor r14d, r14d
.sl:
    cmp dword [r13+16], 0
    jne .slx
    ; along y: sleepers span x 4..12 at y
    mov esi, [r13+4]
    add esi, r14d
    cmp esi, [r13+12]
    jge .rails
    mov edi, 4
    mov edx, 1
    mov ecx, 12
    lea r8d, [rsi+1]
    mov r9d, 2
    call vbox
    add r14d, 2
    jmp .sl
.slx:
    mov edi, [r13]
    add edi, r14d
    cmp edi, [r13+8]
    jge .rails
    mov esi, 4
    mov edx, 1
    lea ecx, [rdi+1]
    mov r8d, 12
    mov r9d, 2
    call vbox
    add r14d, 2
    jmp .sl
.rails:
    MAT M_METAL
    cmp dword [r13+16], 0
    jne .rx
    mov edi, 6
    mov esi, [r13+4]
    mov edx, 2
    mov ecx, 7
    mov r8d, [r13+12]
    mov r9d, 3
    call vbox
    mov edi, 9
    mov esi, [r13+4]
    mov edx, 2
    mov ecx, 10
    mov r8d, [r13+12]
    mov r9d, 3
    call vbox
    jmp .an
.rx:
    mov edi, [r13]
    mov esi, 6
    mov edx, 2
    mov ecx, [r13+8]
    mov r8d, 7
    mov r9d, 3
    call vbox
    mov edi, [r13]
    mov esi, 9
    mov edx, 2
    mov ecx, [r13+8]
    mov r8d, 10
    mov r9d, 3
    call vbox
.an:
    inc ebx
    cmp ebx, 4
    jl .arm
    call finish_model
    RETURN

; rails laid over a road (edi 0: along x, 1: along y)
FUNC gen_railx
    mov r12d, edi
    lea eax, [r12+520]
    BEGIN 16, 3, eax
    MAT M_METAL
    test r12d, r12d
    jnz .y
    BOX 0,6,1,16,7,2
    BOX 0,9,1,16,10,2
    jmp .d
.y:
    BOX 6,0,1,7,16,2
    BOX 9,0,1,10,16,2
.d:
    call finish_model
    RETURN

; a train car (edi 0 loco, 1 coach, 2 freight wagon; esi dir)
FUNC gen_train
    mov r12d, edi
    mov [car_dir], esi
    lea eax, [r12+7600]
    BEGIN 16, 14, eax
    MAT M_DARK
    CBOX 1,5,0,15,11,2
    cmp r12d, 1
    je .coach
    cmp r12d, 2
    je .wagon
    ; the locomotive: red, a cab and a lamp at the front
    MAT M_RED
    CBOX 0,4,2,16,12,9
    MAT M_GLASS
    CBOX 12,4,6,14,12,8
    MAT M_METAL
    CBOX 1,5,9,15,11,10
    MAT M_YELLOW
    CBOX 0,4,3,16,12,4
    MAT M_LAMP
    CBOX 15,7,4,16,9,5
    jmp .d
.coach:
    MAT M_WHITE
    CBOX 0,4,2,16,12,9
    MAT M_GLASS
    CBOX 1,4,5,15,12,7
    MAT M_BLUE
    CBOX 0,4,3,16,12,4
    MAT M_METAL
    CBOX 0,5,9,16,11,10
    jmp .d
.wagon:
    ; a flat wagon with two containers
    MAT M_METAL
    CBOX 0,4,2,16,12,3
    MAT M_ORANGE
    CBOX 1,4,3,8,12,9
    MAT M_BLUE
    CBOX 8,4,3,15,12,9
.d:
    call finish_model
    RETURN

; a railway station: platforms and a hall with a clock
FUNC bld_railstn
    BEGIN 32, 40, 6200
    MAT M_CONCRETE
    BOX 1,1,0,31,31,2
    ; the hall
    MAT M_BRICK
    BOX 3,3,2,29,18,16
    MAT M_WHITE_WIN
    BOX 4,17,4,28,18,13
    MAT M_ROOF_RED
    PYR 2,2,16,30,19,8
    ; the clock tower
    MAT M_BRICK
    BOX 13,8,16,19,14,30
    MAT M_WHITE
    BOX 14,13,24,18,14,28
    MAT M_DARK
    BOX 15,13,26,17,14,27
    MAT M_ROOF_RED
    PYR 12,7,30,20,15,6
    ; the platform canopy
    MAT M_METAL
    BOX 4,24,2,5,25,10
    BOX 27,24,2,28,25,10
    MAT M_GLASS
    BOX 2,21,10,30,29,11
    call finish_model
    RETURN

; a freight yard: containers stacked, a gantry crane
FUNC bld_freight
    BEGIN 48, 48, 6300
    MAT M_DIRT
    BOX 1,1,0,47,47,1
    ; stacks of containers
    MAT M_ORANGE
    BOX 4,4,1,16,9,7
    BOX 4,4,7,16,9,13
    MAT M_BLUE
    BOX 4,11,1,16,16,7
    MAT M_RED
    BOX 4,18,1,16,23,7
    BOX 4,18,7,16,23,13
    MAT M_TEAL
    BOX 20,4,1,32,9,7
    MAT M_WHITE
    BOX 20,11,1,32,16,7
    BOX 20,11,7,32,16,13
    MAT M_ORANGE
    BOX 20,18,1,32,23,7
    MAT M_BLUE
    BOX 34,4,1,44,9,7
    BOX 34,4,7,44,9,13
    ; the gantry crane over the loading track
    MAT M_YELLOW
    BOX 6,28,1,8,30,30
    BOX 6,42,1,8,44,30
    BOX 38,28,1,40,30,30
    BOX 38,42,1,40,44,30
    BOX 6,28,30,40,30,33
    BOX 6,42,30,40,44,33
    BOX 20,28,30,24,44,33
    MAT M_DARK
    BOX 21,34,20,23,38,30
    ; the office
    MAT M_CONCRETE
    BOX 36,14,1,46,24,10
    MAT M_WHITE_WIN
    BOX 36,23,3,46,24,9
    call finish_model
    RETURN

; everything above, at start-up
FUNC rail_sprites_init
    xor ebx, ebx
.r:
    mov edi, ebx
    xor esi, esi
    call gen_rail
    mov [spr_rail+rbx*4], eax
    mov edi, ebx
    mov esi, 1
    call gen_rail
    mov [spr_rail+rbx*4+64], eax
    inc ebx
    cmp ebx, 16
    jl .r
    xor edi, edi
    call gen_railx
    mov [spr_railx], eax
    mov edi, 1
    call gen_railx
    mov [spr_railx+4], eax
    xor r12d, r12d
.t:
    xor r13d, r13d
.td:
    mov edi, r12d
    mov esi, r13d
    call gen_train
    lea ecx, [r12*4+r13]
    mov [spr_train+rcx*4], eax
    inc r13d
    cmp r13d, 4
    jl .td
    inc r12d
    cmp r12d, 3
    jl .t
    RETURN
