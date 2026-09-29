; =====================================================================
;  SIM - the city simulation
;
;  A day passes every DAY_TICKS[speed] ticks.  Each day:
;    * construction, fires, garbage and shop stock tick for every tile
;    * one eighth of the map runs the zone growth model
;    * statistics, workforce and demand are recomputed
;  every 4 days the utility networks are re-flooded (power, pipes,
;  sewage, road links) and every 8 days the coverage / pollution /
;  noise / crime / land value / traffic maps are rebuilt.
;  Month end settles the budget, policies and milestones.
; =====================================================================

OV_NONE     equ 0
OV_POWER    equ 1
OV_WATER    equ 2
OV_POLLUTE  equ 3
OV_NOISE    equ 4
OV_CRIME    equ 5
OV_LANDVAL  equ 6
OV_TRAFFIC  equ 7
OV_POLICE   equ 8
OV_FIRE     equ 9
OV_HEALTH   equ 10
OV_EDU      equ 11
OV_GARBAGE  equ 12
OV_TRANSIT  equ 13
OV_HAPPY    equ 14
OV_RESOURCE equ 15
OV_DESIRE_R equ 16      ; tool context overlays (zone desirability)
OV_DESIRE_C equ 17
OV_DESIRE_I equ 18
OV_DESIRE_O equ 19
OV_LAND     equ 20
OV_COUNT    equ 16      ; user-cyclable overlays

MISC_NET    equ 1       ; road reaches the outside
MISC_NEARW  equ 2

; policies
P_SMOKE     equ 1
P_RECYCLE   equ 2
P_FREEBUS   equ 4
P_HIGHRISE  equ 8
P_BIKE      equ 16
P_FILTERS   equ 32
P_EDUBOOST  equ 64
P_PARKS     equ 128
POLICY_COUNT equ 8

MAX_LIST    equ 8192

section .bss
alignb 16
map_lv          resb MAP_TILES
map_pol         resb MAP_TILES
map_crime       resb MAP_TILES
map_police      resb MAP_TILES
map_fire        resb MAP_TILES
map_health      resb MAP_TILES
map_elem        resb MAP_TILES
map_high        resb MAP_TILES
map_uni         resb MAP_TILES
map_park        resb MAP_TILES
map_garb        resb MAP_TILES
map_transit     resb MAP_TILES
map_noise       resb MAP_TILES
map_traffic     resb MAP_TILES      ; scratch
map_wpol        resb MAP_TILES
map_scenic      resb MAP_TILES
map_powerarea   resb MAP_TILES      ; 1 = a building here would get power
map_waterarea   resb MAP_TILES      ; bit0 served by pipes, bit1 live pipe
alignb 16
wire_head       resd MAP_TILES
wire_next       resd MAX_WIRES*2
wire_to         resd MAX_WIRES*2
alignb 16
comp_map        resw MAP_TILES
road_comp       resw MAP_TILES      ; which region-linked road network
cons_comp       resw MAP_TILES
bfs_queue       resw MAP_TILES+16
MAX_COMPS equ 4096
comp_supply     resd MAX_COMPS
comp_demand     resd MAX_COMPS
comp_sewcap     resd MAX_COMPS
comp_dirty      resb MAX_COMPS
alignb 16
list_res        resw MAX_LIST
list_com        resw MAX_LIST
list_ind        resw MAX_LIST
list_off        resw MAX_LIST
list_svc        resw 1024
n_res           resd 1
n_com           resd 1
n_ind           resd 1
n_off           resd 1
n_svc           resd 1

; ---- saved state block ----
money           resq 1
sim_speed       resd 1
day_timer       resd 1
day             resd 1
month           resd 1
year            resd 1
day_count       resd 1
tax_rate        resd 4          ; per zone class
policies        resd 1
; -- cleared every stats pass (population .. cnt_nogoods) --
population      resd 1
workers         resd 1
edu_workers     resd 1
hedu_workers    resd 1
jobs            resd 4          ; per zone class
jobs_c          resd 1
jobs_i          resd 1
unemployed      resd 1
cnt_r           resd 1
cnt_c           resd 1
cnt_i           resd 1
cnt_o           resd 1
cnt_abandon     resd 1
cnt_fire        resd 1
cnt_unpowered   resd 1
cnt_nowater     resd 1
cnt_noroad      resd 1
cnt_garbage     resd 1
cnt_nogoods     resd 1
; --
staff_basic     resd 1          ; 0..256
staff_edu       resd 1
staff_hedu      resd 1
demand          resd 4          ; -100..100 per zone class
happy_avg       resd 1
power_supply    resd 1
power_demand    resd 1
water_supply    resd 1
water_demand    resd 1
sewage_cap      resd 1
sewage_demand   resd 1
avg_traffic     resd 1
avg_pollution   resd 1
avg_crime       resd 1
avg_edu         resd 1
ext_demand      resd 1
landfill_used   resd 1
landfill_cap    resd 1
garbage_total   resd 1
income_last     resd 1
expense_last    resd 1
inc_class       resd 4
inc_other       resd 1          ; fares, tourism, exports
exp_roads       resd 1
exp_services    resd 1
exp_policies    resd 1
exports_month   resd 1
fares_month     resd 1
road_tiles      resd 1
road_cost       resd 1
svc_count       resd BK_COUNT
milestone       resd 1
hist_pop        resd 64
hist_money      resd 64
hist_count      resd 1
net_dirty       resd 1
cov_dirty       resd 1
disasters_on    resd 1
goal_index      resd 1
brownout_warned resd 1
water_warned    resd 1
sewage_warned   resd 1
garbage_warned  resd 1
island_warned   resd 1
landfull_warned resd 1
trips_ok        resd 1
trips_failed    resd 1
commute_sum     resd 1
commute_n       resd 1
avg_commute     resd 1
flow_pct        resd 1
bus_riders      resd 1
riders_month    resd 1
n_wires         resd 1
wire_a          resw MAX_WIRES
wire_b          resw MAX_WIRES
plot_owned      resb PLOTS*PLOTS+7      ; land you can build on
exp_loans       resd 1
loan_left       resd 3                  ; months still to pay per loan
ms_card         resd 1                  ; milestone card to show (0 none)
free_mode       resd 1                  ; a sandbox city: money never runs out
sim_state_end:
exp_cat         resd 8          ; upkeep per service category (not saved)

demand_r equ demand
demand_c equ demand+4
demand_i equ demand+8
demand_o equ demand+12

section .data
DAY_TICKS   dd 0, 30, 14, 5
; residents / jobs by zone type (row = zone) and level
zone_pop:
    dd 0, 0, 0, 0, 0, 0
    dd 0, 6, 10, 14, 18, 24         ; R low
    dd 0, 4, 8, 12, 16, 20          ; C low
    dd 0, 10, 20, 34, 50, 70        ; I
    dd 0, 16, 34, 70, 130, 240      ; O
    dd 0, 20, 45, 90, 170, 320      ; R high
    dd 0, 14, 30, 60, 110, 190      ; C high
zone_class  db 0, ZC_RES, ZC_COM, ZC_IND, ZC_OFF, ZC_RES, ZC_COM
ind_poll    db 0, 35, 50, 75, 100, 20
spec_poll   db 0, 8, 25, 45
use_power   dd 0, 2, 3, 6, 12, 24
use_water   dd 0, 2, 3, 6, 12, 24
cov_strength db 0, 220, 220, 200, 200, 200, 220, 150, 255, 0
bld_cov_boost db 0,0,0,0,0,0,0,0,0, 0,0,0,40, 0,20,50, 0, 0,20,40,20,60
policy_cost_div dd 100, 80, 0, 0, 150, 0, 60, 120
; which services stop working without power
svc_needs_power db 0,0,0,0, 1,1,0, 0,1, 1,1,1,1, 1,1,1, 1, 0,0,1,1,1

milestone_pop   dd 0, 60, 250, 600, 1200, 2500, 5000, 9000, 16000, 30000, 0x7fffffff
milestone_cash  dd 0, 1000, 2000, 3500, 5000, 8000, 12000, 16000, 25000, 50000, 0
; loans: amount, monthly payment, months, milestone needed
loan_amount     dd 10000, 30000, 80000
loan_payment    dd 460, 720, 1050
loan_months     dd 24, 48, 96
loan_ms         dd 0, 2, 4
milestone_names dq ms0, ms1, ms2, ms3, ms4, ms5, ms6, ms7, ms8, ms9, ms9
ms0 db "Empty Land", 0
ms1 db "Hamlet", 0
ms2 db "Village", 0
ms3 db "Town", 0
ms4 db "Large Town", 0
ms5 db "City", 0
ms6 db "Large City", 0
ms7 db "Capital", 0
ms8 db "Metropolis", 0
ms9 db "Megalopolis", 0

month_names db "Jan",0,"Feb",0,"Mar",0,"Apr",0,"May",0,"Jun",0
            db "Jul",0,"Aug",0,"Sep",0,"Oct",0,"Nov",0,"Dec",0

msg_brownout db "Brownout! Your city needs more power.", 0
msg_nowater  db "Not enough water - build pumps and pipes.", 0
msg_nosewage db "Sewage is backing up - build a sewage outlet.", 0
msg_garbage  db "Garbage is piling up - build a landfill or incinerator nearby.", 0
msg_fire     db "Fire! A building is burning.", 0
msg_fire_out db "Firefighters put out a blaze.", 0
msg_burned   db "A building burned down.", 0
msg_milestone db "MILESTONE: ", 0
msg_reward   db "  Reward: ", 0
msg_broke    db "The treasury is empty! Raise taxes or cut costs.", 0
msg_meteor   db "A METEOR has struck the city!", 0
msg_boom     db "Industrial boom! Exports surge.", 0
msg_newyear  db "Happy new year! Year ", 0
msg_landfull db "The landfill is full! Build another, or an incinerator.", 0
msg_island   db "A power plant isn't connected to anything - use power lines.", 0

section .text

%macro WARN_ONCE 3      ; flag var, message, colour  (eax = 1 when bad)
    test eax, eax
    jz %%ok
    cmp dword [%1], 0
    jne %%done
    cmp dword [tut_bubble], 0       ; quiet during the tour's practice village
    jne %%done
    mov dword [%1], 1
    lea rdi, [%2]
    mov esi, %3
    mov edx, -1
    mov ecx, -1
    call notify
    jmp %%done
%%ok:
    mov dword [%1], 0
%%done:
%endmacro

; ---------------------------------------------------------------------
FUNC sim_init
    mov qword [money], 30000
    ; the starting plot (or everything in the sandbox modes)
    lea rdi, [plot_owned]
    xor eax, eax
    cmp dword [sandbox], 0
    je .po
    mov eax, 0x01010101
.po:
    mov ecx, (PLOTS*PLOTS+7)/4
    rep stosd
    mov byte [plot_owned+START_PLOT], 1
    mov dword [sim_speed], 1
    mov dword [tax_rate], 9
    mov dword [tax_rate+4], 9
    mov dword [tax_rate+8], 9
    mov dword [tax_rate+12], 9
    mov dword [year], 2026
    mov dword [month], 2
    mov dword [day], 0
    mov dword [ext_demand], 35
    mov dword [net_dirty], 1
    mov dword [cov_dirty], 1
    mov dword [disasters_on], 1
    mov dword [demand], 60
    mov dword [demand+4], 10
    mov dword [demand+8], 40
    mov dword [demand+12], 0
    mov dword [staff_basic], 256
    mov dword [flow_pct], 100
    call scenic_init
    call networks_update
    call coverage_update
    call stats_update
    RETURN

; scenic value: water and forest nearby raise land value forever
FUNC scenic_init
    xor r13d, r13d
.y:
    xor r12d, r12d
.x:
    xor ebx, ebx
    mov r14d, -3
.dy:
    mov r15d, -3
.dx:
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call tile_at
    test rax, rax
    jz .n
    cmp byte [rax+T_TERRAIN], TER_WATER
    jne .nw
    add ebx, 5
.nw:
    cmp byte [rax+T_OBJ], OBJ_TREE
    jne .n
    add ebx, 2
.n:
    inc r15d
    cmp r15d, 3
    jle .dx
    inc r14d
    cmp r14d, 3
    jle .dy
    CLAMP ebx, 0, 90
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    mov [map_scenic+rax], bl
    inc r12d
    cmp r12d, MAP_W
    jl .x
    inc r13d
    cmp r13d, MAP_W
    jl .y
    RETURN

; ---------------------------------------------------------------------
FUNC sim_tick
    mov eax, [sim_speed]
    test eax, eax
    jz .out
    inc dword [day_timer]
    mov ecx, [DAY_TICKS+rax*4]
    cmp [day_timer], ecx
    jl .out
    mov dword [day_timer], 0
    call sim_day
.out:
    RETURN

FUNC sim_day
    PERF_MARK -1
    inc dword [day_count]
    ; a sandbox city never runs out of money
    cmp dword [free_mode], 0
    je .nf
    cmp qword [money], 500000
    jge .nf
    mov qword [money], 1000000
.nf:
    call daily_tiles
    PERF_MARK 20
    mov eax, [day_count]
    and eax, 7
    shl eax, 4
    mov edi, eax
    mov esi, 16
    call zone_slice
    PERF_MARK 21
    mov eax, [day_count]
    and eax, 3
    jnz .nn
    call networks_update
    jmp .nd
.nn:
    cmp dword [net_dirty], 0
    je .nd
    call networks_update
.nd:
    PERF_MARK 22
    ; coverage every 8 days, never on the same day as the networks (both
    ; on one day made the slowest frame at top speed)
    mov eax, [day_count]
    and eax, 7
    cmp eax, 2
    jne .nc
    call coverage_update
    jmp .ncd
.nc:
    cmp dword [cov_dirty], 0
    je .ncd
    call coverage_update
.ncd:
    PERF_MARK 23
    mov dword [cov_dirty], 0
    call stats_update
    PERF_MARK 24
    call dispatch_services
    PERF_MARK 25
    call check_goals
    inc dword [day]
    cmp dword [day], 30
    jl .out
    mov dword [day], 0
    call month_end
.out:
    PERF_MARK 26
    RETURN

; ---------------------------------------------------------------------
;  daily per-tile work: construction, fires, garbage, shop stock
; ---------------------------------------------------------------------
FUNC daily_tiles
    xor r14d, r14d                  ; tile index
