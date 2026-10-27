extends Control

const Model = preload("res://scripts/board_model.gd")
const Board = preload("res://scripts/board_view.gd")
const Piece = preload("res://scripts/piece_view.gd")
const Garden = preload("res://scripts/garden_backdrop.gd")
const Keeper = preload("res://scripts/keeper.gd")
const Catalog = preload("res://scripts/catalog.gd")

var model = Model.new()
var board
var menu: Control
var menu_host: Control
var game: Control
var game_host: Control
var overlay: Control
var night_label: Label
var title_label: Label
var story_label: Label
var moves_label: Label
var goals_row: HFlowContainer
var score_label: Label
var continue_button: Button
var progress_label: Label
var repair_label: Label
var night_lamps: Array = []
var menu_title: Label
var overlay_panel: Panel
var overlay_card: VBoxContainer
var overlay_fit := 1.0
var overlay_tween: Tween
var name_key := ""
var line_key := ""
var level_number := 1
var card_mode := ""
var garden
var overlay_title: Label
var overlay_body: Label
var next_button: Button
var reward_button: Button
var again_button: Button
var home_button: Button
var shop_button: Button
var shop_box: VBoxContainer
var water_button: Button
var _shop_from := ""
var _buying := false
var overlay_goals: HFlowContainer
var star_row: HBoxContainer
var awaiting_start := false
var watering := false
var water_left := 1
var level_index := 0
var drag_from := Vector2i(-1, -1)
var drag_point := Vector2.ZERO
var dragging := false
var busy := false
var keeper
var game_keeper
var board_slot: Control
var keeper_slot: Control
var ui_font: Font
var display_font: Font


func _ready() -> void:
	_apply_fonts()
	Locale.language_changed.connect(_on_language)
	garden = Garden.new()
	add_child(garden)
	_build_menu()
	_build_game()
	_apply_static_copy(self)
	Yandex.purchase_resolved.connect(_on_purchase)
	Yandex.catalog_changed.connect(_on_catalog)
	Yandex.progress_changed.connect(_on_progress)
	Yandex.mark_listener_ready()
	_show_menu()
	resized.connect(_fit_screen)
	get_viewport().size_changed.connect(_fit_screen)
	_fit_screen()
	menu_title.modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(menu_title, "modulate:a", 1.0, 0.45)


func _build_menu() -> void:
	menu = _column()
	menu_host = _host(menu)
	add_child(menu_host)
	keeper = Keeper.new()
	keeper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.add_child(keeper)
	var eyebrow := _label("", 28, Color("6b3a14"))
	eyebrow.set_meta("copy", "kicker")
	eyebrow.add_theme_font_override("font", display_font)
	eyebrow.set_meta("display", true)
	menu.add_child(eyebrow)
	menu_title = _label("", 92, Color("1d4a32"))
	menu_title.add_theme_font_override("font", display_font)
	menu_title.set_meta("display", true)
	menu_title.set_meta("copy", "title")
	menu.add_child(menu_title)
	var story := _label("", 20, Color("4a3424"))
	story.set_meta("copy", "home_story")
	menu.add_child(story)
	progress_label = _label("", 18, Color("8a4e12"))
	repair_label = _label("", 26, Color("1d4a32"))
	repair_label.add_theme_font_override("font", display_font)
	repair_label.set_meta("display", true)
	menu.add_child(progress_label)
	menu.add_child(repair_label)
	var lamps := HBoxContainer.new()
	lamps.alignment = BoxContainer.ALIGNMENT_CENTER
	lamps.add_theme_constant_override("separation", 8)
	for _i in 3:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lamps.add_child(dot)
		night_lamps.append(dot)
	menu.add_child(lamps)
	continue_button = _button("", true)
	continue_button.pressed.connect(_continue)
	menu.add_child(continue_button)
	var help := _button("", false)
	help.set_meta("copy", "how")
	help.pressed.connect(_show_how)
	menu.add_child(help)
	var shop := _button("", true)
	shop.set_meta("copy", "shop")
	shop.pressed.connect(_open_shop)
	menu.add_child(shop)
	_refresh_home()


