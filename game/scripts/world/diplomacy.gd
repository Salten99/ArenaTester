class_name Diplomacy
extends RefCounted
## Tribe reputation and status (DECISIONS 16, 20, Council II 14).
##
## Statuses: neutral -> friendly -> allied, or corrupted (taken by Count Fuckula).
## Tribes are never conquered (user, 2026-11-16). Tribes are otherwise static.

const FRIENDLY_AT := 30
const ALLIED_AT := 70


static func change_reputation(state: RunState, race: String, delta: int) -> void:
	var t: Dictionary = state.tribes.get(race, {})
	if t.is_empty() or t.status == "corrupted":
		return
	t["reputation"] = clampi(int(t.reputation) + delta, -100, 100)
	t["status"] = "allied" if t.reputation >= ALLIED_AT else ("friendly" if t.reputation >= FRIENDLY_AT else "neutral")


## A tribe mission was completed (you defended their village): they become
## allies and their god appears.
static func complete_mission(state: RunState, race: String) -> String:
	change_reputation(state, race, ALLIED_AT)
	return state.tribes.get(race, {}).get("god", "")


## Tribes that fight beside you in the final battle.
static func allies(state: RunState) -> Array:
	return state.tribes_with_status("allied")

