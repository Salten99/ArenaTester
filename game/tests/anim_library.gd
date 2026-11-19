extends Node3D
## Animation library (user, 2026-11-18): every people animation we have, played on the hero.
## KayKit clips (the ones the game loads and the three packs it doesn't) and the Quaternius
## Universal Animation Library clips converted to our rig (tools\retarget_ual.bat). For each
## clip, mark Use / Maybe / Discard and write where it should go; it saves as you type to
## animation_notes.json in the project folder, which Claude reads to wire the clips in.
## Quaternius clips show the original mannequin beside the hero, to judge the conversion.
##
## Run: double-click tools\anim_library.bat
## Drag on the view to turn, mouse wheel to zoom. Up/down arrows flip through the list.

const STATE_FILE := "animation_notes.json"  ## in the project folder (next to the spreadsheet)
const UAL_LIB := "res://models/quaternius/ual_rig_medium.res"
const KAYKIT_DIR := "itch/kaykit-animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/"
## KayKit files the game doesn't load (asset_library only).
const KAYKIT_UNUSED := ["Rig_Medium_Special.glb", "Rig_Medium_Simulation.glb", "Rig_Medium_Tools.glb"]
const UAL_PACKS := {  ## the originals, for the side-by-side mannequin
	"UAL1_": "itch/quaternius-ual1/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb",
	"UAL2_": "itch/quaternius-ual2/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb",
}
const VERDICTS := ["use", "maybe", "discard"]
const MARK := {"use": "✔ ", "maybe": "? ", "discard": "✘ ", "": "   "}
const FILTERS := ["All", "Not marked yet", "Use", "Maybe", "Discard", "Used in the game now", "Quaternius only", "KayKit only"]
const WEAPONS := {"Sword": "gear_sword.glb", "Greatsword": "weapon_greatsword.glb", "Spear": "weapon_spear.glb", "Bow": "weapon_bow.glb", "No weapon": ""}
const SPEEDS := [0.1, 0.25, 0.5, 1.0, 1.5]

var state_path := ""
var state := {}  ## clip -> {verdict, notes}
var clips: Array = []  ## [{name, lib, source, length, in_game}]
var _by_name := {}
var _hero: CharacterModel
var _originals := {}  ## "UAL1_" -> [scene, AnimationPlayer]
var _shown_original: Node3D
var _current := ""
var _list: ItemList
var _search: LineEdit
var _filter: OptionButton
var _title: Label
var _info: Label
var _notes: TextEdit
var _verdict_buttons := {}
var _time: HSlider
var _time_label: Label
var _pause: Button
var _speed := 1.0
var _show_original: CheckBox
var _cam: Camera3D
var _yaw := PI + 0.6  ## in front of the hero (it faces -Z)
var _pitch := 0.25
var _dist := 4.2


func _ready() -> void:
	if state_path == "":
		state_path = ProjectSettings.globalize_path("res://").path_join("..").simplify_path().path_join(STATE_FILE)
	_load_state()
	_build_stage()
	_hero = CharacterModel.new()
	add_child(_hero)
	_hero.setup(ModelRegistry.DEFAULT_RACE, ModelRegistry.own("gear_sword.glb"))
	gather(_hero)
	_build_panel()
	_fill()
	if _list.item_count > 0:
		_list.select(0)
		select(_list.get_item_metadata(0))


