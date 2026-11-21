class_name Chain
extends RefCounted
## The chain grab (combat feel plan, user 2026-11-18, from their fifth reel). The same held light
## attack as the hand grab: with no minion in reach but a target in the crosshair within
## chain_range, a chain shoots from your free hand and hooks it, even mid-air. No cooldown.
## With empty hands it also takes a weapon (lying, or stuck in a wall) and pulls it into your hand.
## With a minion hooked, still holding light attack:
##   - scroll the wheel: reel it in; if a light hit would kill it you punch it apart, else it's in
##     your hand (the hand grab: crush or hurl);
##   - right click: rip it to you into a kick (a heavy hit that launches it);
##   - flick the mouse down: yank it up and slam it down, a burst where it lands;
##   - sweep the mouse sideways: swing it around you, hitting all it sweeps; let go to fling it;
##   - let go without swinging: the chain lets go and it drops;
##   - walk away from it: the chain goes taut and drags it limp along the ground, hurting it as it goes.
## What you pull in knocks enemies in its path aside (chain_plow_knockback).
## On a Large unit or boss the chain holds fast; right click (or the wheel) pulls you to it for a drop kick (a heavy):
## it's launched only if the kick kills it, else it slides back on its feet (chain_kick_push).
## On a gold ring on a tall wall's lip (a LedgeAnchor, user 2026-11-20) it slings you up and over onto the top.
enum Mode { OFF, FLYING, HOOKED, REEL, SLAM, SWING, PULL, KICK, YANK, DRAG, ANCHOR, SLING }
const YANK_TIME := 0.22  ## s for a yanked minion to fly into your blow
const WALL_SLAM_DAMAGE := 1.4  ## swinging it into a wall: x a heavy hit

var player: Player
var mode := Mode.OFF
var target: Node3D  ## what the chain is after (a hooked minion, or the big one pulling you)
var _time := 0.0
var _swing_angle := 0.0
var _swing_dir := 1.0
var _swing_hit: Array = []
var _slam_from := Vector3.ZERO
var _last_yaw := INF
var _last_pitch := INF
var _hold_at := Vector3.ZERO  ## where a hooked minion hangs while nothing moves it
var _line: MultiMeshInstance3D
var _kick_started := false
var _vel := Vector3.ZERO  ## a hanging minion's fall speed
var _spin := 0.0  ## the swing's spin now (radians/s): it winds up, a heavy thing takes time to get going
var _swing_turned := 0.0  ## radians swung so far this swing
var _length := 0.0  ## how much chain is out (m, along the ground): walk farther than this and it drags
var _drag_tick := 0.0  ## s until the next scrape of drag damage
const GRAVITY := 20.0  ## the same fall as thrown things
const KICK_LEAD := 0.15  ## s before you reach a big one that the drop kick starts, so its strike frame lands on arrival


func kicking() -> bool:
	return _kick_started


func _init(p: Player) -> void:
	player = p


func active() -> bool:
	return mode != Mode.OFF


## Whether `e` pulls you to it instead of being hooked: a unit too big to grab.
static func pulls_you(e: Node) -> bool:
	return e is Enemy and not Grabber.grabbable(e)


