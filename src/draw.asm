; =====================================================================
;  DRAW - 2D primitives, text and a small text builder
;  All primitives draw into the current target (world fb or ui fb)
;  and are clipped to the target clip rectangle.
; =====================================================================

section .bss
tgt_buf     resq 1
tgt_w       resd 1
tgt_h       resd 1
clip_x0     resd 1
clip_y0     resd 1
clip_x1     resd 1
clip_y1     resd 1
font_scale  resd 1
text_shadow resd 1
text_color0 resd 1
textbuf     resb 1024
tb_ptr      resq 1
numbuf      resb 64

section .data
color_codes db 0, 0, UI_GOOD, UI_BAD, UI_WARN, UI_GOLD, UI_DIM, UI_ACCENT, UI_TEXT

section .text

set_target_world:
    mov dword [tgt_is_world], 1
    lea rax, [fb]
    mov [tgt_buf], rax
    mov eax, [fb_w]
    mov [tgt_w], eax
    mov [clip_x1], eax
    mov eax, [fb_h]
    mov [tgt_h], eax
    mov [clip_y1], eax
    mov dword [clip_x0], 0
    mov dword [clip_y0], 0
    ret

set_target_ui:
    mov dword [tgt_is_world], 0
    lea rax, [uifb]
    mov [tgt_buf], rax
    mov eax, [ui_w]
    mov [tgt_w], eax
    mov [clip_x1], eax
    mov eax, [ui_h]
    mov [tgt_h], eax
    mov [clip_y1], eax
    mov dword [clip_x0], 0
    mov dword [clip_y0], 0
    ret

; set_clip(edi x, esi y, edx w, ecx h) intersected with target
set_clip:
    xor eax, eax
    cmp edi, eax
    cmovl edi, eax
    cmp esi, eax
    cmovl esi, eax
    mov [clip_x0], edi
    mov [clip_y0], esi
    add edx, edi
    add ecx, esi
    ; the caller passed original x,y; recompute right/bottom
    cmp edx, [tgt_w]
    jle .a
    mov edx, [tgt_w]
.a: cmp ecx, [tgt_h]
    jle .b
    mov ecx, [tgt_h]
.b: mov [clip_x1], edx
    mov [clip_y1], ecx
    ret

reset_clip:
    mov dword [clip_x0], 0
    mov dword [clip_y0], 0
    mov eax, [tgt_w]
    mov [clip_x1], eax
    mov eax, [tgt_h]
    mov [clip_y1], eax
    ret

; clear whole target: edi = colour
clear_target:
    mov eax, edi
    mov rdi, [tgt_buf]
    mov ecx, [tgt_w]
    imul ecx, [tgt_h]
    mov ah, al
    mov edx, eax
    shl eax, 16
    mov ax, dx
    mov edx, ecx
    shr ecx, 2
    rep stosd
    mov ecx, edx
    and ecx, 3
    rep stosb
    ret

; ---------------------------------------------------------------------
;  fill_rect(edi x, esi y, edx w, ecx h, r8d colour)
; ---------------------------------------------------------------------
fill_rect:
    add edx, edi                ; x1
    add ecx, esi                ; y1
    cmp edi, [clip_x0]
    jge .1
    mov edi, [clip_x0]
.1: cmp esi, [clip_y0]
    jge .2
    mov esi, [clip_y0]
.2: cmp edx, [clip_x1]
    jle .3
    mov edx, [clip_x1]
.3: cmp ecx, [clip_y1]
    jle .4
    mov ecx, [clip_y1]
.4: sub edx, edi
    jle .out
    sub ecx, esi
    jle .out
    mov r9d, ecx                ; rows
    mov r10d, edx               ; width
    mov eax, esi
    imul eax, [tgt_w]
    add eax, edi
    mov r11, [tgt_buf]
    add r11, rax
    mov eax, r8d
.row:
    mov rdi, r11
    mov ecx, r10d
    rep stosb
    movsxd rdx, dword [tgt_w]
    add r11, rdx
    dec r9d
    jnz .row
