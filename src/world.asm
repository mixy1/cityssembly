; =====================================================================
;  WORLD - map storage, random numbers, noise and terrain generation
; =====================================================================

section .bss
alignb 16
tiles           resb MAP_TILES*TILE_BYTES
rng_state       resd 1
music_rng       resd 1          ; the music's own (see music_rand)
world_seed      resd 1
hwy_row         resd 1          ; y row where the highway enters (west edge)
hwy_col         resd 1          ; x column where the 2nd highway enters (north)

section .text

; ---------------------------------------------------------------------
;  random numbers
; ---------------------------------------------------------------------
rand:
    mov eax, [rng_state]
    mov edx, eax
    shl edx, 13
    xor eax, edx
    mov edx, eax
    shr edx, 17
    xor eax, edx
    mov edx, eax
    shl edx, 5
    xor eax, edx
    mov [rng_state], eax
    ret

; the music's random numbers, apart from the city's: the music is made as
; the sound card plays it, so drawing from rand made the city's future
; depend on frame timing
music_rand:
    mov eax, [music_rng]
    test eax, eax
    jnz .s
    mov eax, 0x9E3779B9
.s:
    mov edx, eax
    shl edx, 13
    xor eax, edx
    mov edx, eax
    shr edx, 17
    xor eax, edx
    mov edx, eax
    shl edx, 5
    xor eax, edx
    mov [music_rng], eax
    ret

; rand_range(edi n) -> eax in [0,n)
rand_range:
    push rdi
    call rand
    pop rcx
    test ecx, ecx
    jz .z
    xor edx, edx
    div ecx
    mov eax, edx
    ret
.z: xor eax, eax
    ret

; hash32(edi) -> eax
hash32:
    mov eax, edi
    mov edx, eax
    shr edx, 16
    xor eax, edx
    imul eax, eax, 0x7feb352d
    mov edx, eax
    shr edx, 15
    xor eax, edx
    imul eax, eax, 0x846ca68b
    mov edx, eax
    shr edx, 16
    xor eax, edx
    ret

; hash3(edi x, esi y, edx z) -> eax
hash3:
    imul edi, edi, 374761393
    imul esi, esi, 668265263
    imul edx, edx, 1274126177
    add edi, esi
    add edi, edx
    add edi, [world_seed]
    jmp hash32

; ---------------------------------------------------------------------
;  lattice value in 0..255 for (edi x, esi y, edx octave seed)
; ---------------------------------------------------------------------
lattice:
    call hash3
    and eax, 255
    ret

; smoothstep on 0..256 fraction: t*t*(3-2t)
smooth256:
    ; eax = t (0..256) -> eax
    mov ecx, eax
    imul ecx, eax               ; t^2 (<= 65536)
    mov edx, 768
    sub edx, eax
    sub edx, eax                ; 3*256 - 2t
    imul ecx, edx               ; t^2 (3-2t) scaled by 256^3
    shr ecx, 16
    mov eax, ecx
    ret

; ---------------------------------------------------------------------
;  value_noise(edi x, esi y, edx cellsize(pow2), ecx seed) -> eax 0..255
; ---------------------------------------------------------------------
FUNC value_noise, 32
    mov r12d, edi
    mov r13d, esi
    mov r14d, ecx                   ; seed
    bsf ecx, edx                    ; shift
    mov [rbp-48], ecx
    mov eax, r12d
    shr eax, cl
    mov [rbp-52], eax               ; cx
    mov eax, r13d
    shr eax, cl
    mov [rbp-56], eax               ; cy
    ; fractions to 0..256
    mov eax, 1
    shl eax, cl
    dec eax
    mov ebx, eax                    ; mask
    mov eax, r12d
    and eax, ebx
    shl eax, 8
    shr eax, cl
    call smooth256
    mov [rbp-60], eax               ; fx
    mov eax, r13d
    and eax, ebx
    mov ecx, [rbp-48]
    shl eax, 8
    shr eax, cl
    call smooth256
    mov [rbp-64], eax               ; fy
    ; corners
    mov edi, [rbp-52]
    mov esi, [rbp-56]
    mov edx, r14d
    call lattice
    mov r15d, eax                   ; v00
    mov edi, [rbp-52]
    inc edi
    mov esi, [rbp-56]
    mov edx, r14d
    call lattice
    mov ebx, eax                    ; v10
    mov edi, [rbp-52]
    mov esi, [rbp-56]
    inc esi
    mov edx, r14d
    call lattice
    mov r12d, eax                   ; v01
    mov edi, [rbp-52]
    inc edi
    mov esi, [rbp-56]
    inc esi
    mov edx, r14d
    call lattice
    mov r13d, eax                   ; v11
    ; top = v00 + (v10-v00)*fx
    mov edi, r15d
    mov esi, ebx
    mov edx, [rbp-60]
    call lerp8
    mov r15d, eax
    mov edi, r12d
    mov esi, r13d
    mov edx, [rbp-60]
    call lerp8
    mov edi, r15d
    mov esi, eax
    mov edx, [rbp-64]
    call lerp8
    RETURN

