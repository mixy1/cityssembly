; =====================================================================
;  PALETTE - 8-bit palette with shading ramps, seasons and day/night
;
;  Like the classic isometric sims, all art is drawn with palette
;  indices.  Each frame the indices are re-expanded to true colour, so
;  seasons, sunsets, night lighting and water shimmer are all free.
; =====================================================================

section .data

; dark / mid / light control colours for every ramp (seasonal ramps are
; overwritten each frame)
ramp_defs:
    db  48, 52, 60,   122,126,134,  212,214,218   ; grey
    db  34, 36, 42,    66, 68, 76,  110,112,120   ; asphalt
    db  40, 74, 28,    84,140, 48,  156,196, 84   ; grass (seasonal)
    db  16, 46, 22,    40, 96, 36,  104,156, 62   ; leaf (seasonal)
    db 120, 96, 60,   200,174,116,  246,232,184   ; sand
    db  58, 36, 22,   122, 82, 48,  194,146, 94   ; wood
    db  84, 32, 26,   164, 72, 52,  226,144,112   ; brick
    db  72, 24, 20,   156, 54, 38,  232,114, 82   ; roof
    db  24, 36, 84,    58, 92,176,  146,186,244   ; blue
    db  22, 42, 60,    64,114,146,  176,224,240   ; glass
    db 110, 80, 10,   224,184, 44,  255,242,156   ; yellow
    db 110, 50, 10,   224,124, 44,  255,204,136   ; orange
    db  52, 30, 72,   114, 72,156,  196,164,236   ; purple
    db 112, 92, 72,   214,194,164,  252,244,228   ; cream
    db 118,122,130,   212,216,222,  255,255,255   ; white
    db  16, 40, 80,    40, 92,152,  112,172,222   ; deep water
    db  20, 62, 62,    62,134,122,  154,214,194   ; teal
    db  60, 64, 30,   122,126, 62,  194,194,124   ; olive
    db  92, 56, 40,   194,134, 94,  252,214,174   ; skin
    db  24, 84, 36,    64,176, 80,  156,246,156   ; zone R
    db  24, 56,120,    64,124,220,  156,204,255   ; zone C
    db 110, 88, 16,   220,176, 40,  255,234,124   ; zone I
    db  30, 54, 20,    76,120, 40,  150,190, 80   ; leaf2 (seasonal)
    db  92, 12, 12,   206, 44, 40,  255,146,124   ; red

; seasonal definitions: spring, summer, autumn, winter
season_grass:
    db  40, 86, 30,    96,164, 56,  180,224,104
    db  40, 74, 28,    84,140, 48,  156,196, 84
    db  70, 72, 30,   140,136, 60,  206,194,112
    db 124,134,156,   208,218,232,  250,252,255
season_leaf:
    db  20, 58, 26,    56,124, 44,  144,200, 82
    db  16, 46, 22,    40, 96, 36,  104,156, 62
    db  84, 32, 10,   186, 94, 30,  244,184, 72
    db  64, 68, 76,   156,166,180,  234,240,248
season_leaf2:
    db  84, 44, 72,   210,128,178,  252,206,232
    db  30, 54, 20,    76,120, 40,  150,190, 80
    db 104, 20, 12,   196, 54, 32,  252,136, 74
    db  64, 68, 76,   156,166,180,  234,240,248

fixed_low:            ; indices 0..15
    db   0,  0,  0,     0,  0,  0,   255,255,255,   18, 18, 26
    db 255,255,255,   255, 84, 64,    84,255,124,  255,224, 64
    db  40, 40, 44,    90, 90, 96,   160,160,170,   20, 16, 12
    db 255,255,255,   255,255,255,   255,255,255,  255,255,255

