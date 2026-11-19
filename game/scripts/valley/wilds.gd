class_name Wilds
extends Node
## Wild enemies roaming the valley: barbarian patrols and beast packs, picked by
## each region's biome. A group wanders near where it appeared, attacks when you
## come close (and gives up if you run), and a while after it's wiped out a new
## group appears somewhere else, away from you. Groups far from you sleep.
## They aren't encounters: Count Fuckula's clock keeps running, but every kill
## gives XP.

## 64 until 2026-10-29, then 90 (user: more wild packs), then 140 (user: the
## valley 30% bigger and still more bandits, animals and monsters).
const GROUPS := 200  # 140 until 2026-11-05 (user: more of them in the wild); 175 for a moment on 2026-11-03: each cave and tower now brings its own guards, about 40 groups
## A group notices you this close...
const AGGRO := 22.0
## ...and wanders this far around its spot.
const ROAM := 25.0
const RESPAWN_SECONDS := 90.0  # 150 until 2026-10-29
const SLEEP_RANGE := 170.0
## Groups keep this far from your camp, villages and encounter spots.
const CLEAR_HOME := 140.0
const CLEAR_VILLAGE := 95.0  # just outside the village walls
const CLEAR_SITE := 45.0
const CLEAR_LANDMARK := 40.0
## New groups appear at least this far from you.
const RESPAWN_AWAY := 150.0

