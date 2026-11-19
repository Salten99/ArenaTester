class_name Arena
extends Node3D
## The fight scene. The Valley extends it (fights happen in the valley); on its
## own it's the Practice arena or runs one encounter (tests).
##
## Milestone 0: one arena, the player pledged to the Lord of the Forge, waves of
## barbarians, and godly gifts from the Lord of the Forge (Forge) and the Storm Caller (Storm) between waves.
## Everything is built in code so the scene file stays a single node.

const ARENA_SIZE := 60.0
const START_GOD := "forge_god"
const START_RACE := "dwarf"
const START_WEAPON := "warhammer"
## Gods whose godly gifts are offered, in turn, after each wave.
const OFFER_GODS := ["forge_god", "storm_god"]

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
## Gods whose gifts are offered in turn (Practice sets it from the god you picked).
var offer_gods: Array = OFFER_GODS
## The run encounter this fight is for ("" = practice arena with its own short run).
var encounter_id := ""
## True while a god's godly gift choice is open after an encounter.
var _offering_god := false


func _ready() -> void:
	HitStop.clear()
	Combat.water = null
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
	Run.player = player
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
	waves.boss_started.connect(_on_boss_started)

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


## Makes sure a run exists and picks the encounter (overridden by the Valley).
func _prepare_run() -> void:
	encounter_id = Flow.pending_encounter if Run.active else ""
	if encounter_id == "":
		# Practice: Milestone 0 runs inside its own short run, so XP and level-ups work.
		# The god and class come from the start screen's Practice picker (Flow.goto_practice).
		var god := Flow.practice_god if Flow.practice_god != "" else START_GOD
		var weapon := Flow.practice_weapon if Flow.practice_weapon != "" else START_WEAPON
		Run.start_new(START_RACE, god, run_seed, 0.34, weapon)
		Run.practice = true
		offer_gods = _practice_offer_gods(god)


## Whose godly gifts the Practice arena offers after each wave, for the god you picked.
func _practice_offer_gods(god: String) -> Array:
	# The picked god comes first (user, 2026-11-17); Practice is for animations and effects, not gifts.
	return [god] + OFFER_GODS.filter(func(g): return g != god)


## Builds the level the player stands in (overridden by the Valley).
func _build_level() -> void:
	if world_scene != null:
		var world := world_scene.instantiate()
		add_child(world)
		CharacterModel.use_vertex_colors(world)
	else:
		_build_world()
	# Things to throw in the practice arena (combat feel plan, 2026-11-18).
	for i in 8:
		var a := TAU * i / 8.0
		Throwable.make(Throwable.KINDS[i % 4], self, Vector3(cos(a), 0.0, sin(a)) * 9.0, a)


## Starts play once everything exists (overridden by the Valley).
func _begin() -> void:
	if encounter_id != "":
		_start_encounter()
	elif auto_start:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.show_message("Pledged to %s. Choose your first godly gift." % GameData.text(GameData.row("gods", Run.state.god_id), "display_name", Run.state.god_id), 3.0)
		_offer_next()


## Warriors fighting on your side in this encounter (the Valley brings some).
func _friendly_count() -> int:
	return 0


## True when this fight belongs to a run (death ends the run, wins go back to the valley).
func _in_run() -> bool:
	return encounter_id != ""


func _physics_process(delta: float) -> void:
	Run.tick(delta)  # only the run's play time moves during fights; the valley clock waits


# ---------------------------------------------------------------- encounter mode

func _start_encounter() -> void:
	var plan := EncounterSystem.plan(Run.state, encounter_id, _friendly_count())
	EncounterSystem.start(Run.state, encounter_id)
	Playtest.fight_started(encounter_id)
	waves.health_mult = 1.0  # enemies keep their sheet health (pivot, 2026-11-18)
	waves.plan_waves = _one_battle(plan.get("waves", []), plan.get("reserve", []))
	waves.overlap = GameData.tuning.wave_overlap
	waves.boss = plan.get("boss", "")  # after the last wave: a mini boss, or the champion
	waves.second_boss = plan.get("second_boss", "")
	var def := GameData.row("encounters", Run.state.encounters[encounter_id].def)
	waves.corrupted = str(Run.state.encounters[encounter_id].get("source", GameData.text(def, "enemy_source"))).begins_with("Evil")  # a raid by the Count's army too
	if not Run.god_offered.is_connected(_on_god_offered):
		Run.god_offered.connect(_on_god_offered)
	if not hud.god_chosen.is_connected(_on_god_chosen):
		hud.god_chosen.connect(_on_god_chosen)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_message("%s: %s" % [GameData.text(def, "display_name"), GameData.text(def, "objective")], 3.0)
	get_tree().create_timer(GameData.tuning.time_between_waves, false).timeout.connect(_continue_waves)