; fbm(edi x, esi y, edx seed) -> eax 0..255
FUNC fbm
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov edx, 32
    mov ecx, r14d
    call value_noise
    imul ebx, eax, 5                ; weight 5
    mov edi, r12d
    mov esi, r13d
    mov edx, 16
    lea ecx, [r14+1]
    call value_noise
    imul eax, eax, 2
    add ebx, eax
    mov edi, r12d
    mov esi, r13d
    mov edx, 4
    lea ecx, [r14+2]
    call value_noise
    add ebx, eax
    mov eax, ebx
    shr eax, 3
    RETURN

; ---------------------------------------------------------------------
;  tile_at(edi x, esi y) -> rax pointer or 0 when outside the map
; ---------------------------------------------------------------------
tile_at:
    cmp edi, MAP_W
    jae .out
    cmp esi, MAP_W
    jae .out
    mov eax, esi
    shl eax, MAP_SHIFT
    add eax, edi
    shl eax, TILE_SHIFT
    add rax, tiles
    ret
.out:
    xor eax, eax
    ret

; ---------------------------------------------------------------------
;  world_generate: terrain, water, river, forests, highway
; ---------------------------------------------------------------------
; beta map types: the valley (classic), an island, lakes, dry plains,
; a river delta
MT_VALLEY   equ 0
MT_ISLAND   equ 1
MT_LAKES    equ 2
MT_PLAINS   equ 3
MT_DELTA    equ 4
MT_TYPES    equ 5
section .data
mt_sea      dd 78, 78, 96, 60, 74, 78, 78, 78   ; height below which it's water
mt_forest   dd 150, 150, 150, 185, 150, 150, 150, 150
section .bss
map_type    resd 1
section .text

FUNC world_generate, 32
    lea rdi, [tiles]
    xor eax, eax
    mov ecx, MAP_TILES*TILE_BYTES/8
    rep stosq

    mov eax, [world_seed]
    or eax, 0x9E3779B1
    mov [rng_state], eax

    ; --- height field -> lakes / land ---
    xor r13d, r13d                  ; y
.gy:
    xor r12d, r12d                  ; x
.gx:
    mov edi, r12d
    mov esi, r13d
    mov edx, 11
    call fbm
    mov ebx, eax
    ; beta map types: an island sinks toward the edges
    cmp dword [map_type], MT_ISLAND
    jne .nisl
    mov eax, r12d
    sub eax, 64
    cdq
    xor eax, edx
    sub eax, edx
    mov ecx, r13d
    sub ecx, 64
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx
    cmp eax, ecx
    cmovl eax, ecx
    sub eax, 38
    jle .nisl
    lea eax, [rax*4]
    sub ebx, eax
.nisl:
    ; push the map border up a little less so lakes can touch edges
    mov edi, r12d
    mov esi, r13d
    call tile_at
    mov r14, rax
    call rand
    and eax, 255
    mov [r14+T_VARIANT], al
    mov eax, [map_type]
    and eax, 7
    cmp ebx, [mt_sea+rax*4]
    jge .land
    mov byte [r14+T_TERRAIN], TER_WATER
    jmp .nextx
