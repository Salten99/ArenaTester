class_name GodlyGiftManager
extends Node
## The player's godly gifts: owning them, ranking them up, offering new ones, and
## running their effects when a trigger event fires. Lives under the player.
##
## Trigger events (Lists sheet): passive_always, on_light_hit, on_heavy_hit,
## on_combo_finisher, on_crit, on_kill, on_multi_kill, on_dodge, on_parry,
## on_block, on_signature_cast, on_movement_cast, on_ultimate_cast,
## on_take_damage, on_low_health, on_status_applied (+ on_element_hit, code-only).

signal godly_gifts_changed

## Trigger events the game actually fires. There's no block or parry move yet,
## so godly gifts on those can't happen.
const FIRED_TRIGGERS := ["on_light_hit", "on_heavy_hit", "on_combo_finisher", "on_crit", "on_kill", "on_multi_kill",
	"on_dodge", "on_signature_cast", "on_movement_cast", "on_ultimate_cast", "on_take_damage", "on_low_health",
	"on_status_applied", "on_element_hit"]
const MULTI_KILL_COUNT := 3
const MULTI_KILL_WINDOW_MSEC := 2000

var player: Node
## The run this build belongs to. RunState.godly gifts is the saved record; every
## change here is written back to it (Council III: one owner of the build).
var run_state: RunState
var owned: Array = []   # [{id, def, rank, is_duo, last_msec, per_target}]
var _kill_times: Array = []
var _suppressed_until := 0
var _warned := {}
var _reacting_to_status := false


func _ready() -> void:
	player = get_parent()
	Combat.killed.connect(_on_killed)
	Combat.status_applied.connect(_on_status_applied)
	Combat.element_hit.connect(_on_element_hit)


# ---------------------------------------------------------------- owning

func has_godly_gift(id: String) -> bool:
	return _find(id) != null


func rank_of(id: String) -> int:
	var b = _find(id)
	return b.rank if b != null else 0


## Adds a godly gift, or ranks it up if already owned. Returns false if maxed or unknown.
func add_godly_gift(id: String) -> bool:
	var existing = _find(id)
	if existing != null:
		if existing.rank >= int(GameData.num(existing.def, "max_rank", 1)):
			return false
		existing.rank += 1
	else:
		var def := GameData.row("godly_gifts", id)
		var is_duo := false
		if def.is_empty():
			def = GameData.row("duo_godly_gifts", id)
			is_duo = true
		if def.is_empty():
			push_warning("Unknown godly_gift '%s'" % id)
			return false
		owned.append({"id": id, "def": def, "rank": 1, "is_duo": is_duo, "last_msec": -100000, "per_target": {}})
	_recompute_passives()
	_write_back()
	godly_gifts_changed.emit()
	return true


## Rebuilds the godly gift list from a run's saved record (loading, pledging).
func load_from(state: RunState) -> void:
	run_state = state
	owned = []
	for b in state.godly_gifts:
		var def := GameData.row("godly_gifts", b.id)
		var is_duo := def.is_empty()
		if is_duo:
			def = GameData.row("duo_godly_gifts", b.id)
		if not def.is_empty():
			owned.append({"id": b.id, "def": def, "rank": int(b.get("rank", 1)), "is_duo": is_duo, "last_msec": -100000, "per_target": {}})
	_recompute_passives()
	godly_gifts_changed.emit()


func _write_back() -> void:
	if run_state != null:
		run_state.godly_gifts = owned.map(func(b): return {"id": b.id, "rank": b.rank})


## Switches every godly gift off for `seconds` (the Void mark). Passives come back afterwards.
func suppress(seconds: float) -> void:
	_suppressed_until = Combat.now_msec() + int(seconds * 1000.0)
	player.stats.set_source("godly_gifts", {})
	godly_gifts_changed.emit()


func is_suppressed() -> bool:
	return _suppressed_until > Combat.now_msec()


func _physics_process(_delta: float) -> void:
	if _suppressed_until > 0 and not is_suppressed():
		_suppressed_until = 0
		_recompute_passives()
		godly_gifts_changed.emit()


## Re-applies passive godly gifts after `owned` changed outside add_godly_gift (pledging, loading).
func refresh() -> void:
	_recompute_passives()
	godly_gifts_changed.emit()