## What roams each biome (Valley Regions "biome"): a list of packs, each a list
## of [unit_id, fewest, most]. Units come from the Barbarians & Beasts sheet.
## Count Fuckula's slimes ooze around the dank places too (user, 2026-10-31).
## Free animated animals (user, 2026-10-31): herds to hunt (they run, never fight)
## and dinosaurs. The first three packs of each biome are its own native animals, found nowhere
## else (user, 2026-11-03), so every region looks and fights differently.
const PACKS := {
	"River meadows and farmland": [[["animal_donkey", 2, 4]], [["beast_fox", 2, 4]], [["beast_fox", 2, 3]], [["beast_wild_boar", 2, 3]], [["barb_raider", 3, 4], ["barb_slinger", 1, 2]], [["barb_warhound", 3, 4]], [["animal_cow", 3, 5]], [["animal_sheep", 4, 6]], [["animal_pig", 2, 4]], [["animal_gull", 3, 5]], [["animal_crane", 2, 3]], [["animal_jackalope", 1, 3]], [["animal_jackalope", 1, 2]]],
	"Rocky hills, pine and old mines": [[["beast_lynx", 2, 3]], [["beast_lynx", 2, 2]], [["animal_mountain_goat", 3, 5]], [["beast_dire_wolf", 3, 5]], [["beast_cave_bear", 1, 1]], [["barb_raider", 2, 3], ["barb_berserker", 1, 1]], [["animal_sheep", 4, 6]], [["animal_llama", 3, 5]], [["animal_eagle", 1, 2]], [["beast_hawk", 1, 3]], [["monster_cyclops", 1, 1]], [["animal_jackalope", 1, 2]]],
	"Ancient forest": [[["animal_deer", 3, 5]], [["animal_deer", 3, 4]], [["beast_panther", 1, 2]], [["beast_dire_wolf", 3, 4]], [["beast_giant_spider", 3, 5]], [["beast_wild_boar", 2, 3]], [["horde_slime", 3, 5]], [["beast_stegosaurus", 1, 1]], [["beast_triceratops", 1, 2]], [["animal_parrot", 3, 5]], [["beast_giant_bat", 3, 5]], [["animal_unicorn", 1, 1]], [["animal_unicorn", 1, 1]]],
	"Open grassland": [[["animal_bison", 4, 7]], [["animal_bison", 4, 6]], [["beast_lion", 1, 2]], [["beast_wild_boar", 3, 4]], [["barb_raider", 3, 5], ["barb_hedge_witch", 1, 1]], [["barb_warhound", 4, 5]], [["animal_horse", 3, 5]], [["animal_zebra", 3, 5]], [["beast_triceratops", 1, 2]], [["beast_apatosaurus", 1, 1]], [["animal_roc", 1, 1]], [["animal_crane", 2, 4]], [["beast_chimera", 1, 1]], [["animal_unicorn", 1, 1]]],
	"Steaming jungle": [[["beast_jaguar", 1, 2]], [["animal_tapir", 2, 3]], [["beast_python", 1, 2]], [["beast_jaguar", 1, 1]], [["beast_python", 1, 1]], [["animal_toucan", 3, 5]], [["animal_toucan", 3, 4]], [["animal_parrot", 3, 5]], [["beast_giant_bat", 3, 4]], [["beast_velociraptor", 3, 4]], [["beast_parasaurolophus", 2, 3]], [["horde_slime", 3, 4]], [["beast_feathered_serpent", 1, 1]], [["beast_feathered_serpent", 1, 1]]],
	"Swamp and river delta": [[["animal_water_buffalo", 3, 5]], [["beast_bog_boar", 2, 3]], [["beast_bog_boar", 2, 2]], [["beast_giant_spider", 3, 5]], [["barb_raider", 2, 3], ["barb_hedge_witch", 1, 2]], [["horde_slime", 4, 6]], [["beast_velociraptor", 3, 5]], [["beast_parasaurolophus", 2, 4]], [["animal_crane", 3, 4]], [["beast_giant_bat", 3, 4]], [["beast_basilisk", 1, 1]], [["monster_gorgon", 1, 1]]],
	"Desert canyons": [[["beast_coyote", 3, 5]], [["beast_coyote", 3, 4]], [["animal_bighorn", 3, 5]], [["barb_raider", 3, 4], ["barb_slinger", 2, 2]], [["barb_berserker", 2, 3]], [["beast_giant_spider", 2, 4]], [["beast_velociraptor", 3, 5]], [["beast_trex", 1, 1]], [["beast_vulture", 2, 3]], [["animal_eagle", 1, 2]], [["monster_mummy", 2, 4]], [["monster_mummy", 3, 4]], [["beast_chimera", 1, 1]]],
	"High cliffs and peaks": [[["animal_ibex", 3, 5]], [["animal_ibex", 3, 4]], [["beast_cougar", 1, 2]], [["beast_dire_wolf", 3, 4]], [["beast_cave_bear", 1, 1]], [["animal_llama", 3, 5]], [["animal_roc", 1, 1]], [["animal_eagle", 1, 2]], [["beast_hawk", 2, 3]], [["monster_harpy", 2, 3]], [["monster_harpy", 2, 3]], [["animal_pegasus", 1, 2]], [["animal_pegasus", 1, 1]]],
	"Volcanic ashlands": [[["beast_ash_hound", 3, 4]], [["beast_ash_hound", 3, 3]], [["beast_cinder_boar", 2, 3]], [["barb_berserker", 2, 3], ["barb_hedge_witch", 1, 1]], [["horde_slime", 3, 5]], [["beast_trex", 1, 1]], [["beast_vulture", 2, 3]], [["beast_giant_bat", 3, 4]], [["beast_cerberus", 1, 1]], [["animal_phoenix", 1, 1]], [["animal_phoenix", 1, 1]], [["beast_little_demon", 3, 5]], [["beast_little_demon", 2, 4]]],
	"Snowfields and glaciers": [[["animal_reindeer", 3, 6]], [["animal_reindeer", 3, 5]], [["beast_snow_leopard", 1, 2]], [["beast_dire_wolf", 4, 5]], [["beast_cave_bear", 1, 2]], [["animal_eagle", 1, 2]], [["animal_roc", 1, 1]], [["monster_frost_giant", 1, 1]], [["monster_harpy", 2, 2]]],
	"Collapsed city and tunnels": [[["beast_feral_dog", 3, 5]], [["beast_tunnel_rat", 4, 6]], [["beast_tunnel_rat", 4, 5]], [["beast_giant_spider", 4, 6]], [["barb_raider", 3, 4], ["barb_slinger", 1, 2]], [["horde_slime", 4, 6]], [["beast_giant_bat", 4, 5]], [["beast_vulture", 2, 3]], [["monster_gorgon", 1, 1]], [["monster_gorgon", 1, 1]], [["monster_mummy", 2, 3]]],
}
const DEFAULT_PACKS := [[["barb_raider", 3, 4]]]
## Each biome's monster (user, 2026-11-03): far stronger than what roams around it.
const MONSTERS := {
	"River meadows and farmland": "beast_hippogriff",
	"Rocky hills, pine and old mines": "monster_stone_giant",
	"Ancient forest": "monster_wendigo",
	"Steaming jungle": "monster_giant_ape",
	"Open grassland": "beast_manticore",
	"Swamp and river delta": "beast_hydra",
	"Desert canyons": "beast_sphinx",
	"High cliffs and peaks": "beast_griffin",
	"Volcanic ashlands": "monster_magma_golem",
	"Snowfields and glaciers": "monster_yeti",
	"Collapsed city and tunnels": "monster_gargoyle",
}
## How far up things fly, and how far they wander.
const FLY_HEIGHT := {"animal_roc": 55.0, "animal_eagle": 28.0, "beast_vulture": 20.0, "beast_hawk": 16.0, "animal_crane": 12.0, "animal_gull": 12.0, "animal_parrot": 9.0, "animal_pegasus": 30.0, "animal_phoenix": 34.0, "beast_feathered_serpent": 20.0, "monster_harpy": 11.0, "animal_toucan": 14.0, "beast_giant_bat": 7.0, "beast_little_demon": 6.0}
const SKY_ROAM := 80.0
## Getting this close to a kind of creature you haven't met counts as finding it: XP for exploring (user, 2026-11-03).
const DISCOVER_RANGE := 45.0
const DISCOVER_XP := 8.0
## How often a land group is a monster, and how often a monster or a hostile pack has another kind with it.
const MONSTER_CHANCE := 0.12
const MIXED_CHANCE := 0.55
## Water monsters in the rivers and lakes (user, 2026-10-29), never near a bridge.
## Repeats make a kind more common; the Kraken is the rarest.
const WATER_GROUPS := 85  # 60 until 2026-11-03 (user: more water life);  45 until 2026-10-30 (user: didn't see sharks or krakens)
## Water monsters show from farther (open water): SLEEP_RANGE x this.
const WATER_SIGHT := 1.8
const WATER_AGGRO := 30.0
const WATER_PACKS := [[["animal_mermaid", 1, 2]], [["animal_mermaid", 1, 1]], [["animal_hippocampus", 1, 3]], [["animal_hippocampus", 2, 3]], [["beast_leviathan", 1, 1]],
	[["animal_dolphin", 2, 3]], [["animal_dolphin", 2, 3]], [["animal_sea_turtle", 1, 2]], [["animal_sea_turtle", 1, 2]],
	[["animal_manta_ray", 1, 2]], [["animal_manta_ray", 1, 2]], [["animal_whale", 1, 1]], [["animal_fish_school", 1, 2]], [["animal_fish_school", 1, 2]],
	[["animal_swan", 2, 3]], [["animal_swan", 2, 3]], [["beast_jellyfish", 2, 4]], [["beast_jellyfish", 2, 3]], [["beast_water_serpent", 1, 1]],
	[["beast_piranha_swarm", 1, 2]], [["beast_piranha_swarm", 2, 2]], [["beast_giant_eel", 1, 2]],
	[["beast_giant_eel", 1, 1]], [["beast_giant_crab", 1, 2]], [["beast_crocodile", 1, 1]], [["beast_crocodile", 1, 2]],
	[["beast_shark", 1, 1]], [["beast_shark", 1, 2]], [["beast_kraken", 1, 1]], [["beast_kraken", 1, 1]]]
