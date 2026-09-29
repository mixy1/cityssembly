; =====================================================================
;  TRAFFIC (beta) - traffic that grows with the city, and costs it
;
;  - as many cars as the city makes trips: no cap at 1,080
;  - the day has a rhythm: commuters in the morning, home again in the
;    evening, shoppers and trucks in between, a quiet night
;  - trips go to nearer jobs, shops and homes (the nearest of three)
;  - avenue junctions have traffic lights: each way gets its turn
;  - every home remembers how long its commute takes: long ones make
;    people unhappy, and homes don't grow past level 3 on them
; =====================================================================
PU_HOME     equ 11              ; a commuter going home in the evening
VEH_CAP_OLD equ 1080            ; the classic traffic's limit
SIG_HALF    equ 64              ; traffic steps each way gets green
COMMUTE_OK  equ 600             ; steps of commute nobody minds
COMMUTE_L4  equ 1200            ; longer than this: homes stop at level 3
TRIP_RES    equ 14              ; a car on the road per this many residents
TRIP_JOBS   equ 40              ; and per this many jobs (x the hour)
TRIPS_TICK  equ 10              ; new trips a traffic step at most

section .bss
traffic_step    resd 1
sig_reds        resd 1          ; cars stopped at red lights (stats)
veh_hint        resd 1          ; where to look for a free vehicle slot
map_commute     resb MAP_TILES  ; each home's commute, in 8-step units

section .data
; cars on the road through the day (16 = the usual), by 1/16 of the day
; (phase 0 = midnight, 62 sunrise, 194 sunset); the last repeats the first
rush_tab    db 6, 5, 5, 8, 18, 26, 18, 15, 16, 15, 18, 26, 20, 13, 9, 7, 6
; what trips are made: cumulative % for commute, home, shop, goods,
; export, import (the rest are visitors)
trips_morning db 58, 63, 73, 85, 91, 96
trips_evening db 5, 60, 75, 85, 91, 96
trips_day     db 22, 38, 63, 79, 87, 94

section .text

; the day's phase 0..255 (a locked daylight is noon)
day_phase:
    mov eax, [tod]
    shr eax, 8
    cmp dword [tod_lock], 0
    je .o
    mov eax, 128
.o: ret

; cars on the road right now, x16 -> eax
rush_now:
    call day_phase
    mov ecx, eax
    shr ecx, 4
    and eax, 15
    movzx edx, byte [rush_tab+rcx]
    movzx ecx, byte [rush_tab+rcx+1]
    imul ecx, eax
    neg eax
    add eax, 16
    imul eax, edx
    add eax, ecx
    shr eax, 4
    ret

; the traffic step (beta): trips for as many cars as the city wants now
FUNC traffic_tick_beta
    inc dword [traffic_step]
    ; a car for every 14 residents and every 40 jobs, at the usual hour
    mov eax, [population]
    xor edx, edx
    mov ecx, TRIP_RES
    div ecx
    mov r8d, eax
    mov eax, [jobs+ZC_COM*4]
    add eax, [jobs+ZC_IND*4]
    add eax, [jobs+ZC_OFF*4]
    xor edx, edx
    mov ecx, TRIP_JOBS
    div ecx
    add eax, r8d
    add eax, 8
    mov ebx, eax
    call rush_now
    imul eax, ebx
    shr eax, 4
    CLAMP eax, 0, MAX_VEH-120
    mov ebx, eax
    mov r12d, TRIPS_TICK
.sp:
    cmp [veh_count], ebx
    jge .mv
    call generate_trip_beta
    dec r12d
    jnz .sp
.mv:
    PERF_MARK 27
    call vehicles_update
    PERF_MARK 28
    RETURN

; Manhattan distance between tiles edi and esi -> eax
tile_dist:
    mov eax, edi
    and eax, MAP_W-1
    mov ecx, esi
    and ecx, MAP_W-1
    sub eax, ecx
    cdq
    xor eax, edx
    sub eax, edx
    mov ecx, edi
    shr ecx, MAP_SHIFT
    mov edx, esi
    shr edx, MAP_SHIFT
    sub ecx, edx
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx
    add eax, ecx
    ret

; the nearest of three random buildings from a list to tile edx:
; (rdi list, esi count, edx tile) -> eax tile or -1
FUNC pick_near, 16
    mov r12, rdi
    mov r13d, esi
    mov r14d, edx
    mov r15d, -1                    ; best
    mov dword [rbp-48], 0x7FFFFFFF
    mov ebx, 3
.t:
    mov rdi, r12
    mov esi, r13d
    call pick_from
    cmp eax, -1
    je .out
    mov [rbp-52], eax
    mov edi, eax
    mov esi, r14d
    call tile_dist
    cmp eax, [rbp-48]
    jge .n
    mov [rbp-48], eax
    mov eax, [rbp-52]
    mov r15d, eax
.n:
    dec ebx
    jnz .t
.out:
    mov eax, r15d
    RETURN

; the nearest of three jobs (shops, industry, offices) to tile edi
FUNC pick_job_near, 16
    mov r14d, edi
    mov r15d, -1
    mov dword [rbp-48], 0x7FFFFFFF
    mov ebx, 3
.t:
    call pick_job
    cmp eax, -1
    je .out
    mov r12d, eax
    mov edi, eax
    mov esi, r14d
    call tile_dist
    cmp eax, [rbp-48]
    jge .n
    mov [rbp-48], eax
    mov r15d, r12d
.n:
    dec ebx
    jnz .t
