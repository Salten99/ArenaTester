class_name PlayerStats
extends RefCounted
## The player's stat modifiers. Each source (race, god, godly gifts, timed buffs)
## contributes percent bonuses that are summed per stat.
##
## Stat keys: max_hp_pct, damage_pct, melee_pct, missile_pct, magic_pct,
## attack_speed_pct, move_speed_pct, stamina_pct, crit_chance, crit_damage_pct,
## armor_pct, cdr_pct, ultimate_cdr_pct, chain_bonus, ultimate_duration_pct.

signal stats_changed

## The stats some code actually reads. A godly gift or level-up that raises any
## other stat would do nothing, so it isn't offered (GodlyGiftManager.is_implemented,
## LevelSystem.make_offer). Add a stat here when code starts reading it.
const READ_STATS := ["max_hp_pct", "damage_pct", "melee_pct", "missile_pct", "magic_pct", "attack_speed_pct",
	"move_speed_pct", "stamina_pct", "stamina_regen_pct", "crit_chance", "crit_damage_pct", "armor_pct",
	"cdr_pct", "ultimate_cdr_pct", "chain_bonus", "lifesteal_pct", "dodge_distance_pct", "xp_gain_pct"]

var _sources := {}        # source name -> {stat: value}
var _timed: Array = []    # [{id, stat, value, stacks, max_stacks, expires_msec}]


func set_source(source_name: String, values: Dictionary) -> void:
	_sources[source_name] = values
	stats_changed.emit()


func get_stat(stat: String) -> float:
	var total := 0.0
	for values in _sources.values():
		total += float(values.get(stat, 0.0))
	var now: int = Combat.now_msec()
	for b in _timed:
		if b.expires_msec > now and b.stat == stat:
			total += b.value * b.stacks
	return total


## A temporary buff, e.g. "+10% damage for 4 s, stacks 3 times". Re-applying
## refreshes the timer and adds a stack.
func add_timed(id: String, stat: String, value: float, duration: float, max_stacks := 1) -> void:
	var now: int = Combat.now_msec()
	for b in _timed:
		if b.id == id:
			b.stacks = mini(b.max_stacks, b.stacks + 1) if b.expires_msec > now else 1
			b.expires_msec = now + int(duration * 1000.0)
			stats_changed.emit()
			return
	_timed.append({"id": id, "stat": stat, "value": value, "stacks": 1, "max_stacks": max_stacks,
		"expires_msec": now + int(duration * 1000.0)})
	stats_changed.emit()


## Multiplier from a percent stat, e.g. 15 -> 1.15.
func mult(stat: String) -> float:
	return 1.0 + get_stat(stat) / 100.0
