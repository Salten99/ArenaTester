class_name EndlessArena
extends Arena
## Endless survival against mythical foes: skeleton warriors and archers, gorgons, minotaurs and
## cyclopes, each wave a little bigger, until you fall. Your score is the wave and the kills. No godly
## gifts and no level-ups: you fight with your weapon and element as they are.
## Everything else (the player, combat, the gladiator arena, the things to throw) is Arena's.

## Enemies in the first wave, and how many more each wave brings (user, 2026-11-19: fewer, tougher).
const START_SIZE := 4
const GROWTH := 1
const MAX_SIZE := 12
## Every third enemy shoots (a skeleton archer); from the third wave one of them casts instead (a gorgon).
const SHOOTER := "horde_skeleton_archer"
const CASTER := "monster_gorgon"
const CASTER_FROM := 2
## From this wave on, every fifth enemy is a tough one (a minotaur, who charges).
const TOUGH_FROM := 3
## Every this many waves, a large one joins (a cyclops).
const LARGE_EVERY := 4
## Your light hits it takes to kill each kind (user, 2026-11-19: 3-4 hits for the common ones).
## Health comes from your light hit at the start, so every weapon needs about the same count.
const HEALTH_WEAPON := "warhammer"
const HITS_TO_KILL := {WaveDirector.BASIC_UNIT: 3.5, SHOOTER: 3.0, CASTER: 3.0, WaveDirector.TOUGH_UNIT: 6.0, WaveDirector.LARGE_UNIT: 18.0}
## Fighters that may close in on you at once (the tuning's max_attackers is 3); the rest circle and
## wait their turn (user, 2026-11-19: FightQuest's pacing, one foe at a time). Shooters take turns apart.
const ATTACKERS := 1
## Enemies on the field at once: a wave walks in this many at a time, the rest as they fall.
const ON_FIELD := 4
## From the second wave, the second skeleton warrior of every four carries a shield.
const SHIELD_FROM := 1
## The arena's pace (user, 2026-11-19: "a little faster combat"): quicker swings and feet, stamina back sooner.
const PACE := {"attack_speed_pct": 20.0, "move_speed_pct": 10.0, "stamina_regen_pct": 25.0}
## Seconds between waves, and the health orb and barrel left in that pause.
const WAVE_GAP := 5.0
## The traps: two spike walls and two fire pits on a ring around the middle.
const HAZARD_RING := 15.0
const HAZARDS := [["fire", 45.0], ["spikes", 135.0], ["fire", 225.0], ["spikes", 315.0]]
const HINT := "Walk over a weapon to take it; hold G and let go to throw it through them.  Break them (gold !) and grab to finish.  Dodge just as a blow lands.  Dodge standing still to parry.\nSlide key: tap to dash, hold to slide.  While chained: right click to yank.  Throw enemies into the spikes and fire."

var kills := 0
var menu: ArenaMenu
## True once a loadout was picked: a restart then goes straight into the fight.
static var loadout_picked := false


## The units for wave `index` (0 = the first).
static func wave_units(index: int) -> Array:
	var count := mini(START_SIZE + GROWTH * index, MAX_SIZE)
	var units: Array = []
	var cast := index >= CASTER_FROM
	for i in count:
		if i % 3 == 2:
			units.append(CASTER if cast else SHOOTER)
			cast = false  # one caster a wave; the other ranged slots stay archers
		elif index >= TOUGH_FROM and i % 5 == 4:
			units.append(WaveDirector.TOUGH_UNIT)
		elif index >= SHIELD_FROM and i % 4 == 1:
			units.append(WaveDirector.BASIC_UNIT + WaveDirector.SHIELD_TAG)
		else:
			units.append(WaveDirector.BASIC_UNIT)
	if (index + 1) % LARGE_EVERY == 0:
		units.append(WaveDirector.LARGE_UNIT)
	return units


## Damage of one plain light hit with a warhammer (no crit), which sets enemy health: the same
## whether you hold a weapon yet or not (you start with your fists).
func light_hit_damage() -> float:
	return player._boosted(GameData.num(GameData.weapon(HEALTH_WEAPON), "weapon_base_damage", 15.0), "Physical", "Melee", null)


