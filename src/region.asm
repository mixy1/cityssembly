; =====================================================================
;  REGION (beta) - the neighbouring cities, the regional market, deals
;
;  Every map edge leads to a neighbour with a name, a character and a
;  population that grows.  A highway, a railway to the edge or an
;  airport links you to it.
;
;  - The market: what your exports fetch rises and falls, with
;    recessions and booms now and then; industry wants to grow when
;    prices are up and the neighbours are linked.
;  - Deals: a neighbour offers to buy your spare power or water, or to
;    pay you to take its garbage, for a year.  Keep your side (the spare
;    capacity, the landfill room) and it pays every month.
;  - Their names stand at the edges where your links leave the map.
;
;  The Neighbours panel: C, or the button in the budget.
; =====================================================================
NB_N        equ 4               ; one per edge: north, east, south, west
NB_INDUSTRY equ 0
NB_FARM     equ 1
NB_RESORT   equ 2
NB_CAPITAL  equ 3
CT_NONE     equ 0
CT_POWER    equ 1               ; they buy spare power
CT_WATER    equ 2               ; they buy spare water
CT_GARBAGE  equ 3               ; they pay you to take their garbage
CT_MONTHS   equ 12
OF_MONTHS   equ 3               ; an offer stands this long

section .bss
alignb 8
region_state:                   ; (saved: "RGON")
nb_kind     resd NB_N
nb_name     resd NB_N
nb_pop      resd NB_N
nb_trade    resd NB_N           ; trade with it last month ($)
mk_price    resd 1              ; what exports fetch, % of normal
mk_trend    resd 1
mk_event    resd 1              ; months of recession (<0) or boom (>0)
ct_kind     resd 1              ; the deal running
ct_nb       resd 1
ct_amount   resd 1
ct_pay      resd 1              ; $ a month
ct_left     resd 1              ; months
ct_missed   resd 1              ; months it wasn't kept
of_kind     resd 1              ; a deal on offer
of_nb       resd 1
of_amount   resd 1
of_pay      resd 1
of_left     resd 1              ; months the offer stands
ct_cool     resd 1              ; months until the next offer
rg_ready    resd 1
goods_sold_month resd 1         ; what exports fetched this month
trade_last  resd 1              ; and last month, at market prices
region_state_end:
nb_links    resb NB_N           ; 1 highway, 2 railway, 4 by air
nb_tile     resd NB_N           ; a link on its edge (for its name), -1

section .data
nb_names    dq nbn0, nbn1, nbn2, nbn3, nbn4, nbn5, nbn6, nbn7
            dq nbn8, nbn9, nbn10, nbn11, nbn12, nbn13, nbn14, nbn15
