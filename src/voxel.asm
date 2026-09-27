; =====================================================================
;  VOXEL - procedural sprite factory
;
;  Every building, tree and vehicle is modelled as a small voxel grid
;  (16 voxels per tile edge) and baked at start-up into an isometric
;  sprite by casting one ray per pixel.  Each sprite pixel stores its
;  palette index AND a depth ("nearness" = x+y+z), so the renderer can
;  z-buffer everything and never has to sort multi-tile buildings.
;
;  Projection (2:1 isometric, 1 voxel = 2x1 px footprint, 1 px tall):
;     px = OX + (x - y)          py = OY + (x + y)/2 - z
; =====================================================================

MAX_SPRITES  equ 2048
ARENA_BYTES  equ 48*1024*1024
VOX_MAX      equ 64*64*224

; faces
FACE_TOP     equ 0
FACE_LEFT    equ 1      ; +y face, facing bottom-left
FACE_RIGHT   equ 2      ; +x face, facing bottom-right

; patterns
P_PLAIN   equ 0
P_NOISE   equ 1
P_WIN     equ 2
P_OFFICE  equ 3
P_GLASS   equ 4
P_STRIPE  equ 5
P_ROOF    equ 6
P_BRICK   equ 7
P_LEAF    equ 8
P_STACK   equ 9
P_GLOW    equ 10
P_SOLAR   equ 11
P_AWNING  equ 12
P_WATER   equ 13
P_SIGN    equ 14
P_WINDARK equ 15

section .bss
alignb 16
arena           resb ARENA_BYTES
arena_used      resd 1
spr_count       resd 1
spr_table       resb MAX_SPRITES*16
alignb 16
vox             resb VOX_MAX
vox_gx          resd 1
vox_gy          resd 1
vox_gz          resd 1
vox_seed        resd 1
vox_mat         resd 1
vox_winlit      resd 1          ; lit-window probability 0..255

section .data
; material table: ramp, shade top, shade left, shade right, pattern, p1, p2, pad
%macro MATDEF 7
    db %1, %2, %3, %4, %5, %6, %7, 0
%endmacro
mat_table:
    MATDEF 0,0,0,0,0,0,0                                   ; 0 empty
M_CONCRETE equ 1
    MATDEF R_GREY,      6,4,2, P_NOISE,0,0
M_ASPHALT equ 2
    MATDEF R_ASPHALT,   5,3,2, P_NOISE,0,0
M_GRASS equ 3
    MATDEF R_GRASS,     5,3,2, P_NOISE,0,0
M_LEAF equ 4
    MATDEF R_LEAF,      5,3,2, P_LEAF,0,0
M_LEAF2 equ 5
    MATDEF R_LEAF2,     5,3,2, P_LEAF,0,0
M_TRUNK equ 6
    MATDEF R_WOOD,      3,2,1, P_NOISE,0,0
M_SAND equ 7
    MATDEF R_SAND,      6,4,3, P_NOISE,0,0
M_WOOD equ 8
    MATDEF R_WOOD,      5,4,2, P_STRIPE,0,0
M_BRICK equ 9
    MATDEF R_BRICK,     5,4,2, P_BRICK,0,0
M_ROOF_RED equ 10
    MATDEF R_ROOF,      5,4,2, P_ROOF,0,0
M_ROOF_BLUE equ 11
    MATDEF R_BLUE,      4,3,1, P_ROOF,0,0
M_ROOF_GREY equ 12
    MATDEF R_GREY,      4,3,1, P_ROOF,0,0
M_CREAM_WIN equ 13
    MATDEF R_CREAM,     6,5,3, P_WIN,4,6
M_WHITE_WIN equ 14
    MATDEF R_WHITE,     6,5,3, P_WIN,4,6
M_BRICK_WIN equ 15
    MATDEF R_BRICK,     5,4,2, P_WIN,3,5
M_OFFICE equ 16
    MATDEF R_GREY,      6,5,3, P_OFFICE,3,5
M_GLASS equ 17
    MATDEF R_GLASS,     5,4,2, P_GLASS,3,4
M_METAL equ 18
    MATDEF R_GREY,      5,4,2, P_STRIPE,0,0
M_TEAL_METAL equ 19
    MATDEF R_TEAL,      5,4,2, P_STRIPE,0,0
M_YELLOW equ 20
    MATDEF R_YELLOW,    5,4,2, P_PLAIN,0,0
M_RED equ 21
    MATDEF R_RED,       5,4,2, P_PLAIN,0,0
M_ORANGE equ 22
    MATDEF R_ORANGE,    5,4,2, P_PLAIN,0,0
M_WATER equ 23
    MATDEF R_DEEPWATER, 5,4,3, P_WATER,0,0
M_DARK equ 24
    MATDEF R_ASPHALT,   2,1,0, P_PLAIN,0,0
M_LAMP equ 25
    MATDEF R_YELLOW,    7,7,7, P_GLOW,4,0
M_BEACON equ 26
    MATDEF R_RED,       6,6,6, P_GLOW,5,0
M_NEON_P equ 27
    MATDEF R_PURPLE,    6,6,6, P_GLOW,6,0
M_NEON_C equ 28
    MATDEF R_GLASS,     6,6,6, P_GLOW,7,0
M_STACK equ 29
    MATDEF R_RED,       5,4,2, P_STACK,4,0
