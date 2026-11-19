extends Node3D
## Art checklist (user, 2026-11-05): a sticky note of every model, animation and sound to make to
## replace the placeholders. Pick one to see what's in the game now (the model turning, its
## animations to play), then give the path to your file and press Import: it goes into
## models/own/ (a .blend is exported first, with Blender), the generated placeholder is deleted,
## and Godot imports it. Your ticks and notes are kept in art_checklist.json in the project folder.
## It is also the model viewer (merged from the old asset viewer, user 2026-11-17): the menu at the
## top switches to every game model or to the downloaded packs in asset_library/ (models and
## pictures); every animation can be scrubbed, slowed down and compared across models.
## "Texture garden" in that menu lays out every picture in the game, a plot each; pick one to fly to it.
##
## Run: double-click tools\art_checklist.bat
## Drag on the view to turn, mouse wheel to zoom. Up/down arrows flip through a list.

const STATE_FILE := "art_checklist.json"  ## in the project folder (next to the spreadsheet)
const BLENDER := "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
const PYTHON := "C:/ProgramData/anaconda3/python.exe"
## The sounds to make: not in the game yet (Milestone 2); imported ones wait in sounds/own/.
const SOUNDS := ["hit", "hit_heavy", "swing", "shot", "magic", "step", "hoof", "click", "level_up", "chest", "death", "horn", "wind"]
const NOTE := UiStyle.PARCHMENT  ## a parchment page in the game's look (UiStyle)
const INK := Color(0.2, 0.17, 0.1)
const SOURCES := ["Art to make", "All game models", "Asset library", "Texture garden"]
const GARDEN := 3  ## the Texture garden in SOURCES (user, 2026-11-17): every picture in the game
const PLOT := 3.0  ## meters between the garden's plots
const PLOTS_PER_ROW := 12
const FOLDERS := ["own/", "free/", "gen/", "own/world/", "gen/world/"]
const PROP_NAMES := ["weapon_", "gear_", "tool_"]  ## none of these (or world/) have animations
## Creatures without clips are moved in code (BeastModel); these names play each of its moves.
const CODE_MOVES := ["Idle_A", "Walking_A", "Running_A", "Melee_1H_Attack_Chop", "Hit_A", "Death_A"]
const SPEEDS := [0.1, 0.25, 0.5, 1.0, 2.0]
## shortcut: no .obj, .stl or .dae (Godot can't open them while running), add a converter if a pack only has those.
const LIBRARY_TYPES := ["glb", "gltf", "fbx", "png", "jpg", "jpeg"]

## Where things go; tests point these somewhere else.
var models_dir := "res://models/"
var sounds_dir := "res://sounds/own/"
var state_path := ""
var items: Array = []  ## [{key, group, name, file, kind: model|world|animation|sound, notes}]
var state := {}        ## key -> {done, path, notes}
var _list: ItemList
var _filter: LineEdit
var _hide_done: CheckBox
var _title: Label
var _info: Label
var _clips: ItemList
var _path: LineEdit
var _status: Label
var _notes: TextEdit
var _done: CheckBox
var _source: OptionButton
var _import_box: VBoxContainer
var _picture: TextureRect
var _time: HSlider
var _time_label: Label
var _pause: Button
var _repeat: CheckBox
var _body: CharacterModel  ## or a BeastModel (then _beast is the same node)
var _beast: BeastModel
var _clip_name := ""
var _paused := false
var _speed := 1.0
var _cam: Camera3D
var _target := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.15
var _dist := 6.0
var _spin := true  ## turns slowly until you drag the view
var _current := {}
var _shown: Array = []
var _game: Array = []     ## res:// paths of every game model, read when first asked for
var _library: Array = []  ## files in asset_library/, read when first asked for
var _side: PanelContainer  ## the animations, on the right (hidden in the garden)
var _garden: Node3D  ## the texture garden, planted when first asked for
var garden_spots := {}  ## res:// path of each picture -> the middle of its plot


