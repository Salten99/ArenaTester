class_name CharacterModel
extends Node3D
## A rigged character model with the shared KayKit animation library, an optional
## weapon in the right hand, and a tint overlay for hit flashes and status glows.
## Used by the player and enemies; gameplay code only calls play() and set_tint().
##
## Any skeleton with the Rig_Medium bone names works, at any proportions: the
## animations' few position keys (hips, shoulders, hip joints, hand slots) are
## refitted to the model's own bone lengths (one library per skeleton shape).
## Models with four extra leg bones (quad_fl/fr/bl/br _up/_lo: the centaur's horse
## half, the mammoth) get those legs walked and galloped in code, like the animals.

## Animations that repeat until something else plays.
const LOOPING := ["Idle_A", "Idle_B", "Melee_2H_Idle", "Melee_Unarmed_Idle", "Walking_A", "Walking_B",
	"Walking_C", "Running_A", "Running_B", "Running_HoldingRifle", "Crouching", "Sneaking", "Jump_Idle", "Walking_Backwards",
	"Running_Strafe_Left", "Running_Strafe_Right"]

static var _libraries := {}  ## skeleton shape -> AnimationLibrary
static var _source_rest := {}  ## bone name -> rest position in the animation files' skeleton
static var _cloth_colors := {}  ## models/gen/cloth_colors.json, once read
## Four-legged gait for the extra leg bones: cycles per second and swing (radians).
const QUAD_LEGS := ["quad_fl", "quad_fr", "quad_bl", "quad_br"]
const QUAD_PHASE := {"walk": [0.0, 0.5, 0.5, 0.0], "run": [0.0, 0.1, 0.5, 0.6]}
const QUAD_GAIT := {"walk": [1.1, 0.35, 0.5], "run": [2.0, 0.7, 0.9]}  # rate, swing, knee

var anim: AnimationPlayer
## Ragdoll deaths (user, 2026-10-29): physics bones for these Rig_Medium bones,
## each a capsule reaching to the next bone, pinned to its parent.
## [bone, child bone it reaches to, capsule radius (m at 1x)]
const RAGDOLL_BONES := [
	["hips", "spine", 0.16], ["spine", "chest", 0.15], ["chest", "head", 0.17], ["head", "", 0.13],
	["upperarm.l", "lowerarm.l", 0.06], ["lowerarm.l", "wrist.l", 0.05],
	["upperarm.r", "lowerarm.r", 0.06], ["lowerarm.r", "wrist.r", 0.05],
	["upperleg.l", "lowerleg.l", 0.08], ["lowerleg.l", "foot.l", 0.06],
	["upperleg.r", "lowerleg.r", 0.08], ["lowerleg.r", "foot.r", 0.06],
]
## At most this many bodies flop at once (more fall with the death animation): 30-40 enemies at 60 fps.
const MAX_RAGDOLLS := 10
## Physics layer 6: ragdolls hit the ground and walls, not you or each other's capsules.
const RAGDOLL_LAYER := 1 << 5
static var ragdolls := 0
## The player goes limp whatever the cap says: it only exists to limit enemies and corpses.
var ignore_ragdoll_cap := false
## A limp body falls this many times harder than it rises (enemies set it from enemy_fall_gravity_mult).
var fall_gravity_mult := 1.0
var _ragdoll: PhysicalBoneSimulator3D
var model: Node3D
var _overlay: ShaderMaterial  ## blood and tint (shaders/blood_overlay.gdshader)
var _blood := 0.0
const BLOOD_SHADER := preload("res://shaders/blood_overlay.gdshader")
var _current := ""
var _skeleton: Skeleton3D
var _quad := {}  ## leg name -> [upper bone, lower bone, upper rest, lower rest]
var _gait_phase := 0.0
## Large weapons are held in both hands (user, 2026-10-29): the left hand is pulled
## onto the handle (TwoBoneIK3D on the left arm, after every animation), at the
## point of the handle nearest the left shoulder. File name -> how far the handle
## runs up from the right hand (m, the weapon's own size) before the head or blade;
## it runs down to the pommel. File names, so your own models in models/own count too.
## The greatsword file is the Guardian's weapon, held in one hand with a shield (user, 2026-11-17).
const TWO_HANDED := {"weapon_warhammer": 0.35, "weapon_battle_axe": 0.35,
	"weapon_spear": 0.7, "weapon_trident": 0.6, "weapon_guandao": 0.6, "weapon_naginata": 0.6, "weapon_scythe": 0.6, "gear_club": 0.15}
## One of these on each hand (user, 2026-11-01). File names, so your own models count too.
const PAIRED := ["weapon_claws", "weapon_twin_khopesh"]
## A weapon this many times its model's size, in hand (user, 2026-11-08: the naginata 33% larger).
const WEAPON_SIZE := {"weapon_naginata": 1.33}


static func weapon_size(weapon_path: String) -> float:
	return GameData.tuning.weapon_scale * WEAPON_SIZE.get(weapon_path.get_file().get_basename(), 1.0)
var _left_ik: TwoBoneIK3D
## The bone the weapon hangs from: the right hand, or the head for a blowgun (WeaponMoveset.weapon_bone).
var weapon_bone := "handslot.r"
var _aura_god := ""
var _aim_lean: AimLean
var _left_grip: Node3D
var _handle := Vector2.ZERO  ## the handle's span along the weapon's Y (down, up)
## With a two-handed weapon these play instead (both hands on the weapon; the IK
## closes the last gap). Walking has no two-handed version: the IK alone.
const TWO_HANDED_ANIMS := {"Idle_A": "Melee_2H_Idle", "Idle_B": "Melee_2H_Idle", "Running_A": "Running_HoldingRifle",
	"Running_B": "Running_HoldingRifle", "Melee_1H_Attack_Chop": "Melee_2H_Attack_Chop",
	"Melee_1H_Attack_Slice_Diagonal": "Melee_2H_Attack_Slice", "Melee_1H_Attack_Slice_Horizontal": "Melee_2H_Attack_Slice",
	"Melee_1H_Attack_Stab": "Melee_2H_Attack_Stab"}


