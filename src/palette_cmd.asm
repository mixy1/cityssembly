; =====================================================================
;  COMMAND PALETTE (beta) - / and type: "hosp", Enter
;
;  Every tool, building and info view in the menus, found by any part of
;  its name.  Up and Down choose, Enter takes it, Esc closes.
; =====================================================================
SC_SLASH_K  equ 56
SC_KPENTER  equ 88
PAL_HITS    equ 8
PAL_LEN     equ 20

section .bss
pal_open    resd 1
pal_len     resd 1
pal_sel     resd 1
pal_nhit    resd 1
pal_text    resb PAL_LEN+1
pal_hits    resd PAL_HITS

section .data
s_pal_tip   db "Type part of a name: Enter picks it, Esc closes", 0
s_pal_none  db "Nothing by that name", 0

section .text

; a key (edi scancode) -> eax 1 if the palette took it (beta)
FUNC palette_key
    xor eax, eax
    cmp dword [beta_on], 0
    je .out
    mov ebx, edi
    cmp dword [pal_open], 0
    jne .open
    cmp ebx, SC_SLASH_K
    jne .out
    ; (only in the game itself: not on a card or the save / load list)
    cmp dword [welcome], 0
    jne .out
    cmp dword [panel], PANEL_SAVE
    je .out
    cmp dword [panel], PANEL_LOAD
    je .out
    mov dword [pal_open], 1
    mov dword [pal_len], 0
    mov byte [pal_text], 0
    mov dword [pal_sel], 0
    call palette_search
    mov eax, 1
    jmp .out
.open:
    cmp ebx, SC_ESCAPE
    jne .k1
    mov dword [pal_open], 0
    jmp .took
.k1:
    cmp ebx, SC_BACKSPACE
    jne .k2
    cmp dword [pal_len], 0
    je .took
    dec dword [pal_len]
    mov eax, [pal_len]
    mov byte [pal_text+rax], 0
    mov dword [pal_sel], 0
    call palette_search
    jmp .took
.k2:
    cmp ebx, SC_RETURN
    je .go
    cmp ebx, SC_KPENTER
    jne .k3
.go:
    mov eax, [pal_sel]
    cmp eax, [pal_nhit]
    jge .took
    mov edi, [pal_hits+rax*4]
    mov dword [pal_open], 0
    call submenu_select
    jmp .took
.k3:
    cmp ebx, SC_DOWN
    jne .k4
    mov eax, [pal_sel]
    inc eax
    cmp eax, [pal_nhit]
    jge .took
    mov [pal_sel], eax
    jmp .took
.k4:
    cmp ebx, SC_UP
    jne .k5
    cmp dword [pal_sel], 0
    je .took
    dec dword [pal_sel]
    jmp .took
.k5:
    ; a letter, a digit or a space
    xor ecx, ecx
    cmp ebx, SC_A
    jl .took
    cmp ebx, SC_Z
    jg .dg
    lea ecx, [rbx-SC_A+'a']
    jmp .add
.dg:
    cmp ebx, SC_1
    jl .sp
    cmp ebx, SC_0
    jg .sp
    lea ecx, [rbx-SC_1+'1']
    cmp ebx, SC_0
    jne .add
    mov ecx, '0'
    jmp .add
.sp:
    cmp ebx, SC_SPACE
    jne .took
    mov ecx, ' '
.add:
    mov eax, [pal_len]
    cmp eax, PAL_LEN
    jge .took
    mov [pal_text+rax], cl
    mov byte [pal_text+rax+1], 0
    inc dword [pal_len]
    mov dword [pal_sel], 0
    call palette_search
.took:
    mov eax, 1
.out:
    RETURN

; does name rsi hold pal_text (any case)? -> eax 1
pal_match:
    cmp dword [pal_len], 0
    je .y
.s:
    cmp byte [rsi], 0
    je .n
    xor ecx, ecx
.c:
    movzx eax, byte [pal_text+rcx]
    test eax, eax
    jz .y
    movzx edx, byte [rsi+rcx]
    test edx, edx
    jz .n
    cmp edx, 'A'
    jb .l
    cmp edx, 'Z'
    ja .l
    add edx, 32
.l:
    cmp eax, edx
    jne .nx
    inc ecx
    jmp .c
.nx:
    inc rsi
    jmp .s
.y: mov eax, 1
    ret
.n: xor eax, eax
    ret

; the things whose names match, from every menu
FUNC palette_search, 16
    mov dword [pal_nhit], 0
    xor r12d, r12d                  ; menu
.m:
    mov eax, r12d
    push r15
    call submenu_list
    mov r13, r15
    pop r15
    xor r14d, r14d
.i:
    mov ebx, [r13+r14*4]
    cmp ebx, -1
    je .mn
    ; not twice
    xor ecx, ecx
.dup:
    cmp ecx, [pal_nhit]
    jge .nd
    cmp [pal_hits+rcx*4], ebx
    je .in
    inc ecx
    jmp .dup
.nd:
    mov edi, ebx
    call submenu_item_info
    mov rsi, rax
    test rsi, rsi
    jz .in
    call pal_match
    test eax, eax
    jz .in
    mov eax, [pal_nhit]
    mov [pal_hits+rax*4], ebx
    inc dword [pal_nhit]
    cmp dword [pal_nhit], PAL_HITS
    jge .out
.in:
    inc r14d
    jmp .i
.mn:
    inc r12d
    cmp r12d, 11
    jl .m
.out:
    RETURN

; the palette (beta, ui)
FUNC draw_palette_cmd, 16
    cmp dword [pal_open], 0
    je .out
    mov r12d, [ui_w]
    sub r12d, 260
    shr r12d, 1
    mov r13d, 60
    mov eax, [pal_nhit]
    imul eax, eax, 13
    add eax, 40
    mov [rbp-48], eax
    mov edi, r12d
    mov esi, r13d
    mov edx, 260
    mov ecx, [rbp-48]
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, 260
    mov ecx, [rbp-48]
    call ui_over
    ; what's typed
    call tb_reset
    mov edi, '/'
    call tb_char
    mov edi, ' '
    call tb_char
    lea rdi, [pal_text]
    call tb_str
    mov edi, '_'
    call tb_char
    lea edi, [r12+8]
    lea esi, [r13+6]
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text
    lea edi, [r12+8]
    lea esi, [r13+18]
    lea rdx, [s_pal_tip]
    mov ecx, UI_DIM
    call draw_text
    cmp dword [pal_nhit], 0
    jne .h
    lea edi, [r12+8]
    lea esi, [r13+32]
    lea rdx, [s_pal_none]
    mov ecx, UI_BAD
    call draw_text
    jmp .out
.h:
    xor ebx, ebx
.l:
    cmp ebx, [pal_nhit]
    jge .out
    imul eax, ebx, 13
    lea r14d, [r13+rax+32]
    cmp ebx, [pal_sel]
    jne .t
    lea edi, [r12+4]
    lea esi, [r14-2]
    mov edx, 252
    mov ecx, 12
    mov r8d, UI_BTN_HI
    call draw_box
.t:
    mov edi, [pal_hits+rbx*4]
    call submenu_item_info
    mov [rbp-52], edx
    lea edi, [r12+10]
    mov esi, r14d
    mov rdx, rax
    mov ecx, UI_TEXT
    call draw_text
    cmp dword [rbp-52], 0
    je .ln
    call tb_reset
    movsxd rdi, dword [rbp-52]
    call tb_money
    lea edi, [r12+252]
    mov esi, r14d
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text_right
.ln:
    inc ebx
    jmp .l
.out:
    RETURN
