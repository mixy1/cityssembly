; =====================================================================
;  TRAFFIC - vehicles with real routes
;
;  Every vehicle is an agent with an origin, a destination and a path
;  found with Dijkstra over the road graph (costs include road speed
;  and live congestion).  Road tiles have a capacity per heading, so
;  queues form behind bottlenecks.  Trips:
;    commuters, shoppers, goods trucks (industry -> shops), exports and
;    imports over the highway, visitors, buses between stops, fire
;    trucks, garbage trucks and police patrols.
; =====================================================================

MAX_VEH      equ 1200
VREC         equ 128
MAX_PATH     equ 250
PF_MAX_POPS  equ 14000
TURN_COST    equ 8

; vehicle record
V_TX     equ 0      ; word
V_TY     equ 2      ; word
V_DIR    equ 4      ; out heading on the current tile
V_TYPE   equ 5      ; VT_*, 255 = free
V_COLOR  equ 6
V_LANE   equ 7
V_PROG   equ 8      ; dword 0..256 across the tile
V_SPD    equ 12     ; dword base speed
V_WX     equ 16     ; world position (1/16 voxel)
V_WY     equ 20
V_PLEN   equ 24     ; word path length
V_PPOS   equ 26     ; word index of the current tile in the path
V_PURP   equ 28     ; PU_*
V_CARGO  equ 29
V_WAIT   equ 30     ; word
V_DST    equ 32     ; dword tile index of the destination building
V_HOME   equ 36     ; dword tile index of the home depot
V_AGE    equ 40
V_STOP   equ 44     ; bus: index of the next stop
V_INDIR  equ 46     ; heading used to enter the tile
V_DWELL  equ 47     ; bus stop / fire fighting countdown (x8 ticks)
V_DSTROAD equ 48    ; dword destination road tile (for re-routing)
V_PATH   equ 64     ; 2 bits per step, 256 steps

VT_CAR     equ 0
VT_TRUCK   equ 1
VT_BUS     equ 2
VT_FIRE    equ 3
VT_GARBAGE equ 4
VT_POLICE  equ 5

PU_COMMUTE  equ 0
PU_SHOP     equ 1
PU_GOODS    equ 2
PU_EXPORT   equ 3
PU_IMPORT   equ 4
PU_VISIT    equ 5
PU_FIRE     equ 6
PU_RETURN   equ 7
PU_GARB     equ 8
PU_PATROL   equ 9
PU_BUS      equ 10

MISC_FTRUCK equ 4       ; fire truck on the way
MISC_GTRUCK equ 8       ; garbage truck on the way

MAX_STOPS   equ 256

section .bss
alignb 16
vehicles        resb MAX_VEH*VREC
pf_dist         resw MAP_TILES
pf_stamp        resw MAP_TILES
pf_from         resb MAP_TILES
pf_heap         resd 65536
pf_gen          resd 1
pf_path         resb MAX_PATH+8
pf_len          resd 1
veh_count       resd 1
stops           resw MAX_STOPS
n_stops         resd 1
flow_moved      resd 1
flow_possible   resd 1
spawn_budget    resd 1
trips_stuck     resd 1
trips_nopath    resd 1
links           resw 64
n_links         resd 1

section .data
road_speed  dd 14, 19, 28          ; street, avenue, highway
road_cap    db 3, 6, 8
road_cost_t dd 6, 4, 2
lane_off    dd 48, 40, 40          ; 1/16 voxel from the centre line
veh_speed_pct dd 100, 85, 80, 115, 85, 110
dir_rev_t   db 2, 3, 0, 1

section .text

FUNC traffic_init
    lea rdi, [vehicles]
    mov ecx, MAX_VEH*VREC
    mov al, 255
    rep stosb
    xor ebx, ebx
.t:
    mov eax, ebx
    shl eax, 7
    mov byte [vehicles+rax+V_TYPE], 255
    inc ebx
    cmp ebx, MAX_VEH
    jl .t
    mov dword [veh_count], 0
    mov dword [pf_gen], 0
    lea rdi, [pf_stamp]
    xor eax, eax
    mov ecx, MAP_TILES/2
    rep stosd
    ; no vehicles means no one on the roads: saves stored the lane counts
    ; of cars that no longer exist, which blocked roads after loading.
    ; Likewise the "truck on the way" marks: a building whose truck was
    ; lost with a save was never served again
    xor ebx, ebx
.o:
    mov eax, ebx
    shl eax, TILE_SHIFT
    mov dword [tiles+rax+T_OCC], 0
    mov byte [tiles+rax+T_JAM], 0
    and byte [tiles+rax+T_MISC], ~(MISC_FTRUCK | MISC_GTRUCK)
    inc ebx
    cmp ebx, MAP_TILES
    jl .o
    RETURN

; ---------------------------------------------------------------------
;  pathfinding: path_find(edi src tile, esi dst tile) -> eax length or -1
;  directions in pf_path[0..len)
; ---------------------------------------------------------------------
FUNC path_find, 32
    mov [rbp-48], edi
    mov [rbp-52], esi
    cmp edi, esi
    jne .go
    mov dword [pf_len], 0
    xor eax, eax
    RETURN
.go:
    inc dword [pf_gen]
    mov eax, [pf_gen]
    and eax, 0xFFFF
    jnz .gen
    lea rdi, [pf_stamp]
    xor eax, eax
    mov ecx, MAP_TILES/2
    rep stosd
    mov dword [pf_gen], 1
    mov eax, 1
.gen:
    mov r15d, eax                   ; generation stamp
    mov ebx, [rbp-48]
    mov [pf_stamp+rbx*2], r15w
    mov word [pf_dist+rbx*2], 0
    mov [pf_heap], ebx              ; key = 0<<14 | src
    mov r12d, 1                     ; heap size
    mov r13d, PF_MAX_POPS
.pop:
    test r12d, r12d
    jz .fail
    dec r13d
    jz .fail
    ; pop min
    mov r14d, [pf_heap]
    dec r12d
    mov eax, [pf_heap+r12*4]        ; last
    ; sift down
    xor ecx, ecx
.sd:
    lea edx, [rcx*2+1]
    cmp edx, r12d
    jge .sdd
    lea r8d, [rdx+1]
    cmp r8d, r12d
    jge .sd1
    mov r9d, [pf_heap+r8*4]
    cmp r9d, [pf_heap+rdx*4]
    jae .sd1
    mov edx, r8d
.sd1:
    mov r9d, [pf_heap+rdx*4]
    cmp eax, r9d
    jbe .sdd
    mov [pf_heap+rcx*4], r9d
    mov ecx, edx
    jmp .sd
.sdd:
    mov [pf_heap+rcx*4], eax
    ; node / cost
    mov ebx, r14d
    and ebx, 0x3FFF
    mov eax, r14d
    shr eax, 14
    cmp ax, [pf_dist+rbx*2]
    ja .pop                         ; stale entry
    cmp ebx, [rbp-52]
    je .found
    mov [rbp-56], eax               ; cost here
    mov eax, ebx
    shl eax, TILE_SHIFT
    movzx r8d, byte [tiles+rax+T_SUB]    ; road mask
    mov [rbp-60], r8d
    xor r9d, r9d                    ; dir
