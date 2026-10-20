extends SceneTree

const Model = preload("res://scripts/board_model.gd")
const Catalog = preload("res://scripts/catalog.gd")


func _init() -> void:
	var level = JSON.parse_string(FileAccess.get_file_as_string("res://levels/01.json"))
	var model = Model.new()
	model.setup(level)
	if model.valid_moves().is_empty():
		push_error("Level 1 has no moves")
		quit(1)
		return
	var move: Dictionary = model.valid_moves()[0]
	var result: Dictionary = model.apply_move(int(move.r1), int(move.c1), int(move.r2), int(move.c2))
	if not result.ok:
		push_error("First legal move was rejected")
		quit(1)
		return
	if model._pattern(5, 0, false) != "spark":
		push_error("Level 1 should make a spark ball, not a rainbow")
		quit(1)
		return
	if model._pattern(0, 0, true) != "heli":
		push_error("A square should make a helicopter")
		quit(1)
		return
	if model._pattern(3, 3, false) != "burst":
		push_error("A corner should make a bomb")
		quit(1)
		return
	var night = JSON.parse_string(FileAccess.get_file_as_string("res://levels/05.json"))
	var later = Model.new()
	later.setup(night)
	if later._pattern(5, 0, false) != "rainbow":
		push_error("Level 5 should make a rainbow ball")
		quit(1)
		return
	if later.valid_moves().is_empty():
		push_error("Level 5 has no moves")
		quit(1)
		return
	var poured: Dictionary = model.pour(0, 0)
	if not poured.ok:
		push_error("Watering can failed")
		quit(1)
		return
	for index in [10, 27, 35, 44, 59, 99, 149]:
		var generated: Dictionary = Catalog.build(index)
		if int(generated.moves) < 22 or int(generated.moves) > 42:
			push_error("Level %d has an unfair move count" % (index + 1))
			quit(1)
			return
		if generated.goals.is_empty():
			push_error("Level %d has no goals" % (index + 1))
			quit(1)
			return
		var sample = Model.new()
		sample.setup(generated)
		if sample.valid_moves().is_empty():
			push_error("Level %d has no moves" % (index + 1))
			quit(1)
			return
	var buds = Model.new()
	buds.setup(Catalog.build(27))
	var bud_cell := Vector2i(-1, -1)
	for r in buds.rows:
		for c in buds.cols:
			var cell = buds.grid[r][c]
			if cell != null and cell.kind == "bud":
				bud_cell = Vector2i(r, c)
	if bud_cell.x < 0:
		push_error("Level 28 should plant buds")
		quit(1)
		return
	if not buds.pour(bud_cell.x, bud_cell.y).ok:
		push_error("Watering a bud failed")
		quit(1)
		return
	print("Lumen self-test ok, score ", model.score)
	quit(0)
