class_name AnimRetarget
extends RefCounted
## Moves clips from another humanoid skeleton onto Rig_Medium (the shared people rig).
##
## Both skeletons are posed in a reference T-pose; for every frame, each bone's world
## rotation change from that pose is copied onto its partner bone, and the hips' movement
## is scaled by the two hip heights. Bones without a partner keep their T-pose angle.
## Used by tools/retarget_ual.bat (Quaternius Universal Animation Library 1 and 2).

## Rig_Medium bone -> source bone. Missing ones (clavicles, neck, spine_02, fingers) are
## folded in: the child's world rotation already includes them.
const UAL_MAP := {
	"root": "root", "hips": "pelvis", "spine": "spine_01", "chest": "spine_03", "head": "Head",
	"upperarm.l": "upperarm_l", "lowerarm.l": "lowerarm_l", "wrist.l": "hand_l",
	"upperarm.r": "upperarm_r", "lowerarm.r": "lowerarm_r", "wrist.r": "hand_r",
	"upperleg.l": "thigh_l", "lowerleg.l": "calf_l", "foot.l": "foot_l", "toes.l": "ball_l",
	"upperleg.r": "thigh_r", "lowerleg.r": "calf_r", "foot.r": "foot_r", "toes.r": "ball_r",
}
## Rig_Medium bone -> the Human animation packs' bone (asset_library/human-*, FBX; the throws).
const HUMAN_MAP := {
	"hips": "B-hips", "spine": "B-spine", "chest": "B-chest", "head": "B-head",
	"upperarm.l": "B-upperArm.L", "lowerarm.l": "B-forearm.L", "wrist.l": "B-hand.L",
	"upperarm.r": "B-upperArm.R", "lowerarm.r": "B-forearm.R", "wrist.r": "B-hand.R",
	"upperleg.l": "B-thigh.L", "lowerleg.l": "B-shin.L", "foot.l": "B-foot.L", "toes.l": "B-toe.L",
	"upperleg.r": "B-thigh.R", "lowerleg.r": "B-shin.R", "foot.r": "B-foot.R", "toes.r": "B-toe.R",
}
const FPS := 30.0


## World rotation and position of every bone of `sk` as it is posed now.
static func world_pose(sk: Skeleton3D) -> Dictionary:
	sk.force_update_all_bone_transforms()
	var out := {}
	for i in sk.get_bone_count():
		var t := sk.global_transform * sk.get_bone_global_pose(i)
		out[sk.get_bone_name(i)] = [t.basis.orthonormalized().get_rotation_quaternion(), t.origin]
	return out


## One frame: target local [rotation, position] per bone, from the source's world pose.
## `src_ref`/`tgt_ref` are world_pose() in the T-pose; `tgt_rest_local` is the target's T-pose
## local [rotation, position]; `k` scales the hips' movement (target hip height / source's).
static func solve_frame(tgt: Skeleton3D, src_now: Dictionary, src_ref: Dictionary, tgt_ref: Dictionary,
		tgt_ref_local: Dictionary, k: float, map := UAL_MAP) -> Dictionary:
	var world := {}  # bone -> Transform3D in world space
	var out := {}
	for i in _order(tgt):
		var name := tgt.get_bone_name(i)
		var p := tgt.get_bone_parent(i)
		var parent_w: Transform3D = world[tgt.get_bone_name(p)] if p >= 0 else tgt.global_transform
		var local: Array = tgt_ref_local[name]
		var rot: Quaternion = local[0]
		var pos: Vector3 = local[1]
		var src_name: String = map.get(name, "")
		if src_name != "" and src_now.has(src_name):
			var delta: Quaternion = (src_now[src_name][0] as Quaternion) * (src_ref[src_name][0] as Quaternion).inverse()
			var want: Quaternion = (delta * (tgt_ref[name][0] as Quaternion)).normalized()
			rot = (parent_w.basis.get_rotation_quaternion().inverse() * want).normalized()
			if name == "hips":
				var moved: Vector3 = (src_now[src_name][1] as Vector3) - (src_ref[src_name][1] as Vector3)
				pos = parent_w.affine_inverse() * ((tgt_ref[name][1] as Vector3) + moved * k)
		out[name] = [rot, pos]
		# parent_w carries the rig's scale (race_human is 0.9); world rotation stays pure.
		world[name] = parent_w * Transform3D(Basis(rot), pos)
	return out