func _build_game() -> void:
	game = _column()
	game.add_theme_constant_override("separation", 8)
	game_host = _host(game)
	game_host.visible = false
	add_child(game_host)
	night_label = _label("", 18, Color("8a4e12"))
	title_label = _label("", 36, Color("1d4a32"))
	title_label.add_theme_font_override("font", display_font)
	title_label.set_meta("display", true)
	story_label = _label("", 18, Color("4a3424"))
	story_label.max_lines_visible = 3
	story_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	moves_label = _label("", 28, Color("c47a22"))
	moves_label.add_theme_font_override("font", display_font)
	moves_label.set_meta("display", true)
	goals_row = HFlowContainer.new()
	goals_row.alignment = FlowContainer.ALIGNMENT_CENTER
	goals_row.add_theme_constant_override("h_separation", 10)
	goals_row.add_theme_constant_override("v_separation", 8)
	score_label = _label("", 18, Color("4a3424"))
	for node in [night_label, title_label, story_label, moves_label, goals_row, score_label]:
		game.add_child(node)
	board = Board.new()
	board.hud_updated.connect(_show_hud)
	board.gui_input.connect(_on_board_input)
	board.matched.connect(_on_matched)
	board_slot = Control.new()
	board_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_slot.add_child(board)
	game.add_child(board_slot)
	game_keeper = Keeper.new()
	game_keeper.scale = Vector2(0.55, 0.55)
	keeper_slot = Control.new()
	keeper_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keeper_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	keeper_slot.custom_minimum_size = Vector2(94, 110)
	keeper_slot.add_child(game_keeper)
	game.add_child(keeper_slot)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	var back := _button("", false)
	back.set_meta("copy", "garden")
	back.pressed.connect(_show_menu)
	var retry := _button("", false)
	retry.set_meta("copy", "retry")
	retry.pressed.connect(func() -> void: start_level(level_index))
	water_button = _button("", false)
	water_button.pressed.connect(_arm_water)
	var help := _button("", false)
	help.set_meta("copy", "how")
	help.pressed.connect(_show_how)
	row.add_child(back)
	row.add_child(water_button)
	row.add_child(help)
	row.add_child(retry)
	game.add_child(row)

	overlay_panel = Panel.new()
	overlay = ColorRect.new()
	overlay.color = Color(0.1, 0.22, 0.14, 0.55)
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 40
	add_child(overlay)
	var panel := overlay_panel
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -210
	panel.offset_bottom = 200
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("fffaf2")
	plate.border_color = Color("e2a83a")
	plate.set_border_width_all(4)
	plate.set_corner_radius_all(28)
	plate.shadow_color = Color(0.25, 0.16, 0.05, 0.35)
	plate.shadow_size = 18
	panel.add_theme_stylebox_override("panel", plate)
	panel.pivot_offset = Vector2(290, 205)
	overlay.add_child(panel)
	var card := _column()
	overlay_card = card
	card.add_theme_constant_override("separation", 10)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 22
	card.offset_top = 22
	card.offset_right = -22
	card.offset_bottom = -22
	card.custom_minimum_size = Vector2(0, 0)
	panel.add_child(card)
	overlay_title = _label("", 40, Color("1d4a32"))
	overlay_title.add_theme_font_override("font", display_font)
	overlay_title.set_meta("display", true)
	overlay_body = _label("", 26, Color("1d4a32"))
	overlay_body.add_theme_font_override("font", display_font)
	overlay_body.set_meta("display", true)
	overlay_goals = HFlowContainer.new()
	overlay_goals.alignment = FlowContainer.ALIGNMENT_CENTER
	overlay_goals.add_theme_constant_override("h_separation", 8)
	overlay_goals.add_theme_constant_override("v_separation", 8)
	star_row = HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 8)
	card.add_child(overlay_title)
	card.add_child(overlay_body)
	card.add_child(overlay_goals)
	card.add_child(star_row)
	var actions := HFlowContainer.new()
	actions.alignment = FlowContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	next_button = _button("", true)
	next_button.pressed.connect(_on_next)
	reward_button = _button("", true)
	reward_button.set_meta("copy", "ad_button")
	reward_button.pressed.connect(_on_reward)
	again_button = _button("", false)
	again_button.set_meta("copy", "again")
	again_button.pressed.connect(func() -> void: start_level(level_index))
	home_button = _button("", false)
	home_button.set_meta("copy", "garden")
	home_button.pressed.connect(_show_menu)
	shop_box = VBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 10)
	shop_box.visible = false
	card.add_child(shop_box)
	shop_button = _button("", true)
	shop_button.set_meta("copy", "shop")
	shop_button.pressed.connect(_open_shop)
	actions.add_child(next_button)
	actions.add_child(reward_button)
	actions.add_child(shop_button)
	actions.add_child(again_button)
	actions.add_child(home_button)
	card.add_child(actions)


