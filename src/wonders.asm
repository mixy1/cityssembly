; =====================================================================
;  WONDERS (beta) - World City (50,000) and Global City (80,000), and
;  the great buildings they unlock: one of each, each with something
;  the city must have first, each doing something no other building does
;
;  Grand Central Station  50,000  1,000 train riders a month and a metro
;                                 -> trains and the metro draw more
;                                    riders (their trips cost less)
;  Stock Exchange         50,000  an airport flying jets, 4,000 office jobs
;                                 -> offices wanted, and a share of their
;                                    trade every month
;  Opera House            50,000  a City Hall and a Stadium
;                                 -> a great park: land value and
;                                    happiness far around it
;  Space Centre           80,000  two universities
;                                 -> offices and hi-tech wanted, and a
;                                    launch every summer that pays
;  Expo Centre            80,000  5,000 air passengers a month
;                                 -> visitors spend: money and shops
; =====================================================================
TE_ONLYONE  equ 8
TE_WGC      equ 9
TE_WEX      equ 10
TE_WOP      equ 11
TE_WSP      equ 12
TE_WXP      equ 13

section .bss
w_off       resd 1              ; offices wanted because of wonders
w_com       resd 1              ; shops wanted

section .data
nm_gcentral db "Grand Central", 0
nm_exchange db "Stock Exchange", 0
nm_opera    db "Opera House", 0
nm_space    db "Space Centre", 0
nm_expo     db "Expo Centre", 0
ds_gcentral db "Wonder: more people ride trains and the metro.", 0
ds_exchange db "Wonder: offices wanted, and their trade pays.", 0
ds_opera    db "Wonder: land value and happiness far around.", 0
ds_space    db "Wonder: hi-tech wanted, a launch every summer.", 0
ds_expo     db "Wonder: visitors from everywhere spend here.", 0
hb_gcentral db "Needs 1,000 train riders a month", 10
            db "and a metro line. One per city.", 0
hb_exchange db "Needs an airport flying jets and", 10
            db "4,000 office jobs. One per city.", 0
hb_opera    db "Needs a City Hall and a Stadium.", 10
            db "One per city.", 0
hb_space    db "Needs two universities.", 10
            db "One per city.", 0
hb_expo     db "Needs 5,000 air passengers a", 10
            db "month. One per city.", 0
s_te_one    db "There can be only one of these.", 0
s_te_wgc    db "Needs 1,000 train riders a month and a metro line.", 0
s_te_wex    db "Needs an airport flying jets and 4,000 office jobs.", 0
s_te_wop    db "Needs a City Hall and a Stadium.", 0
s_te_wsp    db "Needs two universities.", 0
s_te_wxp    db "Needs 5,000 air passengers a month.", 0
s_launch    db "Launch! The Space Centre's rocket is up - $15,000 from the contract.", 0
ms10        db "World City", 0
ms11        db "Global City", 0

section .text

; can wonder edi be built? -> eax 0, or a TE_ reason (beta)
FUNC wonder_check
    xor eax, eax
    cmp edi, BK_GCENTRAL
    jb .out
    cmp edi, BK_EXPO
    ja .out
    mov eax, TE_ONLYONE
    cmp dword [svc_count+rdi*4], 0
    jne .out
    cmp edi, BK_GCENTRAL
    jne .ex
    mov eax, TE_WGC
    cmp dword [train_riders], 1000
    jl .out
    cmp dword [metro_riders], 1
    jl .out
    jmp .ok
.ex:
    cmp edi, BK_EXCHANGE
    jne .op
    mov eax, TE_WEX
    cmp dword [jobs+ZC_OFF*4], 4000
    jl .out
    xor ecx, ecx
.ap:
    cmp ecx, [ap_n]
    jge .out
    cmp byte [ap_live+rcx], 2
    je .ok
    inc ecx
    jmp .ap
.op:
    cmp edi, BK_OPERA
    jne .sp
    mov eax, TE_WOP
    cmp dword [svc_count+BK_CITYHALL*4], 0
    je .out
    cmp dword [svc_count+BK_STADIUM*4], 0
    je .out
    jmp .ok
.sp:
    cmp edi, BK_SPACE
    jne .xp
    mov eax, TE_WSP
    cmp dword [svc_count+BK_UNIV*4], 2
    jl .out
    jmp .ok
.xp:
    mov eax, TE_WXP
    cmp dword [air_pax], 5000
    jl .out
.ok:
    xor eax, eax
.out:
    RETURN

; the wonders' month (beta; before the income is summed)
FUNC wonders_month
    cmp dword [beta_on], 0
    je .out
    mov dword [w_off], 0
    mov dword [w_com], 0
    cmp dword [svc_count+BK_EXCHANGE*4], 0
    je .n1
    add dword [w_off], 12
    mov eax, [jobs+ZC_OFF*4]
    shr eax, 1
    add [exports_month], eax
.n1:
    cmp dword [svc_count+BK_SPACE*4], 0
    je .n2
    add dword [w_off], 8
    ; a launch every summer
    cmp dword [month], 6
    jne .n2
    call space_launch
.n2:
    cmp dword [svc_count+BK_EXPO*4], 0
    je .out
    add dword [w_com], 15
    add dword [exports_month], 8000
.out:
    RETURN

FUNC space_launch
    add dword [exports_month], 15000
    ; smoke and fire at the pad
    xor ebx, ebx
.f:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_SERVICE
    jne .fn
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .fn
    cmp byte [tiles+rax+T_SUB], BK_SPACE
    je .have
.fn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .f
    RETURN
