; =====================================================================
;  SIM - the city simulation
;
;  Time: a day passes every DAY_TICKS[speed] ticks.  Each day
;    * construction / fires advance for every tile
;    * one eighth of the map runs the zone growth model
;    * every 4 days the utility networks are re-flooded
;    * every 8 days coverage, pollution, crime, traffic and land value
;      maps are rebuilt
;  At month end the budget is settled and milestones are checked.
; =====================================================================

OV_NONE     equ 0
OV_POWER    equ 1
OV_WATER    equ 2
OV_POLLUTE  equ 3
OV_CRIME    equ 4
OV_LANDVAL  equ 5
OV_TRAFFIC  equ 6
OV_POLICE   equ 7
OV_FIRE     equ 8
OV_HEALTH   equ 9
OV_EDU      equ 10
OV_HAPPY    equ 11
OV_COUNT    equ 12

MISC_NET    equ 1       ; road reaches the highway
MISC_NEARW  equ 2       ; near water (scenic)

section .bss
alignb 16
map_lv          resb MAP_TILES
map_pol         resb MAP_TILES
map_crime       resb MAP_TILES
map_police      resb MAP_TILES
map_fire        resb MAP_TILES
map_health      resb MAP_TILES
map_edu         resb MAP_TILES
map_park        resb MAP_TILES
map_traffic     resb MAP_TILES
map_scenic      resb MAP_TILES
alignb 16
comp_map        resw MAP_TILES
bfs_queue       resw MAP_TILES+16
MAX_COMPS equ 4096
comp_supply     resd MAX_COMPS
comp_demand     resd MAX_COMPS

money           resq 1
sim_speed       resd 1          ; 0 paused, 1..3
day_timer       resd 1
day             resd 1          ; 0..29
month           resd 1          ; 0..11
year            resd 1
day_count       resd 1          ; days since start
tax_rate        resd 1

population      resd 1
jobs_c          resd 1
jobs_i          resd 1
workers         resd 1
cnt_r           resd 1
cnt_c           resd 1
cnt_i           resd 1
cnt_abandon     resd 1
cnt_fire        resd 1
cnt_unpowered   resd 1
cnt_nowater     resd 1
cnt_noroad      resd 1
demand_r        resd 1          ; -100..100
demand_c        resd 1
demand_i        resd 1
happy_avg       resd 1          ; 0..100
power_supply    resd 1
power_demand    resd 1
water_supply    resd 1
water_demand    resd 1
avg_traffic     resd 1
avg_pollution   resd 1
avg_crime       resd 1
ext_demand      resd 1          ; grows with time (industry trade)

income_last     resd 1
expense_last    resd 1
inc_res         resd 1
inc_com         resd 1
inc_ind         resd 1
exp_roads       resd 1
exp_services    resd 1
road_tiles      resd 1
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
sim_state_end:

section .data
DAY_TICKS   dd 0, 30, 14, 5
res_pop     dd 0, 8, 22, 60, 150, 380
com_jobs    dd 0, 6, 16, 40, 100, 240
ind_jobs    dd 0, 10, 26, 50, 90, 140
ind_poll    db 0, 35, 50, 75, 100, 20
use_power   dd 0, 2, 3, 6, 12, 24
use_water   dd 0, 2, 3, 6, 12, 24
cov_strength db 0, 220, 220, 200, 200, 150
bld_cov_boost db 0,0,0,0,0,0, 0,0,0,40,0,50, 0,20,40,20,60

; milestones: population, reward, name
milestone_pop   dd 0, 60, 250, 600, 1200, 2500, 5000, 9000, 16000, 30000, 0x7fffffff
milestone_cash  dd 0, 1000, 2000, 3500, 5000, 8000, 12000, 16000, 25000, 50000, 0
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
msg_nowater  db "Taps are running dry - build water pumps.", 0
msg_fire     db "Fire! A building is burning.", 0
msg_fire_out db "Firefighters put out a blaze.", 0
msg_burned   db "A building burned down.", 0
msg_milestone db "MILESTONE: ", 0
msg_reward   db "  Reward: ", 0
msg_broke    db "The treasury is empty! Raise taxes or cut costs.", 0
msg_abandon  db "Residents are abandoning buildings.", 0
msg_meteor   db "A METEOR has struck the city!", 0
msg_tourists db "Tourists flock to the Asm Tower: +$", 0
msg_boom     db "Industrial boom! Exports surge.", 0
msg_newyear  db "Happy new year! Year ", 0

section .text

; ---------------------------------------------------------------------
FUNC sim_init
    mov qword [money], 25000
    mov dword [sim_speed], 1
    mov dword [tax_rate], 9
    mov dword [year], 2026
    mov dword [month], 2
    mov dword [day], 0
    mov dword [ext_demand], 30
    mov dword [net_dirty], 1
    mov dword [cov_dirty], 1
    mov dword [disasters_on], 1
    mov dword [demand_r], 60
    mov dword [demand_c], 10
    mov dword [demand_i], 40
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
;  sim_tick: called at 60 Hz
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
    inc dword [day_count]
    call daily_tiles
    ; one eighth of the map per day
    mov eax, [day_count]
    and eax, 7
    shl eax, 4
    mov edi, eax
    mov esi, 16
    call zone_slice
    mov eax, [day_count]
    and eax, 3
    jnz .nn
    call networks_update
