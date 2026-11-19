extends Node
## The one place damage is applied. Everything that hurts something goes through
## Combat.deal(), which also handles statuses, lightning chains, feedback
## (hit-stop, shake, damage numbers) and the signals godly gifts listen to.

signal hit_landed(target: Node, info: DamageInfo, dealt: float)
signal killed(target: Node, info: DamageInfo)
## A status was applied by `source` (used for the on_status_applied trigger).
signal status_applied(target: Node, status_id: String, source: Node)
## Non-physical damage from `source` hit a target (used by element combos like the Fire + Lightning duo godly gift).
signal element_hit(target: Node, element: String, source: Node)

const CHAIN_RADIUS := 4.0
const CHAIN_BASE_COUNT := 2
const CHAIN_DAMAGE_FRACTION := 0.5

## Set by the arena: the camera rig (for shake) and the node effects are spawned under.
var camera_rig: Node = null
var effects_root: Node3D = null
## Set by the arena: its CrowdDirector, whose grid answers "who is near here" (enemies_in_radius).
var crowd: CrowdDirector = null
## Game time in seconds. Godly gift cooldowns and timed buffs use this (not the wall
## clock), so they pause with the game and run correctly in fast tests.
var time := 0.0
## The valley's water (its ValleyTerrain: rivers, lakes, rapids); null = no water
## (the arena). Anyone deeper than about chest height swims (Player, Enemy).
var water: Object = null


## Water surface height above `p`, or -INF where there's no water.
func water_surface(p: Vector3) -> float:
	return water.water_surface(p.x, p.z) if water != null else -INF


func _physics_process(delta: float) -> void:
	time += delta


func now_msec() -> int:
	return int(time * 1000.0)


func deal(target: Node, info: DamageInfo) -> float:
	if target == null or not is_instance_valid(target) or not target.has_method("take_hit"):
		return 0.0
	if target.is_dead():
		return 0.0
	var dealt: float = target.take_hit(info)
	# Only the hit that killed it reports the kill: a gift reacting below can finish the target
	# with its own deal(), which reports it, and this one must not report it again.
	var died_here: bool = target.is_dead()
	if dealt > 0.0 and _is_player(info.source):
		Run.note("damage_dealt", dealt)
		if target is Enemy and target.tactics and info.is_direct():
			ElementReactions.react(target, info)  # before this hit's own statuses land
	if target is Enemy and _launches(info):
		target.launch_from_hit(info)
	var statuses: StatusEffects = target.get("statuses")
	if statuses != null and not target.is_dead():
		for s in info.statuses:
			apply_status(target, s.id, s.stacks, info.source, s.duration_bonus)
	_feedback(target, info, dealt)
	hit_landed.emit(target, info, dealt)
	if info.damage_type != "Physical" and _is_player(info.source):
		element_hit.emit(target, info.damage_type, info.source)
	if info.damage_type == "Lightning" and info.can_chain and _is_player(info.source):
		_chain_lightning(target, info)
	if died_here:
		if target is Node3D:
			ElementFx.kill(info.damage_type, target.global_position + Vector3.UP)
		killed.emit(target, info)
	return dealt


func apply_status(target: Node, status_id: String, stacks := 1, source: Node = null, duration_bonus := 0.0) -> void:
	if target == null or not is_instance_valid(target) or target.is_dead():
		return
	var statuses: StatusEffects = target.get("statuses")
	if statuses == null:
		return
	statuses.apply(status_id, stacks, source, duration_bonus)
	status_applied.emit(target, status_id, source)


## Damages every enemy within `radius` of `center`. Returns the enemies hit.
func area(center: Vector3, radius: float, template: DamageInfo, exclude: Array = []) -> Array:
	var hit := enemies_in_radius(center, radius, exclude)
	if _is_player(template.source):  # your blasts break buildings and props too
		Breakable.smash_near(get_tree(), center, radius * 0.6, center)
	for e in hit:
		var info := _copy(template)
		var away: Vector3 = (e.global_position - center)
		away.y = 0.0
		info.knockback_dir = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
		deal(e, info)
	return hit


## Units your weapon can hit besides enemies: a tribe's warriors while you help defend their
## village (user, 2026-11-05: hit them twice before any raider and you turn on the tribe).
const STRIKABLE := "strikable"


## What your swings and shots can hit: enemies, and anyone STRIKABLE.
func weapon_targets(center: Vector3, radius: float, exclude: Array = []) -> Array:
	var out := enemies_in_radius(center, radius, exclude)
	for e in get_tree().get_nodes_in_group(STRIKABLE):
		if e in exclude or e.is_dead():
			continue
		var d: Vector3 = e.global_position - center
		d.y = 0.0
		if d.length() <= radius:
			out.append(e)
	return out


func enemies_in_radius(center: Vector3, radius: float, exclude: Array = []) -> Array:
	var out: Array = []
	# The fight's crowd grid finds the nearby ones; without it (no arena), every enemy.
	# Sleeping units (Enemy.set_dormant) leave the crowd: they're 160+ m away and out of reach.
	var pool: Array = crowd.near(center, radius + 0.4, Enemy.Team.HOSTILE) if is_instance_valid(crowd) else get_tree().get_nodes_in_group("enemies")
	for e in pool:
		if not is_instance_valid(e) or not e.is_in_group("enemies") or e in exclude or e.is_dead():
			continue
		var d: Vector3 = e.global_position - center
		d.y = 0.0
		if d.length() <= radius + 0.4:
			out.append(e)
	return out


