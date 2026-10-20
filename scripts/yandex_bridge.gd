extends Node

const LEVEL_COUNT := 150

## Official Yandex Games SDK, called from the exported page.
## Outside the Yandex shell the calls do nothing, except a rewarded video
## in the editor: it resolves so the extra-moves button can be tried.

signal rewarded_finished(success: bool)

var ad_open := false
var last_reward := false
var cleared := 0
var best_stars: Array = []
var _reward_state := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_local()
	if OS.has_feature("web"):
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
		file.store_string(JSON.stringify({ "cleared": cleared, "stars": best_stars }))
	if not OS.has_feature("web"):
		return
	var payload := JSON.stringify({ "cleared": cleared, "stars": best_stars })
	JavaScriptBridge.eval(
		"if (window.__ysdk && window.__ysdk.getPlayer) { window.__ysdk.getPlayer().then(function (player) { player.setData("
		+ payload
		+ ", true); }).catch(function () {}); }",
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


func _show_interstitial() -> void:
	if not OS.has_feature("web"):
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
