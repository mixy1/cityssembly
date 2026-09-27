"""Cityssembly trailer compositor: footage + motion graphics -> trailer.mp4"""
import glob
import math
import os
import re
import subprocess
import sys
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from timeline import BEAT, BAR, FPS, DURATION, SHOTS, SHOT_END, EDL, bar

W, H = 1920, 1080
SRC_W, SRC_H = 960, 540
TOTAL = int(round((DURATION + 1.0) * FPS))
LINES_OF_ASM = 24005

FONT_DIR = "/usr/share/fonts/opentype/inter/"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
_fonts = {}


def font(weight, size):
    key = (weight, size)
    if key not in _fonts:
        path = MONO if weight == "mono" else FONT_DIR + f"InterDisplay-{weight}.otf"
        _fonts[key] = ImageFont.truetype(path, size)
    return _fonts[key]


# ------------------------------------------------------------------ easing
def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease_out(x):
    x = clamp(x)
    return 1 - (1 - x) ** 3


def ease_in_out(x):
    x = clamp(x)
    return 3 * x * x - 2 * x * x * x


def ease_out_back(x, s=1.4):
    x = clamp(x) - 1
    return x * x * ((s + 1) * x + s) + 1


def window(t, t0, t1, fin=0.25, fout=0.25):
    """0..1 envelope for an element visible from t0 to t1 (seconds)"""
    if t < t0 or t > t1:
        return 0.0
    a = clamp((t - t0) / fin) if fin > 0 else 1
    b = clamp((t1 - t) / fout) if fout > 0 else 1
    return min(ease_out(a), ease_out(b))


# ------------------------------------------------------------------ text
_text_cache = {}