## The enemy nearest your aim within chain_range (any size), or null.
func find_target(intent: PlayerIntent) -> Node3D:
	var t: CombatTuning = GameData.tuning
	var eye := player.global_position + Vector3.UP * 1.4
	var aim: Vector3 = (intent.crosshair - eye).normalized() if intent.crosshair != Vector3.INF and intent.crosshair.distance_to(eye) > 0.5 else player.facing
	var best: Node3D = null
	var best_angle := deg_to_rad(t.chain_cone_deg)
	var pool: Array = Combat.enemies_in_radius(player.global_position, t.chain_range)
	for n in player.get_tree().get_nodes_in_group("throwables") + player.get_tree().get_nodes_in_group("breakables"):
		if Grabber.is_item(n) and (n as Node3D).global_position.distance_to(player.global_position) <= t.chain_range:
			pool.append(n)  # items too: whatever is nearest the crosshair
	if player.weapon_id == GameData.FISTS:  # and weapons, lying or stuck in a wall, for empty hands
		for w in player.get_tree().get_nodes_in_group("chain_weapons"):
			if (w as Node3D).global_position.distance_to(player.global_position) <= t.chain_range:
				pool.append(w)
	for a in player.get_tree().get_nodes_in_group("ledge_anchors"):  # and the rings on tall walls, farther off
		if (a as Node3D).global_position.distance_to(player.global_position) <= t.sling_range:
			pool.append(a)
	for e in pool:
		if not is_instance_valid(e) or e.is_dead() or (e is Enemy and e.held_by != null):
			continue
		# Anywhere on its body counts, feet to head, plus its width: a big one is a big target.
		var feet: Vector3 = e.global_position
		var near := Geometry3D.get_closest_point_to_segment(eye + aim * eye.distance_to(feet), feet, feet + Vector3.UP * e.aim_height() * 2.0)
		var to: Vector3 = near - eye
		if to.length() > (t.sling_range if e is LedgeAnchor else t.chain_range) + 1.0:
			continue
		var width: float = 0.4 * e.size_scale if e is Enemy else (0.8 if e is LedgeAnchor else 0.3)
		var angle := maxf(0.0, aim.angle_to(to) - atan2(width, maxf(to.length(), 0.5)))
		if angle <= best_angle:
			best_angle = angle
			best = e
	return best


func fire(e: Node3D) -> void:
	if Throwable.is_prop(e):
		e = Throwable.from_prop(e)
	target = e
	mode = Mode.FLYING
	_time = 0.0
	_kick_started = false
	_last_yaw = INF
	_last_pitch = INF
	_swing_hit = [e]
	_show_line(true)


