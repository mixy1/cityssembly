; =====================================================================
;  UI - immediate-mode interface, tools, panels and input
; =====================================================================

T_INSPECT   equ 0
T_BULLDOZE  equ 1
T_ROAD      equ 2
T_POWERLN   equ 3
T_ZONE_R    equ 4
T_ZONE_C    equ 5
T_ZONE_I    equ 6
T_DEZONE    equ 7
T_BUILD     equ 8
T_TREE      equ 9

PANEL_NONE   equ 0
PANEL_BUDGET equ 1
PANEL_MENU   equ 2
PANEL_HELP   equ 3

MAX_TL      equ 1100
NOTIFS      equ 5
DOCK_BTN    equ 22

section .bss
icon_bits       resb ICON_COUNT*256
tool            resd 1
build_kind      resd 1
umx             resd 1
umy             resd 1
lmb_down        resd 1
click_pending   resd 1
release_pending resd 1
ui_captured     resd 1
drag_active     resd 1
drag_sx         resd 1
drag_sy         resd 1
submenu         resd 1          ; -1 none
submenu_x       resd 1
panel           resd 1
sel_x           resd 1
sel_y           resd 1
welcome         resd 1
minimap_on      resd 1
tooltip         resq 1
tl_n            resd 1
tl_cost         resd 1
tl_valid        resd 1          ; count of valid tiles
tl_x            resd MAX_TL
tl_y            resd MAX_TL
tl_ok           resb MAX_TL
path_mark       resb MAP_TILES
notif_text      resb NOTIFS*96
notif_col       resd NOTIFS
notif_tx        resd NOTIFS
notif_ty        resd NOTIFS
notif_time      resd NOTIFS
money_shown     resq 1
last_tool_err   resd 1
minimap_buf     resb 128*64
minimap_age     resd 1
save_name       resb 16

section .data
; toolbar: icon, action (0..9 tool, 100+n submenu, 200 budget, 201 menu, 202 help)
dock_items:
    dd ICON_INSPECT, 0,    ICON_BULLDOZE, 1,  ICON_ROAD, 2,    ICON_POWERLINE, 3
    dd ICON_ZONE_R, 4,     ICON_ZONE_C, 5,    ICON_ZONE_I, 6,  ICON_DEZONE, 7
    dd ICON_TREE, 9,       ICON_POWER, 100,   ICON_WATER, 101, ICON_SAFETY, 102
    dd ICON_HEALTH, 103,   ICON_EDU, 104,     ICON_LEISURE, 105
    dd ICON_OVERLAY, 106,  ICON_BUDGET, 200,  ICON_MENU, 201
DOCK_COUNT equ 18
dock_tips:
    dq tip0, tip1, tip2, tip3, tip4, tip5, tip6, tip7, tip8, tip9
    dq tip10, tip11, tip12, tip13, tip14, tip15, tip16, tip17
tip0  db "Inspect (Q)", 0
tip1  db "Bulldoze (B)", 0
tip2  db "Road (R) - drag. Bridges over water cost more", 0
tip3  db "Power Line (L) - roads & buildings carry power too", 0
tip4  db "Residential Zone (1)", 0
tip5  db "Commercial Zone (2)", 0
tip6  db "Industrial Zone (3)", 0
tip7  db "De-zone empty lots (X)", 0
tip8  db "Plant Trees (T) - cleaner air, higher land value", 0
tip9  db "Power plants", 0
tip10 db "Water", 0
tip11 db "Police & Fire", 0
tip12 db "Health", 0
tip13 db "Education", 0
tip14 db "Parks & Landmarks", 0
tip15 db "Data overlays (O)", 0
tip16 db "Budget & taxes (F2)", 0
tip17 db "Menu (Esc)", 0

submenu_lists:
    dq sm_power, sm_water, sm_safety, sm_health, sm_edu, sm_leisure, sm_overlay
sm_power    dd BK_COAL, BK_WIND, BK_SOLAR, BK_NUCLEAR, -1
sm_water    dd BK_PUMP, BK_WTOWER, -1
sm_safety   dd BK_POLICE, BK_FIRE, -1
sm_health   dd BK_CLINIC, BK_HOSPITAL, -1
sm_edu      dd BK_SCHOOL, BK_UNIV, -1
sm_leisure  dd BK_PARK, BK_PLAZA, BK_STADIUM, BK_CITYHALL, BK_LANDMARK, -1
sm_overlay  dd 1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010, 1011, -1

overlay_names:
    dq ov0, ov1, ov2, ov3, ov4, ov5, ov6, ov7, ov8, ov9, ov10, ov11
ov0  db "No overlay", 0
ov1  db "Power grid", 0
ov2  db "Water supply", 0
ov3  db "Pollution", 0
ov4  db "Crime", 0
ov5  db "Land value", 0
ov6  db "Traffic", 0
ov7  db "Police coverage", 0
ov8  db "Fire coverage", 0
ov9  db "Health coverage", 0
ov10 db "Education", 0
ov11 db "Happiness", 0

tool_names:
    dq tn0, tn1, tn2, tn3, tn4, tn5, tn6, tn7, tn8, tn9
tn0 db "Inspect", 0
tn1 db "Bulldoze", 0
tn2 db "Road", 0
tn3 db "Power line", 0
tn4 db "Residential", 0
tn5 db "Commercial", 0
tn6 db "Industrial", 0
tn7 db "De-zone", 0
tn8 db "Build", 0
tn9 db "Trees", 0

zone_names  dq zn0, zn1, zn2, zn3
zn0 db "Empty land", 0
zn1 db "Residential", 0
zn2 db "Commercial", 0
zn3 db "Industrial", 0
lvl_names   dq lv0, lv1, lv2, lv3, lv4, lv5
lv0 db "Lot", 0
lv1 db "Low density", 0
lv2 db "Medium density", 0
lv3 db "Mid-rise", 0
lv4 db "High-rise", 0
lv5 db "Tower", 0

s_welcome1  db "Welcome, Mayor!", 0
s_welcome2  db "This valley needs a city. Build a road off the highway,", 10
            db "zone homes (1) and industry (3), then power it up.", 10
            db "Roads, zones and buildings all carry power and water.", 10, 10
            db 7, "Drag", 1, " to build.  ", 7, "Right-drag", 1, " / WASD to pan.  ", 7, "Wheel", 1, " to zoom.", 10
            db 7, "Space", 1, " pause   ", 7, "O", 1, " overlays   ", 7, "F1", 1, " help", 10, 10
            db 5, "Click anywhere to begin.", 0
s_help      db "CONTROLS", 10, 10
            db 7, "Left drag", 1, "    build with the current tool", 10
            db 7, "Right drag", 1, "   pan the camera (also WASD / arrows)", 10
            db 7, "Wheel", 1, "        zoom (also - and =)", 10
            db 7, "Q B R L T", 1, "    inspect / bulldoze / road / power / trees", 10
            db 7, "1 2 3 X", 1, "      residential / commercial / industrial / de-zone", 10
            db 7, "Space", 1, "        pause    ", 7, "[ ]", 1, " game speed", 10
            db 7, "O", 1, "            cycle data overlays", 10
            db 7, "Tab", 1, "          minimap   ", 7, "N", 1, " lock daylight   ", 7, "M", 1, " music", 10
            db 7, "F5 / F9", 1, "      save / load     ", 7, "F11", 1, " fullscreen", 10, 10
            db 6, "Tip: buildings upgrade when land value, services,", 10
            db 6, "water and demand allow it. Inspect one to see why.", 0
s_goal      db "GOAL ", 0
s_reward    db "  reward ", 0
s_goaldone  db "Goal complete! +", 0
s_nomoney   db "Not enough money!", 0
s_locked    db "Unlocks at population ", 0
s_needwater db "Water pumps must touch water.", 0
s_budget    db "BUDGET", 0
s_tax       db "Tax rate", 0
s_income    db "Income (last month)", 0
s_res       db "  Residential", 0
s_com       db "  Commercial", 0
s_ind       db "  Industrial", 0
s_expense   db "Expenses", 0
s_roads     db "  Roads", 0
s_services  db "  Services", 0
s_net       db "Net", 0
s_pophist   db "Population", 0
s_cashhist  db "Treasury", 0
s_menu      db "MENU", 0
s_m_resume  db "Resume", 0
s_m_save    db "Save city  (F5)", 0
s_m_load    db "Load city  (F9)", 0
s_m_new     db "New city", 0
s_m_music   db "Music: ", 0
s_m_dis     db "Disasters: ", 0
s_m_day     db "Day/night: ", 0
s_m_full    db "Fullscreen (F11)", 0
s_m_help    db "Help (F1)", 0
s_m_quit    db "Quit", 0
s_on        db "on", 0
s_off       db "off", 0
s_cycle     db "cycle", 0
s_locked_d  db "daylight", 0
s_saved     db "City saved.", 0
s_loaded    db "City loaded.", 0
s_loadfail  db "No saved city found.", 0
s_savefile  db "city.sav", 0
s_paused    db "PAUSED", 0
s_speeds    dq sp0, sp1, sp2, sp3
sp0 db "||", 0
sp1 db ">", 0
sp2 db ">>", 0
sp3 db ">>>", 0
s_pop       db 132, " ", 0
s_happy     db 127, " ", 0
s_bolt      db 128, " ", 0
s_drop      db 129, " ", 0
s_slash     db "/", 0
s_rci       db "R C I", 0
s_cost      db "  cost ", 0
s_tiles     db " tiles", 0
s_residents db "Residents: ", 0
s_jobs      db "Jobs: ", 0
s_power_ok  db 128, " Powered", 0
s_power_no  db 128, " No power!", 0
s_water_ok  db 129, " Water", 0
s_water_no  db 129, " No water", 0
s_road_ok   db "Road access", 0
s_road_no   db "No road nearby!", 0
s_happiness db "Happiness", 0
s_landval   db "Land value", 0
s_pollution db "Pollution", 0
s_crime     db "Crime", 0
s_police    db "Police", 0
s_firecov   db "Fire safety", 0
s_healthc   db "Health", 0
s_educ      db "Education", 0
s_traffic   db "Traffic", 0
s_desire    db "Desirability", 0
s_burning   db "ON FIRE!", 0
s_fightfire db "Send firefighters  $150", 0
s_nofiredep db "Build a fire station first!", 0
s_abandoned db "Abandoned", 0
s_building  db "Under construction", 0
s_needs     db "To grow: ", 0
s_n_road    db "road access", 0
s_n_power   db "power", 0
s_n_hwy     db "a road link to the highway", 0
s_n_water   db "running water", 0
s_n_value   db "land value / demand", 0
s_n_svc     db "police and fire cover", 0
s_n_edu     db "schools and health care", 0
s_n_max     db "fully grown", 0
s_upkeep    db "Upkeep ", 0
s_permonth  db "/mo", 0
s_produces  db "Output ", 0
s_radius    db "Coverage radius ", 0
s_highway   db "Regional highway", 0
s_road      db "Road", 0
s_powerline db "Power line", 0
s_trees     db "Forest", 0
s_water_t   db "Water", 0
s_rubble    db "Rubble", 0
s_grass     db "Grassland", 0
s_bridge    db "Bridge", 0
s_units     db " units", 0

; goals: text, reward
goal_text:
    dq g0, g1, g2, g3, g4, g5, g6, g7, g8, g9, g10, g11, g12, g13, g14
goal_reward dd 500, 300, 800, 1000, 1000, 1500, 2000, 1500, 2000, 3000, 3000, 5000, 20000, 50000, 0
g0  db "Build a road connected to the highway", 0
g1  db "Zone 6 residential lots", 0
g2  db "Build a power plant and light up a home", 0
g3  db "Reach 100 residents", 0
g4  db "Give the town running water", 0
g5  db "Build a police and a fire station", 0
g6  db "Reach 500 residents", 0
g7  db "Build a school", 0
g8  db "Provide 150 shop jobs", 0
g9  db "Reach 1,500 residents at 60% happiness", 0
g10 db "Build a hospital or university", 0
g11 db "Reach 5,000 residents", 0
g12 db "Build the Asm Tower", 0
g13 db "Megalopolis: reach 15,000 residents", 0
g14 db "All goals done - keep building!", 0
GOAL_COUNT equ 14