.nn:
    cmp dword [net_dirty], 0
    je .nd
    call networks_update
.nd:
    mov eax, [day_count]
    and eax, 7
    jnz .nc
    call coverage_update
.nc:
    cmp dword [cov_dirty], 0
    je .ncd
    mov dword [cov_dirty], 0
    call coverage_update
.ncd:
    call stats_update
    call check_goals
    inc dword [day]
    cmp dword [day], 30
    jl .out
    mov dword [day], 0
    call month_end
.out:
    RETURN

; ---------------------------------------------------------------------
;  daily per-tile work: construction progress and fires
; ---------------------------------------------------------------------
FUNC daily_tiles
    xor r13d, r13d                  ; y
.y:
    xor r12d, r12d
.x:
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    mov r14d, eax                   ; index
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    mov al, [rbx+T_FLAGS]
    test al, F_BUILD
    jz .nb
    ; construction
    movzx eax, byte [rbx+T_TIMER]
    add eax, 14
    cmp eax, 96
    jl .bstore
    ; finished: level up
    and byte [rbx+T_FLAGS], ~F_BUILD
    mov byte [rbx+T_TIMER], 0
    inc byte [rbx+T_LEVEL]
    cmp byte [rbx+T_LEVEL], 5
    jbe .lvok
    mov byte [rbx+T_LEVEL], 5
.lvok:
    mov rdi, rbx
    call set_tile_pop
    mov edi, r12d
    mov esi, r13d
    call fx_building_done
    jmp .nb
.bstore:
    mov [rbx+T_TIMER], al
.nb:
    test byte [rbx+T_FLAGS], F_FIRE
    jz .next
    ; burning
    movzx eax, byte [rbx+T_TIMER]
    inc eax
    mov [rbx+T_TIMER], al
    ; chance of extinguish from fire coverage
    movzx ecx, byte [map_fire+r14]
    call rand
    and eax, 255
    shr ecx, 2
    add ecx, 3
    cmp eax, ecx
    jae .spread
    and byte [rbx+T_FLAGS], ~F_FIRE
    mov byte [rbx+T_TIMER], 0
    lea rdi, [msg_fire_out]
    mov esi, UI_GOOD
    mov edx, r12d
    mov ecx, r13d
    call notify
    jmp .next
.spread:
    call rand
    and eax, 63
    cmp eax, 6
    jae .burnout
    ; ignite a random neighbour
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
    cmp byte [rbx+T_TIMER], 16
    jb .next
    ; destroyed
    mov edi, r12d
    mov esi, r13d
    call destroy_to_rubble
.next:
    inc r12d
    cmp r12d, MAP_W
    jl .x
    inc r13d
    cmp r13d, MAP_W
    jl .y
    RETURN

; destroy whatever is at (edi,esi) leaving rubble (whole footprint)
FUNC destroy_to_rubble
    mov r12d, edi
    mov r13d, esi
    call tile_at
    test rax, rax
    jz .out
    cmp byte [rax+T_OBJ], OBJ_SERVICE
    jne .single
    ; walk to anchor
    movzx ecx, byte [rax+T_ANCHOR]
    mov edx, ecx
    and ecx, 15
    shr edx, 4
    sub r12d, ecx
    sub r13d, edx
    mov edi, r12d
    mov esi, r13d
    call tile_at
    movzx edi, byte [rax+T_SUB]
    call bld_rec
    movzx r14d, byte [rax+BI_SIZE]
    xor ebx, ebx
.fy:
    xor r15d, r15d
.fx:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call tile_at
    mov rdi, rax
    call make_rubble
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
    mov byte [rdi+T_LEVEL], 0
    mov byte [rdi+T_TIMER], 0
    mov word [rdi+T_POP], 0
    mov byte [rdi+T_ANCHOR], 0
    ret

; set_tile_pop(rdi tile): residents/jobs from zone + level
set_tile_pop:
    movzx eax, byte [rdi+T_LEVEL]
    CLAMP eax, 0, 5
    movzx ecx, byte [rdi+T_ZONE]
    cmp ecx, ZONE_R
    jne .c
    mov eax, [res_pop+rax*4]
    jmp .s
.c: cmp ecx, ZONE_C
    jne .i
    mov eax, [com_jobs+rax*4]
    jmp .s
.i: mov eax, [ind_jobs+rax*4]
.s: test byte [rdi+T_FLAGS], F_ABANDON
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

