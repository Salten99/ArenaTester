class_name Breakable
extends Node3D
## A wooden prop (barrel, crate, hay, cart, market stand) that breaks when hit (user,
## 2026-11-08): it's swapped for its chunks (models/gen/world/<name>_broken.glb, made by
## tools/blender/make_props.py), which fly off from the hit, lie a while, then shrink away.
## Hits come from your swings, abilities and a charging mount (smash_near).
## Buildings break too (user, 2026-11-09): a small one comes down whole after a few blows; a
## big one (wider than BIG) only loses the chunk you hit. Either way it's cut up the first
## time it's hit into pieces of about CHUNK, each with its own box, so the hole is real.

const KINDS := ["barrel", "crate", "hay", "cart", "market_stand"]
const PIECES_LAST := 5.0  ## seconds the chunks lie about before they shrink away
const PUSH := 5.0  ## m/s the chunks fly from the hit
const UP := 3.0  ## and up

var kind := ""
var _model: Node3D
var _radius := -1.0  ## flat reach of a prop (m, measured on first use), or a building's quick-check reach

const BIG := 9.0  ## m: a building wider than this loses chunks; a smaller one comes down whole
const HIT_GAP_MS := 300
const CHUNK := 2.4  ## m: the size of a building's pieces
const FLYING := 10  ## at most this many pieces fly off at once; the rest crumble where they are
var _shape: CollisionShape3D  ## a building's box in ValleyWorld's solid body, until it's cut up
var _big := false
var _hits_left := 0
var _hit_at := -1000  ## Combat.now_msec() of the last strike
var _chunks: Array = []  ## [{mesh: MeshInstance3D, shape: CollisionShape3D, center: Vector3}] once cut up
var _body: StaticBody3D


## Makes `model` (a placed prop) breakable if it's one of KINDS with chunks made.
static func attach(model: Node3D, prop: String) -> void:
	if not prop in KINDS or not ResourceLoader.exists(_broken_path(prop)):
		return
	var b := Breakable.new()
	b.kind = prop
	b._model = model
	model.add_child(b)


## Makes a building breakable. `shape` is its box (`size`, m) in ValleyWorld's solid body.
static func attach_building(model: Node3D, shape: CollisionShape3D, size: Vector3) -> void:
	var b := Breakable.new()
	b.kind = "building"
	b._model = model
	b._shape = shape
	b._big = maxf(size.x, size.z) > BIG
	b._hits_left = 2 + int(maxf(size.x, size.z) / 3.0)
	b._radius = size.length()  # a whole diagonal: covers a box set off from the model's origin
	model.add_child(b)


static func _broken_path(prop: String) -> String:
	return ValleyWorld.VILLAGE + prop + "_broken.glb"


func _ready() -> void:
	add_to_group("breakables")


## Breaks every prop within `radius` m (flat) of `at`; the chunks fly away from `from`.
## Returns how many broke.
static func smash_near(tree: SceneTree, at: Vector3, radius: float, from: Vector3) -> int:
	var n := 0
	for b: Breakable in tree.get_nodes_in_group("breakables"):
		if b.kind == "building":
			if b.global_position.distance_to(at) > b._radius + radius + CHUNK:
				continue  # quick: nowhere near this building
			var spot := b.nearest(at)
			if spot.distance_to(at) <= radius + (0.6 if b._chunks.is_empty() else CHUNK * 0.7):  # a piece's middle sits inside it
				b.strike(spot, from)
				n += 1
			continue
		var d := b.global_position - at
		d.y = 0.0
		if d.length() <= radius + b.reach():
			b.smash(from)
			n += 1
	return n


## The point of this building nearest `at`: on its box, or the middle of its nearest piece.
func nearest(at: Vector3) -> Vector3:
	if _chunks.is_empty():
		if not is_instance_valid(_shape):
			return Vector3.INF
		var half: Vector3 = (_shape.shape as BoxShape3D).size * 0.5
		var local := _shape.global_transform.affine_inverse() * at
		return _shape.global_transform * local.clamp(-half, half)
	var best := Vector3.INF
	for c in _chunks:
		if (c.center as Vector3).distance_to(at) < best.distance_to(at):
			best = c.center
	return best