nbn0        db "Port Ember", 0
nbn1        db "Kessel", 0
nbn2        db "Marrow Falls", 0
nbn3        db "Brightwater", 0
nbn4        db "Oakhollow", 0
nbn5        db "Stonebridge", 0
nbn6        db "Vantis", 0
nbn7        db "Cinder Bay", 0
nbn8        db "Hollin", 0
nbn9        db "Greyford", 0
nbn10       db "Lumen", 0
nbn11       db "Redcliff", 0
nbn12       db "Ashgrove", 0
nbn13       db "Northwick", 0
nbn14       db "Seabrook", 0
nbn15       db "Tallow", 0
nb_kinds    dq nbk0, nbk1, nbk2, nbk3
nbk0        db "industrial town", 0
nbk1        db "farming county", 0
nbk2        db "resort", 0
nbk3        db "capital", 0
nb_dirs     dq nbd0, nbd1, nbd2, nbd3
nbd0        db "North", 0
nbd1        db "East", 0
nbd2        db "South", 0
nbd3        db "West", 0
; people at the start (base, spread) and growth a month (per 1000)
nb_pop0     dd 8000, 3000, 4000, 30000
nb_popr     dd 7000, 3000, 5000, 20000
nb_grow     dd 4, 2, 3, 5
s_rg_title  db "Neighbours", 0
s_rg_price  db "Export prices: ", 0
s_rg_rec    db "  recession, months left: ", 0
s_rg_boom   db "  boom, months left: ", 0
s_rg_up     db "  rising", 0
s_rg_down   db "  falling", 0
s_rg_flat   db "  steady", 0
s_rg_dash   db " - ", 0
s_rg_people db " people  ", 0
s_rg_road   db "highway ", 0
s_rg_rail   db "rail ", 0
s_rg_air    db "air ", 0
s_rg_trade  db " trade ", 0
s_rg_nolink db "no link: lay track to this edge", 0
s_rg_deal   db "Deal: ", 0
s_rg_nodeal db "No deal running. Neighbours make offers now and then.", 0
s_rg_left   db ", months left: ", 0
s_rg_amo    db " a month", 0
s_rg_offer  db "Offer: ", 0
s_rg_colon  db ": ", 0
s_rg_ok     db "Accept", 0
s_rg_no     db "Decline", 0
s_rg_miss   db "  (missed: ", 0
s_rg_close  db ")", 0
; what a deal is, by kind: (neighbour) (text 1) (amount) (text 2) (pay)
ct_what     dq 0, ctw1, ctw2, ctw3
ct_what2    dq 0, ctv1, ctv2, ctv3
ctw1        db " buys ", 0
ctv1        db " of your spare power", 0
ctw2        db " buys ", 0
ctw3        db " sends ", 0
ctv3        db " garbage a month to your dumps", 0
ctv2        db " of your spare water", 0
s_rg_for    db ", ", 0
s_rg_year   db " a month, for a year", 0
s_rg_pad    db "   ", 0
; notices
s_rg_offerm db " offers a deal - see Neighbours (C).", 0
s_rg_signed db "Deal signed with ", 0
s_rg_ended  db "The deal with ", 0
s_rg_ended2 db " has ended.", 0
s_rg_missed db "The deal with ", 0
s_rg_missed2 db " wasn't kept this month: no payment.", 0
s_rg_broken db " called the deal off: it wasn't kept.", 0
s_rg_recm   db "Recession in the region: exports fetch less.", 0
s_rg_boomm  db "Boom in the region: exports fetch more.", 0
s_rg_recend db "The recession is over.", 0
s_rg_boomend db "The boom is over.", 0
s_rg_btn    db "Neighbours", 0
s_rg_tip    db "The neighbouring cities, the market for your exports, deals (C)", 0

section .text

; the neighbours of a new or loaded city are made on first use
region_reset:
    push rdi
    push rcx
    lea rdi, [region_state]
    mov ecx, region_state_end - region_state
    xor eax, eax
    rep stosb
    pop rcx
    pop rdi
    ret

FUNC region_ensure
    cmp dword [rg_ready], 0
    jne .out
    xor ebx, ebx
.n:
    mov edi, [world_seed]
    imul eax, ebx, 7919
    add edi, eax
    add edi, 12345
    call hash32
    mov r12d, eax
    ; the character: every edge a different one, turned by the seed
    mov eax, r12d
    shr eax, 20
    add eax, ebx
    and eax, 3
    mov [nb_kind+rbx*4], eax
    mov r13d, eax
    ; a name not taken yet
    mov eax, r12d
    shr eax, 8
    and eax, 15
.nm:
    xor ecx, ecx
.nc:
    cmp ecx, ebx
    jge .nok
    cmp [nb_name+rcx*4], eax
    je .nnx
    inc ecx
    jmp .nc
.nnx:
    inc eax
    and eax, 15
    jmp .nm
.nok:
    mov [nb_name+rbx*4], eax
    ; people
    mov eax, r12d
    shr eax, 4
    and eax, 0xFFFF
    xor edx, edx
    div dword [nb_popr+r13*4]
    add edx, [nb_pop0+r13*4]
    mov [nb_pop+rbx*4], edx
    inc ebx
    cmp ebx, NB_N
    jl .n
    mov dword [mk_price], 100
    mov dword [ct_cool], 3
    mov dword [rg_ready], 1
.out:
    RETURN

; the edge a border tile is on (edi tile) -> eax 0..3 or -1
edge_of:
    mov eax, edi
    shr eax, MAP_SHIFT
    jz .n
    mov ecx, edi
    and ecx, MAP_W-1
    cmp ecx, MAP_W-1
    je .e
    cmp eax, MAP_W-1
    je .s
    test ecx, ecx
    jz .w
    mov eax, -1
    ret
