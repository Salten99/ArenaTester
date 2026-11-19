class_name EncounterSystem
extends RefCounted
## Turns an encounter in the RunState into a fight plan (which units, how many,
## how many waves) and applies its result (reputation, god reveal, supplies).
## The arena or valley scene runs the actual fight with the plan.

## enemy_source text (Encounters sheet) -> where its units come from.
const BARBARIANS := ["barb_raider", "barb_slinger", "barb_berserker", "barb_hedge_witch", "barb_warhound"]
const BEASTS := ["beast_dire_wolf", "beast_giant_spider", "beast_wild_boar"]


## How likely each army role is in a wave (Large and Cavalry only after the first wave).
const ROLE_WEIGHT := {"Melee": 5, "Ranged": 3, "Magic": 2, "Cavalry": 1, "Large": 1, "Miniboss": 1, "Boss": 0}


## A fight: 3 waves, each wave_growth (1.5x) bigger than the one before, then
## a mini boss (user, 2026-10-29). Champion fights and the final battle end
## with their champion instead. Deterministic per run seed + encounter id.
## Waves hold unit tokens: "unit_id", or "unit_id@race" for a bandit wearing
## another race's look (WaveDirector.spawn reads them).
## Sizing: the enemies' total health aims at (your damage per second + your
## warriors') x target_minutes, but the first wave stays between
## first_wave_min and first_wave_max enemies, so long fights come out shorter.
## Enemies keep their sheet health: a stronger side means more of them, not
## tougher ones (pivot, user 2026-11-18).
static func plan(state: RunState, encounter_id: String, friendlies := 0) -> Dictionary:
	var e: Dictionary = state.encounters.get(encounter_id, {})
	var def := GameData.row("encounters", e.get("def", ""))
	if def.is_empty():
		return {}
	var t: CombatTuning = GameData.tuning
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(state.seed) + encounter_id)
	var minutes := GameData.num(def, "target_minutes", 3.5)
	var budget := hp_budget(state, minutes * 60.0, friendlies)
	var source := str(e.get("source", GameData.text(def, "enemy_source")))  # a raid or siege picks its attackers (ValleyGenerator.ATTACKERS)
	var party := _party(state, source, e.get("race", ""), rng, str(e.get("region", "")))
	var pool: Array = party.pool
	var boss := ""
	if source.begins_with("Champion") or encounter_id == "final_battle":
		boss = "champ_" + str(e.get("race", ""))
		if GameData.unit(boss).is_empty():
			boss = ""
	if str(e.get("race", "")) == EvilTribe.HORDE and encounter_id == "final_battle":
		boss = EvilTribe.HORDE_BOSS  # the Evil Dragon
	if boss == "":
		boss = party.boss
	var champion := boss.begins_with("champ_") or boss == EvilTribe.HORDE_BOSS
	var boss_hp := GameData.num(GameData.unit(boss), "hp") * (1.0 if champion else mini_boss_mult(boss))
	var second_boss := EvilTribe.HORDE_LEADER if boss == EvilTribe.HORDE_BOSS else ""
	if second_boss != "":
		boss_hp += GameData.num(GameData.unit(second_boss), "hp")
	var left := maxf(budget - boss_hp, budget * 0.4)
	var parts := 0.0
	for w in t.wave_count:
		parts += pow(t.wave_growth, w)
	var first := clampi(roundi(left / (_average_hp(pool) * parts)), t.first_wave_min, t.first_wave_max)
	var out: Array = []
	for w in t.wave_count:
		var wave: Array = []
		for i in mini(roundi(first * pow(t.wave_growth, w)), t.max_wave_size):
			wave.append(_pick(pool, rng, w > 0))
		out.append(wave)
	# Reinforcements (user, 2026-11-10): the waves stop growing at max_wave_size, so a long fight
	# (the final battle, a champion's band) gets the rest of its health as more enemies that join later.
	var reserve: Array = []
	var planned := 0.0
	for wave in out:
		for id in wave:
			planned += GameData.num(GameData.unit(str(id).get_slice("@", 0)), "hp", 40.0)
	var avg := maxf(_average_hp(pool), 1.0)
	while planned < left and reserve.size() < MAX_RESERVE:
		reserve.append(_pick(pool, rng, true))
		planned += avg
	return {"waves": out, "reserve": reserve, "boss": boss, "second_boss": second_boss, "leader": boss if champion else "", "budget": budget, "minutes": minutes,
		"type": GameData.text(def, "type"), "party": party.kind}


