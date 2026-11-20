class_name StartMenu
extends Control
## The start screen (user, 2026-11-20): Tutorial, Play (the endless waves) and Test (TestArena).

const SCENE := "res://scenes/start_menu.tscn"


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var t := UiStyle.title(Label.new(), 32)
	t.text = "Arena"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	for b in [["Tutorial", TutorialArena.SCENE], ["Play", TutorialArena.ENDLESS_SCENE], ["Test", TestArena.SCENE]]:
		var button := Button.new()
		button.text = b[0]
		button.custom_minimum_size = Vector2(0, 48)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(open.bind(b[1]))
		box.add_child(button)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(0, 40)
	quit.pressed.connect(get_tree().quit)
	box.add_child(quit)


func open(scene: String) -> void:
	EndlessArena.loadout_picked = false  # Play always asks for your element first
	get_tree().change_scene_to_file(scene)
