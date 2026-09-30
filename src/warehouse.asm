; =====================================================================
;  WAREHOUSES (beta) - goods kept near where they're made and sold
;
;  A warehouse (2x2, from 1,200 people; it needs power) holds up to 200 truckloads of
;  goods (in its anchor tile's T_POP).  Factories within its reach (24
;  tiles) that would truck their goods out of town take them there
;  instead; shops within its reach that run short are restocked from it
;  and don't have to import from the region.  What it holds over a
;  reserve of 40 loads goes out in bulk: four loads a truck, worth $15 a
;  load (against $12), or $20 by rail from a freight yard on a line to
;  the map edge.  Short trips, and fewer trucks on the highway.
; =====================================================================
WH_MAX      equ 32
WH_CAP      equ 200
WH_KEEP     equ 40              ; kept back for the shops
WH_REACH    equ 24
PU_STORE    equ 13

section .bss
wh_n        resd 1
wh_tile     resd WH_MAX
wh_in       resd 1              ; loads stored this month
wh_out      resd 1              ; to shops
wh_bulk     resd 1              ; exported
wh_in_last  resd 1
wh_out_last resd 1
wh_bulk_last resd 1

section .data
nm_wh       db "Warehouse", 0
ds_wh       db "Stores goods: shops restock nearby.", 0
hb_wh       db "Factories in reach store their", 10
            db "goods here; shops in reach restock", 10
            db "from it, not from the region. It", 10
            db "exports in bulk (by rail from a", 10
            db "freight yard).", 0
s_wh_stock  db "Stock: ", 0
s_wh_of     db " of 200 loads", 0
s_wh_month  db "Last month in ", 0
s_wh_shops  db ", to shops ", 0
s_wh_exp    db ", exported ", 0

section .text

; a warehouse found by the census (edi its anchor; beta)
wh_note:
    mov eax, [wh_n]
    cmp eax, WH_MAX
    jge .o
    mov [wh_tile+rax*4], edi
    inc dword [wh_n]
.o: ret

; the nearest warehouse in reach of tile edi -> eax its anchor or -1;
; esi 1: one with goods, 2: one with room
FUNC wh_nearest
    mov r12d, edi
    mov r13d, -1
    mov r14d, WH_REACH+1
    mov r15d, esi
    xor ebx, ebx
.w:
    cmp ebx, [wh_n]
    jge .out
    mov eax, [wh_tile+rbx*4]
    shl eax, TILE_SHIFT
    test byte [tiles+rax+T_FLAGS], F_POWER
    jz .n
    movzx ecx, word [tiles+rax+T_POP]
    cmp r15d, 1
    jne .room
    test ecx, ecx
    jz .n
    jmp .d
.room:
    cmp ecx, WH_CAP
    jge .n
.d:
    mov edi, r12d
    mov esi, [wh_tile+rbx*4]
    call tile_dist
    cmp eax, r14d
    jge .n
    mov r14d, eax
    mov r13d, [wh_tile+rbx*4]
.n:
    inc ebx
    jmp .w
.out:
    mov eax, r13d
    RETURN

; factory edi would export a load: to a warehouse in reach instead?
; -> eax 1 if it goes there (beta)
FUNC wh_store, 16
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp dword [wh_n], 0
    je .out
    mov [rbp-48], edi
    mov esi, 2
    call wh_nearest
    cmp eax, -1
    je .no
    mov esi, eax
    mov edi, [rbp-48]
    mov edx, VT_TRUCK
    mov ecx, PU_STORE
    call make_trip
    mov eax, 1
    jmp .out
.no:
    xor eax, eax
.out:
    RETURN

; shop edi runs short: restocked from a warehouse in reach?
; -> eax 1 if so (beta)
FUNC wh_supply, 16
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    cmp dword [wh_n], 0
    je .out
    mov [rbp-48], edi
    mov esi, 1
    call wh_nearest
    cmp eax, -1
    je .no
    mov edi, eax
    shl eax, TILE_SHIFT
    dec word [tiles+rax+T_POP]
    inc dword [wh_out]
    mov esi, [rbp-48]
    mov edx, VT_TRUCK
    mov ecx, PU_GOODS
    call make_trip
    mov eax, 1
    jmp .out
.no:
    xor eax, eax
.out:
    RETURN

