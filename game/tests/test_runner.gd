extends Node
## Automated tests. Run from the GodsGame folder:
##   tools\run_tests.bat
## or directly:
##   <godot_console.exe> --headless --path game --fixed-fps 60 res://tests/test_main.tscn
## Exit code 0 = all passed.

const ARENA := preload("res://scenes/main.tscn")
const VALLEY := preload("res://scenes/valley.tscn")
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
	SaveSystem.RUN_PATH = "user://test_run_save.json"
	SaveSystem.PROFILE_PATH = "user://test_profile.json"
	await get_tree().process_frame
	var tests := [
		"test_data_loads", "test_data_is_consistent", "test_rng_is_deterministic", "test_damage_pipeline",
		"test_fire_ticks", "test_godly_gift_offer_and_duo", "test_unbuilt_content_is_hidden", "test_first_fight_and_playtest_numbers", "test_god_pick_and_class_sidearm", "test_run_opens_with_camp_raid", "test_dodge_iframes", "test_guardian_parry",
		"test_searing_strikes_ignites_slam", "test_thunderforged_combo", "test_attack_tokens",
		"test_ability_cast", "test_fire_lance", "test_breakable_props", "test_wall_occluders", "test_ranged_shots_can_be_dodged", "test_aimed_ultimate", "test_ultimate_circles", "test_stone_eruption", "test_ragdoll_death", "test_performance_40_enemies", "test_wave_and_godly_gift_flow", "test_kiln_heart_on_burning_kill",
		"test_sprint_and_jump", "test_slide_boost_and_crouch", "test_models_and_animations",
		"test_valley_generation", "test_evil_tribe_clock", "test_diplomacy", "test_encounters",
		"test_level_ups", "test_one_god_per_race", "test_save_round_trip", "test_meta_unlocks",
		"test_void_mark", "test_all_movesets",
		"test_save_resume_keeps_build", "test_clock_pauses_in_fights", "test_end_to_end_run",
		"test_arena_plays_an_encounter", "test_weapon_choice",
		"test_valley_terrain", "test_battle_sizing", "test_valley_befriend_battle", "test_tribe_welcomes", "test_village_raid_and_sites", "test_valley_wilds", "test_mount", "test_valley_water", "test_islands", "test_new_races", "test_element_effects", "test_home_biomes", "test_controls_rebind", "test_stamina", "test_world_events", "test_pitched_battle", "test_checklist_viewer", "test_mount_keeps_your_pace", "test_race_preview", "test_shelved_races", "test_main_weapon_and_sidearm", "test_spyglass_bestiary_wings", "test_own_effects", "test_stone_status", "test_race_actives", "test_race_active_fixes", "test_launches_and_ragdolls", "test_top_review_fixes", "test_throwing_knife", "test_big_villages", "test_batch_2026_11_09", "test_hollow_tower_climb", "test_menus_wait_their_turn", "test_saves_survive", "test_open_offers_come_back", "test_jungle", "test_myths", "test_giants", "test_caves_and_towers", "test_dungeons", "test_native_animals", "test_exploration_life", "test_pin_to_wall", "test_aiming", "test_god_mode_no_mount", "test_glide", "test_paired_claws", "test_retro_look", "test_stealth", "test_fog_of_war", "test_roads_and_caravans", "test_custom_battle", "test_practice_picks", "test_war_chest", "test_compass_and_crowds", "test_target_search", "test_demon_and_wings", "test_art_checklist", "test_combat_feel", "test_blood_and_falls", "test_mount_stats", "test_mount_orders", "test_camp_stealth", "test_wild_sides", "test_end_of_run_exit", "test_race_carousel", "test_audit_fixes", "test_audit_fixes_2", "test_hit_effects", "test_rhythm_and_charge", "test_weapon_and_spell_feel", "test_grab_crush_hurl", "test_chain_grab", "test_throwable_items", "test_item_field", "test_body_split", "test_crowd_split", "test_strike_frames", "test_anim_library", "test_endless_waves", "test_kill_reported_once", "test_arena_menu", "test_arena_tactics", "test_grab_aim_and_slams", "test_training_ground",
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


func test_run_opens_with_camp_raid() -> void:
	# The opening (user, 2026-11-08): a short clip of you walking home over a hill to your burning,
	# wrecked village. No fight; then the elder sends you after Count Fuckula.
	var v: Valley = await _valley(77, true)
	await _frames(3)
	var clip := v.get_node_or_null("OpeningClip") as OpeningClip
	check(clip != null and not Run.in_fight and v.player.input_source == clip and OpeningClip.LENGTH <= 20.0,
		"a new run opens with a short clip (at most 20 s), no fight")
	var home: Village = v.villages[Run.state.race_id]
	check(Run.state.flags.get("home_burned", false) and home.buildings.has_meta("burned") and ValleyWorld.burned_spots(home.buildings).size() >= 3,
		"your village is burning, its houses wrecked (%d)" % ValleyWorld.burned_spots(home.buildings).size())
	var flat := func() -> float:
		return Vector2(home.global_position.x - v.player.global_position.x, home.global_position.z - v.player.global_position.z).length()
	var far: float = flat.call()
	await _frames(90)
	check(flat.call() < far - 3.0, "you walk toward it (%.0f -> %.0f m)" % [far, flat.call()])
	clip.stop()  # any key skips it
	await _frames(2)
	# Then the gods answer your call (user, 2026-11-16): pledge to one before the elder speaks.
	check(v.player.input_source != clip and v.hud._offer_kind == "god_pick" and not Run.in_fight, "then the gods answer your call")
	var picked: String = v.hud._offer[v.hud._offer.size() - 1]
	v.hud._pick(v.hud._offer.size() - 1)
	await _frames(2)
	check(Run.state.god_id == picked and v.player.god_id == picked, "the god you pick is yours from now on (%s)" % picked)
	check(v.hud._offer_kind == "elder", "then the village elder speaks")
	var pages := 0
	var heard_early := false
	while v.hud.is_choosing() and v.hud._offer_kind == "elder" and pages < 10:
		heard_early = heard_early or Run.state.flags.get("elder_spoke", false)
		pages += 1
		v.hud._pick(0)
		await _frames(1)
	check(pages == v.elder_pages().size() and Run.state.flags.get("elder_spoke", false), "the elder explains the run (%d pages)" % pages)
	check(not heard_early, "and it only counts as heard once the last page closes (quit midway and it comes back)")
	check(v.hud._offer_kind == "god" and v.hud.is_choosing(), "then your god gives you a first godly gift")
	v.hud._pick(0)
	await _frames(2)
	# The fires burn until you leave (user, 2026-11-08); the charred houses stay.
	check(not v._smoke.is_empty(), "the village is still burning while you're there")
	v.player.global_position = home.global_position + Vector3(Valley.FIRE_LEFT + 30.0, 5.0, 0.0)
	await _frames(40)
	check(v._smoke.is_empty() and home.buildings.has_meta("burned"), "leave and the fires go out; the burned houses stay")
	# A weapon found in a chest replaces the one of its kind.
	var before := [Run.state.weapon_id, Run.state.sidearm_id]
	v.offer_weapon()
	await _frames(1)
	var found: String = v.hud._offer[0] if v.hud._offer_kind == "weapon" else ""
	v.hud._pick(0)
	await _frames(2)
	var now := [Run.state.weapon_id, Run.state.sidearm_id]
	check(found != "" and GameData.is_sidearm(found) and now[0] == before[0] and now[1] == found and v.player.sidearm_id == found,
		"a chest's weapon is a sidearm, in place of yours; your class keeps its weapon (%s -> %s)" % [before, now])


func test_first_fight_and_playtest_numbers() -> void:
	var s := _fresh_run(71)
	ValleyTerrain.assign_slots(s)
	var home := ValleyTerrain.region_center(s.flags.home_region)
	var p := ValleyTerrain.site_point(s, "first_fight")
	check(s.encounters.has("first_fight") and p.distance_to(home) < 150.0, "a first fight waits right by your camp (%.0f m)" % p.distance_to(home))
	var fights_before: int = Playtest.fights.size()
	Playtest.fight_started("first_fight")
	await _frames(3)
	check(Playtest._frames > 0 and Playtest._frame_worst > 0.0, "frame times are counted during a fight (%d frames)" % Playtest._frames)
	Playtest.fight_ended("first_fight", true)
	var f: Dictionary = Playtest.fights.back()
	check(Playtest.fights.size() == fights_before + 1 and f.name == "First Fight" and is_equal_approx(f.target, 90.0) and Playtest.first_fight_after >= 0.0,
		"the playtest numbers time each fight against its target")
	check(Playtest.summary().contains("First Fight"), "the F11 overlay lists it")
	check(Playtest.summary().contains("draw calls"), "and shows where a frame's time goes")
	EncounterSystem.start(s, "first_fight")
	check(EncounterSystem.finish(s, "first_fight", true) == s.god_id, "winning the first fight offers a godly gift from your own god")
	_fresh_run()


func test_god_pick_and_class_sidearm() -> void:
	# Fewer picks before a run (user, 2026-11-16): the class sets the sidearm, the god is picked after the opening.
	check(GameData.sidearm_for("warhammer") == "staff" and GameData.sidearm_for("greatsword") == "staff"
		and GameData.sidearm_for("twin_khopesh") == "bow" and GameData.sidearm_for("naginata") == "bow",
		"Barbarian and Guardian start with the staff, Rogue and Lancer with the bow")
	check(Run.start_new("dwarf", "forge_god", 5, 1.0, "twin_khopesh").sidearm_id == "bow", "a run started without a sidearm takes the class's")
	var s := _fresh_run(43)
	var patron := s.god_id
	var offer := Run.god_offer()
	var kept: int = GameData.rows("gods").filter(func(g): return Meta.is_unlocked("gods", g.god_id)).size()
	check(offer.size() == mini(3, kept) and patron in offer and offer.all(func(g): return offer.count(g) == 1),
		"after the opening up to three different gods answer, your race's patron among them (%s)" % ", ".join(offer))
	check(offer == Run.god_offer(), "and the same ones come back if you quit and return")
	# Pick a god the valley already uses elsewhere: it swaps places with the patron.
	# With 4 gods there may be no wild or captive god (and the evil tribe's god is then ""): take a tribe's.
	var other: String = s.wild_gods[0] if not s.wild_gods.is_empty() else s.tribes.values().map(func(t): return t.god).filter(func(g): return g != "" and g != patron)[0]
	Run.choose_god(other)
	var holders := func(g: String) -> int:
		var n: int = s.wild_gods.count(g) + (1 if s.evil.captive_god == g else 0)
		for t in s.tribes.values():
			n += 1 if t.god == g else 0
		return n
	check(s.god_id == other and s.encounters.first_fight.god == other, "the god you pick is yours, and gives the first gift")
	check(holders.call(other) == 0 and holders.call(patron) >= 1, "the patron takes its place in the valley; no god is in two places")
	Run.choose_god(patron)
	check(s.god_id == patron and holders.call(patron) == 0 and holders.call(other) >= 1, "picking back swaps back")
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
	for god in ["forge_god", "storm_god", "snow_god", "animal_god", "sun_god"]:
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


## Breakable props (user, 2026-11-08): a swing breaks a barrel into flying chunks.
## Big battles, first person, no sliding, staff tips, buildings that break, towers to climb (user, 2026-11-09).
func test_batch_2026_11_09() -> void:
	var v: Valley = await _valley(80)
	var p := v.player
	p.god_mode = true
	var t: CombatTuning = GameData.tuning
	# No sliding: from a sprint, letting go stops you within a step or two.
	await _until_on_floor()
	var s := ScriptedInput.new()
	p.input_source = s
	s.hold({"move": Vector2(0, 1), "sprint": true}, 60)
	await _frames(60)
	var from := p.global_position
	s.hold({}, 30)
	await _frames(30)
	var coast := Vector2(p.global_position.x - from.x, p.global_position.z - from.z).length()
	check(coast < 1.5, "letting go of a sprint stops you short, no slide (%.2f m)" % coast)
	# First person: T puts the camera at your eyes and hides your body.
	var rig: CameraRig = v.camera_rig
	var key := InputEventAction.new()
	key.action = "camera_view"
	key.pressed = true
	rig._unhandled_input(key)
	await _frames(3)
	check(rig.first_person and rig._arm.spring_length == 0.0 and p.visual.visible, "T switches to first person; your body and weapons stay visible")
	rig._unhandled_input(key)
	await _frames(3)
	check(not rig.first_person and p.visual.visible, "and back")
	# Spells leave the staff's tip.
	var caster := CharacterModel.new()
	add_child(caster)
	caster.setup(ModelRegistry.for_unit("barb_hedge_witch").model, ModelRegistry.weapon_model("staff"), 1.0)
	caster.global_position = Vector3(500, 0, 500)
	caster.play("Idle_A")
	await _frames(20)  # in its idle pose, staff held up
	var tip_node: Node3D = caster.weapon_tip()
	var away: float = tip_node.global_position.distance_to(tip_node.get_parent().get_parent().global_position) if tip_node != null else 0.0  # from the hand slot
	check(away > 0.6, "a staff has a tip, well away from the hand (%.2f m)" % away)
	caster.queue_free()
	# Pixels 20% finer.
	check(is_equal_approx(float(load("res://tuning/retro_screen.tres").get_shader_parameter("pixel_height")), 324.0), "the screen is 324 pixels tall")
	# One big battle: battle_size enemies, the boss when boss_when_left are left.
	var camp: String = v.sites.keys().filter(func(id): return v.sites[id].auto)[0]
	v.start_site(camp)
	await _frames(int(t.time_between_waves * 60.0) + 30)
	check(v.waves.total() == 1 and v.waves.alive() >= t.battle_size, "a fight is one battle of %d (%d)" % [t.battle_size, v.waves.alive()])
	var ground_ok := v.waves.members.all(func(e): return e.global_position.y < v.terrain.height(e.global_position.x, e.global_position.z) + 1.5)
	check(ground_ok, "nobody starts on a roof or a tree")
	v.waves.reserve = []  # this checks the boss's timing, not the reinforcements
	var foes: Array = v.waves.members.duplicate()
	for i in foes.size() - t.boss_when_left - 1:
		Combat.deal(foes[i], DamageInfo.make(999999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, p))
	await _frames_past_menus(v, 30)
	check(not v.waves._boss_spawned, "no boss while more than %d are left" % t.boss_when_left)
	Combat.deal(foes[foes.size() - t.boss_when_left - 1], DamageInfo.make(999999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, p))
	await _frames_past_menus(v, 30)
	check(v.waves._boss_spawned and v.waves.alive() == t.boss_when_left + 1, "at %d left the mini boss comes in" % t.boss_when_left)
	var boss_node: Enemy = v.waves._boss_node
	check(boss_node != null and is_equal_approx(boss_node.health_mult, v.waves.health_mult) and is_equal_approx(float(foes[-1].health_mult), v.waves.health_mult * v.waves.army_mult),
		"the mini boss keeps its planned health; the army shares the plan's (x%.2f)" % v.waves.army_mult)
	v._return_to_valley()
	# Roads: a strip of dirt you can see.
	var roads: MeshInstance3D = v.world.get_node_or_null("Roads")
	check(roads != null and roads.mesh != null and roads.mesh.get_surface_count() > 0, "the roads are laid as dirt on the land")
	# Buildings: a small one comes down, a big one loses a chunk.
	var small: Breakable = null
	var big: Breakable = null
	for b in get_tree().get_nodes_in_group("breakables"):
		if b.kind == "building" and not b._big and small == null:
			small = b
		elif b.kind == "building" and b._big and big == null:
			big = b
	check(small != null and big != null, "houses and walls are breakable")
	var house: Node3D = small._model
	var at: Vector3 = small.nearest(house.global_position + Vector3(0, 1, 30))
	for i in 12:
		var before: int = small._hits_left
		Breakable.smash_near(get_tree(), at, 1.0, at + Vector3(0, 0, 5))
		Breakable.smash_near(get_tree(), at, 1.0, at + Vector3(0, 0, 5))  # same moment: counts once
		if i == 1:
			check(small._hits_left == before - 1, "two blows at once (a gallop, a dash) count as one")
		await _frames(20)  # past Breakable.HIT_GAP_MS
		if not is_instance_valid(small) or (small._chunks.is_empty() and small._body != null):
			break
		at = small.nearest(at)  # once it's in pieces, the next blow lands on the nearest one
	await _frames(2)
	check(not is_instance_valid(house) and (not is_instance_valid(small) or small._chunks.is_empty()), "a small building comes down after a few blows")
	var spot: Vector3 = big.nearest(big._model.global_position + Vector3(0, 1, 60))
	Breakable.smash_near(get_tree(), spot, 1.4, spot + Vector3(0, 0, 5))
	await _frames(2)
	var left: int = big._chunks.size()
	check(left > 4 and is_instance_valid(big._body), "a big one loses only a chunk (%d pieces left)" % left)
	var hole := PhysicsRayQueryParameters3D.create(spot + (spot - big._body.global_position).normalized() * 0.0 + Vector3.UP * 0.2, spot + Vector3.UP * 0.21, 0b001)
	Breakable.smash_near(get_tree(), spot, 1.4, spot + Vector3(0, 0, 5))
	await _frames(2)
	check(big._chunks.size() <= left, "and more with each blow")
	# Towers: some climbed the other way, some hollow, with a way in.
	var kinds := {}
	for sp in v.loot.spots.filter(func(x): return x.kind == "tower"):
		kinds[sp.variant] = true
	check(kinds.size() == 3, "plain, mirrored and hollow towers (%s)" % [kinds.keys()])
	var hollow: Dictionary = v.loot.spots.filter(func(x): return x.kind == "tower" and x.variant == "hollow")[0]
	var space := v.get_world_3d().direct_space_state
	var door_out := LootSpots.tower_point(hollow, 0.0, 9.0, 1.2)
	var inside := LootSpots.tower_point(hollow, 0.0, 0.5, 1.2)
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(door_out, inside, 0b001)).is_empty(), "a hollow tower's door is open")
	var steps_ok := true
	for k in LootSpots.INSIDE.size():
		var step: Array = LootSpots.INSIDE[k]
		var top := LootSpots.tower_point(hollow, step[0], step[1], step[2])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top + Vector3.UP * 0.6, top + Vector3.DOWN * 0.4, 0b001))
		steps_ok = steps_ok and hit and absf(hit.position.y - top.y) < 0.2
		if k > 0:
			var rise: float = float(step[2]) - float(LootSpots.INSIDE[k - 1][2])
			steps_ok = steps_ok and rise < 1.1
	check(steps_ok, "and steps inside, each an easy hop up")
	var last: Array = LootSpots.INSIDE[-1]
	var hatch_from := LootSpots.tower_point(hollow, last[0], last[1], last[2] + 0.2)
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(hatch_from, hatch_from + Vector3.UP * 3.0, 0b001)).is_empty(), "up through a hatch to the roof")
	for k in range(1, LootSpots.ROUTE.size()):
		if k != LootSpots.GAP:
			check(float(LootSpots.ROUTE[k][2]) - float(LootSpots.ROUTE[k - 1][2]) <= 1.0, "outside steps are about 1 m up (%d)" % k)
	get_tree().paused = false



## A scripted player really climbs a hollow tower: hop from each inside step to the next, then out the hatch.
func test_hollow_tower_climb() -> void:
	var v: Valley = await _valley(80)
	var p := v.player
	var hollow: Dictionary = v.loot.spots.filter(func(x): return x.kind == "tower" and x.variant == "hollow")[0]
	var s := ScriptedInput.new()
	p.input_source = s
	var steps: Array = LootSpots.INSIDE
	var first: Array = steps[0]
	p.global_position = LootSpots.tower_point(hollow, first[0], first[1], first[2] + 0.3)
	p.velocity = Vector3.ZERO
	await _frames(30)
	var reached := 0
	for hop in 40:  # hop to whichever step is next above you, like a player would
		var k := -1
		for n in steps.size():
			if LootSpots.tower_point(hollow, steps[n][0], steps[n][1], steps[n][2]).y > p.global_position.y + 0.3:
				k = n
				break
		if k < 0:
			break
		var st: Array = steps[k]
		var top := LootSpots.tower_point(hollow, st[0], st[1], st[2])
		s.press("jump")
		for f in 80:  # steer at the step, and stop once over it
			var d := top - p.global_position
			s.aim_yaw = atan2(-d.x, -d.z)
			if Vector2(d.x, d.z).length() > 0.25:
				s.hold({"move": Vector2(0, 0.6)}, 1)
			await _frames(1)
			get_tree().paused = false  # no menu stops the climb
		await _frames(15)
		for n in steps.size():
			if p.is_on_floor() and p.global_position.y > LootSpots.tower_point(hollow, steps[n][0], steps[n][1], steps[n][2]).y - 0.35:
				reached = maxi(reached, n)
	check(reached == steps.size() - 1, "a player hops up every step inside a hollow tower (reached %d of %d)" % [reached, steps.size() - 1])
	s.press("jump")
	var highest := p.global_position.y
	for f in 70:
		await _frames(1)
		highest = maxf(highest, p.global_position.y)
	check(highest > hollow.base.y + LootSpots.ROOF_Y, "and jumps out through the hatch above the roof (%.1f m up)" % (highest - hollow.base.y))


func test_breakable_props() -> void:
	var p: Player = _arena.player
	var barrel: Node3D = (load(ValleyWorld.VILLAGE + "barrel.glb") as PackedScene).instantiate()
	_arena.add_child(barrel)
	barrel.scale = Vector3.ONE * ValleyWorld.VILLAGE_SCALE
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


