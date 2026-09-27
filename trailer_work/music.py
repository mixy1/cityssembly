"""Trailer score, arranged from Cityssembly's own synthesized instruments."""
import numpy as np
import wave
from timeline import BPM, BEAT, BAR, SR, DURATION, bar

rng = np.random.default_rng(7)

# ---------------------------------------------------------------- samples
NAMES = ["rhodes_lo", "rhodes_hi", "bass", "guitar", "vibes", "marimba", "horn", "pad",
         "kick", "brush", "tap", "ride", "hat", "shaker", "rim", "rumble", "boom", "bell"]
ROOTS = {"rhodes_lo": 48, "rhodes_hi": 72, "bass": 33, "guitar": 57, "vibes": 72,
         "marimba": 72, "horn": 60, "pad": 60, "bell": 84}
S = {n: np.fromfile(f"samples/s{i}.raw", dtype=np.float32).astype(np.float64)
     for i, n in enumerate(NAMES)}

N = int((DURATION + 4) * SR)
bus = {k: np.zeros((N, 2)) for k in ("drums", "music", "fx", "lead")}


def pitched(name, note):
    s = S[name]
    root = ROOTS.get(name, 60)
    if name == "rhodes_lo" and note >= 60:
        s, root = S["rhodes_hi"], 72
    ratio = 2 ** ((note - root) / 12)
    if abs(ratio - 1) < 1e-6:
        return s
    idx = np.arange(0, len(s) - 1, ratio)
    return np.interp(idx, np.arange(len(s)), s)


def place(b, t, x, vel=1.0, pan=0.0, dur=None, fade=0.08):
    """add mono signal x at time t (s) into bus b"""
    x = x * vel
    if dur is not None:
        n = int(dur * SR)
        if n < len(x):
            f = int(fade * SR)
            x = x[:n + f].copy()
            if f > 0 and len(x) > n:
                ramp = np.linspace(1, 0, len(x) - n)
                x[n:] *= ramp
    i = int(t * SR)
    if i >= N:
        return
    x = x[:N - i]
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    bus[b][i:i + len(x), 0] += x * l
    bus[b][i:i + len(x), 1] += x * r


def note(b, inst, t, n, vel=1.0, pan=0.0, dur=None):
    place(b, t, pitched(inst, n), vel, pan, dur)


def hit(b, inst, t, vel=1.0, pan=0.0, rate=1.0):
    s = S[inst]
    if rate != 1.0:
        s = np.interp(np.arange(0, len(s) - 1, rate), np.arange(len(s)), s)
    place(b, t, s, vel, pan)


def B(bar_n, beat=0.0):
    return bar(bar_n) + beat * BEAT

# ---------------------------------------------------------------- synth fx
def lowpass_sweep(x, f0, f1):
    """one-pole lowpass with the cutoff sweeping from f0 to f1 (Hz)"""
    n = len(x)
    fc = np.geomspace(f0, f1, n)
    a = 1 - np.exp(-2 * np.pi * fc / SR)
    y = np.zeros(n)
    s = 0.0
    for i in range(n):
        s += a[i] * (x[i] - s)
        y[i] = s
    return y


def riser(t_end, length):
    n = int(length * SR)
    x = rng.standard_normal(n)
    y = lowpass_sweep(x, 200, 9000)
    y = y - lowpass_sweep(y, 80, 2000) * 0.7
    env = np.linspace(0, 1, n) ** 2.2
    tone = np.sin(2 * np.pi * np.cumsum(np.geomspace(110, 880, n)) / SR) * 0.25
    return t_end - length, (y * 0.9 + tone) * env * 0.55


def reverse_cymbal(t_end, length=1.6):
    r = S["ride"][:int(length * SR)][::-1].copy()
    r *= np.linspace(0, 1, len(r)) ** 1.5
    return t_end - len(r) / SR, r * 1.6


def impact(t, size=1.0):
    n = int(2.5 * SR)
    tt = np.arange(n) / SR
    sub = np.sin(2 * np.pi * np.cumsum(55 * np.exp(-tt * 2.0) + 28) / SR) * np.exp(-tt * 1.6)
    noise = lowpass_sweep(rng.standard_normal(int(0.6 * SR)), 6000, 150) * np.exp(-np.arange(int(0.6 * SR)) / SR * 6)
    place("fx", t, sub, 0.9 * size)
    place("fx", t, noise, 0.5 * size)
    hit("fx", "boom", t, 0.7 * size)
    hit("fx", "kick", t, 0.9 * size)
    hit("fx", "ride", t, 0.35 * size, 0.3)
    hit("fx", "ride", t, 0.35 * size, -0.3, rate=0.97)