def text_image(txt, weight, size, color=(255, 255, 255), tracking=0.0, glow=0):
    key = (txt, weight, size, color, round(tracking, 2), glow)
    if key in _text_cache:
        return _text_cache[key]
    f = font(weight, size)
    # width with tracking
    widths = [f.getlength(c) for c in txt]
    track = tracking * size
    tw = int(sum(widths) + track * max(0, len(txt) - 1)) + 4
    asc, desc = f.getmetrics()
    th = asc + desc + 4
    pad = glow * 3
    img = Image.new("RGBA", (tw + pad * 2, th + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = pad
    for c, cw in zip(txt, widths):
        d.text((x, pad), c, font=f, fill=color + (255,))
        x += cw + track
    if glow:
        g = img.filter(ImageFilter.GaussianBlur(glow))
        arr = np.array(g).astype(np.float32)
        arr[..., 3] *= 1.6
        g = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
        g.alpha_composite(img)
        img = g
    arr = np.array(img).astype(np.float32) / 255.0
    _text_cache[key] = arr
    return arr


def blit(dst, src, x, y, alpha=1.0):
    """alpha-composite an RGBA float image onto an RGB float frame"""
    h, w = src.shape[:2]
    x, y = int(round(x)), int(round(y))
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + w), min(H, y + h)
    if x0 >= x1 or y0 >= y1 or alpha <= 0:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    a = s[..., 3:4] * alpha
    dst[y0:y1, x0:x1] = dst[y0:y1, x0:x1] * (1 - a) + s[..., :3] * a


def text(dst, txt, weight, size, x, y, alpha=1.0, color=(255, 255, 255),
         tracking=0.0, anchor="c", glow=0, reveal=None):
    """draw text; anchor c = centred on x, l = left, r = right.
    reveal: 0..1 slides the text up from behind a mask line"""
    img = text_image(txt, weight, size, color, tracking, glow)
    h, w = img.shape[:2]
    if anchor == "c":
        x -= w / 2
    elif anchor == "r":
        x -= w
    y -= h / 2
    if reveal is not None:
        r = ease_out(reveal)
        cut = int(h * r)
        if cut <= 0:
            return
        # the visible part rises from below its baseline
        img = img[:cut]
        y += h - cut
    blit(dst, img, x, y, alpha)


def rect(dst, x0, y0, x1, y1, color, alpha=1.0):
    x0, y0, x1, y1 = [int(round(v)) for v in (x0, y0, x1, y1)]
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(W, x1), min(H, y1)
    if x0 >= x1 or y0 >= y1:
        return
    c = np.array(color, np.float32) / 255
    dst[y0:y1, x0:x1] = dst[y0:y1, x0:x1] * (1 - alpha) + c * alpha


# ------------------------------------------------------------------ source code for the cold open
TOKEN_RE = re.compile(r"(;.*$)|(\b(?:r[a-z0-9]{1,3}|e[a-z]{2}|[re]?[abcd]x|[a-d]l|xmm\d+)\b)|(\b0x[0-9a-fA-F]+\b|\b\d+\b)|(\b[a-z]{2,6}\b)", re.M)
MNEMONICS = set("mov lea add sub imul idiv div shl shr sar cmp test jmp je jne jl jg jle jge jb ja jae jbe jz jnz call ret push pop xor and or movzx movsx inc dec neg rep stosb stosd movsb movss mulss addss subss cvtsi2ss bt bts btr sete setg".split())


def load_code():
    lines = []
    for p in ["../src/voxel.asm", "../src/traffic.asm", "../src/sim.asm", "../src/render.asm", "../src/audio.asm"]:
        for ln in open(p):
            ln = ln.rstrip("\n").replace("\t", "    ")
            if ln.strip() and len(ln) < 70:
                lines.append(ln)
    return lines


CODE = load_code()
C_MNEM = (86, 196, 255)
C_REG = (255, 170, 80)
C_NUM = (255, 214, 84)
C_CMT = (110, 118, 140)
C_TXT = (200, 205, 220)
_code_cache = {}


def code_line_image(ln):
    if ln in _code_cache:
        return _code_cache[ln]
    f = font("mono", 22)
    img = Image.new("RGBA", (1100, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = 0
    pos = 0
    for m in TOKEN_RE.finditer(ln):
        if m.start() > pos:
            seg = ln[pos:m.start()]
            d.text((x, 2), seg, font=f, fill=C_TXT)
            x += f.getlength(seg)
        tok = m.group(0)
        col = C_TXT
        if m.group(1):
            col = C_CMT
        elif m.group(2):
            col = C_REG
        elif m.group(3):
            col = C_NUM
        elif m.group(4) and tok in MNEMONICS:
            col = C_MNEM
        d.text((x, 2), tok, font=f, fill=col)
        x += f.getlength(tok)
        pos = m.end()
    if pos < len(ln):
        d.text((x, 2), ln[pos:], font=f, fill=C_TXT)
    arr = np.array(img).astype(np.float32) / 255
    _code_cache[ln] = arr
    return arr


def draw_code_intro(fr, t):
    """bars 1-4: scrolling real source, headlines, rising glitch"""
    p = t / (bar(5))
    speed = 40 + 900 * p ** 3                     # px per second, accelerating
    scroll = 40 * t + 300 * p ** 4 * 60
    lh = 30
    first = int(scroll // lh)
    off = scroll % lh
    rows = H // lh + 2
    for r in range(rows):
        idx = (first + r) % len(CODE)
        y = r * lh - off
        # fade toward the edges, dimmer behind the headlines
        edge = min(y, H - y) / 260
        a = clamp(edge) * (0.38 + 0.35 * p)
        img = code_line_image(CODE[idx])
        blit(fr, img, 120 + 18 * math.sin(idx * 1.7), y, a)
    # typing cursor line
    cur = int(t * 2) % 2
    if cur:
        rect(fr, 1500, 540, 1514, 568, (86, 196, 255), 0.8)
    # headlines
    b1, b2, b3, b4 = bar(1), bar(2), bar(3), bar(4)
    a = window(t, b1 + 0.3, b2 + BEAT * 3.4, 0.5, 0.4)
    text(fr, "Some games are built on engines.", "Medium", 64, W / 2, H / 2 - 20, a, tracking=0.01,
         reveal=clamp((t - b1 - 0.3) / 0.7))
    a = window(t, b2 + BEAT * 0.5 + 0.2, b3 + BEAT * 3.5, 0.5, 0.4)
    text(fr, "This one was built on instructions.", "SemiBold", 64, W / 2, H / 2 - 20, a,
         reveal=clamp((t - b2 - BEAT * 0.5 - 0.2) / 0.7))
    # bar 4: three hits
    for k, word in enumerate(["EVERY PIXEL.", "EVERY CAR.", "EVERY CITIZEN."]):
        t0 = b4 + k * BEAT
        a = window(t, t0, t0 + BEAT * 0.95, 0.06, 0.1)
        if a > 0:
            s = 1.12 - 0.12 * ease_out((t - t0) / 0.25)
            text(fr, word, "Black", int(118 * s), W / 2, H / 2, a, tracking=0.04)
    if t > b4 + BEAT * 3:
        a = window(t, b4 + BEAT * 3, bar(5), 0.05, 0.02)
        text(fr, "IN PURE ASSEMBLY.", "Black", 118, W / 2, H / 2, a, color=(86, 196, 255), tracking=0.04, glow=10)


# ------------------------------------------------------------------ pixel logo from the game's font
def load_game_font():
    glyphs = {}
    src = open("../src/font.asm").read()
    rows = re.findall(r'^G ((?:"[.#]{5}",?){8})', src, re.M)
    for i, r in enumerate(rows):
        parts = re.findall(r'"([.#]{5})"', r)
        glyphs[chr(33 + i)] = parts
    return glyphs


GAME_FONT = load_game_font()


def pixel_logo(word, scale, extrude=8):
    """bitmap wordmark with an isometric-ish pixel extrusion and a glow"""
    cols = []
    for ch in word:
        g = GAME_FONT[ch]
        used = [c for c in range(5) if any(row[c] == "#" for row in g)]
        c0, c1 = min(used), max(used)
        for c in range(c0, c1 + 1):
            cols.append([row[c] == "#" for row in g[:7]])
        cols.append([False] * 7)
    bw = len(cols) * scale
    bh = 7 * scale
    pad = extrude * scale // 2 + 60
    img = np.zeros((bh + pad * 2, bw + pad * 2, 4), np.float32)
    top = np.array([1.0, 0.83, 0.33])       # gold
    side = np.array([0.55, 0.30, 0.12])
    for layer in range(extrude, -1, -1):
        dx = layer * scale // 6
        dy = layer * scale // 6
        col = top if layer == 0 else side * (0.7 + 0.3 * (1 - layer / extrude))
        for ci, colbits in enumerate(cols):
            for ri, on in enumerate(colbits):
                if on:
                    x = pad + ci * scale + dx
                    y = pad + ri * scale + dy
                    img[y:y + scale, x:x + scale, :3] = col
                    img[y:y + scale, x:x + scale, 3] = 1.0
    # highlight the top edge of each pixel block
    pil = Image.fromarray((img * 255).astype(np.uint8))
    glow = pil.filter(ImageFilter.GaussianBlur(28))
    g = np.array(glow).astype(np.float32) / 255
    g[..., :3] = np.array([1.0, 0.65, 0.2])
    g[..., 3] *= 0.9
    out = g.copy()
    a = img[..., 3:4]
    out[..., :3] = out[..., :3] * (1 - a) + img[..., :3] * a
    out[..., 3:4] = np.maximum(out[..., 3:4], a)
    return out


LOGO = None


# ------------------------------------------------------------------ grading
def bloom(img, strength=0.35):
    lum = img.mean(axis=2, keepdims=True)
    bright = np.clip((lum - 0.62) / 0.38, 0, 1) * img
    small = bright[::8, ::8]
    pil = Image.fromarray((np.clip(small, 0, 1) * 255).astype(np.uint8))
    pil = pil.filter(ImageFilter.GaussianBlur(6))
    b = np.array(pil.resize((W, H), Image.BILINEAR)).astype(np.float32) / 255
    return img + b * strength


VIG = None


def vignette():
    global VIG
    if VIG is None:
        y, x = np.mgrid[0:H, 0:W].astype(np.float32)
        d = np.sqrt(((x - W / 2) / (W / 2)) ** 2 + ((y - H / 2) / (H / 2)) ** 2)
        VIG = (1 - 0.32 * np.clip(d - 0.35, 0, 1) ** 1.6)[..., None]
    return VIG


def grade(img):
    img = np.clip(img, 0, 1)
    # gentle s-curve and saturation
    img = img * img * (3 - 2 * img) * 0.35 + img * 0.65
    lum = img.mean(axis=2, keepdims=True)
    img = lum + (img - lum) * 1.12
    return img


def rgb_split(img, amount):
    if amount < 1:
        return img
    a = int(amount)
    out = img.copy()
    out[:, a:, 0] = img[:, :-a, 0]
    out[:, :-a, 2] = img[:, a:, 2]
    return out


def slice_glitch(img, amount, seed):
    if amount <= 0:
        return img
    rng = np.random.default_rng(seed)
    out = img.copy()
    for _ in range(int(3 + amount * 10)):
        y = rng.integers(0, H - 40)
        h = rng.integers(6, 60)
        s = int(rng.integers(-60, 60) * amount)
        out[y:y + h] = np.roll(img[y:y + h], s, axis=1)
    return out


def zoom_punch(img, z):
    if z <= 1.001:
        return img
    ch, cw = int(H / z), int(W / z)
    y0, x0 = (H - ch) // 2, (W - cw) // 2
    crop = img[y0:y0 + ch, x0:x0 + cw]
    pil = Image.fromarray((np.clip(crop, 0, 1) * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)
    return np.array(pil).astype(np.float32) / 255


# ------------------------------------------------------------------ footage lookup
def source_frame(t):
    """-> (source frame index or None, edl entry, local time)"""
    b = t / BAR + 1
    for (b0, b1, shot, off, extra) in EDL:
        if b0 <= b < b1:
            if shot is None:
                return None, (b0, b1, shot), t - bar(b0)
            local = t - bar(b0)
            sp = extra.get("speed", 1.0)
            start = SHOTS[shot]
            names = list(SHOTS)
            nxt = names.index(shot) + 1
            end = SHOTS[names[nxt]] if nxt < len(names) else SHOT_END
            f = start + off + int(local * FPS * sp)
            return min(f, end - 1), (b0, b1, shot), local
    return SHOT_END - 1, (31, 34, "wide"), t - bar(31)


DROPS = [bar(5), bar(9), bar(25), bar(31)]
CUTS = [bar(e[0]) for e in EDL]


SCRIM = None


def scrim(fr, strength):
    """dark gradient at the bottom of the frame behind captions"""
    global SCRIM
    if SCRIM is None:
        y = np.linspace(0, 1, H, dtype=np.float32)
        SCRIM = (1 - 0.72 * np.clip((y - 0.6) / 0.3, 0, 1) ** 1.3)[:, None, None]
    if strength > 0:
        fr *= 1 - (1 - SCRIM) * strength


CAPTION_SHOTS = {"valley", "build", "follow", "district", "sunset", "night", "meteor"}


def overlays(fr, t, shot, local):
    """all the titles on top of the footage"""
    if shot in CAPTION_SHOTS:
        scrim(fr, 1.0)
    B5, B7, B8, B9 = bar(5), bar(7), bar(8), bar(9)
    if shot == "valley":
        a = window(t, B5 + 0.4, bar(7) - 0.1, 0.5, 0.3)
        text(fr, "START WITH A VALLEY", "Bold", 44, 140, 860, a, tracking=0.18, anchor="l", reveal=clamp((t - B5 - 0.4) / 0.6))
        rect(fr, 140, 900, 140 + 380 * ease_out((t - B5 - 0.6) / 0.8), 903, (255, 214, 84), a)
        text(fr, "// procedurally generated terrain, seasons and weather light", "mono", 22, 140, 935, a * 0.8, color=(170, 180, 200), anchor="l")
    if shot == "build":
        a = window(t, B7 + 0.1, B8 - 0.05, 0.35, 0.2)
        text(fr, "DRAW THE ROADS.", "Black", 76, 140, 860, a, tracking=0.06, anchor="l", reveal=clamp((t - B7) / 0.5))
        a = window(t, B8, B9 - 0.02, 0.3, 0.1)
        text(fr, "ZONE THE LAND.", "Black", 76, 140, 860, a, tracking=0.06, anchor="l", reveal=clamp((t - B8) / 0.5))
    if shot == "grow":
        a = window(t, B9, bar(10.5), 0.02, 0.5)
        if a > 0:
            s = 1.25 - 0.25 * ease_out((t - B9) / 0.5)
            text(fr, "WATCH IT GROW", "Black", int(150 * s), W / 2, H / 2 - 20, a, tracking=0.05, glow=14)
        words = ["HOMES", "SHOPS", "OFFICES", "FACTORIES", "FARMS"]
        for k, w_ in enumerate(words):
            t0 = bar(11) + k * BEAT * 1.4
            a = window(t, t0, bar(13) - 0.1, 0.25, 0.25)
            text(fr, w_, "Bold", 40, 200 + k * 330, 930, a, tracking=0.2, reveal=clamp((t - t0) / 0.4))
    if shot == "follow":
        t0 = bar(13) + 0.3
        a = window(t, t0, bar(15) - 0.1, 0.4, 0.3)
        text(fr, "EVERY CAR HAS SOMEWHERE TO BE", "Black", 64, 140, 840, a, tracking=0.03, anchor="l", reveal=clamp((t - t0) / 0.6))
        text(fr, "// Dijkstra routing  ·  live congestion  ·  up to 1,200 vehicles", "mono", 24, 140, 905, a * 0.85, color=(86, 196, 255), anchor="l")
    if shot == "district":
        t0 = bar(15) + 0.2
        a = window(t, t0, bar(17) - 0.1, 0.4, 0.3)
        text(fr, "HUNDREDS OF VOXEL-BAKED BUILDINGS", "Black", 60, W - 140, 840, a, tracking=0.03, anchor="r", reveal=clamp((t - t0) / 0.6))
        text(fr, "// every model ray-traced into pixel art at startup", "mono", 24, W - 140, 905, a * 0.85, color=(255, 214, 84), anchor="r")
    views = {"view_power": ("POWER", (255, 214, 84)), "view_water": ("WATER", (86, 196, 255)),
             "view_traffic": ("TRAFFIC", (244, 84, 72)), "view_land": ("LAND VALUE", (112, 224, 112))}
    if shot in views:
        word, col = views[shot]
        s = 1.18 - 0.18 * ease_out(local / 0.2)
        text(fr, word, "Black", int(170 * s), W / 2, H / 2, 0.92, color=col, tracking=0.06, glow=12)
        text(fr, "INFO VIEWS", "Bold", 28, W / 2, H / 2 + 120, 0.8, tracking=0.5)
    if shot == "sunset":
        t0 = bar(19) + 0.5
        a = window(t, t0, bar(21) - 0.2, 0.8, 0.5)
        text(fr, "DAY TURNS TO NIGHT", "Light", 72, W / 2, 900, a, tracking=0.25, reveal=clamp((t - t0) / 1.0))
    if shot == "night":
        t0 = bar(21) + 0.4
        a = window(t, t0, bar(23) - 0.2, 0.8, 0.5)
        text(fr, "THE CITY NEVER SLEEPS", "Light", 72, W / 2, 900, a, tracking=0.25, reveal=clamp((t - t0) / 1.0))
    if shot == "seasons":
        f = local * FPS * 0.98
        pos = (128 + 8 * f) % 1024
        season = ["SPRING", "SUMMER", "AUTUMN", "WINTER"][int(pos // 256)]
        text(fr, season, "Black", 120, W / 2, H / 2, 0.9, tracking=0.12, glow=8)
        text(fr, "FOUR SEASONS", "Bold", 28, W / 2, H / 2 + 100, 0.75, tracking=0.5)
    if shot == "meteor":
        a = window(t, bar(25) + 0.15, bar(26.5), 0.05, 0.4)
        if a > 0:
            s = 1.3 - 0.3 * ease_out((t - bar(25) - 0.15) / 0.3)
            text(fr, "DISASTERS STRIKE", "Black", int(130 * s), W / 2, H / 2 - 40, a, color=(255, 90, 60), tracking=0.04, glow=16)
        t0 = bar(26)
        a = window(t, t0, bar(27) - 0.05, 0.3, 0.1)
        text(fr, "Fire trucks race the flames.", "SemiBold", 48, W / 2, 900, a, reveal=clamp((t - t0) / 0.5))
    if shot and shot.startswith("ui_"):
        feats = ["POWER GRIDS", "WATER & SEWAGE", "GARBAGE", "SCHOOLS & JOBS", "BUS NETWORKS", "POLICIES", "TAXES & BUDGETS", "INFO VIEWS"]
        t_all = bar(27)
        for k, f_ in enumerate(feats):
            t0 = t_all + k * BEAT
            a = window(t, t0, bar(29) - 0.05, 0.15, 0.15)
            if a <= 0:
                continue
            slide = (1 - ease_out((t - t0) / 0.3)) * 80
            y = 170 + k * 88
            rect(fr, W - 560 + slide, y - 34, W - 90 + slide, y + 34, (14, 16, 26), 0.78 * a)
            rect(fr, W - 560 + slide, y - 34, W - 554 + slide, y + 34, (255, 214, 84), a)
            text(fr, f_, "Bold", 36, W - 530 + slide, y, a, tracking=0.08, anchor="l")
    if shot == "finale":
        t0 = bar(29) + 0.1
        a = window(t, t0, bar(31) - 0.05, 0.3, 0.1)
        n = int(LINES_OF_ASM * ease_out((t - t0) / 2.0))
        text(fr, f"{n:,}", "Black", 180, W / 2, H / 2 - 70, a, tracking=0.02, glow=10)
        text(fr, "LINES OF HAND-WRITTEN x86-64 ASSEMBLY", "Bold", 40, W / 2, H / 2 + 60, a, tracking=0.2)
        t1 = bar(30) + 0.2
        a2 = window(t, t1, bar(31) - 0.05, 0.3, 0.1)
        text(fr, "NO ENGINE.  NO FRAMEWORK.  ONE EXECUTABLE.", "Medium", 34, W / 2, H / 2 + 130, a2, color=(86, 196, 255), tracking=0.25,
             reveal=clamp((t - t1) / 0.5))


def end_card(fr, t):
    global LOGO
    if LOGO is None:
        LOGO = pixel_logo("CITYSSEMBLY", 22)
    t0 = bar(31)
    p = ease_out_back((t - t0) / 0.7, 1.2)
    a = clamp((t - t0) / 0.15)
    h, w = LOGO.shape[:2]
    s = 0.85 + 0.15 * p
    if s != 1.0:
        img = Image.fromarray((np.clip(LOGO, 0, 1) * 255).astype(np.uint8))
        img = img.resize((int(w * s), int(h * s)), Image.NEAREST)
        L = np.array(img).astype(np.float32) / 255
    else:
        L = LOGO
    lh, lw = L.shape[:2]
    blit(fr, L, W / 2 - lw / 2, H / 2 - 110 - lh / 2, a)
    t1 = t0 + BEAT * 2
    a = window(t, t1, DURATION + 5, 0.5, 0.1)
    text(fr, "BUILD A LIVING CITY.  WRITTEN IN PURE ASSEMBLY.", "Medium", 38, W / 2, H / 2 + 95, a, tracking=0.22,
         reveal=clamp((t - t1) / 0.6))
    t2 = t0 + BEAT * 4
    a = window(t, t2, DURATION + 5, 0.5, 0.1)
    text(fr, "FREE  ·  WINDOWS & LINUX", "Bold", 30, W / 2, H / 2 + 175, a, color=(255, 214, 84), tracking=0.35)
    text(fr, "github.com/mixy1/cityssembly", "mono", 30, W / 2, H / 2 + 230, a, color=(170, 180, 200))


# ------------------------------------------------------------------ render one output frame
def render(i, src):
    t = i / FPS
    fr = np.zeros((H, W, 3), np.float32)
    info = source_frame(t)
    shot = info[1][2]
    local = info[2]
    if src is not None:
        fr[:] = np.repeat(np.repeat(src, 2, axis=0), 2, axis=1)
        fr = grade(fr)
        fr = bloom(fr, 0.42 if shot in ("night", "sunset", "finale") else 0.25)
    # end card darkens + blurs the wide shot
    if t >= bar(31):
        k = ease_in_out((t - bar(31)) / 0.8)
        small = Image.fromarray((np.clip(fr, 0, 1) * 255).astype(np.uint8)).resize((W // 4, H // 4), Image.BILINEAR)
        blur = np.array(small.filter(ImageFilter.GaussianBlur(3)).resize((W, H), Image.BILINEAR)).astype(np.float32) / 255
        fr = fr * (1 - k) + blur * k
        fr *= 1 - 0.55 * k
    if shot is None:
        fr[:] = np.array([6, 7, 12], np.float32) / 255
        draw_code_intro(fr, t)
    # punch zoom + flash on the drops
    for d in DROPS:
        if 0 <= t - d < 0.35:
            fr = zoom_punch(fr, 1.0 + 0.07 * (1 - ease_out((t - d) / 0.35)))
    # meteor shake
    if bar(25) <= t < bar(25) + 1.2:
        k = 1 - (t - bar(25)) / 1.2
        rng = np.random.default_rng(i)
        dx, dy = rng.integers(-18, 19) * k, rng.integers(-12, 13) * k
        fr = np.roll(np.roll(fr, int(dy), axis=0), int(dx), axis=1)
        fr = rgb_split(fr, 10 * k)
    # glitch transitions around the fast cuts
    for c in [bar(17), bar(17.5), bar(18), bar(18.5), bar(19), bar(27), bar(27.66), bar(28.33), bar(4.75)]:
        dt = t - c
        if -0.07 < dt < 0.1:
            k = 1 - abs(dt) / 0.1
            fr = slice_glitch(fr, k, i)
            fr = rgb_split(fr, 14 * k)
    if bar(4) <= t < bar(5):
        k = ((t - bar(4)) / BAR) ** 2
        if i % 3 == 0:
            fr = slice_glitch(fr, k * 0.8, i)
        fr = rgb_split(fr, 8 * k)
    if src is not None:
        fr *= vignette()
    # letterbox (not over the interface shots)
    if shot is not None and not shot.startswith("ui_") and t < bar(31):
        bars_h = 96
        fr[:bars_h] = 0
        fr[H - bars_h:] = 0
    overlays(fr, t, shot, local)
    if t >= bar(31):
        end_card(fr, t)
    # flash frames on the big cuts
    for d in DROPS:
        if 0 <= t - d < 0.12:
            k = 1 - (t - d) / 0.12
            fr = fr * (1 - k) + k
    # fade from / to black
    if t > DURATION - 0.3:
        fr *= clamp((DURATION + 0.7 - t) / 1.0)
    # grain
    rng = np.random.default_rng(i * 7 + 1)
    fr += (rng.random((H // 2, W // 2, 1), dtype=np.float32) - 0.5).repeat(2, 0).repeat(2, 1) * 0.025
    return (np.clip(fr, 0, 1) * 255).astype(np.uint8)


# ------------------------------------------------------------------ workers
def worker(args):
    a, b, out = args
    need = [source_frame(i / FPS)[0] for i in range(a, b)]
    srcs = [f for f in need if f is not None]
    reader = None
    cur = -1
    frame = None
    if srcs:
        f0 = min(srcs)
        reader = subprocess.Popen(
            ["ffmpeg", "-loglevel", "error", "-ss", f"{f0 / FPS:.5f}", "-i", "capture.mkv",
             "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
        cur = f0 - 1
    enc = subprocess.Popen(
        ["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
         "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "14", "-pix_fmt", "yuv420p", out],
        stdin=subprocess.PIPE)
    size = SRC_W * SRC_H * 3
    for i, f in zip(range(a, b), need):
        src = None
        if f is not None:
            while cur < f:
                buf = reader.stdout.read(size)
                if len(buf) < size:
                    break
                frame = np.frombuffer(buf, np.uint8).reshape(SRC_H, SRC_W, 3).astype(np.float32) / 255
                cur += 1
            src = frame
        enc.stdin.write(render(i, src).tobytes())
    enc.stdin.close()
    enc.wait()
    if reader:
        reader.kill()
    return out


if __name__ == "__main__":
    only = None
    if len(sys.argv) > 1 and sys.argv[1] == "--still":
        # render a few stills for review
        ts = [float(x) for x in sys.argv[2:]]
        for t in ts:
            i = int(t * FPS)
            f = source_frame(t)[0]
            src = None
            if f is not None:
                raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", "capture.mkv", "-vf", f"select=eq(n\\,{f})",
                                      "-vframes", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
                src = np.frombuffer(raw, np.uint8).reshape(SRC_H, SRC_W, 3).astype(np.float32) / 255
            Image.fromarray(render(i, src)).save(f"still_{t:05.1f}.png")
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
