extends Node
## Registers the input actions in code so the bindings live in one readable list.
## Players change them in the Controls menu (ControlsMenu: start screen and Esc
## pause menu); their choices are saved to user://controls.cfg and win over these.

const KEYS := {
	"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
	"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "dodge": [KEY_CTRL],
	"ability_signature": [KEY_Q], "ability_movement": [KEY_E], "ability_ultimate": [KEY_R], "race_active": [KEY_V], "throw_knife": [KEY_G], "sidearm": [KEY_C], "spyglass": [KEY_Z], "god_mode": [KEY_P], "camera_view": [KEY_T],
	"choose_1": [KEY_1], "choose_2": [KEY_2], "choose_3": [KEY_3],
	"release_mouse": [KEY_ESCAPE], "mount": [KEY_X],
	"debug_help": [KEY_F1], "debug_spawn": [KEY_F2], "debug_spawn_large": [KEY_F3],
	"debug_godly_gift": [KEY_F4], "debug_combo_kit": [KEY_F5], "debug_god_mode": [KEY_F6],
	"debug_kill_all": [KEY_F7], "debug_next_wave": [KEY_F8], "debug_restart": [KEY_F9],
	"debug_teleport": [KEY_F10], "playtest_overlay": [KEY_F11], "debug_final_battle": [KEY_F12],
}
const MOUSE := {
	"attack_light": MOUSE_BUTTON_LEFT, "attack_heavy": MOUSE_BUTTON_RIGHT,
	"slide": MOUSE_BUTTON_XBUTTON1,  # mouse side button (back), as in sam-movement
}
## Scrolling the wheel either way switches between your main weapon and your sidearm (user, 2026-11-08).
const WHEEL := {"switch_weapon": [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]}
## The actions a player can rebind, in menu order, with their labels.
const REBINDABLE := [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"],
	["move_right", "Move right"], ["jump", "Jump"], ["sprint", "Sprint"], ["dodge", "Dodge"], ["slide", "Slide"],
	["attack_light", "Light attack"], ["attack_heavy", "Heavy attack"],
	["ability_signature", "Special ability"], ["ability_movement", "Movement ability"],
	["ability_ultimate", "Ultimate ability"], ["race_active", "Race active skill"], ["throw_knife", "Throwing knife"], ["sidearm", "Switch to your bow and back"], ["switch_weapon", "Switch to your bow and back (wheel)"], ["spyglass", "Hold: spyglass (identify creatures far away)"], ["god_mode", "God mode"], ["mount", "Mount: get on or off"],
	["choose_1", "Choose option 1"], ["choose_2", "Choose option 2"],
	["choose_3", "Choose option 3"],
]
const SAVE_PATH := "user://controls.cfg"


func _ready() -> void:
	reset_to_defaults(false)
	load_saved()


## Puts every action back to the list above (and forgets saved changes if `save`).
func reset_to_defaults(save := true) -> void:
	for action in KEYS:
		_ensure(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE:
		_ensure(action)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE[action]
		InputMap.action_add_event(action, ev)
	for action in WHEEL:
		_ensure(action)
		for button in WHEEL[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
	if save:
		var cfg := ConfigFile.new()
		cfg.save(SAVE_PATH)


## Binds `action` to one key or mouse button (replacing its bindings) and saves.
## Returns the action that lost this input to avoid a clash ("" if none).
func rebind(action: String, event: InputEvent, save := true) -> String:
	var stolen := ""
	for other in REBINDABLE:
		var id: String = other[0]
		if id == action:
			continue
		for ev in InputMap.action_get_events(id):
			if _same(ev, event):
				InputMap.action_erase_event(id, ev)
				stolen = id
	_ensure(action)
	InputMap.action_add_event(action, event)
	if save:
		_save()
	return stolen


## Reads the player's saved bindings (if any).
func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for pair in REBINDABLE:
		var action: String = pair[0]
		if not cfg.has_section_key("bindings", action):
			continue
		var events: Array = cfg.get_value("bindings", action, [])
		_ensure(action)
		for e in events:
			if e is InputEvent:
				InputMap.action_add_event(action, e)


## A readable name for an action's first binding ("W", "Mouse Left"...).
func binding_text(action: String) -> String:
	var events := InputMap.action_get_events(action) if InputMap.has_action(action) else []
	if events.is_empty():
		return "(none)"
	var names: Array = []
	for ev in events:
		names.append(event_text(ev))
	return " / ".join(names)


static func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k: InputEventKey = ev
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Mouse Left"
			MOUSE_BUTTON_RIGHT: return "Mouse Right"
			MOUSE_BUTTON_MIDDLE: return "Mouse Middle"
			MOUSE_BUTTON_XBUTTON1: return "Mouse Back"
			MOUSE_BUTTON_XBUTTON2: return "Mouse Forward"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			_: return "Mouse %d" % (ev as InputEventMouseButton).button_index
	return ev.as_text()


func _save() -> void:
	var cfg := ConfigFile.new()
	for pair in REBINDABLE:
		cfg.set_value("bindings", pair[0], InputMap.action_get_events(pair[0]))
	cfg.save(SAVE_PATH)


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


func _ensure(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