## One frame. Returns false once the chain is done (the player goes back to free).
func update(delta: float, intent: PlayerIntent) -> bool:
	var t: CombatTuning = GameData.tuning
	_time += delta
	var yaw_rate := 0.0 if _last_yaw == INF else angle_difference(_last_yaw, intent.aim_yaw) / maxf(delta, 0.001)
	var pitch_rate := 0.0 if _last_pitch == INF else (intent.aim_pitch - _last_pitch) / maxf(delta, 0.001)
	_last_yaw = intent.aim_yaw
	_last_pitch = intent.aim_pitch
	if not is_instance_valid(target) or (target.is_dead() and mode not in [Mode.KICK]):
		return _end()
	match mode:
		Mode.FLYING:
			var reach := hand().distance_to(_target_point())
			if _time * t.chain_speed >= reach:
				if target is WeaponPickup:  # a weapon: yanked straight into your hand
					player.equip(target.weapon_id)
					Vfx.sparks(_target_point(), hand() - _target_point(), 6)
					target.queue_free()
					return _end()
				if target is LedgeAnchor:  # a ring on a wall: up you go
					mode = Mode.SLING
					_time = 0.0
					player.collision_mask = 0b001  # past anyone in the way
					Vfx.sparks(_target_point(), hand() - _target_point(), 6)
					return true
				if pulls_you(target):
					mode = Mode.ANCHOR  # it holds on a big one until you pull yourself in
				else:
					mode = Mode.HOOKED
					_hold_at = target.global_position
					_vel = Vector3.ZERO
					_length = _flat_gap(_hold_at)
					target.grab_by(player)
					Vfx.sparks(_target_point(), hand() - _target_point(), 6)
					Combat.shake(t.shake_heavy * 0.3)  # the jolt as the chain goes taut on its weight
				Vfx.burst(_target_point() - Vector3.UP * 0.6, 0.7, Color(1, 1, 1, 0.85), 0.08)  # the white flash where it hooks
		Mode.HOOKED:
			if not intent.light_held:
				return _end()
			if intent.wheel_back:
				mode = Mode.REEL
			elif intent.heavy:
				mode = Mode.YANK  # right click: rip it toward you into a kick (user, 2026-11-19)
				_time = 0.0
				if player.visual != null:
					player.visual.play_strike("Melee_Unarmed_Attack_Kick", YANK_TIME, YANK_TIME + 0.35)
			elif pitch_rate <= -t.chain_flick_rate:
				mode = Mode.SLAM
				_slam_from = target.global_position
				_time = 0.0
				if player.visual != null:  # the overhead chop lands as the minion hits the ground
					player.visual.play_strike("Melee_2H_Attack_Chop", 0.32, 0.6)
			elif absf(yaw_rate) >= t.chain_swing_rate:
				mode = Mode.SWING
				_swing_dir = signf(yaw_rate)
				var to: Vector3 = target.global_position - player.global_position
				_swing_angle = atan2(to.x, to.z)
				_swing_hit = [target]
				_spin = 0.0
				_swing_turned = 0.0
			elif target is Enemy and _flat_gap(_hold_at) > _length + 0.5:
				mode = Mode.DRAG  # you walked off with it: the chain goes taut
				_drag_tick = 0.0
				var e: Enemy = target
				e.release_grab()
				e.throw((player.global_position - _hold_at).normalized() * 2.0, player)  # it goes limp, off its feet
			else:  # it hangs where it was hooked, falling to the ground
				_vel.y -= GRAVITY * delta
				_hold_at.y = maxf(_hold_at.y + _vel.y * delta, _ground_y(_hold_at))
		Mode.YANK:
			var meet: Vector3 = player.global_position + player.facing * 1.3 + Vector3.UP * 1.0
			var from := _hold_at
			_hold_at = from.lerp(meet, clampf(delta / maxf(YANK_TIME - _time + delta, 0.001), 0.0, 1.0))
			_plow()
			if _time >= YANK_TIME or _hold_at.distance_to(meet) < 0.4:
				var e := target
				_release_target(false)
				_stop()
				if is_instance_valid(e) and not e.is_dead():
					kick(e)
				return false
		Mode.REEL:
			if not intent.light_held:
				return _end()
			_hold_at = _hold_at.move_toward(player.grabber.hold_point(), t.chain_reel_speed * delta)
			_plow()
			if _hold_at.distance_to(player.grabber.hold_point()) < 0.3:
				var e := target
				_release_target(false)
				_stop()
				player._take_into_hand(e)
				return true
		Mode.SLAM:
			var up := 0.18
			if _time < up:  # ripped up fast, slowing at the top as its weight catches up
				var u := _time / up
				_hold_at = _slam_from.lerp(_slam_from + Vector3.UP * t.chain_slam_height, 1.0 - (1.0 - u) * (1.0 - u))
			else:  # then it comes down faster and faster
				var fall := clampf((_time - up) / 0.14, 0.0, 1.0)
				var top := _slam_from + Vector3.UP * t.chain_slam_height
				var land := Vector3(_slam_from.x, _ground_y(_slam_from), _slam_from.z)
				_hold_at = top.lerp(land, fall * fall)
				if fall >= 1.0:
					_slam(land)
					return _end()
		Mode.SWING:
			if not intent.light_held:
				var e := target
				_release_target(true)
				# Wherever you look, up and down too (user, 2026-11-19): aim high to launch it, low to spike it.
				var look := Vector3(-sin(intent.aim_yaw) * cos(intent.aim_pitch), sin(intent.aim_pitch), -cos(intent.aim_yaw) * cos(intent.aim_pitch))
				e.hurl((look * t.hurl_speed + Vector3.UP * t.hurl_lift) * Grabber.THROW_BOOST, player)
				return _end()
			var top := minf(t.chain_swing_spin + t.chain_swing_spin_per_turn * floorf(_swing_turned / TAU), t.chain_swing_spin_max)
			_spin = move_toward(_spin, maxf(absf(yaw_rate), top), t.chain_swing_windup * delta)
			_swing_angle += _swing_dir * _spin * delta
			_swing_turned += _spin * delta  # every full turn it goes faster
			var circle := player.global_position + Vector3(sin(_swing_angle), 0.0, cos(_swing_angle)) * t.chain_swing_radius + Vector3.UP * 1.0
			# The body trails behind where the chain pulls it, as a weight does.
			var swung := _hold_at.lerp(circle, 1.0 - exp(-t.chain_swing_pull * delta))
			var wall := _wall_between(_hold_at, swung)
			if wall.is_empty():
				wall = _wall_between(player.global_position + Vector3.UP * 1.0, swung)
			if not wall.is_empty():
				_wall_slam(wall.position, wall.normal, (swung - _hold_at).normalized())
				return false
			_hold_at = swung
			var fresh: Array = Combat.enemies_in_radius(_hold_at, 1.3, _swing_hit)
			if not fresh.is_empty():
				_swing_hit.append_array(fresh)
				player.hit_targets(fresh, player.moveset._base(player) * t.heavy_multiplier, DamageInfo.Kind.HEAVY, t.knockback_heavy,
					false, t.hitstop_heavy, t.shake_heavy * 0.5, [], _hold_at, "Physical", false, false)
		Mode.DRAG:
			if not intent.light_held:
				return _end()  # it lies there, then gets up
			if intent.wheel_back:  # reel it in off the ground
				_hold_at = target.global_position
				target.grab_by(player)
				mode = Mode.REEL
			else:
				_drag(delta)
		Mode.ANCHOR:
			if not intent.light_held:
				return _end()
			if intent.heavy or intent.wheel_back:  # right click (user, 2026-11-19) or the wheel: in for the drop kick
				mode = Mode.PULL
				_time = 0.0
				player.collision_mask = 0b001  # hauled through the crowd, so nobody stops you short
		Mode.PULL:
			var to: Vector3 = target.global_position - player.global_position
			var gap := Vector2(to.x, to.z).length()  # along the ground: a tall one's middle is no farther
			if not _kick_started and gap <= t.chain_kick_reach + t.chain_pull_speed * KICK_LEAD:
				_kick_started = true
				if player.visual != null:
					player.visual.play_strike("Melee_Unarmed_Attack_Kick", KICK_LEAD, KICK_LEAD + 0.35)
			if gap <= t.chain_kick_reach or (_time > 1.5 and gap <= t.chain_kick_reach * 2.0):  # stopped close by: kick anyway
				mode = Mode.KICK
				_time = 0.0
				_show_line(false)
				player.velocity = Vector3.ZERO
				player.collision_mask = 0b101
				kick(target)
			elif _time > 2.0:
				return _end()  # something's in the way
		Mode.KICK:
			if _time >= 0.35:
				return _end()
		Mode.SLING:
			var land: Vector3 = (target as LedgeAnchor).landing()
			if player.global_position.distance_to(land) < 0.8 or _time > 2.0:
				player.velocity = (land - player.global_position).normalized() * 3.0  # a soft drop onto the top
				return _end()
	_update_line(delta)
	return true


