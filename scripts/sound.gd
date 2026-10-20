extends Node

## Тихая музыка оранжереи и короткие звуки действий.
## На время рекламы и при потере фокуса общий канал глушит мост Яндекса.

var music: AudioStreamPlayer


func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.volume_db = -10.0
	add_child(music)
	var stream := _wav("res://audio/music.wav")
	if stream == null:
		return
	stream = stream.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.stream = stream
	music.play()


func play(name: String) -> void:
	var stream := _wav("res://audio/%s.wav" % name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _wav(path: String) -> AudioStreamWAV:
	if not ResourceLoader.exists(path):
		return null
	var stream = load(path)
	if stream is AudioStreamWAV:
		return stream
	return null
