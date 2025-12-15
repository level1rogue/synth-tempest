extends Node2D

@export var shape_name: String = "pentagon"
@export var segments_per_edge: int = 4        # lanes per original edge
@export var inner_ratio: float = 0.05         # inner ring size (of min dimension)
@export var outer_ratio: float = 0.45         # outer ring size (of min dimension)

var inner_points: Array[Vector2] = []
var outer_points: Array[Vector2] = []
var lanes := []

var inner_line: Line2D
var outer_line: Line2D
var lanes_container: Node2D

var screen_center := Vector2(0,0)
var lane_line_scene: PackedScene = preload("res://scenes/lane_line.tscn")

func _ensure_lines():
		if inner_line == null:
				inner_line = Line2D.new()
				inner_line.width = 2.0
				inner_line.default_color = Color(0.0, 0.369, 0.42, 1.0)  # inner ring color
				add_child(inner_line)
		if outer_line == null:
				outer_line = Line2D.new()
				outer_line.width = 2.0
				outer_line.default_color = Color(0.3, 0.9, 1.0)  # outer ring color
				add_child(outer_line)
		if lanes_container == null:
				lanes_container = Node2D.new()
				add_child(lanes_container)



func get_lane_position(index: int, t: float) -> Vector2:
	var a = lanes[index]
	var b = lanes[(index + 1) % lanes.size()]
	print(", lanes: ", a, ", ", b, ", ", t)
	return a.lerp(b, t)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_center = get_viewport_rect().size * 0.5
	_ensure_lines()
	build_tube()

	get_viewport().size_changed.connect(recalc_on_resize) 	

func recalc_on_resize():
		screen_center = get_viewport_rect().size * 0.5
		build_tube()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func build_tube():
	var viewport_size = get_viewport_rect().size
	var min_dim = min(viewport_size.x, viewport_size.y)
	var inner_scale = min_dim * inner_ratio
	var outer_scale = min_dim * outer_ratio

	# 1) Get normalized, subdivided points for the chosen shape
	var base_points = load("res://scripts/shapes_config.gd").calc_shape_segments(shape_name, segments_per_edge)

	# 2) Scale and translate to center for both rings
	inner_points.clear()
	outer_points.clear()
	for p in base_points:
			inner_points.append(screen_center + Vector2(p.x * inner_scale, p.y * inner_scale))
			outer_points.append(screen_center + Vector2(p.x * outer_scale, p.y * outer_scale))

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
		for child in lanes_container.get_children():
			child.queue_free()
		#lanes_container.clear()
		for i in inner_points.size():
			var spoke: Line2D = lane_line_scene.instantiate()
			if spoke == null:
				continue
			spoke.clear_points()
			spoke.add_point(inner_points[i])
			spoke.add_point(outer_points[i])
			lanes_container.add_child(spoke)

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
