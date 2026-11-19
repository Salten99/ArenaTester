class_name WaveDirector
extends Node
## Runs a fight's waves: spawn a wave, wait until it's cleared, spawn the next.
## Practice waves come from the tuning resource; the endless arena plans its own (plan_waves, reserve).

signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal all_waves_cleared

## Unit ids from the sheets: the arena's mythical roster (fantasy pivot, 2026-11-19).
const BASIC_UNIT := "horde_skeleton_warrior"
const TOUGH_UNIT := "minotaur_labrys_warrior"
const LARGE_UNIT := "monster_cyclops"
## At most this many reinforcements join every quarter second, so they come in a stream, not a heap.
const REINFORCE_PER_CHECK := 3

var arena: Node3D
var director: CrowdDirector
var player: Node3D
var wave := -1
## Enemies appear in a ring this far from the arena center (the gladiator arena is ~50 m to the walls).
var spawn_radius := 36.0
## Where waves appear around (the arena's center).
var center := Vector3.ZERO
## Ground raycasts start this far above the reference height.
var ray_height := 20.0
var running := false
## Endless survival (EndlessArena): the arena adds the next wave each time one is cleared.
var endless := false
## Planned waves ([[unit_id, ...], ...]); empty = the practice waves from tuning.
var plan_waves: Array = []
## Hostile units this fight is waiting on (the ones it spawned).
var members: Array = []
## Reinforcements (unit tokens): one joins whenever fewer than battle_size are fighting.
var reserve: Array = []
## Reinforcements wait while this many fight (0 = the tuning's battle_size).
var battle_size := 0
## Arena tactics (the endless arena): hostile units get Enemy.tactics, a "#shield" token a shield,
## and a caster (role Magic) one of WITCH_ELEMENTS.
var tactics := false
const SHIELD_TAG := "#shield"
const WITCH_ELEMENTS := ["fire", "ice", "poison", "water"]
## Health by hits (the endless arena): a hostile unit listed here gets hit_damage x its count.
var hit_damage := 0.0
var hits_to_kill := {}
var _alive_check := 0.0


func start() -> void:
	running = true
	wave = -1
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
			spawn(id)
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
	wave_started.emit(wave, sizes.size())


## `token` is a unit id.
func spawn(token: String, near: Vector3 = Vector3.INF, team := Enemy.Team.HOSTILE) -> Enemy:
	var shield := token.ends_with(SHIELD_TAG)  # "horde_skeleton_warrior#shield": one with a shield (arena tactics)
	token = token.trim_suffix(SHIELD_TAG)
	var e := Enemy.new()
	e.setup(token, player, director, team)
	if tactics and team == Enemy.Team.HOSTILE:
		e.tactics = true
		e.shielded = shield
		if GameData.text(e.unit, "role") == "Magic":
			e.element_status = RunRng.pick(WITCH_ELEMENTS)
	e.peaceful = false  # called into a fight, it fights
	arena.add_child(e)
	if team == Enemy.Team.HOSTILE:
		members.append(e)
		if hit_damage > 0.0 and hits_to_kill.has(token):
			e.health.setup(hit_damage * float(hits_to_kill[token]))
		if e.shielded and e.model != null:
			e.model.set_offhand(ModelRegistry.own(Player.SHIELD))
		if e.element_status != "":  # a caster wears her element
			var aura := ElementFx.aura(GameData.text(GameData.status(e.element_status), "damage_type", "Physical"), 0.7)
			if aura != null:
				e.add_child(aura)
				aura.emitting = true
	var near_player := near != Vector3.INF
	var origin := near if near_player else center
	var angle := RunRng.randf_range(0.0, TAU)
	var dist := RunRng.randf_range(4.0, 9.0) if near_player else RunRng.randf_range(spawn_radius * 0.5, spawn_radius)
	var pos := origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	pos.y = ground_y(pos.x, pos.z) + 0.1
	e.global_position = pos
	return e


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
	var left := alive()
	for i in mini(REINFORCE_PER_CHECK, mini(reserve.size(), (battle_size if battle_size > 0 else GameData.tuning.battle_size) - left)):
		spawn(reserve.pop_front())
		left += 1
	if left + reserve.size() <= 0:  # the fight isn't over while reinforcements are still coming
		running = false
		wave_cleared.emit(wave)


func resume() -> void:
	running = true
	next_wave()