.n: xor eax, eax
    ret
.e: mov eax, 1
    ret
.s: mov eax, 2
    ret
.w: mov eax, 3
    ret

; how each neighbour is linked to the city
FUNC region_links
    mov dword [nb_links], 0
    xor ebx, ebx
.c:
    mov dword [nb_tile+rbx*4], -1
    inc ebx
    cmp ebx, NB_N
    jl .c
    ; highways
    xor ebx, ebx
.h:
    cmp ebx, [n_links]
    jge .r
    movzx r12d, word [links+rbx*2]
    mov edi, r12d
    call edge_of
    test eax, eax
    js .hn
    or byte [nb_links+rax], 1
    cmp dword [nb_tile+rax*4], -1
    jne .hn
    mov [nb_tile+rax*4], r12d
.hn:
    inc ebx
    jmp .h
.r:
    ; railways to the edge
    mov ebx, 1
.rl:
    cmp ebx, [rl_lines]
    jg .a
    movzx r12d, word [rl_edge+rbx*2]
    test r12d, r12d
    jz .rn
    dec r12d
    mov edi, r12d
    call edge_of
    test eax, eax
    js .rn
    or byte [nb_links+rax], 2
    cmp dword [nb_tile+rax*4], -1
    jne .rn
    mov [nb_tile+rax*4], r12d
.rn:
    inc ebx
    cmp ebx, 4095
    jl .rl
.a:
    ; an airport flies to all of them
    xor ebx, ebx
.ap:
    cmp ebx, [ap_n]
    jge .out
    cmp byte [ap_live+rbx], 0
    jne .air
    inc ebx
    jmp .ap
.air:
    or dword [nb_links], 0x04040404
.out:
    RETURN

; a notice with a neighbour's name in front (edi neighbour, rsi text,
; edx colour)
FUNC rg_notify
    mov r12d, edx
    mov r13, rsi
    call tb_reset
    mov eax, [nb_name+rdi*4]
    and eax, 15
    mov rdi, [nb_names+rax*8]
    call tb_str
    mov rdi, r13
    call tb_str
    lea rdi, [textbuf]
    mov esi, r12d
    mov edx, -1
    mov ecx, -1
    call notify
    RETURN

; the month (beta): called before the month's income is summed
FUNC region_month, 16
    cmp dword [beta_on], 0
    je .out
    call region_ensure
    call region_links
    ; the neighbours grow
    xor ebx, ebx
.g:
    mov ecx, [nb_kind+rbx*4]
    and ecx, 3
    mov r12d, [nb_grow+rcx*4]
    mov edi, 3
    call rand_range
    add r12d, eax
    mov eax, [nb_pop+rbx*4]
    imul eax, r12d
    xor edx, edx
    mov ecx, 1000
    div ecx
    add [nb_pop+rbx*4], eax
    cmp dword [nb_pop+rbx*4], 2000000
    jl .gn
    mov dword [nb_pop+rbx*4], 2000000
.gn:
    inc ebx
    cmp ebx, NB_N
    jl .g
    call market_month
    ; what the goods fetched at today's prices
    mov eax, [goods_sold_month]
    mov ecx, [mk_price]
    sub ecx, 100
    imul eax, ecx
    cdq
    mov ecx, 100
    idiv ecx
    add [exports_month], eax
    cmp dword [exports_month], 0
    jge .ex
    mov dword [exports_month], 0
.ex:
    add eax, [goods_sold_month]
    mov [trade_last], eax
    mov dword [goods_sold_month], 0
    call trade_shares
    ; industry wants to grow when prices are up and the region linked
    xor ecx, ecx
    xor ebx, ebx
.lk:
    cmp byte [nb_links+rbx], 0
    je .lkn
    add ecx, 3
.lkn:
    inc ebx
    cmp ebx, NB_N
    jl .lk
    mov eax, [mk_price]
    sub eax, 100
    sar eax, 1
    add eax, 50
    add eax, ecx
    CLAMP eax, 10, 90
    mov ecx, [ext_demand]
    sub eax, ecx
    CLAMP eax, -3, 3
    add [ext_demand], eax
    call deal_month