.l:
    mov eax, r14d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    mov r12d, r14d
    and r12d, MAP_W-1               ; x
    mov r13d, r14d
    shr r13d, MAP_SHIFT             ; y
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .fires
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .fires
    test byte [rbx+T_FLAGS], F_BUILD
    jz .grown
    ; construction
    movzx eax, byte [rbx+T_TIMER]
    add eax, 14
    cmp byte [rbx+T_SIZE], 2
    jne .cs
    sub eax, 6                      ; big buildings take longer
.cs:
    cmp eax, 96
    jl .bstore
    mov byte [rbx+T_TIMER], 0
    inc byte [rbx+T_LEVEL]
    cmp byte [rbx+T_LEVEL], 5
    jbe .lvok
    mov byte [rbx+T_LEVEL], 5
.lvok:
    mov edi, r12d
    mov esi, r13d
    call footprint_clear_build
    mov rdi, rbx
    call set_tile_pop
    mov edi, r12d
    mov esi, r13d
    call fx_building_done
    jmp .fires
.bstore:
    mov [rbx+T_TIMER], al
    jmp .fires
.grown:
    test byte [rbx+T_FLAGS], F_ABANDON
    jnz .fires
    ; garbage accumulates with activity (every 4th day, staggered)
    mov ecx, [day_count]
    add ecx, r14d
    and ecx, 3
    jnz .ng0
    movzx eax, word [rbx+T_POP]
    shr eax, 4
    inc eax
    test dword [policies], P_RECYCLE
    jz .nr
    lea eax, [rax*2+rax]
    shr eax, 2
.nr:
    movzx ecx, byte [rbx+T_GARBAGE]
    add eax, ecx
    CLAMP eax, 0, 255
    mov [rbx+T_GARBAGE], al
.ng0:
    movzx eax, byte [rbx+T_GARBAGE]
    and byte [rbx+T_FLAGS2], ~F2_GARBAGE
    cmp eax, 190
    jb .ng
    or byte [rbx+T_FLAGS2], F2_GARBAGE
.ng:
    ; commerce sells goods, industry makes them
    movzx eax, byte [rbx+T_ZONE]
    movzx eax, byte [zone_class+rax]
    cmp eax, ZC_COM
    jne .ind
    movzx ecx, word [rbx+T_POP]
    shr ecx, 4
    inc ecx
    movzx eax, byte [rbx+T_GOODS]
    sub eax, ecx
    jge .gs
    xor eax, eax
.gs:
    mov [rbx+T_GOODS], al
    and byte [rbx+T_FLAGS2], ~F2_NOGOODS
    cmp eax, 20
    jae .fires
    or byte [rbx+T_FLAGS2], F2_NOGOODS
    jmp .fires
.ind:
    cmp eax, ZC_IND
    jne .fires
    movzx ecx, word [rbx+T_POP]
    imul ecx, [staff_basic]
    shr ecx, 12
    inc ecx
    movzx eax, byte [rbx+T_GOODS]
    add eax, ecx
    CLAMP eax, 0, 255
    mov [rbx+T_GOODS], al
.fires:
    test byte [rbx+T_FLAGS], F_FIRE
    jz .next
    movzx eax, byte [rbx+T_TIMER]
    inc eax
    mov [rbx+T_TIMER], al
    ; without a fire truck, a small chance to burn out on its own
    call rand
    and eax, 255
    cmp eax, 6
    jae .spread
    and byte [rbx+T_FLAGS], ~F_FIRE
    mov byte [rbx+T_TIMER], 0
    jmp .next
.spread:
    call rand
    and eax, 63
    cmp eax, 5
    jae .burnout
    call rand
    and eax, 3
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+rax*4]
    add esi, [dir_dy+rax*4]
    call tile_at
    test rax, rax
    jz .burnout
    mov cl, [rax+T_OBJ]
    cmp cl, OBJ_ZONEBLD
    je .ign
    cmp cl, OBJ_TREE
    je .ign
    cmp cl, OBJ_SERVICE
    jne .burnout
.ign:
    test byte [rax+T_FLAGS], F_FIRE
    jnz .burnout
    or byte [rax+T_FLAGS], F_FIRE
    mov byte [rax+T_TIMER], 0
.burnout:
    cmp byte [rbx+T_TIMER], 22
    jb .next
    mov edi, r12d
    mov esi, r13d
    call destroy_to_rubble
.next:
    inc r14d
    cmp r14d, MAP_TILES
    jl .l
    RETURN

; clear F_BUILD over a zone building footprint (edi, esi = anchor)
FUNC footprint_clear_build
    mov r12d, edi
    mov r13d, esi
    call tile_at
    movzx r14d, byte [rax+T_SIZE]
    CLAMP r14d, 1, 2
    xor ebx, ebx
.y:
    xor r15d, r15d
.x:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call tile_at
    test rax, rax
    jz .n
    and byte [rax+T_FLAGS], ~F_BUILD
.n:
    inc r15d
    cmp r15d, r14d
    jl .x
    inc ebx
    cmp ebx, r14d
    jl .y
    RETURN

; anchor_of(edi x, esi y) -> eax x, edx y of the building's anchor
anchor_of:
    push rdi
    push rsi
    call tile_at
    pop rsi
    pop rdi
    test rax, rax
    jz .same
    movzx ecx, byte [rax+T_ANCHOR]
    mov edx, ecx
    and ecx, 15
    shr edx, 4
    mov eax, edi
    sub eax, ecx
    sub esi, edx
    mov edx, esi
    ret
.same:
    mov eax, edi
    mov edx, esi
    ret

; footprint size of the building at an anchor tile (rdi tile) -> eax
footprint_size:
    mov eax, 1
    cmp byte [rdi+T_OBJ], OBJ_ZONEBLD
    jne .svc
    movzx eax, byte [rdi+T_SIZE]
    CLAMP eax, 1, 2
    ret
.svc:
    cmp byte [rdi+T_OBJ], OBJ_SERVICE
    jne .o
    push rdi
    movzx edi, byte [rdi+T_SUB]
    call bld_rec
    movzx eax, byte [rax+BI_SIZE]
    pop rdi
.o: ret

; destroy whatever is at (edi,esi) leaving rubble (whole footprint)
FUNC destroy_to_rubble
    mov r12d, edi
    mov r13d, esi
    call tile_at
    test rax, rax
    jz .out
    mov cl, [rax+T_OBJ]
    cmp cl, OBJ_SERVICE
    je .multi
    cmp cl, OBJ_ZONEBLD
    jne .single
.multi:
    mov edi, r12d
    mov esi, r13d
    call anchor_of
    mov r12d, eax
    mov r13d, edx
    mov edi, r12d
    mov esi, r13d
    call tile_at
    mov rdi, rax
    call footprint_size
    mov r14d, eax
    xor ebx, ebx
.fy:
    xor r15d, r15d
.fx:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call tile_at
    test rax, rax
    jz .fn
    mov rdi, rax
    call make_rubble
.fn:
    inc r15d
    cmp r15d, r14d
    jl .fx
    inc ebx
    cmp ebx, r14d
    jl .fy
    jmp .done
.single:
    mov rdi, rax
    call make_rubble
.done:
    mov dword [net_dirty], 1
    mov edi, r12d
    mov esi, r13d
    call fx_smoke_burst
.out:
    RETURN

make_rubble:
    mov byte [rdi+T_OBJ], OBJ_RUBBLE
    mov byte [rdi+T_FLAGS], 0
    and byte [rdi+T_FLAGS2], F2_PIPE
    mov byte [rdi+T_LEVEL], 0
    mov byte [rdi+T_TIMER], 0
    mov word [rdi+T_POP], 0
    mov byte [rdi+T_ANCHOR], 0
    mov byte [rdi+T_SIZE], 0
    mov byte [rdi+T_GARBAGE], 0
    mov byte [rdi+T_PROBLEM], 0
    ret

; set_tile_pop(rdi tile): residents/jobs from zone, level and size
set_tile_pop:
    movzx eax, byte [rdi+T_LEVEL]
    CLAMP eax, 0, 5
    movzx ecx, byte [rdi+T_ZONE]
    CLAMP ecx, 0, 6
    imul ecx, ecx, 6
    add ecx, eax
    mov eax, [zone_pop+rcx*4]
    cmp byte [rdi+T_ZONE], ZONE_I
    jne .sz
    cmp byte [rdi+T_SUB], 0
    je .sz
    lea eax, [rax*2+rax]
    shr eax, 2
.sz:
    cmp byte [rdi+T_SIZE], 2
    jne .ab
    lea eax, [rax*4+rax]            ; a 2x2 building holds 5 tiles' worth
.ab:
    test byte [rdi+T_FLAGS], F_ABANDON
    jz .w
    xor eax, eax
.w: mov [rdi+T_POP], ax
    ret

; ---------------------------------------------------------------------
;  zone growth for rows [edi, edi+esi)
; ---------------------------------------------------------------------
FUNC zone_slice, 16
    mov r13d, edi
    add esi, edi
    mov [rbp-48], esi
.y:
    cmp r13d, [rbp-48]
    jge .out
    xor r12d, r12d
.x:
    mov edi, r12d
    mov esi, r13d
    call zone_update
    inc r12d
    cmp r12d, MAP_W
    jl .x
    inc r13d
    jmp .y
.out:
    RETURN

; road_near(edi x, esi y) -> eax: 0 none, 1 local road, 2 road linked
; to the region.  Highways don't give building access.
FUNC road_near
    mov r12d, edi
    mov r13d, esi
    xor ebx, ebx
    mov r14d, -3
.dy:
    mov r15d, -3
.dx:
    mov eax, r14d
    cdq
    xor eax, edx
    sub eax, edx
    mov ecx, r15d
    sar ecx, 31
    mov edx, r15d
    xor edx, ecx
    sub edx, ecx
    add eax, edx
    cmp eax, 3
    jg .n
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call tile_at
    test rax, rax
    jz .n
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .n
    cmp byte [rax+T_ROADTYPE], RT_HIGHWAY
    je .n
    mov ecx, 1
    test byte [rax+T_MISC], MISC_NET
    jz .one
    mov ecx, 2
.one:
    cmp ecx, ebx
    jle .n
    mov ebx, ecx
.n:
    inc r15d
    cmp r15d, 3
    jle .dx
    inc r14d
    cmp r14d, 3
    jle .dy
    mov eax, ebx
    RETURN

; ---------------------------------------------------------------------
;  zone_update(edi x, esi y) - the growth model for one tile
; ---------------------------------------------------------------------
FUNC zone_update, 48
    mov r12d, edi
    mov r13d, esi
    call tile_at
    mov rbx, rax
    movzx eax, byte [rbx+T_ZONE]
    test eax, eax
    jz .out
    mov [rbp-48], eax               ; zone
    movzx ecx, byte [zone_class+rax]
    mov [rbp-60], ecx               ; class
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_NONE
    je .ok
    cmp eax, OBJ_ZONEBLD
    jne .out
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .out                         ; parts of big buildings follow their anchor
.ok:
    test byte [rbx+T_FLAGS], F_FIRE | F_BUILD
    jnz .out
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    mov r14d, eax                   ; map index

    ; ---- road access ----
    mov edi, r12d
    mov esi, r13d
    call road_near
    mov [rbp-52], eax
    and byte [rbx+T_FLAGS], ~F_ROADOK
    test eax, eax
    jz .noroad
    or byte [rbx+T_FLAGS], F_ROADOK
.noroad:

    ; ---- desirability ----
    movzx r15d, byte [map_lv+r14]
    shr r15d, 1
    mov ecx, [rbp-60]
    mov eax, [demand+rcx*4]
    sar eax, 1
    add r15d, eax
    cmp ecx, ZC_RES
    jne .dc
    movzx eax, byte [map_health+r14]
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_elem+r14]
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_park+r14]
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_transit+r14]
    shr eax, 4
    add r15d, eax
    movzx eax, byte [map_pol+r14]
    shr eax, 1
    sub r15d, eax
    movzx eax, byte [map_noise+r14]
    shr eax, 2
    sub r15d, eax
    movzx eax, byte [map_crime+r14]
    shr eax, 2
    sub r15d, eax
    jmp .dd
.dc:
    cmp ecx, ZC_COM
    jne .di
    movzx eax, byte [map_noise+r14]     ; busy streets = customers
    CLAMP eax, 0, 120
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_transit+r14]
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_crime+r14]
    shr eax, 2
    sub r15d, eax
    movzx eax, byte [map_pol+r14]
    shr eax, 3
    sub r15d, eax
    jmp .dd
.di:
    cmp ecx, ZC_IND
    jne .do
    shr r15d, 1
    add r15d, 34
    movzx eax, byte [map_crime+r14]
    shr eax, 3
    sub r15d, eax
    jmp .dd
.do:
    movzx eax, byte [map_high+r14]
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_uni+r14]
    shr eax, 4
    add r15d, eax
    movzx eax, byte [map_transit+r14]
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_pol+r14]
    shr eax, 2
    sub r15d, eax
    movzx eax, byte [map_crime+r14]
    shr eax, 2
    sub r15d, eax
.dd:
    CLAMP r15d, 0, 255
    mov [rbx+T_SCORE], r15b

    ; ---- target level ----
    xor ecx, ecx
    cmp dword [rbp-52], 0
    je .tdone
    test byte [rbx+T_FLAGS], F_POWER
    jz .tdone
    cmp dword [rbp-60], ZC_RES
    je .needlink
    cmp dword [rbp-60], ZC_IND
    jne .l1
.needlink:
    cmp dword [rbp-52], 2
    jne .tdone
.l1:
    cmp r15d, 22
    jl .tdone
    mov ecx, 1
    test byte [rbx+T_FLAGS], F_WATER
    jz .tdone
    test byte [rbx+T_FLAGS2], F2_SEWAGE
    jz .tdone
    cmp r15d, 56
    jl .tdone
    mov ecx, 2
    test byte [rbx+T_FLAGS2], F2_GARBAGE | F2_NOGOODS | F2_NOWORKERS | F2_DIRTY
    jnz .tdone
    cmp r15d, 88
    jl .tdone
    mov ecx, 3
    test dword [policies], P_HIGHRISE
    jz .nohr
    mov eax, [rbp-48]
    cmp eax, ZONE_R
    je .nohr
    cmp eax, ZONE_C
    je .nohr
    cmp eax, ZONE_I
    je .nohr
    jmp .tdone
