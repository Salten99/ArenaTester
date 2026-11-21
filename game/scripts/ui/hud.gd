class_name Hud
extends CanvasLayer
## On-screen info: health, stamina, abilities, wave, FPS, messages and the debug key help (F1).

var player: Player
var waves: WaveDirector
var director: CrowdDirector
## Shown at the top when no waves are running ("" in the valley between fights).
var idle_text := "Practice"

var _reticle: Control
var _charge: ColorRect
var _charge_fill: ColorRect
## A boss's health along the top while it fights near you (user, 2026-11-05).
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var boss: Enemy
var _boss_look := 0.0
const BOSS_RANGE := 50.0
var _dot: ColorRect
var _hp_bar: ProgressBar
var _stamina_bar: ProgressBar
var _hp_label: Label
var _abilities: Label
var _wave: Label
var _stats: Label
var _message: Label
var _help: Label

const HELP := """WASD move  ·  Shift sprint  ·  Space jump  ·  Mouse side button slide  ·  Ctrl dodge
LMB light combo  ·  RMB heavy slam
Q special  ·  E movement  ·  R ultimate  ·  V race skill  ·  G throw your weapon (hold for force)  ·  T first person
P god mode  ·  Esc menu

Debug:  F1 this help  ·  F2 spawn 10 skeletons  ·  F3 spawn a cyclops
F6 god mode (fly: Space / Ctrl)  ·  F7 kill all  ·  F8 skip to next wave  ·  F9 restart
F11 playtest numbers (deaths, kills, frame time; deaths also logged to playtest_log.txt)"""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UiStyle.theme()  # a CanvasLayer cuts off the window's theme: give it here
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# A parchment scroll in the top right (UiStyle): who you are, health, stamina.
	var scroll := PanelContainer.new()
	scroll.add_theme_stylebox_override("panel", UiStyle.parchment())
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(scroll, Vector2(1.0, 0.0), Rect2(-400, 22, 380, 118))
	root.add_child(scroll)
	for rod_y in [14.0, 136.0]:  # the scroll's wooden rods, top and bottom
		var rod := Panel.new()
		rod.add_theme_stylebox_override("panel", UiStyle.box(Color(0.3, 0.19, 0.09), Color(0.16, 0.09, 0.03), 2, 3, 0))
		rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(rod, Vector2(1.0, 0.0), Rect2(-410, rod_y, 400, 12))
		root.add_child(rod)
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	scroll.add_child(bottom)
	_hp_label = _ink(_label(bottom, "", 17), true)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_bar = _bar(bottom, UiStyle.BLOOD)
	_hp_bar.custom_minimum_size = Vector2(340, 15)
	_stamina_bar = _bar(bottom, UiStyle.STAMINA)
	_stamina_bar.custom_minimum_size = Vector2(340, 9)

	_wave = UiStyle.title(_label(root, "", 22), 22)
	_place(_wave, Vector2(0.5, 0.0), Rect2(-200, 38, 400, 30))  # under the valley's compass
	_wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var dot := ColorRect.new()  # the crosshair: only while something is aimed (Player.crosshair_shown)
	dot.color = Color(1.0, 1.0, 1.0, 0.75)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)
	_place(dot, Vector2(0.5, 0.5), Rect2(-2, -2, 4, 4))
	_dot = dot
	# With a bow or spell weapon, a gold reticle around it: four arms with a gap (user, 2026-11-05).
	_reticle = Control.new()
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_reticle)
	_place(_reticle, Vector2(0.5, 0.5), Rect2(0, 0, 0, 0))
	for arm in [Rect2(-16, -1.5, 9, 3), Rect2(7, -1.5, 9, 3), Rect2(-1.5, -16, 3, 9), Rect2(-1.5, 7, 3, 9)]:
		var shade := ColorRect.new()
		shade.color = Color(0.05, 0.03, 0.01, 0.8)
		shade.position = arm.position - Vector2(1, 1)
		shade.size = arm.size + Vector2(2, 2)
		_reticle.add_child(shade)
		var line := ColorRect.new()
		line.color = UiStyle.GOLD
		line.position = arm.position
		line.size = arm.size
		_reticle.add_child(line)

	# The heavy's charge bar under the crosshair (combat feel plan, 2026-11-18): only while you
	# charge, filling red, then orange, then yellow.
	_charge = ColorRect.new()
	_charge.color = Color(0.05, 0.03, 0.01, 0.8)
	_charge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_charge)
	_place(_charge, Vector2(0.5, 0.5), Rect2(-32, 26, 64, 7))
	_charge_fill = ColorRect.new()
	_charge_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_fill.position = Vector2(1, 1)
	_charge_fill.size = Vector2(0, 5)
	_charge.add_child(_charge_fill)
	_charge.visible = false

	_stats = _label(root, "", 14)
	_place(_stats, Vector2(1.0, 0.0), Rect2(-260, 160, 240, 80))
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats.visible = false  # the test numbers show with the F1 help, or in god mode

	_abilities = _label(root, "", 15)
	_place(_abilities, Vector2(0.5, 1.0), Rect2(-450, -46, 900, 30))
	_abilities.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_message = UiStyle.title(_label(root, "", 34), 34)
	_place(_message, Vector2(0.5, 0.5), Rect2(-500, -200, 1000, 50))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_help = _label(root, HELP, 15)
	_place(_help, Vector2(0.0, 1.0), Rect2(20, -190, 900, 150))
	_help.visible = false

	_boss_box = VBoxContainer.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_boss_box, Vector2(0.5, 0.0), Rect2(-280, 64, 560, 50))
	root.add_child(_boss_box)
	_boss_name = UiStyle.title(_label(_boss_box, "", 20), 20)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_bar = _bar(_boss_box, UiStyle.BLOOD)
	_boss_bar.custom_minimum_size = Vector2(560, 14)
	_boss_box.visible = false


