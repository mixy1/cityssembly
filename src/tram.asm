; =====================================================================
;  TRAMS (beta) - rails laid along avenues, a depot, trams that ride
;  in the traffic
;
;  The Tram tool lays rails along avenues ($80 a tile; the road stays a
;  road, cars still use it).  Rails joined up make a line; a Tram Depot
;  touching a line runs it: its trams carry 5,000 a month.  People within
;  4 tiles of a line whose trip ends near the same line may take the
;  tram - quicker than the bus, slower than the metro, and held up by
;  jams like the cars.
; =====================================================================
MISC_TRAM   equ 64              ; T_MISC on a road: tram rails
TRM_COST    equ 80
TRM_REACH   equ 4
TRM_CAP     equ 5000
TRAM_MAX    equ 24
TRAM_SPEED  equ 12              ; of 256 a tile, a step
TM_TRAM     equ 5

section .bss
tw_comp     resw MAP_TILES      ; the line of a tram tile
tw_queue    resw MAP_TILES
tw_lines    resd 1
tw_depot    resb 4096           ; the line has a depot
tw_len      resw 4096           ; its tiles
tw_near     resw MAP_TILES      ; the nearest line (id) of a place, 0 none
tw_dist     resb MAP_TILES
tram_riders_month resd 1
tram_riders resd 1
tram_on     resb TRAM_MAX
tram_line   resw TRAM_MAX
tram_tile   resw TRAM_MAX
tram_dir    resb TRAM_MAX
tram_ndir   resb TRAM_MAX       ; the way on, chosen at the tile's middle
tram_chose  resb TRAM_MAX
tram_prog   resd TRAM_MAX
spr_tramx   resd 16
spr_tram    resd 4

section .data
nm_tramdepot db "Tram Depot", 0
ds_tramdepot db "Runs the tram line it touches.", 0
hb_tramdepot db "Next to tram rails. Its trams run", 10
             db "the whole line, 5,000 riders a", 10
             db "month per depot.", 0
ti_tram     db "Tram rails", 0
hx_tram     db "Drag along avenues to lay tram", 10
            db "rails. A Tram Depot touching them", 10
            db "runs the line.", 10
            db 7, "People near a line ride to", 10
            db 7, "places near the same line.", 0
s_tw_line   db "Tram line: ", 0
s_tw_tiles  db " tiles of rails", 0
s_tw_nodep  db "No tram depot on this line", 0
s_st_tram   db "Tram riders / month", 0

section .text

; a tram tile? (edi, esi) -> eax 1
is_tram:
    call tile_at
    test rax, rax
    jz .no
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .no
    test byte [rax+T_MISC], MISC_TRAM
    jz .no
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; the tram tool on a tile (r12 tile, ecx object) -> eax cost or -1
tram_tile_cost:
    cmp ecx, OBJ_ROAD
    jne .no
    cmp byte [r12+T_ROADTYPE], RT_AVENUE
    jne .no
    test byte [r12+T_FLAGS], F_HIGHWAY
    jnz .no
    test byte [r12+T_MISC], MISC_TRAM
    jnz .no
    mov eax, TRM_COST
    ret
.no:
    mov eax, -1
    ret

tram_lay_tile:
    or byte [r12+T_MISC], MISC_TRAM
    ret

; the rails over a road (render; rdi tile) -> eax sprite or 0
FUNC tramx_sprite
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp byte [rdi+T_OBJ], OBJ_ROAD
    jne .out
    test byte [rdi+T_MISC], MISC_TRAM
    jz .out
    mov rax, rdi
    sub rax, tiles
    shr eax, TILE_SHIFT
    mov r12d, eax
    and r12d, MAP_W-1
    mov r13d, eax
    shr r13d, MAP_SHIFT
    xor ebx, ebx
    xor r14d, r14d
.d:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+r14*4]
    add esi, [dir_dy+r14*4]
    call is_tram
    test eax, eax
    jz .n
    bts ebx, r14d
.n:
    inc r14d
    cmp r14d, 4
    jl .d
    mov eax, [spr_tramx+rbx*4]
.out:
    RETURN

; lines, depots and reach (with the other networks)
FUNC tram_update, 16
    cmp dword [beta_on], 0
    je .out
    lea rdi, [tw_comp]
    mov ecx, MAP_TILES/4
    xor eax, eax
    rep stosq
    lea rdi, [tw_depot]
    mov ecx, 4096/8
    rep stosq
    lea rdi, [tw_len]
    mov ecx, 4096*2/8
    rep stosq
    xor r15d, r15d                  ; lines
    xor ebx, ebx
