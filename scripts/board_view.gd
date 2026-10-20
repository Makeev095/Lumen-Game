extends Control

const TILE := 64
const GAP := 8
const Piece = preload("res://scripts/piece_view.gd")

signal hud_updated(hud: Dictionary)
signal matched

var tiles := {}
var glasses := {}
var animating := false
var grid_rows := 8
var grid_cols := 8


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(_span(8), _span(8))


func build(grid: Array) -> void:
	for child in get_children():
		child.queue_free()
	tiles.clear()
	glasses.clear()
	if grid.is_empty():
		return
	grid_rows = grid.size()
	grid_cols = grid[0].size()
	custom_minimum_size = Vector2(_span(grid_cols), _span(grid_rows))
	size = custom_minimum_size
	_add_tray()
	for r in grid.size():
		for c in grid[r].size():
			var cell = grid[r][c]
			if cell == null:
				continue
			_place_new(cell, _origin(r, c))


func cell_at(pos: Vector2, rows: int, cols: int) -> Vector2i:
	var step := TILE + GAP
	var c := int(pos.x / step)
	var r := int(pos.y / step)
	if r < 0 or c < 0 or r >= rows or c >= cols:
		return Vector2i(-1, -1)
	if pos.x > c * step + TILE or pos.y > r * step + TILE:
		return Vector2i(-1, -1)
	return Vector2i(r, c)


