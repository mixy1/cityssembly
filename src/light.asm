; =====================================================================
;  LIGHT - sun shadows, cloud shadows and the true-colour light pass
;
;  Every sprite pixel carries the height of the voxel it shows, so the
;  world position of each screen pixel is known:
;      X - Y = wsx - ORIGIN_X        X + Y = 2 * (wsy + Z)
;  (X, Y, Z in voxels, 16 per tile edge; wsx/wsy world pixels).
;
;  Each frame the heights of everything near the view are stamped into
;  a world height map (2x2 voxels per cell), and one sweep toward the
;  sun turns it into a "shadow height" map: S[p] is the height below
;  which point p is in shadow.  Sweeping row by row away from the sun,
;      S[p] = max(H, S)[p + sun step] - drop per step
;  so any building, tree or pylon shades the ground, the streets and
;  the walls of its neighbours, and shadows stretch out at dawn and
;  dusk.  The light pass then shades each pixel by its shadow depth and
;  the drifting cloud cover, and adds sun glints on the water.
; =====================================================================

LS_W        equ 1024            ; cells per side (2 voxels each)
LS_SHIFT    equ 10
CLOUD_W     equ 512             ; cloud texels per side (4 voxels each)

section .bss
alignb 16
lhmap       resb LS_W*LS_W      ; object height per cell (voxels)
alignb 16
lsmap       resw LS_W*LS_W      ; shadow height per cell (8.8 voxels)
alignb 16
laomap      resb LS_W*LS_W      ; contact shade per cell (0..240)
alignb 16
; the two above, rotated 45 degrees so a row of pixels reads them in
; order: [(cx + cy) * 2048 + (cx - cy + 1023)] = shadow | contact << 16
luvmap      resd 2*LS_W*2*LS_W
alignb 16
cloudtex    resb CLOUD_W*CLOUD_W
alignb 16
litbuf      resd MAX_FB_W*MAX_FB_H
lit_dst     resq 1              ; where the lit frame goes (litbuf or the texture)
wavetex     resb 128*128        ; tiling ripple heights (1 texel = 1 voxel)
sin8        resb 256            ; sin, one period in 256 steps, -127..127
wdepth      resb MAP_TILES      ; water: distance to the shore, 32 per tile
wv_ph1      resd 1
wv_ph2      resd 1
hbuf        resb MAX_FB_W*MAX_FB_H
alignb 16
bl_a        resd (MAX_FB_W/4)*(MAX_FB_H/4)*3 + 16    ; bloom cells (b, g, r)
bl_b        resd (MAX_FB_W/4)*(MAX_FB_H/4)*3 + 16
bl_z        resb (MAX_FB_W/4)*(MAX_FB_H/4) + 16   ; 1: no glow near this cell
bl_w        resd 1
bl_h        resd 1
bl_gain     resd 1
sun_on      resd 1
sun_drop    resd 1              ; S drop per row step (8.8 voxels)
sun_f       resd 1              ; x shift per row step (8.8 cells, signed)
sun_str     resd 1              ; 0..256
sh_mul      resd 3              ; shadow colour multipliers (b, g, r) 0..256
lit_mul     resd 3              ; sunlight multipliers (b, g, r), 256 = 1
alignb 16
lut_shade   resd 33*256         ; lut_world shaded from full sun (0) to full shade (32)
lcache      resd MAX_FB_W/2*(TH_MAX+1)+16   ; per band: shade of each pixel pair on the row above
glint_n     resd 1              ; water glints per 1024 pixels
cloud_str   resd 1
cloud_ox    resd 1
cloud_oy    resd 1
lb_ok       resd 1              ; 1: lb_* hold the region shown
lb_x0       resd 1              ; region whose shadows are shown (cells)
lb_x1       resd 1
lb_y0       resd 1
lb_y1       resd 1
light_off   resd 1              ; 1 = flat lighting (settings)
light_force resd 1              ; 1 = sweep every frame (trailer)
lc_key      resd 6              ; view + sun of the last sweep
lc_tick     resd 1              ; anim_tick of the last sweep
ls_phase    resd 1              ; a sweep under way (see light_step), 0 none
ls_x0       resd 1              ; its region (cells)
ls_x1       resd 1
ls_y0       resd 1
ls_y1       resd 1
ls_ty       resd 1              ; next tile row to stamp
ls_row      resd 1              ; last cell row swept

section .data
; shadow colour at full strength: cool blue shade (b, g, r)
; water: shallow and deep colours (b, g, r), foam
wt_shallow  dd 186, 184, 70
wt_deep     dd 150, 82, 24
wt_foam     dd 250, 248, 238
sh_base     dd 206, 166, 150
sh_gold     dd 10, 36, 44           ; extra shade depth at golden hour
lit_noon    dd 2, 8, 10             ; sunlight boost (b, g, r) at noon
lit_gold    dd -46, 14, 74          ; and toward sunrise / sunset

section .text

; ---------------------------------------------------------------------
;  light_init: bake the cloud cover texture
; ---------------------------------------------------------------------
FUNC light_init
    ; sine table
    xor ebx, ebx
.s:
    cvtsi2ss xmm0, ebx
    mulss xmm0, [f_twopi]
    mulss xmm0, [f_inv256]
    call fast_sin
    mulss xmm0, [f_127]
    cvtss2si eax, xmm0
    mov [sin8+rbx], al
    inc ebx
    cmp ebx, 256
    jl .s
    ; ripples: three wave trains that tile every 128 texels
    xor r13d, r13d
.wy:
    xor r12d, r12d
.wx:
%macro WAVE 3                       ; kx, ky, amplitude/128
    mov eax, r12d
    imul eax, %1
    mov ecx, r13d
    imul ecx, %2
    add eax, ecx
    add eax, eax
    and eax, 255
    movsx eax, byte [sin8+rax]
    imul eax, %3
    sar eax, 7
    add ebx, eax
%endmacro
    mov ebx, 128
    WAVE 3, 1, 46
    WAVE -1, 4, 38
    WAVE 5, -3, 22
    WAVE 11, 6, 16
    WAVE -7, 13, 12
    CLAMP ebx, 0, 255
    mov eax, r13d
    shl eax, 7
    add eax, r12d
    mov [wavetex+rax], bl
    inc r12d
    cmp r12d, 128
    jl .wx
    inc r13d
    cmp r13d, 128
    jl .wy
    xor r13d, r13d
.y:
    xor r12d, r12d
.x:
    mov edi, r12d
    mov esi, r13d
    call cloud_val
    mov ecx, r13d
    shl ecx, 9
    add ecx, r12d
    mov [cloudtex+rcx], al
    inc r12d
    cmp r12d, CLOUD_W
    jl .x
    inc r13d
    cmp r13d, CLOUD_W
    jl .y
    RETURN

section .data
f_inv256    dd 0.00390625
f_127       dd 127.0
section .text

; water depth: chamfer distance (in 1/32 tiles, capped) from every water
; tile to the nearest land
FUNC water_depth
    xor ecx, ecx
.init:
    mov eax, ecx
    shl eax, TILE_SHIFT
    mov dl, 0
    cmp byte [tiles+rax+T_TERRAIN], TER_WATER
    jne .i
    mov dl, 255
.i:
    mov [wdepth+rcx], dl
    inc ecx
    cmp ecx, MAP_TILES
    jl .init
    ; forward pass (from up/left), then backward (from down/right)
    xor ecx, ecx
