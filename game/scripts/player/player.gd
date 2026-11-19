class_name Player
extends CharacterBody3D
## The player character: movement, dodge, the god's weapon moveset and abilities.
## Reads a PlayerIntent each physics frame (see PlayerInput); never reads keys itself.
##
## Weapon movesets are per weapon class (Heavy, Blade, Polearm, Ranged).
## Milestone 0 implements Heavy; other classes fall back to it until built.

signal died
signal stamina_changed(current: float, maximum: float)
## Tried to swim water only the Frogfolk can cross (rapids, deep lakes).
signal water_blocked

enum State { FREE, LIGHT, HEAVY, DODGE, CAST, PARRY, DEAD, GRAB, CHAIN }

@export var race_id := "dwarf"
@export var god_id := "forge_god"
## Picked with the race at run start; pledging to a new god keeps it.
@export var weapon_id := "warhammer"  ## main (melee) weapon
@export var sidearm_id := "bow"  ## held on its own key (user, 2026-11-06: a melee weapon and a sidearm, as in shooter-brawlers)
var using_sidearm := false
var spying := false  ## looking through the spyglass (the HUD names what's in the middle)
var _main: Dictionary
var _side: Dictionary
var _main_moveset: WeaponMoveset
var _side_moveset: WeaponMoveset
## Drop a character model (.glb / .tscn) here to replace the capsule.
@export var model_scene: PackedScene

## These races jump much higher and glide down, on foot and mounted (user, 2026-11-01).
const GLIDERS := ["angel", "bird"]

var stats := PlayerStats.new()
var health := HealthComponent.new()
var statuses := StatusEffects.new()
var godly_gifts := GodlyGiftManager.new()
var abilities := AbilityRunner.new()
var race_active := RaceActive.new()
var race_active_held := false
var _crosshair := Vector3.INF  ## what you're aiming at (PlayerIntent.crosshair)
var _knife_left := 0.0  ## seconds until the knife can be thrown again
var bow_left := 0.0  ## seconds until the bow can fire again
var _cast_clip := "Throw"
var _cast_slow := 1.0  ## the cast animation plays this many times longer (the Fire Lance's stab: 1.5)
const CAST_TIME := 0.25  ## a cast holds you this long (s)...
const CAST_CLIP := 0.4  ## ...while its animation plays this long
var input_source: Object  ## anything with read() -> PlayerIntent
## The race's mount (X to ride).
var mount: Mount
## In deep water: slow, floating, no attacks (see Combat.water).
var swimming := false
var _surface := -INF
var _blocked_cooldown := 0.0
## The current's push, fixed when you enter rapids or a deep lake, so it always
## drives you back the way you came (even past the middle).
var _current := Vector2.ZERO
## Frogfolk swim this much faster than everyone else.
const SWIM_ENTER := 1.3  ## water deeper than this at your feet: you swim...
const SWIM_EXIT := 0.8   ## ...until it's shallower than this
const SWIM_FLOAT := 1.05 ## how far below the surface your feet float
var is_large := false
var god_mode := false
## Thrown off a dying mount: limp (ragdoll) for THROWN_TIME, then you get up.
const THROWN_TIME := 2.0
## Holding the mount key this long on foot tells your mount to stay; a tap rides (or calls it back).
const MOUNT_HOLD := 0.4
var _sidearm_out := false  ## switched to your bow (C or the wheel), until you switch back
var _mount_hold := -1.0  ## seconds the mount key has been held on foot, -1 when it isn't
var _thrown_left := 0.0
## God mode (F6) also flies: Space up, Ctrl down, Shift fast. No gravity.
var flying := false
const FLY_SPEED := 30.0

var state: State = State.FREE
var facing := Vector3.FORWARD
var stamina := 100.0
var winded := false  ## ran out: no sprinting until sprint_recover_pct (else Shift keeps regen at 0)
var _stamina_used_msec := -100000
## How far the current heavy attack is charged (0..1); sets its damage (heavy_mult).
var heavy_charge := 0.0
var _heavy_hit_at := 0.0
var max_stamina := 100.0

var _god: Dictionary
var _weapon: Dictionary
var _race: Dictionary
var _state_time := 0.0
var _hit_done := false
var _combo_index := 0
var _combo_timer := 0.0
var _queued_light := false
var _dodge_dir := Vector3.ZERO
var _weapon_pivot: Node3D
## The animated character model, or null when using the capsule fallback.
var visual: CharacterModel
var _body := ""  ## the model file `visual` was built from
## The weapon type's attacks (Heavy, Blade, Polearm, Ranged).
var moveset: WeaponMoveset = WeaponMoveset.new()
var _weapon_hits := 0
var _low_health_fired := false
## In a cave or at a tower (LootSpots): your mount stays outside.
var no_mount := false
var _knock := Vector3.ZERO
var is_sliding := false
var is_crouching := false
var _slide_timer := 0.0
var _slide_dir := Vector3.ZERO
var _wall_jump_timer := 0.0

const LOW_HEALTH := 0.3
## The Guardian's shield (tools/blender/make_shield.py; your own models/own/gear_shield.glb wins).
const SHIELD := "gear_shield.glb"


func _ready() -> void:
	add_to_group("player")
	collision_layer = 0b10      # layer 2: player
	collision_mask = 0b101      # world + enemies
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	_build_visuals()
	race_active.player = self
	for c in [health, statuses, godly_gifts, abilities, race_active]:
		add_child(c)
	if input_source == null:
		input_source = PlayerInput.new()
		add_child(input_source)
	health.died.connect(_on_died)
	mount = Mount.new()
	mount.name = "Mount"
	add_child(mount)
	stats.stats_changed.connect(_on_stats_changed)
	Combat.element_hit.connect(_on_element_hit)
	setup(race_id, god_id, weapon_id)


## Applies race, god and weapon data. Safe to call again (pledging swaps only the god).
func setup(p_race: String, p_god: String, p_weapon := "", p_sidearm := "") -> void:
	race_id = p_race
	god_id = p_god
	_race = GameData.race(race_id)
	_god = GameData.god(god_id)
	var n := GameData.num
	stats.set_source("race", {
		"max_hp_pct": n.call(_race, "hp_mod_pct"), "melee_pct": n.call(_race, "melee_damage_mod_pct"),
		"missile_pct": n.call(_race, "missile_damage_mod_pct"), "magic_pct": n.call(_race, "magic_damage_mod_pct"),
		"attack_speed_pct": n.call(_race, "attack_speed_mod_pct"), "move_speed_pct": n.call(_race, "move_speed_mod_pct"),
		"stamina_pct": n.call(_race, "stamina_mod_pct"),
	})
	var t: CombatTuning = GameData.tuning
	health.setup(t.base_health * stats.mult("max_hp_pct"))
	max_stamina = t.base_stamina * stats.mult("stamina_pct")
	stamina = max_stamina
	abilities.load_for(god_id)
	if mount != null and mount.is_inside_tree():
		if mount.riding:
			mount.dismount()
		mount.refresh()
	equip(p_weapon if p_weapon != "" else weapon_id, p_sidearm if p_sidearm != "" else sidearm_id)
	if visual != null:
		visual.set_weapon_aura(god_id)
		visual.set_god_colors(race_id, god_id)  # shortcut: a saved run reloads in the pledged god's colors, not the starting god's


## Makes the player match a run's saved state: race, pledged god, godly gifts,
## level-ups and health. Used on fight start and resume.
func apply_run_state(state: RunState) -> void:
	if state.race_id != race_id or state.god_id != god_id:
		setup(state.race_id, state.god_id, state.weapon_id, state.sidearm_id)
	elif state.weapon_id != weapon_id or state.sidearm_id != sidearm_id:
		equip(state.weapon_id, state.sidearm_id)
	godly_gifts.load_from(state)
	LevelSystem.apply_all(state, stats)
	if state.hp >= 0.0:
		health.hp = clampf(state.hp, 1.0, health.max_hp)
		health.changed.emit(health.hp, health.max_hp)


## Level-ups and godly gifts change max health and stamina: keep the current fraction.
func _on_stats_changed() -> void:
	var t: CombatTuning = GameData.tuning
	var new_max := t.base_health * stats.mult("max_hp_pct")
	if not is_equal_approx(new_max, health.max_hp) and health.max_hp > 0.0:
		health.hp = health.hp / health.max_hp * new_max
		health.max_hp = new_max
		health.changed.emit(health.hp, health.max_hp)
	max_stamina = t.base_stamina * stats.mult("stamina_pct")


## Light or Stone damage on a corrupted enemy clears the Void mark (Council II 13).
func _on_element_hit(target: Node, element: String, source: Node) -> void:
	if source == self and element in ["Light", "Stone"] and target.get("corrupted") == true:
		statuses.remove("void")


