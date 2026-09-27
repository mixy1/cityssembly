; =====================================================================
;  AUDIO - sampler, instrument synthesis and a generative jazz score
;
;  * At start-up every instrument is rendered into a float sample using
;    physical / FM models (Karplus-Strong strings, FM electric piano,
;    modal vibraphone and marimba, noise-shaped brushes and cymbals).
;    WAV files in ./samples/ override any built-in instrument.
;  * A 32-voice stereo sampler plays them with pitch shifting, and a
;    Freeverb-style reverb glues the band together.
;  * The composer writes one bar at a time: chord progressions,
;    walking bass, comping, drums and motif-based melodies.  Style and
;    density follow the city: day swing, night lo-fi, park bossa and a
;    minor "tension" mode while fires burn.
;  * UI sound effects are played on the same instruments, in key.
; =====================================================================

SR          equ 44100
NVOICES     equ 32
CHUNK       equ 256
POOL_FLOATS equ 6000000
MAX_EVENTS  equ 512

; sample ids
S_RHODES_LO equ 0
S_RHODES_HI equ 1
S_BASS      equ 2
S_GUITAR    equ 3
S_VIBES     equ 4
S_MARIMBA   equ 5
S_HORN      equ 6
S_PAD       equ 7
S_KICK      equ 8
S_BRUSH     equ 9
S_TAP       equ 10
S_RIDE      equ 11
S_HAT       equ 12
S_SHAKER    equ 13
S_RIM       equ 14
S_RUMBLE    equ 15
S_BOOM      equ 16
S_BELL      equ 17
S_COUNT     equ 18                  ; synthesised; recorded zones follow
S_NYC       equ S_COUNT

; instruments (what the composer / sfx ask for)
I_RHODES    equ 0
I_BASS      equ 1
I_GUITAR    equ 2
I_VIBES     equ 3
I_MARIMBA   equ 4
I_HORN      equ 5
I_PAD       equ 6
I_KICK      equ 7
I_BRUSH     equ 8
I_TAP       equ 9
I_RIDE      equ 10
I_HAT       equ 11
I_SHAKER    equ 12
I_RIM       equ 13
I_RUMBLE    equ 14
I_BOOM      equ 15
I_BELL      equ 16
; recorded instruments (music v2, "Five Boroughs")
I_PIANO     equ 17
I_UBASS     equ 18
I_HARMON    equ 19
I_SAX       equ 20
I_CLAR      equ 21
I_STR       equ 22
I_TBN       equ 23
I_TPT       equ 24
I_KICK2     equ 25
I_SNARE     equ 26
I_HATC      equ 27
I_HATO      equ 28
I_HATF      equ 29
I_RIDE2     equ 30
I_RBELL     equ 31
I_CLAP      equ 32
I_CONGA     equ 33
I_SLAP      equ 34
I_TUMBA     equ 35
I_BONGOH    equ 36
I_BONGOL    equ 37
I_COWBELL   equ 38
I_CLAVES    equ 39
I_GUIRO     equ 40
I_SIREN     equ 41
I_VINYL     equ 42
I_COUNT     equ 43

; sfx ids
SFX_CLICK    equ 0
SFX_PLACE    equ 1
SFX_ROAD     equ 2
SFX_BULLDOZE equ 3
SFX_ZONE     equ 4
SFX_ERROR    equ 5
SFX_COIN     equ 6
SFX_POP      equ 7
SFX_CHIME    equ 8
SFX_FANFARE  equ 9
SFX_ALARM    equ 10
SFX_BOOM     equ 11
SFX_CRUMBLE  equ 12
SFX_COUNT    equ 13


; voice record (64 bytes)
V_DATA  equ 0    ; q float*
V_POS   equ 8    ; q 32.32
V_STEP  equ 16   ; q 32.32
V_LEN   equ 24   ; d
V_LS    equ 28   ; d loop start (0 = none)
V_LE    equ 32   ; d loop end
V_GL    equ 36   ; f
V_GR    equ 40   ; f
V_ENV   equ 44   ; f
V_REL   equ 48   ; f release multiplier (1.0 until released)
V_DUR   equ 52   ; d samples until release (0 = never)
V_SEND  equ 56   ; f reverb send
V_TREM  equ 60   ; d tremolo phase (0 = off)
V_SIZE  equ 64

; event record (32 bytes)
E_TIME  equ 0    ; q sample time
E_INST  equ 8    ; d
E_NOTE  equ 12   ; d
E_VEL   equ 16   ; f
E_DUR   equ 20   ; d samples
E_PAN   equ 24   ; f -1..1
E_USED  equ 28   ; d
E_SIZE  equ 32

%include "nyc_samples.inc"
S_ALL       equ S_COUNT + NZ_COUNT

section .bss
alignb 16
smp_pool        resd POOL_FLOATS
pool_used       resd 1
smp_ptr         resq S_ALL
smp_len         resd S_ALL
smp_ls          resd S_ALL
smp_le          resd S_ALL
smp_root        resd S_ALL
smp_rate        resd S_ALL         ; float: source rate / SR
alignb 16
voices          resb NVOICES*V_SIZE
events          resb MAX_EVENTS*E_SIZE
mixbuf          resw CHUNK*2
audio_dev       resd 1
audio_ok        resd 1
audio_time      resq 1
semi_ratio      resd 97             ; 2^((i-48)/12)
; reverb
alignb 16
comb_buf        resd 8*1800
comb_idx        resd 8
comb_filt       resd 8
ap_buf          resd 4*700
ap_idx          resd 4
rev_in          resd 1
; ks ring
ks_ring         resd 4096
; music state
music_on        resd 1
music_vol       resd 1              ; float
sfx_vol         resd 1              ; float
mus_key         resd 1              ; tonic midi (48..59)
mus_style       resd 1
mus_prog        resq 1
mus_bar         resd 1              ; 0..7 within section
mus_sections    resd 1
mus_tempo       resd 1
mus_tick        resd 1              ; samples per tick (12 ticks / beat)
mus_next_bar    resq 1
mus_intensity   resd 1
mus_lead        resd 1              ; lead instrument for this section
mus_last_bass   resd 1
mus_mel_deg     resd 1
motif_pos       resb 16
motif_step      resb 16
motif_dur       resb 16
motif_len       resd 1
chord_root      resd 2              ; per half bar (absolute semis above key)
chord_q         resd 2
next_root       resd 1
wav_spec        resb 32
wav_buf         resq 1
wav_len         resd 1
path_buf        resb 128
; synth scratch
g_phase         resd 1
g_phase2        resd 1
g_lp            resd 1
g_lp2           resd 1
g_env           resd 1

section .data
align 16
f_zero      dd 0.0
f_one       dd 1.0
f_half      dd 0.5
f_two       dd 2.0
f_pi        dd 3.14159265
f_halfpi    dd 1.57079633
f_twopi     dd 6.28318531
f_inv2pi    dd 0.15915494
f_sr        dd 44100.0
f_invsr     dd 0.0000226757
f_inv32     dd 2.3283064e-10
f_inv16k    dd 0.0000610352        ; 1/16384
f_c3        dd 0.16666667
f_c5        dd 0.00833333
f_c7        dd 0.00019841
f_ln2_12    dd 0.05776227          ; ln2/12
f_32767     dd 30000.0
f_27        dd 27.0
f_9         dd 9.0
f_rel_fast  dd 0.9990
f_rel_slow  dd 0.99985
f_minenv    dd 0.0004
f_trem_d    dd 0.25
f_damp      dd 0.28
f_ndamp     dd 0.72
f_fb        dd 0.83
f_apfb      dd 0.5
f_revout    dd 0.22
comb_len    dd 1116, 1188, 1277, 1356, 1139, 1211, 1300, 1379
ap_len      dd 556, 441, 579, 464

