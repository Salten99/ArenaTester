class_name Throwable
extends Node3D
## An item you can grab and hurl (combat feel plan, user 2026-11-18): a barrel or crate from a
## village, or a loose boulder or fallen branch (ThrowableField scatters those). Grabbed like a
## minion (Grabber, Chain: whatever is nearest the crosshair), held as a shield, hurled with right
## click. Every item hits the same way: your heavy damage and a launch on whoever it passes. It
## breaks when it lands. Large enemies pick them up and throw them at you too (Enemy._try_item).

const KINDS := ["barrel", "crate", "boulder", "branch"]
## Your own models win (docs/ART_SWAP.md): models/own/world/<kind>.glb.
const OWN := "res://models/own/world/"

var kind := ""
var held_by: Node3D  ## who holds it (you, or a Large enemy), or null
var _flying := false
var _vel := Vector3.ZERO
var _thrower: Node
var _hit: Array = []
var _air := 0.0
var _broken := false
var _model: Node3D


## A loose item of `kind` on the ground at `pos`, under `parent`.
static func make(p_kind: String, parent: Node, pos: Vector3, yaw := 0.0) -> Throwable:
	var t := Throwable.new()
	t.kind = p_kind
	parent.add_child(t)
	t.global_position = pos
	t.rotation.y = yaw
	t._model = t._build_model()
	return t


## Takes over a village's barrel or crate (a Breakable prop): the same model, now loose.
static func from_prop(b: Breakable) -> Throwable:
	var model: Node3D = b._model
	var t := Throwable.new()
	t.kind = b.kind
	model.get_parent().add_child(t)
	t.global_transform = Transform3D(Basis.from_euler(Vector3(0.0, model.global_rotation.y, 0.0)), model.global_position)
	b.remove_from_group("breakables")
	b.queue_free()
	model.reparent(t)
	t._model = model
	return t


## Barrels and crates in the village props you can pick up.
static func is_prop(n: Node) -> bool:
	return n is Breakable and n.kind in ["barrel", "crate"] and n.is_inside_tree() and not n.is_queued_for_deletion()


func _ready() -> void:
	add_to_group("throwables")


func is_dead() -> bool:
	return _broken


func aim_height() -> float:
	return 0.5


func bleeds() -> bool:
	return false


func grab_by(by: Node3D) -> void:
	held_by = by
	_flying = false


func release_grab() -> void:
	if held_by == null:
		return
	held_by = null
	if not _flying and not _broken:
		var space := get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 30.0, 0b001))
		if hit:
			global_position = hit.position


## Thrown by `by` at `vel`.
func hurl(vel: Vector3, by: Node) -> void:
	held_by = null
	_flying = true
	_vel = vel
	_thrower = by
	_hit = [self, by]
	_air = 0.0


func _physics_process(delta: float) -> void:
	if held_by != null:
		var at: Vector3 = held_by.hold_point_for(self) if is_instance_valid(held_by) and held_by.has_method("hold_point_for") else Vector3.INF
		if at == Vector3.INF:
			release_grab()
		else:
			global_position = at
		return
	if not _flying:
		return
	_air += delta
	_vel.y -= 20.0 * delta
	var next := global_position + _vel * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position, next + _vel.normalized() * 0.4, 0b001)
	var hit := space.intersect_ray(q)
	global_position = hit.position if hit else next
	_strike(Combat.enemies_in_radius(global_position, 1.1, _hit) if is_instance_valid(_thrower) and _thrower is Player else _foes_near(1.2))
	if hit or _air > 4.0:
		_shatter()


## Who it hits when an enemy threw it: you.
func _foes_near(radius: float) -> Array:
	var out: Array = []
	for u in get_tree().get_nodes_in_group("player"):
		if u in _hit or not is_instance_valid(u) or u.is_dead():
			continue
		if (u.global_position + Vector3.UP - global_position).length() <= radius + 0.5:
			out.append(u)
	return out


