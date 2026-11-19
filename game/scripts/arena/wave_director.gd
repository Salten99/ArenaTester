class_name WaveDirector
extends Node
## Runs a fight's waves: spawn a wave, wait until it's cleared, spawn the next.
## Practice waves come from the tuning resource; encounters bring their own plan.

signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal all_waves_cleared
## The mini boss (or champion) arrived after the last wave.
signal boss_started(enemy: Enemy)

## Unit ids from the sheets. Milestone 0 uses one roster: barbarians.
const BASIC_UNIT := "barb_raider"
const TOUGH_UNIT := "barb_berserker"
const LARGE_UNIT := "barb_warlord"
## At most this many reinforcements join every quarter second, so they come in a stream, not a heap.
const REINFORCE_PER_CHECK := 3

var arena: Node3D
var director: CrowdDirector
var player: Node3D
var wave := -1
## Enemies appear in a ring this far from the arena center (the gladiator arena is ~50 m to the walls).
var spawn_radius := 36.0
## Where waves appear around (the arena's center, or an encounter spot in the valley).
var center := Vector3.ZERO
## Ground raycasts start this far above the reference height (high in the valley's hills).
var ray_height := 20.0
var running := false
## Endless survival (EndlessArena): the arena adds the next wave each time one is cleared.
var endless := false
## Waves from an encounter plan ([[unit_id, ...], ...]); empty = Milestone 0 waves from tuning.
var plan_waves: Array = []
## Arrives once the last wave is down; the fight ends when it falls. A unit
## token ("unit_id" or "unit_id@race"); "" = none. Not counted as a wave.
var boss := ""
## Comes where the boss fell, once everyone else is down (Count Fuckula after his dragon).
var second_boss := ""
var _boss_spawned := false
var _boss_node: Enemy
var _boss_at := Vector3.INF
## Units spawned for Count Fuckula's tribe use Void attacks and count as corrupted.
var corrupted := false
## Every hostile unit spawned gets this x its health (your allies' share, EncounterSystem.plan).
var health_mult := 1.0
## The planned waves' share of health and XP for each enemy of the one battle (Arena._one_battle);
## not the boss's, whose health the plan budgets on its own.
var army_mult := 1.0
## Next wave when this fraction of the current one is left (0 = when all are dead).
var overlap := 0.0
## Hostile units this fight is waiting on (the ones it spawned).
var members: Array = []
## Reinforcements (unit tokens): one joins whenever fewer than battle_size are fighting.
var reserve: Array = []
## Where reinforcements come from (Vector3.INF = the ring around the center).
var reserve_at := Vector3.INF
## Reinforcements wait while this many fight (0 = the tuning's battle_size).
var battle_size := 0
var _wave_size := 0
var _alive_check := 0.0


func start() -> void:
	running = true
	wave = -1
	_boss_spawned = false
	next_wave()


func total() -> int:
	return plan_waves.size() if not plan_waves.is_empty() else GameData.tuning.wave_sizes.size()


func next_wave() -> void:
	var sizes: PackedInt32Array = GameData.tuning.wave_sizes
	wave += 1
	if wave >= total():
		running = false
		all_waves_cleared.emit()
		return
	if not plan_waves.is_empty():
		for id in plan_waves[wave]:
			spawn(id, Vector3.INF, Enemy.Team.HOSTILE, false, army_mult)
		_wave_size = alive()
		wave_started.emit(wave, total())
		return
	var count := sizes[wave]
	for i in count:
		var id := BASIC_UNIT
		if wave >= 1 and i % 7 == 6:
			id = TOUGH_UNIT
		spawn(id)
	if wave == sizes.size() - 1:
		spawn(LARGE_UNIT)
	_wave_size = alive()
	wave_started.emit(wave, sizes.size())


