extends Node
## Playtest numbers (Council V): how long you've played, how long until the first
## fight, how long each fight took against its target, deaths, kills and the
## regions you walked through. F11 shows them on screen; every event is also
## written to user://playtest_log.txt, i.e.
##   %APPDATA%\Godot\app_userdata\Pantheon Valley\playtest_log.txt
## so the playtest-reader agent can work from real numbers, not just notes.
## The game reports events here (Arena, Valley); nothing here changes gameplay.

const LOG_PATH := "user://playtest_log.txt"
## Fights kept for the on-screen list.
const SHOWN_FIGHTS := 4

## Tests turn this off so they never write the real log.
var persist := true
var session_start := 0
var run_start := -1
var first_fight_after := -1.0  ## seconds from the run's start to its first fight (-1 = none yet)
var fights: Array = []         ## [{id, name, seconds, target, won}], newest last
var deaths := 0
var kills := 0
var _fight_id := ""
var _fight_start := 0
var _layer: CanvasLayer
var _label: Label
var _session_logged := false
## Frame times during the current fight (PERFORMANCE_PLAN Phase 0): logged when it ends.
var _frames := 0
var _frame_sum := 0.0
var _frame_worst := 0.0
var _fight_secs := 0.0  ## this fight's play time, menus left out
var _worst_at := 0.0  ## seconds into the fight
var _script_sum := 0.0
var _physics_sum := 0.0
var _peak_foes := 0
var _peak_friends := 0
var _peak_draws := 0


func _ready() -> void:
	session_start = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Run.run_started.connect(_on_run_started)
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


func _process(delta: float) -> void:
	if _fight_id != "" and not get_tree().paused:
		_fight_secs += delta  # menus pause the fight: a level-up screen isn't fight time
		_frames += 1
		_frame_sum += delta
		if delta > _frame_worst:
			_frame_worst = delta
			_worst_at = _fight_secs
		_script_sum += Performance.get_monitor(Performance.TIME_PROCESS)
		_physics_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		if _frames % 15 == 1:  # counting walks every unit: a few times a second is enough
			_peak_foes = maxi(_peak_foes, awake("enemies"))
			_peak_friends = maxi(_peak_friends, awake("allies"))
		_peak_draws = maxi(_peak_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _layer.visible:
		_label.text = summary()


## The overlay text.
func summary() -> String:
	var now := Time.get_ticks_msec()
	var lines := ["PLAYTEST  (F11 hides)", "Session %s%s" % [_clock((now - session_start) / 1000.0),
		"   ·   run %s" % _clock((now - run_start) / 1000.0) if run_start >= 0 else ""]]
	lines.append("First fight after %s" % _clock(first_fight_after) if first_fight_after >= 0.0 else "No fight yet this run")
	if _fight_id != "":
		lines.append("Fighting: %s" % _clock(_fight_secs))
	for f in fights.slice(maxi(0, fights.size() - SHOWN_FIGHTS)):
		lines.append("%s  %s / target %s%s" % [f.name, _clock(f.seconds), _clock(f.target), "" if f.won else "  (lost)"])
	lines.append("Deaths %d   ·   kills %d   ·   %d fps" % [deaths, kills, Engine.get_frames_per_second()])
	# Where a frame's time goes: scripts (_process), physics ticks (scripts + Jolt), and what is drawn.
	lines.append("Frame %.1f ms   ·   scripts %.1f   ·   physics %.1f   ·   draw calls %d   ·   units %d" % [
		1000.0 / maxf(Engine.get_frames_per_second(), 1.0), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), awake("enemies") + awake("allies")])
	return "\n".join(lines)


## Units of a group that are awake (far villages sleep, Enemy.set_dormant, and cost nothing).
func awake(group: String) -> int:
	var n := 0
	for u in get_tree().get_nodes_in_group(group):
		if u.can_process():
			n += 1
	return n


# ---------------------------------------------------------------- events (called by the game)

func fight_started(encounter_id: String) -> void:
	_fight_id = encounter_id
	_fight_start = Time.get_ticks_msec()
	_fight_secs = 0.0
	_frames = 0
	_frame_sum = 0.0
	_frame_worst = 0.0
	_worst_at = 0.0
	_script_sum = 0.0
	_physics_sum = 0.0
	_peak_foes = 0
	_peak_friends = 0
	_peak_draws = 0
	if first_fight_after < 0.0 and run_start >= 0:
		first_fight_after = (_fight_start - run_start) / 1000.0
	_log("fight started: %s" % _encounter_name(encounter_id))


func fight_ended(encounter_id: String, won: bool) -> void:
	if _fight_id == "":
		return
	var def := _encounter_def(encounter_id)
	var f := {"id": encounter_id, "name": _encounter_name(encounter_id), "seconds": _fight_secs,
		"target": GameData.num(def, "target_minutes", 0.0) * 60.0, "won": won}
	fights.append(f)
	_fight_id = ""
	_log("fight %s: %s in %.0f s (target %.0f s)" % ["won" if won else "lost", f.name, f.seconds, f.target])
	if _frames > 0:
		_log("  frames: average %.1f ms (%.0f fps; scripts %.1f, physics %.1f), worst %.0f ms at %s, up to %d enemies and %d allies awake, %d draw calls (%s build)" % [
			_frame_sum / _frames * 1000.0, _frames / maxf(_frame_sum, 0.001), _script_sum / _frames * 1000.0, _physics_sum / _frames * 1000.0,
			_frame_worst * 1000.0, _clock(_worst_at), _peak_foes, _peak_friends, _peak_draws, "debug" if OS.is_debug_build() else "release"])


func death() -> void:
	deaths += 1
	if _fight_id != "":
		fight_ended(_fight_id, false)
	_log("died")


func region_entered(region_name: String) -> void:
	_log("entered %s" % region_name)


func _on_run_started() -> void:
	run_start = Time.get_ticks_msec()
	first_fight_after = -1.0
	var s: RunState = Run.state
	_log("run started: %s, %s, %s (seed %d)" % [s.race_id, s.weapon_id, s.god_id, s.seed])


func _on_killed(target: Node, _info: DamageInfo) -> void:
	if target is Enemy and (target as Enemy).team == Enemy.Team.HOSTILE:
		kills += 1


# ---------------------------------------------------------------- helpers

func _encounter_def(encounter_id: String) -> Dictionary:
	if Run.state == null:
		return {}
	return GameData.row("encounters", Run.state.encounters.get(encounter_id, {}).get("def", ""))


func _encounter_name(encounter_id: String) -> String:
	return GameData.text(_encounter_def(encounter_id), "display_name", encounter_id)


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


## A line in the playtest log from anywhere in the game (e.g. why you came off your mount).
func note_event(text: String) -> void:
	_log(text)
