extends Node
## Battle length calibration (not part of the normal tests). An autopilot plays
## the player (Dwarf, warhammer, level 1, no godly gifts) and fights real enemies, to
## measure how much enemy health per second you and a friendly warrior clear.
## Those numbers go into combat_tuning.tres (battle_player_dps, battle_ally_dps);
## the battle planner sizes every fight from them and the sheet's target_minutes.
## Run: tools\battle_sim.bat  (takes a minute or two)
## Options after `--`: --seed=N (a different run seed, default 99), --mortal (the
## autopilot can die: reports whether a beginner survives and with how much health) and
## --only=<encounter_id> (skip the calibration, measure just that fight), e.g.
##   godot --headless --path game --fixed-fps 60 res://tests/battle_sim.tscn -- --seed=7 --only=ct_champion_duel

const ARENA := preload("res://scenes/main.tscn")

var _arena: Node3D
var _seed := 99
var _only := ""
var _taken := {}  ## mortal mode: damage the player took, by kind and enemy
var _mortal := false  ## --mortal: the autopilot can die (a beginner who rarely dodges)


## Plays the player: walk to the nearest enemy, combo it, slam crowds, dodge
## wind-ups now and then, use abilities on big groups.
class Autopilot:
	extends RefCounted
	var player: Player
	var frame := 0
	var rng := RandomNumberGenerator.new()

	func read() -> PlayerIntent:
		frame += 1
		var i := PlayerIntent.new()
		var near: Node3D = null
		var best := INF
		var crowd := 0
		var threat := false
		for e in player.get_tree().get_nodes_in_group("enemies"):
			var d: float = e.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				near = e
			if d < 4.0:
				crowd += 1
			if d < 2.8 and e.state == Enemy.State.WINDUP:
				threat = true
		if near == null:
			return i
		var to := near.global_position - player.global_position
		i.aim_yaw = atan2(-to.x, -to.z)
		if threat and rng.randf() < 0.04 and player.stamina > 40.0:
			i.dodge = true
			i.move = Vector2(1.0 if rng.randf() < 0.5 else -1.0, 0.0)
			return i
		if best > 3.0:
			i.move = Vector2(0.0, 1.0)
			i.sprint = best > 8.0
			return i
		if crowd >= 4 and frame % 600 < 2:
			i.signature = true
		elif crowd >= 6 and frame % 1800 < 2:
			i.ultimate = true
		elif crowd >= 3 and frame % 45 == 0:
			i.heavy = true
		elif frame % 9 == 0:
			i.light = true
		return i


