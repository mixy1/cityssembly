; =====================================================================
;  RAIL (beta) - railways, stations, freight yards and trains
;
;  Track is its own object (OBJ_RAIL), drawn like roads.  Where it
;  crosses a road the road stays and gets a level crossing
;  (MISC_RAILX); cars wait while a train is on it or coming.  Track on
;  the map edge links the line to the region.
;
;  Stations (2x2) next to the track join its line: people near one whose
;  trip ends near another station of the line go by train, and visitors
;  from the region arrive by train when the line reaches the edge.
;  Freight yards (3x3) next to track that reaches the edge ship the
;  exports of industry around them by train instead of by truck.
;
;  Trains are drawn: a locomotive and three coaches shuttling between a
;  line's stations, freight trains between a yard and the edge.
; =====================================================================
RL_REACH    equ 8               ; a walk to a station
RL_FREACH   equ 10              ; industry a freight yard serves
RL_CAP      equ 6000            ; riders a month per station
RL_COST     equ 60              ; a track tile
RL_XCOST    equ 80              ; a level crossing
RL_MAXSTN   equ 128
TR_MAX      equ 32
TR_PATH     equ 256
TR_CARS     equ 4               ; the train's length, locomotive included
TR_SPEED    equ 40              ; of 256 a tile, each step
TM_TRAIN    equ 4

section .bss
rl_comp     resw MAP_TILES      ; the line of each track tile
rl_queue    resw MAP_TILES
rl_from     resb MAP_TILES      ; (paths: the way in)
rl_seen     resw MAP_TILES
rl_gen      resd 1
rl_edge     resw 4096           ; per line: an edge tile + 1 (0: none)
rl_lines    resd 1
rl_stn      resw RL_MAXSTN      ; station anchors
rl_stop     resw RL_MAXSTN      ; the track tile its trains stop at
rl_snet     resw RL_MAXSTN
rl_sfrt     resb RL_MAXSTN      ; 1 = a freight yard
rl_n        resd 1
rl_near     resb MAP_TILES      ; 1 + the nearest passenger station
rl_dist     resb MAP_TILES
rl_fnear    resb MAP_TILES      ; 1 + the freight yard that serves here
rl_occ      resb MAP_TILES*2    ; train on the tile (id + 1), per way:
                                ; +x/+y, then -x/-y (as double track)
rl_block    resb MAP_TILES      ; a level crossing a train is at / near
train_riders_month  resd 1
train_riders        resd 1
rail_visitors_month resd 1
rail_freight_month  resd 1
rail_freight        resd 1
; trains
tr_kind     resb TR_MAX         ; 0 none, 1 passengers, 2 freight
tr_line     resw TR_MAX
tr_len      resw TR_MAX
tr_pos      resw TR_MAX
tr_prog     resd TR_MAX
tr_dwell    resw TR_MAX
tr_next     resw TR_MAX         ; the stop it's going to (slot)
tr_wait     resw TR_MAX         ; steps stuck behind another train
tr_path     resw TR_MAX*TR_PATH

section .data
s_rail      db "Railway", 0
s_railx     db "Level crossing", 0
ti_rail     db "Railway", 0
hx_rail     db "Drag to lay track. It crosses", 10
            db "roads with a level crossing (cars", 10
            db "wait for trains) and bridges water.", 10
            db "Track on the map edge links to", 10
            db "the region.", 10
            db 7, "Stations and freight yards go", 10
            db 7, "next to the track.", 0
hb_railstn  db "Next to the track. People near it", 10
            db "ride trains to other stations on", 10
            db "the line; visitors come by train", 10
            db "when the line reaches the map edge.", 0
hb_freight  db "Next to track that reaches the map", 10
            db "edge: the industry around it ships", 10
            db "its exports by train, not truck.", 0
ov_rail_n   db "Railways", 0
oh_rail     db 7, "station  ", 1, "a walk from one  ", 2, "freight served  ", 3, "not by the track", 0
s_st_train  db "Train riders / month", 0
s_st_frt    db "Freight by rail / month", 0
s_rl_line   db "Line: ", 0
s_rl_stns   db " stations", 0
s_rl_edge   db 2, "Linked to the region", 0
s_rl_noedge db 6, "Not linked to the region", 0
s_rl_none   db 3, "Not next to any track", 0

section .text

; ---------------------------------------------------------------------
;  track tiles
; ---------------------------------------------------------------------
; is (edi, esi) track (rail, or a road with a crossing)? -> eax 1
is_rail:
    call tile_at
    test rax, rax
    jz .no
    cmp byte [rax+T_OBJ], OBJ_RAIL
    je .y
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .no
    test byte [rax+T_MISC], MISC_RAILX
    jz .no
.y: mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; the track's shape at (edi, esi) -> eax mask (edge tiles reach out)
FUNC rail_mask
    mov r12d, edi
    mov r13d, esi
    xor ebx, ebx
    xor r14d, r14d
.d:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+r14*4]
    add esi, [dir_dy+r14*4]
    call is_rail
    test eax, eax
    jz .n
    bts ebx, r14d
