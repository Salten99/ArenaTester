extends Node
## Automated tests. Run from the GodsGame folder:
##   tools\run_tests.bat
## or directly:
##   <godot_console.exe> --headless --path game --fixed-fps 60 res://tests/test_main.tscn
## Exit code 0 = all passed.

const ARENA := preload("res://scenes/main.tscn")
const ENDLESS := preload("res://scenes/endless_arena.tscn")

var _failures: Array = []
var _passed := 0
var _arena: Node3D


## Feeds the player pre-planned intents (instead of keyboard input).
class ScriptedInput:
	extends RefCounted
	var queue: Array = []
	var aim_yaw := 0.0

	func press(field: String) -> void:
		var i := PlayerIntent.new()
		i.aim_yaw = aim_yaw
		i.set(field, true)
		queue.append(i)

	## Queues `frames` intents with the given fields set, e.g. {"move": Vector2.UP, "sprint": true}.
	func hold(fields: Dictionary, frames: int) -> void:
		for f in frames:
			var i := PlayerIntent.new()
			i.aim_yaw = aim_yaw
			for k in fields:
				i.set(k, fields[k])
			queue.append(i)

	func read() -> PlayerIntent:
		if queue.is_empty():
			var idle := PlayerIntent.new()
			idle.aim_yaw = aim_yaw
			return idle
		return queue.pop_front()


func _ready() -> void:
	Meta.persist = false
	Playtest.persist = false
	SaveSystem.PROFILE_PATH = "user://test_profile.json"
	await get_tree().process_frame
	var tests := [
		"test_data_loads", "test_data_is_consistent", "test_rng_is_deterministic", "test_damage_pipeline",
		"test_fire_ticks", "test_godly_gift_offer_and_duo", "test_unbuilt_content_is_hidden", "test_dodge_iframes", "test_guardian_parry", "test_minotaur_charge_throws_you",
		"test_searing_strikes_ignites_slam", "test_thunderforged_combo", "test_attack_tokens",
		"test_ability_cast", "test_fire_lance", "test_breakable_props", "test_ranged_shots_can_be_dodged", "test_aimed_ultimate", "test_ultimate_circles", "test_fire_ultimate", "test_stone_eruption", "test_spells", "test_ragdoll_death", "test_performance_40_enemies", "test_wave_and_godly_gift_flow", "test_kiln_heart_on_burning_kill",
		"test_sprint_and_jump", "test_slide_boost_and_crouch", "test_models_and_animations",
		"test_level_ups", "test_one_god_per_race",
		"test_void_mark", "test_all_movesets", "test_weapon_choice", "test_element_effects", "test_controls_rebind", "test_stamina", "test_checklist_viewer", "test_shelved_races", "test_weapons_and_classes", "test_bestiary_and_wings", "test_own_effects", "test_stone_status", "test_race_actives", "test_race_active_fixes", "test_launches_and_ragdolls", "test_top_review_fixes", "test_throw_key_and_weapon_aura", "test_myths", "test_pin_to_wall", "test_aiming", "test_fists_pickups_and_throws", "test_weapon_launch_knocks_on", "test_glide", "test_paired_claws", "test_practice_picks", "test_demon_and_wings", "test_art_checklist", "test_combat_feel", "test_blood_and_falls", "test_end_of_run_exit", "test_audit_fixes", "test_audit_fixes_2", "test_hit_effects", "test_rhythm_and_charge", "test_weapon_and_spell_feel", "test_grab_crush_hurl", "test_chain_grab", "test_throwable_items", "test_body_split", "test_crowd_split", "test_strike_frames", "test_anim_library", "test_endless_waves", "test_kill_reported_once", "test_arena_menu", "test_arena_tactics", "test_grab_aim_and_slams", "test_training_ground", "test_arena_textures", "test_arena_look", "test_mythical_roster", "test_tutorial", "test_bestiary_saved", "test_hitstop_in_slow_motion", "test_test_arena_and_start_menu", "test_element_head", "test_pixelfx_effects", "test_hit_reactions", "test_aim_every_spell", "test_lance_flight_and_shoulder_camera",
	]
	if OS.get_environment("ONLY") != "":  # ONLY=test_mount,test_spells runs just those
		tests = tests.filter(func(name): return name in OS.get_environment("ONLY").split(","))
	for t in tests:
		await _setup()
		var before := _failures.size()
		await call(t)
		print(("PASS  " if _failures.size() == before else "FAIL  ") + t)
		_teardown()
	print("\n%d checks passed, %d failed" % [_passed, _failures.size()])
	for f in _failures:
		print("  - " + f)
	get_tree().quit(1 if _failures.size() > 0 else 0)


# ---------------------------------------------------------------- helpers

func _setup() -> void:
	GameData.tuning.base_crit_chance = 0.0
	GameData.tuning.hitstop_enabled = false
	GameData.tuning.show_damage_numbers = false
	_arena = ARENA.instantiate()
	_arena.auto_start = false
	_arena.run_seed = 1234
	add_child(_arena)
	_arena.player.equip("warhammer")  # most tests swing a warhammer; fists, pickups and throws have their own test
	await _frames(2)
	await _until_on_floor()


## The player starts above the gladiator arena's floor and drops onto it.
func _until_on_floor() -> void:
	for i in 120:
		if _arena.player.is_on_floor():
			return
		await get_tree().physics_frame


func _teardown() -> void:
	get_tree().paused = false
	_arena.queue_free()
	_arena = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failures.append(what)


func _scripted() -> ScriptedInput:
	var s := ScriptedInput.new()
	_arena.player.input_source = s
	return s


## Spawns `count` raiders in a tight cluster `dist` meters in front of the player.
func _cluster(count: int, dist := 2.5, unit := "barb_raider") -> Array:
	var p: Player = _arena.player
	var out: Array = []
	for i in count:
		var e: Enemy = _arena.waves.spawn(unit)
		var angle := TAU * i / count
		e.global_position = p.global_position + Vector3(0, 0, -dist) + Vector3(cos(angle), 0, sin(angle)) * 0.9
		out.append(e)
	return out


# ---------------------------------------------------------------- tests

func test_data_is_consistent() -> void:
	var problems := DataCheck.run()
	check(problems.is_empty(), "spreadsheet cross-references are consistent: %s" % "; ".join(problems))


func test_data_loads() -> void:
	check(GameData.rows("gods").size() == 15 - GameData.SHELVED_GODS.size(), "every god not set aside is loaded")
	check(GameData.rows("races").size() == 20 - GameData.SHELVED_RACES.size(), "every race not set aside is loaded")
	check(GameData.godly_gifts_for("forge_god").size() == 6, "6 forge godly_gifts")
	check(not GameData.status("fire").is_empty(), "fire status exists")
	check(GameData.abilities_for("forge_god").size() == 3, "forge has 3 abilities")
	check(GameData.text(GameData.weapon("warhammer"), "weapon_class") == "Heavy", "the warhammer is a Heavy weapon")
	check(GameData.pickup_weapons().size() == GameData.rows("weapons").size() - 1 and not GameData.FISTS in GameData.pickup_weapons(), "every weapon but your fists can be picked up")


func test_rng_is_deterministic() -> void:
	RunRng.start_run(42)
	var a := [RunRng.randf_range(0, 1), RunRng.randi_range(0, 100), RunRng.chance(50)]
	RunRng.start_run(42)
	var b := [RunRng.randf_range(0, 1), RunRng.randi_range(0, 100), RunRng.chance(50)]
	check(a == b, "same seed gives same rolls")


func test_damage_pipeline() -> void:
	var p: Player = _arena.player
	var e: Enemy = _cluster(1, 2.5, "barb_warlord")[0]
	var cls: Dictionary = p.stats._sources.get("class", {})
	p.stats.set_source("class", {})  # race and god only; classes have their own test
	var info := p.make_hit(22.0, "Physical", "Melee", e, DamageInfo.Kind.LIGHT)
	# Dwarf melee +10%, the Lord of the Forge physical +10% -> 22 * 1.2
	check(is_equal_approx(info.amount, 26.4), "light hit = 22 x 1.2 (got %.2f)" % info.amount)
	var fire := p.make_hit(40.0, "Fire", "Magic", e, DamageInfo.Kind.ABILITY)
	# Dwarf magic +0%, the Lord of the Forge fire +20% -> 40 * 1.2
	check(is_equal_approx(fire.amount, 48.0), "fire ability = 40 x 1.2 (got %.2f)" % fire.amount)
	var hp_before := e.health.hp
	Combat.deal(e, info)
	check(is_equal_approx(e.health.hp, hp_before - 26.4), "damage applied to enemy")
	p.stats.set_source("class", cls)


func test_fire_ticks() -> void:
	var e: Enemy = _cluster(1, 8.0, "barb_warlord")[0]
	var hp := e.health.hp
	Combat.apply_status(e, "fire", 1, _arena.player)
	await _frames(70)  # ~1.17 s: fire ticks every 0.5 s for 4 damage
	check(e.health.hp <= hp - 8.0 and e.health.hp >= hp - 12.0, "fire ticked twice (hp %.1f -> %.1f)" % [hp, e.health.hp])
	await _frames(150)
	check(not e.statuses.has("fire"), "fire expired after its duration")


func test_unbuilt_content_is_hidden() -> void:
	var unbuilt: Array = GodlyGiftManager.unbuilt().map(func(u): return u.id)
	check(not unbuilt.is_empty() and not "forge_masterwork" in unbuilt,
		"godly gifts without code are found (%d), including ones on triggers that never happen (block)" % unbuilt.size())
	var b: GodlyGiftManager = _arena.player.godly_gifts
	var offered_bad := []
	for g in GameData.rows("gods"):
		for i in 25:
			for id in b.make_offer(g.god_id):
				if id in unbuilt:
					offered_bad.append(id)
	check(offered_bad.is_empty(), "a godly gift that does nothing is never offered (offered: %s)" % [offered_bad])
	var s := _fresh_run(61)
	var bad_levels := []
	for i in 60:
		for id in LevelSystem.make_offer(s):
			if not LevelSystem.is_implemented(GameData.row("level_up_options", id)):
				bad_levels.append(id)
	check(bad_levels.is_empty() and not LevelSystem.is_implemented(GameData.row("level_up_options", "magnet")), "level-ups that raise an unread stat are never offered (offered: %s)" % [bad_levels])
	_fresh_run()


func test_godly_gift_offer_and_duo() -> void:
	var b: GodlyGiftManager = _arena.player.godly_gifts
	var offer := b.make_offer("forge_god")
	check(offer.size() == 3, "offer has 3 godly_gifts")
	check(offer.size() == Array(offer).filter(func(id): return offer.count(id) == 1).size(), "offer has no duplicates")
	check(b.available_duos().is_empty(), "no duo before a storm godly_gift")
	b.add_godly_gift("storm_thunderclap")
	check("duo_forge_storm" in b.available_duos(), "the Fire + Lightning duo godly_gift unlocks with a storm godly_gift")
	check(b.add_godly_gift("storm_thunderclap") and b.rank_of("storm_thunderclap") == 2, "taking it again ranks up")


func test_dodge_iframes() -> void:
	var p: Player = _arena.player
	var e: Enemy = _cluster(1, 2.0)[0]
	var far: Enemy = _cluster(1, 8.0)[0]
	var shot := Projectile.fire(p.global_position + Vector3(2, 1, 0), Vector3.RIGHT, 10.0, DamageInfo.make(1.0, "Physical", DamageInfo.Kind.ENEMY, null), Color.WHITE)
	shot.hostile = true
	var s := _scripted()
	s.press("dodge")
	await _frames(2)
	check(p.state == Player.State.DODGE, "dodge started")
	check(e._dash_slowed and not far._dash_slowed, "your dash slows the enemies within dash_slow_radius, not those further off")
	check(shot.dash_slow_until > Engine.get_physics_frames(), "and enemy shots near you")
	var hit := DamageInfo.make(50.0, "Physical", DamageInfo.Kind.ENEMY, null)
	check(p.take_hit(hit) == 0.0, "no damage during i-frames")
	await _frames(30)
	check(p.state == Player.State.FREE, "dodge ended")
	await _frames(6)
	check(not e._dash_slowed, "half a second later they run at full speed again")


func test_minotaur_charge_throws_you() -> void:
	var p: Player = _arena.player
	var start := p.global_position
	var hit := DamageInfo.make(1.0, "Physical", DamageInfo.Kind.ENEMY, null)
	hit.knockback = 12.0
	hit.knockback_dir = Vector3.RIGHT
	hit.knockdown = true
	check(p.take_hit(hit) > 0.0, "the charge lands")
	check(p.velocity.y > 0.0, "a minotaur's charge throws you up")
	await _frames(20)
	check(p.global_position.x - start.x > 2.0, "and well along the way it ran")
	check(absf(p.global_position.z - start.z) < 0.5, "not off to the side")


func test_guardian_parry() -> void:
	# The Guardian's signature move (DECISIONS 2026-11-16): a parry on the dodge key, a shield in the left hand.
	var p: Player = _arena.player
	check(not p.parries(), "other classes still dodge")
	p.equip("greatsword")
	check(p.parries(), "a Guardian parries on the dodge key")
	if p.visual != null:
		check(not p.visual.find_children("Offhand", "BoneAttachment3D", true, false).is_empty(), "the Guardian holds a shield in the left hand")
	var e: Enemy = _cluster(1, 2.0)[0]
	var front := DamageInfo.make(50.0, "Physical", DamageInfo.Kind.ENEMY, e)
	front.knockback_dir = (p.global_position - e.global_position).normalized()
	var s := _scripted()
	s.press("dodge")
	await _frames(2)
	check(p.state == Player.State.PARRY, "the dodge key raises the shield")
	var speed_before := p.stats.get_stat("attack_speed_pct")
	var arrow := DamageInfo.make(50.0, "Physical", DamageInfo.Kind.ENEMY, e)
	arrow.knockback_dir = front.knockback_dir
	arrow.shot = true
	check(p.take_hit(arrow) == 0.0 and p.state == Player.State.PARRY, "an arrow from the front is blocked, the shield stays up")
	check(e.state != Enemy.State.STAGGER and p.stats.get_stat("attack_speed_pct") == speed_before, "a blocked arrow leaves the shooter alone and gives no follow-up")
	check(p.take_hit(front) == 0.0, "a blow from the front, in time, is parried")
	check(e.state == Enemy.State.STAGGER, "the attacker reels")
	check(p.state == Player.State.FREE and p.stats.get_stat("attack_speed_pct") > speed_before, "you can follow up at once, faster")
	var behind := DamageInfo.make(50.0, "Physical", DamageInfo.Kind.ENEMY, e)
	behind.knockback_dir = -front.knockback_dir
	await _frames(int(GameData.tuning.riposte_time * 60.0) + 2)
	s.press("dodge")
	await _frames(2)
	check(p.state == Player.State.PARRY and p.take_hit(behind) > 0.0, "a blow from behind gets past the shield")
	await _frames(int(GameData.tuning.parry_duration * 60.0) + 2)
	s.press("dodge")
	await _frames(int(GameData.tuning.parry_window * 60.0) + 3)
	check(p.state == Player.State.PARRY and p.take_hit(front) > 0.0, "a late parry doesn't stop the blow")
	e.queue_free()


func test_searing_strikes_ignites_slam() -> void:
	var p: Player = _arena.player
	p.godly_gifts.add_godly_gift("forge_searing_strikes")
	var enemies := _cluster(5, 2.5, "barb_warlord")
	var s := _scripted()
	s.press("heavy")
	await _frames(40)
	var burning := enemies.filter(func(e): return is_instance_valid(e) and e.statuses.has("fire")).size()
	check(burning == 5, "heavy slam set all 5 enemies on fire (got %d)" % burning)


## Stamina (user, 2026-10-29): sprinting, charging a heavy attack and casting spend it; it comes back.
func test_stamina() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	var man: Enemy = _cluster(1, 8.0, "barb_raider")[0]
	var wolf: Enemy = _cluster(1, 8.0, "beast_dire_wolf")[0]
	var lord: Enemy = _cluster(1, 8.0, "barb_warlord")[0]
	check(is_equal_approx(man.health.max_hp, 25.0) and is_equal_approx(wolf.health.max_hp, 45.0) and is_equal_approx(lord.health.max_hp, 400.0 * t.humanoid_health_mult),
		"minions keep their sheet health (%.0f, %.0f); a hostile leader gets %d%% more (%.0f)" % [man.health.max_hp, wolf.health.max_hp, roundi(t.humanoid_health_mult * 100 - 100), lord.health.max_hp])
	check(man.health.max_hp <= GameData.num(GameData.row("weapons", "warhammer"), "weapon_base_damage") * 2.0, "a warhammer drops a raider in 1-2 hits")
	man.queue_free()
	lord.queue_free()
	wolf.queue_free()
	var s := _scripted()
	s.hold({"move": Vector2(0, 1), "sprint": true}, 60)
	await _frames(60)
	check(p.stamina < p.max_stamina - t.sprint_stamina * 0.5, "sprinting uses stamina (%.0f left)" % p.stamina)
	await _frames(int((t.stamina_regen_delay + 1.0) * 60))
	check(p.stamina > p.max_stamina * 0.8, "stamina comes back over time (%.0f)" % p.stamina)
	p.stamina = p.max_stamina
	var e: Enemy = _cluster(1, 2.0, "barb_warlord")[0]
	s.press("heavy")
	await _frames(60)
	var quick := e.health.max_hp - e.health.hp
	e.health.hp = e.health.max_hp
	if e.thrown:  # the hammer's launch (combat feel plan) throws it out of reach: stand it back up in front
		e._get_up(e.global_position)
	e.global_position = p.global_position + Vector3(0, 0, -2.0)
	await _frames(2)
	p.stamina = p.max_stamina
	s.hold({"heavy": true, "heavy_held": true}, 1)
	s.hold({"heavy_held": true}, int((t.heavy_windup + t.heavy_charge_time) * 60) + 5)
	await _frames(int((t.heavy_windup + t.heavy_charge_time) * 60) + 40)
	var charged := e.health.max_hp - e.health.hp
	check(charged > quick * 1.5 and p.stamina < p.max_stamina - t.heavy_charge_stamina * 0.5, "a held heavy attack charges: more damage (%.0f vs %.0f), costs stamina" % [charged, quick])
	p.stamina = t.signature_stamina - 1.0
	s.press("signature")
	await _frames(2)
	check(p.state != Player.State.CAST, "too little stamina: the spell doesn't cast")
	p.stamina = p.max_stamina
	s.press("signature")
	await _frames(2)
	check(p.state == Player.State.CAST and p.stamina <= p.max_stamina - t.signature_stamina + 1.0, "casting a spell costs stamina")
	# Out of stamina with Shift held: you walk while it refills, then sprint again.
	await _frames(60)  # the Magma Ball's pull and throw done
	p.stamina = 0.0
	s.hold({"move": Vector2(0, 1), "sprint": true}, 60)
	await _frames(60)
	check(p.winded and p.stamina > 8.0, "holding Shift with no stamina: you walk and it still refills (%.0f)" % p.stamina)


func test_thunderforged_combo() -> void:
	var p: Player = _arena.player
	for id in DebugTools.COMBO_KIT:
		p.godly_gifts.add_godly_gift(id)
	_fire_godly_gift_hits = 0
	Combat.hit_landed.connect(_count_fire_godly_gift_hit)
	_cluster(6, 2.5, "barb_warlord")
	var s := _scripted()
	s.press("heavy")
	await _frames(45)
	Combat.hit_landed.disconnect(_count_fire_godly_gift_hit)
	check(_fire_godly_gift_hits >= 6, "the Fire + Lightning duo godly_gift explosions hit enemies (got %d fire godly_gift hits)" % _fire_godly_gift_hits)


var _fire_godly_gift_hits := 0


func _count_fire_godly_gift_hit(_target: Node, info: DamageInfo, _dealt: float) -> void:
	if info.kind == DamageInfo.Kind.GODLY_GIFT and info.damage_type == "Fire":
		_fire_godly_gift_hits += 1


func test_attack_tokens() -> void:
	var p: Player = _arena.player
	p.god_mode = true
	for i in 12:
		_arena.waves.spawn("barb_raider", p.global_position)
	var most := 0
	for i in 240:
		await get_tree().physics_frame
		most = maxi(most, _arena.director.attackers())
	check(most <= GameData.tuning.max_attackers, "never more than %d attackers (max seen %d)" % [GameData.tuning.max_attackers, most])
	check(most >= 1, "enemies do attack")


## Shooters stop tracking you ranged_aim_lock seconds before they shoot (user,
## 2026-10-29): stand still and you're hit; step aside after the lock and it misses.
func test_ranged_shots_can_be_dodged() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	var out: Array = []
	for step_aside in [false, true]:
		var e: Enemy = _arena.waves.spawn("barb_slinger", p.global_position)
		e.global_position = p.global_position + Vector3(0, 0, -12)
		var start := p.health.hp
		var moved := false
		for i in 360:
			await get_tree().physics_frame
			if step_aside and not moved and e._aim_at != Vector3.INF:
				moved = true
				p.global_position += Vector3(6, 0, 0)
			if p.health.hp < start or (moved and i > 200):
				break
		out.append(p.health.hp < start)
		e.queue_free()
		p.health.heal(99999.0)
		await _frames(2)
	check(out[0], "a slinger's stone hits you when you stand still")
	check(not out[1], "stepping aside after the shooter locks its aim (%.1f s before the shot) makes it miss" % t.ranged_aim_lock)


## Hold the ultimate key to aim (a ring where the camera points), release to cast it there.
func test_aimed_ultimate() -> void:
	var p: Player = _arena.player
	p.abilities.remaining["Ultimate"] = 0.0
	var far := _cluster(3, 14.0, "barb_warlord")   # 14 m ahead: out of reach of a blast around you
	var near := _cluster(3, 2.0, "barb_warlord")
	for e in near:
		e.global_position += Vector3(8, 0, 14)  # off to the side, behind you
	for e in far + near:
		e.freeze(5.0)  # hold still so only the aim decides who is hit
	var target: Vector3 = p.global_position + Vector3(0, 0, -14)
	var s := _scripted()
	s.hold({"ultimate": true, "ultimate_held": true, "aim_point": target}, 1)
	s.hold({"ultimate_held": true, "aim_point": target}, 20)
	await _frames(10)
	check(p._aim_slot == "Ultimate" and p._aim_ring != null and p._aim_ring.global_position.distance_to(target) < 1.0, "holding the ultimate key shows where it will land")
	s.hold({"ultimate_released": true, "aim_point": target}, 1)
	var t: CombatTuning = GameData.tuning
	var lands := maxf(UltimateFx.impact_time(), t.ult_dragon_delay + t.ult_dragon_time)  # the Fire one's dragon takes longer
	await _frames(int(lands * Engine.physics_ticks_per_second) + 15)
	check(p._aim_slot == "" and p.abilities.ready_in("Ultimate") > 0.0, "releasing casts it")
	check(far.all(func(e): return e.health.hp < e.health.max_hp), "the ultimate lands where you aimed")
	check(near.all(func(e): return e.health.hp == e.health.max_hp), "and not around you")
	var way_off := p.aim_target(p.global_position + Vector3(0, 0, -200))
	check(Vector2(way_off.x - p.global_position.x, way_off.z - p.global_position.z).length() <= p.abilities.aim_range() + 0.1, "you can't aim past the ultimate's range")


## Every element's Ultimate (user, 2026-11-10): a magic circle opens over the aimed spot, and the
## element falls from it and deals the ultimate's damage there, not before.
func test_ultimate_circles() -> void:
	var p: Player = _arena.player
	var kept: Dictionary = p.abilities.defs
	for god in ["sun_god"]:  # the plain kind; Fire has its own (test_fire_ultimate), the rest are spells (test_spells)
		p.abilities.load_for(god)
		if god == "sun_god":  # shelved (GameData.SHELVED_GODS): its sheet row by hand
			p.abilities.defs = {"Ultimate": {"ability_id": "sun_high_noon", "slot": "Ultimate", "damage_type": "Light", "base_damage": 120, "radius_m": 8, "status_effect": "light"}}
		var a: Dictionary = p.abilities.defs.Ultimate
		var element := GameData.text(a, "damage_type")
		var enemies := _cluster(3, 12.0, "barb_warlord")
		for e in enemies:
			e.freeze(5.0)
		var spot: Vector3 = p.global_position + Vector3(0, 0, -12)
		check(p.abilities.cast("Ultimate", p, Vector3.FORWARD, spot), "%s ultimate casts" % element)
		await _frames(3)
		var circles := get_tree().get_nodes_in_group("magic_circle")
		check(circles.any(func(c): return Vector2(c.global_position.x - spot.x, c.global_position.z - spot.z).length() < 0.1 and c.global_position.y > spot.y + 3.0),
			"%s ultimate opens a magic circle in the sky over the aimed spot" % element)
		var hurt := func(): return enemies.filter(func(e): return e.health.hp < e.health.max_hp or e.statuses.has(GameData.text(a, "status_effect"))).size()
		check(hurt.call() == 0, "%s ultimate hasn't struck yet while the circle opens" % element)
		await _frames(int(UltimateFx.impact_time() * Engine.physics_ticks_per_second) + 6)
		check(hurt.call() > 0, "%s ultimate strikes the aimed spot (%d of 3 hit)" % [element, hurt.call()])
		for e in enemies:
			e.queue_free()
	p.abilities.defs = kept
	await _frames(int(GameData.tuning.ult_tail_time * Engine.physics_ticks_per_second) + 30)
	check(get_tree().get_nodes_in_group("magic_circle").is_empty(), "the circles close afterwards")


