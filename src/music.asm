; =====================================================================
;  MUSIC - "Five Boroughs": a generative New York score on real
;  instruments (CC0 recordings, see tools/samples/build_samples.py)
;
;  One bar at a time, in 8-bar sections.  The style follows the city:
;    night     Village Vanguard   swing: ride, walking upright bass,
;                                 Steinway comping, harmon trumpet / sax
;    day       Brooklyn boom bap  dusty drums, lo-fi piano chops, vinyl,
;                                 upright bass, sax phrases
;    day       Nuyorican salsa    clave 2-3, congas, bongos, cowbell,
;                                 guiro, piano montuno, tumbao bass, brass
;    morning   Broadway           2-feel, stride piano, strings, clarinet
;    fires     Noir               slow minor ballad, tenor sax, strings,
;                                 sirens across the city
;  Sections alternate between the band (A) and a featured lead (B); the
;  last bar of a section gets a fill.  Small towns get a smaller band.
; =====================================================================

ST_VANGUARD equ 0
ST_BOOMBAP  equ 1
ST_SALSA    equ 2
ST_BROADWAY equ 3
ST_NOIR     equ 4

; chord qualities
Q_MAJ7 equ 0
Q_M7   equ 1
Q_DOM7 equ 2
Q_M7B5 equ 3

section .bss
mus_role        resd 1          ; 0 band, 1 lead feature
mus_swing       resd 1          ; 0 straight, 1 swung 8ths, 2 swung 16ths
mus_scale       resq 1
mel_prev        resd 1
riff_step       resb 8
riff_deg        resb 8
riff_len        resd 1

section .data
force_style     dd -1           ; --wav tests pin a style
solo_inst       dd -1           ; ... and can solo an instrument

;               vanguard boombap salsa broadway noir
style_tempo dd  132,     88,     188,  148,     70
style_swing dd  1,       2,      0,    1,       1
style_drums dq  dr_vanguard, dr_boombap, 0, dr_broadway, dr_noir

; 16th steps -> ticks (12 per beat) for straight / swung 8ths / swung 16ths
sub_ticks   db 0, 3, 6, 9,   0, 4, 8, 10,   0, 4, 6, 10

chord_tones db 0,4,7,11,  0,3,7,10,  0,4,7,10,  0,3,6,10
voicings    db 4,7,11,14, 3,7,10,14, 4,9,10,14, 3,6,10,12   ; rootless (3 7 9 / 13)
major_scale db 0,2,4,5,7,9,11
minor_scale db 0,2,3,5,7,8,10
blues_scale db 0,3,5,6,7,10,12

; progressions: 8 bars x 2 half-bars of (semitones above key, quality)
prog_autumn:    ; ii V | I IV | vii-o III7 | vi vi   (Autumn in New York)
    db 2,1, 2,1, 7,2, 7,2, 0,0, 0,0, 5,0, 5,0
    db 11,3, 11,3, 4,2, 4,2, 9,1, 9,1, 9,1, 7,2
prog_downtown:  ; ii-V | I | IV | iii-VI | ii | V | I-vi | ii-V
    db 2,1, 7,2, 0,0, 0,0, 5,0, 5,0, 4,1, 9,2
    db 2,1, 2,1, 7,2, 7,2, 0,0, 9,1, 2,1, 7,2
prog_bap:       ; i9 | i9 | iv9 | iv9 | i9 | i9 | bVI | V7
    db 0,1, 0,1, 0,1, 0,1, 5,1, 5,1, 5,1, 5,1
    db 0,1, 0,1, 0,1, 0,1, 8,0, 8,0, 7,2, 7,2
prog_bap2:      ; ii | V | I | vi  x2
    db 2,1, 2,1, 7,2, 7,2, 0,0, 0,0, 9,1, 9,1
    db 2,1, 2,1, 7,2, 7,2, 0,0, 0,0, 9,1, 9,1
prog_salsa:     ; i | iv | V | i   x2  (minor montuno)
    db 0,1, 0,1, 5,1, 5,1, 7,2, 7,2, 0,1, 0,1
    db 0,1, 0,1, 5,1, 5,1, 7,2, 7,2, 0,1, 7,2
prog_salsa2:    ; I | IV | V | IV  x2
    db 0,0, 0,0, 5,0, 5,0, 7,2, 7,2, 5,0, 5,0
    db 0,0, 0,0, 5,0, 5,0, 7,2, 7,2, 0,0, 7,2
prog_broadway:  ; I VI7 | ii V7 | iii VI7 | ii V7  (rhythm changes-ish)
    db 0,0, 9,2, 2,1, 7,2, 4,1, 9,2, 2,1, 7,2
    db 0,0, 9,2, 2,1, 7,2, 5,0, 5,0, 7,2, 0,0
prog_noir:      ; i | i | iv | iv | bVI | ii-o V7 | i | V7
    db 0,1, 0,1, 0,1, 0,1, 5,1, 5,1, 5,1, 5,1
    db 8,0, 8,0, 2,3, 7,2, 0,1, 0,1, 7,2, 7,2