## Builds the model. Returns false if the files are missing (callers fall back to a capsule).
func setup(model_path: String, weapon_path := "", model_scale := 1.0) -> bool:
	if not ResourceLoader.exists(model_path):
		return false
	model = (load(model_path) as PackedScene).instantiate()
	model.rotation.y = PI  # KayKit models face +Z; the game's forward is -Z
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	use_vertex_colors(model)
	add_blob_shadow()
	anim = AnimationPlayer.new()
	anim.deterministic = false  # cheaper blending; every clip keys the whole rig anyway
	model.add_child(anim)  # root_node ".." = the model, matching the library's track paths
	var skeletons: Array = model.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] if not skeletons.is_empty() else null
	anim.add_animation_library("", _library_for(_skeleton))
	_find_quad_legs()
	_find_wings()
	anim.playback_default_blend_time = 0.12
	set_weapon(weapon_path)
	_overlay = make_overlay()
	return true


## Puts the body's meshes (not what the hands hold) on render `layers`. The player's body goes on
## CameraRig.BODY_LAYER, which the first-person camera leaves out, so only the weapon shows.
func set_body_layer(layers: int) -> void:
	_body_layers = layers
	_layer_head()
	if model == null:
		return
	for n in model.find_children("*", "VisualInstance3D", true, false):
		var held := false
		var up: Node = n.get_parent()
		while up != null and up != model:
			if up is BoneAttachment3D:
				held = true
				break
			up = up.get_parent()
		if not held:
			(n as VisualInstance3D).layers = layers


var _body_layers := 1
var head_ball: BoneAttachment3D
const HEAD_BALL_RADIUS := 0.27  ## m (bigger, user 2026-11-20)


## The god's element as the head (user, 2026-11-20): a fireball, a ball of ice, a ball of lightning,
## a boulder; other elements a glowing ball in their color. Rides the head bone from outside the
## skeleton, so swapping weapons (which clears the skeleton's attachments) leaves it.
func set_head_ball(element: String) -> void:
	if head_ball != null:
		head_ball.free()
		head_ball = null
	if _skeleton == null or _skeleton.find_bone("head") < 0:
		return
	head_ball = BoneAttachment3D.new()
	head_ball.name = "HeadBall"
	add_child(head_ball)
	head_ball.use_external_skeleton = true
	head_ball.external_skeleton = head_ball.get_path_to(_skeleton)
	head_ball.bone_name = "head"
	var sphere := SphereMesh.new()
	sphere.radius = HEAD_BALL_RADIUS
	sphere.height = HEAD_BALL_RADIUS * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ElementFx.color(element)
	var mesh: Mesh = sphere
	if element in ["Stone", "Ice"]:  # a few flat faces: a rough boulder, a cut crystal
		sphere.radial_segments = 7 if element == "Stone" else 6
		sphere.rings = 4 if element == "Stone" else 3
		var st := SurfaceTool.new()
		st.create_from(sphere, 0)
		st.deindex()
		st.generate_normals()
		mesh = st.commit()
		mat.roughness = 1.0 if element == "Stone" else 0.1
		if element == "Ice":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.8
	else:
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 2.0
	var ball := MeshInstance3D.new()
	ball.mesh = mesh
	ball.material_override = mat
	ball.position = Vector3.UP * HEAD_BALL_RADIUS * 0.6  # sits on the neck
	head_ball.add_child(ball)
	if element != "Stone":
		var aura := ElementFx.aura(element, 0.5)  # flames, frost, sparks around it
		aura.position = Vector3.ZERO
		aura.scale_amount_min *= 0.35  # the aura's pieces are sized for a whole body
		aura.scale_amount_max *= 0.35
		ball.add_child(aura)
	_layer_head()


func _layer_head() -> void:
	if head_ball != null:
		for n in head_ball.find_children("*", "VisualInstance3D", true, false):
			(n as VisualInstance3D).layers = _body_layers


## Leans the upper body up or down with your aim (radians, + is up). 0 stands straight.
func set_aim_pitch(pitch: float) -> void:
	if _skeleton == null or _skeleton.find_bone("chest") < 0:
		return
	if _aim_lean == null:
		if absf(pitch) < 0.01:
			return
		_aim_lean = AimLean.new()
		_skeleton.add_child(_aim_lean)
	_aim_lean.pitch = clampf(pitch, -0.9, 0.9)


## Bends the spine and chest after the animation has posed them.
class AimLean:
	extends SkeletonModifier3D
	var pitch := 0.0

	func _process_modification() -> void:
		var bones := get_skeleton()
		if bones == null or absf(pitch) < 0.01:
			return
		for name in ["spine", "chest"]:
			var i := bones.find_bone(name)
			if i >= 0:
				bones.set_bone_pose_rotation(i, bones.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, -pitch * 0.5))


## Wraps the weapon in a glow of a god's color, for good (user, 2026-11-01). It stays through weapon swaps.
func set_weapon_aura(god_id: String) -> void:
	_aura_god = god_id
	_build_weapon_aura()


func _build_weapon_aura() -> void:
	if _aura_god == "" or _skeleton == null:
		return
	var hex := GameData.text(GameData.god(_aura_god), "theme_color_hex")
	if hex == "":
		return
	var color := Color.html(hex)
	var element := GameData.text(GameData.god(_aura_god), "element", "Physical")
	var shell := StandardMaterial3D.new()  # a slightly bigger copy of the weapon, inside out: it reads as a halo
	shell.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell.albedo_color = Color(color.r, color.g, color.b, 0.55)
	shell.cull_mode = BaseMaterial3D.CULL_FRONT
	shell.grow = true
	shell.grow_amount = 0.03
	for slot in _skeleton.find_children("*", "BoneAttachment3D", false, false):
		if slot.is_queued_for_deletion():
			continue
		for old in slot.find_children("WeaponAura*", "", true, false):
			old.free()
		var meshes: Array = slot.find_children("*", "MeshInstance3D", true, false)
		for m in meshes:
			var halo := MeshInstance3D.new()
			halo.name = "WeaponAuraShell"
			halo.mesh = m.mesh
			halo.material_override = shell
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.add_child(halo)
		if meshes.is_empty():
			continue
		var box: AABB = (meshes[0] as MeshInstance3D).global_transform * (meshes[0] as MeshInstance3D).get_aabb()
		var center: Vector3 = slot.global_transform.affine_inverse() * box.get_center()
		var light := OmniLight3D.new()
		light.name = "WeaponAuraLight"
		light.light_color = color
		light.light_energy = 0.7
		light.omni_range = 1.8
		slot.add_child(light)
		light.position = center
		var sparks := ElementFx.aura(element, 0.35)
		if sparks != null:
			sparks.name = "WeaponAuraSparks"
			slot.add_child(sparks)
			sparks.position = center


