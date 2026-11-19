class_name Mount
extends Node3D
## The player's mount (Mounts sheet: one per race). Press X to call it and ride;
## press X again (or dodge) to get off.
##   - Riding uses the sheet's speed_mps / sprint_mps instead of your running speed.
##   - Sprinting into enemies tramples them for charge_damage and knocks them down;
##     after a full gallop of mount_throw_after seconds (user, 2026-11-05: so battles
##     aren't just launching enemies) they're thrown back (Enemy.throw: limp, hurt by what they hit).
##   - Just before it reaches someone it plays its attack (mount_butt_lead), so the head
##     comes down as they're hit.
##   - Space jumps (mount_jump_velocity): at a gallop you clear narrow river stretches.
##   - In deep water the mount swims with you (slowly).
##   - You can still swing your weapon (light and heavy) and use abilities; no slide.
##   - Hits land on the mount first (its hp from the sheet). If it drops to 0 you're
##     thrown off, and it needs THROWN_COOLDOWN seconds before you can call it again.
## Races without a mount model (the centaur) just gallop: the speed and charge, no model.
##
## On foot in the valley your mount walks with you and fights beside you (user,
## 2026-10-29): a FRIENDLY unit (Enemy.setup_companion) that follows you, butts
## the nearest enemy for half its charge_damage, and shares the mount's health.
## Riding puts it away; if it falls you can't ride or call it for THROWN_COOLDOWN.

## Seconds before a thrown-off mount can be called again.
const THROWN_COOLDOWN := 25.0
var _gallop_time := 0.0  ## how long you've been at a full gallop without slowing
## Mount health back per second while you're on foot (it walking beside you or not).
const REGEN := 4.0
## Trampling: who's in front of you within this range, and how often one enemy can be hit.
const TRAMPLE_RANGE := 2.2
const TRAMPLE_REPEAT := 0.8
## The camera pulls back while riding.
const CAMERA_DISTANCE := 8.5
## A dead mount lies this long before it sinks away.
const CORPSE_SECONDS := 4.0
## A companion farther than this from you (you rode off, fast travel) catches up at once.
const COMPANION_LEASH := 60.0

var companion: Enemy

var player: Player
var data: Dictionary
var riding := false
## Orders on foot (user, 2026-11-16, after Far Cry Primal); a tap of the mount key calls it back:
##   - hold the mount key: it leaves, out of sight (away);
##   - through the spyglass, tap the mount key on an enemy: it goes for that one (mark, shown
##     by a gold arrow over it); anywhere else: it goes there and waits out of fights (staying, spot).
var staying := false
var spot := Vector3.INF  ## where a staying mount waits (INF: where it stopped)
var away := false
var mark: Enemy
## Your mount fades this much when it's between the camera and you or what you aim at.
const FADE := 0.7
var _fade := 0.0
var _size := -1.0  ## the walking mount's rough radius (m), measured once
var hp := 0.0
var max_hp := 0.0
var cooldown := 0.0
var beast: BeastModel
var _look: Dictionary
var _trampled := {}  # enemy instance id -> time left before it can be trampled again
var _butt_left := 0.0  # the attack is playing this much longer (no running clip until then)


func _ready() -> void:
	player = get_parent() as Player
	refresh()


## Reads the race's mount (call again after changing race).
func refresh() -> void:
	var rows: Array = GameData.where("mounts", "race_id", player.race_id)
	data = rows[0] if not rows.is_empty() else {}
	max_hp = GameData.num(data, "hp", 0.0) * GameData.tuning.mount_health_mult
	hp = max_hp
	_look = ModelRegistry.for_mount(data)


func has_mount() -> bool:
	return not data.is_empty()


func can_ride() -> bool:
	return has_mount() and cooldown <= 0.0 and not player.is_dead() and not player.flying and not player.no_mount


## Gets on or off.
func toggle() -> void:
	if riding:
		dismount()
	elif can_ride() and player.is_on_floor():
		ride()