.f:
    movzx eax, byte [wdepth+rcx]
    test eax, eax
    jz .fn
    mov edx, ecx
    and edx, MAP_W-1
    jz .fu
    movzx ebx, byte [wdepth+rcx-1]
    add ebx, 32
    cmp ebx, eax
    cmovb eax, ebx
.fu:
    cmp ecx, MAP_W
    jb .fs
    movzx ebx, byte [wdepth+rcx-MAP_W]
    add ebx, 32
    cmp ebx, eax
    cmovb eax, ebx
.fs:
    mov [wdepth+rcx], al
.fn:
    inc ecx
    cmp ecx, MAP_TILES
    jl .f
    mov ecx, MAP_TILES-1
.b:
    movzx eax, byte [wdepth+rcx]
    test eax, eax
    jz .bn
    mov edx, ecx
    and edx, MAP_W-1
    cmp edx, MAP_W-1
    je .bd
    movzx ebx, byte [wdepth+rcx+1]
    add ebx, 32
    cmp ebx, eax
    cmovb eax, ebx
.bd:
    cmp ecx, MAP_TILES-MAP_W
    jae .bs
    movzx ebx, byte [wdepth+rcx+MAP_W]
    add ebx, 32
    cmp ebx, eax
    cmovb eax, ebx
.bs:
    mov [wdepth+rcx], al
.bn:
    dec ecx
    jns .b
    RETURN

; tileable value noise for the cloud texture (edi x, esi y) -> eax 0..255
; octaves of 64, 32, 16 and 8 texels, all dividing the 512 texel period
FUNC cloud_val, 16
    mov r12d, edi
    mov r13d, esi
    xor r14d, r14d                  ; sum
    mov r15d, 6                     ; log2 size
    mov dword [rbp-48], 128         ; amplitude
.oct:
    mov ecx, r15d
    mov eax, 1
    shl eax, cl
    dec eax
    mov ebx, eax                    ; size-1
    ; fractions (0..256) with smoothstep
    mov eax, r12d
    and eax, ebx
    shl eax, 8
    shr eax, cl
    mov edi, eax
    call .smooth
    mov [rbp-52], eax               ; sx
    mov eax, r13d
    and eax, ebx
    shl eax, 8
    shr eax, cl
    mov edi, eax
    call .smooth
    mov [rbp-56], eax               ; sy
    ; lattice cell and wrap mask
    mov eax, r12d
    shr eax, cl
    mov r8d, eax                    ; lx
    mov eax, r13d
    shr eax, cl
    mov r9d, eax                    ; ly
    mov eax, 512
    shr eax, cl
    dec eax
    mov r10d, eax                   ; cells-1
    ; four corners
    mov edi, r8d
    mov esi, r9d
    call .lat
    mov [rbp-60], eax
    lea edi, [r8+1]
    mov esi, r9d
    call .lat
    sub eax, [rbp-60]
    imul eax, [rbp-52]
    sar eax, 8
    add [rbp-60], eax               ; top
    mov edi, r8d
    lea esi, [r9+1]
    call .lat
    mov [rbp-64], eax
    lea edi, [r8+1]
    lea esi, [r9+1]
    call .lat
    sub eax, [rbp-64]
    imul eax, [rbp-52]
    sar eax, 8
    add eax, [rbp-64]               ; bottom
    sub eax, [rbp-60]
    imul eax, [rbp-56]
    sar eax, 8
    add eax, [rbp-60]
    imul eax, [rbp-48]
    shr eax, 8
    add r14d, eax
    shr dword [rbp-48], 1
    dec r15d
    cmp r15d, 3
    jge .oct
    ; 240 max -> 0..255
    mov eax, r14d
    imul eax, 272
    shr eax, 8
    CLAMP eax, 0, 255
    RETURN
.smooth:                            ; edi t 0..256 -> eax 3t^2 - 2t^3
    mov eax, edi
    imul eax, edi
    mov edx, 768
    sub edx, edi
    sub edx, edi
    imul eax, edx
    shr eax, 16
    ret
.lat:                               ; edi x, esi y (wrapped) -> eax 0..255
    and edi, r10d
    and esi, r10d
    imul esi, esi, 1031
    add edi, esi
    imul eax, r15d, 7919
    add edi, eax
    add edi, 0x5bd1e995
    push r8
    push r9
    push r10
    push r11
    call hash32
    pop r11
    pop r10
    pop r9
    pop r8
    and eax, 255
    ret

; ---------------------------------------------------------------------
;  light_sun: sun position and strength from the time of day
; ---------------------------------------------------------------------
FUNC light_sun
    mov dword [sun_on], 0
    cmp dword [light_off], 0
    jne .out
    mov eax, [tod]
    shr eax, 8
    cmp dword [tod_lock], 0
    je .t
    mov eax, 128
.t:
    ; p = (phase - 50) / 156 in 0..256
    sub eax, 50
    js .out
    shl eax, 8
    xor edx, edx
    mov ecx, 156
    div ecx
    cmp eax, 256
    jae .out
    mov r12d, eax                   ; p
    ; q = 4p(1-p): 0 at sunrise / sunset, 256 at noon
    mov ecx, 256
    sub ecx, eax
    imul eax, ecx
    shr eax, 6
    CLAMP eax, 0, 256
    mov r13d, eax
    ; strength fades in over the first light
    lea eax, [r13*4]
    CLAMP eax, 0, 256
    mov [sun_str], eax
    cmp eax, 8
    jl .out
    mov dword [sun_on], 1
    ; the sun stands to the left of the view (the side the models are
    ; lit from): shadows fall up-right in the morning, right at dusk
    mov eax, r12d
    imul eax, 166
    sar eax, 8
    add eax, 90
    mov [sun_f], eax
    ; height lost per row step: 2 voxels * slope, slope 0.28 .. 1.3
    mov eax, r13d
    imul eax, 261
    sar eax, 8
    add eax, 72                     ; slope in 8.8
    ; longer diagonal steps: * (1 + f^2/2)
    mov ecx, [sun_f]
    imul ecx, ecx
    shr ecx, 9
    add ecx, 256
    imul eax, ecx
    sar eax, 7                      ; *2 voxels per cell
    mov [sun_drop], eax
    ; golden hour: g = 256 - q, warm sunlight against cool shade
    mov r14d, 256
    sub r14d, r13d
    xor ebx, ebx
.c:
    ; shade: cool, deeper when the sun is low
    mov eax, 256
    sub eax, [sh_base+rbx*4]
    mov ecx, [sh_gold+rbx*4]
    imul ecx, r14d
    sar ecx, 8
    add eax, ecx
    imul eax, [sun_str]
    sar eax, 8
    mov ecx, 256
    sub ecx, eax
    mov [sh_mul+rbx*4], ecx
    ; sunlight
    mov eax, [lit_gold+rbx*4]
    imul eax, r14d
    sar eax, 8
    add eax, [lit_noon+rbx*4]
    imul eax, [sun_str]
    sar eax, 8
    add eax, 256
    mov [lit_mul+rbx*4], eax
    inc ebx
    cmp ebx, 3
    jl .c
    ; glints: more when the sun is low over the water
    mov eax, r14d
    shr eax, 4
    add eax, 3
    mov [glint_n], eax
    ; clouds drift slowly with the game clock (8.8 texels)
    mov eax, [anim_tick]
    imul eax, 5
    mov [cloud_ox], eax
    mov eax, [anim_tick]
    add eax, eax
    mov [cloud_oy], eax
    mov eax, [sun_str]
    mov [cloud_str], eax