.nohr:
    movzx eax, byte [map_police+r14]
    movzx edx, byte [map_fire+r14]
    add eax, edx
    cmp eax, 60
    jl .tdone
    cmp r15d, 122
    jl .tdone
    mov eax, [rbp-60]
    cmp eax, ZC_RES
    jne .l4c
    movzx eax, byte [map_health+r14]
    cmp eax, 30
    jl .tdone
    movzx eax, byte [map_elem+r14]
    cmp eax, 30
    jl .tdone
    ; beta: a home on a long commute stays at level 3
    mov edi, r14d
    call commute_too_long
    test eax, eax
    jnz .tdone
    jmp .l4
.l4c:
    cmp eax, ZC_OFF
    jne .l4
    movzx eax, byte [map_high+r14]
    cmp eax, 30
    jl .tdone
.l4:
    mov ecx, 4
    cmp r15d, 156
    jl .tdone
    mov eax, [rbp-60]
    cmp eax, ZC_RES
    jne .l5c
    movzx eax, byte [map_high+r14]
    cmp eax, 30
    jl .tdone
    movzx eax, byte [map_park+r14]
    cmp eax, 20
    jl .tdone
    jmp .l5
.l5c:
    movzx eax, byte [map_uni+r14]
    cmp eax, 30
    jl .tdone
.l5:
    mov ecx, 5
.tdone:
    mov [rbp-56], ecx               ; target

    ; ---- happiness (drifts toward conditions) ----
    mov eax, r15d
    shr eax, 1
    add eax, 24
    test byte [rbx+T_FLAGS], F_POWER
    jnz .hp
    sub eax, 40
.hp:
    movzx ecx, byte [rbx+T_LEVEL]
    cmp ecx, 2
    jl .hw
    test byte [rbx+T_FLAGS], F_WATER
    jnz .hs
    sub eax, 25
.hs:
    test byte [rbx+T_FLAGS2], F2_SEWAGE
    jnz .hw
    sub eax, 15
.hw:
    test byte [rbx+T_FLAGS2], F2_GARBAGE
    jz .hg
    sub eax, 15
.hg:
    test byte [rbx+T_FLAGS2], F2_DIRTY
    jz .hd
    sub eax, 15
.hd:
    test byte [rbx+T_FLAGS2], F2_NOROUTE
    jz .hrt
    sub eax, 10
.hrt:
    cmp dword [rbp-52], 0
    jne .hr
    sub eax, 40
.hr:
    test dword [policies], P_PARKS
    jz .hpk
    add eax, 5
.hpk:
    mov ecx, [rbp-60]
    mov ecx, [tax_rate+rcx*4]
    sub ecx, 9
    imul ecx, 3
    sub eax, ecx
    cmp dword [rbp-60], ZC_RES
    jne .hc
    ; beta: the home's own commute
    cmp dword [beta_on], 0
    je .hcg
    push rax
    push rax
    mov edi, r14d
    call commute_penalty
    mov ecx, eax
    pop rax
    pop rax
    sub eax, ecx
    jmp .hc
.hcg:
    mov ecx, [avg_commute]
    sub ecx, 300
    sar ecx, 5
    CLAMP ecx, 0, 10
    sub eax, ecx
.hc:
    CLAMP eax, 0, 100
    movzx ecx, byte [rbx+T_HAPPY]
    test ecx, ecx
    jnz .hmix
    mov ecx, 60
.hmix:
    lea ecx, [rcx*2+rcx]
    add ecx, eax
    shr ecx, 2
    CLAMP ecx, 1, 100
    mov [rbx+T_HAPPY], cl

    push rcx
    push rcx
    call pick_problem
    pop rcx
    pop rcx

    ; ---- abandoned buildings ----
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .lot
    test byte [rbx+T_FLAGS], F_ABANDON
    jz .notab
    cmp ecx, 45
    jl .out
    mov eax, [rbp-56]
    cmp al, [rbx+T_LEVEL]
    jl .out
    and byte [rbx+T_FLAGS], ~F_ABANDON
    mov rdi, rbx
    call set_tile_pop
    jmp .out
.notab:
    cmp ecx, 14
    jg .grow
    call rand
    and eax, 7
    jnz .grow
    or byte [rbx+T_FLAGS], F_ABANDON
    mov rdi, rbx
    call set_tile_pop
    jmp .out

.lot:
.grow:
    movzx eax, byte [rbx+T_LEVEL]
    cmp byte [rbx+T_OBJ], OBJ_NONE
    jne .hl
    xor eax, eax
.hl:
    mov [rbp-64], eax               ; current level
    cmp eax, [rbp-56]
    jge .maybe_decline
    mov ecx, [rbp-60]
    mov edx, [demand+rcx*4]
    cmp edx, -30
    jl .out
    call rand
    and eax, 255
    mov ecx, [rbp-60]
    mov edx, [demand+rcx*4]
    add edx, 110
    CLAMP edx, 20, 230
    cmp eax, edx
    jae .out
    ; dense zones may merge into a 2x2 building at level 3+
    cmp dword [rbp-64], 2
    jl .single
    cmp byte [rbx+T_SIZE], 2
    je .up
    mov eax, [rbp-48]
    cmp eax, ZONE_R
    je .single
    cmp eax, ZONE_C
    je .single
    call rand
    and eax, 3
    jnz .single
    mov edi, r12d
    mov esi, r13d
    call try_merge
    test eax, eax
    jnz .started
.single:
    cmp byte [rbx+T_OBJ], OBJ_NONE
    jne .up
    mov byte [rbx+T_OBJ], OBJ_ZONEBLD
    mov byte [rbx+T_LEVEL], 0
    mov byte [rbx+T_SIZE], 1
    mov byte [rbx+T_ANCHOR], 0
    mov byte [rbx+T_GARBAGE], 0
    or byte [rbx+T_FLAGS], F_ANCHOR
    mov byte [rbx+T_GOODS], 120
    call rand
    mov [rbx+T_VARIANT], al
    mov byte [rbx+T_SUB], 0
    mov byte [rbx+T_AGE], 0
    ; homes take on the character of their neighbourhood
    movzx eax, byte [rbx+T_ZONE]
    cmp byte [zone_class+rax], ZC_RES
    jne .nsty
    mov edi, r12d
    mov esi, r13d
    call choose_style
    mov [rbx+T_SUB], al
.nsty:
    cmp byte [rbx+T_ZONE], ZONE_I
    jne .up
    mov al, [rbx+T_RES]
    mov [rbx+T_SUB], al
.up:
    or byte [rbx+T_FLAGS], F_BUILD
    mov byte [rbx+T_TIMER], 0
.started:
    mov edi, r12d
    mov esi, r13d
    call fx_construct_start
    jmp .out
.maybe_decline:
    mov ecx, [rbp-56]
    add ecx, 1
    cmp eax, ecx
    jle .out
    call rand
    and eax, 7
    jnz .out
    cmp byte [rbx+T_SIZE], 2
    jne .dec1
    cmp byte [rbx+T_LEVEL], 3
    jle .out
.dec1:
    dec byte [rbx+T_LEVEL]
    cmp byte [rbx+T_LEVEL], 0
    jne .dp
    mov byte [rbx+T_OBJ], OBJ_NONE
    and byte [rbx+T_FLAGS], ~F_ANCHOR
.dp:
    mov rdi, rbx
    call set_tile_pop
.out:
    RETURN

; choose the most urgent problem for the icon (rbx tile)
pick_problem:
    xor eax, eax
    mov cl, [rbx+T_FLAGS]
    mov dl, [rbx+T_FLAGS2]
    test cl, F_FIRE
    jz .p1
    mov eax, PR_FIRE
    jmp .s
.p1:
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .s
    test cl, F_ROADOK
    jnz .p2
    mov eax, PR_ROAD
    jmp .s
.p2:
    test cl, F_POWER
    jnz .p3
    mov eax, PR_POWER
    jmp .s
.p3:
    cmp byte [rbx+T_LEVEL], 1
    jb .p5
    test cl, F_WATER
    jnz .p4
    mov eax, PR_WATER
    jmp .s
.p4:
    test dl, F2_SEWAGE
    jnz .p5
    mov eax, PR_SEWAGE
    jmp .s
.p5:
    test dl, F2_GARBAGE
    jz .p6
    mov eax, PR_GARBAGE
    jmp .s
.p6:
    test dl, F2_DIRTY
    jz .p7
    mov eax, PR_DIRTY
    jmp .s
.p7:
    test dl, F2_NOGOODS
    jz .p8
    mov eax, PR_GOODS
    jmp .s
.p8:
    test dl, F2_NOWORKERS
    jz .p9
    mov eax, PR_WORKERS
    jmp .s
.p9:
    test dl, F2_NOROUTE
    jz .s
    mov eax, PR_ROUTE
.s:
    mov [rbx+T_PROBLEM], al
    ret

; ---------------------------------------------------------------------
;  neighbourhood character
;  choose_style(edi x, esi y) -> eax style 1..6 for a new home:
;  mostly what the neighbours are (districts hold together), otherwise
;  what the place suggests: the water, industry, money, parks, and the
;  city's age (the first streets become the old town)
; ---------------------------------------------------------------------
STY_OLDTOWN equ 1
STY_GARDEN  equ 2
STY_SHORE   equ 3
STY_WORKER  equ 4
STY_UPTOWN  equ 5
STY_MODERN  equ 6
section .data
style_sibling db 0, STY_UPTOWN, STY_MODERN, STY_GARDEN, STY_OLDTOWN, STY_OLDTOWN, STY_GARDEN
section .text

FUNC choose_style, 64
    mov r12d, edi
    mov r13d, esi
    ; tally the styles of nearby homes, and look around
    xor eax, eax
    lea rdi, [rbp-80]
    mov ecx, 8
    rep stosd                       ; counts [rbp-80 .. -49]
    mov dword [rbp-84], 0           ; water seen
    mov dword [rbp-88], 0           ; industry seen
    mov dword [rbp-92], 0           ; trees seen
    mov r14d, -4
.dy:
    mov r15d, -4
.dx:
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call tile_at
    test rax, rax
    jz .n
    cmp byte [rax+T_TERRAIN], TER_WATER
    jne .w
    inc dword [rbp-84]
.w: cmp byte [rax+T_OBJ], OBJ_TREE
    jne .t
    inc dword [rbp-92]
.t: cmp byte [rax+T_ZONE], ZONE_I
    jne .i
    inc dword [rbp-88]
.i: cmp byte [rax+T_OBJ], OBJ_ZONEBLD
    jne .n
    movzx ecx, byte [rax+T_ZONE]
    cmp byte [zone_class+rcx], ZC_RES
    jne .n
    movzx ecx, byte [rax+T_SUB]
    cmp ecx, 6
    ja .n
    test ecx, ecx
    jz .n
    ; closer neighbours count double
    mov edx, r15d
    imul edx, edx
    mov r8d, r14d
    imul r8d, r8d
    add edx, r8d
    mov r8d, 1
    cmp edx, 5
    jg .c1
    mov r8d, 2
.c1:
    add [rbp-80+rcx*4], r8d
.n:
    inc r15d
    cmp r15d, 4
    jle .dx
    inc r14d
    cmp r14d, 4
    jle .dy
    ; the district wins most of the time
    xor ebx, ebx                    ; best style
    xor ecx, ecx                    ; best count
    mov edx, 1
.b:
    cmp [rbp-80+rdx*4], ecx
    jle .bn
    mov ecx, [rbp-80+rdx*4]
    mov ebx, edx
.bn:
    inc edx
    cmp edx, 6
    jle .b
    cmp ecx, 3
    jl .ctx
    call rand
    and eax, 3
    jnz .out                        ; 3 in 4 follow the street
    ; the rest mostly pick a related look (texture, not chaos)
    call rand
    and eax, 1
    jz .ctx
    movzx ebx, byte [style_sibling+rbx]
    jmp .out
.ctx:
    ; what the place itself suggests
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    mov r14d, eax                   ; map index
    mov ebx, STY_SHORE
    cmp dword [rbp-84], 3
    jge .out
    mov ebx, STY_WORKER
    cmp dword [rbp-88], 2
    jge .out
    cmp byte [map_pol+r14], 90
    jae .out
    mov ebx, STY_UPTOWN
    cmp byte [map_lv+r14], 175
    jae .out
    mov ebx, STY_GARDEN
    cmp dword [rbp-92], 5
    jge .out
    cmp byte [map_park+r14], 40
    jae .out
    ; the city's age: the first streets are the old town
    mov eax, [year]
    sub eax, 2026
    mov ebx, STY_OLDTOWN
    cmp eax, 5
    jl .era
    mov ebx, STY_MODERN
.era:
    ; a little mixing keeps the edges of districts interesting
    call rand
    and eax, 7
    jnz .out
    call rand
    and eax, 1
    mov ebx, STY_GARDEN
    jz .out
    mov ebx, STY_OLDTOWN
.out:
    mov eax, ebx
    RETURN

; homes built before styles existed (older saves) pick one now, in scan
; order so that neighbourhoods still come out coherent
FUNC style_existing
    xor r12d, r12d
.l:
    mov eax, r12d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .n
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .n
    cmp byte [rbx+T_SIZE], 1
    jne .n
    movzx eax, byte [rbx+T_ZONE]
    cmp byte [zone_class+rax], ZC_RES
    jne .n
    cmp byte [rbx+T_SUB], 0
    jne .n
    mov edi, r12d
    and edi, MAP_W-1
    mov esi, r12d
    shr esi, MAP_SHIFT
    call choose_style
    mov [rbx+T_SUB], al
.n:
    inc r12d
    cmp r12d, MAP_TILES
    jl .l
    RETURN

; try_merge(edi x, esi y): turn a 2x2 block of the same dense zone into
; one big building site -> eax 1 on success
FUNC try_merge
    mov r12d, edi
    mov r13d, esi
    call tile_at
    movzx r14d, byte [rax+T_ZONE]
    xor ebx, ebx
