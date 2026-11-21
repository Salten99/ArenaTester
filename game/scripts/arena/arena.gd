class_name Arena
extends Node3D
## The fight scene: the base of EndlessArena (tests use it bare, as main.tscn). Everything is
## built in code so the scene file stays a single node.

const ARENA_SIZE := 60.0
const START_GOD := "forge_god"
const START_RACE := "dwarf"

## The arena model's look: the user's grass and stone pictures (shaders/arena_ground.gdshader).
const ARENA_GROUND := preload("res://materials/arena_ground.tres")
## The level the fight happens in (the gladiator arena from sam-movement).
## Clear it to fall back to the plain box arena built in code.
@export var world_scene: PackedScene = preload("res://scenes/gladiator_arena.tscn")
## Where the player starts; they drop onto the floor below.
@export var player_start := Vector3(0, 0.0, 0.4)
## Set a seed to replay a run exactly; -1 = random.
@export var run_seed := -1
## Start the fight on its own (tests turn it off and drive it themselves).
@export var auto_start := true

var player: Player
var camera_rig: CameraRig
var director: CrowdDirector
var waves: WaveDirector
var hud: Hud


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

	hud = Hud.new()
	hud.player = player
	hud.waves = waves
	hud.director = director
	add_child(hud)

	var debug := DebugTools.new()  # only P (god mode) works in a release .exe
	debug.arena = self
	add_child(debug)
	_begin()


## Starts play once everything exists (EndlessArena starts its waves here).
func _begin() -> void:
	if auto_start:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A fresh fight state, with the god picked in the arena menu (Flow).
## You start with your fists (Run.start_new); weapons lie about the arena (scatter_weapons).
func _prepare_run() -> void:
	var god := Flow.practice_god if Flow.practice_god != "" else START_GOD
	Run.start_new(START_RACE, god, run_seed)


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
	_add_motes()
	# Things to throw in the practice arena (combat feel plan, 2026-11-18).
	for i in 8:
		var a := TAU * i / 8.0
		Throwable.make(Throwable.KINDS[i % 4], self, Vector3(cos(a), 0.0, sin(a)) * 9.0, a)
	scatter_weapons()


## Lays weapons about the arena until weapon_pickups lie there (user, 2026-11-20): at the start one of
## each kind in turn on a ring, and after each wave more to make up for thrown ones that were lost.
func scatter_weapons() -> void:
	var kinds := GameData.pickup_weapons()
	if kinds.is_empty():
		return  # weapons.json lost its rows (GameData printed why): fists only
	var lying := get_tree().get_nodes_in_group("weapon_pickups").filter(func(w): return not w.is_queued_for_deletion()).size()
	for i in maxi(0, GameData.tuning.weapon_pickups - lying):
		spawn_weapon(kinds[(lying + i) % kinds.size()])


## Lays weapon `id` somewhere about the arena (a new one for one stuck in a wall).
func spawn_weapon(id: String) -> WeaponPickup:
	var a := RunRng.randf_range(0.0, TAU)
	return WeaponPickup.make(id, self, Vector3(cos(a), 0.0, sin(a)) * RunRng.randf_range(5.0, 14.0))


## Glowing motes of magic drifting slowly up over the arena floor (arena_motes, arena_mote_color).
func _add_motes() -> void:
	var t: CombatTuning = GameData.tuning
	if t.arena_motes <= 0:
		return
	var motes := GPUParticles3D.new()
	motes.name = "Motes"
	motes.amount = t.arena_motes
	motes.lifetime = 9.0
	motes.preprocess = 9.0  # already drifting when the fight opens
	motes.visibility_aabb = AABB(Vector3(-40, -2, -40), Vector3(80, 16, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(32, 3, 32)
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.08, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 6.0
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var fade := Gradient.new()  # fade in and out, so none pops
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	motes.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = t.arena_mote_color
	mat.emission_enabled = true
	mat.emission = t.arena_mote_color
	mat.emission_energy_multiplier = 4.0  # bright enough to bloom
	quad.material = mat
	motes.draw_pass_1 = quad
	add_child(motes)
	motes.position = Vector3(0, 3.5, 0)


func _continue_waves() -> void:
	if player.is_dead():
		return
	if waves.wave < 0:
		waves.start()
	else:
		waves.resume()


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
