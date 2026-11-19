class_name RunState
extends RefCounted
## Everything about the current run that must survive a save: who you are, what
## you've picked up, and the state of the valley. Plain data only, so it
## serializes to JSON (and later over the network) with to_dict()/from_dict().

const VERSION := 7

var seed := 0
## 1.0 = full 60-90 minute run; smaller values shrink the clock and content for testing.
var length_scale := 1.0
var race_id := ""
var weapon_id := ""           ## your main (melee) weapon; picked at the start, swapped for ones you find
var sidearm_id := "bow"       ## your sidearm (bow or spells), on its own key
var god_id := ""              ## your race's god (the core of the build)
var gods_met: Array = []      ## gods revealed this run (for the codex and unlocks)
var godly_gifts: Array = []         ## [{id, rank}]. The only record of the build; GodlyGiftManager mirrors it.
var hp := -1.0                ## player health when saved (-1 = full)
var rng_state := 0            ## RunRng position, so a resumed run doesn't replay the same rolls
var events: Array = []        ## append-only events [{t, event, ...}] for recaps, codex and unlocks
var level := 1
var xp := 0
var level_picks: Array = []   ## upgrade ids chosen at level-ups, in order
var supplies := 0
var elapsed := 0.0            ## seconds of play this run
var regions := {}             ## region_id -> {tribe, encounters: [encounter ids], corrupted}
var tribes := {}              ## race_id -> {god, region, reputation, status}
var encounters := {}          ## encounter instance id -> {def, region, state, race, god}
var evil := {}                ## {race, captive_god, territories, next_push_in, pushes, pending}
var wild_gods: Array = []     ## gods met through wild encounters, not tribes
var buildings: Array = []     ## home base buildings built this run
var flags := {}               ## one-off facts (e.g. "home_burned", "events_done")
var checkpoint := ""          ## where an autosave was taken
var player_pos: Array = []    ## [x, y, z] in the valley when saved ([] = start at home)
var pending_god := ""         ## a god's offer still open (offered again on load)
var pending_level_ups := 0    ## upgrades earned and not chosen yet


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "seed": seed, "length_scale": length_scale, "race_id": race_id,
		"weapon_id": weapon_id, "sidearm_id": sidearm_id, "god_id": god_id, "gods_met": gods_met, "godly_gifts": godly_gifts,
		"level": level, "xp": xp, "level_picks": level_picks,
		"supplies": supplies, "elapsed": elapsed, "regions": regions, "tribes": tribes,
		"encounters": encounters, "evil": evil, "wild_gods": wild_gods, "buildings": buildings,
		"flags": flags, "checkpoint": checkpoint, "hp": hp, "rng_state": str(rng_state), "events": events,
		"player_pos": player_pos, "pending_god": pending_god, "pending_level_ups": pending_level_ups,
	}


static func from_dict(raw: Dictionary) -> RunState:
	var d := migrate(raw)
	var s := RunState.new()
	for key in d:
		if key != "version" and key in s:
			s.set(key, d[key])
	# JSON turns ints into floats; restore the counters.
	s.seed = int(s.seed)
	s.level = int(s.level)
	s.xp = int(s.xp)
	s.supplies = int(s.supplies)
	s.pending_level_ups = int(s.pending_level_ups)
	s.rng_state = int(str(d.get("rng_state", "0")))
	for b in s.godly_gifts:
		b["rank"] = int(b.get("rank", 1))
	return s


## Upgrades saves from older versions. Add a step here whenever fields change.
static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var v := int(out.get("version", 1))
	if v < 2:
		out["hp"] = -1.0
		out["rng_state"] = "0"
		out["events"] = []
	if v < 3:
		out["weapon_id"] = "warhammer"  # before 2026-10-22 the weapon came from the god
	if v < 4:
		out["player_pos"] = []  # before the 3D valley
	if v < 5:
		out["godly_gifts"] = out.get("boons", [])  # called boons before 2026-10-23
		out.erase("boons")
	if v < 6:
		out["pending_god"] = ""  # open offers weren't saved before 2026-11-04
		out["pending_level_ups"] = 0
	if v < 7:  # a main weapon and a sidearm (2026-11-06): a bow or spell run keeps it as the sidearm
		var w: String = out.get("weapon_id", "warhammer")
		out["sidearm_id"] = "bow"
		if w in ["bow", "crossbow", "staff", "whip"]:
			out["weapon_id"] = "warhammer"
	out["version"] = VERSION
	return out


func add_log(event: String, extra: Dictionary = {}) -> void:
	var entry := {"t": snappedf(elapsed, 0.1), "event": event}
	entry.merge(extra)
	events.append(entry)


## Tribe helpers -------------------------------------------------------------

func tribe(race: String) -> Dictionary:
	return tribes.get(race, {})


func tribes_with_status(status: String) -> Array:
	return tribes.keys().filter(func(r): return tribes[r].get("status") == status)
