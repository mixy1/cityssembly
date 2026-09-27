; =====================================================================
;  CITYSSEMBLY
;  An isometric city builder written in x86-64 assembly.
;  SDL2 is used only for the window, input and the audio device;
;  rendering, sprite generation, simulation, audio synthesis, music
;  composition and UI are all hand-written here.
;
;  command line:
;     cityssembly                      play
;     cityssembly --shot N file.bmp    render N frames, save a screenshot
;     cityssembly --demo N file.bmp    auto-build a town, simulate, shoot
; =====================================================================

%include "macros.inc"
%include "sdl.inc"

global main

section .bss
running         resd 1
frame_count     resd 1
shot_frames     resd 1
shot_file       resq 1
demo_mode       resd 1
demo_view       resd 1
wav_seconds     resd 1
event_buf       resb 64
last_ticks      resd 1
tick_accum      resd 1
cam_x           resd 1
cam_y           resd 1
text_input_active resd 1
rmb_down        resd 1
rmb_moved       resd 1

section .data
str_shot_flag   db "--shot", 0
str_demo_flag   db "--demo", 0
str_wav_flag    db "--wav", 0
wav_header:
    db "RIFF"
    dd 0
    db "WAVEfmt "
    dd 16
    dw 1, 2
    dd 44100, 44100*4
    dw 4, 16
    db "data"
    dd 0

section .text

%ifdef WIN64
; Win64 entry: translate args; preserve rdi/rsi/xmm6-15 (callee-saved)
main:
    push rsi
    push rdi
    sub rsp, 168
    movdqu [rsp], xmm6
    movdqu [rsp+16], xmm7
    movdqu [rsp+32], xmm8
    movdqu [rsp+48], xmm9
    movdqu [rsp+64], xmm10
    movdqu [rsp+80], xmm11
    movdqu [rsp+96], xmm12
    movdqu [rsp+112], xmm13
    movdqu [rsp+128], xmm14
    movdqu [rsp+144], xmm15
    mov edi, ecx
    mov rsi, rdx
    call cmain
    movdqu xmm6, [rsp]
    movdqu xmm7, [rsp+16]
    movdqu xmm8, [rsp+32]
    movdqu xmm9, [rsp+48]
    movdqu xmm10, [rsp+64]
    movdqu xmm11, [rsp+80]
    movdqu xmm12, [rsp+96]
    movdqu xmm13, [rsp+112]
    movdqu xmm14, [rsp+128]
    movdqu xmm15, [rsp+144]
    add rsp, 168
    pop rdi
    pop rsi
    ret
FUNC cmain
%else
FUNC main
%endif
    mov r12d, edi                   ; argc
    mov r13, rsi                    ; argv
    cmp r12d, 4
    jl .noargs
    mov rdi, [r13+8]
    lea rsi, [str_wav_flag]
    CALLC strcmp
    test eax, eax
    jnz .notwav
    mov rdi, [r13+16]
    CALLC atoi
    mov [wav_seconds], eax
    mov rax, [r13+24]
    mov [shot_file], rax
    jmp .noargs
.notwav:
    mov rdi, [r13+8]
    lea rsi, [str_demo_flag]
    CALLC strcmp
    test eax, eax
    jnz .notdemo
    mov dword [demo_mode], 1
    cmp r12d, 5
    jl .shotargs
    mov rax, [r13+32]
    movzx eax, byte [rax]
    mov [demo_view], eax
    jmp .shotargs
.notdemo:
    mov rdi, [r13+8]
    lea rsi, [str_shot_flag]
    CALLC strcmp
    test eax, eax
    jnz .noargs
.shotargs:
    mov rdi, [r13+16]
    CALLC atoi
    mov [shot_frames], eax
    mov rax, [r13+24]
    mov [shot_file], rax
.noargs:
    call video_init
    call palette_init
    call font_init
    mov dword [world_seed], 1234567
    cmp dword [shot_frames], 0
    jne .fixed
    CALLC SDL_GetPerformanceCounter
    mov [world_seed], eax
.fixed:
    call sprites_init
    call audio_init
    call ui_init
    call world_generate
    call sim_init
    call agents_init
    mov rax, [money]
    mov [money_shown], rax
    mov edi, 30
    mov esi, [hwy_row]
    call camera_center_tile
    cmp dword [wav_seconds], 0
    je .nowav
    call wav_dump
    jmp .quit
.nowav:
    cmp dword [demo_mode], 0
    je .nodemo
    call demo_build
.nodemo:
    CALLC SDL_GetTicks
    mov [last_ticks], eax

    mov dword [running], 1