## Your kick (user, 2026-11-19): a heavy hit. A small one is launched; a Large unit or boss only if
## it dies, else it's driven back at pace and stays on its feet.
func kick(e: Node3D) -> void:
	var t: CombatTuning = GameData.tuning
	var big := pulls_you(e)
	player.hit_targets([e], player.moveset._base(player) * player.heavy_mult(), DamageInfo.Kind.HEAVY,
		t.knockback_heavy * 1.5, true, t.hitstop_heavy, t.shake_heavy, ["on_heavy_hit"], e.global_position + Vector3.UP,
		"Physical", false, true, not big)
	Vfx.burst(e.global_position + Vector3.UP, 1.1, Color(1.0, 0.85, 0.4, 0.9), 0.1)
	if not big or not is_instance_valid(e):
		return
	var away := Vector3(e.global_position.x - player.global_position.x, 0.0, e.global_position.z - player.global_position.z)
	away = away.normalized() if away.length() > 0.05 else player.facing
	if e.is_dead():
		e.throw((away * t.launch_speed + Vector3.UP * t.launch_lift) * Enemy.DEATH_LAUNCH, player)
	else:
		e._knock = away * t.chain_kick_push


## While pulling you to a big one: your velocity (the Player's _move uses it). ZERO otherwise.
func pull_velocity() -> Vector3:
	if mode != Mode.PULL or not is_instance_valid(target):
		return Vector3.ZERO
	var to: Vector3 = target.global_position + Vector3.UP * 0.5 - player.global_position
	return to.normalized() * GameData.tuning.chain_pull_speed


## Where a hooked minion is now (Enemy._follow_hand), or INF when it isn't on the chain.
func point_for(e: Node3D) -> Vector3:
	if mode == Mode.SLING and is_instance_valid(target):
		# Up to just over the lip first (sliding up the wall face if you're against it), then in onto the top.
		var lip: Vector3 = target.global_position + Vector3.UP * 1.0
		var goal: Vector3 = lip if player.global_position.y < lip.y - 0.3 else (target as LedgeAnchor).landing()
		return (goal - player.global_position).normalized() * GameData.tuning.sling_speed
	return _hold_at if e == target and mode in [Mode.HOOKED, Mode.REEL, Mode.SLAM, Mode.SWING, Mode.YANK] else Vector3.INF


