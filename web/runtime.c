// runtime.c - host side of the translated game: SDL / libc wrappers,
// start-up, and (in the browser) frame pacing and save persistence.
//
// The translated code calls ext_<name>() with its arguments in the
// emulated registers (SysV order: rdi rsi rdx rcx r8 r9, floats in xmm0..)
// and expects the result in rax.
#include "cpu.h"
#include <stdio.h>
#include <stdlib.h>
#include <SDL2/SDL.h>
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

_Thread_local cpu_t R;

void cpu_trap(const char *why) {
    fprintf(stderr, "cityssembly: cpu trap: %s\n", why);
#ifdef __EMSCRIPTEN__
    EM_ASM({ if (window.cityCrash) window.cityCrash(UTF8ToString($0)); }, why);
    emscripten_force_exit(1);
#endif
    abort();
}

#define A0 R.r[7]
#define A1 R.r[6]
#define A2 R.r[2]
#define A3 R.r[1]
#define A4 R.r[8]
#define A5 R.r[9]
#define P(x) ((void *)(uintptr_t)(x))
#define RET(v) (R.r[0] = (uint64_t)(v))
#define RETP(p) (R.r[0] = (uint64_t)(uintptr_t)(p))

// SDL_AudioSpec as the x86-64 code lays it out (pointers are 8 bytes there)
static void spec_from_game(uint64_t a, SDL_AudioSpec *s) {
    memset(s, 0, sizeof *s);
    s->freq = (int)LD32(a);
    s->format = LD16(a + 4);
    s->channels = LD8(a + 6);
    s->silence = LD8(a + 7);
    s->samples = LD16(a + 8);
    s->size = LD32(a + 12);
}
static void spec_to_game(uint64_t a, const SDL_AudioSpec *s) {
    ST32(a, (uint32_t)s->freq);
    ST16(a + 4, s->format);
    ST8(a + 6, s->channels);
    ST8(a + 7, s->silence);
    ST16(a + 8, s->samples);
    ST32(a + 12, s->size);
    ST64(a + 16, 0);
    ST64(a + 24, 0);
}

// ------------------------------------------------------------------ SDL
void ext_SDL_Init(void) {
#ifdef __EMSCRIPTEN__
    // SDL would yield to the browser inside SDL_RenderPresent, through
    // function pointers Asyncify doesn't track; we yield in our own wrapper
    SDL_SetHint(SDL_HINT_EMSCRIPTEN_ASYNCIFY, "0");
#endif
    RET(SDL_Init((Uint32)A0));
}
void ext_SDL_Quit(void) { SDL_Quit(); }
void ext_SDL_SetHint(void) { RET(SDL_SetHint(P(A0), P(A1))); }
void ext_SDL_GetError(void) { RETP(SDL_GetError()); }
void ext_SDL_CreateWindow(void) {
    RETP(SDL_CreateWindow(P(A0), (int)A1, (int)A2, (int)A3, (int)A4, (Uint32)A5));
}
void ext_SDL_CreateRenderer(void) {
    Uint32 flags = (Uint32)A2;
#ifdef __EMSCRIPTEN__
    // the page paces frames itself (requestAnimationFrame); SDL's simulated
    // vsync divides by the display refresh rate, which can be 0
    flags &= ~(Uint32)SDL_RENDERER_PRESENTVSYNC;
#endif
    RETP(SDL_CreateRenderer(P(A0), (int)A1, flags));
}
void ext_SDL_CreateTexture(void) {
    RETP(SDL_CreateTexture(P(A0), (Uint32)A1, (int)A2, (int)A3, (int)A4));
}
void ext_SDL_DestroyTexture(void) { SDL_DestroyTexture(P(A0)); }
void ext_SDL_SetTextureBlendMode(void) { RET(SDL_SetTextureBlendMode(P(A0), (SDL_BlendMode)A1)); }
void ext_SDL_LockTexture(void) {
    void *pix = 0; int pitch = 0;
    int r = SDL_LockTexture(P(A0), P(A1), &pix, &pitch);
    if (A2) ST64(A2, (uint64_t)(uintptr_t)pix);
    if (A3) ST32(A3, (uint32_t)pitch);
    RET((uint32_t)r);
}
void ext_SDL_UnlockTexture(void) { SDL_UnlockTexture(P(A0)); }
void ext_SDL_RenderCopy(void) { RET((uint32_t)SDL_RenderCopy(P(A0), P(A1), P(A2), P(A3))); }

