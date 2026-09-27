; =====================================================================
;  TUTORIAL - the first-time tour: build a practice village, lose it,
;  clean up, then start for real
;
;  Every new city begins with the offer of a tour (Help also starts it).
;  Once the player takes it, the map and the whole sim state are set aside, and the player builds a small village
;  with every mechanic: roads, zones, power and lines, water and sewage,
;  time and demand, services, info views, the inspector and the budget.
;  Money is topped up, all land is owned and everything is unlocked.
;  Then meteors wipe the village out and the player bulldozes the
;  rubble.  Finishing (or skipping) puts the set-aside world and state
;  back: a fresh start with the real budget and date.
;
;  Each step highlights one thing (a dock button, the speed buttons, the
;  demand bars, the goal, or the end of the highway in the world), dims
;  the rest and shows a card with Next / Skip.  Steps that ask for an
;  action move on by themselves once it's done; progress is measured
;  against the set-aside world, so a replay in a grown city works too.
; =====================================================================

TK_NONE     equ 0           ; highlight: nothing (card in the middle)
TK_DOCK     equ 1           ;   dock button (arg: index)
TK_SPEED    equ 2           ;   the speed buttons
TK_RCIO     equ 3           ;   the demand bars
TK_GOAL     equ 4           ;   the goal panel
TK_HWY      equ 5           ;   the end of the highway, in the world

DK_NEXT     equ 0           ; done: when Next is pressed
DK_SUBMENU  equ 1           ;   that submenu is open (arg)
DK_COUNT    equ 2           ;   arg2 more of kind arg than at the start
DK_POWER    equ 3           ;   a power plant was built
DK_WATER    equ 4           ;   a pump or water tower was built
DK_POP      equ 5           ;   population >= arg
DK_VIEW     equ 6           ;   an info view is on
DK_INSPECT  equ 7           ;   a building is being inspected
DK_PANEL    equ 8           ;   that panel is open (arg)
DK_METEOR   equ 9           ;   the meteor shower is over
DK_CLEAN    equ 10          ;   no rubble left from the village

; kinds counted against the set-aside world
KD_ROAD     equ 1           ; non-highway road tiles
KD_PYLON    equ 2
KD_RUBBLE   equ 3
KD_ZONE     equ 16          ; + zone class: zoned tiles
KD_SVC      equ 32          ; + building kind: service anchors

TUT_W       equ 280
TUT_MONEY   equ 5000000
MET_STRIKES equ 5
MET_GAP     equ 26          ; frames between strikes
TUT_LIST    equ 4096

section .data
tut_step    dd -1           ; -1: no tour
section .bss
tut_anim    resd 1
tut_freeze  resd 1          ; test screenshots: no auto-advance
tut_bubble  resd 1          ; 1: the practice village is running
tut_met_t   resd 1          ; meteor shower frame
tut_met_done resd 1
tut_list_n  resd 1
tut_list    resd TUT_LIST
alignb 16
tut_tiles   resb MAP_TILES*TILE_BYTES       ; the set-aside world
tut_sim     resb sim_state_end - money     ; and sim state

section .data
align 8
; title, text, target, target arg, done, done arg, done arg 2, pad
%macro TSTEP 7
    dq %1, %2
    dd %3, %4, %5, %6, %7, 0
