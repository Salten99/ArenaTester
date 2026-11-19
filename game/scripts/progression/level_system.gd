class_name LevelSystem
extends RefCounted
## XP and level-ups (Level Up Options sheet). Level-ups are universal: they
## stay when you switch gods. Each level-up offers 3 upgrades weighted by
## rarity; picks become a PlayerStats source called "levels".

## Level Up Options "stat" names -> PlayerStats keys.
const STAT_KEYS := {
	"Max Health": "max_hp_pct", "Damage": "damage_pct", "Melee Damage": "melee_pct",
	"Missile Damage": "missile_pct", "Magic Damage": "magic_pct", "Attack Speed": "attack_speed_pct",
	"Move Speed": "move_speed_pct", "Stamina": "stamina_pct", "Stamina Regen": "stamina_regen_pct",
	"Crit Chance": "crit_chance", "Crit Damage": "crit_damage_pct", "Armor": "armor_pct",
	"Cooldown Reduction": "cdr_pct", "Status Chance": "status_chance_pct", "XP Gain": "xp_gain_pct",
	"Lifesteal": "lifesteal_pct", "Dodge Distance": "dodge_distance_pct", "Pickup Radius": "pickup_radius_pct",
}
const RARITY_WEIGHT := {"Common": 60.0, "Rare": 28.0, "Epic": 10.0, "Legendary": 2.0}


## XP needed to go from `level` to the next one.
static func xp_to_next(level: int) -> int:
	return maxi(1, int(round(20.0 * pow(level, 1.4) * GameData.tuning.xp_scale)))  # 0 would level up forever (xp_scale 0)


## Adds XP (after the XP Gain stat). Returns how many level-ups it caused.
static func add_xp(state: RunState, amount: float, stats: PlayerStats = null) -> int:
	var gain := amount * (stats.mult("xp_gain_pct") if stats != null else 1.0)
	state.xp += int(round(gain))
	var ups := 0
	while state.xp >= xp_to_next(state.level):
		state.xp -= xp_to_next(state.level)
		state.level += 1
		ups += 1
	return ups


## Up to `count` upgrade ids, skipping any already at max_picks.
## True if the game reads the stat this level-up raises (PlayerStats.READ_STATS).
static func is_implemented(option: Dictionary) -> bool:
	return STAT_KEYS.get(GameData.text(option, "stat"), "") in PlayerStats.READ_STATS


static func make_offer(state: RunState, count := 3, rng: RandomNumberGenerator = null) -> Array:
	var pool: Array = []
	for o in GameData.rows("level_up_options"):
		if state.level_picks.count(o.upgrade_id) < int(GameData.num(o, "max_picks", 99)) and is_implemented(o):
			pool.append(o)
	var offer: Array = []
	while offer.size() < count and not pool.is_empty():
		var pick: Dictionary = _weighted(pool, rng)
		pool.erase(pick)
		offer.append(pick.upgrade_id)
	return offer


static func pick(state: RunState, upgrade_id: String, stats: PlayerStats) -> void:
	state.level_picks.append(upgrade_id)
	apply_all(state, stats)


## Rebuilds the "levels" stat source from every pick (also used after loading a save).
static func apply_all(state: RunState, stats: PlayerStats) -> void:
	var values := {}
	for id in state.level_picks:
		var o := GameData.row("level_up_options", id)
		var key: String = STAT_KEYS.get(GameData.text(o, "stat"), "")
		if key != "":
			values[key] = float(values.get(key, 0.0)) + GameData.num(o, "value_per_pick")
	stats.set_source("levels", values)


static func _weighted(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var weight := func(o): return RARITY_WEIGHT.get(o.get("rarity", "Common"), 10.0)
	if rng == null:
		return RunRng.weighted_pick(pool, weight)
	var total := 0.0
	for o in pool:
		total += weight.call(o)
	var roll := rng.randf() * total
	for o in pool:
		roll -= weight.call(o)
		if roll <= 0.0:
			return o
	return pool.back()