## The Fire ultimate (user, 2026-11-20): five magic circles open in an arc over your head, a flame
## dragon pours out of them, snakes through the air and dives into the aimed spot; the ground burns.
func test_fire_ultimate() -> void:
	var p: Player = _arena.player
	var kept: Dictionary = p.abilities.defs
	var hz := Engine.physics_ticks_per_second
	p.abilities.load_for("forge_god")
	p.abilities.remaining["Ultimate"] = 0.0
	var enemies := _cluster(3, 12.0, "barb_warlord")
	for e in enemies:
		e.freeze(8.0)
	var t: CombatTuning = GameData.tuning
	var spot: Vector3 = p.global_position + Vector3(0, 0, -12)
	var lifted: Vector3 = p.global_position + Vector3.UP * t.ult_lift_height  # where you'll hang
	# The dragons' ways are random (visual only, the global RNG): seeded, the test sees the same five
	# flights every run. Unseeded, a fast one (ult_dragon_land_spread) could already be diving low.
	seed(7)
	check(p.abilities.cast("Ultimate", p, Vector3.FORWARD, spot), "the Fire ultimate casts")
	randomize()
	await _frames(int(t.ult_arc_gap * 2.0 * hz) + 4)
	var over := get_tree().get_nodes_in_group("magic_circle").filter(func(c):
		var to: Vector3 = c.global_position - lifted
		return to.y > -0.5 and to.length() < 7.0)  # the outer two sit out beside you (user, 2026-11-20)
	check(over.size() == 5, "five magic circles open in an arc round your head (%d)" % over.size())
	var heights: Array = over.map(func(c): return c.global_position.y - lifted.y)
	heights.sort()
	check(heights.size() == 5 and heights[4] > 3.0 and heights[0] < heights[4] - 1.0, "arching up over it, the middle one highest")
	check(enemies.all(func(e): return e.health.hp == e.health.max_hp), "nothing is hit yet")
	await _frames(int(t.ult_lift_time * hz) + 2)
	check(p.global_position.y > lifted.y - 0.5 and p.abilities.levitating(), "you rise %.0f m off the ground (%.1f)" % [t.ult_lift_height, p.global_position.y - spot.y])
	await _frames(int((t.ult_dragon_delay + t.ult_dragon_time * 0.5 - t.ult_lift_time) * hz))
	var dragons: Array = get_tree().get_nodes_in_group("fire_dragons")
	check(dragons.size() == 5, "a flame dragon out of each circle (%d)" % dragons.size())
	var flying := dragons.filter(func(d): return d.pieces[0].visible and d.pieces[0].global_position.y > spot.y + 1.0)  # each at its own pace
	check(flying.size() == 5, "all five snake through the air (%d)" % flying.size())
	check(dragons.all(func(d): return d.pieces.size() == t.ult_dragon_segments), "each with a long body behind its head")
	var lands: Array = dragons.map(func(d): return d.p3)
	check(lands.count(spot) == 1 and lands.all(func(l): return Vector2(l.x - spot.x, l.z - spot.z).length() <= p.abilities.ultimate_radius() * t.ult_dragon_land_scatter + 0.01) and lands[0] != lands[1],
		"the middle one dives into the aimed spot, the others scatter round it")
	var pushes: Array = range(20).map(func(_n): return p.abilities._wander(t.ult_dragon_wander))
	check(pushes.all(func(v): return absf(v.x) <= t.ult_dragon_wander and v.y >= -t.ult_dragon_wander * 0.4) and pushes[0] != pushes[1], "each dragon's way there is random, within ult_dragon_wander")
	var ways: Array = range(200).map(func(_n): return p.abilities._any_way(-1.0))
	check(ways.all(func(v): return is_equal_approx(v.length(), 1.0)) and ways.any(func(v): return v.y < -0.5) and ways.any(func(v): return v.x < -0.5) and ways.any(func(v): return v.z > 0.5),
		"a dragon can leave its circle any way at all, not just up")
	check(dragons.all(func(d): return d.p1.y >= spot.y + t.ult_dragon_floor - 0.01 and d.p2.y >= spot.y + t.ult_dragon_floor - 0.01), "and its path stays off the ground")
	check(dragons.all(func(d): return d.duration <= t.ult_lift_time + t.ult_dragon_time + 0.3) and dragons.any(func(d): return not is_equal_approx(d.duration, t.ult_dragon_time)),
		"they land at different times, all before the spell ends")
	var paces: Array = range(11).map(func(j): return dragons[0].u_for(j / 10.0))
	check(paces[0] == 0.0 and paces[10] == 1.0 and range(10).all(func(j): return paces[j + 1] > paces[j]) and paces != range(11).map(func(j): return j / 10.0),
		"its pace changes with the bends of its curve, still from the circle to the ground (%s)" % str(paces))
	await _frames(int(t.ult_dragon_time * 0.6 * hz) + 4)
	check(enemies.all(func(e): return e.health.hp < e.health.max_hp), "it dives into the aimed spot, hitting everything there")
	var fires := get_tree().get_nodes_in_group("hazards").filter(func(h): return Vector2(h.global_position.x - spot.x, h.global_position.z - spot.z).length() < 1.0)
	check(fires.size() == 1, "and the ground burns there")
	await _frames(int(t.ult_dragon_time * hz) + 40)
	check(get_tree().get_nodes_in_group("fire_dragons").is_empty(), "then their tails pour into the ground and they're gone")
	check(not p.abilities.levitating() and p.global_position.y < spot.y + 0.5, "and you come back down")
	for e in enemies:
		e.queue_free()
	p.abilities.defs = kept
	await _frames(int(t.ult_dragon_time * hz) + 40)
	check(get_tree().get_nodes_in_group("magic_circle").is_empty(), "the circles close afterwards")


## The Stone special (user, 2026-11-16): a circle on the aimed ground, then spikes erupt there:
## the ones they kill hang impaled, the rest fly outward.
func test_stone_eruption() -> void:
	var p: Player = _arena.player
	var kept: Dictionary = p.abilities.defs
	p.abilities.load_for("animal_god")
	check(GameData.text(p.abilities.defs.Signature, "shape") == "Spikes", "the Stone special is a Spikes ability")
	var weak: Enemy = _cluster(1, 10.0)[0]
	var tough: Enemy = _cluster(1, 10.0, "barb_warlord")[0]
	var bystander: Enemy = _cluster(1, 3.0)[0]
	var spot: Vector3 = p.global_position + Vector3(0, 0, -10)
	weak.global_position = spot + Vector3(1.0, 0, 0)
	tough.global_position = spot + Vector3(-1.5, 0, 0)
	for e in [weak, tough, bystander]:
		e.freeze(5.0)
	weak.health.hp = 1.0
	tough.health.hp = tough.health.max_hp
	var tough_from: Vector3 = tough.global_position
	check(p.abilities.cast("Signature", p, Vector3.FORWARD, spot), "the Stone special casts")
	await _frames(3)
	check(get_tree().get_nodes_in_group("magic_circle").any(func(c): return c.global_position.distance_to(spot) < 0.5), "a magic circle opens on the aimed ground")
	check(tough.health.hp == tough.health.max_hp, "nothing is hit before the spikes come up")
	await _frames(int(GameData.tuning.erupt_delay * Engine.physics_ticks_per_second) + 10)
	check(weak.is_dead() and weak._pinned and weak.global_position.y > spot.y + 0.5, "an enemy it kills hangs up on a spike")
	check(tough.health.hp < tough.health.max_hp, "the spikes hurt the others")
	await _frames(20)
	var out := Vector2(tough.global_position.x - spot.x, tough.global_position.z - spot.z).length()
	check(out > Vector2(tough_from.x - spot.x, tough_from.z - spot.z).length() + 0.5, "and hurl them outward (%.1f m from the middle)" % out)
	check(bystander.health.hp == bystander.health.max_hp, "it erupts where you aimed, not around you")
	var far := p.abilities._erupt_spot(p, Vector3.FORWARD, p.global_position + Vector3(0, 0, -200), 14.0)
	check(Vector2(far.x - p.global_position.x, far.z - p.global_position.z).length() <= 14.1, "you can't aim it past its range")
	for e in [weak, tough, bystander]:
		if is_instance_valid(e):
			e.queue_free()
	p.abilities.defs = kept


func _hurt(es: Array) -> int:
	return es.filter(func(e): return is_instance_valid(e) and e.health.hp < e.health.max_hp).size()


func _free_all(es: Array) -> void:
	for e in es:
		if is_instance_valid(e):
			e.queue_free()


## A tough enemy standing `offset` from the player.
func _dummy(offset: Vector3, hold := true) -> Enemy:
	var e: Enemy = _arena.waves.spawn("barb_warlord")
	e.global_position = _arena.player.global_position + offset
	if hold:
		e.freeze(20.0)
	return e


## The arena's spells (Arena Magic Attacks sheet, user 2026-11-20; spells.gd): each one hits where
## its design says and not elsewhere.
func test_spells() -> void:
	var p: Player = _arena.player
	var kept: Dictionary = p.abilities.defs
	var t: CombatTuning = GameData.tuning
	var hz := Engine.physics_ticks_per_second
	var home: Vector3 = p.global_position
	var saved := [t.cage_time, t.ice_snake_time]
	t.cage_time = 1.5
	t.ice_snake_time = 1.0

	# Magma Ball (Fire Q, user 2026-11-20): hold Q to aim, let go: you pull a ball of magma out of the
	# ground and hurl it at the aimed spot.
	p.abilities.load_for("forge_god")
	var aimed: Vector3 = home + Vector3(4, 0, -10)
	var hit_one := _dummy(aimed - home)
	var missed := _dummy(Vector3(0, 0, -4))
	var s := _scripted()
	s.hold({"signature": true, "signature_held": true, "aim_point": aimed}, 1)
	s.hold({"signature_held": true, "aim_point": aimed}, 30)
	s.hold({"aim_point": aimed}, 1)
	await _frames(20)
	check(p._aim_slot == "Signature" and p._aim_ring != null and Vector2(p._aim_ring.global_position.x - aimed.x, p._aim_ring.global_position.z - aimed.z).length() < 0.5,
		"holding Q shows a circle on the ground where it will land, as long as you hold it")
	check(p.state == Player.State.FREE and p.abilities.ready_in("Signature") == 0.0, "nothing is cast while you aim")
	await _frames(int((t.magma_pull_time * 0.8) * hz) + 12)
	check(p.state == Player.State.CAST and p.abilities.spells.holding_magma(), "letting go: you reach down and pull out a ball of magma")
	check(p.crosshair_shown(), "the crosshair shows while you hold it")
	await _frames(int((t.magma_pull_time + t.magma_hold_time + t.magma_throw_windup + 0.6) * hz))
	check(hit_one.health.hp < hit_one.health.max_hp and missed.health.hp == missed.health.max_hp, "and hurl it where you aimed: it bursts there")
	check(not p.abilities.spells.holding_magma(), "and it's gone")
	_free_all([hit_one, missed])
	p.input_source = null
	p.global_position = home

	# Ring of Ice: icicles all round you; what they hit is frozen.
	p.abilities.load_for("snow_god")
	var ring := [_dummy(Vector3(0, 0, -2.5), false), _dummy(Vector3(0, 0, 2.5), false)]
	p.abilities.cast("Signature", p, Vector3.FORWARD)
	await _frames(int((t.spell_release_delay + 0.8) * hz) + 6)  # the rings, then the freeze once they are thrown
	check(_hurt(ring) == 2, "Ring of Ice hits in front and behind (%d of 2)" % _hurt(ring))
	check(ring.any(func(e): return e.state == Enemy.State.FROZEN), "Ring of Ice freezes what it hits")
	_free_all(ring)

	# Ice Slide: you slide range_m forward and leave ice that slows.
	var before := get_tree().get_nodes_in_group("hazards").size()
	var start: Vector3 = p.global_position
	p.abilities.cast("Movement", p, Vector3.FORWARD)
	await _frames(int(t.slide_time * hz) + 4)
	check(start.z - p.global_position.z > 7.0, "Ice Slide carries you forward (%.1f m)" % (start.z - p.global_position.z))
	check(get_tree().get_nodes_in_group("hazards").size() >= before + 4, "and leaves a trail of ice")
	var skater := _dummy(start - p.global_position + Vector3(0, 0, -4), false)
	await _frames(40)
	check(skater.statuses.has("ice"), "the trail slows whoever stands on it")
	_free_all([skater])
	p.global_position = home

	# Ice Snake: you ride a giant ice snake; what it touches freezes, what it kills shatters.
	p.facing = Vector3.RIGHT  # off the Ice Slide's trail
	var cold := _dummy(Vector3(4, 0, 0), false)
	var weak := _dummy(Vector3(7, 0, 0.5), false)
	weak.health.hp = 1.0
	var lift: float = p.global_position.y
	var steer := _scripted()
	steer.aim_yaw = -PI * 0.5  # looking right: it flies right
	p.abilities.cast("Ultimate", p, Vector3.RIGHT)
	for i in int(0.6 * hz):
		get_tree().paused = false  # a kill can open a level-up choice
		await _frames(1)
	check(p.abilities.spells.riding() and p.is_invulnerable() and p.global_position.y > lift + 1.0, "the Ice Snake lifts you up and carries you")
	check(p.global_position.x - home.x > 4.0, "it keeps going without input (%.1f m)" % (p.global_position.x - home.x))
	check(cold.state == Enemy.State.FROZEN and cold.health.hp < cold.health.max_hp, "what it touches is hurt and frozen")
	check(weak.is_dead() and not weak.visible, "what it kills shatters")
	for i in int(0.6 * hz):
		get_tree().paused = false
		await _frames(1)
	check(not p.abilities.spells.riding() and not p.is_invulnerable(), "after its time it's gone and you drop")
	_free_all([cold, weak])
	p.global_position = home
	# A click while riding breathes icicles: what they hit flies back and is pinned to the wall behind.
	var wall := StaticBody3D.new()
	var wall_box := CollisionShape3D.new()
	wall_box.shape = BoxShape3D.new()
	wall_box.shape.size = Vector3(1.0, 12.0, 30.0)
	wall.add_child(wall_box)
	wall.collision_layer = 0b001
	_arena.add_child(wall)
	wall.global_position = home + Vector3(16, 4, 0)
	var target := _dummy(Vector3(10, 0, 0), false)
	target.health.setup(9999.0)
	p.abilities.remaining["Ultimate"] = 0.0
	p.abilities.cast("Ultimate", p, Vector3.RIGHT)
	await _frames(int(0.15 * hz))
	steer.hold({"light": true, "aim_pitch": -0.08}, 1)
	for i in int(0.8 * hz):
		get_tree().paused = false
		await _frames(1)
		if target._pinned:
			break
	check(target._pinned and target.health.hp < 9999.0, "the snake's icicle breath knocks it back and pins it to the wall")
	check(target.global_position.x - home.x > 12.0, "back against the wall (%.1f m)" % (target.global_position.x - home.x))
	for i in int(1.0 * hz):
		get_tree().paused = false
		await _frames(1)
	_free_all([target, wall])
	p.input_source = null
	p.global_position = home

	# Thunder Crash and Bolt Fan: in front, not behind.
	p.abilities.load_for("storm_god")
	var ahead := _dummy(Vector3(0, 0, -4))
	var behind := _dummy(Vector3(0, 0, 5))
	p.abilities.cast("Signature", p, Vector3.FORWARD)
	await _frames(int(t.spell_release_delay * hz) + 6)
	check(ahead.health.hp < ahead.health.max_hp and behind.health.hp == behind.health.max_hp, "Thunder Crash strikes ahead of you")
	_free_all([ahead, behind])
	# Lightning Beam (E, user 2026-11-20): lunges and fires like the Fire Lance, from a circle before your chest, for lightning_beam_time.
	var cast_from: Vector3 = p.global_position
	p.facing = Vector3.FORWARD
	var line := [_dummy(Vector3(0, 0, -6)), _dummy(Vector3(0, 0, -25))]
	var off := [_dummy(Vector3(0, 0, 5)), _dummy(Vector3(6, 0, -4))]
	p.abilities.cast("Movement", p, Vector3.FORWARD)
	await _frames(int(AbilityRunner.LUNGE_TIME * hz) + 4)
	check(p.abilities.beaming() and _hurt(line) == 2 and _hurt(off) == 0, "Lightning Beam strikes all along the line ahead, nothing behind or beside (%d of 2)" % _hurt(line))
	check(cast_from.distance_to(p.global_position) > t.lance_lunge_m - 0.5, "it lunges you forward like the Fire Lance")
	var chest: Vector3 = p.abilities._beam_from({}, p, p.facing)
	check(get_tree().get_nodes_in_group("magic_circle").any(func(c): return c.global_position.distance_to(chest) < 0.5), "it fires from a magic circle before your chest")
	await _frames(int(t.lightning_beam_time * hz) + 4)
	check(not p.abilities.beaming(), "and stops after %.1f s" % t.lightning_beam_time)
	_free_all(line + off)

	# Kaminari (user, 2026-11-20): press R once and you fly up; click to place its pillars (large
	# lightning bolts) where you aim, within cage_place_time; then bolts bounce between them, each
	# carried by a lightning hawk, and who's inside is caught.
	var spot: Vector3 = p.global_position + Vector3(0, 0, -12)
	var caged := [_dummy(Vector3(0, 0, -12)), _dummy(Vector3(1, 0, -13))]
	var y0: float = p.global_position.y
	var def: Dictionary = p.abilities.defs.Ultimate
	var places: Array = []
	for i in t.cage_pillars:
		places.append(spot + UltimateFx._around(i, t.cage_pillars, 5.0))
	var keys := _scripted()
	keys.hold({"ultimate": true, "ultimate_held": true, "aim_point": places[0]}, 1)
	keys.hold({"aim_point": places[0]}, 4)
	keys.hold({"light": true, "light_held": true, "aim_point": places[0]}, 1)
	keys.hold({"aim_point": places[1]}, 4)
	keys.hold({"light": true, "light_held": true, "aim_point": places[1]}, 1)
	keys.hold({"aim_point": places[1]}, 30)
	await _frames(14)
	check(p.abilities.spells.placing() and p.abilities.spells.pillars_placed() == 2 and p.abilities.ready_in("Ultimate") == 0.0,
		"press R once, then each click places a pillar where you aim, not an attack (%d)" % p.abilities.spells.pillars_placed())
	check(p.state == Player.State.CAST and p._cast_clip == "Throw" and p.facing.dot((places[1] - p.global_position) * Vector3(1, 0, 1)) > 0.0,
		"each click throws the bolt, turned toward it")
	check(p._aim_ring != null, "a ring shows where the next goes")
	await _frames(20)
	check(p.global_position.y > y0 + 1.0, "you fly up while you place them")
	var pillar: MeshInstance3D = p.abilities.spells._placing.glows[0]
	check(pillar.mesh is QuadMesh and (pillar.mesh as QuadMesh).size.y == t.cage_pillar_height and (pillar.material_override as StandardMaterial3D).albedo_texture != null,
		"each pillar is a large lightning bolt, your bolt pictures")
	p.input_source = null
	for i in range(2, t.cage_pillars - 1):
		check(p.abilities.spells.place_pillar(places[i]), "pillar %d placed" % (i + 1))
	check(not p.abilities.spells.place_pillar(places[-1]), "the last one casts it")
	p.abilities.cast("Ultimate", p, Vector3.FORWARD, places[-1])
	await _frames(3)
	check(p.abilities.spells.caging() and not p.abilities.spells.placing() and p.abilities.ready_in("Ultimate") > 0.0, "then Kaminari starts, and its cooldown")
	var cage: Dictionary = p.abilities.spells._cages[0]
	check(cage.pillars.size() == t.cage_pillars and cage.pillars.all(func(q: Vector3) -> bool: return places.any(func(w: Vector3) -> bool: return w.distance_to(q) < 0.1)),
		"its pillars stand where you placed them")
	check(caged.all(func(e): return cage.trapped.has(e)) and cage.bolts.size() >= t.cage_pillars, "who's inside is caught, and bolts already bounce off every pillar (%d)" % cage.bolts.size())
	check(cage.bolts.all(func(b): return b.hawk != null), "each bolt is carried by a lightning hawk, %.0f m across" % t.cage_hawk_size)
	await _frames(10)
	var flier: Dictionary = cage.bolts[1]
	var headed: Vector3 = (cage.pillars[flier.to] as Vector3) + Vector3.UP * 1.2 - flier.hawk.global_position
	check((-flier.hawk.global_basis.z).normalized().dot(headed.normalized()) > 0.5, "the hawk flies at the pillar it's headed for")
	caged[0].global_position = spot + Vector3(0, 0, -15)  # knocked out of it
	await _frames(2)
	check(Vector2(caged[0].global_position.x - spot.x, caged[0].global_position.z - spot.z).length() < 6.0, "a caught one can't leave the pillars")
	check(cage.bolts.size() == 3 and t.cage_max_bolts == 3, "three hawks in all, however often they bounce (%d)" % cage.bolts.size())
	await _frames(int(t.ult_lift_time * hz) + 10)
	check(p.global_position.y > y0 + t.cage_lift_height - 1.0, "you float %.0f m up while it lasts (%.1f)" % [t.cage_lift_height, p.global_position.y - y0])
	var after_first: float = caged[1].health.hp
	await _frames(int(t.cage_time * hz) + 6)
	check(not p.abilities.spells.caging() and _hurt(caged) == 2, "Kaminari strikes what's inside, then collapses (%d of 2)" % _hurt(caged))
	check(caged[1].health.hp < after_first, "caught ones are struck again and again")
	_free_all(caged)
	await _frames(int(2.0 * hz))  # back down
	# Out of time (cage_place_time): the rest stand at random round the ones placed, and it starts.
	var place_time := t.cage_place_time
	t.cage_place_time = 0.5
	p.abilities.remaining.erase("Ultimate")
	p.abilities.spells.begin_placing(def, p)
	p.abilities.spells.place_pillar(places[0])
	p.abilities.spells.place_pillar(places[2])
	await _frames(int(0.5 * hz) + 5)
	var filled: Array = p.abilities.spells._cages[0].pillars if p.abilities.spells.caging() else []
	var mid: Vector3 = (places[0] + places[2]) * 0.5
	var radius := GameData.num(def, "radius_m")
	check(filled.size() == t.cage_pillars and p.abilities.ready_in("Ultimate") > 0.0
		and filled.slice(2).all(func(q: Vector3) -> bool: return absf(Vector2(q.x - mid.x, q.z - mid.z).length() - radius) <= radius * 0.35),
		"out of time, the rest stand round a circle about the placed ones, and it starts")
	await _frames(int(t.cage_time * hz) + 6)
	t.cage_place_time = place_time
	p.abilities.remaining.erase("Ultimate")
	p.abilities.cast("Ultimate", p, Vector3.FORWARD, spot)  # not aimed (scripted): they stand round the spot
	await _frames(2)
	check(p.abilities.spells.caging() and p.abilities.spells._cages[0].pillars.size() == t.cage_pillars, "cast without placing, its pillars stand round the spot")
	await _frames(int(t.cage_time * hz) + 6)
	await _frames(int(2.0 * hz))  # back down before the next spell

	# Stone Slab: launches what's in front.
	p.abilities.load_for("animal_god")
	var slabbed := _dummy(Vector3(0, 0, -3))
	var safe := _dummy(Vector3(0, 0, 3))
	p.abilities.cast("Movement", p, Vector3.FORWARD)
	await _frames(int(t.spell_release_delay * hz) + 6)
	check(slabbed.health.hp < slabbed.health.max_hp and safe.health.hp == safe.health.max_hp, "Stone Slab erupts in front of you")
	for kind in p.abilities.spells.SLAB_SHAPES:
		var shape: Node3D = p.abilities.spells._slab_shape(kind)
		check(not shape.find_children("*", "MeshInstance3D", true, false).is_empty(), "Stone Slab can come up as a stone %s" % kind.to_lower())
		shape.free()
	_free_all([slabbed, safe])
	p.abilities.remaining["Movement"] = 0.0
	var hp_before: float = p.health.hp
	p.abilities.cast("Movement", p, Vector3.FORWARD, p.global_position)
	await _frames(int(t.spell_release_delay * hz) + 6)
	check(p.velocity.y > 0.0 and p.health.hp == hp_before, "cast under you, Stone Slab throws you up unhurt (%.1f m/s)" % p.velocity.y)
	await _frames(int(2.5 * hz))  # back down before the next spell

	# Crushing Pillars: two circles, then the pillars meet on the aimed spot.
	var crushed := _dummy(Vector3(0, 0, -12))
	var away := _dummy(Vector3(0, 0, -24))
	p.abilities.cast("Ultimate", p, Vector3.FORWARD, spot)
	await _frames(3)
	check(get_tree().get_nodes_in_group("magic_circle").filter(func(c): return c.global_position.distance_to(spot) < 2.0 * t.ram_size + 3.0).size() >= 2, "Crushing Pillars opens two circles at the aimed spot")
	check(crushed.health.hp == crushed.health.max_hp, "and nothing is crushed before the pillars meet")
	check(get_tree().get_nodes_in_group("stone_ram").size() == 2, "two stone rams come out of the circles")
	check((get_tree().get_nodes_in_group("stone_ram")[0].find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).material_override.cull_mode == BaseMaterial3D.CULL_DISABLED, "stone on both sides, so no holes")
	var ram_start: Vector3 = get_tree().get_nodes_in_group("stone_ram")[0].global_position
	await _frames(int((t.pillar_delay + t.ram_rear_time * 0.6) * hz))
	var reared: Node3D = get_tree().get_nodes_in_group("stone_ram")[0]
	var rskel := reared.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var shin := rskel.find_bone("FrontLowerLeg.L")
	check(rskel.get_bone_global_pose(shin).basis.y.normalized().angle_to(rskel.get_bone_global_rest(shin).basis.y.normalized()) > deg_to_rad(30.0), "their front legs curl up as they rear")
	check(Vector2(reared.global_position.x - spot.x, reared.global_position.z - spot.z).length() > Vector2(ram_start.x - spot.x, ram_start.z - spot.z).length() - 0.6 * t.ram_size, "they rear where they rose, without charging first")
	check(reared.basis.z.normalized().y > 0.7 and crushed.health.hp == crushed.health.max_hp, "the rams rear up on their hind legs before they collide (%.2f)" % reared.basis.z.normalized().y)
	await _frames(int((t.ram_rear_time * 0.4 + t.ram_lunge_time) * hz) + 6)
	check(crushed.health.hp < crushed.health.max_hp and away.health.hp == away.health.max_hp, "the pillars crush what's between them")
	var ram: Node3D = get_tree().get_nodes_in_group("stone_ram")[0]
	var anims := ram.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	check(is_equal_approx(anims.get_animation("Attack_Headbutt").length, 24.0 / 24.0), "the ram's animations run 24 frames a second, as the clash pose expects")
	var skel := ram.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var head := skel.find_bone("Head")
	check(head >= 0 and not anims.active and ram.basis.z.normalized().y > 0.2, "the rams end front up, legs still, the player stopped (%.2f)" % ram.basis.z.normalized().y)
	await _frames(int(0.8 * hz))
	check(get_tree().get_nodes_in_group("stone_ram").is_empty(), "then they shrink away like the pillars did")
	_free_all([crushed, away])

	t.cage_time = saved[0]
	t.ice_snake_time = saved[1]
	p.global_position = home
	p.abilities.defs = kept


