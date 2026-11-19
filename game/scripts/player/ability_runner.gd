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
##   shape Cone               -> a cone ahead, range_m long and radius_m wide each side at the end
##                               (Movement lunges you forward first, then the Fire Lance's beam:
##                               range_m long, radius_m wide each side, following your aim a moment)
## Abilities count as Magic damage.

signal cooldowns_changed

const LEAP_TIME := 0.45
const LUNGE_TIME := 0.18
const LANCE_FX_LENGTH := 3.5  # meters of visible flame in forge_fire_lance.tscn (models/own/fx/fire/) at scale 1

var defs := {}        # slot -> ability row
var remaining := {}   # slot -> seconds left on cooldown
var invulnerable := false
var _beam := {}  # the Fire Lance's beam while it's on (user, 2026-11-19)


func load_for(god_id: String) -> void:
	defs = GameData.abilities_for(god_id)
	remaining = {"Signature": 0.0, "Movement": 0.0, "Ultimate": 0.0}


func _physics_process(delta: float) -> void:
	for slot in remaining:
		remaining[slot] = maxf(0.0, remaining[slot] - delta)
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


## Returns true if the ability fired. `at`: where an aimed ultimate lands (INF = the old way).
func cast(slot: String, player: Node, dir: Vector3, at := Vector3.INF) -> bool:
	var a: Dictionary = defs.get(slot, {})
	if a.is_empty() or remaining.get(slot, 0.0) > 0.0:
		return false
	# Your own scene for this ability (models/own/fx/<ability_id>.tscn) plays where it's aimed, or on
	# you, turned your way; the code's element particles stay quiet while the ability runs.
	if GameData.text(a, "shape") == "Spikes":
		at = _erupt_spot(player, dir, at, GameData.num(a, "range_m"))
	elif slot != "Ultimate":
		at = Vector3.INF  # the others go off from where you stand
	var id := GameData.text(a, "ability_id")
	var own := ElementFx.own_scene(id) != null
	if own and GameData.text(a, "shape") != "Cone":  # a cone plays yours when it bursts out
		ElementFx.play_own(id, at if at != Vector3.INF else (player as Node3D).global_position, 1.0, dir)
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
		if GameData.text(a, "damage_type") == "Fire" and radius > 0.0:
			_twin_meteors(a, player, spot, radius)
			return true
		var yours := ElementFx.own_scene(GameData.text(a, "ability_id")) != null  # your scene plays the strike
		UltimateFx.play(GameData.text(a, "damage_type", "Physical"), spot, ultimate_radius(), not yours)
		var land := get_tree().create_timer(UltimateFx.impact_time(), false).timeout
		if radius > 0.0:
			land.connect(_blast.bind(a, player, spot, radius))
		else:
			land.connect(_multi_hit.bind(a, player, dir, spot))
		return true
	if GameData.text(a, "shape") == "Spikes":
		_erupt(a, player, at, radius)
	elif GameData.text(a, "shape") == "Cone":
		_lance(a, player, dir, reach, radius)
	elif slot == "Movement" and reach > 0.0:
		_leap(a, player, dir, reach, radius)
	elif reach > 0.0 and radius > 0.0:
		_blast(a, player, player.global_position + dir * reach, radius)
	elif radius > 0.0:
		_blast(a, player, player.global_position, radius)
	else:
		_multi_hit(a, player, dir)
	return true


## The Fire ultimate (user, 2026-11-19): a magic circle opens diagonally above each shoulder, and a
## fast meteor shoots from each toward the aimed spot; each bursts where it lands, side by side.
func _twin_meteors(a: Dictionary, player: Node, spot: Vector3, radius: float) -> void:
	var t: CombatTuning = GameData.tuning
	var from: Vector3 = player.global_position
	var flat := Vector3(spot.x - from.x, 0.0, spot.z - from.z)
	var ahead: Vector3 = flat.normalized() if flat.length() > 0.5 else player.facing
	var right := ahead.cross(Vector3.UP).normalized()
	var each := a.duplicate()
	each["base_damage"] = GameData.num(a, "base_damage") * t.ult_meteor_share
	for s in [-1.0, 1.0]:
		var circle_at: Vector3 = from + Vector3.UP * t.ult_shoulder_height + right * s * t.ult_shoulder_out
		var land: Vector3 = spot + right * s * t.ult_meteor_spread
		var fly := circle_at.distance_to(land) / t.ult_meteor_speed
		UltimateFx.shoulder_meteor(circle_at, land, t.ult_meteor_delay, fly)
		get_tree().create_timer(t.ult_meteor_delay + fly, false).timeout.connect(_meteor_land.bind(each, player, land, radius * t.ult_meteor_radius))

