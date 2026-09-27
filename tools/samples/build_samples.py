#!/usr/bin/env python3
"""
Build the game's embedded instrument samples ("Five Boroughs" music v2).

Sources are CC0 recordings from Versilian Studios:
  VCSL        https://github.com/sgossner/VCSL        (CC0-1.0)
  VSCO-2-CE   https://github.com/sgossner/VSCO-2-CE   (CC0-1.0)
plus two sounds synthesised here (an NYC siren and vinyl crackle).

For every zone: download, fold to mono, detect the real pitch (libraries
number octaves differently) and retune to an exact equal-tempered root,
trim, fade, level-match the zones of an instrument, find a crossfaded
loop for sustained instruments, and resample to the stored rate.

Output:
  src/nyc_samples.bin   int16 little-endian mono, all zones back to back
  src/nyc_samples.inc   NASM index: offset, length, root, loop start/end, rate
"""
import os, re, sys, json, urllib.request, urllib.parse
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly, butter, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, 'third_party', 'samples_cache')
VCSL = 'https://raw.githubusercontent.com/sgossner/VCSL/master/'
VSCO = 'https://raw.githubusercontent.com/sgossner/VSCO-2-CE/master/'
NOTE = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}

# name, base url, path, keep seconds, stored rate, pitched?, loop (start s, end s) or None, gain
PIANO = 'Chordophones/Zithers/Grand Piano, Steinway B/Sus/JHPiano_Sus_Close_{}_vl3_rr1.wav'
BASS = 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_{}_v1_rr1.wav'
HARMON = 'Brass/Trumpet/harmonM-sus/Sum_SHTrumpet_harmonM-sus_{}_v3_rr1.wav'
SAX = 'Aerophones/Reed Aerophones/Tenor Saxophone/Vibrato/BrettTenor_Vib_Main_{}.wav'
CLAR = 'Woodwinds/Clarinet/susLong/DCClar_susLong_{}_v2_rr1_sum.wav'
VLN = 'Strings/Violin Section/susVib/VlnEns_susVib_{}_v1.wav'
TBN = 'Brass/Tenor Trombone/stac/tenortbn_stac_{}_v3_rr1.wav'
TPT = 'Brass/Trumpet/stac/Sum_SHTrumpet_stac_{}_v2_rr1.wav'

