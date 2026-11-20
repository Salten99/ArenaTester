extends Node
## Remembers the element picked in the arena menu across a scene reload, and sets the UI look.

## The god the arena starts with ("" = Arena's default).
var practice_god := ""


func _ready() -> void:
	get_tree().root.theme = UiStyle.theme()  # one look for every screen (UiStyle)
