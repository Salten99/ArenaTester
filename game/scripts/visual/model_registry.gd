class_name ModelRegistry
extends RefCounted
## Which model, weapon and scale each race, weapon, unit and beast uses.
##
## Every model is named in the spreadsheet (Races player_model_file, Weapons
## weapon_model_file, Army Units / Tribe Members / Champions / Mounts /
## Barbarians & Beasts model_file). The game looks for that file in:
##   1. game/models/own/  YOUR models: they always win (docs/ART_SWAP.md).
##   2. game/models/gen/  the generated low-poly set (tools/blender/make_*.py).
##   3. game/models/free/ free animated animals (Quaternius, CC0; tools/blender/make_free_animals.py).
## Generated people hold the weapon listed for them in models/gen/held.json.

const OWN := "res://models/own/"
const GEN := "res://models/gen/"
const FREE := "res://models/free/"
## Rig_Medium animation sets, merged into one library for every character.
## Your own animations (user, 2026-11-05: the art checklist imports them): every .glb in
## models/own/animations/ is read first, so a clip there replaces the free one of the same name.
## It must be made on the same rig (Rig_Medium, the KayKit bone names).
const OWN_ANIMATIONS := "res://models/own/animations/"


static func animation_files() -> Array:
	var out: Array = []
	if DirAccess.dir_exists_absolute(OWN_ANIMATIONS):
		for f in DirAccess.get_files_at(OWN_ANIMATIONS):
			if f.ends_with(".glb"):
				out.append(OWN_ANIMATIONS + f)
	return out + ANIMATION_FILES


const ANIMATION_FILES := [
	"res://models/kaykit/animations/Rig_Medium_General.glb",
	"res://models/kaykit/animations/Rig_Medium_MovementBasic.glb",
	"res://models/kaykit/animations/Rig_Medium_MovementAdvanced.glb",
	"res://models/kaykit/animations/Rig_Medium_CombatMelee.glb",
	"res://models/kaykit/animations/Rig_Medium_CombatRanged.glb",
]

const DEFAULT_RACE := GEN + "race_human.glb"
const DEFAULT_WEAPON := GEN + "weapon_mace.glb"

static var _held: Dictionary = {}
static var _held_loaded := false


## The model for a spreadsheet file name: yours, else the generated one, else "".
static func own(file_name) -> String:
	var f := str(file_name) if file_name != null else ""
	if f == "":
		return ""
	if ResourceLoader.exists(OWN + f):
		return OWN + f
	var people := _own_people(f)
	if people != "":
		return people
	if ResourceLoader.exists(GEN + f):
		return GEN + f
	return FREE + f if ResourceLoader.exists(FREE + f) else ""


static var _people := {}  ## file name -> its path in own/<race>/people/
static var _people_loaded := false


## Your villagers, warriors, barbarians and champion can live in their race's people/ folder.
static func _own_people(f: String) -> String:
	if not _people_loaded:
		_people_loaded = true
		for r in GameData.rows("races"):
			var dir := OWN + str(r.race_id) + "/people/"
			for name in ResourceLoader.list_directory(dir):
				_people[name] = dir + name
	return str(_people.get(f, ""))


## Looks again after a file was added while the game runs (the art checklist's import).
static func rescan() -> void:
	_people_loaded = false
	_people.clear()


## Each race has the same classes, each with its own look (user, 2026-11-17): your files go in
## own/<race>/<class>/ (body.glb, weapon.glb, shield.glb), the sidearms and the throwing weapon in
## own/<race>/ (bow.glb, staff.glb, knife.glb). "" when you haven't made it.
static func class_part(race_id: String, class_id: String, part: String) -> String:
	if race_id == "" or class_id == "":
		return ""
	var path := OWN + "%s/%s/%s.glb" % [race_id, class_id.to_lower(), part]
	return path if ResourceLoader.exists(path) else ""


static func race_part(race_id: String, part: String) -> String:
	var path := OWN + "%s/%s.glb" % [race_id, part]
	return path if race_id != "" and ResourceLoader.exists(path) else ""


