extends Node
## Loads the game data (data/*.json, edited by hand) and the combat tuning resource.
## Read-only during play.

const DATA_DIR := "res://data/"
const TUNING_PATH := "res://tuning/combat_tuning.tres"

## The id column for each table. Tables not listed are keyed by their first column.
const ID_KEYS := {
	"races": "race_id", "gods": "god_id", "weapons": "weapon_id", "god_abilities": "ability_id", "godly_gifts": "godly_gift_id",
	"duo_godly_gifts": "duo_id", "status_effects": "status_id", "level_up_options": "upgrade_id",
	"tribe_members": "member_id", "army_units": "unit_id", "champions": "champion_id",
	"barbarians_beasts": "unit_id",
}

var tables := {}  # table name -> Array[Dictionary]
var by_id := {}   # table name -> {id: Dictionary}
var lists := {}   # dropdown lists from the Lists sheet
var tuning: CombatTuning


func _ready() -> void:
	load_all()


## Races set aside for now (user, 2026-11-06: "maybe we will add in the future but for now
## it is too much"). Their rows stay on the sheet and their models stay in the project; the game
## just never lists them: not on the start screen, not as tribes, not in the art checklist.
## Their rows still load by id, so an old save with one of them doesn't break.
## Empty this list to bring them back.
const SHELVED_RACES := ["owl", "elephant", "dragon", "fennec"]
## Milestone 1's roster (user, 2026-11-09, Council VIII: "less options for the characters").
## Races you can't start as any more.
const START_HIDDEN_RACES := ["gnome", "gnoll", "centaur", "treekin", "ratfolk", "cat"]
## The races you can start as for now (user, 2026-11-16: the dwarf only, the rest built once it's done).
## The start screen's ring shows the other start races blacked out and locked. Add a race_id to open it.
const PLAYABLE_RACES := ["dwarf"]
## Gods (and with them their damage types) set aside: no one worships them, they offer no gifts,
## their abilities and gifts (and duo gifts with them) are never offered. Rows stay on the sheet
## and still load by id; empty this list to bring them back. Any race may take any kept god.
## Kept for now (user, 2026-11-16): Fire (forge_god), Ice (snow_god), Lightning (storm_god) and
## Stone (animal_god), the others come back once these four are polished.
const SHELVED_GODS := ["nature_god", "war_god", "disease_god", "death_god", "chaos_god", "desert_god",
	"sun_god", "moon_god", "harvest_god", "sea_god", "wind_god"]
## What you hold with no weapon (user, 2026-11-20: you start with only your fists and the chain).
const FISTS := "fists"


func load_all() -> void:
	tables.clear()
	by_id.clear()
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_error("GameData: missing %s." % DATA_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var table := file.get_basename()
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR + file))
		if table == "lists":
			lists = parsed if parsed is Dictionary else {}
			continue
		if not parsed is Array:
			push_error("GameData: %s is not a list of rows." % file)
			continue
		tables[table] = parsed.filter(func(r): return not r.get("race_id") in SHELVED_RACES \
			and not r.get("god_id") in SHELVED_GODS and not r.get("god_a") in SHELVED_GODS and not r.get("god_b") in SHELVED_GODS)
		var key: String = ID_KEYS.get(table, "")
		var index := {}
		for row in parsed:
			var id = row.get(key) if key != "" else row.values()[0]
			if id != null:
				index[id] = row
		by_id[table] = index
	tuning = load(TUNING_PATH) as CombatTuning
	if tuning == null:
		push_warning("GameData: no tuning resource; using defaults.")
		tuning = CombatTuning.new()
	for problem in DataCheck.run():
		push_warning("Spreadsheet: " + problem)


func row(table: String, id: String) -> Dictionary:
	return by_id.get(table, {}).get(id, {})


func rows(table: String) -> Array:
	return tables.get(table, [])


## Rows of a table where `column` equals `value`.
func where(table: String, column: String, value) -> Array:
	return rows(table).filter(func(r): return r.get(column) == value)


## A numeric cell, treating blanks as `default`.
static func num(r: Dictionary, key: String, default := 0.0) -> float:
	var v = r.get(key)
	return float(v) if v is float or v is int else default


static func text(r: Dictionary, key: String, default := "") -> String:
	var v = r.get(key)
	return str(v) if v != null else default


func god(id: String) -> Dictionary:
	return row("gods", id)


func race(id: String) -> Dictionary:
	return row("races", id)


func weapon(id: String) -> Dictionary:
	return row("weapons", id)


## The weapons lying about the arena to pick up and throw: every weapon but your fists.
func pickup_weapons() -> Array:
	return rows("weapons").map(func(r): return r.weapon_id).filter(func(w): return w != FISTS)


func status(id: String) -> Dictionary:
	return row("status_effects", id)


func godly_gifts_for(god_id: String) -> Array:
	return where("godly_gifts", "god_id", god_id)


func abilities_for(god_id: String) -> Dictionary:
	var out := {}
	for a in where("god_abilities", "god_id", god_id):
		out[a.get("slot", "")] = a
	return out


## Any unit row: army units, barbarians and beasts, champions or tribe members (villagers).
func unit(id: String) -> Dictionary:
	for table in ["army_units", "barbarians_beasts", "champions", "tribe_members"]:
		var r := row(table, id)
		if not r.is_empty():
			return r
	return {}