M_SOLAR equ 30
    MATDEF R_BLUE,      2,2,1, P_SOLAR,0,0
M_AWN_RED equ 31
    MATDEF R_RED,       5,4,3, P_AWNING,0,0
M_AWN_BLUE equ 32
    MATDEF R_BLUE,      5,4,3, P_AWNING,0,0
M_AWN_GREEN equ 33
    MATDEF R_ZONER,     5,4,3, P_AWNING,0,0
M_WHITE equ 34
    MATDEF R_WHITE,     6,5,3, P_NOISE,0,0
M_CREAM equ 35
    MATDEF R_CREAM,     6,5,3, P_NOISE,0,0
M_BLUE equ 36
    MATDEF R_BLUE,      5,4,2, P_PLAIN,0,0
M_PURPLE equ 37
    MATDEF R_PURPLE,    5,4,2, P_PLAIN,0,0
M_TEAL equ 38
    MATDEF R_TEAL,      5,4,2, P_NOISE,0,0
M_OLIVE equ 39
    MATDEF R_OLIVE,     5,4,2, P_NOISE,0,0
M_SIGN_C equ 40
    MATDEF R_ASPHALT,   2,2,2, P_SIGN,7,0
M_SIGN_P equ 41
    MATDEF R_ASPHALT,   2,2,2, P_SIGN,6,0
M_BLUE_WIN equ 42
    MATDEF R_BLUE,      6,5,3, P_WIN,4,6
M_TEAL_WIN equ 43
    MATDEF R_TEAL,      6,5,3, P_OFFICE,4,5
M_SKIN equ 44
    MATDEF R_SKIN,      5,4,3, P_PLAIN,0,0
M_DIRT equ 45
    MATDEF R_WOOD,      4,3,2, P_NOISE,0,0
M_GLASS_BLUE equ 46
    MATDEF R_BLUE,      5,4,2, P_GLASS,4,4
M_RUST equ 47
    MATDEF R_ORANGE,    3,2,1, P_STRIPE,0,0
M_WINDARK equ 48
    MATDEF R_GREY,      4,3,2, P_WINDARK,3,5
M_ZONE_R equ 49
    MATDEF R_ZONER,     5,4,3, P_PLAIN,0,0
M_ZONE_C equ 50
    MATDEF R_ZONEC,     5,4,3, P_PLAIN,0,0
M_ZONE_I equ 51
    MATDEF R_ZONEI,     5,4,3, P_PLAIN,0,0
M_BRIGHT equ 52
    MATDEF R_WHITE,     7,6,5, P_PLAIN,0,0
M_ROOF_GREEN equ 53
    MATDEF R_ZONER,     4,3,1, P_ROOF,0,0
M_ROOF_BROWN equ 54
    MATDEF R_WOOD,      4,3,1, P_ROOF,0,0
M_GOLD equ 55
    MATDEF R_YELLOW,    6,5,3, P_NOISE,0,0
M_PURPLE_WIN equ 56
    MATDEF R_PURPLE,    6,5,3, P_OFFICE,3,5
M_CREAM_OFFICE equ 57
    MATDEF R_CREAM,     6,5,3, P_OFFICE,3,5
M_SMOKE equ 58
    MATDEF R_GREY,      6,5,4, P_NOISE,0,0
M_FIRE equ 59
    MATDEF R_ORANGE,    7,6,5, P_LEAF,0,0
M_COUNT equ 60
    times (256-M_COUNT)*8 db 0

section .text

; ---------------------------------------------------------------------
;  vox_begin(edi gx=gy, esi gz, edx seed) - clear the grid
; ---------------------------------------------------------------------
vox_begin:
    mov [vox_gx], edi
    mov [vox_gy], edi
    mov [vox_gz], esi
    mov [vox_seed], edx
    mov dword [vox_winlit], 150
    imul edi, edi
    imul edi, esi
    mov ecx, edi
    lea rdi, [vox]
    xor eax, eax
    rep stosb
    ret

; ---------------------------------------------------------------------
;  vbox(edi x0, esi y0, edx z0, ecx x1, r8d y1, r9d z1) fill [x0,x1)...
; ---------------------------------------------------------------------
vbox:
    push rbx
    push r12
    push r13
    push r14
    push r15
    xor eax, eax
    cmp edi, eax
    cmovl edi, eax
    cmp esi, eax
    cmovl esi, eax
    cmp edx, eax
    cmovl edx, eax
    cmp ecx, [vox_gx]
    cmovg ecx, [vox_gx]
    cmp r8d, [vox_gy]
    cmovg r8d, [vox_gy]
    cmp r9d, [vox_gz]
    cmovg r9d, [vox_gz]
    mov bl, [vox_mat]
    mov r12d, edx                   ; z
.z:
    cmp r12d, r9d
    jge .done
    mov r13d, esi                   ; y
.y:
    cmp r13d, r8d
    jge .zn
    mov eax, r12d
    imul eax, [vox_gy]
    add eax, r13d
    imul eax, [vox_gx]
    add eax, edi
    lea r15, [vox+rax]
    mov r14d, edi                   ; x
.x:
    cmp r14d, ecx
    jge .yn
    mov [r15], bl
    inc r15
    inc r14d
    jmp .x
.yn:
    inc r13d
    jmp .y
