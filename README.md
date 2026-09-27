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

Start by extending one of the two **regional highways** (west and north) with
a road, zone some homes and industry next to it, and add a power plant.
Every tool shows a short hint panel on the left explaining what it does.
Power and water tools open their **info view** automatically:

- power tools show where power reaches (yellow), buildings without power (red)
  and the glowing wires
- water tools show the underground **pipe network** (grey = not connected to a
  pump), the area it serves (blue) and dry buildings (red)

Info views are tinted over the city, so you can still see every building
underneath. For any tool that has a view (services too), a chip at the top
switches it on or off (`V`). Your choice is remembered in `cityssembly.cfg`.
Placing a service shows its reach and dim rings around the ones you already
have. All other views (traffic, land value, pollution, desirability...) are
one press of `O` or a pick from the info views menu away.

Then chase the advisor goals shown in the top-left.

| Input | Action |
|---|---|
| Left drag | build with the current tool (roads/pipes draw L-shapes, power lines run straight, zones draw rectangles) |
| Left click | inspect a building, or a problem icon; click empty land to close |
| Right drag / WASD / arrows | pan (Shift = faster) |
| Right click | step back: cancel the drag, close the inspector, panel or menu, then drop the tool |
| Mouse wheel, `-` `=` | zoom |
| `Q` `B` `R` `T` `P` `L` | inspect, bulldoze, road, trees, water pipes, power lines |
| `1` - `6` | zones: residential, commercial, industry, office, dense residential, dense commercial |
| `X` | de-zone empty lots |
| `Space`, `[` `]` | pause, game speed |
| `O` | cycle info views |
| `V` | show/hide the current tool's info view (remembered) |
| `F2` `F3` `F4` | budget & taxes, policies, city statistics |
| `Tab` | minimap (click it to jump) |
| `N` / `M` | lock daylight / music on-off |
| `F5` / `F9` | save / load (`city.sav`) |
| `F11`, `F1`, `Esc` | fullscreen, help, menu |

Icons above buildings show their most urgent problem (no power, no water,
sewage, garbage, missing goods, missing workers, fire, no road, no route).
Hover an icon to name the problem, click it to open the building. The
inspector explains what's wrong and how to fix it.

### How the city works

**Zones.** There are six zone types: low- and high-density residential and
commercial, industry, and offices. Buildings grow through five levels, and
dense zones merge into **2x2 buildings** (courtyard blocks, twin towers, malls,
cinemas, HQ towers, big factories). Industry specialises by the land beneath
it: farms on fertile soil, forestry in forests, mines on ore, manufacturing
elsewhere. The *Natural resources* info view shows where each is.

Each level has requirements:

- level 1: road access and electricity; homes and factories also need a road
  link to the region
- level 2: water and sewage
- level 3: garbage collection, goods for shops, staff for jobs, clean water
- level 4: police and fire cover; homes also need health care and schools,
  and offices need high schools
- level 5: higher education and parks (a university for jobs)

**Electricity** spreads between buildings within 2 tiles. Roads don't carry
it, so drag **power lines** across gaps. Like Cities: Skylines, a line is a
straight run of steel pylons, placed automatically every few tiles, with
wires strung between them. A pylon powers anything within 2 tiles, and wires
can end on a plant or any building. Overloaded grids brown out.

**Water** flows through pipes from pumps (which must touch water) and water
towers, and serves buildings within 3 tiles of a pipe. One pipe network
carries both ways. Fresh water comes in from a pump or tower touching the
pipes. Every building it serves sends its **sewage back** through the same
pipes to a **sewage outlet** touching the network, and the outlet dumps it
into the river, **polluting it downstream**. So put outlets on the shore, far
from your pumps. A pump drawing polluted water supplies dirty water, which makes
people sick.

**Traffic** is agent-based. Every vehicle has a real origin, destination and
route (Dijkstra over the road graph with live congestion):

- commuters and shoppers
- goods trucks from industry to shops
- exports and imports over the highways
- visitors
- fire trucks that must reach a fire to put it out
- garbage trucks that sweep a block and return to their depot
- police patrols

Roads have per-lane capacity, so queues and jams form; stuck drivers re-route.
Streets, avenues (4 lanes with a median) and highways (fast, but no building
access) have different capacity and speed. Build a highway to the map edge for
another regional link.

**Transit.** A bus depot runs buses between every bus stop. Residents near a
stop ride instead of driving, which cuts traffic and earns fares.

**Workforce.** Elementary schools, high schools and universities raise
residents' education. Offices need educated workers and hi-tech industry needs
graduates; the wrong mix leaves jobs unfilled.

**Garbage** piles up without collection. Landfills fill up; incinerators burn
waste and make power, but pollute.

**Pollution, noise, crime and land value** interact; trees and parks help.

**Budget.** Separate tax rates for residential, commercial, industry and
offices, plus fares, exports and tourism income, against road, service and
policy upkeep.

**Policies:** smoke detectors, recycling, free public transport, high-rise
ban, encourage biking, industrial filters, education boost, and parks &
recreation.

**Hazards.** Fires spread and meteors strike big cities (disasters can be
turned off).

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
| `src/sprites.asm`, `src/sprites2.asm` | every model: terrain, 3 road types, trees, ~40 zone building designs x 4 variants, 2x2 buildings, farms / forestry / mines, 22 services, 6 vehicle types |
| `src/world.asm` | map, noise, terrain generation, road/power masks |
| `src/sim.asm` | growth, utilities (power / pipes / sewage), services, workforce, budget |
| `src/traffic.asm` | pathfinding, vehicles, trips, buses, service dispatch |
| `src/agents.asm` | cars, pedestrians, particles, floating text |
| `src/audio.asm` | instrument synthesis, sampler, reverb, composer, sound effects |
| `src/ui.asm`, `src/icons_data.asm` | interface, tools, panels, goals, save/load |
| `src/buildings.asm` | service building stats |

`tools/icons_to_asm.py` only validates the 16×16 ASCII-art icons and emits
`src/icons_data.asm`. It isn't needed to build.

### Test modes

```sh
cityssembly --shot N out.bmp            # render N frames, save a screenshot
cityssembly --demo N out.bmp [view]     # auto-build a town, simulate ~2 years, screenshot
                                        # view: b budget, m stats, y policies, i inspect,
                                        #       s water menu, w/p/z/t/o info views, n night,
                                        #       q/Q pylons, F placing a service, I problem inspector,
                                        #       T scripted new-player playtest (prints a report)
cityssembly --wav SECONDS out.wav       # render the soundtrack offline
```
