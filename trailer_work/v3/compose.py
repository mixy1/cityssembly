"""Trailer v3 compositor: edit, camera, grade, type, mux.

python3 compose.py              -> trailer_v3.mp4 (1920x1080, 30 fps)
python3 compose.py --still 12.5 20 ...   (bars) -> stills/*.png
"""
import json
import math
import os
import subprocess
import sys
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from timeline import EDIT, BAR_FRAMES, FPS, BARS, IMPACT_BAR, LOGO_BAR, PRE, bar  # noqa

W, H = 1920, 1080
CW, CH = 2560, 1440                       # capture size (world px 1:1)
CAP = os.path.join(HERE, "cap")
TAKES = json.load(open(os.path.join(CAP, "takes.json")))
TOTAL = BARS * BAR_FRAMES
STORY_BARS = BARS - PRE
FONT = "/usr/share/fonts/opentype/inter/InterDisplay-Medium.otf"
FONT_LIGHT = "/usr/share/fonts/opentype/inter/InterDisplay-Light.otf"
FONT_BOLD = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
for f in ("FONT_LIGHT", "FONT_BOLD"):
    if not os.path.exists(globals()[f]):
        globals()[f] = FONT


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def smooth(u):
    u = clamp(u)
    return u * u * (3 - 2 * u)


def ease_out(u):
    u = clamp(u)
    return 1 - (1 - u) ** 3


def ease_in_out(u):
    u = clamp(u)
    return 0.5 - 0.5 * math.cos(math.pi * u)


def tile_px(take, tx, ty):
    """capture pixel of a tile centre (the take's camera tile is at the centre)"""
    cx, cy = TAKES[take]["cam"]
    return (CW / 2 + ((tx - ty) - (cx - cy)) * 16, CH / 2 + ((tx + ty) - (cx + cy)) * 8)


def off(take, dx, dy):
    """capture pixel of the camera tile + (dx, dy) tiles"""
    cx, cy = TAKES[take]["cam"]
    return tile_px(take, cx + dx, cy + dy)


# ------------------------------------------------------------------ shots
# per take: source start frame, speed, camera keyframes [(u, (px, py), zoom)]
def lin_cam(take, a, b, za, zb):
    return [(0.0, off(take, *a), za), (1.0, off(take, *b), zb)]


