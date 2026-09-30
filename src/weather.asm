; =====================================================================
;  WEATHER (beta) - a hazard for every season, and new disasters
;
;  - Winter snow: roads get slow (cars crawl) except within reach of a
;    Snowplow Depot.  Snow falls on screen.
;  - Spring floods: the water rises onto the land beside it for a week
;    or so; homes and shops there are miserable, and some are wrecked
;    when it goes down.  Levees (dragged along the shore) hold it back.
;  - Summer heatwaves: every building uses a quarter more water, and
;    fires start easily.
;  - Autumn storms: rain, and power lines come down - rebuild them.
;  - Disasters (with disasters on): tornadoes that tear a path through
;    the city, epidemics where health care is short, riots when people
;    are unhappy.
; =====================================================================
WX_NONE     equ 0
WX_SNOW     equ 1
WX_FLOOD    equ 2
WX_HEAT     equ 3
WX_STORM    equ 4
PLOW_REACH  equ 20
LV_COST     equ 40              ; a levee tile
PK_SNOW     equ 7
PK_RAIN     equ 8
PK_FUNNEL   equ 9

section .bss
map_plow    resb MAP_TILES      ; roads a snowplow clears
map_flood   resb MAP_TILES      ; 1, 2: under water (how far from it)
wx_queue    resw MAP_TILES
flood_ready resd 1              ; map_flood is for the flood running
tor_on      resd 1              ; a tornado: steps left
tor_x       resd 1              ; (world units)
tor_y       resd 1
tor_vx      resd 1
tor_vy      resd 1
tor_tile    resd 1
tor_hits    resd 1
spr_levee   resd 16
spr_snowtile resd 1

section .data
s_wx_snow   db "Snow! Roads are slow - Snowplow Depots clear them.", 0
s_wx_snowe  db "The snow has stopped.", 0
s_wx_flood  db "Flood! The water is rising - levees hold it back.", 0
s_wx_floode db "The flood is going down.", 0
s_wx_fdmg   db " buildings were wrecked by the flood.", 0
s_wx_heat   db "Heatwave: more water used, and fires start easily.", 0
s_wx_heate  db "The heatwave is over.", 0
s_wx_storm  db "Storm! Power lines are down - rebuild them.", 0
s_wx_storme db "The storm has passed.", 0
s_wx_tor    db "Tornado!", 0
s_wx_tore   db "The tornado is gone: ", 0
s_wx_tore2  db " buildings wrecked.", 0
s_wx_epi    db " homes without health care fell ill: an epidemic.", 0
s_wx_riot   db "Riot! Unhappy people are setting fires.", 0
nm_plow     db "Snowplow Depot", 0
ds_plow     db "Clears snow from roads within 20 tiles.", 0
hb_plow     db "Snow falls in winter and slows", 10
            db "cars. Roads within 20 tiles of a", 10
            db "depot are cleared.", 0
s_levee     db "Levee", 0
ti_levee    db "Levee", 0
hx_levee    db "Drag along the shore. Spring", 10
            db "floods don't get past levees.", 0
wx_notes    dq 0, s_wx_snow, s_wx_flood, s_wx_heat, s_wx_storm
wx_ends     dq 0, s_wx_snowe, s_wx_floode, s_wx_heate, s_wx_storme
wx_cols     dd 0, UI_TEXT, UI_BAD, UI_WARN, UI_BAD

section .text

; the season: 0 spring .. 3 winter -> eax
season_now:
    mov eax, [month]
    add eax, 10
    xor edx, edx
    mov ecx, 12
    div ecx
    mov eax, edx
    xor edx, edx
    mov ecx, 3
    div ecx
    ret

; every day (beta)
FUNC weather_day
    cmp dword [beta_on], 0
    je .out
    ; snow piles up while it falls and melts after
    cmp dword [wx_kind], WX_SNOW
    jne .melt
    add dword [snow_level], 50
    cmp dword [snow_level], 255
    jle .sn
    mov dword [snow_level], 255
    jmp .sn
