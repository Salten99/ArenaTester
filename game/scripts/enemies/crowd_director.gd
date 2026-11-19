class_name CrowdDirector
extends Node
## Keeps big crowds fair: only `max_attackers` enemies may wind up or strike at
## once (attack tokens). Everyone else circles at a distance, waiting their turn.

var enemies: Array = []
var _holders: Array = []
## Attackers per friendly warrior (the player's limit is max_attackers in the tuning).
const ALLY_ATTACKERS := 2
var _ally_holders := {}  # target instance id -> [attackers]


func register(e: Node) -> void:
	enemies.append(e)
	_grid_frame = -1  # a unit spawned this frame is found by this frame's searches too


## Units of `team` whose cell lies within `radius` of `center` (a superset: callers check the
## real distance). Combat's hit searches use it instead of walking every unit in the valley
## (measured 2026-11-16: 0.27 ms per search over 1100 units).
func near(center: Vector3, radius: float, team: int) -> Array:
	if _grid_frame != Engine.get_physics_frames():
		_build_grid()
	var cells: Dictionary = _far.get(team, {})
	var c := Vector2i(floori(center.x / FAR_CELL), floori(center.z / FAR_CELL))
	var r := ceili((radius + 1.0) / FAR_CELL)  # +1 m: units moved since the grid was built
	var out: Array = []
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			out.append_array(cells.get(c + Vector2i(dx, dz), []))
	return out


func unregister(e: Node) -> void:
	enemies.erase(e)
	release(e)


func request_token(e: Node) -> bool:
	_holders = _holders.filter(func(h): return is_instance_valid(h) and not h.is_dead())
	if e in _holders:
		return true
	if _holders.size() >= GameData.tuning.max_attackers:
		return false
	# Shooters and casters hit from range and can't be crowded out, so fewer of
	# them may fire at you at once (first playtest: they did most of the damage).
	if e.is_ranged() and _holders.filter(func(h): return h.is_ranged()).size() >= GameData.tuning.max_ranged_attackers:
		return false
	_holders.append(e)
	return true


## A token to attack a friendly warrior: at most ALLY_ATTACKERS at once each.
func request_ally_token(e: Node, target: Node) -> bool:
	var key := target.get_instance_id()
	var list: Array = _ally_holders.get(key, []).filter(func(h): return is_instance_valid(h) and not h.is_dead() and h.target == target)
	_ally_holders[key] = list
	if e in list:
		return true
	if list.size() < ALLY_ATTACKERS:
		list.append(e)
		return true
	return false


func release(e: Node) -> void:
	_holders.erase(e)
	for key in _ally_holders.keys():
		_ally_holders[key].erase(e)
		if _ally_holders[key].is_empty():
			_ally_holders.erase(key)  # a warrior nobody attacks: forget it, or the list grows all session


func attackers() -> int:
	return _holders.size()


## Push-apart vector so enemies don't stack on top of each other. Only units in
## the 3x3 grid cells around it count: checking everyone against everyone cost
## 30 ms a frame at 120 enemies (user wants bigger fights, 2026-10-30).
const CELL := 4.0
## A unit is pushed by at most this many neighbours, the ring of units that can touch it.
const MAX_TOUCHING := 6
## Up to this many units, everyone thinks every tick; above it far units take turns (Enemy.crowd_stride).
const FULL_RATE_UNITS := 100
var _grid := {}  ## Vector2i -> [[unit, position, size_scale]]
var _grid_frame := -1
## Coarse cells for finding targets far away (best_near).
const FAR_CELL := 16.0
var _far := {}  ## team -> {Vector2i -> [unit]}


