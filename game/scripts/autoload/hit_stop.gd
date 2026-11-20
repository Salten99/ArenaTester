extends Node
## Hit-stop: briefly slows the whole game on impact so hits feel heavy.
## Timed in real milliseconds so it isn't affected by the slowdown itself.
## Slow motion (slow()) keeps its own clock: a hit landing during it stops briefly, then slow motion goes on.

var _hit_end := 0
var _slow_end := 0
var _slow_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func trigger(duration: float) -> void:
	if duration <= 0.0 or not GameData.tuning.hitstop_enabled:
		return
	_hit_end = maxi(_hit_end, Time.get_ticks_msec() + int(duration * 1000.0))
	_update()


## Slow motion for `duration` real seconds at `scale` (a perfect dodge, a finisher). Unlike
## trigger(), it ignores hitstop_enabled: it's a reward, not impact feel.
func slow(duration: float, scale: float) -> void:
	var now := Time.get_ticks_msec()
	_slow_scale = minf(_slow_scale, scale) if _slow_end > now else scale  # two at once: the slower wins
	_slow_end = maxi(_slow_end, now + int(duration * 1000.0))
	_update()


func _process(_delta: float) -> void:
	if _hit_end > 0 or _slow_end > 0:
		_update()


## The pace right now: hit-stop while it runs, else slow motion while it runs, else normal.
func _update() -> void:
	var now := Time.get_ticks_msec()
	if _hit_end <= now:
		_hit_end = 0
	if _slow_end <= now:
		_slow_end = 0
		_slow_scale = 1.0
	Engine.time_scale = GameData.tuning.hitstop_time_scale if _hit_end > 0 else (_slow_scale if _slow_end > 0 else 1.0)


func clear() -> void:
	_hit_end = 0
	_slow_end = 0
	_slow_scale = 1.0
	Engine.time_scale = 1.0
