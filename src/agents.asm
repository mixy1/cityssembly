; =====================================================================
;  AGENTS - cars, pedestrians, particles and floating text
;
;  Agents live in world voxel space (16 units per tile, z up), so they
;  project and depth-test exactly like the baked sprites:
;     sx = (x - y) + ORIGIN_X - cam_x     sy = (x + y)/2 - z - cam_y
;     depth = x + y + z
;  Positions are stored in 1/16 voxel fixed point.
; =====================================================================

MAX_CARS     equ 400
MAX_PEEPS    equ 300
MAX_PARTS    equ 1200
MAX_FLOATS   equ 32

; car record (32 bytes)
C_TX    equ 0   ; word tile x
C_TY    equ 2   ; word tile y
C_DIR   equ 4   ; byte
C_TYPE  equ 5   ; byte (0 car, 1 truck, 2 bus); 255 = free
C_COLOR equ 6   ; byte
C_FLAGS equ 7
C_PROG  equ 8   ; dword progress along tile (fixed 4)
C_SPEED equ 12  ; dword
C_LIFE  equ 16  ; dword
C_WX    equ 20  ; dword world x (voxels) cached
C_WY    equ 24
C_SIZE  equ 32

; particle record (32 bytes)
PT_X    equ 0   ; fixed 4
PT_Y    equ 4
PT_Z    equ 8
PT_VX   equ 12
PT_VY   equ 16
PT_VZ   equ 20
PT_LIFE equ 24  ; word
PT_TYPE equ 26  ; byte
PT_COL  equ 27  ; byte
PT_MAX  equ 28  ; word initial life
PT_SIZE equ 32

PK_SMOKE    equ 1
PK_DUST     equ 2
PK_SPARK    equ 3
PK_CONFETTI equ 4
PK_EMBER    equ 5
PK_STEAM    equ 6

; floating text (48 bytes)
FT_X    equ 0
FT_Y    equ 4
FT_Z    equ 8
FT_LIFE equ 12
FT_COL  equ 16
FT_TEXT equ 20  ; 24 chars
FT_SIZE equ 48

section .bss
alignb 16
cars            resb MAX_CARS*C_SIZE
peeps           resb MAX_PEEPS*C_SIZE
parts           resb MAX_PARTS*PT_SIZE
floats          resb MAX_FLOATS*FT_SIZE
car_count       resd 1
peep_count      resd 1
part_next       resd 1
emit_now        resd 1
wind_x          resd 1

section .data
traffic_reps db 0, 1, 2, 6
dir_rev     db 2, 3, 0, 1
peep_cols   db RAMP(R_RED,4), RAMP(R_BLUE,4), RAMP(R_YELLOW,5), RAMP(R_ZONER,4)
            db RAMP(R_PURPLE,4), RAMP(R_WHITE,5), RAMP(R_ORANGE,4), RAMP(R_TEAL,4)
confetti_cols db RAMP(R_RED,5), RAMP(R_YELLOW,6), RAMP(R_BLUE,5), RAMP(R_ZONER,5)
              db RAMP(R_PURPLE,5), RAMP(R_ORANGE,5), RAMP(R_WHITE,7), RAMP(R_GLASS,6)

section .text

FUNC agents_init
    call traffic_init
    lea rdi, [peeps]
    mov ecx, MAX_PEEPS*C_SIZE
    mov al, 255
    rep stosb
    lea rdi, [parts]
    xor eax, eax
    mov ecx, MAX_PARTS*PT_SIZE + MAX_FLOATS*FT_SIZE
    rep stosb
    mov dword [car_count], 0
    mov dword [peep_count], 0
    ; mark every car slot free (type byte = 255 set above)
    RETURN

; ---------------------------------------------------------------------
;  road helpers
; ---------------------------------------------------------------------
; road_sub(edi x, esi y) -> eax mask or -1 when not a road
road_sub:
    call tile_at
    test rax, rax
    jz .no
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .no
    movzx eax, byte [rax+T_SUB]
    ret
.no:
    mov eax, -1
    ret

