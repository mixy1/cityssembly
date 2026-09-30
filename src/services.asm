; =====================================================================
;  SERVICES (beta) - services with room for so many, and their funding
;
;  Every police station, fire station, clinic, hospital and school has
;  room for so many people.  When the city outgrows what its buildings
;  of a kind can take, that service reaches everyone less well (down to
;  about a third): a growing city keeps needing new ones.
;
;  Funding (50% to 150% for each service, in the Services panel) sets
;  both the room and the reach - and the upkeep.
; =====================================================================
SV_FIRST    equ CV_POLICE       ; the services with room: police ..
SV_LAST     equ CV_UNIV         ; .. universities
SV_FLOOR    equ 96              ; the least an overloaded service gives (/256)
ISSUE_LOAD  equ 12

section .bss
cov_cap     resd CV_COUNT       ; people the buildings of a kind take
cov_scale   resd CV_COUNT       ; how well it reaches everyone (/256)
cov_need    resd CV_COUNT       ; people who need it
sv_worst    resd 1              ; the most overloaded kind, 0 if none

section .data
; room in each building, by kind (people)
svc_room    dd 0,0,0,0,0,0,0,0,0                ; power .. incinerator
            dd 4000, 4000, 1500, 6000            ; police, fire, clinic, hospital
            dd 2500, 4000, 10000                 ; schools, high school, university
            times BK_MAX-16 dd 0
sv_names    dq 0, svn1, svn2, svn3, svn4, svn5, svn6
svn1        db "Police", 0
svn2        db "Fire", 0
svn3        db "Health", 0
svn4        db "Schools", 0
svn5        db "High schools", 0
svn6        db "Universities", 0
sv_over     dq 0, svo1, svo2, svo3, svo4, svo5, svo6
svo1        db "Police stations overloaded", 0
svo2        db "Fire stations overloaded", 0
svo3        db "Hospitals overloaded", 0
svo4        db "Schools overloaded", 0
svo5        db "High schools overloaded", 0
svo6        db "Universities overloaded", 0
s_sv_title  db "Services", 0
s_sv_sub    db "Funding sets how far they reach and how many they take - and the upkeep.", 0
s_sv_room   db " places for ", 0
s_sv_for    db " people", 0
s_sv_none   db " none built", 0
s_sv_city   db "City-wide: ", 0
s_sv_ppl    db " places for ", 0
s_sv_ppl2   db " people", 0
s_sv_fund   db "Funding: ", 0
s_sv_btn    db "Services", 0
s_sv_tip    db "Funding for police, fire, health and schools", 0

section .text

; funding of coverage kind edi, in % -> eax (50 .. 150)
sv_fund_pct:
    mov eax, [svc_fund+rdi*4]
    CLAMP eax, -5, 5
    imul eax, eax, 10
    add eax, 100
    ret

; room, need and reach of every service (beta; before the coverage)
FUNC svc_load
    cmp dword [beta_on], 0
    je .out
    lea rdi, [cov_cap]
    mov ecx, CV_COUNT
    xor eax, eax
    rep stosd
    xor ebx, ebx
.b:
    mov eax, [svc_room+rbx*4]
    test eax, eax
    jz .bn
    imul eax, [svc_count+rbx*4]
    mov r12d, eax
    mov edi, ebx
    call bld_rec
    movzx ecx, byte [rax+BI_COV]
    add [cov_cap+rcx*4], r12d
.bn:
    inc ebx
    cmp ebx, BK_COUNT
    jl .b
    mov dword [sv_worst], 0
    mov r13d, 256                   ; the worst reach so far
    mov ebx, 1
.k:
    mov eax, 256
    mov [cov_scale+rbx*4], eax
    mov edi, ebx
    call sv_fund_pct
    mov r14d, eax                   ; funding %
    mov eax, [cov_cap+rbx*4]
    imul eax, r14d
    xor edx, edx
    mov ecx, 100
    div ecx
    mov r12d, eax                   ; room, funded
    mov eax, [population]
    cmp ebx, CV_UNIV
    jne .nd
    shr eax, 1
.nd:
    mov [cov_need+rbx*4], eax
    mov r15d, 256
    cmp ebx, SV_LAST
    ja .f
    test r12d, r12d
    jz .f
    cmp eax, r12d
    jle .f
    ; overloaded: room / need
    mov ecx, eax
    mov eax, r12d
    shl eax, 8
    xor edx, edx
    div ecx
    CLAMP eax, SV_FLOOR, 256
    mov r15d, eax
    cmp eax, 230
    jge .f
    cmp eax, r13d
    jge .f
    mov r13d, eax
    mov [sv_worst], ebx
.f:
    ; funding reaches further or less far: x (100 + funding) / 200
    lea eax, [r14+100]
    imul eax, r15d
    xor edx, edx
    mov ecx, 200
    div ecx
    mov [cov_scale+rbx*4], eax
    inc ebx
    cmp ebx, CV_COUNT
    jl .k
.out:
    RETURN

; upkeep of building kind edi, rax its record, ecx its upkeep so far
; -> ecx with the funding of its service (beta)
sv_upkeep:
    cmp dword [beta_on], 0
    je .o
    push rax
    push rdx
    push rdi
    movzx edi, byte [rax+BI_COV]
    cmp edi, SV_FIRST
    jb .n
    cmp edi, SV_LAST
    ja .n
    push rcx
    call sv_fund_pct
    pop rcx
    imul ecx, eax
    mov eax, ecx
    xor edx, edx
    mov ecx, 100
    div ecx
    mov ecx, eax
