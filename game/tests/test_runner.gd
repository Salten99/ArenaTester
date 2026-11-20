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
		"test_fire_ticks", "test_godly_gift_offer_and_duo", "test_unbuilt_content_is_hidden", "test_dodge_iframes", "test_guardian_parry",
		"test_searing_strikes_ignites_slam", "test_thunderforged_combo", "test_attack_tokens",
		"test_ability_cast", "test_fire_lance", "test_breakable_props", "test_ranged_shots_can_be_dodged", "test_aimed_ultimate", "test_ultimate_circles", "test_fire_ultimate", "test_stone_eruption", "test_ragdoll_death", "test_performance_40_enemies", "test_wave_and_godly_gift_flow", "test_kiln_heart_on_burning_kill",
		"test_sprint_and_jump", "test_slide_boost_and_crouch", "test_models_and_animations",
		"test_level_ups", "test_one_god_per_race",
		"test_void_mark", "test_all_movesets", "test_weapon_choice", "test_element_effects", "test_controls_rebind", "test_stamina", "test_checklist_viewer", "test_shelved_races", "test_main_weapon_and_sidearm", "test_bestiary_and_wings", "test_own_effects", "test_stone_status", "test_race_actives", "test_race_active_fixes", "test_launches_and_ragdolls", "test_top_review_fixes", "test_throwing_knife", "test_myths", "test_pin_to_wall", "test_aiming", "test_glide", "test_paired_claws", "test_stealth", "test_practice_picks", "test_target_search", "test_demon_and_wings", "test_art_checklist", "test_combat_feel", "test_blood_and_falls", "test_bull_rush", "test_end_of_run_exit", "test_audit_fixes", "test_audit_fixes_2", "test_hit_effects", "test_rhythm_and_charge", "test_weapon_and_spell_feel", "test_grab_crush_hurl", "test_chain_grab", "test_throwable_items", "test_body_split", "test_crowd_split", "test_strike_frames", "test_anim_library", "test_endless_waves", "test_kill_reported_once", "test_arena_menu", "test_arena_tactics", "test_grab_aim_and_slams", "test_training_ground", "test_arena_textures", "test_arena_look", "test_mythical_roster",
	]
	if OS.get_environment("ONLY") != "":  # ONLY=test_mount,test_stealth runs just those
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
	check(GameData.weapon_options("dwarf").size() == GameData.rows("weapons").size() - GameData.sidearms().size(), "a race with blank weapon_options can pick any main weapon")


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
	var s := _scripted()
	s.press("dodge")
	await _frames(2)
	check(p.state == Player.State.DODGE, "dodge started")
	var hit := DamageInfo.make(50.0, "Physical", DamageInfo.Kind.ENEMY, null)
	check(p.take_hit(hit) == 0.0, "no damage during i-frames")
	await _frames(30)
	check(p.state == Player.State.FREE, "dodge ended")


func test_guardian_parry() -> void:
	# The Guardian's signature move (DECISIONS 2026-11-16): a parry on the dodge key, a shield in the left hand.
	var p: Player = _arena.player
	check(not p.parries(), "other classes still dodge")
	p.equip("greatsword", p.sidearm_id)
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
	check(p._aiming and p._aim_ring != null and p._aim_ring.global_position.distance_to(target) < 1.0, "holding the ultimate key shows where it will land")
	s.hold({"ultimate_released": true, "aim_point": target}, 1)
	await _frames(int(UltimateFx.impact_time() * Engine.physics_ticks_per_second) + 15)
	check(not p._aiming and p.abilities.ready_in("Ultimate") > 0.0, "releasing casts it")
	check(far.all(func(e): return e.health.hp < e.health.max_hp), "the ultimate lands where you aimed")
	check(near.all(func(e): return e.health.hp == e.health.max_hp), "and not around you")
	var way_off := p.aim_target(p.global_position + Vector3(0, 0, -200))
	check(Vector2(way_off.x - p.global_position.x, way_off.z - p.global_position.z).length() <= p.abilities.aim_range() + 0.1, "you can't aim past the ultimate's range")


## Every element's Ultimate (user, 2026-11-10): a magic circle opens over the aimed spot, and the
## element falls from it and deals the ultimate's damage there, not before.
func test_ultimate_circles() -> void:
	var p: Player = _arena.player
	var kept: Dictionary = p.abilities.defs
	for god in ["storm_god", "snow_god", "animal_god", "sun_god"]:  # Fire has its own: test_fire_ultimate
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


