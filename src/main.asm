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
sandbox         resd 1
beta_on         resd 1          ; ?beta / --beta: features still in testing
key_mod         resd 1          ; modifiers of the last key press
mouse_inside    resd 1          ; demo / trailer: whole map is yours
demo_view       resd 1
demo_no_ff      resd 1
trailer_mode    resd 1
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
str_beta_flag   db "--beta", 0
str_beta_env    db "CS_BETA", 0
str_bench_env   db "CS_BENCH", 0
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
%ifndef WEB
    ; --beta anywhere on the line (or CS_BETA=1): the features in testing
    mov ebx, 1
.beta:
    cmp ebx, r12d
    jge .betae
    mov rdi, [r13+rbx*8]
    lea rsi, [str_beta_flag]
    CALLC strcmp
    test eax, eax
    jnz .betan
    mov dword [beta_on], 1
.betan:
    inc ebx
    jmp .beta
.betae:
    lea rdi, [str_beta_env]
    CALLC getenv
    test rax, rax
    jz .nbenv
    mov dword [beta_on], 1
.nbenv:
    lea rdi, [str_bench_env]
    CALLC getenv
    test rax, rax
    jz .nbench
    mov dword [perf_on], 1
.nbench:
%endif
    cmp r12d, 3
    jl .noargs
%ifndef WEB
    mov rdi, [r13+8]
    lea rsi, [str_trailer_flag]
    CALLC strcmp
    test eax, eax
    jnz .nottrailer
    mov dword [trailer_mode], 1
    mov rax, [r13+16]
    mov [shot_file], rax
    mov dword [shot_frames], 1          ; fixed seed
    mov dword [init_w], 960
    mov dword [init_h], 540
    ; --trailer out.raw plan.bin [W H]
    cmp r12d, 4
    jl .noargs
    mov rax, [r13+24]
    mov [tr_plan_file], rax
    cmp r12d, 6
    jl .noargs
    mov rdi, [r13+32]
    CALLC atoi
    mov [init_w], eax
    mov rdi, [r13+40]
    CALLC atoi
    mov [init_h], eax
    jmp .noargs
.nottrailer:
    ; --tourbot FRAMES out.bmp [seed]: play the tour by its highlights
    mov rdi, [r13+8]
    lea rsi, [str_tourbot]
    CALLC strcmp
    test eax, eax
    jnz .nottb
    mov dword [bot_on], 1
    mov rdi, [r13+16]
    CALLC atoi
    mov [shot_frames], eax
    mov rax, [r13+24]
    mov [shot_file], rax
    cmp r12d, 5
    jl .noargs
    mov rdi, [r13+32]
    CALLC atoi
    mov [bot_seed], eax
    jmp .noargs
.nottb:
    ; --play SCRIPT: a scripted player for tests (src/script.asm)
    mov rdi, [r13+8]
    lea rsi, [str_play_flag]
    CALLC strcmp
    test eax, eax
    jnz .notplay
    mov dword [play_on], 1
    mov rax, [r13+16]
    mov [play_file], rax
    mov dword [shot_frames], 100000000  ; one tick a frame, fixed seed
    mov dword [init_w], 1920            ; room to drag away from the ui
    mov dword [init_h], 1080
    call play_load
    jmp .noargs
.notplay:
%endif
    mov rdi, [r13+8]
    lea rsi, [str_wav_flag]
    CALLC strcmp
    test eax, eax
    jnz .notwav
    cmp r12d, 4
    jl .noargs
    mov rdi, [r13+16]
    CALLC atoi
    mov [wav_seconds], eax
    mov rax, [r13+24]
    mov [shot_file], rax
    ; optional: pin the music style (0..4) for listening tests
    cmp r12d, 5
    jl .noargs
    mov rdi, [r13+32]
    CALLC atoi
    mov [force_style], eax
    ; and optionally solo one instrument (mixing tests)
    cmp r12d, 6
    jl .noargs
    mov rdi, [r13+40]
    CALLC atoi
    mov [solo_inst], eax
    jmp .noargs
