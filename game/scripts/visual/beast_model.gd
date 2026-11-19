class_name BeastModel
extends CharacterModel
## An animal or monster with its own animations (Quaternius animals and
## monsters), driven through the same calls as a KayKit character: enemies ask
## for "Running_A", "Melee_1H_Attack_Chop", "Hit_A", "Death_A"... and this
## plays the beast's matching clip (Gallop, Attack, HitReact, Death...).
## Models without animations (e.g. the poly.pizza bear) get simple code-driven
## motion instead: a bob when walking, a lunge to attack, a flinch, a fall.

## KayKit animation name -> beast role.
const ROLE_OF := {
	"Idle_A": "idle", "Idle_B": "idle", "Melee_2H_Idle": "idle",
	"Walking_A": "walk", "Walking_B": "walk", "Walking_C": "walk",
	"Running_A": "run", "Running_B": "run",
	"Melee_1H_Attack_Chop": "attack",
	"Hit_A": "hit", "Hit_B": "hit",
	"Death_A": "death", "Death_B": "death",
	"Jump_Idle": "jump",
}
## Beast role -> clip names to look for, best first (the part after "Armature|").
const CLIPS := {
	"idle": ["Idle", "Spider_Idle"],
	"walk": ["Walk", "Spider_Walk", "Run", "Gallop"],  # a model with only a run (the user's rat) runs slower
	"run": ["Gallop", "Run", "Walk", "Spider_Walk"],
	"attack": ["Attack", "Attack_Headbutt", "Punch", "Bite_Front", "Spider_Attack"],
	"hit": ["Idle_HitReact_Left", "HitReact", "HitRecieve"],
	"death": ["Death", "Spider_Death"],
	"jump": ["Gallop_Jump", "Jump", "Spider_Jump"],
}
const LOOPING_ROLES := ["idle", "walk", "run"]
## Speed of the run clip when it stands in for a missing walk.
const WALK_ON_RUN := 0.5

var _clip := {}  ## role -> the model's animation name
var _limp: RigidBody3D  ## carries the model while it tumbles
var _model_rest := Transform3D()
var _static_before := false
## Code-driven motion for models without animations.
var _static := false
var _rest := Transform3D()
var _move_role := "idle"
var _action := ""
var _action_t := 0.0
var _action_len := 0.0
var _phase := 0.0
var _speed := 1.0
var _dead := false


## Builds the beast. Returns false if the file is missing (callers fall back to a capsule).
## `lift` raises models whose origin is at their middle instead of their feet.
func setup_beast(model_path: String, model_scale: float, tint := Color(0, 0, 0, 0), lift := 0.0) -> bool:
	if not ResourceLoader.exists(model_path):
		return false
	model = (load(model_path) as PackedScene).instantiate()
	model.rotation.y = PI  # glTF models face +Z; the game's forward is -Z
	model.scale = Vector3.ONE * model_scale
	model.position.y = lift
	add_child(model)
	use_vertex_colors(model)
	add_blob_shadow()
	var players: Array = model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		_static = true
		_rest = model.transform
		_setup_overlay(tint)
		return true
	anim = players[0]
	anim.playback_default_blend_time = 0.12
	_find_bird_wings()
	var names: Array = anim.get_animation_list()
	for role in CLIPS:
		for wanted in CLIPS[role]:
			var found := ""
			for n in names:
				if n == wanted or n.ends_with("|" + wanted):
					found = n
					break
			if found != "":
				_clip[role] = found
				break
	for role in LOOPING_ROLES:
		if _clip.has(role):
			anim.get_animation(_clip[role]).loop_mode = Animation.LOOP_LINEAR
	for role in ["attack", "hit", "death", "jump"]:
		if _clip.has(role):
			anim.get_animation(_clip[role]).loop_mode = Animation.LOOP_NONE
	_setup_overlay(tint)
	return true


func _setup_overlay(tint: Color) -> void:
	_overlay = make_overlay()
	_base_tint = tint  # a permanent color cast (e.g. the bull darkened into a boar)
	_show_tint(tint)


var _base_tint := Color(0, 0, 0, 0)


## Beasts carry no weapons.
func set_weapon(_weapon_path: String) -> void:
	pass


func play(anim_name: String, duration := 0.0, restart := false) -> void:
	var role: String = ROLE_OF.get(anim_name, "")
	if _static:
		_play_static(role, duration)
		_current = anim_name
		return
	if anim == null or not _clip.has(role):
		return
	var clip: String = _clip[role]
	if anim_name == _current and not restart and anim.is_playing():
		return
	var length := anim.get_animation(clip).length
	var rate := length / duration if duration > 0.0 else 1.0
	if role == "walk" and clip == _clip.get("run", ""):
		rate *= WALK_ON_RUN
	anim.play(clip, -1, rate)
	if restart:
		anim.seek(0.0, true)
	_current = anim_name


