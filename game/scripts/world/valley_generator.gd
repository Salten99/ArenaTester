class_name ValleyGenerator
extends RefCounted
## Fills a new RunState's valley from its seed: which tribes are present and
## where, which race Count Fuckula corrupts, which god he imprisons, which
## gods are wild, and which encounters sit in each region.
##
## Pure logic (no scenes), deterministic per seed, so it's testable and the same
## seed always gives the same valley (co-op rule 2). The 3D valley reads this
## state; its shape (open valley or region arenas) is decided after Milestone 0.

## The valley map (Valley Regions sheet: neighbors, player_home) with this run's
## layout (ValleyLayout): a swapped region borders what its new spot borders.
## The evil tribe spreads along neighbors; your tribe starts in your race's home
## region (Races home_region), moved to the south end.
static func neighbors() -> Dictionary:
	var sheet := {}
	for r in GameData.rows("valley_regions"):
		sheet[r.region_id] = Array(GameData.text(r, "neighbors").split(",", false)).map(func(n): return n.strip_edges())
	var out := {}
	for region in sheet:
		out[region] = sheet[ValleyLayout.slot(region)].map(func(n): return ValleyLayout.region_at_slot(n))
	return out


static func home_region(race_id := "") -> String:
	var wanted := GameData.text(GameData.race(race_id), "home_region") if race_id != "" else ""
	if wanted != "" and not GameData.row("valley_regions", wanted).is_empty():
		return wanted
	for r in GameData.rows("valley_regions"):
		if GameData.text(r, "player_home") == "Yes":
			return r.region_id
	var all := GameData.rows("valley_regions")
	return all[0].region_id if not all.is_empty() else ""


## Every region but yours has a tribe (user, 2026-10-29), Count Fuckula's included:
## 10 of the 11 regions. Short and full runs alike.
const FULL_TRIBES := 10
const WILD_GODS := 2
## Camps (bandit camps, beast dens, war camps) on top of the tribes' encounters: 3
## until 2026-10-29, then 6 (user: more non-tribe events).
const BARBARIAN_CAMPS := 6
## The ways a tribe joins you (user, 2026-11-16: tribes are never conquered, only won over) (the tm_<race> encounter's def): a raid on their
## village, their champion's challenge at the village, or a barbarian camp they ask you to clear.
const WELCOMES := ["tm_raid_defense", "ct_champion_duel", "tm_clear_camp", "siege"]
## Who attacks a raided or besieged village (user, 2026-11-16): bandits, monsters or Count
## Fuckula's army (enemy_source text, EncounterSystem._party).
const ATTACKERS := ["Barbarians", "Beasts", "Evil tribe"]


