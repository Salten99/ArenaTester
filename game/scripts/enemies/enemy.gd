class_name Enemy
extends CharacterBody3D
## A fighting unit (or villager) built from a unit row: Army Units, Barbarians &
## Beasts, Champions or Tribe Members. Despite the name it can be on any side:
##   HOSTILE  fights you and your warriors ("enemies" group)
##   FRIENDLY fights enemies, follows you when there are none ("allies" group)
##   NEUTRAL  village guards and villagers going about their day ("villagers" group)
## Fighters chase a target, wait for an attack token (only against the player),
## telegraph, strike, recover.

enum State { CHASE, WAIT, WINDUP, STRIKE, RECOVER, STAGGER, DOWN, FROZEN, DEAD, CHARGE_WIND, CHARGE }
enum Team { HOSTILE, FRIENDLY, NEUTRAL }

const GRAVITY := 20.0
const GROUPS := {Team.HOSTILE: "enemies", Team.FRIENDLY: "allies", Team.NEUTRAL: "villagers"}
## Friendly units look for enemies this far away; otherwise they follow you.
const ALLY_SIGHT := 70.0

var unit: Dictionary
var unit_id := ""
var health := HealthComponent.new()
var statuses := StatusEffects.new()
var is_large := false
## A bandit of another race: barbarian stats, that race's look (EncounterSystem bandit parties).
## A wild animal many times its size: make_giant().
var giant := false
## The fight's mini boss: tougher (mini_boss_hp_mult) and bigger.
var mini_boss := false
## Your mount walking beside you (Mount): its look, from ModelRegistry.for_mount.
var companion_look := {}
## Part of Count Fuckula's corrupted tribe (Void attacks, cleared by Light/Stone).
var corrupted := false
var size_scale := 1.0
## Water monsters (rig_type "Water monster..."): they float at the surface, never
## leave deep water, and only go after someone swimming (user, 2026-10-29).
var water_bound := false
## Stays up in the air, this far above the ground, until it dives at its target.
var flying := false
var fly_height := 12.0
## Leaves you alone until you hit it (faction "Neutral").
var peaceful := false
## x its health on top of everything else (a fight with your allies: WaveDirector.health_mult).
var health_mult := 1.0
## Thrown by a galloping mount (throw()): flying, limp if it can ragdoll, until it gets up.
var thrown := false
var _throw_vel := Vector3.ZERO
var _throw_time := 0.0
var _throw_ragdoll := false
var _limp_height := 0.0  ## how far above this unit's feet its limp body was at launch
var _throw_speed := 0.0  ## last frame's horizontal speed, to notice a sudden stop
var _thrower: Node
var state: State = State.CHASE
var team: Team = Team.HOSTILE
## Villagers never fight: they wander near their post and run from battles.
## Animals (faction "Animal") neither: hurt, they run from whoever hit them.
var civilian := false
var _calm_left := 0.0  ## an animal stops running this long after its last hurt
## Where a guard or villager stands; they return to it when idle. INF = none.
var post := Vector3.INF
## Wild units each belong to a side (user, 2026-11-05): barbarians, or a beast's own kind. Units of
## different sides that notice each other fight (a manticore and a band of barbarians). "" = none.
var faction := ""
## A hostile unit with an aggro radius waits at its post until someone comes this close.
var aggro_radius := 0.0
## Wild groups wander this far around their post (0 = stand guard). Villagers wander 10 m.
var roam_radius := 0.0
## Villagers run away from this point (a battle in their village). INF = calm.
var flee_from := Vector3.INF
## Fleeing villagers run into this house and hide there (hidden) until the fight ends.
var hide_at := Vector3.INF
var target: Node3D
var player: Node3D
var director: CrowdDirector

var _state_time := 0.0
var _state_len := 0.0
var _knock := Vector3.ZERO
var _orbit_sign := 1.0
var _mat: StandardMaterial3D
var _base_color := Color(0.55, 0.5, 0.45)
var _flash_time := 0.0
var _retarget := 0.0
var _aggroed := false
var _boosted := false
var _wander_to := Vector3.INF
var _wander_wait := 0.0
var _visual: Node3D  ## the meshes; animated instead of the physics body
## Where a shooter aims, fixed ranged_aim_lock seconds before it shoots (INF = still tracking).
var _aim_at := Vector3.INF
## Getting unstuck: how long it has been blocked, and the side-step it is taking.
var _stuck_time := 0.0
var _detour := Vector3.ZERO
var _detour_time := 0.0
const STUCK_AFTER := 0.5
## A ragdolled body lies this long before it sinks away.
const RAGDOLL_SECONDS := 3.5
## How long after a heavy shot its body can still be pinned, and how far ahead it looks (m).
const PIN_WATCH_SECONDS := 1.5
const PIN_REACH := 1.0
var _pinning := false
var _pinned := false
var _pinned_left := 0.0
var _pin_watch_left := 0.0
var _pin_dir := Vector3.ZERO
var _pin_bolt: Node3D
const DETOUR_TIME := 0.9
var _marker: MeshInstance3D
## The animated model, or null when using the capsule fallback.
var model: CharacterModel

# ---------------------------------------------------------------- arena tactics (user, 2026-11-19)
# The endless arena turns these on (WaveDirector.tactics): a posture meter that breaks into a
# grab finisher, shields, shooters that keep their distance, witches' ground circles and elements,
# and the berserker's charge. Off everywhere else, so the valley's units fight as before.
var tactics := false
var shielded := false  ## blocks light and heavy hits from the front; grab, chain, throws and hits from behind get through
var element_status := ""  ## a witch's element: her circles carry it, and it bursts onto those near her when she dies
var poise := 0.0  ## fills with your hits; full = broken (staggered, and a grab finishes it)
var _poise_rest := 0.0  ## s since the last hit: posture recovers after POISE_REST
var _broken_left := 0.0
var _broken_tag: Label3D
var _charge_dir := Vector3.ZERO
var _charge_cd := 3.0
var _charge_hit: Array = []
const POISE_MAX := 100.0
const POISE_BY_KIND := {DamageInfo.Kind.LIGHT: 30.0, DamageInfo.Kind.HEAVY: 70.0, DamageInfo.Kind.ABILITY: 50.0}
const POISE_REST := 1.2
const POISE_RECOVERY := 25.0  ## per second, after POISE_REST
const BREAK_TIME := 2.5
const SHIELD_ARC := 0.35  ## a hit is "from the front" when the attacker is within this dot of where it faces
const KITE_NEAR := 7.0  ## shooters back off when you come closer than this
const CHARGER := "barb_berserker"
const CHARGE_WIND := 0.8
const CHARGE_SPEED := 17.0
const CHARGE_TIME := 1.1
const CHARGE_COOLDOWN := 6.0


## Your mount as a friendly fighter: a unit built from its Mounts row (its
## health, speed and half its charge damage per butt). Call before adding to the tree.
func setup_companion(row: Dictionary, look: Dictionary, p_player: Node3D, p_director: CrowdDirector) -> void:
	setup("", p_player, p_director, Team.FRIENDLY)
	unit_id = "mount_" + str(row.get("mount_id", ""))
	unit = {"unit_id": unit_id, "display_name": row.get("display_name", "Mount"), "role": "Melee",
		"hp": GameData.num(row, "hp", 150.0), "damage": GameData.num(row, "charge_damage", 25.0) * 0.5,
		"damage_type": "Physical", "move_speed": GameData.num(row, "sprint_mps", 12.0), "attack_range_m": 2.2,
		"charge_damage": GameData.num(row, "charge_damage", 25.0), "attack_force": GameData.num(row, "attack_force", 14.0)}
	companion_look = look
	is_large = false
	size_scale = 1.0


## Call after setup, before adding to the tree.
## A wild animal grown to a monstrous size, a mini boss (user, 2026-11-03). After setup, before adding to the tree.
func make_giant() -> void:
	var t: CombatTuning = GameData.tuning
	make_mini_boss()
	giant = true
	civilian = false  # even a giant deer fights
	peaceful = false
	size_scale = t.giant_scale
	unit = unit.duplicate()
	unit["display_name"] = "Giant " + GameData.text(unit, "display_name")
	unit["hp"] = GameData.num(unit, "hp", 25.0) * t.giant_health_mult
	unit["damage"] = maxf(GameData.num(unit, "damage", 0.0) * t.giant_damage_mult, t.giant_min_damage)
	unit["xp_reward"] = GameData.num(unit, "xp_reward", 2.0) * t.giant_xp_mult
	unit["attack_range_m"] = GameData.num(unit, "attack_range_m", 2.0) * 1.6


func make_mini_boss() -> void:
	mini_boss = true
	is_large = true
	size_scale = 2.0
	_base_color = Color(0.6, 0.25, 0.25)