.n:
    inc r14d
    cmp r14d, 4
    jl .d
    ; the map edge: out to the region
    test r12d, r12d
    jnz .e1
    or ebx, 8
.e1:
    test r13d, r13d
    jnz .e2
    or ebx, 1
.e2:
    cmp r12d, MAP_W-1
    jne .e3
    or ebx, 2
.e3:
    cmp r13d, MAP_W-1
    jne .e4
    or ebx, 4
.e4:
    mov eax, ebx
    RETURN

; the ground sprite of a track tile (rdi tile, esi x, edx y) -> eax
FUNC rail_ground
    mov rbx, rdi
    movzx eax, byte [rbx+T_SUB]
    and eax, 15
    cmp byte [rbx+T_TERRAIN], TER_WATER
    jne .l
    add eax, 16
.l:
    mov eax, [spr_rail+rax*4]
    RETURN

; the rails to draw over a road with a crossing (rdi tile) -> eax
; sprite or 0
FUNC railx_sprite
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    test byte [rdi+T_MISC], MISC_RAILX
    jz .out
    mov rbx, rdi
    mov rax, rdi
    sub rax, tiles
    shr eax, TILE_SHIFT
    mov edi, eax
    and edi, MAP_W-1
    mov esi, eax
    shr esi, MAP_SHIFT
    call rail_mask
    ; along y (-y or +y arms) or along x
    mov ecx, 1
    test eax, 5
    jnz .s
    xor ecx, ecx
.s:
    mov eax, [spr_railx+rcx*4]
.out:
    RETURN

; ---------------------------------------------------------------------
;  the rail tool
; ---------------------------------------------------------------------
; a tile for the rail tool (r12 tile, ecx object, edx terrain)
; -> eax cost or -1
rail_tile_cost:
    cmp ecx, OBJ_NONE
    je .new
    cmp ecx, OBJ_TREE
    je .new
    cmp ecx, OBJ_RUBBLE
    je .new
    cmp ecx, OBJ_ZONEBLD
    jne .rd
    ; homes and shops make way with Ctrl held
    test dword [ev_keys], 2
    jz .blk
    movzx eax, byte [r12+T_LEVEL]
    imul eax, 12
    add eax, 5+RL_COST
    ret
.blk:
    inc dword [tl_blocked]
    jmp .no
.rd:
    cmp ecx, OBJ_ROAD
    jne .no
    ; a road: a level crossing (not on highways)
    test byte [r12+T_FLAGS], F_HIGHWAY
    jnz .no
    cmp byte [r12+T_ROADTYPE], RT_HIGHWAY
    je .no
    test byte [r12+T_MISC], MISC_RAILX
    jnz .no
    mov eax, RL_XCOST
    ret
.new:
    mov eax, RL_COST
    cmp edx, TER_WATER
    jne .o
    imul eax, eax, 3                ; bridges
.o: ret
.no:
    mov eax, -1
    ret

; lay track on a tile (r12 tile; r13d, r14d its x, y)
rail_lay_tile:
    cmp byte [r12+T_OBJ], OBJ_ROAD
    jne .z
    or byte [r12+T_MISC], MISC_RAILX
    ret
.z:
    cmp byte [r12+T_OBJ], OBJ_ZONEBLD
    jne .t
    ; a building in the way comes down (Ctrl); its rubble is swept
    push rdi
    push rsi
    mov edi, r13d
    mov esi, r14d
    call destroy_to_rubble
    pop rsi
    pop rdi
.t:
    mov byte [r12+T_OBJ], OBJ_RAIL
    mov byte [r12+T_ZONE], 0
    mov byte [r12+T_FLAGS], 0
    mov byte [r12+T_LEVEL], 0
    mov word [r12+T_POP], 0
    mov dword [r12+T_OCC], 0
    mov byte [r12+T_PROBLEM], 0
    ret

; ---------------------------------------------------------------------
;  lines, stations, reach (with the other networks)
; ---------------------------------------------------------------------
FUNC rail_update, 32
    cmp dword [beta_on], 0
    je .out
    lea rdi, [rl_comp]
    mov ecx, MAP_TILES/4
    xor eax, eax
    rep stosq
    lea rdi, [rl_edge]
    mov ecx, 4096*2/8
    rep stosq
    xor r15d, r15d
    xor ebx, ebx
.t:
    cmp word [rl_comp+rbx*2], 0
    jne .tn
    mov edi, ebx
    and edi, MAP_W-1
    mov esi, ebx
    shr esi, MAP_SHIFT
    call is_rail
    test eax, eax
    jz .tn
    cmp r15d, 4095
    jge .tn
    inc r15d
    mov [rl_comp+rbx*2], r15w
    mov [rl_queue], bx
    xor r12d, r12d
    mov r13d, 1
.q:
    cmp r12d, r13d
    jge .tn
    movzx r14d, word [rl_queue+r12*2]
    inc r12d
    ; an edge tile links the line to the region
    mov eax, r14d
    and eax, MAP_W-1
    jz .edge
    cmp eax, MAP_W-1
    je .edge
    mov eax, r14d
    shr eax, MAP_SHIFT
    jz .edge
    cmp eax, MAP_W-1
    jne .ne