## Swaps the weapon in the right hand (pledging to a new god changes weapons).
func set_weapon(weapon_path: String) -> void:
	_set_weapon_model(weapon_path)
	_build_weapon_aura()


func _set_weapon_model(weapon_path: String) -> void:
	var skeleton: Array = model.find_children("*", "Skeleton3D", true, false) if model != null else []
	if skeleton.is_empty():
		return
	for old in skeleton[0].find_children("*", "BoneAttachment3D", false, false):
		old.queue_free()
	if _left_ik != null:
		_left_ik.queue_free()
		_left_ik = null
	if has_node("LeftElbowPole"):
		get_node("LeftElbowPole").free()
	if weapon_path == "" or not ResourceLoader.exists(weapon_path):
		return
	var slot := BoneAttachment3D.new()
	slot.bone_name = weapon_bone
	skeleton[0].add_child(slot)
	var weapon: Node = (load(weapon_path) as PackedScene).instantiate()
	slot.add_child(weapon)
	weapon.scale *= weapon_size(weapon_path)
	use_vertex_colors(weapon)
	if weapon_path.get_file().get_basename() in PAIRED and skeleton[0].find_bone("handslot.l") >= 0:
		var other := BoneAttachment3D.new()
		other.bone_name = "handslot.l"
		skeleton[0].add_child(other)
		var second: Node = (load(weapon_path) as PackedScene).instantiate()
		other.add_child(second)
		second.scale *= weapon_size(weapon_path)
		# The left hand's bone isn't a mirror image of the right's: turn it so the two weapons mirror each other.
		var right: Basis = skeleton[0].get_bone_global_rest(skeleton[0].find_bone("handslot.r")).basis.orthonormalized()
		var left: Basis = skeleton[0].get_bone_global_rest(skeleton[0].find_bone("handslot.l")).basis.orthonormalized()
		var flip := Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, 1))
		second.basis = (left.inverse() * flip * right * flip).scaled(Vector3.ONE * weapon_size(weapon_path))
		use_vertex_colors(second)
	if TWO_HANDED.has(weapon_path.get_file().get_basename()):
		_hold_with_both_hands(skeleton[0], weapon, TWO_HANDED[weapon_path.get_file().get_basename()])


## Something in the left hand (the Guardian's shield), or nothing for "". Call after set_weapon,
## which clears every hand.
func set_offhand(path: String) -> void:
	var skeleton: Array = model.find_children("*", "Skeleton3D", true, false) if model != null else []
	if skeleton.is_empty() or skeleton[0].find_bone("handslot.l") < 0:
		return
	for old in skeleton[0].find_children("Offhand*", "BoneAttachment3D", false, false):
		old.free()
	if path == "" or not ResourceLoader.exists(path):
		return
	var slot := BoneAttachment3D.new()
	slot.name = "Offhand"
	slot.bone_name = "handslot.l"
	skeleton[0].add_child(slot)
	var item: Node = (load(path) as PackedScene).instantiate()
	slot.add_child(item)
	item.scale *= GameData.tuning.weapon_scale
	use_vertex_colors(item)


## The point of the weapon in the right hand (its far end along +Y), a node that moves with it.
## Null without a weapon. Made the first time it's asked for.
func weapon_tip() -> Node3D:
	var skeleton: Array = model.find_children("*", "Skeleton3D", true, false) if model != null else []
	if skeleton.is_empty():
		return null
	for slot in skeleton[0].find_children("*", "BoneAttachment3D", false, false):
		if (slot as BoneAttachment3D).bone_name != "handslot.r" or slot.get_child_count() == 0 or slot.is_queued_for_deletion():
			continue
		var weapon := slot.get_child(0) as Node3D
		var tip := weapon.get_node_or_null("WeaponTip") as Node3D
		if tip == null:
			var high := 0.0
			for m in weapon.find_children("*", "MeshInstance3D", true, false):
				var xf := Transform3D()
				var n: Node = m
				while n != weapon:
					xf = (n as Node3D).transform * xf
					n = n.get_parent()
				high = maxf(high, (xf * (m as MeshInstance3D).get_aabb()).end.y)
			tip = Node3D.new()
			tip.name = "WeaponTip"
			tip.position = Vector3(0.0, high, 0.0)
			weapon.add_child(tip)
		return tip
	return null


func _hold_with_both_hands(skeleton: Skeleton3D, weapon: Node3D, handle_up: float) -> void:
	if skeleton.find_bone("wrist.l") < 0 or skeleton.find_bone("lowerarm.l") < 0:
		return
	# The handle runs down the weapon's -Y from the right hand to the pommel.
	var low := 0.0
	for m in weapon.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()  # the mesh's transform relative to the weapon (works before it's in the tree)
		var n: Node = m
		while n != weapon:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var box: AABB = xf * (m as MeshInstance3D).get_aabb()
		low = minf(low, box.position.y)
	_handle = Vector2(low + 0.05, handle_up)
	var grip := Node3D.new()
	grip.name = "LeftGrip"
	weapon.add_child(grip)
	_left_grip = grip
	var ik := TwoBoneIK3D.new()
	ik.name = "LeftHandIK"
	skeleton.add_child(ik)
	ik.setting_count = 1
	ik.set_root_bone_name(0, "upperarm.l")
	ik.set_middle_bone_name(0, "lowerarm.l")
	ik.set_end_bone_name(0, "wrist.l")
	ik.set_target_node(0, ik.get_path_to(grip))
	var elbow := Node3D.new()  # the elbow points down, out to the left and back
	elbow.name = "LeftElbowPole"
	elbow.position = Vector3(-0.7, 0.2, 0.4) * scale_of_rig()
	add_child(elbow)
	ik.set_pole_node(0, ik.get_path_to(elbow))
	_left_ik = ik