; choose next direction at tile (edi x, esi y) arriving with dir edx
; -> eax new dir or -1 (dead end handled as u-turn)
FUNC choose_dir
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    call road_sub
    cmp eax, -1
    je .fail
    mov ebx, eax                    ; mask
    ; off-map exits count for highway tiles
    movzx ecx, byte [dir_rev+r14]
    btr ebx, ecx                    ; never reverse unless forced
    test ebx, ebx
    jz .uturn
    ; prefer straight
    bt ebx, r14d
    jnc .pick
    call rand
    and eax, 3
    jz .pick
    mov eax, r14d
    RETURN
.pick:
    call rand
    and eax, 3
    mov ecx, 4
.find:
    bt ebx, eax
    jc .got
    inc eax
    and eax, 3
    dec ecx
    jnz .find
.uturn:
    movzx eax, byte [dir_rev+r14]
    RETURN
.got:
    RETURN
.fail:
    mov eax, -1
    RETURN

; ---------------------------------------------------------------------
;  update all cars (and peeps, which use the same record)
;  update_movers(rdi base, esi count, edx lane offset(1/16 vox), ecx is_peep)
; ---------------------------------------------------------------------
FUNC update_movers, 32
    mov [rbp-48], rdi
    mov [rbp-52], esi
    mov [rbp-56], edx
    mov [rbp-60], ecx
    xor ebx, ebx
.l:
    cmp ebx, [rbp-52]
    jge .out
    mov eax, ebx
    shl eax, 5
    mov r15, [rbp-48]
    add r15, rax
    cmp byte [r15+C_TYPE], 255
    je .n
    dec dword [r15+C_LIFE]
    jle .kill
    ; congestion slows cars
    movzx edi, word [r15+C_TX]
    movzx esi, word [r15+C_TY]
    call tile_at
    test rax, rax
    jz .kill
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .kill
    mov ecx, [r15+C_SPEED]
    cmp dword [rbp-60], 0
    jne .spd
    movzx edx, byte [rax+T_TRAFFIC]
    cmp edx, 140
    jb .spd
    shr ecx, 1
.spd:
    add [r15+C_PROG], ecx
    cmp dword [r15+C_PROG], 256
    jl .pos
    ; advance to next tile
    sub dword [r15+C_PROG], 256
    movzx r12d, word [r15+C_TX]
    movzx r13d, word [r15+C_TY]
    movzx r14d, byte [r15+C_DIR]
    add r12d, [dir_dx+r14*4]
    add r13d, [dir_dy+r14*4]
    cmp r12d, MAP_W
    jae .kill                       ; drove off the map (highway exit)
    cmp r13d, MAP_W
    jae .kill
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    call choose_dir
    cmp eax, -1
    je .kill
    mov [r15+C_DIR], al
    mov [r15+C_TX], r12w
    mov [r15+C_TY], r13w
.pos:
    ; world position: tile centre + (prog-8)*fwd + lane*right
    movzx eax, word [r15+C_TX]
    shl eax, 4
    add eax, 8
    shl eax, 4                      ; fixed
    movzx ecx, word [r15+C_TY]
    shl ecx, 4
    add ecx, 8
    shl ecx, 4
    movzx edx, byte [r15+C_DIR]
    mov r8d, [r15+C_PROG]
    sub r8d, 128                    ; -8..8 voxels (fixed)
    mov r9d, [dir_dx+rdx*4]
    imul r9d, r8d
    add eax, r9d
    mov r9d, [dir_dy+rdx*4]
    imul r9d, r8d
    add ecx, r9d
    ; right-hand lane: right = (-dy, dx)
    mov r10d, [rbp-56]
    mov r9d, [dir_dy+rdx*4]
    neg r9d
    imul r9d, r10d
    add eax, r9d
    mov r9d, [dir_dx+rdx*4]
    imul r9d, r10d
    add ecx, r9d
    mov [r15+C_WX], eax
    mov [r15+C_WY], ecx
    jmp .n
.kill:
    mov byte [r15+C_TYPE], 255
    cmp dword [rbp-60], 0
    jne .kp
    dec dword [car_count]
    jmp .n
