; =====================================================================
;  QOL (beta) - small things that make the game easier to play
;
;  - Coverage gain: placing a police station, school, clinic, park ...
;    the price at the cursor says how many homes (or buildings) it
;    would reach that aren't served well now.
;  - Photo mode (F): the interface goes, the city stays; [ and ] turn
;    the clock, P saves a picture; F or Esc brings it back.
;  - Follow camera: click a car, train, plane or ship with the
;    inspector and the view follows it.
; =====================================================================
section .bss
photo_mode  resd 1
photo_hint_t resd 1

section .data
s_cg_homes  db " homes", 0
s_cg_blds   db " buildings", 0
s_photo     db "Photo mode - [ ] time of day, P save a picture, F or Esc to come back", 0

section .text

; the text builder gets " +N homes" for the building being placed
; (beta; tl_x, tl_y its corner)
FUNC cov_gain_text, 32
    cmp dword [beta_on], 0
    je .out
    mov edi, [build_kind]
    call bld_rec
    movzx ecx, byte [rax+BI_COV]
    test ecx, ecx
    jz .out
    cmp ecx, CV_GARBAGE
    je .out
    cmp ecx, CV_TRANSIT
    je .out
    mov [rbp-48], ecx               ; the kind
    mov rdx, [cov_maps+rcx*8]
    mov [rbp-56], rdx               ; its map
    movzx r14d, byte [rax+BI_RADIUS]
    movzx eax, byte [rax+BI_SIZE]
    shr eax, 1
    mov r12d, [tl_x]
    add r12d, eax
    mov r13d, [tl_y]
    add r13d, eax
    mov eax, r14d
    imul eax, eax
    mov [rbp-60], eax               ; r^2
    xor r15d, r15d                  ; count
    mov ebx, r14d
    neg ebx                         ; dy
.y:
    cmp ebx, r14d
    jg .done
    mov ecx, r14d
    neg ecx                         ; dx
.x:
    cmp ecx, r14d
    jg .yn
    mov eax, ecx
    imul eax, ecx
    mov edx, ebx
    imul edx, ebx
    add eax, edx
    cmp eax, [rbp-60]
    jg .xn
    lea edi, [r12+rcx]
    lea esi, [r13+rbx]
    cmp edi, MAP_W
    jae .xn
    cmp esi, MAP_W
    jae .xn
    shl esi, MAP_SHIFT
    add esi, edi
    mov eax, esi
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ZONEBLD
    jne .xn
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .xn
    ; police and fire serve every building; the rest serve homes
    mov edx, [rbp-48]
    cmp edx, CV_FIRE
    jbe .any
    movzx edx, byte [tiles+rax+T_ZONE]
    cmp byte [zone_class+rdx], ZC_RES
    jne .xn
.any:
    mov rdx, [rbp-56]
    cmp byte [rdx+rsi], 40
    jae .xn
    inc r15d
.xn:
    inc ecx
    jmp .x
.yn:
    inc ebx
    jmp .y
.done:
    test r15d, r15d
    jz .out
    mov edi, ' '
    call tb_char
    mov edi, '+'
    call tb_char
    movsxd rdi, r15d
    call tb_num
    lea rdi, [s_cg_homes]
    cmp dword [rbp-48], CV_FIRE
    ja .h
    lea rdi, [s_cg_blds]
.h:
    call tb_str
.out:
    RETURN

; F: photo mode on or off (beta)
photo_toggle:
    xor dword [photo_mode], 1
    jz .o
    mov dword [tool], T_INSPECT
    mov dword [sel_x], -1
    mov dword [panel], PANEL_NONE
    mov dword [submenu], -1
    mov dword [photo_hint_t], 180
.o: ret

; while in photo mode: a word on how to come back, for a few seconds
FUNC photo_draw
    cmp dword [photo_hint_t], 0
    je .out
    dec dword [photo_hint_t]
    mov edi, [ui_w]
    shr edi, 1
    mov esi, [ui_h]
    sub esi, 20
    lea rdx, [s_photo]
    mov ecx, UI_TEXT
    call draw_text_centered
.out:
    RETURN

; ---------------------------------------------------------------------
;  follow camera (beta): click a car, a train, a plane or a ship with
;  the inspector and the view follows it; moving the view, or Esc,
;  lets go
; ---------------------------------------------------------------------
FW_CAR      equ 1
FW_TRAIN    equ 2
FW_PLANE    equ 3
FW_SHIP     equ 4

section .bss
follow_kind resd 1
follow_idx  resd 1
follow_cx   resd 1              ; where the view was put last
follow_cy   resd 1
fw_best     resd 1

