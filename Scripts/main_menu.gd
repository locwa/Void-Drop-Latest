extends Control

@onready var settings_menu: Control = $SettingsMenu
@onready var quit_confirm: Control = $MenuConfirmation


func _ready() -> void:
	MenuMusic.play_music()
	_load_settings_ui()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/gameplay.tscn")
	MenuMusic.stop_music()
	pass

func _on_settings_pressed() -> void:
	settings_menu.open()

func _load_settings_ui():
	$SettingsMenu/Panel/VolumeSlider.value = SettingsGlobal.volume
	$SettingsMenu/Panel/Mute.button_pressed = SettingsGlobal.mute
	$SettingsMenu/Panel/Resolution.select(SettingsGlobal.resolution)
	$SettingsMenu/Panel/Fullscreen.button_pressed = SettingsGlobal.fullscreen

func _on_exit_pressed() -> void:
	quit_confirm.open()


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Credits.tscn")
