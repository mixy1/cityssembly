"""Shared trailer timeline: music and picture are both cut to this grid."""
BPM = 124
BEAT = 60.0 / BPM
BAR = BEAT * 4
FPS = 30
SR = 44100
BARS = 16
DURATION = BAR * BARS + 1.6       # plus a short ring-out


def bar(b):
    """start time (s) of 1-based bar b (fractions allowed)"""
    return (b - 1) * BAR


SHOTS = {}
with open("shots.txt") as f:
    for line in f:
        _, name, start = line.split()
        SHOTS[name] = int(start)
SHOT_END = 1901

# (start bar, end bar, shot, source offset frames, speed)
EDL = [
    (1,     3,     "valley",       0,  0.75),
    (3,     4,     "build",        24, 1.2),
    (4,     6,     "grow",         40, 2.0),
    (6,     7,     "follow",       20, 1.3),
    (7,     7.25,  "view_power",   6,  1.0),
    (7.25,  7.5,   "view_water",   6,  1.0),
    (7.5,   7.75,  "view_traffic", 6,  1.0),
    (7.75,  8,     "view_land",    6,  1.0),
    (8,     9,     "district",     10, 1.3),
    (9,     10,    "sunset",       30, 1.6),
    (10,    11,    "night",        0,  1.2),
    (11,    12,    "seasons",      0,  2.1),
    (12,    12.75, "finale",       10, 1.4),
    (12.75, 15,    "meteor",       6,  1.0),    # impact lands on the bar 13 downbeat
    (15,    18,    "wide",         0,  0.7),
]
