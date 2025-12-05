# powerup.gd
extends Area2D

enum PowerupType { HARMONY, SLOWDOWN, MAGNET }
var type = PowerupType.HARMONY
# UPDATED: Duration increased to 15 seconds
var duration = 15.0 

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	type = PowerupType.values().pick_random()
	
	if animated_sprite:
		animated_sprite.play("default")
		update_visuals()
	
	area_entered.connect(_on_area_entered)

func _process(delta):
	var speed = 200.0
	var game_node = get_tree().get_first_node_in_group("game")
	if game_node and "current_fall_speed" in game_node:
		speed = game_node.current_fall_speed
	
	position.y -= speed * delta
	
	if position.y < -100:
		queue_free()

func update_visuals():
	if not animated_sprite: return
	
	# [cite_start]GDD Colors [cite: 467-478]:
	match type:
		PowerupType.HARMONY:
			# Blue (Invulnerability)
			animated_sprite.modulate = Color(0.2, 0.4, 1.0, 1.0) 
		PowerupType.SLOWDOWN:
			# Yellow (Slow Time)
			animated_sprite.modulate = Color(1.0, 1.0, 0.0, 1.0)
		PowerupType.MAGNET:
			# Purple (Magnet)
			animated_sprite.modulate = Color(0.8, 0.0, 0.8, 1.0)

func _on_area_entered(area):
	if area.name == "Player":
		apply_effect(area)
		queue_free()

func apply_effect(player):
	match type:
		PowerupType.HARMONY:
			if player.has_method("activate_harmony"):
				player.activate_harmony(duration)
				print("Powerup: Harmony (15s)")
				
		PowerupType.MAGNET:
			if player.has_method("activate_magnet"):
				player.activate_magnet(duration)
				print("Powerup: Magnet (15s)")
				
		PowerupType.SLOWDOWN:
			var game = get_tree().get_first_node_in_group("game")
			if game and game.has_method("activate_slowdown"):
				game.activate_slowdown(duration)
				print("Powerup: Slowdown (15s)")
