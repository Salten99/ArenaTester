class_name Spells
extends Node
## The arena's spells that aren't a plain blast (Arena Magic Attacks sheet, user 2026-11-20). A child
## of the AbilityRunner; the God Abilities `shape` column picks one:
##   Rings   rings roll out from you to radius_m; the nearer, the harder (Lava Ripple, Ring of Ice)
##   Strike  one big bolt on the spot range_m ahead, throwing what's near (Thunder Crash)
##   Fan     hits_or_projectiles bolts fan across fan_arc_deg in front, range_m long (Bolt Fan)
##   Cage    press R, fly up, click to place pillars; bolts bounce between them on lightning hawks (Kaminari)
##   Slide   slide range_m on a trail of ice that slows (Ice Slide)
##   Snake   a giant ice snake you ride; it freezes what it touches, shatters what it kills (Ice Snake)
##   Slab    a stone fist, hammer, tree or dolphin shoots up where aimed, launches what's on it (you too, unhurt), then bursts into dust (Stone Slab)
##   Crush   two stone rams charge and headbutt on the aimed spot (Crushing Pillars)
##   Magma   reach into the ground, pull out a magma ball and hurl it at the aimed spot (Magma Ball)
## The looks are built in code; your models/own/fx/<ability_id>.tscn plays instead once you make it.
## The numbers are in combat_tuning.tres, group Spells.

const RAM := "res://models/own/mount_war_ram.glb"  # the Crush rams
const RAM_HOOF := Vector3(0.0, 0.0, -0.55)  # its hind hooves standing still (measured in Blender)
const RAM_REAR_DEG := 55.0  # how far it rears up (the user's photo, 2026-11-20)
static var STONE_SKIN := _stone_skin()  # solid and two-sided like the model's own material, so no see-through holes


static func _stone_skin() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = UltimateFx.STONE
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


var _cages := []  # Kaminari cages while they're on
var _snake := {}  # the Ice Snake while you ride it


func _runner() -> AbilityRunner:
	return get_parent() as AbilityRunner


## Casts `a` if its shape is one of these; false if it isn't. `at`: the aimed spot (ultimates).
func cast(a: Dictionary, player: Node, dir: Vector3, at: Vector3) -> bool:
	var t: CombatTuning = GameData.tuning
	dir = Vector3(dir.x, 0.0, dir.z).normalized() if Vector3(dir.x, 0.0, dir.z).length() > 0.01 else Vector3.FORWARD
	match GameData.text(a, "shape"):
		"Rings":
			_later(t.spell_release_delay, _rings.bind(a, player))
		"Strike":
			var spot: Vector3 = at if at != Vector3.INF else player.global_position + dir * GameData.num(a, "range_m", 4.0)
			if not _own(a):  # the mark on the ground while the blade comes down
				UltimateFx.circle("Lightning", spot + Vector3.UP * 0.06, Vector3.UP, GameData.num(a, "radius_m", 3.0) * 0.6, t.spell_release_delay + 0.3)
			_later(t.spell_release_delay, _strike_down.bind(a, player, spot))
		"Fan":
			_later(t.spell_release_delay, _fan.bind(a, player, dir))
		"Cage":
			_cage(a, player, at)
		"Slide":
			_slide(a, player, dir, at)
		"Magma":
			_magma(a, player, at if at != Vector3.INF else player.global_position + dir * GameData.num(a, "range_m", 15.0))
		"Snake":
			_snake_ride(a, player)
		"Slab":
			_later(t.spell_release_delay, _slab.bind(a, player, dir, at))
		"Crush":
			_crush(a, player, dir, at)
		_:
			return false
	return true


func _later(seconds: float, f: Callable) -> void:
	if seconds <= 0.0:
		f.call()
	else:
		get_tree().create_timer(seconds, false).timeout.connect(f)


func _own(a: Dictionary) -> bool:
	return ElementFx.own_scene(GameData.text(a, "ability_id")) != null


func _alive(n: Node) -> bool:
	return is_instance_valid(n) and not n.is_dead()


## `a` with its damage times `k`.
func _scaled(a: Dictionary, k: float) -> Dictionary:
	var each := a.duplicate()
	each["base_damage"] = GameData.num(a, "base_damage") * k
	return each


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# ---------------------------------------------------------------- Rings: Lava Ripple, Ring of Ice

func _rings(a: Dictionary, player: Node) -> void:
	if not _alive(player):
		return
	var t: CombatTuning = GameData.tuning
	var center: Vector3 = player.global_position
	var radius := GameData.num(a, "radius_m", 4.0)
	var element := GameData.text(a, "damage_type", "Fire")
	if not _own(a):
		ElementFx.area(element, center, 1.2)  # the slam
		UltimateFx.circle(element, center + Vector3.UP * 0.06, Vector3.UP, 1.5, 0.6)
		UltimateFx._cracks(center, Vector3.UP, radius * 0.6)
		for i in t.ripple_rings:  # each ring a little smaller, fainter and slower than the one before
			var col := Color(ElementFx.color(element), 0.85 - 0.2 * i)
			var r := radius * (1.0 - 0.12 * i)
			var time := r / t.ripple_speed * (1.0 + 0.5 * i)
			_later(t.ripple_ring_gap * i, func(): Vfx.ring(center, r, col, time))
		if element == "Ice":
			for k in 3:  # rings of icicles, one after another, out to the edge
				var r := radius * (k + 1) / 3.0
				_later(r / t.ripple_speed, _icicles.bind(center, r, 6 + 4 * k))
	Combat.shake(t.shake_explosion)
	HitStop.trigger(t.hitstop_light)
	for e in Combat.enemies_in_radius(center, radius):
		var d := _flat(e.global_position - center).length()
		_later(d / t.ripple_speed, _ring_hit.bind(a, player, e, center, lerpf(1.0, t.ripple_edge_strength, clampf(d / radius, 0.0, 1.0))))


## The rolling ring reaches `e`: it hits as hard as `k` of the spell; ice freezes it once it's thrown.
func _ring_hit(a: Dictionary, player: Node, e: Node, center: Vector3, k: float) -> void:
	if not _alive(player) or not _alive(e):
		return
	_runner()._strike(_scaled(a, k), player, e, center, k > 0.7)
	if GameData.text(a, "damage_type") == "Ice":
		_later(0.35, _freeze_one.bind(e, GameData.tuning.ice_ring_freeze))


func _freeze_one(e, seconds: float) -> void:  # untyped: it may be freed by now
	if _alive(e):
		e.freeze(seconds)


