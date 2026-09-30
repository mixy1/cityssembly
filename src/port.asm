; =====================================================================
;  PORT (beta) - a cargo port on the water, and its ships
;
;  A Port (3x3) goes on the shore.  When ships can reach it from the sea
;  (water all the way to the map edge), industry ships much of its
;  exports from it and shops get their imports through it: they pay a
;  third more - and every one of them is a truck to or from the port.
;  A freight yard within 8 tiles of the port takes that off the roads:
;  its railway line counts as reaching the region, and what the line's
;  yards send pays the port's price.
;
;  Ships come in from the edge along the water, tie up, and sail away.
; =====================================================================
PO_MAX      equ 4
PO_PATH     equ 400             ; tiles of the way in, kept
PO_REACH    equ 8               ; a freight yard this close serves it
SH_SPEED    equ 10              ; of 256 a tile, a step
PO_BONUS    equ 4               ; more an export truck fetches there

section .bss
pt_n        resd 1
pt_tile     resw PO_MAX         ; anchors
pt_live     resb PO_MAX         ; ships reach it
pt_len      resw PO_MAX         ; the way in: tiles
pt_path     resw PO_MAX*PO_PATH ; from the sea to the quay
pt_clock    resd PO_MAX
pt_seen     resd MAP_TILES      ; (the search: a stamp per tile)
pt_from     resb MAP_TILES
pt_queue    resw MAP_TILES
pt_gen      resd 1
rl_port     resb 4096           ; a railway line with a yard at a port
port_trade_month resd 1         ; what went through the ports ($)
port_trade  resd 1              ; (last month)
; ships
sh_on       resb PO_MAX         ; one per port: 0 none, 1 in, 2 tied up, 3 out
sh_pos      resw PO_MAX         ; the tile along the way
sh_prog     resd PO_MAX
sh_t        resd PO_MAX
spr_ship    resd 4

section .data
nm_port     db "Cargo Port", 0
ds_port     db "Ships take exports, bring imports. Busy.", 0
hb_port     db "On the shore, with water all the", 10
            db "way to the map edge. Exports and", 10
            db "imports go through it, paying more", 10
            db "- by truck, unless a freight yard", 10
            db "within 8 tiles links it by rail.", 0
s_pt_sea    db "Ships come in from the sea", 0
s_pt_nosea  db "No way to the sea: ships can't come", 0
s_pt_rail   db "A freight yard links it by rail", 0
s_pt_trade  db "Through the ports / month: ", 0
s_st_port   db "Through the ports / month", 0

section .text

; ---------------------------------------------------------------------
;  ports (with the other networks, before the railways)
; ---------------------------------------------------------------------
FUNC port_update, 32
    cmp dword [beta_on], 0
    je .out
    mov dword [pt_n], 0
    xor ebx, ebx
.s:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_SERVICE
    jne .sn
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .sn
    cmp byte [tiles+rax+T_SUB], BK_PORT
    jne .sn
    mov r12d, [pt_n]
    cmp r12d, PO_MAX
    jge .out
    mov [pt_tile+r12*2], bx
    mov [rbp-48], eax
    mov edi, r12d
    call port_sea_path
    mov eax, [rbp-48]
    test byte [tiles+rax+T_FLAGS], F_POWER
    jnz .pw
    mov byte [pt_live+r12], 0
.pw:
    inc dword [pt_n]
.sn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .s
.out:
    RETURN

; the way from the sea to port edi (breadth first over water, from the
; water at its quay out to the map edge)
FUNC port_sea_path, 16
    mov r15d, edi
    mov byte [pt_live+r15], 0
    mov word [pt_len+r15*2], 0
    inc dword [pt_gen]
    mov r14d, [pt_gen]
    xor r12d, r12d                  ; queue head
    xor r13d, r13d                  ; tail
    ; seeds: water around the 3x3 footprint
    movzx eax, word [pt_tile+r15*2]
    mov [rbp-48], eax
    mov ebx, -1
.sy:
    mov ecx, -1