.zn:
    inc r12d
    jmp .z
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; vset(edi x, esi y, edx z)
vset:
    lea ecx, [rdi+1]
    lea r8d, [rsi+1]
    lea r9d, [rdx+1]
    jmp vbox

; ---------------------------------------------------------------------
;  vroof_x: gable roof, ridge along x (slopes face +-y)
;  (edi x0, esi y0, edx z0, ecx x1, r8d y1, r9d h)
; ---------------------------------------------------------------------
FUNC vroof_x
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov ebx, r8d
    mov [rbp-48], r9d
.l:
    cmp dword [rbp-48], 0
    jle .d
    cmp r13d, ebx
    jge .d
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, r15d
    mov r8d, ebx
    lea r9d, [r14+1]
    call vbox
    inc r13d
    dec ebx
    inc r14d
    dec dword [rbp-48]
    jmp .l
.d:
    RETURN

; gable roof, ridge along y (slopes face +-x)
FUNC vroof_y
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov ebx, r8d
    mov [rbp-48], r9d
.l:
    cmp dword [rbp-48], 0
    jle .d
    cmp r12d, r15d
    jge .d
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, r15d
    mov r8d, ebx
    lea r9d, [r14+1]
    call vbox
    inc r12d
    dec r15d
    inc r14d
    dec dword [rbp-48]
    jmp .l
.d:
    RETURN

; hip / pyramid roof
FUNC vpyr
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov ebx, r8d
    mov [rbp-48], r9d
.l:
    cmp dword [rbp-48], 0
    jle .d
    cmp r12d, r15d
    jge .d
    cmp r13d, ebx
    jge .d
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, r15d
    mov r8d, ebx
    lea r9d, [r14+1]
    call vbox
    inc r12d
    dec r15d
    inc r13d
    dec ebx
    inc r14d
    dec dword [rbp-48]
    jmp .l
.d:
    RETURN

; ---------------------------------------------------------------------
;  vcyl(edi cx2, esi cy2, edx z0, ecx r2, r8d z1)
;  centre and radius in half-voxel units
; ---------------------------------------------------------------------
FUNC vcyl
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov [rbp-48], r8d
    imul r15d, r15d                 ; r2^2
    xor ebx, ebx                    ; y
.y:
    cmp ebx, [vox_gy]
    jge .d
    xor ecx, ecx                    ; x
.x:
    cmp ecx, [vox_gx]
    jge .yn
    lea eax, [rcx*2+1]
    sub eax, r12d
    imul eax, eax
    lea edx, [rbx*2+1]
    sub edx, r13d
    imul edx, edx
    add eax, edx
    cmp eax, r15d
    jg .xn
    push rcx
    push rcx
    mov edi, ecx
    mov esi, ebx
    mov edx, r14d
    inc ecx
    lea r8d, [rbx+1]
    mov r9d, [rbp-48]
    call vbox
    pop rcx
    pop rcx
.xn:
    inc ecx
    jmp .x
.yn:
    inc ebx
    jmp .y
.d:
    RETURN

; ---------------------------------------------------------------------
;  vcone(edi cx2, esi cy2, edx z0, ecx r2 base, r8d h) - radius tapers
; ---------------------------------------------------------------------
FUNC vcone, 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov [rbp-48], r8d               ; h
    xor ebx, ebx                    ; layer
.l:
    cmp ebx, [rbp-48]
    jge .d
    ; r = r2 * (h - layer) / h
    mov eax, [rbp-48]
    sub eax, ebx
    imul eax, r15d
    xor edx, edx
    div dword [rbp-48]
    test eax, eax
    jz .d
    mov ecx, eax
    mov edi, r12d
    mov esi, r13d
    lea edx, [r14+rbx]
    lea r8d, [r14+rbx+1]
    call vcyl
    inc ebx
    jmp .l
.d:
    RETURN

; ---------------------------------------------------------------------
;  vsphere(edi cx2, esi cy2, edx cz2, ecx r2) - all in half voxels
; ---------------------------------------------------------------------
FUNC vsphere, 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    imul ecx, ecx
    mov [rbp-48], ecx               ; r^2
    xor ebx, ebx                    ; z
.z:
    cmp ebx, [vox_gz]
    jge .d
    lea eax, [rbx*2+1]
    sub eax, r14d
    imul eax, eax
    mov ecx, [rbp-48]
    sub ecx, eax
    jl .zn
    ; radius at this layer = sqrt(ecx) (integer sqrt)
    xor eax, eax
.sq:
    lea edx, [rax+1]
    imul edx, edx
    cmp edx, ecx
    jg .sqd
    inc eax
    jmp .sq
.sqd:
    test eax, eax
    jz .zn
    mov ecx, eax
    mov edi, r12d
    mov esi, r13d
    mov edx, ebx
    lea r8d, [rbx+1]
    call vcyl
.zn:
    inc ebx
    jmp .z
.d:
    RETURN

; ---------------------------------------------------------------------
;  shade(edi mat, esi face, edx u, ecx v(z), r8d x, r9d y) -> eax index
;  u = coordinate along the face, v = z (sides)
; ---------------------------------------------------------------------
FUNC shade, 16
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov [rbp-48], r8d
    mov [rbp-52], r9d
    lea rbx, [mat_table+r12*8]
    movzx eax, byte [rbx+1+r13]     ; shade for face
    mov [rbp-56], eax
    movzx eax, byte [rbx+4]
    cmp eax, P_WINDARK
    ja .plain
    jmp [pat_jump+rax*8]