## Occlusion culling (a contained try): walls, towers and the castle hide what stands behind them.
func test_wall_occluders() -> void:
	check(ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling"), "occlusion culling is on")
	for model in ["human_wall", "human_tower", "landmark_castle"]:
		var n: Node3D = (load(ValleyWorld.VILLAGE + model + ".glb") as PackedScene).instantiate()
		_arena.add_child(n)
		ValleyWorld.occlude(n)
		var occ: Array = n.find_children("*", "OccluderInstance3D", true, false)
		var tris := 0
		for o: OccluderInstance3D in occ:
			tris += (o.occluder as ArrayOccluder3D).indices.size() / 3
		check(not occ.is_empty() and tris >= 12, "%s gets an occluder from its own mesh (%d triangles)" % [model, tris])
		n.queue_free()
	# The Old Towers wear the stone picture (2026-11-17), tiled in world space.
	var tower: Node3D = (load(ValleyWorld.VILLAGE + "tower_meadow.glb") as PackedScene).instantiate()
	ValleyWorld.stone(tower)
	var mat := (tower.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
	check(mat != null and mat.albedo_texture == ValleyWorld.STONE_TEXTURE and mat.uv1_triplanar, "an Old Tower wears the stone picture")
	tower.free()


## Fire Lance (user, 2026-11-06): lunge, stab, and a cone of fire ahead hits hard and ignites; nothing behind or beside you.
func test_fire_lance() -> void:
	var p: Player = _arena.player
	check(GameData.text(p.abilities.defs.Movement, "ability_id") == "forge_fire_lance", "the forge god's Movement is Fire Lance")
	var start := p.global_position
	var ahead: Array = []
	for x in [-1.0, 0.0, 1.0]:
		var e: Enemy = _arena.waves.spawn("barb_warlord")
		e.global_position = start + Vector3(x, 0, -7.0)
		ahead.append(e)
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
	var tip: Node3D = p.visual.weapon_tip()
	check(tip != null and tip.global_position.distance_to(p.global_position + Vector3.UP) < 3.0, "the flame rides your weapon's point (user, 2026-11-08)")
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

func _fresh_run(seed_value := 777, length := 1.0) -> RunState:
	return Run.start_new("dwarf", "forge_god", seed_value, length)


func test_valley_generation() -> void:
	var a := _fresh_run(42).to_dict()
	var b := _fresh_run(42).to_dict()
	check(JSON.stringify(a) == JSON.stringify(b), "same seed gives the same valley")
	var s := _fresh_run(42)
	check(s.tribes.size() == ValleyGenerator.FULL_TRIBES, "full run places %d tribes (got %d)" % [ValleyGenerator.FULL_TRIBES, s.tribes.size()])
	check(not s.tribes.has("dwarf"), "the player's race isn't a rival tribe")
	check(s.tribes[s.evil.race].status == "corrupted", "one tribe is corrupted by Count Fuckula")
	check(s.evil.captive_god != "" and not s.evil.captive_god in s.wild_gods, "its patron god is the captive")
	check(s.encounters.has("final_battle"), "the final battle is placed")
	# Count Fuckula's tribe is his horde of monsters and skeletons (user, 2026-10-30).
	check(s.evil.race == EvilTribe.HORDE and not GameData.rows("races").any(func(r): return s.tribes.has(r.race_id) and s.tribes[r.race_id].god == s.evil.captive_god),
		"Count Fuckula's tribe is the horde; his captive god is no tribe's")
	var final_plan := EncounterSystem.plan(s, "final_battle")
	var horde_units: Array = EncounterSystem.army_rows(EvilTribe.HORDE).map(func(u): return u.unit_id)
	var outsiders: Array = []
	for wave in final_plan.waves:
		for token in wave:
			if not str(token).get_slice("@", 0) in horde_units:
				outsiders.append(token)
	check(final_plan.boss == EvilTribe.HORDE_BOSS and outsiders.is_empty() and horde_units.size() >= 6,
		"the final battle is the horde's (%d kinds), ending with the Evil Dragon (%s)" % [horde_units.size(), outsiders])
	var regions_used := {}
	for race in s.tribes:
		regions_used[s.tribes[race].region] = true
	check(regions_used.size() == s.tribes.size(), "every tribe has its own region")
	var short := _fresh_run(42, 0.34)
	var tribeless: Array = short.regions.keys().filter(func(r): return short.regions[r].tribe == "")
	check(short.tribes.size() == s.tribes.size() and tribeless.is_empty(), "every region has a tribe, short runs too (user, 2026-10-29)")


func test_evil_tribe_clock() -> void:
	var s := _fresh_run(9)
	var interval := EvilTribe.interval(s)
	check(is_equal_approx(interval, 12.0 * 60.0 * GameData.tuning.evil_push_scale), "full run pushes every 12 x %.2f minutes" % GameData.tuning.evil_push_scale)
	var r := EvilTribe.tick(s, interval + 1.0)
	check(r.event in ["attack", "fell"], "the evil tribe pushes when the clock runs out (got %s)" % r.event)
	if r.event == "attack":
		EvilTribe.resolve_defense(s, true)
		check(not s.regions[r.region].corrupted, "winning Border Defense saves the region")
		r = EvilTribe.tick(s, interval + 1.0)
		if r.event == "attack":
			check(float(s.evil.pending.time_left) >= 299.0, "you get 5 minutes to reach the village under attack")
			EvilTribe.tick(s, GameData.tuning.border_defense_seconds + 1.0)
			check(s.regions[r.region].corrupted, "an unanswered attack takes the region")
	check(not s.regions[s.flags.home_region].corrupted, "the home region is never attacked")


func test_diplomacy() -> void:
	var s := _fresh_run(5)
	var race: String = s.tribes.keys().filter(func(r): return s.tribes[r].status == "neutral")[0]
	Diplomacy.change_reputation(s, race, 35)
	check(s.tribes[race].status == "friendly", "35 reputation = friendly")
	Diplomacy.change_reputation(s, race, 40)
	check(s.tribes[race].status == "allied" and race in Diplomacy.allies(s), "75 reputation = allied, joins the final battle")
	check(not s.encounters.keys().any(func(id): return id.begins_with("ct_")), "no tribe can be conquered (user, 2026-11-16)")


func test_encounters() -> void:
	var s := _fresh_run(11)
	var mission: String = s.encounters.keys().filter(func(id): return id.begins_with("tm_"))[0]
	var plan := EncounterSystem.plan(s, mission)
	check(plan.has("waves") and plan.waves.size() >= 1 and plan.waves[0].size() >= 1, "a mission makes a spawn plan")
	check(JSON.stringify(plan) == JSON.stringify(EncounterSystem.plan(s, mission)), "plans are deterministic")
	var race: String = s.encounters[mission].race
	var god := EncounterSystem.finish(s, mission, true)
	check(god == s.tribes[race].god and god in s.gods_met, "finishing a tribe mission reveals its god")
	check(s.tribes[race].reputation >= 40, "and raises reputation")


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


func test_save_round_trip() -> void:
	var s := _fresh_run(8)
	s.supplies = 77
	s.godly_gifts = [{"id": "forge_tempered", "rank": 2}]
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(back.supplies == 77 and back.seed == 8 and back.tribes.size() == s.tribes.size(), "run state survives JSON")
	# Compare after one JSON pass each (JSON stores every number as a float).
	var once := func(d): return JSON.stringify(JSON.parse_string(JSON.stringify(d)))
	check(once.call(back.to_dict()) == once.call(s.to_dict()), "round trip keeps every value")


func test_meta_unlocks() -> void:
	var saved: Dictionary = Meta.data.duplicate(true)
	var s := _fresh_run(6)
	s.gods_met.append("chaos_god")
	var unlocked := Meta.record_run(s, true)
	var ids: Array = unlocked.map(func(u): return u.id)
	check(Meta.is_unlocked("gods", "chaos_god"), "meeting a god unlocks it")
	check(Meta.is_unlocked("gods", s.evil.captive_god) or s.evil.captive_god == "", "winning frees the captive god")
	check(GameData.rows("races").all(func(r): return Meta.is_unlocked("races", r.race_id)), "every race is available from the start")
	Meta.data = saved


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
	for weapon in ["warhammer", "greatsword", "naginata", "bow", "staff"]:
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


func test_save_resume_keeps_build() -> void:
	var s := _fresh_run(21)
	var p: Player = _arena.player
	p.apply_run_state(s)
	p.godly_gifts.add_godly_gift("forge_searing_strikes")
	p.godly_gifts.add_godly_gift("forge_tempered")
	p.godly_gifts.add_godly_gift("forge_tempered")
	p.health.hp = 123.0
	Run.player = p
	Run.checkpoint("test")
	var next_roll := RunRng.randf_range(0.0, 1.0)
	check(Run.resume(), "the saved run loads")
	check(SaveSystem.has_run(), "and stays on disk, so a crash right after loading loses nothing")
	check(Run.state.godly_gifts.size() == 2 and Run.state.godly_gifts[1].rank == 2, "godly_gifts and ranks survive the save")
	check(is_equal_approx(Run.state.hp, 123.0), "health survives the save")
	check(is_equal_approx(RunRng.randf_range(0.0, 1.0), next_roll), "the dice continue where they were, not from the start")
	p.apply_run_state(Run.state)
	check(p.godly_gifts.rank_of("forge_tempered") == 2 and is_equal_approx(p.health.hp, 123.0), "the player rebuilds from the save")
	Run.state.weapon_id = "a_weapon_taken_off_the_sheet"
	Run.checkpoint("test")
	check(Run.resume() and not GameData.weapon(Run.state.weapon_id).is_empty(), "an old save whose weapon left the sheet gets one of the race's weapons")
	Run.player = null


func test_clock_pauses_in_fights() -> void:
	var s := _fresh_run(22)
	var before: float = s.evil.next_push_in
	Run.in_fight = true
	Run.tick(30.0)
	check(is_equal_approx(s.evil.next_push_in, before), "the evil clock waits during fights")
	Run.in_fight = false
	Run.tick(30.0)
	check(is_equal_approx(s.evil.next_push_in, before - 30.0), "and runs in the valley")


func test_end_to_end_run() -> void:
	var s := _fresh_run(23, 0.34)
	check(s.tribes.size() == ValleyGenerator.FULL_TRIBES, "a short run has a tribe in every region but yours")
	var offered := []
	var on_offer := func(g): offered.append(g)
	Run.god_offered.connect(on_offer)
	var rival: String = s.tribes.keys().filter(func(r): return s.tribes[r].status != "corrupted")[0]
	Run.finish_encounter("tm_" + rival, true)
	check(offered.size() == 1 and offered[0] == s.tribes[rival].god, "a tribe mission reveals its god")
	# Let the evil tribe push until it attacks the rival.
	var attack := {}
	for i in 10:
		var r := EvilTribe.tick(s, EvilTribe.interval(s) + 1.0)
		if r.event == "attack":
			attack = r
			break
	if not attack.is_empty():
		var border := "border_" + str(attack.region)
		check(s.encounters.has(border) and s.encounters[border].state == "available", "a border attack creates a Border Defense encounter")
		Run.finish_encounter(border, true)
		check(not s.regions[attack.region].corrupted, "holding the line saves the region")
	Run.finish_encounter("final_battle", true)
	check(not Run.active and Run.last_result.get("victory", false), "winning the final battle ends the run as a victory")
	Run.god_offered.disconnect(on_offer)


func test_arena_plays_an_encounter() -> void:
	_arena.queue_free()
	await _frames(1)
	var s := _fresh_run(24, 0.34)
	var rival: String = s.tribes.keys().filter(func(r): return s.tribes[r].status != "corrupted")[0]
	var id := "tm_" + rival
	Flow.pending_encounter = id
	_arena = ARENA.instantiate()
	add_child(_arena)
	await _frames(2)
	await _until_on_floor()
	check(_arena.encounter_id == id, "the arena runs the run's encounter")
	_arena.player.god_mode = true
	for i in 3000:  # fights are crowds of weak minions now (2026-11-18): reinforcements take a while to all arrive
		for e in get_tree().get_nodes_in_group("enemies"):
			Combat.deal(e, DamageInfo.make(9999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, _arena.player))
		await get_tree().physics_frame
		if _arena.hud.is_choosing():
			if _arena.hud._offer_kind == "god":
				break
			_arena.hud._pick(0)  # take level-ups as they come
	check(s.encounters[id].state == "done", "clearing every wave finishes the encounter")
	check(_arena.hud.is_choosing() and _arena.hud._offer_kind == "god", "its god appears with godly gifts")
	_arena.hud._pick(0)
	check(s.god_id != "forge_god" or s.godly_gifts.size() > 0, "the choice is applied to the run")
	Flow.pending_encounter = ""


func test_weapon_choice() -> void:
	var s := Run.start_new("dwarf", "forge_god", 31, 0.34, "naginata")
	var p: Player = _arena.player
	p.apply_run_state(s)
	check(p.weapon_id == "naginata" and p.moveset is WeaponMoveset.Polearm, "the weapon picked at the start sets the moveset")
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(back.weapon_id == "naginata", "the weapon survives a save")
	var old := s.to_dict()
	old.erase("weapon_id")
	old["version"] = 2
	check(RunState.from_dict(old).weapon_id == "warhammer", "old saves get a default weapon")
	var older := s.to_dict()
	older["boons"] = [{"id": "forge_tempered", "rank": 2}]
	older.erase("godly_gifts")
	older["version"] = 4
	check(RunState.from_dict(older).godly_gifts.size() == 1, "saves from before the rename keep their godly gifts")
	p.setup("dwarf", "forge_god", "warhammer")


func test_valley_terrain() -> void:
	var s := _fresh_run(51, 0.34)
	var a := ValleyTerrain.new(51)
	var b := ValleyTerrain.new(51)
	check(is_equal_approx(a.height(37.0, -81.0), b.height(37.0, -81.0)), "the same seed gives the same valley")
	var wrong := 0
	for r in GameData.rows("valley_regions"):
		var c := ValleyTerrain.region_center(r.region_id)
		if a.region_at(c.x, c.y) != r.region_id:
			wrong += 1
	check(wrong == 0, "every region center lies in its own region")
	var lake: Dictionary = a.lakes[0]
	var radii: Array = range(16).map(func(k): return ValleyTerrain.shore_radius(lake, TAU * k / 16.0))
	check(radii.max() - radii.min() > lake.radius * 0.08, "lake shores are irregular, not circles (%.0f-%.0f m)" % [radii.min(), radii.max()])
	check(not is_equal_approx(ValleyTerrain.new(52).rivers[0].c[100], a.rivers[0].c[100]), "rivers take a different course each run")
	var home := ValleyTerrain.region_center(s.flags.home_region)
	var evil := ValleyTerrain.region_center(s.evil.territories[0])
	check(s.flags.home_region == GameData.text(GameData.race("dwarf"), "home_region"), "a dwarf's camp is in the dwarves' home region (%s)" % s.flags.home_region)
	check(home.distance_to(evil) > 3000.0, "Count Fuckula starts at the other end of the valley (%.0f m)" % home.distance_to(evil))
	check(home.y > 1000.0 and evil.y < -1000.0, "you start in the south, Count Fuckula holds the north (north is -z)")
	check(ValleyTerrain.shape_q(0.0, 2270.0) < 1.0 and ValleyTerrain.shape_q(1130.0, 0.0) < 1.0 and ValleyTerrain.shape_q(0.0, 2400.0) > 1.0, "the valley is about 2.3 km wide and 4.6 km long (30% more area than 2 x 4 km)")
	ValleyTerrain.assign_slots(s)
	var spots := {}
	var bumpy := 0
	for id in s.encounters:
		var key := "%s:%d" % [s.encounters[id].region, s.encounters[id].slot]
		spots[key] = true
		var p := ValleyTerrain.site_point(s, id)
		if absf(a.height(p.x, p.y) - a.height(p.x + 8.0, p.y)) > 0.05:
			bumpy += 1
		if ValleyTerrain.shape_q(p.x, p.y) > ValleyTerrain.SAFE_Q + 0.01:
			bumpy += 1
	check(spots.size() == s.encounters.size(), "every encounter has its own spot")
	check(bumpy == 0, "encounter spots are flat and inside the valley")
	# River banks: from the water's edge, the ground rises gently.
	var steepest := 0.0
	for i in a.rivers.size():
		var river: Dictionary = a.rivers[i]
		if river.branch:
			continue
		for along in ([-600.0, -240.0, 120.0, 480.0] if river.axis == "x" else [-1200.0, -400.0, 400.0, 1200.0]):
			var c := a.river_center(i, along)
			# Walk out across the river (z for rivers that cross the valley, x for the main river).
			var at := func(d: float) -> float: return a.height(along, c + d) if river.axis == "x" else a.height(c + d, along)
			for side in [-1.0, 1.0]:
				var d := 2.0
				while d < 300.0 and at.call(side * d) < ValleyTerrain.WATER_Y:
					d += 1.0
				steepest = maxf(steepest, (at.call(side * (d + 12.0)) - at.call(side * d)) / 12.0)
	check(steepest < 0.6, "river banks are gentle enough to walk out of the water (steepest %.0f degrees)" % rad_to_deg(atan(steepest)))


func test_battle_sizing() -> void:
	var s := _fresh_run(55, 0.34)
	var t: CombatTuning = GameData.tuning
	var rival: String = s.tribes.keys().filter(func(r): return s.tribes[r].status != "corrupted" and s.encounters["tm_" + r].def == "tm_raid_defense" and not s.encounters["tm_" + r].get("siege", false))[0]
	var plan := EncounterSystem.plan(s, "tm_" + rival, 4)
	check(is_equal_approx(plan.budget, (t.battle_player_dps + t.battle_ally_dps * pow(4, t.battle_ally_scaling)) * 90.0), "befriending a tribe is a 1.5-minute raid: (your damage + 4 warriors') x 90 s of enemy health")
	check(plan.waves.size() == t.wave_count, "battles come in %d waves (got %d)" % [t.wave_count, plan.waves.size()])
	var sizes: Array = plan.waves.map(func(w): return w.size())
	check(sizes[0] >= t.first_wave_min and sizes[0] <= t.first_wave_max, "the first wave has %d-%d enemies (got %d)" % [t.first_wave_min, t.first_wave_max, sizes[0]])
	check(sizes[1] == roundi(sizes[0] * t.wave_growth) and sizes[2] == roundi(sizes[0] * t.wave_growth * t.wave_growth), "each wave is 1.5x the one before: %s" % str(sizes))
	check(plan.boss != "" and not GameData.unit(plan.boss.get_slice("@", 0)).is_empty(), "a mini boss ends the fight (%s)" % plan.boss)
	# Reinforcements (2026-11-10): a long fight holds its target length with more enemies, not tougher ones.
	var final_plan := EncounterSystem.plan(s, "final_battle", 10)
	check(final_plan.reserve.size() > plan.reserve.size() and final_plan.reserve.size() > 50, "the final battle brings reinforcements (%d)" % final_plan.reserve.size())
	var field: Array = _arena._one_battle(final_plan.waves, final_plan.reserve)
	check(field[0].size() == t.battle_size and _arena.waves.reserve.size() > 0, "%d on the field at once, the rest join as they fall" % t.battle_size)
	_arena.waves.reserve = []
	_arena.waves.health_mult = 1.0
	var more := EncounterSystem.plan(s, "tm_" + rival, 10)
	check(not more.has("health_mult") and more.waves[0].size() + more.reserve.size() >= plan.waves[0].size() + plan.reserve.size(),
		"more defenders on your side: more enemies, never tougher ones")
	s.level = 6
	check(EncounterSystem.plan(s, "tm_" + rival, 4).budget > plan.budget, "a stronger you means more enemies")
	var dueler: String = s.tribes.keys().filter(func(r): return s.encounters.get("tm_" + r, {}).get("def", "") == "ct_champion_duel")[0]
	var champ := EncounterSystem.plan(s, "tm_" + dueler, 4)
	check(champ.leader == "champ_" + dueler and champ.boss == champ.leader and not GameData.unit(champ.leader).is_empty(), "a champion's challenge ends with the champion")
	check(champ.waves.all(func(w): return w.all(func(id): return GameData.text(GameData.unit(id), "race_id") == dueler)), "a tribe's warriors are all of that race")
	# Fights not tied to a tribe are barbarians, just barbarians (user, 2026-11-08).
	for i in 6:
		s.encounters["probe_%d" % i] = {"def": "tm_clear_camp", "region": s.flags.home_region, "state": "available", "race": "", "god": ""}
		var p := EncounterSystem.plan(s, "probe_%d" % i, 0)
		var units: Array = []
		for w in p.waves:
			units.append_array(w)
		check(p.party == "bandits" and units.all(func(id): return id in EncounterSystem.BARBARIANS or id == EncounterSystem.BANDIT_BOSS),
			"a raiding party is barbarians only (%s)" % str(units.slice(0, 4)))
		s.encounters.erase("probe_%d" % i)


func _valley(seed_value: int, raided := false) -> Valley:
	_arena.queue_free()
	await _frames(1)
	Run.in_fight = false
	_fresh_run(seed_value, 0.34)
	if not raided:
		Run.state.encounters["first_fight"]["state"] = "expired"  # most tests start after the opening raid
	_arena = VALLEY.instantiate()
	add_child(_arena)
	_arena.wilds.discovering = false
	await _frames(2)
	await _until_on_floor()
	return _arena


## Kills every hostile unit in the fight each frame until a god offer appears (or `frames` pass).
func _win_fight(v: Valley, frames := 6000) -> void:
	for i in frames:
		for e in v.waves.members.duplicate():
			if is_instance_valid(e) and not e.is_dead():
				Combat.deal(e, DamageInfo.make(99999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, v.player))
		await get_tree().physics_frame
		if v.hud.is_choosing() and v.hud._offer_kind == "god":
			return
		if v.hud.is_choosing():
			v.hud._pick(0)


var _ally_damage := 0.0


func _count_ally_damage(target: Node, info: DamageInfo, dealt: float) -> void:
	if target.get("team") == Enemy.Team.HOSTILE and info.source != null and is_instance_valid(info.source) and info.source.get("team") == Enemy.Team.FRIENDLY:
		_ally_damage += dealt


func test_valley_befriend_battle() -> void:
	var v: Valley = await _valley(52)
	var s: RunState = Run.state
	var home := ValleyTerrain.region_center(s.flags.home_region)
	check(Vector2(v.player.global_position.x, v.player.global_position.z).distance_to(home) < 20.0 and v.player.is_on_floor(), "you start on the ground at your tribe's camp")
	check(v.villages.size() == s.tribes.size() + 1, "every tribe (and you) has a village")
	var evil: Village = v.villages[s.evil.race]
	check(not evil.guards.is_empty() and evil.guards.all(func(g): return g.team == Enemy.Team.HOSTILE and g.aggro_radius > 0.0), "Count Fuckula's village is guarded by sentries")
	var rival: String = s.tribes.keys().filter(func(r): return s.tribes[r].status != "corrupted" and s.encounters["tm_" + r].def == "tm_raid_defense" and not s.encounters["tm_" + r].get("siege", false))[0]
	var village: Village = v.villages[rival]
	check(not village.villagers.is_empty() and village.guards.all(func(g): return g.team == Enemy.Team.NEUTRAL), "a tribe's village has villagers and warriors on guard")
	var before: float = s.evil.next_push_in
	await _frames(40)
	check(s.evil.next_push_in < before, "Count Fuckula's clock runs while you explore")
	# Playtest 2026-10-29: a leap left the player inside the ground. The safety net pops you back up.
	var spot: Vector3 = v.player.global_position
	v.player.global_position.y = v.terrain.height(spot.x, spot.z) - 4.0
	await _frames(3)
	check(v.player.global_position.y > v.terrain.height(spot.x, spot.z) - 0.6, "you can never stay stuck under the ground")
	# A villager walking into a house side-steps instead of pushing forever.
	var walker: Enemy = village.villagers[0]
	walker._check_stuck(walker.global_position, Vector3(2, 0, 0), 0.6)
	check(walker._detour_time > 0.0 and walker._detour.length() > 0.9, "a blocked villager side-steps around the obstacle")
	v.player.global_position = spot
	await _frames(2)
	v.player.global_position = village.global_position + Vector3(0, 2, Valley.MEET_RANGE - 8.0)
	await _frames(40)
	check(not v.hud.is_choosing() and Run.in_fight and s.encounters["tm_" + rival].state == "active", "walking into a new tribe's village, a raid is already on: no menu")
	check(v.helpers.is_empty() and village.guards.all(func(g): return g.team == Enemy.Team.FRIENDLY), "no warriors of yours come; the village's own guards defend it with you")
	v.player.god_mode = true
	_ally_damage = 0.0
	Combat.hit_landed.connect(_count_ally_damage)
	await _frames(600)
	Combat.hit_landed.disconnect(_count_ally_damage)
	check(_ally_damage > 0.0, "the village guards damage the raiders (%.0f)" % _ally_damage)
	await _win_fight(v)
	check(s.encounters["tm_" + rival].state == "done" and v.hud._offer_kind == "god", "winning the defense reveals their god")
	v.hud._pick(0)
	await _frames(2)
	check(s.tribes[rival].status == "allied", "they become your allies")
	check(not Run.in_fight and v.helpers.is_empty(), "afterwards your warriors head home")
	check(s.xp > 0 or s.level > 1, "kills by anyone on your side give you XP")
	check(s.player_pos.size() == 3, "your position is saved for resuming")
	var old := s.to_dict()
	old.erase("player_pos")
	old["version"] = 3
	check(RunState.from_dict(old).player_pos.is_empty(), "older saves start at the camp")


func test_tribe_welcomes() -> void:
	# Playtest 2026-11-09: a run was nine raids in a row. Tribes win you over four ways now (2026-11-16).
	var s := _fresh_run(61, 0.34)
	var tms: Array = s.encounters.keys().filter(func(id): return id.begins_with("tm_"))
	var defs: Array = tms.map(func(id): return "siege" if s.encounters[id].get("siege", false) else s.encounters[id].def)
	for d in ValleyGenerator.WELCOMES:
		check(defs.count(d) >= defs.size() / 4, "about a quarter of the tribes: %s (%d of %d)" % [d, defs.count(d), defs.size()])
	var raided: Array = tms.filter(func(id): return s.encounters[id].def == "tm_raid_defense")
	check(raided.all(func(id): return s.encounters[id].get("source", "") in ValleyGenerator.ATTACKERS), "every raid and siege has its attackers: bandits, monsters or the Count's army")
	for src in ValleyGenerator.ATTACKERS:  # each kind of attacker makes a fight
		s.encounters[raided[0]]["source"] = src
		var kind: String = EncounterSystem.plan(s, raided[0], 4).party
		check(kind == {"Barbarians": "bandits", "Beasts": "beasts", "Evil tribe": "race:" + EvilTribe.HORDE}[src], "%s attack: %s" % [src, kind])
	var fallen: String = s.tribes.keys().filter(func(r): return s.encounters.get("tm_" + r, {}).get("def", "") == "tm_clear_camp")[0]
	EvilTribe.fall(s, s.tribes[fallen].region)
	check(s.encounters["tm_" + fallen].state == "expired", "the Count takes a tribe's region: the camp they asked you to clear is gone (no gift from a fallen tribe)")
	var v: Valley = await _valley(61)
	s = Run.state
	var by := func(def: String) -> String:
		return s.tribes.keys().filter(func(r): return s.encounters.get("tm_" + r, {}).get("def", "") == def and v.villages.has(r))[0]
	var camp_tribe: String = by.call("tm_clear_camp")
	v.meet(camp_tribe)
	check(not Run.in_fight and s.encounters["tm_" + camp_tribe].asked and not v.can_meet(camp_tribe), "a tribe that asks for help: no fight at the village, and it asks once")
	check(v.sites.has("tm_" + camp_tribe), "the camp they want cleared is out in the valley")
	var duel_tribe: String = by.call("ct_champion_duel")
	v.player.god_mode = true
	v.meet(duel_tribe)
	check(Run.in_fight and v.encounter_id == "tm_" + duel_tribe, "a tribe whose champion challenges you: the fight starts at the village")
	check(v.villages[duel_tribe].guards.all(func(g): return not is_instance_valid(g) or g.team == Enemy.Team.NEUTRAL), "their guards watch, they don't join in")
	await _win_fight(v)
	if v.hud.is_choosing():
		v.hud._pick(0)
	await _frames(2)
	check(s.tribes[duel_tribe].status == "allied", "beat their champion and the tribe joins you")
	# A siege: time to get ready, then the attack comes from outside the far gate.
	var siege_tribe: String = s.tribes.keys().filter(func(r): return s.encounters.get("tm_" + r, {}).get("siege", false) and v.villages.has(r) and s.encounters["tm_" + r].state == "available")[0]
	var town: Village = v.villages[siege_tribe]
	v.player.global_position = town.global_position + Vector3(0, 2, 30)
	v.meet(siege_tribe)
	check(not Run.in_fight and v._siege_race == siege_tribe and v._siege_left > 30.0, "a siege: you get time to get ready")
	await _frames(40)
	check(not Run.in_fight and v._siege_race == siege_tribe, "the tribe isn't met again while it waits")
	v._siege_left = 0.01
	await _frames(int((GameData.tuning.time_between_waves + 1.0) * 60))
	check(Run.in_fight and v.encounter_id == "tm_" + siege_tribe, "then the attack comes")
	var outside: Array = v.waves.members.filter(func(e): return is_instance_valid(e) and e.global_position.distance_to(town.global_position) > ValleyWorld.GATE_RING)
	check(not outside.is_empty() and v.waves.center.distance_to(v.player.global_position) > town.global_position.distance_to(v.player.global_position),
		"from outside the gate on the far side (%d of %d outside the walls)" % [outside.size(), v.waves.members.size()])
	await _win_fight(v)
	if v.hud.is_choosing():
		v.hud._pick(0)
	await _frames(2)
	check(s.tribes[siege_tribe].status == "allied", "hold the village and the tribe joins you")
	Run.finish_encounter("tm_" + camp_tribe, true)
	check(s.tribes[camp_tribe].status == "allied", "clear their camp and that tribe joins you too")


func test_village_raid_and_sites() -> void:
	var v: Valley = await _valley(53)
	var s: RunState = Run.state
	var rival: String = s.tribes.keys().filter(func(r): return s.tribes[r].status != "corrupted")[0]
	var village: Village = v.villages[rival]
	v.start_village_battle(rival)
	await _frames(2)
	var guard: Enemy = village.guards.filter(func(g): return is_instance_valid(g) and not g.is_dead())[0]
	check(Run.in_fight and not guard in Combat.weapon_targets(guard.global_position, 1.0), "in a raid your weapon can't reach the tribe's warriors (no conquering, user 2026-11-16)")
	check(village.villagers.all(func(c): return c.flee_from != Vector3.INF and (c.hide_at != Vector3.INF or c.unit_id.begins_with("animal_"))), "their villagers flee to a house (the livestock just runs)")
	v.player.god_mode = true
	for f in 300:
		if village.villagers.any(func(c): return is_instance_valid(c) and not c.visible):
			break
		await get_tree().physics_frame
	check(village.villagers.any(func(c): return is_instance_valid(c) and not c.visible), "and hide inside instead of standing at the edge of town")
	await _win_fight(v)
	if v.hud.is_choosing():
		v.hud._pick(0)
	await _frames(2)
	check(s.tribes[rival].status == "allied", "win the raid and the tribe joins you")
	check(village.villagers.all(func(c): return not is_instance_valid(c) or c.visible), "after the fight the villagers come back out")
	var beam: String = v.sites.keys().filter(func(id): return not v.sites[id].auto)[0]  # camps start when you walk in
	v.player.global_position = (v.sites[beam] as Node3D).global_position + Vector3(0, 2, 3)
	await _frames(30)
	check(v.nearest_site(Valley.INTERACT_RANGE) == beam, "other encounters are places: standing at one offers it")
	v.start_site(beam)
	check(Run.in_fight and s.encounters[beam].state == "active", "pressing F starts the fight right there")


## The final battle is a pitched battle (user, 2026-10-30): two lines, your allies
## on your side, Count Fuckula's horde and his converted tribes on his.
func test_mount_keeps_your_pace() -> void:
	var v: Valley = await _valley(54)
	var p := v.player
	check(v.valley_hud._goal.visible and "Goal" in v.valley_hud._goal.text and "attacks a region" in v.valley_hud._clock.text, "the valley always shows your goal and a plain clock")
	check(not v.hud._stats.visible, "test numbers are hidden unless you ask for them")
	var s := ScriptedInput.new()
	p.input_source = s
	p.god_mode = true
	await _frames(30)
	var buddy: Enemy = p.mount.companion
	check(buddy != null, "your mount is beside you on foot")
	if buddy == null:
		return
	for e in get_tree().get_nodes_in_group("enemies"):  # nothing around to fight: just the walk
		e.queue_free()
	# Along a road between villages: roads are kept clear of trees and buildings.
	var road: PackedVector2Array = v.terrain.roads[0].line
	var a2: Vector2 = road[0].lerp(road[1], 0.35)
	var road_dir := Vector3(road[1].x - road[0].x, 0.0, road[1].y - road[0].y).normalized()
	p.global_position = Vector3(a2.x, v.terrain.height(a2.x, a2.y) + 1.0, a2.y)
	buddy.global_position = p.global_position + p.mount.beside_you()
	await _frames(5)
	var best_yaw := atan2(-road_dir.x, -road_dir.z)
	s.aim_yaw = best_yaw
	s.hold({"move": Vector2(0, 1)}, 150)
	await _frames(150)
	var walking: String = buddy.model.current()
	var walk_speed := Vector2(buddy.velocity.x, buddy.velocity.z).length()
	s.hold({"move": Vector2(0, 1), "sprint": true}, 150)
	await _frames(150)
	var running: String = buddy.model.current()
	var run_speed := Vector2(buddy.velocity.x, buddy.velocity.z).length()
	check(walking == "Walking_A" and walk_speed > 1.0 and walk_speed < 4.0, "it walks when you walk (%s, %.1f m/s)" % [walking, walk_speed])
	check(running == "Running_A" and run_speed > 6.0, "it gallops when you sprint (%s, %.1f m/s)" % [running, run_speed])
	check(buddy.global_position.distance_to(p.global_position) < 12.0, "it keeps up (%.1f m)" % buddy.global_position.distance_to(p.global_position))
	var from_you: Vector3 = buddy.global_position - p.global_position
	from_you.y = 0.0
	check(from_you.normalized().dot(-p.facing) < 0.9, "it stays out of the line between you and the camera")
	await _frames(180)
	check(buddy.model.current() == "Idle_A", "it stands when you stop (%s)" % buddy.model.current())


func test_race_preview() -> void:
	var box := Control.new()
	box.size = Vector2(400, 300)
	add_child(box)
	var preview := RacePreview.new()
	box.add_child(preview)
	var mounts := 0
	for r in GameData.rows("races"):
		preview.show_choice(r.race_id, GameData.weapon_options(r.race_id)[0], GameData.text(r, "starting_gods").split(",")[0].strip_edges())
		check(preview.person != null and preview.person.model != null and preview.weapon != null, "the home screen shows the %s and a weapon" % r.race_id)
		mounts += 1 if preview.mount != null else 0
	check(mounts >= GameData.rows("mounts").size() - 1, "and their mounts (%d)" % mounts)
	var count := func(m: Node) -> Dictionary:
		var seen := {}
		for mesh in m.find_children("*", "MeshInstance3D", true, false):
			for c in (mesh.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
				seen[c.to_html()] = true
		return seen
	preview.show_choice("dwarf", "warhammer", "forge_god")
	var fire: Dictionary = count.call(preview.person)
	preview.show_choice("dwarf", "warhammer", "snow_god")
	var ice: Dictionary = count.call(preview.person)
	check(fire.keys().any(func(k): return not ice.has(k)), "a different starting god changes the colors of the clothes")
	box.free()


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


func test_spyglass_bestiary_wings() -> void:
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
	check(p.state == Player.State.HEAVY and p.using_sidearm, "right click fires the heavy shot")
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
	# The spyglass: a narrow view, and what's in the middle is named and goes in the bestiary.
	input.hold({"spyglass_held": true}, 40)
	await _frames(30)
	var cam := get_viewport().get_camera_3d()
	var wolf: Enemy = _arena.waves.spawn("beast_dire_wolf", cam.global_position - cam.global_basis.z * 80.0)
	wolf.global_position = cam.global_position - cam.global_basis.z * 80.0 - Vector3.UP * wolf.aim_height()
	await _frames(1)
	check(p.spying and cam.fov < 30.0, "the spyglass narrows the view (%.0f degrees)" % cam.fov)
	var seen: Node3D = _arena.hud.spy_target()
	check(seen == wolf and Hud.describe(wolf).contains(GameData.text(wolf.unit, "display_name")), "it names the creature in the middle, 80 m away (%s)" % (Hud.describe(seen) if seen else "nothing"))
	Meta.data.codex.erase("creature:beast_dire_wolf")
	Meta.data.codex.erase("creature:giant_beast_dire_wolf")
	await _frames(8)
	check(Bestiary.is_discovered("beast_dire_wolf"), "and puts it in the bestiary")
	wolf.queue_free()
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
	check(demon.model is BeastModel and demon.flying and demon.is_ranged() and "horde_minigun_demon" in EncounterSystem._army(EvilTribe.HORDE), "the minigun demon flies with Count Fuckula's horde")
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
	check(GameData.sidearms() == ["bow", "staff"], "and two sidearms: bow or spells")
	check(GameData.rows("weapons").size() == 6, "only the six weapons in use are on the sheet")
	check(GameData.text(GameData.weapon("twin_khopesh"), "weapon_class") == "Twin" and WeaponMoveset.for_class("Twin") is WeaponMoveset.Twin, "twin blades are their own class")
	check(ModelRegistry.weapon_model("naginata").ends_with("weapon_naginata.glb"), "the naginata has its own model")
	check(ModelRegistry.weapon_model("staff", "macaque").ends_with("macaque/weapon_staff.glb") and ModelRegistry.weapon_model("bow", "dwarf").ends_with("dwarf/weapon_bow.glb"),
		"a race's own weapon versions are used for that race")
	check(ModelRegistry.weapon_model("naginata", "macaque") == ModelRegistry.OWN + "weapon_naginata.glb"
		and ModelRegistry.weapon_model("naginata", "minotaur").ends_with("minotaur/weapon_naginata.glb") and ModelRegistry.weapon_model("naginata", "frog").ends_with("frog/weapon_naginata.glb"),
		"polearms by race: your naginata for the macaques, the minotaurs' and frogfolk's own (user, 2026-11-09; the dwarves' is your lance, below)")
	# Every race has its own set of all six weapons (user, 2026-11-09).
	var shared: Array = []
	for r in GameData.rows("races"):
		for w in GameData.rows("weapons"):
			if not ModelRegistry.weapon_model(w.weapon_id, r.race_id).contains("/%s/" % r.race_id):
				shared.append("%s %s" % [r.race_id, w.weapon_id])
	check(shared == ["macaque naginata"], "every race has its own version of every weapon; only the macaques' polearm is your naginata (%s)" % [shared])
	check(ModelRegistry.weapon_model("staff", "nobody") == ModelRegistry.weapon_model("staff"), "and the normal weapon where there is no race version")
	check(ModelRegistry.own("dwarf/gear_knife.glb") != "", "the dwarves throw axes instead of knives")
	# Each race has the same classes, each with its own look (user, 2026-11-17): own/<race>/<class>/.
	check(ModelRegistry.weapon_model("greatsword", "dwarf") == ModelRegistry.OWN + "dwarf/guardian/weapon.glb"
		and ModelRegistry.weapon_model("warhammer", "dwarf") == ModelRegistry.OWN + "dwarf/barbarian/weapon.glb"
		and ModelRegistry.weapon_model("naginata", "dwarf") == ModelRegistry.OWN + "dwarf/lancer/weapon.glb",
		"a race's class weapons come from its class folders (the user's dwarf axe, warhammer and lance)")
	check(ModelRegistry.for_race("dwarf", "Guardian") == ModelRegistry.for_race("dwarf") and ModelRegistry.class_part("dwarf", "Guardian", "body") == "",
		"a class without its own body for a race wears the race's model")
	check(ModelRegistry.weapon_model("bow", "dwarf") == ModelRegistry.own("dwarf/weapon_bow.glb"), "sidearms without your own file keep the race's generated one")
	var old := RunState.from_dict({"version": 6, "weapon_id": "crossbow", "race_id": "dwarf", "god_id": "forge_god"})
	check(old.weapon_id == "warhammer" and old.sidearm_id == "bow", "an old bow run keeps its bow as the sidearm")
	var p: Player = _arena.player
	p.god_mode = true
	p.setup("dwarf", "forge_god", "greatsword", "staff")
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
	check(p.using_sidearm and p.weapon_class() == "Caster" and p.aiming, "C draws the sidearm, with the crosshair")
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
	check(p.using_sidearm and p.weapon_class() == "Caster", "a turn of the wheel draws your sidearm, and it stays out")
	input.press("switch_weapon")
	await _frames(4)
	check(not p.using_sidearm and p.weapon_class() == "Blade", "another turn puts the main weapon back")
	# The staff's heavy: a bolt that drifts to its target and bursts there.
	var target: Enemy = _cluster(1, 10.0)[0]
	target.health.setup(5000.0)
	await _frames(1)
	p._face_yaw(atan2(-(target.global_position.x - p.global_position.x), -(target.global_position.z - p.global_position.z)))
	var burst_at := []
	var bolt := p.fire_burst_bolt(WeaponMoveset.Caster.BOLT_SPEED, WeaponMoveset.Caster.BOLT_PULL, func(at): burst_at.append([at, target.global_position]))
	check(bolt != null, "a staff's heavy fires a bolt")
	await _frames(60)
	check(burst_at.size() == 1 and (burst_at[0][0] as Vector3).distance_to(burst_at[0][1] + Vector3.UP) < 2.0 and target.health.hp == target.health.max_hp,
		"which bursts once, where it meets an enemy (the burst does the damage)")
	target.queue_free()
	# A spell bursts where it lands.
	var foes := _cluster(3, 6.0)
	var hp: float = foes[1].health.hp
	var info := p.make_hit(12.0, "Fire", "Magic", foes[0], DamageInfo.Kind.LIGHT)
	p._spell_blast(foes[0], info)
	check(foes[1].health.hp < hp, "a spell hurts the ones around the one it hit")
	for e in foes:
		e.queue_free()
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
	_fresh_run(4242, 0.34)
	Run.state.race_id = "elf"
	Run.state.god_id = "storm_god"
	ValleyGenerator.generate(Run.state)
	var gods: Array = Run.state.tribes.values().map(func(t): return t.god)
	check(not gods.any(func(g): return g in GameData.SHELVED_GODS), "nobody worships a set-aside god (%s)" % [gods])
	check(GameData.START_HIDDEN_RACES.all(func(r): return not GameData.race(r).is_empty() and GameData.rows("races").has(GameData.race(r))), "hidden races can still be tribes in the valley")
	check(not Run.state.wild_gods.any(func(g): return g in GameData.SHELVED_GODS), "wild gods are kept gods too")


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
	# A dying mount: you fly limp with the camera on you, and it falls limp too.
	var s := _scripted()
	p.setup("human", "forge_god")
	p.god_mode = false
	s.press("mount")
	await _frames(3)
	check(p.mount.riding, "riding the horse")
	var horse: BeastModel = p.mount.beast
	p.velocity = Vector3(0, 0, -10)
	p.mount.absorb(99999.0)
	check(p.visual.is_ragdoll() and not p.mount.riding, "thrown off")
	check(is_instance_valid(horse) and horse.is_ragdoll() and horse.get_parent() == p.get_parent(), "the dying mount goes limp and stays behind in the world")
	var ragdoll_hips: PhysicsBody3D = p.visual.ragdoll_hips()
	await _frames(20)
	check(ragdoll_hips != null and p.camera_focus().distance_to(ragdoll_hips.global_position - Vector3.UP * 0.9) < 0.01 and p.camera_focus().distance_to(p.global_position) > 0.3,
		"the camera follows your flying body (%.1f m from where you were)" % p.camera_focus().distance_to(p.global_position))
	p.god_mode = true
	await _frames(int((Player.THROWN_TIME + 0.2) * 60))
	check(not p.visual.is_ragdoll(), "and you get back up")
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


func test_god_mode_no_mount() -> void:
	var v: Valley = await _valley(54)
	var p := v.player
	await _frames(30)
	check(p.mount.companion != null, "on foot your mount walks with you")
	p.god_mode = true
	p.flying = true
	await _frames(3)
	check(p.mount.companion == null and not p.mount.can_ride(), "in god mode it's gone")
	p.god_mode = false
	p.flying = false
	await _frames(3)
	check(p.mount.companion != null, "and back when you leave god mode")


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
	# Practice leaves your saved run alone.
	var real := RunState.new()
	real.race_id = "elf"
	SaveSystem.save_run(real, "real")
	var before := FileAccess.get_file_as_string(SaveSystem.RUN_PATH)
	var was_practice := Run.practice
	var runs: int = Meta.data.runs
	Run.practice = true
	Run.checkpoint("quit")
	check(FileAccess.get_file_as_string(SaveSystem.RUN_PATH) == before, "closing the game in Practice doesn't overwrite the save")
	Run.end(false)
	check(SaveSystem.has_run() and Meta.data.runs == runs, "ending Practice keeps the save and the profile as they were")
	Run.practice = was_practice
	Run.active = true
	SaveSystem.delete_run()
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
	# You fly off a dying mount even when there are already plenty of limp bodies.
	var cap_was: int = CharacterModel.ragdolls
	CharacterModel.ragdolls = CharacterModel.MAX_RAGDOLLS
	p.throw_off(Vector3(0, 4, 3))
	check(p._thrown_left > 0.0 and p.visual.is_ragdoll(), "the ragdoll cap doesn't stop you being thrown")
	CharacterModel.ragdolls = cap_was
	for i in 400:
		get_tree().paused = false
		await _frames(1)
		if p._thrown_left <= 0.0:
			break


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


func test_big_villages() -> void:
	var v: Valley = await _valley(70)
	for row in GameData.rows("races"):
		for g in ValleyWorld.GROUP_TYPES:
			check(ResourceLoader.exists(ValleyWorld.VILLAGE + "%s_%s.glb" % [row.race_id, g]), "the %s have a %s" % [row.race_id, g])
	var town: Variant = v.villages.values().filter(func(t): return not t.is_home)[0] if v.villages.values().any(func(t): return not t.is_home) else v.villages.values()[0]
	var near_ring := func(r: float, reach: float) -> Array:
		return town.buildings.get_children().filter(func(n): return n is Node3D and absf((n as Node3D).position.length() - r) < reach)
	var outer: Array = near_ring.call(ValleyWorld.OUTER_RING, 2.5)
	var inner: Array = near_ring.call(ValleyWorld.INNER_RING, 2.0)
	check(outer.size() >= inner.size() and inner.size() > 0, "a village's outer ring doubles it (%d + %d)" % [inner.size(), outer.size()])
	# A village is a place, not a ring (user, 2026-11-03): streets, a market, farm land, walls with gates.
	var spots: Dictionary = town.buildings.get_meta("spots")
	check(town.buildings.has_node("Streets"), "it has streets")
	check(near_ring.call(ValleyWorld.MIDDLE_RING, 2.0).size() >= 6, "and a street of houses")
	check(spots.market.size() >= 4 and spots.yard.size() >= 4 and spots.pens.size() >= 2, "a market and farm land")
	check(spots.gates.size() == ValleyWorld.ROADS, "a gate for each road")
	var wall_parts: Array = near_ring.call(ValleyWorld.WALL_RING, 1.0)
	check(wall_parts.size() >= 6, "and walls (%d sections)" % wall_parts.size())
	for row in GameData.rows("races"):
		for part in ["wall", "gate", "tower"]:
			check(ResourceLoader.exists(ValleyWorld.VILLAGE + "%s_%s.glb" % [row.race_id, part]), "the %s build a %s" % [row.race_id, part])
	for m in ValleyWorld.YARD:
		check(ResourceLoader.exists(ValleyWorld.VILLAGE + m + ".glb"), "%s exists" % m)
	var at_gate: Vector3 = town.global_position + spots.gates[0]
	var road_dir: Vector3 = (at_gate - town.global_position).normalized()
	var q := PhysicsRayQueryParameters3D.create(town.global_position + road_dir * 50.0 + Vector3.UP, town.global_position + road_dir * 75.0 + Vector3.UP, 0b001)
	check(v.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "the road through a gate is open")
	check(town.villagers.any(func(u): return u.global_position.distance_to(town.global_position) > ValleyWorld.OUTER_RING + 5.0), "villagers work out in the fields")


## Peaceful mobs, water life, things in the sky, and finding them (user, 2026-11-03).
func test_exploration_life() -> void:
	var v: Valley = await _valley(72)
	var p := v.player
	p.god_mode = true
	await _frames(2)
	for pack in Wilds.WATER_PACKS:
		check(ModelRegistry.for_beast(pack[0][0]).has("model"), "%s has a model" % pack[0][0])
	var water_kinds := {}
	var sky_kinds := {}
	for g in v.wilds.groups:
		for u in g.units:
			if u.water_bound:
				water_kinds[u.unit_id] = true
			if u.flying:
				sky_kinds[u.unit_id] = true
	check(water_kinds.size() >= 8, "plenty of kinds in the water (%d)" % water_kinds.size())
	check(sky_kinds.size() >= 5, "and in the sky (%d)" % sky_kinds.size())
	var at := p.global_position
	# A peaceful giant: no interest in you until you hit it.
	var giant := Enemy.new()
	giant.setup("beast_triceratops", p, v.director, Enemy.Team.HOSTILE)
	giant.aggro_radius = 22.0
	giant.post = at + Vector3(6, 0, 0)
	v.add_child(giant)
	giant.global_position = giant.post + Vector3.UP * 0.5
	await _frames(40)
	check(giant.peaceful and giant.target == null, "a peaceful giant ignores you, standing right there")
	var hit := DamageInfo.make(1.0, "Physical", DamageInfo.Kind.LIGHT, p)
	Combat.deal(giant, hit)
	await _frames(40)
	check(giant.target != null, "until you hit it")
	giant.queue_free()
	var fight_unit: Enemy = v.waves.spawn("beast_triceratops", at + Vector3(30, 0, 0))
	check(not fight_unit.peaceful, "in a fight, it fights")
	fight_unit.queue_free()
	# Something flying stays up, comes down to attack; shot down, it falls.
	var hawk := Enemy.new()
	hawk.setup("beast_hawk", p, v.director, Enemy.Team.HOSTILE)
	hawk.aggro_radius = 0.0
	hawk.post = at + Vector3(80, 0, 0)
	hawk.fly_height = 16.0
	hawk.team = Enemy.Team.NEUTRAL
	v.add_child(hawk)
	hawk.global_position = hawk.post + Vector3.UP * 16.0
	await _frames(90)
	var ground: float = v.terrain.height(hawk.global_position.x, hawk.global_position.z)
	check(hawk.global_position.y > ground + 8.0, "a hawk stays up in the air (%.1f m)" % (hawk.global_position.y - ground))
	hawk.team = Enemy.Team.HOSTILE
	hawk.global_position = at + Vector3(10, 16, 0)
	for i in 200:
		get_tree().paused = false
		await _frames(1)
		if hawk.global_position.y < at.y + 5.0:
			break
	check(hawk.global_position.y < at.y + 5.0, "and dives on you")
	hawk.queue_free()
	# Finding things.
	Run.state.flags.erase("discovered")
	var xp: int = Run.state.xp
	var level: int = Run.state.level
	var some: Enemy = v.wilds.groups[0].units[0]
	v.wilds.groups[0].asleep = false
	v.wilds.groups[0].center = p.global_position
	some.global_position = p.global_position + Vector3(5, 0, 5)
	for k in 6:
		v.wilds._discover(p.global_position)
	check(some.unit_id in Run.state.flags.get("discovered", []), "coming close to a new kind discovers it")
	check(Run.state.xp > xp or Run.state.level > level, "for some XP")
	check(("creature:" + some.unit_id) in Meta.data.codex, "and it goes in the codex")
	get_tree().paused = false


func test_dungeons() -> void:
	var v: Valley = await _valley(75)
	var p := v.player
	p.god_mode = true
	var caves: Array = v.loot.spots.filter(func(s): return s.kind == "cave" and s.has("dungeon"))
	check(caves.size() >= 11, "every cave is a dungeon (%d)" % caves.size())
	var cave: Dictionary = caves[0]
	var units: Array = cave.dungeon.units
	check(units.size() == LootSpots.CAVE_POSTS.size() + 1 and units.filter(func(u): return u.mini_boss).size() == 1, "its tunnel holds %d foes and a boss" % units.size())
	check(units.all(func(u): return v.loot._in_cave(cave, u.post)), "all of them inside the cave")
	# Clear it: XP, supplies, and a godly gift or a weapon.
	p.global_position = cave.base + Vector3(0, 1.5, 0)
	var supplies := Run.state.supplies
	var xp := Run.state.xp + Run.state.level * 1000
	for u in units:
		if is_instance_valid(u):
			Combat.deal(u, DamageInfo.make(99999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, p))
	for i in 40:  # the kills' level-ups come first (and pause the game)
		if v.hud.is_choosing() and v.hud._offer_kind == "level":
			v.hud._pick(0)
		await _frames(1)
	check(cave.get("cleared", false) and cave.id in Run.state.flags.get("dungeons_cleared", []), "the cave is cleared, for the run")
	check(Run.state.supplies >= supplies + GameData.tuning.dungeon_supplies and Run.state.xp + Run.state.level * 1000 > xp, "clearing pays supplies and XP")
	var kinds: Array = [v.hud._offer_kind] + v.hud._waiting_choices.map(func(c): return c[0])
	check(kinds.any(func(k): return k in ["weapon", "event_gift"]), "and a godly gift or a weapon (%s)" % [kinds])
	while v.hud.is_choosing():
		v.hud._pick(v.hud._offer.size() - 1)
		await _frames(1)
	# A castle is a dungeon too: more defenders and a boss.
	var castles: Array = v.events.events.filter(func(e): return e.get("dungeon", false))
	check(castles.size() == ValleyTerrain.LANDMARK_COPIES + 1, "every castle is a dungeon (%d)" % castles.size())
	check(castles[0].foes.size() > 10 and castles[0].foes.filter(func(e): return e.mini_boss).size() == 1, "with %d defenders and a boss" % castles[0].foes.size())


func test_caves_and_towers() -> void:
	var v: Valley = await _valley(75)
	var p := v.player
	p.god_mode = true
	var art := {}
	for l in v.terrain.landmarks:
		if l.has("chest"):
			check(ResourceLoader.exists(ValleyWorld.VILLAGE + l.model + ".glb"), "%s has its model" % l.model)
			var biome := GameData.text(GameData.row("valley_regions", v.terrain.region_at(l.pos.x, l.pos.y)), "biome")
			if not art.has(biome):
				art[biome] = {}
			art[biome][l.model] = true
	var all_art := {}
	for biome in art:
		for model in art[biome]:
			all_art[model] = all_art.get(model, 0) + 1
	check(all_art.size() >= 12 and all_art.values().all(func(n): return n == 1), "each region's caves and towers have their own art (%s)" % [all_art.keys()])
	var caves := v.loot.spots.filter(func(s): return s.kind == "cave")
	var towers := v.loot.spots.filter(func(s): return s.kind == "tower")
	check(caves.size() >= 11 and towers.size() >= 11, "caves and towers fill the valley (%d, %d)" % [caves.size(), towers.size()])
	# Caves go a little underground (user, 2026-11-08): level at the mouth, sunk in the chamber, the chest on the floor.
	var sunk := caves.filter(func(c): return v.terrain.cave_dip(c.pos.x, c.pos.z) > 2.0)
	check(sunk.size() >= caves.size() / 2, "caves sink underground (%d of %d)" % [sunk.size(), caves.size()])
	var c0: Dictionary = sunk[0] if not sunk.is_empty() else caves[0]
	var mouth: Vector3 = c0.base + Vector3(0, 0, 19).rotated(Vector3.UP, c0.angle)
	check(v.terrain.cave_dip(mouth.x, mouth.z) < 0.2 and c0.base.y - c0.pos.y > 2.0, "level at the mouth, the chest down on the sunk floor (%.1f m down)" % (c0.base.y - c0.pos.y))
	for l in v.terrain.landmarks:
		if l.has("chest"):
			check(ValleyTerrain.shape_q(l.pos.x, l.pos.y) <= ValleyTerrain.SAFE_Q and v.terrain.water_surface(l.pos.x, l.pos.y) == -INF, "%s is on dry land in the valley" % l.kind)
	var space := v.get_world_3d().direct_space_state
	await _frames(2)
	# You can walk into a cave and stand at its chest.
	var cave: Dictionary = v.terrain.landmarks.filter(func(l): return l.get("kind") == "cave")[0]
	var base := Vector3(cave.pos.x, cave.y, cave.pos.y)
	var way_in := base + Vector3(0, 0, 22).rotated(Vector3.UP, cave.angle)
	var to_chest := base + Vector3(0, 0, -16).rotated(Vector3.UP, cave.angle)
	way_in.y = v.terrain.height(way_in.x, way_in.z) + 1.5  # down the sloping floor
	to_chest.y = v.terrain.height(to_chest.x, to_chest.z) + 1.5
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(way_in, to_chest, 0b001)).is_empty(), "a cave is open from its mouth to its chest")
	var above := PhysicsRayQueryParameters3D.create(to_chest, to_chest + Vector3.UP * 30.0, 0b001)
	check(not space.intersect_ray(above).is_empty(), "and has a roof")
	# A tower is a climb: platforms you can stand on, each a walking jump from the last, but
	# one gap no jump clears until the lever drops the plank; from the top the map clears.
	var tspot: Dictionary = v.loot.spots.filter(func(s): return s.kind == "tower" and s.variant == "plain")[0]
	var foot: Vector3 = tspot.base
	var standing := true
	for step in LootSpots.ROUTE + LootSpots.LEVER_WAY:
		var at := LootSpots.tower_point(tspot, step[0], step[1], step[2])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at + Vector3.DOWN * 1.0, 0b001))
		standing = standing and not hit.is_empty() and absf(hit.position.y - at.y) < 0.2
	check(standing, "every step of a tower's climb is solid to stand on")
	var t: CombatTuning = GameData.tuning
	var reach := func(a: Array, b: Array) -> bool:
		# a walking jump from a's edge to b's: how far it carries at b's height
		var rise: float = b[2] - a[2]
		var vy: float = t.jump_velocity_base + t.move_speed * t.jump_speed_scale
		var peak: float = vy * vy / (2.0 * t.gravity)
		if rise > peak - 0.3:
			return false
		var air: float = vy / t.gravity + sqrt(2.0 * (peak - maxf(rise, -6.0)) / t.gravity)
		var gap: float = LootSpots.tower_point(tspot, a[0], a[1], 0.0).distance_to(LootSpots.tower_point(tspot, b[0], b[1], 0.0)) - minf(a[3], a[4]) * 0.5 - minf(b[3], b[4]) * 0.5
		return gap < t.move_speed * air
	var r: Array = LootSpots.ROUTE
	var route_ok: bool = r[0][2] < 1.5  # the first crate is a jump from the ground
	for i in range(1, r.size()):
		if i != LootSpots.GAP:
			route_ok = route_ok and reach.call(r[i - 1], r[i])
	var lw: Array = LootSpots.LEVER_WAY
	check(route_ok and reach.call(r[LootSpots.LANDING], lw[0]) and reach.call(lw[0], lw[1]) and reach.call(lw[0], r[LootSpots.LANDING]),
		"each step is a walking jump from the last, out to the lever and back too")
	var too_high: float = r[LootSpots.GAP][2] - r[LootSpots.LANDING][2]
	var best_vy: float = minf(t.jump_velocity_base + t.sprint_speed * t.jump_speed_scale, t.jump_velocity_max)
	check(too_high > best_vy * best_vy / (2.0 * t.gravity), "but no jump clears the gap above the landing (%.1f m up)" % too_high)
	var plank_mid: Vector3 = (LootSpots.tower_point(tspot, r[LootSpots.LANDING][0], r[LootSpots.LANDING][1], r[LootSpots.LANDING][2])
		+ LootSpots.tower_point(tspot, r[LootSpots.GAP][0], r[LootSpots.GAP][1], r[LootSpots.GAP][2])) * 0.5
	var plank_ray := PhysicsRayQueryParameters3D.create(plank_mid + Vector3.UP * 1.5, plank_mid + Vector3.DOWN * 1.5, 0b001)
	check(space.intersect_ray(plank_ray).is_empty(), "there's no plank across it yet")
	p.global_position = tspot.lever + Vector3.UP
	await _frames(1)
	check(v.loot.prompt().contains("lever") and v.loot.interact(), "at the lever, F pulls it")
	await _frames(100)
	check(not space.intersect_ray(plank_ray).is_empty(), "and the plank swings down across the gap")
	var top := PhysicsRayQueryParameters3D.create(foot + Vector3(1.5, 25.0, 1.5), foot + Vector3(1.5, 0.0, 1.5), 0b001)
	var roof := space.intersect_ray(top)
	check(roof and absf(roof.position.y - foot.y - 16.25) < 1.0, "to a flat roof, where the chest is")
	var far := Vector2(foot.x, foot.z) + (Vector2.ZERO - Vector2(foot.x, foot.z)).normalized() * 400.0  # toward the middle
	check(not v.fog.is_seen(far), "the land 400 m from a tower is still dark on the map")
	p.global_position = foot + Vector3(0, LootSpots.ROOF_Y + 0.5, 0)
	await _frames(12)
	check(v.fog.is_seen(far), "until you reach the top: from there you see far")
	# Your mount stays out.
	p.god_mode = false
	p.flying = false
	p.global_position = foot + Vector3(40, 3, 0)
	await _frames(20)
	p.mount.cooldown = 0.0
	p.mount.hp = p.mount.max_hp
	p.no_mount = false
	p.mount.ride()
	check(p.mount.riding, "riding toward a tower")
	p.global_position = foot + Vector3(8, 1, 0)
	await _frames(15)
	check(p.no_mount and not p.mount.riding, "you get down at its foot")
	check(not p.mount.can_ride(), "and can't mount up there")
	check(p.mount.companion == null, "and it doesn't follow you in")
	var inside: Vector3 = base + Vector3(0, 1, -10).rotated(Vector3.UP, cave.angle)
	check(v.loot.in_mount_free_zone(inside) and v.loot.in_mount_free_zone(base + Vector3(0, 1, 20).rotated(Vector3.UP, cave.angle)), "the same goes for a cave, from its mouth in")
	check(not v.loot.in_mount_free_zone(base + Vector3(0, 1, 34).rotated(Vector3.UP, cave.angle)), "but not out in front of it")
	p.global_position = foot + Vector3(40, 3, 0)
	await _frames(15)
	check(not p.no_mount and p.mount.can_ride(), "walk away and it's yours again")
	p.god_mode = true
	# Opening one: once, for loot, and it's remembered.
	var spot: Dictionary = towers.filter(func(s): return s.variant != "hollow")[0]
	p.global_position = spot.pos + Vector3.UP
	await _frames(1)
	check(v.loot.prompt() != "", "standing at a chest, F opens it")
	var supplies := Run.state.supplies
	var level := Run.state.level
	var xp := Run.state.xp
	check(v.loot.interact(), "it opens")
	get_tree().paused = false
	check(Run.state.supplies > supplies and (Run.state.xp > xp or Run.state.level > level), "for supplies and XP")
	check(not v.loot.interact(), "and only once")
	check(spot.id in Run.state.flags.looted, "and a saved run remembers")
	var groups: int = v.wilds.groups.size()
	check(groups >= Wilds.GROUPS + Wilds.WATER_GROUPS, "with guards on top of the usual groups (%d)" % groups)
	get_tree().paused = false


