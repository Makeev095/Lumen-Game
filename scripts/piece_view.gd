extends Control

## Фишки — сами предметы оранжереи, с одним светом сверху-слева и тёплой тенью.
## Круглый запасной вид лежит в piece_view_tokens.gd.

const SIZE := 64.0

var kind := "tile"
var piece_id := 0
var tile_type := "fern"
var power := ""
var hp := 1
var selected := false
var fit_px := 64.0
var time := 0.0

const COLORS := {
	"fern": Color("2f9d52"),
	"beetle": Color("e8a317"),
	"moss": Color("1aa6a0"),
	"pearl": Color("f28baf"),
	"vine": Color("ef5d42"),
	"moth": Color("f6d7b0"),
}


func _ready() -> void:
	_apply_fit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if power != "" or kind == "bud":
		time += delta
		queue_redraw()


func _apply_fit() -> void:
	custom_minimum_size = Vector2(fit_px, fit_px)
	size = custom_minimum_size
	pivot_offset = size * 0.5


func set_piece(cell: Dictionary) -> void:
	kind = str(cell.kind)
	piece_id = int(cell.get("id", 0))
	tile_type = str(cell.get("tile", ""))
	power = str(cell.get("power", ""))
	hp = int(cell.get("hp", 1))
	z_index = 3 if power != "" else 0
	queue_redraw()


func _draw() -> void:
	var fit := size.x / SIZE
	if fit <= 0.0:
		fit = 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(fit, fit))
	_shadow()
	if kind == "glass":
		_glass()
	elif kind == "bud":
		_bud()
	elif power != "":
		_bonus_glow()
		_power()
	else:
		_creature()
	if selected:
		draw_arc(Vector2(32, 30), 30, 0, TAU, 36, Color("fff1c2"), 2.6, true)


func _shadow() -> void:
	draw_ellipse(Vector2(34, 56), 18, 6, Color(0.28, 0.18, 0.08, 0.28))


func _bonus_glow() -> void:
	var pulse := 0.5 + 0.5 * sin(time * 4.2)
	var glow := _bonus_color()
	var center := Vector2(32, 32)
	draw_circle(center, 38.0, Color(0.28, 0.12, 0.02, 0.45))
	var halo := glow
	halo.a = 0.92
	draw_circle(center, 33.0 + pulse * 3.0, halo)
	draw_circle(center, 22.0, Color("fffdf6"))
	draw_arc(center, 30.0, 0, TAU, 48, Color("fffdf8"), 5.0, true)
	draw_arc(center, 36.0 + pulse * 5.0, 0, TAU, 48, glow, 3.5, true)
	for i in 8:
		var angle := time * 2.4 + TAU * float(i) / 8.0
		var dir := Vector2(cos(angle), sin(angle))
		var near := center + dir * 28.0
		var far := center + dir * (44.0 + pulse * 8.0)
		draw_line(near, far, Color("fffdf8"), 3.0, true)
		draw_circle(far, 4.2, glow)
		draw_circle(far, 2.2, Color("fffdf8"))


func _bonus_color() -> Color:
	match power:
		"burst":
			return Color("ff9a3c")
		"heli":
			return Color("ff9a1a")
		"spark":
			return Color("ffc107")
		"rainbow":
			var bands := [Color("ef5d42"), Color("f0a202"), Color("2f9d52"), Color("7aa2f7"), Color("f28baf")]
			return bands[int(time * 2.0) % bands.size()]
		_:
			return Color("ffd56a")


func _creature() -> void:
	match tile_type:
		"beetle":
			_beetle()
		"moss":
			_moss()
		"pearl":
			_pearl()
		"vine":
			_vine()
		"moth":
			_moth()
		_:
			_fern()


func _power() -> void:
	match power:
		"burst":
			_bomb()
		"heli":
			_heli()
		"spark":
			_spark()
		"rainbow":
			_rainbow()
		"col":
			_arrow(false)
		_:
			_arrow(true)
	if power != "rainbow":
		_pip()


func _ink() -> Color:
	return COLORS.get(tile_type, Color("2f9d52"))


func _pip() -> void:
	draw_circle(Vector2(50, 50), 7.5, Color("fffdf8"))
	draw_circle(Vector2(50, 50), 5.2, _ink())
	draw_circle(Vector2(48, 48), 1.8, Color(1, 1, 1, 0.7))