.dir:
    mov r8d, [rbp-60]
    bt r8d, r9d
    jnc .dn
    mov edi, ebx
    and edi, MAP_W-1
    mov esi, ebx
    shr esi, MAP_SHIFT
    add edi, [dir_dx+r9*4]
    add esi, [dir_dy+r9*4]
    cmp edi, MAP_W
    jae .dn
    cmp esi, MAP_W
    jae .dn
    shl esi, MAP_SHIFT
    add esi, edi                    ; neighbour index
    mov eax, esi
    shl eax, TILE_SHIFT
    lea r10, [tiles+rax]
    cmp byte [r10+T_OBJ], OBJ_ROAD
    jne .dn
    ; edge cost: road speed + congestion
    movzx eax, byte [r10+T_ROADTYPE]
    CLAMP eax, 0, 2
    mov ecx, [road_cost_t+rax*4]
    movzx eax, byte [r10+T_OCC+r9]
    shl eax, 1
    add ecx, eax
    movzx eax, byte [r10+T_JAM]
    shr eax, 5
    add ecx, eax
    ; turning costs extra: cars keep to their lane on wide roads and
    ; prefer straight routes instead of zig-zagging through grids
    cmp ebx, [rbp-48]
    je .nturn
    movzx eax, byte [pf_from+rbx]
    cmp eax, r9d
    je .nturn
    add ecx, TURN_COST
.nturn:
    add ecx, [rbp-56]
    cmp ecx, 0xFFF0
    jae .dn
    ; relax
    cmp [pf_stamp+rsi*2], r15w
    jne .newn
    cmp cx, [pf_dist+rsi*2]
    jae .dn
.newn:
    mov [pf_stamp+rsi*2], r15w
    mov [pf_dist+rsi*2], cx
    mov [pf_from+rsi], r9b
    ; push (cost<<14 | node)
    shl ecx, 14
    or ecx, esi
    cmp r12d, 65535
    jae .dn
    mov edx, r12d
    inc r12d
.su:
    test edx, edx
    jz .sud
    lea r8d, [rdx-1]
    shr r8d, 1
    mov eax, [pf_heap+r8*4]
    cmp eax, ecx
    jbe .sud
    mov [pf_heap+rdx*4], eax
    mov edx, r8d
    jmp .su
.sud:
    mov [pf_heap+rdx*4], ecx
.dn:
    inc r9d
    cmp r9d, 4
    jl .dir
    jmp .pop
.found:
    ; walk back to count, then write forwards
    xor ecx, ecx
    mov ebx, [rbp-52]
.cnt:
    cmp ebx, [rbp-48]
    je .cd
    inc ecx
    cmp ecx, MAX_PATH
    jge .fail
    movzx eax, byte [pf_from+rbx]
    movzx edx, byte [dir_rev_t+rax]
    mov edi, ebx
    and edi, MAP_W-1
    mov esi, ebx
    shr esi, MAP_SHIFT
    add edi, [dir_dx+rdx*4]
    add esi, [dir_dy+rdx*4]
    shl esi, MAP_SHIFT
    lea ebx, [rsi+rdi]
    jmp .cnt
.cd:
    mov [pf_len], ecx
    mov ebx, [rbp-52]
    mov edx, ecx
.wr:
    test edx, edx
    jz .ok
    dec edx
    movzx eax, byte [pf_from+rbx]
    mov [pf_path+rdx], al
    movzx eax, byte [dir_rev_t+rax]
    mov edi, ebx
    and edi, MAP_W-1
    mov esi, ebx
    shr esi, MAP_SHIFT
    add edi, [dir_dx+rax*4]
    add esi, [dir_dy+rax*4]
    shl esi, MAP_SHIFT
    lea ebx, [rsi+rdi]
    jmp .wr
.ok:
    mov eax, [pf_len]
    RETURN
.fail:
    mov eax, -1
    RETURN

; ---------------------------------------------------------------------
;  access_road(edi building anchor tile index) -> eax road tile or -1
;  (a local street or avenue within 3 tiles of the footprint)
; ---------------------------------------------------------------------
FUNC access_road, 16
    mov r12d, edi
    mov eax, edi
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    cmp byte [rdi+T_OBJ], OBJ_ROAD
    jne .bld
    mov eax, r12d
    RETURN
.bld:
    call footprint_size
    mov [rbp-48], eax
    mov r15d, 1                     ; ring distance
.ring:
    mov r13d, r15d
    neg r13d                        ; dy
.ry:
    mov eax, [rbp-48]
    dec eax
    add eax, r15d
    cmp r13d, eax
    jg .rn
    mov r14d, r15d
    neg r14d                        ; dx
.rx:
    mov eax, [rbp-48]
    dec eax
    add eax, r15d
    cmp r14d, eax
    jg .ryn
    mov edi, r12d
    and edi, MAP_W-1
    add edi, r14d
    mov esi, r12d
    shr esi, MAP_SHIFT
    add esi, r13d
    cmp edi, MAP_W
    jae .rxn
    cmp esi, MAP_W
    jae .rxn
    shl esi, MAP_SHIFT
    add esi, edi
    mov eax, esi
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    jne .rxn
    cmp byte [tiles+rax+T_ROADTYPE], RT_HIGHWAY
    je .rxn
    mov eax, esi
    RETURN
.rxn:
    inc r14d
    jmp .rx
.ryn:
    inc r13d
    jmp .ry
.rn:
    inc r15d
    cmp r15d, 3
    jle .ring
    mov eax, -1
    RETURN

; nearest link to the region for a trip touching tile edi
; (edi road tile index) -> eax border highway tile
FUNC outside_tile, 16
    ; trips to the region use any highway exit on the same road network
    ; that isn't much farther than the nearest (traffic spreads out)
    mov r12d, edi
    and r12d, MAP_W-1
    mov r13d, edi
    shr r13d, MAP_SHIFT
    movzx eax, word [road_comp+rdi*2]
    mov [rbp-48], eax               ; origin network (0: any)
    mov eax, [hwy_row]
    shl eax, MAP_SHIFT
    mov r15d, eax                   ; fallback: the west highway
    ; pass 1: nearest distance
    mov r14d, 0x7FFFFFFF
    xor ebx, ebx
.l:
    cmp ebx, [n_links]
    jge .p2
    call .dist
    cmp eax, -1
    je .n
    cmp eax, r14d
    jge .n
    mov r14d, eax
    movzx r15d, word [links+rbx*2]
.n:
    inc ebx
    jmp .l
.p2:
    cmp r14d, 0x7FFFFFFF
    je .out
    ; pass 2: pick one of the exits within reach at random
    mov eax, r14d
    shr eax, 1
    lea eax, [r14+rax+16]
    mov [rbp-52], eax               ; limit
    xor ebx, ebx
    xor ecx, ecx
.c:
    cmp ebx, [n_links]
    jge .pick
    push rcx
    push rcx
    call .dist
    pop rcx
    pop rcx
    cmp eax, -1
    je .cn
    cmp eax, [rbp-52]
    jg .cn
    inc ecx
.cn:
    inc ebx
    jmp .c
.pick:
    cmp ecx, 1
    jle .out
    mov [rbp-56], ecx
    call rand
    xor edx, edx
    div dword [rbp-56]
    mov [rbp-56], edx               ; the k-th candidate
    xor ebx, ebx
.f:
    cmp ebx, [n_links]
    jge .out
    call .dist
    cmp eax, -1
    je .fn
    cmp eax, [rbp-52]
    jg .fn
    cmp dword [rbp-56], 0
    je .take
    dec dword [rbp-56]
.fn:
    inc ebx
    jmp .f
.take:
    movzx r15d, word [links+rbx*2]
.out:
    mov eax, r15d
    RETURN
