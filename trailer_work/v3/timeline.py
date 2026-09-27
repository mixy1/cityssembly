"""Trailer v3 timeline: picture and score share this grid.

90 BPM at 30 fps: a bar is exactly 80 frames, a beat 20, an eighth 10.
Bars are 1-based and may be fractional.
"""
BPM = 90
FPS = 30
SR = 48000
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BAR_FRAMES = 80
PRE = 2                    # cold open before the story (bars)
BARS = 40 + PRE
DURATION = BARS * BAR


def bar(b):
    """start time (s) of bar b"""
    return (b - 1) * BAR


def frame(b):
    return int(round((b - 1) * BAR_FRAMES))


# the edit: (start bar, end bar, take, caption)
EDIT = [
    # I. dawn
    (1.0, 3.5, "valley", None),
    (3.5, 7.0, "road", None),
    (7.0, 8.0, "houses", None),
    (8.0, 9.0, "car", None),
    # II. life
    (9.0, 10.0, "oldtown", "OLD TOWN"),
    (10.0, 11.0, "shore", "THE SHORE"),
    (11.0, 12.0, "downtown", "DOWNTOWN"),
    (12.0, 13.0, "uptown", "UPTOWN"),
    (13.0, 14.0, "works", "THE WORKS"),
    (14.0, 15.0, "bridge", "RIVER CROSSING"),
    (15.0, 16.0, "north", "NORTH BANK"),
    (16.0, 17.0, "stadium", "GAME NIGHT"),
    # III. growth
    (17.0, 22.5, "timelapse", None),
    (22.5, 23.0, "view_power", "POWER"),
    (23.0, 23.5, "view_water", "WATER"),
    (23.5, 24.0, "view_traffic", "TRAFFIC"),
    (24.0, 24.5, "view_land", "LAND VALUE"),
    # IV. trials
    (25.0, 26.5, "night", None),
    (26.5, 28.0, "fire", None),
    (28.0, 29.5, "fire_wide", None),
    (29.5, 31.25, "meteor", None),
    # V. finale
    (32.0, 33.0, "gold_a", None),
    (33.0, 34.0, "gold_b", None),
    (34.0, 34.5, "gold_c", None),
    (34.5, 35.0, "gold_d", None),
    (35.0, 40.0, "wide", None),
]
IMPACT_BAR = 31.0          # the meteor lands on this downbeat
LOGO_BAR = 37.0
