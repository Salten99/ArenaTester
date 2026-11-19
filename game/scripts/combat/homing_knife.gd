class_name HomingKnife
extends Node3D
## The throwing knife every character has on G (user, 2026-11-01): enchanted by your god, it
## chases its target and can't miss, then explodes, hitting everyone in the blast with your
## god's damage type. Each damage type has its own throw, flight and explosion (STYLES).
## Its path only looks wild: the flourish fades as it arrives, and hits are worked out
## from the straight chase underneath, so it always lands.

## element: throw animation, flight (path, how wide, how fast), how the blade spins, explosion.
##   paths: straight, wave (side to side), zigzag, bob (up and down), spiral, orbit (tight and quick)
const STYLES := {
	"Fire": ["Throw", "spiral", 0.5, 11.0, Vector3(16, 0, 0), "firestorm"],
	"Thorns": ["Melee_1H_Attack_Slice_Diagonal", "wave", 0.9, 7.0, Vector3(0, 0, 10), "spikes"],
	"Blood": ["Melee_1H_Attack_Stab", "bob", 0.5, 12.0, Vector3(22, 0, 0), "gore"],
	"Poison": ["Use_Item", "wave", 0.5, 5.0, Vector3(5, 5, 0), "cloud"],
	"Death": ["Melee_1H_Attack_Chop", "orbit", 0.35, 22.0, Vector3(0, 8, 0), "collapse"],
	"Turn": ["Melee_2H_Attack_Spin", "spiral", 1.1, 8.0, Vector3(0, 20, 0), "whirl"],
	"Sand": ["Melee_Unarmed_Attack_Kick", "wave", 1.3, 4.0, Vector3(9, 0, 9), "dust"],
	"Light": ["Ranged_Magic_Shoot", "straight", 0.0, 0.0, Vector3(30, 0, 0), "pillar"],
	"Dark": ["Ranged_Magic_Raise", "bob", 1.0, 3.5, Vector3(0, 0, 4), "implode"],
	"Ice": ["Ranged_1H_Shoot", "straight", 0.0, 0.0, Vector3(0, 0, 18), "shards"],
	"Drain": ["Interact", "orbit", 0.6, 14.0, Vector3(6, 0, 6), "siphon"],
	"Water": ["Melee_1H_Attack_Slice_Horizontal", "bob", 1.2, 6.0, Vector3(10, 0, 0), "splash"],
	"Lightning": ["Melee_Unarmed_Attack_Punch_A", "zigzag", 1.0, 16.0, Vector3(25, 25, 0), "strikes"],
	"Air": ["Melee_Dualwield_Attack_Slice", "spiral", 1.6, 5.0, Vector3(0, 28, 0), "gusts"],
	"Stone": ["Melee_2H_Attack_Chop", "bob", 0.6, 6.0, Vector3(14, 0, 0), "quake"],
	"Physical": ["Throw", "straight", 0.0, 0.0, Vector3(20, 0, 0), "plain"],
}
const MODEL := "res://models/free/gear_knife.glb"
const REACH := 0.7  ## this close to its target, it has hit
const MAX_FLIGHT := 6.0  ## seconds: no chase lasts forever, it blows up on its target

var player: Player
var element := "Physical"
var target: Node3D
var _goal := Vector3.ZERO
var _base := Vector3.ZERO  ## the true position; the path's flourish is drawn on top of it
var _time := 0.0
var _style: Array
var _blade: Node3D


## The animation a character throws this element's knife with.
static func throw_clip(p_element: String) -> String:
	return STYLES.get(p_element, STYLES["Physical"])[0]


## Throws at `p_target`, or at the spot `goal` when there's no one to aim at.
static func fire(p_player: Player, p_target: Node3D, goal: Vector3) -> HomingKnife:
	var root: Node3D = Combat.effects_root
	if root == null or not is_instance_valid(root):
		return null
	var k := HomingKnife.new()
	k.player = p_player
	k.element = p_player.element()
	k.target = p_target
	k._goal = goal
	k._style = STYLES.get(k.element, STYLES["Physical"])
	k._base = p_player.global_position + Vector3.UP * 1.3 + p_player.facing * 0.6
	root.add_child(k)
	k.global_position = k._base
	k._build_look()
	return k