## Every clip, and its library on `hero`'s player (the game's own is ""; the others are added).
func gather(hero: CharacterModel) -> Array:
	clips.clear()
	_by_name.clear()
	var used := _clips_in_code()
	var game_lib := hero.anim.get_animation_library("")
	for a in game_lib.get_animation_list():
		_add(a, "", "KayKit (in game files)", game_lib.get_animation(a).length, used)
	var extra := AnimationLibrary.new()
	for f in KAYKIT_UNUSED:
		var scene := AnimRetarget.load_library_glb(KAYKIT_DIR + f)
		if scene == null:
			continue
		for player in scene.find_children("*", "AnimationPlayer", true, false):
			for a in (player as AnimationPlayer).get_animation_list():
				if a == "T-Pose" or game_lib.has_animation(a) or extra.has_animation(a):
					continue
				var clip: Animation = (player as AnimationPlayer).get_animation(a).duplicate(true)
				CharacterModel._refit(clip, hero._skeleton)
				extra.add_animation(a, clip)
				_add(a, "kaykit_extra", "KayKit %s (not loaded by the game)" % f.trim_prefix("Rig_Medium_").get_basename(), clip.length, used)
		scene.free()
	hero.anim.add_animation_library("kaykit_extra", extra)
	if ResourceLoader.exists(UAL_LIB):
		var src: AnimationLibrary = load(UAL_LIB)
		var ual := AnimationLibrary.new()
		for a in src.get_animation_list():
			var clip: Animation = src.get_animation(a).duplicate(true)
			CharacterModel._refit(clip, hero._skeleton)
			ual.add_animation(a, clip)
			_add(a, "ual", "Quaternius UAL%s (converted)" % a.substr(3, 1), clip.length, used)
		hero.anim.add_animation_library("ual", ual)
	return clips


func _add(clip: String, lib: String, source: String, length: float, used: Dictionary) -> void:
	var c := {"name": clip, "lib": lib, "source": source, "length": length, "in_game": used.has(clip)}
	clips.append(c)
	_by_name[clip] = c


## Clip names that appear in quotes in the game's scripts.
func _clips_in_code() -> Dictionary:
	var text := ""
	var todo := ["res://scripts/"]
	while not todo.is_empty():
		var dir: String = todo.pop_back()
		for d in DirAccess.get_directories_at(dir):
			todo.append(dir.path_join(d))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				text += FileAccess.get_file_as_string(dir.path_join(f))
	var used := {}
	var re := RegEx.create_from_string("\"([A-Za-z0-9_\\-]+)\"")
	for m in re.search_all(text):
		used[m.get_string(1)] = true
	return used


func verdict(clip: String) -> String:
	return str(state.get(clip, {}).get("verdict", ""))


func set_verdict(clip: String, v: String) -> void:
	_entry(clip).verdict = v if verdict(clip) != v else ""  # pressing it again clears it
	_save_state()


func set_notes(clip: String, text: String) -> void:
	_entry(clip).notes = text
	_save_state()


func _entry(clip: String) -> Dictionary:
	if not state.has(clip):
		var c: Dictionary = _by_name.get(clip, {})
		state[clip] = {"verdict": "", "notes": "", "source": c.get("source", "")}
	return state[clip]


func _load_state() -> void:
	var text := FileAccess.get_file_as_string(state_path) if FileAccess.file_exists(state_path) else ""
	var parsed = JSON.parse_string(text) if text != "" else null
	state = parsed if parsed is Dictionary else {}


func _save_state() -> void:
	var keep := {}  # empty entries aren't written
	for k in state:
		if str(state[k].get("verdict", "")) != "" or str(state[k].get("notes", "")).strip_edges() != "":
			keep[k] = state[k]
	var f := FileAccess.open(state_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(keep, "  ", true))


func matches(c: Dictionary, filter: int, q: String) -> bool:
	if q != "" and not str(c.name).to_lower().contains(q.to_lower()):
		return false
	var v := verdict(c.name)
	match FILTERS[filter]:
		"Not marked yet": return v == ""
		"Use": return v == "use"
		"Maybe": return v == "maybe"
		"Discard": return v == "discard"
		"Used in the game now": return c.in_game
		"Quaternius only": return c.lib == "ual"
		"KayKit only": return c.lib != "ual"
	return true


# ---------------------------------------------------------------- the window