.kp:
    dec dword [peep_count]
.n:
    inc ebx
    jmp .l
.out:
    RETURN

; spawn a pedestrian next to a populated building
FUNC peep_spawn
    xor ebx, ebx
.slot:
    cmp ebx, MAX_PEEPS
    jge .out
    mov eax, ebx
    shl eax, 5
    cmp byte [peeps+rax+C_TYPE], 255
    je .have
    inc ebx
    jmp .slot
.have:
    lea r15, [peeps+rax]
    mov ebx, 20
.try:
    call rand
    and eax, MAP_TILES-1
    mov ecx, eax
    shl ecx, TILE_SHIFT
    cmp byte [tiles+rcx+T_OBJ], OBJ_ROAD
    jne .tn
    test byte [tiles+rcx+T_FLAGS], F_HIGHWAY
    jnz .tn
    movzx edx, byte [tiles+rcx+T_TRAFFIC]
    test edx, edx
    jz .tn
    mov r12d, eax
    and r12d, MAP_W-1
    mov r13d, eax
    shr r13d, MAP_SHIFT
    movzx eax, byte [tiles+rcx+T_SUB]
    test eax, eax
    jz .tn
    bsf r14d, eax
    mov [r15+C_TX], r12w
    mov [r15+C_TY], r13w
    mov [r15+C_DIR], r14b
    call rand
    and eax, 255
    mov [r15+C_PROG], eax
    call rand
    and eax, 3
    add eax, 3
    mov [r15+C_SPEED], eax
    call rand
    and eax, 1023
    add eax, 600
    mov [r15+C_LIFE], eax
    call rand
    and eax, 7
    mov [r15+C_COLOR], al
    mov byte [r15+C_TYPE], 0
    call rand
    and eax, 1
    mov [r15+C_FLAGS], al           ; which sidewalk
    inc dword [peep_count]
    jmp .out
.tn:
    dec ebx
    jnz .try
.out:
    RETURN

; ---------------------------------------------------------------------
;  particles
; ---------------------------------------------------------------------
; part_emit(edi x, esi y, edx z (fixed), ecx type)  velocities randomised
FUNC part_emit
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov eax, [part_next]
    inc dword [part_next]
    xor edx, edx
    mov ecx, MAX_PARTS
    div ecx
    mov eax, edx
    shl eax, 5
    lea rbx, [parts+rax]
    mov [rbx+PT_X], r12d
    mov [rbx+PT_Y], r13d
    mov [rbx+PT_Z], r14d
    mov [rbx+PT_TYPE], r15b
    ; random velocity
    call rand
    and eax, 15
    sub eax, 8
    mov [rbx+PT_VX], eax
    call rand
    and eax, 15
    sub eax, 8
    mov [rbx+PT_VY], eax
    mov dword [rbx+PT_VZ], 6
    mov word [rbx+PT_LIFE], 60
    mov byte [rbx+PT_COL], RAMP(R_GREY, 5)
    cmp r15d, PK_SMOKE
    jne .n1
    call rand
    and eax, 63
    add eax, 120
    mov [rbx+PT_LIFE], ax
    mov eax, [wind_x]
    add [rbx+PT_VX], eax
    sub [rbx+PT_VY], eax
    mov dword [rbx+PT_VZ], 5
    call rand
    and eax, 1
    add eax, RAMP(R_GREY, 3)
    mov [rbx+PT_COL], al
    jmp .d
.n1:
    cmp r15d, PK_STEAM
    jne .n2
    call rand
    and eax, 63
    add eax, 100
    mov [rbx+PT_LIFE], ax
    mov dword [rbx+PT_VZ], 7
    mov byte [rbx+PT_COL], RAMP(R_WHITE, 6)
    jmp .d
.n2:
    cmp r15d, PK_DUST
    jne .n3
    mov word [rbx+PT_LIFE], 40
    mov dword [rbx+PT_VZ], 4
    mov byte [rbx+PT_COL], RAMP(R_SAND, 4)
    jmp .d
