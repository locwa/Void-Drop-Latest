extends Node2D

# --- SCENE REFERENCES ---
@export var obstacle_scene: PackedScene
@export var soul_fragment_scene: PackedScene
@export var powerup_scene: PackedScene

# --- SPAWN SETTINGS ---
@export var spawn_interval = 1.2
@export var min_spawn_interval = 0.3

# --- VISUAL SETTINGS ---
@export var texture_height = 720.0 
var loop_overlap_px = 2.0 

# --- GLOBAL GAME STATE ---
var base_difficulty_speed = 400.0
var current_fall_speed = 400.0
var slowdown_timer = 0.0

var spawn_timer = 0.0
var game_running = true
var score = 0.0
var difficulty_timer = 0.0

# --- BOUNDARIES (MATCHING PLAYER.GD) ---
var spawn_min_x = 250.0 
var spawn_max_x = 1280.0 - 232.0 

# --- SPAWNING SYSTEM (Pattern Bag) ---
var pattern_bag = []
var recent_pattern = -1

# --- SOUL MECHANIC ---
var soul_meter = 0 
var max_soul_fragments = 15 
var cheat_buffer = "" 

# --- COLOR MEMORY ---
var was_invulnerable = false
var stored_player_color = Color(1, 1, 1)

# --- LEADERBOARD SYSTEM ---
var leaderboard = [] 
const MAX_ENTRIES = 5
const MAX_NAME_LENGTH = 5

# --- NODES ---
@onready var player = $Player
@onready var solid_background = $SolidBackground
@onready var ethereal_background = $EtherealBackground
@onready var borders = $Borders

var border_segments = []
var bg_fade_speed = 5.0 
var solid_bg_alpha = 1.0
var ethereal_bg_alpha = 0.0

# --- UI NODES ---
@onready var score_label = $UI/ScoreLabel
@onready var form_label = $UI/FormLabel
@onready var game_over_panel = $UI/GameOverPanel
@onready var game_over_label = $UI/GameOverPanel/GameOverLabel
@onready var final_score_label = $UI/GameOverPanel/FinalScoreLabel
@onready var instructions_label = $UI/GameOverPanel/InstructionsLabel
@onready var soul_bar = $UI/SoulMeterContainer/SoulMeter if has_node("UI/SoulMeterContainer/SoulMeter") else null
@onready var powerup_label = $UI/PowerupLabel if has_node("UI/PowerupLabel") else null
@onready var soul_label = $UI/SoulLabel if has_node("UI/SoulLabel") else null

func _ready():
	load_leaderboard()	
	add_to_group("game")
	
	process_priority = -1 
	
	if game_over_label:
		game_over_label.visible = false
		game_over_panel.visible = false
		final_score_label.visible = false
		instructions_label.visible = false
	
	refill_spawn_bag()
	
	if borders:
		border_segments.append(borders)
		for i in range(2):
			var clone = borders.duplicate()
			add_child(clone)
			border_segments.append(clone)
		
		for i in range(border_segments.size()):
			border_segments[i].position.y = i * (texture_height - loop_overlap_px)

	if solid_background: solid_background.visible = true
	if ethereal_background: ethereal_background.visible = true

func _process(delta):
	if not game_running:
		return
	
	if slowdown_timer > 0:
		slowdown_timer -= delta
		current_fall_speed = base_difficulty_speed * 0.5
	else:
		current_fall_speed = base_difficulty_speed
	
	var move_amount = current_fall_speed * delta
	
	for segment in border_segments:
		segment.position.y -= move_amount
	
	if border_segments.size() > 0:
		var top_segment = border_segments[0]
		if top_segment.position.y <= -(texture_height + 10):
			var bottom_segment = border_segments.back()
			top_segment.position.y = bottom_segment.position.y + texture_height - loop_overlap_px
			border_segments.push_back(border_segments.pop_front())

	update_background_visuals(delta)
	update_player_visuals() 
	
	score += (current_fall_speed * delta) / 10.0
	update_ui()
	
	difficulty_timer += delta
	if difficulty_timer >= 5.0:
		increase_difficulty()
		difficulty_timer = 0.0

	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_obstacles()
		spawn_timer = 0.0

