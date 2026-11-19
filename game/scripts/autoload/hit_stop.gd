extends Node
## Hit-stop: briefly slows the whole game on impact so hits feel heavy.
## Timed in real milliseconds so it isn't affected by the slowdown itself.

var _end_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func trigger(duration: float) -> void:
	var t: CombatTuning = GameData.tuning
	if duration <= 0.0 or not t.hitstop_enabled:
		return
	_end_msec = maxi(_end_msec, Time.get_ticks_msec() + int(duration * 1000.0))
	Engine.time_scale = t.hitstop_time_scale


## Slow motion for `duration` real seconds at `scale` (a perfect dodge, a finisher). Unlike
## trigger(), it ignores hitstop_enabled: it's a reward, not impact feel.
func slow(duration: float, scale: float) -> void:
	_end_msec = maxi(_end_msec, Time.get_ticks_msec() + int(duration * 1000.0))
	Engine.time_scale = minf(Engine.time_scale, scale)  # a hit-stop already slower keeps its pace


func _process(_delta: float) -> void:
	if _end_msec > 0 and Time.get_ticks_msec() >= _end_msec:
		_end_msec = 0
		Engine.time_scale = 1.0


func clear() -> void:
	_end_msec = 0
	Engine.time_scale = 1.0