.notwav:
    cmp r12d, 4
    jl .noargs
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
%ifdef WEB
    ; the browser window decides the canvas size
    call web_setup
    mov [init_w], eax
    shr rax, 32
    mov [init_h], eax
%endif
    call video_init
    mov dword [mouse_inside], 1
    call palette_init
    call font_init
    mov dword [world_seed], 1234567
    cmp dword [shot_frames], 0
    jne .fixed
    cmp dword [wav_seconds], 0      ; audio renders are reproducible too
    jne .fixed
    CALLC SDL_GetPerformanceCounter
    mov [world_seed], eax
.fixed:
%ifndef WEB
    mov eax, [bot_seed]
    test eax, eax
    jz .nbs
    mov [world_seed], eax
.nbs:
%endif
    call sprites_init
    call light_init
    call threads_init
    call audio_init
    call ui_init
    call settings_load
    call check_saves
    ; a city is saved: start in the load picker (not in test modes)
    cmp dword [has_save], 0
    je .nopick
    mov eax, [demo_mode]
    or eax, [trailer_mode]
    or eax, [wav_seconds]
    jnz .nopick
    mov dword [slots_start], 1
    mov dword [welcome], 0
    call open_load_panel
.nopick:
    ; demo and trailer worlds skip land plots and the starter creek
    mov eax, [trailer_mode]
    or eax, [demo_mode]
    cmp dword [demo_view], 'T'
    je .sbx0
    cmp dword [demo_view], 'L'
    je .sbx0
    cmp dword [demo_view], 'Z'
    je .sbx0
    cmp dword [demo_view], 'l'
    je .sbx0
    cmp dword [demo_view], 'r'
    je .sbx0
    cmp dword [demo_view], 'R'
    je .sbx0
    cmp dword [demo_view], 'W'
    je .sbx0
    cmp dword [demo_view], 'U'
    je .sbx0
    cmp dword [demo_view], 'N'
    je .sbx0
    cmp dword [demo_view], 'G'
    jne .sbx
.sbx0:
    xor eax, eax
.sbx:
    mov [sandbox], eax
    call world_generate
    call sim_init
    call agents_init
    mov rax, [money]
    mov [money_shown], rax
    mov edi, 38
    cmp dword [sandbox], 0
    je .cam
    mov edi, 30
.cam:
    mov esi, [hwy_row]
    call camera_center_tile
%ifdef WEB
    call web_beta
    mov [beta_on], eax
    call web_bench
    mov [perf_on], eax
    ; a city opened by link (?load=...): straight into it
    call web_open
    test rax, rax
    jz .noopen
    mov rdi, rax
    call load_city_from
    mov dword [welcome], 0
.noopen:
%endif
%ifndef WEB
    cmp dword [trailer_mode], 0
    je .notr
    call trailer_run
    jmp .quit
.notr:
%endif
    cmp dword [wav_seconds], 0
    je .nowav
    call wav_dump
    jmp .quit
.nowav:
    cmp dword [demo_mode], 0
    je .nodemo
    cmp dword [demo_view], 'T'
    jne .ld
    call playtest_build
    jmp .nodemo
.ld:
    cmp dword [demo_view], 'A'
    jne .lda
    mov edi, ZONE_R
    call pt_gallery
    jmp .nodemo
.lda:
    cmp dword [demo_view], 'H'
    jne .ldh
    mov edi, ZONE_RH
    call pt_gallery
    jmp .nodemo
.ldh:
    cmp dword [demo_view], 'l'
    je .ldl
    cmp dword [demo_view], 'r'
    jne .ldl0
.ldl:
    call load_city
    mov dword [welcome], 0
    mov dword [tool], T_INSPECT
    mov dword [mouse_x], 1275
    mov dword [mouse_y], 400
    mov dword [sel_x], -1
    mov edi, 34
    mov esi, 64
    call camera_center_tile
    cmp dword [demo_view], 'r'
    jne .nodemo
    mov dword [sel_x], 30
    mov dword [sel_y], 64
    jmp .nodemo
.ldl0:
    cmp dword [demo_view], 'm'
    jne .ldm
    call pt_minimap_loop_setup
    jmp .nodemo
