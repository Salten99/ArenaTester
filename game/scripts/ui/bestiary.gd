class_name Bestiary
extends PanelContainer
## The bestiary (user, 2026-11-06): every creature you've discovered across your runs, by
## coming near it or killing it (Meta codex "creature:<id>").
## The rest show as "???". Opened from the start screen and the Esc menu; works while paused.

signal closed

const PREVIEW_SIZE := 2.6  ## creatures are scaled to fit this on the stage (m)
const FACTION_ORDER := ["Animal", "Neutral", "Beast", "Barbarian", "Horde"]

var _info: Label
var _title: Label
var _stage: Node3D
var _spin: Node3D


static func open(parent: Node) -> Bestiary:
	var b := Bestiary.new()
	parent.add_child(b)
	return b


static func is_discovered(unit_id: String) -> bool:
	return ("creature:" + unit_id) in Meta.data.codex


## Every creature in the book, grouped by faction then name.
static func creatures() -> Array:
	var rows: Array = GameData.rows("barbarians_beasts").duplicate()
	for id in EndlessArena.HITS_TO_KILL:  # the waves' foes from the army sheet (the minotaur)
		if not GameData.row("army_units", id).is_empty():
			rows.append(GameData.row("army_units", id))
	rows.sort_custom(func(a, b):
		var fa := FACTION_ORDER.find(GameData.text(a, "faction"))
		var fb := FACTION_ORDER.find(GameData.text(b, "faction"))
		return fa < fb if fa != fb else GameData.text(a, "display_name") < GameData.text(b, "display_name"))
	return rows


func _ready() -> void:
	theme = UiStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var style := UiStyle.panel()
	style.set_content_margin_all(20)
	add_theme_stylebox_override("panel", style)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -520
	offset_right = 520
	offset_top = -330
	offset_bottom = 330
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var all := creatures()
	var found := all.filter(func(r): return is_discovered(r.unit_id)).size()
	_title = Label.new()
	_title.text = "Bestiary   ·   %d of %d creatures discovered" % [found, all.size()]
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	box.add_child(_title)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	box.add_child(cols)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var faction := ""
	var first := ""
	for r in all:
		if GameData.text(r, "faction") != faction:
			faction = GameData.text(r, "faction")
			var head := Label.new()
			head.text = faction
			head.modulate = Color(0.95, 0.8, 0.45)
			list.add_child(head)
		var b := Button.new()
		var known := is_discovered(r.unit_id)
		b.text = GameData.text(r, "display_name", r.unit_id) if known else "???"
		b.disabled = not known
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_show.bind(r.unit_id))
		list.add_child(b)
		if known and first == "":
			first = r.unit_id
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.custom_minimum_size = Vector2(0, 300)
	right.add_child(view)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	view.add_child(vp)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(0.0, 1.5, 7.0)
	vp.add_child(cam)
	cam.look_at(Vector3(0.0, 1.0, 0.0))
	_stage = Node3D.new()
	vp.add_child(_stage)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.text = "Nothing discovered yet. Creatures go in the book when you come near them or kill one." if first == "" else ""
	right.add_child(_info)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size.y = 38
	done.pressed.connect(_close)
	box.add_child(done)
	if first != "":
		_show(first)


func _process(delta: float) -> void:
	if is_instance_valid(_spin):
		_spin.rotation.y += delta * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()


## One creature: its model turning on the stage and what's known of it.
func _show(unit_id: String) -> void:
	var r := GameData.unit(unit_id)
	var behavior := GameData.text(r, "behavior")
	_info.text = "%s\n%s · %s\n\n%s\n\nHealth %d   ·   Hits for %d (%s)   ·   Speed %.1f\n%s" % [
		GameData.text(r, "display_name", unit_id), GameData.text(r, "faction"), GameData.text(r, "role"), GameData.text(r, "description"),
		int(GameData.num(r, "hp")), int(GameData.num(r, "damage")), GameData.text(r, "damage_type", "Physical"), GameData.num(r, "move_speed"),
		behavior]
	for c in _stage.get_children():
		c.free()
	_spin = Node3D.new()
	_stage.add_child(_spin)
	var model := _model_for(unit_id)
	if model == null:
		return
	var box := CharacterModel.bounds(model)
	var longest := box.get_longest_axis_size()
	if longest > 0.01:
		model.scale = Vector3.ONE * minf(PREVIEW_SIZE / longest, 3.0)
		box = CharacterModel.bounds(model)
		model.position.y -= box.position.y


func _model_for(unit_id: String) -> Node3D:
	var beast: Dictionary = ModelRegistry.for_beast(unit_id) if unit_id.begins_with("beast_") or unit_id.begins_with("animal_") or ModelRegistry.BEASTS.has(unit_id) else {}
	if not beast.is_empty():
		var b := BeastModel.new()
		_spin.add_child(b)
		if b.setup_beast(beast.model, beast.scale):
			b.play("Idle_A")
			return b
		b.queue_free()
		return null
	var look := ModelRegistry.for_unit(unit_id)
	if look.is_empty():
		return null
	var m := CharacterModel.new()
	_spin.add_child(m)
	if m.setup(look.model, look.get("weapon", "")):
		m.play("Idle_A")
		return m
	m.queue_free()
	return null