SHOTS = {
    "valley": dict(start=0, speed=1.0, cam=lin_cam("valley", (-6, 2), (3, -1), 1.05, 1.3), ease=ease_in_out),
    "road": dict(start=None, speed=None, cam=None, zoom=3.1),              # follows the tip
    "houses": dict(start=30, speed=1.0, cam=lin_cam("houses", (0, 2), (0, 1), 3.2, 3.6)),
    "car": dict(start=20, speed=1.0, cam=None, zoom=3.6),                  # follows the car
    "oldtown": dict(start=8, speed=1.0, cam=lin_cam("oldtown", (-2, 1), (1, -1), 2.8, 3.0)),
    "shore": dict(start=8, speed=1.0, cam=lin_cam("shore", (1, 2), (-1, 0), 2.6, 2.7)),
    "downtown": dict(start=8, speed=1.0, cam=lin_cam("downtown", (1, 0), (-1, 1), 2.3, 2.5)),
    "uptown": dict(start=8, speed=1.0, cam=lin_cam("uptown", (0, -2), (1, 1), 2.6, 2.4)),
    "works": dict(start=8, speed=1.0, cam=lin_cam("works", (-2, 0), (1, 0), 2.4, 2.6)),
    "bridge": dict(start=8, speed=1.0, cam=lin_cam("bridge", (1, -1), (-1, 1), 2.7, 2.9)),
    "north": dict(start=8, speed=1.0, cam=lin_cam("north", (0, 1), (2, -1), 2.4, 2.6)),
    "stadium": dict(start=8, speed=1.0, cam=lin_cam("stadium", (1, 1), (0, 0), 2.8, 3.2)),
    "timelapse": dict(start=0, speed=480 / 440, cam=lin_cam("timelapse", (0, 0), (0, 0), 1.0, 1.12)),
    "view_power": dict(start=4, speed=1.0, cam=lin_cam("view_power", (0, 0), (1, 0), 1.5, 1.55)),
    "view_water": dict(start=4, speed=1.0, cam=lin_cam("view_water", (1, 0), (2, 0), 1.55, 1.6)),
    "view_traffic": dict(start=4, speed=1.0, cam=lin_cam("view_traffic", (2, 0), (3, 0), 1.6, 1.65)),
    "view_land": dict(start=4, speed=1.0, cam=lin_cam("view_land", (3, 0), (4, 0), 1.65, 1.7)),
    "night": dict(start=10, speed=1.0, cam=lin_cam("night", (-3, 2), (2, -1), 1.7, 1.9)),
    "fire": dict(start=20, speed=1.0, cam=lin_cam("fire", (0, 0), (0, -1), 3.2, 3.6)),
    "fire_wide": dict(start=20, speed=1.0, cam=lin_cam("fire_wide", (0, 0), (1, 0), 2.0, 2.1)),
    "meteor": dict(start=None, speed=1.0, cam=lin_cam("meteor", (0, 0), (0, 0), 1.9, 2.1)),
    "gold_a": dict(start=8, speed=1.0, cam=lin_cam("gold_a", (-2, 2), (1, -1), 2.3, 2.5)),
    "gold_b": dict(start=8, speed=1.0, cam=lin_cam("gold_b", (0, 2), (1, -1), 2.5, 2.6)),
    "gold_c": dict(start=8, speed=1.0, cam=lin_cam("gold_c", (1, 0), (0, 0), 2.8, 3.0)),
    "gold_d": dict(start=8, speed=1.0, cam=lin_cam("gold_d", (0, 0), (-1, 0), 2.6, 2.8)),
    "wide": dict(start=0, speed=1.0, cam=None),
}


def edit_at(f):
    """output frame -> (take, local frame in the shot, shot length, entry)"""
    b = f / BAR_FRAMES + 1
    for e in EDIT:
        b0, b1, take, cap = e
        if b0 <= b < b1:
            return take, f - (b0 - 1) * BAR_FRAMES, (b1 - b0) * BAR_FRAMES, e
    return None, 0, 1, None


def road_map(local):
    """source frame for the road shot: each tile lands on its eighth note"""
    tiles = TAKES["road"]["tiles"]
    k = local / 10.0                       # eighth notes since the shot began
    i = int(k)
    if i + 1 < len(tiles):
        a, b = tiles[i][0], tiles[i + 1][0]
        return a + (b - a) * (k - i), i
    return tiles[-1][0] + (k - len(tiles) + 1) * 10, len(tiles) - 1


def source_and_cam(take, local, length):
    sh = SHOTS[take]
    u = local / max(1, length - 1)
    if take == "road":
        sf, i = road_map(local)
        # camera: ease toward the tile being laid
        tiles = TAKES["road"]["tiles"]
        k = local / 10.0
        j = min(len(tiles) - 1, int(k))
        tx = tiles[j][1] + (k - j) * 0.6 - 3
        px, py = tile_px("road", tx, 64)
        return sf, (px, py - 20), sh["zoom"]
    if take == "car":
        cars = TAKES["car"]["car"]
        sf = sh["start"] + local
        pts = [c for c in cars if abs(c[0] - sf) <= 12]
        if pts:
            cx = sum(c[1] for c in pts) / len(pts)
            cy = sum(c[2] for c in pts) / len(pts)
        else:
            cx, cy = CW / 2, CH / 2
        return sf, (cx, cy), sh["zoom"]
    if take == "meteor":
        imp = TAKES["meteor"]["impact"]
        sf = imp - (IMPACT_BAR - 29.5) * BAR_FRAMES + local
    elif take == "wide":
        sf = local
        # pull out over bars 35-37, then hold for the logo
        v = ease_in_out(local / (2 * BAR_FRAMES))
        z = 2.6 + (0.92 - 2.6) * v
        p0 = off("wide", 2, -3)
        p1 = off("wide", 0, 0)
        return sf, (p0[0] + (p1[0] - p0[0]) * v, p0[1] + (p1[1] - p0[1]) * v), z
    else:
        sf = sh["start"] + local * sh["speed"]
    (u0, p0, z0), (u1, p1, z1) = sh["cam"][0], sh["cam"][-1]
    e = sh.get("ease", smooth)(u)
    return sf, (p0[0] + (p1[0] - p0[0]) * e, p0[1] + (p1[1] - p0[1]) * e), z0 + (z1 - z0) * e


