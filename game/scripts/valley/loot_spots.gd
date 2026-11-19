class_name LootSpots
extends Node
## Caves and towers across the valley (ValleyTerrain.landmarks with a "chest"): each has a
## chest to find and guards around it (user, 2026-11-03). What's opened stays opened in a
## saved run (RunState.flags.looted).
## Towers are a climb (user, 2026-11-05, like the radio towers in open-world shooters): no
## stairs, a scaffold of wooden platforms to jump up, a lever to find that swings a plank
## across the one gap too wide to jump, bandits at the foot and on the way up, and from the
## top you see far: the map's fog lifts around the tower.

const OPEN_RANGE := 4.0
const GUARD_DISTANCE := 26.0  ## from the structure, out in front of its entrance or ramp
## Mounts stay out of: a cave's box (half width, back, past the mouth) and a circle around a tower.
const CAVE_ZONE := Vector3(9.5, -23.0, 24.0)
const TOWER_ZONE := 13.0
## The climb, in the tower's own frame: [angle in degrees from the door side, distance from the
## middle, height of the top, length, width]. In order from the ground up; ROUTE[GAP] can only
## be reached over the plank. Walking jumps: up to about 3 m across and 1.5 m up; no jump
## clears 3.4 m up, even sprinting.
## Made easier (user, 2026-11-09): about 1 m up per step, closer together, bigger to land on.
const ROUTE := [
	[-16.0, 9.4, 0.8, 1.7, 1.7], [0.0, 8.6, 1.65, 1.7, 1.7],  # two crates to get started
	[22.0, 6.7, 2.6, 2.9, 2.5], [48.0, 6.7, 3.55, 2.9, 2.5], [74.0, 6.7, 4.5, 2.9, 2.5], [100.0, 6.7, 5.45, 2.9, 2.5],
	[126.0, 6.7, 6.4, 2.9, 2.5],
	[156.0, 7.0, 7.3, 4.2, 3.4],  # the landing: a guard, and the gap (3.6 m up: higher than any jump)
	[222.0, 6.7, 10.9, 3.0, 2.6], [247.0, 7.0, 11.9, 3.0, 2.6], [272.0, 7.4, 12.9, 3.0, 2.6], [297.0, 7.8, 13.9, 3.0, 2.6],
	[322.0, 8.2, 14.9, 3.0, 2.6],  # then a step onto the roof, through the gap in its battlements
]
const LANDING := 7
const GAP := 8
## Out from the landing and down: the lever that lowers the plank.
const LEVER_WAY := [[182.0, 10.0, 6.8, 2.4, 2.4], [204.0, 11.4, 7.1, 2.6, 2.6]]
## A hollow tower (variant "hollow"): you go in at the door and climb steps around the inside
## wall, up through a hatch in the roof. No lever: the climb is the way in.
const INSIDE := [
	[80.0, 2.5, 0.95, 1.8, 1.6], [110.0, 2.5, 1.9, 1.8, 1.6], [140.0, 2.5, 2.85, 1.8, 1.6], [170.0, 2.5, 3.8, 1.8, 1.6],
	[200.0, 2.5, 4.75, 1.8, 1.6], [230.0, 2.5, 5.7, 1.8, 1.6], [260.0, 2.5, 6.65, 1.8, 1.6], [290.0, 2.5, 7.6, 1.8, 1.6],
	[320.0, 2.5, 8.55, 1.8, 1.6], [350.0, 2.5, 9.5, 1.8, 1.6], [380.0, 2.5, 10.45, 1.8, 1.6], [410.0, 2.5, 11.4, 1.8, 1.6],
	[440.0, 2.5, 12.35, 1.8, 1.6], [470.0, 2.5, 13.3, 1.8, 1.6], [500.0, 2.5, 14.25, 1.8, 1.6], [530.0, 2.5, 15.2, 1.8, 1.6],
]


## This tower's climb: the usual one, its mirror image, or the steps inside a hollow tower.
static func route(spot: Dictionary) -> Array:
	match spot.get("variant", "plain"):
		"hollow": return INSIDE
		"mirror": return ROUTE.map(func(s): return [-float(s[0])] + s.slice(1))
	return ROUTE


