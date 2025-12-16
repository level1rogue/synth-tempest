extends Node2D

@export var level_config: LevelConfig
const DEFAULT_CONFIG := preload("res://resources/level_1_triangle.tres")

@onready var starfield := $Starfield as GPUParticles2D
@onready var starfield_far := $StarfieldFar as GPUParticles2D
@onready var points_label := $PointsLabel as Label
@onready var health_label := $HealthLabel as Label

var player_points := 0
var player_health := 100

var inner_points: Array[Vector2] = []
var outer_points: Array[Vector2] = []
var lanes := []

var inner_line: Line2D
var outer_line: Line2D
var lanes_container: Node2D
var active_lane_fill: Polygon2D
var lane_spokes: Array = []
var active_spoke_index: int = -1
var projectiles_container: Node2D
var enemies_container: Node2D
var enemy_timer: Timer
var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

var screen_center := Vector2(0,0)
var screen_center_base := Vector2(0,0)
var screen_center_offset := Vector2(0,0)
var last_outer_scale: float = 0.0
var lane_line_scene: PackedScene = preload("res://scenes/lane_line.tscn")
var rng := RandomNumberGenerator.new()

func _ensure_lines():
	if inner_line == null:
		inner_line = Line2D.new()
		inner_line.width = 1.0
		var ring_col = level_config.ring_color if level_config else GlobalData.c_purple
		inner_line.default_color = ring_col
		inner_line.default_color.a = level_config.ring_alpha if level_config else 0.2
		add_child(inner_line)
	if outer_line == null:
		outer_line = Line2D.new()
		outer_line.width = 3.0
		outer_line.default_color = level_config.ring_color if level_config else GlobalData.c_purple
		add_child(outer_line)
	if lanes_container == null:
		lanes_container = Node2D.new()
		add_child(lanes_container)
	if active_lane_fill == null:
		active_lane_fill = Polygon2D.new()
		var hl_col = level_config.highlight_color if level_config else GlobalData.c_highlight
		active_lane_fill.color = Color(hl_col, 0.01)
		add_child(active_lane_fill)
	if projectiles_container == null:
		projectiles_container = Node2D.new()
		projectiles_container.name = "Projectiles"
		add_child(projectiles_container)
	# Ensure enemies container and timer
	if enemies_container == null:
		enemies_container = Node2D.new()
		enemies_container.name = "Enemies"
		add_child(enemies_container)
	if enemy_timer == null:
		enemy_timer = Timer.new()
		enemy_timer.wait_time = level_config.enemy_spawn_interval if level_config else 2.0
		enemy_timer.one_shot = false
		enemy_timer.autostart = true
		add_child(enemy_timer)
		enemy_timer.timeout.connect(_on_enemy_timer_timeout)



func get_lane_position(index: int, t: float) -> Vector2:
	var a = lanes[index]
	var b = lanes[(index + 1) % lanes.size()]
	print(", lanes: ", a, ", ", b, ", ", t)
	return a.lerp(b, t)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if level_config == null:
		# Fallback so the level always renders if not set in the scene
		if ResourceLoader.exists("res://resources/level_1_triangle.tres"):
			level_config = DEFAULT_CONFIG
		else:
			# Last resort: create an empty config with sane defaults
			level_config = LevelConfig.new()
	screen_center_base = get_viewport_rect().size * 0.5
	screen_center = screen_center_base + screen_center_offset
	
	starfield.position = screen_center
	if starfield_far:
		starfield_far.position.x = screen_center.x
		starfield_far.position.y = screen_center.y + 140
	rng.randomize()
	_ensure_lines()
	build_tube()

	get_viewport().size_changed.connect(recalc_on_resize) 	
	# Start enemy spawning after initial tube build
	if enemy_timer:
		enemy_timer.start()
		
	points_label.text = str(player_points).pad_zeros(5)
	health_label.text = str(player_health).pad_zeros(3)