## Call before adding to the tree.
func setup(p_unit_id: String, p_player: Node3D, p_director: CrowdDirector, p_team := Team.HOSTILE) -> void:
	unit_id = p_unit_id
	unit = GameData.unit(unit_id)
	player = p_player
	director = p_director
	team = p_team
	civilian = unit.has("archetype") or GameData.text(unit, "faction") == "Animal"
	var role := GameData.text(unit, "role", "Melee")
	is_large = role in ["Large", "Miniboss", "Boss"] or unit_id.begins_with("champ_")
	size_scale = 2.0 if unit_id.begins_with("champ_") else (1.7 if is_large else 1.0)
	water_bound = GameData.text(unit, "rig_type").begins_with("Water")
	flying = GameData.text(unit, "rig_type").begins_with("Flying")
	peaceful = GameData.text(unit, "faction") == "Neutral"
	if water_bound or GameData.text(unit, "rig_type").contains("real size"):
		size_scale = 1.0  # built at their real size
	_base_color = Color(0.6, 0.25, 0.25) if is_large else Color(0.55, 0.5, 0.45)


func _ready() -> void:
	collision_mask = 0b001   # world only; crowding is handled by separation
	set_team(team)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4 * size_scale
	capsule.height = 1.7 * size_scale
	shape.shape = capsule
	shape.position.y = 0.85 * size_scale
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var living := unit.has("race_id") and not corrupted
	var look := ModelRegistry.for_tribe(unit_id) if living else ModelRegistry.for_unit(unit_id)
	var beast: Dictionary = ModelRegistry.for_beast(unit_id) if unit_id.begins_with("beast_") or unit_id.begins_with("animal_") or ModelRegistry.BEASTS.has(unit_id) else {}
	if not companion_look.is_empty():
		beast = companion_look
	if not beast.is_empty():
		var b := BeastModel.new()
		_visual.add_child(b)
		if b.setup_beast(beast.model, beast.scale, beast.get("tint", Color(0, 0, 0, 0))):
			model = b
			model.play("Idle_A")
		else:
			b.queue_free()
		look = {}
	if not look.is_empty():
		var m := CharacterModel.new()
		_visual.add_child(m)
		if m.setup(look.model, look.get("weapon", ""), size_scale):
			model = m
			model.play("Idle_A" if team == Team.NEUTRAL else "Running_A")
		else:
			m.queue_free()
	if model == null:
		_build_capsule(capsule, shape.position.y)
	elif flying:
		model.flapping = true  # winged flyers (the harpy) beat their wings all the time
	if model != null and giant:
		_visual.scale = Vector3.ONE * size_scale
		var tag := Label3D.new()
		tag.text = GameData.text(unit, "display_name")
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 56
		tag.outline_size = 14
		tag.pixel_size = 0.02
		tag.modulate = Color(1.0, 0.72, 0.3)
		tag.visibility_range_end = 70.0
		tag.position.y = 2.6 * size_scale
		add_child(tag)
		health.died.connect(tag.queue_free)
	_update_marker()
	add_child(health)
	add_child(statuses)
	statuses.aura_size = size_scale
	_boosted = team == Team.FRIENDLY and companion_look.is_empty()  # your mount keeps its own health
	var person := team == Team.HOSTILE and model != null and not (model is BeastModel) 		and not GameData.text(unit, "role", "Melee") in ["Melee", "Ranged", "Magic"]  # minions stay weak (pivot, 2026-11-18)
	health.setup(GameData.num(unit, "hp", 25.0) * (GameData.tuning.ally_health_mult if _boosted else 1.0)
		* (EncounterSystem.mini_boss_mult(unit_id) if mini_boss else 1.0) * (GameData.tuning.humanoid_health_mult if person else 1.0) * health_mult)
	health.died.connect(_on_died)
	_orbit_sign = 1.0 if RunRng.chance(50.0) else -1.0
	if director != null:
		director.register(self)


## Switches side (a village's guards join you, or turn on you).
func set_team(t: Team) -> void:
	for g in GROUPS.values():
		if is_in_group(g):
			remove_from_group(g)
	if t == Team.FRIENDLY and team != Team.FRIENDLY and is_inside_tree() and not _boosted:
		# A village's guards joining you get the same toughness as your own warriors.
		_boosted = true
		health.max_hp *= GameData.tuning.ally_health_mult
		health.hp *= GameData.tuning.ally_health_mult
	team = t
	if state != State.DEAD:
		add_to_group(GROUPS[t])
		collision_layer = 0b100 if t == Team.HOSTILE else 0b1000  # layer 3 enemies, layer 4 everyone else
	target = null
	_retarget = 0.0
	if is_inside_tree():
		_update_marker()


## Far-away villagers pause (no physics, hidden) to keep the big valley fast.
## Everything stops: movement, status ticks and the model's animation (hundreds of
## far-away units otherwise cost several ms a frame).
## Sleeping units also leave the crowd director, whose push-apart check walks its
## whole list for every awake unit, every frame.
func set_dormant(on: bool) -> void:
	if on == (process_mode == Node.PROCESS_MODE_DISABLED):
		return  # already so (events and camps ask every half second; a woken villager in hiding stays hidden)
	process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	visible = not on
	if director != null and not is_dead():
		if on:
			director.unregister(self)
		elif not self in director.enemies:
			director.register(self)


## Fallback look (capsule with a glowing visor) when the unit has no model.
func _build_capsule(capsule: CapsuleShape3D, center_y: float) -> void:
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = capsule.radius
	mesh.height = capsule.height
	mesh.radial_segments = 12
	mesh.rings = 4
	body.mesh = mesh
	body.position.y = center_y
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color
	body.material_override = _mat
	_visual.add_child(body)
	var eye := MeshInstance3D.new()
	var eye_mesh := BoxMesh.new()
	eye_mesh.size = Vector3(0.5, 0.12, 0.12) * size_scale
	eye.mesh = eye_mesh
	eye.position = Vector3(0, 1.45 * size_scale, -0.35 * size_scale)
	eye.material_override = Vfx.material(Color(1.0, 0.9, 0.6))
	_visual.add_child(eye)


## A colored ring at the feet: blue = on your side, red = a tribe's warrior fighting you.
func _update_marker() -> void:
	var show := team == Team.FRIENDLY or (team == Team.HOSTILE and unit.has("race_id") and not corrupted)
	if not show:
		if _marker != null:
			_marker.visible = false
		return
	if _marker == null:
		_marker = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.55 * size_scale
		torus.outer_radius = 0.7 * size_scale
		_marker.mesh = torus
		_marker.position.y = 0.08
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_marker)
	_marker.visible = true
	_marker.material_override = Vfx.material(Color(0.3, 0.65, 1.0) if team == Team.FRIENDLY else Color(1.0, 0.25, 0.2))


func is_dead() -> bool:
	return state == State.DEAD


## Big battles (user, 2026-11-05: 500 troops without lag): with many units about, a unit far
## from you thinks and moves only every `crowd_stride`-th physics tick, with the time it
## skipped (CrowdDirector sets the stride from the crowd's size). Near you, thrown or dead,
## every tick. Measured at 500 units: the units' own code cost 16 ms a tick before.
static var crowd_stride := 1
const FULL_RATE_RANGE := 20.0
var _skip_left := 0
var _skipped := 0.0
## This tick is a far unit's turn in a big crowd: it walks without collisions (_think).
var _far_turn := false


## In the crowd: not one of the nearest crowd_full_fighters (CrowdDirector._rank_crowd), so it takes
## turns like a far unit even close by.
var in_crowd := false


func _physics_process(delta: float) -> void:
	_far_turn = false
	if model != null:
		model.in_crowd = in_crowd
	if crowd_stride > 1 and not thrown and state != State.DEAD and not _pinning and held_by == null and is_instance_valid(player) \
			and (in_crowd or global_position.distance_squared_to(player.global_position) > FULL_RATE_RANGE * FULL_RATE_RANGE):
		_skipped += delta
		_skip_left -= 1
		if _skip_left > 0:
			return
		_skip_left = crowd_stride
		delta = _skipped
		_far_turn = true
	_skipped = 0.0
	_think(delta)


