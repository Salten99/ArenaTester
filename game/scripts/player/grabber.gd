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
const CRUSH_BLOOD := 4  ## a squeeze kill's blood: x blood_kill_drops
const UP_TOSS := 0.7   ## a throw straight up goes this share of hurl_speed
const THROW_BOOST := 1.33  ## your throws (hand and chain) fly a third faster than hurl_speed (user, 2026-11-19)
const SHOULDER := 1.2  ## m above your feet that a held minion swings from
const HANG := 0.75     ## how far a held minion's feet hang below the point you hold it by
const REACH := 0.85    ## arm's length
const PITCH_MIN := -0.6
const PITCH_MAX := 1.45  ## nearly straight up: toss it skyward and let it fall
## Squeeze damage (arena tactics) x your heavy hit: a minion with more health left is slammed instead.
const SQUEEZE_HEAVIES := 1.6
var aim_yaw := 0.0
var aim_pitch := 0.0


## Where you aim the held minion: your view's direction, pitch clamped to PITCH_MIN..PITCH_MAX.
func aim_dir() -> Vector3:
	var p := clampf(aim_pitch, PITCH_MIN, PITCH_MAX)
	return Vector3(-sin(aim_yaw) * cos(p), sin(p), -cos(aim_yaw) * cos(p))


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
	if e.is_broken() and role != "Boss":
		return true  # broken (arena tactics): any size can be finished
	return not (e.is_large or e.giant or e.mini_boss or e.civilian or role in ["Boss", "Champion", "Large", "Miniboss"]
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
	# Held out along your aim (user, 2026-11-19): up, down and round, so a throw goes where you look.
	var front := player.global_position + Vector3.UP * (SHOULDER - HANG) + aim_dir() * REACH
	front.y = maxf(front.y, player.global_position.y + 0.1)  # not into the ground when you look down
	if _throw >= 0.0:
		var k := clampf(_throw / THROW_WINDUP, 0.0, 1.0)
		return front.lerp(player.global_position - player.facing * 0.3 + Vector3.UP * 2.0, k)
	var squeeze := clampf(_crush / GameData.tuning.crush_time, 0.0, 1.0) if not held is Throwable else 0.0
	var side := player.facing.cross(Vector3.UP)
	return front + side * sin(Combat.time * 70.0) * (0.01 + 0.05 * squeeze) + Vector3.UP * sin(Combat.time * 53.0) * 0.03 * squeeze


## One frame of holding. False once the grab is over (crushed, hurled, dropped or lost).
func update(delta: float, intent: PlayerIntent) -> bool:
	aim_yaw = intent.aim_yaw
	aim_pitch = intent.aim_pitch
	player.facing = player.facing.slerp(Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw)), clampf(20.0 * delta, 0.0, 1.0)).normalized()
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
			var ball := held is Throwable and player.visual.anim.has_animation("Human_ThrowBall")  # items go overhand
			player.visual.play_strike("Human_ThrowBall" if ball else "Throw", THROW_WINDUP, THROW_WINDUP + 0.4)
		return true
	if not intent.light_held:
		drop()
		return false
	if held is Throwable:
		return true  # items are hurled, not crushed
	_crush += delta
	if _crush >= GameData.tuning.crush_time:
		if held is Enemy and held.tactics and held.health.hp > squeeze_damage():
			slam()  # too tough to squeeze to death: into the ground with it
		else:
			crush()
		return false
	return true


func squeeze_damage() -> float:
	return player.moveset._base(player) * GameData.tuning.heavy_multiplier * SQUEEZE_HEAVIES


const SLAM_RADIUS := 3.5
const SLAM_PUSH := 11.0


## Slammed into the ground at your feet (user, 2026-11-19): a heavy blow, it's left limp, and the
## shock knocks everyone near you back.
func slam() -> void:
	var e := held
	_let_go()
	if not is_instance_valid(e) or e.is_dead():
		return
	var t: CombatTuning = GameData.tuning
	e.release_grab()
	var land := player.global_position + player.facing * 1.0
	e.global_position = Vector3(land.x, player.global_position.y, land.z)
	if player.visual != null:
		player.visual.play_strike("Melee_2H_Attack_Chop", 0.12, 0.45)
	var info := player.make_hit(squeeze_damage(), "Physical", "Melee", e, DamageInfo.Kind.HEAVY)
	info.no_launch = true
	info.hitstop = t.hitstop_heavy
	info.shake = t.shake_heavy * 1.5
	Combat.deal(e, info)
	if not e.is_dead():
		e.throw(Vector3.UP * 1.5, player)  # bounced off the ground, limp
	for n in Combat.enemies_in_radius(e.global_position, SLAM_RADIUS, [e]):
		var away: Vector3 = n.global_position - e.global_position
		away.y = 0.0
		var push := DamageInfo.make(0.0, "Physical", DamageInfo.Kind.CHAIN, player)
		push.knockback = SLAM_PUSH
		push.knockback_dir = away.normalized() if away.length() > 0.05 else player.facing
		Combat.deal(n, push)
		if n.has_method("stun"):
			n.stun(0.6)
	Vfx.ring(e.global_position + Vector3.UP * 0.05, SLAM_RADIUS, Color(0.9, 0.8, 0.6), 0.3)
	ElementFx.area("Physical", e.global_position, SLAM_RADIUS)
	if e.bleeds():
		Vfx.blood(e.global_position + Vector3.UP * 0.5, Vector3.UP, t.blood_kill_drops)
		Vfx.blood_stains(e.global_position, player.facing, t.blood_stains_per_hit * 2, 1.4)


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
	var head: Vector3 = e.global_position + Vector3.UP * 1.6 * float(e.get("size_scale") if e.get("size_scale") != null else 1.0)
	if e.get("model") != null and e.model.has_method("head_position"):
		head = e.model.head_position(head)
	Combat.deal(e, info)
	player.screen_flash(Color(0.75, 0.0, 0.0, 0.45))  # one red frame over the screen, then the burst
	# The head goes (user, 2026-11-19), a skeleton's skull too.
	if e.get("model") != null and e.model.has_method("pop_head"):
		e.model.pop_head()
	if e.bleeds():
		# A fountain from the neck, a red cloud, the ground soaked all round.
		Vfx.blood(head, Vector3.UP, t.blood_kill_drops * CRUSH_BLOOD)
		Vfx.blood(head, player.facing + Vector3.UP, t.blood_kill_drops * 2)
		Vfx.burst(head, 1.1, Color(0.6, 0.0, 0.0, 0.85), 0.2)
		for k in 4:
			var spread := Vector3(cos(k * PI * 0.5), 0.0, sin(k * PI * 0.5))
			Vfx.blood_stains(e.global_position + spread * 0.6, spread, t.blood_stains_per_hit * 2, 1.6)


## Thrown where you look: it flies as a big projectile (Enemy.hurl).
func hurl() -> void:
	var e := held
	_let_go()
	if not is_instance_valid(e) or e.is_dead():
		return
	var t: CombatTuning = GameData.tuning
	var dir := aim_dir()  # where you look, up or down too: straight up and it falls back hard (Enemy._impact)
	e.release_grab()
	# Straight up it goes UP_TOSS of the speed: about 12 m up, which is plenty of fall.
	var up := clampf(dir.y, 0.0, 1.0)
	e.hurl((dir * t.hurl_speed * lerpf(1.0, UP_TOSS, up) + Vector3.UP * t.hurl_lift * (1.0 - up)) * THROW_BOOST, player)
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
