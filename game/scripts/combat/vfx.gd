class_name Vfx
extends RefCounted
## Placeholder effects built from simple meshes: rings, bursts, bolts and
## damage numbers. Swap for real particles later; callers won't need to change.

static var _materials := {}


static func ring(center: Vector3, radius: float, color: Color, duration := 0.3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	var node := _spawn(mesh, color, center + Vector3.UP * 0.1)
	if node == null:
		return
	node.scale = Vector3.ONE * 0.2
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3(radius, 1.0, radius), duration)
	tw.parallel().tween_property(node, "transparency", 1.0, duration)
	tw.tween_callback(node.queue_free)


static func burst(center: Vector3, radius: float, color: Color, duration := 0.25) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var node := _spawn(mesh, color, center + Vector3.UP * 0.6)
	if node == null:
		return
	node.scale = Vector3.ONE * 0.3
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * radius, duration)
	tw.parallel().tween_property(node, "transparency", 1.0, duration)
	tw.tween_callback(node.queue_free)


static func bolt(from: Vector3, to: Vector3, color: Color, duration := 0.15) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, length)
	var node := _spawn(mesh, color, (from + to) * 0.5)
	if node == null:
		return
	node.look_at_from_position(node.global_position, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := node.create_tween()
	tw.tween_property(node, "transparency", 1.0, duration)
	tw.tween_callback(node.queue_free)


static func damage_number(pos: Vector3, amount: float, color: Color, crit := false) -> void:
	var root := _root()
	if root == null:
		return
	var label := Label3D.new()
	label.text = str(roundi(amount)) + ("!" if crit else "")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_size = 8
	label.font_size = 44 if crit else 30
	label.pixel_size = 0.01
	root.add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	var tw := label.create_tween()
	tw.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.9, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.tween_callback(label.queue_free)


static var _drop_mesh: SphereMesh


## A spray of round blood drops flying toward `dir` (x gore_amount; user 2026-11-18: round drops).
static func blood(pos: Vector3, dir: Vector3, drops: int) -> void:
	var root := _root()
	drops = roundi(drops * GameData.tuning.gore_amount)
	if root == null or drops <= 0:
		return
	var p := CPUParticles3D.new()
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 0.045
		_drop_mesh.height = 0.09
		_drop_mesh.radial_segments = 6
		_drop_mesh.rings = 3
	p.mesh = _drop_mesh
	p.material_override = material(Color(0.55, 0.03, 0.04))
	p.amount = drops
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.6
	p.direction = (dir.normalized() + Vector3.UP * 0.5) if dir.length() > 0.01 else Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.5
	p.gravity = Vector3.DOWN * 14.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Stains on the ground (combat feel plan, 2026-11-18): `count` splashes scattered ahead of
## `pos` along `dir` (the way the blow went), each stretched that way. They stay
## blood_stain_seconds, and past blood_stain_max the oldest go first.
static var _stains: Array = []
static var _stain_mesh: CylinderMesh


static func blood_stains(pos: Vector3, dir: Vector3, count: int, size := 1.0) -> void:
	var t: CombatTuning = GameData.tuning
	var root := _root()
	count = roundi(count * t.gore_amount)
	if root == null or count <= 0:
		return
	if _stain_mesh == null:
		_stain_mesh = CylinderMesh.new()
		_stain_mesh.top_radius = 1.0
		_stain_mesh.bottom_radius = 1.0
		_stain_mesh.height = 0.01
		_stain_mesh.radial_segments = 8
		_stain_mesh.rings = 1
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
	var space := root.get_world_3d().direct_space_state
	for i in count:
		var along := flat.rotated(Vector3.UP, randf_range(-0.5, 0.5))
		var at := pos + along * randf_range(0.3, 2.2) * size
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 4.0, 0b001)
		var hit := space.intersect_ray(q)
		if not hit or hit.normal.y < 0.6:
			continue  # only on the ground, not walls
		var node := MeshInstance3D.new()
		node.mesh = _stain_mesh
		node.material_override = material(Color(0.42 + randf() * 0.1, 0.02, 0.03))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		node.global_position = hit.position + hit.normal * (0.012 + 0.002 * (_stains.size() % 5))
		var r := randf_range(0.12, 0.35) * size
		node.basis = Basis.looking_at(along, Vector3.UP).scaled(Vector3(r, 1.0, r * randf_range(1.6, 3.0)))
		_stains.append(node)
		var tw := node.create_tween()
		tw.tween_interval(t.blood_stain_seconds)
		tw.tween_property(node, "transparency", 1.0, 1.5)
		tw.tween_callback(node.queue_free)
	_stains = _stains.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion())  # faded ones are gone
	while _stains.size() > t.blood_stain_max:
		var old: Variant = _stains.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## Stains on the ground right now (tests).
