class_name Hazard
extends Node3D
## A lingering damage zone (e.g. Slag Trail): pulses damage and statuses on
## enemies standing in it until it expires.

var radius := 1.5
var lifetime := 2.0
var tick := 0.5
var template: DamageInfo
var _tick_left := 0.0


static func spawn(center: Vector3, p_radius: float, p_lifetime: float, p_tick: float, p_template: DamageInfo, color: Color) -> Hazard:
	var root: Node3D = Combat.effects_root
	if root == null or not is_instance_valid(root):
		return null
	var h := Hazard.new()
	h.add_to_group("hazards")
	h.radius = p_radius
	h.lifetime = p_lifetime
	h.tick = p_tick
	h.template = p_template
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = p_radius
	mesh.bottom_radius = p_radius
	mesh.height = 0.05
	disc.mesh = mesh
	var mat := Vfx.material(Color(color, 0.45))
	disc.material_override = mat
	h.add_child(disc)
	root.add_child(h)
	h.global_position = center + Vector3.UP * 0.05
	return h


func _physics_process(delta: float) -> void:
	lifetime -= delta
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = tick
		Combat.area(global_position, radius, template)
	if lifetime <= 0.0:
		queue_free()
