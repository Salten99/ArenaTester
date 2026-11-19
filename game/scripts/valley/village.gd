class_name Village
extends Node3D
## A tribe's village in the valley: its buildings (from ValleyWorld), villagers
## who wander around the bonfire, and warriors standing guard. They're all
## Enemy units on the NEUTRAL side until a battle:
##   befriend: a barbarian raid; the guards fight beside you, villagers flee
##   attack:   the guards (and the tribe's reinforcements) fight you, villagers flee
## Count Fuckula's village has no villagers, only sentries that attack anyone
## who comes close. Far-away villages go dormant to keep the valley fast.
## A hamlet (a fishing settlement by the water, ValleyTerrain.hamlets) is a small
## Village with a few villagers of its region's tribe and no guards; it plays no
## part in diplomacy, and empties when Count Fuckula takes its region.

## Guards per village: army role -> how many.
const GUARDS := {"Melee": 3, "Ranged": 2, "Magic": 1}
const EVIL_GUARDS := {"Melee": 4, "Ranged": 2, "Magic": 1, "Large": 1}
const VILLAGERS := 10
const HAMLET_VILLAGERS := 3
## Count Fuckula sentries attack anyone this close.
const SENTRY_AGGRO := 28.0
## Villages farther than this from the player pause.
const AWAKE_RANGE := 160.0

var race := ""
var region := ""
var is_home := false
## The terrain's hamlet entry ({pos, to_water, name, region}) if this is a hamlet.
var hamlet := {}
var valley: Node  ## the Valley scene
var buildings: Node3D
var guards: Array = []
var villagers: Array = []
var _dormant := false


static func make(p_valley: Node, p_region: String, p_race: String, p_is_home: bool, center: Vector3) -> Village:
	var v := Village.new()
	v.name = "Tribe_" + p_race
	v.valley = p_valley
	v.region = p_region
	v.race = p_race
	v.is_home = p_is_home
	v.position = center
	return v


## A riverside hamlet whose villagers are of `p_race`.
static func make_hamlet(p_valley: Node, entry: Dictionary, p_race: String, center: Vector3) -> Village:
	var v := make(p_valley, entry.region, p_race, false, center)
	v.name = "Hamlet_" + entry.name.replace(" ", "_")
	v.hamlet = entry
	return v


func _ready() -> void:
	if not hamlet.is_empty():
		buildings = valley.world.build_hamlet(global_position, hamlet.to_water, hamlet.name, race)
		if Run.state.regions.get(region, {}).get("corrupted", false):
			_corrupt_look()
		else:
			_spawn_villagers(HAMLET_VILLAGERS)
		update_sign()
		return
	var place := GameData.text(GameData.race(race), "village_name", GameData.text(GameData.race(race), "display_name", race))
	var title := "%s, your camp" % place if is_home else place
	buildings = valley.world.build_village(global_position, is_home, title, race)
	if is_home and Run.state.flags.get("home_burned", false):
		ValleyWorld.burn_village(buildings)  # Count Fuckula's raid (the opening clip)
	if is_corrupted():
		_corrupt_look()
		_spawn_guards(EVIL_GUARDS, true)
	else:
		_spawn_villagers(VILLAGERS)
		_spawn_guards(GUARDS, false)
	update_sign()


func is_corrupted() -> bool:
	return Run.state.tribes.get(race, {}).get("status", "") == "corrupted"


func status() -> String:
	return "home" if is_home else Run.state.tribes.get(race, {}).get("status", "neutral")


## The sign over the village: name and how they feel about you.
func update_sign() -> void:
	var sign := buildings.get_node_or_null("Sign") as Label3D
	if sign == null or is_home:
		return
	var name := GameData.text(GameData.race(race), "display_name", race)
	if not hamlet.is_empty():
		var empty: bool = Run.state.regions.get(region, {}).get("corrupted", false)
		sign.text = "%s\n%s" % [hamlet.name, "abandoned" if empty else "%s fishers" % name]
		sign.modulate = Color(0.85, 0.6, 1.0) if empty else Color(0.75, 0.9, 1.0)
		return
	match status():
		"corrupted": sign.text = "%s tribe\nheld by Count Fuckula" % name
		"allied": sign.text = "%s tribe\nyour allies" % name
		_: sign.text = "%s tribe" % name
	sign.modulate = {"corrupted": Color(0.85, 0.6, 1.0), "allied": Color(0.5, 0.8, 1.0)}.get(status(), Color(1, 1, 1))


# ---------------------------------------------------------------- battles

## A raid on the village (befriending): the guards fight beside you, villagers flee.
func defend() -> void:
	for g in _living(guards):
		g.set_team(Enemy.Team.FRIENDLY)
	_flee(true)


## After a battle: survivors go back to their posts.
func calm() -> void:
	for g in _living(guards):
		g.remove_from_group(Combat.STRIKABLE)
		g.faction = ""
		g.set_team(Enemy.Team.NEUTRAL)
	_flee(false)
	update_sign()