.loop:
    call poll_events
    cmp dword [running], 0
    je .quit

    ; fixed 60 Hz simulation steps
    CALLC SDL_GetTicks
    mov ecx, eax
    sub eax, [last_ticks]
    mov [last_ticks], ecx
    CLAMP eax, 0, 250
    imul eax, 60
    add [tick_accum], eax
    cmp dword [shot_frames], 0
    je .steps
    mov dword [tick_accum], 1000    ; screenshot mode: exactly 1 tick/frame
.steps:
    cmp dword [tick_accum], 1000
    jl .render
    sub dword [tick_accum], 1000
    call game_tick
    jmp .steps
.render:
    call update_hover
    call palette_update
    ; screen shake
    mov r14d, [cam_x]
    mov r15d, [cam_y]
    mov eax, [shake]
    test eax, eax
    jz .ns
    dec dword [shake]
    shr eax, 2
    inc eax
    lea edi, [rax*2+1]
    call rand_range
    mov ecx, [shake]
    shr ecx, 3
    sub eax, ecx
    add [cam_x], eax
    mov edi, 5
    call rand_range
    sub eax, 2
    add [cam_y], eax
.ns:
    call render_world
    mov dword [emit_now], 0
    call draw_agents
    call render_ui
    call draw_tool_preview
    call world_input
    mov [cam_x], r14d
    mov [cam_y], r15d
    call video_present
    call audio_update
    inc dword [frame_count]

    mov eax, [shot_frames]
    test eax, eax
    jz .loop
    cmp [frame_count], eax
    jl .loop
    mov rdi, [shot_file]
    call video_screenshot
.quit:
    CALLC SDL_Quit
    xor eax, eax
    RETURN

; ---------------------------------------------------------------------
FUNC game_tick
    inc dword [anim_tick]
    call camera_update
    cmp dword [welcome], 0
    jne .nosim
    call sim_tick
.nosim:
    call agents_tick
    cmp dword [tod_lock], 0
    jne .t
    add dword [tod], 9
    and dword [tod], 0xFFFF
.t:
    inc dword [water_phase]
    ; season follows the calendar (spring starts in March)
    mov eax, [month]
    add eax, 10
    xor edx, edx
    mov ecx, 12
    div ecx
    imul eax, edx, 30
    add eax, [day]
    shl eax, 10
    xor edx, edx
    mov ecx, 360
    div ecx
    mov [season_pos], eax
    RETURN

; ---------------------------------------------------------------------
FUNC poll_events
.next:
    lea rdi, [event_buf]
    CALLC SDL_PollEvent
    test eax, eax
    jz .done
    mov eax, [event_buf+EV_TYPE]
    cmp eax, SDL_QUIT
    jne .nq
    mov dword [running], 0
    jmp .next
.nq:
    cmp eax, SDL_WINDOWEVENT
    jne .nw
    movzx eax, byte [event_buf+EV_WIN_EVENT]
    cmp eax, SDL_WINDOWEVENT_SIZE_CHANGED
    jne .next
    call video_resize
    jmp .next
.nw:
    cmp eax, SDL_MOUSEMOTION
    jne .nm
    mov ecx, [event_buf+EV_MM_X]
    mov [mouse_x], ecx
    mov ecx, [event_buf+EV_MM_Y]
    mov [mouse_y], ecx
    cmp dword [rmb_down], 0
    je .next
    ; drag-pan
    mov dword [rmb_moved], 1
    mov eax, [event_buf+28]
    cdq
    idiv dword [zoom]
    sub [cam_x], eax
    mov eax, [event_buf+32]
    cdq
    idiv dword [zoom]
    sub [cam_y], eax
    call camera_clamp
    jmp .next
.nm:
    cmp eax, SDL_MOUSEBUTTONDOWN
    jne .nbd
    movzx eax, byte [event_buf+EV_MB_BUTTON]
    cmp eax, 1
    jne .nl
    mov dword [click_pending], 1
    mov dword [lmb_down], 1
    jmp .next
.nl:
    cmp eax, 3
    je .rd
    cmp eax, 2
    jne .next
.rd:
    mov dword [rmb_down], 1
    mov dword [rmb_moved], 0
    jmp .next
.nbd:
    cmp eax, SDL_MOUSEBUTTONUP
    jne .nbu
    movzx eax, byte [event_buf+EV_MB_BUTTON]
    cmp eax, 1
    jne .nl2
    mov dword [release_pending], 1
    mov dword [lmb_down], 0
    jmp .next
.nl2:
    cmp eax, 3
    je .ru
    cmp eax, 2
    jne .next
.ru:
    mov dword [rmb_down], 0
    ; a right click without dragging cancels the current action
    cmp dword [rmb_moved], 0
    jne .next
    cmp dword [drag_active], 0
    je .rc2
    mov dword [drag_active], 0
    jmp .next
.rc2:
    mov dword [tool], T_INSPECT
    mov dword [submenu], -1
    jmp .next