; has_road_near(edi x, esi y) -> eax: 0 none, 1 road, 2 road on highway net
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
FUNC zone_update, 32
    mov r12d, edi
    mov r13d, esi
    call tile_at
    mov rbx, rax
    movzx eax, byte [rbx+T_ZONE]
    test eax, eax
    jz .out
    mov [rbp-48], eax               ; zone
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_NONE
    je .ok
    cmp eax, OBJ_ZONEBLD
    jne .out
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
    shr r15d, 1                     ; 0..127
    mov eax, [rbp-48]
    cmp eax, ZONE_R
    jne .dc
    mov eax, [demand_r]
    sar eax, 1
    add r15d, eax
    movzx eax, byte [map_health+r14]
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_edu+r14]
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_park+r14]
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_pol+r14]
    shr eax, 1
    sub r15d, eax
    movzx eax, byte [map_crime+r14]
    shr eax, 2
    sub r15d, eax
    jmp .dd
.dc:
    cmp eax, ZONE_C
    jne .di
    mov eax, [demand_c]
    sar eax, 1
    add r15d, eax
    movzx eax, byte [map_traffic+r14]
    CLAMP eax, 0, 120
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_edu+r14]
    shr eax, 4
    add r15d, eax
    movzx eax, byte [map_crime+r14]
    shr eax, 2
    sub r15d, eax
    movzx eax, byte [map_pol+r14]
    shr eax, 3
    sub r15d, eax
    jmp .dd
.di:
    ; industry cares little about land value
    shr r15d, 1
    add r15d, 30
    mov eax, [demand_i]
    sar eax, 1
    add r15d, eax
    movzx eax, byte [map_edu+r14]
    shr eax, 3
    add r15d, eax
    movzx eax, byte [map_crime+r14]
    shr eax, 3
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
    ; R and I need the highway (immigrants / trade)
    cmp dword [rbp-48], ZONE_C
    je .l1
    cmp dword [rbp-52], 2
    jne .tdone
.l1:
    cmp r15d, 22
    jl .tdone
    mov ecx, 1
    test byte [rbx+T_FLAGS], F_WATER
    jz .tdone
    cmp r15d, 58
    jl .tdone
    mov ecx, 2
    cmp r15d, 92
    jl .tdone
    mov ecx, 3
    ; level 4+ needs services
    mov eax, [rbp-48]
    cmp eax, ZONE_I
    je .ind45
    movzx eax, byte [map_police+r14]
    add al, [map_fire+r14]
    jc .svc_ok
    cmp eax, 60
    jl .tdone
.svc_ok:
    cmp r15d, 128
    jl .tdone
    mov ecx, 4
    movzx eax, byte [map_edu+r14]
    cmp eax, 40
    jl .tdone
    movzx eax, byte [map_health+r14]
    cmp eax, 30
    jl .tdone
    cmp r15d, 162
    jl .tdone
    mov ecx, 5
    jmp .tdone
.ind45:
    cmp r15d, 120
    jl .tdone
    mov ecx, 4
    movzx eax, byte [map_edu+r14]
    cmp eax, 90
    jl .tdone
    cmp r15d, 140
    jl .tdone
    mov ecx, 5
.tdone:
    mov [rbp-56], ecx               ; target

    ; ---- happiness (drifts toward conditions) ----
    mov eax, r15d
    shr eax, 1
    add eax, 20
    test byte [rbx+T_FLAGS], F_POWER
    jnz .hp
    sub eax, 40
.hp:
    movzx ecx, byte [rbx+T_LEVEL]
    cmp ecx, 2
    jl .hw
    test byte [rbx+T_FLAGS], F_WATER
    jnz .hw
    sub eax, 30
.hw:
    cmp dword [rbp-52], 0
    jne .hr
    sub eax, 40
.hr:
    mov ecx, [tax_rate]
    sub ecx, 9
    imul ecx, 3
    sub eax, ecx
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
    cmp eax, [rbp-56]
    jge .maybe_decline
    ; zone demand gate
    mov ecx, [rbp-48]
    mov edx, [demand_r+rcx*4-4]
    cmp edx, -30
    jl .out
    ; growth chance: 1 in (4 - demand/40)
    call rand
    and eax, 255
    mov ecx, [rbp-48]
    mov edx, [demand_r+rcx*4-4]
    add edx, 110
    CLAMP edx, 20, 230
    cmp eax, edx
    jae .out
    ; start construction
    cmp byte [rbx+T_OBJ], OBJ_NONE
    jne .up
    mov byte [rbx+T_OBJ], OBJ_ZONEBLD
    mov byte [rbx+T_LEVEL], 0
    call rand
    mov [rbx+T_VARIANT], al
.up:
    or byte [rbx+T_FLAGS], F_BUILD
    mov byte [rbx+T_TIMER], 0
    mov edi, r12d
    mov esi, r13d
    call fx_construct_start
    jmp .out
