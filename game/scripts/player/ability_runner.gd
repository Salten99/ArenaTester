class_name AbilityRunner
extends Node
## Runs the pledged god's 3 abilities (Signature, Movement, Ultimate) from the
## God Abilities sheet. One generic executor reads the columns:
##   radius_m only            -> blast around the player
##   range_m and radius_m     -> blast at a point ahead
##   slot Ultimate            -> a magic circle over the aimed spot calls the element down (UltimateFx);
##                               the blast (or the hits, without a radius) lands at UltimateFx.impact_time()
##   range_m, slot Movement   -> leap forward, blast on landing
##   hits_or_projectiles > 1  -> repeated hits on the nearest enemy (radius 0)
##   shape Cone               -> the Fire Lance: lunge forward (lance_lunge_m), then a beam
##                               range_m long, radius_m wide each side, following your aim a moment
##   shape Beam               -> the Lightning beam: the same beam without the lunge, lightning_beam_time long
##   shape Rings, Strike, Fan, Cage, Slide, Freeze, Slab, Crush, Magma -> the arena's spells (spells.gd)
## Abilities count as Magic damage.

signal cooldowns_changed

const LEAP_TIME := 0.45
const LUNGE_TIME := 0.18
const LANCE_FX_LENGTH := 3.5  # meters of visible flame in forge_fire_lance.tscn (models/own/fx/fire/) at scale 1
const LANCE_FX_WIDTH := 1.78  # meters across it at scale 1 (its 31 px tall frames x 0.0575 m a pixel)

var defs := {}        # slot -> ability row
var remaining := {}   # slot -> seconds left on cooldown
var invulnerable := false
var _beam := {}  # the Fire Lance's (or Lightning beam's) beam while it's on (user, 2026-11-19)
var hover_y := 0.0  # the Fire ultimate's lift: the height you hang at, for _hover_left s more
var _hover_left := 0.0
var spells := Spells.new()  # the shapes that aren't a plain blast (spells.gd)


func _ready() -> void:
	add_child(spells)


func load_for(god_id: String) -> void:
	defs = GameData.abilities_for(god_id)
	remaining = {"Signature": 0.0, "Movement": 0.0, "Ultimate": 0.0}


func _physics_process(delta: float) -> void:
	for slot in remaining:
		remaining[slot] = maxf(0.0, remaining[slot] - delta)
	_hover_left = maxf(0.0, _hover_left - delta)
	if not _beam.is_empty():
		_update_beam(delta)


func ready_in(slot: String) -> float:
	return remaining.get(slot, 0.0)


func cooldown_of(slot: String, player: Node) -> float:
	var cd := GameData.num(defs.get(slot, {}), "cooldown_s", 10.0)
	cd *= maxf(0.2, 1.0 - player.stats.get_stat("cdr_pct") / 100.0)
	if slot == "Ultimate":
		cd *= maxf(0.2, 1.0 - player.stats.get_stat("ultimate_cdr_pct") / 100.0)
	return cd


## How far an ultimate can be aimed.
func aim_range() -> float:
	return maxf(GameData.tuning.ultimate_aim_range, GameData.num(defs.get("Ultimate", {}), "range_m"))


## The ultimate's blast radius (for the aiming ring); 3 m for single-target ones.
func ultimate_radius() -> float:
	var r := GameData.num(defs.get("Ultimate", {}), "radius_m")
	return r if r > 0.0 else 3.0


## How far from you a spell can be aimed (user, 2026-11-20: every spell is aimed): 0 for one that
## goes off around you.
func aim_reach(slot: String) -> float:
	var a: Dictionary = defs.get(slot, {})
	if GameData.text(a, "shape") in ["Rings", "Freeze"]:
		return 0.0
	return aim_range() if slot == "Ultimate" else GameData.num(a, "range_m")


## How wide the aiming circle on the ground is.
func aim_radius(slot: String) -> float:
	if slot == "Ultimate":
		return ultimate_radius()
	var r := GameData.num(defs.get(slot, {}), "radius_m")
	return r if r > 0.0 else 1.0