.plain:
    jmp .base
.noise:
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, r13d
    shl edx, 6
    add edx, r15d
    call hash3
    and eax, 15
    cmp eax, 1
    jg .n2
    dec dword [rbp-56]
    jmp .base
.n2:
    cmp eax, 14
    jl .base
    inc dword [rbp-56]
    jmp .base

.leaf:
    mov edi, [rbp-48]
    mov esi, [rbp-52]
    mov edx, r13d
    shl edx, 6
    add edx, r15d
    call hash3
    and eax, 15
    cmp eax, 3
    jg .l2
    sub dword [rbp-56], 2
    jmp .base
.l2:
    cmp eax, 7
    jg .l3
    dec dword [rbp-56]
    jmp .base
.l3:
    cmp eax, 13
    jl .base
    inc dword [rbp-56]
    jmp .base

.stripe:
    cmp r13d, FACE_TOP
    je .base
    test r14d, 1
    jnz .base
    dec dword [rbp-56]
    jmp .base

.roof:
    test r15d, 1
    jnz .base
    dec dword [rbp-56]
    jmp .base

.brick:
    cmp r13d, FACE_TOP
    je .noise
    mov eax, r15d
    xor edx, edx
    mov ecx, 3
    div ecx
    test edx, edx
    jnz .br2
    inc dword [rbp-56]
    jmp .base
.br2:
    ; vertical joints offset per course
    and eax, 1
    lea eax, [r14+rax*2]
    and eax, 3
    jnz .noise
    inc dword [rbp-56]
    jmp .base

.win:   ; punched windows: p1 = horizontal period, p2 = vertical period
    cmp r13d, FACE_TOP
    je .base
    movzx ecx, byte [rbx+5]
    mov eax, r14d
    xor edx, edx
    div ecx
    test edx, edx
    jz .base
    dec ecx
    cmp edx, ecx
    jge .base
    mov [rbp-60], eax               ; column
    movzx ecx, byte [rbx+6]
    mov eax, r15d
    xor edx, edx
    div ecx
    cmp edx, 2
    jl .base
    sub ecx, 1
    cmp edx, ecx
    jge .base
    jmp .window                     ; eax = row

.office: ; ribbon windows
    cmp r13d, FACE_TOP
    je .base
    movzx ecx, byte [rbx+5]
    mov eax, r14d
    xor edx, edx
    div ecx
    test edx, edx
    jz .base
    mov [rbp-60], eax
    movzx ecx, byte [rbx+6]
    mov eax, r15d
    xor edx, edx
    div ecx
    cmp edx, 1
    jl .base
    sub ecx, 1
    cmp edx, ecx
    jge .base
    jmp .window

.windark: ; ribbon windows that never light (abandoned / industrial)
    cmp r13d, FACE_TOP
    je .base
    movzx ecx, byte [rbx+6]
    mov eax, r15d
    xor edx, edx
    div ecx
    cmp edx, 1
    jl .base
    sub ecx, 1
    cmp edx, ecx
    jge .base
    mov eax, RAMP(R_ASPHALT, 2)
    RETURN

.glass:
    cmp r13d, FACE_TOP
    je .base
    movzx ecx, byte [rbx+5]
    mov eax, r14d
    xor edx, edx
    div ecx
    test edx, edx
    jnz .g1
    add dword [rbp-56], 2           ; mullion
    jmp .base
.g1:
    mov [rbp-60], eax
    movzx ecx, byte [rbx+6]
    mov eax, r15d
    xor edx, edx
    div ecx
    test edx, edx
    jnz .g2
    dec dword [rbp-56]              ; floor slab line
    jmp .base
.g2:
    ; reflection gradient: lighter high up
    push rax
    push rax
    mov edi, [rbp-60]
    mov esi, eax
    lea edx, [r13+500]
    add edx, [vox_seed]
    call hash3
    mov ecx, eax
    pop rax
    pop rax
    and ecx, 255
    cmp ecx, [vox_winlit]
    jae .base
    shr ecx, 6
    lea eax, [rcx+PAL_GLOW]
    RETURN

.window: ; eax = row, [rbp-60] = column -> lit or dark glass
    mov edi, [rbp-60]
    mov esi, eax
    lea edx, [r13*8+77]
    add edx, [vox_seed]
    call hash3
    mov ecx, eax
    and ecx, 255
    cmp ecx, [vox_winlit]
    jae .unlit
    shr eax, 8
    and eax, 3
    add eax, PAL_GLOW
    RETURN
.unlit:
    mov eax, RAMP(R_GLASS, 1)
    cmp r13d, FACE_LEFT
    jne .ul
    mov eax, RAMP(R_GLASS, 2)
.ul:
    RETURN

.stack:
    movzx ecx, byte [rbx+5]
    mov eax, r15d
    xor edx, edx
    div ecx
    test eax, 1
    jz .base
    mov eax, [rbp-56]
    add eax, RAMP(R_WHITE, 0)
    RETURN

.glow:
    movzx eax, byte [rbx+5]
    add eax, PAL_GLOW
    RETURN