.n3:
    cmp r15d, PK_SPARK
    jne .n4
    mov word [rbx+PT_LIFE], 45
    call rand
    and eax, 15
    add eax, 14
    mov [rbx+PT_VZ], eax
    mov byte [rbx+PT_COL], RAMP(R_YELLOW, 7)
    jmp .d
.n4:
    cmp r15d, PK_CONFETTI
    jne .n5
    mov word [rbx+PT_LIFE], 150
    call rand
    and eax, 31
    add eax, 20
    mov [rbx+PT_VZ], eax
    call rand
    and eax, 7
    mov al, [confetti_cols+rax]
    mov [rbx+PT_COL], al
    jmp .d
.n5:
    ; ember
    mov word [rbx+PT_LIFE], 50
    call rand
    and eax, 15
    add eax, 8
    mov [rbx+PT_VZ], eax
    mov byte [rbx+PT_COL], RAMP(R_ORANGE, 6)
.d:
    mov ax, [rbx+PT_LIFE]
    mov [rbx+PT_MAX], ax
    RETURN

FUNC parts_update
    xor ebx, ebx
.l:
    mov eax, ebx
    shl eax, 5
    lea r15, [parts+rax]
    cmp word [r15+PT_LIFE], 0
    je .n
    dec word [r15+PT_LIFE]
    mov eax, [r15+PT_VX]
    add [r15+PT_X], eax
    mov eax, [r15+PT_VY]
    add [r15+PT_Y], eax
    mov eax, [r15+PT_VZ]
    add [r15+PT_Z], eax
    movzx eax, byte [r15+PT_TYPE]
    cmp eax, PK_CONFETTI
    je .grav
    cmp eax, PK_SPARK
    je .grav
    cmp eax, PK_EMBER
    je .grav
    ; smoke: slow down horizontally
    mov eax, [r15+PT_VX]
    sar eax, 4
    sub [r15+PT_VX], eax
    jmp .floor
.grav:
    sub dword [r15+PT_VZ], 1
.floor:
    cmp dword [r15+PT_Z], 0
    jge .n
    mov dword [r15+PT_Z], 0
    mov dword [r15+PT_VZ], 0
    mov dword [r15+PT_VX], 0
    mov dword [r15+PT_VY], 0
.n:
    inc ebx
    cmp ebx, MAX_PARTS
    jl .l
    ; floating texts
    xor ebx, ebx
.f:
    mov eax, ebx
    imul eax, FT_SIZE
    lea r15, [floats+rax]
    cmp dword [r15+FT_LIFE], 0
    je .fn
    dec dword [r15+FT_LIFE]
    add dword [r15+FT_Z], 5
.fn:
    inc ebx
    cmp ebx, MAX_FLOATS
    jl .f
    RETURN

; float_text(edi tile x, esi tile y, rdx text, ecx colour)
FUNC float_text
    mov r12d, edi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    xor ebx, ebx
.s:
    cmp ebx, MAX_FLOATS
    jge .out
    mov eax, ebx
    imul eax, FT_SIZE
    lea rax, [floats+rax]
    cmp dword [rax+FT_LIFE], 0
    je .have
    inc ebx
    jmp .s
.have:
    mov rbx, rax
    mov eax, r12d
    shl eax, 8
    add eax, 128
    mov [rbx+FT_X], eax
    mov eax, r13d
    shl eax, 8
    add eax, 128
    mov [rbx+FT_Y], eax
    mov dword [rbx+FT_Z], 16*16
    mov dword [rbx+FT_LIFE], 70
    mov [rbx+FT_COL], r15d
    lea rdi, [rbx+FT_TEXT]
    mov ecx, 23
.cp:
    mov al, [r14]
    mov [rdi], al
    test al, al
    jz .out
    inc r14
    inc rdi
    dec ecx
    jnz .cp
    mov byte [rdi], 0
.out:
    RETURN

; ---------------------------------------------------------------------
;  per-tick agent update
; ---------------------------------------------------------------------
FUNC agents_tick
    ; wind drifts slowly
    mov eax, [anim_tick]
    and eax, 1023
    jnz .w
    call rand
    and eax, 7
    sub eax, 2
    mov [wind_x], eax