func start_level(index: int) -> void:
	level_index = index
	busy = false
	watering = false
	water_left = 1 + Yandex.take_cans()
	_update_water_button()
	menu_host.visible = false
	game_host.visible = true
	var level := _read_level(index)
	_localize_level(level)
	model.setup(level)
	model.grant_moves(Yandex.take_moves())
	board.build(model.grid)
	_fit_screen()
	_show_hud(model.hud())
	board.clear_selected()
	_show_goal_card()


func _on_board_input(event: InputEvent) -> void:
	if menu_host.visible or overlay.visible or busy:
		return
	var local: Vector2 = _event_pos(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(local)
		else:
			_release(local)
	elif event is InputEventMouseMotion and drag_from.x >= 0:
		_drag(local)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_press(local)
		else:
			_release(local)
	elif event is InputEventScreenDrag and drag_from.x >= 0:
		_drag(local)


func _press(local: Vector2) -> void:
	drag_from = board.cell_at(local, model.rows, model.cols)
	drag_point = local
	dragging = false
	if watering:
		watering = false
		if drag_from.x >= 0 and water_left > 0:
			water_left -= 1
			_update_water_button()
			_pour(drag_from)
		else:
			_update_water_button()
		return
	if drag_from.x >= 0:
		board.set_selected(drag_from.x, drag_from.y)


func _drag(local: Vector2) -> void:
	if dragging or drag_from.x < 0:
		return
	var delta := local - drag_point
	if delta.length() < 18.0:
		return
	dragging = true
	var target := drag_from
	if absf(delta.x) > absf(delta.y):
		target.y += 1 if delta.x > 0.0 else -1
	else:
		target.x += 1 if delta.y > 0.0 else -1
	var origin := drag_from
	drag_from = Vector2i(-1, -1)
	_try_swap(origin, target)


func _release(local: Vector2) -> void:
	var origin := drag_from
	drag_from = Vector2i(-1, -1)
	if origin.x < 0 or dragging:
		dragging = false
		return
	var target: Vector2i = board.cell_at(local, model.rows, model.cols)
	if target == origin:
		var cell = model.grid[origin.x][origin.y]
		if cell != null and str(cell.get("power", "")) != "":
			_try_activate(origin)
		return
	if abs(target.x - origin.x) + abs(target.y - origin.y) == 1:
		_try_swap(origin, target)


func _try_swap(a: Vector2i, b: Vector2i) -> void:
	if busy:
		return
	board.clear_selected()
	var result: Dictionary = model.apply_move(a.x, a.y, b.x, b.y)
	if not result.ok:
		Sound.play("deny")
		board.shake_cells(a.x, a.y, b.x, b.y)
		return
	busy = true
	await board.animate_swap(a.x, a.y, b.x, b.y)
	await board.play_frames(result.frames)
	_show_hud(model.hud())
	_after_move()
	busy = false


func _try_activate(cell: Vector2i) -> void:
	if busy:
		return
	board.clear_selected()
	var result: Dictionary = model.activate(cell.x, cell.y)
	if not result.ok:
		Sound.play("deny")
		return
	busy = true
	await board.play_frames(result.frames)
	_show_hud(model.hud())
	_after_move()
	busy = false


func _after_move() -> void:
	if model.goals_met():
		_finish(true)
	elif model.valid_moves().is_empty() and model.moves_left > 0:
		model.shuffle_tiles()
		board.build(model.grid)
	elif model.moves_left <= 0:
		_finish(false)


func _pour(cell: Vector2i) -> void:
	if busy:
		return
	var result: Dictionary = model.pour(cell.x, cell.y)
	if not result.ok:
		water_left += 1
		_update_water_button()
		return
	busy = true
	await board.play_frames(result.frames)
	_show_hud(model.hud())
	_after_move()
	busy = false


func _arm_water() -> void:
	if busy or water_left <= 0 or awaiting_start:
		return
	watering = not watering
	_update_water_button()


func _update_water_button() -> void:
	if water_button == null:
		return
	water_button.disabled = water_left <= 0
	if water_left <= 0:
		water_button.text = Locale.line("can_empty")
	elif watering:
		water_button.text = Locale.line("can_aim")
	else:
		water_button.text = Locale.line("can")


func _show_goal_card() -> void:
	awaiting_start = true
	card_mode = "goal"
	overlay_title.text = "%s · %s" % [model.night, model.level_name]
	overlay_body.text = Locale.line("this_level") % model.level_name
	_fill_overlay_goals()
	_paint_stars(0)
	next_button.visible = true
	next_button.text = Locale.line("start")
	reward_button.visible = false
	shop_button.visible = false
	again_button.visible = false
	home_button.visible = false
	shop_box.visible = false
	_present_overlay()


func _fill_overlay_goals() -> void:
	_drop_children(overlay_goals)
	var hud: Dictionary = model.hud()
	for goal in model.goals:
		overlay_goals.add_child(_goal_chip(
			_goal_title(goal),
			"0/%d" % int(goal.count),
			_goal_icon(goal)
		))
	if hud.is_empty():
		return


func _paint_stars(count: int) -> void:
	_drop_children(star_row)
	if count <= 0:
		return
	for i in 3:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(22, 22)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(11)
		box.bg_color = Color("e0c17a") if i < count else Color("efe6d4")
		dot.add_theme_stylebox_override("panel", box)
		dot.pivot_offset = Vector2(11, 11)
		dot.scale = Vector2(0.2, 0.2)
		star_row.add_child(dot)
		var pop := create_tween()
		pop.tween_interval(0.06 * i)
		pop.tween_property(dot, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)


func _earned_stars() -> int:
	var left := int(model.moves_left)
	if left >= 8:
		return 3
	if left >= 4:
		return 2
	return 1


func _finish(won: bool) -> void:
	awaiting_start = false
	card_mode = "win" if won else "lose"
	again_button.visible = true
	home_button.visible = true
	next_button.text = Locale.line("onward")
	next_button.visible = won and level_index < Catalog.COUNT - 1
	reward_button.visible = not won
	shop_button.visible = not won
	shop_box.visible = false
	_drop_children(overlay_goals)
	if won:
		var lamps := _earned_stars()
		_fill_win_card()
		EventBus.level_won.emit(model.level_id, model.score)
		Yandex.note_stars(model.level_id, lamps)
		Yandex.save_progress(model.level_id)
		Yandex.submit_score(model.score)
		if garden:
			garden.set_restored(Yandex.cleared)
		Sound.play("win")
	else:
		_fill_lose_card()
		EventBus.level_lost.emit(model.level_id)
		Sound.play("lose")
	_present_overlay()


func _fill_win_card() -> void:
	var last := level_index >= Catalog.COUNT - 1
	overlay_title.text = Locale.line("lit") if last else Locale.line("cleared")
	_paint_stars(_earned_stars())
	if last:
		overlay_body.text = Locale.line("finale")
	else:
		var next_level := Catalog.build(level_index + 1)
		var next_name := Locale.line(str(next_level.name_key))
		overlay_body.text = Locale.line("next_level") % next_name


func _fill_lose_card() -> void:
	_paint_stars(0)
	var close := model.goal_fraction() >= 0.65
	overlay_title.text = Locale.line("almost") if close else Locale.line("out")
	overlay_body.text = Locale.line("almost_ad") if close else Locale.line("out_ad")


func _show_how() -> void:
	card_mode = "how"
	overlay_title.text = Locale.line("how_title")
	overlay_body.text = Locale.line("how_body")
	_drop_children(overlay_goals)
	_paint_stars(0)
	next_button.visible = true
	next_button.text = Locale.line("how_ok")
	reward_button.visible = false
	shop_button.visible = false
	again_button.visible = false
	home_button.visible = false
	shop_box.visible = false
	_present_overlay()


func _open_shop() -> void:
	_shop_from = card_mode
	card_mode = "shop"
	overlay_title.text = Locale.line("shop_title")
	overlay_body.text = ""
	_drop_children(overlay_goals)
	_paint_stars(0)
	next_button.visible = true
	next_button.text = Locale.line("shop_close")
	reward_button.visible = false
	shop_button.visible = false
	again_button.visible = false
	home_button.visible = false
	shop_box.visible = true
	_fill_shop()
	_present_overlay()
	Yandex.refresh_catalog()


func _close_shop() -> void:
	shop_box.visible = false
	var back := _shop_from
	_shop_from = ""
	if back == "lose":
		card_mode = "lose"
		again_button.visible = true
		home_button.visible = true
		reward_button.visible = true
		shop_button.visible = true
		next_button.visible = false
		_fill_lose_card()
		_present_overlay()
		return
	card_mode = ""
	overlay.visible = false


func _fill_shop() -> void:
	if shop_box == null:
		return
	_drop_children(shop_box)
	var rows: Array = Yandex.catalog
	if rows.is_empty():
		rows = Yandex._editor_catalog()
	for item in rows:
		if not (item is Dictionary):
			continue
		var product_id := str(item.get("id", ""))
		if not Yandex.PRODUCTS.has(product_id):
			continue
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)
		var title := _label(_product_title(product_id, item), 28, Color("1d4a32"))
		title.add_theme_font_override("font", display_font)
		title.set_meta("display", true)
		var about := _label(_product_body(product_id, item), 20, Color("4a3424"))
		var buy := _button(_product_price(product_id, item), true)
		if product_id == "quiet" and Yandex.ads_off:
			buy.text = Locale.line("shop_owned")
			buy.disabled = true
		elif _buying:
			buy.disabled = true
		else:
			buy.pressed.connect(_buy_product.bind(product_id))
		block.add_child(title)
		block.add_child(about)
		block.add_child(buy)
		shop_box.add_child(block)