section .data
fw_names    dq 0, fwn1, fwn2, fwn3, fwn4
fwn1        db "Following a car - drag the view or Esc to stop", 0
fwn2        db "Following a train - drag the view or Esc to stop", 0
fwn3        db "Following a plane - drag the view or Esc to stop", 0
fwn4        db "Following a ship - drag the view or Esc to stop", 0

section .text

; where the thing followed is (edi kind, esi index)
; -> eax 1 and edi x, esi y, edx z (world units), or eax 0 if it's gone
FUNC follow_pos
    mov r12d, edi
    mov r13d, esi
    cmp r12d, FW_CAR
    jne .t
    mov eax, r13d
    shl eax, 7
    lea r15, [vehicles+rax]
    cmp byte [r15+V_TYPE], 255
    je .gone
    mov edi, [r15+V_WX]
    mov esi, [r15+V_WY]
    mov edx, 48
    jmp .have
.t:
    cmp r12d, FW_TRAIN
    jne .p
    cmp byte [tr_kind+r13], 0
    je .gone
    imul eax, r13d, TR_PATH*2
    lea r14, [tr_path+rax]
    movzx ebx, word [tr_pos+r13*2]  ; the locomotive
    movzx r15d, word [r14+rbx*2]    ; its tile
    movzx ecx, word [tr_len+r13*2]
    lea edx, [rbx+1]
    mov eax, 1
    cmp edx, ecx
    jge .tb
    movzx esi, word [r14+rdx*2]
    mov edi, r15d
    call tile_heading
    jmp .th
.tb:
    test ebx, ebx
    jz .th
    movzx edi, word [r14+rbx*2-2]
    mov esi, r15d
    call tile_heading
.th:
    mov ecx, eax
    mov eax, [tr_prog+r13*4]
    sub eax, 128
    jmp .tile
.p:
    cmp r12d, FW_PLANE
    jne .s
    cmp byte [pl_kind+r13], 0
    je .gone
    movzx ecx, byte [pl_h+r13]
    mov eax, [pl_s+r13*4]
    sar eax, 4
    mov edi, [dir_dx+rcx*4]
    imul edi, eax
    add edi, [pl_ox+r13*4]
    mov esi, [dir_dy+rcx*4]
    imul esi, eax
    add esi, [pl_oy+r13*4]
    mov edx, [pl_alt+r13*4]
    add edx, 64
    jmp .have
.s:
    cmp byte [sh_on+r13], 0
    je .gone
    imul eax, r13d, PO_PATH*2
    lea r14, [pt_path+rax]
    movzx ebx, word [sh_pos+r13*2]
    movzx r15d, word [r14+rbx*2]
    movzx ecx, word [pt_len+r13*2]
    lea edx, [rbx+1]
    mov eax, 1
    cmp edx, ecx
    jge .sh
    movzx esi, word [r14+rdx*2]
    mov edi, r15d
    call tile_heading
.sh:
    mov ecx, eax
    mov eax, [sh_prog+r13*4]
.tile:
    ; the tile's middle, and along the heading
    mov edi, r15d
    and edi, MAP_W-1
    shl edi, 8
    add edi, 128
    mov esi, r15d
    shr esi, MAP_SHIFT
    shl esi, 8
    add esi, 128
    mov edx, [dir_dx+rcx*4]
    imul edx, eax
    add edi, edx
    mov edx, [dir_dy+rcx*4]
    imul edx, eax
    add esi, edx
    mov edx, 64
.have:
    mov eax, 1
    RETURN
.gone:
    xor eax, eax
    RETURN

; is (edi kind, esi index) nearer the pointer than the best so far?
; (r12d, r13d the pointer on the screen) -> updates follow_kind/idx
FUNC follow_try, 16
    mov [rbp-48], edi
    mov [rbp-52], esi
    call follow_pos
    test eax, eax
    jz .out
    call world_proj
    sub eax, r12d
    imul eax, eax
    sub edx, r13d
    imul edx, edx
    add eax, edx
    cmp eax, [fw_best]
    jge .out
    mov [fw_best], eax
    mov eax, [rbp-48]
    mov [follow_kind], eax
    mov eax, [rbp-52]
    mov [follow_idx], eax
.out:
    RETURN