; per instrument: sample, gain, pan, send, release (fast/slow), trem
; gain/pan/send as floats
align 4
inst_table:
    ;   sample,     gain,  pan,  send, rel(0 fast,1 slow), trem, zones
    dd S_RHODES_LO, 0.30, -0.30, 0.30, 1, 1, 2
    dd S_BASS,      0.85,  0.00, 0.10, 0, 0, 1
    dd S_GUITAR,    0.42, -0.35, 0.25, 1, 0, 1
    dd S_VIBES,     0.40,  0.35, 0.40, 1, 1, 1
    dd S_MARIMBA,   0.50,  0.25, 0.30, 0, 0, 1
    dd S_HORN,      0.30,  0.18, 0.45, 0, 0, 1
    dd S_PAD,       0.16,  0.00, 0.60, 1, 0, 1
    dd S_KICK,      0.75,  0.00, 0.05, 0, 0, 1
    dd S_BRUSH,     0.30, -0.10, 0.20, 0, 0, 1
    dd S_TAP,       0.40, -0.10, 0.20, 0, 0, 1
    dd S_RIDE,      0.20,  0.40, 0.25, 1, 0, 1
    dd S_HAT,       0.22,  0.30, 0.15, 0, 0, 1
    dd S_SHAKER,    0.16,  0.45, 0.15, 0, 0, 1
    dd S_RIM,       0.28, -0.25, 0.20, 0, 0, 1
    dd S_RUMBLE,    0.55,  0.00, 0.05, 0, 0, 1
    dd S_BOOM,      0.90,  0.00, 0.30, 1, 0, 1
    dd S_BELL,      0.35,  0.20, 0.45, 1, 0, 1
    ; recorded (CC0, Versilian Studios)
    dd S_NYC+NZ_PIANO,     0.42, -0.18, 0.28, 1, 0, NZ_PIANO_N
    dd S_NYC+NZ_BASS,      0.70,  0.02, 0.10, 0, 0, NZ_BASS_N
    dd S_NYC+NZ_HARMON,    0.55,  0.20, 0.42, 0, 0, NZ_HARMON_N
    dd S_NYC+NZ_SAX,       0.34,  0.16, 0.40, 0, 0, NZ_SAX_N
    dd S_NYC+NZ_CLARINET,  0.30,  0.22, 0.42, 0, 0, NZ_CLARINET_N
    dd S_NYC+NZ_STRINGS,   0.28,  0.00, 0.55, 1, 0, NZ_STRINGS_N
    dd S_NYC+NZ_TROMBONE,  0.32, -0.30, 0.30, 0, 0, NZ_TROMBONE_N
    dd S_NYC+NZ_TRUMPET,   0.28,  0.30, 0.30, 0, 0, NZ_TRUMPET_N
    dd S_NYC+NZ_KICK,      0.80,  0.00, 0.05, 0, 0, 1
    dd S_NYC+NZ_SNARE,     0.62, -0.06, 0.18, 0, 0, 1
    dd S_NYC+NZ_HAT,       0.48,  0.28, 0.10, 0, 0, 1
    dd S_NYC+NZ_HATOPEN,   0.36,  0.28, 0.14, 0, 0, 1
    dd S_NYC+NZ_HATFOOT,   0.36,  0.24, 0.10, 0, 0, 1
    dd S_NYC+NZ_RIDE,      0.45,  0.36, 0.20, 1, 0, 1
    dd S_NYC+NZ_RIDEBELL,  0.16,  0.36, 0.20, 1, 0, 1
    dd S_NYC+NZ_CLAP,      0.30,  0.00, 0.22, 0, 0, 1
    dd S_NYC+NZ_CONGA,     0.40,  0.30, 0.16, 0, 0, 1
    dd S_NYC+NZ_CONGASLAP, 0.34,  0.34, 0.16, 0, 0, 1
    dd S_NYC+NZ_TUMBA,     0.42,  0.40, 0.16, 0, 0, 1
    dd S_NYC+NZ_BONGOHI,   0.40, -0.34, 0.14, 0, 0, 1
    dd S_NYC+NZ_BONGOLO,   0.30, -0.28, 0.14, 0, 0, 1
    dd S_NYC+NZ_COWBELL,   0.32, -0.12, 0.14, 0, 0, 1
    dd S_NYC+NZ_CLAVES,    0.55,  0.10, 0.16, 0, 0, 1
    dd S_NYC+NZ_GUIRO,     0.45, -0.40, 0.14, 0, 0, 1
    dd S_NYC+NZ_SIREN,     0.10,  0.50, 0.60, 1, 0, 1
    dd S_NYC+NZ_VINYL,     0.10,  0.00, 0.00, 0, 0, 1
INST_REC equ 28

; wav override file names (samples/<name>.wav) and root notes
wav_names:
    dq wn_rhodes, wn_rhodes_hi, wn_bass, wn_guitar, wn_vibes, wn_marimba
    dq wn_horn, wn_pad, wn_kick, wn_brush, wn_tap, wn_ride, wn_hat
    dq wn_shaker, wn_rim, wn_rumble, wn_boom, wn_bell
wn_rhodes    db "rhodes", 0
wn_rhodes_hi db "rhodes_hi", 0
wn_bass      db "bass", 0
wn_guitar    db "guitar", 0
wn_vibes     db "vibes", 0
wn_marimba   db "marimba", 0
wn_horn      db "horn", 0
wn_pad       db "pad", 0
wn_kick      db "kick", 0
wn_brush     db "brush", 0
wn_tap       db "snare", 0
wn_ride      db "ride", 0
wn_hat       db "hat", 0
wn_shaker    db "shaker", 0
wn_rim       db "rim", 0
wn_rumble    db "rumble", 0
wn_boom      db "boom", 0
wn_bell      db "bell", 0
str_samples  db "samples/", 0
str_wav      db ".wav", 0

; sfx scripts: delay(10ms), instrument, note (relative to key+24 if <100,
; absolute-100 if >=100), velocity(0..127); 255 ends
sfx_scripts:
    dq sx_click, sx_place, sx_road, sx_bulldoze, sx_zone, sx_error, sx_coin
    dq sx_pop, sx_chime, sx_fanfare, sx_alarm, sx_boom, sx_crumble
sx_click    db 0, I_RIM, 160, 50, 255
sx_place    db 0, I_MARIMBA, 24, 80, 0, I_KICK, 136, 60, 255
sx_road     db 0, I_SHAKER, 160, 90, 0, I_TAP, 160, 50, 255
sx_bulldoze db 0, I_RUMBLE, 140, 110, 0, I_KICK, 130, 70, 255
sx_zone     db 0, I_VIBES, 16, 55, 4, I_VIBES, 23, 40, 255
sx_error    db 0, I_HORN, 13, 70, 11, I_HORN, 12, 70, 255
sx_coin     db 0, I_BELL, 35, 90, 7, I_BELL, 40, 100, 255
sx_pop      db 0, I_MARIMBA, 31, 70, 5, I_MARIMBA, 36, 60, 255
sx_chime    db 0, I_VIBES, 24, 80, 9, I_VIBES, 28, 80, 18, I_VIBES, 31, 80, 27, I_VIBES, 36, 90, 255
sx_fanfare  db 0, I_HORN, 19, 100, 0, I_VIBES, 24, 90, 15, I_HORN, 24, 100, 15, I_VIBES, 28, 90
            db 30, I_HORN, 28, 100, 30, I_VIBES, 31, 90, 45, I_HORN, 31, 110, 45, I_VIBES, 36, 110
            db 45, I_RIDE, 160, 110, 45, I_KICK, 136, 100, 255
sx_alarm    db 0, I_HORN, 26, 110, 18, I_HORN, 20, 110, 36, I_HORN, 26, 110, 54, I_HORN, 20, 110, 255
sx_boom     db 0, I_BOOM, 136, 127, 0, I_RUMBLE, 130, 110, 255
sx_crumble  db 0, I_RUMBLE, 145, 100, 0, I_TAP, 150, 80, 6, I_TAP, 145, 60, 255

section .text

; =====================================================================
;  math helpers (xmm0 in / out)
; =====================================================================
; fast_sin: any angle -> sin
fast_sin:
    movss xmm1, xmm0
    mulss xmm1, [f_inv2pi]
    cvtss2si eax, xmm1
    cvtsi2ss xmm1, eax
    mulss xmm1, [f_twopi]
    subss xmm0, xmm1                ; [-pi, pi]
    ; fold to [-pi/2, pi/2]
    movss xmm1, [f_halfpi]
    comiss xmm0, xmm1
    jbe .n1
    movss xmm1, [f_pi]
    subss xmm1, xmm0
    movss xmm0, xmm1
    jmp .poly