.sx:
    mov edi, [rbp-48]
    and edi, MAP_W-1
    add edi, ecx
    mov esi, [rbp-48]
    shr esi, MAP_SHIFT
    add esi, ebx
    cmp edi, MAP_W
    jae .sxn
    cmp esi, MAP_W
    jae .sxn
    shl esi, MAP_SHIFT
    add esi, edi
    mov eax, esi
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_TERRAIN], TER_WATER
    jne .sxn
    cmp byte [tiles+rax+T_OBJ], OBJ_NONE
    jne .sxn
    cmp [pt_seen+rsi*4], r14d
    je .sxn
    mov [pt_seen+rsi*4], r14d
    mov byte [pt_from+rsi], 255     ; a start
    mov [pt_queue+r13*2], si
    inc r13d
.sxn:
    inc ecx
    cmp ecx, 3
    jle .sx
    inc ebx
    cmp ebx, 3
    jle .sy
.q:
    cmp r12d, r13d
    jge .out
    movzx ebx, word [pt_queue+r12*2]
    inc r12d
    ; at the edge: the way is found
    mov eax, ebx
    and eax, MAP_W-1
    jz .found
    cmp eax, MAP_W-1
    je .found
    mov eax, ebx
    shr eax, MAP_SHIFT
    jz .found
    cmp eax, MAP_W-1
    je .found
    xor ecx, ecx
.d:
    mov edi, ebx
    and edi, MAP_W-1
    mov esi, ebx
    shr esi, MAP_SHIFT
    add edi, [dir_dx+rcx*4]
    add esi, [dir_dy+rcx*4]
    cmp edi, MAP_W
    jae .dn
    cmp esi, MAP_W
    jae .dn
    shl esi, MAP_SHIFT
    add esi, edi
    cmp [pt_seen+rsi*4], r14d
    je .dn
    mov eax, esi
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_TERRAIN], TER_WATER
    jne .dn
    ; under bridges is fine, not through piers
    cmp byte [tiles+rax+T_OBJ], OBJ_NONE
    je .dok
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    je .dok
    cmp byte [tiles+rax+T_OBJ], OBJ_RAIL
    jne .dn
.dok:
    mov [pt_seen+rsi*4], r14d
    mov [pt_from+rsi], cl
    mov [pt_queue+r13*2], si
    inc r13d
.dn:
    inc ecx
    cmp ecx, 4
    jl .d
    jmp .q
.found:
    ; walk back to the quay, writing the way from the sea
    mov byte [pt_live+r15], 1
    imul r13d, r15d, PO_PATH*2
    lea r13, [pt_path+r13]
    xor ecx, ecx
.w:
    cmp ecx, PO_PATH
    jge .wd
    mov [r13+rcx*2], bx
    inc ecx
    movzx eax, byte [pt_from+rbx]
    cmp eax, 255
    je .wd
    ; back the way it came
    mov edi, ebx
    and edi, MAP_W-1
    mov esi, ebx
    shr esi, MAP_SHIFT
    sub edi, [dir_dx+rax*4]
    sub esi, [dir_dy+rax*4]
    shl esi, MAP_SHIFT
    lea ebx, [rsi+rdi]
    jmp .w
.wd:
    mov [pt_len+r15*2], cx
.out:
    RETURN

; is tile edi within PO_REACH of a port? -> eax 1
near_port:
    push rbx
    xor ebx, ebx
.p:
    cmp ebx, [pt_n]
    jge .no
    movzx esi, word [pt_tile+rbx*2]
    add esi, MAP_W+1                ; its middle
    push rdi
    call tile_dist
    pop rdi
    cmp eax, PO_REACH+1
    jle .y
    inc ebx
    jmp .p
.y: mov eax, 1
    pop rbx
    ret
.no:
    xor eax, eax
    pop rbx
    ret

; railway lines with a yard at a port count as reaching the region
; (called at the end of rail_update)
FUNC port_rail
    cmp dword [beta_on], 0
    je .out
    lea rdi, [rl_port]
    mov ecx, 4096/8
    xor eax, eax
    rep stosq
    cmp dword [pt_n], 0
    je .out
    xor ebx, ebx
