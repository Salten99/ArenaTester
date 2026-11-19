class_name WorldEvents
extends Node
## Things happening in the valley that you come upon (user, 2026-10-29), beside
## the encounters (EncounterSite). All are real places with real people:
##   caravan  A cart going from one tribe's village to another, on a trail through a
##            forest (user, 2026-11-08: something you happen upon, not a cart on every
##            road). As you come near, bandits or a wild pack ambush it. Press F:
##            DEFEND it (the tribe likes you more, pays you) or JOIN the attack
##            (you take the cargo, the tribe likes you less). Leave it and the
##            fight ends without you.
##   ritual   A tribe's feast or sacrifice to its god near its village. F:
##            PARTAKE (the tribe likes you more, its god offers a godly gift) or
##            DESTROY it (fight its guards: the tribe likes you less, you take
##            the offerings and your own god offers a gift).
##   bridge   Every bridge has one: a Bridge Troll (sometimes), a bandit camp,
##            a trader's stall (spend supplies) or a quest-giver.
##   hamlet   Every fishing hamlet has a quest-giver.
## A quest: "a pack troubles us": a group of wild enemies appears nearby with a
## sign over it; kill it for supplies and the nearest tribe's thanks.
## Finished events stay finished for the run (RunState.flags.events_done).

const CARAVANS := 3
const CARAVAN_SPEED := 2.2  ## m/s along its trail, back and forth until it's ambushed
const CARAVAN_TRAIL := 70.0  ## m of trail it travels
const AMBUSH_RANGE := 45.0  ## the ambush springs when you come this close
## Where caravans travel: regions whose land is one of these (the wooded ones).
const CARAVAN_BIOMES := ["Ancient forest", "Rocky hills, pine and old mines", "Steaming jungle"]
const RITUALS := 3
## Chance of each bridge event (in order; the rest is a quest-giver).
const BRIDGE_TROLL := 0.2
const BRIDGE_CAMP := 0.25
const BRIDGE_SHOP := 0.25
const TALK_RANGE := 7.0
const AWAKE_RANGE := 150.0
const CAMP_AGGRO := 22.0
## Supplies paid out, and reputation changes.
const PAY := {"defend": 30, "loot": 50, "offerings": 30, "camp": 15, "troll": 30, "quest": 25, "hold": 40}
## Who holds a big landmark (user, 2026-11-05: more large places with enemies): a war band, or a beast pack.
const HOLDERS := [["barb_raider", "barb_raider", "barb_raider", "barb_slinger", "barb_slinger", "barb_berserker", "barb_hedge_witch", "barb_warlord"],
	["beast_dire_wolf", "beast_dire_wolf", "beast_dire_wolf", "beast_dire_wolf", "beast_cave_bear", "beast_cave_bear"]]
const HOLD_XP := 30.0
## A castle is a dungeon: its band, a second ring of defenders, and a boss (the band's own: a
## warlord for the barbarians, a great bear for the beasts).
const CASTLE_WALL_GUARDS := 6
const CASTLE_BOSSES := ["barb_warlord", "beast_cave_bear"]
const REP := {"defend": 20, "join": -35, "partake": 15, "destroy": -35, "quest": 10}
## Trader's stall: [id, text, price in supplies].
## The HUD shows 3 options, so two wares plus Leave (your mount heals on its own on foot).
const SHOP := [["heal", "Healing draught: heal to full", 10], ["gift", "A godly gift from your god", 35]]
const ATTACKERS := [[["barb_raider", 3], ["barb_slinger", 1], ["barb_berserker", 1]], [["beast_dire_wolf", 4]], [["beast_wild_boar", 3]]]

