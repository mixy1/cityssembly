; =====================================================================
;  METRO (beta) - trains under the city
;
;  Tunnels are dug like pipes (under anything; twice the price under
;  water) and live in the tile record (MISC_METRO), so undo and saves
;  carry them.  A station touching a tunnel joins that tunnel's line.
;  People within MT_REACH tiles of a station whose trip ends near
;  another station on the same line can take the metro: fast and never
;  in traffic.  Each station carries MT_CAP riders a month.
;
;  How people travel (every trip, beta): on foot for short hops, by
;  car, by bus when both ends are near stops, by metro as above - the
;  quickest, give or take a little (people differ).
; =====================================================================
MISC_METRO  equ 16
MT_REACH    equ 6
MT_CAP      equ 4000
MT_MAX      equ 255                 ; stations counted
MT_COST     equ 40                  ; a tunnel tile
TM_CAR      equ 0
TM_BUS      equ 1
TM_METRO    equ 2
TM_FOOT     equ 3

section .bss
mt_comp     resw MAP_TILES          ; tunnel line of each tunnel tile
mt_queue    resw MAP_TILES
mt_stn      resw MT_MAX             ; station tiles
mt_net      resw MT_MAX             ; and their line (0: no tunnel)
mt_n        resd 1
mt_near     resb MAP_TILES          ; 1 + the nearest station in reach
mt_dist     resb MAP_TILES          ; how far it is
metro_riders_month resd 1
metro_riders       resd 1           ; last month's
walkers_month      resd 1
walkers            resd 1           ; last month's
ghost_trips        resd 1           ; trips not by car, still going (x256)
tm_calls           resd 1           ; (stats: trips weighed)
tm_near            resd 1           ; (both ends near a station)
tm_same            resd 1           ; (the same station)
tm_lost            resd 1           ; (the car was quicker)

section .data
sm_water_beta   dd SI_PIPE, BK_PUMP, BK_WTOWER, BK_SEWAGE, SI_LEVEE, SI_UNPIPE, -1
sm_safety_beta  dd BK_POLICE, BK_FIRE, BK_PLOW, -1
sm_leisure_beta dd BK_PARK, BK_PLAZA, BK_STADIUM, BK_CITYHALL, BK_LANDMARK
                dd BK_GCENTRAL, BK_EXCHANGE, BK_OPERA, BK_SPACE, BK_EXPO, -1
sm_transit_beta dd BK_BUSDEPOT, SI_BUSSTOP, BK_METRO, SI_METRO, SI_UNMETRO
                dd SI_RAIL, BK_RAILSTN, BK_FREIGHT, BK_AIRPORT, SI_RUNWAY, BK_PORT, -1
ti_metro    db "Metro tunnel", 0
ti_unmetro  db "Remove tunnels", 0
hx_metro    db "Drag to dig: tunnels go under", 10
            db "anything (twice the price under", 10
            db "water). Stations touching the same", 10
            db "tunnels make a line.", 10
            db 7, "Pink: where a station is a", 10
            db 7, "walk away.", 0
hx_unmetro  db "Drag over tunnels to fill them in.", 0
ov_metro_n  db "Metro", 0
oh_metro    db 7, "station  ", 1, "a walk from one  ", 5, "tunnels  ", 3, "station on no line", 0
s_st_metro  db "Metro riders / month", 0
s_mt_line   db "Line: ", 0
s_mt_stns   db " stations", 0
s_mt_none   db 3, "No tunnel - dig one to another station", 0
s_mt_ride   db "Riders this month (all lines): ", 0

section .text

; ---------------------------------------------------------------------
;  lines and reach (with the other networks)
; ---------------------------------------------------------------------
FUNC metro_update, 16
    cmp dword [beta_on], 0
    je .out
    ; tunnel lines: flood each unlabelled tunnel tile
    lea rdi, [mt_comp]
    mov ecx, MAP_TILES/4
    xor eax, eax
    rep stosq
    xor r15d, r15d                  ; lines so far
    xor ebx, ebx
.t:
    mov eax, ebx
    shl eax, TILE_SHIFT
    test byte [tiles+rax+T_MISC], MISC_METRO
    jz .tn
    cmp word [mt_comp+rbx*2], 0
    jne .tn
    inc r15d
    mov [mt_comp+rbx*2], r15w
    mov [mt_queue], bx
    xor r12d, r12d                  ; head
    mov r13d, 1                     ; tail
.q:
    cmp r12d, r13d
    jge .tn
    movzx r14d, word [mt_queue+r12*2]
    inc r12d
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
    cmp word [mt_comp+rsi*2], 0
    jne .dn
    mov eax, esi
    shl eax, TILE_SHIFT
    test byte [tiles+rax+T_MISC], MISC_METRO
    jz .dn
    mov [mt_comp+rsi*2], r15w
    mov [mt_queue+r13*2], si
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
    ; stations: on their tile's tunnel, or one next to it
    mov dword [mt_n], 0
    xor ebx, ebx
