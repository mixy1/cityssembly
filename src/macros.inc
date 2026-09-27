; =====================================================================
;  CITYSSEMBLY - macros and global constants
; =====================================================================
;  Calling convention: System V AMD64.
;    args   : rdi, rsi, rdx, rcx, r8, r9
;    return : rax
;    saved  : rbx, rbp, r12-r15 (every routine preserves these)
;  FUNC/RETURN build a frame that saves all callee-saved registers and
;  keeps rsp 16-byte aligned so any routine may call into SDL/libc.
; =====================================================================

%macro FUNC 1-2 0
%1:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, ((%2 + 15) & ~15) + 8
%endmacro

%macro RETURN 0
    lea rsp, [rbp-40]
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
%endmacro

; ---------------------------------------------------------------------
;  CALLC fn - call an external C function (SDL / libc).
;  Internal code always uses the System V register order; on Windows
;  the arguments are shuffled into the Win64 ABI (rcx, rdx, r8, r9,
;  stack) with the mandatory 32-byte shadow space.  Up to 6 args.
; ---------------------------------------------------------------------
%macro CALLC 1
%ifdef WIN64
    sub rsp, 48
    mov [rsp+32], r8
    mov [rsp+40], r9
    mov r9, rcx
    mov r8, rdx
    mov rdx, rsi
    mov rcx, rdi
    call %1
    add rsp, 48
%else
    call %1
%endif
%endmacro

; locals for FUNC frames live below the saved registers
%define LOCAL(n) rbp-48-(n)

; clamp register %1 into [%2,%3] (immediates)
%macro CLAMP 3
    cmp %1, %2
    jge %%lo_ok
    mov %1, %2
%%lo_ok:
    cmp %1, %3
    jle %%hi_ok
    mov %1, %3
%%hi_ok:
%endmacro

; ---------------------------------------------------------------------
;  Map
; ---------------------------------------------------------------------
MAP_W        equ 128
MAP_SHIFT    equ 7
MAP_TILES    equ MAP_W*MAP_W
TILE_BYTES   equ 16
TILE_SHIFT   equ 4

; tile record layout
T_TERRAIN    equ 0     ; TER_*
T_ZONE       equ 1     ; ZONE_*
T_OBJ        equ 2     ; OBJ_*
T_SUB        equ 3     ; road mask / building kind
T_LEVEL      equ 4     ; zone building level 0..5
T_FLAGS      equ 5     ; F_*
T_ANCHOR     equ 6     ; dx | dy<<4 offset back to anchor tile
T_TIMER      equ 7     ; construction / burn timer
T_POP        equ 8     ; word: residents or jobs
T_AGE        equ 10
T_SCORE      equ 11    ; last desirability 0..255
T_TRAFFIC    equ 12
T_VARIANT    equ 13
T_HAPPY      equ 14
T_MISC       equ 15

TER_GRASS    equ 0
TER_WATER    equ 1
TER_SAND     equ 2
TER_DIRT     equ 3

ZONE_NONE    equ 0
ZONE_R       equ 1
ZONE_C       equ 2
ZONE_I       equ 3

OBJ_NONE     equ 0
OBJ_TREE     equ 1
OBJ_ROAD     equ 2
OBJ_POWER    equ 3     ; power line
OBJ_ZONEBLD  equ 4     ; grown zone building
OBJ_SERVICE  equ 5     ; placed service building (sub = building kind)
OBJ_RUBBLE   equ 6

F_POWER      equ 1
F_WATER      equ 2
F_FIRE       equ 4
F_ABANDON    equ 8
F_ANCHOR     equ 16
F_ROADOK     equ 32
F_BUILD      equ 64    ; under construction
F_HIGHWAY    equ 128   ; road piece that is part of the regional highway

; ---------------------------------------------------------------------
;  Palette layout
; ---------------------------------------------------------------------
RAMP_BASE    equ 16    ; ramps start here, 8 shades each
RAMP_COUNT   equ 24
PAL_WATER    equ 208   ; 8 animated water colours
PAL_GLOW     equ 216   ; 8 night-glow colours (windows, lamps)
PAL_UI       equ 224   ; 16 ui colours
PAL_HEAT     equ 240   ; 16 heat-map colours

%define RAMP(r,s) (RAMP_BASE + (r)*8 + (s))

R_GREY       equ 0
R_ASPHALT    equ 1
R_GRASS      equ 2
R_LEAF       equ 3
R_SAND       equ 4
R_WOOD       equ 5
R_BRICK      equ 6
R_ROOF       equ 7
R_BLUE       equ 8
R_GLASS      equ 9
R_YELLOW     equ 10
R_ORANGE     equ 11
R_PURPLE     equ 12
R_CREAM      equ 13
R_WHITE      equ 14
R_DEEPWATER  equ 15
R_TEAL       equ 16
R_OLIVE      equ 17
R_SKIN       equ 18
R_ZONER      equ 19
R_ZONEC      equ 20
R_ZONEI      equ 21
R_LEAF2      equ 22
R_RED        equ 23

; UI palette indices (UI layer, never tinted)
UI_BG        equ PAL_UI+0   ; translucent panel
UI_BG2       equ PAL_UI+1   ; darker translucent
UI_EDGE_HI   equ PAL_UI+2
UI_EDGE_LO   equ PAL_UI+3
UI_TEXT      equ PAL_UI+4
UI_DIM       equ PAL_UI+5
UI_ACCENT    equ PAL_UI+6
UI_GOOD      equ PAL_UI+7
UI_BAD       equ PAL_UI+8
UI_WARN      equ PAL_UI+9
UI_SHADOW    equ PAL_UI+10
UI_BTN       equ PAL_UI+11
UI_BTN_HI    equ PAL_UI+12
UI_BTN_SEL   equ PAL_UI+13
UI_GOLD      equ PAL_UI+14
UI_BLACK     equ PAL_UI+15
