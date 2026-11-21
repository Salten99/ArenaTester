class_name Spells
extends Node
## The arena's spells that aren't a plain blast (Arena Magic Attacks sheet, user 2026-11-20). A child
## of the AbilityRunner; the God Abilities `shape` column picks one:
##   Rings   rings roll out from you to radius_m; the nearer, the harder (Lava Ripple, Ring of Ice)
##   Strike  one big bolt on the spot range_m ahead, throwing what's near (Thunder Crash)
##   Fan     hits_or_projectiles bolts fan across fan_arc_deg in front, range_m long (Bolt Fan)
##   Spear   a lightning bolt thrown from your hand, a dragon coiled round it, jumping enemy to enemy (Kaminari)
##   Slide   slide range_m on a trail of ice that slows (Ice Slide)
##   Freeze  everything within radius_m locks in ice, then shatters (Deep Freeze)
##   Slab    a square stone pillar shoots up ahead, launches what's on it, then bursts into dust (Stone Slab)
##   Crush   two stone pillars slam together on the aimed spot (Crushing Pillars)
##   Magma   reach into the ground, pull out a magma ball and hurl it at the aimed spot (Magma Ball)
## The looks are built in code; your models/own/fx/<ability_id>.tscn plays instead once you make it.
## The numbers are in combat_tuning.tres, group Spells.

var _spears := []  # Kaminari spears while they fly


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
		"Spear":
			_spear(a, player, at if at != Vector3.INF else player.global_position + dir * GameData.num(a, "range_m", 20.0))
		"Slide":
			_slide(a, player, dir, at)
		"Magma":
			_magma(a, player, at if at != Vector3.INF else player.global_position + dir * GameData.num(a, "range_m", 15.0))
		"Freeze":
			_freeze(a, player)
		"Slab":
			_later(t.spell_release_delay, _slab.bind(a, player, dir))
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


# ---------------------------------------------------------------- Spear: Kaminari

