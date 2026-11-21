class_name LedgeAnchor
extends Node3D
## A gold ring on the lip of a tall wall (user, 2026-11-20). Aim at it and hold grab (as for the
## chain grab): the chain hooks it and slings you up and over onto the top (Chain.Mode.SLING).

## Where you come down, on top of the wall (local to the ring).
var landing_at := Vector3(0.0, 1.0, -1.5)


static func make(parent: Node, pos: Vector3, yaw: float) -> LedgeAnchor:
	var a := LedgeAnchor.new()
	parent.add_child(a)
	a.global_position = pos
	a.rotation.y = yaw
	return a


func _ready() -> void:
	add_to_group("ledge_anchors")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.42
	ring.mesh = torus
	ring.rotation.x = PI * 0.5  # stands up, facing out from the wall
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.3)
	gold.metallic = 0.8
	gold.roughness = 0.3
	gold.emission_enabled = true  # glows, so it reads from across the arena
	gold.emission = Color(1.0, 0.7, 0.25)
	gold.emission_energy_multiplier = 2.0
	ring.material_override = gold
	add_child(ring)


## Where the sling sets you down, on top.
func landing() -> Vector3:
	return global_transform * landing_at


## The chain treats it like a target (Chain.find_target, Chain.update).
func is_dead() -> bool:
	return false


func aim_height() -> float:
	return 0.0