.nbu:
    cmp eax, SDL_MOUSEWHEEL
    jne .nwh
    mov eax, [event_buf+EV_MW_Y]
    mov edi, [zoom]
    test eax, eax
    jz .next
    jg .zin
    dec edi
    jmp .zset
.zin:
    inc edi
.zset:
    call video_set_zoom
    call camera_clamp
    jmp .next
.nwh:
    cmp eax, SDL_KEYDOWN
    jne .next
    cmp byte [event_buf+EV_KEY_REPEAT], 0
    jne .next
    mov edi, [event_buf+EV_KEY_SCAN]
    call ui_key
    jmp .next
.done:
    RETURN

; ---------------------------------------------------------------------
;  demo: lay out a small town next to the highway and fast-forward
; ---------------------------------------------------------------------
FUNC demo_build, 16
    mov dword [welcome], 0
    mov qword [money], 200000
    mov r12d, [hwy_row]
    ; main street continuing the highway east, cross streets every 7
    mov ebx, 22
.ms:
    mov edi, ebx
    mov esi, r12d
    call demo_road
    inc ebx
    cmp ebx, 52
    jl .ms
    mov ebx, 24
.cs:
    mov r13d, -12
.csy:
    mov edi, ebx
    lea esi, [r12+r13]
    call demo_road
    inc r13d
    cmp r13d, 13
    jl .csy
    add ebx, 7
    cmp ebx, 52
    jl .cs
    ; parallel streets
    mov r13d, -12
.ps:
    mov ebx, 24
.psx:
    mov edi, ebx
    lea esi, [r12+r13]
    call demo_road
    inc ebx
    cmp ebx, 46
    jl .psx
    add r13d, 6
    cmp r13d, 13
    jl .ps
    call roads_update_all
    ; zones: residential north, commercial along main, industry south
    mov r13d, -11
.zy:
    mov ebx, 25
.zx:
    mov edi, ebx
    lea esi, [r12+r13]
    call tile_at
    test rax, rax
    jz .zn
    cmp byte [rax+T_OBJ], OBJ_NONE
    je .zok
    cmp byte [rax+T_OBJ], OBJ_TREE
    jne .zn
.zok:
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .zn
    mov byte [rax+T_OBJ], OBJ_NONE
    mov cl, ZONE_R
    cmp r13d, -1
    jl .zset
    mov cl, ZONE_C
    cmp r13d, 1
    jle .zset
    mov cl, ZONE_I
    cmp r13d, 7
    jge .zset
    mov cl, ZONE_R
.zset:
    mov [rax+T_ZONE], cl
.zn:
    inc ebx
    cmp ebx, 45
    jl .zx
    inc r13d
    cmp r13d, 12
    jl .zy
    ; services
    mov edi, BK_COAL
    mov esi, 46
    lea edx, [r12+8]
    call demo_place
    mov edi, BK_WTOWER
    mov esi, 46
    lea edx, [r12-3]
    call demo_place
    mov edi, BK_WTOWER
    mov esi, 46
    lea edx, [r12-4]
    call demo_place
    mov edi, BK_WTOWER
    mov esi, 46
    lea edx, [r12-5]
    call demo_place
    mov edi, BK_POLICE
    mov esi, 18
    lea edx, [r12-6]
    call demo_place
    mov edi, BK_FIRE
    mov esi, 18
    lea edx, [r12+3]
    call demo_place
    mov edi, BK_CLINIC
    mov esi, 20
    lea edx, [r12-2]
    call demo_place
    mov edi, BK_SCHOOL
    mov esi, 18
    lea edx, [r12-10]
    call demo_place
    mov edi, BK_PARK
    mov esi, 21
    lea edx, [r12-2]
    call demo_place
    mov edi, BK_WIND
    mov esi, 46
    lea edx, [r12+12]
    call demo_place
    ; fast-forward
    mov dword [sim_speed], 1
    mov ebx, 700
.ff:
    call sim_day
    dec ebx
    jnz .ff
    mov rax, [money]
    mov [money_shown], rax
    mov edi, 34
    mov esi, r12d
    call camera_center_tile
    ; optional view for screenshots
    mov eax, [demo_view]
    cmp eax, 'b'
    jne .v1
    mov dword [panel], PANEL_BUDGET
.v1:
    cmp eax, 'm'
    jne .v2
    mov dword [panel], PANEL_MENU
.v2:
    cmp eax, 'o'
    jne .v3
    mov dword [overlay_mode], OV_LANDVAL
.v3:
    cmp eax, 'n'
    jne .v4
    mov dword [tod], 10*256
.v4:
    cmp eax, 'i'
    jne .v5
    mov dword [sel_x], 28
    mov ecx, r12d
    sub ecx, 4
    mov [sel_y], ecx
.v5:
    cmp eax, 's'
    jne .v6
    mov dword [submenu], 5
    mov dword [submenu_x], 400
