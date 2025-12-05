# Obstacle.gd
extends Area2D

# GDD: Speed must match the global fall speed
enum ObstacleForm { SOLID, ETHEREAL }
@export var obstacle_form = ObstacleForm.SOLID

# UPDATED: Horizontal Movement Support
var horizontal_speed = 0.0
var screen_width = 1280.0

@onready var sprite = $Sprite2D

func _ready():
	if get_viewport():
		screen_width = get_viewport_rect().size.x
		
	area_entered.connect(_on_area_entered)
	update_visual()

func _process(delta):
	var speed = 200.0 # Fallback default
	
	# Fetch the dynamic speed from the main game loop
	var game_node = get_tree().get_first_node_in_group("game")
	if game_node and "current_fall_speed" in game_node:
		speed = game_node.current_fall_speed
	
	# 1. Vertical Movement (Falling Up)
	position.y -= speed * delta
	
	# 2. UPDATED: Horizontal Movement (Moving Left/Right)
	if horizontal_speed != 0:
		position.x += horizontal_speed * delta
		
		# Bounce Logic: Reverse direction if hitting screen edges
		if position.x < 50: # Buffer for sprite width
			position.x = 50
			horizontal_speed *= -1
		elif position.x > screen_width - 50:
			position.x = screen_width - 50
			horizontal_speed *= -1
	
	# Remove when off-screen
	if position.y < -200:
		queue_free()

func update_visual():
	# Visual distinction
	if obstacle_form == ObstacleForm.SOLID:
		sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)  # Red for solid
	else:
		sprite.modulate = Color(0.6, 0.2, 1.0, 0.8)  # Violet for ethereal

func _on_area_entered(area):
	# Check if the area is the player
	if area.has_method("is_solid") and area.has_method("is_ethereal"):
		var should_collide = false
		
		if obstacle_form == ObstacleForm.SOLID and area.is_solid():
			should_collide = true
		elif obstacle_form == ObstacleForm.ETHEREAL and area.is_ethereal():
			should_collide = true
		
		if should_collide:
			area.die()

func set_form(form: ObstacleForm):
	obstacle_form = form
	if is_inside_tree():
		update_visual()
