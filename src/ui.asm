; =====================================================================
;  UI - immediate-mode interface, tools, panels and input
; =====================================================================

T_INSPECT   equ 0
T_BULLDOZE  equ 1
T_ROAD      equ 2
T_POWERLN   equ 3
T_ZONETOOL      equ 4
T_PIPE      equ 5
T_BUSSTOP   equ 6
T_DEZONE    equ 7
T_BUILD     equ 8
T_TREE      equ 9

PANEL_NONE     equ 0
PANEL_BUDGET   equ 1
PANEL_MENU     equ 2
PANEL_HELP     equ 3
PANEL_POLICIES equ 4
PANEL_STATS    equ 5

MAX_TL      equ 1100
NOTIFS      equ 5
DOCK_BTN    equ 22

; submenu item codes
SI_STREET   equ 100
SI_AVENUE   equ 101
SI_HIGHWAY  equ 102
SI_BUSSTOP  equ 103
SI_ZONE     equ 110        ; + zone type
SI_DEZONE   equ 117
SI_POWERLN  equ 120
SI_PIPE     equ 121
SI_OVERLAY  equ 1000       ; + overlay

%include "icons_data.asm"

section .bss
icon_bits       resb ICON_COUNT*256
tool            resd 1
build_kind      resd 1
road_type       resd 1
zone_type       resd 1
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
tl_valid        resd 1
tl_x            resd MAX_TL
tl_y            resd MAX_TL
tl_ok           resb MAX_TL
notif_text      resb NOTIFS*96
notif_col       resd NOTIFS
notif_tx        resd NOTIFS
notif_ty        resd NOTIFS
notif_time      resd NOTIFS
money_shown     resq 1
last_tool_err   resd 1
minimap_buf     resb 128*64
minimap_age     resd 1
saved_speed     resd 1
budget_net      resd 1
force_place     resd 1

section .data
; toolbar: icon, action (0..9 tool, 100+n submenu, 200+ panels)
dock_items:
    dd ICON_INSPECT, 0,    ICON_BULLDOZE, 1,  ICON_ROAD, 100,   ICON_ZONE_R, 101
    dd ICON_POWER, 102,    ICON_WATER, 103,   ICON_GARBAGE, 104, ICON_SAFETY, 105
    dd ICON_HEALTH, 106,   ICON_EDU, 107,     ICON_BUS, 108,    ICON_LEISURE, 109
    dd ICON_TREE, 9,       ICON_OVERLAY, 110, ICON_POLICY, 204, ICON_BUDGET, 201
    dd ICON_STATS, 205,    ICON_MENU, 202
DOCK_COUNT equ 18
dock_tips:
    dq tip0, tip1, tip2, tip3, tip4, tip5, tip6, tip7, tip8, tip9
    dq tip10, tip11, tip12, tip13, tip14, tip15, tip16, tip17
tip0  db "Inspect (Q)", 0
tip1  db "Bulldoze (B)", 0
tip2  db "Roads & bus stops (R)", 0
tip3  db "Zoning (1-6)", 0
tip4  db "Electricity", 0
tip5  db "Water, pipes & sewage (P)", 0
tip6  db "Garbage", 0
tip7  db "Police & fire", 0
tip8  db "Health", 0
tip9  db "Education", 0
tip10 db "Public transport", 0
tip11 db "Parks & landmarks", 0
tip12 db "Plant trees (T)", 0
tip13 db "Info views (O)", 0
tip14 db "Policies (F3)", 0
tip15 db "Budget & taxes (F2)", 0
tip16 db "City statistics (F4)", 0
tip17 db "Menu (Esc)", 0

submenu_lists:
    dq sm_roads, sm_zones, sm_power, sm_water, sm_garbage, sm_safety
    dq sm_health, sm_edu, sm_transit, sm_leisure, sm_overlay
sm_roads    dd SI_STREET, SI_AVENUE, SI_HIGHWAY, SI_BUSSTOP, -1
sm_zones    dd SI_ZONE+ZONE_R, SI_ZONE+ZONE_RH, SI_ZONE+ZONE_C, SI_ZONE+ZONE_CH
            dd SI_ZONE+ZONE_I, SI_ZONE+ZONE_O, SI_DEZONE, -1
sm_power    dd SI_POWERLN, BK_WIND, BK_COAL, BK_SOLAR, BK_NUCLEAR, -1
sm_water    dd SI_PIPE, BK_PUMP, BK_WTOWER, BK_SEWAGE, -1
sm_garbage  dd BK_LANDFILL, BK_INCIN, -1
sm_safety   dd BK_POLICE, BK_FIRE, -1
sm_health   dd BK_CLINIC, BK_HOSPITAL, -1
sm_edu      dd BK_ELEM, BK_HIGH, BK_UNIV, -1
sm_transit  dd BK_BUSDEPOT, SI_BUSSTOP, -1
sm_leisure  dd BK_PARK, BK_PLAZA, BK_STADIUM, BK_CITYHALL, BK_LANDMARK, -1
sm_overlay  dd 1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009
            dd 1010, 1011, 1012, 1013, 1014, 1015, -1
; the info view a submenu shows while it is open
submenu_view dd OV_TRAFFIC, OV_DESIRE_R, OV_POWER, OV_WATER, OV_GARBAGE, OV_POLICE
             dd OV_HEALTH, OV_EDU, OV_TRANSIT, OV_LANDVAL, 0

overlay_names:
    dq ov0, ov1, ov2, ov3, ov4, ov5, ov6, ov7, ov8, ov9, ov10, ov11, ov12, ov13, ov14, ov15
    dq ov16, ov17, ov18, ov19
ov0  db "No info view", 0
ov1  db "Electricity", 0
ov2  db "Water & pipes", 0
ov3  db "Pollution", 0
ov4  db "Noise", 0
ov5  db "Crime", 0
ov6  db "Land value", 0
ov7  db "Traffic", 0
ov8  db "Police", 0
ov9  db "Fire safety", 0
ov10 db "Health", 0
ov11 db "Education", 0
ov12 db "Garbage", 0
ov13 db "Public transport", 0
ov14 db "Happiness", 0
ov15 db "Natural resources", 0
ov16 db "Residential desirability", 0
ov17 db "Commercial desirability", 0
ov18 db "Industrial desirability", 0
ov19 db "Office desirability", 0
; legend hints for the utility views
ov_hint:
    dq 0, oh1, oh2, 0, 0, 0, 0, oh7, 0, 0, 0, 0, 0, 0, 0, oh15, 0, 0, 0, 0
oh1  db 2, "powered  ", 3, "no power", 0
oh2  db 7, "pipes  ", 2, "served  ", 3, "dry  ", 4, "polluted", 0
oh7  db 2, "flowing  ", 4, "busy  ", 3, "jammed", 0
oh15 db 2, "fertile  ", 7, "forest  ", 4, "ore", 0

zone_names  dq zn0, zn1, zn2, zn3, zn4, zn5, zn6
zn0 db "Empty land", 0
zn1 db "Residential (low)", 0
zn2 db "Commercial (low)", 0
zn3 db "Industrial", 0
zn4 db "Office", 0
zn5 db "Residential (high)", 0
zn6 db "Commercial (high)", 0
spec_names  dq sp_gen, sp_farm, sp_forest, sp_ore
sp_gen    db "Manufacturing", 0
sp_farm   db "Farming", 0
sp_forest db "Forestry", 0
sp_ore    db "Mining", 0
lvl_names   dq lv0, lv1, lv2, lv3, lv4, lv5
lv0 db "Empty lot", 0
lv1 db "Level 1", 0
lv2 db "Level 2", 0
lv3 db "Level 3", 0
lv4 db "Level 4", 0
lv5 db "Level 5", 0
road_names  dq rn0, rn1, rn2
rn0 db "Street", 0
rn1 db "Avenue", 0
rn2 db "Highway", 0
road_costs  dd 10, 25, 40
tool_item_names:
    dq rn0, rn1, rn2, ti_stop
ti_stop    db "Bus stop", 0
ti_dezone  db "De-zone", 0
ti_line    db "Power line", 0
ti_pipe    db "Water pipe", 0
ti_tile    db "/tile", 0

