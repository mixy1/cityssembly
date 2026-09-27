; =====================================================================
;  VIDEO - window, textures, 8bpp -> ARGB conversion, screenshots
;
;  Two 8-bit layers are composed each frame:
;    fb    : the world, drawn at (window / zoom) resolution
;    uifb  : the interface, drawn at (window / ui_scale) resolution
;  Each layer is expanded through its own 256-entry ARGB lookup table
;  (lut_world gets day/night + season tinting, lut_ui carries alpha).
; =====================================================================

MAX_FB_W equ 3840
MAX_FB_H equ 2160

section .data
str_title       db "CITYSSEMBLY", 0
str_hint_scale  db "SDL_RENDER_SCALE_QUALITY", 0
str_hint_vsync  db "SDL_RENDER_VSYNC", 0
str_zero        db "0", 0
str_one         db "1", 0
str_wb          db "wb", 0
str_rb          db "rb", 0
str_sdlfail     db "SDL error: %s", 10, 0

section .bss
alignb 16
fb              resb MAX_FB_W*MAX_FB_H
alignb 16
uifb            resb MAX_FB_W*MAX_FB_H
alignb 16
zbuf            resw MAX_FB_W*MAX_FB_H
alignb 16
shotbuf         resd MAX_FB_W*MAX_FB_H

window          resq 1
renderer        resq 1
tex_world       resq 1
tex_ui          resq 1
tex_pixels      resq 1
tex_pitch       resd 1
win_w           resd 1
win_h           resd 1
zoom            resd 1
ui_scale        resd 1
fb_w            resd 1
fb_h            resd 1
ui_w            resd 1
ui_h            resd 1
fullscreen      resd 1
alignb 16
lut_world       resd 256
lut_ui          resd 256
dst_rect        resd 4

section .text

; ---------------------------------------------------------------------
sdl_fail:
    CALLC SDL_GetError
    mov rsi, rax
    lea rdi, [str_sdlfail]
    xor eax, eax
    CALLC printf
    mov edi, 1
    CALLC exit

; ---------------------------------------------------------------------
FUNC video_init
    mov edi, SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER
    CALLC SDL_Init
    test eax, eax
    jnz sdl_fail
    lea rdi, [str_hint_scale]
    lea rsi, [str_zero]
    CALLC SDL_SetHint

    lea rdi, [str_title]
    mov esi, SDL_WINDOWPOS_CENTERED
    mov edx, SDL_WINDOWPOS_CENTERED
    mov ecx, 1280
    mov r8d, 720
    mov r9d, SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE
    CALLC SDL_CreateWindow
    test rax, rax
    jz sdl_fail
    mov [window], rax

    mov rdi, rax
    mov esi, -1
    mov edx, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC
    CALLC SDL_CreateRenderer
    test rax, rax
    jnz .have_r
    mov rdi, [window]
    mov esi, -1
    xor edx, edx
    CALLC SDL_CreateRenderer
    test rax, rax
    jz sdl_fail
.have_r:
    mov [renderer], rax
    xor edi, edi
    CALLC SDL_ShowCursor
    mov dword [zoom], 2
    call video_resize
    RETURN

; ---------------------------------------------------------------------
;  (Re)create textures to match the window size, zoom and ui scale.
; ---------------------------------------------------------------------
FUNC video_resize
    mov rdi, [window]
    lea rsi, [win_w]
    lea rdx, [win_h]
    CALLC SDL_GetWindowSize

    ; world framebuffer
    mov eax, [win_w]
    add eax, [zoom]
    dec eax
    xor edx, edx
    div dword [zoom]
    CLAMP eax, 64, MAX_FB_W
    mov [fb_w], eax
    mov eax, [win_h]
    add eax, [zoom]
    dec eax
    xor edx, edx
    div dword [zoom]
    CLAMP eax, 64, MAX_FB_H
    mov [fb_h], eax

    ; ui scale: aim for ~360 logical lines, but keep >= 620 columns
    mov eax, [win_h]
    xor edx, edx
    mov ecx, 360
    div ecx
    CLAMP eax, 1, 6
.shrink:
    cmp eax, 1
    jle .scale_ok
    mov ecx, eax
    mov eax, [win_w]
    xor edx, edx
    div ecx
    cmp eax, 620
    mov eax, ecx
    jge .scale_ok
    dec eax
    jmp .shrink
