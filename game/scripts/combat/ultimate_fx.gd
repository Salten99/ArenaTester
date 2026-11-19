class_name UltimateFx
extends RefCounted
## How a god's Ultimate looks (user, 2026-11-10): you raise your weapon, a glowing magic circle
## opens and spins in the sky over the aimed spot (lying parallel to the ground there), then it
## calls the element down:
##   Fire (its own way: Fire Lance boot jets lift you, three circles around your head, a giant Fire Lance beam from each; all in AbilityRunner) · Lightning a storm of strikes · Ice giant icicles · Stone a rain of rock shards
##   Sand a tornado that moves across · Poison a gas bomb and its cloud · Light an orbital laser sweep
## The damage lands once, impact_time() after the cast (AbilityRunner deals it, God Abilities sheet
## rules); what comes after (more strikes, the tornado moving on, the cloud) is for the eye.
## Numbers: the "Ultimate magic circle" group in combat_tuning.

## element: [main lines, second lines] (the reference circle is red and blue)
const CIRCLE_COLORS := {
	"Fire": [Color(1.0, 0.22, 0.08), Color(1.0, 0.75, 0.2)],
	"Lightning": [Color(0.3, 0.55, 1.0), Color(0.85, 0.95, 1.0)],
	"Ice": [Color(0.55, 0.92, 1.0), Color(0.25, 0.4, 1.0)],
	"Stone": [Color(0.95, 0.6, 0.25), Color(0.55, 0.42, 0.3)],
	"Sand": [Color(1.0, 0.82, 0.4), Color(0.95, 0.45, 0.15)],
	"Poison": [Color(0.5, 1.0, 0.25), Color(0.7, 0.3, 0.95)],
	"Light": [Color(1.0, 0.88, 0.45), Color(1.0, 1.0, 1.0)],
}
const LINE := 0.016  ## line width, in circle radii


## Seconds from the cast until the element hits the ground (the damage moment).
static func impact_time() -> float:
	var t: CombatTuning = GameData.tuning
	return t.ult_circle_delay + t.ult_fall_time


## The whole show over `spot`; `radius` is the ultimate's blast radius. `strike` false: only the
## circle (your own scene for this ultimate plays the rest). Returns the circle.
static func play(element: String, spot: Vector3, radius: float, strike := true) -> Node3D:
	var root := Vfx._root()
	if root == null:
		return null
	var t: CombatTuning = GameData.tuning
	var sky := spot + Vector3.UP * t.ult_circle_height
	var c := circle(element, sky, _ground_up(root, spot), radius * t.ult_circle_scale)
	if strike:
		root.get_tree().create_timer(t.ult_circle_delay, false).timeout.connect(func(): _strike(element, sky, spot, radius))
	return c


# ---------------------------------------------------------------- the magic circle

## Rings, star polygons and small circles, in two layers spinning opposite ways. `lasts` < 0: as
## long as an ultimate.
static func circle(element: String, center: Vector3, up: Vector3, radius: float, lasts := -1.0) -> Node3D:
	var root := Vfx._root()
	var t: CombatTuning = GameData.tuning
	var cols: Array = CIRCLE_COLORS.get(element, [ElementFx.color(element), Color.WHITE])
	var mat := StandardMaterial3D.new()  # its own, so this circle fades alone
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := Node3D.new()
	node.name = "MagicCircle"
	node.add_to_group("magic_circle")
	root.add_child(node)
	node.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), center)
	var outer := MeshInstance3D.new()
	outer.mesh = _lines(_outer_layer(), cols, 0.0, true)
	var inner := MeshInstance3D.new()
	inner.mesh = _lines(_inner_layer(), cols, 0.02)
	for m in [outer, inner]:
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(m)
	var life := impact_time() + t.ult_tail_time if lasts < 0.0 else lasts
	var turn := deg_to_rad(t.ult_circle_spin) * (life + 0.4)
	node.scale = Vector3.ONE * radius * 0.05
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * radius, minf(0.35, t.ult_circle_delay)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(outer, "rotation:y", turn, life + 0.4)
	tw.parallel().tween_property(inner, "rotation:y", -turn * 1.5, life + 0.4)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.4).set_delay(life)
	tw.tween_callback(node.queue_free)
	return node


## [points, color index] polylines (closed) of the outer layer: double rim, small circles in it, a {12/5} star.
static func _outer_layer() -> Array:
	var out: Array = [[_ring(1.0, 64), 0], [_ring(0.93, 64), 1], [_star(12, 5, 0.93), 0], [_ring(0.6, 48), 1]]
	for i in 12:
		out.append([_ring(0.035, 10, Vector2.from_angle(TAU * (i + 0.5) / 12) * 0.965), 1])
	return out