.edge:
    lea eax, [r14+1]
    mov [rl_edge+r15*2], ax
.ne:
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
    mov eax, esi
    shl eax, MAP_SHIFT
    add eax, edi
    cmp word [rl_comp+rax*2], 0
    jne .dn
    push rcx
    push rax
    call is_rail
    mov edx, eax
    pop rax
    pop rcx
    test edx, edx
    jz .dn
    mov [rl_comp+rax*2], r15w
    mov [rl_queue+r13*2], ax
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
    mov [rl_lines], r15d
    ; stations and yards: the track tile next to them
    mov dword [rl_n], 0
    xor ebx, ebx
.s:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_SERVICE
    jne .sn
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .sn
    movzx ecx, byte [tiles+rax+T_SUB]
    xor edx, edx
    cmp ecx, BK_RAILSTN
    je .sk
    mov edx, 1
    cmp ecx, BK_FREIGHT
    jne .sn
.sk:
    mov r12d, [rl_n]
    cmp r12d, RL_MAXSTN
    jge .reach
    mov [rl_stn+r12*2], bx
    mov [rl_sfrt+r12], dl
    mov word [rl_snet+r12*2], 0
    mov word [rl_stop+r12*2], 0
    ; the ring around its footprint
    mov edi, ebx
    and edi, MAP_W-1
    mov esi, ebx
    shr esi, MAP_SHIFT
    mov edx, 2
    cmp byte [rl_sfrt+r12], 0
    je .sz
    mov edx, 3
.sz:
    call rail_ring
    cmp eax, -1
    je .sadd
    mov [rl_stop+r12*2], ax
    movzx eax, word [rl_comp+rax*2]
    mov [rl_snet+r12*2], ax
.sadd:
    inc dword [rl_n]
.sn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .s
.reach:
    ; who is a walk from a station, and what a yard serves
    lea rdi, [rl_near]
    mov ecx, MAP_TILES/8
    xor eax, eax
    rep stosq
    lea rdi, [rl_fnear]
    mov ecx, MAP_TILES/8
    rep stosq
    lea rdi, [rl_dist]
    mov ecx, MAP_TILES/8
    mov rax, -1
    rep stosq
    xor ebx, ebx
.r:
    cmp ebx, [rl_n]
    jge .out
    cmp word [rl_snet+rbx*2], 0
    je .rn
    movzx eax, word [rl_stn+rbx*2]
    mov r12d, eax
    and r12d, MAP_W-1
    mov r13d, eax
    shr r13d, MAP_SHIFT
    mov eax, RL_REACH
    cmp byte [rl_sfrt+rbx], 0
    je .rr
    mov eax, RL_FREACH
.rr:
    mov [rbp-48], eax
    mov r14d, eax
    neg r14d
.ry:
    mov r15d, [rbp-48]
    neg r15d
.rx:
    mov eax, r14d
    cdq
    xor eax, edx
    sub eax, edx
    mov ecx, r15d
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx
    add eax, ecx
    cmp eax, [rbp-48]
    jg .rxn
    lea edi, [r12+r15+1]            ; (from the middle of the 2x2)
    lea esi, [r13+r14+1]
    cmp edi, MAP_W
    jae .rxn
    cmp esi, MAP_W
    jae .rxn
    shl esi, MAP_SHIFT
    add esi, edi
    lea ecx, [rbx+1]
    cmp byte [rl_sfrt+rbx], 0
    jne .fr
    cmp al, [rl_dist+rsi]
    jae .rxn
    mov [rl_dist+rsi], al
    mov [rl_near+rsi], cl
    jmp .rxn
.fr:
    mov [rl_fnear+rsi], cl
.rxn:
    inc r15d
    cmp r15d, [rbp-48]
    jle .rx
    inc r14d
    cmp r14d, [rbp-48]
    jle .ry
.rn:
    inc ebx
    jmp .r
.out:
    call port_rail
    RETURN

; a track tile touching the n x n footprint at (edi, esi), edx = n
; -> eax tile index or -1
FUNC rail_ring
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov ebx, -1
.y:
    mov r15d, -1
.x:
    ; the ring only (not inside, not the corners)
    mov eax, ebx
    or eax, r15d
    js .edge
    cmp ebx, r14d
    je .edge
    cmp r15d, r14d
    je .edge
    jmp .n
.edge:
    ; corners are no good (diagonal)
    mov eax, ebx
    cmp eax, -1
    je .cy
    cmp eax, r14d
    jne .ok
.cy:
    cmp r15d, -1
    je .n
    cmp r15d, r14d
    je .n
.ok:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    push rdi
    push rsi
    call is_rail
    pop rsi
    pop rdi
    test eax, eax
    jz .n
    shl esi, MAP_SHIFT
    lea eax, [rsi+rdi]
    RETURN
