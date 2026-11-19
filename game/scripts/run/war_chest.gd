class_name WarChest
extends Node
## The war chest (user, 2026-11-05): supplies gathered in the run buy help for the final
## battle (Esc menu, "War chest"). What's bought is kept in the run (RunState.flags.war_chest)
## and only shows up in the final battle:
##   catapult  a siege engine behind your line that hurls stones into his army
##   meteors   your god's intervention: meteors rain on his army as the lines clash
##   champion  a giant warrior of your people fights beside you
##   veterans  ten more of your tribe's warriors
## As a Node in the Valley it runs the catapults and meteors during the battle.
## shortcut: prices live here, not in the spreadsheet; move them there if you want to tune them in Excel.

const ITEMS := {
	"catapult": {"name": "Siege engine: catapult", "text": "Hurls stones into Count Fuckula's lines.", "cost": 60, "max": 3},
	"meteors": {"name": "God's intervention: meteors", "text": "Your god rains meteors on his army as the lines clash.", "cost": 90, "max": 2},
	"champion": {"name": "Special unit: champion", "text": "A giant warrior of your people fights beside you.", "cost": 75, "max": 2},
	"veterans": {"name": "Veterans", "text": "Ten more of your tribe's warriors in your line.", "cost": 40, "max": 3},
}
const VETERANS_EACH := 10

var valley: Node  ## the Valley scene
var engines: Array = []  ## [{node: Node3D, left: float}]


static func owned(state: RunState, id: String) -> int:
	return int(state.flags.get("war_chest", {}).get(id, 0))


## Buys one of `id` with supplies. False if you can't afford it or have the most allowed.
static func buy(state: RunState, id: String) -> bool:
	var item: Dictionary = ITEMS.get(id, {})
	if item.is_empty() or state.supplies < int(item.cost) or owned(state, id) >= int(item.max):
		return false
	state.supplies -= int(item.cost)
	var chest: Dictionary = state.flags.get("war_chest", {})
	chest[id] = owned(state, id) + 1
	state.flags["war_chest"] = chest
	return true


## The final battle starts: extra troops into `helpers`, catapults behind the line at `behind`
## (facing `front`, toward the enemy).
func muster(helpers: Array, behind: Vector3, front: Vector3) -> void:
	var s: RunState = Run.state
	var army: Array = EncounterSystem.army_rows(s.race_id)
	var melee: Array = army.filter(func(u): return GameData.text(u, "role") == "Melee")
	var large: Array = army.filter(func(u): return GameData.text(u, "role") == "Large")
	for k in owned(s, "veterans") * VETERANS_EACH:
		if not melee.is_empty():
			helpers.append(valley.waves.spawn(melee[0].unit_id, Vector3.INF, Enemy.Team.FRIENDLY))
	for k in owned(s, "champion"):
		var pick: Array = large if not large.is_empty() else melee
		if not pick.is_empty():
			var e: Enemy = valley.waves.spawn(pick[0].unit_id, Vector3.INF, Enemy.Team.FRIENDLY)
			e.make_giant()
			helpers.append(e)
	var side := Vector3(-front.z, 0.0, front.x)
	var n := owned(s, "catapult")
	for k in n:
		var at := behind + side * (k - (n - 1) * 0.5) * 9.0
		at.y = valley.waves.ground_y(at.x, at.z)
		engines.append({"node": _catapult(at, front), "left": 2.0 + k * 1.3})


## The lines clash: each meteors bought is a volley of them.
func intervene() -> void:
	var t: CombatTuning = GameData.tuning
	for volley in owned(Run.state, "meteors"):
		for k in t.meteors_per_volley:
			get_tree().create_timer(1.0 + volley * 4.0 + k * 0.35, false).timeout.connect(_meteor)  # waits while a menu pauses the battle


func _physics_process(delta: float) -> void:
	if engines.is_empty() or not Run.in_fight:
		return
	var t: CombatTuning = GameData.tuning
	for eng in engines:
		eng.left -= delta
		if eng.left > 0.0:
			continue
		eng.left = t.catapult_interval
		var foe := _random_foe()
		if foe != null:
			_lob(eng.node.global_position + Vector3.UP * 3.0, foe.global_position, t.catapult_damage, t.catapult_radius, Color(0.55, 0.5, 0.45), 1.6)


func _random_foe() -> Enemy:
	var foes: Array = valley.waves.members.filter(func(e): return is_instance_valid(e) and not e.is_dead() and e.team == Enemy.Team.HOSTILE)
	return foes[RunRng.randi_range(0, foes.size() - 1)] if not foes.is_empty() else null


func _meteor() -> void:
	var foe := _random_foe()
	if foe == null:
		return
	var t: CombatTuning = GameData.tuning
	var at := foe.global_position
	_lob(at + Vector3(randf_range(-20.0, 20.0), 70.0, randf_range(-20.0, 20.0)), at, t.meteor_damage, t.meteor_radius, Color(1.0, 0.45, 0.15), 1.0)


## A stone (or meteor) flying from `from` to `to`; where it lands, everyone of his army within
## `radius` is hurt.
func _lob(from: Vector3, to: Vector3, damage: float, radius: float, color: Color, seconds: float) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.7 if radius < 5.0 else 1.4
	mesh.height = mesh.radius * 2.0
	rock.mesh = mesh
	rock.material_override = Vfx.material(color)
	valley.add_child(rock)
	rock.global_position = from
	var tw := create_tween()
	var mid := (from + to) * 0.5 + Vector3.UP * (12.0 if from.y - to.y < 20.0 else 0.0)
	tw.tween_method(func(u: float): rock.global_position = from.lerp(mid, u).lerp(mid.lerp(to, u), u), 0.0, 1.0, seconds)
	tw.tween_callback(func():
		rock.queue_free()
		Vfx.burst(to + Vector3.UP, radius, Color(color, 0.8), 0.5)
		for e in valley.waves.members.duplicate():
			if is_instance_valid(e) and not e.is_dead() and e.team == Enemy.Team.HOSTILE and e.global_position.distance_to(to) < radius:
				Combat.deal(e, DamageInfo.make(damage, "Fire" if radius >= 5.0 else "Physical", DamageInfo.Kind.GODLY_GIFT, valley.player)))


## A catapult built from boxes until your own model exists.
func _catapult(at: Vector3, front: Vector3) -> Node3D:
	var root := Node3D.new()
	valley.add_child(root)
	root.global_position = at
	root.rotation.y = atan2(-front.x, -front.z)
	var wood := Vfx.material(Color(0.42, 0.28, 0.16))
	for part in [[Vector3(0, 0.5, 0), Vector3(2.6, 0.4, 4.0)], [Vector3(-1.1, 1.6, 0), Vector3(0.3, 2.2, 0.3)], [Vector3(1.1, 1.6, 0), Vector3(0.3, 2.2, 0.3)],
			[Vector3(0, 2.6, 0), Vector3(2.4, 0.3, 0.3)], [Vector3(0, 3.2, 0.9), Vector3(0.3, 0.3, 4.2)]]:
		var box := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = part[1]
		box.mesh = m
		box.material_override = wood
		root.add_child(box)
		box.position = part[0]
	root.get_child(-1).rotation.x = -0.6  # the throwing arm, cocked
	return root
