extends Node

const LEVEL_COUNT := 150

## Official Yandex Games SDK, called from the exported page.
## Outside the Yandex shell the calls do nothing, except a rewarded video
## in the editor: it resolves so the extra-moves button can be tried.

signal rewarded_finished(success: bool)
signal purchase_resolved(product_id: String, ok: bool, token: String, consumable: bool)
signal catalog_changed
signal progress_changed

const PRODUCTS := {
	"moves5": true,
	"can": true,
	"quiet": false,
}

var ad_open := false
var last_reward := false
var cleared := 0
var best_stars: Array = []
var ads_off := false
var banked_moves := 0
var banked_cans := 0
var catalog: Array = []
var _reward_state := ""
var _handled_tokens: Array = []
var _sealed_tokens: Array = []
var _listener_ready := false
var _inbox: Array = []
var _pending_polls := 0
var _cloud_done := false
var _purchases_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_local()
	if OS.has_feature("web"):
		set_process(true)
		JavaScriptBridge.eval("""
			(function () {
				if (window.__ysdk || window.__lumenSdkStarted) return;
				window.__lumenSdkStarted = true;
				var script = document.createElement('script');
				script.async = true;
				script.src = '/sdk.js';
				script.onload = function () {
					if (typeof YaGames === 'undefined') return;
					YaGames.init().then(function (ysdk) {
						window.__ysdk = ysdk;
						var lang = ysdk.environment && ysdk.environment.i18n && ysdk.environment.i18n.lang;
						window.__lumenLang = lang || '';
						if (ysdk.features && ysdk.features.LoadingAPI) ysdk.features.LoadingAPI.ready();
						ysdk.getPlayer({ signed: false }).then(function (player) {
							window.__lumenPlayer = player;
							return player.getData();
						}).then(function (data) {
							window.__lumenCloud = JSON.stringify(data || {});
							window.__lumenCloudState = 'ok';
						}).catch(function () {
							window.__lumenCloudState = 'error';
						});
						var ready = ysdk.getPayments ? ysdk.getPayments({ signed: false }) : Promise.resolve(ysdk.payments);
						ready.then(function (payments) {
							window.__lumenPayments = payments;
							return payments.getPurchases();
						}).then(function (list) {
							window.__lumenPending = JSON.stringify(list || []);
							window.__lumenPendingState = 'ok';
						}).catch(function () {
							window.__lumenPendingState = 'error';
						});
					});
				};
				document.body.appendChild(script);
			})();
		""", true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_mute(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and not ad_open:
		_mute(false)


func between_levels() -> void:
	await _show_interstitial()


func show_rewarded() -> void:
	if ad_open:
		last_reward = false
		return
	last_reward = false
	ad_open = true
	_mute(true)
	if not OS.has_feature("web"):
		await get_tree().create_timer(0.35).timeout
		_finish_reward(true)
		return
	_reward_state = ""
	JavaScriptBridge.eval("""
		(function () {
			window.__lumenReward = '';
			if (!window.__ysdk || !window.__ysdk.adv) {
				window.__lumenReward = 'error';
				return;
			}
			window.__ysdk.adv.showRewardedVideo({
				callbacks: {
					onOpen: function () {},
					onRewarded: function () { window.__lumenReward = 'ok'; },
					onClose: function () {
						if (window.__lumenReward !== 'ok') window.__lumenReward = 'closed';
					},
					onError: function () { window.__lumenReward = 'error'; }
				}
			});
		})();
	""", true)
	for _i in 80:
		await get_tree().create_timer(0.25).timeout
		var state = str(JavaScriptBridge.eval("window.__lumenReward || ''", true))
		if state == "":
			continue
		_finish_reward(state == "ok")
		return
	_finish_reward(false)


func note_stars(level_id: int, count: int) -> void:
	var index := level_id - 1
	if index < 0 or index >= LEVEL_COUNT:
		return
	while best_stars.size() <= index:
		best_stars.append(0)
	var safe := clampi(count, 0, 3)
	if safe > int(best_stars[index]):
		best_stars[index] = safe
	_write_save()


func save_progress(cleared_level: int) -> void:
	var safe := clampi(cleared_level, 0, LEVEL_COUNT)
	if safe > cleared:
		cleared = safe
	_write_save()


func _write_save() -> void:
	var file := FileAccess.open("user://lumen_save.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
		"cleared": cleared,
		"stars": best_stars,
		"ads_off": ads_off,
		"banked_moves": banked_moves,
		"banked_cans": banked_cans,
		"handled_tokens": _handled_tokens,
	}))
	if not OS.has_feature("web"):
		return
	var payload := JSON.stringify({
		"cleared": cleared,
		"stars": best_stars,
		"ads_off": ads_off,
		"banked_moves": banked_moves,
		"banked_cans": banked_cans,
		"handled_tokens": _handled_tokens,
	})
	JavaScriptBridge.eval(
		"if (window.__ysdk && window.__ysdk.getPlayer) { var send = function (player) { player.setData("
		+ payload
		+ ", true); player.setStats({nights: " + str(cleared) + "}); }; if (window.__lumenPlayer) send(window.__lumenPlayer); else window.__ysdk.getPlayer({signed:false}).then(function (player) { window.__lumenPlayer = player; send(player); }).catch(function () {}); }",
		true
	)


