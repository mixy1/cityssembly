; =====================================================================
;  DEATHCARE (beta) - cemeteries and crematoriums
;
;  Every month about one in 400 people dies.  Cemeteries (3x3) take them
;  until they're full (6,000 graves each); crematoriums (2x2, powered)
;  take 200 a month and never fill.  Homes with neither within 30 tiles
;  are unhappy; when the city has more dead than it can take, everyone
;  is a little less happy and the city issues say so.
; =====================================================================
DC_REACH    equ 30
DC_GRAVES   equ 6000            ; a cemetery
DC_CREM     equ 200             ; a crematorium, a month
ISSUE_DEATH equ 13

section .bss
map_death   resb MAP_TILES      ; homes deathcare reaches
dc_short    resd 1              ; the dead it couldn't take last month
dc_deaths   resd 1              ; last month

section .data
nm_cemetery db "Cemetery", 0
ds_cemetery db "Graves for 6,000. Homes 30 tiles around served.", 0
nm_crem     db "Crematorium", 0
ds_crem     db "200 a month, never full. Homes 30 tiles around.", 0
hb_cemetery db "People die: homes want a cemetery", 10
            db "or crematorium within 30 tiles.", 10
            db "A cemetery fills up (6,000).", 0
hb_crem     db "Takes 200 a month and never fills", 10
            db "up. Needs power. Homes 30 tiles", 10
            db "around are served.", 0
s_dc_full   db "The cemeteries are full - build another, or a crematorium.", 0
s_dc_iss    db "Not enough deathcare", 0
s_dc_graves db "Graves: ", 0
s_dc_of     db " of ", 0
s_dc_month  db "Deaths last month: ", 0
s_dc_none   db "Deathcare: none within 30 tiles", 0

section .text

; homes deathcare reaches (beta; with the services' room)
FUNC death_update
    cmp dword [beta_on], 0
    je .out
    lea rdi, [map_death]
    mov ecx, MAP_TILES/8
    xor eax, eax
    rep stosq
    mov eax, [svc_count+BK_CEMETERY*4]
    add eax, [svc_count+BK_CREM*4]
    test eax, eax
    jz .out
    xor ebx, ebx
.s:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_SERVICE
    jne .sn
    test byte [tiles+rax+T_FLAGS], F_ANCHOR
    jz .sn
    movzx ecx, byte [tiles+rax+T_SUB]
    cmp ecx, BK_CEMETERY
    je .st
    cmp ecx, BK_CREM
    jne .sn
    test byte [tiles+rax+T_FLAGS], F_POWER
    jz .sn
.st:
    mov r12d, ebx
    and r12d, MAP_W-1
    inc r12d
    mov r13d, ebx
    shr r13d, MAP_SHIFT
    inc r13d
    mov r14d, -DC_REACH
.y:
    mov r15d, -DC_REACH
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
    cmp eax, DC_REACH
    jg .xn
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    cmp edi, MAP_W
    jae .xn
    cmp esi, MAP_W
    jae .xn
    shl esi, MAP_SHIFT
    add esi, edi
    mov byte [map_death+rsi], 1
.xn:
    inc r15d
    cmp r15d, DC_REACH
    jle .x
    inc r14d
    cmp r14d, DC_REACH
    jle .y
.sn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .s
.out:
    RETURN

; the month's dead (beta)
FUNC death_month
    cmp dword [beta_on], 0
    je .out
    mov eax, [population]
    xor edx, edx
    mov ecx, 400
    div ecx
    mov [dc_deaths], eax
    mov r12d, eax                   ; still to take
    ; crematoriums first
    mov eax, [svc_count+BK_CREM*4]
    imul eax, eax, DC_CREM
    sub r12d, eax
    jns .gr
    xor r12d, r12d
.gr:
    ; then graves, while there are any
    mov eax, [svc_count+BK_CEMETERY*4]
    imul eax, eax, DC_GRAVES
    ; (a cemetery that's gone takes its graves: never more than there's room)
    cmp [graves_used], eax
    jle .gc
    mov [graves_used], eax
.gc:
    mov ecx, eax
    sub ecx, [graves_used]
    jle .full
    cmp r12d, ecx
    jle .fit
    add [graves_used], ecx
    sub r12d, ecx
    jmp .full
.fit:
    add [graves_used], r12d
    xor r12d, r12d
    jmp .done
.full:
    ; say so once, when they fill
    test eax, eax
    jz .done
    cmp dword [dc_short], 0
    jne .done
    test r12d, r12d
    jz .done
    lea rdi, [s_dc_full]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
.done:
    mov [dc_short], r12d
.out:
    RETURN

; unhappiness from the dead, and the home's district (edi a home's
; tile) -> eax (beta)
death_penalty:
    push rdi
    call dist_unhappy
    pop rdi
    cmp dword [population], 2000
    jl .o
    cmp byte [map_death+rdi], 0
    jne .s
    add eax, 6