ZONES = [
    # the Steinway: comping, montunos, ballads
    *[('piano', VCSL, PIANO.format(n), 2.2, 32000, True, None, 1.0)
      for n in ('D2', 'A#2', 'F#3', 'D4', 'A#4', 'F#5')],
    # upright bass, plucked
    *[('bass', VSCO, BASS.format(n), 1.3, 22050, True, None, 1.0)
      for n in ('E0', 'A#0', 'E1', 'A1', 'C#2')],
    # Miles' harmon-muted trumpet, looped
    *[('harmon', VSCO, HARMON.format(n), 1.6, 32000, True, (0.55, 1.45), 1.0)
      for n in ('G#3', 'D4', 'A4')],
    # tenor sax with vibrato, looped
    *[('sax', VCSL, SAX.format(n), 1.8, 32000, True, (0.6, 1.65), 1.0)
      for n in ('A#2_var4', 'F#3_var2', 'D4_var1', 'A#3_var3')],
    # clarinet (Broadway mornings)
    *[('clarinet', VSCO, CLAR.format(n), 1.6, 32000, True, (0.5, 1.45), 1.0)
      for n in ('F3', 'D4', 'A#4')],
    # violin section pad
    *[('strings', VSCO, VLN.format(n), 2.0, 32000, True, (0.7, 1.85), 1.0)
      for n in ('A2', 'D3', 'C4')],
    # brass section stabs (salsa)
    *[('trombone', VSCO, TBN.format(n), 0.7, 32000, True, None, 1.0)
      for n in ('A#1', 'F2', 'D3')],
    *[('trumpet', VSCO, TPT.format(n), 0.6, 32000, True, None, 1.0)
      for n in ('F3', 'A#3', 'D4')],
    # drum kit
    ('kick', VCSL, 'Membranophones/Struck Membranophones/Bass Drum 1/BDrumNew_hit_v5_rr1_Sum.wav', 0.6, 32000, False, None, 1.0),
    ('snare', VCSL, 'Membranophones/Struck Membranophones/Snare Drum, Modern 1/Snare2_HitSN_v6_rr1_Mid.wav', 0.55, 32000, False, None, 1.0),
    ('hat', VCSL, 'Idiophones/Struck Idiophones/Hi-Hat Cymbal/HiHat_HitC_v2_rr1_Mid.wav', 0.3, 44100, False, None, 1.0),
    ('hatopen', VCSL, 'Idiophones/Struck Idiophones/Hi-Hat Cymbal/HiHat_HitO_rr1_Mid.wav', 0.9, 44100, False, None, 1.0),
    ('hatfoot', VCSL, 'Idiophones/Struck Idiophones/Hi-Hat Cymbal/HiHat_Close_rr1_Mid.wav', 0.25, 44100, False, None, 1.0),
    ('ride', VCSL, 'Idiophones/Struck Idiophones/Suspended Cymbal 2/susCymb2_hit_stick_mp1.wav', 1.6, 44100, False, None, 1.0),
    ('ridebell', VCSL, 'Idiophones/Struck Idiophones/Suspended Cymbal 1/susCymb1_hit_bell_mf1.wav', 1.2, 44100, False, None, 1.0),
    ('clap', VCSL, 'Idiophones/Struck Idiophones/Claps/Clap_rr1.wav', 0.4, 32000, False, None, 1.0),
    # Latin percussion
    ('conga', VCSL, 'Membranophones/Struck Membranophones/Conga/Conga_HitN_v2_rr1_Sum.wav', 0.6, 32000, False, None, 1.0),
    ('congaslap', VCSL, 'Membranophones/Struck Membranophones/Conga/Quinto_HitFM1_v2_rr1_Sum.wav', 0.4, 32000, False, None, 1.0),
    ('tumba', VCSL, 'Membranophones/Struck Membranophones/Conga/Tumba_HitN_v2_rr1_Sum.wav', 0.7, 32000, False, None, 1.0),
    ('bongohi', VCSL, 'Membranophones/Struck Membranophones/Bongos/BongoH_Hit1_v2_rr1_Mid.wav', 0.35, 32000, False, None, 1.0),
    ('bongolo', VCSL, 'Membranophones/Struck Membranophones/Bongos/BongoL_Hit1_v2_rr1_Mid.wav', 0.4, 32000, False, None, 1.0),
    ('cowbell', VCSL, 'Idiophones/Struck Idiophones/Cowbells/Cowbell1_Normal_v2_rr1_Mid.wav', 0.5, 32000, False, None, 1.0),
    ('claves', VCSL, 'Idiophones/Struck Idiophones/Claves/Claves1_Hit_v2_rr1_Mid.wav', 0.3, 32000, False, None, 1.0),
    ('guiro', VCSL, 'Idiophones/Struck Idiophones/Guiro/Guiro_Hit_rr1_Mid.wav', 0.35, 32000, False, None, 1.0),
]
SYNTH = ['siren', 'vinyl']


def fetch(base, path):
    os.makedirs(CACHE, exist_ok=True)
    local = os.path.join(CACHE, re.sub(r'[^\w.#-]', '_', path))
    if not os.path.exists(local):
        url = base + urllib.parse.quote(path)
        with urllib.request.urlopen(url) as r, open(local + '.part', 'wb') as f:
            f.write(r.read())
        os.rename(local + '.part', local)
    sr, d = wavfile.read(local)
    d = d.astype(np.float64)
    if d.ndim == 2:
        d = d.mean(axis=1)
    d /= max(np.max(np.abs(d)), 1e-9)
    return sr, d


def name_pc(path):
    m = re.search(r'_([A-G]#?)(-?\d)(_|\.wav)', path)
    return NOTE[m.group(1)], int(m.group(2))


