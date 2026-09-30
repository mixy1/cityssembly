; =====================================================================
;  QOL (beta) - small things that make the game easier to play
;
;  - Coverage gain: placing a police station, school, clinic, park ...
;    the price at the cursor says how many homes (or buildings) it
;    would reach that aren't served well now.
;  - Photo mode (F): the interface goes, the city stays; F or Esc
;    brings it back.
;  - Follow camera: click a car, train, plane or ship with the
;    inspector and the view follows it.
; =====================================================================
section .bss
photo_mode  resd 1
photo_hint_t resd 1

section .data
s_cg_homes  db " homes", 0
s_cg_blds   db " buildings", 0
s_photo     db "Photo mode - F or Esc to come back", 0

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
