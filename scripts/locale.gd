extends Node

signal language_changed(code: String)

var lang := "ru"
var _pack: Dictionary = {}
var _polls := 0


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://locale/ui.json"))
	if typeof(parsed) == TYPE_DICTIONARY:
		_pack = parsed
	_apply(_from_device(), false)
	set_process(OS.has_feature("web"))


func _process(_delta: float) -> void:
	_polls += 1
	var raw := str(JavaScriptBridge.eval("String(window.__lumenLang || '')", true)).strip_edges()
	if raw != "" and raw != "null":
		_apply(raw, true)
		set_process(false)
	elif _polls > 600:
		set_process(false)


func line(key: String) -> String:
	var table = _pack.get(lang, {})
	if table is Dictionary and table.has(key):
		return str(table[key])
	var english = _pack.get("en", {})
	if english is Dictionary and english.has(key):
		return str(english[key])
	var russian = _pack.get("ru", {})
	if russian is Dictionary and russian.has(key):
		return str(russian[key])
	return key


func ui_fonts() -> PackedStringArray:
	match _script_group():
		"cjk":
			return PackedStringArray(["PingFang SC", "Hiragino Sans", "Noto Sans CJK SC", "Microsoft YaHei", "Yu Gothic", "Malgun Gothic", "Arial Unicode MS"])
		"ar":
			return PackedStringArray(["SF Arabic", "Geeza Pro", "Noto Naskh Arabic", "Arial"])
		"hi":
			return PackedStringArray(["Kohinoor Devanagari", "Noto Sans Devanagari", "Nirmala UI", "Mangal"])
		_:
			return PackedStringArray(["Avenir Next", "Segoe UI", "Helvetica Neue", "Noto Sans", "Trebuchet MS"])


func display_fonts() -> PackedStringArray:
	if _script_group() != "latin":
		return ui_fonts()
	return PackedStringArray(["Iowan Old Style", "Palatino", "Georgia", "Times New Roman", "Noto Serif"])


func direction() -> int:
	if lang == "ar":
		return Control.TEXT_DIRECTION_RTL
	return Control.TEXT_DIRECTION_AUTO


func _from_device() -> String:
	var code := OS.get_locale_language()
	if OS.has_feature("web"):
		var nav := str(JavaScriptBridge.eval("(navigator.language || '').split('-')[0]", true))
		if nav != "":
			code = nav
	return code


func _apply(raw: String, notify: bool) -> void:
	var next := _normalize(raw)
	if next == lang and notify:
		return
	var changed := next != lang
	lang = next
	if notify and changed:
		language_changed.emit(lang)


func _normalize(raw: String) -> String:
	var code := raw.to_lower().replace("_", "-")
	if code.find("-") >= 0:
		code = code.split("-")[0]
	if _pack.has(code):
		return code
	return "en"


func _script_group() -> String:
	if lang in ["zh", "ja", "ko"]:
		return "cjk"
	if lang == "ar":
		return "ar"
	if lang == "hi":
		return "hi"
	return "latin"
