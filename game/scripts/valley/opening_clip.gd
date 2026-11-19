class_name OpeningClip
extends Node
## The run's opening (user, 2026-11-08): a short clip, no fight. You walk home up the road (kept
## clear of trees, so the village is in view; over the hill if there's no road) and find your
## village burning, its houses wrecked by Count Fuckula's raid. At most LENGTH seconds;
## any key skips it. Then the village elder tells you to go and defeat him (Valley._after_opening).

signal finished

const LENGTH := 18.0  ## seconds at most
const BEHIND_CREST := 22.0  ## with no road: you start this far behind the hill's top
const ROAD_START := 100.0  ## up the road: you start this far along it from the village (m)
const STOP_AT := 28.0  ## the clip ends this close to the village's middle (inside its walls)
const FADE := 1.0  ## seconds of fade to black at the end

var valley: Valley
var _village: Village
var _time := 0.0
var _yaw := 0.0
var _saved_input: Object
var _black: ColorRect
var _done := false
var _path: Array = []  ## points (Vector3, flat) to walk through, the village last


func _ready() -> void:
	var player: Player = valley.player
	_village = valley.villages.get(Run.state.race_id)
	_path = _road_home()
	if _path.is_empty():  # no road: over the hill
		var crest: Vector3 = valley._hill_over_camp()
		var home := _village.global_position if _village != null else crest + Vector3.FORWARD * 100.0
		var dir := Vector3(home.x - crest.x, 0.0, home.z - crest.z).normalized()
		_path = [crest - dir * BEHIND_CREST, home]
	var start: Vector3 = _path.pop_front()
	player.global_position = Vector3(start.x, valley.terrain.height(start.x, start.z) + 1.0, start.z)
	_aim()
	player.facing = Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	player.rotation.y = _yaw
	valley.camera_rig.yaw = _yaw
	valley.camera_rig.pitch = -0.1
	valley.camera_rig.snap_to_target()
	_saved_input = player.input_source
	player.input_source = self  # you walk on your own
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # the mouse doesn't turn the camera
	valley.cinematic = true  # no HUD
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)


## The road from your village, from ROAD_START along it to the village (flat points), or [].
func _road_home() -> Array:
	var home: String = valley.home_region()
	for road in valley.terrain.roads:
		if road.a != home and road.b != home:
			continue
		var line: PackedVector2Array = road.line
		var pts: Array = Array(line).map(func(q: Vector2): return Vector3(q.x, 0.0, q.y))
		if road.b != home:
			pts.reverse()  # now it ends at your village
		var out: Array = [pts[-1]]
		var walked := 0.0
		for i in range(pts.size() - 2, -1, -1):
			var step: float = (pts[i + 1] as Vector3).distance_to(pts[i])
			if walked + step >= ROAD_START:
				out.push_front((pts[i + 1] as Vector3).lerp(pts[i], (ROAD_START - walked) / step))
				return out
			walked += step
			out.push_front(pts[i])
		return out
	return []


## Heads for the next point, the camera turning with you.
func _aim() -> void:
	var here := valley.player.global_position
	while _path.size() > 1 and Vector2(_path[0].x - here.x, _path[0].z - here.z).length() < 4.0:
		_path.pop_front()
	if _path.is_empty():
		return
	var to := Vector3(_path[0].x - here.x, 0.0, _path[0].z - here.z)
	if to.length() > 0.5:
		_yaw = atan2(-to.x, -to.z)


## The player's input while the clip plays: walking toward the village.
func read() -> PlayerIntent:
	var i := PlayerIntent.new()
	i.aim_yaw = _yaw
	i.move = Vector2(0.0, 1.0) if not _done else Vector2.ZERO  # forward
	return i


func _process(delta: float) -> void:
	_time += delta
	_aim()
	valley.camera_rig.yaw = lerp_angle(valley.camera_rig.yaw, _yaw, clampf(delta * 2.0, 0.0, 1.0))
	var near := _village != null and Vector2(_village.global_position.x - valley.player.global_position.x,
		_village.global_position.z - valley.player.global_position.z).length() < STOP_AT
	if not _done and (near or _time >= LENGTH - FADE):
		_done = true  # fade out, then hand over
		_end_time = _time + FADE
	if _done:
		_black.color.a = clampf(1.0 - (_end_time - _time) / FADE, 0.0, 1.0)
		if _time >= _end_time:
			stop()


var _end_time := 0.0


func _input(event: InputEvent) -> void:
	if _time > 0.5 and ((event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)):
		get_viewport().set_input_as_handled()
		stop()  # skipped


## Ends the clip (played through or skipped): you're in charge again.
func stop() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var player: Player = valley.player
	player.input_source = _saved_input
	valley.cinematic = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	finished.emit()
	queue_free()