func test_demon_and_wings() -> void:
	# The little demon flies in the ashlands, and its wing beat moves the winged people's wings.
	check(not GameData.unit("beast_little_demon").is_empty() and ResourceLoader.exists(ModelRegistry.own("beast_little_demon.glb")), "the little demon is in the game")
	check(Wilds.PACKS["Volcanic ashlands"].any(func(p): return p[0][0] == "beast_little_demon"), "it flies in the ashlands")
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


func test_wild_sides() -> void:
	var v: Valley = await _valley(75)
	var sides := {}
	for g in v.wilds.groups:
		for u in g.units:
			if is_instance_valid(u) and u.faction != "":
				sides[u.faction] = true
	check(sides.has("barbarians") and sides.size() >= 4, "wild packs belong to sides (%d)" % sides.size())
	# A beast and a barbarian that meet fight each other.
	var p := v.player
	p.god_mode = true
	var at := Vector3.INF
	for k in 16:  # flat ground 40 m away (on a slope they'd slide apart)
		var c := p.global_position + Vector3(40, 0, 0).rotated(Vector3.UP, k * TAU / 16.0)
		var hs: Array = [-4.0, 0.0, 4.0, 8.0].map(func(dx): return v.terrain.height(c.x + dx, c.z))
		if hs.max() - hs.min() < 1.0 and v.terrain.water_surface(c.x, c.z) == -INF:
			at = Vector3(c.x, v.terrain.height(c.x, c.z) + 1.0, c.z)
			break
	var beast: Enemy = v.waves.spawn("beast_dire_wolf", at)
	var barb: Enemy = v.waves.spawn("barb_raider", at + Vector3(3, 0, 0))
	beast.faction = "beast_dire_wolf"
	barb.faction = "barbarians"
	beast.aggro_radius = 22.0
	barb.aggro_radius = 22.0
	await _frames(2)
	check(beast._pick_target() == barb and barb._pick_target() == beast, "a beast and a barbarian go for each other")
	var holds: Array = v.events.events.filter(func(e): return e.kind == "hold")
	check(holds.size() >= 6 and holds.all(func(e): return e.foes.size() >= 6), "big landmarks are held by war bands (%d)" % holds.size())
	check(ModelRegistry.held("unit_gnome_spore_slinger.glb").ends_with("weapon_gnome_rifle.glb"), "gnome shooters carry rifles")
	var sizes := v.world.find_children("*", "Node3D", true, false).size()
	check(ValleyWorld.BUILDING_GROWTH >= 1.3 and ValleyWorld.BUILDING_GROWTH <= 1.5 and sizes > 0, "houses are 30-50% bigger")


