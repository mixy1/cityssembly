; =====================================================================
;  BLUEPRINTS (beta) - copy a piece of the city, stamp it elsewhere
;
;  Ctrl+C, then drag a rectangle (up to 32x32): its roads, zones, pipes
;  and trees are copied (not the buildings - the zones grow them again).
;  Then the copy follows the cursor: click to stamp it (paying for what
;  it lays), R to turn it, Ctrl+V to pick it up again later.
; =====================================================================
BP_MAX      equ 32

section .bss
bp_w        resd 1
bp_h        resd 1
bp_rot      resd 1
bp_road     resb BP_MAX*BP_MAX  ; road type + 1, 0 none
bp_zone     resb BP_MAX*BP_MAX
bp_flags    resb BP_MAX*BP_MAX  ; 1 pipe, 2 tree
bp_cell     resw MAX_TL         ; the cell each tool tile stamps

section .data
ti_copy     db "Copy", 0
hx_copy     db "Drag over a piece of the city to", 10
            db "copy its roads, zones, pipes and", 10
            db "trees (up to 32x32).", 0
ti_paste    db "Paste", 0
hx_paste    db "Click to stamp the copy.", 10
            db 7, "R turns it. Buildings aren't", 10
            db 7, "copied: the zones grow them.", 0
s_bp_done   db "Copied - click to paste it, R to turn it.", 0
s_bp_none   db "Nothing copied yet: Ctrl+C and drag over the city.", 0

section .text

; Ctrl+C / Ctrl+V (beta; from the keys)
bp_key_copy:
    mov dword [tool], T_COPY
    mov dword [submenu], -1
    ret

bp_key_paste:
    cmp dword [bp_w], 0
    je .none
    mov dword [tool], T_PASTE
    mov dword [submenu], -1
    ret
.none:
    lea rdi, [s_bp_none]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    jmp notify

; the copy tool's drag is done: copy what's under it
FUNC bp_copy
    mov eax, [tl_n]
    test eax, eax
    jz .out
    ; the rectangle's corners
    mov r12d, 1000                  ; x0
    mov r13d, 1000                  ; y0
    mov r14d, -1                    ; x1
    mov r15d, -1                    ; y1
    xor ebx, ebx
.b:
    mov eax, [tl_x+rbx*4]
    cmp eax, r12d
    cmovl r12d, eax
    cmp eax, r14d
    cmovg r14d, eax
    mov eax, [tl_y+rbx*4]
    cmp eax, r13d
    cmovl r13d, eax
    cmp eax, r15d
    cmovg r15d, eax
    inc ebx
    cmp ebx, [tl_n]
    jl .b
    sub r14d, r12d
    inc r14d
    CLAMP r14d, 1, BP_MAX
    sub r15d, r13d
    inc r15d
    CLAMP r15d, 1, BP_MAX
    mov [bp_w], r14d
    mov [bp_h], r15d
    mov dword [bp_rot], 0
    ; every cell
    xor ebx, ebx                    ; y
.y:
    xor ecx, ecx                    ; x
.x:
    mov eax, ebx
    imul eax, eax, BP_MAX
    add eax, ecx
    mov byte [bp_road+rax], 0
    mov byte [bp_zone+rax], 0
    mov byte [bp_flags+rax], 0
    push rax
    push rcx
    lea edi, [r12+rcx]
    lea esi, [r13+rbx]
    call tile_at
    pop rcx
    pop rdx                         ; (the cell)
    test rax, rax
    jz .xn
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .z
    test byte [rax+T_FLAGS], F_HIGHWAY
    jnz .z
    movzx r8d, byte [rax+T_ROADTYPE]
    cmp r8d, RT_HIGHWAY
    je .z
    inc r8d
    mov [bp_road+rdx], r8b
.z:
    movzx r8d, byte [rax+T_ZONE]
    mov [bp_zone+rdx], r8b
    test byte [rax+T_FLAGS2], F2_PIPE
    jz .t
    or byte [bp_flags+rdx], 1
.t:
    cmp byte [rax+T_OBJ], OBJ_TREE
    jne .xn
    or byte [bp_flags+rdx], 2
.xn:
    inc ecx
    cmp ecx, r14d
    jl .x
    inc ebx
    cmp ebx, r15d
    jl .y
    mov dword [tool], T_PASTE
    lea rdi, [s_bp_done]
    mov esi, UI_GOOD
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; where cell (edi x, esi y) of the copy lands, turned -> eax dx, edx dy
bp_turn:
    mov eax, [bp_rot]
    and eax, 3
    jz .r0
    cmp eax, 1
    je .r1
    cmp eax, 2
    je .r2
    ; 3: (y, w-1-x)
    mov eax, esi
    mov edx, [bp_w]
    dec edx
    sub edx, edi
    ret
