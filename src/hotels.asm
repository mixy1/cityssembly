; =====================================================================
;  HOTELS and INTERCITY (beta)
;
;  Tourists come by air (half the passengers), by train (visitors), and
;  for the sights (the Asm Tower, stadiums, plazas, wonders, intercity
;  stations).  Hotels (2x2) put them up: 1,200 guest nights a month each,
;  $3 a night, and shops are wanted for them.  Without hotels the city
;  sees little of their money.
;
;  The Intercity Station (3x3, from Megalopolis) is a railway station
;  for fast trains: on a line that reaches the map edge it brings
;  business (offices wanted) and 2,000 tourists a month.
; =====================================================================
HT_ROOMS    equ 1200            ; guest nights a month a hotel
HT_PRICE    equ 3

section .bss
tourists    resd 1              ; last month
guests      resd 1              ; of them, in hotels
ic_live     resd 1              ; intercity stations on a line out

section .data
nm_hotel    db "Hotel", 0
ds_hotel    db "Puts up tourists: $3 a night, 1,200 a month.", 0
hb_hotel    db "Tourists come by air, by train and", 10
            db "for the sights. Each hotel puts up", 10
            db "1,200 a month at $3 a night.", 0
nm_icstn    db "Intercity Station", 0
ds_icstn    db "Fast trains: business and tourists.", 0
hb_icstn    db "Next to railway track that reaches", 10
            db "the map edge: offices are wanted", 10
            db "and 2,000 tourists come a month.", 0
s_ht_line   db "Tourists last month: ", 0
s_ht_in     db ", in hotels: ", 0
s_ic_live   db "Fast trains to the region", 0
s_ic_dead   db "No line to the map edge: no fast trains", 0
s_st_tour   db "Tourists / month", 0

section .text

; the month's tourists, and what the hotels make (beta; before the
; income is summed)
FUNC hotels_month
    cmp dword [beta_on], 0
    je .out
    ; intercity stations on a line to the edge
    xor r12d, r12d
    xor ebx, ebx
.i:
    cmp ebx, [rl_n]
    jge .id
    movzx eax, word [rl_stn+rbx*2]
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_SUB], BK_ICSTN
    jne .in
    movzx eax, word [rl_snet+rbx*2]
    test eax, eax
    jz .in
    cmp word [rl_edge+rax*2], 0
    je .in
    inc r12d
.in:
    inc ebx
    jmp .i
.id:
    mov [ic_live], r12d
    ; the tourists
    mov eax, [air_pax]
    shr eax, 1
    imul ecx, [rail_visitors_last], 20
    add eax, ecx
    mov ecx, [svc_count+BK_LANDMARK*4]
    imul ecx, ecx, 800
    add eax, ecx
    mov ecx, [svc_count+BK_STADIUM*4]
    imul ecx, ecx, 400
    add eax, ecx
    mov ecx, [svc_count+BK_PLAZA*4]
    imul ecx, ecx, 50
    add eax, ecx
    mov ecx, BK_GCENTRAL
.w:
    mov edx, [svc_count+rcx*4]
    imul edx, edx, 1000
    add eax, edx
    inc ecx
    cmp ecx, BK_EXPO
    jle .w
    imul ecx, r12d, 2000
    add eax, ecx
    mov [tourists], eax
    ; the hotels' rooms
    mov ecx, [svc_count+BK_HOTEL*4]
    imul ecx, ecx, HT_ROOMS
    cmp eax, ecx
    jle .g
    mov eax, ecx
.g:
    mov [guests], eax
    imul ecx, eax, HT_PRICE
    add [exports_month], ecx
    ; shops for them, offices for the fast trains
    xor edx, edx
    mov ecx, 300
    div ecx
    CLAMP eax, 0, 15
    add [w_com], eax
    test r12d, r12d
    jz .out
    add dword [w_off], 10
.out:
    RETURN

; a hotel or an intercity station in the inspector (beta; rbx tile,
; r15d index)
FUNC hotel_inspect
    cmp dword [beta_on], 0
    je .out
    movzx eax, byte [rbx+T_SUB]
    cmp eax, BK_ICSTN
    je .ic
    cmp eax, BK_HOTEL
    jne .out
    call tb_reset
    lea rdi, [s_ht_line]
    call tb_str
    movsxd rdi, dword [tourists]
    call tb_num
    lea rdi, [s_ht_in]
    call tb_str
    movsxd rdi, dword [guests]
    call tb_num
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
    jmp .out
.ic:
    ; its line reaches the edge?
    xor ecx, ecx
.f:
    cmp ecx, [rl_n]
    jge .dead
    movzx eax, word [rl_stn+rcx*2]
    cmp eax, r15d
    je .have
    inc ecx
    jmp .f
.have:
    movzx eax, word [rl_snet+rcx*2]
    test eax, eax
    jz .dead
    cmp word [rl_edge+rax*2], 0
    je .dead
    lea rdx, [s_ic_live]
    mov ecx, UI_GOOD
    call row_text
    jmp .out
.dead:
    lea rdx, [s_ic_dead]
    mov ecx, UI_BAD
    call row_text
.out:
    RETURN

; ---------------------------------------------------------------------
;  models
; ---------------------------------------------------------------------
FUNC bld_hotel
    BEGIN 32, 60, 10100
    MAT M_CONCRETE
    BOX 0,0,0,32,32,1
    ; a pool
    MAT M_WATER
    BOX 3,22,1,13,29,2
    ; the tower
    MAT M_CREAM_WIN
    BOX 14,6,1,28,26,48
    MAT M_WHITE
    BOX 13,5,48,29,27,50
    ; the sign on top
    MAT M_RED
    BOX 17,15,50,25,16,56
    ; the lobby
    MAT M_GLASS
    BOX 12,24,1,30,30,6
    call finish_model
    RETURN

FUNC bld_icstn
    BEGIN 48, 40, 10200
    MAT M_CONCRETE
    BOX 0,0,0,48,48,2
    ; long platforms under a glass roof
    MAT M_WHITE
    BOX 4,6,2,44,10,4
    BOX 4,16,2,44,20,4
    MAT M_METAL
    BOX 4,4,4,6,22,16
    BOX 42,4,4,44,22,16
    MAT M_GLASS
    RFX 3,3,16,45,23,8
    ; the hall
    MAT M_WHITE_WIN
    BOX 6,26,2,42,44,18
    MAT M_BLUE
    RFX 5,25,18,43,45,5
    ; a sleek train at the platform
    MAT M_WHITE
    BOX 6,11,4,40,15,8
    MAT M_RED
    BOX 6,11,6,40,15,7
    MAT M_GLASS
    BOX 38,11,6,41,15,8
    call finish_model
    RETURN
