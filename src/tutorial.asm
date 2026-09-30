; =====================================================================
;  TUTORIAL - a guided first village
;
;  Every new city begins with the offer of a tour (Help also starts it).
;  Once the player takes it, the map and the whole sim state are set
;  aside and the player builds a small village step by step, every step
;  something to do: move the view, draw the street, zone homes / shops /
;  industry, a coal plant away from the homes and a power line to it, a
;  pump on the creek, pipes, a sewage outlet far from the pump, speed up
;  time, read demand, fire / health / school / garbage / park (all on the
;  street), an info view, the inspector and the budget.  Money is
;  topped up, all land is owned and everything is unlocked.  Then meteors
;  fall on the village, the player bulldozes the rubble, and finishing
;  (or skipping) puts the set-aside world and state back: the real city
;  starts fresh.
;
;  The village is planned from the map when the tour begins (a street
;  from the end of the highway to the creek, homes on one side, shops and
;  industry on the other, the coal plant by the creek past the industry
;  with a line across the gap, the pump at the end of the street where the
;  plant powers it, a pipe under the street, the outlet far up the creek
;  with a pipe to it), so doing what the tour shows always gives a village
;  that has all the power and water it needs.  A building step leads
;  the way in three phases: the dock button (the rest dimmed), then the
;  item in its menu, then the place in the world (a path with a start
;  arrow, an area to drag over, or a spot to click), with an instruction
;  line on the card.  Progress is measured against the set-aside world.
;
;  --tourbot FRAMES out.bmp [seed] plays the tour with real mouse and
;  keyboard events, doing only what the highlights show, and prints each
;  step: the test that the tour can be finished by following it.
; =====================================================================

; step kinds
SK_OFFER    equ 0
SK_INFO     equ 1           ; read, then Next
SK_KEYS     equ 2           ; move the view with the keys
SK_RDRAG    equ 3           ; drag the view with the right button
SK_WHEEL    equ 4           ; zoom with the wheel
SK_TOOL     equ 5           ; dock -> menu item -> the world
SK_SPEED    equ 6           ; the fastest speed button
SK_GROW     equ 7           ; wait for residents
SK_DEMAND   equ 8           ; point at the demand bars
SK_METEOR   equ 9
SK_FINAL    equ 10

; world targets
WT_NONE     equ 0
WT_PATH     equ 1           ; drag from the start along a line
WT_RECT     equ 2           ; drag corner to corner
WT_SPOT     equ 3           ; click

; done checks for tool steps
DK_PATHROAD equ 1           ; the path is mostly road
DK_RECTZONE equ 2           ; the area is mostly zoned (arg: class)
DK_SVC      equ 3           ; one more building of a kind (arg)
DK_PYLONS   equ 4           ; two more pylons
DK_PATHPIPE equ 5           ; the path mostly has pipe
DK_OVERLAY  equ 6           ; that info view is on (arg)
DK_INSPECT  equ 7           ; a building is inspected
DK_PANEL    equ 8           ; that panel is open (arg)
DK_CLEAN    equ 9           ; no rubble left from the village

; kinds counted against the set-aside world
KD_ROAD     equ 1
KD_PYLON    equ 2
KD_RUBBLE   equ 3
KD_PIPE     equ 4
KD_ZONE     equ 16          ; + zone class
KD_SVC      equ 32          ; + building kind

; plan slots (tile rects x0, y0, x1, y1)
SL_ROAD     equ 0
SL_R        equ 1
SL_C        equ 2
SL_I        equ 3
SL_COAL     equ 4
SL_PLINE    equ 5
SL_PUMP     equ 6
SL_PIPE     equ 7
SL_SEWER    equ 8
SL_FIRE     equ 9
SL_CLINIC   equ 10
SL_SCHOOL   equ 11
SL_LANDF    equ 12
SL_PARK     equ 13
SL_HOUSE    equ 14
SL_RUBBLE   equ 15
SL_PIPE2    equ 16
SL_COUNT    equ 17
OUTLET_DY   equ 16          ; the outlet this far up the creek from the pump

TUT_W       equ 300
TUT_MONEY   equ 5000000
TUT_LIST    equ 4096
MET_COUNT   equ 3
MET_FALL    equ 40          ; frames a meteor falls
MET_GAP     equ 55          ; frames between meteors

section .data
tut_step    dd -1           ; -1: no tour
section .bss
tut_anim    resd 1
tut_freeze  resd 1          ; test screenshots: no auto-advance
tut_bubble  resd 1          ; 1: the practice village is running
tut_st      resd 1          ; frames in this step
tut_phase   resd 1          ; tool steps: 1 dock, 2 menu item, 3 world
tut_acc     resd 1          ; camera steps: distance moved
tut_lcx     resd 1
tut_lcy     resd 1
tut_zoom0   resd 1
tut_keyseen resd 1
tut_camset  resd 1          ; this step's target was brought into view
tut_met_t   resd 1
tut_met_done resd 1
tut_met_tx  resd MET_COUNT
tut_met_ty  resd MET_COUNT
tut_list_n  resd 1
tut_list    resd TUT_LIST
tut_plan    resd SL_COUNT*4
tut_legr    resd 4          ; one leg of a slot (see tut_leg)
tut_base    resd 1          ; this step's kind, counted when it began
; what is highlighted (ui px), for drawing and for the test player
tut_hl      resd 1          ; 0 none, 1 ui rect, 2 world target
tut_rx      resd 1
tut_ry      resd 1
tut_rw      resd 1
tut_rh      resd 1
tut_wt      resd 1          ; world target type
tut_wax     resd 1          ; world target start / end, window px
tut_way     resd 1
tut_wbx     resd 1
tut_wby     resd 1
tut_nx      resd 1          ; the Next button (ui px)
tut_ny      resd 1
tut_nw      resd 1
tut_mtop    resd 1          ; top of the open menu (ui px)
alignb 16
tut_tiles   resb MAP_TILES*TILE_BYTES       ; the set-aside world
tut_sim     resb sim_state_end - money     ; and sim state

section .data
align 8
; title, text, kind, dock, submenu, item, tool, tool arg, world target,
; plan slot, done check, done arg, pad
%macro TSTEP 12
    dq %1, %2
    dd %3, %4, %5, %6, %7, %8, %9, %10, %11, %12, 0, 0
%endmacro
TSTEP_BYTES equ 64
tut_steps:
    TSTEP tt0,  tx0,  SK_OFFER, 0, -1, 0, -1, -1, WT_NONE, 0, 0, 0
    TSTEP tt1,  tx1,  SK_KEYS,  0, -1, 0, -1, -1, WT_NONE, 0, 0, 0
    TSTEP tt2,  tx2,  SK_RDRAG, 0, -1, 0, -1, -1, WT_NONE, 0, 0, 0
    TSTEP tt3,  tx3,  SK_WHEEL, 0, -1, 0, -1, -1, WT_NONE, 0, 0, 0
    TSTEP tt4,  tx4,  SK_TOOL, 2, 0, 0, T_ROAD, RT_STREET, WT_PATH, SL_ROAD, DK_PATHROAD, 0
    TSTEP tt5,  tx5,  SK_TOOL, 3, 1, 0, T_ZONETOOL, ZONE_R, WT_RECT, SL_R, DK_RECTZONE, ZC_RES
    TSTEP tt6,  tx6,  SK_TOOL, 3, 1, 2, T_ZONETOOL, ZONE_C, WT_RECT, SL_C, DK_RECTZONE, ZC_COM
    TSTEP tt7,  tx7,  SK_TOOL, 3, 1, 4, T_ZONETOOL, ZONE_I, WT_RECT, SL_I, DK_RECTZONE, ZC_IND
    TSTEP tt8,  tx8,  SK_TOOL, 4, 2, 2, T_BUILD, BK_COAL, WT_SPOT, SL_COAL, DK_SVC, BK_COAL
    TSTEP tt9,  tx9,  SK_TOOL, 4, 2, 0, T_POWERLN, -1, WT_PATH, SL_PLINE, DK_PYLONS, 0
    TSTEP tt10, tx10, SK_TOOL, 5, 3, 1, T_BUILD, BK_PUMP, WT_SPOT, SL_PUMP, DK_SVC, BK_PUMP
    TSTEP tt11, tx11, SK_TOOL, 5, 3, 0, T_PIPE, -1, WT_PATH, SL_PIPE, DK_PATHPIPE, 0
    TSTEP tt12, tx12, SK_TOOL, 5, 3, 3, T_BUILD, BK_SEWAGE, WT_SPOT, SL_SEWER, DK_SVC, BK_SEWAGE
    TSTEP tt13, tx13, SK_TOOL, 5, 3, 0, T_PIPE, -1, WT_PATH, SL_PIPE2, DK_PATHPIPE, 0
    TSTEP tt14, tx14, SK_SPEED, 0, -1, 0, -1, -1, WT_NONE, 0, 0, 0
    TSTEP tt15, tx15, SK_GROW,  0, -1, 0, -1, -1, WT_NONE, 0, 0, 0
    TSTEP tt16, tx16, SK_DEMAND, 0, -1, 0, -1, -1, WT_NONE, 0, 0, 0
    TSTEP tt17, tx17, SK_TOOL, 7, 5, 1, T_BUILD, BK_FIRE, WT_SPOT, SL_FIRE, DK_SVC, BK_FIRE
    TSTEP tt18, tx18, SK_TOOL, 8, 6, 0, T_BUILD, BK_CLINIC, WT_SPOT, SL_CLINIC, DK_SVC, BK_CLINIC
    TSTEP tt19, tx19, SK_TOOL, 9, 7, 0, T_BUILD, BK_ELEM, WT_SPOT, SL_SCHOOL, DK_SVC, BK_ELEM
    TSTEP tt20, tx20, SK_TOOL, 6, 4, 0, T_BUILD, BK_LANDFILL, WT_SPOT, SL_LANDF, DK_SVC, BK_LANDFILL
    TSTEP tt21, tx21, SK_TOOL, 11, 9, 0, T_BUILD, BK_PARK, WT_SPOT, SL_PARK, DK_SVC, BK_PARK
    TSTEP tt22, tx22, SK_TOOL, 13, 10, 1, -1, -1, WT_NONE, 0, DK_OVERLAY, OV_POWER
    TSTEP tt23, tx23, SK_TOOL, 0, -1, 0, T_INSPECT, -1, WT_SPOT, SL_HOUSE, DK_INSPECT, 0
    TSTEP tt24, tx24, SK_TOOL, 15, -1, 0, -1, -1, WT_NONE, 0, DK_PANEL, PANEL_BUDGET
    TSTEP tt25, tx25, SK_METEOR, 0, -1, 0, -1, -1, WT_NONE, 0, 0, 0
    TSTEP tt26, tx26, SK_TOOL, 1, -1, 0, T_BULLDOZE, 0, WT_RECT, SL_RUBBLE, DK_CLEAN, 0
    TSTEP tt27, tx27, SK_FINAL, 0, -1, 0, -1, -1, WT_NONE, 0, 0, 0