.out:
    RETURN

; export prices: a walk, pulled back to normal - or to a recession's
; low or a boom's high
FUNC market_month
    mov eax, [mk_event]
    test eax, eax
    jnz .ev
    ; one now and then
    mov edi, 40
    call rand_range
    test eax, eax
    jnz .walk
    mov edi, 5
    call rand_range
    add eax, 6
    mov r12d, eax
    call rand
    test eax, 1
    jz .rec
    mov [mk_event], r12d
    lea rdi, [s_rg_boomm]
    mov esi, UI_GOOD
    jmp .note
.rec:
    neg r12d
    mov [mk_event], r12d
    lea rdi, [s_rg_recm]
    mov esi, UI_BAD
.note:
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .walk
.ev:
    ; an event runs its course
    jg .evb
    inc dword [mk_event]
    jnz .walk
    lea rdi, [s_rg_recend]
    mov esi, UI_GOOD
    jmp .evn
.evb:
    dec dword [mk_event]
    jnz .walk
    lea rdi, [s_rg_boomend]
    mov esi, UI_TEXT
.evn:
    mov edx, -1
    mov ecx, -1
    call notify
.walk:
    mov r12d, 100
    mov eax, [mk_event]
    test eax, eax
    jz .t
    mov r12d, 72
    js .t
    mov r12d, 130
.t:
    mov edi, 5
    call rand_range
    sub eax, 2
    add eax, [mk_trend]
    CLAMP eax, -3, 3
    mov [mk_trend], eax
    mov eax, r12d
    sub eax, [mk_price]
    cdq
    mov ecx, 6
    idiv ecx
    add eax, [mk_trend]
    add eax, [mk_price]
    CLAMP eax, 55, 150
    mov [mk_price], eax
    RETURN

; the month's trade, shared among the linked neighbours by size
FUNC trade_shares
    xor r12d, r12d                  ; weights
    xor ebx, ebx
.w:
    mov dword [nb_trade+rbx*4], 0
    cmp byte [nb_links+rbx], 0
    je .wn
    mov eax, [nb_pop+rbx*4]
    shr eax, 10
    inc eax
    add r12d, eax
.wn:
    inc ebx
    cmp ebx, NB_N
    jl .w
    test r12d, r12d
    jz .out
    xor ebx, ebx
.s:
    cmp byte [nb_links+rbx], 0
    je .sn
    mov eax, [nb_pop+rbx*4]
    shr eax, 10
    inc eax
    imul eax, [trade_last]
    cdq
    idiv r12d
    mov [nb_trade+rbx*4], eax
.sn:
    inc ebx
    cmp ebx, NB_N
    jl .s
.out:
    RETURN

; the deal running, and new offers
FUNC deal_month
    cmp dword [ct_left], 0
    je .offers
    ; kept this month?
    mov eax, [ct_kind]
    cmp eax, CT_POWER
    jne .w
    mov eax, [power_supply]
    sub eax, [power_demand]
    cmp eax, [ct_amount]
    jl .miss
    jmp .paid
.w:
    cmp eax, CT_WATER
    jne .gb
    mov eax, [water_supply]
    sub eax, [water_demand]
    cmp eax, [ct_amount]
    jl .miss
    jmp .paid
.gb:
    ; their garbage: burned, or buried if there's room
    cmp dword [svc_count+BK_INCIN*4], 0
    jne .paid
    mov eax, [landfill_cap]
    sub eax, [landfill_used]
    cmp eax, [ct_amount]
    jl .miss
    mov eax, [ct_amount]
    add [landfill_used], eax
.paid:
    mov eax, [ct_pay]
    add [exports_month], eax
    jmp .left
.miss:
    inc dword [ct_missed]
    mov edi, [ct_nb]
    cmp dword [ct_missed], 3
    jge .broken
    call tb_reset
    lea rdi, [s_rg_missed]
    call tb_str
    mov eax, [ct_nb]
    mov eax, [nb_name+rax*4]
    and eax, 15
    mov rdi, [nb_names+rax*8]
    call tb_str
    lea rdi, [s_rg_missed2]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .left