## Enemies go limp when they die (user, 2026-10-29): physics bones take over and fall.
func test_ragdoll_death() -> void:
	var e: Enemy = _cluster(1, 4.0)[0]
	await _frames(5)
	check(e.model != null, "the raider has a model")
	if e.model == null:
		return
	var info := DamageInfo.make(99999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, _arena.player)
	info.knockback = 8.0
	info.knockback_dir = Vector3(0, 0, -1)
	Combat.deal(e, info)
	await _frames(2)
	check(e.model.is_ragdoll(), "a killed enemy becomes a ragdoll")
	# The skeleton takes the bodies' pose while drawing; check the physics bodies themselves.
	var head: PhysicalBone3D = e.model._ragdoll.get_children().filter(func(pb): return pb.bone_name == "head")[0]
	var start_y := head.global_position.y
	await _frames(60)
	check(head.global_position.y < start_y - 0.5, "its head falls to the ground (%.2f -> %.2f m)" % [start_y, head.global_position.y])


func test_ability_cast() -> void:
	var p: Player = _arena.player
	var enemies := _cluster(4, 20.0, "barb_warlord")  # where the Magma Ball lands, unaimed: range_m ahead
	for e in enemies:
		e.freeze(5.0)
	var s := _scripted()
	s.press("signature")
	await _frames(110)  # reach down, pull the ball out, hurl it
	check(p.abilities.ready_in("Signature") > 0.0, "the Fire Special went on cooldown")
	var hurt := enemies.filter(func(e): return e.health.hp < e.health.max_hp).size()
	check(hurt == 4, "the Fire Special hit all 4 nearby enemies (got %d)" % hurt)
	var burning := enemies.filter(func(e): return e.statuses.has("fire")).size()
	check(burning == 4, "the Fire Special set them on fire (got %d)" % burning)


func test_breakable_props() -> void:
	var p: Player = _arena.player
	var barrel: Node3D = (load(Breakable.PROPS + "barrel.glb") as PackedScene).instantiate()
	_arena.add_child(barrel)
	barrel.scale = Vector3.ONE * 3.2
	barrel.global_position = p.global_position + p.facing * 1.5
	Breakable.attach(barrel, "barrel")
	Breakable.attach(barrel, "well")  # stone: not breakable
	check(barrel.get_children().filter(func(c): return c is Breakable).size() == 1 and get_tree().get_nodes_in_group("breakables").size() == 1, "a barrel is breakable, a well isn't")
	var before := _arena.get_child_count()
	p.moveset.light_hit(p, false)
	await _frames(2)
	var chunks := 0
	for c in _arena.get_children():
		if c is RigidBody3D:
			chunks += 1
	check(not is_instance_valid(barrel) and chunks >= 4, "a swing breaks it into chunks (%d)" % chunks)
	check(get_tree().get_nodes_in_group("breakables").is_empty(), "and it can't break twice")
	for c in _arena.get_children():
		if c is RigidBody3D:
			c.queue_free()


## Fire Lance (user, 2026-11-06): lunge, stab, and a cone of fire ahead hits hard and ignites; nothing behind or beside you.
func test_fire_lance() -> void:
	var p: Player = _arena.player
	check(GameData.text(p.abilities.defs.Movement, "ability_id") == "forge_fire_lance", "the forge god's Movement is Fire Lance")
	var start := p.global_position
	var ahead: Array = []
	for z in [-6.0, -20.0, -45.0]:  # in a line, within the 50 m beam (user, 2026-11-19)
		var e: Enemy = _arena.waves.spawn("barb_warlord")
		e.global_position = start + Vector3(0, 0, z)
		ahead.append(e)
	var far: Enemy = _arena.waves.spawn("barb_warlord")
	far.global_position = start + Vector3(0, 0, -60.0)
	var behind: Enemy = _arena.waves.spawn("barb_warlord")
	behind.global_position = start + Vector3(0, 0, 3.0)
	var beside: Enemy = _arena.waves.spawn("barb_warlord")
	beside.global_position = start + Vector3(6.0, 0, -3.5)
	var s := _scripted()
	s.press("movement")
	await _frames(25)
	check(p.global_position.z < start.z - 2.0, "you lunge forward (%.1f m)" % (start.z - p.global_position.z))
	check(is_equal_approx(p._cast_slow, GameData.tuning.lance_stab_slow), "the stab plays 50% slower (user, 2026-11-08)")
	var hurt := ahead.filter(func(e): return e.health.hp <= e.health.max_hp - 60.0).size()
	check(hurt == 3, "the lance hits all 3 enemies ahead hard (got %d)" % hurt)
	check(ahead.filter(func(e): return e.statuses.has("fire")).size() == 3, "and sets them on Fire")
	check(behind.health.hp == behind.health.max_hp and beside.health.hp == beside.health.max_hp, "enemies behind and beside you are untouched")
	check(far.health.hp == far.health.max_hp, "nor one past the beam's 50 m")
	var chest: Vector3 = p.global_position + Vector3.UP * 1.25 + p.facing * GameData.tuning.lance_chest_ahead
	var circles := get_tree().get_nodes_in_group("magic_circle").filter(func(c): return c.global_position.distance_to(chest) < 0.5)
	check(circles.size() == 1 and absf(circles[0].scale.x - 0.5) < 0.05, "the beam fires from one 1 m magic circle 1 m before your chest (user, 2026-11-20)")
	var tint: Color = GameData.tuning.lance_tint
	var fx: Node3D = p.abilities._beam.get("fx")
	var sprites: Array = fx.find_children("*", "SpriteBase3D", true, false) if fx != null else []
	check(fx == null or sprites.all(func(sp): return sp.modulate.g <= tint.g + 0.01), "and the lance is darker red")
	# The beam stays on and follows your aim (user, 2026-11-19): turn right and it sweeps onto the one beside.
	check(p.abilities.beaming() and p.state == Player.State.CAST, "the beam stays on a moment, and you keep casting")
	check(float(p.abilities._beam.get("spin", 0.0)) > 0.5, "the circle whirls faster while the beam fires (user, 2026-11-19)")
	s.aim_yaw = -PI / 2.0
	await _frames(20)
	check(p.facing.x > 0.9, "your body turns with your aim while it's on")
	check(beside.health.hp < beside.health.max_hp, "and the beam sweeps onto the enemy beside you")
	await _frames(int(GameData.tuning.lance_beam_time * Engine.physics_ticks_per_second))
	check(not p.abilities.beaming() and p.state == Player.State.FREE, "then the beam ends and you're free")
	s.aim_yaw = 0.0
	await _frames(20)
	# Under a low roof (a cave): the lunge stays under it (playtest 2026-11-08: it put you on the ceiling).
	var roof := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(20, 1, 20)
	roof.add_child(box)
	_arena.add_child(roof)
	roof.global_position = p.global_position + Vector3.UP * 4.0
	await _frames(2)
	var floor_y := p.global_position.y
	p.stamina = p.max_stamina
	p.abilities._lance(p.abilities.defs.Movement, p, p.facing, 8.0, 3.0)
	var highest := floor_y
	for f in 20:
		await _frames(1)
		highest = maxf(highest, p.global_position.y)
	check(highest < floor_y + 2.0, "lunging under a low roof keeps you under it (%.1f m up)" % (highest - floor_y))
	roof.queue_free()


func test_performance_40_enemies() -> void:
	var p: Player = _arena.player
	p.god_mode = true
	for i in 40:
		_arena.waves.spawn("barb_raider", p.global_position)
	await _frames(30)
	var start := Time.get_ticks_usec()
	await _frames(120)
	var avg_ms := (Time.get_ticks_usec() - start) / 120.0 / 1000.0
	print("      40 enemies: %.2f ms per frame (headless, no rendering)" % avg_ms)
	check(avg_ms < 8.0, "40 enemies simulate in under 8 ms per frame (got %.2f)" % avg_ms)


func test_wave_and_godly_gift_flow() -> void:
	# Replace the test arena with one that starts like a real run.
	_arena.queue_free()
	await _frames(1)
	_arena = ARENA.instantiate()
	_arena.run_seed = 99
	add_child(_arena)
	await _frames(2)
	var hud: Hud = _arena.hud
	check(hud.is_choosing() and get_tree().paused, "run starts with a paused godly_gift choice")
	hud._pick(0)
	check(not get_tree().paused and _arena.player.godly_gifts.owned.size() == 1, "picking a godly_gift unpauses and adds it")
	await _frames(int(GameData.tuning.time_between_waves * 60.0) + 10)
	var first_wave := GameData.tuning.wave_sizes[0]
	check(_arena.waves.wave == 0 and _arena.waves.alive() == first_wave, "wave 1 spawned %d enemies (got %d)" % [first_wave, _arena.waves.alive()])
	for e in get_tree().get_nodes_in_group("enemies"):
		Combat.deal(e, DamageInfo.make(9999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, _arena.player))
	await _frames(40)
	while hud.is_choosing() and hud._offer_kind == "level":  # the wave's XP can bring a level-up first (it pauses the waves)
		hud._pick(0)
		await _frames(40)
	check(hud.is_choosing(), "clearing the wave offers another godly_gift")
	check(GameData.text(GameData.god("storm_god"), "display_name") in hud._choice_title.text, "second offer comes from the Storm Caller (Storm)")
	hud._pick(0)


func test_kiln_heart_on_burning_kill() -> void:
	var p: Player = _arena.player
	p.godly_gifts.add_godly_gift("forge_kiln_heart")
	var e: Enemy = _cluster(1)[0]
	Combat.apply_status(e, "fire", 1, p)
	Combat.deal(e, DamageInfo.make(999.0, "Physical", DamageInfo.Kind.LIGHT, p))
	check(p.stats.get_stat("damage_pct") >= 10.0, "killing a burning enemy grants Kiln Heart's +10%% damage (got %.0f)" % p.stats.get_stat("damage_pct"))


func _horizontal_speed() -> float:
	var v: Vector3 = _arena.player.velocity
	return Vector2(v.x, v.z).length()


func test_sprint_and_jump() -> void:
	var p: Player = _arena.player
	var s := _scripted()
	var race_mult := p.stats.mult("move_speed_pct")
	s.hold({"move": Vector2.UP}, 20)
	await _frames(20)
	check(absf(_horizontal_speed() - GameData.tuning.move_speed * race_mult) < 0.3, "walk speed is %.2f (got %.2f)" % [GameData.tuning.move_speed * race_mult, _horizontal_speed()])
	s.hold({"move": Vector2.UP, "sprint": true}, 20)
	await _frames(20)
	var sprint := _horizontal_speed()
	check(absf(sprint - GameData.tuning.sprint_speed * race_mult) < 0.5, "sprint speed is %.2f (got %.2f)" % [GameData.tuning.sprint_speed * race_mult, sprint])
	var floor_y := p.global_position.y
	s.hold({"move": Vector2.UP, "sprint": true, "jump": true}, 1)
	s.hold({"move": Vector2.UP, "sprint": true}, 19)
	await _frames(20)  # the knees bend a moment first
	check(p.global_position.y > floor_y + 1.0, "a sprinting jump leaves the ground (rose %.2f m)" % (p.global_position.y - floor_y))
	check(_horizontal_speed() > sprint - 1.0, "momentum carries through the jump")


func test_slide_boost_and_crouch() -> void:
	var p: Player = _arena.player
	var s := _scripted()
	s.hold({"move": Vector2.UP}, 20)
	await _frames(20)
	var walk := _horizontal_speed()
	s.hold({"move": Vector2.UP, "slide": true, "slide_held": true}, 1)
	await _frames(1)
	check(p.is_sliding, "slide started")
	check(_horizontal_speed() > walk + GameData.tuning.slide_speed_gain - 0.3, "slide adds speed (walk %.2f -> %.2f)" % [walk, _horizontal_speed()])
	check(p.is_low(), "camera drops while sliding")
	s.hold({"move": Vector2.UP}, 60)
	await _frames(60)
	check(not p.is_sliding, "slide ends after its duration")
	# Slide with no movement key = crouch while held.
	s.hold({}, 30)
	await _frames(30)
	s.hold({"slide": true, "slide_held": true}, 1)
	s.hold({"slide_held": true}, 10)
	await _frames(5)
	check(p.is_crouching and _horizontal_speed() < 0.01, "stationary slide = crouch")
	await _frames(10)
	check(not p.is_crouching, "releasing slide stands up")


func test_models_and_animations() -> void:
	# Barbarians are every race in barbarian clothes (user, 2026-11-08): each one a race at random.
	var picks := {}
	for i in 40:
		picks[ModelRegistry.barbarian_of_any_race("barb_raider.glb")] = true
	check(picks.size() >= 6 and picks.keys().all(func(f): return f.begins_with("barb_raider_") and ModelRegistry.own(f) != "" and ModelRegistry.held(f) != ""),
		"a barbarian is a random race in barbarian clothes, armed (%d kinds seen)" % picks.size())
	var p: Player = _arena.player
	check(p.visual != null, "player uses the KayKit model")
	if p.visual != null:
		check(p.visual.anim.has_animation("Running_A") and p.visual.anim.has_animation("Melee_1H_Attack_Jump_Chop"), "shared animation library loaded")
		check(not p.visual.find_children("*", "BoneAttachment3D", true, false).is_empty(), "weapon attached to the hand")
	var e: Enemy = _cluster(1, 3.0)[0]
	check(e.model != null, "raider uses the skeleton model")
	var s := _scripted()
	s.hold({"move": Vector2.UP, "sprint": true}, 20)
	await _frames(20)
	check(p.visual != null and p.visual.current() == "Running_B", "sprinting plays the sprint animation (got %s)" % (p.visual.current() if p.visual else "none"))
	s.press("heavy")
	await _frames(3)
	check(p.visual != null and p.visual.current() == "Melee_1H_Attack_Jump_Chop", "heavy attack plays the jump chop")


# ---------------------------------------------------------------- architecture

func _fresh_run(seed_value := 777) -> RunState:
	return Run.start_new("dwarf", "forge_god", seed_value)


func test_level_ups() -> void:
	var s := _fresh_run(3)
	var p: Player = _arena.player
	var ups := LevelSystem.add_xp(s, LevelSystem.xp_to_next(1) + LevelSystem.xp_to_next(2), p.stats)
	check(ups == 2 and s.level == 3, "enough XP gives two level-ups")
	var offer := LevelSystem.make_offer(s)
	check(offer.size() == 3, "a level-up offers 3 upgrades")
	var hp_before := p.health.max_hp
	LevelSystem.pick(s, "vitality", p.stats)
	check(p.health.max_hp > hp_before, "Vitality raises max health (%.0f -> %.0f)" % [hp_before, p.health.max_hp])


func test_one_god_per_race() -> void:
	check(not ResourceLoader.exists("res://scripts/progression/pledge_system.gd"), "you can't switch gods any more")
	var src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	check(not src.contains("PLEDGE"), "a god you meet offers only godly gifts")
	var dwarf_first: String = GameData.text(GameData.race("dwarf"), "starting_gods").split(",")[0].strip_edges()
	check(dwarf_first != "", "each race starts with its own god (the dwarf's is %s)" % dwarf_first)


func test_void_mark() -> void:
	var p: Player = _arena.player
	p.godly_gifts.add_godly_gift("forge_tempered")
	for i in 5:
		Combat.apply_status(p, "void", 1, null)
	check(p.godly_gifts.is_suppressed(), "a full Void mark switches godly_gifts off")
	check(not p.statuses.has("void"), "and the mark resets")
	await _frames(int(StatusEffects.VOID_SUPPRESS_SECONDS * 60.0) + 5)
	check(not p.godly_gifts.is_suppressed(), "godly_gifts come back after 3 s")
	Combat.apply_status(p, "void", 2, null)
	var s := _scripted()
	s.press("dodge")
	await _frames(2)
	check(p.statuses.stacks("void") == 1, "dodging removes a Void stack")


func test_all_movesets() -> void:
	var p: Player = _arena.player
	for weapon in ["fists", "warhammer", "greatsword", "twin_khopesh", "naginata"]:
		p.setup("dwarf", "forge_god", weapon)
		var enemies := _cluster(3, 3.0, "barb_warlord")
		var s := _scripted()
		s.press("light")
		await _frames(30)
		s.press("heavy")
		await _frames(50)
		var hurt := enemies.filter(func(e): return is_instance_valid(e) and e.health.hp < e.health.max_hp).size()
		check(hurt >= 1, "%s (%s) hits enemies with light and heavy attacks (%d hurt)" % [weapon, p.weapon_class(), hurt])
		for e in enemies:
			if is_instance_valid(e):
				e.queue_free()
		await _frames(2)


func test_weapon_choice() -> void:
	var p: Player = _arena.player
	p.apply_run_state(Run.start_new("dwarf", "forge_god", 31))
	check(p.weapon_id == GameData.FISTS and p.moveset is WeaponMoveset.Fists, "a fight starts with bare fists (user, 2026-11-20)")
	var s := Run.start_new("dwarf", "forge_god", 31, "naginata")
	p.apply_run_state(s)
	check(p.weapon_id == "naginata" and p.moveset is WeaponMoveset.Polearm, "the weapon picked at the start sets the moveset")
	p.setup("dwarf", "forge_god", "warhammer")


func test_stone_status() -> void:
	check(GameData.text(GameData.god("animal_god"), "element") == "Stone" and not GameData.status("stone").is_empty(), "the Lord of Beasts' damage type is Stone")
	var foes := _cluster(1, 4.0)
	var e: Enemy = foes[0]
	await _frames(2)
	e.statuses.apply("stone", 1, _arena.player)
	await _frames(1)
	check(e.state == Enemy.State.DOWN, "a Stone hit knocks the enemy down")
	check(is_equal_approx(e.statuses.slow_fraction(), 0.3), "and slows it 30%% while it lasts (%.2f)" % e.statuses.slow_fraction())
	var troll: Enemy = _arena.waves.spawn("horde_troll", _arena.player.global_position + Vector3(4, 0, -6))
	await _frames(2)
	troll.statuses.apply("stone", 1, _arena.player)
	await _frames(1)
	check(troll.state != Enemy.State.DOWN and troll.statuses.slow_fraction() > 0.0, "a large one keeps its feet, but is slowed")
	e.queue_free()
	troll.queue_free()


## Your own effect scenes (models/own/fx) win over the code's, and only where you've made one.
func test_own_effects() -> void:
	var folder := "user://test_fx/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for element in ["fire", "lightning"]:
		var real := ElementFx.find_own(ElementFx.impact(element) + ".tscn", ElementFx.OWN_FX)
		check(ResourceLoader.exists(real) and (load(real) as PackedScene).instantiate().find_children("*", "GPUParticles3D").size() > 0, "your %s explosion loads from its folder in models/own/fx" % element)
	var me: Player = _arena.player
	var arcs := Combat.effects_root.get_child_count()
	check(ElementFx.bolt_arc(me.global_position + Vector3(0, 1, -3), me.global_position + Vector3(4, 1, -7)) and Combat.effects_root.get_child_count() == arcs + ElementFx.ARC_SEGMENTS,
		"lightning jumping to the next enemy is an arc of your bolt pictures (user, 2026-11-08)")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder + "fire/deeper"))
	for file in ["fire_hit", "fire/deeper/" + ElementFx.impact("fire"), "fire_aura", "forge_eruption"]:  # one sorted into a folder
		var root := Node3D.new()
		root.name = "Mine_" + file.get_file()
		var sparks := CPUParticles3D.new()
		sparks.one_shot = true
		sparks.lifetime = 0.3
		root.add_child(sparks)
		sparks.owner = root
		var packed := PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, folder + file + ".tscn")
		root.free()
	var saved_path := ElementFx.OWN_FX
	ElementFx.OWN_FX = folder
	ElementFx._own = {}
	var p: Player = _arena.player
	var mine := func(name: String) -> int:
		return Combat.effects_root.find_children(name, "", false, false).size()
	ElementFx._budget_left = 99
	ElementFx.hit("Fire", p.global_position + Vector3(0, 1, -3))
	check(mine.call("Mine_fire_hit") == 1, "your fire hit plays in place of the code's")
	ElementFx.hit("Fire", p.global_position + Vector3(0, 1, -3), 1.6, Vector3.INF, true)
	check(mine.call("Mine_fire_explosion") == 1 and mine.call("Mine_fire_hit") == 1, "a fire heavy hit plays your heavy explosion")
	var before := Combat.effects_root.get_child_count()
	check(ElementFx.area("Fire", p.global_position + Vector3(0, 0, -6), 3.0) and Combat.effects_root.get_child_count() == before + 1, "every fire explosion plays it too (one scene, none of the code's)")
	var god := p.god_id
	p.setup(p.race_id, "forge_god")
	var explosions := func() -> int:
		return Combat.effects_root.get_children().filter(func(n): return n.scene_file_path.ends_with("fire_explosion.tscn")).size()
	var booms: int = explosions.call()
	p.hit_targets([], 10.0, DamageInfo.Kind.HEAVY, 1.0, false, 0.0, 0.0, [], p.global_position + p.facing * 2.0)
	check(explosions.call() == booms + 1, "a weapon heavy plays your god's explosion where it lands, even on a miss (user, 2026-11-08)")
	p.setup(p.race_id, god)
	before = Combat.effects_root.get_child_count()
	ElementFx.hit("Ice", p.global_position + Vector3(0, 1, -3))
	check(Combat.effects_root.get_child_count() == before + 1 and mine.call("Mine_*") == 2, "one you haven't made keeps the code effect")
	var aura := ElementFx.aura("Fire", 1.0)
	check(aura is CPUParticles3D and aura.find_child("Mine_fire_aura", false, false) != null, "your aura rides along like the code's (start and stop work the same)")
	aura.free()
	p.setup("dwarf", "forge_god", "warhammer")
	p.abilities.remaining["Signature"] = 0.0
	var code_before: int = Combat.effects_root.get_children().filter(func(n): return n is CPUParticles3D).size()
	p.abilities.cast("Signature", p, p.facing)
	check(mine.call("Mine_forge_eruption") == 1, "a god ability plays your scene for it (%s)" % GameData.text(p.abilities.defs.Signature, "ability_id"))
	check(Combat.effects_root.get_children().filter(func(n): return n is CPUParticles3D).size() == code_before and not ElementFx.quiet, "and the code's element particles stay quiet while it does")
	await _frames(60)
	check(mine.call("Mine_*") == 0, "your effects free themselves when they're done")
	ElementFx.OWN_FX = saved_path
	ElementFx._own = {}


## The pixelfx sprite-sheet effects (user, 2026-11-20): the four elements, four weapons, and landing.
func test_pixelfx_effects() -> void:
	var p: Player = _arena.player
	var at := p.global_position + Vector3(0, 0, -5)
	var played := func(file: String) -> int:
		return Combat.effects_root.get_children().filter(func(n): return n.scene_file_path.ends_with("/" + file + ".tscn")).size()
	for file in ["fire_blast", "water_hit", "air_blast", "stone_blast", "hammer_slam", "sword_slash", "khopesh_spin", "naginata_sweep", "landing"]:
		var scene := ElementFx.own_scene(file)
		var sprite: AnimatedSprite3D = scene.instantiate().find_child("Sprite") if scene != null else null
		check(sprite != null and sprite.sprite_frames.get_frame_count("default") > 10, "%s is a sprite-sheet effect" % file)
		if sprite != null:
			var lasts := ElementFx._start(sprite)
			check(lasts > 0.7 and lasts < 4.5, "%s lasts one play of its sheet (%.2f s)" % [file, lasts])
			sprite.free()
	for element in ["Fire", "Air", "Stone"]:
		ElementFx.area(element, at, 3.0)
		check(played.call(element.to_lower() + "_blast") == 1, "a %s blast plays its pixelfx effect" % element)
	ElementFx._budget_left = 99
	ElementFx.hit("Water", at + Vector3.UP)
	check(played.call("water_hit") == 1, "a Water hit splashes")
	for weapon in [["warhammer", "hammer_slam"], ["twin_khopesh", "khopesh_spin"], ["naginata", "naginata_sweep"]]:
		p.setup("dwarf", p.god_id, weapon[0])
		p.moveset.heavy_hit(p)
		check(played.call(weapon[1]) == 1, "the %s's heavy attack plays %s" % weapon)
	p.setup("dwarf", p.god_id, "greatsword")
	p.moveset.light_hit(p, false)
	check(played.call("sword_slash") == 1, "a greatsword swing plays the sword slash")
	p.global_position += Vector3.UP * 6.0  # a fall from 6 m lands at about 13 m/s
	for i in 120:
		await _frames(1)
		if played.call("landing") > 0:
			break
	check(played.call("landing") == 1, "a hard landing kicks up dust")
	var ghosts := func() -> int:
		return Combat.effects_root.find_children("*Ghost*", "MeshInstance3D", false, false).size()
	p._start_dodge(p.facing)
	await _frames(10)
	var left: int = ghosts.call()
	check(left >= 2, "a dash leaves after-images of your body (%d)" % left)
	await _frames(60)
	check(ghosts.call() == 0, "and they fade away")


