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
T_LAND      equ 10
T_UPGRADE   equ 11
T_METRO     equ 12              ; beta: metro tunnels
T_RAIL      equ 13              ; beta: railway track
T_RUNWAY    equ 14              ; beta: airport runway
T_LEVEE     equ 15              ; beta: levees
T_TRAM      equ 16              ; beta: tram rails
T_DISTRICT  equ 17              ; beta: districts

PANEL_NONE     equ 0
PANEL_BUDGET   equ 1
PANEL_MENU     equ 2
PANEL_HELP     equ 3
PANEL_POLICIES equ 4
PANEL_STATS    equ 5
PANEL_SETTINGS equ 6
PANEL_SAVE     equ 7
PANEL_LOAD     equ 8
PANEL_REGION   equ 9            ; beta: the neighbours
PANEL_SERVICES equ 10           ; beta: services' funding
PANEL_ACHV     equ 11           ; beta: achievements
PANEL_HIST     equ 12           ; beta: history graphs
PANEL_SCEN     equ 13           ; beta: scenarios

MAX_TL      equ 4096
NOTIFS      equ 5
DOCK_BTN    equ 22

; submenu item codes
SI_STREET   equ 100
SI_AVENUE   equ 101
SI_HIGHWAY  equ 102
SI_BUSSTOP  equ 103
SI_UPGRADE  equ 104
SI_ZONE     equ 110        ; + zone type
SI_DEZONE   equ 117
SI_POWERLN  equ 120
SI_PIPE     equ 121
SI_UNPIPE   equ 122
SI_UNPOWER  equ 123
SI_METRO    equ 124             ; beta
SI_UNMETRO  equ 125             ; beta
SI_RAIL     equ 126             ; beta
SI_RUNWAY   equ 127             ; beta
SI_LEVEE    equ 128             ; beta
SI_TRAM     equ 129             ; beta
SI_DIST     equ 130             ; beta
SI_UNDIST   equ 131             ; beta
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
pl_n            resd 1
pl_x            resd 256
pl_y            resd 256
notif_text      resb NOTIFS*96
notif_col       resd NOTIFS
notif_tx        resd NOTIFS
notif_ty        resd NOTIFS
notif_time      resd NOTIFS
notif_cnt       resd NOTIFS
notif_show      resb 128
money_shown     resq 1
last_tool_err   resd 1
minimap_buf     resb 160*80
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
    dd ICON_LAND, T_LAND,  ICON_STATS, 205,    ICON_MENU, 202
DOCK_COUNT equ 19
dock_tips:
    dq tip0, tip1, tip2, tip3, tip4, tip5, tip6, tip7, tip8, tip9
    dq tip10, tip11, tip12, tip13, tip14, tip15, tip_land, tip16, tip17
tip_land db "Buy land (K)", 0
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
sm_roads    dd SI_STREET, SI_AVENUE, SI_HIGHWAY, SI_UPGRADE, SI_BUSSTOP, -1
sm_zones    dd SI_ZONE+ZONE_R, SI_ZONE+ZONE_RH, SI_ZONE+ZONE_C, SI_ZONE+ZONE_CH
            dd SI_ZONE+ZONE_I, SI_ZONE+ZONE_O, SI_DEZONE, -1
sm_power    dd SI_POWERLN, BK_WIND, BK_COAL, BK_SOLAR, BK_NUCLEAR, SI_UNPOWER, -1
sm_water    dd SI_PIPE, BK_PUMP, BK_WTOWER, BK_SEWAGE, SI_UNPIPE, -1
sm_garbage  dd BK_LANDFILL, BK_INCIN, -1
sm_safety   dd BK_POLICE, BK_FIRE, -1
sm_health   dd BK_CLINIC, BK_HOSPITAL, -1
sm_edu      dd BK_ELEM, BK_HIGH, BK_UNIV, -1
sm_transit  dd BK_BUSDEPOT, SI_BUSSTOP, -1
sm_leisure  dd BK_PARK, BK_PLAZA, BK_STADIUM, BK_CITYHALL, BK_LANDMARK, -1
sm_overlay  dd 1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009
            dd 1010, 1011, 1012, 1013, 1014, 1015, -1
; the info view a submenu shows while it is open
submenu_view dd 0, 0, OV_POWER, OV_WATER, OV_GARBAGE, OV_POLICE
             dd OV_HEALTH, OV_EDU, OV_TRANSIT, 0, 0

overlay_names:
    dq ov0, ov1, ov2, ov3, ov4, ov5, ov6, ov7, ov8, ov9, ov10, ov11, ov12, ov13, ov14, ov15
    dq ov16, ov17, ov18, ov19, ov20, ov21, ov_metro_n, ov_rail_n, ov_dist_n
ov21 db "Routes through this road", 0
ov20 db "Land", 0
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
    dq 0, oh1, oh2, 0, 0, 0, 0, oh7, 0, 0, 0, 0, 0, 0, 0, oh15, 0, 0, 0, 0, oh20, oh21, oh_metro, oh_rail, oh_dist
oh21 db 7, "where they come from  ", 2, "where they go  ", 4, "route  ", 3, "busy route", 0
oh20 db 1, "yours  ", 5, "for sale  ", 4, "can't afford  ", 6, "later", 0
oh1  db 5, "powered area  ", 3, "no power  ", 6, "wires", 0
oh2  db 7, "served  ", 3, "no water  ", 4, "no sewage outlet  ", 6, "no pump  ", 5, "polluted", 0
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
ti_upgrade db "Upgrade roads (U)", 0
ht_upgrade db "Upgrade roads", 0
hx_upgrade db "Click a road: upgrades its whole", 10
           db "stretch, junctions too. Or drag", 10
           db "along roads. Only existing roads", 10
           db "change; you pay the difference.", 10
           db 6, "Cars per lane: street 3,", 10
           db 6, "avenue 6, highway 8.", 0
up_names   dq rn0, rn1, rn2
ti_dezone  db "De-zone", 0
ti_line    db "Power line", 0
ti_pipe    db "Water pipe", 0
ti_unpipe  db "Remove pipes", 0
ti_unpower db "Remove power lines", 0
hx_unpipe  db "Drag over pipes to dig them up.", 10
           db "Roads and buildings stay put.", 10
           db 6, "(The bulldozer does this in the", 10
           db 6, "water view too.)", 0
hx_unpower db "Drag over pylons to take them", 10
           db "down, wires and all. Nothing", 10
           db "else is touched.", 0
ti_tile    db "/tile", 0

s_welcome1  db "Welcome, Mayor!", 0
s_welcome2  db "This valley needs a city. You own one plot of land by the", 10
            db "creek. Link a road to the highway, zone homes and industry,", 10
            db "then bring power, water pipes and a sewage outlet.", 10
            db "Grow to reach ", 5, "milestones", 1, ": each unlocks new buildings", 10
            db "and lets you buy more land (", 7, "K", 1, "). Watch your budget!", 10, 10
            db 7, "Drag", 1, " to build.  ", 7, "Right-drag", 1, " / WASD to pan.  ", 7, "Wheel", 1, " to zoom.", 10
            db 7, "Space", 1, " pause   ", 7, "O", 1, " info views   ", 7, "F1", 1, " help", 10, 10
            db 5, "Click anywhere for a new city.", 0
s_help      db "CONTROLS", 10, 10
            db 7, "Left drag", 1, "    build with the current tool", 10
            db 7, "Right drag", 1, "   pan (also WASD / arrows)", 10
            db 7, "Right click", 1, "  close / cancel, one step at a time", 10
            db 7, "V H", 1, "          tool's info view on/off, see-through buildings", 10
            db 7, "Ctrl+Z", 1, "       undo (up to 24 actions)", 10
            db 7, "U K Home", 1, "     upgrade roads, buy land, back to the city", 10
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
s_locked    db "Unlocks at ", 0
s_lockpeop  db " people)", 0
s_people    db " people", 0
s_tiles     db " tiles", 0
s_stretch   db "Stretch: ", 0
s_isstip    db "Click to visit each one", 0
iss_names   dq 0, is1, is2, is3, is4, is5, is6, is7, is8, is9, is10, is11, is12, s_dc_iss
is12 db "Services overloaded", 0
is1  db "without power", 0
is2  db "without water", 0
is3  db "without sewage", 0
is4  db "with garbage piling up", 0
is5  db "shops out of goods", 0
is6  db "short of workers", 0
is7  db "on fire!", 0
is8  db "with no road", 0
is9  db "with dirty water", 0
is10 db "whose trips can't get through", 0
is11 db "jammed road tiles - upgrade?", 0
iss_glyph   db 0, 128, 129, 129, 137, 138, 132, '!', '?', 129, '?', 136, '!', '!' 
iss_col     db 0, UI_WARN, UI_ACCENT, RAMP(R_WOOD,5), RAMP(R_ZONER,6), RAMP(R_ORANGE,6), UI_TEXT, UI_BAD, UI_BAD, RAMP(R_WOOD,4), UI_WARN, UI_BAD, UI_WARN, UI_WARN
s_stjam1    db ", ", 3, 0
s_stjam2    db " jammed", 0
s_mmtip     db "Click or drag to move the view  (Tab hides)", 0
s_notowned  db "You don't own this land yet - buy it with the Land tool (K).", 0
ht_land     db "Buy land", 0
s_lh1       db "Your city can only grow on land", 10
            db "you own. Click a ", 5, "gold plot", 1, " next to", 10
            db "your land to buy it.", 10
            db "Each milestone lets you own", 10
            db "one more plot; a Megalopolis", 10
            db "can own them all.", 10, 10, 0
s_lh2       db "Plots owned: ", 0
s_lh3       db " of ", 0
s_lh4       db 10, "Next plot: ", 0
s_lh5       db 10, 3, "Grow to the next milestone", 0
s_lh6       db 10, "The whole map is yours.", 0
s_bought    db "New land! Your city can grow here now.", 0
s_lnown     db "You already own this plot.", 0
s_lnext     db "You can only buy land next to your own.", 0
s_lms       db "Reach the next milestone to buy more land.", 0
s_lcash     db "Not enough money for this plot.", 0
s_mscard    db "MILESTONE", 0
s_msrew     db "Reward: ", 0
s_msland    db "+1 plot of land to buy (K)", 0
s_msland9   db "All the land is for sale (K)", 0
s_msunl     db "Now available:", 0
s_msok      db "Great!", 0
s_msnext    db "Next milestone: ", 0
s_msat      db " at ", 0
s_loans     db "Loans", 0
s_borrow    db "Borrow ", 0
s_moleft    db " mo left", 0
s_lnlock    db "at ", 0
s_lntaken   db "Loan received: ", 0
zone_unlock dd 0, 0, 0, 0, 600, 1200, 1200
road_unlock dd 0, 250, 1200, 600
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
s_m_sandbox db "New sandbox city", 0
s_m_export  db "Download city file", 0
s_m_import  db "Open city file...", 0
s_m_music   db "Music: ", 0
s_m_dis     db "Disasters: ", 0
s_m_day     db "Day/night: ", 0
s_m_full    db "Fullscreen (F11)", 0
s_m_help    db "Help (F1)", 0
s_m_quit    db "Quit", 0
s_m_settings db "Settings", 0
s_m_autold  db "Load autosave", 0
s_continue  db "Continue my city", 0
s_autofile  db "autosave.sav", 0
s_settings  db "SETTINGS", 0
s_st_music  db "Music", 0
s_st_sfx    db "Sound effects", 0
s_st_xray   db "See-through buildings: ", 0
s_xr_names  dq s_xr0, s_xr1, s_xr2
s_xr0       db "off", 0
s_xr1       db "near cursor", 0
s_xr2       db "all", 0
s_st_edge   db "Edge scrolling: ", 0
s_st_light  db "Lighting: ", 0
s_st_auto   db "Autosave: ", 0
s_st_auto1  db "every 3 months", 0
s_st_back   db "Back", 0
s_st_abandon db "Clear abandoned buildings: ", 0
s_st_rubble db "Sweep up rubble: ", 0
s_st_epause db "Pause for emergencies: ", 0
s_autosaved db "Autosaved.", 0
s_on        db "on", 0
s_off       db "off", 0
s_cycle     db "cycle", 0
s_locked_d  db "daylight", 0
s_saved     db "City saved.", 0
s_loaded    db "City loaded.", 0
s_loadfail  db "No saved city found.", 0
s_savefile  db "city.sav", 0
s_paused    db "PAUSED", 0
s_beta      db "BETA", 0
s_sandbox   db "Sandbox", 0
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
s_n_water   db "water (pipes within 3 tiles)", 0
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
s_n_commute db "shorter commutes (ease the jams)", 0
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
s_lostfare  db "-", 0
s_farestr   db " fares", 0
s_nobus     db "no buses yet", 0
s_indtax    db "-25% ind. tax", 0
s_growth    db "limits growth", 0

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
pd2 db "More bus riders, but no fare income.", 0
pd3 db "Dense zones stop at level 3.", 0
pd4 db "Fewer car trips.", 0
pd5 db "Industry pollutes far less, pays less tax.", 0
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
    dq s_st_metro, metro_riders, 0      ; beta rows follow
    dq s_st_walk, walkers, 0
    dq s_st_train, train_riders, 0
    dq s_st_frt, rail_freight, 0
    dq s_st_air, air_pax, 0
    dq s_st_port, port_trade, 2
    dq s_st_tram, tram_riders, 0
    dq s_st_raw, raw_last, 0
    dq s_st_tour, tourists, 0
    dq s_st_ferry, ferry_riders, 0
ST_ROWS_BETA equ 28
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
s_st_walk db "Trips on foot / month", 0
s_sec       db " s", 0

goal_text:
    dq g0, g1, g2, g3, g4, g5, g6, g7, g8, g9, g10, g11, g12, g13, g14, g15, g16, g17, g18, g19
goal_reward dd 500, 300, 500, 500, 500, 500, 800, 1000, 800, 800, 1000, 1200, 1500, 2000, 2000, 3000, 3000, 10000, 25000, 0
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

s_showview db "Show ", 0
s_vkey     db " view (V)", 0
s_hide     db "hide", 0
s_hidetip  db "Keep this view closed for this tool (V)", 0

; tool hints, by tool
hint_title dq 0, ht_bull, ht_road, ti_line, ht_zone, ti_pipe, ti_stop, ti_dezone, 0, ht_tree
hint_text  dq 0, hx_bull, hx_road, hx_line, hx_zone, hx_pipe, hx_stop, hx_dezone, 0, hx_tree
ht_bull db "Bulldozer", 0
ht_road db "Roads", 0
ht_zone db "Zoning", 0
ht_tree db "Trees", 0
hx_bull db "Drag over anything to clear it.", 10
        db "Empty ground: digs up pipes.", 0
hx_road db "Drag to build. Link new roads", 10
        db "to a highway at the map edge -", 10
        db "that's where people arrive.", 0
hx_line db "Drag a line: pylons go up every", 10
        db "few tiles and wires hop between.", 10
        db 5, "Power spreads from building to", 10
        db 5, "building within 2 tiles", 1, ", so one", 10
        db "line to a neighbourhood's edge", 10
        db "lights up the whole block.", 10
        db 6, "$20 a pylon, $2 a tile.", 0
hx_zone db "Drag along roads. Buildings", 10
        db "grow on their own.", 0
s_zd1   db 10, 1, "Demand right now: ", 0
cat_names dq cn0, cn1, cn2, cn3, cn4, cn5, cn6, cn7
cn0 db "Power       ", 0
cn1 db "Water       ", 0
cn2 db "Garbage     ", 0
cn3 db "Police/fire ", 0
cn4 db "Health      ", 0
cn5 db "Education   ", 0
cn6 db "Transit     ", 0
cn7 db "Parks & fun ", 0
s_zdhi  db 2, "high", 0
s_zdmid db 4, "some", 0
s_zdlo  db 3, "none", 1, 10, "(zone what the top bar wants)", 0
hz_zone db "They need a road, power and", 10
        db "water to grow past level 1.", 0
hx_pipe db "Pipes run underground (roads", 10
        db "can go on top). Every building", 10
        db 7, "within 3 tiles of a pipe", 1, " is served.", 10
        db "One pipe network does both:", 10
        db 7, " fresh water in", 1, " from a Pump or", 10
        db "   Water Tower touching it,", 10
        db 4, " sewage out", 1, " to a Sewage Outlet", 10
        db "   touching it.", 0
hx_stop db "Click a road. A Bus Depot sends", 10
        db "buses around all your stops.", 0
hx_dezone db "Drag to remove zoning.", 0
hx_tree db "Trees raise land value and", 10
        db "soak up pollution and noise.", 0

; extra hints by building kind
hint_bk dq hb_plant, hb_plant, hb_plant, hb_plant, hb_pump, hb_tower, hb_sewage
        dq 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        dq hb_metro, hb_railstn, hb_freight, hb_airport, hb_port, hb_plow
        dq hb_gcentral, hb_exchange, hb_opera, hb_space, hb_expo, hb_treat
        dq hb_cemetery, hb_crem, hb_tramdepot, hb_hotel, hb_icstn, hb_pier
        times BK_MAX-BK_COUNT dq 0
hb_plant   db "No road needed. Put it away from", 10
           db "homes, then drag a power line", 10
           db "to your city.", 0
hb_pump    db "Place it on the shore, then run", 10
           db "a pipe from it into town.", 10
           db "Needs power. Keep it ", 3, "upstream", 1, 10
           db "of sewage outlets.", 0
hb_tower   db "Place it on a pipe anywhere.", 10
           db "Needs power.", 0
hb_sewage  db "Every building on a pipe sends", 10
           db "its waste down the pipes to", 10
           db "here, and it spills into the", 10
           db "river. Put it on the shore", 10
           db 3, "downstream, far from pumps", 1, ".", 0
hb_metro   db "Stations joined by metro tunnels", 10
           db "make a line. People near one ride", 10
           db "to places near another: fast, and", 10
           db "never in traffic. Dig the tunnels", 10
           db "with Metro tunnel.", 0
hb_service db "The ring shows its reach.", 10
           db "Dim rings: ones you already have.", 0

; problem names and what to do about them, per PR_*
prob_titles dq 0, pt1, pt2, pt3, pt4, pt5, pt6, pt7, pt8, pt9, pt10
prob_fixes  dq 0, pf1, pf2, pf3, pf4, pf5, pf6, pf7, pf8, pf9, pf10
pt1  db "No electricity", 0
pt2  db "No running water", 0
pt3  db "Sewage is backing up", 0
pt4  db "Garbage is piling up", 0
pt5  db "Shelves are empty", 0
pt6  db "Not enough workers", 0
pt7  db "On fire!", 0
pt8  db "No road access", 0
pt9  db "Tap water is polluted", 0
pt10 db "Trips can't get through", 0
pf1  db "Build a power plant, then drag", 10
     db "a power line to within 2 tiles.", 10
     db "Powered buildings pass it on.", 0
pf2  db "Lay water pipes within 3 tiles", 10
     db "(under roads is fine), joined", 10
     db "to a Water Pump or Tower.", 0