.w:
    ; traffic runs on simulation time: more steps at higher speeds
    mov eax, [sim_speed]
    movzx ebx, byte [traffic_reps+rax]
.trep:
    test ebx, ebx
    jz .tdone
    call traffic_tick
    dec ebx
    jmp .trep
.tdone:
    mov eax, [population]
    shr eax, 4
    CLAMP eax, 0, MAX_PEEPS-10
    cmp [peep_count], eax
    jge .nopeep
    call peep_spawn
.nopeep:
    lea rdi, [peeps]
    mov esi, MAX_PEEPS
    mov edx, 13*8
    mov ecx, 1
    call update_movers
    call parts_update
    mov eax, [anim_tick]
    and eax, 7
    sete al
    movzx eax, al
    mov [emit_now], eax
    RETURN

; ---------------------------------------------------------------------
;  drawing
; ---------------------------------------------------------------------
; world_proj(edi x16, esi y16, edx z16) -> eax sx, edx sy, ecx depth
world_proj:
    sar edi, 4
    sar esi, 4
    sar edx, 4
    mov eax, edi
    sub eax, esi
    add eax, ORIGIN_X
    sub eax, [cam_x]
    lea ecx, [rdi+rsi]
    mov r8d, ecx
    sar r8d, 1
    sub r8d, edx
    sub r8d, [cam_y]
    add ecx, edx
    mov edx, r8d
    ret

; depth-tested pixel: (edi x, esi y, edx colour, ecx depth)
zpixel:
    cmp edi, [fb_w]
    jae .o
    cmp esi, [fb_h]
    jae .o
    cmp dword [dl_record], 0
    jne .rec
    mov eax, esi
    imul eax, [fb_w]
    add eax, edi
    cmp cx, [zbuf+rax*2]
    jb .o
    mov [fb+rax], dl
    mov [zbuf+rax*2], cx
    mov cl, [blit_tint]
    mov [tintbuf+rax], cl
.o: ret
.rec:
    ; laying out the frame: a pixel entry in the draw list (id -1)
    mov eax, [dl_n]
    cmp eax, DL_MAX
    jae .o
    inc dword [dl_n]
    shl eax, 5
    mov dword [dl_list+rax], -1
    mov [dl_list+rax+4], edi
    mov [dl_list+rax+8], esi
    mov [dl_list+rax+12], ecx
    mov [dl_list+rax+16], dl
    mov cl, [blit_tint]
    mov [dl_list+rax+24], cl
    ret

FUNC draw_agents, 16
    call draw_vehicles
    call draw_trains
    call draw_planes
    call draw_ships
.peeps:
    xor ebx, ebx
.p:
    cmp ebx, MAX_PEEPS
    jge .parts
    mov eax, ebx
    shl eax, 5
    lea r15, [peeps+rax]
    cmp byte [r15+C_TYPE], 255
    je .pn
    mov edi, [r15+C_WX]
    mov esi, [r15+C_WY]
    ; flip to the other sidewalk
    test byte [r15+C_FLAGS], 1
    jz .ps
    movzx eax, byte [r15+C_DIR]
    mov ecx, [dir_dy+rax*4]
    imul ecx, 13*16
    add edi, ecx
    mov ecx, [dir_dx+rax*4]
    imul ecx, 13*16
    sub esi, ecx
