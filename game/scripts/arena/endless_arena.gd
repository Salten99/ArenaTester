class_name EndlessArena
extends Arena
## Endless survival: waves keep coming, each one bigger and tougher, until you fall.
## Your score is the wave you reached and how many you killed. No godly gift menus between
## waves (level-ups from XP still come). Everything else (the player, combat, the gladiator
## arena, the things to throw) is Arena's.

## Enemies in the first wave, and how many more each wave brings.
const START_SIZE := 6
const GROWTH := 4
## shortcut: capped so the frame rate holds; raise it once the crowd split handles more.
const MAX_SIZE := 80
## From this wave on, every fifth enemy is a tough one.
const TOUGH_FROM := 2
## Every this many waves, a large one joins.
const LARGE_EVERY := 3

var kills := 0


## The units for wave `index` (0 = the first).
static func wave_units(index: int) -> Array:
	var count := mini(START_SIZE + GROWTH * index, MAX_SIZE)
	var units: Array = []
	for i in count:
		units.append(WaveDirector.TOUGH_UNIT if index >= TOUGH_FROM and i % 5 == 4 else WaveDirector.BASIC_UNIT)
	if (index + 1) % LARGE_EVERY == 0:
		units.append(WaveDirector.LARGE_UNIT)
	return units


func _begin() -> void:
	waves.endless = true
	waves.plan_waves = [wave_units(0)]
	if not auto_start:
		return  # tests start the waves themselves
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_message("Survive as long as you can.", 2.5)
	get_tree().create_timer(GameData.tuning.time_between_waves, false).timeout.connect(_continue_waves)


func _on_wave_started(index: int, _total: int) -> void:
	hud.show_message("Wave %d" % (index + 1), 1.5)


func _on_wave_cleared(index: int) -> void:
	waves.plan_waves.append(wave_units(index + 1))
	hud.show_message("Wave %d survived" % (index + 1), 1.5)
	get_tree().create_timer(GameData.tuning.time_between_waves, false).timeout.connect(_continue_waves)


func _on_killed(target: Node, info: DamageInfo) -> void:
	if target.get("team") == Enemy.Team.HOSTILE:
		kills += 1
	super(target, info)


func _on_player_died() -> void:
	Playtest.death()
	hud.show_message("You fell on wave %d with %d kills.  F9 to try again." % [waves.wave + 1, kills], 0.0)
	Run.end(false)
