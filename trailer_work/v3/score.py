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
from timeline import BEAT, BAR, SR, DURATION, bar as _bar, IMPACT_BAR, LOGO_BAR, PRE  # noqa


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


# ------------------------------------------------------------------ I. dawn (bars 1-8)
def act1():
    wind(0.0, bar(9) - 0.2, 0.05)
    for tb in (1.4, 1.9, 2.6, 3.3, 4.1, 5.2, 6.0):
        bird(t_of(tb), rng.uniform(-0.7, 0.7))
    # a low open fifth, then the pad
    note("keys", "piano", t_of(1), m("F1"), 5, 0.35, -0.2, rel=2)
    note("keys", "piano", t_of(1), m("C2"), 5, 0.25, -0.1, rel=2)
    note("keys", "piano", t_of(2, 2), m("C6"), 1.5, 0.12, 0.4, rel=2)
    note("keys", "piano", t_of(3), m("A5"), 1.5, 0.12, 0.3, rel=2)
    for ch, b0, b1 in ((chord("F3 C4 A4"), 2, 4), (chord("F3 C4 A4"), 4, 5), (chord("D3 A3 F4"), 5, 6),
                       (chord("Bb2 F3 D4"), 6, 6.5), (chord("C3 G3 E4"), 6.5, 7), (chord("F3 C4 A4"), 7, 8),
                       (chord("D3 A3 F4"), 8, 8.5), (chord("Bb2 F3 D4"), 8.5, 8.75)):
        for i, n in enumerate(ch):
            v = 0.16 if b0 > 2 else 0.1
            note("strings", "strings", t_of(b0), n, (b1 - b0) * BAR, v, (-0.5, 0, 0.5)[i], rel=0.9)
    # the road: every eighth note is a tile (bars 3.5 - 7), the theme on top
    melody = [  # (bar, eighth, note, eighths)
        (3.5, 0, "F4", 1), (3.5, 1, "A4", 1), (3.5, 2, "C5", 1), (3.5, 3, "F5", 1),
        (4, 0, "F5", 3), (4, 3, "A5", 1), (4, 4, "C6", 4),
        (5, 0, "D6", 6), (5, 6, "C6", 2),
        (6, 0, "Bb5", 3), (6, 3, "A5", 1), (6, 4, "G5", 4),
        (7, 0, "A5", 8)]
    chords_by_bar = {3: chord("F2 C3 A3"), 4: chord("F2 C3 A3"), 5: chord("D2 A2 F3"), 6: chord("Bb1 F2 D3"),
                     6.5: chord("C2 G2 E3"), 7: chord("F2 C3 A3")}
    mel_at = {}
    for b, e, nn, ln in melody:
        mel_at[round(b + e / 8, 4)] = (nn, ln)
    for k in range(28):
        b = 3.5 + k / 8
        t = t_of(b)
        key = round(b, 4)
        cb = 6.5 if 6.5 <= b < 7 else (3 if b < 4 else int(b))
        ch = chords_by_bar[cb]
        # left hand: rolling chord tones
        lh = ch[[0, 1, 2, 1][k % 4]] + (12 if k % 8 >= 4 else 0)
        note("keys", "piano", t, lh, BEAT * 0.9, 0.22, -0.25, rel=0.6)
        if key in mel_at:
            nn, ln = mel_at[key]
            note("keys", "piano", t, m(nn), ln * BEAT / 2, 0.55, 0.15, rel=0.8)
    # bar 7: the first houses - a low bell of hammers and the last of the theme
    for k in range(6):
        hit("perc", "claves", t_of(7, 0.5 + k * 0.5), 0.08, rng.uniform(-0.5, 0.5), 0.7)
    note("keys", "piano", t_of(8), m("D5"), BEAT * 2, 0.4, 0.1, rel=1)
    note("keys", "piano", t_of(8, 2), m("C5"), BEAT * 1.5, 0.35, 0.1, rel=0.6)
    note("keys", "piano", t_of(8), m("D2"), BEAT * 3, 0.3, -0.2, rel=0.6)
    reverse_swell(t_of(9), 1.5, 0.35)


# ------------------------------------------------------------------ II. life (bars 9-16)
SW = 0.62   # swing: the off 16th lands at 62% of the eighth


def s16(k):
    """16th note k within the bar -> beats, swung"""
    e, h = divmod(k, 2)
    return e * 0.5 + (SW * 0.5 if h else 0)


