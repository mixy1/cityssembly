; =====================================================================
;  FERRIES (beta) - piers on the shore, boats between them
;
;  A Pier (1x1, touching water) joins the other piers on the same water
;  (a lake, the river, the sea).  People within 6 tiles of a pier whose
;  trip ends near another pier on that water may take the ferry - no
;  traffic, 3,000 a month per pier.  Ferries sail between the piers.
; =====================================================================
FE_MAX      equ 32              ; piers
FE_REACH    equ 6
FE_CAP      equ 3000
FB_MAX      equ 6               ; ferries
FB_PATH     equ 320
FB_SPEED    equ 14
TM_FERRY    equ 6

section .bss
fe_n        resd 1
fe_tile     resw FE_MAX         ; the pier
fe_water    resw FE_MAX         ; the water tile beside it
fe_comp     resw FE_MAX         ; its water
fe_wcomp    resw MAP_TILES      ; water bodies
fe_near     resb MAP_TILES      ; the nearest pier (+1)
fe_dist     resb MAP_TILES
ferry_riders_month resd 1
ferry_riders resd 1
; the boats
fb_on       resb FB_MAX         ; 0 none, 1 sailing, 2 at a pier
fb_len      resw FB_MAX
fb_pos      resw FB_MAX
fb_prog     resd FB_MAX
fb_wait     resd FB_MAX
fb_path     resw FB_MAX*FB_PATH
spr_ferry   resd 4

section .data
nm_pier     db "Ferry Pier", 0
ds_pier     db "Ferries to other piers on the same water.", 0
hb_pier     db "Touching water. People near it", 10
            db "take ferries to places near other", 10
            db "piers on the same water.", 0
s_fe_on     db "Piers on this water: ", 0
s_st_ferry  db "Ferry riders / month", 0

section .text

; piers, their water, and who's near one (with the other networks)
FUNC ferry_update, 16
    cmp dword [beta_on], 0
    je .out
    mov dword [fe_n], 0
    cmp dword [svc_count+BK_PIER*4], 0
    je .out
    ; water bodies
    lea rdi, [fe_wcomp]
    mov ecx, MAP_TILES/4
    xor eax, eax
    rep stosq
    xor r15d, r15d
    xor ebx, ebx
.w:
    cmp word [fe_wcomp+rbx*2], 0
    jne .wn
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_TERRAIN], TER_WATER
    jne .wn
    inc r15d
    mov [fe_wcomp+rbx*2], r15w
    mov [wx_queue], bx
    xor r12d, r12d
    mov r13d, 1
.q:
    cmp r12d, r13d
    jge .wn
    movzx r14d, word [wx_queue+r12*2]
    inc r12d
    xor ecx, ecx
.d:
    mov edi, r14d
    and edi, MAP_W-1
    mov esi, r14d
    shr esi, MAP_SHIFT
    add edi, [dir_dx+rcx*4]
    add esi, [dir_dy+rcx*4]
    cmp edi, MAP_W
    jae .dn
    cmp esi, MAP_W
    jae .dn
    shl esi, MAP_SHIFT
    add esi, edi
    cmp word [fe_wcomp+rsi*2], 0
    jne .dn
    mov eax, esi
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_TERRAIN], TER_WATER
    jne .dn
    mov [fe_wcomp+rsi*2], r15w
    mov [wx_queue+r13*2], si
    inc r13d
.dn:
    inc ecx
    cmp ecx, 4
    jl .d
    jmp .q
.wn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .w
    ; the piers
    xor ebx, ebx
.p:
    mov eax, ebx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_SERVICE
    jne .pn
    cmp byte [tiles+rax+T_SUB], BK_PIER
    jne .pn
    mov r12d, [fe_n]
    cmp r12d, FE_MAX
    jge .reach
    ; the water beside it
    xor ecx, ecx
.pw:
    mov edi, ebx
    and edi, MAP_W-1
    mov esi, ebx
    shr esi, MAP_SHIFT
    add edi, [dir_dx+rcx*4]
    add esi, [dir_dy+rcx*4]
    cmp edi, MAP_W
    jae .pwn
    cmp esi, MAP_W
    jae .pwn
    shl esi, MAP_SHIFT
    add esi, edi
    movzx eax, word [fe_wcomp+rsi*2]
    test eax, eax
    jz .pwn
    mov [fe_tile+r12*2], bx
    mov [fe_water+r12*2], si
    mov [fe_comp+r12*2], ax
    inc dword [fe_n]
    jmp .pn
