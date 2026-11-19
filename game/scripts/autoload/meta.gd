extends Node
## The meta profile: what carries over between runs (DECISIONS 22): unlocked
## races, gods, starting options and the lore codex, plus lifetime stats.
## Saved to user://profile.json.
##
## Every race is available from the start (2026-10-22) and gods unlock by being met;
## there are no other unlock rules (Council VIII: no unlocks yet).

var data := {}
## Tests turn this off so they never touch the real profile.
var persist := true


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	data = SaveSystem.load_profile()
	for key in ["races", "gods", "options", "buildings", "codex"]:
		if not data.has(key):
			data[key] = []
	for key in ["runs", "wins", "deaths"]:
		data[key] = int(data.get(key, 0))
	# Everything marked "unlocked at start" in the sheet is always available.
	for r in GameData.rows("races"):
		if GameData.text(r, "unlocked_at_start") == "Yes" and not r.race_id in data.races:
			data.races.append(r.race_id)
	for g in GameData.rows("gods"):
		if GameData.text(g, "unlocked_at_start") == "Yes" and not g.god_id in data.gods:
			data.gods.append(g.god_id)


func save() -> void:
	if persist:
		SaveSystem.save_profile(data)


func is_unlocked(kind: String, id: String) -> bool:
	return id in data.get(kind, [])


func unlock(kind: String, id: String) -> bool:
	if id == "" or id in data[kind]:
		return false
	data[kind].append(id)
	return true


## A creature goes in the bestiary (seen, killed or looked at through the spyglass). Saved at once.
func discover(unit_id: String) -> void:
	if unit_id == "" or GameData.row("barbarians_beasts", unit_id).is_empty() or ("creature:" + unit_id) in data.codex:
		return
	data.codex.append("creature:" + unit_id)
	if not Run.practice:
		save()


func add_codex(entry: String) -> void:
	if not entry in data.codex:
		data.codex.append(entry)


## Called when a run ends. Returns everything newly unlocked: [{kind, id}].
func record_run(state: RunState, victory: bool) -> Array:
	var unlocked: Array = []
	data.runs += 1
	if victory:
		data.wins += 1
	else:
		data.deaths += 1
	# Meeting a god unlocks it for future runs; winning frees the captive god too.
	var gods: Array = state.gods_met.duplicate()
	if victory and state.evil.get("captive_god", "") != "":
		gods.append(state.evil.captive_god)
	for g in gods:
		if unlock("gods", g):
			unlocked.append({"kind": "gods", "id": g})
		add_codex("god:" + g)
	for race in state.tribes:
		add_codex("race:" + race)
	save()
	return unlocked