.t:
    cmp word [tw_comp+rbx*2], 0
    jne .tn
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    jne .tn
    test byte [tiles+rax+T_MISC], MISC_TRAM
    jz .tn
    cmp r15d, 4095
    jge .tn
    inc r15d
    mov [tw_comp+rbx*2], r15w
    mov [tw_queue], bx
    xor r12d, r12d
    mov r13d, 1
.q:
    cmp r12d, r13d
    jge .tn
    movzx r14d, word [tw_queue+r12*2]
    inc r12d
    inc word [tw_len+r15*2]
    xor ecx, ecx
.d:
    mov edi, r14d
    and edi, MAP_W-1
    mov esi, r14d
    shr esi, MAP_SHIFT
    add edi, [dir_dx+rcx*4]
    add esi, [dir_dy+rcx*4]
    cmp edi, MAP_W
    jae .dn
    cmp esi, MAP_W
    jae .dn
    shl esi, MAP_SHIFT
    add esi, edi
    cmp word [tw_comp+rsi*2], 0
    jne .dn
    mov eax, esi
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    jne .dn
    test byte [tiles+rax+T_MISC], MISC_TRAM
    jz .dn
    mov [tw_comp+rsi*2], r15w
    mov [tw_queue+r13*2], si
    inc r13d
.dn:
    inc ecx
    cmp ecx, 4
    jl .d
    jmp .q
.tn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .t
    mov [tw_lines], r15d
    test r15d, r15d
    jz .out
    ; depots: a line tile around the footprint
    xor ebx, ebx
.s:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_SERVICE
    jne .sn
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .sn
    cmp byte [tiles+rax+T_SUB], BK_TRAMDEPOT
    jne .sn
    mov r12d, ebx
    and r12d, MAP_W-1
    mov r13d, ebx
    shr r13d, MAP_SHIFT
    mov r14d, -1
.ry:
    mov r15d, -1
.rx:
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    cmp edi, MAP_W
    jae .rn
    cmp esi, MAP_W
    jae .rn
    shl esi, MAP_SHIFT
    add esi, edi
    movzx eax, word [tw_comp+rsi*2]
    test eax, eax
    jz .rn
    mov byte [tw_depot+rax], 1
.rn:
    inc r15d
    cmp r15d, 2
    jle .rx
    inc r14d
    cmp r14d, 2
    jle .ry
.sn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .s
    ; who's near a running line
    lea rdi, [tw_near]
    mov ecx, MAP_TILES/4
    xor eax, eax
    rep stosq
    lea rdi, [tw_dist]
    mov ecx, MAP_TILES/8
    mov rax, -1
    rep stosq
    xor ebx, ebx
.r:
    movzx r15d, word [tw_comp+rbx*2]
    test r15d, r15d
    jz .rn2
    cmp byte [tw_depot+r15], 0
    je .rn2
    mov r12d, ebx
    and r12d, MAP_W-1
    mov r13d, ebx
    shr r13d, MAP_SHIFT
    mov r14d, -TRM_REACH
.y:
    mov ecx, -TRM_REACH
.x:
    mov eax, r14d
    cdq
    xor eax, edx
    sub eax, edx
    mov edx, ecx
    sar edx, 31
    mov edi, ecx
    xor edi, edx
    sub edi, edx
    add eax, edi
    cmp eax, TRM_REACH
    jg .xn
    lea edi, [r12+rcx]
    lea esi, [r13+r14]
    cmp edi, MAP_W
    jae .xn
    cmp esi, MAP_W
    jae .xn
    shl esi, MAP_SHIFT
    add esi, edi
    cmp al, [tw_dist+rsi]
    jae .xn
    mov [tw_dist+rsi], al
    mov [tw_near+rsi*2], r15w
.xn:
    inc ecx
    cmp ecx, TRM_REACH
    jle .x
    inc r14d
    cmp r14d, TRM_REACH
    jle .y
.rn2:
    inc ebx
    cmp ebx, MAP_TILES
    jl .r
.out:
    RETURN