TUT_COUNT equ ($-tut_steps)/TSTEP_BYTES

tt0  db "Welcome, Mayor! Take the tour?", 0
tx0  db "We'll build a practice village together, with", 10
     db "free money, all the land and everything", 10
     db "unlocked. Then your real city begins.", 0
tt1  db "Moving around", 0
tx1  db "Hold W, A, S or D (or the arrow keys) to", 10
     db "move the view.", 0
tt2  db "Dragging the view", 0
tx2  db "Now hold the right mouse button and drag.", 0
tt3  db "Zooming", 0
tx3  db "Scroll the mouse wheel to zoom in or out.", 0
tt4  db "Your first street", 0
tx4  db "Every city starts with a road. Draw a street", 10
     db "from the end of the highway.", 0
tt5  db "Homes", 0
tx5  db "Zone land for homes along the street. People", 10
     db "build houses on it by themselves.", 0
tt6  db "Shops", 0
tx6  db "People want to shop nearby: zone some", 10
     db "Commercial across the street.", 0
tt7  db "Jobs", 0
tx7  db "They need work too: zone Industry a little", 10
     db "further along the street.", 0
tt8  db "Power plant", 0
tx8  db "Nothing grows without power. Coal plants", 10
     db "make plenty, but their smoke lowers land", 10
     db "value: keep them far from homes. Build one", 10
     db "by the creek, past the industry.", 0
tt9  db "Power lines", 0
tx9  db "Power jumps from building to building (up", 10
     db "to 2 tiles apart, even across a street),", 10
     db "but never along roads. Bridge the gap from", 10
     db "the industry to the plant with a line.", 0
tt10 db "Water pump", 0
tx10 db "Water doesn't pass through buildings like", 10
     db "power: it always comes from a pump. Pumps", 10
     db "need power too: place one on the creek bank", 10
     db "at the end of the street, by the plant.", 0
tt11 db "Pipes", 0
tx11 db "Pipes carry the water to buildings up to 3", 10
     db "tiles away. Lay one under the street, from", 10
     db "the pump to the far end.", 0
tt12 db "Sewage", 0
tx12 db "Used water drains into the creek through a", 10
     db "sewage outlet, which dirties the water", 10
     db "around it. Put it far up the creek, well", 10
     db "away from the pump, so your water stays", 10
     db "clean.", 0
tt13 db "Drains", 0
tx13 db "The same pipes carry the sewage away.", 10
     db "Connect the outlet: a pipe from the street.", 0
tt14 db "Time", 0
tx14 db "Click the fastest speed to let the village", 10
     db "grow. (Space pauses.)", 0
tt15 db "Let it grow", 0
tx15 db "Watch the first homes, shops and factories", 10
     db "go up. Wait for 20 people to move in.", 0
tt16 db "Demand", 0
tx16 db "These bars show what the city wants next:", 10
     db "Residential, Commercial, Industry, Offices.", 0
tt17 db "Safety", 0
tx17 db "Fires spread fast. Build a fire station on", 10
     db "the street: its trucks need a road.", 0
tt18 db "Health", 0
tx18 db "Sick people move away. Build a clinic on", 10
     db "the street.", 0
tt19 db "Schools", 0
tx19 db "Educated people take better jobs and pay", 10
     db "more tax. Build a school on the street.", 0
tt20 db "Garbage", 0
tx20 db "Trash piles up quickly. Build a landfill on", 10
     db "the street (garbage trucks need a road),", 10
     db "far from the homes: it smells.", 0
tt21 db "Parks", 0
tx21 db "Parks make people happier and land worth", 10
     db "more. Place one on the street by the homes.", 0
tt22 db "Info views", 0
tx22 db "Info views show power, water, traffic, land", 10
     db "value and more. Turn on the power view.", 0
tt23 db "Inspect", 0
tx23 db "Check on a building: pick Inspect and click", 10
     db "a home. Icons over buildings mean trouble.", 0
tt24 db "Budget", 0
tx24 db "Taxes pay for everything. Open the budget", 10
     db "to see income and upkeep.", 0
tt25 db "Oh no!", 0
tx25 db "Meteors! Disasters can strike any city.", 0
tt26 db "Clean up", 0
tx26 db "Pick the bulldozer and drag over the rubble", 10
     db "to clear it away.", 0
tt27 db "Your city begins", 0
tx27 db "That was practice. Your real city starts on", 10
     db "your own land with $30,000. Follow the goals", 10
     db "top left for rewards. Good luck, Mayor!", 0

s_tut_next   db "Next", 0
s_tut_take   db "Take the tour", 0
s_tut_no     db "No thanks", 0
s_tut_done   db "Start!", 0
s_tut_skip   db "Skip tour", 0
s_tut_replay db "Take the tour", 0
s_tut_nosave db "Finish or skip the tour to save.", 0
s_tut_begin  db "Your city begins. Good luck, Mayor!", 0
si_dock      db "Click the highlighted button below.", 0
si_item      db "Now pick the highlighted item.", 0
si_path      db "Drag from the arrow along the outline.", 0
si_rect      db "Drag over the outlined area.", 0
si_spot      db "Click the outlined spot.", 0
si_keys      db "Hold a key to move the view...", 0
si_rdrag     db "Hold the right button and move the mouse.", 0
si_wheel     db "Scroll the wheel.", 0
si_speed     db "Click the highlighted speed button.", 0
si_demand    db "Point at the demand bars.", 0
si_wait      db "Hold on...", 0
si_people    db " / 20 people", 0
si_left      db " tiles of rubble left", 0

section .text

%macro PSET 5                       ; slot, x0, y0, x1, y1 (registers ok)
    mov dword [tut_plan+%1*16], %2
    mov dword [tut_plan+%1*16+4], %3
    mov dword [tut_plan+%1*16+8], %4
    mov dword [tut_plan+%1*16+12], %5
%endmacro

; ---------------------------------------------------------------------
;  starting, finishing
; ---------------------------------------------------------------------
; start (or restart) the tour: the offer
FUNC tut_start
    mov dword [tut_step], 0
    mov dword [tut_anim], 0
    mov dword [tut_freeze], 0
    call tut_enter
    RETURN

; a new city begins: offer the tour
tut_maybe_start:
    cmp dword [sandbox], 0
    jne .o
    jmp tut_start
.o: ret

; the offer was taken: set the world aside, plan the village
FUNC tut_begin
    cmp dword [tut_bubble], 0
    jne .o
    lea rsi, [tiles]
    lea rdi, [tut_tiles]
    mov ecx, MAP_TILES*TILE_BYTES/8
    rep movsq
    lea rsi, [money]
    lea rdi, [tut_sim]
    mov ecx, sim_state_end - money
    rep movsb
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
    call tut_plan_make
.o:
    RETURN

; the tour is over (finished or skipped): the real game starts
FUNC tut_end
    mov dword [tut_step], -1
    mov dword [set_tutdone], 1
    call settings_save
    cmp dword [tut_bubble], 0
    je .o
    mov dword [tut_bubble], 0
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

; stop without putting anything back (a city was loaded, or a new one
; started: they replace the world anyway)
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
    mov dword [tut_st], 0
    mov dword [tut_acc], 0
    mov dword [tut_keyseen], 0
    mov dword [tut_camset], 0
    mov dword [tut_phase], 0
    mov eax, [cam_x]
    mov [tut_lcx], eax
    mov eax, [cam_y]
    mov [tut_lcy], eax
    mov eax, [zoom]
    mov [tut_zoom0], eax
%ifndef WEB
    call tut_bot_log
%endif
    call tut_cur
    mov rbx, rax
    mov eax, [rbx+16]
    cmp eax, SK_METEOR
    jne .t
    call tut_meteor_begin
    RETURN
.t:
    ; what's there already: the step counts what gets added to it
    mov dword [tut_base], 0
    cmp dword [rbx+16], SK_TOOL
    jne .spots
    call tut_kind_of
    test edi, edi
    jz .spots
    call tut_more
    mov [tut_base], eax
.spots:
    ; spots are found when their step begins (the land changes); every
    ; building faces the street
    mov eax, [rbx+44]
    cmp eax, SL_COAL
    jne .s0
    mov edi, SL_COAL
    mov esi, [tut_ex]
    sub esi, [tut_hx]
    sub esi, 3                      ; by the creek, past the industry
    mov edx, 1
    mov ecx, 3
    call tut_find_spot
    RETURN
.s0:
    cmp eax, SL_PLINE
    jne .s1
    ; from the industry's east edge to the plant, along its middle row
    mov eax, [tut_plan+SL_I*16+8]
    inc eax
    mov ecx, [tut_plan+SL_COAL*16+4]
    inc ecx
    mov edx, [tut_plan+SL_COAL*16]
    dec edx
    PSET SL_PLINE, eax, ecx, edx, ecx
    RETURN
.s1:
    cmp eax, SL_FIRE
    jne .s2
    mov edi, SL_FIRE
    mov esi, 10
    mov edx, -2
    mov ecx, 2
    call tut_find_spot
    RETURN
.s2:
    cmp eax, SL_CLINIC
    jne .s3
    mov edi, SL_CLINIC
    mov esi, 7                      ; between the shops and the industry
    mov edx, 1
    mov ecx, 1
    call tut_find_spot
    RETURN
.s3:
    cmp eax, SL_SCHOOL
    jne .s4
    mov edi, SL_SCHOOL
    mov esi, 8
    mov edx, 1
    mov ecx, 1
    call tut_find_spot
    RETURN
.s4:
    cmp eax, SL_LANDF
    jne .s5
    mov edi, SL_LANDF
    mov esi, [tut_ex]
    sub esi, [tut_hx]
    sub esi, 3                      ; far from the homes
    mov edx, -2
    mov ecx, 2
    call tut_find_spot
    RETURN
.s5:
    cmp eax, SL_PARK
    jne .s6
    mov edi, SL_PARK
    mov esi, 9                      ; next to the homes
    mov edx, -1
    mov ecx, 1
    call tut_find_spot
    RETURN
.s6:
    cmp eax, SL_HOUSE
    jne .o
    call tut_find_house
.o:
    RETURN

; the kind a tool step counts (rbx step) -> edi, 0 if none
tut_kind_of:
    mov eax, [rbx+48]
    mov ecx, [rbx+52]
    xor edi, edi
    cmp eax, DK_PATHROAD
    jne .a
    mov edi, KD_ROAD
    ret
.a: cmp eax, DK_RECTZONE
    jne .b
    lea edi, [rcx+KD_ZONE]
    ret
.b: cmp eax, DK_SVC
    jne .c
    lea edi, [rcx+KD_SVC]
    ret
.c: cmp eax, DK_PYLONS
    jne .d
    mov edi, KD_PYLON
    ret
.d: cmp eax, DK_PATHPIPE
    jne .e
    mov edi, KD_PIPE
.e: ret

; the current step's record -> rax
tut_cur:
    mov eax, [tut_step]
    imul eax, eax, TSTEP_BYTES
    lea rax, [tut_steps+rax]
    ret

; ---------------------------------------------------------------------
;  the plan
; ---------------------------------------------------------------------