%endmacro
TSTEP_BYTES equ 40
tut_steps:
    TSTEP tt0,  tx0,  TK_NONE, 0,   DK_NEXT, 0, 0
    TSTEP tt1,  tx1,  TK_NONE, 0,   DK_NEXT, 0, 0
    TSTEP tt2,  tx2,  TK_DOCK, 2,   DK_SUBMENU, 0, 0
    TSTEP tt3,  tx3,  TK_HWY, 0,    DK_COUNT, KD_ROAD, 8
    TSTEP tt4,  tx4,  TK_DOCK, 3,   DK_COUNT, KD_ZONE+ZC_RES, 8
    TSTEP tt5,  tx5,  TK_DOCK, 3,   DK_COUNT, KD_ZONE+ZC_COM, 4
    TSTEP tt6,  tx6,  TK_DOCK, 3,   DK_COUNT, KD_ZONE+ZC_IND, 4
    TSTEP tt7,  tx7,  TK_DOCK, 4,   DK_POWER, 0, 0
    TSTEP tt8,  tx8,  TK_DOCK, 4,   DK_COUNT, KD_PYLON, 2
    TSTEP tt9,  tx9,  TK_DOCK, 5,   DK_WATER, 0, 0
    TSTEP tt10, tx10, TK_DOCK, 5,   DK_COUNT, KD_SVC+BK_SEWAGE, 1
    TSTEP tt11, tx11, TK_SPEED, 0,  DK_POP, 20, 0
    TSTEP tt12, tx12, TK_RCIO, 0,   DK_NEXT, 0, 0
    TSTEP tt13, tx13, TK_DOCK, 7,   DK_COUNT, KD_SVC+BK_FIRE, 1
    TSTEP tt14, tx14, TK_DOCK, 8,   DK_COUNT, KD_SVC+BK_CLINIC, 1
    TSTEP tt15, tx15, TK_DOCK, 9,   DK_COUNT, KD_SVC+BK_ELEM, 1
    TSTEP tt16, tx16, TK_DOCK, 6,   DK_COUNT, KD_SVC+BK_LANDFILL, 1
    TSTEP tt17, tx17, TK_DOCK, 11,  DK_COUNT, KD_SVC+BK_PARK, 1
    TSTEP tt18, tx18, TK_DOCK, 13,  DK_VIEW, 0, 0
    TSTEP tt19, tx19, TK_DOCK, 0,   DK_INSPECT, 0, 0
    TSTEP tt20, tx20, TK_DOCK, 15,  DK_PANEL, PANEL_BUDGET, 0
    TSTEP tt21, tx21, TK_NONE, 0,   DK_METEOR, 0, 0
    TSTEP tt22, tx22, TK_DOCK, 1,   DK_CLEAN, 0, 0
    TSTEP tt23, tx23, TK_GOAL, 0,   DK_NEXT, 0, 0
TUT_COUNT equ ($-tut_steps)/TSTEP_BYTES

tt0  db "Welcome, Mayor! Take the tour?", 0
tx0  db "We'll build a practice village together, with", 10
     db "free money, all the land and everything", 10
     db "unlocked. Then your real city begins.", 0
tt1  db "Look around", 0
tx1  db "Right-drag or use WASD to move the view.", 10
     db "Scroll the mouse wheel to zoom in and out.", 0
tt2  db "Roads", 0
tx2  db "Everything starts with a road.", 10
     db "Open the roads menu (R).", 0
tt3  db "Your first road", 0
tx3  db "Drag a street from the end of the highway into", 10
     db "your land. Water pipes run under every road.", 0
tt4  db "Homes", 0
tx4  db "Open zoning, pick Residential and drag to paint", 10
     db "a strip of land along your road.", 0
tt5  db "Shops", 0
tx5  db "People want to shop nearby. Paint a little", 10
     db "Commercial along the road too.", 0
tt6  db "Jobs", 0
tx6  db "And they need work: paint some Industry a bit", 10
     db "further away (it's noisy and dirty).", 0
tt7  db "Electricity", 0
tx7  db "Build a power plant from this menu. A wind", 10
     db "turbine is cheap and clean.", 0
tt8  db "Power lines", 0
tx8  db "Power spreads between buildings that touch.", 10
     db "Drag a power line (same menu) to carry it", 10
     db "to your homes and jobs.", 0
tt9  db "Water", 0
tx9  db "Place a water tower right next to a road, so", 10
     db "it feeds the pipes under the streets.", 0
tt10 db "Sewage", 0
tx10 db "Homes need drains too. Place a sewage outlet", 10
     db "on the shore (it must touch water), and drag", 10
     db "pipes to it if no road reaches it.", 0
tt11 db "Let it grow", 0
tx11 db "Unpause and speed up time with these buttons,", 10
     db "then watch your first residents move in.", 0
tt12 db "Demand", 0
tx12 db "These bars show what the city wants next:", 10
     db "Residential, Commercial, Industry, Offices.", 0
tt13 db "Safety", 0
tx13 db "Fires spread fast. Build a fire station; the", 10
     db "police station is in the same menu.", 0
tt14 db "Health", 0
tx14 db "Sick people move away. Build a clinic.", 0
tt15 db "Schools", 0
tx15 db "Educated people take better jobs and pay more", 10
     db "tax. Build an elementary school.", 0
tt16 db "Garbage", 0
tx16 db "Trash piles up quickly. Build a landfill, away", 10
     db "from the homes.", 0
