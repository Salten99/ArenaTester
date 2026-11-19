extends Node
## The one source of gameplay randomness. Seeded per run so a run can be
## replayed exactly (network-ready rule 2). Never call randf()/randi() directly
## in gameplay code; use these instead. Visual-only randomness may use the globals.

var rng := RandomNumberGenerator.new()
var seed_value := 0


func _ready() -> void:
	start_run()


## Starts a new run. Pass a seed to replay a specific run.
func start_run(new_seed: int = -1) -> void:
	seed_value = new_seed if new_seed >= 0 else int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	rng.seed = seed_value


## True with the given chance in percent (0-100).
func chance(percent: float) -> bool:
	return rng.randf() * 100.0 < percent


func randf_range(from: float, to: float) -> float:
	return rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return rng.randi_range(from, to)


func pick(items: Array):
	return null if items.is_empty() else items[rng.randi_range(0, items.size() - 1)]


## Picks one item; `weight_of` returns each item's weight.
func weighted_pick(items: Array, weight_of: Callable):
	var total := 0.0
	for item in items:
		total += weight_of.call(item)
	if total <= 0.0:
		return pick(items)
	var roll := rng.randf() * total
	for item in items:
		roll -= weight_of.call(item)
		if roll <= 0.0:
			return item
	return items.back()
