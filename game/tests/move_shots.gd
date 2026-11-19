extends "res://tests/test_runner.gd"
## Pictures of your moves in the practice arena, run by hand in a window (not part of the tests):
##   <godot_console.exe> --path game res://tests/move_shots.tscn -- --out=<folder>
## A sheet per move (a light swing, a charged heavy, grab and crush, grab and throw), one picture
## every 3 frames from the side, to check them against the reels (user, 2026-11-18).

const CELL := 260
const COLS := 6
const ROWS := 4
var _out := "user://move_shots"
var _cam: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.get_slice("=", 1)
	Meta.persist = false
	Playtest.persist = false
	get_window().size = Vector2i(CELL * 3, CELL * 3)
	await get_tree().process_frame
	await _setup()
	var p: Player = _arena.player
	p.god_mode = true
	await _until_on_floor()
	for old in get_tree().get_nodes_in_group("throwables"):
		old.queue_free()
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	var s := _scripted()
	# A light swing at a raider.
	var foe: Enemy = _cluster(1, 2.0)[0]
	s.press("light")
	await _sheet("light", 1)
	foe.queue_free()
	await _frames(60)
	# A charged heavy.
	foe = _cluster(1, 2.0)[0]
	s.press("heavy")
	s.hold({"heavy_held": true}, 50)
	await _sheet("heavy", 2)
	foe.queue_free()
	await _frames(60)
	# Grab and crush.
	foe = _cluster(1, 1.6)[0]
	await _frames(2)
	s.hold({"light": true, "light_held": true}, 1)
	s.hold({"light_held": true}, 120)
	await _frames(18)
	await _sheet("grab_crush", 3)
	await _frames(60)
	# Grab and throw.
	foe = _cluster(1, 1.6)[0]
	await _frames(2)
	s.hold({"light": true, "light_held": true}, 1)
	s.hold({"light_held": true}, 40)
	s.hold({"light_held": true, "heavy": true}, 1)
	s.hold({"light_held": true}, 30)
	await _frames(30)
	await _sheet("grab_throw", 2)
	get_tree().quit()


func _sheet(name: String, every: int) -> void:
	var p: Player = _arena.player
	var img := Image.create(CELL * COLS, CELL * ROWS, false, Image.FORMAT_RGB8)
	for i in COLS * ROWS:
		var side := p.facing.cross(Vector3.UP)
		_cam.global_position = p.global_position + side * 2.6 + p.facing * 2.6 + Vector3.UP * 1.5
		_cam.look_at(p.global_position + p.facing * 0.6 + Vector3.UP * 1.0)
		await _frames(every)
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGB8)
		shot.resize(CELL, CELL)
		img.blit_rect(shot, Rect2i(0, 0, CELL, CELL), Vector2i((i % COLS) * CELL, (i / COLS) * CELL))
	img.save_png(_out + "/move_%s.png" % name)