#ifdef __EMSCRIPTEN__
// hand the browser a frame: wait for the next animation frame
EM_ASYNC_JS(void, web_wait_frame, (), {
    // next animation frame (vsync); a timer keeps things moving when the
    // tab can't paint (background tabs, headless browsers)
    await new Promise(function (r) {
        var done = false;
        function go() { if (!done) { done = true; r(); } }
        requestAnimationFrame(go);
        setTimeout(go, 50);
    });
});
#endif
static unsigned frames;
static double work_ms, work_max, wait_end;
void ext_SDL_RenderPresent(void) {
    SDL_RenderPresent(P(A0));
#ifdef __EMSCRIPTEN__
    // ?debug shows how long the game itself takes per frame (the average
    // and the slowest of the last 120)
    double now = emscripten_get_now();
    if (wait_end > 0) {
        work_ms += now - wait_end;
        if (now - wait_end > work_max) work_max = now - wait_end;
    }
    if ((++frames % 120) == 0) {
        EM_ASM({ if (window.cityPerf) window.cityPerf($0, $1, $2); }, frames, work_ms / 120, work_max);
        work_ms = 0;
        work_max = 0;
    }
    web_wait_frame();
    wait_end = emscripten_get_now();
#endif
}
void ext_SDL_GetWindowSize(void) {
    int w = 0, h = 0;
    SDL_GetWindowSize(P(A0), &w, &h);
    if (A1) ST32(A1, (uint32_t)w);
    if (A2) ST32(A2, (uint32_t)h);
}
void ext_SDL_SetWindowFullscreen(void) { RET((uint32_t)SDL_SetWindowFullscreen(P(A0), (Uint32)A1)); }
void ext_SDL_ShowCursor(void) { RET((uint32_t)SDL_ShowCursor((int)A0)); }
void ext_SDL_PollEvent(void) {
    // SDL_Event has no pointers in the variants the game reads, so the
    // layout matches the x86-64 one byte for byte
    RET((uint32_t)SDL_PollEvent(P(A0)));
}
void ext_SDL_GetKeyboardState(void) {
    int n = 0;
    const Uint8 *k = SDL_GetKeyboardState(&n);
    if (A0) ST32(A0, (uint32_t)n);
    RETP(k);
}
void ext_SDL_GetTicks(void) { RET(SDL_GetTicks()); }
#ifdef __EMSCRIPTEN__
// SDL's counter in the browser counts whole milliseconds: too coarse for
// the frame profile (?bench), so microseconds from performance.now()
void ext_SDL_GetPerformanceCounter(void) { RET((uint64_t)(emscripten_get_now() * 1000.0)); }
void ext_SDL_GetPerformanceFrequency(void) { RET(1000000ull); }
#else
void ext_SDL_GetPerformanceCounter(void) { RET(SDL_GetPerformanceCounter()); }
void ext_SDL_GetPerformanceFrequency(void) { RET(SDL_GetPerformanceFrequency()); }
#endif