static func lever_way(spot: Dictionary) -> Array:
	if spot.get("variant", "plain") == "hollow":
		return []
	return LEVER_WAY.map(func(s): return [-float(s[0])] + s.slice(1)) if spot.get("variant") == "mirror" else LEVER_WAY
const ROOF_Y := 16.0
## How far the map clears around a tower once you've reached its top.
const TOWER_VIEW := 650.0

var valley: Node  ## the Valley scene
var spots: Array = []  ## [{id, kind, pos: Vector3, base: Vector3, angle, chest: Node3D, opened}]
## towers also: {lever: Vector3, handle, plank: Node3D, plank_down, top_seen}
var _wood: StandardMaterial3D
var _crate: StandardMaterial3D
var _zone_left := 0.0


func _ready() -> void:
	var looted: Array = Run.state.flags.get("looted", [])
	var index := 0
	for l in valley.terrain.landmarks:
		if not l.has("chest"):
			continue
		var base := Vector3(l.pos.x, l.get("y", valley.terrain.height(l.pos.x, l.pos.y)), l.pos.y)
		var at: Vector3 = base + (l.chest as Vector3).rotated(Vector3.UP, l.angle)
		if l.kind == "cave":
			at.y = valley.terrain.height(at.x, at.z) + 0.1  # on the cave's sunk floor
		var id := "%s_%d" % [l.kind, index]
		index += 1
		var opened: bool = id in looted
		var spot := {"id": id, "kind": l.kind, "pos": at, "base": base, "angle": l.angle, "chest": _chest("chest_open" if opened else "chest", at, l.angle), "opened": opened,
			"variant": l.get("variant", "plain")}
		spots.append(spot)
		if l.kind == "cave":
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.75, 0.45)
			light.light_energy = 2.5
			light.omni_range = 14.0
			light.position = at + Vector3.UP * 2.5
			add_child(light)
		if l.kind == "tower":
			_build_climb(spot, opened)
		if not opened and valley.battle.is_empty():  # a custom battle's field stays clear
			var guard_at: Vector3 = base + Vector3(0.0, 0.0, GUARD_DISTANCE).rotated(Vector3.UP, l.angle)
			guard_at.y = valley.terrain.height(guard_at.x, guard_at.z)
			if l.kind == "tower":
				valley.wilds.groups.append(_bandits(spot, guard_at))
		if l.kind == "cave" and valley.battle.is_empty() and not id in Run.state.flags.get("dungeons_cleared", []):
			spot.dungeon = _cave_dwellers(spot)
			valley.wilds.groups.append(spot.dungeon)


## No mounts in caves or towers (user, 2026-11-03): you get down at the entrance, and it waits
## outside until you come back out.
func _physics_process(delta: float) -> void:
	_zone_left -= delta
	if _zone_left > 0.0:
		return
	_zone_left = 0.15
	var player: Player = valley.player
	_check_dungeons(player.global_position)
	_check_tower_tops(player.global_position)
	player.no_mount = in_mount_free_zone(player.global_position)
	if player.no_mount and player.mount != null and player.mount.riding:
		player.mount.dismount("Your mount won't go in. It waits outside.")


func in_mount_free_zone(p: Vector3) -> bool:
	for spot in spots:
		var rel: Vector3 = (p - spot.base).rotated(Vector3.UP, -float(spot.angle))
		if absf(rel.x) > 26.0 or absf(rel.z) > 26.0:
			continue
		if spot.kind == "tower":
			if Vector2(rel.x, rel.z).length() < TOWER_ZONE:
				return true
		elif _in_cave(spot, p):
			return true
	return false


func _chest(model: String, at: Vector3, angle: float) -> Node3D:
	var node: Node3D = (load(ValleyWorld.VILLAGE + model + ".glb") as PackedScene).instantiate()
	add_child(node)
	CharacterModel.use_vertex_colors(node)
	node.global_position = at
	node.rotation.y = angle
	return node


# ---------------------------------------------------------------- tower climbs

## A point in a tower's frame (angle from its door side, distance out, height) in the world.
static func tower_point(spot: Dictionary, deg: float, r: float, y: float) -> Vector3:
	var a := deg_to_rad(deg)
	return spot.base + Vector3(sin(a) * r, y, cos(a) * r).rotated(Vector3.UP, spot.angle)