; a tram trip between buildings r12d and r13d (r14d tiles apart; eax
; the car's slowness x48 in r15d) -> eax cost or -1
tram_trip_cost:
    movzx eax, word [tw_near+r12*2]
    test eax, eax
    jz .no
    cmp ax, [tw_near+r13*2]
    jne .no
    mov eax, [svc_count+BK_TRAMDEPOT*4]
    imul eax, eax, TRM_CAP
    cmp [tram_riders_month], eax
    jge .no
    movzx eax, byte [tw_dist+r12]
    movzx ecx, byte [tw_dist+r13]
    add eax, ecx
    imul eax, eax, 10               ; the walk
    ; the ride: 8 a tile, slower in jams (r15d: 48 .. 148)
    mov ecx, r14d
    imul ecx, r15d
    shr ecx, 3
    add eax, ecx
    add eax, 30                     ; the wait
    ret
.no:
    mov eax, -1
    ret

tram_month:
    cmp dword [beta_on], 0
    je .o
    mov eax, [tram_riders_month]
    mov [tram_riders], eax
    mov dword [tram_riders_month], 0
.o: ret

; ---------------------------------------------------------------------
;  the trams themselves
; ---------------------------------------------------------------------
; a few per running line; they go straight on where they can
FUNC trams_update, 16
    cmp dword [beta_on], 0
    je .out
    ; new ones: a line with a depot and fewer trams than it wants
    mov r15d, 1
.l:
    cmp r15d, [tw_lines]
    jg .mv
    cmp byte [tw_depot+r15], 0
    je .ln
    movzx eax, word [tw_len+r15*2]
    xor edx, edx
    mov ecx, 12
    div ecx
    inc eax
    CLAMP eax, 1, 6
    mov r12d, eax                   ; wanted
    xor ecx, ecx
    xor ebx, ebx
.c:
    cmp byte [tram_on+rbx], 0
    je .cn
    cmp [tram_line+rbx*2], r15w
    jne .cn
    inc ecx
.cn:
    inc ebx
    cmp ebx, TRAM_MAX
    jl .c
    cmp ecx, r12d
    jge .ln
    ; a free tram, at a tile of the line
    xor ebx, ebx
.f:
    cmp byte [tram_on+rbx], 0
    je .fh
    inc ebx
    cmp ebx, TRAM_MAX
    jl .f
    jmp .mv
.fh:
    mov edi, MAP_TILES
    call rand_range
    mov r13d, eax
    mov r14d, MAP_TILES
.ft:
    cmp [tw_comp+r13*2], r15w
    je .fs
    inc r13d
    and r13d, MAP_TILES-1
    dec r14d
    jnz .ft
    jmp .ln
.fs:
    mov byte [tram_on+rbx], 1
    mov [tram_line+rbx*2], r15w
    mov [tram_tile+rbx*2], r13w
    mov edi, 4
    call rand_range
    mov [tram_dir+rbx], al
    mov byte [tram_chose+rbx], 0
    mov dword [tram_prog+rbx*4], 128
.ln:
    inc r15d
    cmp r15d, 4095
    jl .l
.mv:
    xor ebx, ebx
.m:
    cmp byte [tram_on+rbx], 0
    je .mn
    movzx r12d, word [tram_tile+rbx*2]
    ; gone from under it: gone
    movzx eax, word [tram_line+rbx*2]
    cmp [tw_comp+r12*2], ax
    jne .kill
    cmp byte [tw_depot+rax], 0
    je .kill
    add dword [tram_prog+rbx*4], TRAM_SPEED
    cmp dword [tram_prog+rbx*4], 128
    jl .mn
    cmp byte [tram_chose+rbx], 0
    jne .ch
    ; at the middle: the way on - straight, else a turn, else back
    movzx r13d, byte [tram_dir+rbx]
    mov edi, r12d
    mov esi, r13d
    call tram_step_ok
    test eax, eax
    jnz .go
    mov edi, 2
    call rand_range
    lea r14d, [rax*2+1]             ; 1 or 3: a turn one way ..
    lea esi, [r13+r14]
    and esi, 3
    mov edi, r12d
    push rsi
    push rsi
    call tram_step_ok
    pop rsi
    pop rsi
    test eax, eax
    jz .t2
    mov r13d, esi
    jmp .go
.t2:
    lea esi, [r13+r14+2]            ; .. or the other
    and esi, 3
    mov edi, r12d
    push rsi
    push rsi
    call tram_step_ok
    pop rsi
    pop rsi
    test eax, eax
    jz .back
    mov r13d, esi
    jmp .go
.back:
    add r13d, 2
    and r13d, 3
    mov edi, r12d
    mov esi, r13d
    call tram_step_ok
    test eax, eax
    jnz .go
    ; nowhere: wait in the middle
    mov dword [tram_prog+rbx*4], 127
    jmp .mn
.go:
    mov [tram_ndir+rbx], r13b
    mov byte [tram_chose+rbx], 1
.ch:
    cmp dword [tram_prog+rbx*4], 256
    jl .mn
    ; over the edge: into the next tile, that way
    sub dword [tram_prog+rbx*4], 256
    mov byte [tram_chose+rbx], 0
    movzx r13d, byte [tram_ndir+rbx]
    mov [tram_dir+rbx], r13b
    mov edi, r12d
    and edi, MAP_W-1
    add edi, [dir_dx+r13*4]
    mov esi, r12d
    shr esi, MAP_SHIFT
    add esi, [dir_dy+r13*4]
    shl esi, MAP_SHIFT
    add esi, edi
    mov [tram_tile+rbx*2], si
    jmp .mn
.kill:
    mov byte [tram_on+rbx], 0
.mn:
    inc ebx
    cmp ebx, TRAM_MAX
    jl .m
.out:
    RETURN

; can a tram go from tile edi one step in dir esi? -> eax 1
tram_step_ok:
    mov eax, edi
    and eax, MAP_W-1
    add eax, [dir_dx+rsi*4]
    cmp eax, MAP_W
    jae .no
    mov ecx, edi
    shr ecx, MAP_SHIFT
    add ecx, [dir_dy+rsi*4]
    cmp ecx, MAP_W
    jae .no
    shl ecx, MAP_SHIFT
    add ecx, eax
    movzx eax, word [tw_comp+rcx*2]
    test eax, eax
    jz .no
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

FUNC draw_trams, 16
    cmp dword [beta_on], 0
    je .out
    xor ebx, ebx
.t:
    cmp byte [tram_on+rbx], 0
    je .tn
    movzx eax, word [tram_tile+rbx*2]
    movzx ecx, byte [tram_dir+rbx]
    ; (past the middle, along the way on)
    cmp byte [tram_chose+rbx], 0
    je .dd
    movzx ecx, byte [tram_ndir+rbx]
.dd:
    mov edi, eax
    and edi, MAP_W-1
    shl edi, 8
    add edi, 128
    mov esi, eax
    shr esi, MAP_SHIFT
    shl esi, 8
    add esi, 128
    mov eax, [tram_prog+rbx*4]
    sub eax, 128
    mov edx, [dir_dx+rcx*4]
    imul edx, eax
    add edi, edx
    mov edx, [dir_dy+rcx*4]
    imul edx, eax
    add esi, edx
    mov [rbp-48], ecx
    sub edi, 16*16
    sub esi, 16*16
    mov edx, 16
    call world_proj
    cmp eax, -60
    jl .tn
    mov r8d, [fb_w]
    add r8d, 60
    cmp eax, r8d
    jg .tn
    cmp edx, -60
    jl .tn
    mov r8d, [fb_h]
    add r8d, 60
    cmp edx, r8d
    jg .tn
    mov r8d, [rbp-48]
    mov edi, [spr_tram+r8*4]
    mov esi, eax
    lea r8, [remap_identity]
    call blit_sprite
.tn:
    inc ebx
    cmp ebx, TRAM_MAX
    jl .t
.out:
    RETURN

trams_reset:
    push rdi
    push rcx
    lea rdi, [tram_on]
    mov ecx, TRAM_MAX
    xor eax, eax
    rep stosb
    lea rdi, [tram_chose]
    mov ecx, TRAM_MAX
    rep stosb
    mov dword [tw_lines], 0
    pop rcx
    pop rdi
    ret

; a road with rails, or a depot, in the inspector (beta; rbx tile,
; r15d index)
FUNC tram_inspect
    cmp dword [beta_on], 0
    je .out
    movzx r12d, word [tw_comp+r15*2]
    cmp byte [rbx+T_OBJ], OBJ_ROAD
    je .have
    cmp byte [rbx+T_OBJ], OBJ_SERVICE
    jne .out
    cmp byte [rbx+T_SUB], BK_TRAMDEPOT
    jne .out
    ; the line it touches
    xor r12d, r12d
    mov eax, r15d
    and eax, MAP_W-1
    mov r13d, eax
    mov eax, r15d
    shr eax, MAP_SHIFT
    mov r14d, eax
    mov ecx, -1
.y:
    mov edx, -1
.x:
    lea edi, [r13+rdx]
    lea esi, [r14+rcx]
    cmp edi, MAP_W
    jae .xn
    cmp esi, MAP_W
    jae .xn
    shl esi, MAP_SHIFT
    add esi, edi
    movzx eax, word [tw_comp+rsi*2]
    test eax, eax
    jz .xn
    mov r12d, eax
.xn:
    inc edx
    cmp edx, 2
    jle .x
    inc ecx
    cmp ecx, 2
    jle .y
.have:
    test r12d, r12d
    jz .out
    call tb_reset
    lea rdi, [s_tw_line]
    call tb_str
    movzx edi, word [tw_len+r12*2]
    call tb_num
    lea rdi, [s_tw_tiles]
    call tb_str
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
    cmp byte [tw_depot+r12], 0
    jne .out
    lea rdx, [s_tw_nodep]
    mov ecx, UI_BAD
    call row_text
.out:
    RETURN

; ---------------------------------------------------------------------
;  sprites: rails on a road, a tram, the depot
; ---------------------------------------------------------------------
FUNC gen_tramx, 16
    mov r12d, edi
    lea eax, [r12+9900]
    BEGIN 16, 3, eax
    MAT M_METAL
    ; a track in each lane (the middle of an avenue is its median)
    xor ebx, ebx
.a:
    bt r12d, ebx
    jnc .an
    imul eax, ebx, 20
    lea r13, [rail_arm+rax]
    xor r14d, r14d                  ; the four rails across
.r:
    movzx eax, byte [tram_rails+r14]
    mov [rbp-48], eax
    cmp dword [r13+16], 0
    jne .ax
    ; along y: x fixed
    mov edi, eax
    mov esi, [r13+4]
    cmp esi, 5
    jne .y1
    xor esi, esi                    ; (arms reach the middle)
.y1:
    mov r8d, [r13+12]
    cmp r8d, 11
    jne .y2
    mov r8d, 16
.y2:
    mov edx, 1
    lea ecx, [rdi+1]
    mov r9d, 2
    call vbox
    jmp .rn
.ax:
    mov esi, eax
    mov edi, [r13]
    cmp edi, 5
    jne .x1
    xor edi, edi
.x1:
    mov ecx, [r13+8]
    cmp ecx, 11
    jne .x2
    mov ecx, 16
.x2:
    mov edx, 1
    lea r8d, [rsi+1]
    mov r9d, 2
    call vbox
.rn:
    inc r14d
    cmp r14d, 4
    jl .r
.an:
    inc ebx
    cmp ebx, 4
    jl .a
    call finish_model
    RETURN

section .data
tram_rails  db 2, 5, 11, 14     ; the rails across the road
section .text

; a tram (edi dir): two cars, red and cream, a pantograph
FUNC gen_tram
    mov [car_dir], edi
    lea eax, [rdi+9950]
    BEGIN 32, 16, eax
    mov dword [pbox_g], 32
    MAT M_DARK
    PBOX 4,13,0,28,19,2
    MAT M_RED
    PBOX 3,12,2,29,20,5
    MAT M_CREAM
    PBOX 3,12,5,29,20,10
    MAT M_GLASS
    PBOX 4,12,6,15,20,9
    PBOX 17,12,6,28,20,9
    PBOX 29,13,4,30,19,9
    MAT M_DARK
    PBOX 15,12,2,17,20,10
    MAT M_WHITE
    PBOX 3,12,10,29,20,11
    MAT M_METAL
    PBOX 13,15,11,19,17,14
    call finish_model
    RETURN

FUNC bld_tramdepot
    BEGIN 32, 22, 9990
    MAT M_CONCRETE
    BOX 0,0,0,32,32,1
    ; the shed with its doors
    MAT M_BRICK
    BOX 2,6,1,30,28,12
    MAT M_DARK
    BOX 6,27,1,12,28,9
    BOX 18,27,1,24,28,9
    MAT M_ROOF_GREY
    RFY 1,5,12,31,29,6
    ; rails out of the doors
    MAT M_METAL
    BOX 8,28,1,9,32,2
    BOX 10,28,1,11,32,2
    BOX 20,28,1,21,32,2
    BOX 22,28,1,23,32,2
    call finish_model
    RETURN

FUNC tram_sprites_init
    xor ebx, ebx
.x:
    mov edi, ebx
    call gen_tramx
    mov [spr_tramx+rbx*4], eax
    inc ebx
    cmp ebx, 16
    jl .x
    xor ebx, ebx
.t:
    mov edi, ebx
    call gen_tram
    mov [spr_tram+rbx*4], eax
    inc ebx
    cmp ebx, 4
    jl .t
    RETURN
