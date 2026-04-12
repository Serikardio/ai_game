extends Node

# --- Музыка (загружаем через load, чтобы не крашить если файл не импортирован) ---
var MUSIC_ARIA_MATH: AudioStream

# --- SFX ---
const SFX_WOOD_HIT = preload("res://assets/sounds/wood2.mp3")

var music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE = 8

func _ready():
	# Загружаем музыку
	MUSIC_ARIA_MATH = load("res://assets/sounds/aria_math.mp3")
	if MUSIC_ARIA_MATH == null:
		push_warning("AudioManager: не удалось загрузить aria_math.mp3 — откройте проект в редакторе для импорта")

	# Музыкальный плеер
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	add_child(music_player)

	# Пул для звуковых эффектов
	for i in SFX_POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)


func play_music(stream: AudioStream, volume_db: float = -10.0):
	if stream == null:
		push_warning("AudioManager: попытка воспроизвести null stream")
		return
	if music_player.stream == stream and music_player.playing:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.play()


func stop_music():
	music_player.stop()


func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_variance: float = 0.0):
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			if pitch_variance > 0:
				p.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
			else:
				p.pitch_scale = 1.0
			p.play()
			return
	# Все заняты — перезапускаем первый
	_sfx_pool[0].stream = stream
	_sfx_pool[0].volume_db = volume_db
	_sfx_pool[0].play()