def detect_f0(x, sr, lo=30.0, hi=1500.0):
    """autocorrelation pitch of a steady chunk (YIN-style difference)"""
    n = len(x)
    start = int(0.12 * sr) if n > int(0.6 * sr) else int(0.03 * sr)
    seg = x[start:start + int(0.25 * sr)]
    seg = seg - seg.mean()
    w = len(seg) // 2
    maxlag = min(int(sr / lo), w - 1)
    minlag = int(sr / hi)
    d = np.array([np.sum((seg[:w] - seg[l:l + w]) ** 2) for l in range(maxlag + 1)])
    cmnd = d.copy()
    cmnd[1:] = d[1:] * np.arange(1, maxlag + 1) / np.maximum(np.cumsum(d[1:]), 1e-12)
    for l in range(minlag, maxlag):
        if cmnd[l] < 0.12 and cmnd[l] <= cmnd[l + 1]:
            # parabolic refinement
            a, b, c = cmnd[l - 1], cmnd[l], cmnd[l + 1]
            den = a - 2 * b + c
            off = 0.5 * (a - c) / den if den != 0 else 0.0
            return sr / (l + off)
    l = minlag + int(np.argmin(cmnd[minlag:maxlag]))
    return sr / l


def trim_onset(x, sr):
    thr = 0.02 * np.max(np.abs(x))
    i = int(np.argmax(np.abs(x) > thr))
    return x[max(0, i - int(0.002 * sr)):]


def fade_tail(x, sr, frac=0.25):
    n = len(x)
    k = int(n * frac)
    x = x.copy()
    x[n - k:] *= np.linspace(1, 0, k) ** 2
    return x


