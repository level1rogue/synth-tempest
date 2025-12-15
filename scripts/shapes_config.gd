extends Node

# Shape definitions as normalized coordinates relative to center
# Each point is [x_offset, y_offset] as fractions of the scale_factor
const SHAPES = {
	"triangle": [
		Vector2(0, -0.67),      # top
		Vector2(1.0, 0.67),     # bottom right
		Vector2(-1.0, 0.67),    # bottom left
	],
	"square": [
		Vector2(-0.7, -0.7),    # top left
		Vector2(0.7, -0.7),     # top right
		Vector2(0.7, 0.7),      # bottom right
		Vector2(-0.7, 0.7),     # bottom left
	],
	"pentagon": [
		Vector2(0, -1.0),
		Vector2(0.95, -0.31),
		Vector2(0.59, 0.81),
		Vector2(-0.59, 0.81),
		Vector2(-0.95, -0.31),
	],
	"hexagon": [
		Vector2(0, -1.0),
		Vector2(0.87, -0.5),
		Vector2(0.87, 0.5),
		Vector2(0, 1.0),
		Vector2(-0.87, 0.5),
		Vector2(-0.87, -0.5),
	],
	"octagon": [
		Vector2(0, -1.0),
		Vector2(0.71, -0.71),
		Vector2(1.0, 0),
		Vector2(0.71, 0.71),
		Vector2(0, 1.0),
		Vector2(-0.71, 0.71),
		Vector2(-1.0, 0),
		Vector2(-0.71, -0.71),
	],
	"custom": [
		Vector2(0, -0.67),
		Vector2(0, -0.03),
		Vector2(1.0, 0.67),
		Vector2(0, 0.67),
		Vector2(0, 0.33),
		Vector2(-1.0, 0.67),
	],
}

static func get_shape(shape_name: String) -> Array:
	if SHAPES.has(shape_name):
		return SHAPES[shape_name]
	else:
		push_warning("Shape '%s' not found, returning triangle" % shape_name)
		return SHAPES["triangle"]

static func get_available_shapes() -> Array:
	return SHAPES.keys()

# Subdivide each edge of a shape into a fixed number of segments.
# Returns an Array of Vector2 points in normalized coordinates.
# Example: calc_shape_segments("triangle", 4) yields 4 segments per edge
# (i.e., inserts 3 evenly spaced points between each pair of vertices).
static func calc_shape_segments(shape_name: String, segments_per_edge: int) -> Array:
	var base := get_shape(shape_name)
	var result: Array = []
	if segments_per_edge <= 1:
		# No subdivision requested, return base vertices
		return base.duplicate()

	for i in base.size():
		var a: Vector2 = base[i]
		var b: Vector2 = base[(i + 1) % base.size()]
		# Always include the starting vertex of the edge
		result.append(a)
		var step := 1.0 / float(segments_per_edge)
		# Insert intermediate points; exclude b to avoid duplicates
		for s in range(1, segments_per_edge):
			print("segment: ", s)
			var t := step * float(s)
			result.append(a.lerp(b, t))
	return result