FUNC tut_plan_make, 16
    ; the end of the highway on its row
    xor ebx, ebx
    xor r12d, r12d
.hw:
    mov edi, ebx
    mov esi, [hwy_row]
    call tile_at
    test rax, rax
    jz .hn
    test byte [rax+T_FLAGS], F_HIGHWAY
    jz .hn
    mov r12d, ebx
.hn:
    inc ebx
    cmp ebx, 64
    jl .hw
    mov [tut_hx], r12d
    mov r13d, [hwy_row]             ; row
    ; the street runs to just before the creek
    mov esi, r13d
    call tut_creek_x
    lea r14d, [rax-2]
    cmp eax, -1
    jne .we
    lea r14d, [r12+20]              ; no water
.we:
    lea eax, [r12+24]
    cmp r14d, eax
    jle .e1
    mov r14d, eax
.e1:
    lea eax, [r12+14]
    cmp r14d, eax
    jge .e2
    mov r14d, eax
.e2:
    mov [tut_ex], r14d
    ; hx = r12, row = r13, ex = r14
    lea eax, [r12+1]
    PSET SL_ROAD, eax, r13d, r14d, r13d
    ; homes on the near side, shops across the street, industry further on
    lea eax, [r12+2]
    lea ecx, [r13-3]
    lea edx, [r12+8]
    lea r8d, [r13-1]
    PSET SL_R, eax, ecx, edx, r8d
    lea eax, [r12+2]
    lea ecx, [r13+1]
    lea edx, [r12+6]
    lea r8d, [r13+2]
    PSET SL_C, eax, ecx, edx, r8d
    lea eax, [r12+9]
    lea ecx, [r13+1]
    lea edx, [r12+13]
    lea r8d, [r13+3]
    PSET SL_I, eax, ecx, edx, r8d
    ; the plant by the creek (found again when its step begins), the line
    ; from the industry to it
    lea eax, [r14-3]
    lea ecx, [r13+1]
    lea edx, [r14-1]
    lea r8d, [r13+3]
    PSET SL_COAL, eax, ecx, edx, r8d
    lea eax, [r12+14]
    lea ecx, [r13+2]
    lea edx, [r14-4]
    PSET SL_PLINE, eax, ecx, edx, ecx
    ; the pump at the end of the street, on the bank; the pipe from it
    lea eax, [r14+1]
    PSET SL_PUMP, eax, r13d, eax, r13d
    lea eax, [r12+2]
    PSET SL_PIPE, r14d, r13d, eax, r13d
    ; the outlet far up the creek, on the bank
    lea ebx, [r13-OUTLET_DY]
    mov esi, ebx
    call tut_creek_x
    lea r15d, [rax-1]               ; outlet x
    cmp eax, -1
    jne .ox
    lea r15d, [r14+1]
.ox:
    PSET SL_SEWER, r15d, ebx, r15d, ebx
    ; its pipe: up from the street, in a column clear of the creek all
    ; the way (x - 2 of the creek on every row), then along to the outlet
    mov [rbp-48], r14d              ; column
    mov [rbp-52], ebx               ; row
.col:
    mov esi, [rbp-52]
    call tut_creek_x
    cmp eax, -1
    je .cn
    sub eax, 2
    cmp eax, [rbp-48]
    jge .cn
    mov [rbp-48], eax
.cn:
    inc dword [rbp-52]
    cmp [rbp-52], r13d
    jle .col
    mov eax, [rbp-48]
    lea ecx, [r15-1]
    PSET SL_PIPE2, eax, r13d, ecx, ebx
    RETURN

section .bss
tut_hx resd 1
tut_ex resd 1
section .data
; path slots hold a start and an end, and run as the line tools lay them
; (an L, the longer way first); the others are rectangles
tut_slotpath db 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1
section .text

; the first water on row esi east of the highway's end -> eax, -1 if none
FUNC tut_creek_x
    mov r12d, esi
    mov ebx, [tut_hx]
    add ebx, 8
    lea r13d, [rbx+34]
.l:
    cmp ebx, r13d
    jg .none
    mov edi, ebx
    mov esi, r12d
    call tile_at
    test rax, rax
    jz .none
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .y
    inc ebx
    jmp .l
.y:
    mov eax, ebx
    RETURN
.none:
    mov eax, -1
    RETURN

; leg edx (0 or 1) of plan slot esi as a tile rect -> tut_legr; eax 0 if
; the slot has no such leg
FUNC tut_leg
    mov r15d, edx
    mov eax, esi
    shl eax, 4
    lea rbx, [tut_plan+rax]
    mov r12d, [rbx]                 ; x0
    mov r13d, [rbx+4]               ; y0
    mov r14d, [rbx+8]               ; x1
    mov r8d, [rbx+12]               ; y1
    mov eax, esi
    cmp byte [tut_slotpath+rax], 0
    jne .path
    test r15d, r15d
    jnz .none
    jmp .put
.path:
    mov eax, r14d
    sub eax, r12d
    mov ecx, eax
    sar ecx, 31
    xor eax, ecx
    sub eax, ecx                    ; |dx|
    mov edx, r8d
    sub edx, r13d
    mov ecx, edx
    sar ecx, 31
    xor edx, ecx
    sub edx, ecx                    ; |dy|
    cmp eax, edx
    jl .yfirst
    ; along x on the start row, then along y on the end column
    test r15d, r15d
    jnz .x1
    mov r8d, r13d
    jmp .put
.x1:
    cmp r8d, r13d
    je .none
    mov r12d, r14d
    jmp .put
.yfirst:
    ; along y on the start column, then along x on the end row
    test r15d, r15d
    jnz .y1
    mov r14d, r12d
    jmp .put
.y1:
    cmp r14d, r12d
    je .none
    mov r13d, r8d
.put:
    cmp r12d, r14d
    jle .nx
    xchg r12d, r14d
.nx:
    cmp r13d, r8d
    jle .ny
    xchg r13d, r8d
.ny:
    mov [tut_legr], r12d
    mov [tut_legr+4], r13d
    mov [tut_legr+8], r14d
    mov [tut_legr+12], r8d
    mov eax, 1
    RETURN
.none:
    xor eax, eax
    RETURN

; find a free square of size ecx that faces a street (a road tile beside
; one of its edges), nearest to (hx + esi, row + edx) -> slot edi
FUNC tut_find_spot, 32
    mov [rbp-48], edi               ; slot
    mov eax, [tut_hx]
    add eax, esi
    mov [rbp-52], eax               ; px
    mov eax, [hwy_row]
    add eax, edx
    mov [rbp-56], eax               ; py
    mov [rbp-60], ecx               ; size
    mov dword [rbp-64], 0x7fffffff  ; best distance
    mov eax, [rbp-52]
    mov [rbp-68], eax               ; best x
    mov eax, [rbp-56]
    mov [rbp-72], eax               ; best y
    mov r12d, -9                    ; dy
.dy:
    mov r13d, -9                    ; dx
.dx:
    mov eax, [rbp-52]
    add eax, r13d
    mov [rbp-76], eax
    mov eax, [rbp-56]
    add eax, r12d
    mov [rbp-80], eax
    ; every tile of the square free?
    xor r14d, r14d
.fy:
    cmp r14d, [rbp-60]
    jge .ok
    xor r15d, r15d
.fx:
    cmp r15d, [rbp-60]
    jge .fyn
    mov edi, [rbp-76]
    add edi, r15d
    mov esi, [rbp-80]
    add esi, r14d
    call tile_at
    test rax, rax
    jz .no
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .no
    cmp byte [rax+T_ZONE], 0
    jne .no
    mov cl, [rax+T_OBJ]
    cmp cl, OBJ_NONE
    je .fok
    cmp cl, OBJ_TREE
    jne .no
.fok:
    inc r15d
    jmp .fx
.fyn:
    inc r14d
    jmp .fy
.ok:
    ; a street beside it: a tile just outside one of its edges
    mov r14d, -1                    ; ry
.ay:
    cmp r14d, [rbp-60]
    jg .no
    mov r15d, -1                    ; rx
.ax:
    cmp r15d, [rbp-60]
    jg .ayn
    xor ecx, ecx                    ; how many of rx, ry are outside
    cmp r15d, 0
    jl .o1
    cmp r15d, [rbp-60]
    jl .i1
.o1:
    inc ecx
.i1:
    cmp r14d, 0
    jl .o2
    cmp r14d, [rbp-60]
    jl .i2
.o2:
    inc ecx
.i2:
    cmp ecx, 1
    jne .axn
    mov edi, [rbp-76]
    add edi, r15d
    mov esi, [rbp-80]
    add esi, r14d
    call tile_at
    test rax, rax
    jz .axn
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .axn
    cmp byte [rax+T_ROADTYPE], RT_HIGHWAY
    jne .road
.axn:
    inc r15d
    jmp .ax
.ayn:
    inc r14d
    jmp .ay
.road:
    mov eax, r12d
    imul eax, eax
    mov ecx, r13d
    imul ecx, ecx
    add eax, ecx
    cmp eax, [rbp-64]
    jge .no
    mov [rbp-64], eax
    mov eax, [rbp-76]
    mov [rbp-68], eax
    mov eax, [rbp-80]
    mov [rbp-72], eax
.no:
    inc r13d
    cmp r13d, 9
    jle .dx
    inc r12d
    cmp r12d, 9
    jle .dy
    mov eax, [rbp-48]
    shl eax, 4
    mov ecx, [rbp-68]
    mov [tut_plan+rax], ecx
    add ecx, [rbp-60]
    dec ecx
    mov [tut_plan+rax+8], ecx
    mov ecx, [rbp-72]
    mov [tut_plan+rax+4], ecx
    add ecx, [rbp-60]
    dec ecx
    mov [tut_plan+rax+12], ecx
    RETURN

; a grown home to inspect (else any building of the village)
FUNC tut_find_house
    mov r12d, -1
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .n
    movzx ecx, byte [tiles+rax+T_OBJ]
    cmp ecx, OBJ_SERVICE
    jne .z
    cmp r12d, -1
    jne .n
    mov r12d, ebx
    jmp .n
.z:
    cmp ecx, OBJ_ZONEBLD
    jne .n
    test byte [tiles+rax+T_FLAGS], F_BUILD
    jnz .n
    mov r12d, ebx
    cmp byte [tiles+rax+T_ZONE], ZONE_R
    je .d
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
.d:
    cmp r12d, -1
    je .o
    mov eax, r12d
    and eax, MAP_W-1
    mov ecx, r12d
    shr ecx, MAP_SHIFT
    PSET SL_HOUSE, eax, ecx, eax, ecx
.o:
    RETURN