s_welcome1  db "Welcome, Mayor!", 0
s_welcome2  db "This valley needs a city. Extend the highway with a road,", 10
            db "zone homes and industry, then add power, water pipes and", 10
            db "a sewage outlet. Picking a tool shows its info view.", 10, 10
            db 7, "Drag", 1, " to build.  ", 7, "Right-drag", 1, " / WASD to pan.  ", 7, "Wheel", 1, " to zoom.", 10
            db 7, "Space", 1, " pause   ", 7, "O", 1, " info views   ", 7, "F1", 1, " help", 10, 10
            db 5, "Click anywhere to begin.", 0
s_help      db "CONTROLS", 10, 10
            db 7, "Left drag", 1, "    build with the current tool", 10
            db 7, "Right drag", 1, "   pan (also WASD / arrows), right click cancels", 10
            db 7, "Wheel", 1, "        zoom (also - and =)", 10
            db 7, "Q B R T P L", 1, "  inspect, bulldoze, road, trees, pipes, power line", 10
            db 7, "1 2 3 4 5 6", 1, "  zones: res, shop, industry, office, dense res/shop", 10
            db 7, "Space  [ ]", 1, "   pause, game speed", 10
            db 7, "O", 1, "            info views     ", 7, "Tab", 1, " minimap", 10
            db 7, "F2 F3 F4", 1, "     budget, policies, statistics", 10
            db 7, "F5 / F9", 1, "      save / load  ", 7, "F11", 1, " fullscreen  ", 7, "N M", 1, " day, music", 10, 10
            db 6, "Icons above buildings show their biggest problem.", 10
            db 6, "Inspect a building to see what it needs to grow.", 0
s_goal      db "GOAL ", 0
s_reward    db "  reward ", 0
s_goaldone  db "Goal complete! +", 0
s_nomoney   db "Not enough money!", 0
s_locked    db "Unlocks at population ", 0
s_needwater db "This must be placed touching water.", 0
s_budget    db "BUDGET", 0
s_taxes     db "Taxes", 0
s_classn    dq s_res, s_com, s_ind, s_offc
s_res       db "Residential", 0
s_com       db "Commercial", 0
s_ind       db "Industrial", 0
s_offc      db "Office", 0
s_other     db "Fares, exports, tourism", 0
s_income    db "Income", 0
s_expense   db "Expenses", 0
s_roads     db "Roads", 0
s_services  db "Services", 0
s_policiesx db "Policies", 0
s_net       db "Net per month", 0
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
s_car       db 136, " ", 0
s_slash     db "/", 0
s_rcio      db "R C I O", 0
s_cost      db "  cost ", 0
s_residents db "Residents: ", 0
s_jobs      db "Jobs: ", 0
s_power_ok  db 128, " Powered", 0
s_power_no  db 128, " No power!", 0
s_water_ok  db 129, " Water", 0
s_water_no  db 129, " No water", 0
s_sew_ok    db "Sewage ok", 0
s_sew_no    db "No sewage!", 0
s_road_ok   db "Road access", 0
s_road_no   db "No road nearby!", 0
s_happiness db "Happiness", 0
s_landval   db "Land value", 0
s_pollution db "Pollution", 0
s_noise     db "Noise", 0
s_crime     db "Crime", 0
s_police    db "Police", 0
s_firecov   db "Fire safety", 0
s_healthc   db "Health", 0
s_educ      db "Education", 0
s_garb      db "Garbage", 0
s_goods     db "Goods stock", 0
s_staff     db "Staffing", 0
s_traffic   db "Traffic", 0
s_jam       db "Congestion", 0
s_desire    db "Desirability", 0
s_burning   db "ON FIRE!", 0
s_fightfire db "Call fire department", 0
s_nofiredep db "Build a fire station first!", 0
s_abandoned db "Abandoned", 0
s_building  db "Under construction", 0
s_needs     db "Needs: ", 0
s_n_road    db "a road nearby", 0
s_n_power   db "electricity", 0
s_n_hwy     db "a road link to the highway", 0
s_n_water   db "water (pipes within 2 tiles)", 0
s_n_sewage  db "sewage treatment", 0
s_n_garbage db "garbage collection", 0
s_n_goods   db "goods deliveries", 0
s_n_workers db "more (educated) workers", 0
s_n_dirty   db "clean water", 0
s_n_value   db "land value / demand", 0
s_n_svc     db "police and fire cover", 0
s_n_edu     db "schools and health care", 0
s_n_uni     db "a university nearby", 0
s_n_max     db "fully grown", 0
s_upkeep    db "Upkeep ", 0
s_permonth  db "/mo", 0
s_produces  db "Output ", 0
s_radius    db "Service radius ", 0
s_vehicles  db "Vehicles ", 0
s_highway   db "Regional highway", 0
s_powerline db "Power line", 0
s_trees     db "Forest", 0
s_water_t   db "Water", 0
s_rubble    db "Rubble", 0
s_grass     db "Grassland", 0
s_bridge    db " bridge", 0
s_units     db " units", 0
s_pipe_here db "Water pipe underneath", 0
s_stop_here db "Bus stop", 0
s_x         db "x", 0
s_minus     db "-", 0
s_plus      db "+", 0
s_policies  db "POLICIES", 0
s_stats     db "CITY STATISTICS", 0
s_pcost     db "costs ", 0
s_free      db "free", 0

policy_names dq pn0, pn1, pn2, pn3, pn4, pn5, pn6, pn7
policy_desc  dq pd0, pd1, pd2, pd3, pd4, pd5, pd6, pd7
pn0 db "Smoke detectors", 0
pn1 db "Recycling", 0
pn2 db "Free public transport", 0
pn3 db "High-rise ban", 0
pn4 db "Encourage biking", 0
pn5 db "Industrial filters", 0
pn6 db "Education boost", 0
pn7 db "Parks & recreation", 0
pd0 db "Halves the chance of fires.", 0
pd1 db "25% less garbage.", 0
pd2 db "More bus riders, no fares.", 0
pd3 db "Dense zones stop at level 3.", 0
pd4 db "Fewer car trips.", 0
pd5 db "Industry pollutes much less.", 0
pd6 db "Schools reach further.", 0
pd7 db "Bigger parks, happier people.", 0

; statistics rows: label, value pointer, kind (0 number, 1 percent, 2 money)
st_rows:
    dq strow0, population, 0
    dq strow1, workers, 0
    dq strow2, unemployed, 0
    dq strow3, avg_edu, 3
    dq strow4, jobs, 0
    dq strow5, jobs+4, 0
    dq strow6, jobs+8, 0
    dq strow7, jobs+12, 0
    dq strow8, flow_pct, 1
    dq strow9, avg_commute, 4
    dq strow10, trips_ok, 0
    dq strow11, trips_failed, 0
    dq strow12, bus_riders, 0
    dq strow13, veh_count, 0
    dq strow14, garbage_total, 0
    dq strow15, landfill_used, 0
    dq strow16, cnt_abandon, 0
    dq strow17, avg_crime, 0
ST_ROWS equ 18
strow0  db "Population", 0
strow1  db "Workers", 0
strow2  db "Unemployed", 0
strow3  db "Education level", 0
strow4  db "Jobs: residential", 0
strow5  db "Jobs: commercial", 0
strow6  db "Jobs: industrial", 0
strow7  db "Jobs: office", 0
strow8  db "Traffic flow", 0
strow9  db "Average commute", 0
strow10 db "Trips completed", 0
strow11 db "Trips failed", 0
strow12 db "Bus riders / month", 0
strow13 db "Vehicles on roads", 0
strow14 db "Uncollected garbage", 0
strow15 db "Landfill used", 0
strow16 db "Abandoned buildings", 0
strow17 db "Average crime", 0
s_sec       db " s", 0

goal_text:
    dq g0, g1, g2, g3, g4, g5, g6, g7, g8, g9, g10, g11, g12, g13, g14, g15, g16, g17, g18, g19