def act2():
    prog = ["Dm9", "Bbmaj7", "Gm9", "A7"] * 2
    voic = {"Dm9": chord("F3 A3 C4 E4"), "Bbmaj7": chord("F3 A3 D4 Bb3"), "Gm9": chord("F3 Bb3 D4 A4"),
            "A7": chord("G3 C#4 E4 A3")}
    roots = {"Dm9": m("D2"), "Bbmaj7": m("Bb1"), "Gm9": m("G1"), "A7": m("A1")}
    for i, c in enumerate(prog):
        b = 9 + i
        # drums: boom bap
        for k in (0, 7, 10):
            hit("drums", "kick", t_of(b, s16(k)), 0.9 if k == 0 else 0.7)
        for k in (4, 12):
            hit("drums", "snare", t_of(b, s16(k)), 0.75, 0.05)
        for k in range(0, 16, 2):
            hit("drums", "hat", t_of(b, s16(k)), 0.35 if k % 4 == 0 else 0.22, 0.25)
        hit("drums", "hat", t_of(b, s16(15)), 0.15, 0.3)
        if i % 2 == 1:
            hit("drums", "hatopen", t_of(b, s16(14)), 0.18, 0.3)
        # piano chops: on 1 and the and of 2
        for beat, v in ((0, 0.34), (1.5 + (SW - 0.5), 0.26)):
            for n in voic[c]:
                note("keys", "piano", t_of(b, beat), n, BEAT * 0.7, v, -0.15, rel=0.3)
        # bass: root, octave pickup, fifth slide
        r = roots[c]
        note("bass", "bass", t_of(b), r, BEAT * 1.4, 0.95, 0, rel=0.1)
        note("bass", "bass", t_of(b, s16(7)), r + 12, BEAT * 0.4, 0.6, 0, rel=0.08)
        note("bass", "bass", t_of(b, s16(10)), r + 7, BEAT * 0.9, 0.75, 0, rel=0.1)
        note("bass", "bass", t_of(b, s16(14)), r + (5 if i % 2 else 3), BEAT * 0.4, 0.55, 0, rel=0.08)
    # vinyl under it all
    z = ZONES["vinyl"][0]["data"]
    loop = np.tile(z, int(8 * BAR * SR / len(z)) + 2)[:int(8 * BAR * SR)]
    place("amb", t_of(9), loop, 0, 0.16)
    # the sax takes the theme, in D minor
    sax = [(9, 0, "A4", 3), (9, 3, "C5", 1), (9, 4, "E5", 4),
           (10, 0, "F5", 6), (10, 6, "E5", 2),
           (11, 0, "D5", 3), (11, 3, "C5", 1), (11, 4, "Bb4", 4),
           (12, 0, "A4", 6), (12, 6, "C5", 1), (12, 7, "D5", 1),
           (13, 0, "E5", 3), (13, 3, "F5", 1), (13, 4, "A5", 4),
           (14, 0, "Bb5", 6), (14, 6, "A5", 2),
           (15, 0, "G5", 3), (15, 3, "F5", 1), (15, 4, "E5", 4),
           (16, 0, "C#5", 4), (16, 4, "E5", 2), (16, 6, "A5", 2)]
    for b, e, nn, ln in sax:
        note("lead", "sax", t_of(b, e * 0.5 + (0.06 if e % 2 else 0)), m(nn), ln * BEAT / 2 * 0.95, 0.5, 0.1, rel=0.2)
    whoosh(t_of(17), 0.3)