.chk:
    mov edi, ebx
    and edi, 1
    add edi, r12d
    mov esi, ebx
    shr esi, 1
    add esi, r13d
    call tile_at
    test rax, rax
    jz .no
    cmp [rax+T_ZONE], r14b
    jne .no
    test byte [rax+T_FLAGS], F_FIRE | F_BUILD | F_ABANDON
    jnz .no
    mov cl, [rax+T_OBJ]
    cmp cl, OBJ_NONE
    je .cn
    cmp cl, OBJ_ZONEBLD
    jne .no
    cmp byte [rax+T_SIZE], 1
    jne .no
.cn:
    inc ebx
    cmp ebx, 4
    jl .chk
    call rand
    mov r15d, eax
    xor ebx, ebx
.cv:
    mov edi, ebx
    and edi, 1
    add edi, r12d
    mov esi, ebx
    shr esi, 1
    add esi, r13d
    call tile_at
    mov byte [rax+T_OBJ], OBJ_ZONEBLD
    mov byte [rax+T_SIZE], 2
    mov byte [rax+T_LEVEL], 2
    mov word [rax+T_POP], 0
    mov byte [rax+T_GARBAGE], 0
    mov byte [rax+T_GOODS], 120
    mov byte [rax+T_PROBLEM], 0
    mov [rax+T_VARIANT], r15b
    mov byte [rax+T_SUB], 0
    and byte [rax+T_FLAGS], F_POWER | F_WATER | F_ROADOK
    or byte [rax+T_FLAGS], F_BUILD
    mov byte [rax+T_TIMER], 0
    mov ecx, ebx
    and ecx, 1
    mov edx, ebx
    shr edx, 1
    shl edx, 4
    or ecx, edx
    mov [rax+T_ANCHOR], cl
    test ecx, ecx
    jnz .na
    or byte [rax+T_FLAGS], F_ANCHOR
.na:
    inc ebx
    cmp ebx, 4
    jl .cv
    mov eax, 1
    RETURN
.no:
    xor eax, eax
    RETURN

; =====================================================================
;  utility networks
; =====================================================================
; power_conductive(rdi tile) -> eax
power_conductive:
    movzx eax, byte [rdi+T_OBJ]
    cmp eax, OBJ_POWER
    je .y
    cmp eax, OBJ_ZONEBLD
    je .y
    cmp eax, OBJ_SERVICE
    je .y
    cmp eax, OBJ_NONE
    jne .n
    cmp byte [rdi+T_ZONE], 0
    je .n
.y: mov eax, 1
    ret
.n: xor eax, eax
    ret

conductive:
    jmp power_conductive

; power supplied by an anchor tile (rbx tile) -> eax
FUNC power_supply_of
    xor eax, eax
    cmp byte [rbx+T_OBJ], OBJ_SERVICE
    jne .out
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .out
    test byte [rbx+T_FLAGS], F_FIRE
    jnz .zero
    movzx edi, byte [rbx+T_SUB]
    mov r12d, edi
    call bld_rec
    mov eax, [rax+BI_POWER]
    cmp r12d, BK_WIND
    jne .out
    mov ecx, [month]
    and ecx, 3
    imul ecx, 5
    add eax, ecx
    jmp .out
.zero:
    xor eax, eax
.out:
    RETURN

; power used by an anchor tile (rdi tile) -> eax
tile_power_use:
    xor eax, eax
    cmp byte [rdi+T_OBJ], OBJ_ZONEBLD
    jne .svc
    test byte [rdi+T_FLAGS], F_ANCHOR
    jz .o
    movzx eax, byte [rdi+T_LEVEL]
    CLAMP eax, 0, 5
    mov eax, [use_power+rax*4]
    cmp byte [rdi+T_SIZE], 2
    jne .i
    shl eax, 2
.i: cmp byte [rdi+T_ZONE], ZONE_I
    jne .o
    add eax, eax
    ret
.svc:
    cmp byte [rdi+T_OBJ], OBJ_SERVICE
    jne .o
    test byte [rdi+T_FLAGS], F_ANCHOR
    jz .o
    mov eax, 6
.o: ret

; ---------------------------------------------------------------------
;  power: conductive tiles connect when within 2 tiles of each other
;  (power lines reach 1)
; ---------------------------------------------------------------------
FUNC power_flood, 64
    call wires_cleanup
    call wires_build_adjacency
    lea rdi, [comp_map]
    xor eax, eax
    mov ecx, MAP_TILES/2
    rep stosd
    lea rdi, [comp_supply]
    mov ecx, MAX_COMPS*2
    rep stosd
    mov dword [rbp-56], 0
    mov dword [rbp-60], 0
    mov dword [rbp-64], 0
    xor r15d, r15d
.scan:
    cmp r15d, MAP_TILES
    jge .assign
    cmp word [comp_map+r15*2], 0
    jne .sn
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    call power_conductive
    test eax, eax
    jz .sn
    mov eax, [rbp-56]
    inc eax
    cmp eax, MAX_COMPS-1
    jge .sn
    mov [rbp-56], eax
    mov [rbp-68], eax
    mov [comp_map+r15*2], ax
    mov [bfs_queue], r15w
    xor r12d, r12d
    mov r13d, 1
.bfs:
    cmp r12d, r13d
    jge .sn
    movzx r14d, word [bfs_queue+r12*2]
    inc r12d
    mov eax, r14d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    push r12
    push r13
    call power_supply_of
    pop r13
    pop r12
    mov ecx, [rbp-68]
    add [comp_supply+rcx*4], eax
    add [rbp-60], eax
    mov rdi, rbx
    call tile_power_use
    mov ecx, [rbp-68]
    add [comp_demand+rcx*4], eax
    add [rbp-64], eax
    ; follow the wires strung from this tile
    mov eax, [wire_head+r14*4]
.wire:
    cmp eax, -1
    je .wd
    mov [rbp-92], eax
    mov esi, [wire_to+rax*4]
    cmp word [comp_map+rsi*2], 0
    jne .wn
    mov [rbp-84], esi
    shl esi, TILE_SHIFT
    lea rdi, [tiles+rsi]
    call power_conductive
    test eax, eax
    jz .wn
    mov eax, [rbp-84]
    mov ecx, [rbp-68]
    mov [comp_map+rax*2], cx
    mov [bfs_queue+r13*2], ax
    inc r13d
.wn:
    mov eax, [rbp-92]
    mov eax, [wire_next+rax*4]
    jmp .wire
.wd:
    ; power spreads between buildings within 2 tiles
    xor eax, eax
    cmp byte [rbx+T_OBJ], OBJ_POWER
    sete al
    mov [rbp-88], eax               ; current tile is a pylon
    mov eax, 2
.rad:
    mov [rbp-72], eax
    neg eax
    mov [rbp-76], eax               ; dy
.ny:
    mov eax, [rbp-76]
    cmp eax, [rbp-72]
    jg .bfs
    mov eax, [rbp-72]
    neg eax
    mov [rbp-80], eax               ; dx
.nx:
    mov eax, [rbp-80]
    cmp eax, [rbp-72]
    jg .nyn
    mov edi, r14d
    and edi, MAP_W-1
    add edi, [rbp-80]
    mov esi, r14d
    shr esi, MAP_SHIFT
    add esi, [rbp-76]
    cmp edi, MAP_W
    jae .nxn
    cmp esi, MAP_W
    jae .nxn
    shl esi, MAP_SHIFT
    add esi, edi
    cmp word [comp_map+rsi*2], 0
    jne .nxn
    mov [rbp-84], esi
    shl esi, TILE_SHIFT
    lea rdi, [tiles+rsi]
    call power_conductive
    test eax, eax
    jz .nxn
    ; two pylons only link through wires (or by touching)
    cmp byte [rdi+T_OBJ], OBJ_POWER
    jne .link
    cmp dword [rbp-88], 0
    je .link
    mov eax, [rbp-80]
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, 1
    jg .nxn
    mov eax, [rbp-76]
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, 1
    jg .nxn
.link:
    mov eax, [rbp-84]
    mov ecx, [rbp-68]
    mov [comp_map+rax*2], cx
    mov [bfs_queue+r13*2], ax
    inc r13d
.nxn:
    inc dword [rbp-80]
    jmp .nx
.nyn:
    inc dword [rbp-76]
    jmp .ny
.sn:
    inc r15d
    jmp .scan
.assign:
    xor r15d, r15d
.as:
    cmp r15d, MAP_TILES
    jge .done
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    and byte [rbx+T_FLAGS], ~F_POWER
    movzx r12d, word [comp_map+r15*2]
    test r12d, r12d
    jz .asn
    mov ecx, [comp_supply+r12*4]
    test ecx, ecx
    jz .asn
    cmp ecx, [comp_demand+r12*4]
    jge .on
    mov eax, ecx
    shl eax, 8
    xor edx, edx
    div dword [comp_demand+r12*4]
    mov r13d, eax
    mov edi, r15d
    add edi, [day_count]
    shr edi, 3
    xor edi, r15d
    call hash32
    and eax, 255
    cmp eax, r13d
    jae .asn
.on:
    or byte [rbx+T_FLAGS], F_POWER
.asn:
    inc r15d
    jmp .as
.done:
    mov eax, [rbp-60]
    mov [power_supply], eax
    mov eax, [rbp-64]
    mov [power_demand], eax
    call power_area_update
    ; a plant whose network has nothing to power?
    xor eax, eax
    mov ecx, 1
.isl:
    cmp ecx, [rbp-56]
    jg .isd
    cmp dword [comp_supply+rcx*4], 0
    je .isn
    cmp dword [comp_demand+rcx*4], 10
    jg .isn
    mov eax, 1
.isn:
    inc ecx
    jmp .isl
.isd:
    WARN_ONCE island_warned, msg_island, UI_WARN
    RETURN

; ---------------------------------------------------------------------
;  water: pipes carry clean water from pumps and towers, and sewage to
;  outlets.  Buildings within 2 tiles of a pipe are served.
; ---------------------------------------------------------------------
is_pipe_node:
    test byte [rdi+T_FLAGS2], F2_PIPE
    jnz .y
    cmp byte [rdi+T_OBJ], OBJ_SERVICE
    jne .n
    movzx eax, byte [rdi+T_SUB]
    cmp eax, BK_PUMP
    je .y
    cmp eax, BK_WTOWER
    je .y
    cmp eax, BK_SEWAGE
    je .y
.n: xor eax, eax
    ret
.y: mov eax, 1
    ret

; water / sewage use of an anchor (rdi tile) -> eax
tile_water_use:
    xor eax, eax
    cmp byte [rdi+T_OBJ], OBJ_ZONEBLD
    je .z
    cmp byte [rdi+T_OBJ], OBJ_SERVICE
    jne .o
    test byte [rdi+T_FLAGS], F_ANCHOR
    jz .o
    mov eax, 4
    ret
.z: test byte [rdi+T_FLAGS], F_ANCHOR
    jz .o
    movzx eax, byte [rdi+T_LEVEL]
    CLAMP eax, 1, 5
    mov eax, [use_water+rax*4]
    cmp byte [rdi+T_SIZE], 2
    jne .o
    shl eax, 2
.o: ret

FUNC water_flood, 80
    lea rdi, [comp_map]
    xor eax, eax
    mov ecx, MAP_TILES/2
    rep stosd
    lea rdi, [cons_comp]
    mov ecx, MAP_TILES/2
    rep stosd
    lea rdi, [comp_supply]
    mov ecx, MAX_COMPS*3
    rep stosd
    lea rdi, [comp_dirty]
    mov ecx, MAX_COMPS/4
    rep stosd
    mov dword [rbp-56], 0
    mov [water_supply], eax
    mov [water_demand], eax
    mov [sewage_cap], eax
    mov [sewage_demand], eax
    ; 1. label pipe networks (4-connected) and add producers
    xor r15d, r15d
.scan:
    cmp r15d, MAP_TILES
    jge .consumers
    cmp word [comp_map+r15*2], 0
    jne .sn
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    call is_pipe_node
    test eax, eax
    jz .sn
    mov eax, [rbp-56]
    inc eax
    cmp eax, MAX_COMPS-1
    jge .sn
    mov [rbp-56], eax
    mov [rbp-68], eax
    mov [comp_map+r15*2], ax
    mov [bfs_queue], r15w
    xor r12d, r12d
    mov r13d, 1
.bfs:
    cmp r12d, r13d
    jge .sn
    movzx r14d, word [bfs_queue+r12*2]
    inc r12d
    mov eax, r14d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    cmp byte [rbx+T_OBJ], OBJ_SERVICE
    jne .nbr
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .nbr
    movzx edi, byte [rbx+T_SUB]
    mov [rbp-72], edi
    call bld_rec
    mov ecx, [rax+BI_WATER]
    mov edx, [rbp-68]
    cmp dword [rbp-72], BK_SEWAGE
    jne .wp
    add [comp_sewcap+rdx*4], ecx
    add [sewage_cap], ecx
    jmp .nbr
.wp:
    test byte [rbx+T_FLAGS], F_POWER
    jz .nbr
    cmp dword [rbp-72], BK_PUMP
    jne .addw
    mov [rbp-88], ecx
    mov edi, r14d
    and edi, MAP_W-1
    mov esi, r14d
    shr esi, MAP_SHIFT
    call water_quality_near
    mov ecx, [rbp-88]
    mov edx, [rbp-68]
    cmp eax, -1
    je .nbr
    cmp eax, 50
    jl .addw
    mov byte [comp_dirty+rdx], 1
.addw:
    add [comp_supply+rdx*4], ecx
    add [water_supply], ecx
.nbr:
    xor ebx, ebx
.nb:
    mov edi, r14d
    and edi, MAP_W-1
    mov esi, r14d
    shr esi, MAP_SHIFT
    add edi, [dir_dx+rbx*4]
    add esi, [dir_dy+rbx*4]
    cmp edi, MAP_W
    jae .nbn
    cmp esi, MAP_W
    jae .nbn
    shl esi, MAP_SHIFT
    add esi, edi
    cmp word [comp_map+rsi*2], 0
    jne .nbn
    mov [rbp-76], esi
    shl esi, TILE_SHIFT
    lea rdi, [tiles+rsi]
    call is_pipe_node
    test eax, eax
    jz .nbn
    mov eax, [rbp-76]
    mov ecx, [rbp-68]
    mov [comp_map+rax*2], cx
    mov [bfs_queue+r13*2], ax
    inc r13d
