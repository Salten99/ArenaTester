extends Control
## The start screen: choose your people (race), class and run length (your god
## is picked in the game, after the opening: Valley.offer_gods), continue a saved run, or open the practice arena. Runs play out in
## the valley scene. Everything is built in code; the look lives in the
## constants and the MenuBackdrop below.

const GOLD := UiStyle.GOLD
const PANEL := UiStyle.WOOD
const INK := UiStyle.TEXT
const MUTED := UiStyle.MUTED
const TITLE_FONTS := UiStyle.SERIF
const BODY_FONTS := UiStyle.SERIF
## The race the start screen suggests to a new player, already selected.
const RECOMMENDED := "dwarf"
## The race passives the game really runs. The others show as coming later.
const PASSIVES_BUILT := ["frog", "bird"]
## Race stat columns shown as bars, with their labels.
const STATS := [["hp_mod_pct", "Health"], ["melee_damage_mod_pct", "Melee"], ["missile_damage_mod_pct", "Missile"],
	["magic_damage_mod_pct", "Magic"], ["attack_speed_mod_pct", "Attack speed"], ["move_speed_mod_pct", "Move speed"],
	["stamina_mod_pct", "Stamina"]]

var _title_font: SystemFont
var _body_font: SystemFont
var _race := ""
var _weapon := ""
var _god := ""  ## your race's patron: the run starts with it until you pick a god after the opening
var _length := 0.34
var _details: VBoxContainer
var _weapon_row: HFlowContainer
var _length_row: HBoxContainer
var _preview: RacePreview
var _page: Control  ## the start screen itself; menus open on top of it
var _begin: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Run.player = null
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if Run.active:
		Flow.goto_valley()
		return
	_title_font = SystemFont.new()
	_title_font.font_names = PackedStringArray(TITLE_FONTS)
	_title_font.font_weight = 600
	_body_font = SystemFont.new()
	_body_font.font_names = PackedStringArray(BODY_FONTS)
	theme = _make_theme()
	var backdrop := MenuBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_build()
	var races: Array = Meta.data.races.filter(func(r): return not GameData.race(r).is_empty())
	_select_race(RECOMMENDED if RECOMMENDED in races else (races[0] if not races.is_empty() else ""))