## Plays an animation. `duration` > 0 stretches it to last that long.
## Goes limp: physics bones take over from the animation, pushed by `impulse`
## (m/s). False if this model can't (no humanoid skeleton, too many already).
## Animals go limp differently: see BeastModel.ragdoll.
func ragdoll(impulse: Vector3) -> bool:
	if _skeleton == null or _ragdoll != null or (ragdolls >= MAX_RAGDOLLS and not ignore_ragdoll_cap) or _skeleton.find_bone("hips") < 0:
		return false
	if anim != null:
		anim.stop()
	if _left_ik != null:
		_left_ik.active = false
	var sim := PhysicalBoneSimulator3D.new()
	_skeleton.add_child(sim)
	var scale_m := global_basis.get_scale().x
	for entry in RAGDOLL_BONES:
		var i := _skeleton.find_bone(entry[0])
		if i < 0:
			continue
		var length := 0.22
		var j := _skeleton.find_bone(entry[1]) if entry[1] != "" else -1
		if j >= 0:
			length = _skeleton.get_bone_global_rest(i).origin.distance_to(_skeleton.get_bone_global_rest(j).origin)
		var pb := FallBone.new()
		pb.fall_mult = fall_gravity_mult
		pb.bone_name = entry[0]
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE if entry[0] == "hips" else PhysicalBone3D.JOINT_TYPE_CONE
		pb.collision_layer = RAGDOLL_LAYER
		pb.collision_mask = 0b001
		pb.mass = 2.0 if entry[0] in ["hips", "spine", "chest"] else 1.0
		pb.linear_damp = 0.4
		pb.angular_damp = 2.0
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = float(entry[2])
		capsule.height = maxf(length, capsule.radius * 2.0 + 0.01)
		shape.shape = capsule
		shape.position = Vector3(0.0, length * 0.5, 0.0)  # Rig_Medium bones point along +Y to their child
		pb.add_child(shape)
		sim.add_child(pb)
	_ragdoll = sim
	ragdolls += 1
	sim.physical_bones_start_simulation()
	push_ragdoll(impulse)
	if _head_pop != null:
		_skeleton.move_child(_head_pop, -1)  # after the ragdoll poses the bones, or it would put the head back
	return true


var _head_pop: HeadPop


## A ragdoll bone that falls harder than it rises: the way up is unchanged, the way down heavier.
class FallBone:
	extends PhysicalBone3D
	var fall_mult := 1.0

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		if state.linear_velocity.y < 0.0:
			state.linear_velocity += state.total_gravity * (fall_mult - 1.0) * state.step


## The head is gone (a squeeze kill, user 2026-11-19): shrunk to nothing every frame from now on,
## with whatever it wears.
func pop_head() -> void:
	if _skeleton == null or _skeleton.find_bone("head") < 0 or _head_pop != null:
		return
	_head_pop = HeadPop.new()
	_skeleton.add_child(_head_pop)


func head_popped() -> bool:
	return _head_pop != null


## Where the head is now, or `fallback` if the rig has none.
func head_position(fallback: Vector3) -> Vector3:
	return bone_position("head", fallback)


## Where bone `bone` is now (handslot.r: the right hand), or `fallback` if the rig has none.
func bone_position(bone: String, fallback: Vector3) -> Vector3:
	var i := _skeleton.find_bone(bone) if _skeleton != null else -1
	return _skeleton.to_global(_skeleton.get_bone_global_pose(i).origin) if i >= 0 else fallback


class HeadPop:
	extends SkeletonModifier3D

	func _process_modification() -> void:
		var bones := get_skeleton()
		var i := bones.find_bone("head") if bones != null else -1
		if i >= 0:
			bones.set_bone_pose_scale(i, Vector3.ONE * 0.001)


func push_ragdoll(impulse: Vector3) -> void:
	var scale_m := global_basis.get_scale().x
	# It tumbles end over end the way it flies (user, 2026-11-18): every bone moves as if the body
	# turned as one around its hips, so it spins instead of just flopping.
	var side := Vector3(-impulse.z, 0.0, impulse.x)
	var spin := side.normalized() * minf(GameData.tuning.launch_spin, impulse.length() * 0.8) if side.length() > 0.5 else Vector3.ZERO
	var hips := ragdoll_hips()
	var center: Vector3 = hips.global_position if hips != null else global_position
	for pb in _ragdoll.get_children() if _ragdoll != null else []:
		if pb is PhysicalBone3D:
			pb.linear_velocity = (impulse * (1.0 if pb.bone_name in ["hips", "spine", "chest"] else 1.3) + spin.cross(pb.global_position - center)) / maxf(scale_m, 0.5)
			pb.angular_velocity = spin


## The physics body that carries a limp model: a person's hips (null while not limp).
func ragdoll_hips() -> PhysicsBody3D:
	for pb in _ragdoll.get_children() if _ragdoll != null else []:
		if pb is PhysicalBone3D and pb.bone_name == "hips":
			return pb
	return null


## Lets go of a two-handed weapon's handle with the left hand (true) or takes it again (false):
## the hand is free to grab (combat feel plan, 2026-11-18).
func free_left_hand(on: bool) -> void:
	if _left_ik != null:
		_left_ik.active = not on and _ragdoll == null


## Back from limp to animated (a thrown enemy getting up).
func unragdoll() -> void:
	if _ragdoll == null:
		return
	_ragdoll.free()  # stopping first, or freeing later, hands Jolt zero-sized bones
	_ragdoll = null
	ragdolls -= 1
	_current = ""
	if _left_ik != null:
		# next physics frame: the hand IK on the same frame as the limp pose bends the arm to a zero size
		get_tree().physics_frame.connect(func(): _left_ik.active = _ragdoll == null, CONNECT_ONE_SHOT)


func _exit_tree() -> void:
	if _ragdoll != null:
		ragdolls -= 1
		_ragdoll = null


## The ragdoll stops touching the ground and falls through it (before the body is removed).
func sink_ragdoll() -> void:
	if _ragdoll == null:
		return
	for pb in _ragdoll.get_children():
		if pb is PhysicalBone3D:
			pb.collision_mask = 0


func is_ragdoll() -> bool:
	return _ragdoll != null


func play(anim_name: String, duration := 0.0, restart := false) -> void:
	var clip: String = TWO_HANDED_ANIMS.get(anim_name, anim_name) if _left_ik != null else anim_name
	if anim == null or not anim.has_animation(clip):
		return
	if _split:  # the legs are busy walking: the move plays on the upper body
		if anim_name == _current_upper and not restart and _upper.is_playing():
			return
		var up_speed := _upper.get_animation(clip).length / duration if duration > 0.0 else 1.0
		_upper.play(clip, -1, up_speed)
		if restart:
			_upper.seek(0.0, true)
		_current_upper = anim_name
		return
	if anim_name == _current and not restart and anim.is_playing():
		return
	var length := anim.get_animation(clip).length
	var speed := length / duration if duration > 0.0 else 1.0
	anim.play(clip, -1, speed)
	if restart:
		anim.seek(0.0, true)
	_current = anim_name


