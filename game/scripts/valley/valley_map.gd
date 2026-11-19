class_name ValleyMap
extends Control
## The valley map (M): an old parchment chart of the regions, villages, places and where you
## are, under a fog of war where you haven't been yet (FogOfWar).
## Zoom (user, 2026-11-05) with the mouse wheel or + and -: all the way out it shows only the
## settlements; zoomed in, the big places, caves, towers and encounters appear, with labels
## that grow with the zoom. Every kind of place has its own icon, and a quest you've taken on
## shows as a pulsing gold beacon.

## Map height on screen, in pixels (the valley is twice as long as it is wide).
const SIZE := 660.0
const ZOOMS := [1.0, 2.0, 4.0]
var valley: Node
var zoom_step := 0
var _chart: Control  ## the parchment's inside: everything drawn on it is clipped to it


func _ready() -> void:
	_chart = Control.new()
	_chart.clip_contents = true
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chart)
	_chart.draw.connect(_draw_chart)


func zoom() -> float:
	return ZOOMS[zoom_step]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var step := 0
	if event is InputEventMouseButton and event.pressed:
		step = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else (-1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0)
	elif event is InputEventKey and event.pressed:
		step = 1 if event.keycode in [KEY_EQUAL, KEY_KP_ADD] else (-1 if event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT] else 0)
	if step != 0:
		zoom_step = clampi(zoom_step + step, 0, ZOOMS.size() - 1)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		var sheet := _sheet()
		_chart.position = sheet.position + Vector2(10, 10)
		_chart.size = sheet.size - Vector2(20, 20)
		queue_redraw()
		_chart.queue_redraw()


func _sheet() -> Rect2:
	var scale := SIZE / (ValleyTerrain.HALF_L * 2.0)
	var half := Vector2(ValleyTerrain.HALF_W, ValleyTerrain.HALF_L) * scale
	return Rect2(size * 0.5 - half - Vector2(40, 30), half * 2.0 + Vector2(80, 50))


func _draw() -> void:
	if not Run.active or valley == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	draw_style_box(UiStyle.parchment(), _sheet())
	var font := UiStyle.font()
	var center := size * 0.5
	var legend := "House: village   Hut: hamlet   Keep: big place   Arch: cave   Spire: tower   Red cross: held by enemies   Diamond: encounter   Gold ring: your quest   ·   Wheel or +/-: zoom   ·   M or Esc to close"
	var lw := font.get_string_size(legend, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(center.x - lw * 0.5, center.y + SIZE * 0.5 + 34), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.GOLD)
	var water := "Blue water: swim, use a bridge (brown) or jump a mount. Dark water (rapids, deep lakes): Frogfolk only"
	var ww := font.get_string_size(water, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(center.x - ww * 0.5, center.y + SIZE * 0.5 + 54), water, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.TEXT)


## World point -> chart point: the whole valley at zoom 1, around you when zoomed in.
func to_chart(p: Vector2) -> Vector2:
	var scale := SIZE / (ValleyTerrain.HALF_L * 2.0) * zoom()
	var focus := Vector2.ZERO
	if zoom() > 1.0 and valley.player != null and is_instance_valid(valley.player):
		focus = Vector2(valley.player.global_position.x, valley.player.global_position.z)
	return _chart.size * 0.5 + (p - focus) * scale