.out:
    ret

; put_pixel(edi x, esi y, edx colour)
put_pixel:
    cmp edi, [clip_x0]
    jl .o
    cmp edi, [clip_x1]
    jge .o
    cmp esi, [clip_y0]
    jl .o
    cmp esi, [clip_y1]
    jge .o
    mov eax, esi
    imul eax, [tgt_w]
    add eax, edi
    add rax, [tgt_buf]
    mov [rax], dl
.o: ret

; hline(edi x, esi y, edx w, ecx colour)
hline:
    mov r8d, ecx
    mov ecx, 1
    jmp fill_rect

; vline(edi x, esi y, edx h, ecx colour)
vline:
    mov r8d, ecx
    mov ecx, edx
    mov edx, 1
    jmp fill_rect

; rect_outline(edi x, esi y, edx w, ecx h, r8d colour)
FUNC rect_outline
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov ebx, r8d
    mov ecx, 1
    call fill_rect                 ; top
    mov edi, r12d
    lea esi, [r13+r15-1]
    mov edx, r14d
    mov ecx, 1
    mov r8d, ebx
    call fill_rect                 ; bottom
    mov edi, r12d
    mov esi, r13d
    mov edx, 1
    mov ecx, r15d
    mov r8d, ebx
    call fill_rect                 ; left
    lea edi, [r12+r14-1]
    mov esi, r13d
    mov edx, 1
    mov ecx, r15d
    mov r8d, ebx
    call fill_rect                 ; right
    RETURN

; ---------------------------------------------------------------------
;  draw_panel(edi x, esi y, edx w, ecx h) - rounded translucent panel
; ---------------------------------------------------------------------
FUNC draw_panel
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    ; body
    lea edi, [r12+1]
    lea esi, [r13+1]
    lea edx, [r14-2]
    lea ecx, [r15-2]
    mov r8d, UI_BG
    call fill_rect
    ; dark rim
    lea edi, [r12+1]
    mov esi, r13d
    lea edx, [r14-2]
    mov ecx, UI_EDGE_LO
    call hline
    lea edi, [r12+1]
    lea esi, [r13+r15-1]
    lea edx, [r14-2]
    mov ecx, UI_EDGE_LO
    call hline
    mov edi, r12d
    lea esi, [r13+1]
    lea edx, [r15-2]
    mov ecx, UI_EDGE_LO
    call vline
    lea edi, [r12+r14-1]
    lea esi, [r13+1]
    lea edx, [r15-2]
    mov ecx, UI_EDGE_LO
    call vline
    ; top highlight
    lea edi, [r12+2]
    lea esi, [r13+1]
    lea edx, [r14-4]
    mov ecx, UI_EDGE_HI
    call hline
    RETURN

; draw_box(edi x, esi y, edx w, ecx h, r8d fill) - solid box with rim
FUNC draw_box
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov ebx, r8d
    lea edi, [r12+1]
    lea esi, [r13+1]
    lea edx, [r14-2]
    lea ecx, [r15-2]
    call fill_rect
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, r15d
    mov r8d, UI_EDGE_LO
    call rect_outline
    RETURN

; ---------------------------------------------------------------------
;  font
; ---------------------------------------------------------------------
FUNC font_init
    xor ebx, ebx                    ; glyph
.g:
    imul r12d, ebx, 40
    lea r12, [font_art+r12]
    xor r13d, r13d                  ; all-row mask
    xor ecx, ecx                    ; row
.r:
    xor eax, eax
    xor edx, edx                    ; col
.c:
    lea r8d, [rcx*4+rcx]
    add r8d, edx
    cmp byte [r12+r8], '#'
    jne .nc
    bts eax, edx
