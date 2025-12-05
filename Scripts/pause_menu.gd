extends Control


func _ready() -> void:
	$PauseBlur.play("RESET")


func resume():
	get_tree().paused = false
	$PauseBlur.play_backwards("pause_menu_blur")
	
	
func pause():
	get_tree().paused = true
	$PauseBlur.play("pause_menu_blur")
	
func esc():
	if Input.is_action_just_pressed("ingame_esc") and !get_tree().paused:
		pause()
	if Input.is_action_just_pressed("ingame_esc") and get_tree().paused:
		resume()


func _on_resume_pressed() -> void:
	resume()


func _on_restart_pressed() -> void:
	resume()
	get_tree().reload_current_scene()


func _on_settings_pressed() -> void:
	pass # Replace with function body.


func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	
	
func _process(delta: float) -> void:
	esc()
