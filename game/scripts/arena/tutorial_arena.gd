class_name TutorialArena
extends EndlessArena
## The tutorial (user, 2026-11-20): the arena with no waves. A prompt teaches one move at a time,
## every chain attack, the hand grab and hurl, and picking up and throwing a weapon, and goes on
## the moment you do it. Two skeletons stand by to practise on (a cyclops for the drop kick); you
## can't be hurt. When it's done, a button takes you to the waves.

const SCENE := "res://scenes/tutorial_arena.tscn"
const ENDLESS_SCENE := "res://scenes/endless_arena.tscn"
## Skeletons kept standing to practise on.
const FOES := 2

## The lessons in order: the prompt ({light}, {heavy} and {throw} become your keys), the check
## that it's done (`seen` holds the chain moves made since the lesson began), and what it puts
## out to practise on ("cyclops", "weapon" or nothing).
var steps: Array = [
	["Chain: aim at a skeleton out of reach and hold {light}. The chain hooks it.",
		func(seen: Dictionary) -> bool: return seen.has(Chain.Mode.HOOKED)],
	["Reel: with one hooked, keep holding {light} and scroll the wheel back. It comes into your hand.",
		func(seen: Dictionary) -> bool: return seen.has(Chain.Mode.REEL)],
	["Hurl: with one in your hand, press {heavy} to throw it where you look.",
		func(_seen: Dictionary) -> bool: return player.grabber.throwing()],
	["Kick: hook one and press {heavy}. The chain rips it into your kick.",
		func(seen: Dictionary) -> bool: return seen.has(Chain.Mode.YANK)],
	["Slam: hook one and flick the mouse down. It's lifted and slammed into the ground.",
		func(seen: Dictionary) -> bool: return seen.has(Chain.Mode.SLAM)],
	["Swing: hook one and sweep the mouse sideways. It hits all it sweeps; let go of {light} to fling it.",
		func(seen: Dictionary) -> bool: return seen.has(Chain.Mode.SWING)],
	["Drag: hook one and walk away from it. The chain goes taut and drags it along the ground.",
		func(seen: Dictionary) -> bool: return seen.has(Chain.Mode.DRAG)],
	["Drop kick: a cyclops is too big to pull. Hook it and press {heavy}: the chain hauls you in for a kick.",
		func(seen: Dictionary) -> bool: return seen.has(Chain.Mode.PULL) or seen.has(Chain.Mode.KICK), "cyclops"],
	["Weapons: walk over the glowing weapon to take it up.",
		func(_seen: Dictionary) -> bool: return player.weapon_id != GameData.FISTS, "weapon"],
	["Throw: hold {throw} to wind up (longer is harder), let go to throw it through them.",
		func(_seen: Dictionary) -> bool: return player.weapon_id == GameData.FISTS],
	["A thrown weapon lies where it lands. Go and take it back.",
		func(_seen: Dictionary) -> bool: return player.weapon_id != GameData.FISTS],
]
var step := -1  ## the lesson now (-1: not begun; steps.size(): all done)
var _seen := {}
var _foes: Array = []
var _cyclops: Enemy


## The endless arena's setup without its loadout menu, and no waves.
func _begin() -> void:
	var picked := loadout_picked
	loadout_picked = true
	super()
	loadout_picked = picked


func _queue_wave(_index: int) -> void:
	pass


func _start_fight() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	start_tutorial()


func start_tutorial() -> void:
	player.god_mode = true  # a place to learn: nothing hurts you
	_go_to(0)


func _go_to(index: int) -> void:
	step = index
	_seen.clear()
	if step >= steps.size():
		hud.show_message("Tutorial done. You know the chain and your weapons.", 0.0)
		hud.show_action("Fight the waves", func(): get_tree().change_scene_to_file(ENDLESS_SCENE))
		return
	var keys := {"light": Controls.binding_text("attack_light"), "heavy": Controls.binding_text("attack_heavy"),
		"throw": Controls.binding_text("throw_weapon")}
	hud.show_message("%d/%d  %s" % [step + 1, steps.size(), (steps[step][0] as String).format(keys)], 0.0)
	var puts: String = steps[step][2] if steps[step].size() > 2 else ""
	if puts == "cyclops" and not is_instance_valid(_cyclops):
		_cyclops = waves.spawn(WaveDirector.LARGE_UNIT, player.global_position)
	if puts == "weapon" and player.weapon_id == GameData.FISTS:
		var at := player.global_position + player.facing * 4.0
		WeaponPickup.make(GameData.pickup_weapons()[0], self, at + Vector3.UP)


func _physics_process(_delta: float) -> void:
	if step < 0 or step >= steps.size():
		return
	_foes = _foes.filter(func(e): return is_instance_valid(e) and not e.is_dead())
	for i in FOES - _foes.size():
		_foes.append(waves.spawn(WaveDirector.BASIC_UNIT, player.global_position))
	if player.chain.active():
		_seen[player.chain.mode] = true
	if (steps[step][1] as Callable).call(_seen):
		Vfx.burst(player.global_position + Vector3.UP, 1.2, Color(1.0, 0.85, 0.5, 0.8), 0.25)
		_go_to(step + 1)
