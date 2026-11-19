class_name Grabber
extends RefCounted
## Grab, crush and hurl (combat feel plan, user 2026-11-18). With your melee weapon out, hold
## light attack grab_hold_time with a minion in reach: your free hand takes it by the neck. Keep
## holding and you crush it in crush_time; let go and it drops; right click hurls it ahead, a
## big projectile (Enemy.hurl). While you hold it, blows from the front land on it instead.
## Minions only: not Large units, champions, mini bosses or bosses. Grabbing is free.

var player: Player
var held: Node3D  ## the minion in your hand, or null
var _crush := 0.0
var _throw := -1.0  ## s since right click started the throw (the minion lets go on the clip's release frame), -1 = not throwing
const THROW_WINDUP := 0.15  ## s from right click to letting go (the reels: a short wind-back)


func throwing() -> bool:
	return _throw >= 0.0


func _init(p: Player) -> void:
	player = p


func holding() -> bool:
	return held != null and is_instance_valid(held) and not held.is_dead()


## Whether `e` can be grabbed: a living hostile minion.
static func grabbable(e: Node) -> bool:
	if not (e is Enemy) or not is_instance_valid(e) or e.is_dead() or e.held_by != null:
		return false
	var role := GameData.text(e.unit, "role")
	return not (e.is_large or e.giant or e.mini_boss or e.water_bound or e.civilian or role in ["Boss", "Champion", "Large", "Miniboss"]
		or e.unit_id.begins_with("champ_"))


## Whether `n` is an item you can pick up (a loose Throwable or a village barrel or crate).
static func is_item(n: Node) -> bool:
	return (n is Throwable and n.held_by == null and not n.is_dead() and not n._flying) or Throwable.is_prop(n)


## The grabbable minion or item in front of you nearest your aim, within grab_reach. Null if none.
func target() -> Node3D:
	var t: CombatTuning = GameData.tuning
	var best: Node3D = null
	var best_angle := deg_to_rad(t.grab_arc_degrees)
	var pool: Array = Combat.enemies_in_radius(player.global_position, t.grab_reach)
	for n in player.get_tree().get_nodes_in_group("throwables") + player.get_tree().get_nodes_in_group("breakables"):
		if is_item(n) and (n as Node3D).global_position.distance_to(player.global_position) <= t.grab_reach + 0.6:
			pool.append(n)
	for e in pool:
		if not grabbable(e) and not is_item(e):
			continue
		var to: Vector3 = e.global_position - player.global_position
		to.y = 0.0
		var angle := player.facing.angle_to(to) if to.length() > 0.1 else 0.0
		if angle <= best_angle:
			best_angle = angle
			best = e
	return best


func grab(e: Node3D) -> void:
	if Throwable.is_prop(e):
		e = Throwable.from_prop(e)
	held = e
	_crush = 0.0
	e.grab_by(player)
	if player.visual != null:
		player.visual.free_left_hand(true)  # a two-handed weapon goes to one hand meanwhile


## Where the held minion hangs: at arm's length in front of you, its feet off the ground. It
## trembles harder as the squeeze goes on, and swings back over your shoulder as you wind up a throw.
func hold_point() -> Vector3:
	var front := player.global_position + player.facing * 0.85 + Vector3.UP * 0.45
	if _throw >= 0.0:
		var k := clampf(_throw / THROW_WINDUP, 0.0, 1.0)
		return front.lerp(player.global_position - player.facing * 0.3 + Vector3.UP * 2.0, k)
	var squeeze := clampf(_crush / GameData.tuning.crush_time, 0.0, 1.0) if not held is Throwable else 0.0
	var side := player.facing.cross(Vector3.UP)
	return front + side * sin(Combat.time * 70.0) * (0.01 + 0.05 * squeeze) + Vector3.UP * sin(Combat.time * 53.0) * 0.03 * squeeze


## One frame of holding. False once the grab is over (crushed, hurled, dropped or lost).
func update(delta: float, intent: PlayerIntent) -> bool:
	if not holding():
		_throw = -1.0
		_let_go()
		return false
	if _throw >= 0.0:  # winding up the throw: it lets go on the release frame
		_throw += delta
		if _throw >= THROW_WINDUP:
			_throw = -1.0
			hurl()
			return false
		return true
	if intent.heavy:
		_throw = 0.0
		if player.visual != null:
			player.visual.play_strike("Throw", THROW_WINDUP, THROW_WINDUP + 0.4)
		return true
	if not intent.light_held:
		drop()
		return false
	if held is Throwable:
		return true  # items are hurled, not crushed
	_crush += delta
	if _crush >= GameData.tuning.crush_time:
		crush()
		return false
	return true


## Squeezed to death: a burst of blood, and it's gone.
func crush() -> void:
	var e := held
	_let_go()
	if not is_instance_valid(e) or e.is_dead():
		return
	var t: CombatTuning = GameData.tuning
	e.release_grab()
	var info := DamageInfo.make(e.health.hp + 1.0, "Physical", DamageInfo.Kind.HEAVY, player)
	info.no_launch = true
	info.hitstop = t.hitstop_heavy
	info.shake = t.shake_heavy
	Combat.deal(e, info)
	player.screen_flash(Color(0.75, 0.0, 0.0, 0.45))  # one red frame over the screen, then the burst
	if e.bleeds():
		Vfx.blood(e.global_position + Vector3.UP * 1.2, Vector3.UP, t.blood_kill_drops)
		Vfx.blood_stains(e.global_position, player.facing, t.blood_stains_per_hit * 2, 1.4)


## Thrown where you look: it flies as a big projectile (Enemy.hurl).
func hurl() -> void:
	var e := held
	_let_go()
	if not is_instance_valid(e) or e.is_dead():
		return
	var t: CombatTuning = GameData.tuning
	var dir := player.facing
	e.release_grab()
	e.hurl(dir * t.hurl_speed + Vector3.UP * t.hurl_lift, player)
	pass  # the throw clip is already playing (update) and reaches its release frame now


## Let go: it drops at your feet and gets up.
func drop() -> void:
	var e := held
	_let_go()
	if is_instance_valid(e) and not e.is_dead():
		e.release_grab()


## Whether the minion in your hand takes this blow: an enemy's blow from in front of you.
## It's dealt to the minion instead.
func shields(info: DamageInfo) -> bool:
	if not holding() or info.kind != DamageInfo.Kind.ENEMY or player.facing.dot(info.knockback_dir) >= 0.0:
		return false
	var e := held
	Combat.deal(e, DamageInfo.make(info.amount, info.damage_type, DamageInfo.Kind.STATUS, null))
	if e.is_dead():
		_let_go()
	return true


func _let_go() -> void:
	_throw = -1.0
	if held != null and is_instance_valid(held):
		held.release_grab()
	held = null
	_crush = 0.0
	if player.visual != null:
		player.visual.free_left_hand(false)