## The Fire ultimate (user, 2026-11-19): boot jets lift you ult_lift_height up, three magic circles
## open around your head and each fires a giant Fire Lance beam at the aimed spot, hurting what's
## there; then you come back down.
func test_fire_ultimate() -> void:
	var p: Player = _arena.player
	var kept: Dictionary = p.abilities.defs
	p.abilities.load_for("forge_god")
	p.abilities.remaining["Ultimate"] = 0.0
	var enemies := _cluster(3, 12.0, "barb_warlord")
	for e in enemies:
		e.freeze(5.0)
	var t: CombatTuning = GameData.tuning
	var ground_y: float = p.global_position.y
	var spot: Vector3 = p.global_position + Vector3(0, 0, -12)
	check(p.abilities.cast("Ultimate", p, Vector3.FORWARD, spot), "the Fire ultimate casts")
	await _frames(int(t.ult_lift_time * Engine.physics_ticks_per_second) + 3)
	check(p.global_position.y > ground_y + t.ult_lift_height - 0.5, "the boot jets lift you %.0f m up (%.1f)" % [t.ult_lift_height, p.global_position.y - ground_y])
	check(p.abilities._jets.all(func(j): return is_instance_valid(j) and j.get_parent() == p), "the jets ride along under your boots")
	var over := get_tree().get_nodes_in_group("magic_circle").filter(func(c):
		var to: Vector3 = c.global_position - p.global_position
		return to.y > 0.5 and to.length() < 5.0)
	check(over.size() == 3, "three magic circles open around your head up there (%d)" % over.size())
	check(enemies.all(func(e): return e.health.hp == e.health.max_hp), "the beams haven't fired yet")
	await _frames(int((t.ult_beam_delay + t.ult_beam_gap * 2.0) * Engine.physics_ticks_per_second) + 4)
	check(enemies.any(func(e): return e.health.hp < e.health.max_hp), "a fire lance beam shoots from each circle to where you aimed")
	var fires := get_tree().get_nodes_in_group("hazards").filter(func(h): return Vector2(h.global_position.x - spot.x, h.global_position.z - spot.z).length() < 3.0)
	check(fires.size() == 3, "and the ground burns where each one lands (%d)" % fires.size())
	await _frames(int(Engine.physics_ticks_per_second * 0.6))
	check(enemies.any(func(e): return e.statuses.has("fire")), "setting alight whoever stands in it")
	check(p.abilities.levitating(), "you stay up while the beams burn")
	var beam: Dictionary = p.abilities._ult_beams[0]
	p._crosshair = beam.from + Vector3(8, -4, -6)
	p.abilities._ult_beam_aim(beam)
	check((beam.dir as Vector3).dot((p._crosshair + beam.side - beam.from).normalized()) > 0.99, "the beams follow your aim")
	await _frames(int((t.ult_beam_time + 1.5) * Engine.physics_ticks_per_second))
	check(not p.abilities.levitating() and p.global_position.y < ground_y + 0.5 and p.abilities._jets.is_empty(), "then the jets stop and you come back down")
	for e in enemies:
		e.queue_free()
	p.abilities.defs = kept
	await _frames(40)
	check(get_tree().get_nodes_in_group("magic_circle").is_empty(), "the shoulder circles close afterwards")


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
	var enemies := _cluster(4, 1.5, "barb_warlord")
	var s := _scripted()
	s.press("signature")
	await _frames(5)
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
	var head: Vector3 = p.visual.head_position(Vector3.INF)
	var circles := get_tree().get_nodes_in_group("magic_circle").filter(func(c): return c.global_position.distance_to(head) < 0.8)
	check(circles.size() == 1 and absf(circles[0].scale.x - 0.5) < 0.05, "the beam fires from a 1 m magic circle before your brow (user, 2026-11-19)")
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
	for weapon in ["warhammer", "greatsword", "naginata", "bow"]:
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
	var s := Run.start_new("dwarf", "forge_god", 31, "naginata")
	var p: Player = _arena.player
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
	p.setup(p.race_id, "forge_god", "warhammer", "bow")
	p._use_sidearm(true)
	var arrow := p.fire_projectile(p.facing, 60.0, 10.0, DamageInfo.Kind.HEAVY, 0, [])
	booms = explosions.call()
	if arrow != null and arrow.on_land.is_valid():
		arrow.on_land.call(p.global_position + p.facing * 10.0)
	check(arrow != null and explosions.call() == booms + 1, "a heavy arrow plays your god's explosion where it lands (user, 2026-11-08)")
	p._use_sidearm(false)
	p.setup(p.race_id, god)
	before = Combat.effects_root.get_child_count()
	ElementFx.hit("Ice", p.global_position + Vector3(0, 1, -3))
	check(Combat.effects_root.get_child_count() == before + 1 and mine.call("Mine_*") == 2, "one you haven't made keeps the code effect")
	var aura := ElementFx.aura("Fire", 1.0)
	check(aura is CPUParticles3D and aura.find_child("Mine_fire_aura", false, false) != null, "your aura rides along like the code's (start and stop work the same)")
	aura.free()
	p.setup("dwarf", "forge_god", "warhammer", "bow")
	p.abilities.remaining["Signature"] = 0.0
	var code_before: int = Combat.effects_root.get_children().filter(func(n): return n is CPUParticles3D).size()
	p.abilities.cast("Signature", p, p.facing)
	check(mine.call("Mine_forge_eruption") == 1, "a god ability plays your scene for it (%s)" % GameData.text(p.abilities.defs.Signature, "ability_id"))
	check(Combat.effects_root.get_children().filter(func(n): return n is CPUParticles3D).size() == code_before and not ElementFx.quiet, "and the code's element particles stay quiet while it does")
	await _frames(60)
	check(mine.call("Mine_*") == 0, "your effects free themselves when they're done")
	ElementFx.OWN_FX = saved_path
	ElementFx._own = {}


func test_bestiary_and_wings() -> void:
	Meta.persist = false
	var p: Player = _arena.player
	p.god_mode = true
	# Holding attack is just an attack; C switches to the sidearm and back (user, 2026-11-08).
	p.setup("dwarf", "forge_god", "warhammer", "bow")
	var input := _scripted()
	input.hold({"light": true, "light_held": true}, 1)
	input.hold({"light_held": true}, 90)
	await _frames(80)
	check(not p.using_sidearm and p.weapon_class() == "Heavy", "holding left click doesn't draw the sidearm")
	await _frames(40)
	input.press("switch_weapon")
	await _frames(4)
	check(p.using_sidearm and p.weapon_class() == "Ranged" and p.aiming, "the wheel switches to the bow, with the crosshair")
	input.press("light")
	await _frames(4)
	check(p.state == Player.State.LIGHT and p.using_sidearm, "a click shoots it")
	await _frames(90)
	check(p.using_sidearm, "and it stays out")
	input.press("heavy")
	await _frames(6)
	check(p.state != Player.State.HEAVY and p.bow_left > 0.0, "one shot, then the bow waits (%.1f s left)" % p.bow_left)
	p.bow_left = 0.0
	input.press("heavy")
	await _frames(6)
	check(p.state == Player.State.HEAVY and p.using_sidearm, "and once it's ready, right click fires it too")
	await _frames(120)
	input.press("sidearm")
	await _frames(4)
	check(not p.using_sidearm and p.weapon_class() == "Heavy", "C from the bow: back to the melee weapon")
	input.press("light")
	var swung := false
	for i in 20:
		await _frames(1)
		swung = swung or (p.state == Player.State.LIGHT and not p.using_sidearm)
	check(swung, "a click swings the main weapon")
	await _frames(60)
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
	demon.target = p
	var bullets: Array = []
	var count := func(n): if n is Projectile: bullets.append(n)
	get_tree().node_added.connect(count)
	var to: Vector3 = p.global_position - demon.global_position
	demon.rotation.y = atan2(-to.x, -to.z)
	demon._strike(30.0, to, to.length())
	await _frames(45)
	get_tree().node_added.disconnect(count)
	check(bullets.size() == Enemy.BURSTS["horde_minigun_demon"], "one attack is a burst of %d bullets (%d)" % [Enemy.BURSTS["horde_minigun_demon"], bullets.size()])
	demon.queue_free()
	input.hold({}, 1)


