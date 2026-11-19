class_name ValleyTerrain
extends RefCounted
## The valley's shape: about 2 km wide and 4 km long (north is -z), ringed by
## mountains, split into the 10 regions of the Valley Regions sheet (map_x,
## map_z = each region's center). Your camp is at the south end, Count
## Fuckula's region at the north end. Each region's biome sets its ground color,
## hills and plants; the edges blend. The seed adds small terrain variation
## (DECISIONS 17).
##
## Pure logic, no nodes: the same seed always gives the same valley, and the
## tests can check heights and positions without building a scene.

## How much bigger the valley is than its first 2 x 4 km layout: 1.14 per side =
## 30% more area (user, 2026-10-29). Region centers (sheet map_x, map_z) and the
## river and bridge positions below are in the first layout's meters, times SCALE.
const SCALE := 1.14
## Half the valley's width (x) and length (z), in meters, up to the walkable edge.
const HALF_W := 1000.0 * SCALE
const HALF_L := 2000.0 * SCALE
## The terrain mesh reaches this far past the edge (the mountains).
const MARGIN := 70.0
## Shape of the valley: a rounded rectangle. `shape_q` is 0 at the center and 1
## at the walkable edge; mountains start at RIM_Q.
const ROUNDNESS := 4.0
const RIM_Q := 0.88
const EDGE_Q := 1.0
## Encounter spots and villages stay inside this.
const SAFE_Q := 0.84
## Below this height is water (swamps, ponds).
const WATER_Y := -0.8
## How far region styles blend into each other (meters).
const BLEND := 150.0
## Encounter spots per region, and their distance from the region center.
const SLOTS := 5
const SLOT_DIST := 90.0
## Flat ground for fights and villages: fully flat inside, blending out to the outer radius.
const SITE_FLAT := Vector2(20.0, 48.0)
const VILLAGE_FLAT := Vector2(76.0, 104.0)
## Flat circles are looked up in a grid of this cell size (much faster than checking all).
const FLAT_CELL := 60.0

## Look of each biome (Valley Regions "biome" column).
##   color: ground  ·  height/hills: base height and hill size  ·  trees/rocks/bushes/grass: plant density 0-1
##   turf: which grass set (ValleyWorld.TURF; none = the generated tufts) ·
##   tree: which tree list (ValleyWorld.TREES)  ·  terrace: 0-1, how much the ground steps in ledges  ·  tint: color multiplied into the plants
##   cover: how much of the ground the grass covers (0-1); from ValleyWorld.CARPET_COVER up, the user's grass tile carpets it near you (GrassField)
const BIOMES := {
	"River meadows and farmland": {"turf": "meadow", "color": Color(0.42, 0.6, 0.28), "height": 0.0, "hills": 2.5, "trees": 0.22, "rocks": 0.08, "bushes": 0.22, "grass": 0.55, "tree": "leafy", "tint": Color(1, 1, 1), "cover": 0.85},
	"Rocky hills, pine and old mines": {"turf": "meadow", "color": Color(0.46, 0.5, 0.38), "height": 7.0, "hills": 10.0, "trees": 0.42, "rocks": 0.28, "bushes": 0.15, "grass": 0.3, "tree": "pine", "terrace": 0.6, "tint": Color(0.9, 0.95, 0.9), "cover": 0.5},
	"Ancient forest": {"giants": 0.4, "turf": "meadow", "color": Color(0.24, 0.4, 0.19), "height": 2.0, "hills": 4.0, "trees": 0.75, "rocks": 0.05, "bushes": 0.3, "grass": 0.3, "tree": "ancient", "tint": Color(0.8, 0.95, 0.8), "cover": 0.6},
	"Open grassland": {"turf": "meadow", "color": Color(0.63, 0.66, 0.32), "height": 1.0, "hills": 3.5, "trees": 0.08, "rocks": 0.1, "bushes": 0.12, "grass": 0.8, "tree": "savanna", "tint": Color(1.1, 1.05, 0.75), "cover": 1.0},
	"Steaming jungle": {"turf": "meadow", "color": Color(0.16, 0.42, 0.17), "height": 1.0, "hills": 5.0, "trees": 0.95, "rocks": 0.05, "bushes": 0.6, "grass": 0.45, "tree": "jungle", "tint": Color(0.72, 1.0, 0.72), "cover": 0.8},
	"Swamp and river delta": {"turf": "meadow", "color": Color(0.3, 0.37, 0.23), "height": -1.4, "hills": 1.5, "trees": 0.38, "rocks": 0.06, "bushes": 0.4, "grass": 0.55, "tree": "swamp", "tint": Color(0.75, 0.8, 0.6), "cover": 0.7},
	"Desert canyons": {"color": Color(0.72, 0.42, 0.26), "height": 5.0, "hills": 13.0, "trees": 0.05, "rocks": 0.4, "bushes": 0.12, "grass": 0.08, "tree": "desert", "terrace": 1.0, "tint": Color(1.0, 0.6, 0.45), "cover": 0.12},
	"High cliffs and peaks": {"color": Color(0.55, 0.55, 0.5), "height": 16.0, "hills": 12.0, "trees": 0.15, "rocks": 0.35, "bushes": 0.1, "grass": 0.2, "tree": "alpine", "terrace": 1.0, "tint": Color(0.9, 0.9, 0.95), "cover": 0.35},
	"Volcanic ashlands": {"color": Color(0.17, 0.15, 0.15), "height": 3.0, "hills": 6.0, "trees": 0.08, "rocks": 0.4, "bushes": 0.03, "grass": 0.0, "tree": "charred", "tint": Color(0.3, 0.27, 0.27)},
	"Snowfields and glaciers": {"color": Color(1.0, 1.0, 1.0), "white": true, "height": 14.0, "hills": 9.0, "trees": 0.25, "rocks": 0.18, "bushes": 0.0, "grass": 0.0, "tree": "snow", "terrace": 0.4, "tint": Color(0.85, 0.92, 1.1)},
	"Collapsed city and tunnels": {"color": Color(0.5, 0.47, 0.41), "height": 0.5, "hills": 2.5, "trees": 0.14, "rocks": 0.45, "bushes": 0.2, "grass": 0.25, "tree": "bare", "tint": Color(0.85, 0.85, 0.8), "cover": 0.4},
}
const DEFAULT_BIOME := "River meadows and farmland"
## Rivers. Each is drawn along one axis: "x" rivers cross the valley west to
## east (their path is a z for every x), "z" rivers run its length (an x for
## every z). The two crossing rivers sit between the region rows, so the way
## north crosses both; the main river runs the whole valley south to north and
## branches off into lakes (BRANCHES). wiggle: how much it meanders (m) ·
## width: bed width range (m); the banks add RIVER_BANK on each side ·
## rapids: fast black water only the Frogfolk can swim (everyone else takes a
## bridge or jumps a mount over a narrow stretch) · bridges: where they stand
## (x for "x" rivers, z for "z" rivers).
const RIVERS := [
	{"name": "River", "axis": "x", "at": 720.0, "wiggle": 40.0, "width": Vector2(18.0, 34.0), "rapids": false, "bridges": [-640.0, -300.0, 300.0, 640.0]},
	{"name": "Rapids", "axis": "x", "at": -750.0, "wiggle": 34.0, "width": Vector2(16.0, 30.0), "rapids": true, "bridges": [-640.0, -300.0, 300.0, 640.0]},
	{"name": "Main River", "axis": "z", "wiggle": 30.0, "width": Vector2(26.0, 44.0), "rapids": false, "bridges": [-1450.0, -1050.0, -350.0, 250.0, 1050.0, 1450.0],
		# Its course (x at each z), clear of the villages: west of Count Fuckula's
		# region, through the middle of the valley, east of your camp.
		"course": [Vector2(-250, -2150), Vector2(-250, -1650), Vector2(-90, -1200), Vector2(30, -500), Vector2(0, 0), Vector2(-40, 500), Vector2(90, 1100), Vector2(250, 1650), Vector2(250, 2150)]},
]
## Side rivers that split off the main river and end in a lake each.
const BRANCHES := 4
const BRANCH_WIDTH := Vector2(10.0, 16.0)
const BRANCH_LENGTH := Vector2(320.0, 540.0)
## Swimming across: everyone, except in rapids and deep lakes (this race only).
const SWIMMER_RACE := "frog"
const RIVER_BED := WATER_Y - 4.0
## Banks rise at least over RIVER_BANK meters, and never steeper than 1 m up per
## BANK_SLOPE m out (5.0 = about 11 degrees on average; 3.0 until 2026-10-29).
const RIVER_BANK := 20.0
const BANK_SLOPE := 5.0
## More natural water (user, 2026-10-29): each run moves the crossing rivers up to
## RIVER_SHIFT m, rivers meander along seeded noise as well as the slow sway, and
## lake shores are irregular (up to LAKE_WOBBLE of the radius in or out) and a bit oval.
const RIVER_SHIFT := 60.0
const RIVER_NOISE := 1.4
const LAKE_WOBBLE := 0.22
const RIVER_STEP := 8.0
const BRIDGE_WIDTH := 5.0
## Big rolling hills across the whole valley (meters, only ever raises the ground).
const MACRO_HILLS := 32.0
## Height of one ledge where the ground steps (terrace biomes).
const TERRACE_STEP := 4.0
## Lakes per valley placed by the seed in open ground (on top of the lakes at the
## end of each branch); the first DEEP_LAKES are deep lakes only the Frogfolk can swim.
const LAKES := 10  # 8 before the valley grew 30% (2026-10-29)
const DEEP_LAKES := 3
const LAKE_RADIUS := Vector2(24.0, 44.0)
const FED_LAKE_RADIUS := Vector2(40.0, 62.0)
const LAKE_BANK := 20.0
const LAKE_DEPTH := 5.0
## Riverside hamlets: small fishing settlements along the rivers and lakes.
const HAMLETS := 10  # 8 before the valley grew 30% (2026-10-29)
const HAMLET_FLAT := Vector2(22.0, 46.0)
const HAMLET_SPACING := 380.0

