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
- `?beta` switches on the features still in testing (see *Beta* below).
  Native builds take `--beta` (or `CS_BETA=1`).

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

### Beta (`?beta`)

Features still in testing, off unless you ask for them:

- **Build over the city:** special buildings go down over zoned
  buildings, which come down first. The price tag says how many and who
  lived or worked there. Roads only give way with Ctrl held. A spot that
  doesn't fit slides up to 2 tiles to the nearest one that does, and the
  cursor says why a spot won't work.
- **Inspector actions:** Demolish any building, Replace a zoned one with
  any service (a list with prices), Move a service (a quarter of its
  price), and Upgrade in place: clinic to hospital, park to plaza,
  landfill to incinerator, coal to nuclear. A service gives its lot back
  to the zone it was built over when it goes.
- **Redo:** Ctrl+Y (or Ctrl+Shift+Z).
- **Road modes** (buttons under the road hint, or `G`): L-shape, straight
  (or hold Shift), freehand (the road follows the pointer) and grid (drag
  a rectangle: a road every few tiles both ways, 6-tile blocks by default
  so every lot is in reach; Ctrl+wheel or +/- sizes the blocks). New
  roads lay a pipe underneath (a chip turns that off). A road stopped by
  buildings says so; with Ctrl held it goes through homes and shops.
- **Rows:** drag a small building (park, wind turbine, water tower...)
  to put down a row of them, or drag bus stops along a road (one every
  5 tiles).
- **Eyedropper:** `E` over anything picks up the tool that built it.
- **Sandbox cities** (menu): money never runs out, all the land is yours
  and everything is unlocked.
- **City files on the web** (menu): download the city you're playing, or
  open a `.sav` file from your computer.
- **Bookmarks:** Ctrl+1..4 marks the view, Shift+1..4 goes back to it
  (saved with the city). Backspace returns to where you were before the
  last jump (bookmark, notification, Home).
- **Assists** (Settings): clear abandoned buildings away every month (on),
  sweep up rubble every month (on), pause for emergencies - fires,
  meteors, an empty treasury (off).
- **Traffic that grows with the city:** no cap at 1,080 cars (a car on
  the road for every 14 residents and 40 jobs, up to about 6,000), and
  the day has a rhythm: commuters in the morning, home again in the
  evening, shoppers and trucks in between, a quiet night. Trips go to
  nearer jobs, shops and homes. Avenue junctions have traffic lights.
  Every home remembers its commute: long ones make people unhappy, and
  homes on them stay at level 3 ("Needs: shorter commutes"). Routes are
  found with A*, so the extra cars cost little.
- **Traffic lights** stand on avenue junctions and show which way is
  green.
- **Metro** (Public transport, from Large City): dig tunnels like pipes
  (under anything, twice the price under water) and put stations on the
  street; stations joined by tunnels make a line. People within 6 tiles
  of a station whose trip ends near another station on the line ride it:
  fast, never in traffic, 4,000 riders a month per station. The metro
  view shows the tunnels (with trains running), the stations and where
  they're a walk away.
- **Railways** (Public transport, from Capital): drag to lay track ($60 a
  tile, three times that over water, as a bridge). Where it crosses a
  road the road gets a level crossing, and cars wait while a train goes
  over. Ctrl lays it through homes and shops. Stations (2x2) go next to
  the track: people within 8 tiles ride to other stations on the line,
  6,000 a month per station, and when the line reaches the map edge,
  visitors arrive by train. Freight yards (3x3) on track that reaches the
  edge ship the goods of industry around them by train instead of by
  truck. Trains run on the track: passenger trains between stations,
  freight trains between a yard and the edge. The rail view shows lines,
  stations and their reach.
- **Airport** (Public transport, from Metropolis): a terminal (3x3,
  $30,000) next to a runway you drag, straight, on land ($150 a tile).
  10 tiles fly small planes (3,000 passengers a month), 16 fly jets
  (9,000). Passengers are a third of the people plus the sights (Asm
  Tower, stadium). Each pays $1, tourists make shops wanted and flights
  make offices wanted, and up to 6% of the city's trips go to or from
  the terminal - by car unless a station is near. Runways are loud, most
  of all under the flight path past their ends (see the noise view).
  Planes come in over the end, land, roll to a stop and taxi off; others
  line up, take off and climb out.