# --- INPUT & CHEATS ---

func _input(event):
	if game_running:
		# 1. Text Cheat ("str")
		if event is InputEventKey and event.pressed and not event.echo:
			var key = OS.get_keycode_string(event.keycode).to_lower()
			if key.length() == 1:
				cheat_buffer += key
				if cheat_buffer.length() > 20: cheat_buffer = cheat_buffer.right(20)
				if cheat_buffer.ends_with("str"): 
					activate_cheat_max_souls()

		# 2. Directional Cheat (U U D D R R Phase)
		# FIX: Added checks to ensure event is InputEventKey before accessing 'keycode'
		if event.is_pressed() and not event.is_echo():
			var code = ""
			if event.is_action_pressed("ui_up"): code = "u"
			elif event.is_action_pressed("ui_down"): code = "d"
			
			# Check ACTION OR (Key Event AND Key R)
			elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.keycode == KEY_R): code = "r"
			
			# Check ACTION OR (Key Event AND Key SPACE)
			elif event.is_action_pressed("switch_phase") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select") or (event is InputEventKey and event.keycode == KEY_SPACE): code = "p"
			
			if code != "":
				cheat_buffer += code
				if cheat_buffer.length() > 20: cheat_buffer = cheat_buffer.right(20)
				if cheat_buffer.ends_with("uuddrrp"):
					activate_cheat_invincibility()

	if not game_running and event.is_action_pressed("restart"):
		restart_game()

func activate_cheat_max_souls():
	soul_meter = max_soul_fragments
	update_ui()
	print("CHEAT: MAX SOULS")

func activate_cheat_invincibility():
	if "invuln_timer" in player:
		player.invuln_timer = 30.0
		player.is_invulnerable = true
		print("CHEAT: 30s INVISIBILITY")
		if powerup_label: 
			powerup_label.modulate = Color(1, 1, 0)
			powerup_label.scale = Vector2(1.5, 1.5)
			var tween = create_tween()
			tween.tween_property(powerup_label, "scale", Vector2(1,1), 0.5)

# --- LEADERBOARD LOGIC ---

func load_leaderboard():
	var cfg = ConfigFile.new()
	var err = cfg.load("res://leaderboard.cfg")
	if err != OK:
		leaderboard = []
		return
	leaderboard = cfg.get_value("scores", "leaderboard", [])
	
func save_leaderboard():
	var cfg = ConfigFile.new()
	cfg.set_value("scores", "leaderboard", leaderboard)
	cfg.save("res://leaderboard.cfg")

func qualifies_for_leaderboard(new_score: int) -> bool:
	if leaderboard.size() < MAX_ENTRIES: return true
	return new_score > leaderboard[-1].score
	
func add_score_to_leaderboard(player_name: String, new_score: int):
	var entry = { "name": player_name.substr(0, MAX_NAME_LENGTH), "score": new_score }
	leaderboard.append(entry)
	leaderboard.sort_custom(func(a, b): return a.score > b.score)
	if leaderboard.size() > MAX_ENTRIES:
		leaderboard = leaderboard.slice(0, MAX_ENTRIES)
	save_leaderboard()

func _on_submit_name_button_pressed() -> void:
	var name = $UI/GameOverPanel/NameInput.text.strip_edges()
	if name == "": name = "???"
	add_score_to_leaderboard(name, int(score))
	show_leaderboard_ui()

# --- GAMEPLAY MECHANICS ---

func increase_difficulty():
	base_difficulty_speed += 30.0
	spawn_interval = max(min_spawn_interval, spawn_interval - 0.08)
	print("Difficulty Up! Speed: ", base_difficulty_speed)

func activate_slowdown(duration):
	slowdown_timer = duration