def make_loop(x, sr, ls, le):
    """crossfade the region before le into ls so the loop is seamless"""
    a, b = int(ls * sr), int(le * sr)
    b = min(b, len(x) - 1)
    # nudge both ends to rising zero crossings
    def zc(i):
        for j in range(i, min(i + 2000, len(x) - 1)):
            if x[j] <= 0 < x[j + 1]:
                return j + 1
        return i
    a, b = zc(a), zc(b)
    xf = min(int(0.12 * sr), (b - a) // 3)
    y = x[:b].copy()
    t = np.linspace(0, 1, xf)
    y[b - xf:b] = x[b - xf:b] * (1 - t) + x[a - xf:a] * t
    return y, a, b


def synth_siren(sr):
    # NYC wail: sweep 650 <-> 1450 Hz over ~4 s, with the yelp's harmonics,
    # heard from a few blocks away (low-passed, a little echo)
    dur = 4.0
    t = np.arange(int(sr * dur)) / sr
    f = 1050 + 400 * np.sin(2 * np.pi * t / dur - np.pi / 2)
    ph = 2 * np.pi * np.cumsum(f) / sr
    y = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    sos = butter(2, 1800, 'low', fs=sr, output='sos')
    y = sosfilt(sos, y)
    echo = np.zeros_like(y)
    d = int(0.18 * sr)
    echo[d:] = 0.35 * y[:-d]
    y = y + echo
    env = np.minimum(1, t / 0.3) * np.minimum(1, (dur - t) / 0.5)
    return y * env


def synth_vinyl(sr):
    # crackle: sparse clicks and pops over faint surface hiss, loopable
    rng = np.random.default_rng(7)
    n = int(sr * 2.0)
    y = rng.normal(0, 0.012, n)
    sos = butter(2, [300, 6000], 'band', fs=sr, output='sos')
    y = sosfilt(sos, y)
    for _ in range(90):
        i = rng.integers(0, n - 60)
        amp = rng.uniform(0.1, 0.6) * rng.choice([-1, 1])
        k = rng.integers(3, 20)
        y[i:i + k] += amp * np.exp(-np.arange(k) / 3.0)
    for _ in range(6):
        i = rng.integers(0, n - 400)
        y[i:i + 400] += rng.uniform(0.3, 0.8) * np.exp(-np.arange(400) / 60.0) * np.sin(np.arange(400) * 0.07)
    # make the loop seamless
    xf = 2000
    t = np.linspace(0, 1, xf)
    y[-xf:] = y[-xf:] * (1 - t) + y[:xf] * t
    return y / np.max(np.abs(y))


def main():
    out = []           # (name, root, int16 array, loop start, loop end, rate)
    groups = {}
    for name, base, path, keep, rate, pitched, loop, gain in ZONES:
        sr, x = fetch(base, path)
        x = trim_onset(x, sr)
        root = 0
        if pitched:
            f0 = detect_f0(x, sr)
            pc, octv = name_pc(path)
            est = 69 + 12 * np.log2(f0 / 440.0)
            # the libraries number octaves differently: the Steinway uses
            # C4 = middle C, VSCO and the tenor sax are an octave higher
            shift = 0 if 'Steinway' in path else 1
            root = pc + 12 * (octv + 1 + shift)
            # the detector can land on an octave or a sub-harmonic: use
            # its reading only for fine tuning, when it is close
            err = est - root
            err -= 12 * round(err / 12)
            cents = 100 * err
            if abs(cents) > 45:
                print(f'  note: {path.split("/")[-1]} reads {cents:+.0f} cents off, left as is', file=sys.stderr)
                cents = 0.0
            # retune to exactly the root: resample by the cents error
            ratio = 2 ** (cents / 1200)
            src_rate = sr * ratio
        else:
            src_rate = sr
            cents = 0
        # resample to the stored rate (also applies the retune)
        up, down = rate, int(round(src_rate))
        g = np.gcd(up, down)
        y = resample_poly(x[:int(sr * (keep + 0.2))], up // g, down // g)
        y = y[:int(rate * keep)]
        ls = le = 0
        if loop:
            y, ls, le = make_loop(y, rate, loop[0], loop[1])
        else:
            y = fade_tail(y, rate, 0.3 if pitched else 0.2)
        out.append([name, root, y * gain, ls, le, rate])
        groups.setdefault(name, []).append(len(out) - 1)
        print(f'{name:10s} root {root:3d} {cents if pitched else 0:+5.0f}c  {len(y) / rate:4.2f}s  {path.split("/")[-1]}')
    sr = 32000
    out.append(['siren', 0, synth_siren(sr), 0, 0, sr]); groups['siren'] = [len(out) - 1]
    v = synth_vinyl(22050)
    out.append(['vinyl', 0, v, 1, len(v) - 1, 22050]); groups['vinyl'] = [len(out) - 1]
    # level: every zone of an instrument to the same loudness (RMS of the
    # first 300 ms), instruments to a common peak
    for name, idx in groups.items():
        rms = []
        for i in idx:
            y = out[i][2]
            n = int(out[i][5] * 0.3)
            rms.append(np.sqrt(np.mean(y[:n] ** 2)) + 1e-9)
        target = np.median(rms)
        for i, r in zip(idx, rms):
            out[i][2] = out[i][2] * (target / r)
        peak = max(np.max(np.abs(out[i][2])) for i in idx)
        for i in idx:
            out[i][2] = out[i][2] * (0.95 / peak)
    # write
    blob = bytearray()
    lines = ['; generated by tools/samples/build_samples.py - do not edit',
             '; CC0 samples from Versilian Studios VCSL and VSCO-2-CE',
             '; per zone: offset (samples), length, root midi, loop start, loop end, rate',
             'section .data', 'align 4', 'nyc_zones:']
    offset = 0
    ids = {}
    for k, (name, root, y, ls, le, rate) in enumerate(out):
        pcm = np.clip(np.round(y * 32767), -32768, 32767).astype('<i2')
        blob += pcm.tobytes()
        lines.append(f'    dd {offset}, {len(pcm)}, {root}, {ls}, {le}, {rate}   ; {name}')
        ids.setdefault(name, (k, 0))
        ids[name] = (ids[name][0], ids[name][1] + 1)
        offset += len(pcm)
    lines.append(f'NZ_COUNT equ {len(out)}')
    lines.append(f'NZ_SAMPLES equ {offset}')
    for name, (first, count) in ids.items():
        lines.append(f'NZ_{name.upper()} equ {first}')
        lines.append(f'NZ_{name.upper()}_N equ {count}')
    lines.append('align 16')
    lines.append('nyc_pcm: incbin "nyc_samples.bin"')
    with open(os.path.join(ROOT, 'src', 'nyc_samples.bin'), 'wb') as f:
        f.write(blob)
    with open(os.path.join(ROOT, 'src', 'nyc_samples.inc'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print(f'{len(out)} zones, {len(blob) / 1e6:.2f} MB')


if __name__ == '__main__':
    main()
