extends Node
## Remembers the loadout picked in the arena menu across a scene reload, and sets the UI look.

## The god and weapon the arena starts with ("" = Arena's defaults).
var practice_god := ""
var practice_weapon := ""


func _ready() -> void:
	get_tree().root.theme = UiStyle.theme()  # one look for every screen (UiStyle)