.land:
    mov byte [r14+T_TERRAIN], TER_GRASS
    ; forests
    mov edi, r12d
    mov esi, r13d
    mov edx, 57
    call fbm
    mov ecx, [map_type]
    and ecx, 7
    cmp eax, [mt_forest+rcx*4]
    jl .scatter
    call rand
    and eax, 7
    cmp eax, 6
    jge .nextx
    jmp .tree
.scatter:
    call rand
    and eax, 63
    jnz .nextx
.tree:
    mov byte [r14+T_OBJ], OBJ_TREE
    call rand
    and eax, 3
    mov [r14+T_SUB], al
.nextx:
    inc r12d
    cmp r12d, MAP_W
    jl .gx
    inc r13d
    cmp r13d, MAP_W
    jl .gy

    ; --- river: meander from the north edge to the south edge ---
    mov edi, 40
    call rand_range
    add eax, 70
    mov r12d, eax                   ; x
    xor r13d, r13d                  ; y
    xor r15d, r15d                  ; drift
.river:
    ; carve width 2..3 (a delta: 6)
    mov ebx, -1
    cmp dword [map_type], MT_DELTA
    jne .rw
    mov ebx, -3
.rw:
    lea edi, [r12+rbx]
    mov esi, r13d
    call tile_at
    test rax, rax
    jz .rwn
    mov byte [rax+T_TERRAIN], TER_WATER
    mov byte [rax+T_OBJ], OBJ_NONE
.rwn:
    inc ebx
    cmp ebx, 2
    jl .rw
    cmp dword [map_type], MT_DELTA
    jne .rwd
    cmp ebx, 3
    jl .rw
.rwd:
    ; meander
    call rand
    and eax, 7
    cmp eax, 2
    jge .nodrift
    call rand
    and eax, 2
    dec eax                         ; -1 or +1
    add r15d, eax
    CLAMP r15d, -1, 1
.nodrift:
    call rand
    and eax, 3
    jnz .keepx
    add r12d, r15d
.keepx:
    CLAMP r12d, 50, 120
    inc r13d
    cmp r13d, MAP_W
    jl .river

    ; --- sand shores ---
    xor r13d, r13d
.sy:
    xor r12d, r12d
.sx:
    mov edi, r12d
    mov esi, r13d
    call tile_at
    mov r14, rax
    cmp byte [r14+T_TERRAIN], TER_GRASS
    jne .snext
    mov edi, r12d
    mov esi, r13d
    call count_water_near
    cmp eax, 0
    je .snext
    mov edi, r12d
    mov esi, r13d
    mov edx, 91
    call fbm
    cmp eax, 120
    jl .snext
    mov byte [r14+T_TERRAIN], TER_SAND
    mov byte [r14+T_OBJ], OBJ_NONE
.snext:
    inc r12d
    cmp r12d, MAP_W
    jl .sx
    inc r13d
    cmp r13d, MAP_W
    jl .sy

    ; --- clear a friendly build area around the map centre-west ---
    mov r13d, 40
.cy:
    mov r12d, 14
.cx:
    mov edi, r12d
    mov esi, r13d
    call tile_at
    mov r14, rax
    ; keep water in the middle of big lakes, drain near the start
    mov eax, r12d
    sub eax, 36
    imul eax, eax
    mov ecx, r13d
    sub ecx, 64
    imul ecx, ecx
    add eax, ecx
    cmp eax, 18*18
    jg .cnext
    cmp byte [r14+T_TERRAIN], TER_WATER
    jne .cland
    mov byte [r14+T_TERRAIN], TER_GRASS
.cland:
    cmp eax, 10*10
    jg .cnext
    cmp byte [r14+T_OBJ], OBJ_TREE
    jne .cnext
    call rand
    and eax, 3
    jz .cnext
    mov byte [r14+T_OBJ], OBJ_NONE
.cnext:
    inc r12d
    cmp r12d, 60
    jl .cx
    inc r13d
    cmp r13d, 90
    jl .cy

    ; --- a creek through the starting plot (pumps upstream, outlets down) ---
    cmp dword [sandbox], 0
    jne .nocreek
    mov r12d, 48
    xor r13d, r13d
.ck:
    mov ebx, 0
