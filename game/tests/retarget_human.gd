extends Node
## Converts the Human Throwing Animations clips (asset_library/human-throwing, the male FBX files
## from "Human Throwing Animations FREE") onto Rig_Medium and saves them to
## models/human/throws_rig_medium.res, which CharacterModel adds to every people rig.
## Run: Godot --headless --path game res://tests/retarget_human.tscn
## "HumanM@ThrowSpear01_R - Hold.fbx" becomes "Human_ThrowSpear_Hold".

const TARGET := "res://models/kaykit/animations/Rig_Medium_General.glb"
const OUT := "res://models/human/throws_rig_medium.res"
const DIR := "human-throwing/"
const FILES := ["ThrowBall01_R", "ThrowBall01_R - Hold", "ThrowBoomerang01_R", "ThrowBoomerang01_R - Hold",
	"ThrowBoomerang01_R - Wait", "ThrowBoomerang01_R - Catch", "ThrowWeapon01_R", "ThrowWeapon01_R - Hold",
	"ThrowSpear01_R", "ThrowSpear01_R - Hold"]


static func clip_name(file: String) -> String:
	return "Human_" + file.replace("01_R", "").replace(" - ", "_")


func _ready() -> void:
	var tgt_scene: Node3D = (load(TARGET) as PackedScene).instantiate()
	add_child(tgt_scene)
	var tgt_sk: Skeleton3D = tgt_scene.find_children("*", "Skeleton3D", true, false)[0]
	var tgt_player: AnimationPlayer = tgt_scene.find_children("*", "AnimationPlayer", true, false)[0]
	var prefix := String(tgt_player.get_animation("Idle_A").track_get_path(0)).get_slice(":", 0)
	var out := AnimationLibrary.new()
	for file in FILES:
		var src: Node3D = AnimRetarget.load_library_glb(DIR + "HumanM@" + file + ".fbx")
		if src == null:
			push_error("Missing: asset_library/" + DIR + "HumanM@" + file + ".fbx")
			continue
		add_child(src)
		await get_tree().process_frame
		var src_sk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
		var src_player: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		var lib := AnimRetarget.bake_all(src_player, src_sk, "", tgt_player, tgt_sk, "T-Pose", prefix, "", AnimRetarget.HUMAN_MAP)
		var a: Animation = lib.get_animation(lib.get_animation_list()[0])
		a.loop_mode = Animation.LOOP_LINEAR if file.ends_with("Hold") or file.ends_with("Wait") else Animation.LOOP_NONE
		out.add_animation(clip_name(file), a)
		src.queue_free()
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err := ResourceSaver.save(out, OUT, ResourceSaver.FLAG_COMPRESS)
	print("Saved %d clips to %s (%s)" % [out.get_animation_list().size(), OUT, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
