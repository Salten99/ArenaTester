class_name ValleyHud
extends CanvasLayer
## The valley's extra on-screen info, on top of the fight HUD: the region you're
## in, Count Fuckula's clock, the "press F" prompt, the map (M) and the pause
## menu (Esc: resume, controls, save and quit, abandon).

var valley: Node  ## the Valley scene
var _region: Label
var _region_left := 0.0
var _clock: Label
var _prompt: Label
var _map: ValleyMap
var _menu: PanelContainer


const GOAL := "Goal: beat Count Fuckula's army at the far end of the valley\nTribes along the way give you allies and godly gifts  ·  M: map"
var _goal: Label


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UiStyle.theme()  # a CanvasLayer cuts off the window's theme: give it here
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_region = UiStyle.title(_label(root, 34, Vector2(0.5, 0.0), Rect2(-400, 72, 800, 90)), 34)
	var compass := Compass.new()
	compass.valley = valley
	root.add_child(compass)
	_clock = _label(root, 15, Vector2(1.0, 0.0), Rect2(-420, 210, 400, 60))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_goal = _label(root, 15, Vector2(1.0, 0.0), Rect2(-520, 158, 500, 50))
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_goal.text = GOAL
	_prompt = _label(root, 22, Vector2(0.5, 1.0), Rect2(-400, -170, 800, 40))
	_map = ValleyMap.new()
	_map.valley = valley
	_map.visible = false
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_map)
	_build_menu(root)


func _process(delta: float) -> void:
	valley.hud.visible = not _map.visible and not valley.cinematic  # the map has the screen to itself; a clip too
	visible = not valley.cinematic
	_clock.visible = not _map.visible
	_goal.visible = Run.active and valley.battle.is_empty() and not _map.visible
	if not Run.active or not valley.battle.is_empty():  # a custom battle has no run clock
		_clock.text = ""
		return
	_region_left -= delta
	_region.modulate.a = 0.0 if valley.hud.is_choosing() else clampf(_region_left, 0.0, 1.0)
	var e: Dictionary = Run.state.evil
	var lines := ["Count Fuckula attacks a region in %s" % _time(float(e.get("next_push_in", 0.0)))]
	var pending: Dictionary = e.get("pending", {})
	if not pending.is_empty():
		lines.append("%s is UNDER ATTACK: Border Defense in %s!" % [_region_name(pending.region), _time(float(pending.time_left))])
	if Run.in_fight:
		lines[0] += "  (paused while you fight)"
	_clock.text = "\n".join(lines)
	_clock.modulate = Color(1.0, 0.55, 0.3) if not pending.is_empty() else UiStyle.TEXT


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("valley_map") and not _menu.visible:
		_map.visible = not _map.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("release_mouse"):
		if _map.visible:
			_map.visible = false
		elif not valley.hud.is_choosing():
			_set_menu(not _menu.visible)
		get_viewport().set_input_as_handled()


## Shows the region's name for a few seconds when you walk into it.
func show_region(text: String) -> void:
	_region.text = text
	_region_left = 4.0


func set_prompt(text: String) -> void:
	_prompt.text = text


# ---------------------------------------------------------------- pause menu

func _build_menu(root: Control) -> void:
	_menu = PanelContainer.new()
	_menu.visible = false
	_menu.add_theme_stylebox_override("panel", UiStyle.panel())
	root.add_child(_menu)
	_menu.anchor_left = 0.5
	_menu.anchor_right = 0.5
	_menu.anchor_top = 0.5
	_menu.anchor_bottom = 0.5
	_menu.offset_left = -180
	_menu.offset_right = 180
	_menu.offset_top = -180
	_menu.offset_bottom = 180
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_menu.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.title(title, 28)
	box.add_child(title)
	for item in [["Resume", _on_resume], ["War chest", _open_war_chest], ["Bestiary", _on_bestiary], ["Controls", _on_controls], ["Save and quit to the start screen", _on_save_quit],
			["Abandon this run", _on_abandon]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size.y = 40
		b.pressed.connect(item[1])
		box.add_child(b)


func _set_menu(on: bool) -> void:
	if _chest != null:  # Esc from the war chest closes it too
		_chest.queue_free()
		_chest = null
	_menu.visible = on
	get_tree().paused = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _on_resume() -> void:
	_set_menu(false)


func _on_bestiary() -> void:
	_menu.visible = false
	var book := Bestiary.open(_menu.get_parent())
	book.closed.connect(func(): _menu.visible = true)


func _on_controls() -> void:
	_menu.visible = false
	var controls := ControlsMenu.open(_menu.get_parent())
	controls.closed.connect(func(): _menu.visible = true)


# ---------------------------------------------------------------- the war chest

var _chest: PanelContainer


## Spend supplies on help for the final battle (WarChest), from the pause menu.
func _open_war_chest() -> void:
	if _chest != null:
		_chest.queue_free()
	_menu.visible = false
	_chest = PanelContainer.new()
	_chest.add_theme_stylebox_override("panel", UiStyle.panel())
	_menu.get_parent().add_child(_chest)
	_chest.anchor_left = 0.5
	_chest.anchor_right = 0.5
	_chest.anchor_top = 0.5
	_chest.anchor_bottom = 0.5
	_chest.offset_left = -330
	_chest.offset_right = 330
	_chest.offset_top = -230
	_chest.offset_bottom = 230
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_chest.add_child(box)
	var title := Label.new()
	title.text = "War chest: %d supplies" % Run.state.supplies
	UiStyle.title(title, 24)
	box.add_child(title)
	var note := Label.new()
	note.text = "What you buy here waits for the final battle against Count Fuckula."
	box.add_child(note)
	for id in WarChest.ITEMS:
		var item: Dictionary = WarChest.ITEMS[id]
		var row := HBoxContainer.new()
		box.add_child(row)
		var text := Label.new()
		text.text = "%s  (%d of %d)\n%s" % [item.name, WarChest.owned(Run.state, id), item.max, item.text]
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var buy := Button.new()
		buy.text = "Buy: %d" % item.cost
		buy.custom_minimum_size = Vector2(110, 40)
		buy.disabled = Run.state.supplies < int(item.cost) or WarChest.owned(Run.state, id) >= int(item.max)
		buy.pressed.connect(func():
			if WarChest.buy(Run.state, id):
				Run.checkpoint("war_chest")
			_open_war_chest())
		row.add_child(buy)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size.y = 40
	back.pressed.connect(func():
		_chest.queue_free()
		_chest = null
		_menu.visible = true)
	box.add_child(back)


func _on_save_quit() -> void:
	valley.remember_position()
	Run.checkpoint("menu")
	Run.active = false
	Flow.goto_director()


func _on_abandon() -> void:
	Run.abandon()
	Flow.goto_director()


# ---------------------------------------------------------------- helpers

func _label(root: Control, size: int, anchor: Vector2, rect: Rect2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	l.anchor_left = anchor.x
	l.anchor_right = anchor.x
	l.anchor_top = anchor.y
	l.anchor_bottom = anchor.y
	l.offset_left = rect.position.x
	l.offset_top = rect.position.y
	l.offset_right = rect.position.x + rect.size.x
	l.offset_bottom = rect.position.y + rect.size.y
	return l


static func _time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


static func _region_name(id: String) -> String:
	return GameData.text(GameData.row("valley_regions", id), "display_name", id)