.out:
    RETURN

; object sprite on a tile (rbx tile, edi x, esi y) -> eax id or -1
FUNC light_obj_sprite
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_TREE
    je .tree
    cmp eax, OBJ_POWER
    je .pylon
    cmp eax, OBJ_ZONEBLD
    je .zb
    cmp eax, OBJ_SERVICE
    je .svc
.none:
    mov eax, -1
    RETURN
.tree:
    movzx eax, byte [rbx+T_SUB]
    movzx ecx, byte [rbx+T_VARIANT]
    shr ecx, 3
    and ecx, 1
    lea eax, [rax*2+rcx]
    and eax, 7
    mov eax, [spr_tree+rax*4]
    RETURN
.pylon:
    mov eax, [spr_pylon]
    RETURN
.svc:
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .none
    movzx eax, byte [rbx+T_SUB]
    mov eax, [spr_bld+rax*4]
    RETURN
.zb:
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .none
    test byte [rbx+T_FLAGS], F_BUILD
    jz .grown
    mov eax, [spr_construct2]
    cmp byte [rbx+T_SIZE], 2
    je .o
    movzx eax, byte [rbx+T_TIMER]
    shr eax, 5
    CLAMP eax, 0, 2
    mov eax, [spr_construct+rax*4]
.o:
    RETURN
.grown:
    movzx edi, byte [rbx+T_ZONE]
    movzx esi, byte [rbx+T_LEVEL]
    CLAMP esi, 1, 5
    movzx edx, byte [rbx+T_VARIANT]
    movzx ecx, byte [rbx+T_SIZE]
    movzx r8d, byte [rbx+T_SUB]
    call zone_sprite
    RETURN

; ---------------------------------------------------------------------
;  light_prepare: height map + shadow sweep for the current view
; ---------------------------------------------------------------------
FUNC light_prepare, 48
    call light_sun
    cmp dword [sun_on], 0
    je .out
    ; the sweep is reused while the view and the sun stand still;
    ; growth and demolition show up within half a second (game ticks, not
    ; frames: at 240 Hz a frame count re-swept 8 times a second)
    xor ebx, ebx                    ; changed?
%macro LKEY 2
    mov eax, %2
    cmp eax, [lc_key+%1*4]
    je %%s
    mov [lc_key+%1*4], eax
    mov ebx, 1
%%s:
%endmacro
    mov ecx, [sun_drop]
    shr ecx, 2
    LKEY 4, ecx
    mov ecx, [sun_f]
    sar ecx, 2
    LKEY 5, ecx
    or ebx, [light_force]
    mov [rbp-64], ebx
    ; view bounds in voxels
    mov eax, [cam_x]
    sub eax, ORIGIN_X
    mov r8d, eax                    ; a0
    add eax, [fb_w]
    mov r9d, eax                    ; a1
    mov r10d, [cam_y]               ; b0
    mov r11d, r10d
    add r11d, [fb_h]
    add r11d, 255                   ; b1 + tallest
    ; X in [b0 + a0/2, b1 + a1/2], Y in [b0 - a1/2, b1 - a0/2]
    mov eax, r8d
    sar eax, 1
    add eax, r10d
    mov [rbp-48], eax               ; X0
    mov eax, r9d
    sar eax, 1
    add eax, r11d
    mov [rbp-52], eax               ; X1
    mov eax, r9d
    sar eax, 1
    mov ecx, r10d
    sub ecx, eax
    mov [rbp-56], ecx               ; Y0
    mov eax, r8d
    sar eax, 1
    mov ecx, r11d
    sub ecx, eax
    mov [rbp-60], ecx               ; Y1
    ; casters stand up to R voxels toward the sun (+Y), shifted in X
    ; R = 255 * 2 / drop (8.8)
    mov eax, 255*2*256
    xor edx, edx
    mov ecx, [sun_drop]
    CLAMP ecx, 16, 100000
    div ecx
    CLAMP eax, 0, 1200
    mov r12d, eax                   ; R voxels
    add [rbp-60], eax
    ; x drift = R/2 * f (cells) -> voxels
    mov eax, [sun_f]
    cdq
    xor eax, edx
    sub eax, edx
    imul eax, r12d
    sar eax, 8
    sub [rbp-48], eax
    add [rbp-52], eax
    ; to cells, clamped to the map
%macro LCELL 1
    mov eax, [rbp-%1]
    sar eax, 1
    CLAMP eax, 0, LS_W-1
    mov [rbp-%1], eax
%endmacro
    LCELL 48
    LCELL 52
    LCELL 56
    LCELL 60
    ; reuse the last sweep while the view stays inside it
    ; a sweep under way goes on a slice a frame, unless the view jumped
    ; off what's shown (then it starts over, all at once)
    cmp dword [ls_phase], 0
    je .idle
    call light_view_on
    test eax, eax
    jz .go
    xor edi, edi
    call light_step
    jmp .out
.idle:
    cmp dword [rbp-64], 0
    jne .go
    mov eax, [anim_tick]
    sub eax, [lc_tick]
    cmp eax, 30
    jae .go
    mov eax, [rbp-48]
    cmp eax, [lb_x0]
    jl .go
    mov eax, [rbp-52]
    cmp eax, [lb_x1]
    jg .go
    mov eax, [rbp-56]
    cmp eax, [lb_y0]
    jl .go
    mov eax, [rbp-60]
    cmp eax, [lb_y1]
    jg .go
    jmp .out
.go:
    mov eax, [anim_tick]
    mov [lc_tick], eax
    ; all at once when nothing valid is on screen (the first sweep, a jump)
    ; or the trailer wants every frame exact; else in slices over the next
    ; frames while the old shadows stay up
    call light_view_on
    xor eax, 1
    or eax, [light_force]
    mov [rbp-68], eax
    ; sweep a margin around the view so panning can reuse it
%macro LGROW 2
    mov eax, [rbp-%1]
    add eax, %2
    CLAMP eax, 0, LS_W-1
    mov [rbp-%1], eax
%endmacro
    cmp dword [light_force], 0
    jne .nogrow
    LGROW 48, -96
    LGROW 52, 96
    LGROW 56, -96
    LGROW 60, 96
.nogrow:
    mov eax, [rbp-48]
    mov [ls_x0], eax
    mov eax, [rbp-52]
    mov [ls_x1], eax
    mov eax, [rbp-56]
    mov [ls_y0], eax
    mov eax, [rbp-60]
    mov [ls_y1], eax
    mov dword [ls_phase], 1
    mov edi, [rbp-68]
    call light_step
.out:
    RETURN

; does the view (cells [rbp-48 .. rbp-60] of light_prepare) overlap the
; region whose shadows are shown? -> eax
light_view_on:
    xor eax, eax
    cmp dword [lb_ok], 0
    je .o
    mov ecx, [rbp-48]
    cmp ecx, [lb_x1]
    jg .o
    mov ecx, [rbp-52]
    cmp ecx, [lb_x0]
    jl .o
    mov ecx, [rbp-56]
    cmp ecx, [lb_y1]
    jg .o
    mov ecx, [rbp-60]
    cmp ecx, [lb_y0]
    jl .o
    inc eax