## Goes limp: the whole animal tumbles as one solid body in its death pose. Animal skeletons can't
## use a person's bone ragdoll: their feet hang off control bones, so the legs would stretch.
func ragdoll(impulse: Vector3) -> bool:
	if model == null or _limp != null or ragdolls >= MAX_RAGDOLLS or not is_inside_tree():
		return false
	var box := CharacterModel.bounds(self)
	_model_rest = model.transform
	_limp = RigidBody3D.new()
	_limp.collision_layer = RAGDOLL_LAYER
	_limp.collision_mask = 0b001
	_limp.mass = 40.0
	_limp.linear_damp = 0.15
	_limp.angular_damp = 1.2
	_limp.top_level = true
	add_child(_limp)
	_limp.global_transform = Transform3D(global_basis.orthonormalized(), global_position + Vector3.UP * 0.05)
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = (box.size * 0.8).max(Vector3.ONE * 0.2)
	solid.size.x = maxf(solid.size.x, minf(solid.size.y, solid.size.z) * 0.75)  # some rigs measure thin sideways: they'd sink when lying down
	shape.shape = solid
	_limp.add_child(shape)
	shape.global_position = box.get_center()
	model.reparent(_limp)
	ragdolls += 1
	if anim != null:
		anim.speed_scale = 0.0  # stiff in the pose it was hit in: the death clip would drop the body through the ground
	_static_before = _static
	_static = false  # no code-driven bobbing while limp
	push_ragdoll(impulse)
	return true


func is_ragdoll() -> bool:
	return _limp != null


func push_ragdoll(impulse: Vector3) -> void:
	if _limp == null:
		return
	_limp.linear_velocity = impulse
	var side := Vector3(-impulse.z, 0.0, impulse.x)  # it rolls over in the direction it flies
	_limp.angular_velocity = side.normalized() * clampf(impulse.length() * 0.7, 2.0, 9.0) if side.length() > 0.1 else Vector3(3.0, 0.0, 1.0)


func ragdoll_hips() -> PhysicsBody3D:
	return _limp


## Stuck where it is, pinned to a wall.
func freeze_limp() -> void:
	if _limp != null:
		_limp.linear_velocity = Vector3.ZERO
		_limp.angular_velocity = Vector3.ZERO
		_limp.freeze = true


func unragdoll() -> void:
	if _limp == null:
		return
	model.reparent(self, false)
	model.transform = _model_rest
	_limp.queue_free()
	_limp = null
	ragdolls -= 1
	_current = ""
	_dead = false
	_static = _static_before
	if anim != null:
		anim.speed_scale = 1.0
		if _clip.has("idle"):
			play("Idle_A", 0.0, true)


func sink_ragdoll() -> void:
	if _limp != null:
		_limp.collision_mask = 0  # the ground lets go


func _exit_tree() -> void:
	if _limp != null:
		ragdolls -= 1
		_limp = null


## Tint overlays (hit flash, telegraph...) sit on top of the beast's own color cast.
func set_tint(color: Color) -> void:
	_show_tint(color if color.a > 0.0 else _base_tint)


func set_speed(scale_factor: float) -> void:
	_speed = scale_factor
	super(scale_factor)


func _play_static(role: String, duration: float) -> void:
	if _dead:
		return
	if role in LOOPING_ROLES:
		_move_role = role
		return
	_action = role
	_action_t = 0.0
	_action_len = duration if duration > 0.0 else {"attack": 0.6, "hit": 0.3, "death": 0.8}.get(role, 0.5)
	_dead = role == "death"


## Birds and other winged beasts (wing_l / wing_r bones, make_creatures.py) beat their wings with
## the little demon's wing beat while they fly (user, 2026-11-06: their own flight was rigid).
var _bird_skeleton: Skeleton3D


func _find_bird_wings() -> void:
	var sks: Array = model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0]
	for side in ["l", "r"]:
		var i := sk.find_bone("wing_" + side)
		if i < 0:
			continue
		var rest := sk.get_bone_global_rest(i).basis
		var axis := rest.y.normalized().cross(Vector3.UP)
		if axis.length() < 0.01:
			axis = Vector3.FORWARD
		_wings.append([i, sk.get_bone_rest(i).basis.get_rotation_quaternion(), (rest.inverse() * axis).normalized(), 0])
	if _wings.is_empty():
		return
	_bird_skeleton = sk
	for clip in anim.get_animation_list():  # the beat replaces the clips' own stiff wing motion
		var a := anim.get_animation(clip)
		for t in range(a.get_track_count() - 1, -1, -1):
			var path := str(a.track_get_path(t))
			if path.ends_with(":wing_l") or path.ends_with(":wing_r"):
				a.remove_track(t)


func _process(delta: float) -> void:
	_thin_animation(delta)  # far beasts in a big battle update their clips every few frames, like people
	if _bird_skeleton != null:
		_beat_wings(delta, _bird_skeleton)
	if not _static or model == null:
		return
	_phase += delta * _speed * {"idle": 1.5, "walk": 7.0, "run": 12.0}.get(_move_role, 1.5)
	var bob := {"idle": 0.02, "walk": 0.08, "run": 0.16}.get(_move_role, 0.0) as float
	var offset := Vector3(0.0, absf(sin(_phase)) * bob, 0.0)
	var pitch := sin(_phase * 2.0) * bob * 0.4
	var roll := 0.0
	if _action != "":
		_action_t += delta * _speed
		var k := clampf(_action_t / maxf(_action_len, 0.01), 0.0, 1.0)
		match _action:
			"attack":  # rear back, then lunge forward
				offset.z -= sin(k * PI) * 0.7 * (1.0 if k > 0.4 else -0.4)
				pitch += sin(k * PI) * 0.25
			"hit":
				offset.x += sin(k * PI * 6.0) * 0.08 * (1.0 - k)
			"death":  # falls on its side
				roll = k * PI * 0.5
				offset.y -= k * 0.3
		if k >= 1.0 and _action != "death":
			_action = ""
	model.transform = Transform3D(Basis.from_euler(Vector3(pitch, 0.0, roll)), offset) * _rest