; the rubble left from the village: its bounding box -> SL_RUBBLE
FUNC tut_rubble_box
    mov r12d, MAP_W                 ; x0
    mov r13d, MAP_W                 ; y0
    mov r14d, -1                    ; x1
    mov r15d, -1                    ; y1
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_RUBBLE
    jne .n
    cmp byte [tut_tiles+rax+T_OBJ], OBJ_RUBBLE
    je .n
    mov eax, ebx
    and eax, MAP_W-1
    mov ecx, ebx
    shr ecx, MAP_SHIFT
    cmp eax, r12d
    cmovl r12d, eax
    cmp eax, r14d
    cmovg r14d, eax
    cmp ecx, r13d
    cmovl r13d, ecx
    cmp ecx, r15d
    cmovg r15d, ecx
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    cmp r14d, 0
    jge .s
    xor r12d, r12d
    xor r13d, r13d
    xor r14d, r14d
    xor r15d, r15d
.s:
    PSET SL_RUBBLE, r12d, r13d, r14d, r15d
    RETURN

; ---------------------------------------------------------------------
;  counting against the set-aside world
; ---------------------------------------------------------------------
; does tile r8 match kind edi? -> ZF clear (eax 1) if so
tut_match:
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
    cmp edi, KD_PIPE
    jne .k5
    test byte [r8+T_FLAGS2], F2_PIPE
    jnz .y
    jmp .n
.k5:
    cmp edi, KD_SVC
    jae .k6
    movzx edx, byte [r8+T_ZONE]
    test edx, edx
    jz .n
    movzx edx, byte [zone_class+rdx]
    lea eax, [rdi-KD_ZONE]
    cmp edx, eax
    je .y
    jmp .n
.k6:
    cmp edx, OBJ_SERVICE
    jne .n
    test byte [r8+T_FLAGS], F_ANCHOR
    jz .n
    movzx edx, byte [r8+T_SUB]
    lea eax, [rdi-KD_SVC]
    cmp edx, eax
    jne .n
.y: mov eax, 1
    ret
.n: xor eax, eax
    ret

; tiles of kind edi in the map at rsi -> eax
tut_count_in:
    push rbx
    push r12
    push r13
    xor r13d, r13d
    xor ebx, ebx
    mov r12, rsi
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea r8, [r12+rax]
    call tut_match
    add r13d, eax
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    mov eax, r13d
    pop r13
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

; tiles of kind edi on plan slot esi (its legs) -> eax matched, edx area
FUNC tut_in_slot, 16
    mov ebx, edi
    mov [rbp-48], esi
    mov dword [rbp-52], 0           ; leg
    xor r14d, r14d                  ; matched
    xor r13d, r13d                  ; area
.leg:
    mov esi, [rbp-48]
    mov edx, [rbp-52]
    call tut_leg
    test eax, eax
    jz .ln
    mov r12d, [tut_legr+4]
.y:
    cmp r12d, [tut_legr+12]
    jg .ln
    mov r15d, [tut_legr]
.x:
    cmp r15d, [tut_legr+8]
    jg .yn
    mov edi, r15d
    mov esi, r12d
    call tile_at
    test rax, rax
    jz .xn
    inc r13d
    mov r8, rax
    mov edi, ebx
    call tut_match
    add r14d, eax
.xn:
    inc r15d
    jmp .x
.yn:
    inc r12d
    jmp .y
.ln:
    inc dword [rbp-52]
    cmp dword [rbp-52], 2
    jl .leg
    mov eax, r14d
    mov edx, r13d
    RETURN

; is at least 70% of plan slot esi of kind edi, or have that many been
; built anywhere in this step? -> eax
FUNC tut_slot_done
    mov r12d, edi
    call tut_in_slot
    ; matched*10 >= area*7
    imul ecx, eax, 10
    imul r8d, edx, 7
    cmp ecx, r8d
    jge .y
    mov r13d, edx
    mov edi, r12d
    call tut_more
    sub eax, [tut_base]
    cmp eax, r13d
    jge .y
    xor eax, eax
    RETURN
.y:
    mov eax, 1
    RETURN

; ---------------------------------------------------------------------
;  has the current step been done? -> eax
; ---------------------------------------------------------------------
FUNC tut_done
    call tut_cur
    mov rbx, rax
    mov eax, [rbx+16]
    cmp eax, SK_KEYS
    je .acc
    cmp eax, SK_RDRAG
    je .acc
    cmp eax, SK_WHEEL
    jne .k1
    mov eax, [zoom]
    cmp eax, [tut_zoom0]
    setne al
    movzx eax, al
    RETURN
.acc:
    xor eax, eax
    cmp dword [tut_acc], 160
    setge al
    RETURN
.k1:
    cmp eax, SK_SPEED
    jne .k2
    xor eax, eax
    cmp dword [sim_speed], 3
    setge al
    RETURN
.k2:
    cmp eax, SK_GROW
    jne .k3
    xor eax, eax
    cmp dword [tut_st], 180         ; a moment to read it, even if they're in
    jl .gn
    cmp dword [population], 20
    setge al
.gn:
    RETURN
.k3:
    cmp eax, SK_DEMAND
    jne .k4
    xor eax, eax
    cmp dword [tut_acc], 45
    setge al
    RETURN
.k4:
    cmp eax, SK_METEOR
    jne .k5
    mov eax, [tut_met_done]
    RETURN
.k5:
    cmp eax, SK_TOOL
    jne .no
    mov eax, [rbx+48]
    mov r12d, [rbx+52]
    cmp eax, DK_PATHROAD
    jne .d2
    mov edi, KD_ROAD
    mov esi, [rbx+44]
    call tut_slot_done
    RETURN
.d2:
    cmp eax, DK_RECTZONE
    jne .d3
    lea edi, [r12+KD_ZONE]
    mov esi, [rbx+44]
    call tut_slot_done
    RETURN
.d3:
    cmp eax, DK_SVC
    jne .d4
    lea edi, [r12+KD_SVC]
    call tut_more
    sub eax, [tut_base]
    cmp eax, 0
    setg al
    movzx eax, al
    RETURN
.d4:
    cmp eax, DK_PYLONS
    jne .d5
    mov edi, KD_PYLON
    call tut_more
    sub eax, [tut_base]
    cmp eax, 2
    setge al
    movzx eax, al
    RETURN
.d5:
    cmp eax, DK_PATHPIPE
    jne .d6
    mov edi, KD_PIPE
    mov esi, [rbx+44]
    call tut_slot_done
    RETURN
.d6:
    cmp eax, DK_OVERLAY
    jne .d7
    xor eax, eax
    cmp [overlay_mode], r12d
    sete al
    RETURN
.d7:
    cmp eax, DK_INSPECT
    jne .d8
    cmp dword [tool], T_INSPECT
    jne .no
    cmp dword [sel_x], 0
    jl .no
    mov edi, [sel_x]
    mov esi, [sel_y]
    call tile_at
    test rax, rax
    jz .no
    mov cl, [rax+T_OBJ]
    cmp cl, OBJ_ZONEBLD
    je .yes
    cmp cl, OBJ_SERVICE
    je .yes
    jmp .no
.d8:
    cmp eax, DK_PANEL
    jne .d9
    xor eax, eax
    cmp [panel], r12d
    sete al
    RETURN
.d9:
    cmp eax, DK_CLEAN
    jne .no
    mov edi, KD_RUBBLE
    call tut_more
    cmp eax, 0
    setle al
    movzx eax, al
    RETURN
.yes:
    mov eax, 1
    RETURN
.no:
    xor eax, eax
    RETURN

; is the tool this step wants selected? -> eax
FUNC tut_tool_ok
    call tut_cur
    mov rbx, rax
    mov eax, [rbx+32]
    cmp eax, -1
    je .no
    cmp [tool], eax
    jne .no
    mov ecx, [rbx+36]
    cmp ecx, -1
    je .yes
    cmp eax, T_ROAD
    jne .z
    cmp [road_type], ecx
    je .yes
    jmp .no
.z:
    cmp eax, T_ZONETOOL
    jne .b
    cmp [zone_type], ecx
    je .yes
    jmp .no
.b:
    cmp eax, T_BUILD
    jne .bz
    cmp [build_kind], ecx
    je .yes
    jmp .no
.bz:
    cmp eax, T_BULLDOZE
    jne .yes
    cmp [bz_filter], ecx
    je .yes
.no:
    xor eax, eax
    RETURN
.yes:
    mov eax, 1
    RETURN

; ---------------------------------------------------------------------
;  per frame: progress on the camera steps, the phase of tool steps
; ---------------------------------------------------------------------
FUNC tut_update
    inc dword [tut_st]
    call tut_cur
    mov rbx, rax
    mov eax, [rbx+16]
    ; camera moved since last frame
    mov ecx, [cam_x]
    sub ecx, [tut_lcx]
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx
    mov r8d, [cam_y]
    sub r8d, [tut_lcy]
    mov edx, r8d
    sar edx, 31
    xor r8d, edx
    sub r8d, edx
    add ecx, r8d                    ; distance this frame
    mov edx, [cam_x]
    mov [tut_lcx], edx
    mov edx, [cam_y]
    mov [tut_lcy], edx
    cmp eax, SK_KEYS
    jne .r
    ; count only while a movement key is held
    push rcx
    push rcx
    xor edi, edi
    CALLC SDL_GetKeyboardState
    pop rcx
    pop rcx
    mov dl, [rax+SC_W]
    or dl, [rax+SC_A]
    or dl, [rax+SC_S]
    or dl, [rax+SC_D]
    or dl, [rax+SC_UP]
    or dl, [rax+SC_DOWN]
    or dl, [rax+SC_LEFT]
    or dl, [rax+SC_RIGHT]
    test dl, dl
    jz .o
    add [tut_acc], ecx
    RETURN
.r:
    cmp eax, SK_RDRAG
    jne .dm
    cmp dword [rmb_down], 0
    je .o
    add [tut_acc], ecx
    RETURN
.dm:
    cmp eax, SK_DEMAND
    jne .t
    ; the pointer on the demand bars
    mov eax, [umx]
    sub eax, 282
    cmp eax, 64
    jae .o
    mov eax, [umy]
    cmp eax, 18
    jae .o
    inc dword [tut_acc]
    RETURN
