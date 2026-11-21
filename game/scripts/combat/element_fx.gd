class_name ElementFx
extends RefCounted
## The look of every damage type: its colors and how its particles move.
##   hit()    a burst where a hit lands (bigger for heavy hits and crits)
##   aura()   a looping effect on anything with that element's status (burning, frozen...)
##   area()   a blast filling a radius (godly gift blasts, abilities)
##   beam()   a shot from one point to another (lightning zig-zags)
##   trail()  particles behind a projectile
##   kill()   a finishing burst when an elemental hit kills
## Everything is low-poly particles built in code, so it's cheap and easy to swap
## for hand-made effects later: change the STYLES table, not the callers.

## element: [main color, second color, particle shape, motion]
##   shapes: spark (thin streak), cube, shard (spike), orb (round), drop (small round)
##   motions: spray (out and falling), rise, fall, swirl, implode, flash (fast out), splash (up then down)
const STYLES := {
	"Physical": [Color(1.0, 0.95, 0.8), Color(1.0, 0.8, 0.4), "spark", "spray"],
	"Fire": [Color(1.0, 0.45, 0.08), Color(1.0, 0.85, 0.3), "cube", "rise"],
	"Thorns": [Color(0.4, 0.7, 0.2), Color(0.5, 0.35, 0.18), "shard", "spray"],
	"Blood": [Color(0.8, 0.05, 0.08), Color(0.35, 0.0, 0.02), "drop", "spray"],
	"Poison": [Color(0.5, 0.95, 0.2), Color(0.2, 0.45, 0.08), "orb", "rise"],
	"Death": [Color(0.4, 0.12, 0.5), Color(0.06, 0.04, 0.08), "orb", "swirl"],
	"Turn": [Color(1.0, 0.5, 0.85), Color(1.0, 0.95, 0.6), "spark", "swirl"],
	"Sand": [Color(0.88, 0.75, 0.48), Color(0.6, 0.48, 0.3), "cube", "spray"],
	"Light": [Color(1.0, 0.97, 0.75), Color(1.0, 1.0, 1.0), "spark", "flash"],
	"Dark": [Color(0.14, 0.06, 0.22), Color(0.4, 0.15, 0.55), "orb", "implode"],
	"Ice": [Color(0.72, 0.93, 1.0), Color(0.35, 0.6, 0.95), "shard", "spray"],
	"Drain": [Color(0.7, 0.1, 0.25), Color(0.35, 0.85, 0.45), "orb", "implode"],
	"Water": [Color(0.25, 0.58, 0.98), Color(0.85, 0.96, 1.0), "drop", "splash"],
	"Lightning": [Color(0.62, 0.86, 1.0), Color(1.0, 1.0, 1.0), "spark", "flash"],
	"Air": [Color(0.85, 0.95, 1.0), Color(1.0, 1.0, 1.0), "spark", "swirl"],
	"Stone": [Color(0.62, 0.57, 0.5), Color(0.36, 0.31, 0.27), "cube", "splash"],  # rock chunks thrown up, falling back (was Radiate)
	"Void": [Color(0.5, 0.2, 0.8), Color(0.04, 0.0, 0.1), "orb", "implode"],
}
## Your own effects win (user, 2026-11-06; docs/MAGIC_EFFECTS.md), like your models in models/own:
##   models/own/fx/<element>_<moment>.tscn   a whole effect: hit, heavy (a heavy attack landing), kill, blast, burst, beam, aura, bolt
##   models/own/fx/<ability_id>.tscn          a god ability's effect (God Abilities sheet ids)
##   models/own/fx/fx_<element>.glb           one particle piece used in place of the code's shape
##   models/own/fx/<name>.tscn               weapons and movement: hammer_slam, sword_slash, khopesh_spin,
##                                           naginata_sweep (built at 1 m radius), landing
## Anything you haven't made keeps the code effect. Element names are lower case: fire_hit.tscn.
## Sprite-sheet effects from pixelfx (MIT, PIXELFX_LICENSE.txt) are made with tools/pixelfx_scene.py.
static var OWN_FX := "res://models/own/fx/"  ## tests point it at their own folder
static var _own := {}  ## file name -> PackedScene or Mesh, or null if you haven't made it
## While a god ability with its own scene plays, the code's element particles stay quiet.
static var quiet := false
## Your damage impact effects (user, 2026-11-06): a heavy attack landing, and every explosion of that
## damage type: fire_explosion.tscn, lightning_explosion.tscn, ... (any folder under models/own/fx).
static func impact(element: String) -> String:
	return element.to_lower() + "_explosion"