## The weapon's row on the Weapons sheet.
## Takes up a main weapon and a sidearm (start of a run, or one you found).
func equip(main: String, side: String) -> void:
	weapon_id = main
	sidearm_id = side
	_main = GameData.weapon(main)
	_side = GameData.weapon(side)
	# Your class is your melee weapon (user, 2026-11-09): its row on the Weapons sheet carries the class's stats.
	var n := GameData.num
	stats.set_source("class", {
		"max_hp_pct": n.call(_main, "hp_mod_pct"), "melee_pct": n.call(_main, "melee_damage_mod_pct"),
		"missile_pct": n.call(_main, "missile_damage_mod_pct"), "magic_pct": n.call(_main, "magic_damage_mod_pct"),
		"attack_speed_pct": n.call(_main, "attack_speed_mod_pct"), "move_speed_pct": n.call(_main, "move_speed_mod_pct"),
		"stamina_pct": n.call(_main, "stamina_mod_pct"), "armor_pct": n.call(_main, "armor_pct"), "stealth_pct": n.call(_main, "stealth_pct"),
	})
	if visual != null and ModelRegistry.for_race(race_id, class_id()) != _body:
		# Each class has its own look per race (user, 2026-11-17): put on this class's body.
		remove_child(visual)
		visual.queue_free()
		visual = null
		_build_visuals()
	_main_moveset = WeaponMoveset.for_class(GameData.text(_main, "weapon_class", "Heavy"))
	_side_moveset = WeaponMoveset.for_class(GameData.text(_side, "weapon_class", "Ranged"), race_id)
	_use_sidearm(using_sidearm, true)


## Draws the sidearm (true) or goes back to the main weapon.
func _use_sidearm(on: bool, force := false) -> void:
	on = on and not _side.is_empty()
	if on == using_sidearm and not force:
		return
	using_sidearm = on
	_weapon = _side if on else _main
	moveset = _side_moveset if on else _main_moveset
	if visual != null:
		visual.weapon_bone = moveset.weapon_bone()
		visual.set_weapon(ModelRegistry.weapon_model(sidearm_id if on else weapon_id, race_id))
		var shield := ModelRegistry.class_part(race_id, class_id(), "shield")
		visual.set_offhand((shield if shield != "" else ModelRegistry.own(SHIELD)) if parries() else "")


func weapon() -> Dictionary:
	return _weapon


func weapon_class() -> String:
	return GameData.text(_weapon, "weapon_class", "Heavy")


## The pledged god's element.
func element() -> String:
	return GameData.text(_god, "element", "Physical")


func is_dead() -> bool:
	return state == State.DEAD


func is_invulnerable() -> bool:
	return god_mode or (state == State.DODGE and _state_time < GameData.tuning.dodge_iframes) or abilities.invulnerable or race_active.invulnerable


# ---------------------------------------------------------------- frame

func _physics_process(delta: float) -> void:
	var t: CombatTuning = GameData.tuning
	if state == State.DEAD:
		velocity = Vector3.ZERO
		return
	if _thrown_left > 0.0:
		_update_thrown(delta)
		return
	var intent: PlayerIntent = input_source.read() if input_source != null else PlayerIntent.new()
	aiming = aims_with_body() and (using_sidearm or intent.light_held or intent.heavy_held)
	_bull_rush(delta)
	_state_time += delta
	_combo_timer -= delta
	if Combat.now_msec() - _stamina_used_msec > t.stamina_regen_delay * 1000.0:
		stamina = minf(max_stamina, stamina + t.stamina_regen * stats.mult("stamina_regen_pct") * delta)
	stamina_changed.emit(stamina, max_stamina)
	# Out of a fight, wounds heal once you haven't been hit for a moment.
	if not Run.in_fight and health.hp < health.max_hp and Combat.now_msec() - _last_hurt_msec > t.rest_regen_delay * 1000.0:
		health.heal(health.max_hp * t.rest_regen_pct / 100.0 * delta)

	_crosshair = intent.crosshair
	if visual != null:
		# Holding a minion or item, or the Fire Lance's beam, your upper body aims it (user, 2026-11-19).
		var held_aim := state == State.GRAB or abilities.beaming()
		visual.set_aim_pitch(intent.aim_pitch if (aims_with_body() or held_aim) and (mount == null or not mount.riding) else 0.0)
	var move_dir := _world_dir(intent.move, intent.aim_yaw)
	var riding := mount != null and mount.riding
	_update_swimming()
	if swimming:
		# No fighting in deep water: swim to a bank or a bridge.
		intent.light = false
		intent.heavy = false
		intent.dodge = false
		intent.signature = false
		intent.movement = false
		intent.ultimate = false
		intent.race_active = false
		intent.throw_knife = false
		if state in [State.LIGHT, State.HEAVY, State.CAST]:
			_set_state(State.FREE)
	if flying:
		intent.dodge = false  # Ctrl flies down instead
	spying = intent.spyglass_held and not swimming
	# C or the wheel switches to your bow and back; your class keeps its one melee weapon
	# (user, 2026-11-09). Holding an attack is just an attack. Changes between attacks, never mid-swing.
	if state == State.CHAIN:  # the wheel reels the chain in, it doesn't switch weapons
		intent.switch_weapon = false
		intent.sidearm = false
	if intent.sidearm or intent.switch_weapon:
		_sidearm_out = not _sidearm_out
	if state == State.FREE and _sidearm_out != using_sidearm:
		_use_sidearm(_sidearm_out and not swimming)
	var light_now := intent.light
	# Hold light attack to grab (combat feel plan, 2026-11-18): a held click waits grab_hold_time,
	# then grabs a minion in reach or swings; let go sooner and it swings right away.
	if _light_hold >= 0.0:
		light_now = false
		if state not in [State.FREE, State.LIGHT]:
			_light_hold = -1.0
		elif intent.light_held:
			_light_hold += delta
			if _light_hold >= t.grab_hold_time:
				_light_hold = -1.0
				if not _try_grab(intent):
					light_now = true
		else:
			_light_hold = -1.0
			light_now = true
	elif intent.light and intent.light_held and _can_grab() and (state == State.FREE or (state == State.LIGHT and _hit_done)):
		_light_hold = 0.0
		light_now = false
	if mount != null and state == State.FREE and (intent.mount or _mount_hold >= 0.0):
		_mount_key(intent, riding)
	elif intent.dodge and riding:
		pass  # dodge does nothing while riding (user, 2026-11-08): you stay on
	elif intent.dodge and (parries() or (parry_for_all and not intent.dash and not using_sidearm and move_dir.length() < 0.1)):
		if state != State.PARRY and stamina >= t.parry_stamina_cost:
			_start_parry(intent.aim_yaw)
	elif intent.dodge and state != State.DODGE and stamina >= t.dodge_stamina_cost:
		_start_dodge(move_dir if move_dir.length() > 0.1 else -facing)
	elif (state == State.FREE or (state == State.LIGHT and _hit_done)) and not (using_sidearm and bow_left > 0.0):
		if light_now:
			if state == State.LIGHT:
				_queued_light = true
			else:
				_start_light(intent.aim_yaw)
		elif intent.heavy:
			_queued_light = false
			_start_heavy(intent.aim_yaw)
	race_active_held = intent.race_active_held
	if intent.race_active and state == State.FREE:
		race_active.cast()
	_knife_left = maxf(0.0, _knife_left - delta)
	bow_left = maxf(0.0, bow_left - delta)
	if intent.throw_knife and state == State.FREE:
		throw_knife(intent.aim_yaw)
	if state == State.FREE:
		if intent.signature:
			_cast("Signature", intent.aim_yaw, intent.aim_point)  # only a Spikes ability uses the point
		elif intent.movement:
			_cast("Movement", intent.aim_yaw)
		elif intent.ultimate and abilities.ready_in("Ultimate") <= 0.0:
			if intent.ultimate_held and intent.aim_point != Vector3.INF:
				_aiming = true  # hold to aim, release to cast
			else:
				_cast("Ultimate", intent.aim_yaw)
	_update_aim(intent)

	_update_state(delta, intent)
	_move(delta, intent, move_dir)
	_unstick()
	_update_animation()


func _update_state(delta: float, intent: PlayerIntent) -> void:
	var t: CombatTuning = GameData.tuning
	match state:
		State.LIGHT:
			var duration := _light_duration()
			if not _hit_done and _state_time >= duration * t.light_windup_fraction:
				_hit_done = true
				_do_light_hit()
			if _state_time >= duration:
				var finished_combo := _combo_index >= _combo_hits() - 1
				_combo_index = 0 if finished_combo else _combo_index + 1
				_combo_timer = 0.0 if finished_combo else t.combo_window
				_set_state(State.FREE)
				if _queued_light:
					_queued_light = false
					_start_light(intent.aim_yaw)
		State.HEAVY:
			var windup := _heavy_windup()
			if not _hit_done and _state_time >= windup:
				# Held past the windup: charge (stamina) until released, full or out.
				var charging := intent.heavy_held and stamina > 0.0 and heavy_charge < 1.0 and t.heavy_charge_time > 0.0
				if charging:
					heavy_charge = minf(1.0, heavy_charge + delta / t.heavy_charge_time)
					spend_stamina(t.heavy_charge_stamina * delta)
				else:
					_hit_done = true
					_heavy_hit_at = _state_time
					_do_heavy_hit()
			if _hit_done and _state_time >= _heavy_hit_at + _heavy_recovery():
				_set_state(State.FREE)
		State.DODGE:
			if _state_time >= t.dodge_duration:
				collision_mask = 0b101
				_set_state(State.FREE)
		State.CAST:
			if _state_time >= CAST_TIME * _cast_slow and not abilities.beaming():
				_set_state(State.FREE)
		State.PARRY:
			if _state_time >= t.parry_duration:
				_set_state(State.FREE)
		State.GRAB:
			if not grabber.update(delta, intent):
				_set_state(State.FREE)
		State.CHAIN:
			if not chain.update(delta, intent) and state == State.CHAIN:
				_set_state(State.FREE)


