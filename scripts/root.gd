extends Node2D


var _level_index := 0
var _level_configs := [
	preload("res://resources/level_1_triangle.tres"),
	preload("res://resources/level_2_hexagon.tres"),
	preload("res://resources/level_3_octagon_hard.tres"),
]

var _reward_scene := preload("res://scenes/reward_screen.tscn")

@onready var _level := $Level
@onready var _points_label := $Level/PointsLabel as Label
@onready var _health_label := $Level/HealthLabel as Label
@onready var _duration_label := $Level/DurationLabel as Label

var player_points := 0
var player_health := 100

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Background.position = get_viewport_rect().size /2
	$Background.scale = get_viewport_rect().size
	$ShaderBackground.position = get_viewport_rect().size /2
	$ShaderBackground.scale = get_viewport_rect().size
	$ShaderGrader.position = get_viewport_rect().size /2
	$ShaderGrader.scale = get_viewport_rect().size

	if _level and _level.has_signal("level_won"):
		_level.level_won.connect(_on_level_won)

	# Ensure first level config is applied and started
	if _level:
		if _level_index >= 0 and _level_index < _level_configs.size():
			_level.apply_and_start(_level_configs[_level_index])

	# Initialize HUD text and layout
	_update_hud_text()
	_update_hud_layout()
	get_viewport().size_changed.connect(_on_resize)

func _process(delta: float) -> void:
	pass

func _on_level_won() -> void:
	# Show reward popup
	var reward = _reward_scene.instantiate()
	reward.position = get_viewport().size /2
	add_child(reward)
	reward.confirmed.connect(_on_reward_confirmed)

func _on_reward_confirmed(option_index: int) -> void:
	# TODO: apply chosen reward effects here (e.g., buff player/projectiles)
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

func _update_hud_layout() -> void:
	if not (_points_label and _health_label and _duration_label):
		return
	# Use logical viewport size to avoid HiDPI pixel scaling on macOS
	var vp := get_viewport().get_visible_rect().size
	print("vp: ", vp)
	var min_dim = min(vp.x, vp.y)
	# Margin and font scale adapt with window size
	var margin = max(12.0, min_dim * 0.02)
	var fs = clamp(int(min_dim * 0.40), 14, 96)
	# Apply font size overrides
	_points_label.label_settings.font_size = fs
	_health_label.label_settings.font_size = fs
	_duration_label.label_settings.font_size = fs
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

func _on_resize() -> void:
	_update_hud_layout()
