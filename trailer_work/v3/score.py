"""Trailer v3 score, arranged on the game's own recorded band
(src/nyc_samples.bin: VCSL / VSCO-2-CE, CC0).

One theme for the city, in F major, carried through five acts:
  I   solo piano, one note per road tile, a string pad at dawn
  II  boom bap in D minor, the tenor sax takes the theme
  III salsa percussion and a piano montuno build the growth
  IV  noir: low strings, sirens, impacts, a hush before the meteor
  V   the whole band: brass play the theme, then solo piano, as it began
"""
import os
import re
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from timeline import (BEAT, BAR, SR, DURATION, bar as _bar, IMPACT_BAR, LOGO_BAR, PRE,  # noqa
                      DAWN, LIFE, GROW, TRIAL, FINAL, END)


def bar(b):
    """the story starts after the cold open"""
    return _bar(b + PRE)

SRC = os.path.join(HERE, "..", "..", "src")
rng = np.random.default_rng(90)

# ------------------------------------------------------------------ samples
RAW = np.fromfile(os.path.join(SRC, "nyc_samples.bin"), dtype=np.int16).astype(np.float32) / 32768
ZONES = {}
for m in re.finditer(r"dd (\d+), (\d+), (\d+), (\d+), (\d+), (\d+)\s+; (\w+)",
                     open(os.path.join(SRC, "nyc_samples.inc")).read()):
    off, ln, root, ls, le, rate = map(int, m.groups()[:6])
    ZONES.setdefault(m.group(7), []).append(dict(data=RAW[off:off + ln], root=root, ls=ls, le=le, rate=rate))

N = int((DURATION + 6) * SR)
BUS = {k: np.zeros((N, 2), np.float32) for k in ("keys", "bass", "lead", "brass", "strings", "drums", "perc", "fx", "amb")}


def t_of(b, beat=0.0):
    """time of bar b (1-based), plus beats"""
    return bar(b) + beat * BEAT


def place(bus, t, x, pan=0.0, gain=1.0):
    i = int(t * SR)
    if i >= N or i + len(x) <= 0:
        return
    if i < 0:
        x = x[-i:]
        i = 0
    x = x[:N - i] * gain
    l = np.cos((pan + 1) * np.pi / 4) * 1.41
    r = np.sin((pan + 1) * np.pi / 4) * 1.41
    BUS[bus][i:i + len(x), 0] += x * l
    BUS[bus][i:i + len(x), 1] += x * r


def pitched(inst, midi, dur, rel=0.25):
    """resample the nearest zone to midi; loop sustained zones"""
    zs = ZONES[inst]
    z = min(zs, key=lambda z: abs(z["root"] - midi) + (0.4 if z["root"] > midi else 0))
    ratio = 2 ** ((midi - z["root"]) / 12) * z["rate"] / SR
    need = int((dur + rel) * SR * ratio) + 4
    d = z["data"]
    if z["le"] > z["ls"] + 100 and need > len(d):
        loop = d[z["ls"]:z["le"]]
        reps = (need - len(d)) // len(loop) + 2
        d = np.concatenate([d] + [loop] * reps)
    idx = np.arange(0, min(need, len(d) - 1), ratio)
    y = np.interp(idx, np.arange(len(d)), d).astype(np.float32)
    n_sus = int(dur * SR)
    n_rel = int(rel * SR)
    if len(y) > n_sus:
        env = np.ones(len(y), np.float32)
        r = np.linspace(1, 0, n_rel, dtype=np.float32)
        env[n_sus:n_sus + n_rel] = r[:max(0, min(n_rel, len(y) - n_sus))]
        env[n_sus + n_rel:] = 0
        y = y * env
    a = min(len(y), int(0.004 * SR))
    y[:a] *= np.linspace(0, 1, a, dtype=np.float32)
    return y


def note(bus, inst, t, midi, dur, vel=0.8, pan=0.0, rel=0.25):
    place(bus, t, pitched(inst, midi, dur, rel), pan, vel)


def hit(bus, inst, t, vel=0.8, pan=0.0, rate=1.0):
    z = ZONES[inst][0]
    r = z["rate"] / SR * rate
    d = z["data"]
    y = np.interp(np.arange(0, len(d) - 1, r), np.arange(len(d)), d).astype(np.float32)
    place(bus, t, y, pan, vel)