## A blow at `spot` (on the building) from `from`.
func strike(spot: Vector3, from: Vector3) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or Combat.now_msec() - _hit_at < HIT_GAP_MS:
		return  # a gallop or a line of hits counts once, not every frame or step
	_hit_at = Combat.now_msec()
	Vfx.burst(spot, 1.2, Color(0.6, 0.55, 0.45, 0.6), 0.35)
	Combat.shake(0.12)
	if _chunks.is_empty():
		_cut_up()
	if _big:  # only what was hit comes away
		var near := _chunks.filter(func(c): return (c.center as Vector3).distance_to(spot) < CHUNK * 1.1)
		if near.is_empty():
			near = [_chunks.reduce(func(m, c): return c if (c.center as Vector3).distance_to(spot) < (m.center as Vector3).distance_to(spot) else m)]
		_knock_off(near, from)
		return
	_hits_left -= 1
	if _hits_left <= 0:  # it comes down
		Vfx.burst(spot, 3.0, Color(0.6, 0.55, 0.45, 0.5), 0.8)
		Combat.shake(0.35)
		_knock_off(_chunks.duplicate(), from)


## Swaps the building's meshes and box for pieces of about CHUNK, each with its own box.
func _cut_up() -> void:
	var cells := {}  # Vector3i -> {Material: [verts, normals, colors]}
	var overlay: Material = null
	var view := 0.0
	for m: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if overlay == null:
			overlay = m.material_overlay
		view = maxf(view, m.visibility_range_end)
		var xf := m.global_transform
		var turn := xf.basis.inverse().transposed()
		for s in m.mesh.get_surface_count():
			var arrays := m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals = arrays[Mesh.ARRAY_NORMAL]
			var colors = arrays[Mesh.ARRAY_COLOR]
			var index = arrays[Mesh.ARRAY_INDEX]
			var mat := m.get_active_material(s)
			var count: int = index.size() if index != null and index.size() > 0 else verts.size()
			for t in range(0, count - 2, 3):
				var ids := [index[t], index[t + 1], index[t + 2]] if index != null and index.size() > 0 else [t, t + 1, t + 2]
				var world: Array = ids.map(func(i): return xf * verts[i])
				var mid: Vector3 = (world[0] + world[1] + world[2]) / 3.0
				var key := Vector3i(floori(mid.x / CHUNK), floori(mid.y / CHUNK), floori(mid.z / CHUNK))
				if not cells.has(key):
					cells[key] = {}
				if not cells[key].has(mat):
					cells[key][mat] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
				var into: Array = cells[key][mat]
				for k in 3:
					into[0].append(world[k])
					into[1].append((turn * (normals[ids[k]] as Vector3)).normalized() if normals != null and normals.size() > 0 else Vector3.UP)
					into[2].append(colors[ids[k]] if colors != null and colors.size() > 0 else Color.WHITE)
	_body = StaticBody3D.new()
	_body.collision_layer = 0b001
	_model.get_parent().add_child(_body)
	_body.global_transform = Transform3D.IDENTITY
	for key in cells:
		var mesh := ArrayMesh.new()
		var box := AABB()
		var first := true
		for mat in cells[key]:
			var data: Array = cells[key][mat]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = data[0]
			arrays[Mesh.ARRAY_NORMAL] = data[1]
			arrays[Mesh.ARRAY_COLOR] = data[2]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
			for p: Vector3 in data[0]:
				box = AABB(p, Vector3.ZERO) if first else box.expand(p)
				first = false
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.material_overlay = overlay
		piece.visibility_range_end = view
		_body.add_child(piece)
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = box.size.max(Vector3.ONE * 0.3)
		shape.shape = bs
		shape.position = box.get_center()
		_body.add_child(shape)
		_chunks.append({"mesh": piece, "shape": shape, "center": box.get_center()})
	if is_instance_valid(_shape):
		_shape.queue_free()
	reparent(_body)  # the model goes; this stays with the pieces
	_model.queue_free()
	_model = _body