func test_mount_stats() -> void:
	var p: Player = _arena.player
	p.setup("angel", "forge_god")
	check(is_equal_approx(p.mount.jump_speed(), GameData.num(GameData.row("mounts", "pegasus"), "jump_mps")) and p.mount.double_jump(), "each mount has its own jump from the sheet; the pegasus jumps twice")
	p.setup("minotaur", "forge_god")
	check(not p.mount.double_jump() and is_equal_approx(p.mount.attack_force(), GameData.num(p.mount.data, "attack_force")), "the minotaur's mount hits as hard as its sheet says")
	await _until_on_floor()
	# A minotaur sprinting flat out on foot tramples like a mount.
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
	p._rush_time = GameData.tuning.mount_throw_after
	p.velocity = p.facing * GameData.tuning.sprint_speed
	p._bull_rush(0.016)
	check(foe.thrown, "and after 2 s at full speed throws them")
	# A hurt mount walking beside you heals too (or each ride starts lower and one hit throws you off).
	p.mount._call_companion()
	await _frames(1)
	p.mount.companion.health.hp = 10.0
	await _frames(30)
	check(p.mount.companion.health.hp > 10.0 and is_equal_approx(p.mount.hp, p.mount.companion.health.hp),
		"a hurt mount heals while it walks beside you (%.1f hp)" % p.mount.companion.health.hp)
	check(Mount.in_the_way(Vector3(0, 1, -5), Vector3.ZERO, Vector3(0, 1, -10), 1.0) and not Mount.in_the_way(Vector3(4, 1, -5), Vector3.ZERO, Vector3(0, 1, -10), 1.0),
		"a mount between the camera and you fades; one beside you doesn't")
	p.mount._put_away_companion()
	p.setup("human", "forge_god")
	p.god_mode = true
	check(GameData.tuning.mount_follow_gap <= 3.0, "your mount walks within 3 m of you")


