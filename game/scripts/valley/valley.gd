class_name Valley
extends Arena
## The valley: the run's open world, about 1 x 2 km. Your camp is at the south
## end, Count Fuckula's tribe at the north end. Fights happen where you find
## them:
##   - Walk into a new tribe's village: its event starts (ValleyGenerator.WELCOMES).
##     Win it and the tribe joins you and its god appears. Tribes are never
##     conquered (user, 2026-11-16).
##   - Other encounters (wild gods, camps, Border Defense, the final battle) are
##     places you come upon (EncounterSite): walk into a camp, or press F.
##   - Barbarian patrols and beast packs roam in between (Wilds).
## Warriors from your tribe and every allied tribe join each fight. Battles are
## sized to last 3-5 minutes (EncounterSystem.plan). Count Fuckula's clock runs
## while you explore and pauses during fights.
##
## It extends the arena, so fights, XP, level-ups and god offers work the same.

## How close you must be to an encounter's ring to start it (meters).
const INTERACT_RANGE := 7.0
## Walking this close to a new tribe's village asks: befriend or attack?
const MEET_RANGE := 72.0  # at the walls
## Enemies appear this far from an encounter spot (or a village's center).
const FIGHT_RADIUS := 18.0
const VILLAGE_FIGHT_RADIUS := 34.0

var terrain: ValleyTerrain
var world: ValleyWorld
var grass: GrassField
var items: ThrowableField
var valley_hud: ValleyHud
var sites := {}     ## encounter id -> EncounterSite
var villages := {}  ## race -> Village
var _prepared := {}  ## the world Flow built behind the loading screen
var hamlets: Array = []  ## riverside hamlets (Village nodes with no diplomacy)
var wilds: Wilds    ## roaming barbarians and beasts
var events: WorldEvents  ## caravans, rituals, bridge and hamlet events
var loot: LootSpots  ## caves and towers, their chests and guards
## Warriors who came to help in the current fight (they go home afterwards).
var helpers: Array = []
var fog: FogOfWar  ## what the map shows (the rest stays dark until you go there)
var war: WarChest  ## what the war chest bought, at work in the final battle
## A custom battle from the start screen (Run.state.flags.battle), or {} in a normal run.
var battle: Dictionary = {}
var _battle_village: Village
var _friendlies := 0
var _region := ""
var _near := ""
var _tick_left := 0.0


# ---------------------------------------------------------------- setup (Arena hooks)

func _prepare_run() -> void:
	encounter_id = ""
	battle = Run.state.flags.get("battle", {}) if Run.active else {}
	world_scene = null
	Run.in_fight = false  # a fresh valley has no fight yet (F9 reloads mid-fight without going through Flow)
	if not Run.active:
		# Opened directly from the editor: start a short test run.
		Run.start_new(START_RACE, START_GOD, run_seed, 0.34, START_WEAPON)
	for e in Run.state.encounters.values():
		if e.state == "active":
			e["state"] = "available"  # the game closed mid-fight: the fight starts over
	ValleyTerrain.assign_slots(Run.state)
	_prepared = Flow.take_prepared(Run.state.seed)
	terrain = _prepared.terrain if _prepared.has("terrain") else ValleyTerrain.new(Run.state.seed)


func _build_level() -> void:
	Combat.water = terrain
	if _prepared.has("world"):
		world = _prepared.world  # built behind the loading screen
	else:
		world = ValleyWorld.new()
		world.name = "World"
		world.terrain = terrain
		world.state = Run.state
	add_child(world)
	_prepared = {}
	var saved: Array = Run.state.player_pos
	if saved.size() == 3:
		player_start = Vector3(saved[0], saved[1] + 1.0, saved[2])
	else:
		var home := ValleyTerrain.region_center(home_region())
		var spot := home + Vector2(0.0, -10.0)
		player_start = Vector3(spot.x, terrain.height(spot.x, spot.y) + 1.0, spot.y)
		if Run.state.encounters.get("first_fight", {}).get("state", "") == "available" and battle.is_empty():
			player_start = _hill_over_camp()


# The opening (user, 2026-11-08): no fight. A short clip (OpeningClip) of you walking over a hill
# back to your village, burning and wrecked by Count Fuckula's raid; then the village elder sends
# you after him, and your god gives you a first godly gift.
const OPENING_DISTANCE := 120.0  ## how far the hill is from the camp (m)
const FIRE_LEFT := 150.0  ## the village burns until you're this far from it (user, 2026-11-08: once you leave)
var cinematic := false  ## a clip is playing (OpeningClip): no HUD
var _elder_page := 0
var _smoke: Array = []  ## smoke rising from the camp while it's raided


## Columns of dark smoke over the camp, seen from the hill; gone when the raid is over.
func _camp_smoke(center: Vector3) -> void:
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.18, 0.17, 0.16, 0.55)
	grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var puff := SphereMesh.new()
	puff.radius = 2.6
	puff.height = 5.2
	puff.radial_segments = 6
	puff.rings = 3
	puff.material = grey
	for k in 3:
		var at := center + Vector3(14.0, 0.0, 0.0).rotated(Vector3.UP, k * TAU / 3.0 + 0.4)
		var smoke := CPUParticles3D.new()
		smoke.amount = 36
		smoke.lifetime = 12.0
		smoke.preprocess = 12.0  # already burning when you arrive
		smoke.mesh = puff
		smoke.direction = Vector3.UP
		smoke.spread = 12.0
		smoke.initial_velocity_min = 5.0
		smoke.initial_velocity_max = 8.0
		smoke.gravity = Vector3(0.6, 0.4, 0.0)  # leaning with the wind
		smoke.scale_amount_min = 0.8
		smoke.scale_amount_max = 3.0
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = 2.0
		add_child(smoke)
		smoke.global_position = Vector3(at.x, terrain.height(at.x, at.z) + 3.0, at.z)
		_smoke.append(smoke)


