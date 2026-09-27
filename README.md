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
- an **audio engine**: a 32-voice sampler with reverb, real recorded
  instruments, and a **generative New York score** that follows your city
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

## Play in the browser

**https://cityssembly.mixy.one** runs the same assembly in your browser.

The x86-64 code isn't emulated. `tools/asm2c/translate.py` reads the object
file NASM produces from the unchanged source (code, data, symbols and
relocations) and translates it statically into C:

- every function becomes a C function, with registers as locals
- flags are lazy, evaluated only where a jump or `setcc` reads them
- the emulated stack keeps the native layout
- data keeps NASM's exact layout
- the few jump and function-pointer tables become switches

Emscripten compiles that C and a small SDL/libc shim (`web/runtime.c`) to
WebAssembly. The native build of the translated code is pixel-identical to the
real binary and runs at about 85% of its speed. Saves go to IndexedDB.

The browser build uses threads too. The page is cross-origin isolated
(`web/_headers`), so the translated worker pool runs on Web Workers over shared
memory. Each worker gets its own register file and stack. Drawing the world
and the lighting are split into bands across them. At 1440p fully zoomed out, a
frame takes about 13 ms of work (it was 53 ms on one thread).

URL options:

- `?load=URL` opens a city file, so you can share a city by link.
- `?debug` shows the log and frame timings.
- `?bench` prints a per-stage frame profile.

```sh
make web        # -> site/  (needs nasm, emcc, pip install capstone pyelftools)
```

GitHub Actions builds Windows, Linux and web on every push. A Cloudflare
Worker serves the site from `site/` (see `wrangler.jsonc`). Deploy with
`make web && npx wrangler deploy`, or let CI do it once the
`CLOUDFLARE_API_TOKEN` secret is set.

## Playing

Start by extending one of the two **regional highways** (west and north) with
a road, zone some homes and industry next to it, and add a power plant.
Every tool shows a short hint panel on the left explaining what it does.
Power and water tools open their **info view** automatically:

- power tools show where power reaches (yellow), buildings without power (red)
  and the glowing wires
- water tools show the underground **pipe network** (grey = no pump, orange =
  no sewage outlet big enough), the area it serves (blue), dry buildings (red)
  and buildings with water but no sewage (orange)

The bulldozer follows the view. In the water view it only digs up pipes, and
in the power view it only takes down power lines. The water and power menus
also have *Remove pipes* / *Remove power lines*. Hover anything on the top
bar for details, and click the money to open the budget.

Info views are tinted over the city, so you can still see every building
underneath. For any tool that has a view (services too), a chip at the top
switches it on or off (`V`). Your choice is remembered in `cityssembly.cfg`.
Placing a service shows its reach and dim rings around the ones you already
have. All other views (traffic, land value, pollution, desirability...) are
one press of `O` or a pick from the info views menu away.

Then chase the advisor goals shown in the top-left.

### Quality of life

- **First-time tour:** a new city opens a guided tour. It highlights each
  thing on screen (the roads menu, the end of the highway, zoning, power,
  water, the speed buttons, demand, info views and goals), dims the rest,
  and shows a card with Next and Skip. Steps that ask you to do something
  move on by themselves once you've done it. It runs once; replay it from
  Help (F1) → Take the tour.

- **Settings** (Esc → Settings) cover music and sound volume sliders,
  see-through buildings, lighting, edge scrolling, autosave (every 3 months), disasters,
  day/night and fullscreen. They're remembered in `cityssembly.cfg`.
- **Continue** your city from the welcome screen. Saves also remember where
  you were looking. Saves carry over to new versions of the game: the file
  is a list of chunks, and state added later starts at its default.
- **Re-zoning:** paint a zone over built-up land to replace what's there, for
  example low-density homes with apartments. The old buildings come down and
  the new zone grows in. De-zoning clears buildings too.
- **Undo** with Ctrl+Z: it takes back what the action changed and refunds the
  money.
- **Upgrade roads** tool: pick street / avenue / highway, then click a road to
  upgrade its whole stretch (junctions included) or drag along roads.
- **See-through buildings:** anything in front of what you're pointing at is
  drawn see-through.
- Placement tools show the **price and tile count next to the cursor**.
- The mouse wheel **zooms toward the cursor**.
- The **minimap** shows districts, your land and your view. Click or drag it
  to move.
- Clicking a notification jumps to where it happened and dismisses it.
  Repeats are grouped (×3).
- **City issues** list (top left, with the inspect tool): counts of buildings
  with each problem plus jammed roads. Click a line to visit each case in
  turn; jammed roads open the road inspector.
- **Road inspector** shows the stretch, how much of it is jammed, and
  one-click upgrade buttons with the price.