style_prog  dq prog_autumn, prog_bap, prog_salsa, prog_broadway, prog_noir
style_prog2 dq prog_downtown, prog_bap2, prog_salsa2, prog_broadway, prog_noir

; drums: 16th step, instrument, velocity, chance (255 = always); 255 ends
dr_vanguard:
    db 0,I_RIDE2,78,255, 4,I_RIDE2,96,255, 6,I_RIDE2,52,230, 8,I_RIDE2,80,255
    db 12,I_RIDE2,98,255, 14,I_RIDE2,56,230
    db 4,I_HATF,64,255, 12,I_HATF,66,255
    db 0,I_KICK2,22,150, 8,I_KICK2,20,110
    db 255
dr_boombap:
    db 0,I_KICK2,118,255, 5,I_KICK2,80,120, 10,I_KICK2,108,255, 11,I_KICK2,70,90
    db 4,I_SNARE,112,255, 12,I_SNARE,116,255, 7,I_SNARE,30,110, 15,I_SNARE,34,90
    db 0,I_HATC,70,255, 2,I_HATC,48,255, 4,I_HATC,64,255, 6,I_HATC,46,255
    db 8,I_HATC,68,255, 10,I_HATC,48,255, 12,I_HATC,64,255, 14,I_HATO,40,140
    db 3,I_HATC,26,90, 9,I_HATC,26,90
    db 255
dr_broadway:
    db 0,I_KICK2,34,255, 8,I_KICK2,30,255, 4,I_HATF,60,255, 12,I_HATF,62,255
    db 0,I_RIDE2,46,255, 4,I_RIDE2,58,255, 8,I_RIDE2,46,255, 12,I_RIDE2,58,255
    db 6,I_RIDE2,34,160, 14,I_RIDE2,34,160
    db 4,I_BRUSH,50,255, 12,I_BRUSH,54,255
    db 255
dr_noir:
    db 0,I_RIDE2,44,255, 8,I_RIDE2,40,255, 12,I_RIDE2,36,180
    db 4,I_BRUSH,46,255, 12,I_BRUSH,50,255, 4,I_HATF,40,255, 12,I_HATF,40,255
    db 0,I_KICK2,30,120
    db 255
; salsa, 2-3 son clave: the "2" bar and the "3" bar
dr_salsa_2:
    db 4,I_CLAVES,96,255, 8,I_CLAVES,96,255
    db 255
dr_salsa_3:
    db 0,I_CLAVES,96,255, 6,I_CLAVES,96,255, 12,I_CLAVES,96,255
    db 255
dr_salsa:       ; both bars: bell, tumbao, martillo, guiro
    db 0,I_COWBELL,92,255, 4,I_COWBELL,60,255, 8,I_COWBELL,84,255, 12,I_COWBELL,60,255
    db 2,I_COWBELL,42,120, 10,I_COWBELL,42,120
    db 4,I_SLAP,96,255, 12,I_CONGA,92,255, 14,I_TUMBA,96,255
    db 0,I_CONGA,26,255, 2,I_CONGA,22,200, 8,I_CONGA,26,255, 10,I_CONGA,22,200
    db 0,I_BONGOH,70,255, 2,I_BONGOH,44,255, 4,I_BONGOH,58,255, 6,I_BONGOL,62,200
    db 8,I_BONGOH,66,255, 10,I_BONGOH,44,255, 12,I_BONGOH,58,255, 14,I_BONGOH,48,255
    db 0,I_GUIRO,78,255, 2,I_GUIRO,40,255, 4,I_GUIRO,62,255, 6,I_GUIRO,40,255
    db 8,I_GUIRO,76,255, 10,I_GUIRO,40,255, 12,I_GUIRO,62,255, 14,I_GUIRO,40,255
    db 255
dr_small:       ; a tiny town: brushes and a quiet hat
    db 4,I_HATF,44,255, 12,I_HATF,46,255, 0,I_BRUSH,30,200, 8,I_BRUSH,30,200
    db 255

; piano comping rhythms for swing (16th steps, 255 ends): Charleston,
; anticipations, "on the and"
comp_swing  db 0,6,255,0,  6,14,255,0,  2,10,255,0,  0,10,255,0,  4,14,255,0,  6,255,0,0
; salsa montuno: 8th positions per clave bar (255 ends)
montuno_2   db 0,2,3,5,6,255,0,0
montuno_3   db 1,2,4,6,7,255,0,0
; lead rhythm slots (16th steps across 2 bars) per style family
mel_slots_swing db 0,6,8,14, 16,22,24,30
mel_slots_bap   db 2,4,7,10, 18,20,23,26
mel_slots_slow  db 0,8,12,16, 24,28,30,31
; salsa brass mambo: 16th steps over two bars
mambo_steps db 2,6,10,12, 18,22,24,28

section .text