## Parents before children.
static func _order(sk: Skeleton3D) -> Array:
	var out: Array = []
	var todo: Array = Array(sk.get_parentless_bones())
	while not todo.is_empty():
		var b: int = todo.pop_front()
		out.append(b)
		todo.append_array(Array(sk.get_bone_children(b)))
	return out


## The current local [rotation, position] of every bone.
static func local_pose(sk: Skeleton3D) -> Dictionary:
	var out := {}
	for i in sk.get_bone_count():
		out[sk.get_bone_name(i)] = [sk.get_bone_pose_rotation(i), sk.get_bone_pose_position(i)]
	return out


## Every clip of `src_player` (on skeleton `src`) baked onto `tgt` as a new library.
## `src_ref_clip`/`tgt_ref_clip` pose both rigs in a T-pose (an empty `src_ref_clip`: the source rests in one); `track_prefix` is the target
## tracks' node path ("Rig_Medium/Skeleton3D"); clip names get `name_prefix`.
static func bake_all(src_player: AnimationPlayer, src: Skeleton3D, src_ref_clip: String,
		tgt_player: AnimationPlayer, tgt: Skeleton3D, tgt_ref_clip: String,
		track_prefix: String, name_prefix: String, map := UAL_MAP) -> AnimationLibrary:
	if src_ref_clip == "":
		src.reset_bone_poses()
	else:
		_seek(src_player, src_ref_clip, 0.0)
	var src_ref := world_pose(src)
	_seek(tgt_player, tgt_ref_clip, 0.0)
	var tgt_ref := world_pose(tgt)
	var tgt_ref_local := local_pose(tgt)
	var k: float = (tgt_ref["hips"][1] as Vector3).y / maxf((src_ref[map["hips"]][1] as Vector3).y, 0.001)
	var lib := AnimationLibrary.new()
	for clip in src_player.get_animation_list():
		if clip == src_ref_clip:
			continue
		var length := src_player.get_animation(clip).length
		var a := Animation.new()
		a.length = length
		a.loop_mode = Animation.LOOP_LINEAR if clip.ends_with("_Loop") else Animation.LOOP_NONE
		var rot_tracks := {}
		var pos_tracks := {}
		for i in tgt.get_bone_count():
			var bone := tgt.get_bone_name(i)
			var r := a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(r, "%s:%s" % [track_prefix, bone])
			rot_tracks[bone] = r
			var p := a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(p, "%s:%s" % [track_prefix, bone])
			pos_tracks[bone] = p
		var frames := int(ceil(length * FPS))
		for f in frames + 1:
			var t := minf(f / FPS, length)
			_seek(src_player, clip, t)
			var pose := solve_frame(tgt, world_pose(src), src_ref, tgt_ref, tgt_ref_local, k, map)
			for bone in pose:
				a.rotation_track_insert_key(rot_tracks[bone], t, pose[bone][0])
				a.position_track_insert_key(pos_tracks[bone], t, pose[bone][1])
		_drop_still(a)
		lib.add_animation(name_prefix + clip, a)
	return lib


## A position track that never moves is replaced by one key (most bones only rotate).
static func _drop_still(a: Animation) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D or a.track_get_key_count(t) < 2:
			continue
		var first: Vector3 = a.track_get_key_value(t, 0)
		var still := true
		for kk in a.track_get_key_count(t):
			if (a.track_get_key_value(t, kk) as Vector3).distance_to(first) > 0.0005:
				still = false
				break
		if still:
			for kk in range(a.track_get_key_count(t) - 1, 0, -1):
				a.track_remove_key(t, kk)


## A .glb or .fbx from asset_library/ (outside the project, so not imported) as a scene. null if missing.
static func load_library_glb(rel: String) -> Node:
	var path := ProjectSettings.globalize_path("res://").path_join("../asset_library").path_join(rel).simplify_path()
	if not FileAccess.file_exists(path):
		return null
	var fbx := rel.get_extension().to_lower() == "fbx"
	var doc: GLTFDocument = FBXDocument.new() if fbx else GLTFDocument.new()
	var state: GLTFState = FBXState.new() if fbx else GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state)


static func _seek(player: AnimationPlayer, clip: String, t: float) -> void:
	player.play(clip)
	player.seek(t, true)
	player.pause()