.v6:
    cmp eax, 'p'
    jne .v7
    mov dword [overlay_mode], OV_POWER
.v7:
    cmp eax, 'l'
    jne .v8
    ; save, wipe with a new city, load back
    call save_city
    call new_city
    mov dword [welcome], 0
    call load_city
    mov edi, 34
    mov esi, [hwy_row]
    call camera_center_tile
.v8:
    cmp eax, 't'
    jne .v9
    ; exercise the drag tools the way a mouse release does
    mov dword [drag_active], 1
    mov dword [tool], T_ROAD
    mov dword [drag_sx], 52
    mov [drag_sy], r12d
    mov dword [hover_tx], 60
    lea eax, [r12-8]
    mov [hover_ty], eax
    mov dword [hover_valid], 1
    call tool_collect
    call tool_apply
    mov dword [tool], T_ZONE_R
    mov dword [drag_sx], 53
    lea eax, [r12-7]
    mov [drag_sy], eax
    mov dword [hover_tx], 59
    lea eax, [r12-1]
    mov [hover_ty], eax
    call tool_collect
    call tool_apply
    mov dword [tool], T_BULLDOZE
    mov dword [drag_sx], 30
    lea eax, [r12-11]
    mov [drag_sy], eax
    mov dword [hover_tx], 36
    lea eax, [r12-8]
    mov [hover_ty], eax
    call tool_collect
    call tool_apply
    mov dword [tool], T_TREE
    mov dword [drag_sx], 53
    lea eax, [r12+2]
    mov [drag_sy], eax
    mov dword [hover_tx], 58
    lea eax, [r12+5]
    mov [hover_ty], eax
    call tool_collect
    call tool_apply
    mov dword [tool], T_POWERLN
    mov dword [drag_sx], 61
    lea eax, [r12-8]
    mov [drag_sy], eax
    mov dword [hover_tx], 61
    lea eax, [r12+4]
    mov [hover_ty], eax
    call tool_collect
    call tool_apply
    mov dword [drag_active], 0
    mov dword [tool], T_INSPECT
    mov edi, 50
    mov esi, [hwy_row]
    call camera_center_tile
.v9:
    RETURN

; offline render of the soundtrack into a wav (for testing)
FUNC wav_dump
    mov rdi, [shot_file]
    lea rsi, [str_wb]
    CALLC SDL_RWFromFile
    test rax, rax
    jz .out
    mov r12, rax
    mov eax, [wav_seconds]
    imul eax, 44100*4
    mov [wav_header+40], eax
    add eax, 36
    mov [wav_header+4], eax
    mov rdi, r12
    lea rsi, [wav_header]
    mov edx, 44
    mov ecx, 1
    CALLC SDL_RWwrite
    mov dword [population], 1500    ; a mid-size town band
    mov dword [welcome], 0
    mov eax, [wav_seconds]
    imul eax, 44100/CHUNK
    mov ebx, eax
.l:
    mov rax, [audio_time]
    add rax, SR/2
    cmp rax, [mus_next_bar]
    jl .nb
    call compose_bar
.nb:
    ; a few sound effects along the way
    mov rax, [audio_time]
    and eax, 0x7FFFF
    cmp eax, CHUNK
    jae .nsfx
    mov edi, SFX_COIN
    call sfx_play
.nsfx:
    ; drift through day and night
    add dword [tod], 60
    and dword [tod], 0xFFFF
    mov rdi, [audio_time]
    add rdi, CHUNK
    call ev_fire
    call mix_chunk
    add qword [audio_time], CHUNK
    mov rdi, r12
    lea rsi, [mixbuf]
    mov edx, CHUNK*4
    mov ecx, 1
    CALLC SDL_RWwrite
    dec ebx
    jnz .l
    mov rdi, r12
    CALLC SDL_RWclose
.out:
    RETURN

; demo_road(edi x, esi y)
FUNC demo_road
    call tile_at
    test rax, rax
    jz .o
    mov byte [rax+T_OBJ], OBJ_ROAD
    mov byte [rax+T_ZONE], 0
.o:
    RETURN

; demo_place(edi kind, esi x, edx y)
FUNC demo_place
    mov [build_kind], edi
    mov dword [tool], T_BUILD
    mov dword [tl_n], 1
    mov [tl_x], esi
    mov [tl_y], edx
    call tool_evaluate
    call tool_apply
    mov dword [tool], T_INSPECT
    RETURN

%ifndef WIN64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif

%include "video.asm"
%include "palette.asm"
%include "draw.asm"
%include "font.asm"
%include "world.asm"
%include "voxel.asm"
%include "buildings.asm"
%include "sprites.asm"
%include "render.asm"
%include "sim.asm"
%include "agents.asm"
%include "audio.asm"
%include "ui.asm"