.ps:
    mov edx, 2*16
    call world_proj
    mov r12d, eax
    mov r13d, edx
    mov r14d, ecx
    ; legs (animated), body, head
    mov eax, [anim_tick]
    add eax, ebx
    shr eax, 3
    and eax, 1
    mov [rbp-48], eax
    mov edi, r12d
    add edi, eax
    mov esi, r13d
    mov edx, RAMP(R_ASPHALT, 1)
    mov ecx, r14d
    call zpixel
    mov edi, r12d
    lea esi, [r13-1]
    mov edx, RAMP(R_ASPHALT, 2)
    lea ecx, [r14+1]
    call zpixel
    movzx eax, byte [r15+C_COLOR]
    movzx edx, byte [peep_cols+rax]
    mov [rbp-52], edx
    mov edi, r12d
    lea esi, [r13-2]
    lea ecx, [r14+2]
    call zpixel
    mov edi, r12d
    lea esi, [r13-3]
    mov edx, [rbp-52]
    lea ecx, [r14+3]
    call zpixel
    lea edi, [r12+1]
    lea esi, [r13-2]
    mov edx, [rbp-52]
    lea ecx, [r14+2]
    call zpixel
    mov edi, r12d
    lea esi, [r13-4]
    mov edx, RAMP(R_SKIN, 5)
    lea ecx, [r14+4]
    call zpixel
.pn:
    inc ebx
    jmp .p
.parts:
    xor ebx, ebx
.q:
    cmp ebx, MAX_PARTS
    jge .floats
    mov eax, ebx
    shl eax, 5
    lea r15, [parts+rax]
    movzx eax, word [r15+PT_LIFE]
    test eax, eax
    jz .qn
    mov edi, [r15+PT_X]
    mov esi, [r15+PT_Y]
    mov edx, [r15+PT_Z]
    call world_proj
    mov r12d, eax
    mov r13d, edx
    mov r14d, ecx
    movzx edx, byte [r15+PT_COL]
    movzx eax, byte [r15+PT_TYPE]
    cmp eax, PK_SMOKE
    je .puff
    cmp eax, PK_STEAM
    je .puff
    cmp eax, PK_DUST
    je .puff
    ; single / double pixel particles
    mov edi, r12d
    mov esi, r13d
    mov ecx, r14d
    call zpixel
    movzx eax, byte [r15+PT_TYPE]
    cmp eax, PK_CONFETTI
    jne .qn
    lea edi, [r12+1]
    mov esi, r13d
    movzx edx, byte [r15+PT_COL]
    mov ecx, r14d
    call zpixel
    jmp .qn
.puff:
    ; radius grows with age; dithered so it reads as translucent
    movzx eax, word [r15+PT_MAX]
    movzx ecx, word [r15+PT_LIFE]
    sub eax, ecx                    ; age
    shr eax, 4
    add eax, 1
    CLAMP eax, 1, 5
    mov [rbp-48], eax
    ; fade: fewer pixels near end of life
    movzx ecx, word [r15+PT_LIFE]
    mov [rbp-52], ecx
    mov r10d, eax
    neg r10d                        ; dy
.pdy:
    cmp r10d, [rbp-48]
    jg .qn
    mov r11d, [rbp-48]
    neg r11d
.pdx:
    cmp r11d, [rbp-48]
    jg .pdyn
    ; circle test (x scaled by 2 for iso look)
    mov eax, r11d
    imul eax, eax
    mov ecx, r10d
    imul ecx, ecx
    shl ecx, 2
    add eax, ecx
    mov ecx, [rbp-48]
    imul ecx, ecx
    shl ecx, 1
    cmp eax, ecx
    jg .pdxn
    ; dither
    lea eax, [r12+r11]
    add eax, r13d
    add eax, r10d
    add eax, [anim_tick]
    and eax, 1
    jnz .pdxn
    cmp dword [rbp-52], 20
    jg .pdraw
    lea eax, [r12+r11]
    and eax, 2
    jnz .pdxn
.pdraw:
    push r10
    push r11
    lea edi, [r12+r11]
    lea esi, [r13+r10]
    movzx edx, byte [r15+PT_COL]
    mov ecx, r14d
    call zpixel
    pop r11
    pop r10
.pdxn:
    inc r11d
    jmp .pdx
.pdyn:
    inc r10d
    jmp .pdy
.qn:
    inc ebx
    jmp .q
.floats:
    RETURN

; floating text is drawn on the ui layer (crisper), after projection
FUNC draw_floats
    xor ebx, ebx