func _build_climb(spot: Dictionary, opened: bool) -> void:
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.albedo_color = Color(0.46, 0.32, 0.19)
		_wood.roughness = 0.95
		_crate = StandardMaterial3D.new()
		_crate.albedo_color = Color(0.58, 0.43, 0.25)
		_crate.roughness = 0.95
	var way := route(spot)
	if spot.variant == "hollow":
		for step in way:
			_platform(spot, step, false, true)
		var light := OmniLight3D.new()  # a lantern hung inside, so the steps can be seen
		light.light_color = Color(1.0, 0.78, 0.5)
		light.light_energy = 1.6
		light.omni_range = 12.0
		add_child(light)
		light.global_position = spot.base + Vector3.UP * 8.0
		spot["plank_down"] = true
		spot["top_seen"] = opened
		return
	for i in way.size():
		_platform(spot, way[i], i < 2)
	var levers := lever_way(spot)
	for step in levers:
		_platform(spot, step, false)
	# The lever, on the last platform out.
	var last: Array = levers[-1]
	spot["lever"] = tower_point(spot, last[0], last[1], last[2])
	var post := _box(Vector3(0.2, 1.1, 0.2), _wood)
	add_child(post)
	post.global_position = spot.lever + Vector3.UP * 0.55
	var handle := _box(Vector3(0.12, 0.8, 0.12), _crate)
	post.add_child(handle)
	handle.position = Vector3(0.0, 0.45, 0.0)
	handle.rotation.z = -0.6
	spot["handle"] = handle
	# The plank, hinged at the far side of the gap: standing up until the lever drops it across.
	var from: Vector3 = tower_point(spot, way[LANDING][0], way[LANDING][1], way[LANDING][2])
	var to: Vector3 = tower_point(spot, way[GAP][0], way[GAP][1], way[GAP][2])
	# The body itself turns on the hinge (a moving parent wouldn't carry its collision along).
	var hinge := AnimatableBody3D.new()
	hinge.collision_layer = 0b001
	hinge.sync_to_physics = false  # placed and turned from code, not by the physics step
	add_child(hinge)
	hinge.global_position = to
	hinge.look_at(from, Vector3.UP)  # -Z toward the landing
	var length := from.distance_to(to)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.2, length)
	shape.shape = box
	shape.position = Vector3(0.0, -0.1, -length * 0.5)
	hinge.add_child(shape)
	var board := _box(box.size, _wood)
	board.position = shape.position
	hinge.add_child(board)
	spot["plank"] = hinge
	spot["plank_down"] = opened
	if not opened:
		hinge.rotation.x += PLANK_UP  # standing up, out of the way
	spot["top_seen"] = opened


const PLANK_UP := 1.45


## One platform (or crate): a box to stand on, a beam back to the wall and a post to the ground.
func _platform(spot: Dictionary, step: Array, crate: bool, inside := false) -> void:
	var top: Vector3 = tower_point(spot, step[0], step[1], step[2])
	var size := Vector3(step[3], 0.3 if not crate else float(step[2]), step[4])
	var body := StaticBody3D.new()
	body.collision_layer = 0b001
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(_box(size, _crate if crate else _wood))
	add_child(body)
	body.global_position = top - Vector3.UP * size.y * 0.5
	body.rotation.y = spot.angle + deg_to_rad(step[0])
	if crate or inside:  # inside a tower, the steps are set into the wall
		return
	var tall: float = top.y - float(spot.base.y)
	var post := _box(Vector3(0.22, tall, 0.22), _wood)
	body.add_child(post)
	post.position = Vector3(0.0, -tall * 0.5, step[4] * 0.45)
	var reach: float = float(step[1]) - 4.0 - float(step[4]) * 0.5
	var beam := _box(Vector3(0.2, 0.2, maxf(reach, 0.2)), _wood)
	body.add_child(beam)
	beam.position = Vector3(0.0, -0.3, -float(step[4]) * 0.5 - reach * 0.5)


func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	return m


# ---------------------------------------------------------------- caves as dungeons

