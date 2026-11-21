class_name RaceActive
extends Node
## Your race's active skill (Races sheet: active_name, duration, active_bonus_damage,
## active_cooldown_s), on the V key (user, 2026-11-01). The arena plays the dwarf (Arena.START_RACE):
## it can't be hurt for `duration` s. Any other race gets a plain blast. The other races' skills
## live on in Pantheon Valley.

const BLAST_RADIUS := 8.0

var player: Player
var cooldown := 0.0
var invulnerable := false


func row() -> Dictionary:
	return GameData.race(player.race_id)


func title() -> String:
	return GameData.text(row(), "active_name", "Active")


## Uses the skill. False while it's cooling down.
func cast() -> bool:
	if cooldown > 0.0 or player.is_dead() or player.abilities.invulnerable:
		return false
	var r := row()
	cooldown = GameData.num(r, "active_cooldown_s", 60.0)
	if player.visual != null:
		player.visual.play("Melee_1H_Attack_Chop", 0.5, true)
	if player.race_id == "dwarf":
		invulnerable = true
		get_tree().create_timer(GameData.num(r, "duration", 5.0), false).timeout.connect(func(): invulnerable = false)
	else:
		_blast(BLAST_RADIUS, maxf(GameData.num(r, "active_bonus_damage", 0.0), 40.0), "Physical", 10.0)
	return true


## Hits everyone around you.
func _blast(radius: float, damage: float, element: String, knockback: float) -> void:
	var center := player.global_position
	ElementFx.area(element, center, radius)
	for e in Combat.enemies_in_radius(center, radius):
		var away: Vector3 = e.global_position - center
		away.y = 0.0
		var info: DamageInfo = player.make_hit(damage, element, "Magic", e, DamageInfo.Kind.ABILITY)
		info.knockback_dir = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
		info.knockback = knockback
		Combat.deal(e, info)


func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