## Movement ported from sam-movement (character_body_test.gd): walk/sprint with
## momentum that fades, jumps that scale with speed, a slide that adds speed,
## wall-jumps, crouch, and a hard speed cap. Numbers live in the tuning resource.
## Jumping, sliding and sprinting are only available outside attacks and casts.
func _move(delta: float, intent: PlayerIntent, move_dir: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	var on_floor := is_on_floor()
	if flying:
		var fly := FLY_SPEED * (3.0 if intent.sprint else 1.0)
		velocity = move_dir.normalized() * fly
		velocity.y = fly * 0.7 * (float(intent.jump_held) - float(intent.dodge_held))
		_finish_move(delta)
		return
	if swimming:
		_swim(delta, intent, move_dir)
		return
	if abilities.levitating():  # the Fire ultimate's column holds you up, eased toward its top
		velocity = Vector3(0.0, (abilities.hover_y - global_position.y) * 10.0, 0.0)
		_finish_move(delta)
		velocity.y = 0.0  # you drop from rest when it lets go
		return
	if not on_floor:
		velocity.y -= t.gravity * delta
		if race_id in GLIDERS and _thrown_left <= 0.0:
			velocity.y = maxf(velocity.y, -t.glide_fall_speed)  # a slow glide down
	_wall_jump_timer = maxf(_wall_jump_timer - delta, 0.0)
	var speed_mult := stats.mult("move_speed_pct") * (1.0 - statuses.slow_fraction())
	var h := Vector2(velocity.x, velocity.z)

	if state == State.CHAIN and chain.mode == Chain.Mode.PULL:  # the chain hauls you to a big one
		velocity = chain.pull_velocity()
		_finish_move(delta)
		return
	if state == State.DODGE:
		velocity.x = _dodge_dir.x * t.dodge_speed * stats.mult("dodge_distance_pct")
		velocity.z = _dodge_dir.z * t.dodge_speed * stats.mult("dodge_distance_pct")
		_finish_move(delta)
		return

	var free := state == State.FREE
	var riding := mount != null and mount.riding
	var nimble := free or state in [State.GRAB, State.CHAIN]  # you can jump and slide with something on your hand or chain
	var chained := state == State.CHAIN  # the chain never slows you (user, 2026-11-19)
	var factor := 1.0 if free or chained else (t.attack_move_factor if state in [State.LIGHT, State.CAST] else (t.grab_move_factor if state == State.GRAB else 0.0))
	if riding:
		factor = 1.0 if free or chained else 0.6  # a mount keeps moving while you swing
	var sprinting := intent.sprint and (free or chained or riding) and (riding or _can_sprint())
	if sprinting and not riding and move_dir.length() > 0.1:
		spend_stamina(t.sprint_stamina * delta)
	var skip_update := false

	if riding:
		# A mount jumps (no sliding or wall-jumps), as high as its own jump; some jump again in the air.
		if on_floor:
			_mount_air_jump = true
		if intent.jump and (on_floor or (_mount_air_jump and mount.double_jump())):
			if not on_floor:
				_mount_air_jump = false
			velocity.y = mount.jump_speed() * (t.glide_jump_mult if race_id in GLIDERS else 1.0)
	elif nimble and _jump_now(intent, delta, on_floor):
		# Ground jump, with a small speed boost if it cancels a slide.
		if is_sliding:
			var boosted := minf(h.length() + t.slide_jump_speed_gain, t.max_speed)
			var hd := h.normalized()
			velocity.x = hd.x * boosted
			velocity.z = hd.y * boosted
			skip_update = true
		var current := Vector2(velocity.x, velocity.z).length()
		velocity.y = minf(t.jump_velocity_base + current * t.jump_speed_scale, t.jump_velocity_max) * _jump_power
		if race_id in GLIDERS:
			velocity.y *= t.glide_jump_mult
		is_sliding = false
		is_crouching = false
	elif nimble and intent.jump and not on_floor and is_on_wall() and _wall_jump_timer <= 0.0:
		# Wall jump: launch at 45 degrees off the wall, keeping speed along it.
		var normal := get_wall_normal()
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		var along := horizontal - normal * horizontal.dot(normal)
		var launch := minf(t.jump_velocity_base + horizontal.length() * t.jump_speed_scale, t.jump_velocity_max)
		var component := launch / sqrt(2.0)
		velocity.y = component
		var out := along + normal * component
		velocity.x = out.x
		velocity.z = out.z
		_wall_jump_timer = t.wall_jump_cooldown
		is_sliding = false
		is_crouching = false
		skip_update = true

	if nimble and not riding and intent.slide and on_floor and not is_sliding and not is_crouching:
		if move_dir.length() > 0.0:
			is_sliding = true
			_slide_timer = t.slide_duration_sprint if sprinting else t.slide_duration
			_slide_dir = move_dir.normalized()
			var boosted_speed := minf(h.length() + t.slide_speed_gain, t.max_speed)
			velocity.x = _slide_dir.x * boosted_speed
			velocity.z = _slide_dir.z * boosted_speed
		else:
			is_crouching = true
	if is_crouching and (not intent.slide_held or not on_floor or not free):
		is_crouching = false

	if not skip_update:
		if is_sliding:
			_slide_timer -= delta
			var slide_speed := maxf(Vector2(velocity.x, velocity.z).length() - t.slide_friction * delta, 0.0)
			velocity.x = _slide_dir.x * slide_speed
			velocity.z = _slide_dir.z * slide_speed
			if _slide_timer <= 0.0 or not on_floor or slide_speed <= 0.5:
				is_sliding = false
		elif is_crouching:  # sneaking: slow, and enemies notice you later (Enemy._notice_distance)
			velocity.x = move_dir.x * t.crouch_speed
			velocity.z = move_dir.z * t.crouch_speed
		else:
			var base_speed: float = mount.speed(sprinting) * _road_factor() if riding else (t.sprint_speed if sprinting else t.move_speed)
			var target := base_speed * speed_mult * factor
			var current := Vector2(velocity.x, velocity.z).length()
			if move_dir.length() > 0.0 and factor > 0.0:
				var d := move_dir.normalized()
				# Above target speed (momentum from a slide or wall jump): keep steering, let it fade:
				# quickly on the ground, the way feet grip (user, 2026-11-09: no sliding), slowly in the air.
				var decay := t.ground_friction if on_floor else t.momentum_decay
				var new_speed := maxf(current - decay * delta, target) if current > target else target
				velocity.x = d.x * new_speed
				velocity.z = d.z * new_speed
			elif on_floor:
				# No input on the ground: friction to a stop.
				var hd := Vector2(velocity.x, velocity.z).normalized()
				var slowed := maxf(current - t.ground_friction * delta, 0.0)
				velocity.x = hd.x * slowed
				velocity.z = hd.y * slowed
			# Airborne with no input: keep momentum.

	var cap := Vector2(velocity.x, velocity.z)
	var limit: float = maxf(t.max_speed, mount.speed(true) * speed_mult * 1.1) if riding else t.max_speed
	if cap.length() > limit:
		cap = cap.normalized() * limit
		velocity.x = cap.x
		velocity.z = cap.y
	if (free or riding) and Vector2(velocity.x, velocity.z).length() > 0.5 and move_dir.length() > 0.1:
		var turn := 6.0 if riding else 14.0  # mounts turn wider
		facing = _turn_toward(move_dir, turn * delta)
	if free and not riding and _first_person():
		# First person (user, 2026-11-19): you face where you look and strafe, so a swing lands on what's in view.
		facing = _turn_toward(Vector3(-sin(intent.aim_yaw), 0.0, -cos(intent.aim_yaw)), 20.0 * delta)
	if abilities.beaming():  # the Fire Lance's beam turns with your aim while the legs keep walking
		facing = _turn_toward(Vector3(-sin(intent.aim_yaw), 0.0, -cos(intent.aim_yaw)), 12.0 * delta)
	_finish_move(delta)


func _first_person() -> bool:
	return is_instance_valid(Combat.camera_rig) and Combat.camera_rig.get("first_person") == true and Combat.camera_rig.get("target") == self


## Turns `facing` toward `dir` by the fraction `amount` (works for any turn,
## including a full about-face, which a vector slerp can't do).
func _turn_toward(dir: Vector3, amount: float) -> Vector3:
	var from := atan2(facing.x, facing.z)
	var to := atan2(dir.x, dir.z)
	var a := lerp_angle(from, to, clampf(amount, 0.0, 1.0))
	return Vector3(sin(a), 0.0, cos(a))


func _update_swimming() -> void:
	_surface = Combat.water_surface(global_position)
	if _surface == -INF:
		swimming = false
		return
	var depth := _surface - global_position.y
	if not swimming and depth > SWIM_ENTER:
		swimming = true
		is_sliding = false
		is_crouching = false
	elif swimming and depth < SWIM_EXIT:
		swimming = false


## Floating at the surface, slow strokes toward where you steer. Space hops you
## up a bank. Riding? Your mount swims with you, a little faster.
func _swim(delta: float, intent: PlayerIntent, move_dir: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	var fast := intent.sprint and _can_sprint()
	if fast:
		spend_stamina(t.swim_sprint_stamina * delta)
	var speed := (t.swim_sprint_speed if fast else t.swim_speed) * stats.mult("move_speed_pct")
	if race_id == ValleyTerrain.SWIMMER_RACE:  # the Frogfolk swim as fast as they run (user, 2026-10-29)
		speed = (t.sprint_speed if fast else t.move_speed) * stats.mult("move_speed_pct")
	if mount != null and mount.riding:
		speed *= t.swim_mount_factor
	var target_y := _surface - SWIM_FLOAT
	velocity.y = clampf((target_y - global_position.y) * 4.0, -4.0, 4.0)
	if intent.jump:
		velocity.y = 5.0
	var want := move_dir.normalized() * speed if move_dir.length() > 0.1 else Vector3.ZERO
	# Rapids and deep lakes: a current pushes everyone but the Frogfolk back out.
	var push := Vector2.ZERO
	if Combat.water != null:
		push = Combat.water.current_push(global_position.x, global_position.z, race_id)
	if push == Vector2.ZERO:
		_current = Vector2.ZERO
	elif _current == Vector2.ZERO:
		_current = push
	push = _current
	_blocked_cooldown -= delta
	if push != Vector2.ZERO:
		want = Vector3(push.x, 0.0, push.y) * (speed + 4.0)
		if _blocked_cooldown <= 0.0:
			_blocked_cooldown = 4.0
			water_blocked.emit()
	velocity.x = move_toward(velocity.x, want.x, 12.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 12.0 * delta)
	if move_dir.length() > 0.1:
		facing = _turn_toward(move_dir, 6.0 * delta)
	_finish_move(delta)


## Adds knockback, moves, and turns the body to face `facing`.
## Height of the first solid floor (terrain, bridge, roof) under (x, z), casting
## down from `from_y`; -INF if there is none.
## Your mount died under you: you go limp and fly (a ragdoll), then get up where you land.
func throw_off(impulse: Vector3) -> void:
	if visual == null:
		return
	visual.ignore_ragdoll_cap = true
	if not visual.ragdoll(impulse):
		return
	_set_state(State.FREE)
	_thrown_left = THROWN_TIME


## From `from` to what the crosshair is on. Straight ahead if it's unknown, or behind you
## (the crosshair on something between the camera and you).
## Where a shot from `from` should head to land on the crosshair (user, 2026-11-05: you aim,
## nothing aims for you). A shot that drops (`drop` m/s², arrows) at `speed` m/s is aimed that
## much higher, so it falls onto the point you picked.
## What the crosshair is on (INF: nothing).
func aim_point() -> Vector3:
	return _crosshair


func aim_direction(from: Vector3, speed := 0.0, drop := 0.0) -> Vector3:
	if _crosshair == Vector3.INF or (_crosshair - from).length() < 0.5:
		return facing
	var at := _crosshair
	if drop > 0.0 and speed > 0.0:
		var t := from.distance_to(at) / speed
		at += Vector3.UP * 0.5 * drop * t * t
	var to := (at - from).normalized()
	return to if to.dot(facing) > 0.1 else facing


## How far the bow's shots are sure to hit what the crosshair is on (30 m).
func sure_range() -> float:
	return GameData.tuning.sure_range_bow


## The enemy nearest the crosshair within `cone_deg` and `reach` of `from`, or null.
func sure_target(from: Vector3, cone_deg: float, reach: float) -> Enemy:
	if _crosshair == Vector3.INF or cone_deg <= 0.0:
		return null
	var look := (_crosshair - from).normalized()
	var best: Enemy = null
	var best_angle := deg_to_rad(cone_deg)
	for e in Combat.enemies_in_radius(from, reach):
		var to: Vector3 = e.global_position + Vector3.UP * e.aim_height() - from
		var a := look.angle_to(to)
		if a < best_angle:
			best_angle = a
			best = e
	return best


## Bows, crossbows and spell weapons lean with where you look.
func aims_with_body() -> bool:
	return GameData.text(_weapon, "weapon_class") in GameData.SIDEARM_CLASSES


## Throws your god's homing knife at whoever you're facing most, or straight ahead if no one's near.
func throw_knife(aim_yaw: float) -> bool:
	if _knife_left > 0.0:
		return false
	var t: CombatTuning = GameData.tuning
	_face_yaw(aim_yaw)
	var aim := aim_direction(global_position + Vector3.UP * 1.3)
	var best: Node3D = null
	var best_score := INF
	for e in Combat.enemies_in_radius(global_position, t.knife_range):
		var to: Vector3 = e.global_position - global_position
		var score := to.length() * (2.0 - to.normalized().dot(aim))  # close and near the crosshair
		if score < best_score:
			best_score = score
			best = e
	if HomingKnife.fire(self, best, global_position + Vector3.UP * 1.3 + aim * 18.0) == null:
		return false
	_knife_left = t.knife_cooldown
	_cast_clip = HomingKnife.throw_clip(element())
	_cast_slow = 1.0
	_set_state(State.CAST)
	return true


## Where the camera looks: your limp body while you're flying off a dying mount, otherwise you.
func camera_focus() -> Vector3:
	if _thrown_left > 0.0 and visual != null:
		var hips: PhysicsBody3D = visual.ragdoll_hips()
		if hips != null:
			return hips.global_position - Vector3.UP * 0.9
	if mount != null and mount.riding:  # the view (and the crosshair) rise with the saddle
		return global_position + Vector3.UP * maxf(mount.seat_height() - 1.0, 0.0)
	return global_position


## A hit draws blood, unless you're made of wood.
func bleeds() -> bool:
	return race_id != "treekin"


func _update_thrown(delta: float) -> void:
	_thrown_left -= delta
	velocity = Vector3.ZERO
	if _thrown_left > 0.0:
		return
	var hips: PhysicsBody3D = visual.ragdoll_hips()
	var at := hips.global_position if hips != null else global_position
	visual.unragdoll()
	var ground := floor_below(at.x, at.z, at.y + 3.0)
	global_position = Vector3(at.x, ground + 0.05 if ground != -INF else global_position.y, at.z)
	visual.play("Spawn_Ground", 0.8, true)


func floor_below(x: float, z: float, from_y: float) -> float:
	if not is_inside_tree():
		return -INF
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 200.0, z), 0b001)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if hit else -INF


