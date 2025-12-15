extends CharacterBody2D


const SPEED = 30.0
const OFFSET_DISTANCE = 40.0  # Distance to offset player from the lane

@export var radial_t: float = 1.0  # 0 = inner ring, 1 = outer ring (along tube depth)

var lane_index := 0
var move_cooldown := 0.0
var is_clockwise := true
var level

func say_hi(name):
	print("Hi, ", name)

func _ready() -> void:
	level = $"../Level"
	# Determine polygon winding once using outer ring
	is_clockwise = _compute_clockwise(level.outer_points)
	update_rotation()
	update_position()
	print(position)

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
	var i_next = (lane_index + 1) % count
	var inner_mid = level.inner_points[lane_index].lerp(level.inner_points[i_next], 0.5)
	var outer_mid = level.outer_points[lane_index].lerp(level.outer_points[i_next], 0.5)
	var base_pos = inner_mid.lerp(outer_mid, clamp(radial_t, 0.0, 1.0))

	# Outward is along the tube from inner to outer mids
	var outward = (outer_mid - inner_mid).normalized()
	position = base_pos + outward * OFFSET_DISTANCE

func update_rotation() -> void:
	# Align with inward (outer->inner) direction at mid-edge to point toward center
	var count = level.get_lane_count()
	var i_next = (lane_index + 1) % count
	var inner_mid = level.inner_points[lane_index].lerp(level.inner_points[i_next], 0.5)
	var outer_mid = level.outer_points[lane_index].lerp(level.outer_points[i_next], 0.5)
	var inward = (inner_mid - outer_mid).normalized()
	# Add PI/2 because sprite points up by default, not right
	rotation = inward.angle() + PI / 2.0
	
func _physics_process(delta: float) -> void:
	move_cooldown -= delta
	
	if Input.is_action_pressed("move_right") and move_cooldown <= 0:
		lane_index = (lane_index + 1) % level.get_lane_count()
		update_rotation()
		update_position()
		move_cooldown = 10.0 / SPEED
		
	if Input.is_action_pressed("move_left") and move_cooldown <= 0:
		lane_index = (lane_index - 1 + level.get_lane_count()) % level.get_lane_count()
		update_rotation()
		update_position()
		move_cooldown = 10.0 / SPEED
