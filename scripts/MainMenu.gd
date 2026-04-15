extends Control

@onready var main_buttons = $MainButtons
@onready var settings_panel = $SettingsPanel
@onready var master_slider = $SettingsPanel/VBoxContainer/MasterSlider
@onready var music_slider = $SettingsPanel/VBoxContainer/MusicSlider
@onready var sfx_slider = $SettingsPanel/VBoxContainer/SFXSlider
@onready var fullscreen_check = $SettingsPanel/VBoxContainer/FullscreenCheck
@onready var back_button = $SettingsPanel/VBoxContainer/BackButton

func _ready():
	settings_panel.visible = false
	_load_settings()

func _on_play_pressed():
	get_tree().change_scene_to_file("res://test_word.tscn")

func _on_settings_pressed():
	main_buttons.visible = false
	settings_panel.visible = true

func _on_quit_pressed():
	get_tree().quit()


func _on_back_pressed():
	settings_panel.visible = false
	main_buttons.visible = true
	_save_settings()

func _on_master_slider_value_changed(value: float):
	var bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))
	AudioServer.set_bus_mute(bus, value <= 0)

func _on_music_slider_value_changed(value: float):
	var bus = AudioServer.get_bus_index("Music")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))
		AudioServer.set_bus_mute(bus, value <= 0)

func _on_sfx_slider_value_changed(value: float):
	var bus = AudioServer.get_bus_index("SFX")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))
		AudioServer.set_bus_mute(bus, value <= 0)

func _on_fullscreen_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master", master_slider.value)
	config.set_value("audio", "music", music_slider.value)
	config.set_value("audio", "sfx", sfx_slider.value)
	config.set_value("video", "fullscreen", fullscreen_check.button_pressed)
	config.save("user://settings.cfg")

func _load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		master_slider.value = config.get_value("audio", "master", 80)
		music_slider.value = config.get_value("audio", "music", 80)
		sfx_slider.value = config.get_value("audio", "sfx", 80)
		fullscreen_check.button_pressed = config.get_value("video", "fullscreen", false)
		_on_master_slider_value_changed(master_slider.value)
		_on_music_slider_value_changed(music_slider.value)
		_on_sfx_slider_value_changed(sfx_slider.value)
		_on_fullscreen_toggled(fullscreen_check.button_pressed)