func _ready() -> void:
	if state_path == "":
		state_path = ProjectSettings.globalize_path("res://").path_join("..").simplify_path().path_join(STATE_FILE)
	if get_tree().current_scene == self:  # not when a test opens it inside the test window
		get_window().title = "Art checklist"
		RetroLook.visible = false  # see the model sharp, as made
		get_window().size = Vector2i(1180, 760)
	_load_state()
	items = gather()
	_build_stage()
	_build_panel()
	_fill()


# ---------------------------------------------------------------- what's to make

## Every model, animation and sound to make, from the spreadsheet and the game's folders.
func gather() -> Array:
	var out: Array = []
	var add := func(group: String, name: String, file, kind := "model", extra := {}) -> void:
		if file == null or str(file) == "":
			return
		var item := {"key": "%s:%s" % [kind, file], "group": group, "name": name, "file": str(file), "kind": kind}
		item.merge(extra)
		out.append(item)
	# Each race has the same classes, each with its own look (user, 2026-11-17): own/<race>/<class>/.
	for r in GameData.rows("races"):
		var race: String = r.race_id
		var group := "Race: " + GameData.text(r, "display_name")
		for w in GameData.rows("weapons"):
			var cls := GameData.text(w, "class_name")
			var wid: String = w.weapon_id
			if cls == "":
				add.call(group, GameData.text(w, "display_name"), "%s/%s.glb" % [race, wid], "model",
					{"now": func(): return ModelRegistry.weapon_model(wid, race)})
				continue
			var folder := "%s/%s/" % [race, cls.to_lower()]
			add.call(group, cls + " body", folder + "body.glb", "model", {"now": func(): return ModelRegistry.for_race(race, cls)})
			add.call(group, "%s weapon (%s)" % [cls, GameData.text(w, "display_name")], folder + "weapon.glb", "model",
				{"now": func(): return ModelRegistry.weapon_model(wid, race)})
			if cls == "Guardian":
				add.call(group, "Guardian shield", folder + "shield.glb", "model", {"now": func():
					var mine := ModelRegistry.class_part(race, cls, "shield")
					return mine if mine != "" else ModelRegistry.own(Player.SHIELD)})
		add.call(group, "Throwing weapon", race + "/knife.glb", "model", {"now": func():
			var mine := ModelRegistry.race_part(race, "knife")
			return mine if mine != "" else ModelRegistry.own(race + "/gear_knife.glb")})
	for r in GameData.rows("races"):
		add.call("Player races (any class without its own body)", GameData.text(r, "display_name"), r.get("player_model_file"))
	for w in GameData.rows("weapons"):
		add.call("Weapons (races without their own)", GameData.text(w, "display_name"), w.get("weapon_model_file"))
	# People go in their race's people/ folder.
	for u in GameData.rows("army_units"):
		add.call("Army units", "%s (%s)" % [GameData.text(u, "display_name"), GameData.text(GameData.race(u.race_id), "display_name")], u.get("model_file"), "model", {"dir": "%s/people/" % u.race_id})
	for m in GameData.rows("tribe_members"):
		add.call("Villagers", "%s (%s)" % [GameData.text(m, "display_name"), GameData.text(GameData.race(m.race_id), "display_name")], m.get("model_file"), "model", {"dir": "%s/people/" % m.race_id})
	for c in GameData.rows("champions"):
		add.call("Champions", GameData.text(c, "display_name"), c.get("model_file"), "model", {"dir": "%s/people/" % c.race_id})
	for m in GameData.rows("mounts"):
		add.call("Mounts", GameData.text(m, "display_name"), m.get("model_file"))
	for b in GameData.rows("barbarians_beasts"):
		add.call("Beasts and monsters", GameData.text(b, "display_name"), b.get("model_file"))
	var world := DirAccess.get_files_at(models_dir + "gen/world/") if DirAccess.dir_exists_absolute(models_dir + "gen/world/") else PackedStringArray()
	for f in world:
		if f.ends_with(".glb"):
			add.call("World", f.get_basename().replace("_", " ").capitalize(), f, "world")
	for clip in _free_clips():
		add.call("Animations (humanoid rig)", clip, clip + ".glb", "animation")
	for s in SOUNDS:
		add.call("Sounds (not in the game yet)", s.replace("_", " ").capitalize(), s + ".wav", "sound")
	var unique: Array = []
	var seen := {}
	for i in out:  # a file the sheet names twice (shared models) is one thing to make
		if not seen.has(i.key):
			seen[i.key] = true
			unique.append(i)
	return unique