.dist:                              ; link ebx -> eax distance, -1 unreachable
    movzx eax, word [links+rbx*2]
    cmp dword [rbp-48], 0
    je .d0
    movzx ecx, word [road_comp+rax*2]
    cmp ecx, [rbp-48]
    je .d0
    mov eax, -1
    ret
.d0:
    mov ecx, eax
    and ecx, MAP_W-1
    sub ecx, r12d
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx
    shr eax, MAP_SHIFT
    sub eax, r13d
    mov edx, eax
    sar edx, 31
    xor eax, edx
    sub eax, edx
    add eax, ecx
    ret

; collect the region links (border highways) - daily
FUNC collect_links
    mov dword [n_links], 0
    xor r15d, r15d
.l:
    mov eax, r15d
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    jne .n
    mov ecx, r15d
    call is_border_highway
    test ecx, ecx
    jz .n
    mov ecx, [n_links]
    cmp ecx, 64
    jge .n
    mov [links+rcx*2], r15w
    inc dword [n_links]
.n:
    inc r15d
    cmp r15d, MAP_TILES
    jl .l
    RETURN

; ---------------------------------------------------------------------
;  vehicle_spawn(edi from tile, esi to tile, edx type, ecx purpose,
;                r8d destination building, r9d home) -> eax slot or -1
;  from / to are road tiles
; ---------------------------------------------------------------------
FUNC vehicle_spawn, 32
    mov [rbp-48], edi
    mov [rbp-52], esi
    mov [rbp-56], edx
    mov [rbp-60], ecx
    mov [rbp-64], r8d
    mov [rbp-68], r9d
    ; free slot
    xor ebx, ebx
.s:
    cmp ebx, MAX_VEH
    jge .fail
    mov eax, ebx
    shl eax, 7
    cmp byte [vehicles+rax+V_TYPE], 255
    je .have
    inc ebx
    jmp .s
.have:
    lea r15, [vehicles+rax]
    ; no room on the starting road: the trip waits (fire trucks excepted).
    ; Without this, cars piled up without limit on entry tiles.
    cmp dword [rbp-56], VT_FIRE
    je .room
    mov eax, [rbp-48]
    shl eax, TILE_SHIFT
    movzx ecx, byte [tiles+rax+T_ROADTYPE]
    CLAMP ecx, 0, 2
    movzx ecx, byte [road_cap+rcx]
    shl ecx, 1
    movzx edx, byte [tiles+rax+T_OCC]
    movzx r8d, byte [tiles+rax+T_OCC+1]
    add edx, r8d
    movzx r8d, byte [tiles+rax+T_OCC+2]
    add edx, r8d
    movzx r8d, byte [tiles+rax+T_OCC+3]
    add edx, r8d
    cmp edx, ecx
    jge .fail
.room:
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    call path_find
    cmp eax, -1
    je .fail
    test eax, eax
    jz .fail
    mov [r15+V_PLEN], ax
    mov word [r15+V_PPOS], 0
    ; pack path
    xor ecx, ecx
.pk:
    cmp ecx, eax
    jge .pkd
    movzx edx, byte [pf_path+rcx]
    mov r8d, ecx
    shr r8d, 2
    mov r9d, ecx
    and r9d, 3
    shl r9d, 1
    push rcx
    mov ecx, r9d
    shl edx, cl
    pop rcx
    test r9d, r9d
    jnz .pko
    mov byte [r15+V_PATH+r8], 0
.pko:
    or [r15+V_PATH+r8], dl
    inc ecx
    jmp .pk
.pkd:
    mov eax, [rbp-48]
    mov ecx, eax
    and ecx, MAP_W-1
    mov [r15+V_TX], cx
    shr eax, MAP_SHIFT
    mov [r15+V_TY], ax
    movzx eax, byte [pf_path]
    mov [r15+V_DIR], al
    mov [r15+V_INDIR], al
    mov eax, [rbp-56]
    mov [r15+V_TYPE], al
    mov eax, [rbp-60]
    mov [r15+V_PURP], al
    mov dword [r15+V_PROG], 128
    mov eax, [rbp-64]
    mov [r15+V_DST], eax
    mov eax, [rbp-68]
    mov [r15+V_HOME], eax
    mov eax, [rbp-52]
    mov [r15+V_DSTROAD], eax
    mov dword [r15+V_AGE], 0
    mov word [r15+V_WAIT], 0
    mov byte [r15+V_DWELL], 0
    mov byte [r15+V_CARGO], 0
    call rand
    and eax, 7
    mov [r15+V_COLOR], al
    call rand
    and eax, 1
    mov [r15+V_LANE], al
    call rand
    and eax, 7
    mov ecx, [rbp-56]
    add eax, 16
    imul eax, [veh_speed_pct+rcx*4]
    xor edx, edx
    mov ecx, 100
    div ecx
    mov [r15+V_SPD], eax
    ; occupy the start tile
    mov eax, [rbp-48]
    shl eax, TILE_SHIFT
    movzx ecx, byte [r15+V_DIR]
    inc byte [tiles+rax+T_OCC+rcx]
    inc dword [veh_count]
    mov rdi, r15
    call vehicle_position
    mov eax, ebx
    RETURN
.fail:
    mov eax, -1
    RETURN

; path step (rdi vehicle, esi step) -> eax dir
path_step:
    mov eax, esi
    shr eax, 2
    movzx eax, byte [rdi+V_PATH+rax]
    mov ecx, esi
    and ecx, 3
    shl ecx, 1
    shr eax, cl
    and eax, 3
    ret

; free a vehicle (rdi) and release its tile
vehicle_free:
    movzx eax, word [rdi+V_TY]
    shl eax, MAP_SHIFT
    movzx ecx, word [rdi+V_TX]
    add eax, ecx
    shl eax, TILE_SHIFT
    movzx ecx, byte [rdi+V_DIR]
    cmp byte [tiles+rax+T_OCC+rcx], 0
    je .z
    dec byte [tiles+rax+T_OCC+rcx]
.z:
    mov byte [rdi+V_TYPE], 255
    dec dword [veh_count]
    ret

; world position with smooth turns: first half of the tile along the
; entry heading, second half along the exit heading (rdi vehicle)
vehicle_position:
    movzx eax, word [rdi+V_TX]
    shl eax, 8
    add eax, 128
    movzx ecx, word [rdi+V_TY]
    shl ecx, 8
    add ecx, 128
    mov r8d, [rdi+V_PROG]
    sub r8d, 128                    ; -128..128 (1/16 voxel)
    movzx edx, byte [rdi+V_DIR]
    test r8d, r8d
    jns .h
    movzx edx, byte [rdi+V_INDIR]
.h:
    mov r9d, [dir_dx+rdx*4]
    imul r9d, r8d
    add eax, r9d
    mov r9d, [dir_dy+rdx*4]
    imul r9d, r8d
    add ecx, r9d
    ; lane offset to the right of the heading
    movzx r10d, word [rdi+V_TY]
    shl r10d, MAP_SHIFT
    movzx r11d, word [rdi+V_TX]
    add r10d, r11d
    shl r10d, TILE_SHIFT
    movzx r11d, byte [tiles+r10+T_ROADTYPE]
    CLAMP r11d, 0, 2
    mov r10d, [lane_off+r11*4]
    test r11d, r11d
    jz .ln
    cmp byte [rdi+V_LANE], 0
    je .ln
    add r10d, 48                    ; outer lane on wide roads