func _think(delta: float) -> void:
	if held_by != null:
		_follow_hand()
		return
	if _pinning:
		_watch_for_wall(delta)
	if thrown and not (state == State.DEAD and _throw_ragdoll):
		_update_throw(delta)  # a dead animal still falls to the ground
		return
	if state == State.DEAD:
		return
	_state_time += delta
	_flash_time -= delta
	if tactics:
		_update_poise(delta)
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = randf_range(0.3, 0.5)  # uneven, so an army spawned together drifts apart instead of all re-picking in one tick
		target = _pick_target()
	_update_color()
	var t: CombatTuning = GameData.tuning
	var to_target := Vector3.ZERO
	var dist := 999.0
	if is_instance_valid(target) and not target.is_dead():
		to_target = target.global_position - global_position
		to_target.y = 0.0
		dist = to_target.length()
	else:
		target = null
	var reach := GameData.num(unit, "attack_range_m", 2.0) + 0.4 * size_scale
	var speed := GameData.num(unit, "move_speed", 5.0) * t.enemy_speed_scale * (1.0 - statuses.slow_fraction())
	var surface := _surface_here()
	var depth := surface - global_position.y
	var swimming := depth > 1.2 * size_scale
	if swimming and not water_bound:
		speed *= 0.45  # deep water slows everyone (but the water monsters)
	var desired := Vector3.ZERO
	var at_player := target != null and target == player
	if is_large and _carry_item(delta, to_target, dist):
		state = State.CHASE
		desired = Vector3.ZERO  # it stands to throw

	match state:
		State.CHASE, State.WAIT:
			if is_instance_valid(_item):
				pass
			elif target == null:
				state = State.CHASE
				desired = _idle_move(speed)
			elif tactics and _kites() and dist < KITE_NEAR:
				state = State.CHASE
				desired = -to_target.normalized() * speed  # a shooter backs off to shoot again
			elif tactics and unit_id == CHARGER and _charge_cd <= 0.0 and at_player and dist > 5.0 and dist < 15.0:
				_charge_dir = to_target.normalized()
				_enter(State.CHARGE_WIND, CHARGE_WIND)
				Vfx.ring(global_position + Vector3.UP * 0.05, 1.4, Color(1.0, 0.25, 0.1), CHARGE_WIND)
			elif dist <= reach + 0.2 and _may_attack(at_player) and _flanked(to_target):
				_enter(State.WINDUP, t.enemy_telegraph * (t.large_slowdown if is_large else 1.0))
			elif at_player and dist <= t.wait_ring_distance + 0.5 and director != null and director.full():
				state = State.WAIT
				# No token free: circle the player at the waiting distance.
				var tangent := Vector3(-to_target.z, 0.0, to_target.x).normalized() * _orbit_sign
				var radial := to_target.normalized() * (dist - t.wait_ring_distance)
				desired = (tangent * 0.35 + radial).limit_length(1.0) * speed * 0.6
			else:
				state = State.CHASE
				desired = _flank_move(to_target, reach) * speed
		State.WINDUP:
			if is_ranged() and _aim_at == Vector3.INF and target != null and _state_len - _state_time <= t.ranged_aim_lock:
				_aim_at = target.global_position + Vector3.UP  # stop tracking: the shot goes where you were
			if _state_time >= _state_len:
				_strike(reach, to_target, dist)
				_enter(State.STRIKE, 0.12)
		State.STRIKE:
			if _state_time >= _state_len:
				# the sheet's attacks_per_sec sets the full cycle; enemy_recovery stays the shortest rest
				var rest := maxf(t.enemy_recovery, 1.0 / maxf(GameData.num(unit, "attacks_per_sec", 1.0), 0.1) - t.enemy_telegraph - 0.12)
				_enter(State.RECOVER, t.ranged_recovery if is_ranged() else rest * (t.large_slowdown if is_large else 1.0))
		State.CHARGE_WIND:  # it roars and paws, turning with you; the run's direction locks as it goes
			if _state_time >= _state_len:
				if target != null:
					_charge_dir = to_target.normalized()
				_charge_hit = [self]
				_enter(State.CHARGE, CHARGE_TIME)
		State.CHARGE:
			desired = _charge_dir * CHARGE_SPEED
			_charge_hits()
			if _state_time >= _state_len:
				_charge_cd = CHARGE_COOLDOWN
				_enter(State.RECOVER, 0.6)
		State.RECOVER, State.STAGGER, State.DOWN, State.FROZEN:
			if _state_time >= _state_len:
				if director != null:
					director.release(self)
				if state == State.FROZEN and model != null:
					model.set_speed(1.0)  # thawed: animations run again
				state = State.CHASE

	if _detour_time > 0.0 and state in [State.CHASE, State.WAIT]:
		_detour_time -= delta
		desired = _detour * maxf(desired.length(), speed * 0.5)
	if director != null and state != State.FROZEN:
		desired += director.separation(self) * 4.0
	var face := to_target if target != null and state in [State.CHASE, State.WAIT, State.WINDUP, State.CHARGE_WIND] else Vector3(desired.x, 0.0, desired.z)
	if tactics and _kites() and state == State.CHASE and target != null:
		face = to_target  # backing off, it keeps its eyes (and sling) on you
	if state == State.WINDUP and _aim_at != Vector3.INF:
		face = Vector3(_aim_at.x - global_position.x, 0.0, _aim_at.z - global_position.z)
	if face.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), clampf(10.0 * delta, 0.0, 1.0))
	if water_bound and desired.length() > 0.1 and not _deep_water(global_position + desired.normalized() * 2.0):
		desired = Vector3.ZERO  # the shore: stay in the water
		_wander_to = Vector3.INF
	velocity.x = desired.x + _knock.x
	velocity.z = desired.z + _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, t.knockback_friction * delta * maxf(1.0, _knock.length()))
	if flying:
		var ground: float = Combat.water.stand_height(global_position.x, global_position.z, global_position.y) if Combat.water != null and Combat.water.has_method("stand_height") else global_position.y - fly_height
		var goal: float = maxf(ground, surface) + fly_height
		if target != null and dist < 25.0:
			goal = target.global_position.y + 1.5  # down to bite
		velocity.y = clampf((goal - global_position.y) * 2.0, -9.0, 9.0)
	elif water_bound:
		velocity.y = clampf(((surface if surface != -INF else global_position.y) - global_position.y) * 4.0, -4.0, 4.0)
	elif swimming:
		velocity.y = clampf((surface - 1.0 * size_scale - global_position.y) * 4.0, -4.0, 4.0)
	else:
		if is_on_floor():
			_landed(_fall_speed)
			_fall_speed = 0.0
		else:
			_fall_speed = maxf(_fall_speed, -velocity.y)
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	var before := global_position
	var catch_up := delta / get_physics_process_delta_time()  # > 1 after skipped ticks: cover their distance too
	var land: Object = Combat.water
	if _far_turn and not flying and not water_bound and not swimming and is_on_floor() and land != null and land.has_method("stand_height"):
		# shortcut: far units in a big crowd skip collisions and follow the terrain (they can pass
		# through houses and trees 20+ m from you); upgrade to move_and_slide if it shows in play.
		var p := global_position + Vector3(velocity.x, 0.0, velocity.z) * delta
		p.y = land.stand_height(p.x, p.z, global_position.y)
		global_position = p
	else:
		velocity *= catch_up
		move_and_slide()
		velocity /= catch_up
	if state == State.CHARGE and _state_time > 0.15 and is_on_wall() and _hit_a_wall():
		_crash()
		return
	_check_stuck(before, Vector3(desired.x, 0.0, desired.z), delta)


## Thrown back hard (a galloping mount): people go limp and fly, animals fly whole.
## Hitting a tree, house or rock hurts (_impact); alive, it gets back up after.
## Your heavy or magic hit sends this enemy flying. Bosses and champions stand their ground.
## A killing blow that knocks back launches the body this much harder (user, 2026-11-19: "launched").
const DEATH_LAUNCH := 1.33