.s:
    cmp ebx, MAP_TILES
    jge .reach
    mov r12d, ebx
    mov eax, r12d
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_SERVICE
    jne .sn
    cmp byte [tiles+rax+T_SUB], BK_METRO
    jne .sn
    mov ecx, [mt_n]
    cmp ecx, MT_MAX
    jge .reach
    mov [mt_stn+rcx*2], r12w
    movzx eax, word [mt_comp+r12*2]
    test eax, eax
    jnz .sl
    xor edx, edx
.sd:
    mov edi, r12d
    and edi, MAP_W-1
    mov esi, r12d
    shr esi, MAP_SHIFT
    add edi, [dir_dx+rdx*4]
    add esi, [dir_dy+rdx*4]
    cmp edi, MAP_W
    jae .sdn
    cmp esi, MAP_W
    jae .sdn
    shl esi, MAP_SHIFT
    add esi, edi
    movzx eax, word [mt_comp+rsi*2]
    test eax, eax
    jnz .sl
.sdn:
    inc edx
    cmp edx, 4
    jl .sd
    xor eax, eax
.sl:
    mov [mt_net+rcx*2], ax
    inc dword [mt_n]
.sn:
    inc ebx
    jmp .s
.reach:
    ; the nearest station within MT_REACH of every tile
    lea rdi, [mt_near]
    mov ecx, MAP_TILES/8
    xor eax, eax
    rep stosq
    lea rdi, [mt_dist]
    mov ecx, MAP_TILES/8
    mov rax, -1
    rep stosq
    xor ebx, ebx
.r:
    cmp ebx, [mt_n]
    jge .out
    cmp word [mt_net+rbx*2], 0
    je .rn
    movzx eax, word [mt_stn+rbx*2]
    mov r12d, eax
    and r12d, MAP_W-1
    mov r13d, eax
    shr r13d, MAP_SHIFT
    mov r14d, -MT_REACH
.ry:
    mov r15d, -MT_REACH
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
    add eax, ecx                    ; steps away
    cmp eax, MT_REACH
    jg .rxn
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    cmp edi, MAP_W
    jae .rxn
    cmp esi, MAP_W
    jae .rxn
    shl esi, MAP_SHIFT
    add esi, edi
    cmp al, [mt_dist+rsi]
    jae .rxn
    mov [mt_dist+rsi], al
    lea ecx, [rbx+1]
    mov [mt_near+rsi], cl
.rxn:
    inc r15d
    cmp r15d, MT_REACH
    jle .rx
    inc r14d
    cmp r14d, MT_REACH
    jle .ry
.rn:
    inc ebx
    jmp .r
.out:
    RETURN

; stations on the same line as station slot edi (0-based) -> eax
metro_line_size:
    movzx ecx, word [mt_net+rdi*2]
    xor eax, eax
    test ecx, ecx
    jz .o
    xor edx, edx
.l: cmp edx, [mt_n]
    jge .o
    cmp [mt_net+rdx*2], cx
    jne .n
    inc eax
.n: inc edx
    jmp .l
.o: ret

; ---------------------------------------------------------------------
;  how a trip goes (edi from building, esi to building; -1 = outside)
;  -> eax TM_*; riders and walkers are counted, fares taken
; ---------------------------------------------------------------------
FUNC travel_mode, 32
    mov r12d, edi
    mov r13d, esi
    inc dword [tm_calls]
    cmp r12d, MAP_TILES
    jae .car
    cmp r13d, MAP_TILES
    jae .car
    mov edi, r12d
    mov esi, r13d
    call tile_dist
    mov r14d, eax                   ; tiles apart
    ; short hops on foot (or by bike)
    cmp r14d, 5
    jg .nf
    call rand
    and eax, 7
    cmp eax, 5
    jb .foot
.nf:
    test dword [policies], P_BIKE
    jz .nb
    call rand
    and eax, 7
    cmp eax, 2
    jb .foot
.nb:
    ; the car: its time grows with the jams
    mov eax, 100
    sub eax, [flow_pct]
    CLAMP eax, 0, 100
    lea r15d, [rax+48]              ; x48ths
    mov eax, r14d
    shl eax, 4
    imul eax, r15d
    xor edx, edx
    mov ecx, 48
    div ecx
    mov [rbp-48], eax               ; car
    call rand
    and eax, 31
    add [rbp-48], eax
    mov dword [rbp-52], TM_CAR
    ; the bus: both ends near stops; waits, and sits in the same traffic
    cmp dword [svc_count+BK_BUSDEPOT*4], 0
    je .nbus
    cmp byte [map_transit+r12], 40
    jb .nbus
    cmp byte [map_transit+r13], 40
    jb .nbus
    mov eax, r14d
    imul eax, 20
    imul eax, r15d
    xor edx, edx
    mov ecx, 48
    div ecx
    add eax, 90
    test dword [policies], P_FREEBUS
    jz .bf
    sub eax, 30