var valley: Node  ## the Valley scene
## [{id, kind, title, pos: Vector3, race, god, npc: Enemy, foes: [Enemy], friends: [Enemy],
##   choice: "", done: bool, sign: Label3D}]
var events: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = Run.state.seed + 31
	if not valley.battle.is_empty():
		return  # a custom battle: no caravans to save or rituals to find
	var done: Array = Run.state.flags.get("events_done", [])
	# Every tribe, fallen ones too, so "ritual_1" is the same tribe's rite in every load of the run
	# (events_done keeps ids); a fallen tribe's events are skipped where they're built.
	var tribes: Array = Run.state.tribes.keys().filter(func(r): return valley.villages.has(r))
	tribes.sort()
	ValleyGenerator._shuffle(tribes, _rng)
	for i in mini(CARAVANS, tribes.size() / 2):
		_add(done, "caravan_%d" % i, func(id): return _caravan(id, tribes[i * 2], tribes[i * 2 + 1]))
	for i in mini(RITUALS, tribes.size()):
		_add(done, "ritual_%d" % i, func(id): return _ritual(id, tribes[tribes.size() - 1 - i]))
	for i in valley.terrain.bridges.size():
		var br: Dictionary = valley.terrain.bridges[i]
		if br.get("lake", false):
			_add(done, "lake_bridge", func(id): return _lake_bridge(id, br))
		else:
			_add(done, "bridge_%d" % i, func(id): return _bridge(id, br))
	var holds := 0
	for l in valley.terrain.landmarks:
		if not l.has("chest"):
			_add(done, "hold_%d" % holds, func(id): return _stronghold(id, l))
			holds += 1
	for i in valley.hamlets.size():
		var h: Village = valley.hamlets[i]
		if h.villagers.is_empty():
			continue  # Count Fuckula's land: empty
		_add(done, "hamlet_%d" % i, func(id): return _quest_giver(id, h.global_position + Vector3(5.0, 0.0, 3.0), h.race, "Fisher's request"))


func _add(done: Array, id: String, build: Callable) -> void:
	_rng.seed = Run.state.seed + 31 + hash(id)  # each event its own dice: one skipped can't change the next
	var ev: Dictionary = build.call(id)
	if ev.is_empty():
		return
	if id in done:
		_free(ev)
		return
	events.append(ev)


# ---------------------------------------------------------------- building the events

func _event(id: String, kind: String, title: String, pos: Vector3, race := "") -> Dictionary:
	var sign := Label3D.new()
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 36
	sign.outline_size = 10
	sign.pixel_size = 0.012
	sign.text = title
	sign.visibility_range_end = 60.0
	valley.add_child(sign)
	sign.global_position = pos + Vector3.UP * 5.0
	return {"id": id, "kind": kind, "title": title, "pos": pos, "race": race, "god": "", "npc": null,
		"foes": [], "friends": [], "others": [], "choice": "", "done": false, "sign": sign, "props": []}


func _caravan(id: String, from: String, to: String) -> Dictionary:
	if _fallen(from) or _fallen(to):
		return {}
	var a: Vector3 = valley.villages[from].global_position
	var b: Vector3 = valley.villages[to].global_position
	var woods: Array = []
	for r in Run.state.regions:
		if not Run.state.regions[r].get("corrupted", false) and GameData.text(GameData.row("valley_regions", r), "biome") in CARAVAN_BIOMES:
			woods.append(r)
	woods.sort()
	var spot := Vector3.INF
	if not woods.is_empty():
		var c := ValleyTerrain.region_center(woods[_rng.randi() % woods.size()])
		spot = _dry_spot(c, 160.0)
	if spot == Vector3.INF:  # no wood: on the way between the two villages
		spot = _dry_spot(Vector2(a.x, a.z).lerp(Vector2(b.x, b.z), _rng.randf_range(0.35, 0.65)), 80.0)
	if spot == Vector3.INF:
		return {}
	var title := "%s caravan to the %s" % [_race_name(from), _race_name(to)]
	var ev := _event(id, "caravan", title, spot, from)
	var way := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	ev.trail = [spot - way * CARAVAN_TRAIL * 0.5, spot + way * CARAVAN_TRAIL * 0.5]
	ev.along = _rng.randf() * CARAVAN_TRAIL * 2.0
	ev.sprung = false
	ev.pack = ATTACKERS[_rng.randi() % ATTACKERS.size()]  # bandits, or a wild pack (user: "bandits or pack of wild animals")
	_prop(ev, "cart", spot, 0.0, false)
	var army: Array = GameData.where("army_units", "race_id", from).filter(func(u): return u.get("role") in ["Melee", "Ranged"])
	for k in 3:
		if not army.is_empty():
			ev.friends.append(_unit(army[k % army.size()].unit_id, spot, 5.0, k, 3, Enemy.Team.FRIENDLY))
	var members: Array = GameData.where("tribe_members", "race_id", from)
	for k in 2:
		if not members.is_empty():
			ev.others.append(_unit(members[k % members.size()].member_id, spot, 2.5, k, 2, Enemy.Team.NEUTRAL))
	ev.npc = ev.others[0] if not ev.others.is_empty() else null
	ev.offsets = {}
	for u in ev.friends + ev.others:
		ev.offsets[u] = u.post - spot  # where each walks beside the cart
	_move_caravan(ev, 0.0)
	return ev


