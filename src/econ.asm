; =====================================================================
;  ECON (beta) - decline, credit, and running out of money
;
;  - Decline: a building a level above what its surroundings support
;    loses that level after a couple of months (the classic game only
;    let buildings two levels too high fall).  The month's count is
;    reported when it's large.
;  - Credit rating (AAA .. B): months in the red over the last year and
;    loans running lower it, money in the bank raises it.  New loans
;    cost more the lower it is.
;  - An empty treasury: after two months in the red a warning, after
;    three the services are cut back to 70%, after six the region bails
;    the city out - at the price of taxes 2% higher.
; =====================================================================
section .bss
declined_month resd 1

section .data
cr_names    dq crn0, crn1, crn2, crn3, crn4, crn5
crn0         db "AAA", 0
crn1         db "AA", 0
crn2         db "A", 0
crn3         db "BBB", 0
crn4         db "BB", 0
crn5         db "B", 0
cr_floor    db 90, 75, 60, 45, 30, 0
cr_cost     dd 100, 110, 120, 135, 150, 175   ; what a loan costs, %
s_cr_lbl    db "Credit: ", 0
s_cr_cost   db ", loans cost ", 0
s_cr_more   db "% more", 0
s_cr_tip    db "Months in the red and loans lower it; money in the bank raises it", 0
s_ec_warn   db "Two months in the red: next month the services get cut back.", 0
s_ec_cut    db "The treasury is empty: services cut back to 70%.", 0
s_ec_bail   db "The region bailed the city out: ", 0
s_ec_bail2  db " - taxes are 2% higher, services back to full.", 0
s_ec_decl   db " buildings lost a level last month - the inspector says what they need.", 0

section .text

; the credit rating -> eax 0 (AAA) .. 5 (B)
credit_grade:
    mov eax, [red_hist]
    and eax, 0xFFF
    popcnt ecx, eax
    imul ecx, ecx, 12
    mov eax, 100
    sub eax, ecx
    xor ecx, ecx
.l:
    cmp dword [loan_left+rcx*4], 0
    je .ln
    sub eax, 12
.ln:
    inc ecx
    cmp ecx, 3
    jl .l
    ; six months of expenses in the bank
    mov ecx, [expense_last]
    imul rcx, rcx, 6
    cmp [money], rcx
    jl .g
    add eax, 10
.g:
    xor ecx, ecx
.f:
    movzx edx, byte [cr_floor+rcx]
    cmp eax, edx
    jge .o
    inc ecx
    cmp ecx, 5
    jl .f
.o: mov eax, ecx
    ret

; a loan was taken (edi which): its payment, by the rating (beta)
loan_taken:
    cmp dword [beta_on], 0
    je .o
    push rdi
    call credit_grade
    pop rdi
    mov ecx, [cr_cost+rax*4]
    mov eax, [loan_payment+rdi*4]
    imul eax, ecx
    xor edx, edx
    mov ecx, 100
    div ecx
    mov [loan_pay_cur+rdi*4], eax
.o: ret

; the month's payment of loan ecx -> edx added (keeps rcx)
loan_due:
    mov eax, [loan_pay_cur+rcx*4]
    test eax, eax
    jnz .a
    mov eax, [loan_payment+rcx*4]
.a: add edx, eax
    ret

; the month's money (beta; after it was settled)
FUNC econ_month
    cmp dword [beta_on], 0
    je .out
    ; the last year in the red
    xor eax, eax
    cmp qword [money], 0
    setl al
    mov ecx, [red_hist]
    shl ecx, 1
    or ecx, eax
    and ecx, 0xFFF
    mov [red_hist], ecx
    test eax, eax
    jnz .red
    mov dword [months_red], 0
    jmp .decl
.red:
    inc dword [months_red]
    mov eax, [months_red]
    cmp eax, 2
    jne .r3
    lea rdi, [s_ec_warn]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
    jmp .decl
.r3:
    cmp eax, 3
    jne .r6
    ; services cut back to 70%
    mov ecx, SV_FIRST
.cut:
    cmp dword [svc_fund+rcx*4], -3
    jle .cn
    mov dword [svc_fund+rcx*4], -3
.cn:
    inc ecx
    cmp ecx, SV_LAST
    jle .cut
    lea rdi, [s_ec_cut]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
    call emergency_pause
    jmp .decl
.r6:
    cmp eax, 6
    jl .decl
    ; bailed out
    mov rax, [money]
    neg rax
    add rax, 25000
    mov r12, rax
    add [money], rax
    xor ecx, ecx
.tx:
    mov eax, [tax_rate+rcx*4]
    add eax, 2
    CLAMP eax, 0, 25
    mov [tax_rate+rcx*4], eax
    inc ecx
    cmp ecx, 4
    jl .tx
    mov dword [months_red], 0
    mov dword [red_hist], 0xFFF
    ; the services back to full
    mov ecx, SV_FIRST
.full:
    cmp dword [svc_fund+rcx*4], 0
    jge .fn
    mov dword [svc_fund+rcx*4], 0
.fn:
    inc ecx
    cmp ecx, SV_LAST
    jle .full
    call tb_reset
    lea rdi, [s_ec_bail]
    call tb_str
    mov rdi, r12
    call tb_money
    lea rdi, [s_ec_bail2]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_BAD
    mov edx, -1
    mov ecx, -1
    call notify
.decl:
    ; many buildings fell a level: say so
    mov eax, [declined_month]
    mov dword [declined_month], 0
    cmp eax, 10
    jl .out
    call tb_reset
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_ec_decl]
    call tb_str
    lea rdi, [textbuf]
    mov esi, UI_WARN
    mov edx, -1
    mov ecx, -1
    call notify
.out:
    RETURN

; the credit line in the budget (beta; edi x, esi y)
FUNC credit_line
    cmp dword [beta_on], 0
    je .out
    mov r12d, edi
    mov r13d, esi
    call credit_grade
    mov ebx, eax
    call tb_reset
    lea rdi, [s_cr_lbl]
    call tb_str
    mov rdi, [cr_names+rbx*8]
    call tb_str
    test ebx, ebx
    jz .d
    lea rdi, [s_cr_cost]
    call tb_str
    mov eax, [cr_cost+rbx*4]
    sub eax, 100
    movsxd rdi, eax
    call tb_num
    lea rdi, [s_cr_more]
    call tb_str
.d:
    mov ecx, UI_GOOD
    cmp ebx, 2
    jle .c
    mov ecx, UI_BAD
.c:
    mov edi, r12d
    mov esi, r13d
    lea rdx, [textbuf]
    call draw_text
    mov edi, r12d
    lea esi, [r13-2]
    mov edx, 200
    mov ecx, 12
    call ui_over
    test eax, eax
    jz .out
    lea rax, [s_cr_tip]
    mov [tooltip], rax
.out:
    RETURN
