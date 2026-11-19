extends Node
## Moves between the game's screens so every scene doesn't invent its own way.
##   director (the start screen: start or continue a run)
##   valley   (the run itself: explore, fight encounters where you find them)
##   fight    (the arena running one encounter: set pending_encounter; used by tests)
##   practice (the Milestone 0 arena on its own)


const DIRECTOR := "res://scenes/run_director.tscn"
const VALLEY := "res://scenes/valley.tscn"
const FIGHT := "res://scenes/main.tscn"

## The encounter the next fight scene should run ("" = practice mode).
var pending_encounter := ""
## The valley built behind the loading screen, for Valley to take: {seed, terrain, world}.
var prepared := {}


func _ready() -> void:
	get_tree().root.theme = UiStyle.theme()  # one look for every screen (UiStyle)


func goto_director() -> void:
	pending_encounter = ""
	Run.in_fight = false
	_change(DIRECTOR)


func goto_valley() -> void:
	pending_encounter = ""
	Run.in_fight = false
	if not Run.active:
		_change(VALLEY)
		return
	# Build the valley behind a loading screen, a slice at a time, then hand it over.
	var screen := LoadingScreen.new()
	get_tree().root.add_child.call_deferred(screen)  # deferred: works even while a scene is still setting up
	await get_tree().process_frame
	await screen.report(0.0, "Preparing the valley")
	await screen.report(0.0)
	ValleyTerrain.assign_slots(Run.state)
	var terrain := ValleyTerrain.new(Run.state.seed)
	var world := ValleyWorld.new()
	world.name = "World"
	world.terrain = terrain
	world.state = Run.state
	await world.build(screen.report)
	prepared = {"seed": Run.state.seed, "terrain": terrain, "world": world}
	await screen.report(1.0, "Entering the valley")
	_change(VALLEY)
	await get_tree().process_frame
	await get_tree().process_frame
	screen.queue_free()


## The valley built behind the loading screen for this seed (and forgets it), or {}.
func take_prepared(seed_value: int) -> Dictionary:
	var p := prepared
	prepared = {}
	if p.get("seed", null) != seed_value:
		if p.has("world"):
			p.world.free()
		return {}
	return p


## The god and class (melee weapon) the Practice arena starts with ("" = Arena's defaults).
var practice_god := ""
var practice_weapon := ""


func goto_practice(god := "", weapon := "") -> void:
	pending_encounter = ""
	practice_god = god
	practice_weapon = weapon
	_change(FIGHT)


func _change(path: String) -> void:
	HitStop.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)