.r0:
    mov eax, edi
    mov edx, esi
    ret
.r1:
    ; (h-1-y, x)
    mov eax, [bp_h]
    dec eax
    sub eax, esi
    mov edx, edi
    ret
.r2:
    mov eax, [bp_w]
    dec eax
    sub eax, edi
    mov edx, [bp_h]
    dec edx
    sub edx, esi
    ret

; the paste tool's tiles: the copy's cells around the cursor
FUNC bp_collect, 16
    mov dword [tl_n], 0
    cmp dword [bp_w], 0
    je .out
    ; the copy's middle at the cursor
    mov eax, [bp_w]
    mov ecx, [bp_h]
    test dword [bp_rot], 1
    jz .m
    xchg eax, ecx
.m:
    shr eax, 1
    shr ecx, 1
    mov r12d, [hover_tx]
    sub r12d, eax
    mov r13d, [hover_ty]
    sub r13d, ecx
    xor ebx, ebx                    ; y
.y:
    xor r14d, r14d                  ; x
.x:
    mov eax, ebx
    imul eax, eax, BP_MAX
    add eax, r14d
    mov r15d, eax
    cmp byte [bp_road+rax], 0
    jne .has
    cmp byte [bp_zone+rax], 0
    jne .has
    cmp byte [bp_flags+rax], 0
    je .xn
.has:
    mov edi, r14d
    mov esi, ebx
    call bp_turn
    lea edi, [r12+rax]
    lea esi, [r13+rdx]
    cmp edi, MAP_W
    jae .xn
    cmp esi, MAP_W
    jae .xn
    mov eax, [tl_n]
    cmp eax, MAX_TL
    jge .out
    mov [bp_cell+rax*2], r15w
    call tl_push
.xn:
    inc r14d
    cmp r14d, [bp_w]
    jl .x
    inc ebx
    cmp ebx, [bp_h]
    jl .y
.out:
    RETURN

; a tile for the paste (r12 tile, ecx object, edx terrain, rbx the tool
; tile) -> eax cost or -1
bp_tile_cost:
    cmp edx, TER_WATER
    je .no
    movzx r8d, word [bp_cell+rbx*2]
    movzx eax, byte [bp_road+r8]
    test eax, eax
    jz .nr
    ; a road: on bare land, trees, rubble - or the same road already
    cmp ecx, OBJ_ROAD
    je .same
    cmp ecx, OBJ_NONE
    je .road
    cmp ecx, OBJ_TREE
    je .road
    cmp ecx, OBJ_RUBBLE
    jne .no
.road:
    dec eax
    CLAMP eax, 0, 1
    mov eax, [road_costs+rax*4]
    ret
.same:
    xor eax, eax
    ret
.nr:
    ; zones and trees go on bare land
    cmp ecx, OBJ_NONE
    je .z
    cmp ecx, OBJ_TREE
    jne .pipe
.z:
    xor eax, eax
    cmp byte [bp_zone+r8], 0
    je .t
    add eax, 5
.t:
    test byte [bp_flags+r8], 2
    jz .p
    add eax, 3
.p:
    test byte [bp_flags+r8], 1
    jz .o
    add eax, 5
.o: ret
.pipe:
    ; only a pipe under what's there
    test byte [bp_flags+r8], 1
    jz .no
    mov eax, 5
    ret
.no:
    mov eax, -1
    ret

; stamp a tile (r12 tile; r13d, r14d its x, y; rbx the tool tile)
bp_lay_tile:
    movzx r8d, word [bp_cell+rbx*2]
    test byte [bp_flags+r8], 1
    jz .np
    or byte [r12+T_FLAGS2], F2_PIPE
.np:
    movzx eax, byte [bp_road+r8]
    test eax, eax
    jz .nr
    cmp byte [r12+T_OBJ], OBJ_ROAD
    je .o
    dec eax
    mov byte [r12+T_OBJ], OBJ_ROAD
    mov [r12+T_ROADTYPE], al
    mov byte [r12+T_ZONE], 0
    mov byte [r12+T_FLAGS], 0
    mov byte [r12+T_LEVEL], 0
    mov word [r12+T_POP], 0
    mov dword [r12+T_OCC], 0
    ret
.nr:
    cmp byte [r12+T_OBJ], OBJ_ROAD
    je .o
    movzx eax, byte [bp_zone+r8]
    test eax, eax
    jz .tr
    mov [r12+T_ZONE], al
.tr:
    test byte [bp_flags+r8], 2
    jz .o
    cmp byte [r12+T_OBJ], OBJ_NONE
    jne .o
    mov byte [r12+T_OBJ], OBJ_TREE
    mov byte [r12+T_SUB], 1
.o: ret

; R with the paste tool: turn the copy
bp_turn_key:
    inc dword [bp_rot]
    and dword [bp_rot], 3
    ret