func ride() -> void:
	riding = true
	_clear_orders()
	_put_away_companion()
	if not _look.is_empty():
		beast = BeastModel.new()
		add_child(beast)
		if not beast.setup_beast(_look.model, _look.scale, Color(0, 0, 0, 0), float(_look.get("lift", 0.0))):
			beast.queue_free()
			beast = null
	if beast != null:
		beast.set_god_colors(str(_look.model).get_file().get_basename(), player.god_id)
	if player.visual != null:
		# The rider's posed hips stay on the saddle (CharacterModel.set_seat).
		player.visual.position = Vector3(0.0, 0.0, 0.1) if beast != null else Vector3.ZERO
		player.visual.set_seat(float(_look.get("saddle", 0.0)) if beast != null else -1.0)
	_camera(CAMERA_DISTANCE)


## `why`, if given, is shown and goes to the playtest log (playtest 2026-11-08: "still gets
## taken off", and nothing said whether the mount fell or a dodge did it).
func dismount(why := "") -> void:
	if riding and why != "":
		Playtest.note_event("off your mount: " + why)
		var hud = player.get_parent().get("hud") if player.is_inside_tree() else null
		if hud != null:
			hud.show_message(why, 3.0)
	riding = false
	if beast != null:
		beast.queue_free()
		beast = null
	if player.visual != null:
		player.visual.set_seat(-1.0)
		player.visual.position = Vector3.ZERO
	_camera(-1.0)


## The mount falls limp where it died, carried on by its speed, then sinks away.
func _drop_dead_beast(speed: Vector3) -> void:
	if beast == null or not player.is_inside_tree():
		return
	var body := beast
	beast = null
	body.reparent(player.get_parent())
	body.set_tint(Color(0.1, 0.1, 0.1, 0.25))
	if body.ragdoll(Vector3(speed.x, 0.0, speed.z) * 0.8 + Vector3.UP * 2.0):
		var tw := body.create_tween()
		tw.tween_interval(CORPSE_SECONDS)
		tw.tween_callback(body.sink_ragdoll)
		tw.tween_interval(0.9)
		tw.tween_callback(body.queue_free)
	else:  # no skeleton, or too many limp bodies already: its death animation
		body.play("Death_A", 0.8, true)
		var tw := body.create_tween()
		tw.tween_interval(CORPSE_SECONDS)
		tw.tween_callback(body.queue_free)


## Its own jump, double jump and charge force (Mounts sheet: jump_mps, double_jump, attack_force).
func jump_speed() -> float:
	return GameData.num(data, "jump_mps", GameData.tuning.mount_jump_velocity)


func double_jump() -> bool:
	return GameData.text(data, "double_jump") == "Yes"


func attack_force() -> float:
	return GameData.num(data, "attack_force", 14.0)


## How high the rider sits (m above the ground), 0 without a mount model.
func seat_height() -> float:
	return float(_look.get("saddle", 0.0)) if beast != null else 0.0


## Speed while riding: the sheet's speeds x mount_speed_scale (tuning), before
## the player's own speed bonuses.
func speed(sprinting: bool) -> float:
	return GameData.num(data, "sprint_mps" if sprinting else "speed_mps", 12.0) * GameData.tuning.mount_speed_scale


## A hit while riding lands on the mount. Returns the damage it soaked.
func absorb(amount: float) -> float:
	if max_hp <= 0.0:
		return 0.0
	hp -= amount
	if beast != null:
		beast.set_tint(Color(1, 0.3, 0.3, 0.5))
		create_tween().tween_method(beast.set_tint, Color(1, 0.3, 0.3, 0.5), Color(1, 0.3, 0.3, 0.0), 0.2)
	if hp <= 0.0:
		hp = 0.0
		cooldown = THROWN_COOLDOWN
		var speed := player.velocity
		_drop_dead_beast(speed)
		dismount("Your mount took too many hits and threw you. It can carry you again in %d s." % int(THROWN_COOLDOWN))
		player.throw_off(Vector3(speed.x, 0.0, speed.z) * 0.6 + Vector3.UP * 4.0)  # flung off, limp
	return amount


