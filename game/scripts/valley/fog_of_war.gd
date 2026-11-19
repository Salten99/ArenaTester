class_name FogOfWar
extends RefCounted
## The map's fog of war (user, 2026-11-05): the valley map is dark until you've been near a
## place, so villages, landmarks and encounters show only once you've found them. The valley
## is cut into CELL-sized squares; walking within SIGHT of one reveals it. What's seen is kept
## in the saved run (RunState.flags.seen).

const CELL := 40.0
const SIGHT := 140.0
const NX := int((ValleyTerrain.HALF_W * 2.0) / CELL) + 1
const NZ := int((ValleyTerrain.HALF_L * 2.0) / CELL) + 1

var seen := PackedByteArray()
var image: Image      ## one pixel per cell, opaque where unseen (ValleyMap draws it tinted over the map)
var texture: ImageTexture
var _changed := true


func _init(saved: String = "") -> void:
	if saved != "":
		seen = Marshalls.base64_to_raw(saved)
	if seen.size() != NX * NZ:
		seen = PackedByteArray()
		seen.resize(NX * NZ)
	image = Image.create(NX, NZ, false, Image.FORMAT_RGBA8)
	for k in seen.size():
		image.set_pixel(k % NX, k / NX, Color(1, 1, 1, 0.0 if seen[k] else 1.0))  # white: the map tints it


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int((p.x + ValleyTerrain.HALF_W) / CELL), int((p.y + ValleyTerrain.HALF_L) / CELL))


func is_seen(p: Vector2) -> bool:
	var c := _cell(p)
	return c.x >= 0 and c.y >= 0 and c.x < NX and c.y < NZ and seen[c.y * NX + c.x] == 1


## Reveals every cell within `sight` of `p` (towers see farther). True if anything new was revealed.
func reveal(p: Vector2, sight := SIGHT) -> bool:
	var c := _cell(p)
	var r := int(ceil(sight / CELL))
	var any := false
	for z in range(maxi(c.y - r, 0), mini(c.y + r, NZ - 1) + 1):
		for x in range(maxi(c.x - r, 0), mini(c.x + r, NX - 1) + 1):
			var k := z * NX + x
			if seen[k] == 1:
				continue
			var mid := Vector2((x + 0.5) * CELL - ValleyTerrain.HALF_W, (z + 0.5) * CELL - ValleyTerrain.HALF_L)
			if mid.distance_to(p) <= sight:
				seen[k] = 1
				image.set_pixel(x, z, Color(1, 1, 1, 0))
				any = true
	_changed = _changed or any
	return any


func save_text() -> String:
	return Marshalls.raw_to_base64(seen)


## The fog as a texture (rebuilt only after something new was revealed).
func get_texture() -> ImageTexture:
	if _changed:
		texture = ImageTexture.create_from_image(image)
		_changed = false
	return texture