func _fern() -> void:
	var stem := Color("1d6b38")
	var leaf := Color("2f9d52")
	var young := Color("8ed97a")
	draw_line(Vector2(32, 57), Vector2(32, 10), stem, 3.4)
	var bands := [48.0, 38.0, 28.0, 18.0]
	var reach := [15.0, 20.0, 18.0, 12.0]
	for i in bands.size():
		var y: float = bands[i]
		var w: float = reach[i]
		var tint: Color = leaf if i % 2 == 0 else young
		_leaflet(Vector2(32, y), Vector2(32 - w, y - 9), -5, tint, stem)
		_leaflet(Vector2(32, y), Vector2(32 + w, y - 9), 5, tint, stem)
	draw_colored_polygon(PackedVector2Array([
		Vector2(32, 6), Vector2(38, 16), Vector2(32, 13), Vector2(26, 16),
	]), Color("e7ffd8"))
	draw_circle(Vector2(29, 16), 2.2, Color(1, 1, 1, 0.65))


func _leaflet(stem: Vector2, tip: Vector2, curl: float, fill: Color, vein: Color) -> void:
	var mid := (stem + tip) * 0.5 + Vector2(0, curl)
	draw_colored_polygon(PackedVector2Array([
		stem,
		mid + Vector2(0, -4),
		tip,
		mid + Vector2(0, 3),
	]), fill)
	draw_line(stem, tip, vein, 1.3)


func _beetle() -> void:
	var shell := Color("e8a317")
	var dark := Color("8a5608")
	var spot := Color("fff1c4")
	for side in [-1.0, 1.0]:
		for i in 3:
			var y := 30.0 + float(i) * 7.0
			var foot := Vector2(32 + side * 24, y + 3)
			draw_line(Vector2(32, y), foot, dark, 2.3)
			draw_circle(foot, 2.1, dark)
	draw_ellipse(Vector2(32, 38), 15, 16, dark)
	draw_ellipse(Vector2(32, 37), 13, 14, shell)
	draw_line(Vector2(32, 26), Vector2(32, 50), dark, 1.5)
	draw_circle(Vector2(27, 36), 2.4, spot)
	draw_circle(Vector2(37, 40), 2.2, spot)
	draw_circle(Vector2(32, 20), 8, shell)
	draw_circle(Vector2(32, 20), 8, dark, false, 1.6)
	draw_circle(Vector2(29, 19), 1.6, Color("2a2114"))
	draw_circle(Vector2(35, 19), 1.6, Color("2a2114"))
	draw_line(Vector2(27, 14), Vector2(18, 6), dark, 2.0)
	draw_line(Vector2(37, 14), Vector2(46, 6), dark, 2.0)
	draw_circle(Vector2(18, 6), 2.4, spot)
	draw_circle(Vector2(46, 6), 2.4, spot)
	draw_circle(Vector2(27, 32), 3.0, Color(1, 1, 1, 0.35))


func _moss() -> void:
	var deep := Color("0e6e68")
	var mid := Color("1aa6a0")
	var tip := Color("b7fff4")
	var mounds := [
		Vector2(18, 44), Vector2(32, 40), Vector2(46, 45),
		Vector2(24, 34), Vector2(40, 33),
	]
	var radii := [11.0, 13.0, 10.0, 8.0, 7.5]
	for i in mounds.size():
		draw_circle(mounds[i] + Vector2(1, 2), radii[i], deep)
	for i in mounds.size():
		draw_circle(mounds[i], radii[i], mid if i != 1 else mid.lightened(0.12))
	draw_circle(Vector2(28, 36), 3.0, tip)
	draw_circle(Vector2(38, 38), 2.2, tip)
	draw_circle(Vector2(20, 42), 1.8, Color("e9fff8"))
	draw_circle(Vector2(46, 42), 1.6, Color("e9fff8"))


func _pearl() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(32, 46), Vector2(46, 40), Vector2(42, 50), Vector2(22, 50), Vector2(18, 40),
	]), Color("7dcea0"))
	draw_line(Vector2(32, 46), Vector2(32, 40), Color("1d6b38"), 1.4)
	draw_circle(Vector2(32, 30), 15, Color("f7c3d4"))
	draw_circle(Vector2(32, 30), 15, Color("c45b86"), false, 1.8)
	draw_circle(Vector2(32, 30), 11, Color("fff0f5"))
	draw_circle(Vector2(27, 25), 4.2, Color(1, 1, 1, 0.95))
	draw_circle(Vector2(36, 34), 2.0, Color("f28baf"))