def whoosh(t, length=0.45, vel=0.35):
    n = int(length * SR)
    x = rng.standard_normal(n)
    half = n // 2
    y = np.concatenate([lowpass_sweep(x[:half], 300, 7000), lowpass_sweep(x[half:], 7000, 300)])
    env = np.sin(np.linspace(0, np.pi, n)) ** 2
    place("fx", t - length / 2, y * env, vel)


def glitch(t, vel=0.25):
    n = int(0.12 * SR)
    x = np.sign(rng.standard_normal(n // 64 + 1)).repeat(64)[:n] * np.exp(-np.arange(n) / SR * 25)
    place("fx", t, x, vel, rng.uniform(-0.5, 0.5))

# ---------------------------------------------------------------- harmony
PROG = [
    [50, 57, 60, 64, 65],   # Dm9
    [46, 53, 57, 60, 62],   # Bbmaj9
    [53, 57, 60, 64, 67],   # Fmaj7(9)
    [48, 55, 62, 64, 67],   # Cadd9
]
ROOT = [38, 34, 41, 36]
ARP = [[62, 65, 69, 72], [58, 62, 65, 69], [60, 65, 69, 72], [60, 64, 67, 74]]
# vibes hook: (eighth position, note, length in eighths) per chord bar
HOOK = [
    [(0, 74, 2), (2, 77, 1), (3, 81, 1), (4, 79, 2), (6, 77, 1), (7, 76, 1)],
    [(0, 74, 2), (2, 77, 1), (3, 81, 1), (4, 84, 2), (6, 81, 1), (7, 79, 1)],
    [(0, 81, 2), (2, 79, 1), (3, 77, 1), (4, 76, 2), (6, 72, 1), (7, 74, 1)],
    [(0, 76, 2), (2, 74, 1), (3, 72, 1), (4, 74, 4)],
]
HORN = [
    [(0, 69, 3), (3, 67, 1), (4, 65, 4)],
    [(0, 65, 2), (2, 64, 2), (4, 62, 4)],
    [(0, 72, 3), (3, 69, 1), (4, 67, 4)],
    [(0, 67, 2), (2, 64, 2), (4, 62, 4)],
]


def chord_idx(b):
    return (b - 1) % 4


def pad_bar(b, vel=0.5):
    for n in PROG[chord_idx(b)]:
        note("music", "pad", B(b), n + 12, vel * 0.5, rng.uniform(-0.6, 0.6), dur=BAR)


def rhodes_chord(b, beat, length, vel=0.5):
    for i, n in enumerate(PROG[chord_idx(b)]):
        note("music", "rhodes_lo", B(b, beat) + i * 0.012, n, vel * 0.45, -0.2 + i * 0.1, dur=length * BEAT)


def arp_bar(b, vel=0.4, inst="vibes", every=0.5):
    notes = ARP[chord_idx(b)]
    k = 0
    beat = 0.0
    while beat < 4:
        note("music", inst, B(b, beat), notes[k % 4] + (12 if (k // 4) % 2 else 0), vel, 0.35 if k % 2 else -0.35, dur=every * BEAT * 2)
        beat += every
        k += 1


def hook_bar(b, vel=0.55, inst="vibes", octave=0):
    for pos, n, ln in HOOK[chord_idx(b)]:
        note("lead", inst, B(b, pos * 0.5), n + octave, vel, 0.15, dur=ln * 0.5 * BEAT)


def horn_bar(b, vel=0.6):
    for pos, n, ln in HORN[chord_idx(b)]:
        note("lead", "horn", B(b, pos * 0.5), n, vel, -0.1, dur=ln * 0.5 * BEAT)


def bass_bar(b, style="pump", vel=0.8):
    r = ROOT[chord_idx(b)]
    if style == "long":
        note("music", "bass", B(b), r, vel, 0, dur=BAR * 0.95)
        return
    if style == "pump":
        for e in range(8):
            n = r + (12 if e in (3, 7) else 0)
            note("music", "bass", B(b, e * 0.5), n, vel * (1.0 if e % 2 == 0 else 0.75), 0, dur=0.42 * BEAT)
    if style == "sync":
        for pos, oct_ in [(0, 0), (1.5, 0), (2.5, 12), (3.0, 0), (3.5, 7)]:
            note("music", "bass", B(b, pos), r + oct_, vel, 0, dur=0.45 * BEAT)


KICKS = []


def drums_bar(b, style="full", vel=1.0):
    if style in ("full", "four"):
        for k in range(4):
            hit("drums", "kick", B(b, k), 0.95 * vel)
            KICKS.append(B(b, k))
        if style == "full":
            hit("drums", "kick", B(b, 2.75), 0.55 * vel)
            for k in (1, 3):
                hit("drums", "tap", B(b, k), 0.8 * vel, -0.05)
                hit("drums", "brush", B(b, k), 0.45 * vel, 0.1)
                hit("drums", "rim", B(b, k), 0.35 * vel, -0.2)
            for e in range(16):
                v = (0.45 if e % 4 == 2 else 0.28) * vel
                hit("drums", "hat", B(b, e * 0.25), v, 0.35)
            for e in range(8):
                hit("drums", "shaker", B(b, e * 0.5 + 0.25), 0.25 * vel, -0.45)
            # ghost notes
            for g in (1.75, 3.25):
                hit("drums", "tap", B(b, g), 0.25 * vel, 0.1)
        else:
            for e in range(8):
                hit("drums", "hat", B(b, e * 0.5 + 0.5 * 0), 0.3 * vel if e % 2 else 0.18 * vel, 0.35)
    if style == "ride":
        for e in range(8):
            hit("drums", "ride", B(b, e * 0.5), (0.3 if e % 2 == 0 else 0.18) * vel, 0.4)


def snare_roll(b0, bars, vel=0.8):
    t0, t1 = B(b0), B(b0 + bars)
    t = t0
    step = BEAT / 2
    while t < t1 - 1e-6:
        prog = (t - t0) / (t1 - t0)
        hit("drums", "tap", t, (0.25 + 0.75 * prog) * vel, rng.uniform(-0.2, 0.2))
        step = BEAT / (2 if prog < 0.35 else 4 if prog < 0.7 else 8)
        t += step


def digital_ticks(b, vel=0.15):
    for e in range(16):
        if rng.random() < 0.55:
            hit("fx", "rim", B(b, e * 0.25), vel * rng.uniform(0.4, 1.0), rng.uniform(-0.8, 0.8), rate=rng.choice([1.0, 1.5, 2.0]))

# ================================================================ arrangement
# 1-4 intro: code on screen
for b in range(1, 5):
    pad_bar(b, 0.4)
    digital_ticks(b, 0.12 + 0.03 * b)
    if b >= 2:
        arp_bar(b, 0.18 + 0.05 * b, every=1.0 if b < 4 else 0.5)
note("lead", "bell", B(1), 74, 0.35, 0.3, dur=BAR * 2)
note("lead", "bell", B(3), 72, 0.35, -0.3, dur=BAR * 2)
s0, x = riser(B(5), BAR * 1.5)
place("fx", s0, x, 0.9)
s0, x = reverse_cymbal(B(5))
place("fx", s0, x, 0.8)

# 5-8 build: the valley and the first roads
impact(B(5), 0.55)
for b in range(5, 9):
    pad_bar(b, 0.45)
    arp_bar(b, 0.35)
    bass_bar(b, "long" if b < 7 else "pump", 0.65)
    rhodes_chord(b, 0, 3.5, 0.45)
    drums_bar(b, "four", 0.55 if b < 7 else 0.8)
snare_roll(8, 1, 0.7)
s0, x = riser(B(9), BAR * 2)
place("fx", s0, x, 1.0)
s0, x = reverse_cymbal(B(9), 2.0)
place("fx", s0, x, 1.0)

# 9-18 drop A: the city grows, cars, districts, info views
impact(B(9), 1.0)
for b in range(9, 19):
    drums_bar(b, "full", 1.0)
    bass_bar(b, "sync" if b % 2 else "pump", 0.8)
    rhodes_chord(b, 0.5, 0.9, 0.5)
    rhodes_chord(b, 2.5, 0.9, 0.42)
    pad_bar(b, 0.25)
    hook_bar(b, 0.55)
    if b % 4 == 1 and b > 9:
        hit("fx", "ride", B(b), 0.35, 0.3)
# info view cuts every half bar
for hb in (17, 17.5, 18, 18.5):
    glitch(B(hb), 0.3)
    whoosh(B(hb), 0.35, 0.3)
s0, x = reverse_cymbal(B(19), 1.2)
place("fx", s0, x, 0.6)

# 19-22 breakdown: sunset and night
for b in range(19, 23):
    pad_bar(b, 0.55)
    rhodes_chord(b, 0, 4, 0.45)
    bass_bar(b, "long", 0.45)
    arp_bar(b, 0.22, inst="marimba", every=0.5)
    if b >= 21:
        hook_bar(b, 0.35, inst="vibes", octave=-12)
drums_bar(21, "ride", 0.5)
drums_bar(22, "ride", 0.6)

# 23-24 build: the seasons turn
for b in (23, 24):
    pad_bar(b, 0.5)
    arp_bar(b, 0.4, every=0.25)
    bass_bar(b, "pump", 0.7)
    drums_bar(b, "four", 0.8)
snare_roll(23, 2, 0.9)
s0, x = riser(B(25) - BEAT, BAR * 2 - BEAT)
place("fx", s0, x, 1.1)
s0, x = reverse_cymbal(B(25) - BEAT * 0.5, 2.2)
place("fx", s0, x, 1.0)

# 25-30 drop B: meteor, interface, finale
impact(B(25), 1.3)
hit("fx", "rumble", B(25), 0.9)
for b in range(25, 31):
    drums_bar(b, "full", 1.05)
    bass_bar(b, "sync", 0.85)
    rhodes_chord(b, 0.5, 0.9, 0.45)
    rhodes_chord(b, 2.5, 0.9, 0.4)
    pad_bar(b, 0.3)
    horn_bar(b, 0.55)
    hook_bar(b, 0.35, octave=12)
for t in (27, 27.66, 28.33):
    whoosh(B(t), 0.3, 0.3)
    glitch(B(t), 0.25)
snare_roll(30, 1, 0.8)
s0, x = riser(B(31), BAR)
place("fx", s0, x, 1.0)

# 31-33 logo: final hit and ring out
impact(B(31), 1.4)
for n in PROG[0]:
    note("music", "pad", B(31), n + 12, 0.45, rng.uniform(-0.6, 0.6), dur=BAR * 2.5)
    note("music", "rhodes_lo", B(31), n, 0.3, 0, dur=BAR * 2)
note("lead", "bell", B(31), 74, 0.5, 0.2, dur=BAR * 2)
note("lead", "bell", B(31, 0.5), 81, 0.35, -0.2, dur=BAR * 2)
note("lead", "vibes", B(31, 1), 86, 0.35, 0.4, dur=BAR * 2)
note("music", "bass", B(31), 38, 0.8, 0, dur=BAR * 1.5)
for k, n in enumerate([62, 65, 69, 72, 74, 77, 81]):
    note("lead", "vibes", B(32) + k * BEAT / 3, n, 0.3, (k - 3) / 4, dur=BAR)
hit("fx", "kick", B(32, 2), 0.6)
hit("fx", "boom", B(32, 2), 0.4)

# ================================================================ mix
# sidechain the music bus to the kicks in the drops
duck = np.ones(N)
env_len = int(0.28 * SR)
shape = 1 - 0.55 * np.exp(-np.linspace(0, 5, env_len))
for t in KICKS:
    i = int(t * SR)
    j = min(N, i + env_len)
    duck[i:j] = np.minimum(duck[i:j], shape[:j - i])
bus["music"] *= duck[:, None]


def reverb(x, seconds=2.4, wet=0.25):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros_like(x)
    for ch in range(2):
        ir = rng.standard_normal(n) * np.exp(-t * 3.0 / seconds * 2.2)
        ir = lowpass_sweep(ir, 7000, 1500)
        ir[:int(0.012 * SR)] = 0
        L = len(x) + n
        size = 1 << (L - 1).bit_length()
        y = np.fft.irfft(np.fft.rfft(x[:, ch], size) * np.fft.rfft(ir, size), size)[:len(x)]
        out[:, ch] = y
    out /= np.max(np.abs(out)) + 1e-9
    return out * wet


mix = bus["drums"] * 0.8 + bus["music"] * 0.9 + bus["lead"] * 0.85 + bus["fx"] * 0.9
verb_in = bus["music"] * 0.6 + bus["lead"] * 0.8 + bus["drums"][:, :] * 0.15 + bus["fx"] * 0.3
mix += reverb(verb_in, 2.6, np.max(np.abs(mix)) * 0.22)
# glue: gentle saturation, then normalise to -1 dBFS
mix = np.tanh(mix / (np.max(np.abs(mix)) * 0.55))
mix = mix / np.max(np.abs(mix)) * 0.89
# fade tail
end = int((DURATION + 3.5) * SR)
mix = mix[:end]
mix[-int(1.5 * SR):] *= np.linspace(1, 0, int(1.5 * SR))[:, None]

pcm = (mix * 32767).astype(np.int16)
with wave.open("music.wav", "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("music.wav", len(mix) / SR, "s")