.nbn:
    inc ebx
    cmp ebx, 4
    jl .nb
    jmp .bfs
.sn:
    inc r15d
    jmp .scan

.consumers:
    ; 2. every consumer anchor attaches to a pipe within 2 tiles
    xor r15d, r15d
.cl:
    cmp r15d, MAP_TILES
    jge .assign
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    mov rdi, rbx
    call tile_water_use
    test eax, eax
    jz .cn
    mov [rbp-80], eax
    mov rdi, rbx
    call footprint_size
    mov [rbp-84], eax
    ; every network in reach is a candidate: take the one with the most
    ; water (a dead stub left after removing pipes must not capture the
    ; building when a live pipe is just as close)
    mov dword [rbp-92], 0           ; best component
    mov dword [rbp-96], -1          ; its supply
    mov r12d, -3
.sy:
    mov eax, [rbp-84]
    add eax, 2
    cmp r12d, eax
    jg .attach
    mov r13d, -3
.sx:
    mov eax, [rbp-84]
    add eax, 2
    cmp r13d, eax
    jg .syn
    mov edi, r15d
    and edi, MAP_W-1
    add edi, r13d
    mov esi, r15d
    shr esi, MAP_SHIFT
    add esi, r12d
    cmp edi, MAP_W
    jae .sxn
    cmp esi, MAP_W
    jae .sxn
    shl esi, MAP_SHIFT
    add esi, edi
    movzx eax, word [comp_map+rsi*2]
    test eax, eax
    jz .sxn
    mov ecx, [comp_supply+rax*4]
    cmp ecx, [rbp-96]
    jle .sxn
    mov [rbp-96], ecx
    mov [rbp-92], eax
.sxn:
    inc r13d
    jmp .sx
.syn:
    inc r12d
    jmp .sy
.attach:
    mov eax, [rbp-92]
    test eax, eax
    jz .cn
    mov [cons_comp+r15*2], ax
    mov ecx, [rbp-80]
    add [comp_demand+rax*4], ecx
    add [water_demand], ecx
    add [sewage_demand], ecx
.cn:
    inc r15d
    jmp .cl

.assign:
    xor r15d, r15d
.as:
    cmp r15d, MAP_TILES
    jge .done
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    and byte [rbx+T_FLAGS], ~F_WATER
    and byte [rbx+T_FLAGS2], ~(F2_SEWAGE | F2_DIRTY)
    movzx r12d, word [cons_comp+r15*2]
    test r12d, r12d
    jz .asn
    mov ecx, [comp_sewcap+r12*4]
    cmp ecx, [comp_demand+r12*4]
    jl .nsw
    or byte [rbx+T_FLAGS2], F2_SEWAGE
.nsw:
    mov ecx, [comp_supply+r12*4]
    test ecx, ecx
    jz .asn
    cmp ecx, [comp_demand+r12*4]
    jge .on
    mov eax, ecx
    shl eax, 8
    xor edx, edx
    div dword [comp_demand+r12*4]
    mov r13d, eax
    mov edi, r15d
    xor edi, 0x5bd1e995
    call hash32
    and eax, 255
    cmp eax, r13d
    jae .asn
.on:
    or byte [rbx+T_FLAGS], F_WATER
    cmp byte [comp_dirty+r12], 0
    je .asn
    or byte [rbx+T_FLAGS2], F2_DIRTY
.asn:
    inc r15d
    jmp .as
.done:
    call spread_footprint_utilities
    call water_area_update
    RETURN

; copy utility flags from anchors to the rest of their footprint
FUNC spread_footprint_utilities
    xor r15d, r15d
.l:
    cmp r15d, MAP_TILES
    jge .out
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .n
    mov rdi, rbx
    call footprint_size
    cmp eax, 1
    jle .n
    mov r14d, eax
    mov r12b, [rbx+T_FLAGS]
    and r12b, F_WATER
    mov r13b, [rbx+T_FLAGS2]
    and r13b, F2_SEWAGE | F2_DIRTY
    xor ecx, ecx
.fy:
    xor edx, edx
.fx:
    mov edi, r15d
    and edi, MAP_W-1
    add edi, edx
    mov esi, r15d
    shr esi, MAP_SHIFT
    add esi, ecx
    push rcx
    push rdx
    call tile_at
    pop rdx
    pop rcx
    test rax, rax
    jz .fn
    and byte [rax+T_FLAGS], ~F_WATER
    or [rax+T_FLAGS], r12b
    and byte [rax+T_FLAGS2], ~(F2_SEWAGE | F2_DIRTY)
    or [rax+T_FLAGS2], r13b
.fn:
    inc edx
    cmp edx, r14d
    jl .fx
    inc ecx
    cmp ecx, r14d
    jl .fy
.n:
    inc r15d
    jmp .l
.out:
    RETURN

; highest water pollution touching tile (edi,esi) -> eax, -1 if no water
FUNC water_quality_near
    mov r12d, edi
    mov r13d, esi
    mov ebx, -1
    mov r14d, -1
.dy:
    mov r15d, -1
.dx:
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call tile_at
    test rax, rax
    jz .n
    cmp byte [rax+T_TERRAIN], TER_WATER
    jne .n
    sub rax, tiles
    shr eax, TILE_SHIFT
    movzx eax, byte [map_wpol+rax]
    cmp eax, ebx
    jle .n
    mov ebx, eax
.n:
    inc r15d
    cmp r15d, 1
    jle .dx
    inc r14d
    cmp r14d, 1
    jle .dy
    mov eax, ebx
    RETURN

; sewage outlets pollute the water they drain into (flood over water)
FUNC water_pollution_update, 16
    lea rdi, [map_wpol]
    xor eax, eax
    mov ecx, MAP_TILES/4
    rep stosd
    lea rdi, [comp_map]
    mov ecx, MAP_TILES/2
    rep stosd
    mov eax, [sewage_demand]
    CLAMP eax, 20, 1000
    shr eax, 2
    add eax, 60
    CLAMP eax, 0, 255
    mov [rbp-48], eax
    xor r15d, r15d
.l:
    cmp r15d, MAP_TILES
    jge .out
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    cmp byte [rbx+T_OBJ], OBJ_SERVICE
    jne .n
    cmp byte [rbx+T_SUB], BK_SEWAGE
    jne .n
    xor r13d, r13d
    xor ecx, ecx
.sd:
    mov edi, r15d
    and edi, MAP_W-1
    add edi, [dir_dx+rcx*4]
    mov esi, r15d
    shr esi, MAP_SHIFT
    add esi, [dir_dy+rcx*4]
    push rcx
    push rcx
    call tile_at
    pop rcx
    pop rcx
    test rax, rax
    jz .sdn
    cmp byte [rax+T_TERRAIN], TER_WATER
    jne .sdn
    sub rax, tiles
    shr eax, TILE_SHIFT
    mov word [comp_map+rax*2], 1
    mov [bfs_queue+r13*2], ax
    inc r13d
.sdn:
    inc ecx
    cmp ecx, 4
    jl .sd
    xor r12d, r12d
.bfs:
    cmp r12d, r13d
    jge .clr
    movzx r14d, word [bfs_queue+r12*2]
    inc r12d
    movzx ecx, word [comp_map+r14*2]
    mov eax, 22
    sub eax, ecx
    jle .bfs
    imul eax, [rbp-48]
    xor edx, edx
    mov ecx, 22
    div ecx
    movzx ecx, byte [map_wpol+r14]
    add eax, ecx
    CLAMP eax, 0, 255
    mov [map_wpol+r14], al
    xor ebx, ebx
.nb:
    mov edi, r14d
    and edi, MAP_W-1
    add edi, [dir_dx+rbx*4]
    mov esi, r14d
    shr esi, MAP_SHIFT
    add esi, [dir_dy+rbx*4]
    call tile_at
    test rax, rax
    jz .nbn
    cmp byte [rax+T_TERRAIN], TER_WATER
    jne .nbn
    sub rax, tiles
    shr eax, TILE_SHIFT
    cmp word [comp_map+rax*2], 0
    jne .nbn
    movzx ecx, word [comp_map+r14*2]
    inc ecx
    mov [comp_map+rax*2], cx
    mov [bfs_queue+r13*2], ax
    inc r13d
.nbn:
    inc ebx
    cmp ebx, 4
    jl .nb
    jmp .bfs
.clr:
    lea rdi, [comp_map]
    xor eax, eax
    mov ecx, MAP_TILES/2
    rep stosd
.n:
    inc r15d
    jmp .l
.out:
    RETURN

; ---------------------------------------------------------------------
;  wires between pylons (and the buildings they end at)
; ---------------------------------------------------------------------
; tile can hold a wire end? (edi tile index) -> eax
wire_end_ok:
    mov eax, edi
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    jmp power_conductive

; drop wires whose ends no longer exist
FUNC wires_cleanup
    xor ebx, ebx                    ; read
    xor r12d, r12d                  ; write
.l:
    cmp ebx, [n_wires]
    jge .d
    movzx edi, word [wire_a+rbx*2]
    call wire_end_ok
    test eax, eax
    jz .n
    movzx edi, word [wire_b+rbx*2]
    call wire_end_ok
    test eax, eax
    jz .n
    mov ax, [wire_a+rbx*2]
    mov [wire_a+r12*2], ax
    mov ax, [wire_b+rbx*2]
    mov [wire_b+r12*2], ax
    inc r12d
.n:
    inc ebx
    jmp .l
.d:
    mov [n_wires], r12d
    RETURN

FUNC wires_build_adjacency
    lea rdi, [wire_head]
    mov eax, -1
    mov ecx, MAP_TILES
    rep stosd
    xor ebx, ebx
.l:
    cmp ebx, [n_wires]
    jge .d
    movzx ecx, word [wire_a+rbx*2]
    movzx edx, word [wire_b+rbx*2]
    lea eax, [rbx*2]
    mov r8d, [wire_head+rcx*4]
    mov [wire_next+rax*4], r8d
    mov [wire_head+rcx*4], eax
    mov [wire_to+rax*4], edx
    inc eax
    mov r8d, [wire_head+rdx*4]
    mov [wire_next+rax*4], r8d
    mov [wire_head+rdx*4], eax
    mov [wire_to+rax*4], ecx
    inc ebx
    jmp .l
.d:
    RETURN

; add_wire(edi tile a, esi tile b) - ignores duplicates
FUNC add_wire
    cmp edi, esi
    je .out
    xor ebx, ebx
.l:
    cmp ebx, [n_wires]
    jge .add
    movzx eax, word [wire_a+rbx*2]
    movzx ecx, word [wire_b+rbx*2]
    cmp eax, edi
    jne .x
    cmp ecx, esi
    je .out
.x:
    cmp eax, esi
    jne .n
    cmp ecx, edi
    je .out
.n:
    inc ebx
    jmp .l
.add:
    cmp ebx, MAX_WIRES
    jge .out
    mov [wire_a+rbx*2], di
    mov [wire_b+rbx*2], si
    inc dword [n_wires]
.out:
    RETURN

; where a new building would be powered: 2 tiles around live tiles
FUNC power_area_update
    lea rdi, [map_powerarea]
    xor eax, eax
    mov ecx, MAP_TILES/4
    rep stosd
    xor r15d, r15d
.l:
    cmp r15d, MAP_TILES
    jge .out
    mov eax, r15d
    shl eax, TILE_SHIFT
    test byte [tiles+rax+T_FLAGS], F_POWER
    jz .n
    mov r12d, r15d
    and r12d, MAP_W-1
    mov r13d, r15d
    shr r13d, MAP_SHIFT
    mov r14d, -2
.dy:
    mov ebx, -2
.dx:
    lea eax, [r12+rbx]
    cmp eax, MAP_W
    jae .dn
    lea ecx, [r13+r14]
    cmp ecx, MAP_W
    jae .dn
    shl ecx, MAP_SHIFT
    add ecx, eax
    mov byte [map_powerarea+rcx], 1
.dn:
    inc ebx
    cmp ebx, 2
    jle .dx
    inc r14d
    cmp r14d, 2
    jle .dy
.n:
    inc r15d
    jmp .l
.out:
    RETURN

; where pipes deliver water: 3 tiles around pipes that have a pump
FUNC water_area_update
    lea rdi, [map_waterarea]
    xor eax, eax
    mov ecx, MAP_TILES/4
    rep stosd
    xor r15d, r15d
.l:
    cmp r15d, MAP_TILES
    jge .out
    movzx eax, word [comp_map+r15*2]
    test eax, eax
    jz .n
    cmp dword [comp_supply+rax*4], 0
    je .n
    or byte [map_waterarea+r15], 2
    ; not enough outlet capacity on this network
    mov ecx, [comp_sewcap+rax*4]
    cmp ecx, [comp_demand+rax*4]
    jge .sok
    or byte [map_waterarea+r15], 4
.sok:
    mov r12d, r15d
    and r12d, MAP_W-1
    mov r13d, r15d
    shr r13d, MAP_SHIFT
    mov r14d, -3
.dy:
    mov ebx, -3
.dx:
    lea eax, [r12+rbx]
    cmp eax, MAP_W
    jae .dn
    lea ecx, [r13+r14]
    cmp ecx, MAP_W
    jae .dn
    shl ecx, MAP_SHIFT
    add ecx, eax
    or byte [map_waterarea+rcx], 1
.dn:
    inc ebx
    cmp ebx, 3
    jle .dx
    inc r14d
    cmp r14d, 3
    jle .dy
.n:
    inc r15d
    jmp .l
.out:
    RETURN

; is_border_highway(ecx tile index, rax = tile offset) -> ecx 1/0
; any highway road on the edge of the map links to the region
is_border_highway:
    cmp byte [tiles+rax+T_ROADTYPE], RT_HIGHWAY
    jne .n
    mov edx, ecx
    and edx, MAP_W-1
    jz .y
    cmp edx, MAP_W-1
    je .y
    shr ecx, MAP_SHIFT
    jz .y
    cmp ecx, MAP_W-1
    je .y
.n: xor ecx, ecx
    ret
.y: mov ecx, 1
    ret