.nc:
    inc edx
    cmp edx, 5
    jl .c
    lea r8d, [rbx*8+rcx]
    mov [font_rows+r8], al
    or r13d, eax
    inc ecx
    cmp ecx, 8
    jl .r
    ; width
    test r13d, r13d
    jz .blank
    lea eax, [rbx+FONT_FIRST]
    cmp eax, '0'
    jl .trim
    cmp eax, '9'
    jg .trim
    mov byte [font_width+rbx], 5
    jmp .next
.trim:
    bsf ecx, r13d                   ; min col
    bsr edx, r13d                   ; max col
    sub edx, ecx
    inc edx
    mov [font_width+rbx], dl
    ; shift rows
    xor r8d, r8d
.sh:
    lea r9d, [rbx*8+r8]
    shr byte [font_rows+r9], cl
    inc r8d
    cmp r8d, 8
    jl .sh
    jmp .next
.blank:
    mov byte [font_width+rbx], 3
.next:
    inc ebx
    cmp ebx, FONT_COUNT
    jl .g
    mov dword [font_scale], 1
    mov dword [text_shadow], 1
    RETURN

; ---------------------------------------------------------------------
;  draw_glyph(edi x, esi y, edx ch, ecx colour) -> eax advance
; ---------------------------------------------------------------------
FUNC draw_glyph, 16
    mov r12d, edi
    mov r13d, esi
    mov r15d, ecx
    sub edx, FONT_FIRST
    jb .space
    cmp edx, FONT_COUNT
    jae .space
    mov ebx, edx
    xor r14d, r14d                  ; row
.row:
    lea eax, [rbx*8+r14]
    movzx eax, byte [font_rows+rax]
    mov [rbp-48], eax               ; row bits
    xor ecx, ecx                    ; col
.col:
    mov eax, [rbp-48]
    bt eax, ecx
    jnc .skip
    ; pixel block of font_scale x font_scale
    mov [rbp-52], ecx
    mov eax, [font_scale]
    mov edi, ecx
    imul edi, eax
    add edi, r12d
    mov esi, r14d
    imul esi, eax
    add esi, r13d
    mov edx, eax
    mov ecx, eax
    mov r8d, r15d
    call fill_rect
    mov ecx, [rbp-52]
.skip:
    inc ecx
    cmp ecx, 5
    jl .col
    inc r14d
    cmp r14d, 8
    jl .row
    movzx eax, byte [font_width+rbx]
    inc eax
    imul eax, [font_scale]
    RETURN
.space:
    mov eax, 4
    imul eax, [font_scale]
    RETURN

; glyph_advance(edi ch) -> eax
glyph_advance:
    sub edi, FONT_FIRST
    jb .sp
    cmp edi, FONT_COUNT
    jae .sp
    movzx eax, byte [font_width+rdi]
    inc eax
    imul eax, [font_scale]
    ret
.sp:
    mov eax, 4
    imul eax, [font_scale]
    ret

; ---------------------------------------------------------------------
;  draw_text(edi x, esi y, rdx str, ecx colour) -> eax end x
;  control bytes: 10 newline, 1..8 colour codes (1 = base colour)
; ---------------------------------------------------------------------
FUNC draw_text, 16
    mov r12d, edi                   ; x
    mov r13d, esi                   ; y
    mov r14, rdx                    ; str
    mov r15d, ecx                   ; colour
    mov [rbp-48], edi               ; line start x
    mov [rbp-52], ecx               ; base colour
    mov [rbp-56], edi               ; max x
.next:
    movzx ebx, byte [r14]
    inc r14
    test ebx, ebx
    jz .done
    cmp ebx, 10
    je .nl
    cmp ebx, 9
    jl .code
    cmp dword [text_shadow], 0
    je .noshadow
    lea edi, [r12+1]
    mov eax, [font_scale]
    lea esi, [r13+rax]
    mov edx, ebx
    mov ecx, UI_BLACK
    cmp dword [tgt_is_world], 0
    je .sh
    mov ecx, 1
.sh:
    call draw_glyph