func _build_stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.16, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()  # a checkered floor, so steps and slides read
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 14)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _checker()
	mat.uv1_scale = Vector3(14, 14, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_place_camera()


static func _checker() -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.fill(Color(0.36, 0.3, 0.22))
	img.set_pixel(0, 0, Color(0.42, 0.35, 0.26))
	img.set_pixel(1, 1, Color(0.42, 0.35, 0.26))
	return ImageTexture.create_from_image(img)


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	layer.add_child(root)
	# left: the list
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UiStyle.panel())
	left.anchor_bottom = 1.0
	left.offset_right = 400
	root.add_child(left)
	var lv := VBoxContainer.new()
	left.add_child(lv)
	lv.add_child(UiStyle.title(Label.new(), 22))
	(lv.get_child(0) as Label).text = "Animation library"
	_search = LineEdit.new()
	_search.placeholder_text = "Search clips (sword, jump, slide...)"
	_search.text_changed.connect(func(_t): _fill())
	lv.add_child(_search)
	_filter = OptionButton.new()
	for f in FILTERS:
		_filter.add_item(f)
	_filter.item_selected.connect(func(_i): _fill())
	lv.add_child(_filter)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i): select(_list.get_item_metadata(i)))
	lv.add_child(_list)
	var legend := Label.new()
	legend.text = "✔ use   ? maybe   ✘ discard   (game) already used"
	legend.add_theme_color_override("font_color", UiStyle.MUTED)
	lv.add_child(legend)
	# right: the notes
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UiStyle.panel())
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -380
	root.add_child(right)
	var rv := VBoxContainer.new()
	right.add_child(rv)
	_title = UiStyle.title(Label.new(), 20)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_title)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", UiStyle.MUTED)
	rv.add_child(_info)
	var row := HBoxContainer.new()
	rv.add_child(row)
	for v in VERDICTS:
		var b := Button.new()
		b.text = {"use": "✔ Use", "maybe": "? Maybe", "discard": "✘ Discard"}[v]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _on_verdict(v))
		row.add_child(b)
		_verdict_buttons[v] = b
	var ask := Label.new()
	ask.text = "Where should we use it? (or why discard)"
	rv.add_child(ask)
	_notes = TextEdit.new()
	_notes.placeholder_text = "e.g. player's light attack combo, 3rd hit; or boss slam windup; or too floaty"
	_notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_notes.custom_minimum_size.y = 160
	_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes.text_changed.connect(func():
		if _current != "":
			set_notes(_current, _notes.text))
	rv.add_child(_notes)
	var saved := Label.new()
	saved.text = "Saves as you type to animation_notes.json"
	saved.add_theme_color_override("font_color", UiStyle.MUTED)
	rv.add_child(saved)
	rv.add_child(HSeparator.new())
	_time = HSlider.new()
	_time.step = 0.01
	_time.drag_started.connect(func(): _set_paused(true))
	_time.value_changed.connect(_scrub)
	rv.add_child(_time)
	var play_row := HBoxContainer.new()
	rv.add_child(play_row)
	_pause = Button.new()
	_pause.text = "Pause"
	_pause.pressed.connect(func(): _set_paused(_hero.anim.is_playing()))
	play_row.add_child(_pause)
	_time_label = Label.new()
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_row.add_child(_time_label)
	var speed := OptionButton.new()
	for s in SPEEDS:
		speed.add_item("%sx speed" % s)
	speed.select(SPEEDS.find(1.0))
	speed.item_selected.connect(func(i):
		_speed = SPEEDS[i]
		_apply_speed())
	play_row.add_child(speed)
	var weapon := OptionButton.new()
	for w in WEAPONS:
		weapon.add_item("Holding: " + w)
	weapon.item_selected.connect(func(i):
		_hero.set_weapon(ModelRegistry.own(WEAPONS.values()[i]))
		_restart())
	rv.add_child(weapon)
	_show_original = CheckBox.new()
	_show_original.text = "Show the Quaternius original beside"
	_show_original.button_pressed = true
	_show_original.toggled.connect(func(_on): _restart())
	rv.add_child(_show_original)


func _fill() -> void:
	var keep := _current
	_list.clear()
	for c in clips:
		if not matches(c, _filter.selected, _search.text):
			continue
		var tag := "  (game)" if c.in_game else ""
		var src := "Q " if c.lib == "ual" else "K "
		var i := _list.add_item(MARK[verdict(c.name)] + src + str(c.name) + tag)
		_list.set_item_metadata(i, c.name)
		if c.name == keep:
			_list.select(i)
	_list.tooltip_text = "%d clips shown (K = KayKit, Q = Quaternius)" % _list.item_count


