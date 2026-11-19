extends "res://tests/test_runner.gd"
## Crowd benchmark, run by hand (not part of the tests): times 100-500 units in the valley.
## <godot_console.exe> --headless --path game --fixed-fps 60 res://tests/crowd_bench.tscn


func _ready() -> void:
	Meta.persist = false
	Playtest.persist = false
	SaveSystem.RUN_PATH = "user://bench_run_save.json"
	SaveSystem.PROFILE_PATH = "user://bench_profile.json"
	await get_tree().process_frame
	var cfgs := [[100, 0], [500, 0], [250, 250]]
	if OS.get_environment("BENCH") != "":  # BENCH=150,0 times just that
		var n := OS.get_environment("BENCH").split(",")
		cfgs = [[int(n[0]), int(n[1]) if n.size() > 1 else 0]]
	for cfg in cfgs:
		_arena = Node3D.new()
		add_child(_arena)
		var v: Valley = await _valley(1234)
		await _crowd(v, cfg[0], cfg[1])
	get_tree().quit(0)


func _crowd(a: Valley, hostile: int, friendly: int) -> void:
	var p: Player = a.player
	p.god_mode = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in hostile + friendly:
		var ang := rng.randf() * TAU
		var pos := p.global_position + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(float(OS.get_environment("BENCH_NEAR")) if OS.get_environment("BENCH_NEAR") != "" else 10.0, float(OS.get_environment("BENCH_FAR")) if OS.get_environment("BENCH_FAR") != "" else 60.0)
		a.waves.spawn("barb_raider", pos, Enemy.Team.HOSTILE if i < hostile else Enemy.Team.FRIENDLY)
	await _frames(30)
	var worst := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	for i in 120:
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	var total := (Time.get_ticks_usec() - start) / 120.0 / 1000.0
	var d: CrowdDirector = a.waves.director
	var units: Array = d.enemies.duplicate()
	var t := Time.get_ticks_usec()
	for u in units:
		if is_instance_valid(u):
			u._pick_target()
	var pick := (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	for u in units:
		if is_instance_valid(u):
			d.separation(u)
	var sep := (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	for u in units:
		if is_instance_valid(u):
			u._think(1.0 / 60.0)
	var think := (Time.get_ticks_usec() - t) / 1000.0
	var parts := {}
	for name in ["water_surface", "stand_height", "update_color", "move_and_slide", "flank_move"]:
		t = Time.get_ticks_usec()
		for u in units:
			if not is_instance_valid(u):
				continue
			match name:
				"water_surface": Combat.water_surface(u.global_position)
				"stand_height": Combat.water.stand_height(u.global_position.x, u.global_position.z, u.global_position.y)
				"update_color": u._update_color()
				"move_and_slide": u.move_and_slide()
				"flank_move": u._flank_move(Vector3(5, 0, 5), 2.0)
		parts[name] = "%.2f" % ((Time.get_ticks_usec() - t) / 1000.0)
	print("    per-part, all units once: ", parts)
	print("valley %d hostile + %d friendly (stride %d, %d registered): %.2f ms/frame, worst frame %.2f ms | all target picks %.2f ms, all separation %.2f ms, all units' full tick %.2f ms" % [
		hostile, friendly, Enemy.crowd_stride, units.size(), total, worst, pick, sep, think])