// audio
// A hidden browser tab gets throttled to ~1 frame a second, far too slow to
// keep the queue fed, so sound stutters. While hidden: pause and stay silent.
static SDL_AudioDeviceID audio_dev;
static int audio_hidden;
static void audio_visibility(void) {
#ifdef __EMSCRIPTEN__
    int hidden = EM_ASM_INT({ return document.hidden ? 1 : 0; });
    if (!audio_dev || hidden == audio_hidden) return;
    audio_hidden = hidden;
    if (hidden) {
        SDL_PauseAudioDevice(audio_dev, 1);
        SDL_ClearQueuedAudio(audio_dev);
    } else {
        SDL_PauseAudioDevice(audio_dev, 0);
    }
#endif
}
void ext_SDL_OpenAudioDevice(void) {
    SDL_AudioSpec want, have;
    spec_from_game(A2, &want);
    SDL_AudioDeviceID d = SDL_OpenAudioDevice(P(A0), (int)A1, &want, A3 ? &have : NULL, (int)A4);
    if (A3) spec_to_game(A3, &have);
    audio_dev = d;
    RET(d);
}
void ext_SDL_PauseAudioDevice(void) {
    SDL_PauseAudioDevice((SDL_AudioDeviceID)A0, audio_hidden ? 1 : (int)A1);
}
void ext_SDL_QueueAudio(void) {
    if (audio_hidden) { RET(0); return; }        // drop: nobody is listening
    RET((uint32_t)SDL_QueueAudio((SDL_AudioDeviceID)A0, P(A1), (Uint32)A2));
}
void ext_SDL_GetQueuedAudioSize(void) {
    audio_visibility();
    // hidden: report a full queue so the game doesn't mix sound for nothing
    if (audio_hidden) { RET(1u << 20); return; }
    RET(SDL_GetQueuedAudioSize((SDL_AudioDeviceID)A0));
}
void ext_SDL_LoadWAV_RW(void) {
    SDL_AudioSpec s;
    Uint8 *buf = 0; Uint32 len = 0;
    SDL_AudioSpec *r = SDL_LoadWAV_RW(P(A0), (int)A1, &s, &buf, &len);
    if (r) {
        spec_to_game(A2, &s);
        ST64(A3, (uint64_t)(uintptr_t)buf);
        ST32(A4, len);
        RET(A2);
    } else RET(0);
}
void ext_SDL_FreeWAV(void) { SDL_FreeWAV(P(A0)); }

// files (saves and settings); in the browser they live in IndexedDB
static int files_dirty;
void ext_SDL_RWFromFile(void) {
    const char *mode = P(A1);
    if (mode && strchr(mode, 'w')) files_dirty = 1;
    RETP(SDL_RWFromFile(P(A0), mode));
}
void ext_SDL_RWread(void) { RET(SDL_RWread(P(A0), P(A1), (size_t)A2, (size_t)A3)); }
void ext_SDL_RWwrite(void) { RET(SDL_RWwrite(P(A0), P(A1), (size_t)A2, (size_t)A3)); }
void ext_SDL_RWsize(void) { RET((uint64_t)SDL_RWsize((SDL_RWops *)P(A0))); }
void ext_SDL_RWclose(void) {
    RET((uint32_t)SDL_RWclose(P(A0)));
#ifdef __EMSCRIPTEN__
    if (files_dirty) {
        files_dirty = 0;
        EM_ASM({ FS.syncfs(false, function (e) { if (e) console.warn('save sync', e); }); });
    }
#endif
}
void ext_SDL_SaveBMP_RW(void) { RET((uint32_t)SDL_SaveBMP_RW(P(A0), P(A1), (int)A2)); }
void ext_SDL_CreateRGBSurfaceWithFormatFrom(void) {
    RETP(SDL_CreateRGBSurfaceWithFormatFrom(P(A0), (int)A1, (int)A2, (int)A3, (int)A4, (Uint32)A5));
}
void ext_SDL_FreeSurface(void) { SDL_FreeSurface(P(A0)); }

