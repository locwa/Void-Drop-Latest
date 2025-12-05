extends Control

@onready var container = $viewport/CreditsContainer
@onready var fade_rect = $CanvasLayer/Fade

func _ready():
	scroll_credits()


func scroll_credits():
	var screen_height = get_viewport_rect().size.y
	var start_y = screen_height
	var end_y = -container.size.y

	container.position.y = start_y

	var tween = create_tween()
	tween.tween_property(
		container,
		"position:y",
		end_y,
		5.0  # scroll duration
	)

	tween.finished.connect(_on_credits_finished)


func _on_credits_finished():
	fade_and_exit()


func fade_and_exit():
	var tween = create_tween()
	tween.tween_property(
		fade_rect,
		"color:a",    # fade alpha
		1.0,             # fully black
		1.0              # duration
	)

	tween.finished.connect(_go_to_menu)


func _go_to_menu():
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _on_back_pressed():
	fade_and_exit()     # back button now also fades