func test_main_weapon_and_sidearm() -> void:
	var mains := GameData.weapon_options("dwarf")
	check(mains.size() == 4 and "naginata" in mains and not "guandao" in mains and not "mace" in mains, "four main weapons to start with (%s)" % ", ".join(mains))
	check(GameData.sidearms() == ["bow"], "and one sidearm: the bow (user, 2026-11-19: no staff)")
	check(GameData.rows("weapons").size() == 5, "only the five weapons in use are on the sheet")
	check(GameData.text(GameData.weapon("twin_khopesh"), "weapon_class") == "Twin" and WeaponMoveset.for_class("Twin") is WeaponMoveset.Twin, "twin blades are their own class")
	check(ModelRegistry.weapon_model("naginata").ends_with("weapon_naginata.glb"), "the naginata has its own model")
	check(ModelRegistry.weapon_model("bow", "macaque").ends_with("macaque/weapon_bow.glb") and ModelRegistry.weapon_model("bow", "dwarf").ends_with("dwarf/weapon_bow.glb"),
		"a race's own weapon versions are used for that race")
	check(ModelRegistry.weapon_model("naginata", "macaque") == ModelRegistry.OWN + "weapon_naginata.glb"
		and ModelRegistry.weapon_model("naginata", "minotaur").ends_with("minotaur/weapon_naginata.glb") and ModelRegistry.weapon_model("naginata", "frog").ends_with("frog/weapon_naginata.glb"),
		"polearms by race: your naginata for the macaques, the minotaurs' and frogfolk's own (user, 2026-11-09; the dwarves' is your lance, below)")
	# Every race has its own set of all five weapons (user, 2026-11-09).
	var shared: Array = []
	for r in GameData.rows("races"):
		for w in GameData.rows("weapons"):
			if not ModelRegistry.weapon_model(w.weapon_id, r.race_id).contains("/%s/" % r.race_id):
				shared.append("%s %s" % [r.race_id, w.weapon_id])
	check(shared == ["macaque naginata"], "every race has its own version of every weapon; only the macaques' polearm is your naginata (%s)" % [shared])
	check(ModelRegistry.weapon_model("bow", "nobody") == ModelRegistry.weapon_model("bow"), "and the normal weapon where there is no race version")
	check(ModelRegistry.own("dwarf/gear_knife.glb") != "", "the dwarves throw axes instead of knives")
	# Each race has the same classes, each with its own look (user, 2026-11-17): own/<race>/<class>/.
	check(ModelRegistry.weapon_model("greatsword", "dwarf") == ModelRegistry.OWN + "dwarf/guardian/weapon.glb"
		and ModelRegistry.weapon_model("warhammer", "dwarf") == ModelRegistry.OWN + "dwarf/barbarian/weapon.glb"
		and ModelRegistry.weapon_model("naginata", "dwarf") == ModelRegistry.OWN + "dwarf/lancer/weapon.glb",
		"a race's class weapons come from its class folders (the user's dwarf axe, warhammer and lance)")
	check(ModelRegistry.for_race("dwarf", "Guardian") == ModelRegistry.for_race("dwarf") and ModelRegistry.class_part("dwarf", "Guardian", "body") == "",
		"a class without its own body for a race wears the race's model")
	check(ModelRegistry.weapon_model("bow", "dwarf") == ModelRegistry.own("dwarf/weapon_bow.glb"), "sidearms without your own file keep the race's generated one")
	var p: Player = _arena.player
	p.god_mode = true
	p.setup("dwarf", "forge_god", "greatsword", "bow")
	check(is_equal_approx(p._light_duration() * 1.5 * GameData.num(GameData.weapon("greatsword"), "weapon_attacks_per_sec", 1.2) * p.stats.mult("attack_speed_pct") * GameData.tuning.light_speed_mult, 1.0),
		"sword swings are 50% faster (user, 2026-11-08)")
	var dash_from := p.global_position
	p.moveset.heavy_hit(p)
	await _frames(1)
	var first := p.global_position.distance_to(dash_from)
	await _frames(15)
	check(first < 2.5 and p.global_position.distance_to(dash_from) > 3.0,
		"the sword's heavy dashes forward, not in one jump (%.1f m in a frame, %.1f m after)" % [first, p.global_position.distance_to(dash_from)])
	var input := _scripted()
	input.press("sidearm")
	await _frames(4)
	check(p.using_sidearm and p.weapon_class() == "Ranged" and p.aiming, "C draws the sidearm, with the crosshair")
	input.press("sidearm")
	await _frames(4)
	check(not p.using_sidearm and p.weapon_class() == "Blade", "pressed again: back to your class's weapon")
	# Classes (user, 2026-11-09): your class is your melee weapon, with its own strengths.
	check(GameData.text(GameData.weapon("warhammer"), "class_name") == "Barbarian" and GameData.text(GameData.weapon("twin_khopesh"), "class_name") == "Rogue",
		"the warhammer is the Barbarian's, the twin blades the Rogue's")
	var plain_hp: float = p.health.max_hp
	var plain_move: float = p.stats.get_stat("move_speed_pct")
	p.equip("warhammer", p.sidearm_id)
	check(p.health.max_hp > plain_hp and p.stats.get_stat("magic_pct") < 0.0 and p.stats.get_stat("melee_pct") > 0.0,
		"a Barbarian has more health and melee damage, less magic (%.0f -> %.0f hp)" % [plain_hp, p.health.max_hp])
	p.equip("twin_khopesh", p.sidearm_id)
	check(p.stats.get_stat("move_speed_pct") > plain_move and p.stats.get_stat("stealth_pct") > 0.0 and p.stats.get_stat("missile_pct") > 0.0,
		"a Rogue is faster, harder to spot and better with bow and knives")
	var foe: Enemy = _cluster(1, 30.0)[0]
	foe.aggro_radius = 20.0  # arena units see the whole arena
	var hidden := foe._notice_distance()
	p.equip("greatsword", p.sidearm_id)
	check(hidden < foe._notice_distance(), "enemies notice a Rogue closer (%.1f m vs %.1f m)" % [hidden, foe._notice_distance()])
	foe.queue_free()
	# The mouse wheel switches and stays switched (user, 2026-11-08).
	check(Controls.binding_text("switch_weapon") == "Wheel Up / Wheel Down", "scrolling the wheel switches weapon (%s)" % Controls.binding_text("switch_weapon"))
	input.press("switch_weapon")
	await _frames(12)
	check(p.using_sidearm and p.weapon_class() == "Ranged", "a turn of the wheel draws your sidearm, and it stays out")
	input.press("switch_weapon")
	await _frames(4)
	check(not p.using_sidearm and p.weapon_class() == "Blade", "another turn puts the main weapon back")
	# The frogfolk's bow is a blowgun, held at the mouth, shooting darts (user, 2026-11-10).
	p.setup("frog", "forge_god", "warhammer", "bow")
	p._use_sidearm(true)
	var slot: Array = p.visual.find_children("*", "BoneAttachment3D", true, false).filter(func(s): return s.get_child_count() > 0 and not s.is_queued_for_deletion())
	var dart := p.fire_projectile(p.facing, 45.0, 1.0, DamageInfo.Kind.LIGHT, 0, [])
	check(p.moveset is WeaponMoveset.Blowgun and slot.size() == 1 and slot[0].bone_name == "head" and dart != null and (dart._mesh.mesh as BoxMesh).size.x < 0.1,
		"the frogfolk hold a blowgun at the mouth and shoot darts")
	if dart != null:
		dart.queue_free()
	p.setup("dwarf", "forge_god", "warhammer", "bow")
	# The bow (user, 2026-11-19): one heavy bolt through everyone in its path, then a 10 s wait.
	p._use_sidearm(true)
	var shots: Array = []
	var count := func(n: Node) -> void:
		if n is Projectile:
			shots.append(n)
	get_tree().node_added.connect(count)
	p.moveset.light_hit(p, false)
	get_tree().node_added.disconnect(count)
	check(shots.size() == 1 and shots[0].pierce >= 99 and shots[0].template.kind == DamageInfo.Kind.HEAVY
		and is_equal_approx(p.bow_left, GameData.tuning.bow_cooldown) and is_equal_approx(GameData.tuning.bow_cooldown, 10.0),
		"a bow shot is one heavy bolt that goes through every enemy, then the bow waits 10 s")
	for b in shots:
		b.queue_free()
	p.bow_left = 0.0
	p._use_sidearm(false)
	input.hold({}, 1)


