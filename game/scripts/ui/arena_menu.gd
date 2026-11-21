class_name ArenaMenu
extends CanvasLayer
## The endless arena's menus: the loadout (your element) before a fight, and the pause menu on Esc
## (resume, restart, change element, quit). Both pause the game. No weapon to pick: you start with
## your fists and the chain and find weapons in the arena (user, 2026-11-20).

signal loadout_chosen(god_id: String)

var arena: Arena
var _root: Control
var _panel: Control
var _mode := ""  ## "", "pause" or "loadout"
var _god := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_root = Control.new()
	_root.theme = UiStyle.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)


func is_open() -> bool:
	return _mode != ""


## Every element you can fight with: one god per element (gods not set aside).
static func elements() -> Array:
	return GameData.rows("gods").map(func(r): return r.god_id).filter(func(g): return not g in GameData.SHELVED_GODS)


func open_loadout(god: String) -> void:
	_god = god
	var box := _open("loadout", "Choose your element")
	var element_row := HFlowContainer.new()
	box.add_child(element_row)
	for g in elements():
		var row := GameData.god(g)
		_chip(element_row, g, "%s\n%s" % [GameData.text(row, "element", g), GameData.text(row, "display_name")],
			GameData.text(row, "short_description"), func(): _god = g; _mark(element_row, g))
	_mark(element_row, _god)
	_button(box, "Fight!", func(): loadout_chosen.emit(_god))
	_button(box, "Tutorial", func(): Flow.practice_god = _god; EndlessArena.loadout_picked = true; open_tutorial())


func open_pause() -> void:
	var box := _open("pause", "Paused")
	_button(box, "Resume", close)
	_button(box, "Restart", func(): arena.restart())
	_button(box, "Tutorial", open_tutorial)
	_button(box, "Change element", func(): open_loadout(Flow.practice_god if Flow.practice_god != "" else Arena.START_GOD))
	_button(box, "Main menu", func(): get_tree().change_scene_to_file(StartMenu.SCENE))
	_button(box, "Quit game", func(): get_tree().quit())


## The tutorial scene (TutorialArena): every chain attack, the grab and hurl, weapons.
func open_tutorial() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TutorialArena.SCENE)


func close() -> void:
	_clear()
	_mode = ""
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("release_mouse"):
		return
	if _mode == "pause":
		close()
	elif _mode == "" and arena != null and not arena.player.is_dead():
		open_pause()
	else:
		return
	get_viewport().set_input_as_handled()


func _open(mode: String, title: String) -> VBoxContainer:
	_clear()
	_mode = mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	panel.custom_minimum_size = Vector2(640 if mode == "loadout" else 360, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var t := UiStyle.title(Label.new(), 28)
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	return box


func _clear() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UiStyle.GOLD)
	l.add_theme_font_size_override("font_size", 18)
	return l


func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _chip(parent: Node, value: String, text: String, tip: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(140, 60)
	b.set_meta("value", value)
	b.pressed.connect(action)
	parent.add_child(b)


## Highlights the chosen chip in a row.
func _mark(row: Node, value: String) -> void:
	for c in row.get_children():
		(c as Button).set_pressed_no_signal(c.get_meta("value") == value)