## Takes `pieces` off: the nearest few fly away from `from`, the rest crumble where they are.
func _knock_off(pieces: Array, from: Vector3) -> void:
	pieces.sort_custom(func(a, b): return (a.center as Vector3).distance_to(from) < (b.center as Vector3).distance_to(from))
	for i in pieces.size():
		var c: Dictionary = pieces[i]
		_chunks.erase(c)
		c.shape.queue_free()
		var piece: MeshInstance3D = c.mesh
		if i >= FLYING:
			var tw := piece.create_tween()
			tw.tween_property(piece, "scale", Vector3.ONE * 0.01, 0.4)
			tw.tween_callback(piece.queue_free)
			continue
		var center: Vector3 = c.center
		var body := RigidBody3D.new()
		body.collision_layer = CharacterModel.RAGDOLL_LAYER
		body.collision_mask = 0b001
		var shape := CollisionShape3D.new()
		var points := PackedVector3Array()
		for p in (piece.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D).points:
			points.append(p - center)
		var convex := ConvexPolygonShape3D.new()
		convex.points = points
		shape.shape = convex
		body.add_child(shape)
		piece.get_parent().remove_child(piece)
		body.add_child(piece)
		piece.position = -center
		_body.get_parent().add_child(body)
		body.global_position = center
		var out := center - from
		out.y = 0.0
		var dir := out.normalized() if out.length() > 0.01 else Vector3.FORWARD
		body.linear_velocity = dir * PUSH * randf_range(0.5, 1.1) + Vector3.UP * UP * randf_range(0.4, 1.0)
		body.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
		var tw := body.create_tween()
		tw.tween_interval(PIECES_LAST * randf_range(0.8, 1.2))
		tw.tween_property(piece, "scale", Vector3.ONE * 0.01, 0.6)
		tw.tween_callback(body.queue_free)
	if _chunks.is_empty():  # nothing left standing
		remove_from_group("breakables")
		get_tree().create_timer(0.5, false).timeout.connect(_body.queue_free)  # after the last pieces have shrunk away


## Breaks props in a strip `width` m either side of the line from `start` along `dir`.
static func smash_line(tree: SceneTree, start: Vector3, dir: Vector3, length: float, width: float) -> int:
	var n := 0
	var steps := ceili(length / maxf(width, 0.25))
	for k in steps + 1:
		n += smash_near(tree, start + dir * length * k / steps, width, start)
	return n


func reach() -> float:
	if _radius < 0.0:
		var box := AABB()
		for m: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
			box = box.merge(m.global_transform * m.get_aabb()) if box.size != Vector3.ZERO else m.global_transform * m.get_aabb()
		_radius = maxf(box.size.x, box.size.z) * 0.5
	return _radius


func smash(from: Vector3) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	remove_from_group("breakables")
	var broken := (load(_broken_path(kind)) as PackedScene).instantiate() as Node3D
	CharacterModel.use_vertex_colors(broken)
	var holder := _model.get_parent()
	var xf := _model.global_transform
	for m: MeshInstance3D in broken.find_children("*", "MeshInstance3D", true, false):
		var local := ValleyWorld.local_transform(m, broken)
		var basis := xf.basis * local.basis  # rotation and the prop's scale go on the mesh: bodies stay unscaled
		var body := RigidBody3D.new()
		body.collision_layer = CharacterModel.RAGDOLL_LAYER
		body.collision_mask = 0b001  # the ground and buildings, nobody's feet
		var shape := CollisionShape3D.new()
		var points := PackedVector3Array()
		for p in (m.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D).points:
			points.append(basis * p)
		var convex := ConvexPolygonShape3D.new()
		convex.points = points
		shape.shape = convex
		body.add_child(shape)
		m.owner = null
		m.get_parent().remove_child(m)
		body.add_child(m)
		m.transform = Transform3D(basis, Vector3.ZERO)
		holder.add_child(body)
		body.global_position = xf * local.origin
		var out := body.global_position - from
		out.y = 0.0
		var dir := out.normalized() if out.length() > 0.01 else Vector3.FORWARD
		body.linear_velocity = dir * PUSH * randf_range(0.6, 1.2) + Vector3.UP * UP * randf_range(0.6, 1.3)
		body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		var tw := body.create_tween()
		tw.tween_interval(PIECES_LAST * randf_range(0.8, 1.2))
		tw.tween_property(m, "scale", Vector3.ONE * 0.01, 0.6)
		tw.tween_callback(body.queue_free)
	broken.queue_free()
	_model.queue_free()
