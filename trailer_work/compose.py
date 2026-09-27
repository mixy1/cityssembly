"""Cityssembly trailer compositor.

All graphics come from the game's own assets: the 5x8 pixel font (built
out of voxel cubes), the toolbar icons, the money popups, the cursor, the
2:1 isometric tile grid and the game palette."""
import glob
import math
import os
import re
import subprocess
import sys
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageFilter

from timeline import BEAT, BAR, FPS, DURATION, SHOTS, SHOT_END, EDL, bar

W, H = 1920, 1080
SRC_W, SRC_H = 960, 540
TOTAL = int(round(DURATION * FPS))

# ------------------------------------------------------------------ game palette
GOLD = (255, 214, 84)
CREAM = (250, 242, 224)
NAVY = (12, 14, 24)
UI_BG = (20, 24, 36)
UI_EDGE = (96, 108, 140)
ACCENT = (96, 196, 255)


def shade(c, k):
    return tuple(int(clamp(v * k, 0, 255)) for v in c)


# ------------------------------------------------------------------ helpers
def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease_out(x):
    x = clamp(x)
    return 1 - (1 - x) ** 3


def ease_in(x):
    x = clamp(x)
    return x * x * x


def ease_out_back(x, s=1.7):
    x = clamp(x) - 1
    return x * x * ((s + 1) * x + s) + 1


def fill(fr, x0, y0, x1, y1, col, a=1.0):
    x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(W, x1), min(H, y1)
    if x0 >= x1 or y0 >= y1 or a <= 0:
        return
    c = np.array(col, np.float32) / 255
    if a >= 1:
        fr[y0:y1, x0:x1] = c
    else:
        fr[y0:y1, x0:x1] = fr[y0:y1, x0:x1] * (1 - a) + c * a


# ------------------------------------------------------------------ game font
def load_game_font():
    glyphs = {}
    src = open("../src/font.asm").read()
    rows = re.findall(r'^G ((?:"[.#]{5}",?){8})', src, re.M)
    for i, r in enumerate(rows):
        glyphs[chr(33 + i)] = re.findall(r'"([.#]{5})"', r)
    return glyphs


FONT = load_game_font()


def text_bitmap(word):
    """list of columns of booleans (7 rows) with the game's proportional spacing"""
    cols = []
    for ch in word:
        if ch == " ":
            cols += [[False] * 7] * 3
            continue
        g = FONT[ch]
        used = [c for c in range(5) if any(row[c] == "#" for row in g)]
        if ch.isdigit():
            used = list(range(5))
        for c in range(min(used), max(used) + 1):
            cols.append([g[r][c] == "#" for r in range(7)])
        cols.append([False] * 7)
    return cols[:-1]