func nearest_enemies(center: Vector3, radius: float, count: int, exclude: Array = []) -> Array:
	var found := enemies_in_radius(center, radius, exclude)
	found.sort_custom(func(a, b): return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	return found.slice(0, count)


func shake(amount: float) -> void:
	if camera_rig != null and is_instance_valid(camera_rig):
		camera_rig.add_trauma(amount)


func _chain_lightning(origin: Node, info: DamageInfo) -> void:
	var player: Node = info.source
	var extra := 0
	if player.get("stats") != null:
		extra = int(player.stats.get_stat("chain_bonus"))
	var targets := nearest_enemies(origin.global_position, CHAIN_RADIUS, CHAIN_BASE_COUNT + extra, [origin])
	var from: Vector3 = origin.global_position + Vector3.UP
	for t in targets:
		var to: Vector3 = t.global_position + Vector3.UP
		if ElementFx.bolt_arc(from, to):  # your bolts arc to it (user, 2026-11-08)
			ElementFx.hit("Lightning", to, 0.8)
		else:
			ElementFx.beam("Lightning", from, to)
		var chained := DamageInfo.make(info.amount * CHAIN_DAMAGE_FRACTION, "Lightning", DamageInfo.Kind.CHAIN, player)
		chained.can_chain = false
		deal(t, chained)


func _feedback(target: Node, info: DamageInfo, dealt: float) -> void:
	var t: CombatTuning = GameData.tuning
	if info.hitstop > 0.0:
		HitStop.trigger(info.hitstop)
	if info.shake > 0.0:
		shake(info.shake)
	if t.show_damage_numbers and dealt > 0.0 and target is Node3D:
		Vfx.damage_number(target.global_position + Vector3.UP * 2.0, dealt, _element_color(info.damage_type), info.is_crit)
	var from: Vector3 = info.source.global_position if info.source is Node3D and is_instance_valid(info.source) else (target.global_position if target is Node3D else Vector3.ZERO)
	if dealt > 0.0 and target is Node3D and info.kind != DamageInfo.Kind.STATUS and target.has_method("bleeds") and target.bleeds():
		var blow: Vector3 = target.global_position - from
		Vfx.blood(target.global_position + Vector3.UP, blow, t.blood_hit_drops)
		# The combat feel plan (2026-11-18): stains on the ground, a cloud and more stains on a kill.
		var dead: bool = target.is_dead()
		Vfx.blood_stains(target.global_position, blow, t.blood_stains_per_hit * (2 if dead else 1), 1.4 if dead else 1.0)
		if dead:
			Vfx.blood(target.global_position + Vector3.UP, blow + Vector3.UP, t.blood_kill_drops)
	if dealt > 0.0 and target is Enemy and info.kind != DamageInfo.Kind.STATUS and info.damage_type == "Physical" and target.wears_metal():
		var toward: Vector3 = from - target.global_position
		Vfx.sparks(target.global_position + Vector3.UP * 1.2, toward + Vector3.UP * 0.5, t.metal_sparks)
		if target.is_dead():  # a killing blow knocks a piece of armour off
			var away := -toward.normalized() if toward.length() > 0.01 else Vector3.FORWARD
			Vfx.armor_piece(target.global_position + Vector3.UP * 1.6, away * 5.0 + Vector3.UP * 5.0)
	if dealt > 0.0 and _is_player(info.source) and info.kind == DamageInfo.Kind.HEAVY and target is Node3D:
		Vfx.burst(target.global_position + Vector3.UP * 0.4, 0.9, Color(1, 1, 1, 0.8), 0.08)  # the white flash of a heavy blow (reels)
	if dealt > 0.0 and _is_player(info.source) and info.kind in [DamageInfo.Kind.LIGHT, DamageInfo.Kind.HEAVY] and target is Node3D \
			and camera_rig != null and is_instance_valid(camera_rig) and camera_rig.has_method("kick"):
		camera_rig.kick(target.global_position - from, t.camera_kick * (2.0 if info.kind == DamageInfo.Kind.HEAVY else 1.0))
	if dealt > 0.0 and target is Node3D and info.kind != DamageInfo.Kind.STATUS:
		# The element's hit burst: bigger for heavy hits and crits, smaller for chains.
		var strength := 1.6 if info.is_crit or info.kind == DamageInfo.Kind.HEAVY else (0.7 if info.kind == DamageInfo.Kind.CHAIN else 1.0)
		var toward: Vector3 = info.source.global_position + Vector3.UP if info.source is Node3D and is_instance_valid(info.source) else Vector3.INF
		ElementFx.hit(info.damage_type, target.global_position + Vector3.UP, strength, toward, info.kind == DamageInfo.Kind.HEAVY)


## Your heavy attacks and magic send enemies flying (user, 2026-11-01).
func _launches(info: DamageInfo) -> bool:
	return not info.no_launch and _is_player(info.source) and (info.kind in [DamageInfo.Kind.HEAVY, DamageInfo.Kind.ABILITY]
		or (info.kind == DamageInfo.Kind.LIGHT and info.category == "Magic"))


func _is_player(node: Node) -> bool:
	return node != null and is_instance_valid(node) and node.is_in_group("player")


func _copy(template: DamageInfo) -> DamageInfo:
	# A shot outlives its shooter: a dead shooter's arrow still hits, from no one.
	var d := DamageInfo.make(template.amount, template.damage_type, template.kind, template.source if is_instance_valid(template.source) else null)
	d.category = template.category
	d.is_crit = template.is_crit
	d.knockback = template.knockback
	d.knockdown = template.knockdown
	d.hitstop = template.hitstop
	d.shake = template.shake
	d.can_chain = template.can_chain
	d.no_launch = template.no_launch
	d.explosive = template.explosive
	d.statuses = template.statuses.duplicate(true)
	return d


## Each element's color (see ElementFx.STYLES).
func _element_color(element: String) -> Color:
	return ElementFx.color(element)
