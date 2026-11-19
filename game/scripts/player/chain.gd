class_name Chain
extends RefCounted
## The chain grab (combat feel plan, user 2026-11-18, from their fifth reel). The same held light
## attack as the hand grab: with no minion in reach but a target in the crosshair within
## chain_range, a chain shoots from your free hand and hooks it, even mid-air. No cooldown.
## With a minion hooked, still holding light attack:
##   - scroll the wheel back: reel it in to your hand (then it's the hand grab: crush or hurl);
##   - flick the mouse down: yank it up and slam it down, a burst where it lands;
##   - sweep the mouse sideways: swing it around you, hitting all it sweeps; let go to fling it;
##   - let go without swinging: the chain lets go and it drops.
## On a Large unit or boss the chain pulls you to it instead, and you land a drop kick (a heavy).

enum Mode { OFF, FLYING, HOOKED, REEL, SLAM, SWING, PULL, KICK, YANK }
const YANK_TIME := 0.22  ## s for a yanked minion to fly into your blow
const YANK_DAMAGE := 1.6  ## the yank's blow x a heavy hit
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
	for e in pool:
		if not is_instance_valid(e) or e.is_dead() or (e is Enemy and (e.civilian or e.held_by != null)):
			continue
		var to: Vector3 = e.global_position + Vector3.UP * e.aim_height() - eye
		if to.length() > t.chain_range:
			continue
		var angle := aim.angle_to(to)
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
				if pulls_you(target):
					mode = Mode.PULL
				else:
					mode = Mode.HOOKED
					_hold_at = target.global_position
					target.grab_by(player)
					Vfx.sparks(_target_point(), hand() - _target_point(), 6)
				Vfx.burst(_target_point() - Vector3.UP * 0.6, 0.7, Color(1, 1, 1, 0.85), 0.08)  # the white flash where it hooks
		Mode.HOOKED:
			if not intent.light_held:
				return _end()
			if intent.wheel_back:
				mode = Mode.REEL
			elif intent.heavy:
				mode = Mode.YANK  # right click: rip it toward you into a heavy blow (arena tactics, 2026-11-19)
				_time = 0.0
				if player.visual != null:
					player.visual.play_strike("Melee_2H_Attack_Chop", YANK_TIME, YANK_TIME + 0.35)
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
			else:  # it hangs where it was hooked, sinking to the ground
				var ground := _ground_y(_hold_at)
				_hold_at.y = move_toward(_hold_at.y, ground, 6.0 * delta)
		Mode.YANK:
			var meet: Vector3 = player.global_position + player.facing * 1.3 + Vector3.UP * 1.0
			var from := _hold_at
			_hold_at = from.lerp(meet, clampf(delta / maxf(YANK_TIME - _time + delta, 0.001), 0.0, 1.0))
			if _time >= YANK_TIME or _hold_at.distance_to(meet) < 0.4:
				var e := target
				_release_target(false)
				_stop()
				if is_instance_valid(e) and not e.is_dead():
					player.hit_targets([e], player.moveset._base(player) * player.heavy_mult() * YANK_DAMAGE, DamageInfo.Kind.HEAVY,
						t.knockback_heavy * 1.5, false, t.hitstop_heavy, t.shake_heavy, ["on_heavy_hit"], e.global_position + Vector3.UP)
					Vfx.burst(e.global_position + Vector3.UP, 1.1, Color(1.0, 0.85, 0.4, 0.9), 0.1)
				return false
		Mode.REEL:
			if not intent.light_held:
				return _end()
			_hold_at = _hold_at.move_toward(player.grabber.hold_point(), t.chain_reel_speed * delta)
			if _hold_at.distance_to(player.grabber.hold_point()) < 0.3:
				var e := target
				_release_target(false)
				_stop()
				player._take_into_hand(e)
				return true
		Mode.SLAM:
			var up := 0.18
			if _time < up:
				_hold_at = _slam_from.lerp(_slam_from + Vector3.UP * t.chain_slam_height, _time / up)
			else:
				var fall := clampf((_time - up) / 0.14, 0.0, 1.0)
				var top := _slam_from + Vector3.UP * t.chain_slam_height
				var land := Vector3(_slam_from.x, _ground_y(_slam_from), _slam_from.z)
				_hold_at = top.lerp(land, fall)
				if fall >= 1.0:
					_slam(land)
					return _end()
		Mode.SWING:
			if not intent.light_held:
				var e := target
				_release_target(true)
				var look := Vector3(-sin(intent.aim_yaw), 0.0, -cos(intent.aim_yaw))
				e.hurl((look * t.hurl_speed + Vector3.UP * t.hurl_lift) * Grabber.THROW_BOOST, player)
				return _end()
			_swing_angle += _swing_dir * maxf(absf(yaw_rate), t.chain_swing_spin) * delta
			var swung := player.global_position + Vector3(sin(_swing_angle), 0.0, cos(_swing_angle)) * t.chain_swing_radius + Vector3.UP * 1.0
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
		Mode.PULL:
			var to: Vector3 = target.global_position - player.global_position
			if not _kick_started and to.length() <= t.chain_kick_reach + t.chain_pull_speed * KICK_LEAD:
				_kick_started = true
				if player.visual != null:
					player.visual.play_strike("Melee_Unarmed_Attack_Kick", KICK_LEAD, KICK_LEAD + 0.35)
			if to.length() <= t.chain_kick_reach:
				mode = Mode.KICK
				_time = 0.0
				_show_line(false)
				player.velocity = Vector3.ZERO
				player.hit_targets([target], player.moveset._base(player) * player.heavy_mult(), DamageInfo.Kind.HEAVY,
					t.knockback_heavy, true, t.hitstop_heavy, t.shake_heavy, ["on_heavy_hit"], target.global_position + Vector3.UP)
			elif _time > 2.0:
				return _end()  # something's in the way
		Mode.KICK:
			if _time >= 0.35:
				return _end()
	_update_line()
	return true