.n1:
    xorps xmm1, xmm1
    subss xmm1, [f_halfpi]
    comiss xmm0, xmm1
    jae .poly
    xorps xmm1, xmm1
    subss xmm1, [f_pi]
    subss xmm1, xmm0
    movss xmm0, xmm1
.poly:
    movss xmm1, xmm0
    mulss xmm1, xmm0                ; x^2
    movss xmm2, [f_c7]
    mulss xmm2, xmm1
    movss xmm3, [f_c5]
    subss xmm3, xmm2                ; c5 - c7 x^2
    mulss xmm3, xmm1
    movss xmm2, [f_c3]
    subss xmm2, xmm3                ; c3 - ...
    mulss xmm2, xmm1
    movss xmm3, [f_one]
    subss xmm3, xmm2
    mulss xmm0, xmm3
    ret

; fexp(xmm0) -> e^x   (x87)
fexp:
    sub rsp, 8
    movss [rsp], xmm0
    fld dword [rsp]
    fldl2e
    fmulp
    fld st0
    frndint
    fsub st1, st0
    fxch
    f2xm1
    fld1
    faddp
    fscale
    fstp st1
    fstp dword [rsp]
    movss xmm0, [rsp]
    add rsp, 8
    ret

; decay_mult(xmm0 tau seconds) -> xmm0 = exp(-1/(tau*SR))
decay_mult:
    mulss xmm0, [f_sr]
    movss xmm1, [f_one]
    divss xmm1, xmm0
    xorps xmm0, xmm0
    subss xmm0, xmm1
    jmp fexp

; frand: xmm0 = random in [-1, 1)
frand:
    call rand
    sar eax, 16
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_inv32k_s]
    ret
section .data
f_inv32k dd 0.0000305176
section .text

; ---------------------------------------------------------------------
;  sample allocation: smp_new(edi id, esi length) -> rax data ptr
; ---------------------------------------------------------------------
smp_new:
    mov eax, [pool_used]
    lea rcx, [smp_pool+rax*4]
    mov [smp_ptr+rdi*8], rcx
    mov [smp_len+rdi*4], esi
    mov dword [smp_ls+rdi*4], 0
    mov dword [smp_le+rdi*4], 0
    mov dword [smp_rate+rdi*4], 0x3F800000   ; 1.0
    add eax, esi
    add eax, 4
    mov [pool_used], eax
    ; clear
    push rdi
    mov rdi, rcx
    mov ecx, esi
    add ecx, 4
    xor eax, eax
    rep stosd
    pop rdi
    mov rax, [smp_ptr+rdi*8]
    ret

; normalise sample (edi id) to peak xmm0
FUNC smp_normalize
    mov ebx, edi
    movss [rbp-48], xmm0
    mov rsi, [smp_ptr+rbx*8]
    mov ecx, [smp_len+rbx*4]
    xorps xmm1, xmm1                ; peak
    xor edx, edx
.p:
    movss xmm2, [rsi+rdx*4]
    andps xmm2, [f_absmask]
    maxss xmm1, xmm2
    inc edx
    cmp edx, ecx
    jl .p
    comiss xmm1, [f_minenv]
    jbe .o
    movss xmm0, [rbp-48]
    divss xmm0, xmm1
    xor edx, edx
.s:
    movss xmm2, [rsi+rdx*4]
    mulss xmm2, xmm0
    movss [rsi+rdx*4], xmm2
    inc edx
    cmp edx, ecx
    jl .s
.o:
    RETURN
section .data
align 16
f_absmask dd 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF
section .text

; midi -> frequency: xmm0 = 440 * 2^((n-69)/12)
midi_freq:
    sub edi, 69
    cvtsi2ss xmm0, edi
    mulss xmm0, [f_ln2_12]
    call fexp
    mulss xmm0, [f_440]
    ret
section .data
f_440 dd 440.0
section .text

; =====================================================================
;  instrument synthesis
; =====================================================================
; ---- FM electric piano: edi id, esi root midi ----
FUNC gen_rhodes, 64
    mov [rbp-48], edi
    mov [rbp-52], esi
    mov edi, esi
    call midi_freq
    mulss xmm0, [f_twopi]
    mulss xmm0, [f_invsr]
    movss [rbp-56], xmm0            ; w
    mov edi, [rbp-48]
    mov esi, SR*3
    call smp_new
    mov r12, rax
    movss xmm0, [f_ep_amp_tau]
    call decay_mult
    movss [rbp-60], xmm0            ; amp decay
    movss xmm0, [f_ep_idx_tau]
    call decay_mult
    movss [rbp-64], xmm0            ; index decay
    movss xmm0, [f_ep_bell_tau]
    call decay_mult
    movss [rbp-68], xmm0            ; bell decay
    movss xmm0, [f_one]
    movss [rbp-72], xmm0            ; amp env
    movss xmm0, [f_ep_idx0]
    movss [rbp-76], xmm0            ; index
    movss xmm0, [f_ep_bell0]
    movss [rbp-80], xmm0            ; bell env
    xor r13d, r13d
.l:
    cvtsi2ss xmm4, r13d
    mulss xmm4, [rbp-56]            ; phase
    ; modulator (ratio 1)
    movss xmm0, xmm4
    call fast_sin
    mulss xmm0, [rbp-76]
    addss xmm0, xmm4
    call fast_sin
    movss xmm5, xmm0
    ; tine bell (ratio 14 -> keep below nyquist by using 7 for high roots)
    cvtsi2ss xmm4, r13d
    mulss xmm4, [rbp-56]
    mulss xmm4, [f_bell_ratio]
    movss xmm0, xmm4
    call fast_sin
    mulss xmm0, [rbp-80]
    addss xmm0, xmm5
    ; attack ramp (first 64 samples)
    mulss xmm0, [rbp-72]
    cmp r13d, 64
    jge .na
    cvtsi2ss xmm1, r13d
    mulss xmm1, [f_1_64]
    mulss xmm0, xmm1
.na:
    movss [r12+r13*4], xmm0
    ; envelopes
    movss xmm0, [rbp-72]
    mulss xmm0, [rbp-60]
    movss [rbp-72], xmm0
    movss xmm0, [rbp-76]
    subss xmm0, [f_ep_idxmin]
    mulss xmm0, [rbp-64]
    addss xmm0, [f_ep_idxmin]
    movss [rbp-76], xmm0
    movss xmm0, [rbp-80]
    mulss xmm0, [rbp-68]
    movss [rbp-80], xmm0
    inc r13d
    cmp r13d, SR*3
    jl .l
    mov eax, [rbp-48]
    mov ecx, [rbp-52]
    mov [smp_root+rax*4], ecx
    mov edi, eax
    movss xmm0, [f_peak]
    call smp_normalize
    RETURN
section .data
f_ep_amp_tau  dd 1.1
f_ep_idx_tau  dd 0.35
f_ep_bell_tau dd 0.025
f_ep_idx0     dd 1.9
f_ep_idxmin   dd 0.35
f_ep_bell0    dd 0.35
f_bell_ratio  dd 7.0
f_1_64        dd 0.015625
f_peak        dd 0.9
section .text

; ---- Karplus-Strong plucked string ----
; edi id, esi root midi, xmm0 = decay per period-sample (0.99..0.9999)
; ks_exc_a  : excitation lowpass (lower = softer pluck)
; ks_loop_a : one-pole filter inside the loop (lower = darker, faster
;             high-frequency decay); its phase delay is compensated
; ks_out_a  : body / output lowpass
FUNC gen_ks, 48
    mov [rbp-48], edi
    mov [rbp-52], esi
    movss [rbp-56], xmm0
    mov edi, esi
    call midi_freq
    movss xmm1, [f_sr]
    divss xmm1, xmm0                ; period in samples
    ; loop filter delay (1-a)/a
    movss xmm2, [f_one]
    subss xmm2, [ks_loop_a]
    divss xmm2, [ks_loop_a]
    subss xmm1, xmm2
    subss xmm1, [f_half]
    cvtss2si r14d, xmm1             ; period N
    CLAMP r14d, 8, 4000
    mov edi, [rbp-48]
    mov esi, SR*3
    call smp_new
    mov r12, rax
    ; excitation: noise through two one-pole lowpasses
    xorps xmm4, xmm4
    xorps xmm5, xmm5
    xor ebx, ebx
