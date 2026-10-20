extends Control

var time := 0.0
var restored := 0


func set_restored(value: int) -> void:
	restored = value
	queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -10
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x < 2.0:
		s = get_viewport_rect().size
	_sky(s)
	_sun(s)
	_arches(s)
	_plants(s)
	_floor(s)
	_lamp(s)
	_flies(s)
	_growth(s)


func _sky(s: Vector2) -> void:
	var bands := [
		Color("8fd4ef"),
		Color("f7d7a1"),
		Color("f3b36a"),
		Color("7dba78"),
		Color("3e8f62"),
	]
	var h := s.y / float(bands.size())
	for i in bands.size():
		draw_rect(Rect2(0, h * i, s.x, h + 1.0), bands[i])


func _sun(s: Vector2) -> void:
	var sun := Vector2(s.x * 0.78, s.y * 0.16)
	draw_circle(sun, 90, Color(1, 0.93, 0.7, 0.35))
	draw_circle(sun, 46, Color("fff1c9"))
	draw_circle(sun + Vector2(-12, -10), 12, Color(1, 1, 1, 0.7))


func _arches(s: Vector2) -> void:
	var ink := Color(1, 1, 1, 0.55)
	var roof := s.y * 0.34
	draw_arc(Vector2(s.x * 0.5, roof + 40), s.x * 0.46, PI, TAU, 48, ink, 3.0, true)
	draw_arc(Vector2(s.x * 0.5, roof + 70), s.x * 0.34, PI, TAU, 40, Color(1, 1, 1, 0.35), 2.0, true)
	draw_line(Vector2(s.x * 0.08, roof + 40), Vector2(s.x * 0.08, s.y), ink, 2.0)
	draw_line(Vector2(s.x * 0.92, roof + 40), Vector2(s.x * 0.92, s.y), ink, 2.0)
	for i in 4:
		var x := s.x * (0.22 + i * 0.16)
		draw_line(Vector2(x, roof - 10), Vector2(x, s.y * 0.78), Color(1, 1, 1, 0.22), 1.5)


func _plants(s: Vector2) -> void:
	_bush(Vector2(s.x * 0.08, s.y * 0.78), 90, Color("1f7a45"))
	_bush(Vector2(s.x * 0.0, s.y * 0.84), 70, Color("14633a"))
	_bush(Vector2(s.x * 0.96, s.y * 0.74), 100, Color("2f8f55"))
	_bush(Vector2(s.x * 1.02, s.y * 0.86), 80, Color("1c6b40"))
	draw_circle(Vector2(s.x * 0.12, s.y * 0.8), 16, Color("e25b78"))
	draw_circle(Vector2(s.x * 0.2, s.y * 0.76), 11, Color("f2d36b"))
	draw_circle(Vector2(s.x * 0.86, s.y * 0.77), 14, Color("f2d36b"))
	draw_circle(Vector2(s.x * 0.93, s.y * 0.82), 10, Color("e25b78"))


func _bush(at: Vector2, radius: float, color: Color) -> void:
	draw_circle(at, radius, color)
	draw_circle(at + Vector2(-radius * 0.45, -radius * 0.35), radius * 0.72, color.lightened(0.12))
	draw_circle(at + Vector2(radius * 0.4, -radius * 0.2), radius * 0.6, color.darkened(0.08))


func _floor(s: Vector2) -> void:
	draw_rect(Rect2(0, s.y * 0.86, s.x, s.y * 0.14), Color("d9a15c"))
	draw_rect(Rect2(0, s.y * 0.86, s.x, 8), Color("f0c98a"))


func _lamp(s: Vector2) -> void:
	var sway := sin(time * 1.3) * 10.0
	var hook := Vector2(s.x * 0.5 + sway, 0)
	var cup := Vector2(s.x * 0.5 + sway * 0.3, 78)
	var lit := restored >= 1
	draw_line(hook, cup, Color("c9862f"), 3.0)
	draw_colored_polygon(PackedVector2Array([
		cup + Vector2(-28, 0),
		cup + Vector2(28, 0),
		cup + Vector2(18, 28),
		cup + Vector2(-18, 28),
	]), Color("f0c15a") if lit else Color("b9a07a"))
	draw_circle(cup + Vector2(0, 46), 16, Color("ffe3a3") if lit else Color("d9c7a4"))
	if lit:
		draw_circle(cup + Vector2(0, 70), 70, Color(1, 0.78, 0.4, 0.22))