goal_reward dd 500, 300, 800, 1000, 1000, 800, 1500, 2000, 1200, 1200, 1500, 2000, 2500, 3000, 3000, 5000, 5000, 20000, 50000, 0
g0  db "Build a road connected to the highway", 0
g1  db "Zone 6 residential lots", 0
g2  db "Build a power plant and light up a home", 0
g3  db "Reach 100 residents", 0
g4  db "Pump water to homes through pipes", 0
g5  db "Drain sewage with a sewage outlet", 0
g6  db "Build a police and a fire station", 0
g7  db "Reach 500 residents", 0
g8  db "Collect garbage with a landfill", 0
g9  db "Build an elementary school", 0
g10 db "Provide 150 shop jobs", 0
g11 db "Run buses: a depot and 2+ bus stops", 0
g12 db "Grow offices to 200 jobs", 0
g13 db "Reach 1,500 residents at 60% happiness", 0
g14 db "Build a hospital or university", 0
g15 db "Reach 5,000 residents", 0
g16 db "Keep traffic flow above 80% at 5,000 people", 0
g17 db "Build the Asm Tower", 0
g18 db "Megalopolis: reach 15,000 residents", 0
g19 db "All goals done - keep building!", 0
GOAL_COUNT equ 19

; problem icons: glyph and colour per PR_*
prob_glyph  db 0, 128, 129, 129, 137, 138, 132, '!', '?', 129, '?'
prob_col    db 0, UI_WARN, UI_ACCENT, RAMP(R_WOOD,5), RAMP(R_ZONER,6), RAMP(R_ORANGE,6), UI_TEXT, UI_BAD, UI_BAD, RAMP(R_WOOD,4), UI_WARN

; icon colour keys
icon_keys   db "kwgdrRyYobBcGhnNpsal"
icon_cols   db UI_BLACK, UI_TEXT, RAMP(R_GREY,5), RAMP(R_GREY,2), RAMP(R_RED,5), RAMP(R_RED,3)
            db RAMP(R_YELLOW,6), RAMP(R_YELLOW,4), RAMP(R_ORANGE,5), RAMP(R_BLUE,5), RAMP(R_BLUE,3)
            db RAMP(R_GLASS,6), RAMP(R_ZONER,5), RAMP(R_ZONER,3), RAMP(R_WOOD,4), RAMP(R_WOOD,2)
            db RAMP(R_PURPLE,5), RAMP(R_SKIN,5), RAMP(R_ASPHALT,3), RAMP(R_GRASS,6)
ICON_KEYS equ 20


section .text

FUNC ui_init
    xor ebx, ebx
.px:
    cmp ebx, ICON_COUNT*256
    jge .dd
    mov al, [icon_art+rbx]
    xor ecx, ecx
    xor edx, edx
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
    mov dword [zone_type], ZONE_R
    RETURN


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
    cmp eax, T_PIPE
    je .line
    cmp eax, T_INSPECT
    je .single
    cmp eax, T_BUILD
    je .single
    cmp eax, T_BUSSTOP
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
save_magic db "CSAVv002"
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

; =====================================================================
;  info view chosen by the current tool (Cities: Skylines style)
; =====================================================================
FUNC compute_eff_overlay
    mov eax, [overlay_mode]
    test eax, eax
    jnz .set
    ; an open build menu previews its view
    mov ecx, [submenu]
    cmp ecx, -1
    je .tool
    mov eax, [submenu_view+rcx*4]
    test eax, eax
    jnz .set
.tool:
    xor eax, eax
    cmp dword [welcome], 0
    jne .set
    mov ecx, [tool]
    cmp ecx, T_POWERLN
    jne .t1
    mov eax, OV_POWER
    jmp .set
.t1:
    cmp ecx, T_PIPE
    jne .t2
    mov eax, OV_WATER
    jmp .set
.t2:
    cmp ecx, T_ROAD
    jne .t3
    mov eax, OV_TRAFFIC
    jmp .set
.t3:
    cmp ecx, T_BUSSTOP
    jne .t4
    mov eax, OV_TRANSIT
    jmp .set
.t4:
    cmp ecx, T_TREE
    jne .t5
    mov eax, OV_POLLUTE
    jmp .set
.t5:
    cmp ecx, T_ZONETOOL
    jne .t6
    mov ecx, [zone_type]
    movzx eax, byte [zone_class+rcx]
    add eax, OV_DESIRE_R
    jmp .set
.t6:
    cmp ecx, T_BUILD
    jne .set
    mov edi, [build_kind]
    call bld_rec
    movzx ecx, byte [rax+BI_CATEGORY]
    movzx eax, byte [cat_view+rcx]
    cmp ecx, CAT_SAFETY
    jne .set
    mov eax, OV_POLICE
    cmp dword [build_kind], BK_FIRE
    jne .set
    mov eax, OV_FIRE
.set:
    mov [eff_overlay], eax
    RETURN
section .data
cat_view db OV_POWER, OV_WATER, OV_GARBAGE, OV_POLICE, OV_HEALTH, OV_EDU, OV_TRANSIT, OV_LANDVAL
section .text

; =====================================================================
;  tools
; =====================================================================
; is the current tool a line tool / single click tool?
tool_is_line:
    mov eax, [tool]
    cmp eax, T_ROAD
    je .y
    cmp eax, T_POWERLN
    je .y
    cmp eax, T_PIPE
    je .y
    xor eax, eax
    ret
.y: mov eax, 1
    ret
tool_is_click:
    mov eax, [tool]
    cmp eax, T_INSPECT
    je .y
    cmp eax, T_BUILD
    je .y
    cmp eax, T_BUSSTOP
    je .y
    xor eax, eax
    ret
.y: mov eax, 1
    ret

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
    xor r13d, r13d
    movzx ecx, byte [r12+T_OBJ]
    movzx edx, byte [r12+T_TERRAIN]
    mov eax, [tool]
    cmp eax, T_ROAD
    jne .t1
    mov r8d, [road_type]
    mov r13d, [road_costs+r8*4]
    cmp ecx, OBJ_ROAD
    jne .rnew
    ; upgrade / downgrade an existing road
    test byte [r12+T_FLAGS], F_HIGHWAY
    jnz .n
    cmp [r12+T_ROADTYPE], r8b
    je .n
    jmp .rw
.rnew:
    cmp ecx, OBJ_NONE
    je .rw
    cmp ecx, OBJ_TREE
    je .rw
    cmp ecx, OBJ_RUBBLE
    jne .n
.rw:
    cmp edx, TER_WATER
    jne .set
    imul r13d, r13d, 3              ; bridges
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
    cmp eax, T_ZONETOOL
    jne .t3
    cmp edx, TER_WATER
    je .n
    cmp ecx, OBJ_NONE
    je .zok
    cmp ecx, OBJ_TREE
    jne .n
.zok:
    mov eax, [zone_type]
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
    mov r13d, 0
    jmp .set
.t4:
    cmp eax, T_BULLDOZE
    jne .t5
    test byte [r12+T_FLAGS], F_HIGHWAY
    jnz .n
    cmp ecx, OBJ_NONE
    jne .bz
    ; empty tiles: dig up pipes
    test byte [r12+T_FLAGS2], F2_PIPE
    jz .n
    mov r13d, 2
    jmp .set
.bz:
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
    jne .t6
    cmp ecx, OBJ_NONE
    jne .n
    cmp edx, TER_WATER
    je .n
    cmp byte [r12+T_ZONE], 0
    jne .n
    mov r13d, 3
    jmp .set
.t6:
    cmp eax, T_PIPE
    jne .t7
    cmp edx, TER_WATER
    je .n
    test byte [r12+T_FLAGS2], F2_PIPE
    jnz .n
    mov r13d, 5
    jmp .set
.t7:
    cmp eax, T_BUSSTOP
    jne .n
    cmp ecx, OBJ_ROAD
    jne .n
    cmp byte [r12+T_ROADTYPE], RT_HIGHWAY
    je .n
    test byte [r12+T_FLAGS2], F2_BUSSTOP
    jnz .n
    mov r13d, 60
.set:
    mov byte [tl_ok+rbx], 1
    inc dword [tl_valid]
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
    mov eax, [r15+BI_UNLOCK]
    cmp [population], eax
    jge .unl
    mov dword [last_tool_err], 1
    jmp .out