# ---------------------------------------------------------------- layout

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36 if side in ["left", "right"] else 26)
	add_child(margin)
	_page = margin
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	# Title.
	var title := Label.new()
	title.text = "PANTHEON VALLEY"
	title.add_theme_font_override("font", _title_font)
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(0.98, 0.9, 0.7))
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 4)
	page.add_child(title)
	var tagline := _label("Choose your race, your weapon and your god.", 17, MUTED)
	tagline.add_theme_font_override("font", _title_font)
	page.add_child(tagline)
	var last: Dictionary = Run.last_result
	if last.get("fresh", false):
		last["fresh"] = false
		_show_recap.call_deferred(last)
	if not last.is_empty():
		var unlocked: Array = last.unlocked.map(func(u): return GameData.text(GameData.row(u.kind, u.id), "display_name", u.id))
		page.add_child(_label("Last run: %s.%s" % ["Victory" if last.victory else "Defeat",
			("  Unlocked: " + ", ".join(unlocked)) if not unlocked.is_empty() else ""], 15, GOLD))

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	page.add_child(columns)

	# Left: the races.
	var left := _panel(columns, 0.42)
	left.add_child(_heading("Choose your people  (click or %s / %s to turn)" % [OS.get_keycode_string(KEY_LEFT), OS.get_keycode_string(KEY_RIGHT)]))
	_preview = RacePreview.new()
	_preview.races = GameData.rows("races").map(func(r): return r.race_id).filter(
		func(id): return not id in GameData.START_HIDDEN_RACES)
	_preview.locked = _preview.races.filter(func(id): return not _playable(id))
	_preview.turned.connect(turn)
	left.add_child(_preview)
	_length_row = HBoxContainer.new()
	_length_row.add_theme_constant_override("separation", 8)
	left.add_child(_length_row)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	left.add_child(buttons)
	var begin := Button.new()
	_begin = begin
	begin.text = "Start Run"
	begin.custom_minimum_size = Vector2(0, 54)
	begin.add_theme_font_override("font", _title_font)
	begin.add_theme_font_size_override("font_size", 24)
	begin.add_theme_stylebox_override("normal", _box(Color(0.55, 0.36, 0.1, 0.95), GOLD, 2))
	begin.add_theme_stylebox_override("hover", _box(Color(0.7, 0.47, 0.15, 0.98), Color(1, 0.86, 0.5), 2))
	begin.add_theme_stylebox_override("pressed", _box(Color(0.45, 0.28, 0.08, 1.0), GOLD, 2))
	begin.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	begin.pressed.connect(_start_run)
	buttons.add_child(begin)
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 8)
	buttons.add_child(small)
	if SaveSystem.has_run():
		_small_button(small, "Continue saved run", _on_continue)
	_small_button(small, "Practice arena", open_practice_setup)
	_small_button(small, "Custom battle", open_battle_setup)
	_small_button(small, "Bestiary", func(): Bestiary.open(self))
	_small_button(small, "Controls", func(): ControlsMenu.open(self))
	_small_button(small, "Quit", get_tree().quit)

	# Right: the chosen race, then weapon, god and run length.
	var right := _panel(columns, 0.58)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 10)
	scroll.add_child(inner)
	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 6)
	inner.add_child(_details)
	inner.add_child(_heading("Class  (your melee weapon + sidearm; %s or the mouse wheel switches)" % Controls.binding_text("sidearm")))
	_weapon_row = HFlowContainer.new()
	inner.add_child(_weapon_row)
	inner.add_child(_label("Your god answers your call once you reach your village.", 14, MUTED))
	for option in [["Short  (about 20-30 min)", 0.34], ["Full  (60-90 min)", 1.0]]:
		var b := _chip(_length_row, option[0], "", _select_length.bind(option[1]))
		b.set_meta("value", option[1])
	_select_length(_length)


# ---------------------------------------------------------------- choices

func _select_race(race_id: String) -> void:
	_race = race_id
	var r := GameData.race(race_id)
	for c in _details.get_children():
		c.queue_free()
	var name := _label(GameData.text(r, "display_name", race_id) + ("  (recommended)" if race_id == RECOMMENDED else "")
		+ ("" if _playable(race_id) else "  (locked)"), 34, Color(1, 0.92, 0.75))
	_begin.disabled = not _playable(race_id)
	_begin.text = "Start Run" if _playable(race_id) else "Locked"
	name.add_theme_font_override("font", _title_font)
	_details.add_child(name)
	_details.add_child(_label(GameData.text(r, "short_description"), 16, INK))
	var lore := _label(GameData.text(r, "lore"), 14, MUTED)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_child(lore)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 12)
	for s in STATS:
		var stat_name := _label(s[1], 13, MUTED)
		stat_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		stat_name.custom_minimum_size = Vector2(110, 0)
		stats.add_child(stat_name)
		stats.add_child(_stat_bar(GameData.num(r, s[0])))
	_details.add_child(stats)
	var passive := GameData.text(r, "passive_description") + ("" if race_id in PASSIVES_BUILT else "  [i](not in the game yet)[/i]")
	_details.add_child(_ability("Passive", GameData.text(r, "passive_name"), passive))
	_details.add_child(_ability("Active", GameData.text(r, "active_name"), GameData.text(r, "active_description")))
	var mount: Array = GameData.where("mounts", "race_id", race_id)
	var home := GameData.text(GameData.row("valley_regions", GameData.text(r, "home_region")), "display_name")
	var extra: Array = []
	if not mount.is_empty():
		extra.append("Mount: " + GameData.text(mount[0], "display_name"))
	if home != "":
		extra.append("Homeland: " + home)
	_details.add_child(_label("   ·   ".join(extra), 13, GOLD))
	_god = ValleyGenerator.patron(race_id)
	if _god == "" and not GameData.rows("gods").is_empty():
		_god = GameData.rows("gods")[0].god_id
	_fill_weapons()