## Safety net: if anything ever pushes you under the valley's ground, pop back up.
func _unstick() -> void:
	if Combat.water == null or not Combat.water.has_method("height"):
		return
	var ground: float = Combat.water.height(global_position.x, global_position.z)
	if global_position.y < ground - 0.6:
		global_position.y = ground + 0.3
		velocity.y = 0.0


func _finish_move(delta: float) -> void:
	velocity += _knock
	_knock = _knock.move_toward(Vector3.ZERO, GameData.tuning.knockback_friction * delta * 2.0)
	move_and_slide()
	velocity -= _knock
	rotation.y = atan2(-facing.x, -facing.z)
	var body := get_node_or_null("Body") as Node3D
	if body != null:
		var low := 0.6 if (is_sliding or is_crouching) else 1.0
		body.scale.y = lerpf(body.scale.y, low, clampf(12.0 * delta, 0.0, 1.0))


## Roads (ValleyTerrain.roads) are quicker on a mount (user, 2026-11-05).
func _road_factor() -> float:
	var land: Object = Combat.water
	if land != null and land.has_method("near_road") and land.near_road(global_position.x, global_position.z, 1.0):
		return GameData.tuning.road_mount_speed
	return 1.0


## True while sliding or crouching (the camera lowers).
func is_low() -> bool:
	return is_sliding or is_crouching


# ---------------------------------------------------------------- weapon

func _combo_hits() -> int:
	return maxi(1, int(GameData.num(_weapon, "light_combo_hits", 3)))


