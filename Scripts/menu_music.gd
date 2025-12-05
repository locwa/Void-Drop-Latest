extends Node2D

@onready var player = $MusicPlayer

func play_music():
	if not player.playing:
		player.play()

func stop_music():
	if player.playing:
		player.stop()


func _on_music_player_finished() -> void:
	player.play()