.o: ret

; ---------------------------------------------------------------------
;  one slice of a sweep (edi 1: to the end now).  The phases: clear the
;  heights, stamp every object's column heights (a few tile rows a
;  slice), sweep toward the sun (a band of rows a slice), then contact
;  shade and the rotated layout on every core, and show the result.
; ---------------------------------------------------------------------
STAMP_ROWS  equ 16              ; tile rows stamped per slice
SWEEP_ROWS  equ 160             ; cell rows swept per slice

FUNC light_step, 48
    mov [rbp-48], edi
.again:
    mov eax, [ls_phase]
    cmp eax, 1
    je .clear
    cmp eax, 2
    je .stamp
    cmp eax, 3
    je .sweep
    cmp eax, 4
    je .finish
    RETURN
.clear:
    ; ---- clear the height map in the region ----
    mov r13d, [ls_y0]
.cy:
    cmp r13d, [ls_y1]
    jg .cyd
    mov edi, r13d
    shl edi, LS_SHIFT
    add edi, [ls_x0]
    lea rdi, [lhmap+rdi]
    mov ecx, [ls_x1]
    sub ecx, [ls_x0]
    inc ecx
    xor eax, eax
    rep stosb
    inc r13d
    jmp .cy
.cyd:
    ; tiles: cells >> 3, anchors up to 3 tiles back
    mov eax, [ls_y0]
    shr eax, 3
    sub eax, 3
    CLAMP eax, 0, MAP_W-1
    mov [ls_ty], eax
    mov dword [ls_phase], 2
    jmp .next
.stamp:
    ; ---- stamp every object's column heights ----
    mov r13d, [ls_ty]               ; ty
    lea eax, [r13+STAMP_ROWS]
    mov [rbp-52], eax               ; this slice ends here
.ty:
    mov eax, [ls_y1]
    shr eax, 3
    cmp r13d, eax
    jg .stampd
    cmp dword [rbp-48], 0
    jne .tyall
    cmp r13d, [rbp-52]
    jge .stamps
.tyall:
    mov eax, [ls_x0]
    shr eax, 3
    sub eax, 3
    CLAMP eax, 0, MAP_W-1
    mov r12d, eax                   ; tx
.tx:
    mov eax, [ls_x1]
    shr eax, 3
    cmp r12d, eax
    jg .tyn
    mov eax, r13d
    shl eax, MAP_SHIFT
    add eax, r12d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    mov edi, r12d
    mov esi, r13d
    call light_obj_sprite
    cmp eax, -1
    je .txn
    ; heightmap: [gx, gy, heights]
    shl eax, 4
    mov eax, [spr_table+rax+12]
    lea r14, [arena+rax]
    movzx r15d, byte [r14]          ; gx
    movzx eax, byte [r14+1]
    mov [rbp-64], eax               ; gy
    add r14, 2
    xor ebx, ebx                    ; iy
.hy:
    cmp ebx, [rbp-64]
    jge .txn
    ; cell row
    mov eax, r13d
    shl eax, 4
    add eax, ebx
    shr eax, 1
    cmp eax, LS_W
    jae .txn
    shl eax, LS_SHIFT
    mov [rbp-68], eax
    xor ecx, ecx                    ; ix
.hx:
    cmp ecx, r15d
    jge .hyn
    movzx edx, byte [r14+rcx]
    test edx, edx
    jz .hxn
    mov eax, r12d
    shl eax, 4
    add eax, ecx
    shr eax, 1
    cmp eax, LS_W
    jae .hxn
    add eax, [rbp-68]
    cmp dl, [lhmap+rax]
    jbe .hxn
    mov [lhmap+rax], dl
.hxn:
    inc ecx
    jmp .hx
.hyn:
    add r14, r15
    inc ebx
    jmp .hy
.txn:
    inc r12d
    cmp r12d, MAP_W
    jl .tx
.tyn:
    inc r13d
    cmp r13d, MAP_W
    jl .ty
.stampd:
    ; the sweep's first row: nothing beyond it
    mov edi, [ls_y1]
    shl edi, LS_SHIFT
    add edi, [ls_x0]
    lea rdi, [lsmap+rdi*2]
    mov ecx, [ls_x1]
    sub ecx, [ls_x0]
    inc ecx
    xor eax, eax
    rep stosw
    mov eax, [ls_y1]
    mov [ls_row], eax
    mov dword [ls_phase], 3
    jmp .next
.stamps:
    mov [ls_ty], r13d
    jmp .next
.sweep:
    ; ---- sweep from the sun side (high Y) down ----
    mov r13d, [ls_row]              ; the last row done
    lea eax, [r13-SWEEP_ROWS]
    mov [rbp-52], eax
    mov r8d, [ls_x0]
    mov r9d, [ls_x1]
    mov r10d, [sun_f]
    mov r11d, [sun_drop]
.row:
    dec r13d
    cmp r13d, [ls_y0]
    jl .swd
    cmp dword [rbp-48], 0
    jne .rowall
    cmp r13d, [rbp-52]
    jl .sws
.rowall:
    mov eax, r13d
    inc eax
    shl eax, LS_SHIFT
    mov r14d, eax                   ; previous row base
    mov eax, r13d
    shl eax, LS_SHIFT
    mov r15d, eax                   ; this row base
    mov ebx, r8d                    ; x
.col:
    cmp ebx, r9d
    jg .row
    ; source x = x - f (8.8)
    mov eax, ebx
    shl eax, 8
    sub eax, r10d
    mov ecx, eax
    sar ecx, 8                      ; i
    and eax, 255                    ; w
    CLAMP ecx, r8d, r9d
    lea edx, [rcx+1]
    cmp edx, r9d
    jle .i1
    mov edx, r9d
.i1:
    ; M(i) = max(H*256, S) on the previous row
    lea esi, [r14+rcx]
    movzx edi, byte [lhmap+rsi]
    shl edi, 8
    movzx esi, word [lsmap+rsi*2]
    cmp esi, edi
    cmovb esi, edi
    mov r12d, esi
    lea esi, [r14+rdx]
    movzx edi, byte [lhmap+rsi]
    shl edi, 8
    movzx esi, word [lsmap+rsi*2]
    cmp esi, edi
    cmovb esi, edi
    mov edi, r12d                   ; M(i) in edi, M(i+1) in esi
    ; lerp
    sub esi, edi
    imul esi, eax
    sar esi, 8
    add esi, edi
    sub esi, r11d
    jns .pos
    xor esi, esi
.pos:
    lea eax, [r15+rbx]
    mov [lsmap+rax*2], si
    inc ebx
    jmp .col
.sws:
    inc r13d
    mov [ls_row], r13d
    jmp .next
.swd:
    mov dword [ls_phase], 4
    jmp .next
.finish:
    ; ---- contact shade, then the rotated layout: rows are independent,
    ; so every core takes a band ----
    lea rdi, [light_ao_rows]
    mov esi, [ls_y1]
    sub esi, [ls_y0]
    dec esi                         ; rows ls_y0+1 .. ls_y1-1
    CLAMP esi, 0, LS_W
    mov edx, 1
    call par_rows
    lea rdi, [light_rot_rows]
    mov esi, [ls_y1]
    sub esi, [ls_y0]
    inc esi                         ; rows ls_y0 .. ls_y1
    CLAMP esi, 0, LS_W
    mov edx, 1
    call par_rows
    ; and show it
    mov eax, [ls_x0]
    mov [lb_x0], eax
    mov eax, [ls_x1]
    mov [lb_x1], eax
    mov eax, [ls_y0]
    mov [lb_y0], eax
    mov eax, [ls_y1]
    mov [lb_y1], eax
    mov dword [lb_ok], 1
    mov dword [ls_phase], 0
    RETURN
