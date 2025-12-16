# Level Configuration System

This project uses a custom Resource system to define multiple levels with different parameters.

## Creating New Levels

### Quick Start

1. In Godot, go to `resources/` folder
2. Right-click → Duplicate an existing level file (e.g., `level_1_triangle.tres`)
3. Rename it (e.g., `level_4_pentagon.tres`)
4. Double-click to open in Inspector
5. Adjust parameters:
   - **shape_name**: "triangle", "square", "pentagon", "hexagon", "octagon", "circle"
   - **segments_per_edge**: Number of lanes per original edge (higher = more lanes)
   - **inner/outer_ratio**: Ring sizes (0-1 range)
   - **perspective_shift_ratio**: How much center shifts toward player (subtle depth effect)
   - **enemy_spawn_interval**: Seconds between enemy spawns
   - **ring_color / highlight_color**: Visual theme
   - **enemy_speed_multiplier**: Difficulty tuning (1.0 = normal, 1.5 = 50% faster)

### Using Levels

In your Level scene (`scenes/level.tscn`):

- Select the Level node
- In Inspector, drag your level config resource into the "Level Config" property

### Level Progression Example

```gdscript
# In a future level manager script:
var levels = [
    preload("res://resources/level_1_triangle.tres"),
    preload("res://resources/level_2_hexagon.tres"),
    preload("res://resources/level_3_octagon_hard.tres"),
]

func load_level(index: int):
    level_node.level_config = levels[index]
    level_node.build_tube()  # Rebuild with new config
```

## Available Parameters

### Geometry

- `shape_name`: Base polygon shape
- `segments_per_edge`: Lane subdivisions per edge

### Visual

- `ring_color`: Main tube/spoke color
- `highlight_color`: Active lane color
- `ring_alpha`: Transparency of inner ring

### Perspective

- `inner_ratio`: Inner ring size (% of screen)
- `outer_ratio`: Outer ring size
- `inner_y_offset_ratio`: Vertical offset for depth illusion
- `perspective_shift_ratio`: Center shift intensity
- `outer_shift_ratio`: Parallax on outer ring

### Gameplay

- `enemy_spawn_interval`: Time between spawns (seconds)
- `enemy_speed_multiplier`: Speed modifier (1.0 = base)
- `enemy_health_multiplier`: Health modifier
- `projectile_damage_multiplier`: Damage modifier

## Examples Included

- **level_1_triangle.tres**: Easy starter, triangle shape, slow spawn
- **level_2_hexagon.tres**: Medium difficulty, hexagon, faster enemies
- **level_3_octagon_hard.tres**: Hard mode, octagon with many lanes, fast spawns