.broken:
    lea rsi, [s_rg_broken]
    mov edx, UI_BAD
    call rg_notify
    mov dword [ct_left], 0
    mov dword [ct_kind], 0
    mov dword [ct_cool], 6
    jmp .out
.left:
    dec dword [ct_left]
    jnz .out
    mov dword [ct_kind], 0
    mov dword [ct_cool], 3
    call tb_reset
    lea rdi, [s_rg_ended]
    call tb_str
    mov eax, [ct_nb]
    mov eax, [nb_name+rax*4]
    and eax, 15
    mov rdi, [nb_names+rax*8]
    call tb_str
    lea rdi, [s_rg_ended2]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_TEXT
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .out
.offers:
    cmp dword [of_kind], 0
    je .cool
    dec dword [of_left]
    jg .out
    mov dword [of_kind], 0          ; it lapsed
    mov dword [ct_cool], 4
    jmp .out
.cool:
    cmp dword [ct_cool], 0
    je .make
    dec dword [ct_cool]
    jmp .out
.make:
    call deal_offer
.out:
    RETURN

; a neighbour offers a deal the city could keep (if one fits)
FUNC deal_offer, 16
    ; which neighbour: one that's linked
    mov edi, NB_N
    call rand_range
    mov r12d, eax
    xor ebx, ebx
.pk:
    cmp byte [nb_links+r12], 0
    jne .have
    inc r12d
    and r12d, NB_N-1
    inc ebx
    cmp ebx, NB_N
    jl .pk
    mov dword [ct_cool], 2
    RETURN
.have:
    ; what the city could spare, from a random start
    mov edi, 3
    call rand_range
    mov r13d, eax
    xor r14d, r14d
.try:
    cmp r14d, 3
    jge .none
    lea eax, [r13+r14]
    xor edx, edx
    mov ecx, 3
    div ecx
    cmp edx, 0
    je .pw
    cmp edx, 1
    je .wt
    ; garbage: an incinerator or a roomy landfill
    mov eax, 1000
    cmp dword [svc_count+BK_INCIN*4], 0
    jne .gok
    mov ecx, [landfill_cap]
    sub ecx, [landfill_used]
    cmp ecx, 20000
    jl .next
.gok:
    mov r15d, CT_GARBAGE
    mov [rbp-48], eax
    imul eax, eax, 3
    shr eax, 1
    jmp .set
.pw:
    mov eax, [power_supply]
    sub eax, [power_demand]
    mov r15d, CT_POWER
    jmp .spare
.wt:
    mov eax, [water_supply]
    sub eax, [water_demand]
    mov r15d, CT_WATER
.spare:
    cmp eax, 800
    jl .next
    ; half of it, in hundreds
    shr eax, 1
    xor edx, edx
    mov ecx, 100
    div ecx
    imul eax, eax, 100
    mov [rbp-48], eax
    ; a capital pays more
    mov ecx, 2
    cmp r15d, CT_WATER
    jne .pc
    mov ecx, 1
.pc:
    cmp dword [nb_kind+r12*4], NB_CAPITAL
    jne .pp
    inc ecx
.pp:
    imul eax, ecx
.set:
    mov [of_pay], eax
    mov eax, [rbp-48]
    mov [of_amount], eax
    mov [of_kind], r15d
    mov [of_nb], r12d
    mov dword [of_left], OF_MONTHS
    mov edi, r12d
    lea rsi, [s_rg_offerm]
    mov edx, UI_GOLD
    call rg_notify
    RETURN
.next:
    inc r14d
    jmp .try
.none:
    mov dword [ct_cool], 2
    RETURN

; ---------------------------------------------------------------------
;  the Neighbours panel
; ---------------------------------------------------------------------
; a deal's terms into the text builder (edi kind, esi neighbour,
; edx amount)
FUNC deal_text
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov eax, [nb_name+r13*4]
    and eax, 15
    mov rdi, [nb_names+rax*8]
    call tb_str
    and r12d, 3
    mov rdi, [ct_what+r12*8]
    test rdi, rdi
    jz .out
    call tb_str
    movsxd rdi, r14d
    call tb_num
    mov rdi, [ct_what2+r12*8]
    call tb_str