## Returns true if the ability fired. `at`: where it was aimed on the ground (INF = straight ahead).
func cast(slot: String, player: Node, dir: Vector3, at := Vector3.INF) -> bool:
	var a: Dictionary = defs.get(slot, {})
	if a.is_empty() or remaining.get(slot, 0.0) > 0.0:
		return false
	# Your own scene for this ability (models/own/fx/<ability_id>.tscn) plays where it's aimed, or on
	# you, turned your way; the code's element particles stay quiet while the ability runs.
	if GameData.text(a, "shape") == "Spikes":
		at = _erupt_spot(player, dir, at, GameData.num(a, "range_m"))
	var id := GameData.text(a, "ability_id")
	var own := ElementFx.own_scene(id) != null
	if own and GameData.text(a, "shape") != "Cone":  # a cone plays yours when it bursts out
		var lands := slot == "Ultimate" or GameData.text(a, "shape") == "Spikes"  # the others play on you
		ElementFx.play_own(id, at if at != Vector3.INF and lands else (player as Node3D).global_position, 1.0, dir)
	ElementFx.quiet = own
	var cast_ok := _cast_now(slot, a, player, dir, at)
	ElementFx.quiet = false
	return cast_ok


func _cast_now(slot: String, a: Dictionary, player: Node, dir: Vector3, at: Vector3) -> bool:
	remaining[slot] = cooldown_of(slot, player)
	cooldowns_changed.emit()
	var radius := GameData.num(a, "radius_m")
	var reach := GameData.num(a, "range_m")
	if slot == "Ultimate":
		var spot: Vector3 = at
		if spot == Vector3.INF:  # not aimed: ahead (ranged ones) or where you stand
			spot = player.global_position + dir * reach if reach > 0.0 and radius > 0.0 else player.global_position
		if spells.cast(a, player, dir, spot):
			return true
		if GameData.text(a, "damage_type") == "Fire" and radius > 0.0:
			_fire_ultimate(a, player, spot, radius)
			return true
		var yours := ElementFx.own_scene(GameData.text(a, "ability_id")) != null  # your scene plays the strike
		UltimateFx.play(GameData.text(a, "damage_type", "Physical"), spot, ultimate_radius(), not yours)
		var land := get_tree().create_timer(UltimateFx.impact_time(), false).timeout
		if radius > 0.0:
			land.connect(_blast.bind(a, player, spot, radius))
		else:
			land.connect(_multi_hit.bind(a, player, dir, spot))
		return true
	if spells.cast(a, player, dir, at):
		return true
	if GameData.text(a, "shape") == "Spikes":
		_erupt(a, player, at, radius)
	elif GameData.text(a, "shape") in ["Cone", "Beam"]:
		_lance(a, player, dir, reach, radius)
	elif slot == "Movement" and reach > 0.0:
		_leap(a, player, dir, reach, radius, at)
	elif reach > 0.0 and radius > 0.0:
		_blast(a, player, at if at != Vector3.INF else player.global_position + dir * reach, radius)
	elif radius > 0.0:
		_blast(a, player, player.global_position, radius)
	else:
		_multi_hit(a, player, dir)
	return true