func _load_local() -> void:
	if not FileAccess.file_exists("user://lumen_save.json"):
		return
	var file := FileAccess.open("user://lumen_save.json", FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	cleared = clampi(int(data.get("cleared", 0)), 0, LEVEL_COUNT)
	ads_off = bool(data.get("ads_off", false))
	banked_moves = maxi(0, int(data.get("banked_moves", 0)))
	banked_cans = maxi(0, int(data.get("banked_cans", 0)))
	_handled_tokens = []
	var tokens = data.get("handled_tokens", [])
	if tokens is Array:
		for token in tokens:
			_handled_tokens.append(str(token))
	var raw = data.get("stars", [])
	best_stars = []
	if raw is Array:
		var limit := mini(raw.size(), LEVEL_COUNT)
		for i in limit:
			var item = raw[i]
			if typeof(item) == TYPE_INT or typeof(item) == TYPE_FLOAT:
				best_stars.append(clampi(int(item), 0, 3))
			else:
				best_stars.append(0)


func _merge_cloud(data: Dictionary) -> void:
	var changed := false
	var remote_cleared := clampi(int(data.get("cleared", 0)), 0, LEVEL_COUNT)
	if remote_cleared > cleared:
		cleared = remote_cleared
		changed = true
	if bool(data.get("ads_off", false)) and not ads_off:
		ads_off = true
		changed = true
	var moves := maxi(0, int(data.get("banked_moves", 0)))
	if moves > banked_moves:
		banked_moves = moves
		changed = true
	var cans := maxi(0, int(data.get("banked_cans", 0)))
	if cans > banked_cans:
		banked_cans = cans
		changed = true
	var raw = data.get("stars", [])
	if raw is Array:
		var limit := mini(raw.size(), LEVEL_COUNT)
		while best_stars.size() < limit:
			best_stars.append(0)
			changed = true
		for i in limit:
			var item = raw[i]
			if typeof(item) != TYPE_INT and typeof(item) != TYPE_FLOAT:
				continue
			var star := clampi(int(item), 0, 3)
			if star > int(best_stars[i]):
				best_stars[i] = star
				changed = true
	var tokens = data.get("handled_tokens", [])
	if tokens is Array:
		for token in tokens:
			var text := str(token)
			if text != "" and not _handled_tokens.has(text):
				_handled_tokens.append(text)
				changed = true
	var behind := remote_cleared < cleared
	if not behind:
		var remote_stars = data.get("stars", [])
		if remote_stars is Array and best_stars.size() > remote_stars.size():
			behind = true
	if changed:
		_write_save()
		progress_changed.emit()
	elif behind:
		_write_save()


func submit_score(score: int) -> void:
	if not OS.has_feature("web"):
		return
	var safe_score := maxi(0, score)
	JavaScriptBridge.eval(
		"if (window.__ysdk && window.__ysdk.getLeaderboards) { window.__ysdk.getLeaderboards().then(function (lb) { lb.setLeaderboardScore('lumen', "
		+ str(safe_score)
		+ "); }).catch(function () {}); }",
		true
	)


func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	_pending_polls += 1
	if not _cloud_done:
		var cloud_state := str(JavaScriptBridge.eval("window.__lumenCloudState || ''", true))
		if cloud_state == "ok":
			_cloud_done = true
			var cloud = JSON.parse_string(str(JavaScriptBridge.eval("window.__lumenCloud || '{}'", true)))
			if cloud is Dictionary:
				_merge_cloud(cloud)
		elif cloud_state == "error":
			_cloud_done = true
	if not _purchases_done:
		var state := str(JavaScriptBridge.eval("window.__lumenPendingState || ''", true))
		if state == "ok":
			_purchases_done = true
			var raw := str(JavaScriptBridge.eval("window.__lumenPending || '[]'", true))
			var parsed = JSON.parse_string(raw)
			if parsed is Array:
				for item in parsed:
					if item is Dictionary:
						_deliver_purchase(str(item.get("productID", "")), str(item.get("purchaseToken", "")))
		elif state == "error":
			_purchases_done = true
	if (_cloud_done and _purchases_done) or _pending_polls > 900:
		set_process(false)


func refresh_catalog() -> void:
	if not OS.has_feature("web"):
		catalog = _editor_catalog()
		catalog_changed.emit()
		return
	JavaScriptBridge.eval("""
		(function () {
			window.__lumenCatalogState = '';
			var run = function (payments) {
				payments.getCatalog().then(function (list) {
					var rows = (list || []).map(function (item) {
						return {
							id: item.id,
							title: item.title,
							description: item.description,
							price: item.price,
							image: item.imageURI || ''
						};
					});
					window.__lumenCatalog = JSON.stringify(rows);
					window.__lumenCatalogState = 'ok';
				}).catch(function () { window.__lumenCatalogState = 'error'; });
			};
			if (window.__lumenPayments) { run(window.__lumenPayments); return; }
			if (!window.__ysdk) { window.__lumenCatalogState = 'error'; return; }
			var ready = window.__ysdk.getPayments ? window.__ysdk.getPayments({ signed: false }) : Promise.resolve(window.__ysdk.payments);
			ready.then(function (payments) {
				window.__lumenPayments = payments;
				run(payments);
			}).catch(function () { window.__lumenCatalogState = 'error'; });
		})();
	""", true)
	for _i in 40:
		await get_tree().create_timer(0.1).timeout
		var state := str(JavaScriptBridge.eval("window.__lumenCatalogState || ''", true))
		if state == "":
			continue
		if state == "ok":
			var parsed = JSON.parse_string(str(JavaScriptBridge.eval("window.__lumenCatalog || '[]'", true)))
			if parsed is Array:
				catalog = parsed
		catalog_changed.emit()
		return
	catalog_changed.emit()


func buy(product_id: String) -> void:
	if not PRODUCTS.has(product_id):
		purchase_resolved.emit(product_id, false, "", false)
		return
	var consumable := bool(PRODUCTS[product_id])
	if not OS.has_feature("web"):
		await get_tree().create_timer(0.35).timeout
		_deliver_purchase(product_id, "")
		return
	JavaScriptBridge.eval(
		"(function () { window.__lumenBuy = ''; window.__lumenBuyToken = ''; var id = "
		+ JSON.stringify(product_id)
		+ "; var run = function (payments) { payments.purchase({ id: id }).then(function (purchase) { window.__lumenBuyToken = (purchase && purchase.purchaseToken) || ''; window.__lumenBuy = 'ok'; }).catch(function () { window.__lumenBuy = 'error'; }); }; if (window.__lumenPayments) { run(window.__lumenPayments); return; } if (!window.__ysdk) { window.__lumenBuy = 'error'; return; } var ready = window.__ysdk.getPayments ? window.__ysdk.getPayments({ signed: false }) : Promise.resolve(window.__ysdk.payments); ready.then(function (payments) { window.__lumenPayments = payments; run(payments); }).catch(function () { window.__lumenBuy = 'error'; }); })();",
		true
	)
	for _i in 80:
		await get_tree().create_timer(0.25).timeout
		var state := str(JavaScriptBridge.eval("window.__lumenBuy || ''", true))
		if state == "":
			continue
		if state == "ok":
			var token := str(JavaScriptBridge.eval("window.__lumenBuyToken || ''", true))
			_deliver_purchase(product_id, token)
		else:
			purchase_resolved.emit(product_id, false, "", consumable)
		return
	purchase_resolved.emit(product_id, false, "", consumable)


func seal(token: String) -> void:
	if token == "":
		return
	if token not in _handled_tokens:
		_handled_tokens.append(token)
	_sealed_tokens.erase(token)
	_write_save()
	consume(token)


func consume(token: String) -> void:
	if token == "" or not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"(function () { var token = "
		+ JSON.stringify(token)
		+ "; var run = function (payments) { payments.consumePurchase(token).catch(function () {}); }; if (window.__lumenPayments) { run(window.__lumenPayments); return; } if (window.__ysdk && window.__ysdk.payments) run(window.__ysdk.payments); })();",
		true
	)


