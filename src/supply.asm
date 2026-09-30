; =====================================================================
;  SUPPLY (beta) - raw materials, and what they're worth
;
;  Farms, forestry and mines (industry on fertile land, forest or ore)
;  send raw materials by truck to the factories (the other industry).
;  A factory with no materials works at half speed; with enough, at
;  full.  When the city has no farms, forests or mines, the materials
;  come from the region instead - more trucks in from the highway.
;  Exports fetch more for what the factories made ($16 a truck) than
;  for raw materials ($8): working them up pays.
; =====================================================================
PU_RAW      equ 12
RAW_LOAD    equ 60              ; a truck of materials

section .bss
map_raw     resb MAP_TILES      ; a factory's materials in stock
raw_month   resd 1
raw_last    resd 1

section .data
s_su_raw    db "Raw materials: ", 0
s_su_send   db "Sends raw materials to factories", 0
s_st_raw    db "Raw materials delivered / month", 0

section .text

; a factory's day's work (rbx its tile, ecx what it would make)
; -> ecx what it makes (beta: half without materials)
raw_production:
    cmp dword [beta_on], 0
    je .o
    cmp byte [rbx+T_SUB], 0
    jne .o
    push rax
    push rdx
    mov rax, rbx
    sub rax, tiles
    shr eax, TILE_SHIFT
    movzx edx, byte [map_raw+rax]
    push rax
    mov eax, edx
    CLAMP eax, 0, 128
    add eax, 128
    imul ecx, eax
    shr ecx, 8
    jnz .n
    inc ecx
.n:
    pop rax
    sub edx, ecx
    jns .s
    xor edx, edx
.s:
    mov [map_raw+rax], dl
    pop rdx
    pop rax
.o: ret

; a truck of raw materials to a factory short of them (beta traffic)
; -> eax 1 if a trip was made
FUNC raw_trip, 16
    xor eax, eax
    cmp dword [n_ind], 0
    je .out
    ; a factory running low
    mov r12d, -1
    mov ebx, 4
.f:
    lea rdi, [list_ind]
    mov esi, [n_ind]
    call pick_from
    cmp eax, -1
    je .fn
    mov ecx, eax
    shl ecx, TILE_SHIFT
    cmp byte [tiles+rcx+T_SUB], 0
    jne .fn
    cmp byte [map_raw+rax], 160
    jae .fn
    mov r12d, eax
    jmp .src
.fn:
    dec ebx
    jnz .f
    xor eax, eax
    jmp .out
.src:
    ; the nearest farm, forest or mine with a load ready (of a few)
    mov r13d, -1
    mov dword [rbp-48], 0x7FFFFFFF
    mov ebx, 6
.r:
    lea rdi, [list_ind]
    mov esi, [n_ind]
    call pick_from
    cmp eax, -1
    je .rn
    mov r14d, eax
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_SUB], 0
    je .rn
    cmp byte [tiles+rax+T_GOODS], 40
    jb .rn
    mov edi, r14d
    mov esi, r12d
    call tile_dist
    cmp eax, [rbp-48]
    jge .rn
    mov [rbp-48], eax
    mov r13d, r14d
.rn:
    dec ebx
    jnz .r
    cmp r13d, -1
    je .import
    mov eax, r13d
    shl eax, TILE_SHIFT
    sub byte [tiles+rax+T_GOODS], 40
    mov edi, r13d
    jmp .go
.import:
    ; none: from the region
    mov edi, -1
.go:
    mov esi, r12d
    mov edx, VT_TRUCK
    mov ecx, PU_RAW
    call make_trip
    mov eax, 1
.out:
    RETURN

; a truck of materials arrived (rdi vehicle)
raw_arrive:
    mov eax, [rdi+V_DST]
    cmp eax, MAP_TILES
    jae .o
    movzx ecx, byte [map_raw+rax]
    add ecx, RAW_LOAD
    CLAMP ecx, 0, 255
    mov [map_raw+rax], cl
    inc dword [raw_month]
.o: ret

; an export truck arrived (rdi vehicle): raw materials fetch less,
; what factories made more (beta)
export_value:
    cmp dword [beta_on], 0
    je .o
    mov eax, [rdi+V_HOME]
    cmp eax, MAP_TILES
    jae .o
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ZONEBLD
    jne .o
    cmp byte [tiles+rax+T_ZONE], ZONE_I
    jne .o
    mov ecx, 4
    cmp byte [tiles+rax+T_SUB], 0
    je .a
    neg ecx
.a:
    add [exports_month], ecx
    add [goods_sold_month], ecx
.o: ret

raw_month_end:
    cmp dword [beta_on], 0
    je .o
    mov eax, [raw_month]
    mov [raw_last], eax
    mov dword [raw_month], 0
.o: ret

; an industry in the inspector (beta; rbx tile, r15d index)
FUNC supply_inspect
    cmp dword [beta_on], 0
    je .out
    cmp byte [rbx+T_OBJ], OBJ_ZONEBLD
    jne .out
    cmp byte [rbx+T_ZONE], ZONE_I
    jne .out
    cmp byte [rbx+T_SUB], 0
    je .fac
    lea rdx, [s_su_send]
    mov ecx, UI_DIM
    call row_text
    jmp .out
.fac:
    call tb_reset
    lea rdi, [s_su_raw]
    call tb_str
    movzx eax, byte [map_raw+r15]
    CLAMP eax, 0, 128
    imul eax, eax, 100
    shr eax, 7
    movsxd rdi, eax
    call tb_pct
    mov ecx, UI_GOOD
    cmp byte [map_raw+r15], 40
    jae .c
    mov ecx, UI_WARN
.c:
    lea rdx, [textbuf]
    call row_text
.out:
    RETURN