.ln:
    mov r9d, [dir_dy+rdx*4]
    neg r9d
    imul r9d, r10d
    add eax, r9d
    mov r9d, [dir_dx+rdx*4]
    imul r9d, r10d
    add ecx, r9d
    mov [rdi+V_WX], eax
    mov [rdi+V_WY], ecx
    ret

; ---------------------------------------------------------------------
;  per tick vehicle update
; ---------------------------------------------------------------------
FUNC vehicles_update, 32
    xor ebx, ebx
.l:
    cmp ebx, MAX_VEH
    jge .out
    mov eax, ebx
    shl eax, 7
    lea r15, [vehicles+rax]
    cmp byte [r15+V_TYPE], 255
    je .n
    inc dword [r15+V_AGE]
    ; dwelling (bus at a stop, truck fighting a fire)
    cmp byte [r15+V_DWELL], 0
    je .move
    mov eax, [anim_tick]
    and eax, 7
    jnz .n
    dec byte [r15+V_DWELL]
    jnz .dwfx
    mov rdi, r15
    call vehicle_dwell_done
    jmp .n
.dwfx:
    cmp byte [r15+V_PURP], PU_FIRE
    jne .n
    movzx edi, word [r15+V_TX]
    movzx esi, word [r15+V_TY]
    mov edx, 2
    mov ecx, PK_STEAM
    mov r8d, 6
    call fx_burst
    jmp .n
.move:
    ; current tile
    movzx eax, word [r15+V_TY]
    shl eax, MAP_SHIFT
    movzx ecx, word [r15+V_TX]
    add eax, ecx
    mov r12d, eax                   ; tile index
    shl eax, TILE_SHIFT
    lea r13, [tiles+rax]
    cmp byte [r13+T_OBJ], OBJ_ROAD
    jne .kill
    movzx eax, byte [r13+T_ROADTYPE]
    CLAMP eax, 0, 2
    mov r14d, eax                   ; road type
    mov eax, [road_speed+r14*4]
    imul eax, [r15+V_SPD]
    shr eax, 4
    ; bunching slows traffic on crowded tiles
    movzx ecx, byte [r15+V_DIR]
    movzx ecx, byte [r13+T_OCC+rcx]
    movzx edx, byte [road_cap+r14]
    dec edx
    cmp ecx, edx
    jb .sp
    lea eax, [rax*2+rax]
    shr eax, 2
.sp:
    mov [rbp-48], eax
    add [flow_possible], eax
    mov ecx, [r15+V_PROG]
    add ecx, eax
    ; final tile: arrive at the middle
    movzx edx, word [r15+V_PPOS]
    cmp dx, [r15+V_PLEN]
    jne .mid
    cmp ecx, 128
    jl .adv
    mov rdi, r15
    call vehicle_arrive
    jmp .n
.mid:
    cmp ecx, 256
    jl .adv
    ; try to enter the next tile
    movzx edi, word [r15+V_TX]
    movzx esi, word [r15+V_TY]
    movzx eax, byte [r15+V_DIR]
    add edi, [dir_dx+rax*4]
    add esi, [dir_dy+rax*4]
    cmp edi, MAP_W
    jae .kill
    cmp esi, MAP_W
    jae .kill
    mov [rbp-52], edi
    mov [rbp-56], esi
    call tile_at
    mov r8, rax
    cmp byte [r8+T_OBJ], OBJ_ROAD
    jne .kill
    ; heading on the next tile
    movzx esi, word [r15+V_PPOS]
    inc esi
    movzx eax, byte [r15+V_DIR]
    mov [rbp-60], eax               ; entry heading
    cmp si, [r15+V_PLEN]
    jae .last
    mov rdi, r15
    push r8
    push r8
    call path_step
    pop r8
    pop r8
    jmp .hd
.last:
    mov eax, [rbp-60]
.hd:
    mov [rbp-64], eax               ; next out heading
    ; capacity (emergency vehicles squeeze through)
    movzx ecx, byte [r8+T_OCC+rax]
    movzx edx, byte [r8+T_ROADTYPE]
    CLAMP edx, 0, 2
    movzx edx, byte [road_cap+rdx]
    cmp byte [r15+V_TYPE], VT_FIRE
    jne .cap
    add edx, 3
.cap:
    ; a car stuck for a while squeezes in (breaks gridlock loops)
    cmp word [r15+V_WAIT], 90
    jb .cap2
    add edx, 2
.cap2:
    cmp ecx, edx
    jb .enter
    ; blocked: queue, and after a while look for a way around
    mov dword [r15+V_PROG], 256
    inc word [r15+V_WAIT]
    cmp word [r15+V_WAIT], 200
    jne .nre
    mov esi, [r15+V_DSTROAD]
    cmp esi, MAP_TILES
    jae .nre
    mov rdi, r15
    movzx edx, byte [r15+V_PURP]
    call vehicle_reroute
    jmp .n
.nre:
    movzx eax, byte [r13+T_JAM]
    add eax, 2
    CLAMP eax, 0, 255
    mov [r13+T_JAM], al
    cmp word [r15+V_WAIT], 1200
    jb .n
    ; gridlocked for too long: give up
    inc dword [trips_failed]
    inc dword [trips_stuck]
    jmp .kill
.enter:
    movzx eax, byte [r15+V_DIR]
    cmp byte [r13+T_OCC+rax], 0
    je .e1
    dec byte [r13+T_OCC+rax]
.e1:
    mov eax, [rbp-64]
    inc byte [r8+T_OCC+rax]
    inc word [r8+T_FLOW]
    jnz .e2
    dec word [r8+T_FLOW]
.e2:
    mov eax, [rbp-52]
    mov [r15+V_TX], ax
    mov eax, [rbp-56]
    mov [r15+V_TY], ax
    mov eax, [rbp-60]
    mov [r15+V_INDIR], al
    mov eax, [rbp-64]
    mov [r15+V_DIR], al
    inc word [r15+V_PPOS]
    mov word [r15+V_WAIT], 0
    sub ecx, 256
    mov ecx, [r15+V_PROG]
    add ecx, [rbp-48]
    sub ecx, 256
    CLAMP ecx, 0, 255
.adv:
    mov [r15+V_PROG], ecx
    mov eax, [rbp-48]
    add [flow_moved], eax
    mov rdi, r15
    call vehicle_position
    jmp .n
.kill:
    mov rdi, r15
    call vehicle_free_trip
.n:
    inc ebx
    jmp .l
.out:
    ; traffic flow % (moved vs possible), smoothed
    mov eax, [flow_possible]
    cmp eax, 20000
    jl .o2
    mov eax, [flow_moved]
    imul eax, 100
    xor edx, edx
    div dword [flow_possible]
    mov ecx, [flow_pct]
    lea ecx, [rcx*2+rcx]
    add eax, ecx
    shr eax, 2
    mov [flow_pct], eax
    mov dword [flow_moved], 0
    mov dword [flow_possible], 0
.o2:
    RETURN

; free a vehicle, clearing any job markers it owned
vehicle_free_trip:
    push rdi
    mov eax, [rdi+V_DST]
    cmp eax, MAP_TILES
    jae .f
    shl eax, TILE_SHIFT
    movzx ecx, byte [rdi+V_PURP]
    cmp ecx, PU_FIRE
    jne .g
    and byte [tiles+rax+T_MISC], ~MISC_FTRUCK
.g:
    cmp ecx, PU_GARB
    jne .f
    and byte [tiles+rax+T_MISC], ~MISC_GTRUCK
.f:
    pop rdi
    jmp vehicle_free