.solar:
    cmp r13d, FACE_TOP
    jne .base
    mov eax, [rbp-48]
    and eax, 3
    jz .sgrid
    mov eax, [rbp-52]
    and eax, 3
    jz .sgrid
    jmp .noise
.sgrid:
    mov eax, RAMP(R_GREY, 5)
    RETURN

.awning:
    mov eax, r14d
    cmp r13d, FACE_TOP
    jne .aw
    mov eax, [rbp-48]
    add eax, [rbp-52]
.aw:
    shr eax, 1
    test eax, 1
    jz .base
    mov eax, [rbp-56]
    add eax, RAMP(R_WHITE, 0)
    RETURN

.water:
    mov eax, [rbp-48]
    add eax, [rbp-52]
    shr eax, 1
    and eax, 7
    add eax, PAL_WATER
    RETURN

.sign:
    mov edi, r14d
    mov esi, r15d
    mov edx, [vox_seed]
    call hash3
    and eax, 3
    jz .base
    movzx eax, byte [rbx+5]
    add eax, PAL_GLOW
    RETURN

.base:
    mov eax, [rbp-56]
    CLAMP eax, 0, 7
    movzx ecx, byte [rbx]
    lea eax, [rax+rcx*8+RAMP_BASE]
    RETURN

section .data
align 8
pat_jump:
    dq shade.plain, shade.noise, shade.win, shade.office, shade.glass
    dq shade.stripe, shade.roof, shade.brick, shade.leaf, shade.stack
    dq shade.glow, shade.solar, shade.awning, shade.water, shade.sign
    dq shade.windark
section .text

; ---------------------------------------------------------------------
;  sprite_new(edi w, esi h) -> eax id, rdx colour plane ptr
; ---------------------------------------------------------------------
sprite_new:
    mov eax, [spr_count]
    inc dword [spr_count]
    mov ecx, eax
    shl ecx, 4
    mov [spr_table+rcx], di
    mov [spr_table+rcx+2], si
    mov r8d, [arena_used]
    mov [spr_table+rcx+8], r8d
    imul edi, esi
    lea edx, [rdi*2+15]
    and edx, ~15
    add [arena_used], edx
    lea rdx, [arena+r8]
    ret

; ---------------------------------------------------------------------
;  vox_render -> eax sprite id
;  casts rays through the current grid; sprite anchor = grid (0,0,0)
; ---------------------------------------------------------------------
FUNC vox_render, 64
    mov eax, [vox_gx]
    lea edi, [rax*2]                ; w
    mov esi, [vox_gz]
    add esi, eax                    ; h = gz + gx
    mov [rbp-48], edi
    mov [rbp-52], esi
    call sprite_new
    mov [rbp-56], eax               ; id
    mov [rbp-64], rdx               ; colour plane
    mov eax, [rbp-48]
    imul eax, [rbp-52]
    add rax, rdx
    mov [rbp-72], rax               ; depth plane
    mov eax, [vox_gx]
    mov [rbp-76], eax               ; OX
    ; row stride for the grid
    mov eax, [vox_gx]
    imul eax, [vox_gy]
    mov [rbp-80], eax               ; layer size

    xor r12d, r12d                  ; py
.py:
    cmp r12d, [rbp-52]
    jge .done
    xor r13d, r13d                  ; px
.px:
    cmp r13d, [rbp-48]
    jge .pyn
    ; X4 = 4py + 2(px-OX) + 5 ; Y4 = 4py - 2(px-OX) + 3 ; Z4 = 4GZ+2
    mov eax, r13d
    sub eax, [rbp-76]
    add eax, eax
    lea ecx, [r12*4]
    lea r8d, [rcx+rax+5]            ; X4
    mov r9d, ecx
    sub r9d, eax
    add r9d, 3                      ; Y4
    mov r10d, [vox_gz]
    lea r10d, [r10*4+2]             ; Z4
    xor r11d, r11d                  ; face of last crossing
.step:
    ; skip ahead when outside the grid in x/y
    mov eax, r8d
    sar eax, 2
    cmp eax, [vox_gx]
    jl .xin
    mov eax, [vox_gx]
    shl eax, 2
    dec eax
    mov ecx, r8d
    sub ecx, eax                    ; k for x
    mov r11d, FACE_RIGHT
    jmp .skip
.xin:
    mov eax, r9d
    sar eax, 2
    cmp eax, [vox_gy]
    jl .inside
    mov eax, [vox_gy]
    shl eax, 2
    dec eax
    mov ecx, r9d
    sub ecx, eax
    mov r11d, FACE_LEFT
.skip:
    ; also consider y needing more
    mov eax, [vox_gy]
    shl eax, 2
    dec eax
    mov edx, r9d
    sub edx, eax
    cmp edx, ecx
    jle .k1
    mov ecx, edx
    mov r11d, FACE_LEFT
.k1:
    mov eax, [vox_gx]
    shl eax, 2
    dec eax
    mov edx, r8d
    sub edx, eax
    cmp edx, ecx
    jle .k2
    mov ecx, edx
    mov r11d, FACE_RIGHT
.k2:
    sub r8d, ecx
    sub r9d, ecx
    sub r10d, ecx
    jmp .test
.inside:
    dec r8d
    dec r9d
    dec r10d
    mov eax, r8d
    and eax, 3
    cmp eax, 3
    jne .ny
    mov r11d, FACE_RIGHT
    jmp .test