.scale_ok:
    mov [ui_scale], eax
    mov ecx, eax
    mov eax, [win_w]
    add eax, ecx
    dec eax
    xor edx, edx
    div ecx
    CLAMP eax, 64, MAX_FB_W
    mov [ui_w], eax
    mov eax, [win_h]
    add eax, ecx
    dec eax
    xor edx, edx
    div ecx
    CLAMP eax, 64, MAX_FB_H
    mov [ui_h], eax

    mov rdi, [tex_world]
    test rdi, rdi
    jz .no_tw
    CALLC SDL_DestroyTexture
.no_tw:
    mov rdi, [tex_ui]
    test rdi, rdi
    jz .no_tu
    CALLC SDL_DestroyTexture
.no_tu:
    mov rdi, [renderer]
    mov esi, SDL_PIXELFORMAT_ARGB8888
    mov edx, SDL_TEXTUREACCESS_STREAMING
    mov ecx, [fb_w]
    mov r8d, [fb_h]
    CALLC SDL_CreateTexture
    test rax, rax
    jz sdl_fail
    mov [tex_world], rax

    mov rdi, [renderer]
    mov esi, SDL_PIXELFORMAT_ARGB8888
    mov edx, SDL_TEXTUREACCESS_STREAMING
    mov ecx, [ui_w]
    mov r8d, [ui_h]
    CALLC SDL_CreateTexture
    test rax, rax
    jz sdl_fail
    mov [tex_ui], rax
    mov rdi, rax
    mov esi, SDL_BLENDMODE_BLEND
    CALLC SDL_SetTextureBlendMode
    RETURN

; ---------------------------------------------------------------------
;  expand8: rdi = src 8bpp, esi = w, edx = h, rcx = lut
;  writes into [tex_pixels] with pitch [tex_pitch]
; ---------------------------------------------------------------------
expand8:
    push rbx
    push r12
    mov r8, [tex_pixels]
    movsxd r9, dword [tex_pitch]
    mov r10d, esi
.row:
    mov r11, r8
    mov ebx, r10d
.px4:
    cmp ebx, 4
    jl .px1
    movzx eax, byte [rdi]
    movzx r12d, byte [rdi+1]
    mov eax, [rcx+rax*4]
    mov r12d, [rcx+r12*4]
    mov [r11], eax
    mov [r11+4], r12d
    movzx eax, byte [rdi+2]
    movzx r12d, byte [rdi+3]
    mov eax, [rcx+rax*4]
    mov r12d, [rcx+r12*4]
    mov [r11+8], eax
    mov [r11+12], r12d
    add rdi, 4
    add r11, 16
    sub ebx, 4
    jmp .px4
.px1:
    test ebx, ebx
    jz .rowdone
    movzx eax, byte [rdi]
    mov eax, [rcx+rax*4]
    mov [r11], eax
    inc rdi
    add r11, 4
    dec ebx
    jmp .px1
.rowdone:
    add r8, r9
    dec edx
    jnz .row
    pop r12
    pop rbx
    ret

; ---------------------------------------------------------------------
FUNC video_present
    ; world layer
    mov rdi, [tex_world]
    xor esi, esi
    lea rdx, [tex_pixels]
    lea rcx, [tex_pitch]
    CALLC SDL_LockTexture
    test eax, eax
    jnz .skip_w
    lea rdi, [fb]
    mov esi, [fb_w]
    mov edx, [fb_h]
    lea rcx, [lut_world]
    call expand8
    mov rdi, [tex_world]
    CALLC SDL_UnlockTexture
.skip_w:
    ; ui layer
    mov rdi, [tex_ui]
    xor esi, esi
    lea rdx, [tex_pixels]
    lea rcx, [tex_pitch]
    CALLC SDL_LockTexture
    test eax, eax
    jnz .skip_u
    lea rdi, [uifb]
    mov esi, [ui_w]
    mov edx, [ui_h]
    lea rcx, [lut_ui]
    call expand8
    mov rdi, [tex_ui]
    CALLC SDL_UnlockTexture