func _playable(race_id: String) -> bool:
	return race_id in GameData.PLAYABLE_RACES and Meta.is_unlocked("races", race_id)


## Turns the carousel one place left (-1) or right (1); the race now in front is chosen.
func turn(step: int) -> void:
	var ring := _preview.races
	if ring.is_empty():
		return
	_select_race(ring[posmod(ring.find(_race) + step, ring.size())])


func _input(event: InputEvent) -> void:
	if _page == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	for c in get_children().slice(_page.get_index() + 1):
		if c.visible:
			return  # a menu or dialog is open on top
	var step: int = {KEY_LEFT: -1, KEY_A: -1, KEY_RIGHT: 1, KEY_D: 1}.get(event.keycode, 0)
	if step != 0:
		turn(step)
		get_viewport().set_input_as_handled()


func _fill_weapons() -> void:
	for c in _weapon_row.get_children():
		c.queue_free()
	var options := GameData.weapon_options(_race)
	if not _weapon in options:
		_weapon = options[0] if not options.is_empty() else ""
	for w in options:
		var row := GameData.weapon(w)
		var side := GameData.text(GameData.weapon(GameData.sidearm_for(w)), "display_name")
		var b := _chip(_weapon_row, "%s  ·  %s + %s" % [GameData.text(row, "class_name", GameData.text(row, "display_name", w)), GameData.text(row, "display_name", w), side],
			GameData.text(row, "class_description", GameData.text(row, "short_description")), _select_weapon.bind(w))
		b.set_meta("value", w)
	_select_weapon(_weapon)


func _select_weapon(w: String) -> void:
	_weapon = w
	_mark(_weapon_row, w)
	_update_preview.call_deferred()


func _update_preview() -> void:
	_preview.show_choice(_race, _weapon, _god)


func _select_length(value: float) -> void:
	_length = value
	_mark(_length_row, value)


func _mark(row: Container, value) -> void:
	for c in row.get_children():
		if c is Button and c.has_meta("value"):
			c.button_pressed = c.get_meta("value") == value


func _start_run() -> void:
	if _race == "" or _god == "" or _weapon == "" or not _playable(_race):
		return
	if not SaveSystem.has_run():
		_begin_new_run()
		return
	var ask := ConfirmationDialog.new()
	ask.title = "Start a new run?"
	ask.dialog_text = "You have a saved run. Starting a new one replaces it for good."
	ask.ok_button_text = "Start new run"
	ask.cancel_button_text = "Keep my saved run"
	ask.confirmed.connect(_begin_new_run)
	add_child(ask)
	ask.popup_centered()


func _begin_new_run() -> void:
	SaveSystem.delete_run()  # a new run replaces the old save at once (user, 2026-11-10), not at its first autosave
	Run.start_new(_race, _god, -1, _length, _weapon)
	Flow.goto_valley()


# ---------------------------------------------------------------- practice arena

## Practice arena (user, 2026-11-17): any kept god and any dwarf class, to watch the
## animations and impact effects. Always a dwarf for now (Arena.START_RACE).
var practice_choice := {"god": Arena.START_GOD, "weapon": Arena.START_WEAPON}


func open_practice_setup() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var holder := HBoxContainer.new()
	holder.custom_minimum_size = Vector2(720, 0)
	center.add_child(holder)
	var box := _panel(holder, 1.0)
	box.add_child(_heading("Practice arena  (as a dwarf)"))
	box.add_child(_line("God", 15, GOLD))
	var god_row := HFlowContainer.new()
	box.add_child(god_row)
	for g in practice_gods():
		var row := GameData.god(g)
		var chip := _chip(god_row, "%s  ·  %s" % [GameData.text(row, "display_name", g), GameData.text(row, "element")],
			GameData.text(row, "short_description"), func(): practice_choice.god = g; _mark(god_row, g))
		chip.set_meta("value", g)
	_mark(god_row, practice_choice.god)
	box.add_child(_line("Class", 15, GOLD))
	var class_row := HFlowContainer.new()
	box.add_child(class_row)
	for w in GameData.weapon_options(Arena.START_RACE):
		var row := GameData.weapon(w)
		var chip := _chip(class_row, "%s  ·  %s" % [GameData.text(row, "class_name", w), GameData.text(row, "display_name", w)],
			GameData.text(row, "class_description"), func(): practice_choice.weapon = w; _mark(class_row, w))
		chip.set_meta("value", w)
	_mark(class_row, practice_choice.weapon)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_small_button(buttons, "Fight!", func(): Flow.goto_practice(practice_choice.god, practice_choice.weapon))
	_small_button(buttons, "Back", dim.queue_free)


