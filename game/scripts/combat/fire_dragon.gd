class_name FireDragon extends Node3D
## The Fire ultimate's flame dragon: a head and a body of glowing pieces that
## snake out of a magic circle, up, and dive into the aimed spot.

signal landed  ## the head reached the ground (sent once)

const HEAD := preload("res://models/fx/flame_dragon_head.glb")
const SEGMENT := preload("res://models/fx/flame_dragon_segment.glb")

@export var p0: Vector3  # the circle
@export var p1: Vector3
@export var p2: Vector3
@export var p3: Vector3  # the ground
@export var side := Vector3.RIGHT  # which way it weaves
@export var phase := 0.0  # each weaves to its own beat
@export var time := 0.0  # below 0: still waiting in the circle

var pieces: Array[Node3D] = []  # the head first, then the body to the tail
var _landed := false
var _pace := PackedFloat32Array()  # how far along the flight (0..1) it is at each of PACE_STEPS steps of the curve

const PACE_STEPS := 64


func _ready() -> void:
	add_to_group("fire_dragons")
	var t: CombatTuning = GameData.tuning
	var n := t.ult_dragon_segments
	for i in n:
		var k := float(i) / (n - 1)  # 0 at the head, 1 at the tail
		var scene: PackedScene = HEAD if i == 0 else SEGMENT
		var piece: Node3D = scene.instantiate()
		for mesh in piece.get_children():  # the models were exported off center: keep their size, drop the offset
			if mesh is Node3D:
				(mesh as Node3D).position = Vector3.ZERO
		piece.scale = Vector3.ONE * t.ult_dragon_size * lerpf(1.0, 0.25, k) * (t.ult_dragon_head_scale if i == 0 else 1.0)
		piece.visible = false  # shown once it's out of the circle
		if i % 3 == 0:  # flames streaming off the head and every third piece
			var flames := ElementFx.trail("Fire")
			if flames != null:
				piece.add_child(flames)
				flames.emitting = true
		add_child(piece)
		pieces.append(piece)
	_build_pace()


## Slower through tight bends, faster down the straights (user, 2026-11-20): each step of the curve
## gets time for its length, and more for how sharply it bends; the flight still takes ult_dragon_time.
func _build_pace() -> void:
	var t: CombatTuning = GameData.tuning
	var pts: Array[Vector3] = []
	for j in PACE_STEPS + 1:
		pts.append(point_at(float(j) / PACE_STEPS))
	var costs: Array[float] = [0.0]
	for j in range(1, PACE_STEPS + 1):
		var step := pts[j] - pts[j - 1]
		var bend := step.angle_to(pts[j + 1] - pts[j]) if j < PACE_STEPS else 0.0
		var curve := bend / maxf(step.length(), 0.001)  # radians a meter
		costs.append(costs[j - 1] + step.length() * (1.0 + t.ult_dragon_bend_slow * curve))
	_pace.resize(PACE_STEPS + 1)
	for j in PACE_STEPS + 1:
		_pace[j] = costs[j] / maxf(costs[PACE_STEPS], 0.001)


## Where on the curve (u) the head is once `s` of the flight (0..1) has gone by.
func u_for(s: float) -> float:
	if s <= 0.0 or s >= 1.0 or _pace.is_empty():
		return s  # past the ground the body pours straight in
	var j := clampi(_pace.bsearch(s), 1, PACE_STEPS)
	var a := _pace[j - 1]
	return (j - 1 + (s - a) / maxf(_pace[j] - a, 0.000001)) / PACE_STEPS


## Where the body is at `u` (0 the circle, 1 the ground): a curve out, up and down onto
## the spot, weaving side to side (and a little up and down) in between.
func point_at(u: float) -> Vector3:
	var t: CombatTuning = GameData.tuning
	var p := p0.bezier_interpolate(p1, p2, p3, u)
	var weave := sin(u * PI) * t.ult_dragon_wave
	var turn := u * TAU * t.ult_dragon_coils + phase
	return p + side * sin(turn) * weave + Vector3.UP * cos(turn) * weave * t.ult_dragon_wave_up


func _physics_process(delta: float) -> void:
	var t: CombatTuning = GameData.tuning
	time += delta
	if time < 0.0:
		return
	var n := pieces.size()
	var gap := 0.6 / n  # the body is 0.6 of the path long
	var f := time / t.ult_dragon_time
	var head_u := u_for(pow(f, 1.4)) if f < 1.0 else 1.0 + (f - 1.0) * 1.2  # gathers speed into the dive
	if head_u >= 1.0 and not _landed:
		_landed = true
		landed.emit()
	for i in n:
		var u := head_u - i * gap
		var piece := pieces[i]
		piece.visible = u > 0.0 and u < 1.0  # still in the circle, or already in the ground
		if piece.visible:
			var here := point_at(u)
			var ahead := point_at(minf(u + 0.01, 1.0)) - here
			piece.global_position = here
			if ahead.length() > 0.001 and absf(ahead.normalized().y) < 0.999:
				piece.look_at(here + ahead, Vector3.UP)
	if head_u - n * gap >= 1.0:  # the tail is in: done
		queue_free()