.ldm:
    cmp dword [demo_view], 'Z'
    jne .ldz
    call pt_undo_test
    jmp .nodemo
.ldz:
    mov eax, [demo_view]
    cmp eax, 'R'
    je .ex
    cmp eax, 'U'
    je .ex
    cmp eax, 'N'
    je .ex
    cmp eax, 'G'
    je .ex
    cmp eax, 'W'                    ; long run of the unchanged city
    jne .ld0
    mov dword [pt_ticks], 3500
    mov dword [demo_view], 'R'
.ex:
    call load_city
    mov dword [welcome], 0
    call pt_plots
    mov eax, [demo_view]
    cmp eax, 'R'
    jne .exu
    ; paint the plan: avenue runs cyan, north link pink
    mov dword [plan_mark], 1
    mov edi, 12
    call pt_upgrade_runs
    mov ecx, 18
.pl:
    mov eax, ecx
    shl eax, MAP_SHIFT
    add eax, 44
    mov byte [plan_map+rax], 2
    inc ecx
    cmp ecx, 48
    jl .pl
    jmp .exr
.exu:
    mov edi, 12
    call pt_upgrade_runs
    cmp dword [demo_view], 'N'
    jne .exg
    call pt_north_link
.exg:
    cmp dword [demo_view], 'G'
    jne .exr
    or dword [policies], P_RECYCLE
.exr:
    call pt_traffic
    jmp .nodemo
.ld0:
    cmp dword [demo_view], 'M'
    jne .ld1
    call pt_minimap_test
    jmp .nodemo
.ld1:
    cmp dword [demo_view], 'D'
    jne .ld2
    call pt_dock_test
    jmp .nodemo
.ld2:
    cmp dword [demo_view], 'L'
    jne .realdemo
    call load_city
    call pt_diagnose
    call pt_diag_view
    mov dword [welcome], 0
    jmp .nodemo
.realdemo:
    call demo_build
.nodemo:
    CALLC SDL_GetTicks
    mov [last_ticks], eax

    mov dword [running], 1
.loop:
    PERF_MARK -1
%ifndef WEB
    call tut_bot
    call play_tick
%endif
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
    PERF_MARK 0                     ; simulation
    call update_hover
    call palette_update
    ; screen shake: offset the camera for this frame only.  Only the
    ; offset is taken back afterwards - restoring the old position would
    ; throw away camera moves made while drawing (minimap clicks,
    ; notification jumps)
    xor r14d, r14d
    xor r15d, r15d
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
    mov r14d, eax
    add [cam_x], eax
    mov edi, 5
    call rand_range
    sub eax, 2
    mov r15d, eax
    add [cam_y], eax
.ns:
    PERF_MARK 1                     ; palette etc.
    call render_world               ; (the agents are drawn with it)
    PERF_MARK 2
    mov dword [emit_now], 0
    PERF_MARK 3
    call render_ui
    call draw_tool_preview
    call world_input
    PERF_MARK 4
    sub [cam_x], r14d
    sub [cam_y], r15d
    call video_present              ; (marks 5: lighting, 6: upload)
%ifndef WEB
    call tut_bot_after
    call play_after
%endif
    PERF_MARK 6
    call audio_update
    PERF_MARK 7
    inc dword [frame_count]
    call perf_report

    mov eax, [shot_frames]
    test eax, eax
    jz .loop
    cmp [frame_count], eax
    jl .loop
    mov rdi, [shot_file]
    call video_screenshot
    cmp dword [demo_view], 'm'
    jne .quit
    call pt_minimap_loop_report
.quit:
    CALLC SDL_Quit
    xor eax, eax
    RETURN

; ---------------------------------------------------------------------
;  frame profile: ?bench in the browser prints where the time goes
; ---------------------------------------------------------------------
FUNC perf_report
    cmp dword [perf_on], 0
    je .out
    ; this frame's times into the totals, and the slowest frame's
    xor ecx, ecx
.f:
    mov rax, [perf_cur+rcx*8]
    add [perf_acc+rcx*8], rax
    cmp rax, [perf_max+rcx*8]
    jbe .fm
    mov [perf_max+rcx*8], rax