## The opening's lookout: the highest dry ground about OPENING_DISTANCE from your camp.
func _hill_over_camp() -> Vector3:
	var c := ValleyTerrain.region_center(home_region())
	var best := Vector3.INF
	for k in 16:
		var p := c + Vector2(OPENING_DISTANCE, 0.0).rotated(k * TAU / 16.0)
		var h := terrain.height(p.x, p.y)
		if terrain.water_surface(p.x, p.y) == -INF and (best == Vector3.INF or h > best.y):
			best = Vector3(p.x, h, p.y)
	return best + Vector3.UP if best != Vector3.INF else Vector3(c.x, terrain.height(c.x, c.y) + 1.0, c.y - 10.0)


## After the opening clip, the village elder explains the run, page by page.
func elder_pages() -> Array:
	var god_row := GameData.god(Run.state.god_id)
	var god := GameData.text(god_row, "display_name", "our god")
	return [
		"You came back too late. Count Fuckula's creatures came in the night: they burned our houses and cut down everyone who stood in their way. He holds the far north of the valley, and every few minutes his army takes another region from the tribes.",
		"Stop him before the valley is his: march north and break his army in the final battle. Go now and you face him weak; take your time and he grows while you do.",
		"Grow strong on the way. %s gives you godly gifts that build on %s. Fights give you levels. Barbarians raid the other tribes: drive them off and the tribe fights beside you." % [god, GameData.text(god_row, "element", "its power")],
		"Caves, towers and camps hold supplies, godly gifts and weapons. Spend supplies at the war chest (Esc) on catapults, a champion, veterans or your god's meteors: they all join the final battle.",
		"Your main weapon is in your hands; press %s (or turn the mouse wheel) to switch to your sidearm and back. %s calls your mount, %s opens the map, Q, E and R are %s's abilities, and %s is your people's own skill. Go, and come back with the valley." % [
			Controls.binding_text("sidearm"), Controls.binding_text("mount"), Controls.binding_text("valley_map"), god, Controls.binding_text("race_active")],
	]


func _elder_speaks() -> void:
	_elder_page = 0
	_show_elder_page()


func _show_elder_page() -> void:
	var pages := elder_pages()
	var last := _elder_page >= pages.size() - 1
	hud.offer_choice("elder", "The Village Elder  (%d / %d)" % [_elder_page + 1, pages.size()], ["next"],
		["%s\n\n1.  %s" % [pages[_elder_page], "Set out" if last else "Go on"]])


func _begin() -> void:
	hud.idle_text = ""
	fog = FogOfWar.new(Run.state.flags.get("seen", ""))
	_reveal()
	if ValleyWorld.BLADES:
		grass = GrassField.new()  # the carpet of the user's grass tile around you
		grass.name = "GrassField"
		grass.world = world
		grass.target = player
		add_child(grass)
	items = ThrowableField.new()  # loose boulders and branches around you (combat feel plan)
	items.name = "ThrowableField"
	items.world = world
	items.target = player
	add_child(items)
	waves.ray_height = 80.0
	camera_rig.yaw = 0.0  # face north, up the valley toward Count Fuckula
	valley_hud = ValleyHud.new()
	valley_hud.valley = self
	add_child(valley_hud)
	for region in Run.state.regions:
		var race: String = Run.state.regions[region].get("tribe", "")
		if race == "":
			continue
		var c := ValleyTerrain.region_center(region)
		var village := Village.make(self, region, race, region == home_region(), Vector3(c.x, terrain.height(c.x, c.y), c.y))
		villages[race] = village
		add_child(village)
	for entry in terrain.hamlets:
		var p: Vector2 = entry.pos
		var hamlet := Village.make_hamlet(self, entry, _hamlet_race(entry.region), Vector3(p.x, terrain.height(p.x, p.y), p.y))
		hamlets.append(hamlet)
		add_child(hamlet)
	terrain.place_camps(Run.state)  # before the wilds, which keep clear of encounters
	wilds = Wilds.new()
	wilds.name = "Wilds"
	wilds.valley = self
	add_child(wilds)
	events = WorldEvents.new()
	events.name = "WorldEvents"
	events.valley = self
	add_child(events)
	loot = LootSpots.new()
	loot.name = "LootSpots"
	loot.valley = self
	add_child(loot)
	war = WarChest.new()
	war.name = "WarChest"
	war.valley = self
	add_child(war)
	Run.border_attack.connect(_on_border_attack)
	Run.region_fell.connect(_on_region_fell)
	hud.choice_made.connect(_on_choice_made)
	hud.choice_made.connect(events.on_choice)
	player.water_blocked.connect(_on_water_blocked)
	Combat.hit_landed.connect(_on_hit_landed)
	_refresh_sites()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not battle.is_empty():
		_start_custom_battle.call_deferred()
		return
	if Run.state.encounters.get("first_fight", {}).get("state", "") == "available":
		_play_opening.call_deferred()
		return
	hud.show_message("Count Fuckula waits at the far end of the valley. Help the tribes on the way, or go straight for him.  M: map", 8.0)
	_offer_what_was_left_open()