.maybe_decline:
    ; much worse than current -> slowly degrade
    mov ecx, [rbp-56]
    add ecx, 1
    cmp eax, ecx
    jle .out
    call rand
    and eax, 7
    jnz .out
    dec byte [rbx+T_LEVEL]
    cmp byte [rbx+T_LEVEL], 0
    jne .dp
    mov byte [rbx+T_OBJ], OBJ_NONE
.dp:
    mov rdi, rbx
    call set_tile_pop
.out:
    RETURN

; ---------------------------------------------------------------------
;  conductive(rdi tile, esi mode) -> eax 1/0
;  mode 0 = power, 1 = water
; ---------------------------------------------------------------------
conductive:
    movzx eax, byte [rdi+T_OBJ]
    cmp eax, OBJ_ROAD
    je .y
    cmp eax, OBJ_ZONEBLD
    je .y
    cmp eax, OBJ_SERVICE
    je .y
    cmp eax, OBJ_POWER
    jne .lot
    test esi, esi
    jz .y
    jmp .n
.lot:
    cmp eax, OBJ_NONE
    jne .n
    cmp byte [rdi+T_ZONE], 0
    je .n
.y: mov eax, 1
    ret
.n: xor eax, eax
    ret

; producer / consumer amounts for a tile in a network
; tile_supply(rdi tile, esi mode, edx x, ecx y) -> eax supply
FUNC tile_supply
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    xor eax, eax
    cmp byte [rbx+T_OBJ], OBJ_SERVICE
    jne .out
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .out
    test byte [rbx+T_FLAGS], F_FIRE
    jnz .none
    movzx edi, byte [rbx+T_SUB]
    mov r15d, edi
    call bld_rec
    test r12d, r12d
    jnz .water
    mov eax, [rax+BI_POWER]
    cmp r15d, BK_WIND
    jne .out
    ; wind output varies gently with the season
    mov ecx, [month]
    and ecx, 3
    imul ecx, 5
    add eax, ecx
    jmp .out
.water:
    mov eax, [rax+BI_WATER]
    test eax, eax
    jz .out
    ; water works need power
    test byte [rbx+T_FLAGS], F_POWER
    jz .none
    cmp r15d, BK_PUMP
    jne .out
    push rax
    push rax
    mov edi, r13d
    mov esi, r14d
    call count_water_near
    mov ecx, eax
    pop rax
    pop rax
    test ecx, ecx
    jnz .out
.none:
    xor eax, eax
.out:
    RETURN

tile_demand:  ; (rdi tile, esi mode) -> eax
    xor eax, eax
    cmp byte [rdi+T_OBJ], OBJ_ZONEBLD
    jne .svc
    movzx eax, byte [rdi+T_LEVEL]
    CLAMP eax, 0, 5
    mov eax, [use_power+rax*4]
    movzx ecx, byte [rdi+T_ZONE]
    cmp ecx, ZONE_I
    jne .o
    lea eax, [rax+rax]
    ret
.svc:
    cmp byte [rdi+T_OBJ], OBJ_SERVICE
    jne .o
    test byte [rdi+T_FLAGS], F_ANCHOR
    jz .o
    mov eax, 6
.o: ret

; ---------------------------------------------------------------------
;  flood one network kind (esi mode) and set F_POWER / F_WATER
; ---------------------------------------------------------------------
FUNC network_flood, 48
    mov [rbp-48], esi               ; mode
    mov eax, F_POWER
    test esi, esi
    jz .f
    mov eax, F_WATER
.f:
    mov [rbp-52], eax               ; flag
    lea rdi, [comp_map]
    xor eax, eax
    mov ecx, MAP_TILES/2
    rep stosd
    lea rdi, [comp_supply]
    mov ecx, MAX_COMPS
    rep stosd
    lea rdi, [comp_demand]
    mov ecx, MAX_COMPS
    rep stosd
    mov dword [rbp-56], 0           ; comp count
    mov dword [rbp-60], 0           ; total supply
    mov dword [rbp-64], 0           ; total demand

    xor r15d, r15d                  ; tile index
.scan:
    cmp r15d, MAP_TILES
    jge .assign
    cmp word [comp_map+r15*2], 0
    jne .snext
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    mov esi, [rbp-48]
    call conductive
    test eax, eax
    jz .snext
    ; new component
    mov eax, [rbp-56]
    inc eax
    cmp eax, MAX_COMPS-1
    jge .snext
    mov [rbp-56], eax
    mov [rbp-68], eax               ; comp id
    ; BFS
    mov [comp_map+r15*2], ax
    mov [bfs_queue], r15w
    xor r12d, r12d                  ; head
    mov r13d, 1                     ; tail
