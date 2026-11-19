class_name Arena
extends Node3D
## The fight scene: the practice arena (waves with godly gifts between them; tests use it) and
## the base of EndlessArena. Everything is built in code so the scene file stays a single node.

const ARENA_SIZE := 60.0
const START_GOD := "forge_god"
const START_RACE := "dwarf"
const START_WEAPON := "warhammer"
## Gods whose godly gifts are offered, in turn, after each wave.
const OFFER_GODS := ["forge_god", "storm_god"]

## The arena model's look: the user's grass and stone pictures (shaders/arena_ground.gdshader).
const ARENA_GROUND := preload("res://materials/arena_ground.tres")
## The level the fight happens in (the gladiator arena from sam-movement).
## Clear it to fall back to the plain box arena built in code.
@export var world_scene: PackedScene = preload("res://scenes/gladiator_arena.tscn")
## Where the player starts; they drop onto the floor below.
@export var player_start := Vector3(0, 0.0, 0.4)
## Set a seed to replay a run exactly; -1 = random.
@export var run_seed := -1
## Skip the godly gift choice at the start (used by tests).
@export var auto_start := true

var player: Player
var camera_rig: CameraRig
var director: CrowdDirector
var waves: WaveDirector
var hud: Hud
var _offer_index := 0
## Gods whose gifts are offered in turn (set from the god you picked).
var offer_gods: Array = OFFER_GODS


func _ready() -> void:
	HitStop.clear()
	_prepare_run()
	_build_level()
	Combat.effects_root = self

	director = CrowdDirector.new()
	add_child(director)
	Combat.crowd = director

	player = Player.new()
	player.race_id = Run.state.race_id
	player.god_id = Run.state.god_id
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	var input := PlayerInput.new()
	input.camera_rig = camera_rig
	player.input_source = input
	player.add_child(input)
	add_child(player)
	player.global_position = player_start
	player.died.connect(_on_player_died)
	player.apply_run_state(Run.state)
	camera_rig.target = player
	camera_rig.snap_to_target()
	Combat.camera_rig = camera_rig

	waves = WaveDirector.new()
	waves.arena = self
	waves.director = director
	waves.player = player
	add_child(waves)
	waves.wave_started.connect(_on_wave_started)
	waves.wave_cleared.connect(_on_wave_cleared)
	waves.all_waves_cleared.connect(_on_victory)

	hud = Hud.new()
	hud.player = player
	hud.waves = waves
	hud.director = director
	add_child(hud)
	hud.godly_gift_chosen.connect(_on_godly_gift_chosen)
	hud.level_up_chosen.connect(_on_level_up_chosen)
	hud.choice_made.connect(func(_kind, _id): _offer_level_up.call_deferred())  # a level-up that waited behind another menu
	Combat.killed.connect(_on_killed)

	var debug := DebugTools.new()  # only P (god mode) works in a release .exe
	debug.arena = self
	add_child(debug)
	_begin()


## A fresh fight state, with the god and weapon picked in the arena menu (Flow), so XP and level-ups work.
func _prepare_run() -> void:
	var god := Flow.practice_god if Flow.practice_god != "" else START_GOD
	var weapon := Flow.practice_weapon if Flow.practice_weapon != "" else START_WEAPON
	Run.start_new(START_RACE, god, run_seed, weapon)
	offer_gods = _practice_offer_gods(god)


## Whose godly gifts the Practice arena offers after each wave, for the god you picked.
func _practice_offer_gods(god: String) -> Array:
	# The picked god comes first (user, 2026-11-17); Practice is for animations and effects, not gifts.
	return [god] + OFFER_GODS.filter(func(g): return g != god)


## Builds the level the player stands in.
func _build_level() -> void:
	if world_scene != null:
		var world := world_scene.instantiate()
		add_child(world)
		CharacterModel.use_vertex_colors(world)
		# The user's grass and stone pictures on the arena model (tune them in materials/arena_ground.tres).
		for m in world.find_children("arena", "MeshInstance3D", true, false):
			var ground: ShaderMaterial = ARENA_GROUND
			for pic in ["grass", "stone"]:
				var avg := _average((ground.get_shader_parameter(pic) as Texture2D).get_image())
				ground.set_shader_parameter(pic + "_gain", Vector3(1.0 / avg.r, 1.0 / avg.g, 1.0 / avg.b))
			(m as MeshInstance3D).material_override = ground
	else:
		_build_world()
	# Things to throw in the practice arena (combat feel plan, 2026-11-18).
	for i in 8:
		var a := TAU * i / 8.0
		Throwable.make(Throwable.KINDS[i % 4], self, Vector3(cos(a), 0.0, sin(a)) * 9.0, a)


## Starts play once everything exists.
func _begin() -> void:
	if auto_start:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.show_message("Pledged to %s. Choose your first godly gift." % GameData.text(GameData.row("gods", Run.state.god_id), "display_name", Run.state.god_id), 3.0)
		_offer_next()