## The caravan rolls on along its trail (back and forth), its people walking with it.
func _move_caravan(ev: Dictionary, delta: float) -> void:
	ev.along = fposmod(float(ev.along) + delta * CARAVAN_SPEED, CARAVAN_TRAIL * 2.0)
	var f: float = ev.along / CARAVAN_TRAIL
	var back := f > 1.0
	var at: Vector3 = (ev.trail[0] as Vector3).lerp(ev.trail[1], 2.0 - f if back else f)
	at.y = valley.terrain.height(at.x, at.z)  # the ground, never a floating island overhead
	ev.pos = at
	var dir: Vector3 = (ev.trail[1] - ev.trail[0]).normalized() * (-1.0 if back else 1.0)
	if not ev.props.is_empty() and is_instance_valid(ev.props[0]):
		ev.props[0].global_position = at
		ev.props[0].rotation.y = atan2(-dir.x, -dir.z)
	if is_instance_valid(ev.sign):
		ev.sign.global_position = at + Vector3.UP * 5.0
	for u in _living(ev.friends + ev.others):
		u.post = at + ev.offsets.get(u, Vector3.ZERO)


## You came near: bandits or a wild pack fall on the caravan, which stops where it is.
func _spring(ev: Dictionary) -> void:
	if ev.get("sprung", true):
		return
	ev.sprung = true
	var n := 0
	for entry in ev.pack:
		for k in entry[1]:
			var e := _unit(entry[0], ev.pos, 11.0, n, 6, Enemy.Team.HOSTILE)
			e.aggro_radius = 60.0
			e.set_dormant(false)
			ev.foes.append(e)
			n += 1
	valley.hud.show_message("The %s is ambushed!" % ev.title, 3.0)


func _process(delta: float) -> void:
	if valley == null or valley.player == null:
		return
	var p: Vector3 = valley.player.global_position
	for ev in events:
		if ev.kind != "caravan" or ev.done or ev.get("sprung", true) or ev.pos.distance_to(p) > AWAKE_RANGE:
			continue
		_move_caravan(ev, delta)
		if ev.pos.distance_to(p) < AMBUSH_RANGE:
			_spring(ev)


## A big landmark someone holds: kill them all for supplies and XP.
func _stronghold(id: String, l: Dictionary) -> Dictionary:
	var spot := Vector3(l.pos.x, l.get("y", valley.terrain.height(l.pos.x, l.pos.y)), l.pos.y)
	var castle: bool = l.model == "landmark_castle"
	var ev := _event(id, "hold", "%s (held)" % l.name, spot)
	var pick := _rng.randi() % HOLDERS.size()
	var band: Array = HOLDERS[pick]
	for k in band.size():
		var e := _unit(band[k], spot, 9.0, k, band.size(), Enemy.Team.HOSTILE)
		e.aggro_radius = CAMP_AGGRO
		ev.foes.append(e)
	if castle:  # a dungeon (user, 2026-11-06): a second ring of defenders on the walls' side, and a boss in the courtyard
		ev.dungeon = true
		for k in CASTLE_WALL_GUARDS:
			var e := _unit(band[k % band.size()], spot, 17.0, k, CASTLE_WALL_GUARDS, Enemy.Team.HOSTILE)
			e.aggro_radius = CAMP_AGGRO
			ev.foes.append(e)
		var boss := Enemy.new()
		boss.setup(CASTLE_BOSSES[pick], valley.player, valley.director, Enemy.Team.HOSTILE)
		boss.make_mini_boss()
		boss.post = spot
		boss.aggro_radius = CAMP_AGGRO
		valley.add_child(boss)
		boss.global_position = spot + Vector3.UP * 0.1
		boss.set_dormant(true)
		ev.foes.append(boss)
	return ev