; icon colour keys
icon_keys   db "kwgdrRyYobBcGhnNpsal"
icon_cols   db UI_BLACK, UI_TEXT, RAMP(R_GREY,5), RAMP(R_GREY,2), RAMP(R_RED,5), RAMP(R_RED,3)
            db RAMP(R_YELLOW,6), RAMP(R_YELLOW,4), RAMP(R_ORANGE,5), RAMP(R_BLUE,5), RAMP(R_BLUE,3)
            db RAMP(R_GLASS,6), RAMP(R_ZONER,5), RAMP(R_ZONER,3), RAMP(R_WOOD,4), RAMP(R_WOOD,2)
            db RAMP(R_PURPLE,5), RAMP(R_SKIN,5), RAMP(R_ASPHALT,3), RAMP(R_GRASS,6)
ICON_KEYS equ 20

%include "icons_data.asm"

section .text

; =====================================================================
FUNC ui_init
    ; decode icons
    xor ebx, ebx
.px:
    cmp ebx, ICON_COUNT*256
    jge .dd
    mov al, [icon_art+rbx]
    xor ecx, ecx
    xor edx, edx                    ; colour (0 = transparent)
.k:
    cmp ecx, ICON_KEYS
    jge .st
    cmp al, [icon_keys+rcx]
    jne .kn
    movzx edx, byte [icon_cols+rcx]
    jmp .st
.kn:
    inc ecx
    jmp .k
.st:
    mov [icon_bits+rbx], dl
    inc ebx
    jmp .px
.dd:
    mov dword [tool], T_INSPECT
    mov dword [submenu], -1
    mov dword [sel_x], -1
    mov dword [welcome], 1
    mov dword [minimap_on], 1
    RETURN

; draw_icon(edi icon, esi x, edx y)
FUNC draw_icon
    mov r12d, esi
    mov r13d, edx
    shl edi, 8
    lea r14, [icon_bits+rdi]
    xor ebx, ebx
.l:
    movzx edx, byte [r14+rbx]
    test edx, edx
    jz .n
    mov edi, ebx
    and edi, 15
    add edi, r12d
    mov esi, ebx
    shr esi, 4
    add esi, r13d
    call put_pixel
.n:
    inc ebx
    cmp ebx, 256
    jl .l
    RETURN

; =====================================================================
;  notifications
; =====================================================================
; notify(rdi text, esi colour, edx tile x, ecx tile y)
FUNC notify
    mov r12, rdi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    ; shift the list down
    mov ebx, NOTIFS-1
.sh:
    test ebx, ebx
    jz .ins
    lea rsi, [notif_text+rbx*8]
    imul eax, ebx, 96
    lea rdi, [notif_text+rax]
    lea rsi, [rdi-96]
    mov ecx, 96
    rep movsb
    mov eax, [notif_col+rbx*4-4]
    mov [notif_col+rbx*4], eax
    mov eax, [notif_tx+rbx*4-4]
    mov [notif_tx+rbx*4], eax
    mov eax, [notif_ty+rbx*4-4]
    mov [notif_ty+rbx*4], eax
    mov eax, [notif_time+rbx*4-4]
    mov [notif_time+rbx*4], eax
    dec ebx
    jmp .sh
.ins:
    lea rdi, [notif_text]
    mov ecx, 95
.cp:
    mov al, [r12]
    mov [rdi], al
    test al, al
    jz .cd
    inc r12
    inc rdi
    dec ecx
    jnz .cp
    mov byte [rdi], 0
.cd:
    mov [notif_col], r13d
    mov [notif_tx], r14d
    mov [notif_ty], r15d
    mov dword [notif_time], 420
    RETURN

FUNC draw_notifications
    xor ebx, ebx
    mov r12d, 22                    ; y
.l:
    cmp ebx, NOTIFS
    jge .out
    mov eax, [notif_time+rbx*4]
    test eax, eax
    jz .n
    dec dword [notif_time+rbx*4]
    imul eax, ebx, 96
    lea r13, [notif_text+rax]
    mov rdi, r13
    call text_width
    lea r14d, [rax+16]              ; width
    ; slide in from the right during the first frames
    mov ecx, [notif_time+rbx*4]
    mov edx, 420
    sub edx, ecx
    CLAMP edx, 0, 20
    mov eax, 20
    sub eax, edx
    imul eax, eax
    shr eax, 2
    mov r15d, [ui_w]
    sub r15d, r14d
    sub r15d, 4
    add r15d, eax                   ; x
    mov edi, r15d
    mov esi, r12d
    mov edx, r14d
    mov ecx, 14
    call draw_panel
    ; colour stripe
    lea edi, [r15+2]
    lea esi, [r12+2]
    mov edx, 2
    mov ecx, 10
    mov r8d, [notif_col+rbx*4]
    call fill_rect
    ; clicking jumps to the location
    mov edi, r15d
    mov esi, r12d
    mov edx, r14d
    mov ecx, 14
    call ui_hit
    test eax, eax
    jz .t
    cmp dword [notif_tx+rbx*4], 0
    jl .t
    mov edi, [notif_tx+rbx*4]
    mov esi, [notif_ty+rbx*4]
    call camera_center_tile
    mov edi, [notif_tx+rbx*4]
    mov [sel_x], edi
    mov edi, [notif_ty+rbx*4]
    mov [sel_y], edi
.t:
    lea edi, [r15+8]
    lea esi, [r12+3]
    mov rdx, r13
    mov ecx, UI_TEXT
    call draw_text
    add r12d, 16
.n:
    inc ebx
    jmp .l
.out:
    RETURN

; =====================================================================
;  widgets
; =====================================================================
; ui_over(edi x, esi y, edx w, ecx h) -> eax 1 if mouse inside (+capture)
ui_over:
    mov eax, [umx]
    sub eax, edi
    jl .n
    cmp eax, edx
    jge .n
    mov eax, [umy]
    sub eax, esi
    jl .n
    cmp eax, ecx
    jge .n
    mov dword [ui_captured], 1
    mov eax, 1
    ret
.n: xor eax, eax
    ret

; ui_hit: over + consume pending click -> eax 1 if clicked
ui_hit:
    call ui_over
    test eax, eax
    jz .n
    cmp dword [click_pending], 0
    je .n
    mov dword [click_pending], 0
    mov eax, 1
    ret
.n: xor eax, eax
    ret

; button(edi x, esi y, edx w, ecx h, r8d selected) -> eax clicked
FUNC button
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov ebx, r8d
    call ui_over
    mov r8d, UI_BTN
    test eax, eax
    jz .nh
    mov r8d, UI_BTN_HI
.nh:
    test ebx, ebx
    jz .ns
    mov r8d, UI_BTN_SEL
.ns:
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, r15d
    call draw_box
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, r15d
    call ui_hit
    test eax, eax
    jz .o
    push rax
    push rax
    mov edi, SFX_CLICK
    call sfx_play
    pop rax
    pop rax
.o:
    RETURN

; text button: (edi x, esi y, edx w, rcx text, r8d selected) -> eax clicked
FUNC text_button
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15, rcx
    mov ecx, 14
    call button
    mov ebx, eax
    mov edi, r14d
    shr edi, 1
    add edi, r12d
    lea esi, [r13+3]
    mov rdx, r15
    mov ecx, UI_TEXT
    call draw_text_centered
    mov eax, ebx
    RETURN

; meter(edi x, esi y, edx w, ecx value 0..255, r8d colour)
FUNC meter
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov ebx, r8d
    mov r8d, UI_BG2
    mov ecx, 5
    call fill_rect
    mov eax, r15d
    CLAMP eax, 0, 255
    imul eax, r14d
    shr eax, 8
    mov edx, eax
    mov edi, r12d
    mov esi, r13d
    mov ecx, 5
    mov r8d, ebx
    call fill_rect
    RETURN

; =====================================================================
;  tools
; =====================================================================
; add a tile to the tool list (edi x, esi y) -> rax index ptr or -1
tl_push:
    mov eax, [tl_n]
    cmp eax, MAX_TL
    jge .f
    mov [tl_x+rax*4], edi
    mov [tl_y+rax*4], esi
    mov byte [tl_ok+rax], 0
    inc dword [tl_n]
    ret
.f: mov eax, -1
    ret

; build list of tiles for the current drag / hover
FUNC tool_collect, 16
    mov dword [tl_n], 0
    mov r12d, [hover_tx]
    mov r13d, [hover_ty]
    cmp dword [drag_active], 0
    je .single
    mov r14d, [drag_sx]
    mov r15d, [drag_sy]
    mov eax, [tool]
    cmp eax, T_ROAD
    je .line
    cmp eax, T_POWERLN
    je .line
    cmp eax, T_INSPECT
    je .single
    cmp eax, T_BUILD
    je .single
    ; rectangle
    mov eax, r14d
    mov ecx, r12d
    cmp eax, ecx
    jle .rx
    xchg eax, ecx
.rx:
    mov [rbp-48], eax               ; x0
    mov [rbp-52], ecx               ; x1
    mov eax, r15d
    mov ecx, r13d
    cmp eax, ecx
    jle .ry
    xchg eax, ecx
.ry:
    mov [rbp-56], eax
    mov [rbp-60], ecx
    mov ebx, [rbp-56]
.ryl:
    cmp ebx, [rbp-60]
    jg .out
    mov r14d, [rbp-48]
.rxl:
    cmp r14d, [rbp-52]
    jg .ryn
    mov edi, r14d
    mov esi, ebx
    call tl_push
    inc r14d
    jmp .rxl
.ryn:
    inc ebx
    jmp .ryl
.line:
    ; L shape: along the longer axis first
    mov eax, r12d
    sub eax, r14d
    mov ecx, eax
    sar ecx, 31
    xor eax, ecx
    sub eax, ecx                    ; |dx|
    mov edx, r13d
    sub edx, r15d
    mov ecx, edx
    sar ecx, 31
    xor edx, ecx
    sub edx, ecx                    ; |dy|
    cmp eax, edx
    jl .yfirst
    ; x from sx to ex at sy, then y from sy to ey at ex
    mov ebx, r14d
.lx:
    mov edi, ebx
    mov esi, r15d
    call tl_push
    cmp ebx, r12d
    je .lx2
    jl .lxi
    dec ebx
    jmp .lx
.lxi:
    inc ebx
    jmp .lx
.lx2:
    mov ebx, r15d
.ly:
    cmp ebx, r13d
    je .out
    jl .lyi
    dec ebx
    jmp .lyp
.lyi:
    inc ebx
.lyp:
    mov edi, r12d
    mov esi, ebx
    call tl_push
    jmp .ly
.yfirst:
    mov ebx, r15d
.ly1:
    mov edi, r14d
    mov esi, ebx
    call tl_push
    cmp ebx, r13d
    je .ly2
    jl .ly1i
    dec ebx
    jmp .ly1
.ly1i:
    inc ebx
    jmp .ly1
.ly2:
    mov ebx, r14d
.lx1:
    cmp ebx, r12d
    je .out
    jl .lx1i
    dec ebx
    jmp .lx1p
.lx1i:
    inc ebx
.lx1p:
    mov edi, ebx
    mov esi, r13d
    call tl_push
    jmp .lx1
.single:
    cmp dword [hover_valid], 0
    je .out
    mov edi, r12d
    mov esi, r13d
    cmp dword [tool], T_BUILD
    jne .sp
    ; centre the footprint on the cursor
    mov edi, [build_kind]
    call bld_rec
    movzx eax, byte [rax+BI_SIZE]
    dec eax
    shr eax, 1
    mov edi, r12d
    sub edi, eax
    mov esi, r13d
    sub esi, eax
.sp:
    call tl_push
.out:
    RETURN

; per-tile validity and cost; fills tl_ok, tl_cost, tl_valid
FUNC tool_evaluate, 32
    mov dword [tl_cost], 0
    mov dword [tl_valid], 0
    mov dword [last_tool_err], 0
    cmp dword [tool], T_BUILD
    je .build
    xor ebx, ebx
