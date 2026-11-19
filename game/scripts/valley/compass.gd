class_name Compass
extends Control
## The compass strip at the top of the screen (user, 2026-11-05): which way the camera looks,
## with north (up the valley, toward Count Fuckula) marked, and a dot for each encounter you
## can start, in its map color, that you've found on the map.

const WIDTH := 520.0
const HEIGHT := 30.0
const SPAN := 180.0  ## degrees shown across the strip
const LETTERS := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}

var valley: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 4.0
	offset_bottom = 4.0 + HEIGHT


func _process(_delta: float) -> void:
	queue_redraw()


## Degrees clockwise from north (-Z) of a direction on the ground.
static func bearing(d: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0)


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var heading := bearing(-cam.global_basis.z)
	var font := get_theme_default_font()
	draw_style_box(UiStyle.box(Color(UiStyle.RECESS, 0.75), UiStyle.BRONZE, 2, 4, 0), Rect2(Vector2.ZERO, size))
	var x_of := func(b: float) -> float:
		return WIDTH * 0.5 + angle_difference(deg_to_rad(heading), deg_to_rad(b)) / deg_to_rad(SPAN) * WIDTH
	for deg in range(0, 360, 15):
		var x: float = x_of.call(float(deg))
		if x < 0.0 or x > WIDTH:
			continue
		if LETTERS.has(deg):
			var text: String = LETTERS[deg]
			var w := UiStyle.font(600).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(UiStyle.font(600), Vector2(x - w * 0.5, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.45, 0.35) if deg == 0 else UiStyle.GOLD)
		else:
			draw_line(Vector2(x, 9), Vector2(x, 19), Color(UiStyle.TEXT, 0.45), 1.0)
	if valley != null and Run.active and valley.player != null:
		var here: Vector3 = valley.player.global_position
		for id in valley.sites:
			var site: Node3D = valley.sites[id]
			var at := site.global_position
			if valley.fog != null and not valley.fog.is_seen(Vector2(at.x, at.z)):
				continue
			var x: float = x_of.call(bearing(at - here))
			if x >= 0.0 and x <= WIDTH:
				draw_circle(Vector2(x, HEIGHT - 4.0), 3.5, (site as EncounterSite).color)  # the site's own (the final battle's is the Count's)
	draw_line(Vector2(WIDTH * 0.5, 0), Vector2(WIDTH * 0.5, 6), Color(1, 0.85, 0.4), 2.0)