.out:
    mov eax, r15d
    RETURN

; one trip, chosen by the time of day
FUNC generate_trip_beta
    lea r15, [trips_day]
    call day_phase
    cmp eax, 64
    jl .mix
    cmp eax, 112
    jl .morning
    cmp eax, 168
    jl .mix
    cmp eax, 216
    jge .mix
    lea r15, [trips_evening]
    jmp .mix
.morning:
    lea r15, [trips_morning]
.mix:
    call rand
    xor edx, edx
    mov ecx, 100
    div ecx
    mov ebx, edx
    movzx eax, byte [r15]
    cmp ebx, eax
    jl .commute
    movzx eax, byte [r15+1]
    cmp ebx, eax
    jl .home
    movzx eax, byte [r15+2]
    cmp ebx, eax
    jl .shop
    ; goods, exports, imports and visitors as before
    call generate_trip
    RETURN
.commute:
    lea rdi, [list_res]
    mov esi, [n_res]
    call pick_from
    cmp eax, -1
    je .out
    mov r12d, eax
    call transit_instead
    test eax, eax
    jnz .out
    mov edi, r12d
    call pick_job_near
    mov esi, eax
    mov edi, r12d
    mov edx, VT_CAR
    mov ecx, PU_COMMUTE
    call make_trip
    jmp .out
.home:
    ; from work, back to a home nearby
    call pick_job
    cmp eax, -1
    je .out
    mov r13d, eax
    lea rdi, [list_res]
    mov esi, [n_res]
    mov edx, r13d
    call pick_near
    cmp eax, -1
    je .out
    mov r12d, eax
    call transit_instead
    test eax, eax
    jnz .out
    mov edi, r13d
    mov esi, r12d
    mov edx, VT_CAR
    mov ecx, PU_HOME
    call make_trip
    jmp .out
.shop:
    lea rdi, [list_res]
    mov esi, [n_res]
    call pick_from
    cmp eax, -1
    je .out
    mov r12d, eax
    call transit_instead
    test eax, eax
    jnz .out
    lea rdi, [list_com]
    mov esi, [n_com]
    mov edx, r12d
    call pick_near
    cmp eax, -1
    je .out
    mov esi, eax
    mov edi, r12d
    mov edx, VT_CAR
    mov ecx, PU_SHOP
    call make_trip
.out:
    RETURN

; a commuter arrived (r15 vehicle): its home learns how long it took
; (beta).  Morning trips start at home, evening ones end there.
note_commute:
    cmp dword [beta_on], 0
    je .o
    mov eax, [r15+V_HOME]
    cmp byte [r15+V_PURP], PU_HOME
    jne .h
    mov eax, [r15+V_DST]
.h:
    cmp eax, MAP_TILES
    jae .o
    mov ecx, [r15+V_AGE]
    shr ecx, 3
    CLAMP ecx, 1, 255
    movzx edx, byte [map_commute+rax]
    test edx, edx
    jz .set
    lea edx, [rdx*2+rdx]
    add ecx, edx
    shr ecx, 2
.set:
    mov [map_commute+rax], cl
.o: ret

; a free vehicle slot, looking on from the last one found (beta)
; -> ebx slot (MAX_VEH if none), rax its record
veh_free_slot:
    mov ecx, MAX_VEH
    mov ebx, [veh_hint]
.l:
    cmp ebx, MAX_VEH
    jb .c
    xor ebx, ebx
.c:
    mov eax, ebx
    shl eax, 7
    cmp byte [vehicles+rax+V_TYPE], 255
    je .y
    inc ebx
    dec ecx
    jnz .l
    mov ebx, MAX_VEH
    ret
.y:
    lea edx, [rbx+1]
    mov [veh_hint], edx
    ret

; a traffic light at the tile a vehicle is about to enter (beta):
; (r8 tile, esi entry heading) -> eax 1 if it's red for that way
signal_red:
    xor eax, eax
    cmp dword [beta_on], 0
    je .o
    ; lights on the avenues (streets give way; highways are interchanges)
    cmp byte [r8+T_ROADTYPE], RT_AVENUE
    jne .o
    ; a junction: three or four ways
    movzx ecx, byte [r8+T_SUB]
    and ecx, 15
    popcnt ecx, ecx
    cmp ecx, 3
    jb .o
    ; its phase: every junction on its own clock
    mov rcx, r8
    sub rcx, tiles
    shr ecx, TILE_SHIFT
    imul ecx, ecx, 53
    add ecx, [traffic_step]
    shr ecx, 6                      ; SIG_HALF steps each way
    and ecx, 1
    mov edx, esi
    and edx, 1                      ; 0 north-south, 1 east-west
    cmp ecx, edx
    setne al
    add [sig_reds], eax
.o: ret

; each home's commute (beta): the extra unhappiness it brings
; (edi tile index) -> eax 0..25
commute_penalty:
    xor eax, eax
    cmp dword [beta_on], 0
    je .o
    movzx eax, byte [map_commute+rdi]
    shl eax, 3
    sub eax, COMMUTE_OK
    jle .z
    xor edx, edx
    mov ecx, 30
    div ecx
    CLAMP eax, 0, 25
    ret
.z: xor eax, eax
.o: ret

; is this home's commute too long for level 4? (edi tile) -> eax 1
commute_too_long:
    xor eax, eax
    cmp dword [beta_on], 0
    je .o
    movzx ecx, byte [map_commute+rdi]
    shl ecx, 3
    cmp ecx, COMMUTE_L4
    seta al
.o: ret