.n:
    inc r15d
    cmp r15d, r14d
    jle .x
    inc ebx
    cmp ebx, r14d
    jle .y
    mov eax, -1
    RETURN

; ---------------------------------------------------------------------
;  paths along the track (breadth first): edi from tile, esi to tile,
;  ecx train -> eax length (tiles, from included) or 0
; ---------------------------------------------------------------------
FUNC rail_path, 16
    mov [rbp-48], edi
    mov [rbp-52], esi
    mov [rbp-56], ecx
    inc dword [rl_gen]
    mov eax, [rl_gen]
    and eax, 0xFFFF
    jnz .g
    lea rdi, [rl_seen]
    mov ecx, MAP_TILES/4
    xor eax, eax
    rep stosq
    mov dword [rl_gen], 1
    mov eax, 1
.g:
    mov r15d, eax
    mov ebx, [rbp-48]
    mov [rl_seen+rbx*2], r15w
    mov [rl_queue], bx
    xor r12d, r12d
    mov r13d, 1
.q:
    cmp r12d, r13d
    jge .none
    movzx r14d, word [rl_queue+r12*2]
    inc r12d
    cmp r14d, [rbp-52]
    je .found
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
    mov eax, esi
    shl eax, MAP_SHIFT
    add eax, edi
    cmp [rl_seen+rax*2], r15w
    je .dn
    push rcx
    push rax
    call is_rail
    mov edx, eax
    pop rax
    pop rcx
    test edx, edx
    jz .dn
    mov [rl_seen+rax*2], r15w
    mov [rl_from+rax], cl
    mov [rl_queue+r13*2], ax
    inc r13d
.dn:
    inc ecx
    cmp ecx, 4
    jl .d
    jmp .q
.found:
    ; count back, then write the tiles forwards
    xor ecx, ecx
    mov ebx, [rbp-52]
.c:
    inc ecx
    cmp ebx, [rbp-48]
    je .cw
    movzx eax, byte [rl_from+rbx]
    movzx eax, byte [dir_rev_t+rax]
    mov edx, [dir_dy+rax*4]
    shl edx, MAP_SHIFT
    add edx, [dir_dx+rax*4]
    add ebx, edx
    jmp .c
.cw:
    cmp ecx, TR_PATH
    jg .none
    mov [rbp-60], ecx
    mov eax, [rbp-56]
    imul eax, eax, TR_PATH*2
    lea r12, [tr_path+rax]
    mov ebx, [rbp-52]
    mov edx, ecx
.w:
    dec edx
    mov [r12+rdx*2], bx
    test edx, edx
    jz .done
    movzx eax, byte [rl_from+rbx]
    movzx eax, byte [dir_rev_t+rax]
    mov r8d, [dir_dy+rax*4]
    shl r8d, MAP_SHIFT
    add r8d, [dir_dx+rax*4]
    add ebx, r8d
    jmp .w
.done:
    mov eax, [rbp-60]
    RETURN
.none:
    xor eax, eax
    RETURN

; ---------------------------------------------------------------------
;  trains
; ---------------------------------------------------------------------
; the next stop for train ecx after slot eax on its line (passengers:
; the next station; freight: 0xFFFF = the edge, else a yard) -> eax
; slot or -1
FUNC train_next_stop
    mov r12d, ecx
    mov r13d, eax
    movzx r14d, word [tr_line+r12*2]
    cmp byte [tr_kind+r12], 2
    jne .pass
    ; freight: a yard, then the edge, and back
    cmp r13d, 0xFFFF
    jne .toedge
    xor ebx, ebx