def flat_text(fr, word, x, y, s, col, a=1.0, shadow=True, anchor="c"):
    """flat pixel text, like the game's HUD (s = pixel size)"""
    cols = text_bitmap(word)
    w = len(cols) * s
    if anchor == "c":
        x -= w / 2
    y -= 7 * s / 2
    if shadow:
        for ci, cb in enumerate(cols):
            for ri, on in enumerate(cb):
                if on:
                    fill(fr, x + ci * s + s // 2, y + ri * s + s // 2, x + ci * s + s + s // 2, y + ri * s + s + s // 2, (0, 0, 0), a * 0.8)
    for ci, cb in enumerate(cols):
        for ri, on in enumerate(cb):
            if on:
                fill(fr, x + ci * s, y + ri * s, x + ci * s + s, y + ri * s + s, col, a)


# ------------------------------------------------------------------ voxel type
class VoxelWord:
    """a word built from the game's font, one voxel cube per pixel;
    cubes drop in and snap together, then tumble out"""

    def __init__(self, word, s, face, seed=0):
        self.cols = text_bitmap(word)
        self.s = s
        self.face = face
        self.top = shade(face, 1.18)
        self.side = shade(face, 0.62)
        self.bottom = shade(face, 0.42)
        self.glow = None
        self.w = len(self.cols) * s
        self.h = 7 * s
        rng = np.random.default_rng(seed)
        self.cubes = []
        for ci, cb in enumerate(self.cols):
            for ri, on in enumerate(cb):
                if on:
                    d_in = ci / max(1, len(self.cols)) * 0.22 + rng.random() * 0.06 + (6 - ri) * 0.01
                    d_out = rng.random() * 0.12
                    self.cubes.append((ci, ri, d_in, d_out, rng.uniform(-1, 1)))

    def draw(self, fr, cx, cy, t_in, t_out=None, t=0.0, scale_pop=1.0):
        s = self.s
        x0 = cx - self.w / 2
        y0 = cy - self.h / 2
        d = max(2, s // 3)
        # soft shadow behind the word so it reads over busy streets
        k_all = clamp((t - t_in) / 0.4)
        if t_out is not None:
            k_all *= 1 - clamp((t - t_out) / 0.35)
        if k_all > 0:
            darken_blob(fr, cx, cy, self.w * 0.62 + s * 2, self.h * 0.9 + s * 2, 0.5 * k_all, self.glow)
        placed = []
        for ci, ri, d_in, d_out, jit in self.cubes:
            p = (t - t_in - d_in) / 0.32
            if p <= 0:
                continue
            e = ease_out_back(p, 1.3)
            dy = -(1 - e) * 260
            dx = 0.0
            if t_out is not None and t > t_out + d_out:
                q = (t - t_out - d_out)
                dy += q * q * 2600
                dx += jit * q * 300
                if dy > H:
                    continue
            placed.append((x0 + ci * s + dx, y0 + ri * s + dy, clamp(p * 3)))
        # extrusion first (bottom-right), then faces
        for x, y, a in placed:
            fill(fr, x + d, y + d, x + s + d, y + s + d, self.bottom, a)
            fill(fr, x + s, y + d * 0.5, x + s + d, y + s + d * 0.5, self.side, a)
        for x, y, a in placed:
            fill(fr, x, y, x + s, y + s, self.face, a)
            fill(fr, x, y, x + s, y + max(2, s // 5), self.top, a)
            fill(fr, x, y + s - 2, x + s, y + s, shade(self.face, 0.8), a)


_blob_cache = {}


def darken_blob(fr, cx, cy, rx, ry, a, glow=None):
    """soft elliptical shadow (or coloured glow) behind titles"""
    key = (int(rx), int(ry))
    if key not in _blob_cache:
        y, x = np.mgrid[-int(ry):int(ry), -int(rx):int(rx)].astype(np.float32)
        d = (x / rx) ** 2 + (y / ry) ** 2
        _blob_cache[key] = np.clip(1 - d, 0, 1) ** 1.5
    m = _blob_cache[key] * a
    h, w = m.shape
    x0, y0 = int(cx - w / 2), int(cy - h / 2)
    xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
    if xa >= xb or ya >= yb:
        return
    mm = m[ya - y0:yb - y0, xa - x0:xb - x0, None]
    if glow is None:
        fr[ya:yb, xa:xb] *= 1 - mm
    else:
        fr[ya:yb, xa:xb] += mm * (np.array(glow, np.float32) / 255)


# ------------------------------------------------------------------ icons + cursor
ICON_COLORS = {
    "k": (0, 0, 0), "w": (238, 240, 246), "g": (170, 172, 180), "d": (80, 84, 92),
    "r": (230, 80, 70), "R": (160, 50, 40), "y": (255, 214, 84), "Y": (220, 170, 40),
    "o": (240, 150, 60), "b": (80, 130, 230), "B": (40, 70, 160), "c": (150, 215, 235),
    "G": (100, 210, 110), "h": (40, 130, 60), "n": (170, 120, 70), "N": (100, 64, 36),
    "p": (160, 120, 210), "s": (230, 180, 140), "a": (80, 82, 90), "l": (140, 200, 90),
}


def load_icons():
    src = open("../tools/icons_to_asm.py").read()
    src = src[:src.index("ORDER")]
    ns = {}
    exec(src, ns)
    out = {}
    for name, art in ns["ICONS"].items():
        rows = art.strip("\n").split("\n")
        img = np.zeros((16, 16, 4), np.float32)
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch in ICON_COLORS:
                    img[y, x, :3] = np.array(ICON_COLORS[ch]) / 255
                    img[y, x, 3] = 1
        out[name] = img
    return out


ICONS = load_icons()


def draw_icon(fr, name, cx, cy, s, a=1.0, panel=True):
    ic = ICONS[name]
    n = 16 * s
    if panel:
        # a game-style ui button behind it
        pad = s * 3
        fill(fr, cx - n / 2 - pad, cy - n / 2 - pad, cx + n / 2 + pad, cy + n / 2 + pad, UI_BG, 0.86 * a)
        fill(fr, cx - n / 2 - pad, cy - n / 2 - pad, cx + n / 2 + pad, cy - n / 2 - pad + s, UI_EDGE, a)
        fill(fr, cx - n / 2 - pad, cy + n / 2 + pad - s, cx + n / 2 + pad, cy + n / 2 + pad, (6, 8, 14), a)
    big = ic.repeat(s, 0).repeat(s, 1)
    x0, y0 = int(cx - n / 2), int(cy - n / 2)
    xa, ya = max(0, x0), max(0, y0)
    xb, yb = min(W, x0 + n), min(H, y0 + n)
    if xa >= xb or ya >= yb:
        return
    part = big[ya - y0:yb - y0, xa - x0:xb - x0]
    al = part[..., 3:4] * a
    fr[ya:yb, xa:xb] = fr[ya:yb, xa:xb] * (1 - al) + part[..., :3] * al


# ------------------------------------------------------------------ transitions
def _diamond_fields():
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    CW, CH = 128.0, 64.0
    best = np.full((H, W), 9.0, np.float32)
    ccx = np.zeros((H, W), np.float32)
    ccy = np.zeros((H, W), np.float32)
    for ox, oy in ((0, 0), (CW / 2, CH / 2)):
        cx = np.floor((x - ox) / CW) * CW + ox + CW / 2
        cy = np.floor((y - oy) / CH) * CH + oy + CH / 2
        dd = np.abs(x - cx) / (CW / 2) + np.abs(y - cy) / (CH / 2)
        m = dd < best
        best = np.where(m, dd, best)
        ccx = np.where(m, cx, ccx)
        ccy = np.where(m, cy, ccy)
    sweep = (ccx / W + ccy / H) / 2          # 0 top-left .. 1 bottom-right
    return best, sweep


DIAMOND = None


def diamond_cover(fr, p, col=NAVY):
    """cover the frame with isometric tiles; p 0 (none) .. 1 (all)"""
    global DIAMOND
    if p <= 0:
        return fr
    if DIAMOND is None:
        DIAMOND = _diamond_fields()
    d, sweep = DIAMOND
    local = np.clip(p * 1.7 - sweep * 0.7, 0, 1)
    m = (d < local * 1.02)[..., None]
    c = np.array(col, np.float32) / 255
    return np.where(m, c, fr)


def mosaic(fr, b):
    b = int(b)
    if b <= 1:
        return fr
    small = fr[b // 2::b, b // 2::b]
    big = small.repeat(b, 0).repeat(b, 1)[:H, :W]
    out = fr.copy()
    out[:big.shape[0], :big.shape[1]] = big
    return out


# ------------------------------------------------------------------ grading
def bloom(img, strength):
    lum = img.mean(axis=2, keepdims=True)
    bright = np.clip((lum - 0.6) / 0.4, 0, 1) * img
    small = Image.fromarray((np.clip(bright[::8, ::8], 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))
    b = np.array(small.resize((W, H), Image.BILINEAR)).astype(np.float32) / 255
    return img + b * strength


VIG = None


def vignette():
    global VIG
    if VIG is None:
        y, x = np.mgrid[0:H, 0:W].astype(np.float32)
        d = np.sqrt(((x - W / 2) / (W / 2)) ** 2 + ((y - H / 2) / (H / 2)) ** 2)
        VIG = (1 - 0.3 * np.clip(d - 0.4, 0, 1) ** 1.5)[..., None]
    return VIG


def grade(img):
    img = np.clip(img, 0, 1)
    img = img * img * (3 - 2 * img) * 0.3 + img * 0.7
    lum = img.mean(axis=2, keepdims=True)
    return lum + (img - lum) * 1.15


def rgb_split(img, amount):
    a = int(amount)
    if a < 1:
        return img
    out = img.copy()
    out[:, a:, 0] = img[:, :-a, 0]
    out[:, :-a, 2] = img[:, a:, 2]
    return out


# ------------------------------------------------------------------ footage lookup
def source_frame(t):
    b = t / BAR + 1
    for (b0, b1, shot, off, sp) in EDL:
        if b0 <= b < b1:
            local = t - bar(b0)
            names = list(SHOTS)
            nxt = names.index(shot) + 1
            end = SHOTS[names[nxt]] if nxt < len(names) else SHOT_END
            f = SHOTS[shot] + off + int(local * FPS * sp)
            return min(f, end - 1), shot, local
    return SHOT_END - 1, "wide", t - bar(15)


# ------------------------------------------------------------------ the words
WORDS = {
    "BUILD": VoxelWord("BUILD", 26, (238, 240, 246), 1),
    "ZONE": VoxelWord("ZONE", 26, (96, 196, 255), 2),
    "GROW": VoxelWord("GROW", 30, GOLD, 3),
    "SURVIVE": VoxelWord("SURVIVE", 26, (240, 90, 70), 4),
    "LOGO": VoxelWord("CITYSSEMBLY", 24, GOLD, 5),
}


# "+$" popups over the time-lapse: (spawn time, x, y, amount)
_prng = np.random.default_rng(11)
POPUPS = []
tt = bar(4) + 0.2
while tt < bar(6) - 0.3:
    POPUPS.append((tt, _prng.uniform(260, W - 260), _prng.uniform(260, H - 220), int(_prng.choice([12, 25, 40, 60, 85, 120, 150, 240]))))
    tt += _prng.uniform(0.07, 0.16)

VIEW_ICONS = [("view_power", "POWER"), ("view_water", "WATER"), ("view_traffic", "ROAD"), ("view_land", "ZONE_R")]

# cuts with a transition: (time, kind)
TRANSITIONS = [(bar(3), "tiles"), (bar(4), "mosaic"), (bar(6), "mosaic"), (bar(8), "tiles"),
               (bar(9), "mosaic"), (bar(10), "mosaic"), (bar(11), "tiles"), (bar(12), "mosaic"),
               (bar(15), "tiles")]
IMPACTS = [bar(3), bar(4), bar(13), bar(15)]


def overlays(fr, t, shot, local):
    # BUILD / ZONE over the roads being laid
    if bar(3) <= t < bar(4) + 0.2:
        WORDS["BUILD"].draw(fr, W / 2, H / 2, bar(3) + 0.05, bar(3, ) + BEAT * 1.75, t)
        if t > bar(3) + BEAT * 2:
            WORDS["ZONE"].draw(fr, W / 2, H / 2, bar(3) + BEAT * 2.05, bar(4) - 0.18, t)
    # GROW + money popups over the time-lapse
    if bar(4) <= t < bar(6):
        for (t0, x, y, amt) in POPUPS:
            age = t - t0
            if 0 <= age < 1.1:
                a = clamp(1.4 - age * 1.3)
                flat_text(fr, f"+${amt}", x, y - age * 90, 5, GOLD, a)
        WORDS["GROW"].draw(fr, W / 2, H / 2 - 20, bar(4) + 0.02, bar(5) + BEAT * 2.5, t)
    # info views: the game's toolbar icons stamped on each beat
    for (sname, icon) in VIEW_ICONS:
        if shot == sname:
            k = ease_out_back(local / 0.22, 2.0)
            s = int(9 * max(0.2, k))
            draw_icon(fr, icon, W / 2, H / 2, s, clamp(local / 0.08))
    # SURVIVE after the meteor impact
    if bar(13) <= t < bar(15):
        WORDS["SURVIVE"].draw(fr, W / 2, H * 0.3, bar(13) + 0.1, bar(14) + BEAT * 3, t)


def end_card(fr, t):
    t0 = bar(15)
    logo = WORDS["LOGO"]
    # the cursor arrives and clicks the logo
    tc = bar(16) + BEAT * 1
    bounce = 0.0
    if t > tc:
        bounce = math.sin(clamp((t - tc) / 0.25) * math.pi) * 14
    logo.draw(fr, W / 2, H / 2 - 90 + bounce, t0 + 0.05, None, t)
    a = clamp((t - t0 - BEAT * 2) / 0.3)
    flat_text(fr, "BUILD A LIVING CITY", W / 2, H / 2 + 110, 7, CREAM, a)
    a2 = clamp((t - t0 - BEAT * 3) / 0.3)
    flat_text(fr, "PLAY FREE ON WINDOWS & LINUX", W / 2, H / 2 + 190, 4, ACCENT, a2)
    # cursor path
    t_in = bar(16) - BEAT * 1.2
    if t > t_in:
        p = ease_out((t - t_in) / (tc - t_in))
        cx = W * 0.92 + (W / 2 + 330 - W * 0.92) * p
        cy = H * 0.95 + (H / 2 - 60 - H * 0.95) * p
        press = 0.85 if tc <= t < tc + 0.12 else 1.0
        draw_icon(fr, "CURSOR", cx + 8 * 6, cy + 8 * 6, int(6 * press), 1.0, panel=False)
        # click sparkles (like the game's construction sparks)
        if t > tc:
            rng = np.random.default_rng(3)
            age = t - tc
            for k in range(26):
                ang = rng.uniform(0, 2 * math.pi)
                sp = rng.uniform(250, 700)
                px = cx + math.cos(ang) * sp * age
                py = cy + math.sin(ang) * sp * age + 900 * age * age
                al = clamp(1 - age / 0.9)
                if al > 0:
                    sz = 8 if k % 3 else 12
                    fill(fr, px, py, px + sz, py + sz, GOLD if k % 2 else CREAM, al)


# ------------------------------------------------------------------ one output frame
def render(i, src):
    t = i / FPS
    fr = np.zeros((H, W, 3), np.float32)
    f, shot, local = source_frame(t)
    if src is not None:
        fr[:] = src.repeat(2, 0).repeat(2, 1)
        fr = grade(fr)
        fr = bloom(fr, 0.45 if shot in ("night", "sunset", "finale") else 0.22)
        fr *= vignette()
    # end card: soften the city behind the logo
    if t >= bar(15):
        k = clamp((t - bar(15)) / 0.5)
        small = Image.fromarray((np.clip(fr, 0, 1) * 255).astype(np.uint8)).resize((W // 6, H // 6), Image.BILINEAR)
        blur = np.array(small.filter(ImageFilter.GaussianBlur(2)).resize((W, H), Image.BILINEAR)).astype(np.float32) / 255
        fr = fr * (1 - k) + blur * k
        fr *= 1 - 0.5 * k
    # meteor shake
    if bar(13) <= t < bar(13) + 0.9:
        k = 1 - (t - bar(13)) / 0.9
        rng = np.random.default_rng(i)
        fr = np.roll(np.roll(fr, int(rng.integers(-20, 21) * k), 0), int(rng.integers(-28, 29) * k), 1)
        fr = rgb_split(fr, 12 * k)
    overlays(fr, t, shot, local)
    if t >= bar(15):
        end_card(fr, t)
    # transitions around cuts
    for (tc, kind) in TRANSITIONS:
        dt = t - tc
        if kind == "tiles" and -0.28 < dt < 0.28:
            p = 1 - abs(dt) / 0.28
            fr = diamond_cover(fr, ease_out(p) if dt < 0 else ease_out(p))
        if kind == "mosaic" and -0.14 < dt < 0.14:
            k = 1 - abs(dt) / 0.14
            fr = mosaic(fr, 2 + 30 * k * k)
    # the opening: tiles open onto the valley
    if t < 0.9:
        fr = diamond_cover(fr, 1 - ease_out(t / 0.9))
    for d in IMPACTS:
        if 0 <= t - d < 0.1:
            k = 1 - (t - d) / 0.1
            fr = fr * (1 - k * 0.8) + k * 0.8
    # close on tiles
    if t > DURATION - 0.6:
        fr = diamond_cover(fr, ease_out((t - (DURATION - 0.6)) / 0.5))
    return (np.clip(fr, 0, 1) * 255).astype(np.uint8)


# ------------------------------------------------------------------ workers
def worker(args):
    a, b, out = args
    need = [source_frame(i / FPS)[0] for i in range(a, b)]
    f0 = min(need)
    reader = subprocess.Popen(
        ["ffmpeg", "-loglevel", "error", "-ss", f"{f0 / FPS:.5f}", "-i", "capture.mkv",
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    cur = f0 - 1
    frame = None
    enc = subprocess.Popen(
        ["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
         "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "15", "-pix_fmt", "yuv420p", out],
        stdin=subprocess.PIPE)
    size = SRC_W * SRC_H * 3
    # the edit is monotonic except where a shot starts earlier than the last one read
    for i, f in zip(range(a, b), need):
        if f < cur:
            reader.kill()
            reader = subprocess.Popen(
                ["ffmpeg", "-loglevel", "error", "-ss", f"{f / FPS:.5f}", "-i", "capture.mkv",
                 "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
            cur = f - 1
        while cur < f:
            buf = reader.stdout.read(size)
            if len(buf) < size:
                break
            frame = np.frombuffer(buf, np.uint8).reshape(SRC_H, SRC_W, 3).astype(np.float32) / 255
            cur += 1
        enc.stdin.write(render(i, frame).tobytes())
    enc.stdin.close()
    enc.wait()
    reader.kill()
    return out


def grab(f):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", "capture.mkv", "-vf", f"select=eq(n\\,{f})",
                          "-vframes", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(SRC_H, SRC_W, 3).astype(np.float32) / 255


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--still":
        for t in [float(x) for x in sys.argv[2:]]:
            i = int(t * FPS)
            Image.fromarray(render(i, grab(source_frame(t)[0]))).save(f"still_{t:05.2f}.png")
        sys.exit()
    os.makedirs("seg", exist_ok=True)
    for f_ in glob.glob("seg/*.mp4"):
        os.remove(f_)
    n = 24
    step = math.ceil(TOTAL / n)
    jobs = [(k * step, min(TOTAL, (k + 1) * step), f"seg/{k:03d}.mp4") for k in range(n) if k * step < TOTAL]
    with Pool(len(jobs)) as p:
        outs = p.map(worker, jobs)
    with open("seg/list.txt", "w") as f:
        for o in outs:
            f.write(f"file '{os.path.basename(o)}'\n")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", "seg/list.txt",
                    "-i", "music.wav", "-c:v", "copy", "-c:a", "aac", "-b:a", "256k", "-shortest",
                    "-movflags", "+faststart", "trailer.mp4"], check=True)
    print("trailer.mp4 done")