.t:
    cmp eax, SK_TOOL
    jne .o
    ; phase: 3 when the tool is in hand (or no tool is needed and the
    ; menu isn't the point), 2 when its menu is open, else 1
    cmp dword [rbx+44], SL_RUBBLE
    jne .ph
    call tut_rubble_box
.ph:
    call tut_tool_ok
    test eax, eax
    jnz .p3
    mov eax, [rbx+24]
    cmp eax, -1
    je .p1
    cmp [submenu], eax
    je .p2
.p1:
    mov dword [tut_phase], 1
    RETURN
.p2:
    mov dword [tut_phase], 2
    RETURN
.p3:
    mov dword [tut_phase], 3
.o:
    RETURN

; ---------------------------------------------------------------------
;  the meteor shower
; ---------------------------------------------------------------------
; is tile index edi something the tour built in the village? -> eax
; (the outlet far up the creek, and anything built well away, is spared)
tut_built:
    mov eax, edi
    and eax, MAP_W-1
    mov ecx, [tut_hx]
    cmp eax, ecx
    jl .n
    mov ecx, [tut_ex]
    add ecx, 2
    cmp eax, ecx
    jg .n
    mov eax, edi
    shr eax, MAP_SHIFT
    mov ecx, [hwy_row]
    sub ecx, 4
    cmp eax, ecx
    jl .n
    add ecx, 8
    cmp eax, ecx
    jg .n
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

; list what the tour built, pick the impacts, look at it
FUNC tut_meteor_begin
    mov dword [tut_met_t], 0
    mov dword [tut_met_done], 0
    mov dword [panel], PANEL_NONE
    mov dword [overlay_mode], 0
    mov dword [submenu], -1
    mov dword [tool], T_INSPECT
    mov dword [sel_x], -1
    mov dword [drag_active], 0
    mov dword [tut_list_n], 0
    xor r12d, r12d
    xor r13d, r13d
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
    mov r14d, eax
    mov eax, r13d
    xor edx, edx
    div ecx
    mov r15d, eax
    cmp dword [zoom], 2
    jle .z
    mov edi, 2
    call video_set_zoom
.z:
    mov edi, r14d
    mov esi, r15d
    call camera_center_tile
    ; impacts: the middle, then two more spread over the village
    mov [tut_met_tx], r14d
    mov [tut_met_ty], r15d
    mov ebx, 1
.im:
    mov edi, [tut_list_n]
    call rand_range
    mov eax, [tut_list+rax*4]
    mov ecx, eax
    and ecx, MAP_W-1
    shr eax, MAP_SHIFT
    mov [tut_met_tx+rbx*4], ecx
    mov [tut_met_ty+rbx*4], eax
    inc ebx
    cmp ebx, MET_COUNT
    jl .im
.o:
    RETURN

; one frame of the shower: impacts land, then the rest turns to rubble
FUNC tut_meteor_frame
    cmp dword [tut_met_done], 0
    jne .o
    inc dword [tut_met_t]
    cmp dword [tut_list_n], 0
    je .sweep
    ; an impact when a meteor finishes falling
    xor ebx, ebx
.i:
    imul eax, ebx, MET_GAP
    add eax, MET_FALL
    cmp eax, [tut_met_t]
    jne .in
    mov edi, [tut_met_tx+rbx*4]
    mov esi, [tut_met_ty+rbx*4]
    call meteor_strike
.in:
    inc ebx
    cmp ebx, MET_COUNT
    jl .i
    cmp dword [tut_met_t], (MET_COUNT-1)*MET_GAP+MET_FALL+50
    jl .o
.sweep:
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
    mov eax, [tut_sim+(n_wires-money)]
    mov [n_wires], eax
    lea rsi, [tut_sim+(wire_a-money)]
    lea rdi, [wire_a]
    mov ecx, MAX_WIRES*4
    rep movsb
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
;  drawing helpers (ui layer)
; ---------------------------------------------------------------------
; world tile corner (edi tx, esi ty) + fb offset (edx, ecx) -> ui px
; (eax x, edx y)
tut_w2ui:
    push rbx
    push r12
    mov ebx, edx
    mov r12d, ecx
    call tile_screen
    add eax, ebx
    add edx, r12d
    imul eax, [zoom]
    imul edx, [zoom]
    mov ecx, [ui_scale]
    push rdx
    cdq
    idiv ecx
    mov r8d, eax
    pop rax
    cdq
    idiv ecx
    mov edx, eax
    mov eax, r8d
    pop r12
    pop rbx
    ret

; tile centre (edi, esi) -> window px (eax x, edx y)
tut_w2win:
    call tile_screen
    add edx, 8
    imul eax, [zoom]
    imul edx, [zoom]
    ret

; line (edi x0, esi y0, edx x1, ecx y1, r8d colour), 2 px thick
FUNC ui_line, 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov [rbp-48], r8d
    ; steps = max(|dx|, |dy|)
    mov eax, r14d
    sub eax, r12d
    cdq
    xor eax, edx
    sub eax, edx
    mov ebx, eax
    mov eax, r15d
    sub eax, r13d
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, ebx
    cmovg ebx, eax
    test ebx, ebx
    jnz .go
    inc ebx
.go:
    xor ecx, ecx
.l:
    cmp ecx, ebx
    jg .o
    mov [rbp-52], ecx
    ; x = x0 + (x1-x0)*i/n
    mov eax, r14d
    sub eax, r12d
    imul eax, ecx
    cdq
    idiv ebx
    add eax, r12d
    mov [rbp-56], eax
    mov eax, r15d
    sub eax, r13d
    imul eax, [rbp-52]
    cdq
    idiv ebx
    add eax, r13d
    mov esi, eax
    mov edi, [rbp-56]
    mov edx, [rbp-48]
    push rsi
    push rdi
    call put_pixel
    pop rdi
    pop rsi
    inc esi
    mov edx, [rbp-48]
    call put_pixel
    mov ecx, [rbp-52]
    inc ecx
    jmp .l
.o:
    RETURN

; filled disc (edi cx, esi cy, edx r, ecx colour)
FUNC ui_disc, 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov [rbp-48], ecx
    mov ebx, r14d
    neg ebx                         ; dy
.y:
    cmp ebx, r14d
    jg .o
    ; half width w: largest with w^2 + dy^2 <= r^2
    mov r15d, r14d
.w:
    mov eax, r15d
    imul eax, eax
    mov ecx, ebx
    imul ecx, ecx
    add eax, ecx
    mov ecx, r14d
    imul ecx, ecx
    cmp eax, ecx
    jle .fill
    dec r15d
    jns .w
    jmp .yn
.fill:
    mov edi, r12d
    sub edi, r15d
    lea esi, [r13+rbx]
    lea edx, [r15*2+1]
    mov ecx, 1
    mov r8d, [rbp-48]
    call fill_rect
.yn:
    inc ebx
    jmp .y
.o:
    RETURN

; outline plan slot edi (each of its legs) in colour esi
FUNC tut_outline_slot, 64
    mov [rbp-48], esi
    mov [rbp-84], edi
    mov dword [rbp-88], 0
.leg:
    mov esi, [rbp-84]
    mov edx, [rbp-88]
    call tut_leg
    test eax, eax
    jz .ln
    lea rbx, [tut_legr]
    ; corners: top of (x0,y0), top of (x1+1,y0), top of (x1+1,y1+1),
    ; top of (x0,y1+1)
    mov edi, [rbx]
    mov esi, [rbx+4]
    xor edx, edx
    xor ecx, ecx
    call tut_w2ui
    mov [rbp-52], eax
    mov [rbp-56], edx
    mov edi, [rbx+8]
    inc edi
    mov esi, [rbx+4]
    xor edx, edx
    xor ecx, ecx
    call tut_w2ui
    mov [rbp-60], eax
    mov [rbp-64], edx
    mov edi, [rbx+8]
    inc edi
    mov esi, [rbx+12]
    inc esi
    xor edx, edx
    xor ecx, ecx
    call tut_w2ui
    mov [rbp-68], eax
    mov [rbp-72], edx
    mov edi, [rbx]
    mov esi, [rbx+12]
    inc esi
    xor edx, edx
    xor ecx, ecx
    call tut_w2ui
    mov [rbp-76], eax
    mov [rbp-80], edx
%macro TLINE 4
    mov edi, [rbp-%1]
    mov esi, [rbp-%2]
    mov edx, [rbp-%3]
    mov ecx, [rbp-%4]
    mov r8d, [rbp-48]
    call ui_line
%endmacro
    TLINE 52, 56, 60, 64
    TLINE 60, 64, 68, 72
    TLINE 68, 72, 76, 80
    TLINE 76, 80, 52, 56
.ln:
    inc dword [rbp-88]
    cmp dword [rbp-88], 2
    jl .leg
    RETURN

; a bouncing arrow pointing down at the centre of tile (edi, esi)
FUNC tut_arrow
    mov edx, 0
    mov ecx, 8
    call tut_w2ui
    mov r12d, eax
    mov r13d, edx
    mov eax, [anim_tick]
    shr eax, 3
    and eax, 7
    cmp eax, 4
    jl .b
    mov ecx, 8
    sub ecx, eax
    mov eax, ecx
.b:
    sub r13d, eax
    sub r13d, 4                     ; tip
    ; rows of the triangle, widening upward
    xor ebx, ebx
.r:
    cmp ebx, 9
    jge .stem
    mov edi, r12d
    sub edi, ebx
    mov esi, r13d
    sub esi, ebx
    lea edx, [rbx*2+1]
    mov ecx, 1
    mov r8d, UI_GOLD
    call fill_rect
    inc ebx
    jmp .r
.stem:
    lea edi, [r12-2]
    lea esi, [r13-17]
    mov edx, 5
    mov ecx, 9
    mov r8d, UI_GOLD
    call fill_rect
    RETURN

; the highlight's slow pulse: ZF set on the gold half (0.6 s each, on
; the game's 60 Hz clock, so it's the same on any display)
tut_pulse:
    push rdx
    mov eax, [anim_tick]
    xor edx, edx
    mov ecx, 36
    div ecx
    test eax, 1
    pop rdx
    ret

; darken the world in a rect (edi x, esi y, edx w, ecx h), leaving the
; interface on top of it as it is
tut_fill:
    push rbx
    push r12
    mov eax, edi
    add edx, edi                    ; x1
    add ecx, esi                    ; y1
    CLAMP eax, 0, 100000
    CLAMP esi, 0, 100000
    cmp edx, [ui_w]
    jle .x
    mov edx, [ui_w]
.x:
    cmp ecx, [ui_h]
    jle .y
    mov ecx, [ui_h]
.y:
    mov r8d, esi                    ; row
.r:
    cmp r8d, ecx
    jge .o
    mov r9d, r8d
    imul r9d, [ui_w]
    lea r10, [uifb+r9]
    mov r11d, eax
.c:
    cmp r11d, edx
    jge .rn
    cmp byte [r10+r11], 0
    jne .cn
    mov byte [r10+r11], UI_SHADOW
.cn:
    inc r11d
    jmp .c
.rn:
    inc r8d
    jmp .r
.o:
    pop r12
    pop rbx
    ret

; the ui rect to highlight for this step and phase -> tut_rx..rh, eax
FUNC tut_ui_target, 16
    call tut_cur
    mov rbx, rax
    mov eax, [rbx+16]
    cmp eax, SK_SPEED
    jne .d
    mov edi, [ui_w]
    sub edi, 90-66
    mov esi, 2
    mov edx, 20
    mov ecx, 14
    jmp .have
.d:
    cmp eax, SK_DEMAND
    jne .t
    mov edi, 282
    mov esi, 1
    mov edx, 64
    mov ecx, 16
    jmp .have
.t:
    cmp eax, SK_TOOL
    jne .none
    cmp dword [tut_phase], 1
    je .dock
    cmp dword [tut_phase], 2
    jne .none
    ; the item in the open menu (see draw_submenu: the same list)
    mov eax, [submenu]
    push r15
    call submenu_list
    mov r8, r15
    pop r15
    xor ecx, ecx
.cnt:
    cmp dword [r8+rcx*4], -1
    je .cd
    inc ecx
    jmp .cnt