func _vine() -> void:
	var stem := Color("a33a28")
	var leaf := Color("ef5d42")
	draw_line(Vector2(14, 52), Vector2(24, 36), stem, 3.2)
	draw_line(Vector2(24, 36), Vector2(40, 40), stem, 3.2)
	draw_line(Vector2(40, 40), Vector2(50, 18), stem, 3.2)
	_leaf(Vector2(16, 46), Vector2(8, 34), leaf)
	_leaf(Vector2(30, 40), Vector2(22, 28), leaf.lightened(0.08))
	_leaf(Vector2(46, 24), Vector2(56, 14), leaf)
	draw_circle(Vector2(50, 16), 3.2, Color("ffd0c4"))


func _leaf(base: Vector2, tip: Vector2, fill: Color) -> void:
	var side := (tip - base).orthogonal().normalized() * 6.0
	draw_colored_polygon(PackedVector2Array([base, tip + side, tip, tip - side]), fill)
	draw_line(base, tip, fill.darkened(0.35), 1.2)


func _bud() -> void:
	var pulse := 0.5 + 0.5 * sin(time * 2.4)
	var sepal := Color("1d6b38")
	var petal := Color("f28baf") if hp > 1 else Color("fff0f5")
	draw_circle(Vector2(32, 40), 8, sepal)
	for i in 5:
		var angle := -PI / 2.0 + TAU * float(i) / 5.0 + pulse * 0.08
		var at := Vector2(32, 30) + Vector2(cos(angle), sin(angle)) * (12.0 + pulse * 2.0)
		draw_circle(at, 7.0, sepal.lightened(0.15))
		draw_circle(at, 5.2, petal)
	draw_circle(Vector2(32, 30), 5.5, Color("fff6ea"))
	draw_circle(Vector2(30, 28), 1.8, Color(1, 1, 1, 0.8))
	if hp <= 1:
		draw_line(Vector2(26, 22), Vector2(38, 36), Color("c45b86"), 1.4)


func _moth() -> void:
	var wing := Color("f6d7b0")
	var edge := Color("8a5a3a")
	draw_colored_polygon(PackedVector2Array([
		Vector2(32, 34), Vector2(10, 22), Vector2(16, 40), Vector2(32, 36),
	]), wing)
	draw_colored_polygon(PackedVector2Array([
		Vector2(32, 34), Vector2(54, 22), Vector2(48, 40), Vector2(32, 36),
	]), wing)
	draw_line(Vector2(32, 34), Vector2(12, 24), edge, 1.2)
	draw_line(Vector2(32, 34), Vector2(52, 24), edge, 1.2)
	draw_ellipse(Vector2(32, 36), 4, 10, Color("6b3a22"))
	draw_circle(Vector2(32, 24), 4.2, Color("2a2114"))
	draw_circle(Vector2(30.5, 23), 1.1, Color("fff6ea"))
	draw_circle(Vector2(33.5, 23), 1.1, Color("fff6ea"))
	draw_line(Vector2(30, 20), Vector2(24, 12), edge, 1.2)
	draw_line(Vector2(34, 20), Vector2(40, 12), edge, 1.2)


func _glass() -> void:
	var edge := Color("6ea4c4")
	var ice := Color("f4fbff")
	var center := Vector2(32, 26)
	var pts := PackedVector2Array()
	for i in 6:
		var angle := -PI / 2.0 + TAU * float(i) / 6.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * 15.0)
	draw_colored_polygon(pts, ice)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, edge, 2.2, true)
	draw_line(Vector2(26, 18), Vector2(30, 26), Color.WHITE, 2.0)
	var drips := [Vector2(22, 38), Vector2(32, 40), Vector2(43, 37)]
	var lengths := [10.0, 16.0, 9.0]
	if hp <= 1:
		lengths = [14.0, 20.0, 12.0]
	for i in drips.size():
		var top: Vector2 = drips[i]
		var drop := top + Vector2(0, lengths[i])
		draw_colored_polygon(PackedVector2Array([
			top + Vector2(-3, 0), top + Vector2(3, 0), drop,
		]), Color("e7f6ff"))
		draw_line(top, drop, edge, 1.3)
	if hp <= 1:
		draw_line(Vector2(20, 16), Vector2(42, 34), Color("8eafc4"), 1.6)
		draw_line(Vector2(40, 14), Vector2(28, 32), Color("8eafc4"), 1.4)


