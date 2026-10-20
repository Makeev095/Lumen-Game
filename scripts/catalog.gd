extends RefCounted

const COUNT := 150
const TYPES := ["fern", "beetle", "moss", "pearl", "vine"]
const HAND_KEYS := [
	{ "name": "r0", "line": "s_fern" },
	{ "name": "r1", "line": "s_frost" },
	{ "name": "r2", "line": "s_floor" },
	{ "name": "r3", "line": "s_heli" },
	{ "name": "r4", "line": "s_rainbow" },
	{ "name": "r5", "line": "s_bomb" },
	{ "name": "r6", "line": "s_pots" },
	{ "name": "r7", "line": "s_can" },
	{ "name": "r8", "line": "s_moths" },
	{ "name": "r9", "line": "s_full" },
]


static func build(index: int) -> Dictionary:
	var safe := clampi(index, 0, COUNT - 1)
	if safe < HAND_KEYS.size():
		return _handmade(safe)
	return _generated(safe + 1)


static func _handmade(index: int) -> Dictionary:
	var path := "res://levels/%02d.json" % (index + 1)
	var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var keys: Dictionary = HAND_KEYS[index]
	level["number"] = index + 1
	level["name_key"] = keys.name
	level["line_key"] = keys.line
	level["buds"] = level.get("buds", [])
	return level


static func _generated(number: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41000 + number * 97
	var types: Array = TYPES.duplicate()
	if number >= 60:
		types.append("moth")
	var slots := 1
	if number >= 70:
		slots = 3
	elif number >= 20:
		slots = 2
	var base := 8 + mini(6, int(number / 22.0))
	var goals: Array = []
	var used := {}
	var cursor := number % types.size()
	while goals.size() < slots:
		var tile: String = types[cursor % types.size()]
		cursor += 1
		if used.has(tile):
			continue
		used[tile] = true
		var count := base + (goals.size() % 2)
		goals.append({ "kind": "collect", "tile": tile, "count": count })
	if number >= 75 and number % 4 == 0:
		goals[0] = { "kind": "collect", "tile": "moth", "count": base }
	var glass_n := 0
	if number >= 14:
		glass_n = mini(7, 2 + int((number - 14) / 20.0))
	var bud_n := 0
	if number >= 28:
		bud_n = mini(5, 2 + int((number - 28) / 30.0))
	var power_n := 0
	if number >= 45 and number % 7 == 3:
		power_n = mini(4, 2 + int((number - 45) / 40.0))
		goals.append({ "kind": "power", "count": power_n })
	var glass_hp := 2 if number >= 36 else 1
	var glass := _scatter(rng, glass_n, glass_hp, {})
	var blocked := {}
	for cell in glass:
		blocked["%d,%d" % [int(cell.r), int(cell.c)]] = true
	var buds := _scatter(rng, bud_n, 2 if number >= 50 else 1, blocked)
	if bud_n > 0 and number % 5 == 3 and not buds.is_empty():
		goals.append({ "kind": "bud", "count": mini(bud_n, buds.size()) })
	if glass.size() >= 3 and number % 2 == 0:
		goals.append({ "kind": "glass", "count": mini(glass.size(), 4) })
	var collect_sum := 0
	for goal in goals:
		if goal.kind == "collect":
			collect_sum += int(goal.count)
	var raw := 28 + int(collect_sum / 6.0) + glass.size() + buds.size() + power_n * 2 - mini(5, int(number / 30.0))
	var floor_moves := int(ceil(float(collect_sum) / 2.5)) + glass.size() + buds.size() + power_n + 10
	var moves := clampi(maxi(raw, floor_moves), 22, 42)
	var name_key := _name_key(number)
	var line_key := "s_soft"
	if number == 28:
		line_key = "s_bud"
	elif number == 36:
		line_key = "s_thick"
	elif number == 45:
		line_key = "s_power"
	elif number == 60:
		line_key = "s_moth"
	elif power_n > 0:
		line_key = "s_power"
	elif glass.size() >= 4:
		line_key = "s_hard"
	return {
		"id": number,
		"number": number,
		"night": "Ночь %d" % number,
		"name": name_key,
		"name_key": name_key,
		"line": line_key,
		"line_key": line_key,
		"rows": 8,
		"cols": 8,
		"types": types,
		"moves": moves,
		"goals": goals,
		"glass": glass,
		"buds": buds,
	}


static func _name_key(number: int) -> String:
	var marks := {
		18: "r_paths",
		28: "r_buds",
		36: "r_thick",
		45: "r_lamps",
		60: "r_moths",
		90: "r_roof",
		110: "r_bowl",
		130: "r_choir",
		145: "r_gold",
		150: "r_eternal",
	}
	if marks.has(number):
		return marks[number]
	return "p%d" % (number % 12)


static func _goal_count(goals: Array, kind: String) -> int:
	for goal in goals:
		if goal.kind == kind:
			return int(goal.count)
	return 0


static func _scatter(rng: RandomNumberGenerator, count: int, hp: int, blocked: Dictionary) -> Array:
	var placed: Array = []
	var column := {}
	var guard := 0
	while placed.size() < count and guard < 100:
		guard += 1
		var r := 1 + rng.randi() % 6
		var c := rng.randi() % 8
		var key := "%d,%d" % [r, c]
		if blocked.has(key):
			continue
		if int(column.get(c, 0)) >= 3:
			continue
		blocked[key] = true
		column[c] = int(column.get(c, 0)) + 1
		placed.append({ "r": r, "c": c, "hp": hp })
	return placed