## The inner layer: an {8/3} star, a hexagram, small circles and the center rings.
static func _inner_layer() -> Array:
	var out: Array = [[_star(8, 3, 0.6), 0], [_star(3, 1, 0.45), 1], [_star(3, 1, 0.45, PI), 1],
		[_ring(0.45, 40), 0], [_ring(0.16, 24), 0], [_ring(0.08, 16), 1]]
	for i in 6:
		out.append([_ring(0.07, 12, Vector2.from_angle(TAU * i / 6 + PI / 6) * 0.3), 1])
	return out


static func _ring(r: float, steps: int, at := Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		pts.append(at + Vector2.from_angle(TAU * i / steps) * r)
	return pts


## The star polygon {n/k}: n points on a circle, joined every k-th.
static func _star(n: int, k: int, r: float, turn := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var count := n / gcd(n, k)
	for i in count:
		pts.append(Vector2.from_angle(turn + TAU * i * k / n - PI / 2) * r)
	return pts


static func gcd(a: int, b: int) -> int:
	return a if b == 0 else gcd(b, a % b)


## Flat ribbons (width LINE) along each closed polyline, in the XZ plane at height `y`; `glow`
## adds a faint filled disc behind the lines.
static func _lines(polys: Array, cols: Array, y: float, glow := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly in polys:
		var pts: PackedVector2Array = poly[0]
		var c: Color = cols[poly[1]]
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			var side := (b - a).orthogonal().normalized() * LINE * 0.5
			var q := [a - side, a + side, b + side, b - side]
			for j in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(c, 0.95))
				st.add_vertex(Vector3(q[j].x, y, q[j].y))
	if glow:
		var disc := _ring(1.0, 48)
		for i in disc.size():
			for p in [Vector2.ZERO, disc[i], disc[(i + 1) % disc.size()]]:
				st.set_color(Color(cols[0], 0.12))
				st.add_vertex(Vector3(p.x, y - 0.01, p.y))
	return st.commit()


## The ground's up direction under `spot` (the circle lies parallel to it); straight up on steep or no ground.
static func _ground_up(root: Node3D, spot: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 2.0, spot + Vector3.DOWN * 2.0, 1)
	var hit := root.get_world_3d().direct_space_state.intersect_ray(q)
	var n: Vector3 = hit.normal if not hit.is_empty() else Vector3.UP
	return n if n.y > 0.6 else Vector3.UP


# ---------------------------------------------------------------- what the circle calls down

## Starts when the circle has opened; whatever falls lands ult_fall_time later, at impact_time().
static func _strike(element: String, sky: Vector3, spot: Vector3, radius: float) -> void:
	var root := Vfx._root()
	if root == null:
		return
	var t: CombatTuning = GameData.tuning
	var fall := t.ult_fall_time
	var tail := t.ult_tail_time
	match element:
		"Fire":  # a meteor
			var m := _solid(_sphere(radius * 0.22), Color(1.0, 0.4, 0.08), sky)
			var trail := ElementFx.trail("Fire")
			if trail != null:
				m.add_child(trail)
				trail.emitting = true
			_drop(m, spot + Vector3.UP * radius * 0.1, fall, 0.0)
		"Lightning":  # a storm: the first strike at the spot, the rest around it
			var strikes := maxi(1, t.ult_storm_strikes)
			for i in strikes:
				var at := spot if i == 0 else spot + _in_disc(radius)
				var when := fall + tail * 0.8 * i / strikes
				root.get_tree().create_timer(when, false).timeout.connect(func():
					if ElementFx.bolt_arc(sky + _in_disc(radius * 0.4), at):  # your bolt pictures
						ElementFx.hit("Lightning", at, 1.0)
					else:
						ElementFx.beam("Lightning", sky + _in_disc(radius * 0.4), at)
					Vfx.burst(at, 1.2, Color(ElementFx.color("Lightning"), 0.6), 0.2))
		"Ice":  # one giant icicle at the spot, smaller ones around it
			for i in 5:
				var at: Vector3 = spot if i == 0 else spot + _around(i - 1, 4, radius * 0.55)
				var size := radius * (0.9 if i == 0 else 0.55)
				var ice := _solid(_spike(size * 0.18, size), Color(0.75, 0.95, 1.0, 0.9), sky + (at - spot))
				_drop(ice, at + Vector3.UP * size * 0.35, fall + 0.06 * i, tail)
		"Stone":  # a spray of rock shards over the area
			for i in t.ult_shard_count:
				var at := spot if i == 0 else spot + _in_disc(radius)
				var shard := _solid(_spike(0.3, 1.3), Color(0.55, 0.5, 0.45), sky + _in_disc(radius * 0.6))
				_drop(shard, at + Vector3.UP * 0.2, fall, 0.0, 0.0 if i == 0 else randf() * tail * 0.5, func(): ElementFx.hit("Stone", at, 0.5))
		"Sand":  # a tornado touches down, then moves across the area
			_tornado(sky, spot, radius, fall, tail)
		"Poison":  # a gas bomb drops and bursts into a cloud
			var bomb := _solid(_sphere(maxf(0.4, radius * 0.08)), Color(0.3, 0.55, 0.12), sky)
			_drop(bomb, spot + Vector3.UP * 0.4, fall, 0.0)
			root.get_tree().create_timer(fall, false).timeout.connect(func(): _cloud(spot, radius, tail))
		"Light":  # an orbital laser sweeps through the spot
			_laser(sky, spot, radius, fall)


# ---------------------------------------------------------------- the Stone special

const STONE := Color(0.55, 0.5, 0.45)
const CRACK := Color(0.08, 0.06, 0.05, 0.85)


## Stone spikes burst up: one under each of `impaled` ([ground point, height, seconds it stays]),
## erupt_spike_count more scattered over `radius`, and cracks run out over the ground.
static func erupt(spot: Vector3, radius: float, impaled: Array) -> void:
	var root := Vfx._root()
	if root == null:
		return
	var t: CombatTuning = GameData.tuning
	var up := _ground_up(root, spot)
	_cracks(spot, up, radius)
	var spikes := impaled.duplicate()
	for i in t.erupt_spike_count:
		spikes.append([spot + _in_disc(radius), t.erupt_spike_height * randf_range(0.35, 0.9), randf_range(0.6, 1.2)])
	for s in spikes:
		var ground: Vector3 = s[0]
		var h: float = s[1]
		var c := CylinderMesh.new()  # a stalagmite: wide at the ground, a point at the top
		c.top_radius = 0.0
		c.bottom_radius = h * 0.17
		c.height = h
		c.radial_segments = 5
		c.rings = 1
		var spike := _solid(c, STONE, ground - Vector3.UP * h * 0.5)
		var out := Vector3(ground.x - spot.x, 0.0, ground.z - spot.z)
		if s in impaled or out.length() < 0.1:
			spike.basis = Basis(Quaternion(Vector3.UP, up))
		else:  # the scattered ones lean outward a little
			spike.basis = Basis(Quaternion(Vector3.UP, (up + out.normalized() * 0.35).normalized()))
		var top := ground + spike.basis.y * h * 0.5
		var tw := spike.create_tween()
		tw.tween_property(spike, "global_position", top, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(float(s[2]))
		tw.tween_property(spike, "global_position", ground - spike.basis.y * h * 0.5, 0.5).set_ease(Tween.EASE_IN)
		tw.tween_callback(spike.queue_free)
	Vfx.burst(spot + Vector3.UP * 0.3, radius, Color(STONE, 0.5), 0.3)


## Dark cracks running out from `spot` over the ground, fading after erupt_crack_time.
static func _cracks(spot: Vector3, up: Vector3, radius: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 9
	for i in n:
		_crack(st, Vector2.ZERO, TAU * (i + randf() * 0.7) / n, radius * randf_range(0.8, 1.35), 0.22)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var mat := Vfx.material(CRACK)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Vfx._root().add_child(m)
	m.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), spot + up * 0.04)
	var tw := m.create_tween()
	tw.tween_interval(GameData.tuning.erupt_crack_time)
	tw.tween_property(m, "transparency", 1.0, 1.0)
	tw.tween_callback(m.queue_free)


## One jagged crack from `from` heading `angle`, `length` long, `width` wide at its start and
## narrowing to a point; it may fork.
static func _crack(st: SurfaceTool, from: Vector2, angle: float, length: float, width: float) -> void:
	var steps := 5
	var a := from
	for k in steps:
		angle += randf_range(-0.45, 0.45)  # the zig-zag
		var b := a + Vector2.from_angle(angle) * length / steps
		var w0 := width * (1.0 - float(k) / steps)
		var w1 := width * (1.0 - float(k + 1) / steps)
		var side := (b - a).orthogonal().normalized() * 0.5
		var q := [a - side * w0, a + side * w0, b + side * w1, b - side * w1]
		for j in [0, 1, 2, 0, 2, 3]:
			st.set_color(CRACK)
			st.add_vertex(Vector3(q[j].x, 0.0, q[j].y))
		if k < 3 and width > 0.08 and randf() < 0.35:  # a fork: shorter, thinner, off at an angle; the width check stops endless forks
			_crack(st, b, angle + randf_range(0.5, 0.9) * (1.0 if randf() < 0.5 else -1.0), length * 0.5, w1 * 0.6)
		a = b


## A random point within `r` of the center, on the flat.
static func _in_disc(r: float) -> Vector3:
	var v := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * r
	return Vector3(v.x, 0.0, v.y)


## The i-th of n points around a circle of radius r.
static func _around(i: int, n: int, r: float) -> Vector3:
	var v := Vector2.from_angle(TAU * i / n + 0.4) * r
	return Vector3(v.x, 0.0, v.y)


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	return s


## A spike pointing down (an icicle, a shard).
static func _spike(r: float, length: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = 0.0
	c.height = length
	c.radial_segments = 6
	c.rings = 1
	return c


static func _solid(mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	return Vfx._spawn(mesh, color, at)


## Drops `n` onto `to` over `time` (after `wait`), leaves it there `stay` s, fades and frees it.
static func _drop(n: MeshInstance3D, to: Vector3, time: float, stay: float, wait := 0.0, landed := Callable()) -> void:
	if n == null:
		return
	var tw := n.create_tween()
	if wait > 0.0:
		n.visible = false
		tw.tween_interval(wait)
		tw.tween_callback(func(): n.visible = true)
	tw.tween_property(n, "global_position", to, time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if landed.is_valid():
		tw.tween_callback(landed)
	if stay > 0.0:
		tw.tween_interval(stay)
		tw.tween_property(n, "transparency", 1.0, 0.3)
	tw.tween_callback(n.queue_free)


## A funnel of sand reaching down from the circle; it touches down at impact, then wanders `radius` away.
static func _tornado(sky: Vector3, spot: Vector3, radius: float, fall: float, tail: float) -> void:
	var root := Vfx._root()
	var h := sky.y - spot.y
	var pivot := Node3D.new()
	root.add_child(pivot)
	pivot.global_position = sky
	for layer in [[1.0, Color(0.88, 0.74, 0.46, 0.55)], [0.6, Color(0.7, 0.55, 0.32, 0.8)]]:
		var c := CylinderMesh.new()
		c.top_radius = radius * 0.45 * layer[0]
		c.bottom_radius = 0.5 * layer[0]
		c.height = h
		c.radial_segments = 10
		var m := MeshInstance3D.new()
		m.mesh = c
		m.material_override = Vfx.material(layer[1])
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3.DOWN * h * 0.5
		pivot.add_child(m)
	pivot.scale = Vector3(1.0, 0.05, 1.0)
	var away := _around(randi() % 8, 8, radius)
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "scale:y", 1.0, fall).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(pivot, "rotation:y", TAU * 3.0 * (fall + tail) , fall + tail)
	tw.parallel().tween_property(pivot, "global_position", sky + away, tail).set_delay(fall)
	tw.tween_property(pivot, "scale", Vector3(0.2, 0.0, 0.2), 0.3)
	tw.tween_callback(pivot.queue_free)


## Green puffs swelling out of the burst and lingering.
static func _cloud(spot: Vector3, radius: float, tail: float) -> void:
	for i in 7:
		var at := spot + Vector3.UP * 0.8 + (Vector3.ZERO if i == 0 else _around(i, 6, radius * 0.5))
		var puff := _solid(_sphere(1.0), Color(0.45, 0.85, 0.2, 0.4), at)
		if puff == null:
			return
		puff.scale = Vector3.ONE * 0.3
		var tw := puff.create_tween()
		tw.tween_property(puff, "scale", Vector3(1.0, 0.6, 1.0) * radius * 0.45, 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_interval(tail * 0.6)
		tw.tween_property(puff, "transparency", 1.0, tail * 0.4)
		tw.tween_callback(puff.queue_free)


## A beam straight down from the circle, sweeping edge to edge across the area; it crosses the
## spot at impact.
static func _laser(sky: Vector3, spot: Vector3, radius: float, fall: float) -> void:
	var root := Vfx._root()
	var h := sky.y - spot.y
	var pivot := Node3D.new()
	root.add_child(pivot)
	for layer in [[radius * 0.14, Color(1.0, 0.85, 0.35, 0.45)], [radius * 0.06, Color(1.0, 1.0, 0.95)]]:
		var c := CylinderMesh.new()
		c.top_radius = layer[0]
		c.bottom_radius = layer[0]
		c.height = h
		c.radial_segments = 10
		var m := MeshInstance3D.new()
		m.mesh = c
		m.material_override = Vfx.material(layer[1])
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3.DOWN * h * 0.5
		pivot.add_child(m)
	var side := _around(randi() % 8, 8, radius)
	var tw := pivot.create_tween()
	tw.tween_method(func(f: float):
		pivot.global_position = sky + side.lerp(-side, f)
		if Engine.get_physics_frames() % 4 == 0:
			ElementFx.hit("Light", spot + side.lerp(-side, f), 0.7), 0.0, 1.0, fall * 2.0)
	tw.tween_property(pivot, "scale", Vector3(0.0, 1.0, 0.0), 0.2)
	tw.tween_callback(pivot.queue_free)
	pivot.global_position = sky + side