## The Fire ultimate (user, 2026-11-20): five magic circles open in an arc over your head, facing
## where you aimed; a flame dragon pours out of the middle one, snakes out and up, and dives into
## the aimed spot: the blast, and the ground there burns.
func _fire_ultimate(a: Dictionary, player: Node, spot: Vector3, radius: float) -> void:
	var t: CombatTuning = GameData.tuning
	var from: Vector3 = player.global_position
	var flat := Vector3(spot.x - from.x, 0.0, spot.z - from.z)
	var ahead: Vector3 = flat.normalized() if flat.length() > 0.5 else player.facing
	var right := ahead.cross(Vector3.UP).normalized()
	# You rise ult_lift_height off the ground (user, 2026-11-20) and hang there until the dragons land;
	# the arc opens over where your head will be.
	hover_y = from.y + t.ult_lift_height
	_hover_left = t.ult_lift_time + t.ult_dragon_delay + t.ult_dragon_time + 0.3
	var top := _brow(player, Vector3.ZERO) + Vector3.UP * (t.ult_arc_height + t.ult_lift_height)  # the arc's middle
	var lasts := t.ult_dragon_delay + t.ult_dragon_time * 1.6
	var root: Node = Vfx._root()
	if root == null:  # no effects layer: the dive still has to land
		root = self
	for i in 5:  # 20..160 degrees round, like a rainbow over you
		var ang := deg_to_rad(lerpf(20.0, 160.0, i / 4.0))
		var out := right * cos(ang) + Vector3.UP * sin(ang)  # from the arc's center out to this circle
		var at := top + (out - Vector3.UP) * t.ult_arc_radius
		get_tree().create_timer(t.ult_arc_gap * absf(i - 2), false).timeout.connect(  # from the middle outward
			func(): UltimateFx.circle("Fire", at, ahead, t.ult_arc_circle_size * (1.3 if i == 2 else 1.0), lasts))
		# A dragon out of each circle (user, 2026-11-20): they fan out, then all dive into the one spot.
		# The middle one deals the blast; the others land with it. Each takes its own random way there
		# (user, 2026-11-20): only the two middle points of its curve move, so the start and end stay.
		var w := t.ult_dragon_wander
		var d := FireDragon.new()
		d.p0 = at
		d.p1 = at + ahead * flat.length() * 0.2 + Vector3.UP * 5.0 + out * 4.0 + _wander(w)
		d.p2 = spot + Vector3.UP * 9.0 - ahead * 2.0 + out * 3.0 + _wander(w)
		d.p3 = spot
		d.side = right if randf() < 0.5 else -right  # weaves left first or right first
		d.phase = randf() * TAU
		d.time = -t.ult_dragon_delay  # all together, so they land as one
		d.landed.connect(_dragon_lands.bind(a, player, spot, radius, i == 2))
		root.add_child(d)
	Combat.shake(t.shake_light)


## A random push up to `w` m, less downward so the path stays in the air.
func _wander(w: float) -> Vector3:
	return Vector3(randf_range(-w, w), randf_range(-w * 0.4, w), randf_range(-w, w))


## While the Fire ultimate holds you up: the Player hangs at hover_y.
func levitating() -> bool:
	return _hover_left > 0.0


## The dive hits the ground: the ultimate's blast, cracks, and the ground there burns.
func _dragon_lands(a: Dictionary, player: Node, spot: Vector3, radius: float, main: bool) -> void:
	if not is_instance_valid(player) or player.is_dead():
		return
	var t: CombatTuning = GameData.tuning
	if not main:  # the others' landing is the look; the middle one deals the blast
		Vfx.burst(spot + UltimateFx._in_disc(radius * 0.4), radius * 0.6, Color(1.0, 0.6, 0.15, 0.8), 0.2)
		return
	_blast(a, player, spot, radius)
	ElementFx.area("Fire", spot, radius * 1.2)
	Vfx.burst(spot, radius, Color(1.0, 0.7, 0.2, 0.8), 0.2)
	UltimateFx._cracks(spot, Vector3.UP, radius)
	_burn_ground(a, player, spot, radius * t.ult_fire_ground_radius)
	for k in 8:
		Vfx.chunk(spot + UltimateFx._in_disc(radius * 0.5), Vector3(randf_range(-5, 5), randf_range(5, 10), randf_range(-5, 5)), Color(1.0, 0.4, 0.05), 0.35)


## The ground at `land` burns a while (user, 2026-11-19), setting alight whoever stands in it.
func _burn_ground(a: Dictionary, player: Node, land: Vector3, r: float) -> void:
	var t: CombatTuning = GameData.tuning
	var tick := 0.5
	var burn := DamageInfo.make(GameData.num(a, "base_damage") * t.ult_fire_ground_damage * tick, "Fire", DamageInfo.Kind.STATUS, player).with_status("fire")
	var h := Hazard.spawn(land, r, t.ult_fire_ground_time, tick, burn, Color(1.0, 0.35, 0.05))
	if h != null:
		var flames := ElementFx.aura("Fire", r)
		if flames != null:
			flames.position = Vector3.UP * 0.4
			h.add_child(flames)
			flames.emitting = true

