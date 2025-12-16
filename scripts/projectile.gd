extends Node2D

@export var near_speed: float = 420.0   # speed near the player (at start)
@export var far_speed: float = 140.0    # speed near the center (far away)
@export var near_scale: float = 1.0     # scale at player
@export var far_scale: float = 0.25     # scale at center
@export var perspective_ease: float = 1.6
@export var extra_travel_margin: float = 4.0
@export var damage: float = 10.0

var level: Node = null
var lane_index: int = 0
var _dir: Vector2 = Vector2.ZERO
var _start: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _length: float = 0.0
var _hit_enemies: Array = []  # Track enemies we've already hit to avoid double-hits

func initialize(level_ref: Node, lane_idx: int, start_pos: Vector2, target_pos: Vector2) -> void:
	level = level_ref
	lane_index = lane_idx
	_start = start_pos
	position = start_pos
	_target = target_pos
	_dir = (_target - _start).normalized()
	_length = (_target - _start).length()
	rotation = _dir.angle() + PI / 2.0
	_apply_perspective_scale(0.0)


func _process(delta: float) -> void:
	if _length <= 0.0:
		queue_free()
		return
	# Compute progress along the path from start (near) to target (far)
	var traveled := _dir.dot(position - _start)
	var t = clamp(traveled / _length, 0.0, 1.0)
	var ease_t := pow(t, perspective_ease)
	# Update scale
	_apply_perspective_scale(ease_t)
	# Move with perspective-adjusted speed
	var current_speed = lerp(near_speed, far_speed, ease_t)
	position += _dir * current_speed * delta
	# Despawn after reaching/overshooting target
	traveled = _dir.dot(position - _start)
	if traveled >= _length + extra_travel_margin:
		queue_free()

func _apply_perspective_scale(ease_t: float) -> void:
	var s = lerp(near_scale, far_scale, ease_t)
	scale = Vector2.ONE * s


func retarget_after_shift() -> void:
	if level == null:
		return
	var count = level.get_lane_count()
	if count <= 0:
		return
	# Progress along old path
	var traveled := _dir.dot(position - _start)
	var t = 0.0 if _length <= 0.0 else clamp(traveled / _length, 0.0, 1.0)
	# New lane geometry
	var i_next: int = (lane_index + 1) % count
	var inner_mid: Vector2 = level.inner_points[lane_index].lerp(level.inner_points[i_next], 0.5)
	# Use inner midpoint as target for projectiles
	var new_target := inner_mid
	var lane_dir = (new_target - level.outer_points[lane_index].lerp(level.outer_points[i_next], 0.5))
	if lane_dir.length() == 0.0:
		queue_free()
		return
	lane_dir = lane_dir.normalized()
	# Project original start onto new lane direction for a consistent path
	var start_proj_len = lane_dir.dot(_start - inner_mid)
	var start_on_lane = inner_mid + lane_dir * start_proj_len
	_start = start_on_lane
	_target = new_target
	_length = (_target - _start).length()
	if _length <= 0.0:
		queue_free()
		return
	_dir = (_target - _start).normalized()
	rotation = _dir.angle() + PI / 2.0
	# Reposition preserving progress
	position = _start.lerp(_target, t)


func _on_collision_polygon_2d_tree_entered() -> void:
	print("projectile entered!")


func _check_collisions() -> void:
	# Use Area2D overlap if we have one
	var area = get_node_or_null("Area2D")
	if area == null or not area is Area2D:
		return
	var overlapping = area.get_overlapping_areas()
	for overlapper in overlapping:
		# Check if this is an enemy hitbox
		var enemy = overlapper.get_parent()
		if enemy == null or _hit_enemies.has(enemy):
			continue
		# If enemy has take_damage, hit it
		if enemy.has_method("take_damage"):
			_hit_enemies.append(enemy)
			enemy.take_damage(damage)
			queue_free()  # Projectile destroyed on hit
			break


func _on_area_entered(area: Area2D) -> void:
	# Check if the area that entered is an enemy hitbox
	var enemy = area
	print("entered: ", enemy)
	if enemy == null or _hit_enemies.has(enemy):
		return
	# If enemy has take_damage, hit it
	if enemy.has_method("take_damage"):
		_hit_enemies.append(enemy)
		enemy.take_damage(damage)
		queue_free()  # Projectile destroyed on hit