func animate_swap(r1: int, c1: int, r2: int, c2: int) -> void:
	var first = _piece_at(r1, c1)
	var second = _piece_at(r2, c2)
	if first == null or second == null:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(first, "position", _origin(r2, c2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(second, "position", _origin(r1, c1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play("swap")
	await tween.finished


func shake_cells(r1: int, c1: int, r2: int, c2: int) -> void:
	for piece in [_piece_at(r1, c1), _piece_at(r2, c2)]:
		if piece == null:
			continue
		var origin: Vector2 = piece.position
		var tween := create_tween()
		tween.tween_property(piece, "position:x", origin.x - 6, 0.05)
		tween.tween_property(piece, "position:x", origin.x + 6, 0.08)
		tween.tween_property(piece, "position", origin, 0.07)


func set_selected(r: int, c: int) -> void:
	for id in tiles:
		var piece = tiles[id]
		var was: bool = piece.selected
		piece.selected = false
		if was:
			piece.queue_redraw()
	var piece = _piece_at(r, c)
	if piece != null and piece.kind == "tile":
		piece.selected = true
		piece.queue_redraw()


func clear_selected() -> void:
	set_selected(-1, -1)


func play_frames(frames: Array) -> void:
	animating = true
	for frame in frames:
		if frame.has("hud"):
			hud_updated.emit(frame.hud)
		if frame.type == "clear":
			await _play_clear(frame)
		elif frame.type == "fall":
			await _play_fall(frame)
	animating = false


func _play_clear(frame: Dictionary) -> void:
	var combo := int(frame.get("combo", 1))
	if combo >= 2:
		_praise(combo)
	var effects: Array = frame.get("effects", [])
	for effect in effects:
		await _play_effect(effect)
	var used := false
	var fade: Tween = null
	for id in frame.pop_ids:
		var piece = tiles.get(int(id))
		if piece == null:
			continue
		used = true
		_burst(piece.position + Vector2(32, 32), piece.tile_type)
		var pop := create_tween()
		pop.tween_property(piece, "scale", Vector2(1.22, 1.22), 0.07).set_trans(Tween.TRANS_QUAD)
		pop.set_parallel(true)
		pop.tween_property(piece, "scale", Vector2(0.15, 0.15), 0.14)
		pop.tween_property(piece, "modulate:a", 0.0, 0.14)
	var anchor = frame.power_up
	if anchor != null:
		var piece = tiles.get(int(anchor.id))
		if piece != null:
			piece.power = str(anchor.power)
			piece.queue_redraw()
			piece.scale = Vector2(0.35, 0.35)
			var born := create_tween()
			born.tween_property(piece, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK)
			born.tween_property(piece, "scale", Vector2.ONE, 0.14)
			Sound.play("power")
	for crack in frame.cracks:
		var piece = glasses.get(int(crack.id))
		if piece == null:
			continue
		piece.hp = int(crack.hp)
		piece.queue_redraw()
		if piece.hp <= 0:
			used = true
			if fade == null:
				fade = create_tween()
				fade.set_parallel(true)
			fade.tween_property(piece, "modulate:a", 0.0, 0.16)
	if used:
		matched.emit()
		if effects.is_empty():
			var voice := "match"
			for id in frame.pop_ids:
				var speaker = tiles.get(int(id))
				if speaker != null and str(speaker.tile_type) != "":
					voice = str(speaker.tile_type)
					break
			Sound.play(voice)
		await get_tree().create_timer(0.22).timeout
	if not frame.cracks.is_empty():
		var broke := false
		for crack in frame.cracks:
			if int(crack.hp) <= 0:
				broke = true
		Sound.play("shatter" if broke else "glass")
	for id in frame.pop_ids:
		var piece = tiles.get(int(id))
		if piece == null:
			continue
		tiles.erase(int(id))
		piece.queue_free()
	for crack in frame.cracks:
		if int(crack.hp) > 0:
			continue
		var piece = glasses.get(int(crack.id))
		if piece == null:
			continue
		glasses.erase(int(crack.id))
		piece.queue_free()


func _play_fall(frame: Dictionary) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	var grid: Array = frame.grid
	var spawn_dist := {}
	for spawn in frame.spawns:
		spawn_dist[int(spawn.id)] = int(spawn.dist)
	for r in grid.size():
		for c in grid[r].size():
			var cell = grid[r][c]
			if cell == null:
				continue
			var dest := _origin(r, c)
			if cell.kind == "tile":
				var piece = tiles.get(int(cell.id))
				if piece == null:
					piece = _place_new(cell, dest + Vector2(0, -spawn_dist.get(int(cell.id), 1) * (TILE + GAP)))
					piece.modulate.a = 0.0
					tween.tween_property(piece, "modulate:a", 1.0, 0.28)
				else:
					piece.set_piece(cell)
				tween.tween_property(piece, "position", dest, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			elif not glasses.has(int(cell.id)):
				_place_new(cell, dest)
	await tween.finished


func _place_new(cell: Dictionary, at: Vector2):
	var piece = Piece.new()
	piece.set_piece(cell)
	piece.position = at
	add_child(piece)
	if str(cell.kind) == "glass" or str(cell.kind) == "bud":
		glasses[int(cell.id)] = piece
	else:
		tiles[int(cell.id)] = piece
	return piece


func _piece_at(r: int, c: int):
	var wanted := _origin(r, c)
	for id in tiles:
		if tiles[id].position.distance_to(wanted) < 4.0:
			return tiles[id]
	for id in glasses:
		if glasses[id].position.distance_to(wanted) < 4.0:
			return glasses[id]
	return null


func _add_tray() -> void:
	var tray := Panel.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.position = Vector2(-14, -14)
	tray.size = custom_minimum_size + Vector2(28, 28)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("e4f0d4")
	box.border_color = Color("c9862f")
	box.set_border_width_all(8)
	box.set_corner_radius_all(26)
	box.shadow_color = Color(0.4, 0.25, 0.08, 0.28)
	box.shadow_size = 16
	tray.add_theme_stylebox_override("panel", box)
	add_child(tray)


func _praise(combo: int) -> void:
	var words := ["Хорошо", "Отлично", "Чудесно", "Сияние"]
	var index := combo - 2
	if index >= words.size():
		index = words.size() - 1
	if index < 0:
		index = 0
	var label := Label.new()
	label.text = words[index]
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("c47a22"))
	label.position = Vector2(18, 6)
	label.z_index = 8
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", -28.0, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.finished.connect(label.queue_free)


func _play_effect(effect: Dictionary) -> void:
	var kind := str(effect.kind)
	var origin := _origin(int(effect.r), int(effect.c)) + Vector2(32, 32)
	if kind == "bomb":
		Sound.play("bomb")
		_ring(origin, Color("ffd7a8"), 110.0)
		_shock(origin, Color("ffd7a8"))
		await get_tree().create_timer(0.36).timeout
	elif kind == "row":
		Sound.play("whoosh")
		_beam(_origin(int(effect.r), 0) + Vector2(0, 32), _origin(int(effect.r), grid_cols - 1) + Vector2(64, 32), Color("fff1c4"))
		await get_tree().create_timer(0.28).timeout
	elif kind == "col":
		Sound.play("whoosh")
		_beam(_origin(0, int(effect.c)) + Vector2(32, 0), _origin(grid_rows - 1, int(effect.c)) + Vector2(32, 64), Color("fff1c4"))
		await get_tree().create_timer(0.28).timeout
	elif kind == "heli":
		Sound.play("heli")
		await _fly(origin, effect.get("hits", []))
	elif kind == "spark":
		Sound.play("shot")
		await _rays(origin, effect.get("hits", []), Color("ffe08a"), 0.05)
	elif kind == "rainbow":
		Sound.play("rainbow")
		await _rays(origin, effect.get("hits", []), Color("fff6ea"), 0.03)


func _fly(origin: Vector2, hits: Array) -> void:
	var ghost = Piece.new()
	ghost.set_piece({ "kind": "tile", "id": 0, "tile": "beetle", "power": "heli" })
	ghost.position = origin - Vector2(32, 32)
	ghost.z_index = 8
	ghost.scale = Vector2(1.25, 1.25)
	add_child(ghost)
	if hits.is_empty():
		await get_tree().create_timer(0.2).timeout
	for hit in hits:
		var dest := _origin(int(hit.x), int(hit.y))
		var lift: Vector2 = (ghost.position + dest) * 0.5 + Vector2(0, -36)
		var tween := create_tween()
		tween.tween_property(ghost, "position", lift, 0.12).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(ghost, "position", dest, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished
		_ring(dest + Vector2(32, 32), Color("ffe08a"), 36.0)
		_burst(dest + Vector2(32, 32), "beetle")
	var away := create_tween()
	away.tween_property(ghost, "modulate:a", 0.0, 0.12)
	await away.finished
	ghost.queue_free()


func _rays(origin: Vector2, hits: Array, color: Color, step: float) -> void:
	if hits.is_empty():
		await get_tree().create_timer(0.12).timeout
		return
	var pending := hits.size()
	for hit in hits:
		var dest := _origin(int(hit.x), int(hit.y)) + Vector2(32, 32)
		_beam(origin, dest, color)
		_ring(dest, color, 28.0)
		pending -= 1
		if pending > 0:
			await get_tree().create_timer(step).timeout
	await get_tree().create_timer(0.28).timeout


func _beam(a: Vector2, b: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 7.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = 8
	line.points = PackedVector2Array([a, a])
	add_child(line)
	var tween := create_tween()
	tween.tween_method(_set_beam.bind(line, a, b), 0.0, 1.0, 0.22)
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.finished.connect(line.queue_free)


func _set_beam(t: float, line: Line2D, a: Vector2, b: Vector2) -> void:
	line.points = PackedVector2Array([a, a.lerp(b, t)])


func _ring(at: Vector2, color: Color, radius: float) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = color
	line.closed = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.z_index = 7
	line.points = _circle_points(at, 6.0)
	add_child(line)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_ring.bind(line, at), 6.0, radius, 0.32)
	tween.tween_property(line, "modulate:a", 0.0, 0.32)
	tween.finished.connect(line.queue_free)


func _set_ring(radius: float, line: Line2D, at: Vector2) -> void:
	line.points = _circle_points(at, radius)


func _circle_points(at: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		points.append(at + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _zap(origin: Vector2, hits: Array, color: Color, step: float) -> void:
	for hit in hits:
		var dest := _origin(int(hit.x), int(hit.y)) + Vector2(32, 32)
		var bit := ColorRect.new()
		bit.color = color
		bit.size = Vector2(8, 8)
		bit.position = origin
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bit.z_index = 6
		add_child(bit)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(bit, "position", dest, step + 0.05)
		tween.tween_property(bit, "modulate:a", 0.15, step + 0.08)
		tween.finished.connect(bit.queue_free)
		await get_tree().create_timer(step).timeout


func _streak(index: int, horizontal: bool) -> void:
	var count := 8
	for i in count:
		var bit := ColorRect.new()
		bit.color = Color("fff1c4")
		bit.size = Vector2(10, 10)
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bit.z_index = 5
		var along := float(i) / float(count - 1)
		if horizontal:
			bit.position = Vector2(along * _span(count), index * (TILE + GAP) + 27)
		else:
			bit.position = Vector2(index * (TILE + GAP) + 27, along * _span(count))
		add_child(bit)
		var tween := create_tween()
		tween.tween_property(bit, "modulate:a", 0.0, 0.22)
		tween.finished.connect(bit.queue_free)


func _shock(at: Vector2, color: Color) -> void:
	for i in 14:
		var bit := ColorRect.new()
		bit.color = color
		bit.size = Vector2(9, 9)
		bit.position = at
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bit.z_index = 6
		add_child(bit)
		var angle := TAU * float(i) / 14.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(bit, "position", at + Vector2(cos(angle), sin(angle)) * 78.0, 0.32)
		tween.tween_property(bit, "modulate:a", 0.0, 0.32)
		tween.finished.connect(bit.queue_free)


func _burst(at: Vector2, tile_type: String) -> void:
	var color: Color = Color("fff6d2")
	if tile_type == "fern":
		color = Color("b6f5cf")
	elif tile_type == "beetle":
		color = Color("ffe09a")
	elif tile_type == "moss":
		color = Color("b7fff8")
	elif tile_type == "pearl":
		color = Color("ffd0e2")
	elif tile_type == "vine":
		color = Color("ffc2b4")
	elif tile_type == "moth":
		color = Color("ffe7c4")
	for i in 8:
		var bit := ColorRect.new()
		bit.color = color
		bit.size = Vector2(7, 7)
		bit.position = at
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bit.z_index = 4
		add_child(bit)
		var angle := TAU * float(i) / 8.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(bit, "position", at + Vector2(cos(angle), sin(angle)) * 34.0, 0.32)
		tween.tween_property(bit, "modulate:a", 0.0, 0.32)
		tween.finished.connect(bit.queue_free)


func _origin(r: int, c: int) -> Vector2:
	return Vector2(c * (TILE + GAP), r * (TILE + GAP))


func _span(count: int) -> float:
	return count * TILE + max(count - 1, 0) * GAP