.unl:
    mov r12d, [tl_x]
    mov r13d, [tl_y]
    xor ebx, ebx
    mov dword [rbp-48], 0
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
    cmp byte [r15+BI_NEEDWATER], 0
    je .bok
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
    cmp dword [force_place], 0
    jne .forced
    call tool_evaluate
.forced:
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
    and byte [r12+T_FLAGS], F_HIGHWAY
    mov byte [r12+T_LEVEL], 0
    mov word [r12+T_POP], 0
    mov eax, [road_type]
    mov [r12+T_ROADTYPE], al
    mov dword [r12+T_OCC], 0
    mov byte [r12+T_PROBLEM], 0
    jmp .upd
.a1:
    cmp eax, T_POWERLN
    jne .a2
    mov byte [r12+T_OBJ], OBJ_POWER
    mov byte [r12+T_ZONE], 0
    mov byte [r12+T_FLAGS], 0
    jmp .upd
.a2:
    cmp eax, T_ZONETOOL
    jne .a3
    mov eax, [zone_type]
    mov [r12+T_ZONE], al
    mov byte [r12+T_OBJ], OBJ_NONE
    mov byte [r12+T_LEVEL], 0
    mov byte [r12+T_HAPPY], 0
    and byte [r12+T_FLAGS], ~F_ANCHOR
    jmp .upd
.a3:
    cmp eax, T_DEZONE
    jne .a4
    mov byte [r12+T_ZONE], 0
    jmp .upd
.a4:
    cmp eax, T_BULLDOZE
    jne .a5
    mov cl, [r12+T_OBJ]
    cmp cl, OBJ_NONE
    jne .bz0
    and byte [r12+T_FLAGS2], ~F2_PIPE
    jmp .upd
.bz0:
    cmp cl, OBJ_SERVICE
    je .bzm
    cmp cl, OBJ_ZONEBLD
    jne .bz
.bzm:
    mov edi, r13d
    mov esi, r14d
    call destroy_to_rubble
    jmp .upd
.bz:
    mov byte [r12+T_OBJ], OBJ_NONE
    and byte [r12+T_FLAGS], 0
    and byte [r12+T_FLAGS2], F2_PIPE
    mov byte [r12+T_LEVEL], 0
    mov word [r12+T_POP], 0
    mov dword [r12+T_OCC], 0
    jmp .upd
.a5:
    cmp eax, T_TREE
    jne .a6
    mov byte [r12+T_OBJ], OBJ_TREE
    call rand
    and eax, 3
    mov [r12+T_SUB], al
    call rand
    mov [r12+T_VARIANT], al
    jmp .upd
.a6:
    cmp eax, T_PIPE
    jne .a7
    or byte [r12+T_FLAGS2], F2_PIPE
    jmp .n                          ; pipes are underground: no dust
.a7:
    cmp eax, T_BUSSTOP
    jne .upd
    or byte [r12+T_FLAGS2], F2_BUSSTOP
.upd:
    mov edi, r13d
    mov esi, r14d
    call roads_update_around
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
    cmp eax, T_PIPE
    je .play
    mov edi, SFX_BULLDOZE
    cmp eax, T_BULLDOZE
    je .play
    mov edi, SFX_PLACE
    cmp eax, T_BUSSTOP
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
    mov byte [rax+T_PROBLEM], 0
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
    call networks_update
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

; ---------------------------------------------------------------------
;  world-side preview of the current tool (drawn into the world fb)
; ---------------------------------------------------------------------
FUNC draw_tool_preview, 16
    call set_target_world
    cmp dword [ui_captured], 0
    jne .sel
    cmp dword [welcome], 0
    jne .out
    cmp dword [tool], T_INSPECT
    jne .tools
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
    mov r12d, [tl_x+rbx*4]
    mov r13d, [tl_y+rbx*4]
    mov edi, r12d
    mov esi, r13d
    call tile_at
    test rax, rax
    jz .n
    mov ecx, RAMP(R_RED, 6)
    cmp byte [tl_ok+rbx], 0
    je .dia
    mov eax, [tool]
    cmp eax, T_ROAD
    jne .gz
    mov edi, r12d
    mov esi, r13d
    call preview_road_mask
    mov ecx, [road_type]
    shl ecx, 4
    add eax, ecx
    mov edi, [spr_road+rax*4]
    jmp .ghost
.gz:
    cmp eax, T_ZONETOOL
    jne .gd
    mov eax, [zone_type]
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
    mov rdi, rax
    call footprint_size
    mov edx, eax
    mov edi, [sel_x]
    mov esi, [sel_y]
    mov ecx, RAMP(R_YELLOW, 7)
    call draw_diamond
.out:
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
    mov dword [submenu], -1
    mov eax, [tool]
    cmp eax, T_INSPECT
    je .inspect
    call tool_is_click
    test eax, eax
    jnz .click
    mov eax, [hover_tx]
    mov [drag_sx], eax
    mov eax, [hover_ty]
    mov [drag_sy], eax
    mov dword [drag_active], 1
    jmp .out
.inspect:
    mov edi, [hover_tx]
    mov esi, [hover_ty]
    call anchor_of
    mov [sel_x], eax
    mov [sel_y], edx
    mov edi, SFX_CLICK
    call sfx_play
    jmp .out
.click:
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
;  HUD
; =====================================================================
FUNC draw_topbar, 16
    xor edi, edi
    xor esi, esi
    mov edx, [ui_w]
    mov ecx, 18
    call draw_panel
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
    ; money counts toward the real value
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
    mov edi, 148
    mov esi, 5
    mov ecx, UI_GOLD
    cmp qword [money], 0
    jge .mc
    mov ecx, UI_BAD
.mc:
    call tb_draw
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
    mov edi, 148
    mov esi, 20
    mov ecx, UI_GOOD
    cmp dword [cash_delta], 0
    jge .dc
    mov ecx, UI_BAD
.dc:
    call tb_draw
.nd:
    call tb_reset
    lea rdi, [s_pop]
    call tb_str
    movsxd rdi, dword [population]
    call tb_num
    mov edi, 222
    mov esi, 5
    mov ecx, UI_TEXT
    call tb_draw
    ; RCIO demand bars
    mov r12d, 284
    mov edi, r12d
    mov esi, 5
    lea rdx, [s_rcio]
    mov ecx, UI_DIM
    call draw_text
    xor ebx, ebx
.rci:
    mov r13d, [demand+rbx*4]
    lea edi, [rbx*4+rbx]
    add edi, r12d
    add edi, 38
    mov esi, 9
    mov edx, 4
    mov ecx, 1
    mov r8d, UI_DIM
    call fill_rect
    mov eax, r13d
    CLAMP eax, -100, 100
    cdq
    mov ecx, 14
    idiv ecx
    lea edi, [rbx*4+rbx]
    add edi, r12d
    add edi, 38
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
    cmp ebx, 4
    jl .rci
    ; happiness
    call tb_reset
    lea rdi, [s_happy]
    call tb_str
    movsxd rdi, dword [happy_avg]
    call tb_pct
    mov edi, 350
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
    ; traffic flow
    call tb_reset
    lea rdi, [s_car]
    call tb_str
    movsxd rdi, dword [flow_pct]
    call tb_pct
    mov edi, 390
    mov esi, 5
    mov ecx, UI_GOOD
    cmp dword [flow_pct], 75
    jge .fc
    mov ecx, UI_WARN
    cmp dword [flow_pct], 50
    jge .fc
    mov ecx, UI_BAD
.fc:
    call tb_draw
    lea r12d, [rax+8]
    ; power and water: use as a share of supply
    lea rdi, [s_bolt]
    mov esi, [power_demand]
    mov edx, [power_supply]
    mov ecx, r12d
    mov r8d, UI_GOOD
    call hud_usage
    lea r12d, [rax+8]
    lea rdi, [s_drop]
    mov esi, [water_demand]
    mov edx, [water_supply]
    mov ecx, r12d
    mov r8d, UI_ACCENT
    call hud_usage
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
; hud_usage(rdi glyph str, esi used, edx supply, ecx x, r8d ok colour) -> eax end x
FUNC hud_usage
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d
    call tb_reset
    call tb_str
    ; percent of capacity in use
    mov eax, r12d
    imul eax, 100
    xor edx, edx
    test r13d, r13d
    jz .zero
    div r13d
    jmp .p
