; =====================================================================
;  TUTORIAL - a first-time guided tour
;
;  Starts when a new city begins (not when one is continued) until the
;  player has finished or skipped it once (remembered in the settings),
;  and can be replayed from the help panel.  Each step highlights one
;  thing on screen (a dock button, the speed buttons, the demand bars,
;  the goal, or the end of the highway in the world), dims the rest and
;  shows a card with Next / Skip.  Steps that ask for an action finish by
;  themselves once the player has done it.
; =====================================================================

TK_NONE     equ 0           ; highlight: nothing (card in the middle)
TK_DOCK     equ 1           ;   dock button (arg: index)
TK_SPEED    equ 2           ;   the speed buttons
TK_RCIO     equ 3           ;   the demand bars
TK_GOAL     equ 4           ;   the goal panel
TK_HWY      equ 5           ;   the end of the highway, in the world

DK_NEXT     equ 0           ; done: when Next is pressed
DK_SUBMENU  equ 1           ;   that submenu is open (arg)
DK_ROADS    equ 2           ;   arg more road tiles than at the start
DK_ZONE     equ 3           ;   6 tiles of that zone class (arg)
DK_POWER    equ 4           ;   a power plant is producing
DK_WATER    equ 5           ;   water is flowing
DK_POP      equ 6           ;   population >= arg

TUT_W       equ 270

section .data
tut_step    dd -1           ; -1: no tour
section .bss
tut_base    resd 1          ; road tiles when the step began
tut_anim    resd 1
tut_freeze  resd 1          ; test screenshots: no auto-advance

section .data
align 8
; title, text, target, target arg, done, done arg
%macro TSTEP 6
    dq %1, %2
    dd %3, %4, %5, %6
%endmacro
tut_steps:
    TSTEP tt0, tx0, TK_NONE, 0, DK_NEXT, 0
    TSTEP tt1, tx1, TK_NONE, 0, DK_NEXT, 0
    TSTEP tt2, tx2, TK_DOCK, 2, DK_SUBMENU, 0
    TSTEP tt3, tx3, TK_HWY, 0, DK_ROADS, 6
    TSTEP tt4, tx4, TK_DOCK, 3, DK_ZONE, ZC_RES
    TSTEP tt5, tx5, TK_DOCK, 3, DK_ZONE, ZC_IND
    TSTEP tt6, tx6, TK_DOCK, 4, DK_POWER, 0
    TSTEP tt7, tx7, TK_DOCK, 5, DK_WATER, 0
    TSTEP tt8, tx8, TK_SPEED, 0, DK_POP, 20
    TSTEP tt9, tx9, TK_RCIO, 0, DK_NEXT, 0
    TSTEP tt10, tx10, TK_DOCK, 13, DK_NEXT, 0
    TSTEP tt11, tx11, TK_GOAL, 0, DK_NEXT, 0
TUT_COUNT equ ($-tut_steps)/32

tt0  db "Welcome, Mayor!", 0
tx0  db "This short tour walks you through your first", 10
     db "neighbourhood. You can skip it at any time.", 0
tt1  db "Look around", 0
tx1  db "Right-drag or use WASD to move the view.", 10
     db "Scroll the mouse wheel to zoom in and out.", 0
tt2  db "Roads", 0
tx2  db "Everything starts with a road.", 10
     db "Open the roads menu (R).", 0
tt3  db "Lay your first road", 0
tx3  db "Drag from the end of the highway into your", 10
     db "land. Water pipes run under every road.", 0
tt4  db "Homes", 0
tx4  db "Open zoning and pick Residential, then drag", 10
     db "to paint a strip of land along your road.", 0
tt5  db "Jobs", 0
tx5  db "People need work. Paint some Industry a", 10
     db "little further along the road.", 0
tt6  db "Electricity", 0
tx6  db "Build a power plant from this menu (wind is", 10
     db "cheap to start). Power spreads between", 10
     db "buildings; power lines carry it further.", 0
tt7  db "Water", 0
tx7  db "Place a water tower touching a road, so it", 10
     db "feeds the pipes. Later, add a sewage outlet", 10
     db "at the water's edge.", 0
tt8  db "Let it grow", 0
tx8  db "Unpause and speed up time with these buttons,", 10
     db "then watch the first homes go up.", 0
tt9  db "Demand", 0
tx9  db "These bars show what your city wants next:", 10
     db "Residential, Commercial, Industry and Offices.", 0
