class_name ValleyLayout
extends RefCounted
## Where each region sits in this run's valley. You always start at the south end
## and Count Fuckula always holds the north end (user, 2026-10-29), and your camp
## is in your race's home biome: so at run start your race's home region swaps
## places with the southern region (the Valley Regions row marked player_home).
## The swapped region takes the other's spot, borders and all; nothing else moves.
##
## The swap lives in RunState.flags.swap ({region: region it trades with}), so
## saves keep it. `use(state)` makes it the current layout; Run calls it on
## start and resume. Old saves have no swap: the sheet's layout.

static var swap: Dictionary = {}


static func use(state: RunState) -> void:
	swap = state.flags.get("swap", {}) if state != null else {}


## The sheet region whose spot `region` occupies this run.
static func slot(region: String) -> String:
	return swap.get(region, region)


## The southern end: the Valley Regions row with player_home = Yes.
static func south() -> String:
	for r in GameData.rows("valley_regions"):
		if GameData.text(r, "player_home") == "Yes":
			return r.region_id
	var all := GameData.rows("valley_regions")
	return all[0].region_id if not all.is_empty() else ""


## The northern end: the spot farthest from the south end (on the sheet's map).
static func north() -> String:
	var s := GameData.row("valley_regions", south())
	var sp := Vector2(GameData.num(s, "map_x"), GameData.num(s, "map_z"))
	var best := ""
	var best_d := -1.0
	for r in GameData.rows("valley_regions"):
		var d := sp.distance_to(Vector2(GameData.num(r, "map_x"), GameData.num(r, "map_z")))
		if d > best_d:
			best_d = d
			best = r.region_id
	return best


## The swap that puts `home` at the south end ({} if it is already there).
static func swap_for(home: String) -> Dictionary:
	var s := south()
	return {} if home == s or home == "" else {home: s, s: home}


## The region standing at a sheet spot this run (the swap is its own inverse).
static func region_at_slot(spot: String) -> String:
	return swap.get(spot, spot)
