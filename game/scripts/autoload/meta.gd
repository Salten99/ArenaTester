extends Node
## The profile: what carries over between sessions: the bestiary (codex). Saved to user://profile.json.

var data := {}
## Tests turn this off so they never touch the real profile.
var persist := true


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	data = SaveSystem.load_profile()
	if not data.get("codex") is Array:
		data["codex"] = []


func save() -> void:
	if persist:
		SaveSystem.save_profile(data)


## A creature goes in the bestiary (seen or killed). Saved at once.
func discover(unit_id: String) -> void:
	if unit_id == "" or GameData.row("barbarians_beasts", unit_id).is_empty() or ("creature:" + unit_id) in data.codex:
		return
	data.codex.append("creature:" + unit_id)
	save()
