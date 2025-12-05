extends Area2D

# --- MOVEMENT AND PHYSICS ---
var velocity_x := 0.0
var velocity_y := 0.0

# Base stats
var base_move_speed := 350.0 
var dive_speed := 500.0      
var acceleration := 3500.0   
var friction := 4000.0       
var return_acceleration := 20000.0 

# --- BOUNDARIES (ASYMMETRICAL) ---
var boundary_left := 250.0 
var boundary_right := 232.0
var neutral_y_pos := 120.0 

# --- PHASE SHIFT ---
enum Form { SOLID, ETHEREAL }
var current_form := Form.SOLID
var form_switch_cooldown := 0.0
var form_switch_delay := 0.1

# --- POWERUPS ---
var is_invulnerable := false
var invuln_timer := 0.0
var is_magnet_active := false
var magnet_timer := 0.0
var magnet_radius := 600.0 

# --- ANTI-CAMPING ---
var idle_timer := 0.0
var max_idle_time := 10.0 

# --- SCREEN LIMITS ---
var screen_size := Vector2(1280, 720)
var game_over = false

# --- VISUALS ---
var color_transition_speed = 10.0

# --- NODES ---
@onready var animated_sprite = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var static_sprite = $Sprite2D if has_node("Sprite2D") else null
var game_node_ref = null # Caches the game node for performance

func _ready():
	if get_viewport():
		screen_size = get_viewport_rect().size
	set_process(true)
	modulate = get_target_color()
	position.y = neutral_y_pos
	
	# Attempt to find game node early
	game_node_ref = get_tree().get_first_node_in_group("game")

func _process(delta):
	if game_over:
		return
	
	# --- FETCH GAME NODE (Safety Check) ---
	if not is_instance_valid(game_node_ref):
		game_node_ref = get_tree().get_first_node_in_group("game")

	# --- DYNAMIC SPEED SCALING ---
	var current_game_speed = 0.0
	if is_instance_valid(game_node_ref) and "current_fall_speed" in game_node_ref:
		current_game_speed = game_node_ref.current_fall_speed
	
	var final_move_speed = base_move_speed + (current_game_speed * 0.8)
	var final_vert_speed = dive_speed + (current_game_speed * 0.5)

	# --- INPUT ---
	var input_axis_x = Input.get_axis("ui_left", "ui_right")
	var input_down = Input.is_action_pressed("ui_down")
	
	# --- ANTI-CAMPING ---
	if is_zero_approx(input_axis_x):
		idle_timer += delta
		if idle_timer > 7.0:
			position.x += randf_range(-2, 2)
			var pulse = (sin(Time.get_ticks_msec() * 0.02) + 1.0) * 0.5
			if pulse > 0.9: Input.start_joy_vibration(0, 0.2, 0.0, 0.1)
		if idle_timer >= max_idle_time:
			print("Consumed by the Void (Anti-Camp)")
			die()
	else:
		idle_timer = 0.0
	
	# --- 1. HORIZONTAL PHYSICS ---
	var target_vx = input_axis_x * final_move_speed
	if input_axis_x < 0: update_direction(true)
	elif input_axis_x > 0: update_direction(false)
	
	if target_vx != 0:
		velocity_x = move_toward(velocity_x, target_vx, acceleration * delta)
	else:
		velocity_x = move_toward(velocity_x, 0, friction * delta)
	
	# --- 2. VERTICAL PHYSICS ---
	var target_vy = 0.0
	var current_accel = acceleration
	
	if input_down:
		target_vy = final_vert_speed
		velocity_y = move_toward(velocity_y, target_vy, acceleration * delta)
	else:
		var dist_to_neutral = position.y - neutral_y_pos
		
		if dist_to_neutral > 10.0: 
			if velocity_y > 0: 
				velocity_y = -final_vert_speed
			
			if abs(velocity_y * delta) > dist_to_neutral:
				position.y = neutral_y_pos
				velocity_y = 0.0
			else:
				target_vy = -final_vert_speed
				current_accel = return_acceleration 
				velocity_y = move_toward(velocity_y, target_vy, current_accel * delta)
				
		elif dist_to_neutral < -10.0:
			target_vy = final_vert_speed
			velocity_y = move_toward(velocity_y, target_vy, acceleration * delta)
			
		else:
			velocity_y = 0.0 
			position.y = move_toward(position.y, neutral_y_pos, 400 * delta)
	
	# --- APPLY POSITION ---
	position.x += velocity_x * delta
	position.y += velocity_y * delta
	
	# --- BOUNDARIES ---
	position.x = clamp(position.x, boundary_left, screen_size.x - boundary_right)
	position.y = clamp(position.y, 50, screen_size.y - 50)
	
	# --- ACTIONS ---
	if Input.is_action_just_pressed("phase_shift"): 
		if form_switch_cooldown <= 0:
			toggle_phase()
			form_switch_cooldown = form_switch_delay
	
	# --- SOUL SHATTER LOGIC (FIXED) ---
	if Input.is_action_just_pressed("soul_shatter"): 
		# Debug: helps verify if Input Map is correct
		print("DEBUG: Soul Shatter Input Pressed")
		
		var can_shatter = false
		
		if is_instance_valid(game_node_ref):
			# Check meter on the game node safely
			if "soul_meter" in game_node_ref and "max_soul_fragments" in game_node_ref:
				print("DEBUG: Meter: ", game_node_ref.soul_meter, "/", game_node_ref.max_soul_fragments)
				if game_node_ref.soul_meter >= game_node_ref.max_soul_fragments:
					can_shatter = true
			else:
				# Fallback if variables are missing
				can_shatter = true
		else:
			# Fallback if node not found (just try to call it)
			can_shatter = true
			
		if can_shatter:
			flash_screen_white()
			get_tree().call_group("game", "attempt_soul_shatter")
			print("DEBUG: Shatter Signal Sent!")
		else:
			print("DEBUG: Not enough souls to shatter.")

	form_switch_cooldown -= delta
	
	# --- POWERUP TIMERS ---
	if is_invulnerable:
		invuln_timer -= delta
		if invuln_timer <= 0: is_invulnerable = false
			
	if is_magnet_active:
		magnet_timer -= delta
		pull_fragments(delta)
		if magnet_timer <= 0: is_magnet_active = false

	# --- VISUAL UPDATES ---
	update_visuals(delta)