.pwn:
    inc ecx
    cmp ecx, 4
    jl .pw
.pn:
    inc ebx
    cmp ebx, MAP_TILES
    jl .p
.reach:
    lea rdi, [fe_near]
    mov ecx, MAP_TILES/8
    xor eax, eax
    rep stosq
    lea rdi, [fe_dist]
    mov ecx, MAP_TILES/8
    mov rax, -1
    rep stosq
    xor ebx, ebx
.r:
    cmp ebx, [fe_n]
    jge .out
    movzx eax, word [fe_tile+rbx*2]
    mov r12d, eax
    and r12d, MAP_W-1
    mov r13d, eax
    shr r13d, MAP_SHIFT
    mov r14d, -FE_REACH
.y:
    mov r15d, -FE_REACH
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
    cmp eax, FE_REACH
    jg .xn
    lea edi, [r12+r15]
    lea esi, [r13+r14]
    cmp edi, MAP_W
    jae .xn
    cmp esi, MAP_W
    jae .xn
    shl esi, MAP_SHIFT
    add esi, edi
    cmp al, [fe_dist+rsi]
    jae .xn
    mov [fe_dist+rsi], al
    lea ecx, [rbx+1]
    mov [fe_near+rsi], cl
.xn:
    inc r15d
    cmp r15d, FE_REACH
    jle .x
    inc r14d
    cmp r14d, FE_REACH
    jle .y
    inc ebx
    jmp .r
.out:
    RETURN

; a ferry trip between buildings r12d and r13d (r14d tiles apart)
; -> eax cost or -1
ferry_trip_cost:
    movzx eax, byte [fe_near+r12]
    movzx ecx, byte [fe_near+r13]
    test eax, eax
    jz .no
    test ecx, ecx
    jz .no
    cmp eax, ecx
    je .no
    movzx edx, word [fe_comp+rax*2-2]
    cmp dx, [fe_comp+rcx*2-2]
    jne .no
    mov edx, [fe_n]
    imul edx, edx, FE_CAP
    cmp [ferry_riders_month], edx
    jge .no
    movzx eax, byte [fe_dist+r12]
    movzx ecx, byte [fe_dist+r13]
    add eax, ecx
    imul eax, eax, 10
    lea eax, [rax+r14*4]
    add eax, r14d                   ; (5 a tile on the water)
    add eax, 40                     ; the wait
    ret
.no:
    mov eax, -1
    ret

ferry_month:
    cmp dword [beta_on], 0
    je .o
    mov eax, [ferry_riders_month]
    mov [ferry_riders], eax
    mov dword [ferry_riders_month], 0
.o: ret

; ---------------------------------------------------------------------
;  the boats
; ---------------------------------------------------------------------
; the way over water from pier edi's water to pier esi's -> boat ebx's
; path; eax its length (0: none)
FUNC ferry_path, 16
    movzx r12d, word [fe_water+rdi*2]   ; from
    movzx r13d, word [fe_water+rsi*2]   ; to
    inc dword [pt_gen]
    mov r14d, [pt_gen]
    mov [pt_seen+r12*4], r14d
    mov byte [pt_from+r12], 255
    mov [pt_queue], r12w
    xor ecx, ecx                    ; head
    mov dword [rbp-48], 1           ; tail
.q:
    cmp ecx, [rbp-48]
    jge .none
    movzx r15d, word [pt_queue+rcx*2]
    inc ecx
    cmp r15d, r13d
    je .found
    xor edx, edx
.d:
    mov edi, r15d
    and edi, MAP_W-1
    mov esi, r15d
    shr esi, MAP_SHIFT
    add edi, [dir_dx+rdx*4]
    add esi, [dir_dy+rdx*4]
    cmp edi, MAP_W
    jae .dn
    cmp esi, MAP_W
    jae .dn
    shl esi, MAP_SHIFT
    add esi, edi
    cmp [pt_seen+rsi*4], r14d
    je .dn
    mov eax, esi
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_TERRAIN], TER_WATER
    jne .dn
    mov [pt_seen+rsi*4], r14d
    mov [pt_from+rsi], dl
    mov eax, [rbp-48]
    mov [pt_queue+rax*2], si
    inc dword [rbp-48]