.n:
    call frand
    subss xmm0, xmm4
    mulss xmm0, [ks_exc_a]
    addss xmm4, xmm0
    movss xmm0, xmm4
    subss xmm0, xmm5
    mulss xmm0, [ks_exc_a]
    addss xmm5, xmm0
    movss xmm0, xmm5
    mulss xmm0, [ks_noise]
    movss [ks_ring+rbx*4], xmm0
    inc ebx
    cmp ebx, r14d
    jl .n
    ; add the triangular displacement of a finger pluck at ks_pluck
    cvtsi2ss xmm3, r14d
    mulss xmm3, [ks_pluck]          ; pluck point p
    cvtsi2ss xmm2, r14d
    subss xmm2, xmm3                ; N - p
    xor ebx, ebx
.tri:
    cvtsi2ss xmm0, ebx
    comiss xmm0, xmm3
    jae .tri2
    divss xmm0, xmm3                ; rising edge i/p
    jmp .tri3
.tri2:
    cvtsi2ss xmm1, r14d
    subss xmm1, xmm0
    movss xmm0, xmm1
    divss xmm0, xmm2                ; falling edge (N-i)/(N-p)
.tri3:
    addss xmm0, [ks_ring+rbx*4]
    movss [ks_ring+rbx*4], xmm0
    inc ebx
    cmp ebx, r14d
    jl .tri
    ; remove dc from the excitation
    xorps xmm0, xmm0
    xor ebx, ebx
.dc:
    addss xmm0, [ks_ring+rbx*4]
    inc ebx
    cmp ebx, r14d
    jl .dc
    cvtsi2ss xmm1, r14d
    divss xmm0, xmm1
    xor ebx, ebx
.dc2:
    movss xmm1, [ks_ring+rbx*4]
    subss xmm1, xmm0
    movss [ks_ring+rbx*4], xmm1
    inc ebx
    cmp ebx, r14d
    jl .dc2
    ; run the string
    xor ebx, ebx                    ; ring index
    xor r13d, r13d                  ; sample
    xorps xmm4, xmm4                ; loop filter state
    xorps xmm5, xmm5                ; output lowpass
.l:
    movss xmm0, [ks_ring+rbx*4]
    movss xmm1, xmm0
    subss xmm1, xmm4
    mulss xmm1, [ks_loop_a]
    addss xmm4, xmm1
    movss xmm1, xmm4
    mulss xmm1, [rbp-56]
    movss [ks_ring+rbx*4], xmm1
    subss xmm0, xmm5
    mulss xmm0, [ks_out_a]
    addss xmm5, xmm0
    movss [r12+r13*4], xmm5
    inc ebx
    cmp ebx, r14d
    jl .l2
    xor ebx, ebx
.l2:
    inc r13d
    cmp r13d, SR*3
    jl .l
    mov eax, [rbp-48]
    mov ecx, [rbp-52]
    mov [smp_root+rax*4], ecx
    mov edi, eax
    movss xmm0, [f_peak]
    call smp_normalize
    RETURN
section .bss
ks_exc_a  resd 1
ks_loop_a resd 1
ks_out_a  resd 1
ks_pluck  resd 1
ks_noise  resd 1
section .text

; ---- modal percussion (vibes / marimba / bell) ----
; edi id, esi root, rdx -> partial table: count, then (ratio, amp, tau) floats
FUNC gen_modal, 96
    mov [rbp-48], edi
    mov [rbp-52], esi
    mov [rbp-64], rdx
    mov edi, esi
    call midi_freq
    mulss xmm0, [f_twopi]
    mulss xmm0, [f_invsr]
    movss [rbp-56], xmm0
    mov edi, [rbp-48]
    mov esi, SR*3
    call smp_new
    mov r12, rax
    mov r15, [rbp-64]
    mov r14d, [r15]                 ; partial count
    add r15, 4
.part:
    test r14d, r14d
    jz .done
    movss xmm0, [r15+8]
    call decay_mult
    movss [rbp-68], xmm0            ; mult
    movss xmm0, [r15+4]
    movss [rbp-72], xmm0            ; env
    movss xmm0, [rbp-56]
    mulss xmm0, [r15]
    movss [rbp-76], xmm0            ; w
    xor r13d, r13d
.l:
    cvtsi2ss xmm0, r13d
    mulss xmm0, [rbp-76]
    call fast_sin
    mulss xmm0, [rbp-72]
    cmp r13d, 32
    jge .na
    cvtsi2ss xmm1, r13d
    mulss xmm1, [f_1_32]
    mulss xmm0, xmm1
.na:
    addss xmm0, [r12+r13*4]
    movss [r12+r13*4], xmm0
    movss xmm0, [rbp-72]
    mulss xmm0, [rbp-68]
    movss [rbp-72], xmm0
    inc r13d
    cmp r13d, SR*3
    jl .l
    add r15, 12
    dec r14d
    jmp .part
.done:
    mov eax, [rbp-48]
    mov ecx, [rbp-52]
    mov [smp_root+rax*4], ecx
    mov edi, eax
    movss xmm0, [f_peak]
    call smp_normalize
    RETURN
section .data
f_1_32 dd 0.03125
modal_vibes:
    dd 3
    dd 1.0, 1.0, 2.4
    dd 4.0, 0.25, 0.45
    dd 10.0, 0.06, 0.08
modal_marimba:
    dd 4
    dd 1.0, 1.0, 0.45
    dd 3.93, 0.35, 0.09
    dd 9.2, 0.12, 0.025
    dd 0.5, 0.08, 0.2
modal_bell:
    dd 4
    dd 1.0, 1.0, 1.4
    dd 2.76, 0.5, 0.7
    dd 5.40, 0.25, 0.35
    dd 8.93, 0.12, 0.2
section .text

; ---- muted horn: FM brass with swell and vibrato ----
FUNC gen_horn, 64
    mov edi, 60
    call midi_freq
    mulss xmm0, [f_twopi]
    mulss xmm0, [f_invsr]
    movss [rbp-56], xmm0
    mov edi, S_HORN
    mov esi, SR*2
    call smp_new
    mov r12, rax
    xorps xmm0, xmm0
    movss [rbp-60], xmm0            ; phase
    movss [rbp-64], xmm0            ; lowpass
    xor r13d, r13d
.l:
    ; envelope: 60ms attack, slight decay, fade out last 0.3s
    cvtsi2ss xmm4, r13d
    mulss xmm4, [f_invsr]           ; t
    movss xmm5, xmm4
    mulss xmm5, [f_16_7]            ; attack 1/0.06
    minss xmm5, [f_one]
    movss xmm1, [f_one]
    movss xmm2, xmm4
    mulss xmm2, [f_0_25]
    subss xmm1, xmm2
    mulss xmm5, xmm1                ; env
    cmp r13d, SR*2-SR*3/10
    jl .nf
    mov eax, SR*2
    sub eax, r13d
    cvtsi2ss xmm1, eax
    mulss xmm1, [f_fade]
    mulss xmm5, xmm1
.nf:
    movss [rbp-68], xmm5
    ; vibrato after 250ms
    movss xmm0, xmm4
    mulss xmm0, [f_vibw]
    call fast_sin
    mulss xmm0, [f_vibd]
    cvtsi2ss xmm1, r13d
    comiss xmm1, [f_vibstart]
    ja .vib
    xorps xmm0, xmm0
.vib:
    addss xmm0, [f_one]
    mulss xmm0, [rbp-56]
    movss xmm1, [rbp-60]
    addss xmm1, xmm0
    movss [rbp-60], xmm1
    ; index follows the envelope (brighter when louder)
    movss xmm0, xmm1
    call fast_sin
    movss xmm2, [rbp-68]
    mulss xmm2, [f_horn_idx]
    mulss xmm0, xmm2
    addss xmm0, [rbp-60]
    call fast_sin
    mulss xmm0, [rbp-68]
    ; mute: lowpass
    movss xmm1, [rbp-64]
    subss xmm0, xmm1
    mulss xmm0, [f_horn_lp]
    addss xmm1, xmm0
    movss [rbp-64], xmm1
    movss [r12+r13*4], xmm1
    inc r13d
    cmp r13d, SR*2
    jl .l
    mov dword [smp_root+S_HORN*4], 60
    mov edi, S_HORN
    movss xmm0, [f_peak]
    call smp_normalize
    RETURN