## Gods in the current build: the pledged god plus every god you hold a godly gift from.
func gods_in_build() -> Array:
	var gods: Array = [player.god_id]
	for b in owned:
		var g = b.def.get("god_id")
		if g != null and not g in gods:
			gods.append(g)
	return gods


## Up to `count` godly gift ids to offer from `god_id`'s pool, plus a duo godly gift when one is unlocked.
func make_offer(god_id: String, count := 3) -> Array:
	var pool: Array = []
	for def in GameData.godly_gifts_for(god_id):
		var id: String = def.godly_gift_id
		if rank_of(id) < int(GameData.num(def, "max_rank", 1)) and is_implemented(def):
			pool.append(def)
	var offer: Array = []
	while offer.size() < count and not pool.is_empty():
		var pick: Dictionary = RunRng.weighted_pick(pool, func(d): return LevelSystem.RARITY_WEIGHT.get(d.get("rarity", "Common"), 10.0))
		pool.erase(pick)
		offer.append(pick.godly_gift_id)
	var duos := available_duos()
	if not duos.is_empty():
		var duo: String = RunRng.pick(duos)
		if offer.size() >= count:
			offer[offer.size() - 1] = duo
		else:
			offer.append(duo)
	return offer


func available_duos() -> Array:
	var gods := gods_in_build()
	var out: Array = []
	for d in GameData.rows("duo_godly_gifts"):
		if d.get("god_a") in gods and d.get("god_b") in gods and not has_godly_gift(d.duo_id) and is_implemented(d):
			out.append(d.duo_id)
	return out


## True if the game has the code to make this godly gift (or duo) do something:
## its trigger happens, its effect type is handled, and any stat it raises is
## read somewhere. Godly gifts that would do nothing are never offered; the game
## lists them at startup (unbuilt()).
static func is_implemented(def: Dictionary) -> bool:
	var id: String = def.get("godly_gift_id", def.get("duo_id", ""))
	var trigger: String = GodlyGiftRules.get_rule(id, "trigger", def.get("trigger_event", ""))
	var effect: String = def.get("effect_type", "")
	var stat: String = GodlyGiftRules.get_rule(id, "stat", "")
	if stat != "" and not stat in PlayerStats.READ_STATS:
		return false
	if trigger == "passive_always":
		return stat != "" or effect == "Bonus Damage"  # _recompute_passives / damage_bonus_pct
	if not trigger in FIRED_TRIGGERS:
		return false
	match effect:
		"Apply Status":
			return GameData.text(def, "status_effect") != ""
		"Bonus Damage", "Area Blast", "Projectile", "Knockback/Pull", "Heal", "Shield":
			return true
		"Stat Buff":
			return stat != ""
		"Cooldown Reduction", "Chain/Bounce":
			return stat != ""  # permanent stat bonus (_recompute_passives)
		"Other":
			return stat != "" and trigger == "on_ultimate_cast"
	return false


## Every godly gift and duo the game can't run yet: [{id, god, name, why}].
static func unbuilt() -> Array:
	var out: Array = []
	for def in GameData.rows("godly_gifts") + GameData.rows("duo_godly_gifts"):
		if not is_implemented(def):
			out.append({"id": def.get("godly_gift_id", def.get("duo_id", "")), "name": GameData.text(def, "display_name"),
				"effect": GameData.text(def, "effect_type"), "trigger": GameData.text(def, "trigger_event")})
	return out


## Bonus damage percent from passive godly gifts whose condition holds for this target.
func damage_bonus_pct(target: Node) -> float:
	if is_suppressed():
		return 0.0  # the Void mark switches every gift off, conditional passives too
	var total := 0.0
	for b in owned:
		var def: Dictionary = b.def
		if def.get("trigger_event") == "passive_always" and def.get("effect_type") == "Bonus Damage":
			if GodlyGiftRules.get_rule(b.id, "condition", "") != "" and _condition_ok(b, {"target": target}):
				total += _value(b)
	return total


# ---------------------------------------------------------------- triggering