NOTE = {n: i for i, n in enumerate("C C# D D# E F F# G G# A A# B".split())}
NOTE.update({"Db": 1, "Eb": 3, "Gb": 6, "Ab": 8, "Bb": 10})


def m(s):
    """'F4' -> midi"""
    mm = re.match(r"([A-G][b#]?)(-?\d)", s)
    return NOTE[mm.group(1)] + 12 * (int(mm.group(2)) + 1)


def chord(names):
    return [m(n) for n in names.split()]


# ------------------------------------------------------------------ synth sound design
def noise(n):
    return rng.standard_normal(n).astype(np.float32)


def lowpass(x, cutoff):
    """one-pole low pass (cutoff Hz, scalar or per-sample array)"""
    a = np.exp(-2 * np.pi * np.asarray(cutoff, np.float32) / SR)
    y = np.empty_like(x)
    acc = 0.0
    if np.ndim(a) == 0:
        # vectorised with lfilter-like recursion via cumulative trick is
        # awkward; this loop is fine for a few seconds of audio
        for i in range(len(x)):
            acc = a * acc + (1 - a) * x[i]
            y[i] = acc
    else:
        for i in range(len(x)):
            acc = a[i] * acc + (1 - a[i]) * x[i]
            y[i] = acc
    return y


def lp_fast(x, cutoff):
    """FFT brick-ish low pass for long buffers"""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x)).astype(np.float32)


def hp_fast(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= (f / cutoff) ** 4 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x)).astype(np.float32)


def wind(t0, t1, level):
    n = int((t1 - t0) * SR)
    x = lp_fast(noise(n), 500) * 3
    tt = np.arange(n) / SR
    env = (0.55 + 0.45 * np.sin(tt * 0.7) * np.sin(tt * 0.31 + 1)) * level
    fade = np.minimum(1, np.minimum(tt / 1.5, (tt[-1] - tt) / 2.5))
    x *= env * fade
    place("amb", t0, x, -0.3, 1)
    place("amb", t0 + 0.37, lp_fast(noise(n), 700) * 2 * env * fade, 0.4, 1)


def bird(t, pan):
    """a two-note chirp"""
    for k in range(rng.integers(2, 5)):
        d = rng.uniform(0.05, 0.11)
        n = int(d * SR)
        f0 = rng.uniform(2800, 4200)
        f = np.linspace(f0, f0 * rng.uniform(1.1, 1.5), n)
        ph = np.cumsum(2 * np.pi * f / SR)
        env = np.sin(np.linspace(0, np.pi, n)) ** 2
        place("amb", t + k * rng.uniform(0.09, 0.16), (np.sin(ph) * env * 0.06).astype(np.float32), pan)


def boom(t, level=1.0, pitch=48.0, length=2.5):
    """cinematic impact: sub drop, body, noise crack"""
    n = int(length * SR)
    tt = np.arange(n) / SR
    f = pitch * (1 + 2.5 * np.exp(-tt * 9))
    sub = np.sin(np.cumsum(2 * np.pi * f / SR)) * np.exp(-tt * 1.4)
    crack = lp_fast(noise(n), 2500) * np.exp(-tt * 14) * 1.2
    body = lp_fast(noise(n), 180) * np.exp(-tt * 2.2) * 2.5
    x = (sub * 0.9 + crack * 0.5 + body * 0.6).astype(np.float32) * level
    place("fx", t, x, 0, 1)


def riser(t0, t1, level=0.5):
    n = int((t1 - t0) * SR)
    tt = np.linspace(0, 1, n, dtype=np.float32)
    x = noise(n)
    x = hp_fast(x, 400)
    # sweep: blend of low and high passed noise
    lo = lp_fast(x, 1500)
    y = lo * (1 - tt) + x * tt
    y *= (tt ** 2.2) * level
    f = 200 + 1800 * tt ** 2
    y += (np.sin(np.cumsum(2 * np.pi * f / SR)) * 0.25 * tt ** 3 * level).astype(np.float32)
    place("fx", t0, y.astype(np.float32), 0, 1)


def reverse_swell(t_end, length=1.2, level=0.4):
    n = int(length * SR)
    tt = np.linspace(0, 1, n, dtype=np.float32)
    x = lp_fast(noise(n), 5000) * tt ** 3 * level
    place("fx", t_end - length, x, 0, 1)