; a load arrived (rdi vehicle)
wh_arrive:
    mov eax, [rdi+V_DST]
    cmp eax, MAP_TILES
    jae .o
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_SERVICE
    jne .o
    ; (the anchor: the trip ends at the building)
    movzx ecx, byte [tiles+rax+T_ANCHOR]
    test ecx, ecx
    jz .a
    mov edx, [rdi+V_DST]
    mov r8d, ecx
    and r8d, 15
    sub edx, r8d
    shr ecx, 4
    shl ecx, MAP_SHIFT
    sub edx, ecx
    mov eax, edx
    shl eax, TILE_SHIFT
.a:
    cmp byte [tiles+rax+T_SUB], BK_WAREHOUSE
    jne .o
    cmp word [tiles+rax+T_POP], WH_CAP
    jge .o
    inc word [tiles+rax+T_POP]
    inc dword [wh_in]
.o: ret

; the day's bulk exports (beta)
FUNC wh_day, 16
    cmp dword [beta_on], 0
    je .out
    xor ebx, ebx
.w:
    cmp ebx, [wh_n]
    jge .out
    mov r12d, [wh_tile+rbx*4]
    mov eax, r12d
    shl eax, TILE_SHIFT
    test byte [tiles+rax+T_FLAGS], F_POWER
    jz .n
    movzx ecx, word [tiles+rax+T_POP]
    cmp ecx, WH_KEEP+4
    jl .n
    sub word [tiles+rax+T_POP], 4
    add dword [wh_bulk], 4
    ; by rail, from a freight yard on a line out
    mov edi, r12d
    call rail_export
    test eax, eax
    jz .road
    add dword [exports_month], 64
    add dword [goods_sold_month], 64
    jmp .n
.road:
    add dword [exports_month], 48
    add dword [goods_sold_month], 48
    mov edi, r12d
    call port_export
    test eax, eax
    jnz .n
    mov edi, r12d
    mov esi, -1
    mov edx, VT_TRUCK
    mov ecx, PU_EXPORT
    call make_trip
.n:
    inc ebx
    jmp .w
.out:
    RETURN

wh_month:
    cmp dword [beta_on], 0
    je .o
    mov eax, [wh_in]
    mov [wh_in_last], eax
    mov eax, [wh_out]
    mov [wh_out_last], eax
    mov eax, [wh_bulk]
    mov [wh_bulk_last], eax
    xor eax, eax
    mov [wh_in], eax
    mov [wh_out], eax
    mov [wh_bulk], eax
.o: ret

; a warehouse in the inspector (beta; rbx tile, r15d index)
FUNC wh_inspect, 16
    cmp dword [beta_on], 0
    je .out
    cmp byte [rbx+T_SUB], BK_WAREHOUSE
    jne .out
    ; the anchor's stock
    mov eax, r15d
    movzx ecx, byte [rbx+T_ANCHOR]
    mov edx, ecx
    and edx, 15
    sub eax, edx
    shr ecx, 4
    shl ecx, MAP_SHIFT
    sub eax, ecx
    shl eax, TILE_SHIFT
    movzx eax, word [tiles+rax+T_POP]
    mov [rbp-48], eax
    call tb_reset
    lea rdi, [s_wh_stock]
    call tb_str
    movsxd rdi, dword [rbp-48]
    call tb_num
    lea rdi, [s_wh_of]
    call tb_str
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
    call tb_reset
    lea rdi, [s_wh_month]
    call tb_str
    movsxd rdi, dword [wh_in_last]
    call tb_num
    lea rdi, [s_wh_shops]
    call tb_str
    movsxd rdi, dword [wh_out_last]
    call tb_num
    lea rdi, [s_wh_exp]
    call tb_str
    movsxd rdi, dword [wh_bulk_last]
    call tb_num
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call row_text
.out:
    RETURN

; ---------------------------------------------------------------------
;  the model
; ---------------------------------------------------------------------
FUNC bld_warehouse
    BEGIN 32, 30, 10500
    MAT M_ASPHALT
    BOX 0,0,0,32,32,1
    ; the shed
    MAT M_CREAM
    BOX 3,3,1,29,21,12
    MAT M_TEAL_METAL
    RFX 2,2,12,30,22,6
    ; loading doors
    MAT M_DARK
    BOX 6,21,1,10,22,8
    BOX 14,21,1,18,22,8
    BOX 22,21,1,26,22,8
    ; a lorry at the dock
    MAT M_WHITE
    BOX 14,23,1,18,29,7
    MAT M_RED
    BOX 14,29,1,18,31,6
    ; pallets
    MAT M_WOOD
    BOX 23,25,1,28,30,3
    BOX 24,26,3,27,29,5
    BOX 4,25,1,9,30,3
    call finish_model
    RETURN