## The boss fighting near you: a boss or mini boss (by its sheet role) that's after you.
func _find_boss() -> Enemy:
	var best: Enemy = null
	var best_d := BOSS_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		var u: Enemy = e as Enemy
		if u == null or u.is_dead():
			continue
		var big := GameData.text(u.unit, "role") in ["Boss", "Miniboss"]
		if not big or u.target == null:
			continue
		var d := u.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_boss_look -= delta
	if _boss_look <= 0.0:
		_boss_look = 0.25
		boss = _find_boss()
	_boss_box.visible = boss != null and is_instance_valid(boss) and not boss.is_dead()
	if _boss_box.visible:
		_boss_name.text = GameData.text(boss.unit, "display_name", boss.unit_id)
		_boss_bar.max_value = boss.health.max_hp
		_boss_bar.value = boss.health.hp
	_reticle.visible = player.crosshair_shown()
	_dot.visible = _reticle.visible
	var charge: float = player.charge_shown()
	_charge.visible = charge >= 0.0
	if _charge.visible:
		_charge_fill.size.x = 62.0 * charge
		_charge_fill.color = Color(0.85, 0.12, 0.08) if charge < 0.34 else (Color(0.95, 0.5, 0.1) if charge < 0.67 else Color(1.0, 0.85, 0.2))
	# Spells hit anything in the wider circle: their reticle is that wide.
	_hp_bar.max_value = player.health.max_hp
	_hp_bar.value = player.health.hp
	_hp_label.text = "%s of %s   %d / %d" % [GameData.text(GameData.race(player.race_id), "display_name"),
		GameData.text(GameData.god(player.god_id), "display_name"), ceili(player.health.hp), ceili(player.health.max_hp)]
	_stamina_bar.max_value = player.max_stamina
	_stamina_bar.value = player.stamina
	var parts: Array = []
	for slot in [["Q", "Signature"], ["E", "Movement"], ["R", "Ultimate"]]:
		var a: Dictionary = player.abilities.defs.get(slot[1], {})
		var left: float = player.abilities.ready_in(slot[1])
		parts.append("[%s] %s %s" % [slot[0], GameData.text(a, "display_name", slot[1]), "ready" if left <= 0.0 else "%.0fs" % ceilf(left)])
	if player.race_active != null:
		var left: float = player.race_active.cooldown
		parts.append("[V] %s %s" % [player.race_active.title(), "ready" if left <= 0.0 else "%.0fs" % ceilf(left)])
	parts.append("Fists: walk over a weapon to take it" if player.weapon_id == GameData.FISTS
		else "[G] Throw the %s" % GameData.text(player.weapon(), "display_name", player.weapon_id))
	_abilities.text = "   ".join(parts)
	if waves != null:
		if waves.wave < 0:
			_wave.text = "" if idle_text == "" else "%s   ·   %d enemies" % [idle_text, waves.alive()]
		else:
			_wave.text = "Wave %d   ·   %d enemies" % [waves.wave + 1, waves.alive()]
	_stats.visible = _help.visible or player.god_mode
	_stats.text = "%d FPS\nattackers %d / %d\nseed %d%s" % [Engine.get_frames_per_second(),
		director.attackers() if director != null else 0, GameData.tuning.max_attackers, RunRng.seed_value,
		"\nGOD MODE" if player.god_mode else ""]


var _screen_flash: ColorRect


## One frame of color over the whole screen, fading fast (the crush's red flash, user 2026-11-18).
func flash(color: Color, seconds := 0.12) -> void:
	if _screen_flash == null:
		_screen_flash = ColorRect.new()
		_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_screen_flash)
	_screen_flash.color = color
	_screen_flash.visible = true
	var tw := _screen_flash.create_tween()
	tw.tween_property(_screen_flash, "color:a", 0.0, seconds)
	tw.tween_callback(func(): _screen_flash.visible = false)


func show_message(text: String, seconds := 2.5) -> void:
	_message.text = text
	if seconds > 0.0:
		get_tree().create_timer(seconds, true, false, true).timeout.connect(_clear_message.bind(text))


func _clear_message(text: String) -> void:
	if _message.text == text:
		_message.text = ""


func toggle_help() -> void:
	_help.visible = not _help.visible


## A big button in the middle of the screen (e.g. "Try again").
func show_action(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	_place(b, Vector2(0.5, 0.5), Rect2(-180, 60, 360, 56))
	b.pressed.connect(action)
	get_node("Root").add_child(b)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	b.grab_focus()


## Pins a control to a screen point (0..1 on each axis) with a pixel rect relative to it.
func _place(c: Control, anchor: Vector2, rect: Rect2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = rect.position.x
	c.offset_top = rect.position.y
	c.offset_right = rect.position.x + rect.size.x
	c.offset_bottom = rect.position.y + rect.size.y


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Dark ink on the parchment scroll, bold for the title line.
func _ink(l: Label, bold: bool) -> Label:
	if bold:
		l.add_theme_font_override("font", UiStyle.font(600))
	l.add_theme_color_override("font_color", UiStyle.INK)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l


func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(620, 16)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", UiStyle.fill(color))
	bar.add_theme_stylebox_override("background", UiStyle.trough())
	parent.add_child(bar)
	return bar