.y:
    cmp ebx, [rl_n]
    jge .out
    cmp byte [rl_sfrt+rbx], 0
    je .yn
    movzx r12d, word [rl_snet+rbx*2]
    test r12d, r12d
    jz .yn
    movzx edi, word [rl_stn+rbx*2]
    add edi, MAP_W+1
    call near_port
    test eax, eax
    jz .yn
    mov byte [rl_port+r12], 1
    ; no edge of its own: the port yard is where the line leaves
    cmp word [rl_edge+r12*2], 0
    jne .yn
    movzx eax, word [rl_stop+rbx*2]
    inc eax
    mov [rl_edge+r12*2], ax
.yn:
    inc ebx
    jmp .y
.out:
    RETURN

; the nearest port ships reach, to tile edi -> eax its anchor or -1
FUNC port_nearest
    mov r12d, edi
    mov r13d, -1
    mov r14d, 0x7FFFFFFF
    xor ebx, ebx
.p:
    cmp ebx, [pt_n]
    jge .out
    cmp byte [pt_live+rbx], 0
    je .n
    movzx esi, word [pt_tile+rbx*2]
    mov r15d, esi
    mov edi, r12d
    call tile_dist
    cmp eax, r14d
    jge .n
    mov r14d, eax
    mov r13d, r15d
.n:
    inc ebx
    jmp .p
.out:
    mov eax, r13d
    RETURN

; exports from industry edi: a truck to the port, three times in five,
; when ships come (beta) -> eax 1 (the trip is made)
FUNC port_export
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp dword [pt_n], 0
    je .out
    mov r12d, edi
    call port_nearest
    cmp eax, -1
    je .no
    mov r13d, eax
    mov edi, 5
    call rand_range
    cmp eax, 3
    jae .no
    mov edi, r12d
    mov esi, r13d
    mov edx, VT_TRUCK
    mov ecx, PU_EXPORT
    call make_trip
    mov eax, 1
    RETURN
.no:
    xor eax, eax
.out:
    RETURN

; imports for shop edi: from the port, three times in five (beta)
FUNC port_import
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp dword [pt_n], 0
    je .out
    mov r12d, edi
    call port_nearest
    cmp eax, -1
    je .no
    mov r13d, eax
    mov edi, 5
    call rand_range
    cmp eax, 3
    jae .no
    mov edi, r13d
    mov esi, r12d
    mov edx, VT_TRUCK
    mov ecx, PU_IMPORT
    call make_trip
    add dword [port_trade_month], 8
    mov eax, 1
    RETURN
.no:
    xor eax, eax
.out:
    RETURN

; an export truck arrived (rdi vehicle): at a port it fetches more
port_arrive:
    mov eax, [rdi+V_DST]
    cmp eax, MAP_TILES
    jae .o
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_SERVICE
    jne .o
    cmp byte [tiles+rax+T_SUB], BK_PORT
    jne .o
    add dword [exports_month], PO_BONUS
    add dword [goods_sold_month], PO_BONUS
    add dword [port_trade_month], 12+PO_BONUS
.o: ret

; a railway export from a line with a port yard: the port's price
; (eax line)
port_rail_export:
    cmp byte [rl_port+rax], 0
    je .o
    add dword [exports_month], 5
    add dword [goods_sold_month], 5
    add dword [port_trade_month], 21
.o: ret

port_month:
    cmp dword [beta_on], 0
    je .o
    mov eax, [port_trade_month]
    mov [port_trade], eax
    mov dword [port_trade_month], 0
.o: ret

; ---------------------------------------------------------------------
;  ships
; ---------------------------------------------------------------------
FUNC ships_update
    cmp dword [beta_on], 0
    je .out
    xor ebx, ebx
.p:
    cmp ebx, [pt_n]
    jge .out
    cmp byte [pt_live+rbx], 0
    jne .live
    mov byte [sh_on+rbx], 0
    jmp .pn
.live:
    movzx eax, byte [sh_on+rbx]
    cmp eax, 1
    je .in
    cmp eax, 2
    je .tied
    cmp eax, 3
    je .outb
    ; none: one comes now and then
    dec dword [pt_clock+rbx*4]
    jg .pn
    mov byte [sh_on+rbx], 1
    mov word [sh_pos+rbx*2], 0
    mov dword [sh_prog+rbx*4], 0
    jmp .pn