; a click with the inspector: on a car, train, plane or ship? -> eax 1
FUNC follow_pick
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    mov r12d, [mouse_wx]
    sub r12d, [cam_x]
    mov r13d, [mouse_wy]
    sub r13d, [cam_y]
    mov dword [fw_best], 16*16
    mov dword [follow_kind], 0
    ; planes and ships first (they're big), then trains, then cars
    xor ebx, ebx
.pl:
    mov edi, FW_PLANE
    mov esi, ebx
    call follow_try
    inc ebx
    cmp ebx, PL_MAX
    jl .pl
    ; the rest only from a road, track or water (not over buildings)
    mov edi, [hover_tx]
    mov esi, [hover_ty]
    call tile_at
    test rax, rax
    jz .end
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .ground
    cmp byte [rax+T_OBJ], OBJ_ROAD
    je .ground
    cmp byte [rax+T_OBJ], OBJ_RAIL
    jne .end
.ground:
    xor ebx, ebx
.sh:
    cmp ebx, [pt_n]
    jge .tr0
    mov edi, FW_SHIP
    mov esi, ebx
    call follow_try
    inc ebx
    jmp .sh
.tr0:
    xor ebx, ebx
.tr:
    mov edi, FW_TRAIN
    mov esi, ebx
    call follow_try
    inc ebx
    cmp ebx, TR_MAX
    jl .tr
    xor ebx, ebx
.car:
    mov edi, FW_CAR
    mov esi, ebx
    call follow_try
    inc ebx
    cmp ebx, MAX_VEH
    jl .car
.end:
    xor eax, eax
    cmp dword [follow_kind], 0
    je .out
    mov eax, [cam_x]
    mov [follow_cx], eax
    mov eax, [cam_y]
    mov [follow_cy], eax
    mov dword [sel_x], -1
    mov eax, 1
.out:
    RETURN

; every frame (beta): keep it in the middle of the view
FUNC follow_update
    cmp dword [follow_kind], 0
    je .out
    ; the view moved by other hands: let go
    mov eax, [cam_x]
    cmp eax, [follow_cx]
    jne .stop
    mov eax, [cam_y]
    cmp eax, [follow_cy]
    jne .stop
    mov edi, [follow_kind]
    mov esi, [follow_idx]
    call follow_pos
    test eax, eax
    jz .stop
    call world_proj
    mov ecx, [fb_w]
    shr ecx, 1
    sub eax, ecx
    add [cam_x], eax
    mov ecx, [fb_h]
    shr ecx, 1
    sub edx, ecx
    add [cam_y], edx
    call camera_clamp
    mov eax, [cam_x]
    mov [follow_cx], eax
    mov eax, [cam_y]
    mov [follow_cy], eax
    jmp .out
.stop:
    mov dword [follow_kind], 0
.out:
    RETURN

; the line saying what's followed (ui)
FUNC follow_draw
    mov eax, [follow_kind]
    test eax, eax
    jz .out
    cmp eax, FW_SHIP
    ja .out
    mov rdx, [fw_names+rax*8]
    mov edi, [ui_w]
    shr edi, 1
    mov esi, [ui_h]
    sub esi, DOCK_BTN+26
    mov ecx, UI_GOLD
    call draw_text_centered
.out:
    RETURN

; ---------------------------------------------------------------------
;  history (beta): six more monthly graphs, beside the budget's two -
;  traffic flow, commute, happiness, transit riders, trade and jams.
;  Saved with the city ("HIST"), on the same 64-month ring.
; ---------------------------------------------------------------------
HS_N        equ 6

section .bss
alignb 4
hist_state:
hist_series resd HS_N*64
hist_state_end:

section .data
hs_names    dq hsn0, hsn1, hsn2, hsn3, hsn4, hsn5
hsn0        db "Traffic flow (%)", 0
hsn1        db "Commute", 0
hsn2        db "Happiness (%)", 0
hsn3        db "Transit riders / month", 0
hsn4        db "Trade / month ($)", 0
hsn5        db "Jammed roads", 0
hs_cols     dd UI_GOOD, UI_WARN, UI_GOLD, UI_ACCENT, UI_GOOD, UI_BAD
s_hs_title  db "History", 0
s_hs_btn    db "History", 0
s_hs_now    db "now ", 0

section .text

hist_reset:
    push rdi
    push rcx
    lea rdi, [hist_state]
    mov ecx, (hist_state_end - hist_state)/4
    xor eax, eax
    rep stosd
    pop rcx
    pop rdi
    ret

; the month's samples (beta; at hist_count, before it moves on)
FUNC hist_month
    cmp dword [beta_on], 0
    je .out
    mov ebx, [hist_count]
    and ebx, 63
    mov eax, [flow_pct]
    mov [hist_series+0*256+rbx*4], eax
    mov eax, [avg_commute]
    mov [hist_series+1*256+rbx*4], eax
    mov eax, [happy_avg]
    mov [hist_series+2*256+rbx*4], eax
    mov eax, [bus_riders]
    add eax, [metro_riders]
    add eax, [train_riders]
    add eax, [tram_riders]
    add eax, [ferry_riders]
    mov [hist_series+3*256+rbx*4], eax
    mov eax, [trade_last]
    mov [hist_series+4*256+rbx*4], eax
    ; jammed road tiles
    xor edx, edx
    xor ecx, ecx
.j:
    mov eax, ecx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    jne .jn
    cmp byte [tiles+rax+T_JAM], 150
    jb .jn
    inc edx
.jn:
    inc ecx
    cmp ecx, MAP_TILES
    jl .j
    mov [hist_series+5*256+rbx*4], edx
.out:
    RETURN

HS_W        equ 340
HS_H        equ 232

FUNC draw_history, 16
    mov r12d, [ui_w]
    sub r12d, HS_W
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, HS_H
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, HS_W
    mov ecx, HS_H
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, HS_W
    mov ecx, HS_H
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_hs_title]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    add r13d, 28
    xor ebx, ebx