.noshadow:
    mov edi, r12d
    mov esi, r13d
    mov edx, ebx
    mov ecx, r15d
    call draw_glyph
    add r12d, eax
    cmp r12d, [rbp-56]
    jle .next
    mov [rbp-56], r12d
    jmp .next
.code:
    cmp ebx, 1
    jne .c2
    mov r15d, [rbp-52]
    jmp .next
.c2:
    movzx r15d, byte [color_codes+rbx]
    jmp .next
.nl:
    mov r12d, [rbp-48]
    mov eax, [font_scale]
    imul eax, 10
    add r13d, eax
    jmp .next
.done:
    mov eax, [rbp-56]
    RETURN

; text_width(rdi str) -> eax (widest line)
FUNC text_width
    mov r12, rdi
    xor r13d, r13d                  ; cur
    xor r14d, r14d                  ; max
.n:
    movzx edi, byte [r12]
    inc r12
    test edi, edi
    jz .d
    cmp edi, 10
    je .nl
    cmp edi, 9
    jl .n
    call glyph_advance
    add r13d, eax
    cmp r13d, r14d
    jle .n
    mov r14d, r13d
    jmp .n
.nl:
    xor r13d, r13d
    jmp .n
.d:
    mov eax, r14d
    RETURN

; draw_text_centered(edi cx, esi y, rdx str, ecx colour)
FUNC draw_text_centered
    mov r12d, edi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov rdi, rdx
    call text_width
    shr eax, 1
    mov edi, r12d
    sub edi, eax
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    call draw_text
    RETURN

; draw_text_right(edi rx, esi y, rdx str, ecx colour)
FUNC draw_text_right
    mov r12d, edi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov rdi, rdx
    call text_width
    mov edi, r12d
    sub edi, eax
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    call draw_text
    RETURN

; ---------------------------------------------------------------------
;  text builder
; ---------------------------------------------------------------------
tb_reset:
    lea rax, [textbuf]
    mov [tb_ptr], rax
    mov byte [rax], 0
    ret

; tb_str(rdi str)
tb_str:
    mov rax, [tb_ptr]
.l:
    mov cl, [rdi]
    mov [rax], cl
    test cl, cl
    jz .d
    inc rdi
    inc rax
    jmp .l
.d:
    mov [tb_ptr], rax
    ret

; tb_char(edi ch)
tb_char:
    mov rax, [tb_ptr]
    mov [rax], dil
    mov byte [rax+1], 0
    inc rax
    mov [tb_ptr], rax
    ret

; tb_num(rdi signed value) with thousands separators
tb_num:
    push rbx
    mov rax, rdi
    lea r8, [numbuf+63]
    mov byte [r8], 0
    xor r9d, r9d                    ; negative flag
    test rax, rax
    jns .pos
    neg rax
    mov r9d, 1
.pos:
    xor ebx, ebx                    ; digit counter
    mov r10, 10
.dig:
    cmp ebx, 3
    jne .nocomma
    dec r8
    mov byte [r8], ','
    xor ebx, ebx
.nocomma:
    xor edx, edx
    div r10
    add dl, '0'
    dec r8
    mov [r8], dl
    inc ebx
    test rax, rax
    jnz .dig
    test r9d, r9d
    jz .cp
    dec r8
    mov byte [r8], '-'
.cp:
    mov rdi, r8
    pop rbx
    jmp tb_str

; tb_money(rdi value) -> "$1,234" / "-$1,234"
tb_money:
    test rdi, rdi
    jns .p
    push rdi
    mov edi, '-'
    call tb_char
    pop rdi
    neg rdi
.p:
    push rdi
    mov edi, '$'
    call tb_char
    pop rdi
    jmp tb_num

; tb_pct(rdi value) -> "42%"
tb_pct:
    call tb_num
    mov edi, '%'
    jmp tb_char

; draw the text builder buffer
; tb_draw(edi x, esi y, ecx colour) -> eax end x
tb_draw:
    lea rdx, [textbuf]
    jmp draw_text

section .bss
tgt_is_world resd 1
