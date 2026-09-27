"""The trailer's city: a bay town with a river, grown in eras so each
neighbourhood gets its own architecture (Old Town first, Modern last).

build(p) appends the whole city to a Plan; stages can be filmed between.
"""
import math

import numpy as np

from plan import *

N = 128
rng = np.random.default_rng(42)


# ------------------------------------------------------------------ terrain
def river_y(x):
    return 36 + 4.0 * math.sin(x / 11.0) + 2.0 * math.sin(x / 5.3)


def coast_x(y):
    """the ocean starts east of this"""
    c = 106 + 3 * math.sin(y / 9.0) + 2 * math.sin(y / 3.7)
    # a bay the old town wraps around
    c -= 9 * math.exp(-((y - 50) / 7.0) ** 2)
    return c


def noise2(seed, scale):
    r = np.random.default_rng(seed)
    g = r.random((N // scale + 3, N // scale + 3))
    ys, xs = np.mgrid[0:N, 0:N] / scale
    x0, y0 = xs.astype(int), ys.astype(int)
    fx, fy = xs - x0, ys - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
    b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def terrain():
    t = np.zeros((N, N), np.uint8)          # [y, x]
    water = np.zeros((N, N), bool)
    for y in range(N):
        cx = coast_x(y)
        for x in range(N):
            if x >= cx:
                water[y, x] = True
    for x in range(N):
        ry = river_y(x)
        for y in range(int(ry - 1.4), int(ry + 1.6) + 1):
            if 0 <= y < N:
                water[y, x] = True
    # a lake in the south-west hills
    ys, xs = np.mgrid[0:N, 0:N]
    water |= ((xs - 18) / 7.0) ** 2 + ((ys - 104) / 5.0) ** 2 < 1
    t[water] = TER_WATER
    # beaches on the ocean
    for y in range(N):
        cx = coast_x(y)
        for x in range(int(cx) - 2, int(cx)):
            if 0 <= x < N and not water[y, x]:
                t[y, x] = TER_SAND
    # forests: dense in the west and south hills, scattered elsewhere
    f = noise2(3, 9) * 0.7 + noise2(5, 4) * 0.3
    forest = f > 0.52
    wild = (xs < 30) | (ys > 100) | (ys < 14)
    trees = (~water) & (t != TER_SAND) & ((forest & wild & (rng.random((N, N)) < 0.8)) |
                                          (wild & (rng.random((N, N)) < 0.12)) |
                                          (rng.random((N, N)) < 0.02))
    kinds = rng.integers(0, 4, (N, N)).astype(np.uint8)
    t = t | (trees.astype(np.uint8) << 2) | (kinds << 3)
    # resources for industry: forest in the west, fertile farmland north
    res = np.zeros((N, N), np.uint8)
    res[(xs < 34) & (ys < 30)] = 1
    res[forest] = 2
    t |= res << 5
    return t, water


T, WATER = terrain()


def is_water(x, y):
    return 0 <= x < N and 0 <= y < N and WATER[y, x]


# ------------------------------------------------------------------ helpers
def hroad(p, y, x0, x1, rt=RT_STREET, bridges=False):
    """road along x at row y, split around water unless bridging"""
    seg = None
    for x in range(x0, x1 + 1):
        ok = bridges or not is_water(x, y)
        if ok and seg is None:
            seg = x
        if (not ok or x == x1) and seg is not None:
            end = x if ok else x - 1
            if end > seg:
                p.road(seg, y, end, y, rt)
            seg = None


def vroad(p, x, y0, y1, rt=RT_STREET, bridges=False):
    seg = None
    for y in range(y0, y1 + 1):
        ok = bridges or not is_water(x, y)
        if ok and seg is None:
            seg = y
        if (not ok or y == y1) and seg is not None:
            end = y if ok else y - 1
            if end > seg:
                p.road(x, seg, x, end, rt)
            seg = None


def zone(p, x0, y0, x1, y1, z):
    p.zone(x0, y0, x1, y1, z)


# ------------------------------------------------------------------ districts
# (name, x0, y0, x1, y1): shot targets for the director
DISTRICTS = {}


def grid(p, x0, y0, x1, y1, bx=4, by=4, rt=RT_STREET):
    for y in range(y0, y1 + 1, by):
        hroad(p, y, x0, x1, rt)
    for x in range(x0, x1 + 1, bx):
        vroad(p, x, y0, y1, rt)


def utilities(p):
    # power: nuclear plant in the south-west, wind on the northern hills
    p.place(BK["NUCLEAR"], 30, 104)
    p.place(BK["NUCLEAR"], 33, 105)
    p.place(BK["NUCLEAR"], 27, 104)
    # pumps on the river bank by the north highway bridge
    for x in range(51, 57):
        p.place(BK["PUMP"], x, 29)
    for i in range(6):
        p.place(BK["WIND"], 40 + i * 3, 10)
    # water towers and sewage by the sea south of the city
    # water towers between the avenue's pipes (row 64) and the power trunk
    for i in range(16):
        p.place(BK["WTOWER"], 34 + i, 65)
    for i in range(12):
        p.place(BK["WTOWER"], 57 + i, 65)
    for i in range(14):
        p.place(BK["WTOWER"], 71 + i, 65)
    # sewage outlets on the beach south of town, along a coastal street
    prev = None
    for y in range(104, 123):
        cx = int(coast_x(y))
        while is_water(cx - 1, y):
            cx -= 1
        rx = cx - 2
        if prev is not None and prev != rx:
            p.road(min(prev, rx), y - 1, max(prev, rx), y - 1, RT_STREET)
        p.road(rx, y, rx, y, RT_STREET)
        prev = rx
        p.place(BK["SEWAGE"], cx - 1, y)
    # garbage: incinerators by the power trunk and a landfill in the woods
    p.place(BK["INCIN"], 28, 66)
    p.place(BK["INCIN"], 28, 69)
    p.place(BK["INCIN"], 52, 66)
    p.place(BK["INCIN"], 44, 31)
    p.place(BK["INCIN"], 46, 31)
    p.place(BK["INCIN"], 64, 104)
    p.place(BK["LANDFILL"], 27, 100)

def build_roads(p):
    # regional highways: west (row 64) and north (column 50), a ring avenue
    p.road(0, 64, 26, 64, RT_HIGHWAY, 1)
    p.road(50, 0, 50, 16, RT_HIGHWAY, 1)
    vroad(p, 50, 16, 100, RT_HIGHWAY, bridges=True)
    hroad(p, 64, 26, 100, RT_AVENUE, bridges=True)
    # service roads to the utilities
    vroad(p, 26, 60, 110, RT_STREET)
    hroad(p, 110, 26, int(coast_x(110)) - 1, RT_STREET)
    hroad(p, 12, 36, 50, RT_STREET)


def stage_old_town(p, part):
    """the first streets, by the bay and the river mouth"""
    x0, y0, x1, y1 = 74, 40, 100, 62
    if part == 'roads':
        grid(p, x0, y0, x1, y1, 4, 4)
        for x in (82, 90):
            vroad(p, x, 30, 64, RT_AVENUE, bridges=True)
        hroad(p, 52, 50, 100, RT_AVENUE)
        grid(p, 64, 28, 80, 34, 4, 3)
        return
    zone(p, x0, y0, x1, y1, ZONE_RH)
    zone(p, 84, 44, 95, 55, ZONE_CH)
    zone(p, x0, 56, 84, y1, ZONE_R)
    zone(p, 66, 30, 80, 34, ZONE_I)          # the old docks industry
    p.place(BK["CITYHALL"], 87, 46)
    p.place(BK["FIRE"], 75, 45)
    p.place(BK["POLICE"], 95, 57)
    p.place(BK["CLINIC"], 79, 57)
    p.place(BK["ELEM"], 83, 41)
    p.place(BK["PARK"], 91, 60)
    p.place(BK["PARK"], 78, 52)
    DISTRICTS["old_town"] = (x0, y0, x1, y1)

def stage_shore(p, part):
    """beach houses along the ocean"""
    x0, y0, x1, y1 = 86, 66, 102, 98
    if part == 'roads':
        for y in range(y0, y1 + 1, 4):
            hroad(p, y, x0, int(coast_x(y)) - 3)
        vroad(p, 86, 64, 100)
        vroad(p, 94, 64, 100)
        vroad(p, 86, 100, 104)
        return
    zone(p, x0, y0, x1, y1, ZONE_R)
    zone(p, 86, 66, 93, 72, ZONE_CH)
    zone(p, 86, 74, 93, 98, ZONE_C)       # beach shops inland, houses by the sand
    p.place(BK["PARK"], 98, 70)
    p.place(BK["FIRE"], 87, 80)
    p.place(BK["CLINIC"], 95, 83)
    p.place(BK["CLINIC"], 95, 93)
    p.place(BK["ELEM"], 99, 87)
    p.place(BK["POLICE"], 91, 87)
    p.place(BK["PARK"], 99, 77)
    DISTRICTS["shore"] = (x0, y0, x1, y1)

def stage_uptown(p, part):
    """towers around a central park"""
    x0, y0, x1, y1 = 56, 66, 84, 88
    if part == 'roads':
        grid(p, x0, y0, x1, y1, 4, 4)
        vroad(p, 70, 64, 90, RT_AVENUE)
        p.clear(61, 73, 68, 83)
        for (px, py) in ((61, 73), (61, 75), (61, 77), (61, 79), (61, 81), (63, 73), (65, 73),
                         (67, 73), (63, 81), (65, 81), (67, 81), (67, 75), (67, 77), (67, 79)):
            p.place(BK["PARK"], px, py)
        return
    zone(p, x0, y0, x1, y1, ZONE_RH)
    zone(p, 71, 66, 83, 72, ZONE_CH)
    # central park
    p.place(BK["PLAZA"], 63, 75)
    p.place(BK["PLAZA"], 65, 78)
    p.trees(63, 77, 64, 80, 70)
    p.place(BK["HOSPITAL"], 75, 81)
    p.place(BK["HIGH"], 57, 85)
    DISTRICTS["uptown"] = (x0, y0, x1, y1)

def stage_garden(p, part):
    """leafy houses by the southern woods"""
    x0, y0, x1, y1 = 30, 70, 54, 96
    if part == 'roads':
        grid(p, x0, y0, x1, y1, 6, 4)
        return
    zone(p, x0, y0, x1, y1, ZONE_R)
    zone(p, x0, 70, x1, 74, ZONE_C)       # a high street
    p.trees(30, 70, 54, 96, 12)
    p.place(BK["ELEM"], 43, 79)
    p.place(BK["HOSPITAL"], 49, 91)
    p.place(BK["CLINIC"], 37, 77)
    p.place(BK["POLICE"], 31, 91)
    p.place(BK["PARK"], 37, 87)
    p.place(BK["PARK"], 49, 75)
    DISTRICTS["garden"] = (x0, y0, x1, y1)

def stage_industry(p, part):
    """factories north of the river, workers' housing beside them"""
    x0, y0, x1, y1 = 28, 18, 48, 30
    if part == 'roads':
        grid(p, x0, y0, x1, y1, 5, 4)
        grid(p, 28, 42, 48, 60, 4, 3)
        vroad(p, 38, 30, 42, RT_STREET, bridges=True)
        grid(p, 38, 99, 62, 109, 6, 5)       # the southern industrial park
        return
    zone(p, x0, y0, x1, y1, ZONE_I)
    zone(p, 28, 42, 48, 60, ZONE_R)
    zone(p, 40, 42, 48, 50, ZONE_RH)
    zone(p, 28, 57, 48, 60, ZONE_C)
    zone(p, 38, 99, 62, 109, ZONE_I)
    p.place(BK["LANDFILL"], 30, 34)
    p.place(BK["BUSDEPOT"], 44, 52)
    p.place(BK["CLINIC"], 30, 46)
    DISTRICTS["industry"] = (x0, y0, x1, y1)
    DISTRICTS["workers"] = (28, 42, 48, 60)

def stage_modern(p, part):
    """the new business district between old town and uptown"""
    x0, y0, x1, y1 = 54, 42, 72, 62
    if part == 'roads':
        grid(p, x0, y0, x1, y1, 4, 4)
        return
    zone(p, x0, y0, x1, y1, ZONE_O)
    zone(p, x0, 58, x1, y1, ZONE_RH)
    zone(p, 54, 42, 60, 50, ZONE_CH)
    p.place(BK["LANDMARK"], 63, 51)
    p.place(BK["UNIV"], 55, 51)
    p.place(BK["POLICE"], 67, 55)
    p.place(BK["STADIUM"], 56, 90)
    DISTRICTS["modern"] = (x0, y0, x1, y1)

def stage_north(p, part):
    """brownstone Brooklyn across the river"""
    x0, y0, x1, y1 = 56, 14, 98, 30
    if part == 'roads':
        grid(p, x0, y0, x1, y1, 4, 4)
        return
    zone(p, x0, y0, x1, y1, ZONE_R)
    zone(p, 76, 14, 90, 20, ZONE_RH)
    zone(p, 56, 22, 98, 30, ZONE_O)
    zone(p, 56, 26, 98, 30, ZONE_C)
    p.place(BK["ELEM"], 69, 21)
    p.place(BK["CLINIC"], 62, 23)
    p.place(BK["HOSPITAL"], 74, 23)
    p.place(BK["FIRE"], 85, 17)
    p.place(BK["PARK"], 61, 17)
    DISTRICTS["north"] = (x0, y0, x1, y1)

def stops(p):
    for (x, y) in ((70, 64), (82, 50), (90, 60), (50, 70), (50, 40), (62, 64), (86, 76)):
        p.stop(x, y)


STAGES = [stage_old_town, stage_north, stage_industry, stage_shore,
          stage_garden, stage_uptown, stage_modern]


def connectors(p):
    """connect every district to the network"""
    for y in (18, 22, 26, 30, 42, 45, 48, 51, 54, 57, 60):
        hroad(p, y, 48, 50)                 # industry, workers -> north highway
    hroad(p, 31, 80, 82)                    # docks -> old town avenue
    vroad(p, 54, 62, 64)                    # modern -> ring avenue
    vroad(p, 74, 62, 64)                    # old town -> ring avenue
    vroad(p, 98, 62, 64)


def power_lines(p):
    """after all streets exist. The power line tool only joins lines at
    drag end points, so the network is drawn as chains between known
    pylons: a trunk along the free corridor at row 63, branches into the
    middle of each district's blocks."""
    def chain(*pts):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            p.pline(x0, y0, x1, y1)
    # plant -> trunk, with the garden rows branching off
    chain((33, 102), (33, 88), (33, 76), (33, 63))
    chain((33, 76), (53, 76))
    chain((33, 102), (61, 102))
    chain((33, 88), (53, 88))
    # the corridor trunk
    chain((29, 63), (33, 63), (41, 63), (57, 63), (73, 63), (85, 63), (101, 63))
    # workers
    chain((29, 63), (29, 44), (47, 44))
    # industry, the wind farm and the north bank
    chain((41, 63), (41, 44), (41, 13), (43, 10))
    chain((41, 13), (57, 13), (97, 13))
    chain((57, 13), (57, 20), (57, 29))
    chain((57, 20), (97, 20))
    # modern, old town, the docks
    chain((73, 63), (73, 58), (73, 46), (73, 42), (73, 28))
    chain((73, 46), (99, 46))
    chain((73, 58), (99, 58))
    # uptown
    chain((57, 63), (57, 68), (57, 84), (57, 87))
    chain((57, 68), (85, 68))
    chain((57, 84), (85, 84))
    # shore
    chain((85, 63), (85, 68), (85, 80), (85, 97))
    chain((85, 68), (99, 68))
    chain((85, 80), (99, 80))


def build(p, film=None):
    """film(stage_name) is called between eras to shoot growth"""
    p.terrain(T)
    p.money()
    p.year(2026)
    build_roads(p)
    for st in STAGES:
        st(p, 'roads')
    connectors(p)
    utilities(p)
    power_lines(p)
    stops(p)
    p.nets()
    eras = [(2026, [stage_old_town]),
            (2031, [stage_north, stage_industry, stage_shore]),
            (2036, [stage_garden, stage_uptown]),
            (2046, [stage_modern])]
    for year, stages in eras:
        p.year(year)
        for st in stages:
            st(p, 'zones')
        p.nets()
        if film:
            film(stages[0].__name__)
        p.ff(2400, 3)
    p.ff(2400, 3)
    p.speed(1)