# ---------------------------------------------------------------- Magma: Fire Q

var _magma_balls := []  # in your hand or in the air


## You reach down into the ground (user, 2026-11-20) and pull out a ball of magma, then hurl it at
## `spot`: it bursts there (the spell's damage over radius_m) and the ground burns.
func _magma(a: Dictionary, player: Node, spot: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	var feet: Vector3 = player.global_position
	var ground: Vector3 = feet + player.facing * 0.7 + (player.facing as Vector3).cross(Vector3.UP) * 0.3
	if not _own(a):
		UltimateFx.circle("Fire", ground + Vector3.UP * 0.06, Vector3.UP, 0.6, t.magma_pull_time + 0.2)
		ElementFx.area("Fire", ground, 0.6)  # the ground bubbles where your hand goes in
	var ball := Vfx._spawn(UltimateFx._sphere(t.magma_ball_size), Color(1.0, 0.45, 0.08), ground - Vector3.UP * 0.4) if not _own(a) else null
	if ball != null:
		var core := MeshInstance3D.new()  # the white-hot middle showing through
		core.mesh = UltimateFx._sphere(t.magma_ball_size * 0.7)
		core.material_override = Vfx.material(Color(1.0, 0.9, 0.5))
		ball.add_child(core)
		var flames := ElementFx.trail("Fire")
		if flames != null:
			ball.add_child(flames)
			flames.emitting = true
	_magma_balls.append({"a": a, "player": player, "spot": spot, "ball": ball, "from": ground, "time": 0.0, "thrown": false, "at": Vector3.ZERO, "vel": Vector3.ZERO})


## Where the ball sits in your raised right hand.
func _hand(player: Node) -> Vector3:
	var f: Vector3 = player.facing
	return player.global_position + Vector3.UP * 1.7 + f.cross(Vector3.UP) * 0.35 - f * 0.2


func _update_magma(m: Dictionary, delta: float) -> void:
	var t: CombatTuning = GameData.tuning
	var player: Node = m.player
	m.time += delta
	var ball: Node3D = m.ball if is_instance_valid(m.ball) else null
	if not m.thrown:
		if not _alive(player) or player.state != Player.State.CAST:  # knocked out of it: the ball drops and cools
			if ball != null:
				ElementFx.hit("Fire", ball.global_position, 0.6)
				ball.queue_free()
			_magma_balls.erase(m)
			return
		if ball != null:  # up out of the ground into your hand
			var up := clampf(m.time / t.magma_pull_time, 0.0, 1.0)
			ball.global_position = (m.from as Vector3).lerp(_hand(player), up * up) if up < 1.0 else _hand(player)
		if m.time >= t.magma_pull_time + t.magma_hold_time:
			m.thrown = true
			m.time = 0.0
			var to: Vector3 = m.spot - player.global_position
			player._face_yaw(atan2(-to.x, -to.z))
			player.cast_again("Throw", t.magma_throw_windup, t.magma_throw_windup + 0.3)
		return
	if m.time < t.magma_throw_windup:  # drawn back for the throw
		if ball != null:
			ball.global_position = _hand(player) if _alive(player) else ball.global_position
		var from: Vector3 = ball.global_position if ball != null else player.global_position + Vector3.UP * 1.7
		# Hurled hard and nearly flat (user, 2026-11-20), aimed a touch high so its slight drop lands it on the spot.
		var fly := from.distance_to(m.spot) / t.magma_speed
		var aim: Vector3 = m.spot + Vector3.UP * (0.5 * t.magma_drop * fly * fly + 0.3)
		m.at = from
		m.vel = (aim - from).normalized() * t.magma_speed
		return
	# It flies on until it touches something: an enemy, the ground or a wall, and bursts there.
	var at: Vector3 = m.at
	m.vel = (m.vel as Vector3) + Vector3.DOWN * t.magma_drop * delta
	var next: Vector3 = at + m.vel * delta
	var burst := Vector3.INF
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at, next, 0b001)) if is_inside_tree() else {}
	if not hit.is_empty():
		burst = hit.position
	for e in Combat.enemies_in_radius(next, t.magma_ball_size + 0.6):
		if e.global_position.y + e.aim_height() * 2.0 > next.y - t.magma_ball_size:  # under its head, not passing over it
			burst = next
			break
	m.at = next
	if ball != null:
		ball.global_position = next
	if burst != Vector3.INF or m.time > 4.0:
		_magma_balls.erase(m)
		if ball != null:
			ball.queue_free()
		_magma_burst(m.a, player, burst if burst != Vector3.INF else next)


func _magma_burst(a: Dictionary, player: Node, spot: Vector3) -> void:
	if not _alive(player):
		return
	var radius := GameData.num(a, "radius_m", 3.0)
	if not _own(a):
		UltimateFx._cracks(spot, Vector3.UP, radius)
		for k in 6:
			Vfx.chunk(spot + UltimateFx._in_disc(radius * 0.4), Vector3(randf_range(-4, 4), randf_range(4, 8), randf_range(-4, 4)), Color(1.0, 0.4, 0.05), 0.3)
	ElementFx.quiet = _own(a)
	_runner()._blast(a, player, spot, radius)  # damage, the throw outward, shake, hit-stop
	_runner()._burn_ground(a, player, spot, radius * 0.6)
	ElementFx.quiet = false


func holding_magma() -> bool:
	return not _magma_balls.is_empty()