func mark_listener_ready() -> void:
	_listener_ready = true
	for item in _inbox:
		purchase_resolved.emit(str(item.id), true, str(item.token), bool(item.consumable))
	_inbox.clear()


func bank_moves(count: int) -> void:
	banked_moves += count
	_write_save()


func bank_cans(count: int) -> void:
	banked_cans += count
	_write_save()


func take_moves() -> int:
	var count := banked_moves
	banked_moves = 0
	if count > 0:
		_write_save()
	return count


func take_cans() -> int:
	var count := banked_cans
	banked_cans = 0
	if count > 0:
		_write_save()
	return count


func _deliver_purchase(product_id: String, token: String) -> void:
	if not PRODUCTS.has(product_id):
		return
	var consumable := bool(PRODUCTS[product_id])
	if token != "" and (token in _handled_tokens or token in _sealed_tokens):
		if consumable and token in _handled_tokens:
			consume(token)
		return
	if token != "":
		_sealed_tokens.append(token)
	if product_id == "quiet":
		ads_off = true
		_write_save()
	var packet := { "id": product_id, "token": token, "consumable": consumable }
	if _listener_ready:
		purchase_resolved.emit(product_id, true, token, consumable)
	else:
		_inbox.append(packet)


func _editor_catalog() -> Array:
	return [
		{ "id": "moves5", "title": "", "description": "", "price": "25", "image": "" },
		{ "id": "can", "title": "", "description": "", "price": "15", "image": "" },
		{ "id": "quiet", "title": "", "description": "", "price": "99", "image": "" },
	]


func _show_interstitial() -> void:
	if ads_off or not OS.has_feature("web"):
		return
	ad_open = true
	_mute(true)
	_reward_state = ""
	JavaScriptBridge.eval("""
		(function () {
			window.__lumenInterstitial = '';
			if (!window.__ysdk || !window.__ysdk.adv) {
				window.__lumenInterstitial = 'skip';
				return;
			}
			window.__ysdk.adv.showFullscreenAdv({
				callbacks: {
					onClose: function () { window.__lumenInterstitial = 'closed'; },
					onError: function () { window.__lumenInterstitial = 'error'; }
				}
			});
		})();
	""", true)
	for _i in 80:
		await get_tree().create_timer(0.25).timeout
		var state = str(JavaScriptBridge.eval("window.__lumenInterstitial || ''", true))
		if state != "":
			break
	ad_open = false
	_mute(false)


func _finish_reward(success: bool) -> void:
	ad_open = false
	last_reward = success
	_mute(false)
	rewarded_finished.emit(success)


func _mute(muted: bool) -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, muted)