// ------------------------------------------------------------------ libc
void ext_strcmp(void) { RET((uint64_t)(int64_t)strcmp(P(A0), P(A1))); }
void ext_atoi(void) { RET((uint64_t)(int64_t)atoi(P(A0))); }
void ext_exit(void) { exit((int)A0); }
void ext_printf(void) {
    // the game only prints integers and strings: format it here
    const char *f = P(A0);
    // five register arguments, then the stack (above the return slot)
    uint64_t args[12] = { A1, A2, A3, A4, A5 };
    for (int i = 5; i < 12; i++) args[i] = LD64(R.r[4] + 8 + 8 * (uint64_t)(i - 5));
    int n = 0;
    char out[1024]; size_t o = 0;
    for (; *f && o < sizeof out - 64; f++) {
        if (*f != '%') { out[o++] = *f; continue; }
        f++;
        while (*f >= '0' && *f <= '9') f++;
        uint64_t v = n < 12 ? args[n] : 0;
        n++;
        switch (*f) {
        case 'd': o += (size_t)snprintf(out + o, 32, "%d", (int)v); break;
        case 'u': o += (size_t)snprintf(out + o, 32, "%u", (unsigned)v); break;
        case 'x': o += (size_t)snprintf(out + o, 32, "%x", (unsigned)v); break;
        case 'c': out[o++] = (char)v; break;
        case 's': o += (size_t)snprintf(out + o, sizeof out - o - 1, "%s", (const char *)P(v)); break;
        case '%': out[o++] = '%'; n--; break;
        default: break;
        }
    }
    out[o] = 0;
    fputs(out, stdout);
    fflush(stdout);
    RET(o);
}

// ------------------------------------------------------------------ web
// window size for the canvas: the browser's, packed as (h << 32) | w
void ext_web_setup(void) {
#ifdef __EMSCRIPTEN__
    int w = EM_ASM_INT({ return window.innerWidth; });
    int h = EM_ASM_INT({ return window.innerHeight; });
    RET(((uint64_t)(uint32_t)h << 32) | (uint32_t)w);
#else
    RET((720ull << 32) | 1280);
#endif
}

// ------------------------------------------------------------------ threads
// The game's worker threads (src/threads.asm) run translated code: each
// gets its own register file (thread-local R) and its own stack.
void dispatch_call(uint64_t id);
typedef struct { uint64_t fn, data; } thread_start_t;
static int thread_tramp(void *p) {
    thread_start_t st = *(thread_start_t *)p;
    free(p);
    size_t sz = 1 << 20;
    uint8_t *stack = aligned_alloc(16, sz);
    memset(&R, 0, sizeof R);
    R.r[4] = (uint64_t)(uintptr_t)(stack + sz - 64) - 8;   // as if called
    R.r[7] = st.data;
    dispatch_call(st.fn);
    free(stack);
    return (int)R.r[0];
}
void ext_SDL_CreateThread(void) {
    thread_start_t *st = malloc(sizeof *st);
    st->fn = A0;
    st->data = A2;
    RETP(SDL_CreateThread(thread_tramp, P(A1), st));
}
void ext_SDL_CreateSemaphore(void) { RETP(SDL_CreateSemaphore((Uint32)A0)); }
void ext_SDL_SemPost(void) { RET((uint32_t)SDL_SemPost(P(A0))); }
void ext_SDL_SemWait(void) { RET((uint32_t)SDL_SemWait(P(A0))); }
void ext_SDL_GetCPUCount(void) {
#ifdef __EMSCRIPTEN__
    // as many as the page's worker pool (and only with shared memory)
    int n = EM_ASM_INT({
        if (typeof SharedArrayBuffer === 'undefined' || !self.crossOriginIsolated) return 1;
        return Math.min(navigator.hardwareConcurrency || 1, 16);
    });
    RET((uint32_t)n);
#else
    RET((uint32_t)SDL_GetCPUCount());
#endif
}

