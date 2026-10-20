extends RefCounted

var rows := 8
var cols := 8
var types: Array = []
var goals: Array = []
var grid: Array = []
var moves_left := 0
var score := 0
var collected := {}
var glass_cleared := 0
var glass_total_hp := 0
var buds_cleared := 0
var powers_made := 0
var next_id := 1
var level_id := 1
var night := ""
var level_name := ""
var line := ""


func setup(level: Dictionary) -> void:
	level_id = int(level.id)
	night = str(level.night)
	level_name = str(level.name)
	line = str(level.line)
	rows = int(level.rows)
	cols = int(level.cols)
	types = level.types.duplicate()
	goals = []
	for goal in level.goals:
		var copy = goal.duplicate(true)
		copy.count = int(copy.count)
		goals.append(copy)
	moves_left = int(level.moves)
	score = 0
	collected = {}
	for tile in types:
		collected[tile] = 0
	glass_cleared = 0
	glass_total_hp = 0
	buds_cleared = 0
	powers_made = 0
	next_id = 1
	grid = _blank()
	for bud in level.get("buds", []):
		var bud_hp := int(bud.hp)
		grid[int(bud.r)][int(bud.c)] = {
			"kind": "bud",
			"id": next_id,
			"hp": bud_hp,
			"max_hp": bud_hp,
		}
		next_id += 1
	for glass in level.get("glass", []):
		var hp := int(glass.hp)
		grid[int(glass.r)][int(glass.c)] = {
			"kind": "glass",
			"id": next_id,
			"hp": hp,
			"max_hp": hp,
		}
		next_id += 1
		glass_total_hp += hp
	_fill_tiles()


func goals_met() -> bool:
	for goal in goals:
		if goal.kind == "collect":
			if int(collected.get(goal.tile, 0)) < int(goal.count):
				return false
		elif goal.kind == "bud":
			if buds_cleared < int(goal.count):
				return false
		elif goal.kind == "power":
			if powers_made < int(goal.count):
				return false
		elif goal.kind == "glass" and glass_cleared < int(goal.count):
			return false
	return true


func goal_fraction() -> float:
	if goals.is_empty():
		return 1.0
	var total := 0.0
	for goal in goals:
		if goal.kind == "collect":
			total += minf(1.0, float(collected.get(goal.tile, 0)) / float(maxi(1, int(goal.count))))
		elif goal.kind == "bud":
			total += minf(1.0, float(buds_cleared) / float(maxi(1, int(goal.count))))
		elif goal.kind == "power":
			total += minf(1.0, float(powers_made) / float(maxi(1, int(goal.count))))
		else:
			total += minf(1.0, float(glass_cleared) / float(maxi(1, int(goal.count))))
	return total / float(goals.size())


func valid_moves() -> Array:
	var moves: Array = []
	for r in rows:
		for c in cols:
			if c + 1 < cols and _swap_works(r, c, r, c + 1):
				moves.append({ "r1": r, "c1": c, "r2": r, "c2": c + 1 })
			if r + 1 < rows and _swap_works(r, c, r + 1, c):
				moves.append({ "r1": r, "c1": c, "r2": r + 1, "c2": c })
	return moves


func suggest_move() -> Dictionary:
	var best := {}
	var best_value := -1.0
	for move in valid_moves():
		var copy = _clone_self()
		var result = copy.apply_move(move.r1, move.c1, move.r2, move.c2)
		if not result.ok:
			continue
		var value = copy.goal_fraction() * 100000.0 + float(copy.score)
		if value > best_value:
			best_value = value
			best = move
	return best


func grant_moves(count: int) -> void:
	moves_left += count