## The plan's waves as one big battle of battle_size enemies (user, 2026-11-09). Their health
## is scaled so the whole fight still holds as much as the plan meant.
## A fight needing more than battle_size enemies keeps battle_size on the field and sends the rest
## in as the others fall (WaveDirector.reserve).
func _one_battle(planned: Array, reserve: Array = []) -> Array:
	waves.army_mult = 1.0
	var all: Array = []
	for w in planned:
		all.append_array(w)
	all.append_array(reserve)
	if all.is_empty():
		return []
	var size: int = GameData.tuning.battle_size
	if all.size() > size:
		waves.reserve = all.slice(size)
		return [all.slice(0, size)]
	waves.army_mult = float(all.size()) / size
	var army: Array = []
	for i in size:
		army.append(all[i % all.size()])
	return [army]


func _finish_encounter(won: bool) -> void:
	var was_final := encounter_id == "final_battle"
	Playtest.fight_ended(encounter_id, won)
	Run.finish_encounter(encounter_id, won)
	if was_final and won:
		hud.show_message("Count Fuckula's tribe is broken. You won the run!", 0.0)
		_announce_unlocks(Run.last_result.get("unlocked", []))
		hud.show_action("Back to the start screen", Flow.goto_director)
	elif not _offering_god:
		_return_to_valley()


## After an encounter (and its god choice): back to exploring.
func _return_to_valley() -> void:
	hud.show_action("Return to the valley", Flow.goto_valley)


func _on_god_offered(god_id: String) -> void:
	_offering_god = true
	hud.offer_god(god_id, player.godly_gifts.make_offer(god_id))


func _on_god_chosen(choice: String) -> void:
	_offering_god = false
	Run.state.pending_god = ""
	_offer_level_up.call_deferred()
	if choice != "":
		player.godly_gifts.add_godly_gift(choice)
		hud.show_message("Gained %s" % _godly_gift_name(choice), 1.5)
	Run.checkpoint("after_god_choice")
	if encounter_id != "":  # an offer left open from last session comes with no fight to leave
		_return_to_valley()


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


func _on_boss_started(e: Enemy) -> void:
	hud.show_message("%s joins the fight!" % GameData.text(e.unit, "display_name", "A mini boss"), 2.0)


func _on_wave_cleared(index: int) -> void:
	if encounter_id != "":
		if index + 1 >= waves.total():
			_finish_encounter(true)
		else:
			get_tree().create_timer(GameData.tuning.time_between_waves, false).timeout.connect(_continue_waves)
		return
	if index + 1 >= GameData.tuning.wave_sizes.size():
		_on_victory()
	elif GameData.tuning.godly_gift_after_each_wave:
		_offer_next()
	else:
		_continue_waves()


func _on_victory() -> void:
	if encounter_id != "":
		return  # encounter mode finishes in _on_wave_cleared
	hud.show_message("The arena is cleared!  F9 to play again.", 0.0)
	_announce_unlocks(Run.end(true))


func _on_player_died() -> void:
	Playtest.death()
	if _in_run():
		hud.show_message("You fell. The run is over.", 0.0)
		_announce_unlocks(Run.end(false))
		hud.show_action("Back to the start screen", Flow.goto_director)
		return
	hud.show_message("You fell.  F9 to try again.", 0.0)
	_announce_unlocks(Run.end(false))


func _announce_unlocks(unlocked: Array) -> void:
	for u in unlocked:
		var row := GameData.row(u.kind, u.id)
		var name_key := "display_name"
		hud.show_message("Unlocked: %s" % GameData.text(row, name_key, u.id), 3.0)


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
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR  # Retro look: plain colors
	ValleyWorld._ps2_glow(e)
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