## The opening clip: your village, burning and wrecked, as you come over the hill.
func _play_opening() -> void:
	var village: Village = villages.get(Run.state.race_id)
	if village != null:
		Run.state.flags["home_burned"] = true
		ValleyWorld.burn_village(village.buildings)
		_camp_smoke(village.global_position)
		for at in ValleyWorld.burned_spots(village.buildings):
			var fire := _flames()
			add_child(fire)
			fire.global_position = at
			_smoke.append(fire)
	var clip := OpeningClip.new()
	clip.name = "OpeningClip"
	clip.valley = self
	clip.finished.connect(_after_opening)
	add_child(clip)


## After the clip, three gods answer your call (user, 2026-11-16); you pledge to one, and then
## the elder speaks (_after_god_pick). Quit before picking and the opening plays again.
func _after_opening() -> void:
	remember_position()
	var gods := Run.god_offer()
	var texts: Array = []
	for g in gods:
		var row := GameData.god(g)
		texts.append("%d.  %s  ·  %s\n%s\n%s" % [texts.size() + 1, GameData.text(row, "display_name", g), GameData.text(row, "element"),
			GameData.text(row, "epithet"), GameData.text(row, "short_description")])
	hud.offer_choice("god_pick", "The gods answer your call. Pledge to one", gods, texts)


## You've pledged: the elder sends you after Count Fuckula, then your god's first godly gift.
func _after_god_pick(god: String) -> void:
	Run.choose_god(god)
	player.apply_run_state(Run.state)
	if not Run.god_offered.is_connected(_on_god_offered):
		Run.god_offered.connect(_on_god_offered)
	if not hud.god_chosen.is_connected(_on_god_chosen):
		hud.god_chosen.connect(_on_god_chosen)
	_elder_speaks()
	Run.finish_encounter("first_fight", true)  # your god's gift, offered once the elder is done


## A burning house: your fire column (models/own/fx/fire/fire_column) and its glow, or the code's flames.
func _flames() -> Node3D:
	var scene := ElementFx.own_scene("fire_column")
	if scene == null:
		var aura := ElementFx.aura("Fire", 4.0)
		aura.emitting = true
		return aura
	var n: Node3D = scene.instantiate()
	n.scale = Vector3.ONE * 6.0
	ElementFx._start(n)
	for sprite in n.find_children("*", "AnimatedSprite3D", true, false):
		(sprite as AnimatedSprite3D).play()
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.2)
	glow.light_energy = 2.0
	glow.omni_range = 5.0
	n.add_child(glow)
	return n


## The burning village goes out once you've left it (the charred houses stay).
func _fires_out_once_gone() -> void:
	var home: Village = villages.get(Run.state.race_id)
	if _smoke.is_empty() or Run.in_fight or home == null:
		return
	if Vector2(home.global_position.x - player.global_position.x, home.global_position.z - player.global_position.z).length() > FIRE_LEFT:
		_put_out_fires()


func _put_out_fires() -> void:
	for s in _smoke:
		if is_instance_valid(s):
			if s is CPUParticles3D or s is GPUParticles3D:
				s.emitting = false  # the last puffs drift off
			else:
				s.queue_free()
	_smoke = []


## You quit on a menu last time: it comes back.
func _offer_what_was_left_open() -> void:
	var s: RunState = Run.state
	if s.pending_god != "":
		if not hud.god_chosen.is_connected(_on_god_chosen):
			hud.god_chosen.connect(_on_god_chosen)
		_on_god_offered(s.pending_god)
	events.reoffer_gifts()
	_offer_level_up.call_deferred()
	if Run.state.encounters.get("first_fight", {}).get("state", "") == "done" and not Run.state.flags.get("elder_spoke", false):
		_elder_speaks()  # you quit before the elder finished


func _in_run() -> bool:
	return true


func _friendly_count() -> int:
	return _friendlies


## Hamlet folk belong to their region's tribe; in a region without one, to the
## nearest region that has one.
func _hamlet_race(region: String) -> String:
	var best := ""
	var best_d := INF
	var at := ValleyTerrain.region_center(region)
	for r in Run.state.regions:
		var race: String = Run.state.regions[r].get("tribe", "")
		var d := at.distance_to(ValleyTerrain.region_center(r))
		if race != "" and d < best_d:
			best_d = d
			best = race
	return best if best != "" else "human"


func home_region() -> String:
	return Run.state.flags.get("home_region", ValleyGenerator.home_region())


# ---------------------------------------------------------------- every frame

func _physics_process(delta: float) -> void:
	super(delta)
	if not Run.active or player == null or player.is_dead():
		return
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = 0.5
		_update_region()
		_fires_out_once_gone()
		_update_sites()
		_reveal()
		_note_travel()
		for v in villages.values() + hamlets:
			v.update_dormant(player.global_position, v == _battle_village)
		wilds.update(0.5)
		events.update(0.5)
		if not Run.in_fight:
			_check_villages()
			if player.is_on_floor():
				remember_position()
	_update_siege(delta)
	_near = "" if Run.in_fight else nearest_site(INTERACT_RANGE)
	if _siege_race != "":
		valley_hud.set_prompt("[F]  Let them come (%d s)" % ceili(_siege_left))
	elif _near != "":
		valley_hud.set_prompt("[F]  %s" % sites[_near].title)
	else:
		var chest_text := loot.prompt()
		valley_hud.set_prompt(chest_text if chest_text != "" else events.prompt())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _siege_race != "" and not hud.is_choosing():
		_start_siege()
	elif event.is_action_pressed("interact") and _near != "" and not hud.is_choosing():
		start_site(_near)
	elif event.is_action_pressed("interact") and not hud.is_choosing():
		if not loot.interact():
			events.interact()
	elif event.is_action_pressed("debug_teleport") and not Run.in_fight and OS.is_debug_build():
		_teleport_to_next_site()