func _light_duration() -> float:
	var aps := GameData.num(_weapon, "weapon_attacks_per_sec", 1.2)
	# Melee light attacks are light_speed_mult faster (combat feel plan, 2026-11-18); each class keeps
	# its own pace from the sheet (Twin fastest, Heavy slowest).
	var quick: float = 1.0 if using_sidearm else GameData.tuning.light_speed_mult
	return 1.0 / (aps * stats.mult("attack_speed_pct") * moveset.swing_speed() * quick)


## 0..1 while you're charging a heavy (the HUD's charge bar), -1 otherwise.
func charge_shown() -> float:
	return heavy_charge if state == State.HEAVY and not _hit_done and heavy_charge > 0.0 else -1.0


## The heavy's windup and recovery, quicker with a quicker moveset (swords).
func _heavy_windup() -> float:
	return GameData.tuning.heavy_windup / (stats.mult("attack_speed_pct") * moveset.swing_speed())


func _heavy_recovery() -> float:
	return GameData.tuning.heavy_recovery / moveset.swing_speed()


var grabber := Grabber.new(self)
const GRAB_CLAMP := 0.08  ## s from the grab to the hands closing on the minion
var chain := Chain.new(self)


## Where `e` should be while you hold it (in your hand or on the chain), or INF if you don't.
func hold_point_for(e: Node3D) -> Vector3:
	if grabber.held == e:
		return grabber.hold_point()
	return chain.point_for(e)


## A minion the chain reeled in lands in your hand: the hand grab from here on.
func _take_into_hand(e: Node3D) -> void:
	state = State.FREE  # not through _set_state: the chain has already let go
	if e is Enemy and e.health.hp <= _boosted(moveset._base(self), "Physical", _category(), e):
		_punch_apart(e)  # a light hit would kill it: one punch and it bursts (user, 2026-11-19)
		return
	grabber.grab(e)
	_set_state(State.GRAB)


## A reeled-in minion a light hit would kill: you punch it and it bursts apart, chunks and blood.
func _punch_apart(e: Enemy) -> void:
	var t: CombatTuning = GameData.tuning
	if visual != null:
		visual.play_strike("Melee_Unarmed_Attack_Punch_A", 0.05, 0.3)
	var at: Vector3 = e.global_position + Vector3.UP * e.size_scale
	var info := DamageInfo.make(e.health.hp + 1.0, "Physical", DamageInfo.Kind.HEAVY, self)
	info.no_launch = true
	info.hitstop = t.hitstop_heavy
	info.shake = t.shake_heavy
	Combat.deal(e, info)
	e.visible = false  # nothing left of it but the pieces
	var color: Color = Color(0.55, 0.03, 0.04) if e.bleeds() else Color(0.8, 0.78, 0.7)
	for k in 8:
		var out := Vector3(cos(k * TAU / 8.0), 0.6 + 0.3 * (k % 2), sin(k * TAU / 8.0)) + facing
		Vfx.chunk(at, out * 5.0, color, 0.18)
	Vfx.burst(at, 1.3, Color(color, 0.85), 0.2)
	if e.bleeds():
		Vfx.blood(at, facing, t.blood_kill_drops * 3)
		Vfx.blood_stains(e.global_position, facing, t.blood_stains_per_hit * 2, 1.6)
var _light_hold := -1.0  ## seconds light attack has been held since its press (a grab?), -1 = not waiting


## Whether a held light attack may become a grab: your melee weapon out, on foot.
func _can_grab() -> bool:
	return not using_sidearm and not swimming and not (mount != null and mount.riding)


## Grabs the minion in reach, if there is one; else fires the chain at what's in the crosshair.
func _try_grab(intent: PlayerIntent = null) -> bool:
	var e := grabber.target()
	if e is Enemy and (e as Enemy).is_broken():
		_finisher(e)
		return true
	if e == null:
		var far: Node3D = chain.find_target(intent) if intent != null else null
		if far == null:
			return false
		var aim: Vector3 = far.global_position - global_position
		_face_yaw(atan2(-aim.x, -aim.z))
		_set_state(State.CHAIN)
		chain.fire(far)
		if visual != null:  # the arm thrown out and held there while the chain flies and holds
			visual.play_strike("Melee_Unarmed_Attack_Punch_A", 0.06, 0.3, true)
		return true
	var to: Vector3 = e.global_position - global_position
	_face_yaw(atan2(-to.x, -to.z))
	grabber.grab(e)
	_set_state(State.GRAB)
	if visual != null:  # the lunging punch, its hands landing within 0.1 s (the horde puncher's grab)
		visual.play_strike("Melee_Unarmed_Attack_Punch_A", GRAB_CLAMP, GRAB_CLAMP + 0.1)
	return true


func _start_light(aim_yaw: float) -> void:
	if _combo_timer <= 0.0:
		_combo_index = 0
	_face_yaw(aim_yaw)
	_set_state(State.LIGHT)
	_swing_visual(_light_duration() * GameData.tuning.light_windup_fraction, _combo_index % 2 == 0)


func _start_heavy(aim_yaw: float) -> void:
	heavy_charge = 0.0
	_face_yaw(aim_yaw)
	_set_state(State.HEAVY)
	_raise_visual(_heavy_windup())


## The mount key (user, 2026-11-16, after Far Cry Primal): riding, a press gets off. On foot,
## a tap rides (or, after an order, calls it back), a hold sends it away, and a tap through the
## spyglass sends it at the enemy you look at, or to the spot.
func _mount_key(i: PlayerIntent, riding: bool) -> void:
	if riding:
		mount.toggle()
		return
	if i.mount and spying:
		var hud = get_parent().get("hud")
		mount.order(hud.spied if hud != null else null, i.crosshair)
		return
	if i.mount:
		_mount_hold = 0.0
	if i.mount_held:
		_mount_hold += get_physics_process_delta_time()
		if _mount_hold >= MOUNT_HOLD:
			_mount_hold = -1.0
			mount.send_away()
		return
	_mount_hold = -1.0  # let go: a tap
	if mount.has_orders():
		mount.come_back()
	else:
		mount.toggle()


func _do_light_hit() -> void:
	moveset.light_hit(self, _combo_index >= _combo_hits() - 1)


func _do_heavy_hit() -> void:
	if visual != null:
		visual.release_strike()
	moveset.heavy_hit(self)


## Heavy damage multiplier, with the charge.
func heavy_mult() -> float:
	var t: CombatTuning = GameData.tuning
	return t.heavy_multiplier * (1.0 + heavy_charge * t.heavy_charge_bonus)


func _can_sprint() -> bool:
	if stamina <= 0.0:
		winded = true
	elif winded and stamina >= max_stamina * GameData.tuning.sprint_recover_pct / 100.0:
		winded = false
	return not winded


func spend_stamina(amount: float) -> void:
	if no_stamina:
		return  # the arena: no stamina for now (user, 2026-11-19), a pure fight and movement ground
	stamina = maxf(0.0, stamina - amount)
	_stamina_used_msec = Combat.now_msec()


## Deals one swing's damage to every target, then fires its godly gift events:
## first once per enemy ("target" phase), then once for the swing ("swing" phase).
## Used by every weapon moveset.
func hit_targets(targets: Array, base: float, kind: DamageInfo.Kind, knockback: float, knockdown: bool,
		hitstop: float, shake: float, events: Array, impact: Vector3, damage_type := "Physical", explosive := false, god_blast := true, launch := true) -> void:
	if kind == DamageInfo.Kind.HEAVY:  # a charged heavy hits harder and knocks farther (user, 2026-11-05)
		knockback *= 1.0 + heavy_charge * GameData.tuning.heavy_charge_knockback
		if damage_type == "Physical" and god_blast:  # not for thrown bodies and items (user, 2026-11-19)  # your god's explosion where a weapon heavy lands, hit or miss (user, 2026-11-08); a spell's has its own
			ElementFx.area(element(), impact, 2.0)  # yours (fire_explosion.tscn ...) as built, else a burst in its color
	var landed: Array = []
	for e in targets:
		var info := make_hit(base, damage_type, _category(), e, kind)
		info.knockback = knockback
		info.knockdown = knockdown
		info.explosive = explosive
		info.no_launch = not launch
		var away: Vector3 = e.global_position - global_position
		away.y = 0.0
		info.knockback_dir = away.normalized() if away.length() > 0.05 else facing
		info.hitstop = hitstop if landed.is_empty() else 0.0
		info.shake = shake if landed.is_empty() else 0.0
		_after_weapon_hit(e, info, Combat.deal(e, info))
		landed.append(e)
	if landed.is_empty():
		return
	for event in events:
		for e in landed:
			godly_gifts.trigger(event, {"target": e, "position": e.global_position, "phase": "target"})
		godly_gifts.trigger(event, {"target": landed[0], "position": impact, "phase": "swing", "targets": landed})


var _mount_air_jump := true
## Minotaurs charge like a mount (user, 2026-11-05): sprinting flat out on foot they trample
## what's in front (their mount's charge damage and force), and after 2 s at full speed they throw it.
const RUSH_RACES := ["minotaur"]
var _rush_time := 0.0
var _rushed := {}  ## enemy instance id -> seconds before it can be trampled again