.ny:
    mov eax, r9d
    and eax, 3
    cmp eax, 3
    jne .nz
    mov r11d, FACE_LEFT
    jmp .test
.nz:
    mov eax, r10d
    and eax, 3
    cmp eax, 3
    jne .step
    mov r11d, FACE_TOP
.test:
    mov eax, r8d
    sar eax, 2
    js .miss
    mov ecx, r9d
    sar ecx, 2
    js .miss
    mov edx, r10d
    sar edx, 2
    js .miss
    cmp eax, [vox_gx]
    jge .step
    cmp ecx, [vox_gy]
    jge .step
    cmp edx, [vox_gz]
    jge .step
    mov r14d, eax                   ; ix
    mov r15d, ecx                   ; iy
    mov ebx, edx                    ; iz
    imul edx, [rbp-80]
    imul ecx, [vox_gx]
    add edx, ecx
    add edx, eax
    movzx eax, byte [vox+rdx]
    test eax, eax
    jz .step
    ; ---- hit ----
    mov [rbp-84], r11d
    lea ecx, [r8+r9]
    add ecx, r10d
    sar ecx, 2
    CLAMP ecx, 1, 255
    mov [rbp-88], ecx               ; depth
    mov edi, eax                    ; material
    mov esi, r11d                   ; face
    ; u: along the face
    mov edx, r14d                   ; left face (+y) runs along x
    cmp r11d, FACE_RIGHT
    jne .u
    mov edx, r15d                   ; right face runs along y
.u:
    mov ecx, ebx
    mov r8d, r14d
    mov r9d, r15d
    call shade
    mov edx, r12d
    imul edx, [rbp-48]
    add edx, r13d
    mov rcx, [rbp-64]
    mov [rcx+rdx], al
    mov rcx, [rbp-72]
    mov eax, [rbp-88]
    mov [rcx+rdx], al
    jmp .pxn
.miss:
    mov edx, r12d
    imul edx, [rbp-48]
    add edx, r13d
    mov rcx, [rbp-64]
    mov byte [rcx+rdx], 0
    mov rcx, [rbp-72]
    mov byte [rcx+rdx], 0
.pxn:
    inc r13d
    jmp .px
.pyn:
    inc r12d
    jmp .py
.done:
    ; anchor
    mov eax, [rbp-56]
    shl eax, 4
    mov ecx, [vox_gx]
    mov [spr_table+rax+4], cx
    mov ecx, [vox_gz]
    mov [spr_table+rax+6], cx
    mov edi, [rbp-56]
    call sprite_trim
    call sprite_outline
    mov eax, [rbp-56]
    RETURN

; ---------------------------------------------------------------------
;  sprite_trim(edi id): drop fully transparent rows from the top
; ---------------------------------------------------------------------
sprite_trim:
    push rbx
    mov eax, edi
    shl eax, 4
    lea rbx, [spr_table+rax]
    movzx ecx, word [rbx]           ; w
    movzx edx, word [rbx+2]         ; h
    mov r8d, [rbx+8]
    lea r8, [arena+r8]              ; colour
    xor r9d, r9d                    ; empty rows
.r:
    cmp r9d, edx
    jge .cnt
    mov eax, r9d
    imul eax, ecx
    lea r10, [r8+rax]
    xor r11d, r11d
.c:
    cmp byte [r10+r11], 0
    jne .cnt
    inc r11d
    cmp r11d, ecx
    jl .c
    inc r9d
    jmp .r
.cnt:
    test r9d, r9d
    jz .out
    cmp r9d, edx
    jge .out
    ; move colour rows and depth rows up
    mov eax, r9d
    imul eax, ecx                   ; bytes skipped
    mov r10d, edx
    sub r10d, r9d                   ; new h
    mov r11d, r10d
    imul r11d, ecx                  ; new plane size
    push rsi
    push rdi
    ; colour
    lea rsi, [r8+rax]
    mov rdi, r8
    push rcx
    mov ecx, r11d
    rep movsb
    pop rcx
    ; depth: old depth plane starts at r8 + w*h
    mov eax, ecx
    imul eax, edx
    lea rsi, [r8+rax]
    mov eax, r9d
    imul eax, ecx
    add rsi, rax
    lea rdi, [r8+r11]
    push rcx
    mov ecx, r11d
    rep movsb
    pop rcx
    pop rdi
    pop rsi
    mov [rbx+2], r10w
    sub [rbx+6], r9w
.out:
    pop rbx
    ret

; ---------------------------------------------------------------------
;  sprite_outline(edi id): darken the silhouette edges one step and
;  put a crisp dark edge where a face meets the sky - the hand-drawn
;  outline look of classic pixel art sprites.
; ---------------------------------------------------------------------
sprite_outline:
    push rbx
    push r12
    push r13
    mov eax, edi
    shl eax, 4
    lea rbx, [spr_table+rax]
    movzx ecx, word [rbx]           ; w
    movzx edx, word [rbx+2]         ; h
    mov r8d, [rbx+8]
    lea r8, [arena+r8]
    xor r9d, r9d                    ; y
.y:
    cmp r9d, edx
    jge .d
    xor r10d, r10d                  ; x