func _begin() -> void:
	waves.endless = true
	waves.battle_size = ON_FIELD
	_queue_wave(0)
	camera_rig.first_person = true  # FightQuest's view (user, 2026-11-19); T switches back
	waves.hit_damage = light_hit_damage()
	waves.hits_to_kill = HITS_TO_KILL
	waves.tactics = true
	director.max_attackers = ATTACKERS
	player.perfect_dodge = true
	player.parry_for_all = true
	player.no_stamina = true  # a fight and movement training ground: no stamina for now (user, 2026-11-19)
	hud._stamina_bar.visible = false
	if player.input_source is PlayerInput:
		player.input_source.slide_dashes = true  # the slide key: tap to dash, hold to slide
	player.stats.set_source("arena_pace", PACE)  # a little faster combat (user, 2026-11-19)
	_build_hazards()
	hud._godly_gifts.visible = false  # no godly gifts here for now (user, 2026-11-19): weapon and element only
	hud._level_label.visible = false  # and no XP or level-ups: a place to test combat (user, 2026-11-19)
	menu = ArenaMenu.new()
	menu.arena = self
	add_child(menu)
	menu.loadout_chosen.connect(_on_loadout_chosen)
	if not auto_start:
		return  # tests start the waves themselves
	if not loadout_picked:
		menu.open_loadout(player.god_id)
		return
	_start_fight()


## Restarts with the picked element (Arena._prepare_run reads it from Flow).
func _on_loadout_chosen(god_id: String) -> void:
	Flow.practice_god = god_id
	loadout_picked = true
	restart()


func _start_fight() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_message(HINT, 6.0)
	get_tree().create_timer(WAVE_GAP, false).timeout.connect(_continue_waves)


## The gladiator arena, plus walls and heights to run, climb and chain up (ArenaCourse).
func _build_level() -> void:
	super()
	ArenaCourse.build(self)


func _build_hazards() -> void:
	for h in HAZARDS:
		var a := deg_to_rad(h[1])
		var at := Vector3(cos(a), 0.0, sin(a)) * HAZARD_RING
		at.y = waves.ground_y(at.x, at.z)
		ArenaHazard.make(h[0], self, at, -a + PI * 0.5)  # a spike wall lies along the ring, its spikes facing the middle


## The pause after a wave: a health orb and a barrel to throw, somewhere near the middle.
func _leave_supplies() -> void:
	var a := RunRng.randf_range(0.0, TAU)
	var at := Vector3(cos(a), 0.0, sin(a)) * RunRng.randf_range(5.0, 9.0)
	at.y = waves.ground_y(at.x, at.z)
	ArenaPickup.make(self, at)
	var b := at + Vector3(cos(a + 1.2), 0.0, sin(a + 1.2)) * 2.5
	b.y = waves.ground_y(b.x, b.z)
	Throwable.make("barrel", self, b, a)


func _on_wave_started(index: int, _total: int) -> void:
	hud.show_message("Wave %d" % (index + 1), 1.5)


## Wave `index` walks in ON_FIELD at a time: none placed up front, all of it as reinforcements
## (WaveDirector.reserve), which come from the ring as others fall.
func _queue_wave(index: int) -> void:
	waves.plan_waves.append([])
	waves.reserve = wave_units(index)


func _on_wave_cleared(index: int) -> void:
	_queue_wave(index + 1)
	hud.show_message("Wave %d survived" % (index + 1), 1.5)
	_leave_supplies()
	scatter_weapons()
	get_tree().create_timer(WAVE_GAP, false).timeout.connect(_continue_waves)


## No XP, so no level-up upgrades: the arena is for testing combat as it is.
func give_xp(_xp: float) -> void:
	pass


func _on_killed(target: Node, info: DamageInfo) -> void:
	if target is Enemy:
		kills += 1
	super(target, info)


func _on_player_died() -> void:
	Playtest.death()
	hud.show_message("You fell on wave %d with %d kills." % [waves.wave + 1, kills], 0.0)
	Run.end()
	hud.show_action("Try again", restart)