tt17 db "Parks", 0
tx17 db "Parks make people happier and land worth more.", 10
     db "Place one among the houses.", 0
tt18 db "Info views", 0
tx18 db "Info views show power, water, traffic, land", 10
     db "value and more. Open one from here (or O).", 0
tt19 db "Inspect", 0
tx19 db "Pick Inspect (Q) and click a building to see", 10
     db "who's there and what it needs. Icons over", 10
     db "buildings mean trouble: click them too.", 0
tt20 db "Budget", 0
tx20 db "Taxes pay for everything. Open the budget (F2)", 10
     db "to set taxes and check upkeep.", 0
tt21 db "Oh no!", 0
tx21 db "Meteors! Disasters can strike any city.", 0
tt22 db "Clean up", 0
tx22 db "Pick the bulldozer (B) and drag over the", 10
     db "rubble to clear it.", 0
tt23 db "Your city begins", 0
tx23 db "That was practice. Now your real city starts on", 10
     db "your own land with $30,000. Follow the goals", 10
     db "up here for rewards. Good luck, Mayor!", 0
s_tut_next   db "Next", 0
s_tut_take   db "Take the tour", 0
s_tut_no     db "No thanks", 0
s_tut_done   db "Start!", 0
s_tut_skip   db "Skip tour", 0
s_tut_do     db "Do it, or press Next", 0
s_tut_wait   db "Hold on...", 0
s_tut_left   db " tiles of rubble left", 0
s_tut_replay db "Take the tour", 0
s_tut_nosave db "Finish or skip the tour to save.", 0
s_tut_begin  db "Your city begins. Good luck, Mayor!", 0

section .text

; ---------------------------------------------------------------------
;  starting, finishing
; ---------------------------------------------------------------------
; start (or restart) the tour
FUNC tut_start
    mov dword [tut_step], 0
    mov dword [tut_anim], 0
    mov dword [tut_freeze], 0
    RETURN

; the offer was taken: set up the practice village
FUNC tut_begin
    cmp dword [tut_bubble], 0
    jne .o
    ; set the world and the sim state aside
    lea rsi, [tiles]
    lea rdi, [tut_tiles]
    mov ecx, MAP_TILES*TILE_BYTES/8
    rep movsq
    lea rsi, [money]
    lea rdi, [tut_sim]
    mov ecx, sim_state_end - money
    rep movsb
    ; practice rules
    mov dword [tut_bubble], 1
    mov qword [money], TUT_MONEY
    mov rax, [money]
    mov [money_shown], rax
    mov dword [milestone], 9        ; everything unlocked
    mov dword [disasters_on], 0
    lea rdi, [plot_owned]
    mov eax, 0x01010101
    mov ecx, (PLOTS*PLOTS+7)/4
    rep stosd
.o:
    RETURN

; a new city begins: offer the tour
tut_maybe_start:
    cmp dword [sandbox], 0
    jne .o
    jmp tut_start
.o: ret

; the tour is over (finished or skipped): the real game starts
FUNC tut_end
    mov dword [tut_step], -1
    mov dword [set_tutdone], 1
    call settings_save
    cmp dword [tut_bubble], 0
    je .o
    mov dword [tut_bubble], 0
    ; the set-aside world and state come back
    lea rsi, [tut_tiles]
    lea rdi, [tiles]
    mov ecx, MAP_TILES*TILE_BYTES/8
    rep movsq
    lea rsi, [tut_sim]
    lea rdi, [money]
    mov ecx, sim_state_end - money
    rep movsb
    mov rax, [money]
    mov [money_shown], rax
    call agents_init
    call roads_update_all
    mov dword [net_dirty], 1
    mov dword [cov_dirty], 1
    call networks_update
    call coverage_update
    call stats_update
    ; a clean slate
    mov dword [n_acts], 0
    mov dword [undo_top], 0
    lea rdi, [notif_time]
    xor eax, eax
    mov ecx, NOTIFS
    rep stosd
    mov dword [panel], PANEL_NONE
    mov dword [overlay_mode], 0
    mov dword [submenu], -1
    mov dword [tool], T_INSPECT
    mov dword [sel_x], -1
    mov dword [drag_active], 0
    lea rdi, [s_tut_begin]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_FANFARE
    call sfx_play
.o:
    RETURN

; the tour stops without putting anything back (a city was loaded, or a
; new one started: they replace the world anyway)
tut_abort:
    mov dword [tut_step], -1
    mov dword [tut_bubble], 0
    ret