# ------------------------------------------------------------------ III. growth (bars 17-24.5)
def act3():
    prog = ["F", "Bb", "C", "F", "Dm", "Bb", "C", "C7"]
    tri = {"F": chord("F3 A3 C4"), "Bb": chord("F3 Bb3 D4"), "C": chord("E3 G3 C4"), "Dm": chord("F3 A3 D4"),
           "C7": chord("E3 Bb3 C4")}
    roots = {"F": m("F1"), "Bb": m("Bb1"), "C": m("C2"), "Dm": m("D2"), "C7": m("C2")}
    clave = [(0, 1.5, 3), (1, 1, 2)]      # 3-2 son clave (beats) over two bars
    for i, c in enumerate(prog):
        b = 17 + i
        energy = i / 7
        # montuno: offbeat piano octaves outlining the chord
        pat = [0, 2, 1, 2, 0, 2, 1, 2]
        for k in range(8):
            if k in (0, 3, 6) and i < 2:
                continue
            n = tri[c][pat[k]] + 12
            note("keys", "piano", t_of(b, k * 0.5), n, BEAT * 0.4, 0.26 + 0.1 * energy, -0.3, rel=0.12)
            note("keys", "piano", t_of(b, k * 0.5), n + 12, BEAT * 0.4, 0.2 + 0.08 * energy, -0.3, rel=0.12)
        # bass tumbao: the and of 2, and 4
        r = roots[c]
        note("bass", "bass", t_of(b, 1.5), r + 7, BEAT * 1.2, 0.8, 0, rel=0.1)
        note("bass", "bass", t_of(b, 3), r, BEAT * 1.0, 0.9, 0, rel=0.1)
        # percussion builds up
        for k in range(4):
            hit("perc", "cowbell", t_of(b, k), 0.22 + 0.15 * energy, 0.35)
        for bb in clave[i % 2][1:]:
            hit("perc", "claves", t_of(b, bb), 0.3, -0.35)
        hit("perc", "claves", t_of(b, clave[i % 2][0] + (0 if i % 2 else 0)), 0.3, -0.35)
        for k, kind in ((3, "conga"), (3.5, "congaslap"), (0.5, "conga"), (1.5, "tumba"), (2.5, "conga")):
            hit("perc", kind, t_of(b, k), 0.35 + 0.2 * energy, rng.uniform(-0.4, 0.4))
        if i >= 2:
            for k in range(8):
                hit("perc", "guiro" if k % 4 == 0 else "hat", t_of(b, k * 0.5), 0.12 + 0.1 * energy, 0.4)
        if i >= 3:
            for k in (0, 1, 2, 3):
                hit("drums", "kick", t_of(b, k), 0.55 + 0.3 * energy)
            hit("drums", "snare", t_of(b, 1), 0.45 * energy)
            hit("drums", "snare", t_of(b, 3), 0.45 * energy)
        # strings rise
        for j, n in enumerate(tri[c]):
            note("strings", "strings", t_of(b), n + 12, BAR, 0.12 + 0.14 * energy, (-0.5, 0, 0.5)[j], rel=0.5)
        # brass stabs from bar 21
        if i >= 4:
            for beat in (0, 2.5):
                for n in tri[c]:
                    note("brass", "trumpet", t_of(b, beat), n + 12, BEAT * 0.35, 0.3 + 0.15 * energy, 0.2, rel=0.12)
                note("brass", "trombone", t_of(b, beat), tri[c][0], BEAT * 0.35, 0.35, -0.2, rel=0.12)
    # the views: a blip on each
    for vb in (22.5, 23.0, 23.5, 24.0):
        blip(t_of(vb), 1100 + 110 * (vb - 22.5) * 4)
    # the wall: everything hits the downbeat of 24.5 and stops
    for n in chord("C3 E3 G3 Bb3 C4"):
        note("brass", "trumpet", t_of(24.5), n + 12, BEAT * 0.5, 0.55, 0.2, rel=0.5)
        note("strings", "strings", t_of(24.5), n, BEAT * 1.0, 0.3, 0, rel=1.2)
    note("brass", "trombone", t_of(24.5), m("C2") + 12, BEAT, 0.6, -0.2, rel=0.4)
    hit("drums", "kick", t_of(24.5), 1.0)
    hit("drums", "snare", t_of(24.5), 0.7)
    riser(t_of(21), t_of(24.5), 0.35)
    boom(t_of(24.5), 0.45, 55, 2.0)