func _draw_chart() -> void:
	if not Run.active or valley == null:
		return
	var c := _chart
	var s: RunState = Run.state
	var z := zoom()
	var scale := SIZE / (ValleyTerrain.HALF_L * 2.0) * z
	var font := UiStyle.font()
	var text_size := int(12 * clampf(sqrt(z), 1.0, 2.0))
	var terrain: ValleyTerrain = valley.terrain
	var outline := PackedVector2Array()
	for i in 97:
		outline.append(to_chart(ValleyTerrain.edge_point(TAU * i / 96.0)))
	c.draw_colored_polygon(outline, Color(0.74, 0.69, 0.5))
	# Regions, tinted by who holds them.
	var home: String = s.flags.get("home_region", "")
	for region in s.regions:
		var r: Dictionary = s.regions[region]
		var col := Color(0.35, 0.45, 0.3)
		if r.get("corrupted", false):
			col = Color(0.45, 0.15, 0.55)
		elif region == home:
			col = Color(0.75, 0.6, 0.25)
		elif r.get("tribe", "") != "":
			col = {"allied": Color(0.3, 0.5, 0.8)}.get(s.tribes.get(r.tribe, {}).get("status", ""), Color(0.6, 0.5, 0.35))
		c.draw_circle(to_chart(ValleyTerrain.region_center(region)), 240.0 * scale, Color(col, 0.45))
	# Water, roads, bridges.
	for i in terrain.rivers.size():
		var river: Dictionary = terrain.rivers[i]
		var line := PackedVector2Array()
		for p in terrain.river_line(i):
			if ValleyTerrain.shape_q(p.x, p.y) <= 1.0:
				line.append(to_chart(p))
		var width := (3.0 if river.branch else (6.0 if river.axis == "z" else 4.0)) * sqrt(z)
		c.draw_polyline(line, Color(0.08, 0.15, 0.25) if river.rapids else Color(0.3, 0.55, 0.85), width)
	for lake in terrain.lakes:
		c.draw_circle(to_chart(lake.pos), (lake.radius + 6.0) * scale, Color(0.08, 0.15, 0.25) if lake.deep else Color(0.3, 0.55, 0.85))
	for road in terrain.roads:
		var road_line := PackedVector2Array()
		for q in road.line:
			road_line.append(to_chart(q))
		c.draw_polyline(road_line, Color(0.55, 0.4, 0.24, 0.85), 2.0 * sqrt(z))
	for b in terrain.bridges:
		c.draw_line(to_chart(b.a), to_chart(b.b), Color(0.45, 0.3, 0.16), 4.0 * sqrt(z))
	# Settlements: always.
	for region in s.regions:
		var r: Dictionary = s.regions[region]
		if r.get("tribe", "") == "":
			continue
		var at := to_chart(ValleyTerrain.region_center(region))
		_house(c, at, 8.0 * sqrt(z), UiStyle.INK)
		var name: String = "Your camp" if region == home else GameData.text(GameData.race(r.tribe), "village_name")
		_label(c, font, at + Vector2(0, 20 * sqrt(z)), name, text_size + 1)
	for h in terrain.hamlets:
		_hut(c, to_chart(h.pos), 4.0 * sqrt(z), Color(0.35, 0.25, 0.14))
	var events: Array = valley.events.events if valley.events != null else []
	# Zoomed in: the places to find.
	if z > 1.0:
		var held := {}
		for ev in events:
			if ev.kind == "hold" and not ev.done:
				held[Vector2(ev.pos.x, ev.pos.z).snapped(Vector2.ONE)] = true
		for l in terrain.landmarks:
			var lp := to_chart(l.pos)
			var kind: String = l.get("kind", "")
			if kind == "cave":
				_arch(c, lp, 6.0 * sqrt(z))
			elif kind == "tower":
				_spire(c, lp, 7.0 * sqrt(z))
			else:
				_keep(c, lp, 7.0 * sqrt(z))
				if held.has((l.pos as Vector2).snapped(Vector2.ONE)):
					_cross(c, lp, 7.0 * sqrt(z))
			if kind == "" or z >= 4.0:
				_label(c, font, lp + Vector2(0, -12 * sqrt(z)), l.name, text_size)
		for id in EncounterSystem.available(s):
			var p := to_chart(ValleyTerrain.site_point(s, id))
			var def := GameData.row("encounters", s.encounters[id].def)
			var col: Color = EncounterSite.COLORS.get(GameData.text(def, "type"), Color.WHITE)
			if id == "final_battle":
				col = EncounterSite.COLORS["Evil Tribe"]
			_diamond(c, p, 6.0 * sqrt(z), col)
	# Fog of war: what you haven't been near yet stays dark (FogOfWar).
	if valley.fog != null:
		c.draw_texture_rect(valley.fog.get_texture(), Rect2(to_chart(Vector2(-ValleyTerrain.HALF_W, -ValleyTerrain.HALF_L)),
				Vector2(ValleyTerrain.HALF_W, ValleyTerrain.HALF_L) * 2.0 * scale), false, Color(0.36, 0.27, 0.17))
	c.draw_polyline(outline, UiStyle.INK, 3.0)
	# Your quest: a gold beacon, pulsing (seen through the fog too).
	for ev in events:
		if ev.kind == "quest" and ev.choice == "accepted" and not ev.done:
			var target: Vector3 = ev.pos
			for f in ev.foes:
				if is_instance_valid(f) and not f.is_dead():
					target = f.global_position
					break
			var q := to_chart(Vector2(target.x, target.z))
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
			c.draw_arc(q, 9.0 + pulse * 6.0, 0.0, TAU, 24, Color(1.0, 0.8, 0.2, 1.0 - pulse * 0.5), 3.0)
			c.draw_line(q, q - Vector2(0, 26), Color(1.0, 0.85, 0.3, 0.8), 3.0)
	# You.
	var player: Node3D = valley.player
	if player != null and is_instance_valid(player):
		var pp := to_chart(Vector2(player.global_position.x, player.global_position.z))
		var f: Vector3 = player.facing
		var dir := Vector2(f.x, f.z).normalized()
		var side := dir.orthogonal()
		c.draw_colored_polygon(PackedVector2Array([pp + dir * 11, pp - dir * 6 + side * 6, pp - dir * 6 - side * 6]), Color(0.7, 0.05, 0.05))