; road connectivity to the outside (MISC_NET)
FUNC road_connectivity, 16
    ; which roads reach the region, and through which highway network
    lea rdi, [road_comp]
    xor eax, eax
    mov ecx, MAP_TILES/2
    rep stosd
    xor r15d, r15d
.clr:
    mov eax, r15d
    shl eax, TILE_SHIFT
    and byte [tiles+rax+T_MISC], ~MISC_NET
    inc r15d
    cmp r15d, MAP_TILES
    jl .clr
    mov dword [rbp-48], 0           ; component id
    xor r15d, r15d
.seed:
    cmp r15d, MAP_TILES
    jge .out
    cmp word [road_comp+r15*2], 0
    jne .sn
    mov eax, r15d
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    jne .sn
    mov ecx, r15d
    call is_border_highway
    test ecx, ecx
    jz .sn
    inc dword [rbp-48]
    mov ecx, [rbp-48]
    mov [road_comp+r15*2], cx
    mov eax, r15d
    shl eax, TILE_SHIFT
    or byte [tiles+rax+T_MISC], MISC_NET
    mov [bfs_queue], r15w
    xor r12d, r12d
    mov r13d, 1
.bfs:
    cmp r12d, r13d
    jge .sn
    movzx r14d, word [bfs_queue+r12*2]
    inc r12d
    xor ebx, ebx
.nb:
    mov edi, r14d
    and edi, MAP_W-1
    mov esi, r14d
    shr esi, MAP_SHIFT
    add edi, [dir_dx+rbx*4]
    add esi, [dir_dy+rbx*4]
    call tile_at
    test rax, rax
    jz .nn
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .nn
    test byte [rax+T_MISC], MISC_NET
    jnz .nn
    or byte [rax+T_MISC], MISC_NET
    sub rax, tiles
    shr eax, TILE_SHIFT
    mov ecx, [rbp-48]
    mov [road_comp+rax*2], cx
    mov [bfs_queue+r13*2], ax
    inc r13d
.nn:
    inc ebx
    cmp ebx, 4
    jl .nb
    jmp .bfs
.sn:
    inc r15d
    jmp .seed
.out:
    RETURN



FUNC networks_update
    mov dword [net_dirty], 0
    call road_connectivity
    call power_flood
    call water_pollution_update
    call water_flood
    xor eax, eax
    mov ecx, [power_demand]
    cmp ecx, [power_supply]
    seta al
    WARN_ONCE brownout_warned, msg_brownout, UI_WARN
    xor eax, eax
    mov ecx, [water_demand]
    cmp ecx, 40
    jl .w
    cmp ecx, [water_supply]
    seta al
.w:
    WARN_ONCE water_warned, msg_nowater, UI_WARN
    xor eax, eax
    mov ecx, [sewage_demand]
    cmp ecx, 60
    jl .s
    cmp ecx, [sewage_cap]
    seta al
.s:
    WARN_ONCE sewage_warned, msg_nosewage, UI_WARN
    xor eax, eax
    cmp dword [cnt_garbage], 8
    setg al
    WARN_ONCE garbage_warned, msg_garbage, UI_WARN
    xor eax, eax
    mov ecx, [landfill_cap]
    test ecx, ecx
    jz .lf
    cmp dword [svc_count+BK_INCIN*4], 0
    jne .lf
    cmp [landfill_used], ecx
    setae al
.lf:
    WARN_ONCE landfull_warned, msg_landfull, UI_BAD
    RETURN

; =====================================================================
;  map stamping
; =====================================================================
; stamp(rdi map, esi cx, edx cy, ecx radius, r8d strength)
stamp:
    mov r9, MAP_W << 32