## `n` icicles shoot up round a circle of radius `r`, leaning out; they stand, then shatter.
func _icicles(center: Vector3, r: float, n: int) -> void:
	var t: CombatTuning = GameData.tuning
	var col := Color(ElementFx.color("Ice"), 0.9)
	for i in n:
		var out := UltimateFx._around(i, n, r) + UltimateFx._in_disc(0.3)
		var ground := center + out
		var h := t.icicle_height * randf_range(0.6, 1.1)
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = h * 0.14
		c.height = h
		c.radial_segments = 5
		c.rings = 1
		var spike := Vfx._spawn(c, col, ground - Vector3.UP * h * 0.5)
		if spike == null:
			return
		var up := (Vector3.UP + out.normalized() * 0.4).normalized()
		spike.basis = Basis(Quaternion(Vector3.UP, up))
		var tw := spike.create_tween()
		tw.tween_property(spike, "global_position", ground + up * h * 0.5, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(t.icicle_stay * randf_range(0.8, 1.2))
		tw.tween_callback(func(): ElementFx.hit("Ice", spike.global_position, 0.6))  # it shatters
		tw.tween_callback(spike.queue_free)


# ---------------------------------------------------------------- Strike: Thunder Crash

func _strike_down(a: Dictionary, player: Node, spot: Vector3) -> void:
	if not _alive(player):
		return
	if not _own(a):
		var sky := spot + Vector3.UP * 18.0
		for i in 3:  # three bolts on top of each other make one thick one
			if not ElementFx.bolt_arc(sky + UltimateFx._in_disc(0.6), spot):
				ElementFx.beam("Lightning", sky, spot)
		Vfx.burst(spot, 2.0, Color(1, 1, 1, 0.7), 0.12)  # the white flash
		UltimateFx._cracks(spot, Vector3.UP, GameData.num(a, "radius_m", 3.0))
	_runner()._blast(a, player, spot, GameData.num(a, "radius_m", 3.0))  # damage, the throw outward, shake, hit-stop


# ---------------------------------------------------------------- Fan: Bolt Fan

func _fan(a: Dictionary, player: Node, dir: Vector3) -> void:
	if not _alive(player):
		return
	var t: CombatTuning = GameData.tuning
	var feet: Vector3 = player.global_position
	var hand := feet + Vector3.UP * 1.3 + dir * 0.5
	var reach := GameData.num(a, "range_m", 8.0)
	var n := maxi(2, int(GameData.num(a, "hits_or_projectiles", 7)))
	var half := deg_to_rad(t.fan_arc_deg) * 0.5
	if not _own(a):
		for i in n:
			var d := dir.rotated(Vector3.UP, lerpf(-half, half, float(i) / (n - 1)))
			var end := feet + Vector3.UP * 0.8 + d * reach
			if not ElementFx.bolt_arc(hand, end):
				ElementFx.beam("Lightning", hand, end)
	for e in Combat.enemies_in_radius(feet, reach):
		var to := _flat(e.global_position - feet)
		if to.length() < 0.5 or absf(dir.signed_angle_to(to.normalized(), Vector3.UP)) <= half:
			_runner()._strike(a, player, e, feet, true)
	Combat.shake(t.shake_explosion)
	HitStop.trigger(t.hitstop_light)


# ---------------------------------------------------------------- Cage: Kaminari

const HAWK := "res://models/gen/beast_hawk.glb"
const HAWK_WINGSPAN := 4.11  ## m across beast_hawk.glb's wings at scale 1

var _placing := {}  ## Kaminari's pillars placed so far, before its bolts start


## Press R once (user, 2026-11-20): you fly cage_lift_height up and have cage_place_time s to place
## cage_pillars pillars where you aim, one per click (Player._update_pillar_aim). Time's up: the rest
## stand at random round the ones you placed, and the bolts start.
func begin_placing(a: Dictionary, player: Node) -> void:
	if not _placing.is_empty():
		return
	var t: CombatTuning = GameData.tuning
	var feet: Vector3 = player.global_position
	_placing = {"a": a, "player": player, "pillars": [], "glows": [], "left": t.cage_place_time,
		"feet": feet, "lift": feet.y + t.cage_lift_height}
	_hover(_placing.lift, t.cage_place_time + 0.2)


func placing() -> bool:
	return not _placing.is_empty()


## A pillar where you clicked. True while more are to come; false for the last, which casts the
## ultimate (_cage puts it there and starts the bolts).
func place_pillar(at: Vector3) -> bool:
	if _placing.is_empty() or _placing.pillars.size() + 1 >= GameData.tuning.cage_pillars:
		return false
	_add_pillar(_placing, at)
	return true


func pillars_placed() -> int:
	return _placing.get("pillars", []).size()


## Holds you `y` high for `seconds` more (Player._move).
func _hover(y: float, seconds: float) -> void:
	var r := _runner()
	r.hover_y = y
	r._hover_left = maxf(r._hover_left, seconds)


## A pillar at `p` in `holder`: struck down from the sky, a large lightning bolt standing there till
## it ends (user, 2026-11-20): your bolt pictures, cage_pillar_height tall, flickering through them.
func _add_pillar(holder: Dictionary, p: Vector3) -> void:
	holder.pillars.append(p)
	if _own(holder.a):
		return
	var t: CombatTuning = GameData.tuning
	var frames := ElementFx.bolt_frames()
	var root := Vfx._root()
	if not frames.is_empty() and root != null:
		var quad := QuadMesh.new()
		quad.size = Vector2(t.cage_pillar_width, t.cage_pillar_height)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y  # upright, turned to the camera
		mat.albedo_color = Color(0.85, 0.92, 1.0)
		mat.albedo_texture = frames[0]
		var bolt := MeshInstance3D.new()
		bolt.mesh = quad
		bolt.material_override = mat
		bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bolt)
		bolt.global_position = p + Vector3.UP * t.cage_pillar_height * 0.5
		var tw := bolt.create_tween().set_loops()
		tw.tween_callback(func() -> void: mat.albedo_texture = frames[randi() % frames.size()])
		tw.tween_interval(t.cage_pillar_frame)
		holder.glows.append(bolt)
	else:
		var col := CylinderMesh.new()
		col.top_radius = 0.18
		col.bottom_radius = 0.18
		col.height = 14.0
		col.radial_segments = 6
		var glow := Vfx._spawn(col, Color(ElementFx.color("Lightning"), 0.75), p + Vector3.UP * 7.0)
		if glow != null:
			holder.glows.append(glow)
	if not ElementFx.bolt_arc(p + Vector3.UP * 18.0, p):
		ElementFx.beam("Lightning", p + Vector3.UP * 18.0, p)
	Combat.shake(t.shake_light)