func launch_from_hit(info: DamageInfo) -> void:
	if mini_boss or water_bound or unit_id.begins_with("champ_") or GameData.text(unit, "role") == "Boss":
		return  # water_bound: thrown onto land it could never get back
	var t: CombatTuning = GameData.tuning
	var dir := Vector3(info.knockback_dir.x, 0.0, info.knockback_dir.z)
	if dir.length() < 0.01 and info.source is Node3D and is_instance_valid(info.source):
		dir = Vector3(global_position.x - info.source.global_position.x, 0.0, global_position.z - info.source.global_position.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var k := 1.0
	if info.source is Player and is_instance_valid(info.source) and info.source.moveset != null:
		k *= info.source.moveset.launch_scale()  # each weapon class throws its own way
	if info.explosive:
		k *= t.explosion_launch_scale
	if state == State.DEAD:
		k *= DEATH_LAUNCH  # the killing blow sends it flying harder (user, 2026-11-19)
	if info.kind == DamageInfo.Kind.HEAVY and info.category == "Missile":  # may pin it to whatever it hits
		k *= t.pin_launch_scale
		_pinning = true
		_pin_watch_left = PIN_WATCH_SECONDS
		_pin_dir = dir
	throw((dir * t.launch_speed + Vector3.UP * t.launch_lift) * k, info.source)


## Whether a hit draws blood: not from bones, slime or wood.
func bleeds() -> bool:
	return not (unit_id.begins_with("horde_skeleton") or unit_id in ["horde_necromancer", "horde_slime", "monster_stone_giant", "monster_magma_golem", "monster_gargoyle", "monster_mummy"] or "treekin" in unit_id)


## Whether this unit's model shows metal (user, 2026-11-18: every armoured model sparks and loses
## pieces). The generated people wear plate or mail by role (make_characters.py: Melee "heavy",
## Cavalry "medium", Champion "champion" outfits); barbarians wear patches, the dead and beasts none.
## shortcut: role-based, not read from the model; upgrade to a per-model flag when the user's own art lands.
func wears_metal() -> bool:
	if model == null or model is BeastModel or not bleeds() or unit_id.begins_with("barb_"):
		return unit_id.begins_with("champ_") and model != null and not model is BeastModel
	return GameData.text(unit, "role") in ["Melee", "Cavalry", "Champion"] or unit_id.begins_with("champ_")


# ---------------------------------------------------------------- Large units throw items
# (combat feel plan, user 2026-11-18): a Large enemy picks up a barrel, crate, boulder or branch
# within item_pickup_reach and throws it at its target from item_throw_min..item_throw_max away.

var _item: Node3D  ## the item it lifts over its head, or null
var _item_time := 0.0
var _item_wait := 0.0
const ITEM_THROW_WINDUP := 0.2


## True while it's lifting an item to throw (it stands still meanwhile).
func _carry_item(delta: float, to_target: Vector3, dist: float) -> bool:
	var t: CombatTuning = GameData.tuning
	_item_wait -= delta
	if is_instance_valid(_item):
		if state not in [State.CHASE, State.WAIT] or thrown or target == null or _item.get("held_by") != self:
			_drop_item()
			return false
		_item_time += delta
		rotation.y = atan2(to_target.x, to_target.z) if to_target.length() > 0.1 else rotation.y
		if model != null and _item_time >= t.item_lift_time - ITEM_THROW_WINDUP and _item_time - delta < t.item_lift_time - ITEM_THROW_WINDUP:
			model.play_strike("Throw", ITEM_THROW_WINDUP, ITEM_THROW_WINDUP + 0.4)  # lets go on the clip's release frame
		if _item_time >= t.item_lift_time:
			var aim: Vector3 = target.global_position + Vector3.UP * 1.0
			var from: Vector3 = _item.global_position
			var flat := Vector3(aim.x - from.x, 0.0, aim.z - from.z)
			var speed := 18.0
			var time := maxf(flat.length() / speed, 0.2)
			var vel := flat / time + Vector3.UP * ((aim.y - from.y) / time + 0.5 * 20.0 * time)
			var item := _item
			_item = null
			item.hurl(vel, self)
			_item_wait = t.item_throw_cooldown
		return true
	if _item_wait > 0.0 or target == null or state != State.CHASE or dist < t.item_throw_min or dist > t.item_throw_max:
		return false
	var best: Node3D = null
	for it in get_tree().get_nodes_in_group("throwables"):
		if it.held_by == null and not it.is_dead() and it.global_position.distance_to(global_position) <= t.item_pickup_reach * size_scale:
			best = it
			break
	if best == null:
		_item_wait = 1.0  # look again in a moment
		return false
	_item = best
	_item_time = 0.0
	best.grab_by(self)
	if model != null:
		model.play("Ranged_Magic_Raise", t.item_lift_time, true)  # both arms up, the item over its head
	return true


func _drop_item() -> void:
	if is_instance_valid(_item) and _item.get("held_by") == self:
		_item.release_grab()
	_item = null


## Where an item it lifts sits: over its head.
func hold_point_for(item: Node3D) -> Vector3:
	return global_position + Vector3.UP * (2.3 * size_scale + 0.3) if item == _item and not thrown and state != State.DEAD else Vector3.INF


# ---------------------------------------------------------------- grabbed and hurled
# (combat feel plan, user 2026-11-18; the player's side is Grabber)

var held_by: Node3D  ## the player holding this minion, or null
var _held_layer := 0
var _hurled := false  ## flying as a hurled projectile: it hits whoever it passes and bursts on a wall
var _hurl_hit: Array = []  ## who it already hit this flight


func grab_by(by: Node3D) -> void:
	_cancel_attack()
	if thrown and model != null and model.is_ragdoll():
		model.unragdoll()
	thrown = false
	_throw_ragdoll = false
	held_by = by
	_held_layer = collision_layer if collision_layer != 0 else (0b100 if team == Team.HOSTILE else 0b1000)
	collision_layer = 0  # it doesn't push you or the crowd while it hangs in your hand
	velocity = Vector3.ZERO
	_enter(State.DOWN, 999.0)


## Let go of (or thrown): it stands again unless something else takes over (hurl, death).
func release_grab() -> void:
	if held_by == null:
		return
	held_by = null
	collision_layer = _held_layer
	if state != State.DEAD:
		var ground: float = Combat.water.stand_height(global_position.x, global_position.z, global_position.y) if Combat.water != null and Combat.water.has_method("stand_height") else global_position.y - 0.45
		global_position.y = maxf(ground, global_position.y - 0.45)
		_enter(State.STAGGER, 0.5)


func _follow_hand() -> void:
	var at: Vector3 = held_by.hold_point_for(self) if is_instance_valid(held_by) and held_by.has_method("hold_point_for") else Vector3.INF
	if at == Vector3.INF:
		release_grab()
		return
	global_position = at
	var to: Vector3 = held_by.global_position - global_position
	rotation.y = atan2(to.x, to.z)


## Hurled by `by` at `vel`: it flies limp, hits everyone it passes (a heavy blow, they're launched)
## and bursts against a wall, hurting everyone within hurl_burst_radius.
func hurl(vel: Vector3, by: Node) -> void:
	_hurled = true
	_hurl_hit = [self]
	throw(vel, by)


func _update_hurl() -> void:
	var body: Node3D = model.ragdoll_hips() if _throw_ragdoll and model != null and model.ragdoll_hips() != null else self
	var at: Vector3 = body.global_position + (Vector3.UP if body == self else Vector3.ZERO)
	var v: Vector3 = (body as PhysicsBody3D).linear_velocity if body is PhysicalBone3D else _throw_vel
	var flat := Vector2(v.x, v.z).length()
	var p := _thrower as Player if is_instance_valid(_thrower) and _thrower is Player else null
	if p != null:
		var fresh: Array = Combat.enemies_in_radius(at, 1.2, _hurl_hit)
		if not fresh.is_empty():
			_hurl_hit.append_array(fresh)
			_hurl_blow(p, fresh, at)
	var t: CombatTuning = GameData.tuning
	var wall := false
	if flat > 2.0:  # a wall (not the ground) right ahead of it
		var ahead := Vector3(v.x, 0.0, v.z).normalized()
		var q := PhysicsRayQueryParameters3D.create(at, at + ahead * maxf(0.9, flat * 0.05), 0b001)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		wall = hit and hit.normal.y < 0.5
	if wall:
		_hurled = false  # hit a wall: it bursts
		if p != null:
			_hurl_blow(p, Combat.enemies_in_radius(at, t.hurl_burst_radius, _hurl_hit), at)
		if bleeds():
			Vfx.blood(at, Vector3.UP, t.blood_kill_drops)
			Vfx.blood_stains(at, Vector3(v.x, 0.0, v.z), t.blood_stains_per_hit * 2, 1.4)
		if state != State.DEAD:
			Combat.deal(self, DamageInfo.make(health.hp + 1.0, "Physical", DamageInfo.Kind.STATUS, _thrower if is_instance_valid(_thrower) else null))
	elif flat < 1.5 and _throw_time > 0.3:
		_hurled = false


func _hurl_blow(p: Player, targets: Array, at: Vector3) -> void:
	if targets.is_empty():
		return
	var t: CombatTuning = GameData.tuning
	p.hit_targets(targets, p.moveset._base(p) * t.heavy_multiplier, DamageInfo.Kind.HEAVY, t.knockback_heavy, false,
		t.hitstop_heavy, t.shake_heavy, [], at, "Physical", false, false)
	Enemy.bowled_over(targets)


const THROW_STUN := 1.5


## Hit by a thrown body or item (arena tactics): knocked flat and stunned, posture broken.
static func bowled_over(targets: Array) -> void:
	for e in targets:
		if e is Enemy and is_instance_valid(e) and e.tactics and not e.is_dead():
			e.add_poise(POISE_MAX)
			e.stun(THROW_STUN)


func throw(vel: Vector3, by: Node) -> void:
	if _pinned_left > 0.0:
		return  # stuck to the wall
	vel *= GameData.tuning.launch_velocity_mult
	if state == State.DEAD:
		if model != null and model.is_ragdoll():
			model.push_ragdoll(vel)  # the hit killed it: the body flies
			if _pinning:
				set_physics_process(true)  # a dead body can be pinned too
		return
	if is_large:
		vel *= 0.35
	_cancel_attack()
	if director != null:
		director.release(self)
	thrown = true
	_thrower = by
	_throw_vel = vel
	_throw_time = 0.0
	_throw_speed = Vector2(vel.x, vel.z).length()
	state = State.DOWN
	if model != null and model.is_ragdoll():  # already flying: this hit sends it farther
		model.push_ragdoll(vel)
		_throw_ragdoll = true
	else:
		_throw_ragdoll = model != null and model.ragdoll(vel)
		if _throw_ragdoll:
			collision_layer = 0  # the body is what's solid now, not the capsule
			_limp_height = model.ragdoll_hips().global_position.y - global_position.y


## While a heavy shot carries this body: is there a wall right ahead of it?
func _watch_for_wall(delta: float) -> void:
	_pin_watch_left -= delta
	var body: Node3D = model.ragdoll_hips() if model != null and model.is_ragdoll() else self
	if body == null or _pin_watch_left <= 0.0:
		_pinning = false
		if state == State.DEAD:
			set_physics_process(false)
		return
	var from: Vector3 = body.global_position + (Vector3.ZERO if body != self else Vector3.UP)
	var q := PhysicsRayQueryParameters3D.create(from, from + _pin_dir * PIN_REACH, 0b001)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.normal.y < 0.5:
		_pin_to(hit.position, hit.normal)


## Sticks the body to the wall at `at`, a bolt through it.
func _pin_to(at: Vector3, normal: Vector3) -> void:
	_pinning = false
	var t: CombatTuning = GameData.tuning
	var alive := state != State.DEAD
	var flat := Vector3(normal.x, 0.0, normal.z).normalized()
	var chest: Vector3
	if model is BeastModel:
		model.freeze_limp()
		chest = model.ragdoll_hips().global_position if model.ragdoll_hips() != null else at + flat * 0.4
	else:
		if model != null:
			model.unragdoll()
			model.play("Hit_B", 0.0, true)
			if model.anim != null and model.anim.has_animation("Hit_B"):
				model.anim.seek(0.3, true)
			model.set_speed(0.0)
		rotation.y = atan2(-flat.x, -flat.z)  # its back to the wall
		var ground: float = Combat.water.stand_height(at.x, at.z, at.y) if Combat.water != null and Combat.water.has_method("stand_height") else at.y - 1.2
		var height := maxf(at.y - 1.05 * size_scale, ground + 0.5)  # its feet off the ground
		global_position = Vector3(at.x, height, at.z) + flat * 0.35 * size_scale
		chest = global_position + Vector3.UP * 1.05 * size_scale
	_show_pin_bolt(chest, flat)
	_pinned = true
	_pinned_left = t.pin_seconds
	if bleeds():
		Vfx.blood(chest, flat, t.blood_slam_drops)
	if not alive:
		set_physics_process(false)
		return
	thrown = true
	_throw_ragdoll = true
	state = State.DOWN
	Combat.deal(self, DamageInfo.make(t.pin_damage, "Physical", DamageInfo.Kind.STATUS, _thrower if is_instance_valid(_thrower) else null))


## Killed by a stone spike (the Stone special, user 2026-11-16): the body hangs on it, the point
## through its chest, until it's gone. `tip`: the spike's point.
func impale(tip: Vector3) -> void:
	if state != State.DEAD or _pinned:
		return
	_pinned = true
	set_physics_process(false)
	if model is BeastModel:  # an animal stays limp, stuck where the spike holds it
		model.freeze_limp()
		if model.ragdoll_hips() != null:
			model.ragdoll_hips().global_position = tip - Vector3.UP * 0.3 * size_scale
	else:
		if model != null:
			model.unragdoll()
			model.play("Hit_B", 0.0, true)
			if model.anim != null and model.anim.has_animation("Hit_B"):
				model.anim.seek(0.3, true)
			model.set_speed(0.0)
		global_position = tip - Vector3.UP * 1.3 * size_scale
	if bleeds():
		Vfx.blood(tip, Vector3.UP, GameData.tuning.blood_slam_drops)


func _show_pin_bolt(chest: Vector3, flat: Vector3) -> void:
	_pin_bolt = Node3D.new()
	add_child(_pin_bolt)
	_pin_bolt.top_level = true
	_pin_bolt.global_position = chest
	_pin_bolt.look_at(chest + flat, Vector3.UP if absf(flat.y) < 0.99 else Vector3.RIGHT)
	var shaft := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.035
	rod.bottom_radius = 0.035
	rod.height = 1.5
	rod.radial_segments = 6
	shaft.mesh = rod
	shaft.rotation.x = PI * 0.5
	shaft.material_override = Vfx.material(Color(0.32, 0.2, 0.12))
	_pin_bolt.add_child(shaft)
	for side in [Vector3.RIGHT, Vector3.UP]:  # the fletching sticks out toward you
		var vane := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.2, 0.02, 0.26) if side == Vector3.RIGHT else Vector3(0.02, 0.2, 0.26)
		vane.mesh = box
		vane.position = Vector3(0, 0, -0.62)
		vane.material_override = Vfx.material(Color(0.8, 0.18, 0.14))
		_pin_bolt.add_child(vane)