; ---------------------------------------------------------------------
FUNC music_init
    mov dword [mus_key], 53
    mov dword [mus_style], ST_VANGUARD
    lea rax, [prog_autumn]
    mov [mus_prog], rax
    lea rax, [major_scale]
    mov [mus_scale], rax
    mov dword [mus_swing], 1
    mov qword [mus_next_bar], SR/2
    mov dword [mel_prev], 72
    call music_set_tempo
    RETURN

FUNC music_set_tempo
    mov eax, [mus_style]
    mov ecx, [style_tempo+rax*4]
    mov [mus_tempo], ecx
    mov eax, SR*60
    xor edx, edx
    imul ecx, ecx, 12
    div ecx
    mov [mus_tick], eax
    RETURN

; 16th step (edi 0..31) -> tick in the bar pair, using the style's swing
step_tick:
    mov eax, edi
    shr eax, 2
    imul eax, eax, 12
    mov ecx, edi
    and ecx, 3
    mov edx, [mus_swing]
    lea edx, [rdx*4+rcx]
    movzx ecx, byte [sub_ticks+rdx]
    add eax, ecx
    ret

; schedule a note: (edi inst, esi note, edx tick in bar, ecx dur ticks, xmm0 vel)
FUNC mnote, 16
    movss [rbp-48], xmm0
    mov r12d, edi
    mov r13d, esi
    mov eax, edx
    imul eax, [mus_tick]
    movsxd r14, eax
    add r14, [mus_next_bar]
    ; a little human looseness (a millisecond or two)
    call rand
    and eax, 127
    sub eax, 64
    movsxd rax, eax
    add r14, rax
    jns .t
    xor r14, r14
.t:
    mov eax, ecx
    imul eax, [mus_tick]
    mov r15d, eax
    call rand
    and eax, 31
    cvtsi2ss xmm1, eax
    mulss xmm1, [f_velvar]
    addss xmm1, [f_velbase]
    movss xmm0, [rbp-48]
    mulss xmm0, [music_vol]
    mulss xmm0, xmm1
    xorps xmm1, xmm1
    mov rsi, r14
    mov edi, r12d
    mov edx, r13d
    mov ecx, r15d
    call ev_add
    RETURN
section .data
f_velvar  dd 0.006
f_velbase dd 0.90
section .text

; vel (edi 0..127) -> xmm0
vel_f:
    cvtsi2ss xmm0, edi
    mulss xmm0, [f_inv127]
    ret

; fit note (edi) into [esi, edx) by octaves -> eax
fit_range:
    mov eax, edi
.lo:
    cmp eax, esi
    jge .hi
    add eax, 12
    jmp .lo
.hi:
    cmp eax, edx
    jl .o
    sub eax, 12
    jmp .hi
.o: ret

; chord tone (edi half, esi index 0..3) -> eax midi (key-relative + key)
chord_tone:
    mov eax, [chord_root+rdi*4]
    add eax, [mus_key]
    mov ecx, [chord_q+rdi*4]
    lea rcx, [chord_tones+rcx*4]
    movzx esi, byte [rcx+rsi]
    add eax, esi
    ret

; voicing note (edi half, esi index 0..3) -> eax midi
voicing_tone:
    mov eax, [chord_root+rdi*4]
    add eax, [mus_key]
    mov ecx, [chord_q+rdi*4]
    lea rcx, [voicings+rcx*4]
    movzx esi, byte [rcx+rsi]
    add eax, esi
    ret

; ---------------------------------------------------------------------
;  pick a style for the next section
; ---------------------------------------------------------------------
FUNC music_pick_style
    mov ebx, [force_style]
    test ebx, ebx
    jns .set
    mov eax, [tod]
    shr eax, 8
    mov ebx, ST_VANGUARD            ; night and evening
    cmp eax, 48
    jl .night
    cmp eax, 96
    jl .morning
    cmp eax, 172
    jl .day
    jmp .fire
.night:
    call rand
    and eax, 7
    jnz .fire
    mov ebx, ST_NOIR                ; now and then, a darker night
    jmp .fire
.morning:
    mov ebx, ST_BROADWAY
    jmp .fire
.day:
    ; keep the groove going for a while, then maybe switch
    mov ebx, [mus_style]
    cmp ebx, ST_BOOMBAP
    je .dk
    cmp ebx, ST_SALSA
    je .dk
    jmp .dp
.dk:
    call rand
    and eax, 3
    jnz .fire
.dp:
    call rand
    and eax, 1
    mov ebx, ST_BOOMBAP
    jz .fire
    mov ebx, ST_SALSA
.fire:
    cmp dword [cnt_fire], 0
    je .set
    mov ebx, ST_NOIR
.set:
    CLAMP ebx, 0, 4
    mov [mus_style], ebx
    ; progression (two per style)
    call rand
    test eax, 1
    mov rax, [style_prog+rbx*8]
    jz .p
    mov rax, [style_prog2+rbx*8]