.l:
    cmp ebx, [tl_n]
    jge .out
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    call tile_at
    test rax, rax
    jz .n
    mov r12, rax
    xor r13d, r13d                  ; cost (0 = invalid)
    movzx ecx, byte [r12+T_OBJ]
    movzx edx, byte [r12+T_TERRAIN]
    mov eax, [tool]
    cmp eax, T_ROAD
    jne .t1
    cmp ecx, OBJ_ROAD
    je .n
    cmp ecx, OBJ_NONE
    je .rok
    cmp ecx, OBJ_TREE
    je .rok
    cmp ecx, OBJ_RUBBLE
    jne .n
.rok:
    mov r13d, 10
    cmp edx, TER_WATER
    jne .set
    mov r13d, 40
    jmp .set
.t1:
    cmp eax, T_POWERLN
    jne .t2
    cmp ecx, OBJ_NONE
    je .pok
    cmp ecx, OBJ_TREE
    jne .n
.pok:
    mov r13d, 5
    cmp edx, TER_WATER
    jne .set
    mov r13d, 15
    jmp .set
.t2:
    cmp eax, T_ZONE_R
    jb .t3
    cmp eax, T_ZONE_I
    ja .t3
    cmp edx, TER_WATER
    je .n
    cmp ecx, OBJ_NONE
    je .zok
    cmp ecx, OBJ_TREE
    jne .n
.zok:
    sub eax, T_ZONE_R-1
    cmp al, [r12+T_ZONE]
    je .n
    mov r13d, 5
    jmp .set
.t3:
    cmp eax, T_DEZONE
    jne .t4
    cmp byte [r12+T_ZONE], 0
    je .n
    cmp ecx, OBJ_NONE
    jne .n
    mov r13d, 1                     ; free (cost corrected below)
    jmp .set
.t4:
    cmp eax, T_BULLDOZE
    jne .t5
    test byte [r12+T_FLAGS], F_HIGHWAY
    jnz .n
    cmp ecx, OBJ_NONE
    je .n
    mov r13d, 5
    cmp ecx, OBJ_TREE
    jne .b1
    mov r13d, 3
.b1:
    cmp ecx, OBJ_ZONEBLD
    jne .b2
    movzx r13d, byte [r12+T_LEVEL]
    imul r13d, 12
    add r13d, 5
.b2:
    cmp ecx, OBJ_SERVICE
    jne .set
    mov r13d, 40
    jmp .set
.t5:
    cmp eax, T_TREE
    jne .n
    cmp ecx, OBJ_NONE
    jne .n
    cmp edx, TER_WATER
    je .n
    cmp byte [r12+T_ZONE], 0
    jne .n
    mov r13d, 3
.set:
    mov byte [tl_ok+rbx], 1
    inc dword [tl_valid]
    cmp dword [tool], T_DEZONE
    je .n
    add [tl_cost], r13d
.n:
    inc ebx
    jmp .l

.build:
    cmp dword [tl_n], 0
    je .out
    mov edi, [build_kind]
    call bld_rec
    mov r15, rax
    movzx r14d, byte [r15+BI_SIZE]
    mov eax, [r15+BI_COST]
    mov [tl_cost], eax
    ; locked?
    mov eax, [r15+BI_UNLOCK]
    cmp [population], eax
    jge .unl
    mov dword [last_tool_err], 1
    jmp .out
.unl:
    mov r12d, [tl_x]
    mov r13d, [tl_y]
    xor ebx, ebx
    mov dword [rbp-48], 0           ; water touching
.fy:
    xor ecx, ecx
.fx:
    mov [rbp-52], ecx
    lea edi, [r12+rcx]
    lea esi, [r13+rbx]
    call tile_at
    test rax, rax
    jz .out
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .out
    mov cl, [rax+T_OBJ]
    cmp cl, OBJ_NONE
    je .fok
    cmp cl, OBJ_TREE
    je .fok
    cmp cl, OBJ_RUBBLE
    jne .out
.fok:
    mov ecx, [rbp-52]
    lea edi, [r12+rcx]
    lea esi, [r13+rbx]
    call count_water_near
    add [rbp-48], eax
    mov ecx, [rbp-52]
    inc ecx
    cmp ecx, r14d
    jl .fx
    inc ebx
    cmp ebx, r14d
    jl .fy
    cmp dword [build_kind], BK_PUMP
    jne .bok
    cmp dword [rbp-48], 0
    jne .bok
    mov dword [last_tool_err], 2
    jmp .out
.bok:
    mov byte [tl_ok], 1
    mov dword [tl_valid], 1
.out:
    RETURN

; apply the tool to all valid tiles
FUNC tool_apply
    call tool_evaluate
    cmp dword [tl_valid], 0
    je .err
    movsxd rax, dword [tl_cost]
    cmp rax, [money]
    jg .broke
    sub [money], rax
    cmp dword [tool], T_BUILD
    je .build
    xor ebx, ebx
.l:
    cmp ebx, [tl_n]
    jge .done
    cmp byte [tl_ok+rbx], 0
    je .n
    mov r13d, [tl_x+rbx*4]
    mov r14d, [tl_y+rbx*4]
    mov edi, r13d
    mov esi, r14d
    call tile_at
    mov r12, rax
    mov eax, [tool]
    cmp eax, T_ROAD
    jne .a1
    mov byte [r12+T_OBJ], OBJ_ROAD
    mov byte [r12+T_ZONE], 0
    mov byte [r12+T_FLAGS], 0
    mov byte [r12+T_LEVEL], 0
    mov word [r12+T_POP], 0
    jmp .upd
.a1:
    cmp eax, T_POWERLN
    jne .a2
    mov byte [r12+T_OBJ], OBJ_POWER
    mov byte [r12+T_ZONE], 0
    mov byte [r12+T_FLAGS], 0
    jmp .upd
.a2:
    cmp eax, T_ZONE_R
    jb .a3
    cmp eax, T_ZONE_I
    ja .a3
    sub eax, T_ZONE_R-1
    mov [r12+T_ZONE], al
    mov byte [r12+T_OBJ], OBJ_NONE
    mov byte [r12+T_LEVEL], 0
    mov byte [r12+T_HAPPY], 0
    jmp .upd
.a3:
    cmp eax, T_DEZONE
    jne .a4
    mov byte [r12+T_ZONE], 0
    jmp .upd
.a4:
    cmp eax, T_BULLDOZE
    jne .a5
    cmp byte [r12+T_OBJ], OBJ_SERVICE
    jne .bz
    mov edi, r13d
    mov esi, r14d
    call destroy_to_rubble
    ; then clear the rubble we just made (bulldozing is clean)
    jmp .upd
.bz:
    mov byte [r12+T_OBJ], OBJ_NONE
    mov byte [r12+T_FLAGS], 0
    mov byte [r12+T_LEVEL], 0
    mov word [r12+T_POP], 0
    jmp .upd
.a5:
    cmp eax, T_TREE
    jne .upd
    mov byte [r12+T_OBJ], OBJ_TREE
    call rand
    and eax, 3
    mov [r12+T_SUB], al
    call rand
    mov [r12+T_VARIANT], al
.upd:
    mov edi, r13d
    mov esi, r14d
    call roads_update_around
    ; dust
    mov edi, r13d
    mov esi, r14d
    mov edx, 2
    mov ecx, PK_DUST
    mov r8d, 1
    call fx_burst
.n:
    inc ebx
    jmp .l
.done:
    ; rubble left by bulldozed services is cleared too
    cmp dword [tool], T_BULLDOZE
    jne .snd
    xor ebx, ebx
.cl:
    cmp ebx, [tl_n]
    jge .snd
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    call tile_at
    test rax, rax
    jz .cln
    cmp byte [rax+T_OBJ], OBJ_RUBBLE
    jne .cln
    mov byte [rax+T_OBJ], OBJ_NONE
.cln:
    inc ebx
    jmp .cl
.snd:
    mov dword [net_dirty], 1
    mov dword [cov_dirty], 1
    mov eax, [tool]
    mov edi, SFX_ROAD
    cmp eax, T_ROAD
    je .play
    cmp eax, T_POWERLN
    je .play
    mov edi, SFX_BULLDOZE
    cmp eax, T_BULLDOZE
    je .play
    mov edi, SFX_ZONE
.play:
    call sfx_play
    call cost_float
    RETURN

.build:
    mov edi, [build_kind]
    call bld_rec
    movzx r14d, byte [rax+BI_SIZE]
    mov r12d, [tl_x]
    mov r13d, [tl_y]
    xor ebx, ebx
.by:
    xor r15d, r15d
.bx:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call tile_at
    mov byte [rax+T_OBJ], OBJ_SERVICE
    mov ecx, [build_kind]
    mov [rax+T_SUB], cl
    mov byte [rax+T_ZONE], 0
    mov byte [rax+T_FLAGS], 0
    mov byte [rax+T_TIMER], 0
    mov word [rax+T_POP], 0
    mov ecx, ebx
    shl ecx, 4
    or ecx, r15d
    mov [rax+T_ANCHOR], cl
    test ecx, ecx
    jnz .nanc
    mov byte [rax+T_FLAGS], F_ANCHOR
.nanc:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    mov edx, 3
    mov ecx, PK_DUST
    mov r8d, 2
    call fx_burst
    inc r15d
    cmp r15d, r14d
    jl .bx
    inc ebx
    cmp ebx, r14d
    jl .by
    ; refresh neighbouring power-line masks
    mov ebx, -1
.rm:
    mov r15d, -1
.rmx:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call roads_update_around
    add r15d, 2
    cmp r15d, r14d
    jle .rmx
    add ebx, 2
    cmp ebx, r14d
    jle .rm
    mov dword [net_dirty], 1
    call coverage_update
    mov edi, SFX_PLACE
    call sfx_play
    call cost_float
    RETURN

.broke:
    lea rdi, [s_nomoney]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
.err:
    cmp dword [last_tool_err], 1
    jne .e2
    call tb_reset
    lea rdi, [s_locked]
    call tb_str
    mov edi, [build_kind]
    call bld_rec
    movsxd rdi, dword [rax+BI_UNLOCK]
    call tb_num
    lea rdi, [textbuf]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
.e2:
    cmp dword [last_tool_err], 2
    jne .e3
    lea rdi, [s_needwater]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
.e3:
    mov edi, SFX_ERROR
    call sfx_play
    RETURN

; floating "-$cost" at the last tile
FUNC cost_float
    mov eax, [tl_cost]
    test eax, eax
    jz .out
    call tb_reset
    mov edi, '-'
    call tb_char
    movsxd rdi, dword [tl_cost]
    call tb_money
    mov eax, [tl_n]
    dec eax
    mov edi, [tl_x+rax*4]
    mov esi, [tl_y+rax*4]
    lea rdx, [textbuf]
    mov ecx, UI_BAD
    call float_text
.out:
    RETURN

; ---------------------------------------------------------------------
;  world-side preview of the current tool (drawn into the world fb)
; ---------------------------------------------------------------------
FUNC draw_tool_preview, 16
    call set_target_world
    cmp dword [ui_captured], 0
    jne .out
    cmp dword [welcome], 0
    jne .out
    cmp dword [tool], T_INSPECT
    jne .tools
    ; inspect: hover outline + selection
    cmp dword [hover_valid], 0
    je .sel
    mov edi, [hover_tx]
    mov esi, [hover_ty]
    mov edx, 1
    mov ecx, RAMP(R_WHITE, 7)
    call draw_diamond
    jmp .sel
.tools:
    call tool_collect
    call tool_evaluate
    cmp dword [tool], T_BUILD
    je .bprev
    xor ebx, ebx
.l:
    cmp ebx, [tl_n]
    jge .sel
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    mov r12d, edi
    mov r13d, esi
    call tile_at
    test rax, rax
    jz .n
    mov ecx, RAMP(R_RED, 6)
    cmp byte [tl_ok+rbx], 0
    je .dia
    ; ghost of the result for roads / zones
    mov eax, [tool]
    cmp eax, T_ROAD
    jne .gz
    mov edi, r12d
    mov esi, r13d
    call preview_road_mask
    mov edi, [spr_road+rax*4]
    jmp .ghost