## Saves where you are, so a resumed run puts you back here.
var _last_pos := Vector3.INF


## Distance and time for the recap (a teleport doesn't count as travel).
func _note_travel() -> void:
	var here := player.global_position
	if _last_pos != Vector3.INF and here.distance_to(_last_pos) < 60.0:
		Run.note("distance", Vector2(here.x - _last_pos.x, here.z - _last_pos.z).length())
	_last_pos = here
	Run.note("seconds", 0.5)


func _reveal() -> void:
	if fog.reveal(Vector2(player.global_position.x, player.global_position.z)):
		Run.state.flags["seen"] = fog.save_text()


func remember_position() -> void:
	var p := player.global_position
	Run.state.player_pos = [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)]


## The available F encounter within `range` meters of the player ("" if none;
## camps and raids start when you walk in instead).
func nearest_site(range: float) -> String:
	var best := ""
	var best_d := range
	for id in sites:
		if (sites[id] as EncounterSite).auto:
			continue
		var d: float = (sites[id] as Node3D).global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = id
	return best


# ---------------------------------------------------------------- meeting tribes

## A tribe you haven't dealt with yet: walking into its village starts its raid (meet).
func _check_villages() -> void:
	if hud.is_choosing():
		return
	for race in villages:
		var v: Village = villages[race]
		if race != _siege_race and v.global_position.distance_to(player.global_position) < MEET_RANGE and can_meet(race):
			meet(race)
			return


## True if this tribe's event hasn't started yet.
func can_meet(race: String) -> bool:
	var s: RunState = Run.state
	var open: bool = s.tribes.get(race, {}).get("status", "") in ["neutral", "friendly"]
	var tm: Dictionary = s.encounters.get("tm_" + race, {})
	return open and tm.get("state", "") == "available" and not tm.get("asked", false)


## You come upon a tribe's village (user, 2026-11-05: no menu, like open-world survival games):
## barbarians are already raiding it. Help drive them off and the tribe becomes your ally.
## Not every tribe is raided (user, 2026-11-09): some have a champion who challenges you, some ask
## you to clear a barbarian camp first (ValleyGenerator.WELCOMES).
func meet(race: String) -> void:
	var name := GameData.text(GameData.race(race), "display_name", race)
	var tm: Dictionary = Run.state.encounters["tm_" + race]
	var who: String = ATTACKER_WORDS.get(str(tm.get("source", "Barbarians")), "Barbarians")
	if tm.get("siege", false):
		_siege_race = race
		_siege_left = GameData.tuning.siege_prep_seconds
		_siege_from = _far_gate(villages[race])
		var dir := WorldEvents._compass(_siege_from - villages[race].global_position)
		hud.show_message("The %s brace for an attack: %s are coming from the %s! Get ready, then hold the gate (F: let them come now)." % [name, who.to_lower(), dir], 5.0)
		return
	match str(tm.def):
		"ct_champion_duel":
			_battle_village = null  # no guards beside you: their champion's own band
			_start_fight("tm_" + race, villages[race].global_position, VILLAGE_FIGHT_RADIUS, 0)
			hud.show_message("The %s champion challenges you! Beat their champion and the tribe joins you." % name, 4.0)
		"tm_clear_camp":
			tm["asked"] = true
			var to := ValleyTerrain.site_point(Run.state, "tm_" + race)
			var dir := WorldEvents._compass(Vector3(to.x, 0.0, to.y) - villages[race].global_position)
			hud.show_message("The %s ask for help: barbarians camp to the %s. Clear the camp and the tribe joins you (it's on your map)." % [name, dir], 5.0)
		_:
			start_village_battle(race)
			hud.show_message("%s are raiding the %s village! Drive them off and win the tribe." % [who, name], 4.0)


## A weapon in a chest (user, 2026-11-06: find weapons and switch in the world): a sidearm you don't
## carry, offered in place of yours. Never a melee weapon: that's your class (user, 2026-11-09).
## False when there's none to offer (only the bow since 2026-11-19).
func offer_weapon() -> bool:
	var s: RunState = Run.state
	var found: Array = GameData.sidearms().filter(func(w): return w != s.sidearm_id)
	if found.is_empty():
		return false
	var w: String = found[RunRng.randi_range(0, found.size() - 1)]
	var side := GameData.is_sidearm(w)
	var now := s.sidearm_id if side else s.weapon_id
	var row := GameData.weapon(w)
	hud.offer_choice("weapon", "In the chest: a %s (%s)" % [GameData.text(row, "display_name", w), GameData.text(row, "weapon_class")], [w, "leave"], [
		"Take it in place of your %s%s\n%s" % [GameData.text(GameData.weapon(now), "display_name", now), " (sidearm)" if side else "", GameData.text(row, "short_description")],
		"Leave it"])
	return true


func take_weapon(w: String) -> void:
	var s: RunState = Run.state
	if GameData.is_sidearm(w):
		s.sidearm_id = w
	else:
		s.weapon_id = w
	player.equip(s.weapon_id, s.sidearm_id)
	hud.show_message("You take up the %s." % GameData.text(GameData.weapon(w), "display_name", w), 2.5)


func _on_choice_made(kind: String, id: String) -> void:
	if kind == "weapon":
		if id != "leave":
			take_weapon(id)
		return
	if kind == "god_pick":
		_after_god_pick(id)
		return
	if kind == "elder":
		_elder_page += 1
		if _elder_page < elder_pages().size():
			_show_elder_page()
		else:
			Run.state.flags["elder_spoke"] = true
		return