func test_mount_orders() -> void:
	# Far Cry Primal style (user, 2026-11-16): hold the mount key and it leaves; a tap calls it back.
	var v: Valley = await _valley(75)
	var p := v.player
	p.god_mode = false
	await _frames(30)
	check(p.mount.companion != null, "your mount walks beside you")
	var hold := PlayerIntent.new()
	hold.mount = true
	hold.mount_held = true
	for k in int(Player.MOUNT_HOLD * 60.0) + 2:
		p._mount_key(hold, false)
		hold.mount = false
	check(p.mount.away and p.mount.companion == null and not p.mount.riding, "holding the mount key: it leaves")
	await _frames(30)
	check(p.mount.companion == null, "and stays gone")
	var tap := PlayerIntent.new()
	tap.mount = true
	p._mount_key(tap, false)
	await _frames(30)
	check(not p.mount.away and p.mount.companion != null and not p.mount.riding, "a tap calls it back (it doesn't ride yet)")
	# Through the spyglass: a tap on an enemy marks it; on the ground, it goes there and waits.
	var foe: Enemy = v.waves.spawn(EncounterSystem.BARBARIANS[0], p.global_position + Vector3(30, 0, 0))
	p.mount.order(foe, Vector3.INF)
	check(p.mount.has_mark() and foe.has_node("MountMark") and p.mount.companion._pick_target() == foe, "an enemy you mark: your mount goes for it, however far, under a gold arrow")
	var there := p.mount.companion.global_position + Vector3(0, 0, 12)
	p.mount.order(null, there)
	check(foe.get_node("MountMark").is_queued_for_deletion(), "a new order takes the arrow away")
	check(p.mount.staying and p.mount.companion._pick_target() == null, "sent to a spot: it waits there, out of fights")
	foe.queue_free()
	await _frames(120)
	var c := p.mount.companion.global_position
	check(Vector2(c.x - there.x, c.z - there.z).length() < 8.0, "and walks to it (%.1f m off)" % Vector2(c.x - there.x, c.z - there.z).length())
	p._mount_key(tap, false)
	check(not p.mount.has_orders(), "a tap calls it back")


func test_camp_stealth() -> void:
	# A camp cleared quietly (user, 2026-11-16): sneak in and pick off its sentries, and there's no battle.
	var v: Valley = await _valley(61)
	var p := v.player
	p.god_mode = true
	var id: String = v.sites.keys().filter(func(k): return v.sites[k].auto and not v.sites[k].sentries.is_empty() and not str(k).begins_with("border_"))[0]
	var site: EncounterSite = v.sites[id]
	var sentry: Enemy = site.sentries[0]
	p.global_position = site.global_position + Vector3(0, 2, 15)
	p.is_crouching = false
	check(site.spotted(p, 15.0), "walk in standing and the camp fights")
	p.is_crouching = true
	check(not site.spotted(p, 15.0), "sneaking, you get closer unseen")
	p.is_crouching = false
	for e in site.sentries:
		Combat.deal(e, DamageInfo.make(1.0, "Physical", DamageInfo.Kind.LIGHT, p))
	check(site.sentries.all(func(e): return e.is_dead()), "a blow on a sentry that hasn't seen you takes it out")
	p.global_position = site.global_position + Vector3(0, 2, 60)
	v._update_sites()
	check(not Run.in_fight and Run.state.encounters[id].state == "done", "every sentry down: the camp is cleared without the battle")
	get_tree().paused = false
	if v.hud.is_choosing():
		v.hud._pick(0)


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


func test_war_chest() -> void:
	var v: Valley = await _valley(62)
	var s := Run.state
	s.supplies = 1000
	check(WarChest.buy(s, "catapult") and WarChest.buy(s, "meteors") and WarChest.buy(s, "champion") and WarChest.buy(s, "veterans"), "supplies buy help for the final battle")
	check(s.supplies == 1000 - 60 - 90 - 75 - 40, "for its price (%d left)" % s.supplies)
	s.supplies = 10
	check(not WarChest.buy(s, "catapult") and WarChest.owned(s, "catapult") == 1, "not without the supplies")
	s.supplies = 1000
	for k in 5:
		WarChest.buy(s, "veterans")
	check(WarChest.owned(s, "veterans") == WarChest.ITEMS.veterans.max, "and only up to its limit")
	WarChest.buy(s, "meteors")
	v.player.god_mode = true
	var t: CombatTuning = GameData.tuning
	v.debug_final_battle()
	var extra := WarChest.owned(s, "veterans") * WarChest.VETERANS_EACH + WarChest.owned(s, "champion")
	check(v.helpers.size() == maxi(t.final_battle_min_side, t.battle_home_warriors + extra + Diplomacy.allies(s).size() * t.battle_ally_warriors), "veterans and the champion stand in your line (%d)" % v.helpers.size())
	check(v.helpers.any(func(h): return h.giant), "the champion is a giant")
	check(v.war.engines.size() == 1, "the catapult stands behind it")
	await _frames(int((t.time_between_waves + 1.0) * 60))
	var foes: Array = v.waves.members.filter(func(e): return is_instance_valid(e) and e.team == Enemy.Team.HOSTILE)
	var hp_before: float = foes.map(func(e): return e.health.hp).reduce(func(a, b): return a + b, 0.0)
	await _frames(60 * 9)
	var hp_after: float = foes.filter(func(e): return is_instance_valid(e)).map(func(e): return e.health.hp).reduce(func(a, b): return a + b, 0.0)
	check(hp_after < hp_before, "meteors and stones hurt his army (%.0f -> %.0f)" % [hp_before, hp_after])
	get_tree().paused = false


func test_compass_and_crowds() -> void:
	check(is_equal_approx(Compass.bearing(Vector3(0, 0, -1)), 0.0) and is_equal_approx(Compass.bearing(Vector3(1, 0, 0)), 90.0) and is_equal_approx(Compass.bearing(Vector3(0, 0, 1)), 180.0), "the compass reads north up the valley, east to the right")
	var p: Player = _arena.player
	var e: Enemy = _arena.waves.spawn("barb_raider", p.global_position + Vector3(0, 0, -60))
	await _frames(2)
	var start := e.global_position
	Enemy.crowd_stride = 3
	e.velocity = Vector3.ZERO
	e._skip_left = 0
	var ticks := 0
	var moved := 0
	for i in 9:
		var before := e.global_position
		e._physics_process(1.0 / 60.0)
		Enemy.crowd_stride = 3
		ticks += 1
		if e.global_position.distance_to(before) > 0.0001:
			moved += 1
	check(moved <= 4, "in a big battle a far unit thinks only every few ticks (%d of %d)" % [moved, ticks])
	Enemy.crowd_stride = 1
	check(start.distance_to(e.global_position) > 0.5, "but still gets where it's going")


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


func test_custom_battle() -> void:
	_arena.queue_free()
	await _frames(1)
	Run.in_fight = false
	_fresh_run(81, 0.34)
	Run.practice = true
	var small := {"Melee": 4, "Ranged": 2, "Magic": 1, "Large": 1, "Cavalry": 1}
	Run.state.flags["battle"] = {"scenario": "plain", "region": "grassland_steppe",
		"ours": {"race": "dwarf", "counts": small}, "theirs": {"race": EvilTribe.HORDE, "counts": small}}
	_arena = VALLEY.instantiate()
	add_child(_arena)
	var v: Valley = _arena
	await _frames(3)
	check(v.wilds.groups.is_empty(), "a custom battle's field has no wild packs")
	check(Run.in_fight and v.helpers.size() == 9, "your chosen army stands with you (%d)" % v.helpers.size())
	check(Valley.army_of({"race": "dwarf", "counts": small}).count("dwarf_ram_rider") == 1, "with the troops you picked")
	await _frames(int((GameData.tuning.time_between_waves + 1.0) * 60))
	var foes: Array = v.waves.members.filter(func(e): return is_instance_valid(e) and e.team == Enemy.Team.HOSTILE)
	check(foes.size() == 9 and foes.all(func(e): return e.unit_id.begins_with("horde_")), "and theirs across the field (%d)" % foes.size())
	var side := func(units: Array) -> float:
		return units.map(func(u): return (u.global_position - v._battle_center).dot(v._front)).reduce(func(a, b): return a + b, 0.0) / units.size()
	check(side.call(v.helpers) > 10.0 and side.call(foes) < -10.0, "two lines facing each other")
	# The other three ways to fight, on the same valley.
	var river: Dictionary = v.battle_field("river", "river_farmland")
	var bridge_near := v.terrain.bridges.any(func(b): return Vector2(river.center.x, river.center.z).distance_to(b.mid) < 1.0)
	var bank_a: Vector3 = river.center + river.front * river.gap
	var bank_b: Vector3 = river.center - river.front * river.gap
	check(bridge_near and v.terrain.water_surface(bank_a.x, bank_a.z) == -INF and v.terrain.water_surface(bank_b.x, bank_b.z) == -INF,
		"a river battle has a line on each bank of a bridged river")
	for scenario in ["defend", "siege"]:
		var f: Dictionary = v.battle_field(scenario, "old_forest")
		var mine: Vector3 = f.center + f.front * f.gap
		var theirs: Vector3 = f.center - f.front * f.gap
		var near_village := func(p: Vector3) -> float:
			var best := INF
			for vil in v.villages.values():
				best = minf(best, Vector2(p.x, p.z).distance_to(Vector2(vil.global_position.x, vil.global_position.z)))
			return best
		var inside: Vector3 = mine if scenario == "defend" else theirs
		var outside: Vector3 = theirs if scenario == "defend" else mine
		check(near_village.call(inside) < ValleyWorld.WALL_RING * 0.5 and near_village.call(outside) > ValleyWorld.WALL_RING + 20.0,
			"%s: one army holds the village square, the other comes at it from outside" % Valley.SCENARIOS[scenario])
	for e in foes:
		Combat.deal(e, DamageInfo.make(99999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, v.player))
	await _frames(30)
	check(not Run.active, "win and the battle is over")
	Run.practice = false


func test_practice_picks() -> void:
	var gods: Array = load("res://scripts/flow/run_director.gd").practice_gods()
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
	check(Run.practice and Run.state.race_id == "dwarf" and Run.state.god_id == god and Run.state.weapon_id == weapon,
		"Practice starts as a dwarf with the god and class picked (%s, %s)" % [Run.state.god_id, Run.state.weapon_id])
	check(_arena.player.god_id == god and god in _arena.offer_gods, "and offers that god's gifts")
	Flow.practice_god = ""
	Flow.practice_weapon = ""


func test_roads_and_caravans() -> void:
	var v: Valley = await _valley(75)
	var terrain: ValleyTerrain = v.terrain
	var map := ValleyGenerator.neighbors()
	check(terrain.roads.size() >= 5, "roads join the villages (%d)" % terrain.roads.size())
	var joined := terrain.roads.all(func(r): return r.b in map.get(r.a, []) and Run.state.regions[r.a].get("tribe", "") != "" and Run.state.regions[r.b].get("tribe", "") != "")
	check(joined, "each road runs between two neighboring villages")
	var dry := true
	for road in terrain.roads:
		var line: PackedVector2Array = road.line
		for i in line.size() - 1:
			var length := line[i].distance_to(line[i + 1])
			var t := 12.0
			while t < length - 12.0:
				var q := line[i].lerp(line[i + 1], t / length)
				if terrain.water_surface(q.x, q.y) != -INF and not terrain.near_bridge(q.x, q.y, 2.0):
					dry = false
				t += 6.0
	check(dry, "roads stay out of the water, crossing rivers on bridges")
	var road: Dictionary = terrain.roads[0]
	var mid: Vector2 = road.line[0].lerp(road.line[1], 0.5)
	check(terrain.near_road(mid.x, mid.y) and not terrain.near_road(mid.x + 40.0, mid.y + 40.0), "you can tell where a road is")
	var center := ValleyTerrain.region_center(road.a)
	check(terrain.road_angles(center).size() >= 1, "a road leaves its village by a gate")
	var on_road: Color = v.world.ground_color(mid.x, mid.y, terrain.height(mid.x, mid.y), [])
	# Since 2026-11-09 (user: more prominent) a dirt strip lies on top too, just above the ground.
	check(v.world.get_node_or_null("Roads") != null and on_road.is_equal_approx(terrain.color(mid.x, mid.y, terrain.height(mid.x, mid.y), []).lerp(ValleyWorld.ROAD_COLOR, 0.85)), "and is the ground colored along the way, with a dirt strip on it")
	var p := v.player
	p.global_position = Vector3(mid.x, terrain.height(mid.x, mid.y) + 0.5, mid.y)
	check(is_equal_approx(p._road_factor(), GameData.tuning.road_mount_speed), "a mount is quicker on a road")
	var off: Vector2 = Vector2(mid.x, mid.y) + (road.line[1] - road.line[0]).normalized().orthogonal() * 30.0
	p.global_position = Vector3(off.x, terrain.height(off.x, off.y) + 0.5, off.y)
	check(is_equal_approx(p._road_factor(), 1.0), "than off it")


func test_fog_of_war() -> void:
	var fog := FogOfWar.new()
	check(not fog.is_seen(Vector2(100, 200)), "the map starts dark")
	check(fog.reveal(Vector2(100, 200)) and fog.is_seen(Vector2(150, 220)), "walking somewhere reveals the land around it")
	check(not fog.is_seen(Vector2(100 + FogOfWar.SIGHT + 60.0, 200)), "but not far away")
	check(not fog.reveal(Vector2(100, 200)), "nothing new the second time")
	var again := FogOfWar.new(fog.save_text())
	check(again.is_seen(Vector2(150, 220)) and not again.is_seen(Vector2(900, -900)), "a saved run remembers what you've seen")
	check(FogOfWar.new("not base64 at all").seen.size() == FogOfWar.NX * FogOfWar.NZ, "a damaged save just starts the map dark")
	check(fog.get_texture() != null, "the map gets the fog as a picture")


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


func test_retro_look() -> void:
	var mat: ShaderMaterial = RetroLook.get_child(0).material
	check(mat.shader.code.contains("hint_screen_texture"), "the retro look redraws the screen")
	check(RetroLook.layer < 1, "the retro look is drawn under the HUD (layer %d)" % RetroLook.layer)
	var was := RetroLook.visible
	RetroLook.toggle()
	check(RetroLook.visible != was and Meta.data.retro_look == RetroLook.visible, "O turns the retro look off and on, and the profile keeps it")
	RetroLook.toggle()
	check(InputMap.has_action("retro_look"), "the retro look has a key")
	var plain := StandardMaterial3D.new()
	RetroLook.paint(plain)
	var own_tex := StandardMaterial3D.new()
	own_tex.albedo_texture = PlaceholderTexture2D.new()
	RetroLook.paint(own_tex)
	check(plain.albedo_texture == RetroLook.grit() and plain.uv1_triplanar and own_tex.albedo_texture is PlaceholderTexture2D
		and own_tex.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, "a plain model gets pixel grit; a textured one keeps its picture, with sharp pixels")
	var blobs: Array = _arena.player.find_children("*", "Decal", true, false)
	var feet: float = _arena.player.global_position.y
	check(blobs.size() == 1 and absf((blobs[0] as Decal).global_position.y + (blobs[0] as Decal).size.y * 0.5 - 0.15 - feet) < 0.3,
		"the player has a dark disc under the feet instead of a sun shadow")


func test_giants() -> void:
	var v: Valley = await _valley(74)
	var p := v.player
	p.god_mode = true
	var t: CombatTuning = GameData.tuning
	var giants: Array = []
	for g in v.wilds.groups:
		giants.append_array(g.units.filter(func(u): return u.giant))
	check(giants.size() >= 8, "giants roam the valley (%d)" % giants.size())
	check(giants.all(func(g): return not g.flying and not g.water_bound and g.mini_boss), "only on land, each a mini boss")
	var kinds := {}
	for g in giants:
		kinds[g.unit_id] = true
	check(kinds.size() >= 5, "many kinds of them (%d)" % kinds.size())
	# Even a deer: huge, tough, it fights, and it's worth the fight.
	var deer := Enemy.new()
	deer.setup("animal_deer", p, v.director, Enemy.Team.HOSTILE)
	deer.make_giant()
	var base: Dictionary = GameData.unit("animal_deer")
	deer.aggro_radius = 30.0
	deer.post = p.global_position + Vector3(8, 0, 0)
	v.add_child(deer)
	deer.global_position = deer.post + Vector3.UP * 0.5
	await _frames(45)
	check(deer.health.max_hp >= GameData.num(base, "hp") * t.giant_health_mult, "a giant has many times the health")
	check(is_equal_approx(deer._visual.scale.x, t.giant_scale), "and it's huge")
	check(deer.target != null, "a giant deer attacks, though a deer wouldn't")
	check(GameData.text(deer.unit, "display_name") == "Giant Deer" and GameData.text(base, "display_name") == "Deer", "named for what it is, and the sheet's deer stays a deer")
	check(GameData.num(deer.unit, "xp_reward") > GameData.num(base, "xp_reward"), "it gives far more XP")
	var hit := DamageInfo.make(1.0, "Physical", DamageInfo.Kind.HEAVY, p)
	Combat.deal(deer, hit)
	check(not deer.thrown, "your heavy hits don't launch it")
	Combat.deal(deer, DamageInfo.make(999999.0, "Physical", DamageInfo.Kind.LIGHT, p))
	await _frames(3)
	check(deer.is_dead(), "and it dies like anything else")
	get_tree().paused = false


func test_myths() -> void:
	var myths := ["animal_unicorn", "animal_jackalope", "animal_pegasus", "animal_phoenix", "animal_mermaid", "animal_hippocampus", "beast_chimera", "beast_cerberus", "beast_basilisk",
		"beast_feathered_serpent", "beast_leviathan", "monster_cyclops", "monster_frost_giant", "monster_gorgon", "monster_mummy", "monster_harpy"]
	var placed := {}
	for biome in Wilds.PACKS:
		for pack in Wilds.PACKS[biome]:
			for entry in pack:
				placed[entry[0]] = true
	for pack in Wilds.WATER_PACKS:
		placed[pack[0][0]] = true
	for id in myths:
		var row := GameData.unit(id)
		var look: Dictionary = ModelRegistry.for_beast(id) if str(id).begins_with("beast_") or str(id).begins_with("animal_") else ModelRegistry.for_unit(id)
		check(not row.is_empty() and placed.has(id), "%s has a row and a home" % id)
		check(look.has("model") and id in str(look.model), "%s has its own model" % id)
	var v: Valley = await _valley(73)
	var p := v.player
	p.god_mode = true
	# Harpies fly on two legs; a feathered serpent flies with no rig at all.
	for id in ["monster_harpy", "beast_feathered_serpent", "animal_pegasus"]:
		var e := Enemy.new()
		e.setup(id, p, v.director, Enemy.Team.NEUTRAL)
		e.post = p.global_position + Vector3(60, 0, 0)
		v.add_child(e)
		e.global_position = e.post
		await _frames(90)
		var ground: float = v.terrain.height(e.global_position.x, e.global_position.z)
		check(e.flying and e.model != null and e.global_position.y > ground + 5.0, "%s takes to the air" % id)
		e.queue_free()


func test_menus_wait_their_turn() -> void:
	var v: Valley = await _valley(78)
	v.player.god_mode = true
	v.player.global_position = v.loot.spots[0].pos + Vector3.UP
	# A chest that levels you up and offers a gift: both menus, one after the other.
	GameData.tuning.loot_gift_chance_tower = 100.0
	GameData.tuning.loot_gift_chance_cave = 100.0
	Run.state.xp = LevelSystem.xp_to_next(Run.state.level) - 1
	v.loot.open(v.loot.spots[0])
	check(v.hud.is_choosing() and v.hud._offer_kind == "level", "the level-up comes first")
	var picks: Array = Run.state.level_picks.duplicate()
	v.hud._pick(0)
	check(Run.state.level_picks.size() == picks.size() + 1, "and you get your upgrade")
	check(v.hud.is_choosing() and v.hud._offer_kind == "event_gift" and get_tree().paused, "then the gift, instead of it being lost")
	var gifts: int = v.player.godly_gifts.owned.size()
	v.hud._pick(0)
	check(v.player.godly_gifts.owned.size() == gifts + 1 and not get_tree().paused, "and you get that too")
	check(not Run.state.flags.has("pending_gift") and Run.state.pending_level_ups == 0, "with nothing left owing")
	GameData.tuning.loot_gift_chance_tower = 70.0
	GameData.tuning.loot_gift_chance_cave = 35.0
	# A god with nothing left to give must not trap you in an empty menu.
	var seen := [""]
	var heard := func(c): seen[0] = "heard:" + c
	v.hud.god_chosen.connect(heard)
	v.hud.offer_god("forge_god", [])
	check(not v.hud.is_choosing() and seen[0] == "heard:", "an empty god offer closes itself")
	v.hud.god_chosen.disconnect(heard)