.s:
    ; two columns
    mov eax, ebx
    and eax, 1
    imul r14d, eax, 165
    add r14d, r12d
    add r14d, 10
    mov eax, ebx
    shr eax, 1
    imul r15d, eax, 66
    add r15d, r13d
    ; the name and the latest value
    mov rdx, [hs_names+rbx*8]
    mov edi, r14d
    mov esi, r15d
    mov ecx, UI_TEXT
    call draw_text
    call tb_reset
    mov eax, [hist_count]
    dec eax
    and eax, 63
    mov ecx, ebx
    shl ecx, 6
    add eax, ecx
    movsxd rdi, dword [hist_series+rax*4]
    call tb_num
    lea edi, [r14+150]
    mov esi, r15d
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call draw_text_right
    ; the graph
    mov edi, r14d
    lea esi, [r15+10]
    mov eax, ebx
    shl eax, 8
    lea rdx, [hist_series+rax]
    mov ecx, [hs_cols+rbx*4]
    call draw_chart
    inc ebx
    cmp ebx, HS_N
    jl .s
    RETURN

; the statistics panel's button to it (beta; edi x, esi y)
FUNC hist_button
    cmp dword [beta_on], 0
    je .out
    mov edx, 70
    lea rcx, [s_hs_btn]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .out
    mov dword [panel], PANEL_HIST
.out:
    RETURN

; ---------------------------------------------------------------------
;  the Transit panel (beta): every kind of public transport, its lines
;  and stops, and how full it ran last month
; ---------------------------------------------------------------------
TP_W        equ 400
TP_H        equ 180

section .data
tp_names    dq tpn0, tpn1, tpn2, tpn3, tpn4, tpn5, tpn6
tpn0        db "Buses", 0
tpn1        db "Trams", 0
tpn2        db "Metro", 0
tpn3        db "Trains", 0
tpn4        db "Ferries", 0
tpn5        db "Planes", 0
tpn6        db "On foot", 0
s_tp_title  db "Transit", 0
s_tp_btn    db "Transit", 0
s_tp_depots db " depots, ", 0
s_tp_depots2 db " depots", 0
s_tp_stops  db " stops", 0
s_tp_lines  db " lines, ", 0
s_tp_stns   db " stations", 0
s_tp_trains db " trains", 0
s_tp_piers  db " piers", 0
s_tp_air    db " airports flying", 0
s_tp_of     db " of ", 0
s_tp_none   db "-", 0

section .text

; one row: the name, what there is (text builder), riders of room
; (ebx the row, r12d x, r13d y, r14d riders, r15d room: 0 no limit)
FUNC tp_row
    mov rdx, [tp_names+rbx*8]
    lea edi, [r12+10]
    mov esi, r13d
    mov ecx, UI_TEXT
    call draw_text
    lea edi, [r12+70]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call draw_text
    ; riders (of room)
    call tb_reset
    movsxd rdi, r14d
    call tb_num
    test r15d, r15d
    jz .nr
    lea rdi, [s_tp_of]
    call tb_str
    movsxd rdi, r15d
    call tb_num
.nr:
    lea edi, [r12+TP_W-80]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text_right
    ; how full
    test r15d, r15d
    jz .out
    lea edi, [r12+TP_W-74]
    lea esi, [r13+2]
    mov edx, 64
    mov ecx, 6
    mov r8d, UI_BG2
    call draw_box
    mov eax, r14d
    imul eax, eax, 64
    xor edx, edx
    div r15d
    CLAMP eax, 0, 64
    test eax, eax
    jz .out
    mov edx, eax
    lea edi, [r12+TP_W-74]
    lea esi, [r13+2]
    mov ecx, 6
    mov r8d, UI_GOOD
    cmp eax, 58
    jl .f
    mov r8d, UI_BAD
.f:
    call fill_rect
.out:
    RETURN