## A meteor hits: its blast, then the ground there burns a while (user, 2026-11-19), setting alight
## whoever stands in it.
func _meteor_land(a: Dictionary, player: Node, land: Vector3, radius: float) -> void:
	_blast(a, player, land, radius)
	if not is_instance_valid(player) or player.is_dead():
		return
	var t: CombatTuning = GameData.tuning
	var tick := 0.5
	var burn := DamageInfo.make(GameData.num(a, "base_damage") * t.ult_fire_ground_damage * tick, "Fire", DamageInfo.Kind.STATUS, player).with_status("fire")
	var r := radius * t.ult_fire_ground_radius
	var h := Hazard.spawn(land, r, t.ult_fire_ground_time, tick, burn, Color(1.0, 0.35, 0.05))
	if h != null:
		var flames := ElementFx.aura("Fire", r)
		if flames != null:
			flames.position = Vector3.UP * 0.4
			h.add_child(flames)
			flames.emitting = true



func _leap(a: Dictionary, player: Node, dir: Vector3, reach: float, radius: float) -> void:
	invulnerable = true
	var start: Vector3 = player.global_position
	var goal := start + dir * reach
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


## Lunge forward (Movement only), then the beam bursts out where you land (a cone, without the lunge).
func _lance(a: Dictionary, player: Node, dir: Vector3, reach: float, half_width: float) -> void:
	dir = Vector3(dir.x, 0.0, dir.z).normalized()
	var lunge: float = GameData.tuning.lance_lunge_m if a.get("slot") == "Movement" else 0.0
	if lunge <= 0.0:
		_cone(a, player, dir, reach, half_width)
		return
	invulnerable = true
	var start: Vector3 = player.global_position
	# Your flame bursts from the weapon's point as you lunge and moves with it (user, 2026-11-08),
	# long and thin like a laser (user, 2026-11-19); it lasts the lunge and the beam.
	var fx := _beam_fx(a, player, dir, reach)
	var tw := create_tween()
	tw.tween_method(_leap_step.bind(player, start, start + dir * lunge, 0.0), 0.0, 1.0, LUNGE_TIME)
	tw.tween_callback(_start_beam.bind(a, player, dir, reach, half_width, fx))


## Your lance scene (models/own/fx/fire/forge_fire_lance.tscn) stretched `reach` long and thin,
## riding the weapon's point; it fades out as the beam ends. Null if you haven't made one.
func _beam_fx(a: Dictionary, player: Node, dir: Vector3, reach: float) -> Node3D:
	var scene := ElementFx.own_scene(GameData.text(a, "ability_id"))
	var root := Vfx._root()
	if scene == null or root == null:
		return null
	var fx: Node3D = scene.instantiate()
	root.add_child(fx)
	fx.global_position = _tip(player, dir)
	fx.look_at(fx.global_position + dir, Vector3.UP)
	var thin: float = GameData.tuning.lance_beam_thickness
	fx.scale = Vector3(thin, thin, reach / LANCE_FX_LENGTH)
	ElementFx._start(fx)
	for ap: AnimationPlayer in fx.find_children("*", "AnimationPlayer", true, false):
		if ap.current_animation != "":  # its fade lands at the beam's end
			ap.speed_scale = ap.current_animation_length / (LUNGE_TIME + GameData.tuning.lance_beam_time)
	_follow_tip(fx, player)
	return fx


