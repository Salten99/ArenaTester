class_name HealthComponent
extends Node
## Hit points, shield and invulnerability for any character.

signal changed(current: float, maximum: float)
signal died

var max_hp := 100.0
var hp := 100.0
var shield := 0.0
var invulnerable := false
var dead := false


func setup(maximum: float) -> void:
	max_hp = maximum
	hp = maximum
	dead = false
	changed.emit(hp, max_hp)


## Applies damage and returns how much actually came off health.
func take(amount: float) -> float:
	if dead or invulnerable or amount <= 0.0:
		return 0.0
	var absorbed := minf(shield, amount)
	shield -= absorbed
	var dealt := minf(hp, amount - absorbed)
	hp -= dealt
	changed.emit(hp, max_hp)
	if hp <= 0.0:
		dead = true
		died.emit()
	return dealt


func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)
	changed.emit(hp, max_hp)


func fraction() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0