.fy:
    cmp ebx, [rl_n]
    jge .no
    cmp byte [rl_sfrt+rbx], 0
    je .fn
    cmp [rl_snet+rbx*2], r14w
    jne .fn
    ; (not the yard at a port, when that's where the line leaves)
    movzx eax, word [rl_stop+rbx*2]
    inc eax
    cmp ax, [rl_edge+r14*2]
    jne .yes
.fn:
    inc ebx
    jmp .fy
.toedge:
    mov eax, 0xFFFF
    RETURN
.pass:
    mov ebx, r13d
    mov ecx, [rl_n]
.l:
    inc ebx
    cmp ebx, [rl_n]
    jl .c
    xor ebx, ebx
.c:
    cmp byte [rl_sfrt+rbx], 0
    jne .n
    cmp [rl_snet+rbx*2], r14w
    je .yes
.n:
    dec ecx
    jg .l
.no:
    mov eax, -1
    RETURN
.yes:
    mov eax, ebx
    RETURN

; the tile a stop slot is at (eax slot, 0xFFFF the line's edge) -> eax
train_stop_tile:
    cmp eax, 0xFFFF
    jne .s
    movzx eax, word [tr_line+rcx*2]
    movzx eax, word [rl_edge+rax*2]
    dec eax
    ret
.s: movzx eax, word [rl_stop+rax*2]
    ret

; the way (0 +x/+y, 1 -x/-y) train r12d's path goes at index eax
; (r14 its path) -> ecx
train_way:
    push rax
    push rdi
    push rsi
    movzx ecx, word [tr_len+r12*2]
    lea edx, [rax+1]
    cmp edx, ecx
    jl .f
    ; the last tile: the way it came in
    test eax, eax
    jz .z
    movzx edi, word [r14+rax*2-2]
    movzx esi, word [r14+rax*2]
    jmp .h
.f:
    movzx edi, word [r14+rax*2]
    movzx esi, word [r14+rdx*2]
.h:
    call tile_heading
    xor ecx, ecx
    cmp eax, 0
    je .neg
    cmp eax, 3
    jne .o
.neg:
    mov ecx, 1
    jmp .o
.z: xor ecx, ecx
.o: pop rsi
    pop rdi
    pop rax
    ret

; mark (esi 1) or clear (esi 0) train edi's tiles and the crossings it
; is at or about to cross
FUNC train_mark
    mov r12d, edi
    mov r13d, esi
    imul eax, r12d, TR_PATH*2
    lea r14, [tr_path+rax]
    movzx r15d, word [tr_pos+r12*2]
    ; its cars: pos back to pos-3; the way ahead: pos+1, pos+2
    mov ebx, -(TR_CARS-1)
.l:
    lea eax, [r15+rbx]
    test eax, eax
    js .n
    movzx ecx, word [tr_len+r12*2]
    cmp eax, ecx
    jge .n
    push rax
    call train_way
    mov r8d, ecx
    pop rax
    movzx ecx, word [r14+rax*2]
    xor edx, edx
    test r13d, r13d
    jz .m
    lea edx, [r12+1]
.m:
    test ebx, ebx
    jg .blk
    ; (its own way's track only)
    imul r8d, r8d, MAP_TILES
    add r8d, ecx
    mov [rl_occ+r8], dl
.blk:
    mov [rl_block+rcx], dl
.n:
    inc ebx
    cmp ebx, 2
    jle .l
    RETURN

; a new train on line edi of kind esi, at stop slot edx
FUNC train_spawn
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    xor ebx, ebx
.f:
    cmp ebx, TR_MAX
    jge .out
    cmp byte [tr_kind+rbx], 0
    je .have
    inc ebx
    jmp .f
.have:
    mov [tr_kind+rbx], r13b
    mov [tr_line+rbx*2], r12w
    ; a one-tile path at the stop: it starts dwelling there
    mov eax, r14d
    mov ecx, ebx
    call train_stop_tile
    imul ecx, ebx, TR_PATH*2
    mov [tr_path+rcx], ax
    mov word [tr_len+rbx*2], 1
    mov word [tr_pos+rbx*2], 0
    mov dword [tr_prog+rbx*4], 128
    mov word [tr_dwell+rbx*2], 60
    mov [tr_next+rbx*2], r14w
.out:
    RETURN

; how many trains each line runs, kept right (daily, beta)
FUNC trains_manage, 32
    cmp dword [beta_on], 0
    je .out
    ; trains whose line changed or went: gone
    xor ebx, ebx
.k:
    cmp byte [tr_kind+rbx], 0
    je .kn
    movzx eax, word [tr_pos+rbx*2]
    imul ecx, ebx, TR_PATH*2
    movzx eax, word [tr_path+rcx+rax*2]
    movzx eax, word [rl_comp+rax*2]
    cmp ax, [tr_line+rbx*2]
    je .kn
    mov edi, ebx
    xor esi, esi
    call train_mark
    mov byte [tr_kind+rbx], 0
.kn:
    inc ebx
    cmp ebx, TR_MAX
    jl .k
    ; per line: a passenger train per two stations (two stations at
    ; least), a freight train per yard when the line reaches the edge
    mov r15d, 1
.line:
    cmp r15d, [rl_lines]
    jg .out
    xor r12d, r12d                  ; stations
    xor r13d, r13d                  ; yards
    mov dword [rbp-48], -1          ; a station slot
    mov dword [rbp-52], -1          ; a yard slot
    xor ebx, ebx
.c:
    cmp ebx, [rl_n]
    jge .cd
    cmp [rl_snet+rbx*2], r15w
    jne .cn
    cmp byte [rl_sfrt+rbx], 0
    jne .cy
    inc r12d
    mov [rbp-48], ebx
    jmp .cn
.cy:
    inc r13d
    mov [rbp-52], ebx
.cn:
    inc ebx
    jmp .c
.cd:
    ; wanted
    xor eax, eax
    cmp r12d, 2
    jl .w1
    mov eax, r12d
    inc eax
    shr eax, 1
    CLAMP eax, 1, 6
.w1:
    mov [rbp-56], eax
    xor eax, eax
    cmp word [rl_edge+r15*2], 0
    je .w2
    mov eax, r13d
    CLAMP eax, 0, 4
.w2:
    mov [rbp-60], eax
    ; running now
    xor ecx, ecx
    xor edx, edx
    xor ebx, ebx
.r:
    cmp [tr_line+rbx*2], r15w
    jne .rn
    cmp byte [tr_kind+rbx], 1
    jne .r2
    inc ecx
    jmp .rn
.r2:
    cmp byte [tr_kind+rbx], 2
    jne .rn
    inc edx
.rn:
    inc ebx
    cmp ebx, TR_MAX
    jl .r
    cmp ecx, [rbp-56]
    jge .fr
    mov edi, r15d
    mov esi, 1
    mov edx, [rbp-48]
    call train_spawn
.fr:
    cmp edx, [rbp-60]
    jge .ln
    cmp dword [rbp-52], 0
    jl .ln
    mov edi, r15d
    mov esi, 2
    mov edx, [rbp-52]
    call train_spawn
.ln:
    inc r15d
    jmp .line
.out:
    RETURN

; every traffic step (beta): trains move, stop, and set off again
FUNC trains_update, 16
    cmp dword [beta_on], 0
    je .out
    xor ebx, ebx
.t:
    cmp byte [tr_kind+rbx], 0
    je .n
    cmp word [tr_dwell+rbx*2], 0
    je .move
    dec word [tr_dwell+rbx*2]
    jnz .n
    ; off to the next stop
    mov edi, ebx
    xor esi, esi
    call train_mark
    movzx eax, word [tr_next+rbx*2]
    mov ecx, ebx
    call train_next_stop
    cmp eax, -1
    je .idle
    mov [tr_next+rbx*2], ax
    mov ecx, ebx
    call train_stop_tile
    mov r12d, eax
    movzx eax, word [tr_pos+rbx*2]
    imul ecx, ebx, TR_PATH*2
    movzx edi, word [tr_path+rcx+rax*2]
    mov esi, r12d
    mov ecx, ebx
    call rail_path
    cmp eax, 2
    jl .idle
    mov [tr_len+rbx*2], ax
    mov word [tr_pos+rbx*2], 0
    mov dword [tr_prog+rbx*4], 128
    mov edi, ebx
    mov esi, 1
    call train_mark
    jmp .n
.idle:
    ; nowhere to go now: try again in a while
    mov word [tr_dwell+rbx*2], 120
    mov edi, ebx
    mov esi, 1
    call train_mark
    jmp .n
.move:
    mov eax, [tr_prog+rbx*4]
    add eax, TR_SPEED
    cmp eax, 256
    jl .adv
    ; into the next tile - unless another train is there
    movzx ecx, word [tr_pos+rbx*2]
    inc ecx
    movzx edx, word [tr_len+rbx*2]
    cmp ecx, edx
    jge .arrive
    push rax
    imul edx, ebx, TR_PATH*2
    lea r14, [tr_path+rdx]
    mov r12d, ebx
    mov eax, ecx
    dec eax                         ; the step into it is from pos
    push rcx
    call train_way
    mov r8d, ecx
    pop rcx
    pop rax
    movzx edx, word [r14+rcx*2]
    imul r8d, r8d, MAP_TILES
    add r8d, edx
    movzx r8d, byte [rl_occ+r8]
    test r8d, r8d
    jz .go
    lea r9d, [rbx+1]
    cmp r8d, r9d
    je .go
    mov dword [tr_prog+rbx*4], 255
    ; stuck a long while: look for the way again from here
    inc word [tr_wait+rbx*2]
    cmp word [tr_wait+rbx*2], 400
    jb .n
    mov word [tr_wait+rbx*2], 0
    mov word [tr_dwell+rbx*2], 1
    ; (keep the same stop as the target)
    movzx eax, word [tr_next+rbx*2]
    jmp .n
.go:
    mov word [tr_wait+rbx*2], 0
    push rax
    push rax
    mov edi, ebx
    xor esi, esi
    call train_mark
    inc word [tr_pos+rbx*2]
    mov edi, ebx
    mov esi, 1
    call train_mark
    pop rax
    pop rax
    sub eax, 256
.adv:
    mov [tr_prog+rbx*4], eax
    jmp .n
.arrive:
    ; at the stop: a while to load up
    mov dword [tr_prog+rbx*4], 128
    mov word [tr_dwell+rbx*2], 90
    cmp byte [tr_kind+rbx], 2
    jne .n
    inc dword [rail_freight_month]
.n:
    inc ebx
    cmp ebx, TR_MAX
    jl .t
.out:
    RETURN

; a road vehicle about to enter a level crossing a train is at or
; coming to (r8 tile) -> eax 1 to wait
crossing_closed:
    xor eax, eax
    test byte [r8+T_MISC], MISC_RAILX
    jz .o
    mov rax, r8
    sub rax, tiles
    shr eax, TILE_SHIFT
    movzx eax, byte [rl_block+rax]
    test eax, eax
    setnz al
.o: ret

; the heading from tile a (edi) to the next tile b (esi) -> eax dir
tile_heading:
    mov eax, esi
    sub eax, edi
    cmp eax, -MAP_W
    je .n
    cmp eax, 1
    je .e
    cmp eax, MAP_W
    je .s
    mov eax, 3
    ret
.n: xor eax, eax
    ret
.e: mov eax, 1
    ret
.s: mov eax, 2
    ret

; draw the trains (with the agents)
FUNC draw_trains, 32
    cmp dword [beta_on], 0
    je .out
    xor ebx, ebx
.t:
    cmp byte [tr_kind+rbx], 0
    je .tn
    imul eax, ebx, TR_PATH*2
    lea r14, [tr_path+rax]
    xor r15d, r15d                  ; car
.c:
    cmp r15d, TR_CARS
    jge .tn
    movzx eax, word [tr_pos+rbx*2]
    sub eax, r15d
    js .tn
    mov [rbp-48], eax               ; its path index
    movzx r12d, word [r14+rax*2]    ; its tile
    ; its heading: toward the next tile (or from the one before)
    movzx ecx, word [tr_len+rbx*2]
    lea edx, [rax+1]
    cmp edx, ecx
    jge .back
    movzx esi, word [r14+rdx*2]
    mov edi, r12d
    call tile_heading
    jmp .hd
.back:
    xor eax, eax
    test edx, edx
    jz .hd
    mov eax, [rbp-48]
    test eax, eax
    jz .hz
    movzx edi, word [r14+rax*2-2]
    mov esi, r12d
    call tile_heading
    jmp .hd
.hz:
    mov eax, 1
.hd:
    mov [rbp-52], eax
    ; where on the tile: the train's progress along the heading
    mov edi, r12d
    and edi, MAP_W-1
    shl edi, 8
    add edi, 128
    mov esi, r12d
    shr esi, MAP_SHIFT
    shl esi, 8
    add esi, 128
    mov eax, [tr_prog+rbx*4]
    sub eax, 128
    mov ecx, [rbp-52]
    mov edx, [dir_dx+rcx*4]
    imul edx, eax
    add edi, edx
    mov edx, [dir_dy+rcx*4]
    imul edx, eax
    add esi, edx
    sub edi, 8*16
    sub esi, 8*16
    mov edx, 16
    call world_proj
    cmp eax, -30
    jl .cn
    mov r8d, [fb_w]
    add r8d, 30
    cmp eax, r8d
    jg .cn
    cmp edx, -30
    jl .cn
    mov r8d, [fb_h]
    add r8d, 30
    cmp edx, r8d
    jg .cn
    mov [rbp-56], eax
    mov [rbp-60], edx
    mov [rbp-64], ecx
    ; the sprite: locomotive first, then coaches or wagons
    xor eax, eax
    test r15d, r15d
    jz .sp
    mov eax, 1
    cmp byte [tr_kind+rbx], 2
    jne .sp
    mov eax, 2
.sp:
    shl eax, 2
    add eax, [rbp-52]
    mov edi, [spr_train+rax*4]
    mov esi, [rbp-56]
    mov edx, [rbp-60]
    mov ecx, [rbp-64]
    lea r8, [remap_identity]
    call blit_sprite
.cn:
    inc r15d
    jmp .c
.tn:
    inc ebx
    cmp ebx, TR_MAX
    jl .t
.out:
    RETURN

; ---------------------------------------------------------------------
;  travel by train, visitors and freight
; ---------------------------------------------------------------------
; a train trip between buildings r12d and r13d (r14d tiles apart)?
; -> eax its cost, or -1
rail_trip_cost:
    movzx eax, byte [rl_near+r12]
    movzx ecx, byte [rl_near+r13]
    test eax, eax
    jz .no
    test ecx, ecx
    jz .no
    cmp eax, ecx
    je .no
    movzx edx, word [rl_snet+rax*2-2]
    test edx, edx
    jz .no
    cmp dx, [rl_snet+rcx*2-2]
    jne .no
    movzx eax, byte [rl_dist+r12]
    movzx ecx, byte [rl_dist+r13]
    add eax, ecx
    imul eax, eax, 10
    lea eax, [rax+r14*2]
    add eax, 50
    ret
.no:
    mov eax, -1
    ret

; a visitor from the region to building edi: by train, if a station
; near it is on a line that reaches the edge -> eax 1 (no car)
FUNC rail_visitor
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp edi, MAP_TILES
    jae .out
    movzx ecx, byte [rl_near+rdi]
    test ecx, ecx
    jz .out
    movzx ecx, word [rl_snet+rcx*2-2]
    cmp word [rl_edge+rcx*2], 0
    je .out
    call rand
    and eax, 3
    jz .no                          ; some still drive
    inc dword [rail_visitors_month]
    inc dword [train_riders_month]
    add dword [fares_month], 3
    mov eax, 1
    RETURN
.no:
    xor eax, eax
.out:
    RETURN

; exports from industry edi: by rail if a freight yard on a line to the
; edge serves it -> eax 1 (no truck; paid now)
FUNC rail_export
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp edi, MAP_TILES
    jae .out
    movzx ecx, byte [rl_fnear+rdi]
    test ecx, ecx
    jz .out
    movzx ecx, word [rl_snet+rcx*2-2]
    cmp word [rl_edge+rcx*2], 0
    je .out
    add dword [exports_month], 16
    add dword [goods_sold_month], 16
    mov eax, ecx
    call port_rail_export
    mov eax, 1
.out:
    RETURN

; month end (beta)
rail_month:
    cmp dword [beta_on], 0
    je .o
    mov eax, [train_riders_month]
    mov [train_riders], eax
    mov dword [train_riders_month], 0
    mov eax, [rail_freight_month]
    mov [rail_freight], eax
    mov dword [rail_freight_month], 0
    mov dword [rail_visitors_month], 0
.o: ret

; forget the trains (a new or loaded city)
trains_reset:
    push rdi
    push rcx
    lea rdi, [tr_kind]
    mov ecx, TR_MAX
    xor eax, eax
    rep stosb
    lea rdi, [rl_occ]
    mov ecx, MAP_TILES*2/8
    rep stosq
    lea rdi, [rl_block]
    mov ecx, MAP_TILES/8
    rep stosq
    pop rcx
    pop rdi
    ret

; ---------------------------------------------------------------------
;  the rail view and the inspector
; ---------------------------------------------------------------------
; (rdi tile, esi index) -> eax tint
rail_tint:
    movzx ecx, byte [rdi+T_OBJ]
    cmp ecx, OBJ_SERVICE
    jne .g
    movzx ecx, byte [rdi+T_SUB]
    cmp ecx, BK_RAILSTN
    je .st
    cmp ecx, BK_FREIGHT
    jne .g
.st:
    ; on a line or not (the corner has the station's reach mark nearby)
    movzx eax, byte [rl_near+rsi]
    or al, [rl_fnear+rsi]
    test eax, eax
    jz .bad
    mov eax, TINT_BLUE
    ret
.bad:
    mov eax, TINT_RED
    ret
.g:
    cmp byte [rl_near+rsi], 0
    je .f
    mov eax, TINT_PINK
    ret
.f:
    xor eax, eax
    cmp byte [rl_fnear+rsi], 0
    je .o
    cmp ecx, OBJ_ZONEBLD
    jne .o
    cmp byte [rdi+T_ZONE], ZONE_I
    jne .o
    mov eax, TINT_GREEN
.o: ret

; should the rail view show? -> eax OV_RAIL or 0
rail_view_wanted:
    xor eax, eax
    cmp dword [beta_on], 0
    je .o
    cmp dword [tool], T_RAIL
    je .y
    cmp dword [tool], T_BUILD
    jne .o
    cmp dword [build_kind], BK_RAILSTN
    je .y
    cmp dword [build_kind], BK_FREIGHT
    jne .o
.y: mov eax, OV_RAIL
.o: ret

; a station or yard in the inspector (beta; rbx tile, r15d index)
FUNC rail_inspect
    cmp dword [beta_on], 0
    je .out
    movzx eax, byte [rbx+T_SUB]
    cmp eax, BK_RAILSTN
    je .go
    cmp eax, BK_FREIGHT
    jne .out
.go:
    xor ecx, ecx
.f:
    cmp ecx, [rl_n]
    jge .none
    movzx eax, word [rl_stn+rcx*2]
    cmp eax, r15d
    je .have
    inc ecx
    jmp .f
.have:
    movzx r12d, word [rl_snet+rcx*2]
    test r12d, r12d
    jz .none
    ; stations on the line
    xor r13d, r13d
    xor edx, edx
.c:
    cmp edx, [rl_n]
    jge .cd
    cmp [rl_snet+rdx*2], r12w
    jne .cn
    cmp byte [rl_sfrt+rdx], 0
    jne .cn
    inc r13d
.cn:
    inc edx
    jmp .c
.cd:
    call tb_reset
    lea rdi, [s_rl_line]
    call tb_str
    movsxd rdi, r13d
    call tb_num
    lea rdi, [s_rl_stns]
    call tb_str
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
    lea rdx, [s_rl_edge]
    cmp word [rl_edge+r12*2], 0
    jne .e
    lea rdx, [s_rl_noedge]
.e:
    mov ecx, UI_TEXT
    call row_text
    jmp .out
.none:
    lea rdx, [s_rl_none]
    mov ecx, UI_TEXT
    call row_text
.out:
    RETURN

; after the rail tool: the rubble of what it went through swept (zones
; stay), a word about tiles buildings blocked
FUNC rail_after
    xor ebx, ebx
.l:
    cmp ebx, [tl_n]
    jge .m
    cmp byte [tl_ok+rbx], 0
    je .n
    mov r13d, [tl_x+rbx*4]
    mov r14d, [tl_y+rbx*4]
    mov r15d, -1
.sy:
    mov r12d, -1
.sx:
    lea edi, [r13+r12]
    lea esi, [r14+r15]
    call tile_at
    test rax, rax
    jz .snx
    cmp byte [rax+T_OBJ], OBJ_RUBBLE
    jne .snx
    cmp byte [rax+T_ZONE], 0
    je .snx
    mov byte [rax+T_OBJ], OBJ_NONE
.snx:
    inc r12d
    cmp r12d, 1
    jle .sx
    inc r15d
    cmp r15d, 1
    jle .sy
.n:
    inc ebx
    jmp .l
.m:
    call road_blocked_msg
    RETURN