.melt:
    sub dword [snow_level], 60
    jns .sn
    mov dword [snow_level], 0
.sn:
    cmp dword [snow_level], 0
    je .ev
    call plow_update
.ev:
    mov eax, [wx_kind]
    test eax, eax
    jz .new
    ; one running
    cmp eax, WX_HEAT
    jne .e2
    mov edi, 6
    call rand_range
    test eax, eax
    jnz .e3
    call wx_fire
    jmp .e3
.e2:
    cmp eax, WX_FLOOD
    jne .e3
    cmp dword [flood_ready], 0
    jne .e25
    call flood_compute              ; (a loaded city in a flood)
.e25:
    call flood_misery
.e3:
    dec dword [wx_days]
    jg .out
    call weather_end
    jmp .out
.new:
    call season_now
    mov r12d, eax
    cmp r12d, 3
    jne .n1
    mov edi, 10
    mov r13d, WX_SNOW
    jmp .roll
.n1:
    cmp r12d, 0
    jne .n2
    cmp dword [disasters_on], 0
    je .out
    mov edi, 45
    mov r13d, WX_FLOOD
    jmp .roll
.n2:
    cmp r12d, 1
    jne .n3
    mov edi, 35
    mov r13d, WX_HEAT
    jmp .roll
.n3:
    mov edi, 25
    mov r13d, WX_STORM
.roll:
    call rand_range
    test eax, eax
    jnz .out
    cmp dword [population], 400
    jl .out
    mov edi, r13d
    call weather_start
.out:
    RETURN

; a spell of weather starts (edi kind)
FUNC weather_start
    mov r12d, edi
    mov [wx_kind], r12d
    mov edi, 6
    call rand_range
    add eax, 5
    cmp r12d, WX_STORM
    jne .d
    mov edi, 2
    call rand_range
    add eax, 2
.d:
    mov [wx_days], eax
    mov rdi, [wx_notes+r12*8]
    mov esi, [wx_cols+r12*4]
    mov edx, -1
    mov ecx, -1
    call notify
    cmp r12d, WX_FLOOD
    jne .s
    call flood_compute
    call emergency_pause
    jmp .out
.s:
    cmp r12d, WX_STORM
    jne .out
    call storm_damage
.out:
    RETURN

FUNC weather_end
    inc dword [ach_wx]
    mov r12d, [wx_kind]
    mov dword [wx_kind], 0
    mov dword [wx_days], 0
    and r12d, 7
    cmp r12d, 4
    ja .out
    mov rdi, [wx_ends+r12*8]
    test rdi, rdi
    jz .out
    mov esi, UI_TEXT
    mov edx, -1
    mov ecx, -1
    call notify
    cmp r12d, WX_FLOOD
    jne .out
    call flood_damage
.out:
    RETURN

; roads a snowplow depot clears
FUNC plow_update
    lea rdi, [map_plow]
    mov ecx, MAP_TILES/8
    xor eax, eax
    rep stosq
    cmp dword [svc_count+BK_PLOW*4], 0
    je .out
    xor ebx, ebx
.s:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_SERVICE
    jne .sn
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .sn
    cmp byte [tiles+rax+T_SUB], BK_PLOW
    jne .sn
    mov r12d, ebx
    and r12d, MAP_W-1
    mov r13d, ebx
    shr r13d, MAP_SHIFT
    mov r14d, -PLOW_REACH
.y:
    mov r15d, -PLOW_REACH
.x:
    mov eax, r14d
    cdq
    xor eax, edx
    sub eax, edx
    mov ecx, r15d
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx
    add eax, ecx
    cmp eax, PLOW_REACH
    jg .xn
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    cmp edi, MAP_W
    jae .xn
    cmp esi, MAP_W
    jae .xn
    shl esi, MAP_SHIFT
    add esi, edi
    mov byte [map_plow+rsi], 1