func attempt_soul_shatter():
	if soul_meter >= max_soul_fragments:
		var obstacles = get_tree().get_nodes_in_group("obstacles")
		var hazards_destroyed = 0
		for obs in obstacles:
			obs.queue_free()
			hazards_destroyed += 1
		
		score += hazards_destroyed * 25
		soul_meter = 0
		update_ui()
		Input.start_joy_vibration(0, 0.8, 1.0, 0.5)

# --- VISUALS & UI ---

func update_player_visuals():
	if player.is_invulnerable and not was_invulnerable:
		stored_player_color = player.modulate
		was_invulnerable = true
		
	if player.is_invulnerable:
		var pulse = (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		player.modulate = Color(1.0, 1.0, 0.0).lerp(Color(1.0, 1.0, 1.0), pulse * 0.6)
	
	elif was_invulnerable:
		player.modulate = stored_player_color
		was_invulnerable = false

func update_background_visuals(delta):
	var target_solid = 1.0 if player.is_solid() else 0.0
	var target_ethereal = 1.0 if not player.is_solid() else 0.0
	
	solid_bg_alpha = move_toward(solid_bg_alpha, target_solid, bg_fade_speed * delta)
	ethereal_bg_alpha = move_toward(ethereal_bg_alpha, target_ethereal, bg_fade_speed * delta)
	
	var darkness = clamp(1.0 - (score / 5000.0), 0.3, 1.0)
	
	if solid_background:
		solid_background.modulate = Color(darkness, darkness, darkness, solid_bg_alpha)
	if ethereal_background:
		ethereal_background.modulate = Color(darkness, darkness * 0.8, darkness, ethereal_bg_alpha)

func update_ui():
	if score_label: score_label.text = "Score: " + str(int(score))
	
	if soul_bar:
		soul_bar.value = soul_meter
		if soul_meter >= max_soul_fragments:
			var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5 
			soul_bar.modulate = Color(1.0, 1.0, 0.5 + (pulse * 0.5))
		else:
			soul_bar.modulate = Color(1, 1, 1)

	if soul_label: soul_label.text = "%d/%d" % [soul_meter, max_soul_fragments]

	if form_label:
		if player.is_solid():
			form_label.text = "SOLID"
			form_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		else:
			form_label.text = "ETHEREAL"
			form_label.modulate = Color(0.6, 0.2, 1.0, 0.8)
			
	if powerup_label:
		var active_texts = []
		if player.is_invulnerable:
			active_texts.append("SHIELD: %.1fs" % player.invuln_timer)
		if player.is_magnet_active:
			active_texts.append("MAGNET: %.1fs" % player.magnet_timer)
		if slowdown_timer > 0:
			active_texts.append("SLOW: %.1fs" % slowdown_timer)
			
		if active_texts.size() > 0:
			powerup_label.text = " | ".join(active_texts)
			if player.is_invulnerable: powerup_label.modulate = Color(0.2, 0.4, 1.0) 
			elif player.is_magnet_active: powerup_label.modulate = Color(0.8, 0.0, 0.8)
			else: powerup_label.modulate = Color(1.0, 1.0, 0.0)
			powerup_label.visible = true
		else:
			powerup_label.visible = false

# --- ADVANCED SPAWNING SYSTEM ---

func refill_spawn_bag():
	pattern_bag = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	pattern_bag.shuffle()

func get_next_pattern() -> int:
	if pattern_bag.is_empty(): refill_spawn_bag()
	var next = pattern_bag.pop_back()
	if next == recent_pattern and not pattern_bag.is_empty():
		pattern_bag.push_front(next)
		next = pattern_bag.pop_back()
	recent_pattern = next
	return next

func spawn_obstacles():
	var screen_size = get_viewport_rect().size
	spawn_min_x = 250.0 
	spawn_max_x = screen_size.x - 232.0 
	
	var pattern = get_next_pattern()
	var spawn_y_baseline = screen_size.y + 450.0 
	var occupied_x = [] 
	
	match pattern:
		0: spawn_single_obstacle(spawn_y_baseline, occupied_x)
		1: spawn_gap_pattern(spawn_y_baseline, occupied_x)
		2: spawn_three_obstacle_pattern(spawn_y_baseline, occupied_x)
		3: spawn_alternating_pattern(spawn_y_baseline, occupied_x)
		4: spawn_mixed_challenge(spawn_y_baseline, occupied_x)
		5: spawn_forced_gate(spawn_y_baseline, occupied_x)
		6: spawn_tunnel(spawn_y_baseline, occupied_x)
		7: spawn_stairs(spawn_y_baseline, occupied_x)
		8: spawn_slalom(spawn_y_baseline, occupied_x)
		9: spawn_double_gate(spawn_y_baseline, occupied_x)
		10: spawn_moving_hazard(spawn_y_baseline, occupied_x)
		
	try_spawn_extras(occupied_x, spawn_y_baseline)

func try_spawn_extras(occupied_x: Array, y_pos: float):
	var item_to_spawn = null
	var is_fragment = false
	
	if randf() < 0.3 and soul_fragment_scene:
		item_to_spawn = soul_fragment_scene
		is_fragment = true
	elif randf() < 0.15 and powerup_scene:
		item_to_spawn = powerup_scene
		is_fragment = false
	
	if item_to_spawn:
		var safe_x = find_safe_x(occupied_x)
		if safe_x != -1.0:
			var item = item_to_spawn.instantiate()
			var offset_y = -150 if is_fragment else -300
			item.position = Vector2(safe_x, y_pos + offset_y)
			add_child(item)
			if not is_fragment: print("!!! SPAWNED POWERUP !!!")

func find_safe_x(occupied_x: Array) -> float:
	var attempts = 10
	var safety_radius = 100.0 
	for i in range(attempts):
		var candidate = randf_range(spawn_min_x + 50, spawn_max_x - 50)
		var is_safe = true
		for ox in occupied_x:
			if abs(candidate - ox) < safety_radius:
				is_safe = false
				break
		if is_safe: return candidate
	return -1.0 

# --- PATTERN IMPLEMENTATIONS ---

func spawn_moving_hazard(y_pos: float, occupied_x: Array):
	var obstacle = obstacle_scene.instantiate()
	var start_left = randf() > 0.5
	var x_pos = spawn_min_x + 50.0 if start_left else spawn_max_x - 50.0
	obstacle.position = Vector2(x_pos, y_pos)
	if "horizontal_speed" in obstacle:
		var speed = randf_range(150.0, 300.0)
		obstacle.horizontal_speed = speed if start_left else -speed
	obstacle.set_form(obstacle.ObstacleForm.SOLID if randf() > 0.5 else obstacle.ObstacleForm.ETHEREAL)
	obstacle.add_to_group("obstacles")
	add_child(obstacle)
	occupied_x.append(x_pos)

func spawn_single_obstacle(y_pos: float, occupied_x: Array):
	var obstacle = obstacle_scene.instantiate()
	var x_pos = randf_range(spawn_min_x, spawn_max_x)
	obstacle.position = Vector2(x_pos, y_pos)
	obstacle.add_to_group("obstacles")
	if randf() > 0.5: obstacle.set_form(obstacle.ObstacleForm.SOLID)
	else: obstacle.set_form(obstacle.ObstacleForm.ETHEREAL)
	add_child(obstacle)
	occupied_x.append(x_pos)

func spawn_gap_pattern(y_pos: float, occupied_x: Array):
	var screen_width = spawn_max_x - spawn_min_x
	var local_center = randf_range(screen_width * 0.3, screen_width * 0.7)
	var gap_center = spawn_min_x + local_center
	var gap_size = 200.0
	var form = obstacle_scene.instantiate().ObstacleForm.SOLID if randf() > 0.5 else obstacle_scene.instantiate().ObstacleForm.ETHEREAL
	
	if gap_center - gap_size > spawn_min_x:
		var left = obstacle_scene.instantiate()
		var x = spawn_min_x + (gap_center - gap_size - spawn_min_x) / 2
		left.position = Vector2(x, y_pos)
		left.set_form(form)
		left.add_to_group("obstacles")
		add_child(left)
		occupied_x.append(x)
		
	if gap_center + gap_size < spawn_max_x:
		var right = obstacle_scene.instantiate()
		var x = gap_center + gap_size + (spawn_max_x - (gap_center + gap_size)) / 2
		right.position = Vector2(x, y_pos)
		right.set_form(form)
		right.add_to_group("obstacles")
		add_child(right)
		occupied_x.append(x)

func spawn_three_obstacle_pattern(y_pos: float, occupied_x: Array):
	var form = obstacle_scene.instantiate().ObstacleForm.SOLID if randf() > 0.5 else obstacle_scene.instantiate().ObstacleForm.ETHEREAL
	var screen_width = spawn_max_x - spawn_min_x
	var positions = [
		spawn_min_x + (screen_width * 0.15),
		spawn_min_x + (screen_width * 0.5),
		spawn_min_x + (screen_width * 0.85)
	]
	for p in positions:
		var obs = obstacle_scene.instantiate()
		obs.position = Vector2(p, y_pos)
		obs.set_form(form)
		obs.add_to_group("obstacles")
		add_child(obs)
		occupied_x.append(p)

func spawn_alternating_pattern(y_pos: float, occupied_x: Array):
	var screen_width = spawn_max_x - spawn_min_x
	var count = 4
	var spacing = screen_width / (count + 1)
	for i in range(count):
		var obs = obstacle_scene.instantiate()
		var x = spawn_min_x + (spacing * (i + 1))
		obs.position = Vector2(x, y_pos)
		if i % 2 == 0: obs.set_form(obs.ObstacleForm.SOLID)
		else: obs.set_form(obs.ObstacleForm.ETHEREAL)
		obs.add_to_group("obstacles")
		add_child(obs)
		occupied_x.append(x)

func spawn_mixed_challenge(y_pos: float, occupied_x: Array):
	var screen_width = spawn_max_x - spawn_min_x
	var left = obstacle_scene.instantiate()
	var lx = spawn_min_x + (screen_width * 0.25)
	left.position = Vector2(lx, y_pos)
	left.set_form(obstacle_scene.instantiate().ObstacleForm.SOLID)
	left.add_to_group("obstacles")
	add_child(left)
	occupied_x.append(lx)
	
	var right = obstacle_scene.instantiate()
	var rx = spawn_min_x + (screen_width * 0.75)
	right.position = Vector2(rx, y_pos)
	right.set_form(obstacle_scene.instantiate().ObstacleForm.ETHEREAL)
	right.add_to_group("obstacles")
	add_child(right)
	occupied_x.append(rx)

func spawn_forced_gate(y_pos: float, occupied_x: Array):
	var screen_width = spawn_max_x - spawn_min_x
	var count = 5
	var spacing = screen_width / (count + 1)
	var row_form = obstacle_scene.instantiate().ObstacleForm.SOLID if randf() > 0.5 else obstacle_scene.instantiate().ObstacleForm.ETHEREAL
	for i in range(count):
		var obs = obstacle_scene.instantiate()
		var x = spawn_min_x + (spacing * (i + 1))
		obs.position = Vector2(x, y_pos)
		obs.set_form(row_form)
		obs.add_to_group("obstacles")
		add_child(obs)
		occupied_x.append(x)

func spawn_tunnel(y_pos: float, occupied_x: Array):
	var left = obstacle_scene.instantiate()
	var lx = spawn_min_x + 50
	left.position = Vector2(lx, y_pos)
	left.set_form(obstacle_scene.instantiate().ObstacleForm.SOLID)
	left.add_to_group("obstacles")
	add_child(left)
	occupied_x.append(lx)
	
	var right = obstacle_scene.instantiate()
	var rx = spawn_max_x - 50
	right.position = Vector2(rx, y_pos)
	right.set_form(obstacle_scene.instantiate().ObstacleForm.SOLID)
	right.add_to_group("obstacles")
	add_child(right)
	occupied_x.append(rx)

func spawn_stairs(y_pos: float, occupied_x: Array):
	var screen_width = spawn_max_x - spawn_min_x
	var steps = 4
	var start_x = spawn_min_x + (screen_width * 0.2)
	var step_x = (screen_width * 0.6) / steps
	var step_y = 100.0 
	var reverse = randf() > 0.5
	for i in range(steps):
		var obs = obstacle_scene.instantiate()
		var offset = (i * step_x)
		var x = start_x + offset if not reverse else (spawn_max_x - (screen_width * 0.2)) - offset
		var y = y_pos + (i * step_y)
		obs.position = Vector2(x, y)
		if i % 2 == 0: obs.set_form(obs.ObstacleForm.SOLID)
		else: obs.set_form(obs.ObstacleForm.ETHEREAL)
		obs.add_to_group("obstacles")
		add_child(obs)
		occupied_x.append(x)

func spawn_slalom(y_pos: float, occupied_x: Array):
	var screen_width = spawn_max_x - spawn_min_x
	var points = [0.25, 0.75, 0.25, 0.75]
	var step_y = 150.0
	for i in range(points.size()):
		var obs = obstacle_scene.instantiate()
		var x = spawn_min_x + (screen_width * points[i])
		obs.position = Vector2(x, y_pos + (i * step_y))
		if randf() > 0.5: obs.set_form(obs.ObstacleForm.SOLID)
		else: obs.set_form(obs.ObstacleForm.ETHEREAL)
		obs.add_to_group("obstacles")
		add_child(obs)
		occupied_x.append(x)

func spawn_double_gate(y_pos: float, occupied_x: Array):
	var screen_width = spawn_max_x - spawn_min_x
	var count = 6
	var spacing = screen_width / count
	var gaps = [1, 4]
	for i in range(count):
		if i in gaps: continue
		var obs = obstacle_scene.instantiate()
		var x = spawn_min_x + (spacing * (i + 0.5))
		obs.position = Vector2(x, y_pos)
		obs.set_form(obs.ObstacleForm.SOLID) 
		obs.add_to_group("obstacles")
		add_child(obs)
		occupied_x.append(x)

func game_over():
	game_running = false
	var final_score = int(score)
	
	if game_over_label:
		game_over_label.text = "GAME OVER"
		final_score_label.text = "Final Score: " +  str(int(score))
		game_over_label.visible = true
		game_over_panel.visible = true
		final_score_label.visible = true
		instructions_label.visible = false
		
	if qualifies_for_leaderboard(final_score):
		show_name_input(final_score)
	else:
		show_leaderboard_ui()	

func restart_game():
	get_tree().reload_current_scene()

func show_name_input(final_score: int):
	$UI/GameOverPanel/NameInput.text = ""
	$UI/GameOverPanel/NameInput.visible = true
	$UI/GameOverPanel/SubmitNameButton.visible = true
	$UI/GameOverPanel/LeaderboardBox.visible = false
	$UI/GameOverPanel/LeaderboardLabel.visible = false
	$UI/GameOverPanel/NamePromptLabel.text = "NEW HIGH SCORE! ENTER NAME:"
	$UI/GameOverPanel/NamePromptLabel.visible = true
	
func show_leaderboard_ui():
	$UI/GameOverPanel/NameInput.visible = false
	$UI/GameOverPanel/SubmitNameButton.visible = false
	$UI/GameOverPanel/NamePromptLabel.visible = false
	$UI/GameOverPanel/LeaderboardLabel.visible = true
	var box = $UI/GameOverPanel/LeaderboardBox
	var boxPanel = $UI/GameOverPanel/LeaderboardBoxPanel
	boxPanel.visible = true
	box.visible = true
	for i in range(MAX_ENTRIES):
		var row = box.get_child(i)
		if i < leaderboard.size():
			row.text = "%d. %s - %d" % [i+1, leaderboard[i].name, leaderboard[i].score]
		else:
			row.text = "%d. ---" % [i+1]
	instructions_label.visible = true 

func _on_audio_stream_player_2d_finished() -> void:
	$AudioStreamPlayer2D.play()