section .data
f_16_7     dd 16.7
f_0_25     dd 0.2
f_fade     dd 0.0000755858         ; 1/(0.3*SR)
f_vibw     dd 34.5                 ; 5.5 Hz * 2pi
f_vibd     dd 0.006
f_vibstart dd 11025.0
f_horn_idx dd 2.6
f_horn_lp  dd 0.32
section .text

; ---- string pad: detuned saws, filtered, looped ----
FUNC gen_pad, 64
    mov edi, S_PAD
    mov esi, SR*4
    call smp_new
    mov r12, rax
    mov edi, 60
    call midi_freq
    mulss xmm0, [f_invsr]
    movss [rbp-48], xmm0            ; cycles per sample
    xorps xmm0, xmm0
    movss [rbp-52], xmm0
    movss [rbp-56], xmm0
    ; five detuned oscillators
    xor r14d, r14d
.osc:
    movss xmm0, [rbp-48]
    mulss xmm0, [pad_detune+r14*4]
    movss [rbp-60], xmm0
    call rand
    and eax, 1023
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_1_1024]
    movss [rbp-64], xmm0            ; phase
    xor r13d, r13d
.l:
    movss xmm0, [rbp-64]
    addss xmm0, [rbp-60]
    cvttss2si eax, xmm0
    cvtsi2ss xmm1, eax
    subss xmm0, xmm1
    movss [rbp-64], xmm0
    mulss xmm0, [f_two]
    subss xmm0, [f_one]
    addss xmm0, [r12+r13*4]
    movss [r12+r13*4], xmm0
    inc r13d
    cmp r13d, SR*4
    jl .l
    inc r14d
    cmp r14d, 5
    jl .osc
    ; two-pole lowpass + slow swell
    xorps xmm4, xmm4
    xorps xmm5, xmm5
    xor r13d, r13d
.f:
    movss xmm0, [r12+r13*4]
    subss xmm0, xmm4
    mulss xmm0, [f_pad_lp]
    addss xmm4, xmm0
    movss xmm0, xmm4
    subss xmm0, xmm5
    mulss xmm0, [f_pad_lp]
    addss xmm5, xmm0
    movss xmm0, xmm5
    cmp r13d, SR/2
    jge .sw
    cvtsi2ss xmm1, r13d
    mulss xmm1, [f_2_sr]
    mulss xmm0, xmm1
.sw:
    movss [r12+r13*4], xmm0
    inc r13d
    cmp r13d, SR*4
    jl .f
    ; crossfade the tail into the loop start (loop 1s..4s)
    xor r13d, r13d
.x:
    cmp r13d, SR/2
    jge .xd
    cvtsi2ss xmm1, r13d
    mulss xmm1, [f_2_sr]            ; 0..1
    mov eax, SR*4-SR/2
    add eax, r13d                   ; tail position
    mov ecx, SR/2
    add ecx, r13d                   ; just before loop start
    movss xmm0, [r12+rax*4]
    movss xmm2, [f_one]
    subss xmm2, xmm1
    mulss xmm0, xmm2
    movss xmm3, [r12+rcx*4]
    mulss xmm3, xmm1
    addss xmm0, xmm3
    movss [r12+rax*4], xmm0
    inc r13d
    jmp .x
.xd:
    mov dword [smp_ls+S_PAD*4], SR
    mov dword [smp_le+S_PAD*4], SR*4-1
    mov dword [smp_root+S_PAD*4], 60
    mov edi, S_PAD
    movss xmm0, [f_peak]
    call smp_normalize
    RETURN
section .data
pad_detune dd 1.0, 1.0041, 0.9959, 2.0023, 0.5012
f_1_1024   dd 0.0009765625
f_pad_lp   dd 0.06
f_2_sr     dd 0.0000453515
section .text

; ---- noise + tone percussion generator ----
; parameters in a block (rdi): id, len, attack(samples), tau_amp, lp, hp,
;   noise amp, tone start hz, tone end hz, tone tau(sweep), tone amp, tone decay tau,
;   metallic amp
struc PERC
    .id     resd 1
    .len    resd 1
    .att    resd 1
    .tau    resd 1
    .lp     resd 1
    .hp     resd 1
    .namp   resd 1
    .f0     resd 1
    .f1     resd 1
    .ftau   resd 1
    .tamp   resd 1
    .ttau   resd 1
    .mamp   resd 1
endstruc

FUNC gen_perc, 96
    mov r15, rdi
    mov edi, [r15+PERC.id]
    mov esi, [r15+PERC.len]
    call smp_new
    mov r12, rax
    movss xmm0, [r15+PERC.tau]
    call decay_mult
    movss [rbp-48], xmm0            ; amp mult
    movss xmm0, [r15+PERC.ftau]
    call decay_mult
    movss [rbp-52], xmm0            ; sweep mult
    movss xmm0, [r15+PERC.ttau]
    call decay_mult
    movss [rbp-56], xmm0            ; tone amp mult
    movss xmm0, [f_one]
    movss [rbp-60], xmm0            ; env
    movss [rbp-64], xmm0            ; sweep env
    movss [rbp-68], xmm0            ; tone env
    xorps xmm0, xmm0
    movss [rbp-72], xmm0            ; tone phase
    movss [rbp-76], xmm0            ; lp state
    movss [rbp-80], xmm0            ; hp lp state
    mov dword [rbp-84], 0           ; metallic phases base
    xor r13d, r13d
.l:
    ; noise band
    call frand
    mulss xmm0, [r15+PERC.namp]
    ; metallic: sum of detuned squares
    movss xmm5, [r15+PERC.mamp]
    comiss xmm5, [f_zero]
    je .nm
    xor ecx, ecx
    xorps xmm4, xmm4
.mt:
    mov eax, r13d
    imul eax, [metal_inc+rcx*4]
    test eax, 0x80000000
    jz .mp
    subss xmm4, [f_one]
    jmp .mn
.mp:
    addss xmm4, [f_one]
.mn:
    inc ecx
    cmp ecx, 6
    jl .mt
    mulss xmm4, xmm5
    addss xmm0, xmm4
.nm:
    ; lowpass then highpass
    movss xmm1, [rbp-76]
    subss xmm0, xmm1
    mulss xmm0, [r15+PERC.lp]
    addss xmm1, xmm0
    movss [rbp-76], xmm1
    movss xmm2, [rbp-80]
    movss xmm3, xmm1
    subss xmm3, xmm2
    mulss xmm3, [r15+PERC.hp]
    addss xmm2, xmm3
    movss [rbp-80], xmm2
    subss xmm1, xmm2                ; high passed
    mulss xmm1, [rbp-60]
    movss [rbp-88], xmm1
    ; tone with pitch sweep
    movss xmm0, [r15+PERC.f0]
    subss xmm0, [r15+PERC.f1]
    mulss xmm0, [rbp-64]
    addss xmm0, [r15+PERC.f1]
    mulss xmm0, [f_twopi]
    mulss xmm0, [f_invsr]
    addss xmm0, [rbp-72]
    movss [rbp-72], xmm0
    call fast_sin
    mulss xmm0, [r15+PERC.tamp]
    mulss xmm0, [rbp-68]
    addss xmm0, [rbp-88]
    ; attack
    mov eax, [r15+PERC.att]
    cmp r13d, eax
    jge .na
    cvtsi2ss xmm1, r13d
    cvtsi2ss xmm2, eax
    divss xmm1, xmm2
    mulss xmm0, xmm1
.na:
    movss [r12+r13*4], xmm0
    movss xmm0, [rbp-60]
    mulss xmm0, [rbp-48]
    movss [rbp-60], xmm0
    movss xmm0, [rbp-64]
    mulss xmm0, [rbp-52]
    movss [rbp-64], xmm0
    movss xmm0, [rbp-68]
    mulss xmm0, [rbp-56]
    movss [rbp-68], xmm0
    inc r13d
    cmp r13d, [r15+PERC.len]
    jl .l
    mov eax, [r15+PERC.id]
    mov dword [smp_root+rax*4], 60
    mov edi, eax
    movss xmm0, [f_peak]
    call smp_normalize
    RETURN