const CLEAR_BRIDGE := 40.0

var valley: Node  ## the Valley scene
var discovering := true  ## tests turn this off: its XP brings up level-up menus, which pause the game
## [{center: Vector3, units: [Enemy], respawn_left: float, asleep: bool}]
var groups: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = Run.state.seed + 7
	if not valley.battle.is_empty():
		return  # a custom battle: the field stays clear
	for i in GROUPS:
		var spot := find_spot(false)
		if spot != Vector3.INF:
			groups.append(_spawn_group(spot))
	for i in WATER_GROUPS:
		var spot := find_water_spot(false)
		if spot != Vector3.INF:
			groups.append(_spawn_group(spot, true))


## Every half second from the Valley: sleep far groups, replace wiped-out ones.
func update(delta: float) -> void:
	var p: Vector3 = valley.player.global_position
	if discovering and not Run.in_fight and not valley.hud.is_choosing():
		_discover(p)
	for i in groups.size():
		var g: Dictionary = groups[i]
		g.units = g.units.filter(func(u): return is_instance_valid(u) and not u.is_dead())
		if g.units.is_empty():
			g.respawn_left -= delta
			if g.respawn_left <= 0.0:
				var water: bool = g.get("water", false)
				var spot := find_water_spot(true) if water else find_spot(true)
				if spot != Vector3.INF:
					groups[i] = _spawn_group(spot, water)
			continue
		var chasing: bool = g.units.any(func(u): return u.target != null)
		var sleep: bool = not chasing and g.center.distance_to(p) > SLEEP_RANGE * (WATER_SIGHT if g.get("water", false) else 1.0)
		if sleep != g.asleep:
			g.asleep = sleep
			for u in g.units:
				u.set_dormant(sleep)