func apply_move(r1: int, c1: int, r2: int, c2: int) -> Dictionary:
	if abs(r1 - r2) + abs(c1 - c2) != 1:
		return { "ok": false }
	var a = grid[r1][c1]
	var b = grid[r2][c2]
	if a == null or b == null or a.kind != "tile" or b.kind != "tile":
		return { "ok": false }
	var type_a = a.tile
	var type_b = b.tile
	var power_a = str(a.power)
	var power_b = str(b.power)
	grid[r1][c1] = b
	grid[r2][c2] = a
	var powered := power_a != "" or power_b != ""
	if not powered and not _has_groups(grid):
		grid[r1][c1] = a
		grid[r2][c2] = b
		return { "ok": false }
	var seeds: Array = []
	if power_a != "":
		seeds.append({ "r": r2, "c": c2, "lamp_target": type_b })
	if power_b != "":
		seeds.append({ "r": r1, "c": c1, "lamp_target": type_a })
	moves_left -= 1
	var resolved := _resolve(seeds, [Vector2i(r2, c2), Vector2i(r1, c1)], power_a == "rainbow" and power_b == "rainbow")
	if resolved.cleared_total == 0 and resolved.glass_damaged == 0:
		moves_left += 1
		grid[r1][c1] = a
		grid[r2][c2] = b
		return { "ok": false }
	return { "ok": true, "frames": resolved.frames }


func activate(r: int, c: int) -> Dictionary:
	if not _inside(r, c):
		return { "ok": false }
	var cell = grid[r][c]
	if cell == null or cell.kind != "tile" or str(cell.power) == "":
		return { "ok": false }
	moves_left -= 1
	var seeds: Array = [{ "r": r, "c": c, "lamp_target": cell.tile }]
	var resolved := _resolve(seeds, [Vector2i(r, c)], false)
	if resolved.cleared_total == 0 and resolved.glass_damaged == 0:
		moves_left += 1
		return { "ok": false }
	return { "ok": true, "frames": resolved.frames }


func pour(r: int, c: int) -> Dictionary:
	if not _inside(r, c):
		return { "ok": false }
	var cell = grid[r][c]
	if cell == null:
		return { "ok": false }
	var pop_ids: Array = []
	var cracks: Array = []
	if cell.kind == "tile":
		pop_ids.append(cell.id)
		collected[cell.tile] = int(collected.get(cell.tile, 0)) + 1
		grid[r][c] = null
	elif _blocks(cell):
		cell.hp -= 1
		if int(cell.hp) <= 0:
			cracks.append({ "id": cell.id, "hp": 0 })
			if cell.kind == "bud":
				buds_cleared += 1
			else:
				glass_cleared += 1
			grid[r][c] = null
		else:
			cracks.append({ "id": cell.id, "hp": cell.hp })
	else:
		return { "ok": false }
	var frames: Array = []
	frames.append({
		"type": "clear",
		"pop_ids": pop_ids,
		"cracks": cracks,
		"power_up": null,
		"effects": [],
		"gained": 0,
		"combo": 1,
		"hud": hud(),
	})
	var spawned := _gravity()
	frames.append({
		"type": "fall",
		"grid": _clone_grid(grid),
		"spawns": spawned,
		"hud": hud(),
	})
	var more: Dictionary = _resolve([], [], false)
	for frame in more.frames:
		frames.append(frame)
	return { "ok": true, "frames": frames }


func shuffle_tiles() -> void:
	_fill_tiles()


func hud() -> Dictionary:
	return {
		"moves_left": moves_left,
		"score": score,
		"collected": collected.duplicate(),
		"glass_cleared": glass_cleared,
		"buds_cleared": buds_cleared,
		"powers_made": powers_made,
	}


func _clone_self():
	var copy = get_script().new()
	copy.rows = rows
	copy.cols = cols
	copy.types = types.duplicate()
	copy.goals = goals.duplicate(true)
	copy.grid = _clone_grid(grid)
	copy.moves_left = moves_left
	copy.score = score
	copy.collected = collected.duplicate()
	copy.glass_cleared = glass_cleared
	copy.glass_total_hp = glass_total_hp
	copy.buds_cleared = buds_cleared
	copy.powers_made = powers_made
	copy.next_id = next_id
	copy.level_id = level_id
	return copy