## The last pillar goes at `spot` and the bolts start. Cast without placing (scripted), the pillars
## stand round the spot, radius_m out.
func _cage(a: Dictionary, player: Node, spot: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	var held: Dictionary = _placing if not _placing.is_empty() else {"a": a, "player": player, "pillars": [], "glows": []}
	_placing = {}
	if held.pillars.is_empty() and not held.has("lift"):
		for i in t.cage_pillars:
			_add_pillar(held, spot + UltimateFx._around(i, t.cage_pillars, GameData.num(a, "radius_m", 6.0)))
	else:
		_add_pillar(held, spot)
		_fill_round(held)
	_start_cage(a, player, held.pillars, held.glows, held.get("lift", INF))


## The pillars not placed stand at random round a circle radius_m out from the middle of the
## placed ones (from where you rose if none).
func _fill_round(held: Dictionary) -> void:
	var t: CombatTuning = GameData.tuning
	var player: Node = held.player
	var mid: Vector3 = held.feet
	if not held.pillars.is_empty():
		mid = Vector3.ZERO
		for p: Vector3 in held.pillars:
			mid += p
		mid /= held.pillars.size()
	var radius := GameData.num(held.a, "radius_m", 4.0)
	while held.pillars.size() < t.cage_pillars:
		var p := mid + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * radius * randf_range(0.7, 1.2)
		var ground: float = player.floor_below(p.x, p.z, mid.y + 30.0) if _alive(player) and player.has_method("floor_below") else -INF
		p.y = ground if ground != -INF else mid.y
		_add_pillar(held, p)


## While you place them you stay up; once cage_place_time runs out, the rest are placed for you and
## the bolts start (the ultimate's cooldown with them).
func _update_placing(delta: float) -> void:
	var player: Node = _placing.player
	if not _alive(player):
		for g in _placing.glows:
			if is_instance_valid(g):
				g.queue_free()
		_placing = {}
		return
	_placing.left -= delta
	_hover(_placing.lift, 0.2)
	if _placing.left > 0.0:
		return
	var held := _placing
	_placing = {}
	_fill_round(held)
	var r := _runner()
	r.remaining["Ultimate"] = r.cooldown_of("Ultimate", player)
	r.cooldowns_changed.emit()
	_start_cage(held.a, player, held.pillars, held.glows, held.lift)


## Bolts bounce between `pillars` for cage_time, each carried by a lightning hawk; who stands
## inside them when it starts is caught there, struck again and again; you float above.
func _start_cage(a: Dictionary, player: Node, pillars: Array, glows: Array, lift := INF) -> void:
	var t: CombatTuning = GameData.tuning
	var spot := Vector3.ZERO
	for p: Vector3 in pillars:
		spot += p
	spot /= pillars.size()
	var radius := 0.0  # inside: within the pillars' average distance from their middle
	for p: Vector3 in pillars:
		radius += _flat(p - spot).length() / pillars.size()
	radius = maxf(radius, 1.5)
	var c := {"a": a, "player": player, "spot": spot, "radius": radius, "pillars": pillars, "glows": glows,
		"left": t.cage_time, "flicker": 0.0, "bolts": [], "struck": {}, "own": _own(a), "trapped": Combat.enemies_in_radius(spot, radius)}
	# Your bolt, thrown from your hand to the first pillar, and two already bouncing off every pillar.
	var hand: Vector3 = player.global_position + Vector3.UP * 1.3 if _alive(player) else pillars[0]
	_add_bolt(c, hand, 0, t.cage_bolt_speed)
	for i in pillars.size() * 2:
		var from: int = i % pillars.size()
		_add_bolt(c, pillars[from] + Vector3.UP * 1.2, _other_pillar(c, from), t.cage_bolt_speed)
	_cages.append(c)
	Combat.shake(t.shake_heavy)
	if _alive(player):  # you float cage_lift_height up while it lasts (already up, if you placed them)
		_hover(lift if lift != INF else player.global_position.y + t.cage_lift_height, t.cage_time)


## A bolt flying from `from` to pillar `to` at `speed`, carried by a lightning hawk (user,
## 2026-11-20): beast_hawk.glb in lightning colour, beating its wings (BeastModel).
func _add_bolt(c: Dictionary, from: Vector3, to: int, speed: float) -> void:
	var t: CombatTuning = GameData.tuning
	var hawk: BeastModel = null
	var root := Vfx._root()
	if not c.own and root != null:
		hawk = BeastModel.new()
		root.add_child(hawk)
		if hawk.setup_beast(HAWK, t.cage_hawk_size / HAWK_WINGSPAN):
			hawk.play("Running_A")
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = ElementFx.color("Lightning").lightened(0.4)
			for m: MeshInstance3D in hawk.find_children("*", "MeshInstance3D", true, false):
				m.material_override = mat
			var sparks := ElementFx.trail("Lightning")
			if sparks != null:
				hawk.add_child(sparks)
				sparks.emitting = true
			hawk.global_position = from
		else:
			hawk.queue_free()
			hawk = null
	c.bolts.append({"from": from, "to": to, "f": 0.0, "speed": speed, "hawk": hawk})


## A pillar other than `i`, picked at random.
func _other_pillar(c: Dictionary, i: int) -> int:
	var n: int = c.pillars.size()
	return (i + randi_range(1, n - 1)) % n


func _physics_process(delta: float) -> void:
	if not _placing.is_empty():
		_update_placing(delta)
	for c: Dictionary in _cages.duplicate():
		_update_cage(c, delta)
	for m: Dictionary in _magma_balls.duplicate():
		_update_magma(m, delta)
	if not _snake.is_empty():
		_update_snake(delta)


func _update_cage(c: Dictionary, delta: float) -> void:
	var t: CombatTuning = GameData.tuning
	var player: Node = c.player
	c.left -= delta
	if c.left <= 0.0 or not _alive(player):
		_end_cage(c)
		return
	_hold_trapped(c)
	c.flicker -= delta
	if c.flicker <= 0.0 and not c.own:  # the pillars crackle
		c.flicker = 0.15
		var p: Vector3 = c.pillars[randi() % c.pillars.size()]
		ElementFx.bolt_arc(p + Vector3.UP * 14.0, p)
	for b: Dictionary in c.bolts.duplicate():
		var target: Vector3 = c.pillars[b.to] + Vector3.UP * 1.2
		var length := maxf(0.5, (b.from as Vector3).distance_to(target))
		b.f += b.speed * delta / length
		var at: Vector3 = (b.from as Vector3).lerp(target, minf(b.f, 1.0))
		if is_instance_valid(b.hawk):
			b.hawk.global_position = at
		for e in Combat.enemies_in_radius(at, 1.3):  # what it passes is struck and tossed (the caught ones only shake)
			if Combat.time - float(c.struck.get(e, -99.0)) >= t.cage_rehit:
				c.struck[e] = Combat.time
				if c.trapped.has(e):
					_shock(c, e)
				else:
					_runner()._strike(c.a, player, e, at, true)
		if b.f >= 1.0:  # it bounces off the pillar, faster, and splits
			var from: int = b.to
			b.from = target
			b.to = _other_pillar(c, from)
			b.f = 0.0
			b.speed *= t.cage_speedup
			if not c.own and not ElementFx.bolt_arc(target, c.pillars[b.to] + Vector3.UP * 1.2):
				ElementFx.beam("Lightning", target, c.pillars[b.to] + Vector3.UP * 1.2)
			if c.bolts.size() < t.cage_max_bolts:
				_add_bolt(c, target, _other_pillar(c, from), b.speed)
		if is_instance_valid(b.hawk):  # faced after the bounce, so it turns at the pillar, not a frame late
			var way: Vector3 = c.pillars[b.to] + Vector3.UP * 1.2 - b.hawk.global_position
			if way.length() > 0.01 and absf(way.normalized().y) < 0.99:
				b.hawk.look_at(b.hawk.global_position + way, Vector3.UP)


## The caught ones stay inside, struck every cage_rehit s whether a bolt passes or not, never thrown out.
func _hold_trapped(c: Dictionary) -> void:
	var t: CombatTuning = GameData.tuning
	var spot: Vector3 = c.spot
	var inside: float = c.radius - 0.8
	for e in c.trapped.duplicate():
		if not is_instance_valid(e) or e.is_dead():
			c.trapped.erase(e)
			continue
		var out := _flat(e.global_position - spot)
		if out.length() > inside:  # pushed back from the edge
			e.global_position = Vector3(spot.x, e.global_position.y, spot.z) + out.normalized() * inside
		if Combat.time - float(c.struck.get(e, -99.0)) >= t.cage_rehit:
			c.struck[e] = Combat.time
			_shock(c, e)
			if not c.own:
				var p: Vector3 = c.pillars[randi() % c.pillars.size()] + Vector3.UP * 1.2
				if not ElementFx.bolt_arc(p, e.global_position + Vector3.UP):
					ElementFx.beam("Lightning", p, e.global_position + Vector3.UP)


## A caught one is struck where it stands: cage_trap_damage of the spell, no throw.
func _shock(c: Dictionary, e: Node) -> void:
	var player: Node = c.player
	var info: DamageInfo = player.make_hit(GameData.num(c.a, "base_damage") * GameData.tuning.cage_trap_damage, "Lightning", "Magic", e, DamageInfo.Kind.ABILITY)
	info.no_launch = true
	info.knockback = 0.0
	_runner()._add_status(c.a, player, info)
	Combat.deal(e, info)


## The pillars collapse in one big burst.
func _end_cage(c: Dictionary) -> void:
	_cages.erase(c)
	for b: Dictionary in c.bolts:
		if is_instance_valid(b.hawk):
			b.hawk.queue_free()
	for g in c.glows:
		if is_instance_valid(g):
			g.queue_free()
	if _alive(c.player):
		ElementFx.quiet = c.own
		_runner()._blast(c.a, c.player, c.spot, c.radius)
		ElementFx.quiet = false


func caging() -> bool:
	return not _cages.is_empty()


# ---------------------------------------------------------------- Slide: Ice Slide

func _slide(a: Dictionary, player: Node, dir: Vector3, at := Vector3.INF) -> void:
	var t: CombatTuning = GameData.tuning
	var r := _runner()
	r.invulnerable = true
	var start: Vector3 = player.global_position
	var goal := at if at != Vector3.INF else start + dir * GameData.num(a, "range_m", 9.0)
	var trail := {"last": start}
	_ice_patch(a, player, start)
	var tw := create_tween()
	tw.tween_method(_slide_step.bind(a, player, start, goal, trail), 0.0, 1.0, t.slide_time)
	tw.tween_callback(func(): r.invulnerable = false)


## One step of the slide; a patch of ice every 1.5 m.
func _slide_step(f: float, a: Dictionary, player: Node, start: Vector3, goal: Vector3, trail: Dictionary) -> void:
	_runner()._leap_step(f, player, start, goal, 0.0)
	if _alive(player) and _flat(player.global_position - trail.last).length() >= 1.5:
		trail.last = player.global_position
		_ice_patch(a, player, trail.last)


## A patch of the ice trail at `p`: it slows (Ice) and nicks whoever stands on it, then melts.
func _ice_patch(a: Dictionary, player: Node, p: Vector3) -> void:
	if not _alive(player):
		return
	var t: CombatTuning = GameData.tuning
	var chill := DamageInfo.make(GameData.num(a, "base_damage", 1.0), "Ice", DamageInfo.Kind.STATUS, player).with_status("ice")
	var col := Color(0.75, 0.93, 1.0) if not _own(a) else Color(0, 0, 0, 0)
	Hazard.spawn(p, GameData.num(a, "radius_m", 1.5), t.ice_trail_time, 0.5, chill, col)
	if not _own(a):
		ElementFx.hit("Ice", p + Vector3.UP * 0.3, 0.5)  # frost mist puffing behind


# ---------------------------------------------------------------- Snake: Ice Snake

## A giant ice snake rises out of the ground under you (user, 2026-11-20). You ride it for
## ice_snake_time s; it never stops and flies where you look (Player._move); a click breathes
## icicles (snake_breath). Its body freezes what it touches; what that touch kills shatters.
func _snake_ride(a: Dictionary, player: Node) -> void:
	var t: CombatTuning = GameData.tuning
	var feet: Vector3 = player.global_position
	var gap := t.ice_snake_size * 0.45  # meters between pieces: they overlap into one smooth body
	var trail: Array[Vector3] = []
	for i in t.ice_snake_segments:  # standing straight down into the ground: it pours up out of it
		trail.append(feet - Vector3.UP * gap * (t.ice_snake_segments - i))
	_snake = {"a": a, "player": player, "left": t.ice_snake_time, "ground": feet.y, "trail": trail,
		"gap": gap, "touched": {}, "node": null, "pieces": [] as Array[Node3D], "breath_at": 0}
	_runner().invulnerable = true
	var root := Vfx._root()
	if not _own(a) and root != null:
		var node := Node3D.new()
		root.add_child(node)
		_snake.node = node
		_snake.pieces = _snake_body(node, t.ice_snake_segments, t.ice_snake_size)
		UltimateFx._cracks(feet, Vector3.UP, 3.0)
		ElementFx.area("Ice", feet, 3.0)
	Combat.shake(t.shake_heavy)


## The snake built in code (user, 2026-11-20: a snake, not a dragon): round ice pieces thinning to
## the tail, a flat wedge of a head with two dark eyes. Hidden until they're out of the ground.
func _snake_body(parent: Node3D, n: int, size: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var ice := StandardMaterial3D.new()
	ice.albedo_color = ElementFx.color("Ice").lightened(0.35)
	ice.emission_enabled = true
	ice.emission = ElementFx.color("Ice") * 0.35
	ice.metallic_specular = 1.0
	ice.roughness = 0.15
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	for i in n:
		var piece := Node3D.new()
		var skin := MeshInstance3D.new()
		skin.mesh = ball
		skin.material_override = ice
		piece.add_child(skin)
		var k := float(i) / maxi(n - 1, 1)  # 0 at the head, 1 at the tail
		if i == 0:
			skin.scale = Vector3(0.95, 0.55, 1.5)  # wide, flat and long
			skin.position.z = -0.25
			for side in [-1.0, 1.0]:
				var eye := MeshInstance3D.new()
				eye.mesh = ball
				eye.material_override = Vfx.material(Color(0.05, 0.1, 0.2))
				eye.scale = Vector3.ONE * 0.16
				eye.position = Vector3(side * 0.38, 0.2, -0.55)
				piece.add_child(eye)
		else:
			skin.scale = Vector3(1.0, 1.0, 1.3)  # a little longer than round: the pieces blend
		piece.scale = Vector3.ONE * size * (1.0 if i == 0 else lerpf(0.9, 0.15, k))
		piece.visible = false
		if i % 4 == 1:
			var mist := ElementFx.trail("Ice")
			if mist != null:
				piece.add_child(mist)
				mist.emitting = true
		parent.add_child(piece)
		out.append(piece)
	return out


func riding() -> bool:
	return not _snake.is_empty()


## The lowest and highest the rider can fly.
func ride_floor() -> float:
	return _snake.ground + GameData.tuning.ice_snake_height


func ride_ceiling() -> float:
	return _snake.ground + GameData.tuning.ice_snake_max_height


## Where the snake's head is and which way it looks.
func _snake_head(player: Node) -> Array:
	var v: Vector3 = player.velocity
	var ahead: Vector3 = v.normalized() if v.length() > 0.5 else player.facing
	return [player.global_position + ahead * _snake.gap * 2.0 - Vector3.UP * GameData.tuning.ice_snake_size * 0.4, ahead]


func _update_snake(delta: float) -> void:
	var t: CombatTuning = GameData.tuning
	var player: Node = _snake.player
	_snake.left -= delta
	if _snake.left <= 0.0 or not _alive(player):
		_end_snake()
		return
	var hd := _snake_head(player)
	var head: Vector3 = hd[0]
	var trail: Array[Vector3] = _snake.trail
	if head.distance_to(trail[-1]) >= _snake.gap:
		trail.append(head)
		if trail.size() > t.ice_snake_segments:
			trail.pop_front()
	var pieces: Array[Node3D] = _snake.pieces
	for i in pieces.size():  # the head where you're going, the body down the way you came
		var here: Vector3 = head if i == 0 else trail[maxi(trail.size() - i, 0)]
		var toward: Vector3 = hd[1] if i == 0 else (head if i == 1 else trail[mini(trail.size() - i + 1, trail.size() - 1)]) - here
		pieces[i].visible = here.y > _snake.ground - 0.5
		pieces[i].global_position = here
		if toward.length() > 0.001 and absf(toward.normalized().y) < 0.999:
			pieces[i].look_at(here + toward, Vector3.UP)
	var touched: Dictionary = _snake.touched
	for p: Vector3 in trail + [head]:
		if p.y < _snake.ground - 0.5:
			continue  # still in the ground
		for e in Combat.enemies_in_radius(p, t.ice_snake_reach):
			if p.y - e.global_position.y > t.ice_snake_reach + e.aim_height():
				continue  # flying over its head
			if not touched.has(e.get_instance_id()):
				touched[e.get_instance_id()] = true
				_snake_touch(_snake.a, player, e)


## The snake's body touches `e`: it's hurt and frozen; if that kills it, it shatters.
func _snake_touch(a: Dictionary, player: Node, e: Node) -> void:
	var info: DamageInfo = player.make_hit(GameData.num(a, "base_damage"), "Ice", "Magic", e, DamageInfo.Kind.ABILITY)
	info.no_launch = true
	Combat.deal(e, info)
	if not e.is_dead():
		e.freeze(GameData.tuning.ice_snake_freeze)
		return
	var at: Vector3 = e.global_position + Vector3.UP * e.aim_height()
	var col := ElementFx.color("Ice")
	e.visible = false  # nothing left of it but the shards
	for k in 8:
		Vfx.chunk(at, Vector3(cos(k * TAU / 8.0), randf_range(0.5, 1.2), sin(k * TAU / 8.0)) * 5.0, col, 0.2)
	Vfx.burst(at, 1.3, Color(col, 0.85), 0.2)
	ElementFx.hit("Ice", at, 1.5)


## A click while riding (user, 2026-11-20): the snake breathes a fan of icicles where you look. They
## knock what they hit back hard and pin it to the wall behind (a heavy Missile hit: Enemy.launch_from_hit).
func snake_breath() -> void:
	var t: CombatTuning = GameData.tuning
	if not riding() or Combat.now_msec() < _snake.breath_at:
		return
	_snake.breath_at = Combat.now_msec() + int(t.ice_breath_gap * 1000.0)
	var player: Node = _snake.player
	var mouth: Vector3 = _snake_head(player)[0] + Vector3.UP * t.ice_snake_size * 0.2
	var look: Vector3 = player.look_direction()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.12
	cone.height = 0.9
	cone.radial_segments = 6
	for i in t.ice_breath_icicles:
		var f := (float(i) / maxi(t.ice_breath_icicles - 1, 1) - 0.5) * 2.0  # -1..1 across the fan
		var dir := look.rotated(Vector3.UP, deg_to_rad(t.ice_breath_spread_deg * 0.5 * f))
		var info: DamageInfo = player.make_hit(t.ice_breath_damage, "Ice", "Missile", null, DamageInfo.Kind.HEAVY)
		info.knockback = t.knockback_heavy
		info.pin_weapon = "icicle"
		var shot := Projectile.fire(mouth, dir, t.ice_breath_speed, info, ElementFx.color("Ice").lightened(0.4), 2)
		if shot == null:
			continue
		shot.radius = 0.6
		shot._mesh.mesh = cone
		shot._mesh.rotation.x = -PI * 0.5  # the point leads
	if not _own(_snake.a):
		ElementFx.hit("Ice", mouth + look, 1.0)  # the frost puff from its mouth
	Combat.shake(t.shake_light)


## Time's up: the snake bursts into ice under you and you drop.
func _end_snake() -> void:
	var player: Node = _snake.player
	if is_instance_valid(player):
		player.collision_mask = 0b101  # Player._move let you pass through enemies while riding
	_runner().invulnerable = false
	for piece: Node3D in _snake.pieces:
		if is_instance_valid(piece) and piece.visible:
			ElementFx.hit("Ice", piece.global_position, 0.8)
			Vfx.chunk(piece.global_position, Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3)), ElementFx.color("Ice"), 0.25)
	if is_instance_valid(_snake.node):
		_snake.node.queue_free()
	Combat.shake(GameData.tuning.shake_heavy)
	_snake = {}