## A cave is a dungeon (user, 2026-11-06, like the optional dungeons of open-world action RPGs):
## the region's own hunters wait along the tunnel, and its strongest, a boss, guards the chest.
## Clear them all for XP, supplies and a godly gift or a weapon (WorldEvents.dungeon_reward).
## Spots along the tunnel, in the cave's frame (x across, z from the mouth at +z to the chest at -16).
const CAVE_POSTS := [Vector3(-2.5, 0, 13), Vector3(2.5, 0, 11), Vector3(-3, 0, 3), Vector3(0, 0, 5), Vector3(3, 0, 2), Vector3(-2, 0, -6), Vector3(2.5, 0, -7)]
const CAVE_BOSS_POST := Vector3(0, 0, -11)
const CAVE_AGGRO := 13.0  ## they notice you inside, not from the meadow outside


func _cave_dwellers(spot: Dictionary) -> Dictionary:
	var biome := GameData.text(GameData.row("valley_regions", valley.terrain.region_at(spot.base.x, spot.base.z)), "biome")
	var kinds: Array = Wilds.native_hunters(biome).filter(func(id): return not GameData.text(GameData.unit(id), "rig_type").begins_with("Flying"))
	if kinds.is_empty():
		kinds = ["barb_raider", "barb_slinger"]
	var strongest: String = kinds[0]
	for id in kinds:
		if GameData.num(GameData.unit(id), "hp") > GameData.num(GameData.unit(strongest), "hp"):
			strongest = id
	var units: Array = []
	for k in CAVE_POSTS.size() + 1:
		var boss: bool = k == CAVE_POSTS.size()
		var local: Vector3 = CAVE_BOSS_POST if boss else CAVE_POSTS[k]
		var at: Vector3 = spot.base + local.rotated(Vector3.UP, spot.angle) + Vector3.UP * 0.3
		var e := Enemy.new()
		e.setup(strongest if boss else kinds[k % kinds.size()], valley.player, valley.director, Enemy.Team.HOSTILE)
		if boss:
			e.make_mini_boss()
		e.post = at
		e.aggro_radius = CAVE_AGGRO
		e.roam_radius = 1.5
		valley.add_child(e)
		e.global_position = at
		units.append(e)
	return {"center": spot.base, "units": units, "respawn_left": INF, "asleep": false, "water": false}  # cleared stays cleared


## You walk in: a warning. Everyone in it dead: the reward (if you were there) and it stays cleared.
func _check_dungeons(p: Vector3) -> void:
	for spot in spots:
		if not spot.has("dungeon") or spot.get("cleared", false):
			continue
		var near: bool = spot.base.distance_to(p) < 30.0
		if near and not spot.get("warned", false) and _in_cave(spot, p):
			spot.warned = true
			valley.hud.show_message("Something lurks in the dark of this cave. Clear it for a reward.", 3.0)
		if spot.dungeon.units.any(func(u): return is_instance_valid(u) and not u.is_dead()):
			continue
		spot.cleared = true
		var cleared: Array = Run.state.flags.get("dungeons_cleared", [])
		cleared.append(spot.id)
		Run.state.flags["dungeons_cleared"] = cleared
		if spot.base.distance_to(p) < 60.0:
			valley.events.dungeon_reward("The cave")


func _in_cave(spot: Dictionary, p: Vector3) -> bool:
	var rel: Vector3 = (p - spot.base).rotated(Vector3.UP, -float(spot.angle))
	return absf(rel.x) < CAVE_ZONE.x and rel.z > CAVE_ZONE.y and rel.z < CAVE_ZONE.z


