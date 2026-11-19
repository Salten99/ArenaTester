class_name UiStyle
extends RefCounted
## The game's look for every screen (user, 2026-11-05: in the spirit of old fantasy RPGs and
## strategy games): dark carved-wood panels with a bronze edge, gold titles, parchment for maps
## and lists, a book serif everywhere, framed bars. Flow puts theme() on the game window, so
## every menu, HUD and tool gets it; pieces that draw themselves use the colors and boxes here.

const WOOD := Color(0.13, 0.1, 0.07, 0.93)       ## panels
const WOOD_LIGHT := Color(0.27, 0.2, 0.13, 0.96) ## buttons
const RECESS := Color(0.06, 0.05, 0.04, 0.9)     ## fields, lists, bar troughs
const BRONZE := Color(0.58, 0.44, 0.22)          ## edges
const GOLD := Color(0.93, 0.77, 0.42)            ## titles, highlights
const TEXT := Color(0.94, 0.89, 0.76)            ## text on wood
const MUTED := Color(0.72, 0.66, 0.55)
const PARCHMENT := Color(0.86, 0.79, 0.62)
const INK := Color(0.2, 0.14, 0.08)              ## text on parchment
const BLOOD := Color(0.72, 0.12, 0.1)            ## health
const STAMINA := Color(0.42, 0.62, 0.25)         ## stamina
const SERIF := ["Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman"]

static var _theme: Theme
static var _fonts := {}


## The book serif; `weight` 600 for titles.
static func font(weight := 400) -> SystemFont:
	if not _fonts.has(weight):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(SERIF)
		f.font_weight = weight
		_fonts[weight] = f
	return _fonts[weight]


## A box: `bg` inside, `edge` around it, `width` thick, with a soft shadow below.
static func box(bg: Color, edge := BRONZE, width := 2, shadow := 6, margin := 10.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(3)
	b.shadow_color = Color(0, 0, 0, 0.45)
	b.shadow_size = shadow
	b.set_content_margin_all(margin)
	return b


static func panel() -> StyleBoxFlat:
	return box(WOOD, BRONZE, 2, 8, 14)


static func parchment() -> StyleBoxFlat:
	return box(PARCHMENT, Color(0.45, 0.32, 0.16), 3, 8, 14)


## A bar's fill: the color, with a darker rim so it reads as set into the frame.
static func fill(color: Color) -> StyleBoxFlat:
	var b := box(color, color.darkened(0.45), 1, 0, 0)
	b.set_corner_radius_all(2)
	return b


static func trough() -> StyleBoxFlat:
	var b := box(RECESS, BRONZE, 2, 3, 0)
	b.set_corner_radius_all(2)
	return b


## Gold title text.
static func title(l: Label, size := 24) -> Label:
	l.add_theme_font_override("font", font(600))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16
	for kind in ["Label", "Button", "CheckBox", "CheckButton", "OptionButton", "LineEdit", "TextEdit", "ItemList", "SpinBox", "RichTextLabel", "PopupMenu", "TooltipLabel", "MenuButton"]:
		t.set_color("font_color", kind, TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	for kind in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", kind, box(WOOD_LIGHT, BRONZE, 2, 3, 8))
		t.set_stylebox("hover", kind, box(WOOD_LIGHT.lightened(0.12), GOLD, 2, 4, 8))
		t.set_stylebox("pressed", kind, box(WOOD_LIGHT.darkened(0.3), GOLD, 2, 1, 8))
		t.set_stylebox("hover_pressed", kind, box(WOOD_LIGHT.darkened(0.15), GOLD, 2, 2, 8))
		t.set_stylebox("disabled", kind, box(Color(WOOD_LIGHT.darkened(0.4), 0.8), Color(BRONZE, 0.5), 2, 0, 8))
		t.set_stylebox("focus", kind, box(Color(0, 0, 0, 0), Color(GOLD, 0.8), 1, 0, 8))
		t.set_color("font_hover_color", kind, Color(1.0, 0.95, 0.8))
		t.set_color("font_pressed_color", kind, GOLD)
		t.set_color("font_hover_pressed_color", kind, GOLD)
		t.set_color("font_disabled_color", kind, Color(MUTED, 0.6))
	for kind in ["PanelContainer", "Panel", "PopupPanel", "PopupMenu", "AcceptDialog", "ConfirmationDialog"]:
		t.set_stylebox("panel", kind, panel())
	t.set_stylebox("embedded_border", "Window", panel())
	t.set_color("title_color", "Window", GOLD)
	t.set_font("title_font", "Window", font(600))
	t.set_stylebox("panel", "TooltipPanel", box(WOOD, GOLD, 1, 4, 8))
	for kind in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", kind, box(RECESS, BRONZE, 1, 0, 6))
		t.set_stylebox("focus", kind, box(RECESS, GOLD, 1, 0, 6))
		t.set_color("font_placeholder_color", kind, Color(MUTED, 0.6))
		t.set_color("caret_color", kind, GOLD)
	t.set_stylebox("panel", "ItemList", box(RECESS, BRONZE, 1, 0, 6))
	t.set_stylebox("selected", "ItemList", box(Color(BRONZE, 0.45), GOLD, 1, 0, 2))
	t.set_stylebox("selected_focus", "ItemList", box(Color(BRONZE, 0.55), GOLD, 1, 0, 2))
	t.set_stylebox("hovered", "ItemList", box(Color(BRONZE, 0.2), Color(0, 0, 0, 0), 0, 0, 2))
	t.set_color("font_selected_color", "ItemList", GOLD)
	t.set_color("guide_color", "ItemList", Color(BRONZE, 0.25))
	t.set_stylebox("background", "ProgressBar", trough())
	t.set_stylebox("fill", "ProgressBar", fill(GOLD))
	t.set_stylebox("grabber", "VScrollBar", box(BRONZE, BRONZE.darkened(0.4), 1, 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(GOLD, BRONZE, 1, 0, 0))
	t.set_stylebox("scroll", "VScrollBar", box(RECESS, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("grabber", "HScrollBar", box(BRONZE, BRONZE.darkened(0.4), 1, 0, 0))
	t.set_stylebox("scroll", "HScrollBar", box(RECESS, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("slider", "HSlider", trough())
	_theme = t
	return t
