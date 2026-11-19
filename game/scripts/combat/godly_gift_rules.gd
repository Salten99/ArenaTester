class_name GodlyGiftRules
extends RefCounted
## Extra details for godly gifts that the spreadsheet columns don't cover yet
## (radius, buff duration, conditions). Keyed by godly_gift_id / duo_id.
## Anything not listed uses DEFAULTS. If a rule is used by many godly gifts, it
## should become a spreadsheet column instead.
##
## Keys:
##   trigger      override the sheet's trigger_event
##   condition    target_burning | target_large | lightning_on_burning
##   radius       area size in meters
##   duration     seconds for timed buffs and hazards
##   max_stacks   timed buff stacks
##   stat         PlayerStats key the godly gift changes
##   hazard       true = Area Blast leaves a lingering zone instead of one blast
##   tick         seconds between hazard pulses
##   target       "attacker" = hit whoever hurt the player
##   chance_per_rank   extra trigger chance (percent) per rank
##   duration_bonus_per_rank   extra status duration per rank
##   per_target_cooldown   seconds before the same enemy can trigger it again
##   ultimate_applies  status the ultimate applies while this godly gift is owned

const DEFAULTS := {"radius": 3.0, "duration": 4.0, "max_stacks": 1, "tick": 0.5}

const RULES := {
	"forge_searing_strikes": {"duration_bonus_per_rank": 1.0},
	"forge_tempered": {"condition": "target_large"},
	"forge_slag_trail": {"hazard": true, "radius": 1.6, "duration": 2.0, "tick": 0.5},
	"forge_spark_shower": {"radius": 2.0},
	"forge_kiln_heart": {"condition": "target_burning", "stat": "damage_pct", "duration": 4.0, "max_stacks": 3},
	"forge_masterwork": {"stat": "ultimate_cdr_pct", "ultimate_applies": "fire"},
	"storm_static_strikes": {"chance_per_rank": 10.0},
	"storm_conductor": {"stat": "chain_bonus"},
	"storm_thunderclap": {"radius": 3.0},
	"storm_overcharge": {"stat": "move_speed_pct", "duration": 3.0},
	"storm_lightning_rod": {"target": "attacker"},
	"storm_tempest": {"stat": "ultimate_duration_pct"},
	"duo_forge_storm": {"trigger": "on_element_hit", "condition": "lightning_on_burning", "radius": 3.0, "per_target_cooldown": 0.5},
}


static func get_rule(godly_gift_id: String, key: String, fallback = null):
	var r: Dictionary = RULES.get(godly_gift_id, {})
	if r.has(key):
		return r[key]
	return DEFAULTS.get(key, fallback) if fallback == null else fallback