.fm:
    mov qword [perf_cur+rcx*8], 0
    inc ecx
    cmp ecx, 32
    jl .f
    inc dword [perf_n]
    cmp dword [perf_n], 120
    jl .out
    ; buckets 30 and 31 count route searches and heap pops
    mov rax, [perf_acc+30*8]
    xor edx, edx
    mov ecx, 120
    div rcx
    mov [perf_calls], eax
    mov rax, [perf_acc+31*8]
    xor edx, edx
    div rcx
    mov [perf_pops], eax
    CALLC SDL_GetPerformanceFrequency
    mov rbx, rax
    xor ecx, ecx
.c:
    mov rax, [perf_acc+rcx*8]
    imul rax, rax, 10000
    xor edx, edx
    div rbx
    xor edx, edx
    mov r8d, 120
    div r8                          ; 0.1 ms units per frame
    mov [perf_out+rcx*4], eax
    mov qword [perf_acc+rcx*8], 0
    mov rax, [perf_max+rcx*8]
    imul rax, rax, 10000
    xor edx, edx
    div rbx
    mov [perf_mx+rcx*4], eax
    mov qword [perf_max+rcx*8], 0
    inc ecx
    cmp ecx, 32
    jl .c
    mov dword [perf_n], 0
    lea rdi, [str_perf]
    mov esi, [perf_out]
    mov edx, [perf_out+4]
    add edx, [perf_out+8]
    mov ecx, [perf_out+12]
    mov r8d, [perf_out+16]
    mov r9d, [perf_out+20]
    sub rsp, 8
    mov eax, [perf_out+28]
    push rax
    mov eax, [perf_out+24]
    push rax
    mov eax, [perf_out+36]
    push rax
    mov eax, [perf_out+32]
    push rax
    xor eax, eax
%ifndef WIN64
    call printf
%endif
    add rsp, 40
    ; the world and the light passes, step by step
    lea rdi, [str_perf2]
    mov esi, [perf_out+40]
    mov edx, [perf_out+44]
    mov ecx, [perf_out+48]
    mov r8d, [perf_out+52]
    mov r9d, [perf_out+56]
    sub rsp, 8
    mov eax, [perf_out+64]
    push rax
    mov eax, [perf_out+60]
    push rax
    xor eax, eax
%ifndef WIN64
    call printf
%endif
    add rsp, 24
    lea rdi, [str_perf3]
    mov esi, [perf_out+68]
    mov edx, [perf_out+72]
    mov ecx, [perf_out+40]
    mov r8d, [zoom]
    mov r9d, [fb_w]
    sub rsp, 8
    push qword [population]
    push qword [fb_h]
    xor eax, eax
%ifndef WIN64
    call printf
%endif
    add rsp, 24
    ; the simulation day, part by part (slowest frame of each)
    lea rdi, [str_perfday]
    mov esi, [perf_mx+80]
    mov edx, [perf_mx+84]
    mov ecx, [perf_mx+88]
    mov r8d, [perf_mx+92]
    mov r9d, [perf_mx+96]
    sub rsp, 8
    push qword [perf_mx+104]
    push qword [perf_mx+100]
    xor eax, eax
%ifndef WIN64
    call printf
%endif
    add rsp, 24
    ; the slowest frame of each part
    lea rdi, [str_perfmx]
    mov esi, [perf_mx]
    mov edx, [perf_mx+68]
    add edx, [perf_mx+72]
    add edx, [perf_mx+40]
    mov ecx, [perf_mx+44]
    mov r8d, [perf_mx+52]
    mov r9d, [perf_mx+60]
    sub rsp, 8
    mov eax, [perf_mx+28]
    push rax
    mov eax, [perf_mx+16]
    push rax
    mov eax, [perf_mx+12]
    push rax
    xor eax, eax
%ifndef WIN64
    call printf
%endif
    add rsp, 32
    ; traffic: trips, moving, route finding (its calls and heap pops per
    ; frame), the vehicles
    lea rdi, [str_perftr]
    mov esi, [perf_out+27*4]
    mov edx, [perf_out+28*4]
    mov ecx, [perf_out+29*4]
    mov r8d, [perf_calls]
    mov r9d, [perf_pops]
    sub rsp, 8
    push qword [veh_count]
    xor eax, eax