func test_bestiary_and_wings() -> void:
	Meta.persist = false
	var p: Player = _arena.player
	p.god_mode = true
	p.setup("dwarf", "forge_god", "warhammer")
	var input := _scripted()
	var book := Bestiary.open(_arena)
	await _frames(2)
	check(book._title.text.contains("discovered") and book._info.text != "", "the bestiary lists what you've found")
	book._close()
	# Birds beat their wings with the little demon's wing beat.
	var eagle: Enemy = _arena.waves.spawn("animal_eagle", p.global_position + Vector3(0, 6, -8))
	await _frames(2)
	var bird := eagle.model as BeastModel
	check(bird != null and bird._bird_skeleton != null and bird._wings.size() == 2, "an eagle's wings are found")
	if bird != null and bird._bird_skeleton != null:
		var i: int = bird._wings[0][0]
		var a := bird._bird_skeleton.get_bone_pose_rotation(i)
		await _frames(10)
		check(not bird._bird_skeleton.get_bone_pose_rotation(i).is_equal_approx(a), "and they beat")
	eagle.queue_free()
	# The minigun demon (the user's model): a flyer of the horde that fires bursts.
	var demon: Enemy = _arena.waves.spawn("horde_minigun_demon", p.global_position + Vector3(0, 0, -12))
	await _frames(2)
	check(demon.model is BeastModel and demon.flying and demon.is_ranged(), "the minigun demon flies with Count Fuckula's horde")
	check(demon.model.find_child("barrels", true, false) != null, "its minigun barrels are on its arm")
	demon.queue_free()
	input.hold({}, 1)


func test_weapons_and_classes() -> void:
	var found := GameData.pickup_weapons()
	check(found.size() == 4 and "naginata" in found and not "bow" in found, "four weapons to find (%s), no bow (user, 2026-11-20)" % ", ".join(found))
	check(GameData.rows("weapons").size() == 5 and GameData.text(GameData.weapon(GameData.FISTS), "weapon_class") == "Fists", "and your fists, five on the sheet")
	check(GameData.text(GameData.weapon("twin_khopesh"), "weapon_class") == "Twin" and WeaponMoveset.for_class("Twin") is WeaponMoveset.Twin, "twin blades are their own class")
	check(ModelRegistry.weapon_model("naginata").ends_with("weapon_naginata.glb"), "the naginata has its own model")
	check(ModelRegistry.weapon_model("naginata", "macaque") == ModelRegistry.OWN + "weapon_naginata.glb"
		and ModelRegistry.weapon_model("naginata", "minotaur").ends_with("minotaur/weapon_naginata.glb") and ModelRegistry.weapon_model("naginata", "frog").ends_with("frog/weapon_naginata.glb"),
		"polearms by race: your naginata for the macaques, the minotaurs' and frogfolk's own (user, 2026-11-09; the dwarves' is your lance, below)")
	# Every race has its own set of the weapons (user, 2026-11-09).
	var shared: Array = []
	for r in GameData.rows("races"):
		for w in found:
			if not ModelRegistry.weapon_model(w, r.race_id).contains("/%s/" % r.race_id):
				shared.append("%s %s" % [r.race_id, w])
	check(shared == ["macaque naginata"], "every race has its own version of every weapon; only the macaques' polearm is your naginata (%s)" % [shared])
	check(ModelRegistry.weapon_model("naginata", "nobody") == ModelRegistry.weapon_model("naginata"), "and the normal weapon where there is no race version")
	# Each race has the same classes, each with its own look (user, 2026-11-17): own/<race>/<class>/.
	check(ModelRegistry.weapon_model("greatsword", "dwarf") == ModelRegistry.OWN + "dwarf/guardian/weapon.glb"
		and ModelRegistry.weapon_model("warhammer", "dwarf") == ModelRegistry.OWN + "dwarf/barbarian/weapon.glb"
		and ModelRegistry.weapon_model("naginata", "dwarf") == ModelRegistry.OWN + "dwarf/lancer/weapon.glb",
		"a race's class weapons come from its class folders (the user's dwarf axe, warhammer and lance)")
	check(ModelRegistry.for_race("dwarf", "Guardian") == ModelRegistry.for_race("dwarf") and ModelRegistry.class_part("dwarf", "Guardian", "body") == "",
		"a class without its own body for a race wears the race's model")
	var p: Player = _arena.player
	p.god_mode = true
	p.setup("dwarf", "forge_god", "greatsword")
	check(is_equal_approx(p._light_duration() * 1.5 * GameData.num(GameData.weapon("greatsword"), "weapon_attacks_per_sec", 1.2) * p.stats.mult("attack_speed_pct") * GameData.tuning.light_speed_mult, 1.0),
		"sword swings are 50% faster (user, 2026-11-08)")
	var dash_from := p.global_position
	p.moveset.heavy_hit(p)
	await _frames(1)
	var first := p.global_position.distance_to(dash_from)
	await _frames(15)
	check(first < 2.5 and p.global_position.distance_to(dash_from) > 3.0,
		"the sword's heavy dashes forward, not in one jump (%.1f m in a frame, %.1f m after)" % [first, p.global_position.distance_to(dash_from)])
	# Classes (user, 2026-11-09): a weapon's class counts while you hold it.
	check(GameData.text(GameData.weapon("warhammer"), "class_name") == "Barbarian" and GameData.text(GameData.weapon("twin_khopesh"), "class_name") == "Rogue",
		"the warhammer is the Barbarian's, the twin blades the Rogue's")
	# Weapons differ only in damage and attack speed (user, 2026-11-20): holding one changes no stat.
	p.equip(GameData.FISTS)
	var plain := {}
	for stat in PlayerStats.READ_STATS:
		plain[stat] = p.stats.get_stat(stat)
	var plain_hp: float = p.health.max_hp
	for w in GameData.pickup_weapons():
		p.equip(w)
		check(p.health.max_hp == plain_hp and PlayerStats.READ_STATS.all(func(s): return p.stats.get_stat(s) == plain[s]), "holding the %s changes none of your stats" % w)
	check(not InputMap.has_action("sidearm") and not InputMap.has_action("switch_weapon"), "no bow to switch to any more (user, 2026-11-20)")


func test_shelved_races() -> void:
	for race in GameData.SHELVED_RACES:
		check(GameData.rows("races").all(func(r): return r.race_id != race) and GameData.where("army_units", "race_id", race).is_empty(),
			"the %s is set aside: not offered, no army in fights" % race)
		check(GameData.text(GameData.race(race), "race_id") == race, "but its row still loads, for old saves and later")
	# Milestone 1's roster (Council VIII; gods cut to Fire, Ice, Lightning, Stone 2026-11-16).
	var elements: Array = GameData.rows("gods").map(func(g): return GameData.text(g, "element"))
	elements.sort()
	check(elements == ["Fire", "Ice", "Lightning", "Stone"], "the Fire, Ice, Lightning and Stone gods (%s)" % [elements])
	var shelved := func(r): return r.get("god_id") in GameData.SHELVED_GODS or r.get("god_a") in GameData.SHELVED_GODS or r.get("god_b") in GameData.SHELVED_GODS
	check(not GameData.rows("god_abilities").any(shelved) and not GameData.rows("godly_gifts").any(shelved) and not GameData.rows("duo_godly_gifts").any(shelved),
		"set-aside gods' abilities, gifts and duo gifts are never offered")
	check(GameData.text(GameData.god("moon_god"), "god_id") == "moon_god", "but their rows still load")


func test_race_actives() -> void:
	var p: Player = _arena.player
	p.god_mode = false
	p.setup("dwarf", "forge_god")
	p.race_active.cooldown = 0.0
	p.abilities.invulnerable = false
	check(p.race_active.cast() and p.race_active.cooldown > 0.0 and not p.race_active.cast(), "the dwarf's active runs, then cools down (%s)" % p.race_active.title())
	check(p.is_invulnerable(), "the dwarf can't be hurt while its active lasts")
	p.race_active.invulnerable = false
	# Any other race gets a plain blast.
	p.setup("human", "forge_god")
	p.race_active.cooldown = 0.0
	var foe: Enemy = _cluster(1, 3.0)[0]
	var hp: float = foe.health.hp
	p.race_active.cast()
	check(not p.is_invulnerable() and (not is_instance_valid(foe) or foe.health.hp < hp), "another race's active is a blast that hurts")
	if is_instance_valid(foe):
		foe.queue_free()
	p.setup("dwarf", "forge_god")
	var s := _scripted()
	p.race_active.cooldown = 0.0
	get_tree().paused = false  # a kill may have opened a level-up choice
	p.abilities.invulnerable = false
	s.press("race_active")
	await _frames(3)
	check(p.race_active.cooldown > 0.0, "the race skill has its own button")
	p.race_active.invulnerable = false


func test_paired_claws() -> void:
	var m := CharacterModel.new()
	add_child(m)
	m.setup(ModelRegistry.for_race("human"), ModelRegistry.own("weapon_claws.glb"))
	var slots := func() -> int:
		return m.find_children("*", "BoneAttachment3D", true, false).filter(func(s): return not s.is_queued_for_deletion()).size()
	check(slots.call() == 2, "claws go on both hands (%d)" % slots.call())
	m.set_weapon(ModelRegistry.weapon_model("twin_khopesh"))
	await _frames(1)
	check(slots.call() == 2, "and so does the Twin Khopesh (%d)" % slots.call())
	m.set_weapon(ModelRegistry.own("weapon_mace.glb"))
	check(slots.call() == 1, "switching to a mace leaves one (%d)" % slots.call())
	m.queue_free()


func test_element_head() -> void:
	var p: Player = _arena.player
	check(ModelRegistry.for_race("dwarf").get_file() == ModelRegistry.PLAYER_BODY, "every race plays the user's base body")
	check(p.visual != null and p.visual.head_ball != null and p.visual.anim.has_animation("Running_A"), "it's rigged, animated, with an element for a head")
	var balls := func() -> int:
		return p.visual.find_children("HeadBall", "BoneAttachment3D", true, false).size()
	p.setup(p.race_id, "forge_god")
	var fire := p.visual.head_ball.find_children("*", "CPUParticles3D", true, false).size()
	p.visual.set_head_ball("Stone")
	check(balls.call() == 1 and fire > 0 and p.visual.head_ball.find_children("*", "CPUParticles3D", true, false).is_empty(),
		"the fire god's head burns, the boulder doesn't, and a new god swaps it (%d heads)" % balls.call())
	p.visual.set_weapon(ModelRegistry.own("weapon_mace.glb"))
	await _frames(1)
	check(is_instance_valid(p.visual.head_ball), "picking up a weapon keeps the head")
	var bone: Transform3D = p.visual._skeleton.global_transform * p.visual._skeleton.get_bone_global_pose(p.visual._skeleton.find_bone("head"))
	check(p.visual.head_ball.global_position.distance_to(bone.origin) < 0.05, "the ball sits on the head bone")


func test_race_active_fixes() -> void:
	var p: Player = _arena.player
	p.god_mode = false
	# A frozen enemy's animations start again when it thaws.
	var foes := _cluster(1, 6.0)
	var e: Enemy = foes[0]
	e.freeze(0.05)
	await _frames(1)
	check(e.model == null or e.model.anim == null or e.model.anim.speed_scale == 0.0, "a frozen enemy stops moving")
	await _frames(12)
	check(e.state != Enemy.State.FROZEN and (e.model == null or e.model.anim == null or e.model.anim.speed_scale == 1.0), "and moves again when it thaws")
	e.queue_free()
	check(GameData.num(GameData.race("dwarf"), "duration") == 5.0, "the race skill numbers are the user's choices")
	# Skill timers wait out a level-up choice.
	p.setup("dwarf", "forge_god")
	p.race_active.cooldown = 0.0
	p.race_active.cast()
	var timer: SceneTreeTimer = get_tree().create_timer(0.05, false)
	get_tree().paused = true
	await get_tree().create_timer(0.2).timeout
	check(timer.time_left > 0.0, "skill timers stop while the game is paused")
	get_tree().paused = false
	p.race_active.invulnerable = false
	p.setup("dwarf", "forge_god")


func test_launches_and_ragdolls() -> void:
	var p: Player = _arena.player
	p.god_mode = true
	# Heavy and magic hits launch; light weapon hits don't.
	var foe: Enemy = _cluster(1, 3.0)[0]
	var hard := func(kind: DamageInfo.Kind, category: String) -> DamageInfo:
		var i := DamageInfo.make(1.0, "Physical", kind, p)
		i.category = category
		return i
	Combat.deal(foe, hard.call(DamageInfo.Kind.LIGHT, "Melee"))
	check(not foe.thrown, "a light melee hit doesn't launch")
	Combat.deal(foe, hard.call(DamageInfo.Kind.HEAVY, "Melee"))
	check(foe.thrown and foe.model.is_ragdoll(), "a heavy attack launches, limp")
	var fall_bone: Variant = foe.model.ragdoll_hips()
	check(fall_bone.get("fall_mult") == GameData.tuning.enemy_fall_gravity_mult and foe._fall_mult(-1.0) > 1.0 and foe._fall_mult(1.0) == 1.0,
		"a launched enemy falls harder than it rises")
	var plain_speed := foe._throw_vel.length()
	var blown: Enemy = _cluster(1, 3.0)[0]
	var blast: DamageInfo = hard.call(DamageInfo.Kind.HEAVY, "Melee")
	blast.explosive = true
	Combat.deal(blown, blast)
	check(blown.thrown and is_equal_approx(blown._throw_vel.length(), plain_speed * GameData.tuning.explosion_launch_scale),
		"an explosion launches 33%% faster (%.1f vs %.1f m/s)" % [blown._throw_vel.length(), plain_speed])
	var v: Vector3 = foe._throw_vel
	var t: CombatTuning = GameData.tuning
	check(is_equal_approx(Vector2(v.x, v.z).length(), t.weapon_launch_speed * 1.3 * _arena.player.moveset.launch_scale()), "launched 30%% faster (times the weapon class) (%.1f m/s)" % Vector2(v.x, v.z).length())
	foe.queue_free()
	var mage: Enemy = _cluster(1, 3.0)[0]
	Combat.deal(mage, hard.call(DamageInfo.Kind.ABILITY, "Magic"))
	check(mage.thrown, "a magic ability launches")
	mage.queue_free()
	var bolted: Enemy = _cluster(1, 3.0)[0]
	Combat.deal(bolted, hard.call(DamageInfo.Kind.LIGHT, "Magic"))
	check(bolted.thrown, "a magic bolt launches too")
	bolted.queue_free()
	var chief: Enemy = _cluster(1, 3.0, "horde_evil_dragon")[0]
	Combat.deal(chief, hard.call(DamageInfo.Kind.HEAVY, "Melee"))
	check(not chief.thrown, "bosses stand their ground")
	chief.queue_free()
	await _frames(1)
	# Animals go limp when launched, and their bodies stay near the ground.
	for id in ["animal_cow", "beast_dire_wolf"]:
		var beast: Enemy = _cluster(1, 4.0, id)[0]
		await _frames(1)
		beast.throw(Vector3(0, 3, -8), p)
		check(beast.thrown and beast.model.is_ragdoll() and beast.model.ragdoll_hips() != null, "a launched %s goes limp" % id)
		await _frames(150)
		var limp: PhysicsBody3D = beast.model.ragdoll_hips() if is_instance_valid(beast) and beast.model.is_ragdoll() else null
		if limp != null:
			check(limp.global_position.y - p.global_position.y < 2.5, "and falls to the ground (%.1f m up)" % (limp.global_position.y - p.global_position.y))
		if is_instance_valid(beast):
			beast.queue_free()
		await _frames(1)
	# Blood: drops on a hit, more when slammed.
	var count := func() -> int:
		return Combat.effects_root.find_children("*", "CPUParticles3D", true, false).size()
	var bleeder: Enemy = _cluster(1, 3.0)[0]
	var before: int = count.call()
	Combat.deal(bleeder, hard.call(DamageInfo.Kind.LIGHT, "Melee"))
	check(count.call() > before, "a hit draws blood")
	bleeder.thrown = true
	bleeder._throw_speed = 20.0
	bleeder._throw_ragdoll = false
	bleeder._impact(0.0)
	check(Combat.effects_root.find_children("*", "CPUParticles3D", true, false).any(func(e): return e.amount == t.blood_slam_drops), "being slammed draws much more")
	bleeder.queue_free()
	await _frames(1)
	p.setup("dwarf", "forge_god")


func test_throw_key_and_weapon_aura() -> void:
	var p: Player = _arena.player
	p.god_mode = true
	var key := InputEventKey.new()
	key.physical_keycode = KEY_G
	check(InputMap.event_is_action(key, "throw_weapon"), "G throws your weapon")
	var god_key := InputEventKey.new()
	god_key.physical_keycode = KEY_P
	check(InputMap.event_is_action(god_key, "god_mode"), "P is god mode")
	for g in GameData.rows("gods"):
		for a in GameData.abilities_for(g.god_id).values():  # the clips picked in the Arena Magic Attacks sheet
			check(p.visual.anim.has_animation(GameData.text(a, "animation_name")), "%s plays %s" % [a.ability_id, a.animation_name])
	check(p.visual.anim.has_animation("Throw"), "the throw animation exists")
	# The aura around the weapon, in your god's color, through weapon swaps.
	p.setup("human", "forge_god", "warhammer")
	await _frames(1)  # the last weapon goes away at the end of the frame
	var halos := func() -> Array:
		return p.visual.find_children("WeaponAuraShell", "", true, false).filter(func(h): return not h.is_queued_for_deletion())
	check(not halos.call().is_empty(), "the weapon glows")
	check(halos.call()[0].material_override.albedo_color.is_equal_approx(Color(Color.html(GameData.text(GameData.god("forge_god"), "theme_color_hex")), 0.55)), "in the god's color")
	p.visual.set_weapon(ModelRegistry.own("weapon_mace.glb"))
	await _frames(1)
	check(not halos.call().is_empty(), "and keeps glowing with a new weapon")
	var weapon_size: Node3D = p.visual._skeleton.find_children("*", "BoneAttachment3D", false, false)[0].get_child(0)
	check(is_equal_approx(weapon_size.scale.x, GameData.tuning.weapon_scale) and GameData.tuning.weapon_scale == 1.3, "weapons are 30% bigger")
	p.setup("dwarf", "forge_god")


func test_aiming() -> void:
	var p: Player = _arena.player
	p.god_mode = true
	p.setup("human", "forge_god", "warhammer")
	await _until_on_floor()
	var t: CombatTuning = GameData.tuning
	var throw := func() -> Projectile:  # a tap of G with the warhammer
		p.equip("warhammer")
		p.throw_charge = 0.0
		return p.throw_weapon(p.rotation.y)
	# Straight ahead with nothing to aim at: it still drops a little.
	p._crosshair = Vector3.INF
	var flat: Projectile = throw.call()
	check(flat != null and flat.drop == t.weapon_throw_drop and flat.aimed, "a thrown weapon drops a little")
	var y0: float = flat.velocity.y
	await _frames(20)
	check(is_instance_valid(flat) and flat.velocity.y < y0 - 1.0 and flat.velocity.y > -8.0, "it falls as it flies, not much (%.1f m/s)" % flat.velocity.y)
	# Up and down, at whatever the crosshair is on.
	var muzzle: Vector3 = p.global_position + Vector3.UP * 1.3
	p._crosshair = muzzle + p.facing * 20.0 + Vector3.UP * 12.0
	check(throw.call().velocity.y > 15.0, "aiming up throws up")
	p._crosshair = muzzle + p.facing * 10.0 + Vector3.DOWN * 6.0
	check(throw.call().velocity.y < -15.0, "aiming down throws down")
	p._crosshair = muzzle - p.facing * 3.0
	check(throw.call().velocity.normalized().dot(p.facing) > 0.9, "a crosshair behind you doesn't throw backwards")
	# Aimed a little high so it drops onto the point you picked (user, 2026-11-05).
	var far_at := muzzle + p.facing * 30.0
	p._crosshair = far_at
	var speed := t.weapon_throw_speed
	var aimed := p.aim_direction(muzzle + p.facing * 0.6, speed, t.weapon_throw_drop)
	var t_fly := 30.0 / speed
	var lands := muzzle + p.facing * 0.6 + aimed * speed * t_fly + Vector3.DOWN * 0.5 * t.weapon_throw_drop * t_fly * t_fly
	check(aimed.y > 0.0 and lands.distance_to(far_at) < 1.0, "a far throw is aimed high and lands on the crosshair (%.2f m off)" % lands.distance_to(far_at))
	# A throw over someone's head misses; one at them hits.
	await _frames(100)  # the throws above have landed
	var foe: Enemy = _cluster(1, 8.0)[0]
	foe.global_position = p.global_position + p.facing * 8.0
	foe.health.setup(99999.0)
	await _frames(1)
	var hp: float = foe.health.hp
	p._crosshair = foe.global_position + Vector3.UP * 14.0
	throw.call()
	await _frames(20)
	check(foe.health.hp == hp, "a throw over their head misses")
	p._crosshair = foe.global_position + Vector3.UP
	throw.call()
	await _frames(20)
	check(foe.health.hp < hp, "a throw at them hits")
	foe.queue_free()
	# Throws stop at the ground.
	p._crosshair = muzzle + p.facing * 3.0 + Vector3.DOWN * 3.0
	var low: Projectile = throw.call()
	await _frames(15)
	check(not is_instance_valid(low), "a throw into the ground stops there")
	# The camera looks nearly straight up and down, and the crosshair is on screen.
	check(_arena.camera_rig.max_pitch > 1.0 and _arena.camera_rig.min_pitch < -1.3, "you can look almost straight up and down")
	p._crosshair = Vector3.INF
	for w in get_tree().get_nodes_in_group("weapon_pickups"):
		w.queue_free()
	p.setup("dwarf", "forge_god", "warhammer")


## User, 2026-11-20: a weapon's blow launches back, not up, and the body knocks into whoever is
## behind, launching them the same way; spells still throw high.
func test_weapon_launch_knocks_on() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	p.god_mode = true
	p.equip("warhammer")
	await _until_on_floor()
	var flight := func(e: Enemy) -> Vector3:
		var hips: PhysicsBody3D = e.model.ragdoll_hips() if e.model != null and e.model.is_ragdoll() else null
		return (hips as PhysicalBone3D).linear_velocity if hips is PhysicalBone3D else e._throw_vel
	var line: Array = []
	for d in [2.0, 4.5, 7.0]:
		var e: Enemy = _cluster(1, d)[0]
		e.global_position = p.global_position + p.facing * d
		e.health.setup(99999.0)
		line.append(e)
	await _frames(2)
	var blow := DamageInfo.make(1.0, "Physical", DamageInfo.Kind.HEAVY, p)
	blow.knockback_dir = p.facing
	Combat.deal(line[0], blow)
	var v: Vector3 = flight.call(line[0])
	check(Vector2(v.x, v.z).length() > v.y * 2.0 and v.dot(p.facing) > 0.0, "a weapon blow launches back, not up (%.1f m/s back, %.1f up)" % [Vector2(v.x, v.z).length(), v.y])
	var hp: Array = line.map(func(e): return e.health.hp)
	for i in 90:
		get_tree().paused = false
		await _frames(1)
		if line[1].thrown and line[2].thrown:
			break
	check(line[1].thrown and line[1].health.hp < hp[1], "the body knocks into the one behind it and launches it")
	check(line[2].thrown, "which knocks on into the next")
	check(line[1].global_position.distance_to(p.global_position) > 4.5, "all of them away from you")
	for e in line:
		e.queue_free()
	await _frames(1)
	var foe: Enemy = _cluster(1, 3.0)[0]
	await _frames(2)
	var spell := DamageInfo.make(1.0, "Fire", DamageInfo.Kind.ABILITY, p)
	spell.category = "Magic"
	spell.knockback_dir = p.facing
	Combat.deal(foe, spell)
	v = flight.call(foe)
	check(v.y > Vector2(v.x, v.z).length() * 0.5 and foe._ram_left <= 0.0, "a spell still throws high, and doesn't knock on (%.1f up)" % v.y)
	foe.queue_free()
	check(t.weapon_launch_lift < t.launch_lift, "weapons lift less than spells")


