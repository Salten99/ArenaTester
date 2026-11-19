class_name RacePreview
extends SubViewportContainer
## The start screen's little 3D stage: a ring of the playable races (a carousel). The one in
## front is your choice, in the god's colors and holding the weapon; the race's mount and the
## weapon on its own turn slowly beside it. Click the left or right half to turn the ring.

signal turned(step: int)  ## -1 = the race to the left, 1 = the race to the right

const SPIN := 0.35  ## radians per second
const MOUNT_MAX_LENGTH := 3.6  ## bigger mounts are shrunk to fit the stage (m)
const WEAPON_SIZE := 1.6
const RING_RADIUS := 2.4  ## m; the front of the ring is where the chosen person stands
const RING_TURN := 8.0  ## how fast the ring swings round to a new choice

var races: Array = []  ## the ring, in order; set before show_choice
var locked: Array = []  ## races in the ring shown as black shapes (not playable yet)

var person: CharacterModel
var mount: BeastModel
var weapon: Node3D
var _viewport: SubViewport
var _stage: Node3D
var _choice := []
var _spinning: Array[Node3D] = []
var _ring: Node3D
var _ring_target := 0.0


func _ready() -> void:
	stretch = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	add_child(_viewport)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	_viewport.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.7
	_viewport.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(-0.2, 1.6, 7.8)
	_viewport.add_child(cam)
	cam.look_at(Vector3(-0.2, 1.05, 0.0))
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	_ring = Node3D.new()
	_ring.position = Vector3(-1.1, 0.0, -RING_RADIUS)
	_viewport.add_child(_ring)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click left or right (or press %s / %s) to turn the ring" % [OS.get_keycode_string(KEY_LEFT), OS.get_keycode_string(KEY_RIGHT)]


## Shows a race, weapon and god. The same choice again does nothing.
func show_choice(race_id: String, weapon_id: String, god_id: String) -> void:
	if _choice == [race_id, weapon_id, god_id]:
		return
	_choice = [race_id, weapon_id, god_id]
	for c in _stage.get_children() + _ring.get_children():
		c.free()
	_spinning.clear()
	person = null
	mount = null
	weapon = null
	if race_id == "":
		return
	var weapon_path := ModelRegistry.weapon_model(weapon_id, race_id)
	var cls := GameData.text(GameData.weapon(weapon_id), "class_name")  # each race shows the picked class's look
	var ring := races if race_id in races else [race_id]
	for i in ring.size():
		var a := TAU * i / ring.size()
		var someone := CharacterModel.new()
		_ring.add_child(someone)
		someone.position = Vector3(sin(a), 0.0, cos(a)) * RING_RADIUS
		someone.rotation.y = a + PI  # faces out of the ring, so the front one faces the camera
		if ring[i] == race_id:
			person = someone
			_ring_target = -a  # turning the ring by -a brings this place to the front
		elif someone.setup(ModelRegistry.for_race(ring[i], cls)):
			someone.play("Melee_2H_Idle")
			if ring[i] in locked:
				_black_out(someone)
	if race_id in locked:  # a locked race in front: just its dark shape, no weapon or mount
		if person.setup(ModelRegistry.for_race(race_id, cls)):
			person.play("Melee_2H_Idle")
			_black_out(person)
		return
	if person.setup(ModelRegistry.for_race(race_id, cls), weapon_path):
		person.set_god_colors(race_id, god_id)
		person.set_weapon_aura(god_id)
		person.play("Melee_2H_Idle")
	var rows: Array = GameData.where("mounts", "race_id", race_id)
	var look := ModelRegistry.for_mount(rows[0] if not rows.is_empty() else {})
	if not look.is_empty():
		mount = BeastModel.new()
		_add(mount, Vector3(1.9, 0.0, 0.0))
		mount.setup_beast(look.model, 1.0)
		mount.set_god_colors(str(look.model).get_file().get_basename(), god_id)
		mount.play("Idle_A")
		var longest := CharacterModel.bounds(mount).get_longest_axis_size()
		if longest > MOUNT_MAX_LENGTH:
			mount.scale = Vector3.ONE * MOUNT_MAX_LENGTH / longest
	if ResourceLoader.exists(weapon_path):
		weapon = (load(weapon_path) as PackedScene).instantiate()
		_add(weapon, Vector3(-3.0, 0.3, 1.2))
		weapon.scale = Vector3.ONE * WEAPON_SIZE * CharacterModel.weapon_size(weapon_path)
		CharacterModel.use_vertex_colors(weapon)
		if weapon_path.get_file().get_basename() in CharacterModel.PAIRED:
			var second: Node3D = (load(weapon_path) as PackedScene).instantiate()
			weapon.add_child(second)
			second.position.x = 0.3
			CharacterModel.use_vertex_colors(second)


func _black_out(node: Node3D) -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color.BLACK
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for m in node.find_children("*", "MeshInstance3D", true, false):
		m.material_override = dark


func _add(node: Node3D, at: Vector3) -> void:
	_stage.add_child(node)
	node.position = at
	node.rotation.y = PI
	_spinning.append(node)


func _process(delta: float) -> void:
	for n in _spinning:
		n.rotation.y += SPIN * delta
	_ring.rotation.y = lerp_angle(_ring.rotation.y, _ring_target, 1.0 - exp(-RING_TURN * delta))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		turned.emit(-1 if event.position.x < size.x * 0.5 else 1)
		accept_event()