.next:
    cmp dword [rbp-48], 0
    jne .again
    RETURN

; contact shade for sweep rows [ls_y0+1 + edi, ls_y0+1 + esi): ground
; cells next to taller things
FUNC light_ao_rows
    mov r13d, edi
    add r13d, [ls_y0]
    inc r13d
    mov r14d, esi
    add r14d, [ls_y0]
    inc r14d
    mov eax, [ls_y1]
    dec eax
    cmp r14d, eax
    jle .ay
    mov r14d, eax
.ay:
    cmp r13d, r14d
    jge .out
    mov ebx, [ls_x0]
    inc ebx
.axx:
    mov eax, [ls_x1]
    dec eax
    cmp ebx, eax
    jge .ayn
    mov ecx, r13d
    shl ecx, LS_SHIFT
    add ecx, ebx
    xor edx, edx
    movzx r11d, byte [lhmap+rcx]
    cmp r11d, 3
    ja .aost
    add r11d, 5
%macro AOTAP 1
    movzx eax, byte [lhmap+rcx+(%1)]
    cmp eax, r11d
    jbe %%n
    add edx, 30
%%n:
%endmacro
    AOTAP 1
    AOTAP -1
    AOTAP LS_W
    AOTAP -LS_W
    AOTAP LS_W+1
    AOTAP LS_W-1
    AOTAP -LS_W+1
    AOTAP -LS_W-1
.aost:
    mov [laomap+rcx], dl
    inc ebx
    jmp .axx
.ayn:
    inc r13d
    jmp .ay
.out:
    RETURN

; the shadow and contact maps of rows [ls_y0 + edi, ls_y0 + esi), rotated
; into the layout the light pass reads
FUNC light_rot_rows
    mov r13d, edi
    add r13d, [ls_y0]
    mov r14d, esi
    add r14d, [ls_y0]
    mov eax, [ls_y1]
    inc eax
    cmp r14d, eax
    jle .ry
    mov r14d, eax
.ry:
    cmp r13d, r14d
    jge .out
    mov ebx, [ls_x0]
.rx:
    cmp ebx, [ls_x1]
    jg .ryn
    mov ecx, r13d
    shl ecx, LS_SHIFT
    add ecx, ebx
    movzx eax, word [lsmap+rcx*2]
    movzx edx, byte [laomap+rcx]
    shl edx, 16
    or eax, edx
    lea edx, [rbx+r13]
    shl edx, 11
    add edx, ebx
    sub edx, r13d
    add edx, LS_W-1
    mov [luvmap+rdx*4], eax
    inc ebx
    jmp .rx
.ryn:
    inc r13d
    jmp .ry
.out:
    RETURN

; ---------------------------------------------------------------------
;  light_compose: fb (palette indices) -> litbuf (argb) with lighting
; ---------------------------------------------------------------------
FUNC light_compose
    call water_depth
    mov eax, [anim_tick]
    mov ecx, eax
    shr eax, 2
    mov [wv_ph1], eax
    imul ecx, 3
    shr ecx, 4
    mov [wv_ph2], ecx
    call light_prepare
    PERF_MARK 13
    cmp dword [sun_on], 0
    je .nolut
    call light_lut
.nolut:
    PERF_MARK 14
    lea rdi, [light_rows]
    mov esi, [fb_h]
    mov edx, 2                      ; bands start on even rows (2x2 blocks)
    call par_rows
    PERF_MARK 15
    call light_bloom
    PERF_MARK 16
    RETURN

; lut_shade[k][i] = lut_world[i] * lerp(sunlight, shade, k/32)
FUNC light_lut, 16
    xor r12d, r12d                  ; level
.k:
    ; per-channel multipliers for this level
    xor ebx, ebx
.m:
    mov eax, [sh_mul+rbx*4]
    sub eax, [lit_mul+rbx*4]
    imul eax, r12d
    sar eax, 5
    add eax, [lit_mul+rbx*4]
    mov [rbp-48+rbx*4-8], eax       ; rbp-56, -52, -48
    inc ebx
    cmp ebx, 3
    jl .m
    xor r13d, r13d                  ; palette index
.i:
    mov ebx, [lut_world+r13*4]
    cmp r13d, RAMP_BASE
    jb .put
    cmp r13d, PAL_GLOW
    jae .put
    xor edi, edi
%macro LCH 2
    mov eax, ebx
    shr eax, %1
    and eax, 255
    imul eax, [rbp-56+%2*4]
    shr eax, 8
    cmp eax, 255
    jbe %%ok
    mov eax, 255
%%ok:
    shl eax, %1
    or edi, eax
%endmacro
    LCH 0, 0
    LCH 8, 1
    LCH 16, 2
    or edi, 0xFF000000
    mov ebx, edi
.put:
    mov eax, r12d
    shl eax, 8
    add eax, r13d
    mov [lut_shade+rax*4], ebx
    inc r13d
    cmp r13d, 256
    jl .i
    inc r12d
    cmp r12d, 33
    jl .k
    RETURN

; the light pass for rows [edi, esi) (runs on worker threads)
FUNC light_rows, 96
    mov r13d, edi                   ; y
    mov [rbp-72], esi               ; end
    ; this band's row cache: bands start at different rows; pick a slot
    ; by the band's start (y0 * workers / rows), clamped
    mov eax, edi
    xor edx, edx
    mov ecx, [th_band]
    CLAMP ecx, 1, 100000
    div ecx
    CLAMP eax, 0, TH_MAX            ; workers + the calling thread
    imul eax, eax, MAX_FB_W/2*4
    lea rcx, [lcache+rax]
    mov [rbp-88], rcx
    mov eax, edi
    imul eax, [fb_w]
    lea r12, [fb+rax]
    mov r15, [lit_dst]
    lea r15, [r15+rax*4]
.y:
    cmp r13d, [rbp-72]
    jge .out
    mov eax, r13d
    add eax, [cam_y]
    mov [rbp-48], eax               ; wsy
    mov eax, [cam_x]
    sub eax, ORIGIN_X
    mov [rbp-52], eax               ; a at x = 0
    xor r14d, r14d                  ; x
.x:
    cmp r14d, [fb_w]
    jge .yn
    test r14d, 1
    jnz .odd
    mov dword [rbp-80], -1          ; nothing to share yet
    ; odd rows: the pair above may share its shade too
    test r13d, 1
    jnz .above
    mov eax, r14d
    shr eax, 1
    mov rcx, [rbp-88]
    mov dword [rcx+rax*4], 0xFF     ; until this pair works one out
    jmp .odd
.above:
    mov eax, r14d
    shr eax, 1
    mov rcx, [rbp-88]
    mov eax, [rcx+rax*4]
    movzx ecx, al
    mov [rbp-80], ecx               ; Z above
    shr eax, 8
    mov [rbp-76], eax               ; its shade
.odd:
    movzx eax, byte [r12]
    mov ebx, [lut_world+rax*4]
    mov dword [rbp-96], 0           ; not water
    mov ecx, eax
    sub ecx, PAL_WATER
    cmp ecx, 8
    jb .water