func _blank() -> Array:
	var next: Array = []
	for _r in rows:
		var row: Array = []
		for _c in cols:
			row.append(null)
		next.append(row)
	return next


func _clone_cell(cell):
	if cell == null:
		return null
	return cell.duplicate(true)


func _clone_grid(source: Array) -> Array:
	var next: Array = []
	for row in source:
		var copy: Array = []
		for cell in row:
			copy.append(_clone_cell(cell))
		next.append(copy)
	return next


func _make_tile(type = null) -> Dictionary:
	var tile_name = type if type != null else types[randi() % types.size()]
	var cell := {
		"kind": "tile",
		"id": next_id,
		"tile": tile_name,
		"power": "",
	}
	next_id += 1
	return cell


func _color_at(source: Array, r: int, c: int):
	var cell = source[r][c]
	if cell == null or cell.kind != "tile":
		return null
	return cell.tile


func _analyze(source: Array) -> Dictionary:
	var h_len := []
	var v_len := []
	for r in rows:
		var h_row: Array = []
		var v_row: Array = []
		h_row.resize(cols)
		v_row.resize(cols)
		h_row.fill(0)
		v_row.fill(0)
		h_len.append(h_row)
		v_len.append(v_row)
	var seen := {}
	var grouped: Array = []
	for r in rows:
		var c := 0
		while c < cols:
			var tile = _color_at(source, r, c)
			if tile == null:
				c += 1
				continue
			var k := c + 1
			while k < cols and _color_at(source, r, k) == tile:
				k += 1
			if k - c >= 3:
				for i in range(c, k):
					h_len[r][i] = k - c
					var id := "%d,%d" % [r, i]
					if not seen.has(id):
						seen[id] = true
						grouped.append(Vector2i(r, i))
			c = k
	for c in cols:
		var r := 0
		while r < rows:
			var tile = _color_at(source, r, c)
			if tile == null:
				r += 1
				continue
			var k := r + 1
			while k < rows and _color_at(source, k, c) == tile:
				k += 1
			if k - r >= 3:
				for i in range(r, k):
					v_len[i][c] = k - r
					var id := "%d,%d" % [i, c]
					if not seen.has(id):
						seen[id] = true
						grouped.append(Vector2i(i, c))
			r = k
	var square := {}
	if rows > 1 and cols > 1:
		for sr in rows - 1:
			for sc in cols - 1:
				var tile = _color_at(source, sr, sc)
				if tile == null:
					continue
				if _color_at(source, sr, sc + 1) != tile:
					continue
				if _color_at(source, sr + 1, sc) != tile:
					continue
				if _color_at(source, sr + 1, sc + 1) != tile:
					continue
				for dr in 2:
					for dc in 2:
						var id := "%d,%d" % [sr + dr, sc + dc]
						square[id] = true
						if not seen.has(id):
							seen[id] = true
							grouped.append(Vector2i(sr + dr, sc + dc))
	return { "h": h_len, "v": v_len, "grouped": grouped, "square": square }


func _has_groups(source: Array) -> bool:
	return not _analyze(source).grouped.is_empty()


func _pattern(h: int, v: int, in_square: bool) -> String:
	if h >= 5 or v >= 5:
		return "rainbow" if level_id >= 5 else "spark"
	if h >= 3 and v >= 3:
		return "burst"
	if h >= 4:
		return "row"
	if v >= 4:
		return "col"
	if in_square and h < 4 and v < 4:
		return "heli"
	return ""


func _inside(r: int, c: int) -> bool:
	return r >= 0 and c >= 0 and r < rows and c < cols


