# Trailer pipeline

Everything in the trailer is rendered by the game itself, then cut, graded,
titled and scored here. The current trailer is `v3/`:

1. **City**: `city.py` plans a bay town (a river, a coast, seven districts)
   that grows in eras, so each neighbourhood gets its own architecture.
2. **Footage**: `v3/shoot.py` writes a bytecode plan for the in-engine
   director (`src/trailer.asm`, `--trailer out.raw plan.bin W H`) and films
   every take at 2560x1440 with world pixels 1:1. The takes are the empty
   valley, the first road drawing itself, a time-lapse of all eras, the
   neighbourhoods, info views, golden hour, night fires and the meteor.
3. **Score**: `v3/score.py` arranges the game's recorded band (the same CC0
   samples the game plays) on the shared 90 BPM grid in `v3/timeline.py`.
   A bar is exactly 80 frames.
4. **Edit**: `v3/compose.py` handles cameras (sub-pixel pans and zooms that
   keep pixel art crisp), grading, bloom, tilt-shift, letterbox, typography,
   the voxel logo and the mux into `v3/trailer_v3.mp4`.

```sh
cd v3 && python3 shoot.py && python3 score.py && python3 compose.py
python3 compose.py --still 12.5 30   # stills at story bars
```

`compose.py` in the top folder is the older v2 edit.