- The zoning hint shows **live demand** for the zone you're painting.
- Hover *Services* in the budget for the **cost per category**.
- `Home` jumps back to the middle of your city.

### Progression (Cities: Skylines style)

- **Land.** The map is a 5×5 grid of plots. You start with one plot, which
  has a creek for your pump and sewage outlet. The land tool (`K`) shows your
  land, what's for sale, and prices. Each milestone lets you own one more plot,
  and every plot costs more than the last. Reaching the second highway in the
  north means buying your way there.
- **Milestones** (Hamlet 60, Village 250, Town 600, Large Town 1,200,
  City 2,500, Large City 5,000, Capital 9,000, Metropolis 16,000,
  Megalopolis 30,000) pay a reward and unlock things. Services, dense zones,
  offices, avenues, highways, buses and landmarks all start locked. A card
  shows what's new, locked items in the build menus name the milestone they
  need, and the bar under the city name tracks your progress.
- **Money is tight.** Services cost real upkeep, and so do roads. Take a loan
  from the budget panel (F2) to bridge a gap: $10k, then $30k from Village and
  $80k from Large Town, repaid monthly. With no money you can't build.

| Input | Action |
|---|---|
| Left drag | build with the current tool (roads/pipes draw L-shapes, power lines run straight, zones draw rectangles) |
| Left click | inspect a building, or a problem icon; click empty land to close |
| Right drag / WASD / arrows | pan (Shift = faster) |
| Right click | step back: cancel the drag, close the inspector, panel or menu, then drop the tool |
| Mouse wheel, `-` `=` | zoom |
| `Q` `B` `R` `T` `P` `L` | inspect, bulldoze, road, trees, water pipes, power lines |
| `1` - `6` | zones: residential, commercial, industry, office, dense residential, dense commercial |
| `X` | de-zone (clears buildings) |
| `Space`, `[` `]` | pause, game speed |
| `K` | buy land |
| `O` | cycle info views |
| `V` | show/hide the current tool's info view (remembered) |
| `F2` `F3` `F4` | budget & taxes, policies, city statistics |
| `Tab` | minimap (click it to jump) |
| `N` / `M` | lock daylight / music on-off |
| `F5` / `F9` | save / load (`city.sav`) |
| `F11`, `F1`, `Esc` | fullscreen, help, menu |
| `Ctrl+Z` | undo (up to 24 actions, money refunded) |
| `U` | upgrade roads (click a road to upgrade the whole stretch) |
| `H` | see-through buildings: near cursor / all / off |
| `Home` | back to the middle of the city |

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

### Neighbourhoods

Homes come in six architectural styles, each with its own low- and
high-density form, built for every level with four variants (240 models):

| Style | Houses | Apartments |
|---|---|---|
| Old Town | brownstone rows with stoops and cornices | brick tenements with fire escapes and rooftop water towers |
| Garden | gabled houses, picket fences, garages, pools | terraces with balconies, planters and roof gardens |
| Shore | pastel beach houses on stilts with decks | glass condos ringed with balconies |
| Worker | rows of clapboard cottages | concrete and brick housing projects |
| Uptown | painted-lady victorians with turrets and porches | art-deco towers with setbacks, gold crowns and spires |
| Modern | white-and-timber boxes, solar roofs, pools | glass towers with fins and beacons |

When a home is built it mostly takes after its street, so districts hold
together, and some pick a related style for texture. Where there's no street
character yet, the place decides: water → Shore, industry or pollution →
Worker, high land value → Uptown, parks and trees → Garden. Otherwise the
city's age decides: the first streets become the Old Town and later growth
is Modern. Buildings also age month by month, and after eight years they look
weathered, so the old town looks its age.

### Music: "Five Boroughs"

The soundtrack is a songbook of five original tunes, one per style, played
by a band of real recorded instruments. The style follows the city:

| When | Tune | Band |
|---|---|---|
| night | **Autumn on Bleecker** (Village Vanguard swing, F major) | ride and brushes, walking upright bass, Steinway comping in rootless voicings, harmon-muted trumpet |
| day | **Myrtle Avenue** (Brooklyn boom bap, D minor) | dusty kick and snare, swung 16th hats, lo-fi piano over vinyl crackle, a written bass riff, tenor sax |
| day | **Loisaida** (Nuyorican salsa, A minor) | 2-3 son clave, conga tumbao, bongo martillo, cowbell, guiro, piano montuno, trumpet melody and a trumpet-trombone mambo |
| morning | **Times Square Morning** (Broadway, C major) | two-feel with stride piano, strings and clarinet |
| fires | **Rain on Mulberry** (noir ballad, C minor) | tenor sax and strings, with sirens across the city |

