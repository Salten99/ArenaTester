class_name EncounterSite
extends Node3D
## An encounter waiting in the valley as a real place, not a beam of light (user,
## 2026-10-29): you come upon it.
##   Camps (bandit camp, beast den, a race's war camp), a war party, a taken
##   shrine, Count Fuckula's border raid: their fighters stand around the place;
##   walk into it (AUTO_RANGE) and the fight starts there. Steer clear to save it
##   for later. Or sneak in (user, 2026-11-16): crouched, only a sentry that notices
##   you starts the fight, and a blow on a sentry that hasn't noticed you takes it
##   out at once. Take them all out and the camp is cleared without the battle.
##   A wild god's shrine, a cornered pilgrim, the final battle: walk up and press F.
## A small sign shows the name once you're close (SIGN_RANGE).

## Map colors by encounter type (Encounters sheet "type").
const COLORS := {
	"Tribe Mission": Color(1.0, 0.8, 0.3),
	"Champion Trial": Color(1.0, 0.3, 0.25),
	"Wild God": Color(0.35, 0.9, 1.0),
	"Border Defense": Color(1.0, 0.5, 0.1),
	"Barbarian": Color(0.75, 0.6, 0.45),
	"Evil Tribe": Color(0.7, 0.3, 1.0),
}
## Encounters whose fighters attack when you walk in (the rest wait for F).
const AUTO := ["tm_clear_camp", "wg_war_party", "wg_camp_purge", "tm_border_defense"]
const AUTO_RANGE := 24.0
const SIGN_RANGE := 70.0
const SENTRIES := 5

var encounter_id := ""
var title := ""
var color := Color.WHITE
## True if walking in starts the fight (AUTO).
var auto := false
var sentries: Array = []
var _posted := 0  ## sentries placed (a camp with none can't be cleared quietly)
var _sign: Label3D
var _props: Node3D
var _look := ""  ## camp, den, shrine, banners, stronghold, pilgrim


static func make(state: RunState, id: String, ground: Vector3) -> EncounterSite:
	var site := EncounterSite.new()
	site.name = "Site_" + id
	site.encounter_id = id
	var e: Dictionary = state.encounters[id]
	var def := GameData.row("encounters", e.def)
	site.title = GameData.text(def, "display_name", id)
	site.color = COLORS.get(GameData.text(def, "type"), Color.WHITE)
	if id == "final_battle":
		site.color = COLORS["Evil Tribe"]
	site.auto = str(e.def) in AUTO or id.begins_with("border_")
	site._look = _look_for(state, id, str(e.def))
	site.position = ground
	return site


## What the place looks like: a camp by who's in it, a shrine for the wild gods...
static func _look_for(state: RunState, id: String, def_id: String) -> String:
	if id == "final_battle":
		return "stronghold"
	if id.begins_with("border_"):
		return "banners"
	match def_id:
		"wg_apostle_in_peril":
			return "pilgrim"
		"wg_shrine_trial", "wg_camp_purge":
			return "shrine"
	var plan := EncounterSystem.plan(state, id)
	return "den" if str(plan.get("party", "")) == "beasts" else "camp"


func _ready() -> void:
	var valley := get_parent()
	_props = Node3D.new()
	_props.name = "Props_" + encounter_id
	valley.world.add_child(_props)
	_props.position = global_position
	_build_props(valley.world)
	_sign = Label3D.new()
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.font_size = 40
	_sign.outline_size = 12
	_sign.pixel_size = 0.012
	_sign.modulate = color.lightened(0.3)
	_sign.position.y = 6.0
	_sign.text = title
	_sign.visibility_range_end = SIGN_RANGE
	add_child(_sign)
	_place_sentries(valley)


func _exit_tree() -> void:
	if is_instance_valid(_props):
		_props.queue_free()
	clear_sentries()