.cd:
    imul ecx, ecx, 17
    add ecx, 6                      ; menu height
    mov edi, [submenu_x]
    sub edi, 80
    CLAMP edi, 4, 10000
    mov eax, [ui_w]
    sub eax, 204
    cmp edi, eax
    jle .xo
    mov edi, eax
.xo:
    add edi, 3
    mov esi, [ui_h]
    sub esi, DOCK_BTN+12
    sub esi, ecx
    mov [tut_mtop], esi
    imul eax, [rbx+28], 17
    lea esi, [rsi+rax+3]
    mov edx, 194
    mov ecx, 15
    jmp .have
.dock:
    mov eax, DOCK_COUNT
    imul eax, DOCK_BTN+2
    add eax, 8
    mov ecx, [ui_w]
    sub ecx, eax
    shr ecx, 1
    imul eax, [rbx+20], DOCK_BTN+2
    lea edi, [rcx+rax+4]
    mov esi, [ui_h]
    sub esi, DOCK_BTN+8
    add esi, 3
    mov edx, DOCK_BTN
    mov ecx, DOCK_BTN
.have:
    mov [tut_rx], edi
    mov [tut_ry], esi
    mov [tut_rw], edx
    mov [tut_rh], ecx
    mov eax, 1
    RETURN
.none:
    xor eax, eax
    RETURN

; is tile (edi, esi) well inside the view? -> eax
tut_on_screen:
    call tile_screen
    mov ecx, eax
    xor eax, eax
    cmp ecx, 16
    jl .n
    add ecx, 16
    cmp ecx, [fb_w]
    jg .n
    cmp edx, 50
    jl .n
    add edx, 40
    cmp edx, [fb_h]
    jg .n
    inc eax
.n: ret

; bring this step's world target into view once
FUNC tut_frame_target
    cmp dword [tut_camset], 0
    jne .o
    mov dword [tut_camset], 1
    call tut_cur
    mov eax, [rax+44]
    shl eax, 4
    lea rbx, [tut_plan+rax]
    cmp dword [zoom], 2
    jle .z
    mov edi, 2
    call video_set_zoom
    mov dword [tut_camset], 0       ; recheck with the new zoom
.z:
    ; the target's middle, on screen with a margin?
    mov edi, [rbx]
    add edi, [rbx+8]
    shr edi, 1
    mov esi, [rbx+4]
    add esi, [rbx+12]
    shr esi, 1
    mov r12d, edi
    mov r13d, esi
    call tile_screen
    cmp eax, 48
    jl .c
    mov ecx, [fb_w]
    sub ecx, 48
    cmp eax, ecx
    jg .c
    cmp edx, 70
    jl .c
    mov ecx, [fb_h]
    sub ecx, 60
    cmp edx, ecx
    jg .c
    ; and both ends of a long path
    mov edi, [rbx]
    mov esi, [rbx+4]
    call tut_on_screen
    test eax, eax
    jz .c
    mov edi, [rbx+8]
    mov esi, [rbx+12]
    call tut_on_screen
    test eax, eax
    jz .c
    jmp .done
.c:
    mov edi, r12d
    mov esi, r13d
    call camera_center_tile
%ifndef WEB
    cmp dword [bot_on], 0
    je .done
    lea rdi, [bot_cfmt]
    mov esi, r12d
    mov edx, r13d
    mov ecx, [cam_x]
    mov r8d, [cam_y]
    mov r9d, [zoom]
    xor eax, eax
    CALLC printf
%endif
.done:
    mov dword [tut_camset], 1
.o:
    RETURN

; ---------------------------------------------------------------------
;  draw the tour on the ui layer (last, over everything)
; ---------------------------------------------------------------------
FUNC draw_tutorial, 64
    mov dword [tut_hl], 0
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
    call tut_update
    call tut_cur
    cmp dword [rax+16], SK_METEOR
    jne .nmet
    call tut_meteor_frame
.nmet:
    ; a step that's been done moves on by itself
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
    call tut_update
.show:
    call tut_cur
    mov r15, rax
    ; ---- the world target (tool steps in phase 3) ----
    cmp dword [r15+16], SK_TOOL
    jne .uit
    cmp dword [tut_phase], 3
    jne .uit
    cmp dword [r15+40], WT_NONE
    je .uit
    call tut_frame_target
    mov dword [tut_hl], 2
    mov eax, [r15+40]
    mov [tut_wt], eax
    mov r8d, UI_GOLD
    call tut_pulse
    jz .wc
    mov r8d, UI_TEXT
.wc:
    mov edi, [r15+44]
    mov esi, r8d
    call tut_outline_slot
    ; the start (paths) or the spot: an arrow; window px for the player
    mov eax, [r15+44]
    shl eax, 4
    lea rbx, [tut_plan+rax]
    mov edi, [rbx]
    mov esi, [rbx+4]
    cmp dword [r15+40], WT_RECT
    jne .spot
    ; an area: from its left corner to its right one (the top one can be
    ; under the card)
    mov esi, [rbx+12]
    jmp .aim
.spot:
    cmp dword [r15+40], WT_SPOT
    jne .aim
    ; a building goes down centred on the pointer: aim at its middle
    mov eax, [rbx+8]
    sub eax, edi
    sar eax, 1
    add edi, eax
    mov eax, [rbx+12]
    sub eax, esi
    sar eax, 1
    add esi, eax
.aim:
    mov [rbp-76], edi
    mov [rbp-80], esi
    call tut_w2win
    mov [tut_wax], eax
    mov [tut_way], edx
    mov edi, [rbx+8]
    mov esi, [rbx+12]
    cmp dword [r15+40], WT_RECT
    jne .bend
    mov esi, [rbx+4]
.bend:
    call tut_w2win
    mov [tut_wbx], eax
    mov [tut_wby], edx
    ; its top and bottom on screen (ui px), to keep the card off it
    mov edi, [rbx]
    mov eax, [rbx+8]
    cmp edi, eax
    cmovg edi, eax
    mov esi, [rbx+4]
    mov eax, [rbx+12]
    cmp esi, eax
    cmovg esi, eax
    xor edx, edx
    xor ecx, ecx
    call tut_w2ui
    sub edx, 24                     ; room for the arrow
    mov [rbp-84], edx
    mov edi, [rbx]
    mov eax, [rbx+8]
    cmp edi, eax
    cmovl edi, eax
    inc edi
    mov esi, [rbx+4]
    mov eax, [rbx+12]
    cmp esi, eax
    cmovl esi, eax
    inc esi
    xor edx, edx
    xor ecx, ecx
    call tut_w2ui
    mov [rbp-88], edx
    cmp dword [r15+40], WT_RECT
    je .card
    mov edi, [rbp-76]
    mov esi, [rbp-80]
    call tut_arrow
    jmp .card
.uit:
    ; ---- a ui target: dim the rest ----
    call tut_ui_target
    test eax, eax
    jz .card
    mov dword [tut_hl], 1
    mov eax, [tut_rx]
    sub eax, 3
    mov [rbp-52], eax
    mov eax, [tut_ry]
    sub eax, 3
    mov [rbp-56], eax
    mov eax, [tut_rx]
    add eax, [tut_rw]
    add eax, 3
    mov [rbp-60], eax
    mov eax, [tut_ry]
    add eax, [tut_rh]
    add eax, 3
    mov [rbp-64], eax
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
    mov r8d, UI_GOLD
    call tut_pulse
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
    cmp dword [r15+16], SK_METEOR
    jne .nfall
    call tut_draw_meteors
.nfall:
    ; ---- the card ----
    mov rdi, [r15+8]
    call count_lines
    imul eax, eax, 10
    add eax, 62
    mov r13d, eax                   ; height
    mov eax, [ui_w]
    sub eax, TUT_W
    shr eax, 1
    mov r12d, eax                   ; x: centred
    mov r14d, 40                    ; y: top, clear of the world
    cmp dword [r15+16], SK_METEOR   ; meteors fall from the top: go low
    jne .nlow
    mov r14d, [ui_h]
    sub r14d, r13d
    sub r14d, 40
    jmp .place
.nlow:
    cmp dword [tut_hl], 2
    jne .nwt
    ; a world target under the card: the card goes to the bottom, if the
    ; target is clear of it there
    lea eax, [r14+r13+8]
    cmp [rbp-84], eax
    jge .place
    mov eax, [ui_h]
    sub eax, r13d
    sub eax, 40
    mov ecx, [rbp-88]
    add ecx, 8
    cmp ecx, eax
    jg .place
    mov r14d, eax
    jmp .place
.nwt:
    cmp dword [tut_hl], 1
    jne .place
    ; a menu item: beside the menu, so the card hides none of it
    cmp dword [r15+16], SK_TOOL
    jne .nside
    cmp dword [tut_phase], 2
    jne .nside
    mov eax, [tut_rx]
    add eax, [tut_rw]
    add eax, 12
    mov ecx, eax
    add ecx, TUT_W+4
    cmp ecx, [ui_w]
    jle .sx
    mov eax, [tut_rx]
    sub eax, TUT_W+12
    cmp eax, 4
    jge .sx
    ; no room either side: above the menu
    mov eax, [tut_mtop]
    sub eax, r13d
    sub eax, 8
    mov r14d, eax
    mov eax, [tut_rx]
    jmp .px
.sx:
    mov r12d, eax
    mov eax, [tut_rh]
    shr eax, 1
    add eax, [tut_ry]
    mov ecx, r13d
    shr ecx, 1
    sub eax, ecx
    mov r14d, eax
    jmp .place
.nside:
    ; above a highlight at the bottom, under one at the top
    mov eax, [tut_ry]
    cmp eax, 60
    jl .under
    sub eax, r13d
    sub eax, 12
    mov r14d, eax
    mov eax, [tut_rx]
    jmp .px
.under:
    add eax, [tut_rh]
    add eax, 12
    mov r14d, eax
    mov eax, [tut_rx]
.px:
    ; centre the card on the highlight
    mov ecx, [tut_rw]
    shr ecx, 1
    add eax, ecx
    sub eax, TUT_W/2
    mov r12d, eax
.place:
    mov eax, [ui_w]
    sub eax, TUT_W + 4
    CLAMP r12d, 4, eax
    mov eax, [ui_h]
    sub eax, r13d
    sub eax, 34
    CLAMP r14d, 38, eax
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
    ; step counter, title, text
    cmp dword [tut_step], 0
    je .nocount
    call tb_reset
    mov edi, [tut_step]
    call tb_num
    mov edi, '/'
    call tb_char
    mov edi, TUT_COUNT-1
    call tb_num
    lea edi, [r12+TUT_W-8]
    lea esi, [r14+7]
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call draw_text_right
.nocount:
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
    ; ---- the instruction line ----
    lea eax, [r14+r13-34]
    mov [rbp-68], eax
    call tut_instruction            ; -> rdx text, or 0
    test rdx, rdx
    jz .btn
    lea edi, [r12+10]
    mov esi, [rbp-68]
    mov ecx, UI_ACCENT
    call draw_text