// ?bench: the game prints a frame profile every 120 frames
void ext_web_bench(void) {
#ifdef __EMSCRIPTEN__
    // (?bench&nomarks: frame times only, without the per-part timers)
    RET((uint32_t)EM_ASM_INT({ return /[?&]bench/.test(location.search) && !/[?&]nomarks/.test(location.search) ? 1 : 0; }));
#else
    RET(0);
#endif
}

// ?beta: features still in testing are switched on
void ext_web_beta(void) {
#ifdef __EMSCRIPTEN__
    RET((uint32_t)EM_ASM_INT({ return /[?&]beta/.test(location.search) ? 1 : 0; }));
#else
    RET(getenv("CS_BETA") ? 1 : 0);
#endif
}

// a city opened by link: the shell fetched it into /save/shared.sav
void ext_web_open(void) {
#ifdef __EMSCRIPTEN__
    int has = EM_ASM_INT({ return Module.openedCity ? 1 : 0; });
    RETP(has ? "shared.sav" : NULL);
#else
    RETP(getenv("CS_OPEN"));        // (test builds: open a city by path)
#endif
}

// ------------------------------------------------------------------ start
void game_init_memory(void);
void game_main(void);
static uint8_t g_stack[8 << 20] __attribute__((aligned(16)));
static uint64_t g_argv[16];

static void start(int argc, char **argv) {
    game_init_memory();
    int n = argc < 15 ? argc : 15;
    for (int i = 0; i < n; i++) g_argv[i] = (uint64_t)(uintptr_t)argv[i];
    g_argv[n] = 0;
    // as if called from the C runtime: return slot pushed, rsp % 16 == 8
    R.r[4] = (uint64_t)(uintptr_t)(g_stack + sizeof g_stack - 64) - 8;
    R.r[7] = (uint64_t)n;
    R.r[6] = (uint64_t)(uintptr_t)g_argv;
    game_main();
}

#ifdef __EMSCRIPTEN__
static char *web_argv[] = { "cityssembly", NULL };
EMSCRIPTEN_KEEPALIVE void web_start(void) {
    EM_ASM(out('boot: game_main'));
    start(1, web_argv);
    // the game returns when you choose Quit
    EM_ASM({ if (window.cityQuit) window.cityQuit(); });
}
int main(void) {
    // saves live in IndexedDB: mount, pull them in, then start the game
    EM_ASM({
        out('boot: mounting saves');
        FS.mkdir('/save');
        FS.mount(IDBFS, {}, '/save');
        FS.chdir('/save');
        var started = false;
        var opened = null;
        function go(why) {
            if (started) return;
            started = true;
            // the opened city is written only now: the saves pulled in from
            // IndexedDB include the last one opened, and that sync can land
            // after the download (the old city then replaced the new one)
            if (opened) {
                FS.writeFile('/save/shared.sav', opened);
                Module.openedCity = true;
            }
            out('boot: ' + why + ', starting');
            if (Module.onGameStart) Module.onGameStart();
            Module.ccall('web_start', null, [], [], { async: true });
        }
        // ?load=URL opens a shared city file
        var m = location.search.match(/[?&]load=([^&]+)/);
        var pending = m ? 1 : 0;
        if (m) {
            fetch(decodeURIComponent(m[1])).then(function (r) {
                    if (!r.ok) throw new Error('HTTP ' + r.status);
                    return r.arrayBuffer();
                })
                .then(function (b) { opened = new Uint8Array(b); })
                .catch(function (e) { console.warn('open city', e); })
                .finally(function () { pending = 0; if (synced) go('city opened'); });
        }
        var synced = false;
        FS.syncfs(true, function (e) {
            if (e) console.warn('save load', e);
            synced = true;
            if (!pending) go('saves ready');
        });
        // never let a stuck IndexedDB keep the city from starting
        setTimeout(function () { synced = true; if (!pending) go('saves slow'); }, 2000);
    });
    emscripten_exit_with_live_runtime();
    return 0;
}
#else
int main(int argc, char **argv) { start(argc, argv); return 0; }
#endif