## Ends it from outside (a dodge, death): a hooked minion drops.
func cancel() -> void:
	if mode != Mode.OFF:
		_end()


## Your free hand, where the chain starts.
func hand() -> Vector3:
	return player.global_position + Vector3.UP * 1.3 + player.facing.cross(Vector3.UP) * -0.3 + player.facing * 0.3


func _flat_gap(at: Vector3) -> float:
	return Vector2(at.x - player.global_position.x, at.z - player.global_position.z).length()


## A limp body on the chain (user, 2026-11-19): it never gets farther from you than the chain that's
## out, so walking away drags it along the ground, and every moment it scrapes along it hurts.
func _drag(delta: float) -> void:
	var t: CombatTuning = GameData.tuning
	var e: Enemy = target
	if not e.thrown:
		e.throw(Vector3.UP, player)  # it got its feet back: down it goes again
	e._throw_time = minf(e._throw_time, 1.0)  # and it doesn't get up while you drag it
	var hips: PhysicsBody3D = _hips()
	var at: Vector3 = hips.global_position if hips != null else e.global_position
	var v: Vector3 = hips.linear_velocity if hips != null else e._throw_vel
	var to := Vector3(player.global_position.x - at.x, 0.0, player.global_position.z - at.z)
	var gap := to.length()
	if gap > _length and gap > 0.01:  # taut: haul it after you
		var dir := to / gap
		var want := (gap - _length) * t.chain_drag_pull
		var along := v.dot(dir)
		if along < want:
			v += dir * (want - along)
		if hips != null:
			hips.linear_velocity = v
		else:
			e._throw_vel = v
	var speed := Vector2(v.x, v.z).length()
	_drag_tick -= delta
	if speed > 1.5 and _drag_tick <= 0.0:
		_drag_tick = 0.25
		Combat.deal(e, DamageInfo.make(player.moveset._base(player) * t.chain_drag_damage * 0.25, "Physical", DamageInfo.Kind.STATUS, player))
		if e.bleeds():
			Vfx.blood_stains(Vector3(at.x, player.global_position.y, at.z), Vector3(v.x, 0.0, v.z), 1, 0.6)


## A dragged body's hips while it's limp, or null.
func _hips() -> PhysicsBody3D:
	var e := target as Enemy
	return e.model.ragdoll_hips() if e != null and e.model != null and e.model.is_ragdoll() else null