.s:
    cmp dword [dc_short], 20
    jl .o
    add eax, 4
.o: ret

; room left in the graves (for the inspector)
FUNC death_inspect
    cmp dword [beta_on], 0
    je .out
    movzx eax, byte [rbx+T_SUB]
    cmp eax, BK_CEMETERY
    je .c
    cmp eax, BK_CREM
    jne .out
    jmp .d
.c:
    call tb_reset
    lea rdi, [s_dc_graves]
    call tb_str
    movsxd rdi, dword [graves_used]
    call tb_num
    lea rdi, [s_dc_of]
    call tb_str
    mov eax, [svc_count+BK_CEMETERY*4]
    imul eax, eax, DC_GRAVES
    movsxd rdi, eax
    call tb_num
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call row_text
.d:
    call tb_reset
    lea rdi, [s_dc_month]
    call tb_str
    movsxd rdi, dword [dc_deaths]
    call tb_num
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call row_text
.out:
    RETURN

; ---------------------------------------------------------------------
;  models
; ---------------------------------------------------------------------
FUNC bld_cemetery
    BEGIN 48, 24, 9700
    MAT M_GRASS
    BOX 0,0,0,48,48,1
    ; a path
    MAT M_SAND
    BOX 22,0,1,26,48,1
    ; rows of headstones
    MAT M_CONCRETE
    xor ebx, ebx
.r:
    imul r12d, ebx, 6
    add r12d, 4
    xor r13d, r13d
.c:
    imul edi, r13d, 6
    add edi, 3
    cmp edi, 20
    jl .ok
    add edi, 7
.ok:
    cmp edi, 46
    jge .cn
    mov esi, r12d
    mov edx, 1
    lea ecx, [rdi+2]
    lea r8d, [rsi+1]
    mov r9d, 4
    call vbox
.cn:
    inc r13d
    cmp r13d, 8
    jl .c
    inc ebx
    cmp ebx, 6
    jl .r
    ; a chapel at the back
    MAT M_CREAM
    BOX 18,38,1,30,46,10
    MAT M_ROOF_GREY
    RFY 17,37,10,31,47,6
    MAT M_CREAM
    BOX 23,44,10,25,46,20
    ; cypress trees
    MAT M_LEAF
    BOX 2,40,1,5,43,14
    BOX 43,40,1,46,43,14
    call finish_model
    RETURN

FUNC bld_crem
    BEGIN 32, 34, 9800
    MAT M_CONCRETE
    BOX 0,0,0,32,32,1
    MAT M_CREAM_WIN
    BOX 4,6,1,28,26,12
    MAT M_ROOF_GREY
    RFX 3,5,12,29,27,6
    ; the chimney
    MAT M_BRICK
    BOX 22,18,1,26,22,30
    ; a garden in front
    MAT M_LEAF
    BOX 4,27,1,10,31,3
    BOX 22,27,1,28,31,3
    call finish_model
    RETURN

; is the deathcare line in the city issues up? -> eax 1
death_issue:
    xor eax, eax
    cmp dword [population], 2000
    jl .o
    cmp dword [dc_short], 20
    jge .y
    mov ecx, [svc_count+BK_CEMETERY*4]
    add ecx, [svc_count+BK_CREM*4]
    test ecx, ecx
    jnz .o
.y: mov eax, 1
.o: ret
