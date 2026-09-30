; =====================================================================
;  AIR (beta) - airports, runways and planes
;
;  A runway is dragged like a road, straight, on land (OBJ_RUNWAY).  An
;  Airport (3x3) touching a runway of 10 tiles or more flies small
;  planes; 16 tiles or more, jets.  Flights bring tourists (money and
;  shoppers), business (offices and shops want to be here) and people
;  to and from the terminal - traffic.  Runways are loud, most of all
;  under the flight path past their ends.
;
;  Planes are drawn: they come in over the end of the runway, land,
;  roll to a stop and taxi off; others line up, take off and climb out.
; =====================================================================
AP_MAX      equ 8               ; airports
AP_UNLOCK   equ 16000
RW_MIN      equ 10              ; a runway for small planes
RW_INTL     equ 16              ; and for jets
RW_COST     equ 150             ; a runway tile
PL_MAX      equ 8               ; planes in the air (or on the runway)
PL_APPROACH equ 24              ; tiles out on the approach
AP_PAX_SMALL equ 3000           ; passengers a month an airport can fly
AP_PAX_JET  equ 9000

section .bss
ap_n        resd 1
ap_tile     resw AP_MAX         ; the terminal's anchor
ap_live     resb AP_MAX         ; 0 not flying, 1 small planes, 2 jets
ap_rwlen      resb AP_MAX         ; its longest runway touching it
ap_x0       resb AP_MAX         ; that runway: its low end
ap_y0       resb AP_MAX
ap_dir      resb AP_MAX         ; 1 along +x, 2 along +y
ap_clock    resd AP_MAX         ; steps to the next plane
ap_next     resb AP_MAX         ; the next plane lands (0) or leaves (1)
rm_x0       resd 1              ; runway_measure results
rm_y0       resd 1
rm_dir      resd 1
air_pax     resd 1              ; passengers last month
air_com     resd 1              ; shops wanted for the tourists
air_off     resd 1              ; offices wanted for the flights
ap_trip_pm  resd 1              ; trips to or from the airport, per 1000
air_trips   resd 1              ; (this month, by car)
; planes
pl_kind     resb PL_MAX         ; 0 none, 1 landing, 2 taking off
pl_big      resb PL_MAX         ; 1 a jet
pl_ap       resb PL_MAX
pl_st       resb PL_MAX         ; the stage (see planes_update)
pl_h        resb PL_MAX         ; heading 0..3
pl_ox       resd PL_MAX         ; where s = 0 (world units, 256 a tile)
pl_oy       resd PL_MAX
pl_s        resd PL_MAX         ; along the runway (4096 a tile)
pl_v        resd PL_MAX         ; speed (4096 a tile, a step)
pl_alt      resd PL_MAX         ; height (world units)
pl_t        resd PL_MAX         ; timer
pl_stop     resd PL_MAX         ; where it stops / lifts off (s)
pl_dec      resd PL_MAX         ; braking
spr_runway  resd 4              ; middle along x / y, end along x / y
spr_plane   resd 8              ; small plane, jet * 4 + dir
spr_pshadow resd 8

section .data
s_runway    db "Runway", 0
ti_runway   db "Runway", 0
nm_airport  db "Airport", 0
ds_airport  db "Flights bring tourists and business. Loud.", 0
hx_runway   db "Drag a straight runway next to", 10
            db "an Airport: 10 tiles for small", 10
            db "planes, 16 for jets.", 10
            db 7, "Planes are loud: keep homes away", 10
            db 7, "from the ends of the runway.", 0
hb_airport  db "Lay a runway next to it: 10 tiles", 10
            db "for small planes, 16 for jets.", 10
            db "Brings tourists and business -", 10
            db "and traffic to the terminal.", 0
s_ap_jet    db "Jets: an international airport", 0
s_ap_small  db "Small planes (16 tiles of runway", 0
s_ap_small2 db "  for jets)", 0
s_ap_none   db "No runway: lay one next to it", 0
s_ap_short  db "Runway too short: ", 0
s_ap_short2 db " of 10 tiles", 0
s_ap_power  db "No power: no flights", 0
s_ap_pax    db "Passengers / month: ", 0
s_st_air    db "Air passengers / month", 0
; the flight path past the end of a runway: tiles out, loudness /8
rw_path     db 3, 7, 6, 6, 9, 4, 12, 3, 0

section .text

; ---------------------------------------------------------------------
;  runway tiles
; ---------------------------------------------------------------------
; is (edi, esi) runway? -> eax 1
is_runway:
    call tile_at
    test rax, rax
    jz .no
    cmp byte [rax+T_OBJ], OBJ_RUNWAY
    jne .no
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; the runway's shape at (edi, esi) -> eax mask
FUNC runway_mask
    mov r12d, edi
    mov r13d, esi
    xor ebx, ebx
    xor r14d, r14d