; ---------------------------------------------------------------------
;  arrival at the end of the path (rdi vehicle)
; ---------------------------------------------------------------------
FUNC vehicle_arrive
    mov r15, rdi
    movzx eax, byte [r15+V_PURP]
    cmp eax, PU_COMMUTE
    je .commute
    cmp eax, PU_SHOP
    je .done_ok
    cmp eax, PU_VISIT
    je .done_ok
    cmp eax, PU_GOODS
    je .goods
    cmp eax, PU_IMPORT
    je .goods
    cmp eax, PU_EXPORT
    je .export
    cmp eax, PU_FIRE
    je .fire
    cmp eax, PU_GARB
    je .garb
    cmp eax, PU_BUS
    je .bus
    jmp .free                       ; returns and patrols
.commute:
    mov eax, [r15+V_AGE]
    add [commute_sum], eax
    inc dword [commute_n]
    cmp dword [commute_n], 64
    jl .done_ok
    mov eax, [commute_sum]
    shr eax, 6
    mov ecx, [avg_commute]
    add eax, ecx
    shr eax, 1
    mov [avg_commute], eax
    mov dword [commute_sum], 0
    mov dword [commute_n], 0
.done_ok:
    inc dword [trips_ok]
    jmp .free
.goods:
    mov eax, [r15+V_DST]
    cmp eax, MAP_TILES
    jae .free
    shl eax, TILE_SHIFT
    movzx ecx, byte [tiles+rax+T_GOODS]
    add ecx, 90
    CLAMP ecx, 0, 255
    mov [tiles+rax+T_GOODS], cl
    and byte [tiles+rax+T_FLAGS2], ~F2_NOGOODS
    inc dword [trips_ok]
    jmp .free
.export:
    add dword [exports_month], 12
    inc dword [trips_ok]
    jmp .free
.fire:
    ; fight the fire for a while, then extinguish
    mov byte [r15+V_DWELL], 12
    RETURN
.garb:
    ; empty every bin within 3 tiles of the stop
    mov eax, [r15+V_DST]
    cmp eax, MAP_TILES
    jae .ret
    mov r12d, eax
    and r12d, MAP_W-1
    mov r13d, eax
    shr r13d, MAP_SHIFT
    mov r14d, -3
.gy:
    mov ebx, -3
.gx:
    lea edi, [r12+rbx]
    lea esi, [r13+r14]
    call tile_at
    test rax, rax
    jz .gn
    cmp byte [rax+T_OBJ], OBJ_ZONEBLD
    jne .gn
    movzx ecx, byte [rax+T_GARBAGE]
    mov edx, [r15+V_HOME]
    shl edx, TILE_SHIFT
    cmp byte [tiles+rdx+T_SUB], BK_INCIN
    je .inc
    add [landfill_used], ecx
.inc:
    mov byte [rax+T_GARBAGE], 0
    and byte [rax+T_FLAGS2], ~F2_GARBAGE
    and byte [rax+T_MISC], ~MISC_GTRUCK
.gn:
    inc ebx
    cmp ebx, 3
    jle .gx
    inc r14d
    cmp r14d, 3
    jle .gy
    mov dword [r15+V_DST], -1
    jmp .ret
.bus:
    ; pick up passengers
    movzx eax, word [r15+V_TY]
    shl eax, MAP_SHIFT
    movzx ecx, word [r15+V_TX]
    add eax, ecx
    movzx eax, byte [map_transit+rax]
    shr eax, 3
    add [riders_month], eax
    test dword [policies], P_FREEBUS
    jnz .bw
    add [fares_month], eax
.bw:
    mov byte [r15+V_DWELL], 10
    RETURN
.ret:
    ; head home to the depot
    mov rdi, r15
    call vehicle_go_home
    RETURN
.free:
    mov rdi, r15
    call vehicle_free
    RETURN

; after dwelling: fire trucks extinguish, buses leave for the next stop
FUNC vehicle_dwell_done
    mov r15, rdi
    cmp byte [r15+V_PURP], PU_FIRE
    jne .bus
    mov eax, [r15+V_DST]
    cmp eax, MAP_TILES
    jae .home
    mov edi, eax
    and edi, MAP_W-1
    mov esi, eax
    shr esi, MAP_SHIFT
    mov r12d, edi
    mov r13d, esi
    ; put out the fire and its neighbours
    mov r14d, -1
.dy:
    mov ebx, -1
.dx:
    lea edi, [r12+rbx]
    lea esi, [r13+r14]
    call tile_at
    test rax, rax
    jz .dn
    and byte [rax+T_FLAGS], ~F_FIRE
    and byte [rax+T_MISC], ~MISC_FTRUCK
.dn:
    inc ebx
    cmp ebx, 1
    jle .dx
    inc r14d
    cmp r14d, 1
    jle .dy
    lea rdi, [msg_fire_out]
    mov esi, UI_GOOD
    mov edx, r12d
    mov ecx, r13d
    call notify
    mov dword [r15+V_DST], -1
.home:
    mov rdi, r15
    call vehicle_go_home
    RETURN
.bus:
    mov rdi, r15
    call bus_next_stop
    RETURN

; replace the path with one back to the home depot, or vanish
FUNC vehicle_go_home
    mov r15, rdi
    mov edi, [r15+V_HOME]
    cmp edi, MAP_TILES
    jae .free
    call access_road
    cmp eax, -1
    je .free
    mov r12d, eax
    mov edi, r15d
    mov rdi, r15
    mov esi, r12d
    mov edx, PU_RETURN
    call vehicle_reroute
    test eax, eax
    jnz .out
.free:
    mov rdi, r15
    call vehicle_free
.out:
    RETURN

; vehicle_reroute(rdi vehicle, esi destination road tile, edx purpose)
; -> eax 1 ok / 0 no route
FUNC vehicle_reroute
    mov r15, rdi
    mov r12d, esi
    mov r13d, edx
    movzx eax, word [r15+V_TY]
    shl eax, MAP_SHIFT
    movzx ecx, word [r15+V_TX]
    add eax, ecx
    mov r14d, eax
    mov edi, eax
    mov esi, r12d
    call path_find
    cmp eax, -1
    je .no
    test eax, eax
    jz .no
    mov [r15+V_PLEN], ax
    mov word [r15+V_PPOS], 0
    xor ecx, ecx
.pk:
    cmp ecx, eax
    jge .pkd
    movzx edx, byte [pf_path+rcx]
    mov r8d, ecx
    shr r8d, 2
    mov r9d, ecx
    and r9d, 3
    shl r9d, 1
    push rcx
    mov ecx, r9d
    shl edx, cl
    pop rcx
    test r9d, r9d
    jnz .pko
    mov byte [r15+V_PATH+r8], 0
.pko:
    or [r15+V_PATH+r8], dl
    inc ecx
    jmp .pk
.pkd:
    ; move occupancy to the new heading
    mov eax, r14d
    shl eax, TILE_SHIFT
    movzx ecx, byte [r15+V_DIR]
    cmp byte [tiles+rax+T_OCC+rcx], 0
    je .o1
    dec byte [tiles+rax+T_OCC+rcx]
.o1:
    movzx ecx, byte [pf_path]
    inc byte [tiles+rax+T_OCC+rcx]
    mov [r15+V_DIR], cl
    mov [r15+V_INDIR], cl
    mov [r15+V_PURP], r13b
    mov [r15+V_DSTROAD], r12d
    mov word [r15+V_WAIT], 0
    mov dword [r15+V_PROG], 128
    mov dword [r15+V_AGE], 0
    mov eax, 1
    RETURN