FUNC tut_next
    cmp dword [tut_step], 0
    jne .n
    call tut_begin
.n:
    inc dword [tut_step]
    cmp dword [tut_step], TUT_COUNT
    jl .go
    call tut_end
    RETURN
.go:
    call tut_enter
    RETURN

; a step begins
FUNC tut_enter
    call tut_cur
    cmp dword [rax+24], DK_METEOR
    jne .o
    call tut_meteor_begin
.o:
    RETURN

; the current step's record -> rax
tut_cur:
    mov eax, [tut_step]
    imul eax, eax, TSTEP_BYTES
    lea rax, [tut_steps+rax]
    ret

; ---------------------------------------------------------------------
;  counting against the set-aside world
; ---------------------------------------------------------------------
; tiles of kind edi in the map at rsi -> eax
tut_count_in:
    push rbx
    push r12
    xor eax, eax
    xor ecx, ecx
    mov r12, rsi
.l:
    mov edx, ecx
    shl edx, TILE_SHIFT
    lea r8, [r12+rdx]
    movzx edx, byte [r8+T_OBJ]
    cmp edi, KD_ROAD
    jne .k2
    cmp edx, OBJ_ROAD
    jne .n
    test byte [r8+T_FLAGS], F_HIGHWAY
    jnz .n
    jmp .y
.k2:
    cmp edi, KD_PYLON
    jne .k3
    cmp edx, OBJ_POWER
    je .y
    jmp .n
.k3:
    cmp edi, KD_RUBBLE
    jne .k4
    cmp edx, OBJ_RUBBLE
    je .y
    jmp .n
.k4:
    cmp edi, KD_SVC
    jae .k5
    ; zoned tiles of a class
    movzx edx, byte [r8+T_ZONE]
    test edx, edx
    jz .n
    movzx edx, byte [zone_class+rdx]
    lea ebx, [rdi-KD_ZONE]
    cmp edx, ebx
    je .y
    jmp .n
.k5:
    cmp edx, OBJ_SERVICE
    jne .n
    test byte [r8+T_FLAGS], F_ANCHOR
    jz .n
    movzx edx, byte [r8+T_SUB]
    lea ebx, [rdi-KD_SVC]
    cmp edx, ebx
    jne .n
.y:
    inc eax
.n:
    inc ecx
    cmp ecx, MAP_TILES
    jl .l
    pop r12
    pop rbx
    ret

; how many more of kind edi than in the set-aside world -> eax
FUNC tut_more
    mov ebx, edi
    lea rsi, [tiles]
    call tut_count_in
    mov r12d, eax
    mov edi, ebx
    lea rsi, [tut_tiles]
    call tut_count_in
    sub r12d, eax
    mov eax, r12d
    RETURN

; has the current step been done? -> eax
FUNC tut_done
    call tut_cur
    mov rbx, rax
    mov eax, [rbx+24]
    mov r12d, [rbx+28]
    mov r13d, [rbx+32]
    cmp eax, DK_SUBMENU
    jne .d2
    xor eax, eax
    cmp [submenu], r12d
    sete al
    RETURN
.d2:
    cmp eax, DK_COUNT
    jne .d3
    mov edi, r12d
    call tut_more
    cmp eax, r13d
    setge al
    movzx eax, al
    RETURN
.d3:
    cmp eax, DK_POWER
    jne .d4
    xor r14d, r14d
    mov edi, KD_SVC+BK_COAL
    call tut_more
    add r14d, eax
    mov edi, KD_SVC+BK_WIND
    call tut_more
    add r14d, eax
    mov edi, KD_SVC+BK_SOLAR
    call tut_more
    add r14d, eax
    mov edi, KD_SVC+BK_NUCLEAR
    call tut_more
    add r14d, eax
    xor eax, eax
    cmp r14d, 0
    setg al
    RETURN
.d4:
    cmp eax, DK_WATER
    jne .d5
    mov edi, KD_SVC+BK_PUMP
    call tut_more
    mov r14d, eax
    mov edi, KD_SVC+BK_WTOWER
    call tut_more
    add r14d, eax
    xor eax, eax
    cmp r14d, 0
    setg al
    RETURN
.d5:
    cmp eax, DK_POP
    jne .d6
    xor eax, eax
    cmp [population], r12d
    setge al
    RETURN