.f:
    cmp ebx, MAX_FLOATS
    jge .out
    mov eax, ebx
    imul eax, FT_SIZE
    lea r15, [floats+rax]
    cmp dword [r15+FT_LIFE], 0
    je .n
    mov edi, [r15+FT_X]
    mov esi, [r15+FT_Y]
    mov edx, [r15+FT_Z]
    call world_proj
    ; world fb px -> ui px
    mov r13d, edx
    imul eax, [zoom]
    cdq
    idiv dword [ui_scale]
    mov r12d, eax
    mov eax, r13d
    imul eax, [zoom]
    cdq
    idiv dword [ui_scale]
    mov r13d, eax
    mov edi, r12d
    mov esi, r13d
    lea rdx, [r15+FT_TEXT]
    mov ecx, [r15+FT_COL]
    call draw_text_centered
.n:
    inc ebx
    jmp .f
.out:
    RETURN

; ---------------------------------------------------------------------
;  effects used by the simulation
; ---------------------------------------------------------------------
; burst(edi tx, esi ty, edx count, ecx type, r8d z voxels)
FUNC fx_burst
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    mov ebx, r8d
.l:
    call rand
    and eax, 255
    mov edi, r12d
    shl edi, 8
    add edi, eax
    call rand
    and eax, 255
    mov esi, r13d
    shl esi, 8
    add esi, eax
    mov edx, ebx
    shl edx, 4
    mov ecx, r15d
    call part_emit
    dec r14d
    jnz .l
    RETURN

; is tile (edi,esi) roughly on screen? -> eax 1/0
tile_visible:
    call tile_screen
    cmp eax, -64
    jl .n
    mov ecx, [fb_w]
    add ecx, 64
    cmp eax, ecx
    jg .n
    cmp edx, -64
    jl .n
    mov ecx, [fb_h]
    add ecx, 128
    cmp edx, ecx
    jg .n
    mov eax, 1
    ret
.n: xor eax, eax
    ret

FUNC fx_building_done
    mov r12d, edi
    mov r13d, esi
    call tile_visible
    test eax, eax
    jz .out
    mov edi, r12d
    mov esi, r13d
    mov edx, 10
    mov ecx, PK_SPARK
    mov r8d, 16
    call fx_burst
    mov edi, SFX_POP
    call sfx_play
.out:
    RETURN

FUNC fx_construct_start
    mov r12d, edi
    mov r13d, esi
    call tile_visible
    test eax, eax
    jz .out
    mov edi, r12d
    mov esi, r13d
    mov edx, 6
    mov ecx, PK_DUST
    mov r8d, 1
    call fx_burst
.out:
    RETURN

FUNC fx_smoke_burst
    mov r12d, edi
    mov r13d, esi
    mov edx, 14
    mov ecx, PK_SMOKE
    mov r8d, 4
    call fx_burst
    mov edi, r12d
    mov esi, r13d
    mov edx, 10
    mov ecx, PK_DUST
    mov r8d, 1
    call fx_burst
    mov edi, SFX_CRUMBLE
    call sfx_play
    RETURN

FUNC fx_meteor
    mov r12d, edi
    mov r13d, esi
    mov edx, 40
    mov ecx, PK_EMBER
    mov r8d, 4
    call fx_burst
    mov edi, r12d
    mov esi, r13d
    mov edx, 40
    mov ecx, PK_SMOKE
    mov r8d, 6
    call fx_burst
    mov dword [shake], 40
    mov edi, SFX_BOOM
    call sfx_play
    RETURN

FUNC fx_milestone
    ; confetti over the centre of the view
    mov edi, [fb_w]
    shr edi, 1
    add edi, [cam_x]
    mov esi, [fb_h]
    shr esi, 1
    add esi, [cam_y]
    call world_to_tile
    mov r12d, eax
    mov r13d, edx
    mov ebx, 120
.l:
    mov edi, 12
    call rand_range
    lea r14d, [r12+rax-6]
    mov edi, 12
    call rand_range
    lea r15d, [r13+rax-6]
    mov edi, r14d
    mov esi, r15d
    mov edx, 1
    mov ecx, PK_CONFETTI
    mov r8d, 30
    call fx_burst
    dec ebx
    jnz .l
    mov edi, SFX_FANFARE
    call sfx_play
    RETURN