%ifndef WIN64
    call printf
%endif
    add rsp, 16
.out:
    RETURN

section .data
str_perftr db "PERFTRAFFIC x0.1ms trips %d move %d routes %d | routes/frame %d pops/frame %d vehicles %d", 10, 0
str_perf2 db "PERF2 world: list %d bands %d pipes %d | light: prep %d lut %d rows %d bloom %d", 10, 0
str_perf3 db "PERF3 list: tiles %d wires %d agents %d | zoom %d world %dx%d pop %d", 10, 0
str_perfday db "PERFDAY max x0.1ms tiles %d zones %d networks %d coverage %d stats %d dispatch %d goals+month %d", 10, 0
str_perfmx db "PERFMAX sim %d list %d bands %d prep %d rows %d | ui %d tex %d audio %d", 10, 0
str_perf db "PERF x0.1ms sim %d world %d agents %d ui %d light %d | tex world %d ui %d | present %d audio %d", 10, 0
section .bss
perf_on     resd 1
perf_n      resd 1
perf_t      resq 1
perf_acc    resq 32
perf_cur    resq 32
perf_max    resq 32
perf_mx     resd 32
perf_out    resd 32
perf_calls  resd 1
perf_pops   resd 1
section .text

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
    cmp eax, SDL_WINDOWEVENT_ENTER
    jne .we1
    mov dword [mouse_inside], 1
    jmp .next
.we1:
    cmp eax, SDL_WINDOWEVENT_LEAVE
    jne .we2
    mov dword [mouse_inside], 0
    jmp .next
.we2:
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
    ; then closes things one at a time: inspector, panel, menu, tool
    cmp dword [sel_x], 0
    jl .rc3
    mov dword [sel_x], -1
    jmp .next
.rc3:
    cmp dword [panel], PANEL_NONE
    je .rc4
    mov dword [panel], PANEL_NONE
    jmp .next
.rc4:
    cmp dword [submenu], -1
    je .rc5
    mov dword [submenu], -1
    jmp .next
.rc5:
    mov dword [tool], T_INSPECT
    jmp .next
.nbu:
    cmp eax, SDL_MOUSEWHEEL
    jne .nwh
    ; beta: Ctrl+wheel sizes the grid of the road tool
    call grid_wheel
    test eax, eax
    jnz .next
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
    call zoom_at_cursor
    jmp .next
.nwh:
    cmp eax, SDL_KEYDOWN
    jne .next
    cmp byte [event_buf+EV_KEY_REPEAT], 0
    jne .next
    movzx eax, word [event_buf+EV_KEY_MOD]
    mov [key_mod], eax
    mov edi, [event_buf+EV_KEY_SCAN]
    call ui_key
    jmp .next
.done:
    RETURN

; ---------------------------------------------------------------------
;  demo: lay out a town next to the highway and fast-forward
; ---------------------------------------------------------------------
FUNC demo_build, 16
    mov dword [welcome], 0
    mov qword [money], 400000
    mov r12d, [hwy_row]
    ; avenue continuing the highway
    mov ebx, 22
.ms:
    mov edi, ebx
    mov esi, r12d
    mov edx, RT_AVENUE
    call demo_road
    inc ebx
    cmp ebx, 60
    jl .ms
    ; service street and cross streets
    mov ebx, 22
.cs:
    mov r13d, -14
.csy:
    mov edi, ebx
    lea esi, [r12+r13]
    mov edx, RT_STREET
    call demo_road
    inc r13d
    cmp r13d, 15
    jl .csy
    add ebx, 4
    cmp ebx, 26
    jl .cs
    mov ebx, 26
.cs2:
    mov r13d, -14
.cs2y:
    mov edi, ebx
    lea esi, [r12+r13]
    mov edx, RT_STREET
    call demo_road
    inc r13d
    cmp r13d, 15
    jl .cs2y
    add ebx, 7
    cmp ebx, 55
    jl .cs2
    mov r13d, -14
