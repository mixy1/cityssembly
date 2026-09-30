; =====================================================================
;  ACHIEVE (beta) - achievements, and the monthly newspaper
;
;  Achievements are the city's (saved with it: "ACHV"), checked every
;  month; each earned one is announced.  The list is in the statistics
;  panel.  The newspaper puts the month's biggest story in a headline.
; =====================================================================
ACH_N       equ 20

section .bss
alignb 4
achv_state:                     ; (saved: "ACHV")
ach_bits    resd 1
ach_wx      resd 1              ; hazards seen through
ach_deals   resd 1              ; deals kept to the end
news_last   resd 1              ; the last headline (not twice running)
achv_state_end:

section .data
ach_names   dq ach0, ach1, ach2, ach3, ach4, ach5, ach6, ach7, ach8, ach9
            dq ach10, ach11, ach12, ach13, ach14, ach15, ach16, ach17, ach18, ach19
ach_descs   dq acd0, acd1, acd2, acd3, acd4, acd5, acd6, acd7, acd8, acd9
            dq acd10, acd11, acd12, acd13, acd14, acd15, acd16, acd17, acd18, acd19
ach0        db "Town Planner", 0
acd0        db "1,000 people", 0
ach1        db "City Slicker", 0
acd1        db "10,000 people", 0
ach2        db "Megalopolis", 0
acd2        db "30,000 people", 0
ach3        db "World Stage", 0
acd3        db "50,000 people", 0
ach4        db "Global Player", 0
acd4        db "80,000 people", 0
ach5        db "Going Underground", 0
acd5        db "1,000 metro riders a month", 0
ach6        db "All Aboard", 0
acd6        db "1,000 train riders a month", 0
ach7        db "Cleared for Takeoff", 0
acd7        db "an airport flying jets", 0
ach8        db "Shipshape", 0
acd8        db "a port ships reach", 0
ach9        db "Free Flowing", 0
acd9        db "90% traffic flow with 20,000 people", 0
ach10       db "Clean Air", 0
acd10       db "no coal plants with 20,000 people", 0
ach11       db "Deep Pockets", 0
acd11       db "$1,000,000 in the bank", 0
ach12       db "Triple A", 0
acd12       db "AAA credit with 30,000 people", 0
ach13       db "Wonder of the World", 0
acd13       db "a wonder built", 0
ach14       db "All the Wonders", 0
acd14       db "all five wonders", 0
ach15       db "Weathered", 0
acd15       db "through 5 storms, floods or snows", 0
ach16       db "Happy Days", 0
acd16       db "80% happy with 10,000 people", 0
ach17       db "Deal Maker", 0
acd17       db "a neighbour's deal kept to the end", 0
ach18       db "Brainy", 0
acd18       db "three universities", 0
ach19       db "Transit City", 0
acd19       db "a fifth of the people ride transit", 0
s_ach_got   db "Achievement: ", 0
s_ach_title db "Achievements", 0
s_ach_btn   db "Achievements", 0
s_ach_n     db " of 20", 0
; the newspaper
s_news      db "THE CITY HERALD: ", 0
nw_heads    dq nw0, nw1, nw2, nw3, nw4, nw5, nw6, nw7, nw8, nw9, nw10, nw11
nw0         db "Gridlock! Drivers lose hours in jams", 0
nw1         db "City coffers run dry", 0
nw2         db "Residents grumble as happiness sinks", 0
nw3         db "Recession bites: factories go quiet", 0
nw4         db "Boom times: exports fetch top dollar", 0
nw5         db "Snow chaos on the roads", 0
nw6         db "Flood waters rise along the river", 0
nw7         db "Heatwave: city sweats, taps run", 0
nw8         db "Traffic flows like never before", 0
nw9         db "Tourists pour in through the airport", 0
nw10        db "City keeps growing - builders busy", 0
nw11        db "Quiet month at city hall", 0

section .text

achv_reset:
    push rdi
    push rcx
    lea rdi, [achv_state]
    mov ecx, achv_state_end - achv_state
    xor eax, eax
    rep stosb
    mov dword [news_last], -1
    pop rcx
    pop rdi
    ret

; is achievement edi met now? -> eax 1
FUNC achv_test
    mov eax, [population]
    cmp edi, 5
    jae .t5
    ; populations
    mov ecx, [ach_pops+rdi*4]
    cmp eax, ecx
    jmp .ge
.t5:
    cmp edi, 5
    jne .t6
    cmp dword [metro_riders], 1000
    jmp .ge
.t6:
    cmp edi, 6
    jne .t7
    cmp dword [train_riders], 1000
    jmp .ge
.t7:
    cmp edi, 7
    jne .t8
    xor ecx, ecx
.ap:
    cmp ecx, [ap_n]
    jge .no
    cmp byte [ap_live+rcx], 2
    je .yes
    inc ecx
    jmp .ap
.t8:
    cmp edi, 8
    jne .t9
    xor ecx, ecx
.pt:
    cmp ecx, [pt_n]
    jge .no
    cmp byte [pt_live+rcx], 0
    jne .yes
    inc ecx
    jmp .pt
.t9:
    cmp edi, 9
    jne .t10
    cmp eax, 20000
    jl .no
    cmp dword [flow_pct], 90
    jmp .ge
.t10:
    cmp edi, 10
    jne .t11
    cmp eax, 20000
    jl .no
    cmp dword [svc_count+BK_COAL*4], 0
    je .yes
    jmp .no
.t11:
    cmp edi, 11
    jne .t12
    cmp qword [money], 1000000
    jge .yes
    jmp .no
.t12:
    cmp edi, 12
    jne .t13
    cmp eax, 30000
    jl .no
    call credit_grade
    test eax, eax
    jz .yes
    jmp .no