.in:
    add dword [sh_prog+rbx*4], SH_SPEED
    cmp dword [sh_prog+rbx*4], 256
    jl .pn
    sub dword [sh_prog+rbx*4], 256
    inc word [sh_pos+rbx*2]
    movzx eax, word [sh_pos+rbx*2]
    movzx ecx, word [pt_len+rbx*2]
    dec ecx
    cmp eax, ecx
    jl .pn
    mov [sh_pos+rbx*2], cx
    mov dword [sh_prog+rbx*4], 0
    mov byte [sh_on+rbx], 2
    mov dword [sh_t+rbx*4], 900
    jmp .pn
.tied:
    dec dword [sh_t+rbx*4]
    jg .pn
    mov byte [sh_on+rbx], 3
    jmp .pn
.outb:
    ; back out the way it came
    sub dword [sh_prog+rbx*4], SH_SPEED
    jge .pn
    add dword [sh_prog+rbx*4], 256
    cmp word [sh_pos+rbx*2], 0
    je .gone
    dec word [sh_pos+rbx*2]
    jmp .pn
.gone:
    mov byte [sh_on+rbx], 0
    mov edi, 600
    call rand_range
    add eax, 900
    mov [pt_clock+rbx*4], eax
.pn:
    inc ebx
    cmp ebx, PO_MAX
    jl .p
.out:
    RETURN

; draw the ships (with the agents)
FUNC draw_ships, 32
    cmp dword [beta_on], 0
    je .out
    xor ebx, ebx
.p:
    cmp ebx, [pt_n]
    jge .out
    cmp byte [sh_on+rbx], 0
    je .pn
    imul eax, ebx, PO_PATH*2
    lea r14, [pt_path+rax]
    movzx r12d, word [sh_pos+rbx*2]
    movzx r13d, word [r14+r12*2]    ; its tile
    ; heading: toward the quay
    movzx ecx, word [pt_len+rbx*2]
    lea eax, [r12+1]
    cmp eax, ecx
    jge .last
    movzx esi, word [r14+rax*2]
    mov edi, r13d
    call tile_heading
    mov [rbp-48], eax
    jmp .hd
.last:
    ; tied up: along the quay, the way it came in
    mov dword [rbp-48], 1
    test r12d, r12d
    jz .hd
    movzx edi, word [r14+r12*2-2]
    mov esi, r13d
    call tile_heading
    mov [rbp-48], eax
.hd:
    mov ecx, [rbp-48]
    mov edi, r13d
    and edi, MAP_W-1
    shl edi, 8
    add edi, 128
    mov esi, r13d
    shr esi, MAP_SHIFT
    shl esi, 8
    add esi, 128
    mov eax, [sh_prog+rbx*4]
    mov edx, [dir_dx+rcx*4]
    imul edx, eax
    add edi, edx
    mov edx, [dir_dy+rcx*4]
    imul edx, eax
    add esi, edx
    sub edi, 24*16
    sub esi, 24*16
    mov edx, 16
    call world_proj
    cmp eax, -120
    jl .pn
    mov r8d, [fb_w]
    add r8d, 120
    cmp eax, r8d
    jg .pn
    cmp edx, -120
    jl .pn
    mov r8d, [fb_h]
    add r8d, 120
    cmp edx, r8d
    jg .pn
    mov r8d, [rbp-48]
    mov edi, [spr_ship+r8*4]
    mov esi, eax
    lea r8, [remap_identity]
    call blit_sprite
.pn:
    inc ebx
    cmp ebx, PO_MAX
    jl .p
.out:
    RETURN

ports_reset:
    push rdi
    push rcx
    mov dword [pt_n], 0
    lea rdi, [sh_on]
    mov ecx, PO_MAX
    xor eax, eax
    rep stosb
    mov dword [port_trade], 0
    mov dword [port_trade_month], 0
    pop rcx
    pop rdi
    ret