func _product_title(product_id: String, item: Dictionary) -> String:
	var remote := str(item.get("title", ""))
	if remote != "":
		return remote
	return Locale.line("prod_" + product_id)


func _product_body(product_id: String, item: Dictionary) -> String:
	var remote := str(item.get("description", ""))
	if remote != "":
		return remote
	return Locale.line("prod_" + product_id + "_body")


func _product_price(product_id: String, item: Dictionary) -> String:
	var remote := str(item.get("price", ""))
	if remote != "":
		return remote
	return Locale.line("prod_" + product_id)


func _buy_product(product_id: String) -> void:
	if _buying:
		return
	_buying = true
	_fill_shop()
	Yandex.buy(product_id)


func _on_catalog() -> void:
	if card_mode == "shop":
		_fill_shop()
		_fit_screen()


func _on_progress() -> void:
	if menu_host != null and menu_host.visible and not overlay.visible:
		_refresh_home()


func _on_purchase(product_id: String, ok: bool, token: String, consumable: bool) -> void:
	_buying = false
	if not ok:
		if card_mode == "shop":
			overlay_body.text = Locale.line("shop_fail")
			_fill_shop()
		return
	_apply_purchase(product_id)
	if consumable:
		Yandex.seal(token)
	if product_id == "quiet":
		if card_mode == "shop":
			_fill_shop()
		return
	if game_host != null and game_host.visible:
		shop_box.visible = false
		card_mode = ""
		_shop_from = ""
		overlay.visible = false
		busy = false
		_show_hud(model.hud())
		return
	if card_mode == "shop":
		overlay_body.text = Locale.line("shop_later")
		_fill_shop()