## Bandits guard a tower (user, 2026-11-05): a few at its foot, a slinger on the landing and
## one on the roof. One group, so they sleep and wake with the rest of the wilds.
func _bandits(spot: Dictionary, foot: Vector3) -> Dictionary:
	var units: Array = []
	var posts := [["barb_raider", foot + Vector3(-3, 0, 0)], ["barb_raider", foot + Vector3(3, 0, 1)], ["barb_slinger", foot + Vector3(0, 0, -3)],
		["barb_slinger", tower_point(spot, route(spot)[LANDING][0], route(spot)[LANDING][1], route(spot)[LANDING][2] + 0.1)],
		["barb_raider", tower_point(spot, 180.0, 3.0, ROOF_Y + 0.1)]]
	for entry in posts:
		var at: Vector3 = entry[1]
		var e := Enemy.new()
		e.setup(entry[0], valley.player, valley.director, Enemy.Team.HOSTILE)
		e.post = at
		e.aggro_radius = Wilds.AGGRO
		e.roam_radius = 0.0 if at.y > foot.y + 2.0 else Wilds.ROAM * 0.3
		valley.add_child(e)
		e.global_position = at
		units.append(e)
	return {"center": foot, "units": units, "respawn_left": Wilds.RESPAWN_SECONDS, "asleep": false, "water": false}


func _near_lever() -> Dictionary:
	var p: Vector3 = valley.player.global_position
	for spot in spots:
		if spot.has("lever") and not spot.plank_down and (spot.lever as Vector3).distance_to(p) < 2.5:
			return spot
	return {}


func pull_lever(spot: Dictionary) -> void:
	spot.plank_down = true
	var tw := create_tween()
	tw.tween_property(spot.handle, "rotation:z", 0.6, 0.3)
	tw.tween_property(spot.plank, "rotation:x", (spot.plank as Node3D).rotation.x - PLANK_UP, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	valley.hud.show_message("Somewhere above, a plank swings down across the gap.", 3.0)


## Reached a tower's roof: the land around it shows on your map.
func _check_tower_tops(p: Vector3) -> void:
	for spot in spots:
		if spot.kind != "tower" or spot.top_seen or p.y < float(spot.base.y) + ROOF_Y - 0.5:
			continue
		if Vector2(p.x - spot.base.x, p.z - spot.base.z).length() < 7.0:
			spot.top_seen = true
			if valley.fog != null and valley.fog.reveal(Vector2(spot.base.x, spot.base.z), TOWER_VIEW):
				Run.state.flags["seen"] = valley.fog.save_text()
			valley.hud.show_message("From up here you can see far across the valley. Your map shows it now.", 3.5)


func _nearest() -> Dictionary:
	var p: Vector3 = valley.player.global_position
	for spot in spots:
		if not spot.opened and spot.pos.distance_to(p) < OPEN_RANGE:
			return spot
	return {}


func prompt() -> String:
	if valley.hud.is_choosing():
		return ""
	if not _near_lever().is_empty():
		return "[F]  Pull the lever"
	return "[F]  Open the chest" if not _nearest().is_empty() else ""


## Opens the chest you're standing at. False if there's none.
func interact() -> bool:
	var lever := _near_lever()
	if not lever.is_empty():
		pull_lever(lever)
		return true
	var spot := _nearest()
	if spot.is_empty():
		return false
	open(spot)
	return true


func open(spot: Dictionary) -> void:
	Run.note("caves_and_towers")
	var t: CombatTuning = GameData.tuning
	spot.opened = true
	var angle: float = spot.chest.rotation.y
	spot.chest.queue_free()
	spot.chest = _chest("chest_open", spot.pos, angle)
	var looted: Array = Run.state.flags.get("looted", [])
	looted.append(spot.id)
	Run.state.flags["looted"] = looted
	# A tower's chest is the harder climb, and pays better.
	var tower: bool = spot.kind == "tower"
	var supplies: int = RunRng.randi_range(t.loot_supplies_min, t.loot_supplies_max) * (2 if tower else 1)
	Run.state.supplies += supplies
	var player: Node = valley.player
	player.health.heal(player.health.max_hp * t.loot_heal_pct / 100.0)
	valley.hud.show_message("You found %d supplies and a healing draught." % supplies, 3.0)
	Vfx.burst(spot.pos + Vector3.UP, 1.5, Color(1.0, 0.85, 0.35, 0.7), 0.4)
	valley.give_xp(t.loot_xp * (2.0 if tower else 1.0))
	if RunRng.chance(t.loot_gift_chance_tower if tower else t.loot_gift_chance_cave):
		valley.events._offer_gift(Run.state.god_id)
	elif RunRng.chance(t.loot_weapon_chance):
		valley.offer_weapon()
	Run.checkpoint("loot_" + str(spot.id))
