; =====================================================================
;  SCRIPT - a scripted player for tests (native builds only)
;
;     cityssembly --play script.txt [--beta]
;
;  Each line of the script is one command.  Mouse and keyboard go
;  through SDL's event queue like the tour bot's, so the game sees what
;  a player would do.  X Y are map tiles (the pointer aims at the middle
;  of the tile); ui commands take interface pixels.  '#' starts a
;  comment.
;
;     new SEED            a fresh city (no tour) from a map seed
;     rich                lots of money, every plot, everything unlocked
;     money N             set the treasury
;     center X Y          centre the view on a tile
;     zoom N              zoom level
;     key NAME            press a key: a, 1, esc, f5, ctrl+z, shift+x ...
;     hold NAME           keep a key down (shift, ctrl, alt ...)
;     release NAME        and let go
;     move X Y            point at a tile
;     click X Y           left click on a tile
;     drag X0 Y0 X1 Y1    left drag from tile to tile
;     uimove X Y          point at interface pixels
;     uiclick X Y         left click on interface pixels
;     rclick              right click where the pointer is
;     wait N              let N frames pass
;     days N              run the simulation N days at once
;     shot FILE           screenshot after the frame is drawn
;     tile X Y            print a tile
;     state               print money, population, tool ...
;     echo TEXT           print a line
;     select N            choose menu item N (a BK_* building, 100+ tools)
;     press LABEL         click the button whose label starts with LABEL
;     down X Y / up X Y   press / let go of the left button on a tile (a
;                         drag in steps: down, move ..., shot, up)
;     poke X Y OFF VALUE  set byte OFF of a tile record (test setups)
;     weather N           beta: 1 snow, 2 flood, 3 heat, 4 storm,
;                         5 tornado, 6 epidemic, 7 riot
;     apply X0 Y0 X1 Y1   use the current tool from tile to tile directly
;                         (no pointer: for building big test cities)
;     roadtype N          the road tool's type (0 street, 1 avenue, 2 hwy)
;     save FILE / load FILE
;     speed N             game speed 0..3
;     report              one line: date, population, jobs, money, traffic
;     mapdump             print the map as text (. land ~ water # road ...)
;     quit
; =====================================================================
%ifndef WEB

PLAY_MAX    equ 65536
PLAY_TOKS   equ 16
PLAY_TOKLEN equ 64

section .bss
play_on     resd 1
play_file   resq 1
play_len    resd 1
play_pos    resd 1          ; offset of the current line
play_next   resd 1          ; offset of the line after it
play_t      resd 1          ; frames into the current command
play_wait   resd 1
play_shot   resd 1          ; a screenshot is due after this frame
play_ntok   resd 1
play_arg    resd PLAY_TOKS
play_tok    resb PLAY_TOKS*PLAY_TOKLEN
play_rest   resb 256        ; the line after the command word
play_buf    resb PLAY_MAX+1
play_ev     resb 64
PB_MAX      equ 128
pb_n        resd 1                  ; buttons drawn this frame (for "press")
pb_rect     resd PB_MAX*4
pb_label    resq PB_MAX
pb_pend     resd 2

section .data
str_play_flag db "--play", 0
play_rb     db "rb", 0
pf_missing  db "PLAY cannot read %s", 10, 0
pf_unknown  db "PLAY unknown command: %s", 10, 0
pf_echo     db "PLAY %s", 10, 0
pf_tile     db "PLAY tile %d,%d obj %d zone %d sub %d level %d", 0
pf_tile2    db " flags %d flags2 %d road %d pop %d", 10, 0
pf_state    db "PLAY state money %lld population %d tool %d acts %d", 0
pf_state2   db " redo %d day %d month %d cam %d,%d", 0
pf_state3   db " sprites %d arena %d", 10, 0
pf_shot     db "PLAY shot %s", 10, 0

; commands, in handler order
play_cmds   dq pc_new, pc_rich, pc_money, pc_center, pc_zoom, pc_key, pc_hold
            dq pc_release, pc_move, pc_click, pc_drag, pc_uimove, pc_uiclick
            dq pc_rclick, pc_wait, pc_days, pc_shot, pc_tile, pc_state, pc_echo
            dq pc_quit, pc_select, pc_press, pc_down, pc_up, pc_poke
            dq pc_apply, pc_save, pc_load, pc_speed, pc_report, pc_roadtype
            dq pc_mapdump, pc_weather, 0
pc_new      db "new", 0
pc_rich     db "rich", 0
pc_money    db "money", 0
pc_center   db "center", 0
pc_zoom     db "zoom", 0
pc_key      db "key", 0
pc_hold     db "hold", 0
pc_release  db "release", 0
pc_move     db "move", 0
pc_click    db "click", 0
pc_drag     db "drag", 0
pc_uimove   db "uimove", 0
pc_uiclick  db "uiclick", 0
pc_rclick   db "rclick", 0
pc_wait     db "wait", 0
pc_days     db "days", 0
pc_shot     db "shot", 0
pc_tile     db "tile", 0
pc_state    db "state", 0
pc_echo     db "echo", 0
pc_quit     db "quit", 0
pc_select   db "select", 0
pc_press    db "press", 0
pc_down     db "down", 0
pc_up       db "up", 0
pc_poke     db "poke", 0
pc_apply    db "apply", 0
pc_save     db "save", 0
pc_load     db "load", 0
pc_speed    db "speed", 0
pc_report   db "report", 0
pc_roadtype db "roadtype", 0
pc_mapdump  db "mapdump", 0
pc_weather  db "weather", 0
pf_mapline  db "MAP %s", 10, 0
; map characters by object (terrain for empty land)
map_chars   db ". #=+HS*"
pf_report   db "PLAY report %d-%02d pop %d jobs %d money %lld", 0
pf_report2  db " vehicles %d flow %d%% commute %d jams %d", 0
pf_report3  db " income %d expenses %d happy %d", 0
pf_report4  db " power %d/%d water %d/%d sewage %d reds %d", 10, 0
pf_report5  db "PLAY spend roads %d services %d policies %d loans %d | income res %d com %d ind %d off %d other %d", 10, 0
pf_report6  db "PLAY travel bus %d metro %d walk %d (this month) stations %d weighed %d near %d same %d lost %d", 10, 0
pf_report7  db "PLAY rail riders %d visitors %d freight %d (this month) lines %d stations %d trains %d", 10, 0
pf_report8  db "PLAY air airports %d flying %d runway %d passengers %d trips %d (this month)", 10, 0
pf_report9  db "PLAY region price %d event %d deal %d offer %d trade %d ext %d", 0
pf_report10 db " links %x tiles N %d W %d", 10, 0
pf_report11 db "PLAY port ports %d live %d way %d ship %d trade %d (this month)", 10, 0
pf_report12 db "PLAY services worst %d reach police %d fire %d health %d schools %d high %d", 10, 0
pf_report13 db "PLAY econ red %d hist %x grade %d declined %d fund %d tax %d", 10, 0
pf_report14 db "PLAY weather kind %d days %d snow %d tornado %d hits %d at %d", 0
pf_report15 db ",%d plowed %d", 10, 0
pf_report16 db "PLAY trams lines %d riders %d (this month) trams %d raw %d (this month) tourists %d", 0
pf_report17 db " guests %d intercity %d", 10, 0
pf_nobtn    db "PLAY no button: %s", 10, 0

; key names -> scancodes
play_keys   dq pk_esc, 41, pk_space, 44, pk_tab, 43, pk_ret, 40, pk_enter, 40
            dq pk_bksp, 42, pk_minus, 45, pk_equals, 46, pk_lbr, 47, pk_rbr, 48
            dq pk_home, 74, pk_del, 76, pk_shift, 225, pk_ctrl, 224, pk_alt, 226
            dq pk_up, 82, pk_down, 81, pk_left, 80, pk_right, 79, pk_slash, 56, 0
pk_esc      db "esc", 0
pk_space    db "space", 0
pk_tab      db "tab", 0
pk_ret      db "return", 0
pk_enter    db "enter", 0
pk_bksp     db "backspace", 0
pk_minus    db "minus", 0
pk_equals   db "equals", 0
pk_lbr      db "lbracket", 0
pk_rbr      db "rbracket", 0
pk_home     db "home", 0
pk_del      db "delete", 0
pk_shift    db "shift", 0
pk_ctrl     db "ctrl", 0
pk_alt      db "alt", 0
pk_up       db "up", 0
pk_down     db "down", 0
pk_left     db "left", 0
pk_right    db "right", 0
pk_slash    db "slash", 0
pm_ctrl     db "ctrl+", 0
pm_shift    db "shift+", 0
pm_alt      db "alt+", 0

section .text

; read the script named by play_file
FUNC play_load
    mov rdi, [play_file]
    lea rsi, [play_rb]
    CALLC SDL_RWFromFile
    test rax, rax
    jnz .open
    lea rdi, [pf_missing]
    mov rsi, [play_file]
    xor eax, eax
    CALLC printf
    mov dword [play_on], 0
    RETURN
.open:
    mov r12, rax
    mov rdi, r12
    lea rsi, [play_buf]
    mov edx, 1
    mov ecx, PLAY_MAX
    CALLC SDL_RWread
    mov [play_len], eax
    mov byte [play_buf+rax], 0
    mov rdi, r12
    CALLC SDL_RWclose
    mov dword [play_pos], 0
    mov dword [play_t], 0
    RETURN

; split the line at play_pos into tokens; sets play_next.
; -> eax 0 at the end of the script
FUNC play_parse
.line:
    mov ebx, [play_pos]
    cmp ebx, [play_len]
    jge .end
    mov dword [play_ntok], 0
    mov byte [play_rest], 0
    ; tokens up to the end of the line (or a comment)
.tok:
    movzx eax, byte [play_buf+rbx]
    cmp al, ' '
    je .sp
    cmp al, 9
    je .sp
    cmp al, 13
    je .sp
    test al, al
    jz .eol
    cmp al, 10
    je .eol
    cmp al, '#'
    je .comment
    ; a token: copy it
    mov ecx, [play_ntok]
    cmp ecx, PLAY_TOKS
    jge .skipw
    ; the rest of the line (after the command word) for echo
    cmp ecx, 1
    jne .nr
    lea rdi, [play_rest]
    xor edx, edx
.rc:
    movzx eax, byte [play_buf+rbx+rdx]
    test al, al
    jz .rcd
    cmp al, 10
    je .rcd
    cmp al, 13
    je .rcd
    cmp edx, 254
    jge .rcd
    mov [rdi+rdx], al
    inc edx
    jmp .rc
.rcd:
    mov byte [rdi+rdx], 0
.nr:
    imul edi, ecx, PLAY_TOKLEN
    lea rdi, [play_tok+rdi]
    xor edx, edx
.cp:
    movzx eax, byte [play_buf+rbx]
    cmp al, ' '
    jbe .cpd
    cmp al, '#'
    je .cpd
    cmp edx, PLAY_TOKLEN-1
    jge .cpn
    mov [rdi+rdx], al
    inc edx
.cpn:
    inc ebx
    jmp .cp
.cpd:
    mov byte [rdi+rdx], 0
    ; its number (0 when it isn't one)
    push rcx
    push rcx
    CALLC atoi
    pop rcx
    pop rcx
    mov [play_arg+rcx*4], eax
    inc dword [play_ntok]
    jmp .tok
.skipw:
    movzx eax, byte [play_buf+rbx]
    cmp al, ' '
    jbe .tok
    inc ebx
    jmp .skipw
.sp:
    inc ebx
    jmp .tok
.comment:
    movzx eax, byte [play_buf+rbx]
    test al, al
    jz .eol
    cmp al, 10
    je .eol
    inc ebx
    jmp .comment
.eol:
    cmp byte [play_buf+rbx], 10
    jne .e2
    inc ebx
.e2:
    mov [play_next], ebx
    cmp dword [play_ntok], 0
    jne .have
    ; blank line: the next one
    mov [play_pos], ebx
    jmp .line
.have:
    mov eax, 1
    RETURN
.end:
    xor eax, eax
    RETURN

; scancode and modifiers for a key name (rdi) -> eax scancode, edx mod
FUNC play_scancode
    mov r12, rdi
    xor r13d, r13d                  ; modifiers
.mods:
    mov rdi, r12
    lea rsi, [pm_ctrl]
    mov edx, 5
    call play_prefix
    test eax, eax
    jz .m2
    or r13d, 0x40
    add r12, 5
    jmp .mods
.m2:
    mov rdi, r12
    lea rsi, [pm_shift]
    mov edx, 6
    call play_prefix
    test eax, eax
    jz .m3
    or r13d, 1
    add r12, 6
    jmp .mods
.m3:
    mov rdi, r12
    lea rsi, [pm_alt]
    mov edx, 4
    call play_prefix
    test eax, eax
    jz .name
    or r13d, 0x100
    add r12, 4
    jmp .mods
.name:
    ; one letter or digit
    cmp byte [r12+1], 0
    jne .table
    movzx eax, byte [r12]
    cmp al, 'a'
    jb .dig
    cmp al, 'z'
    ja .dig
    sub eax, 'a'-4
    jmp .out
.dig:
    cmp al, '0'
    jne .d1
    mov eax, 39
    jmp .out
.d1:
    cmp al, '1'
    jb .table
    cmp al, '9'
    ja .table
    sub eax, '1'-30
    jmp .out
.table:
    ; f1..f12
    cmp byte [r12], 'f'
    jne .t0
    movzx eax, byte [r12+1]
    cmp al, '1'
    jb .t0
    cmp al, '9'
    ja .t0
    lea rdi, [r12+1]
    CALLC atoi
    add eax, 57
    jmp .out
.t0:
    xor ebx, ebx
.t:
    mov rsi, [play_keys+rbx*8]
    test rsi, rsi
    jz .none
    mov rdi, r12
    CALLC strcmp
    test eax, eax
    jz .found
    add ebx, 2
    jmp .t
.found:
    mov eax, [play_keys+rbx*8+8]
    jmp .out
.none:
    xor eax, eax
.out:
    mov edx, r13d
    RETURN

; does rdi start with the edx bytes at rsi? -> eax 1
play_prefix:
    xor ecx, ecx
.l:
    cmp ecx, edx
    jge .y
    mov al, [rdi+rcx]
    cmp al, [rsi+rcx]
    jne .n
    inc ecx
    jmp .l
.y: mov eax, 1
    ret
.n: xor eax, eax
    ret

; window px of tile (play_arg[i], play_arg[i+1]); edi = i -> eax, edx
play_tile_win:
    mov esi, [play_arg+rdi*4+4]
    mov edi, [play_arg+rdi*4]
    jmp tut_w2win

; before the frame's events are read
FUNC play_tick, 16
    cmp dword [play_on], 0
    je .out
    cmp dword [play_shot], 0
    jne .out
    cmp dword [play_wait], 0
    je .go
    dec dword [play_wait]
    jmp .out
.go:
    cmp dword [play_t], 0
    jne .run
    call play_parse
    test eax, eax
    jnz .run
    ; the script ran out: stop
    mov dword [running], 0
    jmp .out
.run:
    ; find the command
    xor ebx, ebx
.c:
    mov rsi, [play_cmds+rbx*8]
    test rsi, rsi
    jz .unknown
    lea rdi, [play_tok]
    CALLC strcmp
    test eax, eax
    jz .cmd
    inc ebx
    jmp .c
.unknown:
    lea rdi, [pf_unknown]
    lea rsi, [play_tok]
    xor eax, eax
    CALLC printf
    mov dword [running], 0
    jmp .out
.cmd:
    mov eax, [play_t]
    mov [bot_t], eax
    cmp ebx, 0
    je .new
    cmp ebx, 1
    je .rich
    cmp ebx, 2
    je .money
    cmp ebx, 3
    je .center
    cmp ebx, 4
    je .zoom
    cmp ebx, 5
    je .key
    cmp ebx, 6
    je .hold
    cmp ebx, 7
    je .release
    cmp ebx, 8
    je .move
    cmp ebx, 9
    je .click
    cmp ebx, 10
    je .drag
    cmp ebx, 11
    je .uimove
    cmp ebx, 12
    je .uiclick
    cmp ebx, 13
    je .rclick
    cmp ebx, 14
    je .wait
    cmp ebx, 15
    je .days
    cmp ebx, 16
    je .shot
    cmp ebx, 17
    je .tile
    cmp ebx, 18
    je .state
    cmp ebx, 19
    je .echo
    cmp ebx, 21
    je .select
    cmp ebx, 22
    je .press
    cmp ebx, 23
    je .down
    cmp ebx, 24
    je .up
    cmp ebx, 25
    je .poke
    cmp ebx, 26
    je .apply
    cmp ebx, 27
    je .save
    cmp ebx, 28
    je .load
    cmp ebx, 29
    je .speed
    cmp ebx, 30
    je .report
    cmp ebx, 31
    je .roadtype
    cmp ebx, 32
    je .mapdump
    cmp ebx, 33
    je .weather
    ; quit
    mov dword [running], 0
    jmp .done

.new:
    call tut_abort
    mov dword [sandbox], 0
    mov eax, [play_arg+4]
    mov [world_seed], eax
    call world_generate
    lea rdi, [money]
    mov ecx, sim_state_end - money
    xor eax, eax
    rep stosb
    call sim_init
    call agents_init
    mov rax, [money]
    mov [money_shown], rax
    call undo_reset
    call extra_reset
    mov dword [sel_x], -1
    mov dword [welcome], 0
    mov dword [slots_start], 0
    mov dword [panel], PANEL_NONE
    mov dword [tool], T_INSPECT
    mov edi, 38
    mov esi, [hwy_row]
    call camera_center_tile
    jmp .done
.rich:
    mov qword [money], 10000000
    mov qword [money_shown], 10000000
    call ms_top
    mov [milestone], eax
    lea rdi, [plot_owned]
    mov al, 1
    mov ecx, PLOTS*PLOTS
    rep stosb
    jmp .done
.money:
    movsxd rax, dword [play_arg+4]
    mov [money], rax
    mov [money_shown], rax
    jmp .done
.center:
    mov edi, [play_arg+4]
    mov esi, [play_arg+8]
    call camera_center_tile
    jmp .done
.zoom:
    mov edi, [play_arg+4]
    call video_set_zoom
    jmp .done
.key:
    lea rdi, [play_tok+PLAY_TOKLEN]
    call play_scancode
    mov r12d, eax
    mov r13d, edx
    lea rdi, [play_ev]
    xor eax, eax
    mov ecx, 64
    rep stosb
    mov dword [play_ev], SDL_KEYDOWN
    mov byte [play_ev+12], 1
    mov [play_ev+EV_KEY_SCAN], r12d
    mov [play_ev+EV_KEY_MOD], r13w
    lea rdi, [play_ev]
    CALLC SDL_PushEvent
    mov dword [play_wait], 2
    jmp .done
.hold:
.release:
    lea rdi, [play_tok+PLAY_TOKLEN]
    call play_scancode
    mov r12d, eax
    xor edi, edi
    CALLC SDL_GetKeyboardState
    xor ecx, ecx
    cmp ebx, 6
    sete cl
    mov [rax+r12], cl
    jmp .done
.move:
    mov edi, 1
    call play_tile_win
    mov edi, eax
    mov esi, edx
    call bot_move
    mov dword [play_wait], 2
    jmp .done
.click:
    mov edi, 1
    call play_tile_win
    mov edi, eax
    mov esi, edx
    call bot_click
    test eax, eax
    jz .more
    mov dword [play_wait], 4
    jmp .done
.drag:
    mov edi, 3
    call play_tile_win
    mov [rbp-48], eax
    mov [rbp-52], edx
    mov edi, 1
    call play_tile_win
    mov edi, eax
    mov esi, edx
    mov edx, [rbp-48]
    mov ecx, [rbp-52]
    call bot_drag
    test eax, eax
    jz .more
    mov dword [play_wait], 4
    jmp .done
.uimove:
    mov edi, [play_arg+4]
    mov esi, [play_arg+8]
    call bot_ui2win
    mov edi, eax
    mov esi, edx
    call bot_move
    mov dword [play_wait], 2
    jmp .done
.uiclick:
    mov edi, [play_arg+4]
    mov esi, [play_arg+8]
    call bot_ui2win
    mov edi, eax
    mov esi, edx
    call bot_click
    test eax, eax
    jz .more
    mov dword [play_wait], 4
    jmp .done
.rclick:
    mov eax, [play_t]
    cmp eax, 0
    jne .rc1
    mov edi, 3
    mov esi, 1
    call bot_button
    jmp .more
.rc1:
    cmp eax, 2
    jl .more
    mov edi, 3
    xor esi, esi
    call bot_button
    mov dword [play_wait], 2
    jmp .done
.wait:
    mov eax, [play_arg+4]
    mov [play_wait], eax
    jmp .done
.days:
    mov r12d, [play_arg+4]
.dl:
    test r12d, r12d
    jle .done
    call sim_day
    dec r12d
    jmp .dl
.shot:
    mov dword [play_shot], 1
    jmp .out                        ; finished after the frame
.tile:
    mov edi, [play_arg+4]
    mov esi, [play_arg+8]
    call tile_at
    test rax, rax
    jz .done
    mov rbx, rax
    lea rdi, [pf_tile]
    mov esi, [play_arg+4]
    mov edx, [play_arg+8]
    movzx ecx, byte [rbx+T_OBJ]
    movzx r8d, byte [rbx+T_ZONE]
    movzx r9d, byte [rbx+T_SUB]
    movzx eax, byte [rbx+T_LEVEL]
    push rax
    push rax
    xor eax, eax
    CALLC printf
    pop rax
    pop rax
    lea rdi, [pf_tile2]
    movzx esi, byte [rbx+T_FLAGS]
    movzx edx, byte [rbx+T_FLAGS2]
    movzx ecx, byte [rbx+T_ROADTYPE]
    movzx r8d, word [rbx+T_POP]
    xor eax, eax
    CALLC printf
    jmp .done
.state:
    lea rdi, [pf_state]
    mov rsi, [money]
    mov edx, [population]
    mov ecx, [tool]
    mov r8d, [n_acts]
    xor eax, eax
    CALLC printf
    lea rdi, [pf_state2]
    mov esi, [n_redo]
    mov edx, [day]
    mov ecx, [month]
    mov r8d, [cam_x]
    mov r9d, [cam_y]
    xor eax, eax
    CALLC printf
    lea rdi, [pf_state3]
    mov esi, [spr_count]
    mov edx, [arena_used]
    xor eax, eax
    CALLC printf
    jmp .done
.echo:
    lea rdi, [pf_echo]
    lea rsi, [play_rest]
    xor eax, eax
    CALLC printf
    jmp .done
.select:
    mov edi, [play_arg+4]
    call submenu_select
    jmp .done
.press:
    ; find the button (from the last frame drawn)
    cmp dword [play_t], 0
    jne .pr1
    xor r12d, r12d
.pl:
    cmp r12d, [pb_n]
    jge .pnone
    mov rdi, [pb_label+r12*8]
    lea rsi, [play_rest]
    call play_starts
    test eax, eax
    jnz .pfound
    inc r12d
    jmp .pl
.pnone:
    lea rdi, [pf_nobtn]
    lea rsi, [play_rest]
    xor eax, eax
    CALLC printf
    jmp .done
.pfound:
    mov eax, r12d
    shl eax, 4
    mov edi, [pb_rect+rax]
    mov ecx, [pb_rect+rax+8]
    shr ecx, 1
    add edi, ecx
    mov esi, [pb_rect+rax+4]
    mov ecx, [pb_rect+rax+12]
    shr ecx, 1
    add esi, ecx
    mov [pb_pend], edi
    mov [pb_pend+4], esi
.pr1:
    mov edi, [pb_pend]
    mov esi, [pb_pend+4]
    call bot_ui2win
    mov edi, eax
    mov esi, edx
    call bot_click
    test eax, eax
    jz .more
    mov dword [play_wait], 4
    jmp .done
.apply:
    ; as if dragged from (X0, Y0) to (X1, Y1)
    mov eax, [play_arg+4]
    mov [drag_sx], eax
    mov eax, [play_arg+8]
    mov [drag_sy], eax
    mov eax, [play_arg+12]
    mov [hover_tx], eax
    mov eax, [play_arg+16]
    mov [hover_ty], eax
    mov dword [hover_valid], 1
    mov dword [drag_active], 1
    call tool_collect
    call tool_apply
    mov dword [drag_active], 0
    jmp .done
.save:
    lea rdi, [play_tok+PLAY_TOKLEN]
    call save_city_to
    jmp .done
.load:
    lea rdi, [play_tok+PLAY_TOKLEN]
    call load_city_from
    jmp .done
.speed:
    mov eax, [play_arg+4]
    mov [sim_speed], eax
    jmp .done
.roadtype:
    mov eax, [play_arg+4]
    mov [road_type], eax
    jmp .done
.report:
    ; jammed road tiles
    xor r12d, r12d
    xor ecx, ecx
.rj:
    mov eax, ecx
    shl eax, TILE_SHIFT
    cmp byte [tiles+rax+T_OBJ], OBJ_ROAD
    jne .rjn
    cmp byte [tiles+rax+T_JAM], 150
    jb .rjn
    inc r12d
.rjn:
    inc ecx
    cmp ecx, MAP_TILES
    jl .rj
    lea rdi, [pf_report]
    mov esi, [year]
    mov edx, [month]
    inc edx
    mov ecx, [population]
    mov r8d, [jobs+ZC_COM*4]
    add r8d, [jobs+ZC_IND*4]
    add r8d, [jobs+ZC_OFF*4]
    mov r9, [money]
    xor eax, eax
    CALLC printf
    lea rdi, [pf_report2]
    mov esi, [veh_count]
    mov edx, [flow_pct]
    mov ecx, [avg_commute]
    mov r8d, r12d
    xor eax, eax
    CALLC printf
    lea rdi, [pf_report3]
    mov esi, [income_last]
    mov edx, [expense_last]
    mov ecx, [happy_avg]
    xor eax, eax
    CALLC printf
    lea rdi, [pf_report4]
    mov esi, [power_demand]
    mov edx, [power_supply]
    mov ecx, [water_demand]
    mov r8d, [water_supply]
    mov r9d, [sewage_cap]
    mov eax, [sig_reds]
    push rax
    push rax
    xor eax, eax
    CALLC printf
    pop rax
    pop rax
    mov dword [sig_reds], 0
    lea rdi, [pf_report5]
    mov esi, [exp_roads]
    mov edx, [exp_services]
    mov ecx, [exp_policies]
    mov r8d, [exp_loans]
    mov r9d, [inc_class]
    sub rsp, 8
    push qword [inc_other]
    push qword [inc_class+12]
    push qword [inc_class+8]
    push qword [inc_class+4]
    xor eax, eax
    CALLC printf
    add rsp, 40
    lea rdi, [pf_report6]
    mov esi, [riders_month]
    mov edx, [metro_riders_month]
    mov ecx, [walkers_month]
    mov r8d, [mt_n]
    mov r9d, [tm_calls]
    sub rsp, 8
    push qword [tm_lost]
    push qword [tm_same]
    push qword [tm_near]
    xor eax, eax
    CALLC printf
    add rsp, 32
    mov dword [tm_calls], 0
    mov dword [tm_near], 0
    mov dword [tm_same], 0
    mov dword [tm_lost], 0
    ; the railways
    xor ecx, ecx
    xor eax, eax
.rtc:
    cmp byte [tr_kind+rcx], 0
    je .rtn
    inc eax
.rtn:
    inc ecx
    cmp ecx, TR_MAX
    jl .rtc
    lea rdi, [pf_report7]
    mov esi, [train_riders_month]
    mov edx, [rail_visitors_month]
    mov ecx, [rail_freight_month]
    mov r8d, [rl_lines]
    mov r9d, [rl_n]
    push rax
    push rax
    xor eax, eax
    CALLC printf
    pop rax
    pop rax
    lea rdi, [pf_report8]
    mov esi, [ap_n]
    movzx edx, byte [ap_live]
    movzx ecx, byte [ap_rwlen]
    mov r8d, [air_pax]
    mov r9d, [air_trips]
    xor eax, eax
    CALLC printf
    lea rdi, [pf_report9]
    mov esi, [mk_price]
    mov edx, [mk_event]
    mov ecx, [ct_kind]
    mov r8d, [of_kind]
    mov r9d, [trade_last]
    mov eax, [ext_demand]
    push rax
    push rax
    xor eax, eax
    CALLC printf
    pop rax
    pop rax
    lea rdi, [pf_report10]
    mov esi, [nb_links]
    mov edx, [nb_tile]
    mov ecx, [nb_tile+12]
    xor eax, eax
    CALLC printf
    lea rdi, [pf_report11]
    mov esi, [pt_n]
    movzx edx, byte [pt_live]
    movzx ecx, word [pt_len]
    movzx r8d, byte [sh_on]
    mov r9d, [port_trade_month]
    xor eax, eax
    CALLC printf
    lea rdi, [pf_report12]
    mov esi, [sv_worst]
    mov edx, [cov_scale+CV_POLICE*4]
    mov ecx, [cov_scale+CV_FIRE*4]
    mov r8d, [cov_scale+CV_HEALTH*4]
    mov r9d, [cov_scale+CV_ELEM*4]
    mov eax, [cov_scale+CV_HIGH*4]
    push rax
    push rax
    xor eax, eax
    CALLC printf
    pop rax
    pop rax
    call credit_grade
    mov ecx, eax
    lea rdi, [pf_report13]
    mov esi, [months_red]
    mov edx, [red_hist]
    mov r8d, [declined_month]
    mov r9d, [svc_fund+CV_POLICE*4]
    mov eax, [tax_rate]
    push rax
    push rax
    xor eax, eax
    CALLC printf
    pop rax
    pop rax
    lea rdi, [pf_report14]
    mov esi, [wx_kind]
    mov edx, [wx_days]
    mov ecx, [snow_level]
    mov r8d, [tor_on]
    mov r9d, [tor_hits]
    mov eax, [tor_x]
    shr eax, 8
    push rax
    push rax
    xor eax, eax
    CALLC printf
    pop rax
    pop rax
    xor edx, edx
    xor ecx, ecx
.plc:
    movzx eax, byte [map_plow+rcx]
    add edx, eax
    inc ecx
    cmp ecx, MAP_TILES
    jl .plc
    lea rdi, [pf_report15]
    mov esi, [tor_y]
    shr esi, 8
    xor eax, eax
    CALLC printf
    xor ecx, ecx
    xor edx, edx
.trc:
    movzx eax, byte [tram_on+rcx]
    add ecx, 1
    add edx, eax
    cmp ecx, TRAM_MAX
    jl .trc
    mov ecx, edx
    lea rdi, [pf_report16]
    mov esi, [tw_lines]
    mov edx, [tram_riders_month]
    mov r8d, [raw_month]
    mov r9d, [tourists]
    xor eax, eax
    CALLC printf
    lea rdi, [pf_report17]
    mov esi, [guests]
    mov edx, [ic_live]
    xor eax, eax
    CALLC printf
    jmp .done
.mapdump:
    xor r12d, r12d                  ; row
.mr:
    xor r13d, r13d
.mc:
    mov eax, r12d
    shl eax, MAP_SHIFT
    add eax, r13d
    shl eax, TILE_SHIFT
    lea rbx, [tiles+rax]
    movzx ecx, byte [rbx+T_OBJ]
    mov dl, '.'
    cmp ecx, OBJ_NONE
    jne .mo
    cmp byte [rbx+T_TERRAIN], TER_WATER
    jne .mz
    mov dl, '~'
    jmp .mput
.mz:
    cmp byte [rbx+T_ZONE], 0
    je .mput
    mov dl, 'z'
    jmp .mput
.mo:
    mov dl, 't'
    cmp ecx, OBJ_TREE
    je .mput
    mov dl, '#'
    cmp ecx, OBJ_ROAD
    jne .mo2
    cmp byte [rbx+T_TERRAIN], TER_WATER
    jne .mput
    mov dl, '='
    jmp .mput
.mo2:
    mov dl, '+'
    cmp ecx, OBJ_POWER
    je .mput
    mov dl, 'b'
    cmp ecx, OBJ_ZONEBLD
    je .mput
    mov dl, 'S'
    cmp ecx, OBJ_SERVICE
    je .mput
    mov dl, 'r'
.mput:
    mov [play_rest+r13], dl
    inc r13d
    cmp r13d, MAP_W
    jl .mc
    mov byte [play_rest+MAP_W], 0
    lea rdi, [pf_mapline]
    lea rsi, [play_rest]
    xor eax, eax
    CALLC printf
    inc r12d
    cmp r12d, MAP_W
    jl .mr
    jmp .done
.weather:
    ; 1 snow, 2 flood, 3 heat, 4 storm, 5 tornado, 6 epidemic, 7 riot
    mov edi, [play_arg+4]
    cmp edi, 5
    jl .wx
    je .wxt
    cmp edi, 6
    je .wxe
    call riot
    jmp .done
.wxe:
    call epidemic
    jmp .done
.wxt:
    call tornado_start
    jmp .done
.wx:
    call weather_start
    jmp .done
.poke:
    mov edi, [play_arg+4]
    mov esi, [play_arg+8]
    call tile_at
    test rax, rax
    jz .done
    mov ecx, [play_arg+12]
    and ecx, 31
    mov edx, [play_arg+16]
    mov [rax+rcx], dl
    jmp .done
.down:
.up:
    cmp dword [play_t], 0
    jne .du1
    mov edi, 1
    call play_tile_win
    mov edi, eax
    mov esi, edx
    call bot_move
    jmp .more
.du1:
    cmp dword [play_t], 2
    jl .more
    mov edi, 1
    xor esi, esi
    cmp ebx, 23
    sete sil
    call bot_button
    mov dword [play_wait], 3
    jmp .done
.more:
    inc dword [play_t]
    jmp .out
.done:
    mov dword [play_t], 0
    mov eax, [play_next]
    mov [play_pos], eax
.out:
    RETURN

; after the frame is on screen: screenshots
FUNC play_after
    cmp dword [play_on], 0
    je .out
    cmp dword [play_shot], 0
    je .out
    mov dword [play_shot], 0
    lea rdi, [pf_shot]
    lea rsi, [play_tok+PLAY_TOKLEN]
    xor eax, eax
    CALLC printf
    lea rdi, [play_tok+PLAY_TOKLEN]
    call video_screenshot
    mov dword [play_t], 0
    mov eax, [play_next]
    mov [play_pos], eax
.out:
    RETURN


; does the text at rdi start with the text at rsi (colour codes in rdi
; skipped)? -> eax 1
play_starts:
    test rdi, rdi
    jz .n
.l:
    mov al, [rsi]
    test al, al
    jz .y
.sk:
    mov cl, [rdi]
    test cl, cl
    jz .n
    cmp cl, 8
    jae .c
    inc rdi                         ; a colour code
    jmp .sk
.c:
    cmp al, cl
    jne .n
    inc rsi
    inc rdi
    jmp .l
.y: mov eax, 1
    ret
.n: xor eax, eax
    ret
%endif

; a button was drawn (edi x, esi y, edx w, ecx h, r8 label): scripts
; can press it by its label.  Nothing in normal play.
ui_note_button:
%ifndef WEB
    cmp dword [play_on], 0
    je .o
    mov eax, [pb_n]
    cmp eax, PB_MAX
    jge .o
    mov [pb_label+rax*8], r8
    shl eax, 4
    mov [pb_rect+rax], edi
    mov [pb_rect+rax+4], esi
    mov [pb_rect+rax+8], edx
    mov [pb_rect+rax+12], ecx
    inc dword [pb_n]
.o:
%endif
    ret

; a new frame of buttons
ui_note_reset:
%ifndef WEB
    mov dword [pb_n], 0
%endif
    ret
