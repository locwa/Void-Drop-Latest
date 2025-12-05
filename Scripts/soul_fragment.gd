# soul_fragment.gd
extends Area2D

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	area_entered.connect(_on_area_entered)
	
	if animated_sprite:
		animated_sprite.play("fragment")
		animated_sprite.modulate = Color(1.0, 1.0, 0.6, 1.0) 

func _process(delta):
	var speed = 200.0
	var game_node = get_tree().get_first_node_in_group("game")
	
	if game_node and "current_fall_speed" in game_node:
		speed = game_node.current_fall_speed
	
	position.y -= speed * delta
	
	if position.y < -100:
		queue_free()

func _on_area_entered(area):
	# We expect the 'area' to be the Player
	if area.has_method("is_ethereal"):
		var can_collect = false
		
		# [cite_start]Condition 1: Player is in Ethereal Form (Standard Rule) [cite: 171]
		if area.is_ethereal():
			can_collect = true
			
		# Condition 2: Magnet is Active (Override Rule) [User Request]
		# This allows collection even if the player is SOLID.
		if "is_magnet_active" in area and area.is_magnet_active:
			can_collect = true
		
		if can_collect:
			collect_fragment(area)

func collect_fragment(player_node):
	var game_node = get_tree().get_first_node_in_group("game")
	if game_node:
		game_node.score += 10
		if "soul_meter" in game_node:
			game_node.soul_meter = min(game_node.soul_meter + 1, game_node.max_soul_fragments)
			game_node.update_ui()
	
	# Trigger Haptic Feedback on Player
	if player_node.has_method("trigger_pickup_feedback"):
		player_node.trigger_pickup_feedback()
	
	queue_free()