func _bull_rush(delta: float) -> void:
	for id in _rushed.keys():
		_rushed[id] -= delta
		if _rushed[id] <= 0.0:
			_rushed.erase(id)
	var t: CombatTuning = GameData.tuning
	var speed := Vector2(velocity.x, velocity.z).length()
	if not race_id in RUSH_RACES or (mount != null and mount.riding) or not is_on_floor() or speed < t.sprint_speed * 0.85:
		_rush_time = 0.0
		return
	_rush_time += delta
	var row: Dictionary = mount.data if mount != null else {}
	for e in enemies_in_arc(Mount.TRAMPLE_RANGE, 50.0):
		if _rushed.has(e.get_instance_id()):
			continue
		_rushed[e.get_instance_id()] = Mount.TRAMPLE_REPEAT
		var info := make_hit(GameData.num(row, "charge_damage", 40.0), "Physical", "Melee", e, DamageInfo.Kind.HEAVY)
		info.knockback = GameData.num(row, "attack_force", 20.0)
		info.knockback_dir = (e.global_position - global_position).normalized()
		info.knockdown = true
		info.no_launch = true
		Combat.deal(e, info)
		if _rush_time >= t.mount_throw_after:
			e.throw(info.knockback_dir * t.mount_throw_speed + Vector3.UP * t.mount_throw_lift, self)
var _jump_charging := false
var _jump_hold := 0.0
var _jump_power := 1.0


## Holding jump jumps higher (user, 2026-11-05): a tap is 100%, held it rises to jump_charge_max
## at jump_charge_time; you jump when you let go (or at the top). True on the tick to jump.
var _jump_tapped := false


func _jump_now(intent: PlayerIntent, delta: float, on_floor: bool) -> bool:
	var t: CombatTuning = GameData.tuning
	if intent.jump and on_floor:
		_jump_charging = true
		_jump_hold = 0.0
		_jump_tapped = false
	if not _jump_charging:
		return false
	if not on_floor:
		_jump_charging = false
		return false
	if not intent.jump_held:
		_jump_tapped = _jump_tapped or _jump_hold < t.jump_crouch_min  # let go during the knee bend: a normal jump
	if (intent.jump_held and _jump_hold < t.jump_charge_time) or _jump_hold < t.jump_crouch_min:
		_jump_hold += delta  # crouched, gathering the jump (a tap still bends the knees for a moment)
		return false
	_jump_charging = false
	_jump_power = 1.0 if _jump_tapped else lerpf(1.0, t.jump_charge_max, clampf(_jump_hold / maxf(t.jump_charge_time, 0.01), 0.0, 1.0))
	return true


## True while you hold an attack with a bow or spell weapon: the crosshair shows and the view narrows.
var aiming := false


## Fires a bow shot.
func fire_projectile(dir: Vector3, speed: float, base: float, kind: DamageInfo.Kind, pierce: int,
		events: Array) -> Projectile:
	var t: CombatTuning = GameData.tuning
	if kind == DamageInfo.Kind.HEAVY:
		speed *= 1.0 + heavy_charge * t.heavy_charge_speed  # a charged shot flies faster
	var info := make_hit(base, "Physical", _category(), null, kind)
	info.knockback = GameData.tuning.knockback_light
	info.hitstop = GameData.tuning.hitstop_light
	var from := global_position + Vector3.UP * 1.3 + dir * 0.6
	# Aim where the crosshair is, up or down too; a shot fired off to the side keeps its angle around that.
	var drop: float = t.missile_gravity if _category() == "Missile" else 0.0
	var shot := aim_direction(from, speed, drop).rotated(Vector3.UP, facing.signed_angle_to(dir, Vector3.UP))
	var sure := sure_target(from, t.aim_cone_missile_deg, sure_range())
	if sure != null and is_equal_approx(facing.signed_angle_to(dir, Vector3.UP), 0.0):
		var at: Vector3 = sure.global_position + Vector3.UP * sure.aim_height()
		var fly := from.distance_to(at) / speed
		shot = (at + Vector3.UP * 0.5 * drop * fly * fly - from).normalized()  # true at the one you aimed at
	var p := Projectile.fire(from, shot, speed, info, Color(1.0, 0.95, 0.7), pierce)
	if p != null:
		p.aimed = true
		p.on_hit = _projectile_hit.bind(events)
		p.drop = drop
		p.lifetime = t.missile_range / speed  # user, 2026-11-05: 75 m
		p.bright = true
		if sure != null:
			p.homing = sure
			p.pull_deg = 720.0  # an arrow at the one in the crosshair can't miss
	if p != null and moveset is WeaponMoveset.Blowgun:  # a dart, not an arrow
		(p._mesh.mesh as BoxMesh).size = Vector3(0.04, 0.04, 0.35)
	if p != null and kind == DamageInfo.Kind.HEAVY and _category() == "Missile":
		var boom := element()  # a heavy arrow or bullet: your god's explosion where it lands (user, 2026-11-08)
		p.on_land = func(at: Vector3) -> void: ElementFx.area(boom, at, 2.0)
	return p


func _projectile_hit(target: Node, info: DamageInfo, dealt: float, events: Array) -> void:
	_after_weapon_hit(target, info, dealt)
	for event in events:
		godly_gifts.trigger(event, {"target": target, "position": target.global_position, "phase": "target"})
		godly_gifts.trigger(event, {"target": target, "position": target.global_position, "phase": "swing", "targets": [target]})


## Lifesteal, the god's on-hit passive and crit godly gifts, for any weapon hit.
func _after_weapon_hit(target: Node, info: DamageInfo, dealt: float) -> void:
	var leech := stats.get_stat("lifesteal_pct")
	if leech > 0.0:
		health.heal(dealt * leech / 100.0)
	_weapon_hits += 1
	_god_passive_on_hit(target)
	if info.is_crit:
		godly_gifts.trigger("on_crit", {"target": target, "position": target.global_position})


## Moves the player by `offset`, stopping at walls (Blade dash-slash).
## A quick dash by `offset` (the sword's heavy), over LUNGE_TIME rather than in one frame
## (playtest 2026-11-08: it looked like a teleport); walls stop it, enemies don't.
const LUNGE_TIME := 0.15
var _lunge_done := 0.0


func lunge(offset: Vector3) -> void:
	_lunge_done = 0.0
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(_lunge_step.bind(offset), 0.0, 1.0, LUNGE_TIME)


func _lunge_step(f: float, offset: Vector3) -> void:
	var mask := collision_mask  # a dodge during the lunge keeps passing through enemies
	collision_mask = 0b001
	move_and_collide(offset * (f - _lunge_done))
	collision_mask = mask
	_lunge_done = f


## Builds outgoing damage with race, god, godly gift and crit modifiers.
## `base` with your damage bonuses for this kind of hit on `target` (no crit).
func _boosted(base: float, damage_type: String, category: String, target: Node) -> float:
	var pct := stats.get_stat("damage_pct") + stats.get_stat(category.to_lower() + "_pct")
	if damage_type == "Physical":
		pct += GameData.num(_god, "dmg_physical_pct")
	elif damage_type == GameData.text(_god, "element"):
		pct += GameData.num(_god, "dmg_element_pct")
	elif damage_type == GameData.text(_god, "weak_element"):
		pct += GameData.num(_god, "weak_element_pct")
	pct += godly_gifts.damage_bonus_pct(target)
	return base * maxf(0.1, 1.0 + pct / 100.0)


func make_hit(base: float, damage_type: String, category: String, target: Node, kind: DamageInfo.Kind) -> DamageInfo:
	var t: CombatTuning = GameData.tuning
	var info := DamageInfo.make(_boosted(base, damage_type, category, target), damage_type, kind, self)
	info.category = category
	if RunRng.chance(t.base_crit_chance + stats.get_stat("crit_chance")):
		info.is_crit = true
		info.amount *= (t.base_crit_damage + stats.get_stat("crit_damage_pct")) / 100.0
	return info


func _category() -> String:
	return GameData.text(_weapon, "attack_category", "Melee")


## God passives that react to weapon hits. Each god gets one entry as it's built.
func _god_passive_on_hit(target: Node) -> void:
	match god_id:
		"forge_god":  # Fire Passive: every 3rd hit sets the target on Fire
			if _weapon_hits % 3 == 0:
				Combat.apply_status(target, "fire", 1, self)


func enemies_in_arc(reach: float, half_angle_deg: float) -> Array:
	var out: Array = []
	var cos_limit := cos(deg_to_rad(half_angle_deg))
	for e in Combat.weapon_targets(global_position, reach):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < 0.8 or to.normalized().dot(facing) >= cos_limit:
			out.append(e)
	return out


# ---------------------------------------------------------------- dodge and abilities