func test_saves_survive() -> void:
	# Start Run asks before it replaces a saved run.
	var kept: RunState = Run.state
	var was_active := Run.active
	Run.state = RunState.new()
	Run.practice = false
	Run.active = true
	Run.checkpoint("test")
	Run.active = false
	var screen = load("res://scenes/run_director.tscn").instantiate()
	add_child(screen)
	await _frames(2)
	screen._race = "dwarf"
	screen._god = "forge_god"
	screen._weapon = "warhammer"
	screen._start_run()
	check(not Run.active and SaveSystem.has_run(), "Start Run doesn't start while a saved run exists")
	var asks: Array = screen.find_children("*", "ConfirmationDialog", false, false)
	check(asks.size() == 1 and asks[0].visible, "it asks first")
	asks[0].hide()
	screen.queue_free()
	await _frames(1)
	# Abandoning keeps nothing (user, 2026-11-10): no save to continue, nothing in the profile.
	Run.state = RunState.new()
	Run.practice = false
	Run.active = true
	Run.checkpoint("test")
	var runs: int = Meta.data.runs
	Run.end(false, false)
	check(not SaveSystem.has_run() and Meta.data.runs == runs, "abandoning a run leaves no save and nothing in your profile")
	# Abandoning a custom battle (a practice run) keeps your real run's save.
	SaveSystem.save_run(_fresh_run(32), "test")
	Run.practice = true
	Run.abandon()
	check(SaveSystem.has_run(), "abandoning a custom battle keeps your saved run")
	Run.practice = false
	SaveSystem.delete_run()
	Run.state = kept
	Run.active = was_active
	# A crash in the middle of swapping the files leaves only the temp file: it's still your run.
	var s := _fresh_run(31)
	s.supplies = 55
	check(SaveSystem.save_run(s, "test"), "a run saves")
	var abs_path := ProjectSettings.globalize_path(SaveSystem.RUN_PATH)
	DirAccess.rename_absolute(abs_path, abs_path + ".tmp")
	check(SaveSystem.has_run(), "a save caught mid-swap still counts")
	var back := SaveSystem.load_run()
	check(back != null and back.supplies == 55, "and it loads")
	check(SaveSystem.load_run() != null, "loading doesn't use it up")
	SaveSystem.delete_run()
	check(not SaveSystem.has_run(), "and a finished run leaves no temp file to come back from")
	# A half-written save is thrown away, not offered forever.
	var f := FileAccess.open(SaveSystem.RUN_PATH, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	check(SaveSystem.load_run() == null and not SaveSystem.has_run(), "a broken save is removed")
	# Saves from before this change still load.
	var old := RunState.from_dict({"version": 5, "seed": 3})
	check(old.pending_god == "" and old.pending_level_ups == 0, "older saves load with nothing owing")
	# An unreadable profile is moved aside, not wiped by the next save.
	var aside := SaveSystem.PROFILE_PATH.get_basename() + ".broken.json"
	f = FileAccess.open(SaveSystem.PROFILE_PATH, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	check(SaveSystem.load_profile().is_empty() and FileAccess.file_exists(aside) and not FileAccess.file_exists(SaveSystem.PROFILE_PATH),
		"a broken profile is kept as profile.broken.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(aside))


func test_open_offers_come_back() -> void:
	_fresh_run(79, 0.34)
	var s: RunState = Run.state
	s.pending_god = "storm_god"
	s.pending_level_ups = 1
	s.flags["pending_gift"] = s.god_id
	s.encounters["first_fight"]["state"] = "done"  # past the opening raid
	s.flags["elder_spoke"] = true
	s = RunState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(s.pending_god == "storm_god" and s.pending_level_ups == 1, "what's still open is in the save")
	Run.state = s
	ValleyLayout.use(s)
	_arena.queue_free()
	await _frames(1)
	Run.in_fight = true  # as after F9 mid-fight: the scene reloads without going through Flow
	_arena = VALLEY.instantiate()
	add_child(_arena)
	var v: Valley = _arena
	v.wilds.discovering = false
	v.player.god_mode = true
	await _frames(2)
	check(not Run.in_fight, "a reloaded valley isn't stuck in a fight")
	var w: ValleyWorld = v.world
	var same := true
	for k in [0, 4321, w._heights.size() / 2, w._heights.size() - 1]:
		var gp := w._grid_point(k % (w._nx + 1), k / (w._nx + 1))
		same = same and is_equal_approx(w._heights[k], v.terrain.height(gp.x, gp.y))
	check(same, "the ground built on many threads matches the terrain")
	check(v.hud.is_choosing() and v.hud._offer_kind == "god", "the god's offer comes back")
	v.hud._pick(0)
	await _frames(1)
	check(s.pending_god == "", "and is settled once you choose")
	check(not v.hud._message.text.contains("fight is won"), "with no word of a fight that didn't happen")
	check(v.hud.is_choosing() and v.hud._offer_kind == "event_gift", "then the gift you left open")
	v.hud._pick(0)
	await _frames(2)
	check(not s.flags.has("pending_gift"), "settled too")
	check(v.hud.is_choosing() and v.hud._offer_kind == "level", "then the upgrade you were owed")
	v.hud._pick(0)
	await _frames(2)
	check(s.pending_level_ups == 0 and not v.hud.is_choosing() and not get_tree().paused, "and then you're back in the game")


func test_jungle() -> void:
	var row := GameData.row("valley_regions", "jungle")
	check(not row.is_empty(), "the jungle is a region")
	var biome := GameData.text(row, "biome")
	check(ValleyTerrain.BIOMES.has(biome) and Wilds.PACKS.has(biome) and Wilds.MONSTERS.has(biome), "with its own ground, wildlife and monster")
	var style: Dictionary = ValleyTerrain.BIOMES[biome]
	for model in ValleyWorld.TREES[style.tree]:
		check(ResourceLoader.exists(ValleyWorld.NATURE + model + ".glb"), "%s exists" % model)
	check(GameData.text(GameData.race("cat"), "home_region") == "jungle", "it's the Cat people's home")
	var s := Run.start_new("cat", "animal_god", 77, 1.0)
	check(s.flags.home_region == "jungle" and s.regions["jungle"].tribe == "cat", "and they start there")
	s = Run.start_new("dwarf", "forge_god", 77, 1.0)
	var v: Valley = await _valley(77)
	var c := ValleyTerrain.region_center("jungle")
	check(ValleyTerrain.shape_q(c.x, c.y) <= ValleyTerrain.SAFE_Q, "it's inside the valley")
	check(v.terrain.region_at(c.x, c.y) == "jungle", "and you can walk into it")
	var met: Array = []
	for g in v.wilds.groups:
		if v.terrain.region_at(g.center.x, g.center.z) == "jungle":
			for u in g.units:
				if not u.unit_id in met:
					met.append(u.unit_id)
	check(met.size() >= 3, "things live there (%s)" % [met])


func test_native_animals() -> void:
	var v: Valley = await _valley(71)
	var seen := {}
	for biome in Wilds.PACKS:
		for k in 3:
			for entry in Wilds.PACKS[biome][k]:
				var row := GameData.unit(entry[0])
				check(not row.is_empty(), "%s has a sheet row" % entry[0])
				check(ModelRegistry.for_beast(entry[0]).has("model"), "%s has a model" % entry[0])
				seen[entry[0]] = seen.get(entry[0], {})
				seen[entry[0]][biome] = true
	for id in seen:
		check(seen[id].size() == 1, "%s lives in one biome only" % id)
	check(seen.size() >= 20, "at least two animals of their own per region (%d)" % seen.size())
	var kinds := {}
	for g in v.wilds.groups:
		for u in g.units:
			if seen.has(u.unit_id):
				kinds[u.unit_id] = true
	check(kinds.size() >= 12, "they really roam the valley (%d kinds)" % kinds.size())
	# Stronger monsters, one per biome, and groups of more than one kind (user, 2026-11-03).
	check(Wilds.MONSTERS.size() == GameData.rows("valley_regions").size(), "every region has its monster")
	for biome in Wilds.MONSTERS:
		var row := GameData.unit(Wilds.MONSTERS[biome])
		check(GameData.num(row, "hp") >= 400.0 and GameData.text(row, "role") == "Large", "the %s is far stronger" % row.display_name)
		var models: Dictionary = ModelRegistry.for_beast(Wilds.MONSTERS[biome]) if str(Wilds.MONSTERS[biome]).begins_with("beast_") else ModelRegistry.for_unit(Wilds.MONSTERS[biome])
		check(models.has("model") and str(row.model_file).get_basename() in str(models.model), "and has its own model")
	var mixed := 0
	var monsters := 0
	for g in v.wilds.groups:
		var ids := {}
		for u in g.units:
			ids[u.unit_id] = true
			if Wilds.MONSTERS.values().has(u.unit_id):
				monsters += 1
		if ids.size() > 1:
			mixed += 1
	check(mixed >= 15, "many groups mix kinds of enemies (%d)" % mixed)
	check(monsters >= 5, "monsters roam the valley (%d)" % monsters)
	var s: RunState = Run.state
	s.encounters["test_beasts"] = {"def": "", "region": "old_forest", "state": "available", "race": "", "god": ""}
	var party := EncounterSystem._party(s, "Beasts", "", RandomNumberGenerator.new(), "old_forest")
	check(party.boss == "monster_wendigo" and "beast_panther" in party.pool, "a beast fight in the forest brings its panthers and its Wendigo")
	s.encounters.erase("test_beasts")


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


func test_pitched_battle() -> void:
	var v: Valley = await _valley(62)
	var s := Run.state
	var t: CombatTuning = GameData.tuning
	var races: Array = s.tribes.keys().filter(func(r): return r != EvilTribe.HORDE)
	s.tribes[races[0]].status = "allied"
	s.tribes[races[0]].reputation = 80
	s.tribes[races[1]].status = "corrupted"
	v.player.god_mode = true
	v.debug_final_battle()
	check(Run.in_fight and v.encounter_id == "final_battle", "the final battle starts")
	check(v.helpers.size() == maxi(t.final_battle_min_side, t.battle_home_warriors + t.battle_ally_warriors), "your tribe and your ally line up with you, at least 30 (%d)" % v.helpers.size())
	await _frames(int((t.time_between_waves + 1.0) * 60))
	var foes: Array = v.waves.members.filter(func(e): return is_instance_valid(e) and e.team == Enemy.Team.HOSTILE)
	var converted: Array = foes.filter(func(e): return GameData.text(e.unit, "race_id") == races[1])
	check(converted.size() == t.battle_converted_warriors and foes.size() > converted.size(), "his line: the horde and the converted tribe's warriors (%d of %d)" % [converted.size(), foes.size()])
	check(foes.size() >= t.final_battle_min_side, "at least 30 on his side too (%d)" % foes.size())
	var stats: Dictionary = Run.state.flags.get("stats", {})
	check(float(stats.get("seconds", 0.0)) > 0.0, "the run keeps numbers for its recap")
	var mid := v._battle_center
	var ours: float = v.helpers.map(func(h): return (h.global_position - mid).dot(v._front)).reduce(func(a, b): return a + b, 0.0) / v.helpers.size()
	var theirs: float = foes.map(func(e): return (e.global_position - mid).dot(v._front)).reduce(func(a, b): return a + b, 0.0) / foes.size()
	check(ours > 10.0 and theirs < -5.0, "two lines across the field (%.0f m and %.0f m from the middle)" % [ours, theirs])
	# Count Fuckula rides in on his dragon once his line is broken, then fights on foot.
	check(not GameData.unit(EvilTribe.HORDE_LEADER).is_empty() and ResourceLoader.exists(ModelRegistry.for_unit(EvilTribe.HORDE_LEADER).model), "Count Fuckula has a model")
	check(not EncounterSystem.army_rows(EvilTribe.HORDE).any(func(u): return u.unit_id == EvilTribe.HORDE_LEADER), "he isn't one of the rank and file")
	var the_boss := func(id: String) -> Enemy:
		for i in 1800:
			get_tree().paused = false
			for e in v.waves.members:
				if is_instance_valid(e) and not e.is_dead():
					if e.unit_id == id:
						return e
					if e.unit_id != EvilTribe.HORDE_BOSS or id == EvilTribe.HORDE_LEADER:
						Combat.deal(e, DamageInfo.make(999999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, v.player))
			await _frames(1)
		return null
	var dragon: Enemy = await the_boss.call(EvilTribe.HORDE_BOSS)
	check(dragon != null, "the Evil Dragon comes when his line breaks")
	if dragon == null:
		return
	await _frames(2)
	var riders: Array = dragon._visual.get_children().filter(func(c): return c is CharacterModel and not c is BeastModel)
	check(riders.size() == 1 and riders[0]._seat == EvilTribe.LEADER_SEAT, "Count Fuckula rides it")
	var at := dragon.global_position
	check(Run.active, "the run isn't over yet")
	var count: Enemy = await the_boss.call(EvilTribe.HORDE_LEADER)
	check(count != null and count.global_position.distance_to(at) < 40.0, "when it falls he comes down to fight, near where it fell")
	if count == null:
		return
	check(Run.active and Run.in_fight, "and killing the dragon doesn't end the run")
	Combat.deal(count, DamageInfo.make(999999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, v.player))
	for i in 240:
		get_tree().paused = false
		if not Run.active:
			break
		await _frames(1)
	check(not Run.active and Run.last_result.get("victory", false), "killing him wins the run")


## Encounters and world events are places you come upon (user, 2026-10-29).
func test_world_events() -> void:
	GameData.tuning.giant_chance = 0.0  # a giant's XP would open a level-up menu in the middle of this test
	await _world_events()
	GameData.tuning.giant_chance = 0.16


## Time passes as if the player closed whatever menu comes up (a level-up from a kill, a tribe's question).
func _frames_past_menus(v: Valley, count: int) -> void:
	for i in count:
		if v.hud.is_choosing():
			v.hud._choice.visible = false
		get_tree().paused = false
		await _frames(1)


func _world_events() -> void:
	var v: Valley = await _valley(61)
	for race in v.villages:  # no village raid starting as you pass by: this test is about the wild
		if Run.state.encounters.has("tm_" + race):
			Run.state.encounters["tm_" + race]["asked"] = true
	# God mode flies (user, 2026-10-30): Space rises with no gravity.
	var y0 := v.player.global_position.y
	v.player.flying = true
	var fly := _scripted()
	fly.hold({"jump_held": true}, 30)
	await _frames(30)
	check(v.player.global_position.y > y0 + 10.0, "god mode flies up (%.0f m)" % (v.player.global_position.y - y0))
	v.player.flying = false
	var s := Run.state
	var ev: WorldEvents = v.events
	v.player.god_mode = true  # the attackers fight whoever stands there
	var kinds := {}
	for e in ev.events:
		kinds[e.kind] = int(kinds.get(e.kind, 0)) + 1
	var bridges: int = ev.events.filter(func(e): return e.id.begins_with("bridge_")).size()
	check(bridges >= v.terrain.bridges.size() / 2 and kinds.has("caravan") and kinds.has("ritual") and kinds.has("quest"),
		"bridges, caravans, rituals and quests are out there (%s, %d of %d bridges)" % [kinds, bridges, v.terrain.bridges.size()])
	check(ev.events.filter(func(e): return e.id.begins_with("hamlet_")).size() >= 1, "fishing hamlets give quests")
	var beams := v.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.mesh is CylinderMesh and (m.mesh as CylinderMesh).height > 50.0)
	check(beams.is_empty(), "no beams of light")
	var kill := func(units: Array):
		for u in units:
			if is_instance_valid(u) and not u.is_dead():
				Combat.deal(u, DamageInfo.make(99999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, v.player))
	# A caravan: defend it.
	var caravans: Array = ev.events.filter(func(e): return e.kind == "caravan")
	var c: Dictionary = caravans[0]
	# It travels a trail through the woods until you come near, then it's ambushed (user, 2026-11-08).
	check(not c.sprung and c.foes.is_empty(), "a caravan is on its way, not yet attacked")
	var was: Vector3 = c.pos
	v.player.global_position = c.pos + Vector3(0, 2, WorldEvents.AMBUSH_RANGE + 30.0)
	await _frames(90)
	check(c.pos.distance_to(was) > 1.0 and not c.sprung, "it moves along its trail (%.1f m)" % c.pos.distance_to(was))
	v.player.global_position = c.pos + Vector3(0, 2, 10)
	await _frames(3)
	check(c.sprung and not c.foes.is_empty(), "come near and it's ambushed")
	var rep: int = s.tribes[c.race].reputation
	var supplies := s.supplies
	v.player.global_position = c.pos + Vector3(0, 2, 3)
	ev.on_choice("event:" + c.id, "defend")
	kill.call(c.foes)
	await _frames(40)
	check(c.done and s.tribes[c.race].reputation > rep and s.supplies > supplies, "defending a caravan: its tribe likes you more and pays")
	var guard: Enemy = WorldEvents._living(c.friends)[0] if not WorldEvents._living(c.friends).is_empty() else null
	if guard != null:
		v.player.global_position = c.pos + Vector3(0, 2, 40)
		await _frames(120)
		check(guard.global_position.distance_to(c.pos) < 20.0, "the caravan's guards stay with their cart, not with you")
	if caravans.size() > 1:
		var j: Dictionary = caravans[1]
		rep = s.tribes[j.race].reputation
		v.player.global_position = j.pos + Vector3(0, 2, 3)
		await _frames(40)
		if v.hud.is_choosing():  # a village close by asks first: leave it
			v.hud._pick(v.hud._offer.size() - 1)
		ev.on_choice("event:" + j.id, "join")
		check(j.friends.all(func(u): return not is_instance_valid(u) or u.team == Enemy.Team.HOSTILE), "joining the attack turns the guards on you")
		kill.call(j.friends)
		for f in 180:
			if v.hud.is_choosing():  # level-ups from the kills, or a village asking: move on
				v.hud._pick(v.hud._offer.size() - 1 if v.hud._offer_kind.begins_with("tribe:") else 0)
			await get_tree().process_frame
		check(j.done and s.tribes[j.race].reputation < rep, "robbing a caravan: its tribe likes you less")
	# A ritual: partake.
	var r: Dictionary = ev.events.filter(func(e): return e.kind == "ritual")[0]
	rep = s.tribes[r.race].reputation
	v.player.global_position = r.pos + Vector3(0, 2, 3)
	await _frames(40)
	ev.on_choice("event:" + r.id, "partake")
	check(r.done and s.tribes[r.race].reputation > rep and v.hud.is_choosing() and v.hud._offer_kind == "event_gift", "partaking in a rite: the tribe likes you more, its god offers a gift")
	v.hud._pick(0)
	await _frames(2)
	# A trader's stall.
	var shops: Array = ev.events.filter(func(e): return e.kind == "shop")
	if not shops.is_empty():
		v.player.health.hp = 10.0
		s.supplies = 50
		ev.on_choice("event:" + shops[0].id, "heal")
		check(v.player.health.hp == v.player.health.max_hp and s.supplies == 40, "the trader sells healing for supplies")
		check(WorldEvents.SHOP.size() + 1 <= 3, "the stall's menu fits the HUD's 3 options, Leave included")
	# A quest.
	var q: Dictionary = ev.events.filter(func(e): return e.kind == "quest")[0]
	v.player.global_position = q.pos + Vector3(0, 2, 3)
	await _frames(40)
	ev.on_choice("event:" + q.id, "accept")
	check(q.choice == "accepted" and not q.foes.is_empty(), "a quest sends you after a pack nearby")
	supplies = s.supplies
	kill.call(q.foes)
	await _frames_past_menus(v, 40)
	check(q.done and s.supplies > supplies and q.id in s.flags.events_done, "driving it off pays, and stays done for the run")
	# The big landmarks (user, 2026-10-30; three of each since 2026-11-05), on dry ground, solid to walk into.
	var names: Array = v.terrain.landmarks.filter(func(l): return not l.has("chest")).map(func(l): return l.name)
	check(names.size() == ValleyTerrain.LANDMARKS.size() * ValleyTerrain.LANDMARK_COPIES + 1 + ValleyTerrain.SKY_ISLANDS.size(), "the Mammoth Graveyard, the Abandoned Quarry and the Castle are out there (%s)" % [names])
	var castle: Node3D = v.world.get_node_or_null("landmark_castle")
	check(castle != null and not castle.find_children("*", "StaticBody3D", true, false).is_empty(), "the castle's walls are solid")
	var tower: Node = v.world.get_children().filter(func(c): return String(c.name).begins_with("tower_")).front()
	var tower_mat: BaseMaterial3D = (tower.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.surface_get_material(0)
	check(tower_mat.albedo_texture == ValleyWorld.STONE_TEXTURE, "the Old Towers wear the user's stone picture")
	# Camps sit at least 500 m from every tribe's village (user, 2026-10-30).
	var close_camps: Array = []
	for id in s.encounters:
		if s.encounters[id].def != "tm_clear_camp":
			continue
		for vi in v.villages.values():
			if Vector2(vi.global_position.x, vi.global_position.z).distance_to(ValleyTerrain.site_point(s, id)) < ValleyTerrain.CAMP_CLEAR:
				close_camps.append(id)
	check(close_camps.is_empty(), "every camp is at least 500 m from every village (%s too close)" % [close_camps])
	# A camp starts its fight when you walk in.
	var camps: Array = v.sites.keys().filter(func(id): return v.sites[id].auto)
	check(not camps.is_empty() and not v.sites[camps[0]].sentries.is_empty(), "camps have their fighters standing around")
	v.player.global_position = v.sites[camps[0]].global_position + Vector3(0, 2, 5)
	await _frames_past_menus(v, 70)
	check(Run.in_fight and v.encounter_id == camps[0], "walking into a camp starts its fight")


func test_valley_wilds() -> void:
	var v: Valley = await _valley(54)
	var home := ValleyTerrain.region_center(v.home_region())
	check(v.wilds.groups.size() >= Wilds.GROUPS - 2, "barbarian patrols and beast packs roam the valley (%d groups)" % v.wilds.groups.size())
	var too_close := v.wilds.groups.filter(func(g): return Vector2(g.center.x, g.center.z).distance_to(home) < Wilds.CLEAR_HOME)
	check(too_close.is_empty(), "none of them near your camp")
	var beasts := 0
	for g in v.wilds.groups:
		for u in g.units:
			if u.unit_id.begins_with("beast_"):
				beasts += 1
	check(beasts > 0, "beasts among them")
	# The user's slime (user, 2026-10-31): roams the world as well as marching with the horde.
	var slimes := 0
	for g in v.wilds.groups:
		slimes += g.units.filter(func(u): return u.unit_id == "horde_slime").size()
	var slime := ModelRegistry.for_beast("horde_slime")
	var blob := BeastModel.new()
	add_child(blob)
	blob.setup_beast(slime.model, 1.0)
	blob.play("Walking_A")
	check(slimes > 0 and slime.model == ModelRegistry.OWN + "horde_slime.glb" and blob._clip.has("attack") and blob.anim.is_playing(), "the user's slime oozes about the valley, animated (%d slimes)" % slimes)
	blob.queue_free()
	# Free animals (user, 2026-10-31): livestock in the villages, herds to hunt, dinosaurs.
	var stock := 0
	for vil in v.villages.values():
		stock += vil.villagers.filter(func(u): return is_instance_valid(u) and u.unit_id.begins_with("animal_")).size()
	check(stock > 0, "cows, sheep and pigs wander the villages (%d)" % stock)
	# Each race builds in its own culture (user, 2026-10-31): its houses and a landmark.
	var styled := 0
	for race in v.villages:
		var vil: Village = v.villages[race]
		if vil.buildings != null and vil.buildings.get_children().any(func(n): return str(n.scene_file_path).get_file().begins_with(race + "_landmark")):
			styled += 1
	check(styled >= v.villages.size() - 2, "the tribes' villages have their own buildings (%d of %d)" % [styled, v.villages.size()])
	var cow := Enemy.new()
	cow.setup("animal_cow", v.player, v.director, Enemy.Team.HOSTILE)
	v.add_child(cow)
	cow.global_position = v.player.global_position + Vector3(4, 0, 0)
	cow.post = cow.global_position
	await _frames(2)
	var start := cow.global_position
	cow.take_hit(DamageInfo.make(5.0, "Physical", DamageInfo.Kind.LIGHT, v.player))
	await _frames(60)
	check(cow.civilian and cow.target == null and cow.model is BeastModel and cow.global_position.distance_to(v.player.global_position) > start.distance_to(v.player.global_position) + 1.5, "a hunted cow never fights back and runs from you")
	cow.queue_free()
	var rex := Enemy.new()
	rex.setup("beast_trex", v.player, v.director, Enemy.Team.HOSTILE)
	check(rex.is_large and rex.size_scale == 1.0 and ModelRegistry.for_beast("beast_trex").model == ModelRegistry.FREE + "beast_trex.glb", "the T-Rex is built at its own (huge) size")
	rex.free()
	# Water monsters (user, 2026-10-29): in deep water, away from bridges, only after swimmers.
	var water: Array = v.wilds.groups.filter(func(g): return g.get("water", false))
	check(water.size() >= Wilds.WATER_GROUPS * 0.7, "water monsters live in the rivers and lakes (%d groups)" % water.size())
	var dry: Array = water.filter(func(g): return v.terrain.water_surface(g.center.x, g.center.z) == -INF or v.terrain.near_bridge(g.center.x, g.center.z, Wilds.CLEAR_BRIDGE - 1.0))
	check(dry.is_empty(), "every one in water, none at a bridge")
	var t: CombatTuning = GameData.tuning
	var kinds := {}
	for g in water:
		for u in g.units:
			kinds[u.unit_id] = true
			var speed := GameData.num(u.unit, "move_speed", 0.0) * t.enemy_speed_scale
			if u.civilian or u.unit_id == "beast_jellyfish":  # harmless, or only drifts: no need to outswim you
				continue
			if not u.water_bound or speed <= t.swim_sprint_speed or speed >= t.sprint_speed:
				kinds["bad"] = u.unit_id
	check(not kinds.has("bad") and kinds.size() >= 4, "they outswim you but not your run (%s)" % [kinds.keys()])
	var m: Enemy = water.filter(func(g): return not g.units[0].civilian)[0].units[0]
	var shore := v.player.global_position
	m.set_dormant(false)
	check(m._pick_target() == null, "on land you're safe from them")
	v.player.global_position = m.global_position + Vector3(6.0, -1.5, 0.0)
	m._aggroed = false
	check(m._pick_target() == v.player, "in the water they come for you")
	v.player.global_position = shore
	await _frames(2)
	# Grass tufts grow only where the shell grass is thin (2026-11-10: they stood out on top of it).
	var meadow: Array = v.world.find_children("grass_meadow_*", "MultiMeshInstance3D", false, false)
	var tufts: Array = v.world.find_children("grass_a_*", "MultiMeshInstance3D", false, false)
	if ValleyWorld.BLADES:
		check(meadow.is_empty() and not tufts.is_empty(), "no tufts on thick shell grass; the generated tufts where it's thin (%d / %d chunks)" % [meadow.size(), tufts.size()])
	else:
		check(meadow.is_empty() and tufts.is_empty() and v.grass == null, "grass blades are off: only the ground texture (ValleyWorld.BLADES)")
	check(not v.world.plant_model("grass_meadow_a").is_empty(), "your grass model still loads from models/own/world")
	for race in v.villages:  # no village raid starting while the test walks around
		if Run.state.encounters.has("tm_" + race):
			Run.state.encounters["tm_" + race]["asked"] = true
	# The user's grass tile (their grass.blend) carpets the ground near you where the grass covers it.
	var covered := Vector2.INF
	for r in GameData.rows("valley_regions"):
		if float(v.terrain.style_at(ValleyTerrain.region_center(r.region_id).x, ValleyTerrain.region_center(r.region_id).y).get("cover", 0.0)) >= ValleyWorld.CARPET_COVER and r.region_id != v.home_region():
			covered = ValleyTerrain.region_center(r.region_id) + Vector2(40.0, 40.0)
			break
	var keep: Vector3 = v.player.global_position
	v.player.global_position = Vector3(covered.x, v.terrain.height(covered.x, covered.y) + 1.0, covered.y)
	await _frames(40)
	if ValleyWorld.BLADES:
		check(v.grass.cell_count() >= 20, "grass covers the ground around you in a covered biome (%d cells)" % v.grass.cell_count())
		var far_cells: Array = v.grass._cells.keys().filter(func(k): return v.grass._center(k).distance_to(covered) > GrassField.RADIUS + GrassField.CELL * 1.5)
		check(far_cells.is_empty(), "the carpet only exists near you")
		await _frames(60)
		var distant: Array = v.grass._cells.keys().filter(func(k): return v.grass._cells[k] != null and v.grass._center(k).distance_to(covered) > GrassField.FULL * 2.0)
		check(not distant.is_empty(), "grass shows out to %d m (thinner past %d m)" % [GrassField.RADIUS, GrassField.FULL])
	check(v.world.plant_model("grass_carpet")[0].get_faces().size() / 3 >= 200, "the tile is your grass, hundreds of blades (%d)" % (v.world.plant_model("grass_carpet")[0].get_faces().size() / 3))
	# The user's grass picture lies on the ground there, and not where the grass doesn't cover it.
	var bare := Vector2.INF
	for r in GameData.rows("valley_regions"):
		var rc := ValleyTerrain.region_center(r.region_id)
		if float(v.terrain.style_at(rc.x, rc.y).get("cover", 0.0)) < 0.2:
			bare = rc
			break
	var grassy: float = v.terrain.color(covered.x, covered.y, v.terrain.height(covered.x, covered.y)).a
	check(grassy > 0.9 and v.terrain.color(bare.x, bare.y, v.terrain.height(bare.x, bare.y)).a < 0.1 and v.world._ground_mat.get_shader_parameter("grass") == ValleyWorld.GRASS_TEXTURE,
		"your grass picture is on the grassy ground only (%.2f)" % grassy)
	v.player.global_position = keep
	await _frames(2)
	var g: Dictionary = v.wilds.groups.filter(func(w): return not w.water and not w.units[0].civilian and not w.units[0].peaceful and not w.units[0].flying)[0]  # a fighting group, not a herd
	v.player.god_mode = true
	v.player.global_position = g.center + Vector3(0, 2, 12)
	for u in g.units:
		u.set_dormant(false)
	await _frames(60)
	var buddy: Enemy = v.player.mount.companion
	check(buddy != null and buddy.team == Enemy.Team.FRIENDLY and buddy.global_position.distance_to(v.player.global_position) < Mount.COMPANION_LEASH, "on foot, your mount walks with you as a fighter")
	check(g.units.any(func(u): return is_instance_valid(u) and (u.target == v.player or (buddy != null and u.target == buddy))), "a group attacks you (or your mount beside you) when you come close")
	for u in g.units:
		Combat.deal(u, DamageInfo.make(99999.0, "Physical", DamageInfo.Kind.GODLY_GIFT, v.player))
	await _frames(2)
	check(Run.state.xp > 0 or Run.state.level > 1, "killing wild enemies gives XP")
	v.wilds.update(Wilds.RESPAWN_SECONDS + 1.0)
	var fresh: Dictionary = v.wilds.groups[0]
	check(not fresh.units.is_empty() and fresh.center.distance_to(v.player.global_position) >= Wilds.RESPAWN_AWAY, "a wiped-out group is replaced somewhere away from you")
	check(Run.state.evil.next_push_in > 0.0 and not Run.in_fight, "wild fights aren't encounters (the clock keeps running)")


func test_mount() -> void:
	var p: Player = _arena.player
	var t: CombatTuning = GameData.tuning
	check(p.mount.has_mount() and GameData.text(p.mount.data, "display_name") == "Ram", "the dwarf rides a ram")
	var s := _scripted()
	s.press("mount")
	await _frames(2)
	check(p.mount.riding and p.mount.beast != null, "X calls the mount and you ride it")
	# The user's ram (ram.blend -> models/own) on the Quaternius bull's skeleton (--rig), with its clips.
	var ram := ModelRegistry.for_mount(p.mount.data)
	check(ram.model == ModelRegistry.OWN + "mount_war_ram.glb" and absf(float(ram.saddle) - 1.57) < 0.05, "the dwarf's ram is the user's model, seated on its back (%s)" % [ram])
	check(p.mount.beast._clip.has("run") and String(p.mount.beast._clip.get("attack", "")).ends_with("Attack_Headbutt"), "the user's ram is rigged and attacks with the bull's headbutt")
	var rat := ModelRegistry.for_mount(GameData.where("mounts", "race_id", "ratfolk")[0])
	var rat_model := BeastModel.new()
	add_child(rat_model)
	rat_model.setup_beast(rat.model, 1.0)
	rat_model.play("Walking_A")
	check(rat.model == ModelRegistry.OWN + "mount_dire_rat.glb" and rat_model._clip.get("walk") == rat_model._clip.get("run") and rat_model.anim.is_playing(), "the user's rat runs with its own animation (walking too, slower)")
	rat_model.queue_free()
	var hyena := ModelRegistry.for_mount(GameData.where("mounts", "race_id", "gnoll")[0])
	check(hyena.model == ModelRegistry.OWN + "mount_dire_hyena.glb", "the gnolls ride the user's hyena (%s)" % [hyena])
	var raptor := ModelRegistry.for_mount(GameData.where("mounts", "race_id", "frog")[0])
	check(raptor.model == ModelRegistry.FREE + "mount_raptor.glb" and absf(float(raptor.saddle) - 1.41) < 0.05, "the frogfolk ride a raptor (user, 2026-10-31) (%s)" % [raptor])
	var bird := ModelRegistry.for_mount(GameData.where("mounts", "race_id", "bird")[0])
	var bird_model := BeastModel.new()
	add_child(bird_model)
	bird_model.setup_beast(bird.model, 1.0)
	check(bird.model == ModelRegistry.FREE + "mount_terror_bird.glb" and float(bird.saddle) > 1.0 and bird_model._clip.has("run") and bird_model._clip.has("attack"), "the Birdmen's bird is on the raptor's skeleton, with its clips (%s)" % [bird])
	bird_model.queue_free()
	check(ModelRegistry.weapon_model("warhammer").begins_with(ModelRegistry.OWN) and ModelRegistry.weapon_model("greatsword").begins_with(ModelRegistry.OWN), "the user's warhammer and sword are the Warhammer and Greatsword")
	# Large weapons in both hands (user, 2026-10-29): the left hand on the handle, two-handed animations.
	var two := CharacterModel.new()
	add_child(two)
	two.setup(ModelRegistry.for_race("dwarf"), ModelRegistry.weapon_model("warhammer"))
	two.play("Running_A")
	var one := CharacterModel.new()
	add_child(one)
	one.setup(ModelRegistry.for_race("dwarf"), ModelRegistry.own("weapon_mace.glb"))
	check(two._left_ik != null and two.anim.current_animation == "Running_HoldingRifle" and two.current() == "Running_A" and one._left_ik == null,
		"large weapons are held in both hands, the mace in one")
	two.queue_free()
	one.queue_free()
	s.hold({"move": Vector2(0, 1), "sprint": true}, 90)
	await _frames(90)
	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	check(speed > t.sprint_speed, "riding is faster than running (%.1f vs %.1f m/s)" % [speed, t.sprint_speed])
	var hp := p.health.hp
	var e: Enemy = _cluster(1, 3.0)[0]
	Combat.deal(p, DamageInfo.make(30.0, "Physical", DamageInfo.Kind.ENEMY, e))
	check(is_equal_approx(p.health.hp, hp) and p.mount.hp < p.mount.max_hp, "hits land on the mount, not on you")
	Combat.deal(p, DamageInfo.make(9999.0, "Physical", DamageInfo.Kind.ENEMY, e))
	check(not p.mount.riding and p.mount.cooldown > 0.0 and not p.mount.can_ride(), "a beaten mount throws you and needs time to recover")
	check(p.visual.is_ragdoll(), "thrown off a dying mount: you go limp")
	await _frames(int(Player.THROWN_TIME * 60) + 10)
	check(not p.visual.is_ragdoll(), "and get back up")
	check(is_equal_approx(p.mount.max_hp, GameData.num(p.mount.data, "hp") * t.mount_health_mult), "mounts have half their sheet health")
	p.mount.cooldown = 0.0
	p.mount.ride()
	p.facing = Vector3.FORWARD  # _cluster puts enemies to the north
	var enemies := _cluster(3, 2.0)
	p.velocity = p.facing * 30.0
	# The attack starts before the hit (user, 2026-11-01).
	p.mount._butt_left = 0.0
	p.mount._headbutt(12.0)
	check(p.mount._butt_left > 0.0 and p.mount.beast.anim.current_animation == p.mount.beast._clip.attack, "the mount attacks just before it reaches them")
	p.mount._trample()
	check(enemies.any(func(x): return is_instance_valid(x) and x.health.hp < x.health.max_hp), "charging into enemies tramples them")
	# A full gallop throws them (user, 2026-10-30): limp, flying back; alive, they get up.
	p.velocity = Vector3.ZERO  # standing while the next one arrives: the mount's own trample can't reach it first
	var flung: Enemy = _cluster(1, 2.0, "barb_berserker")[0]
	flung.health.max_hp = 5000.0  # it may land against the arena wall: it has to live to get up
	flung.health.hp = 5000.0
	var start := flung.global_position
	p.velocity = p.facing * p.mount.speed(true)
	p.mount._trampled.clear()
	p.mount._gallop_time = 0.5
	p.mount._trample()
	check(not flung.thrown, "a gallop just begun tramples but doesn't throw (user, 2026-11-05)")
	p.mount._trampled.clear()
	p.mount._gallop_time = GameData.tuning.mount_throw_after + 0.1
	p.mount._trample()
	check(flung.thrown and flung.model.is_ragdoll(), "after 2 s at a full gallop: thrown, limp")
	for i in 480:  # a long throw takes a while to land and get up
		if i >= 240 and not flung.thrown and not flung.model.is_ragdoll():
			break
		await get_tree().physics_frame
	check(not flung.thrown and not flung.is_dead() and not flung.model.is_ragdoll() and flung.global_position.distance_to(start) > 3.0,
		"it lands %.0f m back and gets up" % flung.global_position.distance_to(start))
	var before := flung.health.hp
	flung.throw(Vector3(0, 2, 15), p)
	flung._impact(1.0)  # from 15 m/s to 1 in a frame: it hit a tree
	check(flung.health.hp < before, "hitting something while thrown hurts")
	await _frames(240)
	var doomed: Enemy = _cluster(1, 2.0, "barb_raider")[0]
	doomed.health.hp = 1.0
	p.velocity = p.facing * p.mount.speed(true)
	p.mount._trampled.clear()
	p.mount._gallop_time = GameData.tuning.mount_throw_after + 0.1
	p.mount._trample()
	await _frames(10)
	check(doomed.is_dead(), "a throw that kills: it stays down")
	if not p.mount.riding:  # the throw tests' enemies may have beaten the (half-health) mount
		await _frames(int(Player.THROWN_TIME * 60) + 10)
		p.mount.cooldown = 0.0
		p.mount.ride()
	p.mount.hp = p.mount.max_hp
	s.hold({}, 2)
	s.press("jump")
	await _frames(4)
	check(p.velocity.y > 0.0 or not p.is_on_floor(), "Space makes the mount jump")
	await _frames(60)
	s.press("dodge")
	await _frames(2)
	check(p.mount.riding and p.state != Player.State.DODGE, "dodging does nothing on a mount: you stay on (user, 2026-11-08)")


func test_new_races() -> void:
	var names: Array = ["frog", "macaque", "cat"].map(func(r): return GameData.text(GameData.race(r), "display_name"))
	check(names == ["Frogfolk", "Snow Macaque", "Catfolk"], "Frogfolk, Snow Macaques and Catfolk are races (%s)" % [names])
	check(GameData.where("army_units", "race_id", "cat").size() == 5 and GameData.where("tribe_members", "race_id", "macaque").size() == 4, "each has an army and villagers")
	var mammoth: Array = GameData.where("mounts", "race_id", "macaque")
	check(not mammoth.is_empty() and mammoth[0].mount_id == "giant_rabbit" and not ModelRegistry.for_mount(mammoth[0]).is_empty(), "the Snow Macaques ride the Giant Rabbit")
	check(ValleyGenerator.patron("cat") == "animal_god" and ValleyGenerator.patron("frog") == "", "Catfolk tribes worship the Lord of Beasts (their first starting god); Frogfolk none (both theirs are set aside)")
	check(not ModelRegistry.for_mount(GameData.where("mounts", "race_id", "cat")[0]).is_empty(), "the Jungle Sabertooth has a stand-in model")


func test_islands() -> void:
	for seed_value in [3, 17, 2024, 777]:  # every valley gets them
		var tt := ValleyTerrain.new(seed_value)
		check(tt.lakes.filter(func(l): return l.has("island")).size() == 1 and tt.sky_islands.size() == ValleyTerrain.SKY_ISLANDS.size(),
			"seed %d: a giant lake and %d floating islands" % [seed_value, tt.sky_islands.size()])
	var v: Valley = await _valley(56)
	var t: ValleyTerrain = v.terrain
	var p: Player = v.player
	# The giant lake: water all around an island with a castle (and its war band) on it.
	var lake: Dictionary = t.lakes.filter(func(l): return l.has("island"))[0]
	var lp: Vector2 = lake.pos
	var ring: Vector2 = lp + Vector2(lake.island + ValleyTerrain.ISLAND_SLOPE + 25.0, 0.0)
	check(lake.radius >= ValleyTerrain.GIANT_LAKE.y and not lake.deep, "a giant lake anyone can swim (%d m across)" % int(lake.radius * 2.0))
	check(t.height(lp.x, lp.y) > lake.surface + 2.0 and t.water_surface(lp.x, lp.y) == -INF and t.water_surface(ring.x, ring.y) == lake.surface,
		"an island in its middle, water all around it")
	var castle: Array = t.landmarks.filter(func(l): return l.pos == lp)
	check(castle.size() == 1 and castle[0].model == ValleyTerrain.GIANT_ISLAND, "a castle on the island")
	var holds: Array = v.events.events.filter(func(ev): return ev.kind == "hold")
	var on_lake: Array = holds.filter(func(ev): return Vector2(ev.pos.x, ev.pos.z).distance_to(lp) < 1.0)
	check(on_lake.size() == 1 and on_lake[0].foes.all(func(e): return e.global_position.y > lake.surface), "its war band and boss hold the island")
	# A random shape, and a bridge out to the island held by a war band (user, 2026-11-08).
	var shores: Array = range(36).map(func(k): return ValleyTerrain.shore_radius(lake, TAU * k / 36.0))
	check(shores.max() > shores.min() * 1.3, "the giant lake is a random shape, not a circle (shore %d-%d m out)" % [shores.min(), shores.max()])
	var lb: Array = t.bridges.filter(func(b): return b.get("lake", false))
	check(lb.size() == 1 and t.water_surface(lb[0].a.x, lb[0].a.y) == -INF and lb[0].b.distance_to(lp) < lake.island,
		"a bridge runs from the shore to the island (%d m)" % int(lb[0].a.distance_to(lb[0].b)) if not lb.is_empty() else "a bridge runs from the shore to the island")
	var held_bridge: Array = v.events.events.filter(func(ev): return ev.id == "lake_bridge")
	check(held_bridge.size() == 1 and held_bridge[0].foes.size() == WorldEvents.LAKE_BRIDGE_GUARDS and held_bridge[0].foes.all(func(e): return e.global_position.y > lake.surface + 0.5),
		"a war band holds the bridge, on its deck")
	await _frames(2)
	if not lb.is_empty():
		var deck_at: Vector2 = lb[0].mid
		var deck := v.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(deck_at.x, lake.surface + 30.0, deck_at.y), Vector3(deck_at.x, lake.surface - 5.0, deck_at.y), 0b001))
		check(not deck.is_empty() and deck.position.y > lake.surface, "you can walk across it")
	# The floating islands: up in the sky, each holding a landmark and its band, stepping stones up.
	for s in t.sky_islands:
		var under := t.height(s.pos.x, s.pos.y)
		var held: Array = t.landmarks.filter(func(l): return l.pos == s.pos and l.get("y", -INF) == s.top)
		check(s.top - under >= ValleyTerrain.SKY_CLEAR - 0.5 and held.size() == 1, "%s floats %d m up" % [held[0].name if held.size() else "?", int(s.top - under)])
		var steps: Array = s.steps
		var first: Vector3 = steps[0]
		var last: Vector3 = steps[steps.size() - 1]
		var climbable := first.y - t.height(first.x, first.z) <= ValleyTerrain.STEP_RISE + 0.6
		for k in range(1, steps.size()):
			var a: Vector3 = steps[k - 1]
			var b: Vector3 = steps[k]
			climbable = climbable and b.y - a.y <= ValleyTerrain.STEP_RISE + 0.01 and Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) <= ValleyTerrain.STEP_GAP + 0.1
		var edge: float = Vector2(last.x, last.z).distance_to(s.pos) - s.radius
		check(climbable and s.top - last.y <= ValleyTerrain.STEP_RISE + 0.01 and edge < 4.0, "stepping stones a jump apart, up to its edge (%d stones)" % steps.size())
		var ev: Array = holds.filter(func(e): return Vector2(e.pos.x, e.pos.z).distance_to(s.pos) < 1.0)
		check(ev.size() == 1 and ev[0].foes.all(func(e): return absf(e.global_position.y - s.top) < 1.0), "its war band stands up on the island")
		check(t.stand_height(s.pos.x, s.pos.y, s.top) == s.top and t.stand_height(s.pos.x, s.pos.y, under) == under, "standing on it vs under it")
	# The island is solid: you land on it and stay.
	var sky: Dictionary = t.sky_islands[0]
	p.global_position = Vector3(sky.pos.x + 10.0, sky.top + 2.0, sky.pos.y)
	p.velocity = Vector3.ZERO
	await _frames(40)
	check(p.global_position.y > sky.top - 0.3 and p.global_position.y < sky.top + 3.0, "you stand on the floating island (or its landmark) (%.1f vs %.1f)" % [p.global_position.y, sky.top])
	var stone: Vector3 = sky.steps[3]
	p.global_position = stone + Vector3.UP * 1.5
	p.velocity = Vector3.ZERO
	await _frames(30)
	check(absf(p.global_position.y - stone.y) < 0.6, "and on a stepping stone")
	# Knocked off the edge, an enemy falls all the way down and stays down there.
	var sky_ev: Dictionary = holds.filter(func(e): return Vector2(e.pos.x, e.pos.z).distance_to(sky.pos) < 1.0)[0]
	var foe: Enemy = sky_ev.foes.filter(func(e): return not e.mini_boss and not e.is_large)[0]
	foe.set_dormant(false)
	foe.health.max_hp = 1e6
	foe.health.hp = 1e6
	var out := Vector3(foe.global_position.x - sky.pos.x, 0.0, foe.global_position.z - sky.pos.y).normalized()
	foe.global_position = Vector3(sky.pos.x, sky.top, sky.pos.y) + out * (sky.radius - 1.0) + Vector3.UP * 0.5
	foe.throw(out * 12.0 + Vector3.UP * 3.0, p)
	var landed := false
	for i in 600:
		await get_tree().physics_frame
		if not foe.thrown and foe.global_position.y < sky.top - 10.0 and foe.is_on_floor():
			landed = true
			break
	var ground_y := t.height(foe.global_position.x, foe.global_position.z)
	check(landed and absf(foe.global_position.y - ground_y) < 2.0, "knocked off the island, it falls all the way to the ground (%.1f, ground %.1f)" % [foe.global_position.y, ground_y])
	check(foe.post.y < sky.top - 8.0, "and its home is down there now (no walking back up)")
	# Knocked into the water, an enemy is a water monster's prey.
	var wet := Vector3(ring.x, lake.surface, ring.y)
	var monster := Enemy.new()
	monster.setup("beast_water_serpent", p, v.director, Enemy.Team.HOSTILE)
	v.add_child(monster)
	monster.global_position = wet
	monster.aggro_radius = 20.0
	var swimmer := Enemy.new()
	swimmer.setup("barb_raider", p, v.director, Enemy.Team.HOSTILE)
	v.add_child(swimmer)
	swimmer.global_position = wet + Vector3(4.0, -1.2, 0.0)
	check(monster._pick_target() == swimmer, "a water monster goes for an enemy knocked into the water")
	swimmer.global_position = Vector3(lp.x, t.height(lp.x, lp.y) + 0.2, lp.y) + Vector3(0, 0, 0)
	check(monster._pick_target() != swimmer, "but not one on dry land")
	monster.queue_free()
	swimmer.queue_free()