## Props aren't solid: ValleyWorld keeps a solid prop's collider after the prop is freed.
func _build_props(world: ValleyWorld) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(encounter_id)
	match _look:
		"camp":  # huts around a fire, crates and a cart
			for i in 2:
				world._building(_props, "hut", Vector3.FORWARD.rotated(Vector3.UP, i * 2.4 + rng.randf()) * 11.0, rng.randf() * TAU, false)
			world._building(_props, "bonfire", Vector3.ZERO, 0.0, false)
			for m in ["crate", "barrel", "cart"]:
				world._building(_props, m, Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * 6.0, rng.randf() * TAU, false)
			_fire_light()
		"den":  # a ring of rocks, bones and hay around a dark hollow
			for i in 6:
				world._building(_props, ["rock_a", "rock_b", "rock_c", "rock_d"][i % 4], Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 6.0) * 8.0, rng.randf() * TAU, false)
			world._building(_props, "hay", Vector3.ZERO, 0.0, false)
			_bones(rng)
		"shrine", "pilgrim":  # a standing stone with a soft glow of the encounter's color
			world._building(_props, "rock_d", Vector3.ZERO, 0.0, false)
			for i in 4:
				world._building(_props, "rock_a", Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 4.0 + 0.4) * 5.0, rng.randf() * TAU, false)
			var orb := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			orb.mesh = s
			orb.material_override = _glow(Color(color, 0.85))
			orb.position = Vector3.UP * 4.5
			add_child(orb)
			var light := OmniLight3D.new()
			light.light_color = color
			light.light_energy = 2.0
			light.omni_range = 12.0
			light.position = Vector3.UP * 4.5
			add_child(light)
		"banners", "stronghold":  # Count Fuckula's dark banners around a fire
			world._building(_props, "bonfire", Vector3.ZERO, 0.0, false)
			for i in (6 if _look == "stronghold" else 4):
				_banner(Vector3.FORWARD.rotated(Vector3.UP, i * TAU / (6.0 if _look == "stronghold" else 4.0)) * 9.0)
			_fire_light()


func _fire_light() -> void:
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.6, 0.3)
	fire.light_energy = 3.0
	fire.omni_range = 14.0
	fire.position = Vector3.UP * 1.5
	add_child(fire)


func _bones(rng: RandomNumberGenerator) -> void:
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.9, 0.87, 0.78)
	for i in 7:
		var m := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.08
		c.bottom_radius = 0.1
		c.height = rng.randf_range(0.6, 1.2)
		m.mesh = c
		m.material_override = bone
		m.position = Vector3(rng.randf_range(-5, 5), 0.1, rng.randf_range(-5, 5))
		m.rotation = Vector3(PI * 0.5, rng.randf() * TAU, 0.0)
		add_child(m)


func _banner(at: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.08
	c.bottom_radius = 0.1
	c.height = 6.0
	pole.mesh = c
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.2, 0.15, 0.12)
	pole.material_override = wood
	pole.position = at + Vector3.UP * 3.0
	add_child(pole)
	var flag := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.4, 2.2, 0.05)
	flag.mesh = b
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.35, 0.1, 0.45)
	flag.material_override = cloth
	flag.position = at + Vector3(0.75, 4.6, 0.0)
	add_child(flag)


## Who's there before the fight: a few of the fight's own units around the place,
## standing still (no side yet). A pilgrim encounter has its pilgrim instead.
func _place_sentries(valley: Node) -> void:
	var units: Array = []
	if _look == "pilgrim":
		units = ["human_hedge_healer"] if not GameData.unit("human_hedge_healer").is_empty() else []
	elif auto:
		var plan := EncounterSystem.plan(Run.state, encounter_id)
		var first: Array = plan.get("waves", [[]])[0] if not plan.get("waves", []).is_empty() else []
		units = first.slice(0, SENTRIES)
	for i in units.size():
		var token: String = units[i]
		var e := Enemy.new()
		e.setup(token, valley.player, valley.director, Enemy.Team.NEUTRAL)
		var p := global_position + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / maxf(1.0, units.size()) + 0.3) * 4.5
		p.y = valley.terrain.height(p.x, p.z) + 0.1
		e.post = p
		if auto:
			e.aggro_radius = AUTO_RANGE  # only for noticing you (Enemy._notice_distance): they have no side yet
			e.add_to_group(Combat.STRIKABLE)  # you can pick them off before the fight
		valley.add_child(e)
		e.global_position = p
		sentries.append(e)
	_posted = sentries.size()


## True if walking here starts the fight: standing within AUTO_RANGE, or, sneaking (crouched),
## within the noticing distance of a sentry still standing.
func spotted(p: Player, d: float) -> bool:
	var live := sentries.filter(func(e): return is_instance_valid(e) and not e.is_dead())
	if not p.is_crouching or live.is_empty():
		return d < AUTO_RANGE
	return live.any(func(e): return e.global_position.distance_to(p.global_position) < e._notice_distance())


## True once every sentry fell before the fight started.
func cleared_quietly() -> bool:
	return _posted > 0 and sentries.all(func(e): return not is_instance_valid(e) or e.is_dead())


## The fight replaces them (its waves start here).
func clear_sentries() -> void:
	for e in sentries:
		if is_instance_valid(e):
			e.queue_free()
	sentries = []


## Far-away places pause their figures.
func set_dormant(on: bool) -> void:
	for e in sentries:
		if is_instance_valid(e):
			e.set_dormant(on)


## Updates the sign (e.g. a Border Defense countdown).
func set_text(text: String) -> void:
	if _sign != null:
		_sign.text = text


## During the fight the figures go (the waves take over) and the sign hides.
func set_fighting(on: bool) -> void:
	if on:
		clear_sentries()
	if _sign != null:
		_sign.visible = not on


static func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
