extends Control

## Запасной вид фишек: цветной кружок и белая иконка внутри.
## Сейчас не подключён. Чтобы вернуть, заменить им scripts/piece_view.gd.

const SIZE := 64.0

var kind := "tile"
var piece_id := 0
var tile_type := "fern"
var power := ""
var hp := 1
var selected := false

const COLORS := {
	"fern": Color("2fbe6a"),
	"beetle": Color("f0a202"),
	"moss": Color("1aa6a0"),
	"pearl": Color("f28baf"),
	"vine": Color("ef5d42"),
}


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_piece(cell: Dictionary) -> void:
	kind = str(cell.kind)
	piece_id = int(cell.id)
	tile_type = str(cell.get("tile", ""))
	power = str(cell.get("power", ""))
	hp = int(cell.get("hp", 1))
	queue_redraw()


func _draw() -> void:
	if kind == "glass":
		_draw_glass()
	else:
		_draw_tile()


func _draw_tile() -> void:
	var glow: Color = COLORS.get(tile_type, Color.WHITE)
	var center := Vector2(SIZE, SIZE) * 0.5
	var radius := 30.0 if not selected else 32.0
	draw_circle(center + Vector2(0, 5), radius, Color(0.35, 0.22, 0.1, 0.22))
	draw_circle(center, radius, Color("fffdf8"))
	draw_arc(center, radius - 2.0, 0, TAU, 36, glow, 6.0, true)
	draw_circle(center, radius - 8.0, glow)
	draw_circle(center + Vector2(-8, -9), 7.0, Color(1, 1, 1, 0.45))
	_draw_icon(center)
	if power == "row":
		draw_line(center + Vector2(-20, 0), center + Vector2(20, 0), Color("fff8df"), 4.0)
	elif power == "col":
		draw_line(center + Vector2(0, -20), center + Vector2(0, 20), Color("fff8df"), 4.0)
	elif power == "burst":
		draw_arc(center, 14, 0, TAU, 24, Color("fff8df"), 3.0, true)
	elif power == "lamp":
		draw_circle(center, 8, Color("fff6d2"))
	if selected:
		draw_arc(center, radius + 2.0, 0, TAU, 36, Color("fff4c4"), 3.0, true)


func _draw_glass() -> void:
	var rect := Rect2(5, 5, SIZE - 10, SIZE - 10)
	draw_rect(rect, Color("e7f7ff"))
	draw_rect(rect, Color("7ec8ea"), false, 3.0)
	draw_line(Vector2(16, 14), Vector2(30, 32), Color("ffffff"), 2.0)
	draw_line(Vector2(30, 32), Vector2(22, 50), Color("d7f1ff"), 2.0)
	if hp <= 1:
		draw_line(Vector2(40, 16), Vector2(28, 36), Color("9fd8f2"), 2.0)
		draw_line(Vector2(44, 40), Vector2(34, 52), Color("9fd8f2"), 2.0)


func _draw_icon(center: Vector2) -> void:
	var ink := Color("fffdf8")
	match tile_type:
		"fern":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -18),
				center + Vector2(12, -2),
				center + Vector2(5, 16),
				center + Vector2(-5, 16),
				center + Vector2(-12, -2),
			]), ink)
			draw_line(center + Vector2(0, -12), center + Vector2(0, 12), Color("1d8a48"), 2.0)
		"beetle":
			draw_circle(center + Vector2(0, 4), 10, ink)
			draw_circle(center + Vector2(0, -8), 5.5, ink)
			draw_line(center + Vector2(0, -2), center + Vector2(0, 12), Color("c47b00"), 1.6)
			draw_line(center + Vector2(-4, -12), center + Vector2(-12, -18), ink, 2.2)
			draw_line(center + Vector2(4, -12), center + Vector2(12, -18), ink, 2.2)
		"moss":
			for offset in [Vector2(0, 2), Vector2(-9, -2), Vector2(9, -1), Vector2(-4, 10), Vector2(6, 9)]:
				draw_circle(center + offset, 5.5, ink)
		"pearl":
			draw_circle(center, 11, ink)
			draw_circle(center + Vector2(-3, -4), 3.2, Color(1, 1, 1, 0.9))
		"vine":
			draw_line(center + Vector2(-12, 12), center + Vector2(-2, 0), ink, 3.2)
			draw_line(center + Vector2(-2, 0), center + Vector2(12, -12), ink, 3.2)
			draw_circle(center + Vector2(-8, 2), 4.5, ink)
			draw_circle(center + Vector2(6, -4), 4.5, ink)
			draw_circle(center + Vector2(12, -12), 3.5, ink)