.dn:
    inc edx
    cmp edx, 4
    jl .d
    jmp .q
.found:
    ; back from the far pier to the near one, then turned round
    imul eax, ebx, FB_PATH*2
    lea r12, [fb_path+rax]
    xor ecx, ecx
.b:
    cmp ecx, FB_PATH
    jge .rev
    mov [r12+rcx*2], r15w
    inc ecx
    movzx eax, byte [pt_from+r15]
    cmp eax, 255
    je .rev
    mov edi, r15d
    and edi, MAP_W-1
    mov esi, r15d
    shr esi, MAP_SHIFT
    sub edi, [dir_dx+rax*4]
    sub esi, [dir_dy+rax*4]
    shl esi, MAP_SHIFT
    lea r15d, [rsi+rdi]
    jmp .b
.rev:
    ; (it was written far to near: turn it round)
    mov eax, ecx
    xor edx, edx
    lea r8d, [rcx-1]
.rv:
    cmp edx, r8d
    jge .rd
    movzx r9d, word [r12+rdx*2]
    movzx r10d, word [r12+r8*2]
    mov [r12+rdx*2], r10w
    mov [r12+r8*2], r9w
    inc edx
    dec r8d
    jmp .rv
.rd:
    RETURN
.none:
    xor eax, eax
    RETURN

; a traffic step (beta): boats sail, wait at the pier, sail again
FUNC ferries_update
    cmp dword [beta_on], 0
    je .out
    cmp dword [fe_n], 2
    jl .clear
    xor ebx, ebx
.b:
    movzx eax, byte [fb_on+rbx]
    test eax, eax
    jnz .has
    ; a new crossing: two piers on the same water
    mov edi, [fe_n]
    call rand_range
    mov r12d, eax
    mov edi, [fe_n]
    call rand_range
    cmp eax, r12d
    je .bn
    movzx ecx, word [fe_comp+r12*2]
    cmp cx, [fe_comp+rax*2]
    jne .bn
    mov edi, r12d
    mov esi, eax
    call ferry_path
    cmp eax, 2
    jl .bn
    mov [fb_len+rbx*2], ax
    mov word [fb_pos+rbx*2], 0
    mov dword [fb_prog+rbx*4], 0
    mov byte [fb_on+rbx], 1
    jmp .bn
.has:
    cmp eax, 2
    je .wait
    add dword [fb_prog+rbx*4], FB_SPEED
    cmp dword [fb_prog+rbx*4], 256
    jl .bn
    sub dword [fb_prog+rbx*4], 256
    inc word [fb_pos+rbx*2]
    movzx eax, word [fb_pos+rbx*2]
    movzx ecx, word [fb_len+rbx*2]
    dec ecx
    cmp eax, ecx
    jl .bn
    mov [fb_pos+rbx*2], cx
    mov dword [fb_prog+rbx*4], 0
    mov byte [fb_on+rbx], 2
    mov dword [fb_wait+rbx*4], 300
    jmp .bn
.wait:
    dec dword [fb_wait+rbx*4]
    jg .bn
    mov byte [fb_on+rbx], 0
.bn:
    inc ebx
    cmp ebx, FB_MAX
    jl .b
    RETURN
.clear:
    lea rdi, [fb_on]
    mov ecx, FB_MAX
    xor eax, eax
    rep stosb
.out:
    RETURN

FUNC draw_ferries, 16
    cmp dword [beta_on], 0
    je .out
    xor ebx, ebx
.b:
    cmp byte [fb_on+rbx], 0
    je .bn
    imul eax, ebx, FB_PATH*2
    lea r14, [fb_path+rax]
    movzx r12d, word [fb_pos+rbx*2]
    movzx r13d, word [r14+r12*2]
    movzx ecx, word [fb_len+rbx*2]
    lea eax, [r12+1]
    mov dword [rbp-48], 1
    cmp eax, ecx
    jge .hd0
    movzx esi, word [r14+rax*2]
    mov edi, r13d
    call tile_heading
    mov [rbp-48], eax
    jmp .hd
