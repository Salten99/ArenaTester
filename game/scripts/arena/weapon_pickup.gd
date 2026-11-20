class_name WeaponPickup
extends Node3D
## A weapon lying in the arena (user, 2026-11-20: you start with only your fists and the chain;
## weapons are found around the map). Walk over it with empty hands to take it up. A thrown weapon
## lies where it lands on the floor, as one of these, until you take it again; one thrown into a wall
## sticks there (stick) and a new one is laid out.

const REACH := 1.6
## A weapon's longest side, lying here or flying (m).
const LENGTH := 1.3

var weapon_id := ""
var _spin: Node3D
var _time := 0.0
var _landed := false  ## dropped onto the floor below where it was put (on the first physics frame)


## A weapon lying at `pos` (it drops onto the floor below), under `parent`.
static func make(id: String, parent: Node, pos: Vector3) -> WeaponPickup:
	var w := WeaponPickup.new()
	w.weapon_id = id
	parent.add_child(w)
	w.global_position = pos
	return w


## Puts weapon `id`'s model under `parent` (in the tree), LENGTH long, its point (the model's long
## axis) facing -Z; returns the pivot it hangs on, or null when there's no model.
static func add_model(parent: Node3D, id: String) -> Node3D:
	var path := ModelRegistry.weapon_model(id)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var pivot := Node3D.new()
	parent.add_child(pivot)
	var m := (load(path) as PackedScene).instantiate() as Node3D
	pivot.add_child(m)
	CharacterModel.use_vertex_colors(m)
	var size := CharacterModel.bounds(m).size
	var longest := maxf(size.x, maxf(size.y, size.z))
	if longest > 0.01:
		m.scale = Vector3.ONE * LENGTH / longest
	if size.y >= size.x and size.y >= size.z:
		m.rotation.x = -PI * 0.5  # handle to tip along +Y: tip forward
	elif size.x >= size.z:
		m.rotation.y = PI * 0.5
	return pivot


## Weapon `id` stuck in a wall at `at`, flying along `dir`: its point in, the rest sticking out.
static func stick(id: String, parent: Node, at: Vector3, dir: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.name = "StuckWeapon"
	parent.add_child(holder)
	holder.global_position = at
	if dir.length() > 0.01:
		holder.look_at(at + dir, Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT)
	var pivot := add_model(holder, id)
	if pivot != null:
		pivot.position.z = LENGTH * 0.3  # back out of the wall along the flight
	return holder


func _ready() -> void:
	add_to_group("weapon_pickups")
	_spin = Node3D.new()
	add_child(_spin)
	var pivot := add_model(_spin, weapon_id)
	if pivot != null:
		pivot.rotation.x = PI * 0.5  # stood on end, turning slowly
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.position.y = 0.8
	add_child(light)


func _physics_process(delta: float) -> void:
	if not _landed:
		_landed = true
		var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position + Vector3.DOWN * 60.0, 0b001))
		if hit:
			global_position = hit.position
	_time += delta
	_spin.position.y = 1.0 + sin(_time * 2.5) * 0.12
	_spin.rotation.y += delta * 1.5
	var p: Node = Combat.camera_rig.target if is_instance_valid(Combat.camera_rig) else null
	if p is Player and not p.is_dead() and p.weapon_id == GameData.FISTS \
			and (p as Node3D).global_position.distance_to(global_position) <= REACH:
		p.equip(weapon_id)
		Vfx.burst(global_position + Vector3.UP, 1.0, Color(1.0, 0.85, 0.5, 0.8), 0.25)
		queue_free()