.ckw:
    lea edi, [r12+rbx]
    mov esi, r13d
    call tile_at
    mov byte [rax+T_TERRAIN], TER_WATER
    mov byte [rax+T_OBJ], OBJ_NONE
    inc ebx
    cmp ebx, 2
    jl .ckw
    call rand
    and eax, 7
    jnz .ckn
    call rand
    and eax, 2
    dec eax
    add r12d, eax
    CLAMP r12d, 47, 49
.ckn:
    inc r13d
    cmp r13d, MAP_W
    jl .ck
.nocreek:
    ; --- highway from the west edge ---
    mov dword [hwy_row], 64
    xor r12d, r12d
.hw:
    mov edi, r12d
    mov esi, 64
    call tile_at
    mov byte [rax+T_TERRAIN], TER_GRASS
    mov byte [rax+T_OBJ], OBJ_ROAD
    mov byte [rax+T_FLAGS], F_HIGHWAY
    mov byte [rax+T_ROADTYPE], RT_HIGHWAY
    mov byte [rax+T_ZONE], 0
    inc r12d
    mov eax, 22
    cmp dword [sandbox], 0
    jne .hwl
    mov eax, 26                     ; reach into the starting plot
.hwl:
    cmp r12d, eax
    jl .hw
    ; second regional highway from the north edge
    mov dword [hwy_col], 44
    xor r12d, r12d
.hn:
    mov edi, 44
    mov esi, r12d
    call tile_at
    mov byte [rax+T_OBJ], OBJ_ROAD
    mov byte [rax+T_FLAGS], F_HIGHWAY
    mov byte [rax+T_ROADTYPE], RT_HIGHWAY
    mov byte [rax+T_ZONE], 0
    inc r12d
    cmp r12d, 18
    jl .hn
    call roads_update_all
    call resources_generate
    RETURN

; ---------------------------------------------------------------------
;  natural resources: forests, fertile soil and ore deposits decide
;  which industries appear where
; ---------------------------------------------------------------------
FUNC resources_generate
    xor r13d, r13d
.y:
    xor r12d, r12d
.x:
    mov edi, r12d
    mov esi, r13d
    call tile_at
    mov rbx, rax
    mov byte [rbx+T_RES], RES_NONE
    cmp byte [rbx+T_TERRAIN], TER_WATER
    je .n
    ; forest: many trees nearby
    xor r14d, r14d
    mov r15d, -2
.fy:
    mov ecx, -2
.fx:
    push rcx
    push rcx
    lea edi, [r12+rcx]
    lea esi, [r13+r15]
    call tile_at
    pop rcx
    pop rcx
    test rax, rax
    jz .fn
    cmp byte [rax+T_OBJ], OBJ_TREE
    jne .fn
    inc r14d
.fn:
    inc ecx
    cmp ecx, 2
    jle .fx
    inc r15d
    cmp r15d, 2
    jle .fy
    cmp r14d, 9
    jl .ore
    mov byte [rbx+T_RES], RES_FOREST
    jmp .n
.ore:
    mov edi, r12d
    mov esi, r13d
    mov edx, 83
    call fbm
    cmp eax, 168
    jl .fert
    mov byte [rbx+T_RES], RES_ORE
    jmp .n
.fert:
    mov edi, r12d
    mov esi, r13d
    mov edx, 71
    call fbm
    cmp eax, 142
    jl .n
    mov byte [rbx+T_RES], RES_FERTILE
.n:
    inc r12d
    cmp r12d, MAP_W
    jl .x
    inc r13d
    cmp r13d, MAP_W
    jl .y
    RETURN

; count_water_near(edi x, esi y) -> eax count of water in 8-neighbourhood
FUNC count_water_near
    mov r12d, edi
    mov r13d, esi
    xor ebx, ebx
    mov r14d, -1
.dy:
    mov r15d, -1
.dx:
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call tile_at
    test rax, rax
    jz .n
    cmp byte [rax+T_TERRAIN], TER_WATER
    jne .n
    inc ebx
.n:
    inc r15d
    cmp r15d, 1
    jle .dx
    inc r14d
    cmp r14d, 1
    jle .dy
    mov eax, ebx
    RETURN

