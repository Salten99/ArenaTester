extends Node
## The profile: what carries over between sessions: unlocked races and gods, the bestiary
## (codex) and settings. Saved to user://profile.json.

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


## A creature goes in the bestiary (seen or killed). Saved at once.
func discover(unit_id: String) -> void:
	if unit_id == "" or GameData.row("barbarians_beasts", unit_id).is_empty() or ("creature:" + unit_id) in data.codex:
		return
	data.codex.append("creature:" + unit_id)