## The gods you can practice with: every god not set aside (GameData.SHELVED_GODS).
static func practice_gods() -> Array:
	return GameData.rows("gods").map(func(r): return r.god_id).filter(func(g): return not g in GameData.SHELVED_GODS)


# ---------------------------------------------------------------- custom battle

## Custom battle (user, 2026-11-05): skip the run and fight one big battle. Pick how it's
## fought, where, and both armies' troops; you fight in your own army's line as the race,
## weapon and god chosen on this screen. Never touches your saved run or profile.
var battle_setup: Control
var battle_choice := {"scenario": "plain", "region": "grassland_steppe",
	"ours": {"race": "human", "counts": {"Melee": 20, "Ranged": 10, "Magic": 4, "Large": 2, "Cavalry": 6}},
	"theirs": {"race": "orc", "counts": {"Melee": 20, "Ranged": 10, "Magic": 4, "Large": 2, "Cavalry": 6}}}
const MAX_PER_ROLE := 60


func open_battle_setup() -> void:
	if _race != "":
		battle_choice.ours.race = _race
	battle_setup = ColorRect.new()
	(battle_setup as ColorRect).color = Color(0.02, 0.02, 0.04, 0.92)
	battle_setup.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(battle_setup)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_setup.add_child(center)
	var holder := HBoxContainer.new()
	holder.custom_minimum_size = Vector2(820, 0)
	center.add_child(holder)
	var box := _panel(holder, 1.0)
	box.add_child(_heading("Custom battle"))
	box.add_child(_label("You fight as the %s you picked, with your weapon and god, in your own army's line." % GameData.text(GameData.race(_race), "display_name", "race"), 14, MUTED))
	var scenario_row := HFlowContainer.new()
	box.add_child(scenario_row)
	for id in Valley.SCENARIOS:
		var chip := _chip(scenario_row, Valley.SCENARIOS[id], "", func(): battle_choice.scenario = id; _mark(scenario_row, id))
		chip.set_meta("value", id)
	_mark(scenario_row, battle_choice.scenario)
	var where := HBoxContainer.new()
	box.add_child(where)
	where.add_child(_line("Where:  ", 15, Color.WHITE))
	var regions := OptionButton.new()
	for r in GameData.rows("valley_regions"):
		regions.add_item(GameData.text(r, "display_name", r.region_id))
		regions.set_item_metadata(regions.item_count - 1, r.region_id)
		if r.region_id == battle_choice.region:
			regions.select(regions.item_count - 1)
	regions.item_selected.connect(func(i): battle_choice.region = regions.get_item_metadata(i))
	regions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	where.add_child(regions)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	box.add_child(grid)
	for title in ["", "Race"] + Valley.ROLES:
		grid.add_child(_line(title, 14, GOLD))
	for side in ["ours", "theirs"]:
		grid.add_child(_line("Your army" if side == "ours" else "Enemy army", 15, Color.WHITE))
		var race := OptionButton.new()
		var races: Array = GameData.rows("races").map(func(r): return [r.race_id, GameData.text(r, "display_name", r.race_id)])
		races.append([EvilTribe.HORDE, "Count Fuckula's horde"])
		for entry in races:
			race.add_item(entry[1])
			race.set_item_metadata(race.item_count - 1, entry[0])
			if entry[0] == battle_choice[side].race:
				race.select(race.item_count - 1)
		race.item_selected.connect(func(i): battle_choice[side].race = race.get_item_metadata(i))
		race.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		race.custom_minimum_size.x = 200
		grid.add_child(race)
		for role in Valley.ROLES:
			var count := SpinBox.new()
			count.min_value = 0
			count.max_value = MAX_PER_ROLE
			count.value = battle_choice[side].counts[role]
			count.value_changed.connect(func(n): battle_choice[side].counts[role] = int(n))
			count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(count)
	box.add_child(_label("Big armies are slower: about 150 soldiers in all runs well.", 13, MUTED))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_small_button(buttons, "Fight!", start_battle)
	_small_button(buttons, "Back", func(): battle_setup.queue_free())


