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
##   shape Rings, Strike, Fan, Cage, Slide, Freeze, Slab, Crush -> the arena's spells (spells.gd)
## Abilities count as Magic damage.

signal cooldowns_changed

const LEAP_TIME := 0.45
const LUNGE_TIME := 0.18
const LANCE_FX_LENGTH := 3.5  # meters of visible flame in forge_fire_lance.tscn (models/own/fx/fire/) at scale 1
const LANCE_FX_WIDTH := 1.78  # meters across it at scale 1 (its 31 px tall frames x 0.0575 m a pixel)

var defs := {}        # slot -> ability row
var remaining := {}   # slot -> seconds left on cooldown
var invulnerable := false
var _beam := {}  # the Fire Lance's beam while it's on (user, 2026-11-19)
var hover_y := 0.0  # the Fire ultimate's lift: the height you hang at, for this many seconds more
var _hover_left := 0.0
var _ult_beams := []  # the Fire ultimate's three beams while they're on
var _jets := []  # its boot jets while you hang in the air
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
	if _hover_left <= 0.0 and not _jets.is_empty():
		for j in _jets:
			if is_instance_valid(j):
				j.queue_free()
		_jets.clear()
	if not _beam.is_empty():
		_update_beam(delta)
	if not _ult_beams.is_empty():
		_update_ult_beams(delta)


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


## The Fire ultimate (user, 2026-11-19): Fire Lance jets blast down from your boots and lift you
## ult_lift_height up; there three magic circles open around your head, facing the aimed spot, and
## each fires a gigantic Fire Lance beam at it for ult_beam_time. You drop when they end.
func _fire_ultimate(a: Dictionary, player: Node, spot: Vector3, radius: float) -> void:
	var t: CombatTuning = GameData.tuning
	var feet: Vector3 = player.global_position
	hover_y = feet.y + t.ult_lift_height
	_hover_left = t.ult_lift_time + t.ult_beam_delay + t.ult_beam_gap * 2.0 + t.ult_beam_time
	var right: Vector3 = (player.facing as Vector3).cross(Vector3.UP).normalized()
	for s in [-1.0, 1.0]:  # one jet under each boot, riding along with you
		var jet := _lance_fx("forge_fire_lance", feet + right * s * 0.15, Vector3.DOWN, t.ult_lift_height + 0.5, t.ult_jet_width, _hover_left)
		if jet != null:
			jet.reparent(player)
			_jets.append(jet)
	get_tree().create_timer(t.ult_lift_time, false).timeout.connect(_circles_from_above.bind(a, player, spot, radius))


func _circles_from_above(a: Dictionary, player: Node, spot: Vector3, radius: float) -> void:
	if not is_instance_valid(player) or player.is_dead():
		return
	var t: CombatTuning = GameData.tuning
	var from: Vector3 = player.global_position
	var flat := Vector3(spot.x - from.x, 0.0, spot.z - from.z)
	var ahead: Vector3 = flat.normalized() if flat.length() > 0.5 else player.facing
	var right := ahead.cross(Vector3.UP).normalized()
	var each := a.duplicate()
	each["base_damage"] = GameData.num(a, "base_damage") * t.ult_beam_share
	var head := _brow(player, Vector3.ZERO)
	for i in 3:
		var s := float(i - 1)  # left of your head, above it, right of it
		var circle_at: Vector3 = head + (right * s if s != 0.0 else Vector3.UP) * t.ult_circle_around
		var side: Vector3 = right * s * t.ult_beam_spread
		var wait := t.ult_beam_delay + t.ult_beam_gap * i
		var circle := UltimateFx.circle("Fire", circle_at, (spot + side - circle_at).normalized(), t.ult_circle_size, wait + t.ult_beam_time)
		get_tree().create_timer(wait, false).timeout.connect(_ult_beam.bind(each, player, circle_at, spot, side, radius, circle))


## One of the three beams: from the circle `from` at the aimed spot (`side` off it, so the three land
## side by side), for ult_beam_time; it follows your aim while it fires (user, 2026-11-19), burns
## each enemy it touches once, and the ground where it first lands burns.
func _ult_beam(a: Dictionary, player: Node, from: Vector3, spot: Vector3, side: Vector3, radius: float, circle: Node3D) -> void:
	if not is_instance_valid(player) or player.is_dead():
		return
	var t: CombatTuning = GameData.tuning
	var b := {"a": a, "player": player, "from": from, "spot": spot, "side": side, "circle": circle, "left": t.ult_beam_time, "hit": {}}
	_ult_beam_aim(b)
	b.fx = _lance_fx("forge_fire_lance", from, b.dir, b.reach, t.ult_beam_width, t.ult_beam_time)
	_ult_beams.append(b)
	_burn_ground(a, player, spot + side, radius * t.ult_fire_ground_radius)
	Combat.shake(t.shake_heavy)
	HitStop.trigger(t.hitstop_light)