.bfs:
    cmp r12d, r13d
    jge .snext
    movzx r14d, word [bfs_queue+r12*2]
    inc r12d
    ; account supply / demand
    mov eax, r14d
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    mov [rbp-80], rdi
    mov esi, [rbp-48]
    mov edx, r14d
    and edx, MAP_W-1
    mov ecx, r14d
    shr ecx, MAP_SHIFT
    call tile_supply
    mov ecx, [rbp-68]
    add [comp_supply+rcx*4], eax
    add [rbp-60], eax
    mov rdi, [rbp-80]
    mov esi, [rbp-48]
    call tile_demand
    mov ecx, [rbp-68]
    add [comp_demand+rcx*4], eax
    add [rbp-64], eax
    ; neighbours
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
    mov eax, esi
    shl eax, MAP_SHIFT
    add eax, edi
    cmp word [comp_map+rax*2], 0
    jne .nbn
    mov [rbp-72], eax
    shl eax, TILE_SHIFT
    lea rdi, [tiles+rax]
    mov esi, [rbp-48]
    call conductive
    test eax, eax
    jz .nbn
    mov eax, [rbp-72]
    mov ecx, [rbp-68]
    mov [comp_map+rax*2], cx
    mov [bfs_queue+r13*2], ax
    inc r13d
.nbn:
    inc ebx
    cmp ebx, 4
    jl .nb
    jmp .bfs
.snext:
    inc r15d
    jmp .scan

.assign:
    ; set flags from component balance
    xor r15d, r15d
.as:
    cmp r15d, MAP_TILES
    jge .done
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    mov ecx, [rbp-52]
    not ecx
    and [rbx+T_FLAGS], cl
    movzx eax, word [comp_map+r15*2]
    test eax, eax
    jz .asn
    mov ecx, [comp_supply+rax*4]
    test ecx, ecx
    jz .asn
    mov edx, [comp_demand+rax*4]
    cmp ecx, edx
    jge .on
    ; brownout: a deterministic share of tiles stays lit
    imul ecx, 256
    push rdx
    mov eax, ecx
    xor edx, edx
    pop rcx
    test ecx, ecx
    jz .on
    div ecx
    mov r12d, eax                   ; share 0..255
    mov edi, r15d
    add edi, [day_count]
    shr edi, 3
    xor edi, r15d
    call hash32
    and eax, 255
    cmp eax, r12d
    jae .asn
.on:
    mov ecx, [rbp-52]
    or [rbx+T_FLAGS], cl
.asn:
    inc r15d
    jmp .as
.done:
    mov eax, [rbp-60]
    mov edx, [rbp-64]
    cmp dword [rbp-48], 0
    jne .ws
    mov [power_supply], eax
    mov [power_demand], edx
    RETURN
.ws:
    mov [water_supply], eax
    mov [water_demand], edx
    RETURN

; road connectivity to the highway (MISC_NET)
FUNC road_connectivity
    xor r15d, r15d
    xor r13d, r13d                  ; queue tail
.clr:
    mov eax, r15d
    shl eax, TILE_SHIFT
    and byte [tiles+rax+T_MISC], ~MISC_NET
    test byte [tiles+rax+T_FLAGS], F_HIGHWAY
    jz .cn
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    jne .cn
    or byte [tiles+rax+T_MISC], MISC_NET
    mov [bfs_queue+r13*2], r15w
    inc r13d
.cn:
    inc r15d
    cmp r15d, MAP_TILES
    jl .clr
    xor r12d, r12d
.bfs:
    cmp r12d, r13d
    jge .out
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
    mov [bfs_queue+r13*2], ax
    inc r13d
.nn:
    inc ebx
    cmp ebx, 4
    jl .nb
    jmp .bfs
.out:
    RETURN

FUNC networks_update
    mov dword [net_dirty], 0
    call road_connectivity
    xor esi, esi
    call network_flood
    mov esi, 1
    call network_flood
    ; warnings (once until fixed)
    mov eax, [power_demand]
    cmp eax, [power_supply]
    jle .pok
    cmp dword [brownout_warned], 0
    jne .w
    mov dword [brownout_warned], 1
    lea rdi, [msg_brownout]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .w
.pok:
    mov dword [brownout_warned], 0
.w:
    mov eax, [water_demand]
    cmp eax, 40
    jl .wok
    cmp eax, [water_supply]
    jle .wok
    cmp dword [water_warned], 0
    jne .out
    mov dword [water_warned], 1
    lea rdi, [msg_nowater]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .out
.wok:
    mov dword [water_warned], 0
.out:
    RETURN

; ---------------------------------------------------------------------
;  stamp(rdi map, edi.. ) radial falloff add
;  stamp(rdi map, esi cx, edx cy, ecx radius, r8d strength)
; ---------------------------------------------------------------------
FUNC stamp, 32
    mov [rbp-56], rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d
    mov eax, ecx
    imul eax, eax
    mov [rbp-48], eax               ; r^2
    mov ebx, r14d
    neg ebx                         ; dy