func _build_look() -> void:
	_blade = Node3D.new()
	add_child(_blade)
	var model := ModelRegistry.race_part(player.race_id, "knife")  # your own (own/<race>/knife.glb)
	if model == "":
		model = ModelRegistry.own(player.race_id + "/gear_knife.glb")  # a race's generated throwable (the dwarves' axe)
	if model == "" and ResourceLoader.exists(MODEL):
		model = MODEL
	if model != "":
		_blade.add_child((load(model) as PackedScene).instantiate())
	_blade.scale = Vector3.ONE * 1.3
	var glow := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.2
	ball.height = 0.4
	ball.radial_segments = 8
	ball.rings = 4
	glow.mesh = ball
	var color := ElementFx.color(element)
	glow.material_override = Vfx.material(Color(color.r, color.g, color.b, 0.55))
	add_child(glow)
	var trail := ElementFx.trail(element)
	if trail != null:
		add_child(trail)


func _physics_process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(target) or target.is_dead():
		target = _nearest()
	var aim: Vector3 = target.global_position + Vector3.UP if target != null else _goal
	var to := aim - _base
	var left := to.length()
	var t: CombatTuning = GameData.tuning
	if left <= REACH or _time >= MAX_FLIGHT:
		_explode(aim if _time >= MAX_FLIGHT else _base)
		return
	var dir := to / left
	_base += dir * minf(left, t.knife_speed * (1.0 + _time) * delta)  # it speeds up: nothing outruns it
	global_position = _base + _flourish(dir, left)
	_blade.rotation += (_style[4] as Vector3) * delta


## What the path adds on top of the true position; it fades away near the target.
func _flourish(dir: Vector3, left: float) -> Vector3:
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var up := side.cross(dir).normalized()
	var wide: float = float(_style[2]) * minf(1.0, left / 5.0)
	var a: float = _time * float(_style[3])
	match _style[1]:
		"wave":
			return side * sin(a) * wide
		"bob":
			return up * sin(a) * wide
		"zigzag":
			return side * (absf(fposmod(a / PI, 2.0) - 1.0) * 2.0 - 1.0) * wide
		"spiral", "orbit":
			return (side * cos(a) + up * sin(a)) * wide
	return Vector3.ZERO


func _nearest() -> Node3D:
	var near: Array = Combat.nearest_enemies(_base, GameData.tuning.knife_range, 1)
	return near[0] if not near.is_empty() else null