## A one-line label (the table's headings and names shouldn't wrap).
func _line(text: String, size: int, color: Color) -> Label:
	var l := _label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func start_battle() -> void:
	if _race == "" or _god == "" or _weapon == "" or not _playable(_race):
		return
	Run.start_new(_race, _god, -1, 0.34, _weapon)
	Run.practice = true  # a throwaway run: no save, no profile
	Run.state.flags["battle"] = battle_choice.duplicate(true)
	Flow.goto_valley()


## The run's recap: how it went, in numbers (Run.note collects them as you play).
const RECAP := [["damage_dealt", "Damage dealt"], ["damage_taken", "Damage taken"], ["kills", "Enemies killed"],
	["distance", "Distance traveled"], ["encounters_won", "Fights won"], ["side_quests", "Side quests done"],
	["caves_and_towers", "Caves and towers cleared"], ["strongholds", "Strongholds taken"], ["seconds", "Time"]]


func _show_recap(last: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiStyle.parchment())
	sheet.custom_minimum_size = Vector2(520, 0)
	center.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	sheet.add_child(box)
	var head := Label.new()
	head.text = "Victory!" if last.get("victory", false) else "Your run is over"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_override("font", UiStyle.font(600))
	head.add_theme_font_size_override("font_size", 32)
	head.add_theme_color_override("font_color", UiStyle.INK)
	box.add_child(head)
	var who := Label.new()
	who.text = "%s of %s  ·  level %d  ·  %d godly gifts" % [GameData.text(GameData.race(last.get("race", "")), "display_name"),
		GameData.text(GameData.god(last.get("god", "")), "display_name"), int(last.get("level", 1)), int(last.get("gifts", 0))]
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_theme_color_override("font_color", UiStyle.INK)
	box.add_child(who)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	box.add_child(grid)
	var stats: Dictionary = last.get("stats", {})
	for row in RECAP:
		var v := float(stats.get(row[0], 0.0))
		var text := str(int(v))
		if row[0] == "distance":
			text = "%.1f km" % (v / 1000.0)
		elif row[0] == "seconds":
			text = "%d min" % int(v / 60.0)
		for cell in [row[1], text]:
			var l := Label.new()
			l.text = cell
			l.add_theme_color_override("font_color", UiStyle.INK)
			grid.add_child(l)
	var ok := Button.new()
	ok.text = "Onward"
	ok.pressed.connect(dim.queue_free)
	box.add_child(ok)


func _on_continue() -> void:
	if Run.resume():
		Flow.goto_valley()


# ---------------------------------------------------------------- pieces

func _make_theme() -> Theme:
	return UiStyle.theme()


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(6)
	b.set_content_margin_all(10)
	return b


func _panel(parent: Control, share: float) -> VBoxContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = share
	var style := _box(PANEL, Color(GOLD, 0.45), 1)
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


func _heading(text: String) -> Label:
	var l := _label(text.to_upper(), 14, GOLD)
	l.add_theme_font_override("font", _title_font)
	return l


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Plain titles like "Ratfolk Passive" or "Fire Special" say nothing the kind doesn't: they're left off.
func _ability(kind: String, name: String, description: String) -> RichTextLabel:
	var words := name.split(" ")
	if words[words.size() - 1] in ["Passive", "Active", "Special", "Movement", "Ultimate"]:
		name = ""
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", 14)
	r.add_theme_font_size_override("bold_font_size", 14)
	r.text = "[color=#%s]%s:[/color] [b]%s[/b]  %s" % [GOLD.to_html(false), kind, name, description]
	return r