.x:
    cmp r10d, ecx
    jge .yn
    mov eax, r9d
    imul eax, ecx
    add eax, r10d
    movzx r11d, byte [r8+rax]
    test r11d, r11d
    jz .xn
    ; is a neighbour (left/right/up) transparent?
    xor r12d, r12d
    test r10d, r10d
    jz .edge
    cmp byte [r8+rax-1], 0
    je .edge
    lea r13d, [r10+1]
    cmp r13d, ecx
    jge .edge
    cmp byte [r8+rax+1], 0
    je .edge
    test r9d, r9d
    jz .edge
    mov r13d, eax
    sub r13d, ecx
    cmp byte [r8+r13], 0
    je .edge
    jmp .xn
.edge:
    ; only darken ramp colours (keep glows / water)
    cmp r11d, RAMP_BASE
    jb .xn
    cmp r11d, PAL_WATER
    jae .xn
    mov r13d, r11d
    sub r13d, RAMP_BASE
    and r13d, 7
    cmp r13d, 1
    jb .xn
    dec r11d
    cmp r13d, 3
    jb .st
    dec r11d
.st:
    mov [r8+rax], r11b
.xn:
    inc r10d
    jmp .x
.yn:
    inc r9d
    jmp .y
.d:
    pop r13
    pop r12
    pop rbx
    ret

; ---------------------------------------------------------------------
;  blit_sprite(edi id, esi sx, edx sy, ecx depth base, r8 remap|0)
;  sx,sy = screen position of the sprite anchor. z-buffered.
; ---------------------------------------------------------------------
FUNC blit_sprite, 32
    mov eax, edi
    shl eax, 4
    lea rbx, [spr_table+rax]
    test r8, r8
    jnz .hr
    lea r8, [remap_identity]
.hr:
    mov [rbp-48], r8
    mov [rbp-52], ecx               ; depth base
    movzx r12d, word [rbx]          ; w
    movzx r13d, word [rbx+2]        ; h
    movsx eax, word [rbx+4]
    sub esi, eax                    ; left
    movsx eax, word [rbx+6]
    sub edx, eax                    ; top
    mov eax, [rbx+8]
    lea r14, [arena+rax]            ; colour plane
    mov eax, r12d
    imul eax, r13d
    lea r15, [r14+rax]              ; depth plane
    ; clip rows
    xor ecx, ecx                    ; first row
    mov eax, edx
    neg eax
    cmp eax, 0
    jle .noclipt
    mov ecx, eax
.noclipt:
    mov eax, [fb_h]
    sub eax, edx                    ; rows available
    cmp r13d, eax
    jle .rowsok
    mov r13d, eax
.rowsok:
    ; clip cols
    xor r9d, r9d                    ; first col
    mov eax, esi
    neg eax
    cmp eax, 0
    jle .nocl
    mov r9d, eax
.nocl:
    mov r10d, r12d                  ; last col (exclusive)
    mov eax, [fb_w]
    sub eax, esi
    cmp r10d, eax
    jle .colok
    mov r10d, eax
.colok:
    mov [rbp-68], r10d
    cmp r9d, r10d
    jge .out
    mov [rbp-56], esi
    mov [rbp-60], edx
    mov [rbp-64], ecx
    mov r11, [rbp-48]
.row:
    mov ecx, [rbp-64]
    cmp ecx, r13d
    jge .out
    ; src index
    mov eax, ecx
    imul eax, r12d
    add eax, r9d
    lea rsi, [r14+rax]              ; colour src
    lea rdi, [r15+rax]              ; depth src
    ; dst index
    mov eax, [rbp-60]
    add eax, ecx
    imul eax, [fb_w]
    add eax, [rbp-56]
    add eax, r9d
    lea rbx, [fb+rax]
    lea rdx, [zbuf+rax*2]
    mov r8d, r10d
    sub r8d, r9d
    mov r10d, [rbp-52]
.col:
    movzx eax, byte [rsi]
    test eax, eax
    jz .cn
    movzx ecx, byte [rdi]
    add ecx, r10d
    cmp cx, [rdx]
    jb .cn
    mov [rdx], cx
    mov al, [r11+rax]
    mov [rbx], al
    mov cl, [blit_tint]
    mov [rbx+(tintbuf-fb)], cl
.cn:
    inc rsi
    inc rdi
    inc rbx
    add rdx, 2
    dec r8d
    jnz .col
    ; restore last-col
    mov r10d, [rbp-68]
    inc dword [rbp-64]
    jmp .row
.out:
    RETURN

; blit_flat(edi id, esi x, edx y, r8 remap|0) - no depth, onto current target
; (used for icons in the ui); x,y = top-left
FUNC blit_flat, 16
    mov eax, edi
    shl eax, 4
    lea rbx, [spr_table+rax]
    test r8, r8
    jnz .hr
    lea r8, [remap_identity]
.hr:
    mov r15, r8
    movzx r12d, word [rbx]
    movzx r13d, word [rbx+2]
    mov eax, [rbx+8]
    lea r14, [arena+rax]
    mov [rbp-48], esi
    mov [rbp-52], edx
    xor ebx, ebx                    ; row
.r:
    cmp ebx, r13d
    jge .d
    xor ecx, ecx
.c:
    cmp ecx, r12d
    jge .rn
    mov eax, ebx
    imul eax, r12d
    add eax, ecx
    movzx eax, byte [r14+rax]
    test eax, eax
    jz .cn
    movzx edx, byte [r15+rax]
    push rcx
    push rcx
    mov edi, [rbp-48]
    add edi, ecx
    mov esi, [rbp-52]
    add esi, ebx
    call put_pixel
    pop rcx
    pop rcx
