extends Node
## Playtest numbers: how long you've played, deaths, kills and where a frame's time goes.
## F11 shows them on screen; events are also written to user://playtest_log.txt.
## The game reports events here; nothing here changes gameplay.

const LOG_PATH := "user://playtest_log.txt"

## Tests turn this off so they never write the real log.
var persist := true
var session_start := 0
var deaths := 0
var kills := 0
var _layer: CanvasLayer
var _label: Label
var _session_logged := false


func _ready() -> void:
	session_start = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Combat.killed.connect(_on_killed)
	_layer = CanvasLayer.new()
	_layer.layer = 60
	_layer.visible = false
	add_child(_layer)
	var panel := PanelContainer.new()
	panel.theme = UiStyle.theme()
	var style := UiStyle.panel()
	style.set_content_margin_all(10)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(16, 300)
	_layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("playtest_overlay"):
		_layer.visible = not _layer.visible


func _process(_delta: float) -> void:
	if _layer.visible:
		_label.text = summary()


## The overlay text.
func summary() -> String:
	var lines := ["PLAYTEST  (F11 hides)", "Session %s" % _clock((Time.get_ticks_msec() - session_start) / 1000.0)]
	lines.append("Deaths %d   ·   kills %d   ·   %d fps" % [deaths, kills, Engine.get_frames_per_second()])
	# Where a frame's time goes: scripts (_process), physics ticks (scripts + Jolt), and what is drawn.
	lines.append("Frame %.1f ms   ·   scripts %.1f   ·   physics %.1f   ·   draw calls %d   ·   units %d" % [
		1000.0 / maxf(Engine.get_frames_per_second(), 1.0), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), get_tree().get_nodes_in_group("enemies").size()])
	return "\n".join(lines)


func death() -> void:
	deaths += 1
	_log("died")


func _on_killed(target: Node, _info: DamageInfo) -> void:
	if target is Enemy:
		kills += 1


## A line in the playtest log from anywhere in the game.
func note_event(text: String) -> void:
	_log(text)


func _log(text: String) -> void:
	if not persist:
		return
	if not _session_logged:
		_session_logged = true  # one header per session that actually does something
		_log("session started")
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s  [%s]  %s" % [Time.get_datetime_string_from_system(), _clock((Time.get_ticks_msec() - session_start) / 1000.0), text])


static func _clock(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	return "%d:%02d" % [s / 60, s % 60]