.p:
    mov [mus_prog], rax
    mov eax, [style_swing+rbx*4]
    mov [mus_swing], eax
    ; scale for melodies
    lea rax, [major_scale]
    cmp ebx, ST_NOIR
    je .mn
    cmp ebx, ST_BOOMBAP
    je .bl
    mov rcx, [mus_prog]
    lea rdx, [prog_salsa]
    cmp rcx, rdx
    jne .sc
.mn:
    lea rax, [minor_scale]
    jmp .sc
.bl:
    lea rax, [blues_scale]
.sc:
    mov [mus_scale], rax
    call music_set_tempo
    ; the band grows with the city
    xor eax, eax
    mov ecx, [population]
    cmp ecx, 80
    jl .i
    inc eax
    cmp ecx, 700
    jl .i
    inc eax
    cmp ecx, 3000
    jl .i
    inc eax
.i:
    mov [mus_intensity], eax
    cmp dword [force_style], 0
    jl .ni
    mov dword [mus_intensity], 3
.ni:
    ; lead instrument
    mov ecx, I_HARMON
    cmp ebx, ST_VANGUARD
    jne .l1
    call rand
    test eax, 3
    mov ecx, I_HARMON
    jnz .l9
    mov ecx, I_SAX
    jmp .l9
.l1:
    mov ecx, I_SAX
    cmp ebx, ST_BOOMBAP
    je .l9
    cmp ebx, ST_NOIR
    je .l9
    mov ecx, I_CLAR
    cmp ebx, ST_BROADWAY
    je .l9
    mov ecx, I_TPT                  ; salsa: the brass section
.l9:
    mov [mus_lead], ecx
    call make_riff
    RETURN

; a two-bar motif: slots from the style's rhythm table, scale steps
FUNC make_riff
    lea r12, [mel_slots_swing]
    mov eax, [mus_style]
    cmp eax, ST_BOOMBAP
    jne .a
    lea r12, [mel_slots_bap]
.a:
    cmp eax, ST_NOIR
    jne .b
    lea r12, [mel_slots_slow]
.b:
    cmp eax, ST_SALSA
    jne .c
    lea r12, [mambo_steps]
.c:
    mov edi, 3
    call rand_range
    lea r13d, [rax+4]               ; 4..6 notes
    mov [riff_len], r13d
    xor ebx, ebx                    ; slot index
    xor r14d, r14d                  ; note index
    xor r15d, r15d                  ; running degree
.n:
    cmp r14d, r13d
    jge .out
    ; spread notes over the 8 slots
    mov eax, 8
    sub eax, ebx
    mov ecx, r13d
    sub ecx, r14d
    sub eax, ecx
    jle .take
    lea edi, [rax+1]
    CLAMP edi, 1, 2
    call rand_range
    add ebx, eax
.take:
    CLAMP ebx, 0, 7
    movzx eax, byte [r12+rbx]
    mov [riff_step+r14], al
    ; stepwise with the odd leap
    call rand
    and eax, 7
    movzx eax, byte [riff_moves+rax]
    movsx eax, al
    add r15d, eax
    CLAMP r15d, -4, 6
    mov [riff_deg+r14], r15b
    inc ebx
    inc r14d
    jmp .n
.out:
    RETURN
section .data
riff_moves db 1, 1, -1, -1, 2, -2, 0, 3
section .text

; scale degree (edi, may be negative) -> midi around the key -> eax
degree_note:
    mov eax, edi
    add eax, 70
    xor edx, edx
    mov ecx, 7
    div ecx                         ; eax octave+10, edx index
    sub eax, 10
    imul eax, 12
    mov rcx, [mus_scale]
    movzx ecx, byte [rcx+rdx]
    add eax, ecx
    add eax, [mus_key]
    ret

; nudge a midi note (edi) onto a tone of half-bar esi's chord -> eax
snap_chord:
    push rbx
    mov ebx, edi
    xor r8d, r8d
.t:
    mov eax, ebx
    sub eax, [mus_key]
    sub eax, [chord_root+rsi*4]
    add eax, 120
    xor edx, edx
    mov ecx, 12
    div ecx                         ; edx interval
    mov eax, [chord_q+rsi*4]
    lea rcx, [chord_tones+rax*4]
    xor eax, eax
.c:
    cmp dl, [rcx+rax]
    je .ok
    inc eax
    cmp eax, 4
    jl .c
    ; try a semitone down, then up
    inc r8d
    cmp r8d, 1
    jne .u
    dec ebx
    jmp .t
.u:
    cmp r8d, 2
    jne .ok0
    add ebx, 2
    jmp .t
.ok0:
    dec ebx
.ok:
    mov eax, ebx
    pop rbx
    ret

; ---------------------------------------------------------------------
;  compose_bar: write every part for the bar starting at mus_next_bar
; ---------------------------------------------------------------------
FUNC compose_bar, 32
    cmp dword [music_on], 0
    je .advance
    cmp dword [mus_bar], 0
    jne .nosec
    call music_pick_style
    ; sections alternate band / featured lead; modulate now and then
    inc dword [mus_sections]
    mov eax, [mus_sections]
    and eax, 1
    mov [mus_role], eax
    test dword [mus_sections], 3
    jnz .nosec
    mov eax, [mus_key]
    add eax, 5
    cmp eax, 60
    jl .k
    sub eax, 12