# ---------------------------------------------------------------- Slab: Stone Slab

const SLAB_SHAPES := ["Fist", "Hammer", "Tree", "Dolphin"]
const SLAB_HEIGHT := 4.0  # about how tall each shape stands (m)


## The slab's shape (user, 2026-11-20), all stone, standing on its own ground point, its front (+Z)
## your way: a fist punching up, your war hammer head up, an oak, or a dolphin leaping nose first.
func _slab_shape(kind: String) -> Node3D:
	var slab := Node3D.new()
	var model: Node3D
	match kind:
		"Hammer":  # 1.14 m long, the handle's end 0.44 m below its middle
			model = (load("res://models/own/weapon_warhammer.glb") as PackedScene).instantiate()
			model.scale = Vector3.ONE * 3.5
			model.position.y = 0.44 * 3.5
		"Tree":  # 4.8 m tall, roots 0.26 m below its middle
			model = (load("res://models/gen/world/Tree_Oak_A.glb") as PackedScene).instantiate()
			model.scale = Vector3.ONE * 0.85
			model.position.y = 0.26 * 0.85
		"Dolphin":  # 2.9 m nose (+Z) to tail: turned nose up, the tail on the ground
			model = (load("res://models/gen/animal_dolphin.glb") as PackedScene).instantiate()
			model.scale = Vector3.ONE * 1.4
			model.rotation.x = deg_to_rad(-90.0)
			model.position.y = 1.45 * 1.4
		_:  # Fist: no model of one, so blocks: forearm, fist, curled fingers in front, knuckles on top, thumb
			model = Node3D.new()
			for part in [[Vector3(1.0, 2.2, 1.0), Vector3(0, 1.1, 0)], [Vector3(1.5, 1.3, 1.2), Vector3(0, 2.85, -0.1)],
					[Vector3(1.0, 0.35, 0.35), Vector3(0.2, 2.35, 0.75)]]:
				_block(model, part[0], part[1])
			for x in [-0.54, -0.18, 0.18, 0.54]:
				_block(model, Vector3(0.34, 0.9, 0.4), Vector3(x, 2.8, 0.55))
				_block(model, Vector3(0.34, 0.25, 0.5), Vector3(x, 3.55, 0.15))
	slab.add_child(model)
	for m in slab.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = STONE_SKIN
	return slab


