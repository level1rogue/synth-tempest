extends CharacterBody2D


const SPEED = 100.0
const OFFSET_DISTANCE = 40.0  # Distance to offset player from the lane

@export var radial_t: float = 1.0  # 0 = inner ring, 1 = outer ring (along tube depth)
@export var perspective_amount: float = 0.3  # How much to skew the polygon (0 = none, 1 = extreme)

var lane_index := 0
var move_cooldown := 0.0
var is_clockwise := true
var level
var polygon_2d: Polygon2D
var original_polygon_points: PackedVector2Array = []
var shoot_timer: Timer
var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

func say_hi(name):
	print("Hi, ", name)

func _ready() -> void:
	level = $"../Level"
	polygon_2d = $Polygon2D
	original_polygon_points = polygon_2d.polygon.duplicate()
	# Wait for level to be initialized
	if level.get_lane_count() == 0:
		push_warning("Level not initialized yet, waiting...")
		return
	# Determine polygon winding once using outer ring
	is_clockwise = _compute_clockwise(level.outer_points)
	update_rotation()
	update_position()
	#update_polygon_perspective()
	print(position)

	# Auto-fire timer (1s)
	shoot_timer = Timer.new()
	shoot_timer.wait_time = 0.8
	shoot_timer.one_shot = false
	shoot_timer.autostart = true
	add_child(shoot_timer)
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)

func _compute_clockwise(points: Array) -> bool:
	var area := 0.0
	for i in points.size():
		var p = points[i]
		var q = points[(i + 1) % points.size()]
		area += (q.x - p.x) * (q.y + p.y)
	# area < 0 means clockwise with this variant
	return area < 0.0

func update_position() -> void:
	# Use midpoint between consecutive points on each ring, then move along tube depth
	var count = level.get_lane_count()
	if count == 0:
		return
	var i_next = (lane_index + 1) % count
	var inner_mid = level.inner_points[lane_index].lerp(level.inner_points[i_next], 0.5)
	var outer_mid = level.outer_points[lane_index].lerp(level.outer_points[i_next], 0.5)
	var base_pos = inner_mid.lerp(outer_mid, clamp(radial_t, 0.0, 1.0))

	# Outward is along the tube from inner to outer mids
	var outward = (outer_mid - inner_mid).normalized()
	position = base_pos + outward * OFFSET_DISTANCE

	# Shift perspective center slightly toward the player to enhance depth
	if level.has_method("update_perspective_focus"):
		level.update_perspective_focus(position)

func update_rotation() -> void:
	# Align with inward (outer->inner) direction at mid-edge to point toward center
	var count = level.get_lane_count()
	if count == 0:
		return
	var i_next = (lane_index + 1) % count
	var inner_mid = level.inner_points[lane_index].lerp(level.inner_points[i_next], 0.5)
	var outer_mid = level.outer_points[lane_index].lerp(level.outer_points[i_next], 0.5)
	var inward = (inner_mid - outer_mid).normalized()
	# Add PI/2 because sprite points up by default, not right
	rotation = inward.angle() + PI / 2.0

func update_polygon_perspective() -> void:
	# Apply perspective skew to align the back parallel to the polygon edge
	var transformed_points: PackedVector2Array = []
	
	# Get the direction of the polygon edge the ship is on
	var count = level.get_lane_count()
	if count == 0:
		return
	var i_next = (lane_index + 1) % count
	var inner_mid = level.inner_points[lane_index].lerp(level.inner_points[i_next], 0.5)
	var outer_mid = level.outer_points[lane_index].lerp(level.outer_points[i_next], 0.5)
	
	# Edge direction - this is what the ship's base should align with
	var edge_direction = (level.inner_points[i_next] - level.inner_points[lane_index]).normalized()
	
	# Calculate the rotation angle needed to align the local X axis with the edge direction
	var local_right = Vector2(1, 0)  # Default right direction
	var angle_to_edge = local_right.angle_to(edge_direction)
	var shear_amount = tan(angle_to_edge) * perspective_amount
	
	for i in original_polygon_points.size():
		var point = original_polygon_points[i]
		
		if i == 1:  # The nose point - keep it as is
			transformed_points.append(point)
		else:  # Base points (0 and 2) - apply shear to align with edge
			# Shear to tilt the base parallel to the polygon edge
			var sheared = Vector2(point.x, point.y + point.x * shear_amount)
			transformed_points.append(sheared)
	
	polygon_2d.polygon = transformed_points
	
func _physics_process(delta: float) -> void:
	move_cooldown -= delta
	
	if Input.is_action_pressed("move_right") and move_cooldown <= 0:
		lane_index = (lane_index + 1) % level.get_lane_count()
		update_rotation()
		update_position()
		#update_polygon_perspective()
		if level.has_method("set_active_lane"):
			level.set_active_lane(lane_index)
		move_cooldown = 10.0 / SPEED
		
	if Input.is_action_pressed("move_left") and move_cooldown <= 0:
		lane_index = (lane_index - 1 + level.get_lane_count()) % level.get_lane_count()
		update_rotation()
		update_position()
		#update_polygon_perspective()
		if level.has_method("set_active_lane"):
			level.set_active_lane(lane_index)
		move_cooldown = 10.0 / SPEED

func _on_shoot_timer_timeout() -> void:
	if level == null:
		return
	var count = level.get_lane_count()
	if count == 0:
		return
	# Compute inward direction along the current mid-edge (towards center)
	var i_next = (lane_index + 1) % count
	var inner_mid = level.inner_points[lane_index].lerp(level.inner_points[i_next], 0.5)
	var outer_mid = level.outer_points[lane_index].lerp(level.outer_points[i_next], 0.5)
	var inward = (inner_mid - outer_mid).normalized()
	# Spawn projectile at player position, moving inward
	var proj = projectile_scene.instantiate()
	if proj == null:
		return
	# Add to projectiles container if available, otherwise to level
	if level.has_node("Projectiles"):
		level.get_node("Projectiles").add_child(proj)
	else:
		level.add_child(proj)
	if proj.has_method("initialize"):
		proj.initialize(level, lane_index, position, inner_mid)