func _slam(land: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	var e := target
	_release_target(true)
	if not is_instance_valid(e):
		return
	e.global_position = land
	var near: Array = Combat.enemies_in_radius(land, t.hurl_burst_radius, [e])
	player.hit_targets(([e] if e is Enemy else []) + near, player.moveset._base(player) * t.heavy_multiplier, DamageInfo.Kind.HEAVY, t.knockback_heavy,
		true, t.hitstop_heavy, t.shake_heavy, ["on_heavy_hit"], land, "Physical", false, false)
	if e is Throwable:
		e._shatter()  # an item breaks where it lands
	ElementFx.area("Physical", land, t.hurl_burst_radius)
	if e.bleeds():
		Vfx.blood(land + Vector3.UP * 0.5, Vector3.UP, t.blood_kill_drops)
		Vfx.blood_stains(land, player.facing, t.blood_stains_per_hit * 2, 1.4)


## What you pull in (user, 2026-11-19) knocks down and hurts each enemy in its path, once each,
## as the swing does, and knocks it aside out of the way, not back.
func _plow() -> void:
	var t: CombatTuning = GameData.tuning
	var fresh: Array = Combat.enemies_in_radius(_hold_at, 1.3, _swing_hit)
	if fresh.is_empty():
		return
	_swing_hit.append_array(fresh)
	var pull := Vector3(player.global_position.x - _hold_at.x, 0.0, player.global_position.z - _hold_at.z).normalized()
	var side := pull.cross(Vector3.UP)
	for e in fresh:
		var info := player.make_hit(player.moveset._base(player) * t.heavy_multiplier, "Physical", "Melee", e, DamageInfo.Kind.HEAVY)
		info.knockback = t.chain_plow_knockback
		info.knockdown = true
		info.no_launch = true
		info.knockback_dir = side if (e.global_position - _hold_at).dot(side) >= 0.0 else -side  # out the side it stands on
		info.hitstop = t.hitstop_heavy if e == fresh[0] else 0.0
		info.shake = t.shake_heavy * 0.5 if e == fresh[0] else 0.0
		Combat.deal(e, info)
		if is_instance_valid(e) and not e.is_large:  # it flies off to the side, limp (a big one is only shoved)
			e.throw(info.knockback_dir * t.chain_plow_knockback + Vector3.UP * t.launch_lift, player)


## A wall (not the ground) between `a` and `b`: the ray's hit {position, normal}, or {} if none.
func _wall_between(a: Vector3, b: Vector3) -> Dictionary:
	if a.distance_to(b) < 0.01 or not player.is_inside_tree():
		return {}
	var q := PhysicsRayQueryParameters3D.create(a, b, 0b001)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit if not hit.is_empty() and hit.normal.y < 0.5 else {}


## The swung minion smashes into a wall (user, 2026-11-19): a heavy blow, and it drops limp off the
## wall in a ragdoll, bouncing back toward you.
func _wall_slam(at: Vector3, normal: Vector3, moving: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	var e := target
	_release_target(true)
	_stop()
	if not is_instance_valid(e):
		return
	e.global_position = at + normal * 0.5 - Vector3.UP * 1.0
	if e is Enemy:
		var info := player.make_hit(player.moveset._base(player) * t.heavy_multiplier * WALL_SLAM_DAMAGE, "Physical", "Melee", e, DamageInfo.Kind.HEAVY)
		info.no_launch = true
		info.hitstop = t.hitstop_heavy
		info.shake = t.shake_heavy
		Combat.deal(e, info)
		if e.bleeds():
			Vfx.blood(at, normal, t.blood_kill_drops)
			Vfx.blood_stains(e.global_position, moving, t.blood_stains_per_hit * 2, 1.4)
		e.throw(normal * 4.0 + Vector3.UP * 2.0, player)  # dead or alive, the body goes limp off the wall
		Enemy.bowled_over(Combat.enemies_in_radius(at, 1.5, [e]))
	else:
		e.hurl(moving * 2.0, player)  # an item: it breaks on the wall
	Vfx.burst(at, 1.0, Color(0.9, 0.85, 0.75, 0.9), 0.12)
	Combat.shake(t.shake_heavy)


func _release_target(_flying: bool) -> void:
	if is_instance_valid(target) and target.has_method("release_grab"):
		target.release_grab()


func _end() -> bool:
	if mode in [Mode.HOOKED, Mode.REEL, Mode.SLAM, Mode.SWING, Mode.YANK]:
		_release_target(false)
	_stop()
	return false


func _stop() -> void:
	if mode in [Mode.PULL, Mode.SLING]:
		player.collision_mask = 0b101  # solid to enemies again
	mode = Mode.OFF
	_kick_started = false
	target = null
	_show_line(false)


func _target_point() -> Vector3:
	if mode in [Mode.HOOKED, Mode.REEL, Mode.SLAM, Mode.SWING, Mode.YANK]:
		return _hold_at + Vector3.UP * 1.0
	if mode == Mode.DRAG and _hips() != null:
		return _hips().global_position
	return target.global_position + Vector3.UP * (target.aim_height() if target.has_method("aim_height") else 1.0)


func _ground_y(at: Vector3) -> float:
	var space := player.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 30.0, 0b001))
	return hit.position.y if hit else player.global_position.y


# ---------------------------------------------------------------- the chain you see
# Chunky steel links from hand to hook, each turned a quarter from the last (user, 2026-11-19: the thin
# bar vanished under the retro look's big pixels). Swap in a link model when the user makes one.
const LINK_SPACING := 0.1   ## m from one link to the next
const LINK_WIDTH := 0.05    ## the ring's outer radius, m (user, 2026-11-19: thinner)