pf3  db "Its water comes from pipes (or", 10
     db "a lone water tower) with no", 10
     db "Sewage Outlet big enough on the", 10
     db "same network - orange in the", 10
     db "water view. Pipe it to an outlet.", 0
pf4  db "Build a Landfill or Incinerator", 10
     db "that its trucks can reach.", 0
pf5  db "Shops need deliveries. Zone", 10
     db "industry and link it by road.", 0
pf6  db "Zone more homes nearby. Offices", 10
     db "also need schooled workers.", 0
pf7  db "A Fire Station in range sends", 10
     db "a truck - or pay to fight it.", 0
pf8  db "Buildings must touch a road", 10
     db "that leads to the highway.", 0
pf9  db "Its pump drinks polluted water.", 10
     db "Move pumps upstream, away", 10
     db "from sewage outlets.", 0
pf10 db "Cars from here can't find a way.", 10
     db "Link roads to the highway and", 10
     db "ease the traffic jams.", 0

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
    ; the same message again: count it instead of stacking copies
    xor ebx, ebx
.dup:
    cmp ebx, NOTIFS
    jge .new
    cmp dword [notif_time+rbx*4], 0
    je .dn
    imul eax, ebx, 96
    lea rdi, [notif_text+rax]
    mov rsi, r12
.cmp:
    mov al, [rsi]
    cmp al, [rdi]
    jne .dn
    test al, al
    jz .same
    inc rsi
    inc rdi
    jmp .cmp
.same:
    inc dword [notif_cnt+rbx*4]
    mov dword [notif_time+rbx*4], 420
    mov [notif_tx+rbx*4], r14d
    mov [notif_ty+rbx*4], r15d
    jmp .out
.dn:
    inc ebx
    jmp .dup
.new:
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
    mov eax, [notif_cnt+rbx*4-4]
    mov [notif_cnt+rbx*4], eax
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
    mov dword [notif_cnt], 1
.out:
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
    cmp dword [notif_cnt+rbx*4], 1
    jle .one
    ; "Fire! A building is burning.  x3"
    call tb_reset
    mov rdi, r13
    call tb_str
    mov edi, ' '
    call tb_char
    mov edi, 6
    call tb_char
    mov edi, 'x'
    call tb_char
    movsxd rdi, dword [notif_cnt+rbx*4]
    call tb_num
    lea rsi, [textbuf]
    lea rdi, [notif_show]
    mov ecx, 120
    rep movsb
    lea r13, [notif_show]
.one:
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
    mov dword [notif_time+rbx*4], 1     ; dismiss
    cmp dword [notif_tx+rbx*4], 0
    jl .t
    call cam_remember
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
    mov ebx, r8d
    mov r8, r15
    call ui_note_button
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, 14
    mov r8d, ebx
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
    ; beta: zone fill / along a road
    cmp dword [tool], T_ZONETOOL
    jne .nzb
    call zone_collect_beta
    test eax, eax
    jnz .out
.nzb:
    cmp dword [drag_active], 0
    je .single
    mov r14d, [drag_sx]
    mov r15d, [drag_sy]
    mov eax, [tool]
    cmp eax, T_ROAD
    je .line
    cmp eax, T_UPGRADE
    jne .nup
    ; a click (no movement) takes the whole stretch
    cmp r14d, r12d
    jne .line
    cmp r15d, r13d
    jne .line
    jmp .seg
.nup:
    cmp eax, T_POWERLN
    je .pline
    cmp eax, T_PIPE
    je .line
    cmp eax, T_METRO
    je .line
    cmp eax, T_RAIL
    je .line
    cmp eax, T_RUNWAY
    je .lineS
    cmp eax, T_LEVEE
    je .line
    cmp eax, T_TRAM
    je .line
    cmp eax, T_INSPECT
    je .single
    ; beta: a row of small buildings / bus stops along the drag
    call drag_places
    test eax, eax
    jz .ndp
    mov edi, r14d
    mov esi, r15d
    mov edx, r12d
    mov ecx, r13d
    call drag_places_collect
    jmp .out
.ndp:
    mov eax, [tool]
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
    ; beta: straight, freehand and grid roads (and railways)
    cmp dword [tool], T_RAIL
    je .lineB
    cmp dword [tool], T_ROAD
    jne .lineL
.lineB:
    mov edi, r14d
    mov esi, r15d
    mov edx, r12d
    mov ecx, r13d
    call road_collect_beta
    cmp eax, 1
    je .out
    cmp eax, 2
    jne .lineL
.lineS:
    ; straight: the end moves onto the start's row or column
    mov eax, r12d
    sub eax, r14d
    cdq
    xor eax, edx
    sub eax, edx
    mov ecx, r13d
    sub ecx, r15d
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx
    cmp eax, ecx
    jl .stv
    mov r13d, r15d
    jmp .lineL
.stv:
    mov r12d, r14d
.lineL:
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
.pline:
    mov edi, r14d
    mov esi, r15d
    mov edx, r12d
    mov ecx, r13d
    call pline_collect
    jmp .out
.seg:
    cmp dword [hover_valid], 0
    je .out
    mov edi, r12d
    mov esi, r13d
    call road_stretch
    jmp .out
.single:
    cmp dword [hover_valid], 0
    je .out
    cmp dword [tool], T_UPGRADE
    je .seg
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
    ; in the drag? (tl_here, marked for the preview)
    cmp r15d, MAP_W
    jae .n
    cmp esi, MAP_W
    jae .n
    mov eax, esi
    shl eax, MAP_SHIFT
    add eax, r15d
    cmp byte [tl_here+rax], 0
    je .n
.y:
    bts ebx, r14d
.n:
    inc r14d
    cmp r14d, 4
    jl .d
    mov eax, ebx
    RETURN

; dim reach rings around the buildings of the kind being placed
FUNC existing_rings
    mov edi, [build_kind]
    call bld_rec
    movzx r14d, byte [rax+BI_RADIUS]
    test r14d, r14d
    jz .out
    cmp r14d, 30
    jg .out                         ; city-wide: rings mean nothing
    movzx r15d, byte [rax+BI_SIZE]
    shr r15d, 1
    xor ebx, ebx
.l:
    cmp ebx, [n_svc]
    jge .out
    movzx r12d, word [list_svc+rbx*2]
    mov eax, r12d
    shl eax, TILE_SHIFT
    movzx ecx, byte [tiles+rax+T_SUB]
    cmp ecx, [build_kind]
    jne .n
    mov edi, r12d
    and edi, MAP_W-1
    add edi, r15d
    sub edi, r14d
    mov esi, r12d
    shr esi, MAP_SHIFT
    add esi, r15d
    sub esi, r14d
    lea edx, [r14*2+1]
    mov ecx, RAMP(R_GLASS, 4)
    call draw_diamond
.n:
    inc ebx
    jmp .l
.out:
    RETURN

; =====================================================================
;  world mouse handling (after the ui had its chance)
; =====================================================================

FUNC draw_goal
    ; beta: the council's request, once the goals are done
    call draw_request
    test eax, eax
    jnz .out
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
    ; beta: a sandbox city (and on the web, city files)
    call menu_extra_rows
    imul eax, eax, 18
    add eax, 180
    mov [rbp-48], eax
    mov r12d, [ui_w]
    sub r12d, 170
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, [rbp-48]
    sub r13d, 42
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, 170
    mov ecx, [rbp-48]
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 170
    mov ecx, [rbp-48]
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
    call open_save_panel
    jmp .out
.m2:
    MBTN s_m_load
    test eax, eax
    jz .m3
    call open_load_panel
    jmp .out
.m3:
    MBTN s_m_new
    test eax, eax
    jz .m4
    call new_city
    mov dword [panel], PANEL_NONE
.m4:
    cmp dword [beta_on], 0
    je .m5
    MBTN s_m_sandbox
    test eax, eax
    jz .m41
    call new_sandbox_city
    mov dword [panel], PANEL_NONE
.m41:
    MBTN s_sc_menu
    test eax, eax
    jz .m4s
    mov dword [panel], PANEL_SCEN
    jmp .out
.m4s:
%ifdef WEB
    MBTN s_m_export
    test eax, eax
    jz .m42
    call city_export
    mov dword [panel], PANEL_NONE
.m42:
    MBTN s_m_import
    test eax, eax
    jz .m5
    call web_import
    mov dword [panel], PANEL_NONE
%endif
.m5:
    MBTN s_m_settings
    test eax, eax
    jz .m8
    mov dword [panel], PANEL_SETTINGS
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


; ---------------------------------------------------------------------
;  settings
; ---------------------------------------------------------------------
; slider(edi x, esi y, edx w, rcx -> dword 0..100) -> eax 1 if changed
FUNC ui_slider, 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15, rcx
    ; drag or click anywhere on the track
    lea esi, [r13-3]
    mov ecx, 12
    call ui_over
    xor ebx, ebx
    test eax, eax
    jz .d
    mov eax, [lmb_down]
    or eax, [click_pending]
    jz .d
    mov dword [click_pending], 0
    mov eax, [umx]
    sub eax, r12d
    imul eax, 100
    cdq
    idiv r14d
    CLAMP eax, 0, 100
    cmp eax, [r15]
    je .d
    mov [r15], eax
    mov ebx, 1
.d:
    ; track, fill, knob
    mov edi, r12d
    lea esi, [r13+2]
    mov edx, r14d
    mov ecx, 3
    mov r8d, UI_BG2
    call fill_rect
    mov eax, [r15]
    imul eax, r14d
    xor edx, edx
    mov ecx, 100
    div ecx
    mov [rbp-48], eax
    mov edi, r12d
    lea esi, [r13+2]
    mov edx, eax
    mov ecx, 3
    mov r8d, UI_GOLD
    call fill_rect
    mov edi, [rbp-48]
    lea edi, [r12+rdi-2]
    lea esi, [r13-2]
    mov edx, 5
    mov ecx, 11
    mov r8d, UI_TEXT
    call fill_rect
    mov eax, ebx
    RETURN

FUNC draw_settings, 16
    ; beta: three more rows (the assists)
    mov eax, 226
    cmp dword [beta_on], 0
    je .h
    add eax, 3*18
.h:
    mov [rbp-48], eax
    mov r12d, [ui_w]
    sub r12d, 260
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, [rbp-48]
    sub r13d, 6
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, 260
    mov ecx, [rbp-48]
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 260
    mov ecx, [rbp-48]
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+130]
    lea esi, [r13+6]
    lea rdx, [s_settings]
    mov ecx, UI_GOLD
    call draw_text_centered
    mov dword [font_scale], 1
    add r13d, 30
%macro SLIDEROW 2       ; label, value
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [%1]
    mov ecx, UI_TEXT
    call draw_text
    lea edi, [r12+96]
    mov esi, r13d
    mov edx, 120
    lea rcx, [%2]
    call ui_slider
    or [settings_dirty], eax
    call tb_reset
    movsxd rdi, dword [%2]
    call tb_pct
    lea edi, [r12+250]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text_right
    add r13d, 16
%endmacro
    SLIDEROW s_st_music, set_music
    SLIDEROW s_st_sfx, set_sfx
    call apply_volumes
    add r13d, 4
%macro SETBTN 0         ; textbuf -> button, eax clicked
    lea edi, [r12+10]
    mov esi, r13d
    mov edx, 240
    lea rcx, [textbuf]
    xor r8d, r8d
    call text_button
    add r13d, 18
%endmacro
    ; see-through
    call tb_reset
    lea rdi, [s_st_xray]
    call tb_str
    mov eax, [set_xray]
    mov rdi, [s_xr_names+rax*8]
    call tb_str
    SETBTN
    test eax, eax
    jz .b1
    mov eax, [set_xray]
    inc eax
    cmp eax, 3
    jl .x1
    xor eax, eax
.x1:
    mov [set_xray], eax
    mov dword [settings_dirty], 1
.b1:
    call tb_reset
    lea rdi, [s_st_light]
    call tb_str
    lea rdi, [s_on]
    cmp dword [set_light], 0
    jne .l1
    lea rdi, [s_off]
.l1:
    call tb_str
    SETBTN
    test eax, eax
    jz .bl
    xor dword [set_light], 1
    mov eax, [set_light]
    xor eax, 1
    mov [light_off], eax
    mov dword [settings_dirty], 1
.bl:
    call tb_reset
    lea rdi, [s_st_edge]
    call tb_str
    lea rdi, [s_on]
    cmp dword [set_edge], 0
    jne .e1
    lea rdi, [s_off]
.e1:
    call tb_str
    SETBTN
    test eax, eax
    jz .b2
    xor dword [set_edge], 1
    mov dword [settings_dirty], 1
.b2:
    call tb_reset
    lea rdi, [s_st_auto]
    call tb_str
    lea rdi, [s_st_auto1]
    cmp dword [set_autosave], 0
    jne .a1
    lea rdi, [s_off]
.a1:
    call tb_str
    SETBTN
    test eax, eax
    jz .b3
    xor dword [set_autosave], 1
    mov dword [settings_dirty], 1
.b3:
    call tb_reset
    lea rdi, [s_m_dis]
    call tb_str
    lea rdi, [s_on]
    cmp dword [disasters_on], 0
    jne .d1
    lea rdi, [s_off]
.d1:
    call tb_str
    SETBTN
    test eax, eax
    jz .b4
    xor dword [disasters_on], 1
.b4:
    call tb_reset
    lea rdi, [s_m_day]
    call tb_str
    lea rdi, [s_cycle]
    cmp dword [tod_lock], 0
    je .t1
    lea rdi, [s_locked_d]
.t1:
    call tb_str
    SETBTN
    test eax, eax
    jz .b5
    xor dword [tod_lock], 1
.b5:
    ; beta: assists
    cmp dword [beta_on], 0
    je .b55
    call tb_reset
    lea rdi, [s_st_abandon]
    call tb_str
    lea rdi, [s_on]
    cmp dword [set_clear_abandoned], 0
    jne .as1
    lea rdi, [s_off]
.as1:
    call tb_str
    SETBTN
    test eax, eax
    jz .as2
    xor dword [set_clear_abandoned], 1
    mov dword [settings_dirty], 1
.as2:
    call tb_reset
    lea rdi, [s_st_rubble]
    call tb_str
    lea rdi, [s_on]
    cmp dword [set_sweep_rubble], 0
    jne .as3
    lea rdi, [s_off]
.as3:
    call tb_str
    SETBTN
    test eax, eax
    jz .as4
    xor dword [set_sweep_rubble], 1
    mov dword [settings_dirty], 1
.as4:
    call tb_reset
    lea rdi, [s_st_epause]
    call tb_str
    lea rdi, [s_on]
    cmp dword [set_emerg_pause], 0
    jne .as5
    lea rdi, [s_off]
.as5:
    call tb_str
    SETBTN
    test eax, eax
    jz .b55
    xor dword [set_emerg_pause], 1
    mov dword [settings_dirty], 1
.b55:
    call tb_reset
    lea rdi, [s_m_full]
    call tb_str
    SETBTN
    test eax, eax
    jz .b6
    call video_toggle_fullscreen
.b6:
    call tb_reset
    lea rdi, [s_st_back]
    call tb_str
    SETBTN
    test eax, eax
    jz .out
    mov dword [panel], PANEL_MENU
.out:
    ; write the file once the mouse lets go
    cmp dword [settings_dirty], 0
    je .o2
    cmp dword [lmb_down], 0
    jne .o2
    mov dword [settings_dirty], 0
    call settings_save
.o2:
    RETURN

; month end: autosave every third month
FUNC autosave_tick
    cmp dword [set_autosave], 0
    je .out
    cmp dword [tut_bubble], 0
    jne .out
    cmp dword [sandbox], 0
    jne .out
    cmp dword [welcome], 0
    jne .out
    mov eax, [month]
    xor edx, edx
    mov ecx, 3
    div ecx
    test edx, edx
    jnz .out
    mov dword [save_quiet], 1
    lea rdi, [s_autofile]
    call save_city_to
    lea rdi, [s_autosaved]
    mov esi, UI_DIM
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; once per frame: raise the launch fade-in (about 4 seconds)
FUNC music_fade_tick
    mov eax, [music_fade]
    cmp eax, 256
    jge .out
    inc eax
    mov [music_fade], eax
    call apply_volumes
.out:
    RETURN

; volume percentages -> the mixer's float gains
FUNC apply_volumes
    ; music fades in over the first few seconds after launch
    mov eax, [set_music]
    imul eax, [music_fade]
    shr eax, 8
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_music_scale]
    movss [music_vol], xmm0
    cvtsi2ss xmm0, dword [set_sfx]
    mulss xmm0, [f_sfx_scale]
    movss [sfx_vol], xmm0
    RETURN

section .data
align 4
f_music_scale dd 0.008
f_sfx_scale   dd 0.01
music_fade    dd 0          ; 0..256
set_music     dd 5
set_sfx       dd 5
set_xray      dd 1          ; 0 off, 1 near the cursor, 2 all
set_edge      dd 0
set_autosave  dd 1
set_light     dd 1          ; sun shadows, clouds and night glow
set_tutdone   dd 0          ; the first-time tour was finished or skipped
set_road_mode dd 0          ; beta: L-shape, straight, freehand, grid
set_grid_step dd 7          ; beta: grid roads this far apart
set_road_pipes dd 1         ; beta: pipes go under new roads
set_zone_mode dd 0          ; beta: area, fill a block, along a road
set_clear_abandoned dd 1    ; beta: abandoned buildings are cleared away
set_sweep_rubble dd 1       ; beta: rubble is swept up every month
set_emerg_pause dd 0        ; beta: fires, meteors, an empty treasury pause
section .data
up_type        dd 1                 ; the upgrade tool's target road type
section .bss
iss_count      resd 12
iss_shown      resd 12
iss_next       resd 12
iss_worst      resd 1
iss_age        resd 1
settings_dirty resd 1
has_save       resd 1
save_quiet     resd 1
cam_save       resd 3
section .text

FUNC draw_help
    mov r12d, [ui_w]
    sub r12d, 330
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, 210
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, 330
    mov ecx, 196
    call draw_panel
    lea edi, [r12+330-120]
    lea esi, [r13+196-22]
    mov edx, 110
    lea rcx, [s_tut_replay]
    mov r8d, 1
    call text_button
    test eax, eax
    jz .nt
    mov dword [panel], PANEL_NONE
    call tut_start
    jmp .d
.nt:
    mov edi, r12d
    mov esi, r13d
    mov edx, 330
    mov ecx, 196
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
    sub r13d, 170
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, 330
    mov ecx, 150
    ; beta: rows for the difficulty and the land
    cmp dword [beta_on], 0
    je .ph
    add ecx, 40
.ph:
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
    ; beta: how hard the new city will be
    lea edi, [r12+12]
    lea esi, [r13+150]
    call welcome_difficulty
    lea edi, [r12+12]
    lea esi, [r13+170]
    call welcome_maps
    ; pick up where you left off
    cmp dword [has_save], 0
    je .out
    lea edi, [r12+180]
    lea esi, [r13+128]
    mov edx, 140
    lea rcx, [s_continue]
    mov r8d, 1
    call text_button
    test eax, eax
    jz .out
    mov dword [welcome], 0
    mov dword [slots_start], 1
    call open_load_panel
