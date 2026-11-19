class_name ArenaHazard
extends Node3D
## A trap in the endless arena (user, 2026-11-19): throw an enemy into it and it dies outright.
##   spikes: a wall of iron spikes, solid (a hurled body bursts on it anyway).
##   fire:   a burning pit. Enemies who walk through catch fire; so do you.

const SPIKE_REACH := 1.6  ## m from the wall's middle line where a thrown body is impaled
const SPIKE_LENGTH := 4.0
const FIRE_RADIUS := 2.2
const BURN_EVERY := 0.6

var kind := "spikes"
var _burn_left := 0.0


static func make(p_kind: String, parent: Node, pos: Vector3, yaw: float) -> ArenaHazard:
	var h := ArenaHazard.new()
	h.kind = p_kind
	parent.add_child(h)
	h.global_position = pos
	h.rotation.y = yaw
	return h


func _ready() -> void:
	add_to_group("arena_hazards")
	if kind == "spikes":
		_build_spikes()
	else:
		_build_fire()


func _build_spikes() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.32, 0.3, 0.3)
	iron.metallic = 0.6
	iron.roughness = 0.5
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SPIKE_LENGTH, 1.2, 0.5)
	base.mesh = box
	base.material_override = iron
	base.position.y = 0.6
	add_child(base)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.09
	spike.height = 0.8
	var tip := StandardMaterial3D.new()
	tip.albedo_color = Color(0.75, 0.72, 0.68)
	tip.metallic = 0.8
	for side in [-1.0, 1.0]:  # spikes on both faces, in two rows
		for row in 2:
			for i in 9:
				var s := MeshInstance3D.new()
				s.mesh = spike
				s.material_override = tip
				s.position = Vector3(-SPIKE_LENGTH * 0.5 + 0.25 + i * (SPIKE_LENGTH - 0.5) / 8.0, 0.35 + row * 0.55, side * 0.6)
				s.rotation.x = side * PI * 0.5
				add_child(s)
	var body := StaticBody3D.new()
	body.collision_layer = 0b001
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = Vector3(SPIKE_LENGTH, 1.6, 0.7)
	shape.shape = col
	shape.position.y = 0.8
	body.add_child(shape)
	add_child(body)


func _build_fire() -> void:
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = FIRE_RADIUS - 0.25
	ring.outer_radius = FIRE_RADIUS + 0.15
	rim.mesh = ring
	rim.scale = Vector3(1.0, 0.6, 1.0)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.25, 0.22, 0.2)
	rim.material_override = stone
	add_child(rim)
	var coals := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = FIRE_RADIUS - 0.2
	disc.bottom_radius = FIRE_RADIUS - 0.2
	disc.height = 0.05
	coals.mesh = disc
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.9, 0.3, 0.05)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.35, 0.05)
	glow.emission_energy_multiplier = 2.0
	coals.material_override = glow
	coals.position.y = 0.03
	add_child(coals)
	var flames := ElementFx.aura("Fire", FIRE_RADIUS * 0.9)
	if flames != null:
		add_child(flames)
		flames.emitting = true
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.omni_range = 7.0
	light.light_energy = 1.5
	light.position.y = 1.0
	add_child(light)


func _physics_process(delta: float) -> void:
	if kind == "spikes":
		_check_spikes()
	else:
		_check_fire(delta)


## A body thrown (or hurled) into the spikes is impaled.
func _check_spikes() -> void:
	for e in Combat.enemies_in_radius(global_position, SPIKE_LENGTH * 0.5 + SPIKE_REACH):
		if not e.thrown:
			continue
		var local: Vector3 = to_local((e as Node3D).global_position)
		if absf(local.x) <= SPIKE_LENGTH * 0.5 + 0.3 and absf(local.z) <= SPIKE_REACH:
			_kill(e, "Physical")
			Vfx.sparks((e as Node3D).global_position + Vector3.UP, Vector3.UP, 10)


## Thrown in: burned up. Walking through: set alight. You too.
func _check_fire(delta: float) -> void:
	_burn_left -= delta
	var burn := _burn_left <= 0.0
	if burn:
		_burn_left = BURN_EVERY
	for e in Combat.enemies_in_radius(global_position, FIRE_RADIUS):
		if e.thrown:
			_kill(e, "Fire")
		elif burn:
			Combat.apply_status(e, "fire", 1, null)
	var p: Node = Combat.camera_rig.target if is_instance_valid(Combat.camera_rig) else null
	if burn and p != null and is_instance_valid(p) and not p.is_dead() and p.global_position.distance_to(global_position) <= FIRE_RADIUS \
			and p.global_position.y < global_position.y + 1.5:
		Combat.apply_status(p, "fire", 1, null)


func _kill(e: Node, element: String) -> void:
	var by: Node = e.get("_thrower")
	var info := DamageInfo.make(e.health.hp + 1.0, element, DamageInfo.Kind.STATUS, by if is_instance_valid(by) else null)
	info.no_launch = true
	Combat.deal(e, info)
	ElementFx.hit(element, (e as Node3D).global_position + Vector3.UP, 1.6)
	Combat.shake(0.2)