func _strike(targets: Array) -> void:
	if targets.is_empty():
		return
	_hit.append_array(targets)
	var t: CombatTuning = GameData.tuning
	if is_instance_valid(_thrower) and _thrower is Player:
		var p: Player = _thrower
		p.hit_targets(targets, p.moveset._base(p) * t.heavy_multiplier, DamageInfo.Kind.HEAVY, t.knockback_heavy, false,
			t.hitstop_heavy, t.shake_heavy, global_position, "Physical", false, false)
		Enemy.bowled_over(targets)
		return
	for u in targets:  # a Large enemy's throw: a heavy enemy blow
		var info := DamageInfo.make(_enemy_damage() * t.item_throw_damage_mult, "Physical", DamageInfo.Kind.ENEMY,
			_thrower if is_instance_valid(_thrower) else null)
		info.knockback = t.knockback_heavy
		info.knockback_dir = Vector3(_vel.x, 0.0, _vel.z).normalized()
		Combat.deal(u, info)


func _enemy_damage() -> float:
	return GameData.num(_thrower.unit, "damage", 15.0) if is_instance_valid(_thrower) and _thrower is Enemy else 15.0


## It breaks where it lands: barrels and crates into their planks, boulders and branches into pieces;
## anyone right there is hit too.
func _shatter() -> void:
	if _broken:
		return
	_broken = true
	_flying = false
	remove_from_group("throwables")
	_strike(Combat.enemies_in_radius(global_position, 1.6, _hit) if is_instance_valid(_thrower) and _thrower is Player else _foes_near(1.6))
	var from := global_position - _vel.normalized()
	# A third bigger, with more pieces (user, 2026-11-19).
	Vfx.burst(global_position, 1.4 * DEBRIS_SCALE, Color(0.6, 0.55, 0.45, 0.6), 0.35)
	Combat.shake(0.12 * DEBRIS_SCALE)
	var color := Color(0.5, 0.48, 0.45) if kind == "boulder" else Color(0.38, 0.26, 0.15)
	for i in DEBRIS_CHUNKS:
		Vfx.chunk(global_position + Vector3.UP * 0.3, Vector3(randf_range(-4, 4), randf_range(3, 6), randf_range(-4, 4)) * DEBRIS_SCALE,
			color, (0.18 if kind == "boulder" else 0.1) * randf_range(0.7, 1.3))
	if kind in ["barrel", "crate"] and is_instance_valid(_model) and ResourceLoader.exists(Breakable._broken_path(kind)):
		var root := get_parent()
		var keep := _model.global_transform
		_model.reparent(root)
		_model.global_transform = keep
		Breakable.attach(_model, kind)
		for b in _model.get_children():
			if b is Breakable:
				b.smash(from)
		queue_free()
		return
	queue_free()


const DEBRIS_SCALE := 1.33  ## how far and wide a thrown item's debris flies
const DEBRIS_CHUNKS := 9    ## pieces it breaks into (5 before, 2026-11-19), on top of a barrel's or crate's own broken model


func _build_model() -> Node3D:
	var own := OWN + kind + ".glb"
	var path := own if ResourceLoader.exists(own) else ""
	if path == "" and kind in ["barrel", "crate"]:
		path = Breakable.PROPS + kind + ".glb"
	if path == "" and kind == "boulder":
		path = Breakable.PROPS + "rock_b.glb"
	var model: Node3D
	if path != "" and ResourceLoader.exists(path):
		model = (load(path) as PackedScene).instantiate()
		add_child(model)
		CharacterModel.use_vertex_colors(model)
		var size := CharacterModel.bounds(model).size
		var want := {"barrel": 1.0, "crate": 1.0, "boulder": 0.9, "branch": 2.2}.get(kind, 1.0) as float
		var biggest := maxf(size.x, maxf(size.y, size.z))
		if biggest > 0.01 and path != own:
			model.scale = Vector3.ONE * want / biggest
		return model
	# shortcut: a branch built in code (a bough and a twig); upgrade to a generated model in make_props.py.
	model = Node3D.new()
	add_child(model)
	for part in [[Vector3(0.08, 2.2, 0.08), Vector3(0, 0.1, 0), Vector3(0, 0, PI * 0.5)], [Vector3(0.05, 0.8, 0.05), Vector3(0.3, 0.3, 0), Vector3(0, 0, 0.8)]]:
		var m := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = part[0].x * 0.7
		cyl.bottom_radius = part[0].x
		cyl.height = part[0].y
		cyl.radial_segments = 6
		m.mesh = cyl
		m.material_override = Vfx.material(Color(0.38, 0.26, 0.15))
		m.position = part[1]
		m.rotation = part[2]
		model.add_child(m)
	return model