tt10 db "Info views", 0
tx10 db "Icons above buildings mean trouble: click one", 10
     db "to see what's wrong. Info views (O) show power,", 10
     db "water, traffic, land value and more.", 0
tt11 db "Goals", 0
tx11 db "Follow the goals up here for rewards and new", 10
     db "buildings. Good luck, Mayor!", 0
s_tut_next   db "Next", 0
s_tut_done   db "Let's go", 0
s_tut_skip   db "Skip tour", 0
s_tut_do     db "Do it, or press Next", 0
s_tut_replay db "Take the tour", 0

section .text

; start (or restart) the tour
tut_start:
    mov dword [tut_step], 0
    mov dword [tut_anim], 0
    jmp tut_enter

; a new city begins: the tour, if it hasn't been seen yet
tut_maybe_start:
    cmp dword [set_tutdone], 0
    jne .o
    cmp dword [sandbox], 0
    jne .o
    jmp tut_start
.o: ret

; the tour ends (finished or skipped): remember it
FUNC tut_end
    mov dword [tut_step], -1
    mov dword [set_tutdone], 1
    call settings_save
    RETURN

; a step begins: note where the player starts from
tut_enter:
    call tut_count_roads
    mov [tut_base], eax
    ret

tut_count_roads:
    xor eax, eax
    xor ecx, ecx
.l:
    mov edx, ecx
    shl edx, TILE_SHIFT
    cmp byte [tiles+rdx+T_OBJ], OBJ_ROAD
    jne .n
    inc eax
.n:
    inc ecx
    cmp ecx, MAP_TILES
    jl .l
    ret

; tiles zoned for class edi -> eax
tut_count_zone:
    xor eax, eax
    xor ecx, ecx
.l:
    mov edx, ecx
    shl edx, TILE_SHIFT
    movzx edx, byte [tiles+rdx+T_ZONE]
    test edx, edx
    jz .n
    movzx edx, byte [zone_class+rdx]
    cmp edx, edi
    jne .n
    inc eax
.n:
    inc ecx
    cmp ecx, MAP_TILES
    jl .l
    ret

; has the current step been done? -> eax
FUNC tut_done
    mov eax, [tut_step]
    shl eax, 5
    lea rbx, [tut_steps+rax]
    mov eax, [rbx+24]
    mov r12d, [rbx+28]
    cmp eax, DK_SUBMENU
    jne .d2
    xor eax, eax
    cmp [submenu], r12d
    sete al
    RETURN
.d2:
    cmp eax, DK_ROADS
    jne .d3
    call tut_count_roads
    sub eax, [tut_base]
    cmp eax, r12d
    setge al
    movzx eax, al
    RETURN
.d3:
    cmp eax, DK_ZONE
    jne .d4
    mov edi, r12d
    call tut_count_zone
    cmp eax, 6
    setge al
    movzx eax, al
    RETURN
.d4:
    cmp eax, DK_POWER
    jne .d5
    xor eax, eax
    cmp dword [power_supply], 0
    setg al
    RETURN
.d5:
    cmp eax, DK_WATER
    jne .d6
    xor eax, eax
    cmp dword [water_supply], 0
    setg al
    RETURN
.d6:
    cmp eax, DK_POP
    jne .dn
    xor eax, eax
    cmp [population], r12d
    setge al
    RETURN
.dn:
    xor eax, eax
    RETURN

; the highlighted rect -> [rbp-48..-60] x, y, w, h (ui px); eax 0 = none
FUNC tut_target, 16
    mov eax, [tut_step]
    shl eax, 5
    lea rbx, [tut_steps+rax]
    mov eax, [rbx+16]
    mov r12d, [rbx+20]
    cmp eax, TK_DOCK
    jne .t2
    ; the dock layout (see draw_dock)
    mov eax, DOCK_COUNT
    imul eax, DOCK_BTN+2
    add eax, 8
    mov ecx, [ui_w]
    sub ecx, eax
    shr ecx, 1
    imul eax, r12d, DOCK_BTN+2
    lea edi, [rcx+rax+4]
    mov esi, [ui_h]
    sub esi, DOCK_BTN+8
    add esi, 3
    mov edx, DOCK_BTN
    mov ecx, DOCK_BTN
    jmp .have
.t2:
    cmp eax, TK_SPEED
    jne .t3
    mov edi, [ui_w]
    sub edi, 90
    mov esi, 2
    mov edx, 86
    mov ecx, 14
    jmp .have
.t3:
    cmp eax, TK_RCIO
    jne .t4
    mov edi, 282
    mov esi, 1
    mov edx, 64
    mov ecx, 16
    jmp .have
