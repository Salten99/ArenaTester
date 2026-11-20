class_name DataCheck
extends RefCounted
## Cross-checks the exported spreadsheet so typos show up as clear warnings
## (in Godot's Output panel and the tests) instead of silent bugs.
## Returns a list of problems; empty means the data is consistent.

static func run() -> Array:
	var problems: Array = []
	var gods := _ids("gods")
	var races := _ids("races")
	var statuses := _ids("status_effects")
	for w in GameData.rows("weapons"):
		if not GameData.text(w, "weapon_class") in ["Fists", "Heavy", "Blade", "Twin", "Polearm"]:
			problems.append("Weapons %s: unknown weapon_class '%s'" % [w.weapon_id, GameData.text(w, "weapon_class")])
	for g in GameData.rows("gods"):
		_ref(problems, "Gods", g.god_id, "default_race", g.get("default_race"), races, true)
	for r in GameData.rows("races"):
		for gid in GameData.text(r, "starting_gods").split(",", false):
			_ref(problems, "Races", r.race_id, "starting_gods", gid.strip_edges(), gods)
	for b in GameData.rows("godly_gifts"):
		_ref(problems, "Godly Gifts", b.godly_gift_id, "god_id", b.get("god_id"), gods)
		_ref(problems, "Godly Gifts", b.godly_gift_id, "status_effect", b.get("status_effect"), statuses, true)
	for d in GameData.rows("duo_godly_gifts"):
		_ref(problems, "Duo Godly Gifts", d.duo_id, "god_a", d.get("god_a"), gods)
		_ref(problems, "Duo Godly Gifts", d.duo_id, "god_b", d.get("god_b"), gods)
	for a in GameData.rows("god_abilities"):
		_ref(problems, "God Abilities", a.ability_id, "god_id", a.get("god_id"), gods)
		_ref(problems, "God Abilities", a.ability_id, "status_effect", a.get("status_effect"), statuses, true)
	for u in GameData.rows("army_units"):
		_ref(problems, "Army Units", u.unit_id, "race_id", u.get("race_id"), races)
	for o in GameData.rows("level_up_options"):
		if not LevelSystem.STAT_KEYS.has(GameData.text(o, "stat")):
			problems.append("Level Up Options %s: unknown stat '%s'" % [o.upgrade_id, GameData.text(o, "stat")])
	return problems


static func _ids(table: String) -> Array:
	return GameData.by_id.get(table, {}).keys()


static func _ref(problems: Array, sheet: String, id: String, column: String, value, valid: Array, optional := false) -> void:
	if value == null or str(value) == "":
		if not optional:
			problems.append("%s %s: %s is empty" % [sheet, id, column])
		return
	if not str(value) in valid:
		problems.append("%s %s: %s '%s' doesn't exist" % [sheet, id, column, value])