func _ritual(id: String, race: String) -> Dictionary:
	if _fallen(race):
		return {}
	var v: Village = valley.villages[race]
	var c := Vector2(v.global_position.x, v.global_position.z) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(70.0, 100.0)
	var spot := _dry_spot(c, 40.0)
	if spot == Vector3.INF:
		return {}
	var god: String = Run.state.tribes[race].god
	if god == "":
		return {}  # no god to feast for
	var feast := _rng.randf() < 0.5
	var title := "%s %s to %s" % [_race_name(race), "feast" if feast else "sacrifice", GameData.text(GameData.god(god), "display_name", god)]
	var ev := _event(id, "ritual", title, spot, race)
	ev.god = god
	_prop(ev, "bonfire", spot, 0.0)
	for k in 3:
		var at := spot + Vector3.FORWARD.rotated(Vector3.UP, k * TAU / 3.0) * 5.0
		_prop(ev, ["market_stand", "barrel", "crate"][k] if feast else ["rock_d", "hay", "rock_b"][k], at, _rng.randf() * TAU)
	var members: Array = GameData.where("tribe_members", "race_id", race)
	for k in 5:
		if not members.is_empty():
			ev.others.append(_unit(members[k % members.size()].member_id, spot, 3.5, k, 5, Enemy.Team.NEUTRAL))
	var army: Array = GameData.where("army_units", "race_id", race).filter(func(u): return u.get("role") == "Melee")
	for k in 2:
		if not army.is_empty():
			ev.foes.append(_unit(army[0].unit_id, spot, 8.0, k, 2, Enemy.Team.NEUTRAL))
	ev.npc = ev.others[0] if not ev.others.is_empty() else null
	return ev


## The giant lake's bridge to the island castle (user, 2026-11-08): a war band holds it, in pairs
## all the way along, to fight through on the way to the castle.
const LAKE_BRIDGE_GUARDS := 12


func _lake_bridge(id: String, bridge: Dictionary) -> Dictionary:
	var t: ValleyTerrain = valley.terrain
	var a := Vector3(bridge.a.x, t.height(bridge.a.x, bridge.a.y) + 0.12, bridge.a.y)  # the deck, as ValleyWorld builds it
	var b := Vector3(bridge.b.x, t.height(bridge.b.x, bridge.b.y) + 0.12, bridge.b.y)
	var ev := _event(id, "hold", "The castle bridge (held)", a.lerp(b, 0.2))
	var band: Array = HOLDERS[0]
	var side := Vector3(b.z - a.z, 0.0, a.x - b.x).normalized() * 1.2
	for k in LAKE_BRIDGE_GUARDS:
		var at := a.lerp(b, 0.12 + 0.8 * float(k / 2) / float(LAKE_BRIDGE_GUARDS / 2 - 1)) + side * (1.0 if k % 2 else -1.0)
		var e := Enemy.new()
		e.setup(band[k % band.size()], valley.player, valley.director, Enemy.Team.HOSTILE)
		e.post = at + Vector3.UP * 0.2
		e.aggro_radius = CAMP_AGGRO
		valley.add_child(e)
		e.global_position = e.post
		e.set_dormant(true)
		ev.foes.append(e)
	return ev


