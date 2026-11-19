class_name StatusEffects
extends Node
## Active status effects on one character. Durations, stacks, ticks and slows come
## from the Status Effects sheet; a few statuses also have code hooks (see _on_applied).

signal applied(status_id: String, stacks: int)
signal expired(status_id: String)

## Lightning "shock" damage when the status is applied, if the sheet has no tick damage.
const DEFAULT_SHOCK_DAMAGE := 10.0
## How long a full Void mark switches the player's godly gifts off.
const VOID_SUPPRESS_SECONDS := 3.0

var active := {}  # status_id -> {stacks, time_left, tick_left, source}
var auras := {}  ## status id -> its looping effect on the character
var aura_size := 1.0


func apply(status_id: String, stacks := 1, source: Node = null, duration_bonus := 0.0) -> void:
	var data := GameData.status(status_id)
	if data.is_empty():
		push_warning("Unknown status '%s'" % status_id)
		return
	var max_stacks := int(GameData.num(data, "max_stacks", 1))
	var duration := GameData.num(data, "duration_s", 3.0) + duration_bonus
	var entry: Dictionary = active.get(status_id, {"stacks": 0, "tick_left": GameData.num(data, "tick_interval_s", 1.0)})
	entry.stacks = mini(max_stacks, int(entry.stacks) + stacks)
	entry.time_left = maxf(float(entry.get("time_left", 0.0)), duration)
	entry.source = source
	active[status_id] = entry
	if not auras.has(status_id) and get_parent() != null:
		var aura := ElementFx.aura(GameData.text(data, "damage_type", "Physical"), aura_size)
		get_parent().add_child(aura)
		aura.emitting = true
		auras[status_id] = aura
	applied.emit(status_id, entry.stacks)  # before the hook: a full Void mark removes itself there, aura included
	_on_applied(status_id, source)


func has(status_id: String) -> bool:
	return active.has(status_id)


func stacks(status_id: String) -> int:
	return int(active.get(status_id, {}).get("stacks", 0))


## Removes `count` stacks (the status ends when none are left).
func consume(status_id: String, count := 1) -> void:
	if not active.has(status_id):
		return
	active[status_id].stacks = int(active[status_id].stacks) - count
	if active[status_id].stacks <= 0:
		remove(status_id)


func remove(status_id: String) -> void:
	if active.erase(status_id):
		if auras.has(status_id):
			ElementFx.stop_aura(auras[status_id])
			auras.erase(status_id)
		expired.emit(status_id)


func clear() -> void:
	for id in active.keys():
		remove(id)


## Total movement slow from all statuses, 0..1.
func slow_fraction() -> float:
	var total := 0.0
	for id in active:
		total += GameData.num(GameData.status(id), "slow_pct") / 100.0
	return clampf(total, 0.0, 0.9)


func _physics_process(delta: float) -> void:
	for id in active.keys():
		var entry: Dictionary = active[id]
		var data := GameData.status(id)
		var tick_damage := GameData.num(data, "damage_per_tick")
		if tick_damage > 0.0:
			entry.tick_left -= delta
			if entry.tick_left <= 0.0:
				entry.tick_left += GameData.num(data, "tick_interval_s", 1.0)
				_tick(id, tick_damage * entry.stacks, entry.source if is_instance_valid(entry.source) else null, data)
		entry.time_left -= delta
		if entry.time_left <= 0.0:
			remove(id)


func _tick(id: String, amount: float, source: Node, data: Dictionary) -> void:
	var owner_node := get_parent()
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var info := DamageInfo.make(amount, GameData.text(data, "damage_type", "Physical"), DamageInfo.Kind.STATUS, source)
	info.can_chain = false
	Combat.deal(owner_node, info)


## Code hooks for statuses whose rule isn't just damage over time.
func _on_applied(id: String, source: Node) -> void:
	match id:
		"lightning":
			var data := GameData.status(id)
			var amount := GameData.num(data, "damage_per_tick", DEFAULT_SHOCK_DAMAGE)
			var info := DamageInfo.make(amount, "Lightning", DamageInfo.Kind.STATUS, source)
			info.can_chain = false  # the shock itself doesn't jump again, or one hit chains forever
			Combat.deal.call_deferred(get_parent(), info)
		"void":
			# Count Fuckula's mark (Council II 13): a full mark switches the player's godly gifts off.
			var owner_node := get_parent()
			if stacks("void") >= int(GameData.num(GameData.status("void"), "max_stacks", 5)) and owner_node.get("godly_gifts") != null:
				owner_node.godly_gifts.suppress(VOID_SUPPRESS_SECONDS)
				remove("void")
		"stone":
			# A stone blow (user, 2026-11-06): knocked down when it lands; the slow is the sheet's slow_pct.
			var owner_node := get_parent()
			if owner_node.has_method("knock_down"):
				owner_node.knock_down()
		"ice":
			if stacks("ice") >= int(GameData.num(GameData.status("ice"), "max_stacks", 3)):
				var owner_node := get_parent()
				if owner_node.has_method("freeze"):
					owner_node.freeze(1.5)