def whistle(t0, t1, level=0.3):
    """the meteor falling: a descending whistle with a rumble"""
    n = int((t1 - t0) * SR)
    tt = np.linspace(0, 1, n)
    f = 2200 * (1 - tt) ** 1.6 + 180
    x = np.sin(np.cumsum(2 * np.pi * f / SR)) * (0.2 + 0.8 * tt) * level
    rumble = lp_fast(noise(n), 120) * tt ** 2 * level * 4
    place("fx", t0, (x + rumble).astype(np.float32), 0.1, 1)


def tinnitus(t, length=3.0, level=0.08):
    n = int(length * SR)
    tt = np.arange(n) / SR
    x = np.sin(2 * np.pi * 3950 * tt) * np.exp(-tt * 1.3) * level
    place("fx", t, x.astype(np.float32), 0, 1)


def blip(t, f=1320, level=0.12):
    n = int(0.09 * SR)
    tt = np.arange(n) / SR
    x = (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(4 * np.pi * f * tt)) * np.exp(-tt * 40) * level
    place("fx", t, x.astype(np.float32), 0.2, 1)


def crackle(t0, t1, level=0.15):
    n = int((t1 - t0) * SR)
    x = np.zeros(n, np.float32)
    k = rng.integers(0, n, int((t1 - t0) * 90))
    x[k] = rng.uniform(-1, 1, len(k)) * 3
    x = lp_fast(x, 3500) + lp_fast(noise(n), 900) * 0.5
    tt = np.linspace(0, 1, n)
    x *= np.minimum(1, np.minimum(tt * 5, (1 - tt) * 5)) * level
    place("fx", t0, x.astype(np.float32), -0.2, 1)


def whoosh(t, level=0.25, length=0.7):
    n = int(length * SR)
    tt = np.linspace(0, 1, n)
    x = lp_fast(noise(n), 1600) * np.sin(np.pi * tt) ** 2 * level
    place("fx", t - length * 0.6, x.astype(np.float32), 0, 1)


# ------------------------------------------------------------------ I. dawn
def act1():
    D = DAWN
    wind(t_of(D) - 0.3, t_of(LIFE) - 0.2, 0.05)
    for tb in (0.3, 0.8, 1.5, 2.4, 3.2):
        bird(t_of(D + tb), rng.uniform(-0.7, 0.7))
    note("keys", "piano", t_of(D), m("F1"), 3, 0.35, -0.2, rel=2)
    note("keys", "piano", t_of(D), m("C2"), 3, 0.25, -0.1, rel=2)
    note("keys", "piano", t_of(D, 2), m("C6"), 1.2, 0.12, 0.4, rel=2)
    for ch, b0, b1 in ((chord("F3 C4 A4"), 0, 2), (chord("D3 A3 F4"), 2, 3), (chord("Bb2 F3 D4"), 3, 3.5),
                       (chord("C3 G3 E4"), 3.5, 3.9)):
        for i, n in enumerate(ch):
            note("strings", "strings", t_of(D + b0), n, (b1 - b0) * BAR, 0.14, (-0.5, 0, 0.5)[i], rel=0.8)
    # the road: every eighth note is a tile (two bars), the theme on top
    melody = [(1, 0, "F5", 3), (1, 3, "A5", 1), (1, 4, "C6", 4),
              (2, 0, "D6", 6), (2, 6, "C6", 2),
              (3, 0, "Bb5", 3), (3, 3, "A5", 1), (3, 4, "G5", 2), (3, 6, "A5", 2)]
    mel = {(b, e): (nn, ln) for b, e, nn, ln in melody}
    lhs = {1: chord("F2 C3 A3"), 2: chord("D2 A2 F3"), 3: chord("Bb1 F2 D3")}
    for k in range(24):
        bb, e = 1 + k // 8, k % 8
        t = t_of(D + bb, e * 0.5)
        ch = lhs[bb] if not (bb == 3 and e >= 4) else chord("C2 G2 E3")
        vel = 0.24 if bb < 3 else 0.18
        note("keys", "piano", t, ch[[0, 1, 2, 1][k % 4]] + (12 if e >= 4 else 0), BEAT * 0.9, vel, -0.25, rel=0.6)
        if (bb, e) in mel:
            nn, ln = mel[(bb, e)]
            note("keys", "piano", t, m(nn), ln * BEAT / 2, 0.55, 0.15, rel=0.8)
    for k in range(4):
        hit("perc", "claves", t_of(D + 3, 0.5 + k * 0.5), 0.08, rng.uniform(-0.5, 0.5), 0.7)
    reverse_swell(t_of(LIFE), 1.2, 0.35)