func _unpin() -> void:
	_pinned = false
	_pinned_left = 0.0
	if is_instance_valid(_pin_bolt):
		_pin_bolt.queue_free()
	if model != null:
		model.set_speed(1.0)
	_get_up(global_position)


func _update_throw(delta: float) -> void:
	if _pinned_left > 0.0:
		_pinned_left -= delta
		if _pinned_left <= 0.0:
			_unpin()
		return
	_throw_time += delta
	if _hurled:
		_update_hurl()
	var dead := state == State.DEAD
	if _throw_ragdoll:
		var hips: PhysicsBody3D = model.ragdoll_hips()
		if hips == null:
			_get_up(global_position)
			return
		# You hit, aim at and target this unit where its body is.
		global_position = hips.global_position - Vector3.UP * _limp_height
		var v: Vector3 = hips.linear_velocity
		_impact(v.length())
		if not dead:
			_thrown_fall(v.y)
		if (_throw_time > 1.2 and v.length() < 1.0) or (_throw_time > 3.0 and v.y > -2.0) or _throw_time > 10.0:
			_get_up(hips.global_position)
		return
	_throw_vel.y -= GRAVITY * delta
	velocity = _throw_vel
	move_and_slide()
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_normal().y < 0.5:  # a wall, a tree, a rock: not the ground
			_throw_vel.x = 0.0
			_throw_vel.z = 0.0
	if not dead:
		_thrown_fall(0.0 if is_on_floor() else _throw_vel.y)
	if is_on_floor():
		_throw_vel.y = 0.0
		var h := Vector2(_throw_vel.x, _throw_vel.z).move_toward(Vector2.ZERO, 25.0 * delta)
		_throw_vel.x = h.x
		_throw_vel.z = h.y
	if not dead:
		_impact(_throw_vel.length())
		if _throw_time > 1.0 and is_on_floor() and Vector2(_throw_vel.x, _throw_vel.z).length() < 0.5:
			_get_up(global_position)


## A sudden stop while flying means it hit something: damage for the speed lost.
var _fall_speed := 0.0  ## how fast it's falling (m/s), while it's in the air


## Thrown or launched and falling (user, 2026-11-19: toss one straight up and it hurts when it lands):
## the fastest fall is kept, and when the fall stops, every m/s past THROWN_FALL_SAFE costs fall_damage.
## A limp body falls slower than a capsule (its damping), hence the lower safe speed than fall_safe_speed.
const THROWN_FALL_SAFE := 6.0


func _thrown_fall(vy: float) -> void:
	if vy < -1.0:
		_fall_speed = maxf(_fall_speed, -vy)
		return
	var s := _fall_speed
	_fall_speed = 0.0
	if s > THROWN_FALL_SAFE and state != State.DEAD:
		if bleeds():
			Vfx.blood_splat(Vector3(global_position.x, global_position.y + 0.03, global_position.z), 0.4 + s * 0.05)
		Combat.deal(self, DamageInfo.make((s - THROWN_FALL_SAFE) * GameData.tuning.fall_damage, "Physical", DamageInfo.Kind.STATUS,
			_thrower if is_instance_valid(_thrower) else null))


## Hit the ground falling at `speed` m/s: past fall_safe_speed it hurts, in proportion.
func _landed(speed: float) -> void:
	_rehome()
	var t: CombatTuning = GameData.tuning
	if speed <= t.fall_safe_speed or flying or state == State.DEAD:
		return
	Combat.deal(self, DamageInfo.make((speed - t.fall_safe_speed) * t.fall_damage, "Physical", DamageInfo.Kind.STATUS, null))


func _impact(speed: float) -> void:
	var t: CombatTuning = GameData.tuning
	var lost := _throw_speed - speed
	_throw_speed = speed
	if lost >= t.throw_impact_min and state != State.DEAD:
		if bleeds():
			var at: Vector3 = model.ragdoll_hips().global_position if _throw_ragdoll and model.ragdoll_hips() != null else global_position + Vector3.UP
			Vfx.blood(at, Vector3.UP, t.blood_slam_drops)
			Vfx.blood_splat(Vector3(at.x, global_position.y + 0.03, at.z), 0.5 + lost * 0.08)
		Combat.deal(self, DamageInfo.make(lost * t.throw_impact_damage, "Physical", DamageInfo.Kind.STATUS,
			_thrower if is_instance_valid(_thrower) else null))


## Knocked off a floating island (user, 2026-11-07): far below its post it stays down there, no
## walking back to a spot it can't reach.
func _rehome() -> void:
	if post != Vector3.INF and global_position.y < post.y - 8.0:
		post = global_position


func _get_up(at: Vector3) -> void:
	thrown = false
	_hurled = false
	if _throw_ragdoll:
		collision_layer = 0b100 if team == Team.HOSTILE else 0b1000
		model.unragdoll()
		var ground: float = Combat.water.stand_height(at.x, at.z, at.y) if Combat.water != null and Combat.water.has_method("stand_height") else global_position.y
		global_position = Vector3(at.x, ground + 0.1, at.z)
		_rehome()
	_throw_ragdoll = false
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO
	if model != null:
		model.play("Spawn_Ground", 1.0, true)
	_enter(State.DOWN, 1.0)


## Blocked by a wall, house or tree while trying to move: side-step around it.
func _check_stuck(before: Vector3, desired: Vector3, delta: float) -> void:
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if desired.length() < 0.5 or moved > desired.length() * delta * 0.3 or _detour_time > 0.0:
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time < STUCK_AFTER:
		return
	_stuck_time = 0.0
	var side := Vector3(-desired.z, 0.0, desired.x).normalized() * (1.0 if RunRng.chance(50.0) else -1.0)
	_detour = (side * 0.85 - desired.normalized() * 0.5).normalized()  # step aside and a little back
	_detour_time = DETOUR_TIME
	_wander_to = Vector3.INF  # wanderers pick a new spot afterwards