.no:
    xor eax, eax
    RETURN

; bus: go to the next stop in the list
FUNC bus_next_stop
    mov r15, rdi
    mov ebx, 4                      ; tries
.t:
    mov ecx, [n_stops]
    cmp ecx, 2
    jl .free
    movzx eax, word [r15+V_STOP]
    inc eax
    xor edx, edx
    div ecx
    mov [r15+V_STOP], dx
    movzx esi, word [stops+rdx*2]
    mov rdi, r15
    mov edx, PU_BUS
    call vehicle_reroute
    test eax, eax
    jnz .out
    dec ebx
    jnz .t
.free:
    mov rdi, r15
    call vehicle_free
.out:
    RETURN

; ---------------------------------------------------------------------
;  trip generation
; ---------------------------------------------------------------------
; random building from a list: (rdi list, esi count) -> eax tile or -1
pick_from:
    test esi, esi
    jz .n
    push rdi
    push rsi
    call rand
    pop rsi
    pop rdi
    xor edx, edx
    div esi
    movzx eax, word [rdi+rdx*2]
    ret
.n: mov eax, -1
    ret

; random job building across commercial, industry and offices
FUNC pick_job
    mov eax, [n_com]
    add eax, [n_ind]
    add eax, [n_off]
    test eax, eax
    jz .none
    mov edi, eax
    call rand_range
    cmp eax, [n_com]
    jl .c
    sub eax, [n_com]
    cmp eax, [n_ind]
    jl .i
    sub eax, [n_ind]
    movzx eax, word [list_off+rax*2]
    RETURN
.i: movzx eax, word [list_ind+rax*2]
    RETURN
.c: movzx eax, word [list_com+rax*2]
    RETURN
.none:
    mov eax, -1
    RETURN

; spawn a trip between two buildings (edi src bld, esi dst bld,
; edx type, ecx purpose). Building -1 = the outside.
FUNC make_trip, 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    ; building ends first
    mov dword [rbp-48], -1
    mov dword [rbp-52], -1
    cmp r12d, -1
    je .s0
    mov edi, r12d
    call access_road
    cmp eax, -1
    je .noroute
    mov [rbp-48], eax
.s0:
    cmp r13d, -1
    je .d0
    mov edi, r13d
    call access_road
    cmp eax, -1
    je .noroute
    mov [rbp-52], eax
.d0:
    ; outside ends: the link nearest the other end
    cmp dword [rbp-48], -1
    jne .s1
    mov edi, [rbp-52]
    cmp edi, -1
    je .out
    call outside_tile
    mov [rbp-48], eax
.s1:
    cmp dword [rbp-52], -1
    jne .d1
    mov edi, [rbp-48]
    call outside_tile
    mov [rbp-52], eax
.d1:
    mov ebx, [rbp-48]
    cmp ebx, [rbp-52]
    je .out
    mov edi, ebx
    mov esi, [rbp-52]
    mov edx, r14d
    mov ecx, r15d
    mov r8d, r13d
    mov r9d, r12d
    call vehicle_spawn
    cmp eax, -1
    jne .ok
.noroute:
    inc dword [trips_failed]
    inc dword [trips_nopath]
    cmp r12d, -1
    je .out
    mov eax, r12d
    shl eax, TILE_SHIFT
    or byte [tiles+rax+T_FLAGS2], F2_NOROUTE
    jmp .out
.ok:
    ; remember the destination road for re-routing
    shl eax, 7
    mov ecx, [rbp-52]
    mov [vehicles+rax+V_DSTROAD], ecx
    cmp r12d, -1
    je .out
    mov ecx, r12d
    shl ecx, TILE_SHIFT
    and byte [tiles+rcx+T_FLAGS2], ~F2_NOROUTE
.out:
    RETURN

FUNC generate_trip
    call rand
    xor edx, edx
    mov ecx, 100
    div ecx
    mov ebx, edx
    cmp ebx, 45
    jl .commute
    cmp ebx, 60
    jl .shop
    cmp ebx, 76
    jl .goods
    cmp ebx, 84
    jl .export
    cmp ebx, 91
    jl .import
    ; visitors from the region
    lea rdi, [list_com]
    mov esi, [n_com]
    call pick_from
    cmp eax, -1
    je .out
    mov esi, eax
    mov edi, -1
    mov edx, VT_CAR
    mov ecx, PU_VISIT
    call make_trip
    jmp .out
.commute:
    lea rdi, [list_res]
    mov esi, [n_res]
    call pick_from
    cmp eax, -1
    je .out
    mov r12d, eax
    call transit_instead
    test eax, eax
    jnz .out
    call pick_job
    mov esi, eax
    cmp esi, -1
    jne .cm
    ; no jobs in town: commute out of the region
.cm:
    mov edi, r12d
    mov edx, VT_CAR
    mov ecx, PU_COMMUTE
    call make_trip
    jmp .out
.shop:
    lea rdi, [list_res]
    mov esi, [n_res]
    call pick_from
    cmp eax, -1
    je .out
    mov r12d, eax
    call transit_instead
    test eax, eax
    jnz .out
    lea rdi, [list_com]
    mov esi, [n_com]
    call pick_from
    cmp eax, -1
    je .out
    mov esi, eax
    mov edi, r12d
    mov edx, VT_CAR
    mov ecx, PU_SHOP
    call make_trip
    jmp .out
.goods:
    ; factory with stock -> shop that needs goods
    lea rdi, [list_ind]
    mov esi, [n_ind]
    call pick_from
    cmp eax, -1
    je .out
    mov r12d, eax
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_GOODS], 50
    jb .out
    sub byte [tiles+rax+T_GOODS], 50
    lea rdi, [list_com]
    mov esi, [n_com]
    call pick_from
    mov esi, eax
    cmp esi, -1
    jne .gs
    mov edi, r12d
    mov esi, -1
    mov edx, VT_TRUCK
    mov ecx, PU_EXPORT
    call make_trip
    jmp .out
.gs:
    mov edi, r12d
    mov edx, VT_TRUCK
    mov ecx, PU_GOODS
    call make_trip
    jmp .out
.export:
    lea rdi, [list_ind]
    mov esi, [n_ind]
    call pick_from
    cmp eax, -1
    je .out
    mov r12d, eax
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_GOODS], 60
    jb .out
    sub byte [tiles+rax+T_GOODS], 60
    mov edi, r12d
    mov esi, -1
    mov edx, VT_TRUCK
    mov ecx, PU_EXPORT
    call make_trip
    jmp .out
.import:
    ; shops short on goods import from the region
    lea rdi, [list_com]
    mov esi, [n_com]
    call pick_from
    cmp eax, -1
    je .out
    mov r12d, eax
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_GOODS], 100
    jae .out
    mov edi, -1
    mov esi, r12d
    mov edx, VT_TRUCK
    mov ecx, PU_IMPORT
    call make_trip
.out:
    RETURN

; residents near a bus stop sometimes ride instead (r12d = home)
; -> eax 1 if the trip went by bus
transit_instead:
    xor eax, eax
    movzx ecx, byte [map_transit+r12]
    cmp ecx, 40
    jb .car
    push rcx
    push rcx
    call rand
    pop rcx
    pop rcx
    and eax, 511
    test dword [policies], P_FREEBUS
    jz .t
    shr eax, 1
.t:
    cmp eax, ecx
    jae .bike
    inc dword [riders_month]
    test dword [policies], P_FREEBUS
    jnz .y
    inc dword [fares_month]
