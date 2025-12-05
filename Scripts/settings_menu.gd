extends Control


var volume: float = 50.0
var mute: bool = false
var resolution: int = 4
var fullscreen: bool = false


func open():
	visible = true


func close():
	visible = false


func _on_volume_value_changed(value: float) -> void:
	$Panel/VolumeLabelInt.text = str(int(value)) + "%"
	var linear = value / 100.0
	var db = linear_to_db(linear)
	AudioServer.set_bus_volume_db(0, db)
	SettingsGlobal.volume = float(value)


func _on_mute_check_box_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0, toggled_on)
	SettingsGlobal.mute = toggled_on


func _on_resolution_item_selected(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_size(Vector2i(1920, 1080))
		1:
			DisplayServer.window_set_size(Vector2i(1600, 1024))
		2:
			DisplayServer.window_set_size(Vector2i(1440, 1080))
		3:
			DisplayServer.window_set_size(Vector2i(1366, 768))
		4:
			DisplayServer.window_set_size(Vector2i(1280, 720))
		5:
			DisplayServer.window_set_size(Vector2i(800, 600))
	SettingsGlobal.resolution = index


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if toggled_on
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	$Panel/Resolution.disabled = toggled_on
	SettingsGlobal.fullscreen = toggled_on


func _on_close_pressed() -> void:
	close()