## User, 2026-11-20: you start with your fists and the chain; weapons lie about the arena, are picked
## up by walking over them, and are thrown with G: through every enemy in the path, pinning them to
## walls, landing to be picked up again.
func test_fists_pickups_and_throws() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	p.god_mode = true
	var lying := get_tree().get_nodes_in_group("weapon_pickups")
	check(lying.size() == t.weapon_pickups and lying.all(func(w): return w.weapon_id in GameData.pickup_weapons()), "%d weapons lie about the arena" % lying.size())
	for w in lying:
		w.queue_free()
	await _frames(1)
	var sheet: Array = GameData.tables.weapons
	GameData.tables.weapons = sheet.filter(func(r): return r.weapon_id == GameData.FISTS)  # weapons.json broken by a typo
	_arena.scatter_weapons()
	GameData.tables.weapons = sheet
	check(get_tree().get_nodes_in_group("weapon_pickups").is_empty(), "with no weapons on the sheet, none are laid out (and nothing breaks)")
	_arena.scatter_weapons()
	check(get_tree().get_nodes_in_group("weapon_pickups").size() == t.weapon_pickups, "and more are laid out to make up the count")
	for w in get_tree().get_nodes_in_group("weapon_pickups"):
		w.queue_free()
	# Fists: weaker than any weapon, a punch combo and a kick.
	p.equip(GameData.FISTS)
	check(p.moveset is WeaponMoveset.Fists and p.visual.find_children("*", "BoneAttachment3D", true, false).filter(func(a): return not a.is_queued_for_deletion() and a.get_child_count() > 0 and a != p.visual.head_ball).is_empty(),
		"bare fists: nothing in your hand")
	var fist := GameData.num(GameData.weapon(GameData.FISTS), "weapon_base_damage")
	check(GameData.pickup_weapons().all(func(w): return GameData.num(GameData.weapon(w), "weapon_base_damage") > fist), "every weapon hits harder than your fists")
	check(not p.throw_weapon(0.0), "there's nothing to throw")
	# Walking over a weapon takes it up; with a weapon in hand you walk past the next.
	await _frames(1)
	var hammer := WeaponPickup.make("warhammer", _arena, p.global_position + Vector3(0, 0, -0.5))
	var sword := WeaponPickup.make("greatsword", _arena, p.global_position + Vector3(0, 0, -0.5))
	await _frames(3)
	check(p.weapon_id in ["warhammer", "greatsword"] and (is_instance_valid(hammer) != is_instance_valid(sword)), "walking over a weapon takes it up, and only one (%s)" % p.weapon_id)
	for w in [hammer, sword]:
		if is_instance_valid(w):
			w.queue_free()
	# Throwing: hold G to wind up, let go to throw. It goes through every enemy in a line and pins them.
	p.equip("warhammer")
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 12.0, 1.0)
	col.shape = box
	wall.add_child(col)
	wall.collision_layer = 0b001
	_arena.add_child(wall)
	wall.global_position = p.global_position + Vector3(0, 4, -14)
	var foes: Array = []
	for d in [4.0, 7.0]:
		var e: Enemy = _cluster(1, d)[0]
		e.global_position = p.global_position + Vector3(0, 0.2, -d)
		e.health.setup(99999.0)
		foes.append(e)
	await _frames(1)
	p._crosshair = p.global_position + Vector3(0, 1.0, -10)
	var s := _scripted()
	s.hold({"throw": true, "throw_held": true, "aim_yaw": 0.0}, 1)
	s.hold({"throw_held": true, "aim_yaw": 0.0}, ceili(t.weapon_throw_charge_time * 60.0) + 5)
	await _frames(10)
	check(p.aiming and p.throw_charge > 0.0 and p.charge_shown() > 0.0, "holding G winds up the throw, the crosshair out and the charge bar filling")
	check(p.visual._strike.get("clip") == "Human_ThrowWeapon", "the hammer winds up on the overhand weapon throw (%s)" % p.visual._strike.get("clip"))
	var shots: Array = []
	var count := func(n: Node) -> void:
		if n is Projectile:
			shots.append(n.velocity)
	get_tree().node_added.connect(count)
	await _frames(ceili(t.weapon_throw_charge_time * 60.0) + 2)
	get_tree().node_added.disconnect(count)
	check(shots.size() == 1 and p.weapon_id == GameData.FISTS and not p.aiming, "letting go throws it: your hands are empty")
	check(p._cast_clip == "Human_ThrowWeapon" and not p.visual.strike_held(), "and the throw clip lets go")
	# Each weapon its own throw (user, 2026-11-20), converted from the Human Throwing pack.
	var throws := {"Heavy": "Human_ThrowWeapon", "Blade": "Human_ThrowWeapon", "Twin": "Human_ThrowBoomerang", "Polearm": "Human_ThrowSpear"}
	check(throws.keys().all(func(c): return WeaponMoveset.for_class(c).throw_anim() == throws[c] and p.visual.anim.has_animation(throws[c]) and CharacterModel.STRIKES.has(throws[c])),
		"hammer and sword throw overhand, the khopesh whips, the polearm goes like a javelin, each on its release frame")
	check(p.visual.anim.has_animation("Human_ThrowBall") and CharacterModel.STRIKES.has("Human_ThrowBall"), "arena items are thrown like a ball")
	# The weapon in your hand is the one that lay on the ground, whatever your race carries.
	var race := p.race_id
	p.race_id = "dwarf"
	check(GameData.pickup_weapons().all(func(w): p.weapon_id = w; return p._hand_model() == ModelRegistry.weapon_model(w)), "you hold the very weapon you picked up")
	p.race_id = race
	p.weapon_id = GameData.FISTS
	check(shots.size() == 1 and is_equal_approx(Vector2(shots[0].x, shots[0].z).length(), t.weapon_throw_speed_max), "wound up all the way, it flies at full force")
	var landed := false
	for i in 120:
		get_tree().paused = false
		await _frames(1)
		landed = landed or _arena.find_children("StuckWeapon", "", false, false).size() > 0
		if landed and foes.all(func(e): return e._pinned):
			break
	check(foes.all(func(e): return e.health.hp < e.health.max_hp), "it went through both enemies")
	check(foes.all(func(e): return e._pinned), "and pinned them to the wall")
	check(foes.all(func(e): return is_instance_valid(e._pin_bolt) and e._pin_weapon == "warhammer"), "the warhammer itself through them")
	check(landed, "the warhammer sticks in the wall it hit")
	check(get_tree().get_nodes_in_group("weapon_pickups").any(func(w): return w.weapon_id == "warhammer"), "and a new warhammer is laid out")
	# Empty hands: the chain grab pulls a weapon out of the wall into your hand (user, 2026-11-20).
	for w in get_tree().get_nodes_in_group("weapon_pickups"):
		w.free()
	for e in foes:
		e.free()
	foes.clear()
	var stuck: Array = _arena.find_children("StuckWeapon", "", false, false)
	p.equip(GameData.FISTS)
	p._set_state(Player.State.FREE)
	var pull := PlayerIntent.new()
	pull.crosshair = stuck[0].global_position
	pull.light_held = true
	check(p.chain.find_target(pull) == stuck[0] and p._try_grab(pull), "with empty hands the chain takes the weapon stuck in the wall")
	for i in 90:
		await _frames(1)
		if p.weapon_id != GameData.FISTS:
			break
	check(p.weapon_id == "warhammer" and not is_instance_valid(stuck[0]), "and pulls it into your hand (%s)" % p.weapon_id)
	for w in _arena.find_children("StuckWeapon", "", false, false):
		w.queue_free()
	for e in foes:
		e.queue_free()
	for w in get_tree().get_nodes_in_group("weapon_pickups"):
		w.queue_free()
	wall.queue_free()
	p._crosshair = Vector3.INF
	p.equip("warhammer")
	s.hold({}, 1)
	await _frames(1)


## The six worst bugs of the 2026-11-03 code review stay fixed.
func test_top_review_fixes() -> void:
	var p: Player = _arena.player
	p.god_mode = true
	await _until_on_floor()
	# Duo gifts that apply a status don't set themselves off forever.
	var foe: Enemy = _cluster(1, 4.0)[0]
	foe.health.setup(9999.0)
	var count := [0]
	var counter := func(_t, _s, _b): count[0] += 1
	Combat.status_applied.connect(counter)
	for id in ["duo_snow_sea", "duo_desert_wind", "duo_disease_sea"]:
		p.godly_gifts.owned = []
		p.godly_gifts.add_godly_gift(id)
		count[0] = 0
		Combat.apply_status(foe, "poison", 1, p)
		check(count[0] <= 4, "%s reacts once to a status (%d)" % [id, count[0]])
	Combat.status_applied.disconnect(counter)
	p.godly_gifts.owned = []
	# A full Void mark leaves no aura behind.
	var marks := int(GameData.num(GameData.status("void"), "max_stacks", 5))
	p.statuses.clear()
	p.statuses.apply("void", marks, foe)
	check(not p.statuses.has("void") and not p.statuses.auras.has("void"), "a full Void mark ends with no aura left on you")
	# Limp bodies are hit where they are.
	foe.global_position = p.global_position + Vector3(0, 0.2, -6)
	await _frames(1)
	foe.throw(Vector3(0, 6, -14), p)
	check(foe.thrown and foe._throw_ragdoll, "a thrown person goes limp")
	check(foe.collision_layer == 0, "its capsule isn't in your way while it flies")
	for i in 25:
		get_tree().paused = false
		await _frames(1)
	var body: Vector3 = foe.model.ragdoll_hips().global_position
	var gap := foe.global_position.distance_to(body)
	check(gap < 2.0 and foe.global_position.distance_to(p.global_position) > 8.0, "the unit stays with its flying body (%.1f m)" % gap)
	check(foe in Combat.enemies_in_radius(body, 2.0), "and a blast at the body hits it")
	for i in 240:
		get_tree().paused = false
		await _frames(1)
		if not foe.thrown:
			break
	check(not foe.thrown and foe.collision_layer != 0, "getting up makes it solid again")
	# A pinned animal gets up where it was pinned, not where it was launched.
	var wolf: Enemy = _arena.waves.spawn("beast_dire_wolf", p.global_position + Vector3(6, 0, 0))
	await _frames(2)
	wolf.health.setup(9999.0)
	var launched_at := wolf.global_position
	wolf.throw(Vector3(0, 3, -14), p)
	check(wolf.model is BeastModel and wolf._throw_ragdoll, "an animal goes limp too")
	for i in 25:
		get_tree().paused = false
		await _frames(1)
	var pinned_at: Vector3 = wolf.model.ragdoll_hips().global_position
	wolf._pin_to(pinned_at, Vector3(0, 0, 1))
	wolf._pinned_left = 0.05
	for i in 60:
		get_tree().paused = false
		await _frames(1)
		if not wolf.thrown:
			break
	var flat := Vector2(wolf.global_position.x - pinned_at.x, wolf.global_position.z - pinned_at.z).length()
	check(not wolf.thrown and flat < 2.0 and pinned_at.distance_to(launched_at) > 3.0, "a pinned animal gets up at the wall (%.1f m off)" % flat)


func test_pin_to_wall() -> void:
	var p: Player = _arena.player
	p.god_mode = true
	await _until_on_floor()
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 12.0, 1.0)
	col.shape = box
	wall.add_child(col)
	wall.collision_layer = 0b001
	_arena.add_child(wall)
	wall.global_position = p.global_position + Vector3(0, 4, -12)
	var shot := func(foe: Enemy, amount: float) -> void:
		var info := DamageInfo.make(amount, "Physical", DamageInfo.Kind.HEAVY, p)
		info.category = "Missile"
		info.knockback_dir = Vector3(0, 0, -1)
		Combat.deal(foe, info)
	# Alive: stuck on the wall, feet off the ground, then it drops and gets up.
	var foe: Enemy = _cluster(1, 4.0)[0]
	foe.global_position = p.global_position + Vector3(0, 0.2, -5)
	await _frames(1)
	foe.health.setup(9999.0)
	shot.call(foe, 1.0)
	check(foe.thrown and foe._pinning, "a heavy shot launches it, ready to pin")
	for i in 120:
		get_tree().paused = false
		await _frames(1)
		if foe._pinned:
			break
	check(foe._pinned and absf(foe.global_position.z - wall.global_position.z) < 2.0, "it's pinned to the wall (%.1f m away)" % absf(foe.global_position.z - wall.global_position.z))
	check(is_instance_valid(foe._pin_bolt), "with a bolt through it")
	var y := foe.global_position.y
	await _frames(30)
	check(foe.global_position.is_equal_approx(Vector3(foe.global_position.x, y, foe.global_position.z)) and foe._pinned, "and it stays there")
	foe._pinned_left = 0.02
	await _frames(4)
	check(not foe._pinned and not foe.is_dead() and not is_instance_valid(foe._pin_bolt), "then it drops and gets up")
	foe.queue_free()
	await _frames(1)
	# A melee heavy doesn't pin, and an animal can be pinned too.
	var melee: Enemy = _cluster(1, 4.0)[0]
	var punch := DamageInfo.make(1.0, "Physical", DamageInfo.Kind.HEAVY, p)
	punch.category = "Melee"
	Combat.deal(melee, punch)
	check(melee.thrown and not melee._pinning, "a melee heavy launches but doesn't pin")
	melee.queue_free()
	var cow: Enemy = _cluster(1, 4.0, "animal_cow")[0]
	cow.global_position = p.global_position + Vector3(0, 0.2, -6)
	await _frames(1)
	shot.call(cow, 1.0)
	for i in 120:
		get_tree().paused = false
		await _frames(1)
		if not is_instance_valid(cow) or cow._pinned:
			break
	check(is_instance_valid(cow) and cow._pinned and cow.model.ragdoll_hips().freeze, "an animal gets pinned too")
	if is_instance_valid(cow):
		cow.queue_free()
	# A shot that kills pins the body.
	var doomed: Enemy = _cluster(1, 4.0)[0]
	doomed.global_position = p.global_position + Vector3(0, 0.2, -5)
	await _frames(1)
	shot.call(doomed, 999999.0)
	check(doomed.is_dead(), "a killing shot")
	for i in 120:
		get_tree().paused = false
		await _frames(1)
		if not is_instance_valid(doomed) or doomed._pinned:
			break
	check(is_instance_valid(doomed) and doomed._pinned, "pins the body")
	wall.queue_free()
	await _frames(1)


func test_demon_and_wings() -> void:
	# The little demon flies in the ashlands, and its wing beat moves the winged people's wings.
	check(not GameData.unit("beast_little_demon").is_empty() and ResourceLoader.exists(ModelRegistry.own("beast_little_demon.glb")), "the little demon is in the game")
	var curve := CharacterModel.flap_curve()
	check(curve[1].size() == CharacterModel.FLAP_SAMPLES and Array(curve[1]).max() - Array(curve[1]).min() > 0.2, "its wing beat is read from its own animation")
	var m := CharacterModel.new()
	add_child(m)
	check(m.setup(ModelRegistry.GEN + "monster_harpy.glb"), "the harpy loads")
	check(m._wings.size() == 4, "the harpy has wing bones (%d)" % m._wings.size())
	var bone: int = m._wings[0][0]
	var rest := m._skeleton.get_bone_pose_rotation(bone)
	m.flapping = true
	var moved := 0.0
	for i in 20:
		m._beat_wings(0.05)
		moved = maxf(moved, rest.angle_to(m._skeleton.get_bone_pose_rotation(bone)))
	check(moved > 0.1, "and beats them while it flies (%.2f rad)" % moved)
	m.queue_free()


func test_combat_feel() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	check(is_equal_approx(t.base_health, 400.0), "you have a third less health (400)")
	# Jump: a tap is 100%, held 2 s it's 130%.
	var tap := PlayerIntent.new()
	tap.jump = true
	var crouched := 0
	var up := p._jump_now(tap, 0.016, true)
	tap.jump = false
	while not up and crouched < 100:
		crouched += 1
		up = p._jump_now(tap, 0.016, true)
	check(up and is_equal_approx(p._jump_power, 1.0) and crouched * 0.016 >= t.jump_crouch_min - 0.02, "a tapped jump is a normal jump, after bending the knees a moment (%d frames)" % crouched)
	var hold := PlayerIntent.new()
	hold.jump = true
	hold.jump_held = true
	var jumped := p._jump_now(hold, 0.016, true)
	hold.jump = false
	for i in 200:
		if jumped:
			break
		jumped = p._jump_now(hold, 0.016, true)
	check(jumped and is_equal_approx(p._jump_power, t.jump_charge_max), "held for 2 s it jumps 130%% (%.2f)" % p._jump_power)
	var foe: Enemy = _cluster(1, 20.0, "barb_warlord")[0]
	foe.global_position = p.global_position + p.facing * 20.0
	await _frames(2)
	# Bosses (sheet role Boss or Miniboss) show a health bar when they fight you.
	foe.target = p
	_arena.hud._boss_look = 0.0
	await _frames(2)
	check(_arena.hud._boss_box.visible and _arena.hud.boss == foe, "a boss fighting you shows its health bar")
	foe.queue_free()
	p.setup("human", "forge_god", "warhammer")


func test_end_of_run_exit() -> void:
	# Playtest 2026-11-05: the final kill's level-up took the mouse from "Back to the start screen".
	var hud: Hud = _arena.hud
	hud._open_choice("test", "A choice", ["a"], ["1.  A"])
	hud.show_action("Back to the start screen", func(): pass)
	hud._pick(0)
	check(hud.mouse_after_choice() == Input.MOUSE_MODE_VISIBLE, "closing a menu leaves the mouse free while the end-of-run button waits")
	hud._action.queue_free()
	await _frames(1)
	check(hud.mouse_after_choice() == Input.MOUSE_MODE_CAPTURED, "otherwise the mouse goes back to the camera")
	check(FileAccess.get_file_as_string("res://scripts/arena/arena.gd").contains("if not Run.active or Run.state.pending_level_ups"), "no level-up opens after the run is over")


func test_blood_and_falls() -> void:
	var p: Player = _arena.player
	p.god_mode = true
	var foe: Enemy = _cluster(1, 6.0)[0]
	await _frames(2)
	foe.health.setup(1000.0)
	Combat.deal(foe, DamageInfo.make(400.0, "Physical", DamageInfo.Kind.HEAVY, p))
	check(foe.model._blood > 0.3 and foe.model._tinted, "a hurt enemy is bloody (%.2f)" % foe.model._blood)
	Combat.deal(foe, DamageInfo.make(400.0, "Physical", DamageInfo.Kind.HEAVY, p))
	check(foe.model._blood > 0.7, "and bloodier with the next hit (%.2f)" % foe.model._blood)
	# Falling from high up hurts an enemy, more the farther it falls.
	var hp := foe.health.hp
	foe._landed(GameData.tuning.fall_safe_speed - 1.0)
	check(foe.health.hp == hp, "a small drop doesn't hurt")
	foe._landed(GameData.tuning.fall_safe_speed + 10.0)
	var small_fall := hp - foe.health.hp
	hp = foe.health.hp
	foe._landed(GameData.tuning.fall_safe_speed + 20.0)
	check(small_fall > 0.0 and hp - foe.health.hp > small_fall * 1.5, "a big fall hurts, a bigger one more (%.0f, %.0f)" % [small_fall, hp - foe.health.hp])
	var pools := Combat.effects_root.get_children().size()
	Combat.deal(foe, DamageInfo.make(99999.0, "Physical", DamageInfo.Kind.HEAVY, p))
	await _frames(2)
	check(Combat.effects_root.get_children().size() > pools, "it dies in a pool of blood")


func test_art_checklist() -> void:
	var app = load("res://tests/art_checklist.gd").new()
	app.models_dir = "user://checklist_test/"
	app.sounds_dir = "user://checklist_test/sounds/"
	app.state_path = OS.get_user_data_dir() + "/checklist_test.json"
	var items: Array = app.gather()
	var groups := {}
	for i in items:
		groups[i.group] = true
	check(items.size() > 300 and groups.has("Army units") and groups.has("Animations (humanoid rig)") and groups.has("Sounds (not in the game yet)"), "the checklist lists models, animations and sounds (%d)" % items.size())
	var by_file := func(f: String) -> Dictionary:
		var found := items.filter(func(i): return i.file == f)
		return found[0] if not found.is_empty() else {}
	var axe: Dictionary = by_file.call("dwarf/guardian/weapon.glb")
	check(not axe.is_empty() and axe.group == "Race: Dwarf" and not by_file.call("dwarf/guardian/shield.glb").is_empty()
		and not by_file.call("dwarf/rogue/body.glb").is_empty() and by_file.call("dwarf/knife.glb").is_empty() and by_file.call("dwarf/fists.glb").is_empty(),
		"each race lists every class's body and weapon and the Guardian's shield; no throwing knife or fists")
	check(app.current(axe) == ModelRegistry.OWN + "dwarf/guardian/weapon.glb", "and shows what the game uses now (the user's dwarf axe)")
	var soldier: Dictionary = by_file.call(str(GameData.rows("army_units")[0].model_file))
	check(app.target(soldier).begins_with("user://checklist_test/own/%s/people/" % soldier.dir.get_slice("/", 0)), "an army unit goes in its race's people folder")
	var dwarf: Dictionary = items.filter(func(i): return i.file == "race_dwarf.glb")[0]
	var gen_copy := ProjectSettings.globalize_path("user://checklist_test/gen/race_dwarf.glb")
	DirAccess.make_dir_recursive_absolute(gen_copy.get_base_dir())
	DirAccess.copy_absolute(ProjectSettings.globalize_path(ModelRegistry.GEN + "race_dwarf.glb"), gen_copy)
	check(not app.is_done(dwarf), "a model not made yet isn't ticked")
	var said: String = app.import_file(dwarf, ProjectSettings.globalize_path(ModelRegistry.GEN + "race_dwarf.glb"))
	check(FileAccess.file_exists("user://checklist_test/own/race_dwarf.glb") and not FileAccess.file_exists(gen_copy), "importing puts yours in models/own and deletes the generated one (%s)" % said)
	check(app.is_done(dwarf) and FileAccess.file_exists(app.state_path), "and ticks it, saved")
	check(app.import_file(dwarf, "C:/nowhere/x.glb").begins_with("No file"), "a wrong path says so")
	check(app.import_file(items.filter(func(i): return i.kind == "sound")[0], gen_copy.get_base_dir() + "/../own/race_dwarf.glb").begins_with("This needs a .wav"), "a sound needs a .wav")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://checklist_test/own/race_dwarf.glb"))
	DirAccess.remove_absolute(app.state_path)
	app.plant_garden()
	check(app.garden_spots.size() > 500 and app.garden_spots.has("res://textures/grass.png") and app.garden_spots.has("res://textures/stone_masonry.png"),
		"the texture garden plants every picture in the game (%d)" % app.garden_spots.size())
	app.free()


func test_practice_picks() -> void:
	var gods: Array = ArenaMenu.elements()
	check(gods.size() >= 4 and not gods.any(func(g): return g in GameData.SHELVED_GODS), "Practice offers every kept god (%s)" % ", ".join(gods))
	var god: String = gods.back()
	_arena.queue_free()
	await _frames(1)
	Flow.practice_god = god
	_arena = ARENA.instantiate()
	_arena.auto_start = false
	add_child(_arena)
	await _frames(2)
	check(Run.state.race_id == "dwarf" and Run.state.god_id == god and Run.state.weapon_id == GameData.FISTS,
		"Practice starts as a dwarf with the god picked, bare-handed (%s, %s)" % [Run.state.god_id, Run.state.weapon_id])
	check(_arena.player.god_id == god and god in _arena.offer_gods, "and offers that god's gifts")
	Flow.practice_god = ""


func test_myths() -> void:
	var myths := ["animal_unicorn", "animal_jackalope", "animal_pegasus", "animal_phoenix", "animal_mermaid", "animal_hippocampus", "beast_chimera", "beast_cerberus", "beast_basilisk",
		"beast_feathered_serpent", "beast_leviathan", "monster_cyclops", "monster_frost_giant", "monster_gorgon", "monster_mummy", "monster_harpy"]
	for id in myths:
		var row := GameData.unit(id)
		var look: Dictionary = ModelRegistry.for_beast(id) if str(id).begins_with("beast_") or str(id).begins_with("animal_") else ModelRegistry.for_unit(id)
		check(not row.is_empty(), "%s has a row" % id)
		check(look.has("model") and id in str(look.model), "%s has its own model" % id)
	var p: Player = _arena.player
	p.god_mode = true
	# Harpies fly on two legs; a feathered serpent flies with no rig at all.
	for id in ["monster_harpy", "beast_feathered_serpent", "animal_pegasus"]:
		var e := Enemy.new()
		e.setup(id, p, _arena.director)
		_arena.add_child(e)
		e.global_position = p.global_position + Vector3(60, 0, 0)  # beyond 25 m it stays up, not diving at you
		await _frames(90)
		check(e.flying and e.model != null and e.global_position.y > p.global_position.y + 5.0, "%s takes to the air" % id)
		e.queue_free()


func test_glide() -> void:
	var p: Player = _arena.player
	await _until_on_floor()
	var heights := {}
	for race in ["dwarf", "bird"]:
		p.setup(race, "forge_god")
		await _until_on_floor()
		var s := _scripted()
		var floor_y := p.global_position.y
		s.press("jump")
		var top := floor_y
		var fastest := 0.0
		for i in 300:
			await _frames(1)
			top = maxf(top, p.global_position.y)
			fastest = minf(fastest, p.velocity.y)
			if i > 10 and p.is_on_floor():
				break
		heights[race] = [top - floor_y, fastest]
	check(heights.bird[0] > heights.dwarf[0] * 2.0, "bird people jump much higher (%.1f m vs %.1f m)" % [heights.bird[0], heights.dwarf[0]])
	check(heights.bird[1] >= -GameData.tuning.glide_fall_speed - 0.5 and heights.dwarf[1] < heights.bird[1], "and glide down slowly (%.1f m/s vs %.1f m/s)" % [heights.bird[1], heights.dwarf[1]])
	p.setup("dwarf", "forge_god")