func _free_clips() -> Array:
	var names: Array = []
	for path in ModelRegistry.ANIMATION_FILES:
		if not ResourceLoader.exists(path):
			continue
		var scene: Node = (load(path) as PackedScene).instantiate()
		for p in scene.find_children("*", "AnimationPlayer", true, false):
			for a in (p as AnimationPlayer).get_animation_list():
				if a != "RESET" and a != "T-Pose" and not a in names:
					names.append(a)
		scene.free()
	names.sort()
	return names


## Where your file for `item` goes in the game.
func target(item: Dictionary) -> String:
	match item.kind:
		"world": return models_dir + "own/world/" + item.file
		"animation": return models_dir + "own/animations/" + item.file
		"sound": return sounds_dir + item.file
	return models_dir + "own/" + str(item.get("dir", "")) + item.file


## The generated stand-in that yours replaces ("" if there is none to delete: free assets stay).
func generated(item: Dictionary) -> String:
	match item.kind:
		"model": return models_dir + "gen/" + item.file
		"world": return models_dir + "gen/world/" + item.file
	return ""


func is_done(item: Dictionary) -> bool:
	return FileAccess.file_exists(target(item)) or bool(state.get(item.key, {}).get("done", false)) 		or (item.kind == "model" and ModelRegistry.own(item.file).begins_with(ModelRegistry.OWN))


## What the game shows for it now.
func current(item: Dictionary) -> String:
	if item.kind == "world":
		return target(item) if FileAccess.file_exists(target(item)) else generated(item)
	if item.has("now"):
		return item.now.call()
	if item.kind == "model":
		return ModelRegistry.own(item.file)
	return ""


# ---------------------------------------------------------------- importing

## Puts the file at `source` into the game for `item`: copied (a .blend is exported to .glb
## first), the generated stand-in deleted. Returns what happened, in words.
func import_file(item: Dictionary, source: String) -> String:
	source = source.strip_edges().trim_prefix("\"").trim_suffix("\"")
	if not FileAccess.file_exists(source):
		return "No file at %s" % source
	var to := ProjectSettings.globalize_path(target(item))
	DirAccess.make_dir_recursive_absolute(to.get_base_dir())
	var ext := source.get_extension().to_lower()
	var wanted := "wav" if item.kind == "sound" else "glb"
	if ext == "blend" and wanted == "glb":
		var out: Array = []
		var script := ProjectSettings.globalize_path("res://").path_join("../tools/blender/export_blend.py").simplify_path()
		OS.execute(BLENDER, ["-b", source, "-P", script, "--", "--out", to], out, true)
		if not FileAccess.file_exists(to):
			return "Blender couldn't export it:\n" + "\n".join(out).right(400)
	elif ext == wanted or (wanted == "glb" and ext == "gltf"):
		if DirAccess.copy_absolute(source, to) != OK:
			return "Couldn't copy it to %s" % to
	else:
		return "This needs a .%s%s file, not .%s" % [wanted, " (or .blend)" if wanted == "glb" else "", ext]
	var said := "In the game as %s" % target(item).trim_prefix("res://")
	var gen := generated(item)
	if gen != "" and FileAccess.file_exists(gen):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gen))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gen + ".import"))
		said += "\nThe generated one is deleted."
	var s: Dictionary = state.get(item.key, {})
	s["path"] = source
	s["done"] = true
	state[item.key] = s
	_save_state()
	return said


## Godot imports the new file in the background, and the model check reports any problem.
func _after_import(item: Dictionary) -> void:
	ModelRegistry.rescan()
	OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"])
	if item.kind in ["model", "world"]:
		var out: Array = []
		var tool := ProjectSettings.globalize_path("res://").path_join("../tools/check_model.py").simplify_path()
		OS.execute(PYTHON, [tool, ProjectSettings.globalize_path(target(item))], out, true)
		_status.text += "\n\nModel check:\n" + "\n".join(out).strip_edges().right(600)