## `token` is a unit id.
func spawn(token: String, near: Vector3 = Vector3.INF, team := Enemy.Team.HOSTILE, mini_boss := false, army := 1.0) -> Enemy:
	var e := Enemy.new()
	e.setup(token, player, director, team)
	if mini_boss:
		e.make_mini_boss()
	e.peaceful = false  # called into a fight, it fights
	e.corrupted = corrupted and team == Enemy.Team.HOSTILE
	if team == Enemy.Team.HOSTILE:
		e.health_mult = health_mult * army
		e.set_meta("xp_mult", army)
	arena.add_child(e)
	if team == Enemy.Team.HOSTILE:
		members.append(e)
	var near_player := near != Vector3.INF
	var origin := near if near_player else center
	var pos := Vector3.INF
	for attempt in 12:  # on open ground: not on a roof, a tree or a wall top, not in the water
		var angle := RunRng.randf_range(0.0, TAU)
		var dist := RunRng.randf_range(4.0, 9.0) if near_player else RunRng.randf_range(spawn_radius * 0.5, spawn_radius)
		var at := origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		at.y = ground_y(at.x, at.z)
		if pos == Vector3.INF or _open_ground(at):
			pos = at
		if _open_ground(at):
			break
	pos.y += 0.1
	e.global_position = pos
	return e


## True if `at` (from ground_y) is the land itself, not something standing on it.
func _open_ground(at: Vector3) -> bool:
	var land: Object = Combat.water
	if land == null or not land.has_method("height"):
		return true  # the arena: its floor is all there is
	return at.y < land.height(at.x, at.z) + 0.6 and Combat.water_surface(at) == -INF


## Floor height under a point (falls back to the player's height if nothing is hit).
func ground_y(x: float, z: float) -> float:
	var fallback: float = player.global_position.y if is_instance_valid(player) else center.y
	if not arena.is_inside_tree():
		return fallback
	var from := Vector3(x, fallback + ray_height, z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (ray_height + 60.0), 0b001)
	var hit := arena.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if hit else fallback


func alive() -> int:
	members = members.filter(func(e): return is_instance_valid(e) and not e.is_dead())
	return members.filter(func(e): return e.team == Enemy.Team.HOSTILE).size()


func _physics_process(delta: float) -> void:
	if not running or wave < 0:
		return
	_alive_check -= delta
	if _alive_check > 0.0:
		return
	_alive_check = 0.25
	if is_instance_valid(_boss_node):
		_boss_at = _boss_node.global_position
	var last := wave >= total() - 1
	var left := alive()
	for i in mini(REINFORCE_PER_CHECK, mini(reserve.size(), (battle_size if battle_size > 0 else GameData.tuning.battle_size) - left)):
		spawn(reserve.pop_front(), reserve_at)
		left += 1
	left += reserve.size()  # the fight isn't nearly over while reinforcements are still coming
	# The mini boss comes in while the battle still rages, at boss_when_left (user, 2026-11-09).
	var boss_due := last and boss != "" and not _boss_spawned and left <= (GameData.tuning.boss_when_left if not plan_waves.is_empty() else 0)
	if boss_due or left <= (0 if last else floori(_wave_size * overlap)):
		if last and boss != "" and not _boss_spawned:
			_boss_spawned = true
			var b := spawn(boss, Vector3.INF, Enemy.Team.HOSTILE, not boss.begins_with("champ_") and second_boss == "")
			_boss_node = b
			boss_started.emit(b)
			return
		if last and second_boss != "":
			var next := spawn(second_boss, _boss_at)
			second_boss = ""
			boss_started.emit(next)
			return
		running = false
		wave_cleared.emit(wave)


## Back to idle after an encounter in the valley.
func reset() -> void:
	running = false
	wave = -1
	plan_waves = []
	boss = ""
	second_boss = ""
	_boss_spawned = false
	_boss_node = null
	_boss_at = Vector3.INF
	corrupted = false
	health_mult = 1.0
	army_mult = 1.0
	members = []
	reserve = []
	reserve_at = Vector3.INF
	battle_size = 0


func resume() -> void:
	running = true
	next_wave()