## Ground under Count Fuckula's control turns this color.
const CORRUPTED := Color(0.24, 0.11, 0.3)

## [{id, pos: Vector2, style: Dictionary}]
var regions: Array = []
## Flattened circles: [{pos: Vector2, y: float, flat: Vector2}]
var flats: Array = []
## [{name, axis: "x"/"z", a0: float, c: PackedFloat32Array, width: PackedFloat32Array,
##   rapids, branch: bool}]: c[i] is the river's middle (z for "x" rivers, x for "z"
##   rivers) at a0 + i * RIVER_STEP along its axis.
var rivers: Array = []
## [{a: Vector2, b: Vector2, river: int}]: bridge ends, on dry ground past both banks.
var bridges: Array = []
## [{pos: Vector2, radius: float, surface: float, deep: bool, fed: bool}]; fed = a branch ends in it.
var lakes: Array = []
## [{top: Vector3, bottom: Vector3, river: int, dir: Vector2}]: where rivers pour out of the mountains.
var waterfalls: Array = []
## [{pos: Vector2, to_water: Vector2, name: String, region: String}]
var hamlets: Array = []
## Big landmarks, one of each per run (user, 2026-10-30): model -> [name, flat (inner,
## outer radius)]. Placed on dry, level-able ground clear of everything else.
const LANDMARKS := {"landmark_mammoth_graveyard": ["Mammoth Graveyard", Vector2(26.0, 52.0)],
	"landmark_abandoned_quarry": ["Abandoned Quarry", Vector2(30.0, 58.0)],
	"landmark_castle": ["Castle", Vector2(40.0, 72.0)]}
const LANDMARK_COPIES := 3
## A giant lake (user, 2026-11-07) with an island in the middle holding a castle (a dungeon: its
## band, wall guards and a boss). Everyone can swim out. Radius tried from the first down to the second.
const GIANT_LAKE := Vector2(230.0, 150.0)
const GIANT_ISLAND := "landmark_castle"
const ISLAND_RISE := 2.5  ## the island's top above the water (m)
const ISLAND_SLOPE := 14.0  ## its shore runs down to the lake bed over this (m)
## Its shore wobbles this much of its radius in and out (user, 2026-11-08: a random shape, not a circle).
const GIANT_WOBBLE := 0.42
## Floating islands (user, 2026-11-07): rock islands hanging in the sky, each holding a landmark
## (and its war band), reached by a spiral of floating stepping stones; glide back down.
const SKY_ISLANDS := ["landmark_mammoth_graveyard", "landmark_abandoned_quarry"]
const SKY_CLEAR := 22.0  ## an island's top stands at least this far over the ground under it
const STEP_RISE := 1.2  ## each stepping stone this much higher than the last (a jump clears ~2 m)
const STEP_GAP := 3.4  ## stone centers apart along the spiral (m); a stone is STEP_RADIUS wide
const STEP_RADIUS := 1.3
## Places with a chest (LootSpots), several in every region: kind -> [how many, sign, flat ground, chest's spot on the model].
const STRUCTURES := {
	"cave": [2, "Cave", Vector2(27.0, 46.0), Vector3(0.0, 0.1, -16.0)],
	"tower": [2, "Old Tower", Vector2(16.0, 34.0), Vector3(0.0, 16.3, 0.0)],
}
const TOWER_VARIANTS := ["plain", "mirror", "hollow"]
## Whose rock and climate a cave or tower is built in (make_landmarks.py REGION_ART).
const STRUCTURE_ART := {"River meadows and farmland": "meadow", "Rocky hills, pine and old mines": "highland", "Ancient forest": "forest",
	"Open grassland": "steppe", "Swamp and river delta": "swamp", "Desert canyons": "canyon", "High cliffs and peaks": "cliff",
	"Volcanic ashlands": "ash", "Snowfields and glaciers": "snow", "Collapsed city and tunnels": "ruin", "Steaming jungle": "jungle"}
## [{model, name, pos: Vector2, angle}; caves and towers also: kind, chest: Vector3; on a floating island: y]
var landmarks: Array = []
## [{pos: Vector2, radius: float (flat top), top: float, steps: [Vector3 stone tops]}]
var sky_islands: Array = []
var _macro := FastNoiseLite.new()
var _flat_grid := {}  # Vector2i cell -> [flat indexes]
## Caves go a little underground (user, 2026-11-08): the floor sinks from the mouth to CAVE_DEPTH m
## in the chamber (make_landmarks.py builds the walls down to match), less where that would flood.
const CAVE_DEPTH := 3.5
var _caves: Array = []  ## [{pos: Vector2, angle, depth}]
var _cave_grid := {}  ## Vector2i cell -> [cave indexes]
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()