func _apply_purchase(product_id: String) -> void:
	var live := game_host != null and game_host.visible and model != null and card_mode != "win"
	if product_id == "moves5":
		if live:
			model.grant_moves(5)
			if model.valid_moves().is_empty():
				model.shuffle_tiles()
				board.build(model.grid)
		else:
			Yandex.bank_moves(5)
	elif product_id == "can":
		if live:
			water_left += 1
			_update_water_button()
		else:
			Yandex.bank_cans(1)
	elif product_id == "quiet":
		pass


func _on_next() -> void:
	if card_mode == "shop":
		_close_shop()
		return
	if card_mode == "how":
		card_mode = ""
		overlay.visible = false
		return
	if awaiting_start:
		awaiting_start = false
		overlay.visible = false
		return
	await Yandex.between_levels()
	start_level(level_index + 1)


func _on_reward() -> void:
	await Yandex.show_rewarded()
	if not Yandex.last_reward:
		overlay_body.text = Locale.line("ad_skip")
		return
	model.grant_moves(5)
	if model.valid_moves().is_empty():
		model.shuffle_tiles()
		board.build(model.grid)
	card_mode = ""
	overlay.visible = false
	busy = false
	_show_hud(model.hud())


func _on_matched() -> void:
	if game_keeper:
		game_keeper.cheer()
	if keeper:
		keeper.cheer()


func _continue() -> void:
	start_level(_next_index())


func _next_index() -> int:
	if Yandex.cleared >= Catalog.COUNT:
		return Catalog.COUNT - 1
	return Yandex.cleared