static func generate(state: RunState) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = state.seed
	var all_races: Array = GameData.rows("races").map(func(r): return r.race_id).filter(func(r): return r != state.race_id)
	_shuffle(all_races, rng)
	var tribe_count := mini(FULL_TRIBES, all_races.size())

	# Free regions, the player's home (your race's home biome) taken.
	var home := home_region(state.race_id)
	state.flags["swap"] = ValleyLayout.swap_for(home)  # your home biome at the south end
	ValleyLayout.use(state)
	var free: Array = neighbors().keys().filter(func(r): return r != home)
	state.regions = {}
	for region in neighbors():
		state.regions[region] = {"tribe": "", "encounters": [], "corrupted": false}
	state.regions[home]["tribe"] = state.race_id
	state.flags["home_region"] = home

	# Count Fuckula's horde (monsters and skeletons, not a race) always holds the north end.
	var chosen: Array = all_races.slice(0, tribe_count - 1)
	var evil_race := EvilTribe.HORDE
	var far := ValleyLayout.region_at_slot(ValleyLayout.north())
	state.tribes = {}
	free.erase(far)
	state.regions[far]["tribe"] = evil_race
	state.tribes[evil_race] = {"god": "", "region": far, "reputation": 0, "status": "neutral"}

	# Place the other tribes, preferring each race's home region.
	for race in chosen:
		if race == evil_race:
			continue
		if free.is_empty():
			break  # the sheet has fewer regions than tribes: the rest stay home
		var wanted: String = GameData.text(GameData.race(race), "home_region")
		var region: String = wanted if wanted in free else free[rng.randi_range(0, free.size() - 1)]
		free.erase(region)
		state.regions[region]["tribe"] = race
		# A tribe whose patron is yours takes up another god below, like the tribes whose god is set aside.
		var god: String = patron(race) if patron(race) != state.god_id else ""
		state.tribes[race] = {"god": god, "region": region, "reputation": 0, "status": "neutral"}

	# He holds one god captive: one no tribe worships and that isn't yours.
	var placed: Array = state.tribes.keys()
	var free_gods: Array = GameData.rows("gods").map(func(g): return g.god_id).filter(func(g):
		return g != state.god_id and not placed.any(func(r): return state.tribes[r].god == g))
	free_gods.sort()
	var captive: String = free_gods[rng.randi_range(0, free_gods.size() - 1)] if not free_gods.is_empty() else ""
	state.tribes[evil_race]["god"] = captive
	state.tribes[evil_race]["status"] = "corrupted"
	var evil_region: String = state.tribes[evil_race]["region"]
	state.regions[evil_region]["corrupted"] = true
	state.evil = {"race": evil_race, "captive_god": captive, "territories": [evil_region],
		"next_push_in": EvilTribe.interval(state), "pushes": 0, "pending": {}}

	# Wild gods: not the player's god, not a placed tribe's god, not the captive.
	var taken: Array = [state.god_id, state.evil.captive_god]
	for race in placed:
		taken.append(state.tribes[race]["god"])
	var wild: Array = GameData.rows("gods").map(func(g): return g.god_id).filter(func(g): return not g in taken)
	_shuffle(wild, rng)
	state.wild_gods = wild.slice(0, mini(WILD_GODS, wild.size()))
	# Tribes whose own god is set aside (GameData.SHELVED_GODS) take up a kept god: one nobody else
	# has while any is left, then any but yours or the captive (tribes may share).
	var spare_gods: Array = wild.slice(state.wild_gods.size())
	var any_god: Array = GameData.rows("gods").map(func(g): return g.god_id).filter(func(g): return g != state.god_id and g != state.evil.captive_god)
	for race in placed:
		if race != evil_race and state.tribes[race]["god"] == "":
			state.tribes[race]["god"] = spare_gods.pop_back() if not spare_gods.is_empty() else any_god[rng.randi_range(0, any_god.size() - 1)]

	# Encounters.
	state.encounters = {}
	# A short first fight right by your camp (Council V): the whole loop (fight,
	# godly gift) in the first minutes instead of a long walk.
	_add(state, "first_fight", "ba_first_raid", home, "", state.god_id)
	# How each tribe wins you over (user, 2026-11-09 and 2026-11-16): about a quarter each are under a
	# raid, have a champion who challenges you, ask you to clear a camp, or brace for a siege.
	var welcomes := placed.filter(func(r): return r != evil_race)
	welcomes.sort()
	var wrng := RandomNumberGenerator.new()
	wrng.seed = state.seed + 91  # its own dice, so the rest of the valley comes out as before
	_shuffle(welcomes, wrng)
	for race in placed:
		if race == evil_race:
			continue
		var region: String = state.tribes[race]["region"]
		var w: String = WELCOMES[welcomes.find(race) % WELCOMES.size()]
		_add(state, "tm_" + race, "tm_raid_defense" if w == "siege" else w, region, race)  # a siege is a raid you get ready for
		if w in ["tm_raid_defense", "siege"]:
			state.encounters["tm_" + race]["source"] = ATTACKERS[wrng.randi_range(0, ATTACKERS.size() - 1)]
			state.encounters["tm_" + race]["siege"] = w == "siege"
	# Wild gods and camps share the tribes' regions (every region has a tribe now).
	var spare: Array = neighbors().keys().filter(func(r): return r != home and r != evil_region)
	var any: Array = spare.duplicate()  # once spare runs out, regions are shared
	_shuffle(spare, rng)
	for god in state.wild_gods:
		var region: String = spare.pop_back() if not spare.is_empty() else evil_region
		_add(state, "wg_" + god, ["wg_apostle_in_peril", "wg_war_party", "wg_camp_purge", "wg_shrine_trial"][rng.randi_range(0, 3)], region, "", god)
	for i in BARBARIAN_CAMPS:
		var region: String = spare.pop_back() if not spare.is_empty() else any[rng.randi_range(0, any.size() - 1)]
		_add(state, "camp_%d" % i, "tm_clear_camp", region)
	_add(state, "final_battle", "ev_final_battle", evil_region, evil_race)


static func _add(state: RunState, id: String, def_id: String, region: String, race := "", god := "") -> void:
	state.encounters[id] = {"def": def_id, "region": region, "state": "available", "race": race,
		"god": god if god != "" else (state.tribes.get(race, {}).get("god", "") if race != "" else "")}
	state.regions[region]["encounters"].append(id)


## The god a race's tribe worships (and the god it starts with on the start screen): the god
## whose default_race it is, or (for
## races no god names, like the Catfolk) the race's first starting god.
## races no god names, like the Catfolk) its first starting god. Set-aside gods are skipped: ""
## if none of them is kept.
static func patron(race: String) -> String:
	for g in GameData.rows("gods"):
		if g.get("default_race") == race:
			return g.god_id
	for g in GameData.text(GameData.race(race), "starting_gods").split(",", false):
		if not g.strip_edges() in GameData.SHELVED_GODS:
			return g.strip_edges()
	return ""


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