.n:
    pop rdi
    pop rdx
    pop rax
.o: ret

; ---------------------------------------------------------------------
;  the Services panel
; ---------------------------------------------------------------------
SV_W        equ 430
SV_H        equ 150

FUNC draw_services, 32
    call svc_load
    mov r12d, [ui_w]
    sub r12d, SV_W
    shr r12d, 1
    mov r13d, [ui_h]
    sub r13d, SV_H
    shr r13d, 1
    mov edi, r12d
    mov esi, r13d
    mov edx, SV_W
    mov ecx, SV_H
    call draw_panel
    mov edi, r12d
    mov esi, r13d
    mov edx, SV_W
    mov ecx, SV_H
    call ui_over
    mov dword [font_scale], 2
    lea edi, [r12+10]
    lea esi, [r13+6]
    lea rdx, [s_sv_title]
    mov ecx, UI_GOLD
    call draw_text
    mov dword [font_scale], 1
    lea edi, [r12+10]
    lea esi, [r13+26]
    lea rdx, [s_sv_sub]
    mov ecx, UI_DIM
    call draw_text
    add r13d, 42
    mov ebx, SV_FIRST
.r:
    mov rdx, [sv_names+rbx*8]
    lea edi, [r12+10]
    mov esi, r13d
    mov ecx, UI_TEXT
    call draw_text
    ; - funding +
    lea edi, [r12+90]
    lea esi, [r13-3]
    mov edx, 14
    lea rcx, [s_minus]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .r1
    cmp dword [svc_fund+rbx*4], -5
    jle .r1
    dec dword [svc_fund+rbx*4]
.r1:
    lea edi, [r12+140]
    lea esi, [r13-3]
    mov edx, 14
    lea rcx, [s_plus]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .r2
    cmp dword [svc_fund+rbx*4], 5
    jge .r2
    inc dword [svc_fund+rbx*4]
.r2:
    call tb_reset
    mov edi, ebx
    call sv_fund_pct
    movsxd rdi, eax
    call tb_pct
    lea edi, [r12+122]
    mov esi, r13d
    lea rdx, [textbuf]
    mov ecx, UI_GOLD
    call draw_text_centered
    ; room for / people
    call tb_reset
    mov ecx, UI_DIM
    cmp dword [cov_cap+rbx*4], 0
    jne .rm
    lea rdi, [s_sv_none]
    call tb_str
    mov ecx, UI_DIM
    jmp .rd
.rm:
    mov edi, ebx
    call sv_fund_pct
    imul eax, [cov_cap+rbx*4]
    xor edx, edx
    mov ecx, 100
    div ecx
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_sv_room]
    call tb_str
    movsxd rdi, dword [cov_need+rbx*4]
    call tb_num
    lea rdi, [s_sv_for]
    call tb_str
    mov ecx, UI_GOOD
    cmp dword [cov_scale+rbx*4], 230
    jge .rd
    mov ecx, UI_BAD
.rd:
    lea edi, [r12+160]
    mov esi, r13d
    lea rdx, [textbuf]
    call draw_text
    add r13d, 15
    inc ebx
    cmp ebx, SV_LAST
    jle .r
    RETURN

; the budget's button to it (beta; edi x, esi y)
FUNC services_button
    cmp dword [beta_on], 0
    je .out
    mov r12d, edi
    mov r13d, esi
    mov edx, 90
    lea rcx, [s_sv_btn]
    xor r8d, r8d
    call text_button
    test eax, eax
    jz .t
    mov dword [panel], PANEL_SERVICES
.t:
    mov edi, r12d
    mov esi, r13d
    mov edx, 90
    mov ecx, 14
    call ui_over
    test eax, eax
    jz .out
    lea rax, [s_sv_tip]
    mov [tooltip], rax
.out:
    RETURN

; a service building in the inspector (beta; rbx tile): the city's room
FUNC service_inspect
    cmp dword [beta_on], 0
    je .out
    movzx edi, byte [rbx+T_SUB]
    cmp dword [svc_room+rdi*4], 0
    je .out
    call bld_rec
    movzx r12d, byte [rax+BI_COV]
    call tb_reset
    lea rdi, [s_sv_city]
    call tb_str
    mov edi, r12d
    call sv_fund_pct
    imul eax, [cov_cap+r12*4]
    xor edx, edx
    mov ecx, 100
    div ecx
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_sv_ppl]
    call tb_str
    movsxd rdi, dword [cov_need+r12*4]
    call tb_num
    lea rdi, [s_sv_ppl2]
    call tb_str
    mov ecx, UI_TEXT
    cmp dword [cov_scale+r12*4], 230
    jge .c
    mov ecx, UI_BAD
.c:
    lea rdx, [textbuf]
    call row_text
    call tb_reset
    lea rdi, [s_sv_fund]
    call tb_str
    mov edi, r12d
    call sv_fund_pct
    movsxd rdi, eax
    call tb_pct
    lea rdx, [textbuf]
    mov ecx, UI_DIM
    call row_text
.out:
    RETURN