; a port in the inspector (beta; rbx tile, r15d index)
FUNC port_inspect
    cmp dword [beta_on], 0
    je .out
    cmp byte [rbx+T_SUB], BK_PORT
    jne .out
    xor r12d, r12d
.f:
    cmp r12d, [pt_n]
    jge .out
    movzx eax, word [pt_tile+r12*2]
    cmp eax, r15d
    je .have
    inc r12d
    jmp .f
.have:
    lea rdx, [s_pt_sea]
    mov ecx, UI_GOOD
    cmp byte [pt_live+r12], 0
    jne .s
    lea rdx, [s_pt_nosea]
    mov ecx, UI_BAD
.s:
    call row_text
    ; a railway at it?
    xor r13d, r13d
.y:
    cmp r13d, [rl_n]
    jge .t
    cmp byte [rl_sfrt+r13], 0
    je .yn
    movzx eax, word [rl_snet+r13*2]
    cmp byte [rl_port+rax], 0
    je .yn
    lea rdx, [s_pt_rail]
    mov ecx, UI_TEXT
    call row_text
    jmp .t
.yn:
    inc r13d
    jmp .y
.t:
    call tb_reset
    lea rdi, [s_pt_trade]
    call tb_str
    movsxd rdi, dword [port_trade]
    call tb_money
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
.out:
    RETURN

; ---------------------------------------------------------------------
;  sprites: the port, a cargo ship
; ---------------------------------------------------------------------
FUNC bld_port
    BEGIN 48, 52, 8600
    MAT M_CONCRETE
    BOX 0,0,0,48,48,2
    ; the quay's edge
    MAT M_YELLOW
    BOX 0,0,2,48,2,3
    ; containers in rows
    MAT M_ORANGE
    BOX 6,18,2,16,23,8
    MAT M_BLUE
    BOX 6,25,2,16,30,8
    BOX 6,25,8,16,30,14
    MAT M_RED
    BOX 18,18,2,28,23,8
    BOX 18,18,8,28,23,14
    MAT M_TEAL
    BOX 18,25,2,28,30,8
    MAT M_WHITE
    BOX 30,18,2,40,23,8
    MAT M_ORANGE
    BOX 30,25,2,40,30,8
    ; two cranes over the water side
    MAT M_RED
    BOX 8,4,2,10,6,34
    BOX 8,12,2,10,14,34
    BOX 32,4,2,34,6,34
    BOX 32,12,2,34,14,34
    BOX 6,0,34,12,16,38
    BOX 30,0,34,36,16,38
    MAT M_WHITE
    BOX 7,6,30,11,12,34
    BOX 31,6,30,35,12,34
    ; the shed
    MAT M_METAL
    BOX 4,36,2,44,46,12
    MAT M_DARK
    RFX 4,36,12,44,46,4
    call finish_model
    RETURN

; a cargo ship (edi dir): hull, containers, the bridge at the stern
FUNC gen_ship
    mov [car_dir], edi
    lea eax, [rdi+8700]
    BEGIN 48, 26, eax
    mov dword [pbox_g], 48
    MAT M_DARK
    PBOX 4,18,0,44,30,4
    PBOX 44,20,0,47,28,4
    MAT M_RED
    PBOX 4,18,0,47,30,1
    MAT M_WHITE
    PBOX 4,19,4,44,29,5
    ; containers
    MAT M_ORANGE
    PBOX 18,19,5,24,29,9
    MAT M_BLUE
    PBOX 25,19,5,31,29,9
    PBOX 25,19,9,31,29,12
    MAT M_TEAL
    PBOX 32,19,5,38,29,9
    MAT M_RED
    PBOX 18,19,9,24,29,12
    ; the bridge
    MAT M_WHITE
    PBOX 6,19,5,14,29,15
    MAT M_GLASS
    PBOX 13,19,12,14,29,14
    MAT M_DARK
    PBOX 8,23,15,11,25,19
    call finish_model
    RETURN

FUNC port_sprites_init
    xor ebx, ebx
.s:
    mov edi, ebx
    call gen_ship
    mov [spr_ship+rbx*4], eax
    inc ebx
    cmp ebx, 4
    jl .s
    RETURN
