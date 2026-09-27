; =====================================================================
;  SAVES - several cities, each with a screenshot
;
;  Eight slots: seven cities and the autosave.  Every save starts with
;  two small chunks, INFO (date, population, money, a save counter) and
;  THMB (a 128x72 picture of the view, in world palette indices), so the
;  Save / Load panels can show all slots by reading only the first few
;  kilobytes of each file.  Older saves load fine and show no picture.
; =====================================================================

SLOTS       equ 8
AUTO_SLOT   equ 7
THUMB_W     equ 128
THUMB_H     equ 72
THUMB_BYTES equ THUMB_W*THUMB_H
INFO_BYTES  equ 32              ; seq, year, month, pop, money (q), pad
PEEK_MAX    equ 16384
CARD_W      equ 136
CARD_H      equ 100
PANEL_SW    equ 4*(CARD_W+4)+12
PANEL_SH    equ 26+2*(CARD_H+4)+26

section .data
align 8
slot_files  dq sf0, sf1, sf2, sf3, sf4, sf5, sf6, s_autofile
sf0 db "city.sav", 0
sf1 db "city2.sav", 0
sf2 db "city3.sav", 0
sf3 db "city4.sav", 0
sf4 db "city5.sav", 0
sf5 db "city6.sav", 0
sf6 db "city7.sav", 0
s_sl_city   db "City ", 0
s_sl_auto   db "Autosave", 0
s_sl_save   db "Save city", 0
s_sl_load   db "Load city", 0
s_sl_empty  db "Empty", 0
s_sl_here   db "Save here", 0
s_sl_old    db "No preview", 0
s_sl_older  db "older save", 0
s_sl_again  db "Click again to overwrite", 0
s_sl_latest db "LATEST", 0
s_sl_pop    db "Pop ", 0
s_sl_new    db "New city", 0
s_sl_close  db "Close", 0
s_sl_hint   db "Pick a city to continue, or start a new one.", 0
s_sl_shint  db "The picture is what you're looking at now.", 0
current_slot dd 0
slot_confirm dd -1

section .bss
save_info   resb INFO_BYTES     ; the chunks of the city being saved / loaded
save_thumb  resb THUMB_BYTES
save_seq    resd 1
slots_start resd 1              ; the load panel was opened at start-up
slot_has    resb SLOTS          ; 0 empty, 1 with picture, 2 older save
alignb 8
slot_info   resb SLOTS*INFO_BYTES
slot_thumb  resb SLOTS*THUMB_BYTES
peek_buf    resb PEEK_MAX
slot_latest resd 1

section .text

; ---------------------------------------------------------------------
;  save_prepare: fill INFO and take the picture before a save
; ---------------------------------------------------------------------
FUNC save_prepare, 32
    inc dword [save_seq]
    mov eax, [save_seq]
    mov [save_info], eax
    mov eax, [year]
    mov [save_info+4], eax
    mov eax, [month]
    mov [save_info+8], eax
    mov eax, [population]
    mov [save_info+12], eax
    mov rax, [money]
    mov [save_info+16], rax
    ; the picture: the middle of the view at 16:9, nearest samples
    mov eax, [fb_w]
    mov ecx, [fb_h]
    test eax, eax
    jz .blank
    test ecx, ecx
    jz .blank
    imul edx, eax, 9
    imul r8d, ecx, 16
    cmp edx, r8d
    jle .tall
    ; wide: full height
    mov [rbp-52], ecx               ; ch
    imul eax, ecx, 16
    xor edx, edx
    mov r8d, 9
    div r8d
    mov [rbp-48], eax               ; cw
    mov ecx, [fb_w]
    sub ecx, eax
    shr ecx, 1
    mov [rbp-56], ecx               ; x0
    mov dword [rbp-60], 0           ; y0
    jmp .grab
.tall:
    mov [rbp-48], eax               ; cw
    imul eax, eax, 9
    shr eax, 4
    mov [rbp-52], eax               ; ch
    mov ecx, [fb_h]
    sub ecx, eax
    shr ecx, 1
    mov [rbp-60], ecx
    mov dword [rbp-56], 0
.grab:
    lea r15, [save_thumb]
    xor r13d, r13d                  ; ty
.gy:
    ; sy = y0 + (2ty+1)*ch / (2*THUMB_H)
    lea eax, [r13*2+1]
    imul eax, [rbp-52]
    xor edx, edx
    mov ecx, 2*THUMB_H
    div ecx
    add eax, [rbp-60]
    imul eax, [fb_w]
    lea r14, [fb+rax]               ; row
    xor r12d, r12d                  ; tx