func _init(seed_value: int) -> void:
	_noise.seed = seed_value
	_noise.frequency = 0.008
	_noise.fractal_octaves = 3
	_detail.seed = seed_value + 1
	_detail.frequency = 0.08
	_ridge.seed = seed_value + 2
	_ridge.frequency = 0.015
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_macro.seed = seed_value + 4
	_macro.frequency = 0.0035
	_macro.fractal_octaves = 2
	for r in GameData.rows("valley_regions"):
		regions.append({"id": r.region_id, "pos": region_center(r.region_id),
			"style": BIOMES.get(GameData.text(r, "biome"), BIOMES[DEFAULT_BIOME])})
	_build_rivers(seed_value)
	# Villages at region centers, encounter spots around them: level ground for both.
	for r in regions:
		_add_flat(r.pos, VILLAGE_FLAT)
		for i in SLOTS:
			_add_flat(slot_point(r.id, i), SITE_FLAT)
	_build_branches(seed_value)
	_build_giant_lake(seed_value)
	_build_lakes(seed_value)
	_build_hamlets()
	_build_bridges()
	_build_lake_bridge()
	_build_landmarks(seed_value)
	_build_structures(seed_value)
	_build_sky_islands(seed_value)
	_build_waterfalls()


## 0 at the valley's center, 1 at its walkable edge (a rounded rectangle).
static func shape_q(x: float, z: float) -> float:
	return pow(pow(absf(x) / HALF_W, ROUNDNESS) + pow(absf(z) / HALF_L, ROUNDNESS), 1.0 / ROUNDNESS)


## A point on the edge line where shape_q == q, at angle `a` (for walls and the map).
static func edge_point(a: float, q := EDGE_Q) -> Vector2:
	var c := cos(a)
	var s := sin(a)
	return Vector2(signf(c) * pow(absf(c), 2.0 / ROUNDNESS) * HALF_W, signf(s) * pow(absf(s), 2.0 / ROUNDNESS) * HALF_L) * q


## Pulls a point back inside the safe area if it's too close to the mountains.
static func clamp_inside(p: Vector2) -> Vector2:
	var q := shape_q(p.x, p.y)
	return p * (SAFE_Q / q) if q > SAFE_Q else p


## A region's center this run (ValleyLayout: your home region swaps to the south end).
static func region_center(region_id: String) -> Vector2:
	var r := GameData.row("valley_regions", ValleyLayout.slot(region_id))
	return Vector2(GameData.num(r, "map_x"), GameData.num(r, "map_z")) * SCALE


## Where encounter spot `slot` of a region is (a ring around the region center).
static func slot_point(region_id: String, slot: int) -> Vector2:
	var c := region_center(region_id)
	var turn := float(hash(region_id) % 360) / 360.0 * TAU
	return clamp_inside(c + Vector2.from_angle(turn + slot * TAU / SLOTS) * SLOT_DIST)


## Gives every encounter without a spot the first free spot in its region.
## Stored in the run state, so spots stay put across saves.
static func assign_slots(state: RunState) -> void:
	var used := {}
	for id in state.encounters:
		var e: Dictionary = state.encounters[id]
		if e.has("slot"):
			used[e.region + ":" + str(int(e.slot))] = true
	var ids: Array = state.encounters.keys()
	ids.sort()
	for id in ids:
		var e: Dictionary = state.encounters[id]
		if e.has("slot"):
			continue
		for i in SLOTS:
			if not used.has(e.region + ":" + str(i)):
				e["slot"] = i
				used[e.region + ":" + str(i)] = true
				break
		if not e.has("slot"):
			e["slot"] = 0  # more encounters than spots: share one


static func site_point(state: RunState, encounter_id: String) -> Vector2:
	var e: Dictionary = state.encounters.get(encounter_id, {})
	if e.has("pos"):  # a camp out in the wild (place_camps)
		return Vector2(e.pos[0], e.pos[1])
	return slot_point(e.get("region", ""), int(e.get("slot", 0)))


## Camps (tm_clear_camp) sit out in the wild, at least CAMP_CLEAR from every tribe's
## village (user, 2026-10-30), on dry ground, apart from each other. Stored in the
## run state ("pos"), so they stay put across saves.
const CAMP_CLEAR := 500.0
const CAMP_APART := 250.0


func place_camps(state: RunState) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = state.seed + 77
	var placed: Array = landmarks.filter(func(l): return not l.has("chest")).map(func(l): return l.pos)
	var small: Array = landmarks.filter(func(l): return l.has("chest")).map(func(l): return l.pos)
	for id in state.encounters:
		if state.encounters[id].has("pos"):
			placed.append(site_point(state, id))
	var ids: Array = state.encounters.keys().filter(func(i): return state.encounters[i].def == "tm_clear_camp" and not state.encounters[i].has("pos"))
	ids.sort()
	for id in ids:
		var best := Vector2.INF
		var best_room := -1.0
		for attempt in 600:
			var p := Vector2(rng.randf_range(-HALF_W, HALF_W), rng.randf_range(-HALF_L, HALF_L))
			if shape_q(p.x, p.y) > SAFE_Q or near_bridge(p.x, p.y, 30.0):
				continue
			if water_surface(p.x, p.y) != -INF or water_surface(p.x + 15.0, p.y) != -INF or water_surface(p.x, p.y + 15.0) != -INF:
				continue
			if placed.any(func(q): return q.distance_to(p) < CAMP_APART) or small.any(func(q): return q.distance_to(p) < 70.0):
				continue
			var room := INF  # distance to the nearest village
			for r in regions:
				room = minf(room, (r.pos as Vector2).distance_to(p))
			if room >= CAMP_CLEAR:
				best = p
				break
			if room > best_room:
				best_room = room
				best = p
		if best != Vector2.INF:
			state.encounters[id]["pos"] = [snappedf(best.x, 0.1), snappedf(best.y, 0.1)]
			placed.append(best)


## The region a point belongs to (nearest region center).
func region_at(x: float, z: float) -> String:
	var best := ""
	var best_d := INF
	for r in regions:
		var d: float = r.pos.distance_squared_to(Vector2(x, z))
		if d < best_d:
			best_d = d
			best = r.id
	return best


## Ground height at a point. `ws` (from weights_at) can be passed in to save work
## when the same point also needs its color.
func height(x: float, z: float, ws: Array = []) -> float:
	var h := _raw_height(x, z, ws)
	var p := Vector2(x, z)
	# Where flat spots overlap, the one that holds this point most firmly wins, so
	# a neighbor's slope can't tilt a spot's flat middle.
	var best := 0.0
	var best_y := 0.0
	for i in _flat_grid.get(Vector2i(floori(x / FLAT_CELL), floori(z / FLAT_CELL)), []):
		var f: Dictionary = flats[i]
		var d: float = p.distance_to(f.pos)
		if d < f.flat.y:
			var w := 1.0 - smoothstep(f.flat.x, f.flat.y, d)
			if w > best:
				best = w
				best_y = f.y
	if best > 0.0:
		h = lerpf(h, best_y, best)
	return h - cave_dip(x, z)