func _expand(queue_start: Array, lamp_hints: Dictionary, clear_all: bool) -> Dictionary:
	var queue: Array = []
	var cleared := {}
	var glass_hit := {}
	var seen := {}
	var effects: Array = []
	if clear_all:
		for r in rows:
			for c in cols:
				var cell = grid[r][c]
				if cell != null and cell.kind == "tile":
					queue.append(Vector2i(r, c))
	for item in queue_start:
		queue.append(item)

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var id := "%d,%d" % [pos.x, pos.y]
		if seen.has(id):
			continue
		if not _inside(pos.x, pos.y):
			continue
		var cell = grid[pos.x][pos.y]
		if cell == null or cell.kind != "tile":
			continue
		seen[id] = true
		cleared[id] = pos
		var power := str(cell.power)
		if power == "":
			continue
		if power == "row":
			effects.append({ "kind": "row", "r": pos.x, "c": pos.y })
			for cc in cols:
				_consider(pos.x, cc, queue, glass_hit, seen)
		elif power == "col":
			effects.append({ "kind": "col", "r": pos.x, "c": pos.y })
			for rr in rows:
				_consider(rr, pos.y, queue, glass_hit, seen)
		elif power == "burst":
			effects.append({ "kind": "bomb", "r": pos.x, "c": pos.y })
			for rr in range(pos.x - 2, pos.x + 3):
				for cc in range(pos.y - 2, pos.y + 3):
					_consider(rr, cc, queue, glass_hit, seen)
		elif power == "heli":
			var hits := _heli_hits(pos)
			effects.append({ "kind": "heli", "r": pos.x, "c": pos.y, "hits": hits })
			for hit in hits:
				_consider(hit.x, hit.y, queue, glass_hit, seen)
		elif power == "spark":
			var shots := _spark_hits(pos)
			effects.append({ "kind": "spark", "r": pos.x, "c": pos.y, "hits": shots })
			for hit in shots:
				_consider(hit.x, hit.y, queue, glass_hit, seen)
		elif power == "rainbow":
			var wanted = lamp_hints.get(id, cell.tile)
			var shots := _rainbow_hits(pos, str(wanted))
			effects.append({ "kind": "rainbow", "r": pos.x, "c": pos.y, "hits": shots })
			for hit in shots:
				_consider(hit.x, hit.y, queue, glass_hit, seen)

	for id in cleared.keys():
		var pos: Vector2i = cleared[id]
		for step in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var rr = pos.x + step.x
			var cc = pos.y + step.y
			if not _inside(rr, cc):
				continue
			var near = grid[rr][cc]
			if _blocks(near):
				glass_hit["%d,%d" % [rr, cc]] = Vector2i(rr, cc)
	return { "cleared": cleared, "glass_hit": glass_hit, "effects": effects }


func _heli_hits(origin: Vector2i) -> Array:
	var pool: Array = []
	var buds: Array = []
	var frost: Array = []
	var goals: Array = []
	var rest: Array = []
	for r in rows:
		for c in cols:
			if r == origin.x and c == origin.y:
				continue
			var cell = grid[r][c]
			if cell == null:
				continue
			var at := Vector2i(r, c)
			if cell.kind == "bud" and int(cell.hp) > 0 and _blocker_still_needed("bud"):
				buds.append(at)
			elif cell.kind == "glass" and int(cell.hp) > 0:
				frost.append(at)
			elif cell.kind == "tile" and _tile_still_needed(str(cell.tile)):
				goals.append(at)
			elif cell.kind == "tile":
				rest.append(at)
	if not buds.is_empty():
		pool = buds
	elif not frost.is_empty():
		pool = frost
	else:
		pool = goals if not goals.is_empty() else rest
	if pool.is_empty():
		return []
	var target: Vector2i = pool[randi() % pool.size()]
	var hits: Array = [target]
	for step in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var near: Vector2i = target + step
		if near == origin or not _inside(near.x, near.y):
			continue
		if grid[near.x][near.y] == null:
			continue
		hits.append(near)
	return hits


func _spark_hits(origin: Vector2i) -> Array:
	var pool: Array = []
	for r in rows:
		for c in cols:
			if r == origin.x and c == origin.y:
				continue
			var cell = grid[r][c]
			if cell != null and cell.kind == "tile":
				pool.append(Vector2i(r, c))
	pool.shuffle()
	var count := 8 if pool.size() > 8 else pool.size()
	var hits: Array = []
	for i in count:
		hits.append(pool[i])
	return hits