FUNC draw_transit, 16
    mov r12d, [ui_w]
    sub r12d, TP_W
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, TP_H
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, TP_W
    mov ecx, TP_H
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, TP_W
    mov ecx, TP_H
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_tp_title]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    add r13d, 30
    ; buses
    xor ebx, ebx
    call tb_reset
    movsxd rdi, dword [svc_count+BK_BUSDEPOT*4]
    call tb_num
    lea rdi, [s_tp_depots]
    call tb_str
    movsxd rdi, dword [n_stops]
    call tb_num
    lea rdi, [s_tp_stops]
    call tb_str
    mov r14d, [bus_riders]
    mov r15d, [svc_count+BK_BUSDEPOT*4]
    imul r15d, r15d, BUS_CAP
    call tp_row
    add r13d, 18
    ; trams
    inc ebx
    call tb_reset
    movsxd rdi, dword [tw_lines]
    call tb_num
    lea rdi, [s_tp_lines]
    call tb_str
    movsxd rdi, dword [svc_count+BK_TRAMDEPOT*4]
    call tb_num
    lea rdi, [s_tp_depots2]
    call tb_str
    mov r14d, [tram_riders]
    mov r15d, [svc_count+BK_TRAMDEPOT*4]
    imul r15d, r15d, TRM_CAP
    call tp_row
    add r13d, 18
    ; metro
    inc ebx
    call tb_reset
    movsxd rdi, dword [mt_n]
    call tb_num
    lea rdi, [s_tp_stns]
    call tb_str
    mov r14d, [metro_riders]
    mov r15d, [mt_n]
    imul r15d, r15d, MT_CAP
    call tp_row
    add r13d, 18
    ; trains
    inc ebx
    call tb_reset
    movsxd rdi, dword [rl_lines]
    call tb_num
    lea rdi, [s_tp_lines]
    call tb_str
    xor eax, eax
    xor ecx, ecx
.tr:
    cmp byte [tr_kind+rcx], 0
    je .trn
    inc eax
.trn:
    inc ecx
    cmp ecx, TR_MAX
    jl .tr
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_tp_trains]
    call tb_str
    ; (passenger stations' room)
    xor r15d, r15d
    xor ecx, ecx
.st:
    cmp ecx, [rl_n]
    jge .std
    cmp byte [rl_sfrt+rcx], 0
    jne .stn
    add r15d, RL_CAP
.stn:
    inc ecx
    jmp .st
.std:
    mov r14d, [train_riders]
    call tp_row
    add r13d, 18
    ; ferries
    inc ebx
    call tb_reset
    movsxd rdi, dword [fe_n]
    call tb_num
    lea rdi, [s_tp_piers]
    call tb_str
    mov r14d, [ferry_riders]
    mov r15d, [fe_n]
    imul r15d, r15d, FE_CAP
    call tp_row
    add r13d, 18
    ; planes
    inc ebx
    call tb_reset
    xor eax, eax
    xor ecx, ecx
.ap:
    cmp ecx, [ap_n]
    jge .apd
    cmp byte [ap_live+rcx], 0
    je .apn
    inc eax
.apn:
    inc ecx
    jmp .ap
.apd:
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_tp_air]
    call tb_str
    mov r14d, [air_pax]
    xor r15d, r15d
    call tp_row
    add r13d, 18
    ; on foot
    inc ebx
    call tb_reset
    mov r14d, [walkers]
    xor r15d, r15d
    call tp_row
    RETURN

; the statistics panel's button to it (beta; edi x, esi y)
FUNC transit_button
    cmp dword [beta_on], 0
    je .out
    mov edx, 70
    lea rcx, [s_tp_btn]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .out
    mov dword [panel], PANEL_TRANSIT
.out:
    RETURN

; ---------------------------------------------------------------------
;  the growth view (beta): each zoned lot coloured by what holds it
;  back - power (red), a road (grey), water or sewage (blue), demand
;  (yellow), the place itself (brown), services (orange); green grows
; ---------------------------------------------------------------------
OV_GROWTH   equ 25

section .data
gr_needs    db 22, 56, 88, 122, 156, 255   ; score for the next level
ov_growth_n db "Growth", 0
oh_growth   db 2, "growing  ", 3, "power  ", 6, "road  ", 7, "water  ", 4, "demand  ", 5, "place", 0

section .text

; (rdi tile, esi index) -> eax tint
growth_tint:
    movzx eax, byte [rdi+T_ZONE]
    test eax, eax
    jz .none
    cmp byte [rdi+T_OBJ], OBJ_ROAD
    je .none
    movzx ecx, byte [zone_class+rax]
    mov eax, TINT_GREY
    test byte [rdi+T_FLAGS], F_ROADOK
    jz .o
    mov eax, TINT_RED
    test byte [rdi+T_FLAGS], F_POWER
    jz .o
    movzx edx, byte [rdi+T_LEVEL]
    cmp byte [rdi+T_OBJ], OBJ_ZONEBLD
    je .b
    xor edx, edx