# ---------------------------------------------------------------- arena tactics (user, 2026-11-19)
## The endless arena turns these on: a dodge just as a blow lands slows time and powers up your
## next hits; the dodge key with no direction parries, whatever your weapon.
var perfect_dodge := false
var parry_for_all := false
var no_stamina := false  ## nothing costs stamina
var _perfect_done := false
const PERFECT_DODGE_WINDOW := 0.2  ## s from the dodge's start
const PERFECT_DODGE_SLOW := 0.35   ## real s of slow motion
const PERFECT_DODGE_BONUS := 60.0  ## damage % for PERFECT_DODGE_BUFF s
const PERFECT_DODGE_BUFF := 2.0


func _perfect_dodge() -> void:
	_perfect_done = true
	HitStop.slow(PERFECT_DODGE_SLOW, 0.3)
	stats.add_timed("perfect_dodge", "damage_pct", PERFECT_DODGE_BONUS, PERFECT_DODGE_BUFF)
	Vfx.ring(global_position + Vector3.UP * 0.1, 2.2, Color(0.5, 0.85, 1.0), 0.35)
	_flash(Color(0.55, 0.85, 1.0))
	stamina = minf(max_stamina, stamina + GameData.tuning.dodge_stamina_cost)  # the dodge was free
	Run.note("perfect_dodges", 1)


## A grab on a broken enemy (its gold "!"): finished on the spot, whatever its size.
func _finisher(e: Enemy) -> void:
	var to: Vector3 = e.global_position - global_position
	_face_yaw(atan2(-to.x, -to.z))
	if visual != null:
		visual.play_strike("Melee_Unarmed_Attack_Punch_A", GRAB_CLAMP, GRAB_CLAMP + 0.1)
	HitStop.slow(0.25, 0.25)
	var info := DamageInfo.make(e.health.hp + 1.0, "Physical", DamageInfo.Kind.HEAVY, self)
	info.knockback = GameData.tuning.knockback_heavy
	info.knockback_dir = to.normalized() if to.length() > 0.05 else facing
	info.shake = GameData.tuning.shake_heavy
	Combat.deal(e, info)
	screen_flash(Color(1.0, 0.8, 0.3, 0.35))
	Vfx.ring(e.global_position + Vector3.UP * 0.1, 2.0, Color(1.0, 0.8, 0.25), 0.35)
	health.heal(health.max_hp * 0.05)  # a little back for every finisher
	Run.note("finishers", 1)


func _start_dodge(dir: Vector3) -> void:
	_perfect_done = false
	spend_stamina(GameData.tuning.dodge_stamina_cost)
	_dodge_dir = dir.normalized()
	facing = _dodge_dir
	_queued_light = false
	collision_mask = 0b001  # pass through enemies while dodging
	_set_state(State.DODGE)
	_reset_visual()
	statuses.consume("void")  # dodging shakes off one Void stack
	godly_gifts.trigger("on_dodge", {"position": global_position})


## The Guardian's signature move (DECISIONS 2026-11-16): the dodge key raises the shield
## instead of rolling. Only with the main weapon out: the shield is on the melee arm.
func parries() -> bool:
	return not using_sidearm and class_id() == "Guardian"


## Your class (Barbarian, Guardian, Rogue, Lancer): the main weapon's class_name.
func class_id() -> String:
	return GameData.text(_main, "class_name")


func _start_parry(aim_yaw: float) -> void:
	spend_stamina(GameData.tuning.parry_stamina_cost)
	_face_yaw(aim_yaw)  # the shield faces where you look
	_queued_light = false
	_set_state(State.PARRY)


## Whether the shield turns this hit (called while the shield is up): an enemy's blow or shot,
## from the front, early in the raise.
func _parries_hit(info: DamageInfo) -> bool:
	return info.kind == DamageInfo.Kind.ENEMY and _state_time < GameData.tuning.parry_window \
		and facing.dot(info.knockback_dir) < 0.0


## A parried blow: the attacker reels, and you get a short window of faster, harder light attacks.
func _parry(attacker: Node) -> void:
	var t: CombatTuning = GameData.tuning
	if is_instance_valid(attacker) and attacker.has_method("parried"):
		attacker.parried()
	stats.add_timed("riposte_speed", "attack_speed_pct", t.riposte_speed_pct, t.riposte_time)
	stats.add_timed("riposte_damage", "melee_pct", t.riposte_damage_pct, t.riposte_time)
	_combo_index = 0  # the follow-up starts a fresh combo
	_set_state(State.FREE)  # attack right away
	Combat.shake(t.shake_player_hit * 0.5)
	_flash(Color(1.0, 0.9, 0.5))
	Run.note("parries", 1)


# ---------------------------------------------------------------- aiming the ultimate

var _aiming := false
var _aim_ring: MeshInstance3D


## While the ultimate key is held: a ring shows where it will land; release casts it there.
func _update_aim(intent: PlayerIntent) -> void:
	if not _aiming:
		return
	if is_dead() or swimming or state == State.DODGE or abilities.ready_in("Ultimate") > 0.0:
		_stop_aiming()
		return
	var point := aim_target(intent.aim_point)
	if _aim_ring == null:
		_aim_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.9
		torus.outer_radius = 1.0
		_aim_ring.mesh = torus
		_aim_ring.material_override = Vfx.material(Color(1.0, 0.45, 0.1, 0.8))
		_aim_ring.top_level = true
		add_child(_aim_ring)
	var r := abilities.ultimate_radius()
	_aim_ring.global_position = point + Vector3.UP * 0.15
	_aim_ring.scale = Vector3(r, 1.0, r)
	if intent.ultimate_released or not intent.ultimate_held:
		_stop_aiming()
		if state == State.FREE:
			var to := point - global_position
			_cast("Ultimate", atan2(-to.x, -to.z) if Vector2(to.x, to.z).length() > 0.5 else intent.aim_yaw, point)


func _stop_aiming() -> void:
	_aiming = false
	if _aim_ring != null:
		_aim_ring.queue_free()
		_aim_ring = null


## Where an aimed ultimate lands: the camera's ground point, pulled in to the
## aim range and dropped onto the floor below it.
func aim_target(camera_point: Vector3) -> Vector3:
	var p := camera_point if camera_point != Vector3.INF else global_position + facing * 6.0
	var flat := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
	var reach := abilities.aim_range()
	if flat.length() > reach:
		flat = flat.normalized() * reach
	p = global_position + flat
	var ground := floor_below(p.x, p.z, global_position.y + 30.0)
	p.y = ground if ground != -INF else global_position.y
	return p


func _cast(slot: String, aim_yaw: float, at := Vector3.INF) -> void:
	var t: CombatTuning = GameData.tuning
	var cost: float = {"Signature": t.signature_stamina, "Movement": t.movement_stamina, "Ultimate": t.ultimate_stamina}[slot]
	if stamina < cost:
		return  # too tired to cast (the stamina bar shows it)
	_face_yaw(aim_yaw)
	if abilities.cast(slot, self, facing, at):
		spend_stamina(cost)
		var clip := GameData.text(abilities.defs.get(slot, {}), "animation_name")  # e.g. Fire Lance stabs
		if slot == "Ultimate" and not (visual != null and visual.anim != null and visual.anim.has_animation(clip)):
			clip = "Ranged_Magic_Raise"  # you raise your weapon to open the magic circle (user, 2026-11-10)
		_cast_clip = clip if visual != null and visual.anim != null and visual.anim.has_animation(clip) else "Throw"
		# The Fire Lance's stab 50% slower (user, 2026-11-08), so it reads as a thrust.
		_cast_slow = GameData.tuning.lance_stab_slow if GameData.text(abilities.defs.get(slot, {}), "shape") == "Cone" and slot == "Movement" else 1.0
		if slot == "Ultimate":
			_cast_slow = GameData.tuning.ult_raise_time / CAST_TIME
		_set_state(State.CAST)
		godly_gifts.trigger({"Signature": "on_signature_cast", "Movement": "on_movement_cast", "Ultimate": "on_ultimate_cast"}[slot], {"position": global_position})


# ---------------------------------------------------------------- taking damage

var _last_hurt_msec := -100000