func _offer_next() -> void:
	var god: String = offer_gods[_offer_index % offer_gods.size()]
	_offer_index += 1
	hud.offer_godly_gifts(god, player.godly_gifts.make_offer(god))


## XP for every enemy that falls in your fight, whoever landed the blow.
func _on_killed(target: Node, info: DamageInfo) -> void:
	if not Run.active or target.get("team") != Enemy.Team.HOSTILE:
		return
	if info != null and info.source is Enemy and (info.source as Enemy).team == Enemy.Team.HOSTILE:
		return  # one wild side killing another: not your XP
	Run.note("kills")
	Meta.discover(str(target.get("unit_id")))
	give_xp(GameData.num(target.get("unit") if target.get("unit") != null else {}, "xp_reward", 2.0) * float(target.get_meta("xp_mult", 1.0)))  # a battle's share (WaveDirector.army_mult)


func give_xp(xp: float) -> void:
	Run.state.pending_level_ups += LevelSystem.add_xp(Run.state, xp, player.stats)
	_offer_level_up()


func _offer_level_up() -> void:
	if not Run.active or Run.state.pending_level_ups <= 0 or hud.is_choosing() or player.is_dead():
		return  # no level-ups once the run is over
	hud.offer_level_up(Run.state.level, LevelSystem.make_offer(Run.state))


func _on_level_up_chosen(upgrade_id: String) -> void:
	Run.state.pending_level_ups -= 1  # counted off only now: quit on this menu and it's still owed
	if upgrade_id != "":
		LevelSystem.pick(Run.state, upgrade_id, player.stats)
		hud.show_message("Gained %s" % GameData.text(GameData.row("level_up_options", upgrade_id), "display_name"), 1.2)
	_offer_level_up.call_deferred()


func _on_godly_gift_chosen(godly_gift_id: String) -> void:
	_offer_level_up.call_deferred()
	if godly_gift_id != "":
		player.godly_gifts.add_godly_gift(godly_gift_id)
		hud.show_message("Gained %s" % _godly_gift_name(godly_gift_id), 1.5)
	var delay := GameData.tuning.time_between_waves
	get_tree().create_timer(delay, false).timeout.connect(_continue_waves)


func _continue_waves() -> void:
	if player.is_dead():
		return
	if waves.wave < 0:
		waves.start()
	else:
		waves.resume()


func _on_wave_started(index: int, total: int) -> void:
	hud.show_message("Wave %d of %d" % [index + 1, total] if total > 1 else "The battle is on!", 1.5)



func _on_wave_cleared(index: int) -> void:
	if index + 1 >= GameData.tuning.wave_sizes.size():
		_on_victory()
	elif GameData.tuning.godly_gift_after_each_wave:
		_offer_next()
	else:
		_continue_waves()


func _on_victory() -> void:
	hud.show_message("The arena is cleared!", 0.0)
	Run.end()
	hud.show_action("Play again", restart)


func _on_player_died() -> void:
	Playtest.death()
	hud.show_message("You fell.", 0.0)
	Run.end()
	hud.show_action("Try again", restart)


## Starts this scene over (the Try again button, and F9 in debug builds).
func restart() -> void:
	HitStop.clear()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _godly_gift_name(id: String) -> String:
	var def := GameData.row("godly_gifts", id)
	if def.is_empty():
		def = GameData.row("duo_godly_gifts", id)
	return GameData.text(def, "display_name", id)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.5, 0.75)
	sky_mat.sky_horizon_color = Color(0.75, 0.7, 0.6)
	sky_mat.ground_horizon_color = Color(0.5, 0.45, 0.4)
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.2
	add_child(sun)

	_box(Vector3(0, -0.5, 0), Vector3(ARENA_SIZE, 1.0, ARENA_SIZE), Color(0.42, 0.45, 0.35))
	var half := ARENA_SIZE * 0.5
	var wall_color := Color(0.5, 0.47, 0.42)
	_box(Vector3(0, 1.5, -half), Vector3(ARENA_SIZE, 3, 1), wall_color)
	_box(Vector3(0, 1.5, half), Vector3(ARENA_SIZE, 3, 1), wall_color)
	_box(Vector3(-half, 1.5, 0), Vector3(1, 3, ARENA_SIZE), wall_color)
	_box(Vector3(half, 1.5, 0), Vector3(1, 3, ARENA_SIZE), wall_color)
	for p in [Vector3(-12, 2, -12), Vector3(12, 2, -12), Vector3(-12, 2, 12), Vector3(12, 2, 12)]:
		_box(p, Vector3(2, 4, 2), wall_color.darkened(0.15))


func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 0b001
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	body.position = pos


## The average color of a picture (linear), to even out the ground textures' brightness.
static func _average(img: Image) -> Color:
	if img.is_compressed():
		img.decompress()
	var sum := Color(0, 0, 0)
	for y in img.get_height():
		for x in img.get_width():
			sum += img.get_pixel(x, y).srgb_to_linear()
	return sum / float(img.get_width() * img.get_height())