# ---------------------------------------------------------------- saved ticks and notes

func _load_state() -> void:
	var text := FileAccess.get_file_as_string(state_path) if FileAccess.file_exists(state_path) else ""
	var parsed = JSON.parse_string(text) if text != "" else null
	state = parsed if parsed is Dictionary else {}


func _save_state() -> void:
	var f := FileAccess.open(state_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(state, " ", true))


# ---------------------------------------------------------------- the note

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
	add_child(sun)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_picture = TextureRect.new()  # a picture from the asset library, between the two panels
	_picture.anchor_right = 1.0
	_picture.anchor_bottom = 1.0
	_picture.offset_left = 560.0
	_picture.offset_right = -240.0
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_picture)
	var paper := Theme.new()  # light boxes with dark ink, like writing on the note
	for kind in ["ItemList", "LineEdit", "TextEdit"]:
		var b := StyleBoxFlat.new()
		b.bg_color = Color(0.95, 0.9, 0.76)
		b.border_color = Color(0.45, 0.32, 0.16)
		b.set_border_width_all(1)
		b.set_content_margin_all(6)
		paper.set_stylebox("panel" if kind == "ItemList" else "normal", kind, b)
		paper.set_color("font_color", kind, INK)
		paper.set_color("font_placeholder_color", kind, Color(INK, 0.45))
	paper.set_color("font_selected_color", "ItemList", INK)
	var panel := PanelContainer.new()
	var style := UiStyle.parchment()
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_bottom = 1.0
	panel.offset_right = 560
	panel.theme = paper
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	_source = OptionButton.new()
	for s in SOURCES:
		_source.add_item(s)
	_source.item_selected.connect(func(_i): _fill())
	top.add_child(_source)
	_filter = LineEdit.new()
	_filter.placeholder_text = "search"
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.text_changed.connect(func(_t): _fill())
	top.add_child(_filter)
	_hide_done = CheckBox.new()
	_ink(_hide_done, "hide done")
	_hide_done.toggled.connect(func(_on): _fill())
	top.add_child(_hide_done)
	var pin := CheckBox.new()
	_ink(pin, "on top")
	pin.toggled.connect(func(on): get_window().always_on_top = on)
	top.add_child(pin)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_color_override("font_color", INK)
	_list.item_selected.connect(func(i): select(_shown[i]))
	box.add_child(_list)
	_title = _ink(Label.new(), "")
	_title.add_theme_font_override("font", UiStyle.font(600))
	_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_title)
	_info = _ink(Label.new(), "")
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	_import_box = VBoxContainer.new()  # hidden while browsing models that aren't on the checklist
	box.add_child(_import_box)
	var row := HBoxContainer.new()
	_import_box.add_child(row)
	_path = LineEdit.new()
	_path.placeholder_text = "path to your file (.glb or .blend; .wav for sounds)"
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_path)
	var browse := Button.new()
	browse.text = "Browse"
	browse.pressed.connect(_browse)
	row.add_child(browse)
	var imp := Button.new()
	imp.text = "Import"
	imp.pressed.connect(_on_import)
	row.add_child(imp)
	_done = CheckBox.new()
	_ink(_done, "done")
	_done.toggled.connect(func(on): _set_field("done", on))
	_import_box.add_child(_done)
	_notes = TextEdit.new()
	_notes.placeholder_text = "your notes"
	_notes.custom_minimum_size.y = 60
	_notes.text_changed.connect(func(): _set_field("notes", _notes.text))
	_import_box.add_child(_notes)
	_status = _ink(Label.new(), "")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	# Its animations, on the right, with the time bar and speed under them.
	var side := PanelContainer.new()
	_side = side
	var s2 := style.duplicate() as StyleBoxFlat
	s2.bg_color = Color(NOTE, 0.85)
	side.add_theme_stylebox_override("panel", s2)
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_bottom = 1.0
	side.offset_left = -240
	side.theme = paper
	layer.add_child(side)
	var sbox := VBoxContainer.new()
	side.add_child(sbox)
	var anim_heading := _ink(Label.new(), "ITS ANIMATIONS")
	anim_heading.add_theme_font_override("font", UiStyle.font(600))
	sbox.add_child(anim_heading)
	_clips = ItemList.new()
	_clips.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_clips.add_theme_color_override("font_color", INK)
	_clips.item_selected.connect(func(i): play_clip(_clips.get_item_metadata(i)))
	sbox.add_child(_clips)
	_time_label = _ink(Label.new(), "")
	sbox.add_child(_time_label)
	_time = HSlider.new()
	_time.step = 0.001
	_time.value_changed.connect(scrub)
	sbox.add_child(_time)
	var controls := HBoxContainer.new()
	sbox.add_child(controls)
	_pause = Button.new()
	_pause.text = "Pause"
	_pause.custom_minimum_size.x = 60
	_pause.pressed.connect(func(): _set_paused(not _paused))
	controls.add_child(_pause)
	var speed := OptionButton.new()
	for s in SPEEDS:
		speed.add_item("%sx" % s)
	speed.select(SPEEDS.find(1.0))
	speed.item_selected.connect(func(i): _speed = SPEEDS[i]; _apply_speed())
	controls.add_child(speed)
	_repeat = CheckBox.new()
	_ink(_repeat, "repeat")
	_repeat.button_pressed = true
	controls.add_child(_repeat)
	sbox.add_child(_ink(Label.new(), "drag the view to turn, wheel to zoom"))