section .data
; metallic square phase increments (freq * 2^32 / SR)
metal_inc dd 40920000, 55390000, 78100000, 96200000, 117400000, 181300000
;             id        len         att   tau     lp    hp    namp  f0     f1    ftau   tamp  ttau   mamp
perc_kick:
    dd S_KICK,  SR/2,       20, 0.05,  0.10, 0.01, 0.15, 120.0, 46.0, 0.035, 1.0, 0.30, 0.0
perc_brush:
    dd S_BRUSH, SR/2,     2200, 0.12,  0.20, 0.04, 1.0,  200.0, 200.0, 0.01, 0.0, 0.01, 0.0
perc_tap:
    dd S_TAP,   SR/3,       40, 0.07,  0.14, 0.02, 1.0,  210.0, 180.0, 0.02, 0.5, 0.05, 0.0
perc_ride:
    dd S_RIDE,  SR*2,       10, 0.9,   0.9,  0.30, 0.35, 3200.0, 3100.0, 0.2, 0.25, 0.35, 0.12
perc_hat:
    dd S_HAT,   SR/6,       10, 0.035, 0.95, 0.40, 0.6,  200.0, 200.0, 0.01, 0.0, 0.01, 0.15
perc_shaker:
    dd S_SHAKER, SR/6,     500, 0.04,  0.6,  0.30, 1.0,  200.0, 200.0, 0.01, 0.0, 0.01, 0.0
perc_rim:
    dd S_RIM,   SR/8,        5, 0.02,  0.7,  0.2,  0.4,  1700.0, 1600.0, 0.02, 0.8, 0.02, 0.0
perc_rumble:
    dd S_RUMBLE, SR,       2000, 0.5,  0.02, 0.001, 1.0, 55.0, 40.0, 0.5, 0.4, 0.4, 0.0
perc_boom:
    dd S_BOOM,  SR*2,       30, 0.7,   0.05, 0.002, 1.0, 90.0, 28.0, 0.12, 1.0, 0.8, 0.0
section .text

; =====================================================================
;  wav overrides: samples/<name>.wav (16-bit PCM, mono or stereo)
; =====================================================================
FUNC try_load_wav, 16
    mov [rbp-48], edi               ; sample id
    ; path
    lea rdi, [path_buf]
    lea rsi, [str_samples]
.c1:
    mov al, [rsi]
    test al, al
    jz .c1d
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .c1
.c1d:
    mov eax, [rbp-48]
    mov rsi, [wav_names+rax*8]
.c2:
    mov al, [rsi]
    test al, al
    jz .c2d
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .c2
.c2d:
    lea rsi, [str_wav]
.c3:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .c3
    lea rdi, [path_buf]
    lea rsi, [str_rb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz .out
    mov rdi, rax
    mov esi, 1
    lea rdx, [wav_spec]
    lea rcx, [wav_buf]
    lea r8, [wav_len]
    CALLC SDL_LoadWAV_RW
    test rax, rax
    jz .out
    cmp word [wav_spec+4], AUDIO_S16LSB
    jne .free
    movzx r13d, byte [wav_spec+6]   ; channels
    cmp r13d, 1
    jl .free
    cmp r13d, 2
    jg .free
    mov eax, [wav_len]
    shr eax, 1
    xor edx, edx
    div r13d
    mov r14d, eax                   ; frames
    CLAMP r14d, 16, SR*8
    mov edi, [rbp-48]
    mov esi, r14d
    call smp_new
    mov r12, rax
    mov rsi, [wav_buf]
    xor ecx, ecx
.cv:
    movsx eax, word [rsi]
    cmp r13d, 2
    jne .mono
    movsx edx, word [rsi+2]
    add eax, edx
    sar eax, 1
.mono:
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_inv32k]
    movss [r12+rcx*4], xmm0
    lea rsi, [rsi+r13*2]
    inc ecx
    cmp ecx, r14d
    jl .cv
    ; sample rate ratio
    cvtsi2ss xmm0, dword [wav_spec]
    divss xmm0, [f_sr]
    mov eax, [rbp-48]
    movss [smp_rate+rax*4], xmm0
    mov dword [smp_ls+rax*4], 0
    mov dword [smp_le+rax*4], 0
.free:
    mov rdi, [wav_buf]
    CALLC SDL_FreeWAV
.out:
    RETURN

; =====================================================================
;  init
; =====================================================================
FUNC audio_init, 64
    ; semitone ratio table
    xor ebx, ebx
.sr:
    lea eax, [rbx-48]
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_ln2_12]
    call fexp
    movss [semi_ratio+rbx*4], xmm0
    inc ebx
    cmp ebx, 97
    jl .sr
    ; instruments
    mov edi, S_RHODES_LO
    mov esi, 48
    call gen_rhodes
    call loading_tick
    mov edi, S_RHODES_HI
    mov esi, 72
    call gen_rhodes
    call loading_tick
    ; upright bass: soft thumb pluck, dark string, warm body
    mov dword [ks_exc_a], 0x3DCCCCCD    ; 0.10
    mov dword [ks_loop_a], 0x3EB33333   ; 0.35
    mov dword [ks_out_a], 0x3E4CCCCD    ; 0.20
    mov dword [ks_pluck], 0x3E800000    ; 0.25
    mov dword [ks_noise], 0x3E99999A    ; 0.3
    mov edi, S_BASS
    mov esi, 33
    movss xmm0, [f_ks_bass]
    call gen_ks
    ; nylon guitar: brighter pluck, lighter damping
    mov dword [ks_exc_a], 0x3F000000    ; 0.5
    mov dword [ks_loop_a], 0x3F333333   ; 0.7
    mov dword [ks_out_a], 0x3F19999A    ; 0.6
    mov dword [ks_pluck], 0x3E4CCCCD    ; 0.2
    mov dword [ks_noise], 0x3F000000    ; 0.5
    mov edi, S_GUITAR
    mov esi, 57
    movss xmm0, [f_ks_gtr]
    call gen_ks
    call loading_tick
    mov edi, S_VIBES
    mov esi, 72
    lea rdx, [modal_vibes]
    call gen_modal
    mov edi, S_MARIMBA
    mov esi, 72
    lea rdx, [modal_marimba]
    call gen_modal
    mov edi, S_BELL
    mov esi, 84
    lea rdx, [modal_bell]
    call gen_modal
    call loading_tick
    call gen_horn
    call gen_pad
    call loading_tick
    lea rdi, [perc_kick]
    call gen_perc
    lea rdi, [perc_brush]
    call gen_perc
    lea rdi, [perc_tap]
    call gen_perc
    lea rdi, [perc_ride]
    call gen_perc
    lea rdi, [perc_hat]
    call gen_perc
    lea rdi, [perc_shaker]
    call gen_perc
    lea rdi, [perc_rim]
    call gen_perc
    lea rdi, [perc_rumble]
    call gen_perc
    lea rdi, [perc_boom]
    call gen_perc
    call loading_tick
    ; the recorded instruments
    call nyc_load
    call loading_tick
    ; user overrides
    xor ebx, ebx
.ov:
    mov edi, ebx
    call try_load_wav
    inc ebx
    cmp ebx, S_COUNT
    jl .ov

    ; reverb delay lengths
    ; voices off
    lea rdi, [voices]
    xor eax, eax
    mov ecx, NVOICES*V_SIZE/4
    rep stosd
    lea rdi, [events]
    mov ecx, MAX_EVENTS*E_SIZE/4
    rep stosd

    mov dword [music_on], 1
    mov dword [music_vol], 0x3F19999A   ; 0.6
    mov dword [sfx_vol], 0x3F4CCCCD     ; 0.8
    call music_init

    ; open device: 44.1k stereo s16
    lea rdi, [wav_spec]
    xor eax, eax
    mov ecx, 8
    rep stosd
    mov dword [wav_spec], SR
    mov word [wav_spec+4], AUDIO_S16LSB
    mov byte [wav_spec+6], 2
    mov word [wav_spec+8], 1024
    xor edi, edi
    xor esi, esi
    lea rdx, [wav_spec]
    xor ecx, ecx
    xor r8d, r8d
    CALLC SDL_OpenAudioDevice
    test eax, eax
    jz .out
    mov [audio_dev], eax
    mov dword [audio_ok], 1
    mov edi, eax
    xor esi, esi
    CALLC SDL_PauseAudioDevice
