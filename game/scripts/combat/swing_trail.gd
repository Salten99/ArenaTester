class_name SwingTrail
extends MeshInstance3D
## The ribbon a weapon leaves while it swings (combat feel plan, user 2026-11-18): steel with a
## slight tinge of your god's element. Each frame it samples the weapon's grip and tip; a sample
## lives swing_trail_time seconds and fades along the ribbon.

var model: CharacterModel
var active := false
var color := Color(0.82, 0.84, 0.88)
var _points: Array = []  ## [grip, tip, age]
var _mesh := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()


func _ready() -> void:
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	material_override = _mat


## Steel tinted toward the element's color.
func tint(element: String) -> void:
	color = Color(0.82, 0.84, 0.88).lerp(ElementFx.color(element), GameData.tuning.swing_trail_tint)


func _process(delta: float) -> void:
	global_transform = Transform3D.IDENTITY
	var life: float = GameData.tuning.swing_trail_time
	for p in _points:
		p[2] += delta
	_points = _points.filter(func(p): return p[2] < life)
	var tip: Node3D = model.weapon_tip() if active and model != null and is_instance_valid(model) else null
	if tip != null:
		var grip: Vector3 = tip.get_parent().global_position
		_points.append([grip.lerp(tip.global_position, 0.35), tip.global_position, 0.0])
	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in _points:
		var c := color
		c.a = 0.7 * (1.0 - p[2] / life)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(p[0])
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(p[1])
	_mesh.surface_end()


## Points in the ribbon right now (tests).
func point_count() -> int:
	return _points.size()