func _ink(c: Control, text: String) -> Control:
	c.set("text", text)
	for state_name in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		c.add_theme_color_override(state_name, INK)
	return c


func _fill() -> void:
	_list.clear()
	_shown.clear()
	var q := _filter.text.to_lower()
	_hide_done.visible = _source.selected == 0
	_side.visible = _source.selected != GARDEN
	if _garden != null:
		_garden.visible = _source.selected == GARDEN
	if _source.selected == GARDEN:
		_fill_garden(q)
		return
	if _source.selected != 0:
		for f in _game_files() if _source.selected == 1 else _library_files():
			var shown: String = f.trim_prefix(models_dir).trim_prefix(_library_root())
			if q == "" or shown.to_lower().contains(q):
				_list.add_item(shown)
				_shown.append({"view": f})
		return
	var group := ""
	var done := 0
	for item in items:
		if is_done(item):
			done += 1
		if (_hide_done.button_pressed and is_done(item)) or (q != "" and not (item.name.to_lower().contains(q) or item.file.to_lower().contains(q))):
			continue
		if item.group != group:
			group = item.group
			_heading(group)
		_list.add_item("%s  %s   (%s)" % ["☑" if is_done(item) else "☐", item.name, item.file])
		_shown.append(item)
	get_window().title = "Art checklist: %d of %d done" % [done, items.size()]


func _heading(text: String) -> void:
	var h := _list.add_item("— %s —" % text)
	_list.set_item_selectable(h, false)
	_list.set_item_custom_fg_color(h, Color(0.55, 0.35, 0.1))
	_shown.append({})


# ---------------------------------------------------------------- the texture garden

## Lists every picture in the game by folder; the garden stands in the view instead of a model.
func _fill_garden(q: String) -> void:
	if _garden == null:
		plant_garden()
		_target = Vector3(PLOT * PLOTS_PER_ROW * 0.5, 0, 6 * PLOT)  # the first beds, from above
		_dist = 45.0
		_pitch = 0.7
	show_model("")
	_import_box.visible = false
	var bed := ""
	for f: String in garden_spots:
		if q != "" and not f.to_lower().contains(q):
			continue
		if f.get_base_dir() != bed:
			bed = f.get_base_dir()
			_heading(bed.trim_prefix("res://"))
		_list.add_item(f.get_file())
		_shown.append({"texture": f})
	get_window().title = "Texture garden: %d pictures" % garden_spots.size()
	_place_camera()


## Every .png and .jpg in the game's folders (res:// paths), folder by folder.
func _texture_files(folder := "res://") -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(folder):
		if f.get_extension().to_lower() in ["png", "jpg", "jpeg"]:
			out.append(folder.path_join(f))
	for d in DirAccess.get_directories_at(folder):
		if not d.begins_with("."):
			out.append_array(_texture_files(folder.path_join(d)))
	return out