.d:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+r14*4]
    add esi, [dir_dy+r14*4]
    call is_runway
    test eax, eax
    jz .n
    bts ebx, r14d
.n:
    inc r14d
    cmp r14d, 4
    jl .d
    mov eax, ebx
    RETURN

; the ground sprite of a runway tile (rdi tile) -> eax
runway_ground:
    movzx eax, byte [rdi+T_SUB]
    xor ecx, ecx                    ; along x
    test eax, 0xA
    jnz .x
    test eax, 5
    jz .x
    mov ecx, 1                      ; along y
    and eax, 5
    jmp .e
.x:
    and eax, 0xA
.e:
    ; one neighbour along it: an end
    popcnt eax, eax
    cmp eax, 1
    jne .m
    add ecx, 2
.m:
    mov eax, [spr_runway+rcx*4]
    ret

; a tile for the runway tool (r12 tile, ecx object, edx terrain)
; -> eax cost or -1
runway_tile_cost:
    cmp edx, TER_WATER
    je .no
    cmp ecx, OBJ_NONE
    je .new
    cmp ecx, OBJ_TREE
    je .new
    cmp ecx, OBJ_RUBBLE
    je .new
    cmp ecx, OBJ_ZONEBLD
    jne .blk
    ; homes and shops make way with Ctrl held
    test dword [ev_keys], 2
    jz .blk
    movzx eax, byte [r12+T_LEVEL]
    imul eax, 12
    add eax, 5+RW_COST
    ret
.blk:
    cmp ecx, OBJ_RUNWAY
    je .no
    inc dword [tl_blocked]
.no:
    mov eax, -1
    ret
.new:
    mov eax, RW_COST
    ret

; lay runway on a tile (r12 tile; r13d, r14d its x, y)
runway_lay_tile:
    cmp byte [r12+T_OBJ], OBJ_ZONEBLD
    jne .t
    push rdi
    push rsi
    mov edi, r13d
    mov esi, r14d
    call destroy_to_rubble
    pop rsi
    pop rdi
.t:
    mov byte [r12+T_OBJ], OBJ_RUNWAY
    mov byte [r12+T_ZONE], 0
    mov byte [r12+T_FLAGS], 0
    mov byte [r12+T_LEVEL], 0
    mov word [r12+T_POP], 0
    mov dword [r12+T_OCC], 0
    mov byte [r12+T_PROBLEM], 0
    and byte [r12+T_MISC], MISC_RWKEEP
    ret

; the runway through (edi, esi): -> eax its length, rm_x0/rm_y0 its low
; end, rm_dir 1 (along x) or 2 (along y)
FUNC runway_measure
    mov r12d, edi
    mov r13d, esi
    ; along x if it goes on either way along x
    mov dword [rm_dir], 1
    lea edi, [r12+1]
    mov esi, r13d
    call is_runway
    test eax, eax
    jnz .dx
    lea edi, [r12-1]
    mov esi, r13d
    call is_runway
    test eax, eax
    jnz .dx
    lea edi, [r12]
    lea esi, [r13+1]
    call is_runway
    test eax, eax
    jnz .dy
    lea edi, [r12]
    lea esi, [r13-1]
    call is_runway
    test eax, eax
    jz .dx
.dy:
    mov dword [rm_dir], 2
.dx:
    mov r14d, [rm_dir]
    mov r15d, [dir_dx+r14*4]
    mov ebx, [dir_dy+r14*4]
    ; back to the low end
.b:
    mov edi, r12d
    sub edi, r15d
    mov esi, r13d
    sub esi, ebx
    call is_runway
    test eax, eax
    jz .bd
    sub r12d, r15d
    sub r13d, ebx
    jmp .b
.bd:
    mov [rm_x0], r12d
    mov [rm_y0], r13d
    ; and along it
    xor r14d, r14d
.f:
    mov edi, r12d
    mov esi, r13d
    call is_runway
    test eax, eax
    jz .fd
    inc r14d
    add r12d, r15d
    add r13d, ebx
    cmp r14d, 250
    jl .f
.fd:
    mov eax, r14d
    RETURN

; ---------------------------------------------------------------------
;  airports (with the other networks)
; ---------------------------------------------------------------------
FUNC airport_update, 32
    cmp dword [beta_on], 0
    je .out
    ; runways go quiet until an airport flies from them
    xor ebx, ebx
.c:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_RUNWAY
    jne .cn
    and byte [tiles+rax+T_MISC], MISC_RWKEEP
.cn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .c
    mov dword [ap_n], 0
    xor ebx, ebx