func _bomb() -> void:
	var band := _ink()
	draw_circle(Vector2(32, 36), 16, Color("2c241c"))
	draw_circle(Vector2(32, 36), 14, Color("4a382c"))
	draw_circle(Vector2(26, 30), 4.5, Color(1, 1, 1, 0.16))
	draw_rect(Rect2(18, 33, 28, 6), band)
	draw_rect(Rect2(18, 35, 28, 2), Color(1, 1, 1, 0.35))
	var spark := Vector2(44, 14 + sin(time * 18.0) * 1.4)
	draw_line(Vector2(38, 24), spark, Color("6b4428"), 2.4)
	draw_circle(spark, 6.0, Color(1, 0.72, 0.28, 0.45))
	draw_circle(spark, 3.1, Color("ffd27a"))


func _heli() -> void:
	var body := _ink()
	var dark := body.darkened(0.38)
	draw_line(Vector2(34, 36), Vector2(50, 26), dark, 3.0)
	draw_circle(Vector2(51, 25), 3.0, dark)
	draw_circle(Vector2(28, 40), 12, dark)
	draw_circle(Vector2(28, 39), 10, body)
	draw_circle(Vector2(24, 35), 3.4, Color(1, 1, 1, 0.4))
	draw_line(Vector2(16, 50), Vector2(40, 50), dark, 2.2)
	draw_line(Vector2(18, 50), Vector2(18, 46), dark, 2.0)
	draw_line(Vector2(38, 50), Vector2(38, 46), dark, 2.0)
	var mast := Vector2(28, 24)
	draw_line(Vector2(28, 32), mast, dark, 2.2)
	var angle := time * 16.0
	var dir := Vector2(cos(angle), sin(angle))
	draw_line(mast - dir * 18.0, mast + dir * 18.0, Color("f7f1e4"), 2.6)
	draw_circle(mast, 2.6, Color("fff8ea"))


func _spark() -> void:
	var core := _ink()
	draw_circle(Vector2(32, 32), 18, Color(1, 0.93, 0.7, 0.35))
	draw_circle(Vector2(32, 32), 13, Color("fff6dc"))
	draw_circle(Vector2(32, 32), 8, core)
	draw_circle(Vector2(28, 28), 3.0, Color(1, 1, 1, 0.9))
	for i in 6:
		var angle := time * 2.4 + TAU * float(i) / 6.0
		var at := Vector2(32, 32) + Vector2(cos(angle), sin(angle)) * 16.0
		draw_circle(at, 2.3, Color("ffe08a"))


func _rainbow() -> void:
	var bands := [
		Color("ef5d42"), Color("f0a202"), Color("2f9d52"),
		Color("1aa6a0"), Color("7aa2f7"), Color("f28baf"),
	]
	draw_circle(Vector2(32, 32), 16, Color("2a2118"))
	draw_circle(Vector2(32, 32), 14, Color("fffdf8"))
	for i in bands.size():
		var a0 := -PI / 2.0 + TAU * float(i) / float(bands.size())
		var a1 := a0 + TAU / float(bands.size()) - 0.05
		draw_arc(Vector2(32, 32), 10.5, a0, a1, 10, bands[i], 3.6, true)
	draw_circle(Vector2(27, 27), 3.2, Color(1, 1, 1, 0.95))


func _arrow(horizontal: bool) -> void:
	var gold := Color("f6e2a8")
	var edge := Color("c47a22")
	if horizontal:
		draw_line(Vector2(8, 32), Vector2(46, 32), edge, 8.0)
		draw_line(Vector2(8, 32), Vector2(46, 32), gold, 5.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(42, 22), Vector2(58, 32), Vector2(42, 42),
		]), gold)
		draw_line(Vector2(14, 26), Vector2(14, 38), edge, 2.0)
	else:
		draw_line(Vector2(32, 56), Vector2(32, 18), edge, 8.0)
		draw_line(Vector2(32, 56), Vector2(32, 18), gold, 5.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(22, 22), Vector2(32, 6), Vector2(42, 22),
		]), gold)
		draw_line(Vector2(26, 50), Vector2(38, 50), edge, 2.0)