func _bridge(id: String, bridge: Dictionary) -> Dictionary:
	var end: Vector2 = bridge.a if _rng.randf() < 0.5 else bridge.b
	var other: Vector2 = bridge.b if end == bridge.a else bridge.a
	var out := (end - other).normalized()
	var roll := _rng.randf()
	var at := end + out * 9.0
	var spot := Vector3(at.x, valley.terrain.height(at.x, at.y), at.y)
	if valley.terrain.water_surface(at.x, at.y) != -INF or _corrupted(spot):
		return {}
	if roll < BRIDGE_TROLL:
		var ev := _event(id, "troll", "Bridge Troll", spot)
		var troll := _unit("barb_bridge_troll", spot, 0.0, 0, 1, Enemy.Team.HOSTILE)
		troll.aggro_radius = 18.0
		ev.foes.append(troll)
		return ev
	var by_village: bool = valley.villages.values().any(func(v): return v.global_position.distance_to(spot) < ValleyTerrain.CAMP_CLEAR)
	if roll < BRIDGE_TROLL + BRIDGE_CAMP and not by_village:
		var camp := spot + Vector3(out.x, 0.0, out.y) * 8.0
		var ev := _event(id, "camp", "Bandits at the bridge", camp)
		_prop(ev, "hut", camp + Vector3(out.x, 0.0, out.y) * 8.0, atan2(out.y, out.x))
		_prop(ev, "bonfire", camp, 0.0)
		for k in 5:
			var e := _unit(["barb_raider", "barb_raider", "barb_slinger", "barb_raider", "barb_berserker"][k], camp, 5.0, k, 5, Enemy.Team.HOSTILE)
			e.aggro_radius = CAMP_AGGRO
			ev.foes.append(e)
		return ev
	var race := _tribe_near(spot)
	if roll >= BRIDGE_TROLL + BRIDGE_CAMP and roll < BRIDGE_TROLL + BRIDGE_CAMP + BRIDGE_SHOP:
		var ev := _event(id, "shop", "Trader's stall", spot, race)
		_prop(ev, "market_stand", spot + Vector3(out.x, 0.0, out.y) * 3.0, atan2(out.y, out.x))
		_prop(ev, "barrel", spot + Vector3(-out.y, 0.0, out.x) * 3.0, 0.0)
		ev.npc = _villager(race, spot)
		return ev
	return _quest_giver(id, spot, race, "Traveler's request")


func _quest_giver(id: String, at: Vector3, race: String, title: String) -> Dictionary:
	var spot := Vector3(at.x, valley.terrain.height(at.x, at.z), at.z)
	var ev := _event(id, "quest", title, spot, race)
	_prop(ev, "crate", spot + Vector3(1.5, 0, 0), 0.0)
	ev.npc = _villager(race, spot)
	return ev


func _villager(race: String, at: Vector3) -> Enemy:
	var members: Array = GameData.where("tribe_members", "race_id", race)
	if members.is_empty():
		members = GameData.where("tribe_members", "race_id", "human")
	return _unit(members[_rng.randi() % members.size()].member_id, at, 0.0, 0, 1, Enemy.Team.NEUTRAL)


## A unit standing around `center` (`i` of `of`, `ring` meters out), posted there.
func _unit(unit_id: String, center: Vector3, ring: float, i: int, of: int, team: Enemy.Team) -> Enemy:
	var e := Enemy.new()
	e.setup(unit_id, valley.player, valley.director, team)
	var p := center + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / maxf(1.0, of) + 0.5) * ring
	p.y = valley.terrain.stand_height(p.x, p.z, center.y) + 0.1
	e.post = p
	valley.add_child(e)
	e.global_position = p
	e.set_dormant(true)
	return e


func _prop(ev: Dictionary, model: String, at: Vector3, angle: float, breakable := true) -> void:
	var root := Node3D.new()
	valley.world.add_child(root)
	root.position = at
	valley.world._building(root, model, Vector3.ZERO, angle, false, 0.0, breakable)
	ev.props.append(root)


# ---------------------------------------------------------------- every half second

func update(_delta: float) -> void:
	var p: Vector3 = valley.player.global_position
	for ev in events:
		var awake: bool = ev.pos.distance_to(p) < AWAKE_RANGE
		for u in _units(ev):
			u.set_dormant(not awake)
		if ev.done or not awake:
			continue
		match ev.kind:
			"caravan":
				if not ev.sprung:
					continue  # still on its way
				if ev.choice == "join":
					if _living(ev.friends).is_empty():
						_finish(ev, "join")
				elif _living(ev.foes).is_empty():
					# Defended, or you helped without a word: paid. Far away: it saved itself.
					_finish(ev, "defend" if ev.choice == "defend" or ev.pos.distance_to(p) < 60.0 else "")
			"ritual":
				if ev.choice == "destroy" and _living(ev.foes).is_empty():
					_finish(ev, "destroy")
			"troll", "camp", "hold":
				if _living(ev.foes).is_empty():
					# Cleared by you, or by some other wild side while you were away (nothing for you then).
					_finish(ev, ev.kind if ev.pos.distance_to(p) < 60.0 else "")
			"quest":
				if ev.choice == "accepted" and _living(ev.foes).is_empty():
					_finish(ev, "quest")