.t4:
    cmp eax, TK_GOAL
    jne .t5
    mov edi, 3
    mov esi, 20
    mov edx, 260
    mov ecx, 16
    jmp .have
.t5:
    cmp eax, TK_HWY
    jne .none
    ; the last highway tile on the highway's row, in ui pixels
    xor ebx, ebx
    xor r13d, r13d
.hw:
    mov edi, ebx
    mov esi, [hwy_row]
    call tile_at
    test rax, rax
    jz .hwn
    test byte [rax+T_FLAGS], F_HIGHWAY
    jz .hwn
    mov r13d, ebx
.hwn:
    inc ebx
    cmp ebx, 48
    jl .hw
    mov edi, r13d
    mov esi, [hwy_row]
    call tile_screen                ; world pixels (back corner)
    add edx, 8                      ; tile centre
    imul eax, [zoom]
    imul edx, [zoom]
    xor ecx, ecx
    mov r8d, [ui_scale]
    push rdx
    push rdx
    cdq
    idiv r8d
    mov edi, eax
    pop rax
    pop rax
    cdq
    idiv r8d
    mov esi, eax
    ; a box around the tile, sized by the zoom
    mov eax, [zoom]
    shl eax, 4
    cdq
    idiv r8d
    mov edx, eax
    sub edi, edx
    sub esi, edx
    add edx, edx
    mov ecx, edx
    jmp .have
.none:
    xor eax, eax
    RETURN
.have:
    mov [tut_rx], edi
    mov [tut_ry], esi
    mov [tut_rw], edx
    mov [tut_rh], ecx
    mov eax, 1
    RETURN

section .bss
tut_rx resd 1
tut_ry resd 1
tut_rw resd 1
tut_rh resd 1
section .text

; draw the tour on the ui layer (last, over everything)
FUNC draw_tutorial, 48
    cmp dword [tut_step], 0
    jl .out
    cmp dword [welcome], 0
    jne .out
    inc dword [tut_anim]
    ; an action step that's been done moves on by itself
    cmp dword [tut_freeze], 0
    jne .show
    call tut_done
    test eax, eax
    jz .show
    mov edi, SFX_CHIME
    call sfx_play
    call tut_next
    cmp dword [tut_step], 0
    jl .out
.show:
    call tut_target
    mov [rbp-48], eax
    test eax, eax
    jz .card
    ; dim everything around the highlight
    mov eax, [tut_rx]
    sub eax, 3
    mov [rbp-52], eax               ; x0
    mov eax, [tut_ry]
    sub eax, 3
    mov [rbp-56], eax               ; y0
    mov eax, [tut_rx]
    add eax, [tut_rw]
    add eax, 3
    mov [rbp-60], eax               ; x1
    mov eax, [tut_ry]
    add eax, [tut_rh]
    add eax, 3
    mov [rbp-64], eax               ; y1
    ; top
    xor edi, edi
    xor esi, esi
    mov edx, [ui_w]
    mov ecx, [rbp-56]
    mov r8d, UI_SHADOW
    call tut_fill
    ; bottom
    xor edi, edi
    mov esi, [rbp-64]
    mov edx, [ui_w]
    mov ecx, [ui_h]
    sub ecx, esi
    mov r8d, UI_SHADOW
    call tut_fill
    ; left
    xor edi, edi
    mov esi, [rbp-56]
    mov edx, [rbp-52]
    mov ecx, [rbp-64]
    sub ecx, esi
    mov r8d, UI_SHADOW
    call tut_fill
    ; right
    mov edi, [rbp-60]
    mov esi, [rbp-56]
    mov edx, [ui_w]
    sub edx, edi
    mov ecx, [rbp-64]
    sub ecx, esi
    mov r8d, UI_SHADOW
    call tut_fill
    ; a pulsing frame
    mov r8d, UI_GOLD
    mov eax, [tut_anim]
    and eax, 32
    jz .pc
    mov r8d, UI_TEXT
.pc:
    mov edi, [rbp-52]
    mov esi, [rbp-56]
    mov edx, [rbp-60]
    sub edx, edi
    mov ecx, [rbp-64]
    sub ecx, esi
    push r8
    push r8
    call rect_outline
    pop r8
    pop r8
    mov edi, [rbp-52]
    inc edi
    mov esi, [rbp-56]
    inc esi
    mov edx, [rbp-60]
    sub edx, edi
    dec edx
    mov ecx, [rbp-64]
    sub ecx, esi
    dec ecx
    call rect_outline