.skip_u:
    mov dword [dst_rect], 0
    mov dword [dst_rect+4], 0
    mov eax, [fb_w]
    imul eax, [zoom]
    mov [dst_rect+8], eax
    mov eax, [fb_h]
    imul eax, [zoom]
    mov [dst_rect+12], eax
    mov rdi, [renderer]
    mov rsi, [tex_world]
    xor edx, edx
    lea rcx, [dst_rect]
    CALLC SDL_RenderCopy

    mov eax, [ui_w]
    imul eax, [ui_scale]
    mov [dst_rect+8], eax
    mov eax, [ui_h]
    imul eax, [ui_scale]
    mov [dst_rect+12], eax
    mov rdi, [renderer]
    mov rsi, [tex_ui]
    xor edx, edx
    lea rcx, [dst_rect]
    CALLC SDL_RenderCopy

    mov rdi, [renderer]
    CALLC SDL_RenderPresent
    RETURN

; ---------------------------------------------------------------------
;  video_screenshot(rdi = filename)
;  composes both layers at window resolution and writes a BMP
; ---------------------------------------------------------------------
FUNC video_screenshot
    mov [rbp-48], rdi
    lea rdi, [shotbuf]
    xor r12d, r12d                 ; y
.y:
    cmp r12d, [win_h]
    jge .done
    ; world row pointer
    mov eax, r12d
    xor edx, edx
    div dword [zoom]
    imul eax, [fb_w]
    lea r13, [fb+rax]
    mov eax, r12d
    xor edx, edx
    div dword [ui_scale]
    imul eax, [ui_w]
    lea r14, [uifb+rax]
    xor r15d, r15d                 ; x
.x:
    cmp r15d, [win_w]
    jge .ynext
    mov eax, r15d
    xor edx, edx
    div dword [zoom]
    movzx eax, byte [r13+rax]
    mov ebx, [lut_world+rax*4]
    mov eax, r15d
    xor edx, edx
    div dword [ui_scale]
    movzx eax, byte [r14+rax]
    mov ecx, [lut_ui+rax*4]
    ; blend ecx (argb) over ebx
    mov r8d, ecx
    shr r8d, 24                    ; alpha
    mov r9d, 256
    sub r9d, r8d                   ; inverse
    xor r10d, r10d                 ; result
    mov r11d, 0                    ; shift
%macro BLENDCH 1
    mov eax, ecx
    shr eax, %1
    and eax, 255
    imul eax, r8d
    mov edx, ebx
    shr edx, %1
    and edx, 255
    imul edx, r9d
    add eax, edx
    shr eax, 8
    shl eax, %1
    or r10d, eax
%endmacro
    BLENDCH 0
    BLENDCH 8
    BLENDCH 16
    or r10d, 0xFF000000
    mov [rdi], r10d
    add rdi, 4
    inc r15d
    jmp .x
.ynext:
    inc r12d
    jmp .y
.done:
    lea rdi, [shotbuf]
    mov esi, [win_w]
    mov edx, [win_h]
    mov ecx, 32
    mov r8d, [win_w]
    shl r8d, 2
    mov r9d, SDL_PIXELFORMAT_ARGB8888
    CALLC SDL_CreateRGBSurfaceWithFormatFrom
    test rax, rax
    jz .out
    mov r12, rax
    mov rdi, [rbp-48]
    lea rsi, [str_wb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz .free
    mov rdi, r12
    mov rsi, rax
    mov edx, 1
    CALLC SDL_SaveBMP_RW
.free:
    mov rdi, r12
    CALLC SDL_FreeSurface
.out:
    RETURN

; ---------------------------------------------------------------------
;  set zoom (edi = 1..4), keep the world point under screen centre fixed
; ---------------------------------------------------------------------
FUNC video_set_zoom
    CLAMP edi, 1, 4
    cmp edi, [zoom]
    je .same
    mov r12d, edi
    ; centre in world coords before
    mov eax, [fb_w]
    shr eax, 1
    add eax, [cam_x]
    mov r13d, eax
    mov eax, [fb_h]
    shr eax, 1
    add eax, [cam_y]
    mov r14d, eax
    mov [zoom], r12d
    call video_resize
    mov eax, [fb_w]
    shr eax, 1
    mov ecx, r13d
    sub ecx, eax
    mov [cam_x], ecx
    mov eax, [fb_h]
    shr eax, 1
    mov ecx, r14d
    sub ecx, eax
    mov [cam_y], ecx
.same:
    RETURN

FUNC video_toggle_fullscreen
    xor dword [fullscreen], 1
    mov rdi, [window]
    xor esi, esi
    cmp dword [fullscreen], 0
    je .set
    mov esi, SDL_WINDOW_FULLSCREEN_DESKTOP
.set:
    CALLC SDL_SetWindowFullscreen
    call video_resize
    RETURN