func test_shelved_races() -> void:
	for race in GameData.SHELVED_RACES:
		check(GameData.rows("races").all(func(r): return r.race_id != race) and GameData.where("army_units", "race_id", race).is_empty(),
			"the %s is set aside: not offered, no army in fights" % race)
		check(GameData.text(GameData.race(race), "race_id") == race, "but its row still loads, for old saves and later")
	# Milestone 1's roster (Council VIII; gods cut to Fire, Ice, Lightning, Stone 2026-11-16).
	var start: Array = GameData.rows("races").filter(func(r): return not r.race_id in GameData.START_HIDDEN_RACES)
	var elements: Array = GameData.rows("gods").map(func(g): return GameData.text(g, "element"))
	elements.sort()
	check(start.size() == 10 and elements == ["Fire", "Ice", "Lightning", "Stone"], "10 races to start as and the Fire, Ice, Lightning and Stone gods (%d, %s)" % [start.size(), elements])
	var shelved := func(r): return r.get("god_id") in GameData.SHELVED_GODS or r.get("god_a") in GameData.SHELVED_GODS or r.get("god_b") in GameData.SHELVED_GODS
	check(not GameData.rows("god_abilities").any(shelved) and not GameData.rows("godly_gifts").any(shelved) and not GameData.rows("duo_godly_gifts").any(shelved),
		"set-aside gods' abilities, gifts and duo gifts are never offered")
	check(GameData.text(GameData.god("moon_god"), "god_id") == "moon_god", "but their rows still load")