# ------------------------------------------------------------------ IV. trials (bars 25-31)
def act4():
    # low strings and piano: D minor, dark
    for b0, b1, ch in ((25, 27, chord("D2 A2 F3")), (27, 29, chord("Bb1 F2 D3")),
                       (29, 30.5, chord("G1 D2 Bb2"))):
        for j, n in enumerate(ch):
            note("strings", "strings", t_of(b0), n + 12, (b1 - b0) * BAR, 0.17, (-0.4, 0, 0.4)[j], rel=0.8)
    for b, n in ((25, "D1"), (26, "D1"), (27, "Bb0"), (28, "Bb0"), (29, "G0"), (30, "A0")):
        note("keys", "piano", t_of(b), m(n), BAR, 0.38, -0.1, rel=1)
        note("keys", "piano", t_of(b), m(n) + 12, BAR, 0.26, -0.1, rel=1)
        boom(t_of(b), 0.35 if b in (25, 27, 29) else 0.15, 42, 2.2)
    # the sax, slow and alone
    sax = [(26, 0, "A4", 4), (26, 4, "C5", 2), (26, 6, "E5", 2),
           (27, 0, "F5", 8), (28, 0, "E5", 3), (28, 3, "D5", 1), (28, 4, "C5", 4),
           (29, 0, "D5", 8)]
    for b, e, nn, ln in sax:
        note("lead", "sax", t_of(b, e * 0.5), m(nn), ln * BEAT / 2 * 0.97, 0.36, 0.15, rel=0.6)
    # the city in trouble
    z = ZONES["siren"][0]
    for tb, pan, g in ((25.6, -0.6, 0.12), (27.4, 0.5, 0.16), (28.8, -0.2, 0.2)):
        place("fx", t_of(tb), np.interp(np.arange(0, len(z["data"]) - 1, z["rate"] / SR),
                                        np.arange(len(z["data"])), z["data"]).astype(np.float32), pan, g)
    crackle(t_of(26.5), t_of(29.6), 0.12)
    # the hush, the fall, the impact
    whistle(t_of(29.9), t_of(IMPACT_BAR) - 0.02, 0.22)
    riser(t_of(29.5), t_of(IMPACT_BAR) - 0.3, 0.2)
    boom(t_of(IMPACT_BAR), 1.25, 38, 4.5)
    hit("drums", "kick", t_of(IMPACT_BAR), 1.0, 0, 0.6)
    tinnitus(t_of(IMPACT_BAR) + 0.3, 3.2, 0.05)