func test_checklist_viewer() -> void:
	# The art checklist is also the model viewer (merged from the asset viewer, user 2026-11-17).
	var v: Node = load("res://tests/art_checklist.tscn").instantiate()
	add_child(v)
	check(v._list.item_count > 300 and v._import_box.visible, "it opens on the art to make (%d rows)" % v._list.item_count)
	v._source.select(1)
	v._fill()
	check(v._list.item_count > 100, "All game models lists every model (%d)" % v._list.item_count)
	v.select({"view": "res://models/own/mount_war_ram.glb"})
	check(not v._import_box.visible, "a model off the checklist just shows, no import box")
	check(range(v._clips.item_count).any(func(i): return v._clips.get_item_text(i) == "Attack_Headbutt  (attack)"), "an animal's clip says what the game uses it for")
	v.play_clip("Attack_Headbutt")
	var bones: Skeleton3D = v._body.model.find_children("*", "Skeleton3D", true, false)[0]
	var head := bones.find_bone("Head")
	v.scrub(0.0)
	await _frames(2)
	var start := bones.get_bone_global_pose(head).origin
	v.scrub(0.38)
	await _frames(2)
	check(bones.get_bone_global_pose(head).origin.distance_to(start) > 0.1 and is_equal_approx(v._body.anim.current_animation_position, 0.38), "dragging the time bar shows that moment and holds it")
	v.show_model("res://models/gen/race_dwarf.glb")
	check(v._clips.item_count > 20 and v._body.anim.is_playing(), "a person plays the shared animations (%d)" % v._clips.item_count)
	v.play_clip("Running_A")
	v.show_model("res://models/gen/race_dwarf.glb")
	check(v._clip_name == "Running_A" and v._body.anim.current_animation == "Running_A", "the chosen clip stays chosen on the next model, to compare")
	v.show_model("res://models/own/horde_slime.glb")
	check(v._body.anim != null and v._clips.item_count > 0, "an object-animated model plays its own clips")
	v.show_model("res://models/gen/beast_kraken.glb")
	v.play_clip("Death_A")
	v.play_clip("Hit_A")
	check(v._body.anim == null and v._clips.item_count == v.CODE_MOVES.size() and not v._beast._dead, "a creature moved in code lists its moves, and gets up after dying")
	v.show_model("res://models/gen/world/well.glb")
	check(v._clips.item_count == 0, "a prop just stands there")
	var all: int = v._list.item_count
	v._filter.text = "mount_war"
	v._fill()
	check(v._list.item_count > 0 and v._list.item_count < all, "the search box narrows the list (%d)" % v._list.item_count)
	v._filter.text = ""
	v._source.select(2)
	v._fill()
	for ext in ["glb", "fbx", "png"]:  # asset_library/ isn't in git: only where it exists
		var found: Array = v._library.filter(func(f): return f.get_extension().to_lower() == ext)
		if not found.is_empty():
			v.show_model(found[0])
			check((v._picture.texture != null) if ext == "png" else (v._body != null and v._body.model != null), "the asset library opens a .%s (%s)" % [ext, found[0].get_file()])
	v.free()


func test_element_effects() -> void:
	var missing := (GameData.lists.get("damage_types", []) as Array).filter(func(e): return not ElementFx.STYLES.has(e))
	check(missing.is_empty(), "every damage type has its own effect (missing: %s)" % [missing])
	var e: Enemy = _cluster(1, 3.0, "barb_warlord")[0]
	var before := _arena.get_children().filter(func(c): return c is CPUParticles3D).size()
	Combat.deal(e, DamageInfo.make(5.0, "Fire", DamageInfo.Kind.LIGHT, _arena.player))
	var after := _arena.get_children().filter(func(c): return c is CPUParticles3D).size()
	check(after > before, "a fire hit makes a burst of embers")
	Combat.apply_status(e, "fire", 1, _arena.player)
	check(e.get_node_or_null("Aura_Fire") != null, "a burning enemy carries flames")
	e.statuses.remove("fire")
	await _frames(2)
	check(not e.statuses.auras.has("fire"), "the flames go when the burning ends")
	check(ElementFx.color("Ice") != ElementFx.color("Fire"), "elements have their own colors")


## The Controls menu's rebinding: a new key replaces the old one, a clash unbinds
## the other action, and reset brings the defaults back.
func test_controls_rebind() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_G
	Controls.rebind("jump", key, false)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_G
	ev.pressed = true
	check(InputMap.event_is_action(ev, "jump"), "G now jumps")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	check(not InputMap.event_is_action(space, "jump"), "Space no longer jumps")
	var stolen := Controls.rebind("dodge", key, false)
	check(stolen == "jump" and InputMap.event_is_action(ev, "dodge") and not InputMap.event_is_action(ev, "jump"),
		"binding G to dodge takes it off jump (stolen from %s)" % stolen)
	check(Controls.binding_text("dodge") == "G", "the menu shows the new key (%s)" % Controls.binding_text("dodge"))
	Controls.reset_to_defaults(false)
	Controls.load_saved()  # the player's real saved bindings, untouched by this test
	check(InputMap.event_is_action(space, "jump") or FileAccess.file_exists(Controls.SAVE_PATH), "reset puts Space back on jump")


## The code audit of 2026-11-16: each check fails if its fix is undone.
func test_audit_fixes() -> void:
	var p: Player = _arena.player
	var d: CrowdDirector = _arena.director
	# Units freed alive (debug next-wave) leave the crowd, or the stride counts them forever.
	var gone: Array = []
	for i in 150:
		var e := Enemy.new()
		e.setup("barb_raider", p, d)
		_arena.add_child(e)
		gone.append(e)
	await _frames(1)
	for e in gone:
		e.queue_free()
	await _frames(2)
	d.separation(p)
	check(d.enemies.size() < 100 and Enemy.crowd_stride == 1, "freed warriors leave the crowd (%d left, stride %d)" % [d.enemies.size(), Enemy.crowd_stride])
	# Hit searches use the crowd grid: they find a unit spawned and moved this very frame.
	var fresh: Enemy = _arena.waves.spawn("barb_raider")
	fresh.global_position = p.global_position + Vector3(30, 0, 30)
	check(fresh in Combat.enemies_in_radius(fresh.global_position, 1.0) and not fresh in Combat.enemies_in_radius(p.global_position, 3.0),
		"hit searches find who is near, through the crowd grid")
	# The Void mark switches conditional passives off too.
	p.godly_gifts.add_godly_gift("forge_tempered")  # bonus damage on large enemies
	var big: Enemy = _cluster(1, 3.0, "barb_warlord")[0]
	var bonus := p.godly_gifts.damage_bonus_pct(big)
	p.godly_gifts.suppress(3.0)
	check(bonus > 0.0 and p.godly_gifts.damage_bonus_pct(big) == 0.0, "a full Void mark switches Tempered off (%.0f%% before)" % bonus)
	# xp_scale 0 in the Inspector must not hang the game.
	var scale := GameData.tuning.xp_scale
	GameData.tuning.xp_scale = 0.0
	var s := RunState.new()
	var ups := LevelSystem.add_xp(s, 5.0)
	GameData.tuning.xp_scale = scale
	check(ups == 5 and s.xp == 0, "xp_scale 0 levels once per point instead of forever (%d)" % ups)


## The second audit (2026-11-17).
func test_audit_fixes_2() -> void:
	var p: Player = _arena.player
	# A dodge during a sword lunge keeps passing through enemies.
	p.collision_mask = 0b001
	p._lunge_step(0.5, Vector3.ZERO)
	check(p.collision_mask == 0b001, "a lunge step keeps the dodge's collision mask")
	p.collision_mask = 0b101
	# An enemy's arrow hits you.
	var godly: bool = p.god_mode
	p.god_mode = false
	var hp := p.health.hp
	var shot := Projectile.fire(p.global_position + Vector3(0, 1, -3), Vector3(0, 0, 1), 30.0, DamageInfo.make(5.0, "Physical", DamageInfo.Kind.ENEMY, null), Color.WHITE)
	shot.hostile = true
	shot.player = p
	await _frames(30)
	check(p.health.hp < hp, "an enemy arrow hits you (%.0f -> %.0f)" % [hp, p.health.hp])
	p.god_mode = godly
	# Rigs that rest their shoulders differently get their own animation library (the cat's and the minotaur's).
	var rigs: Array = []
	for race in ["cat", "minotaur"]:
		var n: Node = (load(ModelRegistry.own(GameData.race(race).get("player_model_file"))) as PackedScene).instantiate()
		rigs.append(CharacterModel._shape_key(n.find_children("*", "Skeleton3D", true, false)[0]))
		n.free()
	check(rigs[0] != rigs[1], "the cat's and the minotaur's rigs don't share animations")


## Combat feel plan, part 1 (user, 2026-11-18): round blood drops, stains that stay, a kill's cloud,
## the gore slider, armour sparks and pieces, the tumble, the camera kick and the swing trail.
func test_hit_effects() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	await _until_on_floor()
	var foe: Enemy = _cluster(1, 3.0)[0]
	await _frames(2)
	var stains := Vfx.stain_count()
	var hit := DamageInfo.make(5.0, "Physical", DamageInfo.Kind.LIGHT, p)
	Combat.deal(foe, hit)
	var drops: Array = Combat.effects_root.find_children("*", "CPUParticles3D", true, false).filter(func(e): return e.mesh is SphereMesh)
	check(not drops.is_empty(), "blood comes out as round drops")
	check(Vfx.stain_count() > stains, "a hit leaves stains on the ground (%d -> %d)" % [stains, Vfx.stain_count()])
	check(Combat.camera_rig._kick.length() > 0.01, "your blow kicks the camera")
	stains = Vfx.stain_count()
	Combat.deal(foe, DamageInfo.make(9999.0, "Physical", DamageInfo.Kind.LIGHT, p))
	check(Combat.effects_root.find_children("*", "CPUParticles3D", true, false).any(func(e): return e.amount == roundi(t.blood_kill_drops * t.gore_amount)), "a kill throws a cloud of blood")
	check(Vfx.stain_count() > stains, "and more stains")
	# The slider: no gore at 0.
	var gore := t.gore_amount
	t.gore_amount = 0.0
	var parts: int = Combat.effects_root.find_children("*", "CPUParticles3D", true, false).size()
	Vfx.blood(p.global_position + Vector3.UP, Vector3.FORWARD, 30)
	check(Combat.effects_root.find_children("*", "CPUParticles3D", true, false).size() == parts, "the gore slider at 0 turns blood off")
	t.gore_amount = gore
	# The cap: past blood_stain_max the oldest go.
	var cap := t.blood_stain_max
	t.blood_stain_max = 5
	for i in 6:
		Vfx.blood_stains(p.global_position, Vector3.FORWARD, 3)
	check(Vfx.stain_count() <= 5, "stains stop at the cap (%d)" % Vfx.stain_count())
	t.blood_stain_max = cap
	# Armour: a man-at-arms sparks, and a killing blow knocks a piece off.
	var knight: Enemy = _cluster(1, 3.0, "human_man_at_arms")[0]
	await _frames(2)
	check(knight.wears_metal() and not foe.wears_metal(), "a man-at-arms wears metal, a raider doesn't")
	var sparks: int = Combat.effects_root.find_children("*", "CPUParticles3D", true, false).filter(func(e): return e.amount == t.metal_sparks).size()
	Combat.deal(knight, DamageInfo.make(9999.0, "Physical", DamageInfo.Kind.LIGHT, p))
	check(Combat.effects_root.find_children("*", "CPUParticles3D", true, false).filter(func(e): return e.amount == t.metal_sparks).size() > sparks, "a hit on armour sparks")
	check(Combat.effects_root.find_children("*", "RigidBody3D", true, false).size() > 0, "and the killing blow knocks a piece of armour off")
	# The tumble: a launched body turns end over end.
	var flier: Enemy = _cluster(1, 4.0)[0]
	await _frames(2)
	flier.throw(Vector3(9.0, 4.0, 0.0), p)
	var hips: PhysicsBody3D = flier.model.ragdoll_hips() if flier.model != null else null
	if hips != null:
		check((hips as PhysicalBone3D).angular_velocity.length() > 2.0, "a launched body tumbles (%.1f rad/s)" % (hips as PhysicalBone3D).angular_velocity.length())
	# The trail: a swing leaves a ribbon, tinted toward your element.
	p.state = Player.State.LIGHT
	await _frames(6)
	check(p.trail != null and (p.trail.point_count() >= 2 or p.visual.weapon_tip() == null), "a swing leaves a trail (%d points)" % (p.trail.point_count() if p.trail != null else -1))
	check(p.trail.color != Color(0.82, 0.84, 0.88) or p.element() == "Physical", "steel tinged by your element")
	p.state = Player.State.FREE
	await _frames(20)
	check(p.trail.point_count() == 0, "and it fades when the swing ends")


## Combat feel plan, part 2: melee light attacks 25% faster (classes keep their order), and the
## charge bar under the crosshair while a heavy charges.
func test_rhythm_and_charge() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	await _until_on_floor()
	var paces := {}
	for w in ["warhammer", "greatsword", "twin_khopesh", "naginata"]:
		p.equip(w)
		paces[w] = p._light_duration()
	check(paces["twin_khopesh"] < paces["greatsword"] and paces["greatsword"] < paces["warhammer"], "Twin is fastest, Heavy slowest: %s" % str(paces))
	var aps := GameData.num(p._weapon, "weapon_attacks_per_sec", 1.2)
	check(is_equal_approx(p._light_duration(), 1.0 / (aps * p.stats.mult("attack_speed_pct") * p.moveset.swing_speed() * t.light_speed_mult)), "a light attack is light_speed_mult faster")
	var s := _scripted()
	s.press("heavy")
	var frames := ceili((t.heavy_windup + t.heavy_charge_time) * 60.0) + 20
	s.hold({"heavy_held": true}, frames)
	p.stamina = 1000.0
	var shown := false
	var visible := true
	var colors := {}
	for i in frames + 1:
		await _frames(1)
		if p.charge_shown() >= 0.0:
			shown = true
			await get_tree().process_frame
			colors[_arena.hud._charge_fill.color.to_html()] = true
			visible = visible and _arena.hud._charge.visible
	check(visible, "the charge bar shows while you charge")
	check(shown, "holding a heavy charges it")
	check(colors.size() >= 2, "the bar changes color as it fills (%d colors)" % colors.size())
	await _frames(60)
	check(p.charge_shown() < 0.0 and not _arena.hud._charge.visible, "and hides when the blow lands")


## Combat feel plan, part 3: each weapon class launches its own way; spells land like heavy blows.
func test_weapon_and_spell_feel() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	await _until_on_floor()
	var k := {}
	for c in ["Heavy", "Blade", "Twin", "Polearm"]:
		k[c] = WeaponMoveset.for_class(c).launch_scale()
	check(k["Heavy"] > k["Polearm"] and k["Polearm"] > k["Blade"] and k["Blade"] > k["Twin"], "the hammer throws hardest, twin blades least: %s" % str(k))
	var speeds := {}
	for w in ["warhammer", "twin_khopesh"]:
		p.equip(w)
		var foe: Enemy = _cluster(1, 3.0)[0]
		await _frames(2)
		var info := DamageInfo.make(1.0, "Physical", DamageInfo.Kind.HEAVY, p)
		info.knockback_dir = Vector3.FORWARD
		foe.launch_from_hit(info)
		var hips: PhysicsBody3D = foe.model.ragdoll_hips() if foe.model != null else null
		speeds[w] = Vector2(foe._throw_vel.x, foe._throw_vel.z).length() if hips == null else Vector2((hips as PhysicalBone3D).linear_velocity.x, (hips as PhysicalBone3D).linear_velocity.z).length()
		foe.queue_free()
		await _frames(1)
	check(speeds["warhammer"] > speeds["twin_khopesh"], "a hammer's launch flies farther than a twin blade's (%s)" % str(speeds))
	p.equip("warhammer")


## Combat feel plan, part 4: hold light attack to grab a minion; keep holding to crush it, right
## click to hurl it (it hits whoever it passes), let go to drop it; it shields you from the front.
func test_grab_crush_hurl() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	p.god_mode = false
	await _until_on_floor()
	var s := _scripted()
	var grab_frames := ceili(t.grab_hold_time * 60.0) + 3
	# A tap still swings at once.
	s.press("light")
	await _frames(2)
	check(p.state == Player.State.LIGHT, "a tap swings right away")
	await _frames(60)
	# Hold: grab and crush.
	var foe: Enemy = _cluster(1, 1.6)[0]
	await _frames(2)
	s.hold({"light": true, "light_held": true}, 1)
	s.hold({"light_held": true}, grab_frames)
	await _frames(grab_frames + 1)
	check(p.state == Player.State.GRAB and p.grabber.held == foe and foe.held_by == p, "holding light attack grabs the minion in reach")
	check(foe.global_position.distance_to(p.grabber.hold_point()) < 0.3, "it hangs in your hand")
	var big: Enemy = _cluster(1, 1.6, "barb_warlord")[0]
	check(not Grabber.grabbable(big) or GameData.text(big.unit, "role") not in ["Boss", "Champion", "Large"], "only minions can be grabbed")
	big.queue_free()
	# The shield: a blow from the front lands on the minion.
	var hp := p.health.hp
	var blow := DamageInfo.make(10.0, "Physical", DamageInfo.Kind.ENEMY, foe)
	blow.knockback_dir = -p.facing
	var minion_hp := foe.health.hp
	Combat.deal(p, blow)
	check(is_equal_approx(p.health.hp, hp) and foe.health.hp < minion_hp, "a blow from the front lands on the minion you hold")
	s.hold({"light_held": true}, ceili(t.crush_time * 60.0) + 5)
	await _frames(ceili(t.crush_time * 60.0) + 6)
	check(foe.is_dead() and p.state != Player.State.GRAB, "keep holding and it's crushed to death")
	await _frames(10)
	# Drop: let go and it stands again.
	var dropped: Enemy = _cluster(1, 1.6)[0]
	await _frames(2)
	s.hold({"light": true, "light_held": true}, 1)
	s.hold({"light_held": true}, grab_frames)
	await _frames(grab_frames + 1)
	check(p.grabber.held == dropped, "grabbed again")
	s.hold({}, 2)
	await _frames(3)
	check(dropped.held_by == null and not dropped.is_dead() and p.state == Player.State.FREE, "let go and it drops")
	await _frames(40)
	# Hurl: right click throws it into the one behind.
	var thrown: Enemy = _cluster(1, 1.6)[0]
	var behind: Enemy = _cluster(1, 5.0)[0]
	behind.global_position = p.global_position + p.facing * 5.0
	thrown.global_position = p.global_position + p.facing * 1.6
	await _frames(2)
	s.hold({"light": true, "light_held": true}, 1)
	s.hold({"light_held": true}, grab_frames)
	await _frames(grab_frames + 1)
	check(p.grabber.held == thrown, "grabbed one to throw")
	var behind_hp := behind.health.hp
	s.hold({"light_held": true, "heavy": true}, 1)
	await _frames(3)
	check(thrown.held_by == p and p.grabber.throwing(), "right click winds up the throw: it's still in your hand")
	s.hold({"light_held": true}, 12)
	await _frames(12)
	check(thrown.held_by == null and thrown.thrown and thrown._hurled, "and lets go on the throw's release frame")
	await _frames(40)
	check(behind.health.hp < behind_hp or behind.is_dead() or behind.thrown, "and it hits the one behind (%.0f -> %.0f)" % [behind_hp, behind.health.hp])
	# Against a wall it bursts, hurting whoever stands by.
	await _frames(60)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 4, 0.5)
	shape.shape = box
	wall.add_child(shape)
	_arena.add_child(wall)
	wall.global_position = p.global_position + p.facing * 6.0 + Vector3.UP * 2.0
	wall.look_at(wall.global_position + p.facing, Vector3.UP)
	var splat: Enemy = _cluster(1, 1.6)[0]
	splat.global_position = p.global_position + p.facing * 1.6
	var bystander: Enemy = _cluster(1, 5.0)[0]
	bystander.global_position = p.global_position + p.facing * 5.0 + p.facing.cross(Vector3.UP) * 2.0
	await _frames(2)
	var by_hp := bystander.health.hp
	s.hold({"light": true, "light_held": true}, 1)
	s.hold({"light_held": true}, grab_frames)
	s.hold({"light_held": true, "heavy": true}, 1)
	await _frames(grab_frames + 50)
	check(splat.is_dead() and not splat._hurled, "hurled into a wall, it bursts")
	check(bystander.health.hp < by_hp or bystander.is_dead() or bystander.thrown, "and hurts whoever stands by the wall")
	wall.queue_free()