func test_race_actives() -> void:
	var p: Player = _arena.player
	p.god_mode = false
	for r in GameData.rows("races"):
		p.setup(r.race_id, "forge_god")
		p.health.heal(99999.0)
		p.race_active.cooldown = 0.0
		p.abilities.invulnerable = false  # the Angel's dive may still be in the air
		var foes := _cluster(2, 3.0)
		p.facing = Vector3(0, 0, -1)
		foes[0].global_position = p.global_position + Vector3(0, 0, -3)  # straight ahead: line skills are narrow
		var hp: float = foes[0].health.hp
		check(p.race_active.cast() and p.race_active.cooldown > 0.0 and not p.race_active.cast(), "the %s active runs, then cools down (%s)" % [r.race_id, p.race_active.title()])
		await _frames(2)
		p.race_active.invulnerable = false
		p.race_active._charge_time = -1.0
		if r.race_id in ["elf", "bird", "owl", "elephant", "dragon", "macaque", "treekin"]:
			check(not is_instance_valid(foes[0]) or foes[0].health.hp < hp, "the %s active hurts enemies" % r.race_id)
		if r.race_id in ["macaque", "treekin"]:
			check(not is_instance_valid(foes[0]) or foes[0].state == Enemy.State.FROZEN or foes[0].is_dead(), "the %s active holds them in place" % r.race_id)
		for e in foes:
			if is_instance_valid(e):
				e.queue_free()
		await _frames(1)
	p.setup("dwarf", "forge_god")
	p.race_active.cooldown = 0.0
	p.race_active.cast()
	check(p.is_invulnerable(), "the dwarf can't be hurt while its active lasts")
	p.race_active.invulnerable = false
	var s := _scripted()
	p.race_active.cooldown = 0.0
	get_tree().paused = false  # the kills above may have opened a level-up choice
	p.abilities.invulnerable = false
	s.press("race_active")
	await _frames(3)
	check(p.race_active.cooldown > 0.0, "the race skill has its own button")


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
	# The Minotaur's charge goes through an enemy instead of stopping at it.
	p.setup("minotaur", "forge_god")
	await _until_on_floor()
	p.facing = Vector3(0, 0, -1)
	e.global_position = p.global_position + Vector3(0, 0, -3)
	e.freeze(5.0)
	var hp: float = e.health.hp
	p.race_active.cooldown = 0.0
	p.abilities.invulnerable = false
	get_tree().paused = false
	var held := _scripted()
	held.hold({"race_active_held": true}, 40)
	p.race_active.cast()
	await _frames(30)
	check(p.race_active._charge_time > 0.0, "a charge keeps going after it reaches an enemy (%.2f)" % p.race_active._charge_time)
	check(not is_instance_valid(e) or e.health.hp < hp, "and hurts the enemy it runs into")
	p.race_active._charge_time = -1.0
	p.race_active.invulnerable = false
	if is_instance_valid(e):
		e.queue_free()
	# Bosses shake off being held in half the time.
	var big: Enemy = _cluster(1, 6.0)[0]
	big.is_large = true
	p.race_active._hold(big, 4.0)
	check(is_equal_approx(big._state_len, 2.0), "a large enemy is held half as long (%.1f s)" % big._state_len)
	big.queue_free()
	check(GameData.num(GameData.race("dwarf"), "duration") == 5.0 and GameData.num(GameData.race("frog"), "active_bonus_damage") == 50.0, "the race skill numbers are the user's choices")
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
	check(is_equal_approx(Vector2(v.x, v.z).length(), t.launch_speed * 1.3 * _arena.player.moveset.launch_scale()), "launched 30%% faster (times the weapon class) (%.1f m/s)" % Vector2(v.x, v.z).length())
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