; money change at month end: remembered for the HUD
fx_month_cash:
    mov [cash_delta], edi
    mov dword [cash_delta_timer], 180
    ret

; ambient emitters for a visible tile (called from the renderer)
; emit_tile(rdi tile, esi x, edx y)
FUNC emit_tile
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    test byte [rbx+T_FLAGS], F_FIRE
    jz .nf
    call rand
    and eax, 1
    jnz .nf
    mov edi, r12d
    mov esi, r13d
    mov edx, 1
    mov ecx, PK_SMOKE
    mov r8d, 14
    call fx_burst
    mov edi, r12d
    mov esi, r13d
    mov edx, 1
    mov ecx, PK_EMBER
    mov r8d, 10
    call fx_burst
.nf:
    movzx eax, byte [rbx+T_OBJ]
    cmp eax, OBJ_ZONEBLD
    je .z
    cmp eax, OBJ_SERVICE
    je .s
    jmp .out
.z:
    cmp byte [rbx+T_ZONE], ZONE_I
    jne .out
    test byte [rbx+T_FLAGS], F_ABANDON | F_BUILD
    jnz .out
    test byte [rbx+T_FLAGS], F_POWER
    jz .out
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .out
    lea rcx, [stack_big]
    cmp byte [rbx+T_SIZE], 2
    je .stacks
    cmp byte [rbx+T_SUB], 0
    jne .spec
    movzx eax, byte [rbx+T_LEVEL]
    CLAMP eax, 0, 5
    lea rcx, [stack_ind+rax*8]
    jmp .stacks
.spec:
    cmp byte [rbx+T_SUB], RES_FOREST
    jne .out
    lea rcx, [stack_mill]
    jmp .stacks
.s:
    test byte [rbx+T_FLAGS], F_ANCHOR
    jz .out
    movzx eax, byte [rbx+T_SUB]
    cmp eax, BK_COAL
    jne .nuc
    lea rcx, [stack_coal]
    jmp .stacks
.nuc:
    cmp eax, BK_INCIN
    jne .nnuc
    lea rcx, [stack_incin]
    jmp .stacks
.nnuc:
    cmp eax, BK_NUCLEAR
    jne .out
    call rand
    and eax, 1
    jnz .out
    ; steam from the cooling tower
    mov edi, r12d
    shl edi, 8
    add edi, 18*16
    mov esi, r13d
    shl esi, 8
    add esi, 18*16
    mov edx, 60*16
    mov ecx, PK_STEAM
    call part_emit
    jmp .out
.stacks:
    ; up to two stacks: lx, ly, z  (bytes) x2, lx=255 terminates
    mov r14, rcx
    xor r15d, r15d
.st:
    movzx eax, byte [r14]
    cmp eax, 255
    je .out
    mov edi, r12d
    shl edi, 8
    shl eax, 4
    add edi, eax
    movzx eax, byte [r14+1]
    mov esi, r13d
    shl esi, 8
    shl eax, 4
    add esi, eax
    movzx edx, byte [r14+2]
    shl edx, 4
    mov ecx, PK_SMOKE
    call part_emit
    add r14, 3
    inc r15d
    cmp r15d, 2
    jl .st
.out:
    RETURN

section .data
; stack tops per industrial level: lx, ly, z  (x2), 255 = none
stack_ind:
    db 255,0,0, 255,0,0, 0,0
    db 255,0,0, 255,0,0, 0,0
    db 13,4,37, 255,0,0, 0,0
    db 2,2,31, 255,0,0, 0,0
    db 4,13,53, 10,13,57, 0,0
    db 255,0,0, 255,0,0, 0,0
stack_coal:
    db 37,23,77, 30,36,71
stack_big:
    db 5,26,64, 13,26,70
stack_mill:
    db 3,3,24, 255,0,0
stack_incin:
    db 27,7,77, 255,0,0
section .bss
cash_delta       resd 1
cash_delta_timer resd 1
section .text