# ------------------------------------------------------------------ frame readers
class Reader:
    def __init__(self):
        self.take = None
        self.proc = None
        self.cur = -1
        self.frame = None

    def get(self, take, f):
        n = TAKES[take]["frames"]
        f = int(clamp(round(f), 0, n - 1))
        if take != self.take or f < self.cur or f > self.cur + 40:
            if self.proc:
                self.proc.kill()
                self.proc.wait()
            self.proc = subprocess.Popen(
                ["ffmpeg", "-loglevel", "error", "-threads", "2", "-ss", f"{f / FPS:.4f}", "-i", os.path.join(CAP, f"{take}.mkv"),
                 "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
            self.take = take
            self.cur = f - 1
        while self.cur < f:
            buf = self.proc.stdout.read(CW * CH * 3)
            if len(buf) < CW * CH * 3:
                break
            self.frame = np.frombuffer(buf, np.uint8).reshape(CH, CW, 3)
            self.cur += 1
        return self.frame


def camera_view(src, center, zoom):
    """crisp pixel art at any zoom and sub-pixel position: integer nearest
    upscale of the crop, then a filtered resample to the output"""
    cx, cy = center
    hw, hh = W / 2 / zoom, H / 2 / zoom
    cx = clamp(cx, hw, CW - hw)
    cy = clamp(cy, hh, CH - hh)
    x0, y0 = cx - hw, cy - hh
    ix0, iy0 = int(math.floor(x0)) - 1, int(math.floor(y0)) - 1
    ix1, iy1 = int(math.ceil(cx + hw)) + 1, int(math.ceil(cy + hh)) + 1
    ix0, iy0 = max(0, ix0), max(0, iy0)
    ix1, iy1 = min(CW, ix1), min(CH, iy1)
    im = Image.fromarray(src[iy0:iy1, ix0:ix1])
    k = max(1, int(math.ceil(zoom)))
    im = im.resize((im.width * k, im.height * k), Image.NEAREST)
    box = ((x0 - ix0) * k, (y0 - iy0) * k, (x0 - ix0 + 2 * hw) * k, (y0 - iy0 + 2 * hh) * k)
    return np.asarray(im.resize((W, H), Image.BILINEAR, box=box), np.float32) / 255


# ------------------------------------------------------------------ grading
def act_of(b):
    if b < 9:
        return 1
    if b < 17:
        return 2
    if b < 25:
        return 3
    if b < 32:
        return 4
    return 5


GRADE = {  # lift (shadows tint), gain, saturation, contrast
    1: ((0.04, 0.03, 0.06), (1.02, 1.0, 0.96), 1.05, 1.05),
    2: ((0.02, 0.02, 0.03), (1.03, 1.01, 0.98), 1.12, 1.08),
    3: ((0.02, 0.02, 0.03), (1.02, 1.01, 1.0), 1.1, 1.06),
    4: ((0.01, 0.02, 0.06), (0.95, 0.98, 1.08), 0.95, 1.12),
    5: ((0.05, 0.03, 0.02), (1.06, 1.01, 0.93), 1.15, 1.08),
}
_vig = None


def vignette():
    global _vig
    if _vig is None:
        y, x = np.mgrid[0:H, 0:W].astype(np.float32)
        d = np.sqrt(((x - W / 2) / (W / 2)) ** 2 + ((y - H / 2) / (H / 2)) ** 2)
        _vig = (1 - 0.35 * np.clip(d - 0.35, 0, 1) ** 1.6)[..., None]
    return _vig


def grade(img, act):
    lift, gain, sat, con = GRADE[act]
    img = img * np.array(gain, np.float32) + np.array(lift, np.float32) * (1 - img)
    lum = img.mean(axis=2, keepdims=True)
    img = lum + (img - lum) * sat
    img = (img - 0.5) * con + 0.5
    return img * vignette()


def bloom(img, strength, thresh=0.62):
    lum = img.max(axis=2, keepdims=True)
    br = np.clip((lum - thresh) / (1 - thresh), 0, 1) * img
    sm = Image.fromarray((np.clip(br[::4, ::4], 0, 1) * 255).astype(np.uint8))
    sm = sm.filter(ImageFilter.GaussianBlur(10))
    b = np.asarray(sm.resize((W, H), Image.BILINEAR), np.float32) / 255
    return img + b * strength


_tilt = {}


def tilt_shift(img, amount):
    """miniature look: blur toward top and bottom"""
    if amount <= 0:
        return img
    if "mask" not in _tilt:
        y = np.linspace(-1, 1, H, dtype=np.float32)
        _tilt["mask"] = np.clip((np.abs(y) - 0.25) / 0.6, 0, 1)[:, None, None] ** 1.5
    sm = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((W // 4, H // 4), Image.BILINEAR)
    sm = sm.filter(ImageFilter.GaussianBlur(2.2)).resize((W, H), Image.BILINEAR)
    blur = np.asarray(sm, np.float32) / 255
    m = _tilt["mask"] * amount
    return img * (1 - m) + blur * m


_grain = None


def grain(img, f, amount=0.018):
    global _grain
    if _grain is None:
        r = np.random.default_rng(5)
        _grain = [r.standard_normal((H // 2, W // 2, 1)).astype(np.float32) for _ in range(8)]
    g = _grain[f % 8].repeat(2, 0).repeat(2, 1)
    return img + g * amount


# ------------------------------------------------------------------ type
_fonts = {}


def font(path, size):
    k = (path, size)
    if k not in _fonts:
        _fonts[k] = ImageFont.truetype(path, size)
    return _fonts[k]


def text_layer(draw_fn):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(im))
    return im


def spaced(draw, xy, text, fnt, fill, tracking, anchor="mm"):
    """draw text with letter spacing (tracking in px), centred on xy"""
    widths = [draw.textlength(ch, font=fnt) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x, y = xy
    if anchor == "mm":
        x -= total / 2
    elif anchor == "rm":
        x -= total
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=fnt, fill=fill, anchor="lm")
        x += w + tracking
    return total


def over(img, layer, alpha=1.0):
    a = np.asarray(layer, np.float32) / 255
    al = a[..., 3:4] * alpha
    return img * (1 - al) + a[..., :3] * al


def caption_intro(img, t_bar):
    """act I statements, centred, fading"""
    lines = [(1.6, 3.2, "EVERY CITY"), (3.7, 6.2, "BEGINS WITH A SINGLE ROAD")]
    for b0, b1, txt in lines:
        if b0 <= t_bar < b1:
            a = min(smooth((t_bar - b0) / 0.35), smooth((b1 - t_bar) / 0.4))
            lay = text_layer(lambda d: spaced(d, (W / 2, H * 0.78), txt, font(FONT_LIGHT, 38), (245, 240, 230, 255), 14))
            img = over(img, lay, a)
    return img


def caption_location(img, t_bar, name, b0):
    """act II: lower-left location title, a thin rule wiping in"""
    u = t_bar - b0
    if u < 0.06 or u > 0.94:
        return img
    a = min(smooth((u - 0.06) / 0.1), smooth((0.94 - u) / 0.1))
    wipe = ease_out((u - 0.06) / 0.25)

    def d(dr):
        x, y = 110, H - 170
        wtxt = spaced(dr, (x, y), name, font(FONT_BOLD, 46), (255, 255, 255, 255), 9, anchor="lm")
        dr.rectangle((x, y + 40, x + (wtxt + 10) * wipe, y + 43), fill=(255, 210, 90, 255))
    lay = text_layer(d)
    return over(img, lay, a)


def caption_small(img, t_bar, name, b0, b1):
    """info views: a label in the corner"""
    u = (t_bar - b0) / (b1 - b0)
    a = min(smooth(u / 0.15), smooth((1 - u) / 0.15))
    lay = text_layer(lambda dr: spaced(dr, (110, 190), name, font(FONT_BOLD, 34), (255, 255, 255, 255), 8, anchor="lm"))
    return over(img, lay, a)


def caption_tested(img, t_bar):
    b0, b1 = 26.0, 29.3
    if not (b0 <= t_bar < b1):
        return img
    a = min(smooth((t_bar - b0) / 0.5), smooth((b1 - t_bar) / 0.5))
    lay = text_layer(lambda d: spaced(d, (W / 2, H * 0.8), "EVERY CITY IS TESTED", font(FONT_LIGHT, 38), (235, 238, 250, 255), 14))
    return over(img, lay, a)


def counters(img, t_bar):
    """the time-lapse: the year and the population"""
    b0, b1 = 17.0, 22.5
    if not (b0 <= t_bar < b1):
        return img
    u = (t_bar - b0) / (b1 - b0)
    year = int(2026 + 22 * u)
    pops = [0] + POPS + [POPS[-1]]
    x = u * (len(pops) - 1)
    i = min(len(pops) - 2, int(x))
    pop = int(pops[i] + (pops[i + 1] - pops[i]) * (x - i))
    a = min(smooth((t_bar - b0) / 0.3), smooth((b1 - t_bar) / 0.3))

    def d(dr):
        dr.text((W - 110, H - 250), str(year), font=font(FONT_BOLD, 92), fill=(255, 255, 255, 255), anchor="rs")
        spaced(dr, (W - 110, H - 205), f"POPULATION {pop:,}", font(FONT, 30), (255, 214, 120, 255), 5, anchor="rm")
    return over(img, text_layer(d), a)


POPS = []
try:
    for ln in open(os.path.join(CAP, "log.txt")):
        if ln.startswith("STAT pop"):
            POPS.append(int(ln.split()[2]))
    POPS = POPS[:4]
except OSError:
    POPS = [10000, 23000, 29000, 48000]


# ------------------------------------------------------------------ the logo: voxel type from the game's font
def load_game_font():
    import re
    glyphs = {}
    src = open(os.path.join(HERE, "..", "..", "src", "font.asm")).read()
    rows = re.findall(r'^G ((?:"[.#]{5}",?){8})', src, re.M)
    for i, r in enumerate(rows):
        glyphs[chr(33 + i)] = re.findall(r'"([.#]{5})"', r)
    return glyphs


GF = load_game_font()


def logo_cells(word):
    cols = []
    for ch in word:
        g = GF[ch]
        used = [c for c in range(5) if any(r[c] == "#" for r in g)]
        for c in range(min(used), max(used) + 1):
            cols.append([g[r][c] == "#" for r in range(7)])
        cols.append([False] * 7)
    return cols[:-1]


LOGO = logo_cells("CITYSSEMBLY")


def draw_logo(img, t_bar):
    """the logo rises out of the ground like the city: each pixel is an
    isometric voxel column that grows to full height"""
    t = t_bar - LOGO_BAR
    if t < -0.02:
        return img
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    s = 23                           # cube size
    cols = len(LOGO)
    x0 = W / 2 - cols * s / 2
    y0 = H * 0.40
    gold = (255, 210, 84)
    top, left, right = (255, 236, 150), (236, 170, 52), (178, 112, 30)
    cubes = []
    for ci, col in enumerate(LOGO):
        for ri, on in enumerate(col):
            if on:
                cubes.append((ci, ri))
    for ci, ri in sorted(cubes, key=lambda c: (c[1], c[0])):
        delay = ci / cols * 0.55 + (6 - ri) * 0.04
        p = ease_out((t - delay) / 0.35)
        if p <= 0:
            continue
        rise = (1 - p) * 120
        x = x0 + ci * s
        y = y0 + ri * s + rise
        dep = s * 0.45
        # extrusion toward bottom-right, like the game's buildings
        d.polygon([(x + s, y), (x + s + dep, y + dep * 0.5), (x + s + dep, y + s + dep * 0.5), (x + s, y + s)],
                  fill=right + (int(255 * min(1, p * 2)),))
        d.polygon([(x, y + s), (x + s, y + s), (x + s + dep, y + s + dep * 0.5), (x + dep, y + s + dep * 0.5)],
                  fill=left + (int(255 * min(1, p * 2)),))
        d.rectangle((x, y, x + s - 1, y + s - 1), fill=gold + (int(255 * min(1, p * 2)),))
        d.rectangle((x, y, x + s - 1, y + 4), fill=top + (int(255 * min(1, p * 2)),))
    img = over(img, lay)
    a1 = smooth((t - 0.9) / 0.3)
    a2 = smooth((t - 1.35) / 0.3)
    if a1 > 0:
        img = over(img, text_layer(lambda dr: spaced(dr, (W / 2, H * 0.62), "A CITY BUILDER WRITTEN IN PURE X86-64 ASSEMBLY",
                                                     font(FONT, 30), (250, 245, 235, 255), 8)), a1)
    if a2 > 0:
        def d2(dr):
            spaced(dr, (W / 2, H * 0.70), "PLAY FREE IN YOUR BROWSER", font(FONT_BOLD, 34), (255, 214, 110, 255), 9)
            spaced(dr, (W / 2, H * 0.76), "cityssembly.mixy.one", font(FONT, 32), (255, 255, 255, 255), 3)
            spaced(dr, (W / 2, H * 0.82), "WINDOWS  ·  LINUX  ·  WEB", font(FONT, 22), (190, 196, 210, 255), 8)
        img = over(img, text_layer(d2), a2)
    return img


# ------------------------------------------------------------------ the meteor
def fireball(img, t_bar, take, center, zoom):
    """a burning meteor streaks down onto the impact tile"""
    b0 = 30.0
    if not (b0 <= t_bar < IMPACT_BAR):
        return img
    u = (t_bar - b0) / (IMPACT_BAR - b0)
    ipx = tile_px("meteor", 78, 60)
    # impact point on screen
    sx = (ipx[0] - center[0]) * zoom + W / 2
    sy = (ipx[1] - center[1]) * zoom + H / 2
    # comes in from the upper right
    e = u ** 2.2
    hx = sx + (1 - e) * 1400
    hy = sy - (1 - e) * 1500
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for k in range(26):
        q = k / 26
        px = hx + q * 300 * (1.2 - e * 0.4)
        py = hy - q * 320 * (1.2 - e * 0.4)
        r = 26 * (1 - q) + 4
        col = (255, int(230 - 160 * q), int(120 - 110 * q), int(230 * (1 - q) ** 1.2))
        d.ellipse((px - r, py - r, px + r, py + r), fill=col)
    d.ellipse((hx - 16, hy - 16, hx + 16, hy + 16), fill=(255, 255, 235, 255))
    lay = lay.filter(ImageFilter.GaussianBlur(2))
    img = over(img, lay)
    # the city lights up under it
    glow = np.zeros((H, W, 1), np.float32)
    return img + glow


# ------------------------------------------------------------------ one frame
def render(f, reader):
    if f < PRE * BAR_FRAMES:
        return render_cold_open(f, reader)
    f -= PRE * BAR_FRAMES
    t_bar = f / BAR_FRAMES + 1
    take, local, length, entry = edit_at(f)
    img = np.zeros((H, W, 3), np.float32)
    act = act_of(t_bar)
    center, zoom = (CW / 2, CH / 2), 1.0
    if take:
        sf, center, zoom = source_and_cam(take, local, length)
        src = reader.get(take, sf)
        if src is not None:
            img = camera_view(src, center, zoom)
            img = grade(img, act)
            night = take in ("night", "fire", "fire_wide", "meteor", "stadium")
            img = bloom(img, 0.55 if night else (0.35 if act == 5 else 0.18))
            if zoom >= 2.3 and not take.startswith("view"):
                img = tilt_shift(img, clamp((zoom - 2.2) / 1.2) * 0.85)
    # ---- overlays by act
    if take == "meteor":
        img = fireball(img, t_bar, take, center, zoom)
    if act == 1:
        img = caption_intro(img, t_bar)
    if entry and entry[3] and act == 2:
        img = caption_location(img, t_bar, entry[3], entry[0])
    if entry and entry[3] and take and take.startswith("view"):
        img = caption_small(img, t_bar, entry[3], entry[0], entry[1])
    img = counters(img, t_bar)
    if act == 4:
        img = caption_tested(img, t_bar)
    # ---- fades, flashes, bars
    if t_bar < 1.6:
        img *= smooth((t_bar - 1.0) / 0.6)
    if 8.85 <= t_bar < 9.0:
        img *= 1 - smooth((t_bar - 8.85) / 0.1)
    if 24.5 <= t_bar < 25.0:
        img[:] = 0
    if 25.0 <= t_bar < 25.3:
        img *= smooth((t_bar - 25.0) / 0.3)
    if IMPACT_BAR <= t_bar < 32.0:
        k = t_bar - IMPACT_BAR
        if k < 0.25:
            img = img * 0 + (1 - k / 0.25) + img * (k / 0.25)
        else:
            img *= max(0.0, 1 - (k - 0.25) / 0.35)
    if t_bar >= LOGO_BAR:
        k = smooth((t_bar - LOGO_BAR) / 0.8)
        sm = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((W // 8, H // 8), Image.BILINEAR)
        sm = np.asarray(sm.filter(ImageFilter.GaussianBlur(1.5)).resize((W, H), Image.BILINEAR), np.float32) / 255
        img = img * (1 - k) + sm * k * 0.45
        img = draw_logo(img, t_bar)
    if t_bar > STORY_BARS + 1 - 0.8:
        img *= smooth((STORY_BARS + 1 - t_bar) / 0.8)
    # letterbox for acts I-IV; it opens on the finale
    lb = 0.0
    if t_bar < 32:
        lb = 1.0
    elif t_bar < 33:
        lb = 1 - ease_in_out(t_bar - 32)
    if lb > 0:
        hbar = int(round(H * (1 - 1920 / 2.35 / H) / 2 * lb))
        img[:hbar] = 0
        img[H - hbar:] = 0
    img = grain(img, f)
    return (np.clip(img, 0, 1) * 255).astype(np.uint8)


# ------------------------------------------------------------------ the cold open
COLD = [("gold_b", 0, 80, (1, 2), (0, 0), 2.2, 2.5, 5),
        ("night", 80, 160, (-2, 1), (0, 0), 1.9, 2.15, 4)]


def render_cold_open(f, reader):
    """two bars before the story: the city at its best, no fade in, so the
    first frame (the thumbnail) is already the picture"""
    for take, a, b, p0, p1, z0, z1, act in COLD:
        if a <= f < b:
            u = (f - a) / (b - a)
            e = smooth(u)
            c0, c1 = off(take, *p0), off(take, *p1)
            center = (c0[0] + (c1[0] - c0[0]) * e, c0[1] + (c1[1] - c0[1]) * e)
            zoom = z0 + (z1 - z0) * e
            src = reader.get(take, 10 + (f - a))
            img = camera_view(src, center, zoom)
            img = grade(img, act)
            img = bloom(img, 0.55 if take == "night" else 0.35)
            img = tilt_shift(img, 0.6)
            if f >= b - 6 and take == "night":
                img *= (b - f) / 6
            return (np.clip(grain(img, f), 0, 1) * 255).astype(np.uint8)
    return np.zeros((H, W, 3), np.uint8)


# ------------------------------------------------------------------ workers
def seg_done(out, frames):
    """a finished segment from an earlier (interrupted) run"""
    if not os.path.exists(out) or os.path.getsize(out) == 0:
        return False
    r = subprocess.run(["ffprobe", "-v", "error", "-count_packets", "-select_streams", "v:0",
                        "-show_entries", "stream=nb_read_packets", "-of", "csv=p=0", out],
                       capture_output=True, text=True)
    return r.stdout.strip() == str(frames)


def worker(job):
    a, b, out = job
    if seg_done(out, b - a):
        return out
    reader = Reader()
    enc = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                            "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-threads", "4", "-preset", "slow",
                            "-crf", "14", "-pix_fmt", "yuv420p", out], stdin=subprocess.PIPE)
    for f in range(a, b):
        enc.stdin.write(render(f, reader).tobytes())
    enc.stdin.close()
    enc.wait()
    # close the decoder too: pool workers are reused, and every job's
    # leftover decoder (~800 MB each) used to pile up
    if reader.proc:
        reader.proc.kill()
        reader.proc.wait()
    return out


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--still":
        os.makedirs(os.path.join(HERE, "stills"), exist_ok=True)
        r = Reader()
        for x in sys.argv[2:]:
            f = int((float(x) - 1 + PRE) * BAR_FRAMES)       # story bars; negative = cold open
            Image.fromarray(render(f, r)).save(os.path.join(HERE, "stills", f"b{float(x):05.2f}.png"))
        return
    # one render at a time: overlapping runs (a render left going in the
    # background, then started again) ran the machine out of memory
    import fcntl
    lock = open(os.path.join(HERE, ".render.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit("another render is already running (trailer_work/v3/.render.lock)")
    seg = os.path.join(HERE, "seg")
    os.makedirs(seg, exist_ok=True)     # kept: finished segments are reused
    # cut at shot boundaries so readers stream sequentially
    cuts = sorted({0, BAR_FRAMES, PRE * BAR_FRAMES, TOTAL} |
                  {int((e[0] - 1 + PRE) * BAR_FRAMES) for e in EDIT})
    jobs = []
    for a, b in zip(cuts, cuts[1:]):
        step = 40
        for s in range(a, b, step):
            jobs.append((s, min(b, s + step), os.path.join(seg, f"{s:05d}.mp4")))
    # each worker holds full frames plus a decoder and an encoder (~2 GB):
    # keep the pool small or the machine runs out of memory
    with Pool(int(os.environ.get("TRAILER_JOBS", "4")), maxtasksperchild=1) as p:
        outs = p.map(worker, jobs, chunksize=1)
    with open(os.path.join(seg, "list.txt"), "w") as fl:
        for o in outs:
            fl.write(f"file '{o}'\n")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i",
                    os.path.join(seg, "list.txt"), "-i", os.path.join(HERE, "score.wav"),
                    "-c:v", "copy", "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart",
                    os.path.join(HERE, "trailer_v3.mp4")], check=True)
    print("trailer_v3.mp4")


if __name__ == "__main__":
    main()