func _refresh_home() -> void:
	var done := int(Yandex.cleared)
	if garden:
		garden.set_restored(done)
	var upcoming := Catalog.build(_next_index())
	var upcoming_name := Locale.line(str(upcoming.name_key))
	if done <= 0:
		progress_label.text = Locale.line("night") % 1
		repair_label.text = Locale.line("next_level") % upcoming_name
		continue_button.text = Locale.line("enter")
	elif done >= Catalog.COUNT:
		progress_label.text = Locale.line("done_title")
		repair_label.text = Locale.line("done_body")
		continue_button.text = Locale.line("replay")
	else:
		progress_label.text = Locale.line("night") % (done + 1)
		repair_label.text = Locale.line("next_level") % upcoming_name
		continue_button.text = Locale.line("onward")
	var earned := 0
	var star_index := mini(done, Catalog.COUNT - 1)
	if star_index < Yandex.best_stars.size():
		earned = int(Yandex.best_stars[star_index])
	for i in night_lamps.size():
		night_lamps[i].visible = earned > 0
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(9)
		box.bg_color = Color("e0c17a") if i < earned else Color("efe6d4")
		night_lamps[i].add_theme_stylebox_override("panel", box)


func _show_menu() -> void:
	busy = false
	card_mode = ""
	overlay.visible = false
	game_host.visible = false
	menu_host.visible = true
	_refresh_home()


func _show_hud(hud: Dictionary) -> void:
	night_label.text = model.night
	title_label.text = model.level_name
	story_label.text = model.line
	moves_label.text = Locale.line("moves") % int(hud.moves_left)
	score_label.text = Locale.line("light") % int(hud.score)
	if goals_row == null:
		return
	for child in goals_row.get_children():
		child.queue_free()
	for goal in model.goals:
		var have := _goal_have(goal, hud)
		goals_row.add_child(_goal_chip(
			_goal_title(goal),
			"%d/%d" % [mini(have, int(goal.count)), int(goal.count)],
			_goal_icon(goal)
		))


func _read_level(index: int) -> Dictionary:
	return Catalog.build(index)


func _localize_level(level: Dictionary) -> void:
	level_number = int(level.get("number", level.get("id", 1)))
	name_key = str(level.get("name_key", ""))
	line_key = str(level.get("line_key", ""))
	level["night"] = Locale.line("night") % level_number
	level["name"] = Locale.line(name_key) if name_key != "" else str(level.get("name", ""))
	level["line"] = Locale.line(line_key) if line_key != "" else str(level.get("line", ""))


func _goal_title(goal: Dictionary) -> String:
	if str(goal.kind) == "collect":
		return _tile_name(str(goal.tile))
	if str(goal.kind) == "bud":
		return Locale.line("bud")
	if str(goal.kind) == "power":
		return Locale.line("lamps")
	return Locale.line("frost")


func _goal_icon(goal: Dictionary) -> Dictionary:
	if str(goal.kind) == "collect":
		return { "kind": "tile", "id": 0, "tile": goal.tile, "power": "" }
	if str(goal.kind) == "bud":
		return { "kind": "bud", "id": 0, "hp": 2 }
	if str(goal.kind) == "power":
		return { "kind": "tile", "id": 0, "tile": "pearl", "power": "spark" }
	return { "kind": "glass", "id": 0, "hp": 2 }


func _goal_have(goal: Dictionary, hud: Dictionary) -> int:
	if str(goal.kind) == "collect":
		return int(hud.collected.get(goal.tile, 0))
	if str(goal.kind) == "bud":
		return int(hud.get("buds_cleared", 0))
	if str(goal.kind) == "power":
		return int(hud.get("powers_made", 0))
	return int(hud.glass_cleared)


