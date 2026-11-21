class_name Projectile
extends Node3D
## A flying shot (arrows, bolts, spells). Hits enemies it passes within
## `radius` of, up to `pierce` + 1 of them, then disappears. A `hostile` shot
## (an enemy's) hits you instead. Magic shots get a `homing`
## target and bend toward it by up to `pull_deg` degrees per second.

var velocity := Vector3.ZERO
var radius := 0.6
var pierce := 0
var lifetime := 1.5
var template: DamageInfo
## Called after each hit with (target, info, dealt).
var on_hit: Callable
var hostile := false
## An enemy's shot hits this (the player).
var player: Node3D
var homing: Node3D
## Called with (where, surface normal) the shot ends: the first wall or ground, or the last enemy it goes into (normal UP).
var on_land: Callable
var pull_deg := 0.0
## How fast it falls (arrows and bolts).
var drop := 0.0
## Your shots stop at the ground, walls, trees and rocks, and only hit what they reach in height too.
var aimed := false
## Your shots glow and leave a bright streak, so you can follow them (user, 2026-11-05).
var bright := false:
	set(on):
		bright = on
		if on:
			_streak()
## Arrows and bolts stay stuck where they land, in the ground or in whoever they hit, this long (s).
const STICK_SECONDS := 4.0
## Your dash slows enemy shots near you (Player._slow_near): until this physics frame it flies slow.
var dash_slow_until := 0
var _hit: Array = []
var _mesh: MeshInstance3D


static func fire(from: Vector3, direction: Vector3, speed: float, p_template: DamageInfo, color: Color, p_pierce := 0) -> Projectile:
	var root: Node3D = Combat.effects_root
	if root == null or not is_instance_valid(root):
		return null
	var p := Projectile.new()
	p.add_to_group("projectiles")
	p.velocity = direction.normalized() * speed
	p.template = p_template
	p.pierce = p_pierce
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.7)
	mesh.mesh = box
	mesh.material_override = Vfx.material(color)
	p.add_child(mesh)
	p._mesh = mesh
	var trail := ElementFx.trail(p_template.damage_type if p_template != null else "Physical")
	if trail != null:
		p.add_child(trail)
	root.add_child(p)
	p.global_position = from
	p.look_at(from + p.velocity, Vector3.UP)
	return p


func _physics_process(delta: float) -> void:
	if Engine.get_physics_frames() < dash_slow_until:
		delta *= GameData.tuning.dash_projectile_slow_scale
	lifetime -= delta
	if pull_deg > 0.0 and is_instance_valid(homing) and not homing.is_dead():
		var want: Vector3 = (homing.global_position + Vector3.UP - global_position).normalized()
		var have := velocity.normalized()
		var angle := have.angle_to(want)
		var axis := have.cross(want)
		if angle > 0.001 and axis.length() > 0.0001:
			velocity = have.rotated(axis.normalized(), minf(angle, deg_to_rad(pull_deg) * delta)) * velocity.length()
			look_at(global_position + velocity, Vector3.UP)
	if drop > 0.0:
		velocity.y -= drop * delta
		look_at(global_position + velocity, Vector3.UP)
	var next := global_position + velocity * delta
	if is_inside_tree():  # every shot stops at walls, enemies' too
		var q := PhysicsRayQueryParameters3D.create(global_position, next, 0b001)
		var wall := get_world_3d().direct_space_state.intersect_ray(q)
		if wall:
			if not hostile:  # your shots knock chunks out of buildings
				Breakable.smash_near(get_tree(), wall.position, 0.6, global_position)
			if on_land.is_valid():
				on_land.call(wall.position, wall.normal)
			_stick(wall.position, Combat.effects_root)
			queue_free()
			return
	global_position = next
	for e in _targets():
		var info := Combat._copy(template)
		info.knockback_dir = velocity.normalized()
		info.shot = true
		var dealt := Combat.deal(e, info)
		if on_hit.is_valid():
			on_hit.call(e, info, dealt)
		_hit.append(e)
		if _hit.size() > pierce:
			if on_land.is_valid():
				on_land.call(global_position, Vector3.UP)
			if is_instance_valid(e) and not e.is_dead():
				_stick(global_position, e)
			queue_free()
			return
	if lifetime <= 0.0:
		queue_free()


## An arrow or bolt left behind, stuck at `at` (in the ground, or in `holder`, moving with it).
func _stick(at: Vector3, holder: Node) -> void:
	if template == null or template.category != "Missile" or _mesh == null or holder == null or not is_instance_valid(holder):
		return
	var stuck := MeshInstance3D.new()
	stuck.mesh = _mesh.mesh
	stuck.material_override = _mesh.material_override
	holder.add_child(stuck)
	var dir := velocity.normalized() if velocity.length() > 0.01 else Vector3.FORWARD
	stuck.global_position = at - dir * 0.25  # half of it in, half sticking out
	stuck.look_at(stuck.global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	stuck.get_tree().create_timer(STICK_SECONDS).timeout.connect(stuck.queue_free)


## A long glowing streak behind the shot.
func _streak() -> void:
	if _mesh == null:
		return
	var glow := (_mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.emission_enabled = true
	glow.emission = glow.albedo_color
	glow.emission_energy_multiplier = 3.0
	_mesh.material_override = glow
	var streak := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.07, 3.0)
	streak.mesh = box
	var mat := glow.duplicate() as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(glow.albedo_color, 0.55)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	streak.material_override = mat
	streak.position = Vector3(0, 0, 1.8)  # behind it: the shot looks down -Z
	add_child(streak)


func _targets() -> Array:
	if not hostile:
		var near := Combat.enemies_in_radius(global_position, radius, _hit)
		if aimed:  # over their heads or under their feet: a miss
			near = near.filter(func(e): return global_position.y > e.global_position.y - 0.7 and global_position.y < e.global_position.y + 2.6 * e.size_scale)
		return near
	if not is_instance_valid(player) or player in _hit or player.is_dead():
		return []
	var d: Vector3 = player.global_position + Vector3.UP - global_position
	return [player] if Vector2(d.x, d.z).length() <= radius + 0.4 and absf(d.y) < 1.6 else []