.b:
    test edx, edx
    jz .d
    mov eax, TINT_BLUE
    test byte [rdi+T_FLAGS], F_WATER
    jz .o
    test byte [rdi+T_FLAGS2], F2_SEWAGE
    jz .o
.d:
    mov eax, TINT_YELLOW
    cmp dword [demand+rcx*4], -30
    jl .o
    CLAMP edx, 0, 5
    movzx ecx, byte [gr_needs+rdx]
    mov eax, TINT_BROWN
    cmp byte [rdi+T_SCORE], cl
    jb .o
    ; top level, or a level that needs more than the place
    mov eax, TINT_GREEN
    cmp edx, 3
    jl .o
    cmp edx, 5
    jge .o
    movzx ecx, byte [map_police+rsi]
    movzx edx, byte [map_fire+rsi]
    add ecx, edx
    cmp ecx, 60
    jge .o
    mov eax, TINT_ORANGE
.o: ret
.none:
    xor eax, eax
    ret

; ---------------------------------------------------------------------
;  forecasts (beta): what will run out soon, at this pace - a line in
;  the city issues
; ---------------------------------------------------------------------
ISSUE_FORECAST equ 14

section .bss
fc_prev_pow resd 1
fc_prev_wat resd 1
fc_prev_land resd 1
fc_kind     resd 1              ; 0 none, 1 power, 2 water, 3 landfill, 4 money
fc_months   resd 1

section .data
fc_texts    dq 0, fct1, fct2, fct3, fct4
fct1        db "Power runs out in ~", 0
fct2        db "Water runs out in ~", 0
fct3        db "Landfill full in ~", 0
fct4        db "Broke in ~", 0
s_fc_months db " months", 0
s_fc_month  db " month", 0
s_fc_iss    db "Forecast", 0

section .text

