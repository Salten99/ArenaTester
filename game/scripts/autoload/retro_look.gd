extends CanvasLayer
## Retro look, crisp pixels (user, 2026-11-09; PS2 style before): lays shaders/retro_screen.gdshader over the 3D world. Layer -1
## is drawn after the 3D world but before every HUD and menu, so text stays sharp.
## O turns it on and off (Controls menu); the choice is kept in the profile.
## shortcut: the full-size world is drawn and then made low-res, so it isn't faster;
## render at low resolution if the look stays and speed matters.

const MATERIAL := preload("res://tuning/retro_screen.tres")
## Pixel grit on every model that isn't yours (user, 2026-11-09): a small painted-looking texture
## of light and dark pixels over its colors, so plain colored models read like PS1-era textured ones.
const GRIT_SIZE := 32  ## pixels across the grit texture
const GRIT_TEXEL := 0.06  ## m each grit pixel covers
static var _grit: ImageTexture


## Gives a model's material the pixel look: sharp texture pixels, and grit if it has no texture of
## its own. `world`: the grit is laid in world space (ground, roads), else it moves with the model.
static func paint(mat: BaseMaterial3D, world := false) -> void:
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if mat.albedo_texture != null:
		return
	mat.albedo_texture = grit()
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = world
	mat.uv1_scale = Vector3.ONE / (GRIT_SIZE * GRIT_TEXEL)


## Light patches of 4 px with single darker and lighter pixels in them (no visible seams: it tiles).
static func grit() -> ImageTexture:
	if _grit == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1999
		var patch := []
		for i in (GRIT_SIZE / 4) * (GRIT_SIZE / 4):
			patch.append(rng.randf_range(0.86, 1.0))
		var img := Image.create_empty(GRIT_SIZE, GRIT_SIZE, false, Image.FORMAT_RGB8)
		for y in GRIT_SIZE:
			for x in GRIT_SIZE:
				var v: float = patch[(y / 4) * (GRIT_SIZE / 4) + x / 4] + rng.randf_range(-0.05, 0.05)
				if rng.randf() < 0.06:
					v -= 0.12
				img.set_pixel(x, y, Color(v, v, v))
		img.generate_mipmaps()
		_grit = ImageTexture.create_from_image(img)
	return _grit


func _ready() -> void:
	layer = -1
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = MATERIAL
	add_child(rect)
	visible = Meta.data.get("retro_look", true)
	grit()  # made here, on the main thread, before any world builds in the background


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("retro_look"):
		toggle()


func toggle() -> void:
	visible = not visible
	Meta.data["retro_look"] = visible
	Meta.save()
