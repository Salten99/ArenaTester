class_name WitchCircle
extends Node3D
## A witch's spell (arena tactics, user 2026-11-19): a ring glows on the ground where you stood and
## fills in over DELAY, then bursts. Step out of it. Hit or grab the witch first and it still lands,
## but kill her and it fizzles. Enemies standing in it get her element too (lure them in).

const DELAY := 1.2
const RADIUS := 2.6

var caster: Node
var damage := 12.0
var status := ""
var _time := 0.0
var _fill: MeshInstance3D
var _color := Color(0.7, 0.3, 1.0)


static func cast(by: Node, at: Vector3, p_damage: float, p_status: String) -> WitchCircle:
	var root: Node = Combat.effects_root if is_instance_valid(Combat.effects_root) else (by.get_parent() if by != null else null)
	if root == null:
		return null
	var c := WitchCircle.new()
	c.caster = by
	c.damage = p_damage
	c.status = p_status
	root.add_child(c)
	c.global_position = at + Vector3.UP * 0.06
	return c


func _ready() -> void:
	if status != "":
		_color = ElementFx.color(GameData.text(GameData.status(status), "damage_type", "Physical"))
	var edge := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = RADIUS - 0.12
	ring.outer_radius = RADIUS
	edge.mesh = ring
	edge.scale = Vector3(1.0, 0.15, 1.0)
	edge.material_override = _glow(Color(_color, 0.9))
	add_child(edge)
	_fill = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.02
	_fill.mesh = disc
	_fill.material_override = _glow(Color(_color, 0.35))
	_fill.scale = Vector3(0.05, 1.0, 0.05)
	add_child(_fill)


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _physics_process(delta: float) -> void:
	if not is_instance_valid(caster) or caster.is_dead():
		queue_free()  # she fell: the spell fizzles
		return
	_time += delta
	var k := clampf(_time / DELAY, 0.0, 1.0)
	_fill.scale = Vector3(k, 1.0, k)
	if _time >= DELAY:
		_burst()


func _burst() -> void:
	var at := global_position
	var element := GameData.text(GameData.status(status), "damage_type", "Physical") if status != "" else "Physical"
	ElementFx.area(element, at, RADIUS)
	var player: Node = caster.get("player")
	if is_instance_valid(player) and _inside(player):
		var info := DamageInfo.make(damage, element, DamageInfo.Kind.ENEMY, caster)
		info.knockback = 6.0
		var away: Vector3 = (player as Node3D).global_position - at
		away.y = 0.0
		info.knockback_dir = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
		if status != "":
			info.with_status(status)
		Combat.deal(player, info)
	if status != "":
		for e in Combat.enemies_in_radius(at, RADIUS, [caster]):
			Combat.apply_status(e, status, 1, null)
	queue_free()


func _inside(n: Node) -> bool:
	var d: Vector3 = (n as Node3D).global_position - global_position
	d.y = 0.0
	return d.length() <= RADIUS