## The beam (user, 2026-11-19): for lance_beam_time it points where you aim, up and down too, and
## burns each enemy it touches once.
func _start_beam(a: Dictionary, player: Node, dir: Vector3, reach: float, half_width: float, fx: Node3D) -> void:
	invulnerable = false
	if not is_instance_valid(player) or player.is_dead():
		if fx != null:
			fx.queue_free()
		return
	if fx == null:
		var tip := _tip(player, dir)
		ElementFx.beam(GameData.text(a, "damage_type", "Physical"), tip, tip + dir * reach)
	_beam = {"a": a, "player": player, "reach": reach, "width": maxf(half_width, 0.5), "fx": fx,
		"left": GameData.tuning.lance_beam_time, "hit": {}}
	_update_beam(0.0)
	var t: CombatTuning = GameData.tuning
	Combat.shake(t.shake_explosion)
	HitStop.trigger(t.hitstop_light)


func _update_beam(delta: float) -> void:
	var b := _beam
	var player: Node = b.player
	var fx: Node3D = b.fx if is_instance_valid(b.fx) else null
	b.left -= delta
	if b.left <= 0.0 or not is_instance_valid(player) or player.is_dead():
		if fx != null:
			fx.queue_free()
		_beam = {}
		return
	var from := _tip(player, player.facing)
	var dir: Vector3 = player.aim_direction(from)
	if fx != null and absf(dir.y) < 0.99:
		fx.look_at(fx.global_position + dir, Vector3.UP)
	var reach: float = b.reach
	var to := from + dir * reach
	for e in Combat.enemies_in_radius(from, reach + 1.0):
		if b.hit.has(e):
			continue
		var feet: Vector3 = e.global_position
		var near := Geometry3D.get_closest_points_between_segments(from, to, feet, feet + Vector3.UP * e.aim_height() * 2.0)
		if near[0].distance_to(near[1]) <= b.width:  # anywhere on the body, feet to head
			b.hit[e] = true
			_strike(b.a, player, e, from)
	Breakable.smash_line(get_tree(), from, dir, reach, b.width * 0.6)


func beaming() -> bool:
	return not _beam.is_empty()


## The weapon's point now: its tip if the model has one, else about where it would be.
func _tip(player: Node, dir: Vector3) -> Vector3:
	var tip: Node3D = player.visual.weapon_tip() if player.get("visual") != null else null
	return tip.global_position if tip != null else player.global_position + Vector3.UP * 1.2 + dir * 0.6


## Keeps `fx` on the weapon's point (its place only: it keeps pointing where you lunge).
func _follow_tip(fx: Node3D, player: Node) -> void:
	var tip: Node3D = player.visual.weapon_tip() if player.get("visual") != null else null
	if tip == null:
		return
	var follow := RemoteTransform3D.new()
	follow.update_rotation = false
	follow.update_scale = false
	tip.add_child(follow)
	follow.remote_path = follow.get_path_to(fx)
	fx.tree_exiting.connect(follow.queue_free)


func _cone(a: Dictionary, player: Node, dir: Vector3, reach: float, half_width: float, flame_shown := false) -> void:
	invulnerable = false
	if not is_instance_valid(player) or player.is_dead():
		return
	var from: Vector3 = player.global_position
	var tip := _tip(player, dir)
	if not flame_shown and ElementFx.play_own(GameData.text(a, "ability_id"), tip, reach / LANCE_FX_LENGTH, dir) == null:
		ElementFx.beam(GameData.text(a, "damage_type", "Physical"), tip, tip + dir * reach)
	var cos_max := cos(atan2(maxf(half_width, 0.5), reach))
	Breakable.smash_line(get_tree(), from, dir, reach, maxf(half_width, 0.5) * 0.6)
	for e in Combat.enemies_in_radius(from, reach):
		var to: Vector3 = e.global_position - from
		to.y = 0.0
		if to.length() < 1.0 or to.normalized().dot(dir) >= cos_max:  # point-blank always counts
			_strike(a, player, e, from)
	var t: CombatTuning = GameData.tuning
	Combat.shake(t.shake_explosion)
	HitStop.trigger(t.hitstop_light)


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
