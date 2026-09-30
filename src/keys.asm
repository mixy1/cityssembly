; =====================================================================
;  KEYS (beta) - the keyboard, rebound
;
;  Menu > Keys: click an action, then press its new key.  Keys swap -
;  the key it had does what the new one did - so nothing is ever lost.
;  The camera's keys (W A S D and the arrows) and the Ctrl and Alt
;  shortcuts stay as they are.  The map
;  (key pressed -> the key it acts as) is saved with the settings.
; =====================================================================
KB_N        equ 25
KB_ROWS     equ 13
KP_W        equ 420
KP_H        equ 262

section .bss
key_map     resb 128
kb_wait     resd 1              ; the action waiting for its key, + 1

section .data
kb_keys     db SC_Q, SC_B, SC_R, SC_L, SC_P, SC_X, SC_T, SC_K, SC_U
            db SC_G, SC_E, SC_H, SC_V, SC_O, SC_TAB, SC_N, SC_M
            db SC_SPACE, SC_LBRACKET, SC_RBRACKET, SC_F, SC_C, SC_SLASH_K
            db SC_F5, SC_F9
kb_names    dq kbn0, kbn1, kbn2, kbn3, kbn4, kbn5, kbn6, kbn7, kbn8
            dq kbn9, kbn10, kbn11, kbn12, kbn13, kbn14, kbn15, kbn16
            dq kbn17, kbn18, kbn19, kbn20, kbn21, kbn22, kbn23, kbn24
kbn0        db "Inspect", 0
kbn1        db "Bulldoze", 0
kbn2        db "Road", 0
kbn3        db "Power line", 0
kbn4        db "Pipe (Shift: plan)", 0
kbn5        db "Dezone", 0
kbn6        db "Trees", 0
kbn7        db "Land", 0
kbn8        db "Upgrade roads", 0
kbn9        db "Tool mode", 0
kbn10       db "Eyedropper", 0
kbn11       db "See-through", 0
kbn12       db "Info view", 0
kbn13       db "Next info view", 0
kbn14       db "Minimap", 0
kbn15       db "Hold the time of day", 0
kbn16       db "Music", 0
kbn17       db "Pause", 0
kbn18       db "Slower", 0
kbn19       db "Faster", 0
kbn20       db "Photo mode", 0
kbn21       db "Neighbours", 0
kbn22       db "Command palette", 0
kbn23       db "Save", 0
kbn24       db "Load", 0
s_kb_title  db "Keys", 0
s_kb_tip    db "Click an action, then press its new key (Esc: never mind).", 0
s_kb_tip2   db "Keys swap; W A S D and the arrows move the camera.", 0
s_kb_press  db "press...", 0
s_kb_no     db "That key moves the camera - pick another.", 0
s_kb_reset  db "Reset", 0
s_kb_close  db "Close", 0
s_kb_menu   db "Keys...", 0
kb_punct    db "Enter", 0, "Esc", 0, "Bksp", 0, "Tab", 0, "Space", 0
            db "-", 0, "=", 0, "[", 0, "]", 0, "\", 0, "#", 0, ";", 0
            db "'", 0, "`", 0, ",", 0, ".", 0, "/", 0, 0
kb_nav      db "Ins", 0, "Home", 0, "PgUp", 0, "Del", 0, "End", 0, "PgDn", 0, 0

section .text

; every key as itself
keys_init:
    xor eax, eax
.l: mov [key_map+rax], al
    inc eax
    cmp eax, 128
    jl .l
    mov dword [kb_wait], 0
    ret

; the keys from the settings file (a permutation, or every key as
; itself)
keys_from_cfg:
    lea rsi, [settings_buf+4+AUTO_ON_N+SET_N*4]
    ; each key once
    sub rsp, 136
    xor eax, eax
.z: mov byte [rsp+rax], 0
    inc eax
    cmp eax, 128
    jl .z
    xor ecx, ecx
.c: movzx eax, byte [rsi+rcx]
    cmp eax, 128
    jae .bad
    cmp byte [rsp+rax], 0
    jne .bad
    mov byte [rsp+rax], 1
    inc ecx
    cmp ecx, 128
    jl .c
    add rsp, 136
    lea rdi, [key_map]
    mov ecx, 128
    rep movsb
    ret
.bad:
    add rsp, 136
    ret

; a key pressed (edi scancode) -> eax the key it acts as, or -1 when it
; was taken for binding (beta)
FUNC keys_key
    mov eax, edi
    cmp dword [beta_on], 0
    je .out
    cmp dword [kb_wait], 0
    je .map
    cmp dword [panel], PANEL_KEYS   ; (the panel went: so did the question)
    je .bind
    mov dword [kb_wait], 0
.map:
    cmp dword [pal_open], 0         ; (the palette wants the letters)
    jne .out
    test dword [key_mod], 0x3C0     ; (Ctrl and Alt keys stay as they are)
    jnz .out
    cmp eax, 128
    jae .out
    movzx eax, byte [key_map+rax]
    jmp .out