.cn:
    inc ecx
    jmp .c
.rn:
    inc ebx
    jmp .r
.d:
    RETURN

; sprite dims helpers: sprite_wh(edi id) -> eax w, edx h
sprite_wh:
    shl edi, 4
    movzx eax, word [spr_table+rdi]
    movzx edx, word [spr_table+rdi+2]
    ret

section .bss
alignb 16
remap_identity  resb 256
remap_green     resb 256
remap_red       resb 256
remap_dark      resb 256
remap_fire      resb 256
remap_bright    resb 256
remap_dim       resb 256
remap_cars      resb 256*8
remap_heat      resb 256*16

section .text
; ---------------------------------------------------------------------
;  build colour remap tables
; ---------------------------------------------------------------------
FUNC remaps_init
    xor ecx, ecx
.id:
    mov [remap_identity+rcx], cl
    mov [remap_green+rcx], cl
    mov [remap_red+rcx], cl
    mov [remap_dark+rcx], cl
    mov [remap_fire+rcx], cl
    mov [remap_bright+rcx], cl
    mov [remap_dim+rcx], cl
    inc ecx
    cmp ecx, 256
    jl .id
    ; ramp colours -> green / red / darker / fiery / brighter versions
    mov ecx, RAMP_BASE
.r:
    mov eax, ecx
    sub eax, RAMP_BASE
    mov edx, eax
    and edx, 7                      ; shade
    ; green ghost: ramp zone R shade (shade/2+3)
    mov r8d, edx
    shr r8d, 1
    add r8d, 3
    lea r9d, [r8+R_ZONER*8+RAMP_BASE]
    mov [remap_green+rcx], r9b
    lea r9d, [r8+R_RED*8+RAMP_BASE]
    mov [remap_red+rcx], r9b
    lea r9d, [r8+R_ORANGE*8+RAMP_BASE-1]
    mov [remap_fire+rcx], r9b
    ; dark: -2 shades, desaturate toward grey ramp
    mov r8d, edx
    sub r8d, 2
    jns .dk
    xor r8d, r8d
.dk:
    lea r9d, [r8+R_GREY*8+RAMP_BASE]
    mov [remap_dark+rcx], r9b
    ; bright: +1 shade
    mov r8d, edx
    inc r8d
    cmp r8d, 7
    jle .br
    mov r8d, 7
.br:
    mov r9d, eax
    and r9d, ~7
    lea r9d, [r9+r8+RAMP_BASE]
    mov [remap_bright+rcx], r9b
    ; dim (land you don't own): two shades down, same colour
    mov r8d, edx
    sub r8d, 2
    jns .dm
    xor r8d, r8d
.dm:
    mov r9d, eax
    and r9d, ~7
    lea r9d, [r9+r8+RAMP_BASE]
    mov [remap_dim+rcx], r9b
    inc ecx
    cmp ecx, PAL_WATER
    jl .r
    ; glows: dark in abandoned, orange in fire
    mov ecx, PAL_GLOW
.g:
    mov byte [remap_dark+rcx], RAMP(R_ASPHALT, 2)
    mov byte [remap_fire+rcx], RAMP(R_YELLOW, 7)
    mov byte [remap_green+rcx], RAMP(R_ZONER, 6)
    mov byte [remap_red+rcx], RAMP(R_RED, 6)
    inc ecx
    cmp ecx, PAL_GLOW+8
    jl .g

    ; car colour variants: remap the red ramp to other ramps
    xor ebx, ebx
.cv:
    lea rdi, [remap_cars]
    mov eax, ebx
    shl eax, 8
    add rdi, rax
    xor ecx, ecx
.cc:
    mov [rdi+rcx], cl
    inc ecx
    cmp ecx, 256
    jl .cc
    movzx r8d, byte [car_ramps+rbx]
    xor ecx, ecx
.cs:
    lea eax, [r8*8+RAMP_BASE]
    add eax, ecx
    mov [rdi+RAMP(R_RED,0)+rcx], al
    inc ecx
    cmp ecx, 8
    jl .cs
    inc ebx
    cmp ebx, 8
    jl .cv

    ; heat tables: every ramp colour -> one heat colour
    xor ebx, ebx
.ht:
    mov eax, ebx
    shl eax, 8
    lea rdi, [remap_heat+rax]
    xor ecx, ecx
.hi:
    mov [rdi+rcx], cl
    cmp ecx, RAMP_BASE
    jb .hn
    cmp ecx, PAL_WATER
    jae .hn
    lea eax, [rbx+PAL_HEAT]
    ; keep a hint of the original shading
    mov edx, ecx
    and edx, 7
    cmp edx, 2
    jae .hs
    lea eax, [rbx+PAL_HEAT]
    cmp ebx, 0
    je .hs
    dec eax
.hs:
    mov [rdi+rcx], al
.hn:
    inc ecx
    cmp ecx, 256
    jl .hi
    inc ebx
    cmp ebx, 16
    jl .ht
    RETURN

section .data
car_ramps db R_RED, R_BLUE, R_YELLOW, R_WHITE, R_ZONER, R_ASPHALT, R_ORANGE, R_TEAL
section .text