.zero:
    xor eax, eax
    test r12d, r12d
    jz .p
    mov eax, 999
.p:
    mov ebx, eax
    movsxd rdi, eax
    call tb_pct
    mov ecx, r15d
    cmp ebx, 90
    jl .c
    mov ecx, UI_WARN
    cmp ebx, 100
    jle .c
    mov ecx, UI_BAD
.c:
    mov edi, r14d
    mov esi, 5
    call tb_draw
    RETURN

section .data
rci_cols db UI_GOOD, UI_ACCENT, UI_WARN, RAMP(R_TEAL,6)
section .text

; ---------------------------------------------------------------------
FUNC draw_dock, 32
    mov eax, DOCK_COUNT
    imul eax, DOCK_BTN+2
    add eax, 8
    mov r14d, eax
    mov r12d, [ui_w]
    sub r12d, eax
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, DOCK_BTN+8
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
    lea r15d, [r12+rax+4]
    mov [rbp-48], r15d
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
    jmp .sb
.pn:
    sub eax, 199
    cmp eax, [panel]
    sete r8b
.sb:
    mov edi, r15d
    lea esi, [r13+3]
    mov edx, DOCK_BTN
    mov ecx, DOCK_BTN
    call button
    mov [rbp-52], eax
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
    cmp dword [drag_active], 0
    je .out
    call tb_reset
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

; name, cost and lock state of a submenu item (edi code) into registers:
; -> rax name ptr, edx cost, ecx unlock population, r8d is-per-tile
FUNC submenu_item_info
    mov ebx, edi
    xor r8d, r8d
    cmp ebx, SI_OVERLAY
    jl .t
    lea eax, [rbx-SI_OVERLAY]
    mov rax, [overlay_names+rax*8]
    xor edx, edx
    xor ecx, ecx
    RETURN
.t:
    cmp ebx, SI_STREET
    jl .b
    mov r8d, 1
    xor ecx, ecx
    cmp ebx, SI_BUSSTOP
    jg .z
    lea eax, [rbx-SI_STREET]
    mov edx, 60
    cmp ebx, SI_BUSSTOP
    je .ts
    mov edx, [road_costs+rax*4]
.ts:
    mov rax, [tool_item_names+rax*8]
    RETURN
.z:
    cmp ebx, SI_DEZONE
    jg .u
    mov edx, 5
    lea rax, [ti_dezone]
    je .zz
    lea eax, [rbx-SI_ZONE]
    mov rax, [zone_names+rax*8]
.zz:
    RETURN
.u:
    mov edx, 5
    lea rax, [ti_line]
    cmp ebx, SI_POWERLN
    je .uu
    lea rax, [ti_pipe]
.uu:
    RETURN
.b:
    mov edi, ebx
    call bld_rec
    mov edx, [rax+BI_COST]
    mov ecx, [rax+BI_UNLOCK]
    mov rax, [rax+BI_NAME]
    RETURN

; choose a submenu item (edi code)
FUNC submenu_select
    mov ebx, edi
    mov dword [drag_active], 0
    cmp ebx, SI_OVERLAY
    jl .t
    lea eax, [rbx-SI_OVERLAY]
    mov [overlay_mode], eax
    jmp .close
.t:
    cmp ebx, SI_STREET
    jl .b
    cmp ebx, SI_HIGHWAY
    jg .s
    lea eax, [rbx-SI_STREET]
    mov [road_type], eax
    mov dword [tool], T_ROAD
    jmp .close
.s:
    cmp ebx, SI_BUSSTOP
    jne .z
    mov dword [tool], T_BUSSTOP
    jmp .close
.z:
    cmp ebx, SI_DEZONE
    jne .z2
    mov dword [tool], T_DEZONE
    jmp .close
.z2:
    cmp ebx, SI_POWERLN
    jge .u
    lea eax, [rbx-SI_ZONE]
    mov [zone_type], eax
    mov dword [tool], T_ZONETOOL
    jmp .close
.u:
    mov dword [tool], T_POWERLN
    cmp ebx, SI_POWERLN
    je .close
    mov dword [tool], T_PIPE
    jmp .close
.b:
    mov [build_kind], ebx
    mov dword [tool], T_BUILD
.close:
    mov dword [submenu], -1
    RETURN

; is a submenu item the active choice?
FUNC submenu_is_active
    xor eax, eax
    mov ebx, edi
    cmp ebx, SI_OVERLAY
    jl .t
    lea ecx, [rbx-SI_OVERLAY]
    cmp ecx, [overlay_mode]
    sete al
    RETURN
.t:
    cmp ebx, SI_STREET
    jl .b
    cmp ebx, SI_HIGHWAY
    jg .s
    cmp dword [tool], T_ROAD
    jne .o
    lea ecx, [rbx-SI_STREET]
    cmp ecx, [road_type]
    sete al
    RETURN
.s:
    cmp ebx, SI_BUSSTOP
    jne .z
    cmp dword [tool], T_BUSSTOP
    sete al
    RETURN
.z:
    cmp ebx, SI_DEZONE
    jne .z2
    cmp dword [tool], T_DEZONE
    sete al
    RETURN
.z2:
    cmp ebx, SI_POWERLN
    jge .u
    cmp dword [tool], T_ZONETOOL
    jne .o
    lea ecx, [rbx-SI_ZONE]
    cmp ecx, [zone_type]
    sete al
    RETURN
.u:
    cmp ebx, SI_POWERLN
    jne .p
    cmp dword [tool], T_POWERLN
    sete al
    RETURN
.p:
    cmp dword [tool], T_PIPE
    sete al
    RETURN
.b:
    cmp dword [tool], T_BUILD
    jne .o
    cmp ebx, [build_kind]
    sete al
.o:
    RETURN

FUNC draw_submenu, 48
    mov eax, [submenu]
    cmp eax, -1
    je .out
    mov r15, [submenu_lists+rax*8]
    xor ecx, ecx
.cnt:
    cmp dword [r15+rcx*4], -1
    je .cd
    inc ecx
    jmp .cnt
.cd:
    mov [rbp-48], ecx
    imul eax, ecx, 17
    add eax, 6
    mov [rbp-52], eax
    mov r12d, [submenu_x]
    sub r12d, 80
    CLAMP r12d, 4, 10000
    mov eax, [ui_w]
    sub eax, 204
    cmp r12d, eax
    jle .xo
    mov r12d, eax
.xo:
    mov r13d, [ui_h]
    sub r13d, DOCK_BTN+12
    sub r13d, [rbp-52]
    mov edi, r12d
    mov esi, r13d
    mov edx, 200
    mov ecx, [rbp-52]
    call draw_panel
    xor ebx, ebx
.i:
    cmp ebx, [rbp-48]
    jge .out
    mov r14d, [r15+rbx*4]
    imul eax, ebx, 17
    lea esi, [r13+rax+3]
    mov [rbp-56], esi
    mov edi, r14d
    call submenu_is_active
    mov r8d, eax
    lea edi, [r12+3]
    mov esi, [rbp-56]
    mov edx, 194
    mov ecx, 15
    call button
    test eax, eax
    jz .draw
    mov edi, r14d
    call submenu_select
    jmp .out
.draw:
    mov edi, r14d
    call submenu_item_info
    mov [rbp-64], rax
    mov [rbp-68], edx
    mov [rbp-72], ecx
    mov [rbp-76], r8d
    lea edi, [r12+8]
    mov esi, [rbp-56]
    add esi, 4
    mov rdx, [rbp-64]
    mov ecx, UI_TEXT
    mov eax, [rbp-72]
    cmp [population], eax
    jge .nm
    mov ecx, UI_DIM