func _rainbow_hits(origin: Vector2i, wanted: String) -> Array:
	var hits: Array = []
	for r in rows:
		for c in cols:
			if r == origin.x and c == origin.y:
				continue
			var cell = grid[r][c]
			if cell != null and cell.kind == "tile" and str(cell.tile) == wanted:
				hits.append(Vector2i(r, c))
	return hits


func _tile_still_needed(tile: String) -> bool:
	for goal in goals:
		if goal.kind == "collect" and str(goal.tile) == tile:
			if int(collected.get(tile, 0)) < int(goal.count):
				return true
	return false


func _consider(r: int, c: int, queue: Array, glass_hit: Dictionary, seen: Dictionary) -> void:
	if not _inside(r, c):
		return
	var cell = grid[r][c]
	if cell == null:
		return
	var id := "%d,%d" % [r, c]
	if _blocks(cell):
		glass_hit[id] = Vector2i(r, c)
	elif not seen.has(id):
		queue.append(Vector2i(r, c))


func _choose_anchor(analysis: Dictionary, prefer: Array):
	var rank := { "rainbow": 6, "spark": 5, "burst": 4, "row": 3, "col": 3, "heli": 2 }
	var best = null
	var squares = analysis.square
	for pos in analysis.grouped:
		var key := "%d,%d" % [pos.x, pos.y]
		var pattern := _pattern(int(analysis.h[pos.x][pos.y]), int(analysis.v[pos.x][pos.y]), squares.has(key))
		if pattern == "":
			continue
		var cell = grid[pos.x][pos.y]
		if cell == null or cell.kind != "tile" or str(cell.power) != "":
			continue
		var is_pivot := false
		for pivot in prefer:
			if pivot == pos:
				is_pivot = true
		var score: int = rank[pattern]
		if best == null or score > best.score or (score == best.score and is_pivot and not best.is_pivot):
			best = {
				"r": pos.x,
				"c": pos.y,
				"power": pattern,
				"score": score,
				"is_pivot": is_pivot,
				"id": cell.id,
			}
	return best


func _resolve(seeds: Array, prefer: Array, clear_all: bool) -> Dictionary:
	var frames: Array = []
	var pivot: Array = prefer.duplicate()
	var combo := 1
	var cleared_total := 0
	var glass_damaged := 0
	var first := true
	while combo < 14:
		var analysis := _analyze(grid)
		var queue_start: Array = analysis.grouped.duplicate()
		var lamp_hints := {}
		if first:
			for seed in seeds:
				queue_start.append(Vector2i(seed.r, seed.c))
				if seed.lamp_target != null:
					lamp_hints["%d,%d" % [seed.r, seed.c]] = seed.lamp_target
		if queue_start.is_empty() and not (first and clear_all):
			break
		var expanded := _expand(queue_start, lamp_hints, first and clear_all)
		var anchor = _choose_anchor(analysis, pivot)
		pivot = []
		first = false
		if anchor != null:
			expanded.cleared.erase("%d,%d" % [anchor.r, anchor.c])
		if expanded.cleared.is_empty() and expanded.glass_hit.is_empty() and anchor == null:
			break
		var pop_ids: Array = []
		var gained := 0
		for id in expanded.cleared.keys():
			var pos: Vector2i = expanded.cleared[id]
			var cell = grid[pos.x][pos.y]
			if cell == null or cell.kind != "tile":
				continue
			pop_ids.append(cell.id)
			collected[cell.tile] = int(collected.get(cell.tile, 0)) + 1
			gained += 70 if str(cell.power) != "" else 40
		gained *= combo
		score += gained
		cleared_total += pop_ids.size()
		var cracks: Array = []
		for id in expanded.glass_hit.keys():
			var pos: Vector2i = expanded.glass_hit[id]
			var cell = grid[pos.x][pos.y]
			if not _blocks(cell):
				continue
			cell.hp -= 1
			glass_damaged += 1
			if cell.hp <= 0:
				cracks.append({ "id": cell.id, "hp": 0 })
				if cell.kind == "bud":
					buds_cleared += 1
				else:
					glass_cleared += 1
				grid[pos.x][pos.y] = null
			else:
				cracks.append({ "id": cell.id, "hp": cell.hp })
		for id in expanded.cleared.keys():
			var pos: Vector2i = expanded.cleared[id]
			grid[pos.x][pos.y] = null
		if anchor != null:
			grid[anchor.r][anchor.c].power = anchor.power
			powers_made += 1
		frames.append({
			"type": "clear",
			"pop_ids": pop_ids,
			"cracks": cracks,
			"power_up": anchor,
			"effects": expanded.effects,
			"gained": gained,
			"combo": combo,
			"hud": hud(),
		})
		var spawned := _gravity()
		frames.append({
			"type": "fall",
			"grid": _clone_grid(grid),
			"spawns": spawned,
			"hud": hud(),
		})
		combo += 1
	return { "frames": frames, "cleared_total": cleared_total, "glass_damaged": glass_damaged }


