extends Node
## The fight in progress: who you are (race, weapon, god) (Run.state). Scenes read Run.state.

var state: RunState
var active := false


## Starts a fresh fight state. weapon_id "" = bare fists (user, 2026-11-20: weapons are found in the arena).
func start_new(race_id: String, god_id: String, seed_value := -1, weapon_id := "") -> RunState:
	RunRng.start_run(seed_value)
	state = RunState.new()
	state.seed = RunRng.seed_value
	state.race_id = race_id
	state.weapon_id = weapon_id if weapon_id != "" else GameData.FISTS
	state.god_id = god_id
	active = true
	return state


func end() -> void:
	active = false