.k:
    mov [mus_key], eax
.nosec:
    ; chords for both half bars (+ the next bar's root)
    mov rsi, [mus_prog]
    mov eax, [mus_bar]
    shl eax, 2
    movzx ecx, byte [rsi+rax]
    mov [chord_root], ecx
    movzx ecx, byte [rsi+rax+1]
    mov [chord_q], ecx
    movzx ecx, byte [rsi+rax+2]
    mov [chord_root+4], ecx
    movzx ecx, byte [rsi+rax+3]
    mov [chord_q+4], ecx
    mov eax, [mus_bar]
    inc eax
    and eax, 7
    shl eax, 2
    movzx ecx, byte [rsi+rax]
    mov [next_root], ecx

    ; paused: the pianist noodles on the chord
    cmp dword [sim_speed], 0
    jne .play
    call part_piano_solo
    jmp .advance
.play:
    call part_drums
    call part_bass
    call part_keys
    call part_lead
    call part_city
.advance:
    mov eax, [mus_tick]
    imul eax, 48
    add [mus_next_bar], rax
    mov eax, [mus_bar]
    inc eax
    and eax, 7
    mov [mus_bar], eax
    RETURN

; play a drum table (rdi): 16th step, inst, vel, chance
FUNC play_drums
    mov r12, rdi
.d:
    movzx eax, byte [r12]
    cmp eax, 255
    je .out
    movzx eax, byte [r12+3]
    cmp eax, 255
    je .go
    mov ebx, eax
    call rand
    and eax, 255
    cmp eax, ebx
    jae .n
.go:
    movzx edi, byte [r12]
    call step_tick
    mov r13d, eax
    movzx edi, byte [r12+2]
    call vel_f
    movzx edi, byte [r12+1]
    mov esi, 60
    mov edx, r13d
    mov ecx, 24
    call mnote
.n:
    add r12, 4
    jmp .d
.out:
    RETURN

FUNC part_drums
    mov eax, [mus_intensity]
    test eax, eax
    jnz .full
    lea rdi, [dr_small]
    call play_drums
    RETURN
.full:
    mov ebx, [mus_style]
    cmp ebx, ST_SALSA
    jne .kit
    lea rdi, [dr_salsa]
    call play_drums
    lea rdi, [dr_salsa_2]
    test dword [mus_bar], 1
    jz .cl
    lea rdi, [dr_salsa_3]
.cl:
    call play_drums
    jmp .fill
.kit:
    mov rdi, [style_drums+rbx*8]
    call play_drums
    ; swing: the drummer comps on the snare (feathers and "bombs")
    cmp ebx, ST_VANGUARD
    jne .fill
    xor r12d, r12d
.g:
    call rand
    and eax, 7
    jnz .gn
    lea edi, [r12*4+2]              ; the "and"s
    call step_tick
    mov r13d, eax
    call rand
    and eax, 31
    lea edi, [rax+26]
    call vel_f
    mov edi, I_SNARE
    mov esi, 60
    mov edx, r13d
    mov ecx, 6
    call mnote
.gn:
    inc r12d
    cmp r12d, 4
    jl .g
.fill:
    ; last bar of the section: a fill into the next
    cmp dword [mus_bar], 7
    jne .out
    cmp ebx, ST_SALSA
    je .sf
    mov r12d, 12
.f:
    mov edi, r12d
    call step_tick
    mov r13d, eax
    lea edi, [r12*8-20]
    CLAMP edi, 40, 120
    call vel_f
    mov edi, I_SNARE
    mov esi, 60
    mov edx, r13d
    mov ecx, 3
    call mnote
    inc r12d
    cmp r12d, 16
    jl .f
    jmp .out
.sf:
    ; salsa: a conga run and the bell on the button
    mov r12d, 8
.sfl:
    mov edi, r12d
    call step_tick
    mov r13d, eax
    mov edi, 90
    call vel_f
    mov edi, I_SLAP
    test r12d, 1
    jz .sfi
    mov edi, I_CONGA
.sfi:
    mov esi, 60
    mov edx, r13d
    mov ecx, 3
    call mnote
    inc r12d
    cmp r12d, 16
    jl .sfl
.out:
    RETURN

; ---------------------------------------------------------------------
;  bass
; ---------------------------------------------------------------------
; bass note in the upright's range (edi midi) -> eax
bass_range:
    mov esi, 31
    mov edx, 50
    jmp fit_range

FUNC part_bass, 16
    mov ebx, [mus_style]
    ; roots of this bar's two halves and the next bar
    xor edi, edi
    xor esi, esi
    call chord_tone
    mov edi, eax
    call bass_range
    mov r12d, eax                   ; root, first half
    mov edi, 1
    xor esi, esi
    call chord_tone
    mov edi, eax
    call bass_range
    mov r13d, eax                   ; root, second half
    mov edi, [next_root]
    add edi, [mus_key]
    call bass_range
    mov r14d, eax                   ; next bar
    cmp ebx, ST_BOOMBAP
    je .bap
    cmp ebx, ST_SALSA
    je .salsa
    cmp ebx, ST_BROADWAY
    je .two
    cmp ebx, ST_NOIR
    je .two
    ; --- walking: root, chord tone, root/tone, approach
    mov edi, 96
    call vel_f
    mov edi, I_UBASS
    mov esi, r12d
    xor edx, edx
    mov ecx, 11
    call mnote
    call rand
    and eax, 1
    lea esi, [rax+1]                ; 3rd or 5th
    xor edi, edi
    call chord_tone
    mov edi, eax
    call bass_range
    mov esi, eax
    mov edi, 80
    push rsi
    push rsi
    call vel_f
    pop rsi
    pop rsi
    mov edi, I_UBASS
    mov edx, 12
    mov ecx, 11
    call mnote
    mov edi, 88
    call vel_f
    mov edi, I_UBASS
    mov esi, r13d
    mov edx, 24
    mov ecx, 11
    call mnote
    ; beat 4: a semitone above or below the next root
    call rand
    and eax, 1
    lea eax, [rax*2-1]
    lea esi, [r14+rax]
    mov edi, 78
    push rsi
    push rsi
    call vel_f
    pop rsi
    pop rsi
    mov edi, I_UBASS
    mov edx, 36
    mov ecx, 10
    call mnote
    RETURN
.two:
    ; two-feel: root on 1, fifth (or next half's root) on 3
    mov edi, 92
    call vel_f
    mov edi, I_UBASS
    mov esi, r12d
    xor edx, edx
    mov ecx, 22
    call mnote
    mov esi, r13d
    cmp r13d, r12d
    jne .t3
    xor edi, edi
    mov esi, 2
    call chord_tone
    mov edi, eax
    call bass_range
    mov esi, eax
.t3:
    mov edi, 80
    push rsi
    push rsi
    call vel_f
    pop rsi
    pop rsi
    mov edi, I_UBASS
    mov edx, 24
    mov ecx, 22
    call mnote
    RETURN
.bap:
    ; boom bap: a fat root, a pickup, a slide toward the next chord
    mov edi, 100
    call vel_f
    mov edi, I_UBASS
    mov esi, r12d
    xor edx, edx
    mov ecx, 20
    call mnote
    call rand
    and eax, 1
    jz .b2
    mov edi, 10
    call step_tick
    mov [rbp-48], eax
    mov edi, 84
    call vel_f
    mov edi, I_UBASS
    mov esi, r13d
    mov edx, [rbp-48]
    mov ecx, 8
    call mnote
.b2:
    mov edi, 14
    call step_tick
    mov [rbp-48], eax
    mov edi, 70
    call vel_f
    mov edi, I_UBASS
    lea esi, [r14-2]
    mov edx, [rbp-48]
    mov ecx, 5
    call mnote
    RETURN
.salsa:
    ; tumbao: the fifth on "and of 2", the next chord's root on 4
    xor edi, edi
    mov esi, 2
    call chord_tone
    mov edi, eax
    call bass_range
    mov r15d, eax
    mov edi, 90
    call vel_f
    mov edi, I_UBASS
    mov esi, r15d
    mov edx, 18
    mov ecx, 16
    call mnote
    mov edi, 100
    call vel_f
    mov edi, I_UBASS
    mov esi, r14d
    mov edx, 36
    mov ecx, 20
    call mnote
    RETURN

; ---------------------------------------------------------------------
;  keys: comping, chops, montunos, stride, strings
; ---------------------------------------------------------------------
; play half-bar edi's rootless voicing at tick esi, dur edx, vel ecx,
; into range [lo = 55, 72)
FUNC play_voicing, 32
    mov [rbp-48], edi
    mov [rbp-52], esi
    mov [rbp-56], edx
    mov [rbp-60], ecx
    ; place the lowest note, stack the rest above it
    mov edi, [rbp-48]
    xor esi, esi
    call voicing_tone
    mov edi, eax
    mov esi, [voice_lo]
    lea edx, [rsi+12]
    call fit_range
    mov r13d, eax                   ; bottom note
    mov edi, [rbp-48]
    xor esi, esi
    call voicing_tone
    mov r14d, r13d
    sub r14d, eax                   ; octave shift applied
    xor ebx, ebx
.v:
    mov edi, [rbp-48]
    mov esi, ebx
    call voicing_tone
    add eax, r14d
    mov r12d, eax
    mov edi, [rbp-60]
    call vel_f
    mov edi, [voice_inst]
    mov esi, r12d
    mov edx, [rbp-52]
    mov ecx, [rbp-56]
    call mnote
    inc ebx
    cmp ebx, [voice_n]
    jl .v
    RETURN
section .data
voice_lo   dd 55
voice_n    dd 4
voice_inst dd I_PIANO
section .text

FUNC part_keys, 16
    mov ebx, [mus_style]
    mov dword [voice_inst], I_PIANO
    mov dword [voice_n], 4
    mov dword [voice_lo], 55
    cmp ebx, ST_BOOMBAP
    je .bap
    cmp ebx, ST_SALSA
    je .montuno
    cmp ebx, ST_BROADWAY
    je .stride
    cmp ebx, ST_NOIR
    je .noir
    ; --- swing comping: one rhythm per bar
    mov edi, 6
    call rand_range
    lea r12, [comp_swing+rax*4]
    xor r13d, r13d
.c:
    movzx edi, byte [r12+r13]
    cmp edi, 255
    je .out
    mov r14d, edi
    call step_tick
    mov esi, eax
    xor edi, edi
    cmp r14d, 8
    jl .h
    mov edi, 1
.h:
    mov edx, 7
    call rand
    and eax, 15
    lea ecx, [rax+52]
    mov edx, 8
    call play_voicing
    inc r13d
    jmp .c
.bap:
    ; lo-fi chop: long chord on 1, a stab on the "a" of 3, vinyl under it
    mov dword [voice_lo], 50
    xor edi, edi
    xor esi, esi
    mov edx, 30
    mov ecx, 50
    call play_voicing
    mov edi, 11
    call step_tick
    mov esi, eax
    mov edi, 1
    mov edx, 6
    mov ecx, 40
    call play_voicing
    mov edi, 110
    call vel_f
    mov edi, I_VINYL
    mov esi, 60
    xor edx, edx
    mov ecx, 48
    call mnote
    jmp .out
.stride:
    ; stride: bass note on 1 and 3, chord on 2 and 4; strings hold
    xor r13d, r13d
.st:
    mov edi, r13d
    xor esi, esi
    call chord_tone
    mov edi, eax
    mov esi, 38
    mov edx, 50
    call fit_range
    mov r12d, eax
    mov edi, 70
    call vel_f
    mov edi, I_PIANO
    mov esi, r12d
    imul edx, r13d, 24
    mov ecx, 10
    call mnote
    mov dword [voice_n], 3
    mov dword [voice_lo], 57
    mov edi, r13d
    imul esi, r13d, 24
    add esi, 12
    mov edx, 8
    mov ecx, 56
    call play_voicing
    inc r13d
    cmp r13d, 2
    jl .st
    jmp .strings
.noir:
    ; one dark chord per bar, low and long
    mov dword [voice_lo], 48
    xor edi, edi
    xor esi, esi
    mov edx, 44
    mov ecx, 44
    call play_voicing
    jmp .strings
.montuno:
    ; piano montuno: octave dyads on the clave-matched 8ths
    lea r12, [montuno_2]
    test dword [mus_bar], 1
    jz .mt
    lea r12, [montuno_3]
.mt:
    xor r13d, r13d
.m:
    movzx eax, byte [r12+r13]
    cmp eax, 255
    je .out
    mov r14d, eax                   ; 8th index
    ; which half, which chord tone (cycles root, 3rd, 5th, 3rd)
    xor edi, edi
    cmp r14d, 4
    jl .mh
    mov edi, 1
.mh:
    mov eax, r13d
    and eax, 3
    movzx esi, byte [montuno_tone+rax]
    call chord_tone
    mov edi, eax
    mov esi, 62
    mov edx, 74
    call fit_range
    mov r15d, eax
    mov eax, r14d
    imul eax, 6
    mov [rbp-48], eax
    mov edi, 72
    test r13d, 1
    jz .mv
    mov edi, 56
.mv:
    call vel_f
    movss [rbp-52], xmm0
    mov edi, I_PIANO
    mov esi, r15d
    mov edx, [rbp-48]
    mov ecx, 5
    call mnote
    movss xmm0, [rbp-52]
    mov edi, I_PIANO
    lea esi, [r15-12]
    mov edx, [rbp-48]
    mov ecx, 5
    call mnote
    inc r13d
    jmp .m
.strings:
    ; strings sustain the guide tones when the band is up to it
    cmp dword [mus_intensity], 2
    jl .out
    mov dword [voice_inst], I_STR
    mov dword [voice_n], 3
    mov dword [voice_lo], 60
    xor edi, edi
    xor esi, esi
    mov edx, 46
    mov ecx, 60
    call play_voicing
.out:
    mov dword [voice_inst], I_PIANO
    RETURN
section .data
montuno_tone db 0, 1, 2, 1
section .text

; paused: a quiet chord and the odd note
FUNC part_piano_solo
    mov dword [voice_inst], I_PIANO
    mov dword [voice_n], 4
    mov dword [voice_lo], 55
    xor edi, edi
    xor esi, esi
    mov edx, 44
    mov ecx, 34
    call play_voicing
    RETURN

; ---------------------------------------------------------------------
;  lead: the motif, answered and resolved over the section
; ---------------------------------------------------------------------
FUNC part_lead, 32
    cmp dword [mus_intensity], 2
    jl .out
    cmp dword [mus_role], 1
    jne .out
    mov ebx, [mus_style]
    cmp ebx, ST_SALSA
    je .mambo
    ; bars 0-1 motif, 2-3 motif on the new chords, 4-5 again, 6-7 answer
    mov eax, [mus_bar]
    and eax, 1
    mov [rbp-48], eax               ; which bar of the pair
    mov eax, [mus_bar]
    shr eax, 1
    mov [rbp-52], eax               ; pair 0..3
    ; lead register
    mov eax, [mus_lead]
    mov r14d, 64                    ; low bound
    cmp eax, I_SAX
    jne .rg
    mov r14d, 56
.rg:
    xor r13d, r13d                  ; note index
.n:
    cmp r13d, [riff_len]
    jge .out
    movzx eax, byte [riff_step+r13]
    mov r12d, eax
    ; only the notes that fall in this bar
    mov ecx, [rbp-48]
    shl ecx, 4
    sub eax, ecx
    js .nn
    cmp eax, 16
    jge .nn
    mov [rbp-56], eax               ; step in this bar
    movsx edi, byte [riff_deg+r13]
    ; the answer (pair 3) steps down toward home
    cmp dword [rbp-52], 3
    jne .d
    mov eax, [riff_len]
    sub eax, r13d
    sub edi, eax
    add edi, 2
.d:
    call degree_note
    mov edi, eax
    mov esi, r14d
    lea edx, [r14+16]
    call fit_range
    mov edi, eax
    ; strong steps land on chord tones
    mov eax, [rbp-56]
    test eax, 3
    jnz .ns
    xor esi, esi
    cmp eax, 8
    jl .sh
    mov esi, 1
.sh:
    call snap_chord
    mov edi, eax
.ns:
    mov [rbp-60], edi
    ; duration: up to the next note (or long at the end of a phrase)
    mov ecx, 10
    lea eax, [r13+1]
    cmp eax, [riff_len]
    jl .du
    mov ecx, 20
    cmp dword [rbp-52], 3
    jne .du
    mov ecx, 36
.du:
    mov [rbp-64], ecx
    mov edi, [rbp-56]
    call step_tick
    mov [rbp-56], eax
    call rand
    and eax, 15
    lea edi, [rax+86]
    call vel_f
    mov edi, [mus_lead]
    mov esi, [rbp-60]
    mov edx, [rbp-56]
    mov ecx, [rbp-64]
    call mnote
.nn:
    inc r13d
    jmp .n
.mambo:
    ; brass mambo: trumpets on top, trombones a chord tone below
    mov eax, [mus_bar]
    and eax, 1
    shl eax, 2
    mov [rbp-48], eax               ; first slot for this bar
    xor r13d, r13d
.mb:
    cmp r13d, 4
    jge .out
    mov eax, [rbp-48]
    add eax, r13d
    movzx edi, byte [mambo_steps+rax]
    and edi, 15
    call step_tick
    mov [rbp-52], eax
    xor edi, edi
    cmp dword [rbp-52], 24
    jl .mh
    mov edi, 1
.mh:
    mov [rbp-56], edi
    mov eax, r13d
    and eax, 1
    lea esi, [rax+1]                ; 3rd / 5th on top
    call chord_tone
    mov edi, eax
    mov esi, 67
    mov edx, 79
    call fit_range
    mov r12d, eax
    mov edi, 104
    call vel_f
    mov edi, I_TPT
    mov esi, r12d
    mov edx, [rbp-52]
    mov ecx, 5
    call mnote
    mov edi, [rbp-56]
    xor esi, esi
    call chord_tone
    mov edi, eax
    mov esi, 50
    mov edx, 62
    call fit_range
    mov r12d, eax
    mov edi, 100
    call vel_f
    mov edi, I_TBN
    mov esi, r12d
    mov edx, [rbp-52]
    mov ecx, 5
    call mnote
    inc r13d
    jmp .mb
.out:
    RETURN

; ---------------------------------------------------------------------
;  the city itself: sirens far away while something burns (and, it being
;  New York, now and then at night anyway)
; ---------------------------------------------------------------------
FUNC part_city
    cmp dword [cnt_fire], 0
    je .night
    call rand
    and eax, 3
    jnz .out
    jmp .siren
.night:
    mov eax, [tod]
    shr eax, 8
    cmp eax, 48
    jl .n2
    cmp eax, 210
    jl .out
.n2:
    call rand
    and eax, 63
    jnz .out
.siren:
    call rand
    and eax, 3
    lea esi, [rax+58]               ; different sirens, different pitches
    mov edi, 70
    push rsi
    push rsi
    call vel_f
    pop rsi
    pop rsi
    mov edi, I_SIREN
    xor edx, edx
    mov ecx, 60
    call mnote
.out:
    RETURN
