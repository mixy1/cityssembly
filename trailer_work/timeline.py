"""Shared trailer timeline: music and picture are both cut to this grid."""
BPM = 110
BEAT = 60.0 / BPM          # seconds
BAR = BEAT * 4
FPS = 30
SR = 44100
BARS = 33                  # 32 bars + ring-out
DURATION = BAR * BARS


def bar(b):
    """start time (s) of 1-based bar b (fractions allowed)"""
    return (b - 1) * BAR


# footage shot starts (frame index in capture.mkv), from shots.txt
SHOTS = {}
with open("shots.txt") as f:
    for line in f:
        _, name, start = line.split()
        SHOTS[name] = int(start)
SHOT_END = 1901

# edit decision list: (start bar, end bar, shot, source offset frames, extra)
# the source frame for timeline time t is SHOTS[shot] + offset + (t-start)*FPS*speed
EDL = [
    (1,    5,    None,           0,   {}),                   # code intro
    (5,    7,    "valley",       0,   {"speed": 0.73}),
    (7,    9,    "build",        0,   {"speed": 0.82}),
    (9,    13,   "grow",         0,   {"speed": 1.15}),
    (13,   15,   "follow",       10,  {}),
    (15,   17,   "district",     0,   {"speed": 0.92}),
    (17,   17.5, "view_power",   4,   {}),
    (17.5, 18,   "view_water",   4,   {}),
    (18,   18.5, "view_traffic", 4,   {}),
    (18.5, 19,   "view_land",    4,   {}),
    (19,   21,   "sunset",       0,   {"speed": 1.1}),
    (21,   23,   "night",        0,   {"speed": 0.92}),
    (23,   25,   "seasons",      0,   {"speed": 0.98}),
    (25,   27,   "meteor",       20,  {"speed": 1.2}),       # impact on the downbeat
    (27,   27.66, "ui_build",    0,   {}),
    (27.66, 28.33, "ui_stats",   0,   {}),
    (28.33, 29,  "ui_water",     0,   {}),
    (29,   31,   "finale",       0,   {"speed": 1.0}),
    (31,   34,   "wide",         0,   {"speed": 0.6}),
]