## Points beam `b` at the crosshair (or the spot first aimed, without one), a little past it.
func _ult_beam_aim(b: Dictionary) -> void:
	var aim: Vector3 = b.player.aim_point()
	var target: Vector3 = (aim if aim != Vector3.INF else b.spot) + b.side
	b.dir = (target - b.from).normalized()
	b.reach = minf(b.from.distance_to(target) + 2.0, aim_range() + 10.0)


func _update_ult_beams(delta: float) -> void:
	var t: CombatTuning = GameData.tuning
	for b: Dictionary in _ult_beams.duplicate():
		b.left -= delta
		if b.left <= 0.0 or not is_instance_valid(b.player) or b.player.is_dead():
			if is_instance_valid(b.fx):
				b.fx.queue_free()
			_ult_beams.erase(b)
			continue
		_ult_beam_aim(b)
		var fx: Node3D = b.fx if is_instance_valid(b.fx) else null
		if fx != null and absf(b.dir.y) < 0.99:
			fx.scale.z = b.reach / LANCE_FX_LENGTH
			fx.look_at(b.from + b.dir, Vector3.UP)
		if is_instance_valid(b.circle):
			b.circle.quaternion = Quaternion(Vector3.UP, b.dir)
		_beam_hits(b.a, b.player, b.hit, b.from, b.dir, b.reach, t.ult_beam_width)


## While the Fire ultimate holds you up: the Player hangs at hover_y.
func levitating() -> bool:
	return _hover_left > 0.0


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


## Lunge forward (Movement only), then the beam bursts out where you land.
func _lance(a: Dictionary, player: Node, dir: Vector3, reach: float, half_width: float) -> void:
	dir = Vector3(dir.x, 0.0, dir.z).normalized()
	var lunge: float = GameData.tuning.lance_lunge_m if a.get("slot") == "Movement" else 0.0
	invulnerable = true
	var start: Vector3 = player.global_position
	# A magic circle opens in front of your forehead as you lunge (user, 2026-11-19); the beam
	# fires out of it when you land.
	var t: CombatTuning = GameData.tuning
	var circle := UltimateFx.circle(GameData.text(a, "damage_type", "Fire"), _brow(player, dir), dir,
		t.lance_circle_diameter * 0.5, LUNGE_TIME + t.lance_beam_time)
	_beam = {"a": a, "player": player, "reach": reach, "width": maxf(half_width, 0.5), "circle": circle,
		"fx": null, "on": false, "left": t.lance_beam_time, "hit": {}, "spin": 0.0}
	var tw := create_tween()
	tw.tween_method(_leap_step.bind(player, start, start + dir * lunge, 0.0), 0.0, 1.0, LUNGE_TIME)
	tw.tween_callback(_start_beam)


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
	b.fx = _lance_fx(GameData.text(b.a, "ability_id"), _brow(player, dir), dir, b.reach, b.width, t.lance_beam_time)
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
	var dir: Vector3 = player.aim_direction(_brow(player, player.facing))
	var from := _brow(player, dir)
	if circle != null:
		circle.global_position = from
		circle.quaternion = Quaternion(Vector3.UP, dir) * Quaternion(Vector3.UP, b.spin)
	if not b.on:
		return
	if fx != null and absf(dir.y) < 0.99:
		fx.global_position = from
		fx.look_at(from + dir, Vector3.UP)
	_beam_hits(b.a, player, b.hit, from, dir, b.reach, b.width)


## Your lance scene (models/own/fx/fire/forge_fire_lance.tscn for `id`) at `from` pointing `dir`,
## stretched to `reach` long and `half_width` * 2 across, its fade landing `time` s later; without
## the scene, the code's beam. Returns the scene (null without).
func _lance_fx(id: String, from: Vector3, dir: Vector3, reach: float, half_width: float, time: float) -> Node3D:
	var scene := ElementFx.own_scene(id)
	var root := Vfx._root()
	if scene == null or root == null:
		ElementFx.beam("Fire", from, from + dir * reach)
		return null
	var fx: Node3D = scene.instantiate()
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
