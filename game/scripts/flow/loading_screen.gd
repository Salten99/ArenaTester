class_name LoadingScreen
extends CanvasLayer
## Shown while the valley is built (first playtest: the window just froze for
## ~9 s). Flow builds the valley behind it a slice at a time; `report()` is
## awaited between slices so the bar and the step text redraw. Same dusk look
## as the start screen.

const TIPS := [
	"Ctrl dodges through enemies and cancels any attack.",
	"Press X to call your mount: it's far faster than running.",
	"Godly gifts from two gods can unlock a duo godly gift.",
	"The gods you meet give godly gifts that build on your own god's.",
	"Your tribe's warriors join every fight. Allies send more.",
	"Out of a fight you heal once nothing has hit you for a few seconds.",
	"M opens the map: the places you've found show on it, and on the compass.",
	"Count Fuckula's tribe pushes into a new region every few minutes.",
	"F11 shows playtest numbers: fight lengths, time to first fight, deaths.",
]
const RUN_DIRECTOR := preload("res://scripts/flow/run_director.gd")

var _bar: ProgressBar
var _step: Label
var _tip: Label
var _tip_time := 0.0
var _tip_index := 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UiStyle.theme()  # a CanvasLayer cuts off the window's theme: give it here
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var backdrop: Control = RUN_DIRECTOR.MenuBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = Vector2(-280, -90)
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(RUN_DIRECTOR.TITLE_FONTS)
	var title := _label("PANTHEON VALLEY", 54, RUN_DIRECTOR.GOLD)
	title.add_theme_font_override("font", title_font)
	box.add_child(title)
	_step = _label("Preparing the valley", 20, Color(0.92, 0.88, 0.8))
	box.add_child(_step)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(560, 14)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	var fill := UiStyle.fill(UiStyle.GOLD)
	fill.set_corner_radius_all(4)
	var back := UiStyle.trough()
	back.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
	_tip = _label("", 16, Color(0.75, 0.72, 0.8))
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_tip)
	_tip_index = randi() % TIPS.size()
	_tip.text = TIPS[_tip_index]


func _process(delta: float) -> void:
	_tip_time += delta
	if _tip_time > 4.0:
		_tip_time = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		_tip.text = TIPS[_tip_index]


## Shows progress (0-1) and the current step. Await the returned signal to let
## the screen redraw before the next slice of work.
func report(fraction: float, step := "") -> Signal:
	_bar.value = fraction
	if step != "":
		_step.text = step
	return get_tree().process_frame


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 6)
	return l