.y: mov eax, 1
    ret
.bike:
.car:
    test dword [policies], P_BIKE
    jz .c
    push rax
    push rax
    call rand
    mov ecx, eax
    pop rax
    pop rax
    and ecx, 7
    cmp ecx, 2
    jae .c
    mov eax, 1
    ret
.c: xor eax, eax
    ret

; ---------------------------------------------------------------------
;  service dispatch (daily)
; ---------------------------------------------------------------------
; count vehicles belonging to a depot tile (edi) -> eax
count_home:
    xor eax, eax
    xor ecx, ecx
.l:
    mov edx, ecx
    shl edx, 7
    cmp byte [vehicles+rdx+V_TYPE], 255
    je .n
    cmp [vehicles+rdx+V_HOME], edi
    jne .n
    inc eax
.n:
    inc ecx
    cmp ecx, MAX_VEH
    jl .l
    ret

FUNC dispatch_services, 32
    call collect_links
    ; gather bus stops
    mov dword [n_stops], 0
    xor r15d, r15d
.bs:
    mov eax, r15d
    shl eax, TILE_SHIFT
    test byte [tiles+rax+T_FLAGS2], F2_BUSSTOP
    jz .bsn
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    jne .bsn
    mov ecx, [n_stops]
    cmp ecx, MAX_STOPS
    jge .bsn
    mov [stops+rcx*2], r15w
    inc dword [n_stops]
.bsn:
    inc r15d
    cmp r15d, MAP_TILES
    jl .bs

    ; fires: send the nearest free fire truck
    xor r15d, r15d
.fire:
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    test byte [rbx+T_FLAGS], F_FIRE
    jz .fn
    test byte [rbx+T_MISC], MISC_FTRUCK
    jnz .fn
    mov edi, r15d
    mov esi, BK_FIRE
    call nearest_service
    cmp eax, -1
    je .fn
    mov r12d, eax                   ; station tile
    mov edi, r12d
    call access_road
    cmp eax, -1
    je .fn
    mov r13d, eax
    mov edi, r15d
    call access_road
    cmp eax, -1
    je .fn
    mov edi, r13d
    mov esi, eax
    mov edx, VT_FIRE
    mov ecx, PU_FIRE
    mov r8d, r15d
    mov r9d, r12d
    call vehicle_spawn
    cmp eax, -1
    je .fn
    or byte [rbx+T_MISC], MISC_FTRUCK
    mov edi, SFX_ALARM
    call sfx_play
.fn:
    inc r15d
    cmp r15d, MAP_TILES
    jl .fire

    ; depots: garbage trucks, police patrols, buses
    call garb_list_make
    call garb_dispatch
    xor r14d, r14d