func _growth(s: Vector2) -> void:
	if restored >= 2:
		for i in 6:
			var x := s.x * (0.08 + float(i) * 0.15)
			draw_line(Vector2(x, s.y * 0.9), Vector2(x, s.y), Color("c4843c"), 2.0)
	if restored >= 3:
		draw_circle(Vector2(s.x * 0.3, s.y * 0.72), 14, Color("e25b78"))
		draw_circle(Vector2(s.x * 0.36, s.y * 0.7), 10, Color("f2d36b"))
		draw_circle(Vector2(s.x * 0.7, s.y * 0.73), 12, Color("f28baf"))
	if restored >= 5:
		var prism := Vector2(s.x * 0.62, s.y * 0.2)
		draw_colored_polygon(PackedVector2Array([
			prism + Vector2(0, -16), prism + Vector2(14, 10), prism + Vector2(-14, 10),
		]), Color("fffdf8"))
		draw_line(prism + Vector2(-10, 4), prism + Vector2(10, 4), Color("ef5d42"), 2.0)
		draw_line(prism + Vector2(-8, 8), prism + Vector2(8, 8), Color("2f9d52"), 2.0)
		draw_line(prism + Vector2(-6, 12), prism + Vector2(6, 12), Color("7aa2f7"), 2.0)
	if restored >= 6:
		var cup := Vector2(s.x * 0.78, 90)
		draw_line(Vector2(s.x * 0.78, 0), cup, Color("c9862f"), 2.0)
		draw_circle(cup + Vector2(0, 18), 10, Color("ffe3a3"))
	if restored >= 7:
		_pot(Vector2(s.x * 0.18, s.y * 0.8))
		_pot(Vector2(s.x * 0.82, s.y * 0.78))
	if restored >= 8:
		var bowl := Vector2(s.x * 0.5, s.y * 0.8)
		draw_ellipse(bowl, 36, 12, Color("7ec8ea"))
		draw_circle(bowl + Vector2(0, -18), 5, Color("e7f7ff"))
		draw_circle(bowl + Vector2(-8, -10), 3, Color(1, 1, 1, 0.8))
	if restored >= 9:
		for i in 3:
			var wing := sin(time * 8.0 + float(i)) * 4.0
			var at := Vector2(s.x * (0.4 + 0.1 * i), s.y * 0.3)
			draw_line(at + Vector2(-8, wing), at, Color("f6d7b0"), 2.0)
			draw_line(at, at + Vector2(8, -wing), Color("f6d7b0"), 2.0)
			draw_circle(at, 3, Color("fff6ea"))
	if restored >= 10:
		draw_circle(Vector2(s.x * 0.5, s.y * 0.42), 120, Color(1, 0.9, 0.6, 0.12))
	if restored >= 40:
		draw_arc(Vector2(s.x * 0.5, s.y * 0.34), s.x * 0.2, PI, TAU, 24, Color(1, 1, 1, 0.35), 2.0, true)
	if restored >= 100:
		draw_circle(Vector2(s.x * 0.5, s.y * 0.8), 18, Color(1, 1, 1, 0.45))
	if restored >= 150:
		draw_circle(Vector2(s.x * 0.5, s.y * 0.28), 160, Color(1, 0.86, 0.45, 0.18))
		draw_circle(Vector2(s.x * 0.5, 120), 28, Color("fff6d2"))


func _pot(at: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-16, -8), at + Vector2(16, -8), at + Vector2(12, 16), at + Vector2(-12, 16),
	]), Color("c47a4a"))
	draw_circle(at + Vector2(0, -16), 14, Color("1d6b38"))
	draw_circle(at + Vector2(-6, -22), 8, Color("2f9d52"))


func _flies(s: Vector2) -> void:
	for i in 7:
		var px := s.x * (0.15 + 0.1 * i) + sin(time * 0.8 + i) * 18.0
		var py := s.y * (0.22 + 0.04 * (i % 3)) + cos(time * 1.1 + i * 0.7) * 14.0
		draw_circle(Vector2(px, py), 3.2, Color("fff4c8"))
		draw_circle(Vector2(px, py), 8.0, Color(1, 0.9, 0.5, 0.25))
