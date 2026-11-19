extends Node
## The fight in progress: who you are (race, weapon, god), your godly gifts and level
## (Run.state). Scenes read Run.state.

var state: RunState
var active := false


## Starts a fresh fight state. weapon_id "" = the race's first weapon option.
func start_new(race_id: String, god_id: String, seed_value := -1, weapon_id := "", sidearm_id := "") -> RunState:
	RunRng.start_run(seed_value)
	state = RunState.new()
	state.seed = RunRng.seed_value
	state.race_id = race_id
	state.weapon_id = weapon_id if weapon_id != "" else GameData.weapon_options(race_id)[0]
	state.sidearm_id = sidearm_id if sidearm_id != "" else GameData.sidearm_for(state.weapon_id)
	state.god_id = god_id
	active = true
	return state


## Counts something for the end-of-fight recap: damage dealt and taken, kills. Kept in state.stats.
func note(stat: String, amount := 1.0) -> void:
	if not active or state == null:
		return
	state.stats[stat] = float(state.stats.get(stat, 0.0)) + amount


func end() -> void:
	active = false