# ---------------------------------------------------------------- icons, inked on the parchment

func _label(c: Control, font: Font, at: Vector2, text: String, px: int) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	c.draw_string(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, UiStyle.INK)


func _house(c: Control, at: Vector2, r: float, col: Color) -> void:
	c.draw_rect(Rect2(at - Vector2(r, r * 0.4), Vector2(r * 2.0, r * 1.4)), col)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 1.3, -r * 0.4), at + Vector2(0, -r * 1.4), at + Vector2(r * 1.3, -r * 0.4)]), col)


func _hut(c: Control, at: Vector2, r: float, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-r, r), at + Vector2(0, -r), at + Vector2(r, r)]), col)


func _keep(c: Control, at: Vector2, r: float) -> void:
	var stone := Color(0.3, 0.27, 0.24)
	c.draw_rect(Rect2(at - Vector2(r, r * 0.6), Vector2(r * 2.0, r * 1.6)), stone)
	for k in 3:
		c.draw_rect(Rect2(at + Vector2(-r + k * r * 0.8, -r * 1.0), Vector2(r * 0.45, r * 0.45)), stone)


func _arch(c: Control, at: Vector2, r: float) -> void:
	c.draw_circle(at, r, Color(0.25, 0.2, 0.15))
	c.draw_rect(Rect2(at - Vector2(r, 0), Vector2(r * 2.0, r)), Color(0.74, 0.69, 0.5))
	c.draw_circle(at + Vector2(0, r * 0.15), r * 0.5, Color(0.06, 0.04, 0.03))


func _spire(c: Control, at: Vector2, r: float) -> void:
	c.draw_rect(Rect2(at - Vector2(r * 0.35, r), Vector2(r * 0.7, r * 2.0)), Color(0.32, 0.28, 0.24))
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 0.55, -r), at + Vector2(0, -r * 1.7), at + Vector2(r * 0.55, -r)]), Color(0.45, 0.12, 0.08))


func _cross(c: Control, at: Vector2, r: float) -> void:
	c.draw_line(at - Vector2(r, r), at + Vector2(r, r), Color(0.75, 0.08, 0.05), 3.0)
	c.draw_line(at + Vector2(-r, r), at + Vector2(r, -r), Color(0.75, 0.08, 0.05), 3.0)


func _diamond(c: Control, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	c.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	c.draw_polyline(pts, UiStyle.INK, 1.5)