.d6:
    cmp eax, DK_VIEW
    jne .d7
    xor eax, eax
    cmp dword [overlay_mode], 0
    setne al
    RETURN
.d7:
    cmp eax, DK_INSPECT
    jne .d8
    xor eax, eax
    cmp dword [tool], T_INSPECT
    jne .d7o
    cmp dword [sel_x], 0
    setge al
.d7o:
    RETURN
.d8:
    cmp eax, DK_PANEL
    jne .d9
    xor eax, eax
    cmp [panel], r12d
    sete al
    RETURN
.d9:
    cmp eax, DK_METEOR
    jne .d10
    mov eax, [tut_met_done]
    RETURN
.d10:
    cmp eax, DK_CLEAN
    jne .dn
    mov edi, KD_RUBBLE
    call tut_more
    cmp eax, 0
    setle al
    movzx eax, al
    RETURN
.dn:
    xor eax, eax
    RETURN

; ---------------------------------------------------------------------
;  the meteor shower
; ---------------------------------------------------------------------
; is tile index edi something the tour built? -> eax
tut_built:
    mov eax, edi
    shl eax, TILE_SHIFT
    movzx ecx, byte [tiles+rax+T_OBJ]
    cmp cl, [tut_tiles+rax+T_OBJ]
    je .n
    cmp ecx, OBJ_ZONEBLD
    je .y
    cmp ecx, OBJ_SERVICE
    je .y
    cmp ecx, OBJ_POWER
    je .y
    cmp ecx, OBJ_ROAD
    jne .n
    test byte [tiles+rax+T_FLAGS], F_HIGHWAY
    jnz .n
.y: mov eax, 1
    ret
.n: xor eax, eax
    ret

; list what the tour built, and look at it
FUNC tut_meteor_begin
    mov dword [tut_met_t], 0
    mov dword [tut_met_done], 0
    mov dword [panel], PANEL_NONE
    mov dword [overlay_mode], 0
    mov dword [submenu], -1
    mov dword [tool], T_INSPECT
    mov dword [sel_x], -1
    mov dword [tut_list_n], 0
    xor r12d, r12d                  ; sum x
    xor r13d, r13d                  ; sum y
    xor ebx, ebx
.l:
    mov edi, ebx
    call tut_built
    test eax, eax
    jz .n
    mov eax, ebx
    and eax, MAP_W-1
    add r12d, eax
    mov eax, ebx
    shr eax, MAP_SHIFT
    add r13d, eax
    mov eax, [tut_list_n]
    cmp eax, TUT_LIST
    jae .n
    mov [tut_list+rax*4], ebx
    inc dword [tut_list_n]
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    mov ecx, [tut_list_n]
    test ecx, ecx
    jz .o
    mov eax, r12d
    xor edx, edx
    div ecx
    mov edi, eax
    mov eax, r13d
    xor edx, edx
    div ecx
    mov esi, eax
    call camera_center_tile
.o:
    RETURN

; one frame of the shower
FUNC tut_meteor_frame
    cmp dword [tut_met_done], 0
    jne .o
    inc dword [tut_met_t]
    mov eax, [tut_met_t]
    cmp dword [tut_list_n], 0
    je .sweep
    ; a strike every MET_GAP frames
    xor edx, edx
    mov ecx, MET_GAP
    div ecx
    test edx, edx
    jnz .late
    cmp eax, MET_STRIKES
    ja .late
    test eax, eax
    jz .late
    mov edi, [tut_list_n]
    call rand_range
    mov eax, [tut_list+rax*4]
    mov edi, eax
    and edi, MAP_W-1
    mov esi, eax
    shr esi, MAP_SHIFT
    call meteor_strike
.late:
    cmp dword [tut_met_t], MET_GAP*(MET_STRIKES+1)+30
    jl .o
.sweep:
    ; whatever is left of the village turns to rubble
    xor ebx, ebx
.s:
    mov edi, ebx
    call tut_built
    test eax, eax
    jz .sp
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    call make_rubble
.sp:
    ; zones and pipes as they were
    mov eax, ebx
    shl eax, TILE_SHIFT
    mov cl, [tut_tiles+rax+T_ZONE]
    cmp byte [tiles+rax+T_OBJ], OBJ_RUBBLE
    jne .sz
    mov [tiles+rax+T_ZONE], cl
