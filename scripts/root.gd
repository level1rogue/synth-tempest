extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Background.position = get_viewport_rect().size /2
	$Background.scale = get_viewport_rect().size

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
