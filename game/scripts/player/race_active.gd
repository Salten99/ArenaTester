class_name RaceActive
extends Node
## Your race's active skill (Races sheet: active_name, active_description, duration,
## active_bonus_damage, active_cooldown_s), on the V key (user, 2026-11-01). Each race's
## skill is one branch of cast(); the numbers come from the sheet.

const BLAST_RADIUS := 8.0
const LINE_HALF_ANGLE := 15.0  ## degrees either side of where you face
const CHARGE_SPEED := 18.0
const CHARGE_MIN := 0.4  ## seconds a charge always lasts
const CHARGE_MAX := 4.0
const CHARGE_REACH := 2.5
const SUMMONS := 3
const SUMMON_UNIT := "beast_dire_wolf"

var player: Player
var cooldown := 0.0
var invulnerable := false
var _charge_time := -1.0  ## seconds into a charge (negative = not charging)
var _holding := false  ## this skill keeps enemies where they are: its hits don't launch
var _charged := {}  ## enemy instance id -> true: a charge hits each enemy once


func row() -> Dictionary:
	return GameData.race(player.race_id)


func title() -> String:
	return GameData.text(row(), "active_name", "Active")


## Uses the skill. False while it's cooling down.
func cast() -> bool:
	if cooldown > 0.0 or player.is_dead() or player.abilities.invulnerable:
		return false
	var r := row()
	cooldown = GameData.num(r, "active_cooldown_s", 60.0)
	var seconds := GameData.num(r, "duration", 5.0)  # the minotaur's is words: its charge ignores it
	var bonus := GameData.num(r, "active_bonus_damage", 0.0)
	if player.visual != null:
		player.visual.play("Melee_1H_Attack_Chop", 0.5, true)
	match player.race_id:
		"dwarf":
			invulnerable = true
			get_tree().create_timer(seconds, false).timeout.connect(func(): invulnerable = false)
		"elf":
			_blast(BLAST_RADIUS * 1.25, bonus, GameData.text(GameData.god(player.god_id), "element", "Light"), 6.0)
		"human":
			for stat in ["damage_pct", "attack_speed_pct", "move_speed_pct", "armor_pct"]:
				player.stats.add_timed("active_" + stat, stat, 20.0, seconds)
		"gnoll":
			player.stats.add_timed("active_fury", "attack_speed_pct", 75.0, seconds)
		"bird":
			_blast(BLAST_RADIUS, bonus, "Air", 18.0)
		"orc":
			player.stats.add_timed("active_cry", "damage_pct", bonus, seconds)
			_shout()
		"gnome":
			_mushroom(seconds)
		"frog":
			player.health.heal(player.health.max_hp)
			player.stats.add_timed("active_spawn", "damage_pct", bonus, seconds)
		"centaur":
			_summon(seconds)
		"minotaur":
			_charge_time = 0.0
			_charged.clear()
			invulnerable = true
		"treekin":
			for e in _blast(BLAST_RADIUS, bonus, "Thorns", 0.0):
				_hold(e, seconds)
		"angel":
			player.abilities._leap({"base_damage": bonus, "damage_type": "Light", "slot": "Movement"}, player, player.facing, 10.0, 6.0)
			player.health.heal(player.health.max_hp * 0.25)
			for ally in get_tree().get_nodes_in_group("allies"):
				ally.health.heal(ally.health.max_hp * 0.25)
		"demon":
			_beam(seconds, bonus)
		"ratfolk":
			_carpet(seconds, bonus)
		"macaque":
			_holding = true
			for e in _line(8.0, bonus, "Ice"):
				_hold(e, seconds)
			_holding = false
		"cat":
			_blast(BLAST_RADIUS, 0.0, "Physical", 14.0, true)  # shortcut: knocked flat, not really fleeing; give enemies a flee state if it feels weak
			_shout()
		"owl":
			_blast(BLAST_RADIUS, bonus, "Ice", 14.0, false, "ice")
		"elephant":
			_blast(7.0, bonus, "Physical", 8.0, true)
			_shout()
		"dragon":
			_line(10.0, bonus, "Lightning")
		"fennec":
			player.stats.add_timed("active_speed", "move_speed_pct", 60.0, seconds)
			_blast(6.0, 0.0, "Sand", 4.0, false, "sand")
		_:
			_blast(BLAST_RADIUS, maxf(bonus, 40.0), "Physical", 10.0)  # a race added without its own skill yet
	return true


## Hits everyone around you. Returns who it hit.
func _blast(radius: float, damage: float, element: String, knockback: float, knockdown := false, status := "") -> Array:
	var center := player.global_position
	ElementFx.area(element, center, radius)
	var hit: Array = Combat.enemies_in_radius(center, radius)
	for e in hit:
		var away: Vector3 = e.global_position - center
		away.y = 0.0
		_hit(e, damage, element, away.normalized() if away.length() > 0.05 else Vector3.FORWARD, knockback, knockdown, status)
	return hit