ui_colors:            ; r,g,b,a for PAL_UI..PAL_UI+15
    db  20, 24, 36,224     ; bg
    db  10, 12, 20,240     ; bg2
    db  96,108,140,255     ; edge hi
    db   6,  8, 14,255     ; edge lo
    db 238,240,246,255     ; text
    db 140,148,170,255     ; dim
    db  96,196,255,255     ; accent
    db 112,224,112,255     ; good
    db 244, 84, 72,255     ; bad
    db 252,192, 64,255     ; warn
    db   0,  0,  0,112     ; shadow
    db  44, 50, 72,240     ; button
    db  74, 86,120,250     ; button hover
    db 232,164, 44,255     ; button selected
    db 255,214, 84,255     ; gold
    db   0,  0,  0,255     ; black

heat_colors:
    db  30, 50,140,   30, 80,170,   30,120,190,   30,160,180
    db  40,180,140,   60,190, 90,  100,200, 60,  150,210, 50
    db 200,210, 50,  230,190, 40,  240,160, 40,  240,120, 30
    db 230, 80, 30,  210, 50, 30,  180, 30, 30,  140, 20, 30

; night-glow colours: day rgb, night rgb
glow_colors:
    db  46, 76,104,   255,222,124
    db  52, 82,112,   255,198, 92
    db  44, 70, 98,   250,242,184
    db  56, 88,116,   255,178, 84
    db  96, 96, 86,   255,244,206     ; street lamp
    db 150, 30, 30,   255, 64, 44     ; beacon
    db 164, 64,124,   255, 96,210     ; neon pink
    db  64,124,154,    96,244,255     ; neon cyan

; time of day tint keyframes: phase(word), r, g, b, pad
tod_keys:
    dw   0
    db  66, 82,150, 0
    dw  40
    db  66, 82,150, 0
    dw  62
    db 236,168,150, 0
    dw  84
    db 255,250,242, 0
    dw 172
    db 255,250,242, 0
    dw 194
    db 250,160,116, 0
    dw 216
    db  66, 82,150, 0
    dw 256
    db  66, 82,150, 0

section .bss
pal_base        resb 256*3
tod             resd 1          ; time of day 0..65535
tod_lock        resd 1          ; 1 = always day
season_pos      resd 1          ; 0..1023
tint_r          resd 1
tint_g          resd 1
tint_b          resd 1
glow_amt        resd 1
water_phase     resd 1
blend_def       resb 12

section .text

; lerp8: eax = a + (b-a)*t/256   (edi=a, esi=b, edx=t)
lerp8:
    mov eax, esi
    sub eax, edi
    imul eax, edx
    sar eax, 8
    add eax, edi
    ret

; ---------------------------------------------------------------------
;  ramp_fill(rdi = dst 24 bytes, rsi = 9-byte def)
; ---------------------------------------------------------------------
ramp_fill:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    xor ebx, ebx                ; shade
.shade:
    ; t = shade*256/7 (0..256)
    mov eax, ebx
    shl eax, 8
    xor edx, edx
    mov ecx, 7
    div ecx
    mov r14d, eax               ; t
    xor ecx, ecx                ; channel
.ch:
    cmp r14d, 128
    jge .upper
    movzx edi, byte [r13+rcx]
    movzx esi, byte [r13+rcx+3]
    mov edx, r14d
    shl edx, 1
    jmp .do
.upper:
    movzx edi, byte [r13+rcx+3]
    movzx esi, byte [r13+rcx+6]
    mov edx, r14d
    sub edx, 128
    shl edx, 1
.do:
    call lerp8
    CLAMP eax, 0, 255
    lea r8, [rbx+rbx*2]
    mov [r12+r8], al
    inc r12
    inc ecx
    cmp ecx, 3
    jl .ch
    sub r12, 3
    inc ebx
    cmp ebx, 8
    jl .shade
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ---------------------------------------------------------------------
;  season_ramp(edi = ramp index, rsi = 4x9 season defs)
; ---------------------------------------------------------------------
FUNC season_ramp
    mov r12d, edi
    mov r13, rsi
    mov eax, [season_pos]
    and eax, 1023
    mov r14d, eax
    shr r14d, 8                 ; season k
    and eax, 255
    mov r15d, eax               ; frac
    ; ease: hold each season for the first half, blend in the second
    sub r15d, 128
    jge .blend
    xor r15d, r15d