.out:
    RETURN

RG_W        equ 420
RG_H        equ 230

FUNC draw_region, 32
    call region_ensure
    call region_links
    mov r12d, [ui_w]
    sub r12d, RG_W
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, RG_H
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, RG_W
    mov ecx, RG_H
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, RG_W
    mov ecx, RG_H
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_rg_title]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    add r13d, 30
    ; the market
    call tb_reset
    lea rdi, [s_rg_price]
    call tb_str
    movsxd rdi, dword [mk_price]
    call tb_pct
    mov eax, [mk_event]
    test eax, eax
    jz .tr
    lea rdi, [s_rg_boom]
    jg .evs
    lea rdi, [s_rg_rec]
    neg eax
.evs:
    mov [rbp-48], eax
    call tb_str
    movsxd rdi, dword [rbp-48]
    call tb_num
    jmp .pd
.tr:
    lea rdi, [s_rg_flat]
    mov eax, [mk_trend]
    cmp eax, 1
    jl .tr1
    lea rdi, [s_rg_up]
.tr1:
    cmp eax, -1
    jg .tr2
    lea rdi, [s_rg_down]
.tr2:
    call tb_str
.pd:
    mov ecx, UI_GOOD
    cmp dword [mk_price], 100
    jge .pc
    mov ecx, UI_BAD
.pc:
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [textbuf]
    call draw_text
    add r13d, 18
    ; the four neighbours
    xor ebx, ebx
.nb:
    call tb_reset
    mov rdi, [nb_dirs+rbx*8]
    call tb_str
    lea rdi, [s_rg_colon]
    call tb_str
    mov eax, [nb_name+rbx*4]
    and eax, 15
    mov rdi, [nb_names+rax*8]
    call tb_str
    lea rdi, [s_rg_dash]
    call tb_str
    mov eax, [nb_kind+rbx*4]
    and eax, 3
    mov rdi, [nb_kinds+rax*8]
    call tb_str
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call draw_text
    add r13d, 11
    call tb_reset
    movsxd rdi, dword [nb_pop+rbx*4]
    call tb_num
    lea rdi, [s_rg_people]
    call tb_str
    movzx r14d, byte [nb_links+rbx]
    test r14d, r14d
    jnz .lk
    lea rdi, [s_rg_nolink]
    call tb_str
    mov ecx, UI_DIM
    jmp .ld
.lk:
    test r14d, 1
    jz .l2
    lea rdi, [s_rg_road]
    call tb_str
.l2:
    test r14d, 2
    jz .l3
    lea rdi, [s_rg_rail]
    call tb_str
.l3:
    test r14d, 4
    jz .l4
    lea rdi, [s_rg_air]
    call tb_str
.l4:
    lea rdi, [s_rg_trade]
    call tb_str
    movsxd rdi, dword [nb_trade+rbx*4]
    call tb_money
    mov ecx, UI_DIM
.ld:
    lea edi, [r12+22]
    mov esi, r13d
    lea rdx, [textbuf]
    call draw_text
    add r13d, 15
    inc ebx
    cmp ebx, NB_N
    jl .nb
    add r13d, 4
    ; the deal running
    call tb_reset
    cmp dword [ct_left], 0
    jne .deal
    lea rdi, [s_rg_nodeal]
    call tb_str
    mov ecx, UI_DIM
    jmp .dd
.deal:
    lea rdi, [s_rg_deal]
    call tb_str
    mov edi, [ct_kind]
    mov esi, [ct_nb]
    mov edx, [ct_amount]
    mov ecx, [ct_pay]
    call deal_text
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_GOOD
    call draw_text
    add r13d, 11
    call tb_reset
    lea rdi, [s_rg_pad]
    call tb_str
    movsxd rdi, dword [ct_pay]
    call tb_money
    lea rdi, [s_rg_amo]
    call tb_str
    lea rdi, [s_rg_left]
    call tb_str
    movsxd rdi, dword [ct_left]
    call tb_num
    cmp dword [ct_missed], 0
    je .dm
    lea rdi, [s_rg_miss]
    call tb_str
    movsxd rdi, dword [ct_missed]
    call tb_num
    lea rdi, [s_rg_close]
    call tb_str