.gz:
    cmp eax, T_ZONE_R
    jb .gd
    cmp eax, T_ZONE_I
    ja .gd
    sub eax, T_ZONE_R-1
    mov edi, [spr_lot+rax*4]
    jmp .ghost
.gd:
    mov ecx, RAMP(R_ZONER, 7)
    cmp dword [tool], T_BULLDOZE
    jne .dia
    mov ecx, RAMP(R_ORANGE, 6)
    jmp .dia
.ghost:
    mov [rbp-48], edi
    mov edi, r12d
    mov esi, r13d
    call tile_screen
    mov esi, eax
    mov edi, [rbp-48]
    mov ecx, 60000
    lea r8, [remap_bright]
    call blit_sprite
    mov ecx, RAMP(R_ZONER, 7)
.dia:
    mov edi, r12d
    mov esi, r13d
    mov edx, 1
    call draw_diamond
.n:
    inc ebx
    jmp .l
.bprev:
    cmp dword [tl_n], 0
    je .sel
    mov edi, [build_kind]
    call bld_rec
    movzx r14d, byte [rax+BI_SIZE]
    mov edi, [tl_x]
    mov esi, [tl_y]
    call tile_screen
    mov esi, eax
    mov eax, [build_kind]
    mov edi, [spr_bld+rax*4]
    mov ecx, 60000
    lea r8, [remap_green]
    cmp byte [tl_ok], 0
    jne .bp
    lea r8, [remap_red]
.bp:
    call blit_sprite
    ; coverage radius ring for services
    mov edi, [build_kind]
    call bld_rec
    movzx r15d, byte [rax+BI_RADIUS]
    test r15d, r15d
    jz .bd
    mov eax, r14d
    shr eax, 1
    mov edi, [tl_x]
    add edi, eax
    sub edi, r15d
    mov esi, [tl_y]
    add esi, eax
    sub esi, r15d
    lea edx, [r15*2+1]
    mov ecx, RAMP(R_GLASS, 7)
    call draw_diamond
.bd:
    mov edi, [tl_x]
    mov esi, [tl_y]
    mov edx, r14d
    mov ecx, RAMP(R_ZONER, 7)
    cmp byte [tl_ok], 0
    jne .bdd
    mov ecx, RAMP(R_RED, 6)
.bdd:
    call draw_diamond
.sel:
    cmp dword [sel_x], 0
    jl .out
    mov edi, [sel_x]
    mov esi, [sel_y]
    call tile_at
    test rax, rax
    jz .out
    mov edx, 1
    cmp byte [rax+T_OBJ], OBJ_SERVICE
    jne .sd
    movzx edi, byte [rax+T_SUB]
    call bld_rec
    movzx edx, byte [rax+BI_SIZE]
.sd:
    mov edi, [sel_x]
    mov esi, [sel_y]
    mov ecx, RAMP(R_YELLOW, 7)
    call draw_diamond
.out:
    RETURN

; road mask for previews: existing roads + other path tiles
FUNC preview_road_mask
    mov r12d, edi
    mov r13d, esi
    xor ebx, ebx
    xor r14d, r14d
.d:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+r14*4]
    add esi, [dir_dy+r14*4]
    mov r15d, edi
    push rsi
    push rsi
    call is_road
    pop rsi
    pop rsi
    test eax, eax
    jnz .y
    ; in path?
    xor ecx, ecx
.p:
    cmp ecx, [tl_n]
    jge .n
    cmp [tl_x+rcx*4], r15d
    jne .pn
    cmp [tl_y+rcx*4], esi
    je .y
.pn:
    inc ecx
    jmp .p
.y:
    bts ebx, r14d
.n:
    inc r14d
    cmp r14d, 4
    jl .d
    mov eax, ebx
    RETURN

; =====================================================================
;  world mouse handling (after the ui had its chance)
; =====================================================================
FUNC world_input
    cmp dword [welcome], 0
    je .play
    cmp dword [click_pending], 0
    je .out
    mov dword [click_pending], 0
    mov dword [welcome], 0
    mov edi, SFX_CHIME
    call sfx_play
    jmp .out
.play:
    cmp dword [click_pending], 0
    je .held
    mov dword [click_pending], 0
    cmp dword [ui_captured], 0
    jne .out
    cmp dword [hover_valid], 0
    je .out
    ; any click in the world closes menus
    mov dword [submenu], -1
    mov eax, [tool]
    cmp eax, T_INSPECT
    je .inspect
    cmp eax, T_BUILD
    je .buildclick
    mov eax, [hover_tx]
    mov [drag_sx], eax
    mov eax, [hover_ty]
    mov [drag_sy], eax
    mov dword [drag_active], 1
    jmp .out
.inspect:
    mov eax, [hover_tx]
    mov [sel_x], eax
    mov eax, [hover_ty]
    mov [sel_y], eax
    ; select the anchor of multi-tile buildings
    mov edi, [sel_x]
    mov esi, [sel_y]
    call tile_at
    cmp byte [rax+T_OBJ], OBJ_SERVICE
    jne .isnd
    movzx ecx, byte [rax+T_ANCHOR]
    mov edx, ecx
    and ecx, 15
    shr edx, 4
    sub [sel_x], ecx
    sub [sel_y], edx
.isnd:
    mov edi, SFX_CLICK
    call sfx_play
    jmp .out
.buildclick:
    call tool_collect
    call tool_apply
    jmp .out
.held:
    cmp dword [release_pending], 0
    je .out
    mov dword [release_pending], 0
    cmp dword [drag_active], 0
    je .out
    call tool_collect
    call tool_apply
    mov dword [drag_active], 0
.out:
    mov dword [release_pending], 0
    RETURN

; =====================================================================
;  HUD pieces
; =====================================================================
FUNC draw_topbar, 16
    xor edi, edi
    xor esi, esi
    mov edx, [ui_w]
    mov ecx, 18
    call draw_panel
    ; milestone + date
    call tb_reset
    mov eax, [milestone]
    mov rdi, [milestone_names+rax*8]
    call tb_str
    mov edi, 6
    mov esi, 5
    mov ecx, UI_GOLD
    call tb_draw
    lea r12d, [rax+8]
    call tb_reset
    call tb_date
    mov edi, r12d
    mov esi, 5
    mov ecx, UI_DIM
    call tb_draw
    ; money (counts toward the real value)
    mov rax, [money]
    sub rax, [money_shown]
    mov rcx, rax
    sar rcx, 3
    test rcx, rcx
    jnz .ms
    mov rcx, rax
.ms:
    add [money_shown], rcx
    call tb_reset
    mov rdi, [money_shown]
    call tb_money
    mov edi, 150
    mov esi, 5
    mov ecx, UI_GOLD
    cmp qword [money], 0
    jge .mc
    mov ecx, UI_BAD
.mc:
    call tb_draw
    ; month delta popup
    cmp dword [cash_delta_timer], 0
    je .nd
    dec dword [cash_delta_timer]
    call tb_reset
    mov eax, [cash_delta]
    test eax, eax
    js .neg
    mov edi, '+'
    call tb_char
.neg:
    movsxd rdi, dword [cash_delta]
    call tb_money
    mov edi, 150
    mov esi, 20
    mov ecx, UI_GOOD
    cmp dword [cash_delta], 0
    jge .dc
    mov ecx, UI_BAD
.dc:
    call tb_draw
.nd:
    ; population
    call tb_reset
    lea rdi, [s_pop]
    call tb_str
    movsxd rdi, dword [population]
    call tb_num
    mov edi, 230
    mov esi, 5
    mov ecx, UI_TEXT
    call tb_draw
    ; RCI demand bars
    mov r12d, 300
    lea rdi, [s_rci]
    mov edi, r12d
    mov esi, 5
    lea rdx, [s_rci]
    mov ecx, UI_DIM
    call draw_text
    xor ebx, ebx
.rci:
    mov eax, [demand_r+rbx*4]
    mov r13d, eax
    lea edi, [rbx*4+rbx]
    add edi, r12d
    add edi, 30
    ; baseline
    mov esi, 9
    mov edx, 4
    mov ecx, 1
    mov r8d, UI_DIM
    call fill_rect
    mov eax, r13d
    CLAMP eax, -100, 100
    cdq
    mov ecx, 14
    idiv ecx                        ; -7..7
    lea edi, [rbx*4+rbx]
    add edi, r12d
    add edi, 30
    movzx r8d, byte [rci_cols+rbx]
    test eax, eax
    js .down
    mov ecx, eax
    mov esi, 9
    sub esi, eax
    mov edx, 4
    call fill_rect
    jmp .rn
.down:
    neg eax
    mov ecx, eax
    mov esi, 10
    mov edx, 4
    mov r8d, UI_BAD
    call fill_rect
.rn:
    inc ebx
    cmp ebx, 3
    jl .rci
    ; happiness
    call tb_reset
    lea rdi, [s_happy]
    call tb_str
    movsxd rdi, dword [happy_avg]
    call tb_pct
    mov edi, 356
    mov esi, 5
    mov ecx, UI_GOOD
    cmp dword [happy_avg], 50
    jge .hc
    mov ecx, UI_WARN
    cmp dword [happy_avg], 35
    jge .hc
    mov ecx, UI_BAD
.hc:
    call tb_draw
    ; power
    call tb_reset
    lea rdi, [s_bolt]
    call tb_str
    movsxd rdi, dword [power_demand]
    call tb_num
    lea rdi, [s_slash]
    call tb_str
    movsxd rdi, dword [power_supply]
    call tb_num
    mov edi, 400
    mov esi, 5
    mov ecx, UI_GOOD
    mov eax, [power_demand]
    cmp eax, [power_supply]
    jle .pc
    mov ecx, UI_BAD
.pc:
    call tb_draw
    lea r12d, [rax+8]
    call tb_reset
    lea rdi, [s_drop]
    call tb_str
    movsxd rdi, dword [water_demand]
    call tb_num
    lea rdi, [s_slash]
    call tb_str
    movsxd rdi, dword [water_supply]
    call tb_num
    mov edi, r12d
    mov esi, 5
    mov ecx, UI_ACCENT
    mov eax, [water_demand]
    cmp eax, [water_supply]
    jle .wc
    mov ecx, UI_BAD
.wc:
    call tb_draw
    ; speed buttons
    xor ebx, ebx
.sp:
    mov edi, [ui_w]
    sub edi, 90
    imul eax, ebx, 22
    add edi, eax
    mov esi, 2
    mov edx, 20
    mov ecx, 14
    xor r8d, r8d
    cmp ebx, [sim_speed]
    sete r8b
    call button
    test eax, eax
    jz .spn
    mov [sim_speed], ebx
.spn:
    mov edi, [ui_w]
    sub edi, 80
    imul eax, ebx, 22
    add edi, eax
    mov esi, 5
    mov rdx, [s_speeds+rbx*8]
    mov ecx, UI_TEXT
    call draw_text_centered
    inc ebx
    cmp ebx, 4
    jl .sp
    ; paused banner
    cmp dword [sim_speed], 0
    jne .out
    mov eax, [anim_tick]
    and eax, 32
    jz .out
    mov edi, [ui_w]
    shr edi, 1
    mov esi, 24
    lea rdx, [s_paused]
    mov ecx, UI_WARN
    call draw_text_centered
.out:
    RETURN
section .data
rci_cols db UI_GOOD, UI_ACCENT, UI_WARN
section .text

FUNC draw_goal
    mov eax, [goal_index]
    cmp eax, GOAL_COUNT
    jg .out
    mov rdi, [goal_text+rax*8]
    mov r12, rdi
    call text_width
    lea r13d, [rax+40]
    call tb_reset
    lea rdi, [s_reward]
    call tb_str
    mov eax, [goal_index]
    movsxd rdi, dword [goal_reward+rax*4]
    test rdi, rdi
    jz .nr
    call tb_money