## Called by the player (and the signal handlers below) when something happens.
func trigger(event: String, ctx: Dictionary = {}) -> void:
	if is_suppressed():
		return
	for b in owned.duplicate():
		if _trigger_of(b) != event:
			continue
		var is_area: bool = b.def.get("effect_type", "") in AREA_EFFECTS
		var phase: String = ctx.get("phase", "")
		if (phase == "target" and is_area) or (phase == "swing" and not is_area):
			continue
		var chance: float = GameData.num(b.def, "chance_pct", 100.0) + float(GodlyGiftRules.get_rule(b.id, "chance_per_rank", 0.0)) * (b.rank - 1)
		if chance < 100.0 and not RunRng.chance(chance):
			continue
		var now: int = Combat.now_msec()
		var icd := GameData.num(b.def, "internal_cooldown_s") * 1000.0
		if icd > 0.0 and now - int(b.last_msec) < icd:
			continue
		if not _condition_ok(b, ctx):
			continue
		var per_target := float(GodlyGiftRules.get_rule(b.id, "per_target_cooldown", 0.0))
		var target = ctx.get("target")
		if per_target > 0.0 and target != null:
			var key: int = target.get_instance_id()
			if now - int(b.per_target.get(key, -100000)) < per_target * 1000.0:
				continue
			b.per_target[key] = now
		b.last_msec = now
		_run(b, ctx)


func _on_killed(target: Node, info: DamageInfo) -> void:
	if info.source != player:
		return
	trigger("on_kill", {"target": target, "position": target.global_position, "info": info})
	var now: int = Combat.now_msec()
	_kill_times.append(now)
	_kill_times = _kill_times.filter(func(t): return now - t <= MULTI_KILL_WINDOW_MSEC)
	if _kill_times.size() >= MULTI_KILL_COUNT:
		_kill_times.clear()
		trigger("on_multi_kill", {"position": target.global_position})


func _on_status_applied(target: Node, status_id: String, source: Node) -> void:
	# A gift that applies a status must not set off status gifts again, or it never ends.
	if source == player and target != player and not _reacting_to_status:
		_reacting_to_status = true
		trigger("on_status_applied", {"target": target, "status": status_id, "position": target.global_position})
		_reacting_to_status = false


func _on_element_hit(target: Node, element: String, source: Node) -> void:
	if source == player and is_instance_valid(target):
		trigger("on_element_hit", {"target": target, "element": element, "position": target.global_position})


# ---------------------------------------------------------------- effects

## Effects that hit an area run once per swing; the rest run once per enemy hit.
## The player fires each hit event twice: phase "target" for every enemy hit,
## then phase "swing" once, so area effects see statuses applied by the first pass.
const AREA_EFFECTS := ["Area Blast", "Projectile", "Knockback/Pull", "Stat Buff", "Heal", "Shield"]


func _run(b: Dictionary, ctx: Dictionary) -> void:
	var def: Dictionary = b.def
	var effect: String = def.get("effect_type", "")
	var element := GameData.text(def, "damage_type", "Physical")
	var status := GameData.text(def, "status_effect")
	var target = ctx.get("target")
	if GodlyGiftRules.get_rule(b.id, "target", "") == "attacker":
		target = ctx.get("attacker")
	var center: Vector3 = ctx.get("position", target.global_position if _valid(target) else player.global_position)
	var radius := float(GodlyGiftRules.get_rule(b.id, "radius"))
	match effect:
		"Apply Status":
			if _valid(target) and status != "":
				var stacks := maxi(1, int(_value(b)))
				var bonus: float = float(GodlyGiftRules.get_rule(b.id, "duration_bonus_per_rank", 0.0)) * (b.rank - 1)
				Combat.apply_status(target, status, stacks, player, bonus)
		"Bonus Damage":
			if _valid(target) and _value(b) > 0.0:
				Combat.deal(target, _godly_gift_hit(_value(b), element, status))
		"Area Blast":
			if GodlyGiftRules.get_rule(b.id, "hazard", false):
				Hazard.spawn(center, radius, float(GodlyGiftRules.get_rule(b.id, "duration")), float(GodlyGiftRules.get_rule(b.id, "tick")), _godly_gift_hit(_value(b), element, status), _color(element))
			else:
				ElementFx.area(element, center, radius)
				var tpl := _godly_gift_hit(_value(b), element, status)
				tpl.knockback = GameData.tuning.knockback_explosion
				tpl.explosive = true
				tpl.shake = GameData.tuning.shake_explosion
				Combat.area(center, radius, tpl)
		"Projectile":
			var hits := Combat.nearest_enemies(player.global_position, 14.0, 1)
			for e in hits:
				ElementFx.beam(element, player.global_position + Vector3.UP, e.global_position + Vector3.UP)
				ElementFx.area(element, e.global_position, radius)
				Combat.area(e.global_position, radius, _godly_gift_hit(_value(b), element, status))
		"Stat Buff":
			var stat: String = GodlyGiftRules.get_rule(b.id, "stat", "")
			if stat != "":
				player.stats.add_timed(b.id, stat, _value(b), float(GodlyGiftRules.get_rule(b.id, "duration")), int(GodlyGiftRules.get_rule(b.id, "max_stacks")))
		"Heal":
			player.health.heal(player.health.max_hp * _value(b) / 100.0)
		"Shield":
			player.health.shield += player.health.max_hp * _value(b) / 100.0
		"Knockback/Pull":
			var tpl := _godly_gift_hit(0.0, element, status)
			tpl.knockback = GameData.tuning.knockback_light * _value(b)
			Combat.area(center, radius, tpl)
		_:
			if not _warned.has(b.id):
				_warned[b.id] = true
				push_warning("GodlyGift '%s': effect '%s' isn't implemented yet." % [b.id, effect])


