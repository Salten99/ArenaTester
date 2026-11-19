class_name ControlsMenu
extends PanelContainer
## The key bindings screen: click an action, then press the key or mouse button
## you want for it (Esc cancels). Saved at once (Controls autoload). Opened from
## the start screen and the Esc pause menu; works while the game is paused.

signal closed

var _rows := {}  ## action -> its binding Button
var _waiting := ""  ## the action waiting for a key, or ""
var _note: Label


static func open(parent: Node) -> ControlsMenu:
	var m := ControlsMenu.new()
	parent.add_child(m)
	return m


func _ready() -> void:
	theme = UiStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var style := UiStyle.panel()
	style.set_content_margin_all(22)
	add_theme_stylebox_override("panel", style)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -290
	offset_right = 290
	offset_top = -330
	offset_bottom = 330
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_note = Label.new()
	_note.text = "Click an action, then press a key or mouse button."
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.modulate = Color(0.8, 0.8, 0.85)
	box.add_child(_note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	scroll.add_child(grid)
	for pair in Controls.REBINDABLE:
		var label := Label.new()
		label.text = pair[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var b := Button.new()
		b.custom_minimum_size = Vector2(220, 34)
		b.pressed.connect(_start_waiting.bind(pair[0]))
		grid.add_child(b)
		_rows[pair[0]] = b
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	box.add_child(bottom)
	for item in [["Reset to defaults", _on_reset], ["Done", _on_done]]:
		var b := Button.new()
		b.text = item[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 38
		b.pressed.connect(item[1])
		bottom.add_child(b)
	_refresh()


func _input(event: InputEvent) -> void:
	if _waiting == "":
		if event.is_action_pressed("release_mouse"):
			_on_done()
			get_viewport().set_input_as_handled()
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_waiting = ""  # Esc cancels (it stays the pause key)
		_note.text = "Click an action, then press a key or mouse button."
		_refresh()
		return
	var ev: InputEvent
	if event is InputEventKey:
		var k := InputEventKey.new()
		k.physical_keycode = (event as InputEventKey).physical_keycode
		ev = k
	else:
		var m := InputEventMouseButton.new()
		m.button_index = (event as InputEventMouseButton).button_index
		ev = m
	var stolen := Controls.rebind(_waiting, ev)
	_note.text = "Click an action, then press a key or mouse button."
	if stolen != "":
		_note.text = "%s was also on %s: that one is now unbound." % [Controls.event_text(ev), _label(stolen)]
	_waiting = ""
	_refresh()


func _start_waiting(action: String) -> void:
	_waiting = action
	_note.text = "Press a key or mouse button for %s (Esc cancels)." % _label(action)
	_refresh()


func _refresh() -> void:
	for action in _rows:
		(_rows[action] as Button).text = "..." if action == _waiting else Controls.binding_text(action)


func _on_reset() -> void:
	Controls.reset_to_defaults()
	_waiting = ""
	_refresh()


func _on_done() -> void:
	closed.emit()
	queue_free()


static func _label(action: String) -> String:
	for pair in Controls.REBINDABLE:
		if pair[0] == action:
			return pair[1]
	return action