func select(clip: String) -> void:
	if not _by_name.has(clip):
		return
	_current = clip
	var c: Dictionary = _by_name[clip]
	_title.text = clip
	var marked := 0
	for k in state:
		if str(state[k].get("verdict", "")) != "":
			marked += 1
	_info.text = "%s\n%.2f s%s\n%d of %d clips marked" % [c.source, c.length, "   ·   already used in the game" if c.in_game else "", marked, clips.size()]
	var v := verdict(clip)
	for k in _verdict_buttons:
		_verdict_buttons[k].set_pressed_no_signal(k == v)
	_notes.text = str(state.get(clip, {}).get("notes", ""))
	_time.max_value = c.length
	_restart()


func _on_verdict(v: String) -> void:
	if _current == "":
		return
	set_verdict(_current, v)
	for k in _verdict_buttons:
		_verdict_buttons[k].set_pressed_no_signal(k == verdict(_current))
	_fill()


func _anim_id(c: Dictionary) -> String:
	return str(c.name) if c.lib == "" else "%s/%s" % [c.lib, c.name]


func _restart() -> void:
	if _current == "":
		return
	var c: Dictionary = _by_name[_current]
	var a := _hero.anim.get_animation(_anim_id(c))
	if a != null:
		a.loop_mode = Animation.LOOP_LINEAR  # the viewer always loops
	_hero.anim.play(_anim_id(c), 0.0)
	_hero.anim.seek(0.0, true)
	_show_original_for(c)
	_apply_speed()
	_set_paused(false)


func _show_original_for(c: Dictionary) -> void:
	if _shown_original != null:
		_shown_original.visible = false
		_shown_original = null
	_hero.position.x = 0.0
	if c.lib != "ual" or not _show_original.button_pressed:
		return
	var pack := str(c.name).substr(0, 5)
	if not _originals.has(pack) and UAL_PACKS.has(pack):
		var scene: Node3D = AnimRetarget.load_library_glb(UAL_PACKS[pack])
		if scene != null:
			scene.rotation.y = PI  # face the camera like the hero (both face +Z)
			add_child(scene)
			_originals[pack] = [scene, scene.find_children("*", "AnimationPlayer", true, false)[0]]
	if not _originals.has(pack):
		return
	_shown_original = _originals[pack][0]
	var player: AnimationPlayer = _originals[pack][1]
	var clip := str(c.name).substr(5)
	if not player.has_animation(clip):
		return
	player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_shown_original.visible = true
	_shown_original.position.x = 0.8
	_hero.position.x = -0.8
	player.play(clip, 0.0)
	player.seek(0.0, true)


func _original_player() -> AnimationPlayer:
	if _shown_original == null:
		return null
	for k in _originals:
		if _originals[k][0] == _shown_original:
			return _originals[k][1]
	return null


func _scrub(t: float) -> void:
	if _hero.anim.is_playing():
		return  # the slider follows the clip; dragging it pauses first
	_hero.anim.seek(t, true)
	var o := _original_player()
	if o != null:
		o.seek(t, true)


func _set_paused(paused: bool) -> void:
	var o := _original_player()
	if paused:
		_hero.anim.pause()
		if o != null:
			o.pause()
	else:
		_hero.anim.play()
		if o != null:
			o.play()
			o.seek(_hero.anim.current_animation_position, true)
	_pause.text = "Play" if paused else "Pause"


func _apply_speed() -> void:
	_hero.anim.speed_scale = _speed
	var o := _original_player()
	if o != null:
		o.speed_scale = _speed


func _process(_delta: float) -> void:
	if _hero == null or _hero.anim == null or _time == null:
		return
	if _hero.anim.is_playing():
		_time.set_value_no_signal(_hero.anim.current_animation_position)
	_time_label.text = "%.2f / %.2f s" % [_time.value, _time.max_value]


func _place_camera() -> void:
	var target := Vector3(0, 0.9, 0)
	_cam.position = target + Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, -_pitch) * Vector3(0, 0, _dist)
	_cam.look_at(target)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.008, -0.1, 1.4)
		_place_camera()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_dist *= 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
		_place_camera()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE and not _notes.has_focus() and not _search.has_focus():
		_set_paused(_hero.anim.is_playing())