func recalc_on_resize():
	screen_center_base = get_viewport_rect().size * 0.5
	screen_center = screen_center_base + screen_center_offset
	starfield.position = screen_center
	if starfield_far:
		starfield_far.position = screen_center
		#var pm_far := starfield_far.process_material as ParticleProcessMaterial
		#if pm_far:
			## Adjust box extents to current viewport to cover sides/top/bottom
			#pm_far.emission_box_extents = Vector3(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y * 0.5, 0)
	build_tube()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func build_tube():
	if not level_config:
		push_error("LevelConfig not assigned!")
		return
	var viewport_size = get_viewport_rect().size
	var min_dim = min(viewport_size.x, viewport_size.y)
	var inner_scale = min_dim * level_config.inner_ratio
	var outer_scale = min_dim * level_config.outer_ratio
	last_outer_scale = outer_scale

	# Offset inner ring on Y by a fraction of the outer radius for perspective illusion
	var inner_y_offset = outer_scale * level_config.inner_y_offset_ratio

	# 1) Get normalized, subdivided points for the chosen shape
	var base_points = load("res://scripts/shapes_config.gd").calc_shape_segments(level_config.shape_name, level_config.segments_per_edge)

	# 2) Scale and translate to center for both rings
	inner_points.clear()
	outer_points.clear()
	var center_inner = screen_center_base + screen_center_offset
	# Outer shifts in the opposite direction (parallax) scaled by outer_shift_ratio
	var center_outer = screen_center_base - screen_center_offset * clamp(level_config.outer_shift_ratio, 0.0, 1.0)
	for p in base_points:
			inner_points.append(center_inner + Vector2(0, inner_y_offset) + Vector2(p.x * inner_scale, p.y * inner_scale))
			outer_points.append(center_outer + Vector2(p.x * outer_scale, p.y * outer_scale))

	# 3) Draw rings
	inner_line.clear_points()
	outer_line.clear_points()
	for i in inner_points.size():
			inner_line.add_point(inner_points[i])
	for i in outer_points.size():
			outer_line.add_point(outer_points[i])
	# Close the loops
	if inner_points.size() > 0:
			inner_line.add_point(inner_points[0])
	if outer_points.size() > 0:
			outer_line.add_point(outer_points[0])

	# 4) Draw radial lanes/spokes as individual lines to avoid zig-zag
	if lanes_container:
		lane_spokes.clear()
		for child in lanes_container.get_children():
			child.queue_free()
		#lanes_container.clear()
		for i in inner_points.size():
			var spoke: Line2D = lane_line_scene.instantiate()
			if spoke == null:
				continue
			# Assign a unique Gradient resource per spoke and enable it
			var grad := Gradient.new()
			var ring_col = level_config.ring_color if level_config else GlobalData.c_purple
			grad.add_point(0.0, Color(ring_col, level_config.ring_alpha if level_config else 0.2))
			grad.add_point(1.0, ring_col)
			spoke.gradient = grad
			#spoke.use_gradient = true
			spoke.clear_points()
			spoke.add_point(inner_points[i])
			spoke.add_point(outer_points[i])
			spoke.width_curve.set_point_value(0, 1)
			spoke.width_curve.set_point_value(1, 2)
			lanes_container.add_child(spoke)
			lane_spokes.append(spoke)

		# Set default inactive modulate for all spokes
		for s in lane_spokes:
			var grad_default := Gradient.new()
			var ring_col = level_config.ring_color if level_config else GlobalData.c_purple
			grad_default.add_point(0.0, Color(ring_col, level_config.ring_alpha if level_config else 0.2))
			grad_default.add_point(1.0, ring_col)
			s.gradient = grad_default
			#s.use_gradient = true

	# Recompute active lane fill if needed
	if active_lane_fill:
		# Default to first lane until explicitly set
		_update_active_lane_fill(0)
		_update_active_spoke(0)

	# Optionally clear enemies on rebuild (keep existing by default)
	# If geometry changes, you may want to reposition enemies.

# Returns a point along the radial lane i from inner (t=0) to outer (t=1)
func get_radial_position(index: int, t: float) -> Vector2:
	var i = posmod(index, inner_points.size())
	return inner_points[i].lerp(outer_points[i], clamp(t, 0.0, 1.0))

# Number of lanes (spokes)
func get_lane_count() -> int:
	return inner_points.size()

# Direction of a lane (spoke), from inner to outer
func get_radial_direction(index: int) -> Vector2:
	var i = posmod(index, inner_points.size())
	if inner_points.is_empty():
		return Vector2.UP
	return (outer_points[i] - inner_points[i]).normalized()

# Active lane fill -----------------------------------------------------
func set_active_lane(index: int) -> void:
	if inner_points.is_empty():
		return
	_update_active_lane_fill(index)
	_update_active_spoke(index)