.bf:
    push rax
    push rax
    call rand
    mov ecx, eax
    pop rax
    pop rax
    and ecx, 31
    add eax, ecx
    cmp eax, [rbp-48]
    jge .nbus
    mov [rbp-48], eax
    mov dword [rbp-52], TM_BUS
.nbus:
    ; the metro: stations near both ends, on the same line, room aboard
    movzx eax, byte [mt_near+r12]
    movzx ecx, byte [mt_near+r13]
    test eax, eax
    jz .pick
    test ecx, ecx
    jz .pick
    inc dword [tm_near]
    cmp eax, ecx
    jne .dif
    inc dword [tm_same]
    jmp .pick
.dif:
    movzx edx, word [mt_net+rax*2-2]
    test edx, edx
    jz .pick
    cmp dx, [mt_net+rcx*2-2]
    jne .pick
    mov eax, [mt_n]
    imul eax, MT_CAP
    cmp [metro_riders_month], eax
    jge .pick
    movzx eax, byte [mt_dist+r12]
    movzx ecx, byte [mt_dist+r13]
    add eax, ecx
    imul eax, eax, 10               ; the walk to and from
    lea eax, [rax+r14*4]            ; the ride, quick
    add eax, 40                     ; the wait
    test dword [policies], P_FREEBUS
    jz .mf
    sub eax, 30
.mf:
    call gc_cheaper
    push rax
    push rax
    call rand
    mov ecx, eax
    pop rax
    pop rax
    and ecx, 31
    add eax, ecx
    cmp eax, [rbp-48]
    jl .mwin
    inc dword [tm_lost]
    jmp .pick
.mwin:
    mov [rbp-48], eax
    mov dword [rbp-52], TM_METRO
.pick:
    ; the train: stations near both ends on one line
    call rail_trip_cost
    cmp eax, -1
    je .pk0
    call gc_cheaper
    push rax
    push rax
    call rand
    mov ecx, eax
    pop rax
    pop rax
    and ecx, 31
    add eax, ecx
    cmp eax, [rbp-48]
    jge .pk0
    mov [rbp-48], eax
    mov dword [rbp-52], TM_TRAIN
.pk0:
    mov eax, [rbp-52]
    cmp eax, TM_TRAIN
    jne .pk1
    inc dword [train_riders_month]
    add dword [fares_month], 3
.pk1:
    test eax, eax
    jz .pk
    add dword [ghost_trips], 256
.pk:
    cmp eax, TM_BUS
    jne .pm
    inc dword [riders_month]
    test dword [policies], P_FREEBUS
    jnz .ret
    inc dword [fares_month]
    jmp .ret
.pm:
    cmp eax, TM_METRO
    jne .ret
    inc dword [metro_riders_month]
    test dword [policies], P_FREEBUS
    jnz .ret
    add dword [fares_month], 2
.ret:
    RETURN
.foot:
    inc dword [walkers_month]
    add dword [ghost_trips], 256
    mov eax, TM_FOOT
    RETURN
.car:
    mov eax, TM_CAR
    RETURN

; month end (beta): the metro's riders into the stats
metro_month:
    cmp dword [beta_on], 0
    je .o
    mov eax, [metro_riders_month]
    mov [metro_riders], eax
    mov dword [metro_riders_month], 0
    mov eax, [walkers_month]
    mov [walkers], eax
    mov dword [walkers_month], 0
.o: ret

; ---------------------------------------------------------------------
;  the tunnel tool
; ---------------------------------------------------------------------
; evaluate a tile for the tunnel tool (r12 tile, edx terrain) -> eax
; cost or -1
metro_tile_cost:
    test byte [r12+T_MISC], MISC_METRO
    jnz .no
    mov eax, MT_COST
    cmp edx, TER_WATER
    jne .o
    add eax, eax
.o: ret
.no:
    mov eax, -1
    ret

; ---------------------------------------------------------------------
;  the metro view: tunnels over the frame, trains running through them
; ---------------------------------------------------------------------
FUNC draw_tunnels, 32
    xor r13d, r13d
.ty:
    xor r12d, r12d