.dy:
    cmp ebx, r14d
    jg .out
    lea eax, [r13+rbx]
    cmp eax, MAP_W
    jae .dyn
    mov ecx, r14d
    neg ecx                         ; dx
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
    add eax, edx                    ; d^2
    mov edx, [rbp-48]
    sub edx, eax
    jl .dxn
    ; v = strength * (r^2 - d^2) / r^2
    mov eax, edx
    imul eax, r15d
    xor edx, edx
    push rcx
    mov ecx, [rbp-48]
    test ecx, ecx
    jnz .dv
    inc ecx
.dv:
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

; subtract version (clamped at 0)
FUNC stamp_sub, 32
    mov [rbp-56], rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d
    mov ebx, r14d
    neg ebx
.dy:
    cmp ebx, r14d
    jg .out
    lea eax, [r13+rbx]
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
cov_maps dq 0, map_police, map_fire, map_health, map_edu, map_park
section .text

; ---------------------------------------------------------------------
;  coverage_update: services, pollution, traffic, crime, land value
; ---------------------------------------------------------------------
FUNC coverage_update, 32
    lea rdi, [map_pol]
    xor eax, eax
    mov ecx, MAP_TILES*7/4          ; pol, crime, police, fire, health, edu, park
    rep stosd
    lea rdi, [map_traffic]
    mov ecx, MAP_TILES/4
    rep stosd

    xor r13d, r13d
.y:
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
    jmp .next
.svc:
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .next
    movzx edi, byte [rbx+T_SUB]
    mov r14d, edi
    call bld_rec
    mov r15, rax
    ; pollution
    movzx r8d, byte [r15+BI_POLL]
    test r8d, r8d
    jz .nopol
    lea rdi, [map_pol]
    movzx eax, byte [r15+BI_SIZE]
    shr eax, 1
    lea esi, [r12+rax]
    lea edx, [r13+rax]
    mov ecx, 9
    call stamp
.nopol:
    movzx eax, byte [r15+BI_COV]
    test eax, eax
    jz .next
    ; services need power (parks do not)
    cmp eax, CV_PARK
    je .cov
    test byte [rbx+T_FLAGS], F_POWER
    jz .next
.cov:
    mov rdi, [cov_maps+rax*8]
    movzx r8d, byte [cov_strength+rax]
    movzx ecx, byte [bld_cov_boost+r14]
    add r8d, ecx
    CLAMP r8d, 0, 255
    movzx eax, byte [r15+BI_SIZE]
    shr eax, 1
    lea esi, [r12+rax]
    lea edx, [r13+rax]
    movzx ecx, byte [r15+BI_RADIUS]
    call stamp
    jmp .next
.zb:
    test byte [rbx+T_FLAGS], F_BUILD
    jnz .next
    ; traffic from residents / jobs onto nearby roads
    movzx eax, word [rbx+T_POP]
    test eax, eax
    jz .ind
    mov edi, r12d
    mov esi, r13d
    mov edx, eax
    call add_traffic
.ind:
    cmp byte [rbx+T_ZONE], ZONE_I
    jne .next
    movzx eax, byte [rbx+T_LEVEL]
    CLAMP eax, 0, 5
    movzx r8d, byte [ind_poll+rax]
    test r8d, r8d
    jz .next
    lea rdi, [map_pol]
    mov esi, r12d
    mov edx, r13d
    movzx ecx, byte [rbx+T_LEVEL]
    shr ecx, 1
    add ecx, 3
    call stamp
    jmp .next
.tree:
    lea rdi, [map_pol]
    mov esi, r12d
    mov edx, r13d
    mov ecx, 1
    mov r8d, 4
    call stamp_sub
.next:
    inc r12d
    cmp r12d, MAP_W
    jl .x
    inc r13d
    cmp r13d, MAP_W
    jl .y

    ; traffic pollution + crime + land value per tile
    xor r15d, r15d
    xor r12d, r12d                  ; total traffic
    mov dword [rbp-48], 0           ; road count
.lv:
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    ; roads: traffic noise pollution
    cmp byte [rbx+T_OBJ], OBJ_ROAD
    jne .nr
    movzx eax, byte [map_traffic+r15]
    mov [rbx+T_TRAFFIC], al
    add r12d, eax
    inc dword [rbp-48]
    shr eax, 2
    movzx ecx, byte [map_pol+r15]
    add eax, ecx
    CLAMP eax, 0, 255
    mov [map_pol+r15], al
.nr:
    ; parks also soak up pollution
    movzx eax, byte [map_park+r15]
    shr eax, 3
    movzx ecx, byte [map_pol+r15]
    sub ecx, eax
    CLAMP ecx, 0, 255
    mov [map_pol+r15], cl
    ; land value
    mov eax, 50
    movzx ecx, byte [map_scenic+r15]
    add eax, ecx
    movzx ecx, byte [map_park+r15]
    shr ecx, 1
    add eax, ecx
    movzx ecx, byte [map_edu+r15]
    shr ecx, 3
    add eax, ecx
    movzx ecx, byte [map_health+r15]
    shr ecx, 3
    add eax, ecx
    movzx ecx, byte [map_police+r15]
    shr ecx, 4
    add eax, ecx
    movzx ecx, byte [map_pol+r15]
    sub eax, ecx
    ; neighbourhood quality: nearby big buildings raise value
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .lvn
    movzx ecx, byte [rbx+T_LEVEL]
    shl ecx, 3
    add eax, ecx