## A bar for a % modifier: gold for a bonus, red for a penalty, longer = bigger.
func _stat_bar(value: float) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 30
	bar.value = clampf(absf(value), 0, 30)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD if value >= 0 else Color(0.8, 0.3, 0.25)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.08)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	row.add_child(bar)
	var amount := _label("%+d%%" % roundi(value) if value != 0 else "0", 13, MUTED)
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(amount)
	return row


func _chip(row: Container, text: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.tooltip_text = tip
	b.pressed.connect(action)
	row.add_child(b)
	return b


func _small_button(row: Container, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(action)
	row.add_child(b)


## The painted backdrop: a dusk sky, layers of mountains drifting slowly, the
## dark god's violet glow on the far horizon, and floating motes.
class MenuBackdrop:
	extends Control

	const LAYERS := [[0.32, Color(0.24, 0.2, 0.3), 0.004], [0.42, Color(0.17, 0.14, 0.22), 0.008],
		[0.54, Color(0.11, 0.09, 0.14), 0.014], [0.68, Color(0.06, 0.05, 0.08), 0.022]]
	var _time := 0.0
	var _ridges: Array = []
	var _motes: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for layer in LAYERS:
			var points: Array = []
			var h := 0.0
			for i in 64:
				h = clampf(h + rng.randf_range(-0.05, 0.05), -0.08, 0.08)
				points.append(h + rng.randf_range(-0.02, 0.02))
			_ridges.append(points)
		for i in 60:
			_motes.append([rng.randf(), rng.randf(), rng.randf_range(0.2, 1.0), rng.randf() * TAU])

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 4.0 or h < 4.0:
			return  # not laid out yet
		# Sky: indigo above, amber at the horizon.
		var steps := 24
		for i in steps:
			var k := float(i) / steps
			var c := Color(0.08, 0.07, 0.16).lerp(Color(0.85, 0.48, 0.25), pow(k, 1.8))
			draw_rect(Rect2(0, h * k * 0.7, w, h * 0.7 / steps + 1), c)
		draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color(0.05, 0.04, 0.07))
		# Setting sun and the dark god's violet glow far away.
		for r in range(6, 0, -1):
			draw_circle(Vector2(w * 0.72, h * 0.5), 30.0 * r, Color(1.0, 0.75, 0.4, 0.05))
		draw_circle(Vector2(w * 0.72, h * 0.5), 38.0, Color(1.0, 0.86, 0.55))
		for r in range(5, 0, -1):
			draw_circle(Vector2(w * 0.12, h * 0.46), 40.0 * r, Color(0.55, 0.2, 0.75, 0.04))
		# Mountain layers, nearer ones darker and drifting faster.
		for li in LAYERS.size():
			var layer: Array = LAYERS[li]
			var ridge: Array = _ridges[li]
			var shift: float = fmod(_time * layer[2], 1.0)
			# Two copies of the ridge side by side, so it can scroll forever; drawn
			# as simple four-sided strips down to the bottom of the screen.
			var n := ridge.size()
			for i in n * 2:
				var x0 := (float(i) / n - shift) * w
				var x1 := (float(i + 1) / n - shift) * w
				if x1 < 0.0 or x0 > w:
					continue
				var y0: float = minf(h * (layer[0] + 0.2 + ridge[i % n]), h - 2.0)
				var y1: float = minf(h * (layer[0] + 0.2 + ridge[(i + 1) % n]), h - 2.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1), Vector2(x1, h), Vector2(x0, h)]), layer[1])
			# A thin mist band above each layer.
			draw_rect(Rect2(0, h * (layer[0] + 0.2), w, 18), Color(0.9, 0.7, 0.6, 0.035))
		# Floating motes (embers and fireflies).
		for m in _motes:
			var x: float = fmod(m[0] + _time * 0.01 * m[2], 1.0) * w
			var y: float = (m[1] - fmod(_time * 0.02 * m[2], 1.0) + 1.0)
			y = fmod(y, 1.0) * h
			var a: float = 0.35 + 0.35 * sin(_time * 2.0 + m[3])
			draw_circle(Vector2(x, y), 1.5 + m[2] * 1.5, Color(1.0, 0.8, 0.45, a))