- **Hotels** (Leisure, from Large City): tourists come by air (half the
  passengers), by train (visitors) and for the sights (the Asm Tower,
  stadiums, plazas, wonders, intercity stations). Each hotel puts up
  1,200 a month at $3 a night, and shops are wanted for the guests.
- **Intercity Station** (Public transport, from Megalopolis; 3x3): a
  railway station for fast trains. On a line that reaches the map edge
  it brings business (offices wanted) and 2,000 tourists a month.
- **Neighbours** (`C`, or the button in the budget): every map edge leads
  to a neighbouring city with a name, a character (industrial town,
  farming county, resort, capital) and a population that grows. A
  highway, a railway to the edge or an airport links you to it, and its
  name stands where your link leaves the map.
  - **The market:** what your exports fetch rises and falls (55-150% of
    normal), with recessions and booms now and then. Industry wants to
    grow when prices are up and more neighbours are linked.
  - **Deals:** now and then a linked neighbour offers to buy half your
    spare power or water, or to pay you to take its garbage, for a year.
    Keep your side (the spare capacity, room in the landfill or an
    incinerator) and it pays every month; three missed months and it's
    called off.
  - **Your own cities** (from Metropolis): "Found a city" on an edge
    starts a new city beyond it in a free save slot (this one is saved
    first); the two are linked both ways. Each save carries a short
    summary its linked cities read: they show as "your city" with their
    population, and their unemployed commute in to fill your jobs (and
    yours to theirs). "Visit" saves this city and opens the other.
- **Raw materials:** farms, forestry and mines (industry on fertile land,
  forest or ore) send raw materials by truck to the factories (the other
  industry). A factory without materials works at half speed, with
  enough at full (the inspector shows its stock). With no farms, forests
  or mines, materials come in from the region - more trucks from the
  highway. Exports fetch $16 a truck for what factories made and $8 for
  raw materials, so working them up pays.
- **Cargo Port** (Public transport, from Capital; 3x3 on the shore,
  powered): when ships can reach it (water all the way to the map edge),
  three in five export trucks go to the port instead of the highway, and
  paying a third more, and shops get imports through it - a lot of
  trucks to and from one place. A freight yard within 8 tiles of the
  port takes them off the roads: its railway line counts as reaching the
  region, and the line's exports pay the port's price. Ships sail in from
  the edge, tie up at the quay and sail away.
- **Services have room for so many:** a police or fire station takes
  10,000 people, a clinic 3,000, a hospital 12,000, a school 5,000, a
  high school 8,000, a university 20,000 (students: half the people).
  When the city outgrows what its buildings of a kind can take, that
  service reaches everyone less well (half the shortfall is felt, down to
  62% at worst), and the city issues say so ("High schools overloaded" -
  click for the Services panel). The inspector shows the city-wide places
  and people.
- **Service funding** (Services panel, from the budget): 50% to 150% for
  police, fire, health, schools, high schools and universities. It sets
  their places, how far they reach, and their upkeep.