func _add_cave(p: Vector2, angle: float, floor_y: float) -> void:
	_caves.append({"pos": p, "angle": angle, "depth": clampf(floor_y - (WATER_Y + 0.8), 0.0, CAVE_DEPTH)})
	var cell := Vector2i(floori(p.x / FLAT_CELL), floori(p.y / FLAT_CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := cell + Vector2i(dx, dz)
			if not _cave_grid.has(k):
				_cave_grid[k] = []
			_cave_grid[k].append(_caves.size() - 1)


## How far a cave has sunk the floor at (x, z). In the cave's frame (LootSpots.CAVE_POSTS: x across,
## z from the mouth at +18 to the chamber around z = -10): none at the mouth, all of it 4 m in and in
## the chamber, easing out under the walls.
func cave_dip(x: float, z: float) -> float:
	var dip := 0.0
	for i in _cave_grid.get(Vector2i(floori(x / FLAT_CELL), floori(z / FLAT_CELL)), []):
		var c: Dictionary = _caves[i]
		var local := Vector3(x - c.pos.x, 0.0, z - c.pos.y).rotated(Vector3.UP, -c.angle)
		var tunnel := (1.0 - smoothstep(4.5, 6.5, absf(local.x))) * smoothstep(16.0, 4.0, local.z) * (1.0 - smoothstep(0.0, 4.0, -local.z - 20.0))
		var chamber := 1.0 - smoothstep(10.0, 12.5, Vector2(local.x, local.z + 10.0).length())
		dip = maxf(dip, c.depth * maxf(tunnel, chamber))
	return dip


## Ground color at a point of height `y`; regions listed in `corrupted` are tinted by the Void.
func color(x: float, z: float, y: float, corrupted: Array = [], ws: Array = []) -> Color:
	var c := Color(0, 0, 0)
	var grass := 0.0  # how much of the user's grass picture shows here: alpha, read by ground.gdshader
	for w in (ws if not ws.is_empty() else _weights(x, z)):
		var r: Dictionary = regions[int(w.x)]
		var rc: Color = r.style.color
		if r.id in corrupted:
			rc = rc.lerp(CORRUPTED, 0.75)
		elif float(r.style.get("cover", 0.0)) >= ValleyWorld.CARPET_COVER:
			grass += w.y
		c += rc * w.y
	var rim := smoothstep(RIM_Q - 0.02, EDGE_Q + 0.04, shape_q(x, z))
	c = c.lerp(Color(0.42, 0.4, 0.38), rim)
	var snow := smoothstep(45.0, 65.0, y) if y > 45.0 else 0.0
	c = c.lerp(Color(0.95, 0.96, 0.98), snow)  # snowy peaks
	# Ground variation; white ground (snow, user 2026-10-30) barely varies so it stays white.
	var vary := 0.08 * (1.0 - _white_weight(ws if not ws.is_empty() else _weights(x, z)) * 0.8)
	c *= 1.0 - vary + _detail.get_noise_2d(x * 3.0, z * 3.0) * vary
	c.a = grass * (1.0 - rim) * (1.0 - snow)
	return c


func _white_weight(ws: Array) -> float:
	var white := 0.0
	for w in ws:
		if regions[int(w.x)].style.get("white", false):
			white += w.y
	return white


## Blended plant densities at a point, all at once: {trees, rocks, bushes, grass}.
func style_values(x: float, z: float) -> Dictionary:
	var out := {"trees": 0.0, "rocks": 0.0, "bushes": 0.0, "grass": 0.0}
	for w in _weights(x, z):
		var style: Dictionary = regions[int(w.x)].style
		for key in out:
			out[key] += float(style.get(key, 0.0)) * w.y
	return out


## The style of the region a point is in (for plant models and tints).
func style_at(x: float, z: float) -> Dictionary:
	var id := region_at(x, z)
	for r in regions:
		if r.id == id:
			return r.style
	return BIOMES[DEFAULT_BIOME]


func _raw_height(x: float, z: float, ws: Array = []) -> float:
	var base := 0.0
	var hills := 0.0
	var terrace := 0.0
	for w in (ws if not ws.is_empty() else _weights(x, z)):
		base += regions[int(w.x)].style.height * w.y
		hills += regions[int(w.x)].style.hills * w.y
		terrace += float(regions[int(w.x)].style.get("terrace", 0.0)) * w.y
	var h := base + _noise.get_noise_2d(x, z) * hills + (_macro.get_noise_2d(x, z) * 0.5 + 0.5) * MACRO_HILLS
	if terrace > 0.01 and h > 1.0:
		# Ledges: flat steps with steep (still walkable-ish) risers between them.
		var f := h / TERRACE_STEP
		var stepped := (floorf(f) + smoothstep(0.55, 1.0, f - floorf(f))) * TERRACE_STEP
		h = lerpf(h, stepped, terrace)
	h += _detail.get_noise_2d(x, z) * 0.35
	var t := smoothstep(RIM_Q, EDGE_Q + MARGIN / HALF_W, shape_q(x, z))
	h += pow(t, 1.5) * 90.0 + t * absf(_ridge.get_noise_2d(x, z)) * 35.0
	# Rivers cut through everything up to the valley's edge, so you can't walk around
	# them; just past the edge they end in a cliff (where the waterfalls pour out).
	# Banks widen where the ground is high, so they stay climbable.
	var past_edge := smoothstep(EDGE_Q + 0.005, EDGE_Q + 0.05, shape_q(x, z))
	var bank := maxf(RIVER_BANK, (h - RIVER_BED) * BANK_SLOPE)
	for river in rivers:
		var info := _river_at(river, x, z)
		var half := info.y * 0.5
		if info.x < half + bank:
			h = lerpf(h, RIVER_BED, (1.0 - smoothstep(half, half + bank, info.x)) * (1.0 - past_edge))
	for lake in lakes:
		var to: Vector2 = Vector2(x, z) - lake.pos
		var dl: float = to.length()
		if dl < lake_reach(lake) + LAKE_BANK:
			var r := shore_radius(lake, to.angle())
			h = lerpf(h, minf(h, lake.surface - LAKE_DEPTH), 1.0 - smoothstep(r * 0.6, r + LAKE_BANK, dl))
			if lake.has("island"):  # the giant lake's island: flat on top, shores down to the bed
				h = maxf(h, lerpf(lake.surface + ISLAND_RISE, lake.surface - LAKE_DEPTH, smoothstep(lake.island, lake.island + ISLAND_SLOPE, dl)))
	return h


## A lake's shore distance in direction `angle`: wobbly and a little oval, the
## same every time for the same seed (each lake keeps its own random phases).
static func shore_radius(lake: Dictionary, angle: float) -> float:
	var ph: Array = lake.get("shape", [])
	if ph.size() < 4:
		return lake.radius
	var w: float = 0.45 * sin(2.0 * angle + ph[0]) + 0.3 * sin(3.0 * angle + ph[1]) + 0.25 * sin(5.0 * angle + ph[2])
	return lake.radius * (1.0 + lake.get("wobble", LAKE_WOBBLE) * w * ph[3])


## How far a lake's shore can reach from its middle at most.
static func lake_reach(lake: Dictionary) -> float:
	return lake.radius * (1.0 + lake.get("wobble", LAKE_WOBBLE))


# ---------------------------------------------------------------- rivers

func _build_rivers(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 3
	for def in RIVERS:
		var phase := rng.randf() * TAU
		var phase2 := rng.randf() * TAU
		var shift := rng.randf_range(-RIVER_SHIFT, RIVER_SHIFT) if def.axis == "x" else 0.0
		var bend := FastNoiseLite.new()  # seeded meanders on top of the slow sway
		bend.seed = rng.randi()
		bend.frequency = 0.006
		bend.fractal_octaves = 3
		var girth := FastNoiseLite.new()
		girth.seed = rng.randi()
		girth.frequency = 0.012
		var half_len := (HALF_W if def.axis == "x" else HALF_L) + MARGIN + 40.0
		var count := int(half_len * 2.0 / RIVER_STEP) + 1
		var cs := PackedFloat32Array()
		var ws := PackedFloat32Array()
		for i in count:
			var t := -half_len + i * RIVER_STEP
			var base: float = def.at * SCALE + shift if def.axis == "x" else _along_course(def.course, t / SCALE) * SCALE
			cs.append(base + def.wiggle * sin(t * 0.004 + phase) + def.wiggle * 0.4 * sin(t * 0.0115 + phase2)
				+ def.wiggle * RIVER_NOISE * bend.get_noise_1d(t))
			var w := 0.5 + 0.35 * sin(t * 0.0055 + phase2 * 1.7) + 0.5 * girth.get_noise_1d(t)
			ws.append(lerpf(def.width.x, def.width.y, clampf(w, 0.0, 1.0)))
		rivers.append({"name": def.name, "axis": def.axis, "a0": -half_len, "c": cs, "width": ws, "rapids": def.rapids, "branch": false})


## Smooth path through a list of (x, z) course points: the x at `z`.
static func _along_course(course: Array, z: float) -> float:
	var i := 0
	while i < course.size() - 2 and z > course[i + 1].y:
		i += 1
	var a: Vector2 = course[maxi(i - 1, 0)]
	var b: Vector2 = course[i]
	var c: Vector2 = course[i + 1]
	var d: Vector2 = course[mini(i + 2, course.size() - 1)]
	var t := clampf((z - b.y) / (c.y - b.y), 0.0, 1.0)
	# Catmull-Rom: passes through every course point with no corners.
	return 0.5 * (2.0 * b.x + (c.x - a.x) * t + (2.0 * a.x - 5.0 * b.x + 4.0 * c.x - d.x) * t * t + (3.0 * b.x - a.x - 3.0 * c.x + d.x) * t * t * t)


## Side rivers: each leaves the main river and winds east or west into a lake of its own.
func _build_branches(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 6
	var main: Dictionary = rivers[_main_index()]
	var used_z: Array = []
	for attempt in 400:
		if used_z.size() >= BRANCHES:
			break
		var side := -1.0 if used_z.size() % 2 == 0 else 1.0
		var z0 := rng.randf_range(-HALF_L * 0.75, HALF_L * 0.75)
		if used_z.any(func(u): return absf(u - z0) < 420.0):
			continue
		var x0 := _center(main, z0)
		var lake_r := rng.randf_range(FED_LAKE_RADIUS.x, FED_LAKE_RADIUS.y)
		var end := Vector2(x0 + side * rng.randf_range(BRANCH_LENGTH.x, BRANCH_LENGTH.y), z0 + rng.randf_range(-220.0, 220.0))
		if shape_q(end.x, end.y) > 0.76 or not _lake_fits(end, lake_r):
			continue
		var branch := _make_branch(rng, Vector2(x0, z0), end)
		if not _branch_clear(branch):
			continue
		rivers.append(branch)
		lakes.append({"pos": end, "radius": lake_r, "surface": WATER_Y, "deep": false, "fed": true, "shape": _lake_shape(rng)})
		used_z.append(z0)


func _make_branch(rng: RandomNumberGenerator, from: Vector2, to: Vector2) -> Dictionary:
	var phase := rng.randf() * TAU
	var x_lo := minf(from.x, to.x)
	var count := int(absf(to.x - from.x) / RIVER_STEP) + 1
	var cs := PackedFloat32Array()
	var ws := PackedFloat32Array()
	var w0 := rng.randf_range(BRANCH_WIDTH.x, BRANCH_WIDTH.y)
	for i in count:
		var x := x_lo + i * RIVER_STEP
		var t := (x - from.x) / (to.x - from.x)  # 0 at the main river, 1 at the lake
		cs.append(from.y + (to.y - from.y) * smoothstep(0.0, 1.0, t) + 22.0 * sin(t * PI) * sin(t * 7.0 + phase))
		ws.append(w0 * lerpf(1.0, 0.75, t))
	return {"name": "Branch", "axis": "x", "a0": x_lo, "c": cs, "width": ws, "rapids": false, "branch": true, "from": from}


## A branch must stay clear of villages, encounter spots and the crossing rivers.
func _branch_clear(branch: Dictionary) -> bool:
	for i in range(0, branch.c.size(), 3):
		var p := Vector2(branch.a0 + i * RIVER_STEP, branch.c[i])
		for f in flats:
			if p.distance_to(f.pos) < f.flat.y + branch.width[i] * 0.5 + RIVER_BANK:
				return false
		for r in rivers:
			if r.axis == "x" and _river_at(r, p.x, p.y).x < 120.0:
				return false
	return true


func _main_index() -> int:
	for i in RIVERS.size():
		if RIVERS[i].axis == "z":
			return i
	return 0


## A river's middle at `along` (x for "x" rivers, z for "z" rivers).
func _center(river: Dictionary, along: float) -> float:
	var f: float = clampf((along - river.a0) / RIVER_STEP, 0.0, river.c.size() - 1.001)
	var i := floori(f)
	return lerpf(river.c[i], river.c[i + 1], f - i)


## The middle of river `index` at `along` (x for rivers that cross, z for the main river).
func river_center(index: int, along: float) -> float:
	return _center(rivers[index], along)


## Vector3(distance from the river's middle, bed width there, which side: -1 or 1).
## Past either end of a river the distance is measured to that end, so the ends are round.
func _river_at(river: Dictionary, x: float, z: float) -> Vector3:
	var along := x if river.axis == "x" else z
	var across := z if river.axis == "x" else x
	var n: int = river.c.size()
	var f: float = (along - river.a0) / RIVER_STEP
	var over := 0.0
	if f < 0.0:
		over = -f * RIVER_STEP
		f = 0.0
	elif f > n - 1:
		over = (f - (n - 1)) * RIVER_STEP
		f = n - 1
	var i := clampi(floori(f), 0, n - 2)
	var k := clampf(f - i, 0.0, 1.0)
	var c := lerpf(river.c[i], river.c[i + 1], k)
	var slope: float = (river.c[i + 1] - river.c[i]) / RIVER_STEP
	var lateral := (across - c) / sqrt(1.0 + slope * slope)
	return Vector3(sqrt(lateral * lateral + over * over), lerpf(river.width[i], river.width[i + 1], k), signf(across - c) if across != c else 1.0)


## Point i of a river, and the direction it flows there.
func _river_point(river: Dictionary, i: int) -> Vector2:
	var along: float = river.a0 + i * RIVER_STEP
	return Vector2(along, river.c[i]) if river.axis == "x" else Vector2(river.c[i], along)


func _river_dir(river: Dictionary, i: int) -> Vector2:
	var j := clampi(i, 0, river.c.size() - 2)
	return (_river_point(river, j + 1) - _river_point(river, j)).normalized()


## Bridges where each river's `bridges` list says (crossing rivers, the main river),
## plus one across the middle of every branch.
func _build_bridges() -> void:
	for i in rivers.size():
		var river: Dictionary = rivers[i]
		var spots: Array = []
		if river.branch:
			spots = [river.a0 + (river.c.size() - 1) * RIVER_STEP * 0.5]
		else:
			# Not where a branch splits off (the water is wide there).
			spots = RIVERS[i].bridges.map(func(a): return a * SCALE).filter(func(a): return not rivers.any(func(r): return r.branch and absf((r.from.y if river.axis == "z" else r.from.x) - a) < 90.0))
		for along in spots:
			var k := clampi(roundi((along - river.a0) / RIVER_STEP), 1, river.c.size() - 2)
			var mid := _river_point(river, k)
			var across := _river_dir(river, k).orthogonal()
			var a := _dry_land(mid, -across)
			var b := _dry_land(mid, across)
			bridges.append({"a": a, "b": b, "river": i, "mid": (a + b) * 0.5, "reach": a.distance_to(b) * 0.5 + BRIDGE_WIDTH * 0.5})


## The giant lake's bridge (user, 2026-11-08): from the nearest shore out to the island, its
## war band along it (WorldEvents). In `bridges` with river -1 and lake true.
func _build_lake_bridge() -> void:
	for lake in lakes:
		if not lake.has("island"):
			continue
		var best := 0.0
		for k in 48:
			if shore_radius(lake, TAU * k / 48.0) < shore_radius(lake, best):
				best = TAU * k / 48.0
		var dir := Vector2.from_angle(best)
		var out := shore_radius(lake, best)
		while water_surface(lake.pos.x + dir.x * out, lake.pos.y + dir.y * out) != -INF and out < lake_reach(lake) + LAKE_BANK * 2.0:
			out += 2.0
		var a: Vector2 = lake.pos + dir * (out + 2.0)
		var b: Vector2 = lake.pos + dir * (float(lake.island) - 3.0)
		bridges.append({"a": a, "b": b, "river": -1, "lake": true, "mid": (a + b) * 0.5, "reach": a.distance_to(b) * 0.5 + BRIDGE_WIDTH * 0.5})


## Walks from a river's middle out to dry ground (a bridge end).
func _dry_land(mid: Vector2, dir: Vector2) -> Vector2:
	var d := 4.0
	while d < 300.0 and _raw_height(mid.x + dir.x * d, mid.y + dir.y * d) < WATER_Y + 1.0:
		d += 2.0
	return mid + dir * (d + 4.0)


# ---------------------------------------------------------------- lakes, waterfalls, swimming

func _build_lakes(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 5
	var placed := 0
	for attempt in 900:
		if placed >= LAKES:
			break
		var r := rng.randf_range(LAKE_RADIUS.x, LAKE_RADIUS.y)
		var p := Vector2(rng.randf_range(-HALF_W, HALF_W) * 0.8, rng.randf_range(-HALF_L, HALF_L) * 0.85)
		if shape_q(p.x, p.y) > 0.78 or not _lake_fits(p, r):
			continue
		# The surface sits just under the lowest point of the rim, so the water stays in.
		var rim := INF
		for k in 12:
			var q := p + Vector2.from_angle(TAU * k / 12.0) * (r + LAKE_BANK * 0.5)
			rim = minf(rim, _raw_height(q.x, q.y))
		lakes.append({"pos": p, "radius": r, "surface": maxf(rim - 0.6, WATER_Y), "deep": placed < DEEP_LAKES, "fed": false, "shape": _lake_shape(rng)})
		placed += 1


func _build_giant_lake(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 6
	var flat: Vector2 = LANDMARKS[GIANT_ISLAND][1]
	for attempt in 1500:
		var r := lerpf(GIANT_LAKE.x, GIANT_LAKE.y, attempt / 1500.0)
		var p := Vector2(rng.randf_range(-HALF_W, HALF_W) * 0.75, rng.randf_range(-HALF_L, HALF_L) * 0.8)
		if shape_q(p.x, p.y) > 0.7 or not _lake_fits(p, r * (1.0 + GIANT_WOBBLE)):
			continue
		var rim := INF
		for k in 16:
			var q := p + Vector2.from_angle(TAU * k / 16.0) * (r + LAKE_BANK * 0.5)
			rim = minf(rim, _raw_height(q.x, q.y))
		# A random blob of a shore (GIANT_WOBBLE); its narrowest stays far outside the island.
		lakes.append({"pos": p, "radius": r, "surface": maxf(rim - 0.6, WATER_Y), "deep": false, "fed": false,
			"shape": [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, 1.0], "wobble": GIANT_WOBBLE, "island": flat.x + 6.0})
		landmarks.append({"model": GIANT_ISLAND, "name": LANDMARKS[GIANT_ISLAND][0], "pos": p, "angle": rng.randf() * TAU})
		_add_flat(p, Vector2(flat.x, flat.x + 4.0))  # no trees through the castle; ends before the shore
		return


## Floating islands: open ground clear of everything, high enough over the ground under them; the
## stepping stones spiral up from the ground beside it to the island's edge.
func _build_sky_islands(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 151
	for model in SKY_ISLANDS:
		var flat: Vector2 = LANDMARKS[model][1]
		var radius := flat.x + 6.0
		for attempt in 600:
			var p := Vector2(rng.randf_range(-HALF_W, HALF_W), rng.randf_range(-HALF_L, HALF_L)) * 0.8
			if not _sky_fits(p, radius):
				continue
			var under := -INF
			for k in 9:
				var q := p + (Vector2.from_angle(TAU * k / 8.0) * radius if k < 8 else Vector2.ZERO)
				under = maxf(under, height(q.x, q.y))
			var spiral := radius + STEP_RADIUS + 2.0
			var a0 := rng.randf() * TAU
			var start := p + Vector2.from_angle(a0) * spiral
			var g0 := height(start.x, start.y)
			var count := ceili((maxf(under + SKY_CLEAR, g0 + 18.0) - g0) / STEP_RISE)
			var top := g0 + (count + 1) * STEP_RISE
			var steps: Array = []
			for k in count:
				var s := p + Vector2.from_angle(a0 + k * STEP_GAP / spiral) * spiral
				steps.append(Vector3(s.x, g0 + (k + 1) * STEP_RISE, s.y))
			sky_islands.append({"pos": p, "radius": radius, "top": top, "steps": steps})
			landmarks.append({"model": model, "name": LANDMARKS[model][0], "pos": p, "angle": rng.randf() * TAU, "y": top})
			break


func _sky_fits(p: Vector2, r: float) -> bool:
	var reach := r + 12.0  # the island and its stepping stones
	if shape_q(p.x, p.y) > SAFE_Q - 0.1 or near_bridge(p.x, p.y, reach + 20.0):
		return false
	for f in flats:
		if p.distance_to(f.pos) < f.flat.y + reach + 20.0:
			return false
	for lake in lakes:
		if p.distance_to(lake.pos) < lake_reach(lake) + LAKE_BANK + reach:
			return false
	for l in landmarks:
		if p.distance_to(l.pos) < reach + 90.0:
			return false
	for s in sky_islands:
		if p.distance_to(s.pos) < reach + s.radius + 120.0:
			return false
	for k in 8:  # stepping stones start on dry land
		var q := p + Vector2.from_angle(TAU * k / 8.0) * reach
		if water_surface(q.x, q.y) != -INF:
			return false
	return true


## Where you stand at (x, z): a floating island's top if you're up on it (`from_y` at least near
## the top), else the ground.
func stand_height(x: float, z: float, from_y := INF) -> float:
	for s in sky_islands:
		if Vector2(x, z).distance_to(s.pos) < s.radius and from_y > s.top - 4.0:
			return s.top
	return height(x, z)


## Random phases (and a strength) for a lake's wobbly shore.
static func _lake_shape(rng: RandomNumberGenerator) -> Array:
	return [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, rng.randf_range(0.6, 1.0)]


func _lake_fits(p: Vector2, r: float) -> bool:
	for f in flats:
		if p.distance_to(f.pos) < f.flat.y + r + LAKE_BANK + 6.0:
			return false
	for lake in lakes:
		if p.distance_to(lake.pos) < lake.radius + r + LAKE_BANK * 2.0:
			return false
	for river in rivers:
		var info := _river_at(river, p.x, p.y)
		if info.x < info.y * 0.5 + 60.0 + r + LAKE_BANK:
			return false
	return _raw_height(p.x, p.y) > WATER_Y + 3.0  # not down in a river valley


const HAMLET_NAMES := ["Ostiana", "Hythe Marrow", "Kalmarsund", "Dunwick", "Piraeon", "Sidonia", "Ravennor", "Hallstadt", "Lindisfarrow", "Massalia", "Tyrrhe", "Volubis"]
## Hamlets on dry, level ground beside the main river, the branches and their lakes.
func _build_hamlets() -> void:
	var spots: Array = []  # [point by the water, direction toward the water]
	var main: Dictionary = rivers[_main_index()]
	for i in range(30, main.c.size() - 30, 25):
		var p := _river_point(main, i)
		var across := _river_dir(main, i).orthogonal()
		spots.append([p, across])
		spots.append([p, -across])
	for lake in lakes:
		if lake.fed:
			for k in 4:
				spots.append([lake.pos, Vector2.from_angle(TAU * k / 4.0 + 0.4)])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(main.c[0] * 1000.0)
	for i in range(spots.size() - 1, 0, -1):  # shuffle, so hamlets spread over the whole valley
		var j := rng.randi_range(0, i)
		var tmp = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	for spot in spots:
		if hamlets.size() >= HAMLETS:
			break
		var shore := _dry_land(spot[0], spot[1])
		var pos: Vector2 = shore + spot[1] * 40.0
		if _hamlet_fits(pos):
			hamlets.append({"pos": pos, "to_water": -(spot[1] as Vector2), "name": HAMLET_NAMES[hamlets.size() % HAMLET_NAMES.size()], "region": region_at(pos.x, pos.y)})
			_add_flat(pos, HAMLET_FLAT)


func _hamlet_fits(p: Vector2) -> bool:
	if shape_q(p.x, p.y) > SAFE_Q - 0.05:
		return false
	for f in flats:
		if p.distance_to(f.pos) < f.flat.y + HAMLET_FLAT.y + 40.0:
			return false
	for h in hamlets:
		if p.distance_to(h.pos) < HAMLET_SPACING:
			return false
	for lake in lakes:
		if p.distance_to(lake.pos) < lake.radius + LAKE_BANK + HAMLET_FLAT.x:
			return false
	var y := _raw_height(p.x, p.y)
	if y < WATER_Y + 1.0:
		return false
	for k in 4:  # not on a steep slope
		var q := p + Vector2.from_angle(TAU * k / 4.0) * HAMLET_FLAT.x
		if absf(_raw_height(q.x, q.y) - y) > 5.0:
			return false
	return true


func _build_landmarks(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 91
	for copy in LANDMARK_COPIES:  # more big places to find (user, 2026-11-05), each held by a war band (WorldEvents)
		for model in LANDMARKS:
			var flat: Vector2 = LANDMARKS[model][1]
			for attempt in 400:
				var p := Vector2(rng.randf_range(-HALF_W, HALF_W), rng.randf_range(-HALF_L, HALF_L)) * 0.85
				if _landmark_fits(p, flat):
					landmarks.append({"model": model, "name": LANDMARKS[model][0], "pos": p, "angle": rng.randf() * TAU})
					_add_flat(p, flat)
					break


func _build_structures(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 137
	for r in regions:
		for kind in STRUCTURES:
			var spec: Array = STRUCTURES[kind]
			for k in spec[0]:
				for attempt in 60:
					var p: Vector2 = r.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(135.0, 380.0)
					if region_at(p.x, p.y) == r.id and _landmark_fits(p, spec[2]):
						var art: String = STRUCTURE_ART.get(GameData.text(GameData.row("valley_regions", r.id), "biome"), "meadow")
						landmarks.append({"model": "%s_%s" % [kind, art], "name": spec[1], "pos": p, "angle": rng.randf() * TAU, "kind": kind, "chest": spec[3]})
						if kind == "tower":  # every third climbed the other way round, every third hollow, climbed inside
							var variant: String = TOWER_VARIANTS[landmarks.filter(func(l): return l.get("kind") == "tower").size() % TOWER_VARIANTS.size()]
							landmarks[-1].variant = variant
							if variant == "hollow":
								landmarks[-1].model += "_hollow"
						_add_flat(p, spec[2])
						if kind == "cave":
							_add_cave(p, landmarks[-1].angle, flats[-1].y)
							landmarks[-1].y = flats[-1].y  # the model stands on the ground at the mouth, not the sunk floor
						break


func _landmark_fits(p: Vector2, flat: Vector2) -> bool:
	if shape_q(p.x, p.y) > SAFE_Q - 0.08 or near_bridge(p.x, p.y, flat.y + 20.0):
		return false
	for f in flats:  # villages, encounter spots, hamlets, other landmarks
		if p.distance_to(f.pos) < f.flat.y + flat.y + 30.0:
			return false
	for lake in lakes:
		if p.distance_to(lake.pos) < lake_reach(lake) + LAKE_BANK + flat.y:
			return false
	var y := _raw_height(p.x, p.y)
	if y < WATER_Y + 1.5:
		return false
	for k in 8:  # dry all around, not too steep
		var q := p + Vector2.from_angle(TAU * k / 8.0) * (flat.x + 12.0)
		if water_surface(q.x, q.y) != -INF or absf(_raw_height(q.x, q.y) - y) > 7.0:
			return false
	return true


## Where the crossing rivers and the main river leave the valley, they pour out of the mountains.
func _build_waterfalls() -> void:
	for i in rivers.size():
		var river: Dictionary = rivers[i]
		if river.branch:
			continue
		var mid: int = river.c.size() / 2
		for step in [-1, 1]:
			# Walk out along the river to the valley's edge...
			var k: int = mid
			while k + step > 0 and k + step < river.c.size() - 1:
				var p := _river_point(river, k + step)
				if shape_q(p.x, p.y) >= EDGE_Q:
					break
				k += step
			var bottom := _river_point(river, k)
			var out: Vector2 = _river_dir(river, k) * step
			# ...the water drops from the cliff top just beyond it.
			var top: Vector2 = bottom + out * 22.0
			waterfalls.append({"bottom": Vector3(bottom.x, WATER_Y, bottom.y), "top": Vector3(top.x, height(top.x, top.y) - 0.5, top.y), "river": i, "dir": out, "width": river.width[k]})


## Height of the water surface over (x, z), or -INF where there's no water.
func water_surface(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var ground := height(x, z)
	for lake in lakes:
		if p.distance_to(lake.pos) < lake_reach(lake) + LAKE_BANK and ground < lake.surface:
			return lake.surface
	return WATER_Y if ground < WATER_Y else -INF


## Rapids and deep lakes push swimmers of other races back to where they came
## from: the direction (x, z) of the push, or ZERO where swimming is open to all.
func current_push(x: float, z: float, race_id: String) -> Vector2:
	if race_id == SWIMMER_RACE:
		return Vector2.ZERO
	var p := Vector2(x, z)
	for river in rivers:
		if not river.rapids:
			continue
		var info := _river_at(river, x, z)
		if info.x < info.y * 0.5 + RIVER_BANK:
			return Vector2(0.0, info.z) if river.axis == "x" else Vector2(info.z, 0.0)
	for lake in lakes:
		if lake.deep and p.distance_to(lake.pos) < lake.radius + LAKE_BANK * 0.5:
			return (p - lake.pos).normalized()
	return Vector2.ZERO


## The river centerline as points (for the map and the rapids' surface).
func river_line(index: int) -> PackedVector2Array:
	var river: Dictionary = rivers[index]
	var out := PackedVector2Array()
	for i in river.c.size():
		out.append(_river_point(river, i))
	return out


## True if (x, z) is within `margin` meters of a bridge's deck.
func near_bridge(x: float, z: float, margin: float) -> bool:
	var p := Vector2(x, z)
	for b in bridges:
		var r: float = b.reach + margin
		if p.distance_squared_to(b.mid) > r * r:
			continue  # farther than the whole deck: skip the exact check (same answer, much cheaper)
		var seg: Vector2 = b.b - b.a
		var t := clampf((p - b.a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		if p.distance_to(b.a + seg * t) < BRIDGE_WIDTH * 0.5 + margin:
			return true
	return false


## True inside the fully flat middle of a village, hamlet or encounter spot.
func near_flat(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for i in _flat_grid.get(Vector2i(floori(x / FLAT_CELL), floori(z / FLAT_CELL)), []):
		var f: Dictionary = flats[i]
		if p.distance_squared_to(f.pos) < f.flat.x * f.flat.x:
			return true
	return false


## True if a point whose ground is at `ground` is under a lake's water.
func in_lake(x: float, z: float, ground: float) -> bool:
	var p := Vector2(x, z)
	for lake in lakes:
		if ground < lake.surface and p.distance_squared_to(lake.pos) < pow(lake_reach(lake) + LAKE_BANK, 2.0):
			return true
	return false


## The region blend at a point, for height() and color().
func weights_at(x: float, z: float) -> Array:
	return _weights(x, z)


## [Vector2(region index, weight)], weights summing to 1.
func _weights(x: float, z: float) -> Array:
	var out: Array = []
	var total := 0.0
	var p := Vector2(x, z)
	for i in regions.size():
		var d2: float = p.distance_squared_to(regions[i].pos)
		if d2 > 16.0 * BLEND * BLEND:
			continue  # too far to matter (weight under 0.03%)
		var w := exp(-d2 / (2.0 * BLEND * BLEND))
		out.append(Vector2(i, w))
		total += w
	if total <= 1e-12:
		# Far outside every region (mountain corners): use the nearest one.
		var id := region_at(x, z)
		for i in regions.size():
			if regions[i].id == id:
				return [Vector2(i, 1.0)]
	for i in out.size():
		out[i].y /= total
	return out


# ---------------------------------------------------------------- roads

## Roads between neighboring villages (user, 2026-11-05): dirt roads caravans travel and you
## can ride (a mount is quicker on them). Straight from village to village, over the nearest
## bridge where a river is in the way; a pair with no dry way between them gets no road.
const ROAD_WIDTH := 5.0
const ROAD_CELL := 64.0
## [{a: region, b: region, line: PackedVector2Array}], village center to village center
var roads: Array = []
var _road_cells := {}  ## Vector2i -> [[from, to], ...] road pieces near that ROAD_CELL square


func build_roads(state: RunState) -> void:
	roads = []
	_road_cells = {}
	var map := ValleyGenerator.neighbors()
	var done := {}
	for region in state.regions:
		if state.regions[region].get("tribe", "") == "":
			continue
		for other in map.get(region, []):
			if not state.regions.has(other) or state.regions[other].get("tribe", "") == "":
				continue
			var pair := [region, other]
			pair.sort()
			if done.has(str(pair)):
				continue
			done[str(pair)] = true
			var line := _road_line(region_center(pair[0]), region_center(pair[1]), 0)
			if not line.is_empty():
				roads.append({"a": pair[0], "b": pair[1], "line": line})
	for road in roads:
		var line: PackedVector2Array = road.line
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			for k in int(a.distance_to(b) / (ROAD_CELL * 0.5)) + 2:
				var p := a.lerp(b, minf(k * ROAD_CELL * 0.5 / maxf(a.distance_to(b), 0.01), 1.0))
				for dz in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var c := Vector2i(floori(p.x / ROAD_CELL) + dx, floori(p.y / ROAD_CELL) + dz)
						if not _road_cells.has(c):
							_road_cells[c] = []
						if not [a, b] in _road_cells[c]:
							_road_cells[c].append([a, b])


func _road_line(a: Vector2, b: Vector2, depth: int) -> PackedVector2Array:
	var wet := _first_water(a, b)
	if wet == Vector2.INF:
		return PackedVector2Array([a, b])
	if wet == -Vector2.INF or depth > 2:
		return PackedVector2Array()  # out of the valley, or too many rivers: no road
	var best: Dictionary = {}
	for br in bridges:
		if (best.is_empty() or wet.distance_to(br.mid) < wet.distance_to(best.mid)) and wet.distance_to(br.mid) < 500.0:
			best = br
	if best.is_empty():
		return PackedVector2Array()
	var near_end: Vector2 = best.a if a.distance_to(best.a) < a.distance_to(best.b) else best.b
	var far_end: Vector2 = best.b if near_end == best.a else best.a
	var first := _road_line(a, near_end, depth + 1)
	var rest := _road_line(far_end, b, depth + 1)
	if first.is_empty() or rest.is_empty():
		return PackedVector2Array()
	return first + rest


## Where the straight way from a to b first meets water (INF: dry all the way; -INF: it
## leaves the valley). The ends are skipped: villages and bridge ends are on the bank.
func _first_water(a: Vector2, b: Vector2) -> Vector2:
	var length := a.distance_to(b)
	var t := 10.0
	while t < length - 10.0:
		var p := a.lerp(b, t / length)
		if shape_q(p.x, p.y) > SAFE_Q:
			return -Vector2.INF
		if water_surface(p.x, p.y) != -INF:
			return p
		t += 6.0
	return Vector2.INF


## True if (x, z) is on a road, or within `margin` meters of one.
func near_road(x: float, z: float, margin := 0.0) -> bool:
	var p := Vector2(x, z)
	var reach := ROAD_WIDTH * 0.5 + margin
	for piece in _road_cells.get(Vector2i(floori(x / ROAD_CELL), floori(z / ROAD_CELL)), []):
		var a: Vector2 = piece[0]
		var ab: Vector2 = piece[1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if p.distance_squared_to(a + ab * t) < reach * reach:
			return true
	return false


## The directions (angles in the x-z plane, as ValleyWorld's village streets use them) roads
## leave a village at `center` by.
func road_angles(center: Vector2) -> Array:
	var out: Array = []
	for road in roads:
		var line: PackedVector2Array = road.line
		if line[0].distance_to(center) < 1.0:
			out.append((line[1] - line[0]).angle())
		elif line[-1].distance_to(center) < 1.0:
			out.append((line[-2] - line[-1]).angle())
	return out


func _add_flat(p: Vector2, flat: Vector2) -> void:
	var index := flats.size()
	flats.append({"pos": p, "y": maxf(_raw_height(p.x, p.y), WATER_Y + 0.6), "flat": flat})
	var reach := int(ceil(flat.y / FLAT_CELL))
	var cell := Vector2i(floori(p.x / FLAT_CELL), floori(p.y / FLAT_CELL))
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var k := cell + Vector2i(dx, dz)
			if not _flat_grid.has(k):
				_flat_grid[k] = []
			_flat_grid[k].append(index)