## Who's attacking, in words (ValleyGenerator.ATTACKERS).
const ATTACKER_WORDS := {"Barbarians": "Bandits", "Beasts": "Monsters", "Evil tribe": "Count Fuckula's army"}

# A siege (user, 2026-11-16): the tribe braces for an attack; it comes from the gate on the far
# side after siege_prep_seconds, or when you press F. Walk away and it waits for you.
const SIEGE_SPAWN_RADIUS := 14.0
const SIEGE_OUT := 25.0  ## the attackers gather this far outside the gate
var _siege_race := ""
var _siege_left := 0.0
var _siege_from := Vector3.ZERO


func _update_siege(delta: float) -> void:
	if _siege_race == "" or Run.in_fight or hud.is_choosing():
		return
	var v: Village = villages[_siege_race]
	if v.global_position.distance_to(player.global_position) > MEET_RANGE * 2.0:
		_siege_race = ""  # you left: it starts over when you come back
		return
	_siege_left -= delta
	if _siege_left <= 0.0:
		_start_siege()


func _start_siege() -> void:
	var race := _siege_race
	_siege_race = ""
	start_village_battle(race, _siege_from)
	if Run.in_fight:
		hud.show_message("Here they come! Hold the gate.", 3.0)


## Where a siege comes from: outside the village's gate farthest from you.
func _far_gate(v: Village) -> Vector3:
	var center := v.global_position
	var away := center - player.global_position
	var best := center + Vector3(away.x, 0.0, away.z).normalized() * (ValleyWorld.GATE_RING + SIEGE_OUT)
	var far := -1.0
	for g: Vector3 in (v.buildings.get_meta("spots", {}).get("gates", []) if v.buildings != null else []):
		var at := v.buildings.to_global(g)
		var out := Vector3(at.x - center.x, 0.0, at.z - center.z).normalized()
		if at.distance_to(player.global_position) > far:
			far = at.distance_to(player.global_position)
			best = center + out * (ValleyWorld.GATE_RING + SIEGE_OUT)
	return best


## Defend their village from a raid, right there (a siege: the attackers gather outside `from`).
func start_village_battle(race: String, from := Vector3.INF) -> void:
	var id := "tm_" + race
	if Run.in_fight or not villages.has(race) or Run.state.encounters.get(id, {}).get("state", "") != "available":
		return
	var village: Village = villages[race]
	_battle_village = village
	village.defend()
	var siege := from != Vector3.INF
	_start_fight(id, from if siege else village.global_position, SIEGE_SPAWN_RADIUS if siege else VILLAGE_FIGHT_RADIUS, village.guards.size())
	if siege:
		waves.reserve_at = from  # reinforcements come the same way


# ---------------------------------------------------------------- fights

## Starts an encounter's fight at its place.
func start_site(id: String) -> void:
	if Run.in_fight or not id in EncounterSystem.available(Run.state) or not sites.has(id):
		return
	_pitched = id == "final_battle"
	(sites[id] as EncounterSite).set_fighting(true)
	_start_fight(id, (sites[id] as Node3D).global_position, FIGHT_RADIUS, 0)


func _start_fight(id: String, center: Vector3, radius: float, defenders: int) -> void:
	encounter_id = id
	Run.in_fight = true
	waves.reset()
	waves.center = center
	waves.spawn_radius = radius
	valley_hud.set_prompt("")
	_call_helpers()
	_friendlies = helpers.size() + defenders
	_start_encounter()
	if _pitched:
		_prepare_pitched_battle(center)
	if not helpers.is_empty():
		hud.show_message("Your tribe and every ally ride to your side!", 3.0)


# ---------------------------------------------------------------- the final battle

## The final battle is a pitched battle (user, 2026-10-30): your side forms a line
## in front of you, Count Fuckula's whole army (the horde, plus the warriors of every
## tribe he converted) forms one across the field, and they charge; the Evil Dragon
## comes once his line is broken.
var _pitched := false
var _front := Vector3.BACK  ## from the battle's center toward your side
var _battle_center := Vector3.ZERO
const LINE_GAP := 22.0  ## each line's distance from the center
var _line_gap := LINE_GAP  ## this battle's (a custom battle sets its own)
const LINE_WIDTH := 14  ## units per row