## A random open spot for a group, clear of your camp, villages, encounters and
## Count Fuckula's land (and far from you, if `away_from_player`). INF if none found.
func find_spot(away_from_player: bool) -> Vector3:
	var s: RunState = Run.state
	var t: ValleyTerrain = valley.terrain
	var home := ValleyTerrain.region_center(valley.home_region())
	for attempt in 80:
		var x := _rng.randf_range(-ValleyTerrain.HALF_W, ValleyTerrain.HALF_W) * 0.85
		var z := _rng.randf_range(-ValleyTerrain.HALF_L, ValleyTerrain.HALF_L) * 0.88
		var p2 := Vector2(x, z)
		if ValleyTerrain.shape_q(x, z) > ValleyTerrain.SAFE_Q or p2.distance_to(home) < CLEAR_HOME:
			continue
		if s.regions.get(t.region_at(x, z), {}).get("corrupted", false):
			continue
		var y := t.height(x, z)
		if t.water_surface(x, z) != -INF or t.water_surface(x + 8.0, z) != -INF or t.water_surface(x, z + 8.0) != -INF:
			continue
		var p := Vector3(x, y, z)
		if away_from_player and p.distance_to(valley.player.global_position) < RESPAWN_AWAY:
			continue
		if _near_any(p2, valley.villages.values().map(func(v): return Vector2(v.global_position.x, v.global_position.z)), CLEAR_VILLAGE):
			continue
		if _near_any(p2, s.encounters.keys().map(func(id): return ValleyTerrain.site_point(s, id)), CLEAR_SITE):
			continue
		if _near_any(p2, t.landmarks.map(func(l): return l.pos), CLEAR_LANDMARK):
			continue  # not inside a cave, tower or ruin
		return p
	return Vector3.INF


## A spot in deep water (a river or a lake), clear of bridges and your camp. INF if none.
func find_water_spot(away_from_player: bool) -> Vector3:
	var t: ValleyTerrain = valley.terrain
	var home := ValleyTerrain.region_center(valley.home_region())
	for attempt in 60:
		var p2: Vector2
		if _rng.randf() < 0.35 and not t.lakes.is_empty():
			var lake: Dictionary = t.lakes[_rng.randi() % t.lakes.size()]
			p2 = lake.pos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * lake.radius * 0.6
		else:
			var line := t.river_line(_rng.randi() % t.rivers.size())
			p2 = line[_rng.randi() % line.size()]
		var surface := t.water_surface(p2.x, p2.y)
		if surface == -INF or surface - t.height(p2.x, p2.y) < 2.5 or ValleyTerrain.shape_q(p2.x, p2.y) > ValleyTerrain.SAFE_Q:
			continue
		if t.near_bridge(p2.x, p2.y, CLEAR_BRIDGE) or p2.distance_to(home) < CLEAR_HOME:
			continue
		var p := Vector3(p2.x, surface, p2.y)
		if away_from_player and p.distance_to(valley.player.global_position) < RESPAWN_AWAY:
			continue
		return p
	return Vector3.INF