- **The city shows its wear:** the grass loses its grid and gets worn
  patches, clover, stones and flowers; homes get a yard (laundry, a
  shed, bins, a paddling pool, a vegetable patch, a woodpile), small
  industry barrels and pallets. A building with garbage piling up,
  crime at the door, unhappy people, or old age on cheap land is drawn
  worn - darker, streaked walls, half the windows dark, weeds and
  litter around it - and the inspector says why ("Condition: worn -
  garbage piling up"); an abandoned one is derelict. Busy streets get
  patched asphalt and potholes, a demolished building leaves its
  foundation for a couple of years until the weeds take it back, and
  autumn leaves gather on the grass under the trees. You shouldn't
  have to open a panel to see where the problems are.
- **Decline:** a building a level above what its surroundings support
  loses that level after months of it (classic only let buildings two
  levels too high fall). A month with many is reported.
- **Credit rating** (AAA to B, in the budget): months in the red over the
  last year and loans running lower it, six months of expenses in the
  bank raises it. New loans cost up to 75% more at a low rating.
- **An empty treasury:** two months in the red brings a warning, three
  cut the services back to 70%, six and the region bails the city out
  (back to $25,000) - with taxes 2% higher.
- **Weather, a hazard for each season:**
  - Winter snow: cars crawl on snowy roads (they turn white) except
    within 20 tiles of a Snowplow Depot (Safety, from City).
  - Spring floods (with disasters on): for a week or so the water covers
    the land up to two tiles from it; the people there are miserable and
    some buildings are wrecked when it goes down. Levees (Water, dragged
    along the shore, $40 a tile) hold it back.
  - Summer heatwaves: a quarter more water used, and fires start easily.
  - Autumn storms: rain, and power lines come down.
- **New disasters** (with disasters on): tornadoes that cross the map
  tearing up what's in their path, epidemics where health care is
  overloaded or the water dirty, riots when people are unhappy.
- **Two more milestones:** World City (50,000, $80,000 reward) and Global
  City (80,000, $120,000), and the wonders they unlock (Leisure, one of
  each, each needing something first):
  - Grand Central (World City; 1,000 train riders a month and a
    metro): trips by train and metro cost a quarter less, so more ride.
  - Stock Exchange (World City; an airport flying jets and 4,000 office
    jobs): offices wanted, and half a dollar a month per office job.
  - Opera House (World City; a City Hall and a Stadium): a great park -
    land value and happiness for 22 tiles around.
  - Space Centre (Global City; two universities): offices and hi-tech
    wanted, and a launch every summer that brings $15,000.
  - Expo Centre (Global City; 5,000 air passengers a month): $8,000 a
    month from visitors, and shops wanted.
- **Coverage at the cursor:** placing a police or fire station, clinic,
  school or park, the price says how many buildings or homes it would
  reach that aren't served well now ("$800 +9 homes").
- **Impact at the cursor:** placing something that smokes or is loud
  (a coal plant, an incinerator, an airport) says how many homes its
  smoke and noise would reach.
- **Growth view** (info views): each zoned lot coloured by what holds it
  back - power, a road, water or sewage, demand, the place itself, or
  the services a higher level needs; green grows.
- **Forecasts** (city issues): power or water running out, the landfill
  filling up, or the money running out within six months at this pace.
- **Blueprints:** Ctrl+C, then drag over a piece of the city (up to
  32x32) to copy its roads, zones, pipes and trees - not the buildings,
  the zones grow them again. The copy then follows the cursor: click to
  stamp it (paying for what it lays), R to turn it; Ctrl+V picks it up
  again later. Undo takes a stamp back.
- **Plan mode** (`Shift+P`): roads, zones, pipes, services and the rest
  are drawn as blue ghosts - not built, not paid for. The plan box
  (bottom left) counts the actions and what they'll cost; Build puts up
  what the money covers now, in the order it was drawn, and the rest goes
  up at the months' ends as the money comes in. Clear throws the plan
  away; a piece that can't go where it was drawn any more is dropped.
  What a storm, a tornado, a meteor or a fire wrecks - services, roads,
  power lines with their wires - goes into the plan too, so the ghosts
  show what was lost; nothing is rebuilt until Build is pressed.
- **Milestone pause:** the game pauses while a milestone's card is up and
  goes on at the same speed when it's closed.
- **Minimap filters** (chips over the minimap): the map, jammed roads
  (green to red), power and water (which buildings have them, the lines
  and pipes) and the land value of the city's lots.
- **Milestone planner** (a click on the city's name, top left): the next
  milestone and how far off it is, how soon at the last year's pace,
  what it brings, and what holds the city back - demand, buildings
  without power, water or a road, abandoned ones, garbage, shops short
  of goods, overloaded services and jammed roads.
- **Keys** (Menu > Keys...): click an action, then press its new key.
  Keys swap - the old key takes over what the new one did - so nothing
  is ever lost; W A S D, the arrows and the Ctrl / Alt shortcuts stay as
  they are. Saved with
  the settings; Reset puts every key back.
- **Bulldozer filters** (chips under the hint, or `G`): everything,
  abandoned buildings only, trees only, rubble only.
- **Command palette** (`/`): type any part of a tool's, building's or
  info view's name ("hosp"), Up/Down to choose, Enter to take it.
- **Colour-blind views** (Settings): the info views' scale runs from
  blue to orange instead of green to red.
- **Photo mode** (`F`): the interface goes, the city stays; `[` and `]`
  turn the clock, `P` saves the picture (photo_001.bmp ...; on the web it
  downloads); `F` or Esc brings the interface back.
- **Follow camera:** click a car or train (on its road or track), a ship
  or a plane with the inspector and the view follows it; moving the view
  or Esc lets go.
- **Transit** (statistics panel, F4): every kind of public transport -
  buses, trams, metro, trains, ferries, planes, and trips on foot - with
  its depots, lines, stations and vehicles, and last month's riders
  against its room (a bar turns red when it's nearly full). In beta the
  statistics panel shows the new rows in a second column.
- **History** (statistics panel, F4): monthly graphs of traffic flow,
  commute, happiness, transit riders, trade and jammed roads, over the
  same 64 months as the budget's population and money.
- **Warehouses** (Zones, from 1,200 people; they need power): each holds
  up to 200 truckloads of goods. Factories within its reach (24 tiles)
  that would truck their goods out of town store them there instead, and
  shops within its reach that run short restock from it rather than
  importing from the region. It keeps 40 loads back for the shops and
  exports the rest in bulk: four loads a truck at $15 a load (factories
  get $12), or $20 by rail when it's near a freight yard on a line out.
- **Deathcare** (Health): every month about one in 400 people dies.
  Cemeteries (3x3, from Large Town) take them until full (6,000 graves
  each); Crematoriums (2x2, powered, from Large City) take 200 a month
  and never fill. Homes with neither within 30 tiles are less happy, and
  when the city has more dead than it can take, everyone is - the city
  issues say "Not enough deathcare".
- **Districts** (Zones > Districts): paint areas into eight named
  districts (Downtown, Old Town, Harbour ...; "Erase district" takes tiles
  out). While painting, a bar above the dock picks the district and its
  policies, $1 a building a month each: High-rise ban (dense zones stop at
  level 3 there), Quiet streets (homes happier, industry wants to be there
  less), Free transit (trips from there by bus, tram or metro cost
  nothing: more riders, no fares), Tourism zone (shops do well, homes put
  up with the crowds). The districts view colours them and names them.
- **Map types** (on the welcome card): Valley (the classic map), Island
  (sea all round, the highway on a causeway), Lakes, Plains (dry, few
  forests) and Delta (a wide river). Picking one makes the map again
  behind the card.
- **Scenarios** (menu): five challenges, each a new city on its own map
  with its own difficulty and a goal before a year - Boom Town (Hard,
  20,000 people in 10 years), Island Resort (12,000 people and 2,000 air
  passengers a month in 15), Transit Utopia (15,000 people, a third of
  trips not by car, in 15), Green Valley (25,000 people on dry plains
  without ever a coal plant, in 20), Flood Plain (15,000 people by a wide
  river that floods three times as often, in 12). The goal stands above
  the dock; the city says when it's met or the time is up, and play goes
  on.
- **Achievements:** twenty for each city (the list is in the statistics
  panel, F4), announced as they're earned: population marks, transit
  riders, an airport with jets, a port, free-flowing traffic, clean air,
  a million in the bank, AAA credit, the wonders, weathering hazards,
  happiness, a deal kept, three universities, a fifth of the people on
  transit.
- **The City Herald:** a headline when the month has news - jams, an
  empty treasury, unhappiness, a recession or a boom, snow, floods,
  heat, free-flowing traffic, tourists, growth.
- **Trams** (Public transport, from City): drag Tram rails along avenues
  ($80 a tile; cars still use the road). Rails joined up make a line; a
  Tram Depot touching it runs it, with 5,000 riders a month per depot.
  People within 4 tiles of a line whose trip ends near the same line may
  ride: quicker than the bus, slower than the metro, held up by jams like
  the cars. The trams run on the rails, going straight on where they can.
- **Ferries** (Public transport, from Large City): a Ferry Pier (1x1,
  touching water) joins the other piers on the same water. People within
  6 tiles of a pier whose trip ends near another pier on that water may
  take the ferry - no traffic, 3,000 a month per pier. Ferries sail
  between the piers and wait at each.
- **Bus capacity:** each Bus Depot's buses carry 3,000 riders a month;
  when they're full, people drive. A growing city needs more depots.
- **Water Treatment** (Water, from City; 2x2, touching water, powered):
  takes the sewage of the pipes touching it like an outlet, but nothing
  downstream gets dirty. A sewage outlet can be upgraded to one from the
  inspector.
- **How people travel:** every trip weighs walking (short hops), the car
  (slower as jams grow), the bus (both ends near stops), the metro and the
  train, and takes the quickest, give or take. Trips not made by car take
  cars off the road; the statistics count metro and train riders, trips on
  foot and freight by rail.
- **Difficulty** (on the welcome card, and in the budget panel):
  Relaxed keeps the classic costs. Normal: services cost 1.5x and more
  as the city grows (about 2.4x at 35,000 people), roads cost $1 / $2 /
  $3 a tile a month, $1 more where traffic wears them. Hard: services 2x
  and growing twice as fast, roads 1.5x that. (A 68,000-people city that
  made $76k a month makes about $18k on Normal.)
- **Council requests:** once the advisor's goals are done, the council
  asks for what the city needs now - fewer jams, shorter commutes,
  happier people, water for every home, cleaner air, more bus riders, or
  growth - with a deadline and a reward of about three months' profit.
- **City issues** keep a steady order. Jams show as "Traffic jams" (no
  jumpy count); clicking opens the traffic view, marks the jammed roads
  and goes to the worst spot, then the next on each click.
- **Route viewer:** inspect a road to see how many cars are on it, where
  they come from (cyan) and where they go (green), with their routes
  marked yellow to red by how many share them.
- **Zone modes** (`G`): area, fill a block (click: every lot the roads
  around it reach, up to the roads) and along a road (drag along it: both
  sides, 3 deep). Lots no road reaches are marked while you drag, and the
  price tag says how many people or jobs the lots hold now and at level 5.

### Quality of life

- **Tour:** every new city offers a guided tour (Take the tour / No
  thanks) in which you build a practice village step by step:
  - moving the view (WASD, right-drag, the wheel);
  - drawing the first street from the highway;
  - zoning homes, shops and industry;
  - a coal plant by the creek, away from the homes (its smoke lowers land
    value), and a power line bridging the gap to the industry (power passes
    between buildings up to 2 tiles apart, never along roads);
  - a pump on the creek bank (water always comes from a pump, and pumps
    need power), a pipe under the street, and a sewage outlet far up the
    creek from the pump with a pipe to it;
  - speeding up time and reading demand;
  - a fire station, clinic, school, landfill and park, all on the street;
  - an info view, the inspector and the budget.

  Each step leads the way: first the dock button (the rest dimmed), then the
  item in its menu, then the place in the world (an outlined path with a
  start arrow, an area to drag over, or a spot to click). It moves on once
  you've done it. The village is planned from the map so that following
  the tour always gives a village with all the power, water and sewage it
  needs (the tour test checks this on every build). Money is free, all land is yours
  and everything is unlocked. Then meteors fall on the village, you pick
  the bulldozer and clear the rubble, and your real city begins on fresh
  land with the real budget and date. The practice village is never saved.
  Skip tour starts the real game at any point; Help (F1) → Take the tour
  replays it.
- **Several cities:** Save and Load (menu, F9) show seven city slots plus
  the autosave as cards, each with a picture of the city, the date,
  population and money. The latest save is marked; overwriting a city asks
  for a second click. F5 quick-saves to the city you're playing. When a
  save exists, the game opens on the Load screen (with New city). Saves
  also remember where you were looking. Saves carry over to new versions of the game: the file
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
| `F5` / `F9` | quick save / load screen |
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
| `src/saves.asm` | save slots with pictures, the Save / Load screens |
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
cityssembly --tourbot FRAMES out.bmp [seed]        # play the tour with real input, following its
                                                   # highlights; prints each step (CI runs it)
cityssembly --play script.txt [--beta]             # a scripted player: keys, clicks and drags on
                                                   # tiles, button presses by label, screenshots
                                                   # (commands in src/script.asm)
python3 tools/bench/gen.py                         # test-city scripts (mid ~10k, big ~55k) for
                                                   # --play; CS_BENCH=1 prints the frame profile
```