## One plot per picture, a bed (rows under a sign) per folder: the picture repeated 2 x 2 on the
## ground to show its seams, the whole picture once on a board behind, its name in front.
## shortcut: every picture loads at once (~550, a few seconds); load beds on demand if it gets slow.
func plant_garden() -> void:
	_garden = Node3D.new()
	add_child(_garden)
	var row := -1
	var col := 0
	var bed := ""
	for f: String in _texture_files():
		var tex := load(f) as Texture2D
		if tex == null:
			continue
		if f.get_base_dir() != bed:  # a new bed: an empty row, then its sign
			bed = f.get_base_dir()
			row += 2 if col > 0 or row < 0 else 1
			col = 0
			var sign := Label3D.new()
			sign.text = bed.trim_prefix("res://")
			sign.font_size = 72
			sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sign.modulate = Color(1.0, 0.85, 0.5)
			sign.position = Vector3(-PLOT, 1.0, row * PLOT)
			_garden.add_child(sign)
		var at := Vector3(col * PLOT, 0, row * PLOT)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # the lightning bolts are see-through
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2, 2)
		ground.mesh = plane
		var tiled := mat.duplicate() as StandardMaterial3D
		tiled.uv1_scale = Vector3(2, 2, 1)
		ground.material_override = tiled
		ground.position = at
		_garden.add_child(ground)
		var board := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var aspect := float(tex.get_width()) / tex.get_height()
		quad.size = Vector2(1.6, 1.6 / aspect) if aspect >= 1.0 else Vector2(1.6 * aspect, 1.6)
		board.mesh = quad
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # its true colors, not lit
		board.material_override = mat
		board.position = at + Vector3(0, 0.2 + quad.size.y / 2, -1.1)
		_garden.add_child(board)
		var label := Label3D.new()
		label.text = f.get_file().get_basename()
		label.font_size = 24
		label.width = 260
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = at + Vector3(0, 0.25, 1.2)
		_garden.add_child(label)
		garden_spots[f] = at + Vector3(0, 0.8, 0)
		col += 1
		if col == PLOTS_PER_ROW:
			col = 0
			row += 1


## Every .glb in the game's model folders (res:// paths), read once.
func _game_files() -> Array:
	if _game.is_empty():
		for folder in FOLDERS:
			for f in DirAccess.get_files_at(models_dir + folder):
				if f.ends_with(".glb"):
					_game.append(models_dir + folder + f)
	return _game


## Every model and picture in the downloaded packs (asset_library/, not in git), read once.
func _library_files(folder := "") -> Array:
	if folder == "" and not _library.is_empty():
		return _library
	for f in DirAccess.get_files_at(_library_root() + folder):
		if f.get_extension().to_lower() in LIBRARY_TYPES:
			_library.append(_library_root() + folder + f)
	for d in DirAccess.get_directories_at(_library_root() + folder):
		_library_files(folder + d + "/")
	return _library


func _library_root() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../asset_library/").simplify_path() + "/"


func select(item: Dictionary) -> void:
	if item.is_empty():
		return
	_status.text = ""
	if item.has("texture"):  # the garden: fly to its plot
		_current = {}
		var tex := load(item.texture) as Texture2D
		_title.text = str(item.texture).get_file()
		_info.text = "%s\n%d x %d picture" % [str(item.texture).trim_prefix("res://"), tex.get_width(), tex.get_height()]
		_target = garden_spots[item.texture]
		_dist = 4.5
		_pitch = 0.35
		_place_camera()
		return
	if item.has("view"):  # browsing: just look at it
		_current = {}
		_import_box.visible = false
		_title.text = str(item.view).get_file()
		_info.text = str(item.view).trim_prefix("res://")
		show_model(item.view)
		return
	_import_box.visible = true
	_current = item
	var s: Dictionary = state.get(item.key, {})
	_title.text = item.name
	var now := current(item)
	var where := {"model": "Now in the game: %s" % (now.trim_prefix("res://") if now != "" else "nothing (a stand-in by role)"),
		"world": "Now in the game: %s" % now.trim_prefix("res://"),
		"animation": "A clip of the shared humanoid rig (make it on Rig_Medium, KayKit bone names). Yours goes in %s and replaces the free one." % target(item).trim_prefix("res://"),
		"sound": "Not played yet: sound is planned for Milestone 2. Yours waits in %s." % target(item).trim_prefix("res://")}
	_info.text = "%s\n%s" % [item.file, where[item.kind]]
	_path.text = str(s.get("path", ""))
	_notes.set_block_signals(true)
	_notes.text = str(s.get("notes", ""))
	_notes.set_block_signals(false)
	_done.set_block_signals(true)
	_done.button_pressed = is_done(item)
	_done.set_block_signals(false)
	show_model(now if item.kind in ["model", "world"] else "", item.file.get_basename() if item.kind == "animation" else "")