.nr:
    lea rdi, [textbuf]
    call text_width
    add r13d, eax
    mov edi, 4
    mov esi, 21
    mov edx, r13d
    mov ecx, 14
    call draw_panel
    mov edi, 8
    mov esi, 24
    lea rdx, [s_goal]
    mov ecx, UI_ACCENT
    call draw_text
    mov edi, eax
    add edi, 2
    mov esi, 24
    mov rdx, r12
    mov ecx, UI_TEXT
    call draw_text
    mov edi, eax
    mov esi, 24
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text
.out:
    RETURN

; ---------------------------------------------------------------------
FUNC draw_dock, 32
    mov eax, DOCK_COUNT
    imul eax, DOCK_BTN+2
    add eax, 8
    mov r14d, eax                   ; width
    mov r12d, [ui_w]
    sub r12d, eax
    shr r12d, 1                     ; x0
    mov r13d, [ui_h]
    sub r13d, DOCK_BTN+8            ; y0
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, DOCK_BTN+6
    call draw_panel
    xor ebx, ebx
.b:
    cmp ebx, DOCK_COUNT
    jge .tip
    imul eax, ebx, DOCK_BTN+2
    lea r15d, [r12+rax+4]           ; x
    mov [rbp-48], r15d
    ; selected?
    mov eax, [dock_items+rbx*8+4]
    xor r8d, r8d
    cmp eax, 10
    jge .sm
    cmp eax, [tool]
    sete r8b
    jmp .sb
.sm:
    cmp eax, 200
    jge .pn
    sub eax, 100
    cmp eax, [submenu]
    sete r8b
    ; build tool from this group active?
    jmp .sb
.pn:
    mov ecx, [panel]
    add ecx, 199
    cmp eax, ecx
    sete r8b
.sb:
    mov edi, r15d
    lea esi, [r13+3]
    mov edx, DOCK_BTN
    mov ecx, DOCK_BTN
    call button
    mov [rbp-52], eax
    ; hover tooltip
    mov edi, r15d
    lea esi, [r13+3]
    mov edx, DOCK_BTN
    mov ecx, DOCK_BTN
    call ui_over
    test eax, eax
    jz .ic
    mov rax, [dock_tips+rbx*8]
    mov [tooltip], rax
.ic:
    mov edi, [dock_items+rbx*8]
    lea esi, [r15+3]
    lea edx, [r13+6]
    call draw_icon
    cmp dword [rbp-52], 0
    je .bn
    ; clicked
    mov eax, [dock_items+rbx*8+4]
    cmp eax, 10
    jge .c1
    mov [tool], eax
    mov dword [submenu], -1
    mov dword [drag_active], 0
    jmp .bn
.c1:
    cmp eax, 200
    jge .c2
    sub eax, 100
    cmp eax, [submenu]
    jne .c1o
    mov dword [submenu], -1
    jmp .bn
.c1o:
    mov [submenu], eax
    mov eax, [rbp-48]
    mov [submenu_x], eax
    jmp .bn
.c2:
    sub eax, 199
    cmp eax, [panel]
    jne .c2o
    xor eax, eax
.c2o:
    mov [panel], eax
    mov dword [submenu], -1
.bn:
    inc ebx
    jmp .b
.tip:
    ; tool hint above the dock
    cmp dword [drag_active], 0
    je .out
    call tb_reset
    mov eax, [tool]
    mov rdi, [tool_names+rax*8]
    call tb_str
    lea rdi, [s_cost]
    call tb_str
    movsxd rdi, dword [tl_cost]
    call tb_money
    mov edi, [ui_w]
    shr edi, 1
    mov esi, r13d
    sub esi, 14
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    movsxd rax, dword [tl_cost]
    cmp rax, [money]
    jle .tc
    mov ecx, UI_BAD
.tc:
    call draw_text_centered
.out:
    RETURN

; submenu popup above its dock button
FUNC draw_submenu, 32
    mov eax, [submenu]
    cmp eax, -1
    je .out
    mov r15, [submenu_lists+rax*8]
    ; count
    xor ecx, ecx
.cnt:
    cmp dword [r15+rcx*4], -1
    je .cd
    inc ecx
    jmp .cnt
.cd:
    mov [rbp-48], ecx
    imul eax, ecx, 18
    add eax, 6
    mov [rbp-52], eax               ; height
    mov r12d, [submenu_x]
    sub r12d, 70
    CLAMP r12d, 4, 10000
    mov eax, [ui_w]
    sub eax, 184
    cmp r12d, eax
    jle .xo
    mov r12d, eax
.xo:
    mov r13d, [ui_h]
    sub r13d, DOCK_BTN+12
    sub r13d, [rbp-52]
    mov edi, r12d
    mov esi, r13d
    mov edx, 180
    mov ecx, [rbp-52]
    call draw_panel
    xor ebx, ebx
.i:
    cmp ebx, [rbp-48]
    jge .out
    mov r14d, [r15+rbx*4]
    imul eax, ebx, 18
    lea esi, [r13+rax+3]
    mov [rbp-56], esi
    ; selected?
    xor r8d, r8d
    cmp r14d, 1000
    jl .bk
    lea eax, [r14-1000]
    cmp eax, [overlay_mode]
    sete r8b
    jmp .bt
.bk:
    cmp dword [tool], T_BUILD
    jne .bt
    cmp r14d, [build_kind]
    sete r8b
.bt:
    lea edi, [r12+3]
    mov edx, 174
    mov ecx, 16
    call button
    test eax, eax
    jz .draw
    cmp r14d, 1000
    jl .setb
    lea eax, [r14-1000]
    mov [overlay_mode], eax
    mov dword [submenu], -1
    jmp .draw
.setb:
    mov [build_kind], r14d
    mov dword [tool], T_BUILD
    mov dword [submenu], -1
.draw:
    cmp r14d, 1000
    jl .bname
    lea eax, [r14-1000]
    mov rdx, [overlay_names+rax*8]
    lea edi, [r12+8]
    mov esi, [rbp-56]
    add esi, 4
    mov ecx, UI_TEXT
    call draw_text
    jmp .in
.bname:
    mov edi, r14d
    call bld_rec
    mov [rbp-64], rax
    mov rdx, [rax+BI_NAME]
    lea edi, [r12+8]
    mov esi, [rbp-56]
    add esi, 4
    mov ecx, UI_TEXT
    mov rax, [rbp-64]
    mov r8d, [rax+BI_UNLOCK]
    cmp [population], r8d
    jge .bn2
    mov ecx, UI_DIM
.bn2:
    call draw_text
    ; cost / lock on the right
    call tb_reset
    mov rax, [rbp-64]
    mov r8d, [rax+BI_UNLOCK]
    cmp [population], r8d
    jge .cost
    mov edi, 132
    call tb_char
    movsxd rdi, r8d
    call tb_num
    lea edi, [r12+174]
    mov esi, [rbp-56]
    add esi, 4
    lea rdx, [textbuf]
    mov ecx, UI_BAD
    call draw_text_right
    jmp .in
.cost:
    movsxd rdi, dword [rax+BI_COST]
    call tb_money
    lea edi, [r12+174]
    mov esi, [rbp-56]
    add esi, 4
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text_right
.in:
    inc ebx
    jmp .i
.out:
    RETURN

; ---------------------------------------------------------------------
;  inspect panel
; ---------------------------------------------------------------------
%macro ROW_TEXT 2      ; label ptr, colour
    lea rdx, [%1]
    mov edi, r12d
    add edi, 6
    mov esi, r13d
    mov ecx, %2
    call draw_text
    add r13d, 11
%endmacro

; stat row: label, value 0..255, colour
FUNC stat_row
    ; edi = label, esi = value, edx = colour ; uses [row_x],[row_y]
    mov r12, rdi
    mov r13d, esi
    mov r14d, edx
    mov edi, [row_x]
    add edi, 6
    mov esi, [row_y]
    mov rdx, r12
    mov ecx, UI_DIM
    call draw_text
    mov edi, [row_x]
    add edi, 80
    mov esi, [row_y]
    add esi, 2
    mov edx, 80
    mov ecx, r13d
    mov r8d, r14d
    call meter
    add dword [row_y], 10
    RETURN
section .bss
row_x resd 1
row_y resd 1
section .text

FUNC draw_inspect, 32
    cmp dword [sel_x], 0
    jl .out
    mov edi, [sel_x]
    mov esi, [sel_y]
    call tile_at
    test rax, rax
    jz .out
    mov rbx, rax
    mov eax, [sel_y]
    shl eax, MAP_SHIFT
    add eax, [sel_x]
    mov r15d, eax                   ; map index
    mov r12d, 4
    mov r13d, 42
    mov [row_x], r12d
    mov edi, r12d
    mov esi, r13d
    sub esi, 4
    mov edx, 172
    mov ecx, 196
    call draw_panel
    ; close box
    lea edi, [r12+158]
    mov esi, r13d
    mov edx, 10
    mov ecx, 10
    call ui_hit
    test eax, eax
    jz .nc
    mov dword [sel_x], -1
    jmp .out
.nc:
    lea edi, [r12+160]
    mov esi, r13d
    lea rdx, [s_x]
    mov ecx, UI_DIM
    call draw_text
    ; title
    call tb_reset
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_ZONEBLD
    je .tz
    cmp eax, OBJ_NONE
    jne .tobj
    movzx eax, byte [rbx+T_ZONE]
    test eax, eax
    jz .tterr
.tz:
    movzx eax, byte [rbx+T_ZONE]
    mov rdi, [zone_names+rax*8]
    call tb_str
    jmp .tdraw
.tobj:
    cmp eax, OBJ_SERVICE
    jne .troad
    movzx edi, byte [rbx+T_SUB]
    call bld_rec
    mov rdi, [rax+BI_NAME]
    call tb_str
    jmp .tdraw
.troad:
    lea rdi, [s_road]
    test byte [rbx+T_FLAGS], F_HIGHWAY
    jz .tr1
    lea rdi, [s_highway]
.tr1:
    cmp byte [rbx+T_TERRAIN], TER_WATER
    jne .tr2
    cmp eax, OBJ_ROAD
    jne .tr2
    lea rdi, [s_bridge]
.tr2:
    cmp eax, OBJ_ROAD
    je .tstr
    lea rdi, [s_powerline]
    cmp eax, OBJ_POWER
    je .tstr
    lea rdi, [s_trees]
    cmp eax, OBJ_TREE
    je .tstr
    lea rdi, [s_rubble]
.tstr:
    call tb_str
    jmp .tdraw
.tterr:
    lea rdi, [s_grass]
    cmp byte [rbx+T_TERRAIN], TER_WATER
    jne .tt
    lea rdi, [s_water_t]
.tt:
    call tb_str
.tdraw:
    lea edi, [r12+6]
    mov esi, r13d
    mov ecx, UI_GOLD
    call tb_draw
    add r13d, 13
    mov [row_y], r13d

    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_ZONEBLD
    je .zone
    cmp eax, OBJ_NONE
    jne .nz
    cmp byte [rbx+T_ZONE], 0
    jne .zone
.nz:
    cmp eax, OBJ_SERVICE
    je .svc
    cmp eax, OBJ_ROAD
    je .road
    jmp .maps

.zone:
    ; level name
    movzx eax, byte [rbx+T_LEVEL]
    cmp byte [rbx+T_OBJ], OBJ_NONE
    jne .lv
    xor eax, eax
.lv:
    CLAMP eax, 0, 5
    mov rdx, [lvl_names+rax*8]
    lea edi, [r12+6]
    mov esi, [row_y]
    mov ecx, UI_TEXT
    test byte [rbx+T_FLAGS], F_ABANDON
    jz .lvn
    lea rdx, [s_abandoned]
    mov ecx, UI_BAD
.lvn:
    test byte [rbx+T_FLAGS], F_BUILD
    jz .lvb
    lea rdx, [s_building]
    mov ecx, UI_WARN
.lvb:
    call draw_text
    add dword [row_y], 11
    ; residents / jobs
    call tb_reset
    lea rdi, [s_residents]
    cmp byte [rbx+T_ZONE], ZONE_R
    je .rj
    lea rdi, [s_jobs]