.ps:
    cmp r13d, 0
    je .psn
    mov ebx, 22
.psx:
    mov edi, ebx
    lea esi, [r12+r13]
    mov edx, RT_STREET
    call demo_road
    inc ebx
    cmp ebx, 55
    jl .psx
.psn:
    add r13d, 7
    cmp r13d, 15
    jl .ps
    ; north highway link down to the town
    mov r13d, 18
.nh:
    mov edi, 44
    mov esi, r13d
    mov edx, RT_HIGHWAY
    call demo_road
    inc r13d
    lea eax, [r12-14]
    cmp r13d, eax
    jl .nh
    call roads_update_all
    ; zones
    mov r13d, -13
.zy:
    mov ebx, 27
.zx:
    mov edi, ebx
    lea esi, [r12+r13]
    call tile_at
    test rax, rax
    jz .zn
    mov cl, [rax+T_OBJ]
    cmp cl, OBJ_NONE
    je .zok
    cmp cl, OBJ_TREE
    jne .zn
.zok:
    cmp byte [rax+T_TERRAIN], TER_WATER
    je .zn
    mov byte [rax+T_OBJ], OBJ_NONE
    ; north: homes (dense to the east), middle: shops / offices,
    ; south: shops + dense homes, far south: industry
    mov cl, ZONE_R
    cmp r13d, -7
    jl .zr
    mov cl, ZONE_CH
    cmp ebx, 40
    jl .zm
    mov cl, ZONE_O
.zm:
    cmp r13d, 0
    jl .zset
    mov cl, ZONE_C
    cmp ebx, 40
    jl .zc
    mov cl, ZONE_RH
.zc:
    cmp r13d, 7
    jl .zset
    mov cl, ZONE_I
    jmp .zset
.zr:
    cmp ebx, 40
    jl .zset
    mov cl, ZONE_RH
.zset:
    mov [rax+T_ZONE], cl
.zn:
    inc ebx
    cmp ebx, 54
    jl .zx
    inc r13d
    cmp r13d, 14
    jl .zy
    ; services along the service street and the east side
%macro DPLACE 3
    mov edi, %1
    mov esi, %2
    lea edx, [r12+%3]
    call demo_force
%endmacro
    DPLACE BK_BUSDEPOT, 24, -12
    DPLACE BK_HIGH, 24, -9
    DPLACE BK_CLINIC, 25, -6
    DPLACE BK_POLICE, 24, -4
    DPLACE BK_PARK, 25, -2
    DPLACE BK_FIRE, 24, 2
    DPLACE BK_ELEM, 25, 5
    DPLACE BK_LANDFILL, 24, 8
    DPLACE BK_WTOWER, 55, -3
    DPLACE BK_WTOWER, 55, -4
    DPLACE BK_WTOWER, 55, -5
    DPLACE BK_WTOWER, 55, -6
    DPLACE BK_WTOWER, 55, -7
    DPLACE BK_WTOWER, 55, -9
    DPLACE BK_WTOWER, 55, -10
    DPLACE BK_WTOWER, 55, -11
    DPLACE BK_SEWAGE, 55, 3
    DPLACE BK_SEWAGE, 55, 4
    DPLACE BK_WIND, 55, 2
    DPLACE BK_COAL, 56, 8
    DPLACE BK_COAL, 56, 11
    DPLACE BK_WTOWER, 55, -12
    DPLACE BK_WTOWER, 55, -13
    DPLACE BK_WTOWER, 56, -3
    DPLACE BK_WTOWER, 56, -4
    DPLACE BK_WTOWER, 56, -5
    DPLACE BK_WTOWER, 56, -6
    ; power line down the east edge links the plants to the city
    mov edi, 57
    lea esi, [r12-13]
    mov edx, 57
    lea ecx, [r12+13]
    call demo_pline
    call roads_update_all
    ; bus stops
    mov edi, 30
    mov esi, r12d
    call demo_stop
    mov edi, 44
    mov esi, r12d
    call demo_stop
    mov edi, 33
    lea esi, [r12-10]
    call demo_stop
    mov edi, 47
    lea esi, [r12+10]
    call demo_stop
    mov dword [net_dirty], 1
    call networks_update
    call coverage_update
    call stats_update
    cmp dword [demo_no_ff], 0
    jne .noff
    ; fast-forward: full ticks so traffic and deliveries run too
    mov dword [sim_speed], 3
    mov ebx, 700*5