.hd0:
    test r12d, r12d
    jz .hd
    movzx edi, word [r14+r12*2-2]
    mov esi, r13d
    call tile_heading
    mov [rbp-48], eax
.hd:
    mov ecx, [rbp-48]
    mov edi, r13d
    and edi, MAP_W-1
    shl edi, 8
    add edi, 128
    mov esi, r13d
    shr esi, MAP_SHIFT
    shl esi, 8
    add esi, 128
    mov eax, [fb_prog+rbx*4]
    mov edx, [dir_dx+rcx*4]
    imul edx, eax
    add edi, edx
    mov edx, [dir_dy+rcx*4]
    imul edx, eax
    add esi, edx
    sub edi, 8*16
    sub esi, 8*16
    mov edx, 16
    call world_proj
    cmp eax, -40
    jl .bn
    mov r8d, [fb_w]
    add r8d, 40
    cmp eax, r8d
    jg .bn
    cmp edx, -40
    jl .bn
    mov r8d, [fb_h]
    add r8d, 40
    cmp edx, r8d
    jg .bn
    mov r8d, [rbp-48]
    mov edi, [spr_ferry+r8*4]
    mov esi, eax
    lea r8, [remap_identity]
    call blit_sprite
.bn:
    inc ebx
    cmp ebx, FB_MAX
    jl .b
.out:
    RETURN

ferries_reset:
    push rdi
    push rcx
    mov dword [fe_n], 0
    lea rdi, [fb_on]
    mov ecx, FB_MAX
    xor eax, eax
    rep stosb
    pop rcx
    pop rdi
    ret

; a pier in the inspector (beta; rbx tile, r15d index)
FUNC ferry_inspect
    cmp dword [beta_on], 0
    je .out
    cmp byte [rbx+T_SUB], BK_PIER
    jne .out
    xor ecx, ecx
.f:
    cmp ecx, [fe_n]
    jge .out
    movzx eax, word [fe_tile+rcx*2]
    cmp eax, r15d
    je .have
    inc ecx
    jmp .f
.have:
    movzx r12d, word [fe_comp+rcx*2]
    xor r13d, r13d
    xor ecx, ecx
.c:
    cmp ecx, [fe_n]
    jge .cd
    cmp [fe_comp+rcx*2], r12w
    jne .cn
    inc r13d
.cn:
    inc ecx
    jmp .c
.cd:
    call tb_reset
    lea rdi, [s_fe_on]
    call tb_str
    movsxd rdi, r13d
    call tb_num
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    cmp r13d, 2
    jge .t
    mov ecx, UI_WARN
.t:
    call row_text
.out:
    RETURN

; ---------------------------------------------------------------------
;  models: a pier, a ferry
; ---------------------------------------------------------------------
FUNC bld_pier
    BEGIN 16, 16, 10300
    MAT M_WOOD
    BOX 0,0,0,16,16,2
    MAT M_DARK
    BOX 1,1,0,3,3,4
    BOX 13,1,0,15,3,4
    BOX 1,13,0,3,15,4
    BOX 13,13,0,15,15,4
    ; a shelter
    MAT M_WHITE
    BOX 4,4,2,12,12,8
    MAT M_BLUE
    PYR 3,3,8,13,13,4
    call finish_model
    RETURN

FUNC gen_ferry
    mov [car_dir], edi
    lea eax, [rdi+10400]
    BEGIN 16, 10, eax
    MAT M_WHITE
    CBOX 1,4,0,15,12,3
    MAT M_BLUE
    CBOX 1,4,0,15,12,1
    MAT M_WHITE
    CBOX 4,5,3,12,11,6
    MAT M_GLASS
    CBOX 4,5,4,12,11,5
    MAT M_YELLOW
    CBOX 7,7,6,9,9,8
    call finish_model
    RETURN

FUNC ferry_sprites_init
    xor ebx, ebx
.s:
    mov edi, ebx
    call gen_ferry
    mov [spr_ferry+rbx*4], eax
    inc ebx
    cmp ebx, 4
    jl .s
    RETURN
