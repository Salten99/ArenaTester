extends Node3D
## Pictures of the shared clips, run by hand in a window (not headless, not part of the tests):
##   <godot_console.exe> --path game res://tests/clip_shots.tscn -- --out=<folder>
## One row per clip, six moments across it, a dwarf with a warhammer seen from the front-left.
## Used to pick poses for the grab, squeeze and throw (combat feel plan, 2026-11-18).

const CLIPS := [["Interact", "PickUp", "Use_Item", "Melee_Block", "Melee_Blocking", "Melee_Block_Attack", "Throw"],
	["Ranged_1H_Aiming", "Ranged_2H_Aiming", "Ranged_Magic_Raise", "Melee_Unarmed_Attack_Punch_A", "Melee_Unarmed_Attack_Kick", "Melee_2H_Attack_Chop", "Melee_1H_Attack_Jump_Chop"]]
const CELL := 180
const COLS := 6


func _ready() -> void:
	var out := "user://clip_shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	get_window().size = Vector2i(CELL, CELL)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(-2.2, 1.4, -2.6)
	cam.look_at(Vector3(0, 0.95, 0))
	cam.fov = 50.0
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation = Vector3(-0.8, 0.6, 0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.82, 0.84, 0.88)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var m := CharacterModel.new()
	add_child(m)
	m.setup(ModelRegistry.for_race("dwarf"), ModelRegistry.weapon_model("warhammer", "dwarf"))
	await get_tree().process_frame
	m.anim.playback_default_blend_time = 0.0
	for sheet in CLIPS.size():
		var img := Image.create(CELL * COLS, CELL * CLIPS[sheet].size(), false, Image.FORMAT_RGB8)
		for row in CLIPS[sheet].size():
			var clip: String = CLIPS[sheet][row]
			if not m.anim.has_animation(clip):
				continue
			var length := m.anim.get_animation(clip).length
			for c in COLS:
				m.anim.play(clip)
				m.anim.seek(length * c / (COLS - 1.0) * 0.999, true)
				m.anim.pause()
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var shot := get_viewport().get_texture().get_image()
				shot.convert(Image.FORMAT_RGB8)
				shot.resize(CELL, CELL)
				img.blit_rect(shot, Rect2i(0, 0, CELL, CELL), Vector2i(c * CELL, row * CELL))
		img.save_png(out + "/clips_%d.png" % sheet)
	get_tree().quit()