.nm:
    call draw_text
    cmp r14d, SI_OVERLAY
    jge .in
    call tb_reset
    mov eax, [rbp-72]
    cmp [population], eax
    jge .cost
    mov edi, 132
    call tb_char
    movsxd rdi, dword [rbp-72]
    call tb_num
    lea edi, [r12+196]
    mov esi, [rbp-56]
    add esi, 4
    lea rdx, [textbuf]
    mov ecx, UI_BAD
    call draw_text_right
    jmp .in
.cost:
    movsxd rdi, dword [rbp-68]
    call tb_money
    cmp dword [rbp-76], 0
    je .cs
    lea rdi, [ti_tile]
    call tb_str
.cs:
    lea edi, [r12+196]
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
; one text line at row_y (rdx text, ecx colour)
row_text:
    mov edi, [row_x]
    add edi, 6
    mov esi, [row_y]
    add dword [row_y], 11
    jmp draw_text

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
    mov r15d, eax
    mov r12d, 4
    mov r13d, 42
    mov [row_x], r12d
    mov edi, r12d
    mov esi, r13d
    sub esi, 4
    mov edx, 184
    mov ecx, 250
    call draw_panel
    lea edi, [r12+170]
    mov esi, r13d
    mov edx, 10
    mov ecx, 10
    call ui_hit
    test eax, eax
    jz .nc
    mov dword [sel_x], -1
    jmp .out
.nc:
    lea edi, [r12+172]
    mov esi, r13d
    lea rdx, [s_x]
    mov ecx, UI_DIM
    call draw_text
    mov [row_y], r13d
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
    cmp eax, OBJ_ROAD
    jne .tpl
    lea rdi, [s_highway]
    test byte [rbx+T_FLAGS], F_HIGHWAY
    jnz .tr1
    movzx ecx, byte [rbx+T_ROADTYPE]
    CLAMP ecx, 0, 2
    mov rdi, [road_names+rcx*8]
.tr1:
    call tb_str
    cmp byte [rbx+T_TERRAIN], TER_WATER
    jne .tdraw
    lea rdi, [s_bridge]
    call tb_str
    jmp .tdraw
.tpl:
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
    mov esi, [row_y]
    mov ecx, UI_GOLD
    call tb_draw
    add dword [row_y], 13

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
    ; level / state line
    call tb_reset
    movzx eax, byte [rbx+T_LEVEL]
    cmp byte [rbx+T_OBJ], OBJ_NONE
    jne .lv
    xor eax, eax
.lv:
    CLAMP eax, 0, 5
    mov rdi, [lvl_names+rax*8]
    call tb_str
    cmp byte [rbx+T_ZONE], ZONE_I
    jne .nsp
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .nsp
    mov edi, ' '
    call tb_char
    movzx eax, byte [rbx+T_SUB]
    CLAMP eax, 0, 3
    mov rdi, [spec_names+rax*8]
    call tb_str
.nsp:
    lea rdx, [textbuf]
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
    call row_text
    ; residents / jobs
    call tb_reset
    lea rdi, [s_residents]
    movzx eax, byte [rbx+T_ZONE]
    cmp byte [zone_class+rax], ZC_RES
    je .rj
    lea rdi, [s_jobs]
.rj:
    call tb_str
    movzx edi, word [rbx+T_POP]
    call tb_num
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
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
    lea edi, [r12+96]
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
    lea rdx, [s_sew_ok]
    mov ecx, UI_GOOD
    test byte [rbx+T_FLAGS2], F2_SEWAGE
    jnz .sw
    lea rdx, [s_sew_no]
    mov ecx, UI_DIM
.sw:
    lea edi, [r12+96]
    mov esi, [row_y]
    call draw_text
    add dword [row_y], 12
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
    lea rdi, [s_garb]
    movzx esi, byte [rbx+T_GARBAGE]
    mov edx, RAMP(R_ZONER,6)
    call stat_row
    movzx eax, byte [rbx+T_ZONE]
    movzx eax, byte [zone_class+rax]
    cmp eax, ZC_RES
    jne .jobz
    lea rdi, [s_educ]
    movzx esi, byte [rbx+T_EDU]
    mov edx, UI_ACCENT
    call stat_row
    jmp .hint
.jobz:
    lea rdi, [s_staff]
    movzx esi, byte [rbx+T_WORKERS]
    mov edx, UI_TEXT
    call stat_row
    cmp eax, ZC_COM
    jne .hint
    lea rdi, [s_goods]
    movzx esi, byte [rbx+T_GOODS]
    mov edx, RAMP(R_ORANGE,6)
    call stat_row
.hint:
    call growth_hint
    test rax, rax
    jz .maps
    mov r14, rax
    call tb_reset
    lea rdi, [s_needs]
    call tb_str
    mov rdi, r14
    call tb_str
    lea rdx, [textbuf]
    mov ecx, UI_WARN
    call row_text
    jmp .maps

.svc:
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
    call row_text
    mov rdx, [r14+BI_DESC]
    mov ecx, UI_DIM
    call row_text
    call tb_reset
    lea rdi, [s_upkeep]
    call tb_str
    movsxd rdi, dword [r14+BI_UPKEEP]
    call tb_money
    lea rdi, [s_permonth]
    call tb_str
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
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
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
.srad:
    movzx eax, byte [r14+BI_RADIUS]
    test eax, eax
    jz .sveh
    call tb_reset
    lea rdi, [s_radius]
    call tb_str
    movzx edi, byte [r14+BI_RADIUS]
    call tb_num
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
.sveh:
    movzx eax, byte [r14+BI_VEHICLES]
    test eax, eax
    jz .maps
    call tb_reset
    lea rdi, [s_vehicles]
    call tb_str
    mov edi, r15d
    call count_home
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_slash]
    call tb_str
    movzx edi, byte [r14+BI_VEHICLES]
    call tb_num
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
    jmp .maps
.road:
    lea rdi, [s_traffic]
    movzx esi, byte [rbx+T_TRAFFIC]
    mov edx, UI_WARN
    call stat_row
    lea rdi, [s_jam]
    movzx esi, byte [rbx+T_JAM]
    mov edx, UI_BAD
    call stat_row
    test byte [rbx+T_FLAGS2], F2_BUSSTOP
    jz .maps
    lea rdx, [s_stop_here]
    mov ecx, UI_ACCENT
    call row_text
.maps:
    test byte [rbx+T_FLAGS2], F2_PIPE
    jz .np
    lea rdx, [s_pipe_here]
    mov ecx, UI_ACCENT
    call row_text
.np:
    add dword [row_y], 2
    lea rdi, [s_landval]
    movzx esi, byte [map_lv+r15]
    mov edx, UI_GOLD
    call stat_row
    lea rdi, [s_pollution]
    movzx esi, byte [map_pol+r15]
    mov edx, UI_BAD
    call stat_row
    lea rdi, [s_noise]
    movzx esi, byte [map_noise+r15]
    mov edx, UI_WARN
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
    test byte [rbx+T_FLAGS], F_FIRE
    jz .out
    lea rdx, [s_burning]
    mov ecx, UI_BAD
    call row_text
    mov edi, [row_x]
    add edi, 6
    mov esi, [row_y]
    mov edx, 170
    lea rcx, [s_fightfire]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .out
    mov dword [fight_request], 1
.out:
    cmp dword [fight_request], 0
    je .o2
    mov dword [fight_request], 0
    call fight_fire
.o2:
    RETURN
section .bss
fight_request resd 1
section .text

; why a zone tile is not growing -> rax string or 0  (rbx tile, r15d index)
FUNC growth_hint
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
    movzx edx, byte [rbx+T_ZONE]
    movzx edx, byte [zone_class+rdx]
    mov [gh_class], edx
    cmp edx, ZC_COM
    je .hw
    cmp edx, ZC_OFF
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
    lea rax, [s_n_sewage]
    test byte [rbx+T_FLAGS2], F2_SEWAGE
    jz .o
    cmp ecx, 2
    jl .val
    lea rax, [s_n_garbage]
    test byte [rbx+T_FLAGS2], F2_GARBAGE
    jnz .o
    lea rax, [s_n_goods]
    test byte [rbx+T_FLAGS2], F2_NOGOODS
    jnz .o
    lea rax, [s_n_workers]
    test byte [rbx+T_FLAGS2], F2_NOWORKERS
    jnz .o
    lea rax, [s_n_dirty]
    test byte [rbx+T_FLAGS2], F2_DIRTY
    jnz .o
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
    cmp dword [gh_class], ZC_RES
    jne .l5
    lea rax, [s_n_edu]
    movzx edx, byte [map_high+r15]
    cmp edx, 30
    jl .o
    jmp .val