# ---------------------------------------------------------------- strike frames
# (user, 2026-11-18: the moves as close to the reels as possible): a blow plays fast up to its clip's
# own strike frame, landing on the hit, then slow through the follow-through; a charged blow waits
# drawn back just before it.

## When each shared clip's blow lands (s): the right hand at its fastest, measured by
## tests/clip_probe.tscn. Clips not listed keep playing evenly (play()).
const STRIKES := {"Melee_1H_Attack_Chop": 0.58, "Melee_1H_Attack_Jump_Chop": 0.73, "Melee_1H_Attack_Slice_Diagonal": 0.42,
	"Melee_1H_Attack_Slice_Horizontal": 0.27, "Melee_1H_Attack_Stab": 0.38, "Melee_2H_Attack_Chop": 0.72,
	"Melee_2H_Attack_Slice": 0.38, "Melee_2H_Attack_Spin": 1.17, "Melee_2H_Attack_Spinning": 0.27, "Melee_2H_Attack_Stab": 0.38,
	"Melee_Dualwield_Attack_Chop": 0.55, "Melee_Dualwield_Attack_Slice": 0.58, "Melee_Dualwield_Attack_Stab": 0.38,
	"Melee_Unarmed_Attack_Kick": 0.30, "Melee_Unarmed_Attack_Punch_A": 0.43, "Throw": 0.62,
	"Human_ThrowBall": 0.75, "Human_ThrowWeapon": 0.65, "Human_ThrowSpear": 1.12, "Human_ThrowBoomerang": 0.85}
## A held blow waits this far (s of the clip) before its strike frame, then takes STRIKE_SNAP s to land it.
const STRIKE_LEAD := 0.06
const STRIKE_SNAP := 0.033

var _strike := {}  ## the blow playing: clip, at (its strike frame), after (speed past it), hold, released


## Plays `anim_name` so its blow lands `windup` s from now and the whole move lasts `total` s.
## `hold`: it waits drawn back just before the blow until release_strike().
func play_strike(anim_name: String, windup: float, total: float, hold := false) -> void:
	var clip: String = TWO_HANDED_ANIMS.get(anim_name, anim_name) if _left_ik != null else anim_name
	if anim == null or not anim.has_animation(clip) or not STRIKES.has(clip):
		play(anim_name, total, true)
		_strike = {}
		return
	var length := anim.get_animation(clip).length
	var at: float = STRIKES[clip]
	var p := _upper if _split else anim
	var before := (at - (STRIKE_LEAD if hold else 0.0)) / maxf(windup, 0.01)
	p.play(clip, 0.05, before)
	p.seek(0.0, true)
	if _split:
		_current_upper = anim_name
	else:
		_current = anim_name
	_strike = {"clip": clip, "at": at, "after": (length - at) / maxf(total - windup, 0.05), "hold": hold, "released": not hold, "past": false}


## Lets a held blow land now (it takes STRIKE_SNAP s).
func release_strike() -> void:
	if _strike.is_empty() or _strike.released:
		return
	_strike.released = true
	var p := _upper if _split else anim
	if p.assigned_animation == _strike.clip:  # assigned: a paused clip has no current_animation
		var at := p.current_animation_position
		p.play(_strike.clip, 0.0, maxf(_strike.at - at, 0.01) / STRIKE_SNAP)
		p.seek(at, true)


## Whether a blow is waiting drawn back (tests).
func strike_held() -> bool:
	return not _strike.is_empty() and not _strike.released


func _update_strike() -> void:
	if _strike.is_empty():
		return
	var p := _upper if _split else anim
	if p == null or p.assigned_animation != _strike.clip:
		_strike = {}
		return
	var at := p.current_animation_position
	if not _strike.released:
		if at >= _strike.at - STRIKE_LEAD and p.is_playing():
			p.pause()
		return
	if not _strike.past and at >= _strike.at:
		_strike.past = true
		p.play(_strike.clip, 0.0, _strike.after)
		p.seek(at, true)


# ---------------------------------------------------------------- the body split
# (combat feel plan, user 2026-11-18, from the "180 animations" reel): while you move, the legs
# keep their walk or run and every move plays on the upper body. A second AnimationPlayer,
# processed after the first, plays copies of the clips that only key the bones from the spine up.

var _upper: AnimationPlayer
var _split := false
var _current_upper := ""
static var _upper_libraries := {}  ## the full library's id -> its upper-body copy


## Splits the body: `legs` (a walk or run) plays on the legs while moves play on the upper body.
## "" joins it again: the move carries on over the whole body.
func set_split(legs: String) -> void:
	if legs == "":
		if not _split:
			return
		_split = false
		var clip := _upper.assigned_animation if strike_held() else _upper.current_animation
		if clip != "" and (_upper.is_playing() or strike_held()):
			var at := _upper.current_animation_position
			anim.play(clip, 0.1, _upper.get_playing_speed())
			anim.seek(at, true)
			if strike_held():
				anim.pause()
			_current = _current_upper
		_upper.stop()
		return
	if anim == null or not anim.has_animation(legs) or not _ensure_upper():
		return
	if not _split:
		_split = true
		var clip := anim.assigned_animation if strike_held() else anim.current_animation
		if clip != "" and _upper.has_animation(clip):
			var at := anim.current_animation_position
			_upper.play(clip, 0.0, anim.get_playing_speed())
			_upper.seek(at, true)
			if strike_held() and not anim.is_playing():
				_upper.pause()
		_current_upper = _current
	if anim.current_animation != legs:
		anim.play(legs)
		_current = legs


func is_split() -> bool:
	return _split


func upper_clip() -> String:
	return _upper.current_animation if _upper != null else ""


