class_name CameraRig
extends Node3D
## Third-person camera: follows the player, mouse to look around, spring arm
## so walls don't block the view, and trauma-based screen shake.

@export var distance := 6.5
@export var height := 1.7
## Degrees of turn per pixel of mouse movement (sam-movement: SENSITIVITY 0.1).
@export var mouse_sensitivity_deg := 0.1
## How quickly the view catches up with the mouse (sam-movement smoothing: 20).
@export var look_smoothing := 20.0
@export var min_pitch := -1.45  ## nearly straight down
@export var max_pitch := 1.25  ## nearly straight up
## How quickly the camera catches up with the player (higher = tighter).
@export var follow_speed := 30.0

var target: Node3D
var yaw := 0.0       ## target yaw (radians); what the player aims with
var pitch := -0.35
var _view_yaw := 0.0  ## smoothed yaw the camera shows
var _view_pitch := -0.35
var _low_offset := 0.0
var _shoulder := 0.0  ## over the right shoulder with a bow or spell weapon (aim_shoulder_offset)
var camera: Camera3D
var _arm: SpringArm3D
var _trauma := 0.0
## First person (user, 2026-11-09: T switches): the camera moves to just in front of your eyes.
## Your body's meshes sit on BODY_LAYER, which this camera then leaves out, so only what your hands
## hold shows (user, 2026-11-19; hiding the whole body hid the weapons too, 2026-11-10).
var first_person := false:
	set(v):
		first_person = v
		if _arm != null:
			_arm.spring_length = 0.0 if v else distance
			camera.position.z = -FIRST_PERSON_AHEAD if v else 0.0
			camera.cull_mask = (camera.cull_mask & ~BODY_LAYER) if v else (camera.cull_mask | BODY_LAYER)
## The render layer of the player's body (layer 11): seen in third person, not in first.
const BODY_LAYER := 1 << 10
## How far in front of the eyes the first-person camera sits, so your own head is behind it.
const FIRST_PERSON_AHEAD := 0.3


func _ready() -> void:
	top_level = true
	_arm = SpringArm3D.new()
	_arm.spring_length = distance
	_arm.collision_mask = 1
	_arm.margin = 0.3
	add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 70.0
	_arm.add_child(camera)
	camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= deg_to_rad(event.screen_relative.x * mouse_sensitivity_deg)
		pitch = clampf(pitch - deg_to_rad(event.screen_relative.y * mouse_sensitivity_deg), min_pitch, max_pitch)
	elif event.is_action_pressed("camera_view"):
		first_person = not first_person
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var t: CombatTuning = GameData.tuning
	if target != null and is_instance_valid(target):
		var low: float = t.slide_camera_offset if target.has_method("is_low") and target.is_low() else 0.0
		_low_offset = lerpf(_low_offset, low, clampf(10.0 * delta, 0.0, 1.0))
		var focus: Vector3 = target.camera_focus() if target.has_method("camera_focus") else target.global_position
		var aims: bool = target.has_method("aims_with_body") and target.aims_with_body()
		_shoulder = lerpf(_shoulder, t.aim_shoulder_offset if aims and not first_person else 0.0, clampf(6.0 * delta, 0.0, 1.0))
		# Moved, not h_offset: the crosshair ray from the camera's middle must stay true.
		var goal := focus + Vector3.UP * (height + _low_offset) + Vector3(cos(_view_yaw), 0.0, -sin(_view_yaw)) * _shoulder
		global_position = global_position.lerp(goal, clampf(follow_speed * delta, 0.0, 1.0)) + _kick
	_kick = _kick.lerp(Vector3.ZERO, clampf(18.0 * delta, 0.0, 1.0))
	var k := clampf(look_smoothing * delta, 0.0, 1.0)
	_view_yaw = lerp_angle(_view_yaw, yaw, k)
	_view_pitch = lerpf(_view_pitch, pitch, k)
	rotation = Vector3(_view_pitch, _view_yaw, 0.0)
	var aim: bool = target != null and is_instance_valid(target) and target.get("aiming") == true
	camera.fov = lerpf(camera.fov, t.aim_fov if aim else 70.0, clampf(8.0 * delta, 0.0, 1.0))  # aiming zooms in a little
	_trauma = maxf(0.0, _trauma - t.shake_decay * delta)
	var s := _trauma * _trauma * t.shake_max_offset
	camera.h_offset = randf_range(-s, s)
	camera.v_offset = randf_range(-s, s)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


var _kick := Vector3.ZERO


## A short push of the view toward a blow you landed (user, 2026-11-18), on top of the shake.
func kick(dir: Vector3, amount: float) -> void:
	if dir.length() > 0.01:
		_kick = (_kick + dir.normalized() * amount).limit_length(0.5)


func snap_to_target() -> void:
	if target != null:
		global_position = target.global_position + Vector3.UP * height
	_view_yaw = yaw
	_view_pitch = pitch


## Flat forward direction of the camera.
func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))