func _leap(a: Dictionary, player: Node, dir: Vector3, reach: float, radius: float, at := Vector3.INF) -> void:
	invulnerable = true
	var start: Vector3 = player.global_position
	var goal := at if at != Vector3.INF else start + dir * reach  # where you aimed it
	var tw := create_tween()
	tw.tween_method(_leap_step.bind(player, start, goal), 0.0, 1.0, LEAP_TIME)
	tw.tween_callback(_land.bind(a, player, radius))


func _leap_step(f: float, player: Node, start: Vector3, goal: Vector3, height := 2.0) -> void:
	if is_instance_valid(player):
		var p := start.lerp(goal, f)
		var ground: float = player.floor_below(p.x, p.z, maxf(start.y, goal.y) + height + 4.0)  # just over the arc: in a cave, not the ceiling (playtest 2026-11-08)
		var base := start.y if ground == -INF else lerpf(start.y, maxf(ground, start.y - 30.0), f)
		p.y = maxf(base, ground) + sin(f * PI) * height  # arc over the ground, never into it
		player.global_position = p


func _land(a: Dictionary, player: Node, radius: float) -> void:
	invulnerable = false
	if is_instance_valid(player) and radius > 0.0:
		_blast(a, player, player.global_position, radius)


func _blast(a: Dictionary, player: Node, center: Vector3, radius: float) -> void:
	ElementFx.quiet = ElementFx.own_scene(GameData.text(a, "ability_id")) != null  # a delayed ultimate: still yours
	_blast_now(a, player, center, radius)
	ElementFx.quiet = false


func _blast_now(a: Dictionary, player: Node, center: Vector3, radius: float) -> void:
	if not is_instance_valid(player) or player.is_dead():
		return
	var t: CombatTuning = GameData.tuning
	var element := GameData.text(a, "damage_type", "Physical")
	ElementFx.area(element, center, radius)
	Breakable.smash_near(get_tree(), center, radius, center)
	for e in Combat.enemies_in_radius(center, radius):
		_strike(a, player, e, center, true)
	Combat.shake(t.shake_heavy if a.get("slot") == "Ultimate" else t.shake_explosion)
	HitStop.trigger(t.hitstop_heavy if a.get("slot") == "Ultimate" else t.hitstop_light)


## Hits one enemy with the ability, pushing it away from `center`.
func _strike(a: Dictionary, player: Node, e: Node, center: Vector3, explosive := false) -> void:
	var t: CombatTuning = GameData.tuning
	var info: DamageInfo = player.make_hit(GameData.num(a, "base_damage"), GameData.text(a, "damage_type", "Physical"), "Magic", e, DamageInfo.Kind.ABILITY)
	var away: Vector3 = e.global_position - center
	away.y = 0.0
	info.knockback_dir = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
	info.knockback = t.knockback_explosion
	info.explosive = explosive
	info.knockdown = a.get("slot") == "Ultimate"
	_add_status(a, player, info)
	Combat.deal(e, info)


