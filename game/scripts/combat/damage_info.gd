class_name DamageInfo
extends RefCounted
## One hit of damage, passed through Combat.deal(). Built by whoever attacks.

## What made the hit, so godly gifts don't re-trigger on their own damage.
enum Kind { LIGHT, HEAVY, ABILITY, GODLY_GIFT, STATUS, CHAIN, ENEMY }

var amount := 0.0
var damage_type := "Physical"   ## "Physical" or an element (Fire, Lightning...)
var category := "Melee"         ## Melee, Missile or Magic (race modifiers)
var kind: Kind = Kind.LIGHT
var source: Node = null         ## Attacker (player or enemy)
var is_crit := false
var knockback := 0.0
var knockback_dir := Vector3.ZERO
var knockdown := false
var hitstop := 0.0
var shake := 0.0
## Lightning damage chains to nearby enemies unless this is false.
var can_chain := true
## An explosion's hit (a blast, a bolt bursting): it launches what it ragdolls harder (explosion_launch_scale).
var explosive := false
## A heavy or magic hit that shouldn't launch (skills that hold enemies in place or hit in ticks).
var no_launch := false
## Brought by a projectile (an arrow, a bolt): a Guardian's shield blocks it without touching the shooter.
var shot := false
## Multiplies the launch (a body knocked into others passes on less each time: ram_chain_falloff).
var launch_scale := 1.0
## A thrown weapon's id: the weapon that pins its target to a wall (Enemy._show_pin_bolt).
var pin_weapon := ""
## Statuses to apply on hit: [{id, stacks, duration_bonus}]
var statuses: Array = []


static func make(p_amount: float, p_type: String, p_kind: Kind, p_source: Node) -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = p_amount
	d.damage_type = p_type
	d.kind = p_kind
	d.source = p_source
	return d


func with_status(id: String, stacks := 1, duration_bonus := 0.0) -> DamageInfo:
	statuses.append({"id": id, "stacks": stacks, "duration_bonus": duration_bonus})
	return self


## Hits from weapons and abilities count for "on hit" godly gifts; godly gift, status and chain damage don't.
func is_direct() -> bool:
	return kind in [Kind.LIGHT, Kind.HEAVY, Kind.ABILITY]
