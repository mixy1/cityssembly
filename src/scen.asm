; =====================================================================
;  SCENARIOS (beta) - a goal, a map and a deadline
;
;  From the menu: five challenges, each a new city on its own map with
;  its own difficulty and a goal to reach before a year.  The goal stands
;  above the dock; when it's met (or the time is up) the city says
;  so, and the game goes on.
;
;  Also the map types on the welcome card: valley, island, lakes,
;  plains, delta (the map is made again behind the card).
; =====================================================================
SCN_N        equ 5
SG_POP      equ 0               ; people
SG_AIR      equ 1               ; people and air passengers
SG_TRANSIT  equ 2               ; people, a third not by car
SG_GREEN    equ 3               ; people, never a coal plant

section .bss
alignb 4
scen_state:                     ; (saved: "SCEN")
scen_id     resd 1              ; 1.. the scenario, 0 none
scen_until  resd 1              ; the year it must be done by
scen_done   resd 1              ; 1 won, 2 lost
scen_state_end:

section .data
; name, text, seed, map, difficulty, goal, people, extra, years
%macro SCEN 9
    dq %1, %2
    dd %3, %4, %5, %6, %7, %8, %9, 0
%endmacro
SCN_BYTES    equ 48
scen_tab:
    SCEN scn1, sct1, 314159, MT_VALLEY, 2, SG_POP, 20000, 0, 10
    SCEN scn2, sct2, 271828, MT_ISLAND, 0, SG_AIR, 12000, 2000, 15
    SCEN scn3, sct3, 161803, MT_VALLEY, 0, SG_TRANSIT, 15000, 0, 15
    SCEN scn4, sct4, 141421, MT_PLAINS, 0, SG_GREEN, 25000, 0, 20
    SCEN scn5, sct5, 173205, MT_DELTA, 0, SG_POP, 15000, 0, 12
scn1        db "Boom Town", 0
sct1        db "Hard. 20,000 people in 10 years.", 0
scn2        db "Island Resort", 0
sct2        db "An island. 12,000 people and 2,000 air passengers a month in 15 years.", 0
scn3        db "Transit Utopia", 0
sct3        db "15,000 people, a third of their trips not by car, in 15 years.", 0
scn4        db "Green Valley", 0
sct4        db "Dry plains. 25,000 people, never a coal plant, in 20 years.", 0
scn5        db "Flood Plain", 0
sct5        db "A wide river that floods. 15,000 people in 12 years.", 0
s_sc_title  db "Scenarios", 0
s_sc_start  db "Start", 0
s_sc_line   db "SCENARIO ", 0
s_sc_by     db " - by ", 0
s_sc_won    db "Scenario complete: ", 0
s_sc_won2   db "! The city is yours to keep building.", 0
s_sc_lost   db "Time's up for ", 0
s_sc_lost2  db " - the goal wasn't reached. Play on, or try again.", 0
s_sc_coal   db " - a coal plant was built.", 0
s_sc_menu   db "Scenarios...", 0
s_sc_won_l  db "  - done!", 0
s_sc_lost_l db "  - time's up", 0
mt_names    dq mtn0, mtn1, mtn2, mtn3, mtn4
mtn0        db "Valley", 0
mtn1        db "Island", 0
mtn2        db "Lakes", 0
mtn3        db "Plains", 0
mtn4        db "Delta", 0
s_mt_tip    db "The land: the map is made again", 0

section .text

scen_reset:
    mov dword [scen_id], 0
    mov dword [scen_until], 0
    mov dword [scen_done], 0
    ret

; start scenario edi (0-based)
FUNC scen_start, 16
    mov ebx, edi
    imul r12d, ebx, SCN_BYTES
    lea r12, [scen_tab+r12]
    mov eax, [r12+20]
    mov [map_type], eax
    mov edi, [r12+16]
    call new_city_seed
    mov dword [map_type], MT_VALLEY
    mov eax, [r12+24]
    mov [difficulty], eax
    lea eax, [rbx+1]
    mov [scen_id], eax
    mov eax, [year]
    add eax, [r12+40]
    mov [scen_until], eax
    mov dword [scen_done], 0
    mov dword [welcome], 0
    mov dword [panel], PANEL_NONE
    ; say what it's about
    call tb_reset
    mov rdi, [r12]
    call tb_str
    mov edi, ':'
    call tb_char
    mov edi, ' '
    call tb_char
    mov rdi, [r12+8]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_GOLD
    mov edx, -1
    mov ecx, -1
    call notify
    RETURN

; is the goal met? (r12 the scenario) -> eax 1
FUNC scen_met
    xor eax, eax
    mov ecx, [population]
    cmp ecx, [r12+32]
    jl .out
    mov edx, [r12+28]
    cmp edx, SG_AIR
    jne .t
    mov ecx, [air_pax]
    cmp ecx, [r12+36]
    jl .out
    jmp .yes
.t:
    cmp edx, SG_TRANSIT
    jne .yes
    mov ecx, [bus_riders]
    add ecx, [metro_riders]
    add ecx, [train_riders]
    add ecx, [tram_riders]
    add ecx, [walkers]
    imul ecx, ecx, 3
    cmp ecx, [population]
    jl .out
.yes:
    mov eax, 1
.out:
    RETURN