## Hits everyone in a narrow line ahead of you. Returns who it hit.
func _line(reach: float, damage: float, element: String) -> Array:
	var hit: Array = player.enemies_in_arc(reach, LINE_HALF_ANGLE)
	var from := player.global_position + Vector3.UP
	ElementFx.beam(element, from, from + player.facing * reach)
	for e in hit:
		_hit(e, damage, element, player.facing, 6.0)
	return hit


func _hit(e: Node, damage: float, element: String, dir: Vector3, knockback: float, knockdown := false, status := "") -> void:
	var info: DamageInfo = player.make_hit(damage, element, "Magic", e, DamageInfo.Kind.ABILITY)
	info.knockback_dir = dir
	info.knockback = knockback
	info.knockdown = knockdown
	info.no_launch = _holding or knockback <= 0.0
	if status != "":
		info.with_status(status)
	Combat.deal(e, info)


## Holds an enemy in place. Bosses and other large units shake it off in half the time.
func _hold(e: Node, seconds: float) -> void:
	e.freeze(seconds * 0.5 if e.is_large else seconds)


func _shout() -> void:
	Combat.shake(GameData.tuning.shake_explosion)


## The Gnome's skill: the nearest enemy shrinks to a squat, helpless mushroom shape for a while.
func _mushroom(seconds: float) -> void:
	var near: Array = Combat.nearest_enemies(player.global_position, 15.0, 1)
	if near.is_empty():
		return
	var e: Enemy = near[0]
	_hold(e, seconds)
	var look: Node3D = e.model
	if look == null:
		return
	var plain := look.scale
	look.scale = Vector3(plain.x * 1.3, plain.y * 0.4, plain.z * 1.3)  # shortcut: squashed, not a real mushroom model; add one if it reads badly
	look.set_tint(Color(0.85, 0.35, 0.3, 0.5))
	var back := get_tree().create_timer(seconds, false).timeout  # bound to the look, so a freed one just drops off
	back.connect(look.set.bind("scale", plain))
	back.connect(look.set_tint.bind(Color(0, 0, 0, 0)))


## The Centaur's skill: wolves fight beside you, then go.
func _summon(seconds: float) -> void:
	var arena: Node = player.get_parent()
	for k in SUMMONS:
		var wolf := Enemy.new()
		wolf.setup(SUMMON_UNIT, player, arena.get("director"), Enemy.Team.FRIENDLY)
		arena.add_child(wolf)
		wolf.global_position = player.global_position + Vector3(cos(k * TAU / SUMMONS), 0.5, sin(k * TAU / SUMMONS)) * 2.5
		get_tree().create_timer(seconds, false).timeout.connect(wolf.queue_free)


## The Demon's skill: `total` damage in ticks along a line ahead, for `seconds`.
func _beam(seconds: float, total: float) -> void:
	var ticks := maxi(1, int(seconds * 2.0))
	for k in ticks:
		if not is_instance_valid(player) or player.is_dead():
			return
		_holding = true  # the beam burns them where they stand
		_line(14.0, total / ticks, "Fire")
		_holding = false
		await get_tree().create_timer(0.5, false).timeout


## The Ratfolk's skill: poison spreads around you while it lasts.
func _carpet(seconds: float, damage: float) -> void:
	var ticks := maxi(1, int(seconds))
	for k in ticks:
		if not is_instance_valid(player) or player.is_dead():
			return
		_blast(6.0, damage, "Poison", 0.0, false, "poison")
		await get_tree().create_timer(1.0, false).timeout


func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if _charge_time >= 0.0:
		_update_charge(delta)


## The Minotaur's skill: runs straight ahead until you let go, hit a wall, or run out of time.
func _update_charge(delta: float) -> void:
	_charge_time += delta
	var bump: KinematicCollision3D = player.move_and_collide(player.facing * CHARGE_SPEED * delta)
	var hit_wall: bool = bump != null and not bump.get_collider() is Enemy and absf(bump.get_normal().y) < 0.5
	var damage := GameData.num(row(), "active_bonus_damage", 150.0)
	for e in player.enemies_in_arc(CHARGE_REACH, 60.0):
		if not _charged.has(e.get_instance_id()):
			_charged[e.get_instance_id()] = true
			_hit(e, maxf(damage, 150.0), "Physical", player.facing, 12.0, true)
	var let_go: bool = _charge_time > CHARGE_MIN and not player.race_active_held
	if let_go or hit_wall or _charge_time > CHARGE_MAX or player.is_dead():
		_charge_time = -1.0
		invulnerable = false