.ff:
    call sim_tick
    call agents_tick
    inc dword [anim_tick]
    dec ebx
    jnz .ff
    mov dword [sim_speed], 1
    mov rax, [money]
    mov [money_shown], rax
    mov edi, 38
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
    mov dword [panel], PANEL_STATS
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
    mov dword [sel_x], 44
    lea ecx, [r12-3]
    mov [sel_y], ecx
.v5:
    cmp eax, 's'
    jne .v6
    mov dword [submenu], 3
    mov dword [submenu_x], 300
.v6:
    cmp eax, 'p'
    jne .v7
    mov dword [tool], T_POWERLN
.v7:
    cmp eax, 'w'
    jne .v8
    mov dword [tool], T_PIPE
.v8:
    cmp eax, 't'
    jne .v9
    mov dword [overlay_mode], OV_TRAFFIC
.v9:
    cmp eax, 'y'
    jne .v10
    mov dword [panel], PANEL_POLICIES
.v10:
    cmp eax, 'z'
    jne .v11
    mov dword [tool], T_ZONETOOL
    mov dword [zone_type], ZONE_RH
.v11:
    cmp eax, 'q'
    jne .v12
    mov edi, 3
    call video_set_zoom
    mov edi, 57
    mov esi, r12d
    call camera_center_tile
.v12:
    cmp eax, 'Q'
    jne .v13
    mov edi, 3
    call video_set_zoom
    mov edi, 57
    mov esi, r12d
    call camera_center_tile
    mov dword [tool], T_POWERLN
.v13:
    cmp eax, 'F'
    jne .v14
    mov dword [tool], T_BUILD
    mov dword [build_kind], BK_POLICE
    mov dword [hover_valid], 1
    mov dword [hover_tx], 40
    lea ecx, [r12+4]
    mov [hover_ty], ecx
.v14:
    cmp eax, 'I'
    jne .v15
    ; inspect the first building with a problem
    xor ecx, ecx
.fi:
    cmp ecx, MAP_TILES
    jge .v15
    mov edx, ecx
    shl edx, TILE_SHIFT
    cmp byte [tiles+rdx+T_PROBLEM], 0
    je .fin
    test byte [tiles+rdx+T_FLAGS], F_ANCHOR
    jz .fin
    mov edx, ecx
    and edx, MAP_W-1
    mov [sel_x], edx
    shr ecx, MAP_SHIFT
    mov [sel_y], ecx
    mov edi, edx
    mov esi, ecx
    call camera_center_tile
    jmp .v15
.fin:
    inc ecx
    jmp .fi
.v15:
    cmp eax, 'e'
    jne .v16
    mov dword [panel], PANEL_SETTINGS
.v16:
    cmp eax, 'k'
    jne .vtut
    ; the tour at step (frames - 1), frozen for screenshots
    mov eax, [shot_frames]
    dec eax
    mov [tut_step], eax
    mov dword [tut_freeze], 1
    mov dword [sel_x], -1
.vtut:
    cmp eax, 'j'
    jne .vj
    call open_load_panel
.vj:
    cmp eax, 'J'
    jne .vJ
    call open_save_panel
    mov dword [slot_confirm], 1
.vJ:
    cmp eax, 'X'
    jne .v17
    mov dword [tool], T_ROAD
    mov dword [mouse_x], 700
    mov dword [mouse_y], 330
.v17:
    cmp eax, 'Y'
    jne .v18
    mov dword [tool], T_ROAD
    mov dword [mouse_x], 700
    mov dword [mouse_y], 330
    mov dword [set_xray], 0
.v18:
    cmp eax, 'u'
    jne .v19
    mov dword [tool], T_UPGRADE
    ; point at a straight north-south street near the middle
    lea r13d, [r12-10]
