class_name GrassField
extends Node3D
## Grass that covers the whole ground around you in the biomes with at least
## ValleyWorld.CARPET_COVER `cover` (ValleyTerrain.BIOMES). The tile is the user's own grass:
## their grass.blend plane, made into blades by make_grass_from_blend.py (user, 2026-11-10:
## "use my tile"; it replaced the shell grass). Covering the
## whole 2 x 4 km valley would be far too many triangles, so the carpet only
## exists within RADIUS of you: cells of carpet tiles (the user's grass,
## models/own/world/grass_carpet.glb) are built as you walk in and freed as you
## walk out. Farther away the ground color and ValleyWorld's scattered patches
## carry the look. Visual only: no collision, no gameplay.

const MODEL := "grass_carpet"
## Meters per cell (one MultiMesh each) and per carpet tile (the tile's size).
const CELL := 8.0
const TILE := 2.0
## Grass shows this far (96 m: 3x the first 32 m, user 2026-10-29). Within
## FULL it's the full carpet; beyond, every tile is the sparser MODEL_FAR (a third
## of the blades): even, not patchy (user, 2026-10-30), about 1 million triangles.
const RADIUS := 96.0
const FULL := 32.0
const MODEL_FAR := "grass_carpet_far"
## Cells built per frame, so walking or riding never stalls a frame.
const BUILDS_PER_FRAME := 6

var world: ValleyWorld
var target: Node3D
var _cells := {}  # Vector2i -> MultiMeshInstance3D, or null for a cell with no carpet


func _process(_delta: float) -> void:
	if not is_instance_valid(target) or world == null:
		return
	var p := Vector2(target.global_position.x, target.global_position.z)
	for key in _cells.keys():
		var d := _center(key).distance_to(p)
		# Freed when out of range, and a thinned far cell rebuilt full as you come close.
		if d > RADIUS + CELL or (d < FULL and _cells[key] != null and _cells[key].has_meta("far")):
			if _cells[key] != null:
				_cells[key].queue_free()
			_cells.erase(key)
	var reach := ceili(RADIUS / CELL)
	var here := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var wanted: Array = []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var key := here + Vector2i(dx, dz)
			if not _cells.has(key) and _center(key).distance_to(p) <= RADIUS + CELL * 0.5:
				wanted.append(key)
	wanted.sort_custom(func(a, b): return _center(a).distance_squared_to(p) < _center(b).distance_squared_to(p))
	for key in wanted.slice(0, BUILDS_PER_FRAME):
		_cells[key] = _build(key)


func cell_count() -> int:
	return _cells.values().filter(func(c): return c != null).size()


func _center(key: Vector2i) -> Vector2:
	return (Vector2(key) + Vector2(0.5, 0.5)) * CELL


## One cell's carpet: tiles laid edge to edge, tilted to the slope, turned by
## quarter turns so the seams don't line up. Null if none of it is covered.
func _build(key: Vector2i) -> MultiMeshInstance3D:
	var far := _center(key).distance_to(Vector2(target.global_position.x, target.global_position.z)) > FULL + CELL
	var model: Array = world.plant_model(MODEL_FAR if far else MODEL)
	if model.is_empty():
		return null
	var t := world.terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var items: Array = []
	var per := int(CELL / TILE)
	for i in per:
		for j in per:
			var x := key.x * CELL + (i + 0.5) * TILE
			var z := key.y * CELL + (j + 0.5) * TILE
			var style := t.style_at(x, z)
			if float(style.get("cover", 0.0)) < ValleyWorld.CARPET_COVER or ValleyTerrain.shape_q(x, z) > ValleyTerrain.RIM_Q:
				continue  # not past the mountains, outside the valley (user, 2026-11-08)
			var y := world._ground_y(x, z)
			if y < ValleyTerrain.WATER_Y + 0.3 or t.in_lake(x, z, y) or t.near_bridge(x, z, 3.0):
				continue
			var normal := Vector3(world._ground_y(x - 1.0, z) - world._ground_y(x + 1.0, z), 2.0,
				world._ground_y(x, z - 1.0) - world._ground_y(x, z + 1.0)).normalized()
			var up := Basis(Quaternion(Vector3.UP, normal))
			var basis := up * Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5)
			items.append([Transform3D(basis, Vector3(x, y - 0.02, z)) * model[1], style.tint])
	if items.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = model[0]
	mm.instance_count = items.size()
	for n in items.size():
		mm.set_instance_transform(n, items[n][0])
		mm.set_instance_color(n, items[n][1])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = model[2]
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if far:
		inst.set_meta("far", true)
	add_child(inst)
	return inst
