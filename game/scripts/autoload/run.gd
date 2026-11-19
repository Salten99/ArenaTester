extends Node
## The run in progress: starts and ends runs, ticks the valley clock (evil tribe),
## and handles saving. Scenes (arena, valley, home base) read
## Run.state and call into the systems in scripts/world and scripts/progression.
##
## Game flow:  menu -> race/god select -> Run.start_new() -> valley (travel,
## encounters, home base) <-> encounter fights -> final battle -> Run.end()
## -> meta screen (unlocks) -> menu.

signal run_started
signal run_ended(victory: bool, unlocked: Array)
## The evil tribe attacked a region with a living tribe: "Border Defense" is available.
signal border_attack(region: String, tribe: String)
## A region fell to the evil tribe.
signal region_fell(region: String)
## A god was revealed: show its godly gifts.
signal god_offered(god_id: String)

var state: RunState
var active := false
## True while a fight scene is running. The evil tribe's clock only
## move in the valley, so a border-defense window can't run out mid-fight.
var in_fight := false
## The Practice arena's throwaway run: it never touches the saved run or the profile.
var practice := false
## The player node of the current fight (for saving health). Set by fight scenes.
var player: Node
## How the last run ended: {victory, unlocked}. Shown on the run screen.
var last_result := {}


## Starts a fresh run. length_scale 1.0 = full length; smaller = shorter test runs.
## weapon_id "" = the race's first weapon option.
func start_new(race_id: String, god_id: String, seed_value := -1, length_scale := 1.0, weapon_id := "", sidearm_id := "") -> RunState:
	practice = false
	RunRng.start_run(seed_value)
	state = RunState.new()
	state.seed = RunRng.seed_value
	state.length_scale = length_scale
	state.race_id = race_id
	state.weapon_id = weapon_id if weapon_id != "" else GameData.weapon_options(race_id)[0]
	state.sidearm_id = sidearm_id if sidearm_id != "" else GameData.sidearm_for(state.weapon_id)
	state.god_id = god_id
	state.gods_met = [god_id]
	ValleyGenerator.generate(state)
	state.add_log("run_started", {"race": race_id, "weapon": state.weapon_id, "sidearm": state.sidearm_id, "god": god_id})
	active = true
	run_started.emit()
	return state


## Continues a saved run. False if there isn't one.
func resume() -> bool:
	var loaded := SaveSystem.load_run()
	if loaded == null:
		return false
	practice = false
	state = loaded
	if GameData.weapon(state.weapon_id).is_empty():  # taken off the Weapons sheet since this save
		state.weapon_id = GameData.weapon_options(state.race_id)[0]
	if GameData.weapon(state.sidearm_id).is_empty():
		state.sidearm_id = GameData.sidearms()[0]
	ValleyLayout.use(state)
	RunRng.start_run(state.seed)
	if state.rng_state != 0:
		RunRng.rng.state = state.rng_state  # continue the dice where they were, not from the start
	active = true
	run_started.emit()
	return true


## Called by the game scene every physics frame while the run is live.
func tick(delta: float) -> void:
	if not active:
		return
	state.elapsed += delta
	if in_fight:
		return
	var r := EvilTribe.tick(state, delta)
	match r.get("event", ""):
		"attack":
			state.add_log("border_attack", {"region": r.region, "tribe": r.tribe})
			border_attack.emit(r.region, r.tribe)
			checkpoint("border_attack")
		"fell":
			state.add_log("region_fell", {"region": r.region})
			region_fell.emit(r.region)
			checkpoint("region_fell")


## The gods that answer your call after the opening (user, 2026-11-16): up to 3, your race's
## patron (the run's god so far) among them.
func god_offer() -> Array:
	var others: Array = GameData.rows("gods").map(func(g): return g.god_id).filter(
		func(g): return g != state.god_id and Meta.is_unlocked("gods", g))
	var rng := RandomNumberGenerator.new()
	rng.seed = state.seed + 17  # its own dice: the same three come back if you quit and return
	others.sort()  # the sheet's order shouldn't change who answers
	ValleyGenerator._shuffle(others, rng)
	return [state.god_id] + others.slice(0, 2)


## You pledge to a god after the opening. The valley was generated around your race's patron, so
## the chosen god swaps places with it everywhere the valley holds a god.
func choose_god(god: String) -> void:
	var old := state.god_id
	if god == "" or god == old:
		return
	var swap := func(g): return god if g == old else (old if g == god else g)
	state.god_id = god
	state.gods_met = state.gods_met.map(swap)
	state.wild_gods = state.wild_gods.map(swap)
	state.evil["captive_god"] = swap.call(state.evil.get("captive_god", ""))
	for t in state.tribes.values():
		t["god"] = swap.call(t.get("god", ""))
	for e in state.encounters.values():
		e["god"] = swap.call(e.get("god", ""))
	state.add_log("god_chosen", {"god": god, "instead_of": old})


## Finishes an encounter; offers its god if it revealed one.
func finish_encounter(encounter_id: String, won: bool) -> void:
	if won:
		note("encounters_won")
	var god := EncounterSystem.finish(state, encounter_id, won)
	state.add_log("encounter", {"id": encounter_id, "won": won})
	state.pending_god = god  # saved with the checkpoint below: quit on this screen and it's offered again
	if encounter_id == "final_battle" and won:
		end(true)
		return
	checkpoint("after_" + encounter_id)
	if god != "":
		god_offered.emit(god)


## Counts something for the end-of-run recap (user, 2026-11-05): damage dealt and taken, kills,
## distance, side quests, caves and towers, strongholds, encounters won. Kept in flags.stats.
func note(stat: String, amount := 1.0) -> void:
	if not active or practice or state == null:
		return
	var stats: Dictionary = state.flags.get("stats", {})
	stats[stat] = float(stats.get(stat, 0.0)) + amount
	state.flags["stats"] = stats


## Saves for crash protection (checkpoints) or when quitting.
func checkpoint(label: String) -> void:
	if not active or practice:
		return
	if player != null and is_instance_valid(player):
		state.hp = player.health.hp
	state.rng_state = RunRng.rng.state
	SaveSystem.save_run(state, label)


## Closing the game window saves the run (DECISIONS 5b).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		checkpoint("quit")


## "Abandon this run" (Esc menu). A custom battle is a throwaway run: the save on disk is your
## real run's, so it stays (2026-11-11: abandoning a custom battle deleted it).
func abandon() -> void:
	if not practice:
		SaveSystem.delete_run()  # even if the run had already ended, no save of it is left to continue
	end(false, false)


## `record`: false when the player abandons the run (user, 2026-11-10): nothing from it is kept,
## not the save and not the profile (unlocks, lifetime stats, codex). The bestiary keeps the creatures
## you met (Meta.discover saves them at once): that's what you've seen, ever (user, 2026-11-11).
func end(victory: bool, record := true) -> Array:
	if not active:
		return []
	active = false
	if practice:
		last_result = {"victory": victory, "unlocked": []}
		run_ended.emit(victory, [])
		return []
	SaveSystem.delete_run()
	var unlocked: Array = Meta.record_run(state, victory) if record else []
	last_result = {"victory": victory, "unlocked": unlocked, "stats": state.flags.get("stats", {}).duplicate(),
		"level": state.level, "gifts": state.godly_gifts.size(), "race": state.race_id, "god": state.god_id, "fresh": true}
	run_ended.emit(victory, unlocked)
	return unlocked