# ------------------------------------------------------------------ II. life
SW = 0.62   # swing: the off 16th lands at 62% of the eighth


def s16(k):
    e, h = divmod(k, 2)
    return e * 0.5 + (SW * 0.5 if h else 0)


def act2():
    prog = ["Dm9", "Bbmaj7", "Gm9", "A7"]
    voic = {"Dm9": chord("F3 A3 C4 E4"), "Bbmaj7": chord("F3 A3 D4 Bb3"), "Gm9": chord("F3 Bb3 D4 A4"),
            "A7": chord("G3 C#4 E4 A3")}
    roots = {"Dm9": m("D2"), "Bbmaj7": m("Bb1"), "Gm9": m("G1"), "A7": m("A1")}
    for i, c in enumerate(prog):
        b = LIFE + i
        for k in (0, 7, 10):
            hit("drums", "kick", t_of(b, s16(k)), 0.95 if k == 0 else 0.75)
        for k in (4, 12):
            hit("drums", "snare", t_of(b, s16(k)), 0.8, 0.05)
        for k in range(0, 16, 2):
            hit("drums", "hat", t_of(b, s16(k)), 0.35 if k % 4 == 0 else 0.22, 0.25)
        hit("drums", "hatopen", t_of(b, s16(14)), 0.16, 0.3)
        hit("perc", "clap", t_of(b), 0.18, -0.2)
        hit("perc", "clap", t_of(b, 2), 0.14, 0.2)
        for beat, v in ((0, 0.34), (1.5 + (SW - 0.5), 0.26)):
            for n in voic[c]:
                note("keys", "piano", t_of(b, beat), n, BEAT * 0.7, v, -0.15, rel=0.3)
        r = roots[c]
        note("bass", "bass", t_of(b), r, BEAT * 1.4, 0.95, 0, rel=0.1)
        note("bass", "bass", t_of(b, s16(7)), r + 12, BEAT * 0.4, 0.6, 0, rel=0.08)
        note("bass", "bass", t_of(b, s16(10)), r + 7, BEAT * 0.9, 0.75, 0, rel=0.1)
        note("bass", "bass", t_of(b, s16(14)), r + (5 if i % 2 else 3), BEAT * 0.4, 0.55, 0, rel=0.08)
    z = ZONES["vinyl"][0]["data"]
    loop = np.tile(z, int(4 * BAR * SR / len(z)) + 2)[:int(4 * BAR * SR)]
    place("amb", t_of(LIFE), loop, 0, 0.16)
    sax = [(0, 0, "A4", 3), (0, 3, "C5", 1), (0, 4, "E5", 4),
           (1, 0, "F5", 6), (1, 6, "E5", 2),
           (2, 0, "D5", 3), (2, 3, "C5", 1), (2, 4, "Bb4", 4),
           (3, 0, "C#5", 4), (3, 4, "E5", 2), (3, 6, "A5", 2)]
    for b, e, nn, ln in sax:
        note("lead", "sax", t_of(LIFE + b, e * 0.5 + (0.06 if e % 2 else 0)), m(nn), ln * BEAT / 2 * 0.95, 0.5, 0.1, rel=0.2)
    whoosh(t_of(GROW), 0.3)