func _gravity() -> Array:
	var spawns: Array = []
	for c in cols:
		var segments: Array = []
		var current: Array = []
		for r in rows:
			var cell = grid[r][c]
			if _blocks(cell):
				if not current.is_empty():
					segments.append(current)
				current = []
			else:
				current.append(r)
		if not current.is_empty():
			segments.append(current)
		for segment in segments:
			var tiles: Array = []
			for r in segment:
				var cell = grid[r][c]
				if cell != null and cell.kind == "tile":
					tiles.append(cell)
				grid[r][c] = null
			var empty = segment.size() - tiles.size()
			for index in tiles.size():
				grid[segment[empty + index]][c] = tiles[index]
			var hole := 0
			for r in segment:
				if grid[r][c] != null:
					continue
				hole += 1
				var tile := _make_tile()
				grid[r][c] = tile
				spawns.append({ "id": tile.id, "dist": hole })
	return spawns


func _different_type(type: String) -> String:
	var pool: Array = []
	for item in types:
		if item != type:
			pool.append(item)
	if pool.is_empty():
		return type
	return pool[randi() % pool.size()]


func _repair() -> void:
	for n in 400:
		var grouped: Array = _analyze(grid).grouped
		if grouped.is_empty():
			return
		var pos: Vector2i = grouped[n % grouped.size()]
		var cell = grid[pos.x][pos.y]
		if cell == null or cell.kind != "tile":
			continue
		cell.tile = _different_type(cell.tile)
		cell.power = ""


func _swap_works(r1: int, c1: int, r2: int, c2: int) -> bool:
	var a = grid[r1][c1]
	var b = grid[r2][c2]
	if a == null or b == null or a.kind != "tile" or b.kind != "tile":
		return false
	if str(a.power) != "" or str(b.power) != "":
		return true
	var trial := _clone_grid(grid)
	trial[r1][c1] = _clone_cell(b)
	trial[r2][c2] = _clone_cell(a)
	return _has_groups(trial)


func _fill_tiles() -> void:
	for _attempt in 60:
		for r in rows:
			for c in cols:
				var cell = grid[r][c]
				if _blocks(cell):
					continue
				grid[r][c] = _make_tile()
		_repair()
		if not _has_groups(grid) and not valid_moves().is_empty():
			return


func _blocks(cell) -> bool:
	return cell != null and (cell.kind == "glass" or cell.kind == "bud")


func _blocker_still_needed(kind: String) -> bool:
	var have := buds_cleared if kind == "bud" else glass_cleared
	for goal in goals:
		if str(goal.kind) == kind and have < int(goal.count):
			return true
	return false


func _remaining_glass_hp() -> int:
	var hp := 0
	for row in grid:
		for cell in row:
			if cell != null and cell.kind == "glass":
				hp += int(cell.hp)
	return hp
