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

section .data
; tint colours (r,g,b,0) indexed by TINT_*
tint_rgb:
    dd 0
    dd 0x1E328C, 0x1E50AA, 0x1E78BE, 0x1EA0B4, 0x28B48C, 0x3CBE5A, 0x64C83C, 0x96D232
    dd 0xC8D232, 0xE6BE28, 0xF0A028, 0xF0781E, 0xE6501E, 0xD2321E, 0xB41E1E, 0x8C141E
    dd 0xFFD23C, 0x3C96FF, 0xF03228, 0x50E6FF, 0x969696, 0x96642A, 0x50DC5A
    dd 0xFF8C1E, 0xFF50DC, 0, 0, 0, 0, 0, 0
init_w          dd 1280
init_h          dd 720

section .bss
alignb 16
fb              resb MAX_FB_W*MAX_FB_H
alignb 16
uifb            resb MAX_FB_W*MAX_FB_H
alignb 16
zbuf            resw MAX_FB_W*MAX_FB_H
alignb 16
shotbuf         resd MAX_FB_W*MAX_FB_H
alignb 16
tintbuf         resb MAX_FB_W*MAX_FB_H
blit_tint       resd 1

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
    mov ecx, [init_w]
    mov r8d, [init_h]
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

; copy_lit: litbuf rows -> [tex_pixels] (esi = w, edx = h)
copy_lit:
    push rbx
    mov r8, [tex_pixels]
    movsxd r9, dword [tex_pitch]
    lea r10, [litbuf]
    mov ebx, edx
.r:
    mov rdi, r8
    mov rsi, r10
    mov ecx, [fb_w]
    rep movsd
    mov r10, rsi
    add r8, r9
    dec ebx
    jnz .r
    pop rbx
    ret

; ---------------------------------------------------------------------
;  tint_px(ebx argb, ecx tint) -> ebx: info-view colouring that keeps
;  the picture underneath readable (shading survives the blend)
; ---------------------------------------------------------------------
tint_px:
    cmp ecx, TINT_KEEP
    je .o
    push rdx
    push rsi
    push r8
    ; luminance
    mov eax, ebx
    shr eax, 16
    and eax, 255
    imul eax, 77
    mov edx, ebx
    shr edx, 8
    and edx, 255
    imul edx, 150
    add eax, edx
    mov edx, ebx
    and edx, 255
    imul edx, 29
    add eax, edx
    shr eax, 8                      ; lum 0..255
    mov esi, eax
    test ecx, ecx
    jnz .tint
    ; untinted: desaturate and darken a little
    xor r8d, r8d
%macro DIMCH 1
    mov eax, ebx
    shr eax, %1
    and eax, 255
    imul eax, 150
    lea edx, [rsi+rsi*2]
    shl edx, 5                      ; lum*96
    add eax, edx
    shr eax, 8
    imul eax, 190
    shr eax, 8
    shl eax, %1
    or r8d, eax
%endmacro
    DIMCH 0
    DIMCH 8
    DIMCH 16
    mov ebx, r8d
    jmp .d
.tint:
    mov r9d, [tint_rgb+rcx*4]
    lea esi, [rsi+256]
    shr esi, 1                      ; 128..255 light factor
    xor r8d, r8d
%macro TINTCH 1
    mov eax, r9d
    shr eax, %1
    and eax, 255
    imul eax, esi
    shr eax, 8                      ; lit tint
    imul eax, 128
    mov edx, ebx
    shr edx, %1
    and edx, 255
    imul edx, 128
    add eax, edx
    shr eax, 8
    shl eax, %1
    or r8d, eax
%endmacro
    TINTCH 0
    TINTCH 8
    TINTCH 16
    mov ebx, r8d
.d:
    or ebx, 0xFF000000
    pop r8
    pop rsi
    pop rdx
.o: ret

; expand the world layer through the tint buffer (info view on)
; rdi = src 8bpp, esi = w, edx = h, rcx = lut
expand8_tint:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r8, [tex_pixels]
    movsxd r15, dword [tex_pitch]
    mov r14, rcx
    mov r13d, esi
    mov r12d, edx
.row:
    mov r11, r8
    xor r10d, r10d
.px:
    lea rax, [fb]
    mov rbx, rdi
    sub rbx, rax
    mov ebx, [litbuf+rbx*4]
    movzx ecx, byte [rdi+(tintbuf-fb)]
    call tint_px
    mov [r11], ebx
    inc rdi
    add r11, 4
    inc r10d
    cmp r10d, r13d
    jl .px
    add r8, r15
    dec r12d
    jnz .row
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ---------------------------------------------------------------------
FUNC video_present
    call light_compose
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
    cmp dword [eff_overlay], 0
    je .plain
    call expand8_tint
    jmp .expd
.plain:
    call copy_lit
.expd:
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
    call compose_frame
    jmp save_shot

; compose both layers at window resolution into shotbuf
FUNC compose_frame
    call light_compose
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
    movzx ecx, byte [r13+rax+(tintbuf-fb)]
    lea rdx, [fb]
    mov rbx, r13
    sub rbx, rdx
    add rbx, rax
    mov ebx, [litbuf+rbx*4]
    cmp dword [eff_overlay], 0
    je .nt
    call tint_px
.nt:
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
    RETURN

; (continuation of video_screenshot: [rbp-48] = file name)
save_shot:
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

; zoom (edi) keeping the world point under the mouse where it is
FUNC zoom_at_cursor
    CLAMP edi, 1, 4
    cmp edi, [zoom]
    je .out
    mov r12d, edi
    mov eax, [mouse_x]
    xor edx, edx
    div dword [zoom]
    add eax, [cam_x]
    mov r13d, eax                   ; world x under the mouse
    mov eax, [mouse_y]
    xor edx, edx
    div dword [zoom]
    add eax, [cam_y]
    mov r14d, eax
    mov edi, r12d
    call video_set_zoom
    mov eax, [mouse_x]
    xor edx, edx
    div dword [zoom]
    mov ecx, r13d
    sub ecx, eax
    mov [cam_x], ecx
    mov eax, [mouse_y]
    xor edx, edx
    div dword [zoom]
    mov ecx, r14d
    sub ecx, eax
    mov [cam_y], ecx
    call camera_clamp
.out:
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