# ------------------------------------------------------------------ III. growth
def act3():
    G = GROW
    prog = [("F", 0), ("Bb", 1), ("C", 2), ("Dm", 2.5), ("Bb", 3)]
    tri = {"F": chord("F3 A3 C4"), "Bb": chord("F3 Bb3 D4"), "C": chord("E3 G3 C4"), "Dm": chord("F3 A3 D4")}
    roots = {"F": m("F1"), "Bb": m("Bb1"), "C": m("C2"), "Dm": m("D2")}
    for idx, (c, b0) in enumerate(prog):
        b1 = prog[idx + 1][1] if idx + 1 < len(prog) else 3.5
        energy = min(1.0, b0 / 3)
        pat = [0, 2, 1, 2, 0, 2, 1, 2]
        for k in range(int((b1 - b0) * 8)):
            n = tri[c][pat[k % 8]] + 12
            t = t_of(G + b0, k * 0.5)
            note("keys", "piano", t, n, BEAT * 0.4, 0.28 + 0.1 * energy, -0.3, rel=0.12)
            note("keys", "piano", t, n + 12, BEAT * 0.4, 0.2 + 0.08 * energy, -0.3, rel=0.12)
        r = roots[c]
        for k in range(int((b1 - b0) * 4)):
            note("bass", "bass", t_of(G + b0, k), r + (0, 7, 12, 7)[k % 4], BEAT * 0.9, 0.85, 0, rel=0.1)
            hit("perc", "cowbell", t_of(G + b0, k), 0.25 + 0.15 * energy, 0.35)
            hit("drums", "kick", t_of(G + b0, k), 0.6 + 0.3 * energy)
            hit("perc", "conga" if k % 2 else "tumba", t_of(G + b0, k + 0.5), 0.4, -0.3)
            if k % 2 == 1:
                hit("drums", "snare", t_of(G + b0, k), 0.5 + 0.2 * energy)
        for k in range(int((b1 - b0) * 8)):
            hit("perc", "guiro" if k % 4 == 0 else "hat", t_of(G + b0, k * 0.5), 0.14 + 0.1 * energy, 0.4)
        for j, n in enumerate(tri[c]):
            note("strings", "strings", t_of(G + b0), n + 12, (b1 - b0) * BAR, 0.14 + 0.14 * energy, (-0.5, 0, 0.5)[j], rel=0.5)
        if b0 >= 1:
            for beat in (0, 2.5):
                if beat < (b1 - b0) * 4:
                    for n in tri[c]:
                        note("brass", "trumpet", t_of(G + b0, beat), n + 12, BEAT * 0.35, 0.34 + 0.12 * energy, 0.2, rel=0.12)
    for i in range(4):
        blip(t_of(G + 2.5 + i * 0.25), 1100 + 160 * i)
    W = G + 3.5
    for n in chord("C3 E3 G3 Bb3 C4"):
        note("brass", "trumpet", t_of(W), n + 12, BEAT * 0.5, 0.55, 0.2, rel=0.5)
        note("strings", "strings", t_of(W), n, BEAT * 1.0, 0.3, 0, rel=1.2)
    note("brass", "trombone", t_of(W), m("C3"), BEAT, 0.6, -0.2, rel=0.4)
    hit("drums", "kick", t_of(W), 1.0)
    hit("drums", "snare", t_of(W), 0.7)
    riser(t_of(G + 1.5), t_of(W), 0.35)
    boom(t_of(W), 0.45, 55, 2.0)


# ------------------------------------------------------------------ IV. trials
def act4():
    T = TRIAL
    for b0, b1, ch in ((0, 1, chord("D2 A2 F3")), (1, 2, chord("Bb1 F2 D3")), (2, 2.6, chord("G1 D2 Bb2"))):
        for j, n in enumerate(ch):
            note("strings", "strings", t_of(T + b0), n + 12, (b1 - b0) * BAR, 0.17, (-0.4, 0, 0.4)[j], rel=0.8)
    for b, n in ((0, "D1"), (1, "Bb0"), (2, "G0")):
        note("keys", "piano", t_of(T + b), m(n), BAR, 0.38, -0.1, rel=1)
        note("keys", "piano", t_of(T + b), m(n) + 12, BAR, 0.26, -0.1, rel=1)
        boom(t_of(T + b), 0.35, 42, 2.2)
    sax = [(0, 0, "A4", 4), (0, 4, "C5", 2), (0, 6, "E5", 2), (1, 0, "F5", 6), (1, 6, "E5", 2)]
    for b, e, nn, ln in sax:
        note("lead", "sax", t_of(T + b, e * 0.5), m(nn), ln * BEAT / 2 * 0.97, 0.36, 0.15, rel=0.6)
    z = ZONES["siren"][0]
    siren = np.interp(np.arange(0, len(z["data"]) - 1, z["rate"] / SR), np.arange(len(z["data"])), z["data"]).astype(np.float32)
    place("fx", t_of(T + 0.4), siren, -0.5, 0.14)
    place("fx", t_of(T + 1.3), siren, 0.4, 0.18)
    crackle(t_of(T + 1), t_of(T + 2.2), 0.12)
    whistle(t_of(T + 2.3), t_of(IMPACT_BAR) - 0.02, 0.22)
    riser(t_of(T + 2), t_of(IMPACT_BAR) - 0.3, 0.2)
    boom(t_of(IMPACT_BAR), 1.25, 38, 4.0)
    hit("drums", "kick", t_of(IMPACT_BAR), 1.0, 0, 0.6)
    tinnitus(t_of(IMPACT_BAR) + 0.3, 1.2, 0.05)


