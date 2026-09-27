"""Film every take of trailer v3 with the in-engine director.

python3 shoot.py [take ...]      (no args: everything)
Writes cap/<take>.raw (2560x1440 BGRA, world pixels 1:1), then encodes
each to cap/<take>.mkv (lossless) and writes cap/takes.json with frame
counts, the capture camera and events (road tiles, followed car).
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
from plan import *            # noqa
import city                   # noqa
from timeline import EDIT, BAR_FRAMES   # noqa

W, H = 2560, 1440
CAP = os.path.join(HERE, "cap")
os.makedirs(CAP, exist_ok=True)


def length(take, extra=24):
    for b0, b1, t, _ in EDIT:
        if t == take:
            return int((b1 - b0) * BAR_FRAMES) + extra
    raise KeyError(take)


takes = {}          # name -> dict(cam=(x, y), frames=n)


def take(p, name, cx, cy, frames, ticks, tod=None, todspeed=0, zoom=1):
    p.outfile(f"cap/{name}.raw")
    p.mark(name)
    p.zoom(zoom)
    p.cam(cx, cy, 0, 0)
    if tod is not None:
        p.tod(tod, todspeed)
    p.film(frames, ticks)
    takes[name] = dict(cam=(cx, cy), frames=frames)


def eras_zones():
    return [(2026, [city.stage_old_town]),
            (2031, [city.stage_north, city.stage_industry, city.stage_shore]),
            (2036, [city.stage_garden, city.stage_uptown]),
            (2046, [city.stage_modern])]


def build_plan():
    p = Plan()
    p.lforce(1)
    p.terrain(city.T)
    p.money()
    p.year(2026)
    p.seasonspeed(0)
    p.season(300)                           # high summer
    # ---- I. the empty valley at dawn
    take(p, "valley", 34, 32, length("valley", 40), 2, tod=76, todspeed=4)
    # ---- the first road: the highway is there, the avenue draws itself
    p.road(0, 64, 26, 64, RT_HIGHWAY, 1)
    p.road(50, 0, 50, 16, RT_HIGHWAY, 1)
    p.nets()
    p.outfile("cap/road.raw")
    p.mark("road")
    p.zoom(1)
    p.cam(40, 64, 0, 0)
    p.tod(84, 1)
    p.film(12, 2)
    # a tile every eighth note (10 frames): 25.6/256 tiles a frame
    p.roadanim(27, 64, 62, 64, RT_AVENUE, 26, 2)
    p.film(24, 2)
    takes["road"] = dict(cam=(40, 64), frames=None)
    # ---- the rest of the plan, era 1 zoned
    city.build_roads(p)
    for st in city.STAGES:
        st(p, 'roads')
    city.connectors(p)
    city.utilities(p)
    city.power_lines(p)
    city.stops(p)
    p.nets()
    city.stage_old_town(p, 'zones')
    p.nets()
    p.savefile("cap/era1.sav")
    # ---- III. the time-lapse, all eras from one camera
    p.speed(3)
    p.outfile("cap/timelapse.raw")
    p.mark("timelapse")
    p.zoom(1)
    p.cam(66, 60, 0, 0)
    p.tod(90, 0)
    p.todspeed2(44)
    p.seasonspeed(6)
    per = 96
    first = True
    for year, stages in eras_zones():
        if not first:
            p.year(year)
            for st in stages:
                st(p, 'zones')
            p.nets()
        first = False
        p.film(per, 26)
        p.stat()
    p.film(per, 26)
    takes["timelapse"] = dict(cam=(66, 60), frames=per * 5)
    p.todspeed2(0)
    p.seasonspeed(0)
    p.season(300)
    p.speed(1)
    p.ff(600, 1)
    p.savefile("cap/full.sav")
    # ---- II. the neighbourhoods by day
    day = [("oldtown", 84, 56, 118), ("shore", 96, 84, 122), ("downtown", 62, 52, 112),
           ("uptown", 70, 74, 116), ("works", 38, 24, 110), ("bridge", 84, 38, 120),
           ("north", 80, 20, 114)]
    for name, x, y, tod in day:
        take(p, name, x, y, length(name), 2, tod=tod)
    # the stadium on game night: dusk, confetti
    p.outfile("cap/stadium.raw")
    p.mark("stadium")
    p.zoom(1)
    p.cam(57, 91, 0, 0)
    p.tod(200, 0)
    p.film(20, 2)
    p.confetti(57, 91)
    p.confetti(58, 92)
    p.film(length("stadium") - 20, 2)
    takes["stadium"] = dict(cam=(57, 91), frames=length("stadium"))
    # ---- info views
    for name, ov in (("view_power", OV_POWER), ("view_water", OV_WATER),
                     ("view_traffic", OV_TRAFFIC), ("view_land", OV_LANDVAL)):
        p.overlay(ov)
        take(p, name, 66, 58, length(name, 16), 2, tod=124)
    p.overlay(0)
    # ---- V. golden hour
    gold = [("gold_a", 64, 56, 182), ("gold_b", 98, 76, 186), ("gold_c", 70, 78, 188),
            ("gold_d", 86, 38, 190)]
    for name, x, y, tod in gold:
        take(p, name, x, y, length(name), 2, tod=tod)
    take(p, "wide", 66, 62, length("wide", 40), 2, tod=184, todspeed=6)
    # ---- IV. night, fires, the meteor
    take(p, "night", 66, 56, length("night"), 2, tod=16)
    for (x, y) in ((88, 50), (90, 48), (86, 52), (92, 51), (89, 46)):
        p.fire(x, y)
    p.speed(2)
    take(p, "fire", 88, 50, length("fire"), 2, tod=20)
    take(p, "fire_wide", 86, 50, length("fire_wide"), 3, tod=24)
    p.speed(1)
    # meteor: film the dark city, strike exactly at the impact frame
    p.outfile("cap/meteor.raw")
    p.mark("meteor")
    p.zoom(1)
    p.cam(78, 60, 0, 0)
    p.tod(30, 0)
    pre = int((31.0 - 29.5) * BAR_FRAMES) + 12      # frames before impact
    p.film(pre, 2)
    p.meteor(78, 60)
    p.film(90, 2)
    takes["meteor"] = dict(cam=(78, 60), frames=pre + 90, impact=pre)
    # ---- back to the first year: the first houses and the first car
    p.load("cap/era1.sav")
    p.speed(3)
    p.speed(3)
    take(p, "houses", 84, 54, length("houses", 40), 1, tod=96)
    p.speed(1)
    p.ff(2400, 3)
    p.speed(1)
    p.outfile("cap/car.raw")
    p.mark("car")
    p.zoom(1)
    p.cam(82, 56, 0, 0)
    p.tod(104, 0)
    p.follow(82, 56)
    p.film(length("car", 40), 2)
    p.follow(-1, -1)
    takes["car"] = dict(cam=(82, 56), frames=length("car", 40))
    p.outfile("cap/end.raw")
    return p


def main():
    p = build_plan()
    p.save(os.path.join(CAP, "plan.bin"))
    print("filming...")
    lines = run(os.path.join(CAP, "plan.bin"), os.path.join(CAP, "_first.raw"), W, H,
                cwd=HERE, log=os.path.join(CAP, "log.txt"))
    # parse events per take
    cur = None
    starts = {}
    ev = {}
    for ln in lines:
        f = ln.split()
        if not f:
            continue
        if f[0] == "SHOT":
            cur = p.shots[int(f[1])]
            starts[cur] = int(f[2])
            ev[cur] = {"tiles": [], "car": []}
        elif f[0] == "TILE" and cur:
            ev[cur]["tiles"].append((int(f[1]) - starts[cur], int(f[2]), int(f[3])))
        elif f[0] == "CAR" and cur:
            ev[cur]["car"].append((int(f[1]) - starts[cur], int(f[2]), int(f[3])))
    for name, d in takes.items():
        d.update(ev.get(name, {}))
        raw = os.path.join(CAP, f"{name}.raw")
        n = os.path.getsize(raw) // (W * H * 4)
        d["frames"] = n
        print(f"{name}: {n} frames")
    json.dump(takes, open(os.path.join(CAP, "takes.json"), "w"), indent=1)
    # encode (lossless, all-intra every 10 for seeking) and drop the raw
    for name in takes:
        raw = os.path.join(CAP, f"{name}.raw")
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgra",
                        "-s", f"{W}x{H}", "-r", "30", "-i", raw, "-c:v", "libx264rgb", "-qp", "0",
                        "-preset", "ultrafast", "-g", "10", os.path.join(CAP, f"{name}.mkv")], check=True)
        os.remove(raw)
    for junk in ("_first.raw", "end.raw"):
        if os.path.exists(os.path.join(CAP, junk)):
            os.remove(os.path.join(CAP, junk))
    print("done")


if __name__ == "__main__":
    main()