func _spawn_group(center: Vector3, water := false, hunters_only := false) -> Dictionary:
	var t: ValleyTerrain = valley.terrain
	var biome := GameData.text(GameData.row("valley_regions", t.region_at(center.x, center.z)), "biome")
	var packs: Array = WATER_PACKS if water else PACKS.get(biome, DEFAULT_PACKS)
	var pack: Array = packs[_rng.randi() % packs.size()]
	if hunters_only:
		var hunters: Array = packs.filter(func(q): return _hunts(q) and not GameData.text(GameData.unit(q[0][0]), "rig_type").begins_with("Flying"))
		if not hunters.is_empty():
			pack = hunters[_rng.randi() % hunters.size()]
	if not water:
		pack = _land_pack(biome, pack, packs)
	var units: Array = []
	var giant_left := 1 if not water and _rng.randf() < GameData.tuning.giant_chance else 0
	for entry in pack:
		for k in _rng.randi_range(entry[1], entry[2]):
			var e := Enemy.new()
			e.setup(entry[0], valley.player, valley.director, Enemy.Team.HOSTILE)
			if giant_left > 0 and _can_be_giant(entry[0]):
				giant_left = 0
				e.make_giant()
			e.post = center
			e.faction = _side(pack)
			e.aggro_radius = WATER_AGGRO if water else AGGRO
			e.roam_radius = SKY_ROAM if e.flying else ROAM
			e.fly_height = FLY_HEIGHT.get(entry[0], e.fly_height)
			var pos := center + Vector3(_rng.randf_range(-5.0, 5.0), 0.0, _rng.randf_range(-5.0, 5.0))
			pos.y = center.y if water else t.height(pos.x, pos.z) + 0.1 + (e.fly_height if e.flying else 0.0)
			valley.add_child(e)
			e.global_position = pos
			units.append(e)
	return {"center": center, "units": units, "respawn_left": RESPAWN_SECONDS, "asleep": false, "water": water}


## Which side a pack is on (user, 2026-11-05: wild sides fight each other): barbarians stand
## together; beasts and monsters side with their own kind (the pack's leader). Herds take no side.
func _side(pack: Array) -> String:
	if not _hunts(pack):
		return ""
	var lead := str(pack[0][0])
	return "barbarians" if lead.begins_with("barb_") else lead


## Not only one kind of enemy (user, 2026-11-03): a hostile group often has another kind with it,
## in smaller numbers, and now and then the region's monster leads it. Herds stay herds.
func _land_pack(biome: String, pack: Array, packs: Array) -> Array:
	if not _hunts(pack):
		return pack
	var hostile: Array = packs.filter(_hunts)
	var out: Array = pack
	if _rng.randf() < MIXED_CHANCE:
		var other: Array = hostile[_rng.randi() % hostile.size()]
		if other[0][0] != pack[0][0]:
			out = pack + other.map(func(e): return [e[0], 1, maxi(1, int(e[2]) - 2)])
	if MONSTERS.has(biome) and _rng.randf() < MONSTER_CHANCE * 2.0:
		var with_it: Array = out.map(func(e): return [e[0], 1, mini(int(e[2]), 2)]) if _rng.randf() < 0.5 else []
		out = [[MONSTERS[biome], 1, 1]] + with_it
	return out


## Land animals only, and not what's already huge.
static func _can_be_giant(id: String) -> bool:
	var row := GameData.unit(id)
	var rig := GameData.text(row, "rig_type")
	return (id.begins_with("beast_") or id.begins_with("animal_")) and GameData.num(row, "hp") < 300.0 and not rig.begins_with("Flying") and not rig.begins_with("Water") and not MONSTERS.values().has(id)


## False for herds, birds and other things that leave you alone.
static func _hunts(pack: Array) -> bool:
	return not str(pack[0][0]).begins_with("animal_") and GameData.text(GameData.unit(pack[0][0]), "faction") != "Neutral"


## The first time you come near a kind of creature, it goes in your book.
func _discover(p: Vector3) -> void:
	var seen: Array = Run.state.flags.get("discovered", [])
	for g in groups:
		if g.asleep or g.center.distance_to(p) > SLEEP_RANGE:
			continue
		for u in g.units:
			var kind: String = ("giant_" if u.giant else "") + u.unit_id
			if kind in seen or (u.global_position - p).length() > DISCOVER_RANGE + (u.fly_height if u.flying else 0.0):
				continue
			seen.append(kind)
			Run.state.flags["discovered"] = seen
			Meta.add_codex("creature:" + kind)
			Meta.discover(u.unit_id)
			valley.give_xp(DISCOVER_XP)
			return  # one at a time


## The hunters that are a biome's own (its first three packs, without the herds).
static func native_hunters(biome: String) -> Array:
	var out: Array = []
	for pack in PACKS.get(biome, []).slice(0, 3):
		if not str(pack[0][0]).begins_with("animal_") and not pack[0][0] in out:
			out.append(pack[0][0])
	return out


static func _near_any(p: Vector2, points: Array, radius: float) -> bool:
	for q in points:
		if p.distance_to(q) < radius:
			return true
	return false