.sz:
    mov cl, [tut_tiles+rax+T_FLAGS2]
    and cl, F2_PIPE
    and byte [tiles+rax+T_FLAGS2], ~F2_PIPE
    or [tiles+rax+T_FLAGS2], cl
    inc ebx
    cmp ebx, MAP_TILES
    jl .s
    ; the wires as they were
    mov eax, [tut_sim+(n_wires-money)]
    mov [n_wires], eax
    lea rsi, [tut_sim+(wire_a-money)]
    lea rdi, [wire_a]
    mov ecx, MAX_WIRES*4
    rep movsb
    ; a last flurry of smoke over the village
    mov ebx, 10
.fx:
    cmp dword [tut_list_n], 0
    je .fxd
    mov edi, [tut_list_n]
    call rand_range
    mov eax, [tut_list+rax*4]
    mov edi, eax
    and edi, MAP_W-1
    mov esi, eax
    shr esi, MAP_SHIFT
    call fx_smoke_burst
    dec ebx
    jnz .fx
.fxd:
    mov dword [shake], 30
    call roads_update_all
    mov dword [net_dirty], 1
    call networks_update
    mov dword [tut_met_done], 1
.o:
    RETURN

; ---------------------------------------------------------------------
;  the highlighted rect -> tut_rx..tut_rh (ui px); eax 0 = none
; ---------------------------------------------------------------------
FUNC tut_target, 16
    call tut_cur
    mov rbx, rax
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

; ---------------------------------------------------------------------
;  draw the tour on the ui layer (last, over everything)
; ---------------------------------------------------------------------
FUNC draw_tutorial, 48
    cmp dword [tut_step], 0
    jl .out
    cmp dword [welcome], 0
    jne .out
    inc dword [tut_anim]
    ; practice money never runs out
    cmp dword [tut_bubble], 0
    je .nm
    cmp qword [money], TUT_MONEY/2
    jge .nm
    mov qword [money], TUT_MONEY
.nm:
    call tut_cur
    cmp dword [rax+24], DK_METEOR
    jne .nmet
    call tut_meteor_frame
.nmet:
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
    xor edi, edi
    xor esi, esi
    mov edx, [ui_w]
    mov ecx, [rbp-56]
    mov r8d, UI_SHADOW
    call tut_fill
    xor edi, edi
    mov esi, [rbp-64]
    mov edx, [ui_w]
    mov ecx, [ui_h]
    sub ecx, esi
    mov r8d, UI_SHADOW
    call tut_fill
    xor edi, edi
    mov esi, [rbp-56]
    mov edx, [rbp-52]
    mov ecx, [rbp-64]
    sub ecx, esi
    mov r8d, UI_SHADOW
    call tut_fill
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
    call tut_cur
    mov r15, rax
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
    cmp dword [r15+24], DK_METEOR   ; keep the view clear for the show
    jne .pm
    mov r14d, 44
    jmp .place
.pm:
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
    cmp dword [tut_step], 0
    jne .sk
    lea rcx, [s_tut_no]
.sk:
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .ns
    call tut_end
    jmp .out
.ns:
    ; the status line: what to do, how much is left, or wait
    mov eax, [r15+24]
    cmp eax, DK_NEXT
    je .nb
    lea rdx, [s_tut_do]
    cmp eax, DK_METEOR
    jne .st2
    lea rdx, [s_tut_wait]
    jmp .st
.st2:
    cmp eax, DK_CLEAN
    jne .st
    mov edi, KD_RUBBLE
    call tut_more
    CLAMP eax, 0, MAP_TILES
    push rax
    push rax
    call tb_reset
    pop rdi
    pop rdi
    call tb_num
    lea rdi, [s_tut_left]
    call tb_str
    lea rdx, [textbuf]
.st:
    lea edi, [r12+84]
    mov esi, [rbp-68]
    add esi, 3
    mov ecx, UI_DIM
    call draw_text
    ; no Next while the meteors fall
    cmp dword [r15+24], DK_METEOR
    je .out
.nb:
    lea rcx, [s_tut_next]
    mov eax, [tut_step]
    inc eax
    cmp eax, TUT_COUNT
    jl .nl
    lea rcx, [s_tut_done]
.nl:
    lea edi, [r12+TUT_W-66]
    mov edx, 58
    cmp dword [tut_step], 0
    jne .nw
    lea rcx, [s_tut_take]
    lea edi, [r12+TUT_W-96]
    mov edx, 88
.nw:
    mov esi, [rbp-68]
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