.wback:
    cmp dword [sun_on], 0
    je .st
    cmp eax, RAMP_BASE
    jb .st
    cmp eax, PAL_GLOW
    jae .st
    movzx esi, byte [r12+(hbuf-fb)]         ; Z
    ; pixels of a 2x2 block at the same height share one shade (they're
    ; at most a pixel apart in the world); the block's first pixel works
    ; it out
    cmp esi, [rbp-80]
    jne .full
    mov r10d, [rbp-76]
    jmp .lookup
.full:
    mov [rbp-80], esi
    ; world position of the pixel (in half voxels)
    mov ecx, [rbp-48]
    add ecx, esi
    add ecx, ecx                    ; X + Y
    mov edx, [rbp-52]
    add edx, r14d                   ; X - Y
    lea edi, [rcx+rdx]              ; 2X
    sub ecx, edx                    ; 2Y
    mov r8d, edi
    mov r9d, ecx
    sar edi, 2                      ; cell x
    sar ecx, 2                      ; cell y
    xor r10d, r10d                  ; shade 0..256
    cmp edi, [lb_x0]
    jl .cloud
    cmp edi, [lb_x1]
    jg .cloud
    cmp ecx, [lb_y0]
    jl .cloud
    cmp ecx, [lb_y1]
    jge .cloud
    lea eax, [rdi+rcx]
    shl eax, 11
    add eax, edi
    sub eax, ecx
    add eax, LS_W-1
    mov eax, [luvmap+rax*4]
    mov [rbp-92], eax
    movzx edx, ax
    mov r11d, esi
    shl r11d, 8
    add r11d, 384                   ; bias: 1.5 voxels
    sub edx, r11d
    jle .ao
    shl edx, 1                      ; a short soft edge
    CLAMP edx, 0, 256
    mov r10d, edx
.ao:
    ; contact shade (ground only; walls keep their own shading)
    cmp esi, 3
    ja .cloud
    movzx edx, byte [rbp-90]
    cmp edx, r10d
    jbe .cloud
    mov r10d, edx
.cloud:
    ; cloud cover: texel = 4 voxels
    mov [rbp-56], r8d
    mov [rbp-60], r9d
    ; texel = 8 half voxels; the offset is in 8.8 texels
    shl r8d, 5
    add r8d, [cloud_ox]
    sar r8d, 8
    and r8d, CLOUD_W-1
    shl r9d, 5
    add r9d, [cloud_oy]
    sar r9d, 8
    and r9d, CLOUD_W-1
    shl r9d, 9
    movzx eax, byte [cloudtex+r9+r8]
    xor r9d, r9d
    lea edx, [rax+r9]
    sub edx, 136
    jle .apply
    imul edx, 5
    CLAMP edx, 0, 256
    imul edx, [cloud_str]
    shr edx, 8
    ; clouds and sun shadow don't stack: take the deeper
    lea edx, [rdx+rdx*2]
    shr edx, 2
    cmp edx, r10d
    jbe .apply
    mov r10d, edx
.apply:
    mov [rbp-76], r10d
    ; remember it for the row below
    test r13d, 1
    jnz .nc
    mov eax, r14d
    shr eax, 1
    mov rcx, [rbp-88]
    mov edx, r10d
    shl edx, 8
    or edx, [rbp-80]
    mov [rcx+rax*4], edx
.nc:
    ; the palette pre-shaded at 33 levels (built once per frame)
    movzx eax, byte [r12]
    mov [rbp-64], eax
    cmp dword [rbp-96], 0
    jne .wshade
    lea ecx, [r10+4]
    shr ecx, 3                      ; level 0..32
    shl ecx, 8
    add ecx, eax
    mov ebx, [lut_shade+rcx*4]
.glint:
    ; sun glints on open water
    mov eax, [rbp-64]
    sub eax, PAL_WATER
    cmp eax, 8
    jae .st
    cmp r10d, 64
    jae .st
    mov eax, [rbp-56]
    sar eax, 1
    imul eax, 73856093
    mov ecx, [rbp-60]
    imul ecx, 19349663
    xor eax, ecx
    mov ecx, [anim_tick]
    shr ecx, 3
    imul ecx, 83492791
    xor eax, ecx
    ; mix, or the glints line up in rows
    mov ecx, eax
    shr ecx, 13
    xor eax, ecx
    imul eax, eax, 0x5bd1e995
    mov ecx, eax
    shr ecx, 15
    xor eax, ecx
    shr eax, 22
    cmp eax, [glint_n]
    jae .st
    mov ebx, 0xFFFFF4DC
    jmp .st
.lookup:
    cmp dword [rbp-96], 0
    jne .wshade2
    movzx eax, byte [r12]
    lea ecx, [r10+4]
    shr ecx, 3
    shl ecx, 8
    add ecx, eax
    mov ebx, [lut_shade+rcx*4]
    jmp .st
.wshade2:
    call .wmul
    jmp .st
.wshade:
    call .wmul
    jmp .glint
    ; water colour [rbp-100] * lerp(sunlight, shade, r10) -> ebx
.wmul:
    mov ebx, [rbp-100]
    xor edi, edi
%macro WSH 2
    mov ecx, [sh_mul+%2*4]
    sub ecx, [lit_mul+%2*4]
    imul ecx, r10d
    sar ecx, 8
    add ecx, [lit_mul+%2*4]
    mov eax, ebx
    shr eax, %1
    and eax, 255
    imul eax, ecx
    shr eax, 8
    cmp eax, 255
    jbe %%ok
    mov eax, 255
%%ok:
    shl eax, %1
    or edi, eax
%endmacro
    WSH 0, 0
    WSH 8, 1
    WSH 16, 2
    or edi, 0xFF000000
    mov ebx, edi
    ret

    ; ---- water: depth colour, moving ripples, shore foam ----
.water:
    movzx esi, byte [r12+(hbuf-fb)]
    mov ecx, [rbp-48]
    add ecx, esi
    add ecx, ecx                    ; X + Y (voxels)
    mov edx, [rbp-52]
    add edx, r14d                   ; X - Y
    lea edi, [rcx+rdx]              ; 2X
    sub ecx, edx                    ; 2Y
    sar edi, 1                      ; X
    sar ecx, 1                      ; Y
    mov [rbp-104], edi
    mov [rbp-108], ecx
    ; depth: bilinear between tile centres (tile = 16 voxels)
    sub edi, 8
    sub ecx, 8
    mov eax, edi
    sar eax, 4
    mov edx, ecx
    sar edx, 4
    CLAMP eax, 0, MAP_W-2
    CLAMP edx, 0, MAP_W-2
    shl edx, MAP_SHIFT
    add edx, eax
    movzx eax, byte [wdepth+rdx]
    movzx r8d, byte [wdepth+rdx+1]
    movzx r9d, byte [wdepth+rdx+MAP_W]
    movzx r11d, byte [wdepth+rdx+MAP_W+1]
    and edi, 15
    and ecx, 15
    sub r8d, eax
    imul r8d, edi
    sar r8d, 4
    add eax, r8d                    ; top
    sub r11d, r9d
    imul r11d, edi
    sar r11d, 4
    add r9d, r11d                   ; bottom
    sub r9d, eax
    imul r9d, ecx
    sar r9d, 4
    add eax, r9d                    ; depth, 32 per tile
    mov [rbp-112], eax
    ; ripples: two layers drifting across each other
    mov edi, [rbp-104]
    mov ecx, [rbp-108]
    mov eax, edi
    add eax, [wv_ph1]
    and eax, 127
    mov edx, ecx
    add edx, [wv_ph1]
    shr edx, 0
    and edx, 127
    shl edx, 7
    movzx r8d, byte [wavetex+rdx+rax]      ; layer 1
    mov eax, ecx
    sub eax, [wv_ph2]
    and eax, 127
    mov edx, edi
    shl edx, 1
    sub edx, [wv_ph2]
    and edx, 127
    shl eax, 7
    movzx r9d, byte [wavetex+rax+rdx]      ; layer 2
    lea r11d, [r8+r9]
    shr r11d, 1                     ; 0..255, 128 calm
    ; ripple light in four steps (pixel art bands)
    mov esi, r11d
    shr esi, 6                      ; 0..3
    imul esi, 26
    add esi, 218                    ; 0.85 .. 1.16
    ; depth mix 0 (shore) .. 256 (four tiles out), in eight bands
    mov ecx, [rbp-112]
    shl ecx, 1
    ; the ripples wobble the band edges into natural contours
    lea eax, [r8-128]
    sar eax, 2
    add ecx, eax
    CLAMP ecx, 0, 256
    and ecx, ~31
    xor edi, edi