func test_throwing_knife() -> void:
	var p: Player = _arena.player
	p.god_mode = true
	var key := InputEventKey.new()
	key.physical_keycode = KEY_G
	check(InputMap.event_is_action(key, "throw_knife"), "G throws the knife")
	var god_key := InputEventKey.new()
	god_key.physical_keycode = KEY_P
	check(InputMap.event_is_action(god_key, "god_mode"), "P is god mode")
	# Every god's knife has its own throw, path and explosion, and every one lands and deals its type.
	var clips := {}
	var blasts := {}
	for g in GameData.rows("gods"):
		var element := GameData.text(g, "element")
		check(HomingKnife.STYLES.has(element), "%s's %s has a knife style" % [g.god_id, element])
		clips[HomingKnife.throw_clip(element)] = true
		blasts[HomingKnife.STYLES.get(element, HomingKnife.STYLES["Physical"])[5]] = true
		check(p.visual.anim.has_animation(HomingKnife.throw_clip(element)), "%s's throw animation exists" % element)
		p.setup("human", g.god_id)
		await _frames(1)
		get_tree().paused = false
		var targets := _cluster(3, 22.0)
		for e in targets:
			e.global_position = p.global_position + Vector3(0, 0, -22) + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))
			e.set_physics_process(true)
		var hp: Array = targets.map(func(e): return e.health.hp)
		var seen := []
		var listen := func(_t, info: DamageInfo, _d):
			seen.append(info.damage_type)
		Combat.hit_landed.connect(listen)
		p._knife_left = 0.0
		var thrown := p.throw_knife(p.rotation.y)
		for i in 240:
			get_tree().paused = false
			await _frames(1)
			if not seen.is_empty():
				break
			for e in targets:  # they run: it still catches them
				if is_instance_valid(e) and not e.is_dead():
					e.global_position += Vector3(0, 0, -0.08)
		Combat.hit_landed.disconnect(listen)
		check(thrown and seen.size() >= 3, "%s's knife hits everyone in the blast (%d)" % [element, seen.size()])
		check(seen.all(func(d): return d == element), "with %s damage (%s)" % [element, seen])
		for e in targets:
			if is_instance_valid(e):
				e.queue_free()
		await _frames(1)
		await _frames(1)
	check(clips.size() == GameData.rows("gods").size() and blasts.size() == GameData.rows("gods").size(), "each damage type has its own throw and explosion (%d, %d)" % [clips.size(), blasts.size()])
	p._knife_left = 1.0
	check(not p.throw_knife(0.0), "and it has a cooldown")
	p._knife_left = 0.0
	# The aura around the weapon, in your god's color, through weapon swaps.
	p.setup("human", "forge_god")
	await _frames(1)  # the last god's weapon goes away at the end of the frame
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
	p.setup("human", "forge_god", "bow")
	await _until_on_floor()
	var newest := func() -> Projectile:
		var shots: Array = Combat.effects_root.get_children().filter(func(n): return n is Projectile and not n.is_queued_for_deletion())
		return shots[-1] if not shots.is_empty() else null
	# Straight ahead with nothing to aim at: it still drops a little.
	p._crosshair = Vector3.INF
	p.fire_projectile(p.facing, 45.0, 1.0, DamageInfo.Kind.LIGHT, 0, [])
	var flat: Projectile = newest.call()
	check(flat != null and flat.drop == GameData.tuning.missile_gravity and flat.aimed, "arrows have a little drop")
	var y0: float = flat.velocity.y
	await _frames(20)
	check(is_instance_valid(flat) and flat.velocity.y < y0 - 1.0 and flat.velocity.y > -6.0, "they fall as they fly, not much (%.1f m/s)" % flat.velocity.y)
	# Up and down, at whatever the crosshair is on.
	var muzzle: Vector3 = p.global_position + Vector3.UP * 1.3
	var up_at := muzzle + p.facing * 20.0 + Vector3.UP * 12.0
	p._crosshair = up_at
	p.fire_projectile(p.facing, 45.0, 1.0, DamageInfo.Kind.LIGHT, 0, [])
	var up: Projectile = newest.call()
	check(up.velocity.y > 15.0, "aiming up shoots up (%.1f m/s)" % up.velocity.y)
	p._crosshair = muzzle + p.facing * 10.0 + Vector3.DOWN * 6.0
	p.fire_projectile(p.facing, 45.0, 1.0, DamageInfo.Kind.LIGHT, 0, [])
	check(newest.call().velocity.y < -15.0, "aiming down shoots down")
	p._crosshair = muzzle - p.facing * 3.0
	p.fire_projectile(p.facing, 45.0, 1.0, DamageInfo.Kind.LIGHT, 0, [])
	check(newest.call().velocity.normalized().dot(p.facing) > 0.9, "a crosshair behind you doesn't shoot backwards")
	# An arrow is aimed a little high so it drops onto the point you picked (user, 2026-11-05).
	var far_at := muzzle + p.facing * 40.0
	p._crosshair = far_at
	var aimed := p.aim_direction(muzzle + p.facing * 0.6, 45.0, GameData.tuning.missile_gravity)
	var t_fly := 40.0 / 45.0
	var lands := muzzle + p.facing * 0.6 + aimed * 45.0 * t_fly + Vector3.DOWN * 0.5 * GameData.tuning.missile_gravity * t_fly * t_fly
	check(aimed.y > 0.0 and lands.distance_to(far_at) < 1.0, "a far arrow is aimed high and lands on the crosshair (%.2f m off)" % lands.distance_to(far_at))
	check(p.aims_with_body(), "a bow puts the camera over your shoulder and shows the reticle")
	# A shot over someone's head misses; one at them hits.
	await _frames(100)  # the shots above have gone
	var foe: Enemy = _cluster(1, 8.0)[0]
	foe.global_position = p.global_position + p.facing * 8.0
	foe.health.setup(9999.0)
	await _frames(1)
	var hp: float = foe.health.hp
	p._crosshair = foe.global_position + Vector3.UP * 14.0
	p.fire_projectile(p.facing, 45.0, 50.0, DamageInfo.Kind.LIGHT, 0, [])
	await _frames(20)
	check(foe.health.hp == hp, "a shot over their head misses")
	p._crosshair = foe.global_position + Vector3.UP
	p.fire_projectile(p.facing, 45.0, 50.0, DamageInfo.Kind.LIGHT, 0, [])
	await _frames(20)
	check(foe.health.hp < hp, "a shot at them hits")
	foe.queue_free()
	# Shots stop at the ground.
	p._crosshair = muzzle + p.facing * 3.0 + Vector3.DOWN * 3.0
	p.fire_projectile(p.facing, 45.0, 1.0, DamageInfo.Kind.LIGHT, 0, [])
	var low: Projectile = newest.call()
	await _frames(15)
	check(not is_instance_valid(low), "a shot into the ground stops there")
	# The camera looks nearly straight up and down, and the crosshair is on screen.
	check(_arena.camera_rig.max_pitch > 1.0 and _arena.camera_rig.min_pitch < -1.3, "you can look almost straight up and down")
	p._crosshair = Vector3.INF
	p.setup("dwarf", "forge_god")


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
	var src := FileAccess.get_file_as_string("res://scripts/valley/wilds.gd")
	check(not src.contains("Discovered:"), "finding a new kind of creature shows no message")


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
	# Sure aim: an enemy right in the crosshair within 30 m is hit by a bow.
	p.setup("human", "forge_god", "bow")
	await _until_on_floor()
	var foe: Enemy = _cluster(1, 20.0)[0]
	foe.global_position = p.global_position + p.facing * 20.0
	await _frames(2)
	var muzzle := p.global_position + Vector3.UP * 1.3
	p._crosshair = foe.global_position + Vector3.UP * 1.0 + Vector3.UP * 0.4  # a little off, still in the circle
	check(p.sure_target(muzzle, t.aim_cone_missile_deg, p.sure_range()) == foe, "the enemy at the crosshair is the bow's target")
	p._crosshair = foe.global_position + Vector3.UP * 12.0
	check(p.sure_target(muzzle, t.aim_cone_missile_deg, p.sure_range()) == null, "but not one well off it")
	check(is_equal_approx(p.sure_range(), t.sure_range_bow), "a bow is sure to 30 m")
	p._crosshair = foe.global_position + Vector3.UP
	var hp := foe.health.hp
	p.fire_projectile(p.facing, 45.0, 5.0, DamageInfo.Kind.LIGHT, 0, [])
	await _frames(40)
	check(foe.health.hp < hp, "and the arrow hits it")
	var stuck := foe.find_children("*", "MeshInstance3D", false, false).size() > 0
	check(stuck, "and stays stuck in it a while")
	# A heavy shot doesn't pass through any more.
	check(not FileAccess.get_file_as_string("res://scripts/combat/weapon_moveset.gd").contains("DamageInfo.Kind.HEAVY, 5,"), "a heavy shot doesn't pierce (that's for godly gifts)")
	# Bosses show a health bar when they fight you.
	foe.mini_boss = true
	foe.target = p
	_arena.hud._boss_look = 0.0
	await _frames(2)
	check(_arena.hud._boss_box.visible and _arena.hud.boss == foe, "a boss fighting you shows its health bar")
	foe.queue_free()
	p.setup("human", "forge_god", "warhammer")


