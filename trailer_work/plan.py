"""Writer for the in-engine trailer director (src/trailer.asm).

A plan is a little bytecode program: build the world, then film it.
    p = Plan()
    p.load("city.sav"); p.cam(40, 64); p.tod(120); p.film(30, 2)
    p.save("plan.bin")
Run it with   cityssembly --trailer out.raw plan.bin W H
"""
import struct
import subprocess

import numpy as np

OPS = ["end", "terrain", "road", "zone", "place", "pline", "stop", "nets", "ff", "mark",
       "cam", "zoom", "vel", "tod", "season", "film", "roadanim", "follow", "overlay", "meteor",
       "fire", "speed", "year", "confetti", "trees", "clear", "load", "light", "money", "lock", "save", "drag"]
OP = {n: i for i, n in enumerate(OPS)}

# game constants
RT_STREET, RT_AVENUE, RT_HIGHWAY = 0, 1, 2
ZONE_R, ZONE_C, ZONE_I, ZONE_O, ZONE_RH, ZONE_CH = 1, 2, 3, 4, 5, 6
BK = {n: i for i, n in enumerate(
    ["COAL", "WIND", "SOLAR", "NUCLEAR", "PUMP", "WTOWER", "SEWAGE", "LANDFILL", "INCIN", "POLICE",
     "FIRE", "CLINIC", "HOSPITAL", "ELEM", "HIGH", "UNIV", "BUSDEPOT", "PARK", "PLAZA", "STADIUM",
     "CITYHALL", "LANDMARK"])}
OV_POWER, OV_WATER, OV_TRAFFIC, OV_LANDVAL = 1, 2, 7, 6
T_BULLDOZE, T_ROAD, T_ZONETOOL, T_DEZONE = 1, 2, 4, 7
TER_GRASS, TER_WATER, TER_SAND, TER_DIRT = 0, 1, 2, 3


class Plan:
    def __init__(self):
        self.b = bytearray()
        self.shots = []          # names by id

    def op(self, name, *args):
        self.b.append(OP[name])
        for a in args:
            self.b += struct.pack("<h", int(a))
        return self

    def __getattr__(self, name):
        if name in OP:
            return lambda *a: self.op(name, *a)
        raise AttributeError(name)

    def terrain(self, grid):
        """grid: uint8 [128,128] indexed [y, x] (bits: terrain, tree, kind, resource)"""
        self.b.append(OP["terrain"])
        self.b += np.ascontiguousarray(grid, np.uint8).tobytes()
        return self

    def load(self, path):
        self.b.append(OP["load"])
        self.b += path.encode() + b"\0"
        return self

    def savefile(self, path):
        self.b.append(OP["save"])
        self.b += path.encode() + b"\0"
        return self

    def mark(self, name):
        self.shots.append(name)
        return self.op("mark", len(self.shots) - 1)

    def road(self, x0, y0, x1, y1, rt=RT_STREET, hwy=0):
        return self.op("road", x0, y0, x1, y1, rt, hwy)

    def save(self, path):
        self.b.append(OP["end"])
        open(path, "wb").write(bytes(self.b))


def run(plan_path, raw_path, w, h, cwd=None, log=None):
    """run the director; returns stdout lines"""
    exe = "/home/mixy/projects/cityssembly/cityssembly"
    env = {"SDL_AUDIODRIVER": "dummy", "SDL_VIDEODRIVER": "dummy", "PATH": "/usr/bin:/bin"}
    r = subprocess.run([exe, "--trailer", raw_path, plan_path, str(w), str(h)],
                       cwd=cwd, env=env, capture_output=True, text=True)
    if log:
        open(log, "w").write(r.stdout)
    return r.stdout.splitlines()


def frames(raw_path, w, h):
    """iterate raw BGRA frames as RGB uint8 arrays"""
    size = w * h * 4
    with open(raw_path, "rb") as f:
        while True:
            buf = f.read(size)
            if len(buf) < size:
                return
            a = np.frombuffer(buf, np.uint8).reshape(h, w, 4)
            yield a[..., [2, 1, 0]]