## Lunge forward (a Fire Lance in the Movement slot), then the beam bursts out where you land. A
## Beam (the Lightning beam, user 2026-11-20) doesn't lunge: it fires from the circle for lightning_beam_time.
func _lance(a: Dictionary, player: Node, dir: Vector3, reach: float, half_width: float) -> void:
	dir = Vector3(dir.x, 0.0, dir.z).normalized()
	var lance := GameData.text(a, "shape") == "Cone"
	var airborne: bool = player is CharacterBody3D and not player.is_on_floor()
	var lunge: float = GameData.tuning.lance_lunge_m if a.get("slot") == "Movement" and lance and not airborne else 0.0
	invulnerable = lunge > 0.0
	var start: Vector3 = player.global_position
	# A magic circle opens before you as you lunge (user, 2026-11-19): the Fire Lance's in front of
	# your chest (2026-11-20), the Lightning beam's before your forehead. The beam fires out of it.
	var t: CombatTuning = GameData.tuning
	var time := t.lance_beam_time if lance else t.lightning_beam_time
	_beam = {"a": a, "player": player, "reach": reach, "width": maxf(half_width, 0.5), "circle": null, "lance": lance,
		"fx": null, "on": false, "left": time, "hit": {}, "spin": 0.0, "flicker": 0.0, "flies": airborne and lance, "push": Vector3.ZERO}
	_beam.circle = UltimateFx.circle(GameData.text(a, "damage_type", "Fire"), _beam_from(_beam, player, dir), dir,
		t.lance_circle_diameter * 0.5, LUNGE_TIME + time)
	if lance and _beam.circle != null:  # darker red (user, 2026-11-20)
		for m: MeshInstance3D in _beam.circle.find_children("*", "MeshInstance3D", false, false):
			(m.material_override as StandardMaterial3D).albedo_color = Color(t.lance_tint, 1.0)
	var tw := create_tween()
	if lunge > 0.0:  # (a lunge holds you to the ground: not in the air)
		tw.tween_method(_leap_step.bind(player, start, start + dir * lunge, 0.0), 0.0, 1.0, LUNGE_TIME)
	else:
		tw.tween_interval(LUNGE_TIME)
	tw.tween_callback(_start_beam)


## Where beam `b` fires from: the Fire Lance's circle lance_chest_ahead in front of your chest, the
## Lightning beam's before your forehead.
func _beam_from(b: Dictionary, player: Node, dir: Vector3) -> Vector3:
	if not b.lance:
		return _brow(player, dir)
	return (player.global_position as Vector3) + Vector3.UP * 1.25 + dir * GameData.tuning.lance_chest_ahead


## Where beam `b` points: at the crosshair; in the air, straight where you look, down too (so a lance
## at the ground carries you).
func _beam_dir(b: Dictionary, player: Node) -> Vector3:
	if b.flies and player.has_method("look_direction"):
		return player.look_direction()
	return player.aim_direction(_beam_from(b, player, player.facing))


## While a Fire Lance fired in the air points down: the push carrying you (Player._move), else ZERO.
func lance_push() -> Vector3:
	return _beam.get("push", Vector3.ZERO) if not _beam.is_empty() else Vector3.ZERO


## In front of your forehead, `dir` (where you aim) ahead of it.
func _brow(player: Node, dir: Vector3) -> Vector3:
	var p: Vector3 = player.global_position
	var head: Vector3 = player.visual.head_position(p + Vector3.UP * 1.6) \
		if player.get("visual") != null and player.visual.has_method("head_position") else p + Vector3.UP * 1.6
	return head + Vector3.UP * 0.1 + dir * GameData.tuning.lance_circle_ahead


## The beam (user, 2026-11-19): for lance_beam_time it fires from the circle where you aim, up and
## down too, and burns each enemy it touches once. Your lance scene
## (models/own/fx/fire/forge_fire_lance.tscn) is stretched to range_m long and radius_m * 2 across.
func _start_beam() -> void:
	invulnerable = false
	if _beam.is_empty() or not is_instance_valid(_beam.player):
		return
	var t: CombatTuning = GameData.tuning
	var b := _beam
	b.on = true
	var player: Node = b.player
	var dir: Vector3 = player.facing
	if b.lance:  # the Lightning beam is drawn fresh each moment (_update_beam)
		b.fx = _lance_fx(GameData.text(b.a, "ability_id"), _beam_from(b, player, dir), dir, b.reach, b.width, t.lance_beam_time, t.lance_tint)
	_update_beam(0.0)
	Combat.shake(t.shake_explosion)
	HitStop.trigger(t.hitstop_light)