func test_valley_water() -> void:
	var v: Valley = await _valley(56)
	var t: ValleyTerrain = v.terrain
	var p: Player = v.player
	var branches := t.rivers.filter(func(r): return r.branch)
	check(t.rivers.size() - branches.size() == 3 and t.waterfalls.size() == 6, "two rivers across the valley and the main river along it, each pouring out of the mountains at both ends")
	check(t.rivers.filter(func(r): return r.axis == "z" and not r.branch).size() == 1, "the main river runs the length of the valley")
	check(branches.size() >= 3 and t.lakes.filter(func(l): return l.fed).size() == branches.size(), "branches split off the main river, each into its own lake (%d)" % branches.size())
	var fed_ok := true
	for i in t.rivers.size():
		var r: Dictionary = t.rivers[i]
		if r.branch:
			var line := t.river_line(i)
			var far_end: Vector2 = line[0] if line[0].distance_to(r.from) > line[line.size() - 1].distance_to(r.from) else line[line.size() - 1]
			var mid: Vector2 = line[line.size() / 2]
			fed_ok = fed_ok and t.height(mid.x, mid.y) < ValleyTerrain.WATER_Y and t.lakes.any(func(l): return l.fed and l.pos.distance_to(far_end) < 10.0)
	check(fed_ok, "every branch is deep water and ends in its lake")
	check(t.bridges.size() >= 12, "bridges over every river (%d)" % t.bridges.size())
	check(t.lakes.filter(func(l): return not l.fed).size() >= 5 and t.lakes.filter(func(l): return l.deep).size() == ValleyTerrain.DEEP_LAKES, "more lakes, some of them deep (%d)" % t.lakes.size())
	check(t.hamlets.size() >= 5 and v.hamlets.size() == t.hamlets.size(), "hamlets along the water (%d)" % t.hamlets.size())
	var dry := t.hamlets.all(func(h): return t.water_surface(h.pos.x, h.pos.y) == -INF and absf(t.height(h.pos.x, h.pos.y) - t.height(h.pos.x + 10.0, h.pos.y)) < 0.05)
	var near_water := t.hamlets.all(func(h): return t.water_surface(h.pos.x + h.to_water.x * 120.0, h.pos.y + h.to_water.y * 120.0) != -INF or t.height(h.pos.x + h.to_water.x * 80.0, h.pos.y + h.to_water.y * 80.0) < ValleyTerrain.WATER_Y)
	check(dry and near_water, "hamlets stand on dry, level ground by the water (dry %s, by water %s)" % [dry, near_water])
	check(v.hamlets.any(func(h): return not h.villagers.is_empty()), "hamlet folk live there")
	var b: Dictionary = t.bridges[1]
	var mid: Vector2 = (b.a + b.b) * 0.5
	check(t.height(mid.x, mid.y) < ValleyTerrain.WATER_Y - 2.0 and t.water_surface(mid.x, mid.y) == ValleyTerrain.WATER_Y, "rivers are deep water")
	check(t.water_surface(b.a.x, b.a.y) == -INF and t.water_surface(b.b.x, b.b.y) == -INF, "bridges start and end on dry land")
	var r: Dictionary = t.bridges.filter(func(x): return t.rivers[x.river].rapids)[0]
	var rapids_mid: Vector2 = (r.a + r.b) * 0.5
	check(t.current_push(rapids_mid.x, rapids_mid.y, "dwarf") != Vector2.ZERO and t.current_push(rapids_mid.x, rapids_mid.y, "frog") == Vector2.ZERO, "the rapids push back everyone but the Frogfolk")
	check(t.current_push(mid.x, mid.y, "dwarf") == Vector2.ZERO, "anyone can swim the other river")
	# Swim the open river.
	p.god_mode = true
	p.global_position = Vector3(mid.x + 12.0, ValleyTerrain.WATER_Y - 1.0, mid.y)
	var s := _scripted()
	await _frames(60)
	check(p.swimming and absf(p.global_position.y - (ValleyTerrain.WATER_Y - Player.SWIM_FLOAT)) < 0.6, "in deep water you swim at the surface")
	s.press("light")
	await _frames(2)
	check(p.state == Player.State.FREE, "no attacking while swimming")
	# Try to swim the rapids as a dwarf: the current pushes you back.
	var side := 1.0
	var center_z: float = t.river_center(r.river, rapids_mid.x + 15.0)  # the river bends: measure from its middle here
	var start := Vector3(rapids_mid.x + 15.0, ValleyTerrain.WATER_Y - 1.0, center_z + side * 4.0)
	p.global_position = start
	var blocked := [false]
	var on_block := func(): blocked[0] = true
	p.water_blocked.connect(on_block)
	s.aim_yaw = 0.0 if side > 0.0 else PI  # swim across, toward the far bank
	s.hold({"move": Vector2(0, 1)}, 120)
	await _frames(120)
	check(blocked[0] and (p.global_position.z - center_z) * side > 4.0, "the rapids drive a dwarf back to the bank it came from (warned %s, %.1f m from the middle)" % [blocked[0], (p.global_position.z - center_z) * side])
	p.water_blocked.disconnect(on_block)
	# Walk a bridge from end to end.
	var a3 := Vector3(b.a.x, t.height(b.a.x, b.a.y) + 1.5, b.a.y)
	var b3 := Vector3(b.b.x, t.height(b.b.x, b.b.y) + 1.5, b.b.y)
	p.global_position = a3
	p.velocity = Vector3.ZERO
	await _frames(20)
	var dir := b3 - a3
	s.aim_yaw = atan2(-dir.x, -dir.z)
	var wet := false
	var closest := INF
	var frames := int(b.a.distance_to(b.b) / 8.25 * 60.0 * 1.4) + 120  # long bridges since the gentler banks
	s.hold({"move": Vector2(0, 1), "sprint": true}, frames)
	for i in frames:
		await get_tree().physics_frame
		wet = wet or p.swimming
		closest = minf(closest, Vector2(p.global_position.x, p.global_position.z).distance_to(b.b))
	check(not wet and closest < 4.0, "you can walk across a bridge without getting wet (wet %s, %.0f m short, bridge %.0f m)" % [wet, closest, b.a.distance_to(b.b)])


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