%macro WCOL 2
    mov eax, [wt_deep+%2*4]
    sub eax, [wt_shallow+%2*4]
    imul eax, ecx
    sar eax, 8
    add eax, [wt_shallow+%2*4]
    ; ripple light 0.84 .. 1.16
    imul eax, esi
    shr eax, 8
    ; time of day
    imul eax, [tint_r+(2-%2)*4]
    shr eax, 8
    CLAMP eax, 0, 255
    shl eax, %1
    or edi, eax
%endmacro
    WCOL 0, 0
    WCOL 8, 1
    WCOL 16, 2
    ; the crests catch the light
    cmp r11d, 184
    jb .wnc
    mov edx, r11d
    sub edx, 184
    imul edx, 3                     ; up to ~210
    CLAMP edx, 0, 150
%macro WLIFT 1
    mov eax, edi
    shr eax, %1
    and eax, 255
    mov ecx, 255
    sub ecx, eax
    imul ecx, edx
    shr ecx, 8
    add eax, ecx
    mov ecx, 255
    shl ecx, %1
    not ecx
    and edi, ecx
    shl eax, %1
    or edi, eax
%endmacro
    WLIFT 0
    WLIFT 8
    WLIFT 16
.wnc:
    ; foam in the shallows, riding the ripple crests
    mov eax, [rbp-112]
    cmp eax, 26
    jge .wnf
    ; a steady line at the water's edge, then crests lapping in
    mov edx, 10
    sub edx, eax
    imul edx, 26                    ; edge foam
    CLAMP edx, 0, 230
    mov ecx, r8d
    sub ecx, 120
    jle .wf1
    mov eax, 26
    sub eax, [rbp-112]
    imul ecx, eax
    shr ecx, 3                      ; lapping foam
    cmp ecx, edx
    jbe .wf1
    mov edx, ecx
.wf1:
    CLAMP edx, 0, 230
    test edx, edx
    jz .wnf
    ; mix toward foam (tinted)
%macro WFOAM 2
    mov eax, edi
    shr eax, %1
    and eax, 255
    mov ecx, [wt_foam+%2*4]
    imul ecx, [tint_r+(2-%2)*4]
    shr ecx, 8
    sub ecx, eax
    imul ecx, edx
    sar ecx, 8
    add eax, ecx
    CLAMP eax, 0, 255
    mov ecx, 255
    shl ecx, %1
    not ecx
    and edi, ecx
    shl eax, %1
    or edi, eax
%endmacro
    WFOAM 0, 0
    WFOAM 8, 1
    WFOAM 16, 2
.wnf:
    or edi, 0xFF000000
    mov [rbp-100], edi
    mov ebx, edi
    mov dword [rbp-96], 1
    jmp .wback
.st:
    ; info views colour the picture here too (on the worker threads)
    cmp dword [eff_overlay], 0
    je .w
    movzx ecx, byte [r12+(tintbuf-fb)]
    call tint_px
.w:
    mov [r15], ebx
    inc r12
    add r15, 4
    inc r14d
    jmp .x
.yn:
    inc r13d
    jmp .y
.out:
    RETURN

; ---------------------------------------------------------------------
;  light_bloom: at night, lit windows, lamps and neon glow and spill
;  light on the streets around them.  Glow pixels are summed into
;  4x4 cells, blurred, and added back with bilinear filtering.
; ---------------------------------------------------------------------
FUNC light_bloom, 48
    cmp dword [light_off], 0
    jne .out
    mov eax, [glow_amt]
    cmp eax, 24
    jl .out
    mov [bl_gain], eax
    mov eax, [fb_w]
    add eax, 3
    shr eax, 2
    mov [bl_w], eax
    mov ecx, [fb_h]
    add ecx, 3
    shr ecx, 2
    mov [bl_h], ecx
    imul eax, ecx
    lea ecx, [rax+rax*2]
    lea rdi, [bl_a]
    xor eax, eax
    rep stosd
    ; ---- gather (rows in multiples of 4: each thread owns its cells) ----
    lea rdi, [bloom_gather_rows]
    mov esi, [fb_h]
    mov edx, 4
    call par_rows
.blur:
    ; two box passes each way: bl_a -> bl_b (h), bl_b -> bl_a (v)
    mov ebx, 2
.bp:
    lea rdi, [blur_h_rows]
    mov esi, [bl_h]
    mov edx, 1
    call par_rows
    lea rdi, [blur_v_cols]
    mov esi, [bl_w]
    lea esi, [rsi+rsi*2]
    mov edx, 1
    call par_rows
    dec ebx
    jnz .bp
    ; ---- cells with no glow around them are skipped ----
    mov eax, [bl_w]
    imul eax, [bl_h]
    mov r8d, eax
    xor ecx, ecx
    mov r9d, [bl_w]
    lea r9d, [r9+r9*2]              ; row stride (dwords)
.zf:
    cmp ecx, r8d
    jge .zd
    lea rax, [rcx+rcx*2]
    lea rsi, [bl_a+rax*4]
    mov eax, [rsi]
    or eax, [rsi+4]
    or eax, [rsi+8]
    or eax, [rsi+12]
    or eax, [rsi+16]
    or eax, [rsi+20]
    lea rdi, [rsi+r9*4]
    mov edx, ecx
    add edx, [bl_w]
    cmp edx, r8d
    jae .zo
    or eax, [rdi]
    or eax, [rdi+4]
    or eax, [rdi+8]
    or eax, [rdi+12]
    or eax, [rdi+16]
    or eax, [rdi+20]
.zo:
    test eax, eax
    setz byte [bl_z+rcx]
    inc ecx
    jmp .zf
.zd:
    ; ---- add back, bilinear ----
    lea rdi, [bloom_add_rows]
    mov esi, [fb_h]
    mov edx, 1
    call par_rows
.out:
    RETURN

; horizontal box blur, radius 2 (rsi src, rdi dst, ecx w, r8d h)
bloom_box:
    push rbx
    push r12
    push r13
    mov r9d, r8d                    ; rows