# ------------------------------------------------------------------ V. finale (bars 32-40)
def act5():
    prog = [("F", 32), ("Dm", 33), ("Bb", 34), ("C", 34.5), ("F", 35), ("Dm", 35.5), ("Bb", 36), ("C", 36.5)]
    tri = {"F": chord("F3 A3 C4"), "Bb": chord("F3 Bb3 D4"), "C": chord("E3 G3 C4"), "Dm": chord("F3 A3 D4")}
    roots = {"F": m("F1"), "Bb": m("Bb1"), "C": m("C2"), "Dm": m("D2")}
    reverse_swell(t_of(32), 1.0, 0.5)
    for idx, (c, b0) in enumerate(prog):
        b1 = prog[idx + 1][1] if idx + 1 < len(prog) else 37
        dur = (b1 - b0) * BAR
        for j, n in enumerate(tri[c]):
            note("strings", "strings", t_of(b0), n + 12, dur, 0.32, (-0.5, 0, 0.5)[j], rel=0.4)
            note("strings", "strings", t_of(b0), n, dur, 0.22, (0.5, 0, -0.5)[j], rel=0.4)
        r = roots[c]
        beats = int(round((b1 - b0) * 4))
        for k in range(beats):
            note("bass", "bass", t_of(b0, k), r + (0, 12, 7, 12)[k % 4], BEAT * 0.9, 0.9, 0, rel=0.08)
            note("keys", "piano", t_of(b0, k + 0.5), tri[c][k % 3] + 12, BEAT * 0.4, 0.3, -0.3, rel=0.1)
        for n in tri[c]:
            note("keys", "piano", t_of(b0), n, BEAT * 1.8, 0.4, -0.3, rel=0.4)
    for b in range(32, 37):
        for k in range(4):
            hit("drums", "kick", t_of(b, k), 1.0)
            hit("drums", "ridebell" if k == 0 else "ride", t_of(b, k), 0.25, 0.3)
        hit("drums", "snare", t_of(b, 1), 0.7)
        hit("drums", "snare", t_of(b, 3), 0.7)
        hit("drums", "snare", t_of(b, 3.5), 0.35)
        for k in range(8):
            hit("perc", "conga" if k % 2 else "tumba", t_of(b, k * 0.5), 0.2, -0.4)
    # the theme on the horns: trumpets in thirds, trombones below
    theme = [(32, 0, "F5", 3), (32, 3, "A5", 1), (32, 4, "C6", 4),
             (33, 0, "D6", 6), (33, 6, "C6", 2),
             (34, 0, "Bb5", 3), (34, 3, "A5", 1), (34, 4, "G5", 4),
             (35, 0, "A5", 3), (35, 3, "C6", 1), (35, 4, "F6", 4),
             (36, 0, "E6", 3), (36, 3, "D6", 1), (36, 4, "C6", 2), (36, 6, "E6", 2)]
    third = {"F5": "A4", "A5": "F5", "C6": "A5", "D6": "F5", "Bb5": "D5", "G5": "E5", "F6": "C6", "E6": "C6"}
    for b, e, nn, ln in theme:
        t = t_of(b, e * 0.5)
        d = ln * BEAT / 2 * 0.93
        note("brass", "trumpet", t, m(nn) - 12, d, 0.8, 0.15, rel=0.25)
        note("brass", "trumpet", t, m(third[nn]) - 12, d, 0.55, -0.1, rel=0.25)
        note("brass", "trombone", t, m(nn) - 24, d, 0.55, -0.25, rel=0.25)
        note("lead", "strings", t, m(nn), d, 0.3, 0.3, rel=0.4)
    # the landing: F major everywhere, the logo
    L = t_of(LOGO_BAR)
    for n in chord("F2 C3 F3 A3 C4 F4 A4 C5"):
        note("strings", "strings", L, n, BAR * 2.2, 0.26, rng.uniform(-0.6, 0.6), rel=2.5)
    for n in chord("F4 A4 C5 F5"):
        note("brass", "trumpet", L, n, BAR * 1.2, 0.5, rng.uniform(-0.3, 0.3), rel=1.5)
    for n in chord("F2 C3 F3"):
        note("brass", "trombone", L, n, BAR * 1.2, 0.5, -0.2, rel=1.5)
    note("bass", "bass", L, m("F1"), BAR * 1.5, 1.0, 0, rel=1.5)
    for n in chord("F2 C3 F3 A3 C4 F4"):
        note("keys", "piano", L, n, BAR * 2, 0.45, -0.2, rel=3)
    hit("drums", "kick", L, 1.0)
    hit("drums", "ridebell", L, 0.5, 0.3)
    boom(L, 0.6, 44, 3.5)
    for k, n in enumerate(chord("C6 F6 A6 C7")):
        note("keys", "piano", L + 0.15 + k * 0.09, n, 2, 0.18, 0.5, rel=2)
    # the end: solo piano, as it began
    for b, e, nn, ln in ((38.5, 0, "F4", 3), (38.5, 3, "A4", 1), (38.5, 4, "C5", 4), (39.5, 0, "D5", 6),
                         (39.5, 6, "C5", 2)):
        note("keys", "piano", t_of(b, e * 0.5), m(nn), ln * BEAT / 2, 0.36, 0.1, rel=2)
    note("keys", "piano", t_of(38.5), m("F2"), BAR * 2, 0.2, -0.2, rel=3)
    note("keys", "piano", t_of(40, 1), m("F5"), BAR, 0.25, 0.2, rel=4)


# ------------------------------------------------------------------ cold open (2 bars before the story)
def cold_open():
    t0 = 0.0
    for n in chord("F2 C3 F3 A3 C4 F4 A4"):
        note("strings", "strings", t0, n, BAR * 2, 0.24, rng.uniform(-0.6, 0.6), rel=1.2)
    for n in chord("F3 A3 C4"):
        note("brass", "trumpet", t0 + 0.05, n + 12, BAR * 1.1, 0.34, rng.uniform(-0.3, 0.3), rel=1.0)
    note("brass", "trombone", t0 + 0.05, m("F2"), BAR * 1.1, 0.4, -0.2, rel=1.0)
    note("bass", "bass", t0, m("F1"), BAR * 1.5, 0.8, 0, rel=1.0)
    for n in chord("F2 C3 F3 A3"):
        note("keys", "piano", t0, n, BAR, 0.4, -0.2, rel=2)
    boom(t0, 0.5, 44, 3.0)
    # the theme's first notes over the night skyline
    for k, nn in enumerate(("F5", "A5", "C6", "D6")):
        note("keys", "piano", BAR + k * BEAT * 0.5, m(nn), BEAT * (2 if k == 3 else 0.5), 0.35, 0.2, rel=1.5)
    reverse_swell(BAR * 2 - 0.05, 0.9, 0.25)


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
    act2()
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
