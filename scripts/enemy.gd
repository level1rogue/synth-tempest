extends Node2D

@export var far_speed: float = 60.0
@export var near_speed: float = 220.0
@export var far_scale: float = 0.35
@export var near_scale: float = 1.0
@export var perspective_ease: float = 1.6  # >1 accelerates near player

var level: Node
var lane_index: int = 0
var _dir: Vector2 = Vector2.ZERO
var _inner: Vector2 = Vector2.ZERO
var _outer: Vector2 = Vector2.ZERO
var _length: float = 1.0

func initialize(level_ref: Node, lane_idx: int) -> void:
	level = level_ref
	lane_index = lane_idx
	
	# Pull mid-edge geometry between consecutive lanes (like Player path)
	var count: int = level.get_lane_count()
	var i_next: int = (lane_index + 1) % count
	var inner_mid: Vector2 = level.inner_points[lane_index].lerp(level.inner_points[i_next], 0.5)
	var outer_mid: Vector2 = level.outer_points[lane_index].lerp(level.outer_points[i_next], 0.5)
	_inner = inner_mid
	_outer = outer_mid
	_dir = (_outer - _inner).normalized()
	_length = (_outer - _inner).length()

	# Start near the center, projected onto this mid-edge radial so we stay on-line
	var center: Vector2 = level.screen_center
	var t_line := (_dir.dot(center - _inner))
	var start_pos := _inner + _dir * t_line
	# Clamp to at least inner point so enemies always emerge outward
	if _dir.dot(start_pos - _inner) < 0.0:
		start_pos = _inner
	position = start_pos
	# Set initial scale based on initial t
	var traveled0 := _dir.dot(position - _inner)
	var t0 = clamp(traveled0 / _length, 0.0, 1.0)
	var ease_t0 := pow(t0, perspective_ease)
	var s0 = lerp(far_scale, near_scale, ease_t0)
	scale = Vector2.ONE * s0

func _process(delta: float) -> void:
	if level == null:
		return
	# Compute progress along lane before moving
	var traveled := _dir.dot(position - _inner)
	var t = clamp(traveled / _length, 0.0, 1.0)
	var ease_t := pow(t, perspective_ease)
	# Update visual scale
	var s = lerp(far_scale, near_scale, ease_t)
	scale = Vector2.ONE * s
	# Move with perspective speed
	var current_speed = lerp(far_speed, near_speed, ease_t)
	position += _dir * current_speed * delta
	# Despawn after we pass beyond the outer ring
	traveled = _dir.dot(position - _inner)
	if traveled >= _length + 4.0:
		queue_free()