## Your explosions play at their built size, times this (user, 2026-11-08: lightning's 33% bigger).
const IMPACT_SIZE := {"Lightning": 1.33}


static func impact_size(element: String) -> float:
	return IMPACT_SIZE.get(element, 1.0)

## Most hit bursts in one physics frame (big AoE fights stay smooth).
const HITS_PER_FRAME := 14

static var _meshes := {}
static var _budget_frame := -1
static var _budget_left := 0


static func color(element: String) -> Color:
	return STYLES.get(element, STYLES.Physical)[0]


## A burst where a hit lands. `toward` pulls Drain particles back to the attacker.
## `heavy` true: a heavy attack's impact, your explosion (impact()) if you made one (played as built).
static func hit(element: String, pos: Vector3, strength := 1.0, toward := Vector3.INF, heavy := false) -> void:
	if quiet or not _spend():
		return
	if heavy and play_own(impact(element), pos, impact_size(element)) != null:
		return
	if play_own(element.to_lower() + "_hit", pos, strength) != null:
		return
	var p := _particles(element, int(14 * strength), 0.5 + 0.15 * strength)
	if p == null:
		return
	p.one_shot = true
	p.explosiveness = 0.9
	_motion(p, element, strength)
	if element == "Drain" and toward != Vector3.INF:
		p.direction = (toward - pos).normalized()
		p.spread = 20.0
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 9.0
		p.gravity = Vector3.ZERO
	_place(p, pos)
	if strength >= 1.5:
		Vfx.burst(pos - Vector3.UP * 0.6, 0.6 * strength, Color(color(element), 0.5), 0.15)


## A finishing burst when an elemental hit kills.
static func kill(element: String, pos: Vector3) -> void:
	if element == "Physical" or quiet:
		return
	if play_own(element.to_lower() + "_kill", pos) != null:
		return
	var p := _particles(element, 22, 0.8)
	if p == null:
		return
	p.one_shot = true
	p.explosiveness = 0.95
	_motion(p, element, 2.0)
	_place(p, pos)
	Vfx.ring(pos - Vector3.UP * 0.9, 2.2, Color(color(element), 0.8), 0.35)


## A blast that fills `radius` around `center` (abilities, godly gift blasts).
## `moment` picks your scene: blast (heavy, abilities, godly gifts) or burst (a spell bolt landing).
## Yours are built at 1 m radius and scaled to the blast's. Without one, your explosion (impact())
## plays as built (user, 2026-11-06: every fire explosion is the fire explosion). True if yours played.
static func area(element: String, center: Vector3, radius: float, moment := "blast") -> bool:
	if quiet:
		return true
	if play_own("%s_%s" % [element.to_lower(), moment], center, radius) != null:
		return true
	if play_own(impact(element), center, impact_size(element)) != null:
		return true
	Vfx.burst(center, radius, Color(color(element), 0.55))
	Vfx.ring(center, radius, color(element))
	var p := _particles(element, int(clampf(radius * 8.0, 12.0, 60.0)), 0.8)
	if p == null:
		return false
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.7
	_motion(p, element, 1.5)
	_place(p, center + Vector3.UP * 0.6)
	return false


## A shot from `from` to `to`: lightning zig-zags, everything else is a straight streak.
## Your beam scene points along -Z and is 1 m long: it's stretched to reach.
static func beam(element: String, from: Vector3, to: Vector3) -> void:
	if quiet:
		return
	var own := play_own(element.to_lower() + "_beam", from, 1.0, to - from)
	if own != null:
		own.scale.z = from.distance_to(to)
		hit(element, to, 0.8)
		return
	if element == "Lightning":
		var points: Array = [from]
		var steps := 4
		var side := (to - from).cross(Vector3.UP).normalized()
		for i in range(1, steps):
			var k := float(i) / steps
			points.append(from.lerp(to, k) + side * randf_range(-0.6, 0.6) + Vector3.UP * randf_range(-0.4, 0.4))
		points.append(to)
		for i in steps:
			Vfx.bolt(points[i], points[i + 1], Color(1, 1, 1), 0.12)
			Vfx.bolt(points[i], points[i + 1], color(element), 0.2)
	else:
		Vfx.bolt(from, to, color(element), 0.18)
	hit(element, to, 0.8)