.tx:
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    mov r15d, eax
    shl eax, TILE_SHIFT
    test byte [tiles+rax+T_MISC], MISC_METRO
    jz .next
    mov edi, r12d
    mov esi, r13d
    call tile_screen
    cmp eax, -20
    jl .next
    mov ecx, [fb_w]
    add ecx, 20
    cmp eax, ecx
    jg .next
    cmp edx, -20
    jl .next
    mov ecx, [fb_h]
    add ecx, 20
    cmp edx, ecx
    jg .next
    mov [rbp-48], eax
    add edx, 8
    mov [rbp-52], edx
    mov dword [pipe_col], RAMP(R_YELLOW, 7)
    mov dword [pipe_col2], RAMP(R_ORANGE, 2)
    xor r14d, r14d
.d:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+r14*4]
    add esi, [dir_dy+r14*4]
    call tile_at
    test rax, rax
    jz .dn
    test byte [rax+T_MISC], MISC_METRO
    jz .dn
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, [pipe_ex+r14*4]
    add edx, edi
    mov ecx, [pipe_ey+r14*4]
    add ecx, esi
    call pipe_line
.dn:
    inc r14d
    cmp r14d, 4
    jl .d
    ; a train: bright cars passing along the line
    movzx eax, word [mt_comp+r15*2]
    test eax, eax
    jz .next
    mov eax, [anim_tick]
    shr eax, 2
    mov ecx, r12d
    add ecx, r13d
    shl ecx, 3
    sub eax, ecx
    and eax, 63
    cmp eax, 6
    jae .next
    mov edi, [rbp-48]
    sub edi, 2
    mov esi, [rbp-52]
    sub esi, 2
    mov edx, 5
    mov ecx, 4
    mov r8d, RAMP(R_WHITE, 7)
    call fill_rect
.next:
    inc r12d
    cmp r12d, MAP_W
    jl .tx
    inc r13d
    cmp r13d, MAP_W
    jl .ty
    RETURN

; the metro view's tint (rdi tile, esi index) -> eax
metro_tint:
    cmp byte [rdi+T_OBJ], OBJ_SERVICE
    jne .g
    cmp byte [rdi+T_SUB], BK_METRO
    jne .g
    ; a station: on a line, or not
    movzx eax, byte [mt_near+rsi]
    test eax, eax
    jz .bad
    mov eax, TINT_BLUE
    ret
.bad:
    mov eax, TINT_RED
    ret
.g:
    xor eax, eax
    cmp byte [mt_near+rsi], 0
    je .o
    mov eax, TINT_PINK
.o: ret

; the submenu list for submenu eax (beta: the metro in public transport)
; -> r15 list
submenu_list:
    mov r15, [submenu_lists+rax*8]
    cmp dword [beta_on], 0
    je .o
    cmp eax, 8
    jne .o3
    lea r15, [sm_transit_beta]
.o3:
    cmp eax, 3
    jne .o5
    lea r15, [sm_water_beta]
.o5:
    cmp eax, 5
    jne .o9
    lea r15, [sm_safety_beta]
.o9:
    cmp eax, 9
    jne .o
    lea r15, [sm_leisure_beta]
.o: ret

; a station's lines in the inspector (beta; rbx its tile, r15d index)
FUNC metro_inspect
    cmp dword [beta_on], 0
    je .out
    cmp byte [rbx+T_SUB], BK_METRO
    jne .out
    ; which station slot is this?
    xor ecx, ecx
.f:
    cmp ecx, [mt_n]
    jge .none
    movzx eax, word [mt_stn+rcx*2]
    cmp eax, r15d
    je .have
    inc ecx
    jmp .f
.have:
    cmp word [mt_net+rcx*2], 0
    je .none
    mov edi, ecx
    call metro_line_size
    mov r12d, eax
    call tb_reset
    lea rdi, [s_mt_line]
    call tb_str
    movsxd rdi, r12d
    call tb_num
    lea rdi, [s_mt_stns]
    call tb_str
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
    call tb_reset
    lea rdi, [s_mt_ride]
    call tb_str
    movsxd rdi, dword [metro_riders_month]
    call tb_num
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
    jmp .out
.none:
    lea rdx, [s_mt_none]
    mov ecx, UI_TEXT
    call row_text
.out:
    RETURN

; should the metro view show? (beta: the tunnel tools, a station
; being placed) -> eax OV_METRO or 0
metro_view_wanted:
    xor eax, eax
    cmp dword [beta_on], 0
    je .o
    cmp dword [tool], T_METRO
    je .y
    cmp dword [tool], T_BULLDOZE
    jne .b
    cmp dword [bz_filter], 3
    je .y
    ret
.b: cmp dword [tool], T_BUILD
    jne .o
    cmp dword [build_kind], BK_METRO
    jne .o
.y: mov eax, OV_METRO
.o: ret