.rj:
    call tb_str
    movzx edi, word [rbx+T_POP]
    call tb_num
    lea edi, [r12+6]
    mov esi, [row_y]
    mov ecx, UI_TEXT
    call tb_draw
    add dword [row_y], 11
    ; utilities
    lea rdx, [s_power_ok]
    mov ecx, UI_GOOD
    test byte [rbx+T_FLAGS], F_POWER
    jnz .pw
    lea rdx, [s_power_no]
    mov ecx, UI_BAD
.pw:
    lea edi, [r12+6]
    mov esi, [row_y]
    call draw_text
    lea rdx, [s_water_ok]
    mov ecx, UI_ACCENT
    test byte [rbx+T_FLAGS], F_WATER
    jnz .wt
    lea rdx, [s_water_no]
    mov ecx, UI_DIM
.wt:
    lea edi, [r12+86]
    mov esi, [row_y]
    call draw_text
    add dword [row_y], 11
    lea rdx, [s_road_ok]
    mov ecx, UI_GOOD
    test byte [rbx+T_FLAGS], F_ROADOK
    jnz .ro
    lea rdx, [s_road_no]
    mov ecx, UI_BAD
.ro:
    lea edi, [r12+6]
    mov esi, [row_y]
    call draw_text
    add dword [row_y], 12
    ; bars
    lea rdi, [s_desire]
    movzx esi, byte [rbx+T_SCORE]
    mov edx, UI_GOLD
    call stat_row
    lea rdi, [s_happiness]
    movzx esi, byte [rbx+T_HAPPY]
    imul esi, 255
    mov eax, esi
    xor edx, edx
    mov ecx, 100
    div ecx
    mov esi, eax
    mov edx, UI_GOOD
    call stat_row
    ; growth hint
    call growth_hint
    test rax, rax
    jz .maps
    mov r14, rax
    call tb_reset
    lea rdi, [s_needs]
    call tb_str
    mov rdi, r14
    call tb_str
    lea edi, [r12+6]
    mov esi, [row_y]
    mov ecx, UI_WARN
    call tb_draw
    add dword [row_y], 12
    jmp .maps

.svc:
    ; walk to anchor for info
    movzx edi, byte [rbx+T_SUB]
    call bld_rec
    mov r14, rax
    lea rdx, [s_power_ok]
    mov ecx, UI_GOOD
    test byte [rbx+T_FLAGS], F_POWER
    jnz .spw
    lea rdx, [s_power_no]
    mov ecx, UI_BAD
.spw:
    lea edi, [r12+6]
    mov esi, [row_y]
    call draw_text
    add dword [row_y], 11
    call tb_reset
    lea rdi, [s_upkeep]
    call tb_str
    movsxd rdi, dword [r14+BI_UPKEEP]
    call tb_money
    lea rdi, [s_permonth]
    call tb_str
    lea edi, [r12+6]
    mov esi, [row_y]
    mov ecx, UI_TEXT
    call tb_draw
    add dword [row_y], 11
    mov eax, [r14+BI_POWER]
    add eax, [r14+BI_WATER]
    test eax, eax
    jz .srad
    call tb_reset
    lea rdi, [s_produces]
    call tb_str
    mov eax, [r14+BI_POWER]
    add eax, [r14+BI_WATER]
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_units]
    call tb_str
    lea edi, [r12+6]
    mov esi, [row_y]
    mov ecx, UI_TEXT
    call tb_draw
    add dword [row_y], 11
.srad:
    movzx eax, byte [r14+BI_RADIUS]
    test eax, eax
    jz .maps
    call tb_reset
    lea rdi, [s_radius]
    call tb_str
    movzx edi, byte [r14+BI_RADIUS]
    call tb_num
    lea edi, [r12+6]
    mov esi, [row_y]
    mov ecx, UI_TEXT
    call tb_draw
    add dword [row_y], 11
    jmp .maps
.road:
    lea rdi, [s_traffic]
    movzx esi, byte [rbx+T_TRAFFIC]
    mov edx, UI_WARN
    call stat_row
.maps:
    add dword [row_y], 2
    lea rdi, [s_landval]
    movzx esi, byte [map_lv+r15]
    mov edx, UI_GOLD
    call stat_row
    lea rdi, [s_pollution]
    movzx esi, byte [map_pol+r15]
    mov edx, UI_BAD
    call stat_row
    lea rdi, [s_crime]
    movzx esi, byte [map_crime+r15]
    mov edx, UI_BAD
    call stat_row
    lea rdi, [s_police]
    movzx esi, byte [map_police+r15]
    mov edx, UI_ACCENT
    call stat_row
    lea rdi, [s_firecov]
    movzx esi, byte [map_fire+r15]
    mov edx, UI_WARN
    call stat_row
    lea rdi, [s_healthc]
    movzx esi, byte [map_health+r15]
    mov edx, UI_GOOD
    call stat_row
    lea rdi, [s_educ]
    movzx esi, byte [map_edu+r15]
    mov edx, UI_ACCENT
    call stat_row
    ; fire: call the fire brigade
    test byte [rbx+T_FLAGS], F_FIRE
    jz .out
    mov edi, [row_x]
    add edi, 6
    mov esi, [row_y]
    add esi, 2
    lea rdx, [s_burning]
    mov ecx, UI_BAD
    call draw_text
    mov edi, [row_x]
    add edi, 6
    mov esi, [row_y]
    add esi, 13
    mov edx, 160
    lea rcx, [s_fightfire]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .out
    call fight_fire
.out:
    RETURN
section .data
s_x db "x", 0
section .text

; the reason a zone tile is not growing -> rax string or 0
FUNC growth_hint
    ; rbx = tile, r15d = map index (caller's registers are ours to read)
    test byte [rbx+T_FLAGS], F_BUILD
    jnz .none
    lea rax, [s_n_road]
    test byte [rbx+T_FLAGS], F_ROADOK
    jz .o
    lea rax, [s_n_power]
    test byte [rbx+T_FLAGS], F_POWER
    jz .o
    movzx ecx, byte [rbx+T_LEVEL]
    cmp byte [rbx+T_OBJ], OBJ_NONE
    jne .l
    xor ecx, ecx
.l:
    cmp ecx, 5
    jge .max
    ; highway link for R / I
    cmp byte [rbx+T_ZONE], ZONE_C
    je .hw
    mov edi, [sel_x]
    mov esi, [sel_y]
    push rcx
    push rcx
    call road_near
    pop rcx
    pop rcx
    cmp eax, 2
    lea rax, [s_n_hwy]
    jne .o
.hw:
    cmp ecx, 1
    jl .val
    lea rax, [s_n_water]
    test byte [rbx+T_FLAGS], F_WATER
    jz .o
    cmp ecx, 3
    jl .val
    lea rax, [s_n_svc]
    movzx edx, byte [map_police+r15]
    movzx esi, byte [map_fire+r15]
    add edx, esi
    cmp edx, 60
    jl .o
    cmp ecx, 4
    jl .val
    lea rax, [s_n_edu]
    cmp byte [rbx+T_ZONE], ZONE_I
    je .ie
    movzx edx, byte [map_edu+r15]
    cmp edx, 40
    jl .o
    movzx edx, byte [map_health+r15]
    cmp edx, 30
    jl .o
    jmp .val
.ie:
    movzx edx, byte [map_edu+r15]
    cmp edx, 90
    jl .o
.val:
    lea rax, [s_n_value]
    RETURN
.max:
    lea rax, [s_n_max]
.o:
    RETURN
.none:
    xor eax, eax
    RETURN

; firefighters: needs a fire station anywhere; costs $150
FUNC fight_fire
    cmp dword [svc_count+BK_FIRE*4], 0
    jne .have
    lea rdi, [s_nofiredep]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_ERROR
    call sfx_play
    jmp .out
.have:
    cmp qword [money], 150
    jl .out
    sub qword [money], 150
    ; put out this tile and its neighbours
    mov r14d, -1
.dy:
    mov r15d, -1
.dx:
    mov edi, [sel_x]
    add edi, r15d
    mov esi, [sel_y]
    add esi, r14d
    call tile_at
    test rax, rax
    jz .n
    and byte [rax+T_FLAGS], ~F_FIRE
.n:
    inc r15d
    cmp r15d, 1
    jle .dx
    inc r14d
    cmp r14d, 1
    jle .dy
    mov edi, [sel_x]
    mov esi, [sel_y]
    mov edx, 20
    mov ecx, PK_STEAM
    mov r8d, 8
    call fx_burst
    lea rdi, [msg_fire_out]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_CHIME
    call sfx_play
.out:
    RETURN

; ---------------------------------------------------------------------
;  budget panel
; ---------------------------------------------------------------------
%macro BROW 3   ; label, value dword, colour
    lea rdx, [%1]
    lea edi, [r12+10]
    mov esi, r13d
    mov ecx, UI_DIM
    call draw_text
    call tb_reset
    movsxd rdi, dword [%2]
    call tb_money
    lea edi, [r12+150]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, %3
    call draw_text_right
    add r13d, 11
%endmacro

FUNC draw_budget, 32
    mov r12d, [ui_w]
    sub r12d, 330
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, 210
    shr r13d, 1
    mov [rbp-48], r13d
    mov edi, r12d
    mov esi, r13d
    mov edx, 330
    mov ecx, 190
    call draw_panel
    ; swallow clicks on the panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 330
    mov ecx, 190
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_budget]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    add r13d, 30
    ; tax
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [s_tax]
    mov ecx, UI_TEXT
    call draw_text
    lea edi, [r12+80]
    lea esi, [r13-3]
    mov edx, 16
    lea rcx, [s_minus]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .t1
    cmp dword [tax_rate], 0
    jle .t1
    dec dword [tax_rate]
.t1:
    lea edi, [r12+134]
    lea esi, [r13-3]
    mov edx, 16
    lea rcx, [s_plus]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .t2
    cmp dword [tax_rate], 20
    jge .t2
    inc dword [tax_rate]
.t2:
    call tb_reset
    movsxd rdi, dword [tax_rate]
    call tb_pct
    lea edi, [r12+117]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text_centered
    add r13d, 16
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [s_income]
    mov ecx, UI_TEXT
    call draw_text
    add r13d, 11
    BROW s_res, inc_res, UI_GOOD
    BROW s_com, inc_com, UI_GOOD
    BROW s_ind, inc_ind, UI_GOOD
    add r13d, 3
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [s_expense]
    mov ecx, UI_TEXT
    call draw_text
    add r13d, 11
    BROW s_roads, exp_roads, UI_BAD
    BROW s_services, exp_services, UI_BAD
    add r13d, 3
    mov eax, [income_last]
    sub eax, [expense_last]
    mov [budget_net], eax
    mov ecx, UI_GOOD
    test eax, eax
    jns .ng
    mov ecx, UI_BAD
.ng:
    mov [rbp-52], ecx
    lea rdx, [s_net]
    lea edi, [r12+10]
    mov esi, r13d
    mov ecx, UI_TEXT
    call draw_text
    call tb_reset
    movsxd rdi, dword [budget_net]
    call tb_money
    lea edi, [r12+150]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, [rbp-52]
    call draw_text_right
    ; history charts
    mov r13d, [rbp-48]
    add r13d, 30
    lea edi, [r12+170]
    mov esi, r13d
    lea rdx, [s_pophist]
    mov ecx, UI_TEXT
    call draw_text
    lea edi, [r12+170]
    lea esi, [r13+12]
    lea rdx, [hist_pop]
    mov ecx, UI_GOOD
    call draw_chart
    lea edi, [r12+170]
    lea esi, [r13+76]
    lea rdx, [s_cashhist]
    mov ecx, UI_TEXT
    call draw_text
    lea edi, [r12+170]
    lea esi, [r13+88]
    lea rdx, [hist_money]
    mov ecx, UI_GOLD
    call draw_chart
    RETURN
section .data
s_minus db "-", 0
s_plus  db "+", 0
section .bss
budget_net resd 1
section .text