.lvn:
    CLAMP eax, 0, 255
    mov [map_lv+r15], al
    ; crime: density and poverty, minus police
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
    movzx ecx, byte [map_police+r15]
    sub eax, ecx
    CLAMP eax, 0, 255
.cr:
    mov [map_crime+r15], al
    inc r15d
    cmp r15d, MAP_TILES
    jl .lv
    mov eax, r12d
    xor edx, edx
    mov ecx, [rbp-48]
    test ecx, ecx
    jz .nt
    div ecx
.nt:
    mov [avg_traffic], eax
    RETURN

; add_traffic(edi x, esi y, edx amount): spread over roads within 3
FUNC add_traffic, 16
    mov r12d, edi
    mov r13d, esi
    shr edx, 1
    add edx, 2
    mov [rbp-48], edx
    ; count roads
    xor ebx, ebx
    mov r14d, -3
.cy:
    mov r15d, -3
.cx:
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call tile_at
    test rax, rax
    jz .cn
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .cn
    inc ebx
.cn:
    inc r15d
    cmp r15d, 3
    jle .cx
    inc r14d
    cmp r14d, 3
    jle .cy
    test ebx, ebx
    jz .out
    mov eax, [rbp-48]
    xor edx, edx
    div ebx
    inc eax
    mov [rbp-48], eax
    mov r14d, -3
.ay:
    mov r15d, -3
.ax:
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call tile_at
    test rax, rax
    jz .an
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .an
    sub rax, tiles
    shr eax, TILE_SHIFT
    movzx ecx, byte [map_traffic+rax]
    add ecx, [rbp-48]
    CLAMP ecx, 0, 255
    mov [map_traffic+rax], cl
.an:
    inc r15d
    cmp r15d, 3
    jle .ax
    inc r14d
    cmp r14d, 3
    jle .ay
.out:
    RETURN

; ---------------------------------------------------------------------
;  city-wide statistics and demand
; ---------------------------------------------------------------------
FUNC stats_update, 32
    xor eax, eax
    mov [population], eax
    mov [jobs_c], eax
    mov [jobs_i], eax
    mov [cnt_r], eax
    mov [cnt_c], eax
    mov [cnt_i], eax
    mov [cnt_abandon], eax
    mov [cnt_fire], eax
    mov [cnt_unpowered], eax
    mov [cnt_nowater], eax
    mov [cnt_noroad], eax
    mov [road_tiles], eax
    lea rdi, [svc_count]
    mov ecx, BK_COUNT
    rep stosd
    xor r12d, r12d                  ; happiness * pop
    xor r13d, r13d                  ; pollution sum
    xor r14d, r14d                  ; crime sum
    xor r15d, r15d
.l:
    mov eax, r15d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_ROAD
    jne .nr
    inc dword [road_tiles]
    jmp .n
.nr:
    cmp eax, OBJ_SERVICE
    jne .ns
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .n
    movzx eax, byte [rbx+T_SUB]
    inc dword [svc_count+rax*4]
    jmp .n
.ns:
    cmp eax, OBJ_ZONEBLD
    jne .n
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
    movzx ecx, word [rbx+T_POP]
    movzx eax, byte [rbx+T_ZONE]
    cmp eax, ZONE_R
    jne .zc
    add [population], ecx
    inc dword [cnt_r]
    movzx eax, byte [rbx+T_HAPPY]
    imul eax, ecx
    add r12d, eax
    movzx eax, byte [map_pol+r15]
    imul eax, ecx
    add r13d, eax
    movzx eax, byte [map_crime+r15]
    imul eax, ecx
    add r14d, eax
    jmp .n
.zc:
    cmp eax, ZONE_C
    jne .zi
    add [jobs_c], ecx
    inc dword [cnt_c]
    jmp .n
.zi:
    add [jobs_i], ecx
    inc dword [cnt_i]
.n:
    inc r15d
    cmp r15d, MAP_TILES
    jl .l

    ; averages
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
    jmp .dem
.nopop:
    mov dword [happy_avg], 60
.dem:
    ; workers ~ 55% of residents
    mov eax, [population]
    imul eax, 55
    xor edx, edx
    mov ecx, 100
    div ecx
    mov [workers], eax

    ; ---- demand ----
    mov r12d, [tax_rate]
    sub r12d, 9
    imul r12d, 6                    ; tax penalty
    ; R: jobs available pull people in; happiness matters
    mov eax, [jobs_c]
    add eax, [jobs_i]
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
    sub eax, r12d
    ; commuters from the region when the city is young
    cmp dword [population], 400
    jg .rr
    add eax, 30