.s:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_SERVICE
    jne .sn
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .sn
    cmp byte [tiles+rax+T_SUB], BK_AIRPORT
    jne .sn
    mov r12d, [ap_n]
    cmp r12d, AP_MAX
    jge .mark
    mov [rbp-48], eax
    mov [ap_tile+r12*2], bx
    mov byte [ap_live+r12], 0
    mov byte [ap_rwlen+r12], 0
    ; the longest runway touching its footprint (not at the corners)
    mov r13d, -1                    ; dy
.ry:
    mov r14d, -1                    ; dx
.rx:
    mov eax, r13d
    or eax, r14d
    js .ring
    cmp r13d, 3
    je .ring
    cmp r14d, 3
    je .ring
    jmp .rn
.ring:
    ; corners are no good
    mov eax, r13d
    cmp eax, -1
    je .cy
    cmp eax, 3
    jne .ok
.cy:
    cmp r14d, -1
    je .rn
    cmp r14d, 3
    je .rn
.ok:
    mov edi, ebx
    and edi, MAP_W-1
    add edi, r14d
    mov esi, ebx
    shr esi, MAP_SHIFT
    add esi, r13d
    mov [rbp-52], edi
    mov [rbp-56], esi
    call is_runway
    test eax, eax
    jz .rn
    mov edi, [rbp-52]
    mov esi, [rbp-56]
    call runway_measure
    cmp al, [ap_rwlen+r12]
    jbe .rn
    CLAMP eax, 0, 255
    mov [ap_rwlen+r12], al
    mov eax, [rm_x0]
    mov [ap_x0+r12], al
    mov eax, [rm_y0]
    mov [ap_y0+r12], al
    mov eax, [rm_dir]
    mov [ap_dir+r12], al
.rn:
    inc r14d
    cmp r14d, 3
    jle .rx
    inc r13d
    cmp r13d, 3
    jle .ry
    ; flying: a long enough runway, and power
    mov eax, [rbp-48]
    test byte [tiles+rax+T_FLAGS], F_POWER
    jz .sadd
    movzx eax, byte [ap_rwlen+r12]
    cmp eax, RW_MIN
    jl .sadd
    mov byte [ap_live+r12], 1
    cmp eax, RW_INTL
    jl .sadd
    mov byte [ap_live+r12], 2
.sadd:
    inc dword [ap_n]
.sn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .s
.mark:
    ; the runways flown from are loud
    xor r12d, r12d
.m:
    cmp r12d, [ap_n]
    jge .pl
    movzx r15d, byte [ap_live+r12]
    test r15d, r15d
    jz .mn
    mov r8d, MISC_RWLIVE
    cmp r15d, 2
    jne .m1
    or r8d, MISC_RWINTL
.m1:
    movzx r13d, byte [ap_x0+r12]
    movzx r14d, byte [ap_y0+r12]
    movzx ebx, byte [ap_rwlen+r12]
    movzx ecx, byte [ap_dir+r12]
    mov [rbp-52], ecx
.mt:
    mov edi, r13d
    mov esi, r14d
    push r8
    push r8
    call tile_at
    pop r8
    pop r8
    test rax, rax
    jz .mn
    or [rax+T_MISC], r8b
    mov ecx, [rbp-52]
    add r13d, [dir_dx+rcx*4]
    add r14d, [dir_dy+rcx*4]
    dec ebx
    jnz .mt
.mn:
    inc r12d
    jmp .m
.pl:
    ; planes of airports that stopped flying are gone
    xor ebx, ebx
.pk:
    cmp byte [pl_kind+rbx], 0
    je .pkn
    movzx eax, byte [pl_ap+rbx]
    cmp eax, [ap_n]
    jae .pkx
    cmp byte [ap_live+rax], 0
    jne .pkn
.pkx:
    mov byte [pl_kind+rbx], 0
.pkn:
    inc ebx
    cmp ebx, PL_MAX
    jl .pk
    call airport_flights
.out:
    RETURN