.bind:
    mov ebx, edi
    cmp ebx, SC_ESCAPE
    je .done
    ; not the camera's keys, nor keys past the table
    cmp ebx, 128
    jae .no
    cmp ebx, SC_W
    je .no
    cmp ebx, SC_A
    je .no
    cmp ebx, SC_S
    je .no
    cmp ebx, SC_D
    je .no
    cmp ebx, SC_RIGHT
    jb .ok
    cmp ebx, SC_UP
    jbe .no
.ok:
    ; the action's key, and the key that does it now
    mov ecx, [kb_wait]
    dec ecx
    movzx ecx, byte [kb_keys+rcx]
    xor edx, edx
.f: movzx eax, byte [key_map+rdx]
    cmp eax, ecx
    je .sw
    inc edx
    cmp edx, 128
    jl .f
    jmp .done
.sw:
    ; swap: the new key does it, the old key what the new one did
    movzx eax, byte [key_map+rbx]
    mov [key_map+rbx], cl
    mov [key_map+rdx], al
    call settings_save
    jmp .done
.no:
    lea rdi, [s_kb_no]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
.done:
    mov dword [kb_wait], 0
    mov eax, -1
.out:
    RETURN

; the name of key edi onto the text buffer
FUNC tb_key
    mov ebx, edi
    cmp ebx, SC_A
    jb .num
    cmp ebx, SC_Z
    ja .dig
    lea edi, [rbx-SC_A+'A']
    call tb_char
    jmp .out
.dig:
    cmp ebx, SC_0
    ja .pun
    lea edi, [rbx-SC_1+'1']
    cmp ebx, SC_0
    jne .dc
    mov edi, '0'
.dc:
    call tb_char
    jmp .out
.pun:
    cmp ebx, SC_SLASH_K
    ja .fk
    lea rdi, [kb_punct]
    lea ecx, [rbx-SC_RETURN]
    call .nth
    jmp .out
.fk:
    cmp ebx, SC_F1
    jb .num
    cmp ebx, SC_F12
    ja .nav
    mov edi, 'F'
    call tb_char
    lea edi, [rbx-SC_F1+1]
    movsxd rdi, edi
    call tb_num
    jmp .out
.nav:
    cmp ebx, 73
    jb .num
    cmp ebx, 78
    ja .num
    lea rdi, [kb_nav]
    lea ecx, [rbx-73]
    call .nth
    jmp .out
.num:
    mov edi, '#'
    call tb_char
    movsxd rdi, ebx
    call tb_num
.out:
    RETURN
.nth:                               ; the ecx-th of the strings at rdi
    test ecx, ecx
    jz .put
.sk:
    cmp byte [rdi], 0
    je .nx
    inc rdi
    jmp .sk
.nx:
    inc rdi
    dec ecx
    jnz .sk
.put:
    jmp tb_str

; the keys panel (beta)
FUNC draw_keys, 16
    mov r12d, [ui_w]
    sub r12d, KP_W
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, KP_H
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, KP_W
    mov ecx, KP_H
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, KP_W
    mov ecx, KP_H
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_kb_title]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    lea edi, [r12+10]
    lea esi, [r13+28]
    lea rdx, [s_kb_tip]
    mov ecx, UI_DIM
    call draw_text
    lea edi, [r12+10]
    lea esi, [r13+39]
    lea rdx, [s_kb_tip2]
    mov ecx, UI_DIM
    call draw_text
    xor ebx, ebx
.a:
    ; two columns
    mov eax, ebx
    xor edx, edx
    mov ecx, KB_ROWS
    div ecx
    imul r14d, eax, 205
    add r14d, r12d
    add r14d, 10
    imul r15d, edx, 14
    add r15d, r13d
    add r15d, 54
    mov rdx, [kb_names+rbx*8]
    mov edi, r14d
    lea esi, [r15+3]
    mov ecx, UI_TEXT
    call draw_text
    ; its key now
    call tb_reset
    lea eax, [rbx+1]
    cmp eax, [kb_wait]
    jne .k
    lea rdi, [s_kb_press]
    call tb_str
    jmp .b
.k:
    movzx ecx, byte [kb_keys+rbx]
    xor edi, edi
.f: movzx eax, byte [key_map+rdi]
    cmp eax, ecx
    je .fk
    inc edi
    cmp edi, 128
    jl .f
    mov edi, ecx
.fk:
    call tb_key
.b:
    lea edi, [r14+130]
    mov esi, r15d
    mov edx, 66
    lea rcx, [textbuf]
    xor r8d, r8d
    lea eax, [rbx+1]
    cmp eax, [kb_wait]
    sete r8b
    call text_button
    test eax, eax
    jz .an
    lea eax, [rbx+1]
    mov [kb_wait], eax
.an:
    inc ebx
    cmp ebx, KB_N
    jl .a
    ; reset, close
    lea edi, [r12+KP_W/2-80]
    lea esi, [r13+KP_H-22]
    mov edx, 76
    lea rcx, [s_kb_reset]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .c
    call keys_init
    call settings_save
.c:
    lea edi, [r12+KP_W/2+4]
    lea esi, [r13+KP_H-22]
    mov edx, 76
    lea rcx, [s_kb_close]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .out
    mov dword [kb_wait], 0
    mov dword [panel], PANEL_NONE
.out:
    RETURN
