class_name Spells
extends Node
## The arena's spells that aren't a plain blast (Arena Magic Attacks sheet, user 2026-11-20). A child
## of the AbilityRunner; the God Abilities `shape` column picks one:
##   Rings   rings roll out from you to radius_m; the nearer, the harder (Lava Ripple, Ring of Ice)
##   Strike  one big bolt on the spot range_m ahead, throwing what's near (Thunder Crash)
##   Fan     hits_or_projectiles bolts fan across fan_arc_deg in front, range_m long (Bolt Fan)
##   Cage    pillar bolts round the aimed spot and bolts bouncing between them (Kaminari)
##   Slide   slide range_m on a trail of ice that slows (Ice Slide)
##   Freeze  everything within radius_m locks in ice, then shatters (Deep Freeze)
##   Slab    a square stone pillar shoots up ahead, launches what's on it, then bursts into dust (Stone Slab)
##   Crush   two stone pillars slam together on the aimed spot (Crushing Pillars)
##   Magma   reach into the ground, pull out a magma ball and hurl it at the aimed spot (Magma Ball)
## The looks are built in code; your models/own/fx/<ability_id>.tscn plays instead once you make it.
## The numbers are in combat_tuning.tres, group Spells.

var _cages := []  # Kaminari cages while they're on


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


# ---------------------------------------------------------------- Cage: Kaminari

func _cage(a: Dictionary, player: Node, spot: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	var radius := GameData.num(a, "radius_m", 6.0)
	var own := _own(a)
	var pillars := []
	var glows := []
	for i in t.cage_pillars:
		var p := spot + UltimateFx._around(i, t.cage_pillars, radius)
		pillars.append(p)
		if not own:
			var col := CylinderMesh.new()
			col.top_radius = 0.18
			col.bottom_radius = 0.18
			col.height = 14.0
			col.radial_segments = 6
			var glow := Vfx._spawn(col, Color(ElementFx.color("Lightning"), 0.75), p + Vector3.UP * 7.0)
			if glow != null:
				glows.append(glow)
			if not ElementFx.bolt_arc(p + Vector3.UP * 18.0, p):
				ElementFx.beam("Lightning", p + Vector3.UP * 18.0, p)
	if not own:
		UltimateFx.circle("Lightning", spot + Vector3.UP * 0.06, Vector3.UP, radius, t.cage_time)
	# Who stands inside when it's cast is caught (user, 2026-11-20): held in the circle and struck
	# again and again until it ends.
	var c := {"a": a, "player": player, "spot": spot, "radius": radius, "pillars": pillars, "glows": glows,
		"left": t.cage_time, "flicker": 0.0, "bolts": [], "struck": {}, "own": own, "trapped": Combat.enemies_in_radius(spot, radius)}
	# Your bolt, thrown from your hand to the first pillar, and one already bouncing off every pillar:
	# it's at full tilt from the start (user, 2026-11-20).
	var hand: Vector3 = player.global_position + Vector3.UP * 1.3 if _alive(player) else pillars[0]
	_add_bolt(c, hand, 0, t.cage_bolt_speed)
	for i in pillars.size() * 2:  # two off every pillar (user, 2026-11-20: twice the bolts)
		var from: int = i % pillars.size()
		_add_bolt(c, pillars[from] + Vector3.UP * 1.2, _other_pillar(c, from), t.cage_bolt_speed)
	_cages.append(c)
	Combat.shake(t.shake_heavy)
	if _alive(player):  # you float cage_lift_height up while it lasts
		var r := _runner()
		r.hover_y = player.global_position.y + t.cage_lift_height
		r._hover_left = t.cage_time


## A bolt flying from `from` to pillar `to` at `speed`.
func _add_bolt(c: Dictionary, from: Vector3, to: int, speed: float) -> void:
	var orb: MeshInstance3D = null
	if not c.own:
		orb = Vfx._spawn(UltimateFx._sphere(0.35), Color(1, 1, 1, 0.9), from)
	c.bolts.append({"from": from, "to": to, "f": 0.0, "speed": speed, "orb": orb})


## A pillar other than `i`, picked at random.
func _other_pillar(c: Dictionary, i: int) -> int:
	var n: int = c.pillars.size()
	return (i + randi_range(1, n - 1)) % n


func _physics_process(delta: float) -> void:
	for c: Dictionary in _cages.duplicate():
		_update_cage(c, delta)
	for m: Dictionary in _magma_balls.duplicate():
		_update_magma(m, delta)


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
		if is_instance_valid(b.orb):
			b.orb.global_position = at
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
		if is_instance_valid(b.orb):
			b.orb.queue_free()
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