.card:
    ; ---- the card: size from its text ----
    mov eax, [tut_step]
    shl eax, 5
    lea r15, [tut_steps+rax]
    mov rdi, [r15+8]
    call count_lines
    imul eax, eax, 10
    add eax, 50
    mov r13d, eax                   ; height
    ; place it: above a dock button, below a top target, else centred
    mov eax, [ui_w]
    sub eax, TUT_W
    shr eax, 1
    mov r12d, eax                   ; x
    mov eax, [ui_h]
    sub eax, r13d
    shr eax, 1
    sub eax, 30
    mov r14d, eax                   ; y
    cmp dword [rbp-48], 0
    je .place
    mov eax, [r15+16]
    cmp eax, TK_DOCK
    jne .pl2
    mov eax, [tut_rx]
    add eax, DOCK_BTN / 2
    sub eax, TUT_W / 2
    mov r12d, eax
    mov eax, [tut_ry]
    sub eax, r13d
    sub eax, 16
    mov r14d, eax
    jmp .place
.pl2:
    cmp eax, TK_HWY
    jne .pl3
    ; beside the highway end, away from it
    mov eax, [tut_rx]
    add eax, [tut_rw]
    add eax, 24
    mov r12d, eax
    mov eax, [tut_ry]
    add eax, [tut_rh]
    add eax, 24
    mov r14d, eax
    jmp .place
.pl3:
    ; top targets: under them
    mov eax, [tut_rx]
    add eax, [tut_rw]
    sub eax, TUT_W
    cmp dword [r15+16], TK_GOAL
    jne .pl4
    mov eax, [tut_rx]
.pl4:
    cmp dword [r15+16], TK_RCIO
    jne .pl5
    mov eax, [tut_rx]
    sub eax, TUT_W / 2
.pl5:
    mov r12d, eax
    mov eax, [tut_ry]
    add eax, [tut_rh]
    add eax, 14
    mov r14d, eax
.place:
    mov eax, [ui_w]
    sub eax, TUT_W + 4
    CLAMP r12d, 4, eax
    mov eax, [ui_h]
    sub eax, r13d
    sub eax, 40
    CLAMP r14d, 40, eax
    mov edi, r12d
    mov esi, r14d
    mov edx, TUT_W
    mov ecx, r13d
    call draw_panel
    ; keep clicks on the card away from the world
    mov edi, r12d
    mov esi, r14d
    mov edx, TUT_W
    mov ecx, r13d
    call ui_over
    ; step counter
    call tb_reset
    mov edi, [tut_step]
    inc edi
    call tb_num
    mov edi, '/'
    call tb_char
    mov edi, TUT_COUNT
    call tb_num
    lea edi, [r12+TUT_W-8]
    lea esi, [r14+7]
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call draw_text_right
    ; title and text
    lea edi, [r12+10]
    lea esi, [r14+7]
    mov rdx, [r15]
    mov ecx, UI_GOLD
    call draw_text
    lea edi, [r12+10]
    lea esi, [r14+22]
    mov rdx, [r15+8]
    mov ecx, UI_TEXT
    call draw_text
    ; buttons
    lea esi, [r14+r13-20]
    mov [rbp-68], esi
    lea edi, [r12+8]
    mov edx, 66
    lea rcx, [s_tut_skip]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .ns
    call tut_end
    jmp .out
.ns:
    cmp dword [r15+24], DK_NEXT
    je .nb
    lea edi, [r12+84]
    mov esi, [rbp-68]
    add esi, 3
    lea rdx, [s_tut_do]
    mov ecx, UI_DIM
    call draw_text
.nb:
    lea rcx, [s_tut_next]
    mov eax, [tut_step]
    inc eax
    cmp eax, TUT_COUNT
    jl .nl
    lea rcx, [s_tut_done]
.nl:
    lea edi, [r12+TUT_W-66]
    mov esi, [rbp-68]
    mov edx, 58
    mov r8d, 1
    call text_button
    test eax, eax
    jz .out
    call tut_next
.out:
    RETURN

; fill_rect that ignores empty or negative sizes
tut_fill:
    test edx, edx
    jle .o
    test ecx, ecx
    jle .o
    jmp fill_rect
.o: ret

FUNC tut_next
    inc dword [tut_step]
    cmp dword [tut_step], TUT_COUNT
    jl .go
    call tut_end
    RETURN
.go:
    call tut_enter
    RETURN