## Every race starts its run in its own home region (Races home_region), and Count
## Fuckula's tribe takes the region farthest from it.
func test_home_biomes() -> void:
	var wrong: Array = []
	for r in GameData.rows("races"):
		var s := Run.start_new(r.race_id, GameData.text(r, "starting_gods").split(",")[0].strip_edges(), 99, 1.0)
		var want := GameData.text(r, "home_region")
		if s.flags.home_region != want or s.regions[want].tribe != r.race_id:
			wrong.append("%s in %s" % [r.race_id, s.flags.home_region])
		if ValleyTerrain.region_center(want).distance_to(_sheet_center(ValleyLayout.south())) > 1.0:
			wrong.append("%s: home not at the south end" % r.race_id)
		if ValleyTerrain.region_center(s.evil.territories[0]).distance_to(_sheet_center(ValleyLayout.north())) > 1.0 or s.evil.territories[0] == want:
			wrong.append("%s: evil tribe in %s" % [r.race_id, s.evil.territories[0]])
		var map := ValleyGenerator.neighbors()
		for region in map:
			for n in map[region]:
				if not region in map[n]:
					wrong.append("%s: %s-%s border is one-way" % [r.race_id, region, n])
	check(wrong.is_empty(), "every race starts in its home biome at the south end, the evil tribe at the north end %s" % str(wrong))


func _sheet_center(region: String) -> Vector2:
	var row := GameData.row("valley_regions", region)
	return Vector2(GameData.num(row, "map_x"), GameData.num(row, "map_z")) * ValleyTerrain.SCALE


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


func test_race_carousel() -> void:
	var was_active := Run.active
	var last: Dictionary = Run.last_result
	Run.active = false
	Run.last_result = {}  # no end-of-run sheet over the screen
	var screen = load("res://scenes/run_director.tscn").instantiate()
	add_child(screen)
	await _frames(2)
	var preview: RacePreview = screen._preview
	var ring: Array = preview.races
	check(ring.size() >= 2 and not ring.any(func(r): return r in GameData.START_HIDDEN_RACES), "the carousel shows only the playable races (%s)" % ", ".join(ring))
	var start: int = ring.find(screen._race)
	check(screen._race == "dwarf" and not screen._begin.disabled, "the dwarf is chosen and can start a run")
	check(preview.locked == ring.filter(func(r): return not r in GameData.PLAYABLE_RACES), "every other race in the ring is locked (%s)" % ", ".join(preview.locked))
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	screen._input(key)
	await _frames(1)
	var next: String = ring[(start + 1) % ring.size()]
	check(screen._race == next and preview.person != null and preview.person.model != null, "the right arrow brings the next race to the front (%s)" % next)
	check(is_equal_approx(preview._ring_target, -TAU * ring.find(next) / ring.size()), "and the ring turns to it")
	if next in preview.locked:
		var meshes: Array = preview.person.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty() and meshes.all(func(m): return m.material_override != null), "a locked race shows blacked out")
		screen._start_run()
		check(screen._begin.disabled and not Run.active, "and can't start a run")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(1, 1)
	preview._gui_input(click)
	await _frames(1)
	check(screen._race == ring[start], "clicking the left half turns back")
	for i in ring.size():
		screen.turn(-1)
	check(screen._race == ring[start], "a full turn comes round to the same race")
	screen.free()
	Run.active = was_active
	Run.last_result = last


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
	# A menu pauses the fight: its time isn't fight time in the playtest numbers.
	Playtest.fight_started("audit")
	get_tree().paused = true
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().paused = false
	await _frames(6)
	Playtest.fight_ended("audit", true)
	check(Playtest.fights.back().seconds < 0.25, "a paused menu doesn't count as fight time (%.2f s)" % Playtest.fights.back().seconds)
	# Two gift menus left open both come back after a reload, not just the last one.
	var v: Valley = await _valley(81)
	v.events._offer_gift(Run.state.god_id)
	v.events._offer_gift(Run.state.god_id)
	check(v.events.pending_gifts().size() == 2, "both open gifts are saved")
	v.hud._pick(0)
	await _frames(1)
	check(v.events.pending_gifts().size() == 1 and v.hud._offer_kind == "event_gift", "choosing one keeps the other")
	v.hud._pick(0)
	await _frames(1)
	check(not Run.state.flags.has("pending_gift"), "and none is left once both are chosen")
	# A region that falls while you're far away: its new sentries sleep like the village.
	var far: Village = v.villages.values().filter(func(x): return not x.is_home)[0]
	far.update_dormant(far.global_position + Vector3(0, 0, Village.AWAKE_RANGE * 3.0), false)
	far.corrupt()
	check(not far.guards.is_empty() and far.guards.all(func(g): return g.process_mode == Node.PROCESS_MODE_DISABLED),
		"sentries of a far fallen village sleep (%d of them)" % far.guards.size())


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
	# Asking a sleeping or awake unit to stay so changes nothing: a villager hiding in a house stays hidden.
	var d: CrowdDirector = _arena.director
	var count := d.enemies.size()
	ally.visible = false
	ally.set_dormant(false)
	check(d.enemies.size() == count and not ally.visible, "waking an awake unit leaves it be (hidden stays hidden)")
	ally.set_dormant(true)
	ally.set_dormant(true)
	check(d.enemies.size() == count - 1, "and sleeping twice unregisters once")
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
	var v: Valley = await _valley(83)
	# A village whose roads come in out of order around the ring: its walls go round once, roads stay open.
	var c := Vector2(v.player.global_position.x, v.player.global_position.z) + Vector2(400, 0)
	var saved: Array = v.terrain.roads
	v.terrain.roads = []
	for a in [0.2, 4.0, 1.9]:
		v.terrain.roads.append({"line": PackedVector2Array([c, c + Vector2.from_angle(a) * 100.0])})
	var root := v.world.build_village(Vector3(c.x, v.terrain.height(c.x, c.y), c.y), false, "Audit")
	v.terrain.roads = saved
	var walls: Array = root.get_children().filter(func(n): return n is Node3D and absf((n as Node3D).position.length() - ValleyWorld.WALL_RING) < 1.0)
	check(walls.size() < 24, "walls go round the village once (%d pieces)" % walls.size())
	root.queue_free()
	# Your mount beside you has the riding health (half the sheet's): whole, it doesn't look hurt.
	var m: Mount = v.player.mount
	if m.has_mount() and m.companion == null:
		m._call_companion()
	if m.companion != null:
		check(is_equal_approx(m.companion.health.max_hp, m.max_hp), "your walking mount's health is the mount's (%.0f / %.0f)" % [m.companion.health.max_hp, m.max_hp])
	# Side events keep who they are after a tribe falls: a ritual you broke can't come back as new.
	var before := {}
	for ev in v.events.events:
		before[ev.id] = ev.title
	var tribe: String = v.villages.keys().filter(func(r): return not v.villages[r].is_home and Run.state.tribes.get(r, {}).get("status", "") != "corrupted")[0]
	Run.state.tribes[tribe]["status"] = "corrupted"
	var again := WorldEvents.new()
	again.valley = v
	v.add_child(again)
	var same := 0
	var moved: Array = []
	for ev in again.events:
		if before.has(ev.id):
			same += 1
			if before[ev.id] != ev.title:
				moved.append("%s: %s -> %s" % [ev.id, before[ev.id], ev.title])
	check(same > 10 and moved.is_empty(), "events keep their ids after a tribe falls (%d same, moved: %s)" % [same, moved])
	check(not again.events.any(func(ev): return ev.race == tribe and ev.kind in ["ritual", "caravan"]), "and the fallen tribe holds no rite or caravan")
	for ev in again.events:
		again._free(ev)
	again.queue_free()



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
		p.equip(w, "staff")
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
	p.equip("warhammer", "staff")
	p._use_sidearm(true)
	var shot: Projectile = p.fire_projectile(p.facing, 30.0, 5.0, DamageInfo.Kind.LIGHT, 0, [], true)
	check(shot != null and is_equal_approx(shot.template.hitstop, t.hitstop_heavy) and shot.template.shake > 0.0, "a spell bolt freezes and shakes like a heavy blow")
	check(is_equal_approx(t.launch_bolt_scale, 1.0), "and launches as hard")
	p._use_sidearm(false)


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
	check(not p._can_grab(), "no grab with the bow or staff out")
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
	await hook.call(foe)
	check(p.state == Player.State.CHAIN and p.chain.mode == Chain.Mode.HOOKED and foe.held_by == p, "a held light attack hooks a minion 8 m away")
	var links: int = p.chain._line.multimesh.visible_instance_count if p.chain._line != null else 0
	check(p.chain._line != null and p.chain._line.visible and links >= 30, "you see the chain: %d links from hand to hook" % links)
	s.hold({"light_held": true, "wheel_back": true}, 1)
	s.hold({"light_held": true}, 40)
	await _frames(41)
	check(p.state == Player.State.GRAB and p.grabber.held == foe, "the wheel reels it into your hand (state %d)" % p.state)
	s.hold({}, 2)
	await _frames(3)
	foe.queue_free()  # out of the way: a minion at your feet would be grabbed by hand next
	await _frames(40)
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
	# A big one pulls you in for a drop kick.
	var ogre: Enemy = _cluster(1, 8.0, "human_hired_ogre")[0]
	check(Chain.pulls_you(ogre), "an ogre is too big to hook")
	var start := p.global_position
	var ogre_hp := ogre.health.hp
	await hook.call(ogre)
	await _frames(60)
	check(p.global_position.distance_to(start) > 3.0, "the chain pulls you to it (%.1f m)" % p.global_position.distance_to(start))
	check(ogre.health.hp < ogre_hp, "and you land a drop kick")
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
	var crate_path := ValleyWorld.VILLAGE + "crate.glb"
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


## The valley scatters loose boulders and branches around you, the same ones every time.
func test_item_field() -> void:
	Run.start_new("dwarf", "forge_god", 91, 1.0)
	var v: Valley = await _valley(91)
	check(v.items != null, "the valley has an item field")
	v.items.update()
	var n: int = v.items.count()
	check(n > 0, "loose items lie around you (%d)" % n)
	var kinds := {}
	for it in get_tree().get_nodes_in_group("throwables"):
		kinds[it.kind] = true
	check(kinds.has("boulder") or kinds.has("branch"), "boulders or branches: %s" % str(kinds.keys()))
	var key: Vector2i = v.items._items.keys()[0]
	var first: Variant = v.items._items[key]
	var again: Throwable = v.items._roll(key)
	check(first == null or (again != null and again.kind == first.kind and again.global_position.distance_to(first.global_position) < 0.01), "a square holds the same item every time")
	if again != null:
		again.queue_free()


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