.xn:
    inc r15d
    cmp r15d, PLOW_REACH
    jle .x
    inc r14d
    cmp r14d, PLOW_REACH
    jle .y
.sn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .s
.out:
    RETURN

; a car on snow (eax its speed, r12d its tile) -> eax (beta)
snow_slow:
    cmp byte [map_plow+r12], 0
    jne .o
    push rdx
    mov ecx, 512
    sub ecx, [snow_level]
    imul eax, ecx
    shr eax, 9
    pop rdx
.o: ret

; a fire in a heatwave, where fire cover is thin
FUNC wx_fire
    mov ebx, 30
.t:
    call rand
    and eax, MAP_TILES-1
    mov r12d, eax
    shl eax, TILE_SHIFT
    lea r13, [tiles+rax]
    cmp byte [r13+T_OBJ], OBJ_ZONEBLD
    jne .n
    test byte [r13+T_FLAGS], F_BUILD|F_FIRE
    jnz .n
    test byte [r13+T_FLAGS], F_ANCHOR
    jz .n
    movzx eax, byte [map_fire+r12]
    cmp eax, 120
    jg .n
    or byte [r13+T_FLAGS], F_FIRE
    mov byte [r13+T_TIMER], 0
    lea rdi, [msg_fire]
    mov esi, UI_BAD
    mov edx, r12d
    and edx, MAP_W-1
    mov ecx, r12d
    shr ecx, MAP_SHIFT
    call notify
    RETURN
.n:
    dec ebx
    jnz .t
    RETURN

; a storm brings power lines down
FUNC storm_damage
    mov edi, 4
    call rand_range
    lea r14d, [rax+1]               ; lines to bring down
    mov ebx, 400
.t:
    test r14d, r14d
    jz .d
    dec ebx
    jz .d
    call rand
    and eax, MAP_TILES-1
    mov r12d, eax
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_POWER
    jne .t
    mov byte [tiles+rax+T_OBJ], OBJ_NONE
    mov byte [tiles+rax+T_SUB], 0
    dec r14d
    mov edi, r12d
    and edi, MAP_W-1
    mov esi, r12d
    shr esi, MAP_SHIFT
    mov edx, 6
    mov ecx, PK_DUST
    mov r8d, 4
    call fx_burst
    jmp .t
.d:
    call wires_cleanup
    mov dword [net_dirty], 1
    RETURN

; ---------------------------------------------------------------------
;  floods
; ---------------------------------------------------------------------
; is tile index edi a levee? -> eax 1
is_levee_idx:
    mov eax, edi
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_LEVEE
    sete al
    movzx eax, al
    ret

; the land the water reaches: two tiles in from it, not past levees
FUNC flood_compute
    lea rdi, [map_flood]
    mov ecx, MAP_TILES/8
    xor eax, eax
    rep stosq
    xor r12d, r12d                  ; queue head
    xor r13d, r13d                  ; tail
    xor ebx, ebx
.w:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_TERRAIN], TER_WATER
    jne .wn
    mov byte [map_flood+rbx], 255
    mov [wx_queue+r13*2], bx
    inc r13d
.wn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .w
.q:
    cmp r12d, r13d
    jge .done
    movzx ebx, word [wx_queue+r12*2]
    inc r12d
    movzx r14d, byte [map_flood+rbx]
    cmp r14d, 255
    jne .dp
    xor r14d, r14d
.dp:
    cmp r14d, 2
    jge .q
    inc r14d                        ; the next ones' depth
    xor ecx, ecx
.d:
    mov edi, ebx
    and edi, MAP_W-1
    mov esi, ebx
    shr esi, MAP_SHIFT
    add edi, [dir_dx+rcx*4]
    add esi, [dir_dy+rcx*4]
    cmp edi, MAP_W
    jae .dn
    cmp esi, MAP_W
    jae .dn
    shl esi, MAP_SHIFT
    add esi, edi
    cmp byte [map_flood+rsi], 0
    jne .dn
    mov edi, esi
    push rcx
    push rsi
    call is_levee_idx
    pop rsi
    pop rcx
    test eax, eax
    jnz .dn
    mov [map_flood+rsi], r14b
    mov [wx_queue+r13*2], si
    inc r13d