.dep:
    cmp r14d, [n_svc]
    jge .out
    movzx r12d, word [list_svc+r14*2]
    mov eax, r12d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    movzx edi, byte [rbx+T_SUB]
    mov [rbp-48], edi
    call bld_rec
    mov r15, rax
    movzx eax, byte [r15+BI_VEHICLES]
    test eax, eax
    jz .dn
    mov [rbp-52], eax
    mov edi, r12d
    call count_home
    cmp eax, [rbp-52]
    jge .dn
    ; services need power (landfills don't)
    cmp dword [rbp-48], BK_LANDFILL
    je .pw
    test byte [rbx+T_FLAGS], F_POWER
    jz .dn
.pw:
    mov edi, r12d
    call access_road
    cmp eax, -1
    je .dn
    mov r13d, eax                   ; depot road
    mov eax, [rbp-48]
    cmp eax, BK_POLICE
    je .police
    cmp eax, BK_BUSDEPOT
    je .bus
    jmp .dn
.police:
    ; patrol to a random road nearby
    mov dword [rbp-60], 16
.pt:
    dec dword [rbp-60]
    js .dn
    mov edi, 29
    call rand_range
    sub eax, 14
    mov ecx, r12d
    and ecx, MAP_W-1
    add eax, ecx
    mov [rbp-64], eax
    mov edi, 29
    call rand_range
    sub eax, 14
    mov ecx, r12d
    shr ecx, MAP_SHIFT
    add eax, ecx
    mov esi, eax
    mov edi, [rbp-64]
    call tile_at
    test rax, rax
    jz .pt
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .pt
    sub rax, tiles
    shr eax, TILE_SHIFT
    mov edi, r13d
    mov esi, eax
    mov edx, VT_POLICE
    mov ecx, PU_PATROL
    mov r8d, -1
    mov r9d, r12d
    call vehicle_spawn
    jmp .dn
.bus:
    cmp dword [n_stops], 2
    jl .dn
    mov edi, [n_stops]
    call rand_range
    mov [rbp-64], eax
    movzx esi, word [stops+rax*2]
    mov edi, r13d
    mov edx, VT_BUS
    mov ecx, PU_BUS
    mov r8d, -1
    mov r9d, r12d
    call vehicle_spawn
    cmp eax, -1
    je .dn
    shl eax, 7
    mov ecx, [rbp-64]
    mov [vehicles+rax+V_STOP], cx
.dn:
    inc r14d
    jmp .dep
.out:
    RETURN

; ---------------------------------------------------------------------
;  garbage: once a day, the bins that need a truck; each depot then
;  takes the fullest in its reach.  (Depots used to probe random tiles,
;  which in a big city found a full bin a few times in a thousand tries:
;  trucks sat at home while garbage piled up.)
; ---------------------------------------------------------------------
GARB_CALL   equ 80              ; a bin this full calls for a truck
GARB_MAX    equ 4096
section .bss
garb_cand   resd GARB_MAX       ; building tiles, -1 once taken
garb_n      resd 1
section .text

FUNC garb_list_make
    xor r12d, r12d
    mov r13d, 255                   ; pass 1: overflowing bins first
    mov r14d, 190
.pass:
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ZONEBLD
    jne .n
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .n
    movzx ecx, byte [tiles+rax+T_GARBAGE]
    cmp ecx, r14d
    jb .n
    cmp ecx, r13d
    ja .n
    test byte [tiles+rax+T_MISC], MISC_GTRUCK
    jnz .n
    cmp r12d, GARB_MAX
    jge .o
    mov [garb_cand+r12*4], ebx
    inc r12d
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    cmp r14d, GARB_CALL
    je .o
    mov r13d, 189                   ; pass 2: the rest that call for a truck
    mov r14d, GARB_CALL
    jmp .pass
.o:
    mov [garb_n], r12d
    RETURN

; each bin on the list, fullest first, gets a truck from the nearest depot
; that has one in (a few a day from each), so trucks don't drive across
; the city past a closer depot
GARB_DEPOTS equ 256
section .bss
gd_tile     resd GARB_DEPOTS
gd_road     resd GARB_DEPOTS
gd_free     resd GARB_DEPOTS
gd_rad      resd GARB_DEPOTS
gd_n        resd 1
section .text

FUNC garb_dispatch, 32
    ; the depots with trucks in and a road out
    mov dword [gd_n], 0
    xor r14d, r14d
.dl:
    cmp r14d, [n_svc]
    jge .bins
    movzx r12d, word [list_svc+r14*2]
    mov eax, r12d
    shl eax, TILE_SHIFT
    movzx edi, byte [tiles+rax+T_SUB]
    cmp edi, BK_LANDFILL
    je .lf
    cmp edi, BK_INCIN
    jne .dn
    test byte [tiles+rax+T_FLAGS], F_POWER
    jz .dn
    jmp .ok
.lf:
    mov ecx, [landfill_used]
    cmp ecx, [landfill_cap]
    jae .dn
.ok:
    call bld_rec
    movzx ecx, byte [rax+BI_VEHICLES]
    mov [rbp-48], ecx
    movzx ecx, byte [rax+BI_RADIUS]
    mov [rbp-52], ecx
    mov edi, r12d
    call count_home
    mov ecx, [rbp-48]
    sub ecx, eax
    jle .dn
    CLAMP ecx, 0, 3                 ; a few a day
    mov [rbp-56], ecx
    mov edi, r12d
    call access_road
    cmp eax, -1
    je .dn
    mov ecx, [gd_n]
    cmp ecx, GARB_DEPOTS
    jge .bins
    mov [gd_tile+rcx*4], r12d
    mov [gd_road+rcx*4], eax
    mov edx, [rbp-56]
    mov [gd_free+rcx*4], edx
    mov edx, [rbp-52]
    mov [gd_rad+rcx*4], edx
    inc dword [gd_n]
.dn:
    inc r14d
    jmp .dl
.bins:
    xor r15d, r15d
.b:
    cmp r15d, [garb_n]
    jge .o
    mov r12d, [garb_cand+r15*4]
.search:
    ; the nearest depot in reach with a truck in
    mov r13d, -1
    mov dword [rbp-60], 0x7fffffff
    xor ecx, ecx
.k:
    cmp ecx, [gd_n]
    jge .kd
    cmp dword [gd_free+rcx*4], 0
    jle .kn
    mov eax, [gd_tile+rcx*4]
    mov edx, eax
    and edx, MAP_W-1
    mov r8d, r12d
    and r8d, MAP_W-1
    sub edx, r8d
    mov r8d, edx
    sar r8d, 31
    xor edx, r8d
    sub edx, r8d                    ; |dx|
    cmp edx, [gd_rad+rcx*4]
    jg .kn
    shr eax, MAP_SHIFT
    mov r9d, r12d
    shr r9d, MAP_SHIFT
    sub eax, r9d
    mov r8d, eax
    sar r8d, 31
    xor eax, r8d
    sub eax, r8d                    ; |dy|
    cmp eax, [gd_rad+rcx*4]
    jg .kn
    add eax, edx
    cmp eax, [rbp-60]
    jge .kn
    mov [rbp-60], eax
    mov r13d, ecx
.kn:
    inc ecx
    jmp .k
.kd:
    cmp r13d, -1
    je .next                        ; nothing in reach has a truck
    mov edi, r12d
    call access_road
    cmp eax, -1
    jne .road
    jmp .next
.road:
    mov esi, eax
    mov edi, [gd_road+r13*4]
    mov edx, VT_GARBAGE
    mov ecx, PU_GARB
    mov r8d, r12d
    mov r9d, [gd_tile+r13*4]
    call vehicle_spawn
    cmp eax, -1
    jne .sent
    ; this depot can't send one today (a jammed road, no way there): try
    ; the next nearest
    mov dword [gd_free+r13*4], 0
    jmp .search
.sent:
    dec dword [gd_free+r13*4]
    mov eax, r12d
    shl eax, TILE_SHIFT
    or byte [tiles+rax+T_MISC], MISC_GTRUCK
.next:
    inc r15d
    jmp .b
.o:
    RETURN

; nearest powered service of a kind within its radius (x1.5)
; (edi target tile, esi kind) -> eax service anchor tile or -1
FUNC nearest_service, 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, 0x7FFFFFFF            ; best distance
    mov r15d, -1
    xor ebx, ebx
.l:
    cmp ebx, [n_svc]
    jge .out
    movzx eax, word [list_svc+rbx*2]
    mov ecx, eax
    shl ecx, TILE_SHIFT
    movzx edx, byte [tiles+rcx+T_SUB]
    cmp edx, r13d
    jne .n
    test byte [tiles+rcx+T_FLAGS], F_POWER
    jz .n
    mov [rbp-48], eax
    ; free vehicles?
    push rax
    push rax
    mov edi, eax
    call count_home
    mov ecx, eax
    pop rax
    pop rax
    push rax
    push rcx
    mov edi, r13d
    call bld_rec
    movzx edx, byte [rax+BI_VEHICLES]
    movzx r8d, byte [rax+BI_RADIUS]
    pop rcx
    pop rax
    cmp ecx, edx
    jge .n
    ; distance (manhattan)
    mov ecx, eax
    and ecx, MAP_W-1
    mov edx, r12d
    and edx, MAP_W-1
    sub ecx, edx
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx
    mov edx, eax
    shr edx, MAP_SHIFT
    mov r9d, r12d
    shr r9d, MAP_SHIFT
    sub edx, r9d
    mov r9d, edx
    sar r9d, 31
    xor edx, r9d
    sub edx, r9d
    add ecx, edx
    lea r8d, [r8*2+r8]
    shr r8d, 1
    cmp ecx, r8d
    jg .n
    cmp ecx, r14d
    jge .n
    mov r14d, ecx
    mov r15d, eax
.n:
    inc ebx
    jmp .l
.out:
    mov eax, r15d
    RETURN

; ---------------------------------------------------------------------
;  per tick: trips and movement
; ---------------------------------------------------------------------
FUNC traffic_tick
    ; how many vehicles the city "wants" on the road
    mov eax, [population]
    xor edx, edx
    mov ecx, 11
    div ecx
    mov ecx, [jobs+ZC_COM*4]
    add ecx, [jobs+ZC_IND*4]
    add ecx, [jobs+ZC_OFF*4]
    shr ecx, 5
    add eax, ecx
    add eax, 8
    CLAMP eax, 0, MAX_VEH-120
    mov ebx, eax
    ; spawn a few trips per tick while below target
    mov r12d, 3
.sp:
    cmp [veh_count], ebx
    jge .mv
    call generate_trip
    dec r12d
    jnz .sp
.mv:
    call vehicles_update
    RETURN

; ---------------------------------------------------------------------
;  drawing
; ---------------------------------------------------------------------
FUNC draw_vehicles
    xor ebx, ebx
.c:
    cmp ebx, MAX_VEH
    jge .out
    mov eax, ebx
    shl eax, 7
    lea r15, [vehicles+rax]
    cmp byte [r15+V_TYPE], 255
    je .cn
    mov edi, [r15+V_WX]
    sub edi, 8*16
    mov esi, [r15+V_WY]
    sub esi, 8*16
    mov edx, 16
    call world_proj
    cmp eax, -20
    jl .cn
    mov r8d, [fb_w]
    add r8d, 20
    cmp eax, r8d
    jg .cn
    cmp edx, -20
    jl .cn
    mov r8d, [fb_h]
    add r8d, 20
    cmp edx, r8d
    jg .cn
    mov r12d, eax
    mov r13d, edx
    mov r14d, ecx
    movzx eax, byte [r15+V_TYPE]
    shl eax, 2
    movzx ecx, byte [r15+V_DIR]
    cmp dword [r15+V_PROG], 128
    jge .od
    movzx ecx, byte [r15+V_INDIR]
.od:
    add eax, ecx
    mov edi, [spr_car+rax*4]
    lea r8, [remap_identity]
    cmp byte [r15+V_TYPE], VT_TRUCK
    ja .rc
    movzx eax, byte [r15+V_COLOR]
    shl eax, 8
    lea r8, [remap_cars+rax]
.rc:
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    call blit_sprite
.cn:
    inc ebx
    jmp .c
.out:
    RETURN