func _set_field(field: String, value) -> void:
	if _current.is_empty():
		return
	var s: Dictionary = state.get(_current.key, {})
	s[field] = value
	state[_current.key] = s
	_save_state()
	if field == "done":
		_fill()


func _browse() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.wav ; Sound"] if _current.get("kind", "") == "sound" else ["*.glb, *.gltf, *.blend ; Models"])
	dialog.file_selected.connect(func(p): _path.text = p)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 500))


func _on_import() -> void:
	if _current.is_empty() or _path.text.strip_edges() == "":
		return
	var gen := generated(_current)
	if gen != "" and FileAccess.file_exists(gen):
		var ask := ConfirmationDialog.new()
		ask.dialog_text = "Import your file and delete the generated %s?\n(It can be made again with the tools/blender scripts.)" % gen.trim_prefix("res://")
		ask.confirmed.connect(_do_import)
		add_child(ask)
		ask.popup_centered()
	else:
		_do_import()


func _do_import() -> void:
	_status.text = import_file(_current, _path.text)
	if _status.text.begins_with("In the game"):
		_after_import(_current)
		_fill()
		show_model(ProjectSettings.globalize_path(target(_current)) if _current.kind in ["model", "world"] else "")


# ---------------------------------------------------------------- the model and its animations

## Shows the model at `path` the way the game loads it (res://), or straight from a file on disk
## (one just imported, or the asset library: .glb, .gltf, .fbx, or a picture). `clip` for an
## animation row shows the player race model playing that clip. The chosen clip stays chosen
## when you pick another model, to compare the same animation on both.
func show_model(path: String, clip := "") -> void:
	if _body != null:
		_body.free()
		_body = null
	_beast = null
	_picture.texture = null
	_clips.clear()
	_time_label.text = ""
	if clip != "":
		_clip_name = clip
		path = ModelRegistry.own(GameData.text(GameData.race("human"), "player_model_file"))
	if path == "":
		return
	var ext := path.get_extension().to_lower()
	if ext in ["png", "jpg", "jpeg"]:
		var image := Image.load_from_file(path)
		_picture.texture = ImageTexture.create_from_image(image) if image != null else null
		_info.text += "\n" + ("%d x %d picture" % [image.get_width(), image.get_height()] if image != null else "could not open it")
		return
	if path.begins_with("res://"):
		var probe: Node = (load(path) as PackedScene).instantiate()
		var own_clips := not probe.find_children("*", "AnimationPlayer", true, false).is_empty()
		var skel: Array = probe.find_children("*", "Skeleton3D", true, false)
		var humanoid: bool = not skel.is_empty() and (skel[0] as Skeleton3D).find_bone("hips") >= 0
		probe.free()
		if humanoid and not own_clips:
			_body = CharacterModel.new()
			add_child(_body)
			_body.setup(path)
		else:
			_beast = BeastModel.new()
			_body = _beast
			add_child(_body)
			_beast.setup_beast(path, 1.0)
			_body.set_process(not _is_prop(path))  # a prop stands still
	else:  # read straight from disk: Godot hasn't imported it (yet)
		var doc: GLTFDocument = FBXDocument.new() if ext == "fbx" else GLTFDocument.new()
		var st: GLTFState = FBXState.new() if ext == "fbx" else GLTFState.new()
		var scene: Node = doc.generate_scene(st) if doc.append_from_file(path, st) == OK else null
		if scene == null:
			_info.text += "\ncould not open it"
			return
		_body = CharacterModel.new()
		add_child(_body)
		_body.model = scene
		_body.add_child(scene)
		var players: Array = scene.find_children("*", "AnimationPlayer", true, false)
		_body.anim = players[0] if not players.is_empty() else null
	_fill_clips(path)
	var box := CharacterModel.bounds(_body)
	_target = box.get_center()
	_dist = clampf(box.size.length() * 1.5, 0.5, 1500.0)  # the packs come in any scale
	_place_camera()