.dn:
    inc ecx
    cmp ecx, 4
    jl .d
    jmp .q
.done:
    ; the water itself isn't "flooded"
    xor ebx, ebx
.c:
    cmp byte [map_flood+rbx], 255
    jne .cn
    mov byte [map_flood+rbx], 0
.cn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .c
    mov dword [flood_ready], 1
    RETURN

; a day under water: the people there are miserable
FUNC flood_misery
    xor ebx, ebx
.l:
    cmp byte [map_flood+rbx], 0
    je .n
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ZONEBLD
    jne .n
    mov cl, [tiles+rax+T_HAPPY]
    sub cl, 4
    jnc .h
    xor ecx, ecx
.h:
    cmp cl, 1
    jae .h2
    mov cl, 1
.h2:
    mov [tiles+rax+T_HAPPY], cl
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    RETURN

; the water goes down: some of what stood in it is wrecked
FUNC flood_damage
    xor r12d, r12d                  ; wrecked
    xor ebx, ebx
.l:
    cmp byte [map_flood+rbx], 0
    je .n
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ZONEBLD
    jne .n
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .n
    mov edi, 5
    call rand_range
    test eax, eax
    jnz .n
    mov edi, ebx
    and edi, MAP_W-1
    mov esi, ebx
    shr esi, MAP_SHIFT
    call destroy_to_rubble
    inc r12d
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    lea rdi, [map_flood]
    mov ecx, MAP_TILES/8
    xor eax, eax
    rep stosq
    mov dword [flood_ready], 0
    test r12d, r12d
    jz .out
    call tb_reset
    movsxd rdi, r12d
    call tb_num
    lea rdi, [s_wx_fdmg]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
    mov dword [net_dirty], 1
.out:
    RETURN

; flood water over a tile's ground (render; rbx tile, r12d x, r13d y,
; r14d depth, [draw_sx], [draw_sy], r8 remap) - beta
FUNC flood_overlay
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    cmp dword [wx_kind], WX_FLOOD
    jne .snow
    cmp byte [map_flood+rax], 0
    je .out
    mov dword [blit_dither], 1
    mov edi, [spr_water]
    jmp .b
.snow:
    cmp byte [rbx+T_OBJ], OBJ_ROAD
    jne .out
    cmp byte [map_plow+rax], 0
    jne .out
    mov dword [blit_dither], 1
    mov edi, [spr_snowtile]
.b:
    mov esi, [draw_sx]
    mov edx, [draw_sy]
    mov ecx, r14d
    call blit_sprite
    mov dword [blit_dither], 0
.out:
    RETURN

; ---------------------------------------------------------------------
;  levees
; ---------------------------------------------------------------------
; is (edi, esi) a levee? -> eax 1
is_levee:
    call tile_at
    test rax, rax
    jz .no
    cmp byte [rax+T_OBJ], OBJ_LEVEE
    jne .no
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

FUNC levee_mask
    mov r12d, edi
    mov r13d, esi
    xor ebx, ebx
    xor r14d, r14d
.d:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+r14*4]
    add esi, [dir_dy+r14*4]
    call is_levee
    test eax, eax
    jz .n
    bts ebx, r14d
.n:
    inc r14d
    cmp r14d, 4
    jl .d
    mov eax, ebx
    RETURN

levee_ground:
    movzx eax, byte [rdi+T_SUB]
    and eax, 15
    mov eax, [spr_levee+rax*4]
    ret

; a tile for the levee tool (r12 tile, ecx object, edx terrain) -> eax
levee_tile_cost:
    cmp edx, TER_WATER
    je .no
    cmp ecx, OBJ_NONE
    je .y
    cmp ecx, OBJ_TREE
    je .y
    cmp ecx, OBJ_RUBBLE
    je .y
.no:
    mov eax, -1
    ret