## Water deep enough to swim in (for water monsters).
static func _deep_water(p: Vector3) -> bool:
	return Combat.water != null and Combat.water.water_surface(p.x, p.z) - Combat.water.height(p.x, p.z) > 1.5


## The water level under this unit (-INF on dry land), re-measured only after it moves
## a metre: measuring every tick cost 10 ms for 500 units in the valley.
var _surface := -INF
var _surface_at := Vector2.INF


func _surface_here() -> float:
	var at := Vector2(global_position.x, global_position.z)
	if at.distance_squared_to(_surface_at) > 1.0:
		_surface = Combat.water_surface(global_position)
		_surface_at = at
	return _surface


## True for someone in the water (a water monster's prey).
static func _in_water(n: Node3D) -> bool:
	return Combat.water_surface(n.global_position) - n.global_position.y > 0.8


## Attack tokens: only a few enemies may swing at you (or at one of your warriors) at once.
## Archers, slingers and casters: anything that hits from more than 5 m.
func is_ranged() -> bool:
	return GameData.num(unit, "attack_range_m", 2.0) > 5.0


func _may_attack(at_player: bool) -> bool:
	if director == null or team != Team.HOSTILE:
		return true
	return director.request_token(self) if at_player else director.request_ally_token(self, target)


## Who to fight: hostile units go for you or your warriors (the nearest, you a
## little more often); friendly units go for the nearest enemy.
## How close the player must come before this unit notices them: its aggro radius, or less
## while the player sneaks (crouched), and less again from behind.
func _notice_distance() -> float:
	var hidden: float = player.stats.get_stat("stealth_pct") / 100.0 if player.get("stats") != null else 0.0  # the Rogue
	var plain := aggro_radius * clampf(1.0 - hidden, 0.2, 1.0)
	if not player.get("is_crouching"):
		return plain
	var t: CombatTuning = GameData.tuning
	var r := plain * t.stealth_notice_scale
	var to_player := player.global_position - global_position
	if Vector2(to_player.x, to_player.z).normalized().dot(Vector2(-global_basis.z.x, -global_basis.z.z).normalized()) < 0.0:
		r *= t.stealth_behind_scale
	return r


## Where to aim at it: its chest.
func aim_height() -> float:
	return 1.0 * size_scale


func _pick_target() -> Node3D:
	if civilian or team == Team.NEUTRAL or (peaceful and not _aggroed) or director == null:
		return null
	var best: Node3D = null
	var best_d := INF
	if team == Team.HOSTILE:
		var reach := maxf(aggro_radius, 25.0) * 2.0
		best = director.best_near(self, Team.FRIENDLY, ALLY_SIGHT, func(u: Enemy, d: float) -> float:
			if u.is_dead() or (water_bound and not _in_water(u)):
				return INF  # on land you're safe from them
			return _target_score(u, d))
		if faction != "" or water_bound:  # rival wild sides nearby, and prey knocked into the water
			var other := director.best_near(self, Team.HOSTILE, reach, func(u: Enemy, d: float) -> float:
				var rival := faction != "" and u.faction != "" and u.faction != faction
				var prey := water_bound and not u.water_bound and not u.flying and _in_water(u)
				return _target_score(u, d) if not u.is_dead() and (rival or prey) else INF)
			if other != null and (best == null or _target_score(other, global_position.distance_to(other.global_position)) < _target_score(best, global_position.distance_to(best.global_position))):
				best = other
		var near := INF  # how far the pick is, for noticing it: its real distance, not its score (a foe behind scores up to double)
		if best != null:
			near = global_position.distance_to(best.global_position)
			best_d = _target_score(best, near)
		if is_instance_valid(player) and not player.is_dead() and not (water_bound and not _in_water(player)):
			var d: float = global_position.distance_to(player.global_position) * 0.8
			if not _aggroed and aggro_radius > 0.0:
				d *= aggro_radius / _notice_distance()
			if d < best_d:
				best_d = d
				best = player
				near = d
		if aggro_radius > 0.0:
			if not _aggroed:
				if best == null or near > aggro_radius:
					return null
				_aggroed = true
			elif best == null or near > aggro_radius * 2.5 or (post != Vector3.INF and global_position.distance_to(post) > aggro_radius * 4.0):
				_aggroed = false  # you got away: give up and head home
				return null
		return best
	var leash: bool = not companion_look.is_empty() and is_instance_valid(player)
	if leash and (player as Player).mount.has_mark():
		return (player as Player).mount.mark  # the one you marked through the spyglass, however far
	if leash and (player as Player).mount.staying:
		return null  # told to wait somewhere: out of the fight
	return director.best_near(self, Team.HOSTILE, ALLY_SIGHT, func(u: Enemy, d: float) -> float:
		if u.is_dead():
			return INF
		if leash and u.global_position.distance_to(player.global_position) > GameData.tuning.mount_leash:
			return INF  # your mount stays at your side: only what's close to you
		return _target_score(u, d))


## How good a target `u` is, `d` metres away: lower is better. Must stay >= d
## (CrowdDirector.best_near stops searching early on that promise).
func _target_score(u: Node3D, d: float) -> float:
	# Foes straight ahead count at their distance, foes behind up to twice it: battle lines clash
	# instead of crossing.
	var to := Vector3(u.global_position.x - global_position.x, 0.0, u.global_position.z - global_position.z)
	if to.length() < 0.01:
		return d
	var ahead := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y)).dot(to / to.length())
	return d * (1.0 + 0.5 * (1.0 - ahead))


## Moving with nothing to fight: villagers flee battles or wander, guards keep
## their post, your warriors stay near you.
func _idle_move(speed: float) -> Vector3:
	var here := global_position
	if _calm_left > 0.0:
		_calm_left -= get_physics_process_delta_time()
		if _calm_left <= 0.0:
			flee_from = Vector3.INF
	if civilian and flee_from != Vector3.INF:
		if hide_at != Vector3.INF:
			var to_house := hide_at - here
			to_house.y = 0.0
			if to_house.length() < 6.0:  # at the wall: in through the door
				visible = false  # inside, hiding
				return Vector3.ZERO
			return to_house.normalized() * speed
		var away := here - flee_from
		away.y = 0.0
		return away.normalized() * speed if away.length() < 45.0 else Vector3.ZERO
	if team == Team.FRIENDLY and post == Vector3.INF and is_instance_valid(player):
		var to_p: Vector3 = player.global_position - here
		to_p.y = 0.0
		if not companion_look.is_empty():
			return _pace_with_player(to_p, speed)
		return to_p.normalized() * speed if to_p.length() > 7.0 else Vector3.ZERO
	if post == Vector3.INF:
		return Vector3.ZERO
	if civilian or roam_radius > 0.0:
		var r := roam_radius if roam_radius > 0.0 else 10.0
		_wander_wait -= get_physics_process_delta_time()
		if _wander_to == Vector3.INF or Vector2(_wander_to.x - here.x, _wander_to.z - here.z).length() < 0.8:
			if _wander_wait <= 0.0:
				_wander_to = post + Vector3(RunRng.randf_range(-r, r), 0.0, RunRng.randf_range(-r, r))
				_wander_wait = RunRng.randf_range(2.0, 6.0)
			else:
				return Vector3.ZERO
		var to_w := _wander_to - here
		to_w.y = 0.0
		return to_w.normalized() * speed * 0.35
	var to_post := post - here
	to_post.y = 0.0
	return to_post.normalized() * speed * 0.6 if to_post.length() > 1.5 else Vector3.ZERO


## Your mount fights from the far side of its target, away from the camera, so it isn't in
## your view (user, 2026-11-08, after Far Cry Primal). Everyone else goes straight in.
func _away_from_camera(to_target: Vector3) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if companion_look.is_empty() or cam == null:
		return Vector3.ZERO
	var away := global_position + to_target - cam.global_position
	away.y = 0.0
	return away.normalized()


## True once your mount is beside or behind its target (seen from the camera); always for others.
func _flanked(to_target: Vector3) -> bool:
	var away := _away_from_camera(to_target)
	return away == Vector3.ZERO or (-to_target.normalized()).dot(away) > -0.3


## The way to go: straight at the target, or for your mount round it to the far side.
func _flank_move(to_target: Vector3, reach: float) -> Vector3:
	var away := _away_from_camera(to_target)
	if away == Vector3.ZERO:
		return to_target.normalized()
	var to_spot := to_target + away * reach * 0.8
	if _flanked(to_target) or to_target.length() > reach * 3.0:
		return to_spot.normalized()
	var side := Vector3(-to_target.z, 0.0, to_target.x).normalized()  # near side: circle round, not through
	if side.dot(to_spot) < 0.0:
		side = -side
	return (side + to_target.normalized() * 0.3).normalized()