# ------------------------------------------------------------------ V. finale
def act5():
    F = FINAL
    prog = [("F", 0), ("Dm", 0.5), ("Bb", 1), ("C", 1.5), ("Dm", 2), ("Bb", 2.5), ("C", 3)]
    tri = {"F": chord("F3 A3 C4"), "Bb": chord("F3 Bb3 D4"), "C": chord("E3 G3 C4"), "Dm": chord("F3 A3 D4")}
    roots = {"F": m("F1"), "Bb": m("Bb1"), "C": m("C2"), "Dm": m("D2")}
    L = LOGO_BAR - F
    reverse_swell(t_of(F), 0.8, 0.5)
    for idx, (c, b0) in enumerate(prog):
        b1 = prog[idx + 1][1] if idx + 1 < len(prog) else L
        dur = (b1 - b0) * BAR
        for j, n in enumerate(tri[c]):
            note("strings", "strings", t_of(F + b0), n + 12, dur, 0.32, (-0.5, 0, 0.5)[j], rel=0.4)
            note("strings", "strings", t_of(F + b0), n, dur, 0.22, (0.5, 0, -0.5)[j], rel=0.4)
        r = roots[c]
        for k in range(int(round((b1 - b0) * 4))):
            note("bass", "bass", t_of(F + b0, k), r + (0, 12, 7, 12)[k % 4], BEAT * 0.9, 0.9, 0, rel=0.08)
            note("keys", "piano", t_of(F + b0, k + 0.5), tri[c][k % 3] + 12, BEAT * 0.4, 0.3, -0.3, rel=0.1)
        for n in tri[c]:
            note("keys", "piano", t_of(F + b0), n, BEAT * 1.6, 0.4, -0.3, rel=0.4)
    for k in range(int(L * 4)):
        t = t_of(F, k)
        hit("drums", "kick", t, 1.0)
        hit("drums", "ridebell" if k % 4 == 0 else "ride", t, 0.25, 0.3)
        if k % 2 == 1:
            hit("drums", "snare", t, 0.7)
        hit("perc", "conga" if k % 2 else "tumba", t_of(F, k + 0.5), 0.2, -0.4)
    theme = [(0, 0, "F5", 3), (0, 3, "A5", 1), (0, 4, "C6", 4),
             (1, 0, "D6", 6), (1, 6, "C6", 2),
             (2, 0, "A5", 3), (2, 3, "C6", 1), (2, 4, "F6", 4),
             (3, 0, "E6", 3), (3, 3, "D6", 1), (3, 4, "E6", 4)]
    third = {"F5": "A4", "A5": "F5", "C6": "A5", "D6": "F5", "F6": "C6", "E6": "C6"}
    for b, e, nn, ln in theme:
        t = t_of(F + b * 0.875, e * 0.5 * 0.875)
        d = ln * BEAT / 2 * 0.9
        note("brass", "trumpet", t, m(nn) - 12, d, 0.8, 0.15, rel=0.25)
        note("brass", "trumpet", t, m(third[nn]) - 12, d, 0.55, -0.1, rel=0.25)
        note("brass", "trombone", t, m(nn) - 24, d, 0.55, -0.25, rel=0.25)
        note("lead", "strings", t, m(nn), d, 0.3, 0.3, rel=0.4)
    Lt = t_of(LOGO_BAR)
    for n in chord("F2 C3 F3 A3 C4 F4 A4 C5"):
        note("strings", "strings", Lt, n, BAR * 2, 0.26, rng.uniform(-0.6, 0.6), rel=2.5)
    for n in chord("F4 A4 C5 F5"):
        note("brass", "trumpet", Lt, n, BAR * 1.1, 0.5, rng.uniform(-0.3, 0.3), rel=1.5)
    for n in chord("F2 C3 F3"):
        note("brass", "trombone", Lt, n, BAR * 1.1, 0.5, -0.2, rel=1.5)
    note("bass", "bass", Lt, m("F1"), BAR * 1.5, 1.0, 0, rel=1.5)
    for n in chord("F2 C3 F3 A3 C4 F4"):
        note("keys", "piano", Lt, n, BAR * 2, 0.45, -0.2, rel=3)
    hit("drums", "kick", Lt, 1.0)
    hit("drums", "ridebell", Lt, 0.5, 0.3)
    boom(Lt, 0.6, 44, 3.0)
    for k, n in enumerate(chord("C6 F6 A6 C7")):
        note("keys", "piano", Lt + 0.15 + k * 0.09, n, 2, 0.18, 0.5, rel=2)
    for k, nn in enumerate(("F5", "A5", "C6", "D6")):
        note("keys", "piano", t_of(LOGO_BAR + 1.5, k * 0.5), m(nn), BEAT * (2 if k == 3 else 0.5), 0.3, 0.1, rel=2)


