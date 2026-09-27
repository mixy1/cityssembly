"""Trailer v3 timeline: picture and score share this grid.

90 BPM at 30 fps: a bar is exactly 80 frames, a beat 20, an eighth 10.
Story bars are 1-based and may be fractional; the cold open (PRE bars)
comes before story bar 1.
"""
BPM = 90
FPS = 30
SR = 48000
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BAR_FRAMES = 80


def bar(b):
    """start time (s) of story-independent bar b (1-based from the very start)"""
    return (b - 1) * BAR


def frame(b):
    return int(round((b - 1) * BAR_FRAMES))


# sections (story bars)
DAWN = 1.0          # valley, the road draws itself, first houses, first car
LIFE = 5.0          # (the neighbourhood tour was cut: dawn runs into growth)
GROW = 5.0          # time-lapse, info views, the wall
TRIAL = 9.0         # night, fire, the meteor
IMPACT_BAR = 12.0   # the meteor lands on this downbeat
FINAL = 12.5        # golden hour, the pull-out, the logo
LOGO_BAR = 16.0
END = 19.0

PRE = 1                     # cold open before the story (bars)
STORY_BARS = END - 1
BARS = int(STORY_BARS + PRE)
DURATION = BARS * BAR

# the edit: (start bar, end bar, take, caption)
_places = [("oldtown", "OLD TOWN"), ("shore", "THE SHORE"), ("downtown", "DOWNTOWN"),
           ("uptown", "UPTOWN"), ("works", "THE WORKS"), ("bridge", "RIVER CROSSING"),
           ("north", "NORTH BANK"), ("stadium", "GAME NIGHT")]
_views = [("view_power", "POWER"), ("view_water", "WATER"), ("view_traffic", "TRAFFIC"),
          ("view_land", "LAND VALUE")]
_gold = ["gold_a", "gold_b", "gold_c", "gold_d"]

EDIT = [
    (DAWN, DAWN + 1, "valley", None),
    (DAWN + 1, DAWN + 3, "road", None),
    (DAWN + 3, DAWN + 3.5, "houses", None),
    (DAWN + 3.5, LIFE, "car", None),
]
EDIT += [(GROW, GROW + 2.5, "timelapse", None)]
EDIT += [(GROW + 2.5 + i * 0.25, GROW + 2.75 + i * 0.25, t, c) for i, (t, c) in enumerate(_views)]
EDIT += [
    (TRIAL, TRIAL + 1, "night", None),
    (TRIAL + 1, TRIAL + 2, "fire", None),
    (TRIAL + 2, IMPACT_BAR + 0.25, "meteor", None),
]
EDIT += [(FINAL + i * 0.5, FINAL + (i + 1) * 0.5, t, None) for i, t in enumerate(_gold)]
EDIT += [(FINAL + 2, END, "wide", None)]
