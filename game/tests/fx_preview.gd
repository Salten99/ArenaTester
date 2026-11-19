extends Node3D
## Preview any effect scene as one whole instance: pick it in the Inspector (Effect), press F6.
## Space replays it. It plays the way the game does (every particle node and AnimationPlayer starts).

@export var effect: PackedScene  ## no built-in path, so moving your effects never breaks this

var _current: Node3D


func _ready() -> void:
	$Camera3D.look_at_from_position(Vector3(0, 4, 11), Vector3(0, 2, 0), Vector3.UP)
	_play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_play()


func _play() -> void:
	if _current != null:
		_current.queue_free()
	if effect == null:
		return  # nothing picked yet: drag an effect .tscn onto Effect in the Inspector
	_current = effect.instantiate()
	add_child(_current)
	$Camera3D.make_current()  # an effect with its own camera doesn't take over
	ElementFx._start(_current)