## The event you're close enough to talk to ("" if none) and what F does there.
func prompt() -> String:
	var ev := _talkable()
	if ev.is_empty():
		return ""
	match ev.kind:
		"caravan": return "[F]  %s: defend it or join the attack" % ev.title
		"ritual": return "[F]  %s: partake or destroy" % ev.title
		"shop": return "[F]  Trader's stall (%d supplies)" % Run.state.supplies
		"quest": return "[F]  %s" % ev.title
	return ""


func interact() -> bool:
	var ev := _talkable()
	if ev.is_empty():
		return false
	var hud: Node = valley.hud
	match ev.kind:
		"caravan":
			var tribe := _race_name(ev.race)
			hud.offer_choice("event:" + ev.id, ev.title, ["defend", "join", "leave"], [
				"1.  DEFEND the caravan: the %s like you more and pay %d supplies." % [tribe, PAY.defend],
				"2.  JOIN the attack: take the cargo (%d supplies); the %s like you less." % [PAY.loot, tribe],
				"3.  Leave."])
		"ritual":
			var god := GameData.text(GameData.god(ev.god), "display_name", ev.god)
			hud.offer_choice("event:" + ev.id, ev.title, ["partake", "destroy", "leave"], [
				"1.  PARTAKE: the %s like you more and %s offers you a godly gift." % [_race_name(ev.race), god],
				"2.  DESTROY it: fight its guards. The %s like you less; take the offerings (%d supplies) and a gift from your god." % [_race_name(ev.race), PAY.offerings],
				"3.  Leave."])
		"shop":
			var ids: Array = SHOP.map(func(s): return s[0]) + ["leave"]
			var texts: Array = []
			for i in SHOP.size():
				texts.append("%d.  %s (%d supplies)" % [i + 1, SHOP[i][1], SHOP[i][2]])
			texts.append("%d.  Leave." % (SHOP.size() + 1))
			hud.offer_choice("event:" + ev.id, "Trader's stall: you have %d supplies" % Run.state.supplies, ids, texts)
		"quest":
			hud.offer_choice("event:" + ev.id, ev.title, ["accept", "leave"], [
				"1.  \"A pack has been troubling us nearby. Drive it off?\" Reward: %d supplies." % PAY.quest, "2.  Leave."])
	return true


func on_choice(kind: String, choice: String) -> void:
	if kind == "event_gift":
		var left := pending_gifts()
		left.pop_front()  # menus open in the order offered (Hud._waiting_choices)
		if left.is_empty():
			Run.state.flags.erase("pending_gift")
		else:
			Run.state.flags["pending_gift"] = left
		if choice != "":
			valley.player.godly_gifts.add_godly_gift(choice)
		return
	if not kind.begins_with("event:"):
		return
	var ev := _find(kind.trim_prefix("event:"))
	if ev.is_empty() or choice == "leave":
		return
	match ev.kind:
		"caravan":
			_spring(ev)
			ev.choice = choice
			if choice == "join":  # the guards turn on you; the attackers fight beside you
				for u in _living(ev.friends):
					u.set_team(Enemy.Team.HOSTILE)
				for u in _living(ev.foes):
					u.set_team(Enemy.Team.FRIENDLY)
				for u in _living(ev.others):
					u.flee_from = ev.pos
		"ritual":
			ev.choice = choice
			if choice == "partake":
				_finish(ev, "partake")
			else:
				for u in _living(ev.foes):
					u.set_team(Enemy.Team.HOSTILE)
				for u in _living(ev.others):
					u.flee_from = ev.pos
		"shop":
			_buy(choice)
		"quest":
			if ev.choice == "":
				_start_quest(ev)