; (edi what's left, esi used more each month) -> eax months, or 99
fc_months_left:
    mov eax, 99
    test esi, esi
    jle .o
    test edi, edi
    jl .z
    mov eax, edi
    xor edx, edx
    div esi
    ret
.z: xor eax, eax
.o: ret

; the month's forecast (beta)
FUNC forecast_month
    cmp dword [beta_on], 0
    je .out
    mov dword [fc_kind], 0
    mov dword [fc_months], 6        ; (no further than this)
    ; power
    mov edi, [power_supply]
    sub edi, [power_demand]
    mov esi, [power_demand]
    sub esi, [fc_prev_pow]
    mov eax, [power_demand]
    mov [fc_prev_pow], eax
    call fc_months_left
    cmp eax, [fc_months]
    jge .w
    mov [fc_months], eax
    mov dword [fc_kind], 1
.w:
    mov edi, [water_supply]
    sub edi, [water_demand]
    mov esi, [water_demand]
    sub esi, [fc_prev_wat]
    mov eax, [water_demand]
    mov [fc_prev_wat], eax
    call fc_months_left
    cmp eax, [fc_months]
    jge .l
    mov [fc_months], eax
    mov dword [fc_kind], 2
.l:
    mov edi, [landfill_cap]
    sub edi, [landfill_used]
    mov esi, [landfill_used]
    sub esi, [fc_prev_land]
    mov eax, [landfill_used]
    mov [fc_prev_land], eax
    cmp dword [landfill_cap], 0
    je .m
    cmp dword [svc_count+BK_INCIN*4], 0
    jne .m
    call fc_months_left
    cmp eax, [fc_months]
    jge .m
    mov [fc_months], eax
    mov dword [fc_kind], 3
.m:
    ; money: losing it at this rate
    mov esi, [expense_last]
    sub esi, [income_last]
    jle .out
    mov rdi, [money]
    test rdi, rdi
    jle .out
    cmp rdi, 0x7FFFFFFF
    jg .out
    call fc_months_left
    cmp eax, [fc_months]
    jge .out
    mov [fc_months], eax
    mov dword [fc_kind], 4
.out:
    RETURN

; the forecast line into the text builder -> eax 1 if there is one
FUNC forecast_text
    xor eax, eax
    mov ecx, [fc_kind]
    test ecx, ecx
    jz .out
    cmp ecx, 4
    ja .out
    call tb_reset
    mov ecx, [fc_kind]
    mov rdi, [fc_texts+rcx*8]
    call tb_str
    mov eax, [fc_months]
    inc eax
    push rax
    push rax
    movsxd rdi, eax
    call tb_num
    pop rax
    pop rax
    lea rdi, [s_fc_months]
    cmp eax, 1
    jne .pl
    lea rdi, [s_fc_month]
.pl:
    call tb_str
    mov eax, 1
.out:
    RETURN

; ---------------------------------------------------------------------
;  impact at the cursor (beta): a building that pollutes or is loud -
;  how many homes its smoke or noise would reach
; ---------------------------------------------------------------------
section .data
s_im_smoke  db ", smoke on ", 0
s_im_noise  db ", noise on ", 0
s_im_homes  db " homes", 0
section .text

; homes within r (edi) of the building being placed -> eax
FUNC homes_within, 16
    mov r14d, edi
    mov edi, [build_kind]
    call bld_rec
    movzx eax, byte [rax+BI_SIZE]
    shr eax, 1
    mov r12d, [tl_x]
    add r12d, eax
    mov r13d, [tl_y]
    add r13d, eax
    mov eax, r14d
    imul eax, eax
    mov [rbp-48], eax
    xor r15d, r15d
    mov ebx, r14d
    neg ebx
.y:
    cmp ebx, r14d
    jg .d
    mov ecx, r14d
    neg ecx
.x:
    cmp ecx, r14d
    jg .yn
    mov eax, ecx
    imul eax, ecx
    mov edx, ebx
    imul edx, ebx
    add eax, edx
    cmp eax, [rbp-48]
    jg .xn
    lea edi, [r12+rcx]
    lea esi, [r13+rbx]
    cmp edi, MAP_W
    jae .xn
    cmp esi, MAP_W
    jae .xn
    shl esi, MAP_SHIFT
    add esi, edi
    mov eax, esi
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ZONEBLD
    jne .xn
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .xn
    movzx edx, byte [tiles+rax+T_ZONE]
    cmp byte [zone_class+rdx], ZC_RES
    jne .xn
    inc r15d
.xn:
    inc ecx
    jmp .x
.yn:
    inc ebx
    jmp .y
.d:
    mov eax, r15d
    RETURN

; the text builder gets " smoke on N homes" / " noise on N homes"
FUNC impact_text
    cmp dword [beta_on], 0
    je .out
    mov edi, [build_kind]
    call bld_rec
    mov rbx, rax
    cmp byte [rbx+BI_POLL], 10
    jb .n
    mov edi, 9
    call homes_within
    test eax, eax
    jz .n
    mov r12d, eax
    lea rdi, [s_im_smoke]
    call tb_str
    movsxd rdi, r12d
    call tb_num
    lea rdi, [s_im_homes]
    call tb_str
.n:
    cmp byte [rbx+BI_NOISE], 30
    jb .out
    mov edi, 4
    call homes_within
    test eax, eax
    jz .out
    mov r12d, eax
    lea rdi, [s_im_noise]
    call tb_str
    movsxd rdi, r12d
    call tb_num
    lea rdi, [s_im_homes]
    call tb_str
.out:
    RETURN

; ---------------------------------------------------------------------
;  colour-blind views (beta setting): the info views' heat scale runs
;  blue to orange instead of green to red, and "good"/"bad" become blue
;  and orange
; ---------------------------------------------------------------------
section .data
tint_std:
    dd 0
    dd 0x1E328C, 0x1E50AA, 0x1E78BE, 0x1EA0B4, 0x28B48C, 0x3CBE5A, 0x64C83C, 0x96D232
    dd 0xC8D232, 0xE6BE28, 0xF0A028, 0xF0781E, 0xE6501E, 0xD2321E, 0xB41E1E, 0x8C141E
    dd 0xFFD23C, 0x3C96FF, 0xF03228, 0x50E6FF, 0x969696, 0x96642A, 0x50DC5A
    dd 0xFF8C1E, 0xFF50DC, 0, 0, 0, 0, 0, 0
tint_cb:
    dd 0
    dd 0x2846B4, 0x2A5AC8, 0x3C74D2, 0x508CDC, 0x64A0E6, 0x82B4E6, 0xA0C4DC, 0xBED2C8
    dd 0xDCD8A0, 0xF0D278, 0xF5C350, 0xF5AF3C, 0xF0962D, 0xE67D23, 0xD2641E, 0xB44B19
    dd 0xFFD23C, 0x3C96FF, 0xFF9A00, 0x50E6FF, 0x969696, 0x96642A, 0x3C96FF
    dd 0xFF8C1E, 0xFF50DC, 0, 0, 0, 0, 0, 0
s_st_cblind db "Colour-blind views: ", 0
section .text

apply_cblind:
    push rsi
    push rdi
    push rcx
    lea rsi, [tint_std]
    cmp dword [beta_on], 0
    je .c
    cmp dword [set_cblind], 0
    je .c
    lea rsi, [tint_cb]
.c:
    lea rdi, [tint_rgb]
    mov ecx, 32
    rep movsd
    pop rcx
    pop rdi
    pop rsi
    ret

; ---------------------------------------------------------------------
;  recent tools (beta): the last five things picked from the menus, in
;  a row above the dock - a click picks one again
; ---------------------------------------------------------------------
RT_N        equ 5

section .bss
rt_list     resd RT_N
rt_n        resd 1
rt_busy     resd 1              ; (picking from the row itself)

section .text

; a menu item was picked (edi its code): to the front of the row
recent_note:
    cmp dword [beta_on], 0
    je .o
    cmp dword [rt_busy], 0
    jne .o
    cmp edi, SI_OVERLAY
    jae .o
    push rbx
    ; where it is now (or the end)
    xor ecx, ecx
.f:
    cmp ecx, [rt_n]
    jge .nf
    cmp [rt_list+rcx*4], edi
    je .mv
    inc ecx
    jmp .f
.nf:
    mov ecx, [rt_n]
    cmp ecx, RT_N
    jl .grow
    mov ecx, RT_N-1
    jmp .mv
.grow:
    inc dword [rt_n]
.mv:
    ; the ones before it move back one
    test ecx, ecx
    jz .put
    mov eax, [rt_list+rcx*4-4]
    mov [rt_list+rcx*4], eax
    dec ecx
    jmp .mv
.put:
    mov [rt_list], edi
    pop rbx
.o: ret

FUNC draw_recent, 16
    cmp dword [beta_on], 0
    je .out
    cmp dword [rt_n], 0
    je .out
    cmp dword [panel], PANEL_NONE
    jne .out
    cmp dword [follow_kind], 0
    jne .out
    cmp dword [tool], T_DISTRICT
    je .out
    cmp dword [welcome], 0
    jne .out
    ; a row above the dock, in the middle
    mov eax, [rt_n]
    imul eax, eax, 106
    mov r12d, [ui_w]
    sub r12d, eax
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, DOCK_BTN+22
    xor ebx, ebx
.b:
    mov edi, [rt_list+rbx*4]
    call submenu_item_info
    mov rcx, rax
    imul edi, ebx, 106
    add edi, r12d
    mov esi, r13d
    mov edx, 104
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .bn
    mov dword [rt_busy], 1
    mov edi, [rt_list+rbx*4]
    call submenu_select
    mov dword [rt_busy], 0
.bn:
    inc ebx
    cmp ebx, [rt_n]
    jl .b
.out:
    RETURN

; ---------------------------------------------------------------------
;  photo mode keys (beta): [ and ] turn the clock back and on, P saves
;  the picture (photo_001.bmp ...; on the web, a download)
; ---------------------------------------------------------------------
section .bss
photo_shot  resd 1
photo_n     resd 1
photo_name  resb 32
section .data
s_photo_pre db "photo_", 0
s_photo_ext db ".bmp", 0
section .text

; a key in photo mode (edi scancode) -> eax 1 if taken
photo_key:
    xor eax, eax
    cmp dword [photo_mode], 0
    je .o
    cmp edi, 47                     ; [
    jne .k1
    sub dword [tod], 4096
    and dword [tod], 0xFFFF
    mov eax, 1
    ret
.k1:
    cmp edi, 48                     ; ]
    jne .k2
    add dword [tod], 4096
    and dword [tod], 0xFFFF
    mov eax, 1
    ret
.k2:
    cmp edi, SC_P
    jne .o
    mov dword [photo_shot], 1
    mov dword [photo_hint_t], 0
    mov eax, 1
.o: ret

; after the frame is shown: the picture asked for
FUNC photo_after
    cmp dword [photo_shot], 0
    je .out
    mov dword [photo_shot], 0
    inc dword [photo_n]
    ; photo_NNN.bmp
    lea rdi, [photo_name]
    lea rsi, [s_photo_pre]
.c:
    mov al, [rsi]
    test al, al
    jz .num
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .c
.num:
    mov eax, [photo_n]
    xor edx, edx
    mov ecx, 100
    div ecx
    add al, '0'
    mov [rdi], al
    mov eax, edx
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [rdi+1], al
    add dl, '0'
    mov [rdi+2], dl
    add rdi, 3
    lea rsi, [s_photo_ext]
.e:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .e
    lea rdi, [photo_name]
    call video_screenshot
%ifdef WEB
    lea rdi, [photo_name]
    lea rsi, [photo_name]
    call web_export
%endif
.out:
    RETURN