## The weapon a generated person holds (models/gen/held.json), or "".
static func held(file_name) -> String:
	if not _held_loaded:
		_held_loaded = true
		var text := FileAccess.get_file_as_string(GEN + "held.json")
		var parsed = JSON.parse_string(text) if text != "" else null
		if parsed is Dictionary:
			_held = parsed
	var w := str(_held.get(str(file_name), ""))
	return own(w) if w != "" else ""


## The player's body: the class's own look for that race, else the race's model.
static func for_race(race_id: String, class_id := "") -> String:
	var mine := class_part(race_id, class_id, "body")
	if mine == "":
		mine = own(GameData.race(race_id).get("player_model_file"))
	return mine if mine != "" else DEFAULT_RACE


## Your class weapon (own/<race>/<class>/weapon.glb) or sidearm (own/<race>/bow.glb) wins; then a
## race's version (<race>/<file>, e.g. gen/dwarf/weapon_naginata.glb, their Dane axe); races without
## one use the shared weapon (your own file first). The macaques have no generated polearm, so they
## carry your naginata (user, 2026-11-09).
static func weapon_model(weapon_id: String, race_id := "") -> String:
	var row := GameData.weapon(weapon_id)
	var cls := GameData.text(row, "class_name")
	var mine := class_part(race_id, cls, "weapon") if cls != "" else race_part(race_id, weapon_id)
	if mine != "":
		return mine
	var file = row.get("weapon_model_file")
	mine = own(race_id + "/" + str(file)) if race_id != "" and file != null else ""
	if mine == "":
		mine = own(file)
	return mine if mine != "" else DEFAULT_WEAPON


## A unit's model and held weapon (any table with model_file), or {} if there is none.
## A barbarian is any race in barbarian clothes (user, 2026-11-08): one of its <file>_<race>.glb, at random.
static func own_unit(unit_id: String) -> Dictionary:
	var file = barbarian_of_any_race(str(GameData.unit(unit_id).get("model_file", "")))
	var mine := own(file)
	return {"model": mine, "weapon": held(file)} if mine != "" else {}


static var _barb_races: Dictionary = {}  ## barbarian model file -> its race versions that exist


## `file`, or for a barbarian one of the race versions made of it (make_characters.py BARB_UNITS).
static func barbarian_of_any_race(file: String) -> String:
	if not file.begins_with("barb_"):
		return file
	if not _barb_races.has(file):
		var found: Array = []
		for r in GameData.rows("races"):
			var version := "%s_%s.glb" % [file.get_basename(), r.race_id]
			if own(version) != "":
				found.append(version)
		_barb_races[file] = found
	var versions: Array = _barb_races[file]
	return versions[randi() % versions.size()] if not versions.is_empty() else file


## Units without a model of their own get a barbarian by role.
const ROLE_FALLBACK := {
	"Melee": "barb_raider.glb",
	"Ranged": "barb_slinger.glb",
	"Magic": "barb_hedge_witch.glb",
	"Cavalry": "barb_raider.glb",
	"Large": "barb_warlord.glb",
}


static func for_unit(unit_id: String) -> Dictionary:
	if not own_unit(unit_id).is_empty():
		return own_unit(unit_id)
	var role := GameData.text(GameData.unit(unit_id), "role", "Melee")
	if role in ["Miniboss", "Boss"]:
		role = "Large"
	var file: String = barbarian_of_any_race(ROLE_FALLBACK.get(role, ROLE_FALLBACK.Melee))
	return {"model": own(file), "weapon": held(file)} if own(file) != "" else {}


## Beasts that aren't named beast_* (so the enemy code knows they're animals).
const BEASTS := {"barb_warhound": true, "horde_slime": true, "horde_evil_dragon": true, "horde_minigun_demon": true}


## A beast's look: its model (animations named Idle / Walk / Gallop / Attack /
## HitReact / Death / Jump), built at real size. {} = none.
static func for_beast(unit_id: String) -> Dictionary:
	var mine := own(GameData.unit(unit_id).get("model_file"))
	return {"model": mine, "scale": 1.0} if mine != "" else {}


## The look of a living tribe's unit, champion or villager.
static func for_tribe(unit_id: String) -> Dictionary:
	if not own_unit(unit_id).is_empty():
		return own_unit(unit_id)
	return for_unit(unit_id)