Each tune has a written melody and chord chart (an A and a B section) and is
played in a proper form: intro, head A, A, B, A, a solo chorus over the A and
B changes, and the head out. In the solos the player works from the tune:
neighbouring chord tones, split notes, anticipations, with the cadence played
as written. Then the next tune for the time of day starts. A fire cuts
straight to the noir tune. In a small town the pianist plays the melody; the
horns join as the population grows. At night in New York you'll hear the odd
siren anyway.

The recordings are CC0 (public domain) from Versilian Studios' **VCSL** and
**VSCO-2 Community Edition**: a Steinway B, an upright bass, harmon-muted and
open trumpet, tenor sax, clarinet, violin section, trombone, a drum kit,
congas, bongos, cowbell, claves and guiro. `tools/samples/build_samples.py`
downloads them, detects each zone's real pitch and retunes it, trims, levels,
loops the sustained ones, and packs 48 zones (3.8 MB) into
`src/nyc_samples.bin`, which the game embeds with `incbin`.

Sound effects use instruments synthesized at start-up (FM electric piano, Karplus-Strong
upright bass and nylon guitar, modal vibraphone, marimba and bells, FM muted
horn, string pad, noise-shaped drums). To use **your own recordings**, drop
16-bit PCM `.wav` files into a `samples/` folder next to the executable. They
replace the built-in instruments:

`rhodes` (C3), `rhodes_hi` (C5), `bass` (A1), `guitar` (A3), `vibes` (C5),
`marimba` (C5), `horn` (C4), `pad` (C4), `bell` (C6), and one-shots `kick`,
`snare`, `brush`, `ride`, `hat`, `shaker`, `rim`, `rumble`, `boom`.

### Lighting

Every sprite pixel stores the height of the voxel it shows, so the renderer
knows where each screen pixel is in the world. Each frame the heights of all
buildings, trees and pylons near the view go into a height map, and one sweep
toward the sun turns it into a shadow map. Buildings shade the ground, the
streets and each other's walls. Shadows are short and cool at noon and
stretch out at dawn and dusk, when sunlit walls turn warm. On top of that
there's contact shading where buildings meet the ground, and drifting cloud
shadows. Water is shaded per pixel: turquoise shallows fade to deep blue with
distance from the shore, two ripple layers drift across each other with
bright crests, foam laps at the water's edge, and the sun glints on it. At night, lit windows, street lamps and
neon glow and spill light onto the streets. Settings → Lighting turns it all
off for slow machines.

The light passes run on every CPU core (a small SDL thread pool splits the
screen into bands). The shadow sweep covers a margin around the view and is
reused while you pan. At 4K fully zoomed out, lighting takes about 5 ms a
frame.

## Source layout

| File | Contents |
|---|---|
| `src/main.asm` | entry point, game loop, input dispatch, test modes |
| `src/macros.inc`, `src/sdl.inc` | calling-convention macros (SysV internally, Win64 shim for C calls), constants |
| `src/video.asm` | window, textures, 8bpp → ARGB, screenshots |
| `src/palette.asm` | shading ramps, seasons, day/night, glow and water cycling |
| `src/draw.asm`, `src/font.asm` | 2D primitives, proportional pixel font (ASCII art) |
| `src/voxel.asm` | voxel primitives, material shaders, isometric ray-caster, z-buffered blitter |
| `src/light.asm` | sun and cloud shadows, contact shading, water glints, night bloom |
| `src/threads.asm` | worker thread pool for the per-pixel passes |
| `src/sprites.asm`, `src/sprites2.asm` | every model: terrain, 3 road types, trees, ~40 zone building designs x 4 variants, 2x2 buildings, farms / forestry / mines, 22 services, 6 vehicle types |
| `src/world.asm` | map, noise, terrain generation, road/power masks |
| `src/sim.asm` | growth, utilities (power / pipes / sewage), services, workforce, budget |
| `src/traffic.asm` | pathfinding, vehicles, trips, buses, service dispatch |
| `src/agents.asm` | cars, pedestrians, particles, floating text |
| `src/audio.asm` | instrument synthesis, recorded zones, sampler, reverb, sound effects |
| `src/sprites3.asm` | neighbourhood architecture: six styles of home, low and high density |
| `src/tunes.asm` | the songbook: chord charts and melodies |
| `src/music.asm` | the "Five Boroughs" band: arranging, form, solos |
| `src/ui.asm`, `src/icons_data.asm` | interface, tools, panels, goals, save/load |
| `src/tutorial.asm` | the first-time guided tour |
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
cityssembly --demo 1 out.bmp L          # load city.sav, print a water/sewage report
cityssembly --wav SECONDS out.wav [STYLE [INST]]  # render the soundtrack (STYLE 0-4, INST solo)
cityssembly --trailer out.raw plan.bin W H         # film a scripted plan (trailer_work/plan.py)
```