## Count Fuckula took the region: villagers vanish, his sentries move in.
func corrupt() -> void:
	for u in _living(guards) + _living(villagers):
		u.queue_free()
	guards = []
	villagers = []
	_corrupt_look()
	if hamlet.is_empty():
		_spawn_guards(EVIL_GUARDS, true)
		for g in guards:
			g.set_dormant(_dormant)  # fallen while you're far away: they sleep like the village
	update_sign()


## A fight: villagers run into the nearest house and hide; afterwards they come out.
func _flee(on: bool) -> void:
	var houses: Array = buildings.get_children().filter(func(n): return n is Node3D and (n as Node3D).position.length() > 14.0 and (n as Node3D).position.length() < 54.0) if buildings != null else []
	for v in _living(villagers):
		v.flee_from = global_position if on else Vector3.INF
		v.hide_at = Vector3.INF
		if on and not houses.is_empty() and not v.unit_id.begins_with("animal_"):
			var nearest: Node3D = houses[0]
			for h in houses:
				if (h as Node3D).global_position.distance_to(v.global_position) < nearest.global_position.distance_to(v.global_position):
					nearest = h
			v.hide_at = nearest.global_position
		if not on:
			v.visible = not _dormant


func _corrupt_look() -> void:
	ValleyWorld.corrupt_village(buildings)


# ---------------------------------------------------------------- people

const LIVESTOCK := ["animal_cow", "animal_sheep", "animal_pig", "animal_llama", "animal_horse", "animal_sheep", "animal_pug"]


func _spawn_villagers(count: int) -> void:
	var members: Array = GameData.where("tribe_members", "race_id", race)
	if members.is_empty():
		return
	var spots: Dictionary = buildings.get_meta("spots", {})
	for i in count:
		var m: Dictionary = members[i % members.size()]
		var a := TAU * i / count + 0.4
		# Each to their place: the market, or out working the fields and yards.
		var work: Array = spots.get("market" if i % 3 == 0 else "yard", [])
		var at: Vector3 = work[i % work.size()] if not work.is_empty() else Vector3(cos(a), 0.0, sin(a)) * 8.0
		villagers.append(_unit(m.member_id, at, Enemy.Team.NEUTRAL, false))
	for i in count / 2:  # livestock (user, 2026-10-31): flees with the villagers, can't be hurt
		var a := TAU * i / maxi(count / 2, 1) + 1.1
		var pens: Array = spots.get("pens", [])
		var at: Vector3 = pens[i % pens.size()] + Vector3(i % 3 - 1, 0.0, i % 2) if not pens.is_empty() else Vector3(cos(a), 0.0, sin(a)) * 18.0
		villagers.append(_unit(LIVESTOCK[(i + region.length()) % LIVESTOCK.size()], at, Enemy.Team.NEUTRAL, false))


func _spawn_guards(counts: Dictionary, evil: bool) -> void:
	var army: Array = EncounterSystem.army_rows(EvilTribe.HORDE if evil else race)  # Count Fuckula's land: his horde
	var gates: Array = buildings.get_meta("spots", {}).get("gates", [])
	var posts := 0
	for n in counts.values():
		posts += n
	var i := 0
	for role in counts:
		var options: Array = army.filter(func(u): return u.get("role") == role)
		if options.is_empty():
			options = army.filter(func(u): return u.get("role") == "Melee")
		if options.is_empty():
			continue
		for k in counts[role]:
			var a := TAU * i / posts
			var at: Vector3 = gates[i] if i < gates.size() else Vector3(cos(a), 0.0, sin(a)) * 15.0  # one at each gate first
			var g := _unit(options[0].unit_id, at, Enemy.Team.HOSTILE if evil else Enemy.Team.NEUTRAL, evil)
			if evil:
				g.aggro_radius = SENTRY_AGGRO
			guards.append(g)
			i += 1


func _unit(unit_id: String, offset: Vector3, team: Enemy.Team, evil: bool) -> Enemy:
	var e := Enemy.new()
	e.setup(unit_id, valley.player, valley.director, team)
	e.corrupted = evil
	var p := global_position + offset
	p.y = valley.terrain.height(p.x, p.z) + 0.1
	e.post = p
	valley.add_child(e)
	e.global_position = p
	return e


## Pauses villages far from the player (unless a battle is on there).
func update_dormant(player_pos: Vector3, in_battle: bool) -> void:
	var sleep := not in_battle and global_position.distance_to(player_pos) > AWAKE_RANGE
	if sleep == _dormant:
		return
	_dormant = sleep
	for u in _living(guards) + _living(villagers):
		u.set_dormant(sleep)


static func _living(units: Array) -> Array:
	return units.filter(func(u): return is_instance_valid(u) and not u.is_dead())