; draw_chart(edi x, esi y, rdx history[64], ecx colour) 150x50 bars
FUNC draw_chart, 32
    mov r12d, edi
    mov r13d, esi
    mov r14, rdx
    mov [rbp-48], ecx
    mov edi, r12d
    mov esi, r13d
    mov edx, 150
    mov ecx, 52
    mov r8d, UI_BG2
    call draw_box
    ; max over the samples we have
    mov ecx, [hist_count]
    CLAMP ecx, 0, 64
    mov [rbp-52], ecx
    mov ebx, 1
    xor edx, edx
.mx:
    cmp edx, ecx
    jge .md
    mov eax, [r14+rdx*4]
    cmp eax, ebx
    jle .mn
    mov ebx, eax
.mn:
    inc edx
    jmp .mx
.md:
    xor r15d, r15d
.b:
    cmp r15d, [rbp-52]
    jge .out
    ; oldest first
    mov eax, [hist_count]
    sub eax, [rbp-52]
    add eax, r15d
    and eax, 63
    mov eax, [r14+rax*4]
    test eax, eax
    jns .pos
    xor eax, eax
.pos:
    imul eax, 46
    xor edx, edx
    div ebx
    mov ecx, eax
    lea edi, [r12+r15*2+3]
    mov esi, r13d
    add esi, 49
    sub esi, eax
    mov edx, 2
    mov r8d, [rbp-48]
    call fill_rect
    inc r15d
    jmp .b
.out:
    RETURN

; ---------------------------------------------------------------------
;  menu panel
; ---------------------------------------------------------------------
FUNC draw_menu, 16
    mov r12d, [ui_w]
    sub r12d, 170
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, 222
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, 170
    mov ecx, 216
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 170
    mov ecx, 216
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+85]
    lea esi, [r13+6]
    lea rdx, [s_menu]
    mov ecx, UI_GOLD
    call draw_text_centered
    mov dword [font_scale], 1
    add r13d, 28
%macro MBTN 1
    lea edi, [r12+10]
    mov esi, r13d
    mov edx, 150
    lea rcx, [%1]
    xor r8d, r8d
    call text_button
    add r13d, 18
%endmacro
    MBTN s_m_resume
    test eax, eax
    jz .m1
    mov dword [panel], PANEL_NONE
.m1:
    MBTN s_m_save
    test eax, eax
    jz .m2
    call save_city
.m2:
    MBTN s_m_load
    test eax, eax
    jz .m3
    call load_city
.m3:
    MBTN s_m_new
    test eax, eax
    jz .m4
    call new_city
    mov dword [panel], PANEL_NONE
.m4:
    call tb_reset
    lea rdi, [s_m_music]
    call tb_str
    lea rdi, [s_on]
    cmp dword [music_on], 0
    jne .mu
    lea rdi, [s_off]
.mu:
    call tb_str
    lea edi, [r12+10]
    mov esi, r13d
    mov edx, 150
    lea rcx, [textbuf]
    xor r8d, r8d
    call text_button
    add r13d, 18
    test eax, eax
    jz .m5
    call music_toggle
.m5:
    call tb_reset
    lea rdi, [s_m_dis]
    call tb_str
    lea rdi, [s_on]
    cmp dword [disasters_on], 0
    jne .di
    lea rdi, [s_off]
.di:
    call tb_str
    lea edi, [r12+10]
    mov esi, r13d
    mov edx, 150
    lea rcx, [textbuf]
    xor r8d, r8d
    call text_button
    add r13d, 18
    test eax, eax
    jz .m6
    xor dword [disasters_on], 1
.m6:
    call tb_reset
    lea rdi, [s_m_day]
    call tb_str
    lea rdi, [s_cycle]
    cmp dword [tod_lock], 0
    je .dy
    lea rdi, [s_locked_d]
.dy:
    call tb_str
    lea edi, [r12+10]
    mov esi, r13d
    mov edx, 150
    lea rcx, [textbuf]
    xor r8d, r8d
    call text_button
    add r13d, 18
    test eax, eax
    jz .m7
    xor dword [tod_lock], 1
.m7:
    MBTN s_m_full
    test eax, eax
    jz .m8
    call video_toggle_fullscreen
.m8:
    MBTN s_m_help
    test eax, eax
    jz .m9
    mov dword [panel], PANEL_HELP
.m9:
    MBTN s_m_quit
    test eax, eax
    jz .out
    mov dword [running], 0
.out:
    RETURN

FUNC draw_help
    mov r12d, [ui_w]
    sub r12d, 330
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, 190
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, 330
    mov ecx, 170
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 330
    mov ecx, 170
    call ui_hit
    test eax, eax
    jz .d
    mov dword [panel], PANEL_NONE
.d:
    lea edi, [r12+10]
    lea esi, [r13+8]
    lea rdx, [s_help]
    mov ecx, UI_TEXT
    call draw_text
    RETURN

FUNC draw_welcome
    mov r12d, [ui_w]
    sub r12d, 330
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, 150
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, 330
    mov ecx, 130
    call draw_panel
    mov dword [font_scale], 2
    lea edi, [r12+165]
    lea esi, [r13+8]
    lea rdx, [s_welcome1]
    mov ecx, UI_GOLD
    call draw_text_centered
    mov dword [font_scale], 1
    lea edi, [r12+12]
    lea esi, [r13+32]
    lea rdx, [s_welcome2]
    mov ecx, UI_TEXT
    call draw_text
    RETURN

; ---------------------------------------------------------------------
;  overlay legend + minimap
; ---------------------------------------------------------------------
FUNC draw_overlay_legend
    mov eax, [overlay_mode]
    test eax, eax
    jz .out
    mov rdi, [overlay_names+rax*8]
    mov r12, rdi
    mov r13d, [ui_w]
    shr r13d, 1
    lea edi, [r13-70]
    mov esi, 38
    mov edx, 140
    mov ecx, 26
    call draw_panel
    mov edi, r13d
    mov esi, 41
    mov rdx, r12
    mov ecx, UI_TEXT
    call draw_text_centered
    xor ebx, ebx
.g:
    lea edi, [r13-64]
    lea edi, [rdi+rbx*8]
    mov esi, 53
    mov edx, 8
    mov ecx, 6
    lea r8d, [rbx+PAL_HEAT]
    call fill_rect
    inc ebx
    cmp ebx, 16
    jl .g
.out:
    RETURN

; minimap colour for a tile
minimap_colour:  ; rdi tile -> eax colour
    movzx eax, byte [rdi+T_OBJ]
    cmp eax, OBJ_ROAD
    jne .a
    mov eax, RAMP(R_GREY, 3)
    ret
.a: cmp eax, OBJ_ZONEBLD
    je .z
    cmp eax, OBJ_SERVICE
    jne .b
    mov eax, RAMP(R_WHITE, 6)
    ret
.b: cmp eax, OBJ_TREE
    jne .c
    mov eax, RAMP(R_LEAF, 3)
    ret
.c: cmp eax, OBJ_NONE
    jne .t
    cmp byte [rdi+T_ZONE], 0
    je .t
.z: movzx eax, byte [rdi+T_ZONE]
    lea eax, [rax*8+RAMP_BASE+R_ZONER*8-8+4]
    ret
.t: cmp byte [rdi+T_TERRAIN], TER_WATER
    jne .g
    mov eax, RAMP(R_DEEPWATER, 3)
    ret
.g: cmp byte [rdi+T_TERRAIN], TER_SAND
    jne .gg
    mov eax, RAMP(R_SAND, 5)
    ret
.gg:
    mov eax, RAMP(R_GRASS, 4)
    ret

FUNC draw_minimap
    cmp dword [minimap_on], 0
    je .out
    ; rebuild the cached image twice a second
    dec dword [minimap_age]
    jns .draw
    mov dword [minimap_age], 30
    lea rdi, [minimap_buf]
    xor eax, eax
    mov ecx, 128*64
    rep stosb
    xor r13d, r13d
.y:
    xor r12d, r12d
.x:
    mov edi, r12d
    mov esi, r13d
    call tile_at
    mov rdi, rax
    call minimap_colour
    ; iso: px = (x - y)/2 + 64, py = (x + y)/4
    mov ecx, r12d
    sub ecx, r13d
    sar ecx, 1
    add ecx, 64
    mov edx, r12d
    add edx, r13d
    shr edx, 2
    cmp ecx, 128
    jae .n
    shl edx, 7
    add edx, ecx
    mov [minimap_buf+rdx], al
.n:
    inc r12d
    cmp r12d, MAP_W
    jl .x
    inc r13d
    cmp r13d, MAP_W
    jl .y
.draw:
    mov r12d, [ui_w]
    sub r12d, 136
    mov r13d, [ui_h]
    sub r13d, DOCK_BTN+86
    mov edi, r12d
    mov esi, r13d
    mov edx, 134
    mov ecx, 70
    call draw_panel
    ; click to move camera
    mov edi, r12d
    mov esi, r13d
    mov edx, 134
    mov ecx, 70
    call ui_over
    test eax, eax
    jz .blit
    cmp dword [lmb_down], 0
    je .blit
    mov dword [click_pending], 0
    ; inverse iso
    mov eax, [umx]
    sub eax, r12d
    sub eax, 3
    sub eax, 64                     ; (x-y)/2
    shl eax, 1
    mov ecx, [umy]
    sub ecx, r13d
    sub ecx, 3
    shl ecx, 2                      ; x+y
    lea edi, [rcx+rax]
    sar edi, 1
    mov esi, ecx
    sub esi, eax
    sar esi, 1
    call camera_center_tile
.blit:
    xor ebx, ebx
.p:
    movzx edx, byte [minimap_buf+rbx]
    test edx, edx
    jz .pn
    mov edi, ebx
    and edi, 127
    lea edi, [rdi+r12+3]
    mov esi, ebx
    shr esi, 7
    lea esi, [rsi+r13+3]
    call put_pixel
.pn:
    inc ebx
    cmp ebx, 128*64
    jl .p
    ; view marker (centre of the camera)
    mov edi, [fb_w]
    shr edi, 1
    add edi, [cam_x]
    mov esi, [fb_h]
    shr esi, 1
    add esi, [cam_y]
    call world_to_tile
    mov ecx, eax
    sub ecx, edx
    sar ecx, 1
    add ecx, 64
    add eax, edx
    shr eax, 2
    lea edi, [r12+rcx+1]
    lea esi, [r13+rax+1]
    mov edx, 5
    mov ecx, 5
    mov r8d, UI_TEXT
    call rect_outline
.out:
    RETURN

; =====================================================================
;  render_ui: everything on the ui layer, in order
; =====================================================================
FUNC render_ui
    call set_target_ui
    xor edi, edi
    call clear_target
    mov eax, [mouse_x]
    xor edx, edx
    div dword [ui_scale]
    mov [umx], eax
    mov eax, [mouse_y]
    xor edx, edx
    div dword [ui_scale]
    mov [umy], eax
    mov dword [ui_captured], 0
    mov qword [tooltip], 0
    ; while dragging in the world, the ui stays out of the way
    cmp dword [drag_active], 0
    je .ui
    mov dword [click_pending], 0
.ui:
    call draw_floats
    cmp dword [welcome], 0
    je .game
    call draw_welcome
    jmp .cursor
.game:
    ; modal panels get first go at clicks
    mov eax, [panel]
    cmp eax, PANEL_BUDGET
    jne .p2
    call draw_budget
    jmp .hud
.p2:
    cmp eax, PANEL_MENU
    jne .p3
    call draw_menu
    jmp .hud
.p3:
    cmp eax, PANEL_HELP
    jne .hud
    call draw_help
.hud:
    call draw_topbar
    call draw_goal
    call draw_notifications
    call draw_submenu
    call draw_dock
    call draw_inspect
    call draw_minimap
    call draw_overlay_legend
    ; tooltip
    mov rdx, [tooltip]
    test rdx, rdx
    jz .cursor
    mov r12, rdx
    mov rdi, rdx
    call text_width
    lea edx, [rax+8]
    mov edi, [umx]
    add edi, 10
    mov eax, [ui_w]
    sub eax, edx
    cmp edi, eax
    jle .tx
    mov edi, eax
