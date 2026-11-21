class_name ArenaCourse
extends RefCounted
## Walls, blocks and heights in the endless arena (user, 2026-11-20), out past the traps' ring so the
## middle stays open for fighting. Plain stone to run along and jump off, mossy walls to climb, and a
## tall tower with a gold ring on its lip to chain up to. Grey boxes until the user models them.
##   - two long walls side by side: wall run along one, wall jump back and forth between them to go up;
##   - a raised platform with a mossy climbing face and a ramp up the back (enemies take the ramp);
##   - a tall tower with a sling ring, and a low step in front;
##   - a staircase of blocks, each a jump higher than the last;
##   - low walls for cover between them.

const STONE := Color(0.55, 0.5, 0.44)
const MOSS := Color(0.32, 0.42, 0.24)
const TOWER_HEIGHT := 10.0


static func build(parent: Node3D) -> void:
	# The wall-run alley, at 0 degrees: two 4.5 m tall walls, 5 m apart, 12 m long, pointing at the middle.
	for side in [-2.5, 2.5]:
		block(parent, Vector3(25.0, 2.25, side), Vector3(12.0, 4.5, 0.8), 0.0)
	# The platform, at 90 degrees: 5 m up, a mossy face toward the middle, a ramp down the far side.
	block(parent, Vector3(0.0, 2.5, 25.0), Vector3(8.0, 5.0, 6.0), 0.0)
	block(parent, Vector3(0.0, 2.5, 21.85), Vector3(4.0, 5.0, 0.3), 0.0, true)
	var ramp_len := 12.0
	var ramp_angle := asin(5.0 / ramp_len)
	var ramp := block(parent, Vector3(0.0, 2.5 - 0.25, 28.0 + cos(ramp_angle) * ramp_len * 0.5), Vector3(4.0, 0.5, ramp_len), 0.0)
	ramp.rotation.x = ramp_angle  # rises toward the platform
	# The tower, at 180 degrees: 10 m tall, a ring on the lip facing the middle; a 2 m step in front.
	block(parent, Vector3(-26.0, TOWER_HEIGHT * 0.5, 0.0), Vector3(5.0, TOWER_HEIGHT, 5.0), 0.0)
	var ring := LedgeAnchor.make(parent, Vector3(-23.4, TOWER_HEIGHT - 0.3, 0.0), PI * 0.5)
	ring.landing_at = Vector3(0.0, 1.0, -2.4)
	block(parent, Vector3(-20.5, 1.0, 0.0), Vector3(3.0, 2.0, 3.0), 0.0)
	# The staircase, at 270 degrees: each block 1.2 m higher, out from the middle.
	for i in 4:
		var high := 1.2 * (i + 1)
		block(parent, Vector3(0.0, high * 0.5, -20.0 - 3.0 * i), Vector3(4.0, high, 3.0), 0.0)
	# Low walls for cover, between the traps.
	for deg in [22.5, 67.5, 112.5, 157.5, 202.5, 247.5, 292.5, 337.5]:
		var a := deg_to_rad(deg)
		block(parent, Vector3(cos(a), 0.0, sin(a)) * 21.0 + Vector3.UP * 0.6, Vector3(3.5, 1.2, 0.8), -a + PI * 0.5)


## A solid box (world layer) centered at `pos`. `climbable` makes it a mossy wall you climb by pushing into it.
static func block(parent: Node3D, pos: Vector3, size: Vector3, yaw: float, climbable := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 0b001
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MOSS if climbable else STONE
	mat.roughness = 0.95
	mesh.material_override = mat
	body.add_child(mesh)
	if climbable:
		body.add_to_group("climbable")
		for y in range(1, int(size.y)):  # handholds, so it reads as climbable
			var hold := MeshInstance3D.new()
			var hm := BoxMesh.new()
			hm.size = Vector3(size.x * 0.8, 0.12, size.z + 0.16)
			hold.mesh = hm
			hold.material_override = mat
			hold.position.y = -size.y * 0.5 + y
			body.add_child(hold)
	body.add_to_group("arena_course")
	parent.add_child(body)
	body.position = pos
	body.rotation.y = yaw
	return body