; stamp_rows: the same, only into rows [r9d, r9 >> 32) (a band's rows)
FUNC stamp_rows, 32
    mov [rbp-56], rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d
    mov [rbp-60], r9d               ; first row
    shr r9, 32
    mov [rbp-64], r9d               ; end row
    mov eax, ecx
    imul eax, eax
    test eax, eax
    jnz .r
    inc eax
.r:
    mov [rbp-48], eax
    mov ebx, r14d
    neg ebx
    mov eax, [rbp-60]
    sub eax, r13d
    cmp ebx, eax
    jge .dy
    mov ebx, eax                    ; from the first row of the clip
.dy:
    cmp ebx, r14d
    jg .out
    lea eax, [r13+rbx]
    cmp eax, [rbp-64]
    jge .out                        ; past its end
    cmp eax, MAP_W
    jae .dyn
    mov ecx, r14d
    neg ecx
.dx:
    cmp ecx, r14d
    jg .dyn
    lea eax, [r12+rcx]
    cmp eax, MAP_W
    jae .dxn
    mov eax, ecx
    imul eax, ecx
    mov edx, ebx
    imul edx, ebx
    add eax, edx
    mov edx, [rbp-48]
    sub edx, eax
    jl .dxn
    mov eax, edx
    imul eax, r15d
    xor edx, edx
    push rcx
    mov ecx, [rbp-48]
    div ecx
    pop rcx
    lea edx, [r13+rbx]
    shl edx, MAP_SHIFT
    add edx, r12d
    add edx, ecx
    mov rdi, [rbp-56]
    movzx r8d, byte [rdi+rdx]
    add eax, r8d
    cmp eax, 255
    jle .st
    mov eax, 255
.st:
    mov [rdi+rdx], al
.dxn:
    inc ecx
    jmp .dx
.dyn:
    inc ebx
    jmp .dy
.out:
    RETURN

; subtract version (clamped at 0), rows [r9d, r9 >> 32)
FUNC stamp_sub_rows, 32
    mov [rbp-56], rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d
    mov [rbp-60], r9d
    shr r9, 32
    mov [rbp-64], r9d
    mov ebx, r14d
    neg ebx
    mov eax, [rbp-60]
    sub eax, r13d
    cmp ebx, eax
    jge .dy
    mov ebx, eax
.dy:
    cmp ebx, r14d
    jg .out
    lea eax, [r13+rbx]
    cmp eax, [rbp-64]
    jge .out
    cmp eax, MAP_W
    jae .dyn
    mov ecx, r14d
    neg ecx
.dx:
    cmp ecx, r14d
    jg .dyn
    lea eax, [r12+rcx]
    cmp eax, MAP_W
    jae .dxn
    lea edx, [r13+rbx]
    shl edx, MAP_SHIFT
    add edx, r12d
    add edx, ecx
    mov rdi, [rbp-56]
    movzx eax, byte [rdi+rdx]
    sub eax, r15d
    jge .st
    xor eax, eax
.st:
    mov [rdi+rdx], al
.dxn:
    inc ecx
    jmp .dx
.dyn:
    inc ebx
    jmp .dy
.out:
    RETURN

section .data
align 8
cov_maps dq 0, map_police, map_fire, map_health, map_elem, map_high, map_uni, map_park, map_garb, 0
section .text

; ---------------------------------------------------------------------
;  coverage_update: services, pollution, noise, traffic, crime, value
; ---------------------------------------------------------------------
; coverage stamps into map rows [edi, esi): clear them, then stamp from
; every source that can reach them
FUNC cov_rows, 48
    mov [rbp-64], edi
    mov [rbp-68], esi
    mov eax, esi
    shl rax, 32
    mov ecx, edi
    or rax, rcx
    mov [rbp-80], rax               ; the rows, as stamp_rows takes them
    ; clear map_pol .. map_traffic (13 consecutive maps) in these rows
    xor ebx, ebx
.clr:
    mov eax, ebx
    imul eax, MAP_TILES
    mov edi, [rbp-64]
    shl edi, MAP_SHIFT
    add edi, eax
    lea rdi, [map_pol+rdi]
    mov ecx, [rbp-68]
    sub ecx, [rbp-64]
    shl ecx, MAP_SHIFT
    xor eax, eax
    rep stosb
    inc ebx
    cmp ebx, 13
    jl .clr
    mov r13d, [rbp-64]
    sub r13d, 52
    CLAMP r13d, 0, MAP_W
.y:
    mov eax, [rbp-68]
    add eax, 52
    cmp r13d, eax
    jge .done
    xor r12d, r12d
.x:
    mov edi, r12d
    mov esi, r13d
    call tile_at
    mov rbx, rax
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_SERVICE
    je .svc
    cmp eax, OBJ_ZONEBLD
    je .zb
    cmp eax, OBJ_TREE
    je .tree
    cmp eax, OBJ_ROAD
    je .road
    jmp .next
.road:
    movzx r8d, byte [rbx+T_TRAFFIC]
    shr r8d, 2
    test r8d, r8d
    jz .bus
    lea rdi, [map_noise]
    mov esi, r12d
    mov edx, r13d
    mov ecx, 2
    mov r9, [rbp-80]
    call stamp_rows
.bus:
    test byte [rbx+T_FLAGS2], F2_BUSSTOP
    jz .next
    cmp dword [svc_count+BK_BUSDEPOT*4], 0
    je .next
    lea rdi, [map_transit]
    mov esi, r12d
    mov edx, r13d
    mov ecx, 5
    mov r8d, 200
    test dword [policies], P_FREEBUS
    jz .bs
    mov r8d, 255
.bs:
    mov r9, [rbp-80]
    call stamp_rows
    jmp .next
.svc:
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .next
    movzx edi, byte [rbx+T_SUB]
    mov r14d, edi
    call bld_rec
    mov r15, rax
    movzx eax, byte [r15+BI_SIZE]
    shr eax, 1
    mov [rbp-48], eax
    movzx r8d, byte [r15+BI_POLL]
    test r8d, r8d
    jz .nopol
    lea rdi, [map_pol]
    mov esi, r12d
    add esi, [rbp-48]
    mov edx, r13d
    add edx, [rbp-48]
    mov ecx, 9
    mov r9, [rbp-80]
    call stamp_rows
.nopol:
    movzx r8d, byte [r15+BI_NOISE]
    test r8d, r8d
    jz .nonoise
    lea rdi, [map_noise]
    mov esi, r12d
    add esi, [rbp-48]
    mov edx, r13d
    add edx, [rbp-48]
    mov ecx, 4
    mov r9, [rbp-80]
    call stamp_rows
.nonoise:
    movzx eax, byte [r15+BI_COV]
    test eax, eax
    jz .next
    cmp eax, CV_TRANSIT
    je .next
    cmp eax, CV_PARK
    je .cov
    test byte [rbx+T_FLAGS], F_POWER
    jz .next
.cov:
    mov [rbp-52], eax
    mov rdi, [cov_maps+rax*8]
    movzx r8d, byte [cov_strength+rax]
    movzx ecx, byte [bld_cov_boost+r14]
    add r8d, ecx
    mov eax, [rbp-52]
    cmp eax, CV_PARK
    jne .pe
    test dword [policies], P_PARKS
    jz .pe
    add r8d, 60
.pe:
    cmp eax, CV_ELEM
    jb .pd
    cmp eax, CV_UNIV
    ja .pd
    test dword [policies], P_EDUBOOST
    jz .pd
    add r8d, 60
.pd:
    CLAMP r8d, 0, 255
    mov esi, r12d
    add esi, [rbp-48]
    mov edx, r13d
    add edx, [rbp-48]
    movzx ecx, byte [r15+BI_RADIUS]
    mov r9, [rbp-80]
    call stamp_rows
    jmp .next
.zb:
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .next
    test byte [rbx+T_FLAGS], F_BUILD
    jnz .next
    movzx eax, byte [rbx+T_ZONE]
    cmp eax, ZONE_CH
    jne .zi
    lea rdi, [map_noise]
    mov esi, r12d
    mov edx, r13d
    mov ecx, 3
    mov r8d, 50
    mov r9, [rbp-80]
    call stamp_rows
    jmp .next
.zi:
    cmp eax, ZONE_I
    jne .next
    movzx eax, byte [rbx+T_LEVEL]
    CLAMP eax, 0, 5
    movzx r8d, byte [ind_poll+rax]
    movzx ecx, byte [rbx+T_SUB]
    test ecx, ecx
    jz .gp
    movzx r8d, byte [spec_poll+rcx]
.gp:
    test dword [policies], P_FILTERS
    jz .nf
    lea r8d, [r8*2+r8]
    shr r8d, 3
.nf:
    test r8d, r8d
    jz .next
    mov [rbp-56], r8d
    lea rdi, [map_pol]
    mov esi, r12d
    mov edx, r13d
    movzx ecx, byte [rbx+T_LEVEL]
    shr ecx, 1
    add ecx, 3
    cmp byte [rbx+T_SIZE], 2
    jne .zs
    add ecx, 2
.zs:
    mov r9, [rbp-80]
    call stamp_rows
    lea rdi, [map_noise]
    mov esi, r12d
    mov edx, r13d
    mov ecx, 3
    mov r8d, [rbp-56]
    mov r9, [rbp-80]
    call stamp_rows
    jmp .next
.tree:
    lea rdi, [map_pol]
    mov esi, r12d
    mov edx, r13d
    mov ecx, 1
    mov r8d, 4
    mov r9, [rbp-80]
    call stamp_sub_rows
    lea rdi, [map_noise]
    mov esi, r12d
    mov edx, r13d
    mov ecx, 1
    mov r8d, 6
    mov r9, [rbp-80]
    call stamp_sub_rows
.next:
    inc r12d
    cmp r12d, MAP_W
    jl .x
    inc r13d
    cmp r13d, MAP_W
    jl .y
.done:
    RETURN


FUNC coverage_update, 48
    ; the stamps: every core takes a band of map rows (each cell still
    ; gets its stamps in the same order, so the result is the same)
    lea rdi, [cov_rows]
    mov esi, MAP_W
    mov edx, 1
    call par_rows

    ; per-tile: traffic fumes, land value, crime, education drift
    xor r15d, r15d
    xor r12d, r12d
    mov dword [rbp-60], 0
.lv:
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    cmp byte [rbx+T_OBJ], OBJ_ROAD
    jne .nr
    movzx eax, word [rbx+T_FLOW]
    shl eax, 1
    CLAMP eax, 0, 255
    movzx ecx, byte [rbx+T_TRAFFIC]
    add eax, ecx
    shr eax, 1
    mov [rbx+T_TRAFFIC], al
    mov word [rbx+T_FLOW], 0
    shr byte [rbx+T_JAM], 1
    add r12d, eax
    inc dword [rbp-60]
    shr eax, 2
    movzx ecx, byte [map_pol+r15]
    add eax, ecx
    CLAMP eax, 0, 255
    mov [map_pol+r15], al
.nr:
    movzx eax, byte [map_park+r15]
    shr eax, 3
    movzx ecx, byte [map_pol+r15]
    sub ecx, eax
    CLAMP ecx, 0, 255
    mov [map_pol+r15], cl
    ; land value
    mov eax, 48
    movzx ecx, byte [map_scenic+r15]
    add eax, ecx
    movzx ecx, byte [map_park+r15]
    shr ecx, 1
    add eax, ecx
    movzx ecx, byte [map_elem+r15]
    shr ecx, 4
    add eax, ecx
    movzx ecx, byte [map_high+r15]
    shr ecx, 4
    add eax, ecx
    movzx ecx, byte [map_health+r15]
    shr ecx, 3
    add eax, ecx
    movzx ecx, byte [map_police+r15]
    shr ecx, 4
    add eax, ecx
    movzx ecx, byte [map_transit+r15]
    shr ecx, 3
    add eax, ecx
    movzx ecx, byte [map_pol+r15]
    sub eax, ecx
    movzx ecx, byte [map_noise+r15]
    shr ecx, 1
    sub eax, ecx
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .lvn
    movzx ecx, byte [rbx+T_LEVEL]
    shl ecx, 3
    add eax, ecx
    test byte [rbx+T_FLAGS2], F2_GARBAGE
    jz .lvn
    sub eax, 25
.lvn:
    CLAMP eax, 0, 255
    mov [map_lv+r15], al
    xor eax, eax
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .cr
    movzx eax, byte [rbx+T_LEVEL]
    imul eax, 14
    movzx ecx, byte [map_lv+r15]
    mov edx, 140
    sub edx, ecx
    CLAMP edx, 0, 140
    shr edx, 1
    add eax, edx
    movzx ecx, byte [rbx+T_EDU]
    shr ecx, 3
    sub eax, ecx
    movzx ecx, byte [map_police+r15]
    sub eax, ecx
    CLAMP eax, 0, 255
.cr:
    mov [map_crime+r15], al
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .ne
    movzx eax, byte [rbx+T_ZONE]
    cmp byte [zone_class+rax], ZC_RES
    jne .ne
    movzx eax, byte [map_elem+r15]
    shr eax, 1
    movzx ecx, byte [map_high+r15]
    imul ecx, 3
    shr ecx, 3
    add eax, ecx
    movzx ecx, byte [map_uni+r15]
    shr ecx, 2
    add eax, ecx
    CLAMP eax, 0, 255
    movzx ecx, byte [rbx+T_EDU]
    sub eax, ecx
    sar eax, 3
    add ecx, eax
    CLAMP ecx, 0, 255
    mov [rbx+T_EDU], cl
.ne:
    inc r15d
    cmp r15d, MAP_TILES
    jl .lv
    mov eax, r12d
    xor edx, edx
    mov ecx, [rbp-60]
    test ecx, ecx
    jz .nt
    div ecx
.nt:
    mov [avg_traffic], eax
    RETURN

; =====================================================================
;  statistics, workforce and demand
; =====================================================================
FUNC stats_update, 48
    lea rdi, [population]
    xor eax, eax
    mov ecx, (cnt_nogoods - population)/4 + 1
    rep stosd
    mov [road_tiles], eax
    mov [road_cost], eax
    mov [n_res], eax
    mov [n_com], eax
    mov [n_ind], eax
    mov [n_off], eax
    mov [n_svc], eax
    mov [garbage_total], eax
    mov [landfill_cap], eax
    lea rdi, [svc_count]
    mov ecx, BK_COUNT
    rep stosd
    xor r12d, r12d
    xor r13d, r13d
    xor r14d, r14d
    mov dword [rbp-48], 0           ; education * pop
    mov dword [rbp-52], 0           ; office jobs
    mov dword [rbp-56], 0           ; hi-tech jobs
    mov dword [rbp-60], 0           ; basic jobs
    xor r15d, r15d
.l:
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_ROAD
    jne .nr
    inc dword [road_tiles]
    movzx eax, byte [rbx+T_ROADTYPE]
    inc eax
    add [road_cost], eax
    jmp .n
.nr:
    cmp eax, OBJ_SERVICE
    jne .ns
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .n
    movzx eax, byte [rbx+T_SUB]
    inc dword [svc_count+rax*4]
    ; services that need electricity show it
    mov byte [rbx+T_PROBLEM], 0
    test byte [rbx+T_FLAGS], F_FIRE
    jz .sf
    mov byte [rbx+T_PROBLEM], PR_FIRE
.sf:
    cmp byte [svc_needs_power+rax], 0
    je .sp
    test byte [rbx+T_FLAGS], F_POWER
    jnz .sp
    mov byte [rbx+T_PROBLEM], PR_POWER
.sp:
    mov ecx, [n_svc]
    cmp ecx, 1024
    jge .n
    mov [list_svc+rcx*2], r15w
    inc dword [n_svc]
    cmp eax, BK_LANDFILL
    jne .n
    add dword [landfill_cap], 150000
    jmp .n
.ns:
    cmp eax, OBJ_ZONEBLD
    jne .n
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .n
    test byte [rbx+T_FLAGS], F_FIRE
    jz .nf
    inc dword [cnt_fire]
.nf:
    test byte [rbx+T_FLAGS], F_ABANDON
    jz .nab
    inc dword [cnt_abandon]
.nab:
    test byte [rbx+T_FLAGS], F_BUILD
    jnz .n
    test byte [rbx+T_FLAGS], F_POWER
    jnz .pw
    inc dword [cnt_unpowered]
.pw:
    test byte [rbx+T_FLAGS], F_ROADOK
    jnz .rd
    inc dword [cnt_noroad]
.rd:
    cmp byte [rbx+T_LEVEL], 2
    jb .wt
    test byte [rbx+T_FLAGS], F_WATER
    jnz .wt
    inc dword [cnt_nowater]
.wt:
    test byte [rbx+T_FLAGS2], F2_GARBAGE
    jz .gb
    inc dword [cnt_garbage]
.gb:
    movzx eax, byte [rbx+T_GARBAGE]
    add [garbage_total], eax
    movzx ecx, word [rbx+T_POP]
    movzx eax, byte [rbx+T_ZONE]
    movzx eax, byte [zone_class+rax]
    cmp eax, ZC_RES
    jne .job
    add [population], ecx
    inc dword [cnt_r]
    mov edx, [n_res]
    cmp edx, MAX_LIST
    jge .rl
    mov [list_res+rdx*2], r15w
    inc dword [n_res]
.rl:
    movzx eax, byte [rbx+T_HAPPY]
    imul eax, ecx
    add r12d, eax
    movzx eax, byte [map_pol+r15]
    imul eax, ecx
    add r13d, eax
    movzx eax, byte [map_crime+r15]
    imul eax, ecx
    add r14d, eax
    movzx eax, byte [rbx+T_EDU]
    imul eax, ecx
    add [rbp-48], eax
    jmp .n
.job:
    add [jobs+rax*4], ecx
    cmp eax, ZC_COM
    jne .j2
    inc dword [cnt_c]
    add [rbp-60], ecx
    test byte [rbx+T_FLAGS2], F2_NOGOODS
    jz .cgl
    inc dword [cnt_nogoods]
.cgl:
    mov edx, [n_com]
    cmp edx, MAX_LIST
    jge .n
    mov [list_com+rdx*2], r15w
    inc dword [n_com]
    jmp .n
.j2:
    cmp eax, ZC_IND
    jne .j3
    inc dword [cnt_i]
    cmp byte [rbx+T_LEVEL], 5
    jne .ib
    cmp byte [rbx+T_SUB], 0
    jne .ib
    add [rbp-56], ecx
    jmp .il
.ib:
    add [rbp-60], ecx
.il:
    mov edx, [n_ind]
    cmp edx, MAX_LIST
    jge .n
    mov [list_ind+rdx*2], r15w
    inc dword [n_ind]
    jmp .n
.j3:
    inc dword [cnt_o]
    add [rbp-52], ecx
    mov edx, [n_off]
    cmp edx, MAX_LIST
    jge .n
    mov [list_off+rdx*2], r15w
    inc dword [n_off]
.n:
    inc r15d
    cmp r15d, MAP_TILES
    jl .l

    mov eax, [jobs+ZC_COM*4]
    mov [jobs_c], eax
    mov eax, [jobs+ZC_IND*4]
    mov [jobs_i], eax

    mov ecx, [population]
    test ecx, ecx
    jz .nopop
    mov eax, r12d
    xor edx, edx
    div ecx
    mov [happy_avg], eax
    mov eax, r13d
    xor edx, edx
    div ecx
    mov [avg_pollution], eax
    mov eax, r14d
    xor edx, edx
    div ecx
    mov [avg_crime], eax
    mov eax, [rbp-48]
    xor edx, edx
    div ecx
    mov [avg_edu], eax
    jmp .wf
.nopop:
    mov dword [happy_avg], 60
.wf:
    ; ---- workforce ----
    mov eax, [population]
    imul eax, 55
    xor edx, edx
    mov ecx, 100
    div ecx
    mov [workers], eax
    mov ecx, [avg_edu]
    imul eax, ecx
    shr eax, 8
    mov [edu_workers], eax
    mov eax, [workers]
    mov ecx, [avg_edu]
    sub ecx, 120
    jge .he
    xor ecx, ecx
.he:
    imul eax, ecx
    xor edx, edx
    mov ebx, 135
    div ebx
    mov [hedu_workers], eax
    ; fill hi-tech, then office, then basic jobs
    mov r12d, [hedu_workers]
    mov edi, r12d
    mov esi, [rbp-56]
    call fill_ratio
    mov [staff_hedu], eax
    mov eax, [rbp-56]
    cmp eax, r12d
    jle .h1
    mov eax, r12d
.h1:
    mov r14d, eax                   ; skilled filled so far
    mov r13d, [edu_workers]
    sub r13d, eax
    jge .h2
    xor r13d, r13d
.h2:
    mov edi, r13d
    mov esi, [rbp-52]
    call fill_ratio
    mov [staff_edu], eax
    mov eax, [rbp-52]
    cmp eax, r13d
    jle .h3
    mov eax, r13d
.h3:
    add r14d, eax
    mov ebx, [workers]
    sub ebx, r14d
    jge .h4
    xor ebx, ebx
.h4:
    ; commuters from the region help a young city
    cmp dword [population], 1500
    jg .nc
    mov eax, [rbp-60]
    shr eax, 1
    add ebx, eax
.nc:
    mov edi, ebx
    mov esi, [rbp-60]
    call fill_ratio
    mov [staff_basic], eax
    mov eax, [rbp-60]
    cmp eax, ebx
    jle .h5
    mov eax, ebx
.h5:
    add r14d, eax
    mov eax, [workers]
    sub eax, r14d
    jge .h6
    xor eax, eax
.h6:
    mov [unemployed], eax
    call apply_staffing

    ; ---- demand ----
    mov eax, [rbp-60]
    add eax, [rbp-52]
    add eax, [rbp-56]
    sub eax, [workers]
    mov ecx, [population]
    shr ecx, 3
    add ecx, 30
    imul eax, 100
    cdq
    idiv ecx
    add eax, 40
    mov ecx, [happy_avg]
    sub ecx, 55
    add eax, ecx
    mov ecx, [tax_rate+ZC_RES*4]
    sub ecx, 9
    imul ecx, 6
    sub eax, ecx
    cmp dword [population], 400
    jg .rr
    add eax, 30
.rr:
    mov edi, ZC_RES
    call smooth_demand
    mov eax, [population]
    xor edx, edx
    mov ecx, 3
    div ecx
    sub eax, [jobs+ZC_COM*4]
    mov ecx, [population]
    shr ecx, 3
    add ecx, 20
    imul eax, 100
    cdq
    idiv ecx
    mov ecx, [tax_rate+ZC_COM*4]
    sub ecx, 9
    imul ecx, 6
    sub eax, ecx
    mov edi, ZC_COM
    call smooth_demand
    mov eax, [unemployed]
    mov ecx, [population]
    shr ecx, 3
    add ecx, 30
    imul eax, 100
    cdq
    idiv ecx
    add eax, [ext_demand]
    mov ecx, [avg_pollution]
    shr ecx, 3
    sub eax, ecx
    mov ecx, [cnt_nogoods]
    shl ecx, 2
    add eax, ecx
    mov ecx, [tax_rate+ZC_IND*4]
    sub ecx, 9
    imul ecx, 6
    sub eax, ecx
    mov edi, ZC_IND
    call smooth_demand
    mov eax, [edu_workers]
    sub eax, [rbp-52]
    mov ecx, [population]
    shr ecx, 3
    add ecx, 30
    imul eax, 100
    cdq
    idiv ecx
    sub eax, 10
    cmp dword [population], 300
    jge .o1
    sub eax, 40
.o1:
    mov ecx, [tax_rate+ZC_OFF*4]
    sub ecx, 9
    imul ecx, 6
    sub eax, ecx
    mov edi, ZC_OFF
    call smooth_demand
    RETURN

; fill_ratio(edi available, esi needed) -> eax 0..256
fill_ratio:
    mov eax, 256
    test esi, esi
    jz .o
    cmp edi, esi
    jge .o
    mov eax, edi
    shl eax, 8
    xor edx, edx
    div esi
.o: ret

; smooth_demand(edi class, eax raw)
smooth_demand:
    CLAMP eax, -100, 100
    mov ecx, [demand+rdi*4]
    lea ecx, [rcx*2+rcx]
    add eax, ecx
    sar eax, 2
    mov [demand+rdi*4], eax
    ret

; mark job buildings that lack staff
FUNC apply_staffing
    xor r15d, r15d
.l:
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .n
    and byte [rbx+T_FLAGS2], ~F2_NOWORKERS
    movzx eax, byte [rbx+T_ZONE]
    movzx eax, byte [zone_class+rax]
    cmp eax, ZC_RES
    je .n
    mov ecx, [staff_basic]
    cmp eax, ZC_OFF
    jne .i
    mov ecx, [staff_edu]
    jmp .s
.i:
    cmp eax, ZC_IND
    jne .s
    cmp byte [rbx+T_LEVEL], 5
    jne .s
    cmp byte [rbx+T_SUB], 0
    jne .s
    mov ecx, [staff_hedu]
.s:
    CLAMP ecx, 0, 255
    mov [rbx+T_WORKERS], cl
    cmp ecx, 128
    jae .n
    or byte [rbx+T_FLAGS2], F2_NOWORKERS
.n:
    inc r15d
    cmp r15d, MAP_TILES
    jl .l
    RETURN

; =====================================================================
;  month end: budget, history, milestones, events
; =====================================================================
FUNC month_end, 32
    mov eax, [population]
    imul eax, [tax_rate+ZC_RES*4]
    xor edx, edx
    mov ecx, 12
    div ecx
    mov [inc_class], eax
    mov eax, [jobs+ZC_COM*4]
    imul eax, [tax_rate+ZC_COM*4]
    xor edx, edx
    mov ecx, 14
    div ecx
    mov [inc_class+4], eax
    mov eax, [jobs+ZC_IND*4]
    imul eax, [tax_rate+ZC_IND*4]
    xor edx, edx
    mov ecx, 16
    div ecx
    ; industrial filters are paid for out of industry's taxes
    test dword [policies], P_FILTERS
    jz .nfl
    lea eax, [rax*2+rax]
    shr eax, 2
.nfl:
    mov [inc_class+8], eax
    mov eax, [jobs+ZC_OFF*4]
    imul eax, [tax_rate+ZC_OFF*4]
    xor edx, edx
    mov ecx, 10
    div ecx
    mov [inc_class+12], eax
    mov eax, [exports_month]
    add eax, [fares_month]
    cmp dword [svc_count+BK_LANDMARK*4], 0
    je .nl
    mov ecx, [population]
    shr ecx, 3
    add eax, ecx
    add eax, 500
.nl:
    cmp dword [svc_count+BK_STADIUM*4], 0
    je .ns
    mov ecx, [population]
    shr ecx, 5
    add eax, ecx
.ns:
    mov [inc_other], eax
    mov dword [exports_month], 0
    mov ecx, [riders_month]
    mov [bus_riders], ecx
    mov dword [riders_month], 0
    mov dword [fares_month], 0
    mov eax, [inc_class]
    add eax, [inc_class+4]
    add eax, [inc_class+8]
    add eax, [inc_class+12]
    add eax, [inc_other]
    mov [income_last], eax
    mov eax, [road_cost]
    xor edx, edx
    mov ecx, 3
    div ecx
    mov [exp_roads], eax
    xor ebx, ebx
    xor r12d, r12d
    lea rdi, [exp_cat]
    xor eax, eax
    mov ecx, 8
    rep stosd
.svc:
    mov edi, ebx
    call bld_rec
    mov ecx, [rax+BI_UPKEEP]
    imul ecx, [svc_count+rbx*4]
    add r12d, ecx
    movzx eax, byte [rax+BI_CATEGORY]
    add [exp_cat+rax*4], ecx
    inc ebx
    cmp ebx, BK_COUNT
    jl .svc
    mov [exp_services], r12d
    xor ebx, ebx
    xor r12d, r12d
.pol:
    bt dword [policies], ebx
    jnc .pn
    mov ecx, [policy_cost_div+rbx*4]
    test ecx, ecx
    jz .pn
    mov eax, [population]
    xor edx, edx
    div ecx
    add eax, 10
    add r12d, eax
.pn:
    inc ebx
    cmp ebx, POLICY_COUNT
    jl .pol
    mov [exp_policies], r12d
    ; loan repayments
    xor ecx, ecx
    xor edx, edx
.ln:
    cmp dword [loan_left+rcx*4], 0
    je .lnn
    dec dword [loan_left+rcx*4]
    add edx, [loan_payment+rcx*4]
.lnn:
    inc ecx
    cmp ecx, 3
    jl .ln
    mov [exp_loans], edx
    mov eax, [exp_roads]
    add eax, [exp_services]
    add eax, r12d
    add eax, edx
    mov [expense_last], eax
    movsxd rax, dword [income_last]
    add [money], rax
    movsxd rax, dword [expense_last]
    sub [money], rax
    mov eax, [income_last]
    sub eax, [expense_last]
    movsxd rdi, eax
    call fx_month_cash
    cmp qword [money], 0
    jge .solvent
    lea rdi, [msg_broke]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
    call emergency_pause
.solvent:
    mov eax, [hist_count]
    and eax, 63
    mov ecx, [population]
    mov [hist_pop+rax*4], ecx
    mov rcx, [money]
    mov [hist_money+rax*4], ecx
    inc dword [hist_count]
    cmp dword [ext_demand], 60
    jge .ed
    inc dword [ext_demand]
.ed:
    call age_buildings
    call assists_month
    call check_milestone
    call random_event
    call autosave_tick
    inc dword [month]
    cmp dword [month], 12
    jl .out
    mov dword [month], 0
    inc dword [year]
    call tb_reset
    lea rdi, [msg_newyear]
    call tb_str
    movsxd rdi, dword [year]
    call tb_num_plain
    lea rdi, [textbuf]
    mov esi, UI_GOLD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_CHIME
    call sfx_play
.out:
    RETURN

; every building gets a month older (up to ~21 years)
FUNC age_buildings
    xor ecx, ecx
.l:
    mov eax, ecx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ZONEBLD
    jne .n
    cmp byte [tiles+rax+T_AGE], 255
    je .n
    inc byte [tiles+rax+T_AGE]
.n:
    inc ecx
    cmp ecx, MAP_TILES
    jl .l
    RETURN

FUNC check_milestone
    mov eax, [milestone]
    cmp eax, 9
    jge .out
    mov ecx, [milestone_pop+rax*4+4]
    cmp [population], ecx
    jl .out
    inc dword [milestone]
    mov ebx, [milestone]
    mov [ms_card], ebx
    movsxd rax, dword [milestone_cash+rbx*4]
    add [money], rax
    call tb_reset
    lea rdi, [msg_milestone]
    call tb_str
    mov rdi, [milestone_names+rbx*8]
    call tb_str
    lea rdi, [msg_reward]
    call tb_str
    movsxd rdi, dword [milestone_cash+rbx*4]
    call tb_money
    lea rdi, [textbuf]
    mov esi, UI_GOLD
    mov edx, -1
    mov ecx, -1
    call notify
    call fx_milestone
.out:
    RETURN

; ---------------------------------------------------------------------
;  land plots (a 5x5 grid) and unlocks
; ---------------------------------------------------------------------
; plot_of(edi x, esi y) -> eax plot index
plot_of:
    lea eax, [rsi*4+rsi]
    shr eax, MAP_SHIFT
    imul eax, PLOTS
    lea ecx, [rdi*4+rdi]
    shr ecx, MAP_SHIFT
    add eax, ecx
    ret

; tile_owned(edi x, esi y) -> eax 1 if the player may build here
tile_owned:
    xor eax, eax
    cmp edi, MAP_W
    jae .o
    cmp esi, MAP_W
    jae .o
    call plot_of
    movzx eax, byte [plot_owned+rax]
.o: ret

; plots owned -> eax
plots_owned:
    xor eax, eax
    xor ecx, ecx
.l: movzx edx, byte [plot_owned+rcx]
    add eax, edx
    inc ecx
    cmp ecx, PLOTS*PLOTS
    jl .l
    ret

; plots the milestones allow -> eax: one more per milestone, and all of
; them once the city is a Megalopolis
plots_allowed:
    mov eax, [milestone]
    cmp eax, 9
    jge .all
    add eax, 1
    ret
.all:
    mov eax, PLOTS*PLOTS
    ret

; price of the next plot -> eax
plot_price:
    call plots_owned
    mov ecx, eax
    imul eax, eax, 5000
    imul ecx, ecx
    imul ecx, ecx, 1500
    add eax, ecx
    ret

; can plot edi be bought? -> eax 0 ok, 1 owned, 2 not next to your land,
; 3 needs a milestone, 4 no money
plot_status:
    push rbx
    mov ebx, edi
    mov eax, 1
    cmp byte [plot_owned+rbx], 0
    jne .o
    ; a neighbour must be owned
    mov eax, ebx
    xor edx, edx
    mov ecx, PLOTS
    div ecx                         ; eax row, edx col
    mov r8d, eax
    mov r9d, edx
    xor r10d, r10d
    test r9d, r9d
    jz .a
    movzx ecx, byte [plot_owned+rbx-1]
    or r10d, ecx
.a: cmp r9d, PLOTS-1
    je .b
    movzx ecx, byte [plot_owned+rbx+1]
    or r10d, ecx
.b: test r8d, r8d
    jz .c
    movzx ecx, byte [plot_owned+rbx-PLOTS]
    or r10d, ecx
.c: cmp r8d, PLOTS-1
    je .d
    movzx ecx, byte [plot_owned+rbx+PLOTS]
    or r10d, ecx
.d: mov eax, 2
    test r10d, r10d
    jz .o
    call plots_owned
    mov ecx, eax
    call plots_allowed
    cmp ecx, eax
    mov eax, 3
    jge .o
    call plot_price
    movsxd rax, eax
    cmp rax, [money]
    mov eax, 4
    jg .o
    xor eax, eax
.o: pop rbx
    ret

; population whose milestone has been reached (unlocks) -> eax
unlocked_pop:
    mov eax, [milestone]
    mov eax, [milestone_pop+rax*4]
    ret

; milestone index for an unlock population (edi) -> eax
milestone_for:
    xor eax, eax
.l: cmp eax, 9
    jge .o
    cmp [milestone_pop+rax*4], edi
    jge .o
    inc eax
    jmp .l
.o: ret

; ---------------------------------------------------------------------
;  random events: fires, meteors, booms
; ---------------------------------------------------------------------
FUNC random_event
    mov eax, [cnt_r]
    add eax, [cnt_c]
    add eax, [cnt_i]
    add eax, [cnt_o]
    cmp eax, 20
    jl .nofire
    call rand
    and eax, 3
    jnz .nofire
    test dword [policies], P_SMOKE
    jz .try0
    call rand
    and eax, 1
    jnz .nofire
.try0:
    mov ebx, 40
.try:
    call rand
    and eax, MAP_TILES-1
    mov r12d, eax
    shl eax, TILE_SHIFT
    lea r13, [tiles+rax]
    cmp byte [r13+T_OBJ], OBJ_ZONEBLD
    jne .tn
    test byte [r13+T_FLAGS], F_BUILD
    jnz .tn
    test byte [r13+T_FLAGS], F_ANCHOR
    jz .tn
    movzx eax, byte [map_fire+r12]
    cmp eax, 150
    jg .nofire
    or byte [r13+T_FLAGS], F_FIRE
    mov byte [r13+T_TIMER], 0
    call emergency_pause
    lea rdi, [msg_fire]
    mov esi, UI_BAD
    mov edx, r12d
    and edx, MAP_W-1
    mov ecx, r12d
    shr ecx, MAP_SHIFT
    call notify
    mov edi, SFX_ALARM
    call sfx_play
    jmp .nofire
.tn:
    dec ebx
    jnz .try
.nofire:
    cmp dword [cnt_i], 10
    jl .nb
    call rand
    and eax, 31
    jnz .nb
    add dword [ext_demand], 15
    lea rdi, [msg_boom]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
.nb:
    cmp dword [disasters_on], 0
    je .out
    cmp dword [population], 1500
    jl .out
    call rand
    and eax, 63
    jnz .out
    call rand
    and eax, MAP_TILES-1
    mov edi, eax
    and edi, MAP_W-1
    mov esi, eax
    shr esi, MAP_SHIFT
    push rdi
    push rsi
    call emergency_pause
    pop rsi
    pop rdi
    call meteor_strike
.out:
    RETURN

FUNC meteor_strike
    mov r12d, edi
    mov r13d, esi
    CLAMP r12d, 3, MAP_W-4
    CLAMP r13d, 3, MAP_W-4
    mov r14d, -2
.dy:
    mov r15d, -2
.dx:
    mov eax, r14d
    imul eax, eax
    mov ecx, r15d
    imul ecx, ecx
    add eax, ecx
    cmp eax, 5
    jg .n
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call tile_at
    mov rbx, rax
    cmp byte [rbx+T_TERRAIN], TER_WATER
    je .n
    test byte [rbx+T_FLAGS], F_HIGHWAY
    jnz .n
    mov cl, [rbx+T_OBJ]
    cmp cl, OBJ_NONE
    je .dirt
    cmp cl, OBJ_TREE
    je .dirt
    cmp cl, OBJ_RUBBLE
    je .dirt
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call destroy_to_rubble
    jmp .n
.dirt:
    mov rdi, rbx
    call make_rubble
    mov byte [rbx+T_ZONE], 0
.n:
    inc r15d
    cmp r15d, 2
    jle .dx
    inc r14d
    cmp r14d, 2
    jle .dy
    mov ebx, 6
.f:
    mov edi, 7
    call rand_range
    lea r14d, [rax-3]
    mov edi, 7
    call rand_range
    lea r15d, [rax-3]
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call tile_at
    test rax, rax
    jz .fn
    cmp byte [rax+T_OBJ], OBJ_ZONEBLD
    jne .fn
    or byte [rax+T_FLAGS], F_FIRE
    mov byte [rax+T_TIMER], 0
.fn:
    dec ebx
    jnz .f
    lea rdi, [msg_meteor]
    mov esi, UI_BAD
    mov edx, r12d
    mov ecx, r13d
    call notify
    mov edi, r12d
    mov esi, r13d
    call fx_meteor
    mov dword [net_dirty], 1
    RETURN

; ---------------------------------------------------------------------
tb_date:
    mov eax, [month]
    lea rdi, [month_names+rax*4]
    call tb_str
    mov edi, ' '
    call tb_char
    movsxd rdi, dword [year]
    jmp tb_num_plain

tb_num_plain:
    lea r8, [numbuf+63]
    mov byte [r8], 0
    mov rax, rdi
    mov r10, 10
.d:
    xor edx, edx
    div r10
    add dl, '0'
    dec r8
    mov [r8], dl
    test rax, rax
    jnz .d
    mov rdi, r8
    jmp tb_str