func _buy(item: String) -> void:
	var price := 0
	for s in SHOP:
		if s[0] == item:
			price = s[2]
	var hud: Node = valley.hud
	if Run.state.supplies < price:
		hud.show_message("Not enough supplies (%d of %d)." % [Run.state.supplies, price], 2.0)
		return
	if item == "gift" and valley.player.godly_gifts.make_offer(Run.state.god_id).is_empty():
		hud.show_message("Your god has no gift left to offer.", 2.0)
		return
	Run.state.supplies -= price
	match item:
		"heal":
			valley.player.health.heal(valley.player.health.max_hp)
			hud.show_message("You're fully healed.", 2.0)
		"gift":
			_offer_gift(Run.state.god_id)


## A quest: a wild group appears 80-150 m away with a sign over it.
func _start_quest(ev: Dictionary) -> void:
	var c := Vector2(ev.pos.x, ev.pos.z) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(80.0, 150.0)
	var spot := _dry_spot(c, 60.0)
	if spot == Vector3.INF:
		valley.hud.show_message("\"Never mind, they've moved on.\"", 2.0)
		return
	ev.choice = "accepted"
	var group: Dictionary = valley.wilds._spawn_group(spot)
	ev.foes = group.units
	ev.sign.text = "%s: the pack" % ev.title
	ev.sign.visibility_range_end = 0.0  # shown from far away, over the pack
	ev.sign.global_position = spot + Vector3.UP * 8.0
	var dir: Vector3 = spot - valley.player.global_position
	valley.hud.show_message("\"They're about %d m to the %s.\"" % [int(dir.length()), _compass(dir)], 3.0)


func _finish(ev: Dictionary, outcome: String) -> void:
	if outcome != "":
		Run.note("strongholds" if ev.kind == "hold" else "side_quests")
	ev.done = true
	var done: Array = Run.state.flags.get("events_done", [])
	done.append(ev.id)
	Run.state.flags["events_done"] = done
	if is_instance_valid(ev.sign):
		ev.sign.queue_free()
	var hud: Node = valley.hud
	var tribe := _race_name(ev.race)
	match outcome:
		"defend":
			_pay(PAY.defend, ev.race, REP.defend, "The caravan is safe. The %s thank you: %d supplies." % [tribe, PAY.defend])
		"join":
			_pay(PAY.loot, ev.race, REP.join, "You take the cargo: %d supplies. The %s won't forget it." % [PAY.loot, tribe])
		"partake":
			_pay(0, ev.race, REP.partake, "You join the %s in their rite." % tribe)
			_offer_gift(ev.god)
		"destroy":
			_pay(PAY.offerings, ev.race, REP.destroy, "The rite is broken. You take the offerings: %d supplies." % PAY.offerings)
			_offer_gift(Run.state.god_id)
		"camp", "troll":
			_pay(PAY[outcome], "", 0, "The bridge is clear: %d supplies." % PAY[outcome])
		"hold":
			if ev.get("dungeon", false):
				dungeon_reward(ev.title.trim_suffix(" (held)"))
			else:
				_pay(PAY.hold, "", 0, "%s is yours: %d supplies." % [ev.title.trim_suffix(" (held)"), PAY.hold])
				valley.give_xp(HOLD_XP)
		"quest":
			_pay(PAY.quest, ev.race, REP.quest, "The pack is gone: %d supplies%s." % [PAY.quest, "" if ev.race == "" else ", and the %s's thanks" % tribe])
		"":
			if ev.kind == "caravan":
				hud.show_message("The caravan fought off its attackers.", 2.0)
	Run.checkpoint("event_" + ev.id)


## A cleared dungeon (a cave or a castle): XP, supplies, and a godly gift from your god or a weapon.
func dungeon_reward(place: String) -> void:
	var t: CombatTuning = GameData.tuning
	Run.note("dungeons")
	_pay(t.dungeon_supplies, "", 0, "%s is cleared: %d supplies." % [place, t.dungeon_supplies])
	valley.give_xp(t.dungeon_xp)
	if RunRng.chance(50.0) or not valley.offer_weapon():
		_offer_gift(Run.state.god_id)


func _pay(supplies: int, race: String, rep: int, text: String) -> void:
	Run.state.supplies += supplies
	if race != "" and rep != 0:
		Diplomacy.change_reputation(Run.state, race, rep)
	valley.hud.show_message(text, 3.0)