.btn:
    ; ---- buttons ----
    lea esi, [r14+r13-19]
    mov [rbp-72], esi
    lea edi, [r12+8]
    mov edx, 72
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
    ; Next (every step: a way on if something doesn't work out), except
    ; while the meteors fall
    cmp dword [r15+16], SK_METEOR
    je .out
    lea rcx, [s_tut_next]
    mov edx, 58
    mov eax, [r15+16]
    cmp eax, SK_OFFER
    jne .n1
    lea rcx, [s_tut_take]
    mov edx, 92
.n1:
    cmp eax, SK_FINAL
    jne .n2
    lea rcx, [s_tut_done]
.n2:
    lea edi, [r12+TUT_W-8]
    sub edi, edx
    mov [tut_nx], edi
    mov eax, [rbp-72]
    mov [tut_ny], eax
    mov [tut_nw], edx
    mov esi, [rbp-72]
    mov r8d, 1
    call text_button
    test eax, eax
    jz .out
    call tut_next
.out:
    RETURN

; the instruction for this step and phase -> rdx (textbuf or a string), 0
FUNC tut_instruction
    call tut_cur
    mov rbx, rax
    xor edx, edx
    mov eax, [rbx+16]
    cmp eax, SK_KEYS
    jne .r
    lea rdx, [si_keys]
    RETURN
.r:
    cmp eax, SK_RDRAG
    jne .w
    lea rdx, [si_rdrag]
    RETURN
.w:
    cmp eax, SK_WHEEL
    jne .s
    lea rdx, [si_wheel]
    RETURN
.s:
    cmp eax, SK_SPEED
    jne .g
    lea rdx, [si_speed]
    RETURN
.g:
    cmp eax, SK_GROW
    jne .dm
    call tb_reset
    movsxd rdi, dword [population]
    call tb_num
    lea rdi, [si_people]
    call tb_str
    lea rdx, [textbuf]
    RETURN
.dm:
    cmp eax, SK_DEMAND
    jne .m
    lea rdx, [si_demand]
    RETURN
.m:
    cmp eax, SK_METEOR
    jne .t
    lea rdx, [si_wait]
    RETURN
.t:
    cmp eax, SK_TOOL
    jne .o
    ; the bulldozer step counts the rubble left in phase 3
    cmp dword [tut_phase], 3
    jne .ph
    cmp dword [rbx+48], DK_CLEAN
    jne .ph
    mov edi, KD_RUBBLE
    call tut_more
    CLAMP eax, 0, MAP_TILES
    mov r12d, eax
    call tb_reset
    movsxd rdi, r12d
    call tb_num
    lea rdi, [si_left]
    call tb_str
    lea rdx, [textbuf]
    RETURN
.ph:
    lea rdx, [si_dock]
    cmp dword [tut_phase], 1
    je .o
    lea rdx, [si_item]
    cmp dword [tut_phase], 2
    je .o
    mov eax, [rbx+40]
    lea rdx, [si_path]
    cmp eax, WT_PATH
    je .o
    lea rdx, [si_rect]
    cmp eax, WT_RECT
    je .o
    lea rdx, [si_spot]
.o:
    RETURN

; the falling meteors: a warning ring on the target, a fireball with
; its trail coming down onto it
FUNC tut_draw_meteors, 32
    xor ebx, ebx
.m:
    cmp ebx, MET_COUNT
    jge .o
    imul eax, ebx, MET_GAP
    mov ecx, [tut_met_t]
    sub ecx, eax                    ; frames into this one's fall
    js .n
    cmp ecx, MET_FALL
    jge .n
    mov [rbp-48], ecx
    mov edi, [tut_met_tx+rbx*4]
    mov esi, [tut_met_ty+rbx*4]
    mov edx, 0
    mov ecx, 8
    call tut_w2ui
    mov r12d, eax                   ; impact x
    mov r13d, edx                   ; impact y
    ; warning ring
    mov edi, r12d
    mov esi, r13d
    mov eax, [rbp-48]
    shr eax, 2
    lea edx, [rax+4]
    mov ecx, RAMP(R_RED, 5)
    call ui_disc
    mov edi, r12d
    mov esi, r13d
    mov eax, [rbp-48]
    shr eax, 2
    lea edx, [rax+2]
    mov ecx, UI_SHADOW
    call ui_disc
    ; the fireball: speeding up as it falls, from up and to the right
    mov eax, [rbp-48]
    imul eax, eax
    mov ecx, [rbp-48]
    add eax, ecx
    imul eax, 128
    mov ecx, MET_FALL*MET_FALL+MET_FALL
    xor edx, edx
    div ecx                         ; 0..128, a gentle ease-in
    mov ecx, [rbp-48]
    shl ecx, 7
    xor edx, edx
    push rax
    mov eax, ecx
    mov ecx, MET_FALL
    div ecx
    pop rcx
    add eax, ecx                    ; 0..256 travelled
    mov r14d, 256
    sub r14d, eax                   ; distance left, 256..0
    ; trail: discs back along the way it came, cooling as they go
    mov r15d, 11
.tr:
    mov eax, r15d
    imul eax, 9
    add eax, r14d
    imul eax, 170
    sar eax, 8
    lea edi, [r12+rax]
    mov eax, r15d
    imul eax, 9
    add eax, r14d
    imul eax, -210
    sar eax, 8
    lea esi, [r13+rax]
    mov edx, 12
    sub edx, r15d
    shr edx, 1
    add edx, 2
    mov ecx, RAMP(R_RED, 3)
    cmp r15d, 8
    jg .tc
    mov ecx, RAMP(R_RED, 5)
.tc:
    cmp r15d, 5
    jg .td
    mov ecx, RAMP(R_ORANGE, 5)
.td:
    cmp r15d, 2
    jg .te
    mov ecx, RAMP(R_YELLOW, 6)
.te:
    call ui_disc
    dec r15d
    jns .tr
    ; the head: a hot core in an orange glow
    mov eax, r14d
    imul eax, 170
    sar eax, 8
    lea edi, [r12+rax]
    mov eax, r14d
    imul eax, -210
    sar eax, 8
    lea esi, [r13+rax]
    mov [rbp-52], edi
    mov [rbp-56], esi
    mov edx, 12
    mov ecx, RAMP(R_ORANGE, 6)
    call ui_disc
    mov edi, [rbp-52]
    mov esi, [rbp-56]
    mov edx, 8
    mov ecx, RAMP(R_YELLOW, 7)
    call ui_disc
    mov edi, [rbp-52]
    mov esi, [rbp-56]
    mov edx, 4
    mov ecx, RAMP(R_WHITE, 7)
    call ui_disc
.n:
    inc ebx
    jmp .m
.o:
    RETURN

; ---------------------------------------------------------------------
;  the test player (--tourbot): follows the highlights with real input
; ---------------------------------------------------------------------
%ifndef WEB
section .bss
bot_on      resd 1
bot_wait    resd 1
bot_t       resd 1
bot_mx      resd 1
bot_my      resd 1
bot_ev      resb 64
bot_lstep   resd 1
bot_lphase  resd 1
bot_shots   resd 1
bot_seen    resd 1
bot_astep   resd 1
section .data
bot_fmt     db "TOUR frame %d step %d: %s  (cam %d,%d)", 10, 0
bot_pfmt    db "PLAN %d: %d,%d - %d,%d", 10, 0
bot_cfmt    db "CENTER %d,%d -> cam %d,%d zoom %d", 10, 0
bot_mfmt    db "meteor_%03d.bmp", 0
bot_efmt    db "TOUR end frame %d: money %d, year %d, population %d, bubble %d", 10, 0
bot_shotfmt db "tour_%02d_%d.bmp", 0
bot_sv1     db "SERVED %d buildings: %d powered, %d water, %d sewage, %d dirty", 10, 0
bot_sv2     db "SERVED %d services: %d powered, %d with a road", 10, 0
bot_sv3     db "SUPPLY power %d/%d, water %d/%d", 10, 0
bot_sv4     db "SUPPLY sewage %d/%d, population %d", 10, 0
bot_shotname times 32 db 0
section .text

; push an event of type edi with (esi x, edx y) at the event's x/y
bot_push:
    push rbx
    lea rbx, [bot_ev]
    push rdi
    push rsi
    push rdx
    mov rdi, rbx
    xor eax, eax
    mov ecx, 64
    rep stosb
    pop rdx
    pop rsi
    pop rdi
    mov [rbx], edi
    mov [rbx+20], esi
    mov [rbx+24], edx
    pop rbx
    ret

; mouse to (edi, esi) window px
bot_move:
    push r12
    push r13
    mov r12d, edi
    mov r13d, esi
    mov edx, esi
    mov esi, edi
    mov edi, SDL_MOUSEMOTION
    call bot_push
    mov eax, r12d
    sub eax, [bot_mx]
    mov [bot_ev+28], eax
    mov eax, r13d
    sub eax, [bot_my]
    mov [bot_ev+32], eax
    mov [bot_mx], r12d
    mov [bot_my], r13d
    cmp dword [rmb_down], 0
    je .nb
    mov byte [bot_ev+16], 4         ; right button held
.nb:
    lea rdi, [bot_ev]
    sub rsp, 8
    CALLC SDL_PushEvent
    add rsp, 8
    pop r13
    pop r12
    ret

; button edi (1 left, 3 right) down (esi 1) or up (esi 0)
bot_button:
    push r12
    push r13
    mov r12d, edi
    mov r13d, esi
    mov edi, SDL_MOUSEBUTTONDOWN
    test r13d, r13d
    jnz .d
    mov edi, SDL_MOUSEBUTTONUP
.d:
    mov esi, [bot_mx]
    mov edx, [bot_my]
    call bot_push
    mov [bot_ev+16], r12b
    mov [bot_ev+17], r13b
    mov byte [bot_ev+18], 1
    lea rdi, [bot_ev]
    sub rsp, 8
    CALLC SDL_PushEvent
    add rsp, 8
    pop r13
    pop r12
    ret

; a ui point (edi, esi ui px) -> window px (eax, edx)
bot_ui2win:
    mov eax, edi
    imul eax, [ui_scale]
    mov edx, esi
    imul edx, [ui_scale]
    ret

; one click at window (edi, esi), spread over frames by bot_t:
; 0 move, 1 down, 2 up; returns eax 1 when finished
FUNC bot_click
    mov r12d, edi
    mov r13d, esi
    mov eax, [bot_t]
    cmp eax, 0
    jne .c1
    mov edi, r12d
    mov esi, r13d
    call bot_move
    jmp .no
.c1:
    cmp eax, 2
    jne .c2
    mov edi, 1
    mov esi, 1
    call bot_button
    jmp .no
.c2:
    cmp eax, 4
    jne .no
    mov edi, 1
    xor esi, esi
    call bot_button
    mov eax, 1
    RETURN
.no:
    xor eax, eax
    RETURN

; a left drag from (edi, esi) to (edx, ecx) window px; eax 1 when done
FUNC bot_drag, 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov eax, [bot_t]
    cmp eax, 0
    jne .d1
    call bot_move
    jmp .no
.d1:
    cmp eax, 2
    jne .d2
    mov edi, 1
    mov esi, 1
    call bot_button
    jmp .no
.d2:
    cmp eax, 24
    jge .d3
    cmp eax, 2
    jl .no
    ; move in 20 steps
    sub eax, 3
    CLAMP eax, 0, 20
    mov ebx, eax
    mov eax, r14d
    sub eax, r12d
    imul eax, ebx
    cdq
    mov ecx, 20
    idiv ecx
    lea edi, [r12+rax]
    mov eax, r15d
    sub eax, r13d
    imul eax, ebx
    cdq
    mov ecx, 20
    idiv ecx
    lea esi, [r13+rax]
    call bot_move
    jmp .no
.d3:
    cmp eax, 26
    jne .no
    mov edi, 1
    xor esi, esi
    call bot_button
    mov eax, 1
    RETURN
.no:
    xor eax, eax
    RETURN

; before events are read each frame
FUNC tut_bot
    cmp dword [bot_on], 0
    je .out
    ; the welcome screen: a click
    cmp dword [welcome], 0
    je .nw
    mov edi, 640
    mov esi, 360
    call bot_click
    inc dword [bot_t]
    test eax, eax
    jz .out
    mov dword [bot_t], 0
    mov dword [bot_wait], 10
    jmp .out
.nw:
    cmp dword [tut_step], 0
    jl .out
    cmp dword [bot_wait], 0
    je .act
    dec dword [bot_wait]
    jmp .out
.act:
    ; the step moved on in the middle of an action: let go of everything
    mov eax, [tut_step]
    cmp dword [bot_t], 0
    je .fresh
    cmp eax, [bot_astep]
    je .go
    cmp dword [rmb_down], 0
    je .nr
    mov edi, 3
    xor esi, esi
    call bot_button
.nr:
    cmp dword [lmb_down], 0
    je .nl
    mov edi, 1
    xor esi, esi
    call bot_button
.nl:
    xor edi, edi
    CALLC SDL_GetKeyboardState
    mov byte [rax+SC_D], 0
    jmp .done
.fresh:
    mov [bot_astep], eax
.go:
    call tut_cur
    mov rbx, rax
    mov eax, [rbx+16]
    cmp eax, SK_OFFER
    je .next
    cmp eax, SK_INFO
    je .next
    cmp eax, SK_FINAL
    je .next
    cmp eax, SK_KEYS
    je .keys
    cmp eax, SK_RDRAG
    je .rdrag
    cmp eax, SK_WHEEL
    je .wheel
    cmp eax, SK_GROW
    je .out
    cmp eax, SK_METEOR
    je .out
    cmp eax, SK_DEMAND
    je .hover
    ; ui targets and world targets
    cmp dword [tut_hl], 1
    je .uiclick
    cmp dword [tut_hl], 2
    je .world
    jmp .out
.next:
    mov edi, [tut_nx]
    add edi, 20
    mov esi, [tut_ny]
    add esi, 7
    call bot_ui2win
    mov edi, eax
    mov esi, edx
    jmp .click
.uiclick:
    mov edi, [tut_rw]
    shr edi, 1
    add edi, [tut_rx]
    mov esi, [tut_rh]
    shr esi, 1
    add esi, [tut_ry]
    call bot_ui2win
    mov edi, eax
    mov esi, edx
.click:
    call bot_click
    inc dword [bot_t]
    test eax, eax
    jz .out
    jmp .done
.hover:
    call tut_ui_target
    mov edi, [tut_rx]
    add edi, 20
    mov esi, [tut_ry]
    add esi, 8
    call bot_ui2win
    mov edi, eax
    mov esi, edx
    call bot_move
    mov dword [bot_wait], 20
    jmp .out
.world:
    cmp dword [tut_wt], WT_SPOT
    jne .wd
    mov edi, [tut_wax]
    mov esi, [tut_way]
    jmp .click
.wd:
    mov edi, [tut_wax]
    mov esi, [tut_way]
    mov edx, [tut_wbx]
    mov ecx, [tut_wby]
    call bot_drag
    inc dword [bot_t]
    test eax, eax
    jz .out
    jmp .done
.keys:
    ; hold D for 40 frames
    xor edi, edi
    CALLC SDL_GetKeyboardState
    mov byte [rax+SC_D], 1
    inc dword [bot_t]
    cmp dword [bot_t], 40
    jl .out
    mov byte [rax+SC_D], 0
    jmp .done
.rdrag:
    mov eax, [bot_t]
    cmp eax, 0
    jne .r1
    mov edi, 640
    mov esi, 400
    call bot_move
    jmp .rn
.r1:
    cmp eax, 2
    jne .r2
    mov edi, 3
    mov esi, 1
    call bot_button
    jmp .rn
.r2:
    cmp eax, 30
    jge .r3
    mov edi, [bot_mx]
    sub edi, 12
    mov esi, [bot_my]
    call bot_move
    jmp .rn
.r3:
    mov edi, 3
    xor esi, esi
    call bot_button
    inc dword [bot_t]
    jmp .done
.rn:
    inc dword [bot_t]
    jmp .out
.wheel:
    mov edi, SDL_MOUSEWHEEL
    mov esi, 0
    mov edx, 0
    call bot_push
    mov dword [bot_ev+20], -1       ; zoom out
    cmp dword [zoom], 1
    jg .wh
    mov dword [bot_ev+20], 1
.wh:
    lea rdi, [bot_ev]
    CALLC SDL_PushEvent
.done:
    mov dword [bot_t], 0
    mov dword [bot_wait], 30
.out:
    RETURN

; a line per step (and the end), for the test log
FUNC tut_bot_log, 16
    cmp dword [bot_on], 0
    je .o
    ; the plan, once
    cmp dword [tut_step], 4
    jne .np
    xor ebx, ebx
.pl:
    lea rdi, [bot_pfmt]
    mov esi, ebx
    mov edx, [tut_plan+rbx*8+0]
    mov ecx, [tut_plan+rbx*8+4]
    mov r8d, [tut_plan+rbx*8+8]
    mov r9d, [tut_plan+rbx*8+12]
    xor eax, eax
    CALLC printf
    add ebx, 2
    cmp ebx, SL_COUNT*2
    jl .pl
.np:
    call tut_cur
    cmp dword [rax+16], SK_METEOR
    jne .ns
    call tut_bot_served
.ns:
    call tut_cur
    lea rdi, [bot_fmt]
    mov esi, [frame_count]
    mov edx, [tut_step]
    mov rcx, [rax]
    mov r8d, [cam_x]
    mov r9d, [cam_y]
    xor eax, eax
    CALLC printf
.o:
    RETURN

; how well the village is served, before the meteors: the test that
; what the tour builds is enough
FUNC tut_bot_served, 48
    xor eax, eax
    mov [rbp-48], eax               ; buildings
    mov [rbp-52], eax               ; powered
    mov [rbp-56], eax               ; water
    mov [rbp-60], eax               ; sewage
    mov [rbp-64], eax               ; dirty
    mov [rbp-68], eax               ; services
    mov [rbp-72], eax               ; powered
    mov [rbp-76], eax               ; with a road
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea r12, [tiles+rax]
    test byte [r12+T_FLAGS], F_ANCHOR
    jz .n
    cmp byte [r12+T_OBJ], OBJ_SERVICE
    je .svc
    cmp byte [r12+T_OBJ], OBJ_ZONEBLD
    jne .n
    test byte [r12+T_FLAGS], F_BUILD
    jnz .n
    inc dword [rbp-48]
    test byte [r12+T_FLAGS], F_POWER
    jz .z1
    inc dword [rbp-52]
.z1:
    test byte [r12+T_FLAGS], F_WATER
    jz .z2
    inc dword [rbp-56]
.z2:
    test byte [r12+T_FLAGS2], F2_SEWAGE
    jz .z3
    inc dword [rbp-60]
.z3:
    test byte [r12+T_FLAGS2], F2_DIRTY
    jz .n
    inc dword [rbp-64]
    jmp .n
.svc:
    inc dword [rbp-68]
    test byte [r12+T_FLAGS], F_POWER
    jz .s1
    inc dword [rbp-72]
.s1:
    mov edi, ebx
    call access_road
    cmp eax, -1
    je .n
    inc dword [rbp-76]
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    lea rdi, [bot_sv1]
    mov esi, [rbp-48]
    mov edx, [rbp-52]
    mov ecx, [rbp-56]
    mov r8d, [rbp-60]
    mov r9d, [rbp-64]
    xor eax, eax
    CALLC printf
    lea rdi, [bot_sv2]
    mov esi, [rbp-68]
    mov edx, [rbp-72]
    mov ecx, [rbp-76]
    xor eax, eax
    CALLC printf
    lea rdi, [bot_sv3]
    mov esi, [power_demand]
    mov edx, [power_supply]
    mov ecx, [water_demand]
    mov r8d, [water_supply]
    xor eax, eax
    CALLC printf
    lea rdi, [bot_sv4]
    mov esi, [sewage_demand]
    mov edx, [sewage_cap]
    mov ecx, [population]
    xor eax, eax
    CALLC printf
    RETURN

; after a frame is shown: screenshots, and stop when the tour is over
FUNC tut_bot_after
    cmp dword [bot_on], 0
    je .o
    cmp dword [tut_step], 0
    jl .end
    mov dword [bot_seen], 1
    ; pictures of the meteors falling
    call tut_cur
    cmp dword [rax+16], SK_METEOR
    jne .nm
    mov eax, [tut_met_t]
    cmp eax, MET_FALL-12
    je .msh
    cmp eax, MET_GAP+MET_FALL-8
    je .msh
    cmp eax, MET_GAP*2+MET_FALL+6
    jne .nm
.msh:
    lea rdi, [bot_shotname]
    lea rsi, [bot_mfmt]
    mov edx, eax
    CALLC sprintf
    lea rdi, [bot_shotname]
    call video_screenshot
    RETURN
.nm:
    ; a picture the first time each step and phase shows up
    mov eax, [tut_step]
    mov ecx, [tut_phase]
    cmp eax, [bot_lstep]
    jne .sh
    cmp ecx, [bot_lphase]
    je .o
.sh:
    cmp dword [bot_t], 0
    jne .o
    mov [bot_lstep], eax
    mov [bot_lphase], ecx
    lea rdi, [bot_shotname]
    lea rsi, [bot_shotfmt]
    mov edx, eax
    CALLC sprintf
    lea rdi, [bot_shotname]
    call video_screenshot
    RETURN
.end:
    cmp dword [bot_seen], 0
    je .o
    cmp dword [bot_shots], 0
    jne .o
    mov dword [bot_shots], 1
    lea rdi, [bot_efmt]
    mov esi, [frame_count]
    mov rdx, [money]
    mov ecx, [year]
    mov r8d, [population]
    mov r9d, [tut_bubble]
    xor eax, eax
    CALLC printf
    ; a few more frames, then the final screenshot and quit
    mov eax, [frame_count]
    add eax, 30
    mov [shot_frames], eax
.o:
    RETURN
%endif