func _ensure_upper() -> bool:
	if _upper != null:
		return true
	if anim == null or _skeleton == null or _skeleton.find_bone("spine") < 0:
		return false
	var full := anim.get_animation_library("")
	if not _upper_libraries.has(full.get_instance_id()):
		_upper_libraries[full.get_instance_id()] = _upper_body_library(full)
	_upper = AnimationPlayer.new()
	_upper.name = "UpperBody"
	_upper.deterministic = false  # bones its clips don't key (the legs) are left to the walk
	_upper.playback_default_blend_time = 0.08
	model.add_child(_upper)  # after `anim`: it poses the upper body last
	_upper.root_node = anim.root_node
	_upper.add_animation_library("", _upper_libraries[full.get_instance_id()])
	return true


## Copies of every clip keeping only the tracks of bones from the spine up.
func _upper_body_library(full: AnimationLibrary) -> AnimationLibrary:
	var upper := {}
	for i in _skeleton.get_bone_count():
		var b := i
		while b >= 0:
			if _skeleton.get_bone_name(b) == "spine":
				upper[_skeleton.get_bone_name(i)] = true
				break
			b = _skeleton.get_bone_parent(b)
	var lib := AnimationLibrary.new()
	for clip_name in full.get_animation_list():
		var copy: Animation = full.get_animation(clip_name).duplicate(true)
		for t in range(copy.get_track_count() - 1, -1, -1):
			if not upper.has(String(copy.track_get_path(t).get_concatenated_subnames())):
				copy.remove_track(t)
		lib.add_animation(clip_name, copy)
	return lib


func set_speed(scale_factor: float) -> void:
	if anim != null:
		anim.speed_scale = scale_factor


## The move playing: the upper body's while the body is split (set_split), else the whole body's.
func current() -> String:
	return _current_upper if _split else _current


## Colors the whole model; alpha 0 = no tint.
func set_tint(color: Color) -> void:
	_show_tint(color)


static func make_overlay() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BLOOD_SHADER
	return m


## How bloody it looks: 0 clean .. 1 soaked (user, 2026-11-05: bloodier with every hit).
func set_blood(amount: float) -> void:
	_blood = clampf(amount, 0.0, 1.0)
	if _overlay != null:
		_overlay.set_shader_parameter("blood", _blood)
		_show_tint(_overlay.get_shader_parameter("tint") if _overlay.get_shader_parameter("tint") != null else Color(1, 1, 1, 0))


## The tint is a second, see-through pass over every mesh: on only while it shows
## (always on, it doubled the draw calls of every unit in a big fight).
var _tinted := false


func _show_tint(color: Color) -> void:
	if _overlay == null:
		return
	_overlay.set_shader_parameter("tint", color)
	var on := color.a > 0.0 or _blood > 0.01
	if on == _tinted:
		return
	_tinted = on
	for m in find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = _overlay if _tinted else null


## The generated models keep their colors in vertex colors; the glTF importer
## doesn't switch those on, so this does (only for meshes that have them).
static func use_vertex_colors(node: Node) -> void:
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (m as MeshInstance3D).mesh
		if not mesh is ArrayMesh:
			continue
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat is BaseMaterial3D and (mesh as ArrayMesh).surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR:
				(mat as BaseMaterial3D).vertex_color_use_as_albedo = true


## Repaints the clothes in a god's color (user, 2026-11-01). `palette` names the row in
## models/gen/cloth_colors.json (a race, or a mount for its blanket): the generators write what
## color they used for cloth and trim. Your own models aren't listed, so they keep their colors.
func set_god_colors(palette: String, god_id: String) -> void:
	if not _cloth_colors.has("loaded"):
		var text := FileAccess.get_file_as_string(ModelRegistry.GEN + "cloth_colors.json")
		var parsed = JSON.parse_string(text) if text != "" else null
		_cloth_colors = parsed if parsed is Dictionary else {}
		_cloth_colors["loaded"] = true
	var hex := GameData.text(GameData.god(god_id), "theme_color_hex")
	if not _cloth_colors.has(palette) or hex == "" or model == null:
		return
	var god := Color.html(hex).srgb_to_linear()
	var pairs := [[_cloth_colors[palette][0], god], [_cloth_colors[palette][1], god.lerp(Color.WHITE, 0.35)]]
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if not m.has_meta("plain_mesh"):
			m.set_meta("plain_mesh", m.mesh)
		var plain: ArrayMesh = m.get_meta("plain_mesh")
		var key := "%d|%s|%s" % [plain.get_instance_id(), palette, god_id]
		var hit: Array = _recolor_cache.get(key, [])
		if hit.is_empty() or hit[0] != plain:  # [0]: the mesh it came from, in case an id is reused
			hit = [plain, _recolored(plain, pairs)]
			_recolor_cache[key] = hit
		m.mesh = hit[1]


## Recolored meshes shared by every model of the same mesh, palette and god (a battle of 35 recolored
## each one's meshes vertex by vertex).
static var _recolor_cache := {}  # shortcut: never emptied (meshes x gods, small); clear it if memory ever matters