## Combat feel plan, part 5: the chain grab. A held light attack with no minion in reach hooks
## one in the crosshair up to chain_range away; wheel back reels it in, a flick down slams it, a
## sweep sideways swings it (let go to fling), letting go drops it; a big one pulls you in for a drop kick.
func test_chain_grab() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	p.god_mode = true
	await _until_on_floor()
	var s := _scripted()
	var grab_frames := ceili(t.grab_hold_time * 60.0) + 2
	var fly_frames := ceili(10.0 / t.chain_speed * 60.0) + 3
	var hook := func(e: Enemy) -> void:
		e.global_position = p.global_position + p.facing * 8.0
		await _frames(2)
		s.hold({"light": true, "light_held": true}, 1)
		s.hold({"light_held": true}, grab_frames + fly_frames)
		await _frames(grab_frames + fly_frames)
	# Reel in.
	var foe: Enemy = _cluster(1, 8.0)[0]
	foe.health.hp = 10000.0  # a light hit wouldn't kill it, so it lands in your hand
	await hook.call(foe)
	check(p.state == Player.State.CHAIN and p.chain.mode == Chain.Mode.HOOKED and foe.held_by == p, "a held light attack hooks a minion 8 m away")
	var blow := DamageInfo.make(1.0, "Physical", DamageInfo.Kind.HEAVY, p)
	blow.knockback = 10.0
	blow.knockback_dir = Vector3.RIGHT
	Combat.deal(foe, blow)
	foe.throw(Vector3(6, 4, 0), p)  # what a launching blow or a body flying into it does
	s.hold({"light_held": true}, 3)
	await _frames(3)
	check(foe.held_by == p and not foe.thrown and (foe.model == null or not foe.model.is_ragdoll()) and p.chain.mode == Chain.Mode.HOOKED,
		"hit while on the chain, it stays on the chain (user, 2026-11-20)")
	var links: int = p.chain._line.multimesh.visible_instance_count if p.chain._line != null else 0
	check(p.chain._line != null and p.chain._line.visible and links >= 30, "you see the chain: %d links from hand to hook" % links)
	var in_way: Enemy = _cluster(1, 8.0)[0]
	var right := p.facing.cross(Vector3.UP)
	in_way.global_position = p.global_position + p.facing * 4.0 + right * 0.3
	in_way.health.hp = 10000.0
	var in_way_hp := in_way.health.hp
	var in_way_from := in_way.global_position
	s.hold({"light_held": true, "wheel_back": true}, 1)
	s.hold({"light_held": true}, 40)
	await _frames(41)
	check(p.state == Player.State.GRAB and p.grabber.held == foe, "the wheel reels it into your hand (state %d)" % p.state)
	check(in_way.health.hp < in_way_hp and (in_way.state == Enemy.State.DOWN or in_way.thrown), "and it knocks down and hurts the one in its path (state %d)" % in_way.state)
	var shoved: Vector3 = in_way.global_position - in_way_from
	check(shoved.dot(right) > 3.0 and shoved.dot(right) > absf(shoved.dot(p.facing)), "knocked aside, not back (%.1f m aside, %.1f m along)" % [shoved.dot(right), shoved.dot(p.facing)])
	s.hold({}, 2)
	await _frames(3)
	foe.queue_free()  # out of the way: a minion at your feet would be grabbed by hand next
	in_way.queue_free()
	await _frames(40)
	# Reel in one a light hit would kill: you punch it and it bursts.
	var weak: Enemy = _cluster(1, 8.0)[0]
	weak.health.hp = 1.0
	await hook.call(weak)
	s.hold({"light_held": true, "wheel_back": true}, 1)
	s.hold({"light_held": true}, 40)
	await _frames(41)
	check(weak.is_dead() and not weak.visible and p.state == Player.State.FREE, "reel in a weak one and your punch bursts it")
	s.hold({}, 2)
	await _frames(30)
	# Right click: a kick that launches a small one.
	var kicked: Enemy = _cluster(1, 8.0)[0]
	kicked.health.hp = 10000.0
	await hook.call(kicked)
	s.hold({"light_held": true, "heavy": true}, 1)
	s.hold({"light_held": true}, 20)
	await _frames(21)
	check(kicked.health.hp < 10000.0 and kicked.thrown and kicked.held_by == null, "right click kicks it: hurt and launched")
	s.hold({}, 2)
	await _frames(60)
	if is_instance_valid(kicked):
		kicked.queue_free()
	await _frames(2)
	# Let go: it drops.
	var loose: Enemy = _cluster(1, 8.0)[0]
	await hook.call(loose)
	s.hold({"light_held": true}, 30)
	await _frames(30)
	var mid: Vector3 = p.chain._rope[Chain.ROPE_NODES / 2]
	var straight: Vector3 = (p.chain.hand() + p.chain._target_point()) * 0.5
	check(mid.y < straight.y - 0.1, "the chain sags under its weight (%.2f m)" % (straight.y - mid.y))
	s.hold({}, 2)
	await _frames(3)
	check(loose.held_by == null and p.state == Player.State.FREE and not loose.is_dead(), "let go and the chain drops it")
	loose.queue_free()
	await _frames(30)
	# Slam: a flick down.
	var slammed: Enemy = _cluster(1, 8.0)[0]
	var near: Enemy = _cluster(1, 8.0)[0]
	await hook.call(slammed)
	near.global_position = slammed.global_position + Vector3(1.0, 0, 0)
	var near_hp := near.health.hp
	s.hold({"light_held": true, "aim_pitch": 0.0}, 1)
	s.hold({"light_held": true, "aim_pitch": -0.25}, 1)
	s.hold({"light_held": true, "aim_pitch": -0.25}, 30)
	await _frames(32)
	check(p.state == Player.State.FREE and slammed.held_by == null, "a flick down slams it")
	check(near.health.hp < near_hp or near.is_dead() or near.thrown, "and the burst hurts the one beside it")
	s.hold({}, 2)
	await _frames(40)
	for e in [slammed, near]:
		if is_instance_valid(e):
			e.queue_free()
	await _frames(2)
	# Swing and fling.
	var swung: Enemy = _cluster(1, 8.0)[0]
	var swept: Enemy = _cluster(1, 8.0)[0]
	swept.global_position = p.global_position - p.facing * t.chain_swing_radius
	await hook.call(swung)
	var swept_hp := swept.health.hp
	var yaw := s.aim_yaw
	for i in 40:
		yaw += 0.15
		s.hold({"light_held": true, "aim_yaw": yaw}, 1)
	await _frames(40)
	check(p.chain.mode == Chain.Mode.SWING, "a sweep sideways swings it around you")
	check(swept.health.hp < swept_hp or swept.is_dead() or swept.thrown, "and it hits what it sweeps")
	p.chain._swing_turned = TAU * 3.0  # three turns in
	s.hold({"light_held": true, "aim_yaw": yaw}, 30)
	await _frames(30)
	check(p.chain._spin > t.chain_swing_spin + 2.0 * t.chain_swing_spin_per_turn, "every turn of the swing spins it faster (%.1f rad/s)" % p.chain._spin)
	s.hold({"aim_yaw": yaw, "aim_pitch": 1.0}, 2)
	await _frames(3)
	check(swung._hurled and swung.held_by == null, "let go mid-swing and it's flung")
	var hips: PhysicsBody3D = swung.model.ragdoll_hips() if swung.model != null else null
	var flung: Vector3 = hips.linear_velocity if hips != null else swung._throw_vel
	check(flung.y > 5.0, "where you look, up too: looking up launches it skyward (%.1f m/s up)" % flung.y)
	await _frames(60)
	for e in [swung, swept]:
		if is_instance_valid(e):
			e.queue_free()
	await _frames(2)
	# Walk away with it hooked: it's dragged limp along the ground, and it hurts.
	var dragged: Enemy = _cluster(1, 8.0)[0]
	await hook.call(dragged)
	var drag_hp := dragged.health.hp
	var drag_from := dragged.global_position
	p.global_position -= p.facing * 3.0
	s.hold({"light_held": true}, 40)
	await _frames(40)
	check(p.chain.mode == Chain.Mode.DRAG and dragged.thrown, "walk away and the chain drags it, off its feet")
	check(dragged.global_position.distance_to(drag_from) > 1.5, "it's hauled after you (%.1f m)" % dragged.global_position.distance_to(drag_from))
	check(dragged.health.hp < drag_hp, "and the ground hurts it")
	s.hold({}, 2)
	await _frames(3)
	check(p.state == Player.State.FREE and dragged.held_by == null, "let go and it's left lying there")
	if is_instance_valid(dragged):
		dragged.queue_free()
	await _frames(30)
	# Jump and slide with a minion on the chain; reel it in mid-slide and throw it.
	var hopper: Enemy = _cluster(1, 8.0)[0]
	hopper.health.hp = 10000.0
	await hook.call(hopper)
	s.hold({"light_held": true, "jump": true, "jump_held": true}, 1)
	s.hold({"light_held": true}, 90)
	await _frames(15)
	check(p.state == Player.State.CHAIN and not p.is_on_floor(), "you can jump with a minion on the chain")
	await _until_on_floor()
	s.queue.clear()
	s.hold({"light_held": true, "move": Vector2.UP, "slide": true, "slide_held": true}, 1)
	s.hold({"light_held": true, "move": Vector2.UP, "slide_held": true}, 3)
	await _frames(4)
	check(p.state == Player.State.CHAIN and p.is_sliding, "and slide with it")
	s.hold({"light_held": true, "move": Vector2.UP, "slide_held": true, "wheel_back": true}, 1)
	s.hold({"light_held": true}, 40)
	await _frames(41)
	check(p.state == Player.State.GRAB and p.grabber.held == hopper, "the wheel still reels it in (state %d)" % p.state)
	s.hold({"light_held": true, "heavy": true}, 1)
	s.hold({"light_held": true}, 30)
	await _frames(31)
	check(hopper._hurled and hopper.held_by == null, "and right click still throws it")
	s.hold({}, 2)
	await _frames(60)
	if is_instance_valid(hopper):
		hopper.queue_free()
	await _frames(2)
	# A big one: the chain holds fast, and right click pulls you in for a drop kick.
	var ogre: Enemy = _cluster(1, 8.0, "human_hired_ogre")[0]
	check(Chain.pulls_you(ogre), "an ogre is too big to hook")
	var start := p.global_position
	ogre.health.hp = 10000.0
	var in_the_way: Enemy = _dummy(p.facing * 4.0 + p.facing.cross(Vector3.UP) * 0.7)  # beside the line, but shoulder to shoulder with you
	await hook.call(ogre)
	s.hold({"light_held": true}, 10)
	await _frames(10)
	check(p.chain.mode == Chain.Mode.ANCHOR and p.global_position.distance_to(start) < 1.0, "the chain holds on it and waits")
	s.hold({"light_held": true, "heavy": true}, 1)
	s.hold({"light_held": true}, 40)
	await _frames(41)
	check(p.global_position.distance_to(start) > 3.0, "the chain pulls you to it (%.1f m)" % p.global_position.distance_to(start))
	check(ogre.health.hp < 10000.0, "and you land a drop kick, through the crowd in the way (user, 2026-11-20)")
	in_the_way.queue_free()
	var gap := ogre.global_position.distance_to(p.global_position)
	check(not ogre.thrown and gap > t.chain_kick_reach + 1.0, "it's driven back on its feet, not launched (%.1f m away)" % gap)
	s.hold({}, 2)
	await _frames(30)
	check(p.state == Player.State.FREE, "and you're free again")
	p.god_mode = false


## Combat feel plan, part 6: throwable items. Grabbed like minions (nearest the crosshair wins),
## hurled for a heavy hit, broken where they land; a village barrel or crate turns into one;
## a held item shields you; Large enemies throw them at you.
func test_throwable_items() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	p.god_mode = false
	await _until_on_floor()
	for old in get_tree().get_nodes_in_group("throwables"):
		old.queue_free()  # the practice arena's own, out of the way
	await _frames(1)
	var s := _scripted()
	var grab_frames := ceili(t.grab_hold_time * 60.0) + 3
	var rock := Throwable.make("boulder", _arena, p.global_position + p.facing * 1.5)
	await _frames(2)
	s.hold({"light": true, "light_held": true}, 1)
	s.hold({"light_held": true}, grab_frames)
	await _frames(grab_frames + 1)
	check(p.state == Player.State.GRAB and p.grabber.held == rock and rock.held_by == p, "holding light attack picks up a boulder")
	s.hold({"light_held": true}, ceili(t.crush_time * 60.0) + 10)
	await _frames(ceili(t.crush_time * 60.0) + 5)
	check(p.grabber.held == rock and not rock.is_dead(), "an item isn't crushed: you keep holding it")
	var hp := p.health.hp
	var blow := DamageInfo.make(10.0, "Physical", DamageInfo.Kind.ENEMY, null)
	blow.knockback_dir = -p.facing
	Combat.deal(p, blow)
	check(is_equal_approx(p.health.hp, hp), "a held item shields you from the front")
	var foe: Enemy = _cluster(1, 5.0)[0]
	foe.global_position = p.global_position + p.facing * 5.0
	await _frames(2)
	var foe_hp := foe.health.hp
	s.hold({"light_held": true, "heavy": true}, 1)
	await _frames(40)
	check(foe.health.hp < foe_hp or foe.is_dead() or foe.thrown, "a hurled boulder hits like a heavy (%.0f -> %.0f)" % [foe_hp, foe.health.hp])
	check(not is_instance_valid(rock) or rock.is_dead(), "and breaks where it lands")
	foe.queue_free()
	s.hold({}, 2)
	await _frames(20)
	# A village crate becomes one when grabbed.
	var crate_path := Breakable.PROPS + "crate.glb"
	if ResourceLoader.exists(crate_path):
		var crate: Node3D = (load(crate_path) as PackedScene).instantiate()
		_arena.add_child(crate)
		crate.global_position = p.global_position + p.facing * 1.5
		Breakable.attach(crate, "crate")
		await _frames(2)
		s.hold({"light": true, "light_held": true}, 1)
		s.hold({"light_held": true}, grab_frames)
		await _frames(grab_frames + 1)
		check(p.grabber.held is Throwable and p.grabber.held.kind == "crate", "a village crate can be picked up")
		s.hold({}, 2)
		await _frames(3)
		check(p.grabber.held == null and get_tree().get_nodes_in_group("throwables").any(func(i): return i.kind == "crate"), "and put down again")
	# The nearest to the crosshair wins.
	for old in get_tree().get_nodes_in_group("throwables"):
		old.queue_free()
	await _frames(1)
	var side := Throwable.make("branch", _arena, p.global_position + p.facing.rotated(Vector3.UP, 0.8) * 1.4)
	var minion: Enemy = _cluster(1, 1.5)[0]
	minion.global_position = p.global_position + p.facing * 1.5
	await _frames(2)
	check(p.grabber.target() == minion, "the minion right ahead wins over a branch to the side")
	minion.global_position = p.global_position + p.facing.rotated(Vector3.UP, -0.8) * 1.4
	side.global_position = p.global_position + p.facing * 1.4
	await _frames(2)
	check(p.grabber.target() == side, "and the branch right ahead wins over a minion to the side")
	minion.queue_free()
	side.queue_free()
	await _frames(2)
	# A Large enemy picks one up and throws it at you.
	var ogre: Enemy = _cluster(1, 10.0, "human_hired_ogre")[0]
	ogre.global_position = p.global_position + p.facing * 10.0
	var log := Throwable.make("boulder", _arena, ogre.global_position + p.facing * -1.0)
	p.god_mode = false
	hp = p.health.hp
	var lifted := false
	for i in 300:
		await _frames(1)
		lifted = lifted or log.held_by == ogre if is_instance_valid(log) else lifted
		if not is_instance_valid(log) or log.is_dead():
			break
	check(lifted, "a Large enemy picks up the boulder")
	check(not is_instance_valid(log) or log.is_dead() or log._flying, "and throws it")
	ogre.queue_free()
	await _frames(2)


## Combat feel plan, part 7: the body split. Moving during a move, the legs keep running and the
## move plays on the upper body (a second player with spine-up clips); standing, it's whole-body again.
func test_body_split() -> void:
	var p: Player = _arena.player
	p.god_mode = true
	await _until_on_floor()
	for old in get_tree().get_nodes_in_group("throwables"):
		old.queue_free()
	var s := _scripted()
	s.hold({"move": Vector2(0, 1)}, 20)
	await _frames(20)
	s.hold({"move": Vector2(0, 1), "light": true}, 1)
	s.hold({"move": Vector2(0, 1)}, 6)
	await _frames(5)
	var v := p.visual
	check(v.is_split(), "attacking while running splits the body")
	check(v.anim.current_animation.begins_with("Running") or v.anim.current_animation.begins_with("Walking"), "the legs keep running (%s)" % v.anim.current_animation)
	check(v.upper_clip() != "" and not v.upper_clip().begins_with("Running"), "the swing plays on the upper body (%s)" % v.upper_clip())
	var lib := v._upper.get_animation_library("")
	var clip: Animation = lib.get_animation(lib.get_animation_list()[0])
	var legs := false
	for t in clip.get_track_count():
		var bone := String(clip.track_get_path(t).get_concatenated_subnames())
		legs = legs or bone in ["hips", "upperleg.l", "lowerleg.r", "foot.l"]
	check(not legs and clip.get_track_count() > 0, "the upper-body clips key no hips or legs")
	s.hold({}, 60)
	await _frames(60)
	check(not v.is_split(), "standing still, the body is whole again")
	s.press("light")
	await _frames(3)
	check(not v.is_split() and p.state == Player.State.LIGHT, "and a swing standing still is whole-body")
	p.god_mode = false


## The crowd split (on its own branch): past crowd_full_fighters units, only that many nearest
## you fight at full rate; the rest are the crowd and take turns.
func test_crowd_split() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	p.god_mode = true
	var keep := t.crowd_full_fighters
	t.crowd_full_fighters = 10
	var units: Array = []
	for i in 30:
		var e: Enemy = _arena.waves.spawn("barb_raider")
		e.global_position = p.global_position + Vector3(cos(i * 0.7), 0, sin(i * 0.7)) * (3.0 + i)
		units.append(e)
	await _frames(3)
	var d: CrowdDirector = _arena.waves.director
	d._build_grid()
	var crowd: Array = d.enemies.filter(func(u): return is_instance_valid(u) and u.in_crowd)
	check(d.enemies.size() > 10 and crowd.size() == d.enemies.size() - 10, "only the 10 nearest are full fighters (%d in the crowd of %d)" % [crowd.size(), d.enemies.size()])
	check(not units[0].in_crowd and units[29].in_crowd, "the nearest fights, the farthest is in the crowd")
	check(units[29].model == null or units[29].model.in_crowd, "and its model animates like a far one")
	t.crowd_full_fighters = keep
	for e in units:
		e.queue_free()
	await _frames(2)
	p.god_mode = false


## The reels, frame by frame (2026-11-18): every blow lands on its clip's own strike frame, right
## when the hit does; a charged heavy waits drawn back; the crush flashes the screen red.
func test_strike_frames() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	p.god_mode = true
	await _until_on_floor()
	for old in get_tree().get_nodes_in_group("throwables"):
		old.queue_free()
	var v := p.visual
	var s := _scripted()
	# A light swing: at the hit, the clip is at its strike frame.
	s.press("light")
	await _frames(1)
	var clip := v.anim.current_animation
	var windup := p._light_duration() * t.light_windup_fraction
	check(CharacterModel.STRIKES.has(clip), "the swing plays a timed clip (%s)" % clip)
	var hit_frame := -1
	for i in 90:
		await _frames(1)
		if p._hit_done:
			hit_frame = i
			break
	await get_tree().process_frame
	var at := v.anim.current_animation_position
	check(hit_frame >= 0 and absf(at - float(CharacterModel.STRIKES.get(clip, 0.0))) < 0.12, "the hit lands on the clip's strike frame (%.2f s vs %.2f s)" % [at, float(CharacterModel.STRIKES.get(clip, 0.0))])
	await _frames(60)
	# A charged heavy waits drawn back, then lands.
	s.press("heavy")
	s.hold({"heavy_held": true}, 50)
	await _frames(40)
	await get_tree().process_frame
	check(v.strike_held() and not v.anim.is_playing(), "charging, the heavy waits drawn back just before its blow")
	s.hold({}, 30)
	await _frames(30)
	check(not v.strike_held(), "let go and it lands")
	await _frames(60)
	# The crush flashes the screen red.
	var foe: Enemy = _cluster(1, 1.6)[0]
	await _frames(2)
	var frames := ceili(t.grab_hold_time * 60.0) + 3
	s.hold({"light": true, "light_held": true}, 1)
	s.hold({"light_held": true}, frames + ceili(t.crush_time * 60.0) + 5)
	await _frames(frames + 1)
	await get_tree().process_frame
	check(v.current() == "Melee_Unarmed_Attack_Punch_A" or v.current() == "Melee_Blocking", "the grab is a lunging clamp (%s)" % v.current())
	await _frames(20)
	await get_tree().process_frame
	check(v.current() == "Melee_Blocking", "then both arms hold it in front (%s)" % v.current())
	var flashed := false
	for i in ceili(t.crush_time * 60.0) + 10:
		await _frames(1)
		flashed = flashed or (_arena.hud._screen_flash != null and _arena.hud._screen_flash.visible)
	check(foe.is_dead() and flashed, "the crush flashes the screen red")
	p.god_mode = false


func test_anim_library() -> void:
	var lib: AnimationLibrary = load("res://models/quaternius/ual_rig_medium.res")
	var names := lib.get_animation_list()
	check(names.size() == 84 and names.has("UAL2_Sword_Heavy_Combo") and names.has("UAL1_Roll"), "the Quaternius clips are converted to our rig (%d)" % names.size())
	var a := lib.get_animation("UAL2_Sword_Regular_A")
	var bones := {}
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			bones[String(a.track_get_path(t)).get_slice(":", 1)] = true
	check(bones.has("hips") and bones.has("upperarm.r") and bones.has("toes.l") and bones.size() == 23, "and key every Rig_Medium bone, so nothing is left from the clip before")
	# The conversion follows the original: limb directions match within a few degrees.
	var src: Node3D = AnimRetarget.load_library_glb("itch/quaternius-ual2/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb")
	if src != null:
		add_child(src)
		var tgt: Node3D = (load("res://models/kaykit/animations/Rig_Medium_General.glb") as PackedScene).instantiate()
		add_child(tgt)
		var sp: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		var tp: AnimationPlayer = tgt.find_children("*", "AnimationPlayer", true, false)[0]
		var ssk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
		var tsk: Skeleton3D = tgt.find_children("*", "Skeleton3D", true, false)[0]
		tp.add_animation_library("ual", lib)
		var worst := 0.0
		for f in 5:
			var t := 0.43 * f / 4.0
			AnimRetarget._seek(sp, "Sword_Regular_A", t)
			AnimRetarget._seek(tp, "ual/UAL2_Sword_Regular_A", t)
			var sw := AnimRetarget.world_pose(ssk)
			var tw := AnimRetarget.world_pose(tsk)
			for l in [["upperarm.r", "lowerarm.r", "upperarm_r", "lowerarm_r"], ["lowerarm.r", "wrist.r", "lowerarm_r", "hand_r"], ["upperleg.l", "lowerleg.l", "thigh_l", "calf_l"]]:
				var d1: Vector3 = tw[l[1]][1] - tw[l[0]][1]
				var d2: Vector3 = sw[l[3]][1] - sw[l[2]][1]
				worst = maxf(worst, rad_to_deg(d1.angle_to(d2)))
		check(worst < 12.0, "a converted sword swing moves the arms and legs like the original (worst %.1f deg)" % worst)
		src.free()
		tgt.free()
	# The viewer: every clip, marks and notes saved, filters.
	var v = load("res://tests/anim_library.tscn").instantiate()
	v.state_path = OS.get_user_data_dir() + "/anim_notes_test.json"
	DirAccess.remove_absolute(v.state_path)
	add_child(v)
	var by_lib := {}
	for c in v.clips:
		by_lib[c.lib] = by_lib.get(c.lib, 0) + 1
	var extra_ok: bool = by_lib.get("kaykit_extra", 0) > 40 or AnimRetarget.load_library_glb(v.KAYKIT_DIR + v.KAYKIT_UNUSED[0]) == null  # the extra KayKit files are local only (asset_library)
	check(by_lib.get("ual", 0) == 84 and by_lib.get("", 0) > 70 and extra_ok, "the animation library lists every clip (%s)" % by_lib)
	check(v._by_name["Idle_A"].in_game and not v._by_name["UAL2_Slide_Loop"].in_game, "and knows which the game uses")
	check(v._hero.anim.has_animation("ual/UAL2_Slide_Loop"), "the hero can play a converted clip")
	v.set_verdict("UAL2_Slide_Loop", "use")
	v.set_notes("UAL2_Slide_Loop", "dodge while running")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(v.state_path))
	check(saved is Dictionary and saved["UAL2_Slide_Loop"].verdict == "use" and saved["UAL2_Slide_Loop"].notes == "dodge while running", "a mark and a note save to the notes file")
	check(v.matches(v._by_name["UAL2_Slide_Loop"], v.FILTERS.find("Use"), "slide") and not v.matches(v._by_name["UAL2_Slide_Loop"], v.FILTERS.find("Discard"), ""), "the filters find it")
	v.set_verdict("UAL2_Slide_Loop", "use")
	check(v.verdict("UAL2_Slide_Loop") == "", "pressing the same mark again clears it")
	v.free()
	DirAccess.remove_absolute(OS.get_user_data_dir() + "/anim_notes_test.json")


func test_arena_menu() -> void:
	# The endless arena's menus: elements to choose from (no weapon: you find those), and Esc to pause and back.
	check(ArenaMenu.elements().size() >= 2, "elements to choose from")
	_arena.queue_free()
	await _frames(1)
	_arena = ENDLESS.instantiate()
	_arena.auto_start = false
	add_child(_arena)
	await _frames(2)
	var a: EndlessArena = _arena
	check(a.menu != null and not a.hud._godly_gifts.visible, "the arena has its menu and shows no godly gifts")
	var level := Run.state.level
	a.give_xp(100000.0)
	check(Run.state.level == level and Run.state.pending_level_ups == 0 and not a.hud.is_choosing(), "no XP or level-up upgrades in the arena")
	var esc := InputEventAction.new()
	esc.action = "release_mouse"
	esc.pressed = true
	a.menu._unhandled_input(esc)
	check(a.menu.is_open() and get_tree().paused, "Esc pauses")
	a.menu._unhandled_input(esc)
	check(not a.menu.is_open() and not get_tree().paused, "Esc again resumes")
	a.menu.open_loadout(a.player.god_id)
	check(a.menu.is_open() and get_tree().paused, "the loadout menu pauses the fight")
	a.menu.close()


func test_arena_tactics() -> void:
	# The endless arena's combat (user, 2026-11-19): posture breaks and finishers, shields, perfect
	# dodges, parry for all, witch circles, element reactions, traps, thrown bodies, pickups.
	_arena.queue_free()
	await _frames(1)
	_arena = ENDLESS.instantiate()
	_arena.auto_start = false
	add_child(_arena)
	await _frames(2)
	await _until_on_floor()
	var a: EndlessArena = _arena
	var p: Player = a.player
	var ahead := func(e: Enemy, d := 1.6) -> void:
		e.global_position = p.global_position + p.facing * d
	var hit := func(e: Node, kind: DamageInfo.Kind, amount := 10.0) -> float:
		var info := DamageInfo.make(amount, "Physical", kind, p)
		return Combat.deal(e, info)
	check(EndlessArena.wave_units(1).has(WaveDirector.BASIC_UNIT + WaveDirector.SHIELD_TAG), "shield bearers join from the second wave")

	# Posture: hits fill it, full breaks it, and a grab finishes a broken enemy.
	var e: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	e.health.setup(10000.0)
	ahead.call(e)
	await _frames(2)
	check(e.tactics and not e.is_broken(), "arena enemies use tactics")
	for i in 4:
		hit.call(e, DamageInfo.Kind.LIGHT)
	check(e.is_broken(), "four light hits break its posture (poise %.0f)" % e.poise)
	check(p._try_grab(), "a grab on a broken enemy is a finisher")
	check(e.is_dead(), "the finisher kills it outright")
	check(Engine.time_scale < 1.0, "a finisher slows time for a moment")
	HitStop.clear()  # its slow motion runs on the real clock, which barely moves in a headless test

	# Thrown bodies bowl enemies over; the berserker crashing into a wall is left open.
	var b: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	await _frames(1)
	Enemy.bowled_over([b])
	check(b.is_broken() and b.state == Enemy.State.DOWN, "hit by a thrown body: down and broken")
	b.queue_free()
	var zerk: Enemy = a.waves.spawn(Enemy.CHARGER)
	await _frames(1)
	zerk._crash()
	check(zerk.is_broken(), "a berserker that charges into a wall is broken")
	zerk.queue_free()

	# Shields block from the front only.
	await _frames(int(Enemy.RAM_SECONDS * 60.0) + 5)  # the finished one's body has stopped knocking into others
	var s: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT + WaveDirector.SHIELD_TAG)
	s.health.setup(10000.0)
	ahead.call(s, 2.0)
	await _frames(1)
	s.set_physics_process(false)  # hold still: it mustn't turn while we test the facing
	var to_p := p.global_position - s.global_position
	s.rotation.y = atan2(-to_p.x, -to_p.z)
	check(s.shielded and is_zero_approx(hit.call(s, DamageInfo.Kind.LIGHT)), "a shield turns a blow from the front")
	s.rotation.y += PI
	check(hit.call(s, DamageInfo.Kind.LIGHT) > 0.0, "and not from behind")
	s.queue_free()

	# Element reactions: your element (Fire, the forge god) ignites poison; a heavy shatters ice.
	var r: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	r.health.setup(10000.0)
	ahead.call(r, 3.0)
	await _frames(1)
	Combat.apply_status(r, "poison", 1, null)
	hit.call(r, DamageInfo.Kind.LIGHT)
	check(p.element() == "Fire" and not r.statuses.has("poison"), "Fire on a poisoned enemy ignites the poison")
	Combat.apply_status(r, "ice", 1, null)
	var before := r.health.hp
	var dealt: float = hit.call(r, DamageInfo.Kind.HEAVY, 20.0)
	check(not r.statuses.has("ice") and before - r.health.hp > dealt * 1.5, "a heavy shatters ice for double damage (%.0f lost)" % (before - r.health.hp))
	r.queue_free()

	# A witch's circle bursts where you stood; she has an element.
	var w: Enemy = a.waves.spawn(EndlessArena.CASTER)
	w.global_position = p.global_position + Vector3(8, 0, 8)
	await _frames(1)
	w.set_physics_process(false)
	check(w.element_status in WaveDirector.WITCH_ELEMENTS, "a witch carries an element (%s)" % w.element_status)
	var hp := p.health.hp
	var circle := WitchCircle.cast(w, p.global_position, 10.0, w.element_status)
	await _frames(int(WitchCircle.DELAY * 60.0) + 6)
	check(p.health.hp < hp and not is_instance_valid(circle), "standing in a witch's circle hurts")
	p.health.heal(1000.0)
	p.statuses.clear()
	w.queue_free()

	# A perfect dodge slows time and powers up your hits; the dodge key standing still parries.
	var dmg := p.stats.get_stat("damage_pct")
	p._start_dodge(p.facing)
	var blow := DamageInfo.make(10.0, "Physical", DamageInfo.Kind.ENEMY, null)
	check(is_zero_approx(p.take_hit(blow)) and p.stats.get_stat("damage_pct") > dmg, "a perfect dodge powers up your hits")
	HitStop.clear()
	await _frames(40)
	var sc := _scripted()
	sc.press("dodge")
	await _frames(2)
	check(p.state == Player.State.PARRY, "the dodge key with no direction parries, any weapon (state %d)" % p.state)
	await _frames(40)

	# Traps: a body thrown into the spikes dies; the health orb heals.
	var spikes: ArenaHazard = get_tree().get_nodes_in_group("arena_hazards").filter(func(h): return h.kind == "spikes")[0]
	var t: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	await _frames(1)
	t.throw(Vector3.UP * 2.0, p)
	t.global_position = spikes.global_position + Vector3.UP * 0.5
	await _frames(3)
	check(t.is_dead(), "thrown into the spikes, it dies")
	p.health.hp = 10.0
	ArenaPickup.make(a, p.global_position - Vector3.UP)
	await _frames(3)
	check(p.health.hp > 10.0, "the health orb heals")


