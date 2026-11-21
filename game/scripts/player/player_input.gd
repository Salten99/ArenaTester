class_name PlayerInput
extends Node
## Turns keyboard and mouse into a PlayerIntent each physics frame.

var camera_rig: Node3D
var _wheel_back := false  ## the wheel turned back (down) since the last read: reels in the chain


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:  # either way reels in a chained one
		_wheel_back = true


## The slide key also dashes (the arena, user 2026-11-19): tap it to dash once, hold it
## SLIDE_HOLD_MSEC to slide (the slide starts then, and lasts while it's held).
var slide_dashes := false
const SLIDE_HOLD_MSEC := 300
var _slide_since := -1
var _sliding := false


func _slide_or_dash(i: PlayerIntent) -> void:
	i.slide = false
	i.slide_held = false
	var now := Time.get_ticks_msec()
	if Input.is_action_pressed("slide"):
		if _slide_since < 0:
			_slide_since = now
		if now - _slide_since >= SLIDE_HOLD_MSEC:
			i.slide = not _sliding
			i.slide_held = true
			_sliding = true
		return
	if _slide_since >= 0 and not _sliding:
		i.dodge = true  # a tap: one dash
		i.dash = true
	_slide_since = -1
	_sliding = false


func read() -> PlayerIntent:
	var i := PlayerIntent.new()
	i.move = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back"))
	if i.move.length() > 1.0:
		i.move = i.move.normalized()
	i.aim_yaw = camera_rig.yaw if camera_rig != null else 0.0
	i.aim_pitch = camera_rig.pitch if camera_rig != null else 0.0
	i.crosshair = _crosshair_point()
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	i.light = captured and Input.is_action_just_pressed("attack_light")
	i.light_held = captured and Input.is_action_pressed("attack_light")
	i.heavy = captured and Input.is_action_just_pressed("attack_heavy")
	i.heavy_held = captured and Input.is_action_pressed("attack_heavy")
	i.wheel_back = captured and _wheel_back
	_wheel_back = false
	i.dodge = Input.is_action_just_pressed("dodge")
	i.jump = Input.is_action_just_pressed("jump")
	i.jump_held = Input.is_action_pressed("jump")
	i.dodge_held = Input.is_action_pressed("dodge")
	i.sprint = Input.is_action_pressed("sprint")
	i.slide = Input.is_action_just_pressed("slide")
	i.slide_held = Input.is_action_pressed("slide")
	if slide_dashes:
		_slide_or_dash(i)
	i.signature = Input.is_action_just_pressed("ability_signature")
	i.race_active = Input.is_action_just_pressed("race_active")
	i.throw = captured and Input.is_action_just_pressed("throw_weapon")
	i.throw_held = captured and Input.is_action_pressed("throw_weapon")
	i.movement = Input.is_action_just_pressed("ability_movement")
	i.signature_held = Input.is_action_pressed("ability_signature")
	i.movement_held = Input.is_action_pressed("ability_movement")
	i.ultimate = Input.is_action_just_pressed("ability_ultimate")
	i.ultimate_held = Input.is_action_pressed("ability_ultimate")
	i.ultimate_released = Input.is_action_just_released("ability_ultimate")
	# Every spell lands where you aim, and so does each Kaminari pillar you click down after R is let go.
	i.aim_point = _camera_ground_point()
	return i


## What's at the middle of the screen: the world or an enemy, or far away in the sky. INF with no camera.
func _crosshair_point() -> Vector3:
	var cam: Camera3D = camera_rig.camera if camera_rig != null else null
	if cam == null or not cam.is_inside_tree():
		return Vector3.INF
	var from := cam.global_position
	var to := from - cam.global_basis.z * 300.0
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 0b101))
	return hit.position if hit else to


## The ground point at the middle of the screen (for aiming ultimates), or INF.
func _camera_ground_point() -> Vector3:
	var cam: Camera3D = camera_rig.camera if camera_rig != null else null
	if cam == null or not cam.is_inside_tree():
		return Vector3.INF
	var from := cam.global_position
	var to := from - cam.global_basis.z * 120.0
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 0b001))
	return hit.position if hit else to