func _explode(at: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	_show_explosion(at, t.knife_radius)
	Breakable.smash_near(get_tree(), at, t.knife_radius * 0.6, at)
	if is_instance_valid(player) and not player.is_dead():
		for e in Combat.enemies_in_radius(at, t.knife_radius):
			var info: DamageInfo = player.make_hit(t.knife_damage, element, "Missile", e, DamageInfo.Kind.ABILITY)  # thrown: the Rogue's missile bonus counts
			var away: Vector3 = e.global_position - at
			away.y = 0.0
			info.knockback_dir = away.normalized() if away.length() > 0.05 else player.facing
			info.knockback = t.knockback_explosion
			info.explosive = true
			if GameData.status(element.to_lower()).size() > 0:
				info.with_status(element.to_lower())
			Combat.deal(e, info)
	Combat.shake(t.shake_explosion)
	queue_free()


## Each damage type's own explosion, on top of its usual blast of particles.
func _show_explosion(at: Vector3, r: float) -> void:
	var c := ElementFx.color(element)
	var dim := Color(c.r, c.g, c.b, 0.6)
	if ElementFx.area(element, at, r):
		return  # your own explosion scene replaces the code's
	var floor_at := Vector3(at.x, at.y - 0.9, at.z)
	match _style[5]:
		"firestorm":
			Vfx.burst(floor_at, r * 0.9, Color(1.0, 0.5, 0.1, 0.7), 0.35)
			Vfx.ring(floor_at, r * 1.2, Color(1.0, 0.8, 0.3, 0.8), 0.4)
		"spikes":
			_spokes(at, r, 12, 1.8, dim, -0.9)
		"gore":
			Vfx.blood(at, Vector3.UP, 60)
			Vfx.blood_splat(floor_at + Vector3.UP * 0.03, r * 0.6)
		"cloud":
			Vfx.burst(floor_at, r * 0.8, Color(c.r, c.g, c.b, 0.35), 1.1)
			Vfx.burst(floor_at + Vector3.UP * 0.6, r * 0.5, Color(c.r, c.g, c.b, 0.45), 0.8)
		"collapse":
			Vfx.burst(at, r * 0.5, Color(0.05, 0.02, 0.08, 0.85), 0.5)
			Vfx.ring(floor_at, r, dim, 0.5)
		"whirl":
			for k in 3:
				Vfx.ring(floor_at + Vector3.UP * k * 0.7, r * (1.0 - k * 0.2), dim, 0.3 + k * 0.12)
		"dust":
			Vfx.ring(floor_at, r * 1.3, dim, 0.7)
			Vfx.burst(floor_at, r * 0.7, Color(c.r, c.g, c.b, 0.3), 0.8)
		"pillar":
			Vfx.bolt(floor_at, floor_at + Vector3.UP * 14.0, Color(1.0, 1.0, 0.8, 0.9), 0.4)
			Vfx.burst(at, r * 0.7, Color(1.0, 1.0, 0.9, 0.5), 0.15)
		"implode":
			_spokes(at, r, 10, 0.0, dim, 0.0)
			Vfx.burst(at, 1.0, Color(0.05, 0.0, 0.1, 0.9), 0.6)
		"shards":
			_spokes(at, r, 14, 0.7, Color(0.8, 0.95, 1.0, 0.85), 0.0)
		"siphon":
			for e in Combat.enemies_in_radius(at, r):
				if is_instance_valid(player):
					ElementFx.beam(element, e.global_position + Vector3.UP, player.global_position + Vector3.UP)
			Vfx.ring(floor_at, r, dim, 0.45)
		"splash":
			Vfx.ring(floor_at, r, Color(0.8, 0.95, 1.0, 0.8), 0.3)
			Vfx.ring(floor_at, r * 0.6, dim, 0.55)
			Vfx.burst(floor_at, r * 0.5, Color(c.r, c.g, c.b, 0.5), 0.3)
		"strikes":
			for k in 6:
				var a := k * TAU / 6.0
				var spot := floor_at + Vector3(cos(a), 0.0, sin(a)) * r * 0.65
				ElementFx.beam(element, spot + Vector3.UP * 12.0, spot)
		"gusts":
			for k in 3:
				Vfx.ring(floor_at + Vector3.UP * 0.3 * k, r * (0.6 + k * 0.35), Color(1, 1, 1, 0.5), 0.25 + k * 0.15)
		"quake":  # the ground cracks: rings rolling out, a puff of dust
			for k in 3:
				Vfx.ring(floor_at, r * (0.5 + k * 0.35), Color(c.r, c.g, c.b, 0.8), 0.25 + k * 0.15)
			Vfx.burst(floor_at, r * 0.6, Color(0.7, 0.65, 0.58, 0.35), 0.5)
		_:
			Vfx.burst(floor_at, r * 0.6, dim, 0.25)


## Lines shooting out of a point, tilted up or down.
func _spokes(at: Vector3, r: float, count: int, reach_k: float, color: Color, lift: float) -> void:
	for k in count:
		var a := k * TAU / count
		var out := Vector3(cos(a), 0.0, sin(a))
		var inner := at + Vector3.UP * lift + out * r * reach_k * 0.15
		var outer := at + Vector3.UP * (lift + 0.8) + out * r * (1.0 if reach_k == 0.0 else minf(reach_k, 1.0))
		Vfx.bolt(inner, outer, color, 0.35)
