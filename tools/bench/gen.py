"""Write test-city scripts for the --play player (seed-1234567 map).

    python3 tools/bench/gen.py        -> tools/bench/{mid,big}city.play
    cityssembly --play tools/bench/midcity.play --beta   (writes midcity.sav)

The cities are built with the game's own tools (grid roads, zone areas,
services placed like a player would), then grown for a few years, with a
report line every half year.  Use them for traffic and balance work.
"""
import os

KEYS = {'R': 1, 'C': 2, 'I': 3, 'O': 4, 'RH': 5, 'CH': 6}


def city(name, grids, avenues, zones, nuclear, pumps, towers, outlets,
         landfills, cells, big_cells, unis, parks, extras, stops, years,
         plines=()):
    L = [f"# {name}: written by tools/bench/gen.py", "new 1234567", "rich",
         "key r", "key g", "key g", "key g", "roadtype 0"]
    a = L.append
    for g in grids:
        a("apply %d %d %d %d" % g)
    a("key g")
    a("roadtype 1")
    for (x0, y0, x1, y1) in avenues:
        a(f"apply {x0} {y0} {x1} {y1}")
    a("roadtype 0")
    for (z, x0, y0, x1, y1) in zones:
        a(f"key {KEYS[z]}")
        a(f"apply {x0} {y0} {x1} {y1}")

    def put(kind, pts):
        for (x, y) in pts:
            a(f"select {kind}")
            a(f"apply {x} {y} {x} {y}")
    put(3, nuclear)
    for (x0, y0, x1, y1) in plines:      # power lines out to the lots
        a("select 120")
        a(f"apply {x0} {y0} {x1} {y1}")
    put(4, pumps)
    put(5, towers)
    put(6, outlets)
    put(7, landfills)
    for (cx, cy) in cells:              # police, fire, clinic, elementary
        for (k, dx, dy) in [(9, -2, -2), (10, 2, -2), (11, -2, 2), (13, 2, 2)]:
            put(k, [(cx + dx, cy + dy)])
    for (cx, cy) in big_cells:          # hospital, high school
        put(12, [(cx, cy)])
        put(14, [(cx + 4, cy)])
    put(15, unis)
    put(17, parks)
    for (k, x, y) in extras:
        put(k, [(x, y)])
    if stops:
        put(16, stops[:1])
        a("select 103")
        for (x, y) in stops[1:]:
            a(f"apply {x} {y} {x} {y}")
    a("key q")
    a("report")
    for _ in range(years * 2):
        a("days 180")
        a("report")
    a(f"save {name}.sav")
    a("quit")
    open(os.path.join(os.path.dirname(__file__) or '.', name + '.play'), 'w').write("\n".join(L) + "\n")


# ~15-20k: the west bank around the regional highway, a street grid with
# one avenue each way
city('midcity',
     grids=[(8, 36, 43, 92)],
     avenues=[(22, 36, 22, 92), (8, 64, 43, 64)],
     zones=[('RH', 8, 36, 22, 64), ('RH', 22, 36, 43, 50), ('R', 22, 50, 43, 64),
            ('C', 8, 64, 22, 71), ('CH', 22, 64, 43, 71), ('O', 8, 71, 43, 78),
            ('I', 8, 78, 43, 92)],
     nuclear=[(12, 100)],
     plines=[(13, 97, 13, 38), (8, 40, 45, 40), (8, 54, 45, 54), (8, 75, 45, 75),
             (8, 88, 45, 88), (45, 38, 45, 100)],
     pumps=[(46, y) for y in range(38, 94, 8)],
     towers=[(15, 45), (36, 45), (15, 75), (36, 85)],
     outlets=[(46, 100), (46, 104), (46, 108)],
     landfills=[(30, 98)],
     cells=[(15, 43), (36, 43), (15, 67), (36, 67), (25, 85)],
     big_cells=[(25, 55)],
     unis=[],
     parks=[(x, y) for x in range(12, 44, 10) for y in range(40, 92, 12)],
     extras=[(20, 32, 60)],
     stops=[(12, 60), (8, 64), (15, 64), (29, 64), (36, 64), (22, 44), (22, 58), (22, 72), (22, 86)],
     years=2)

# ~55k: the whole map in a street grid with avenues every 28 tiles
city('bigcity',
     grids=[(8, 12, 64, 68), (64, 12, 120, 68), (8, 68, 64, 124), (64, 68, 120, 124)],
     avenues=[(x, 12, x, 124) for x in (36, 64, 92)] + [(8, y, 120, y) for y in (40, 68, 96)],
     zones=[('R', 8, 12, 36, 96), ('RH', 36, 12, 47, 68), ('C', 36, 68, 47, 96),
            ('I', 8, 96, 47, 124), ('O', 51, 40, 64, 68), ('CH', 64, 40, 87, 68),
            ('RH', 51, 12, 87, 40), ('CH', 51, 68, 87, 96), ('I', 51, 110, 87, 124),
            ('R', 51, 96, 87, 110), ('RH', 100, 68, 124, 124), ('R', 100, 12, 124, 68)],
     nuclear=[(12, 118), (118, 118), (118, 14), (58, 14), (30, 14), (80, 118)],
     plines=[(45, 14, 45, 124)] + [(10, y, 120, y) for y in (26, 54, 82, 110)],
     pumps=[(46, y) for y in range(18, 124, 6)],
     towers=[(x, y) for x in (20, 40, 58, 78, 108) for y in (20, 40, 60, 80, 100, 118)],
     outlets=[(96, 24), (96, 34), (96, 44), (94, 54), (86, 74), (86, 84), (86, 94),
              (86, 104), (86, 114), (86, 122), (96, 30), (96, 40), (86, 80), (86, 90),
              (86, 100), (86, 110)],
     landfills=[(22, 100), (60, 116), (110, 100), (24, 30), (76, 24), (110, 40)],
     cells=[(cx, cy) for cx in (18, 39, 60, 81, 110) for cy in (22, 43, 64, 85, 106)],
     big_cells=[(cx, cy) for cx in (25, 60, 110) for cy in (30, 64, 100)],
     unis=[(30, 50), (72, 86)],
     parks=[(x, y) for x in range(12, 120, 14) for y in range(16, 124, 14)],
     extras=[(19, 74, 58), (20, 57, 60), (21, 72, 48)],
     stops=[(62, 72)] + [(x, y) for x in range(10, 120, 10) for y in (40, 68)],
     years=4)
print("wrote midcity.play, bigcity.play")