# ------------------------------------------------------------------ cold open (one bar before the story)
def cold_open():
    t0 = 0.0
    for n in chord("F2 C3 F3 A3 C4 F4 A4"):
        note("strings", "strings", t0, n, BAR, 0.24, rng.uniform(-0.6, 0.6), rel=1.0)
    for n in chord("F3 A3 C4"):
        note("brass", "trumpet", t0 + 0.05, n + 12, BAR * 0.7, 0.34, rng.uniform(-0.3, 0.3), rel=0.8)
    note("brass", "trombone", t0 + 0.05, m("F2"), BAR * 0.7, 0.4, -0.2, rel=0.8)
    note("bass", "bass", t0, m("F1"), BAR, 0.8, 0, rel=0.8)
    for n in chord("F2 C3 F3 A3"):
        note("keys", "piano", t0, n, BAR, 0.4, -0.2, rel=1.5)
    boom(t0, 0.5, 44, 2.5)
    reverse_swell(BAR - 0.05, 0.6, 0.2)


# ------------------------------------------------------------------ mix
def reverb_ir(seconds=2.6, predelay=0.02):
    n = int(seconds * SR)
    tt = np.arange(n) / SR
    ir = np.zeros((n, 2), np.float32)
    for c in range(2):
        x = noise(n) * np.exp(-tt * 3.2 / seconds * 2.2)
        ir[:, c] = lp_fast(x, 6000)
    ir[:int(predelay * SR)] = 0
    ir /= np.sqrt((ir ** 2).sum(axis=0))
    return ir


def convolve(x, ir):
    n = len(x) + len(ir)
    nf = 1 << (n - 1).bit_length()
    out = np.zeros((n, 2), np.float32)
    for c in range(2):
        out[:, c] = np.fft.irfft(np.fft.rfft(x[:, c], nf) * np.fft.rfft(ir[:, c], nf), nf)[:n]
    return out[:len(x)]


def main():
    cold_open()
    act1()
    act3()
    act4()
    act5()
    gains = {"keys": 0.9, "bass": 0.8, "lead": 0.9, "brass": 0.75, "strings": 0.7, "drums": 0.75,
             "perc": 0.55, "fx": 0.9, "amb": 0.9}
    sends = {"keys": 0.35, "bass": 0.05, "lead": 0.3, "brass": 0.3, "strings": 0.45, "drums": 0.12,
             "perc": 0.15, "fx": 0.2, "amb": 0.0}
    dry = np.zeros((N, 2), np.float32)
    wet_in = np.zeros((N, 2), np.float32)
    for k, b in BUS.items():
        dry += b * gains[k]
        wet_in += b * gains[k] * sends[k]
    wet = convolve(wet_in, reverb_ir())
    mix = dry + wet * 0.6
    # glue: gentle compression via soft clip, then peak normalise
    peak = np.max(np.abs(mix))
    mix = mix / peak * 1.6
    mix = np.tanh(mix) / np.tanh(1.6)
    mix *= 0.89                               # -1 dBFS
    n = int((DURATION + 3) * SR)
    mix = mix[:n]
    fade = int(2.5 * SR)
    mix[-fade:] *= np.linspace(1, 0, fade)[:, None]
    out = (np.clip(mix, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(HERE, "score.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(out.tobytes())
    print(path, f"{len(out) / SR:.1f}s")


if __name__ == "__main__":
    main()