func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if not riding:
		_update_companion()
		if companion != null:  # it heals walking beside you too, or a hurt mount never does
			companion.health.heal(clampf(max_hp - companion.health.hp, 0.0, REGEN * delta))
			hp = companion.health.hp
		else:
			hp = minf(max_hp, hp + REGEN * delta)
		return
	var moving := Vector2(player.velocity.x, player.velocity.z).length()
	_gallop_time = _gallop_time + delta if moving >= speed(true) * 0.85 else 0.0
	_butt_left = maxf(0.0, _butt_left - delta)
	if beast != null:
		if not player.is_on_floor() and not player.swimming:
			beast.play("Jump_Idle")
		elif player.swimming:
			beast.play("Walking_A")
		elif _butt_left <= 0.0:
			beast.play("Running_A" if moving > speed(false) * 0.8 else ("Walking_A" if moving > 0.5 else "Idle_A"))
	if player.visual != null and player.state == Player.State.FREE:
		if beast != null:
			player.visual.play("Crouching")  # knees bent: the closest pose to riding in the animation set
		else:  # the centaur gallops on its own (horse) legs
			player.visual.play("Running_A" if moving > speed(false) * 0.8 else ("Walking_A" if moving > 0.5 else "Idle_A"))
	for id in _trampled.keys():
		_trampled[id] -= delta
		if _trampled[id] <= 0.0:
			_trampled.erase(id)
	if moving > speed(false) * 0.9 and not player.swimming:
		_headbutt(moving)
		_trample()


## Someone straight ahead, about to be hit: the mount attacks now, so its head is
## down at the moment of the hit. A model with no attack clip (the rat) keeps running.
func _headbutt(moving: float) -> void:
	if beast == null or _butt_left > 0.0 or not player.is_on_floor():
		return
	var t: CombatTuning = GameData.tuning
	for e in player.enemies_in_arc(TRAMPLE_RANGE + moving * t.mount_butt_lead, 30.0):
		if not _trampled.has(e.get_instance_id()):
			_butt_left = t.mount_butt_time
			beast.play("Melee_1H_Attack_Chop", _butt_left, true)
			return


## Sprinting into enemies: charge damage, knockdown, and a heavy knockback.
func _trample() -> void:
	Breakable.smash_near(get_tree(), player.global_position + player.facing * TRAMPLE_RANGE * 0.6, TRAMPLE_RANGE * 0.6, player.global_position)
	for e in player.enemies_in_arc(TRAMPLE_RANGE, 50.0):
		if _trampled.has(e.get_instance_id()):
			continue
		_trampled[e.get_instance_id()] = TRAMPLE_REPEAT
		var info := player.make_hit(GameData.num(data, "charge_damage", 25.0), "Physical", "Melee", e, DamageInfo.Kind.HEAVY)
		info.knockback = attack_force()
		info.knockback_dir = (e.global_position - player.global_position).normalized()
		info.knockdown = true
		info.hitstop = 0.03
		info.no_launch = true  # a trample knocks down; only a long full gallop throws (below)
		Combat.deal(e, info)
		var t: CombatTuning = GameData.tuning
		if Vector2(player.velocity.x, player.velocity.z).length() >= speed(true) * 0.85 and _gallop_time >= t.mount_throw_after:
			e.throw(info.knockback_dir * t.mount_throw_speed * attack_force() / 14.0 + Vector3.UP * t.mount_throw_lift, player)


# ---------------------------------------------------------------- walking beside you

## Only in the valley (the practice arena and tests keep the old way), with a model to show.
func _wants_companion() -> bool:
	return has_mount() and not _look.is_empty() and cooldown <= 0.0 and not player.is_dead() \
		and player.is_inside_tree() and player.get_parent() is Valley and hp > 0.0 and not away


func _update_companion() -> void:
	if player.flying or player.no_mount or player.get_parent().get("cinematic") == true:  # god mode: no mount (user, 2026-11-01); it waits outside caves and towers; not in a clip
		_put_away_companion()
		return
	if companion != null and (not is_instance_valid(companion) or companion.is_dead()):
		companion = null
		hp = 0.0
		cooldown = THROWN_COOLDOWN  # it fell: give it time to recover
		return
	if companion == null:
		if _wants_companion():
			_call_companion()
		return
	hp = companion.health.hp
	_fade_if_in_the_way()
	if not staying and not has_mark() and companion.global_position.distance_to(player.global_position) > COMPANION_LEASH:
		companion.global_position = player.global_position + beside_you() + Vector3.UP * 0.5


## Hold the mount key: it leaves until a tap calls it back.
func send_away() -> void:
	if riding:
		return
	_put_away_companion()
	away = true
	_say("Your mount leaves. Tap %s to call it back." % Controls.binding_text("mount"))


