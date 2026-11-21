class_name WeaponMoveset
extends RefCounted
## The shared weapon types (Council II 5; Twin added 2026-11-06): Heavy, Blade, Twin, Polearm,
## and Fists, what you fight with until you pick a weapon up (user, 2026-11-20).
## The weapon (Weapons sheet, picked with the race) gives the stats and model; the moveset
## decides the shape of the light combo, the heavy attack, and the animations.
##
## Every moveset uses the player's helpers, so damage, crits, godly gift events and
## feedback stay identical across weapon types:
##   p.enemies_in_arc(reach, half_angle)   p.hit_targets(...)

## Light combo animations, in order; the last one is the finisher.
func light_anims() -> Array:
	return ["Melee_2H_Attack_Chop", "Melee_2H_Attack_Slice", "Melee_2H_Attack_Spin"]


func heavy_anim() -> String:
	return "Melee_1H_Attack_Jump_Chop"


func idle_anim() -> String:
	return "Melee_2H_Idle"


## The clip that throws it (G; the Human Throwing pack, user 2026-11-20): a short overhand throw
## for the hammer and the sword, a sideways whip for the khopesh, a javelin throw for the polearm.
func throw_anim() -> String:
	return "Human_ThrowWeapon"


## The bone the weapon is held by (CharacterModel.weapon_bone).
func weapon_bone() -> String:
	return "handslot.r"


## How much quicker its swings are than the weapon's attack speed says (animations and hits alike).
func swing_speed() -> float:
	return 1.0


## How hard its launching hits throw enemies (combat feel plan, 2026-11-18: each class its own):
## the hammer hardest, twin blades least. Times launch_speed and launch_lift.
func launch_scale() -> float:
	return 1.3


func light_hit(p: Player, finisher: bool) -> void:
	var t: CombatTuning = GameData.tuning
	var reach := _reach(p)
	var targets := p.enemies_in_arc(reach, t.light_arc_degrees)
	_smash_ahead(p, reach)
	_swing(p, targets, finisher, p.global_position + p.facing * reach * 0.6)


func heavy_hit(p: Player) -> void:
	var t: CombatTuning = GameData.tuning
	var center := p.global_position + p.facing * 1.2
	var radius := 4.0
	ElementFx.play_own("hammer_slam", center, radius)  # your weapon effects (models/own/fx/weapons), built at 1 m
	Vfx.ring(center, radius, Color(1.0, 0.8, 0.5))
	Vfx.ring(center, radius * 0.6, Color(1, 1, 1, 0.9), 0.2)  # the hammer reel's white ring on the ground
	var targets := Combat.enemies_in_radius(center, radius)
	Breakable.smash_near(p.get_tree(), center, radius, center)
	p.hit_targets(targets, _base(p) * p.heavy_mult(), DamageInfo.Kind.HEAVY, t.knockback_heavy, true,
		t.hitstop_heavy, t.shake_heavy, center)
	if targets.is_empty():
		Combat.shake(t.shake_light)


## Shared light-swing damage: the finisher hits harder and fires both events.
func _swing(p: Player, targets: Array, finisher: bool, impact: Vector3) -> void:
	var t: CombatTuning = GameData.tuning
	p.hit_targets(targets, _base(p), DamageInfo.Kind.LIGHT, t.knockback_heavy * 0.6 if finisher else t.knockback_light,
		false, t.hitstop_light, t.shake_light, impact)


## Breaks the props a forward swing of `reach` m covers (Breakable): a circle filling the arc in front.
func _smash_ahead(p: Player, reach: float) -> void:
	Breakable.smash_near(p.get_tree(), p.global_position + p.facing * reach * 0.5, reach * 0.5, p.global_position)


## Breaks the props in a circle around you.
func _smash_around(p: Player, radius: float) -> void:
	Breakable.smash_near(p.get_tree(), p.global_position, radius, p.global_position)


func _reach(p: Player) -> float:
	return GameData.num(p.weapon(), "weapon_range_m", 2.5) + 0.4


func _base(p: Player) -> float:
	return GameData.num(p.weapon(), "weapon_base_damage", 15.0)


static func for_class(weapon_class: String) -> WeaponMoveset:
	match weapon_class:
		"Blade": return Blade.new()
		"Twin": return Twin.new()
		"Polearm": return Polearm.new()
		"Fists": return Fists.new()
		_: return WeaponMoveset.new()  # Heavy


## Swords: wide fast arcs; the finisher spins; heavy is a dash-slash.
class Blade extends WeaponMoveset:
	func launch_scale() -> float:
		return 1.0

	## Sword swings 50% faster (user, 2026-11-08).
	func swing_speed() -> float:
		return 1.5

	func light_anims() -> Array:
		return ["Melee_1H_Attack_Slice_Horizontal", "Melee_1H_Attack_Slice_Diagonal", "Melee_2H_Attack_Spinning"]

	func heavy_anim() -> String:
		return "Melee_1H_Attack_Stab"

	func light_hit(p: Player, finisher: bool) -> void:
		var reach := _reach(p)
		ElementFx.play_own("sword_slash", p.global_position)
		var targets := Combat.enemies_in_radius(p.global_position, reach) if finisher else p.enemies_in_arc(reach, 85.0)
		if finisher:
			_smash_around(p, reach)
		else:
			_smash_ahead(p, reach)
		_swing(p, targets, finisher, p.global_position + p.facing * reach * 0.5)

	func heavy_hit(p: Player) -> void:
		var t: CombatTuning = GameData.tuning
		var dash := 5.0
		var start := p.global_position
		p.lunge(p.facing * dash)
		var targets := _in_line(start, p.facing, dash + 1.0, 1.2)
		Breakable.smash_line(p.get_tree(), start, p.facing, dash + 1.0, 1.2)
		p.hit_targets(targets, _base(p) * p.heavy_mult(), DamageInfo.Kind.HEAVY, t.knockback_light, false,
			t.hitstop_heavy, t.shake_heavy, start + p.facing * dash * 0.5)


