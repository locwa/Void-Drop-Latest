extends Control


func open():
	visible = true


func close():
	visible = false


func _on_yes_pressed() -> void:
	get_tree().quit()


func _on_no_pressed() -> void:
	close()