# --- HELPER: DIRECTION ---
func update_direction(is_left: bool):
	if animated_sprite: animated_sprite.flip_h = is_left
	if static_sprite: static_sprite.flip_h = is_left

# --- HELPER: SCREEN FLASH ---
func flash_screen_white():
	var canvas = CanvasLayer.new()
	canvas.layer = 100 
	get_parent().add_child(canvas)
	
	var flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 1) 
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(flash_rect)
	
	var tween = create_tween()
	tween.tween_property(flash_rect, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(canvas.queue_free)

# --- MAGNET LOGIC ---
func pull_fragments(delta):
	var areas = get_parent().get_children()
	for node in areas:
		if node is Area2D and node.has_method("collect_fragment") and node != self:
			var dist = global_position.distance_to(node.global_position)
			if dist < magnet_radius:
				var direction = (global_position - node.global_position).normalized()
				node.global_position += direction * 1200.0 * delta

# --- POWERUP ACTIVATION ---
func activate_harmony(duration):
	is_invulnerable = true
	invuln_timer = duration
	vibrate_small()

func activate_magnet(duration):
	is_magnet_active = true
	magnet_timer = duration
	vibrate_small()

# --- VIBRATION ---
func vibrate_small():
	Input.start_joy_vibration(0, 0.4, 0.0, 0.2)

func vibrate_heavy():
	Input.start_joy_vibration(0, 0.5, 1.0, 0.5)

func trigger_pickup_feedback():
	vibrate_small()

# --- PHASE SHIFT LOGIC ---
func toggle_phase():
	if current_form == Form.SOLID:
		current_form = Form.ETHEREAL
	else:
		current_form = Form.SOLID
	
	if animated_sprite:
		if current_form == Form.SOLID:
			animated_sprite.play("solid")
		else:
			animated_sprite.play("ethereal")

# --- VISUALS ---
func get_target_color() -> Color:
	# Priority 0: Anti-Camp Warning
	if idle_timer > 7.0:
		var flash = sin(Time.get_ticks_msec() * 0.02)
		return Color(0.2, 0.2, 0.2, 1.0) if flash > 0 else Color(0.5, 0.0, 0.0, 1.0)

	# 1. Base Form Color
	var base_color = Color(1.0, 0.2, 0.2, 1.0) # Solid Red
	if current_form == Form.ETHEREAL:
		base_color = Color(0.6, 0.2, 1.0, 0.8) # Ethereal Violet

	# 2. Collect Active Powerup Colors
	var active_colors = []
	if is_invulnerable: active_colors.append(Color(0.2, 0.4, 1.0, 1.0)) # Blue
	if is_magnet_active: active_colors.append(Color(1.0, 0.5, 1.0, 1.0)) # Purple

	# 3. Determine Pulse Target
	var pulse_target = base_color
	
	if active_colors.size() == 1:
		pulse_target = active_colors[0]
	elif active_colors.size() > 1:
		var cycle_speed = 0.005
		var time = Time.get_ticks_msec() * cycle_speed
		var index = int(time) % active_colors.size()
		var next_index = (index + 1) % active_colors.size()
		var t = time - int(time)
		pulse_target = active_colors[index].lerp(active_colors[next_index], t)

	# 4. Apply Pulse Wave against Base Color
	if pulse_target != base_color:
		var wave = (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		return base_color.lerp(pulse_target, wave)

	return base_color

func update_visuals(delta):
	var target = get_target_color()
	modulate =  modulate.lerp(target, color_transition_speed * delta)

func is_solid() -> bool: return current_form == Form.SOLID
func is_ethereal() -> bool: return current_form == Form.ETHEREAL

func die():
	if is_invulnerable: return 
	if not game_over:
		game_over = true
		modulate = Color(1, 0, 0, 1)
		vibrate_heavy()
		get_tree().call_group("game", "game_over")
