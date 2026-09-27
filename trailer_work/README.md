# Trailer pipeline

Everything in the trailer is rendered by the game itself, then graded,
titled and scored here.

1. **Footage** - `cityssembly --trailer out.raw` runs a scripted director
   (`src/trailer.asm`): camera moves, a time-lapse of the city growing, a
   tracking shot, info views, sunset/night, seasons, a meteor and interface
   shots. It writes raw 960x540 BGRA frames plus shot markers on stdout.
   ```sh
   ../cityssembly --trailer raw.bgra > shots.txt
   ffmpeg -f rawvideo -pix_fmt bgra -s 960x540 -r 30 -i raw.bgra \
          -c:v libx264 -crf 4 -pix_fmt yuv444p capture.mkv
   ```
2. **Instruments** - the game's synthesized samples are dumped from memory
   (see `dump.gdb` recipe in the commit history) into `samples/`.
3. **Score** - `python3 music.py` arranges them into `music.wav`, cut to the
   same 110 BPM bar grid as the edit (`timeline.py`).
4. **Edit + motion graphics** - `python3 compose.py` renders the titles,
   code cold-open, grading, bloom, transitions and end card in parallel and
   muxes `trailer.mp4`.