## Your mount on foot keeps your pace (user, 2026-11-01): it walks when you walk and gallops
## when you sprint. It keeps to your side, out from between you and the camera.
func _pace_with_player(to_p: Vector3, speed: float) -> Vector3:
	var m: Mount = (player as Player).mount
	if m.staying:  # told to wait somewhere: it goes there first
		var to_spot := m.spot - global_position if m.spot != Vector3.INF else Vector3.ZERO
		to_spot.y = 0.0
		return to_spot.normalized() * speed if to_spot.length() > 1.5 else Vector3.ZERO
	var pace: Vector3 = (player as CharacterBody3D).velocity
	pace.y = 0.0
	var t: CombatTuning = GameData.tuning
	var to_spot: Vector3 = to_p + (player as Player).mount.beside_you()
	var gap := to_spot.length() - 1.0
	if gap <= 0.0:
		return pace.limit_length(speed)
	return to_spot.normalized() * minf(speed, maxf(pace.length(), t.move_speed) + gap * 0.5)


func _strike(reach: float, to_target: Vector3, dist: float) -> void:
	if dist > reach + 0.5 or not is_instance_valid(target):
		return
	var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	if to_target.normalized().dot(fwd) < 0.3:
		return
	var damage_type := GameData.text(unit, "damage_type", "Physical")
	var info := DamageInfo.make(GameData.num(unit, "damage", 8.0), damage_type, DamageInfo.Kind.ENEMY, self)
	info.knockback = 6.0 if is_large else 3.0
	info.knockback_dir = to_target.normalized()
	if not companion_look.is_empty() and Vector2(velocity.x, velocity.z).length() > GameData.num(unit, "move_speed", 12.0) * 0.6:
		# Your mount at a charge hits like a heavy attack (user, 2026-11-05): its full charge, a knockdown.
		info.amount = GameData.num(unit, "charge_damage", 25.0)
		info.knockback = GameData.num(unit, "attack_force", 14.0)
		info.knockdown = true
	var status := GameData.text(unit, "status_effect")
	if status != "":
		info.with_status(status)
	if tactics and GameData.text(unit, "role") == "Magic":
		_cast_circle()
		return
	if is_ranged():
		_shoot(info, damage_type)
		for k in range(1, BURSTS.get(unit_id, 1)):  # a minigun: the rest of the burst
			get_tree().create_timer(k * BURST_GAP, false).timeout.connect(func():
				if is_instance_valid(target) and not is_dead():
					var shot := DamageInfo.make(info.amount, damage_type, DamageInfo.Kind.ENEMY, self)
					shot.knockback = 1.0
					shot.knockback_dir = info.knockback_dir
					_shoot(shot, damage_type))
		return
	Combat.deal(target, info)


## Who shoots guns, and who fires bursts (shots per attack) instead of one shot.
const GUNS := ["gnome_spore_slinger", "horde_minigun_demon"]
const BURSTS := {"horde_minigun_demon": 8}
const BURST_GAP := 0.07  ## seconds between a burst's shots
const BURST_SPREAD := 0.05  ## how far a burst's shots stray, per meter of range
var _barrels: Node3D


## The minigun's barrels turn with every shot (the user's model has them as their own part).
func _spin_barrels() -> void:
	if _barrels == null and model != null:
		_barrels = model.find_child("barrels", true, false) as Node3D
		if _barrels == null:
			_barrels = Node3D.new()  # a model without barrels: look only once
	if _barrels.is_inside_tree() and _barrels.get_parent() != null:
		_barrels.rotate_object_local(_barrel_axis(), 0.9)


func _barrel_axis() -> Vector3:
	var mesh := _barrels as MeshInstance3D
	if mesh == null or mesh.mesh == null:
		return Vector3.UP
	var size := mesh.mesh.get_aabb().size
	return Vector3.RIGHT if size.x >= size.y and size.x >= size.z else (Vector3.UP if size.y >= size.z else Vector3.BACK)


## Bows, slings, crossbows and spells fire a real shot at the locked aim point:
## arrows fly straight, spells bend slightly toward their target.
func _shoot(info: DamageInfo, damage_type: String) -> void:
	var t: CombatTuning = GameData.tuning
	var from := global_position + Vector3.UP * 1.3 * size_scale
	var at := _aim_at if _aim_at != Vector3.INF else target.global_position + Vector3.UP
	var magic := GameData.text(unit, "role") == "Magic"
	var speed := t.enemy_spell_speed if magic else t.enemy_shot_speed
	var gun := unit_id in GUNS  # gnomes shoot rifles (user, 2026-11-05), the demon its minigun: fast, bright bullets
	if gun:
		speed *= 2.2
	if BURSTS.has(unit_id):
		at += Vector3(RunRng.randf_range(-1.0, 1.0), RunRng.randf_range(-0.5, 0.8), RunRng.randf_range(-1.0, 1.0)) * BURST_SPREAD * from.distance_to(at)
		_spin_barrels()
	var color := Combat._element_color(damage_type) if magic or damage_type != "Physical" else Color(0.85, 0.8, 0.7)
	var p := Projectile.fire(from, at - from, speed, info, Color(1.0, 0.85, 0.35) if gun else color)
	if gun and p != null:
		Vfx.burst(from, 0.4, Color(1.0, 0.8, 0.4, 0.9), 0.08)  # the muzzle flash
	if p == null:
		Combat.deal(target, info)  # no effects layer: hit as before
		return
	p.hostile = team == Team.HOSTILE
	p.player = player
	p.lifetime = (from.distance_to(at) + 12.0) / speed
	if magic:
		p.homing = target
		p.pull_deg = t.enemy_magic_pull_deg


func take_hit(info: DamageInfo) -> float:
	if tactics and _blocks(info):
		return 0.0
	var dealt := health.take(info.amount * (GameData.tuning.ally_damage_taken if team == Team.FRIENDLY else 1.0))
	_flash_time = 0.08
	if model != null and bleeds() and health.max_hp > 0.0:
		model.set_blood(1.0 - health.hp / health.max_hp)
	var t: CombatTuning = GameData.tuning
	var resist := 0.35 if is_large else 1.0
	if info.knockback > 0.0:
		_knock = info.knockback_dir * info.knockback * resist
	if state == State.DEAD or thrown:
		return dealt
	if civilian and is_instance_valid(info.source) and info.source is Node3D:
		flee_from = info.source.global_position
		_calm_left = 8.0
	_aggroed = true
	if tactics:
		add_poise(POISE_BY_KIND.get(info.kind, 0.0))
		if is_broken():
			return dealt  # already reeling: hits don't cut the break short
	if info.knockdown and not is_large:
		_cancel_attack()
		_enter(State.DOWN, t.knockdown_time)
	elif info.is_direct() and state in [State.CHASE, State.WAIT, State.WINDUP] and not is_large:
		_cancel_attack()
		_enter(State.STAGGER, t.hit_stagger)
	return dealt


## Your shield turned this enemy's blow (the Guardian's parry): it reels, open to the follow-up.
func parried() -> void:
	if state != State.DEAD and not thrown:
		if tactics:
			_break()  # a parried blow leaves it wide open: grab it to finish it
			return
		_cancel_attack()
		_enter(State.STAGGER, GameData.tuning.parry_stagger * (0.5 if is_large else 1.0))


# ---------------------------------------------------------------- arena tactics

func is_broken() -> bool:
	return _broken_left > 0.0


## Fills the posture meter; full, it breaks.
func add_poise(amount: float) -> void:
	if amount <= 0.0 or is_broken() or state == State.DEAD:
		return
	_poise_rest = 0.0
	poise += amount * (0.5 if is_large or mini_boss else 1.0)
	if poise >= POISE_MAX:
		_break()


## Broken: it reels for BREAK_TIME with a gold mark over its head, and a grab finishes it.
func _break() -> void:
	if state == State.DEAD:
		return
	poise = 0.0
	_broken_left = BREAK_TIME
	if not thrown and held_by == null:
		_cancel_attack()
		_enter(State.STAGGER, BREAK_TIME)
	Vfx.ring(global_position + Vector3.UP * 0.1, 1.2 * size_scale, Color(1.0, 0.8, 0.25), 0.4)
	if _broken_tag == null:
		_broken_tag = Label3D.new()
		_broken_tag.text = "!"
		_broken_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_broken_tag.font_size = 96
		_broken_tag.outline_size = 18
		_broken_tag.pixel_size = 0.01
		_broken_tag.modulate = Color(1.0, 0.82, 0.25)
		_broken_tag.no_depth_test = true
		add_child(_broken_tag)
	_broken_tag.position.y = 2.4 * size_scale
	_broken_tag.visible = true


func _update_poise(delta: float) -> void:
	_charge_cd -= delta
	if _broken_left > 0.0:
		_broken_left -= delta
		if _broken_left <= 0.0 and _broken_tag != null:
			_broken_tag.visible = false
		return
	_poise_rest += delta
	if _poise_rest >= POISE_REST:
		poise = maxf(0.0, poise - POISE_RECOVERY * delta)


## Knocked flat for `seconds` (hit by a thrown body or item). Large ones only reel.
func stun(seconds: float) -> void:
	if state == State.DEAD or thrown or held_by != null:
		return
	_cancel_attack()
	_enter(State.STAGGER if is_large else State.DOWN, seconds * (0.5 if is_large else 1.0))