.y: mov eax, LV_COST
    ret

levee_lay_tile:
    mov byte [r12+T_OBJ], OBJ_LEVEE
    mov byte [r12+T_ZONE], 0
    mov byte [r12+T_FLAGS], 0
    mov byte [r12+T_LEVEL], 0
    mov word [r12+T_POP], 0
    mov byte [r12+T_PROBLEM], 0
    ret

; ---------------------------------------------------------------------
;  disasters (with the month's random events; beta)
; ---------------------------------------------------------------------
FUNC disasters_month
    cmp dword [beta_on], 0
    je .out
    cmp dword [disasters_on], 0
    je .out
    ; a tornado
    cmp dword [population], 5000
    jl .epi
    mov edi, 40
    call rand_range
    test eax, eax
    jnz .epi
    call tornado_start
    jmp .out
.epi:
    ; an epidemic: health care overloaded or water dirty
    cmp dword [population], 3000
    jl .riot
    cmp dword [cov_scale+CV_HEALTH*4], 200
    jl .ep1
    cmp dword [iss_count+PR_DIRTY*4], 50
    jl .riot
.ep1:
    mov edi, 12
    call rand_range
    test eax, eax
    jnz .riot
    call epidemic
    jmp .out
.riot:
    cmp dword [population], 3000
    jl .out
    cmp dword [happy_avg], 35
    jge .out
    mov edi, 6
    call rand_range
    test eax, eax
    jnz .out
    call riot
.out:
    RETURN

FUNC epidemic
    xor r12d, r12d
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, TILE_SHIFT
    lea r13, [tiles+rax]
    cmp byte [r13+T_OBJ], OBJ_ZONEBLD
    jne .n
    test byte [r13+T_FLAGS], F_ANCHOR
    jz .n
    movzx eax, byte [r13+T_ZONE]
    cmp byte [zone_class+rax], ZC_RES
    jne .n
    cmp byte [map_health+rbx], 40
    jae .n
    mov byte [r13+T_HAPPY], 10
    inc r12d
    ; some move away
    mov edi, 4
    call rand_range
    test eax, eax
    jnz .n
    cmp byte [r13+T_LEVEL], 1
    jbe .n
    dec byte [r13+T_LEVEL]
    mov rdi, r13
    call set_tile_pop
.n:
    inc ebx
    cmp ebx, MAP_TILES
    jl .l
    cmp r12d, 20
    jl .out
    call tb_reset
    movsxd rdi, r12d
    call tb_num
    lea rdi, [s_wx_epi]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

FUNC riot
    mov r14d, 5                     ; fires
    mov ebx, 600
    mov r15d, -1
.t:
    dec ebx
    jz .d
    call rand
    and eax, MAP_TILES-1
    mov r12d, eax
    shl eax, TILE_SHIFT
    lea r13, [tiles+rax]
    cmp byte [r13+T_OBJ], OBJ_ZONEBLD
    jne .t
    test byte [r13+T_FLAGS], F_ANCHOR
    jz .t
    test byte [r13+T_FLAGS], F_BUILD|F_FIRE
    jnz .t
    cmp byte [r13+T_HAPPY], 30
    jae .t
    or byte [r13+T_FLAGS], F_FIRE
    mov byte [r13+T_TIMER], 0
    cmp r15d, -1
    jne .f
    mov r15d, r12d
.f:
    dec r14d
    jnz .t
.d:
    cmp r15d, -1
    je .out
    lea rdi, [s_wx_riot]
    mov esi, UI_BAD
    mov edx, r15d
    and edx, MAP_W-1
    mov ecx, r15d
    shr ecx, MAP_SHIFT
    call notify
    mov edi, SFX_ALARM
    call sfx_play
    call emergency_pause
.out:
    RETURN

; a tornado sets off from an edge, across the land
FUNC tornado_start
    mov edi, 80
    call rand_range
    add eax, 24
    shl eax, 8
    mov r12d, eax                   ; along the edge
    call rand
    and eax, 1
    jz .fromw
    ; from the north edge, going south (and a little sideways)
    mov [tor_x], r12d
    mov dword [tor_y], 128
    mov dword [tor_vy], 9
    mov edi, 5
    call rand_range
    sub eax, 2
    mov [tor_vx], eax
    jmp .go
.fromw:
    mov dword [tor_x], 128
    mov [tor_y], r12d
    mov dword [tor_vx], 9
    mov edi, 5
    call rand_range
    sub eax, 2
    mov [tor_vy], eax
.go:
    mov dword [tor_on], 1800
    mov dword [tor_tile], -1
    mov dword [tor_hits], 0
    mov eax, [tor_x]
    shr eax, 8
    mov edx, eax
    mov eax, [tor_y]
    shr eax, 8
    mov ecx, eax
    lea rdi, [s_wx_tor]
    mov esi, UI_BAD
    ; (it's a long way off: the notice points at where it starts)
    call notify
    mov edi, SFX_ALARM
    call sfx_play
    call emergency_pause
    RETURN

; the tornado, a traffic step (beta)
FUNC tornado_step
    cmp dword [tor_on], 0
    je .out
    dec dword [tor_on]
    jz .end
    mov eax, [tor_vx]
    add [tor_x], eax
    mov eax, [tor_vy]
    add [tor_y], eax
    ; wobble
    mov edi, 3
    call rand_range
    dec eax
    add [tor_x], eax
    mov eax, [tor_x]
    cmp eax, 0
    jl .end
    cmp eax, MAP_W*256
    jge .end
    mov eax, [tor_y]
    cmp eax, 0
    jl .end
    cmp eax, MAP_W*256
    jge .end
    ; the funnel: wider as it goes up
    mov ebx, 14
.p:
    mov edi, 110
    call rand_range
    mov r12d, eax                   ; height (voxels)
    mov edi, r12d
    shr edi, 3
    add edi, 1
    mov r13d, edi
    lea edi, [r13*2+1]
    call rand_range
    sub eax, r13d
    shl eax, 4
    add eax, [tor_x]
    mov r14d, eax
    lea edi, [r13*2+1]
    call rand_range
    sub eax, r13d
    shl eax, 4
    add eax, [tor_y]
    mov edi, r14d
    mov esi, eax
    mov edx, r12d
    shl edx, 4
    mov ecx, PK_FUNNEL
    call part_emit
    dec ebx
    jnz .p
    ; a new tile: what's there is torn apart
    mov eax, [tor_y]
    shr eax, 8
    shl eax, MAP_SHIFT
    mov ecx, [tor_x]
    shr ecx, 8
    add eax, ecx
    cmp eax, [tor_tile]
    je .out
    mov [tor_tile], eax
    mov r12d, ecx
    mov r13d, [tor_y]
    shr r13d, 8
    mov r14d, -1
.dy:
    mov r15d, -1
.dx:
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call tile_at
    test rax, rax
    jz .dn
    movzx ecx, byte [rax+T_OBJ]
    cmp ecx, OBJ_TREE
    je .clear
    cmp ecx, OBJ_POWER
    je .clear
    cmp ecx, OBJ_ZONEBLD
    je .wreck
    cmp ecx, OBJ_SERVICE
    jne .dn
    mov edi, 3
    push rax
    push rax
    call rand_range
    mov ecx, eax
    pop rax
    pop rax
    test ecx, ecx
    jnz .dn
.wreck:
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    call destroy_to_rubble
    inc dword [tor_hits]
    jmp .dn
.clear:
    mov byte [rax+T_OBJ], OBJ_NONE
    mov byte [rax+T_SUB], 0
    mov dword [net_dirty], 1
.dn:
    inc r15d
    cmp r15d, 1
    jle .dx
    inc r14d
    cmp r14d, 1
    jle .dy
    jmp .out
.end:
    mov dword [tor_on], 0
    call wires_cleanup
    mov dword [net_dirty], 1
    call tb_reset
    lea rdi, [s_wx_tore]
    call tb_str
    movsxd rdi, dword [tor_hits]
    call tb_num
    lea rdi, [s_wx_tore2]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_TEXT
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; ---------------------------------------------------------------------
;  snow and rain on screen (beta; with the particles)
; ---------------------------------------------------------------------
FUNC weather_fx
    cmp dword [beta_on], 0
    je .out
    mov r12d, PK_SNOW
    mov ebx, 12
    cmp dword [wx_kind], WX_SNOW
    je .go
    mov r12d, PK_RAIN
    mov ebx, 14
    cmp dword [wx_kind], WX_STORM
    jne .out
.go:
    ; a point on the screen, as ground 100 voxels below where it shows
    mov edi, [fb_w]
    call rand_range
    add eax, [cam_x]
    sub eax, ORIGIN_X
    mov r13d, eax                   ; x - y
    mov edi, [fb_h]
    call rand_range
    add eax, 100
    add eax, [cam_y]
    add eax, eax
    mov r14d, eax                   ; x + y
    lea edi, [r13+r14]
    sar edi, 1
    mov esi, r14d
    sub esi, r13d
    sar esi, 1
    shl edi, 4
    shl esi, 4
    mov edx, 100*16
    mov ecx, r12d
    call part_emit
    dec ebx
    jnz .go
.out:
    RETURN

; ---------------------------------------------------------------------
;  sprites: levees, the snowplow depot
; ---------------------------------------------------------------------
FUNC gen_levee, 16
    mov r12d, edi
    lea eax, [r12+8800]
    BEGIN 16, 8, eax
    MAT M_GRASS
    BOX 0,0,0,16,16,1
    MAT M_DIRT
    BOX 4,4,1,12,12,5
    MAT M_GRASS
    BOX 5,5,5,11,11,6
    xor ebx, ebx
.arm:
    bt r12d, ebx
    jnc .an
    imul eax, ebx, 20
    lea r13, [rail_arm+rax]
    MAT M_DIRT
    mov edi, [r13]
    mov esi, [r13+4]
    mov edx, 1
    mov ecx, [r13+8]
    mov r8d, [r13+12]
    mov r9d, 5
    call vbox
    MAT M_GRASS
    mov edi, [r13]
    mov esi, [r13+4]
    mov edx, 5
    mov ecx, [r13+8]
    mov r8d, [r13+12]
    mov r9d, 6
    call vbox
.an:
    inc ebx
    cmp ebx, 4
    jl .arm
    call finish_model
    RETURN

FUNC bld_plow
    BEGIN 32, 30, 8900
    MAT M_CONCRETE
    BOX 0,0,0,32,32,1
    ; the garage
    MAT M_BRICK
    BOX 3,14,1,29,29,12
    MAT M_DARK
    BOX 6,13,1,12,14,9
    BOX 18,13,1,24,14,9
    MAT M_ROOF_GREY
    RFX 2,13,12,30,30,5
    ; a salt pile
    MAT M_WHITE
    CONE 8,6,1,6,8
    ; a plow truck
    MAT M_ORANGE
    BOX 18,3,1,28,8,5
    MAT M_YELLOW
    BOX 17,2,1,18,9,3
    MAT M_GLASS
    BOX 25,3,4,27,8,5
    call finish_model
    RETURN

FUNC weather_sprites_init
    BEGIN 16, 2, 8950
    MAT M_WHITE
    BOX 0,0,0,16,16,1
    call finish_model
    mov [spr_snowtile], eax
    xor ebx, ebx
.l:
    mov edi, ebx
    call gen_levee
    mov [spr_levee+rbx*4], eax
    inc ebx
    cmp ebx, 16
    jl .l
    RETURN

weather_reset:
    mov dword [tor_on], 0
    mov dword [wx_kind], 0
    mov dword [wx_days], 0
    mov dword [snow_level], 0
    mov dword [flood_ready], 0
    ret
