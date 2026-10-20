extends Control

var time := 0.0
var blink := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(170, 200)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	time += delta
	blink = maxf(blink - delta, 0.0)
	if blink <= 0.0 and randf() < delta * 0.35:
		blink = 0.12
	queue_redraw()


func cheer() -> void:
	var base := scale
	var tween := create_tween()
	tween.tween_property(self, "scale", base * Vector2(1.14, 0.88), 0.07)
	tween.tween_property(self, "scale", base * Vector2(0.94, 1.1), 0.09)
	tween.tween_property(self, "scale", base, 0.12)


func _draw() -> void:
	var c := Vector2(85, 118)
	draw_ellipse(c + Vector2(0, 36), 92, 24, Color(0.2, 0.25, 0.15, 0.18))
	draw_circle(c + Vector2(-34, 8), 16, Color("2f8f55"))
	draw_circle(c + Vector2(34, 10), 14, Color("3eaf68"))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-28, -8),
		c + Vector2(28, -8),
		c + Vector2(40, 48),
		c + Vector2(-40, 48),
	]), Color("f6d7b0"))
	draw_circle(c + Vector2(0, -6), 38, Color("ffe7c8"))
	draw_circle(c + Vector2(0, -8), 34, Color("fff6ea"))
	draw_circle(c + Vector2(-12, -10), 8, Color("243028"))
	draw_circle(c + Vector2(12, -10), 8, Color("243028"))
	if blink <= 0.0:
		draw_circle(c + Vector2(-10, -12), 2.4, Color.WHITE)
		draw_circle(c + Vector2(14, -12), 2.4, Color.WHITE)
	else:
		draw_line(c + Vector2(-18, -10), c + Vector2(-6, -10), Color("243028"), 2.0)
		draw_line(c + Vector2(6, -10), c + Vector2(18, -10), Color("243028"), 2.0)
	draw_arc(c + Vector2(0, 2), 8, 0.2, PI - 0.2, 12, Color("e07a62"), 2.0, true)
	var bob := sin(time * 2.2) * 3.0
	draw_line(c + Vector2(-10, -36), c + Vector2(-22, -58 + bob), Color("3eaf68"), 3.0)
	draw_line(c + Vector2(10, -36), c + Vector2(22, -58 - bob), Color("3eaf68"), 3.0)
	draw_circle(c + Vector2(-22, -58 + bob), 6, Color("ffe08a"))
	draw_circle(c + Vector2(22, -58 - bob), 6, Color("ffe08a"))
	var lamp := c + Vector2(48, 18)
	draw_line(c + Vector2(24, 10), lamp, Color("c9862f"), 4.0)
	draw_circle(lamp, 16, Color("ffe7a3"))
	draw_circle(lamp, 8, Color("fff8df"))
	draw_circle(lamp, 22, Color(1, 0.85, 0.4, 0.35))