## You hold a lightning bolt in your hand, your bolt pictures flickering kaminari_bolt_length long,
## and throw it where the crosshair is, a lightning dragon coiling round it every which way (user,
## 2026-11-20). It jumps from enemy to enemy for kaminari_time; once only one enemy is left alive it
## strikes in and out of that one until it's dead.
func _spear(a: Dictionary, player: Node, spot: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	var hand := _right_hand(player)
	var s := {"a": a, "player": player, "at": hand, "goal": spot, "target": null, "last": null,
		"held": t.kaminari_hold_time, "left": t.kaminari_time, "fwd": (spot - hand).normalized(), "node": null,
		"pieces": [] as Array[Node3D], "bolt": null, "frame": 0.0, "fi": 0,
		"spin": randf() * TAU, "rate": 0.0, "turn": t.kaminari_coil_turn, "wobble": randf() * TAU, "change": 0.0}
	_new_coil(s)
	s.rate = s.rate_goal
	s.turn = s.turn_goal
	var root := Vfx._root()
	if not _own(a) and root != null:
		var node := Node3D.new()
		root.add_child(node)
		node.global_position = hand
		if not ElementFx.bolt_frames().is_empty():
			var quad := QuadMesh.new()
			quad.size = Vector2(t.kaminari_bolt_width, t.kaminari_bolt_length)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_color = Color(0.85, 0.92, 1.0)
			var bolt := MeshInstance3D.new()
			bolt.mesh = quad
			bolt.material_override = mat
			bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(bolt)
			s.bolt = bolt
		var sparks := ElementFx.trail("Lightning")
		if sparks != null:
			node.add_child(sparks)
			sparks.emitting = true
		s.node = node
		s.pieces = FireDragon.build(node, t.kaminari_dragon_segments, t.kaminari_dragon_size, "Lightning",
			t.kaminari_dragon_segments, ElementFx.color("Lightning").lightened(0.4))
	_spears.append(s)
	_place_spear(s, 0.0)


## Your right hand, or about where it would be.
func _right_hand(player: Node) -> Vector3:
	var near: Vector3 = player.global_position + Vector3.UP * 1.3
	var v: Variant = player.get("visual")
	return v.bone_position("handslot.r", near) if v != null and v.has_method("bone_position") else near


func _update_spear(s: Dictionary, delta: float) -> void:
	var t: CombatTuning = GameData.tuning
	var done: bool = not _alive(s.player) or s.get("done", false)
	if s.held <= 0.0:
		s.left -= delta
	if s.left <= 0.0 and not done:  # time's up, unless one enemy is left: then it's struck until it's dead
		done = Combat.enemies_in_radius(s.at, 10000.0).size() != 1
	if done:
		_spears.erase(s)
		if is_instance_valid(s.node):
			s.node.queue_free()
		return
	if s.held > 0.0:  # in your hand until the throw
		s.held -= delta
		s.at = _right_hand(s.player)
		var aim: Vector3 = (s.goal as Vector3) - (s.at as Vector3)
		if aim.length() > 0.01:
			s.fwd = aim.normalized()
		if s.held <= 0.0:
			Combat.shake(t.shake_heavy)
		_place_spear(s, delta)
		return
	var e: Variant = s.target
	if e != null and (not is_instance_valid(e) or e.is_dead()):  # it died on the way: jump on
		_arrive(s)
		return
	if e != null:
		s.goal = (e as Node3D).global_position + Vector3.UP
	var at: Vector3 = s.at
	var step: Vector3 = (s.goal as Vector3) - at
	if step.length() > 0.01:
		s.fwd = step.normalized()
	s.at = at.move_toward(s.goal, t.kaminari_speed * delta)
	if (s.at as Vector3).distance_to(s.goal) < 0.05:
		_arrive(s)
	_place_spear(s, delta)


## The spear reached its goal: it strikes the enemy there and picks where to go next: the nearest
## other enemy within kaminari_jump_range, else out of the one it struck and back in, else it's done.
func _arrive(s: Dictionary) -> void:
	var t: CombatTuning = GameData.tuning
	var e: Variant = s.target
	s.target = null
	var struck := false
	if e != null and is_instance_valid(e) and not e.is_dead():
		_runner()._strike(s.a, s.player, e, s.at, true)
		s.last = e
		struck = true
	var last: Variant = s.last if s.last != null and is_instance_valid(s.last) and not s.last.is_dead() else null
	var next := Combat.nearest_enemies(s.at, t.kaminari_jump_range, 1, [last] if last != null else [])
	if not next.is_empty():
		s.target = next[0]
		if not _own(s.a) and not ElementFx.bolt_arc(s.at, next[0].global_position + Vector3.UP):
			ElementFx.beam("Lightning", s.at, next[0].global_position + Vector3.UP)
	elif last != null and struck:  # out the far side
		var out := Vector3(randf_range(-1, 1), randf_range(0.3, 1.0), randf_range(-1, 1)).normalized()
		s.goal = (last as Node3D).global_position + Vector3.UP + out * t.kaminari_out_m
	elif last != null:  # and back in
		s.target = last
	else:
		s.done = true


## A new way for the dragon to coil, every kaminari_coil_change s or so: faster or slower, now and
## then the other way round, tighter or looser (kaminari_coil_vary).
func _new_coil(s: Dictionary) -> void:
	var t: CombatTuning = GameData.tuning
	var v := t.kaminari_coil_vary
	s.change = t.kaminari_coil_change * randf_range(0.5, 1.5)
	s.rate_goal = deg_to_rad(t.kaminari_coil_spin) * randf_range(1.0 - v, 1.0 + v) * (-1.0 if randf() < 0.35 else 1.0)
	s.turn_goal = t.kaminari_coil_turn * randf_range(1.0 - v, 1.0 + v)


## The bolt lies along where it flies, its face to the camera, flickering through your bolt pictures;
## the dragon's pieces coil round it.
func _place_spear(s: Dictionary, delta: float) -> void:
	if not is_instance_valid(s.node):
		return
	var t: CombatTuning = GameData.tuning
	var node: Node3D = s.node
	var at: Vector3 = s.at
	var fwd: Vector3 = s.fwd
	node.global_position = at
	if absf(fwd.y) < 0.999:
		node.look_at(at + fwd, Vector3.UP)
	var bolt: MeshInstance3D = s.bolt if is_instance_valid(s.bolt) else null
	if bolt != null:
		var cam := node.get_viewport().get_camera_3d()
		var side := fwd.cross((cam.global_position - at) if cam != null else Vector3.UP).normalized()
		if side.length() < 0.5:
			side = fwd.cross(Vector3.RIGHT).normalized()
		bolt.global_transform = Transform3D(Basis(side, fwd, side.cross(fwd)), at)
		s.frame -= delta
		if s.frame <= 0.0:
			var frames := ElementFx.bolt_frames()
			s.frame = t.kaminari_bolt_frame
			s.fi = (int(s.fi) + 1) % frames.size()
			(bolt.material_override as StandardMaterial3D).albedo_texture = frames[s.fi]
	s.change -= delta
	if s.change <= 0.0:
		_new_coil(s)
	var k := 1.0 - exp(-4.0 * delta)  # eases into the new way
	s.rate = lerpf(s.rate, s.rate_goal, k)
	s.turn = lerpf(s.turn, s.turn_goal, k)
	s.spin += s.rate * delta
	s.wobble += delta * 3.0
	var pieces: Array[Node3D] = s.pieces
	for i in pieces.size():
		var here := _coil(s, i)
		var piece := pieces[i]
		piece.visible = true
		piece.global_position = here
		var ahead := _coil(s, i - 1)
		if (ahead - here).length() > 0.001 and absf((ahead - here).normalized().y) < 0.999:
			piece.look_at(ahead, Vector3.UP)


## Where piece `i` of spear `s`'s dragon coils: from the bolt's tip back, kaminari_dragon_gap further
## each, about kaminari_coil_radius out from it (breathing in and out), s.turn degrees round from the last.
func _coil(s: Dictionary, i: float) -> Vector3:
	var t: CombatTuning = GameData.tuning
	var fwd: Vector3 = s.fwd
	var right := fwd.cross(Vector3.UP)
	right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	var up := right.cross(fwd)
	var turn: float = s.spin - i * deg_to_rad(s.turn)
	var r: float = t.kaminari_coil_radius * (1.0 + t.kaminari_coil_vary * 0.4 * sin(s.wobble + i * 0.5))
	var tip: Vector3 = (s.at as Vector3) + fwd * t.kaminari_bolt_length * 0.5
	return tip - fwd * (i * t.kaminari_dragon_gap) + (right * cos(turn) + up * sin(turn)) * r


func _physics_process(delta: float) -> void:
	for s: Dictionary in _spears.duplicate():
		_update_spear(s, delta)
	for m: Dictionary in _magma_balls.duplicate():
		_update_magma(m, delta)


func caging() -> bool:
	return not _spears.is_empty()


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


# ---------------------------------------------------------------- Freeze: Deep Freeze

func _freeze(a: Dictionary, player: Node) -> void:
	var t: CombatTuning = GameData.tuning
	var center: Vector3 = player.global_position
	var radius := GameData.num(a, "radius_m", 8.0)
	if not _own(a):  # a frost circle spreads from your feet
		UltimateFx.circle("Ice", center + Vector3.UP * 0.06, Vector3.UP, radius, t.deep_freeze_delay + t.deep_freeze_time)
		Vfx.ring(center, radius, ElementFx.color("Ice"), t.deep_freeze_delay)
	_later(t.deep_freeze_delay, _lock.bind(a, player, center, radius))


## Everything inside locks in ice at once; it shatters deep_freeze_time later.
func _lock(a: Dictionary, player: Node, center: Vector3, radius: float) -> void:
	if not _alive(player):
		return
	var t: CombatTuning = GameData.tuning
	var own := _own(a)
	var locked := []
	for e in Combat.enemies_in_radius(center, radius):
		e.freeze(t.deep_freeze_time)
		var block: MeshInstance3D = null
		if not own:
			var box := BoxMesh.new()
			var h: float = e.aim_height() * 2.2
			box.size = Vector3(h * 0.6, h, h * 0.6)
			block = Vfx._spawn(box, Color(ElementFx.color("Ice"), 0.45), e.global_position + Vector3.UP * h * 0.5)
		locked.append([e, block])
	if not own:
		Vfx.burst(center, radius, Color(1, 1, 1, 0.6), 0.15)  # the white flash
	Combat.shake(t.shake_heavy)
	_later(t.deep_freeze_time, _shatter.bind(a, player, center, locked))


func _shatter(a: Dictionary, player: Node, center: Vector3, locked: Array) -> void:
	var t: CombatTuning = GameData.tuning
	for pair in locked:
		var e: Node = pair[0]
		if is_instance_valid(pair[1]):
			pair[1].queue_free()
		if _alive(player) and _alive(e):
			if not _own(a):
				ElementFx.hit("Ice", e.global_position + Vector3.UP, 2.0)
			_runner()._strike(a, player, e, center)
	Combat.shake(t.shake_heavy)
	HitStop.trigger(t.hitstop_heavy)


# ---------------------------------------------------------------- Slab: Stone Slab

func _slab(a: Dictionary, player: Node, dir: Vector3) -> void:
	if not _alive(player):
		return
	var t: CombatTuning = GameData.tuning
	var feet: Vector3 = player.global_position
	var length := GameData.num(a, "range_m", 6.0)
	var half_w := GameData.num(a, "radius_m", 1.5)
	var mid := feet + dir * (length * 0.5 + 0.5)
	if not _own(a):
		var box := BoxMesh.new()
		box.size = Vector3(half_w * 2.0, 3.0, half_w * 2.0)  # a square pillar
		var slab := Vfx._spawn(box, UltimateFx.STONE, mid - Vector3.UP * 1.5)
		if slab != null:
			slab.basis = Basis.looking_at(dir, Vector3.UP)
			var tw := slab.create_tween()
			tw.tween_property(slab, "global_position", mid + Vector3.UP * 1.5, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(t.slab_stay)
			tw.tween_callback(func() -> void:
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
	Combat.shake(t.shake_explosion)
	HitStop.trigger(t.hitstop_light)


# ---------------------------------------------------------------- Crush: Crushing Pillars

func _crush(a: Dictionary, player: Node, dir: Vector3, spot: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	var right := dir.cross(Vector3.UP).normalized()
	var half := t.pillar_gap * 0.5
	if not _own(a):
		for s in [-1.0, 1.0]:
			var at: Vector3 = spot + right * s * half + Vector3.UP * 1.6
			UltimateFx.circle("Stone", at, -right * s, 1.7, t.pillar_delay + t.pillar_time + 0.3)
			var c := CylinderMesh.new()
			c.top_radius = 1.4
			c.bottom_radius = 1.4
			c.height = half
			c.radial_segments = 10
			var pillar := Vfx._spawn(c, UltimateFx.STONE, at + right * s * half * 0.5)
			if pillar == null:
				continue
			pillar.basis = Basis(Quaternion(Vector3.UP, right))
			pillar.scale = Vector3(1, 0.05, 1)  # still inside the circle
			var tw := pillar.create_tween()
			tw.tween_property(pillar, "scale", Vector3.ONE, t.pillar_delay * 0.5).set_delay(t.pillar_delay * 0.5)
			tw.tween_property(pillar, "global_position", spot + right * s * half * 0.5 + Vector3.UP * 1.6, t.pillar_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_interval(0.35)
			tw.tween_callback(_crumble.bind(pillar))
			tw.tween_property(pillar, "scale", Vector3(0.3, 0.3, 0.3), 0.3)
			tw.tween_callback(pillar.queue_free)
	_later(t.pillar_delay + t.pillar_time, _slam.bind(a, player, spot, right, half))


## A pillar breaks into rubble.
func _crumble(pillar: Node3D) -> void:
	for k in 6:
		Vfx.chunk(pillar.global_position + UltimateFx._in_disc(1.0), Vector3(randf_range(-3, 3), randf_range(2, 6), randf_range(-3, 3)), UltimateFx.STONE, 0.4)


## The pillars meet: what's between them takes it all and goes down; the rest at the edges is knocked out.
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