func _is_prop(path: String) -> bool:
	return "world/" in path or PROP_NAMES.any(func(p): return path.get_file().begins_with(p))


func _fill_clips(path: String) -> void:
	var names: Array = []
	if _body.anim != null:
		names = Array(_body.anim.get_animation_list()).filter(func(n): return n != "RESET")
		names.sort()
		_body.anim.playback_default_blend_time = 0.0
	elif _beast != null and not _is_prop(path):
		names = CODE_MOVES
	for n in names:
		_clips.set_item_metadata(_clips.add_item(_clip_text(n)), n)
	if names.is_empty():
		_time_label.text = "no animations"
		return
	if not _clip_name in names:  # keep the chosen clip to compare; else start on an idle
		var idles: Array = names.filter(func(n): return n.contains("Idle"))
		_clip_name = idles[0] if not idles.is_empty() else names[0]
	_clips.select(names.find(_clip_name))
	play_clip(_clip_name)


## An animal's clip says what the game uses it for; clips with no note are never played.
func _clip_text(clip: String) -> String:
	if _beast == null or _body.anim == null:
		return clip
	var roles: Array = _beast._clip.keys().filter(func(r): return _beast._clip[r] == clip)
	return clip if roles.is_empty() else "%s  (%s)" % [clip, ", ".join(roles)]


func play_clip(clip: String) -> void:
	_clip_name = clip
	if _body == null:
		return
	if _body.anim == null:  # a creature moved in code
		_beast._dead = false  # a code-moved death doesn't get up by itself
		_beast.model.transform = _beast._rest
		_beast._move_role = "idle"
		_body.play(clip)
		_time_label.text = "(moved in code)"
		return
	if not _body.anim.has_animation(clip):
		return
	_body.anim.play(clip)
	_body._current = clip  # four-legged humanoids gallop in code from this name
	_time.set_value_no_signal(0.0)
	_time.max_value = _body.anim.get_animation(clip).length
	_set_paused(false)


## Jumps to a moment of the animation and holds it there. Holding is speed 0, not
## AnimationPlayer.pause(): a paused player doesn't show the pose you seek to.
func scrub(t: float) -> void:
	if _body == null or _body.anim == null or _clip_name == "":
		return
	if not _body.anim.is_playing():
		_body.anim.play(_clip_name)
	_set_paused(true)
	_body.anim.seek(t, true)


func _set_paused(paused: bool) -> void:
	_paused = paused
	_pause.text = "Play" if paused else "Pause"
	_apply_speed()


func _apply_speed() -> void:
	if _body != null and _body.anim != null:
		_body.anim.speed_scale = 0.0 if _paused else _speed


func _process(delta: float) -> void:
	if _spin and _body != null:
		_yaw += delta * 0.5
		_place_camera()
	if _body == null or _body.anim == null or _clip_name == "" or not _body.anim.has_animation(_clip_name):
		return
	if not _body.anim.is_playing() and _repeat.button_pressed and not _paused:
		_body.anim.play(_clip_name)
	if _body.anim.is_playing():
		_time.set_value_no_signal(_body.anim.current_animation_position)
	_time_label.text = "%.2f / %.2f s" % [_time.value, _time.max_value]


func _place_camera() -> void:
	_cam.position = _target + Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, -_pitch) * Vector3(0, 0, _dist)
	_cam.look_at(_target)
	# the model shows beside the note, not under it (further right in the garden: no panel there)
	_cam.h_offset = -_dist * (0.45 if _side != null and not _side.visible else 0.18)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_spin = false  # you're turning it yourself now
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.008, -0.1, 1.4)
		_place_camera()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_dist *= 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
		_place_camera()