.out:
    RETURN
section .data
f_ks_bass dd 0.9995
f_ks_gtr  dd 0.9992
section .text

; ---------------------------------------------------------------------
;  nyc_load: turn the embedded 16-bit recordings into pool samples
; ---------------------------------------------------------------------
section .data
f_inv32k_s dd 0.000030517578
section .text
FUNC nyc_load, 16
    xor ebx, ebx
.z:
    cmp ebx, NZ_COUNT
    jge .out
    imul eax, ebx, 24
    lea r12, [nyc_zones+rax]
    lea r13d, [rbx+S_NYC]           ; sample id
    mov edi, r13d
    mov esi, [r12+4]                ; length
    call smp_new
    mov r14, rax
    ; int16 -> float
    mov eax, [r12]
    lea rsi, [nyc_pcm+rax*2]
    xor ecx, ecx
.c:
    cmp ecx, [r12+4]
    jge .cd
    movsx eax, word [rsi+rcx*2]
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_inv32k]
    movss [r14+rcx*4], xmm0
    inc ecx
    jmp .c
.cd:
    mov eax, [r12+8]
    test eax, eax
    jnz .r
    mov eax, 60                     ; unpitched: note 60 = as recorded
.r:
    mov [smp_root+r13*4], eax
    mov eax, [r12+12]
    mov [smp_ls+r13*4], eax
    mov eax, [r12+16]
    mov [smp_le+r13*4], eax
    cvtsi2ss xmm0, dword [r12+20]
    mulss xmm0, [f_invsr]
    movss [smp_rate+r13*4], xmm0
    inc ebx
    jmp .z
.out:
    RETURN

; =====================================================================
;  voices
; =====================================================================
; voice_start(edi inst, esi midi note, xmm0 velocity, edx dur samples, xmm1 pan)
FUNC voice_start, 32
    mov eax, [solo_inst]
    test eax, eax
    js .all
    cmp eax, edi
    jne .quiet
.all:
    movss [rbp-48], xmm0
    movss [rbp-52], xmm1
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    imul eax, r12d, INST_REC
    lea r15, [inst_table+rax]
    mov ebx, [r15]                  ; first zone
    ; several zones: take the one recorded nearest this note
    mov ecx, [r15+24]
    cmp ecx, 1
    jle .ns
    lea r8d, [rbx+rcx]              ; end
    mov r9d, 0x7fffffff             ; best distance
    mov r10d, ebx                   ; best zone
.z:
    mov eax, r13d
    sub eax, [smp_root+rbx*4]
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, r9d
    jge .zn
    mov r9d, eax
    mov r10d, ebx
.zn:
    inc ebx
    cmp ebx, r8d
    jl .z
    mov ebx, r10d
.ns:
    cmp qword [smp_ptr+rbx*8], 0
    je .out
    ; find a free voice (or steal the quietest)
    xor ecx, ecx
    mov edx, -1
    movss xmm2, [f_two]
.f:
    cmp ecx, NVOICES
    jge .steal
    mov eax, ecx
    shl eax, 6
    cmp qword [voices+rax+V_DATA], 0
    je .have
    movss xmm3, [voices+rax+V_ENV]
    comiss xmm3, xmm2
    jae .fn
    movss xmm2, xmm3
    mov edx, ecx
.fn:
    inc ecx
    jmp .f
.steal:
    mov ecx, edx
    mov eax, ecx
    shl eax, 6
.have:
    lea rdi, [voices+rax]
    mov rax, [smp_ptr+rbx*8]
    mov [rdi+V_DATA], rax
    mov qword [rdi+V_POS], 0
    mov eax, [smp_len+rbx*4]
    sub eax, 2
    mov [rdi+V_LEN], eax
    mov eax, [smp_ls+rbx*4]
    mov [rdi+V_LS], eax
    mov eax, [smp_le+rbx*4]
    mov [rdi+V_LE], eax
    ; pitch step = ratio(note-root) * rate
    mov eax, r13d
    sub eax, [smp_root+rbx*4]
    add eax, 48
    CLAMP eax, 0, 96
    movss xmm0, [semi_ratio+rax*4]
    mulss xmm0, [smp_rate+rbx*4]
    mulss xmm0, [f_2p24]
    cvtss2si rax, xmm0
    shl rax, 8                      ; 2^32
    mov [rdi+V_STEP], rax
    ; gains
    movss xmm0, [rbp-48]
    mulss xmm0, [r15+4]
    movss xmm1, [rbp-52]
    addss xmm1, [r15+8]
    ; equal-ish pan: l = (1-p)/2+0.25, r = (1+p)/2+0.25
    movss xmm2, [f_one]
    subss xmm2, xmm1
    mulss xmm2, [f_half]
    addss xmm2, [f_0_25b]
    mulss xmm2, xmm0
    movss [rdi+V_GL], xmm2
    movss xmm2, [f_one]
    addss xmm2, xmm1
    mulss xmm2, [f_half]
    addss xmm2, [f_0_25b]
    mulss xmm2, xmm0
    movss [rdi+V_GR], xmm2
    mov dword [rdi+V_ENV], 0x3F800000
    mov dword [rdi+V_REL], 0x3F800000
    ; ringing instruments sustain well past their written length
    cmp dword [r15+16], 0
    je .dur
    lea r14d, [r14+r14*2]
.dur:
    mov [rdi+V_DUR], r14d
    mov eax, [r15+12]
    mov [rdi+V_SEND], eax
    mov eax, [r15+20]
    mov [rdi+V_TREM], eax
.out:
.quiet:
    RETURN
section .data
f_2p24   dd 16777216.0
f_0_25b  dd 0.25
section .text

; ---------------------------------------------------------------------
;  event queue: ev_add(rsi time(q), edi inst, edx note, xmm0 vel, ecx dur, xmm1 pan)
; ---------------------------------------------------------------------
ev_add:
    xor eax, eax
.f:
    cmp eax, MAX_EVENTS
    jge .full
    mov r8d, eax
    shl r8d, 5
    cmp dword [events+r8+E_USED], 0
    je .have
    inc eax
    jmp .f
.have:
    lea r8, [events+r8]
    mov [r8+E_TIME], rsi
    mov [r8+E_INST], edi
    mov [r8+E_NOTE], edx
    movss [r8+E_VEL], xmm0
    mov [r8+E_DUR], ecx
    movss [r8+E_PAN], xmm1
    mov dword [r8+E_USED], 1
.full:
    ret

; fire events due before (rdi time)
FUNC ev_fire
    mov r12, rdi
    xor ebx, ebx
.l:
    cmp ebx, MAX_EVENTS
    jge .out
    mov eax, ebx
    shl eax, 5
    lea r13, [events+rax]
    cmp dword [r13+E_USED], 0
    je .n
    cmp [r13+E_TIME], r12
    jg .n
    mov dword [r13+E_USED], 0
    mov edi, [r13+E_INST]
    mov esi, [r13+E_NOTE]
    movss xmm0, [r13+E_VEL]
    mov edx, [r13+E_DUR]
    movss xmm1, [r13+E_PAN]
    ; sfx use their own volume, music theirs
    call voice_start
.n:
    inc ebx
    jmp .l
.out:
    RETURN

; =====================================================================
;  mixer
; =====================================================================
FUNC mix_chunk, 32
    ; clear accumulators handled per sample
    xor r12d, r12d                  ; sample in chunk
.s:
    cmp r12d, CHUNK
    jge .done
    xorps xmm6, xmm6                ; L
    xorps xmm7, xmm7                ; R
    xorps xmm8, xmm8                ; reverb send
    xor ebx, ebx
