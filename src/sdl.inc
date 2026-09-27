; =====================================================================
;  SDL2 / libc imports and constants (hand-written, no C headers)
; =====================================================================

extern SDL_Init, SDL_Quit, SDL_CreateWindow, SDL_DestroyWindow
extern SDL_CreateRenderer, SDL_CreateTexture, SDL_DestroyTexture
extern SDL_LockTexture, SDL_UnlockTexture, SDL_RenderCopy, SDL_RenderPresent
extern SDL_RenderClear, SDL_SetRenderDrawColor, SDL_SetTextureBlendMode
extern SDL_PollEvent, SDL_GetTicks, SDL_Delay, SDL_SetHint
extern SDL_GetKeyboardState, SDL_GetWindowSize, SDL_ShowCursor
extern SDL_SetWindowTitle, SDL_GetPerformanceCounter, SDL_GetPerformanceFrequency
extern SDL_OpenAudioDevice, SDL_PauseAudioDevice, SDL_QueueAudio
extern SDL_GetQueuedAudioSize, SDL_ClearQueuedAudio
extern SDL_CreateRGBSurfaceWithFormatFrom, SDL_SaveBMP_RW, SDL_RWFromFile, SDL_RWsize
extern SDL_FreeSurface, SDL_GetError, SDL_SetWindowFullscreen
extern SDL_RWread, SDL_RWwrite, SDL_RWclose, SDL_LoadWAV_RW, SDL_FreeWAV
extern SDL_CreateThread, SDL_CreateSemaphore, SDL_SemPost, SDL_SemWait, SDL_GetCPUCount
extern printf, exit, strcmp, atoi

SDL_INIT_TIMER          equ 0x00000001
SDL_INIT_AUDIO          equ 0x00000010
SDL_INIT_VIDEO          equ 0x00000020

SDL_WINDOWPOS_CENTERED  equ 0x2FFF0000
SDL_WINDOW_SHOWN        equ 0x00000004
SDL_WINDOW_RESIZABLE    equ 0x00000020
SDL_WINDOW_FULLSCREEN_DESKTOP equ 0x00001001

SDL_RENDERER_ACCELERATED  equ 2
SDL_RENDERER_PRESENTVSYNC equ 4
SDL_PIXELFORMAT_ARGB8888  equ 0x16362004
SDL_TEXTUREACCESS_STREAMING equ 1
SDL_BLENDMODE_BLEND     equ 1

; events
SDL_QUIT                equ 0x100
SDL_WINDOWEVENT         equ 0x200
SDL_KEYDOWN             equ 0x300
SDL_KEYUP               equ 0x301
SDL_MOUSEMOTION         equ 0x400
SDL_MOUSEBUTTONDOWN     equ 0x401
SDL_MOUSEBUTTONUP       equ 0x402
SDL_MOUSEWHEEL          equ 0x403
SDL_WINDOWEVENT_RESIZED equ 5
SDL_WINDOWEVENT_SIZE_CHANGED equ 6
SDL_WINDOWEVENT_ENTER equ 10
SDL_WINDOWEVENT_LEAVE equ 11

EV_TYPE     equ 0
EV_KEY_REPEAT equ 13
EV_KEY_SCAN equ 16
EV_KEY_MOD  equ 24
EV_MM_STATE equ 16
EV_MM_X     equ 20
EV_MM_Y     equ 24
EV_MB_BUTTON equ 16
EV_MB_X     equ 20
EV_MB_Y     equ 24
EV_MW_Y     equ 20
EV_WIN_EVENT equ 12
EV_WIN_D1   equ 16
EV_WIN_D2   equ 20

; scancodes
SC_A equ 4
SC_B equ 5
SC_C equ 6
SC_D equ 7
SC_E equ 8
SC_F equ 9
SC_G equ 10
SC_H equ 11
SC_I equ 12
SC_L equ 15
SC_M equ 16
SC_N equ 17
SC_O equ 18
SC_P equ 19
SC_Q equ 20
SC_R equ 21
SC_S equ 22
SC_T equ 23
SC_U equ 24
SC_V equ 25
SC_K equ 14
SC_HOME equ 74
SC_W equ 26
SC_X equ 27
SC_Z equ 29
SC_1 equ 30
SC_0 equ 39
SC_RETURN equ 40
SC_ESCAPE equ 41
SC_BACKSPACE equ 42
SC_TAB equ 43
SC_SPACE equ 44
SC_MINUS equ 45
SC_EQUALS equ 46
SC_LBRACKET equ 47
SC_RBRACKET equ 48
SC_COMMA equ 54
SC_PERIOD equ 55
SC_F1 equ 58
SC_F5 equ 62
SC_F9 equ 66
SC_F11 equ 68
SC_F12 equ 69
SC_DELETE equ 76
SC_PAGEUP equ 75
SC_PAGEDOWN equ 78
SC_RIGHT equ 79
SC_LEFT equ 80
SC_DOWN equ 81
SC_UP equ 82
SC_KP_MINUS equ 86
SC_KP_PLUS equ 87
SC_LSHIFT equ 225
SC_RSHIFT equ 229

AUDIO_S16LSB equ 0x8010
%ifdef WEB
extern web_setup, web_open, web_bench
%endif