func test_end_of_run_exit() -> void:
	# Playtest 2026-11-05: the final kill's level-up took the mouse from "Back to the start screen".
	var hud: Hud = _arena.hud
	hud.offer_choice("test", "A choice", ["a"], ["1.  A"])
	hud.show_action("Back to the start screen", func(): pass)
	hud._pick(0)
	check(hud.mouse_after_choice() == Input.MOUSE_MODE_VISIBLE, "closing a menu leaves the mouse free while the end-of-run button waits")
	hud._action.queue_free()
	await _frames(1)
	check(hud.mouse_after_choice() == Input.MOUSE_MODE_CAPTURED, "otherwise the mouse goes back to the camera")
	check(FileAccess.get_file_as_string("res://scripts/arena/arena.gd").contains("if not Run.active or Run.state.pending_level_ups"), "no level-up opens after the run is over")


func test_bull_rush() -> void:
	var p: Player = _arena.player
	p.setup("minotaur", "forge_god")
	await _until_on_floor()
	# A minotaur sprinting flat out tramples what's in front.
	p.god_mode = false
	p.flying = false
	var foe: Enemy = _cluster(1, 1.5)[0]
	await _frames(1)
	foe.health.setup(9999.0)
	p.velocity = p.facing * GameData.tuning.sprint_speed
	p._rush_time = 0.0
	p._rushed.clear()
	var hp := foe.health.hp
	p._bull_rush(0.016)
	check(foe.health.hp < hp and not foe.thrown, "a minotaur at a sprint tramples, without throwing at first")
	p._rushed.clear()
	p._rush_time = GameData.tuning.rush_throw_after
	p.velocity = p.facing * GameData.tuning.sprint_speed
	p._bull_rush(0.016)
	check(foe.thrown, "and after 2 s at full speed throws them")
	p.setup("human", "forge_god")
	p.god_mode = true


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
		and not by_file.call("dwarf/rogue/body.glb").is_empty() and not by_file.call("dwarf/knife.glb").is_empty(),
		"each race lists every class's body and weapon, the Guardian's shield and the throwing weapon")
	check(app.current(axe) == ModelRegistry.OWN + "dwarf/guardian/weapon.glb", "and shows what the game uses now (the user's dwarf axe)")
	var villager: Dictionary = by_file.call(str(GameData.rows("tribe_members")[0].model_file))
	check(app.target(villager).begins_with("user://checklist_test/own/%s/people/" % villager.dir.get_slice("/", 0)), "a villager goes in its race's people folder")
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


func test_target_search() -> void:
	var w: WaveDirector = _arena.waves
	var at: Vector3 = _arena.player.global_position + Vector3(0, 0, 80)
	var me := w.spawn("barb_raider", at)
	var foes: Array = []
	for i in 30:
		foes.append(w.spawn("barb_raider", at, Enemy.Team.FRIENDLY))
	var far := w.spawn("barb_raider", at + Vector3(45, 0, 0), Enemy.Team.FRIENDLY)
	await _frames(2)
	var nearest: Node3D = null
	for f in foes:
		if nearest == null or me.global_position.distance_to(f.global_position) < me.global_position.distance_to(nearest.global_position):
			nearest = f
	var any := func(u: Enemy, d: float) -> float: return d
	check(w.director.best_near(me, Enemy.Team.FRIENDLY, 70.0, any) == nearest, "the target search finds the nearest foe among many")
	check(w.director.best_near(me, Enemy.Team.HOSTILE, 70.0, any) == null, "and looks only at the side it asks for")
	for f in foes:
		f.queue_free()
	await _frames(2)
	check(w.director.best_near(me, Enemy.Team.FRIENDLY, 70.0, func(u: Enemy, d: float) -> float: return INF if u.is_dead() else d) == far, "with the near ones gone, it finds the one farther off")
	for u in [me, far]:
		u.queue_free()


func test_practice_picks() -> void:
	var gods: Array = ArenaMenu.elements()
	check(gods.size() >= 4 and not gods.any(func(g): return g in GameData.SHELVED_GODS), "Practice offers every kept god (%s)" % ", ".join(gods))
	var weapons := GameData.weapon_options(Arena.START_RACE)
	var god: String = gods.back()
	var weapon: String = weapons.back()
	_arena.queue_free()
	await _frames(1)
	Flow.practice_god = god
	Flow.practice_weapon = weapon
	_arena = ARENA.instantiate()
	_arena.auto_start = false
	add_child(_arena)
	await _frames(2)
	check(Run.state.race_id == "dwarf" and Run.state.god_id == god and Run.state.weapon_id == weapon,
		"Practice starts as a dwarf with the god and class picked (%s, %s)" % [Run.state.god_id, Run.state.weapon_id])
	check(_arena.player.god_id == god and god in _arena.offer_gods, "and offers that god's gifts")
	Flow.practice_god = ""
	Flow.practice_weapon = ""


