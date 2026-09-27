# CITYSSEMBLY

An isometric city builder written in **x86-64 assembly** (NASM), in the spirit of
SimCity and RollerCoaster Tycoon. Pixel art, an arcade pace, and a surprisingly
deep simulation underneath.

SDL2 is used only as a thin platform layer (window, input, audio device). The
rest is hand-written assembly:

- a **voxel sprite factory** that ray-casts every building, tree and car into
  isometric pixel art at start-up (~150 sprites in a fraction of a second)
- a **z-buffered 8-bit renderer** with palette-driven seasons, day/night,
  glowing windows, neon and shimmering water
- the **city simulation**: utility networks, services, pollution, crime, land
  value, traffic, growth, fires and disasters, budget, demand and milestones
- an **audio engine**: physically modelled instruments, a 32-voice sampler with
  reverb, and a **generative jazz score** that follows your city
- the **UI**: immediate-mode widgets, tools, overlays, minimap, advisor goals

## Building

From WSL / Linux (needs `nasm`, `x86_64-w64-mingw32-gcc`):

```sh
make            # Windows build -> dist/cityssembly.exe (SDL2 linked statically)
make linux      # native Linux build -> ./cityssembly (needs libSDL2 installed)
```

The Windows build downloads the SDL2 MinGW development package into
`third_party/` automatically on first build (or run `make deps`).

Run `dist/cityssembly.exe` from Windows, or straight from WSL with
`./dist/cityssembly.exe`.

## Playing

Start by extending the **highway** on the west edge with a road, zone some
**residential (1)** and **industrial (3)** land next to it, and add a power
plant. Roads, zoned lots and buildings all carry power and water, so power
lines are only needed to bridge gaps. Then chase the advisor goals shown in
the top-left.

| Input | Action |
|---|---|
| Left drag | build with the current tool (roads draw L-shapes, zones draw rectangles) |
| Right drag / WASD / arrows | pan (Shift = faster) |
| Right click | cancel drag / back to Inspect |
| Mouse wheel, `-` `=` | zoom |
| `Q` `B` `R` `L` `T` | inspect, bulldoze, road, power line, trees |
| `1` `2` `3` `X` | residential, commercial, industrial, de-zone |
| `Space`, `[` `]` | pause, game speed |
| `O` | cycle data overlays (power, water, pollution, crime, land value, traffic, coverage, happiness) |
| `F2` | budget and taxes (with history charts) |
| `Tab` | minimap (click it to jump) |
| `N` | lock daylight, `M` music on/off |
| `F5` / `F9` | save / load (`city.sav`) |
| `F11` | fullscreen, `F1` help, `Esc` menu |

### How the city works

- **Growth.** Each zoned tile computes a desirability from land value, demand,
  services, pollution and crime. Buildings grow through five levels (cottage
  → tower); each level has requirements:
  - level 1: road access and power; residential and industry also need a road
    link to the regional highway
  - level 2: running water
  - level 4: police and fire cover
  - level 5: schools and health care (high-tech industry needs education)
- **Why won't it grow?** Inspect a building: the panel tells you what's missing.
- **Utilities** are real networks. A power plant only supplies the grid it
  touches. Overloaded grids brown out, dimming a share of the city. Water pumps
  must touch water and need power themselves.
- **Services** (police, fire, health, education, parks) cover a radius and only
  work when powered. Their coverage feeds land value, crime and growth.
- **Pollution** comes from industry, coal and traffic. It drifts over
  neighbourhoods and lowers land value. Trees and parks soak it up.
- **Traffic.** Every building sends trips onto nearby roads. Busy roads slow
  cars and add pollution; more, better-spread roads relieve it.
- **Fires** break out and spread. Fire stations extinguish them, or you can
  send firefighters from the inspector. Big cities may be hit by **meteors**
  (disasters can be turned off in the menu).
- **Money.** Taxes (0–20%) change demand and happiness; upkeep is paid monthly.
  Milestones and goals pay cash rewards and unlock buildings.

### Music

The soundtrack is composed live: jazz chord progressions (ii–V–I, rootless
voicings), a walking bass, swung ride cymbal and brushes, and motif-based melodies
that develop over 8-bar phrases. The style follows the city: swing by day, lo-fi
at night, bossa nova some afternoons, and a minor-key tension mode while fires
burn. The band grows with your population. Sound effects are played on the same
instruments, in the current key.

The instruments are synthesized at start-up (FM electric piano, Karplus-Strong
upright bass and nylon guitar, modal vibraphone, marimba and bells, FM muted
horn, string pad, noise-shaped drums). To use **your own recordings**, drop
16-bit PCM `.wav` files into a `samples/` folder next to the executable. They
replace the built-in instruments:

`rhodes` (C3), `rhodes_hi` (C5), `bass` (A1), `guitar` (A3), `vibes` (C5),
`marimba` (C5), `horn` (C4), `pad` (C4), `bell` (C6), and one-shots `kick`,
`snare`, `brush`, `ride`, `hat`, `shaker`, `rim`, `rumble`, `boom`.

## Source layout

| File | Contents |
|---|---|
| `src/main.asm` | entry point, game loop, input dispatch, test modes |
| `src/macros.inc`, `src/sdl.inc` | calling-convention macros (SysV internally, Win64 shim for C calls), constants |
| `src/video.asm` | window, textures, 8bpp → ARGB, screenshots |
| `src/palette.asm` | shading ramps, seasons, day/night, glow and water cycling |
| `src/draw.asm`, `src/font.asm` | 2D primitives, proportional pixel font (ASCII art) |
| `src/voxel.asm` | voxel primitives, material shaders, isometric ray-caster, z-buffered blitter |
| `src/sprites.asm` | every model: terrain, roads, trees, 45 zone buildings, 17 services, vehicles |
| `src/world.asm` | map, noise, terrain generation, road/power masks |
| `src/sim.asm` | the simulation |
| `src/agents.asm` | cars, pedestrians, particles, floating text |
| `src/audio.asm` | instrument synthesis, sampler, reverb, composer, sound effects |
| `src/ui.asm`, `src/icons_data.asm` | interface, tools, panels, goals, save/load |
| `src/buildings.asm` | service building stats |

`tools/icons_to_asm.py` only validates the 16×16 ASCII-art icons and emits
`src/icons_data.asm`. It isn't needed to build.

### Test modes

```sh
cityssembly --shot N out.bmp            # render N frames, save a screenshot
cityssembly --demo N out.bmp [view]     # auto-build a town, simulate 700 days, screenshot
                                        # view: b budget, m menu, i inspect, s build menu,
                                        #       o/p overlays, n night, t tools, l save/load
cityssembly --wav SECONDS out.wav       # render the soundtrack offline
```