## Lightning jumping to the next enemy (user, 2026-11-08): your bolt pictures (lightning/lightning
## bolts/bolt_1..6.png under models/own/fx) laid end to end along an arc from `from` to `to`, each
## flickering through the pictures for ARC_TIME. False if you haven't made them (beam() instead).
const ARC_TIME := 0.25
const ARC_SEGMENTS := 3
const ARC_WIDTH := 1.0  ## m across a bolt
static var _bolts: Array = []
static var _bolts_from := ""


## Your bolt images (models/own/fx/lightning/lightning bolts/bolt_1..6.png), loaded once; empty without.
static func bolt_frames() -> Array:
	if _bolts_from != OWN_FX:
		_bolts_from = OWN_FX
		_bolts = []
		for i in range(1, 7):
			var path := OWN_FX + "lightning/lightning bolts/bolt_%d.png" % i
			if ResourceLoader.exists(path):
				_bolts.append(load(path))
	return _bolts


static func bolt_arc(from: Vector3, to: Vector3) -> bool:
	if quiet:
		return true
	bolt_frames()
	var root := Vfx._root()
	if _bolts.is_empty() or root == null:
		return false
	var cam := root.get_viewport().get_camera_3d()
	var mid := (from + to) * 0.5 + Vector3.UP * from.distance_to(to) * 0.25  # it arcs up between them
	var pts: Array = []
	for i in ARC_SEGMENTS + 1:
		var k := float(i) / ARC_SEGMENTS
		pts.append(from.lerp(mid, k).lerp(mid.lerp(to, k), k))
	for i in ARC_SEGMENTS:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var quad := QuadMesh.new()
		quad.size = Vector2(ARC_WIDTH, a.distance_to(b) * 1.15)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(0.85, 0.92, 1.0)
		mat.albedo_texture = _bolts[randi() % _bolts.size()]
		var bolt := MeshInstance3D.new()
		bolt.mesh = quad
		bolt.material_override = mat
		bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bolt)
		# Along the segment, its face turned to the camera.
		var up := (b - a).normalized()
		var toward := (cam.global_position - (a + b) * 0.5) if cam != null else Vector3.BACK
		var side := up.cross(toward).normalized()
		if side.length() < 0.5:
			side = up.cross(Vector3.RIGHT).normalized()
		bolt.global_transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
		var tw := bolt.create_tween()
		for f in 4:
			tw.tween_interval(ARC_TIME / 5.0)
			tw.tween_callback(func(): mat.albedo_texture = _bolts[randi() % _bolts.size()])
		tw.tween_interval(ARC_TIME / 5.0)
		tw.tween_callback(bolt.queue_free)
	return true


## A looping effect for something carrying this element's status. Add it as a
## child of the unit; call stop_aura() to let it fade out.
static func aura(element: String, size := 1.0) -> CPUParticles3D:
	var own := _carrier(element.to_lower() + "_aura", size)
	if own != null:
		own.name = "Aura_" + element
		own.position = Vector3.UP * 1.0 * size
		return own
	var p := _particles(element, 10, 0.9)
	if p == null:
		p = CPUParticles3D.new()
	p.name = "Aura_" + element
	p.amount = int(8 * size) + 4
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5 * size
	_motion(p, element, 0.6)
	p.position = Vector3.UP * 1.0 * size
	return p


## Stops an aura and frees it once its particles have faded.
static func stop_aura(p: CPUParticles3D) -> void:
	if p == null or not is_instance_valid(p):
		return
	p.emitting = false
	var t := p.get_tree().create_timer(p.lifetime + 0.1) if p.is_inside_tree() else null
	if t != null:
		t.timeout.connect(p.queue_free)
	else:
		p.queue_free()