.out:
    RETURN

; does any save exist? (has_save)
FUNC check_saves
    mov dword [has_save], 0
    cmp dword [sandbox], 0
    jne .out
    call slots_scan
    call slots_any
    mov [has_save], eax
.out:
    RETURN

; ---------------------------------------------------------------------
;  overlay legend + minimap
; ---------------------------------------------------------------------

MM_W equ 160
MM_H equ 80

; minimap position -> r12d x, r13d y (panel top-left)
minimap_pos:
    mov r12d, [ui_w]
    sub r12d, MM_W+10
    mov r13d, [ui_h]
    sub r13d, DOCK_BTN+18+MM_H
    ret

; minimap pixel (edi px, esi py) -> eax x, edx y (tile, may be off-map)
;   x - y = (px - W/2) * 8/5      x + y = py * 16/5
minimap_to_tile:
    lea eax, [rdi-MM_W/2]
    shl eax, 3
    cdq
    mov ecx, 5
    idiv ecx
    mov r8d, eax                    ; x - y
    mov eax, esi
    shl eax, 4
    cdq
    idiv ecx                        ; x + y
    lea ecx, [rax+r8]
    sar ecx, 1
    sub eax, r8d
    sar eax, 1
    mov edx, eax
    mov eax, ecx
    ret

; tile (edi x, esi y) -> eax px, edx py on the minimap
tile_to_minimap:
    mov eax, edi
    sub eax, esi
    imul eax, 5
    sar eax, 3
    add eax, MM_W/2
    lea edx, [rdi+rsi]
    imul edx, 5
    sar edx, 4
    ret

FUNC draw_minimap, 16
    cmp dword [minimap_on], 0
    je .out
    ; rebuild the cached image twice a second
    dec dword [minimap_age]
    jns .draw
    mov dword [minimap_age], 30
    xor r13d, r13d                  ; py
.y:
    xor r12d, r12d                  ; px
.x:
    ; sample the 2x2 tiles under the pixel, keep the most important
    mov edi, r12d
    mov esi, r13d
    call minimap_to_tile
    mov r14d, eax
    mov r15d, edx
    xor ebx, ebx                    ; best colour
    mov dword [rbp-48], -1          ; best priority
    xor ecx, ecx
.s:
    mov [rbp-52], ecx
    mov edi, ecx
    and edi, 1
    add edi, r14d
    mov esi, ecx
    shr esi, 1
    add esi, r15d
    cmp edi, MAP_W
    jae .sn
    cmp esi, MAP_W
    jae .sn
    push rdi
    push rsi
    call tile_at
    mov rdi, rax
    call minimap_colour             ; eax colour, edx priority
    pop rsi
    pop rdi
    cmp edx, [rbp-48]
    jle .sn
    mov [rbp-48], edx
    mov ebx, eax
    ; your land bright, the rest dimmer
    cmp dword [sandbox], 0
    jne .sn
    push rbx
    push rbx
    call tile_owned
    pop rbx
    pop rbx
    test eax, eax
    jnz .sn
    movzx ebx, byte [remap_dim+rbx]
.sn:
    mov ecx, [rbp-52]
    inc ecx
    cmp ecx, 4
    jl .s
    mov eax, r13d
    imul eax, MM_W
    add eax, r12d
    mov [minimap_buf+rax], bl
    inc r12d
    cmp r12d, MM_W
    jl .x
    inc r13d
    cmp r13d, MM_H
    jl .y
.draw:
    call minimap_pos
    mov edi, r12d
    mov esi, r13d
    mov edx, MM_W+6
    mov ecx, MM_H+6
    call draw_panel
    ; click or drag to move the camera
    mov edi, r12d
    mov esi, r13d
    mov edx, MM_W+6
    mov ecx, MM_H+6
    call ui_over
    test eax, eax
    jz .blit
    lea rax, [s_mmtip]
    mov [tooltip], rax
    mov eax, [lmb_down]
    or eax, [click_pending]
    jz .blit
    mov dword [click_pending], 0
    mov edi, [umx]
    sub edi, r12d
    sub edi, 3
    mov esi, [umy]
    sub esi, r13d
    sub esi, 3
    call minimap_to_tile
    mov edi, eax
    mov esi, edx
    CLAMP edi, 0, MAP_W-1
    CLAMP esi, 0, MAP_W-1
    call camera_center_tile
    call camera_clamp
.blit:
    xor ebx, ebx
.p:
    movzx edx, byte [minimap_buf+rbx]
    test edx, edx
    jz .pn
    mov eax, ebx
    xor edx, edx
    mov ecx, MM_W
    div ecx
    lea esi, [rax+r13+3]
    lea edi, [rdx+r12+3]
    movzx edx, byte [minimap_buf+rbx]
    call put_pixel
.pn:
    inc ebx
    cmp ebx, MM_W*MM_H
    jl .p
    ; the part of the world on screen, as a rectangle
    mov edi, [cam_x]
    mov esi, [cam_y]
    call world_to_tile
    mov edi, eax
    mov esi, edx
    call tile_to_minimap
    mov r14d, eax
    mov r15d, edx
    mov edi, [cam_x]
    add edi, [fb_w]
    mov esi, [cam_y]
    add esi, [fb_h]
    call world_to_tile
    mov edi, eax
    mov esi, edx
    call tile_to_minimap
    sub eax, r14d
    sub edx, r15d
    CLAMP eax, 3, MM_W
    CLAMP edx, 3, MM_H
    mov [rbp-48], eax
    mov [rbp-52], edx
    ; clip to the minimap box
    lea edi, [r12+3]
    lea esi, [r13+3]
    mov edx, MM_W
    mov ecx, MM_H
    call set_clip
    lea edi, [r12+r14+3]
    lea esi, [r13+r15+3]
    mov edx, [rbp-48]
    mov ecx, [rbp-52]
    mov r8d, UI_TEXT
    call rect_outline
    call reset_clip
.out:
    RETURN

; =====================================================================
;  render_ui: everything on the ui layer, in order
; =====================================================================

; re-zoning a built lot (r12 tile, r13d x, r14d y): the old building
; comes down (its whole footprint) and the lot is cleared for the new zone
rezone_clear:
    cmp byte [r12+T_OBJ], OBJ_ZONEBLD
    jne .o
    sub rsp, 8                      ; keep the stack 16-byte aligned
    mov edi, r13d
    mov esi, r14d
    call destroy_to_rubble
    add rsp, 8
.o:
    ret

; ---------------------------------------------------------------------
;  Saves are a list of chunks: tag (4 bytes), length (u32), data.
;    TILE  the map          SIMS  the saved sim state block
;    SEED  world seed       CAMR  camera (x, y, zoom)
;  Loading copies what a chunk has and leaves the rest at defaults, so
;  saves keep working when later versions add state (append new saved
;  fields at the end of the block in sim.asm).  Unknown chunks are
;  skipped.  Older "CSAVv004" saves (one fixed block) still load.
; ---------------------------------------------------------------------
save_city:
    mov eax, [current_slot]
    mov rdi, [slot_files+rax*8]
FUNC save_city_to, 16
    ; the practice village of the tour is never saved
    cmp dword [tut_bubble], 0
    je .ok
    lea rdi, [s_tut_nosave]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .out
.ok:
    push rdi
    push rdi
    call save_prepare
    call region_summarise
    pop rdi
    pop rdi
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
    mov eax, [cam_x]
    mov [cam_save], eax
    mov eax, [cam_y]
    mov [cam_save+4], eax
    mov eax, [zoom]
    mov [cam_save+8], eax
    xor ebx, ebx
.ch:
    cmp ebx, SAVE_CHUNKS
    jge .close
    imul eax, ebx, 16
    lea r13, [save_chunks+rax]
    ; header: tag, length
    mov eax, [r13]
    mov [numbuf], eax
    mov eax, [r13+12]
    mov [numbuf+4], eax
    mov rdi, r12
    lea rsi, [numbuf]
    mov edx, 8
    mov ecx, 1
    CALLC SDL_RWwrite
    mov rdi, r12
    mov rsi, [r13+4]
    mov edx, [r13+12]
    mov ecx, 1
    CALLC SDL_RWwrite
    inc ebx
    jmp .ch
.close:
    mov rdi, r12
    CALLC SDL_RWclose
    cmp dword [save_quiet], 0
    jne .out
    lea rdi, [s_saved]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_CHIME
    call sfx_play
.out:
    mov dword [save_quiet], 0
    RETURN

; copy up to the chunk's capacity (rdi chunk entry, rsi src, edx len)
save_take:
    push rbx
    mov rbx, rdi
    mov ecx, [rbx+12]
    cmp edx, ecx
    jbe .n
    mov edx, ecx
.n:
    mov rdi, [rbx+4]
    mov ecx, edx
    rep movsb
    pop rbx
    ret

load_city:
    mov eax, [current_slot]
    mov rdi, [slot_files+rax*8]