## Twin blades (user, 2026-11-06: their own class): quick cuts with both blades; the
## finisher is a deep double stab; heavy is a spinning flurry all around you.
class Twin extends WeaponMoveset:
	func throw_anim() -> String:
		return "Human_ThrowBoomerang"

	func launch_scale() -> float:
		return 0.8

	func light_anims() -> Array:
		return ["Melee_Dualwield_Attack_Slice", "Melee_Dualwield_Attack_Chop", "Melee_Dualwield_Attack_Stab"]

	func heavy_anim() -> String:
		return "Melee_2H_Attack_Spinning"

	func light_hit(p: Player, finisher: bool) -> void:
		var reach := _reach(p)
		var targets := p.enemies_in_arc(reach + 0.8, 35.0) if finisher else p.enemies_in_arc(reach, 100.0)
		_smash_ahead(p, reach + (0.8 if finisher else 0.0))
		_swing(p, targets, finisher, p.global_position + p.facing * reach * 0.5)

	func heavy_hit(p: Player) -> void:
		var t: CombatTuning = GameData.tuning
		var radius := _reach(p) + 1.0
		_smash_around(p, radius)
		ElementFx.play_own("khopesh_spin", p.global_position, radius)
		Vfx.ring(p.global_position, radius, Color(1.0, 0.85, 0.6))
		p.hit_targets(Combat.enemies_in_radius(p.global_position, radius), _base(p) * p.heavy_mult(),
			DamageInfo.Kind.HEAVY, t.knockback_light, false, t.hitstop_heavy, t.shake_heavy, p.global_position)


## Spears, tridents, scythes, naginata: long thrusts; the finisher sweeps; heavy is a full circle.
class Polearm extends WeaponMoveset:
	func throw_anim() -> String:
		return "Human_ThrowSpear"

	func launch_scale() -> float:
		return 1.1

	func light_anims() -> Array:
		return ["Melee_2H_Attack_Stab", "Melee_2H_Attack_Stab", "Melee_2H_Attack_Slice"]

	func heavy_anim() -> String:
		return "Melee_2H_Attack_Spin"

	func light_hit(p: Player, finisher: bool) -> void:
		var reach := _reach(p) + 0.8
		var targets := p.enemies_in_arc(reach, 70.0) if finisher else _in_line(p.global_position, p.facing, reach, 0.9)
		if finisher:
			_smash_ahead(p, reach)
		else:
			Breakable.smash_line(p.get_tree(), p.global_position, p.facing, reach, 0.9)
		_swing(p, targets, finisher, p.global_position + p.facing * reach * 0.7)

	func heavy_hit(p: Player) -> void:
		var t: CombatTuning = GameData.tuning
		var radius := _reach(p) + 0.6
		_smash_around(p, radius)
		ElementFx.play_own("naginata_sweep", p.global_position, radius)
		Vfx.ring(p.global_position, radius, Color(0.9, 0.9, 1.0))
		p.hit_targets(Combat.enemies_in_radius(p.global_position, radius), _base(p) * p.heavy_mult(),
			DamageInfo.Kind.HEAVY, t.knockback_heavy, false, t.hitstop_heavy, t.shake_heavy, p.global_position)


## Bare hands (user, 2026-11-20: you start with none but the chain): two quick punches and a kick;
## heavy is a front kick that knocks the one in front of you back. Weak, so a found weapon is worth it.
class Fists extends WeaponMoveset:
	func launch_scale() -> float:
		return 0.8

	func light_anims() -> Array:
		return ["Melee_Unarmed_Attack_Punch_A", "Melee_Unarmed_Attack_Punch_A", "Melee_Unarmed_Attack_Kick"]

	func heavy_anim() -> String:
		return "Melee_Unarmed_Attack_Kick"

	func idle_anim() -> String:
		return "Melee_Unarmed_Idle"

	func heavy_hit(p: Player) -> void:
		var t: CombatTuning = GameData.tuning
		var reach := _reach(p) + 0.6
		_smash_ahead(p, reach)
		p.hit_targets(p.enemies_in_arc(reach, 45.0), _base(p) * p.heavy_mult(), DamageInfo.Kind.HEAVY, t.knockback_heavy, true,
			t.hitstop_heavy, t.shake_heavy, p.global_position + p.facing * reach * 0.6, "Physical", false, false)


## Enemies inside a capsule from `start` along `dir`.
static func _in_line(start: Vector3, dir: Vector3, length: float, width: float) -> Array:
	var out: Array = []
	for e in Combat.enemies_in_radius(start + dir * length * 0.5, length * 0.5 + width):
		var to: Vector3 = e.global_position - start
		to.y = 0.0
		var along := to.dot(dir)
		if along >= -0.3 and along <= length and (to - dir * along).length() <= width:
			out.append(e)
	return out