; the month's flights (beta): the tourists' money (called before the
; month's income is summed)
FUNC airport_month
    cmp dword [beta_on], 0
    je .out
    call airport_flights
    mov eax, [air_pax]
    add [exports_month], eax        ; a dollar a passenger
    mov dword [air_trips], 0
.out:
    RETURN

; passengers, and what the city wants because of them
FUNC airport_flights
    xor r12d, r12d                  ; seats
    xor r13d, r13d                  ; flying jets
    xor ebx, ebx
.a:
    cmp ebx, [ap_n]
    jge .ad
    movzx eax, byte [ap_live+rbx]
    cmp eax, 1
    jne .a2
    add r12d, AP_PAX_SMALL
.a2:
    cmp eax, 2
    jne .an
    add r12d, AP_PAX_JET
    inc r13d
.an:
    inc ebx
    jmp .a
.ad:
    ; who wants to fly: a third of the people, and the sights
    mov eax, [population]
    xor edx, edx
    mov ecx, 3
    div ecx
    mov ecx, [svc_count+BK_LANDMARK*4]
    imul ecx, ecx, 3000
    add eax, ecx
    mov ecx, [svc_count+BK_STADIUM*4]
    imul ecx, ecx, 1000
    add eax, ecx
    cmp eax, r12d
    jle .p
    mov eax, r12d
.p:
    mov [air_pax], eax
    mov ecx, eax
    xor edx, edx
    mov r8d, 300
    div r8d
    CLAMP eax, 0, 25
    mov [air_com], eax
    xor eax, eax
    test r12d, r12d
    jz .o1
    mov eax, 6
    test r13d, r13d
    jz .o1
    mov eax, 15
.o1:
    mov [air_off], eax
    mov eax, ecx
    xor edx, edx
    mov r8d, 150
    div r8d
    CLAMP eax, 0, 60
    mov [ap_trip_pm], eax
    RETURN

; a trip to or from an airport (beta traffic)
FUNC airport_trip
    mov edi, [ap_n]
    test edi, edi
    jz .out
    call rand_range
    cmp byte [ap_live+rax], 0
    je .out
    movzx r13d, word [ap_tile+rax*2]
    call rand
    test eax, 1
    jz .arrive
    ; someone flying out: from home to the terminal
    lea rdi, [list_res]
    mov esi, [n_res]
    call pick_from
    cmp eax, -1
    je .out
    mov r12d, eax
    mov edi, r12d
    mov esi, r13d
    call travel_mode
    test eax, eax
    jnz .out
    mov edi, r12d
    mov esi, r13d
    mov edx, VT_CAR
    mov ecx, PU_SHOP
    call make_trip
    inc dword [air_trips]
    jmp .out
.arrive:
    ; a visitor who landed: from the terminal to the shops and hotels
    lea rdi, [list_com]
    mov esi, [n_com]
    call pick_from
    cmp eax, -1
    je .out
    mov r12d, eax
    mov edi, r13d
    mov esi, r12d
    call travel_mode
    test eax, eax
    jnz .out
    mov edi, r13d
    mov esi, r12d
    mov edx, VT_CAR
    mov ecx, PU_VISIT
    call make_trip
    inc dword [air_trips]
.out:
    RETURN

; noise from a runway tile flown from (rdi tile, esi x, edx y, rcx the
; rows, as stamp_rows takes them)
FUNC runway_noise, 32
    movzx eax, byte [rdi+T_MISC]
    test eax, MISC_RWLIVE
    jz .out
    mov [rbp-56], rcx
    mov r12d, esi
    mov r13d, edx
    mov r15d, 70
    test eax, MISC_RWINTL
    jz .s
    mov r15d, 110
.s:
    lea rdi, [map_noise]
    mov esi, r12d
    mov edx, r13d
    mov ecx, 3
    mov r8d, r15d
    mov r9, [rbp-56]
    call stamp_rows
    ; an end of the runway: the planes come in low past it
    xor r14d, r14d
.d:
    mov edi, r12d
    mov esi, r13d
    add edi, [dir_dx+r14*4]
    add esi, [dir_dy+r14*4]
    call is_runway
    test eax, eax
    jz .dn
    mov edi, r12d
    mov esi, r13d
    sub edi, [dir_dx+r14*4]
    sub esi, [dir_dy+r14*4]
    call is_runway
    test eax, eax
    jnz .dn
    ; out the other way
    xor ebx, ebx
.p:
    movzx eax, byte [rw_path+rbx*2]
    test eax, eax
    jz .dn
    mov edi, [dir_dx+r14*4]
    imul edi, eax
    neg edi
    add edi, r12d
    mov esi, [dir_dy+r14*4]
    imul esi, eax
    neg esi
    add esi, r13d
    movzx r8d, byte [rw_path+rbx*2+1]
    imul r8d, r15d
    shr r8d, 3

    mov edx, esi
    mov esi, edi
    lea rdi, [map_noise]
    mov ecx, 3
    mov r9, [rbp-56]
    call stamp_rows
    inc ebx
    jmp .p
.dn:
    inc r14d
    cmp r14d, 4
    jl .d
.out:
    RETURN

; ---------------------------------------------------------------------
;  planes
; ---------------------------------------------------------------------
; a new plane for airport ebx
FUNC plane_spawn
    xor r12d, r12d
.f:
    cmp byte [pl_kind+r12], 0
    je .have
    inc r12d
    cmp r12d, PL_MAX
    jl .f
    RETURN
.have:
    movzx eax, byte [ap_live+rbx]
    dec eax
    mov [pl_big+r12], al
    mov [pl_ap+r12], bl
    ; which way: into the wind, the same way for a few months
    movzx ecx, byte [ap_dir+rbx]
    movzx r13d, byte [ap_x0+rbx]
    movzx r14d, byte [ap_y0+rbx]
    mov eax, [month]
    shr eax, 2
    add eax, ebx
    test eax, 1
    jz .w
    ; from the far end, the other way
    movzx eax, byte [ap_rwlen+rbx]
    dec eax
    mov edx, [dir_dx+rcx*4]
    imul edx, eax
    add r13d, edx
    mov edx, [dir_dy+rcx*4]
    imul edx, eax
    add r14d, edx
    add ecx, 2
    and ecx, 3
.w:
    mov [pl_h+r12], cl
    shl r13d, 8
    add r13d, 128
    mov [pl_ox+r12*4], r13d
    shl r14d, 8
    add r14d, 128
    mov [pl_oy+r12*4], r14d
    movzx eax, byte [ap_rwlen+rbx]
    shl eax, 12
    imul eax, eax, 55
    xor edx, edx
    mov ecx, 100
    div ecx
    mov [pl_stop+r12*4], eax
    mov dword [pl_alt+r12*4], 0
    xor byte [ap_next+rbx], 1
    jz .leave
    ; landing: from the approach, at speed
    mov byte [pl_kind+r12], 1
    mov byte [pl_st+r12], 0
    mov dword [pl_s+r12*4], -PL_APPROACH*4096
    mov dword [pl_v+r12*4], 320
    mov dword [pl_alt+r12*4], PL_APPROACH*4096*3/128
    RETURN
.leave:
    mov byte [pl_kind+r12], 2
    mov byte [pl_st+r12], 4
    mov dword [pl_s+r12*4], 4096    ; (a tile in: all of it on the runway)
    mov dword [pl_v+r12*4], 0
    mov dword [pl_t+r12*4], 40
    RETURN

; the planes, a traffic step (beta)
FUNC planes_update
    cmp dword [beta_on], 0
    je .out
    ; airports send planes now and then
    xor ebx, ebx
.a:
    cmp ebx, [ap_n]
    jge .p
    cmp byte [ap_live+rbx], 0
    je .an
    dec dword [ap_clock+rbx*4]
    jg .an
    ; one plane on its runway at a time
    xor ecx, ecx
.busy:
    cmp byte [pl_kind+rcx], 0
    je .bn
    cmp [pl_ap+rcx], bl
    je .wait
.bn:
    inc ecx
    cmp ecx, PL_MAX
    jl .busy
    call plane_spawn
    mov edi, 400
    call rand_range
    add eax, 500
    cmp byte [ap_live+rbx], 2
    je .clk
    add eax, 400
.clk:
    mov [ap_clock+rbx*4], eax
    jmp .an
.wait:
    mov dword [ap_clock+rbx*4], 60
.an:
    inc ebx
    jmp .a
.p:
    xor ebx, ebx
.pl:
    cmp byte [pl_kind+rbx], 0
    je .pn
    movzx eax, byte [pl_st+rbx]
    cmp eax, 0
    je .appr
    cmp eax, 1
    je .roll
    cmp eax, 2
    je .dwell
    cmp eax, 3
    je .fade
    cmp eax, 4
    je .fadein
    cmp eax, 5
    je .run
    ; 6: climbing out
    mov eax, [pl_v+rbx*4]
    add eax, 2
    CLAMP eax, 0, 560
    mov [pl_v+rbx*4], eax
    add [pl_s+rbx*4], eax
    mov eax, [pl_s+rbx*4]
    sub eax, [pl_stop+rbx*4]
    imul eax, eax, 5
    sar eax, 7
    mov [pl_alt+rbx*4], eax
    cmp eax, 4000
    jl .pn
    jmp .gone
.appr:
    mov eax, [pl_v+rbx*4]
    add [pl_s+rbx*4], eax
    mov eax, [pl_s+rbx*4]
    test eax, eax
    jns .touch
    neg eax
    imul eax, eax, 3
    sar eax, 7
    mov [pl_alt+rbx*4], eax
    jmp .pn
.touch:
    ; down: brake to a stop by the taxiway
    mov dword [pl_alt+rbx*4], 0
    mov byte [pl_st+rbx], 1
    mov eax, [pl_v+rbx*4]
    imul eax, eax
    mov ecx, [pl_stop+rbx*4]
    sub ecx, [pl_s+rbx*4]
    CLAMP ecx, 4096, 1000000
    add ecx, ecx
    xor edx, edx
    div ecx
    inc eax
    mov [pl_dec+rbx*4], eax
    jmp .pn
.roll:
    mov eax, [pl_v+rbx*4]
    add [pl_s+rbx*4], eax
    sub eax, [pl_dec+rbx*4]
    mov [pl_v+rbx*4], eax
    cmp eax, 8
    jg .pn
    mov dword [pl_v+rbx*4], 0
    mov byte [pl_st+rbx], 2
    mov dword [pl_t+rbx*4], 90
    jmp .pn
.dwell:
    dec dword [pl_t+rbx*4]
    jg .pn
    mov byte [pl_st+rbx], 3
    mov dword [pl_t+rbx*4], 40
    jmp .pn
.fade:
    dec dword [pl_t+rbx*4]
    jg .pn
    jmp .gone
.fadein:
    dec dword [pl_t+rbx*4]
    jg .pn
    mov byte [pl_st+rbx], 5
    jmp .pn
.run:
    mov eax, [pl_v+rbx*4]
    add eax, 3
    mov [pl_v+rbx*4], eax
    add [pl_s+rbx*4], eax
    mov eax, [pl_s+rbx*4]
    cmp eax, [pl_stop+rbx*4]
    jl .pn
    mov byte [pl_st+rbx], 6
    jmp .pn
.gone:
    mov byte [pl_kind+rbx], 0
.pn:
    inc ebx
    cmp ebx, PL_MAX
    jl .pl
.out:
    RETURN

; draw the planes and their shadows (with the agents)
FUNC draw_planes, 32
    cmp dword [beta_on], 0
    je .out
    xor ebx, ebx
.p:
    cmp byte [pl_kind+rbx], 0
    je .pn
    movzx ecx, byte [pl_h+rbx]
    mov [rbp-48], ecx
    ; where: s along the heading from the start
    mov eax, [pl_s+rbx*4]
    sar eax, 4                      ; world units
    mov r12d, [dir_dx+rcx*4]
    imul r12d, eax
    add r12d, [pl_ox+rbx*4]
    mov r13d, [dir_dy+rcx*4]
    imul r13d, eax
    add r13d, [pl_oy+rbx*4]
    sub r12d, 16*16                 ; the model's corner
    sub r13d, 16*16
    movzx eax, byte [pl_big+rbx]
    shl eax, 2
    add eax, ecx
    mov [rbp-52], eax               ; sprite slot
    ; fading in or out: see-through
    xor eax, eax
    cmp byte [pl_st+rbx], 3
    je .dz
    cmp byte [pl_st+rbx], 4
    jne .dn
.dz:
    mov eax, 1
.dn:
    mov [rbp-56], eax
    ; the shadow, on the ground under it
    cmp dword [pl_alt+rbx*4], 16
    jl .body
    mov edi, r12d
    mov esi, r13d
    mov edx, 8
    call world_proj
    call .onscreen
    jc .body
    mov dword [blit_dither], 1
    mov r8d, [rbp-52]
    mov edi, [spr_pshadow+r8*4]
    mov esi, eax
    lea r8, [remap_identity]
    call blit_sprite
    mov dword [blit_dither], 0
.body:
    mov edi, r12d
    mov esi, r13d
    mov edx, [pl_alt+rbx*4]
    add edx, 16
    call world_proj
    call .onscreen
    jc .pn
    mov r8d, [rbp-56]
    mov [blit_dither], r8d
    mov r8d, [rbp-52]
    mov edi, [spr_plane+r8*4]
    mov esi, eax
    lea r8, [remap_identity]
    call blit_sprite
    mov dword [blit_dither], 0
.pn:
    inc ebx
    cmp ebx, PL_MAX
    jl .p
.out:
    RETURN
; (eax sx, edx sy) on the screen, with a margin? carry set if not
.onscreen:
    cmp eax, -80
    jl .off
    mov r8d, [fb_w]
    add r8d, 80
    cmp eax, r8d
    jg .off
    cmp edx, -80
    jl .off
    mov r8d, [fb_h]
    add r8d, 80
    cmp edx, r8d
    jg .off
    clc
    ret
.off:
    stc
    ret

; forget the planes (a new or loaded city)
planes_reset:
    push rdi
    push rcx
    lea rdi, [pl_kind]
    mov ecx, PL_MAX
    xor eax, eax
    rep stosb
    mov dword [ap_n], 0
    mov dword [air_pax], 0
    mov dword [air_com], 0
    mov dword [air_off], 0
    mov dword [ap_trip_pm], 0
    pop rcx
    pop rdi
    ret

; ---------------------------------------------------------------------
;  the inspector
; ---------------------------------------------------------------------
; an airport in the inspector (beta; rbx tile, r15d index)
FUNC airport_inspect
    cmp dword [beta_on], 0
    je .out
    cmp byte [rbx+T_SUB], BK_AIRPORT
    jne .out
    xor r12d, r12d
.f:
    cmp r12d, [ap_n]
    jge .out
    movzx eax, word [ap_tile+r12*2]
    cmp eax, r15d
    je .have
    inc r12d
    jmp .f
.have:
    movzx eax, byte [ap_live+r12]
    cmp eax, 2
    jne .n2
    lea rdx, [s_ap_jet]
    mov ecx, UI_GOOD
    call row_text
    jmp .pax
.n2:
    cmp eax, 1
    jne .n1
    lea rdx, [s_ap_small]
    mov ecx, UI_TEXT
    call row_text
    lea rdx, [s_ap_small2]
    mov ecx, UI_TEXT
    call row_text
    jmp .pax
.n1:
    movzx r13d, byte [ap_rwlen+r12]
    cmp r13d, RW_MIN
    jl .short
    lea rdx, [s_ap_power]
    mov ecx, UI_BAD
    call row_text
    jmp .out
.short:
    test r13d, r13d
    jnz .sh
    lea rdx, [s_ap_none]
    mov ecx, UI_BAD
    call row_text
    jmp .out
.sh:
    call tb_reset
    lea rdi, [s_ap_short]
    call tb_str
    movsxd rdi, r13d
    call tb_num
    lea rdi, [s_ap_short2]
    call tb_str
    lea rdx, [textbuf]
    mov ecx, UI_BAD
    call row_text
    jmp .out
.pax:
    call tb_reset
    lea rdi, [s_ap_pax]
    call tb_str
    movsxd rdi, dword [air_pax]
    call tb_num
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
.out:
    RETURN

; ---------------------------------------------------------------------
;  sprites: runway tiles, planes and their shadows, the terminal
; ---------------------------------------------------------------------
section .bss
air_axis    resd 1
section .text

; a box along the runway (f along it, l across it; x or y by air_axis)
; (edi f0, esi l0, edx z0, ecx f1, r8d l1, r9d z1)
rw_box:
    cmp dword [air_axis], 0
    je vbox
    xchg edi, esi
    xchg ecx, r8d
    jmp vbox

; a runway tile: edi 0 middle, 1 an end; esi 0 along x, 1 along y
FUNC gen_runway
    mov r12d, edi
    mov [air_axis], esi
    lea eax, [r12+rsi*2+8200]
    BEGIN 16, 3, eax
    MAT M_ASPHALT
    BOX 0,0,0,16,16,1
    MAT M_WHITE
    ; edge lines
    mov edi, 0
    mov esi, 1
    mov edx, 0
    mov ecx, 16
    mov r8d, 2
    mov r9d, 1
    call rw_box
    mov edi, 0
    mov esi, 14
    mov edx, 0
    mov ecx, 16
    mov r8d, 15
    mov r9d, 1
    call rw_box
    test r12d, r12d
    jnz .end
    ; the centre line, dashed
    mov edi, 2
    mov esi, 7
    mov edx, 0
    mov ecx, 9
    mov r8d, 9
    mov r9d, 1
    call rw_box
    jmp .d
.end:
    ; the threshold: white bars across
    xor ebx, ebx
.b:
    lea esi, [rbx*2+3]
    mov edi, 3
    xor edx, edx
    mov ecx, 13
    lea r8d, [rsi+1]
    mov r9d, 1
    call rw_box
    inc ebx
    cmp ebx, 5
    jl .b
    ; lights along the end
    MAT M_LAMP
    mov edi, 0
    mov esi, 2
    mov edx, 1
    mov ecx, 1
    mov r8d, 3
    mov r9d, 2
    call rw_box
    mov edi, 0
    mov esi, 13
    mov edx, 1
    mov ecx, 1
    mov r8d, 14
    mov r9d, 2
    call rw_box
.d:
    call finish_model
    RETURN

; plane_box: car_box on a 32 grid (f forward, l across)
plane_box:
    mov eax, [car_dir]
    cmp eax, 1
    je .px
    cmp eax, 3
    je .nx
    cmp eax, 2
    je .py
    ; 0: forward = -y : x = l, y = 32 - f
    mov eax, 32
    sub eax, ecx
    mov r10d, 32
    sub r10d, edi
    mov edi, esi
    mov esi, eax
    mov ecx, r8d
    mov r8d, r10d
    jmp vbox
.px:            ; forward = +x : x = f, y = 32 - l
    mov eax, 32
    sub eax, r8d
    mov r10d, 32
    sub r10d, esi
    mov esi, eax
    mov r8d, r10d
    jmp vbox
.nx:            ; forward = -x : x = 32 - f, y = l
    mov eax, 32
    sub eax, ecx
    mov r10d, 32
    sub r10d, edi
    mov edi, eax
    mov ecx, r10d
    jmp vbox
.py:            ; forward = +y : x = 32 - l, y = f
    mov eax, 32
    sub eax, r8d
    mov r10d, 32
    sub r10d, esi
    mov r11d, edi
    mov edi, eax
    mov esi, r11d
    mov eax, ecx
    mov ecx, r10d
    mov r8d, eax
    jmp vbox

%macro PBOX 6
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov ecx, %4
    mov r8d, %5
    mov r9d, %6
    call plane_box
%endmacro

; a plane (edi 0 small, 1 jet; esi dir; edx 1 = its shadow)
FUNC gen_plane
    mov r12d, edi
    mov [car_dir], esi
    mov r13d, edx
    lea eax, [r12*8+rsi+8300]
    lea eax, [rax+r13*4]
    BEGIN 32, 14, eax
    test r13d, r13d
    jnz .shadow
    test r12d, r12d
    jnz .jet
    ; a small plane: high wing, two propellers, a T tail
    MAT M_WHITE
    PBOX 7,14,2,25,18,5
    PBOX 25,15,3,27,17,4
    MAT M_RED
    PBOX 7,14,2,25,18,3
    MAT M_GLASS
    PBOX 23,14,4,25,18,5
    PBOX 10,14,3,22,18,4
    MAT M_WHITE
    PBOX 15,4,5,19,28,6
    MAT M_DARK
    PBOX 17,9,4,21,11,5
    PBOX 17,21,4,21,23,5
    MAT M_METAL
    PBOX 21,8,3,22,12,6
    PBOX 21,20,3,22,24,6
    MAT M_RED
    PBOX 7,15,5,11,17,11
    PBOX 7,11,10,10,21,11
    jmp .d
.jet:
    ; a jet: swept wings, engines under them, a tall fin
    MAT M_WHITE
    PBOX 3,14,2,29,18,6
    PBOX 29,15,3,31,17,5
    MAT M_BLUE
    PBOX 3,14,3,29,18,4
    MAT M_GLASS
    PBOX 8,14,4,26,18,5
    PBOX 27,14,5,29,18,6
    MAT M_METAL
    PBOX 13,3,3,19,14,4
    PBOX 13,18,3,19,29,4
    PBOX 11,3,3,13,6,4
    PBOX 11,26,3,13,29,4
    MAT M_DARK
    PBOX 14,8,1,19,10,3
    PBOX 14,22,1,19,24,3
    MAT M_METAL
    PBOX 3,9,5,7,23,6
    MAT M_BLUE
    PBOX 3,15,6,8,17,13
    jmp .d
.shadow:
    MAT M_DARK
    test r12d, r12d
    jnz .sj
    PBOX 7,14,0,27,18,1
    PBOX 15,4,0,19,28,1
    PBOX 7,11,0,10,21,1
    jmp .d
.sj:
    PBOX 3,14,0,31,18,1
    PBOX 13,3,0,19,29,1
    PBOX 3,9,0,7,23,1
.d:
    call finish_model
    RETURN

; the airport: a glass terminal, gates, a control tower, a plane waiting
FUNC bld_airport
    BEGIN 48, 44, 8400
    MAT M_CONCRETE
    BOX 0,0,0,48,48,1
    ; apron markings
    MAT M_YELLOW
    BOX 2,12,0,46,13,1
    BOX 14,2,0,15,12,1
    BOX 32,2,0,33,12,1
    ; the terminal
    MAT M_CONCRETE
    BOX 3,26,1,45,45,3
    MAT M_GLASS
    BOX 4,27,3,44,44,12
    MAT M_WHITE
    RFX 3,26,12,45,45,5
    ; gates out to the apron
    MAT M_METAL
    BOX 10,16,7,13,27,9
    BOX 28,16,7,31,27,9
    MAT M_DARK
    BOX 10,15,1,13,17,9
    BOX 28,15,1,31,17,9
    ; the control tower
    MAT M_CONCRETE
    BOX 38,4,1,43,9,32
    MAT M_GLASS
    BOX 36,2,32,45,11,37
    MAT M_DARK
    BOX 36,2,37,45,11,39
    MAT M_BEACON
    BOX 40,6,39,41,7,42
    ; a small plane at the gate
    MAT M_WHITE
    BOX 16,5,2,34,8,5
    BOX 22,1,3,28,12,4
    MAT M_BLUE
    BOX 16,6,5,19,7,9
    MAT M_GLASS
    BOX 31,5,4,33,8,5
    call finish_model
    RETURN

FUNC air_sprites_init
    xor ebx, ebx
.r:
    mov edi, ebx
    shr edi, 1
    mov esi, ebx
    and esi, 1
    call gen_runway
    mov [spr_runway+rbx*4], eax
    inc ebx
    cmp ebx, 4
    jl .r
    xor ebx, ebx
.p:
    mov edi, ebx
    shr edi, 2
    mov esi, ebx
    and esi, 3
    xor edx, edx
    call gen_plane
    mov [spr_plane+rbx*4], eax
    mov edi, ebx
    shr edi, 2
    mov esi, ebx
    and esi, 3
    mov edx, 1
    call gen_plane
    mov [spr_pshadow+rbx*4], eax
    inc ebx
    cmp ebx, 8
    jl .p
    RETURN