.tx:
    mov r13d, edi
    mov esi, [umy]
    sub esi, 18
    mov ecx, 13
    mov r8d, UI_BG2
    call draw_box
    lea edi, [r13+4]
    mov esi, [umy]
    sub esi, 15
    mov rdx, r12
    mov ecx, UI_TEXT
    call draw_text
.cursor:
    mov edi, ICON_CURSOR
    mov esi, [umx]
    mov edx, [umy]
    call draw_icon
    ; small tool icon beside the cursor
    cmp dword [ui_captured], 0
    jne .out
    mov eax, [tool]
    cmp eax, T_INSPECT
    je .out
    mov edi, ICON_BULLDOZE
    cmp eax, T_BULLDOZE
    je .ti
    mov edi, ICON_ROAD
    cmp eax, T_ROAD
    je .ti
    mov edi, ICON_POWERLINE
    cmp eax, T_POWERLN
    je .ti
    mov edi, ICON_ZONE_R
    cmp eax, T_ZONE_R
    je .ti
    mov edi, ICON_ZONE_C
    cmp eax, T_ZONE_C
    je .ti
    mov edi, ICON_ZONE_I
    cmp eax, T_ZONE_I
    je .ti
    mov edi, ICON_DEZONE
    cmp eax, T_DEZONE
    je .ti
    mov edi, ICON_TREE
    cmp eax, T_TREE
    je .ti
    mov edi, ICON_POWER
.ti:
    mov esi, [umx]
    add esi, 10
    mov edx, [umy]
    add edx, 12
    call draw_icon
.out:
    RETURN

; =====================================================================
;  keyboard
; =====================================================================
FUNC ui_key
    mov eax, edi
    cmp eax, SC_ESCAPE
    jne .k1
    cmp dword [welcome], 0
    je .e1
    mov dword [welcome], 0
    jmp .out
.e1:
    cmp dword [drag_active], 0
    je .e2
    mov dword [drag_active], 0
    jmp .out
.e2:
    cmp dword [submenu], -1
    je .e3
    mov dword [submenu], -1
    jmp .out
.e3:
    cmp dword [panel], PANEL_NONE
    je .e4
    mov dword [panel], PANEL_NONE
    jmp .out
.e4:
    cmp dword [tool], T_INSPECT
    je .e5
    mov dword [tool], T_INSPECT
    jmp .out
.e5:
    mov dword [panel], PANEL_MENU
    jmp .out
.k1:
    mov ecx, T_INSPECT
    cmp eax, SC_Q
    je .settool
    mov ecx, T_BULLDOZE
    cmp eax, SC_B
    je .settool
    mov ecx, T_ROAD
    cmp eax, SC_R
    je .settool
    mov ecx, T_POWERLN
    cmp eax, SC_L
    je .settool
    mov ecx, T_ZONE_R
    cmp eax, SC_1
    je .settool
    mov ecx, T_ZONE_C
    cmp eax, SC_1+1
    je .settool
    mov ecx, T_ZONE_I
    cmp eax, SC_1+2
    je .settool
    mov ecx, T_DEZONE
    cmp eax, SC_X
    je .settool
    mov ecx, T_TREE
    cmp eax, SC_T
    je .settool
    cmp eax, SC_SPACE
    jne .k2
    cmp dword [sim_speed], 0
    je .unp
    mov eax, [sim_speed]
    mov [saved_speed], eax
    mov dword [sim_speed], 0
    jmp .out
.unp:
    mov eax, [saved_speed]
    test eax, eax
    jnz .up2
    mov eax, 1
.up2:
    mov [sim_speed], eax
    jmp .out
.k2:
    cmp eax, SC_RBRACKET
    jne .k3
    cmp dword [sim_speed], 3
    jge .out
    inc dword [sim_speed]
    jmp .out
.k3:
    cmp eax, SC_LBRACKET
    jne .k4
    cmp dword [sim_speed], 1
    jle .out
    dec dword [sim_speed]
    jmp .out
.k4:
    cmp eax, SC_O
    jne .k5
    mov eax, [overlay_mode]
    inc eax
    cmp eax, OV_COUNT
    jl .ov
    xor eax, eax
.ov:
    mov [overlay_mode], eax
    jmp .out
.k5:
    cmp eax, SC_TAB
    jne .k6
    xor dword [minimap_on], 1
    jmp .out
.k6:
    cmp eax, SC_N
    jne .k7
    xor dword [tod_lock], 1
    jmp .out
.k7:
    cmp eax, SC_M
    jne .k8
    call music_toggle
    jmp .out
.k8:
    cmp eax, SC_F5
    jne .k9
    call save_city
    jmp .out
.k9:
    cmp eax, SC_F9
    jne .k10
    call load_city
    jmp .out
.k10:
    cmp eax, SC_F11
    jne .k11
    call video_toggle_fullscreen
    jmp .out
.k11:
    cmp eax, SC_F1
    jne .k12
    mov dword [panel], PANEL_HELP
    jmp .out
.k12:
    cmp eax, SC_F1+1
    jne .k13
    xor eax, eax
    cmp dword [panel], PANEL_BUDGET
    je .bp
    mov eax, PANEL_BUDGET
.bp:
    mov [panel], eax
    jmp .out
.k13:
    cmp eax, SC_MINUS
    je .zo
    cmp eax, SC_KP_MINUS
    jne .k14
.zo:
    mov edi, [zoom]
    dec edi
    call video_set_zoom
    jmp .out
.k14:
    cmp eax, SC_EQUALS
    je .zi
    cmp eax, SC_KP_PLUS
    jne .out
.zi:
    mov edi, [zoom]
    inc edi
    call video_set_zoom
    jmp .out
.settool:
    mov [tool], ecx
    mov dword [drag_active], 0
    mov dword [submenu], -1
.out:
    RETURN
section .bss
saved_speed resd 1
section .text

; =====================================================================
;  goals (checked daily)
; =====================================================================
FUNC check_goals
    mov eax, [goal_index]
    cmp eax, GOAL_COUNT
    jge .out
    xor ebx, ebx                    ; met?
    cmp eax, 0
    jne .g1
    ; road on the highway network (not the highway itself)
    xor ecx, ecx
    xor edx, edx
.r:
    mov r8d, ecx
    shl r8d, TILE_SHIFT
    cmp byte [tiles+r8+T_OBJ], OBJ_ROAD
    jne .rn
    test byte [tiles+r8+T_FLAGS], F_HIGHWAY
    jnz .rn
    test byte [tiles+r8+T_MISC], MISC_NET
    jz .rn
    inc edx
.rn:
    inc ecx
    cmp ecx, MAP_TILES
    jl .r
    cmp edx, 3
    setge bl
    jmp .chk
.g1:
    cmp eax, 1
    jne .g2
    xor ecx, ecx
    xor edx, edx
.z:
    mov r8d, ecx
    shl r8d, TILE_SHIFT
    cmp byte [tiles+r8+T_ZONE], ZONE_R
    jne .zn
    inc edx
.zn:
    inc ecx
    cmp ecx, MAP_TILES
    jl .z
    cmp edx, 6
    setge bl
    jmp .chk
.g2:
    cmp eax, 2
    jne .g3
    cmp dword [power_supply], 0
    je .chk
    cmp dword [population], 0
    setg bl
    jmp .chk
.g3:
    cmp eax, 3
    jne .g4
    cmp dword [population], 100
    setge bl
    jmp .chk
.g4:
    cmp eax, 4
    jne .g5
    cmp dword [water_supply], 0
    setg bl
    jmp .chk
.g5:
    cmp eax, 5
    jne .g6
    cmp dword [svc_count+BK_POLICE*4], 0
    je .chk
    cmp dword [svc_count+BK_FIRE*4], 0
    setne bl
    jmp .chk
.g6:
    cmp eax, 6
    jne .g7
    cmp dword [population], 500
    setge bl
    jmp .chk
.g7:
    cmp eax, 7
    jne .g8
    cmp dword [svc_count+BK_SCHOOL*4], 0
    setne bl
    jmp .chk
.g8:
    cmp eax, 8
    jne .g9
    cmp dword [jobs_c], 150
    setge bl
    jmp .chk
.g9:
    cmp eax, 9
    jne .g10
    cmp dword [population], 1500
    jl .chk
    cmp dword [happy_avg], 60
    setge bl
    jmp .chk
.g10:
    cmp eax, 10
    jne .g11
    mov ecx, [svc_count+BK_HOSPITAL*4]
    or ecx, [svc_count+BK_UNIV*4]
    setnz bl
    jmp .chk
.g11:
    cmp eax, 11
    jne .g12
    cmp dword [population], 5000
    setge bl
    jmp .chk
.g12:
    cmp eax, 12
    jne .g13
    cmp dword [svc_count+BK_LANDMARK*4], 0
    setne bl
    jmp .chk
.g13:
    cmp dword [population], 15000
    setge bl
.chk:
    test ebx, ebx
    jz .out
    mov eax, [goal_index]
    movsxd rcx, dword [goal_reward+rax*4]
    add [money], rcx
    call tb_reset
    lea rdi, [s_goaldone]
    call tb_str
    mov eax, [goal_index]
    movsxd rdi, dword [goal_reward+rax*4]
    call tb_money
    lea rdi, [textbuf]
    mov esi, UI_GOLD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_COIN
    call sfx_play
    inc dword [goal_index]
.out:
    RETURN

; =====================================================================
;  save / load / new
; =====================================================================
FUNC save_city, 16
    lea rdi, [s_savefile]
    lea rsi, [str_wb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz .out
    mov r12, rax
    mov rdi, r12
    lea rsi, [save_magic]
    mov edx, 8
    mov ecx, 1
    CALLC SDL_RWwrite
    mov rdi, r12
    lea rsi, [tiles]
    mov edx, MAP_TILES*TILE_BYTES
    mov ecx, 1
    CALLC SDL_RWwrite
    mov rdi, r12
    lea rsi, [money]
    mov edx, sim_state_end - money
    mov ecx, 1
    CALLC SDL_RWwrite
    mov rdi, r12
    lea rsi, [world_seed]
    mov edx, 12
    mov ecx, 1
    CALLC SDL_RWwrite
    mov rdi, r12
    CALLC SDL_RWclose
    lea rdi, [s_saved]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_CHIME
    call sfx_play
.out:
    RETURN

FUNC load_city, 16
    lea rdi, [s_savefile]
    lea rsi, [str_rb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz .fail
    mov r12, rax
    mov rdi, r12
    lea rsi, [numbuf]
    mov edx, 8
    mov ecx, 1
    CALLC SDL_RWread
    mov rax, [numbuf]
    cmp rax, [save_magic]
    jne .close
    mov rdi, r12
    lea rsi, [tiles]
    mov edx, MAP_TILES*TILE_BYTES
    mov ecx, 1
    CALLC SDL_RWread
    mov rdi, r12
    lea rsi, [money]
    mov edx, sim_state_end - money
    mov ecx, 1
    CALLC SDL_RWread
    mov rdi, r12
    lea rsi, [world_seed]
    mov edx, 12
    mov ecx, 1
    CALLC SDL_RWread
    mov rdi, r12
    CALLC SDL_RWclose
    call agents_init
    call scenic_init
    call networks_update
    call coverage_update
    call stats_update
    mov rax, [money]
    mov [money_shown], rax
    mov dword [sel_x], -1
    mov dword [panel], PANEL_NONE
    lea rdi, [s_loaded]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .out
.close:
    mov rdi, r12
    CALLC SDL_RWclose
.fail:
    lea rdi, [s_loadfail]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN
section .data
save_magic db "CSAVv001"
section .text

FUNC new_city
    CALLC SDL_GetPerformanceCounter
    mov [world_seed], eax
    call world_generate
    ; reset sim state block
    lea rdi, [money]
    mov ecx, sim_state_end - money
    xor eax, eax
    rep stosb
    call sim_init
    call agents_init
    mov rax, [money]
    mov [money_shown], rax
    mov dword [sel_x], -1
    mov dword [welcome], 1
    mov edi, 30
    mov esi, [hwy_row]
    call camera_center_tile
    RETURN