.gx:
    lea eax, [r12*2+1]
    imul eax, [rbp-48]
    xor edx, edx
    mov ecx, 2*THUMB_W
    div ecx
    add eax, [rbp-56]
    movzx eax, byte [r14+rax]
    test eax, eax
    jnz .px
    mov eax, RAMP(R_DEEPWATER, 1)
.px:
    mov [r15], al
    inc r15
    inc r12d
    cmp r12d, THUMB_W
    jl .gx
    inc r13d
    cmp r13d, THUMB_H
    jl .gy
    RETURN
.blank:
    lea rdi, [save_thumb]
    mov eax, RAMP(R_DEEPWATER, 1)
    mov ecx, THUMB_BYTES
    rep stosb
    RETURN

; ---------------------------------------------------------------------
;  slots_scan: read the header of every slot file
; ---------------------------------------------------------------------
FUNC slots_scan, 16
    mov dword [slot_latest], -1
    xor ebx, ebx
    xor r15d, r15d                  ; highest seq
.l:
    cmp ebx, SLOTS
    jge .done
    mov byte [slot_has+rbx], 0
    mov rdi, [slot_files+rbx*8]
    lea rsi, [str_rb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz .n
    mov r12, rax
    mov rdi, r12
    lea rsi, [peek_buf]
    mov edx, 1
    mov ecx, PEEK_MAX
    CALLC SDL_RWread
    mov r13, rax                    ; bytes
    mov rdi, r12
    CALLC SDL_RWclose
    cmp r13, 8
    jb .n
    mov byte [slot_has+rbx], 2      ; a save, at least
    mov rax, [peek_buf]
    cmp rax, [save_magic]
    jne .n
    ; walk the chunks up to the map
    mov r12d, 8                     ; position
    xor r14d, r14d                  ; found: 1 info, 2 picture
.c:
    lea eax, [r12+8]
    cmp rax, r13
    ja .cd
    mov ecx, [peek_buf+r12]         ; tag
    mov edx, [peek_buf+r12+4]       ; length
    cmp ecx, 'TILE'
    je .cd
    lea eax, [r12+8]
    add rax, rdx
    cmp rax, r13
    ja .cd
    cmp ecx, 'INFO'
    jne .c2
    cmp edx, INFO_BYTES
    jne .cn
    imul edi, ebx, INFO_BYTES
    lea rdi, [slot_info+rdi]
    lea rsi, [peek_buf+r12+8]
    mov ecx, INFO_BYTES
    rep movsb
    or r14d, 1
    jmp .cn
.c2:
    cmp ecx, 'THMB'
    jne .cn
    cmp edx, THUMB_BYTES
    jne .cn
    imul edi, ebx, THUMB_BYTES
    lea rdi, [slot_thumb+rdi]
    lea rsi, [peek_buf+r12+8]
    mov ecx, THUMB_BYTES
    rep movsb
    or r14d, 2
.cn:
    mov edx, [peek_buf+r12+4]
    lea r12d, [r12+rdx+8]
    jmp .c
.cd:
    cmp r14d, 3
    jne .n
    mov byte [slot_has+rbx], 1
    imul eax, ebx, INFO_BYTES
    mov eax, [slot_info+rax]
    cmp eax, r15d
    jbe .n
    mov r15d, eax
    mov [slot_latest], ebx
.n:
    inc ebx
    jmp .l
.done:
    cmp r15d, [save_seq]
    jbe .o
    mov [save_seq], r15d
.o:
    RETURN

; any save at all? -> eax
slots_any:
    xor eax, eax
    xor ecx, ecx
.l:
    cmp byte [slot_has+rcx], 0
    je .n
    mov eax, 1
.n:
    inc ecx
    cmp ecx, SLOTS
    jl .l
    ret

; open the panels
open_load_panel:
    mov dword [panel], PANEL_LOAD
    mov dword [slot_confirm], -1
    jmp slots_scan
open_save_panel:
    mov dword [panel], PANEL_SAVE
    mov dword [slot_confirm], -1
    jmp slots_scan

; quick save / load (F5, the menu) use the current slot
save_current:
    mov eax, [current_slot]
    mov rdi, [slot_files+rax*8]
    jmp save_city_to

; draw a picture (rdx) at ui (edi x, esi y)
blit_thumb:
    push rbx
    push r12
    mov r8, rdx
    mov r12d, esi
    xor r9d, r9d                    ; row
.r:
    lea eax, [r12+r9]
    cmp eax, [ui_h]
    jae .rn
    imul eax, [ui_w]
    lea r10, [uifb+rax]
    xor r11d, r11d
.c:
    lea eax, [rdi+r11]
    cmp eax, [ui_w]
    jae .cn
    movzx ebx, byte [r8+r11]
    mov [r10+rax], bl
.cn:
    inc r11d
    cmp r11d, THUMB_W
    jl .c
.rn:
    add r8, THUMB_W
    inc r9d
    cmp r9d, THUMB_H
    jl .r
    pop r12
    pop rbx
    ret

; the slot's name into textbuf (edi slot)
tb_slot_name:
    push rbx
    mov ebx, edi
    call tb_reset
    cmp ebx, AUTO_SLOT
    jne .c
    lea rdi, [s_sl_auto]
    call tb_str
    pop rbx
    ret
.c:
    lea rdi, [s_sl_city]
    call tb_str
    lea edi, [rbx+1]
    call tb_num
    pop rbx
    ret

; ---------------------------------------------------------------------
;  draw_slots: the Save or Load panel
; ---------------------------------------------------------------------
FUNC draw_slots, 48
    mov eax, [ui_w]
    sub eax, PANEL_SW
    sar eax, 1
    mov [rbp-48], eax               ; px
    mov eax, [ui_h]
    sub eax, PANEL_SH
    sar eax, 1
    mov [rbp-52], eax               ; py
    xor eax, eax
    cmp dword [panel], PANEL_SAVE
    sete al
    mov [rbp-56], eax               ; save mode
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, PANEL_SW
    mov ecx, PANEL_SH
    call draw_panel
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, PANEL_SW
    mov ecx, PANEL_SH
    call ui_over
    ; title and hint
    mov dword [font_scale], 2
    mov edi, [rbp-48]
    add edi, 10
    mov esi, [rbp-52]
    add esi, 6
    lea rdx, [s_sl_load]
    cmp dword [rbp-56], 0
    je .t
    lea rdx, [s_sl_save]
.t:
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    mov edi, [rbp-48]
    add edi, PANEL_SW-10
    mov esi, [rbp-52]
    add esi, 10
    lea rdx, [s_sl_hint]
    cmp dword [rbp-56], 0
    je .h
    lea rdx, [s_sl_shint]
.h:
    mov ecx, UI_DIM
    call draw_text_right
    ; ---- cards ----
    xor ebx, ebx
.card:
    cmp ebx, SLOTS
    jge .bottom
    mov eax, ebx
    and eax, 3
    imul eax, CARD_W+4
    add eax, [rbp-48]
    add eax, 8
    mov r12d, eax                   ; card x
    mov eax, ebx
    shr eax, 2
    imul eax, CARD_H+4
    add eax, [rbp-52]
    add eax, 26
    mov r13d, eax                   ; card y
    movzx r14d, byte [slot_has+rbx]
    ; clickable?  save: every city slot; load: every slot with a save
    xor r15d, r15d
    cmp dword [rbp-56], 0
    je .ld
    cmp ebx, AUTO_SLOT
    je .dis
    mov r15d, 1
    jmp .box
.ld:
    test r14d, r14d
    jz .dis
    mov r15d, 1
.box:
    xor r8d, r8d
    mov edi, r12d
    mov esi, r13d
    mov edx, CARD_W
    mov ecx, CARD_H
    call button
    mov [rbp-60], eax               ; clicked
    jmp .pic
.dis:
    mov edi, r12d
    mov esi, r13d
    mov edx, CARD_W
    mov ecx, CARD_H
    mov r8d, UI_BG2
    call draw_box
    mov dword [rbp-60], 0
.pic:
    ; the picture, or a placeholder
    cmp r14d, 1
    jne .nopic
    imul eax, ebx, THUMB_BYTES
    lea rdx, [slot_thumb+rax]
    lea edi, [r12+4]
    lea esi, [r13+4]
    call blit_thumb
    jmp .text
.nopic:
    lea edi, [r12+4]
    lea esi, [r13+4]
    mov edx, THUMB_W
    mov ecx, THUMB_H
    mov r8d, UI_BLACK
    call fill_rect
    lea edi, [r12+4+THUMB_W/2]
    lea esi, [r13+4+THUMB_H/2-4]
    lea rdx, [s_sl_empty]
    cmp r14d, 2
    jne .ph
    lea rdx, [s_sl_old]
.ph:
    cmp r14d, 0
    jne .ph2
    cmp dword [rbp-56], 0
    je .ph2
    cmp ebx, AUTO_SLOT
    je .ph2
    lea rdx, [s_sl_here]
.ph2:
    mov ecx, UI_DIM
    call draw_text_centered
.text:
    ; latest marker
    cmp dword [rbp-56], 0
    jne .nl
    cmp ebx, [slot_latest]
    jne .nl
    lea edi, [r12+6]
    lea esi, [r13+6]
    mov edx, 38
    mov ecx, 11
    mov r8d, UI_BTN_SEL
    call fill_rect
    lea edi, [r12+8]
    lea esi, [r13+7]
    lea rdx, [s_sl_latest]
    mov ecx, UI_BLACK
    call draw_text
.nl:
    ; overwrite confirmation
    cmp ebx, [slot_confirm]
    jne .nc
    lea edi, [r12+4]
    lea esi, [r13+4+THUMB_H/2-7]
    mov edx, THUMB_W
    mov ecx, 14
    mov r8d, UI_BG2
    call fill_rect
    lea edi, [r12+4+THUMB_W/2]
    lea esi, [r13+4+THUMB_H/2-4]
    lea rdx, [s_sl_again]
    mov ecx, UI_WARN
    call draw_text_centered
.nc:
    ; the slot you're playing in: a gold frame
    cmp ebx, [current_slot]
    jne .nf
    cmp dword [rbp-56], 0
    je .nf
    lea edi, [r12+2]
    lea esi, [r13+2]
    mov edx, THUMB_W+4
    mov ecx, THUMB_H+4
    mov r8d, UI_GOLD
    call rect_outline
.nf:
    ; name and date
    mov edi, ebx
    call tb_slot_name
    lea edi, [r12+5]
    lea esi, [r13+79]
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text
    cmp r14d, 1
    jne .old
    imul r15d, ebx, INFO_BYTES
    call tb_reset
    mov eax, [slot_info+r15+8]
    CLAMP eax, 0, 11
    lea rdi, [month_names+rax*4]
    call tb_str
    mov edi, ' '
    call tb_char
    movsxd rdi, dword [slot_info+r15+4]
    call tb_num_plain
    lea edi, [r12+CARD_W-5]
    lea esi, [r13+79]
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call draw_text_right
    ; population and money
    call tb_reset
    lea rdi, [s_sl_pop]
    call tb_str
    movsxd rdi, dword [slot_info+r15+12]
    call tb_num
    lea edi, [r12+5]
    lea esi, [r13+89]
    lea rdx, [textbuf]
    mov ecx, UI_TEXT
    call draw_text
    call tb_reset
    mov rdi, [slot_info+r15+16]
    call tb_money
    lea edi, [r12+CARD_W-5]
    lea esi, [r13+89]
    lea rdx, [textbuf]
    mov ecx, UI_GOOD
    call draw_text_right
    jmp .click
.old:
    cmp r14d, 2
    jne .click
    lea edi, [r12+5]
    lea esi, [r13+89]
    lea rdx, [s_sl_older]
    mov ecx, UI_DIM
    call draw_text
.click:
    cmp dword [rbp-60], 0
    je .next
    cmp dword [rbp-56], 0
    je .doload
    ; save: an occupied slot asks twice
    test r14d, r14d
    jz .dosave
    cmp ebx, [slot_confirm]
    je .dosave
    mov [slot_confirm], ebx
    jmp .next
.dosave:
    mov [current_slot], ebx
    mov rdi, [slot_files+rbx*8]
    call save_city_to
    mov dword [panel], PANEL_NONE
    mov dword [slot_confirm], -1
    jmp .out
.doload:
    cmp ebx, AUTO_SLOT
    je .la
    mov [current_slot], ebx
.la:
    mov rdi, [slot_files+rbx*8]
    call load_city_from
    mov dword [panel], PANEL_NONE
    jmp .out
.next:
    inc ebx
    jmp .card
.bottom:
    ; New city (at start-up) or Close
    mov edi, [rbp-48]
    add edi, PANEL_SW-110
    mov esi, [rbp-52]
    add esi, PANEL_SH-20
    mov edx, 100
    lea rcx, [s_sl_close]
    xor r8d, r8d
    cmp dword [slots_start], 0
    je .b
    lea rcx, [s_sl_new]
    mov r8d, 1
.b:
    call text_button
    test eax, eax
    jz .out
    mov dword [panel], PANEL_NONE
.out:
    RETURN
