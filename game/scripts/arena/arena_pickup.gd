class_name ArenaPickup
extends Node3D
## A health orb left between waves in the endless arena (user, 2026-11-19). Walk through it to heal
## HEAL of your health. It waits for you; the next wave's leftovers stay too.

const HEAL := 0.35
const REACH := 1.4

var _time := 0.0
var _orb: MeshInstance3D


static func make(parent: Node, pos: Vector3) -> ArenaPickup:
	var p := ArenaPickup.new()
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	add_to_group("arena_pickups")
	_orb = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.32
	ball.height = 0.64
	_orb.mesh = ball
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 1.0, 0.45)
	m.emission_enabled = true
	m.emission = Color(0.25, 1.0, 0.4)
	m.emission_energy_multiplier = 2.5
	_orb.material_override = m
	add_child(_orb)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.5)
	light.omni_range = 4.0
	add_child(light)


func _physics_process(delta: float) -> void:
	_time += delta
	_orb.position.y = 1.0 + sin(_time * 3.0) * 0.15
	var p: Node = Combat.camera_rig.target if is_instance_valid(Combat.camera_rig) else null
	if p == null or not is_instance_valid(p) or p.is_dead():
		return
	if (p as Node3D).global_position.distance_to(global_position + Vector3.UP) <= REACH + 0.6:
		p.health.heal(p.health.max_hp * HEAL)
		Vfx.burst(global_position + Vector3.UP, 1.2, Color(0.4, 1.0, 0.5, 0.8), 0.25)
		queue_free()