.have:
    mov r12d, ebx
    and r12d, MAP_W-1
    inc r12d
    mov r13d, ebx
    shr r13d, MAP_SHIFT
    inc r13d
    mov edi, r12d
    mov esi, r13d
    mov edx, 40
    mov ecx, PK_SMOKE
    mov r8d, 2
    call fx_burst
    mov edi, r12d
    mov esi, r13d
    mov edx, 30
    mov ecx, PK_SPARK
    mov r8d, 20
    call fx_burst
    lea rdi, [s_launch]
    mov esi, UI_GOLD
    mov edx, r12d
    mov ecx, r13d
    call notify
    RETURN

; a trip by train or metro costs less with Grand Central (eax cost)
gc_cheaper:
    cmp dword [svc_count+BK_GCENTRAL*4], 0
    je .o
    lea eax, [rax+rax*2]
    shr eax, 2
.o: ret

; ---------------------------------------------------------------------
;  the models
; ---------------------------------------------------------------------
FUNC bld_gcentral
    BEGIN 48, 48, 9100
    MAT M_CONCRETE
    BOX 0,0,0,48,48,1
    ; the hall
    MAT M_CREAM_WIN
    BOX 4,6,1,44,40,18
    MAT M_GLASS
    RFX 3,5,18,45,41,12
    ; the front, with columns
    MAT M_WHITE
    BOX 6,40,1,42,44,3
    BOX 8,41,3,10,43,16
    BOX 14,41,3,16,43,16
    BOX 32,41,3,34,43,16
    BOX 38,41,3,40,43,16
    BOX 6,40,16,42,44,19
    ; the clock tower
    MAT M_CREAM
    BOX 19,36,1,29,46,40
    MAT M_WHITE
    BOX 21,45,28,27,46,34
    MAT M_DARK
    BOX 23,45,30,25,46,32
    MAT M_ROOF_GREY
    PYR 18,35,40,30,47,8
    call finish_model
    RETURN

FUNC bld_exchange
    BEGIN 32, 34, 9200
    MAT M_CONCRETE
    BOX 0,0,0,32,32,2
    MAT M_WHITE
    BOX 2,22,2,30,30,3
    ; the body
    MAT M_CREAM_WIN
    BOX 4,3,2,28,22,20
    ; columns and the pediment
    MAT M_WHITE
    BOX 5,24,3,7,26,18
    BOX 10,24,3,12,26,18
    BOX 15,24,3,17,26,18
    BOX 20,24,3,22,26,18
    BOX 25,24,3,27,26,18
    BOX 3,22,18,29,28,21
    RFX 3,22,21,29,28,6
    ; a flag
    MAT M_METAL
    BOX 15,10,20,16,11,32
    MAT M_RED
    BOX 16,10,28,21,11,32
    call finish_model
    RETURN

FUNC bld_opera
    BEGIN 48, 40, 9300
    MAT M_CREAM
    BOX 0,0,0,48,48,3
    MAT M_GLASS
    BOX 6,10,3,42,38,8
    ; white sails, one behind the other, smaller as they go
    MAT M_WHITE
    PYR 4,10,8,22,38,26
    PYR 18,12,8,34,36,20
    PYR 30,14,8,42,34,14
    ; the steps down to the water
    MAT M_CREAM
    BOX 42,14,0,48,34,2
    call finish_model
    RETURN

FUNC bld_space
    BEGIN 48, 96, 9400
    MAT M_CONCRETE
    BOX 0,0,0,48,48,1
    ; the pad and its tower
    MAT M_DARK
    BOX 6,6,1,24,24,3
    MAT M_RED
    BOX 20,12,3,23,15,62
    BOX 14,12,50,20,14,52
    BOX 14,12,34,20,14,36
    ; the rocket
    MAT M_WHITE
    CYL 30,30,3,6,58
    MAT M_DARK
    CYL 30,30,40,6,44
    MAT M_WHITE
    CONE 30,30,58,6,10
    MAT M_ORANGE
    CYL 24,30,3,3,24
    CYL 36,30,3,3,24
    ; mission control and a dish
    MAT M_WHITE_WIN
    BOX 28,28,1,46,46,12
    MAT M_WHITE
    SPH 74,74,34,8
    call finish_model
    RETURN

FUNC bld_expo
    BEGIN 48, 52, 9500
    MAT M_CONCRETE
    BOX 0,0,0,48,48,2
    ; legs
    MAT M_METAL
    BOX 14,14,2,16,16,16
    BOX 32,14,2,34,16,16
    BOX 14,32,2,16,34,16
    BOX 32,32,2,34,34,16
    ; the sphere
    MAT M_GLASS
    SPH 48,48,62,30
    ; flags round it
    MAT M_RED
    BOX 2,2,2,3,3,12
    MAT M_BLUE
    BOX 45,2,2,46,3,12
    MAT M_YELLOW
    BOX 2,45,2,3,46,12
    MAT M_TEAL
    BOX 45,45,2,46,46,12
    call finish_model
    RETURN

; a water treatment plant: settling tanks and a works building
FUNC bld_treat
    BEGIN 32, 20, 9600
    MAT M_CONCRETE
    BOX 0,0,0,32,32,1
    ; round tanks
    MAT M_CONCRETE
    CYL 18,18,1,14,5
    CYL 46,18,1,14,5
    CYL 18,46,1,14,5
    MAT M_WATER
    CYL 18,18,4,12,5
    CYL 46,18,4,12,5
    CYL 18,46,4,12,5
    ; the works
    MAT M_WHITE_WIN
    BOX 18,18,1,30,30,10
    MAT M_BLUE
    RFX 17,17,10,31,31,4
    call finish_model
    RETURN