.t13:
    cmp edi, 14
    jae .t14
    ; a wonder
    mov ecx, BK_GCENTRAL
.w:
    cmp dword [svc_count+rcx*4], 0
    jne .yes
    inc ecx
    cmp ecx, BK_EXPO
    jle .w
    jmp .no
.t14:
    jne .t15
    mov ecx, BK_GCENTRAL
.w5:
    cmp dword [svc_count+rcx*4], 0
    je .no
    inc ecx
    cmp ecx, BK_EXPO
    jle .w5
    jmp .yes
.t15:
    cmp edi, 15
    jne .t16
    cmp dword [ach_wx], 5
    jmp .ge
.t16:
    cmp edi, 16
    jne .t17
    cmp eax, 10000
    jl .no
    cmp dword [happy_avg], 80
    jmp .ge
.t17:
    cmp edi, 17
    jne .t18
    cmp dword [ach_deals], 1
    jmp .ge
.t18:
    cmp edi, 18
    jne .t19
    cmp dword [svc_count+BK_UNIV*4], 3
    jmp .ge
.t19:
    ; a fifth of the people ride something each month
    cmp eax, 5000
    jl .no
    mov ecx, [bus_riders]
    add ecx, [metro_riders]
    add ecx, [train_riders]
    add ecx, [tram_riders]
    add ecx, [ferry_riders]
    imul ecx, ecx, 5
    cmp ecx, eax
.ge:
    jl .no
.yes:
    mov eax, 1
    RETURN
.no:
    xor eax, eax
    RETURN

section .data
ach_pops    dd 1000, 10000, 30000, 50000, 80000
section .text

; the month (beta): new achievements, the newspaper
FUNC achv_month
    cmp dword [beta_on], 0
    je .out
    ; hazards seen through, deals kept (counted as they end)
    xor ebx, ebx
.a:
    bt dword [ach_bits], ebx
    jc .an
    mov edi, ebx
    call achv_test
    test eax, eax
    jz .an
    bts dword [ach_bits], ebx
    call tb_reset
    lea rdi, [s_ach_got]
    call tb_str
    mov rdi, [ach_names+rbx*8]
    call tb_str
    mov edi, ' '
    call tb_char
    mov edi, '-'
    call tb_char
    mov edi, ' '
    call tb_char
    mov rdi, [ach_descs+rbx*8]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_GOLD
    mov edx, -1
    mov ecx, -1
    call notify
    mov edi, SFX_CHIME
    call sfx_play
.an:
    inc ebx
    cmp ebx, ACH_N
    jl .a
    call newspaper
.out:
    RETURN

; the month's biggest story as a headline
FUNC newspaper
    ; pick the first story that's true
    xor ebx, ebx
    cmp dword [jam_show], 0
    jg .have
    inc ebx
    cmp qword [money], 0
    jl .have
    inc ebx
    cmp dword [happy_avg], 40
    jl .have
    inc ebx
    cmp dword [mk_event], 0
    jl .have
    inc ebx
    cmp dword [mk_event], 0
    jg .have
    inc ebx
    cmp dword [wx_kind], WX_SNOW
    je .have
    inc ebx
    cmp dword [wx_kind], WX_FLOOD
    je .have
    inc ebx
    cmp dword [wx_kind], WX_HEAT
    je .have
    inc ebx
    cmp dword [population], 5000
    jl .nf
    cmp dword [flow_pct], 88
    jge .have
.nf:
    mov ebx, 9
    cmp dword [air_pax], 3000
    jge .have
    inc ebx
    cmp dword [demand], 20
    jge .have
    inc ebx
.have:
    ; only news, and not the same story twice running
    cmp ebx, 11
    jae .out
    cmp ebx, [news_last]
    je .out
.say:
    mov [news_last], ebx
    cmp dword [population], 500
    jl .out
    call tb_reset
    lea rdi, [s_news]
    call tb_str
    mov rdi, [nw_heads+rbx*8]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_TEXT
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; ---------------------------------------------------------------------
;  the Achievements panel
; ---------------------------------------------------------------------
ACH_W       equ 420
ACH_H       equ 250

FUNC draw_achievements, 16
    mov r12d, [ui_w]
    sub r12d, ACH_W
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, ACH_H
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, ACH_W
    mov ecx, ACH_H
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, ACH_W
    mov ecx, ACH_H
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_ach_title]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    ; how many
    call tb_reset
    mov eax, [ach_bits]
    popcnt eax, eax
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_ach_n]
    call tb_str
    lea edi, [r12+ACH_W-10]
    lea esi, [r13+10]
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call draw_text_right
    add r13d, 30
    ; two columns of ten
    xor ebx, ebx
.r:
    mov eax, ebx
    xor edx, edx
    mov ecx, 10
    div ecx
    imul r14d, eax, 205
    add r14d, r12d
    add r14d, 10
    imul r15d, edx, 21
    add r15d, r13d
    mov ecx, UI_DIM
    bt dword [ach_bits], ebx
    jnc .c
    mov ecx, UI_GOLD
.c:
    mov [rbp-48], ecx
    mov edi, r14d
    mov esi, r15d
    mov rdx, [ach_names+rbx*8]
    call draw_text
    mov edi, r14d
    lea esi, [r15+10]
    mov rdx, [ach_descs+rbx*8]
    mov ecx, UI_DIM
    call draw_text
    inc ebx
    cmp ebx, ACH_N
    jl .r
    RETURN

; the statistics panel's button to it (beta; edi x, esi y)
FUNC achv_button
    cmp dword [beta_on], 0
    je .out
    mov edx, 92
    lea rcx, [s_ach_btn]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .out
    mov dword [panel], PANEL_ACHV
.out:
    RETURN
