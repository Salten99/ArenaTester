class_name ThrowableField
extends Node
## Loose boulders and fallen branches around you in the valley (combat feel plan, user 2026-11-18):
## the ground is cut into item_field_cell squares; each square within item_field_radius of you may
## hold one item, rolled from its own seed (a boulder by the biome's "rocks", a branch by its
## "trees"), so a square always holds the same one. Squares you leave are cleared; a square whose
## item was thrown stays empty until the valley is loaded again.

var world: ValleyWorld
var target: Node3D
var _items := {}  ## cell -> Throwable
var _used := {}  ## cells whose item was thrown or carried off
var _wait := 0.0


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or world == null or not is_instance_valid(target):
		return
	_wait = 0.5
	update()


func update() -> void:
	var t: CombatTuning = GameData.tuning
	var cell := t.item_field_cell
	var here := Vector2(target.global_position.x, target.global_position.z)
	var r := ceili(t.item_field_radius / cell)
	var center := Vector2i(floori(here.x / cell), floori(here.y / cell))
	var keep := {}
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var key := center + Vector2i(dx, dz)
			if ((Vector2(key) + Vector2(0.5, 0.5)) * cell).distance_to(here) > t.item_field_radius:
				continue
			keep[key] = true
			if not _items.has(key) and not _used.has(key):
				_items[key] = _roll(key)
	for key in _items.keys():
		var it: Variant = _items[key]
		if it != null and (not is_instance_valid(it) or it.is_dead() or it.held_by != null or it._flying):
			_used[key] = true  # taken or thrown: this square stays empty
			_items.erase(key)
		elif not keep.has(key):
			if it != null:
				it.queue_free()
			_items.erase(key)


## The item a square holds, or null. Same answer every time for the same square and run.
func _roll(key: Vector2i) -> Throwable:
	var t: CombatTuning = GameData.tuning
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, Run.state.seed if Run.state != null else 0, "throwables"])
	var x := (key.x + rng.randf()) * t.item_field_cell
	var z := (key.y + rng.randf()) * t.item_field_cell
	var terrain := world.terrain
	if ValleyTerrain.shape_q(x, z) > ValleyTerrain.RIM_Q or terrain.near_road(x, z, 2.0):
		return null
	var ground := terrain.height(x, z)
	if terrain.water_surface(x, z) > ground:
		return null
	var style := terrain.style_at(x, z)
	var boulder := t.item_field_chance * float(style.get("rocks", 0.1)) * 2.0
	var branch := t.item_field_chance * float(style.get("trees", 0.2))
	var roll := rng.randf()
	var kind := "boulder" if roll < boulder else ("branch" if roll < boulder + branch else "")
	if kind == "":
		return null
	return Throwable.make(kind, world, Vector3(x, ground, z), rng.randf() * TAU)


## Items lying around right now (tests).
func count() -> int:
	return _items.values().filter(func(i): return i != null and is_instance_valid(i)).size()