.l5:
    lea rax, [s_n_uni]
    movzx edx, byte [map_uni+r15]
    cmp edx, 30
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
section .bss
gh_class resd 1
section .text

; ---------------------------------------------------------------------
;  budget panel with per-class taxes
; ---------------------------------------------------------------------
%macro BROW 3   ; label, value dword, colour
    lea rdx, [%1]
    lea edi, [r12+14]
    mov esi, r13d
    mov ecx, UI_DIM
    call draw_text
    call tb_reset
    movsxd rdi, dword [%2]
    call tb_money
    lea edi, [r12+160]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, %3
    call draw_text_right
    add r13d, 11
%endmacro

FUNC draw_budget, 32
    mov r12d, [ui_w]
    sub r12d, 350
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, 244
    shr r13d, 1
    mov [rbp-48], r13d
    mov edi, r12d
    mov esi, r13d
    mov edx, 350
    mov ecx, 226
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 350
    mov ecx, 226
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_budget]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    add r13d, 28
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [s_taxes]
    mov ecx, UI_TEXT
    call draw_text
    add r13d, 12
    ; four tax rows
    xor ebx, ebx
.tx:
    mov rdx, [s_classn+rbx*8]
    lea edi, [r12+14]
    mov esi, r13d
    mov ecx, UI_DIM
    call draw_text
    lea edi, [r12+90]
    lea esi, [r13-3]
    mov edx, 14
    lea rcx, [s_minus]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .t1
    cmp dword [tax_rate+rbx*4], 0
    jle .t1
    dec dword [tax_rate+rbx*4]
.t1:
    lea edi, [r12+140]
    lea esi, [r13-3]
    mov edx, 14
    lea rcx, [s_plus]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .t2
    cmp dword [tax_rate+rbx*4], 25
    jge .t2
    inc dword [tax_rate+rbx*4]
.t2:
    call tb_reset
    movsxd rdi, dword [tax_rate+rbx*4]
    call tb_pct
    lea edi, [r12+122]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text_centered
    add r13d, 14
    inc ebx
    cmp ebx, 4
    jl .tx
    add r13d, 2
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [s_income]
    mov ecx, UI_TEXT
    call draw_text
    call tb_reset
    movsxd rdi, dword [income_last]
    call tb_money
    lea edi, [r12+160]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_GOOD
    call draw_text_right
    add r13d, 11
    BROW s_other, inc_other, UI_GOOD
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [s_expense]
    mov ecx, UI_TEXT
    call draw_text
    add r13d, 11
    BROW s_roads, exp_roads, UI_BAD
    BROW s_services, exp_services, UI_BAD
    BROW s_policiesx, exp_policies, UI_BAD
    mov eax, [income_last]
    sub eax, [expense_last]
    mov [budget_net], eax
    mov ecx, UI_GOOD
    test eax, eax
    jns .ng
    mov ecx, UI_BAD
.ng:
    mov [rbp-52], ecx
    add r13d, 2
    lea rdx, [s_net]
    lea edi, [r12+10]
    mov esi, r13d
    mov ecx, UI_TEXT
    call draw_text
    call tb_reset
    movsxd rdi, dword [budget_net]
    call tb_money
    lea edi, [r12+160]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, [rbp-52]
    call draw_text_right
    mov r13d, [rbp-48]
    add r13d, 30
    lea edi, [r12+180]
    mov esi, r13d
    lea rdx, [s_pophist]
    mov ecx, UI_TEXT
    call draw_text
    lea edi, [r12+180]
    lea esi, [r13+12]
    lea rdx, [hist_pop]
    mov ecx, UI_GOOD
    call draw_chart
    lea edi, [r12+180]
    lea esi, [r13+76]
    lea rdx, [s_cashhist]
    mov ecx, UI_TEXT
    call draw_text
    lea edi, [r12+180]
    lea esi, [r13+88]
    lea rdx, [hist_money]
    mov ecx, UI_GOLD
    call draw_chart
    RETURN

; ---------------------------------------------------------------------
;  policies panel
; ---------------------------------------------------------------------
FUNC draw_policies, 16
    mov r12d, [ui_w]
    sub r12d, 330
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, 250
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, 330
    mov ecx, 230
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 330
    mov ecx, 230
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_policies]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    add r13d, 30
    xor ebx, ebx
.p:
    xor r8d, r8d
    bt dword [policies], ebx
    setc r8b
    lea edi, [r12+10]
    mov esi, r13d
    mov edx, 310
    mov ecx, 23
    call button
    test eax, eax
    jz .d
    btc dword [policies], ebx
    mov dword [cov_dirty], 1
.d:
    mov rdx, [policy_names+rbx*8]
    lea edi, [r12+16]
    lea esi, [r13+3]
    mov ecx, UI_TEXT
    call draw_text
    mov rdx, [policy_desc+rbx*8]
    lea edi, [r12+16]
    lea esi, [r13+13]
    mov ecx, UI_DIM
    call draw_text
    ; monthly cost
    call tb_reset
    mov ecx, [policy_cost_div+rbx*4]
    test ecx, ecx
    jnz .c
    lea rdi, [s_free]
    call tb_str
    jmp .cd
.c:
    mov eax, [population]
    xor edx, edx
    div ecx
    add eax, 10
    movsxd rdi, eax
    call tb_money
    lea rdi, [s_permonth]
    call tb_str
.cd:
    lea edi, [r12+314]
    lea esi, [r13+8]
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text_right
    add r13d, 25
    inc ebx
    cmp ebx, POLICY_COUNT
    jl .p
    RETURN

; ---------------------------------------------------------------------
;  statistics panel
; ---------------------------------------------------------------------
FUNC draw_stats, 16
    mov r12d, [ui_w]
    sub r12d, 260
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, 250
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, 260
    mov ecx, 236
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 260
    mov ecx, 236
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_stats]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    add r13d, 30
    xor ebx, ebx
.r:
    imul eax, ebx, 24
    lea r14, [st_rows+rax]
    mov rdx, [r14]
    lea edi, [r12+12]
    mov esi, r13d
    mov ecx, UI_DIM
    call draw_text
    call tb_reset
    mov rax, [r14+8]
    movsxd rdi, dword [rax]
    mov rax, [r14+16]
    cmp eax, 1
    jne .k2
    call tb_pct
    jmp .kd
.k2:
    cmp eax, 3
    jne .k3
    imul rdi, rdi, 100
    shr rdi, 8
    call tb_pct
    jmp .kd
.k3:
    cmp eax, 4
    jne .k4
    ; ticks -> seconds
    xor edx, edx
    mov rax, rdi
    mov ecx, 60
    div rcx
    mov rdi, rax
    call tb_num
    lea rdi, [s_sec]
    call tb_str
    jmp .kd
.k4:
    call tb_num
.kd:
    lea edi, [r12+248]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call draw_text_right
    add r13d, 11
    inc ebx
    cmp ebx, ST_ROWS
    jl .r
    RETURN

; ---------------------------------------------------------------------
;  info view legend
; ---------------------------------------------------------------------
FUNC draw_overlay_legend
    mov eax, [eff_overlay]
    test eax, eax
    jz .out
    mov rdi, [overlay_names+rax*8]
    mov r12, rdi
    mov r14, [ov_hint+rax*8]
    mov r13d, [ui_w]
    shr r13d, 1
    lea edi, [r13-90]
    mov esi, 38
    mov edx, 180
    mov ecx, 26
    call draw_panel
    mov edi, r13d
    mov esi, 41
    mov rdx, r12
    mov ecx, UI_TEXT
    call draw_text_centered
    test r14, r14
    jz .grad
    mov edi, r13d
    mov esi, 52
    mov rdx, r14
    mov ecx, UI_DIM
    call draw_text_centered
    jmp .out