.blend:
    shl r15d, 1
    lea eax, [r14+1]
    and eax, 3
    imul eax, 9
    lea rbx, [r13+rax]          ; next def
    imul eax, r14d, 9
    add r13, rax                ; cur def
    xor ecx, ecx
.c:
    movzx edi, byte [r13+rcx]
    movzx esi, byte [rbx+rcx]
    mov edx, r15d
    push rcx
    push rcx
    call lerp8
    pop rcx
    pop rcx
    mov [blend_def+rcx], al
    inc ecx
    cmp ecx, 9
    jl .c
    lea eax, [r12*8+RAMP_BASE]
    imul eax, 3
    lea rdi, [pal_base+rax]
    lea rsi, [blend_def]
    call ramp_fill
    RETURN

; ---------------------------------------------------------------------
FUNC palette_init
    ; fixed low colours
    lea rsi, [fixed_low]
    lea rdi, [pal_base]
    mov ecx, 48
    rep movsb
    ; ramps
    xor ebx, ebx
.r:
    lea eax, [rbx*8+RAMP_BASE]
    imul eax, 3
    lea rdi, [pal_base+rax]
    imul eax, ebx, 9
    lea rsi, [ramp_defs+rax]
    call ramp_fill
    inc ebx
    cmp ebx, RAMP_COUNT
    jl .r
    ; heat colours
    lea rsi, [heat_colors]
    lea rdi, [pal_base+PAL_HEAT*3]
    mov ecx, 48
    rep movsb
    ; ui colours into pal_base (rgb only)
    xor ecx, ecx
.u:
    mov al, [ui_colors+rcx*4]
    lea edx, [rcx+PAL_UI]
    imul edx, 3
    mov [pal_base+rdx], al
    mov al, [ui_colors+rcx*4+1]
    mov [pal_base+rdx+1], al
    mov al, [ui_colors+rcx*4+2]
    mov [pal_base+rdx+2], al
    inc ecx
    cmp ecx, 16
    jl .u
    mov dword [tod], 100*256
    call palette_update
    call build_ui_lut
    RETURN

; ---------------------------------------------------------------------
;  ui lut: untinted palette, alpha from ui_colors, index 0 transparent
; ---------------------------------------------------------------------
build_ui_lut:
    xor ecx, ecx
.l:
    lea edx, [rcx+rcx*2]
    movzx eax, byte [pal_base+rdx]
    shl eax, 16
    movzx r8d, byte [pal_base+rdx+1]
    shl r8d, 8
    or eax, r8d
    movzx r8d, byte [pal_base+rdx+2]
    or eax, r8d
    or eax, 0xFF000000
    cmp ecx, PAL_UI
    jl .store
    cmp ecx, PAL_UI+16
    jge .store
    and eax, 0x00FFFFFF
    movzx r8d, byte [ui_colors+(rcx-PAL_UI)*4+3]
    shl r8d, 24
    or eax, r8d
.store:
    mov [lut_ui+rcx*4], eax
    inc ecx
    cmp ecx, 256
    jl .l
    mov dword [lut_ui], 0
    ret

; ---------------------------------------------------------------------
;  palette_update: recompute tint, seasons, water and the world lut
; ---------------------------------------------------------------------
FUNC palette_update
    ; seasonal ramps
    mov edi, R_GRASS
    lea rsi, [season_grass]
    call season_ramp
    mov edi, R_LEAF
    lea rsi, [season_leaf]
    call season_ramp
    mov edi, R_LEAF2
    lea rsi, [season_leaf2]
    call season_ramp

    ; ---- time of day tint ----
    mov eax, [tod]
    shr eax, 8                  ; phase 0..255
    cmp dword [tod_lock], 0
    je .tl
    mov eax, 128