func _offer_gift(god: String) -> void:
	if god == "":
		return
	var ids: Array = valley.player.godly_gifts.make_offer(god)
	if ids.is_empty():
		return
	Run.state.flags["pending_gift"] = pending_gifts() + [god]  # offered again if you quit on this menu
	var hud: Node = valley.hud
	var texts: Array = []
	for i in ids.size():
		texts.append(hud._describe(ids[i], i + 1))
	hud.offer_choice("event_gift", "%s offers a godly gift" % GameData.text(GameData.god(god), "display_name", god), ids, texts)


## The gods whose gift menus are still open, oldest first (an old save keeps one god as text).
func pending_gifts() -> Array:
	var p = Run.state.flags.get("pending_gift", [])
	return [p] if p is String else Array(p)


## After loading: every gift you left open comes back.
func reoffer_gifts() -> void:
	var gods := pending_gifts()
	Run.state.flags.erase("pending_gift")
	for g in gods:
		_offer_gift(g)


# ---------------------------------------------------------------- helpers

func _talkable() -> Dictionary:
	if valley.hud.is_choosing() or Run.in_fight:
		return {}
	var p: Vector3 = valley.player.global_position
	for ev in events:
		if ev.done or not ev.kind in ["caravan", "ritual", "shop", "quest"]:
			continue
		if ev.choice != "" and ev.kind != "shop":
			continue
		if not ev.get("sprung", true):
			continue  # a caravan on its way: nothing to say yet
		var who: Vector3 = ev.npc.global_position if is_instance_valid(ev.npc) else ev.pos
		if who.distance_to(p) < TALK_RANGE or (ev.kind != "shop" and ev.kind != "quest" and ev.pos.distance_to(p) < TALK_RANGE * 2.0):
			return ev
	return {}


func _find(id: String) -> Dictionary:
	for ev in events:
		if ev.id == id:
			return ev
	return {}


func _units(ev: Dictionary) -> Array:
	return _living(ev.foes + ev.friends + ev.others + ([ev.npc] if ev.npc != null else []))


static func _living(units: Array) -> Array:
	return units.filter(func(u): return is_instance_valid(u) and not u.is_dead())


func _free(ev: Dictionary) -> void:
	for u in _units(ev):
		u.queue_free()
	for p in ev.props:
		p.queue_free()
	if is_instance_valid(ev.sign):
		ev.sign.queue_free()


## Open dry ground near `c` (within `spread` m), clear of water, villages and
## Count Fuckula's land. INF if none.
func _dry_spot(c: Vector2, spread: float) -> Vector3:
	var t: ValleyTerrain = valley.terrain
	for attempt in 40:
		var p := c + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread)) * (0.0 if attempt == 0 else 1.0)
		if ValleyTerrain.shape_q(p.x, p.y) > ValleyTerrain.SAFE_Q:
			continue
		if t.water_surface(p.x, p.y) != -INF or t.water_surface(p.x + 10.0, p.y) != -INF or t.water_surface(p.x, p.y + 10.0) != -INF:
			continue
		if t.near_bridge(p.x, p.y, 12.0):
			continue
		var spot := Vector3(p.x, t.height(p.x, p.y), p.y)
		if _corrupted(spot) or valley.villages.values().any(func(v): return v.global_position.distance_to(spot) < 80.0):
			continue
		return spot
	return Vector3.INF


func _fallen(race: String) -> bool:
	return Run.state.tribes.get(race, {}).get("status", "") == "corrupted"


func _corrupted(p: Vector3) -> bool:
	return Run.state.regions.get(valley.terrain.region_at(p.x, p.z), {}).get("corrupted", false)


## The tribe whose region this is ("" for none).
func _tribe_near(p: Vector3) -> String:
	return str(Run.state.regions.get(valley.terrain.region_at(p.x, p.z), {}).get("tribe", ""))


static func _race_name(race: String) -> String:
	return GameData.text(GameData.race(race), "display_name", race) if race != "" else "travelers"


static func _compass(d: Vector3) -> String:
	var names := ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
	var a := fposmod(atan2(d.x, -d.z), TAU)  # north is -z
	return names[int(round(a / (TAU / 8.0))) % 8]

