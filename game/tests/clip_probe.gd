extends Node
## Times the shared attack clips, run by hand (not part of the tests):
##   <godot_console.exe> --headless --path game res://tests/clip_probe.tscn
## For each clip: its length, when the right hand moves fastest (the blow), and how far it reaches
## then, so swings can land their hit on the clip's own strike frame.

const FILES := ["res://models/kaykit/animations/Rig_Medium_CombatMelee.glb", "res://models/kaykit/animations/Rig_Medium_General.glb",
	"res://models/kaykit/animations/Rig_Medium_CombatRanged.glb"]


func _ready() -> void:
	for f in FILES:
		var root: Node = (load(f) as PackedScene).instantiate()
		add_child(root)
		var anim: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
		for hand in ["handslot.r", "handslot.l"]:
			var bone := sk.find_bone(hand)
			if bone < 0:
				continue
			for clip in anim.get_animation_list():
				if not (clip.begins_with("Melee") or clip in ["Throw", "PickUp", "Use_Item", "Interact", "Hit_A", "Hit_B"] or clip.begins_with("Ranged_Magic")):
					continue
				var a := anim.get_animation(clip)
				var steps := int(a.length * 60.0)
				var last := Vector3.INF
				var best := 0.0
				var best_t := 0.0
				var reach := 0.0
				var hips := sk.find_bone("hips")
				for i in steps + 1:
					var t := i / 60.0
					anim.play(clip)
					anim.seek(t, true)
					sk.force_update_all_bone_transforms()
					var p := sk.get_bone_global_pose(bone).origin - Vector3(0, sk.get_bone_global_pose(hips).origin.y if hips >= 0 else 0.0, 0)
					if last != Vector3.INF:
						var v := (p - last).length() * 60.0
						if v > best:
							best = v
							best_t = t
							reach = Vector2(p.x, p.z).length()
					last = p
				print("%-36s %s len %.2fs  fastest at %.2fs (%.0f%%)  %.1f m/s  reach %.2f m" % [clip, hand, a.length, best_t, best_t / a.length * 100.0, best, reach])
		root.queue_free()
	get_tree().quit()