func take_hit(info: DamageInfo) -> float:
	if is_invulnerable():
		if perfect_dodge and state == State.DODGE and _state_time <= PERFECT_DODGE_WINDOW and not _perfect_done \
				and info.kind == DamageInfo.Kind.ENEMY:
			_perfect_dodge()
		return 0.0
	if state == State.GRAB and grabber.shields(info):
		return 0.0  # the minion in your hand takes the blow
	if state == State.PARRY and _parries_hit(info):
		if info.shot:
			_flash(Color(1.0, 0.9, 0.5))  # a blocked arrow: the shooter is untouched, no follow-up
		else:
			_parry(info.source)
		return 0.0
	var amount := info.amount * maxf(0.1, 1.0 - stats.get_stat("armor_pct") / 100.0)
	# Enemy hits, and the poison or burning they leave on you, are scaled down
	# (first playtest: a Witch's poison alone did most of the damage).
	var own := is_instance_valid(info.source) and info.source == self
	if info.kind == DamageInfo.Kind.ENEMY or (info.kind == DamageInfo.Kind.STATUS and not own):
		amount *= GameData.tuning.enemy_damage_scale
	if mount != null and mount.riding and mount.max_hp > 0.0:
		Combat.shake(GameData.tuning.shake_player_hit * 0.5)
		return mount.absorb(amount)  # the mount takes the hit
	if health.fraction() >= LOW_HEALTH:
		_low_health_fired = false  # healed back up: the low-health gift can fire again
	var dealt := health.take(amount)
	if dealt > 0.0:
		Run.note("damage_taken", dealt)
		_last_hurt_msec = Combat.now_msec()
		_knock = info.knockback_dir * info.knockback * 0.5
		Combat.shake(GameData.tuning.shake_player_hit)
		_flash(Color(1, 0.3, 0.3))
		if visual != null and bleeds():
			visual.set_blood(1.0 - health.fraction())  # bloodier with every hit
		godly_gifts.trigger("on_take_damage", {"attacker": info.source, "position": global_position})
		if not _low_health_fired and health.fraction() < LOW_HEALTH:
			_low_health_fired = true
			godly_gifts.trigger("on_low_health", {"position": global_position})
	return dealt


func _on_died() -> void:
	if mount != null and mount.riding:
		mount.dismount()
	_set_state(State.DEAD)
	if visual != null:
		visual.play("Death_A")
	died.emit()


# ---------------------------------------------------------------- helpers

func _set_state(s: State) -> void:
	if state == State.GRAB and s != State.GRAB and grabber.holding():
		grabber.drop()  # a dodge, a hit that ends the grab, death: you let go
	if state == State.CHAIN and s != State.CHAIN:
		chain.cancel()
	if s != State.FREE:
		if s not in [State.GRAB, State.CHAIN]:  # grabbing or chaining keeps your slide going (user, 2026-11-19)
			is_sliding = false
		is_crouching = false
	state = s
	_state_time = 0.0
	_hit_done = false
	if s == State.FREE or s == State.DODGE:
		_reset_visual()


func _face_yaw(aim_yaw: float) -> void:
	facing = Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))


func _world_dir(move: Vector2, aim_yaw: float) -> Vector3:
	var fwd := Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))
	var right := Vector3(cos(aim_yaw), 0.0, -sin(aim_yaw))
	return fwd * move.y + right * move.x


func _build_visuals() -> void:
	if model_scene != null:
		add_child(model_scene.instantiate())
		return
	var m := CharacterModel.new()
	m.name = "Model"
	add_child(m)
	_body = ModelRegistry.for_race(race_id, class_id())
	if m.setup(_body, ModelRegistry.weapon_model(weapon_id, race_id)):
		visual = m
		visual.set_body_layer(CameraRig.BODY_LAYER)  # first person shows only what you hold
		visual.play("Melee_2H_Idle")
		return
	m.queue_free()
	_build_capsule()


## Fallback look (capsule + box hammer) when no model is available.
func _build_capsule() -> void:
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.8
	body.mesh = mesh
	body.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.55, 0.3)
	body.material_override = mat
	body.name = "Body"
	add_child(body)
	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.45, 1.2, 0.0)
	add_child(_weapon_pivot)
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.08, 0.08, 1.1)
	handle.mesh = hm
	handle.position = Vector3(0, 0, -0.55)
	_weapon_pivot.add_child(handle)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.45, 0.3, 0.3)
	head.mesh = head_mesh
	head.position = Vector3(0, 0, -1.1)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.35, 0.33, 0.32)
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 0.4, 0.1)
	head_mat.emission_energy_multiplier = 0.6
	head.material_override = head_mat
	_weapon_pivot.add_child(head)
	_reset_visual()


func _swing_visual(time: float, left_to_right: bool) -> void:
	if visual != null:
		var anims := moveset.light_anims()
		var i := mini(_combo_index, anims.size() - 1)
		if _combo_index >= _combo_hits() - 1:
			i = anims.size() - 1
		# The blow lands on the clip's own strike frame, right when the hit does (reels, 2026-11-18).
		visual.play_strike(anims[i], _light_duration() * GameData.tuning.light_windup_fraction, _light_duration())
		return
	var from := deg_to_rad(70.0 if left_to_right else -70.0)
	_weapon_pivot.rotation = Vector3(deg_to_rad(-20.0), from, 0.0)
	var tw := create_tween()
	tw.tween_property(_weapon_pivot, "rotation:y", -from, maxf(0.05, time))


func _raise_visual(time: float) -> void:
	if visual != null:
		visual.play_strike(moveset.heavy_anim(), time, time + _heavy_recovery(), true)  # waits drawn back while you charge
		return
	var tw := create_tween()
	tw.tween_property(_weapon_pivot, "rotation:x", deg_to_rad(80.0), time * 0.8)
	tw.tween_property(_weapon_pivot, "rotation:x", deg_to_rad(-60.0), time * 0.2)


func _reset_visual() -> void:
	if _weapon_pivot != null:
		_weapon_pivot.rotation = Vector3(deg_to_rad(-30.0), 0.0, 0.0)


## Picks the looping animation for movement states; attacks and dodges start their own.
var trail: SwingTrail  ## the ribbon your melee weapon leaves while it swings (user, 2026-11-18)


func _update_animation() -> void:
	if visual == null:
		return
	if trail == null:
		trail = SwingTrail.new()
		add_child(trail)
	trail.model = visual
	trail.active = state in [State.LIGHT, State.HEAVY] and not using_sidearm
	if trail.active:
		trail.tint(element())
	# The body split (combat feel plan, 2026-11-18): moving during any move, the legs keep walking.
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	var acting := state in [State.LIGHT, State.HEAVY, State.CAST, State.PARRY, State.GRAB] 		or (state == State.CHAIN and chain.mode not in [Chain.Mode.PULL, Chain.Mode.KICK])
	if acting and flat_speed > 0.6 and is_on_floor() and not swimming and not (mount != null and mount.riding):
		visual.set_split(_legs_clip(flat_speed))
	else:
		visual.set_split("")
	match state:
		State.DEAD:
			visual.play("Death_A")
		State.DODGE:
			visual.play("Dodge_Forward", GameData.tuning.dodge_duration)
		State.CAST:
			visual.play(_cast_clip, CAST_CLIP * _cast_slow)
		State.PARRY:
			visual.play("Melee_Block", GameData.tuning.parry_duration)
		State.GRAB:
			if not grabber.throwing() and _state_time > GRAB_CLAMP + 0.1:
				visual.play("Melee_Blocking")  # both arms in front, holding it
		State.CHAIN:
			match chain.mode:
				Chain.Mode.PULL:
					if not chain.kicking():
						visual.play("Jump_Idle")
				Chain.Mode.SWING:
					visual.play("Melee_2H_Attack_Spinning")
		State.FREE:
			var speed := Vector2(velocity.x, velocity.z).length()
			visual.flapping = not is_on_floor() and not swimming and not (mount != null and mount.riding)  # winged races beat their wings
			if mount != null and mount.riding:
				return  # the mount poses the rider
			if swimming:
				visual.play("Walking_B")  # a stand-in stroke until your own swim animation exists
				return
			if _jump_charging and is_on_floor():
				visual.play("Crouching")
			elif is_crouching:
				visual.play("Sneaking" if Vector2(velocity.x, velocity.z).length() > 0.3 else "Crouching")
			elif is_sliding:
				visual.play("Dodge_Forward", 0.6)
			elif not is_on_floor():
				visual.play("Jump_Idle")
			elif speed > GameData.tuning.move_speed * 1.6:
				visual.play("Running_B")
			elif speed > GameData.tuning.move_speed * 0.6:
				visual.play("Running_A")
			elif speed > 0.3:
				visual.play("Walking_A")
			else:
				visual.play(moveset.idle_anim())


## The walk or run the legs play while the upper body acts: backwards when you move away from
## where you face.
func _legs_clip(speed: float) -> String:
	if Vector3(velocity.x, 0.0, velocity.z).normalized().dot(facing) < -0.5:
		return "Walking_Backwards"
	if speed > GameData.tuning.move_speed * 1.6:
		return "Running_B"
	return "Running_A" if speed > GameData.tuning.move_speed * 0.9 else "Walking_A"


## A flash over the whole screen (the crush's red frame).
func screen_flash(color: Color) -> void:
	var hud = get_parent().get("hud") if get_parent() != null else null
	if hud != null and hud.has_method("flash"):
		hud.flash(color)


func _flash(color: Color) -> void:
	if visual != null:
		visual.set_tint(Color(color, 0.55))
		var tw := create_tween()
		tw.tween_method(visual.set_tint, Color(color, 0.55), Color(color, 0.0), 0.2)
		return
	var body := get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var mat := body.material_override as StandardMaterial3D
	var original := Color(0.85, 0.55, 0.3)
	mat.albedo_color = color
	create_tween().tween_property(mat, "albedo_color", original, 0.2)

# ---------------------------------------------------------------- status auras

## A looping effect while a status lasts (burning, frozen, poisoned...).