func separation(e: Node3D) -> Vector3:
	if _grid_frame != Engine.get_physics_frames():
		_build_grid()
	var push := Vector3.ZERO
	var r: float = GameData.tuning.separation_radius
	var here: Vector3 = e.global_position
	var cell := Vector2i(floori(here.x / CELL), floori(here.z / CELL))
	var touching := 0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for entry in _grid.get(cell + Vector2i(dx, dz), []):
				if entry[0] == e:
					continue
				var d: Vector3 = here - entry[1]
				d.y = 0.0
				var dist := d.length()
				var min_dist: float = r * (entry[2] + e.size_scale) * 0.5
				if dist < min_dist and dist > 0.001:
					push += d / dist * (min_dist - dist) / min_dist
					touching += 1
					if touching >= MAX_TOUCHING:
						return push  # only the ones pressed right against it (user, 2026-11-12)
	return push


## The unit of `team` within `radius` of `e` with the lowest score(unit, distance); INF skips a unit.
## Searches outward ring by ring and stops once no nearer ring can win, so in a 500-unit
## battle a unit looks at its neighbours, not at everyone (that cost 34 ms a re-pick).
## score must be >= distance, or the early stop could miss the best unit.
func best_near(e: Node3D, team: int, radius: float, score: Callable) -> Node3D:
	if _grid_frame != Engine.get_physics_frames():
		_build_grid()
	var here: Vector3 = e.global_position
	var c := Vector2i(floori(here.x / FAR_CELL), floori(here.z / FAR_CELL))
	var cells: Dictionary = _far.get(team, {})
	var best: Node3D = null
	var best_s := INF
	for ring in ceili(radius / FAR_CELL) + 1:
		if (ring - 1) * FAR_CELL > minf(best_s, radius):
			break  # every cell from here on is farther than the best so far
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue  # inner rings were searched already
				for u in cells.get(c + Vector2i(dx, dz), []):
					if u == e or not is_instance_valid(u):
						continue
					var d: float = here.distance_to(u.global_position)
					if d > radius:
						continue
					var s: float = score.call(u, d)
					if s < best_s:
						best_s = s
						best = u
	return best


## The crowd split (combat feel plan, user 2026-11-18; Council X Phase 2, the cheap half): in a
## crowd bigger than crowd_full_fighters, only that many nearest you are full fighters. The rest
## are the crowd (Enemy.in_crowd): they take turns thinking and walk without collisions like far
## units, and their animation steps as often. shortcut: the same models, ranked by distance;
## upgrade to a MultiMesh crowd with GPU-baked animation if 500 must run at 60.
func _rank_crowd() -> void:
	var n: int = GameData.tuning.crowd_full_fighters
	if enemies.size() <= n or enemies.is_empty():
		for u in enemies:
			u.in_crowd = false
		return
	var you: Node3D = enemies[0].player
	if not is_instance_valid(you):
		return
	var at := you.global_position
	var by_distance: Array = []
	for u in enemies:
		by_distance.append([u.global_position.distance_squared_to(at), u])
	by_distance.sort_custom(func(a, b): return a[0] < b[0])
	for i in by_distance.size():
		by_distance[i][1].in_crowd = i >= n


## Units in the crowd right now (tests, the benchmark).
func crowd_count() -> int:
	return enemies.filter(func(u): return is_instance_valid(u) and u.in_crowd).size()


func _build_grid() -> void:
	_grid_frame = Engine.get_physics_frames()
	_grid.clear()
	_far.clear()
	# Units freed without dying (warriors heading home, a camp's sentries) never unregister: drop them,
	# or they pile up all session and the stride below counts them as a crowd.
	enemies = enemies.filter(func(u): return is_instance_valid(u))
	Enemy.crowd_stride = clampi(ceili(enemies.size() / float(FULL_RATE_UNITS)), 1, 4)
	_rank_crowd()
	for u in enemies:
		var p: Vector3 = u.global_position
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not _grid.has(key):
			_grid[key] = []
		_grid[key].append([u, p, u.size_scale])
		var far := Vector2i(floori(p.x / FAR_CELL), floori(p.z / FAR_CELL))
		if not _far.has(u.team):
			_far[u.team] = {}
		if not _far[u.team].has(far):
			_far[u.team][far] = []
		_far[u.team][far].append(u)