## A copy of the mesh with each [from rgb, to color] swapped, keeping each face's light and dark.
static func _recolored(mesh: ArrayMesh, pairs: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		for k in colors.size():
			var c := colors[k]
			for pair in pairs:
				var from: Array = pair[0]
				var total: float = from[0] + from[1] + from[2]
				if absf(c.r - from[0]) + absf(c.g - from[1]) + absf(c.b - from[2]) < 0.01 + 0.1 * total:
					var light := (c.r + c.g + c.b) / maxf(total, 0.001)
					colors[k] = Color(pair[1].r * light, pair[1].g * light, pair[1].b * light, c.a)
					break
		if not colors.is_empty():
			arrays[Mesh.ARRAY_COLOR] = colors
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(i), arrays, [], {}, mesh.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(i, mesh.surface_get_material(i))
	return out


## Retro look: a soft dark disc on the ground under the model, instead of a sun shadow.
## A decal, so it lies on slopes; its box reaches only a little above the feet, so the
## body isn't darkened. Sized from the model's real size once it's in the world (half its
## footprint, at least 0.4 of its height). Far discs fade out.
func add_blob_shadow() -> void:
	_add_blob_shadow.call_deferred()


func _add_blob_shadow() -> void:
	if not is_inside_tree() or model == null:
		return
	var box := bounds(model)
	var s := global_basis.get_scale().x
	if box.size.y <= 0.0 or s <= 0.0:
		return
	var r := clampf(minf(box.size.x, box.size.z) * 0.5, box.size.y * 0.4, box.size.y) / s
	var blob := Decal.new()
	blob.texture_albedo = _blob_texture()
	blob.size = Vector3(r * 2.0, r + 1.5 / s, r * 2.0)
	blob.distance_fade_enabled = true
	blob.distance_fade_begin = 40.0
	blob.distance_fade_length = 10.0
	add_child(blob)
	# the model's lowest point is its feet (the node itself may sit higher, at the body's middle)
	blob.global_position.y = box.position.y + 0.15 - blob.size.y * s * 0.5


static var _blob_tex: ImageTexture
static func _blob_texture() -> ImageTexture:
	if _blob_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
				img.set_pixel(x, y, Color(0, 0, 0, 0.7 * clampf(1.0 - d * d * d, 0.0, 1.0)))
		_blob_tex = ImageTexture.create_from_image(img)
	return _blob_tex


## How big a node's models really are. Includes the bones: a model scaled through its
## skeleton (the free animals) reports a mesh box that doesn't show its real size.
static func bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = m.global_transform * (m as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	for sk in node.find_children("*", "Skeleton3D", true, false):
		for i in sk.get_bone_count():
			box = box.expand(sk.global_transform * sk.get_bone_global_pose(i).origin)
	return box


## The model's scale (1 = the rig's own size).
func scale_of_rig() -> float:
	return model.scale.x if model != null else 1.0



# ---------------------------------------------------------------- wings

## Winged people (angels, bird and owl people, the harpy, the gargoyle; user, 2026-11-05) have
## two bones per wing (wing1/wing2 .l/.r, made by make_characters.py). While `flapping` (in the
## air) they beat them with the little demon's own wing beat: how far its wing bones turn over
## its "movement" clip, read once from its model (beast_little_demon.glb).
const FLAP_MODEL := "beast_little_demon.glb"
const FLAP_SAMPLES := 48
var flapping := false
var _wings: Array = []  ## [bone, rest rotation, axis in the bone's space, which curve (0 inner, 1 outer)]
var _flap_phase := 0.0
static var _flap: Array = []  ## [clip length, inner angles, outer angles]; [] = not read yet


func _find_wings() -> void:
	_wings.clear()
	if _skeleton == null:
		return
	for name in ["wing1.l", "wing2.l", "wing1.r", "wing2.r"]:
		var i := _skeleton.find_bone(name)
		if i < 0:
			continue
		var rest := _skeleton.get_bone_global_rest(i).basis
		var along := rest.y.normalized()  # Godot bones point along their +Y
		var axis := along.cross(Vector3.UP)
		if axis.length() < 0.01:
			axis = Vector3.FORWARD
		_wings.append([i, _skeleton.get_bone_rest(i).basis.get_rotation_quaternion(), (rest.inverse() * axis).normalized(), 0 if name.begins_with("wing1") else 1])


static func flap_curve() -> Array:
	if not _flap.is_empty():
		return _flap
	_flap = [1.0, PackedFloat32Array(), PackedFloat32Array()]
	var path := ModelRegistry.own(FLAP_MODEL)
	if path == "":
		return _flap
	var scene: Node = (load(path) as PackedScene).instantiate()
	var players: Array = scene.find_children("*", "AnimationPlayer", true, false)
	var skels: Array = scene.find_children("*", "Skeleton3D", true, false)
	if not players.is_empty() and not skels.is_empty():
		var ap: AnimationPlayer = players[0]
		var sk: Skeleton3D = skels[0]
		var clip := "Gallop" if ap.has_animation("Gallop") else (ap.get_animation_list()[0] if not ap.get_animation_list().is_empty() else "")
		if clip != "":
			var a := ap.get_animation(clip)
			_flap[0] = maxf(a.length, 0.1)
			for k in 2:
				var bone := "wing%d.l" % (k + 1)
				for t in a.get_track_count():
					if a.track_get_type(t) == Animation.TYPE_ROTATION_3D and str(a.track_get_path(t)).ends_with(":" + bone):
						var rest := sk.get_bone_rest(sk.find_bone(bone)).basis.get_rotation_quaternion()
						var ref := Vector3.ZERO
						var angles := PackedFloat32Array()
						for s in FLAP_SAMPLES:
							var d: Quaternion = rest.inverse() * a.rotation_track_interpolate(t, _flap[0] * s / FLAP_SAMPLES)
							var ax := d.get_axis() if d.get_angle() > 0.001 else ref
							if ref == Vector3.ZERO and d.get_angle() > 0.05:
								ref = ax
							angles.append(d.get_angle() * (1.0 if ref == Vector3.ZERO or ax.dot(ref) >= 0.0 else -1.0))
						_flap[k + 1] = angles
	scene.free()
	return _flap


func _beat_wings(delta: float, skel: Skeleton3D = null) -> void:
	var sk := skel if skel != null else _skeleton
	var curve := flap_curve()
	var length: float = curve[0]
	if flapping:
		_flap_phase = fmod(_flap_phase + delta / length, 1.0)
	for w in _wings:
		var angles: PackedFloat32Array = curve[w[3] + 1]
		var angle := 0.0
		if flapping and not angles.is_empty():
			var f := _flap_phase * angles.size()
			angle = lerpf(angles[int(f) % angles.size()], angles[(int(f) + 1) % angles.size()], fmod(f, 1.0))
		sk.set_bone_pose_rotation(w[0], (w[1] as Quaternion) * Quaternion(w[2], angle))


## Big battles: a model far from the camera updates its animation only every
## Enemy.crowd_stride-th frame (with the time in between), like its unit's thinking.
const FULL_ANIM_RANGE := 35.0
var in_crowd := false  ## its unit is in the crowd (Enemy.in_crowd): animate it as if it were far
var _anim_skip := 0
var _anim_time := 0.0


func _thin_animation(delta: float) -> void:
	if anim == null:
		return
	var cam := get_viewport().get_camera_3d() if Enemy.crowd_stride > 1 else null
	var far := cam != null and (in_crowd or global_position.distance_squared_to(cam.global_position) > FULL_ANIM_RANGE * FULL_ANIM_RANGE)
	if not far:
		if anim.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
			anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
			anim.advance(_anim_time)
			_anim_time = 0.0
		return
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_anim_time += delta
	_anim_skip -= 1
	if _anim_skip <= 0:
		_anim_skip = Enemy.crowd_stride
		anim.advance(_anim_time)
		_anim_time = 0.0


func _process(delta: float) -> void:
	_thin_animation(delta)
	_update_strike()
	if not _wings.is_empty():
		_beat_wings(delta)
	if _left_ik != null and is_instance_valid(_left_grip) and _left_grip.is_inside_tree():
		# The left hand's spot: the point of the handle nearest the left shoulder.
		var w := (_left_grip.get_parent() as Node3D).global_transform
		if w.basis.determinant() != 0.0:  # a model shrunk to nothing can't be inverted
			var shoulder := _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("upperarm.l")).origin
			_left_grip.position = Vector3(0.0, clampf((w.affine_inverse() * shoulder).y, _handle.x, _handle.y), 0.0)
	if _quad.is_empty():
		return
	var kind := ""
	if _current.contains("Running") or _current.contains("Sprint") or _current.contains("Dash"):
		kind = "run"
	elif _current.contains("Walking") or _current.contains("Strafe"):
		kind = "walk"
	var speed := anim.speed_scale if anim != null else 1.0
	if kind != "":
		var rate: float = QUAD_GAIT[kind][0]
		_gait_phase = fmod(_gait_phase + delta * rate * speed, 1.0)
	for k in QUAD_LEGS.size():
		var leg: Array = _quad.get(QUAD_LEGS[k], [])
		if leg.is_empty():
			continue
		var swing := 0.0
		var knee := 0.0
		if kind != "":
			var phase: float = QUAD_PHASE[kind][k]
			var amp: float = QUAD_GAIT[kind][1]
			var bend: float = QUAD_GAIT[kind][2]
			var a := TAU * (_gait_phase + phase)
			swing = amp * sin(a)
			knee = -bend * maxf(0.0, cos(a))
		_skeleton.set_bone_pose_rotation(leg[0], leg[2] * Quaternion(Vector3.RIGHT, swing))
		_skeleton.set_bone_pose_rotation(leg[1], leg[3] * Quaternion(Vector3.RIGHT, knee))


func _find_quad_legs() -> void:
	_quad.clear()
	if _skeleton == null:
		return
	for leg in QUAD_LEGS:
		var up := _skeleton.find_bone(leg + "_up")
		var lo := _skeleton.find_bone(leg + "_lo")
		if up >= 0 and lo >= 0:
			_quad[leg] = [up, lo, _skeleton.get_bone_rest(up).basis.get_rotation_quaternion(),
				_skeleton.get_bone_rest(lo).basis.get_rotation_quaternion()]


## The Human Throwing pack's clips on Rig_Medium (tests/retarget_human.gd), named Human_*.
const HUMAN_CLIPS := "res://models/human/throws_rig_medium.res"


## Every Rig_Medium animation merged into one library, refitted to `skeleton`'s
## proportions: position keys keep their motion relative to the bone's rest
## position, scaled by how much taller the hips sit than in the animation files.
static func _library_for(skeleton: Skeleton3D) -> AnimationLibrary:
	var key := _shape_key(skeleton)
	if _libraries.has(key):
		return _libraries[key]
	var lib := AnimationLibrary.new()
	for path in ModelRegistry.animation_files():
		if not ResourceLoader.exists(path):
			continue
		var scene: Node = (load(path) as PackedScene).instantiate()
		var src: Array = scene.find_children("*", "Skeleton3D", true, false)
		if not src.is_empty() and _source_rest.is_empty():
			var s0: Skeleton3D = src[0]
			for i in s0.get_bone_count():
				_source_rest[s0.get_bone_name(i)] = s0.get_bone_rest(i).origin
		for player in scene.find_children("*", "AnimationPlayer", true, false):
			for lib_name in player.get_animation_library_list():
				var source: AnimationLibrary = player.get_animation_library(lib_name)
				for a in source.get_animation_list():
					if a == "T-Pose" or lib.has_animation(a):
						continue
					var clip: Animation = source.get_animation(a).duplicate(true)
					clip.loop_mode = Animation.LOOP_LINEAR if a in LOOPING else Animation.LOOP_NONE
					_refit(clip, skeleton)
					lib.add_animation(a, clip)
		scene.free()
	if ResourceLoader.exists(HUMAN_CLIPS):  # the throws, converted to this rig (tests/retarget_human.gd)
		var human: AnimationLibrary = load(HUMAN_CLIPS)
		for a in human.get_animation_list():
			var clip: Animation = human.get_animation(a).duplicate(true)
			_refit(clip, skeleton)
			lib.add_animation(a, clip)
	_libraries[key] = lib
	return lib


## The bones the animation files move by position (_refit re-bases each on the rig's own rest).
const POSITION_BONES := ["root", "hips", "upperleg.l", "upperleg.r", "upperarm.l", "upperarm.r", "handslot.l", "handslot.r"]


## Rigs share a library only if those bones rest within a centimetre: keyed by the hips alone, a
## minotaur loaded after a cat got the cat's shoulders, 6 cm off (audit 2026-11-17).
static func _shape_key(skeleton: Skeleton3D) -> String:
	if skeleton == null or skeleton.find_bone("hips") < 0:
		return "source"
	var key := ""
	for b in POSITION_BONES:
		var i := skeleton.find_bone(b)
		key += str(skeleton.get_bone_rest(i).origin.snapped(Vector3.ONE * 0.01)) if i >= 0 else "-"
	return key


static func _refit(clip: Animation, skeleton: Skeleton3D) -> void:
	if skeleton == null or not _source_rest.has("hips") or skeleton.find_bone("hips") < 0:
		return
	var src_hips: float = (_source_rest["hips"] as Vector3).y
	var k := skeleton.get_bone_rest(skeleton.find_bone("hips")).origin.y / src_hips if src_hips > 0.0 else 1.0
	if absf(k - 1.0) < 0.001:
		return
	for t in clip.get_track_count():
		if clip.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var bone := String(clip.track_get_path(t).get_concatenated_subnames())
		var i := skeleton.find_bone(bone)
		if i < 0 or not _source_rest.has(bone):
			continue
		var old_rest: Vector3 = _source_rest[bone]
		var new_rest := skeleton.get_bone_rest(i).origin
		for kk in clip.track_get_key_count(t):
			var v: Vector3 = clip.track_get_key_value(t, kk)
			clip.track_set_key_value(t, kk, new_rest + (v - old_rest) * k)
