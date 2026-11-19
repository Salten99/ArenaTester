extends Node
## Converts the Quaternius Universal Animation Library clips (asset_library/itch/quaternius-ual1, -ual2)
## onto Rig_Medium and saves them to models/quaternius/ual_rig_medium.res. Run tools\retarget_ual.bat.
## Clip names get a UAL1_ / UAL2_ prefix so they never replace a KayKit clip.

const TARGET := "res://models/kaykit/animations/Rig_Medium_General.glb"
const OUT := "res://models/quaternius/ual_rig_medium.res"
const PACKS := {
	"UAL1_": "itch/quaternius-ual1/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb",
	"UAL2_": "itch/quaternius-ual2/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb",
}


func _ready() -> void:
	var tgt_scene: Node3D = (load(TARGET) as PackedScene).instantiate()
	add_child(tgt_scene)
	var tgt_sk: Skeleton3D = tgt_scene.find_children("*", "Skeleton3D", true, false)[0]
	var tgt_player: AnimationPlayer = tgt_scene.find_children("*", "AnimationPlayer", true, false)[0]
	var prefix := String(tgt_player.get_animation("Idle_A").track_get_path(0)).get_slice(":", 0)
	var out := AnimationLibrary.new()
	for name_prefix in PACKS:
		var src: Node3D = AnimRetarget.load_library_glb(PACKS[name_prefix])
		if src == null:
			push_error("Missing pack: asset_library/" + PACKS[name_prefix])
			continue
		add_child(src)
		var src_sk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
		var src_player: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		var lib := AnimRetarget.bake_all(src_player, src_sk, "A_TPose", tgt_player, tgt_sk, "T-Pose", prefix, name_prefix)
		for clip in lib.get_animation_list():
			out.add_animation(clip, lib.get_animation(clip))
		print("%s %d clips" % [name_prefix, lib.get_animation_list().size()])
		src.queue_free()
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err := ResourceSaver.save(out, OUT, ResourceSaver.FLAG_COMPRESS)
	print("Saved %d clips to %s (%s)" % [out.get_animation_list().size(), OUT, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
