class_name EvilTribe
extends RefCounted
## Count Fuckula's corrupted tribe and its clock. Every interval it pushes into
## a neighboring region. If a living tribe is there, it fights back and the
## player gets a "Border Defense" border defense; if the player wins, the push
## fails. Otherwise the region (and its tribe) is corrupted.
##
## Driven by RunManager.tick(); emits nothing itself, it returns what happened so
## callers (and tests) can react.

## Seconds to answer a border attack: CombatTuning.border_defense_seconds (not
## shortened in short runs: the valley isn't smaller).
## Count Fuckula's tribe is his horde of monsters and skeletons (user, 2026-10-30),
## not one of the races: its units are the Barbarians & Beasts rows of faction
## "Horde" (EncounterSystem.army_rows), the Evil Dragon ends the final battle.
const HORDE := "horde"
const HORDE_BOSS := "horde_evil_dragon"
## He rides the Evil Dragon, then fights on foot when it falls (user, 2026-11-01).
const HORDE_LEADER := "horde_count_fuckula"
## How high he sits on the dragon, in meters.
const LEADER_SEAT := 3.35
const HORDE_ROW := {"race_id": HORDE, "display_name": "Horde", "village_name": "Golgoth"}


## Seconds between pushes (Evil Tribe sheet: advance_interval_min), scaled by run length.
static func interval(state: RunState) -> float:
	var minutes := 12.0
	var row := GameData.row("evil_tribe", "advance_interval_min")
	if not row.is_empty():
		minutes = GameData.num(row, "value", 12.0)
	return minutes * 60.0 * state.length_scale * GameData.tuning.evil_push_scale


## Advances the clock. Returns {"event": "attack"|"fell"|"", "region": ...}.
static func tick(state: RunState, delta: float) -> Dictionary:
	var e: Dictionary = state.evil
	if e.is_empty():
		return {"event": ""}
	var pending: Dictionary = e.get("pending", {})
	if not pending.is_empty():
		pending["time_left"] = float(pending["time_left"]) - delta
		if pending["time_left"] <= 0.0:
			var region: String = pending["region"]
			fall(state, region)
			return {"event": "fell", "region": region}
		return {"event": ""}
	e["next_push_in"] = float(e.get("next_push_in", interval(state))) - delta
	if e["next_push_in"] > 0.0:
		return {"event": ""}
	e["next_push_in"] = interval(state)
	e["pushes"] = int(e.get("pushes", 0)) + 1
	var target := next_target(state)
	if target == "":
		return {"event": ""}
	var tribe: String = state.regions[target].get("tribe", "")
	if tribe != "" and state.tribes.get(tribe, {}).get("status") != "corrupted":
		e["pending"] = {"region": target, "time_left": GameData.tuning.border_defense_seconds}
		# "Border Defense" becomes an encounter the player can take.
		var id := "border_" + target
		state.encounters[id] = {"def": "tm_border_defense", "region": target, "state": "available", "race": tribe, "god": ""}
		if not id in state.regions[target]["encounters"]:
			state.regions[target]["encounters"].append(id)
		return {"event": "attack", "region": target, "tribe": tribe}
	fall(state, target)
	return {"event": "fell", "region": target}


## The player won (or lost) the border defense.
static func resolve_defense(state: RunState, won: bool) -> void:
	var pending: Dictionary = state.evil.get("pending", {})
	if pending.is_empty():
		return
	if not won:
		fall(state, pending["region"])
	state.evil["pending"] = {}


## Picks the bordering region to attack: tribe regions first, never the player's home.
static func next_target(state: RunState) -> String:
	var candidates: Array = []
	var map := ValleyGenerator.neighbors()
	var home: String = state.flags.get("home_region", ValleyGenerator.home_region())
	for owned in state.evil.get("territories", []):
		for n in map.get(owned, []):
			if n == home or n in state.evil.territories or n in candidates or not state.regions.has(n):
				continue
			candidates.append(n)
	if candidates.is_empty():
		return ""
	candidates.sort_custom(func(a, b): return (state.regions[a].tribe != "") and (state.regions[b].tribe == ""))
	return candidates[0]


static func fall(state: RunState, region: String) -> void:
	state.regions[region]["corrupted"] = true
	var border := "border_" + region
	if state.encounters.has(border) and state.encounters[border].state == "available":
		state.encounters[border]["state"] = "expired"
	if not region in state.evil.territories:
		state.evil.territories.append(region)
	var tribe: String = state.regions[region].get("tribe", "")
	if tribe != "" and state.tribes.has(tribe):
		state.tribes[tribe]["status"] = "corrupted"
		for id in ["tm_" + tribe]:  # e.g. a camp they asked you to clear: no gift from a fallen tribe
			if state.encounters.get(id, {}).get("state", "") == "available":
				state.encounters[id]["state"] = "expired"
	state.evil["pending"] = {}