static func stain_count() -> int:
	_stains = _stains.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion())
	return _stains.size()


## Sparks off armour: a quick spray of bright specks.
static func sparks(pos: Vector3, dir: Vector3, count: int) -> void:
	var root := _root()
	if root == null or count <= 0:
		return
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, 0.12)
	p.mesh = mesh
	p.material_override = material(Color(1.0, 0.82, 0.35))
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.3
	p.particle_flag_align_y = true
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3.DOWN * 9.0
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## A piece of armour knocked off by a killing blow: a steel helmet or plate that flies,
## bounces, lies a while and shrinks away. At most armor_pieces_max at once.
static var _pieces: Array = []


static func armor_piece(pos: Vector3, vel: Vector3) -> void:
	var root := _root()
	_pieces = _pieces.filter(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion())
	if root == null or _pieces.size() >= GameData.tuning.armor_pieces_max:
		return
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0b001
	body.mass = 2.0
	var mesh_node := MeshInstance3D.new()
	var helmet := randf() < 0.5
	if helmet:
		var dome := SphereMesh.new()
		dome.radius = 0.16
		dome.height = 0.18
		dome.is_hemisphere = true
		dome.radial_segments = 8
		dome.rings = 3
		mesh_node.mesh = dome
	else:
		var plate := BoxMesh.new()
		plate.size = Vector3(0.3, 0.05, 0.36)
		mesh_node.mesh = plate
	mesh_node.material_override = material(Color(0.62, 0.64, 0.68))
	body.add_child(mesh_node)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.12, 0.32)
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	body.global_position = pos
	body.linear_velocity = vel
	body.angular_velocity = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
	_pieces.append(body)
	var tw := body.create_tween()
	tw.tween_interval(6.0)
	tw.tween_callback(func(): body.freeze = true)  # a physics body mustn't be scaled: shrink the mesh
	tw.tween_property(mesh_node, "scale", Vector3.ONE * 0.01, 0.6)
	tw.tween_callback(body.queue_free)


## A piece of something broken (a boulder, a branch) that flies, lies a while and shrinks away.
static func chunk(pos: Vector3, vel: Vector3, color: Color, size: float) -> void:
	var root := _root()
	if root == null:
		return
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0b001
	var mesh_node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size * randf_range(0.7, 1.3)
	mesh_node.mesh = box
	mesh_node.material_override = material(color)
	body.add_child(mesh_node)
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = box.size
	shape.shape = solid
	body.add_child(shape)
	root.add_child(body)
	body.global_position = pos
	body.linear_velocity = vel
	body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	var tw := body.create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(func(): body.freeze = true)
	tw.tween_property(mesh_node, "scale", Vector3.ONE * 0.01, 0.5)
	tw.tween_callback(body.queue_free)


## A pool of blood left on what someone was slammed into, fading away.
static func blood_splat(pos: Vector3, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.02
	mesh.radial_segments = 9
	var node := _spawn(mesh, Color(0.38, 0.02, 0.03), pos)
	if node == null:
		return
	node.scale = Vector3(radius, 1.0, radius)
	var tw := node.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(node, "transparency", 1.0, 1.5)
	tw.tween_callback(node.queue_free)


## A pool of blood under a body (user, 2026-11-05): it spreads over `grow` seconds, stays, then
## soaks into the ground (fades) over `fade` seconds starting at `fade_at`, as the body sinks.
static func blood_pool(pos: Vector3, radius: float, grow: float, fade_at: float, fade: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.02
	mesh.radial_segments = 12
	var node := _spawn(mesh, Color(0.3, 0.01, 0.02), pos)
	if node == null:
		return
	node.scale = Vector3(0.2, 1.0, 0.2)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3(radius, 1.0, radius), grow).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(fade_at - grow, 0.0))
	tw.tween_property(node, "transparency", 1.0, fade)
	tw.parallel().tween_property(node, "position:y", pos.y - 0.04, fade)
	tw.tween_callback(node.queue_free)


## A flat colored material, shared per color.
static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = m
	return _materials[key]


static func _spawn(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var root := _root()
	if root == null:
		return null
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	node.global_position = pos
	return node


static func _root() -> Node3D:
	var root: Node3D = Combat.effects_root
	return root if root != null and is_instance_valid(root) and root.is_inside_tree() else null