.grad:
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

; ---------------------------------------------------------------------
;  problem icons above buildings (screen positions from the renderer)
; ---------------------------------------------------------------------
FUNC draw_problem_icons, 16
    xor ebx, ebx
.l:
    cmp ebx, [prob_n]
    jge .out
    mov eax, [prob_x+rbx*4]
    imul eax, [zoom]
    cdq
    idiv dword [ui_scale]
    mov r12d, eax
    mov eax, [prob_y+rbx*4]
    imul eax, [zoom]
    cdq
    idiv dword [ui_scale]
    mov r13d, eax
    ; gentle bob
    mov eax, [anim_tick]
    add eax, ebx
    shr eax, 4
    and eax, 1
    sub r13d, eax
    sub r13d, 10
    movzx r14d, byte [prob_t+rbx]
    ; bubble
    lea edi, [r12-5]
    mov esi, r13d
    mov edx, 11
    mov ecx, 11
    mov r8d, UI_BG2
    call draw_box
    movzx edx, byte [prob_glyph+r14]
    movzx ecx, byte [prob_col+r14]
    mov [rbp-48], edx
    mov edi, [rbp-48]
    call glyph_advance
    shr eax, 1
    mov edi, r12d
    sub edi, eax
    inc edi
    lea esi, [r13+2]
    mov edx, [rbp-48]
    movzx ecx, byte [prob_col+r14]
    call draw_glyph
    inc ebx
    jmp .l
.out:
    RETURN

; minimap colour for a tile (rdi tile) -> eax
minimap_colour:
    movzx eax, byte [rdi+T_OBJ]
    cmp eax, OBJ_ROAD
    jne .a
    mov eax, RAMP(R_GREY, 3)
    cmp byte [rdi+T_ROADTYPE], RT_STREET
    je .ar
    mov eax, RAMP(R_GREY, 5)
.ar:
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
    movzx eax, byte [mini_zone+rax]
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
section .data
mini_zone db 0, RAMP(R_ZONER,5), RAMP(R_ZONEC,5), RAMP(R_ZONEI,5), RAMP(R_TEAL,5), RAMP(R_ZONER,2), RAMP(R_ZONEC,2)
section .text

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
    cmp dword [drag_active], 0
    je .ui
    mov dword [click_pending], 0
.ui:
    call draw_problem_icons
    call draw_floats
    cmp dword [welcome], 0
    je .game
    call draw_welcome
    jmp .cursor
.game:
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
    jne .p4
    call draw_help
    jmp .hud
.p4:
    cmp eax, PANEL_POLICIES
    jne .p5
    call draw_policies
    jmp .hud
.p5:
    cmp eax, PANEL_STATS
    jne .hud
    call draw_stats
.hud:
    call draw_topbar
    cmp dword [sel_x], 0
    jge .nogoal
    call draw_goal
.nogoal:
    call draw_notifications
    call draw_submenu
    call draw_dock
    call draw_inspect
    call draw_minimap
    call draw_overlay_legend
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
    cmp dword [ui_captured], 0
    jne .out
    mov eax, [tool]
    cmp eax, T_INSPECT
    je .out
    movzx edi, byte [tool_icon+rax]
    cmp eax, T_ZONETOOL
    jne .ti
    mov edi, ICON_ZONE_R
    mov ecx, [zone_type]
    movzx ecx, byte [zone_class+rcx]
    cmp ecx, ZC_COM
    jne .z1
    mov edi, ICON_ZONE_C
.z1:
    cmp ecx, ZC_IND
    jne .z2
    mov edi, ICON_ZONE_I
.z2:
    cmp ecx, ZC_OFF
    jne .ti
    mov edi, ICON_STATS
.ti:
    mov esi, [umx]
    add esi, 10
    mov edx, [umy]
    add edx, 12
    call draw_icon
.out:
    RETURN
section .data
tool_icon db ICON_INSPECT, ICON_BULLDOZE, ICON_ROAD, ICON_POWERLINE, ICON_ZONE_R, ICON_WATER, ICON_BUS, ICON_DEZONE, ICON_POWER, ICON_TREE
section .text

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
    cmp dword [sel_x], 0
    jl .e45
    mov dword [sel_x], -1
    jmp .out
.e45:
    cmp dword [tool], T_INSPECT
    je .e5
    mov dword [tool], T_INSPECT
    jmp .out
.e5:
    mov dword [panel], PANEL_MENU
    jmp .out
.k1:
    ; zones 1..6
    cmp eax, SC_1
    jl .nz
    cmp eax, SC_1+5
    jg .nz
    sub eax, SC_1
    movzx eax, byte [key_zone+rax]
    mov [zone_type], eax
    mov ecx, T_ZONETOOL
    jmp .settool
.nz:
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
    mov ecx, T_PIPE
    cmp eax, SC_P
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
    mov ecx, PANEL_BUDGET
    cmp eax, SC_F1+1
    je .tp
    mov ecx, PANEL_POLICIES
    cmp eax, SC_F1+2
    je .tp
    mov ecx, PANEL_STATS
    cmp eax, SC_F1+3
    jne .k13
.tp:
    xor eax, eax
    cmp [panel], ecx
    je .tps
    mov eax, ecx
.tps:
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
section .data
key_zone db ZONE_R, ZONE_C, ZONE_I, ZONE_O, ZONE_RH, ZONE_CH
section .text

; =====================================================================
;  goals (checked daily)
; =====================================================================
FUNC check_goals
    mov eax, [goal_index]
    cmp eax, GOAL_COUNT
    jge .out
    xor ebx, ebx
    cmp eax, 0
    jne .g1
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
    movzx r9d, byte [tiles+r8+T_ZONE]
    cmp byte [zone_class+r9], ZC_RES
    jne .zn
    test r9d, r9d
    jz .zn
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
    je .chk
    cmp dword [water_demand], 0
    setg bl
    jmp .chk
.g5:
    cmp eax, 5
    jne .g6
    cmp dword [sewage_cap], 0
    setg bl
    jmp .chk
.g6:
    cmp eax, 6
    jne .g7
    cmp dword [svc_count+BK_POLICE*4], 0
    je .chk
    cmp dword [svc_count+BK_FIRE*4], 0
    setne bl
    jmp .chk
.g7:
    cmp eax, 7
    jne .g8
    cmp dword [population], 500
    setge bl
    jmp .chk
.g8:
    cmp eax, 8
    jne .g9
    mov ecx, [svc_count+BK_LANDFILL*4]
    or ecx, [svc_count+BK_INCIN*4]
    setnz bl
    jmp .chk
.g9:
    cmp eax, 9
    jne .g10
    cmp dword [svc_count+BK_ELEM*4], 0
    setne bl
    jmp .chk
.g10:
    cmp eax, 10
    jne .g11
    cmp dword [jobs+ZC_COM*4], 150
    setge bl
    jmp .chk
.g11:
    cmp eax, 11
    jne .g12
    cmp dword [svc_count+BK_BUSDEPOT*4], 0
    je .chk
    cmp dword [n_stops], 2
    setge bl
    jmp .chk
.g12:
    cmp eax, 12
    jne .g13
    cmp dword [jobs+ZC_OFF*4], 200
    setge bl
    jmp .chk
.g13:
    cmp eax, 13
    jne .g14
    cmp dword [population], 1500
    jl .chk
    cmp dword [happy_avg], 60
    setge bl
    jmp .chk
.g14:
    cmp eax, 14
    jne .g15
    mov ecx, [svc_count+BK_HOSPITAL*4]
    or ecx, [svc_count+BK_UNIV*4]
    setnz bl
    jmp .chk
.g15:
    cmp eax, 15
    jne .g16
    cmp dword [population], 5000
    setge bl
    jmp .chk
.g16:
    cmp eax, 16
    jne .g17
    cmp dword [population], 5000
    jl .chk
    cmp dword [flow_pct], 80
    setge bl
    jmp .chk
.g17:
    cmp eax, 17
    jne .g18
    cmp dword [svc_count+BK_LANDMARK*4], 0
    setne bl
    jmp .chk
.g18:
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