FUNC load_city_from, 32
    lea rsi, [str_rb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz .fail
    mov r12, rax
    mov rdi, r12
    lea rsi, [load_buf]
    mov edx, 1
    mov ecx, LOAD_MAX
    CALLC SDL_RWread
    mov r14, rax                    ; bytes in the file
    mov rdi, r12
    CALLC SDL_RWclose
    cmp r14, 8 + MAP_TILES*TILE_BYTES
    jb .fail
    ; the old city's actions can't be undone in this one
    call undo_reset
    call extra_reset
    ; defaults for anything the save doesn't have
    lea rdi, [money]
    mov ecx, sim_state_end - money
    xor eax, eax
    rep stosb
    lea rdi, [plot_owned]           ; saves from before land plots
    mov eax, 0x01010101
    mov ecx, (PLOTS*PLOTS+7)/4
    rep stosd
    mov dword [flow_pct], 100
    mov dword [staff_basic], 256
    mov dword [cam_save+8], 0
    mov rax, [load_buf]
    cmp rax, [save_magic]
    je .chunks
    cmp rax, [save_magic4]
    jne .fail
    ; ---- CSAVv004: magic, tiles, state, seed (12) [, camera (12)] ----
    lea rsi, [load_buf+8]
    lea rdi, [save_chunks+SC_TILE*16]
    mov edx, MAP_TILES*TILE_BYTES
    call save_take
    mov r15, r14
    sub r15, 8 + MAP_TILES*TILE_BYTES + 12
    ; a camera trailer ends with the zoom (1..4); the seed block ends
    ; with the second highway's column
    mov eax, [load_buf+r14-4]
    dec eax
    cmp eax, 4
    jae .nocam4
    sub r15, 12
    lea rsi, [load_buf+r14-12]
    lea rdi, [save_chunks+SC_CAMR*16]
    mov edx, 12
    call save_take
.nocam4:
    cmp r15, 0
    jle .fail
    lea rsi, [load_buf+8+MAP_TILES*TILE_BYTES]
    lea rdi, [save_chunks+SC_SIMS*16]
    mov edx, r15d
    push rsi
    push rsi
    call save_take
    pop rsi
    pop rsi
    add rsi, r15
    lea rdi, [save_chunks+SC_SEED*16]
    mov edx, 12
    call save_take
    jmp .loaded
.chunks:
    mov r13d, 8                     ; read position
    xor r15d, r15d                  ; saw the map
.next:
    lea eax, [r13+8]
    cmp rax, r14
    ja .done
    mov ecx, [load_buf+r13+4]       ; length
    mov ebx, [load_buf+r13]         ; tag
    add r13d, 8
    mov eax, r13d
    add rax, rcx
    cmp rax, r14
    ja .done                        ; truncated
    mov [rbp-48], ecx
    ; known chunk?
    xor edx, edx
.find:
    cmp edx, SAVE_CHUNKS
    jge .skip
    imul eax, edx, 16
    cmp ebx, [save_chunks+rax]
    je .take
    inc edx
    jmp .find
.take:
    cmp ebx, 'TILE'
    jne .t
    mov r15d, 1
.t:
    lea rdi, [save_chunks+rax]
    lea rsi, [load_buf+r13]
    mov edx, [rbp-48]
    call save_take
.skip:
    add r13d, [rbp-48]
    jmp .next
.done:
    test r15d, r15d
    jz .fail
.loaded:
    mov edi, [cam_save+8]
    test edi, edi
    jz .nocam
    call video_set_zoom
    mov eax, [cam_save]
    mov [cam_x], eax
    mov eax, [cam_save+4]
    mov [cam_y], eax
    call camera_clamp
.nocam:
    mov dword [welcome], 0
    mov dword [slots_start], 0
    call region_read                ; (beta: your other cities)
    call tut_abort
    call agents_init
    call scenic_init
    call style_existing
    mov dword [net_dirty], 1
    mov dword [cov_dirty], 1
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
.fail:
    lea rdi, [s_loadfail]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

LOAD_MAX equ 4*1024*1024
section .bss
load_buf    resb LOAD_MAX
section .data
save_magic  db "CSAVv005"
save_magic4 db "CSAVv004"
align 8
; tag, address, length
save_chunks:
    db "INFO"
    dq save_info
    dd INFO_BYTES
    db "THMB"
    dq save_thumb
    dd THUMB_BYTES
    db "SUMM"                       ; (for your other cities; beta)
    dq region_summ
    dd SUMM_BYTES
    db "TILE"
    dq tiles
    dd MAP_TILES*TILE_BYTES
    db "SIMS"
    dq money
    dd sim_state_end - money
    db "SEED"
    dq world_seed
    dd 12
    db "CAMR"
    dq cam_save
    dd 12
    db "SZON"
    dq svc_zone
    dd MAP_TILES
    db "BKMK"
    dq bookmarks
    dd BOOKMARKS*12
    db "RGON"
    dq region_state
    dd region_state_end - region_state
    db "ACHV"
    dq achv_state
    dd achv_state_end - achv_state
    db "HIST"
    dq hist_state
    dd hist_state_end - hist_state
    db "SCEN"
    dq scen_state
    dd scen_state_end - scen_state
    db "DIST"
    dq dist_state
    dd dist_state_end - dist_state
SAVE_CHUNKS equ ($-save_chunks)/16
SC_TILE equ 3
SC_SIMS equ 4
SC_SEED equ 5
SC_CAMR equ 6
section .text


FUNC new_city
    call tut_abort
    call undo_reset
    call extra_reset
    mov dword [sandbox], 0
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
    mov edi, 38
    mov esi, [hwy_row]
    call camera_center_tile
    RETURN

; =====================================================================
;  info view chosen by the current tool (Cities: Skylines style)
; =====================================================================
FUNC compute_eff_overlay
    ; which view goes with what is selected right now
    xor eax, eax
    cmp dword [welcome], 0
    jne .have
    ; beta: the metro tools show the metro view, the railway ones theirs
    call metro_view_wanted
    test eax, eax
    jnz .set2
    call rail_view_wanted
    test eax, eax
    jnz .set2
    call dist_view_wanted
    test eax, eax
    jnz .set2
    mov ecx, [submenu]
    cmp ecx, -1
    je .tool
    mov eax, [submenu_view+rcx*4]
    test eax, eax
    jnz .have
.tool:
    mov ecx, [tool]
    cmp ecx, T_POWERLN
    jne .t1
    mov eax, OV_POWER
    jmp .have
.t1:
    cmp ecx, T_PIPE
    jne .t3
    mov eax, OV_WATER
    jmp .have
.t3:
    cmp ecx, T_BULLDOZE
    jne .t4
    mov eax, [bz_filter]
    test eax, eax
    jz .have
    mov eax, OV_WATER
    cmp dword [bz_filter], 1
    je .have
    mov eax, OV_POWER
    jmp .have
.t4:
    cmp ecx, T_BUSSTOP
    jne .t5
    mov eax, OV_TRANSIT
    jmp .have
.t5:
    ; zoning shows where that kind of building wants to be
    cmp ecx, T_ZONETOOL
    jne .t5a
    mov eax, [zone_type]
    movzx eax, byte [zone_class+rax]
    add eax, OV_DESIRE_R
    jmp .have
.t5a:
    mov eax, OV_TRAFFIC
    cmp ecx, T_ROAD
    je .have
    cmp ecx, T_UPGRADE
    je .have
    mov eax, OV_POLLUTE
    cmp ecx, T_TREE
    je .have
    xor eax, eax
.t6:
    cmp ecx, T_BUILD
    jne .have
    mov edi, [build_kind]
    call bld_rec
    movzx ecx, byte [rax+BI_CATEGORY]
    movzx eax, byte [cat_view+rcx]
    cmp ecx, CAT_SAFETY
    jne .have
    mov eax, OV_POLICE
    cmp dword [build_kind], BK_FIRE
    jne .have
    mov eax, OV_FIRE
.have:
    cmp dword [tool], T_LAND
    jne .have2
    cmp dword [welcome], 0
    jne .have2
    mov dword [auto_view], 0
    mov eax, OV_LAND
    cmp dword [overlay_mode], 0
    je .set
.have2:
    mov [auto_view], eax
    ; an info view picked by hand always wins
    mov ecx, [overlay_mode]
    test ecx, ecx
    jnz .man
    ; otherwise only if the player left it switched on for this tool
    test eax, eax
    jz .set
    cmp byte [auto_on+rax], 0
    jne .set
    xor eax, eax
    jmp .set
.man:
    mov eax, ecx
.set:
    ; beta: an inspected road shows its routes (unless a view was picked)
    cmp dword [route_sel], 0
    jl .set2
    cmp dword [overlay_mode], 0
    jne .set2
    mov eax, OV_ROUTES
.set2:
    mov [eff_overlay], eax
    RETURN

; V / the chip in the tool hint: flip the remembered auto view
; (no view for this tool: V shows / hides the last view picked with O)
toggle_auto_view:
    mov eax, [auto_view]
    test eax, eax
    jz .manual
    ; a view picked with O on top of the tool's: V just drops it
    cmp dword [overlay_mode], 0
    jne .drop
    xor byte [auto_on+rax], 1
    call settings_save
    jmp .click
.drop:
    mov dword [overlay_mode], 0
    jmp .click
.manual:
    mov eax, [overlay_mode]
    test eax, eax
    jz .restore
    mov [ov_last], eax
    mov dword [overlay_mode], 0
    jmp .click
.restore:
    mov eax, [ov_last]
    test eax, eax
    jnz .r
    mov eax, OV_POWER
.r:
    mov [overlay_mode], eax
.click:
    mov edi, SFX_CLICK
    call sfx_play
    ret

section .data
cat_view db OV_POWER, OV_WATER, OV_GARBAGE, OV_POLICE, OV_HEALTH, OV_EDU, OV_TRANSIT, OV_LANDVAL
; which info views open by themselves (the player can flip each; saved)
auto_on  db 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
AUTO_ON_N equ 20
SET_N     equ 14                ; append new settings at the end
CFG_SIZE  equ 4+AUTO_ON_N+SET_N*4
settings_file db "cityssembly.cfg", 0
settings_magic db "CSC3"
section .bss
auto_view resd 1
ov_last   resd 1
settings_buf resb 64
section .text

; settings: the remembered info-view switches
FUNC settings_save
    lea rdi, [settings_file]
    lea rsi, [str_wb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz .o
    mov r12, rax
    mov eax, [settings_magic]
    mov [settings_buf], eax
    lea rdi, [settings_buf+4]
    lea rsi, [auto_on]
    mov ecx, AUTO_ON_N
    rep movsb
    lea rsi, [set_music]
    mov ecx, SET_N*4
    rep movsb
    mov rdi, r12
    lea rsi, [settings_buf]
    mov edx, CFG_SIZE
    mov ecx, 1
    CALLC SDL_RWwrite
    mov rdi, r12
    CALLC SDL_RWclose
.o:
    RETURN

FUNC settings_load
    lea rdi, [settings_file]
    lea rsi, [str_rb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz .o
    mov r12, rax
    mov rdi, r12
    lea rsi, [settings_buf]
    mov edx, 1
    mov ecx, CFG_SIZE
    CALLC SDL_RWread
    mov r13, rax                    ; bytes read (older files are shorter)
    mov rdi, r12
    CALLC SDL_RWclose
    cmp r13, 4+AUTO_ON_N
    jb .o
    mov eax, [settings_buf]
    cmp eax, [settings_magic]
    jne .o
    lea rsi, [settings_buf+4]
    lea rdi, [auto_on]
    mov ecx, AUTO_ON_N
    rep movsb
    ; the settings the file has; newer ones keep their defaults
    lea rdi, [set_music]
    lea rcx, [r13-4-AUTO_ON_N]
    and ecx, ~3
    cmp ecx, SET_N*4
    jbe .n
    mov ecx, SET_N*4
.n:
    rep movsb
.o:
    call apply_volumes
    mov eax, [set_light]
    xor eax, 1
    mov [light_off], eax
    RETURN

; =====================================================================
;  tools
; =====================================================================
; ---------------------------------------------------------------------
;  power lines: a straight run with pylons every few tiles
; ---------------------------------------------------------------------
PYLON_SPAN equ 6
MAX_PL     equ 256

; pline_collect(edi sx, esi sy, edx ex, ecx ey): pylon spots -> tl list
FUNC pline_collect, 32
    mov [rbp-48], edi
    mov [rbp-52], esi
    sub edx, edi
    sub ecx, esi
    mov [rbp-56], edx               ; dx
    mov [rbp-60], ecx               ; dy
    mov eax, edx
    cdq
    xor eax, edx
    sub eax, edx
    mov r8d, eax
    mov eax, ecx
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, r8d
    cmovl eax, r8d
    CLAMP eax, 0, MAX_PL-1
    mov [rbp-64], eax               ; n
    mov [pl_n], eax
    ; points along the line
    xor ebx, ebx
.pt:
    cmp ebx, [rbp-64]
    jg .pick
    mov eax, [rbp-56]
    call .lerp
    add eax, [rbp-48]
    mov [pl_x+rbx*4], eax
    mov eax, [rbp-60]
    call .lerp
    add eax, [rbp-52]
    mov [pl_y+rbx*4], eax
    inc ebx
    jmp .pt
.lerp:                              ; round(eax * ebx / n)
    cmp dword [rbp-64], 0
    je .lz
    imul eax, ebx
    add eax, eax
    mov ecx, [rbp-64]
    test eax, eax
    js .lneg
    add eax, ecx
    cdq
    idiv ecx
    sar eax, 1
    ret
.lneg:
    sub eax, ecx
    cdq
    idiv ecx
    neg eax
    sar eax, 1
    neg eax
    ret
.lz:
    xor eax, eax
    ret
.pick:
    mov edi, [pl_x]
    mov esi, [pl_y]
    call tl_push
    xor r12d, r12d                  ; last pylon
.next:
    cmp r12d, [rbp-64]
    jge .out
    lea r13d, [r12+PYLON_SPAN]
    cmp r13d, [rbp-64]
    jl .srch
    mov r13d, [rbp-64]
    jmp .take
.srch:
    ; farthest good spot within reach
    mov r14d, r13d
.s:
    cmp r14d, r12d
    jle .take                       ; nothing: take the far point anyway
    mov edi, [pl_x+r14*4]
    mov esi, [pl_y+r14*4]
    call pylon_spot_ok
    test eax, eax
    jnz .found
    dec r14d
    jmp .s
.found:
    mov r13d, r14d
.take:
    mov edi, [pl_x+r13*4]
    mov esi, [pl_y+r13*4]
    call tl_push
    mov r12d, r13d
    jmp .next
.out:
    RETURN

; can a pylon stand here (or is one already here)? (edi x, esi y)
pylon_spot_ok:
    call tile_at
    test rax, rax
    jz .n
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .n
    movzx ecx, byte [rax+T_OBJ]
    cmp ecx, OBJ_POWER
    je .y
    cmp ecx, OBJ_TREE
    je .y
    cmp ecx, OBJ_NONE
    jne .n
    cmp byte [rax+T_ZONE], 0
    jne .n                          ; keep zoned lots free
.y: mov eax, 1
    ret
.n: xor eax, eax
    ret

; bulldozer mode -> eax: 0 everything, 1 pipes only, 2 power lines only
; (an explicit choice, else whatever the water / power view shows)
bz_mode:
    mov eax, [bz_filter]
    test eax, eax
    jnz .o
    cmp dword [eff_overlay], OV_WATER
    jne .p0
    mov eax, 1
    ret
.p0:
    cmp dword [eff_overlay], OV_METRO
    jne .p
    mov eax, 3
    ret
.p: cmp dword [eff_overlay], OV_POWER
    jne .o
    mov eax, 2
.o: ret

; road_stretch(edi x, esi y): push the straight run of road through
; this tile, up to and including the next junction or bend each way
FUNC road_stretch, 16
    mov r12d, edi
    mov r13d, esi
    call tile_at
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .out
    movzx ebx, byte [rax+T_SUB]
    mov edi, r12d
    mov esi, r13d
    call tl_push
    ; a junction on its own
    popcnt eax, ebx
    cmp eax, 2
    jg .out
    xor r14d, r14d                  ; direction
.d:
    bt ebx, r14d
    jnc .dn
    mov r15d, r12d
    mov eax, r13d
    mov [rbp-48], eax
    mov dword [rbp-52], 0
.w:
    add r15d, [dir_dx+r14*4]
    mov eax, [dir_dy+r14*4]
    add [rbp-48], eax
    inc dword [rbp-52]
    cmp dword [rbp-52], MAP_W
    jg .dn
    mov edi, r15d
    mov esi, [rbp-48]
    call tile_at
    test rax, rax
    jz .dn
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .dn
    test byte [rax+T_FLAGS], F_HIGHWAY
    jnz .dn
    movzx ecx, byte [rax+T_SUB]
    mov [rbp-56], ecx
    mov edi, r15d
    mov esi, [rbp-48]
    call tl_push
    cmp eax, -1
    je .out
    mov ecx, [rbp-56]
    popcnt eax, ecx
    cmp eax, 2
    jg .dn                          ; junction: included, stop
    bt ecx, r14d
    jnc .dn                         ; bend: included, stop
    jmp .w
.dn:
    inc r14d
    cmp r14d, 4
    jl .d
.out:
    RETURN

; inspector: the road's stretch and one-click upgrades
FUNC inspect_road_upgrade, 32
    mov dword [tl_n], 0
    mov edi, [sel_x]
    mov esi, [sel_y]
    call road_stretch
    ; how much of it is jammed
    xor ebx, ebx
    xor r12d, r12d
.j:
    cmp ebx, [tl_n]
    jge .jd
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    call tile_at
    cmp byte [rax+T_JAM], 150
    jb .jn
    inc r12d
.jn:
    inc ebx
    jmp .j
.jd:
    call tb_reset
    lea rdi, [s_stretch]
    call tb_str
    movsxd rdi, dword [tl_n]
    call tb_num
    lea rdi, [s_tiles]
    call tb_str
    test r12d, r12d
    jz .nj
    lea rdi, [s_stjam1]
    call tb_str
    movsxd rdi, r12d
    call tb_num
    lea rdi, [s_stjam2]
    call tb_str
.nj:
    add dword [row_y], 2
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
    ; a button per other road type, with the price for the stretch
    mov edi, [sel_x]
    mov esi, [sel_y]
    call tile_at
    movzx eax, byte [rax+T_ROADTYPE]
    mov [rbp-48], eax               ; current type
    mov dword [rbp-52], 0           ; buttons drawn
    xor r13d, r13d                  ; target type
.t:
    cmp r13d, 3
    jge .out
    cmp r13d, [rbp-48]
    je .tn
    ; price: sum over the stretch
    mov dword [rbp-56], 0
    xor ebx, ebx
.c:
    cmp ebx, [tl_n]
    jge .cd
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    call tile_at
    test byte [rax+T_FLAGS], F_HIGHWAY
    jnz .cn
    movzx ecx, byte [rax+T_ROADTYPE]
    cmp ecx, r13d
    je .cn
    mov eax, [road_costs+r13*4]
    sub eax, [road_costs+rcx*4]
    cmp eax, 2
    jge .ca
    mov eax, 2
.ca:
    add [rbp-56], eax
.cn:
    inc ebx
    jmp .c
.cd:
    call tb_reset
    mov rdi, [up_names+r13*8]
    call tb_str
    mov edi, ' '
    call tb_char
    ; locked?
    mov ecx, [road_unlock+r13*4]
    call unlocked_pop
    cmp eax, ecx
    jge .open
    mov edi, [road_unlock+r13*4]
    call milestone_for
    mov rdi, [milestone_names+rax*8]
    call tb_str
    mov dword [rbp-60], 1
    jmp .btn
.open:
    movsxd rdi, dword [rbp-56]
    call tb_money
    mov dword [rbp-60], 0
.btn:
    mov eax, [rbp-52]
    imul eax, eax, 88
    mov edi, [row_x]
    lea edi, [rdi+rax+6]
    mov esi, [row_y]
    mov edx, 86
    lea rcx, [textbuf]
    xor r8d, r8d
    call text_button
    inc dword [rbp-52]
    test eax, eax
    jz .tn
    cmp dword [rbp-60], 0
    jne .locked
    ; apply through the upgrade tool (undo, costs, checks all included)
    mov [up_type], r13d
    mov eax, [tool]
    mov [rbp-64], eax
    mov dword [tool], T_UPGRADE
    call tool_apply
    mov eax, [rbp-64]
    mov [tool], eax
    jmp .out
.locked:
    mov edi, [road_unlock+r13*4]
    call tb_unlock_msg
    lea rdi, [textbuf]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
.tn:
    inc r13d
    jmp .t
.out:
    add dword [row_y], 18
    RETURN

; ---------------------------------------------------------------------
;  city issues: what's wrong across the city, click to visit each case
; ---------------------------------------------------------------------
ISSUE_JAM equ 11

FUNC issues_count
    lea rdi, [iss_count]
    xor eax, eax
    mov ecx, 12
    rep stosd
    mov dword [iss_worst], -1
    xor r12d, r12d                  ; worst jam
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    movzx ecx, byte [rdi+T_OBJ]
    cmp ecx, OBJ_ROAD
    jne .b
    test byte [rdi+T_FLAGS], F_HIGHWAY
    jnz .n
    cmp byte [rdi+T_ROADTYPE], RT_HIGHWAY
    je .n
    movzx eax, byte [rdi+T_JAM]
    cmp eax, 200
    jb .n
    inc dword [iss_count+ISSUE_JAM*4]
    cmp eax, r12d
    jbe .n
    mov r12d, eax
    mov [iss_worst], ebx
    jmp .n
.b:
    cmp ecx, OBJ_ZONEBLD
    je .z
    cmp ecx, OBJ_SERVICE
    jne .n
.z:
    test byte [rdi+T_FLAGS], F_ANCHOR
    jz .n
    movzx eax, byte [rdi+T_PROBLEM]
    test eax, eax
    jz .n
    cmp eax, 10
    ja .n
    inc dword [iss_count+rax*4]
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    RETURN

; jump to the next building with issue edi (cycles through them)
FUNC issue_visit
    mov r12d, edi
    cmp r12d, ISSUE_JAM
    jne .p
    mov eax, [iss_worst]
    test eax, eax
    js .out
    jmp .go
.p:
    mov ebx, [iss_next+r12*4]
    xor r13d, r13d
.l:
    inc ebx
    and ebx, MAP_TILES-1
    inc r13d
    cmp r13d, MAP_TILES
    jg .out
    mov eax, ebx
    shl eax, TILE_SHIFT
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .l
    movzx ecx, byte [tiles+rax+T_PROBLEM]
    cmp ecx, r12d
    jne .l
    mov [iss_next+r12*4], ebx
    mov eax, ebx
.go:
    mov edi, eax
    and edi, MAP_W-1
    mov esi, eax
    shr esi, MAP_SHIFT
    mov [sel_x], edi
    mov [sel_y], esi
    call cam_remember_keep
    call camera_center_tile
    mov dword [tool], T_INSPECT
    mov edi, SFX_CLICK
    call sfx_play
.out:
    RETURN

FUNC draw_issues, 16
    cmp dword [welcome], 0
    jne .out
    cmp dword [tool], T_INSPECT
    jne .out
    cmp dword [panel], PANEL_NONE
    jne .out
    ; beta: a steady list, and jams shown on the map
    cmp dword [beta_on], 0
    je .classic
    call draw_issues_beta
    RETURN
.classic:
    dec dword [iss_age]
    jns .d
    mov dword [iss_age], 20
    call issues_count
.d:
    mov r13d, 64                    ; y
    ; biggest first: pick up to 5 by repeated max
    lea rdi, [iss_shown]
    xor eax, eax
    mov ecx, 12
    rep stosd
    mov dword [rbp-48], 0
.pick:
    cmp dword [rbp-48], 5
    jge .out
    xor r12d, r12d                  ; best count
    mov r14d, -1                    ; best issue
    mov ebx, 1
.m:
    cmp dword [iss_shown+rbx*4], 0
    jne .mn
    mov eax, [iss_count+rbx*4]
    cmp eax, r12d
    jle .mn
    mov r12d, eax
    mov r14d, ebx
.mn:
    inc ebx
    cmp ebx, 12
    jl .m
    test r14d, r14d
    js .out
    mov dword [iss_shown+r14*4], 1
    ; one row: glyph, count, name
    call tb_reset
    movsxd rdi, r12d
    call tb_num
    mov edi, ' '
    call tb_char
    mov rdi, [iss_names+r14*8]
    call tb_str
    lea rdi, [textbuf]
    call text_width
    lea r15d, [rax+22]
    mov edi, 4
    mov esi, r13d
    mov edx, r15d
    mov ecx, 13
    call ui_over
    mov [rbp-52], eax
    mov r8d, UI_BG2
    test eax, eax
    jz .bg
    mov r8d, UI_BTN_HI
    lea rax, [s_isstip]
    mov [tooltip], rax
.bg:
    mov edi, 4
    mov esi, r13d
    mov edx, r15d
    mov ecx, 13
    call draw_box
    movzx edx, byte [iss_glyph+r14]
    movzx ecx, byte [iss_col+r14]
    mov edi, 8
    lea esi, [r13+3]
    call draw_glyph
    mov edi, 18
    lea esi, [r13+3]
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call draw_text
    cmp dword [rbp-52], 0
    je .nx
    cmp dword [click_pending], 0
    je .nx
    mov dword [click_pending], 0
    mov edi, r14d
    call issue_visit
.nx:
    add r13d, 15
    inc dword [rbp-48]
    jmp .pick
.out:
    RETURN

; tile index of tl entry ebx -> eax
tl_index:
    mov eax, [tl_y+rbx*4]
    shl eax, MAP_SHIFT
    add eax, [tl_x+rbx*4]
    ret

; is the current tool a line tool / single click tool?
tool_is_line:
    mov eax, [tool]
    cmp eax, T_ROAD
    je .y
    cmp eax, T_UPGRADE
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
    cmp eax, T_LAND
    je .y
    ; beta: rows of small buildings and of bus stops are dragged
    push rax
    push rax
    call drag_places
    mov ecx, eax
    pop rax
    pop rax
    test ecx, ecx
    jnz .n
    cmp eax, T_BUILD
    je .y
    cmp eax, T_BUSSTOP
    je .y
.n: xor eax, eax
    ret
.y: mov eax, 1
    ret

; per-tile validity and cost; fills tl_ok, tl_cost, tl_valid
FUNC tool_evaluate, 32
    mov dword [tl_cost], 0
    mov dword [tl_valid], 0
    mov dword [last_tool_err], 0
    mov dword [tl_blocked], 0
    mov dword [tl_far], 0
    call keys_held
    mov [ev_keys], eax
    cmp dword [tool], T_BUILD
    je .build
    mov dword [pl_n], 0
    cmp dword [drag_active], 0
    je .l0
    cmp dword [tool], T_POWERLN
    jne .l0
    mov eax, [drag_sx]
    sub eax, [hover_tx]
    cdq
    xor eax, edx
    sub eax, edx
    mov ecx, eax
    mov eax, [drag_sy]
    sub eax, [hover_ty]
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, ecx
    cmovl eax, ecx
    mov [pl_n], eax
.l0:
    xor ebx, ebx
.l:
    cmp ebx, [tl_n]
    jge .lend
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    call tile_at
    test rax, rax
    jz .n
    mov r12, rax
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    call tile_owned
    test eax, eax
    jnz .own
    mov dword [last_tool_err], 3
    jmp .n
.own:
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
    je .rw
    ; beta: Ctrl builds through homes, shops and pylons
    call road_through_cost
    cmp eax, -1
    je .n
    add r13d, eax
.rw:
    cmp edx, TER_WATER
    jne .rwl
    imul r13d, r13d, 3              ; bridges
    jmp .set
.rwl:
    ; beta: a pipe underneath
    call road_pipe_cost
    add r13d, eax
    jmp .set
.t1:
    cmp eax, T_POWERLN
    jne .t2
    ; existing pylons and buildings take the wire for free
    xor r13d, r13d
    cmp ecx, OBJ_POWER
    je .set
    cmp ecx, OBJ_ZONEBLD
    je .set
    cmp ecx, OBJ_SERVICE
    je .set
    cmp edx, TER_WATER
    je .n
    mov r13d, PYLON_COST
    cmp ecx, OBJ_TREE
    je .set
    cmp ecx, OBJ_NONE
    jne .n
    jmp .set
.t2:
    cmp eax, T_ZONETOOL
    jne .t3
    cmp edx, TER_WATER
    je .n
    cmp ecx, OBJ_NONE
    je .zok
    cmp ecx, OBJ_TREE
    je .zok
    ; re-zoning: grown buildings of another zone are replaced
    cmp ecx, OBJ_RUBBLE
    je .zok
    cmp ecx, OBJ_ZONEBLD
    jne .n
.zok:
    mov eax, [zone_type]
    cmp al, [r12+T_ZONE]
    je .n
    mov r13d, 5
    ; beta: is it in a road's reach?
    mov edi, [tl_x+rbx*4]
    mov esi, [tl_y+rbx*4]
    call zone_reach_mark
    jmp .set
.t3:
    cmp eax, T_DEZONE
    jne .t4
    cmp byte [r12+T_ZONE], 0
    je .n
    cmp ecx, OBJ_NONE
    je .dz
    cmp ecx, OBJ_RUBBLE
    je .dz
    cmp ecx, OBJ_ZONEBLD
    jne .n
.dz:
    mov r13d, 0
    jmp .set
.t4:
    cmp eax, T_BULLDOZE
    jne .t5
    call bz_mode
    cmp eax, 1
    jne .bzp
    ; pipes only
    test byte [r12+T_FLAGS2], F2_PIPE
    jz .n
    mov r13d, 2
    jmp .set
.bzp:
    cmp eax, 3
    jne .bzp2
    ; metro tunnels only
    test byte [r12+T_MISC], MISC_METRO
    jz .n
    mov r13d, 5
    jmp .set
.bzp2:
    cmp eax, 2
    jne .bzall
    cmp ecx, OBJ_POWER
    jne .n
    mov r13d, 5
    jmp .set
.bzall:
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
    jne .t8
    cmp ecx, OBJ_ROAD
    jne .n
    cmp byte [r12+T_ROADTYPE], RT_HIGHWAY
    je .n
    test byte [r12+T_FLAGS2], F2_BUSSTOP
    jnz .n
    mov r13d, 60
    jmp .set
.t8:
    cmp eax, T_DISTRICT
    jne .t8d
    call dist_tile_cost
    cmp eax, -1
    je .n
    mov r13d, eax
    jmp .set
.t8d:
    cmp eax, T_TRAM
    jne .t8m
    call tram_tile_cost
    cmp eax, -1
    je .n
    mov r13d, eax
    jmp .set
.t8m:
    cmp eax, T_LEVEE
    jne .t8v
    call levee_tile_cost
    cmp eax, -1
    je .n
    mov r13d, eax
    jmp .set
.t8v:
    cmp eax, T_RUNWAY
    jne .t8w
    call runway_tile_cost
    cmp eax, -1
    je .n
    mov r13d, eax
    jmp .set
.t8w:
    cmp eax, T_RAIL
    jne .t8r
    call rail_tile_cost
    cmp eax, -1
    je .n
    mov r13d, eax
    jmp .set
.t8r:
    cmp eax, T_METRO
    jne .t8u
    call metro_tile_cost
    cmp eax, -1
    je .n
    mov r13d, eax
    jmp .set
.t8u:
    cmp eax, T_UPGRADE
    jne .n
    cmp ecx, OBJ_ROAD
    jne .n
    test byte [r12+T_FLAGS], F_HIGHWAY
    jnz .n
    movzx r8d, byte [r12+T_ROADTYPE]
    mov r9d, [up_type]
    cmp r8d, r9d
    je .n
    mov r13d, [road_costs+r9*4]
    sub r13d, [road_costs+r8*4]
    cmp r13d, 2
    jge .set
    mov r13d, 2
    jmp .set
.lend:
    cmp dword [tool], T_POWERLN
    je .plcost
    jmp .out
.set:
    mov byte [tl_ok+rbx], 1
    inc dword [tl_valid]
    add [tl_cost], r13d
.n:
    inc ebx
    jmp .l
.plcost:
    ; cable: a little per tile spanned
    mov eax, [pl_n]
    imul eax, WIRE_COST
    add [tl_cost], eax
    jmp .out

.build:
    cmp dword [tl_n], 0
    je .out
    mov edi, [build_kind]
    call bld_rec
    mov r15, rax
    movzx r14d, byte [r15+BI_SIZE]
    mov eax, [r15+BI_COST]
    mov [tl_cost], eax
    mov ecx, [r15+BI_UNLOCK]
    call unlocked_pop
    cmp eax, ecx
    jge .unl
    mov dword [last_tool_err], 1
    jmp .out
.unl:
    ; beta: over zoned buildings, sliding to where it fits
    cmp dword [beta_on], 0
    je .unl0
    call build_eval_beta
    jmp .out
.unl0:
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
    call tile_owned
    test eax, eax
    jnz .fown
    mov dword [last_tool_err], 3
    jmp .out
.fown:
    mov ecx, [rbp-52]
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
    call undo_begin
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
    call road_clear_tile
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
    movzx eax, byte [r12+T_OBJ]
    cmp eax, OBJ_NONE
    je .pnew
    cmp eax, OBJ_TREE
    jne .pwire
.pnew:
    mov byte [r12+T_OBJ], OBJ_POWER
    mov byte [r12+T_ZONE], 0
    mov byte [r12+T_FLAGS], 0
.pwire:
    ; string a wire back to the previous pylon of this run
    test ebx, ebx
    jz .upd
    cmp byte [tl_ok+rbx-1], 0
    je .upd
    call tl_index
    mov esi, eax
    dec ebx
    call tl_index
    inc ebx
    mov edi, eax
    call add_wire
    jmp .upd
.a2:
    cmp eax, T_ZONETOOL
    jne .a3
    call rezone_clear
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
    call rezone_clear
    mov byte [r12+T_ZONE], 0
    mov byte [r12+T_OBJ], OBJ_NONE
    mov byte [r12+T_LEVEL], 0
    and byte [r12+T_FLAGS], ~F_ANCHOR
    jmp .upd
.a4:
    cmp eax, T_BULLDOZE
    jne .a5
    call bz_mode
    cmp eax, 3
    jne .bzt
    and byte [r12+T_MISC], ~MISC_METRO
    jmp .n                          ; underground: no dust
.bzt:
    cmp eax, 1
    jne .bzq
    and byte [r12+T_FLAGS2], ~F2_PIPE
    jmp .n                          ; underground: no dust
.bzq:
    mov cl, [r12+T_OBJ]
    cmp cl, OBJ_NONE
    jne .bz0
    and byte [r12+T_FLAGS2], ~F2_PIPE
    jmp .upd
.bz0:
    cmp cl, OBJ_SERVICE
    jne .bzz
    ; beta: a service leaves its lot as it found it (zone and all)
    cmp dword [beta_on], 0
    je .bzm
    mov edi, r13d
    mov esi, r14d
    call anchor_of
    mov edi, eax
    mov esi, edx
    mov edx, OBJ_RUBBLE
    call svc_remove
    jmp .upd
.bzz:
    cmp cl, OBJ_ZONEBLD
    jne .bz
.bzm:
    mov edi, r13d
    mov esi, r14d
    call destroy_to_rubble
    jmp .upd
.bz:
    ; a road with a level crossing: the track stays
    cmp byte [r12+T_OBJ], OBJ_ROAD
    jne .bz1
    test byte [r12+T_MISC], MISC_RAILX
    jz .bz1
    and byte [r12+T_MISC], ~MISC_RAILX
    mov byte [r12+T_OBJ], OBJ_RAIL
    mov byte [r12+T_FLAGS], 0
    and byte [r12+T_FLAGS2], F2_PIPE
    mov dword [r12+T_OCC], 0
    jmp .upd
.bz1:
    and byte [r12+T_MISC], ~MISC_TRAM & 0xFF
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
    jne .a6m
    or byte [r12+T_FLAGS2], F2_PIPE
    jmp .n                          ; pipes are underground: no dust
.a6m:
    cmp eax, T_METRO
    jne .a6r
    or byte [r12+T_MISC], MISC_METRO
    jmp .n
.a6r:
    cmp eax, T_RAIL
    jne .a6w
    call rail_lay_tile
    jmp .upd
.a6w:
    cmp eax, T_RUNWAY
    jne .a6v
    call runway_lay_tile
    jmp .upd
.a6v:
    cmp eax, T_LEVEE
    jne .a6t
    call levee_lay_tile
    jmp .upd
.a6t:
    cmp eax, T_DISTRICT
    jne .a6x
    call dist_lay_tile
    jmp .n
.a6x:
    cmp eax, T_TRAM
    jne .a7
    call tram_lay_tile
    mov dword [net_dirty], 1
    jmp .upd
.a7:
    cmp eax, T_BUSSTOP
    jne .a8
    or byte [r12+T_FLAGS2], F2_BUSSTOP
    jmp .upd
.a8:
    cmp eax, T_UPGRADE
    jne .upd
    mov eax, [up_type]
    mov [r12+T_ROADTYPE], al
    cmp eax, RT_AVENUE
    je .upd
    and byte [r12+T_MISC], ~MISC_TRAM & 0xFF
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
    cmp dword [tool], T_ROAD
    je .dr
    cmp dword [tool], T_RUNWAY
    je .drl
    cmp dword [tool], T_RAIL
    jne .dnr
.drl:
    call rail_after
    jmp .dnr
.dr:
    call road_after_beta
.dnr:
    cmp dword [tool], T_BULLDOZE
    jne .snd
    call wires_cleanup
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
    mov edi, [tl_cost]
    call undo_end
    mov dword [net_dirty], 1
    mov dword [cov_dirty], 1
    mov eax, [tool]
    mov edi, SFX_ROAD
    cmp eax, T_ROAD
    je .play
    cmp eax, T_UPGRADE
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
    ; beta: a row of them
    cmp dword [tl_n], 1
    jle .b1
    call build_many
    RETURN
.b1:
    ; beta: clear the spot first (what's built there comes down)
    cmp dword [beta_on], 0
    je .bnb
    mov edi, [tl_x]
    mov esi, [tl_y]
    call bld_clear
.bnb:
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
    ; the zone it stands on, for when it goes
    lea edx, [r13+rbx]
    shl edx, MAP_SHIFT
    add edx, r12d
    add edx, r15d
    mov cl, [rax+T_ZONE]
    mov [svc_zone+rdx], cl
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
    mov edi, [tl_cost]
    call undo_end
    mov edi, SFX_PLACE
    call sfx_play
    call cost_float
    mov edi, [tl_x]
    mov esi, [tl_y]
    call build_placed_beta
    RETURN

.broke:
    lea rdi, [s_nomoney]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
.err:
    cmp dword [last_tool_err], 3
    jne .e1
    lea rdi, [s_notowned]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .e3
.e1:
    cmp dword [last_tool_err], 1
    jne .e2
    mov edi, [build_kind]
    call bld_rec
    mov edi, [rax+BI_UNLOCK]
    call tb_unlock_msg
    lea rdi, [textbuf]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
.e2:
    cmp dword [last_tool_err], 2
    jne .e4
    lea rdi, [s_needwater]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .e3
.e4:
    ; beta: what's in the way
    mov eax, [last_tool_err]
    cmp eax, TE_ROAD
    jb .e3
    cmp eax, TE_WXP
    ja .e3
    mov rdi, [te_msgs+rax*8]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
.e3:
    call road_blocked_msg
    mov edi, SFX_ERROR
    call sfx_play
    RETURN

; ---------------------------------------------------------------------
;  world-side preview of the current tool (drawn into the world fb)
; ---------------------------------------------------------------------
FUNC draw_tool_preview, 16
    call set_target_world
    cmp dword [photo_mode], 0
    jne .out
    call freehand_track
    call route_keep
    call jam_marks
    ; a move ends when the build tool is put down
    cmp dword [tool], T_BUILD
    je .mvk
    mov dword [moving], 0
    mov dword [move_from], -1
.mvk:
    cmp dword [tool], T_LAND
    jne .nland
    cmp dword [welcome], 0
    jne .out
    call land_preview
    jmp .sel
.nland:
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
    cmp dword [tool], T_LAND
    jne .tools2
    call land_preview
    jmp .sel
.tools2:
    call tool_collect
    call tool_evaluate
    cmp dword [tool], T_BUILD
    je .bprev
    cmp dword [tool], T_POWERLN
    je .plprev
    call tl_here_mark
    xor ebx, ebx
.l:
    cmp ebx, [tl_n]
    jge .ldone
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
    cmp eax, T_UPGRADE
    jne .gr
    ; the road as it will look after the upgrade
    mov edi, r12d
    mov esi, r13d
    call tile_at
    movzx eax, byte [rax+T_SUB]
    mov ecx, [up_type]
    shl ecx, 4
    add eax, ecx
    mov edi, [spr_road+rax*4]
    jmp .ghost
.gr:
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
    ; beta: a lot no road reaches won't grow
    mov ecx, RAMP(R_YELLOW, 6)
    cmp byte [tl_farf+rbx], 0
    jne .dia
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
.ldone:
    call tl_here_clear
    jmp .sel
.plprev:
    mov dword [blit_tint], TINT_KEEP
    xor ebx, ebx
.pp:
    cmp ebx, [tl_n]
    jge .sel
    mov r12d, [tl_x+rbx*4]
    mov r13d, [tl_y+rbx*4]
    mov edi, r12d
    mov esi, r13d
    call tile_at
    test rax, rax
    jz .ppn
    cmp byte [tl_ok+rbx], 0
    je .ppbad
    ; wire back to the previous spot
    test ebx, ebx
    jz .ppg
    cmp byte [tl_ok+rbx-1], 0
    je .ppg
    mov dword [wire_front], 1
    mov dword [wire_col], RAMP(R_YELLOW, 7)
    call tl_index
    mov esi, eax
    dec ebx
    call tl_index
    inc ebx
    mov edi, eax
    call draw_wire
    mov dword [wire_front], 0
.ppg:
    mov edi, r12d
    mov esi, r13d
    call tile_at
    cmp byte [rax+T_OBJ], OBJ_POWER
    je .ppn
    cmp byte [rax+T_OBJ], OBJ_NONE
    je .ppghost
    cmp byte [rax+T_OBJ], OBJ_TREE
    jne .ppn
.ppghost:
    mov edi, r12d
    mov esi, r13d
    call tile_screen
    mov esi, eax
    mov edi, [spr_pylon]
    mov ecx, 60000
    lea r8, [remap_bright]
    call blit_sprite
    jmp .ppn
.ppbad:
    mov edi, r12d
    mov esi, r13d
    mov edx, 1
    mov ecx, RAMP(R_RED, 6)
    call draw_diamond
.ppn:
    inc ebx
    jmp .pp
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
    call existing_rings
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
    cmp dword [beta_on], 0
    je .sel
    call build_preview_beta
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
    call tut_maybe_start
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
    ; beta: a car, a train, a plane, a ship: follow it
    call follow_pick
    test eax, eax
    jnz .out
    ; clicking bare land closes the inspector
    mov edi, [hover_tx]
    mov esi, [hover_ty]
    call tile_at
    cmp byte [rax+T_OBJ], OBJ_NONE
    jne .insel
    cmp byte [rax+T_ZONE], 0
    jne .insel
    test byte [rax+T_FLAGS2], F2_PIPE
    jnz .insel
    mov dword [sel_x], -1
    jmp .out
.insel:
    mov edi, [hover_tx]
    mov esi, [hover_ty]
    call anchor_of
    mov [sel_x], eax
    mov [sel_y], edx
    mov edi, SFX_CLICK
    call sfx_play
    jmp .out
.click:
    cmp dword [tool], T_LAND
    jne .click2
    call land_click
    jmp .out
.click2:
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
    cmp dword [free_mode], 0
    je .tn
    lea rdi, [s_sandbox]
.tn:
    call tb_str
    mov edi, 6
    mov esi, 5
    mov ecx, UI_GOLD
    call tb_draw
    lea r12d, [rax+8]
    call ms_progress_bar
    mov [tt_date], r12d
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
    mov [tt_pow], r12d
    lea rdi, [s_bolt]
    mov esi, [power_demand]
    mov edx, [power_supply]
    mov ecx, r12d
    mov r8d, UI_GOOD
    call hud_usage
    lea r12d, [rax+8]
    mov [tt_wat], r12d
    lea rdi, [s_drop]
    mov esi, [water_demand]
    mov edx, [water_supply]
    mov ecx, r12d
    mov r8d, UI_ACCENT
    call hud_usage
    mov [tt_end], eax
    call topbar_tips
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
    push rax
    push rax
    mov edi, [ui_w]
    sub edi, 90
    imul eax, ebx, 22
    add edi, eax
    mov esi, 2
    mov edx, 20
    mov ecx, 14
    call ui_over
    test eax, eax
    jz .spt
    mov rax, [speed_tips+rbx*8]
    mov [tooltip], rax
.spt:
    pop rax
    pop rax
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
    ; features in testing are on: say so in the corner
    cmp dword [beta_on], 0
    je .nbeta
    mov edi, 4
    mov esi, [ui_h]
    sub esi, 12
    lea rdx, [s_beta]
    mov ecx, UI_WARN
    call draw_text
.nbeta:
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
speed_tips dq spt0, spt1, spt2, spt3
spt0 db "Pause (Space)", 0
spt1 db "Normal speed", 0
spt2 db "Fast ( ] )", 0
spt3 db "Fastest", 0
s_tdate  db "Date. The budget settles at the end of each month.", 10
         db 6, "Space pauses, [ and ] change the speed.", 0
s_tmoney db "Treasury", 10, 0
s_tinc   db "Last month: ", 2, "+", 0
s_texp   db 1, " income, ", 3, "-", 0
s_tnet   db 1, " costs", 10, "Net: ", 0
s_tclick db 10, 6, "Click for the budget and loans (F2)", 0
s_tpop   db "Population ", 0
s_tjobs  db 10, "Jobs ", 0
s_tunemp db "   unemployed ", 0
s_tdem   db "Zone demand - bars up: people want more of it", 10, 0
s_tdemn  dq s_tdr, s_tdc, s_tdi, s_tdo
s_tdr    db 2, "Residential ", 0
s_tdc    db 7, "Commercial ", 0
s_tdi    db 4, "Industrial ", 0
s_tdo    db 1, "Office ", 0
s_thap   db "Average happiness ", 0
s_thap2  db 10, 6, "Unhappy people move out and pay less tax.", 10
         db 6, "Services, parks and clean air help.", 0
s_tflow  db "Traffic flow ", 0
s_tflow2 db 10, 6, "How freely cars move. Jams make workers late", 10
         db 6, "and shops run out of goods.", 0
s_tpow   db "Electricity: using ", 0
s_tof    db " of ", 0
s_tpow2  db " MW", 10, 6, "Over 100% the grid browns out.", 0
s_twat   db "Water: using ", 0
s_tsew   db 10, "Sewage: ", 0
s_tsew2  db " of outlet capacity", 10, 6, "Build more pumps or outlets before 100%.", 0
section .bss
tt_date  resd 1
tt_pow   resd 1
tt_wat   resd 1
tt_end   resd 1
tt_buf   resb 320
section .text

; hover tips for the top bar (built fresh each frame)
FUNC topbar_tips
    mov eax, [umy]
    cmp eax, 18
    jge .out
    mov r12d, [umx]
    call tb_reset
    cmp r12d, [tt_date]
    jl .out                         ; the milestone has its own tip
    cmp r12d, 146
    jge .money
    lea rdi, [s_tdate]
    call tb_str
    jmp .show
.money:
    cmp r12d, 220
    jge .pop
    lea rdi, [s_tmoney]
    call tb_str
    lea rdi, [s_tinc]
    call tb_str
    movsxd rdi, dword [income_last]
    call tb_money
    lea rdi, [s_texp]
    call tb_str
    movsxd rdi, dword [expense_last]
    call tb_money
    lea rdi, [s_tnet]
    call tb_str
    mov eax, [income_last]
    sub eax, [expense_last]
    movsxd rdi, eax
    call tb_money
    lea rdi, [s_tclick]
    call tb_str
    cmp dword [click_pending], 0
    je .show
    mov dword [click_pending], 0
    mov dword [panel], PANEL_BUDGET
    jmp .show
.pop:
    cmp r12d, 282
    jge .dem
    lea rdi, [s_tpop]
    call tb_str
    movsxd rdi, dword [population]
    call tb_num
    lea rdi, [s_tjobs]
    call tb_str
    mov eax, [jobs]
    add eax, [jobs+4]
    add eax, [jobs+8]
    add eax, [jobs+12]
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_tunemp]
    call tb_str
    movsxd rdi, dword [unemployed]
    call tb_num
    jmp .show
.dem:
    cmp r12d, 348
    jge .hap
    lea rdi, [s_tdem]
    call tb_str
    xor ebx, ebx
.dl:
    mov rdi, [s_tdemn+rbx*8]
    call tb_str
    movsxd rdi, dword [demand+rbx*4]
    call tb_num
    mov edi, ' '
    call tb_char
    mov edi, ' '
    call tb_char
    inc ebx
    cmp ebx, 4
    jl .dl
    jmp .show
.hap:
    cmp r12d, 388
    jge .flow
    lea rdi, [s_thap]
    call tb_str
    movsxd rdi, dword [happy_avg]
    call tb_pct
    lea rdi, [s_thap2]
    call tb_str
    jmp .show
.flow:
    cmp r12d, [tt_pow]
    jge .pw
    lea rdi, [s_tflow]
    call tb_str
    movsxd rdi, dword [flow_pct]
    call tb_pct
    lea rdi, [s_tflow2]
    call tb_str
    jmp .show
.pw:
    cmp r12d, [tt_wat]
    jge .wt
    lea rdi, [s_tpow]
    call tb_str
    movsxd rdi, dword [power_demand]
    call tb_num
    lea rdi, [s_tof]
    call tb_str
    movsxd rdi, dword [power_supply]
    call tb_num
    lea rdi, [s_tpow2]
    call tb_str
    jmp .show
.wt:
    cmp r12d, [tt_end]
    jg .out
    lea rdi, [s_twat]
    call tb_str
    movsxd rdi, dword [water_demand]
    call tb_num
    lea rdi, [s_tof]
    call tb_str
    movsxd rdi, dword [water_supply]
    call tb_num
    lea rdi, [s_tsew]
    call tb_str
    movsxd rdi, dword [sewage_demand]
    call tb_num
    lea rdi, [s_tof]
    call tb_str
    movsxd rdi, dword [sewage_cap]
    call tb_num
    lea rdi, [s_tsew2]
    call tb_str
.show:
    lea rsi, [textbuf]
    lea rdi, [tt_buf]
    mov ecx, 319
.cp:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    jz .cpd
    inc rsi
    inc rdi
    dec ecx
    jnz .cp
    mov byte [rdi], 0
.cpd:
    lea rax, [tt_buf]
    mov [tooltip], rax
.out:
    RETURN

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
    cmp eax, 100
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
    sub eax, 200
    cmp eax, [panel]
    sete r8b
.sb:
    mov [rbp-56], r8d
    mov edi, r15d
    lea esi, [r13+3]
    mov edx, DOCK_BTN
    mov ecx, DOCK_BTN
    mov r8, [dock_tips+rbx*8]
    call ui_note_button
    mov edi, r15d
    lea esi, [r13+3]
    mov edx, DOCK_BTN
    mov ecx, DOCK_BTN
    mov r8d, [rbp-56]
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
    cmp eax, 100
    jge .c1
    mov [tool], eax
    mov dword [bz_filter], 0
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
    sub eax, 200
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
    cmp ebx, SI_UPGRADE
    jne .t0
    lea rax, [ti_upgrade]
    mov edx, 15
    RETURN
.t0:
    cmp ebx, SI_BUSSTOP
    jg .z
    lea eax, [rbx-SI_STREET]
    mov ecx, [road_unlock+rax*4]
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
    mov ecx, [zone_unlock+rax*4]
    mov rax, [zone_names+rax*8]
.zz:
    RETURN
.u:
    cmp ebx, SI_DIST
    jne .ud1
    xor edx, edx
    lea rax, [ti_dist]
    mov ecx, 1200
    RETURN
.ud1:
    cmp ebx, SI_UNDIST
    jne .ud2
    xor edx, edx
    lea rax, [ti_undist]
    mov ecx, 1200
    RETURN
.ud2:
    cmp ebx, SI_TRAM
    jne .ut
    mov edx, TRM_COST
    lea rax, [ti_tram]
    mov ecx, 2500
    RETURN
.ut:
    cmp ebx, SI_LEVEE
    jne .uv
    mov edx, LV_COST
    lea rax, [ti_levee]
    mov ecx, 2500
    RETURN
.uv:
    cmp ebx, SI_RUNWAY
    jne .uw
    mov edx, RW_COST
    lea rax, [ti_runway]
    mov ecx, AP_UNLOCK
    RETURN
.uw:
    cmp ebx, SI_RAIL
    jne .u0
    mov edx, RL_COST
    lea rax, [ti_rail]
    mov ecx, 9000
    RETURN
.u0:
    cmp ebx, SI_METRO
    jne .u1
    mov edx, MT_COST
    lea rax, [ti_metro]
    mov ecx, 5000
    RETURN
.u1:
    cmp ebx, SI_UNMETRO
    jne .u2
    mov edx, 5
    lea rax, [ti_unmetro]
    RETURN
.u2:
    mov edx, 5
    lea rax, [ti_line]
    cmp ebx, SI_POWERLN
    je .uu
    lea rax, [ti_pipe]
    cmp ebx, SI_PIPE
    je .uu
    mov edx, 2
    lea rax, [ti_unpipe]
    cmp ebx, SI_UNPIPE
    je .uu
    mov edx, 5
    lea rax, [ti_unpower]
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
    jge .ov
    mov edi, ebx
    call submenu_item_info
    call unlocked_pop
    cmp eax, ecx
    jge .t
    mov edi, ecx
    call tb_unlock_msg
    lea rdi, [textbuf]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_ERROR
    call sfx_play
    RETURN
.ov:
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
    cmp ebx, SI_UPGRADE
    jne .s2
    mov dword [tool], T_UPGRADE
    jmp .close
.s2:
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
    mov dword [bz_filter], 0
    mov dword [tool], T_DISTRICT
    mov dword [dist_erase], 0
    cmp ebx, SI_DIST
    je .close
    mov dword [dist_erase], 1
    cmp ebx, SI_UNDIST
    je .close
    mov dword [dist_erase], 0
    mov dword [tool], T_TRAM
    cmp ebx, SI_TRAM
    je .close
    mov dword [tool], T_LEVEE
    cmp ebx, SI_LEVEE
    je .close
    mov dword [tool], T_RUNWAY
    cmp ebx, SI_RUNWAY
    je .close
    mov dword [tool], T_RAIL
    cmp ebx, SI_RAIL
    je .close
    mov dword [tool], T_METRO
    cmp ebx, SI_METRO
    je .close
    mov dword [tool], T_BULLDOZE
    mov dword [bz_filter], 3
    cmp ebx, SI_UNMETRO
    je .close
    mov dword [bz_filter], 0
    mov dword [tool], T_POWERLN
    cmp ebx, SI_POWERLN
    je .close
    mov dword [tool], T_PIPE
    cmp ebx, SI_PIPE
    je .close
    mov dword [tool], T_BULLDOZE
    mov dword [bz_filter], 1
    cmp ebx, SI_UNPIPE
    je .close
    mov dword [bz_filter], 2
    jmp .close
.b:
    mov [build_kind], ebx
    mov dword [tool], T_BUILD
    mov dword [moving], 0
    mov dword [move_from], -1
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
    cmp ebx, SI_UPGRADE
    jne .s2
    cmp dword [tool], T_UPGRADE
    sete al
    RETURN
.s2:
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
    cmp ebx, SI_DIST
    jne .uds
    cmp dword [tool], T_DISTRICT
    jne .o
    cmp dword [dist_erase], 0
    sete al
    RETURN
.uds:
    cmp ebx, SI_UNDIST
    jne .udu
    cmp dword [tool], T_DISTRICT
    jne .o
    cmp dword [dist_erase], 0
    setne al
    RETURN
.udu:
    cmp ebx, SI_TRAM
    jne .utr
    cmp dword [tool], T_TRAM
    sete al
    RETURN
.utr:
    cmp ebx, SI_LEVEE
    jne .ulv
    cmp dword [tool], T_LEVEE
    sete al
    RETURN
.ulv:
    cmp ebx, SI_RUNWAY
    jne .urw
    cmp dword [tool], T_RUNWAY
    sete al
    RETURN
.urw:
    cmp ebx, SI_RAIL
    jne .ur
    cmp dword [tool], T_RAIL
    sete al
    RETURN
.ur:
    cmp ebx, SI_METRO
    jne .um
    cmp dword [tool], T_METRO
    sete al
    RETURN
.um:
    cmp ebx, SI_UNMETRO
    jne .um2
    cmp dword [tool], T_BULLDOZE
    jne .o
    cmp dword [bz_filter], 3
    sete al
    RETURN
.um2:
    cmp ebx, SI_POWERLN
    jne .p
    cmp dword [tool], T_POWERLN
    sete al
    RETURN
.p:
    cmp ebx, SI_PIPE
    jne .p2
    cmp dword [tool], T_PIPE
    sete al
    RETURN
.p2:
    cmp dword [tool], T_BULLDOZE
    jne .o
    mov ecx, 1
    cmp ebx, SI_UNPIPE
    je .p3
    mov ecx, 2
.p3:
    cmp ecx, [bz_filter]
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
    call submenu_list
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
    lea edi, [r12+3]
    mov esi, [rbp-56]
    mov edx, 194
    mov ecx, 15
    mov r8, rax
    call ui_note_button
    mov [rbp-68], edx
    mov [rbp-72], ecx
    mov [rbp-76], r8d
    lea edi, [r12+8]
    mov esi, [rbp-56]
    add esi, 4
    mov rdx, [rbp-64]
    mov ecx, UI_TEXT
    call unlocked_pop
    cmp eax, [rbp-72]
    mov ecx, UI_TEXT
    jge .nm
    mov ecx, UI_DIM
.nm:
    call draw_text
    cmp r14d, SI_OVERLAY
    jge .in
    call tb_reset
    call unlocked_pop
    cmp eax, [rbp-72]
    jge .cost
    mov edi, [rbp-72]
    call milestone_for
    mov rdi, [milestone_names+rax*8]
    call tb_str
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
    mov ecx, [insp_h]
    CLAMP ecx, 60, 320
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
    lea rdi, [s_rail]
    cmp eax, OBJ_RAIL
    je .tstr
    lea rdi, [s_runway]
    cmp eax, OBJ_RUNWAY
    je .tstr
    lea rdi, [s_levee]
    cmp eax, OBJ_LEVEE
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
    mov esi, [row_y]
    mov ecx, UI_GOLD
    call tb_draw
    add dword [row_y], 13
    ; what's wrong, and how to fix it
    movzx eax, byte [rbx+T_PROBLEM]
    test eax, eax
    jz .noprob
    cmp eax, PR_ROUTE
    ja .noprob
    mov [rbp-48], eax
    mov rdx, [prob_fixes+rax*8]
    xor ecx, ecx
.cntl:
    mov al, [rdx]
    inc rdx
    test al, al
    jz .cntd
    cmp al, 10
    jne .cntl
    inc ecx
    jmp .cntl
.cntd:
    imul ecx, 10
    add ecx, 25
    lea edi, [r12+3]
    mov esi, [row_y]
    sub esi, 2
    mov edx, 178
    mov r8d, RAMP(R_RED, 1)
    push rcx
    push rcx
    call draw_box
    pop rcx
    pop rcx
    mov eax, [rbp-48]
    mov rdx, [prob_titles+rax*8]
    mov ecx, UI_BAD
    call row_text
    mov eax, [rbp-48]
    mov rdx, [prob_fixes+rax*8]
    mov edi, [row_x]
    add edi, 6
    mov esi, [row_y]
    mov ecx, UI_TEXT
    call draw_text
    mov eax, [rbp-48]
    mov rdx, [prob_fixes+rax*8]
.cnt2:
    mov al, [rdx]
    inc rdx
    test al, al
    jz .cnt3
    cmp al, 10
    jne .cnt2
    add dword [row_y], 10
    jmp .cnt2
.cnt3:
    add dword [row_y], 16
.noprob:

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
    call supply_inspect             ; (beta: materials)
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
    call metro_inspect
    call rail_inspect
    call airport_inspect
    call port_inspect
    call service_inspect
    call death_inspect
    call tram_inspect
    call hotel_inspect
    call ferry_inspect
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
    test byte [rbx+T_FLAGS], F_HIGHWAY
    jnz .rdone
    call inspect_road_upgrade
.rdone:
    ; beta: where the cars on this road come from and go
    call route_panel
    test byte [rbx+T_MISC], MISC_RAILX
    jz .nrx
    lea rdx, [s_railx]
    mov ecx, UI_ACCENT
    call row_text
.nrx:
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
    ; beta: demolish / replace / move / upgrade
    call insp_actions
    ; size next frame's panel to what was drawn
    mov eax, [row_y]
    sub eax, 42-8
    mov [insp_h], eax
    cmp dword [fight_request], 0
    je .o2
    mov dword [fight_request], 0
    call fight_fire
.o2:
    RETURN
section .bss
fight_request resd 1
bz_filter     resd 1
rect_col      resd 1
ms_tipbuf     resb 96
insp_h        resd 1
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
    ; beta: a long commute holds homes at level 3
    cmp dword [gh_class], ZC_RES
    jne .nlc
    push rcx
    push rcx
    mov edi, r15d
    call commute_too_long
    pop rcx
    pop rcx
    test eax, eax
    jz .nlc
    lea rax, [s_n_commute]
    RETURN
.nlc:
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
    call budget_h
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 350
    call budget_h
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_budget]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    ; beta: the city's difficulty, the neighbours
    lea edi, [r12+230]
    lea esi, [r13+6]
    call budget_difficulty
    lea edi, [r12+128]
    lea esi, [r13+6]
    call region_button
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
    ; hover: what the services cost, by kind
    lea edi, [r12+10]
    lea esi, [r13-11]
    mov edx, 160
    mov ecx, 11
    call ui_over
    test eax, eax
    jz .nsv
    call budget_services_tip
.nsv:
    BROW s_policiesx, exp_policies, UI_BAD
    BROW s_loans, exp_loans, UI_BAD
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
    ; loans
    mov r13d, [rbp-48]
    add r13d, 224
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [s_loans]
    mov ecx, UI_TEXT
    call draw_text
    xor ebx, ebx
.lo:
    imul eax, ebx, 104
    lea r14d, [r12+rax+40]
    call tb_reset
    cmp dword [loan_left+rbx*4], 0
    je .lfree
    movsxd rdi, dword [loan_left+rbx*4]
    call tb_num
    lea rdi, [s_moleft]
    call tb_str
    mov edi, r14d
    lea esi, [r13+1]
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call draw_text
    jmp .lnext
.lfree:
    mov eax, [milestone]
    cmp eax, [loan_ms+rbx*4]
    jge .lopen
    mov eax, [loan_ms+rbx*4]
    mov rdi, [milestone_names+rax*8]
    call tb_str
    mov edi, r14d
    lea esi, [r13+1]
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call draw_text
    jmp .lnext
.lopen:
    lea rdi, [s_borrow]
    call tb_str
    movsxd rdi, dword [loan_amount+rbx*4]
    call tb_money
    mov edi, r14d
    lea esi, [r13-2]
    mov edx, 100
    lea rcx, [textbuf]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .lnext
    mov eax, [loan_months+rbx*4]
    mov [loan_left+rbx*4], eax
    mov edi, ebx
    call loan_taken
    movsxd rax, dword [loan_amount+rbx*4]
    add [money], rax
    call tb_reset
    lea rdi, [s_lntaken]
    call tb_str
    movsxd rdi, dword [loan_amount+rbx*4]
    call tb_money
    lea rdi, [textbuf]
    mov esi, UI_GOLD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_COIN
    call sfx_play
.lnext:
    inc ebx
    cmp ebx, 3
    jl .lo
    ; beta: services' funding
    mov r13d, [rbp-48]
    add r13d, 244
    lea edi, [r12+10]
    mov esi, r13d
    call services_button
    lea edi, [r12+112]
    lea esi, [r13+3]
    call credit_line
    RETURN

; the budget panel's height -> ecx (taller in beta)
budget_h:
    mov ecx, 256
    cmp dword [beta_on], 0
    je .o
    mov ecx, 264
.o: ret

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
    ; policies whose price isn't a monthly bill
    cmp ebx, 2
    jne .k3
    lea rdi, [s_nobus]
    cmp dword [svc_count+BK_BUSDEPOT*4], 0
    je .ks
    lea rdi, [s_lostfare]
    call tb_str
    movsxd rdi, dword [bus_riders]
    call tb_money
    lea rdi, [s_farestr]
    jmp .ks
.k3:
    lea rdi, [s_growth]
    cmp ebx, 3
    je .ks
    lea rdi, [s_indtax]
    cmp ebx, 5
    je .ks
    lea rdi, [s_free]
.ks:
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
    mov ecx, 236
    mov dword [rbp-48], ST_ROWS
    cmp dword [beta_on], 0
    je .sh
    add ecx, 128
    mov dword [rbp-48], ST_ROWS_BETA
.sh:
    mov [rbp-52], ecx
    mov edi, r12d
    mov esi, r13d
    mov edx, 260
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 260
    mov ecx, [rbp-52]
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
    cmp ebx, [rbp-48]
    jl .r
    ; beta: the achievements, the history
    lea edi, [r12+10]
    lea esi, [r13+3]
    call achv_button
    lea edi, [r12+120]
    lea esi, [r13+3]
    call hist_button
    RETURN

; ---------------------------------------------------------------------
;  info view legend
; ---------------------------------------------------------------------
FUNC draw_overlay_legend, 16
    mov eax, [eff_overlay]
    test eax, eax
    jnz .on
    ; the tool has a view the player switched off: offer it back
    mov eax, [auto_view]
    test eax, eax
    jz .out
    call tb_reset
    lea rdi, [s_showview]
    call tb_str
    mov eax, [auto_view]
    mov rdi, [overlay_names+rax*8]
    call tb_str
    lea rdi, [s_vkey]
    call tb_str
    lea rdi, [textbuf]
    call text_width
    lea edx, [rax+12]
    mov r13d, [ui_w]
    shr r13d, 1
    mov edi, edx
    shr edi, 1
    neg edi
    add edi, r13d
    mov esi, 38
    lea rcx, [textbuf]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .out
    call toggle_auto_view
    jmp .out
.on:
    mov rdi, [overlay_names+rax*8]
    mov r12, rdi
    mov r14, [ov_hint+rax*8]
    mov r13d, [ui_w]
    shr r13d, 1
    ; keep clear of the tool hint panel on the left
    cmp r13d, 368
    jge .lx
    mov r13d, 368
.lx:
    lea edi, [r13-160]
    mov esi, 38
    mov edx, 320
    mov ecx, 26
    call draw_panel
    mov edi, r13d
    mov esi, 41
    mov rdx, r12
    mov ecx, UI_TEXT
    call draw_text_centered
    ; opened by the tool? a small switch to keep it closed from now on
    cmp dword [overlay_mode], 0
    jne .hint
    cmp dword [auto_view], 0
    je .hint
    lea edi, [r13+126]
    mov esi, 39
    mov edx, 32
    mov ecx, 11
    call ui_over
    mov [rbp-48], eax
    lea edi, [r13+126]
    mov esi, 39
    mov edx, 32
    mov ecx, 11
    mov r8d, UI_BTN
    cmp dword [rbp-48], 0
    je .hb
    mov r8d, UI_BTN_HI
    lea rax, [s_hidetip]
    mov [tooltip], rax
.hb:
    call draw_box
    lea edi, [r13+129]
    mov esi, 41
    lea rdx, [s_hide]
    mov ecx, UI_DIM
    call draw_text
    cmp dword [rbp-48], 0
    je .hint
    cmp dword [click_pending], 0
    je .hint
    mov dword [click_pending], 0
    call toggle_auto_view
.hint:
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
;  tool hint: what the selected tool does, in plain words
; ---------------------------------------------------------------------
FUNC draw_tool_hint, 16
    cmp dword [welcome], 0
    jne .out
    mov eax, [tool]
    cmp eax, T_INSPECT
    je .out
    xor r14, r14                    ; extra text
    cmp eax, T_BUILD
    je .bld
    cmp eax, T_LAND
    je .land
    cmp eax, T_UPGRADE
    jne .nupg
    lea r12, [ht_upgrade]
    lea r13, [hx_upgrade]
    jmp .draw
.nupg:
    cmp eax, T_BULLDOZE
    jne .nbz
    cmp dword [bz_filter], 0
    je .nbz
    lea r12, [ti_unmetro]
    lea r13, [hx_unmetro]
    cmp dword [bz_filter], 3
    je .draw
    lea r12, [ti_unpipe]
    lea r13, [hx_unpipe]
    cmp dword [bz_filter], 1
    je .draw
    lea r12, [ti_unpower]
    lea r13, [hx_unpower]
    jmp .draw
.nbz:
    cmp eax, T_DISTRICT
    jne .nbzd
    lea r12, [ti_dist]
    lea r13, [hx_dist]
    cmp dword [dist_erase], 0
    je .draw
    lea r12, [ti_undist]
    lea r13, [hx_undist]
    jmp .draw
.nbzd:
    cmp eax, T_TRAM
    jne .nbzt
    lea r12, [ti_tram]
    lea r13, [hx_tram]
    jmp .draw
.nbzt:
    cmp eax, T_LEVEE
    jne .nbzv
    lea r12, [ti_levee]
    lea r13, [hx_levee]
    jmp .draw
.nbzv:
    cmp eax, T_RUNWAY
    jne .nbzw
    lea r12, [ti_runway]
    lea r13, [hx_runway]
    jmp .draw
.nbzw:
    cmp eax, T_RAIL
    jne .nbzr
    lea r12, [ti_rail]
    lea r13, [hx_rail]
    jmp .draw
.nbzr:
    cmp eax, T_METRO
    jne .nbzm
    lea r12, [ti_metro]
    lea r13, [hx_metro]
    jmp .draw
.nbzm:
    cmp eax, T_ZONETOOL
    jne .t
    call zone_demand_text
    lea r14, [textbuf]
    mov eax, [tool]
.t:
    mov r12, [hint_title+rax*8]
    mov r13, [hint_text+rax*8]
    test r13, r13
    jz .out
    jmp .draw
.land:
    call land_hint_text
    lea r12, [ht_land]
    lea r13, [textbuf]
    jmp .draw
.bld:
    call move_hint_title
    test rax, rax
    jz .bld0
    mov r12, rax
    lea r13, [hx_moving]
    xor r14, r14
    jmp .draw
.bld0:
    mov edi, [build_kind]
    call bld_rec
    mov r12, [rax+BI_NAME]
    mov r13, [rax+BI_DESC]
    mov ecx, [build_kind]
    mov r14, [hint_bk+rcx*8]
    test r14, r14
    jnz .draw
    lea r14, [hb_service]
.draw:
    ; count lines
    mov rdi, r13
    call count_lines
    mov ebx, eax
    test r14, r14
    jz .h
    mov rdi, r14
    call count_lines
    add ebx, eax
.h:
    imul ecx, ebx, 10
    add ecx, 19
    cmp dword [tool], T_UPGRADE
    jne .h2
    add ecx, 20                     ; room for the type buttons
.h2:
    ; beta: room for the mode buttons
    push rcx
    push rcx
    call tool_mode_rows
    pop rcx
    pop rcx
    imul eax, eax, 17
    add ecx, eax
    mov [rbp-48], ecx
    mov edi, 4
    mov esi, 42
    mov edx, 196
    call draw_panel
    mov edi, 10
    mov esi, 46
    mov rdx, r12
    mov ecx, UI_GOLD
    call draw_text
    mov edi, 10
    mov esi, 58
    mov rdx, r13
    mov ecx, UI_TEXT
    call draw_text
    test r14, r14
    jz .out
    mov rdi, r13
    call count_lines
    imul esi, eax, 10
    add esi, 58
    mov edi, 10
    mov rdx, r14
    mov ecx, UI_DIM
    call draw_text
.out:
    ; beta: the road and zone modes
    call tool_mode_rows
    test eax, eax
    jz .nmr
    imul eax, eax, 17
    mov edi, [rbp-48]
    add edi, 42-4
    sub edi, eax
    call tool_mode_chips
.nmr:
    cmp dword [tool], T_UPGRADE
    jne .o2
    cmp dword [welcome], 0
    jne .o2
    ; pick what to upgrade to
    xor ebx, ebx
.ub:
    mov eax, [rbp-48]
    lea esi, [rax+42-20]
    imul edi, ebx, 62
    add edi, 10
    mov edx, 58
    mov rcx, [up_names+rbx*8]
    xor r8d, r8d
    cmp ebx, [up_type]
    sete r8b
    call text_button
    test eax, eax
    jz .ubn
    ; highways unlock later
    mov ecx, [road_unlock+rbx*4]
    call unlocked_pop
    cmp eax, ecx
    jl .ubn
    mov [up_type], ebx
.ubn:
    inc ebx
    cmp ebx, 3
    jl .ub
.o2:
    RETURN

; price tag next to the cursor while placing things
FUNC draw_cursor_cost
    cmp dword [welcome], 0
    jne .out
    cmp dword [ui_captured], 0
    jne .out
    cmp dword [hover_valid], 0
    je .out
    mov eax, [tool]
    cmp eax, T_INSPECT
    je .out
    cmp eax, T_LAND
    je .out
    cmp dword [tl_valid], 0
    jne .val
    ; beta: why a building can't go here
    cmp dword [beta_on], 0
    je .out
    cmp eax, T_BUILD
    jne .out
    mov eax, [last_tool_err]
    cmp eax, TE_NEEDW
    jb .out
    cmp eax, TE_WXP
    ja .out
    mov rdi, [te_short+rax*8]
    mov esi, UI_BAD
    xor edx, edx
    call cursor_note
    jmp .out
.val:
    call tb_reset
    movsxd rdi, dword [tl_cost]
    call tb_money
    ; tiles, for line and area tools
    cmp dword [tool], T_BUILD
    je .d
    cmp dword [tl_valid], 1
    jle .d
    mov edi, ' '
    call tb_char
    mov edi, 6
    call tb_char
    movsxd rdi, dword [tl_valid]
    call tb_num
    lea rdi, [s_tiles]
    call tb_str
.d:
    ; beta: the homes a service would reach
    cmp dword [tool], T_BUILD
    jne .d2
    call cov_gain_text
.d2:
    lea rdi, [textbuf]
    call text_width
    lea r12d, [rax+6]
    mov r13d, [umx]
    add r13d, 28
    mov r14d, [umy]
    add r14d, 16
    mov edi, r13d
    mov esi, r14d
    mov edx, r12d
    mov ecx, 12
    mov r8d, UI_BG2
    call draw_box
    mov ecx, UI_GOLD
    movsxd rax, dword [tl_cost]
    cmp rax, [money]
    jle .c
    mov ecx, UI_BAD
.c:
    lea edi, [r13+3]
    lea esi, [r14+2]
    lea rdx, [textbuf]
    call draw_text
    call zone_notes
    ; beta: what comes down to make room
    cmp dword [beta_on], 0
    je .out
    cmp dword [tool], T_BUILD
    jne .out
    call build_repl_text
    test eax, eax
    jz .out
    lea rdi, [textbuf]
    mov esi, UI_WARN
    mov edx, 1
    call cursor_note
.out:
    RETURN

; a note in a box by the cursor (rdi text, esi colour, edx line 0/1)
FUNC cursor_note
    mov r15, rdi
    mov ebx, esi
    imul r12d, edx, 14
    mov rdi, r15
    call text_width
    lea r14d, [rax+6]
    mov r13d, [umx]
    add r13d, 28
    add r12d, [umy]
    add r12d, 16
    mov edi, r13d
    mov esi, r12d
    mov edx, r14d
    mov ecx, 12
    mov r8d, UI_BG2
    call draw_box
    lea edi, [r13+3]
    lea esi, [r12+2]
    mov rdx, r15
    mov ecx, ebx
    call draw_text
    RETURN

; zoning hint: the rules plus how much this zone is wanted right now
FUNC zone_demand_text
    call tb_reset
    lea rdi, [hz_zone]
    call tb_str
    lea rdi, [s_zd1]
    call tb_str
    mov eax, [zone_type]
    movzx eax, byte [zone_class+rax]
    mov ebx, [demand+rax*4]
    lea rdi, [s_zdhi]
    cmp ebx, 40
    jg .s
    lea rdi, [s_zdmid]
    cmp ebx, 10
    jg .s
    lea rdi, [s_zdlo]
.s:
    call tb_str
    RETURN

FUNC budget_services_tip
    call tb_reset
    xor ebx, ebx
.l:
    mov rdi, [cat_names+rbx*8]
    call tb_str
    movsxd rdi, dword [exp_cat+rbx*4]
    call tb_money
    cmp ebx, 7
    je .d
    mov edi, 10
    call tb_char
.d:
    inc ebx
    cmp ebx, 8
    jl .l
    lea rsi, [textbuf]
    lea rdi, [tt_buf]
    mov ecx, 300
    rep movsb
    lea rax, [tt_buf]
    mov [tooltip], rax
    RETURN

; Home: back to the middle of the city (its buildings' centre)
FUNC camera_home
    call cam_remember
    xor ebx, ebx
    xor r12, r12                    ; sum x
    xor r13, r13                    ; sum y
    xor r14d, r14d                  ; count
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ZONEBLD
    jne .n
    mov eax, ebx
    and eax, MAP_W-1
    add r12, rax
    mov eax, ebx
    shr eax, MAP_SHIFT
    add r13, rax
    inc r14d
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    mov edi, 38
    mov esi, 64
    test r14d, r14d
    jz .go
    mov rax, r12
    xor edx, edx
    div r14
    mov edi, eax
    mov rax, r13
    xor edx, edx
    div r14
    mov esi, eax
.go:
    call camera_center_tile
    call camera_clamp
    RETURN

; count_lines(rdi str) -> eax
count_lines:
    mov eax, 1
.l: mov cl, [rdi]
    inc rdi
    test cl, cl
    jz .o
    cmp cl, 10
    jne .l
    inc eax
    jmp .l
.o: ret

; ---------------------------------------------------------------------
;  problem icons above buildings (screen positions from the renderer)
; ---------------------------------------------------------------------
FUNC draw_problem_icons, 32
    ; beta: none while a road's routes, or the metro, are shown
    cmp dword [route_sel], 0
    jge .out
    cmp dword [eff_overlay], OV_METRO
    je .out
    ; beta: none over the spot a building is being placed on
    mov dword [rbp-56], -1000
    mov dword [rbp-60], -1000
    mov dword [rbp-64], 0
    cmp dword [beta_on], 0
    je .nb
    cmp dword [tool], T_BUILD
    jne .nb
    cmp dword [tl_n], 0
    je .nb
    mov edi, [build_kind]
    call bld_rec
    movzx eax, byte [rax+BI_SIZE]
    mov [rbp-64], eax
    mov eax, [tl_x]
    mov [rbp-56], eax
    mov eax, [tl_y]
    mov [rbp-60], eax
.nb:
    xor ebx, ebx
.l:
    cmp ebx, [prob_n]
    jge .out
    ; (in the building's footprint, or a tile around it: skip)
    mov eax, [prob_tile+rbx*4]
    mov ecx, eax
    and ecx, MAP_W-1
    shr eax, MAP_SHIFT
    mov edx, [rbp-64]
    inc edx
    sub ecx, [rbp-56]
    inc ecx
    cmp ecx, 0
    jl .show
    cmp ecx, edx
    jg .show
    sub eax, [rbp-60]
    inc eax
    cmp eax, 0
    jl .show
    cmp eax, edx
    jg .show
    inc ebx
    jmp .l
.show:
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
    ; zoomed right out: a small coloured pip instead of a bubble
    cmp dword [zoom], 1
    jg .big
    lea edi, [r12-2]
    lea esi, [r13+6]
    mov edx, 5
    mov ecx, 5
    mov r8d, UI_BLACK
    call fill_rect
    lea edi, [r12-1]
    lea esi, [r13+7]
    mov edx, 3
    mov ecx, 3
    movzx r8d, byte [prob_col+r14]
    call fill_rect
    inc ebx
    jmp .l
.big:
    ; hover: name the problem, click (inspect tool) to open the building
    mov dword [rbp-52], UI_BG2
    ; hovering names the problem; only the inspect tool takes the click,
    ; so icons never get in the way of building
    mov eax, [umx]
    lea ecx, [r12-5]
    sub eax, ecx
    cmp eax, 11
    jae .bub
    mov eax, [umy]
    sub eax, r13d
    cmp eax, 11
    jae .bub
    cmp dword [tool], T_INSPECT
    jne .nocap
    mov dword [ui_captured], 1
.nocap:
    mov dword [rbp-52], UI_BTN_HI
    mov rax, [prob_titles+r14*8]
    mov [tooltip], rax
    cmp dword [click_pending], 0
    je .bub
    cmp dword [tool], T_INSPECT
    jne .bub
    mov dword [click_pending], 0
    mov eax, [prob_tile+rbx*4]
    mov ecx, eax
    and ecx, MAP_W-1
    shr eax, MAP_SHIFT
    mov [sel_x], ecx
    mov [sel_y], eax
    mov edi, SFX_CLICK
    call sfx_play
.bub:
    lea edi, [r12-5]
    mov esi, r13d
    mov edx, 11
    mov ecx, 11
    mov r8d, [rbp-52]
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
minimap_colour:                     ; -> eax colour, edx priority
    movzx eax, byte [rdi+T_OBJ]
    cmp eax, OBJ_ROAD
    jne .a
    mov edx, 4
    movzx ecx, byte [rdi+T_ROADTYPE]
    mov eax, RAMP(R_GREY, 5)
    cmp ecx, RT_STREET
    je .ar
    mov edx, 7
    mov eax, RAMP(R_WHITE, 7)
    cmp ecx, RT_HIGHWAY
    jne .ar
    mov eax, RAMP(R_YELLOW, 6)
    mov edx, 7
.ar:
    ret
.a: cmp eax, OBJ_ZONEBLD
    jne .a2
    movzx eax, byte [rdi+T_ZONE]
    movzx eax, byte [mini_zone+rax]
    mov edx, 5
    ret
.a2:
    cmp eax, OBJ_SERVICE
    jne .b
    mov eax, RAMP(R_WHITE, 5)
    mov edx, 6
    ret
.b: cmp eax, OBJ_TREE
    jne .c
    mov eax, RAMP(R_LEAF, 2)
    mov edx, 1
    ret
.c: cmp eax, OBJ_NONE
    jne .t
    cmp byte [rdi+T_ZONE], 0
    je .t
    movzx eax, byte [rdi+T_ZONE]
    movzx eax, byte [mini_lot+rax]
    mov edx, 3
    ret
.t: mov edx, 2
    cmp byte [rdi+T_TERRAIN], TER_WATER
    jne .g
    mov eax, RAMP(R_DEEPWATER, 3)
    ret
.g: xor edx, edx
    cmp byte [rdi+T_TERRAIN], TER_SAND
    jne .gg
    mov eax, RAMP(R_SAND, 5)
    ret
.gg:
    mov eax, RAMP(R_GRASS, 4)
    ret
section .data
mini_zone db 0, RAMP(R_ZONER,5), RAMP(R_ZONEC,5), RAMP(R_ZONEI,5), RAMP(R_TEAL,5), RAMP(R_ZONER,3), RAMP(R_ZONEC,3)
mini_lot  db 0, RAMP(R_ZONER,2), RAMP(R_ZONEC,2), RAMP(R_ZONEI,2), RAMP(R_TEAL,2), RAMP(R_ZONER,1), RAMP(R_ZONEC,1)
section .text

; =====================================================================
;  render_ui: everything on the ui layer, in order
; =====================================================================
; =====================================================================
;  progression: land plots, milestone card, unlock messages
; =====================================================================
; "Unlocks at Village (250 people)" into textbuf (edi = population)
FUNC tb_unlock_msg
    mov ebx, edi
    call tb_reset
    lea rdi, [s_locked]
    call tb_str
    mov edi, ebx
    call milestone_for
    mov rdi, [milestone_names+rax*8]
    call tb_str
    mov edi, ' '
    call tb_char
    mov edi, '('
    call tb_char
    movsxd rdi, ebx
    call tb_num
    lea rdi, [s_lockpeop]
    call tb_str
    RETURN

; plot bounds (edi plot) -> r8d x0, r9d y0, r10d x1, r11d y1 (exclusive)
plot_bounds:
    mov eax, edi
    xor edx, edx
    mov ecx, PLOTS
    div ecx                         ; eax row, edx col
    mov ecx, edx
    ; x0 = (col*128 + 4) / 5
    shl ecx, MAP_SHIFT
    add ecx, PLOTS-1
    push rax
    mov eax, ecx
    xor edx, edx
    mov ecx, PLOTS
    div ecx
    mov r8d, eax
    lea eax, [rax]
    pop rax
    push r8
    ; x1 from col+1
    mov ecx, edi
    push rax
    mov eax, ecx
    xor edx, edx
    mov ecx, PLOTS
    div ecx
    lea eax, [rdx+1]
    shl eax, MAP_SHIFT
    add eax, PLOTS-1
    xor edx, edx
    mov ecx, PLOTS
    div ecx
    mov r10d, eax
    pop rax
    ; rows
    mov ecx, eax
    shl ecx, MAP_SHIFT
    add ecx, PLOTS-1
    push rax
    mov eax, ecx
    xor edx, edx
    mov ecx, PLOTS
    div ecx
    mov r9d, eax
    pop rax
    inc eax
    shl eax, MAP_SHIFT
    add eax, PLOTS-1
    xor edx, edx
    mov ecx, PLOTS
    div ecx
    mov r11d, eax
    pop r8
    ret

; screen line in the current target (edi x0, esi y0, edx x1, ecx y1, r8d colour)
FUNC screen_line, 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov [rbp-48], r8d
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
    cmp ebx, eax
    cmovl ebx, eax
    test ebx, ebx
    jz .out
    xor ecx, ecx
.l:
    cmp ecx, ebx
    jg .out
    mov [rbp-52], ecx
    mov eax, r14d
    sub eax, r12d
    imul eax, ecx
    cdq
    idiv ebx
    lea edi, [r12+rax]
    mov ecx, [rbp-52]
    mov eax, r15d
    sub eax, r13d
    imul eax, ecx
    cdq
    idiv ebx
    lea esi, [r13+rax]
    mov edx, [rbp-48]
    push rdi
    push rsi
    call put_pixel
    pop rsi
    pop rdi
    inc esi
    mov edx, [rbp-48]
    call put_pixel
    mov ecx, [rbp-52]
    inc ecx
    jmp .l
.out:
    RETURN

; outline tiles [x0,x1) x [y0,y1) on the ground (r8d..r11d as plot_bounds, [rect_col])
FUNC tile_rect_outline, 48
    mov [rbp-48], r8d
    mov [rbp-52], r9d
    mov [rbp-56], r10d
    mov [rbp-60], r11d
    ; corners: (x0,y0) (x1,y0) (x1,y1) (x0,y1)
    mov edi, r8d
    mov esi, r9d
    call tile_screen
    mov [rbp-64], eax
    mov [rbp-68], edx
    mov edi, [rbp-56]
    mov esi, [rbp-52]
    call tile_screen
    mov [rbp-72], eax
    mov [rbp-76], edx
    mov edi, [rbp-56]
    mov esi, [rbp-60]
    call tile_screen
    mov [rbp-80], eax
    mov [rbp-84], edx
    mov edi, [rbp-48]
    mov esi, [rbp-60]
    call tile_screen
    mov [rbp-88], eax
    mov [rbp-92], edx
    mov edi, [rbp-64]
    mov esi, [rbp-68]
    mov edx, [rbp-72]
    mov ecx, [rbp-76]
    mov r8d, [rect_col]
    call screen_line
    mov edi, [rbp-72]
    mov esi, [rbp-76]
    mov edx, [rbp-80]
    mov ecx, [rbp-84]
    mov r8d, [rect_col]
    call screen_line
    mov edi, [rbp-80]
    mov esi, [rbp-84]
    mov edx, [rbp-88]
    mov ecx, [rbp-92]
    mov r8d, [rect_col]
    call screen_line
    mov edi, [rbp-88]
    mov esi, [rbp-92]
    mov edx, [rbp-64]
    mov ecx, [rbp-68]
    mov r8d, [rect_col]
    call screen_line
    RETURN

; land tool: outline every plot you could buy, price in the middle
FUNC land_preview, 32
    mov dword [blit_tint], TINT_KEEP
    ; hovered plot
    mov dword [rbp-52], -1
    cmp dword [hover_valid], 0
    je .h
    mov edi, [hover_tx]
    mov esi, [hover_ty]
    call plot_of
    mov [rbp-52], eax
.h:
    xor ebx, ebx
.l:
    cmp ebx, PLOTS*PLOTS
    jge .out
    mov edi, ebx
    call plot_status
    mov [rbp-48], eax
    cmp eax, 1
    je .n                           ; owned
    cmp eax, 2
    je .n                           ; not reachable yet
    mov dword [rect_col], RAMP(R_YELLOW, 7)
    cmp eax, 0
    je .c
    mov dword [rect_col], RAMP(R_GREY, 5)
.c:
    cmp ebx, [rbp-52]
    jne .d
    mov dword [rect_col], RAMP(R_WHITE, 7)
.d:
    mov edi, ebx
    call plot_bounds
    push r8
    push r9
    push r10
    push r11
    call tile_rect_outline
    pop r11
    pop r10
    pop r9
    pop r8
    ; price label in the middle
    lea edi, [r8+r10]
    shr edi, 1
    lea esi, [r9+r11]
    shr esi, 1
    call tile_screen
    mov r12d, eax
    lea r13d, [rdx+4]
    call tb_reset
    call plot_price
    movsxd rdi, eax
    call tb_money
    mov edi, r12d
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, RAMP(R_YELLOW, 7)
    cmp dword [rbp-48], 0
    je .pc
    mov ecx, RAMP(R_GREY, 6)
.pc:
    call draw_text_centered
.n:
    inc ebx
    jmp .l
.out:
    RETURN

; land tool click: buy the plot under the cursor
FUNC land_click
    cmp dword [hover_valid], 0
    je .out
    mov edi, [hover_tx]
    mov esi, [hover_ty]
    call plot_of
    mov ebx, eax
    mov edi, ebx
    call plot_status
    test eax, eax
    jz .buy
    lea rdi, [s_lnown]
    cmp eax, 1
    je .msg
    lea rdi, [s_lnext]
    cmp eax, 2
    je .msg
    lea rdi, [s_lms]
    cmp eax, 3
    je .msg
    lea rdi, [s_lcash]
.msg:
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_ERROR
    call sfx_play
    jmp .out
.buy:
    call plot_price
    movsxd rax, eax
    sub [money], rax
    mov byte [plot_owned+rbx], 1
    lea rdi, [s_bought]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_COIN
    call sfx_play
    ; confetti over the new land
    mov edi, ebx
    call plot_bounds
    lea edi, [r8+r10]
    shr edi, 1
    lea esi, [r9+r11]
    shr esi, 1
    mov edx, 8
    mov ecx, PK_DUST
    mov r8d, 3
    call fx_burst
.out:
    RETURN

; land tool hint text into textbuf
FUNC land_hint_text
    call tb_reset
    lea rdi, [s_lh1]
    call tb_str
    lea rdi, [s_lh2]
    call tb_str
    call plots_owned
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_lh3]
    call tb_str
    call plots_allowed
    movsxd rdi, eax
    call tb_num
    call plots_owned
    mov ebx, eax
    call plots_allowed
    cmp ebx, eax
    jl .price
    lea rdi, [s_lh5]
    cmp ebx, PLOTS*PLOTS
    jl .more
    lea rdi, [s_lh6]
.more:
    call tb_str
    RETURN
.price:
    lea rdi, [s_lh4]
    call tb_str
    call plot_price
    movsxd rdi, eax
    call tb_money
    RETURN

; progress toward the next milestone, under its name (edi.. from topbar)
FUNC ms_progress_bar
    call ms_top
    mov ecx, eax
    mov eax, [milestone]
    cmp eax, ecx
    jge .out
    mov r12d, [milestone_pop+rax*4]
    mov r13d, [milestone_pop+rax*4+4]
    mov eax, [population]
    sub eax, r12d
    CLAMP eax, 0, 0x7fffff
    imul eax, 60
    mov ecx, r13d
    sub ecx, r12d
    xor edx, edx
    div ecx
    CLAMP eax, 0, 60
    mov ebx, eax
    mov edi, 6
    mov esi, 14
    mov edx, 60
    mov ecx, 2
    mov r8d, UI_BG2
    call fill_rect
    mov edi, 6
    mov esi, 14
    mov edx, ebx
    mov ecx, 2
    mov r8d, UI_GOLD
    call fill_rect
    ; hover: what's next
    mov edi, 0
    mov esi, 0
    mov edx, 70
    mov ecx, 18
    call ui_over
    test eax, eax
    jz .out
    call tb_reset
    lea rdi, [s_msnext]
    call tb_str
    mov eax, [milestone]
    mov rdi, [milestone_names+rax*8+8]
    call tb_str
    lea rdi, [s_msat]
    call tb_str
    movsxd rdi, r13d
    call tb_num
    lea rdi, [s_people]
    call tb_str
    lea rax, [ms_tipbuf]
    lea rsi, [textbuf]
.cp:
    mov cl, [rsi]
    mov [rax], cl
    inc rsi
    inc rax
    test cl, cl
    jnz .cp
    lea rax, [ms_tipbuf]
    mov [tooltip], rax
.out:
    RETURN

; the milestone card: what you just unlocked
FUNC draw_ms_card, 32
    mov eax, [ms_card]
    test eax, eax
    jz .out
    cmp dword [welcome], 0
    jne .out
    cmp dword [sandbox], 0
    jne .out
    cmp dword [panel], PANEL_NONE
    jne .out
    mov [rbp-48], eax
    mov edi, [milestone_pop+rax*4]
    mov [rbp-52], edi
    mov r12d, [ui_w]
    sub r12d, 240
    shr r12d, 1
    mov r13d, 60
    mov edi, r12d
    mov esi, r13d
    mov edx, 240
    mov ecx, 200
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 240
    mov ecx, 200
    call ui_over
    lea edi, [r12+120]
    lea esi, [r13+8]
    lea rdx, [s_mscard]
    mov ecx, UI_DIM
    call draw_text_centered
    mov dword [font_scale], 2
    mov eax, [rbp-48]
    mov rdx, [milestone_names+rax*8]
    lea edi, [r12+120]
    lea esi, [r13+20]
    mov ecx, UI_GOLD
    call draw_text_centered
    mov dword [font_scale], 1
    call tb_reset
    lea rdi, [s_msrew]
    call tb_str
    mov eax, [rbp-48]
    movsxd rdi, dword [milestone_cash+rax*4]
    call tb_money
    lea edi, [r12+120]
    lea esi, [r13+44]
    lea rdx, [textbuf]
    mov ecx, UI_GOOD
    call draw_text_centered
    lea edi, [r12+120]
    lea esi, [r13+56]
    lea rdx, [s_msland]
    cmp dword [ms_card], 9
    jl .land1
    lea rdx, [s_msland9]
.land1:
    mov ecx, UI_TEXT
    call draw_text_centered
    lea edi, [r12+12]
    lea esi, [r13+74]
    lea rdx, [s_msunl]
    mov ecx, UI_ACCENT
    call draw_text
    ; list everything that unlocks at this population, two columns
    mov dword [rbp-56], 0           ; row counter
    xor ebx, ebx
.b:
    cmp ebx, BK_COUNT
    jge .zones
    ; (buildings still in testing only with ?beta)
    cmp ebx, BK_FIRST_BETA
    jl .bb
    cmp dword [beta_on], 0
    je .bn
.bb:
    mov edi, ebx
    call bld_rec
    mov ecx, [rax+BI_UNLOCK]
    cmp ecx, [rbp-52]
    jne .bn
    mov rdx, [rax+BI_NAME]
    call .item
.bn:
    inc ebx
    jmp .b
.zones:
    xor ebx, ebx
.z:
    cmp ebx, 7
    jge .roads
    mov ecx, [zone_unlock+rbx*4]
    cmp ecx, [rbp-52]
    jne .zn
    test ecx, ecx
    jz .zn
    mov rdx, [zone_names+rbx*8]
    call .item
.zn:
    inc ebx
    jmp .z
.roads:
    xor ebx, ebx
.r:
    cmp ebx, 4
    jge .btn
    mov ecx, [road_unlock+rbx*4]
    cmp ecx, [rbp-52]
    jne .rn
    test ecx, ecx
    jz .rn
    mov rdx, [tool_item_names+rbx*8]
    call .item
.rn:
    inc ebx
    jmp .r
.btn:
    ; loans that open up
    lea edi, [r12+85]
    lea esi, [r13+178]
    mov edx, 70
    lea rcx, [s_msok]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .out
    mov dword [ms_card], 0
.out:
    RETURN
.item:                              ; rdx name
    mov eax, [rbp-56]
    mov ecx, eax
    and ecx, 1
    imul ecx, ecx, 112
    lea edi, [r12+rcx+16]
    shr eax, 1
    imul eax, eax, 11
    lea esi, [r13+rax+88]
    mov ecx, UI_TEXT
    push rbx
    push rbx
    call draw_text
    pop rbx
    pop rbx
    inc dword [rbp-56]
    ret

FUNC render_ui
    call ui_note_reset
    call web_import_poll
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
    ; beta: photo mode - nothing over the city
    cmp dword [photo_mode], 0
    je .nphoto
    call photo_draw
    jmp .out
.nphoto:
    call draw_problem_icons
    call draw_floats
    call region_labels
    call follow_draw
    call scen_draw
    call dist_labels
    call draw_dist_bar
    cmp dword [welcome], 0
    je .game
    call draw_welcome
    jmp .cursor
.game:
    cmp dword [slots_start], 0
    je .gs
    cmp dword [panel], PANEL_LOAD
    je .gs
    mov dword [slots_start], 0
    mov dword [welcome], 1
    jmp .ui
.gs:
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
    jne .p6
    call draw_stats
    jmp .hud
.p6:
    cmp eax, PANEL_SETTINGS
    jne .p6r
    call draw_settings
    jmp .hud
.p6r:
    cmp eax, PANEL_REGION
    jne .p6s
    call draw_region
    jmp .hud
.p6s:
    cmp eax, PANEL_SERVICES
    jne .p6a
    call draw_services
    jmp .hud
.p6a:
    cmp eax, PANEL_ACHV
    jne .p6h
    call draw_achievements
    jmp .hud
.p6h:
    cmp eax, PANEL_HIST
    jne .p6c
    call draw_history
    jmp .hud
.p6c:
    cmp eax, PANEL_SCEN
    jne .p7
    call draw_scenarios
    jmp .hud
.p7:
    cmp eax, PANEL_SAVE
    je .p8
    cmp eax, PANEL_LOAD
    jne .hud
.p8:
    ; modal: only the top bar and the picker
    call draw_topbar
    call draw_slots
    jmp .tip
.hud:
    call draw_topbar
    cmp dword [sel_x], 0
    jge .nogoal
    call draw_goal
    call draw_issues
.nogoal:
    call draw_notifications
    call draw_submenu
    call draw_dock
    cmp dword [tool], T_INSPECT
    jne .noinsp
    call draw_inspect
    call draw_replace_list
.noinsp:
    cmp dword [tut_step], 0         ; the tour's card explains instead
    jge .nohint
    call draw_tool_hint
.nohint:
    call draw_minimap
    call draw_ms_card
    call draw_overlay_legend
    call draw_cursor_cost
    call draw_tutorial
.tip:
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
    ; multi-line tips grow upward; near the top they hang below the cursor
    push rdx
    push rdx
    mov rdi, r12
    call count_lines
    pop rdx
    pop rdx
    imul ecx, eax, 10
    add ecx, 3
    mov esi, [umy]
    sub esi, ecx
    sub esi, 5
    cmp esi, 20
    jge .ty
    mov esi, [umy]
    add esi, 24
.ty:
    mov r14d, esi
    mov edi, r13d
    mov r8d, UI_BG2
    call draw_box
    lea edi, [r13+4]
    lea esi, [r14+3]
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
tool_icon db ICON_INSPECT, ICON_BULLDOZE, ICON_ROAD, ICON_POWERLINE, ICON_ZONE_R, ICON_WATER, ICON_BUS, ICON_DEZONE, ICON_POWER, ICON_TREE, ICON_LAND, ICON_ROAD, ICON_BUS, ICON_ROAD
section .text

; =====================================================================
;  keyboard
; =====================================================================
FUNC ui_key
    mov eax, edi
    ; Ctrl+Z: undo (beta: Ctrl+Shift+Z and Ctrl+Y redo)
    cmp eax, SC_Z
    jne .nz0
    test dword [key_mod], 0xC0
    jz .nz0
    cmp dword [beta_on], 0
    je .undo
    test dword [key_mod], 3
    jz .undo
    call redo_do
    jmp .out
.undo:
    call undo_do
    jmp .out
.nz0:
    cmp eax, SC_Y
    jne .ny0
    test dword [key_mod], 0xC0
    jz .ny0
    cmp dword [beta_on], 0
    je .ny0
    call redo_do
    jmp .out
.ny0:
    ; beta: photo mode (F; Esc also leaves it)
    cmp dword [beta_on], 0
    je .nph
    cmp eax, SC_F
    jne .nph1
    test dword [key_mod], 0xC0
    jnz .nph
    call photo_toggle
    jmp .out
.nph1:
    cmp eax, SC_ESCAPE
    jne .nph
    cmp dword [follow_kind], 0
    je .nph2
    mov dword [follow_kind], 0
    jmp .out
.nph2:
    cmp dword [photo_mode], 0
    je .nph
    call photo_toggle
    jmp .out
.nph:
    cmp eax, SC_ESCAPE
    jne .k1
    cmp dword [welcome], 0
    je .e1
    mov dword [welcome], 0
    call tut_maybe_start
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
    ; beta: Ctrl+1..4 marks the view, Shift+1..4 goes back to it
    push rax
    push rax
    mov edi, eax
    call bookmark_key
    mov ecx, eax
    pop rax
    pop rax
    test ecx, ecx
    jnz .out
    ; zones 1..6
    cmp eax, SC_1
    jl .nz
    cmp eax, SC_1+5
    jg .nz
    sub eax, SC_1
    movzx eax, byte [key_zone+rax]
    lea edi, [rax+SI_ZONE]
    call submenu_select
    jmp .out
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
    mov ecx, T_LAND
    cmp eax, SC_K
    je .settool
    mov ecx, T_UPGRADE
    cmp eax, SC_U
    je .settool
    cmp eax, SC_HOME
    jne .nhome
    call camera_home
    jmp .out
.nhome:
    cmp eax, SC_H
    jne .nh
    mov eax, [set_xray]
    inc eax
    cmp eax, 3
    jl .h1
    xor eax, eax
.h1:
    mov [set_xray], eax
    call settings_save
    mov rdi, [s_xr_names+rax*8]
    call tb_reset
    push rdi
    push rdi
    lea rdi, [s_st_xray]
    call tb_str
    pop rdi
    pop rdi
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_TEXT
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .out
.nh:
    cmp eax, SC_G
    jne .ng
    call tool_next_mode
    jmp .out
.ng:
    cmp eax, SC_E
    jne .ne
    call eyedropper
    jmp .out
.ne:
    cmp eax, SC_BACKSPACE
    jne .nbk
    call cam_back
    jmp .out
.nbk:
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
    cmp eax, SC_V
    jne .kv
    call toggle_auto_view
    jmp .out
.kv:
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
    call open_load_panel
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
    je .tp
    ; beta: the neighbours
    cmp dword [beta_on], 0
    je .k13
    mov ecx, PANEL_REGION
    cmp eax, SC_C
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
    mov dword [bz_filter], 0
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
