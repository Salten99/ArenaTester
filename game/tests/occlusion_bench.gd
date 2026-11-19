extends "res://tests/test_runner.gd"
## Occlusion benchmark, run by hand in a real window (not headless: nothing is drawn there):
## <godot_console.exe> --path game res://tests/occlusion_bench.tscn
## Stands a camera outside each village wall and the castle, looking in, and prints what is drawn
## and the frame time with occlusion culling off and on.


func _ready() -> void:
	Meta.persist = false
	Playtest.persist = false
	SaveSystem.RUN_PATH = "user://bench_run_save.json"
	SaveSystem.PROFILE_PATH = "user://bench_profile.json"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await get_tree().process_frame
	_arena = Node3D.new()
	add_child(_arena)
	var v: Valley = await _valley(1234)
	v.player.god_mode = true
	var cam := Camera3D.new()
	cam.far = 4000.0
	v.add_child(cam)
	var spots: Array = []
	for c in v.world.get_children():
		if c.name.begins_with("Village_"):
			spots.append([c.name, (c as Node3D).global_position, ValleyWorld.WALL_RING + 15.0])
		elif c.name == "landmark_castle":
			spots.append([c.name, (c as Node3D).global_position, 45.0])
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var sums := {false: [0.0, 0.0, 0.0], true: [0.0, 0.0, 0.0]}
	for s in spots:
		for k in 4:  # four sides
			var a := k * TAU / 4.0 + 0.3
			var at: Vector3 = s[1] + Vector3(cos(a), 0.0, sin(a)) * float(s[2])
			at.y = v.world.terrain.height(at.x, at.z) + 2.5
			cam.global_position = at
			cam.look_at(s[1] + Vector3.UP * 4.0)
			cam.make_current()
			var line := "%-28s side %d" % [s[0], k]
			for on in [false, true]:
				get_viewport().use_occlusion_culling = on
				await _frames(10)
				var objects := 0.0
				var cpu := 0.0
				var gpu := 0.0
				for i in 30:
					await get_tree().process_frame
					objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
					cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
					gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
				line += "   %s: %4d objects, cpu %.2f ms, gpu %.2f ms" % ["ON " if on else "OFF", objects / 30.0, cpu / 30.0, gpu / 30.0]
				sums[on][0] += objects / 30.0
				sums[on][1] += cpu / 30.0
				sums[on][2] += gpu / 30.0
			print(line)
	var n := spots.size() * 4.0
	for on in [false, true]:
		print("AVERAGE %s: %d objects, render cpu %.2f ms, gpu %.2f ms" % ["ON " if on else "OFF", sums[on][0] / n, sums[on][1] / n, sums[on][2] / n])
	get_tree().quit(0)