; the month (beta)
FUNC scen_month
    cmp dword [beta_on], 0
    je .out
    mov eax, [scen_id]
    test eax, eax
    jz .out
    cmp dword [scen_done], 0
    jne .out
    dec eax
    imul r12d, eax, SCN_BYTES
    lea r12, [scen_tab+r12]
    ; green: a coal plant loses it
    cmp dword [r12+28], SG_GREEN
    jne .m
    cmp dword [svc_count+BK_COAL*4], 0
    je .m
    mov dword [scen_done], 2
    call tb_reset
    lea rdi, [s_sc_lost]
    call tb_str
    mov rdi, [r12]
    call tb_str
    lea rdi, [s_sc_coal]
    call tb_str
    jmp .say
.m:
    call scen_met
    test eax, eax
    jz .late
    mov dword [scen_done], 1
    call tb_reset
    lea rdi, [s_sc_won]
    call tb_str
    mov rdi, [r12]
    call tb_str
    lea rdi, [s_sc_won2]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_GOLD
    mov edx, -1
    mov ecx, -1
    call notify
    call fx_milestone
    jmp .out
.late:
    mov eax, [year]
    cmp eax, [scen_until]
    jl .out
    mov dword [scen_done], 2
    call tb_reset
    lea rdi, [s_sc_lost]
    call tb_str
    mov rdi, [r12]
    call tb_str
    lea rdi, [s_sc_lost2]
    call tb_str
.say:
    lea rdi, [textbuf]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; the goal under the top bar (beta, ui)
FUNC scen_draw
    cmp dword [beta_on], 0
    je .out
    cmp dword [tool], T_DISTRICT    ; (the districts' bar is there)
    je .out
    mov eax, [scen_id]
    test eax, eax
    jz .out
    dec eax
    imul r12d, eax, SCN_BYTES
    lea r12, [scen_tab+r12]
    call tb_reset
    mov rdi, [r12]
    call tb_str
    lea rdi, [s_sc_by]
    call tb_str
    mov edi, [scen_until]
    call tb_year
    mov edi, ':'
    call tb_char
    mov edi, ' '
    call tb_char
    mov rdi, [r12+8]
    call tb_str
    mov ecx, UI_GOLD
    cmp dword [scen_done], 0
    je .d
    lea rdi, [s_sc_won_l]
    mov ecx, UI_GOOD
    cmp dword [scen_done], 1
    je .dw
    lea rdi, [s_sc_lost_l]
    mov ecx, UI_BAD
.dw:
    push rcx
    push rcx
    call tb_str
    pop rcx
    pop rcx
.d:
    mov edi, 8
    mov esi, [ui_h]
    sub esi, DOCK_BTN+40
    lea rdx, [textbuf]
    call draw_text
.out:
    RETURN

; the Scenarios panel
SCP_W       equ 440
SCP_H       equ 190

FUNC draw_scenarios, 16
    mov r12d, [ui_w]
    sub r12d, SCP_W
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, SCP_H
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, SCP_W
    mov ecx, SCP_H
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, SCP_W
    mov ecx, SCP_H
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_sc_title]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    add r13d, 30
    xor ebx, ebx
.s:
    imul r14d, ebx, SCN_BYTES
    lea r14, [scen_tab+r14]
    lea edi, [r12+10]
    mov esi, r13d
    mov rdx, [r14]
    mov ecx, UI_TEXT
    call draw_text
    lea edi, [r12+10]
    lea esi, [r13+10]
    mov rdx, [r14+8]
    mov ecx, UI_DIM
    call draw_text
    lea edi, [r12+SCP_W-70]
    lea esi, [r13+2]
    mov edx, 60
    lea rcx, [s_sc_start]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .n
    mov edi, ebx
    call scen_start
    jmp .out
.n:
    add r13d, 30
    inc ebx
    cmp ebx, SCN_N
    jl .s
.out:
    RETURN

; the map types on the welcome card (beta; edi x, esi y)
FUNC welcome_maps
    cmp dword [beta_on], 0
    je .out
    mov r12d, edi
    mov r13d, esi
    xor ebx, ebx
.b:
    imul edi, ebx, 54
    add edi, r12d
    mov esi, r13d
    mov edx, 52
    mov rcx, [mt_names+rbx*8]
    xor r8d, r8d
    cmp ebx, [map_type]
    sete r8b
    call text_button
    test eax, eax
    jz .n
    cmp ebx, [map_type]
    je .n
    ; the same seed, other land
    mov [map_type], ebx
    mov eax, [difficulty]
    push rax
    push rax
    mov edi, [world_seed]
    call new_city_seed
    pop rax
    pop rax
    mov [difficulty], eax
.n:
    imul edi, ebx, 54
    add edi, r12d
    mov esi, r13d
    mov edx, 52
    mov ecx, 14
    call ui_over
    test eax, eax
    jz .nt
    lea rax, [s_mt_tip]
    mov [tooltip], rax
.nt:
    inc ebx
    cmp ebx, MT_TYPES
    jl .b
.out:
    RETURN

; a year (edi) into the text builder, without a thousands comma
tb_year:
    mov eax, edi
    lea r8, [numbuf+15]
    mov byte [r8], 0
    mov ecx, 10
.d:
    xor edx, edx
    div ecx
    add dl, '0'
    dec r8
    mov [r8], dl
    test eax, eax
    jnz .d
    mov rdi, r8
    jmp tb_str