## Particles following a projectile (add as its child).
static func trail(element: String) -> CPUParticles3D:
	var own := _carrier(element.to_lower() + "_bolt", 1.0)
	if own != null:
		return own
	var p := _particles(element, 16, 0.35)
	if p == null:
		return null
	p.local_coords = false
	p.direction = Vector3.BACK
	p.spread = 15.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.gravity = Vector3.ZERO
	return p


# ---------------------------------------------------------------- your own effects

static func own_scene(file: String) -> PackedScene:
	if not _own.has(file):
		var path := find_own(file + ".tscn", OWN_FX)
		_own[file] = load(path) if path != "" else null
	return _own[file]


## Where your effect file is: in models/own/fx or any folder inside it, so you can sort them into
## folders freely (user, 2026-11-07). "" if you haven't made it.
## shortcut: two files with the same name in different folders: the first one found wins.
static func find_own(file: String, dir: String) -> String:
	if ResourceLoader.exists(dir + file):
		return dir + file
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			var found := find_own(file, dir + f)
			if found != "":
				return found
	return ""


## Plays your effect scene `file` at `pos` (scaled, turned to `facing` if given) and frees it when it's
## done. Null if you haven't made that one (the code effect plays instead).
static func play_own(file: String, pos: Vector3, size := 1.0, facing := Vector3.ZERO) -> Node3D:
	var scene := own_scene(file)
	var root := Vfx._root()
	if scene == null or root == null:
		return null
	var n: Node3D = scene.instantiate()
	root.add_child(n)
	n.global_position = pos
	if facing.length() > 0.01 and absf(facing.normalized().dot(Vector3.UP)) < 0.99:
		n.look_at(pos + facing, Vector3.UP)
	n.scale = Vector3.ONE * maxf(size, 0.05)
	root.get_tree().create_timer(_start(n) + 0.3, false).timeout.connect(n.queue_free)
	return n


## Starts every particle system and animation in your scene; returns how long it lasts (s).
static func _start(n: Node) -> float:
	var longest := 0.5
	for c in [n] + n.find_children("*", "", true, false):
		if c is GPUParticles3D or c is CPUParticles3D:
			c.restart()
			longest = maxf(longest, c.lifetime)
		elif c is AnimatedSprite3D:  # a sprite sheet (the pixelfx ones): a looping one lasts one loop
			var sprite := c as AnimatedSprite3D
			var frames := sprite.sprite_frames
			sprite.play(sprite.animation)
			longest = maxf(longest, frames.get_frame_count(sprite.animation) / maxf(frames.get_animation_speed(sprite.animation), 1.0))
		elif c is AnimationPlayer:
			var ap := c as AnimationPlayer
			if ap.current_animation == "" and not ap.get_animation_list().is_empty():
				var first: String = ap.autoplay if ap.autoplay != "" else ap.get_animation_list()[0]
				ap.play(first)
			if ap.current_animation != "":
				longest = maxf(longest, ap.current_animation_length)
	return longest


## Your looping effect (an aura, a bolt's trail) inside an empty particle node, so the code that adds,
## starts and stops auras and trails works the same for yours. Null if you haven't made it.
static func _carrier(file: String, size: float) -> CPUParticles3D:
	var scene := own_scene(file)
	if scene == null:
		return null
	var p := CPUParticles3D.new()  # draws nothing itself (no mesh); it carries your scene
	p.amount = 1
	p.lifetime = 0.4
	var n: Node3D = scene.instantiate()
	n.scale = Vector3.ONE * size
	p.add_child(n)
	n.ready.connect(func(): _start(n), CONNECT_ONE_SHOT)  # particles restart only inside the scene
	return p


## Your particle piece for an element (fx_<element>.glb, anywhere under models/own/fx), tinted like the code's shapes.
static func _own_piece(element: String) -> Mesh:
	var file := "fx_" + element.to_lower()
	if not _own.has(file):
		_own[file] = null
		var path := find_own(file + ".glb", OWN_FX)
		if path != "":
			var scene: Node = (load(path) as PackedScene).instantiate()
			var meshes: Array = scene.find_children("*", "MeshInstance3D", true, false)
			if not meshes.is_empty():
				var m: Mesh = (meshes[0] as MeshInstance3D).mesh.duplicate()
				var mat := StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.vertex_color_use_as_albedo = true
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				for i in m.get_surface_count():
					m.surface_set_material(i, mat)
				_own[file] = m
			scene.free()
	return _own[file]


