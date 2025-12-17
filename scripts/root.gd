extends Node2D


const BASE_DAMAGE := 14.0
const BASE_FIRE_RATE := 1.0

var _level_index := 0
var _level_configs := [
	preload("res://resources/level_1_triangle.tres"),
	preload("res://resources/level_2_hexagon.tres"),
	preload("res://resources/level_3_octagon_hard.tres"),
]

var _reward_scene := preload("res://scenes/reward_screen.tscn")
var _start_scene := preload("res://scenes/start_screen.tscn")
var _level_scene := preload("res://scenes/level.tscn")
var _player_scene := preload("res://scenes/player.tscn")

var _level: Node2D
var _player: CharacterBody2D
@onready var _points_label: Label
@onready var _health_label: Label
@onready var _duration_label: Label
@onready var _damage_label: Label
@onready var _fire_rate_label: Label

var player_points := 0
var player_health := 100
var shot_speed_multiplier := 1.0  # Reduces fire interval
var shot_power_multiplier := 1.0  # Increases damage

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Background.position = get_viewport_rect().size /2
	$Background.scale = get_viewport_rect().size
	$ShaderBackground.position = get_viewport_rect().size /2
	$ShaderBackground.scale = get_viewport_rect().size
	$ShaderGrader.position = get_viewport_rect().size /2
	$ShaderGrader.scale = get_viewport_rect().size
	
	# Fix ShaderGrader modulate so it doesn't render black
	$ShaderGrader.modulate = Color(1, 1, 1, 1)
	$ShaderGrader.self_modulate = Color(1, 1, 1, 1)
	
	# Add BackBufferCopy before ShaderGrader so it captures rendered content
	var backbuffer = BackBufferCopy.new()
	backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(backbuffer)
	# Move it just before ShaderGrader
	move_child(backbuffer, $ShaderGrader.get_index())

	# Show start screen only; level/player not loaded yet
	_show_start_screen()

func _process(delta: float) -> void:
	pass

func _show_start_screen() -> void:
	var start = _start_scene.instantiate()
	add_child(start)
	var button = start.get_node("Container/VBox/StartButton") as Button
	if button:
		button.pressed.connect(func(): _on_start_game(start))

func _on_start_game(start_screen: Node) -> void:
	# Remove start screen
	start_screen.queue_free()

	# Instantiate level 
	_level = _level_scene.instantiate()
	add_child(_level)
	
	# Instantiate Player
	_player = _player_scene.instantiate()
	add_child(_player)
	
	# Move BackBufferCopy and ShaderGrader to render after all game content
	# This ensures the shader processes everything including dynamically added nodes
	for child in get_children():
		if child is BackBufferCopy:
			move_child(child, -1)
	if has_node("ShaderGrader"):
		move_child($ShaderGrader, -1)

	# Get label refs from the newly instantiated level
	_points_label = _level.get_node("PointsLabel") as Label
	_health_label = _level.get_node("HealthLabel") as Label
	_duration_label = _level.get_node("DurationLabel") as Label
	_damage_label = _level.get_node("DamageLabel") as Label
	_fire_rate_label = _level.get_node("FireRateLabel") as Label

	# Wire level won signal
	if _level.has_signal("level_won"):
		_level.level_won.connect(_on_level_won)

	# Start first level
	if _level_index >= 0 and _level_index < _level_configs.size():
		_level.apply_and_start(_level_configs[_level_index])

	# Initialize HUD text and layout
	_update_hud_text()
	_update_hud_layout()
	get_viewport().size_changed.connect(_on_resize)


func _on_level_won() -> void:
	# Show reward popup
	var reward = _reward_scene.instantiate()
	reward.position = get_viewport().size /2
	add_child(reward)
	reward.confirmed.connect(_on_reward_confirmed)

