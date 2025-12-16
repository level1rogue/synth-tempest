extends Resource
class_name LevelConfig

## Configuration resource for level parameters
## Create different .tres files to define multiple levels

# Time
@export var duration: int = 30

# Geometry
@export var shape_name: String = "octagon"
@export var segments_per_edge: int = 2

# Ring sizes
@export_range(0.01, 0.2) var inner_ratio: float = 0.05
@export_range(0.2, 0.6) var outer_ratio: float = 0.40

# Perspective
@export_range(0.0, 0.5) var inner_y_offset_ratio: float = 0.22
@export_range(0.0, 0.15) var perspective_shift_ratio: float = 0.08
@export_range(0.0, 1.0) var outer_shift_ratio: float = 0.0

# Enemy spawning
@export_range(0.5, 5.0) var enemy_spawn_interval: float = 2.0

# Colors
@export var ring_color: Color = Color("8b5cf6")
@export var highlight_color: Color = Color("a78bfa")
@export_range(0.0, 1.0) var ring_alpha: float = 0.2

# Difficulty modifiers (for future use)
@export var enemy_speed_multiplier: float = 1.0
@export var enemy_health_multiplier: float = 1.0
@export var projectile_damage_multiplier: float = 1.0