# ---------------------------------------------------------------- building blocks

static func _spend() -> bool:
	var frame := Engine.get_physics_frames()
	if frame != _budget_frame:
		_budget_frame = frame
		_budget_left = HITS_PER_FRAME
	if _budget_left <= 0:
		return false
	_budget_left -= 1
	return true


static func _particles(element: String, amount: int, lifetime: float) -> CPUParticles3D:
	var style: Array = STYLES.get(element, STYLES.Physical)
	var p := CPUParticles3D.new()
	p.amount = maxi(2, amount)
	p.lifetime = lifetime
	var piece: Mesh = _own_piece(element)
	p.mesh = piece if piece != null else _mesh(style[2])
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = fade
	var ramp := Gradient.new()
	ramp.set_color(0, style[0])
	ramp.set_color(1, Color(style[1], 0.0))
	p.color_ramp = ramp
	return p


static func _motion(p: CPUParticles3D, element: String, strength: float) -> void:
	var speed := 3.0 + 2.5 * strength
	match STYLES.get(element, STYLES.Physical)[3]:
		"spray":
			p.direction = Vector3.UP
			p.spread = 70.0
			p.initial_velocity_min = speed * 0.6
			p.initial_velocity_max = speed
			p.gravity = Vector3(0, -12.0, 0)
		"rise":
			p.direction = Vector3.UP
			p.spread = 35.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.5 + strength
			p.gravity = Vector3(0, 3.0, 0)
			p.damping_min = 1.0
			p.damping_max = 2.0
		"fall":
			p.direction = Vector3.DOWN
			p.spread = 25.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.5
			p.gravity = Vector3(0, -8.0, 0)
		"swirl":
			p.direction = Vector3.UP
			p.spread = 60.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = speed * 0.7
			p.gravity = Vector3(0, 1.0, 0)
			p.tangential_accel_min = 8.0
			p.tangential_accel_max = 14.0
		"implode":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.9 + 0.3 * strength
			p.direction = Vector3.UP
			p.spread = 180.0
			p.initial_velocity_min = 0.0
			p.initial_velocity_max = 0.5
			p.radial_accel_min = -10.0
			p.radial_accel_max = -6.0
			p.gravity = Vector3.ZERO
		"flash":
			p.direction = Vector3.UP
			p.spread = 180.0
			p.initial_velocity_min = speed
			p.initial_velocity_max = speed * 1.6
			p.gravity = Vector3.ZERO
			p.damping_min = 6.0
			p.damping_max = 10.0
		"splash":
			p.direction = Vector3.UP
			p.spread = 45.0
			p.initial_velocity_min = speed * 0.8
			p.initial_velocity_max = speed * 1.2
			p.gravity = Vector3(0, -16.0, 0)


static func _mesh(shape: String) -> Mesh:
	if _meshes.has(shape):
		return _meshes[shape]
	var m: PrimitiveMesh
	match shape:
		"spark":
			var b := BoxMesh.new()
			b.size = Vector3(0.09, 0.45, 0.09)
			m = b
		"shard":
			var pr := PrismMesh.new()
			pr.size = Vector3(0.18, 0.5, 0.18)
			m = pr
		"orb":
			var s := SphereMesh.new()
			s.radius = 0.16
			s.height = 0.32
			s.radial_segments = 6
			s.rings = 3
			m = s
		"drop":
			var d := SphereMesh.new()
			d.radius = 0.11
			d.height = 0.22
			d.radial_segments = 5
			d.rings = 2
			m = d
		_:
			var c := BoxMesh.new()
			c.size = Vector3(0.18, 0.18, 0.18)
			m = c
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	_meshes[shape] = m
	return m


static func _place(p: CPUParticles3D, pos: Vector3) -> void:
	var root: Node3D = Combat.effects_root
	if root == null or not is_instance_valid(root) or not root.is_inside_tree():
		p.free()
		return
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	root.get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)