func _on_reward_confirmed(option_index: int) -> void:
	# Apply chosen reward
	match option_index:
		0:  # Shot Speed +
			shot_speed_multiplier += 0.2
			print("Shot Speed upgraded! Multiplier: ", shot_speed_multiplier)
		1:  # Shot Power +
			shot_power_multiplier += 0.4
			print("Shot Power upgraded! Multiplier: ", shot_power_multiplier)
	
	# Update player fire rate if active
	if _player and _player.has_method("update_fire_rate"):
		_player.update_fire_rate(shot_speed_multiplier)
	
	_update_hud_text()
	_start_next_level()

func _start_next_level() -> void:
	_level_index += 1
	if _level_index >= _level_configs.size():
		_level_index = 0  # loop for now; could show end screen instead
	if _level and _level_index < _level_configs.size():
		_level.apply_and_start(_level_configs[_level_index])
	# Refresh HUD for new level (duration text is handled by Level)
	_update_hud_text()
	_update_hud_layout()

func add_to_points(amount: int) -> void:
	player_points += amount
	_update_hud_text()

func player_take_damage(amount: int) -> void:
	player_health = max(0, player_health - amount)
	_update_hud_text()

func _update_hud_text() -> void:
	if _points_label:
		_points_label.text = str(player_points).pad_zeros(5)
	if _health_label:
		_health_label.text = str(player_health).pad_zeros(3)
	if _damage_label:
		var damage = snapped(get_base_damage() * shot_power_multiplier, 0.1)
		_damage_label.text = "DMG " + str(damage)
	if _fire_rate_label:
		var base_rate = get_base_fire_rate()
		var current_fire_interval = base_rate / shot_speed_multiplier if shot_speed_multiplier > 0 else base_rate
		var fire_rate = snapped(current_fire_interval, 0.01)
		_fire_rate_label.text = "FIRE RATE " + str(fire_rate)

func _update_hud_layout() -> void:
	if not (_points_label and _health_label and _duration_label and _damage_label and _fire_rate_label):
		return
	# Use logical viewport size to avoid HiDPI pixel scaling on macOS
	var vp := get_viewport().get_visible_rect().size
	print("vp: ", vp)
	var min_dim = min(vp.x, vp.y)
	# Margin and font scale adapt with window size
	var margin = max(12.0, min_dim * 0.02)
	var fs = clamp(int(min_dim * 0.40), 14, 96)
	var fs_small = clamp(int(min_dim * 0.25), 12, 64)  # Smaller font for stats
	# Apply font size overrides
	_points_label.label_settings.font_size = fs
	_health_label.label_settings.font_size = fs
	_duration_label.label_settings.font_size = fs
	_damage_label.label_settings.font_size = fs_small
	_fire_rate_label.label_settings.font_size = fs_small
	# Position: health and points upper-left, duration upper-right
	# Use simple estimates for widths based on font size
	# Estimate character width based on font size (rough heuristic)
	var est_char_w = fs * 0.55
	var health_width = est_char_w * 4.0
	# Gap scales with font size for consistent spacing
	var gap = max(12.0, est_char_w * 1.2)
	_health_label.position = Vector2(margin, margin)
	_points_label.position = Vector2(margin + health_width + gap, margin)
	# Duration on upper-right
	var duration_chars := 3.0
	var duration_width = est_char_w * duration_chars
	print("x: " , vp.x /2 - margin - duration_width, ", y: ", margin)
	print("dLabel: " , _duration_label.position)
	_duration_label.position = Vector2(vp.x/2 - duration_width, margin)
	print("dLabel: " , _duration_label.position)
	_duration_label.visible = true
	# Damage and Fire Rate on left side, stacked vertically
	# var right_x = vp.x - margin - (fs_small * 4.0)
	_damage_label.position = Vector2(margin, margin + fs + margin)
	_fire_rate_label.position = Vector2(margin, margin + fs + margin + fs_small + margin)

func get_shot_power_multiplier() -> float:
	return shot_power_multiplier

func get_base_damage() -> float:
	return BASE_DAMAGE

func get_base_fire_rate() -> float:
	return BASE_FIRE_RATE

func _on_resize() -> void:
	_update_hud_layout()