func _present_overlay() -> void:
	overlay.visible = true
	_fit_overlay(size if size.x > 8.0 else get_viewport_rect().size, _safe_insets(size if size.x > 8.0 else get_viewport_rect().size))
	if overlay_tween:
		overlay_tween.kill()
	overlay_panel.scale = Vector2(overlay_fit, overlay_fit) * 0.92
	overlay_tween = create_tween()
	overlay_tween.tween_property(overlay_panel, "scale", Vector2(overlay_fit, overlay_fit), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_language(_code: String) -> void:
	_apply_fonts()
	_walk_fonts(self)
	_apply_static_copy(self)
	if model != null and name_key != "":
		model.night = Locale.line("night") % level_number
		model.level_name = Locale.line(name_key)
		model.line = Locale.line(line_key)
	if menu_host != null and menu_host.visible:
		_refresh_home()
	if game_host != null and game_host.visible and model != null:
		_show_hud(model.hud())
		_update_water_button()
	if card_mode == "goal":
		overlay_title.text = "%s · %s" % [model.night, model.level_name]
		overlay_body.text = Locale.line("this_level") % model.level_name
		next_button.text = Locale.line("start")
		_fill_overlay_goals()
	elif card_mode == "win":
		_fill_win_card()
	elif card_mode == "lose":
		_fill_lose_card()
	elif card_mode == "how":
		overlay_title.text = Locale.line("how_title")
		overlay_body.text = Locale.line("how_body")
		next_button.text = Locale.line("how_ok")
	elif card_mode == "shop":
		overlay_title.text = Locale.line("shop_title")
		next_button.text = Locale.line("shop_close")
		_fill_shop()
	_fit_screen()


func _apply_fonts() -> void:
	ui_font = SystemFont.new()
	ui_font.font_names = Locale.ui_fonts()
	display_font = SystemFont.new()
	display_font.font_names = Locale.display_fonts()


func _walk_fonts(node: Node) -> void:
	if node is Label or node is Button:
		var font := display_font if bool(node.get_meta("display", false)) else ui_font
		node.add_theme_font_override("font", font)
		if node is Control:
			node.text_direction = Locale.direction() as Control.TextDirection
	for child in node.get_children():
		_walk_fonts(child)


func _apply_static_copy(node: Node) -> void:
	if (node is Label or node is Button) and node.has_meta("copy"):
		node.text = Locale.line(str(node.get_meta("copy")))
	for child in node.get_children():
		_apply_static_copy(child)


func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return event.position
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO


func _fit_screen() -> void:
	if menu == null or game == null or board_slot == null or overlay_panel == null:
		return
	var vp := size
	if vp.x < 8.0:
		vp = get_viewport_rect().size
	var pad := _safe_insets(vp)
	_pad_host(menu_host, pad)
	_pad_host(game_host, pad)
	var inner_w := vp.x - pad.x - pad.z
	var col := clampf(inner_w - 8.0, 280.0, 640.0)
	menu.custom_minimum_size.x = col
	game.custom_minimum_size.x = col
	if overlay_card:
		overlay_card.custom_minimum_size.x = 0
	_fit_board(vp.y - pad.y - pad.w)
	_fit_overlay(vp, pad)


func _pad_host(host: Control, pad: Vector4) -> void:
	if host == null:
		return
	host.offset_left = pad.x
	host.offset_top = pad.y
	host.offset_right = -pad.z
	host.offset_bottom = -pad.w


func _safe_insets(vp: Vector2) -> Vector4:
	var win := Vector2(DisplayServer.window_get_size())
	if win.x < 2.0 or win.y < 2.0 or vp.x < 2.0 or vp.y < 2.0:
		return Vector4(16, 20, 16, 24)
	var safe := DisplayServer.get_display_safe_area()
	var left := float(safe.position.x) / win.x * vp.x
	var top := float(safe.position.y) / win.y * vp.y
	var right := float(win.x - (safe.position.x + safe.size.x)) / win.x * vp.x
	var bottom := float(win.y - (safe.position.y + safe.size.y)) / win.y * vp.y
	return Vector4(maxf(left, 14.0), maxf(top, 16.0), maxf(right, 14.0), maxf(bottom, 20.0))


func _fit_board(inner_h: float) -> void:
	var natural: Vector2 = board.size
	if natural.y < 32.0:
		natural = board.custom_minimum_size
	var others := 0.0
	for child in game.get_children():
		if child == board_slot:
			continue
		others += child.get_combined_minimum_size().y
	var sep := float(game.get_theme_constant("separation"))
	others += sep * float(maxi(game.get_child_count() - 1, 0))
	var room := inner_h - others - 8.0
	var full: float = natural.y + 28.0
	var fit := 1.0
	if full > 1.0:
		fit = clampf(room / full, 0.58, 1.0)
	board.scale = Vector2(fit, fit)
	board.position = Vector2(14, 14) * fit
	board_slot.custom_minimum_size = (natural + Vector2(28, 28)) * fit


func _fit_overlay(vp: Vector2, pad: Vector4) -> void:
	var avail_w := maxf(280.0, vp.x - pad.x - pad.z - 28.0)
	var avail_h := maxf(320.0, vp.y - pad.y - pad.w - 28.0)
	var w := minf(560.0, avail_w)
	var inner := maxf(220.0, w - 44.0)
	var content_h := 280.0
	if overlay_card:
		overlay_card.custom_minimum_size = Vector2(inner, 0)
		content_h = _column_height(overlay_card, inner) + 52.0
	var limit := minf(760.0, avail_h * 0.9)
	var h := minf(maxf(content_h, 200.0), limit)
	overlay_fit = 1.0
	if content_h > h + 1.0:
		overlay_fit = clampf(h / content_h, 0.72, 1.0)
		h = content_h
	overlay_panel.offset_left = -w * 0.5
	overlay_panel.offset_right = w * 0.5
	overlay_panel.offset_top = -h * 0.5
	overlay_panel.offset_bottom = h * 0.5
	overlay_panel.pivot_offset = Vector2(w, h) * 0.5
	if overlay_tween == null or not overlay_tween.is_running():
		overlay_panel.scale = Vector2(overlay_fit, overlay_fit)


func _column_height(box: VBoxContainer, width: float) -> float:
	var total := 0.0
	var count := 0
	var sep := float(box.get_theme_constant("separation"))
	for child in box.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		total += _control_height(child as Control, width)
		count += 1
	if count > 1:
		total += sep * float(count - 1)
	return total


func _control_height(node: Control, width: float) -> float:
	node.size.x = width
	if node is Label:
		(node as Label).custom_minimum_size.x = width
		return (node as Label).get_combined_minimum_size().y
	if node is HFlowContainer:
		return _flow_height(node as HFlowContainer, width)
	if node is VBoxContainer:
		return _column_height(node as VBoxContainer, width)
	return node.get_combined_minimum_size().y


func _flow_height(flow: HFlowContainer, width: float) -> float:
	var x := 0.0
	var row_h := 0.0
	var total := 0.0
	var hsep := float(flow.get_theme_constant("h_separation"))
	var vsep := float(flow.get_theme_constant("v_separation"))
	var any := false
	for child in flow.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		var item := child as Control
		var s := item.get_combined_minimum_size()
		var item_w := s.x
		if item is Button:
			item_w = maxf(item_w, 148.0)
		if any and x + item_w > width + 1.0:
			total += row_h + vsep
			x = 0.0
			row_h = 0.0
		x += item_w + hsep
		row_h = maxf(row_h, s.y)
		any = true
	return total + row_h


func _drop_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _host(content: Control) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(content)
	return center


func _column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(580, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 14)
	return box


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if ui_font:
		label.add_theme_font_override("font", ui_font)
	label.text_direction = Locale.direction() as Control.TextDirection
	return label


func _button(text: String, solid: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(148, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 20)
	if ui_font:
		button.add_theme_font_override("font", ui_font)
	button.text_direction = Locale.direction() as Control.TextDirection
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(16)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	if solid:
		box.bg_color = Color("e0c17a")
		button.add_theme_color_override("font_color", Color("2a1c0e"))
		button.add_theme_color_override("font_hover_color", Color("2a1c0e"))
		button.add_theme_color_override("font_pressed_color", Color("2a1c0e"))
	else:
		box.bg_color = Color("fffaf2")
		box.border_color = Color("e2a83a")
		box.set_border_width_all(2)
		button.add_theme_color_override("font_color", Color("3a2a16"))
		button.add_theme_color_override("font_hover_color", Color("3a2a16"))
		button.add_theme_color_override("font_pressed_color", Color("3a2a16"))
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", box)
	return button


func _goal_chip(title: String, value: String, cell: Dictionary) -> Control:
	var chip := VBoxContainer.new()
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_theme_constant_override("separation", 8)
	var icon = Piece.new()
	icon.fit_px = 52
	icon.set_piece(cell)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.add_child(icon)
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var plate_box := StyleBoxFlat.new()
	plate_box.bg_color = Color("fffaf2")
	plate_box.border_color = Color("e2c48a")
	plate_box.set_border_width_all(1)
	plate_box.set_corner_radius_all(12)
	plate_box.content_margin_left = 8
	plate_box.content_margin_right = 8
	plate_box.content_margin_top = 4
	plate_box.content_margin_bottom = 5
	plate.add_theme_stylebox_override("panel", plate_box)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	var name := _label(title, 16, Color("3a2a16"))
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var count := _label(value, 18, Color("1d4a32"))
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	count.add_theme_font_override("font", display_font)
	plate.custom_minimum_size = Vector2(96, 0)
	words.add_child(name)
	words.add_child(count)
	plate.add_child(words)
	chip.add_child(plate)
	return chip


func _tile_name(tile: String) -> String:
	if tile in ["fern", "beetle", "moss", "pearl", "vine", "moth"]:
		return Locale.line(tile)
	return tile


func mini(a: int, b: int) -> int:
	return a if a < b else b