## Keeps the circle (and the beam, once it's on) in front of your forehead, pointing where you aim.
func _update_beam(delta: float) -> void:
	var b := _beam
	var player: Node = b.player
	var fx: Node3D = b.fx if is_instance_valid(b.fx) else null
	var circle: Node3D = b.circle if is_instance_valid(b.circle) else null
	if b.on:
		b.left -= delta
		b.spin += deg_to_rad(GameData.tuning.lance_circle_beam_spin) * delta  # it whirls while firing
	if b.left <= 0.0 or not is_instance_valid(player) or player.is_dead():
		for n in [fx, circle]:
			if n != null:
				n.queue_free()
		_beam = {}
		return
	var dir := _beam_dir(b, player)
	var from := _beam_from(b, player, dir)
	# Fired in the air and pointing down at the ground (user, 2026-11-20): it carries you, away from where it points.
	b.push = -dir * GameData.tuning.lance_fly_speed if b.on and b.flies and dir.y < -0.3 else Vector3.ZERO
	if circle != null:
		circle.global_position = from
		circle.quaternion = Quaternion(Vector3.UP, dir) * Quaternion(Vector3.UP, b.spin)
	if not b.on:
		return
	if fx != null:
		fx.global_position = from
		fx.look_at(from + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	elif fx == null and GameData.text(b.a, "shape") == "Beam":
		b.flicker -= delta
		if b.flicker <= 0.0:  # a crackling bolt redrawn every moment, round a white-hot core
			b.flicker = 0.04
			var to: Vector3 = from + dir * b.reach
			ElementFx.beam(GameData.text(b.a, "damage_type", "Lightning"), from, to)
			Vfx.bolt(from, to, Color(1, 1, 1, 0.9), 0.06)
	_beam_hits(b.a, player, b.hit, from, dir, b.reach, b.width)


## Your lance scene (models/own/fx/fire/forge_fire_lance.tscn for `id`) at `from` pointing `dir`,
## stretched to `reach` long and `half_width` * 2 across, its fade landing `time` s later; without
## the scene, the code's beam. Returns the scene (null without).
func _lance_fx(id: String, from: Vector3, dir: Vector3, reach: float, half_width: float, time: float, tint := Color.WHITE) -> Node3D:
	var scene := ElementFx.own_scene(id)
	var root := Vfx._root()
	if scene == null or root == null:
		ElementFx.beam("Fire", from, from + dir * reach)
		return null
	var fx: Node3D = scene.instantiate()
	if tint != Color.WHITE:
		_tint(fx, tint)
	root.add_child(fx)
	var across: float = half_width * 2.0 / LANCE_FX_WIDTH
	fx.scale = Vector3(across, across, reach / LANCE_FX_LENGTH)
	ElementFx._start(fx)
	for ap: AnimationPlayer in fx.find_children("*", "AnimationPlayer", true, false):
		if ap.current_animation != "":  # its fade lands at the beam's end
			ap.speed_scale = ap.current_animation_length / time
	fx.global_position = from
	fx.look_at(from + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)  # straight down: the boot jets
	return fx


## Tints a scene: its sprites, and the colors its animations give them (they'd undo a plain tint).
## Each copy gets its own animations, so the scene itself is left as it was.
static func _tint(fx: Node, tint: Color) -> void:
	for ap: AnimationPlayer in fx.find_children("*", "AnimationPlayer", true, false):
		for lib_name in ap.get_animation_library_list():
			var lib: AnimationLibrary = ap.get_animation_library(lib_name).duplicate(true)
			for anim_name in lib.get_animation_list():
				var anim := lib.get_animation(anim_name)
				for ti in anim.get_track_count():
					if String(anim.track_get_path(ti)).ends_with(":modulate"):
						for k in anim.track_get_key_count(ti):
							var c: Color = anim.track_get_key_value(ti, k)
							anim.track_set_key_value(ti, k, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
			ap.remove_animation_library(lib_name)
			ap.add_animation_library(lib_name, lib)
	for s: SpriteBase3D in fx.find_children("*", "SpriteBase3D", true, false):
		s.modulate = Color(s.modulate.r * tint.r, s.modulate.g * tint.g, s.modulate.b * tint.b, s.modulate.a)


## A beam from `from` along `dir`: strikes each enemy it touches (anywhere feet to head) that isn't
## in `hit` yet, and smashes props on its line.
func _beam_hits(a: Dictionary, player: Node, hit: Dictionary, from: Vector3, dir: Vector3, reach: float, width: float) -> void:
	var to := from + dir * reach
	for e in Combat.enemies_in_radius(from, reach + width + 1.0):
		if hit.has(e):
			continue
		var feet: Vector3 = e.global_position
		var near := Geometry3D.get_closest_points_between_segments(from, to, feet, feet + Vector3.UP * e.aim_height() * 2.0)
		if near[0].distance_to(near[1]) <= width:
			hit[e] = true
			_strike(a, player, e, from)
	Breakable.smash_line(get_tree(), from, dir, reach, width * 0.6)


func beaming() -> bool:
	return not _beam.is_empty()


## Where the Spikes open: the aimed ground point, at most `reach` away (ahead of you, unaimed).
func _erupt_spot(player: Node, dir: Vector3, at: Vector3, reach: float) -> Vector3:
	var from: Vector3 = player.global_position
	var flat: Vector3 = (at if at != Vector3.INF else from + dir * reach) - from
	flat.y = 0.0
	var p: Vector3 = from + flat.limit_length(reach)
	var ground: float = player.floor_below(p.x, p.z, from.y + 30.0)
	p.y = ground if ground != -INF else from.y
	return p


## The Stone special (user, 2026-11-16): a magic circle opens on the ground at `spot`, then stone
## spikes erupt from it. The ones they kill stay impaled up on a spike; the rest are hurled outward.
func _erupt(a: Dictionary, player: Node, spot: Vector3, radius: float) -> void:
	var t: CombatTuning = GameData.tuning
	var element := GameData.text(a, "damage_type", "Physical")
	var root := Vfx._root()
	if root != null:
		UltimateFx.circle(element, spot + Vector3.UP * 0.06, UltimateFx._ground_up(root, spot), radius, t.erupt_delay + 0.5)
	get_tree().create_timer(t.erupt_delay, false).timeout.connect(_erupt_now.bind(a, player, spot, radius))


func _erupt_now(a: Dictionary, player: Node, spot: Vector3, radius: float) -> void:
	if not is_instance_valid(player) or player.is_dead():
		return
	var t: CombatTuning = GameData.tuning
	var caught := Combat.enemies_in_radius(spot, radius)
	_blast(a, player, spot, radius)  # the damage, and the push outward from the middle
	var impaled := []  # [ground point, spike height, seconds it stays]
	for e in caught:
		if is_instance_valid(e) and e.is_dead():
			var h: float = t.erupt_spike_height * e.size_scale
			var ground := Vector3(e.global_position.x, spot.y, e.global_position.z)
			e.impale(ground + Vector3.UP * h)
			impaled.append([ground, h, Enemy.RAGDOLL_SECONDS + 0.9])
	UltimateFx.erupt(spot, radius, impaled)


func _multi_hit(a: Dictionary, player: Node, dir: Vector3, at := Vector3.INF) -> void:
	if not is_instance_valid(player) or player.is_dead():
		return
	var hits := maxi(1, int(GameData.num(a, "hits_or_projectiles", 1)))
	var element := GameData.text(a, "damage_type", "Physical")
	var reach := maxf(3.0, GameData.num(a, "range_m", 6.0))
	var center: Vector3 = at if at != Vector3.INF else player.global_position + dir * reach * 0.5
	var targets := Combat.nearest_enemies(center, ultimate_radius() if at != Vector3.INF else reach, hits)
	var from: Vector3 = player.global_position + Vector3.UP if at == Vector3.INF else at + Vector3.UP * GameData.tuning.ult_circle_height  # an ultimate's hits come from its circle
	for i in hits:
		if targets.is_empty():
			return
		var e: Node = targets[i % targets.size()]
		var info: DamageInfo = player.make_hit(GameData.num(a, "base_damage"), element, "Magic", e, DamageInfo.Kind.ABILITY)
		_add_status(a, player, info)
		ElementFx.beam(element, from, e.global_position + Vector3.UP)
		Combat.deal(e, info)


func _add_status(a: Dictionary, player: Node, info: DamageInfo) -> void:
	var status := GameData.text(a, "status_effect")
	if status != "" and RunRng.chance(GameData.num(a, "status_chance_pct", 100.0)):
		info.with_status(status)
	if a.get("slot") == "Ultimate":
		var extra: String = player.godly_gifts.ultimate_status()
		if extra != "" and extra != status:
			info.with_status(extra)