## The mount key tapped through the spyglass: go for `target` if it's someone to fight, else go to `at` and wait.
func order(target: Node3D, at: Vector3) -> void:
	if riding or companion == null:
		return
	if target is Enemy and target.team != Enemy.Team.FRIENDLY and not target.civilian and not target.is_dead():
		_clear_orders()
		_set_mark(target)
		_say("Your mount goes for the %s." % GameData.text(target.unit, "display_name", "enemy"))
	elif at != Vector3.INF:
		_clear_orders()
		staying = true
		spot = at
		_say("Your mount goes there and waits. Tap %s to call it back." % Controls.binding_text("mount"))


## True while it has an order (left, waiting, or after a marked enemy): a tap calls it back.
func has_orders() -> bool:
	return away or staying or has_mark()


func has_mark() -> bool:
	return is_instance_valid(mark) and not mark.is_dead()


## A tap after an order: it comes back to your side.
func come_back() -> void:
	_clear_orders()
	_say("Your mount comes back to you.")


func _clear_orders() -> void:
	staying = false
	away = false
	spot = Vector3.INF
	_set_mark(null)


## The gold arrow over the enemy your mount goes for.
func _set_mark(e: Enemy) -> void:
	if is_instance_valid(mark) and mark.has_node("MountMark"):
		mark.get_node("MountMark").queue_free()
	mark = e
	if e == null:
		return
	var tag := Label3D.new()
	tag.name = "MountMark"
	tag.text = "▼"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 64
	tag.outline_size = 10
	tag.modulate = Color(1.0, 0.8, 0.2)
	tag.position.y = e.aim_height() * 2.0 + 1.0
	e.add_child(tag)


func _say(text: String) -> void:
	var hud = player.get_parent().get("hud") if player.is_inside_tree() else null
	if hud != null:
		hud.show_message(text, 2.0)


## Fades the walking mount when it's between the camera and you, or what you're looking at.
func _fade_if_in_the_way() -> void:
	var cam := player.get_viewport().get_camera_3d() if player.is_inside_tree() else null
	if cam == null or companion.model == null:
		return
	if _size < 0.0:
		var box := AABB()
		for m: MeshInstance3D in companion.model.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = m.global_transform * m.get_aabb()
			box = b if box.size == Vector3.ZERO else box.merge(b)
		_size = maxf(box.size.x, box.size.z) * 0.4 + 0.3
	var eye := cam.global_position
	var me := player.global_position + Vector3.UP * 1.2
	var ahead := me + -cam.global_transform.basis.z * 12.0
	var body := companion.global_position + Vector3.UP * minf(_size, 1.5)
	var blocking := in_the_way(body, eye, me, _size) or in_the_way(body, eye, ahead, _size)
	_fade = move_toward(_fade, FADE if blocking else 0.0, get_physics_process_delta_time() * 4.0)
	for m: MeshInstance3D in companion.model.find_children("*", "MeshInstance3D", true, false):
		m.transparency = _fade


## True if a body of radius `radius` at `p` is on the line of sight from `eye` to `to`.
static func in_the_way(p: Vector3, eye: Vector3, to: Vector3, radius: float) -> bool:
	var q := Geometry3D.get_closest_point_to_segment(p, eye, to)
	return q.distance_to(p) < radius and q.distance_to(to) > 0.5


## Where your mount walks, relative to you: to your right, a little behind.
func beside_you() -> Vector3:
	var f := player.facing
	return Vector3(-f.z, 0.0, f.x) * GameData.tuning.mount_follow_gap - f


func _call_companion() -> void:
	var arena: Node = player.get_parent()
	companion = Enemy.new()
	companion.setup_companion(data, _look, player, arena.get("director"))
	arena.add_child(companion)
	companion.global_position = player.global_position + beside_you() + Vector3.UP * 0.5
	companion.health.max_hp = max_hp  # the sheet's hp x mount_health_mult, as when riding: else a whole mount looked half hurt (blood)
	companion.health.hp = hp
	if companion.model != null:
		companion.model.set_god_colors(str(_look.model).get_file().get_basename(), player.god_id)


func _put_away_companion() -> void:
	staying = false
	_fade = 0.0
	_size = -1.0
	if companion != null and is_instance_valid(companion):
		hp = companion.health.hp
		companion.queue_free()
	companion = null


func _camera(distance: float) -> void:
	var rig = Combat.camera_rig
	if rig == null or not is_instance_valid(rig) or rig.get("_arm") == null or rig.first_person:
		return
	rig._arm.spring_length = distance if distance > 0.0 else rig.distance