.tl:
    mov r12d, eax
    lea rbx, [tod_keys]
.find:
    movzx eax, word [rbx+6]     ; next key phase
    cmp r12d, eax
    jl .found
    add rbx, 6
    jmp .find
.found:
    movzx r13d, word [rbx]      ; key phase a
    movzx r14d, word [rbx+6]    ; key phase b
    mov eax, r12d
    sub eax, r13d
    shl eax, 8
    mov ecx, r14d
    sub ecx, r13d
    xor edx, edx
    div ecx
    mov r15d, eax               ; t 0..256
    movzx edi, byte [rbx+2]
    movzx esi, byte [rbx+8]
    mov edx, r15d
    call lerp8
    mov [tint_r], eax
    movzx edi, byte [rbx+3]
    movzx esi, byte [rbx+9]
    mov edx, r15d
    call lerp8
    mov [tint_g], eax
    movzx edi, byte [rbx+4]
    movzx esi, byte [rbx+10]
    mov edx, r15d
    call lerp8
    mov [tint_b], eax
    ; glow = clamp((190-g)*256/100)
    mov eax, 190
    sub eax, [tint_g]
    imul eax, 256
    cdq
    mov ecx, 100
    idiv ecx
    CLAMP eax, 0, 256
    mov [glow_amt], eax

    ; ---- water shimmer ----
    xor ebx, ebx
.w:
    mov eax, ebx
    shl eax, 5
    add eax, [water_phase]
    and eax, 255
    ; triangle wave 0..256
    cmp eax, 128
    jl .tri
    mov ecx, 256
    sub ecx, eax
    mov eax, ecx
.tri:
    shl eax, 1
    mov r12d, eax
    lea r13d, [rbx+PAL_WATER]
    imul r13d, 3
    mov edi, 34
    mov esi, 84
    mov edx, r12d
    call lerp8
    mov [pal_base+r13], al
    mov edi, 86
    mov esi, 150
    mov edx, r12d
    call lerp8
    mov [pal_base+r13+1], al
    mov edi, 150
    mov esi, 206
    mov edx, r12d
    call lerp8
    mov [pal_base+r13+2], al
    inc ebx
    cmp ebx, 8
    jl .w
    ; winter: frost the water slightly
    mov eax, [season_pos]
    shr eax, 8
    and eax, 3

    ; ---- build world lut ----
    xor ebx, ebx
.l:
    lea edx, [rbx+rbx*2]
    movzx r8d, byte [pal_base+rdx]
    movzx r9d, byte [pal_base+rdx+1]
    movzx r10d, byte [pal_base+rdx+2]
    cmp ebx, PAL_GLOW
    jl .tint
    cmp ebx, PAL_GLOW+8
    jl .glow
    cmp ebx, PAL_UI
    jge .notint
.tint:
    imul r8d, [tint_r]
    shr r8d, 8
    imul r9d, [tint_g]
    shr r9d, 8
    imul r10d, [tint_b]
    shr r10d, 8
    jmp .pack
.glow:
    mov eax, ebx
    sub eax, PAL_GLOW
    imul eax, 6
    lea r11, [glow_colors+rax]
%macro GLOWCH 2
    movzx eax, byte [r11+%2]
    imul eax, [tint_r+%2*4]
    shr eax, 8
    mov edi, eax
    movzx esi, byte [r11+%2+3]
    mov edx, [glow_amt]
    call lerp8
    mov %1, eax
%endmacro
    GLOWCH r8d, 0
    GLOWCH r9d, 1
    GLOWCH r10d, 2
    jmp .pack
.notint:
.pack:
    CLAMP r8d, 0, 255
    CLAMP r9d, 0, 255
    CLAMP r10d, 0, 255
    mov eax, r8d
    shl eax, 16
    shl r9d, 8
    or eax, r9d
    or eax, r10d
    or eax, 0xFF000000
    mov [lut_world+rbx*4], eax
    inc ebx
    cmp ebx, 256
    jl .l
    RETURN