; ---------------------------------------------------------------------
;  road connection masks. bit0 = -y (NE), bit1 = +x (SE),
;  bit2 = +y (SW), bit3 = -x (NW).  Roads also connect off-map at the
;  highway entry so the highway visibly continues out of the region.
; ---------------------------------------------------------------------
; is_road(edi x, esi y) -> eax 1/0   (off-map counts for highway rows)
is_road:
    call tile_at
    test rax, rax
    jz .no
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .no
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; road_mask(edi x, esi y) -> eax
FUNC road_mask
    mov r12d, edi
    mov r13d, esi
    xor ebx, ebx
    mov edi, r12d
    lea esi, [r13-1]
    call is_road
    or ebx, eax
    lea edi, [r12+1]
    mov esi, r13d
    call is_road
    shl eax, 1
    or ebx, eax
    mov edi, r12d
    lea esi, [r13+1]
    call is_road
    shl eax, 2
    or ebx, eax
    lea edi, [r12-1]
    mov esi, r13d
    call is_road
    shl eax, 3
    or ebx, eax
    ; highways on the map edge connect outwards to the region
    mov edi, r12d
    mov esi, r13d
    call tile_at
    cmp byte [rax+T_ROADTYPE], RT_HIGHWAY
    jne .done
    test r12d, r12d
    jnz .n2
    or ebx, 8
.n2:
    test r13d, r13d
    jnz .n3
    or ebx, 1
.n3:
    cmp r12d, MAP_W-1
    jne .n4
    or ebx, 2
.n4:
    cmp r13d, MAP_W-1
    jne .done
    or ebx, 4
.done:
    mov eax, ebx
    RETURN

; same idea for power lines (they also link to roads-less buildings)
FUNC power_mask
    mov r12d, edi
    mov r13d, esi
    xor ebx, ebx
    xor r14d, r14d
.dir:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+r14*4]
    add esi, [dir_dy+r14*4]
    call tile_at
    test rax, rax
    jz .n
    mov cl, [rax+T_OBJ]
    cmp cl, OBJ_POWER
    je .yes
    cmp cl, OBJ_SERVICE
    je .yes
    cmp cl, OBJ_ZONEBLD
    je .yes
    jmp .n
.yes:
    bts ebx, r14d
.n:
    inc r14d
    cmp r14d, 4
    jl .dir
    mov eax, ebx
    RETURN

; update road/power sub masks around (edi x, esi y)
FUNC roads_update_around
    mov r12d, edi
    mov r13d, esi
    mov r14d, -1
.dy:
    mov r15d, -1
.dx:
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call update_tile_mask
    inc r15d
    cmp r15d, 1
    jle .dx
    inc r14d
    cmp r14d, 1
    jle .dy
    RETURN

FUNC update_tile_mask
    mov r12d, edi
    mov r13d, esi
    call tile_at
    test rax, rax
    jz .out
    mov rbx, rax
    mov al, [rbx+T_OBJ]
    cmp al, OBJ_ROAD
    jne .np
    mov edi, r12d
    mov esi, r13d
    call road_mask
    mov [rbx+T_SUB], al
    jmp .out
.np:
    cmp al, OBJ_RAIL
    jne .npr
    mov edi, r12d
    mov esi, r13d
    call rail_mask
    mov [rbx+T_SUB], al
    jmp .out
.npr:
    cmp al, OBJ_RUNWAY
    jne .npw
    mov edi, r12d
    mov esi, r13d
    call runway_mask
    mov [rbx+T_SUB], al
    jmp .out
.npw:
    cmp al, OBJ_LEVEE
    jne .npl
    mov edi, r12d
    mov esi, r13d
    call levee_mask
    mov [rbx+T_SUB], al
    jmp .out
.npl:
    cmp al, OBJ_POWER
    jne .out
    mov edi, r12d
    mov esi, r13d
    call power_mask
    mov [rbx+T_SUB], al
.out:
    RETURN

FUNC roads_update_all
    xor r13d, r13d
.y:
    xor r12d, r12d
.x:
    mov edi, r12d
    mov esi, r13d
    call update_tile_mask
    inc r12d
    cmp r12d, MAP_W
    jl .x
    inc r13d
    cmp r13d, MAP_W
    jl .y
    RETURN

section .data
; direction vectors matching the mask bits: -y, +x, +y, -x
dir_dx  dd  0, 1, 0, -1
dir_dy  dd -1, 0, 1,  0