.v:
    mov eax, ebx
    shl eax, 6
    lea r13, [voices+rax]
    mov rsi, [r13+V_DATA]
    test rsi, rsi
    jz .vn
    mov rax, [r13+V_POS]
    mov rcx, rax
    shr rcx, 32                     ; index
    cmp ecx, [r13+V_LEN]
    jge .kill
    mov edx, eax                    ; frac
    shr edx, 8
    cvtsi2ss xmm1, edx
    mulss xmm1, [f_inv2p24]
    movss xmm0, [rsi+rcx*4]
    movss xmm2, [rsi+rcx*4+4]
    subss xmm2, xmm0
    mulss xmm2, xmm1
    addss xmm0, xmm2
    mulss xmm0, [r13+V_ENV]
    ; tremolo (vibes / rhodes motor)
    cmp dword [r13+V_TREM], 0
    je .nt
    mov eax, [r13+V_TREM]
    add eax, 8
    and eax, 0xFFFF
    or eax, 0x10000                 ; keep non-zero (= enabled)
    mov [r13+V_TREM], eax
    movss xmm4, xmm0
    and eax, 0xFFFF
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_trem_w]
    push rcx
    call fast_sin
    pop rcx
    mulss xmm0, [f_trem_d]
    addss xmm0, [f_one]
    mulss xmm0, xmm4
.nt:
    movss xmm1, xmm0
    mulss xmm1, [r13+V_GL]
    addss xmm6, xmm1
    movss xmm2, xmm0
    mulss xmm2, [r13+V_GR]
    addss xmm7, xmm2
    addss xmm1, xmm2
    mulss xmm1, [r13+V_SEND]
    addss xmm8, xmm1
    ; advance
    mov rax, [r13+V_POS]
    add rax, [r13+V_STEP]
    mov [r13+V_POS], rax
    ; looping
    mov edx, [r13+V_LE]
    test edx, edx
    jz .nl
    shr rax, 32
    cmp eax, edx
    jl .nl
    sub edx, [r13+V_LS]
    shl rdx, 32
    sub [r13+V_POS], rdx
.nl:
    ; duration / release
    mov eax, [r13+V_DUR]
    test eax, eax
    jz .env
    dec eax
    mov [r13+V_DUR], eax
    jnz .env
    mov eax, [f_rel_fast]
    mov [r13+V_REL], eax
.env:
    movss xmm0, [r13+V_ENV]
    mulss xmm0, [r13+V_REL]
    movss [r13+V_ENV], xmm0
    comiss xmm0, [f_minenv]
    ja .vn
.kill:
    mov qword [r13+V_DATA], 0
.vn:
    inc ebx
    cmp ebx, NVOICES
    jl .v

    ; ---- reverb: 4 combs per side, 2 allpasses per side ----
    movss [rev_in], xmm8
    xorps xmm9, xmm9                ; wet L
    xorps xmm10, xmm10              ; wet R
    xor ecx, ecx
.cb:
    mov eax, [comb_idx+rcx*4]
    imul edx, ecx, 1800
    add edx, eax
    movss xmm0, [comb_buf+rdx*4]    ; out
    ; damped feedback
    movss xmm1, [comb_filt+rcx*4]
    mulss xmm1, [f_damp]
    movss xmm2, xmm0
    mulss xmm2, [f_ndamp]
    addss xmm1, xmm2
    movss [comb_filt+rcx*4], xmm1
    mulss xmm1, [f_fb]
    addss xmm1, [rev_in]
    movss [comb_buf+rdx*4], xmm1
    inc eax
    cmp eax, [comb_len+rcx*4]
    jl .ci
    xor eax, eax
.ci:
    mov [comb_idx+rcx*4], eax
    cmp ecx, 4
    jge .cr
    addss xmm9, xmm0
    jmp .cn
.cr:
    addss xmm10, xmm0
.cn:
    inc ecx
    cmp ecx, 8
    jl .cb
    ; allpasses: 0,1 left  2,3 right
    xor ecx, ecx
.ap:
    mov eax, [ap_idx+rcx*4]
    imul edx, ecx, 700
    add edx, eax
    movss xmm0, [ap_buf+rdx*4]      ; b
    movaps xmm1, xmm9
    cmp ecx, 2
    jl .apl
    movaps xmm1, xmm10
.apl:
    movss xmm2, xmm0
    subss xmm2, xmm1                ; out = b - in
    movss xmm3, xmm0
    mulss xmm3, [f_apfb]
    addss xmm3, xmm1
    movss [ap_buf+rdx*4], xmm3
    cmp ecx, 2
    jl .apL
    movaps xmm10, xmm2
    jmp .apn
.apL:
    movaps xmm9, xmm2
.apn:
    inc eax
    cmp eax, [ap_len+rcx*4]
    jl .api
    xor eax, eax
.api:
    mov [ap_idx+rcx*4], eax
    inc ecx
    cmp ecx, 4
    jl .ap
    mulss xmm9, [f_revout]
    mulss xmm10, [f_revout]
    addss xmm6, xmm9
    addss xmm7, xmm10

    ; soft clip and store
    movss xmm0, xmm6
    call softclip
    mulss xmm0, [f_32767]
    cvtss2si eax, xmm0
    mov [mixbuf+r12*4], ax
    movss xmm0, xmm7
    call softclip
    mulss xmm0, [f_32767]
    cvtss2si eax, xmm0
    mov [mixbuf+r12*4+2], ax
    inc r12d
    jmp .s
.done:
    RETURN
section .data
f_inv2p24 dd 5.9604645e-08
f_trem_w  dd 0.0000958738     ; 2pi / 65536 (phase += 8/sample = 5.4 Hz)
f_clip    dd 3.0
section .text

; softclip: x*(27+x^2)/(27+9x^2), clamped at |x|<=3
softclip:
    minss xmm0, [f_clip]
    movss xmm1, [f_clip]
    xorps xmm2, xmm2
    subss xmm2, xmm1
    maxss xmm0, xmm2
    movss xmm1, xmm0
    mulss xmm1, xmm0                ; x^2
    movss xmm2, xmm1
    addss xmm2, [f_27]
    mulss xmm2, xmm0
    mulss xmm1, [f_9]
    addss xmm1, [f_27]
    divss xmm2, xmm1
    movss xmm0, xmm2
    ret

; ---------------------------------------------------------------------
;  audio_update: keep ~100 ms queued, so one slow frame (a big window
;  fully zoomed out, a save, a burst of city growth) never starves it
; ---------------------------------------------------------------------
FUNC audio_update
    call music_fade_tick
    cmp dword [audio_ok], 0
    je .out
.more:
    mov edi, [audio_dev]
    CALLC SDL_GetQueuedAudioSize
    cmp eax, 4400*4
    jae .out
    ; compose ahead
    mov rax, [audio_time]
    add rax, SR/2
    cmp rax, [mus_next_bar]
    jl .nb
    call compose_bar
.nb:
    ; events for this chunk
    mov rdi, [audio_time]
    add rdi, CHUNK
    call ev_fire
    call mix_chunk
    add qword [audio_time], CHUNK
    mov edi, [audio_dev]
    lea rsi, [mixbuf]
    mov edx, CHUNK*4
    CALLC SDL_QueueAudio
    jmp .more
.out:
    RETURN

; =====================================================================
;  sound effects: sfx_play(edi id)
; =====================================================================
FUNC sfx_play
    cmp dword [audio_ok], 0
    je .out
    cmp edi, SFX_COUNT
    jae .out
    mov r12, [sfx_scripts+rdi*8]
.l:
    movzx eax, byte [r12]
    cmp eax, 255
    je .out
    ; delay (10 ms units) -> samples
    imul eax, eax, 441
    movsxd rsi, eax
    add rsi, [audio_time]
    add rsi, CHUNK
    movzx edi, byte [r12+1]
    movzx edx, byte [r12+2]
    cmp edx, 100
    jl .rel
    sub edx, 100
    jmp .note
.rel:
    add edx, [mus_key]
    add edx, 12
.note:
    movzx eax, byte [r12+3]
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_inv127]
    mulss xmm0, [sfx_vol]
    mov ecx, SR/3
    xorps xmm1, xmm1
    call ev_add
    add r12, 4
    jmp .l
.out:
    RETURN
section .data
f_inv127 dd 0.007874
section .text

; =====================================================================
;  composer
; =====================================================================
; (the composer lives in music.asm)

music_toggle:
    xor dword [music_on], 1
    ret