func _prepare_pitched_battle(center: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	var army: Array = []
	for w in waves.plan_waves:
		army.append_array(w)
	army.append_array(waves.reserve)  # his whole army, up to final_battle_on_field at once (below)
	for race in Run.state.tribes:
		if Run.state.tribes[race].status == "corrupted" and race != EvilTribe.HORDE:
			var ids: Array = EncounterSystem.army_rows(race).filter(func(u): return u.role in ["Melee", "Ranged", "Magic"]).map(func(u): return u.unit_id)
			for k in t.battle_converted_warriors if not ids.is_empty() else 0:
				army.append(ids[k % ids.size()])
	var before := army.size()
	var horde: Array = EncounterSystem.army_rows(EvilTribe.HORDE).filter(func(u): return u.role in ["Melee", "Ranged"]).map(func(u): return u.unit_id)
	while army.size() < t.final_battle_min_side and not horde.is_empty():
		army.append(horde[army.size() % horde.size()])
	if army.size() > before and before > 0:
		waves.health_mult *= float(before) / army.size()  # more of them, not a longer fight
	waves.plan_waves = [army.slice(0, t.final_battle_on_field)]  # one great line, not waves
	waves.reserve = army.slice(t.final_battle_on_field)
	waves.battle_size = t.final_battle_on_field
	_battle_center = center
	_front = Vector3(player.global_position.x - center.x, 0.0, player.global_position.z - center.z).normalized()
	if _front == Vector3.ZERO:
		_front = Vector3.BACK
	waves.reserve_at = center - _front * (LINE_GAP + 10.0)  # his reinforcements march in behind his line
	war.muster(helpers, center + _front * (LINE_GAP + 18.0), -_front)  # what the war chest bought
	var own: Array = EncounterSystem.army_rows(Run.state.race_id).filter(func(u): return u.role in ["Melee", "Ranged", "Magic"]).map(func(u): return u.unit_id)
	while helpers.size() < t.final_battle_min_side and not own.is_empty():
		helpers.append(waves.spawn(own[helpers.size() % own.size()], Vector3.INF, Enemy.Team.FRIENDLY))
	form_line(helpers, center + _front * LINE_GAP, -_front)
	hud.show_message("Count Fuckula's army forms its lines. Your tribe and your allies stand with you!", 3.5)


## Count Fuckula arrives riding his dragon; when it falls, he comes down to fight you himself.
func _on_boss_started(e: Enemy) -> void:
	if e.unit_id == EvilTribe.HORDE_BOSS:
		_seat_count_on(e)
		hud.show_message("Count Fuckula comes for you on his Evil Dragon!", 3.5)
	elif e.unit_id == EvilTribe.HORDE_LEADER:
		hud.show_message("The dragon is dead. Count Fuckula will finish you himself!", 3.5)
	else:
		super(e)


func _seat_count_on(dragon: Enemy) -> void:
	var look := ModelRegistry.for_unit(EvilTribe.HORDE_LEADER)
	if look.is_empty() or dragon._visual == null:
		return
	var rider := CharacterModel.new()
	dragon._visual.add_child(rider)
	if not rider.setup(look.model, look.get("weapon", ""), 1.5):
		rider.queue_free()
		return
	rider.set_seat(EvilTribe.LEADER_SEAT)
	rider.play("Crouching")
	dragon.health.died.connect(rider.queue_free)


func _on_wave_started(index: int, total: int) -> void:
	if not _pitched:
		super(index, total)
		return
	form_line(waves.members.filter(func(e): return is_instance_valid(e) and e.team == Enemy.Team.HOSTILE),
		_battle_center - _front * _line_gap, _front)
	if encounter_id == "final_battle":
		war.intervene()
	hud.show_message("The lines clash!", 2.0)


## Stands `units` in rows across `facing`, the first row at `origin`.
func form_line(units: Array, origin: Vector3, facing: Vector3) -> void:
	var side := Vector3(-facing.z, 0.0, facing.x)
	for i in units.size():
		var e: Node3D = units[i]
		var row := i / LINE_WIDTH
		var in_row := mini(LINE_WIDTH, units.size() - row * LINE_WIDTH)
		var p := origin + side * ((i % LINE_WIDTH) - (in_row - 1) * 0.5) * 2.4 - facing * row * 2.6
		p.y = waves.ground_y(p.x, p.z) + 0.1
		e.global_position = p
		e.rotation.y = atan2(-facing.x, -facing.z)


## Warriors from your tribe and every allied tribe run in to help, in the final
## battle only: every other fight is yours alone (pivot, user 2026-11-18).
func _call_helpers() -> void:
	if not _pitched:
		return
	var t: CombatTuning = GameData.tuning
	var groups := [[Run.state.race_id, t.battle_home_warriors]]
	for race in Diplomacy.allies(Run.state):
		groups.append([race, t.battle_ally_warriors])
	var behind := -player.facing
	var i := 0
	for g in groups:
		var army: Array = GameData.where("army_units", "race_id", g[0]).filter(func(u): return u.get("role") in ["Melee", "Ranged", "Magic"])
		if army.is_empty():
			continue
		for k in g[1]:
			var u: Dictionary = army[(k * 2) % army.size()] if k % 3 != 2 else army[k % army.size()]
			var a := (i - 4.0) * 0.35
			var pos := player.global_position + behind.rotated(Vector3.UP, a) * 10.0
			var e := waves.spawn(u.unit_id, Vector3.INF, Enemy.Team.FRIENDLY)
			pos.y = terrain.height(pos.x, pos.z) + 0.1
			e.global_position = pos
			helpers.append(e)
			i += 1


func _return_to_valley() -> void:
	var was := encounter_id
	encounter_id = ""
	_put_out_fires()
	_pitched = false
	Run.in_fight = false
	waves.reset()
	for h in helpers:
		if is_instance_valid(h) and not h.is_dead():
			h.queue_free()  # they head home
	helpers = []
	if _battle_village != null:
		_battle_village.calm()
		_battle_village = null
	_refresh_sites()
	remember_position()
	Run.checkpoint("valley")
	hud.show_message("The fight is won.", 2.5)
	if was == "first_fight" and not Run.state.flags.get("elder_spoke", false):
		_elder_speaks()  # after your god's gift: menus wait their turn


## Places for encounters that aren't a tribe's village event.
func _place_encounters() -> Array:
	return EncounterSystem.available(Run.state).filter(func(id): return not id.begins_with("tm_") 		or (id.begins_with("tm_") and Run.state.encounters[id].def == "tm_clear_camp"))  # a camp a tribe asks you to clear


## Adds places for new encounters and removes finished or expired ones.
func _refresh_sites() -> void:
	ValleyTerrain.assign_slots(Run.state)
	var live: Array = _place_encounters()
	if encounter_id != "" and sites.has(encounter_id):
		live.append(encounter_id)
	for id in sites.keys():
		if not id in live:
			sites[id].queue_free()
			sites.erase(id)
	for id in live:
		if sites.has(id):
			continue
		var p := ValleyTerrain.site_point(Run.state, id)
		var site := EncounterSite.make(Run.state, id, Vector3(p.x, terrain.height(p.x, p.y), p.y))
		sites[id] = site
		add_child(site)


func _update_sites() -> void:
	if not Run.in_fight:
		_refresh_sites()
	for id in sites:
		var site: EncounterSite = sites[id]
		var d := site.global_position.distance_to(player.global_position)
		site.set_dormant(d > Village.AWAKE_RANGE)
		if site.auto and not Run.in_fight and not hud.is_choosing():
			if site.cleared_quietly():
				_clear_quietly(id)
				break
			if site.spotted(player, d):
				start_site(id)  # you walked into the camp (or they saw you sneaking): they fight
				break
	var pending: Dictionary = Run.state.evil.get("pending", {})
	for id in sites:
		if str(id).begins_with("border_") and not pending.is_empty():
			sites[id].set_text("%s\nBorder Defense: %s left" % [sites[id].title, ValleyHud._time(float(pending.time_left))])


## Every sentry of a camp fell before it raised the alarm: cleared without the battle.
func _clear_quietly(id: String) -> void:
	Run.note("camps_quiet")
	hud.show_message("The camp is yours, and nobody raised the alarm.", 3.0)
	Run.finish_encounter(id, true)
	_refresh_sites()


## A blow on a camp's sentry before its fight: one that hasn't noticed you falls at once (a sneak
## attack); the fight would have started if it had noticed you.
## shortcut: any blow on an unaware sentry kills, bows from afar included (Far Cry style); add a
## "found the body" alarm if picking them off proves too easy in play.
func _on_hit_landed(target: Node, info: DamageInfo, _dealt: float) -> void:
	if Run.in_fight or info == null or info.source != player or not target is Enemy:
		return
	for id in sites:
		if target in (sites[id] as EncounterSite).sentries and not target.is_dead():
			target.health.take(target.health.hp)
			return


func _on_water_blocked() -> void:
	hud.show_message("The current drives you back. Only the Frogfolk can swim these waters: find a bridge, or jump your mount across a narrow spot.", 3.0)


func _on_border_attack(region: String, _tribe: String) -> void:
	_refresh_sites()
	hud.show_message("Count Fuckula attacks %s! His raiders gather under dark banners at the border: Border Defense (M: map)." % ValleyHud._region_name(region), 5.0)


func _on_region_fell(region: String) -> void:
	_refresh_sites()
	world.recolor(region)
	var race: String = Run.state.regions.get(region, {}).get("tribe", "")
	if villages.has(race):
		villages[race].corrupt()
	for h in hamlets:
		if h.region == region:
			h.corrupt()
	hud.show_message("%s has fallen to Count Fuckula." % ValleyHud._region_name(region), 5.0)


# ---------------------------------------------------------------- regions

func _update_region() -> void:
	var p := player.global_position
	var region := terrain.region_at(p.x, p.z)
	if region == _region:
		return
	var first := _region == ""
	_region = region
	var r: Dictionary = Run.state.regions.get(region, {})
	var line := ValleyHud._region_name(region)
	if r.get("corrupted", false):
		line += "\nHeld by Count Fuckula"
	elif region == home_region():
		line += "\nYour tribe's camp"
	elif r.get("tribe", "") != "":
		var t: Dictionary = Run.state.tribes.get(r.tribe, {})
		line += "\n%s (%s)" % [GameData.text(GameData.race(r.tribe), "village_name"), t.get("status", "")]
	valley_hud.show_region(line)
	Playtest.region_entered(ValleyHud._region_name(region))
	if not first and not Run.in_fight:
		remember_position()
		Run.checkpoint("region")  # DECISIONS 5b: autosave on entering a region


# ---------------------------------------------------------------- custom battles

## A custom battle (user, 2026-11-05, like the big field battles of medieval sandbox games):
## chosen on the start screen, two armies of chosen troops fight one of four ways, and you
## fight in your own army's line. No valley run around it: it's a throwaway run (Run.practice).
##   plain   two lines on open ground in the chosen region
##   river   one line on each bank of a river with a bridge: cross it, or swim
##   defend  your army holds a village's square; theirs comes in through a gate
##   siege   theirs holds the square; you break in
const SCENARIOS := {"plain": "Pitched battle", "river": "Battle at the river", "defend": "Castle defense", "siege": "Castle siege"}
const ROLES := ["Melee", "Ranged", "Magic", "Large", "Cavalry"]


func _start_custom_battle() -> void:
	var field := battle_field(battle.get("scenario", "plain"), battle.get("region", home_region()))
	encounter_id = "custom_battle"
	_pitched = true
	Run.in_fight = true
	_battle_center = field.center
	_front = field.front
	_line_gap = field.gap
	waves.reset()
	waves.center = field.center
	waves.spawn_radius = 30.0
	waves.health_mult = 1.0
	waves.plan_waves = [army_of(battle.get("theirs", {}))]
	helpers = []
	for id in army_of(battle.get("ours", {})):
		helpers.append(waves.spawn(id, Vector3.INF, Enemy.Team.FRIENDLY))
	_friendlies = helpers.size()
	var ours: Vector3 = field.center + field.front * field.gap
	form_line(helpers, ours, -field.front)
	player.global_position = ours + field.front * 6.0 + Vector3.UP * 2.0
	player.facing = -field.front
	camera_rig.yaw = atan2(field.front.x, field.front.z)
	valley_hud.set_prompt("")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_message("%s: %d against %d. The lines form..." % [SCENARIOS.get(battle.get("scenario", "plain"), "Battle"), helpers.size() + 1, waves.plan_waves[0].size()], 4.0)
	get_tree().create_timer(GameData.tuning.time_between_waves, false).timeout.connect(_continue_waves)  # the Esc menu holds it


## The unit ids of an army: {race, counts: {role: how many}}. A race without a unit for a
## role sends its first unit instead.
static func army_of(side: Dictionary) -> Array:
	var rows := EncounterSystem.army_rows(side.get("race", "human"))
	var out: Array = []
	if rows.is_empty():
		return out
	for role in ROLES:
		var of_role: Array = rows.filter(func(u): return GameData.text(u, "role") == role)
		var id: String = of_role[0].unit_id if not of_role.is_empty() else rows[0].unit_id
		for k in int(side.get("counts", {}).get(role, 0)):
			out.append(id)
	return out


## Where a custom battle is fought: {center, front (from the center toward your line), gap
## (each line's distance from the center)}.
func battle_field(scenario: String, region: String) -> Dictionary:
	var c := ValleyTerrain.region_center(region)
	if scenario == "river" and not terrain.bridges.is_empty():
		var best: Dictionary = terrain.bridges[0]
		for b in terrain.bridges:
			if b.river >= 0 and c.distance_to(b.mid) < c.distance_to(best.mid):
				best = b
		var across: Vector2 = (best.b - best.a).normalized()
		return {"center": _ground3(best.mid), "front": Vector3(across.x, 0.0, across.y), "gap": float(best.reach) + 24.0}
	if scenario in ["defend", "siege"]:
		var village: Village = null
		for v in villages.values():
			if village == null or c.distance_to(Vector2(v.global_position.x, v.global_position.z)) < c.distance_to(Vector2(village.global_position.x, village.global_position.z)):
				village = v
		if village != null:
			var at := Vector2(village.global_position.x, village.global_position.z)
			var gates := terrain.road_angles(at)
			var a: float = gates[0] if not gates.is_empty() else 0.0
			var out := Vector2.from_angle(a)
			var inside := at + out * 12.0
			var outside := at + out * (ValleyWorld.WALL_RING + 45.0)
			var mine: Vector2 = inside if scenario == "defend" else outside
			var theirs: Vector2 = outside if scenario == "defend" else inside
			var front := (mine - theirs).normalized()
			return {"center": _ground3((mine + theirs) * 0.5), "front": Vector3(front.x, 0.0, front.y), "gap": mine.distance_to(theirs) * 0.5}
	# Open ground: the flattest dry spot a little way out from the region's middle.
	var best_spot := c
	var best_rough := INF
	for k in 12:
		var p := c + Vector2.from_angle(TAU * k / 12.0) * 230.0
		if ValleyTerrain.shape_q(p.x, p.y) > ValleyTerrain.SAFE_Q * 0.95:
			continue
		var rough := 0.0
		for q in [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
			if terrain.water_surface(p.x + q.x, p.y + q.y) != -INF:
				rough += 100.0
			rough += absf(terrain.height(p.x + q.x, p.y + q.y) - terrain.height(p.x, p.y))
		if rough < best_rough:
			best_rough = rough
			best_spot = p
	var face := (c - best_spot).normalized() if best_spot != c else Vector2(0, 1)
	return {"center": _ground3(best_spot), "front": Vector3(face.x, 0.0, face.y), "gap": LINE_GAP}


func _ground3(p: Vector2) -> Vector3:
	return Vector3(p.x, terrain.height(p.x, p.y), p.y)


## A custom battle gives no XP: no level-up menus stopping the fight.
func give_xp(xp: float) -> void:
	if battle.is_empty():
		super(xp)


## A custom battle's end: no god, no run to go back to.
func _finish_encounter(won: bool) -> void:
	if battle.is_empty():
		super(won)
		return
	hud.show_message("Victory! Their army is broken." if won else "Your army is broken.", 0.0)
	Run.end(won)
	hud.show_action("Back to the start screen", Flow.goto_director)


func _on_player_died() -> void:
	if battle.is_empty():
		super()
		return
	hud.show_message("You fell. The battle is lost.", 0.0)
	Run.end(false)
	hud.show_action("Back to the start screen", Flow.goto_director)


## F12 (debug): straight to Count Fuckula's final battle.
func debug_final_battle() -> void:
	if Run.in_fight or not sites.has("final_battle"):
		return
	player.global_position = (sites["final_battle"] as Node3D).global_position + Vector3(0.0, 1.0, 6.0)
	player.velocity = Vector3.ZERO
	start_site("final_battle")


## F10 (debug): jump to the next encounter place or village you haven't dealt with.
func _teleport_to_next_site() -> void:
	var spots: Array = []
	for id in sites:
		spots.append([str(id), (sites[id] as Node3D).global_position + Vector3(0.0, 1.0, 4.0)])
	for race in villages:
		if can_meet(race):
			spots.append(["village " + race, villages[race].global_position + Vector3(0.0, 1.0, MEET_RANGE + 5.0)])
	if spots.is_empty():
		return
	spots.sort_custom(func(a, b): return a[0] < b[0])
	var next: Array = spots[0]
	for i in spots.size():
		if spots[i][1].distance_to(player.global_position) < 12.0:
			next = spots[(i + 1) % spots.size()]
			break
	player.global_position = next[1]
	player.velocity = Vector3.ZERO
	camera_rig.snap_to_target()
	hud.show_message("Debug: teleported to %s" % next[0], 1.5)