func _ready() -> void:
	Meta.persist = false
	Playtest.persist = false
	SaveSystem.RUN_PATH = "user://sim_run_save.json"
	GameData.tuning.hitstop_enabled = false
	GameData.tuning.show_damage_numbers = false
	await get_tree().process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--only="):
			_only = arg.get_slice("=", 1)
		elif arg == "--mortal":
			_mortal = true
	if _only != "":
		Combat.hit_landed.connect(func(target, info, dealt):
			if _arena != null and target == _arena.player and dealt > 0.0:
				var who: String = info.source.unit_id if is_instance_valid(info.source) and info.source is Enemy else "?"
				var key := "%s %s" % [DamageInfo.Kind.keys()[info.kind], who]
				_taken[key] = float(_taken.get(key, 0.0)) + dealt)
		var friendlies: int = {"tm_raid_defense": 6, "ev_final_battle": 10}.get(_only, 0)
		var r: Array = await _full_battle(_only, friendlies)
		var target: float = GameData.num(GameData.row("encounters", _only), "target_minutes", 3.5) * 60.0
		var life := ("DIED after %.0f s" % r[0]) if r[5] else ("survived with %.0f%% health" % (r[4] * 100.0))
		print("SIM seed %d %s, %d warriors: %.0f s (target %.0f s), %d enemies in %d waves%s" % [_seed, _only, friendlies, r[0], target, r[2], r[3], ("   " + life) if _mortal else ""])
		if _mortal:
			var keys := _taken.keys()
			keys.sort_custom(func(a, b): return _taken[a] > _taken[b])
			print("SIM damage taken: " + ", ".join(keys.map(func(k): return "%s %.0f" % [k, _taken[k]])))
		get_tree().quit()
		return
	# 1) You alone in a planned 3-minute raid: how much enemy health per second you clear.
	var solo: Array = await _full_battle("tm_raid_defense", 0)
	var you: float = solo[1] / solo[0]
	# 2) The same with 6 warriors beside you: what each one adds.
	var team: Array = await _full_battle("tm_raid_defense", 6)
	var ally: float = maxf(0.0, (team[1] / team[0] - you) / pow(6.0, GameData.tuning.battle_ally_scaling))
	print("
=== Battle calibration (level 1, no godly_gifts, warhammer) ===")
	print("You alone clear %.1f enemy HP per second; warriors add %.1f x count^%.2f." % [you, ally, GameData.tuning.battle_ally_scaling])
	print("Suggested: battle_player_dps = %.1f, battle_ally_dps = %.1f (now %.1f / %.1f). Single runs are noisy:" % [you, ally, GameData.tuning.battle_player_dps, GameData.tuning.battle_ally_dps])
	print("run this 2-3 times and average before changing combat_tuning.tres.")
	print("
=== Check with the current tuning ===")
	# Each case: the encounter (its target time comes from the Encounters sheet), your warriors, a label.
	# Solo until the final battle (pivot, 2026-11-18): a raid has only the village's guards beside you.
	for case in [["tm_raid_defense", 6, "Befriend raid, 6 village guards"], ["tm_raid_defense", 0, "A fight alone"], ["ct_champion_duel", 0, "Champion's challenge, alone"],
			["ev_final_battle", 10, "Final battle, 10 warriors"]]:
		var r: Array = await _full_battle(case[0], case[1])
		var target: float = GameData.num(GameData.row("encounters", case[0]), "target_minutes", 3.5) * 60.0
		print("%s: %.0f s (target %.0f s), %d enemies in %d waves" % [case[2], r[0], target, r[2], r[3]])
	get_tree().quit()


func _new_arena() -> void:
	if _arena != null:
		_arena.queue_free()
		await get_tree().physics_frame
	_arena = ARENA.instantiate()
	_arena.auto_start = false
	_arena.run_seed = _seed
	add_child(_arena)
	for i in 90:
		await get_tree().physics_frame
	_arena.waves.wave_cleared.disconnect(_arena._on_wave_cleared)  # no practice godly gift offers
	Combat.killed.disconnect(_arena._on_killed)  # no XP: level-up choices would pause the game, and the measure is for level 1
	_arena.waves.spawn_radius = 20.0  # in the valley enemies come from 18-34 m on open ground; the arena's stands would trap them
	var pilot := Autopilot.new()
	pilot.player = _arena.player
	_arena.player.input_source = pilot
	_arena.player.god_mode = not _mortal


## A planned battle with `friendlies` warriors: [seconds, enemy HP, enemy count, waves].
func _full_battle(def: String, friendlies: int) -> Array:
	await _new_arena()
	var s: RunState = Run.state
	s.encounters["sim"] = {"def": def, "region": s.flags.home_region, "state": "available", "race": "elf", "god": ""}
	var plan := EncounterSystem.plan(s, "sim", friendlies)
	_arena.waves.boss = plan.boss
	for i in friendlies:
		_arena.waves.spawn(["dwarf_shieldbearer", "dwarf_thunder_crossbow", "dwarf_runepriest"][i % 3], _arena.player.global_position, Enemy.Team.FRIENDLY)
	_arena.waves.plan_waves = _arena._one_battle(plan.waves, plan.reserve)
	_arena.waves.overlap = GameData.tuning.wave_overlap
	_arena.waves.wave_cleared.connect(_next_wave)
	_arena.waves.start()
	var frames := 0
	while frames < 60 * 60 * 10:
		await get_tree().physics_frame
		frames += 1
		if _mortal and _arena.player.is_dead():
			break
		if not _arena.waves.running and _arena.waves.wave >= _arena.waves.total() - 1 and _arena.waves.alive() == 0:
			break
		if frames % 3600 == 0:
			print("  t=%ds  wave %d/%d  enemies %d  allies %d" % [frames / 60, _arena.waves.wave + 1, _arena.waves.total(), _arena.waves.alive(), get_tree().get_nodes_in_group("allies").size()])
	var count := 1 if plan.boss != "" else 0
	var hp := GameData.num(GameData.unit(plan.boss.get_slice("@", 0)), "hp", 0.0) * EncounterSystem.mini_boss_mult(plan.boss) if plan.boss != "" else 0.0
	for w in plan.waves + [plan.reserve]:
		count += w.size()
		for id in w:
			hp += GameData.num(GameData.unit(id.get_slice("@", 0)), "hp", 25.0)
	var health: HealthComponent = _arena.player.health
	return [frames / 60.0, hp, count, plan.waves.size(), health.hp / health.max_hp, _arena.player.is_dead()]


func _next_wave(index: int) -> void:
	if index + 1 < _arena.waves.total():
		get_tree().create_timer(GameData.tuning.time_between_waves).timeout.connect(_arena.waves.resume)