.r:
    xor r10d, r10d                  ; x
.x:
    xor r11d, r11d
.ch:
    xor eax, eax
    mov r12d, -2
.k:
    lea r13d, [r10+r12]
    cmp r13d, 0
    jl .kn
    cmp r13d, ecx
    jge .kn
    lea r13, [r13+r13*2]
    add r13, r11
    add eax, [rsi+r13*4]
.kn:
    inc r12d
    cmp r12d, 2
    jle .k
    imul eax, eax, 205              ; / 5
    shr eax, 10
    lea r13, [r10+r10*2]
    add r13, r11
    mov [rdi+r13*4], eax
    inc r11d
    cmp r11d, 3
    jl .ch
    inc r10d
    cmp r10d, ecx
    jl .x
    lea rax, [rcx+rcx*2]
    lea rsi, [rsi+rax*4]
    lea rdi, [rdi+rax*4]
    dec r9d
    jnz .r
    pop r13
    pop r12
    pop rbx
    ret

; vertical box blur, radius 2 (rsi src, rdi dst, edx row stride dwords,
; ecx h, r8d first column, r9d end column, in dwords)
bloom_box_v:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r14d, edx
    mov r15d, r9d
    mov r9d, r8d                    ; column
.c:
    xor r10d, r10d                  ; y
.y:
    xor eax, eax
    mov r12d, -2
.k:
    lea r13d, [r10+r12]
    cmp r13d, 0
    jl .kn
    cmp r13d, ecx
    jge .kn
    imul r13d, r14d
    add r13d, r9d
    add eax, [rsi+r13*4]
.kn:
    inc r12d
    cmp r12d, 2
    jle .k
    imul eax, eax, 205              ; / 5
    shr eax, 10
    mov r13d, r10d
    imul r13d, r14d
    add r13d, r9d
    mov [rdi+r13*4], eax
    inc r10d
    cmp r10d, ecx
    jl .y
    inc r9d
    cmp r9d, r15d
    jl .c
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; blur jobs: horizontal over cell rows, vertical over dword columns
FUNC blur_h_rows
    mov r12d, edi
    mov r13d, esi
    mov eax, [bl_w]
    lea eax, [rax+rax*2]
    imul eax, r12d                  ; first dword
    lea rsi, [bl_a+rax*4]
    lea rdi, [bl_b+rax*4]
    mov ecx, [bl_w]
    mov r8d, r13d
    sub r8d, r12d
    jle .o
    call bloom_box
.o:
    RETURN

FUNC blur_v_cols
    cmp edi, esi
    jge .o
    mov r8d, edi
    mov r9d, esi
    lea rsi, [bl_b]
    lea rdi, [bl_a]
    mov edx, [bl_w]
    lea edx, [rdx+rdx*2]
    mov ecx, [bl_h]
    call bloom_box_v
.o:
    RETURN

; bloom: sum glow pixels of rows [edi, esi) into their cells
FUNC bloom_gather_rows, 16
    mov r13d, edi
    mov [rbp-52], esi
    mov eax, edi
    imul eax, [fb_w]
    lea r12, [fb+rax]
    mov r15, [lit_dst]
    lea r15, [r15+rax*4]
.gy:
    cmp r13d, [rbp-52]
    jge .out
    mov eax, r13d
    shr eax, 2
    imul eax, [bl_w]
    mov [rbp-48], eax               ; cell row base
    xor r14d, r14d
.gx:
    cmp r14d, [fb_w]
    jge .gyn
    movzx eax, byte [r12]
    sub eax, PAL_GLOW
    cmp eax, 8
    jae .gn
    mov eax, r14d
    shr eax, 2
    add eax, [rbp-48]
    lea rax, [rax+rax*2]
    lea rdi, [bl_a+rax*4]
    mov ebx, [r15]
    movzx ecx, bl
    add [rdi], ecx
    movzx ecx, bh
    add [rdi+4], ecx
    shr ebx, 16
    movzx ecx, bl
    add [rdi+8], ecx
.gn:
    inc r12
    add r15, 4
    inc r14d
    jmp .gx
.gyn:
    inc r13d
    jmp .gy
.out:
    RETURN

; bloom: add the blurred glow to rows [edi, esi)
FUNC bloom_add_rows, 64
    mov r13d, edi
    mov [rbp-60], esi
    mov eax, edi
    imul eax, [fb_w]
    mov r15, [lit_dst]
    lea r15, [r15+rax*4]
.ay:
    cmp r13d, [rbp-60]
    jge .out
    ; v = y/4 - 3/8 in 8.8
    mov eax, r13d
    shl eax, 6
    sub eax, 96
    jns .vy
    xor eax, eax
.vy:
    mov ecx, eax
    shr ecx, 8
    and eax, 255
    mov [rbp-52], eax               ; wy
    mov eax, [bl_h]
    sub eax, 2
    CLAMP ecx, 0, eax
    imul ecx, [bl_w]
    mov [rbp-56], ecx               ; row0 base (cells)
    xor r14d, r14d
.ax:
    cmp r14d, [fb_w]
    jge .ayn
    ; the glow is worked out once per pixel pair
    test r14d, 1
    jnz .apply
    mov dword [rbp-76], 0           ; nothing to add
    mov eax, r14d
    shl eax, 6
    sub eax, 96
    jns .vx
    xor eax, eax
.vx:
    mov ecx, eax
    shr ecx, 8
    and eax, 255
    mov r12d, eax                   ; wx
    mov eax, [bl_w]
    sub eax, 2
    CLAMP ecx, 0, eax
    add ecx, [rbp-56]
    cmp byte [bl_z+rcx], 0
    jne .askip
    lea rcx, [rcx+rcx*2]
    lea rsi, [bl_a+rcx*4]           ; c00
    mov edx, [bl_w]
    lea rdx, [rdx+rdx*2]
    lea rdi, [rsi+rdx*4]            ; c01
%macro BLCH 1
    mov eax, [rsi+%1*4+12]
    sub eax, [rsi+%1*4]
    imul eax, r12d
    sar eax, 8
    add eax, [rsi+%1*4]             ; top
    mov r10d, [rdi+%1*4+12]
    sub r10d, [rdi+%1*4]
    imul r10d, r12d
    sar r10d, 8
    add r10d, [rdi+%1*4]            ; bottom
    sub r10d, eax
    imul r10d, [rbp-52]
    sar r10d, 8
    add eax, r10d
    imul eax, [bl_gain]
    shr eax, 12
    CLAMP eax, 0, 255
    mov [rbp-64-%1*4], eax
    or [rbp-76], eax
%endmacro
    BLCH 0
    BLCH 1
    BLCH 2
.apply:
    cmp dword [rbp-76], 0
    je .askip
    mov ebx, [r15]
    xor r9d, r9d
%macro BLADD 2
    mov eax, ebx
    shr eax, %2
    and eax, 255
    add eax, [rbp-64-%1*4]
    cmp eax, 255
    jbe %%ok
    mov eax, 255
%%ok:
    shl eax, %2
    or r9d, eax
%endmacro
    BLADD 0, 0
    BLADD 1, 8
    BLADD 2, 16
    or r9d, 0xFF000000
    mov [r15], r9d
.askip:
    add r15, 4
    inc r14d
    jmp .ax
.ayn:
    inc r13d
    jmp .ay
.out:
    RETURN