.us:
    mov r14d, 28
.ux:
    mov edi, r14d
    mov esi, r13d
    call tile_at
    cmp byte [rax+T_OBJ], OBJ_ROAD
    jne .un
    cmp byte [rax+T_ROADTYPE], RT_STREET
    jne .un
    cmp byte [rax+T_SUB], 5
    je .uf
.un:
    inc r14d
    cmp r14d, 44
    jl .ux
    inc r13d
    jmp .us
.uf:
    mov edi, r14d
    mov esi, r13d
    call tile_screen
    imul eax, [zoom]
    imul edx, [zoom]
    add edx, 8
    mov [mouse_x], eax
    mov [mouse_y], edx
.v19:
.noff:
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
    ; render at a fixed reference level, no launch fade
    mov dword [set_music], 75
    mov dword [set_sfx], 30
    mov dword [music_fade], 256
    call apply_volumes
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
    ; a few sound effects along the way (not in pinned-style listening tests)
    cmp dword [force_style], 0
    jge .nsfx
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

; demo_road(edi x, esi y, edx type): road with a pipe underneath
FUNC demo_road
    mov ebx, edx
    call tile_at
    test rax, rax
    jz .o
    mov byte [rax+T_OBJ], OBJ_ROAD
    mov byte [rax+T_ZONE], 0
    mov [rax+T_ROADTYPE], bl
    or byte [rax+T_FLAGS2], F2_PIPE
.o:
    RETURN

; demo_pline(edi x0, esi y0, edx x1, ecx y1): drag the power line tool
FUNC demo_pline
    mov dword [tool], T_POWERLN
    mov [drag_sx], edi
    mov [drag_sy], esi
    mov [hover_tx], edx
    mov [hover_ty], ecx
    mov dword [hover_valid], 1
    mov dword [drag_active], 1
    call tool_collect
    call tool_apply
    mov dword [drag_active], 0
    mov dword [tool], T_INSPECT
    RETURN

; demo_stop(edi x, esi y)
FUNC demo_stop
    call tile_at
    test rax, rax
    jz .o
    or byte [rax+T_FLAGS2], F2_BUSSTOP
.o:
    RETURN

; demo_force(edi kind, esi x, edx y): place without the usual checks
FUNC demo_force
    mov [build_kind], edi
    mov dword [tool], T_BUILD
    mov dword [tl_n], 1
    mov [tl_x], esi
    mov [tl_y], edx
    ; clear the footprint first
    mov r12d, esi
    mov r13d, edx
    call bld_rec
    movzx r14d, byte [rax+BI_SIZE]
    xor ebx, ebx
.y:
    xor r15d, r15d
.x:
    lea edi, [r12+r15]
    lea esi, [r13+rbx]
    call tile_at
    test rax, rax
    jz .n
    mov byte [rax+T_OBJ], OBJ_NONE
    mov byte [rax+T_ZONE], 0
    mov byte [rax+T_TERRAIN], TER_GRASS
.n:
    inc r15d
    cmp r15d, r14d
    jl .x
    inc ebx
    cmp ebx, r14d
    jl .y
    mov edi, [build_kind]
    call bld_rec
    mov eax, [rax+BI_COST]
    mov [tl_cost], eax
    mov byte [tl_ok], 1
    mov dword [tl_valid], 1
    mov dword [force_place], 1
    call tool_apply
    mov dword [force_place], 0
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
%include "sprites2.asm"
%include "sprites3.asm"
%include "sprites4.asm"
%include "render.asm"
%include "light.asm"
%include "threads.asm"
%include "sim.asm"
%include "traffic.asm"
%include "traffic2.asm"
%include "requests.asm"
%include "metro.asm"
%include "rail.asm"
%include "air.asm"
%include "agents.asm"
%include "audio.asm"
%include "music.asm"
%include "tunes.asm"
%include "ui.asm"
%include "tools.asm"
%include "tutorial.asm"
%include "saves.asm"
%ifndef WEB
%include "trailer.asm"
%endif
%include "undo.asm"
%include "playtest.asm"
%include "script.asm"