func _block(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var m := MeshInstance3D.new()
	m.mesh = box
	m.position = at
	parent.add_child(m)


func _slab(a: Dictionary, player: Node, dir: Vector3, at: Vector3) -> void:
	if not _alive(player):
		return
	var t: CombatTuning = GameData.tuning
	var feet: Vector3 = player.global_position
	var length := GameData.num(a, "range_m", 6.0)
	var half_w := GameData.num(a, "radius_m", 1.5)
	var mid: Vector3 = at if at != Vector3.INF else feet + dir * (length * 0.5 + 0.5)
	if not _own(a):
		var root := Vfx._root()
		if root != null:
			var kind: String = t.slab_shape if t.slab_shape != "Random" else SLAB_SHAPES.pick_random()
			var slab := _slab_shape(kind)
			root.add_child(slab)
			slab.global_position = mid - Vector3.UP * SLAB_HEIGHT
			slab.basis = Basis.looking_at(dir, Vector3.UP, true)
			var tw := slab.create_tween()
			tw.tween_property(slab, "global_position", mid, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(t.slab_stay)
			tw.tween_callback(func() -> void:
				slab.global_position += Vector3.UP * SLAB_HEIGHT * 0.5  # the rubble comes off its middle
				_crumble(slab)
				ElementFx.area("Stone", slab.global_position, half_w * 1.5)
				slab.queue_free())
		UltimateFx._cracks(mid, Vector3.UP, half_w * 2.0)
		ElementFx.area("Stone", mid, half_w * 1.5)
	for e in Combat.enemies_in_radius(mid, half_w * 1.5 + 1.0):
		var to := _flat(e.global_position - mid)
		# what stands on the pillar's square is launched
		if absf(to.dot(dir)) <= half_w + 0.5 and absf(to.dot(dir.cross(Vector3.UP))) <= half_w + 0.5:
			_runner()._strike(a, player, e, feet - dir * 2.0, true)  # launched up and away from you
	# cast under you (user, 2026-11-20): it throws you up too, without hurting you
	var you := _flat(feet - mid)
	if absf(you.dot(dir)) <= half_w + 0.5 and absf(you.dot(dir.cross(Vector3.UP))) <= half_w + 0.5:
		player.velocity.y = t.slab_player_launch
	Combat.shake(t.shake_explosion)
	HitStop.trigger(t.hitstop_light)


# ---------------------------------------------------------------- Crush: Crushing Pillars

func _crush(a: Dictionary, player: Node, dir: Vector3, spot: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	var right := dir.cross(Vector3.UP).normalized()
	var half := t.pillar_gap * 0.5
	if not _own(a):
		var ram_scene := load(RAM) as PackedScene
		for s in [-1.0, 1.0]:
			# each rises a body length from the spot and rears up right there, no charge (user 2026-11-20)
			var at: Vector3 = spot + right * s * 1.97 * t.ram_size
			UltimateFx.circle("Stone", at + Vector3.UP * t.ram_size, -right * s, t.ram_size * 1.1, t.pillar_delay + t.ram_rear_time)
			var ram := _stone_ram(ram_scene, at, -right * s)
			if ram == null:
				continue
			var size := Vector3.ONE * t.ram_size
			ram.scale = size * 0.05  # still inside the circle
			_still_pose(ram)
			var tw := ram.create_tween()
			tw.tween_property(ram, "scale", size, t.pillar_delay * 0.5).set_delay(t.pillar_delay * 0.5)
			var face := ram.basis.orthonormalized()
			var k := t.ram_size
			# rears up on its hind hooves, front legs curling up, shedding stone bits
			var hoof: Vector3 = at + face * RAM_HOOF * k
			tw.tween_callback(_curl_front_legs.bind(ram))
			tw.tween_method(func(d: float): _lean(ram, face, k, d, hoof), 0.0, RAM_REAR_DEG, t.ram_rear_time * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_method(_shed.bind(ram), 0, int(t.ram_rear_time * 9.0), t.ram_rear_time * 0.45)
			tw.tween_method(_shed.bind(ram), 0, int(t.ram_rear_time * 11.0), t.ram_rear_time * 0.55)
			# then drops forward into the clash: horns locked, the front 15 degrees up, hind hooves on the
			# ground (measured in Blender: with the head twisted the horns reach 1.18 m ahead of its middle)
			tw.tween_callback(_head_down.bind(ram))
			var hoof_meet: Vector3 = spot + right * s * 1.18 * k + (face * Basis(Vector3.RIGHT, deg_to_rad(-15.0))) * RAM_HOOF * k
			hoof_meet.y = spot.y
			tw.tween_method(func(f: float): _lean(ram, face, k, lerpf(RAM_REAR_DEG, 15.0, f), hoof.lerp(hoof_meet, f)), 0.0, 1.0, t.ram_lunge_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_interval(0.35)
			tw.tween_property(ram, "scale", size * 0.3, 0.3)
			tw.tween_callback(ram.queue_free)
	_later(t.pillar_delay + t.ram_rear_time + t.ram_lunge_time, _slam.bind(a, player, spot, right, half))


## Your war ram model, all stone, standing at `at` and facing `facing`.
func _stone_ram(scene: PackedScene, at: Vector3, facing: Vector3) -> Node3D:
	var root := Vfx._root()
	if scene == null or root == null:
		return null
	var ram := scene.instantiate() as Node3D
	for m in ram.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = STONE_SKIN
	ram.add_to_group("stone_ram")
	root.add_child(ram)
	ram.global_position = at
	ram.basis = Basis.looking_at(facing, Vector3.UP, true)
	return ram


## Stone bits shaken off a rearing ram (called 20 times a second; `_tick` is the count).
func _shed(_tick: int, ram: Node3D) -> void:
	var k := ram.scale.x
	for i in GameData.tuning.ram_shed_chunks:
		Vfx.chunk(ram.global_position + Vector3.UP * k + UltimateFx._in_disc(k * 0.8), Vector3(randf_range(-2, 2), randf_range(1, 4), randf_range(-2, 2)), UltimateFx.STONE, 0.12 * k)


## The rams' legs never move (user 2026-11-20): Idle held at its first frame. Frames are Blender's, 24 a second.
func _still_pose(ram: Node3D) -> void:
	for p: AnimationPlayer in ram.find_children("*", "AnimationPlayer", true, false):
		if p.has_animation("Idle"):
			p.play("Idle")
			p.seek(0.0, true)
			p.active = false  # holds it; the head and neck are set by hand in _head_down


## Head and neck lowered for the clash, from Attack_Headbutt frame 6.
func _head_down(ram: Node3D) -> void:
	var skels := ram.find_children("*", "Skeleton3D", true, false)
	for p: AnimationPlayer in ram.find_children("*", "AnimationPlayer", true, false):
		if skels.is_empty() or not p.has_animation("Attack_Headbutt"):
			continue
		var butt := p.get_animation("Attack_Headbutt")
		var skel := skels[0] as Skeleton3D
		for i in butt.get_track_count():
			var bone := skel.find_bone(butt.track_get_path(i).get_concatenated_subnames())
			if bone < 0 or skel.get_bone_name(bone) not in ["Head", "Neck3", "Neck2", "Neck1"]:
				continue
			if butt.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				skel.set_bone_pose_rotation(bone, butt.rotation_track_interpolate(i, 6.0 / 24.0))
			elif butt.track_get_type(i) == Animation.TYPE_POSITION_3D:
				skel.set_bone_pose_position(bone, butt.position_track_interpolate(i, 6.0 / 24.0))
		# twisted a little to its own left, so the two rams' horns cross (user 2026-11-20)
		_turn_bone(skel, "Head", Vector3.UP, 20.0)
		_turn_bone(skel, "Head", Vector3.BACK, -20.0)


## Front legs curled up under the chest, like a real ram rearing (tried out in Blender).
func _curl_front_legs(ram: Node3D) -> void:
	for skel: Skeleton3D in ram.find_children("*", "Skeleton3D", true, false):
		for side in ["L", "R"]:
			_turn_bone(skel, "FrontUpperLeg." + side, Vector3.RIGHT, -60.0)
			_turn_bone(skel, "FrontLowerLeg." + side, Vector3.RIGHT, 110.0)


## Turns `bone_name` `deg` about the model's own `axis`, round the bone's joint.
func _turn_bone(skel: Skeleton3D, bone_name: String, axis: Vector3, deg: float) -> void:
	var b := skel.find_bone(bone_name)
	if b < 0:
		return
	var g := skel.get_bone_global_pose(b)
	skel.set_bone_global_pose(b, Transform3D(Basis(axis, deg_to_rad(deg)) * g.basis, g.origin))


## Tips the ram `deg` nose-up about its hind hooves, which stand at `hoof`. `face`: its unscaled facing.
func _lean(ram: Node3D, face: Basis, k: float, deg: float, hoof: Vector3) -> void:
	if not is_instance_valid(ram):
		return
	var b := (face * Basis(Vector3.RIGHT, deg_to_rad(-deg))).scaled(Vector3.ONE * k)
	ram.basis = b
	ram.global_position = hoof - b * RAM_HOOF


## A slab breaks into rubble.
func _crumble(pillar: Node3D) -> void:
	for k in 6:
		Vfx.chunk(pillar.global_position + UltimateFx._in_disc(1.0), Vector3(randf_range(-3, 3), randf_range(2, 6), randf_range(-3, 3)), UltimateFx.STONE, 0.4)


## The rams meet: what's between them takes it all and goes down; the rest at the edges is knocked out.
func _slam(a: Dictionary, player: Node, spot: Vector3, right: Vector3, half: float) -> void:
	if not _alive(player):
		return
	var t: CombatTuning = GameData.tuning
	var radius := GameData.num(a, "radius_m", 3.0)
	ElementFx.quiet = _own(a)
	ElementFx.area("Stone", spot, radius)
	ElementFx.quiet = false
	for e in Combat.enemies_in_radius(spot, half):
		var to := _flat(e.global_position - spot)
		if absf(to.dot(right)) <= half and to.length() <= radius:
			var each := a.duplicate()
			each["slot"] = "Ultimate"  # knocked down
			_runner()._strike(each, player, e, spot, true)
		elif to.length() <= half:
			_runner()._strike(_scaled(a, 0.5), player, e, spot)
	Combat.shake(t.shake_heavy)
	HitStop.trigger(t.hitstop_heavy)