## Passive godly gifts become stat sources so they apply all the time.
func _recompute_passives() -> void:
	if is_suppressed():
		return
	var values := {}
	for b in owned:
		var def: Dictionary = b.def
		var stat: String = GodlyGiftRules.get_rule(b.id, "stat", "")
		var passive: bool = def.get("trigger_event") == "passive_always"
		var effect: String = def.get("effect_type", "")
		# Godly gifts with a stat rule and no timed duration in their trigger act as permanent bonuses.
		if stat != "" and (passive or effect == "Cooldown Reduction" or effect == "Chain/Bounce" or (effect == "Other" and def.get("trigger_event") == "on_ultimate_cast")):
			values[stat] = float(values.get(stat, 0.0)) + _value(b)
		elif passive and effect == "Bonus Damage" and GodlyGiftRules.get_rule(b.id, "condition", "") == "":
			values["damage_pct"] = float(values.get("damage_pct", 0.0)) + _value(b)
	player.stats.set_source("godly_gifts", values)


func ultimate_status() -> String:
	for b in owned:
		var s: String = GodlyGiftRules.get_rule(b.id, "ultimate_applies", "")
		if s != "":
			return s
	return ""


func _trigger_of(b: Dictionary) -> String:
	return GodlyGiftRules.get_rule(b.id, "trigger", GameData.text(b.def, "trigger_event"))


func _condition_ok(b: Dictionary, ctx: Dictionary) -> bool:
	var target = ctx.get("target")
	match GodlyGiftRules.get_rule(b.id, "condition", ""):
		"":
			return true
		# Status checks also accept a target that just died (on-kill godly gifts).
		"target_burning":
			return _exists(target) and target.statuses.has("fire")
		"target_large":
			return _exists(target) and target.get("is_large") == true
		"lightning_on_burning":
			return ctx.get("element") == "Lightning" and _exists(target) and target.statuses.has("fire")
	return false


func _value(b: Dictionary) -> float:
	return GameData.num(b.def, "value") + GameData.num(b.def, "value_per_rank") * (b.rank - 1)


func _godly_gift_hit(amount: float, element: String, status: String) -> DamageInfo:
	var info := DamageInfo.make(amount * player.stats.mult("damage_pct"), element, DamageInfo.Kind.GODLY_GIFT, player)
	info.category = "Magic"
	if status != "":
		info.with_status(status)
	return info


func _find(id: String):
	for b in owned:
		if b.id == id:
			return b
	return null


func _exists(n) -> bool:
	return n != null and is_instance_valid(n) and n.get("statuses") != null


func _valid(n) -> bool:
	return n != null and is_instance_valid(n) and n.has_method("is_dead") and not n.is_dead()


func _color(element: String) -> Color:
	return Combat._element_color(element)
