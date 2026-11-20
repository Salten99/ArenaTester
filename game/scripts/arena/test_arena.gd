class_name TestArena
extends EndlessArena
## Test mode (user, 2026-11-20): the arena with no enemies and no traps, for animation and effect
## testing. Number keys switch your element at will, spells have no cooldown, nothing hurts you,
## weapons lie about, and a ring of props stands ready to smash (each comes back a while after).

const SCENE := "res://scenes/test_arena.tscn"
## The props to smash (Breakable kinds), on a ring this far from the middle.
const TARGETS := ["barrel", "crate", "hay", "cart", "market_stand", "barrel", "crate", "hay"]
const TARGET_RING := 11.0
## Seconds before a smashed prop stands again.
const TARGET_BACK := 3.0

var _targets := {}  ## ring slot -> the prop's model (freed once smashed)


## The endless arena's setup without its loadout menu, waves or traps.
func _begin() -> void:
	var picked := loadout_picked
	loadout_picked = true
	super()
	loadout_picked = picked


func _queue_wave(_index: int) -> void:
	pass


func _build_hazards() -> void:
	pass


func _start_fight() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	start_test()


func start_test() -> void:
	player.god_mode = true
	for i in TARGETS.size():
		_place_target(i)
	var names: Array = ArenaMenu.elements().map(func(g): return GameData.text(GameData.god(g), "element", g))
	var keys := ""
	for i in names.size():
		keys += "%d %s   " % [i + 1, names[i]]
	hud.show_message("Test mode: no cooldowns, nothing hurts you.\nSwitch element: " + keys, 6.0)


## Switches to the `index`th element (ArenaMenu.elements), keeping your weapon.
func switch_element(index: int) -> void:
	var gods := ArenaMenu.elements()
	if index < 0 or index >= gods.size():
		return
	Flow.practice_god = gods[index]  # a restart keeps it
	Run.state.god_id = gods[index]
	player.setup(player.race_id, gods[index], player.weapon_id)
	hud.show_message(GameData.text(GameData.god(gods[index]), "element", gods[index]), 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not get_tree().paused:
		var k: int = event.keycode - KEY_1
		if k >= 0 and k < 9:
			switch_element(k)


func _physics_process(_delta: float) -> void:
	for slot in player.abilities.remaining:
		player.abilities.remaining[slot] = 0.0  # no spell cooldowns
	for i in _targets.keys():
		if not is_instance_valid(_targets[i]):
			_targets.erase(i)  # its timer puts it back
			get_tree().create_timer(TARGET_BACK, false).timeout.connect(_place_target.bind(i))


func _place_target(i: int) -> void:
	var kind: String = TARGETS[i]
	var a := TAU * (i + 0.5) / TARGETS.size()
	var at := Vector3(cos(a), 0.0, sin(a)) * TARGET_RING
	at.y = waves.ground_y(at.x, at.z)
	var model := (load(Breakable.PROPS + kind + ".glb") as PackedScene).instantiate() as Node3D
	add_child(model)
	model.global_position = at
	model.rotation.y = -a
	CharacterModel.use_vertex_colors(model)
	Breakable.attach(model, kind)
	_targets[i] = model