.dm:
    mov ecx, UI_DIM
.dd:
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [textbuf]
    call draw_text
    add r13d, 16
    ; an offer
    cmp dword [of_kind], 0
    je .out
    call tb_reset
    lea rdi, [s_rg_offer]
    call tb_str
    mov edi, [of_kind]
    mov esi, [of_nb]
    mov edx, [of_amount]
    mov ecx, [of_pay]
    call deal_text
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text
    add r13d, 11
    call tb_reset
    lea rdi, [s_rg_pad]
    call tb_str
    movsxd rdi, dword [of_pay]
    call tb_money
    lea rdi, [s_rg_year]
    call tb_str
    lea edi, [r12+10]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text
    add r13d, 14
    lea edi, [r12+10]
    mov esi, r13d
    mov edx, 90
    lea rcx, [s_rg_ok]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .no
    cmp dword [ct_left], 0
    jne .no
    mov eax, [of_kind]
    mov [ct_kind], eax
    mov eax, [of_nb]
    mov [ct_nb], eax
    mov eax, [of_amount]
    mov [ct_amount], eax
    mov eax, [of_pay]
    mov [ct_pay], eax
    mov dword [ct_left], CT_MONTHS
    mov dword [ct_missed], 0
    mov dword [of_kind], 0
    mov dword [of_left], 0
    call tb_reset
    lea rdi, [s_rg_signed]
    call tb_str
    mov eax, [ct_nb]
    mov eax, [nb_name+rax*4]
    and eax, 15
    mov rdi, [nb_names+rax*8]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_COIN
    call sfx_play
    jmp .out
.no:
    lea edi, [r12+110]
    mov esi, r13d
    mov edx, 90
    lea rcx, [s_rg_no]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .out
    mov dword [of_kind], 0
    mov dword [of_left], 0
    mov dword [ct_cool], 4
.out:
    RETURN

; the budget's button to it (beta; edi x, esi y)
FUNC region_button
    cmp dword [beta_on], 0
    je .out
    mov r12d, edi
    mov r13d, esi
    mov edx, 90
    lea rcx, [s_rg_btn]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .t
    mov dword [panel], PANEL_REGION
.t:
    mov edi, r12d
    mov esi, r13d
    mov edx, 90
    mov ecx, 14
    call ui_over
    test eax, eax
    jz .out
    lea rax, [s_rg_tip]
    mov [tooltip], rax
.out:
    RETURN

; the neighbours' names where the links leave the map (beta)
FUNC region_labels
    cmp dword [beta_on], 0
    je .out
    cmp dword [rg_ready], 0
    je .out
    xor ebx, ebx
.l:
    mov eax, [nb_tile+rbx*4]
    cmp eax, -1
    je .n
    mov edi, eax
    and edi, MAP_W-1
    shl edi, 8
    add edi, 128
    mov esi, eax
    shr esi, MAP_SHIFT
    shl esi, 8
    add esi, 128
    mov edx, 24*16
    call world_proj
    mov r13d, edx
    imul eax, [zoom]
    cdq
    idiv dword [ui_scale]
    mov r12d, eax
    mov eax, r13d
    imul eax, [zoom]
    cdq
    idiv dword [ui_scale]
    mov r13d, eax
    cmp r12d, -100
    jl .n
    mov eax, [ui_w]
    add eax, 100
    cmp r12d, eax
    jg .n
    cmp r13d, -20
    jl .n
    cmp r13d, [ui_h]
    jg .n
    call tb_reset
    mov eax, [nb_name+rbx*4]
    and eax, 15
    mov rdi, [nb_names+rax*8]
    call tb_str
    mov edi, ' '
    call tb_char
    mov edi, '('
    call tb_char
    movsxd rdi, dword [nb_pop+rbx*4]
    call tb_num
    mov edi, ')'
    call tb_char
    mov edi, r12d
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text_centered
.n:
    inc ebx
    cmp ebx, NB_N
    jl .l
.out:
    RETURN