func test_grab_aim_and_slams() -> void:
	# User, 2026-11-19: first person shows only the weapon; a held minion is aimed up, down and round
	# and tossed skyward it takes fall damage; a squeeze too weak to kill slams it down instead, a
	# squeeze kill takes the head; a chained minion swung into a wall goes limp.
	_arena.queue_free()
	await _frames(1)
	_arena = ENDLESS.instantiate()
	_arena.auto_start = false
	add_child(_arena)
	await _frames(2)
	await _until_on_floor()
	var a: EndlessArena = _arena
	var p: Player = a.player
	var rig: CameraRig = a.camera_rig
	p.equip("warhammer")  # you start bare-handed: take a weapon to see it
	await _frames(1)
	var body_meshes: Array = p.visual.model.find_children("*", "MeshInstance3D", true, false)
	check(rig.first_person and (rig.camera.cull_mask & CameraRig.BODY_LAYER) == 0, "first person leaves the body's layer out")
	check(body_meshes.any(func(m): return m.layers == CameraRig.BODY_LAYER) and body_meshes.any(func(m): return m.layers & 1),
		"the body is on its own layer, the weapon stays on the seen one")
	rig.first_person = false
	check(rig.camera.cull_mask & CameraRig.BODY_LAYER, "third person shows the body again")
	rig.first_person = true

	var intent := PlayerIntent.new()
	intent.light_held = true
	var grab := func(e: Enemy) -> void:
		e.global_position = p.global_position + p.facing * 1.0
		await _frames(1)
		p.grabber.grab(e)
		p._set_state(Player.State.GRAB)
	# Aimed straight up: held overhead, thrown skyward, it falls back hard.
	var up: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	up.health.setup(10000.0)
	await grab.call(up)
	intent.aim_yaw = 0.0
	intent.aim_pitch = 1.4
	p.grabber.update(1.0 / 60.0, intent)
	check(p.grabber.hold_point().y > p.global_position.y + 1.2, "looking up holds it overhead")
	p.grabber.hurl()
	p._set_state(Player.State.FREE)
	for i in 60:  # up and back down (a ragdoll falls slower than a capsule)
		await _frames(10)
		if up.health.hp < 10000.0:
			break
	check(up.health.hp < 10000.0, "tossed straight up, it takes fall damage (%.0f)" % (10000.0 - up.health.hp))
	up.queue_free()
	intent.aim_pitch = 0.0

	# Too much health left to squeeze: slammed into the ground, the crowd pushed back.
	var tough: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	tough.health.setup(10000.0)
	var near: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	near.health.setup(10000.0)
	await grab.call(tough)
	near.global_position = p.global_position + p.facing * 2.5
	p.grabber._crush = GameData.tuning.crush_time
	p.grabber.update(1.0 / 60.0, intent)
	check(not tough.is_dead() and tough.health.hp < 10000.0 and tough.thrown, "a tough one is slammed down, hurt and limp")
	check(near.state == Enemy.State.DOWN or near._knock.length() > 1.0, "the slam pushes the others back")
	p._set_state(Player.State.FREE)
	tough.queue_free()
	near.queue_free()
	await _frames(2)
	# Weak enough: crushed, and the head goes.
	var weak: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	await grab.call(weak)
	weak.health.hp = 1.0
	p.grabber._crush = GameData.tuning.crush_time
	p.grabber.update(1.0 / 60.0, intent)
	check(weak.is_dead() and weak.model.head_popped(), "a squeeze kill takes its head")
	p._set_state(Player.State.FREE)
	HitStop.clear()

	# Chained and swung into a wall: a heavy blow, and it goes limp.
	var swung: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	swung.health.setup(10000.0)
	swung.global_position = p.global_position + p.facing * 4.0
	await _frames(1)
	p.chain.target = swung
	p.chain.mode = Chain.Mode.SWING
	swung.grab_by(p)
	p.chain._wall_slam(swung.global_position + Vector3.UP, -p.facing, p.facing)
	check(swung.thrown and swung.health.hp < 10000.0 and p.chain.mode == Chain.Mode.OFF, "swung into a wall: hurt, limp, and the chain lets go")
	check(Chain.LINK_WIDTH <= 0.06, "the chain is thin")


func test_training_ground() -> void:
	# User, 2026-11-19: no stamina in the arena; the slide key taps to dash and holds to slide.
	_arena.queue_free()
	await _frames(1)
	_arena = ENDLESS.instantiate()
	_arena.auto_start = false
	add_child(_arena)
	await _frames(2)
	var a: EndlessArena = _arena
	var p: Player = a.player
	var full := p.stamina
	p.spend_stamina(50.0)
	check(p.no_stamina and is_equal_approx(p.stamina, full) and not a.hud._stamina_bar.visible, "nothing costs stamina, and its bar is gone")
	var input: PlayerInput = p.input_source
	check(input.slide_dashes, "the arena's slide key dashes too")
	Input.action_press("slide")
	var i1 := input.read()
	Input.action_release("slide")
	var i2 := input.read()
	check(not i1.slide and not i1.dodge and i2.dodge and i2.dash and not i2.slide, "a tap dashes, once, on release")
	Input.action_press("slide")
	input.read()
	OS.delay_msec(PlayerInput.SLIDE_HOLD_MSEC + 30)
	var held := input.read()
	var still := input.read()
	Input.action_release("slide")
	var after := input.read()
	check(held.slide and held.slide_held and not still.slide and still.slide_held and not after.dodge, "held, it slides (no dash when let go)")
	check(after.aim_point != Vector3.INF, "where you aim is known with no spell key held (each Kaminari pillar lands where you click)")
	check(Enemy.DEATH_LAUNCH > 1.3 and Grabber.THROW_BOOST > 1.3 and Throwable.DEBRIS_SCALE > 1.3, "killing blows launch, throws and debris fly a third farther")


func test_kill_reported_once() -> void:
	# The Fire + Lightning duo finishes a burning enemy inside the lightning hit's own deal():
	# that kill must be reported once (it used to be twice: double XP and kill score).
	var p: Player = _arena.player
	p.godly_gifts.add_godly_gift("duo_forge_storm")
	var e: Enemy = _cluster(1)[0]
	await _frames(2)
	Combat.apply_status(e, "fire", 1, null)
	e.health.hp = 20.0
	var count := [0]
	var on_kill := func(t, _i): if t == e: count[0] += 1
	Combat.killed.connect(on_kill)
	Combat.deal(e, DamageInfo.make(5.0, "Lightning", DamageInfo.Kind.LIGHT, p))
	Combat.killed.disconnect(on_kill)
	check(e.is_dead() and count[0] == 1, "a kill by a gift inside a hit is reported once (dead %s, reported %d)" % [e.is_dead(), count[0]])


func test_endless_waves() -> void:
	# Endless survival: each cleared wave brings a bigger one, kills are counted, and it never ends.
	check(EndlessArena.wave_units(1).size() > EndlessArena.wave_units(0).size(), "each wave is bigger than the last")
	check(EndlessArena.wave_units(999).size() <= EndlessArena.MAX_SIZE + 1, "waves stop growing at the cap")
	_arena.queue_free()
	await _frames(1)
	_arena = ENDLESS.instantiate()
	_arena.auto_start = false
	_arena.run_seed = 7
	add_child(_arena)
	await _frames(2)
	var a: EndlessArena = _arena
	check(a.camera_rig.first_person, "the arena starts in first person")
	a._continue_waves()
	await _frames(40)
	var first: int = EndlessArena.wave_units(0).size()
	check(a.waves.wave == 0 and a.waves.alive() == mini(EndlessArena.ON_FIELD, first) and a.waves.alive() + a.waves.reserve.size() == first,
		"wave 1's %d walk in %d at a time (%d in, %d waiting)" % [first, EndlessArena.ON_FIELD, a.waves.alive(), a.waves.reserve.size()])
	for i in 6:  # kill whoever's in, and the next ones as they come
		for e in get_tree().get_nodes_in_group("enemies"):
			Combat.deal(e, DamageInfo.make(9999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, a.player))
		await _frames(30)
	check(a.kills == first, "every kill is counted (%d of %d)" % [a.kills, first])
	check(EndlessArena.SHOOTER in EndlessArena.wave_units(0) and EndlessArena.CASTER in EndlessArena.wave_units(EndlessArena.CASTER_FROM),
		"waves bring shooters, and casters later")
	check(a.director.attacker_limit() == EndlessArena.ATTACKERS, "fewer enemies swing at you at once")
	var raider: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	var hit := a.light_hit_damage()
	var hits := ceili(raider.health.max_hp / hit)
	check(hits >= 3 and hits <= 4, "a raider takes 3-4 light hits (%d: %.0f hp, %.0f a hit)" % [hits, raider.health.max_hp, hit])
	raider.queue_free()
	check(not a.hud.is_choosing(), "no godly gift menu between waves")
	await _frames(int(EndlessArena.WAVE_GAP * 60.0) + 10)
	check(get_tree().get_nodes_in_group("arena_pickups").size() == 1, "a health orb waits between waves")
	check(a.waves.wave == 1 and a.waves.alive() + a.waves.reserve.size() == EndlessArena.wave_units(1).size(), "wave 2 follows, bigger (%d)" % (a.waves.alive() + a.waves.reserve.size()))
	# Pacing: one fighter closes in at a time, and a shooter may fire beside it.
	var d: CrowdDirector = a.director
	var f1: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	var f2: Enemy = a.waves.spawn(WaveDirector.BASIC_UNIT)
	var sh: Enemy = a.waves.spawn(EndlessArena.SHOOTER)
	await _frames(1)
	d._holders.clear()
	check(d.request_token(f1) and not d.request_token(f2) and d.request_token(sh) and d.full(), "one fighter at a time, and a shooter beside it")


func test_arena_textures() -> void:
	# User, 2026-11-19: their grass picture on the arena floor, their stone picture on its walls.
	_arena.queue_free()
	await _frames(1)
	_arena = ENDLESS.instantiate()
	_arena.auto_start = false
	add_child(_arena)
	await _frames(2)
	var looks := _arena.find_children("arena", "MeshInstance3D", true, false).map(func(m): return m.material_override)
	var mat := looks[0] as ShaderMaterial if looks.size() == 1 else null
	check(mat != null and mat.get_shader_parameter("grass").resource_path == "res://textures/grass.png"
		and mat.get_shader_parameter("stone").resource_path == "res://textures/stone_masonry.png"
		and mat.get_shader_parameter("grass_gain") != Vector3.ONE,
		"the arena model wears the grass and stone pictures, each shading its own color")


## The fantasy pivot (2026-11-19): full-resolution rendering, a golden-hour sky with haze and glow,
## and motes of magic drifting over the floor.
func test_arena_look() -> void:
	check(not Engine.has_singleton("RetroLook") and get_tree().root.get_node_or_null("RetroLook") == null, "no retro pixel filter over the world")
	var env: Environment = (_arena.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	check(env.fog_enabled and env.glow_enabled and env.ssao_enabled and env.tonemap_mode != Environment.TONE_MAPPER_LINEAR,
		"the arena has haze, glow, ambient occlusion and a filmic tone map")
	var motes: GPUParticles3D = _arena.get_node_or_null("Motes")
	check(motes != null and motes.amount == GameData.tuning.arena_motes, "motes of magic drift over the arena (%d)" % (motes.amount if motes != null else 0))
	var kept := GameData.tuning.arena_motes
	GameData.tuning.arena_motes = 0
	var bare := ARENA.instantiate()
	bare.auto_start = false
	add_child(bare)
	await _frames(1)
	check(bare.get_node_or_null("Motes") == null, "arena_motes 0 turns them off")
	bare.queue_free()
	GameData.tuning.arena_motes = kept
	await _frames(1)


## The fantasy pivot (2026-11-19): the endless arena fights mythical foes, each with a model.
func test_mythical_roster() -> void:
	var seen := {}
	for w in 12:
		for token in EndlessArena.wave_units(w):
			seen[str(token).trim_suffix(WaveDirector.SHIELD_TAG)] = true
	check(seen.keys().all(func(id): return not str(id).begins_with("barb_")), "no barbarians left in the waves (%s)" % ", ".join(seen.keys()))
	for id in [WaveDirector.BASIC_UNIT, EndlessArena.SHOOTER, EndlessArena.CASTER, WaveDirector.TOUGH_UNIT, WaveDirector.LARGE_UNIT]:
		check(seen.has(id) and not GameData.unit(id).is_empty() and EndlessArena.HITS_TO_KILL.has(id), "%s fights in the waves and has a row" % id)
		var e: Enemy = _arena.waves.spawn(id, _arena.player.global_position + Vector3(0, 0, -10))
		await _frames(1)
		check(e.model != null, "%s has a model" % id)
		e.queue_free()
	check(Enemy.CHARGER == WaveDirector.TOUGH_UNIT and GameData.text(GameData.unit(EndlessArena.CASTER), "role") == "Magic", "the minotaur charges and the gorgon casts")
	await _frames(1)


func test_tutorial() -> void:
	# The tutorial (user, 2026-11-20): each lesson goes on once its move is made, with foes to practise on.
	_arena.queue_free()
	await _frames(1)
	_arena = load(TutorialArena.SCENE).instantiate()
	_arena.auto_start = false
	add_child(_arena)
	await _frames(2)
	await _until_on_floor()
	var a: TutorialArena = _arena
	var p: Player = a.player
	check(a.waves.reserve.is_empty() and not a.waves.running, "the tutorial has no waves")
	a.start_tutorial()
	await _frames(2)
	check(a.step == 0 and p.god_mode, "the tutorial begins at the first lesson and nothing hurts you")
	check(a._foes.size() == TutorialArena.FOES, "skeletons stand by to practise on")
	check(not a.hud._message.text.contains("{"), "the prompt shows your keys")
	for mode in [Chain.Mode.HOOKED, Chain.Mode.REEL]:
		p.chain.mode = mode
		await _frames(2)
	p.chain.mode = Chain.Mode.OFF
	check(a.step == 2, "hooking and reeling pass their lessons")
	p.grabber._throw = 0.0
	await _frames(2)
	p.grabber._throw = -1.0
	check(a.step == 3, "a hurl passes its lesson")
	for mode in [Chain.Mode.YANK, Chain.Mode.SLAM, Chain.Mode.SWING, Chain.Mode.DRAG]:
		p.chain.mode = mode
		await _frames(2)
	p.chain.mode = Chain.Mode.OFF
	check(a.step == 7 and is_instance_valid(a._cyclops), "the chain moves pass, and a cyclops comes for the drop kick")
	p.chain.mode = Chain.Mode.PULL
	await _frames(2)
	p.chain.mode = Chain.Mode.OFF
	check(a.step == 8 and get_tree().get_nodes_in_group("weapon_pickups").size() > 0, "the drop kick passes, and a weapon lies ready")
	p.equip("warhammer")
	await _frames(2)
	p.throw_weapon(0.0)
	await _frames(2)
	p.equip("warhammer")
	await _frames(2)
	check(a.step == a.steps.size(), "taking up, throwing and taking back a weapon finish the tutorial")


func test_bestiary_saved() -> void:
	Meta.persist = true
	Meta.data = {"codex": []}
	Meta.discover(WaveDirector.BASIC_UNIT)
	Meta.persist = false
	Meta.data = {}
	Meta.load_profile()
	check(("creature:" + WaveDirector.BASIC_UNIT) in Meta.data.codex, "a discovered creature is still in the bestiary after a reload")
	for id in EndlessArena.HITS_TO_KILL:
		Meta.discover(id)
		check(Bestiary.is_discovered(id) and Bestiary.creatures().any(func(r): return r.unit_id == id), "%s, met in the waves, is in the bestiary" % id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.PROFILE_PATH))
	# An unreadable profile is kept aside, never written over.
	var f := FileAccess.open(SaveSystem.PROFILE_PATH, FileAccess.WRITE)
	f.store_string("{oops")
	f.close()
	var aside := SaveSystem.PROFILE_PATH.get_basename() + ".broken.json"
	Meta.load_profile()
	check(FileAccess.file_exists(aside) and FileAccess.get_file_as_string(aside) == "{oops" and Meta.data.codex.is_empty(),
		"a broken profile is kept as profile.broken.json and the game starts with an empty bestiary")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(aside))


func test_hitstop_in_slow_motion() -> void:
	GameData.tuning.hitstop_enabled = true  # _setup turns it off for every other test
	HitStop.slow(5.0, 0.3)
	HitStop.trigger(5.0)
	check(is_equal_approx(Engine.time_scale, GameData.tuning.hitstop_time_scale), "a hit during slow motion stops time briefly")
	HitStop._hit_end = 1  # the hit-stop is over (the real clock barely moves in a headless test)
	HitStop._update()
	check(is_equal_approx(Engine.time_scale, 0.3), "then slow motion goes on at its own pace")
	HitStop.clear()


func test_test_arena_and_start_menu() -> void:
	# Test mode (user, 2026-11-20): no enemies, switch element at will, no cooldowns, props to smash.
	var menu: StartMenu = load(StartMenu.SCENE).instantiate()
	add_child(menu)
	check(menu.find_children("*", "Button", true, false).size() == 4, "the start menu has Tutorial, Play, Test and Quit")
	menu.queue_free()
	_arena.queue_free()
	await _frames(1)
	_arena = load(TestArena.SCENE).instantiate()
	_arena.auto_start = false
	add_child(_arena)
	await _frames(2)
	var a: TestArena = _arena
	var p: Player = a.player
	a.start_test()
	await _frames(2)
	check(get_tree().get_nodes_in_group("enemies").is_empty() and a.waves.reserve.is_empty(), "test mode has no enemies")
	check(get_tree().get_nodes_in_group("breakables").size() == TestArena.TARGETS.size(), "a ring of props stands ready to smash")
	check(p.god_mode, "nothing hurts you in test mode")
	a.switch_element(1)
	check(p.god_id == ArenaMenu.elements()[1], "a number key switches your element")
	p.abilities.remaining["Ultimate"] = 30.0
	await _frames(2)
	check(p.abilities.ready_in("Ultimate") == 0.0, "spells have no cooldown")
	var b: Breakable = get_tree().get_nodes_in_group("breakables")[0]
	b.smash(p.global_position)
	await _frames(2)
	check(a._targets.size() == TestArena.TARGETS.size() - 1, "a smashed prop is gone")


## Enemy hit reactions (user, 2026-11-20): a blow rocks the body back the way it was hit, and for a
## quarter second it can't land a blow of its own, large ones too.
func test_hit_reactions() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	var e: Enemy = _cluster(1, 3.0)[0]
	await _frames(2)
	var blow := DamageInfo.make(1.0, "Physical", DamageInfo.Kind.LIGHT, p)
	blow.knockback_dir = Vector3.RIGHT
	Combat.deal(e, blow)
	await _frames(2)
	check(e._visual.global_basis.y.normalized().dot(Vector3.RIGHT) > sin(deg_to_rad(t.enemy_hit_lean_deg) * 0.5), "a blow from the left leans it to the right")
	await _frames(int(t.enemy_hit_lean_time * 60.0) + 4)
	check(e._visual.quaternion.is_equal_approx(Quaternion.IDENTITY), "then it straightens up")
	e.queue_free()
	var ogre: Enemy = _cluster(1, 2.0, "human_hired_ogre")[0]
	await _frames(2)
	var to: Vector3 = p.global_position - ogre.global_position
	ogre.rotation.y = atan2(-to.x, -to.z)
	ogre.target = p
	ogre._enter(Enemy.State.WINDUP, 0.05)
	Combat.deal(ogre, DamageInfo.make(1.0, "Physical", DamageInfo.Kind.LIGHT, p))
	await _frames(int(t.enemy_hit_attack_lock * 60.0) - 5)
	check(ogre.state == Enemy.State.WINDUP, "a big one hit as it winds up holds its blow")
	await _frames(15)
	check(ogre.state != Enemy.State.WINDUP, "until a quarter second has passed")
	ogre.queue_free()


## Every spell is aimed (user, 2026-11-20): hold its key, a circle on the ground shows where it lands
## (at your feet for one that goes off around you); the crosshair only for one that shoots forward.
func test_aim_every_spell() -> void:
	var p: Player = _arena.player
	var kept: Dictionary = p.abilities.defs
	var home: Vector3 = p.global_position
	var s := _scripted()
	var aimed: Vector3 = home + Vector3(0, 0, -8)
	for c in [["storm_god", "movement", "Movement", true], ["storm_god", "signature", "Signature", false], ["snow_god", "signature", "Signature", false]]:
		p.abilities.load_for(c[0])
		s.hold({c[1]: true, c[1] + "_held": true, "aim_point": aimed}, 1)
		s.hold({c[1] + "_held": true, "aim_point": aimed}, 8)
		await _frames(6)
		var ring: Vector3 = p._aim_ring.global_position if p._aim_ring != null else Vector3.INF
		var reach: float = p.abilities.aim_reach(c[2])
		var want: Vector3 = home + (aimed - home).limit_length(reach)
		check(p._aim_slot == c[2] and Vector2(ring.x - want.x, ring.z - want.z).length() < 0.5, "%s %s: the circle shows where it lands (%.1f m out)" % [c[0], c[2], reach])
		check(p.crosshair_shown() == c[3], "%s %s: the crosshair %s" % [c[0], c[2], "shows: it shoots forward" if c[3] else "stays hidden"])
		p._stop_aiming()  # not cast: these are checked in test_spells
		s.queue.clear()
		await _frames(2)
	p.abilities.defs = kept
	p.input_source = null


## Fired in mid-air pointing at the ground (user, 2026-11-20), the Fire Lance carries you up.
func test_lance_flight_and_shoulder_camera() -> void:
	var p: Player = _arena.player
	var kept: Dictionary = p.abilities.defs
	p.abilities.load_for("forge_god")
	await _until_on_floor()
	var s := _scripted()
	p.global_position += Vector3.UP * 6.0  # mid-jump
	p.velocity = Vector3.ZERO
	await _frames(2)
	check(not p.is_on_floor(), "in the air")
	var y0 := p.global_position.y
	s.hold({"movement": true, "aim_pitch": -1.4}, 1)
	s.hold({"aim_pitch": -1.4}, int((AbilityRunner.LUNGE_TIME + 0.4) * 60.0))
	await _frames(int((AbilityRunner.LUNGE_TIME + 0.4) * 60.0))
	check(p.abilities.beaming() and p.abilities.lance_push().y > 5.0, "the lance points at the ground and pushes you up")
	check(p.global_position.y > y0 + 1.0, "you fly up on it (%.1f m)" % (p.global_position.y - y0))
	await _frames(int(GameData.tuning.lance_beam_time * 60.0) + 10)
	check(p.abilities.lance_push() == Vector3.ZERO, "then it ends and you fall")
	p.abilities.defs = kept
	p.input_source = null
	await _until_on_floor()
	# The camera swings camera_side_deg round to your right, you still in the middle of the screen.
	var rig: CameraRig = _arena.camera_rig
	await _frames(30)
	var to_cam: Vector3 = rig.camera.global_position - p.global_position
	var right := Vector3(cos(rig.yaw), 0.0, -sin(rig.yaw))
	var look: Vector3 = -rig.camera.global_basis.z
	var pivot: Vector3 = p.global_position + Vector3.UP * rig.height
	var off_center := (pivot - rig.camera.global_position).cross(look).length()  # how far you are from the middle of its view
	check(to_cam.dot(right) > 1.0 and off_center < 0.3, "the camera stands off your right side (%.1f m), you in the middle of the screen (%.2f m off)" % [to_cam.dot(right), off_center])