.rr:
    CLAMP eax, -100, 100
    mov ecx, [demand_r]
    lea ecx, [rcx*2+rcx]
    add eax, ecx
    sar eax, 2
    mov [demand_r], eax
    ; C: wants ~ 1 shop job per 3 residents
    mov eax, [population]
    xor edx, edx
    mov ecx, 3
    div ecx
    sub eax, [jobs_c]
    mov ecx, [population]
    shr ecx, 3
    add ecx, 20
    imul eax, 100
    cdq
    idiv ecx
    sub eax, r12d
    CLAMP eax, -100, 100
    mov ecx, [demand_c]
    lea ecx, [rcx*2+rcx]
    add eax, ecx
    sar eax, 2
    mov [demand_c], eax
    ; I: external trade + unemployed workers
    mov eax, [workers]
    sub eax, [jobs_c]
    sub eax, [jobs_i]
    mov ecx, [population]
    shr ecx, 3
    add ecx, 30
    imul eax, 100
    cdq
    idiv ecx
    add eax, [ext_demand]
    sub eax, r12d
    ; industry dislikes heavy pollution totals a little
    mov ecx, [avg_pollution]
    shr ecx, 3
    sub eax, ecx
    CLAMP eax, -100, 100
    mov ecx, [demand_i]
    lea ecx, [rcx*2+rcx]
    add eax, ecx
    sar eax, 2
    mov [demand_i], eax
    RETURN

; ---------------------------------------------------------------------
;  month end: budget, history, milestones, events
; ---------------------------------------------------------------------
FUNC month_end, 32
    ; income: residents pay tax, businesses pay half-rate on jobs
    mov eax, [population]
    imul eax, [tax_rate]
    xor edx, edx
    mov ecx, 12
    div ecx
    mov [inc_res], eax
    mov eax, [jobs_c]
    imul eax, [tax_rate]
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [inc_com], eax
    mov eax, [jobs_i]
    imul eax, [tax_rate]
    xor edx, edx
    mov ecx, 16
    div ecx
    mov [inc_ind], eax
    mov eax, [inc_res]
    add eax, [inc_com]
    add eax, [inc_ind]
    mov [income_last], eax
    ; expenses
    mov eax, [road_tiles]
    xor edx, edx
    mov ecx, 5
    div ecx
    mov [exp_roads], eax
    xor ebx, ebx
    xor r12d, r12d
.svc:
    mov edi, ebx
    call bld_rec
    mov ecx, [rax+BI_UPKEEP]
    imul ecx, [svc_count+rbx*4]
    add r12d, ecx
    inc ebx
    cmp ebx, BK_COUNT
    jl .svc
    mov [exp_services], r12d
    mov eax, [exp_roads]
    add eax, r12d
    mov [expense_last], eax
    ; apply
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
.solvent:
    ; history
    mov eax, [hist_count]
    and eax, 63
    mov ecx, [population]
    mov [hist_pop+rax*4], ecx
    mov rcx, [money]
    mov [hist_money+rax*4], ecx
    inc dword [hist_count]
    ; external demand slowly rises
    cmp dword [ext_demand], 60
    jge .ed
    inc dword [ext_demand]
.ed:
    ; landmark tourism
    cmp dword [svc_count+BK_LANDMARK*4], 0
    je .nl
    mov eax, [population]
    shr eax, 3
    add eax, 500
    movsxd rax, eax
    add [money], rax
.nl:
    call check_milestone
    call random_event
    ; calendar
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

FUNC check_milestone
    mov eax, [milestone]
    cmp eax, 9
    jge .out
    mov ecx, [milestone_pop+rax*4+4]
    cmp [population], ecx
    jl .out
    inc dword [milestone]
    mov ebx, [milestone]
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
;  random events: fires, meteors, booms
; ---------------------------------------------------------------------
FUNC random_event
    ; spontaneous fires: more likely with many buildings, less with
    ; fire coverage
    mov eax, [cnt_r]
    add eax, [cnt_c]
    add eax, [cnt_i]
    cmp eax, 20
    jl .nofire
    call rand
    and eax, 3
    jnz .nofire
    ; pick random building tiles until one qualifies (a few tries)
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
    movzx eax, byte [map_fire+r12]
    cmp eax, 120
    jg .nofire                       ; well protected
    or byte [r13+T_FLAGS], F_FIRE
    mov byte [r13+T_TIMER], 0
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
    ; industrial boom
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
    ; meteor (disasters on, big enough city)
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
    call meteor_strike
.out:
    RETURN

; meteor_strike(edi x, esi y) - crater of rubble + fires
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
    cmp eax, 2
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
    ; set neighbours on fire
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
;  date string into the text builder: "Mar 2026"
; ---------------------------------------------------------------------
tb_date:
    mov eax, [month]
    lea rdi, [month_names+rax*4]
    call tb_str
    mov edi, ' '
    call tb_char
    movsxd rdi, dword [year]
    jmp tb_num_plain

; number without separators (years)
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