## A shield turns light and heavy blows from the front (not while it reels or lies down).
## A heavy blow on the shield still staggers it and fills its posture.
func _blocks(info: DamageInfo) -> bool:
	if not shielded or not info.kind in [DamageInfo.Kind.LIGHT, DamageInfo.Kind.HEAVY] or is_broken() \
			or state in [State.STAGGER, State.DOWN, State.FROZEN, State.DEAD] or not (info.source is Node3D) or not is_instance_valid(info.source):
		return false
	var to_source: Vector3 = (info.source as Node3D).global_position - global_position
	to_source.y = 0.0
	var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	if to_source.length() < 0.05 or to_source.normalized().dot(fwd) < SHIELD_ARC:
		return false
	Vfx.sparks(global_position + Vector3.UP * 1.2 + fwd * 0.5, to_source + Vector3.UP * 0.5, 8)
	Combat.shake(0.08)
	if info.kind == DamageInfo.Kind.HEAVY:
		add_poise(POISE_BY_KIND[DamageInfo.Kind.HEAVY])
		if not is_broken():
			_cancel_attack()
			_enter(State.STAGGER, 0.6)
	else:
		add_poise(10.0)
		_knock = -to_source.normalized() * 2.0
	return true


## Shooters (not casters) keep their distance.
func _kites() -> bool:
	return is_ranged() and GameData.text(unit, "role") == "Ranged"


## The charge runs into you (a heavy knockdown blow) and bowls over enemies in its way.
func _charge_hits() -> void:
	if is_instance_valid(target) and not target in _charge_hit and target.global_position.distance_to(global_position) < 1.7 * size_scale:
		_charge_hit.append(target)
		var info := DamageInfo.make(GameData.num(unit, "damage", 14.0) * 1.5, "Physical", DamageInfo.Kind.ENEMY, self)
		info.knockback = 12.0
		info.knockback_dir = _charge_dir
		info.knockdown = true
		Combat.deal(target, info)
		_charge_cd = CHARGE_COOLDOWN
		_enter(State.RECOVER, 0.8)
		return
	if director == null:
		return
	for e in director.near(global_position, 1.6, Team.HOSTILE):
		if e in _charge_hit or not is_instance_valid(e) or e.is_dead() or e.global_position.distance_to(global_position) > 1.6:
			continue
		_charge_hit.append(e)
		var bump := DamageInfo.make(GameData.num(unit, "damage", 14.0), "Physical", DamageInfo.Kind.ENEMY, self)
		bump.knockback = 8.0
		bump.knockback_dir = (e.global_position - global_position).normalized()
		Combat.deal(e, bump)
		if e.has_method("stun"):
			e.stun(1.5)


func _hit_a_wall() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < 0.5 and not (c.get_collider() is CharacterBody3D):
			return true
	return false


## The charge ends in a wall: it's dazed and open (broken), and the impact hurts.
func _crash() -> void:
	_charge_cd = CHARGE_COOLDOWN
	Vfx.burst(global_position + Vector3.UP, 1.2, Color(0.9, 0.85, 0.7, 0.9), 0.15)
	Combat.shake(0.25)
	health.take(health.max_hp * 0.15)
	if not is_dead():
		_break()


const ELEMENT_BURST_RADIUS := 4.5


## A dead witch's element bursts out onto everyone near her (the kill is yours, so is the status).
func _element_burst(at: Vector3) -> void:
	var dt := GameData.text(GameData.status(element_status), "damage_type", "Physical")
	ElementFx.area(dt, at, ELEMENT_BURST_RADIUS)
	var by: Node = player if is_instance_valid(player) else null
	for e in Combat.enemies_in_radius(at, ELEMENT_BURST_RADIUS):
		Combat.apply_status(e, element_status, 2, by)


## A witch's attack: a ring on the ground where you stand, which bursts after a moment.
func _cast_circle() -> void:
	if not is_instance_valid(target):
		return
	var at: Vector3 = target.global_position
	WitchCircle.cast(self, at, GameData.num(unit, "damage", 12.0), element_status)


## Down for knockdown_time (a Stone status). Large ones and bosses keep their feet.
func knock_down() -> void:
	if state != State.DEAD and not is_large and not thrown:
		_cancel_attack()
		_enter(State.DOWN, GameData.tuning.knockdown_time)


func freeze(seconds: float) -> void:
	if state != State.DEAD:
		_cancel_attack()
		_enter(State.FROZEN, seconds)


func _cancel_attack() -> void:
	if director != null:
		director.release(self)


func _enter(s: State, length: float) -> void:
	state = s
	_aim_at = Vector3.INF
	_state_time = 0.0
	_state_len = length
	if model == null:
		return
	model.set_speed(0.0 if s == State.FROZEN else 1.0)
	match s:
		State.WINDUP:  # the chop lands about halfway through, right when the strike happens
			model.play("Melee_1H_Attack_Chop", length * 2.0, true)
		State.STAGGER:
			model.play("Hit_A", 0.35, true)
		State.DOWN:
			model.play("Hit_B", length, true)


func _update_color() -> void:
	if model != null:
		_update_model_look()
		return
	var c := _base_color
	if state == State.WINDUP:
		c = c.lerp(Color(1.0, 0.45, 0.1), clampf(_state_time / maxf(_state_len, 0.01), 0.0, 1.0))
	elif state == State.FROZEN:
		c = Color(0.7, 0.9, 1.0)
	if statuses.has("fire"):
		c = c.lerp(Color(1.0, 0.4, 0.05), 0.55)
	if statuses.has("lightning"):
		c = c.lerp(Color(0.5, 0.75, 1.0), 0.5)
	if _flash_time > 0.0:
		c = Color(1, 1, 1)
	_mat.albedo_color = c
	_mat.emission_enabled = statuses.has("fire") or _flash_time > 0.0
	_mat.emission = c
	_mat.emission_energy_multiplier = 0.6


func _on_died() -> void:
	state = State.DEAD
	if _broken_tag != null:
		_broken_tag.visible = false
	if tactics and element_status != "":
		_element_burst.call_deferred(global_position)
	# Statuses stay until the body is removed, so on-kill godly gifts can still see them
	# (e.g. Kiln Heart: "killing a burning enemy"). Ticks on a dead enemy deal nothing.
	for g in GROUPS.values():
		if is_in_group(g):
			remove_from_group(g)
	if director != null:
		director.unregister(self)
	collision_layer = 0
	if _marker != null:
		_marker.visible = false
	if bleeds() and model != null:  # the ground soaks it up as the body sinks
		model.set_blood(1.0)
		Vfx.blood_pool(Vector3(global_position.x, global_position.y + 0.03, global_position.z), 1.1 * size_scale, 2.0, RAGDOLL_SECONDS, 1.4)
	var tw := create_tween()
	var push := (Vector3(_knock.x, 0.0, _knock.z).limit_length(9.0) + Vector3.UP * 2.5) * DEATH_LAUNCH
	if _pinned:  # it stays on the wall until it's gone
		if model != null:
			model.set_tint(Color(0.1, 0.1, 0.1, 0.25))
		set_physics_process(false)
		tw.tween_interval(RAGDOLL_SECONDS)
	elif model != null and (model.is_ragdoll() or model.ragdoll(push)):
		# The body flops where it falls, then sinks away.
		model.set_tint(Color(0.1, 0.1, 0.1, 0.25))
		set_physics_process(false)
		tw.tween_interval(RAGDOLL_SECONDS)
		tw.tween_callback(model.sink_ragdoll)  # the ground lets go: it drops out of sight
		tw.tween_interval(0.9)
	elif model != null:
		model.set_speed(1.0)
		model.play("Death_A", 0.8, true)
		model.set_tint(Color(0.1, 0.1, 0.1, 0.35))
		tw.tween_interval(1.0)
		tw.tween_property(_visual, "position:y", -1.5, 0.6)
	else:
		_mat.albedo_color = Color(0.2, 0.2, 0.2)
		tw.tween_property(_visual, "scale", Vector3(1.2, 0.05, 1.2), 0.25)
	tw.tween_callback(queue_free)


## Model version of the state colors: a tint overlay plus looping move animations.
func _update_model_look() -> void:
	var tint := Color(0, 0, 0, 0)
	if state == State.WINDUP:
		tint = Color(1.0, 0.45, 0.1, 0.45 * clampf(_state_time / maxf(_state_len, 0.01), 0.0, 1.0))
	elif state in [State.CHARGE_WIND, State.CHARGE]:
		tint = Color(1.0, 0.15, 0.05, 0.55)  # red: it's about to run you down
	elif is_broken():
		tint = Color(1.0, 0.8, 0.25, 0.4)  # gold: open to a finisher
	elif state == State.FROZEN:
		tint = Color(0.7, 0.9, 1.0, 0.5)
	if statuses.has("fire"):
		tint = Color(1.0, 0.4, 0.05, maxf(tint.a, 0.35))
	if statuses.has("lightning"):
		tint = Color(0.5, 0.75, 1.0, 0.4)
	if _flash_time > 0.0:
		tint = Color(1, 1, 1, 0.6)
	model.set_tint(tint)
	if state == State.CHARGE:
		model.play("Running_A")
	elif state in [State.CHASE, State.WAIT]:
		var moving := Vector2(velocity.x, velocity.z).length()
		model.play("Running_A" if moving > 3.3 or flying else ("Walking_A" if moving > 0.3 else "Idle_A"))  # wings never rest

# ---------------------------------------------------------------- status auras

## A looping effect while a status lasts (burning, frozen, poisoned...).