## Who fights in a fight not tied to one tribe: Count Fuckula's army, a champion's, the region's
## beasts, or barbarians (each of them a random race, ModelRegistry.barbarian_of_any_race).
## {kind, pool: unit ids, boss}.
static func _party(state: RunState, source: String, race: String, rng: RandomNumberGenerator, region := "") -> Dictionary:
	if source.begins_with("Evil tribe") or source.begins_with("Champion"):
		var r: String = state.evil.get("race", race) if source.begins_with("Evil") else race
		var army := _army(r)
		if not army.is_empty():
			return {"kind": "race:" + r, "pool": army, "boss": _army_boss(r)}
	# Beasts fight with the region's own animals, led by its monster (user, 2026-11-03).
	var biome := GameData.text(GameData.row("valley_regions", region), "biome")
	var local_beasts: Array = BEASTS + Wilds.native_hunters(biome)
	if source.begins_with("Beasts"):
		return {"kind": "beasts", "pool": local_beasts, "boss": Wilds.MONSTERS.get(biome, BEAST_BOSS)}
	var beasts: Array = local_beasts if "Beasts" in source else []
	# Raids are barbarians, just barbarians (user, 2026-11-08): no other tribe's army, no borrowed looks.
	return {"kind": "bandits", "pool": BARBARIANS + beasts, "boss": BANDIT_BOSS}


const BANDIT_BOSS := "barb_warlord"
## No fight sends more reinforcements than this (a safety cap; the final battle needs about 150).
const MAX_RESERVE := 300
const BEAST_BOSS := "beast_cave_bear"


static func _army(race: String) -> Array:
	return army_rows(race).map(func(u): return u.unit_id)


## A race's army (Army Units), or Count Fuckula's horde (its boss, the dragon, aside).
static func army_rows(race: String) -> Array:
	if race == EvilTribe.HORDE:
		return GameData.where("barbarians_beasts", "faction", "Horde").filter(func(u): return not u.unit_id in [EvilTribe.HORDE_BOSS, EvilTribe.HORDE_LEADER])
	return GameData.where("army_units", "race_id", race)


## A race's mini boss: its Large unit (made tougher by mini_boss_mult).
static func _army_boss(race: String) -> String:
	for u in army_rows(race):
		if GameData.text(u, "role") == "Large":
			return u.unit_id
	return BANDIT_BOSS


## How much more health a mini boss gets than its sheet (units already made as
## bosses, like the Barbarian Warlord, keep theirs).
static func mini_boss_mult(token: String) -> float:
	var role := GameData.text(GameData.unit(token), "role")
	return 1.0 if role in ["Miniboss", "Boss"] or token.begins_with("champ_") else GameData.tuning.mini_boss_hp_mult


## Total enemy health a fight of `seconds` should have.
static func hp_budget(state: RunState, seconds: float, friendlies: int) -> float:
	var t: CombatTuning = GameData.tuning
	var you := t.battle_player_dps * (1.0 + t.battle_level_growth * (state.level - 1)) * (1.0 + t.battle_godly_gift_growth * state.godly_gifts.size())
	var helpers := t.battle_ally_dps * pow(friendlies, t.battle_ally_scaling) if friendlies > 0 else 0.0
	return (you + helpers) * seconds


## Average health of a unit drawn from `pool` (weighted like _pick).
static func _average_hp(pool: Array) -> float:
	var total := 0.0
	var weight := 0.0
	for id in pool:
		var w: float = ROLE_WEIGHT.get(GameData.text(GameData.unit(id), "role", "Melee"), 2)
		total += GameData.num(GameData.unit(id), "hp", 25.0) * w
		weight += w
	return maxf(1.0, total / weight) if weight > 0.0 else 25.0


static func _pick(pool: Array, rng: RandomNumberGenerator, allow_big: bool) -> String:
	var total := 0
	var weights: Array = []
	for id in pool:
		var role := GameData.text(GameData.unit(id), "role", "Melee")
		var w: int = ROLE_WEIGHT.get(role, 2)
		if not allow_big and role in ["Large", "Cavalry", "Miniboss"]:
			w = 0
		weights.append(w)
		total += w
	if total <= 0:
		return pool[rng.randi_range(0, pool.size() - 1)]
	var roll := rng.randi_range(1, total)
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0:
			return pool[i]
	return pool[0]


static func start(state: RunState, encounter_id: String) -> void:
	if state.encounters.has(encounter_id):
		state.encounters[encounter_id]["state"] = "active"


## Applies the result. Returns a god id to offer (pledge or godly gift), or "".
static func finish(state: RunState, encounter_id: String, won: bool) -> String:
	var e: Dictionary = state.encounters.get(encounter_id, {})
	if e.is_empty():
		return ""
	e["state"] = "done" if won else "failed"
	if not won:
		return ""
	var def := GameData.row("encounters", e.def)
	state.supplies += 20
	var race: String = e.get("race", "")
	var god := ""
	match "Tribe Mission" if encounter_id.begins_with("tm_") else GameData.text(def, "type"):  # any befriending fight wins them over
		"Tribe Mission":
			god = Diplomacy.complete_mission(state, race)
		"Wild God":
			god = e.get("god", "")
		"Barbarian":
			god = e.get("god", "")  # the first fight (the Count's raid on your camp): a godly gift from your own god
		"Border Defense":
			EvilTribe.resolve_defense(state, true)
			Diplomacy.change_reputation(state, race, 30)
	if god != "" and not god in state.gods_met:
		state.gods_met.append(god)
	return god


static func available(state: RunState) -> Array:
	return state.encounters.keys().filter(func(id): return state.encounters[id].state == "available")