func update_perspective_focus(focus: Vector2) -> void:
	# Shift the effective center toward the focus point to enhance perspective
	var viewport_size = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	# Compute offset relative to base center, scaled by ratio
	var shift_ratio = level_config.perspective_shift_ratio if level_config else 0.08
	var raw_offset = (focus - screen_center_base) * shift_ratio
	# Optionally clamp to avoid extreme distortion
	var clamp_len = max(8.0, last_outer_scale * 0.25)
	if raw_offset.length() > clamp_len:
		raw_offset = raw_offset.normalized() * clamp_len
	screen_center_offset = raw_offset
	screen_center = screen_center_base + screen_center_offset
	build_tube()
	_update_starfield()
	# Retarget existing enemies to the new geometry so they stay on-lane
	if enemies_container:
		for e in enemies_container.get_children():
			if e.has_method("retarget_after_shift"):
				e.retarget_after_shift()
	# Retarget projectiles so they stay aligned after shift
	if projectiles_container:
		for p in projectiles_container.get_children():
			if p.has_method("retarget_after_shift"):
				p.retarget_after_shift()

func _update_starfield() -> void:
	if starfield == null:
		return
	# Position starfield at inner ring center (follow current center)
	starfield.global_position = screen_center
	var pm := starfield.process_material as ParticleProcessMaterial
	if pm == null:
		return
	# Derive a speed scale from how far the center is shifted; larger offset -> faster stars
	var s = clamp(screen_center_offset.length() / max(8.0, last_outer_scale * 0.25), 0.5, 3.0)
	pm.initial_velocity_min = 800.0 * s
	pm.initial_velocity_max = 1400.0 * s
	starfield.amount = int(300 * s)
	# Far layer fills the periphery with slower, denser stars
	#if starfield_far:
		#starfield_far.global_position = screen_center
		#var pm_far := starfield_far.process_material as ParticleProcessMaterial
		#if pm_far:
			#var sf = clamp(s * 0.6, 0.4, 2.0)
			#pm_far.initial_velocity_min = 200.0 * sf
			#pm_far.initial_velocity_max = 420.0 * sf
			#starfield_far.amount = int(700 * sf)

func _update_active_lane_fill(index: int) -> void:
	var count := inner_points.size()
	if count < 2:
		return
	var i := posmod(index, count)
	var j := (i + 1) % count
	# Quad representing the sector between lanes i and j
	var p0: Vector2 = inner_points[i]
	var p1: Vector2 = inner_points[j]
	var p2: Vector2 = outer_points[j]
	var p3: Vector2 = outer_points[i]
	active_lane_fill.polygon = PackedVector2Array([p0, p1, p2, p3])

func _update_active_spoke(index: int) -> void:
	if lane_spokes.is_empty():
		return
	var count := lane_spokes.size()
	var i := posmod(index, count)
	var j := (i + 1) % count
	for k in count:
		var s: Line2D = lane_spokes[k]
		if k == i or k == j:
			var grad_active := Gradient.new()
			var hl_col = level_config.highlight_color if level_config else GlobalData.c_highlight
			grad_active.add_point(0.0, Color(hl_col, level_config.ring_alpha if level_config else 0.2))
			grad_active.add_point(1.0, hl_col)
			s.gradient = grad_active
			#s.use_gradient = true
		else:
			var grad_inactive := Gradient.new()
			var ring_col = level_config.ring_color if level_config else GlobalData.c_purple
			grad_inactive.add_point(0.0, Color(ring_col, level_config.ring_alpha if level_config else 0.2))
			grad_inactive.add_point(1.0, ring_col)
			s.gradient = grad_inactive
			#s.use_gradient = true

# Spawning ------------------------------------------------------------
func _on_enemy_timer_timeout() -> void:
	if inner_points.is_empty():
		return
	var lane_count = get_lane_count()
	if lane_count <= 0:
		return
	var lane_index = rng.randi_range(0, lane_count - 1)
	var enemy = enemy_scene.instantiate()
	if enemy == null:
		return
	# Add to enemies container
	enemies_container.add_child(enemy)
	# Initialize enemy to move along chosen lane towards outer ring
	if enemy.has_method("initialize"):
		enemy.initialize(self, lane_index)

func add_to_points(amount: int):
	player_points += amount
	points_label.text = str(player_points).pad_zeros(5)

func player_take_damage(amount: int):
	player_health -= amount
	health_label.text = str(player_health).pad_zeros(3)