func _show_line(on: bool) -> void:
	if on and _line == null and player.is_inside_tree():
		var link := TorusMesh.new()
		link.outer_radius = LINK_WIDTH
		link.inner_radius = LINK_WIDTH * 0.55
		link.rings = 12
		link.ring_segments = 6
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color(0.78, 0.8, 0.86)
		steel.metallic = 0.7
		steel.roughness = 0.35
		steel.emission_enabled = true  # a faint glow so it reads against dark ground and fog
		steel.emission = Color(0.35, 0.37, 0.42)
		link.material = steel
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = link
		mm.instance_count = ceili((GameData.tuning.chain_range + 8.0) / LINK_SPACING)
		mm.visible_instance_count = 0
		_line = MultiMeshInstance3D.new()
		_line.multimesh = mm
		_line.top_level = true
		_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		player.add_child(_line)
	if _line != null:
		_line.visible = on
	if on:
		_rope.resize(ROPE_NODES)
		_rope.fill(hand())  # it uncoils from your hand
		_rope_prev = _rope.duplicate()
		_update_line()


# The chain's shape (user, 2026-11-19: make it feel like a real, heavy chain): a row of points that
# keep their speed from frame to frame and fall under gravity, held no farther apart than one
# stretch of chain. Both ends are pinned, to your hand and the hook, so it sags when slack and
# whips and trails when you or what's on it move fast.
const ROPE_NODES := 20
var _rope := PackedVector3Array()
var _rope_prev := PackedVector3Array()


func _step_rope(a: Vector3, b: Vector3, delta: float) -> void:
	var n := _rope.size()
	var slack := 1.0 if mode in [Mode.FLYING, Mode.DRAG] else GameData.tuning.chain_slack  # flying out or dragging it's pulled straight
	var seg := a.distance_to(b) * slack / (n - 1)
	var floor_y := player.global_position.y + LINK_WIDTH  # it lies on the ground, not through it
	for i in range(1, n - 1):
		var now := _rope[i]
		_rope[i] = now + (now - _rope_prev[i]) * 0.98 + Vector3.DOWN * GRAVITY * delta * delta
		_rope_prev[i] = now
	_rope[0] = a
	_rope[n - 1] = b
	for _pass in 10:
		for i in n - 1:
			var d := _rope[i + 1] - _rope[i]
			var l := d.length()
			if l <= seg:
				continue  # a chain goes slack, it doesn't push
			var fix := d * (1.0 - seg / l)
			if i == 0:
				_rope[i + 1] -= fix
			elif i + 1 == n - 1:
				_rope[i] += fix
			else:
				_rope[i] += fix * 0.5
				_rope[i + 1] -= fix * 0.5
		for i in range(1, n - 1):
			_rope[i].y = maxf(_rope[i].y, floor_y)


func _update_line(delta := 0.0) -> void:
	# Not `not _line.visible`: the chain hides itself on its first frame (length 0, still in your hand),
	# and skipping hidden chains kept it hidden for good.
	if _line == null or mode == Mode.OFF or not is_instance_valid(target) or _rope.size() < 2:
		return
	var a := hand()
	var b := _target_point()
	if mode == Mode.FLYING:
		b = a.lerp(b, clampf(_time * GameData.tuning.chain_speed / maxf(a.distance_to(b), 0.01), 0.0, 1.0))
	if a.distance_to(b) < 0.05:
		_line.visible = false
		return
	_step_rope(a, b, delta)
	_line.visible = true
	_line.global_transform = Transform3D.IDENTITY
	var mm := _line.multimesh
	var flat := Basis(Vector3.BACK, 0.0)
	var turned := Basis(Vector3.BACK, PI * 0.5)
	var count := 0
	var next := LINK_SPACING * 0.5  # how far into this stretch the next link sits
	for i in _rope.size() - 1:
		var d := _rope[i + 1] - _rope[i]
		var l := d.length()
		if l < 0.0001:
			next -= l
			continue
		var dir := d / l
		var along := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
		while next < l and count < mm.instance_count:
			# The torus's ring lies in its XZ plane, so the chain (local Z) runs along it; stretched along Z
			# into an oval link, every other link turned a quarter about the chain.
			var ring := along * (turned if count % 2 == 1 else flat) * Basis.from_scale(Vector3(1.0, 1.0, 1.6))
			mm.set_instance_transform(count, Transform3D(ring, _rope[i] + dir * next))
			count += 1
			next += LINK_SPACING
		next -= l
	mm.visible_instance_count = count