## While pulling you to a big one: your velocity (the Player's _move uses it). ZERO otherwise.
func pull_velocity() -> Vector3:
	if mode != Mode.PULL or not is_instance_valid(target):
		return Vector3.ZERO
	var to: Vector3 = target.global_position + Vector3.UP * 0.5 - player.global_position
	return to.normalized() * GameData.tuning.chain_pull_speed


## Where a hooked minion is now (Enemy._follow_hand), or INF when it isn't on the chain.
func point_for(e: Node3D) -> Vector3:
	return _hold_at if e == target and mode in [Mode.HOOKED, Mode.REEL, Mode.SLAM, Mode.SWING, Mode.YANK] else Vector3.INF


## Ends it from outside (a dodge, death): a hooked minion drops.
func cancel() -> void:
	if mode != Mode.OFF:
		_end()


## Your free hand, where the chain starts.
func hand() -> Vector3:
	return player.global_position + Vector3.UP * 1.3 + player.facing.cross(Vector3.UP) * -0.3 + player.facing * 0.3


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
	mode = Mode.OFF
	_kick_started = false
	target = null
	_show_line(false)


func _target_point() -> Vector3:
	if mode in [Mode.HOOKED, Mode.REEL, Mode.SLAM, Mode.SWING, Mode.YANK]:
		return _hold_at + Vector3.UP * 1.0
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
		_update_line()


func _update_line() -> void:
	# Not `not _line.visible`: the chain hides itself on its first frame (length 0, still in your hand),
	# and skipping hidden chains kept it hidden for good.
	if _line == null or mode == Mode.OFF or not is_instance_valid(target):
		return
	var a := hand()
	var b := _target_point()
	if mode == Mode.FLYING:
		b = a.lerp(b, clampf(_time * GameData.tuning.chain_speed / maxf(a.distance_to(b), 0.01), 0.0, 1.0))
	var length := a.distance_to(b)
	if length < 0.05:
		_line.visible = false
		return
	_line.visible = true
	_line.global_transform = Transform3D.IDENTITY
	var dir := (b - a) / length
	var along := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	var mm := _line.multimesh
	var count := mini(ceili(length / LINK_SPACING), mm.instance_count)
	var flat := Basis(Vector3.BACK, 0.0)
	var turned := Basis(Vector3.BACK, PI * 0.5)
	for i in count:
		# The torus's ring lies in its XZ plane, so the chain (local Z) runs along it; stretched along Z
		# into an oval link, every other link turned a quarter about the chain.
		var ring := along * (turned if i % 2 == 1 else flat) * Basis.from_scale(Vector3(1.0, 1.0, 1.6))
		mm.set_instance_transform(i, Transform3D(ring, a + dir * (i + 0.5) * minf(LINK_SPACING, length / count)))
	mm.visible_instance_count = count