func test_stealth() -> void:
	var p: Player = _arena.player
	var e: Enemy = _arena.waves.spawn("barb_raider", p.global_position + Vector3(0, 0, -15))
	e.aggro_radius = 22.0
	e._aggroed = false
	e.rotation.y = 0.0  # looks toward -Z, away from the player
	check(e._pick_target() == p, "standing, a guard 15 m away notices you")
	e._aggroed = false
	p.is_crouching = true
	check(e._pick_target() == null, "sneaking (crouched) behind a guard 15 m away, it doesn't notice you")
	e.rotation.y = PI  # turns to face you
	check(e._pick_target() == null and e._notice_distance() > 22.0 * 0.4, "sneaking in front of it, it would notice you closer (%.1f m)" % e._notice_distance())
	p.global_position = e.global_position + Vector3(0, 0, 5)
	check(e._pick_target() == p, "sneak right up to it and it notices you")
	p.is_crouching = false
	await _frames(1)


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
		e.setup(id, p, _arena.director, Enemy.Team.NEUTRAL)
		e.post = p.global_position + Vector3(20, 0, 0)
		_arena.add_child(e)
		e.global_position = e.post
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
	# Units freed alive (warriors heading home) leave the crowd, or the stride counts them forever.
	var gone: Array = []
	for i in 150:
		var e := Enemy.new()
		e.setup("barb_raider", p, d, Enemy.Team.FRIENDLY)
		_arena.add_child(e)
		gone.append(e)
	await _frames(1)
	for e in gone:
		e.queue_free()
	await _frames(2)
	d.separation(p)
	check(d.enemies.size() < 100 and Enemy.crowd_stride == 1, "freed warriors leave the crowd (%d left, stride %d)" % [d.enemies.size(), Enemy.crowd_stride])
	var foe: Enemy = _cluster(1)[0]
	check(d.request_ally_token(foe, p), "an ally token is handed out")
	d.release(foe)
	check(d._ally_holders.is_empty(), "and forgotten once released, so the list doesn't grow all session")
	# Units prefer foes straight ahead (battle lines clash), and never score under their distance.
	var me: Enemy = _cluster(1, 20.0)[0]
	me.rotation.y = 0.0  # facing -Z
	var front := Node3D.new()
	var back := Node3D.new()
	_arena.add_child(front)
	_arena.add_child(back)
	front.global_position = me.global_position + Vector3(0, 0, -6)
	back.global_position = me.global_position + Vector3(0, 0, 5)
	check(me._target_score(front, 6.0) < me._target_score(back, 5.0) and me._target_score(back, 5.0) >= 5.0,
		"a foe 6 m ahead beats one 5 m behind")
	front.queue_free()
	back.queue_free()
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
	# An enemy's arrow finds your warrior through the crowd grid.
	var ally: Enemy = _arena.waves.spawn("barb_raider", Vector3.INF, Enemy.Team.FRIENDLY)
	ally.global_position = p.global_position + Vector3(12, 0, 0)
	ally.post = ally.global_position  # stands still, not following you
	await _frames(2)
	var hp := ally.health.hp
	var shot := Projectile.fire(ally.global_position + Vector3(0, 1, -3), Vector3(0, 0, 1), 30.0, DamageInfo.make(5.0, "Physical", DamageInfo.Kind.ENEMY, null), Color.WHITE)
	shot.hostile = true
	shot.player = p
	await _frames(30)
	check(ally.health.hp < hp, "an enemy arrow hits your warrior (%.0f -> %.0f)" % [hp, ally.health.hp])
	# A wild unit notices a rival by its real distance: one 15 m behind it is inside a 22 m aggro radius.
	var wolf: Enemy = _arena.waves.spawn("beast_dire_wolf")
	var raider: Enemy = _arena.waves.spawn("barb_raider")
	wolf.global_position = Vector3(20, wolf.global_position.y, -20)
	raider.global_position = Vector3(20, wolf.global_position.y, -5)
	wolf.rotation.y = 0.0  # facing -Z, away from the raider
	wolf.faction = "beast_dire_wolf"
	raider.faction = "barbarians"
	wolf.aggro_radius = 22.0
	p.global_position = Vector3(-20, p.global_position.y, 20)  # far off: the rival is the one to notice
	await _frames(1)
	check(wolf._pick_target() == raider, "a wild unit notices a rival 15 m behind it (aggro 22 m)")
	# Rigs that rest their shoulders differently get their own animation library (the cat's and the minotaur's).
	var rigs: Array = []
	for race in ["cat", "minotaur"]:
		var n: Node = (load(ModelRegistry.for_race(race)) as PackedScene).instantiate()
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
		p.equip(w, "bow")
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
		p.equip(w, "bow")
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
	p.equip("warhammer", "bow")


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
	# Not with the sidearm out.
	p._use_sidearm(true)
	check(not p._can_grab(), "no grab with the bow out")
	p._use_sidearm(false)


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
	await hook.call(ogre)
	s.hold({"light_held": true}, 10)
	await _frames(10)
	check(p.chain.mode == Chain.Mode.ANCHOR and p.global_position.distance_to(start) < 1.0, "the chain holds on it and waits")
	s.hold({"light_held": true, "heavy": true}, 1)
	s.hold({"light_held": true}, 40)
	await _frames(41)
	check(p.global_position.distance_to(start) > 3.0, "the chain pulls you to it (%.1f m)" % p.global_position.distance_to(start))
	check(ogre.health.hp < 10000.0, "and you land a drop kick")
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
	# The endless arena's menus: a loadout of weapons and elements, and Esc to pause and back.
	check(ArenaMenu.weapons().size() >= 2 and ArenaMenu.elements().size() >= 2, "weapons and elements to choose from")
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
	a.menu.open_loadout(a.player.god_id, a.player.weapon_id)
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
